//! Measured code sizes for the m6809 bank allocator.
//!
//! The allocator (Phase 4) has to decide which bank each function goes to before any
//! code exists, so on its own it can only estimate sizes from the AST — and those
//! estimates were off by 2x, which left too much code in bank #0. This module closes the
//! loop with the real assembler:
//!
//! 1. generate the program with the AST estimates,
//! 2. split it into banks and assemble each code bank exactly as the multibank linker
//!    does (same bank split, same const-array relocation, same long-branch rewrite),
//! 3. read every function's size off the label addresses,
//! 4. regenerate with those sizes ([`vpy_codegen::CodeSizeHints`]).
//!
//! A function's code does not depend on the bank it lands in (cross-bank calls are
//! patched to trampolines of the same `JSR` size), so the second layout is built from
//! the sizes it will really have. Addresses are still only computed by the linker: the
//! measurement only yields byte counts.

use std::collections::{BTreeMap, BTreeSet};
use std::path::PathBuf;

use vpy_codegen::{AssetInfo, BankConfig, CodeSizeHints, GeneratedASM, FUNCTIONS_END_MARKER};
use vpy_parser::Module;

use crate::multi_bank_linker::{convert_short_to_long_branches, relocate_array_data_to_helpers, MultiBankLinker};

/// Label the measurement puts where the backend wrote [`FUNCTIONS_END_MARKER`].
const END_LABEL: &str = "VPY_SIZE_PROBE_END";

/// Generation passes at most: estimate, measured, and one more in case the measured
/// layout changed a size (it should not — the loop stops as soon as sizes repeat).
const MAX_PASSES: usize = 3;

/// Sizes read from one assembly of the code banks.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct CodeSizeReport {
    /// Bytes of each movable user function, keyed by its assembly label.
    pub function_sizes: BTreeMap<String, usize>,
    /// Bank of each measured function.
    pub function_banks: BTreeMap<String, u8>,
    /// Bytes of MAIN + LOOP_BODY (always in bank #0).
    pub entry_bytes: usize,
    /// Per code bank: bytes that are not movable functions, up to the end of the
    /// function block (bank #0: header + START + MAIN + LOOP_BODY).
    pub bank_fixed_bytes: Vec<usize>,
    /// Per code bank: total assembled bytes (functions + fixed code + assets).
    pub bank_total_bytes: Vec<usize>,
}

impl CodeSizeReport {
    pub fn to_hints(&self) -> CodeSizeHints {
        CodeSizeHints {
            function_sizes: self.function_sizes.clone(),
            bank_fixed_bytes: self.bank_fixed_bytes.clone(),
        }
    }

    /// Bytes of the movable functions measured in `bank`.
    pub fn bank_function_bytes(&self, bank: u8) -> usize {
        self.function_banks.iter()
            .filter(|(_, &b)| b == bank)
            .map(|(f, _)| self.function_sizes[f])
            .sum()
    }
}

/// Assembly labels of the program's movable functions (everything but main/loop).
pub fn movable_function_labels(module: &Module) -> BTreeSet<String> {
    module.items.iter()
        .filter_map(|item| match item {
            vpy_parser::Item::Function(f) if !vpy_bank_allocator::allocator::is_pinned_to_bank0(&f.name) => {
                Some(vpy_parser::symbols::m6809_label(&f.name))
            }
            _ => None,
        })
        .collect()
}

/// Measure the code banks of a generated multibank program.
///
/// `function_labels` are the labels of the movable functions; MAIN marks bank #0's
/// entry code. Fails if a code bank does not assemble (the caller then keeps the
/// estimated layout and the link reports the real error).
pub fn measure_multibank_asm(
    asm: &str,
    bank_config: &BankConfig,
    include_dir: Option<PathBuf>,
    function_labels: &BTreeSet<String>,
) -> Result<CodeSizeReport, String> {
    let bank_count = bank_config.rom_bank_count;
    if bank_count < 3 || bank_count > 256 {
        return Err(format!("not a multibank layout ({} banks)", bank_count));
    }
    let helpers_bank = (bank_count - 1) as u8;
    let linker = MultiBankLinker::new(
        bank_config.rom_bank_size as u32,
        bank_count as u8,
        true,
        include_dir.clone(),
    );
    let mut sections = linker.split_asm_by_bank(asm)?;
    if sections.len() > 2 {
        relocate_array_data_to_helpers(&mut sections, helpers_bank);
    }
    if let Some(dir) = include_dir {
        vpy_assembler::m6809::asm_to_binary::set_include_dir(Some(dir));
    }

    let mut report = CodeSizeReport::default();
    for bank_id in 0..helpers_bank {
        let Some(section) = sections.get(&bank_id) else {
            report.bank_fixed_bytes.push(0);
            report.bank_total_bytes.push(0);
            continue;
        };
        // The end-of-functions comment becomes a (zero-byte) label we can read back.
        let mut text = String::with_capacity(section.asm_code.len() + 64);
        let mut has_end = false;
        for line in convert_short_to_long_branches(&section.asm_code).lines() {
            if line.trim_start().starts_with(FUNCTIONS_END_MARKER) && !has_end {
                text.push_str(END_LABEL);
                text.push_str(":\n");
                has_end = true;
            } else {
                text.push_str(line);
                text.push('\n');
            }
        }

        let (binary, _, symbols, _) =
            vpy_assembler::m6809::asm_to_binary::assemble_m6809(&text, 0x0000, true, false)
                .map_err(|e| format!("bank #{} does not assemble: {}", bank_id, e))?;
        let total = binary.len();
        let addr = |label: &str| symbols.get(label).map(|&a| a as usize);

        // Function starts in this bank, in address order.
        let mut starts: Vec<(usize, &str)> = function_labels.iter()
            .filter_map(|l| addr(l).map(|a| (a, l.as_str())))
            .collect();
        let entry = if bank_id == 0 { addr("MAIN") } else { None };
        if let Some(a) = entry {
            starts.push((a, "MAIN"));
        }
        starts.sort();

        let end = match addr(END_LABEL) {
            Some(a) => a,
            None if starts.is_empty() => total,
            None => return Err(format!("bank #{}: end-of-functions marker missing", bank_id)),
        };
        for (i, &(start, label)) in starts.iter().enumerate() {
            let next = starts.get(i + 1).map(|&(a, _)| a).unwrap_or(end);
            if next < start {
                return Err(format!("bank #{}: function {} ends before it starts", bank_id, label));
            }
            if label == "MAIN" {
                report.entry_bytes = next - start;
            } else {
                report.function_sizes.insert(label.to_string(), next - start);
                report.function_banks.insert(label.to_string(), bank_id);
            }
        }
        let movable: usize = starts.iter()
            .filter(|(_, l)| *l != "MAIN")
            .map(|(_, l)| report.function_sizes[*l])
            .sum();
        report.bank_fixed_bytes.push(end.saturating_sub(movable));
        report.bank_total_bytes.push(total);
    }

    let missing: Vec<&String> = function_labels.iter()
        .filter(|l| !report.function_sizes.contains_key(*l))
        .collect();
    if !missing.is_empty() {
        return Err(format!("functions not found in any code bank: {:?}", missing));
    }
    Ok(report)
}

