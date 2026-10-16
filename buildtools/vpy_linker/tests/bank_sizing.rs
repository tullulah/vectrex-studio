//! Bank allocation from measured code sizes (generate → assemble → measure → regenerate).
//!
//! The allocator used to size functions with "30 + 25 bytes per statement", off by up to
//! 3x: expression-heavy code left far too much in bank #0 ("Bank 0 overflow: 31163 bytes
//! (max 16384)"). `vpy_linker::sizing::generate_m6809` re-measures every function from
//! assembled code and allocates with the real sizes.
//!
//! Single-bank, multibank and error cases, plus the AST estimate checked against the
//! assembled sizes.

use std::collections::{BTreeSet, HashMap};
use std::path::{Path, PathBuf};

use vpy_codegen::BankConfig;

const BANK_SIZE: usize = 16384;

fn include_dir() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../../ide/frontend/public/include")
}

fn scratch_dir(tag: &str) -> PathBuf {
    let dir = std::env::temp_dir().join(format!("vpy_bank_sizing_{}_{}", std::process::id(), tag));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).expect("create scratch dir");
    dir
}

/// `functions` expression-heavy functions of `statements` statements each, all called
/// from loop(). Each one assembles to ~2.7 KB at 40 statements — about twice what the
/// old estimate assumed.
fn program(functions: usize, statements: usize, rom_size: Option<usize>) -> String {
    let mut src = String::new();
    if let Some(rom) = rom_size {
        src.push_str(&format!("META ROM_TOTAL_SIZE = {rom}\nMETA ROM_BANK_SIZE = {BANK_SIZE}\n"));
    }
    src.push_str("a: i16 = 0\nb: i16 = 0\nc: i16 = 0\narr = [0, 0, 0, 0, 0, 0, 0, 0]\n\n");
    for f in 0..functions {
        src.push_str(&format!("def work_{f}(x, y):\n"));
        for s in 0..statements {
            match (f * 7 + s) % 5 {
                0 => src.push_str(&format!("    a = (a + x * {} - y) & 255\n", s + 1)),
                1 => src.push_str(&format!(
                    "    if a > {s} and b < {}:\n        b = b + (a - c) * 2\n",
                    s + 3
                )),
                2 => src.push_str(&format!("    arr[{}] = arr[{}] + c - {s}\n", s % 8, (s + 1) % 8)),
                3 => src.push_str(&format!("    DRAW_LINE(a, b, a + {s}, b - {s}, 80)\n")),
                _ => src.push_str("    c = (c + a + b + x) / 3\n"),
            }
        }
        src.push_str("    return a + b\n\n");
    }
    src.push_str("def main():\n    SET_INTENSITY(80)\n\ndef loop():\n");
    for f in 0..functions {
        src.push_str(&format!("    c = work_{f}(a, b)\n"));
    }
    src.push_str("    PRINT_NUMBER(-50, 0, c)\n");
    src
}

fn module_of(src: &str) -> vpy_parser::Module {
    let tokens = vpy_parser::lex(src).expect("lex");
    let module = vpy_parser::parse_tokens(&tokens, "main.vpy").expect("parse");
    let mut modules = HashMap::new();
    modules.insert("main".to_string(), module);
    vpy_unifier::unify_modules(modules, "main").expect("unify")
}

fn config_of(module: &vpy_parser::Module) -> BankConfig {
    let rom = module.meta.rom_total_size.map(|s| s as usize).unwrap_or(32768);
    let bank = module.meta.rom_bank_size.map(|s| s as usize).unwrap_or(BANK_SIZE);
    BankConfig::new(rom, bank)
}

/// Bank of every user function in the generated ASM (from the `; Function:` comments).
fn function_banks(asm: &str) -> HashMap<String, u8> {
    asm.lines()
        .filter_map(|l| l.strip_prefix("; Function: "))
        .filter_map(|rest| {
            let (name, bank) = rest.split_once(" (Bank #")?;
            Some((name.to_string(), bank.trim_end_matches(')').parse().ok()?))
        })
        .collect()
}

fn single_bank_rom(generated: &vpy_codegen::GeneratedASM) -> Vec<u8> {
    let sections = vpy_assembler::parse_unified_asm(&generated.asm_source).expect("bank sections");
    vpy_assembler::set_include_dir(Some(include_dir()));
    let binaries = vpy_assembler::assemble_banks(sections).expect("assemble");
    vpy_linker::link_unified_asm(generated, binaries).expect("link").rom_data
}

