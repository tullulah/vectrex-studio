//! Joystick Input Runtime Helpers
//!
//! Handles analog joystick input from Vectrex hardware
//! Uses BIOS Joy_Analog ($F1F5) for hardware compatibility
//! 
//! IMPORTANT: Joystick mux must be initialized ONCE in START/MAIN before use.
//! These builtins assume mux is already configured.

use std::collections::HashSet;

/// Emit joystick runtime helpers
/// Only emits helpers that are actually used in the code (tree shaking)
/// 
/// COPIED EXACTLY from core/src/backend/m6809/emission.rs lines 77-102
pub fn emit_runtime_helpers(out: &mut String, needed: &HashSet<String>) {
    // J1X_BUILTIN: Joystick 1 X axis (INCREMENTAL - with state preservation)
    // Based on core emission.rs but with VIA restoration after Joy_Analog
    if needed.contains("J1X_BUILTIN") {
        out.push_str("; === JOYSTICK BUILTIN SUBROUTINES ===\n");
        out.push_str("; J1_X() - Read Joystick 1 X axis (INCREMENTAL - with state preservation)\n");
        out.push_str("; Returns: D = raw value from $C81B after Joy_Analog call\n");
        out.push_str("J1X_BUILTIN:\n");
        out.push_str("    PSHS X       ; Save X (Joy_Analog uses it)\n");
        out.push_str("    JSR $F1AA    ; DP_to_D0 (required for Joy_Analog BIOS call)\n");
        out.push_str("    JSR $F1F5    ; Joy_Analog (updates $C81B from hardware)\n");
        out.push_str("    JSR Reset0Int ; Restore integrators to zero (Joy_Analog leaves them at joystick pos)\n");
        out.push_str("    JSR $F1AF    ; DP_to_C8 (required to read RAM $C81B)\n");
        out.push_str("    LDB $C81B    ; Vec_Joy_1_X (BIOS writes ~$FE at center)\n");
        out.push_str("    SEX          ; Sign-extend B to D\n");
        out.push_str("    ADDD #2      ; Calibrate center offset\n");
        out.push_str("    PULS X       ; Restore X\n");
        out.push_str("    RTS\n\n");
    }
    
    // J1Y_BUILTIN: Joystick 1 Y axis (INCREMENTAL - with state preservation)
    // Based on core emission.rs but with VIA restoration after Joy_Analog
    if needed.contains("J1Y_BUILTIN") {
        out.push_str("; J1_Y() - Read Joystick 1 Y axis (INCREMENTAL - with state preservation)\n");
        out.push_str("; Returns: D = raw value from $C81C after Joy_Analog call\n");
        out.push_str("J1Y_BUILTIN:\n");
        out.push_str("    PSHS X       ; Save X (Joy_Analog uses it)\n");
        out.push_str("    JSR $F1AA    ; DP_to_D0 (required for Joy_Analog BIOS call)\n");
        out.push_str("    JSR $F1F5    ; Joy_Analog (updates $C81C from hardware)\n");
        out.push_str("    JSR Reset0Int ; Restore integrators to zero (Joy_Analog leaves them at joystick pos)\n");
        out.push_str("    JSR $F1AF    ; DP_to_C8 (required to read RAM $C81C)\n");
        out.push_str("    LDB $C81C    ; Vec_Joy_1_Y (BIOS writes ~$FE at center)\n");
        out.push_str("    SEX          ; Sign-extend B to D\n");
        out.push_str("    ADDD #2      ; Calibrate center offset\n");
        out.push_str("    PULS X       ; Restore X\n");
        out.push_str("    RTS\n\n");
    }
    
    // J2X_BUILTIN: Joystick 2 X axis (BIOS - hardware compatible)
    if needed.contains("J2X_BUILTIN") {
        out.push_str("; J2_X() - Read Joystick 2 X axis (BIOS Joy_Analog)\n");
        out.push_str("J2X_BUILTIN:\n");
        out.push_str("    PSHS X       ; Save X\n");
        out.push_str("    JSR $F1AA    ; DP_to_D0\n");
        out.push_str("    JSR $F1F5    ; Joy_Analog\n");
        out.push_str("    JSR $F1AF    ; DP_to_C8\n");
        out.push_str("    LDB $C81D    ; Vec_Joy_2_X\n");
        out.push_str("    SEX          ; Sign-extend B to D\n");
        out.push_str("    ADDD #2      ; Calibrate center offset\n");
        out.push_str("    PULS X       ; Restore X\n");
        out.push_str("    RTS\n\n");
    }
    
    // J2Y_BUILTIN: Joystick 2 Y axis (BIOS - hardware compatible)
    if needed.contains("J2Y_BUILTIN") {
        out.push_str("; J2_Y() - Read Joystick 2 Y axis (BIOS Joy_Analog)\n");
        out.push_str("J2Y_BUILTIN:\n");
        out.push_str("    PSHS X       ; Save X\n");
        out.push_str("    JSR $F1AA    ; DP_to_D0\n");
        out.push_str("    JSR $F1F5    ; Joy_Analog\n");
        out.push_str("    JSR $F1AF    ; DP_to_C8\n");
        out.push_str("    LDB $C81E    ; Vec_Joy_2_Y\n");
        out.push_str("    SEX          ; Sign-extend B to D\n");
        out.push_str("    ADDD #2      ; Calibrate center offset\n");
        out.push_str("    PULS X       ; Restore X\n");
        out.push_str("    RTS\n\n");
    }
}

/// Emit joystick initialization code (ONCE in MAIN/startup)
/// COPIED from core/src/backend/m6809/mod.rs lines 834-849
pub fn emit_joystick_init(out: &mut String) {
    out.push_str("    ; === Initialize Joystick (one-time setup) ===\n");
    out.push_str("    JSR $F1AF    ; DP_to_C8 (required for RAM access)\n");
    out.push_str("    CLR $C823    ; CRITICAL: Clear analog mode flag (Joy_Analog does DEC on this)\n");
    out.push_str("    LDA #$01     ; CRITICAL: Resolution threshold (power of 2: $40=fast, $01=accurate)\n");
    out.push_str("    STA $C81A    ; Vec_Joy_Resltn (loop terminates when B=this value after LSRBs)\n");
    out.push_str("    LDA #$01\n");
    out.push_str("    STA $C81F    ; Vec_Joy_Mux_1_X (enable X axis reading)\n");
    out.push_str("    LDA #$03\n");
    out.push_str("    STA $C820    ; Vec_Joy_Mux_1_Y (enable Y axis reading)\n");
    out.push_str("    LDA #$00\n");
    out.push_str("    STA $C821    ; Vec_Joy_Mux_2_X (disable joystick 2 - CRITICAL!)\n");
    out.push_str("    STA $C822    ; Vec_Joy_Mux_2_Y (disable joystick 2 - saves cycles)\n");
    out.push_str("    ; Mux configured - J1_X()/J1_Y() can now be called\n\n");
}
