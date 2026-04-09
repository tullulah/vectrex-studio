//! Runtime Helper Functions
//!
//! Mathematical and utility functions

use vpy_parser::{Module, Item, Stmt, Expr, BinOp};
use std::collections::HashSet;
use super::ram_layout::RamLayout;

/// Analyze module to detect which runtime helpers are needed
/// Returns set of helper names that should be emitted
pub fn analyze_module_helpers(module: &Module) -> HashSet<String> {
    let mut needed = HashSet::new();

    // Scan all functions in module
    for item in &module.items {
        if let Item::Function(func) = item {
            for stmt in &func.body {
                analyze_stmt_for_helpers(stmt, &mut needed);
            }
        }
    }

    needed
}

/// Generate RAM definitions and array data (called BEFORE user functions)
/// Returns tuple: (ASM string, RamLayout for later use by generate_helpers)
pub fn generate_ram_and_arrays(module: &Module) -> Result<String, String> {
    let mut asm = String::new();
    
    // Analyze module to detect which helpers are needed (for RAM allocation)
    let needed = analyze_module_helpers(module);
    
    // Create RamLayout for RAM variable allocation
    let mut ram = RamLayout::new(0xC880); // Start at $C880 (Vectrex RAM: $C800-$CBFF)
    
    // Core scratch variables (always needed)
    ram.allocate("RESULT", 2, "Main result temporary");
    // NOTE: TMPVAL is an alias for RESULT - both use the same memory location for efficiency
    ram.allocate("TMPVAL", 2, "Temporary value storage (alias for RESULT)");
    ram.allocate("TMPPTR", 2, "Temporary pointer");
    ram.allocate("TMPPTR2", 2, "Temporary pointer 2");
    ram.allocate("VPY_MOVE_X", 1, "MOVE() current X offset (signed byte, 0 by default)");
    ram.allocate("VPY_MOVE_Y", 1, "MOVE() current Y offset (signed byte, 0 by default)");
    ram.allocate("TEMP_YX", 2, "Temporary Y/X coordinate storage");
    ram.allocate("BTN_PREV_STATE", 1, "Button edge-detection: holds bit 7,6,5,4 = prev press state for btn 1,2,3,4");
    ram.allocate("BTN_RAW", 1, "Raw PSG reg 14 (active-LOW: 0=pressed, 1=released) - Vectorblade pattern");
    
    // Conditional variables based on usage
    if needed.contains("PRINT_NUMBER") {
        ram.allocate("NUM_STR", 6, "Buffer for PRINT_NUMBER decimal output (5 digits + terminator)");
    }
    if needed.contains("RAND") || needed.contains("RAND_HELPER") {
        ram.allocate("RAND_SEED", 2, "Random seed for RAND()");
    }
    
    // Drawing helper variables
    // NOTE: Check both DRAW_CIRCLE and DRAW_CIRCLE_RUNTIME because the analysis may add either
    if needed.contains("DRAW_CIRCLE") || needed.contains("DRAW_CIRCLE_RUNTIME") {
        ram.allocate("DRAW_CIRCLE_XC", 1, "Circle center X");
        ram.allocate("DRAW_CIRCLE_YC", 1, "Circle center Y");
        ram.allocate("DRAW_CIRCLE_DIAM", 1, "Circle diameter");
        ram.allocate("DRAW_CIRCLE_INTENSITY", 1, "Circle intensity");
        ram.allocate("DRAW_CIRCLE_RADIUS", 1, "Circle radius (diam/2) - used in segment drawing");
        ram.allocate("DRAW_CIRCLE_TEMP", 8, "Circle temporary buffer (8 bytes: radius16, a, b, c, d, --, --)  a=0.383r b=0.324r c=0.217r d=0.076r");
    }
    
    // NOTE: Check both DRAW_RECT and DRAW_RECT_RUNTIME
    if needed.contains("DRAW_RECT") || needed.contains("DRAW_RECT_RUNTIME") {
        ram.allocate("DRAW_RECT_X", 1, "Rectangle X");
        ram.allocate("DRAW_RECT_Y", 1, "Rectangle Y");
        ram.allocate("DRAW_RECT_WIDTH", 1, "Rectangle width");
        ram.allocate("DRAW_RECT_HEIGHT", 1, "Rectangle height");
        ram.allocate("DRAW_RECT_INTENSITY", 1, "Rectangle intensity");
    }
    
    // DRAW_VEC_INTENSITY always needed: SET_INTENSITY writes to it unconditionally
    ram.allocate("DRAW_VEC_INTENSITY", 1, "Vector intensity override (0=use vector data)");

    // DRAW_VECTOR / DRAW_VECTOR_EX variables (CRITICAL - MISSING!)
    if needed.contains("DRAW_VECTOR") || needed.contains("DRAW_VECTOR_EX") {
        ram.allocate("DRAW_VEC_X_HI", 1, "Vector draw X high byte (16-bit screen_x)");
        ram.allocate("DRAW_VEC_X", 1, "Vector draw X offset");
        ram.allocate("DRAW_VEC_Y", 1, "Vector draw Y offset");
        
        // CRITICAL FIX: Add padding to prevent collision with TEMP_YX (usually allocated at offset 6)
        ram.allocate("MIRROR_PAD", 16, "Safety padding to prevent MIRROR flag corruption");

        ram.allocate("MIRROR_X", 1, "X mirror flag (0=normal, 1=flip)");
        ram.allocate("MIRROR_Y", 1, "Y mirror flag (0=normal, 1=flip)");
    }
    
    // DRAW_VECTOR_3D rotation scratch variables
    if needed.contains("DRAW_VECTOR_3D") {
        ram.allocate("ROT3D_AX", 1, "3D raw angle X (0-127)");
        ram.allocate("ROT3D_AY", 1, "3D raw angle Y (0-127)");
        ram.allocate("ROT3D_AZ", 1, "3D raw angle Z (0-127)");
        // ROT3D_COS_X/Y/Z repurposed: now store (angle+32)&0x7F for cos-offset LUT lookup
        // (sin angle is ROT3D_AX/AY/AZ directly; cos = sin(angle+32))
        ram.allocate("ROT3D_COS_X", 1, "3D cos angle offset for X axis: (AX+32)&0x7F");
        ram.allocate("ROT3D_COS_Y", 1, "3D cos angle offset for Y axis: (AY+32)&0x7F");
        ram.allocate("ROT3D_COS_Z", 1, "3D cos angle offset for Z axis: (AZ+32)&0x7F");
        ram.allocate("ROT3D_OX", 1, "3D draw X offset");
        ram.allocate("ROT3D_OY", 1, "3D draw Y offset");
        ram.allocate("ROT3D_PC", 1, "3D path/vertex count remaining");
        ram.allocate("ROT3D_PT_REM", 1, "3D remaining points in current path");
        ram.allocate("ROT3D_CLOSED", 1, "3D path closed flag");
        ram.allocate("ROT3D_RX", 1, "3D raw x");
        ram.allocate("ROT3D_RY", 1, "3D raw y");
        ram.allocate("ROT3D_RZ", 1, "3D raw z");
        ram.allocate("ROT3D_Y1", 1, "3D intermediate y after X-axis rotation");
        ram.allocate("ROT3D_Z1", 1, "3D intermediate z after X-axis rotation");
        ram.allocate("ROT3D_X2", 1, "3D intermediate x after Y-axis rotation");
        ram.allocate("ROT3D_SCR_X", 1, "3D final screen x");
        ram.allocate("ROT3D_SCR_Y", 1, "3D final screen y");
        ram.allocate("ROT3D_PREV_X", 1, "3D previous screen x");
        ram.allocate("ROT3D_PREV_Y", 1, "3D previous screen y");
        ram.allocate("ROT3D_FIRST_X", 1, "3D first screen x (for closed path)");
        ram.allocate("ROT3D_FIRST_Y", 1, "3D first screen y (for closed path)");
        ram.allocate("ROT3D_TEMP", 1, "3D rotation temp 1");
        ram.allocate("ROT3D_TEMP2", 1, "3D rotation temp 2");
        // Rotated vertex cache: up to 127 unique vertices × 2 bytes (x', y')
        ram.allocate("ROT3D_VBUF", 254, "3D rotated vertex cache (127 verts × 2 bytes: x',y')");
    }

    // DRAW_LINE argument buffer (10 bytes: x0, y0, x1, y1, intensity)
    ram.allocate("DRAW_LINE_ARGS", 10, "DRAW_LINE argument buffer (x0,y0,x1,y1,intensity)");
    
    // DRAW_LINE segmentation variables (always needed if DRAW_LINE exists)
    // FIX (2026-01-18): Both remaining variables need 2 bytes (16-bit) for segment 2
    ram.allocate("VLINE_DX_16", 2, "DRAW_LINE dx (16-bit)");
    ram.allocate("VLINE_DY_16", 2, "DRAW_LINE dy (16-bit)");
    ram.allocate("VLINE_DX", 1, "DRAW_LINE dx clamped (8-bit)");
    ram.allocate("VLINE_DY", 1, "DRAW_LINE dy clamped (8-bit)");
    ram.allocate("VLINE_DY_REMAINING", 2, "DRAW_LINE remaining dy for segment 2 (16-bit)");
    ram.allocate("VLINE_DX_REMAINING", 2, "DRAW_LINE remaining dx for segment 2 (16-bit)");
    
    // Level system variables (vplay-aware)
    if needed.contains("SHOW_LEVEL") || needed.contains("SHOW_LEVEL_RUNTIME")
        || needed.contains("LOAD_LEVEL") || needed.contains("LOAD_LEVEL_RUNTIME")
        || needed.contains("UPDATE_LEVEL_RUNTIME")
        || needed.contains("LEVEL_COLLISION_Y_RUNTIME")
    {
        ram.allocate("LEVEL_PTR", 2, "Pointer to currently loaded level header");
        ram.allocate("LEVEL_LOADED", 1, "Level loaded flag (0=not loaded, 1=loaded)");
        // Legacy tile-based vars (kept for backward compat / GET_LEVEL_WIDTH etc.)
        ram.allocate("LEVEL_WIDTH", 1, "Level width (legacy tile API)");
        ram.allocate("LEVEL_HEIGHT", 1, "Level height (legacy tile API)");
        ram.allocate("LEVEL_TILE_SIZE", 1, "Tile size (legacy tile API)");
        ram.allocate("LEVEL_Y_IDX", 1, "SHOW_LEVEL row counter (legacy)");
        ram.allocate("LEVEL_X_IDX", 1, "SHOW_LEVEL column counter (legacy)");
        ram.allocate("LEVEL_TEMP", 1, "SHOW_LEVEL temporary byte (legacy)");
        // vplay layer counts and ROM pointers
        ram.allocate("LEVEL_BG_COUNT", 1, "BG object count");
        ram.allocate("LEVEL_GP_COUNT", 1, "GP object count");
        ram.allocate("LEVEL_FG_COUNT", 1, "FG object count");
        ram.allocate("CAMERA_X", 2, "Camera X scroll offset (16-bit signed world units)");
        ram.allocate("CAMERA_Y", 2, "Camera Y scroll offset (16-bit signed world units)");
        ram.allocate("LEVEL_BG_ROM_PTR", 2, "BG layer ROM pointer");
        ram.allocate("LEVEL_GP_ROM_PTR", 2, "GP layer ROM pointer");
        ram.allocate("LEVEL_FG_ROM_PTR", 2, "FG layer ROM pointer");
        ram.allocate("LEVEL_GP_PTR", 2, "GP active pointer (RAM buffer after LOAD_LEVEL)");
        ram.allocate("LEVEL_BANK", 1, "Bank ID for current level (for multibank)");
        // SHOW_LEVEL_RUNTIME draw temps (shared with DRAW_VECTOR if not already allocated)
        if !needed.contains("DRAW_VECTOR") && !needed.contains("DRAW_VECTOR_EX") {
            ram.allocate("DRAW_VEC_X_HI", 1, "SHOW_LEVEL: vector draw X high byte (16-bit)");
            ram.allocate("DRAW_VEC_X", 1, "SHOW_LEVEL: vector draw X");
            ram.allocate("DRAW_VEC_Y", 1, "SHOW_LEVEL: vector draw Y");
            ram.allocate("MIRROR_X", 1, "SHOW_LEVEL: mirror X flag");
            ram.allocate("MIRROR_Y", 1, "SHOW_LEVEL: mirror Y flag");
            ram.allocate("DRAW_VEC_INTENSITY", 1, "SHOW_LEVEL: intensity override");
        }
        // Clipped-path draw loop tracker
        ram.allocate("SLR_CUR_X", 1, "SHOW_LEVEL: tracked beam X for per-segment clipping");
        // GP objects RAM buffer (max 32 objects × 15 bytes)
        ram.allocate("LEVEL_GP_BUFFER", 32 * 15, "GP objects RAM buffer (max 32 objects × 15 bytes)");
        // LEVEL_COLLISION_Y input/scratch variables
        ram.allocate("LCOL_PX", 2, "LEVEL_COLLISION_Y player world_x input (16-bit)");
        ram.allocate("LCOL_BEST_Y", 1, "LEVEL_COLLISION_Y best floor y found (signed byte)");
        ram.allocate("LCOL_PY", 1, "LEVEL_COLLISION_Y player feet Y (player_y - player_hh)");
        ram.allocate("LCOL_PHH", 1, "LEVEL_COLLISION_Y player half_height");
        // Physics / collision temporaries
        ram.allocate("UGPC_OUTER_IDX", 1, "GP-GP outer loop index");
        ram.allocate("UGPC_OUTER_MAX", 1, "GP-GP outer loop max (count-1)");
        ram.allocate("UGPC_INNER_IDX", 1, "GP-GP inner loop index");
        ram.allocate("UGPC_DX", 2, "GP-GP |dx| (16-bit)");
        ram.allocate("UGPC_DIST", 2, "GP-GP Manhattan distance (16-bit)");
        ram.allocate("UGFC_GP_IDX", 1, "GP-FG outer loop GP index");
        ram.allocate("UGFC_FG_COUNT", 1, "GP-FG inner loop FG count");
        ram.allocate("UGFC_DX", 1, "GP-FG |dx|");
        ram.allocate("UGFC_DY", 1, "GP-FG |dy|");
    }
    
    // Text scale (2 bytes): written by SET_TEXT_SIZE, read by VECTREX_PRINT_TEXT/NUMBER
    // Vec_Text_Height ($C82A): signed byte, -n (default $F8 = -8 = normal)
    // Vec_Text_Width ($C82B): unsigned byte, n*9 (default 72 = $48 = normal)
    if needed.contains("PRINT_TEXT") || needed.contains("PRINT_NUMBER") {
        ram.allocate("TEXT_SCALE_H", 1, "Character height for Print_Str_d (default $F8 = -8, normal)");
        ram.allocate("TEXT_SCALE_W", 1, "Character width for Print_Str_d (default $48 = 72, normal)");
    }

// Function argument slots (used by PRINT_TEXT, etc.) - at fixed address in upper RAM
    // These need to be at a fixed location for cross-bank compatibility
    // CRITICAL: Must be within Vectrex 1KB RAM ($C800-$CBFF) — $CFxx is unmapped!
    // Placed at $CB80, well below stack ($CBEA grows down, ~106 bytes headroom)
    ram.allocate_fixed("VAR_ARG0", 0xCB80, 2, "Function argument 0 (16-bit)");
    ram.allocate_fixed("VAR_ARG1", 0xCB82, 2, "Function argument 1 (16-bit)");
    ram.allocate_fixed("VAR_ARG2", 0xCB84, 2, "Function argument 2 (16-bit)");
    ram.allocate_fixed("VAR_ARG3", 0xCB86, 2, "Function argument 3 (16-bit)");
    ram.allocate_fixed("VAR_ARG4", 0xCB88, 2, "Function argument 4 (16-bit)");

    // CRITICAL (2026-01-20): Multibank bank tracking variable
    // Required for cross-bank function calls and bank switching wrappers
    // Must be at fixed address for all banks to access
    ram.allocate_fixed("CURRENT_ROM_BANK", 0xCB8A, 1, "Current ROM bank ID (multibank tracking)");

    // Audio system variables at FIXED addresses in upper RAM
    // These are allocated AFTER VAR_ARG0-4 at $CBEB onwards
    use crate::m6809::functions::has_audio_calls;
    if has_audio_calls(module) {
        ram.allocate_fixed("PSG_MUSIC_PTR", 0xCBEB, 2, "PSG music data pointer");
        ram.allocate_fixed("PSG_MUSIC_START", 0xCBED, 2, "PSG music start pointer (for loops)");
        ram.allocate_fixed("PSG_MUSIC_ACTIVE", 0xCBEF, 1, "PSG music active flag");
        ram.allocate_fixed("PSG_IS_PLAYING", 0xCBF0, 1, "PSG playing flag");
        ram.allocate_fixed("PSG_DELAY_FRAMES", 0xCBF1, 1, "PSG frame delay counter");
        ram.allocate_fixed("PSG_MUSIC_BANK", 0xCBF2, 1, "PSG music bank ID (for multibank)");
        ram.allocate_fixed("SFX_PTR", 0xCBF3, 2, "SFX data pointer");
        ram.allocate_fixed("SFX_ACTIVE", 0xCBF5, 1, "SFX active flag");
        ram.allocate_fixed("SFX_BANK", 0xCBF6, 1, "SFX bank ID (for multibank)");
    }

    if needed.contains("BEEP") {
        ram.allocate("BEEP_FRAMES_LEFT", 1, "Beep countdown timer (frames remaining)");
    }

    if module.meta.interleaved_frames.is_some() {
        ram.allocate("FRAME_PARITY", 1, "Interleaved frame group counter");
    }

    // =========================================================================
    // USER VARIABLES (continue allocation after system vars)
    // =========================================================================

    // Generate user variables using the same RamLayout instance
    let user_vars_result = crate::m6809::variables::generate_user_variables(module, &mut ram)?;
    
    // =========================================================================
    // EMIT EQU DEFINITIONS
    // =========================================================================
    asm.push_str(";***************************************************************************\n");
    asm.push_str("; === RAM VARIABLE DEFINITIONS ===\n");
    asm.push_str(";***************************************************************************\n");
    asm.push_str(&ram.emit_equ_definitions());
    asm.push_str("\n");
    
    // CRITICAL FIX (2026-01-18): Emit array data BEFORE code
    // Arrays must be defined before first use to avoid forward references in single-pass assembler
    asm.push_str(&crate::m6809::variables::emit_array_data(module));
    
    // NOTE (2026-01-19): emit_array_aliases() is no longer needed
    // We now use context::is_mutable_array() to determine the correct label at emit time
    // This avoids EQU forward reference issues with the assembler
    
    // Emit user variable internal definitions (builtin aliases)
    asm.push_str(&user_vars_result);
    asm.push_str("\n");
    
    Ok(asm)
}

