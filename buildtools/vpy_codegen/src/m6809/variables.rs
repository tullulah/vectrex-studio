use vpy_parser::{Module, Item, Expr};
use std::collections::HashSet;
use super::ram_layout::RamLayout;
use super::context;

/// Determine variable size in bytes and signedness from type annotation
/// Returns (bytes, signed)
fn size_for_annotation(type_annotation: &Option<String>) -> (usize, bool) {
    match type_annotation.as_deref() {
        Some("u8") => (1, false),
        Some("i8") => (1, true),
        Some("u16") => (2, false),
        Some("i16") => (2, true),
        _ => (2, true), // Default to i16 (16-bit signed) for untyped variables
    }
}

/// Generate user variables using a RamLayout that already has system variables allocated
/// Returns ASM string for array data sections (not EQU definitions - those come from RamLayout)
pub fn generate_user_variables(module: &Module, ram: &mut RamLayout) -> Result<String, String> {
    let asm = String::new();
    let mut vars = Vec::new();  // Changed to Vec to store (name, type_annotation, is_array, element_count)
    let mut mutable_arrays: Vec<(String, usize, (usize, bool))> = Vec::new();  // (name, element_count, (bytes, signed))

    // Collect all global variables from module items (GlobalLet and Const)
    for item in &module.items {
        match item {
            Item::GlobalLet { name, value, type_annotation, .. } => {
                let (bytes, signed) = size_for_annotation(type_annotation);
                context::set_var_size(name, bytes, signed);

                // Check if this is an array initialization (mutable array, needs RAM)
                if let Expr::List(elements) = value {
                    mutable_arrays.push((name.clone(), elements.len(), (bytes, signed)));
                } else {
                    vars.push((name.clone(), bytes));
                }
            }
            Item::Const { name, value, type_annotation, .. } => {
                let (bytes, signed) = size_for_annotation(type_annotation);
                context::set_var_size(name, bytes, signed);
                // SCALAR const literals (numeric) are inlined as immediates at every use
                // (see mod.rs:set_const_value + expressions.rs:emit_simple_expr). No RAM
                // slot needed. Skipping these saves significant RAM in programs with many
                // tunables — critical for keeping the layout inside the 1KB Vectrex RAM
                // window ($C800-$CBFF). Array consts still need allocation for the
                // pointer; we handle those below in mutable_arrays.
                if matches!(value, Expr::Number(_)) {
                    continue;
                }
                // Const ARRAYS live in ROM (ARRAY_<NAME>_DATA); the name evaluates to
                // that address, so no RAM slot either.
                if matches!(value, Expr::List(_)) {
                    continue;
                }
                vars.push((name.clone(), bytes));
            }
            _ => {}
        }
    }

    // Parameters and locals are not globals: they live in their function's frame
    // (see `frames`), allocated by `helpers::generate_ram_and_arrays`.

    // Allocate all user variables using RamLayout with correct sizes.
    // Skip vars that are promoted to compile-time constants — every reference
    // is inlined as an LDD #N immediate (see expressions.rs:emit_simple_expr),
    // so no RAM slot is needed. This is essential for SnowBros and similar
    // programs that declare many scalar tunables; without skipping, those vars
    // would push later allocations past $CBFF into BIOS-aliased RAM.
    // Dedupe by UPPERCASED name to avoid collisions when both `ex` and `EX`
    // appear in the same module (both emit `VAR_EX` and the second clobbers).
    let mut seen = HashSet::new();
    for (var, bytes) in vars.iter() {
        let canonical = var.to_uppercase();
        if seen.insert(canonical) {
            if context::get_const_value(var).is_some() {
                continue;
            }
            // Global array names evaluate to their data label (VAR_<NAME>_DATA /
            // ARRAY_<NAME>_DATA); they have no pointer variable.
            if context::global_array_base_label(var).is_some() {
                continue;
            }
            ram.allocate(&format!("VAR_{}", var.to_uppercase()), *bytes, &format!("User variable: {}", var));
        }
    }

    // Allocate RAM space for MUTABLE arrays
    // Arrays defined with 'let' (GlobalLet) are mutable and need RAM space
    // Arrays defined with 'const' stay in ROM (handled in emit_array_data)
    for (name, element_count, (element_bytes, _signed)) in &mutable_arrays {
        let total_size = element_count * element_bytes;  // element_count * bytes per element
        ram.allocate(
            &format!("VAR_{}_DATA", name.to_uppercase()),
            total_size,
            &format!("Mutable array '{}' data ({} elements x {} bytes)", name, element_count, element_bytes)
        );
    }

    // NOTE: Array ROM literals moved to emit_array_data() function
    // Arrays are emitted BEFORE code (after EQU definitions) to ensure labels are defined before use

    // NOTE: VAR_ARG definitions are now in helpers.rs using ram.allocate_fixed()
    // They are emitted alongside system variables because they need fixed addresses

    // NOTE: Internal variables (DRAW_VEC_X, MIRROR_Y, etc.) are now allocated via RamLayout in helpers.rs
    // This prevents collisions with scratchpad variables like TEMP_YX

    Ok(asm)
}

