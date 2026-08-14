//! Builtin Functions for M6809
//!
//! Essential builtins:
//! - PRINT_TEXT: Print text at position
//! - DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
//! - WAIT_RECAL: Wait for screen refresh
//! - SET_INTENSITY: Set drawing intensity

use vpy_parser::{Expr, Item, Module, Stmt};
use super::expressions;
use super::math;
use super::debug;
use super::math_extended;
use super::drawing;
use super::level;
use super::utilities;
use super::assets;
use crate::{AssetInfo, AssetType};
use crate::vecres::VecResource;
use std::sync::atomic::{AtomicUsize, AtomicBool, Ordering};

/// A single entry from MSG_DEF(id, x, y, "text")
#[derive(Debug, Clone)]
pub struct MsgEntry {
    pub id: u8,
    pub x: i8,
    pub y: i8,
    pub text: String,
}

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
    ("SET_TEXT_SIZE", 1),   // n (1-8, 8=normal): sets Vec_Text_Height/Width
    ("DRAW_LINE", 5),       // x0, y0, x1, y1, intensity
    ("DRAW_BEZIER", 10),    // x0, y0, cp1x, cp1y, cp2x, cp2y, x1, y1, steps, intensity
    ("DRAW_BEZIER_QUAD", 8),// x0, y0, cpx, cpy, x1, y1, steps, intensity
    ("DRAW_RECT", 5),       // x, y, width, height, intensity
    ("SET_INTENSITY", 1),   // intensity
    ("RESET0REF", 0),       // no args
    
    // Vector asset functions
    ("DRAW_VECTOR", 3),     // name, x, y
    ("DRAW_VECTOR_EX", 5),  // name, x, y, mirror, intensity
    ("DRAW_VECTOR_3D", 6),  // name, ax, ay, az, x, y
    
    // Audio functions
    ("PLAY_MUSIC", 1),      // name
    ("PLAY_SFX", 1),        // name
    ("STOP_MUSIC", 0),      // no args
    ("AUDIO_UPDATE", 0),    // no args
    ("MUSIC_UPDATE", 0),    // no args (deprecated)
    
    // SD game list (simulated on m6809/emulator; real SD on rp2350)
    ("SD_FILE_COUNT", 0),   // no args -> count
    ("SD_FILE_NAME", 1),    // index -> ptr to name string

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

    // Level camera
    ("SET_CAMERA_X", 1),          // camera_x (16-bit scroll offset)
    ("SET_CAMERA_Y", 1),          // camera_y (16-bit scroll offset)
    ("GET_SCROLL_LIMIT_LEFT",   0),  // → i16 left scroll boundary
    ("GET_SCROLL_LIMIT_RIGHT",  0),  // → i16 right scroll boundary
    ("GET_SCROLL_LIMIT_TOP",    0),  // → i16 top scroll boundary
    ("GET_SCROLL_LIMIT_BOTTOM", 0),  // → i16 bottom scroll boundary
    ("GET_LEVEL_FLOOR_Y",       0),  // → i16 floor surface world Y (camera-relative)
    ("GET_FRAME_US",            0),  // → u32 µs since last WAIT_RECAL (M6809 stub: 0)
    ("LEVEL_COLLISION_Y", 3),     // player_x, player_y, player_half_height → returns tile_top + player_hh
    ("LEVEL_COLLISION_X", 4),     // player_x, player_y, player_half_width, player_half_height → returns push-out dx

    // Message table dispatch
    ("MSG_DEF", 4),       // id, x, y, text  — data declaration, emits no code
    ("PRINT_MSG", 1),     // id_expr          — runtime dispatch via ROM table

    // Animation
    ("DRAW_ANIM", 1),     // animation_name → draws current frame, advances counter

    // Vector-movie playback (.vrec) — single-bank, video-only
    ("DRAW_RECORDING", 5),// name, x, y, scale, frame

    // Pitched instrument
    ("PLAY_NOTE", 3),     // instrument_name, channel, midi_note

    // Enemy access (collision / state machine)
    ("GET_ENEMY_ACTIVE", 1),  // i → 0 or 1
    ("GET_ENEMY_X", 1),       // i → i16 x
    ("GET_ENEMY_Y", 1),       // i → i16 y
    ("GET_ENEMY_HP", 1),      // i → u8 hp
    ("GET_ENEMY_STATE", 1),   // i → u8 sm_state ($FF = no SM)
    ("SET_ENEMY_X", 2),       // i, x → writes pool[i].x
    ("SET_ENEMY_Y", 2),       // i, y → writes pool[i].y
    ("SET_ENEMY_STATE", 2),   // i, state → writes pool[i].sm_state byte
    ("SET_ENEMY_DIR", 2),     // i, dir → writes pool[i].dir (0=left, 1=right)
    ("GET_ENEMY_AREA_IDX", 1),// i → u8 current_area_idx (255 if inactive) — debug
    ("KILL_ENEMY", 1),        // i → kills enemy, returns new ENEMY_COUNT
    ("ENEMY_FIRE_EVENT", 2),  // i, "eventName" → fires event hash
];

