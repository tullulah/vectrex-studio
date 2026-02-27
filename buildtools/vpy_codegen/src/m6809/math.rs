//! Math Builtin Functions
//!
//! Basic math operations for VPy

use std::collections::HashSet;
use std::sync::atomic::{AtomicUsize, Ordering};
use vpy_parser::Expr;
use super::expressions;

use crate::AssetInfo;

/// Unique label counter for math labels
static LABEL_COUNTER: AtomicUsize = AtomicUsize::new(0);

pub fn emit_abs(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    if args.len() != 1 {
        out.push_str("    ; ERROR: ABS requires 1 argument\n");
        out.push_str("    LDD #0\n    STD RESULT\n");
        return;
    }
    
    let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
    out.push_str("    ; ABS: Absolute value\n");
    
    // Evaluate argument
    expressions::emit_simple_expr(&args[0], out, assets);
    
    // Check if negative (test high bit of A)
    out.push_str("    LDD RESULT\n");
    out.push_str("    TSTA           ; Test sign bit\n");
    out.push_str(&format!("    BPL .ABS_{}_POS   ; Branch if positive\n", label_id));
    
    // Negative: negate (two's complement)
    out.push_str("    COMA           ; Complement A\n");
    out.push_str("    COMB           ; Complement B\n");
    out.push_str("    ADDD #1        ; Add 1 for two's complement\n");
    
    out.push_str(&format!(".ABS_{}_POS:\n", label_id));
    out.push_str("    STD RESULT\n");
}

pub fn emit_min(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    if args.len() != 2 {
        out.push_str("    ; ERROR: MIN requires 2 arguments\n");
        out.push_str("    LDD #0\n    STD RESULT\n");
        return;
    }
    
    let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
    out.push_str("    ; MIN: Return minimum of two values\n");
    
    // Evaluate first argument -> store in TMPPTR
    expressions::emit_simple_expr(&args[0], out, assets);
    out.push_str("    LDD RESULT\n");
    out.push_str("    STD TMPPTR     ; Save first value\n");
    
    // Evaluate second argument -> RESULT
    expressions::emit_simple_expr(&args[1], out, assets);
    
    // Compare: TMPPTR vs RESULT (signed comparison)
    out.push_str("    LDD TMPPTR     ; Load first value\n");
    out.push_str("    CMPD RESULT    ; Compare with second\n");
    out.push_str(&format!("    BLE .MIN_{}_FIRST ; Branch if first <= second\n", label_id));
    
    // Second is smaller, already in RESULT
    out.push_str(&format!("    BRA .MIN_{}_END\n", label_id));
    
    out.push_str(&format!(".MIN_{}_FIRST:\n", label_id));
    out.push_str("    STD RESULT     ; First is smaller\n");
    
    out.push_str(&format!(".MIN_{}_END:\n", label_id));
}

pub fn emit_max(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    if args.len() != 2 {
        out.push_str("    ; ERROR: MAX requires 2 arguments\n");
        out.push_str("    LDD #0\n    STD RESULT\n");
        return;
    }
    
    let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
    out.push_str("    ; MAX: Return maximum of two values\n");
    
    // Evaluate first argument -> store in TMPPTR
    expressions::emit_simple_expr(&args[0], out, assets);
    out.push_str("    LDD RESULT\n");
    out.push_str("    STD TMPPTR     ; Save first value\n");
    
    // Evaluate second argument -> RESULT
    expressions::emit_simple_expr(&args[1], out, assets);
    
    // Compare: TMPPTR vs RESULT (signed comparison)
    out.push_str("    LDD TMPPTR     ; Load first value\n");
    out.push_str("    CMPD RESULT    ; Compare with second\n");
    out.push_str(&format!("    BGE .MAX_{}_FIRST ; Branch if first >= second\n", label_id));
    
    // Second is larger, already in RESULT
    out.push_str(&format!("    BRA .MAX_{}_END\n", label_id));
    
    out.push_str(&format!(".MAX_{}_FIRST:\n", label_id));
    out.push_str("    STD RESULT     ; First is larger\n");
    
    out.push_str(&format!(".MAX_{}_END:\n", label_id));
}

