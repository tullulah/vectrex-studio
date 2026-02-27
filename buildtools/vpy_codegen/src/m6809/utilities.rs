// Utility Builtins for VPy
// Simple utility functions for common tasks

use std::collections::HashSet;
use vpy_parser::Expr;

/// Emit MOVE(x, y) - Move beam to position without drawing
/// 
/// Parameters:
/// - x: X coordinate (-127 to 127)
/// - y: Y coordinate (-127 to 127)
/// 
/// Uses BIOS Moveto_d_7F
pub fn emit_move(args: &[Expr], out: &mut String) {
    out.push_str("    ; ===== MOVE builtin =====\n");
    
    if args.len() != 2 {
        out.push_str("    ; ERROR: MOVE requires 2 arguments (x, y)\n");
        out.push_str("    LDD #0\n");
        out.push_str("    STD RESULT\n");
        return;
    }
    
    // Store MOVE offset in VPY_MOVE_X / VPY_MOVE_Y RAM bytes
    if let (Expr::Number(x), Expr::Number(y)) = (&args[0], &args[1]) {
        out.push_str(&format!("    LDA #${:02X}                ; X coordinate\n", (*x as i8) as u8));
        out.push_str("    STA VPY_MOVE_X\n");
        out.push_str(&format!("    LDA #${:02X}                ; Y coordinate\n", (*y as i8) as u8));
        out.push_str("    STA VPY_MOVE_Y\n");
    } else {
        // Variable args: evaluate each and store low byte
        out.push_str("    ; TODO: variable MOVE args (store expressions)\n");
    }
    
    out.push_str("    LDD #0\n");
    out.push_str("    STD RESULT\n");
}

/// Emit LEN(array) - Get array length
/// 
/// For now, returns size from array metadata (stored at array_ptr - 2)
/// 
/// Note: This is a placeholder - proper implementation needs:
/// - Array metadata tracking
/// - String length calculation
/// - Variable length extraction
pub fn emit_len(args: &[Expr], out: &mut String) {
    out.push_str("    ; ===== LEN builtin =====\n");
    
    if args.len() != 1 {
        out.push_str("    ; ERROR: LEN requires 1 argument (array or string)\n");
        out.push_str("    LDD #0\n");
        out.push_str("    STD RESULT\n");
        return;
    }
    
    // Placeholder - always return 0 for now
    out.push_str("    ; TODO: Implement array/string length extraction\n");
    out.push_str("    ; Needs metadata tracking in array system\n");
    out.push_str("    LDD #0                 ; Placeholder return\n");
    out.push_str("    STD RESULT\n");
}

/// Emit GET_TIME() - Get frame counter
/// 
/// Returns number of frames elapsed since boot.
/// Uses VIA timer or internal counter.
/// 
/// For now, returns placeholder 0 (needs timer integration)
pub fn emit_get_time(_args: &[Expr], out: &mut String) {
    out.push_str("    ; ===== GET_TIME builtin =====\n");
    out.push_str("    ; TODO: Integrate with VIA timer or frame counter\n");
    out.push_str("    LDD FRAME_COUNTER      ; Placeholder - needs initialization\n");
    out.push_str("    STD RESULT\n");
}

/// Emit PEEK(addr) - Read byte from memory address
/// 
/// Parameters:
/// - addr: Memory address (0-65535)
/// 
/// Returns: Byte value at address (0-255)
pub fn emit_peek(args: &[Expr], out: &mut String) {
    out.push_str("    ; ===== PEEK builtin =====\n");
    
    if args.len() != 1 {
        out.push_str("    ; ERROR: PEEK requires 1 argument (address)\n");
        out.push_str("    LDD #0\n");
        out.push_str("    STD RESULT\n");
        return;
    }
    
    // Check if address is constant
    if let Expr::Number(addr) = &args[0] {
        out.push_str(&format!("    LDA ${:04X}             ; Read from address\n", addr));
        out.push_str("    CLR RESULT             ; Clear high byte\n");
        out.push_str("    STA RESULT+1           ; Store low byte\n");
    } else {
        out.push_str("    ; TODO: Support variable address\n");
        out.push_str("    LDD #0\n");
        out.push_str("    STD RESULT\n");
    }
}

/// Emit POKE(addr, value) - Write byte to memory address
/// 
/// Parameters:
/// - addr: Memory address (0-65535)
/// - value: Byte value (0-255)
/// 
/// WARNING: Direct memory access - can corrupt system state!
pub fn emit_poke(args: &[Expr], out: &mut String) {
    out.push_str("    ; ===== POKE builtin =====\n");
    
    if args.len() != 2 {
        out.push_str("    ; ERROR: POKE requires 2 arguments (address, value)\n");
        out.push_str("    LDD #0\n");
        out.push_str("    STD RESULT\n");
        return;
    }
    
    // Check if both arguments are constants
    if let (Expr::Number(addr), Expr::Number(value)) = (&args[0], &args[1]) {
        out.push_str(&format!("    LDA #{}                ; Value to write\n", value));
        out.push_str(&format!("    STA ${:04X}             ; Write to address\n", addr));
    } else {
        out.push_str("    ; TODO: Support variable address/value\n");
    }
    
    out.push_str("    LDD #0\n");
    out.push_str("    STD RESULT\n");
}

