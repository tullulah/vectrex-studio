//! Builtin Functions for M6809
//!
//! Essential builtins:
//! - PRINT_TEXT: Print text at position
//! - DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
//! - WAIT_RECAL: Wait for screen refresh
//! - SET_INTENSITY: Set drawing intensity

use vpy_parser::{Expr, Module};
use super::expressions;
use super::math;
use super::debug;
use super::math_extended;
use super::drawing;
use super::level;
use super::utilities;
use crate::{AssetInfo, AssetType};
use crate::vecres::VecResource;
use std::sync::atomic::{AtomicUsize, AtomicBool, Ordering};

/// Unique label counter for builtin function labels
static LABEL_COUNTER: AtomicUsize = AtomicUsize::new(0);

/// Flag indicating if we're generating code for multibank ROM
/// When true, asset references use banked access (DRAW_VECTOR_BANKED, PLAY_MUSIC_BANKED)
static IS_MULTIBANK: AtomicBool = AtomicBool::new(false);

/// Flag indicating if assets are distributed across banks (requires bank switching)
/// This is separate from IS_MULTIBANK because small assets stay in Bank #0 even in multibank mode
static USE_BANKED_ASSETS: AtomicBool = AtomicBool::new(false);

/// Set multibank mode for code generation
pub fn set_multibank_mode(multibank: bool) {
    IS_MULTIBANK.store(multibank, Ordering::SeqCst);
}

/// Set banked assets mode (called when assets are actually distributed)
pub fn set_banked_assets_mode(banked: bool) {
    USE_BANKED_ASSETS.store(banked, Ordering::SeqCst);
}

/// Check if we're in multibank mode
pub fn is_multibank() -> bool {
    IS_MULTIBANK.load(Ordering::SeqCst)
}

/// Check if assets require bank switching (distributed across banks)
pub fn use_banked_assets() -> bool {
    USE_BANKED_ASSETS.load(Ordering::SeqCst)
}

/// Builtin function arities (COPIED FROM core/src/codegen.rs)
/// This table defines the expected number of arguments for each builtin
static BUILTIN_ARITIES: &[(&str, usize)] = &[
    // Core display builtins
    ("PRINT_TEXT", 3),      // x, y, string (3 args) OR x, y, string, height, width (5 args - handled specially)
    ("PRINT_NUMBER", 3),    // x, y, number
    ("DRAW_LINE", 5),       // x0, y0, x1, y1, intensity
    ("DRAW_RECT", 5),       // x, y, width, height, intensity
    ("SET_INTENSITY", 1),   // intensity
    ("RESET0REF", 0),       // no args
    
    // Vector asset functions
    ("DRAW_VECTOR", 3),     // name, x, y
    ("DRAW_VECTOR_EX", 5),  // name, x, y, mirror, intensity
    
    // Audio functions
    ("PLAY_MUSIC", 1),      // name
    ("PLAY_SFX", 1),        // name
    ("STOP_MUSIC", 0),      // no args
    ("AUDIO_UPDATE", 0),    // no args
    ("MUSIC_UPDATE", 0),    // no args (deprecated)
    
    // Joystick input
    ("J1_X", 0),            // no args
    ("J1_Y", 0),            // no args
    ("J1_BUTTON_1", 0),     // no args
    ("J1_BUTTON_2", 0),     // no args
    ("J1_BUTTON_3", 0),     // no args
    ("J1_BUTTON_4", 0),     // no args
    ("UPDATE_BUTTONS", 0),  // no args
    
    // Math functions
    ("ABS", 1),             // value
    ("MIN", 2),             // a, b
    ("MAX", 2),             // a, b
    
    // Debug functions
    ("DEBUG_PRINT", 1),           // value
    ("DEBUG_PRINT_LABELED", 2),   // label, value
    ("DEBUG_PRINT_STR", 1),       // string
];

/// Get expected arity for a builtin (None if not a builtin)
fn expected_builtin_arity(name: &str) -> Option<usize> {
    let upper = name.to_ascii_uppercase();
    let core = if let Some(stripped) = upper.strip_prefix("VECTREX_") { 
        stripped 
    } else { 
        upper.as_str() 
    };
    
    for (n, a) in BUILTIN_ARITIES {
        if *n == core {
            return Some(*a);
        }
    }
    None
}

/// Validate builtin arity before emission
fn validate_builtin_arity(name: &str, arg_count: usize) -> Result<(), String> {
    let upper = name.to_ascii_uppercase();
    
    // Special cases with variable arity
    match upper.as_str() {
        "PRINT_TEXT" => {
            if arg_count != 3 && arg_count != 5 {
                return Err(format!("PRINT_TEXT requires 3 or 5 arguments, got {}", arg_count));
            }
            return Ok(());
        }
        _ => {}
    }
    
    // Fixed arity validation
    if let Some(expected) = expected_builtin_arity(name) {
        if arg_count != expected {
            return Err(format!(
                "{} requires exactly {} argument{}, got {}",
                upper,
                expected,
                if expected == 1 { "" } else { "s" },
                arg_count
            ));
        }
    }
    
    Ok(())
}