pub fn emit_clamp(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    if args.len() != 3 {
        out.push_str("    ; ERROR: CLAMP requires 3 arguments (value, min, max)\n");
        out.push_str("    LDD #0\n    STD RESULT\n");
        return;
    }
    
    let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
    out.push_str("    ; CLAMP: Clamp value to range [min, max]\n");
    
    // Evaluate value (arg 0)
    expressions::emit_simple_expr(&args[0], out, assets);
    out.push_str("    LDD RESULT\n");
    out.push_str("    STD TMPPTR     ; Save value\n");
    
    // Evaluate min (arg 1)
    expressions::emit_simple_expr(&args[1], out, assets);
    out.push_str("    LDD RESULT\n");
    out.push_str("    STD TMPPTR+2   ; Save min\n");
    
    // Evaluate max (arg 2)
    expressions::emit_simple_expr(&args[2], out, assets);
    out.push_str("    LDD RESULT\n");
    out.push_str("    STD TMPPTR+4   ; Save max\n");
    
    // Compare value with min
    out.push_str("    LDD TMPPTR     ; Load value\n");
    out.push_str("    CMPD TMPPTR+2  ; Compare with min\n");
    out.push_str(&format!("    BGE .CLAMP_{}_CHK_MAX ; Branch if value >= min\n", label_id));
    
    // Value < min: return min
    out.push_str("    LDD TMPPTR+2\n");
    out.push_str("    STD RESULT\n");
    out.push_str(&format!("    BRA .CLAMP_{}_END\n", label_id));
    
    out.push_str(&format!(".CLAMP_{}_CHK_MAX:\n", label_id));
    // Compare value with max
    out.push_str("    LDD TMPPTR     ; Load value again\n");
    out.push_str("    CMPD TMPPTR+4  ; Compare with max\n");
    out.push_str(&format!("    BLE .CLAMP_{}_OK  ; Branch if value <= max\n", label_id));
    
    // Value > max: return max
    out.push_str("    LDD TMPPTR+4\n");
    out.push_str("    STD RESULT\n");
    out.push_str(&format!("    BRA .CLAMP_{}_END\n", label_id));
    
    out.push_str(&format!(".CLAMP_{}_OK:\n", label_id));
    // Value is in range: return value
    out.push_str("    LDD TMPPTR\n");
    out.push_str("    STD RESULT\n");
    
    out.push_str(&format!(".CLAMP_{}_END:\n", label_id));
}