/// m6809 code generation as `vpy_cli build` runs it.
///
/// Single-bank layouts are generated once. Multibank layouts are generated, measured
/// and regenerated with the measured sizes, so the bank allocator places functions by
/// their real size; code that cannot fit the configured ROM fails here with the exact
/// shortfall instead of as a bank overflow in the linker.
pub fn generate_m6809(
    module: &Module,
    bank_config: &BankConfig,
    title: &str,
    assets: &[AssetInfo],
    include_dir: Option<PathBuf>,
) -> Result<GeneratedASM, String> {
    let mut generated = vpy_codegen::generate_from_module(module, bank_config, title, assets)
        .map_err(|e| e.to_string())?;
    if !vpy_codegen::is_m6809_multibank(bank_config) {
        return Ok(generated);
    }

    let labels = movable_function_labels(module);
    let mut last_hints: Option<CodeSizeHints> = None;
    for _ in 1..MAX_PASSES {
        let report = match measure_multibank_asm(&generated.asm_source, bank_config, include_dir.clone(), &labels) {
            Ok(r) => r,
            Err(e) => {
                // The link assembles the same banks and reports the real problem.
                eprintln!("  ⚠ Code size measurement failed ({}); bank layout uses estimates", e);
                return Ok(generated);
            }
        };
        let hints = report.to_hints();
        if last_hints.as_ref() == Some(&hints) {
            break; // sizes are stable: this layout was built from them
        }
        generated = vpy_codegen::generate_from_module_with_hints(module, bank_config, title, assets, &hints)
            .map_err(|e| e.to_string())?;
        last_hints = Some(hints);
    }
    Ok(generated)
}

/// Advice for a single-bank (32 KB) cartridge whose image came out `size` bytes against
/// a `limit`-byte ROM: what takes the room, and what to change in the project.
pub fn single_bank_overflow_advice(size: usize, limit: usize, module: &Module, assets: &[AssetInfo]) -> String {
    use vpy_codegen::AssetType;
    const BANK: usize = 16384;

    let used = vpy_codegen::m6809::assets::filter_used_assets(assets, module);
    let mut sized: Vec<(String, usize)> = vpy_codegen::m6809::assets::prepare_assets_with_sizes(&used)
        .into_iter()
        .map(|a| (a.info.name, a.binary_size))
        .collect();
    sized.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));
    let recordings: Vec<&str> = used.iter()
        .filter(|a| a.asset_type == AssetType::Recording)
        .map(|a| a.name.as_str())
        .collect();

    let mut msg = format!(
        "The program is {} bytes and the cartridge is a single {}-byte ROM: {} bytes over.",
        size, limit, size.saturating_sub(limit)
    );
    if !recordings.is_empty() {
        msg.push_str(&format!(
            " Recordings ({}) are single-bank only on m6809, so a bigger ROM does not help: \
             use shorter recordings, or build for rp2350/pitrex.",
            recordings.join(", ")
        ));
        return msg;
    }
    if !sized.is_empty() {
        let list: Vec<String> = sized.iter().take(5).map(|(n, s)| format!("{} ({} bytes)", n, s)).collect();
        let total: usize = sized.iter().map(|(_, s)| s).sum();
        msg.push_str(&format!(
            " Assets take {} bytes, code and runtime the other {}; largest assets: {}.",
            total, size.saturating_sub(total), list.join(", ")
        ));
    }
    if let Some((name, s)) = sized.iter().find(|(_, s)| *s > BANK) {
        msg.push_str(&format!(
            " Asset '{}' alone is {} bytes, more than one {}-byte bank, and an asset cannot span \
             banks, so a bigger ROM does not help: shorten or split it.",
            name, s, BANK
        ));
        return msg;
    }
    // Banked cartridge: N-1 switchable code/asset banks + the fixed helpers bank.
    let rom = (size + 2 * BANK).next_power_of_two().max(4 * BANK);
    msg.push_str(&format!(
        " Use a banked cartridge: add `META ROM_TOTAL_SIZE = {}` and `META ROM_BANK_SIZE = {}` \
         to the entry file (or make the code/assets smaller).",
        rom, BANK
    ));
    msg
}
