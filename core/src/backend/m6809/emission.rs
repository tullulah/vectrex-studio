// Emission - High-level code emission functions for M6809 backend
use crate::ast::{Function, Stmt, Module, Expr};
use crate::codegen::CodegenOptions;
use super::{LoopCtx, FuncCtx, emit_stmt, collect_locals, collect_locals_with_params, RuntimeUsage, LineTracker, DebugInfo};
use super::analyze_var_types; // Import the new function
use std::sync::atomic::{AtomicBool, Ordering};

// Tracking for last END position
static LAST_END_SET: AtomicBool = AtomicBool::new(false);

pub fn emit_function(f: &Function, out: &mut String, string_map: &std::collections::BTreeMap<String,String>, opts: &CodegenOptions, tracker: &mut LineTracker, global_names: &[String]) {
    // Reset end position tracking for each function
    LAST_END_SET.store(false, Ordering::Relaxed);
    
    // ✅ CRITICAL: Record the function definition line in .pdb
    // This enables breakpoints on 'def function_name():' lines
    tracker.set_line(f.line);
    out.push_str(&format!("    ; VPy_LINE:{}\n", f.line));
    
    // Map special VPy functions to proper ASM labels
    let label_name = if f.name == "main" {
        "MAIN".to_string()
    } else {
        f.name.to_uppercase()
    };
    
    out.push_str(&format!("{}: ; function\n", label_name));
    out.push_str(&format!("; --- function {} ---\n", f.name));
    let locals = collect_locals_with_params(&f.body, global_names, &f.params);
    
    // Analyze variable types to determine struct instances and their sizes
    let var_info = analyze_var_types(&f.body, &locals, &opts.structs);
    
    // Calculate frame size based on actual variable sizes
    let mut frame_size = 0;
    for var_name in &locals {
        let size = var_info.get(var_name)
            .map(|(_, s)| *s as i32)
            .unwrap_or(2); // Default to 2 bytes for simple variables
        frame_size += size;
    }
    
    if frame_size > 0 { out.push_str(&format!("    LEAS -{},S ; allocate locals\n", frame_size)); }
    // Copy parameters from VAR_ARG to stack locals (parameters are first N locals)
    // Parameters go at: 0,S (param 0), 2,S (param 1), 4,S (param 2), 6,S (param 3)
    for (i, _p) in f.params.iter().enumerate().take(4) {
        let offset = i as i32 * 2; // Each parameter is 2 bytes, sequential
        out.push_str(&format!("    LDD VAR_ARG{}\n    STD {},S ; param {}\n", i, offset, i));
    }
    let fctx = FuncCtx { 
        locals: locals.clone(), 
        frame_size, 
        var_info,
        // Detect if this is a struct method by checking if name contains underscore
        // Format: STRUCTNAME_methodname (e.g., POINT_MOVE, ENTITY_GET_NEW_X)
        struct_type: if f.name.contains('_') {
            // Extract struct name (part before first underscore)
            f.name.split('_').next().map(|s| s.to_string())
        } else {
            None
        },
        // Add function parameters for correct stack offset calculation
        params: f.params.clone(),
    };
    for stmt in &f.body { emit_stmt(stmt, out, &LoopCtx::default(), &fctx, string_map, opts, tracker, 0); }
    if !matches!(f.body.last(), Some(Stmt::Return(_, _))) {
    if frame_size > 0 { out.push_str(&format!("    LEAS {},S ; free locals\n", frame_size)); }
        out.push_str("    RTS\n");
    }
    out.push('\n');
}

