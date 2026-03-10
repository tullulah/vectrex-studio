//! Extended Math Functions
//!
//! Advanced math operations:
//! - SIN, COS, TAN: Trigonometry (lookup tables)
//! - SQRT: Square root (Newton-Raphson approximation)
//! - POW: Power (repeated multiplication)
//! - ATAN2: Arctangent (CORDIC-style approximation)
//! - RAND: Random number generator (Linear Congruential)
//! - RAND_RANGE: Random in range

use vpy_parser::Expr;
use super::expressions;
use crate::AssetInfo;

/// Generates trigonometry lookup tables
/// 
/// Tables contain 128 entries (0-127 representing 0-360 degrees)
/// Values are signed 16-bit (-127 to +127 for SIN/COS)
pub fn generate_trig_tables() -> String {
    let mut asm = String::new();
    
    asm.push_str(";***************************************************************************\n");
    asm.push_str("; TRIGONOMETRY LOOKUP TABLES (128 entries each)\n");
    asm.push_str(";***************************************************************************\n");
    
    // Generate SIN table (0-127 angles, values -127 to +127)
    asm.push_str("SIN_TABLE:\n");
    for i in 0..128 {
        let angle = (i as f32) * std::f32::consts::TAU / 128.0;
        let value = (angle.sin() * 127.0).round() as i16;
        asm.push_str(&format!("    FDB {}    ; angle {}\n", value, i));
    }
    asm.push_str("\n");
    
    // Generate COS table
    asm.push_str("COS_TABLE:\n");
    for i in 0..128 {
        let angle = (i as f32) * std::f32::consts::TAU / 128.0;
        let value = (angle.cos() * 127.0).round() as i16;
        asm.push_str(&format!("    FDB {}    ; angle {}\n", value, i));
    }
    asm.push_str("\n");
    
    // Generate TAN table (clamped to ±120 to avoid overflow)
    asm.push_str("TAN_TABLE:\n");
    for i in 0..128 {
        let angle = (i as f32) * std::f32::consts::TAU / 128.0;
        let tan_val = angle.tan();
        let value = if tan_val.is_finite() {
            (tan_val.clamp(-6.0, 6.0) * 20.0).round() as i16
        } else {
            0  // Vertical asymptote
        };
        asm.push_str(&format!("    FDB {}    ; angle {}\n", value, i));
    }
    asm.push_str("\n");
    
    asm
}

/// SIN(angle) - Sine lookup (angle 0-127 represents 0-360°)
pub fn emit_sin(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    if args.is_empty() {
        out.push_str("    ; SIN: no argument\n");
        out.push_str("    LDD #0\n    STD RESULT\n");
        return;
    }
    
    out.push_str("    ; SIN: Sine lookup\n");
    
    // Evaluate angle; D = angle after emit
    expressions::emit_simple_expr(&args[0], out, assets);

    // Mask to 0-127 range
    out.push_str("    ANDB #$7F      ; Mask to 0-127\n");
    out.push_str("    CLRA           ; Clear high byte\n");
    
    // Multiply by 2 (table entries are 2 bytes)
    out.push_str("    ASLB\n");
    out.push_str("    ROLA\n");
    
    // Load from table
    out.push_str("    LDX #SIN_TABLE\n");
    out.push_str("    ABX            ; Add offset to table base\n");
    out.push_str("    LDD ,X         ; Load 16-bit value\n");
    out.push_str("    STD RESULT\n");
}

/// COS(angle) - Cosine lookup
pub fn emit_cos(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    if args.is_empty() {
        out.push_str("    ; COS: no argument\n");
        out.push_str("    LDD #0\n    STD RESULT\n");
        return;
    }
    
    out.push_str("    ; COS: Cosine lookup\n");
    
    expressions::emit_simple_expr(&args[0], out, assets);

    out.push_str("    ANDB #$7F\n");
    out.push_str("    CLRA\n");
    out.push_str("    ASLB\n");
    out.push_str("    ROLA\n");
    out.push_str("    LDX #COS_TABLE\n");
    out.push_str("    ABX\n");
    out.push_str("    LDD ,X\n");
    out.push_str("    STD RESULT\n");
}