/// Check if function is a builtin and emit code
pub fn emit_builtin(
    name: &str,
    args: &[Expr],
    out: &mut String,
    assets: &[AssetInfo],
) -> bool {
    let up = name.to_ascii_uppercase();
    
    // CRITICAL: Validate arity BEFORE emitting any code
    if let Err(error) = validate_builtin_arity(name, args.len()) {
        panic!("Builtin arity error: {}", error);
    }
    
    match up.as_str() {
        // ===== Core Display Builtins =====
        "SET_INTENSITY" => {
            emit_set_intensity(args, out, assets);
            true
        }
        "PRINT_TEXT" => {
            emit_print_text(args, out, assets);
            true
        }
        "DRAW_LINE" => {
            emit_draw_line(args, out, assets);
            true
        }
        
        // ===== Joystick Input =====
        "J1_X" => {
            out.push_str("    JSR J1X_BUILTIN\n");
            out.push_str("    STD RESULT\n");
            true
        }
        "J1_Y" => {
            out.push_str("    JSR J1Y_BUILTIN\n");
            out.push_str("    STD RESULT\n");
            true
        }
        "UPDATE_BUTTONS" => {
            out.push_str("    JSR $F1AA     ; DP_to_D0\n");
            out.push_str("    JSR $F1BA     ; Read_Btns\n");
            out.push_str("    JSR $F1AF     ; DP_to_C8\n");
            out.push_str("    LDD #0\n");
            out.push_str("    STD RESULT\n");
            true
        }
        "J1_BUTTON_1" => {
            let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
            out.push_str("    LDA $C811      ; Vec_Button_1_1 (transition bits, rising edge = debounce)\n");
            out.push_str("    ANDA #$01      ; Test bit 0 (Button 1)\n");
            out.push_str(&format!("    LBEQ .J1B1_{}_OFF\n", label_id));
            out.push_str("    LDD #1\n");
            out.push_str(&format!("    LBRA .J1B1_{}_END\n", label_id));
            out.push_str(&format!(".J1B1_{}_OFF:\n", label_id));
            out.push_str("    LDD #0\n");
            out.push_str(&format!(".J1B1_{}_END:\n", label_id));
            out.push_str("    STD RESULT\n");
            true
        }
        "J1_BUTTON_2" => {
            let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
            out.push_str("    LDA $C811      ; Vec_Button_1_1 (transition bits, rising edge = debounce)\n");
            out.push_str("    ANDA #$02      ; Test bit 1 (Button 2)\n");
            out.push_str(&format!("    LBEQ .J1B2_{}_OFF\n", label_id));
            out.push_str("    LDD #1\n");
            out.push_str(&format!("    LBRA .J1B2_{}_END\n", label_id));
            out.push_str(&format!(".J1B2_{}_OFF:\n", label_id));
            out.push_str("    LDD #0\n");
            out.push_str(&format!(".J1B2_{}_END:\n", label_id));
            out.push_str("    STD RESULT\n");
            true
        }
        "J1_BUTTON_3" => {
            let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
            out.push_str("    LDA $C811      ; Vec_Button_1_1 (transition bits, rising edge = debounce)\n");
            out.push_str("    ANDA #$04      ; Test bit 2 (Button 3)\n");
            out.push_str(&format!("    LBEQ .J1B3_{}_OFF\n", label_id));
            out.push_str("    LDD #1\n");
            out.push_str(&format!("    LBRA .J1B3_{}_END\n", label_id));
            out.push_str(&format!(".J1B3_{}_OFF:\n", label_id));
            out.push_str("    LDD #0\n");
            out.push_str(&format!(".J1B3_{}_END:\n", label_id));
            out.push_str("    STD RESULT\n");
            true
        }
        "J1_BUTTON_4" => {
            let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
            out.push_str("    LDA $C811      ; Vec_Button_1_1 (transition bits, rising edge = debounce)\n");
            out.push_str("    ANDA #$08      ; Test bit 3 (Button 4)\n");
            out.push_str(&format!("    LBEQ .J1B4_{}_OFF\n", label_id));
            out.push_str("    LDD #1\n");
            out.push_str(&format!("    LBRA .J1B4_{}_END\n", label_id));
            out.push_str(&format!(".J1B4_{}_OFF:\n", label_id));
            out.push_str("    LDD #0\n");
            out.push_str(&format!(".J1B4_{}_END:\n", label_id));
            out.push_str("    STD RESULT\n");
            true
        }
        
        // ===== Joystick 2 Input (Player 2) =====
        "J2_X" => {
            out.push_str("    JSR J2X_BUILTIN\n");
            out.push_str("    STD RESULT\n");
            true
        }
        "J2_Y" => {
            out.push_str("    JSR J2Y_BUILTIN\n");
            out.push_str("    STD RESULT\n");
            true
        }
        "J2_BUTTON_1" => {
            let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
            out.push_str("    LDA $C812      ; Vec_Button_1_2 (Player 2 transition bits)\n");
            out.push_str("    ANDA #$01      ; Test bit 0\n");
            out.push_str(&format!("    BEQ .J2B1_{}_OFF\n", label_id));
            out.push_str("    LDD #1\n");
            out.push_str(&format!("    BRA .J2B1_{}_END\n", label_id));
            out.push_str(&format!(".J2B1_{}_OFF:\n", label_id));
            out.push_str("    LDD #0\n");
            out.push_str(&format!(".J2B1_{}_END:\n", label_id));
            out.push_str("    STD RESULT\n");
            true
        }
        "J2_BUTTON_2" => {
            let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
            out.push_str("    LDA $C812      ; Vec_Button_1_2 (Player 2 transition bits)\n");
            out.push_str("    ANDA #$02      ; Test bit 1\n");
            out.push_str(&format!("    BEQ .J2B2_{}_OFF\n", label_id));
            out.push_str("    LDD #1\n");
            out.push_str(&format!("    BRA .J2B2_{}_END\n", label_id));
            out.push_str(&format!(".J2B2_{}_OFF:\n", label_id));
            out.push_str("    LDD #0\n");
            out.push_str(&format!(".J2B2_{}_END:\n", label_id));
            out.push_str("    STD RESULT\n");
            true
        }
        "J2_BUTTON_3" => {
            let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
            out.push_str("    LDA $C812      ; Vec_Button_1_2 (Player 2 transition bits)\n");
            out.push_str("    ANDA #$04      ; Test bit 2\n");
            out.push_str(&format!("    BEQ .J2B3_{}_OFF\n", label_id));
            out.push_str("    LDD #1\n");
            out.push_str(&format!("    BRA .J2B3_{}_END\n", label_id));
            out.push_str(&format!(".J2B3_{}_OFF:\n", label_id));
            out.push_str("    LDD #0\n");
            out.push_str(&format!(".J2B3_{}_END:\n", label_id));
            out.push_str("    STD RESULT\n");
            true
        }
        "J2_BUTTON_4" => {
            let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
            out.push_str("    LDA $C812      ; Vec_Button_1_2 (Player 2 transition bits)\n");
            out.push_str("    ANDA #$08      ; Test bit 3\n");
            out.push_str(&format!("    BEQ .J2B4_{}_OFF\n", label_id));
            out.push_str("    LDD #1\n");
            out.push_str(&format!("    BRA .J2B4_{}_END\n", label_id));
            out.push_str(&format!(".J2B4_{}_OFF:\n", label_id));
            out.push_str("    LDD #0\n");
            out.push_str(&format!(".J2B4_{}_END:\n", label_id));
            out.push_str("    STD RESULT\n");
            true
        }
        "J2_ANALOG_X" => {
            out.push_str("    ; J2_ANALOG_X: Read raw Player 2 X axis (0-255)\n");
            out.push_str("    LDB $CF02      ; Joy_2_X (unsigned byte)\n");
            out.push_str("    CLRA           ; Zero extend to 16-bit\n");
            out.push_str("    STD RESULT\n");
            true
        }
        "J2_ANALOG_Y" => {
            out.push_str("    ; J2_ANALOG_Y: Read raw Player 2 Y axis (0-255)\n");
            out.push_str("    LDB $CF03      ; Joy_2_Y (unsigned byte)\n");
            out.push_str("    CLRA           ; Zero extend to 16-bit\n");
            out.push_str("    STD RESULT\n");
            true
        }
        "J2_DIGITAL_X" => {
            out.push_str("    ; J2_DIGITAL_X: Player 2 X axis as -1/0/+1\n");
            out.push_str("    JSR J2X_BUILTIN\n");
            out.push_str("    STD RESULT\n");
            true
        }
        "J2_DIGITAL_Y" => {
            out.push_str("    ; J2_DIGITAL_Y: Player 2 Y axis as -1/0/+1\n");
            out.push_str("    JSR J2Y_BUILTIN\n");
            out.push_str("    STD RESULT\n");
            true
        }
        "J2_BUTTON_UP" => {
            let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
            out.push_str("    ; J2_BUTTON_UP: Player 2 D-pad UP\n");
            out.push_str("    LDB $CF03      ; Joy_2_Y\n");
            out.push_str("    CMPB #149      ; Threshold for UP (>148)\n");
            out.push_str(&format!("    BHI .J2UP_{}_ON\n", label_id));
            out.push_str("    LDD #0\n");
            out.push_str(&format!("    BRA .J2UP_{}_END\n", label_id));
            out.push_str(&format!(".J2UP_{}_ON:\n", label_id));
            out.push_str("    LDD #1\n");
            out.push_str(&format!(".J2UP_{}_END:\n", label_id));
            out.push_str("    STD RESULT\n");
            true
        }
        "J2_BUTTON_DOWN" => {
            let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
            out.push_str("    ; J2_BUTTON_DOWN: Player 2 D-pad DOWN\n");
            out.push_str("    LDB $CF03      ; Joy_2_Y\n");
            out.push_str("    CMPB #108      ; Threshold for DOWN (<108)\n");
            out.push_str(&format!("    BLO .J2DN_{}_ON\n", label_id));
            out.push_str("    LDD #0\n");
            out.push_str(&format!("    BRA .J2DN_{}_END\n", label_id));
            out.push_str(&format!(".J2DN_{}_ON:\n", label_id));
            out.push_str("    LDD #1\n");
            out.push_str(&format!(".J2DN_{}_END:\n", label_id));
            out.push_str("    STD RESULT\n");
            true
        }
        "J2_BUTTON_LEFT" => {
            let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
            out.push_str("    ; J2_BUTTON_LEFT: Player 2 D-pad LEFT\n");
            out.push_str("    LDB $CF02      ; Joy_2_X\n");
            out.push_str("    CMPB #108      ; Threshold for LEFT (<108)\n");
            out.push_str(&format!("    BLO .J2LFT_{}_ON\n", label_id));
            out.push_str("    LDD #0\n");
            out.push_str(&format!("    BRA .J2LFT_{}_END\n", label_id));
            out.push_str(&format!(".J2LFT_{}_ON:\n", label_id));
            out.push_str("    LDD #1\n");
            out.push_str(&format!(".J2LFT_{}_END:\n", label_id));
            out.push_str("    STD RESULT\n");
            true
        }
        "J2_BUTTON_RIGHT" => {
            let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
            out.push_str("    ; J2_BUTTON_RIGHT: Player 2 D-pad RIGHT\n");
            out.push_str("    LDB $CF02      ; Joy_2_X\n");
            out.push_str("    CMPB #149      ; Threshold for RIGHT (>148)\n");
            out.push_str(&format!("    BHI .J2RGT_{}_ON\n", label_id));
            out.push_str("    LDD #0\n");
            out.push_str(&format!("    BRA .J2RGT_{}_END\n", label_id));
            out.push_str(&format!(".J2RGT_{}_ON:\n", label_id));
            out.push_str("    LDD #1\n");
            out.push_str(&format!(".J2RGT_{}_END:\n", label_id));
            out.push_str("    STD RESULT\n");
            true
        }
        
        // ===== Audio/Music =====
        "PLAY_MUSIC" => {
            // PLAY_MUSIC("asset_name") - Load music pointer and start playback
            if args.len() != 1 {
                out.push_str("    ; ERROR: PLAY_MUSIC requires 1 argument (music asset name)\n");
            } else if let Expr::StringLit(asset_name) = &args[0] {
                // Check if asset exists
                let asset_exists = assets.iter().any(|a| {
                    a.name == *asset_name && matches!(a.asset_type, AssetType::Music)
                });
                
                if asset_exists {
                    // Find asset index for multibank lookup
                    let music_assets: Vec<_> = assets.iter()
                        .filter(|a| matches!(a.asset_type, AssetType::Music))
                        .collect();
                    
                    let asset_index = music_assets.iter()
                        .position(|a| a.name == *asset_name)
                        .unwrap_or(0);
                    
                    let symbol = format!("_{}_MUSIC", asset_name.to_uppercase().replace("-", "_").replace(" ", "_"));
                    out.push_str(&format!("    ; PLAY_MUSIC(\"{}\") - play music asset (index={})\n", asset_name, asset_index));
                    
                    if use_banked_assets() {
                        // MULTIBANK MODE: Use banked access via lookup tables
                        out.push_str(&format!("    LDX #{}        ; Music asset index for lookup\n", asset_index));
                        out.push_str("    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching\n");
                    } else {
                        // SINGLE-BANK MODE: Direct access to asset label
                        out.push_str(&format!("    LDX #{}  ; Load music data pointer\n", symbol));
                        out.push_str("    JSR PLAY_MUSIC_RUNTIME\n");
                    }
                    out.push_str("    LDD #0\n");
                    out.push_str("    STD RESULT\n");
                } else {
                    out.push_str(&format!("    ; ERROR: Music asset '{}' not found\n", asset_name));
                    out.push_str(&format!("    ; Available music assets: {:?}\n", 
                        assets.iter().filter(|a| matches!(a.asset_type, AssetType::Music)).map(|a| &a.name).collect::<Vec<_>>()));
                    out.push_str("    LDD #0\n");
                    out.push_str("    STD RESULT\n");
                }
            } else {
                out.push_str("    ; ERROR: PLAY_MUSIC first argument must be string literal\n");
                out.push_str("    LDD #0\n");
                out.push_str("    STD RESULT\n");
            }
            true
        }
        "AUDIO_UPDATE" => {
            out.push_str("    ; AUDIO_UPDATE: Update audio/music\n");
            out.push_str("    JSR AUDIO_UPDATE\n");
            out.push_str("    LDD #0\n");
            out.push_str("    STD RESULT\n");
            true
        }
        "MUSIC_UPDATE" => {
            out.push_str("    ; MUSIC_UPDATE: Update music playback\n");
            out.push_str("    JSR MUSIC_UPDATE\n");
            out.push_str("    LDD #0\n");
            out.push_str("    STD RESULT\n");
            true
        }
        "STOP_MUSIC" => {
            out.push_str("    ; STOP_MUSIC: Stop music playback\n");
            out.push_str("    JSR STOP_MUSIC_RUNTIME\n");
            out.push_str("    LDD #0\n");
            out.push_str("    STD RESULT\n");
            true
        }
        "PLAY_SFX" => {
            // PLAY_SFX("asset_name") - Load SFX pointer and start playback
            if args.len() != 1 {
                out.push_str("    ; ERROR: PLAY_SFX requires 1 argument (SFX asset name)\n");
            } else if let Expr::StringLit(asset_name) = &args[0] {
                // Check if asset exists
                let asset_exists = assets.iter().any(|a| {
                    a.name == *asset_name && matches!(a.asset_type, AssetType::Sfx)
                });

                if asset_exists {
                    // Find asset index for multibank lookup
                    let sfx_assets: Vec<_> = assets.iter()
                        .filter(|a| matches!(a.asset_type, AssetType::Sfx))
                        .collect();

                    let asset_index = sfx_assets.iter()
                        .position(|a| a.name == *asset_name)
                        .unwrap_or(0);

                    let symbol = format!("_{}_SFX", asset_name.to_uppercase().replace("-", "_").replace(" ", "_"));
                    out.push_str(&format!("    ; PLAY_SFX(\"{}\") - play SFX asset (index={})\n", asset_name, asset_index));

                    if use_banked_assets() {
                        // MULTIBANK MODE: Use banked access via lookup tables
                        out.push_str(&format!("    LDX #{}        ; SFX asset index for lookup\n", asset_index));
                        out.push_str("    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching\n");
                    } else {
                        // SINGLE-BANK MODE: Direct access to asset label
                        out.push_str(&format!("    LDX #{}  ; Load SFX data pointer\n", symbol));
                        out.push_str("    JSR PLAY_SFX_RUNTIME\n");
                    }
                } else {
                    out.push_str(&format!("    ; ERROR: SFX asset '{}' not found\n", asset_name));
                    out.push_str(&format!("    ; Available SFX assets: {:?}\n",
                        assets.iter().filter(|a| matches!(a.asset_type, AssetType::Sfx)).map(|a| &a.name).collect::<Vec<_>>()));
                }
            } else {
                out.push_str("    ; ERROR: PLAY_SFX first argument must be string literal\n");
            }
            out.push_str("    LDD #0\n");
            out.push_str("    STD RESULT\n");
            true
        }
        
        // ===== Vector Assets =====
        "DRAW_VECTOR" => {
            emit_draw_vector(args, out, assets);
            true
        }
        "DRAW_VECTOR_EX" => {
            emit_draw_vector_ex(args, out, assets);
            true
        }
        
        
        // ===== Math Functions =====
        "ABS" | "MATH_ABS" => {
            math::emit_abs(args, out, assets);
            true
        }
        "MIN" | "MATH_MIN" => {
            math::emit_min(args, out, assets);
            true
        }
        "MAX" | "MATH_MAX" => {
            math::emit_max(args, out, assets);
            true
        }
        "CLAMP" => {
            math::emit_clamp(args, out, assets);
            true
        }
        
        // ===== Debug Tools =====
        "DEBUG_PRINT" => {
            debug::emit_debug_print(args, out, assets);
            true
        }
        "DEBUG_PRINT_STR" => {
            debug::emit_debug_print_str(args, out, assets);
            true
        }
        "PRINT_NUMBER" => {
            debug::emit_print_number(args, out, assets);
            true
        }
        
        // ===== Math Extended =====
        "SIN" | "MATH_SIN" => {
            math_extended::emit_sin(args, out, assets);
            true
        }
        "COS" | "MATH_COS" => {
            math_extended::emit_cos(args, out, assets);
            true
        }
        "TAN" | "MATH_TAN" => {
            math_extended::emit_tan(args, out, assets);
            true
        }
        "SQRT" | "MATH_SQRT" => {
            math_extended::emit_sqrt(args, out, assets);
            true
        }
        "POW" | "MATH_POW" => {
            math_extended::emit_pow(args, out, assets);
            true
        }
        "ATAN2" | "MATH_ATAN2" => {
            math_extended::emit_atan2(args, out, assets);
            true
        }
        "RAND" | "MATH_RAND" => {
            math_extended::emit_rand(out, assets);
            true
        }
        "RAND_RANGE" | "MATH_RAND_RANGE" => {
            math_extended::emit_rand_range(args, out, assets);
            true
        }
        "DRAW_CIRCLE" => {
            emit_draw_circle_full(args, out, assets);
            true
        }
        "DRAW_RECT" => {
            drawing::emit_draw_rect(args, out);
            true
        }
        "DRAW_POLYGON" => {
            drawing::emit_draw_polygon(args, out);
            true
        }
        "DRAW_CIRCLE_SEG" => {
            drawing::emit_draw_circle_seg(args, out);
            true
        }
        "DRAW_ARC" => {
            drawing::emit_draw_arc(args, out);
            true
        }
        "DRAW_FILLED_RECT" => {
            drawing::emit_draw_filled_rect(args, out);
            true
        }
        "DRAW_ELLIPSE" => {
            drawing::emit_draw_ellipse(args, out);
            true
        }
        "DRAW_SPRITE" => {
            drawing::emit_draw_sprite(args, out);
            true
        }
        
        // Level System (6 builtins)
        "LOAD_LEVEL" => {
            level::emit_load_level(args, out, assets);
            true
        }
        "SHOW_LEVEL" => {
            level::emit_show_level(args, out);
            true
        }
        "UPDATE_LEVEL" => {
            level::emit_update_level(args, out);
            true
        }
        "GET_LEVEL_WIDTH" => {
            level::emit_get_level_width(args, out);
            true
        }
        "GET_LEVEL_HEIGHT" => {
            level::emit_get_level_height(args, out);
            true
        }
        "GET_LEVEL_TILE" => {
            level::emit_get_level_tile(args, out);
            true
        }
        
        // Utilities (9 builtins)
        "MOVE" => {
            utilities::emit_move(args, out);
            true
        }
        "LEN" => {
            utilities::emit_len(args, out);
            true
        }
        "GET_TIME" => {
            utilities::emit_get_time(args, out);
            true
        }
        "PEEK" => {
            utilities::emit_peek(args, out);
            true
        }
        "POKE" => {
            utilities::emit_poke(args, out);
            true
        }
        "WAIT" => {
            utilities::emit_wait(args, out);
            true
        }
        "BEEP" => {
            utilities::emit_beep(args, out);
            true
        }
        "FADE_IN" => {
            utilities::emit_fade_in(args, out);
            true
        }
        "FADE_OUT" => {
            utilities::emit_fade_out(args, out);
            true
        }
        
        "OLD_LEN" => {
            out.push_str("    ; LEN: Get array/string length\n");
            expressions::emit_simple_expr(&args[0], out, assets);
            out.push_str("    ; TODO: LEN implementation\n");
            out.push_str("    STD RESULT\n");
            true
        }
        
        // ===== Default: Not a builtin =====
        _ => false,
    }
}

