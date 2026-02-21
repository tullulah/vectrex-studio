use vpy_parser::{Module, Item, Expr, Stmt, AssignTarget};
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
            Item::Const { name, type_annotation, .. } => {
                let (bytes, signed) = size_for_annotation(type_annotation);
                context::set_var_size(name, bytes, signed);
                vars.push((name.clone(), bytes));
            }
            _ => {}
        }
    }

    // Collect all identifiers used in functions (parameters and local variables)
    // This includes Stmt::Let items which also have type_annotation
    for item in &module.items {
        if let Item::Function(func) = item {
            // Collect parameters - they are Vec<String>, assume 16-bit default
            for param in &func.params {
                context::set_var_size(param, 2, true);
                vars.push((param.clone(), 2));
            }

            // Collect local variables from function body (including Stmt::Let type_annotations)
            collect_identifiers_from_stmts(&func.body, &mut vars);
        }
    }

    // Allocate all user variables using RamLayout with correct sizes
    let mut seen = HashSet::new();  // Track which variables we've already allocated
    for (var, bytes) in vars.iter() {
        if seen.insert(var.clone()) {
            // First time seeing this variable
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
                        asm.push_str(&format!("    {} 0    ; Element {} (TODO: complex init)\n", directive, i));
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

/// OLD FUNCTION - kept for backward compatibility but not used anymore
/// Use generate_user_variables() instead with RamLayout parameter
pub fn generate_variables(module: &Module) -> Result<String, String> {
    let mut asm = String::new();
    let mut vars = Vec::new();
    let mut arrays = Vec::new();  // Track arrays for data generation

    // Collect all variable names from module (GlobalLet items)
    for item in &module.items {
        if let Item::GlobalLet { name, value, type_annotation, .. } = item {
            let (bytes, signed) = size_for_annotation(type_annotation);
            context::set_var_size(name, bytes, signed);
            vars.push((name.clone(), bytes));

            // Check if this is an array initialization
            if matches!(value, Expr::List(_)) {
                arrays.push((name.clone(), value.clone()));
            }
        }
    }

    // CRITICAL FIX: Also collect all identifiers used in functions
    // This includes function parameters and local variables
    // Treat them all as globals for now (simple solution)
    for item in &module.items {
        if let Item::Function(func) = item {
            // Collect parameters - they are Vec<String> not Vec<Param>
            for param in &func.params {
                context::set_var_size(param, 2, true);
                if !vars.iter().any(|(n, _)| n == param) {
                    vars.push((param.clone(), 2));
                }
            }

            // Collect local variables from function body
            collect_identifiers_from_stmts(&func.body, &mut vars);
        }
    }
    
    // Generate RAM variable definitions
    if !vars.is_empty() {
        asm.push_str(";***************************************************************************\n");
        asm.push_str("; USER VARIABLES\n");
        asm.push_str(";***************************************************************************\n");

        let mut offset = 0;
        let mut seen = HashSet::new();
        for (var, bytes) in vars.iter() {
            if seen.insert(var.clone()) {
                // Variables use uppercase labels for consistency with array/const naming
                asm.push_str(&format!("VAR_{} EQU $CF10+{}\n", var.to_uppercase(), offset));
                offset += bytes;
            }
        }

        asm.push_str("\n");
    }
    
    // Generate array data sections
    // Arrays are stored in ROM as FDB data with ARRAY_{name}_DATA labels
    // At runtime, main() initializes VAR_{name} (RAM pointer) to point to this ROM data
    if !arrays.is_empty() {
        asm.push_str(";***************************************************************************\n");
        asm.push_str("; ARRAY DATA (ROM literals)\n");
        asm.push_str(";***************************************************************************\n");
        asm.push_str("; Arrays are stored in ROM and accessed via pointers\n");
        asm.push_str("; At startup, main() initializes VAR_{name} to point to ARRAY_{name}_DATA\n\n");
        
        // Emit array data in ROM (no ORG - flows naturally after code)
        for (name, value) in arrays {
            if let Expr::List(elements) = value {
                let array_label = format!("ARRAY_{}_DATA", name.to_uppercase());
                asm.push_str(&format!("; Array literal for variable '{}' ({} elements)\n", name, elements.len()));
                asm.push_str(&format!("{}:\n", array_label));
                
                // Emit array elements
                for (i, elem) in elements.iter().enumerate() {
                    if let Expr::Number(n) = elem {
                        asm.push_str(&format!("    FDB {}   ; Element {}\n", n, i));
                    } else {
                        asm.push_str(&format!("    FDB 0    ; Element {} (TODO: complex init)\n", i));
                    }
                }
                asm.push_str("\n");
            }
        }
    }
    
    // NOTE: VAR_ARG definitions moved to Bank #31 (helpers bank) in mod.rs
    // They are emitted alongside helpers because Bank #31 is always visible at $4000-$7FFF
    // This allows all banks to access VAR_ARG without duplication
    // See mod.rs line ~325 for the actual emission
    
    // NOTE: Internal variables (DRAW_VEC_X, MIRROR_Y, etc.) are now allocated via RamLayout in helpers.rs
    // This prevents collisions with scratchpad variables like TEMP_YX
    
    Ok(asm)
}

/// Recursively collect all identifiers from statements, registering their types
/// This captures local variables and any identifiers used in expressions
fn collect_identifiers_from_stmts(stmts: &[Stmt], vars: &mut Vec<(String, usize)>) {
    for stmt in stmts {
        match stmt {
            Stmt::Assign { target, value, .. } => {
                // Collect from assignment target
                match target {
                    AssignTarget::Ident { name, .. } => {
                        if !vars.iter().any(|(n, _)| n == name) {
                            vars.push((name.clone(), 2)); // Default to 16-bit if not already registered
                        }
                    }
                    AssignTarget::Index { target, .. } => {
                        collect_identifiers_from_expr(target, vars);
                    }
                    AssignTarget::FieldAccess { target, .. } => {
                        collect_identifiers_from_expr(target, vars);
                    }
                }

                // Collect from value expression
                collect_identifiers_from_expr(value, vars);
            }
            Stmt::Let { name, type_annotation, value, .. } => {
                let (bytes, signed) = size_for_annotation(type_annotation);
                context::set_var_size(name, bytes, signed);
                vars.push((name.clone(), bytes));
                collect_identifiers_from_expr(value, vars);
            }
            Stmt::If { cond, body, elifs, else_body, .. } => {
                collect_identifiers_from_expr(cond, vars);
                collect_identifiers_from_stmts(body, vars);
                for (elif_cond, elif_body) in elifs {
                    collect_identifiers_from_expr(elif_cond, vars);
                    collect_identifiers_from_stmts(elif_body, vars);
                }
                if let Some(else_stmts) = else_body {
                    collect_identifiers_from_stmts(else_stmts, vars);
                }
            }
            Stmt::While { cond, body, .. } => {
                collect_identifiers_from_expr(cond, vars);
                collect_identifiers_from_stmts(body, vars);
            }
            Stmt::For { var, start, end, step, body, .. } => {
                // For loop variables default to 16-bit if not already registered
                if !vars.iter().any(|(n, _)| n == var) {
                    vars.push((var.clone(), 2));
                }
                collect_identifiers_from_expr(start, vars);
                collect_identifiers_from_expr(end, vars);
                if let Some(step_expr) = step {
                    collect_identifiers_from_expr(step_expr, vars);
                }
                collect_identifiers_from_stmts(body, vars);
            }
            Stmt::ForIn { var, iterable, body, .. } => {
                // ForIn loop variables default to 16-bit if not already registered
                if !vars.iter().any(|(n, _)| n == var) {
                    vars.push((var.clone(), 2));
                }
                collect_identifiers_from_expr(iterable, vars);
                collect_identifiers_from_stmts(body, vars);
            }
            Stmt::Return(value, _) => {
                if let Some(expr) = value {
                    collect_identifiers_from_expr(expr, vars);
                }
            }
            Stmt::Expr(expr, _) => {
                collect_identifiers_from_expr(expr, vars);
            }
            Stmt::CompoundAssign { target, value, .. } => {
                match target {
                    AssignTarget::Ident { name, .. } => {
                        if !vars.iter().any(|(n, _)| n == name) {
                            vars.push((name.clone(), 2)); // Default to 16-bit if not already registered
                        }
                    }
                    AssignTarget::Index { target, .. } => {
                        collect_identifiers_from_expr(target, vars);
                    }
                    AssignTarget::FieldAccess { target, .. } => {
                        collect_identifiers_from_expr(target, vars);
                    }
                }
                collect_identifiers_from_expr(value, vars);
            }
            _ => {}
        }
    }
}

/// Recursively collect identifiers from an expression
fn collect_identifiers_from_expr(expr: &Expr, vars: &mut Vec<(String, usize)>) {
    match expr {
        Expr::Ident(id) => {
            // Only add if not already registered with a size
            if !vars.iter().any(|(n, _)| n == &id.name) {
                vars.push((id.name.clone(), 2)); // Default to 16-bit
            }
        }
        Expr::Binary { left, right, .. } => {
            collect_identifiers_from_expr(left, vars);
            collect_identifiers_from_expr(right, vars);
        }
        Expr::Compare { left, right, .. } => {
            collect_identifiers_from_expr(left, vars);
            collect_identifiers_from_expr(right, vars);
        }
        Expr::Logic { left, right, .. } => {
            collect_identifiers_from_expr(left, vars);
            collect_identifiers_from_expr(right, vars);
        }
        Expr::Not(operand) => {
            collect_identifiers_from_expr(operand, vars);
        }
        Expr::BitNot(operand) => {
            collect_identifiers_from_expr(operand, vars);
        }
        Expr::Call(call_info) => {
            // CallInfo has name field, not func
            for arg in &call_info.args {
                collect_identifiers_from_expr(arg, vars);
            }
        }
        Expr::MethodCall(method_info) => {
            collect_identifiers_from_expr(&method_info.target, vars);
            for arg in &method_info.args {
                collect_identifiers_from_expr(arg, vars);
            }
        }
        Expr::Index { target, index, .. } => {
            collect_identifiers_from_expr(target, vars);
            collect_identifiers_from_expr(index, vars);
        }
        Expr::FieldAccess { target, .. } => {
            collect_identifiers_from_expr(target, vars);
        }
        Expr::List(elements) => {
            for elem in elements {
                collect_identifiers_from_expr(elem, vars);
            }
        }
        _ => {}
    }
}