fn link_multibank(asm: &str, config: &BankConfig, dir: &Path) -> Result<Vec<u8>, String> {
    let asm_path = dir.join("game.asm");
    let bin_path = dir.join("game.bin");
    std::fs::write(&asm_path, asm).unwrap();
    let linker = vpy_linker::MultiBankLinker::new(
        config.rom_bank_size as u32,
        config.rom_bank_count as u8,
        true,
        Some(include_dir()),
    );
    linker.generate_multibank_rom(&asm_path, &bin_path)?;
    Ok(std::fs::read(&bin_path).unwrap())
}

#[test]
fn single_bank_is_generated_once_and_unchanged() {
    let module = module_of(&program(3, 10, None));
    let config = config_of(&module);
    assert!(!vpy_codegen::is_m6809_multibank(&config));
    let plain = vpy_codegen::generate_from_module(&module, &config, "SIZING", &[]).unwrap();
    let sized = vpy_linker::sizing::generate_m6809(&module, &config, "SIZING", &[], Some(include_dir())).unwrap();
    // Generated labels are numbered by process-wide counters, so compare the ROMs.
    assert_eq!(single_bank_rom(&plain), single_bank_rom(&sized));
    assert!(!sized.asm_source.contains(vpy_codegen::FUNCTIONS_END_MARKER));
}

/// ~27 KB of functions in a 64 KB ROM (3 code banks). With the old estimate this put
/// everything in bank #0 ("Bank 0 overflow: 27865 bytes (max: 16384 bytes)"); placed by
/// measured size, the program spreads over the banks and links.
#[test]
fn oversized_program_spreads_across_banks_and_links() {
    let module = module_of(&program(10, 40, Some(65536)));
    let config = config_of(&module);
    let labels = vpy_linker::sizing::movable_function_labels(&module);

    let generated = vpy_linker::sizing::generate_m6809(&module, &config, "SIZING", &[], Some(include_dir()))
        .expect("fits 3 code banks");
    let report = vpy_linker::sizing::measure_multibank_asm(&generated.asm_source, &config, Some(include_dir()), &labels)
        .expect("measure");
    let code: usize = report.function_sizes.values().sum();
    assert!(code > 25_000, "the fixture is ~27 KB of functions, got {code}");
    // What the old "30 + 25 bytes per statement" estimate believed.
    let old_estimate: usize = 10 * (30 + 25 * 48);
    assert!(code > old_estimate * 2, "old estimate {old_estimate}, assembled {code}");

    // Every code bank fits, with the allocator's margin; more than one bank is used.
    for (bank, total) in report.bank_total_bytes.iter().enumerate() {
        assert!(
            total + vpy_bank_allocator::allocator::MEASURED_BANK_MARGIN <= BANK_SIZE,
            "bank #{bank}: {total} bytes"
        );
    }
    let banks: BTreeSet<u8> = function_banks(&generated.asm_source).values().copied().collect();
    assert!(banks.len() >= 2, "functions spread over the code banks: {banks:?}");

    // The banks the ASM says are the banks the measurement found.
    for (label, bank) in function_banks(&generated.asm_source) {
        assert_eq!(report.function_banks[&label.to_uppercase()], bank, "{label}");
    }

    let dir = scratch_dir("spread");
    let rom = link_multibank(&generated.asm_source, &config, &dir).expect("links");
    assert_eq!(rom.len(), 65536);
    let _ = std::fs::remove_dir_all(&dir);
}

/// Measured layouts are reproducible: same program, same ROM bytes.
#[test]
fn measured_layout_is_deterministic() {
    let module = module_of(&program(7, 40, Some(65536)));
    let config = config_of(&module);
    let build = |tag: &str| {
        let generated = vpy_linker::sizing::generate_m6809(&module, &config, "SIZING", &[], Some(include_dir())).unwrap();
        let dir = scratch_dir(tag);
        let rom = link_multibank(&generated.asm_source, &config, &dir).expect("links");
        let _ = std::fs::remove_dir_all(&dir);
        (function_banks(&generated.asm_source), rom)
    };
    let first = build("det0");
    for i in 1..3 {
        let again = build(&format!("det{i}"));
        assert_eq!(first.0, again.0, "bank assignment changed between runs");
        assert!(first.1 == again.1, "ROM bytes changed between runs");
    }
}