fn emit_set_intensity(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    if args.len() != 1 {
        out.push_str("    ; ERROR: SET_INTENSITY requires 1 argument\n");
        return;
    }
    
    out.push_str("    ; SET_INTENSITY: Set drawing intensity\n");
    
    // Evaluate intensity argument
    expressions::emit_simple_expr(&args[0], out, assets);
    
    // Load result into A and call BIOS
    out.push_str("    LDA RESULT+1    ; Load intensity (8-bit)\n");
    out.push_str("    JSR Intensity_a\n");
    out.push_str("    LDD #0\n");
    out.push_str("    STD RESULT\n");
}

/// Generate deterministic hash for string
pub fn hash_string(s: &str) -> u64 {
    let mut hash: u64 = 0;
    for b in s.bytes() {
        hash = hash.wrapping_mul(31).wrapping_add(b as u64);
    }
    hash
}

fn emit_print_text(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    if args.len() != 3 {
        out.push_str("    ; ERROR: PRINT_TEXT requires 3 arguments (x, y, text)\n");
        return;
    }
    
    out.push_str("    ; PRINT_TEXT: Print text at position\n");
    
    // Store all 3 arguments in VAR_ARG0, VAR_ARG1, VAR_ARG2 (like core implementation)
    // Arg 0: x coordinate
    expressions::emit_simple_expr(&args[0], out, assets);
    out.push_str("    LDD RESULT\n");
    out.push_str("    STD VAR_ARG0\n");
    
    // Arg 1: y coordinate
    expressions::emit_simple_expr(&args[1], out, assets);
    out.push_str("    LDD RESULT\n");
    out.push_str("    STD VAR_ARG1\n");
    
    // Arg 2: text string
    match &args[2] {
        Expr::StringLit(s) => {
            // Load pointer to string in helpers bank
            let str_label = format!("PRINT_TEXT_STR_{}", hash_string(s));
            out.push_str(&format!("    LDX #{}      ; Pointer to string in helpers bank\n", str_label));
            out.push_str("    STX VAR_ARG2\n");
        }
        _ => {
            // Variable or expression - evaluate to pointer
            expressions::emit_simple_expr(&args[2], out, assets);
            out.push_str("    LDD RESULT\n");
            out.push_str("    STD VAR_ARG2\n");
        }
    }
    
    // Call the helper which reads x, y, string from VAR_ARG0-2
    out.push_str("    JSR VECTREX_PRINT_TEXT\n");
    
    out.push_str("    LDD #0\n");
    out.push_str("    STD RESULT\n");
}