/// Emit mathematical runtime helpers
/// Only emits helpers that are actually used in the code (tree shaking)
pub fn emit_runtime_helpers(out: &mut String, needed: &HashSet<String>) {
    // MUL16: Multiply X * D -> D
    if needed.contains("MUL16") {
        out.push_str("MUL16:\n");
        out.push_str("    ; Multiply 16-bit X * D -> D\n");
        out.push_str("    ; Simple implementation (can be optimized)\n");
        out.push_str("    PSHS X,B,A\n");
        out.push_str("    LDD #0         ; Result accumulator\n");
        out.push_str("    LDX 2,S        ; Multiplier\n");
        out.push_str(".MUL16_LOOP:\n");
        out.push_str("    BEQ .MUL16_END\n");
        out.push_str("    ADDD ,S        ; Add multiplicand\n");
        out.push_str("    LEAX -1,X\n");
        out.push_str("    BRA .MUL16_LOOP\n");
        out.push_str(".MUL16_END:\n");
        out.push_str("    LEAS 4,S\n");
        out.push_str("    RTS\n\n");
    }
    
    // DIV16: Signed 16-bit division X / D -> D (quotient)
    // Calling convention: X = dividend (signed), D = divisor (signed)
    // Uses TMPVAL (|dividend|), TMPPTR (|divisor|), TMPPTR2 (sign flag)
    // Result returned in D. Also stored in RESULT.
    if needed.contains("DIV16") {
        out.push_str("DIV16:\n");
        out.push_str("    ; Signed 16-bit division: D = X / D\n");
        out.push_str("    ; X = dividend (i16), D = divisor (i16) -> D = quotient\n");
        out.push_str("    STD TMPPTR          ; Save divisor\n");
        out.push_str("    TFR X,D             ; D = dividend (TFR does NOT set flags!)\n");
        out.push_str("    CMPD #0             ; Set flags from FULL D BEFORE any LDA corrupts high byte\n");
        out.push_str("    BPL .D16_DPOS       ; if dividend >= 0, skip negation\n");
        out.push_str("    COMA\n");
        out.push_str("    COMB\n");
        out.push_str("    ADDD #1             ; D = |dividend|\n");
        out.push_str("    STD TMPVAL          ; store |dividend| BEFORE LDA corrupts A (high byte of D)\n");
        out.push_str("    LDA #1\n");
        out.push_str("    STA TMPPTR2         ; sign_flag = 1 (dividend was negative)\n");
        out.push_str("    BRA .D16_RCHECK\n");
        out.push_str(".D16_DPOS:\n");
        out.push_str("    STD TMPVAL          ; dividend is positive, store as-is\n");
        out.push_str("    LDA #0\n");
        out.push_str("    STA TMPPTR2         ; sign_flag = 0 (positive result)\n");
        out.push_str(".D16_RCHECK:\n");
        out.push_str("    LDD TMPPTR          ; D = divisor\n");
        out.push_str("    BPL .D16_RPOS       ; if divisor >= 0, skip negation\n");
        out.push_str("    COMA\n");
        out.push_str("    COMB\n");
        out.push_str("    ADDD #1             ; D = |divisor|\n");
        out.push_str("    STD TMPPTR          ; TMPPTR = |divisor|\n");
        out.push_str("    LDA TMPPTR2\n");
        out.push_str("    EORA #1\n");
        out.push_str("    STA TMPPTR2         ; toggle sign flag (XOR with 1)\n");
        out.push_str(".D16_RPOS:\n");
        out.push_str("    LDD #0\n");
        out.push_str("    STD RESULT          ; quotient = 0\n");
        out.push_str(".D16_LOOP:\n");
        out.push_str("    LDD TMPVAL\n");
        out.push_str("    SUBD TMPPTR         ; |dividend| - |divisor|\n");
        out.push_str("    BLO .D16_END        ; if |dividend| < |divisor|, done\n");
        out.push_str("    STD TMPVAL          ; update remainder\n");
        out.push_str("    LDD RESULT\n");
        out.push_str("    ADDD #1\n");
        out.push_str("    STD RESULT          ; quotient++\n");
        out.push_str("    BRA .D16_LOOP\n");
        out.push_str(".D16_END:\n");
        out.push_str("    LDD RESULT          ; D = unsigned quotient\n");
        out.push_str("    LDA TMPPTR2\n");
        out.push_str("    BEQ .D16_DONE       ; zero = positive result\n");
        out.push_str("    COMA\n");
        out.push_str("    COMB\n");
        out.push_str("    ADDD #1             ; negate for negative result\n");
        out.push_str(".D16_DONE:\n");
        out.push_str("    RTS\n\n");
    }

    // MOD16: Signed 16-bit modulo X % D -> D (remainder, same sign as dividend)
    // Calling convention: X = dividend (signed), D = divisor (signed)
    // Uses TMPVAL (|dividend|), TMPPTR (|divisor|), TMPPTR2 (sign flag)
    out.push_str("MOD16:\n");
    out.push_str("    ; Signed 16-bit modulo: D = X % D (result has same sign as dividend)\n");
    out.push_str("    ; X = dividend (i16), D = divisor (i16) -> D = remainder\n");
    out.push_str("    STD TMPPTR          ; Save divisor\n");
    out.push_str("    TFR X,D             ; D = dividend (TFR does NOT set flags!)\n");
    out.push_str("    CMPD #0             ; Set flags from FULL D BEFORE any LDA corrupts high byte\n");
    out.push_str("    BPL .M16_DPOS       ; if dividend >= 0, skip negation\n");
    out.push_str("    COMA\n");
    out.push_str("    COMB\n");
    out.push_str("    ADDD #1             ; D = |dividend|\n");
    out.push_str("    STD TMPVAL          ; store |dividend| BEFORE LDA corrupts A (high byte of D)\n");
    out.push_str("    LDA #1\n");
    out.push_str("    STA TMPPTR2         ; sign_flag = 1\n");
    out.push_str("    BRA .M16_RCHECK\n");
    out.push_str(".M16_DPOS:\n");
    out.push_str("    STD TMPVAL          ; dividend is positive, store as-is\n");
    out.push_str("    LDA #0\n");
    out.push_str("    STA TMPPTR2         ; sign_flag = 0 (positive result)\n");
    out.push_str(".M16_RCHECK:\n");
    out.push_str("    LDD TMPPTR          ; D = divisor\n");
    out.push_str("    BPL .M16_RPOS       ; if divisor >= 0, skip negation\n");
    out.push_str("    COMA\n");
    out.push_str("    COMB\n");
    out.push_str("    ADDD #1             ; D = |divisor|\n");
    out.push_str("    STD TMPPTR          ; TMPPTR = |divisor|\n");
    out.push_str(".M16_RPOS:\n");
    out.push_str(".M16_LOOP:\n");
    out.push_str("    LDD TMPVAL\n");
    out.push_str("    SUBD TMPPTR         ; |dividend| - |divisor|\n");
    out.push_str("    BLO .M16_END        ; if |dividend| < |divisor|, done\n");
    out.push_str("    STD TMPVAL          ; update remainder\n");
    out.push_str("    BRA .M16_LOOP\n");
    out.push_str(".M16_END:\n");
    out.push_str("    LDD TMPVAL          ; D = |remainder|\n");
    out.push_str("    LDA TMPPTR2\n");
    out.push_str("    BEQ .M16_DONE       ; zero = positive result\n");
    out.push_str("    COMA\n");
    out.push_str("    COMB\n");
    out.push_str("    ADDD #1             ; negate (same sign as dividend)\n");
    out.push_str(".M16_DONE:\n");
    out.push_str("    RTS\n\n");
    
    // SQRT_HELPER: Square root (Newton-Raphson with DIV16)
    if needed.contains("SQRT_HELPER") {
            out.push_str("SQRT_HELPER:\n");
        out.push_str("    ; Input: D = x, Output: D = sqrt(x)\n");
        out.push_str("    ; Newton-Raphson: guess_new = (guess + x/guess) / 2\n");
        out.push_str("    ; Iterate 4 times for convergence\n");
        out.push_str("    \n");
        out.push_str("    ; Handle edge cases\n");
        out.push_str("    CMPD #0\n");
        out.push_str("    BEQ .SQRT_DONE  ; sqrt(0) = 0\n");
        out.push_str("    CMPD #1\n");
        out.push_str("    BEQ .SQRT_DONE  ; sqrt(1) = 1\n");
        out.push_str("    \n");
        out.push_str("    STD TMPPTR      ; Save x\n");
        out.push_str("    ; Initial guess = (x + 1) / 2\n");
        out.push_str("    ADDD #1\n");
        out.push_str("    ASRA            ; Divide by 2\n");
        out.push_str("    RORB\n");
        out.push_str("    STD TMPPTR2     ; guess\n");
        out.push_str("    \n");
        out.push_str("    ; Iterate 4 times\n");
        out.push_str("    LDB #4\n");
        out.push_str("    STB RESULT+1    ; Counter\n");
        out.push_str(".SQRT_LOOP:\n");
        out.push_str("    ; Calculate x/guess using DIV16\n");
        out.push_str("    LDX TMPPTR      ; X = x (dividend)\n");
        out.push_str("    LDD TMPPTR2     ; D = guess (divisor)\n");
        out.push_str("    JSR DIV16       ; D = x/guess\n");
        out.push_str("    \n");
        out.push_str("    ; guess_new = (guess + x/guess) / 2\n");
        out.push_str("    ADDD TMPPTR2    ; D = guess + x/guess\n");
        out.push_str("    ASRA            ; Divide by 2\n");
        out.push_str("    RORB\n");
        out.push_str("    STD TMPPTR2     ; Update guess\n");
        out.push_str("    \n");
        out.push_str("    DEC RESULT+1    ; Decrement counter\n");
        out.push_str("    BNE .SQRT_LOOP\n");
        out.push_str("    \n");
        out.push_str("    LDD TMPPTR2     ; Return final guess\n");
        out.push_str(".SQRT_DONE:\n");
        out.push_str("    RTS\n\n");
    }
    
    // POW_HELPER: Power (base ^ exp)
    if needed.contains("POW_HELPER") {
            out.push_str("POW_HELPER:\n");
        out.push_str("    ; Input: TMPPTR = base, TMPPTR2 = exp, Output: D = result\n");
        out.push_str("    LDD #1         ; result = 1\n");
        out.push_str("    STD RESULT\n");
        out.push_str(".POW_LOOP:\n");
        out.push_str("    LDD TMPPTR2    ; Load exponent\n");
        out.push_str("    BEQ .POW_DONE  ; If exp == 0, done\n");
        out.push_str("    SUBD #1        ; exp--\n");
        out.push_str("    STD TMPPTR2\n");
        out.push_str("    ; result = result * base (simplified: assumes small values)\n");
        out.push_str("    LDD RESULT\n");
        out.push_str("    LDX TMPPTR     ; Load base\n");
        out.push_str("    ; Simple multiplication loop\n");
        out.push_str("    PSHS D\n");
        out.push_str("    LDD #0\n");
        out.push_str(".POW_MUL_LOOP:\n");
        out.push_str("    LEAX -1,X\n");
        out.push_str("    BEQ .POW_MUL_DONE\n");
        out.push_str("    ADDD ,S\n");
        out.push_str("    BRA .POW_MUL_LOOP\n");
        out.push_str(".POW_MUL_DONE:\n");
        out.push_str("    LEAS 2,S\n");
        out.push_str("    STD RESULT\n");
        out.push_str("    BRA .POW_LOOP\n");
        out.push_str(".POW_DONE:\n");
        out.push_str("    LDD RESULT\n");
        out.push_str("    RTS\n\n");
    }
    
    // ATAN2_HELPER: Arctangent (y, x)
    if needed.contains("ATAN2_HELPER") {
            out.push_str("ATAN2_HELPER:\n");
        out.push_str("    ; Input: TMPPTR = y, TMPPTR2 = x, Output: D = angle (0-127)\n");
        out.push_str("    ; Simplified: return approximate angle based on quadrant\n");
        out.push_str("    LDD TMPPTR2    ; Load x\n");
        out.push_str("    BEQ .ATAN2_X_ZERO\n");
        out.push_str("    ; TODO: Full CORDIC implementation\n");
        out.push_str("    ; For now return 0 (placeholder)\n");
        out.push_str("    LDD #0\n");
        out.push_str("    RTS\n");
        out.push_str(".ATAN2_X_ZERO:\n");
        out.push_str("    LDD TMPPTR     ; Load y\n");
        out.push_str("    BPL .ATAN2_Y_POS\n");
        out.push_str("    LDD #96        ; -90 degrees (3/4 of 128)\n");
        out.push_str("    RTS\n");
        out.push_str(".ATAN2_Y_POS:\n");
        out.push_str("    LDD #32        ; +90 degrees (1/4 of 128)\n");
        out.push_str("    RTS\n\n");
    }
    
    // RAND_HELPER: Random number generator (Linear Congruential)
    if needed.contains("RAND_HELPER") {
            out.push_str("RAND_HELPER:\n");
        out.push_str("    ; LCG: seed = (seed * 1103515245 + 12345) & 0x7FFF\n");
        out.push_str("    ; Simplified for 6809: seed = (seed * 25 + 13) & 0x7FFF\n");
        out.push_str("    LDD RAND_SEED\n");
        out.push_str("    LDX #26\n");
        out.push_str("    ; Multiply by 25: loop runs 25 times (LCG a=25, Hull-Dobell ok)\n");
        out.push_str("    PSHS D\n");
        out.push_str("    LDD #0\n");
        out.push_str("RAND_MUL_LOOP:\n");
        out.push_str("    LEAX -1,X\n");
        out.push_str("    BEQ RAND_MUL_DONE\n");
        out.push_str("    ADDD ,S\n");
        out.push_str("    BRA RAND_MUL_LOOP\n");
        out.push_str("RAND_MUL_DONE:\n");
        out.push_str("    LEAS 2,S\n");
        out.push_str("    ADDD #13       ; Add constant c=13 (odd, Hull-Dobell ok)\n");
        out.push_str("    STD RAND_SEED  ; Store full 16-bit state BEFORE masking output\n");
        out.push_str("    ANDA #$7F      ; Mask output to positive 15-bit (state stays full)\n");
        out.push_str("    RTS\n\n");
    }
    
    // RAND_RANGE_HELPER: Random in range [min, max]
    if needed.contains("RAND_RANGE_HELPER") {
        out.push_str("RAND_RANGE_HELPER:\n");
        out.push_str("    ; Input: TMPPTR = min (i16), TMPPTR2 = max (i16)\n");
        out.push_str("    ; Returns: D = min + (rand % (max - min + 1))\n");
        out.push_str("    JSR RAND_HELPER        ; D = rand (0..$7FFF)\n");
        out.push_str("    PSHS D                 ; Save rand\n");
        out.push_str("    LDD TMPPTR2            ; max\n");
        out.push_str("    SUBD TMPPTR            ; D = max - min\n");
        out.push_str("    ADDD #1                ; D = inclusive range\n");
        out.push_str("    STD TMPPTR2            ; TMPPTR2 = range\n");
        out.push_str("    PULS D                 ; Restore rand\n");
        out.push_str("RRH_MOD:\n");
        out.push_str("    SUBD TMPPTR2           ; D -= range\n");
        out.push_str("    BCC RRH_MOD            ; if no borrow (D >= range), keep subtracting\n");
        out.push_str("    ADDD TMPPTR2           ; Undo last subtract: now 0 <= D < range\n");
        out.push_str("    ADDD TMPPTR            ; Add min -> D in [min, max]\n");
        out.push_str("    RTS\n\n");
    }
}