/// Recursively analyze statement for helper usage
fn analyze_stmt_for_helpers(stmt: &Stmt, needed: &mut HashSet<String>) {
    match stmt {
        Stmt::Expr(expr, _) => analyze_expr_for_helpers(expr, needed),
        Stmt::Assign { value, .. } => analyze_expr_for_helpers(value, needed),
        Stmt::If { cond, body, elifs, else_body, .. } => {
            analyze_expr_for_helpers(cond, needed);
            for s in body {
                analyze_stmt_for_helpers(s, needed);
            }
            for (elif_cond, elif_body) in elifs {
                analyze_expr_for_helpers(elif_cond, needed);
                for s in elif_body {
                    analyze_stmt_for_helpers(s, needed);
                }
            }
            if let Some(else_stmts) = else_body {
                for s in else_stmts {
                    analyze_stmt_for_helpers(s, needed);
                }
            }
        }
        Stmt::While { cond, body, .. } => {
            analyze_expr_for_helpers(cond, needed);
            for s in body {
                analyze_stmt_for_helpers(s, needed);
            }
        }
        Stmt::Return(Some(expr), _) => analyze_expr_for_helpers(expr, needed),
        _ => {}
    }
}

/// Recursively analyze expression for helper usage
fn analyze_expr_for_helpers(expr: &Expr, needed: &mut HashSet<String>) {
    match expr {
        // Builtin calls that may need runtime helpers
        Expr::Call(call_info) => {
            let name_upper = call_info.name.to_uppercase();
            let args = &call_info.args;
            
            // Text/Number printing
            if name_upper == "PRINT_TEXT" {
                needed.insert("PRINT_TEXT".to_string());
            }
            if name_upper == "PRINT_NUMBER" {
                needed.insert("PRINT_NUMBER".to_string());
            }
            
            // Drawing helpers: Always needed when called (even with constant args)
            if name_upper == "DRAW_CIRCLE" {
                needed.insert("DRAW_CIRCLE".to_string());
                needed.insert("DRAW_CIRCLE_RUNTIME".to_string());
            }
            if name_upper == "DRAW_RECT" {
                needed.insert("DRAW_RECT".to_string());
                needed.insert("DRAW_RECT_RUNTIME".to_string());
            }
            if name_upper == "DRAW_LINE" {
                needed.insert("DRAW_LINE_WRAPPER".to_string());
            }
            if name_upper == "DRAW_VECTOR" {
                needed.insert("DRAW_VECTOR".to_string());
            }
            if name_upper == "DRAW_VECTOR_EX" {
                needed.insert("DRAW_VECTOR_EX".to_string());
            }
            if name_upper == "DRAW_VECTOR_3D" {
                needed.insert("DRAW_VECTOR_3D".to_string());
                needed.insert("DRAW_VECTOR".to_string()); // for DRAW_VEC_X/Y RAM vars
            }
            
            // Joystick helpers: Always needed when called
            if name_upper == "J1_X" {
                needed.insert("J1X_BUILTIN".to_string());
            }
            if name_upper == "J1_Y" {
                needed.insert("J1Y_BUILTIN".to_string());
            }
            if name_upper == "J2_X" {
                needed.insert("J2X_BUILTIN".to_string());
            }
            if name_upper == "J2_Y" {
                needed.insert("J2Y_BUILTIN".to_string());
            }
            
            // Level system helpers
            if name_upper == "SHOW_LEVEL" {
                needed.insert("SHOW_LEVEL_RUNTIME".to_string());
                // SHOW_LEVEL_RUNTIME calls Draw_Sync_List_At_With_Mirrors,
                // which is emitted in drawing.rs when DRAW_VECTOR is in needed.
                needed.insert("DRAW_VECTOR".to_string());
            }
            if name_upper == "LOAD_LEVEL" {
                needed.insert("LOAD_LEVEL".to_string());
                needed.insert("LOAD_LEVEL_RUNTIME".to_string());
            }
            if name_upper == "UPDATE_LEVEL" {
                needed.insert("UPDATE_LEVEL_RUNTIME".to_string());
            }
            if name_upper == "LEVEL_COLLISION_Y" {
                needed.insert("LEVEL_COLLISION_Y_RUNTIME".to_string());
            }
            
// Math helpers: Need runtime if operands contain variables
            if name_upper == "SQRT" && has_variable_args(args) {
                needed.insert("SQRT_HELPER".to_string());
                needed.insert("DIV16".to_string()); // SQRT uses DIV16
            }
            if name_upper == "POW" && has_variable_args(args) {
                needed.insert("POW_HELPER".to_string());
            }
            if name_upper == "ATAN2" && has_variable_args(args) {
                needed.insert("ATAN2_HELPER".to_string());
            }
            if name_upper == "RAND" {
                needed.insert("RAND_HELPER".to_string());
            }
            if name_upper == "RAND_RANGE" {
                needed.insert("RAND_RANGE_HELPER".to_string());
                needed.insert("RAND_HELPER".to_string()); // RAND_RANGE uses RAND
            }
            if name_upper == "BEEP" {
                needed.insert("BEEP".to_string());
            }

            // Recursively analyze arguments
            for arg in args {
                analyze_expr_for_helpers(arg, needed);
            }
        }
        
        // Binary operations that may need math helpers
        Expr::Binary { left, op, right } => {
            // Check if operands are variables (not constants)
            let left_is_const = matches!(**left, Expr::Number(_));
            let right_is_const = matches!(**right, Expr::Number(_));
            
            if !left_is_const || !right_is_const {
                match op {
                    BinOp::Mul => { needed.insert("MUL16".to_string()); }
                    BinOp::Div | BinOp::FloorDiv => { needed.insert("DIV16".to_string()); }
                    BinOp::Mod => { needed.insert("MOD16".to_string()); }
                    _ => {}
                }
            }
            
            analyze_expr_for_helpers(left, needed);
            analyze_expr_for_helpers(right, needed);
        }
        
        // Other expression types (Not and BitNot are unary operations)
        Expr::Not(operand) | Expr::BitNot(operand) => analyze_expr_for_helpers(operand, needed),
        Expr::Index { target, index } => {
            analyze_expr_for_helpers(target, needed);
            analyze_expr_for_helpers(index, needed);
        }
        Expr::List(items) => {
            for item in items {
                analyze_expr_for_helpers(item, needed);
            }
        }
        _ => {}
    }
}