/// Escape special characters in strings for FCC directive
fn escape_string(s: &str) -> String {
    let mut result = String::new();
    for ch in s.chars() {
        match ch {
            '"' => result.push_str("\"\""),  // Double quotes to escape in FCC
            '\\' => result.push_str("\\\\"), // Escape backslash
            '\n' => result.push_str("\\n"),  // Newline
            '\r' => result.push_str("\\r"),  // Carriage return
            '\t' => result.push_str("\\t"),  // Tab
            _ => result.push(ch),
        }
    }
    result
}

fn emit_draw_line(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    if args.len() != 5 {
        out.push_str("    ; ERROR: DRAW_LINE requires 5 arguments (x0, y0, x1, y1, intensity)\n");
        return;
    }
    
    out.push_str("    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)\n");
    
    // Store all arguments in DRAW_LINE_ARGS area (10 bytes: 5 words)
    // Arg 0: x0
    expressions::emit_simple_expr(&args[0], out, assets);
    out.push_str("    LDD RESULT\n");
    out.push_str("    STD DRAW_LINE_ARGS+0    ; x0\n");
    
    // Arg 1: y0
    expressions::emit_simple_expr(&args[1], out, assets);
    out.push_str("    LDD RESULT\n");
    out.push_str("    STD DRAW_LINE_ARGS+2    ; y0\n");
    
    // Arg 2: x1
    expressions::emit_simple_expr(&args[2], out, assets);
    out.push_str("    LDD RESULT\n");
    out.push_str("    STD DRAW_LINE_ARGS+4    ; x1\n");
    
    // Arg 3: y1
    expressions::emit_simple_expr(&args[3], out, assets);
    out.push_str("    LDD RESULT\n");
    out.push_str("    STD DRAW_LINE_ARGS+6    ; y1\n");
    
    // Arg 4: intensity
    expressions::emit_simple_expr(&args[4], out, assets);
    out.push_str("    LDD RESULT\n");
    out.push_str("    STD DRAW_LINE_ARGS+8    ; intensity\n");
    
    // Call DRAW_LINE_WRAPPER which handles DP switching and segmentation
    out.push_str("    JSR DRAW_LINE_WRAPPER\n");
    
    out.push_str("    LDD #0\n");
    out.push_str("    STD RESULT\n");
}