// emit_builtin_helpers: simple placeholder wrappers for Vectrex intrinsics.
pub fn emit_builtin_helpers(out: &mut String, usage: &RuntimeUsage, opts: &CodegenOptions, module: &Module, debug_info: &mut DebugInfo) {
    let w = &usage.wrappers_used;
    
    // Joystick builtins (always emit since they're commonly used)
    out.push_str("; === JOYSTICK BUILTIN SUBROUTINES ===\n");
    out.push_str("; J1_X() - Read Joystick 1 X axis (INCREMENTAL - with state preservation)\n");
    out.push_str("; Returns: D = raw value from $C81B after Joy_Analog call\n");
    out.push_str("J1X_BUILTIN:\n");
    out.push_str("    PSHS X       ; Save X (Joy_Analog uses it)\n");
    out.push_str("    JSR $F1AA    ; DP_to_D0 (required for Joy_Analog BIOS call)\n");
    out.push_str("    JSR $F1F5    ; Joy_Analog (updates $C81B from hardware)\n");
    out.push_str("    JSR Reset0Ref ; Full beam reset: zeros DAC (VIA_port_a=0) via Reset_Pen + grounds integrators\n");
    out.push_str("    JSR $F1AF    ; DP_to_C8 (required to read RAM $C81B)\n");
    out.push_str("    LDB $C81B    ; Vec_Joy_1_X (BIOS writes ~$FE at center)\n");
    out.push_str("    SEX          ; Sign-extend B to D\n");
    out.push_str("    ADDD #2      ; Calibrate center offset\n");
    out.push_str("    PULS X       ; Restore X\n");
    out.push_str("    RTS\n\n");
    
    out.push_str("; J1_Y() - Read Joystick 1 Y axis (INCREMENTAL - with state preservation)\n");
    out.push_str("; Returns: D = raw value from $C81C after Joy_Analog call\n");
    out.push_str("J1Y_BUILTIN:\n");
    out.push_str("    PSHS X       ; Save X (Joy_Analog uses it)\n");
    out.push_str("    JSR $F1AA    ; DP_to_D0 (required for Joy_Analog BIOS call)\n");
    out.push_str("    JSR $F1F5    ; Joy_Analog (updates $C81C from hardware)\n");
    out.push_str("    JSR Reset0Ref ; Full beam reset: zeros DAC (VIA_port_a=0) via Reset_Pen + grounds integrators\n");
    out.push_str("    JSR $F1AF    ; DP_to_C8 (required to read RAM $C81C)\n");
    out.push_str("    LDB $C81C    ; Vec_Joy_1_Y (BIOS writes ~$FE at center)\n");
    out.push_str("    SEX          ; Sign-extend B to D\n");
    out.push_str("    ADDD #2      ; Calibrate center offset\n");
    out.push_str("    PULS X       ; Restore X\n");
    out.push_str("    RTS\n\n");
    
    // Button system - Read BIOS transition bits ($C811)
    // Read_Btns (auto-injected) calculates rising edge detection automatically
    // $C80F = raw state (1 while pressed)
    // $C811 = transitions (1 only on 0→1, calculated by BIOS via Vec_Prev_Btns)
    out.push_str("; === BUTTON SYSTEM - BIOS TRANSITIONS ===\n");
    out.push_str("; J1_BUTTON_1-4() - Read transition bits from $C811\n");
    out.push_str("; Read_Btns (auto-injected) calculates: ~(new) OR Vec_Prev_Btns\n");
    out.push_str("; Result: bit=1 ONLY on rising edge (0→1 transition)\n");
    out.push_str("; Returns: D = 1 (just pressed), 0 (not pressed or still held)\n\n");
    
    out.push_str("J1B1_BUILTIN:\n");
    out.push_str("    LDA $C811      ; Read transition bits (Vec_Button_1_1)\n");
    out.push_str("    ANDA #$01      ; Test bit 0 (Button 1)\n");
    out.push_str("    BEQ .J1B1_OFF\n");
    out.push_str("    LDD #1         ; Return pressed (rising edge)\n");
    out.push_str("    RTS\n");
    out.push_str(".J1B1_OFF:\n");
    out.push_str("    LDD #0         ; Return not pressed\n");
    out.push_str("    RTS\n\n");
    
    out.push_str("J1B2_BUILTIN:\n");
    out.push_str("    LDA $C811\n");
    out.push_str("    ANDA #$02      ; Test bit 1 (Button 2)\n");
    out.push_str("    BEQ .J1B2_OFF\n");
    out.push_str("    LDD #1\n");
    out.push_str("    RTS\n");
    out.push_str(".J1B2_OFF:\n");
    out.push_str("    LDD #0\n");
    out.push_str("    RTS\n\n");
    
    out.push_str("J1B3_BUILTIN:\n");
    out.push_str("    LDA $C811\n");
    out.push_str("    ANDA #$04      ; Test bit 2 (Button 3)\n");
    out.push_str("    BEQ .J1B3_OFF\n");
    out.push_str("    LDD #1\n");
    out.push_str("    RTS\n");
    out.push_str(".J1B3_OFF:\n");
    out.push_str("    LDD #0\n");
    out.push_str("    RTS\n\n");
    
    out.push_str("J1B4_BUILTIN:\n");
    out.push_str("    LDA $C811\n");
    out.push_str("    ANDA #$08      ; Test bit 3 (Button 4)\n");
    out.push_str("    BEQ .J1B4_OFF\n");
    out.push_str("    LDD #1\n");
    out.push_str("    RTS\n");
    out.push_str(".J1B4_OFF:\n");
    out.push_str("    LDD #0\n");
    out.push_str("    RTS\n\n");
    
    // Only emit vector phase helper if referenced
    if w.contains("VECTREX_VECTOR_PHASE_BEGIN") {
        if opts.fast_wait {
            out.push_str("VECTREX_VECTOR_PHASE_BEGIN:\n    JSR DP_to_C8\n    JSR VECTREX_RESET0_FAST\n    RTS\n");
        } else {
            out.push_str("VECTREX_VECTOR_PHASE_BEGIN:\n    JSR DP_to_C8\n    JSR Reset0Ref\n    RTS\n");
        }
    }
    if w.contains("VECTREX_DBG_STATIC_VL") {
        out.push_str("VECTREX_DBG_STATIC_VL:\n    JSR DP_to_C8\n    LDU #DBG_STATIC_LIST\n    LDA #$5F\n    JSR Intensity_a\n    JSR Draw_VL\n    RTS\nDBG_STATIC_LIST:\n    FCB $80,$20\n");
    }
    if opts.blink_intensity {
        out.push_str("VECTREX_BLINK_INT:\n    LDA BLINK_STATE\n    EORA #$01\n    STA BLINK_STATE\n    BEQ BLINK_LOW\nBLINK_HIGH: LDA #$5F\n    BRA BLINK_SET\nBLINK_LOW:  LDA #$10\nBLINK_SET:  JSR Intensity_a\n    RTS\n");
    }
    if opts.debug_init_draw {
        out.push_str("VECTREX_DEBUG_DRAW:\n    JSR DP_to_C8\n    LDU #DEBUG_DRAW_LIST\n    LDA #$40\n    JSR Intensity_a\n    JSR Draw_VL\n    RTS\nDEBUG_DRAW_LIST:\n    FCB $80,$40\n");
    }
    if opts.per_frame_silence {
        out.push_str("VECTREX_SILENCE:\n    LDA #0\n    STA $D001\n    CLR $D000\n    LDA #1\n    STA $D001\n    CLR $D000\n    LDA #2\n    STA $D001\n    CLR $D000\n    LDA #3\n    STA $D001\n    CLR $D000\n    LDA #4\n    STA $D001\n    CLR $D000\n    LDA #5\n    STA $D001\n    CLR $D000\n    LDA #6\n    STA $D001\n    CLR $D000\n    LDA #7\n    STA $D001\n    LDA #$3F\n    STA $D000\n    LDA #8\n    STA $D001\n    CLR $D000\n    LDA #9\n    STA $D001\n    CLR $D000\n    LDA #10\n    STA $D001\n    CLR $D000\n    RTS\n");
    }
    if w.contains("VECTREX_PRINT_TEXT") {
        let start_line = out.lines().count() + 1;
        let function_code = "VECTREX_PRINT_TEXT:\n    ; CRITICAL: Print_Str_d requires DP=$D0 and signature is (Y, X, string)\n    ; VPy signature: PRINT_TEXT(x, y, string) -> args (ARG0=x, ARG1=y, ARG2=string)\n    ; BIOS signature: Print_Str_d(A=Y, B=X, U=string)\n    ; NOTE: Do NOT set VIA_cntl here - Reset0Int already set $CC (/ZERO active)\n    ;       Setting $98 would release /ZERO prematurely, causing integrators to drift\n    ;       toward joystick DAC value. Let Moveto_d_7F handle VIA_cntl via $CE.\n    LDA #$D0\n    TFR A,DP       ; Set Direct Page to $D0 for BIOS\n    LDU VAR_ARG2   ; string pointer (ARG2 = third param)\n    LDA VAR_ARG1+1 ; Y (ARG1 = second param)\n    LDB VAR_ARG0+1 ; X (ARG0 = first param)\n    JSR Print_Str_d\n    JSR $F1AF      ; DP_to_C8 (restore before return - CRITICAL for TMPPTR access)\n    RTS\n";
        out.push_str(function_code);
        let end_line = out.lines().count();
        
        // Register ASM function location for debugging
        debug_info.add_asm_function(
            "VECTREX_PRINT_TEXT".to_string(),
            debug_info.asm.clone(),
            start_line,
            end_line,
            "native"
        );
    }
    if w.contains("VECTREX_DEBUG_PRINT") {
        let start_line = out.lines().count() + 1;
        let function_code = "VECTREX_DEBUG_PRINT:\n    ; Debug print to console - writes to gap area (C000-C7FF)\n    ; Write both high and low bytes for proper 16-bit signed interpretation\n    LDA VAR_ARG0     ; Load high byte (for signed interpretation)\n    STA $C002        ; Debug output high byte in gap\n    LDA VAR_ARG0+1   ; Load low byte\n    STA $C000        ; Debug output low byte in unmapped gap\n    LDA #$42         ; Debug marker\n    STA $C001        ; Debug marker to indicate new output\n    RTS\n";
        out.push_str(function_code);
        let end_line = out.lines().count();
        
        // Register ASM function location for debugging  
        debug_info.add_asm_function(
            "VECTREX_DEBUG_PRINT".to_string(),
            debug_info.asm.clone(),
            start_line,
            end_line,
            "native"
        );
    }
    if w.contains("VECTREX_DEBUG_PRINT_LABELED") {
        out.push_str(
            "VECTREX_DEBUG_PRINT_LABELED:\n    ; Debug print with label - writes to gap area (C000-C7FF)\n    ; Write value to debug output (16-bit signed)\n    LDA VAR_ARG1     ; Load value high byte\n    STA $C002        ; Debug output high byte\n    LDA VAR_ARG1+1   ; Load value low byte\n    STA $C000        ; Debug output low byte\n    ; Write label string pointer to C004-C005\n    LDA VAR_ARG0     ; Label string pointer high byte\n    STA $C004        ; Label pointer high in gap\n    LDA VAR_ARG0+1   ; Label string pointer low byte  \n    STA $C005        ; Label pointer low in gap\n    LDA #$FE         ; Labeled debug marker\n    STA $C001        ; Debug marker to indicate labeled output\n    RTS\n"
        );
    }
    if w.contains("VECTREX_POKE") {
        out.push_str(
            "VECTREX_POKE:\n    ; Write byte to memory address\n    ; ARG0 = address (16-bit), ARG1 = value (8-bit)\n    LDX VAR_ARG0     ; Load address into X\n    LDA VAR_ARG1+1   ; Load value (low byte)\n    STA ,X           ; Store value to address\n    RTS\n"
        );
    }
    if w.contains("VECTREX_PEEK") {
        out.push_str(
            "VECTREX_PEEK:\n    ; Read byte from memory address\n    ; ARG0 = address (16-bit), returns value in VAR_ARG0+1\n    LDX VAR_ARG0     ; Load address into X\n    LDA ,X           ; Load value from address\n    STA VAR_ARG0+1   ; Store result in low byte of ARG0\n    RTS\n"
        );
    }
    if w.contains("VECTREX_PRINT_NUMBER") {
        out.push_str(
            "VECTREX_PRINT_NUMBER:\n    ; Print signed decimal number (-9999 to 9999)\n    ; ARG0=X, ARG1=Y, ARG2=value\n    ; STEP 1: Convert number to decimal string (DP=$C8)\n    LDD >VAR_ARG2   ; Load 16-bit value (safe: DP=$C8)\n    STD >RESULT      ; Save to temp\n    LDX #NUM_STR    ; String buffer pointer\n    ; Check sign: negative values get '-' prefix and are negated\n    CMPD #0\n    BPL .PN_DIV1000  ; D >= 0: go directly to digit conversion\n    LDA #'-'\n    STA ,X+          ; Store '-', advance buffer pointer\n    LDD >RESULT\n    COMA\n    COMB\n    ADDD #1          ; Two's complement negation -> absolute value\n    STD >RESULT\n    ; --- 1000s digit ---\n.PN_DIV1000:\n    CLR ,X           ; Counter = 0 (in buffer)\n.PN_L1000:\n    LDD >RESULT\n    SUBD #1000\n    BMI .PN_D1000\n    STD >RESULT\n    INC ,X\n    BRA .PN_L1000\n.PN_D1000:\n    LDA ,X\n    ADDA #'0'\n    STA ,X+\n    ; --- 100s digit ---\n    CLR ,X\n.PN_L100:\n    LDD >RESULT\n    SUBD #100\n    BMI .PN_D100\n    STD >RESULT\n    INC ,X\n    BRA .PN_L100\n.PN_D100:\n    LDA ,X\n    ADDA #'0'\n    STA ,X+\n    ; --- 10s digit ---\n    CLR ,X\n.PN_L10:\n    LDD >RESULT\n    SUBD #10\n    BMI .PN_D10\n    STD >RESULT\n    INC ,X\n    BRA .PN_L10\n.PN_D10:\n    LDA ,X\n    ADDA #'0'\n    STA ,X+\n    ; --- 1s digit (remainder) ---\n    LDD >RESULT\n    ADDB #'0'\n    STB ,X+\n    LDA #$80          ; Terminator (same format as FCC/FCB strings)\n    STA ,X\n.PN_AFTER_CONVERT:\n    ; STEP 2: Set up BIOS and print (NOW change DP to $D0)\n    ; NOTE: Do NOT set VIA_cntl=$98 here - would prematurely release /ZERO\n    LDA #$D0\n    TFR A,DP         ; Set Direct Page to $D0 for BIOS\n    LDA >VAR_ARG1+1  ; Y coordinate\n    LDB >VAR_ARG0+1  ; X coordinate\n    LDU #NUM_STR     ; String pointer\n    JSR Print_Str_d  ; Print using BIOS (A=Y, B=X, U=string)\n    JSR $F1AF        ; DP_to_C8 - restore DP\n    RTS\n"
        );
    }
    if w.contains("VECTREX_MOVE_TO") {
        out.push_str(
            "VECTREX_MOVE_TO:\n    LDA VAR_ARG1+1 ; Y\n    LDB VAR_ARG0+1 ; X\n    JSR Moveto_d\n    ; store new current position\n    LDA VAR_ARG0+1\n    STA VCUR_X\n    LDA VAR_ARG1+1\n    STA VCUR_Y\n    RTS\n"
        );
    }
    if w.contains("VECTREX_DRAW_TO") {
        out.push_str(
            "; Draw from current (VCUR_X,VCUR_Y) to new (x,y) provided in low bytes VAR_ARG0/1.\n; Semántica: igual a MOVE_TO seguido de línea, pero preserva origen previo como punto inicial.\n; Deltas pueden ser ±127 (hardware Vectrex soporta rango completo).\nVECTREX_DRAW_TO:\n    ; Cargar destino (x,y)\n    LDA VAR_ARG0+1  ; Xdest en A temporalmente\n    STA VLINE_DX    ; reutilizar buffer temporal (bajo) para Xdest\n    LDA VAR_ARG1+1  ; Ydest en A\n    STA VLINE_DY    ; reutilizar buffer temporal para Ydest\n    ; Calcular dx = Xdest - VCUR_X\n    LDA VLINE_DX\n    SUBA VCUR_X\n    STA VLINE_DX\n    ; Calcular dy = Ydest - VCUR_Y\n    LDA VLINE_DY\n    SUBA VCUR_Y\n    STA VLINE_DY\n    ; No clamping needed - signed byte arithmetic handles ±127 correctly\n    ; Mover haz al origen previo (VCUR_Y en A, VCUR_X en B)\n    LDA VCUR_Y\n    LDB VCUR_X\n    JSR Moveto_d\n    ; Dibujar línea usando deltas (A=dy, B=dx)\n    LDA VLINE_DY\n    LDB VLINE_DX\n    JSR Draw_Line_d\n    ; Actualizar posición actual al destino exacto original\n    LDA VAR_ARG0+1\n    STA VCUR_X\n    LDA VAR_ARG1+1\n    STA VCUR_Y\n    RTS\n"
        );
    }
    if w.contains("DRAW_LINE_WRAPPER") {
        // Header and setup
        out.push_str("; DRAW_LINE unified wrapper - handles 16-bit signed coordinates\n");
        out.push_str("; Args: (x0,y0,x1,y1,intensity) as 16-bit words\n");
        out.push_str("; Resets beam to center, moves to (x0,y0), draws to (x1,y1)\n");
        out.push_str("DRAW_LINE_WRAPPER:\n");
        out.push_str("    ; Set DP to hardware registers\n");
        out.push_str("    LDA #$D0\n");
        out.push_str("    TFR A,DP\n");
        out.push_str("    JSR Reset0Ref   ; Reset beam to center (0,0) before positioning\n");

        // Set intensity and move to start — use extended addressing since DP=$D0
        out.push_str("    ; Set intensity\n");
        out.push_str("    LDA >RESULT+8+1  ; intensity (low byte) - extended addressing\n");
        out.push_str("    JSR Intensity_a\n");
        out.push_str("    ; Move to start position (y in A, x in B)\n");
        out.push_str("    LDA >RESULT+2+1  ; Y start (low byte) - extended addressing\n");
        out.push_str("    LDB >RESULT+0+1  ; X start (low byte) - extended addressing\n");
        out.push_str("    JSR Moveto_d\n");
        
        // Compute deltas
        out.push_str("    ; Compute deltas using 16-bit arithmetic\n");
        out.push_str("    ; dx = x1 - x0 (treating as signed 16-bit)\n");
        out.push_str("    LDD RESULT+4    ; x1 (RESULT+4, 16-bit)\n");
        out.push_str("    SUBD RESULT+0   ; subtract x0 (RESULT+0, 16-bit)\n");
        out.push_str("    STD VLINE_DX_16 ; Store full 16-bit dx\n");
        out.push_str("    ; dy = y1 - y0 (treating as signed 16-bit)\n");
        out.push_str("    LDD RESULT+6    ; y1 (RESULT+6, 16-bit)\n");
        out.push_str("    SUBD RESULT+2   ; subtract y0 (RESULT+2, 16-bit)\n");
        out.push_str("    STD VLINE_DY_16 ; Store full 16-bit dy\n");
        
        // SEGMENT 1: Clamp and draw first segment
        out.push_str("    ; SEGMENT 1: Clamp dy to ±127 and draw\n");
        out.push_str("    LDD VLINE_DY_16 ; Load full dy\n");
        out.push_str("    CMPD #127\n");
        out.push_str("    BLE DLW_SEG1_DY_LO\n");
        out.push_str("    LDA #127        ; dy > 127: use 127\n");
        out.push_str("    BRA DLW_SEG1_DY_READY\n");
        out.push_str("DLW_SEG1_DY_LO:\n");
        out.push_str("    CMPD #-128\n");
        out.push_str("    BGE DLW_SEG1_DY_NO_CLAMP  ; -128 <= dy <= 127: use original (sign-extended)\n");
        out.push_str("    LDA #$80        ; dy < -128: use -128\n");
        out.push_str("    BRA DLW_SEG1_DY_READY\n");
        out.push_str("DLW_SEG1_DY_NO_CLAMP:\n");
        out.push_str("    LDA VLINE_DY_16+1  ; Use original low byte (already in valid range)\n");
        out.push_str("DLW_SEG1_DY_READY:\n");
        out.push_str("    STA VLINE_DY    ; Save clamped dy for segment 1\n");
        
        // Clamp dx for segment 1
        out.push_str("    ; Clamp dx to ±127\n");
        out.push_str("    LDD VLINE_DX_16\n");
        out.push_str("    CMPD #127\n");
        out.push_str("    BLE DLW_SEG1_DX_LO\n");
        out.push_str("    LDB #127        ; dx > 127: use 127\n");
        out.push_str("    BRA DLW_SEG1_DX_READY\n");
        out.push_str("DLW_SEG1_DX_LO:\n");
        out.push_str("    CMPD #-128\n");
        out.push_str("    BGE DLW_SEG1_DX_NO_CLAMP  ; -128 <= dx <= 127: use original (sign-extended)\n");
        out.push_str("    LDB #$80        ; dx < -128: use -128\n");
        out.push_str("    BRA DLW_SEG1_DX_READY\n");
        out.push_str("DLW_SEG1_DX_NO_CLAMP:\n");
        out.push_str("    LDB VLINE_DX_16+1  ; Use original low byte (already in valid range)\n");
        out.push_str("DLW_SEG1_DX_READY:\n");
        out.push_str("    STB VLINE_DX    ; Save clamped dx for segment 1\n");
        
        // Draw segment 1
        out.push_str("    ; Draw segment 1\n");
        out.push_str("    CLR Vec_Misc_Count\n");
        out.push_str("    LDA VLINE_DY\n");
        out.push_str("    LDB VLINE_DX\n");
        out.push_str("    JSR Draw_Line_d ; Beam moves automatically\n");
        
        // Check if we need segment 2 - for BOTH dy > 127 AND dy < -128
        out.push_str("    ; Check if we need SEGMENT 2 (dy outside ±127 range)\n");
        out.push_str("    LDD VLINE_DY_16 ; Reload original dy\n");
        out.push_str("    CMPD #127\n");
        out.push_str("    BGT DLW_NEED_SEG2  ; dy > 127: needs segment 2\n");
        out.push_str("    CMPD #-128\n");
        out.push_str("    BLT DLW_NEED_SEG2  ; dy < -128: needs segment 2\n");
        out.push_str("    BRA DLW_DONE       ; dy in range ±127: no segment 2\n");
        out.push_str("DLW_NEED_SEG2:\n");
        
        // SEGMENT 2: Handle remaining dy AND dx
        out.push_str("    ; SEGMENT 2: Draw remaining dy and dx\n");
        out.push_str("    ; Calculate remaining dy\n");
        out.push_str("    LDD VLINE_DY_16 ; Load original full dy\n");
        out.push_str("    CMPD #127\n");
        out.push_str("    BGT DLW_SEG2_DY_POS  ; dy > 127\n");
        out.push_str("    ; dy < -128, so we drew -128 in segment 1\n");
        out.push_str("    ; remaining = dy - (-128) = dy + 128\n");
        out.push_str("    ADDD #128       ; Add back the -128 we already drew\n");
        out.push_str("    BRA DLW_SEG2_DY_DONE\n");
        out.push_str("DLW_SEG2_DY_POS:\n");
        out.push_str("    ; dy > 127, so we drew 127 in segment 1\n");
        out.push_str("    ; remaining = dy - 127\n");
        out.push_str("    SUBD #127       ; Subtract 127 we already drew\n");
        out.push_str("DLW_SEG2_DY_DONE:\n");
        out.push_str("    STD VLINE_DY_REMAINING  ; Store remaining dy (16-bit)\n");
        
        // Also calculate remaining dx
        out.push_str("    ; Calculate remaining dx\n");
        out.push_str("    LDD VLINE_DX_16 ; Load original full dx\n");
        out.push_str("    CMPD #127\n");
        out.push_str("    BLE DLW_SEG2_DX_CHECK_NEG\n");
        out.push_str("    ; dx > 127, so we drew 127 in segment 1\n");
        out.push_str("    ; remaining = dx - 127\n");
        out.push_str("    SUBD #127\n");
        out.push_str("    BRA DLW_SEG2_DX_DONE\n");
        out.push_str("DLW_SEG2_DX_CHECK_NEG:\n");
        out.push_str("    CMPD #-128\n");
        out.push_str("    BGE DLW_SEG2_DX_NO_REMAIN  ; -128 <= dx <= 127: no remaining dx\n");
        out.push_str("    ; dx < -128, so we drew -128 in segment 1\n");
        out.push_str("    ; remaining = dx - (-128) = dx + 128\n");
        out.push_str("    ADDD #128\n");
        out.push_str("    BRA DLW_SEG2_DX_DONE\n");
        out.push_str("DLW_SEG2_DX_NO_REMAIN:\n");
        out.push_str("    LDD #0          ; No remaining dx\n");
        out.push_str("DLW_SEG2_DX_DONE:\n");
        out.push_str("    STD VLINE_DX_REMAINING  ; Store remaining dx (16-bit) in VLINE_DX_REMAINING\n");
        
        // Draw segment 2 with both remaining dx and dy
        out.push_str("    ; Setup for Draw_Line_d: A=dy, B=dx (CRITICAL: order matters!)\n");
        out.push_str("    ; Load remaining dy from VLINE_DY_REMAINING (already saved)\n");
        out.push_str("    LDA VLINE_DY_REMAINING+1  ; Low byte of remaining dy\n");
        out.push_str("    LDB VLINE_DX_REMAINING+1  ; Low byte of remaining dx\n");
        out.push_str("    CLR Vec_Misc_Count\n");
        out.push_str("    JSR Draw_Line_d ; Beam continues from segment 1 endpoint\n");
        
        // Cleanup
        out.push_str("DLW_DONE:\n");
        out.push_str("    LDA #$C8       ; CRITICAL: Restore DP to $C8 for our code\n");
        out.push_str("    TFR A,DP\n");
        out.push_str("    RTS\n");
    }
    if w.contains("VECTREX_FRAME_BEGIN") {
        if opts.fast_wait {
            out.push_str(
                "VECTREX_FRAME_BEGIN:\n    LDA VAR_ARG0+1\n    JSR Intensity_a\n    JSR VECTREX_RESET0_FAST\n    RTS\n"
            );
        } else {
            out.push_str(
                "VECTREX_FRAME_BEGIN:\n    LDA VAR_ARG0+1\n    JSR Intensity_a\n    JSR Reset0Ref\n    RTS\n"
            );
        }
    }
    if w.contains("VECTREX_DRAW_VL") {
        out.push_str(
            "VECTREX_DRAW_VL:\n    LDU VAR_ARG0\n    LDA VAR_ARG1+1\n    JSR Intensity_a\n    JSR Draw_VL\n    RTS\n"
        );
    }
    if w.contains("VECTREX_SET_ORIGIN") {
        if opts.fast_wait {
            out.push_str("VECTREX_SET_ORIGIN:\n    JSR VECTREX_RESET0_FAST\n    RTS\n");
        } else {
            out.push_str("VECTREX_SET_ORIGIN:\n    JSR Reset0Ref\n    RTS\n");
        }
    }
    if w.contains("VECTREX_SET_INTENSITY") {
    out.push_str("VECTREX_SET_INTENSITY:\n    ; CRITICAL: Set VIA to DAC mode BEFORE calling BIOS (don't assume state)\n    LDA #$98       ; VIA_cntl = $98 (DAC mode)\n    STA >$D00C     ; VIA_cntl\n    LDA #$D0\n    TFR A,DP       ; Set Direct Page to $D0 for BIOS\n    LDA VAR_ARG0+1\n    JSR __Intensity_a\n    RTS\n");
    }
    if w.contains("SETUP_DRAW_COMMON") {
        out.push_str(
            "; Common drawing setup - sets DP register and resets integrator origin\n; Eliminates repetitive LDA #$D0; TFR A,DP; JSR Reset0Ref sequences\nSETUP_DRAW_COMMON:\n    ; CRITICAL: Set VIA to DAC mode BEFORE calling BIOS (don't assume state)\n    LDA #$98       ; VIA_cntl = $98 (DAC mode for vector drawing)\n    STA >$D00C     ; VIA_cntl\n    LDA #$D0\n    TFR A,DP\n    JSR Reset0Ref\n    RTS\n"
        );
    }
    if w.contains("VECTREX_WAIT_RECAL") || opts.fast_wait {
        if opts.fast_wait { out.push_str("VECTREX_WAIT_RECAL:\n    LDA #$D0\n    TFR A,DP\n    LDA FAST_WAIT_HIT\n    INCA\n    STA FAST_WAIT_HIT\n    RTS\n");
            out.push_str("VECTREX_RESET0_FAST:\n    LDA #$D0\n    TFR A,DP\n    CLR Vec_Dot_Dwell\n    CLR Vec_Loop_Count\n    RTS\n"); } else { out.push_str("VECTREX_WAIT_RECAL:\n    JSR Wait_Recal\n    RTS\n"); }
    }
    if w.contains("VECTREX_PLAY_MUSIC1") {
        // Simple wrapper to restart the default MUSIC1 tune each frame or once. BIOS expects U to point to music data table at (?), but calling MUSIC1 vector reinitializes tune.
        out.push_str("VECTREX_PLAY_MUSIC1:\n    JSR MUSIC1\n    RTS\n");
    }
    
    // BIOS music system handles all PSG operations internally - no custom helpers needed
    
    // DRAW_VECTOR_RUNTIME: Old helper - NO LONGER USED
    // Now using inline code with Draw_VLc BIOS function
    // (removed to avoid label conflicts with inline code)
    
    // PLAY_MUSIC_RUNTIME: Direct PSG music player (inspired by Christman2024/malbanGit)
    // Writes directly to PSG chip, bypassing BIOS
    // Force generation if music assets exist or PLAY_MUSIC/PLAY_SFX calls are in code
    if opts.has_audio(module) {
        out.push_str(
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
            ; RAM variables (defined via ram.allocate in mod.rs):\n\
            ; PSG_MUSIC_PTR, PSG_MUSIC_START, PSG_IS_PLAYING,\n\
            ; PSG_MUSIC_ACTIVE, PSG_DELAY_FRAMES\n\
            \n\
            ; PLAY_MUSIC_RUNTIME - Start PSG music playback\n\
            ; Input: X = pointer to PSG music data\n\
            PLAY_MUSIC_RUNTIME:\n\
            STX >PSG_MUSIC_PTR     ; Store current music pointer (force extended)\n\
            STX >PSG_MUSIC_START   ; Store start pointer for loops (force extended)\n\
            CLR >PSG_DELAY_FRAMES  ; Clear delay counter\n\
            LDA #$01\n\
            STA >PSG_IS_PLAYING ; Mark as playing (extended - var at 0xC8A0)\n\
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
            STA >PSG_MUSIC_ACTIVE  ; Mark music system active (for PSG logging)\n\
            LDA >PSG_IS_PLAYING ; Check if playing (extended - var at 0xC8A0)\n\
            BEQ PSG_update_done    ; Not playing, exit\n\
            \n\
            LDX >PSG_MUSIC_PTR     ; Load pointer (force extended - LDX has no DP mode)\n\
            BEQ PSG_update_done    ; No music loaded\n\
            \n\
            ; Read frame count byte (number of register writes)\n\
            LDB ,X+\n\
            BEQ PSG_music_ended    ; Count=0 means end (no loop)\n\
            CMPB #$FF              ; Check for loop command\n\
            BEQ PSG_music_loop     ; $FF means loop (never valid as count)\n\
            \n\
            ; Process frame - push counter to stack\n\
            PSHS B                 ; Save count on stack\n\
            \n\
            ; Write register/value pairs to PSG\n\
PSG_write_loop:\n\
            LDA ,X+                ; Load register number\n\
            LDB ,X+                ; Load register value\n\
            PSHS X                 ; Save pointer (after reads)\n\
            \n\
            ; WRITE_PSG sequence\n\
            STA VIA_port_a         ; Store register number\n\
            LDA #$19               ; BDIR=1, BC1=1 (LATCH)\n\
            STA VIA_port_b\n\
            LDA #$01               ; BDIR=0, BC1=0 (INACTIVE)\n\
            STA VIA_port_b\n\
            LDA VIA_port_a         ; Read status\n\
            STB VIA_port_a         ; Store data\n\
            LDB #$11               ; BDIR=1, BC1=0 (WRITE)\n\
            STB VIA_port_b\n\
            LDB #$01               ; BDIR=0, BC1=0 (INACTIVE)\n\
            STB VIA_port_b\n\
            \n\
            PULS X                 ; Restore pointer\n\
            PULS B                 ; Get counter\n\
            DECB                   ; Decrement\n\
            BEQ PSG_frame_done     ; Done with this frame\n\
            PSHS B                 ; Save counter back\n\
            BRA PSG_write_loop\n\
            \n\
PSG_frame_done:\n\
            \n\
            ; Frame complete - update pointer and done\n\
            STX >PSG_MUSIC_PTR     ; Update pointer (force extended)\n\
            BRA PSG_update_done\n\
            \n\
PSG_music_ended:\n\
            CLR >PSG_IS_PLAYING ; Stop playback (extended - var at 0xC8A0)\n\
            ; NOTE: Do NOT write PSG registers here - corrupts VIA for vector drawing\n\
            ; Music will fade naturally as frame data stops updating\n\
            BRA PSG_update_done\n\
            \n\
PSG_music_loop:\n\
            ; Loop command: $FF followed by 2-byte address (FDB)\n\
            ; X points past $FF, read the target address\n\
            LDD ,X                 ; Load 2-byte loop target address\n\
            STD >PSG_MUSIC_PTR     ; Update pointer to loop start\n\
            ; Exit - next frame will start from loop target\n\
            BRA PSG_update_done\n\
            \n\
PSG_update_done:\n\
            CLR >PSG_MUSIC_ACTIVE  ; Clear flag (music system done)\n\
            RTS\n\
            \n\
            ; ============================================================================\n\
            ; STOP_MUSIC_RUNTIME - Stop music playback\n\
            ; ============================================================================\n\
            STOP_MUSIC_RUNTIME:\n\
            CLR >PSG_IS_PLAYING ; Clear playing flag (extended - var at 0xC8A0)\n\
            CLR >PSG_MUSIC_PTR     ; Clear pointer high byte (force extended)\n\
            CLR >PSG_MUSIC_PTR+1   ; Clear pointer low byte (force extended)\n\
            ; NOTE: Do NOT write PSG registers here - corrupts VIA for vector drawing\n\
            RTS\n\
            \n\
            ; ============================================================================\n\
            ; AUDIO_UPDATE - Unified music + SFX update (auto-injected after WAIT_RECAL)\n\
            ; ============================================================================\n\
            ; Processes both music (channel B) and SFX (channel C) in one pass\n\
            ; Uses Sound_Byte (BIOS) for PSG writes - compatible with both systems\n\
            ; Sets DP=$D0 once at entry, restores at exit\n\
            ; RAM variables: SFX_PTR, SFX_ACTIVE (defined via ram.allocate in mod.rs)\n\
            \n\
            AUDIO_UPDATE:\n\
            PSHS DP                 ; Save current DP\n\
            LDA #$D0                ; Set DP=$D0 (Sound_Byte requirement)\n\
            TFR A,DP\n\
            \n\
            ; UPDATE MUSIC (channel B: registers 9, 11-14)\n\
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
            ; Mark that next time we should read delay, not count\n\
            ; (This is implicit - after processing, X points to next delay byte)\n\
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
            AU_DONE:\n\
            PULS DP                 ; Restore original DP\n\
            RTS\n\
            \n"
        );
    }
    
    // PLAY_SFX_RUNTIME: Sound effects player for .vsfx assets (parametric sounds)
    // Only emit if PLAY_SFX() builtin is actually used in code
    // PLAY_SFX_RUNTIME: AYFX player (Richard Chadd system - 1 channel, channel C)
    // Only emit if PLAY_SFX() builtin is actually used in code
    if w.contains("PLAY_SFX_RUNTIME") {
        out.push_str(
            "; ============================================================================\n\
            ; AYFX SOUND EFFECTS PLAYER (Richard Chadd original system)\n\
            ; ============================================================================\n\
            ; Uses channel C (registers 4/5=tone, 6=noise, 10=volume, 7=mixer bit2/bit5)\n\
            ; RAM variables: SFX_PTR (16-bit), SFX_ACTIVE (8-bit)\n\
            ; AYFX format: flag byte + optional data per frame, end marker $D0 $20\n\
            ; Flag bits: 0-3=volume, 4=disable tone, 5=tone data present,\n\
            ;            6=noise data present, 7=disable noise\n\
            ; ============================================================================\n\
            ; (RAM variables defined in AUDIO_UPDATE section above)\n\
            \n\
            ; PLAY_SFX_RUNTIME - Start SFX playback\n\
            ; Input: X = pointer to AYFX data\n\
            PLAY_SFX_RUNTIME:\n\
                STX SFX_PTR            ; Store pointer\n\
                LDA #$01\n\
                STA SFX_ACTIVE         ; Mark as active\n\
                RTS\n\
            \n\
            ; SFX_UPDATE - Process one AYFX frame (call once per frame in loop)\n\
            SFX_UPDATE:\n\
                LDA SFX_ACTIVE         ; Check if active\n\
                BEQ noay               ; Not active, skip\n\
                JSR sfx_doframe        ; Process one frame\n\
            noay:\n\
                RTS\n\
            \n\
            ; sfx_doframe - AYFX frame parser (Richard Chadd original)\n\
            sfx_doframe:\n\
                LDU SFX_PTR            ; Get current frame pointer\n\
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
                STY SFX_PTR            ; Update pointer for next frame\n\
                RTS\n\
            \n\
            sfx_endofeffect:\n\
                ; Stop SFX - set volume to 0\n\
                CLR SFX_ACTIVE         ; Mark as inactive\n\
                LDA #$0A               ; Register 10 (volume C)\n\
                LDB #$00               ; Volume = 0\n\
                JSR Sound_Byte\n\
                LDD #$0000\n\
                STD SFX_PTR            ; Clear pointer\n\
                RTS\n\
            \n"
        );
    }
    
    // Stub sfx_doframe - only defined if AUDIO_UPDATE was emitted (has audio assets)
    // This ensures AUDIO_UPDATE can always call it without linker errors
    // Check if AUDIO_UPDATE was emitted but sfx_doframe wasn't (no PLAY_SFX_RUNTIME)
    if out.contains("AUDIO_UPDATE") && !out.contains("sfx_doframe:") {
        out.push_str(
            r#"; sfx_doframe stub (SFX not used in this project)
sfx_doframe:
	RTS

"#
        );
    }
    // Trig tables are emitted later in data section.
    
    // ===========================================================================
    // BIOS WRAPPERS - VIDE/gcc6809 compatible calling convention
    // ===========================================================================
    // These wrappers ensure DP=$D0 is set before each BIOS call, mimicking
    // the behavior of VIDE's auto-generated wrapper functions.
    // Using these wrappers instead of direct BIOS calls eliminates issues
    // with Direct Page register state across multiple calls.
    
    out.push_str("; BIOS Wrappers - VIDE compatible (ensure DP=$D0 per call)\n");
    
    // __Intensity_a wrapper - VIDE compatible (JMP not JSR)
    out.push_str(
        "__Intensity_a:\n\
        TFR B,A         ; Move B to A (BIOS expects intensity in A)\n\
        JMP Intensity_a ; JMP (not JSR) - BIOS returns to original caller\n"
    );
    
    // __Reset0Ref wrapper - VIDE compatible (JMP not JSR)
    out.push_str(
        "__Reset0Ref:\n\
        JMP Reset0Ref   ; JMP (not JSR) - BIOS returns to original caller\n"
    );
    
    // __Moveto_d wrapper - VIDE compatible (JMP not JSR)
    // Caller pushes Y parameter on stack, X in B register
    out.push_str(
        "__Moveto_d:\n\
        LDA 2,S         ; Get Y from stack (after return address)\n\
        JMP Moveto_d    ; JMP (not JSR) - BIOS returns to original caller\n"
    );
    
    // __Draw_Line_d wrapper - VIDE compatible (JMP not JSR)
    // Caller pushes dy parameter on stack, dx in B register
    out.push_str(
        "__Draw_Line_d:\n\
        LDA 2,S         ; Get dy from stack (after return address)\n\
        JMP Draw_Line_d ; JMP (not JSR) - BIOS returns to original caller\n"
    );

    // Draw_Sync_List - EXACT translation of Malban's draw_synced_list_c
    // Only emit if DRAW_VECTOR is used (detected via uses_draw_vector flag)
    if usage.uses_draw_vector || usage.uses_draw_vector_ex || usage.uses_show_level {
        // Data format: intensity, y_start, x_start, next_y, next_x, [flag, dy, dx]*, 2
        out.push_str(
            "; ============================================================================\n\
            ; Draw_Sync_List - EXACT port of Malban's draw_synced_list_c\n\
            ; Data: FCB intensity, y_start, x_start, next_y, next_x, [flag, dy, dx]*, 2\n\
            ; ============================================================================\n\
            Draw_Sync_List:\n\
        ; ITERACIÓN 11: Loop completo dentro (bug assembler arreglado, datos embebidos OK)\n\
        LDA ,X+                 ; intensity\n\
        JSR $F2AB               ; BIOS Intensity_a (expects value in A)\n\
        LDB ,X+                 ; y_start\n\
        LDA ,X+                 ; x_start\n\
        STD TEMP_YX             ; Guardar en variable temporal (evita stack)\n\
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
        LDD TEMP_YX             ; Recuperar y,x\n\
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
        DSL_W1:\n\
        LDA VIA_int_flags\n\
        ANDA #$40\n\
        BEQ DSL_W1\n\
        ; Loop de dibujo\n\
        DSL_LOOP:\n\
        LDA ,X+                 ; Read flag\n\
        CMPA #2                 ; Check end marker\n\
        LBEQ DSL_DONE           ; Exit if end (long branch)\n\
        CMPA #1                 ; Check next path marker\n\
        LBEQ DSL_NEXT_PATH      ; Process next path (long branch)\n\
        ; Draw line\n\
        CLR Vec_Misc_Count      ; Clear for relative line drawing (CRITICAL for continuity)\n\
        LDB ,X+                 ; dy\n\
        LDA ,X+                 ; dx\n\
        PSHS A                  ; Save dx\n\
        STB VIA_port_a          ; dy to DAC\n\
        CLR VIA_port_b\n\
        LDA #1\n\
        STA VIA_port_b\n\
        PULS A                  ; Restore dx\n\
        STA VIA_port_a          ; dx to DAC\n\
        CLR VIA_t1_cnt_hi\n\
        LDA #$FF\n\
        STA VIA_shift_reg\n\
        ; Wait for line draw\n\
        DSL_W2:\n\
        LDA VIA_int_flags\n\
        ANDA #$40\n\
        BEQ DSL_W2\n\
        CLR VIA_shift_reg\n\
        LBRA DSL_LOOP            ; Long branch back to loop start\n\
        ; Next path: read new intensity and header, then continue drawing\n\
        DSL_NEXT_PATH:\n\
        ; Save current X position before reading anything\n\
        TFR X,D                 ; D = X (current position)\n\
        PSHS D                  ; Save X address\n\
        LDA ,X+                 ; Read intensity (X now points to y_start)\n\
        PSHS A                  ; Save intensity\n\
        LDB ,X+                 ; y_start\n\
        LDA ,X+                 ; x_start (X now points to next_y)\n\
        STD TEMP_YX             ; Save y,x\n\
        PULS A                  ; Get intensity back\n\
        PSHS A                  ; Save intensity again\n\
        LDA #$D0\n\
        TFR A,DP                ; Set DP=$D0 (BIOS requirement)\n\
        PULS A                  ; Restore intensity\n\
        JSR $F2AB               ; BIOS Intensity_a (may corrupt X!)\n\
        ; Restore X to point to next_y,next_x (after the 3 bytes we read)\n\
        PULS D                  ; Get original X\n\
        ADDD #3                 ; Skip intensity, y_start, x_start\n\
        TFR D,X                 ; X now points to next_y\n\
        ; Reset to zero (same as Draw_Sync_List start)\n\
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
        STB VIA_port_a          ; y to DAC\n\
        PSHS A\n\
        LDA #$CE\n\
        STA VIA_cntl\n\
        CLR VIA_port_b\n\
        LDA #1\n\
        STA VIA_port_b\n\
        PULS A\n\
        STA VIA_port_a          ; x to DAC\n\
        LDA #$7F\n\
        STA VIA_t1_cnt_lo\n\
        CLR VIA_t1_cnt_hi\n\
        LEAX 2,X                ; Skip next_y, next_x\n\
        ; Wait for move\n\
        DSL_W3:\n\
        LDA VIA_int_flags\n\
        ANDA #$40\n\
        BEQ DSL_W3\n\
        CLR VIA_shift_reg       ; Clear before continuing\n\
        LBRA DSL_LOOP            ; Continue drawing - LONG BRANCH\n\
        DSL_DONE:\n\
        RTS\n"
        );
    }

    // Draw_Sync_List_At - Only emit if DRAW_VECTOR with offset is used
    if usage.uses_draw_vector_ex || usage.uses_show_level {
        out.push_str("\n\
        ; ============================================================================\n\
        ; Draw_Sync_List_At - Draw vector at offset position (DRAW_VEC_X, DRAW_VEC_Y)\n\
        ; Same as Draw_Sync_List but adds offset to y_start, x_start coordinates\n\
        ; Uses: DRAW_VEC_X, DRAW_VEC_Y (set by DRAW_VECTOR before calling this)\n\
        ; ============================================================================\n\
        Draw_Sync_List_At:\n\
        LDA ,X+                 ; intensity\n\
        PSHS A                  ; Save intensity\n\
        LDA #$D0\n\
        PULS A                  ; Restore intensity\n\
        JSR $F2AB               ; BIOS Intensity_a\n\
        LDB ,X+                 ; y_start from .vec\n\
        ADDB DRAW_VEC_Y         ; Add Y offset\n\
        LDA ,X+                 ; x_start from .vec\n\
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
        LDD TEMP_YX             ; Recuperar y,x ajustado\n\
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
        DSLA_W1:\n\
        LDA VIA_int_flags\n\
        ANDA #$40\n\
        BEQ DSLA_W1\n\
        ; Loop de dibujo (same as Draw_Sync_List)\n\
        DSLA_LOOP:\n\
        LDA ,X+                 ; Read flag\n\
        CMPA #2                 ; Check end marker\n\
        LBEQ DSLA_DONE\n\
        CMPA #1                 ; Check next path marker\n\
        LBEQ DSLA_NEXT_PATH\n\
        ; Draw line\n\
        CLR Vec_Misc_Count      ; Clear for relative line drawing (CRITICAL for continuity)\n\
        LDB ,X+                 ; dy\n\
        LDA ,X+                 ; dx\n\
        PSHS A                  ; Save dx\n\
        STB VIA_port_a          ; dy to DAC\n\
        CLR VIA_port_b\n\
        LDA #1\n\
        STA VIA_port_b\n\
        PULS A                  ; Restore dx\n\
        STA VIA_port_a          ; dx to DAC\n\
        CLR VIA_t1_cnt_hi\n\
        LDA #$FF\n\
        STA VIA_shift_reg\n\
        ; Wait for line draw\n\
        DSLA_W2:\n\
        LDA VIA_int_flags\n\
        ANDA #$40\n\
        BEQ DSLA_W2\n\
        CLR VIA_shift_reg\n\
        LBRA DSLA_LOOP           ; Long branch\n\
        ; Next path: add offset to new coordinates too\n\
        DSLA_NEXT_PATH:\n\
        TFR X,D\n\
        PSHS D\n\
        LDA ,X+                 ; Read intensity\n\
        PSHS A\n\
        LDB ,X+                 ; y_start\n\
        ADDB DRAW_VEC_Y         ; Add Y offset to new path\n\
        LDA ,X+                 ; x_start\n\
        ADDA DRAW_VEC_X         ; Add X offset to new path\n\
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
        ; Move to new start position (already offset-adjusted)\n\
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
        DSLA_W3:\n\
        LDA VIA_int_flags\n\
        ANDA #$40\n\
        BEQ DSLA_W3\n\
        CLR VIA_shift_reg\n\
        LBRA DSLA_LOOP           ; Long branch\n\
        DSLA_DONE:\n\
        RTS\n"
        );
    }
    
    // Draw_Sync_List_At_With_Mirrors - Only emit if DRAW_VECTOR, DRAW_VECTOR_EX or SHOW_LEVEL is used
    if usage.uses_draw_vector || usage.uses_draw_vector_ex || usage.uses_show_level {
        // Draw_Sync_List_At_With_Mirrors: Unified mirror support (X, Y, or both)
        // Reads MIRROR_X and MIRROR_Y flags (set by DRAW_VECTOR_EX) and conditionally negates
        // Much more efficient than 4 separate functions - one unified runtime logic with conditional branches
        // MIRROR_X: 0=normal, 1=negate X (horizontal flip)
        // MIRROR_Y: 0=normal, 1=negate Y (vertical flip)
        // Can combine: both flags set = flip both axes
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
    
    // ========== DRAW_CIRCLE_RUNTIME - Only emit if DRAW_CIRCLE is used ==========
    if usage.uses_draw_circle {
        out.push_str(
            "; ============================================================================\n\
            ; DRAW_CIRCLE_RUNTIME - Draw circle with runtime parameters\n\
            ; ============================================================================\n\
        ; Follows Draw_Sync_List_At pattern: read params BEFORE DP change\n\
        ; Inputs: DRAW_CIRCLE_XC, DRAW_CIRCLE_YC, DRAW_CIRCLE_DIAM, DRAW_CIRCLE_INTENSITY (bytes in RAM)\n\
        ; Uses 8 segments (regular octagon inscribed in circle) with unrolled loop\n\
        DRAW_CIRCLE_RUNTIME:\n\
        ; Read ALL parameters into registers/stack BEFORE changing DP (critical!)\n\
        ; (These are byte variables, use LDB not LDD)\n\
        LDB DRAW_CIRCLE_INTENSITY\n\
        PSHS B                 ; Save intensity on stack\n\
        \n\
        LDB DRAW_CIRCLE_DIAM\n\
        SEX                    ; Sign-extend to 16-bit (diameter is unsigned 0..255)\n\
        LSRA                   ; Divide by 2 to get radius\n\
        RORB\n\
        STD DRAW_CIRCLE_TEMP   ; DRAW_CIRCLE_TEMP = radius (16-bit)\n\
        \n\
        LDB DRAW_CIRCLE_XC     ; xc (signed -128..127)\n\
        SEX\n\
        STD DRAW_CIRCLE_TEMP+2 ; Save xc\n\
        \n\
        LDB DRAW_CIRCLE_YC     ; yc (signed -128..127)\n\
        SEX\n\
        STD DRAW_CIRCLE_TEMP+4 ; Save yc\n\
        \n\
        ; NOW safe to setup BIOS (all params are in DRAW_CIRCLE_TEMP+stack)\n\
        LDA #$D0\n\
        TFR A,DP\n\
        JSR Reset0Ref\n\
        \n\
        ; Set intensity (from stack)\n\
        PULS A                 ; Get intensity from stack\n\
        CMPA #$5F\n\
        BEQ DCR_intensity_5F\n\
        JSR Intensity_a\n\
        BRA DCR_after_intensity\n\
DCR_intensity_5F:\n\
        JSR Intensity_5F\n\
DCR_after_intensity:\n\
        \n\
        ; Move to start position: (xc + radius, yc)\n\
        ; radius = DRAW_CIRCLE_TEMP, xc = DRAW_CIRCLE_TEMP+2, yc = DRAW_CIRCLE_TEMP+4\n\
        LDD DRAW_CIRCLE_TEMP   ; D = radius\n\
        ADDD DRAW_CIRCLE_TEMP+2 ; D = xc + radius\n\
        TFR B,B                ; Keep X in B (low byte)\n\
        PSHS B                 ; Save X on stack\n\
        LDD DRAW_CIRCLE_TEMP+4 ; Load yc\n\
        TFR B,A                ; Y to A\n\
        PULS B                 ; X to B\n\
        JSR Moveto_d\n\
        \n\
        ; Precompute r/4 and 3r/4 for regular octagon segments\n\
        ; Radius low byte is at DRAW_CIRCLE_TEMP+1\n\
        LDB DRAW_CIRCLE_TEMP+1 ; Load radius (low byte)\n\
        LSRB\n\
        LSRB                   ; B = r/4\n\
        STB DRAW_CIRCLE_TEMP+6 ; Save r/4 in spare byte\n\
        LDB DRAW_CIRCLE_TEMP+1 ; Load radius\n\
        SUBB DRAW_CIRCLE_TEMP+6 ; B = r - r/4 = 3r/4\n\
        STB DRAW_CIRCLE_TEMP+7 ; Save 3r/4 in spare byte\n\
        \n\
        ; Draw 8 unrolled segments - regular octagon inscribed in circle\n\
        ; Counterclockwise from rightmost point (xc+r, yc)\n\
        ; Draw_Line_d(A=dy, B=dx)\n\
        \n\
        ; Seg 0 (0->45 deg): dy=+3r/4, dx=-r/4\n\
        CLR Vec_Misc_Count\n\
        LDA DRAW_CIRCLE_TEMP+7  ; 3r/4\n\
        LDB DRAW_CIRCLE_TEMP+6  ; r/4\n\
        NEGB\n\
        JSR Draw_Line_d\n\
        \n\
        ; Seg 1 (45->90 deg): dy=+r/4, dx=-3r/4\n\
        CLR Vec_Misc_Count\n\
        LDA DRAW_CIRCLE_TEMP+6  ; r/4\n\
        LDB DRAW_CIRCLE_TEMP+7  ; 3r/4\n\
        NEGB\n\
        JSR Draw_Line_d\n\
        \n\
        ; Seg 2 (90->135 deg): dy=-r/4, dx=-3r/4\n\
        CLR Vec_Misc_Count\n\
        LDA DRAW_CIRCLE_TEMP+6  ; r/4\n\
        NEGA\n\
        LDB DRAW_CIRCLE_TEMP+7  ; 3r/4\n\
        NEGB\n\
        JSR Draw_Line_d\n\
        \n\
        ; Seg 3 (135->180 deg): dy=-3r/4, dx=-r/4\n\
        CLR Vec_Misc_Count\n\
        LDA DRAW_CIRCLE_TEMP+7  ; 3r/4\n\
        NEGA\n\
        LDB DRAW_CIRCLE_TEMP+6  ; r/4\n\
        NEGB\n\
        JSR Draw_Line_d\n\
        \n\
        ; Seg 4 (180->225 deg): dy=-3r/4, dx=+r/4\n\
        CLR Vec_Misc_Count\n\
        LDA DRAW_CIRCLE_TEMP+7  ; 3r/4\n\
        NEGA\n\
        LDB DRAW_CIRCLE_TEMP+6  ; r/4 (positive)\n\
        JSR Draw_Line_d\n\
        \n\
        ; Seg 5 (225->270 deg): dy=-r/4, dx=+3r/4\n\
        CLR Vec_Misc_Count\n\
        LDA DRAW_CIRCLE_TEMP+6  ; r/4\n\
        NEGA\n\
        LDB DRAW_CIRCLE_TEMP+7  ; 3r/4 (positive)\n\
        JSR Draw_Line_d\n\
        \n\
        ; Seg 6 (270->315 deg): dy=+r/4, dx=+3r/4\n\
        CLR Vec_Misc_Count\n\
        LDA DRAW_CIRCLE_TEMP+6  ; r/4 (positive)\n\
        LDB DRAW_CIRCLE_TEMP+7  ; 3r/4 (positive)\n\
        JSR Draw_Line_d\n\
        \n\
        ; Seg 7 (315->360 deg): dy=+3r/4, dx=+r/4\n\
        CLR Vec_Misc_Count\n\
        LDA DRAW_CIRCLE_TEMP+7  ; 3r/4 (positive)\n\
        LDB DRAW_CIRCLE_TEMP+6  ; r/4 (positive)\n\
        JSR Draw_Line_d\n\
        \n\
        RTS\n\
        \n"
        );
    }
    
    // ========== JOYSTICK SUPPORT ==========
    // VPy programs now use REAL BIOS routines just like commercial ROMs:
    // - Joy_Digital ($F1F8) - reads joystick axes, updates Vec_Joy_1_X/Y ($C81B/$C81C)
    // - Read_Btns ($F1BA) - reads button states, updates Vec_Btn_State ($C80F)
    //
    // Benefits:
    // 1. Perfect compatibility with real Vectrex hardware
    // 2. Minestorm and BIOS games work correctly with gamepad
    // 3. No custom memory-mapped registers needed
    // 4. Standard Vectrex programming practice
    //
    // The BIOS calls are inlined directly in emit_builtin_call() for J1_X(), J1_Y(), etc.
    // No helper routines needed - everything goes through official BIOS entry points.
    
    // === LEVEL SYSTEM HELPERS ===
    if w.contains("LOAD_LEVEL_RUNTIME") {
        out.push_str("; === LOAD_LEVEL_RUNTIME ===\n");
        out.push_str("; Load level data from ROM and copy objects to RAM\n");
        out.push_str("; Input: X = pointer to level data in ROM\n");
        out.push_str("; Output: LEVEL_PTR = pointer to level header (persistent)\n");
        out.push_str(";         RESULT    = pointer to level header (return value)\n");
        out.push_str(";         OPTIMIZATION: BG and FG are static → read from ROM directly\n");
        out.push_str(";                       Only GP is copied to RAM (has dynamic objects)\n");
        out.push_str(";           LEVEL_GP_BUFFER (max 16 objects * 20 bytes = 320 bytes)\n");
        out.push_str("LOAD_LEVEL_RUNTIME:\n");
        out.push_str("    PSHS D,X,Y,U     ; Preserve registers\n");
        out.push_str("    \n");
        out.push_str("    ; Store level pointer persistently\n");
        out.push_str("    STX >LEVEL_PTR\n");
        out.push_str("    \n");
        out.push_str("    ; Skip world bounds (8 bytes) + time/score (4 bytes)\n");
        out.push_str("    LEAX 12,X        ; X now points to object counts\n");
        out.push_str("    \n");
        out.push_str("    ; Read object counts\n");
        out.push_str("    LDB ,X+          ; B = bgCount\n");
        out.push_str("    STB >LEVEL_BG_COUNT\n");
        out.push_str("    LDB ,X+          ; B = gameplayCount\n");
        out.push_str("    STB >LEVEL_GP_COUNT\n");
        out.push_str("    LDB ,X+          ; B = fgCount\n");
        out.push_str("    STB >LEVEL_FG_COUNT\n");
        out.push_str("    \n");
        out.push_str("    ; Read layer pointers (ROM)\n");
        out.push_str("    LDD ,X++         ; D = bgObjectsPtr (ROM)\n");
        out.push_str("    STD >LEVEL_BG_ROM_PTR\n");
        out.push_str("    LDD ,X++         ; D = gameplayObjectsPtr (ROM)\n");
        out.push_str("    STD >LEVEL_GP_ROM_PTR\n");
        out.push_str("    LDD ,X++         ; D = fgObjectsPtr (ROM)\n");
        out.push_str("    STD >LEVEL_FG_ROM_PTR\n");
        out.push_str("    \n");
        out.push_str("    ; === Setup GP pointer: RAM buffer if physics, ROM if static ===\n");
        out.push_str("    LDB >LEVEL_GP_COUNT\n");
        out.push_str("    BEQ LLR_SKIP_GP  ; Skip if zero objects\n");
        out.push_str("    \n");
        if opts.buffer_requirements.as_ref().map(|r| r.needs_buffer).unwrap_or(false) {
            out.push_str("    ; Physics enabled → Copy GP objects to RAM buffer\n");
            out.push_str("    LDA #$FF         ; Empty marker\n");
            out.push_str("    LDU #LEVEL_GP_BUFFER\n");
            out.push_str("    LDB #16          ; 16 objects\n");
            out.push_str("LLR_CLR_GP_LOOP:\n");
            out.push_str("    STA ,U           ; Write 0xFF to type byte\n");
            out.push_str("    LEAU 14,U\n");
            out.push_str("    DECB\n");
            out.push_str("    BNE LLR_CLR_GP_LOOP\n");
            out.push_str("    \n");
            out.push_str("    LDB >LEVEL_GP_COUNT   ; Reload count\n");
            out.push_str("    LDX >LEVEL_GP_ROM_PTR ; X = source (ROM)\n");
            out.push_str("    LDU #LEVEL_GP_BUFFER ; U = destination (RAM)\n");
            out.push_str("    PSHS U              ; Save buffer start BEFORE copy\n");
            out.push_str("    JSR LLR_COPY_OBJECTS ; Copy B objects from X to U\n");
            out.push_str("    PULS D              ; Restore buffer start\n");
            out.push_str("    STD >LEVEL_GP_PTR    ; Store RAM buffer pointer\n");
            out.push_str("    BRA LLR_GP_DONE\n");
        } else {
            out.push_str("    ; No physics → GP reads from ROM like BG/FG\n");
            out.push_str("    LDD >LEVEL_GP_ROM_PTR ; Just point to ROM\n");
            out.push_str("    STD >LEVEL_GP_PTR    ; Store ROM pointer\n");
        }
        out.push_str("LLR_GP_DONE:\n");
        out.push_str("LLR_SKIP_GP:\n");
        out.push_str("    \n");
        out.push_str("    ; Return level pointer in RESULT\n");
        out.push_str("    LDX >LEVEL_PTR\n");
        out.push_str("    STX RESULT\n");
        out.push_str("    \n");
        out.push_str("    PULS D,X,Y,U,PC  ; Restore and return\n");
        out.push_str("    \n");
        out.push_str("; === Subroutine: Copy N Objects ===\n");
        out.push_str("; Input: B = count, X = source (ROM), U = destination (RAM)\n");
        out.push_str("; OPTIMIZATION: Skip 'type' field (+0) - read from ROM when needed\n");
        out.push_str("; Each ROM object is 20 bytes, but we copy only 19 bytes to RAM (skip type)\n");
        out.push_str("; Clobbers: A, B, X, U\n");
        out.push_str("LLR_COPY_OBJECTS:\n");
        out.push_str("LLR_COPY_LOOP:\n");
        out.push_str("    TSTB\n");
        out.push_str("    BEQ LLR_COPY_DONE\n");
        out.push_str("    PSHS B           ; Save counter (LDD will clobber B!)\n");
        out.push_str("    \n");
        out.push_str("    ; Skip type (offset +0) and intensity (offset +8) fields in ROM\n");
        out.push_str("    LEAX 1,X         ; X now points to +1 (x position)\n");
        out.push_str("    \n");
        out.push_str("    ; Copy 14 bytes optimized: x,y,scale,spawn_delay as 1-byte values\n");
        out.push_str("    LDA 1,X          ; ROM +2 (x low byte) → RAM +0\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    LDA 3,X          ; ROM +4 (y low byte) → RAM +1\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    LDA 5,X          ; ROM +6 (scale low byte) → RAM +2\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    LDA 6,X          ; ROM +7 (rotation) → RAM +3\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    LEAX 8,X         ; Skip to ROM +9 (past intensity at +8)\n");
        out.push_str("    LDA ,X+          ; ROM +9 (velocity_x) → RAM +4\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    LDA ,X+          ; ROM +10 (velocity_y) → RAM +5\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    LDA ,X+          ; ROM +11 (physics_flags) → RAM +6\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    LDA ,X+          ; ROM +12 (collision_flags) → RAM +7\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    LDA ,X+          ; ROM +13 (collision_size) → RAM +8\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    LDA 1,X          ; ROM +15 (spawn_delay low byte) → RAM +9\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    LEAX 2,X         ; Skip spawn_delay (2 bytes)\n");
        out.push_str("    LDD ,X++         ; ROM +16-17 (vector_ptr) → RAM +10-11\n");
        out.push_str("    STD ,U++\n");
        out.push_str("    LDD ,X++         ; ROM +18-19 (properties_ptr) → RAM +12-13\n");
        out.push_str("    STD ,U++\n");
        out.push_str("    \n");
        out.push_str("    PULS B           ; Restore counter\n");
        out.push_str("    DECB             ; Decrement after copy\n");
        out.push_str("    BRA LLR_COPY_LOOP\n");
        out.push_str("LLR_COPY_DONE:\n");
        out.push_str("    RTS\n");
        out.push_str("\n");
    }
    
    if w.contains("SHOW_LEVEL_RUNTIME") {
        out.push_str("; === SHOW_LEVEL_RUNTIME ===\n");
        out.push_str("; Draw all level objects from loaded level\n");
        out.push_str("; Input: LEVEL_PTR = pointer to level data\n");
        out.push_str("; Level structure (from levelres.rs):\n");
        out.push_str(";   +0:  FDB xMin, xMax (world bounds)\n");
        out.push_str(";   +4:  FDB yMin, yMax\n");
        out.push_str(";   +8:  FDB timeLimit, targetScore\n");
        out.push_str(";   +12: FCB bgCount, gameplayCount, fgCount\n");
        out.push_str(";   +15: FDB bgObjectsPtr, gameplayObjectsPtr, fgObjectsPtr\n");
        out.push_str("; RAM object structure (19 bytes each, 'type' omitted - read from ROM):\n");
        out.push_str(";   +0:  FDB x, y (position)\n");
        out.push_str(";   +4:  FDB scale (8.8 fixed point)\n");
        out.push_str(";   +6:  FCB rotation, intensity\n");
        out.push_str(";   +8:  FCB velocity_x, velocity_y\n");
        out.push_str(";   +10: FCB physics_flags, collision_flags, collision_size\n");
        out.push_str(";   +13: FDB spawn_delay\n");
        out.push_str(";   +15: FDB vector_ptr\n");
        out.push_str(";   +17: FDB properties_ptr\n");
        out.push_str("SHOW_LEVEL_RUNTIME:\n");
        out.push_str("    PSHS D,X,Y,U     ; Preserve registers\n");
        out.push_str("    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access - ONCE at start)\n");
        out.push_str("    \n");
        out.push_str("    ; Get level pointer (persistent)\n");
        out.push_str("    LDX >LEVEL_PTR\n");
        out.push_str("    CMPX #0\n");
        out.push_str("    BEQ SLR_DONE     ; No level loaded\n");
        out.push_str("    \n");
        out.push_str("    ; Skip world bounds (8 bytes) + time/score (4 bytes)\n");
        out.push_str("    LEAX 12,X        ; X now points to object counts\n");
        out.push_str("    \n");
        out.push_str("    ; Read object counts (use LDB+STB to ensure 1-byte operations)\n");
        out.push_str("    LDB ,X+          ; B = bgCount\n");
        out.push_str("    STB >LEVEL_BG_COUNT\n");
        out.push_str("    LDB ,X+          ; B = gameplayCount\n");
        out.push_str("    STB >LEVEL_GP_COUNT\n");
        out.push_str("    LDB ,X+          ; B = fgCount\n");
        out.push_str("    STB >LEVEL_FG_COUNT\n");
        out.push_str("    \n");
        out.push_str("    ; NOTE: Layer pointers already set by LOAD_LEVEL\n");
        out.push_str("    ; - LEVEL_BG_PTR points to ROM (set by LOAD_LEVEL)\n");
        out.push_str("    ; - LEVEL_GP_PTR points to RAM buffer if physics, ROM if static (set by LOAD_LEVEL)\n");
        out.push_str("    ; - LEVEL_FG_PTR points to ROM (set by LOAD_LEVEL)\n");
        out.push_str("    \n");
        out.push_str("    ; === Draw Background Layer (from ROM) ===\n");
        out.push_str("SLR_BG_COUNT:\n");
        out.push_str("    CLRB             ; Clear high byte to prevent corruption\n");
        out.push_str("    LDB >LEVEL_BG_COUNT\n");
        out.push_str("    CMPB #0\n");
        out.push_str("    BEQ SLR_GAMEPLAY\n");
        out.push_str("SLR_BG_PTR:\n");
        out.push_str("    LDA #20          ; ROM objects are 20 bytes (with 'type' field)\n");
        out.push_str("    LDX >LEVEL_BG_ROM_PTR ; Read from ROM directly (no RAM copy)\n");
        out.push_str("    JSR SLR_DRAW_OBJECTS\n");
        out.push_str("    \n");
        out.push_str("    ; === Draw Gameplay Layer (from RAM) ===\n");
        out.push_str("SLR_GAMEPLAY:\n");
        out.push_str("SLR_GP_COUNT:\n");
        out.push_str("    CLRB             ; Clear high byte to prevent corruption\n");
        out.push_str("    LDB >LEVEL_GP_COUNT\n");
        out.push_str("    CMPB #0\n");
        out.push_str("    BEQ SLR_FOREGROUND\n");
        out.push_str("SLR_GP_PTR:\n");
        
        // Stride depends on whether buffer exists (14=RAM, 20=ROM)
        if opts.buffer_requirements.as_ref().map(|r| r.needs_buffer).unwrap_or(false) {
            out.push_str("    LDA #14          ; GP objects in RAM buffer (14 bytes)\n");
        } else {
            out.push_str("    LDA #20          ; GP objects read from ROM (20 bytes)\n");
        }
        
        out.push_str("    LDX >LEVEL_GP_PTR ; Read from pointer (RAM if physics, ROM if static)\n");
        out.push_str("    JSR SLR_DRAW_OBJECTS\n");
        out.push_str("    \n");
        out.push_str("    ; === Draw Foreground Layer (from ROM) ===\n");
        out.push_str("SLR_FOREGROUND:\n");
        out.push_str("SLR_FG_COUNT:\n");
        out.push_str("    CLRB             ; Clear high byte to prevent corruption\n");
        out.push_str("    LDB >LEVEL_FG_COUNT\n");
        out.push_str("    CMPB #0\n");
        out.push_str("    BEQ SLR_DONE\n");
        out.push_str("SLR_FG_PTR:\n");
        out.push_str("    LDA #20          ; ROM objects are 20 bytes (with 'type' field)\n");
        out.push_str("    LDX >LEVEL_FG_ROM_PTR ; Read from ROM directly (no RAM copy)\n");
        out.push_str("    JSR SLR_DRAW_OBJECTS\n");
        out.push_str("    \n");
        out.push_str("SLR_DONE:\n");
        out.push_str("    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access - ONCE at end)\n");
        out.push_str("    PULS D,X,Y,U,PC  ; Restore and return\n");
        out.push_str("    \n");
        out.push_str("; === Subroutine: Draw N Objects ===\n");
        out.push_str("; Input: A = stride (19=RAM, 20=ROM), B = count, X = objects ptr\n");
        out.push_str("SLR_DRAW_OBJECTS:\n");
        out.push_str("    PSHS A           ; Save stride on stack\n");
        out.push_str("    ; NOTE: Use register-based loop (no stack juggling).\n");
        out.push_str("    ; Input: B = count, X = objects ptr. Clobbers B,X,Y,U.\n");
        out.push_str("SLR_OBJ_LOOP:\n");
        out.push_str("    TSTB             ; Test if count is zero\n");
        out.push_str("    LBEQ SLR_OBJ_DONE ; Exit if zero (LONG branch - intensity calc made loop large)\n");
        out.push_str("    \n");
        out.push_str("    PSHS B           ; CRITICAL: Save counter (B gets clobbered by LDD operations)\n");
        out.push_str("    \n");
        out.push_str("    ; X points to current object\n");
        out.push_str("    ; ROM: 20 bytes with 'type' at +0 (offsets: intensity +8, y +3, x +1, vector_ptr +16)\n");
        out.push_str("    ; RAM: 18 bytes without 'type' and 'intensity' (offsets: y +2, x +0, vector_ptr +14)\n");
        out.push_str("    ; NOTE: intensity ALWAYS read from ROM (even for RAM objects)\n");
        out.push_str("    \n");
        out.push_str("    ; Determine object type based on stride (peek from stack)\n");
        out.push_str("    LDA 1,S          ; Load stride from stack (offset +1 because B is at top)\n");
        out.push_str("    CMPA #20\n");
        out.push_str("    BEQ SLR_ROM_OFFSETS\n");
        out.push_str("    \n");
        out.push_str("    ; RAM offsets (18 bytes, no 'type' or 'intensity')\n");
        out.push_str("    ; Need to calculate ROM address for intensity: ROM_PTR + (objIndex * 20) + 8\n");
        out.push_str("    ; objIndex = (X - LEVEL_GP_BUFFER) / 18\n");
        out.push_str("    PSHS X           ; Save RAM object pointer\n");
        out.push_str("    LDB >LEVEL_GP_COUNT\n");
        out.push_str("    SUBB 2,S         ; objIndex = totalCount - currentCounter\n");
        out.push_str("    ; Multiply objIndex by 20 using loop (B * 20)\n");
        out.push_str("    PSHS B           ; Save objIndex for loop counter\n");
        out.push_str("    LDD >LEVEL_GP_ROM_PTR ; D = ROM base\n");
        out.push_str("SLR_RAM_INTENSITY_LOOP:\n");
        out.push_str("    LDB ,S           ; Load counter\n");
        out.push_str("    BEQ SLR_RAM_INTENSITY_DONE  ; Exit if 0\n");
        out.push_str("    ADDD #20         ; D += 20\n");
        out.push_str("    DEC ,S           ; Decrement counter on stack\n");
        out.push_str("    LBRA SLR_RAM_INTENSITY_LOOP\n");
        out.push_str("SLR_RAM_INTENSITY_DONE:\n");
        out.push_str("    LEAS 1,S         ; Clean objIndex from stack\n");
        out.push_str("    TFR D,Y          ; Y = ROM object address\n");
        out.push_str("    LDA 8,Y          ; intensity at ROM +8\n");
        out.push_str("    STA DRAW_VEC_INTENSITY\n");
        out.push_str("    PULS X           ; Restore RAM object pointer\n");
        out.push_str("    \n");
        out.push_str("    CLR MIRROR_X\n");
        out.push_str("    CLR MIRROR_Y\n");
        out.push_str("    LDB 1,X          ; y at +1 (1 byte)\n");
        out.push_str("    STB DRAW_VEC_Y\n");
        out.push_str("    LDB 0,X          ; x at +0 (1 byte)\n");
        out.push_str("    STB DRAW_VEC_X\n");
        out.push_str("    LDU 10,X         ; vector_ptr at +10\n");
        out.push_str("    BRA SLR_DRAW_VECTOR\n");
        out.push_str("    \n");
        out.push_str("SLR_ROM_OFFSETS:\n");
        out.push_str("    ; ROM offsets (20 bytes, with 'type' at +0)\n");
        out.push_str("    CLR MIRROR_X\n");
        out.push_str("    CLR MIRROR_Y\n");
        out.push_str("    LDA 8,X          ; intensity at +8\n");
        out.push_str("    STA DRAW_VEC_INTENSITY\n");
        out.push_str("    LDD 3,X          ; y at +3\n");
        out.push_str("    STB DRAW_VEC_Y\n");
        out.push_str("    LDD 1,X          ; x at +1\n");
        out.push_str("    STB DRAW_VEC_X\n");
        out.push_str("    LDU 16,X         ; vector_ptr at +16\n");
        out.push_str("    \n");
        out.push_str("SLR_DRAW_VECTOR:\n");
        out.push_str("    PSHS X           ; Save object pointer on stack (Y may be corrupted by Draw_Sync_List)\n");
        out.push_str("    TFR U,X          ; X = vector data pointer (points to header)\n");
        out.push_str("    \n");
        out.push_str("    ; Read path_count from header (byte 0)\n");
        out.push_str("    LDB ,X+          ; B = path_count, X now points to pointer table\n");
        out.push_str("    \n");
        out.push_str("    ; Draw all paths using pointer table (DP already set to $D0 by SHOW_LEVEL_RUNTIME)\n");
        out.push_str("SLR_PATH_LOOP:\n");
        out.push_str("    TSTB             ; Check if count is zero\n");
        out.push_str("    BEQ SLR_PATH_DONE ; Exit if no paths left\n");
        out.push_str("    DECB             ; Decrement count\n");
        out.push_str("    PSHS B           ; Save decremented count\n");
        out.push_str("    \n");
        out.push_str("    ; Read next path pointer from table (X points to current FDB entry)\n");
        out.push_str("    LDU ,X++         ; U = path pointer, X advances to next entry\n");
        out.push_str("    PSHS X           ; Save pointer table position\n");
        out.push_str("    TFR U,X          ; X = actual path data\n");
        out.push_str("    JSR Draw_Sync_List_At_With_Mirrors  ; Draw this path\n");
        out.push_str("    PULS X           ; Restore pointer table position\n");
        out.push_str("    PULS B           ; Restore counter for next iteration\n");
        out.push_str("    BRA SLR_PATH_LOOP\n");
        out.push_str("    \n");
        out.push_str("SLR_PATH_DONE:\n");
        out.push_str("    PULS X           ; Restore object pointer from stack\n");
        out.push_str("    \n");
        out.push_str("    ; Advance to next object using stride from stack\n");
        out.push_str("    LDA 1,S          ; Load stride from stack (offset +1 because B is at top)\n");
        out.push_str("    LEAX A,X         ; X += stride (18 or 20 bytes)\n");
        out.push_str("    \n");
        out.push_str("    PULS B           ; Restore counter\n");
        out.push_str("    DECB             ; Decrement count AFTER drawing\n");
        out.push_str("    LBRA SLR_OBJ_LOOP  ; LONG branch - intensity calc made loop large\n");
        out.push_str("    \n");
        out.push_str("SLR_OBJ_DONE:\n");
        out.push_str("    PULS A           ; Clean up stride from stack\n");
        out.push_str("    RTS\n");
        out.push_str("\n");
    }
    
    // UPDATE_LEVEL_RUNTIME - Placeholder for level state updates
    if w.contains("UPDATE_LEVEL_RUNTIME") {
        out.push_str("; === UPDATE_LEVEL_RUNTIME ===\n");
        out.push_str("; Update level state (physics, velocity, spawn delays)\n");
        out.push_str("; OPTIMIZATION: Only updates GP layer (BG/FG are static, read from ROM)\n");
        out.push_str("; CRITICAL: Works on RAM BUFFERS, not ROM!\n");
        out.push_str(";\n");
        out.push_str("UPDATE_LEVEL_RUNTIME:\n");
        out.push_str("    PSHS U,X,Y,D  ; Preserve all registers\n");
        out.push_str("    \n");
        out.push_str("    ; === Skip Background (static, no updates) ===\n");
        out.push_str("    ; BG objects are read directly from ROM - no physics processing needed\n");
        out.push_str("    \n");
        out.push_str("    ; === Update Gameplay Objects ONLY ===\n");
        out.push_str("    LDB LEVEL_GP_COUNT\n");
        out.push_str("    CMPB #0\n");
        out.push_str("    LBEQ ULR_EXIT  ; Long branch (no objects to update)\n");
        out.push_str("    LDU LEVEL_GP_PTR  ; U = GP pointer (RAM if physics, ROM if static)\n");
        out.push_str("    BSR ULR_UPDATE_LAYER  ; Process objects\n");
        out.push_str("    \n");
        
        // Only emit collision detection if physics buffer exists
        if opts.buffer_requirements.as_ref().map(|r| r.needs_buffer).unwrap_or(false) {
            out.push_str("    ; === Object-to-Object Collisions (GAMEPLAY only) ===\n");
            out.push_str("    JSR ULR_GAMEPLAY_COLLISIONS  ; Use JSR for long distance\n");
        }
        out.push_str("    \n");
        out.push_str("    ; === Skip Foreground (static, no updates) ===\n");
        out.push_str("    ; FG objects are read directly from ROM - no physics processing needed\n");
        out.push_str("    \n");
        out.push_str("ULR_EXIT:\n");
        out.push_str("    PULS D,Y,X,U  ; Restore registers\n");
        out.push_str("    RTS\n");
        out.push_str("\n");
        out.push_str("; === ULR_UPDATE_LAYER - Process all objects in a layer ===\n");
        out.push_str("; Input: B = object count, U = buffer base address\n");
        out.push_str("; Uses: X for world bounds\n");
        out.push_str("ULR_UPDATE_LAYER:\n");
        out.push_str("    LDX >LEVEL_PTR  ; Load level pointer for world bounds\n");
        out.push_str("    CMPX #0\n");
        out.push_str("    LBEQ ULR_LAYER_EXIT  ; No level loaded (long branch)\n");
        out.push_str("    \n");
        out.push_str("ULR_LOOP:\n");
        out.push_str("    ; U = pointer to object data (19 bytes per object in RAM)\n");
        out.push_str("    ; RAM object structure (type omitted - read from ROM if needed):\n");
        out.push_str("    ; +0: x (2 bytes signed)\n");
        out.push_str("    ; +2: y (2 bytes signed)\n");
        out.push_str("    ; +4: scale (2 bytes - not used by physics)\n");
        out.push_str("    ; +6: rotation (1 byte - not used by physics)\n");
        out.push_str("    ; +7: intensity (1 byte - not used by physics)\n");
        out.push_str("    ; +8: velocity_x (1 byte signed)\n");
        out.push_str("    ; +9: velocity_y (1 byte signed)\n");
        out.push_str("    ; +10: physics_flags (1 byte)\n");
        out.push_str("    ; +11: collision_flags (1 byte)\n");
        out.push_str("    ; +12-18: other fields (collision_size, spawn_delay, vector_ptr, properties_ptr)\n");
        out.push_str("\n");
        out.push_str("    ; Check physics_flags (offset +9)\n");
        out.push_str("    PSHS B  ; Save loop counter\n");
        out.push_str("    LDB 6,U      ; Read flags\n");
        out.push_str("    CMPB #0\n");
        out.push_str("    LBEQ ULR_NEXT  ; Skip if no physics enabled (long branch)\n");
        out.push_str("\n");
        out.push_str("    ; Check if dynamic physics enabled (bit 0)\n");
        out.push_str("    BITB #$01\n");
        out.push_str("    LBEQ ULR_NEXT  ; Skip if not dynamic (long branch)\n");
        out.push_str("\n");
        out.push_str("    ; Check if gravity enabled (bit 1)\n");
        out.push_str("    BITB #$02\n");
        out.push_str("    LBEQ ULR_NO_GRAVITY  ; Long branch\n");
        out.push_str("\n");
        out.push_str("    ; Apply gravity: velocity_y -= 1\n");
        out.push_str("    LDB 8,U       ; Read velocity_y\n");
        out.push_str("    DECB          ; Subtract gravity\n");
        out.push_str("    ; Clamp to -15..+15 (max velocity)\n");
        out.push_str("    CMPB #$F1     ; Compare with -15\n");
        out.push_str("    BGE ULR_VY_OK\n");
        out.push_str("    LDB #$F1      ; Clamp to -15\n");
        out.push_str("ULR_VY_OK:\n");
        out.push_str("    STB 5,U       ; Store updated velocity_y\n");
        out.push_str("\n");
        out.push_str("ULR_NO_GRAVITY:\n");
        out.push_str("    ; Apply velocity to position (8-bit arithmetic)\n");
        out.push_str("    ; x += velocity_x\n");
        out.push_str("    LDA 0,U       ; Load x (8-bit at offset +0)\n");
        out.push_str("    LDB 4,U       ; Load velocity_x (signed 8-bit)\n");
        out.push_str("    PSHS A        ; Save original x\n");
        out.push_str("    ADDA 4,U      ; A = x + velocity_x\n");
        out.push_str("    STA 0,U       ; Store new x\n");
        out.push_str("    PULS A        ; Clean stack\n");
        out.push_str("\n");
        out.push_str("    ; y += velocity_y\n");
        out.push_str("    LDA 1,U       ; Load y (8-bit at offset +1)\n");
        out.push_str("    ADDA 5,U      ; A = y + velocity_y\n");
        out.push_str("    STA 1,U       ; Store new y\n");
        out.push_str("\n");
        out.push_str("    ; === Check World Bounds (Wall Collisions) ===\n");
        out.push_str("    LDB 7,U      ; Load collision_flags\n");
        out.push_str("    BITB #$02     ; Check bounce_walls flag (bit 1)\n");
        out.push_str("    LBEQ ULR_NEXT  ; Skip bounce if not enabled (long branch)\n");
        out.push_str("\n");
        out.push_str("    ; Load world bounds pointer from LEVEL_PTR\n");
        out.push_str("    LDX >LEVEL_PTR\n");
        out.push_str("    ; LEVEL_PTR → +0: xMin, +2: xMax, +4: yMin, +6: yMax (direct values)\n");
        out.push_str("\n");
        out.push_str("    ; === Check X Bounds (Left/Right walls) ===\n");
        out.push_str("    ; Check xMin: if (x - collision_size) < xMin then bounce\n");
        out.push_str("    LDB 8,U      ; collision_size (offset +8)\n");
        out.push_str("    SEX           ; Sign-extend to 16-bit in D\n");
        out.push_str("    PSHS D        ; Save collision_size on stack\n");
        out.push_str("    LDB 0,U       ; Load object x (8-bit at offset +0)\n");
        out.push_str("    SEX           ; Sign-extend x to 16-bit\n");
        out.push_str("    SUBD ,S++     ; D = x - collision_size (left edge), pop stack\n");
        out.push_str("    CMPD 0,X      ; Compare left edge with xMin\n");
        out.push_str("    LBGE ULR_X_MAX_CHECK  ; Skip if left_edge >= xMin (LONG)\n");
        out.push_str("    ; Hit xMin wall - only bounce if moving left (velocity_x < 0)\n");
        out.push_str("    LDB 4,U       ; velocity_x (offset +4)\n");
        out.push_str("    CMPB #0\n");
        out.push_str("    LBGE ULR_X_MAX_CHECK  ; Skip if moving right (LONG)\n");
        out.push_str("    ; Bounce: set position so left edge = xMin\n");
        out.push_str("    LDB 8,U      ; Reload collision_size\n");
        out.push_str("    SEX\n");
        out.push_str("    ADDD 0,X      ; D = xMin + collision_size (center position)\n");
        out.push_str("    STB 0,U       ; x = (xMin + collision_size) low byte (8-bit store)\n");
        out.push_str("    LDB 4,U       ; Reload velocity_x\n");
        out.push_str("    NEGB          ; velocity_x = -velocity_x\n");
        out.push_str("    STB 4,U\n");
        out.push_str("\n");
        out.push_str("    ; Check xMax: if (x + collision_size) > xMax then bounce\n");
        out.push_str("ULR_X_MAX_CHECK:\n");
        out.push_str("    LDB 8,U      ; Reload collision_size\n");
        out.push_str("    SEX\n");
        out.push_str("    PSHS D        ; Save collision_size on stack\n");
        out.push_str("    LDB 0,U       ; Load object x (8-bit at offset +0)\n");
        out.push_str("    SEX           ; Sign-extend x to 16-bit\n");
        out.push_str("    ADDD ,S++     ; D = x + collision_size (right edge), pop stack\n");
        out.push_str("    CMPD 2,X      ; Compare right edge with xMax\n");
        out.push_str("    LBLE ULR_Y_BOUNDS  ; Skip if right_edge <= xMax (LONG)\n");
        out.push_str("    ; Hit xMax wall - only bounce if moving right (velocity_x > 0)\n");
        out.push_str("    LDB 4,U       ; velocity_x (offset +4)\n");
        out.push_str("    CMPB #0\n");
        out.push_str("    LBLE ULR_Y_BOUNDS  ; Skip if moving left (LONG)\n");
        out.push_str("    ; Bounce: set position so right edge = xMax\n");
        out.push_str("    LDB 8,U      ; Reload collision_size\n");
        out.push_str("    SEX\n");
        out.push_str("    TFR D,Y       ; Y = collision_size\n");
        out.push_str("    LDD 2,X       ; D = xMax\n");
        out.push_str("    PSHS Y        ; Push collision_size\n");
        out.push_str("    SUBD ,S++     ; D = xMax - collision_size (center position), pop\n");
        out.push_str("    STB 0,U       ; x = (xMax - collision_size) low byte (8-bit store)\n");
        out.push_str("    LDB 4,U       ; Reload velocity_x\n");
        out.push_str("    NEGB          ; velocity_x = -velocity_x\n");
        out.push_str("    STB 4,U\n");
        out.push_str("\n");
        out.push_str("    ; === Check Y Bounds (Top/Bottom walls) ===\n");
        out.push_str("ULR_Y_BOUNDS:\n");
        out.push_str("    ; Check yMin: if (y - collision_size) < yMin then bounce\n");
        out.push_str("    LDB 8,U      ; Reload collision_size\n");
        out.push_str("    SEX\n");
        out.push_str("    PSHS D        ; Save collision_size on stack\n");
        out.push_str("    LDB 1,U       ; Load object y (8-bit at offset +1)\n");
        out.push_str("    SEX           ; Sign-extend y to 16-bit\n");
        out.push_str("    SUBD ,S++     ; D = y - collision_size (bottom edge), pop stack\n");
        out.push_str("    CMPD 4,X      ; Compare bottom edge with yMin\n");
        out.push_str("    LBGE ULR_Y_MAX_CHECK  ; Skip if bottom_edge >= yMin (LONG)\n");
        out.push_str("    ; Hit yMin wall - only bounce if moving down (velocity_y < 0)\n");
        out.push_str("    LDB 5,U       ; velocity_y (offset +5)\n");
        out.push_str("    CMPB #0\n");
        out.push_str("    LBGE ULR_Y_MAX_CHECK  ; Skip if moving up (LONG)\n");
        out.push_str("    ; Bounce: set position so bottom edge = yMin\n");
        out.push_str("    LDB 8,U      ; Reload collision_size\n");
        out.push_str("    SEX\n");
        out.push_str("    ADDD 4,X      ; D = yMin + collision_size (center position)\n");
        out.push_str("    STB 1,U       ; y = (yMin + collision_size) low byte (8-bit store)\n");
        out.push_str("    LDB 5,U       ; Reload velocity_y\n");
        out.push_str("    NEGB          ; velocity_y = -velocity_y\n");
        out.push_str("    STB 5,U\n");
        out.push_str("\n");
        out.push_str("    ; Check yMax: if (y + collision_size) > yMax then bounce\n");
        out.push_str("ULR_Y_MAX_CHECK:\n");
        out.push_str("    LDB 8,U      ; Reload collision_size\n");
        out.push_str("    SEX\n");
        out.push_str("    PSHS D        ; Save collision_size on stack\n");
        out.push_str("    LDB 1,U       ; Load object y (8-bit at offset +1)\n");
        out.push_str("    SEX           ; Sign-extend y to 16-bit\n");
        out.push_str("    ADDD ,S++     ; D = y + collision_size (top edge), pop stack\n");
        out.push_str("    CMPD 6,X      ; Compare top edge with yMax\n");
        out.push_str("    LBLE ULR_NEXT  ; Skip if top_edge <= yMax (LONG)\n");
        out.push_str("    ; Hit yMax wall - only bounce if moving up (velocity_y > 0)\n");
        out.push_str("    LDB 5,U       ; velocity_y (offset +5)\n");
        out.push_str("    CMPB #0\n");
        out.push_str("    LBLE ULR_NEXT  ; Skip if moving down (LONG)\n");
        out.push_str("    ; Bounce: set position so top edge = yMax\n");
        out.push_str("    LDB 8,U      ; Reload collision_size\n");
        out.push_str("    SEX\n");
        out.push_str("    TFR D,Y       ; Y = collision_size\n");
        out.push_str("    LDD 6,X       ; D = yMax\n");
        out.push_str("    PSHS Y        ; Push collision_size\n");
        out.push_str("    SUBD ,S++     ; D = yMax - collision_size (center position), pop\n");
        out.push_str("    STB 1,U       ; y = (yMax - collision_size) low byte (8-bit store)\n");
        out.push_str("    LDB 5,U       ; Reload velocity_y\n");
        out.push_str("    NEGB          ; velocity_y = -velocity_y\n");
        out.push_str("    STB 5,U\n");
        out.push_str("\n");
        out.push_str("ULR_NEXT:\n");
        out.push_str("    PULS B        ; Restore loop counter\n");
        out.push_str("    LEAU 14,U     ; Move to next object (14 bytes)\n");
        out.push_str("    DECB\n");
        out.push_str("    LBNE ULR_LOOP  ; Continue if more objects (long branch)\n");
        out.push_str("\n");
        out.push_str("ULR_LAYER_EXIT:\n");
        out.push_str("    RTS\n");
        out.push_str("\n");
        
        // Only emit collision detection function if physics buffer exists
        if opts.buffer_requirements.as_ref().map(|r| r.needs_buffer).unwrap_or(false) {
            out.push_str("; === ULR_GAMEPLAY_COLLISIONS - Check collisions between gameplay objects ===\n");
        out.push_str("; Input: None (uses LEVEL_GP_BUFFER and LEVEL_GP_COUNT)\n");
        out.push_str("ULR_GAMEPLAY_COLLISIONS:\n");
        out.push_str("    ; Ultra-simple algorithm: NO stack juggling, use RAM variables\n");
        out.push_str("    LDA LEVEL_GP_COUNT\n");
        out.push_str("    CMPA #2\n");
        out.push_str("    BHS UGPC_START   ; Continue if >=2\n");
        out.push_str("    RTS              ; Early exit\n");
        out.push_str("UGPC_START:\n");
        out.push_str("    \n");
        out.push_str("    ; Store count-1 in temporary RAM (we'll iterate up to this)\n");
        out.push_str("    DECA\n");
        out.push_str("    STA UGPC_OUTER_MAX   ; Store at RESULT+20 (temp storage)\n");
        out.push_str("    CLR UGPC_OUTER_IDX   ; Start at 0\n");
        out.push_str("    \n");
        out.push_str("UGPC_OUTER_LOOP:\n");
        out.push_str("    ; Calculate U = LEVEL_GP_BUFFER + (UGPC_OUTER_IDX * 14)\n");
        out.push_str("    LDU #LEVEL_GP_BUFFER\n");
        out.push_str("    LDB UGPC_OUTER_IDX\n");
        out.push_str("    BEQ UGPC_SKIP_OUTER_MUL  ; If idx=0, U already correct\n");
        out.push_str("UGPC_OUTER_MUL:\n");
        out.push_str("    LEAU 14,U\n");
        out.push_str("    DECB\n");
        out.push_str("    BNE UGPC_OUTER_MUL\n");
        out.push_str("UGPC_SKIP_OUTER_MUL:\n");
        out.push_str("    \n");
        out.push_str("    ; Check if collidable\n");
        out.push_str("    LDB 10,U\n");
        out.push_str("    BITB #$01\n");
        out.push_str("    LBEQ UGPC_NEXT_OUTER\n");
        out.push_str("    \n");
        out.push_str("    ; Inner loop: check against all objects AFTER current\n");
        out.push_str("    LDA UGPC_OUTER_IDX\n");
        out.push_str("    INCA             ; Start from next object\n");
        out.push_str("    STA UGPC_INNER_IDX\n");
        out.push_str("    \n");
        out.push_str("UGPC_INNER_LOOP:\n");
        out.push_str("    ; Check if inner reached count\n");
        out.push_str("    LDA UGPC_INNER_IDX\n");
        out.push_str("    CMPA LEVEL_GP_COUNT\n");
        out.push_str("    LBHS UGPC_INNER_DONE  ; Done if idx >= count (LONG)\n");
        out.push_str("    \n");
        out.push_str("    ; Calculate Y = LEVEL_GP_BUFFER + (UGPC_INNER_IDX * 14)\n");
        out.push_str("    LDY #LEVEL_GP_BUFFER\n");
        out.push_str("    LDB UGPC_INNER_IDX\n");
        out.push_str("    BEQ UGPC_SKIP_INNER_MUL\n");
        out.push_str("UGPC_INNER_MUL:\n");
        out.push_str("    LEAY 14,Y\n");
        out.push_str("    DECB\n");
        out.push_str("    BNE UGPC_INNER_MUL\n");
        out.push_str("UGPC_SKIP_INNER_MUL:\n");
        out.push_str("    \n");
        out.push_str("    ; Check if Y collidable\n");
        out.push_str("    LDB 7,Y\n");
        out.push_str("    BITB #$01\n");
        out.push_str("    LBEQ UGPC_NEXT_INNER\n");
        out.push_str("    \n");
        out.push_str("    ; Manhattan distance |x1-x2| + |y1-y2|\n");
        out.push_str("    LDB 0,U          ; x1 (8-bit at offset +0)\n");
        out.push_str("    SEX              ; Sign-extend to 16-bit\n");
        out.push_str("    PSHS D           ; Save x1\n");
        out.push_str("    LDB 0,Y          ; x2 (8-bit at offset +0)\n");
        out.push_str("    SEX              ; Sign-extend to 16-bit\n");
        out.push_str("    TFR D,X          ; X = x2\n");
        out.push_str("    PULS D           ; D = x1\n");
        out.push_str("    PSHS X           ; Save X register\n");
        out.push_str("    TFR X,D          ; D = x2\n");
        out.push_str("    PULS X           ; Restore X\n");
        out.push_str("    PSHS D           ; Push x2\n");
        out.push_str("    LDB 0,U          ; Reload x1\n");
        out.push_str("    SEX\n");
        out.push_str("    SUBD ,S++        ; x1-x2\n");
        out.push_str("    BPL UGPC_DX_POS\n");
        out.push_str("    COMA\n");
        out.push_str("    COMB\n");
        out.push_str("    ADDD #1\n");
        out.push_str("UGPC_DX_POS:\n");
        out.push_str("    STD UGPC_DX      ; Store |dx| in temp\n");
        out.push_str("    \n");
        out.push_str("    LDB 1,U          ; y1 (8-bit at offset +1)\n");
        out.push_str("    SEX              ; Sign-extend to 16-bit\n");
        out.push_str("    PSHS D           ; Save y1\n");
        out.push_str("    LDB 1,Y          ; y2 (8-bit at offset +1)\n");
        out.push_str("    SEX              ; Sign-extend to 16-bit\n");
        out.push_str("    TFR D,X          ; X = y2 (temp)\n");
        out.push_str("    PULS D           ; D = y1\n");
        out.push_str("    PSHS X           ; Save X\n");
        out.push_str("    TFR X,D          ; D = y2\n");
        out.push_str("    PULS X           ; Restore X\n");
        out.push_str("    PSHS D           ; Push y2\n");
        out.push_str("    LDB 1,U          ; Reload y1\n");
        out.push_str("    SEX\n");
        out.push_str("    SUBD ,S++        ; y1-y2\n");
        out.push_str("    BPL UGPC_DY_POS\n");
        out.push_str("    COMA\n");
        out.push_str("    COMB\n");
        out.push_str("    ADDD #1\n");
        out.push_str("UGPC_DY_POS:\n");
        out.push_str("    ADDD UGPC_DX     ; distance = |dx| + |dy|\n");
        out.push_str("    STD UGPC_DIST\n");
        out.push_str("    \n");
        out.push_str("    ; Sum of radii\n");
        out.push_str("    LDB 8,U\n");
        out.push_str("    ADDB 8,Y\n");
        out.push_str("    SEX              ; D = sum_radius (normal, not doubled)\n");
        out.push_str("    ; Collision if distance < sum_radius (i.e., sum_radius > distance)\n");
        out.push_str("    CMPD UGPC_DIST   ; Compare sum_radius with distance\n");
        out.push_str("    LBHI UGPC_COLLISION  ; Jump to collision if sum_radius > distance (LONG)\n");
        out.push_str("    LBRA UGPC_NEXT_INNER ; No collision, skip (LONG)\n");
        out.push_str("    \n");
        out.push_str("UGPC_COLLISION:\n");
        out.push_str("    ; COLLISION! Swap velocities (elastic collision)\n");
        out.push_str("    ; Swap velocity_x (offset +4)\n");
        out.push_str("    LDA 4,U          ; A = vel_x of object 1\n");
        out.push_str("    LDB 4,Y          ; B = vel_x of object 2\n");
        out.push_str("    STB 4,U          ; Object 1 gets object 2's vel_x\n");
        out.push_str("    STA 4,Y          ; Object 2 gets object 1's vel_x\n");
        out.push_str("    ; Swap velocity_y (offset +5)\n");
        out.push_str("    LDA 5,U          ; A = vel_y of object 1\n");
        out.push_str("    LDB 5,Y          ; B = vel_y of object 2\n");
        out.push_str("    STB 5,U          ; Object 1 gets object 2's vel_y\n");
        out.push_str("    STA 5,Y          ; Object 2 gets object 1's vel_y\n");
        out.push_str("    \n");
        out.push_str("UGPC_NEXT_INNER:\n");
        out.push_str("    INC UGPC_INNER_IDX\n");
        out.push_str("    LBRA UGPC_INNER_LOOP\n");
        out.push_str("    \n");
        out.push_str("UGPC_INNER_DONE:\n");
        out.push_str("UGPC_NEXT_OUTER:\n");
        out.push_str("    INC UGPC_OUTER_IDX\n");
        out.push_str("    LDA UGPC_OUTER_IDX\n");
        out.push_str("    CMPA UGPC_OUTER_MAX\n");
        out.push_str("    LBHI UGPC_EXIT    ; Exit if idx > max (LONG)\n");
        out.push_str("    LBRA UGPC_OUTER_LOOP  ; Continue (LONG)\n");
        out.push_str("    \n");
        out.push_str("UGPC_EXIT:\n");
        out.push_str("    RTS\n");
        out.push_str("    \n");
        } // End conditional ULR_GAMEPLAY_COLLISIONS
    }
}

// power_of_two_const: return shift count if expression is a numeric power-of-two (>1).

// format_expr_ref: helper for peephole comparisons.
// In the Vectrex context, all variables need DATA section definitions regardless of scope