/// Emit WAIT(frames) - Wait for N frames
/// 
/// Parameters:
/// - frames: Number of frames to wait (1-255)
/// 
/// Calls WAIT_RECAL() N times
pub fn emit_wait(args: &[Expr], out: &mut String) {
    out.push_str("    ; ===== WAIT builtin =====\n");
    
    if args.len() != 1 {
        out.push_str("    ; ERROR: WAIT requires 1 argument (frames)\n");
        out.push_str("    LDD #0\n");
        out.push_str("    STD RESULT\n");
        return;
    }
    
    // Check if frames is constant
    if let Expr::Number(frames) = &args[0] {
        if *frames <= 10 {
            // Inline for small counts
            for _ in 0..*frames {
                out.push_str("    JSR Wait_Recal\n");
            }
        } else {
            // Use loop for larger counts
            out.push_str(&format!("    LDA #{}                ; Frame counter\n", frames));
            out.push_str("WAIT_LOOP:\n");
            out.push_str("    PSHS A\n");
            out.push_str("    JSR Wait_Recal\n");
            out.push_str("    PULS A\n");
            out.push_str("    DECA\n");
            out.push_str("    BNE WAIT_LOOP\n");
        }
    } else {
        out.push_str("    ; TODO: Support variable frame count\n");
    }
    
    out.push_str("    LDD #0\n");
    out.push_str("    STD RESULT\n");
}

/// Emit BEEP(frequency, duration) - Generate sound (non-blocking)
///
/// Parameters:
/// - frequency: PSG period value (0-255); higher = lower pitch. 50 ≈ ~1.8kHz
/// - duration: Duration in frames (1-255); timer decremented by BEEP_UPDATE_RUNTIME
///
/// Non-blocking: sets PSG registers and BEEP_FRAMES_LEFT counter, then returns.
/// BEEP_UPDATE_RUNTIME (auto-injected at LOOP_BODY start) mutes PSG when timer expires.
/// No busy-wait = no frame blanking = no screen flicker.
pub fn emit_beep(args: &[Expr], out: &mut String) {
    out.push_str("    ; ===== BEEP builtin (non-blocking) =====\n");

    // Resolve (freq, dur): 0 args = defaults, 2 const args = explicit
    let (freq, dur): (i32, i32) = if args.is_empty() {
        (50, 8)
    } else if args.len() == 2 {
        if let (Expr::Number(f), Expr::Number(d)) = (&args[0], &args[1]) {
            (*f, *d)
        } else {
            out.push_str("    ; TODO: Support variable frequency/duration\n");
            out.push_str("    LDD #0\n    STD RESULT\n");
            return;
        }
    } else {
        out.push_str("    ; ERROR: BEEP requires 0 or 2 arguments\n");
        out.push_str("    LDD #0\n    STD RESULT\n");
        return;
    };

    // Use Sound_Byte BIOS call for proper VIA-mediated PSG writes
    out.push_str("    PSHS DP\n");
    out.push_str("    LDA #$D0\n");
    out.push_str("    TFR A,DP            ; DP=$D0 for Sound_Byte\n");
    out.push_str("    LDA #0              ; PSG reg 0 = freq low\n");
    out.push_str(&format!("    LDB #{}             ; frequency period ({})\n", freq & 0xFF, freq & 0xFF));
    out.push_str("    JSR Sound_Byte\n");
    out.push_str("    LDA #1              ; PSG reg 1 = freq high\n");
    out.push_str("    LDB #0\n");
    out.push_str("    JSR Sound_Byte\n");
    out.push_str("    LDA #7              ; PSG reg 7 = mixer\n");
    out.push_str("    LDB #$3E            ; Enable tone A, disable noise\n");
    out.push_str("    JSR Sound_Byte\n");
    out.push_str("    LDA #8              ; PSG reg 8 = volume A\n");
    out.push_str("    LDB #15             ; Max volume\n");
    out.push_str("    JSR Sound_Byte\n");
    out.push_str("    PULS DP             ; Restore DP=$C8\n");
    // Set timer - BEEP_UPDATE_RUNTIME will mute PSG after this many frames
    out.push_str(&format!("    LDA #{}             ; Beep duration: {} frames\n", dur, dur));
    out.push_str("    STA >BEEP_FRAMES_LEFT\n");
    out.push_str("    LDD #0\n");
    out.push_str("    STD RESULT\n");
}


/// Emit runtime helpers for utilities builtins
/// Only emits helpers that are actually used in the code (tree shaking)
pub fn emit_runtime_helpers(_out: &mut String, _needed: &HashSet<String>) {
    // No utility runtime helpers currently needed
}