/// Too much code for the ROM: the error gives the shortfall and the ROM size to use.
#[test]
fn too_big_program_reports_how_much_and_what_to_set() {
    let module = module_of(&program(20, 40, Some(65536)));
    let config = config_of(&module);
    let err = vpy_linker::sizing::generate_m6809(&module, &config, "SIZING", &[], Some(include_dir()))
        .expect_err("55 KB of functions do not fit 3 code banks");
    assert!(err.contains("does not fit the ROM"), "{err}");
    assert!(err.contains("Short by at least"), "{err}");
    assert!(err.contains("META ROM_TOTAL_SIZE = 131072"), "{err}");

    // ...and the suggested size does fit.
    let module = module_of(&program(20, 40, Some(131072)));
    let config = config_of(&module);
    let generated = vpy_linker::sizing::generate_m6809(&module, &config, "SIZING", &[], Some(include_dir()))
        .expect("fits 128 KB");
    let dir = scratch_dir("suggested");
    link_multibank(&generated.asm_source, &config, &dir).expect("links at the suggested size");
    let _ = std::fs::remove_dir_all(&dir);
}

/// One function bigger than a bank can never be placed.
#[test]
fn function_bigger_than_a_bank_is_an_error() {
    let module = module_of(&program(1, 260, Some(65536)));
    let config = config_of(&module);
    let err = vpy_linker::sizing::generate_m6809(&module, &config, "SIZING", &[], Some(include_dir()))
        .expect_err("one ~17 KB function");
    assert!(err.to_lowercase().contains("function 'work_0' is"), "{err}");
    assert!(err.contains("split it"), "{err}");
}

/// Single-bank overflow advice: how much over, and the META lines to add.
#[test]
fn single_bank_overflow_advice_names_the_fix() {
    let module = module_of(&program(1, 1, None));
    let msg = vpy_linker::sizing::single_bank_overflow_advice(40000, 32768, &module, &[]);
    assert!(msg.contains("7232 bytes over"), "{msg}");
    assert!(msg.contains("META ROM_TOTAL_SIZE = 131072"), "{msg}");
    assert!(msg.contains("META ROM_BANK_SIZE = 16384"), "{msg}");
}

/// The AST estimate (used only until the code is measured) against assembled sizes:
/// generous in total, never wildly low for a function.
#[test]
fn estimate_tracks_assembled_sizes() {
    let src = format!(
        "{}\ndef small(v):\n    return v + 1\n\ndef draw_box(x, y):\n    DRAW_LINE(x, y, x + 10, y, 80)\n    DRAW_LINE(x + 10, y, x + 10, y + 10, 80)\n    DRAW_LINE(x + 10, y + 10, x, y + 10, 80)\n    DRAW_LINE(x, y + 10, x, y, 80)\n\ndef walk(n):\n    total = 0\n    for i in range(0, n):\n        if arr[i & 7] > 3:\n            total = total + arr[i & 7] * 2\n        else:\n            total = total - 1\n    return total\n",
        program(4, 25, Some(65536))
    );
    let module = module_of(&src);
    let config = BankConfig::new(1 << 20, BANK_SIZE); // plenty of banks: measure everything
    let labels = vpy_linker::sizing::movable_function_labels(&module);
    let generated = vpy_codegen::generate_from_module(&module, &config, "SIZING", &[]).unwrap();
    let report = vpy_linker::sizing::measure_multibank_asm(&generated.asm_source, &config, Some(include_dir()), &labels)
        .expect("measure");

    let mut total_est = 0;
    let mut total_real = 0;
    for item in &module.items {
        let vpy_parser::Item::Function(f) = item else { continue };
        let label = vpy_parser::symbols::m6809_label(&f.name);
        let Some(&real) = report.function_sizes.get(&label) else { continue };
        let est = vpy_bank_allocator::graph::estimate_function_size(f);
        total_est += est;
        total_real += real;
        assert!(real <= est * 2, "{}: estimated {est}, assembled {real}", f.name);
    }
    assert!(total_real > 0);
    assert!(
        total_est >= total_real,
        "estimates should be generous in total: estimated {total_est}, assembled {total_real}"
    );
}