/// TAN(angle) - Tangent lookup
pub fn emit_tan(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    if args.is_empty() {
        out.push_str("    ; TAN: no argument\n");
        out.push_str("    LDD #0\n    STD RESULT\n");
        return;
    }
    
    out.push_str("    ; TAN: Tangent lookup\n");
    
    expressions::emit_simple_expr(&args[0], out, assets);

    out.push_str("    ANDB #$7F\n");
    out.push_str("    CLRA\n");
    out.push_str("    ASLB\n");
    out.push_str("    ROLA\n");
    out.push_str("    LDX #TAN_TABLE\n");
    out.push_str("    ABX\n");
    out.push_str("    LDD ,X\n");
    out.push_str("    STD RESULT\n");
}

/// SQRT(x) - Square root (Newton-Raphson approximation)
/// 
/// Simple implementation using successive approximation:
/// result = (x + 1) >> 1  (initial guess)
/// for 4 iterations: result = (result + x/result) >> 1
pub fn emit_sqrt(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    if args.is_empty() {
        out.push_str("    ; SQRT: no argument\n");
        out.push_str("    LDD #0\n    STD RESULT\n");
        return;
    }
    
    out.push_str("    ; SQRT: Square root (Newton-Raphson)\n");
    
    // Evaluate x; D = x after emit
    expressions::emit_simple_expr(&args[0], out, assets);

    // Call helper (D passes value directly)
    out.push_str("    JSR SQRT_HELPER\n");
    out.push_str("    STD RESULT\n");
}

/// POW(base, exp) - Power (repeated multiplication)
pub fn emit_pow(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    if args.len() < 2 {
        out.push_str("    ; POW: insufficient arguments\n");
        out.push_str("    LDD #0\n    STD RESULT\n");
        return;
    }
    
    out.push_str("    ; POW: Power (base ^ exp)\n");
    
    // Evaluate base; D = base after emit
    expressions::emit_simple_expr(&args[0], out, assets);
    out.push_str("    STD TMPPTR     ; Save base\n");

    // Evaluate exponent; D = exp after emit
    expressions::emit_simple_expr(&args[1], out, assets);
    out.push_str("    STD TMPPTR2    ; Save exponent\n");
    
    // Call helper
    out.push_str("    JSR POW_HELPER\n");
    out.push_str("    STD RESULT\n");
}

/// ATAN2(y, x) - Arctangent (CORDIC-style approximation)
pub fn emit_atan2(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    if args.len() < 2 {
        out.push_str("    ; ATAN2: insufficient arguments\n");
        out.push_str("    LDD #0\n    STD RESULT\n");
        return;
    }
    
    out.push_str("    ; ATAN2: Arctangent (y, x)\n");
    
    // Evaluate y; D = y after emit
    expressions::emit_simple_expr(&args[0], out, assets);
    out.push_str("    STD TMPPTR     ; Save y\n");

    // Evaluate x; D = x after emit
    expressions::emit_simple_expr(&args[1], out, assets);
    out.push_str("    STD TMPPTR2    ; Save x\n");
    
    // Call helper
    out.push_str("    JSR ATAN2_HELPER\n");
    out.push_str("    STD RESULT\n");
}

/// RAND() - Random number generator (Linear Congruential)
/// 
/// Uses formula: seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
/// Returns 16-bit positive random value (0-32767)
pub fn emit_rand(out: &mut String, _assets: &[AssetInfo]) {
    out.push_str("    ; RAND: Random number generator\n");
    out.push_str("    JSR RAND_HELPER\n");
    out.push_str("    STD RESULT\n");
}

/// RAND_RANGE(min, max) - Random number in range [min, max]
pub fn emit_rand_range(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    if args.len() < 2 {
        out.push_str("    ; RAND_RANGE: insufficient arguments\n");
        out.push_str("    LDD #0\n    STD RESULT\n");
        return;
    }
    
    out.push_str("    ; RAND_RANGE: Random in range [min, max]\n");
    
    // Evaluate min; D = min after emit
    expressions::emit_simple_expr(&args[0], out, assets);
    out.push_str("    STD TMPPTR     ; Save min\n");

    // Evaluate max; D = max after emit
    expressions::emit_simple_expr(&args[1], out, assets);
    out.push_str("    STD TMPPTR2    ; Save max\n");
    
    // Call helper
    out.push_str("    JSR RAND_RANGE_HELPER\n");
    out.push_str("    STD RESULT\n");
}