fn emit_draw_vector(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    // Arity already validated by emit_builtin
    out.push_str("    ; DRAW_VECTOR: Draw vector asset at position\n");
    
    // For buildtools, we generate a call to the asset label directly
    // The asset must exist in the ROM (checked during compilation)
    match &args[0] {
        Expr::StringLit(asset_name) => {
            // Find asset index in the vector assets list (for multibank lookup tables)
            let vector_assets: Vec<_> = assets.iter()
                .filter(|a| matches!(a.asset_type, AssetType::Vector))
                .collect();
            let asset_index = vector_assets.iter()
                .position(|a| a.name == *asset_name)
                .unwrap_or(0);
            
            // Find path count
            let path_count = if let Some(asset) = assets.iter().find(|a| a.name == *asset_name && matches!(a.asset_type, AssetType::Vector)) {
                 if let Ok(resource) = VecResource::load(std::path::Path::new(&asset.path)) {
                    resource.visible_paths().len()
                 } else {
                    1
                 }
            } else {
                 1
            };

            let symbol = format!("_{}", asset_name.to_uppercase().replace("-", "_").replace(" ", "_"));
            
            out.push_str(&format!("    ; Asset: {} (index={}, {} paths)\n", asset_name, asset_index, path_count));
            
            // Evaluate x position (arg 1) - save immediately to avoid overwrite
            expressions::emit_simple_expr(&args[1], out, assets);
            out.push_str("    LDA RESULT+1  ; X position (low byte)\n");
            out.push_str("    STA TMPPTR    ; Save X to temporary storage\n");
            
            // Evaluate y position (arg 2)
            expressions::emit_simple_expr(&args[2], out, assets);
            out.push_str("    LDA RESULT+1  ; Y position (low byte)\n");
            out.push_str("    STA TMPPTR+1  ; Save Y to temporary storage\n");
            
            // Restore X and Y from temporary storage and set positions
            out.push_str("    LDA TMPPTR    ; X position\n");
            out.push_str("    STA DRAW_VEC_X\n");
            out.push_str("    LDA TMPPTR+1  ; Y position\n");
            out.push_str("    STA DRAW_VEC_Y\n");
            
            // Clear mirror flags (DRAW_VECTOR uses no mirroring)
            out.push_str("    CLR MIRROR_X\n");
            out.push_str("    CLR MIRROR_Y\n");
            out.push_str("    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data\n");
            
            if use_banked_assets() {
                // MULTIBANK MODE: Use banked access via lookup tables in Bank #31
                // The DRAW_VECTOR_BANKED helper handles bank switching automatically
                out.push_str(&format!("    LDX #{}        ; Asset index for lookup\n", asset_index));
                out.push_str("    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching\n");
            } else {
                // SINGLE-BANK MODE: Direct access to asset labels
                // Single DP switch for all paths (CRITICAL PATTERN FROM CORE)
                out.push_str("    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)\n");
                
                // Loop through all paths
                for i in 0..path_count {
                    out.push_str(&format!("    LDX #{}_PATH{}  ; Load path {}\n", symbol, i, i));
                    out.push_str("    JSR Draw_Sync_List_At_With_Mirrors\n");
                }
                
                // Restore DP (CRITICAL PATTERN FROM CORE)
                out.push_str("    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)\n");
            }
            
            out.push_str("    LDD #0\n    STD RESULT\n");
        }
        _ => {
            out.push_str("    ; ERROR: DRAW_VECTOR first argument must be string literal\n");
            out.push_str("    LDD #0\n    STD RESULT\n");
        }
    }
}