/// Check if any argument is not a constant (i.e., contains variables)
fn has_variable_args(args: &[Expr]) -> bool {
    args.iter().any(|arg| !matches!(arg, Expr::Number(_) | Expr::StringLit(_)))
}

/// Get BIOS function address from VECTREX.I
/// Returns the address as a hex string (e.g., "$F1AA")
/// Falls back to hardcoded value if VECTREX.I cannot be read
fn get_bios_address(symbol_name: &str, fallback_address: &str) -> String {
    // Try to get from VECTREX.I
    let possible_paths = vec![
        "ide/frontend/public/include/VECTREX.I",
        "../ide/frontend/public/include/VECTREX.I",
        "../../ide/frontend/public/include/VECTREX.I",
        "./ide/frontend/public/include/VECTREX.I",
    ];
    
    for path in &possible_paths {
        if let Ok(content) = std::fs::read_to_string(path) {
            // Parse VECTREX.I to find the symbol
            for line in content.lines() {
                let line = line.trim();
                if line.is_empty() || line.starts_with(';') {
                    continue;
                }
                
                // Parse lines like: "Wait_Recal  EQU     $F192"
                if let Some(equ_pos) = line.find("EQU") {
                    let name_part = line[..equ_pos].trim();
                    let value_part = line[equ_pos + 3..].trim();
                    
                    if name_part.eq_ignore_ascii_case(symbol_name) {
                        // Extract just the address (e.g., "$F1AA" or "$F1AA   ; comment")
                        if let Some(addr) = value_part.split_whitespace().next() {
                            if addr.starts_with('$') || addr.starts_with("0x") {
                                return addr.to_string();
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Fallback to hardcoded value
    fallback_address.to_string()
}

pub fn generate_helpers(module: &Module, is_multibank: bool) -> Result<String, String> {
    let mut asm = String::new();

    // Import has_audio_calls for audio helper detection
    use crate::m6809::functions::has_audio_calls;

    // Analyze module to detect which helpers are needed
    let needed = analyze_module_helpers(module);
    
    // Get BIOS function addresses from VECTREX.I
    let dp_to_c8 = get_bios_address("DP_to_C8", "$F1AF");
    
    // NOTE: RAM allocation and EQU definitions are now handled by generate_ram_and_arrays()
    // which is called BEFORE user functions in mod.rs
    // This ensures arrays are defined before first use
    
    asm.push_str(";***************************************************************************\n");
    asm.push_str("; RUNTIME HELPERS\n");
    asm.push_str(";***************************************************************************\n\n");
    
    // VECTREX_PRINT_TEXT: Call Print_Str_d with proper setup (CONDITIONAL)
    // Only emit if PRINT_TEXT is actually used in code
    if needed.contains("PRINT_TEXT") {
        asm.push_str("VECTREX_PRINT_TEXT:\n");
        asm.push_str("    ; VPy signature: PRINT_TEXT(x, y, string)\n");
        asm.push_str("    ; BIOS signature: Print_Str_d(A=Y, B=X, U=string)\n");
        asm.push_str("    ; NOTE: Do NOT set VIA_cntl=$98 here - would release /ZERO prematurely\n");
        asm.push_str("    ;       causing integrators to drift toward joystick DAC value.\n");
        asm.push_str("    ;       Moveto_d_7F (called by Print_Str_d) handles VIA_cntl via $CE.\n");
        asm.push_str("    LDA #$D0\n");
        asm.push_str("    TFR A,DP       ; Set Direct Page to $D0 for BIOS\n");
        asm.push_str("    JSR Intensity_5F ; Ensure consistent text brightness (DP=$D0 required)\n");
        asm.push_str("    JSR Reset0Ref   ; Reset beam to center before positioning text\n");
        asm.push_str("    LDU VAR_ARG2   ; string pointer\n");
        asm.push_str("    LDA >TEXT_SCALE_H ; height (signed byte, e.g. $F8=-8)\n");
        asm.push_str("    STA >$C82A      ; Vec_Text_Height: controls character Y scale\n");
        asm.push_str("    LDA >TEXT_SCALE_W ; width (unsigned byte, e.g. 72)\n");
        asm.push_str("    STA >$C82B      ; Vec_Text_Width: controls character X spacing\n");
        asm.push_str("    LDA >VAR_ARG1+1 ; Y coordinate\n");
        asm.push_str("    LDB >VAR_ARG0+1 ; X coordinate\n");
        asm.push_str("    JSR Print_Str_d\n");
        asm.push_str("    LDA #$F8\n");
        asm.push_str("    STA >$C82A      ; Restore Vec_Text_Height to normal (-8)\n");
        asm.push_str("    LDA #$48\n");
        asm.push_str("    STA >$C82B      ; Restore Vec_Text_Width to normal (72)\n");
        asm.push_str(&format!("    JSR {}      ; DP_to_C8 - restore DP before return\n", dp_to_c8));
        asm.push_str("    RTS\n\n");
    }
    
    // VECTREX_PRINT_NUMBER: Print number at position (CONDITIONAL)
    // Only emit if PRINT_NUMBER is actually used in code
    if needed.contains("PRINT_NUMBER") {
        asm.push_str("VECTREX_PRINT_NUMBER:\n");
        asm.push_str("    ; Print signed decimal number (-9999 to 9999)\n");
        asm.push_str("    ; ARG0=x, ARG1=y, ARG2=value\n");
        asm.push_str("    ;\n");
        asm.push_str("    ; STEP 1: Convert number to decimal string (DP=$C8)\n");
        asm.push_str("    LDD >VAR_ARG2   ; Load 16-bit value (safe: DP=$C8)\n");
        asm.push_str("    STD >TMPVAL      ; Save to temp\n");
        asm.push_str("    LDX #NUM_STR    ; String buffer pointer\n");
        asm.push_str("    \n");
        asm.push_str("    ; Check sign: negative values get '-' prefix and are negated\n");
        asm.push_str("    CMPD #0\n");
        asm.push_str("    BPL .PN_DIV1000  ; D >= 0: go directly to digit conversion\n");
        asm.push_str("    LDA #'-'\n");
        asm.push_str("    STA ,X+          ; Store '-', advance buffer pointer\n");
        asm.push_str("    LDD >TMPVAL\n");
        asm.push_str("    COMA\n");
        asm.push_str("    COMB\n");
        asm.push_str("    ADDD #1          ; Two's complement negation -> absolute value\n");
        asm.push_str("    STD >TMPVAL\n");
        asm.push_str("    \n");
        asm.push_str("    ; --- 1000s digit ---\n");
        asm.push_str(".PN_DIV1000:\n");
        asm.push_str("    CLR ,X           ; Counter = 0 (in buffer)\n");
        asm.push_str(".PN_L1000:\n");
        asm.push_str("    LDD >TMPVAL\n");
        asm.push_str("    SUBD #1000\n");
        asm.push_str("    BMI .PN_D1000\n");
        asm.push_str("    STD >TMPVAL      ; Store reduced value\n");
        asm.push_str("    INC ,X           ; Increment digit counter\n");
        asm.push_str("    BRA .PN_L1000\n");
        asm.push_str(".PN_D1000:\n");
        asm.push_str("    LDA ,X           ; Get count\n");
        asm.push_str("    ADDA #'0'        ; Convert to ASCII\n");
        asm.push_str("    STA ,X+          ; Store and advance\n");
        asm.push_str("    \n");
        asm.push_str("    ; --- 100s digit ---\n");
        asm.push_str("    CLR ,X\n");
        asm.push_str(".PN_L100:\n");
        asm.push_str("    LDD >TMPVAL\n");
        asm.push_str("    SUBD #100\n");
        asm.push_str("    BMI .PN_D100\n");
        asm.push_str("    STD >TMPVAL\n");
        asm.push_str("    INC ,X\n");
        asm.push_str("    BRA .PN_L100\n");
        asm.push_str(".PN_D100:\n");
        asm.push_str("    LDA ,X\n");
        asm.push_str("    ADDA #'0'\n");
        asm.push_str("    STA ,X+\n");
        asm.push_str("    \n");
        asm.push_str("    ; --- 10s digit ---\n");
        asm.push_str("    CLR ,X\n");
        asm.push_str(".PN_L10:\n");
        asm.push_str("    LDD >TMPVAL\n");
        asm.push_str("    SUBD #10\n");
        asm.push_str("    BMI .PN_D10\n");
        asm.push_str("    STD >TMPVAL\n");
        asm.push_str("    INC ,X\n");
        asm.push_str("    BRA .PN_L10\n");
        asm.push_str(".PN_D10:\n");
        asm.push_str("    LDA ,X\n");
        asm.push_str("    ADDA #'0'\n");
        asm.push_str("    STA ,X+\n");
        asm.push_str("    \n");
        asm.push_str("    ; --- 1s digit (remainder) ---\n");
        asm.push_str("    LDD >TMPVAL\n");
        asm.push_str("    ADDB #'0'        ; Low byte = ones digit\n");
        asm.push_str("    STB ,X+          ; Store digit\n");
        asm.push_str("    LDA #$80          ; Terminator (same format as FCC/FCB $80 strings)\n");
        asm.push_str("    STA ,X\n");
        asm.push_str("    \n");
        asm.push_str(".PN_AFTER_CONVERT:\n");
        asm.push_str("    ; STEP 2: Set up BIOS and print (NOW change DP to $D0)\n");
        asm.push_str("    ; NOTE: Do NOT set VIA_cntl=$98 - would release /ZERO prematurely\n");
        asm.push_str("    LDA #$D0\n");
        asm.push_str("    TFR A,DP         ; Set Direct Page to $D0 for BIOS (inline - JSR $F1AA unreliable in emulator)\n");
        asm.push_str("    JSR Reset0Ref    ; Reset beam to center before positioning text\n");
        asm.push_str("    LDU #NUM_STR     ; String pointer\n");
        asm.push_str("    LDA >TEXT_SCALE_H ; height (signed byte)\n");
        asm.push_str("    STA >$C82A       ; Vec_Text_Height: character Y scale\n");
        asm.push_str("    LDA >TEXT_SCALE_W ; width (unsigned byte)\n");
        asm.push_str("    STA >$C82B       ; Vec_Text_Width: character X spacing\n");
        asm.push_str("    LDA >VAR_ARG1+1  ; Y coordinate\n");
        asm.push_str("    LDB >VAR_ARG0+1  ; X coordinate\n");
        asm.push_str("    JSR Print_Str_d  ; Print using BIOS (A=Y, B=X, U=string)\n");
        asm.push_str("    LDA #$F8\n");
        asm.push_str("    STA >$C82A       ; Restore Vec_Text_Height to normal (-8)\n");
        asm.push_str("    LDA #$48\n");
        asm.push_str("    STA >$C82B       ; Restore Vec_Text_Width to normal (72)\n");
        asm.push_str(&format!("    JSR {}      ; Restore DP to $C8\n", dp_to_c8));
        asm.push_str("    RTS\n\n");
    }
    
    // Call module-specific runtime helpers with analyzed needed set
    super::math::emit_runtime_helpers(&mut asm, &needed);
    super::joystick::emit_runtime_helpers(&mut asm, &needed);
    super::drawing::emit_runtime_helpers(&mut asm, &needed);
    super::level::emit_runtime_helpers(&mut asm, &needed);
    super::utilities::emit_runtime_helpers(&mut asm, &needed);
    
    // PLAY_MUSIC_RUNTIME and STOP_MUSIC_RUNTIME: Always emit if audio calls exist
    // (has_audio_calls already imported at top of function)
    if has_audio_calls(module) {
        emit_play_music_runtime(&mut asm);
    }

    // AUDIO_UPDATE: Auto-inject if PLAY_MUSIC or PLAY_SFX detected
    if has_audio_calls(module) {
        emit_audio_update_helper(&mut asm, is_multibank);
        emit_play_sfx_runtime(&mut asm);
    }

    // BEEP_UPDATE_RUNTIME: Auto-inject if beep() is used
    if needed.contains("BEEP") {
        emit_beep_update_runtime(&mut asm);
    }

    // DRAW_VECTOR_3D_RUNTIME: 3D rotation and drawing
    if needed.contains("DRAW_VECTOR_3D") {
        emit_draw_vector_3d_runtime(&mut asm);
    }

    Ok(asm)
}

/// Emit PLAY_MUSIC_RUNTIME and STOP_MUSIC_RUNTIME helpers
/// Called when PLAY_MUSIC() builtin is used in code
fn emit_play_music_runtime(asm: &mut String) {
    asm.push_str(
        "; ============================================================================\n\
        ; PSG DIRECT MUSIC PLAYER (inspired by Christman2024/malbanGit)\n\
        ; ============================================================================\n\
        ; Writes directly to PSG chip using WRITE_PSG sequence\n\
        ;\n\
        ; Music data format (frame-based):\n\
        ;   FCB count           ; Number of register writes this frame\n\
        ;   FCB reg, val        ; PSG register/value pairs\n\
        ;   ...                 ; Repeat for each register\n\
        ;   FCB $FF             ; End marker\n\
        ;\n\
        ; PSG Registers:\n\
        ;   0-1: Channel A frequency (12-bit)\n\
        ;   2-3: Channel B frequency\n\
        ;   4-5: Channel C frequency\n\
        ;   6:   Noise period\n\
        ;   7:   Mixer control (enable/disable channels)\n\
        ;   8-10: Channel A/B/C volume\n\
        ;   11-12: Envelope period\n\
        ;   13:  Envelope shape\n\
        ; ============================================================================\n\
        \n\
        ; RAM variables (defined in SYSTEM RAM VARIABLES section):\n\
        ; PSG_MUSIC_PTR, PSG_MUSIC_START, PSG_IS_PLAYING,\n\
        ; PSG_MUSIC_ACTIVE, PSG_DELAY_FRAMES\n\
        \n\
        ; PLAY_MUSIC_RUNTIME - Start PSG music playback\n\
        ; Input: X = pointer to PSG music data\n\
        PLAY_MUSIC_RUNTIME:\n\
        CMPX >PSG_MUSIC_START   ; Check if already playing this music\n\
        BNE PMr_start_new       ; If different, start fresh\n\
        LDA >PSG_IS_PLAYING     ; Check if currently playing\n\
        BNE PMr_done            ; If playing same song, ignore\n\
PMr_start_new:\n\
        ; Silence PSG before switching tracks (prevents noise bleed-through)\n\
        PSHS X,DP               ; Save music pointer and DP\n\
        LDA #$D0\n\
        TFR A,DP                ; Set DP=$D0 for Sound_Byte\n\
        LDA #7                  ; PSG reg 7 = Mixer\n\
        LDB #$3F                ; All channels disabled (bits 0-5 only; bits 6-7=0=IOA/IOB input!)\n\
        JSR Sound_Byte\n\
        LDA #8                  ; PSG reg 8 = Volume channel A\n\
        LDB #0\n\
        JSR Sound_Byte\n\
        LDA #9                  ; PSG reg 9 = Volume channel B\n\
        LDB #0\n\
        JSR Sound_Byte\n\
        LDA #10                 ; PSG reg 10 = Volume channel C\n\
        LDB #0\n\
        JSR Sound_Byte\n\
        PULS X,DP               ; Restore music pointer and DP\n\
        STX >PSG_MUSIC_PTR      ; Store current music pointer (force extended)\n\
        STX >PSG_MUSIC_START    ; Store start pointer for loops (force extended)\n\
        CLR >PSG_DELAY_FRAMES   ; Clear delay counter\n\
        LDA #$01\n\
        STA >PSG_IS_PLAYING     ; Mark as playing (extended - var at 0xC8A0)\n\
PMr_done:\n\
        RTS\n\
        \n\
        ; ============================================================================\n\
        ; UPDATE_MUSIC_PSG - Update PSG (call every frame)\n\
        ; Data format per event: FCB delay, FCB count, (FCB reg, FCB val)*N\n\
        ; delay = frames since previous event (0 = apply immediately)\n\
        ; End marker: FCB 0 after last event's count\n\
        ; Loop marker: delay=$FF is treated as loop; OR count=$FF followed by FDB addr\n\
        ; PSG_DELAY_FRAMES counts down to the next event fire point.\n\
        ; PSG_MUSIC_PTR always points to delay byte of next pending event.\n\
        ; ============================================================================\n\
        UPDATE_MUSIC_PSG:\n\
        LDA #$01\n\
        STA >PSG_MUSIC_ACTIVE   ; Mark music system active\n\
        LDA >PSG_IS_PLAYING\n\
        LBEQ PSG_update_done    ; Not playing\n\
        \n\
        ; Check if delay counter is running\n\
        LDA >PSG_DELAY_FRAMES\n\
        BEQ PSG_read_delay      ; Counter=0: time to read next delay byte\n\
        DECA\n\
        STA >PSG_DELAY_FRAMES\n\
        LBNE PSG_update_done    ; Still waiting\n\
        BRA PSG_process_event   ; Counter just hit 0: apply the event\n\
        \n\
        PSG_read_delay:\n\
        LDX >PSG_MUSIC_PTR      ; PTR → delay byte of current event\n\
        LDB ,X+                 ; Consume delay byte, X → count byte\n\
        CMPB #$FF\n\
        LBEQ PSG_music_loop_d   ; $FF as delay = loop command\n\
        STB >PSG_DELAY_FRAMES   ; Store delay count\n\
        STX >PSG_MUSIC_PTR      ; Advance PTR past delay byte (now at count byte)\n\
        BEQ PSG_process_event   ; delay=0: apply immediately\n\
        DEC >PSG_DELAY_FRAMES   ; Decrement once (fires after delay-1 more frames)\n\
        LBRA PSG_update_done    ; Wait\n\
        \n\
        PSG_process_event:\n\
        LDX >PSG_MUSIC_PTR      ; PTR is at count byte\n\
        LDB ,X+\n\
        LBEQ PSG_music_ended    ; Count=0 means end\n\
        CMPB #$FF\n\
        LBEQ PSG_music_loop     ; Count=$FF means loop\n\
        \n\
        PSHS B                  ; Save count on stack\n\
        PSG_write_loop:\n\
        LDA ,X+                 ; Load register number\n\
        LDB ,X+                 ; Load register value\n\
        PSHS X                  ; Save pointer\n\
        \n\
        ; WRITE_PSG sequence (direct VIA access)\n\
        STA VIA_port_a          ; Store register number\n\
        LDA #$19                ; BDIR=1, BC1=1 (LATCH)\n\
        STA VIA_port_b\n\
        LDA #$01                ; BDIR=0, BC1=0 (INACTIVE)\n\
        STA VIA_port_b\n\
        LDA VIA_port_a          ; Read status\n\
        STB VIA_port_a          ; Store data\n\
        LDB #$11                ; BDIR=1, BC1=0 (WRITE)\n\
        STB VIA_port_b\n\
        LDB #$01                ; BDIR=0, BC1=0 (INACTIVE)\n\
        STB VIA_port_b\n\
        \n\
        PULS X                  ; Restore pointer\n\
        PULS B                  ; Get counter\n\
        DECB\n\
        BEQ PSG_event_done      ; Done with this event\n\
        PSHS B                  ; Save counter back\n\
        BRA PSG_write_loop\n\
        \n\
        PSG_event_done:\n\
        STX >PSG_MUSIC_PTR      ; PTR → delay byte of next event\n\
        CLR >PSG_DELAY_FRAMES   ; Trigger PSG_read_delay next frame\n\
        LBRA PSG_update_done\n\
        \n\
        PSG_music_ended:\n\
        CLR >PSG_IS_PLAYING\n\
        LBRA PSG_update_done\n\
        \n\
        PSG_music_loop:\n\
        ; count=$FF: X points after $FF, at FDB loop address\n\
        LDD ,X\n\
        STD >PSG_MUSIC_PTR\n\
        CLR >PSG_DELAY_FRAMES\n\
        LBRA PSG_update_done\n\
        \n\
        PSG_music_loop_d:\n\
        ; delay=$FF: X points after $FF, at FDB loop address\n\
        LDD ,X\n\
        STD >PSG_MUSIC_PTR\n\
        CLR >PSG_DELAY_FRAMES\n\
        \n\
        PSG_update_done:\n\
        CLR >PSG_MUSIC_ACTIVE   ; Clear flag (music system done)\n\
        RTS\n\
        \n\
        ; ============================================================================\n\
        ; STOP_MUSIC_RUNTIME - Stop music playback\n\
        ; ============================================================================\n\
        STOP_MUSIC_RUNTIME:\n\
        CLR >PSG_IS_PLAYING     ; Clear playing flag\n\
        CLR >PSG_MUSIC_PTR      ; Clear pointer high byte\n\
        CLR >PSG_MUSIC_PTR+1    ; Clear pointer low byte\n\
        ; Mute all PSG channels so the last note doesn't keep sounding\n\
        PSHS DP\n\
        LDA #$D0\n\
        TFR A,DP                ; Set DP=$D0 for Sound_Byte\n\
        LDA #8                  ; PSG reg 8 = Volume Channel A\n\
        LDB #0\n\
        JSR Sound_Byte\n\
        LDA #9                  ; PSG reg 9 = Volume Channel B\n\
        LDB #0\n\
        JSR Sound_Byte\n\
        LDA #10                 ; PSG reg 10 = Volume Channel C\n\
        LDB #0\n\
        JSR Sound_Byte\n\
        PULS DP\n\
        RTS\n\
        \n"
    );
}

/// Emit AUDIO_UPDATE helper for PSG music + SFX playback
/// Auto-called at end of LOOP_BODY when PLAY_MUSIC/PLAY_SFX detected
/// Uses Sound_Byte BIOS call for PSG writes (DP=$D0 required)
fn emit_audio_update_helper(asm: &mut String, is_multibank: bool) {
    // Common header (no bank-switch code for single-bank)
    asm.push_str(
        "; ============================================================================\n\
        ; AUDIO_UPDATE - Unified music + SFX update (auto-injected after WAIT_RECAL)\n\
        ; ============================================================================\n\
        ; Uses Sound_Byte (BIOS) for PSG writes - compatible with both systems\n\
        ; Sets DP=$D0 once at entry, restores at exit\n\
        \n\
        AUDIO_UPDATE:\n\
        PSHS DP                 ; Save current DP\n\
        LDA #$D0                ; Set DP=$D0 (Sound_Byte requirement)\n\
        TFR A,DP\n\
        \n"
    );

    // Bank-switch block only for multibank projects.
    // Single-bank: emitting PSHS A / STA $DF00 every frame causes spurious
    // bank-switch side-effects in the emulator due to uninitialized RAM data.
    if is_multibank {
        asm.push_str(
            "        ; MULTIBANK: Switch to music's bank before accessing data\n\
            LDA >CURRENT_ROM_BANK   ; Get current bank\n\
            PSHS A                  ; Save on stack\n\
            LDA >PSG_MUSIC_BANK     ; Get music's bank\n\
            CMPA ,S                 ; Compare with current bank\n\
            BEQ AU_BANK_OK          ; Skip switch if same\n\
            STA >CURRENT_ROM_BANK   ; Update RAM tracker\n\
            STA $DF00               ; Switch bank hardware register\n\
            AU_BANK_OK:\n\
            \n"
        );
    }

    // Music player body (common to both single and multibank)
    asm.push_str(
        "        ; UPDATE MUSIC\n\
        LDA >PSG_IS_PLAYING     ; Check if music is playing\n\
        BEQ AU_SKIP_MUSIC       ; Skip if not\n\
        \n\
        ; Check delay counter first\n\
        LDA >PSG_DELAY_FRAMES   ; Load delay counter\n\
        BEQ AU_MUSIC_READ       ; If zero, read next frame data\n\
        DECA                    ; Decrement delay\n\
        STA >PSG_DELAY_FRAMES   ; Store back\n\
        CMPA #0                 ; Check if it just reached zero\n\
        BNE AU_UPDATE_SFX       ; If not zero yet, skip this frame\n\
        \n\
        ; Delay just reached zero, X points to count byte already\n\
        LDX >PSG_MUSIC_PTR      ; Load music pointer (points to count)\n\
        BRA AU_MUSIC_READ_COUNT ; Skip delay read, go straight to count\n\
        \n\
        AU_MUSIC_READ:\n\
        LDX >PSG_MUSIC_PTR      ; Load music pointer\n\
        \n\
        ; Check if we need to read delay or we're ready for count\n\
        ; PSG_DELAY_FRAMES just reached 0, so we read delay byte first\n\
        LDB ,X+                 ; Read delay counter (X now points to count byte)\n\
        CMPB #$FF               ; Check for loop marker\n\
        BEQ AU_MUSIC_LOOP       ; Handle loop\n\
        CMPB #0                 ; Check if delay is 0\n\
        BNE AU_MUSIC_HAS_DELAY  ; If not 0, process delay\n\
        \n\
        ; Delay is 0, read count immediately\n\
        AU_MUSIC_NO_DELAY:\n\
        AU_MUSIC_READ_COUNT:\n\
        LDB ,X+                 ; Read count (number of register writes)\n\
        BEQ AU_MUSIC_ENDED      ; If 0, end of music\n\
        CMPB #$FF               ; Check for loop marker (can appear after delay)\n\
        BEQ AU_MUSIC_LOOP       ; Handle loop\n\
        BRA AU_MUSIC_PROCESS_WRITES\n\
        \n\
        AU_MUSIC_HAS_DELAY:\n\
        ; B has delay > 0, store it and skip to next frame\n\
        DECB                    ; Delay-1 (we consume this frame)\n\
        BEQ AU_MUSIC_READ_COUNT ; delay was 1: X already at count byte, process immediately\n\
        STB >PSG_DELAY_FRAMES   ; Save delay counter\n\
        STX >PSG_MUSIC_PTR      ; Save pointer (X points to count byte)\n\
        BRA AU_UPDATE_SFX       ; Skip reading data this frame\n\
        \n\
        AU_MUSIC_PROCESS_WRITES:\n\
        PSHS B                  ; Save count\n\
        \n\
        AU_MUSIC_WRITE_LOOP:\n\
        LDA ,X+                 ; Load register number\n\
        LDB ,X+                 ; Load register value\n\
        PSHS X                  ; Save pointer\n\
        JSR Sound_Byte          ; Write to PSG using BIOS (DP=$D0)\n\
        PULS X                  ; Restore pointer\n\
        PULS B                  ; Get counter\n\
        DECB                    ; Decrement\n\
        BEQ AU_MUSIC_DONE       ; Done if count=0\n\
        PSHS B                  ; Save counter\n\
        BRA AU_MUSIC_WRITE_LOOP ; Continue\n\
        \n\
        AU_MUSIC_DONE:\n\
        STX >PSG_MUSIC_PTR      ; Update music pointer\n\
        BRA AU_UPDATE_SFX       ; Now update SFX\n\
        \n\
        AU_MUSIC_ENDED:\n\
        CLR >PSG_IS_PLAYING     ; Stop music\n\
        BRA AU_UPDATE_SFX       ; Continue to SFX\n\
        \n\
        AU_MUSIC_LOOP:\n\
        LDD ,X                  ; Load loop target\n\
        STD >PSG_MUSIC_PTR      ; Set music pointer to loop\n\
        CLR >PSG_DELAY_FRAMES   ; Clear delay on loop\n\
        BRA AU_UPDATE_SFX       ; Continue to SFX\n\
        \n\
        AU_SKIP_MUSIC:\n\
        BRA AU_UPDATE_SFX       ; Skip music, go to SFX\n\
        \n\
        ; UPDATE SFX (channel C: registers 4/5=tone, 6=noise, 10=volume, 7=mixer)\n\
        AU_UPDATE_SFX:\n\
        LDA >SFX_ACTIVE         ; Check if SFX is active\n\
        BEQ AU_DONE             ; Skip if not active\n\
        \n"
    );

    // Multibank SFX: switch to SFX bank before reading SFX data
    if is_multibank {
        asm.push_str(
            "        ; MULTIBANK: Switch to SFX bank before reading SFX data\n\
            LDA >SFX_BANK           ; Get SFX bank ID\n\
            STA >CURRENT_ROM_BANK   ; Update RAM tracker\n\
            STA $DF00               ; Switch bank hardware register\n\
            \n"
        );
    }

    asm.push_str(
        "        JSR sfx_doframe         ; Process one SFX frame (uses Sound_Byte internally)\n\
        \n\
        AU_DONE:\n"
    );

    // Bank-restore block only for multibank
    if is_multibank {
        asm.push_str(
            "        ; MULTIBANK: Restore original bank\n\
            PULS A                  ; Get saved bank from stack\n\
            STA >CURRENT_ROM_BANK   ; Update RAM tracker\n\
            STA $DF00               ; Restore bank hardware register\n"
        );
    }

    asm.push_str(
        "        PULS DP                 ; Restore original DP\n\
        RTS\n\
        \n"
    );
}

// emit_draw_sync_list_at_with_mirrors - Vector drawing with mirror support
pub fn emit_draw_sync_list_at_with_mirrors(out: &mut String) {
    out.push_str(
        "Draw_Sync_List_At_With_Mirrors:\n\
        ; Unified mirror support using flags: MIRROR_X and MIRROR_Y\n\
            ; Conditionally negates X and/or Y coordinates and deltas\n\
            ; NOTE: Caller has DP=$D0 for VIA access — RAM vars need '>' extended addressing\n\
            ; CRITICAL: Do NOT call JSR $F2AB (Intensity_a) here! Intensity_a manipulates\n\
            ; VIA Port B through states $05->$04->$01 which resets the analog hardware\n\
            ; (zero-reference sequence) and would disrupt the beam position mid-drawing.\n\
            ; Instead we replicate only the VIA Port A write + Port B Z-axis strobe inline.\n\
            LDA ,X+                 ; Read per-path intensity from vector data\n\
DSWM_SET_INTENSITY:\n\
            STA >$C832              ; Update BIOS variable (Vec_Misc_Count)\n\
            STA >$D001              ; Port A = intensity (alg_xsh = intensity XOR $80)\n\
            LDA #$04\n\
            STA >$D000              ; Port B=$04: Z-axis mux enabled -> alg_zsh updated\n\
            LDA #$01\n\
            STA >$D000              ; Port B=$01: restore normal mux\n\
            LDB ,X+                 ; y_start from .vec (already relative to center)\n\
            ; Check if Y mirroring is enabled\n\
            TST >MIRROR_Y\n\
            BEQ DSWM_NO_NEGATE_Y\n\
            NEGB                    ; ← Negate Y if flag set\n\
DSWM_NO_NEGATE_Y:\n\
            ADDB >DRAW_VEC_Y        ; Add Y offset\n\
            LDA ,X+                 ; x_start from .vec (already relative to center)\n\
            ; Check if X mirroring is enabled\n\
            TST >MIRROR_X\n\
            BEQ DSWM_NO_NEGATE_X\n\
            NEGA                    ; ← Negate X if flag set\n\
DSWM_NO_NEGATE_X:\n\
            ADDA >DRAW_VEC_X        ; Add X offset\n\
            STD >TEMP_YX            ; Save adjusted position\n\
            ; Reset completo\n\
            CLR VIA_shift_reg\n\
            LDA #$CC\n\
            STA VIA_cntl\n\
            CLR VIA_port_a\n\
            LDA #$03\n\
            STA VIA_port_b          ; PB=$03: disable mux (Reset_Pen step 1)\n\
            LDA #$02\n\
            STA VIA_port_b          ; PB=$02: enable mux (Reset_Pen step 2)\n\
            LDA #$02\n\
            STA VIA_port_b          ; repeat\n\
            LDA #$01\n\
            STA VIA_port_b          ; PB=$01: disable mux (integrators zeroed)\n\
            ; Moveto (BIOS Moveto_d: Y->PA, CLR PB, settle, #CE, CLR SR, INC PB, X->PA)\n\
            LDD >TEMP_YX\n\
            STB VIA_port_a          ; Y to DAC (PB=1: integrators hold)\n\
            CLR VIA_port_b          ; PB=0: enable mux, beam tracks Y\n\
            PSHS A                  ; ~4 cycle settling delay for Y\n\
            LDA #$CE\n\
            STA VIA_cntl            ; PCR=$CE: /ZERO high, integrators active\n\
            CLR VIA_shift_reg       ; SR=0: no draw during moveto\n\
            INC VIA_port_b          ; PB=1: disable mux, lock direction at Y\n\
            PULS A                  ; Restore X\n\
            STA VIA_port_a          ; X to DAC\n\
            ; T1 fixed at $7F (constant scale; brightness is set via $C832 above, independently)\n\
            LDA #$7F\n\
            STA VIA_t1_cnt_lo\n\
            CLR VIA_t1_cnt_hi\n\
            LEAX 2,X                ; Skip next_y, next_x\n\
            ; Wait for move to complete (PB=1 on exit)\n\
            DSWM_W1:\n\
            LDA VIA_int_flags\n\
            ANDA #$40\n\
            BEQ DSWM_W1\n\
            ; PB stays 1 — draw loop begins with PB=1\n\
            ; Loop de dibujo (conditional mirrors)\n\
            DSWM_LOOP:\n\
            LDA ,X+                 ; Read flag\n\
            CMPA #2                 ; Check end marker\n\
            LBEQ DSWM_DONE\n\
            CMPA #1                 ; Check next path marker\n\
            LBEQ DSWM_NEXT_PATH\n\
            ; Draw line with conditional negations\n\
            LDB ,X+                 ; dy\n\
            ; Check if Y mirroring is enabled\n\
            TST >MIRROR_Y\n\
            BEQ DSWM_NO_NEGATE_DY\n\
            NEGB                    ; ← Negate dy if flag set\n\
DSWM_NO_NEGATE_DY:\n\
            LDA ,X+                 ; dx\n\
            ; Check if X mirroring is enabled\n\
            TST >MIRROR_X\n\
            BEQ DSWM_NO_NEGATE_DX\n\
            NEGA                    ; ← Negate dx if flag set\n\
DSWM_NO_NEGATE_DX:\n\
            ; B=DY_final, A=DX_final, PB=1 on entry (from moveto or previous segment)\n\
            STB VIA_port_a          ; DY to DAC (PB=1: integrators hold position)\n\
            CLR VIA_port_b          ; PB=0: enable mux, beam tracks DY direction\n\
            NOP                     ; settling 1 (per BIOS Draw_Line_d: LEAX+NOP = ~7 cycles)\n\
            NOP                     ; settling 2\n\
            NOP                     ; settling 3\n\
            INC VIA_port_b          ; PB=1: disable mux, lock direction at DY\n\
            STA VIA_port_a          ; DX to DAC\n\
            LDA #$FF\n\
            STA VIA_shift_reg       ; beam ON first (ramp still off from T1PB7)\n\
            CLR VIA_t1_cnt_hi       ; THEN start T1 -> ramp ON (BIOS order)\n\
            ; Wait for line draw\n\
            DSWM_W2:\n\
            LDA VIA_int_flags\n\
            ANDA #$40\n\
            BEQ DSWM_W2\n\
            CLR VIA_shift_reg       ; beam off (PB stays 1 for next segment)\n\
            LBRA DSWM_LOOP          ; Long branch\n\
            ; Next path: repeat mirror logic for new path header\n\
            DSWM_NEXT_PATH:\n\
            TFR X,D\n\
            PSHS D\n\
            ; Read per-path intensity from vector data\n\
            LDA ,X+                 ; Read intensity from vector data\n\
DSWM_NEXT_SET_INTENSITY:\n\
            PSHS A\n\
            LDB ,X+                 ; y_start\n\
            TST >MIRROR_Y\n\
            BEQ DSWM_NEXT_NO_NEGATE_Y\n\
            NEGB\n\
DSWM_NEXT_NO_NEGATE_Y:\n\
            ADDB >DRAW_VEC_Y        ; Add Y offset\n\
            LDA ,X+                 ; x_start\n\
            TST >MIRROR_X\n\
            BEQ DSWM_NEXT_NO_NEGATE_X\n\
            NEGA\n\
DSWM_NEXT_NO_NEGATE_X:\n\
            ADDA >DRAW_VEC_X        ; Add X offset\n\
            STD >TEMP_YX\n\
            PULS A                  ; Get intensity back\n\
            STA >$C832              ; Update BIOS variable (Vec_Misc_Count)\n\
            STA >$D001              ; Port A = intensity (alg_xsh = intensity XOR $80)\n\
            LDA #$04\n\
            STA >$D000              ; Port B=$04: Z-axis mux enabled -> alg_zsh updated\n\
            LDA #$01\n\
            STA >$D000              ; Port B=$01: restore normal mux\n\
            PULS D\n\
            ADDD #3\n\
            TFR D,X\n\
            ; Reset to zero\n\
            CLR VIA_shift_reg\n\
            LDA #$CC\n\
            STA VIA_cntl\n\
            CLR VIA_port_a\n\
            LDA #$03\n\
            STA VIA_port_b          ; PB=$03: disable mux (Reset_Pen step 1)\n\
            LDA #$02\n\
            STA VIA_port_b          ; PB=$02: enable mux (Reset_Pen step 2)\n\
            LDA #$02\n\
            STA VIA_port_b          ; repeat\n\
            LDA #$01\n\
            STA VIA_port_b          ; PB=$01: disable mux (integrators zeroed)\n\
            ; Moveto new start position (BIOS Moveto_d order)\n\
            LDD >TEMP_YX\n\
            STB VIA_port_a          ; Y to DAC (PB=1: integrators hold)\n\
            CLR VIA_port_b          ; PB=0: enable mux, beam tracks Y\n\
            PSHS A                  ; ~4 cycle settling delay for Y\n\
            LDA #$CE\n\
            STA VIA_cntl            ; PCR=$CE: /ZERO high, integrators active\n\
            CLR VIA_shift_reg       ; SR=0: no draw during moveto\n\
            INC VIA_port_b          ; PB=1: disable mux, lock direction at Y\n\
            PULS A\n\
            STA VIA_port_a          ; X to DAC\n\
            ; T1 fixed at $7F (constant scale; brightness set via $C832 above)\n\
            LDA #$7F\n\
            STA VIA_t1_cnt_lo\n\
            CLR VIA_t1_cnt_hi\n\
            LEAX 2,X\n\
            ; Wait for move (PB=1 on exit)\n\
            DSWM_W3:\n\
            LDA VIA_int_flags\n\
            ANDA #$40\n\
            BEQ DSWM_W3\n\
            ; PB stays 1 — draw loop continues with PB=1\n\
            LBRA DSWM_LOOP          ; Long branch\n\
            DSWM_DONE:\n\
            RTS\n"
    );
}

/// Emit PLAY_SFX_RUNTIME and sfx_doframe helpers
/// AYFX sound effects player (Richard Chadd system - 1 channel, channel C)
fn emit_play_sfx_runtime(asm: &mut String) {
    asm.push_str(
        "; ============================================================================\n\
        ; AYFX SOUND EFFECTS PLAYER (Richard Chadd original system)\n\
        ; ============================================================================\n\
        ; Uses channel C (registers 4/5=tone, 6=noise, 10=volume, 7=mixer bit2/bit5)\n\
        ; RAM variables: SFX_PTR (16-bit), SFX_ACTIVE (8-bit)\n\
        ; AYFX format: flag byte + optional data per frame, end marker $D0 $20\n\
        ; Flag bits: 0-3=volume, 4=disable tone, 5=tone data present,\n\
        ;            6=noise data present, 7=disable noise\n\
        ; ============================================================================\n\
        \n\
        ; PLAY_SFX_RUNTIME - Start SFX playback\n\
        ; Input: X = pointer to AYFX data\n\
        PLAY_SFX_RUNTIME:\n\
            STX >SFX_PTR           ; Store pointer (force extended addressing)\n\
            LDA #$01\n\
            STA >SFX_ACTIVE        ; Mark as active\n\
            RTS\n\
        \n\
        ; SFX_UPDATE - Process one AYFX frame (call once per frame in loop)\n\
        SFX_UPDATE:\n\
            LDA >SFX_ACTIVE        ; Check if active\n\
            BEQ noay               ; Not active, skip\n\
            JSR sfx_doframe        ; Process one frame\n\
        noay:\n\
            RTS\n\
        \n\
        ; sfx_doframe - AYFX frame parser (Richard Chadd original)\n\
        sfx_doframe:\n\
            LDU >SFX_PTR           ; Get current frame pointer\n\
            LDB ,U                 ; Read flag byte (NO auto-increment)\n\
            CMPB #$D0              ; Check end marker (first byte)\n\
            BNE sfx_checktonefreq  ; Not end, continue\n\
            LDB 1,U                ; Check second byte at offset 1\n\
            CMPB #$20              ; End marker $D0 $20?\n\
            BEQ sfx_endofeffect    ; Yes, stop\n\
        \n\
        sfx_checktonefreq:\n\
            LEAY 1,U               ; Y = pointer to tone/noise data\n\
            LDB ,U                 ; Reload flag byte (Sound_Byte corrupts B)\n\
            BITB #$20              ; Bit 5: tone data present?\n\
            BEQ sfx_checknoisefreq ; No, skip tone\n\
            ; Set tone frequency (channel C = reg 4/5)\n\
            LDB 2,U                ; Get LOW byte (fine tune)\n\
            LDA #$04               ; Register 4\n\
            JSR Sound_Byte         ; Write to PSG\n\
            LDB 1,U                ; Get HIGH byte (coarse tune)\n\
            LDA #$05               ; Register 5\n\
            JSR Sound_Byte         ; Write to PSG\n\
            LEAY 2,Y               ; Skip 2 tone bytes\n\
        \n\
        sfx_checknoisefreq:\n\
            LDB ,U                 ; Reload flag byte\n\
            BITB #$40              ; Bit 6: noise data present?\n\
            BEQ sfx_checkvolume    ; No, skip noise\n\
            LDB ,Y                 ; Get noise period\n\
            LDA #$06               ; Register 6\n\
            JSR Sound_Byte         ; Write to PSG\n\
            LEAY 1,Y               ; Skip 1 noise byte\n\
        \n\
        sfx_checkvolume:\n\
            LDB ,U                 ; Reload flag byte\n\
            ANDB #$0F              ; Get volume from bits 0-3\n\
            LDA #$0A               ; Register 10 (volume C)\n\
            JSR Sound_Byte         ; Write to PSG\n\
        \n\
        ; Combined mixer update: read shadow once, apply tone+noise, write once\n\
        sfx_updatemixer:\n\
            LDB $C807              ; Read mixer shadow ONCE\n\
            LDA ,U                 ; Load flag byte into A\n\
            ; Handle tone (flag bit 4 → mixer bit 2)\n\
            BITA #$10              ; Bit 4: disable tone?\n\
            BNE sfx_m_tonedis\n\
            ANDB #$FB              ; Clear bit 2 (enable tone C)\n\
            BRA sfx_m_noise\n\
        sfx_m_tonedis:\n\
            ORB #$04               ; Set bit 2 (disable tone C)\n\
        sfx_m_noise:\n\
            ; Handle noise (flag bit 7 → mixer bit 5)\n\
            BITA #$80              ; Bit 7: disable noise?\n\
            BNE sfx_m_noisedis\n\
            ANDB #$DF              ; Clear bit 5 (enable noise C)\n\
            BRA sfx_m_write\n\
        sfx_m_noisedis:\n\
            ORB #$20               ; Set bit 5 (disable noise C)\n\
        sfx_m_write:\n\
            STB $C807              ; Update mixer shadow\n\
            LDA #$07               ; Register 7 (mixer)\n\
            JSR Sound_Byte         ; Single write to PSG\n\
        \n\
        sfx_nextframe:\n\
            STY >SFX_PTR            ; Update pointer for next frame\n\
            RTS\n\
        \n\
        sfx_endofeffect:\n\
            ; Stop SFX - silence channel C and restore mixer\n\
            CLR >SFX_ACTIVE         ; Mark as inactive\n\
            LDA #$0A                ; Register 10 (volume C)\n\
            LDB #$00                ; Volume = 0\n\
            JSR Sound_Byte\n\
            ; Restore mixer: disable tone+noise on channel C\n\
            LDB $C807              ; Read mixer shadow\n\
            ORB #$24               ; Set bits 2+5 (disable tone C + noise C)\n\
            STB $C807              ; Update shadow\n\
            LDA #$07               ; Register 7\n\
            JSR Sound_Byte         ; Write mixer\n\
            LDD #$0000\n\
            STD >SFX_PTR            ; Clear pointer\n\
            RTS\n\
        \n"
    );
}

/// Emit BEEP_UPDATE_RUNTIME - decrements beep timer and mutes PSG when done
/// Auto-injected at start of LOOP_BODY when beep() is used
fn emit_beep_update_runtime(asm: &mut String) {
    asm.push_str(
        "; ============================================================================\n\
        ; BEEP_UPDATE_RUNTIME - Tick beep countdown, mute PSG when expired\n\
        ; ============================================================================\n\
        ; Called once per frame (auto-injected). Non-blocking: drawing continues\n\
        ; while PSG plays the tone set by beep().\n\
        BEEP_UPDATE_RUNTIME:\n\
        LDA >BEEP_FRAMES_LEFT    ; Check beep timer\n\
        BEQ BEEP_UPDATE_DONE     ; Zero = nothing playing, skip\n\
        DECA\n\
        STA >BEEP_FRAMES_LEFT    ; Decrement and store\n\
        BNE BEEP_UPDATE_DONE     ; Still counting, keep playing\n\
        ; Timer just expired: mute PSG channel A\n\
        PSHS DP\n\
        LDA #$D0\n\
        TFR A,DP                ; DP=$D0 for Sound_Byte\n\
        LDA #8                  ; PSG reg 8 = Volume Channel A\n\
        LDB #0\n\
        JSR Sound_Byte\n\
        PULS DP\n\
BEEP_UPDATE_DONE:\n\
        RTS\n\n"
    );
}

/// Emit SMUL8 (kept for backward compat), SMUL_LUT, SMUL_PROD table,
/// updated DV3D_ROTATE, and new vertex-dedup DRAW_VECTOR_3D_RUNTIME.
fn emit_draw_vector_3d_runtime(asm: &mut String) {
    // Emit SMUL_PROD table first (8192 bytes)
    asm.push_str(&emit_smul_prod_table());

    asm.push_str(
"; ============================================================================\n\
; SMUL8 - Signed 8x8 multiply, result = (A * B) / 128  (i8)  [kept for compat]\n\
; ============================================================================\n\
; Input:  A = op1 (i8), B = op2 (i8)\n\
; Output: A = result (i8)\n\
; Destroys: B  (no RAM touched — sign tracked with branches)\n\
SMUL8:\n\
    TSTA\n\
    BPL SMUL8_AP        ; A >= 0?\n\
    NEGA\n\
    TSTB\n\
    BPL SMUL8_NEGNEG    ; A<0, B: check sign\n\
    NEGB                ; A<0, B<0 -> result positive\n\
    MUL\n\
    ASLB\n\
    ROLA\n\
    RTS\n\
SMUL8_NEGNEG:           ; A<0, B>=0 -> result negative\n\
    MUL\n\
    ASLB\n\
    ROLA\n\
    NEGA\n\
    RTS\n\
SMUL8_AP:               ; A >= 0\n\
    TSTB\n\
    BPL SMUL8_POSPOS    ; A>=0, B>=0 -> result positive\n\
    NEGB                ; A>=0, B<0 -> result negative\n\
    MUL\n\
    ASLB\n\
    ROLA\n\
    NEGA\n\
    RTS\n\
SMUL8_POSPOS:\n\
    MUL\n\
    ASLB\n\
    ROLA\n\
    RTS\n\
\n\
; ============================================================================\n\
; SMUL_LUT - LUT-based signed 8×8 multiply, result = (A * sin(B*2π/128)) / 128\n\
; ============================================================================\n\
; Input:  A = val (i8, |val|≤63), B = angle index (0-127)\n\
;         Y = SMUL_PROD base address (caller pre-loads: LDY #SMUL_PROD)\n\
; Output: A = result (i8)\n\
; Strategy: LSRA trick — D = (|val|/2)*256 + (angle | (bit0*128)) → table offset\n\
;           LDA D,Y — 7 cycles vs LDX+LEAX+LDA = 12 cycles. Saves 5c per call.\n\
; Destroys: B  (Y preserved)\n\
SMUL_LUT:\n\
    TSTA\n\
    BPL SMUL_LUT_P      ; A >= 0 ?\n\
    ; --- negative val ---\n\
    NEGA                ; A = |val|\n\
    LSRA                ; A = |val|/2,  C = |val| bit0\n\
    BCC SMUL_LUT_N1\n\
    ORB #$80\n\
SMUL_LUT_N1:\n\
    LDA D,Y             ; table[|val|/2][angle]\n\
    NEGA\n\
    RTS\n\
SMUL_LUT_P:\n\
    LSRA                ; A = val/2,  C = val bit0\n\
    BCC SMUL_LUT_P1\n\
    ORB #$80\n\
SMUL_LUT_P1:\n\
    LDA D,Y\n\
    RTS\n\
\n\
; ============================================================================\n\
; DV3D_ROTATE - Apply X/Y/Z Euler rotation to a single point (LUT version)\n\
; ============================================================================\n\
; Input:  ROT3D_RX, ROT3D_RY, ROT3D_RZ (i8 world coords, |val|≤63)\n\
;         ROT3D_AX/AY/AZ = raw sin angle indices (0-127)\n\
;         ROT3D_COS_X/Y/Z = cos angle offsets: (angle+32)&0x7F\n\
;         ROT3D_OX, ROT3D_OY (i8 screen offsets)\n\
; Output: ROT3D_SCR_X, ROT3D_SCR_Y\n\
; Destroys: A, B, X, Y, ROT3D_TEMP, ROT3D_TEMP2, ROT3D_Y1, ROT3D_Z1, ROT3D_X2\n\
DV3D_ROTATE:\n\
    LDY #SMUL_PROD      ; Y = table base — shared by all SMUL_LUT calls\n\
    ; -- X-axis rotation: y1 = y*cX - z*sX,  z1 = y*sX + z*cX --\n\
    LDA >ROT3D_RY\n\
    LDB >ROT3D_COS_X\n\
    JSR SMUL_LUT\n\
    STA >ROT3D_TEMP\n\
    LDA >ROT3D_RZ\n\
    LDB >ROT3D_AX\n\
    JSR SMUL_LUT\n\
    STA >ROT3D_TEMP2\n\
    LDA >ROT3D_TEMP\n\
    SUBA >ROT3D_TEMP2\n\
    STA >ROT3D_Y1\n\
\n\
    LDA >ROT3D_RY\n\
    LDB >ROT3D_AX\n\
    JSR SMUL_LUT\n\
    STA >ROT3D_TEMP\n\
    LDA >ROT3D_RZ\n\
    LDB >ROT3D_COS_X\n\
    JSR SMUL_LUT\n\
    ADDA >ROT3D_TEMP\n\
    STA >ROT3D_Z1\n\
\n\
    ; -- Y-axis rotation: x2 = x*cY + z1*sY --\n\
    LDA >ROT3D_RX\n\
    LDB >ROT3D_COS_Y\n\
    JSR SMUL_LUT\n\
    STA >ROT3D_TEMP\n\
    LDA >ROT3D_Z1\n\
    LDB >ROT3D_AY\n\
    JSR SMUL_LUT\n\
    ADDA >ROT3D_TEMP\n\
    STA >ROT3D_X2\n\
\n\
    ; -- Z-axis rotation: sx = x2*cZ - y1*sZ + OX,  sy = x2*sZ + y1*cZ + OY --\n\
    LDA >ROT3D_X2\n\
    LDB >ROT3D_COS_Z\n\
    JSR SMUL_LUT\n\
    STA >ROT3D_TEMP\n\
    LDA >ROT3D_Y1\n\
    LDB >ROT3D_AZ\n\
    JSR SMUL_LUT\n\
    STA >ROT3D_TEMP2\n\
    LDA >ROT3D_TEMP\n\
    SUBA >ROT3D_TEMP2\n\
    ADDA >ROT3D_OX\n\
    STA >ROT3D_SCR_X\n\
\n\
    LDA >ROT3D_X2\n\
    LDB >ROT3D_AZ\n\
    JSR SMUL_LUT\n\
    STA >ROT3D_TEMP\n\
    LDA >ROT3D_Y1\n\
    LDB >ROT3D_COS_Z\n\
    JSR SMUL_LUT\n\
    ADDA >ROT3D_TEMP\n\
    ADDA >ROT3D_OY\n\
    STA >ROT3D_SCR_Y\n\
    RTS\n\
\n\
; ============================================================================\n\
; DV3D_MOVETO - Move beam to absolute (X,Y) using direct VIA (same as DSWM)\n\
; ============================================================================\n\
; Input:  ROT3D_TEMP=dy, ROT3D_TEMP2=dx (delta from current beam pos)\n\
;         DP must be $D0 on entry\n\
; Destroys: A\n\
; On exit: PB=1 (ready for draw loop)\n\
DV3D_MOVETO:\n\
    LDA >ROT3D_TEMP     ; dy\n\
    STA VIA_port_a      ; Y to DAC\n\
    CLR VIA_port_b      ; PB=0: enable mux, beam tracks Y\n\
    NOP                 ; settling\n\
    LDA #$CE\n\
    STA VIA_cntl        ; PCR=$CE: /ZERO high, integrators active\n\
    CLR VIA_shift_reg   ; SR=0: beam off during move\n\
    INC VIA_port_b      ; PB=1: lock direction\n\
    LDA >ROT3D_TEMP2    ; dx\n\
    STA VIA_port_a      ; X to DAC\n\
    LDA #$7F\n\
    STA VIA_t1_cnt_lo   ; T1=$7F — same scale as DSWM\n\
    CLR VIA_t1_cnt_hi   ; start timer (ramp)\n\
DV3D_MOVETO_WAIT:\n\
    LDA VIA_int_flags\n\
    ANDA #$40\n\
    BEQ DV3D_MOVETO_WAIT\n\
    RTS\n\
\n\
; ============================================================================\n\
; DV3D_DRAWLINE - Draw line with delta (dy,dx) using direct VIA (same as DSWM)\n\
; ============================================================================\n\
; Input:  ROT3D_TEMP=dy, ROT3D_TEMP2=dx\n\
;         PB=1 on entry (left by previous moveto or drawline)\n\
;         DP must be $D0 on entry\n\
; Destroys: A\n\
; On exit: PB=1\n\
DV3D_DRAWLINE:\n\
    LDA >ROT3D_TEMP     ; dy\n\
    STA VIA_port_a      ; DY to DAC (PB=1: integrators hold)\n\
    CLR VIA_port_b      ; PB=0: enable mux, set direction\n\
    NOP\n\
    NOP\n\
    NOP                 ; settling (~same as DSWM)\n\
    INC VIA_port_b      ; PB=1: lock direction\n\
    LDA >ROT3D_TEMP2    ; dx\n\
    STA VIA_port_a      ; DX to DAC\n\
    LDA #$FF\n\
    STA VIA_shift_reg   ; SR=$FF: beam ON\n\
    CLR VIA_t1_cnt_hi   ; start T1 ramp (lo already $7F from moveto — reuse)\n\
DV3D_DRAWLINE_WAIT:\n\
    LDA VIA_int_flags\n\
    ANDA #$40\n\
    BEQ DV3D_DRAWLINE_WAIT\n\
    CLR VIA_shift_reg   ; beam OFF\n\
    RTS\n\
\n\
; ============================================================================\n\
; DRAW_VECTOR_3D_RUNTIME - Draw 3D-rotated vector (vertex-dedup + LUT version)\n\
; ============================================================================\n\
; Input:  X = pointer to _NAME_3D_DATA (vertex-indexed format)\n\
;         ROT3D_AX, ROT3D_AY, ROT3D_AZ = raw angles (0-127)\n\
;         ROT3D_OX, ROT3D_OY = screen offsets\n\
; Data format:\n\
;   FDB vertex_count         ; unique vertex count (high byte skipped)\n\
;   FCB x,y,z × count        ; vertex table (coords ±63)\n\
;   FDB path_count           ; path count (high byte skipped)\n\
;   per path: FCB pt_count, closed, idx0, idx1, ...\n\
; Uses direct VIA access (DP=$D0 required) — same scale as DRAW_VECTOR/DSWM.\n\
; Destroys: A, B, X, U, all ROT3D_* vars\n\
DRAW_VECTOR_3D_RUNTIME:\n\
    TFR X,U             ; U = ROM data pointer\n\
\n\
    ; --- Compute cos angle offsets: ROT3D_COS_X = (AX+32)&0x7F, etc. ---\n\
    LDA >ROT3D_AX\n\
    ADDA #32\n\
    ANDA #$7F\n\
    STA >ROT3D_COS_X\n\
    LDA >ROT3D_AY\n\
    ADDA #32\n\
    ANDA #$7F\n\
    STA >ROT3D_COS_Y\n\
    LDA >ROT3D_AZ\n\
    ADDA #32\n\
    ANDA #$7F\n\
    STA >ROT3D_COS_Z\n\
\n\
    ; --- Phase 1: rotate unique vertices → ROT3D_VBUF ---\n\
    LDA ,U+             ; skip high byte of FDB vertex_count\n\
    LDB ,U+             ; B = vertex count\n\
    STB >ROT3D_PC\n\
    LDX #ROT3D_VBUF     ; X = write ptr into RAM cache\n\
\n\
DV3D_VERT_LOOP:\n\
    TST >ROT3D_PC\n\
    BEQ DV3D_VERTS_DONE\n\
    DEC >ROT3D_PC\n\
    LDA ,U+\n\
    STA >ROT3D_RX\n\
    LDA ,U+\n\
    STA >ROT3D_RY\n\
    LDA ,U+\n\
    STA >ROT3D_RZ\n\
    PSHS X,U            ; save VBUF write ptr and ROM data ptr (DV3D_ROTATE uses X,Y)\n\
    JSR DV3D_ROTATE     ; -> ROT3D_SCR_X, ROT3D_SCR_Y\n\
    PULS X,U            ; Y was clobbered but not needed outside DV3D_ROTATE\n\
    LDA >ROT3D_SCR_X\n\
    STA ,X+\n\
    LDA >ROT3D_SCR_Y\n\
    STA ,X+\n\
    BRA DV3D_VERT_LOOP\n\
\n\
DV3D_VERTS_DONE:\n\
    ; U now points to FDB path_count in ROM\n\
    ; Switch to DP=$D0 for direct VIA access (same as DSWM)\n\
    LDA #$D0\n\
    TFR A,DP\n\
\n\
    ; --- Reset integrators (DSWM-style: PB sequence + PCR) ---\n\
    CLR VIA_shift_reg\n\
    LDA #$CC\n\
    STA VIA_cntl\n\
    CLR VIA_port_a\n\
    LDA #$03\n\
    STA VIA_port_b\n\
    LDA #$02\n\
    STA VIA_port_b\n\
    LDA #$02\n\
    STA VIA_port_b\n\
    LDA #$01\n\
    STA VIA_port_b\n\
\n\
    ; Set intensity ($7F) via Port A + Z-axis strobe (DSWM-style)\n\
    LDA #$7F\n\
    STA VIA_port_a\n\
    LDA #$04\n\
    STA VIA_port_b\n\
    LDA #$01\n\
    STA VIA_port_b\n\
\n\
    ; Beam at (0,0) after reset — PREV tracks beam position\n\
    CLR >ROT3D_PREV_X\n\
    CLR >ROT3D_PREV_Y\n\
    ; T1 lo pre-loaded — reused by DV3D_DRAWLINE\n\
    LDA #$7F\n\
    STA VIA_t1_cnt_lo\n\
\n\
    ; --- Phase 2: draw paths using VBUF lookup ---\n\
    LDA ,U+             ; skip high byte of FDB path_count\n\
    LDB ,U+             ; B = path count\n\
    STB >ROT3D_PC\n\
\n\
DV3D_PATH_LOOP:\n\
    TST >ROT3D_PC\n\
    LBEQ DV3D_ALL_DONE\n\
    DEC >ROT3D_PC\n\
\n\
    LDB ,U+             ; B = point count for this path\n\
    STB >ROT3D_PT_REM\n\
    LDA ,U+             ; A = closed flag\n\
    STA >ROT3D_CLOSED\n\
\n\
    ; Look up first vertex from VBUF\n\
    LDB ,U+             ; B = vertex index\n\
    ASLB                ; B = index*2 (VBUF stride = 2 bytes: x', y')\n\
    LDX #ROT3D_VBUF\n\
    ABX                 ; X = &VBUF[idx*2]\n\
    LDA ,X\n\
    STA >ROT3D_FIRST_X\n\
    LDA 1,X\n\
    STA >ROT3D_FIRST_Y\n\
\n\
    ; Moveto: delta from current beam position (PREV)\n\
    LDA >ROT3D_FIRST_Y\n\
    SUBA >ROT3D_PREV_Y\n\
    STA >ROT3D_TEMP     ; dy\n\
    LDA >ROT3D_FIRST_X\n\
    SUBA >ROT3D_PREV_X\n\
    STA >ROT3D_TEMP2    ; dx\n\
    JSR DV3D_MOVETO     ; direct VIA move (T1=$7F, same scale as DSWM)\n\
\n\
    LDA >ROT3D_FIRST_X\n\
    STA >ROT3D_PREV_X\n\
    LDA >ROT3D_FIRST_Y\n\
    STA >ROT3D_PREV_Y\n\
    DEC >ROT3D_PT_REM\n\
\n\
DV3D_SEG_LOOP:\n\
    TST >ROT3D_PT_REM\n\
    BEQ DV3D_CLOSE_CHECK\n\
    DEC >ROT3D_PT_REM\n\
\n\
    LDB ,U+             ; B = vertex index\n\
    ASLB\n\
    LDX #ROT3D_VBUF\n\
    ABX                 ; X = &VBUF[idx*2]\n\
    ; Compute dx, update PREV_X: new_X - PREV_X = dx; new_X = dx + PREV_X\n\
    LDA ,X              ; new_X\n\
    SUBA >ROT3D_PREV_X  ; A = dx\n\
    STA >ROT3D_TEMP2    ; save dx\n\
    ADDA >ROT3D_PREV_X  ; A = new_X again\n\
    STA >ROT3D_PREV_X\n\
    ; Compute dy, update PREV_Y\n\
    LDA 1,X             ; new_Y\n\
    SUBA >ROT3D_PREV_Y  ; A = dy\n\
    STA >ROT3D_TEMP     ; save dy\n\
    ADDA >ROT3D_PREV_Y  ; A = new_Y again\n\
    STA >ROT3D_PREV_Y\n\
    JSR DV3D_DRAWLINE\n\
    BRA DV3D_SEG_LOOP\n\
\n\
DV3D_CLOSE_CHECK:\n\
    TST >ROT3D_CLOSED\n\
    BEQ DV3D_NEXT_PATH\n\
\n\
    LDA >ROT3D_FIRST_Y\n\
    SUBA >ROT3D_PREV_Y\n\
    STA >ROT3D_TEMP\n\
    LDA >ROT3D_FIRST_X\n\
    SUBA >ROT3D_PREV_X\n\
    STA >ROT3D_TEMP2\n\
    JSR DV3D_DRAWLINE\n\
    LDA >ROT3D_FIRST_X\n\
    STA >ROT3D_PREV_X\n\
    LDA >ROT3D_FIRST_Y\n\
    STA >ROT3D_PREV_Y\n\
\n\
DV3D_NEXT_PATH:\n\
    LBRA DV3D_PATH_LOOP\n\
\n\
DV3D_ALL_DONE:\n\
    ; Restore DP=$C8 for normal RAM access\n\
    JSR $F1AF\n\
    RTS\n\n"
    );
}

/// Generate SMUL_PROD lookup table: 64 rows × 128 columns = 8192 bytes
/// SMUL_PROD[val][angle] = (val * sin(angle * 2π/128)) rounded and clamped to i8
/// val = 0..63 (row, stride=128), angle = 0..127 (column within each row)
/// LSRA trick: A=|val|/2, B=angle|(bit0*0x80) → D=|val|*128+angle ✓
/// Vertex coords must be clamped to ±63 before use.
fn emit_smul_prod_table() -> String {
    use std::f64::consts::PI;
    let mut asm = String::new();
    asm.push_str("; ============================================================================\n");
    asm.push_str("; SMUL_PROD - Product lookup table for SMUL_LUT\n");
    asm.push_str("; SMUL_PROD[val][angle] = (val * sin(angle*2π/128)) >> 7  (i8)\n");
    asm.push_str("; val=row (0-63, stride=128), angle=col (0-127) — 8KB total\n");
    asm.push_str("; For cos: use angle=(ax+32)&0x7F — same table, shifted column\n");
    asm.push_str("; Vertex coords must be ≤63 (clamped at data emit time)\n");
    asm.push_str("SMUL_PROD:\n");
    for val in 0i32..64 {
        let mut row_bytes = Vec::with_capacity(128);
        for angle in 0i32..128 {
            let sin_f = f64::sin(angle as f64 * 2.0 * PI / 128.0);
            let sin_i8 = (sin_f * 127.0).round() as i32;
            let raw = val * sin_i8;
            // Round-toward-nearest with +64 bias, then divide by 128
            let prod = if raw >= 0 {
                (raw + 64) / 128
            } else {
                -( (raw.abs() + 64) / 128 )
            };
            let prod = prod.clamp(-127, 127) as i8;
            row_bytes.push(prod);
        }
        // Emit as one FCB line per row (128 bytes)
        let bytes_str: Vec<String> = row_bytes.iter()
            .map(|&b| format!("${:02X}", b as u8))
            .collect();
        asm.push_str(&format!("    FCB {}  ; val={}\n", bytes_str.join(","), val));
    }
    asm.push_str("\n");
    asm
}