/// True if `name` resolves to a known builtin / native runtime function.
pub fn is_builtin(name: &str) -> bool {
    expected_builtin_arity(name).is_some()
}

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
        "MSG_DEF" => {
            if arg_count != 4 {
                return Err(format!("MSG_DEF requires 4 arguments (id, x, y, text), got {}", arg_count));
            }
            return Ok(());
        }
        "DRAW_ANIM" => {
            if arg_count != 1 && arg_count != 3 && arg_count != 4 && arg_count != 5 && arg_count != 6 {
                return Err(format!("DRAW_ANIM requires 1, 3, 4, 5, or 6 arguments (name / name+x+y / +mirror / +scale / +speed), got {}", arg_count));
            }
            return Ok(());
        }
        "DRAW_VECTOR" => {
            if arg_count != 3 && arg_count != 4 {
                return Err(format!("DRAW_VECTOR requires 3 or 4 arguments (name, x, y / +mirror), got {}", arg_count));
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
        "MSG_DEF" => {
            // Data declaration only — collected by collect_msg_entries(), no code emitted here
            true
        }
        "PRINT_MSG" => {
            emit_print_msg(args, out, assets);
            true
        }
        "SET_TEXT_SIZE" => {
            // SET_TEXT_SIZE(n): n=1..8, n=8 is normal size
            // Vec_Text_Height ($C82A) = -n (signed byte: e.g. -8 = $F8 for normal)
            // Vec_Text_Width  ($C82B) = n*9 (e.g. 72 for normal)
            if let Some(arg) = args.first() {
                expressions::emit_simple_expr(arg, out, assets);
                // B = n after emit; save to TMPPTR2 so we can restore n after NEGB
                out.push_str("    STD TMPPTR2     ; Save n (TMPPTR2+1 = n)\n");
                out.push_str("    NEGB            ; B = -n -> TEXT_SCALE_H\n");
                out.push_str("    STB >TEXT_SCALE_H\n");
                out.push_str("    LDB TMPPTR2+1   ; Reload n (from TMPPTR2, not RESULT)\n");
                out.push_str("    ASLB            ; n*2\n");
                out.push_str("    ASLB            ; n*4\n");
                out.push_str("    ASLB            ; n*8\n");
                out.push_str("    ADDB TMPPTR2+1  ; n*8 + n = n*9 -> TEXT_SCALE_W\n");
                out.push_str("    STB >TEXT_SCALE_W\n");
            }
            true
        }
        "DRAW_LINE" => {
            emit_draw_line(args, out, assets);
            true
        }
        
        // ===== SD game list (simulated on m6809 — see sim_sd_files) =====
        "SD_FILE_COUNT" => {
            let n = sim_sd_files().len();
            out.push_str(&format!("    LDD #{}          ; SD_FILE_COUNT (sim: {} file(s))\n", n, n));
            out.push_str("    STD RESULT\n");
            true
        }
        "SD_FILE_NAME" => {
            // args[0] = index → D = pointer to simulated name[i].
            // Use LDX #label + LEAX D,X (same #label form that PRINT_TEXT strings
            // resolve with) — an immediate ADDD #label does not resolve here.
            expressions::emit_simple_expr(&args[0], out, assets); // D = i
            out.push_str("    ASLB\n    ROLA            ; D = i*2 (16-bit ptr stride)\n");
            out.push_str("    LDX #SD_NAME_TABLE\n");
            out.push_str("    LEAX D,X        ; X = &SD_NAME_TABLE[i]\n");
            out.push_str("    LDD ,X          ; D = ptr to name[i]\n");
            out.push_str("    STD RESULT\n");
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
            // $C80F = Vec_Btns_1 (BIOS Read_Btns output, active-HIGH: 1=pressed, 0=released)
            // BNE after BITA: Z=0 when bit IS 1 (button pressed in active-HIGH)
            out.push_str("    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed\n");
            out.push_str("    BITA #$01\n");
            out.push_str(&format!("    BNE .J1B1_{0}_ON\n", label_id));
            out.push_str("    LDD #0\n");
            out.push_str(&format!("    BRA .J1B1_{0}_END\n", label_id));
            out.push_str(&format!(".J1B1_{0}_ON:\n", label_id));
            out.push_str("    LDD #1\n");
            out.push_str(&format!(".J1B1_{0}_END:\n", label_id));
            out.push_str("    STD RESULT\n");
            true
        }
        "J1_BUTTON_2" => {
            let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
            out.push_str("    LDA >$C80F   ; Vec_Btns_1: bit1=1 means btn2 pressed\n");
            out.push_str("    BITA #$02\n");
            out.push_str(&format!("    BNE .J1B2_{0}_ON\n", label_id));
            out.push_str("    LDD #0\n");
            out.push_str(&format!("    BRA .J1B2_{0}_END\n", label_id));
            out.push_str(&format!(".J1B2_{0}_ON:\n", label_id));
            out.push_str("    LDD #1\n");
            out.push_str(&format!(".J1B2_{0}_END:\n", label_id));
            out.push_str("    STD RESULT\n");
            true
        }
        "J1_BUTTON_3" => {
            let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
            out.push_str("    LDA >$C80F   ; Vec_Btns_1: bit2=1 means btn3 pressed\n");
            out.push_str("    BITA #$04\n");
            out.push_str(&format!("    BNE .J1B3_{0}_ON\n", label_id));
            out.push_str("    LDD #0\n");
            out.push_str(&format!("    BRA .J1B3_{0}_END\n", label_id));
            out.push_str(&format!(".J1B3_{0}_ON:\n", label_id));
            out.push_str("    LDD #1\n");
            out.push_str(&format!(".J1B3_{0}_END:\n", label_id));
            out.push_str("    STD RESULT\n");
            true
        }
        "J1_BUTTON_4" => {
            let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
            out.push_str("    LDA >$C80F   ; Vec_Btns_1: bit3=1 means btn4 pressed\n");
            out.push_str("    BITA #$08\n");
            out.push_str(&format!("    BNE .J1B4_{0}_ON\n", label_id));
            out.push_str("    LDD #0\n");
            out.push_str(&format!("    BRA .J1B4_{0}_END\n", label_id));
            out.push_str(&format!(".J1B4_{0}_ON:\n", label_id));
            out.push_str("    LDD #1\n");
            out.push_str(&format!(".J1B4_{0}_END:\n", label_id));
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
        // Player 2 buttons live in the upper nibble of Vec_Btns ($C80F),
        // the same BIOS variable as Player 1 (P1 = bits 0-3, P2 = bits 4-7).
        // Active-HIGH after Read_Btns. The old code was looking at $C812
        // with mask 0x01-0x08 — wrong address and wrong bit positions, so
        // J2_BUTTON_*() never reported pressed (issue #4).
        "J2_BUTTON_1" => {
            let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
            out.push_str("    LDA >$C80F   ; Vec_Btns: bit4=1 means P2 btn1 pressed\n");
            out.push_str("    BITA #$10\n");
            out.push_str(&format!("    BNE .J2B1_{0}_ON\n", label_id));
            out.push_str("    LDD #0\n");
            out.push_str(&format!("    BRA .J2B1_{0}_END\n", label_id));
            out.push_str(&format!(".J2B1_{0}_ON:\n", label_id));
            out.push_str("    LDD #1\n");
            out.push_str(&format!(".J2B1_{0}_END:\n", label_id));
            out.push_str("    STD RESULT\n");
            true
        }
        "J2_BUTTON_2" => {
            let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
            out.push_str("    LDA >$C80F   ; Vec_Btns: bit5=1 means P2 btn2 pressed\n");
            out.push_str("    BITA #$20\n");
            out.push_str(&format!("    BNE .J2B2_{0}_ON\n", label_id));
            out.push_str("    LDD #0\n");
            out.push_str(&format!("    BRA .J2B2_{0}_END\n", label_id));
            out.push_str(&format!(".J2B2_{0}_ON:\n", label_id));
            out.push_str("    LDD #1\n");
            out.push_str(&format!(".J2B2_{0}_END:\n", label_id));
            out.push_str("    STD RESULT\n");
            true
        }
        "J2_BUTTON_3" => {
            let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
            out.push_str("    LDA >$C80F   ; Vec_Btns: bit6=1 means P2 btn3 pressed\n");
            out.push_str("    BITA #$40\n");
            out.push_str(&format!("    BNE .J2B3_{0}_ON\n", label_id));
            out.push_str("    LDD #0\n");
            out.push_str(&format!("    BRA .J2B3_{0}_END\n", label_id));
            out.push_str(&format!(".J2B3_{0}_ON:\n", label_id));
            out.push_str("    LDD #1\n");
            out.push_str(&format!(".J2B3_{0}_END:\n", label_id));
            out.push_str("    STD RESULT\n");
            true
        }
        "J2_BUTTON_4" => {
            let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
            out.push_str("    LDA >$C80F   ; Vec_Btns: bit7=1 means P2 btn4 pressed\n");
            out.push_str("    BITA #$80\n");
            out.push_str(&format!("    BNE .J2B4_{0}_ON\n", label_id));
            out.push_str("    LDD #0\n");
            out.push_str(&format!("    BRA .J2B4_{0}_END\n", label_id));
            out.push_str(&format!(".J2B4_{0}_ON:\n", label_id));
            out.push_str("    LDD #1\n");
            out.push_str(&format!(".J2B4_{0}_END:\n", label_id));
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
        "DRAW_VECTOR_3D" => {
            emit_draw_vector_3d(args, out, assets);
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
        "DEBUG_PRINT_LABELED" => {
            // (label, value) — discard the label (M6809 has no host UART
            // channel to surface it on) and just print the value.
            if args.len() >= 2 {
                debug::emit_debug_print(&args[1..], out, assets);
            }
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
            emit_draw_rect_full(args, out, assets);
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
        "DRAW_BEZIER" => {
            drawing::emit_draw_bezier(args, out);
            true
        }
        "DRAW_BEZIER_QUAD" => {
            drawing::emit_draw_bezier_quad(args, out);
            true
        }
        "DRAW_SPRITE" => {
            drawing::emit_draw_sprite(args, out);
            true
        }
        
        // Level System (7 builtins)
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
        "SET_CAMERA_X" => {
            level::emit_set_camera_x(args, out, assets);
            true
        }
        "SET_CAMERA_Y" => {
            level::emit_set_camera_y(args, out, assets);
            true
        }
        "GET_SCROLL_LIMIT_LEFT" => {
            level::emit_get_scroll_limit_left(args, out);
            true
        }
        "GET_SCROLL_LIMIT_RIGHT" => {
            level::emit_get_scroll_limit_right(args, out);
            true
        }
        "GET_SCROLL_LIMIT_TOP" => {
            level::emit_get_scroll_limit_top(args, out);
            true
        }
        "GET_SCROLL_LIMIT_BOTTOM" => {
            level::emit_get_scroll_limit_bottom(args, out);
            true
        }
        "GET_LEVEL_FLOOR_Y" => {
            level::emit_get_level_floor_y(args, out);
            true
        }
        "GET_FRAME_US" => {
            level::emit_get_frame_us(args, out);
            true
        }
        "LEVEL_COLLISION_Y" => {
            level::emit_level_collision_y(args, out, assets);
            true
        }
        "LEVEL_COLLISION_X" => {
            level::emit_level_collision_x(args, out, assets);
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

        // ===== Pitched Instrument =====
        // PLAY_NOTE("instrument_name", channel, midi_note)
        //   instrument_name: string literal matching a .vinstr asset
        //   channel: 0=A, 1=B, 2=C
        //   midi_note: MIDI note number 24-107 (C1-B7)
        "PLAY_NOTE" => {
            if args.len() != 3 {
                out.push_str("    ; ERROR: PLAY_NOTE requires 3 arguments (instrument_name, channel, midi_note)\n");
            } else if let Expr::StringLit(instr_name) = &args[0] {
                let symbol = format!("_{}_INSTR", instr_name.to_uppercase().replace('-', "_").replace(' ', "_"));
                out.push_str(&format!("    ; PLAY_NOTE(\"{}\", channel, note)\n", instr_name));
                // Load instrument ROM block address into NOTE_ARG_INSTR
                out.push_str(&format!("    LDX #{}\n", symbol));
                out.push_str("    STX >NOTE_ARG_INSTR\n");
                // Evaluate channel (0/1/2) → NOTE_ARG_CHANNEL
                expressions::emit_simple_expr(&args[1], out, assets);
                out.push_str("    STB >NOTE_ARG_CHANNEL\n");
                // Evaluate midi_note → NOTE_ARG_NOTE
                expressions::emit_simple_expr(&args[2], out, assets);
                out.push_str("    STB >NOTE_ARG_NOTE\n");
                // Call runtime
                out.push_str("    JSR PLAY_NOTE_RUNTIME\n");
            } else {
                out.push_str("    ; ERROR: PLAY_NOTE first argument must be a string literal (instrument name)\n");
            }
            out.push_str("    LDD #0\n");
            out.push_str("    STD RESULT\n");
            true
        }

        "OLD_LEN" => {
            out.push_str("    ; LEN: Get array/string length\n");
            expressions::emit_simple_expr(&args[0], out, assets);
            out.push_str("    ; TODO: LEN implementation\n");
            out.push_str("    STD RESULT\n");
            true
        }
        
        // ===== Animation =====
        // DRAW_ANIM("name")                          — draw at DRAW_VEC_X/Y (caller must set)
        // DRAW_ANIM("name", x, y)                    — draw at screen position (x, y)
        // DRAW_ANIM("name", x, y, mirror)            — draw with X mirror flag
        // DRAW_ANIM("name", x, y, mirror, scale)     — T1 scale ($7F=normal, $3F=half, $FF=double)
        // DRAW_ANIM("name", x, y, mirror, scale, speed) — speed multiplier (1=normal, 2=half speed)
        "DRAW_ANIM" => {
            if let Some(Expr::StringLit(anim_name)) = args.first() {
                let name_upper = anim_name.to_uppercase().replace('-', "_").replace(' ', "_");
                out.push_str(&format!("    ; DRAW_ANIM: draw animation '{}'\n", anim_name));
                if args.len() >= 3 {
                    // Set X position
                    expressions::emit_simple_expr(&args[1], out, assets);
                    out.push_str("    TFR B,A\n");
                    out.push_str("    STA DRAW_VEC_X\n");
                    // Set Y position
                    expressions::emit_simple_expr(&args[2], out, assets);
                    out.push_str("    TFR B,A\n");
                    out.push_str("    STA DRAW_VEC_Y\n");
                } else {
                    out.push_str("    CLR DRAW_VEC_X\n");
                    out.push_str("    CLR DRAW_VEC_Y\n");
                }
                if args.len() >= 4 {
                    expressions::emit_simple_expr(&args[3], out, assets);
                    out.push_str("    TFR B,A\n");
                    out.push_str("    STA >MIRROR_X\n");          // write mirror directly (extended)
                    out.push_str("    STA >DRAW_ANIM_MIRROR_X\n"); // keep for runtime compatibility
                } else {
                    out.push_str("    CLR >MIRROR_X\n");
                    out.push_str("    CLR >DRAW_ANIM_MIRROR_X\n");
                }
                out.push_str("    CLR >MIRROR_Y\n");
                // Scale (arg[4], default $7F = normal size)
                if args.len() >= 5 {
                    expressions::emit_simple_expr(&args[4], out, assets);
                    out.push_str("    TFR B,A\n");
                    out.push_str("    STA DRAW_ANIM_SCALE\n");
                } else {
                    out.push_str("    LDA #$7F\n");
                    out.push_str("    STA DRAW_ANIM_SCALE\n");
                }
                // Speed: ticks_per_frame (arg[5]). 0 or omitted = use vanim's duration_ticks.
                // E.g. speed=6 → each animation frame lasts 6 game ticks (~8fps at 50Hz).
                if args.len() >= 6 {
                    expressions::emit_simple_expr(&args[5], out, assets);
                    out.push_str("    TFR B,A\n");
                    out.push_str("    STA DRAW_ANIM_SPEED_MUL\n");
                } else {
                    out.push_str("    CLR DRAW_ANIM_SPEED_MUL\n"); // 0 = use vanim timing
                }
                out.push_str(&format!("    LDX #_ANIM_{}\n", name_upper));
                out.push_str(&format!("    LDU #ANIM_{}_STATE\n", name_upper));
                out.push_str("    JSR DRAW_ANIM_RUNTIME\n");
                out.push_str("    LDD #0\n");
                out.push_str("    STD RESULT\n");
            } else {
                out.push_str("    ; ERROR: DRAW_ANIM requires a string literal name\n");
            }
            true
        }

        // ===== Vector-movie playback (.vrec) =====
        "DRAW_RECORDING" => {
            emit_draw_recording(args, out, assets);
            true
        }

        // ===== Enemy system builtins =====
        "SPAWN_ENEMIES" => {
            if args.len() != 1 {
                out.push_str("    ; ERROR: SPAWN_ENEMIES requires 1 argument (level name)\n");
            } else if let Expr::StringLit(level_name) = &args[0] {
                out.push_str(&format!("    ; SPAWN_ENEMIES(\"{level_name}\")\n"));
                if use_banked_assets() {
                    // Multibank: LOAD_LEVEL already set LEVEL_BANK/LEVEL_ENEMY_COUNT/LEVEL_ENEMY_INSTANCES_PTR
                    out.push_str("    JSR SPAWN_ENEMIES_BANKED\n");
                } else {
                    // Single-bank: LOAD_LEVEL_RUNTIME already stored count and instances ptr into RAM
                    out.push_str("    LDB >LEVEL_ENEMY_COUNT        ; count stored by LOAD_LEVEL_RUNTIME\n");
                    out.push_str("    LDX >LEVEL_ENEMY_INSTANCES_PTR ; instances ptr stored by LOAD_LEVEL_RUNTIME\n");
                    out.push_str("    JSR SPAWN_ENEMIES_RUNTIME\n");
                }
            } else {
                out.push_str("    ; ERROR: SPAWN_ENEMIES requires a string literal level name\n");
            }
            true
        }

        "UPDATE_ENEMIES" => {
            out.push_str("    ; UPDATE_ENEMIES: advance enemy AI and movement\n");
            out.push_str("    JSR UPDATE_ENEMIES_RUNTIME\n");
            true
        }

        "DRAW_ENEMIES" => {
            out.push_str("    ; DRAW_ENEMIES: render all active enemies\n");
            out.push_str("    JSR DRAW_ENEMIES_RUNTIME\n");
            true
        }

        // ===== Enemy read/kill/event builtins =====
        "GET_ENEMY_ACTIVE" | "GET_ENEMY_X" | "GET_ENEMY_Y" | "GET_ENEMY_HP" | "GET_ENEMY_STATE" => {
            if args.len() != 1 {
                out.push_str(&format!("    ; ERROR: {} requires 1 argument\n", name));
                return true;
            }
            expressions::emit_simple_expr(&args[0], out, assets);
            out.push_str("    TFR B,A             ; A = enemy index (low byte)\n");
            out.push_str("    LDB #28             ; ENEMY_POOL_STRIDE\n");
            out.push_str("    MUL                 ; D = A * stride\n");
            out.push_str("    LDX #ENEMY_POOL\n");
            out.push_str("    LEAX D,X            ; X = &pool[i]\n");
            match up.as_str() {
                "GET_ENEMY_ACTIVE" => {
                    out.push_str("    CLRA\n");
                    out.push_str("    LDB ,X              ; active byte\n");
                }
                "GET_ENEMY_X" => {
                    out.push_str("    LDA 1,X             ; x hi\n");
                    out.push_str("    LDB 2,X             ; x lo\n");
                }
                "GET_ENEMY_Y" => {
                    out.push_str("    LDA 3,X             ; y hi\n");
                    out.push_str("    LDB 4,X             ; y lo\n");
                }
                "GET_ENEMY_HP" => {
                    out.push_str("    CLRA\n");
                    out.push_str("    LDB 9,X             ; hp byte\n");
                }
                "GET_ENEMY_STATE" => {
                    out.push_str("    CLRA\n");
                    out.push_str("    LDB 13,X            ; sm_state byte\n");
                }
                _ => {}
            }
            out.push_str("    STD RESULT\n");
            true
        }

        // ===== Enemy debug/PiTrex-only stubs =====
        // The M6809 enemy pool has no `dir` field or area-tracking, so these
        // ARM/PiTrex builtins become no-ops on M6809 to keep cross-target code
        // (SnowBros etc.) compiling. SET_ENEMY_DIR still consumes its args via
        // emit_simple_expr so any side effects in expressions still happen.
        "SET_ENEMY_DIR" => {
            if args.len() == 2 {
                expressions::emit_simple_expr(&args[0], out, assets);
                expressions::emit_simple_expr(&args[1], out, assets);
            }
            out.push_str("    ; SET_ENEMY_DIR: NOP on M6809 (no dir field in pool)\n");
            true
        }
        "GET_ENEMY_AREA_IDX" => {
            if args.len() == 1 {
                expressions::emit_simple_expr(&args[0], out, assets);
            }
            out.push_str("    ; GET_ENEMY_AREA_IDX: stub returns 0 on M6809\n");
            out.push_str("    LDD #0\n");
            out.push_str("    STD RESULT\n");
            true
        }

        // ===== Enemy write builtins =====
        "SET_ENEMY_X" | "SET_ENEMY_Y" | "SET_ENEMY_STATE" => {
            if args.len() != 2 {
                out.push_str(&format!("    ; ERROR: {} requires 2 arguments (idx, value)\n", name));
                return true;
            }
            // SET_ENEMY_STATE goes through SET_ENEMY_STATE_RUNTIME so pool.action
            // and sm_decay_timer also get updated from the type's SM state record.
            // SET_ENEMY_X/Y stay as direct writes.
            if up == "SET_ENEMY_STATE" {
                // arg1 (state_idx) evaluated first, low byte stashed
                expressions::emit_simple_expr(&args[1], out, assets);
                out.push_str("    STB >TMPVAL         ; stash state_idx\n");
                expressions::emit_simple_expr(&args[0], out, assets);
                out.push_str("    TFR B,A             ; A = enemy index\n");
                out.push_str("    LDB >TMPVAL         ; B = state_idx\n");
                out.push_str("    JSR SET_ENEMY_STATE_RUNTIME\n");
                return true;
            }
            // Compute pool entry pointer: X = &pool[i]
            expressions::emit_simple_expr(&args[0], out, assets);
            out.push_str("    TFR B,A             ; A = enemy index (low byte)\n");
            out.push_str("    LDB #28             ; ENEMY_POOL_STRIDE\n");
            out.push_str("    MUL                 ; D = A * stride\n");
            out.push_str("    LDX #ENEMY_POOL\n");
            out.push_str("    LEAX D,X            ; X = &pool[i]\n");
            out.push_str("    PSHS X              ; save pool entry ptr on stack (safe across function calls)\n");
            // Evaluate value into D
            expressions::emit_simple_expr(&args[1], out, assets);
            out.push_str("    PULS X              ; restore pool entry ptr\n");
            match up.as_str() {
                "SET_ENEMY_X" => {
                    out.push_str("    STD 1,X             ; x hi @+1, x lo @+2\n");
                }
                "SET_ENEMY_Y" => {
                    out.push_str("    STD 3,X             ; y hi @+3, y lo @+4\n");
                }
                _ => {}
            }
            true
        }

        "KILL_ENEMY" => {
            if args.len() != 1 {
                out.push_str("    ; ERROR: KILL_ENEMY requires 1 argument\n");
                return true;
            }
            expressions::emit_simple_expr(&args[0], out, assets);
            out.push_str("    TFR B,A             ; A = enemy index\n");
            out.push_str("    JSR KILL_ENEMY_RUNTIME\n");
            true
        }

        "ENEMY_FIRE_EVENT" => {
            if args.len() != 2 {
                out.push_str("    ; ERROR: ENEMY_FIRE_EVENT requires 2 arguments (i, \"eventName\")\n");
                return true;
            }
            expressions::emit_simple_expr(&args[0], out, assets);
            out.push_str("    TFR B,A             ; A = enemy index\n");
            if let Expr::StringLit(event_name) = &args[1] {
                let hash = fnv1a_u8(event_name.as_str());
                out.push_str(&format!("    LDB #${:02X}              ; event hash '{}'\n", hash, event_name));
            } else {
                out.push_str("    ; ERROR: ENEMY_FIRE_EVENT second arg must be a string literal\n");
                out.push_str("    LDB #0\n");
            }
            out.push_str("    JSR ENEMY_FIRE_EVENT_RUNTIME\n");
            true
        }

        // ===== Default: Not a builtin =====
        _ => false,
    }
}

/// FNV-1a 8-bit hash — same algorithm used in venemy.rs for SM event name encoding.
fn fnv1a_u8(s: &str) -> u8 {
    let mut h: u32 = 2166136261;
    for b in s.bytes() {
        h ^= b as u32;
        h = h.wrapping_mul(16777619);
    }
    (h & 0xFF) as u8
}

fn emit_set_intensity(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    if args.len() != 1 {
        out.push_str("    ; ERROR: SET_INTENSITY requires 1 argument\n");
        return;
    }
    
    out.push_str("    ; SET_INTENSITY: Set drawing intensity\n");
    
    // Evaluate intensity argument
    expressions::emit_simple_expr(&args[0], out, assets);
    
    // Store intensity in DRAW_VEC_INTENSITY — DSWM reads this with extended addressing and
    // uses the correct BIOS Intensity_a sequence (PB=$05->$04, PA=val, PB=$00->$01).
    // Do NOT call JSR Intensity_a here: SET_INTENSITY runs with DP=$C8 so Intensity_a's
    // direct-mode VIA writes go to RAM ($C800) instead of the VIA ($D000).
    out.push_str("    TFR B,A         ; Intensity (8-bit) — B already holds low byte\n");
    out.push_str("    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn\n");
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
    // Arg 0: x coordinate; D = x after emit
    expressions::emit_simple_expr(&args[0], out, assets);
    out.push_str("    STD >VAR_ARG0\n");

    // Arg 1: y coordinate; D = y after emit
    expressions::emit_simple_expr(&args[1], out, assets);
    out.push_str("    STD >VAR_ARG1\n");
    
    // Arg 2: text string
    match &args[2] {
        Expr::StringLit(s) => {
            // Load pointer to string in helpers bank
            let str_label = format!("PRINT_TEXT_STR_{}", hash_string(s));
            out.push_str(&format!("    LDX #{}      ; Pointer to string in helpers bank\n", str_label));
            out.push_str("    STX >VAR_ARG2\n");
        }
        _ => {
            // Variable or expression - evaluate to pointer; D = pointer after emit
            expressions::emit_simple_expr(&args[2], out, assets);
            out.push_str("    STD >VAR_ARG2\n");
        }
    }
    
    // Call the helper which reads x, y, string from VAR_ARG0-2
    out.push_str("    JSR VECTREX_PRINT_TEXT\n");

    out.push_str("    LDD #0\n");
    out.push_str("    STD RESULT\n");
}

fn emit_print_msg(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    if args.len() != 1 {
        out.push_str("    ; ERROR: PRINT_MSG requires 1 argument (msg_id)\n");
        return;
    }
    out.push_str("    ; PRINT_MSG: Dispatch via ROM message table\n");
    expressions::emit_simple_expr(&args[0], out, assets);
    out.push_str("    STD >VAR_ARG0\n");
    out.push_str("    JSR PRINT_MSG_DISPATCH\n");
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
    // Arg 0: x0; D = x0 after emit
    expressions::emit_simple_expr(&args[0], out, assets);
    out.push_str("    STD DRAW_LINE_ARGS+0    ; x0\n");

    // Arg 1: y0; D = y0 after emit
    expressions::emit_simple_expr(&args[1], out, assets);
    out.push_str("    STD DRAW_LINE_ARGS+2    ; y0\n");

    // Arg 2: x1; D = x1 after emit
    expressions::emit_simple_expr(&args[2], out, assets);
    out.push_str("    STD DRAW_LINE_ARGS+4    ; x1\n");

    // Arg 3: y1; D = y1 after emit
    expressions::emit_simple_expr(&args[3], out, assets);
    out.push_str("    STD DRAW_LINE_ARGS+6    ; y1\n");

    // Arg 4: intensity; D = intensity after emit
    expressions::emit_simple_expr(&args[4], out, assets);
    out.push_str("    STD DRAW_LINE_ARGS+8    ; intensity\n");
    
    // Call DRAW_LINE_WRAPPER which handles DP switching and segmentation
    out.push_str("    JSR DRAW_LINE_WRAPPER\n");
    
    out.push_str("    LDD #0\n");
    out.push_str("    STD RESULT\n");
}

/// DRAW_RECORDING("name", x, y, scale, frame) — play one frame of a .vrec
/// vector recording. SINGLE-BANK, VIDEO-ONLY. Resolves "name" → _<NAME>_VREC,
/// stores x/y/scale/frame into DRAW_REC_* RAM, and JSRs DRAW_RECORDING_RUNTIME.
/// `frame` is a plain VPy variable the game increments each loop (no audio clock).
fn emit_draw_recording(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    // Arity (5) already validated by emit_builtin.
    match &args[0] {
        Expr::StringLit(rec_name) => {
            let symbol = format!("_{}_VREC", rec_name.to_uppercase().replace('-', "_").replace(' ', "_"));
            out.push_str(&format!("    ; DRAW_RECORDING(\"{}\", x, y, scale, frame)\n", rec_name));

            // x center (arg 1) → DRAW_REC_X (i8, low byte)
            expressions::emit_simple_expr(&args[1], out, assets);
            out.push_str("    TFR B,A          ; X center (low byte)\n");
            out.push_str("    STA >DRAW_REC_X\n");

            // y center (arg 2) → DRAW_REC_Y
            expressions::emit_simple_expr(&args[2], out, assets);
            out.push_str("    TFR B,A          ; Y center (low byte)\n");
            out.push_str("    STA >DRAW_REC_Y\n");

            // scale (arg 3) → DRAW_REC_SCALE (0-128, 128=100%)
            expressions::emit_simple_expr(&args[3], out, assets);
            out.push_str("    TFR B,A          ; scale (low byte)\n");
            out.push_str("    STA >DRAW_REC_SCALE\n");

            // frame counter (arg 4) → DRAW_REC_FRAME (16-bit; runtime does frame % frame_count)
            expressions::emit_simple_expr(&args[4], out, assets);
            out.push_str("    STD >DRAW_REC_FRAME\n");

            // Runtime honors SET_INTENSITY override (DRAW_VEC_INTENSITY); recorded
            // per-segment intensity is used when the override is 0.
            out.push_str(&format!("    LDX #{}      ; recording header\n", symbol));
            out.push_str("    JSR DRAW_RECORDING_RUNTIME\n");
            out.push_str("    LDD #0\n    STD RESULT\n");
        }
        _ => {
            out.push_str("    ; ERROR: DRAW_RECORDING first argument must be a string literal\n");
            out.push_str("    LDD #0\n    STD RESULT\n");
        }
    }
}

fn emit_draw_vector(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    // Arity already validated by emit_builtin
    out.push_str("    ; DRAW_VECTOR: Draw vector asset at position\n");
    
    // For buildtools, we generate a call to the asset label directly
    // The asset must exist in the ROM (checked during compilation)
    match &args[0] {
        Expr::StringLit(asset_name) => {
            // Find asset index in the vector assets list (for multibank lookup tables).
            // IMPORTANT: must exactly mirror the VECTOR_ADDR_TABLE built in assets.rs:
            //   1. Sort alphabetically (same as vector_entries.sort_by)
            //   2. Exclude animation-embedded vecs (same as !anim_vec_refs.contains(&a.name))
            //      because those go inline in vanim data, not in VECTOR_ADDR_TABLE.
            let anim_vec_refs = assets::collect_anim_vec_refs(assets);
            let mut vector_assets: Vec<_> = assets.iter()
                .filter(|a| matches!(a.asset_type, AssetType::Vector)
                    && !anim_vec_refs.contains(&a.name))
                .collect();
            vector_assets.sort_by(|a, b| a.name.cmp(&b.name));
            let asset_index = vector_assets.iter()
                .position(|a| a.name == *asset_name)
                .unwrap_or(0);
            
            // Find path count
            let path_count = if let Some(asset) = assets.iter().find(|a| a.name == *asset_name && matches!(a.asset_type, AssetType::Vector)) {
                 if let Ok(resource) = VecResource::load(std::path::Path::new(&asset.path)) {
                    // Must match the filter in vecres.rs compile_to_asm — degenerate
                    // paths (< 2 points) are dropped from the data table, so the
                    // unrolled DRAW_VECTOR loop here has to drop them too or it
                    // references _NAME_PATHN labels that were never emitted.
                    resource.visible_paths().iter().filter(|p| p.points.len() >= 2).count()
                 } else {
                    1
                 }
            } else {
                 1
            };

            let symbol = format!("_{}", asset_name.to_uppercase().replace("-", "_").replace(" ", "_"));
            
            let label_id = LABEL_COUNTER.fetch_add(1, Ordering::SeqCst);
            let skip_label = format!("DRVEC_SKIP_{}", label_id);

            out.push_str(&format!("    ; Asset: {} (index={}, {} paths)\n", asset_name, asset_index, path_count));

            // Evaluate x position (arg 1) — 16-bit signed result in D
            expressions::emit_simple_expr(&args[1], out, assets);
            // Cull if screen_x is outside signed 8-bit range [-128, 127]
            out.push_str("    STA TMPPTR2      ; save high byte of 16-bit screen_x\n");
            out.push_str("    TFR B,A\n");
            out.push_str("    SEX              ; A = sign-extend of B (0x00 or 0xFF)\n");
            out.push_str(&format!("    CMPA TMPPTR2     ; vs actual high byte\n"));
            out.push_str(&format!("    LBNE {}          ; out of 8-bit range — skip draw\n", skip_label));
            out.push_str("    TFR B,A\n");
            out.push_str("    STA TMPPTR       ; save 8-bit x\n");

            // Evaluate y position (arg 2)
            expressions::emit_simple_expr(&args[2], out, assets);
            out.push_str("    TFR B,A          ; Y position (8-bit signed in A)\n");
            out.push_str("    STA TMPPTR+1     ; Save Y to temporary storage\n");

            // Set draw positions
            out.push_str("    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)\n");
            out.push_str("    STA DRAW_VEC_X\n");
            // Sign-extend X to DRAW_VEC_X_HI for 16-bit clipping in SLR_DRAW_CLIPPED_PATH.
            // SHA the high byte: if A is negative ($80-$FF), store $FF, else $00.
            out.push_str("    LDB #0\n");
            out.push_str("    TSTA\n");
            out.push_str(&format!("    BPL .sx_pos_{}\n", label_id));
            out.push_str("    LDB #$FF\n");
            out.push_str(&format!(".sx_pos_{}:\n", label_id));
            out.push_str("    STB DRAW_VEC_X_HI\n");
            out.push_str("    LDA TMPPTR+1     ; Y position\n");
            out.push_str("    STA DRAW_VEC_Y\n");
            
            // Mirror X: optional 4th arg (0=normal, 1=flip X)
            if args.len() >= 4 {
                expressions::emit_simple_expr(&args[3], out, assets);
                out.push_str("    TFR B,A\n");
                out.push_str("    STA MIRROR_X\n");
            } else {
                out.push_str("    CLR MIRROR_X\n");
            }
            out.push_str("    CLR MIRROR_Y\n");
            // DRAW_VEC_INTENSITY was set by SET_INTENSITY() (or 0 = use $7F default in DSWM)
            
            if use_banked_assets() {
                // MULTIBANK MODE: Use banked access via lookup tables in Bank #31
                // DRAW_VECTOR_BANKED expects MIRROR_X/Y and DRAW_VEC_INTENSITY set by caller
                out.push_str("    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities\n");
                out.push_str(&format!("    LDX #{}        ; Asset index for lookup\n", asset_index));
                out.push_str("    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching\n");
            } else {
                // SINGLE-BANK MODE: Direct access to asset labels (match core compiler pattern)
                // Clear intensity override BEFORE draw so DSWM uses .vec intensities
                out.push_str("    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)\n");
                out.push_str("    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)\n");
                
                // Loop through all paths
                for i in 0..path_count {
                    out.push_str(&format!("    LDX #{}_PATH{}  ; Load path {}\n", symbol, i, i));
                    out.push_str("    JSR Draw_Sync_List_At_With_Mirrors\n");
                }
                
                // Restore DP (match core compiler pattern - no ACR manipulation needed)
                out.push_str("    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)\n");
            }

            out.push_str(&format!("{}:\n", skip_label));
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
                    // Must match the filter in vecres.rs compile_to_asm — degenerate
                    // paths (< 2 points) are dropped from the data table, so the
                    // unrolled DRAW_VECTOR loop here has to drop them too or it
                    // references _NAME_PATHN labels that were never emitted.
                    resource.visible_paths().iter().filter(|p| p.points.len() >= 2).count()
                 } else {
                    1
                 }
            } else {
                 1
            };
            
            // Find asset index for multibank lookup tables
            // IMPORTANT: must exactly mirror VECTOR_ADDR_TABLE: sort + exclude anim-embedded vecs
            let anim_vec_refs = assets::collect_anim_vec_refs(assets);
            let mut vector_assets: Vec<_> = assets.iter()
                .filter(|a| matches!(a.asset_type, AssetType::Vector)
                    && !anim_vec_refs.contains(&a.name))
                .collect();
            vector_assets.sort_by(|a, b| a.name.cmp(&b.name));
            let asset_index = vector_assets.iter()
                .position(|a| a.name == *asset_name)
                .unwrap_or(0);

            let symbol = format!("_{}", asset_name.to_uppercase().replace("-", "_").replace(" ", "_"));

            out.push_str(&format!("    ; Asset: {} (index={}, {} paths) with mirror + intensity\n", asset_name, asset_index, path_count));
            
            // Evaluate x position (arg 1)
            expressions::emit_simple_expr(&args[1], out, assets);
            out.push_str("    TFR B,A       ; X position (low byte) — B already holds it\n");
            out.push_str("    STA DRAW_VEC_X\n");

            // Evaluate y position (arg 2)
            expressions::emit_simple_expr(&args[2], out, assets);
            out.push_str("    TFR B,A       ; Y position (low byte) — B already holds it\n");
            out.push_str("    STA DRAW_VEC_Y\n");

            // Evaluate mirror flag (arg 3); B already holds mirror mode after emit
            expressions::emit_simple_expr(&args[3], out, assets);
            
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
            out.push_str("    TFR B,A       ; Intensity (0-127) — B already holds it\n");
            out.push_str("    STA DRAW_VEC_INTENSITY  ; Store intensity override\n");
            
            if use_banked_assets() {
                // MULTIBANK MODE: DRAW_VECTOR_BANKED handles DP setup, bank switch, path loop
                // MIRROR_X/Y and DRAW_VEC_INTENSITY are already set above
                out.push_str(&format!("    LDX #{}        ; Asset index for lookup\n", asset_index));
                out.push_str("    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching\n");
            } else {
                // SINGLE-BANK MODE: Direct path label loop
                // NOTE: do NOT set ACR here — DRAW_VECTOR works without it and
                // setting ACR=$18 breaks T1 timing inside DSWM (same fix as DRAW_ANIM).
                out.push_str("    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)\n");
                for i in 0..path_count {
                    out.push_str(&format!("    LDX #{}_PATH{}  ; Load path {}\n", symbol, i, i));
                    out.push_str("    JSR Draw_Sync_List_At_With_Mirrors\n");
                }
                out.push_str("    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)\n");
            }
            
            out.push_str("    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw\n");
            out.push_str("    LDD #0\n    STD RESULT\n");
        }
        _ => {
            out.push_str("    ; ERROR: DRAW_VECTOR_EX first argument must be string literal\n");
            out.push_str("    LDD #0\n    STD RESULT\n");
        }
    }
}


fn emit_draw_vector_3d(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    // Arity already validated by emit_builtin: DRAW_VECTOR_3D("name", ax, ay, az)
    out.push_str("    ; DRAW_VECTOR_3D: Draw vector asset with 3D rotation\n");

    match &args[0] {
        Expr::StringLit(asset_name) => {
            let symbol = format!("_{}", asset_name.to_uppercase().replace("-", "_").replace(" ", "_"));
            out.push_str(&format!("    ; Asset: {} (3D rotation)\n", asset_name));

            // Store raw angles to RAM — trig lookup happens inside DRAW_VECTOR_3D_RUNTIME
            // (runtime is in helpers bank where SIN_TABLE/COS_TABLE live)
            expressions::emit_simple_expr(&args[1], out, assets);
            out.push_str("    STB >ROT3D_AX       ; angle X (0-127)\n");
            expressions::emit_simple_expr(&args[2], out, assets);
            out.push_str("    STB >ROT3D_AY       ; angle Y (0-127)\n");
            expressions::emit_simple_expr(&args[3], out, assets);
            out.push_str("    STB >ROT3D_AZ       ; angle Z (0-127)\n");

            // Set screen position from args[4]=x, args[5]=y
            expressions::emit_simple_expr(&args[4], out, assets);
            out.push_str("    STB >ROT3D_OX       ; screen X offset\n");
            expressions::emit_simple_expr(&args[5], out, assets);
            out.push_str("    STB >ROT3D_OY       ; screen Y offset\n");

            // Load 3D data pointer and call runtime (DP stays $C8, runtime uses extended addressing)
            out.push_str(&format!("    LDX #{}_3D_DATA  ; pointer to 3D data table\n", symbol));
            out.push_str("    JSR DRAW_VECTOR_3D_RUNTIME\n");

            out.push_str("    LDD #0\n    STD RESULT\n");
        }
        _ => {
            out.push_str("    ; ERROR: DRAW_VECTOR_3D first argument must be string literal\n");
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

    out.push_str("    ; DRAW_CIRCLE: Draw circle at (xc, yc) with radius\n");
    
    // Evaluate xc and store in DRAW_CIRCLE_XC
    expressions::emit_simple_expr(&args[0], out, assets);
    out.push_str("    TFR B,A\n");
    out.push_str("    STA DRAW_CIRCLE_XC\n");

    // Evaluate yc and store in DRAW_CIRCLE_YC
    expressions::emit_simple_expr(&args[1], out, assets);
    out.push_str("    TFR B,A\n");
    out.push_str("    STA DRAW_CIRCLE_YC\n");

    // Evaluate diam and store in DRAW_CIRCLE_DIAM
    expressions::emit_simple_expr(&args[2], out, assets);
    out.push_str("    TFR B,A\n");
    out.push_str("    STA DRAW_CIRCLE_DIAM\n");

    // Evaluate intensity (default $5F if not provided)
    if args.len() == 4 {
        expressions::emit_simple_expr(&args[3], out, assets);
        out.push_str("    TFR B,A\n");
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

/// DRAW_RECT with full variable support.
/// All-constant args go through `drawing::emit_draw_rect` (inline 4-line path);
/// any variable argument falls back to evaluating each operand into the
/// DRAW_RECT_X/Y/WIDTH/HEIGHT/INTENSITY byte slots and calling
/// DRAW_RECT_RUNTIME (mirrors `emit_draw_circle_full`).
fn emit_draw_rect_full(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    if args.len() != 4 && args.len() != 5 {
        out.push_str("    ; ERROR: DRAW_RECT requires 4 or 5 arguments\n");
        return;
    }

    if args.iter().all(|a| matches!(a, Expr::Number(_))) {
        drawing::emit_draw_rect(args, out);
        return;
    }

    out.push_str("    ; DRAW_RECT: x, y, width, height[, intensity] (variable args)\n");

    let slots = ["DRAW_RECT_X", "DRAW_RECT_Y", "DRAW_RECT_WIDTH", "DRAW_RECT_HEIGHT"];
    for (i, slot) in slots.iter().enumerate() {
        expressions::emit_simple_expr(&args[i], out, assets);
        out.push_str("    TFR B,A\n");
        out.push_str(&format!("    STA {}\n", slot));
    }

    if args.len() == 5 {
        expressions::emit_simple_expr(&args[4], out, assets);
        out.push_str("    TFR B,A\n");
        out.push_str("    STA DRAW_RECT_INTENSITY\n");
    } else {
        out.push_str("    LDA #$5F\n");
        out.push_str("    STA DRAW_RECT_INTENSITY\n");
    }

    out.push_str("    JSR DRAW_RECT_RUNTIME\n");
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

// ── Simulated SD game list (m6809 emulator preview) ───────────────────────
// The RP2350 target reads a real SD card via SYS_SD_* syscalls. The m6809
// build has no SD hardware, so the IDE preview simulates one from a folder in
// the user's home (`~/VectrexStudio/sd`, created if missing). Drop `.bin`
// files there and they appear in the menu. Scanned once, baked into ROM.

/// Absolute path of the simulated-SD folder, created if missing.
pub fn sim_sd_dir() -> std::path::PathBuf {
    let home = std::env::var("HOME")
        .or_else(|_| std::env::var("USERPROFILE"))
        .unwrap_or_default();
    std::path::Path::new(&home).join("VectrexStudio").join("sd")
}

/// The simulated game list: uppercase stems of `*.bin` in the sim-SD folder.
/// Scanned once per process (each IDE build is a fresh vpy_cli invocation).
fn sim_sd_files() -> &'static Vec<String> {
    static FILES: std::sync::OnceLock<Vec<String>> = std::sync::OnceLock::new();
    FILES.get_or_init(|| {
        let mut out: Vec<String> = Vec::new();
        let dir = sim_sd_dir();
        let _ = std::fs::create_dir_all(&dir); // create if missing
        if let Ok(entries) = std::fs::read_dir(&dir) {
            for e in entries.flatten() {
                let p = e.path();
                let is_bin = p.extension()
                    .and_then(|s| s.to_str())
                    .map(|s| s.eq_ignore_ascii_case("bin"))
                    .unwrap_or(false);
                if !is_bin { continue; }
                if let Some(stem) = p.file_stem().and_then(|s| s.to_str()) {
                    if stem.starts_with('.') { continue; } // hidden / macOS ._ junk
                    let mut name = stem.to_ascii_uppercase();
                    name.truncate(12); // 8.3-ish cap for the vector display
                    out.push(name);
                }
            }
        }
        out.sort();
        out.truncate(24); // cap the list
        out
    })
}

/// True if the module calls SD_FILE_COUNT / SD_FILE_NAME (so we emit the table).
pub fn module_uses_sd(module: &Module) -> bool {
    fn expr_uses(e: &Expr) -> bool {
        match e {
            Expr::Call(c) => {
                let n = c.name.to_ascii_uppercase();
                n == "SD_FILE_COUNT" || n == "SD_FILE_NAME" || c.args.iter().any(expr_uses)
            }
            _ => false,
        }
    }
    fn stmts_use(stmts: &[Stmt]) -> bool {
        stmts.iter().any(|s| match s {
            Stmt::Expr(e, _) => expr_uses(e),
            Stmt::Return(Some(e), _) => expr_uses(e),
            Stmt::Let { value, .. } => expr_uses(value),
            Stmt::Assign { value, .. } => expr_uses(value),
            Stmt::CompoundAssign { value, .. } => expr_uses(value),
            Stmt::If { cond, body, elifs, else_body, .. } => {
                expr_uses(cond) || stmts_use(body)
                    || elifs.iter().any(|(c, b)| expr_uses(c) || stmts_use(b))
                    || else_body.as_ref().map(|b| stmts_use(b)).unwrap_or(false)
            }
            Stmt::While { cond, body, .. } => expr_uses(cond) || stmts_use(body),
            Stmt::For { body, .. } => stmts_use(body),
            Stmt::ForIn { body, .. } => stmts_use(body),
            Stmt::Switch { cases, default, .. } => {
                cases.iter().any(|(_, b)| stmts_use(b))
                    || default.as_ref().map(|b| stmts_use(b)).unwrap_or(false)
            }
            _ => false,
        })
    }
    module.items.iter().any(|it| matches!(it, Item::Function(f) if stmts_use(&f.body)))
}

/// Emit the simulated SD name table + strings (helpers bank).
pub fn emit_sd_tables(out: &mut String) {
    let files = sim_sd_files();
    out.push_str(";**** Simulated SD game list (m6809 preview; ~/VectrexStudio/sd) ****\n");
    out.push_str("SD_NAME_TABLE:\n");
    if files.is_empty() {
        out.push_str("    FDB 0            ; no .bin files in the sim-SD folder\n");
    } else {
        for i in 0..files.len() {
            out.push_str(&format!("    FDB SD_NAME_{}\n", i));
        }
    }
    for (i, name) in files.iter().enumerate() {
        out.push_str(&format!("SD_NAME_{}:\n", i));
        out.push_str(&format!("    FCC \"{}\"\n", escape_string(name)));
        out.push_str("    FCB $80          ; Vectrex string terminator\n");
    }
    out.push('\n');
}

/// Collect all MSG_DEF(id, x, y, "text") calls from the module
pub fn collect_msg_entries(module: &Module) -> Vec<MsgEntry> {
    let mut entries = Vec::new();
    for item in &module.items {
        if let vpy_parser::Item::Function(func) = item {
            for stmt in &func.body {
                collect_msg_entries_from_stmt(stmt, &mut entries);
            }
        }
    }
    entries.sort_by_key(|e| e.id);
    entries
}

fn collect_msg_entries_from_stmt(stmt: &vpy_parser::Stmt, entries: &mut Vec<MsgEntry>) {
    match stmt {
        vpy_parser::Stmt::Expr(expr, _) => {
            if let Expr::Call(call) = expr {
                if call.name.to_uppercase() == "MSG_DEF" && call.args.len() == 4 {
                    let id = extract_int_lit(&call.args[0]).unwrap_or(0) as u8;
                    let x  = extract_int_lit(&call.args[1]).unwrap_or(0) as i8;
                    let y  = extract_int_lit(&call.args[2]).unwrap_or(0) as i8;
                    if let Expr::StringLit(s) = &call.args[3] {
                        entries.push(MsgEntry { id, x, y, text: s.clone() });
                    }
                }
            }
        }
        vpy_parser::Stmt::If { body, elifs, else_body, .. } => {
            for s in body { collect_msg_entries_from_stmt(s, entries); }
            for (_, b) in elifs { for s in b { collect_msg_entries_from_stmt(s, entries); } }
            if let Some(eb) = else_body { for s in eb { collect_msg_entries_from_stmt(s, entries); } }
        }
        vpy_parser::Stmt::While { body, .. } => {
            for s in body { collect_msg_entries_from_stmt(s, entries); }
        }
        vpy_parser::Stmt::For { body, .. } => {
            for s in body { collect_msg_entries_from_stmt(s, entries); }
        }
        _ => {}
    }
}

fn extract_int_lit(expr: &Expr) -> Option<i32> {
    match expr {
        Expr::Number(n) => Some(*n),
        _ => None,
    }
}

/// Emit PRINT_MSG_DISPATCH helper + PRINT_MSG_TABLE ROM data
/// Called after emit_print_text_strings so all string labels are defined
pub fn emit_msg_table(entries: &[MsgEntry], out: &mut String) {
    if entries.is_empty() {
        return;
    }

    let max_id = entries.iter().map(|e| e.id).max().unwrap_or(0);

    // Build id → entry map
    let mut entry_map: std::collections::HashMap<u8, &MsgEntry> = std::collections::HashMap::new();
    for e in entries {
        entry_map.insert(e.id, e);
    }

    // ── Dispatch helper routine ──────────────────────────────────────────────
    out.push_str(";**** PRINT_MSG Dispatch ****\n");
    out.push_str("PRINT_MSG_DISPATCH:\n");
    out.push_str("    ; VAR_ARG0 = msg_id (set by PRINT_MSG caller)\n");
    out.push_str("    LDB >VAR_ARG0+1      ; B = msg_id (low byte)\n");
    out.push_str("    BEQ PRINT_MSG_SKIP  ; id=0 → nothing to print\n");
    out.push_str("    DECB                ; 0-based index (id starts at 1)\n");
    out.push_str("    LSLB               ; B = index * 2\n");
    out.push_str("    LSLB               ; B = index * 4\n");
    out.push_str("    LDX #PRINT_MSG_TABLE\n");
    out.push_str("    ABX                ; X = &table[index * 4]\n");
    out.push_str("    LDB ,X+            ; B = x (signed byte)\n");
    out.push_str("    SEX                ; D = sign-extended x\n");
    out.push_str("    STD >VAR_ARG0\n");
    out.push_str("    LDB ,X+            ; B = y (signed byte)\n");
    out.push_str("    SEX                ; D = sign-extended y\n");
    out.push_str("    STD >VAR_ARG1\n");
    out.push_str("    LDX ,X             ; X = string pointer\n");
    out.push_str("    STX >VAR_ARG2\n");
    out.push_str("    JMP VECTREX_PRINT_TEXT  ; tail call (no RTS needed)\n");
    out.push_str("PRINT_MSG_SKIP:\n");
    out.push_str("    RTS\n\n");

    // ── Message table: 4 bytes per entry (x, y, ptr_hi, ptr_lo) ────────────
    out.push_str("PRINT_MSG_TABLE:\n");
    out.push_str("    ; 4 bytes/entry: x(signed), y(signed), string_ptr(2)\n");
    for id in 1..=max_id {
        if let Some(entry) = entry_map.get(&id) {
            let str_label = format!("PRINT_TEXT_STR_{}", hash_string(&entry.text));
            out.push_str(&format!(
                "    FCB {}  ; msg {} x\n    FCB {}  ; msg {} y\n    FDB {}  ; msg {} \"{}\"\n",
                entry.x as i32, id, entry.y as i32, id, str_label, id, entry.text
            ));
        } else {
            out.push_str(&format!("    FCB 0  ; id {} unused x\n    FCB 0  ; id {} unused y\n    FDB 0  ; id {} unused ptr\n", id, id, id));
        }
    }
    out.push_str("\n");
}

#[cfg(test)]
mod draw_recording_tests {
    use super::*;

    /// DRAW_RECORDING("clip", 0, 0, 128, frame) must resolve the recording symbol
    /// (_CLIP_VREC) and JSR the runtime, passing x/y/scale/frame through the
    /// DRAW_REC_* RAM args.
    #[test]
    fn draw_recording_emits_runtime_call_and_symbol() {
        let args = vec![
            Expr::StringLit("clip".to_string()),
            Expr::Number(0),
            Expr::Number(0),
            Expr::Number(128),
            Expr::Number(0), // frame counter (a plain VPy var at runtime; const here for the test)
        ];
        let mut out = String::new();
        let handled = emit_builtin("DRAW_RECORDING", &args, &mut out, &[]);
        assert!(handled, "DRAW_RECORDING must be handled as a builtin");
        assert!(out.contains("LDX #_CLIP_VREC"), "must resolve recording symbol:\n{out}");
        assert!(out.contains("JSR DRAW_RECORDING_RUNTIME"), "must call runtime:\n{out}");
        assert!(out.contains("STD >DRAW_REC_FRAME"), "must pass frame arg:\n{out}");
        assert!(out.contains("STA >DRAW_REC_SCALE"), "must pass scale arg:\n{out}");
    }
}