fn emit_draw_vector_ex(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    // Arity already validated by emit_builtin
    out.push_str("    ; DRAW_VECTOR_EX: Draw vector asset with transformations\n");
    
    match &args[0] {
        Expr::StringLit(asset_name) => {
             // Find path count
            let path_count = if let Some(asset) = assets.iter().find(|a| a.name == *asset_name && matches!(a.asset_type, AssetType::Vector)) {
                 if let Ok(resource) = VecResource::load(std::path::Path::new(&asset.path)) {
                    resource.visible_paths().len()
                 } else {
                    1
                 }
            } else {
                 1
            };
            
            let symbol = format!("_{}", asset_name.to_uppercase().replace("-", "_").replace(" ", "_"));
            
            out.push_str(&format!("    ; Asset: {} ({} paths) with mirror + intensity\n", asset_name, path_count));
            
            // Evaluate x position (arg 1)
            expressions::emit_simple_expr(&args[1], out, assets);
            out.push_str("    LDA RESULT+1  ; X position (low byte)\n");
            out.push_str("    STA DRAW_VEC_X\n");
            
            // Evaluate y position (arg 2)
            expressions::emit_simple_expr(&args[2], out, assets);
            out.push_str("    LDA RESULT+1  ; Y position (low byte)\n");
            out.push_str("    STA DRAW_VEC_Y\n");
            
            // Evaluate mirror flag (arg 3)
            expressions::emit_simple_expr(&args[3], out, assets);
            out.push_str("    LDB RESULT+1  ; Mirror mode (0=normal, 1=X, 2=Y, 3=both)\n");
            
            // Decode mirror mode into separate MIRROR_X and MIRROR_Y flags
            let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
            out.push_str("    ; Decode mirror mode into separate flags:\n");
            out.push_str("    CLR MIRROR_X  ; Clear X flag\n");
            out.push_str("    CLR MIRROR_Y  ; Clear Y flag\n");
            out.push_str("    CMPB #1       ; Check if X-mirror (mode 1)\n");
            out.push_str(&format!("    LBNE .DSVEX_{}_CHK_Y\n", label_id));
            out.push_str("    LDA #1\n");
            out.push_str("    STA MIRROR_X\n");
            out.push_str(&format!(".DSVEX_{}_CHK_Y:\n", label_id));
            out.push_str("    CMPB #2       ; Check if Y-mirror (mode 2)\n");
            out.push_str(&format!("    LBNE .DSVEX_{}_CHK_XY\n", label_id));
            out.push_str("    LDA #1\n");
            out.push_str("    STA MIRROR_Y\n");
            out.push_str(&format!(".DSVEX_{}_CHK_XY:\n", label_id));
            out.push_str("    CMPB #3       ; Check if both-mirror (mode 3)\n");
            out.push_str(&format!("    LBNE .DSVEX_{}_CALL\n", label_id));
            out.push_str("    LDA #1\n");
            out.push_str("    STA MIRROR_X\n");
            out.push_str("    STA MIRROR_Y\n");
            out.push_str(&format!(".DSVEX_{}_CALL:\n", label_id));
            
            // Evaluate and set intensity override (arg 4)
            out.push_str("    ; Set intensity override for drawing\n");
            expressions::emit_simple_expr(&args[4], out, assets);
            out.push_str("    LDA RESULT+1  ; Intensity (0-127)\n");
            out.push_str("    STA DRAW_VEC_INTENSITY  ; Store intensity override\n");
            
            // Single DP switch for all paths (CRITICAL PATTERN FROM CORE)
            out.push_str("    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)\n");
            
            // Loop through all paths
            for i in 0..path_count {
                out.push_str(&format!("    LDX #{}_PATH{}  ; Load path {}\n", symbol, i, i));
                out.push_str("    JSR Draw_Sync_List_At_With_Mirrors\n");
            }
            
            // Restore DP (CRITICAL PATTERN FROM CORE)
            out.push_str("    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)\n");
            
            out.push_str("    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw\n");
            out.push_str("    LDD #0\n    STD RESULT\n");
        }
        _ => {
            out.push_str("    ; ERROR: DRAW_VECTOR_EX first argument must be string literal\n");
            out.push_str("    LDD #0\n    STD RESULT\n");
        }
    }
}

