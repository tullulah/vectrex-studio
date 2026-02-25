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
    ram.allocate("TEMP_YX", 2, "Temporary Y/X coordinate storage");
    
    // Conditional variables based on usage
    if needed.contains("PRINT_NUMBER") {
        ram.allocate("NUM_STR", 6, "Buffer for PRINT_NUMBER decimal output (5 digits + terminator)");
    }
    if needed.contains("RAND") {
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
        ram.allocate("DRAW_CIRCLE_TEMP", 8, "Circle temporary buffer (8 bytes: radius16, xc16, yc16, r/4, 3r/4)");
    }
    
    // NOTE: Check both DRAW_RECT and DRAW_RECT_RUNTIME
    if needed.contains("DRAW_RECT") || needed.contains("DRAW_RECT_RUNTIME") {
        ram.allocate("DRAW_RECT_X", 1, "Rectangle X");
        ram.allocate("DRAW_RECT_Y", 1, "Rectangle Y");
        ram.allocate("DRAW_RECT_WIDTH", 1, "Rectangle width");
        ram.allocate("DRAW_RECT_HEIGHT", 1, "Rectangle height");
        ram.allocate("DRAW_RECT_INTENSITY", 1, "Rectangle intensity");
    }
    
    // DRAW_VECTOR / DRAW_VECTOR_EX variables (CRITICAL - MISSING!)
    if needed.contains("DRAW_VECTOR") || needed.contains("DRAW_VECTOR_EX") {
        ram.allocate("DRAW_VEC_X", 1, "Vector draw X offset");
        ram.allocate("DRAW_VEC_Y", 1, "Vector draw Y offset");
        ram.allocate("DRAW_VEC_INTENSITY", 1, "Vector intensity override (0=use vector data)");
        
        // CRITICAL FIX: Add padding to prevent collision with TEMP_YX (usually allocated at offset 6)
        ram.allocate("MIRROR_PAD", 16, "Safety padding to prevent MIRROR flag corruption");

        ram.allocate("MIRROR_X", 1, "X mirror flag (0=normal, 1=flip)");
        ram.allocate("MIRROR_Y", 1, "Y mirror flag (0=normal, 1=flip)");
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
    
    // Level system variables
    if needed.contains("SHOW_LEVEL") || needed.contains("LOAD_LEVEL") {
        ram.allocate("LEVEL_PTR", 2, "Pointer to currently loaded level data");
        ram.allocate("LEVEL_WIDTH", 1, "Level width");
        ram.allocate("LEVEL_HEIGHT", 1, "Level height");
        ram.allocate("LEVEL_TILE_SIZE", 1, "Tile size");
    }
    
    // Fade effects variables
    if needed.contains("FADE_IN") || needed.contains("FADE_OUT") {
        ram.allocate("FRAME_COUNTER", 2, "Frame counter for fade effects");
        ram.allocate("CURRENT_INTENSITY", 2, "Current intensity for fade");
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
            }
            if name_upper == "LOAD_LEVEL" {
                needed.insert("LOAD_LEVEL".to_string());
            }
            
            // Utility helpers
            if name_upper == "FADE_IN" {
                needed.insert("FADE_IN_RUNTIME".to_string());
            }
            if name_upper == "FADE_OUT" {
                needed.insert("FADE_OUT_RUNTIME".to_string());
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
        asm.push_str("    JSR Reset0Ref   ; Reset beam to center before positioning text\n");
        asm.push_str("    LDU VAR_ARG2   ; string pointer\n");
        asm.push_str("    LDA >VAR_ARG1+1 ; Y coordinate\n");
        asm.push_str("    LDB >VAR_ARG0+1 ; X coordinate\n");
        asm.push_str("    JSR Print_Str_d\n");
        asm.push_str("    LDA #$80\n");
        asm.push_str("    STA >$D004      ; Restore VIA_t1_cnt_lo: Moveto_d_7F sets it to $7F, corrupting DRAW_LINE scale\n");
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
        asm.push_str("    LDA >VAR_ARG1+1  ; Y coordinate\n");
        asm.push_str("    LDB >VAR_ARG0+1  ; X coordinate\n");
        asm.push_str("    LDU #NUM_STR     ; String pointer\n");
        asm.push_str("    JSR Print_Str_d  ; Print using BIOS (A=Y, B=X, U=string)\n");
        asm.push_str("    LDA #$80\n");
        asm.push_str("    STA >$D004      ; Restore VIA_t1_cnt_lo: Moveto_d_7F sets it to $7F, corrupting DRAW_LINE scale\n");
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
        ; ============================================================================\n\
        UPDATE_MUSIC_PSG:\n\
        ; CRITICAL: Set VIA to PSG mode BEFORE accessing PSG (don't assume state)\n\
        ; DISABLED: Conflicts with SFX which uses Sound_Byte (HANDSHAKE mode)\n\
        ; LDA #$00       ; VIA_cntl = $00 (PSG mode)\n\
        ; STA >$D00C     ; VIA_cntl\n\
        LDA #$01\n\
        STA >PSG_MUSIC_ACTIVE   ; Mark music system active (for PSG logging)\n\
        LDA >PSG_IS_PLAYING     ; Check if playing (extended - var at 0xC8A0)\n\
        BEQ PSG_update_done     ; Not playing, exit\n\
        \n\
        LDX >PSG_MUSIC_PTR      ; Load pointer (force extended - LDX has no DP mode)\n\
        BEQ PSG_update_done     ; No music loaded\n\
        \n\
        ; Read frame count byte (number of register writes)\n\
        LDB ,X+\n\
        BEQ PSG_music_ended     ; Count=0 means end (no loop)\n\
        CMPB #$FF               ; Check for loop command\n\
        BEQ PSG_music_loop      ; $FF means loop (never valid as count)\n\
        \n\
        ; Process frame - push counter to stack\n\
        PSHS B                  ; Save count on stack\n\
        \n\
        ; Write register/value pairs to PSG\n\
        PSG_write_loop:\n\
        LDA ,X+                 ; Load register number\n\
        LDB ,X+                 ; Load register value\n\
        PSHS X                  ; Save pointer (after reads)\n\
        \n\
        ; WRITE_PSG sequence\n\
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
        DECB                    ; Decrement\n\
        BEQ PSG_frame_done      ; Done with this frame\n\
        PSHS B                  ; Save counter back\n\
        BRA PSG_write_loop\n\
        \n\
        PSG_frame_done:\n\
        \n\
        ; Frame complete - update pointer and done\n\
        STX >PSG_MUSIC_PTR      ; Update pointer (force extended)\n\
        BRA PSG_update_done\n\
        \n\
        PSG_music_ended:\n\
        CLR >PSG_IS_PLAYING     ; Stop playback (extended - var at 0xC8A0)\n\
        ; NOTE: Do NOT write PSG registers here - corrupts VIA for vector drawing\n\
        ; Music will fade naturally as frame data stops updating\n\
        BRA PSG_update_done\n\
        \n\
        PSG_music_loop:\n\
        ; Loop command: $FF followed by 2-byte address (FDB)\n\
        ; X points past $FF, read the target address\n\
        LDD ,X                  ; Load 2-byte loop target address\n\
        STD >PSG_MUSIC_PTR      ; Update pointer to loop start\n\
        ; Exit - next frame will start from loop target\n\
        BRA PSG_update_done\n\
        \n\
        PSG_update_done:\n\
        CLR >PSG_MUSIC_ACTIVE   ; Clear flag (music system done)\n\
        RTS\n\
        \n\
        ; ============================================================================\n\
        ; STOP_MUSIC_RUNTIME - Stop music playback\n\
        ; ============================================================================\n\
        STOP_MUSIC_RUNTIME:\n\
        CLR >PSG_IS_PLAYING     ; Clear playing flag (extended - var at 0xC8A0)\n\
        CLR >PSG_MUSIC_PTR      ; Clear pointer high byte (force extended)\n\
        CLR >PSG_MUSIC_PTR+1    ; Clear pointer low byte (force extended)\n\
        ; NOTE: Do NOT write PSG registers here - corrupts VIA for vector drawing\n\
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
        BEQ AU_SKIP_MUSIC       ; Skip if null\n\
        BRA AU_MUSIC_READ_COUNT ; Skip delay read, go straight to count\n\
        \n\
        AU_MUSIC_READ:\n\
        LDX >PSG_MUSIC_PTR      ; Load music pointer\n\
        BEQ AU_SKIP_MUSIC       ; Skip if null\n\
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
        \n\
        JSR sfx_doframe         ; Process one SFX frame (uses Sound_Byte internally)\n\
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
            ; NOTE: Caller must ensure DP=$D0 for VIA access\n\
            LDA DRAW_VEC_INTENSITY  ; Check if intensity override is set\n\
            BNE DSWM_USE_OVERRIDE   ; If non-zero, use override\n\
            LDA ,X+                 ; Otherwise, read intensity from vector data\n\
            BRA DSWM_SET_INTENSITY\n\
DSWM_USE_OVERRIDE:\n\
            LEAX 1,X                ; Skip intensity byte in vector data\n\
DSWM_SET_INTENSITY:\n\
            JSR $F2AB               ; BIOS Intensity_a\n\
            LDB ,X+                 ; y_start from .vec (already relative to center)\n\
            ; Check if Y mirroring is enabled\n\
            TST MIRROR_Y\n\
            BEQ DSWM_NO_NEGATE_Y\n\
            NEGB                    ; ← Negate Y if flag set\n\
DSWM_NO_NEGATE_Y:\n\
            ADDB DRAW_VEC_Y         ; Add Y offset\n\
            LDA ,X+                 ; x_start from .vec (already relative to center)\n\
            ; Check if X mirroring is enabled\n\
            TST MIRROR_X\n\
            BEQ DSWM_NO_NEGATE_X\n\
            NEGA                    ; ← Negate X if flag set\n\
DSWM_NO_NEGATE_X:\n\
            ADDA DRAW_VEC_X         ; Add X offset\n\
            STD TEMP_YX             ; Save adjusted position\n\
            ; Reset completo\n\
            CLR VIA_shift_reg\n\
            LDA #$CC\n\
            STA VIA_cntl\n\
            CLR VIA_port_a\n\
            LDA #$82\n\
            STA VIA_port_b\n\
            NOP\n\
            NOP\n\
            NOP\n\
            NOP\n\
            NOP\n\
            LDA #$83\n\
            STA VIA_port_b\n\
            ; Move sequence\n\
            LDD TEMP_YX\n\
            STB VIA_port_a          ; y to DAC\n\
            PSHS A                  ; Save x\n\
            LDA #$CE\n\
            STA VIA_cntl\n\
            CLR VIA_port_b\n\
            LDA #1\n\
            STA VIA_port_b\n\
            PULS A                  ; Restore x\n\
            STA VIA_port_a          ; x to DAC\n\
            ; Timing setup\n\
            LDA #$7F\n\
            STA VIA_t1_cnt_lo\n\
            CLR VIA_t1_cnt_hi\n\
            LEAX 2,X                ; Skip next_y, next_x\n\
            ; Wait for move to complete\n\
            DSWM_W1:\n\
            LDA VIA_int_flags\n\
            ANDA #$40\n\
            BEQ DSWM_W1\n\
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
            TST MIRROR_Y\n\
            BEQ DSWM_NO_NEGATE_DY\n\
            NEGB                    ; ← Negate dy if flag set\n\
DSWM_NO_NEGATE_DY:\n\
            LDA ,X+                 ; dx\n\
            ; Check if X mirroring is enabled\n\
            TST MIRROR_X\n\
            BEQ DSWM_NO_NEGATE_DX\n\
            NEGA                    ; ← Negate dx if flag set\n\
DSWM_NO_NEGATE_DX:\n\
            PSHS A                  ; Save final dx\n\
            STB VIA_port_a          ; dy (possibly negated) to DAC\n\
            CLR VIA_port_b\n\
            LDA #1\n\
            STA VIA_port_b\n\
            PULS A                  ; Restore final dx\n\
            STA VIA_port_a          ; dx (possibly negated) to DAC\n\
            CLR VIA_t1_cnt_hi\n\
            LDA #$FF\n\
            STA VIA_shift_reg\n\
            ; Wait for line draw\n\
            DSWM_W2:\n\
            LDA VIA_int_flags\n\
            ANDA #$40\n\
            BEQ DSWM_W2\n\
            CLR VIA_shift_reg\n\
            LBRA DSWM_LOOP          ; Long branch\n\
            ; Next path: repeat mirror logic for new path header\n\
            DSWM_NEXT_PATH:\n\
            TFR X,D\n\
            PSHS D\n\
            ; Check intensity override (same logic as start)\n\
            LDA DRAW_VEC_INTENSITY  ; Check if intensity override is set\n\
            BNE DSWM_NEXT_USE_OVERRIDE   ; If non-zero, use override\n\
            LDA ,X+                 ; Otherwise, read intensity from vector data\n\
            BRA DSWM_NEXT_SET_INTENSITY\n\
DSWM_NEXT_USE_OVERRIDE:\n\
            LEAX 1,X                ; Skip intensity byte in vector data\n\
DSWM_NEXT_SET_INTENSITY:\n\
            PSHS A\n\
            LDB ,X+                 ; y_start\n\
            TST MIRROR_Y\n\
            BEQ DSWM_NEXT_NO_NEGATE_Y\n\
            NEGB\n\
DSWM_NEXT_NO_NEGATE_Y:\n\
            ADDB DRAW_VEC_Y         ; Add Y offset\n\
            LDA ,X+                 ; x_start\n\
            TST MIRROR_X\n\
            BEQ DSWM_NEXT_NO_NEGATE_X\n\
            NEGA\n\
DSWM_NEXT_NO_NEGATE_X:\n\
            ADDA DRAW_VEC_X         ; Add X offset\n\
            STD TEMP_YX\n\
            PULS A                  ; Get intensity back\n\
            JSR $F2AB\n\
            PULS D\n\
            ADDD #3\n\
            TFR D,X\n\
            ; Reset to zero\n\
            CLR VIA_shift_reg\n\
            LDA #$CC\n\
            STA VIA_cntl\n\
            CLR VIA_port_a\n\
            LDA #$82\n\
            STA VIA_port_b\n\
            NOP\n\
            NOP\n\
            NOP\n\
            NOP\n\
            NOP\n\
            LDA #$83\n\
            STA VIA_port_b\n\
            ; Move to new start position\n\
            LDD TEMP_YX\n\
            STB VIA_port_a\n\
            PSHS A\n\
            LDA #$CE\n\
            STA VIA_cntl\n\
            CLR VIA_port_b\n\
            LDA #1\n\
            STA VIA_port_b\n\
            PULS A\n\
            STA VIA_port_a\n\
            LDA #$7F\n\
            STA VIA_t1_cnt_lo\n\
            CLR VIA_t1_cnt_hi\n\
            LEAX 2,X\n\
            ; Wait for move\n\
            DSWM_W3:\n\
            LDA VIA_int_flags\n\
            ANDA #$40\n\
            BEQ DSWM_W3\n\
            CLR VIA_shift_reg\n\
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
        sfx_checktonedisable:\n\
            LDB ,U                 ; Reload flag byte\n\
            BITB #$10              ; Bit 4: disable tone?\n\
            BEQ sfx_enabletone\n\
        sfx_disabletone:\n\
            LDB $C807              ; Read mixer shadow (MUST be B register)\n\
            ORB #$04               ; Set bit 2 (disable tone C)\n\
            LDA #$07               ; Register 7 (mixer)\n\
            JSR Sound_Byte         ; Write to PSG\n\
            BRA sfx_checknoisedisable  ; Continue to noise check\n\
        \n\
        sfx_enabletone:\n\
            LDB $C807              ; Read mixer shadow (MUST be B register)\n\
            ANDB #$FB              ; Clear bit 2 (enable tone C)\n\
            LDA #$07               ; Register 7 (mixer)\n\
            JSR Sound_Byte         ; Write to PSG\n\
        \n\
        sfx_checknoisedisable:\n\
            LDB ,U                 ; Reload flag byte\n\
            BITB #$80              ; Bit 7: disable noise?\n\
            BEQ sfx_enablenoise\n\
        sfx_disablenoise:\n\
            LDB $C807              ; Read mixer shadow (MUST be B register)\n\
            ORB #$20               ; Set bit 5 (disable noise C)\n\
            LDA #$07               ; Register 7 (mixer)\n\
            JSR Sound_Byte         ; Write to PSG\n\
            BRA sfx_nextframe      ; Done, update pointer\n\
        \n\
        sfx_enablenoise:\n\
            LDB $C807              ; Read mixer shadow (MUST be B register)\n\
            ANDB #$DF              ; Clear bit 5 (enable noise C)\n\
            LDA #$07               ; Register 7 (mixer)\n\
            JSR Sound_Byte         ; Write to PSG\n\
        \n\
        sfx_nextframe:\n\
            STY >SFX_PTR            ; Update pointer for next frame\n\
            RTS\n\
        \n\
        sfx_endofeffect:\n\
            ; Stop SFX - set volume to 0\n\
            CLR >SFX_ACTIVE         ; Mark as inactive\n\
            LDA #$0A                ; Register 10 (volume C)\n\
            LDB #$00                ; Volume = 0\n\
            JSR Sound_Byte\n\
            LDD #$0000\n\
            STD >SFX_PTR            ; Clear pointer\n\
            RTS\n\
        \n"
    );
}

