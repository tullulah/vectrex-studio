; --- Motorola 6809 backend (Vectrex) title='FADE' origin=$0000 ---
        ORG $0000
;***************************************************************************
; DEFINE SECTION
;***************************************************************************
    INCLUDE "VECTREX.I"

;***************************************************************************
; HEADER SECTION
;***************************************************************************
    FCC "g GCE 1982"
    FCB $80
    FDB music1
    FCB $F8
    FCB $50
    FCB $20
    FCB $BB
    FCC "FADE"
    FCB $80
    FCB 0

;***************************************************************************
; CODE SECTION
;***************************************************************************

; === RAM VARIABLE DEFINITIONS (EQU) ===
; AUTO-GENERATED - All offsets calculated automatically
; Total RAM used: 63 bytes
RESULT               EQU $C880+$00   ; Main result temporary (2 bytes)
TMPLEFT              EQU $C880+$02   ; Left operand temp (2 bytes)
TMPLEFT2             EQU $C880+$04   ; Left operand temp 2 (for nested operations) (2 bytes)
TMPRIGHT             EQU $C880+$06   ; Right operand temp (2 bytes)
TMPRIGHT2            EQU $C880+$08   ; Right operand temp 2 (for nested operations) (2 bytes)
TMPPTR               EQU $C880+$0A   ; Pointer temp (used by DRAW_VECTOR, arrays, structs) (2 bytes)
TMPPTR2              EQU $C880+$0C   ; Pointer temp 2 (for nested array operations) (2 bytes)
TEMP_YX              EQU $C880+$0E   ; Temporary y,x storage (2 bytes)
TEMP_X               EQU $C880+$10   ; Temporary x storage (1 bytes)
TEMP_Y               EQU $C880+$11   ; Temporary y storage (1 bytes)
VPY_MOVE_X           EQU $C880+$12   ; MOVE() current X offset (signed byte, 0 by default) (1 bytes)
VPY_MOVE_Y           EQU $C880+$13   ; MOVE() current Y offset (signed byte, 0 by default) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$14   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity as i16x5) (10 bytes)
NUM_STR              EQU $C880+$1E   ; String buffer for PRINT_NUMBER (5 digits + terminator) (6 bytes)
VLINE_DX_16          EQU $C880+$24   ; x1-x0 (16-bit) for line drawing (2 bytes)
VLINE_DY_16          EQU $C880+$26   ; y1-y0 (16-bit) for line drawing (2 bytes)
VLINE_DX             EQU $C880+$28   ; Clamped dx (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$29   ; Clamped dy (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$2A   ; Remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$2C   ; Remaining dx for segment 2 (16-bit) (2 bytes)
VLINE_STEPS          EQU $C880+$2E   ; Line drawing step counter (1 bytes)
VLINE_LIST           EQU $C880+$2F   ; 2-byte vector list (Y|endbit, X) (2 bytes)
VAR_BRIGHTNESS       EQU $C880+$31   ; User variable (2 bytes)
VAR_ARG0             EQU $C880+$33   ; Function argument 0 (2 bytes)
VAR_ARG1             EQU $C880+$35   ; Function argument 1 (2 bytes)
VAR_ARG2             EQU $C880+$37   ; Function argument 2 (2 bytes)
VAR_ARG3             EQU $C880+$39   ; Function argument 3 (2 bytes)
VAR_ARG4             EQU $C880+$3B   ; Function argument 4 (2 bytes)
VAR_ARG5             EQU $C880+$3D   ; Function argument 5 (2 bytes)

    JMP START

;**** CONST DECLARATIONS (NUMBER-ONLY) ****

; === JOYSTICK BUILTIN SUBROUTINES ===
; J1_X() - Read Joystick 1 X axis (INCREMENTAL - with state preservation)
; Returns: D = raw value from $C81B after Joy_Analog call
J1X_BUILTIN:
    PSHS X       ; Save X (Joy_Analog uses it)
    JSR $F1AA    ; DP_to_D0 (required for Joy_Analog BIOS call)
    JSR $F1F5    ; Joy_Analog (updates $C81B from hardware)
    JSR Reset0Ref ; Full beam reset: zeros DAC (VIA_port_a=0) via Reset_Pen + grounds integrators
    JSR $F1AF    ; DP_to_C8 (required to read RAM $C81B)
    LDB $C81B    ; Vec_Joy_1_X (BIOS writes ~$FE at center)
    SEX          ; Sign-extend B to D
    ADDD #2      ; Calibrate center offset
    PULS X       ; Restore X
    RTS

; J1_Y() - Read Joystick 1 Y axis (INCREMENTAL - with state preservation)
; Returns: D = raw value from $C81C after Joy_Analog call
J1Y_BUILTIN:
    PSHS X       ; Save X (Joy_Analog uses it)
    JSR $F1AA    ; DP_to_D0 (required for Joy_Analog BIOS call)
    JSR $F1F5    ; Joy_Analog (updates $C81C from hardware)
    JSR Reset0Ref ; Full beam reset: zeros DAC (VIA_port_a=0) via Reset_Pen + grounds integrators
    JSR $F1AF    ; DP_to_C8 (required to read RAM $C81C)
    LDB $C81C    ; Vec_Joy_1_Y (BIOS writes ~$FE at center)
    SEX          ; Sign-extend B to D
    ADDD #2      ; Calibrate center offset
    PULS X       ; Restore X
    RTS

; === BUTTON SYSTEM - BIOS TRANSITIONS ===
; J1_BUTTON_1-4() - Read transition bits from $C811
; Read_Btns (auto-injected) calculates: ~(new) OR Vec_Prev_Btns
; Result: bit=1 ONLY on rising edge (0→1 transition)
; Returns: D = 1 (just pressed), 0 (not pressed or still held)

J1B1_BUILTIN:
    LDA $C811      ; Read transition bits (Vec_Button_1_1)
    ANDA #$01      ; Test bit 0 (Button 1)
    BEQ .J1B1_OFF
    LDD #1         ; Return pressed (rising edge)
    RTS
.J1B1_OFF:
    LDD #0         ; Return not pressed
    RTS

J1B2_BUILTIN:
    LDA $C811
    ANDA #$02      ; Test bit 1 (Button 2)
    BEQ .J1B2_OFF
    LDD #1
    RTS
.J1B2_OFF:
    LDD #0
    RTS

J1B3_BUILTIN:
    LDA $C811
    ANDA #$04      ; Test bit 2 (Button 3)
    BEQ .J1B3_OFF
    LDD #1
    RTS
.J1B3_OFF:
    LDD #0
    RTS

J1B4_BUILTIN:
    LDA $C811
    ANDA #$08      ; Test bit 3 (Button 4)
    BEQ .J1B4_OFF
    LDD #1
    RTS
.J1B4_OFF:
    LDD #0
    RTS

VECTREX_PRINT_TEXT:
    ; Print_Str_d requires DP=$D0 and signature is (Y, X, string)
    ; VPy signature: PRINT_TEXT(x, y, string) -> args (ARG0=x, ARG1=y, ARG2=string)
    ; BIOS signature: Print_Str_d(A=Y, B=X, U=string)
    LDA #$D0
    TFR A,DP       ; Set Direct Page to $D0 for BIOS
    JSR Intensity_5F ; Ensure consistent text brightness (DP=$D0 required)
    JSR Reset0Ref  ; Reset beam to center for absolute text positioning
    LDU VAR_ARG2   ; string pointer (ARG2 = third param)
    LDA VAR_ARG1+1 ; Y (ARG1 = second param)
    LDB VAR_ARG0+1 ; X (ARG0 = first param)
    JSR Print_Str_d
    LDA #$80
    STA $D004      ; Restore VIA_t1_cnt_lo=$80 (Moveto_d_7F sets it to $7F)
    JSR $F1AF      ; DP_to_C8 (restore before return)
    RTS
; DRAW_LINE unified wrapper - handles 16-bit signed coordinates
; Args in DRAW_LINE_ARGS[0..9]: x0,y0,x1,y1,intensity (5x i16, low byte used for coords)
; Resets beam to center, moves to (x0,y0), draws to (x1,y1)
DRAW_LINE_WRAPPER:
    ; Set DP to hardware registers
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref   ; Reset beam to center (0,0) before positioning
    LDA #$80
    STA <$04        ; VIA_t1_cnt_lo = $80 (ensure correct scale regardless of prior builtins)
    ; Set intensity
    LDA >DRAW_LINE_ARGS+9  ; intensity (low byte)
    JSR Intensity_a
    ; Move to start position (y in A, x in B)
    LDA >DRAW_LINE_ARGS+3  ; Y start (low byte)
    ADDA >VPY_MOVE_Y       ; Add MOVE Y offset
    LDB >DRAW_LINE_ARGS+1  ; X start (low byte)
    ADDB >VPY_MOVE_X       ; Add MOVE X offset
    JSR Moveto_d
    ; Compute deltas using 16-bit arithmetic
    ; dx = x1 - x0 (treating as signed 16-bit)
    LDD >DRAW_LINE_ARGS+4  ; x1 (16-bit)
    SUBD >DRAW_LINE_ARGS+0 ; subtract x0 (16-bit)
    STD VLINE_DX_16        ; Store full 16-bit dx
    ; dy = y1 - y0 (treating as signed 16-bit)
    LDD >DRAW_LINE_ARGS+6  ; y1 (16-bit)
    SUBD >DRAW_LINE_ARGS+2 ; subtract y0 (16-bit)
    STD VLINE_DY_16        ; Store full 16-bit dy
    ; SEGMENT 1: Clamp dy to ±127 and draw
    LDD VLINE_DY_16 ; Load full dy
    CMPD #127
    BLE DLW_SEG1_DY_LO
    LDA #127        ; dy > 127: use 127
    BRA DLW_SEG1_DY_READY
DLW_SEG1_DY_LO:
    CMPD #-128
    BGE DLW_SEG1_DY_NO_CLAMP  ; -128 <= dy <= 127: use original (sign-extended)
    LDA #$80        ; dy < -128: use -128
    BRA DLW_SEG1_DY_READY
DLW_SEG1_DY_NO_CLAMP:
    LDA VLINE_DY_16+1  ; Use original low byte (already in valid range)
DLW_SEG1_DY_READY:
    STA VLINE_DY    ; Save clamped dy for segment 1
    ; Clamp dx to ±127
    LDD VLINE_DX_16
    CMPD #127
    BLE DLW_SEG1_DX_LO
    LDB #127        ; dx > 127: use 127
    BRA DLW_SEG1_DX_READY
DLW_SEG1_DX_LO:
    CMPD #-128
    BGE DLW_SEG1_DX_NO_CLAMP  ; -128 <= dx <= 127: use original (sign-extended)
    LDB #$80        ; dx < -128: use -128
    BRA DLW_SEG1_DX_READY
DLW_SEG1_DX_NO_CLAMP:
    LDB VLINE_DX_16+1  ; Use original low byte (already in valid range)
DLW_SEG1_DX_READY:
    STB VLINE_DX    ; Save clamped dx for segment 1
    ; Draw segment 1
    CLR Vec_Misc_Count
    LDA VLINE_DY
    LDB VLINE_DX
    JSR Draw_Line_d ; Beam moves automatically
    ; Check if we need SEGMENT 2 (dy outside ±127 range)
    LDD VLINE_DY_16 ; Reload original dy
    CMPD #127
    BGT DLW_NEED_SEG2  ; dy > 127: needs segment 2
    CMPD #-128
    BLT DLW_NEED_SEG2  ; dy < -128: needs segment 2
    BRA DLW_DONE       ; dy in range ±127: no segment 2
DLW_NEED_SEG2:
    ; SEGMENT 2: Draw remaining dy and dx
    ; Calculate remaining dy
    LDD VLINE_DY_16 ; Load original full dy
    CMPD #127
    BGT DLW_SEG2_DY_POS  ; dy > 127
    ; dy < -128, so we drew -128 in segment 1
    ; remaining = dy - (-128) = dy + 128
    ADDD #128       ; Add back the -128 we already drew
    BRA DLW_SEG2_DY_DONE
DLW_SEG2_DY_POS:
    ; dy > 127, so we drew 127 in segment 1
    ; remaining = dy - 127
    SUBD #127       ; Subtract 127 we already drew
DLW_SEG2_DY_DONE:
    STD VLINE_DY_REMAINING  ; Store remaining dy (16-bit)
    ; Calculate remaining dx
    LDD VLINE_DX_16 ; Load original full dx
    CMPD #127
    BLE DLW_SEG2_DX_CHECK_NEG
    ; dx > 127, so we drew 127 in segment 1
    ; remaining = dx - 127
    SUBD #127
    BRA DLW_SEG2_DX_DONE
DLW_SEG2_DX_CHECK_NEG:
    CMPD #-128
    BGE DLW_SEG2_DX_NO_REMAIN  ; -128 <= dx <= 127: no remaining dx
    ; dx < -128, so we drew -128 in segment 1
    ; remaining = dx - (-128) = dx + 128
    ADDD #128
    BRA DLW_SEG2_DX_DONE
DLW_SEG2_DX_NO_REMAIN:
    LDD #0          ; No remaining dx
DLW_SEG2_DX_DONE:
    STD VLINE_DX_REMAINING  ; Store remaining dx (16-bit) in VLINE_DX_REMAINING
    ; Setup for Draw_Line_d: A=dy, B=dx (CRITICAL: order matters!)
    ; Load remaining dy from VLINE_DY_REMAINING (already saved)
    LDA VLINE_DY_REMAINING+1  ; Low byte of remaining dy
    LDB VLINE_DX_REMAINING+1  ; Low byte of remaining dx
    CLR Vec_Misc_Count
    JSR Draw_Line_d ; Beam continues from segment 1 endpoint
DLW_DONE:
    LDA #$C8       ; CRITICAL: Restore DP to $C8 for our code
    TFR A,DP
    RTS
; BIOS Wrappers - VIDE compatible (ensure DP=$D0 per call)
__Intensity_a:
TFR B,A         ; Move B to A (BIOS expects intensity in A)
JMP Intensity_a ; JMP (not JSR) - BIOS returns to original caller
__Reset0Ref:
JMP Reset0Ref   ; JMP (not JSR) - BIOS returns to original caller
__Moveto_d:
LDA 2,S         ; Get Y from stack (after return address)
JMP Moveto_d    ; JMP (not JSR) - BIOS returns to original caller
__Draw_Line_d:
LDA 2,S         ; Get dy from stack (after return address)
JMP Draw_Line_d ; JMP (not JSR) - BIOS returns to original caller
START:
    LDA #$D0
    TFR A,DP        ; Set Direct Page for BIOS (CRITICAL - do once at startup)
    CLR $C80E        ; Initialize Vec_Prev_Btns to 0 for Read_Btns debounce
    LDA #$80
    STA VIA_t1_cnt_lo
    LDX #Vec_Default_Stk
    TFR X,S

    ; *** DEBUG *** main() function code inline (initialization)
    ; VPy_LINE:13
    ; VPy_LINE:11
    LDD #100
    STD VAR_BRIGHTNESS
    ; VPy_LINE:14
    LDD #100
    STD RESULT
    LDX RESULT
    LDU #VAR_BRIGHTNESS
    STU TMPPTR
    STX ,U

MAIN:
    JSR $F1AF    ; DP_to_C8 (required for RAM access)
    ; === Initialize Joystick (one-time setup) ===
    CLR $C823    ; CRITICAL: Clear analog mode flag (Joy_Analog does DEC on this)
    LDA #$01     ; CRITICAL: Resolution threshold (power of 2: $40=fast, $01=accurate)
    STA $C81A    ; Vec_Joy_Resltn (loop terminates when B=this value after LSRBs)
    LDA #$01
    STA $C81F    ; Vec_Joy_Mux_1_X (enable X axis reading)
    LDA #$03
    STA $C820    ; Vec_Joy_Mux_1_Y (enable Y axis reading)
    LDA #$00
    STA $C821    ; Vec_Joy_Mux_2_X (disable joystick 2 - CRITICAL!)
    STA $C822    ; Vec_Joy_Mux_2_Y (disable joystick 2 - saves cycles)
    ; Mux configured - J1_X()/J1_Y() can now be called

    ; JSR Wait_Recal is now called at start of LOOP_BODY (see auto-inject)
    LDA #$80
    STA VIA_t1_cnt_lo
    CLR VPY_MOVE_X  ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y  ; MOVE offset defaults to 0
    ; *** Call loop() as subroutine (executed every frame)
    JSR LOOP_BODY
    BRA MAIN

    ; VPy_LINE:16
LOOP_BODY:
    JSR Wait_Recal  ; CRITICAL: Sync with CRT refresh (50Hz frame timing)
    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access
    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)
    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access
    ; DEBUG: Statement 0 - Discriminant(8)
    ; VPy_LINE:17
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-60
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #90
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_1
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 17
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; DEBUG: Statement 1 - Discriminant(8)
    ; VPy_LINE:18
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-80
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #70
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_0
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 18
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; DEBUG: Statement 2 - Discriminant(9)
    ; VPy_LINE:20
; NATIVE_CALL: J1_BUTTON_1 at line 20
    JSR J1B1_BUILTIN
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_1
    ; VPy_LINE:21
    LDD VAR_BRIGHTNESS
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #5
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_4
    LDD #0
    STD RESULT
    BRA CE_5
CT_4:
    LDD #1
    STD RESULT
CE_5:
    LDD RESULT
    LBEQ IF_NEXT_3
    ; VPy_LINE:22
    LDD VAR_BRIGHTNESS
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #5
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_BRIGHTNESS
    STU TMPPTR
    STX ,U
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    ; DEBUG: Statement 3 - Discriminant(9)
    ; VPy_LINE:24
; NATIVE_CALL: J1_BUTTON_2 at line 24
    JSR J1B2_BUILTIN
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_7
    ; VPy_LINE:25
    LDD VAR_BRIGHTNESS
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #120
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_10
    LDD #0
    STD RESULT
    BRA CE_11
CT_10:
    LDD #1
    STD RESULT
CE_11:
    LDD RESULT
    LBEQ IF_NEXT_9
    ; VPy_LINE:26
    LDD VAR_BRIGHTNESS
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #5
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_BRIGHTNESS
    STU TMPPTR
    STX ,U
    LBRA IF_END_8
IF_NEXT_9:
IF_END_8:
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
    ; DEBUG: Statement 4 - Discriminant(8)
    ; VPy_LINE:28
    LDD #65496
    STD >DRAW_LINE_ARGS+0
    LDD #65496
    STD >DRAW_LINE_ARGS+2
    LDD #40
    STD >DRAW_LINE_ARGS+4
    LDD #65496
    STD >DRAW_LINE_ARGS+6
    LDD VAR_BRIGHTNESS
    STD RESULT
    STD >DRAW_LINE_ARGS+8
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    ; DEBUG: Statement 5 - Discriminant(8)
    ; VPy_LINE:29
    LDD #40
    STD >DRAW_LINE_ARGS+0
    LDD #65496
    STD >DRAW_LINE_ARGS+2
    LDD #40
    STD >DRAW_LINE_ARGS+4
    LDD #40
    STD >DRAW_LINE_ARGS+6
    LDD VAR_BRIGHTNESS
    STD RESULT
    STD >DRAW_LINE_ARGS+8
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    ; DEBUG: Statement 6 - Discriminant(8)
    ; VPy_LINE:30
    LDD #40
    STD >DRAW_LINE_ARGS+0
    LDD #40
    STD >DRAW_LINE_ARGS+2
    LDD #65496
    STD >DRAW_LINE_ARGS+4
    LDD #40
    STD >DRAW_LINE_ARGS+6
    LDD VAR_BRIGHTNESS
    STD RESULT
    STD >DRAW_LINE_ARGS+8
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    ; DEBUG: Statement 7 - Discriminant(8)
    ; VPy_LINE:31
    LDD #65496
    STD >DRAW_LINE_ARGS+0
    LDD #40
    STD >DRAW_LINE_ARGS+2
    LDD #65496
    STD >DRAW_LINE_ARGS+4
    LDD #65496
    STD >DRAW_LINE_ARGS+6
    LDD VAR_BRIGHTNESS
    STD RESULT
    STD >DRAW_LINE_ARGS+8
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    ; DEBUG: Statement 8 - Discriminant(8)
    ; VPy_LINE:32
    LDD #65496
    STD >DRAW_LINE_ARGS+0
    LDD #65496
    STD >DRAW_LINE_ARGS+2
    LDD #40
    STD >DRAW_LINE_ARGS+4
    LDD #40
    STD >DRAW_LINE_ARGS+6
    LDD VAR_BRIGHTNESS
    STD RESULT
    STD >DRAW_LINE_ARGS+8
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    ; DEBUG: Statement 9 - Discriminant(8)
    ; VPy_LINE:33
    LDD #40
    STD >DRAW_LINE_ARGS+0
    LDD #65496
    STD >DRAW_LINE_ARGS+2
    LDD #65496
    STD >DRAW_LINE_ARGS+4
    LDD #40
    STD >DRAW_LINE_ARGS+6
    LDD VAR_BRIGHTNESS
    STD RESULT
    STD >DRAW_LINE_ARGS+8
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    RTS

;***************************************************************************
; DATA SECTION
;***************************************************************************
; String literals (classic FCC + $80 terminator)
STR_0:
    FCC "B1=DIM B2=BRIGHT"
    FCB $80
STR_1:
    FCC "BRIGHTNESS"
    FCB $80