/// Generate helper function implementations
pub fn generate_helper_functions() -> String {
    let mut asm = String::new();
    
    asm.push_str(";***************************************************************************\n");
    asm.push_str("; HELPER FUNCTIONS\n");
    asm.push_str(";***************************************************************************\n\n");
    
    // Add any runtime helpers here (MUL16, DIV16, etc.)
    
    asm
}
/// Collect all PRINT_TEXT string literals from the module
/// Returns a map of hash -> string
pub fn collect_print_text_strings(module: &Module) -> std::collections::BTreeMap<u64, String> {
    let mut strings = std::collections::BTreeMap::new();
    
    // Visit statements and collect PRINT_TEXT strings
    for item in &module.items {
        if let vpy_parser::Item::Function(func) = item {
            for stmt in &func.body {
                collect_strings_from_stmt(stmt, &mut strings);
            }
        }
    }
    
    strings
}

fn collect_strings_from_stmt(stmt: &vpy_parser::Stmt, strings: &mut std::collections::BTreeMap<u64, String>) {
    match stmt {
        vpy_parser::Stmt::Expr(expr, _) => collect_strings_from_expr(expr, strings),
        vpy_parser::Stmt::Assign { value, .. } => collect_strings_from_expr(value, strings),
        vpy_parser::Stmt::Let { value, .. } => collect_strings_from_expr(value, strings),
        vpy_parser::Stmt::For { start, end, step, body, .. } => {
            collect_strings_from_expr(start, strings);
            collect_strings_from_expr(end, strings);
            if let Some(s) = step {
                collect_strings_from_expr(s, strings);
            }
            for s in body {
                collect_strings_from_stmt(s, strings);
            }
        }
        vpy_parser::Stmt::ForIn { iterable, body, .. } => {
            collect_strings_from_expr(iterable, strings);
            for s in body {
                collect_strings_from_stmt(s, strings);
            }
        }
        vpy_parser::Stmt::While { cond, body, .. } => {
            collect_strings_from_expr(cond, strings);
            for s in body {
                collect_strings_from_stmt(s, strings);
            }
        }
        vpy_parser::Stmt::If { cond, body, elifs, else_body, .. } => {
            collect_strings_from_expr(cond, strings);
            for s in body {
                collect_strings_from_stmt(s, strings);
            }
            for (e, b) in elifs {
                collect_strings_from_expr(e, strings);
                for s in b {
                    collect_strings_from_stmt(s, strings);
                }
            }
            if let Some(else_stmts) = else_body {
                for s in else_stmts {
                    collect_strings_from_stmt(s, strings);
                }
            }
        }
        vpy_parser::Stmt::CompoundAssign { value, .. } => collect_strings_from_expr(value, strings),
        _ => {}
    }
}