/// Emit ARRAY_{NAME}_LEN EQU constants for all arrays.
/// These are needed by ForIn loops to determine the iteration count at assemble time.
pub fn emit_array_len_equates(module: &Module) -> String {
    let mut asm = String::new();
    let mut has_any = false;
    for item in &module.items {
        match item {
            Item::GlobalLet { name, value, .. } | Item::Const { name, value, .. } => {
                if let Expr::List(elements) = value {
                    if !has_any {
                        asm.push_str("; Array length constants\n");
                        has_any = true;
                    }
                    asm.push_str(&format!(
                        "ARRAY_{}_LEN         EQU {}   ; {} elements\n",
                        name.to_uppercase(),
                        elements.len(),
                        elements.len()
                    ));
                }
            }
            _ => {}
        }
    }
    if has_any { asm.push('\n'); }
    asm
}

/// Emit array data sections (must be called AFTER EQU definitions, BEFORE code)
/// Arrays stored in ROM with ARRAY_{name}_DATA labels
/// At runtime, main() initializes VAR_{name} (RAM pointer) to point to this ROM data
pub fn emit_array_data(module: &Module) -> String {
    let mut asm = String::new();
    let mut arrays = Vec::new();

    // Collect arrays from module (both GlobalLet and Const), storing type_annotation
    for item in &module.items {
        match item {
            Item::GlobalLet { name, value, type_annotation, .. } => {
                if matches!(value, Expr::List(_)) {
                    arrays.push((name.clone(), value.clone(), type_annotation.clone()));
                }
            }
            Item::Const { name, value, type_annotation, .. } => {
                if matches!(value, Expr::List(_)) {
                    arrays.push((name.clone(), value.clone(), type_annotation.clone()));
                }
            }
            _ => {}
        }
    }

    if arrays.is_empty() {
        return asm;
    }

    asm.push_str(";***************************************************************************\n");
    asm.push_str("; ARRAY DATA (ROM literals)\n");
    asm.push_str(";***************************************************************************\n");
    asm.push_str("; Arrays are stored in ROM and accessed via pointers\n");
    asm.push_str("; At startup, main() initializes VAR_{name} to point to ARRAY_{name}_DATA\n\n");

    // Emit array data in ROM (no ORG - flows naturally after EQU definitions)
    for (name, value, type_annotation) in arrays {
        if let Expr::List(elements) = value {
            let array_label = format!("ARRAY_{}_DATA", name.to_uppercase());
            let (element_bytes, _signed) = size_for_annotation(&type_annotation);

            // Check if this is a string array (all elements are StringLit)
            let is_string_array = elements.iter().all(|e| matches!(e, Expr::StringLit(_)));

            if is_string_array {
                // String array: emit individual strings with labels + pointer table (always FDB for string pointers)
                asm.push_str(&format!("; String array literal for variable '{}' ({} elements)\n", name, elements.len()));

                let mut string_labels = Vec::new();

                // Emit individual strings
                for (i, elem) in elements.iter().enumerate() {
                    if let Expr::StringLit(s) = elem {
                        let str_label = format!("{}_STR_{}", array_label, i);
                        string_labels.push(str_label.clone());

                        asm.push_str(&format!("{}:\n", str_label));
                        asm.push_str(&format!("    FCC \"{}\"\n", s.to_ascii_uppercase()));
                        asm.push_str("    FCB $80   ; String terminator (high bit)\n");
                    }
                }

                // Emit pointer table
                asm.push_str(&format!("\n{}:  ; Pointer table for {}\n", array_label, name));
                for str_label in string_labels {
                    asm.push_str(&format!("    FDB {}  ; Pointer to string\n", str_label));
                }
                asm.push_str("\n");
            } else {
                // Number array: emit FCB or FDB based on element size
                asm.push_str(&format!("; Array literal for variable '{}' ({} elements, {} bytes each)\n",
                    name, elements.len(), element_bytes));
                asm.push_str(&format!("{}:\n", array_label));

                let directive = if element_bytes == 1 { "FCB" } else { "FDB" };

                // Emit array elements
                for (i, elem) in elements.iter().enumerate() {
                    if let Expr::Number(n) = elem {
                        if element_bytes == 1 {
                            // For 8-bit: mask to low byte only
                            let low_byte = (n & 0xFF) as u8;
                            asm.push_str(&format!("    {} ${}   ; Element {}\n", directive,
                                format!("{:02X}", low_byte), i));
                        } else {
                            // For 16-bit: use full value
                            asm.push_str(&format!("    {} {}   ; Element {}\n", directive, n, i));
                        }
                    } else {
                        super::diagnostics::error(format!(
                            "array `{}` element {} is not a number literal; array literals must contain \
                             only numbers (e.g. `[1, -2, 3]`) or only strings", name, i));
                        asm.push_str(&format!("    {} 0    ; Element {} (not a literal: compile error)\n", directive, i));
                    }
                }
                asm.push_str("\n");
            }
        }
    }

    asm
}

