//! Debug builtins for VPy
//!
//! This module provides debug output functions for development and testing:
//! - DEBUG_PRINT(value) - Print value with optional variable label
//! - DEBUG_PRINT_STR(string) - Print string content
//! - PRINT_NUMBER(x, y, num) - Print number at screen position

use vpy_parser::Expr;
use super::expressions;
use crate::AssetInfo;
use std::sync::atomic::{AtomicUsize, Ordering};

// Label counter for unique labels (thread-safe)
static DEBUG_LABEL_COUNTER: AtomicUsize = AtomicUsize::new(0);

fn next_label() -> String {
    let count = DEBUG_LABEL_COUNTER.fetch_add(1, Ordering::Relaxed);
    format!("DEBUG_SKIP_{}", count)
}

/// DEBUG_PRINT(value) - Print value to debug output
/// 
/// Protocol: Writes to $C000-$C005 for IDE to capture:
/// - If variable: Shows "name: value" (marker $FE)
/// - If expression: Shows just value (marker $42)
/// 
/// Memory map:
/// - $C000-$C001: Value (low, high)
/// - $C002: Marker ($FE=labeled, $42=simple)
/// - $C004-$C005: Label pointer (or 0 if no label)
pub fn emit_debug_print(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    if args.is_empty() {
        out.push_str("    ; DEBUG_PRINT: no argument\n");
        out.push_str("    LDD #0\n");
        out.push_str("    STD RESULT\n");
        return;
    }

    // Check if argument is a variable (Ident) to generate labeled output
    let var_name = if let Expr::Ident(id) = &args[0] {
        Some(id.name.clone())
    } else {
        None
    };
    
    // Evaluate expression
    expressions::emit_simple_expr(&args[0], out, assets);
    
    if let Some(name) = var_name {
        // Labeled debug output (show variable name)
        out.push_str(&format!("    ; DEBUG_PRINT({})\n", name));
        let label_name = format!("DEBUG_LABEL_{}", name.to_uppercase());
        let skip_label = next_label();
        
        out.push_str("    LDD RESULT\n");
        out.push_str("    STA $C002\n");      // Store high byte (A) to C002
        out.push_str("    STB $C000\n");      // Store low byte (B) to C000
        out.push_str("    LDA #$FE\n");       // Marker for LABELED debug output
        out.push_str("    STA $C001\n");      // Write marker
        out.push_str(&format!("    LDX #{}\n", label_name));
        out.push_str("    STX $C004\n");      // Store label pointer to C004-C005
        out.push_str(&format!("    BRA {}\n", skip_label));
        
        // Emit label data inline (skipped by BRA)
        out.push_str(&format!("{}:\n", label_name));
        out.push_str(&format!("    FCC \"{}\"\n", name));
        out.push_str("    FCB $00\n");        // Null terminator
        out.push_str(&format!("{}:\n", skip_label));
    } else {
        // Simple debug output (no label)
        out.push_str("    ; DEBUG_PRINT(expression)\n");
        out.push_str("    LDD RESULT\n");
        out.push_str("    STA $C002\n");      // Store high byte (A) to C002
        out.push_str("    STB $C000\n");      // Store low byte (B) to C000
        out.push_str("    LDA #$42\n");       // Marker for simple debug output
        out.push_str("    STA $C001\n");      // Write marker
        out.push_str("    CLR $C003\n");      // Clear label pointer
        out.push_str("    CLR $C005\n");
    }
    
    out.push_str("    LDD #0\n");
    out.push_str("    STD RESULT\n");
}

/// DEBUG_PRINT_STR(string) - Print string content to debug output
/// 
/// Protocol: Writes to $C000-$C005 for IDE to capture:
/// - $C002-$C003: String pointer
/// - $C001: Marker ($FD=string)
/// - $C004-$C005: Variable name label (if variable) or 0
/// 
/// Note: For buildtools simplicity, only supports string variables.
/// String literals should be passed as variables.
pub fn emit_debug_print_str(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    if args.is_empty() {
        out.push_str("    ; DEBUG_PRINT_STR: no argument\n");
        out.push_str("    LDD #0\n");
        out.push_str("    STD RESULT\n");
        return;
    }

    // Variable or expression
    let var_name = if let Expr::Ident(id) = &args[0] {
        Some(id.name.clone())
    } else {
        None
    };
    
    expressions::emit_simple_expr(&args[0], out, assets);
    
    if let Some(name) = var_name {
        out.push_str(&format!("    ; DEBUG_PRINT_STR({})\n", name));
        let label_name = format!("DEBUG_LABEL_{}", name.to_uppercase());
        let skip_label = next_label();
        
        out.push_str("    LDD RESULT\n");
        out.push_str("    STD $C002\n");      // Store string pointer
        out.push_str("    LDA #$FD\n");       // Marker for STRING debug output
        out.push_str("    STA $C001\n");      // Write marker
        out.push_str(&format!("    LDX #{}\n", label_name));
        out.push_str("    STX $C004\n");      // Store label pointer at C004-C005
        out.push_str(&format!("    BRA {}\n", skip_label));
        
        // Emit label data inline
        out.push_str(&format!("{}:\n", label_name));
        out.push_str(&format!("    FCC \"{}\"\n", name));
        out.push_str("    FCB $00\n");
        out.push_str(&format!("{}:\n", skip_label));
    } else {
        // Expression without label
        out.push_str("    ; DEBUG_PRINT_STR(expression)\n");
        out.push_str("    LDD RESULT\n");
        out.push_str("    STD $C002\n");      // Store string pointer
        out.push_str("    LDA #$FD\n");       // Marker for STRING debug output
        out.push_str("    STA $C001\n");      // Write marker
        out.push_str("    CLR $C004\n");      // Clear label pointer
        out.push_str("    CLR $C005\n");
    }
    
    out.push_str("    LDD #0\n");
    out.push_str("    STD RESULT\n");
}

/// PRINT_NUMBER(x, y, num) - Print number at screen position
/// 
/// Converts number to hexadecimal string and displays on screen using BIOS.
/// 
/// Arguments:
/// - x: X position (-127 to 127)
/// - y: Y position (-127 to 127)
/// - num: Number to print (16-bit value, displays as hex)
/// 
/// Uses VAR_ARG0-2 for arguments, calls JSR VECTREX_PRINT_NUMBER helper.
/// The helper converts the low byte to a 2-digit hex string and prints it.
/// 
/// Note: Assumes VAR_ARG0-2 are allocated (requires max_args >= 3 in codegen).
pub fn emit_print_number(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    if args.len() < 3 {
        out.push_str("    ; PRINT_NUMBER: insufficient arguments\n");
        out.push_str("    LDD #0\n");
        out.push_str("    STD RESULT\n");
        return;
    }

    out.push_str("    ; PRINT_NUMBER(x, y, num)\n");
    
    // Evaluate x position
    expressions::emit_simple_expr(&args[0], out, assets);
    out.push_str("    LDD RESULT\n");
    out.push_str("    STD VAR_ARG0    ; X position\n");
    
    // Evaluate y position
    expressions::emit_simple_expr(&args[1], out, assets);
    out.push_str("    LDD RESULT\n");
    out.push_str("    STD VAR_ARG1    ; Y position\n");
    
    // Evaluate number
    expressions::emit_simple_expr(&args[2], out, assets);
    out.push_str("    LDD RESULT\n");
    out.push_str("    STD VAR_ARG2    ; Number value\n");
    
    // Call helper
    out.push_str("    JSR VECTREX_PRINT_NUMBER\n");
    
    out.push_str("    LDD #0\n");
    out.push_str("    STD RESULT\n");
}