fn collect_strings_from_expr(expr: &Expr, strings: &mut std::collections::BTreeMap<u64, String>) {
    match expr {
        Expr::StringLit(s) => {
            let hash = hash_string(s);
            strings.insert(hash, s.clone());
        }
        Expr::Call(call) => {
            // Check for PRINT_TEXT 3rd arg (redundant now but harmless)
            if call.name.to_uppercase() == "PRINT_TEXT" && call.args.len() >= 3 {
                if let Expr::StringLit(s) = &call.args[2] {
                    let hash = hash_string(s);
                    strings.insert(hash, s.clone());
                }
            }
            for arg in &call.args {
                collect_strings_from_expr(arg, strings);
            }
        }
        Expr::Binary { left, right, .. } => {
            collect_strings_from_expr(left, strings);
            collect_strings_from_expr(right, strings);
        }
        Expr::Compare { left, right, .. } => {
            collect_strings_from_expr(left, strings);
            collect_strings_from_expr(right, strings);
        }
        Expr::Logic { left, right, .. } => {
            collect_strings_from_expr(left, strings);
            collect_strings_from_expr(right, strings);
        }
        Expr::Not(expr) | Expr::BitNot(expr) => collect_strings_from_expr(expr, strings),
        Expr::Index { target, index } => {
            collect_strings_from_expr(target, strings);
            collect_strings_from_expr(index, strings);
        }
        Expr::FieldAccess { target, .. } => collect_strings_from_expr(target, strings),
        Expr::MethodCall(call) => {
            for arg in &call.args {
                collect_strings_from_expr(arg, strings);
            }
        }
        Expr::List(items) => {
            for item in items {
                collect_strings_from_expr(item, strings);
            }
        }
        _ => {}
    }
}

/// DRAW_CIRCLE with full variable support
/// Uses inline 16-gon for constant args (matching core), DRAW_CIRCLE_RUNTIME for variables
fn emit_draw_circle_full(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    if args.len() != 3 && args.len() != 4 {
        out.push_str("    ; ERROR: DRAW_CIRCLE requires 3 or 4 arguments\n");
        return;
    }

    // All-constant path: emit inline 16-gon (same as core compiler)
    if args.iter().all(|a| matches!(a, Expr::Number(_))) {
        drawing::emit_draw_circle(args, out);
        return;
    }

    out.push_str("    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter\n");
    
    // Evaluate xc and store in DRAW_CIRCLE_XC
    expressions::emit_simple_expr(&args[0], out, assets);
    out.push_str("    LDA RESULT+1\n");
    out.push_str("    STA DRAW_CIRCLE_XC\n");
    
    // Evaluate yc and store in DRAW_CIRCLE_YC
    expressions::emit_simple_expr(&args[1], out, assets);
    out.push_str("    LDA RESULT+1\n");
    out.push_str("    STA DRAW_CIRCLE_YC\n");
    
    // Evaluate diam and store in DRAW_CIRCLE_DIAM
    expressions::emit_simple_expr(&args[2], out, assets);
    out.push_str("    LDA RESULT+1\n");
    out.push_str("    STA DRAW_CIRCLE_DIAM\n");
    
    // Evaluate intensity (default $5F if not provided)
    if args.len() == 4 {
        expressions::emit_simple_expr(&args[3], out, assets);
        out.push_str("    LDA RESULT+1\n");
        out.push_str("    STA DRAW_CIRCLE_INTENSITY\n");
    } else {
        out.push_str("    LDA #$5F\n");
        out.push_str("    STA DRAW_CIRCLE_INTENSITY\n");
    }
    
    // Call runtime helper
    out.push_str("    JSR DRAW_CIRCLE_RUNTIME\n");
    
    out.push_str("    LDD #0\n");
    out.push_str("    STD RESULT\n");
}

/// Emit all PRINT_TEXT string data in helpers bank
pub fn emit_print_text_strings(strings: &std::collections::BTreeMap<u64, String>, out: &mut String) {
    if strings.is_empty() {
        return;
    }
    
    out.push_str(";**** PRINT_TEXT String Data ****\n");
    for (hash, s) in strings {
        let label = format!("PRINT_TEXT_STR_{}", hash);
        out.push_str(&format!("{}:\n", label));
        out.push_str(&format!("    FCC \"{}\"\n", escape_string(s)));
        out.push_str("    FCB $80          ; Vectrex string terminator\n\n");
    }
}