/// Generate EQU aliases for array access
/// Mutable arrays (GlobalLet): point to RAM (VAR_{NAME}_DATA)
/// Const arrays: point to ROM (ARRAY_{NAME}_DATA)
pub fn emit_array_aliases(module: &Module) -> String {
    let mut asm = String::new();
    
    // Collect info about which arrays are mutable vs const
    let mut has_any_array = false;
    
    for item in &module.items {
        match item {
            Item::GlobalLet { name, value, .. } => {
                if matches!(value, Expr::List(_)) {
                    if !has_any_array {
                        asm.push_str(";***************************************************************************\n");
                        asm.push_str("; ARRAY ACCESS ALIASES\n");
                        asm.push_str(";***************************************************************************\n");
                        asm.push_str("; Mutable arrays -> RAM, Const arrays -> ROM\n\n");
                        has_any_array = true;
                    }
                    // Mutable array: alias points to RAM
                    asm.push_str(&format!("{}_ARRAYPTR EQU VAR_{}_DATA  ; Mutable array -> RAM\n", 
                        name.to_uppercase(), name.to_uppercase()));
                }
            }
            Item::Const { name, value, .. } => {
                if matches!(value, Expr::List(_)) {
                    if !has_any_array {
                        asm.push_str(";***************************************************************************\n");
                        asm.push_str("; ARRAY ACCESS ALIASES\n");
                        asm.push_str(";***************************************************************************\n");
                        asm.push_str("; Mutable arrays -> RAM, Const arrays -> ROM\n\n");
                        has_any_array = true;
                    }
                    // Const array: alias points to ROM
                    asm.push_str(&format!("{}_ARRAYPTR EQU ARRAY_{}_DATA  ; Const array -> ROM\n", 
                        name.to_uppercase(), name.to_uppercase()));
                }
            }
            _ => {}
        }
    }
    
    if has_any_array {
        asm.push_str("\n");
    }
    
    asm
}
