; --- Motorola 6809 backend (Vectrex) title='SOLITAIRE' origin=$0000 ---
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
    FCC "SOLITAIRE"
    FCB $80
    FCB 0

;***************************************************************************
; CODE SECTION
;***************************************************************************

; === RAM VARIABLE DEFINITIONS (EQU) ===
; AUTO-GENERATED - All offsets calculated automatically
; Total RAM used: 733 bytes
RESULT               EQU $C880+$00   ; Main result temporary (2 bytes)
TMPLEFT              EQU $C880+$02   ; Left operand temp (2 bytes)
TMPLEFT2             EQU $C880+$04   ; Left operand temp 2 (for nested operations) (2 bytes)
TMPRIGHT             EQU $C880+$06   ; Right operand temp (2 bytes)
TMPRIGHT2            EQU $C880+$08   ; Right operand temp 2 (for nested operations) (2 bytes)
TMPPTR               EQU $C880+$0A   ; Pointer temp (used by DRAW_VECTOR, arrays, structs) (2 bytes)
TMPPTR2              EQU $C880+$0C   ; Pointer temp 2 (for nested array operations) (2 bytes)
MUL_A                EQU $C880+$0E   ; Multiplicand A (2 bytes)
MUL_B                EQU $C880+$10   ; Multiplicand B (2 bytes)
MUL_RES              EQU $C880+$12   ; Multiply result (2 bytes)
MUL_TMP              EQU $C880+$14   ; Multiply temporary (2 bytes)
MUL_CNT              EQU $C880+$16   ; Multiply counter (2 bytes)
DIV_A                EQU $C880+$18   ; Dividend (2 bytes)
DIV_B                EQU $C880+$1A   ; Divisor (2 bytes)
DIV_Q                EQU $C880+$1C   ; Quotient (2 bytes)
DIV_R                EQU $C880+$1E   ; Remainder (2 bytes)
TEMP_YX              EQU $C880+$20   ; Temporary y,x storage (2 bytes)
TEMP_X               EQU $C880+$22   ; Temporary x storage (1 bytes)
TEMP_Y               EQU $C880+$23   ; Temporary y storage (1 bytes)
VPY_MOVE_X           EQU $C880+$24   ; MOVE() current X offset (signed byte, 0 by default) (1 bytes)
VPY_MOVE_Y           EQU $C880+$25   ; MOVE() current Y offset (signed byte, 0 by default) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$26   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity as i16x5) (10 bytes)
RAND_SEED            EQU $C880+$30   ; Random seed for RAND() LCG (2 bytes)
NUM_STR              EQU $C880+$32   ; String buffer for PRINT_NUMBER (5 digits + terminator) (6 bytes)
TEXT_SCALE_H         EQU $C880+$38   ; Character height for Print_Str_d (default $F8=-8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$39   ; Character width for Print_Str_d (default $48=72, normal) (1 bytes)
DRAW_VEC_X           EQU $C880+$3A   ; X position offset for vector drawing (1 bytes)
DRAW_VEC_Y           EQU $C880+$3B   ; Y position offset for vector drawing (1 bytes)
MIRROR_X             EQU $C880+$3C   ; X-axis mirror flag (0=normal, 1=flip) (1 bytes)
MIRROR_Y             EQU $C880+$3D   ; Y-axis mirror flag (0=normal, 1=flip) (1 bytes)
DRAW_VEC_INTENSITY   EQU $C880+$3E   ; Intensity override (0=use vector's, >0=override) (1 bytes)
VAR_DECK_DATA        EQU $C880+$3F   ; Array data (52 elements) (104 bytes)
VAR_TAB_DATA         EQU $C880+$A7   ; Array data (140 elements) (280 bytes)
VAR_TAB_SZ_DATA      EQU $C880+$1BF   ; Array data (7 elements) (14 bytes)
VAR_TAB_HID_DATA     EQU $C880+$1CD   ; Array data (7 elements) (14 bytes)
VAR_FOUND_CNT_DATA   EQU $C880+$1DB   ; Array data (4 elements) (8 bytes)
VAR_STOCK_DATA       EQU $C880+$1E3   ; Array data (24 elements) (48 bytes)
VAR_STK_SZ           EQU $C880+$213   ; User variable (2 bytes)
VAR_WASTE_DATA       EQU $C880+$215   ; Array data (24 elements) (48 bytes)
VAR_WST_SZ           EQU $C880+$245   ; User variable (2 bytes)
VAR_CURSOR           EQU $C880+$247   ; User variable (2 bytes)
VAR_SEL_CARD         EQU $C880+$249   ; User variable (2 bytes)
VAR_SEL_SRC          EQU $C880+$24B   ; User variable (2 bytes)
VAR_GAME_STATE       EQU $C880+$24D   ; User variable (2 bytes)
VAR_WIN_BLINK        EQU $C880+$24F   ; User variable (2 bytes)
VAR_PREV_BTN1        EQU $C880+$251   ; User variable (2 bytes)
VAR_PREV_BTN2        EQU $C880+$253   ; User variable (2 bytes)
VAR_BTN1_FIRE        EQU $C880+$255   ; User variable (2 bytes)
VAR_BTN2_FIRE        EQU $C880+$257   ; User variable (2 bytes)
VAR_PREV_JX          EQU $C880+$259   ; User variable (2 bytes)
VAR_G_RESULT         EQU $C880+$25B   ; User variable (2 bytes)
VAR_G_COL_X          EQU $C880+$25D   ; User variable (2 bytes)
VAR_G_CARD           EQU $C880+$25F   ; User variable (2 bytes)
VAR_G_RANK           EQU $C880+$261   ; User variable (2 bytes)
VAR_G_SUIT           EQU $C880+$263   ; User variable (2 bytes)
VAR_G_SZ             EQU $C880+$265   ; User variable (2 bytes)
VAR_G_HD             EQU $C880+$267   ; User variable (2 bytes)
VAR_G_IDX            EQU $C880+$269   ; User variable (2 bytes)
VAR_G_CY             EQU $C880+$26B   ; User variable (2 bytes)
VAR_G_TIDX           EQU $C880+$26D   ; User variable (2 bytes)
VAR_G_TOP            EQU $C880+$26F   ; User variable (2 bytes)
VAR_G_TR             EQU $C880+$271   ; User variable (2 bytes)
VAR_G_TC             EQU $C880+$273   ; User variable (2 bytes)
VAR_G_TOP_RED        EQU $C880+$275   ; User variable (2 bytes)
VAR_G_CARD_RED       EQU $C880+$277   ; User variable (2 bytes)
VAR_G_PLACED         EQU $C880+$279   ; User variable (2 bytes)
VAR_DEAL_IDX         EQU $C880+$27B   ; User variable (2 bytes)
VAR_G_ROW            EQU $C880+$27D   ; User variable (2 bytes)
VAR_G_C              EQU $C880+$27F   ; User variable (2 bytes)
VAR_G_CX             EQU $C880+$281   ; User variable (2 bytes)
VAR_G_FC             EQU $C880+$283   ; User variable (2 bytes)
VAR_G_WCARD          EQU $C880+$285   ; User variable (2 bytes)
VAR_G_FX             EQU $C880+$287   ; User variable (2 bytes)
VAR_CARD_H           EQU $C880+$289   ; User variable (2 bytes)
VAR_CARD_W           EQU $C880+$28B   ; User variable (2 bytes)
VAR_COL_DY           EQU $C880+$28D   ; User variable (2 bytes)
VAR_F0_X             EQU $C880+$28F   ; User variable (2 bytes)
VAR_F1_X             EQU $C880+$291   ; User variable (2 bytes)
VAR_F2_X             EQU $C880+$293   ; User variable (2 bytes)
VAR_F3_X             EQU $C880+$295   ; User variable (2 bytes)
VAR_HALF_W           EQU $C880+$297   ; User variable (2 bytes)
VAR_INT_CARD         EQU $C880+$299   ; User variable (2 bytes)
VAR_INT_CURSOR       EQU $C880+$29B   ; User variable (2 bytes)
VAR_INT_EMPTY        EQU $C880+$29D   ; User variable (2 bytes)
VAR_INT_FACEDN       EQU $C880+$29F   ; User variable (2 bytes)
VAR_INT_HELD         EQU $C880+$2A1   ; User variable (2 bytes)
VAR_STATE_PLAY       EQU $C880+$2A3   ; User variable (2 bytes)
VAR_STATE_WIN        EQU $C880+$2A5   ; User variable (2 bytes)
VAR_STK_X            EQU $C880+$2A7   ; User variable (2 bytes)
VAR_TAB_X0           EQU $C880+$2A9   ; User variable (2 bytes)
VAR_TAB_X1           EQU $C880+$2AB   ; User variable (2 bytes)
VAR_TAB_X2           EQU $C880+$2AD   ; User variable (2 bytes)
VAR_TAB_X3           EQU $C880+$2AF   ; User variable (2 bytes)
VAR_TAB_X4           EQU $C880+$2B1   ; User variable (2 bytes)
VAR_TAB_X5           EQU $C880+$2B3   ; User variable (2 bytes)
VAR_TAB_X6           EQU $C880+$2B5   ; User variable (2 bytes)
VAR_TAB_Y            EQU $C880+$2B7   ; User variable (2 bytes)
VAR_TOP_Y            EQU $C880+$2B9   ; User variable (2 bytes)
VAR_WST_X            EQU $C880+$2BB   ; User variable (2 bytes)
VAR_CARD             EQU $C880+$2BD   ; User variable (2 bytes)
VAR_COL              EQU $C880+$2BF   ; User variable (2 bytes)
VAR_FX               EQU $C880+$2C1   ; User variable (2 bytes)
VAR_INTENSITY        EQU $C880+$2C3   ; User variable (2 bytes)
VAR_N                EQU $C880+$2C5   ; User variable (2 bytes)
VAR_R                EQU $C880+$2C7   ; User variable (2 bytes)
VAR_S                EQU $C880+$2C9   ; User variable (2 bytes)
VAR_SUIT             EQU $C880+$2CB   ; User variable (2 bytes)
VAR_X                EQU $C880+$2CD   ; User variable (2 bytes)
VAR_Y                EQU $C880+$2CF   ; User variable (2 bytes)
VAR_ARG0             EQU $C880+$2D1   ; Function argument 0 (2 bytes)
VAR_ARG1             EQU $C880+$2D3   ; Function argument 1 (2 bytes)
VAR_ARG2             EQU $C880+$2D5   ; Function argument 2 (2 bytes)
VAR_ARG3             EQU $C880+$2D7   ; Function argument 3 (2 bytes)
VAR_ARG4             EQU $C880+$2D9   ; Function argument 4 (2 bytes)
VAR_ARG5             EQU $C880+$2DB   ; Function argument 5 (2 bytes)

    JMP START

;**** CONST DECLARATIONS (NUMBER-ONLY) ****
; VPy_LINE:11
; _CONST_DECL_0:  ; const CARD_W
; VPy_LINE:12
; _CONST_DECL_1:  ; const CARD_H
; VPy_LINE:13
; _CONST_DECL_2:  ; const COL_DY
; VPy_LINE:14
; _CONST_DECL_3:  ; const HALF_W
; VPy_LINE:17
; _CONST_DECL_4:  ; const TOP_Y
; VPy_LINE:18
; _CONST_DECL_5:  ; const TAB_Y
; VPy_LINE:19
; _CONST_DECL_6:  ; const STK_X
; VPy_LINE:20
; _CONST_DECL_7:  ; const WST_X
; VPy_LINE:21
; _CONST_DECL_8:  ; const F0_X
; VPy_LINE:22
; _CONST_DECL_9:  ; const F1_X
; VPy_LINE:23
; _CONST_DECL_10:  ; const F2_X
; VPy_LINE:24
; _CONST_DECL_11:  ; const F3_X
; VPy_LINE:25
; _CONST_DECL_12:  ; const TAB_X0
; VPy_LINE:26
; _CONST_DECL_13:  ; const TAB_X1
; VPy_LINE:27
; _CONST_DECL_14:  ; const TAB_X2
; VPy_LINE:28
; _CONST_DECL_15:  ; const TAB_X3
; VPy_LINE:29
; _CONST_DECL_16:  ; const TAB_X4
; VPy_LINE:30
; _CONST_DECL_17:  ; const TAB_X5
; VPy_LINE:31
; _CONST_DECL_18:  ; const TAB_X6
; VPy_LINE:34
; _CONST_DECL_19:  ; const INT_CARD
; VPy_LINE:35
; _CONST_DECL_20:  ; const INT_CURSOR
; VPy_LINE:36
; _CONST_DECL_21:  ; const INT_FACEDN
; VPy_LINE:37
; _CONST_DECL_22:  ; const INT_EMPTY
; VPy_LINE:38
; _CONST_DECL_23:  ; const INT_HELD
; VPy_LINE:41
; _CONST_DECL_24:  ; const STATE_PLAY
; VPy_LINE:42
; _CONST_DECL_25:  ; const STATE_WIN

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
    LDA >TEXT_SCALE_H ; height (signed byte, -n)
    STA >$C82A     ; Vec_Text_Height: character Y scale
    LDA >TEXT_SCALE_W ; width (unsigned byte, n*9)
    STA >$C82B     ; Vec_Text_Width: character X spacing
    LDA VAR_ARG1+1 ; Y (ARG1 = second param)
    LDB VAR_ARG0+1 ; X (ARG0 = first param)
    JSR Print_Str_d
    LDA #$F8
    STA >$C82A     ; Restore Vec_Text_Height to normal (-8)
    LDA #$48
    STA >$C82B     ; Restore Vec_Text_Width to normal (72)
    JSR $F1AF      ; DP_to_C8 (restore before return)
    RTS
VECTREX_SET_INTENSITY:
    ; CRITICAL: Set VIA to DAC mode BEFORE calling BIOS (don't assume state)
    LDA #$98       ; VIA_cntl = $98 (DAC mode)
    STA >$D00C     ; VIA_cntl
    LDA #$D0
    TFR A,DP       ; Set Direct Page to $D0 for BIOS
    LDA VAR_ARG0+1
    JSR __Intensity_a
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
; ============================================================================
; Draw_Sync_List - EXACT port of Malban's draw_synced_list_c
; Data: FCB intensity, y_start, x_start, next_y, next_x, [flag, dy, dx]*, 2
; ============================================================================
Draw_Sync_List:
; ITERACIÓN 11: Loop completo dentro (bug assembler arreglado, datos embebidos OK)
LDA ,X+                 ; intensity
JSR $F2AB               ; BIOS Intensity_a (expects value in A)
LDB ,X+                 ; y_start
LDA ,X+                 ; x_start
STD TEMP_YX             ; Guardar en variable temporal (evita stack)
; Reset completo
CLR VIA_shift_reg
LDA #$CC
STA VIA_cntl
CLR VIA_port_a
LDA #$03
STA VIA_port_b          ; PB=$03: disable mux (Reset_Pen step 1)
LDA #$02
STA VIA_port_b          ; PB=$02: enable mux (Reset_Pen step 2)
LDA #$02
STA VIA_port_b          ; repeat
LDA #$01
STA VIA_port_b          ; PB=$01: disable mux (integrators zeroed)
; Moveto (BIOS Moveto_d: Y->PA, CLR PB, settle, #CE, CLR SR, INC PB, X->PA)
LDD TEMP_YX             ; Recuperar y,x
STB VIA_port_a          ; Y to DAC (PB=1: integrators hold)
CLR VIA_port_b          ; PB=0: enable mux, beam tracks Y
PSHS A                  ; ~4 cycle settling delay for Y
LDA #$CE
STA VIA_cntl            ; PCR=$CE: /ZERO high, integrators active
CLR VIA_shift_reg       ; SR=0: no draw during moveto
INC VIA_port_b          ; PB=1: disable mux, lock direction at Y
PULS A                  ; Restore x
STA VIA_port_a          ; x to DAC
; Timing setup
LDA #$7F
STA VIA_t1_cnt_lo
CLR VIA_t1_cnt_hi
LEAX 2,X                ; Skip next_y, next_x
; Wait for move to complete (PB=1 on exit)
DSL_W1:
LDA VIA_int_flags
ANDA #$40
BEQ DSL_W1
; PB stays 1 — draw loop begins with PB=1
; Loop de dibujo
DSL_LOOP:
LDA ,X+                 ; Read flag
CMPA #2                 ; Check end marker
LBEQ DSL_DONE           ; Exit if end (long branch)
CMPA #1                 ; Check next path marker
LBEQ DSL_NEXT_PATH      ; Process next path (long branch)
; Draw line
CLR Vec_Misc_Count      ; Clear for relative line drawing (CRITICAL for continuity)
LDB ,X+                 ; dy
LDA ,X+                 ; dx
; B=DY, A=DX, PB=1 on entry (from moveto or previous segment)
STB VIA_port_a          ; DY to DAC (PB=1: integrators hold position)
CLR VIA_port_b          ; PB=0: enable mux, beam tracks DY direction
NOP                     ; settling 1 (per BIOS Draw_Line_d: LEAX+NOP = ~7 cycles)
NOP                     ; settling 2
NOP                     ; settling 3
INC VIA_port_b          ; PB=1: disable mux, lock direction at DY
STA VIA_port_a          ; DX to DAC
LDA #$FF
STA VIA_shift_reg       ; beam ON first (ramp still off from T1PB7)
CLR VIA_t1_cnt_hi       ; THEN start T1 -> ramp ON (BIOS order)
; Wait for line draw
DSL_W2:
LDA VIA_int_flags
ANDA #$40
BEQ DSL_W2
CLR VIA_shift_reg       ; beam off (PB stays 1 for next segment)
LBRA DSL_LOOP            ; Long branch back to loop start
; Next path: read new intensity and header, then continue drawing
DSL_NEXT_PATH:
; Save current X position before reading anything
TFR X,D                 ; D = X (current position)
PSHS D                  ; Save X address
LDA ,X+                 ; Read intensity (X now points to y_start)
PSHS A                  ; Save intensity
LDB ,X+                 ; y_start
LDA ,X+                 ; x_start (X now points to next_y)
STD TEMP_YX             ; Save y,x
PULS A                  ; Get intensity back
PSHS A                  ; Save intensity again
LDA #$D0
TFR A,DP                ; Set DP=$D0 (BIOS requirement)
PULS A                  ; Restore intensity
JSR $F2AB               ; BIOS Intensity_a (may corrupt X!)
; Restore X to point to next_y,next_x (after the 3 bytes we read)
PULS D                  ; Get original X
ADDD #3                 ; Skip intensity, y_start, x_start
TFR D,X                 ; X now points to next_y
; Reset to zero (same as Draw_Sync_List start)
CLR VIA_shift_reg
LDA #$CC
STA VIA_cntl
CLR VIA_port_a
LDA #$03
STA VIA_port_b          ; PB=$03: disable mux (Reset_Pen step 1)
LDA #$02
STA VIA_port_b          ; PB=$02: enable mux (Reset_Pen step 2)
LDA #$02
STA VIA_port_b          ; repeat
LDA #$01
STA VIA_port_b          ; PB=$01: disable mux (integrators zeroed)
; Moveto new start position (BIOS Moveto_d order)
LDD TEMP_YX
STB VIA_port_a          ; Y to DAC (PB=1: integrators hold)
CLR VIA_port_b          ; PB=0: enable mux, beam tracks Y
PSHS A                  ; ~4 cycle settling delay for Y
LDA #$CE
STA VIA_cntl            ; PCR=$CE: /ZERO high, integrators active
CLR VIA_shift_reg       ; SR=0: no draw during moveto
INC VIA_port_b          ; PB=1: disable mux, lock direction at Y
PULS A
STA VIA_port_a          ; x to DAC
LDA #$7F
STA VIA_t1_cnt_lo
CLR VIA_t1_cnt_hi
LEAX 2,X                ; Skip next_y, next_x
; Wait for move (PB=1 on exit)
DSL_W3:
LDA VIA_int_flags
ANDA #$40
BEQ DSL_W3
; PB stays 1 — draw loop continues with PB=1
LBRA DSL_LOOP            ; Continue drawing - LONG BRANCH
DSL_DONE:
RTS
Draw_Sync_List_At_With_Mirrors:
; Unified mirror support using flags: MIRROR_X and MIRROR_Y
; Conditionally negates X and/or Y coordinates and deltas
; NOTE: Caller must ensure DP=$D0 for VIA access
LDA DRAW_VEC_INTENSITY  ; Check if intensity override is set
BNE DSWM_USE_OVERRIDE   ; If non-zero, use override
LDA ,X+                 ; Otherwise, read intensity from vector data
BRA DSWM_SET_INTENSITY
DSWM_USE_OVERRIDE:
LEAX 1,X                ; Skip intensity byte in vector data
DSWM_SET_INTENSITY:
JSR $F2AB               ; BIOS Intensity_a
LDB ,X+                 ; y_start from .vec (already relative to center)
; Check if Y mirroring is enabled
TST MIRROR_Y
BEQ DSWM_NO_NEGATE_Y
NEGB                    ; ← Negate Y if flag set
DSWM_NO_NEGATE_Y:
ADDB DRAW_VEC_Y         ; Add Y offset
LDA ,X+                 ; x_start from .vec (already relative to center)
; Check if X mirroring is enabled
TST MIRROR_X
BEQ DSWM_NO_NEGATE_X
NEGA                    ; ← Negate X if flag set
DSWM_NO_NEGATE_X:
ADDA DRAW_VEC_X         ; Add X offset
STD TEMP_YX             ; Save adjusted position
; Reset completo
CLR VIA_shift_reg
LDA #$CC
STA VIA_cntl
CLR VIA_port_a
LDA #$03
STA VIA_port_b          ; PB=$03: disable mux (Reset_Pen step 1)
LDA #$02
STA VIA_port_b          ; PB=$02: enable mux (Reset_Pen step 2)
LDA #$02
STA VIA_port_b          ; repeat
LDA #$01
STA VIA_port_b          ; PB=$01: disable mux (integrators zeroed)
; Moveto (BIOS Moveto_d: Y->PA, CLR PB, settle, #CE, CLR SR, INC PB, X->PA)
LDD TEMP_YX
STB VIA_port_a          ; Y to DAC (PB=1: integrators hold)
CLR VIA_port_b          ; PB=0: enable mux, beam tracks Y
PSHS A                  ; ~4 cycle settling delay for Y
LDA #$CE
STA VIA_cntl            ; PCR=$CE: /ZERO high, integrators active
CLR VIA_shift_reg       ; SR=0: no draw during moveto
INC VIA_port_b          ; PB=1: disable mux, lock direction at Y
PULS A                  ; Restore x
STA VIA_port_a          ; x to DAC
; Timing setup
LDA #$7F
STA VIA_t1_cnt_lo
CLR VIA_t1_cnt_hi
LEAX 2,X                ; Skip next_y, next_x
; Wait for move to complete (PB=1 on exit)
DSWM_W1:
LDA VIA_int_flags
ANDA #$40
BEQ DSWM_W1
; PB stays 1 — draw loop begins with PB=1
; Loop de dibujo (conditional mirrors)
DSWM_LOOP:
LDA ,X+                 ; Read flag
CMPA #2                 ; Check end marker
LBEQ DSWM_DONE
CMPA #1                 ; Check next path marker
LBEQ DSWM_NEXT_PATH
; Draw line with conditional negations
LDB ,X+                 ; dy
; Check if Y mirroring is enabled
TST MIRROR_Y
BEQ DSWM_NO_NEGATE_DY
NEGB                    ; ← Negate dy if flag set
DSWM_NO_NEGATE_DY:
LDA ,X+                 ; dx
; Check if X mirroring is enabled
TST MIRROR_X
BEQ DSWM_NO_NEGATE_DX
NEGA                    ; ← Negate dx if flag set
DSWM_NO_NEGATE_DX:
; B=DY_final, A=DX_final, PB=1 on entry (from moveto or previous segment)
STB VIA_port_a          ; DY to DAC (PB=1: integrators hold position)
CLR VIA_port_b          ; PB=0: enable mux, beam tracks DY direction
NOP                     ; settling 1 (per BIOS Draw_Line_d: LEAX+NOP = ~7 cycles)
NOP                     ; settling 2
NOP                     ; settling 3
INC VIA_port_b          ; PB=1: disable mux, lock direction at DY
STA VIA_port_a          ; DX to DAC
LDA #$FF
STA VIA_shift_reg       ; beam ON first (ramp still off from T1PB7)
CLR VIA_t1_cnt_hi       ; THEN start T1 -> ramp ON (BIOS order)
; Wait for line draw
DSWM_W2:
LDA VIA_int_flags
ANDA #$40
BEQ DSWM_W2
CLR VIA_port_a          ; stop X integrator drift between segments
CLR VIA_shift_reg       ; beam off (PB stays 1 for next segment)
LBRA DSWM_LOOP          ; Long branch
; Next path: repeat mirror logic for new path header
DSWM_NEXT_PATH:
TFR X,D
PSHS D
; Check intensity override (same logic as start)
LDA DRAW_VEC_INTENSITY  ; Check if intensity override is set
BNE DSWM_NEXT_USE_OVERRIDE   ; If non-zero, use override
LDA ,X+                 ; Otherwise, read intensity from vector data
BRA DSWM_NEXT_SET_INTENSITY
DSWM_NEXT_USE_OVERRIDE:
LEAX 1,X                ; Skip intensity byte in vector data
DSWM_NEXT_SET_INTENSITY:
PSHS A
LDB ,X+                 ; y_start
TST MIRROR_Y
BEQ DSWM_NEXT_NO_NEGATE_Y
NEGB
DSWM_NEXT_NO_NEGATE_Y:
ADDB DRAW_VEC_Y         ; Add Y offset
LDA ,X+                 ; x_start
TST MIRROR_X
BEQ DSWM_NEXT_NO_NEGATE_X
NEGA
DSWM_NEXT_NO_NEGATE_X:
ADDA DRAW_VEC_X         ; Add X offset
STD TEMP_YX
PULS A                  ; Get intensity back
JSR $F2AB
PULS D
ADDD #3
TFR D,X
; Reset to zero
CLR VIA_shift_reg
LDA #$CC
STA VIA_cntl
CLR VIA_port_a
LDA #$03
STA VIA_port_b          ; PB=$03: disable mux (Reset_Pen step 1)
LDA #$02
STA VIA_port_b          ; PB=$02: enable mux (Reset_Pen step 2)
LDA #$02
STA VIA_port_b          ; repeat
LDA #$01
STA VIA_port_b          ; PB=$01: disable mux (integrators zeroed)
; Moveto new start position (BIOS Moveto_d order)
LDD TEMP_YX
STB VIA_port_a          ; Y to DAC (PB=1: integrators hold)
CLR VIA_port_b          ; PB=0: enable mux, beam tracks Y
PSHS A                  ; ~4 cycle settling delay for Y
LDA #$CE
STA VIA_cntl            ; PCR=$CE: /ZERO high, integrators active
CLR VIA_shift_reg       ; SR=0: no draw during moveto
INC VIA_port_b          ; PB=1: disable mux, lock direction at Y
PULS A
STA VIA_port_a          ; X to DAC
LDA #$7F
STA VIA_t1_cnt_lo
CLR VIA_t1_cnt_hi
LEAX 2,X
; Wait for move (PB=1 on exit)
DSWM_W3:
LDA VIA_int_flags
ANDA #$40
BEQ DSWM_W3
; PB stays 1 — draw loop continues with PB=1
LBRA DSWM_LOOP          ; Long branch
DSWM_DONE:
RTS
; === RAND_HELPER - LCG random number generator ===
; Returns D = random value 0..$7FFF
RAND_HELPER:
    LDD RAND_SEED
    LDX #26
    ; Multiply by 25: loop runs 25 times (LCG a=25, Hull-Dobell ok)
    PSHS D
    LDD #0
RAND_MUL_LOOP:
    LEAX -1,X
    BEQ RAND_MUL_DONE
    ADDD ,S
    BRA RAND_MUL_LOOP
RAND_MUL_DONE:
    LEAS 2,S
    ADDD #13
    STD RAND_SEED  ; Store full 16-bit state BEFORE masking output
    ANDA #$7F      ; Mask output to positive 15-bit (state stays full)
    RTS

; === RAND_RANGE_HELPER - Random in [min, max] ===
; Inputs: TMPPTR = min (i16), TMPPTR2 = max (i16)
; Returns: D = min + (rand % (max - min + 1))
RAND_RANGE_HELPER:
    JSR RAND_HELPER        ; D = rand (0..$7FFF)
    PSHS D                 ; Save rand
    LDD TMPPTR2            ; max
    SUBD TMPPTR            ; D = max - min
    ADDD #1                ; D = inclusive range
    STD TMPPTR2            ; TMPPTR2 = range
    PULS D                 ; Restore rand
RRH_MOD:
    SUBD TMPPTR2           ; D -= range
    BCC RRH_MOD            ; if no borrow (D >= range), keep subtracting
    ADDD TMPPTR2           ; Undo last subtract: now 0 <= D < range
    ADDD TMPPTR            ; Add min -> D in [min, max]
    RTS

START:
    LDA #$D0
    TFR A,DP        ; Set Direct Page for BIOS (CRITICAL - do once at startup)
    CLR $C80E        ; Initialize Vec_Prev_Btns to 0 for Read_Btns debounce
    LDA #$80
    STA VIA_t1_cnt_lo
    LDX #Vec_Default_Stk
    TFR X,S

    ; *** DEBUG *** main() function code inline (initialization)
    ; VPy_LINE:103
    ; VPy_LINE:45
    ; Copy array 'deck' from ROM to RAM (52 elements)
    LDX #ARRAY_0       ; Source: ROM array data
    LDU #VAR_DECK_DATA ; Dest: RAM array space
    LDD #52        ; Number of elements
COPY_LOOP_0:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    BNE COPY_LOOP_0 ; Loop until done
    ; VPy_LINE:48
    ; Copy array 'tab' from ROM to RAM (140 elements)
    LDX #ARRAY_1       ; Source: ROM array data
    LDU #VAR_TAB_DATA ; Dest: RAM array space
    LDD #140        ; Number of elements
COPY_LOOP_1:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    BNE COPY_LOOP_1 ; Loop until done
    ; VPy_LINE:49
    ; Copy array 'tab_sz' from ROM to RAM (7 elements)
    LDX #ARRAY_2       ; Source: ROM array data
    LDU #VAR_TAB_SZ_DATA ; Dest: RAM array space
    LDD #7        ; Number of elements
COPY_LOOP_2:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    BNE COPY_LOOP_2 ; Loop until done
    ; VPy_LINE:50
    ; Copy array 'tab_hid' from ROM to RAM (7 elements)
    LDX #ARRAY_3       ; Source: ROM array data
    LDU #VAR_TAB_HID_DATA ; Dest: RAM array space
    LDD #7        ; Number of elements
COPY_LOOP_3:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    BNE COPY_LOOP_3 ; Loop until done
    ; VPy_LINE:53
    ; Copy array 'found_cnt' from ROM to RAM (4 elements)
    LDX #ARRAY_4       ; Source: ROM array data
    LDU #VAR_FOUND_CNT_DATA ; Dest: RAM array space
    LDD #4        ; Number of elements
COPY_LOOP_4:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    BNE COPY_LOOP_4 ; Loop until done
    ; VPy_LINE:56
    ; Copy array 'stock' from ROM to RAM (24 elements)
    LDX #ARRAY_5       ; Source: ROM array data
    LDU #VAR_STOCK_DATA ; Dest: RAM array space
    LDD #24        ; Number of elements
COPY_LOOP_5:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    BNE COPY_LOOP_5 ; Loop until done
    ; VPy_LINE:57
    LDD #0
    STD VAR_STK_SZ
    ; VPy_LINE:58
    ; Copy array 'waste' from ROM to RAM (24 elements)
    LDX #ARRAY_6       ; Source: ROM array data
    LDU #VAR_WASTE_DATA ; Dest: RAM array space
    LDD #24        ; Number of elements
COPY_LOOP_6:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    BNE COPY_LOOP_6 ; Loop until done
    ; VPy_LINE:59
    LDD #0
    STD VAR_WST_SZ
    ; VPy_LINE:62
    LDD #0
    STD VAR_CURSOR
    ; VPy_LINE:63
    LDD #-1
    STD VAR_SEL_CARD
    ; VPy_LINE:64
    LDD #-1
    STD VAR_SEL_SRC
    ; VPy_LINE:67
    LDD #0
    STD RESULT
    STD VAR_GAME_STATE
    ; VPy_LINE:68
    LDD #0
    STD VAR_WIN_BLINK
    ; VPy_LINE:71
    LDD #0
    STD VAR_PREV_BTN1
    ; VPy_LINE:72
    LDD #0
    STD VAR_PREV_BTN2
    ; VPy_LINE:73
    LDD #0
    STD VAR_BTN1_FIRE
    ; VPy_LINE:74
    LDD #0
    STD VAR_BTN2_FIRE
    ; VPy_LINE:75
    LDD #0
    STD VAR_PREV_JX
    ; VPy_LINE:78
    LDD #0
    STD VAR_G_RESULT
    ; VPy_LINE:79
    LDD #0
    STD VAR_G_COL_X
    ; VPy_LINE:80
    LDD #0
    STD VAR_G_CARD
    ; VPy_LINE:81
    LDD #0
    STD VAR_G_RANK
    ; VPy_LINE:82
    LDD #0
    STD VAR_G_SUIT
    ; VPy_LINE:83
    LDD #0
    STD VAR_G_SZ
    ; VPy_LINE:84
    LDD #0
    STD VAR_G_HD
    ; VPy_LINE:85
    LDD #0
    STD VAR_G_IDX
    ; VPy_LINE:86
    LDD #0
    STD VAR_G_CY
    ; VPy_LINE:87
    LDD #0
    STD VAR_G_TIDX
    ; VPy_LINE:88
    LDD #0
    STD VAR_G_TOP
    ; VPy_LINE:89
    LDD #0
    STD VAR_G_TR
    ; VPy_LINE:90
    LDD #0
    STD VAR_G_TC
    ; VPy_LINE:91
    LDD #0
    STD VAR_G_TOP_RED
    ; VPy_LINE:92
    LDD #0
    STD VAR_G_CARD_RED
    ; VPy_LINE:93
    LDD #0
    STD VAR_G_PLACED
    ; VPy_LINE:94
    LDD #0
    STD VAR_DEAL_IDX
    ; VPy_LINE:95
    LDD #0
    STD VAR_G_ROW
    ; VPy_LINE:96
    LDD #0
    STD VAR_G_C
    ; VPy_LINE:97
    LDD #0
    STD VAR_G_CX
    ; VPy_LINE:98
    LDD #0
    STD VAR_G_FC
    ; VPy_LINE:99
    LDD #0
    STD VAR_G_WCARD
    ; VPy_LINE:100
    LDD #0
    STD VAR_G_FX
    ; VPy_LINE:104
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_GAME_STATE
    STU TMPPTR
    STX ,U
    ; VPy_LINE:105
    JSR SHUFFLE
    ; VPy_LINE:106
    JSR DEAL

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
    LDA #$F8
    STA TEXT_SCALE_H  ; Default height = -8 (normal size)
    LDA #$48
    STA TEXT_SCALE_W  ; Default width = 72 (normal size)
    ; *** Call loop() as subroutine (executed every frame)
    JSR LOOP_BODY
    BRA MAIN

CARD_W EQU 26
CARD_H EQU 32
COL_DY EQU 14
HALF_W EQU 13
TOP_Y EQU 85
TAB_Y EQU 30
STK_X EQU 65434
WST_X EQU 65468
F0_X EQU 0
F1_X EQU 34
F2_X EQU 68
F3_X EQU 102
TAB_X0 EQU 65434
TAB_X1 EQU 65468
TAB_X2 EQU 65502
TAB_X3 EQU 0
TAB_X4 EQU 34
TAB_X5 EQU 68
TAB_X6 EQU 102
INT_CARD EQU 70
INT_CURSOR EQU 127
INT_FACEDN EQU 40
INT_EMPTY EQU 25
INT_HELD EQU 100
STATE_PLAY EQU 0
STATE_WIN EQU 1
    ; VPy_LINE:109
LOOP_BODY:
    JSR Wait_Recal  ; CRITICAL: Sync with CRT refresh (50Hz frame timing)
    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access
    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)
    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access
    ; DEBUG: Statement 0 - Discriminant(0)
    ; VPy_LINE:110
; NATIVE_CALL: J1_BUTTON_1 at line 110
    JSR J1B1_BUILTIN
    STD RESULT
    LDX RESULT
    LDU #VAR_G_CARD
    STU TMPPTR
    STX ,U
    ; DEBUG: Statement 1 - Discriminant(0)
    ; VPy_LINE:111
; NATIVE_CALL: J1_BUTTON_2 at line 111
    JSR J1B2_BUILTIN
    STD RESULT
    LDX RESULT
    LDU #VAR_G_RANK
    STU TMPPTR
    STX ,U
    ; DEBUG: Statement 2 - Discriminant(0)
    ; VPy_LINE:112
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_BTN1_FIRE
    STU TMPPTR
    STX ,U
    ; DEBUG: Statement 3 - Discriminant(0)
    ; VPy_LINE:113
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_BTN2_FIRE
    STU TMPPTR
    STX ,U
    ; DEBUG: Statement 4 - Discriminant(9)
    ; VPy_LINE:114
    LDD VAR_G_CARD
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_2
    LDD #0
    STD RESULT
    BRA CE_3
CT_2:
    LDD #1
    STD RESULT
CE_3:
    LDD RESULT
    BEQ AND_FALSE_4
    LDD VAR_PREV_BTN1
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_6
    LDD #0
    STD RESULT
    BRA CE_7
CT_6:
    LDD #1
    STD RESULT
CE_7:
    LDD RESULT
    BEQ AND_FALSE_4
    LDD #1
    STD RESULT
    BRA AND_END_5
AND_FALSE_4:
    LDD #0
    STD RESULT
AND_END_5:
    LDD RESULT
    LBEQ IF_NEXT_1
    ; VPy_LINE:115
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_BTN1_FIRE
    STU TMPPTR
    STX ,U
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    ; DEBUG: Statement 5 - Discriminant(9)
    ; VPy_LINE:116
    LDD VAR_G_RANK
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_10
    LDD #0
    STD RESULT
    BRA CE_11
CT_10:
    LDD #1
    STD RESULT
CE_11:
    LDD RESULT
    BEQ AND_FALSE_12
    LDD VAR_PREV_BTN2
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_14
    LDD #0
    STD RESULT
    BRA CE_15
CT_14:
    LDD #1
    STD RESULT
CE_15:
    LDD RESULT
    BEQ AND_FALSE_12
    LDD #1
    STD RESULT
    BRA AND_END_13
AND_FALSE_12:
    LDD #0
    STD RESULT
AND_END_13:
    LDD RESULT
    LBEQ IF_NEXT_9
    ; VPy_LINE:117
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_BTN2_FIRE
    STU TMPPTR
    STX ,U
    LBRA IF_END_8
IF_NEXT_9:
IF_END_8:
    ; DEBUG: Statement 6 - Discriminant(0)
    ; VPy_LINE:118
    LDD VAR_G_CARD
    STD RESULT
    LDX RESULT
    LDU #VAR_PREV_BTN1
    STU TMPPTR
    STX ,U
    ; DEBUG: Statement 7 - Discriminant(0)
    ; VPy_LINE:119
    LDD VAR_G_RANK
    STD RESULT
    LDX RESULT
    LDU #VAR_PREV_BTN2
    STU TMPPTR
    STX ,U
    ; DEBUG: Statement 8 - Discriminant(9)
    ; VPy_LINE:121
    LDD VAR_GAME_STATE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_18
    LDD #0
    STD RESULT
    BRA CE_19
CT_18:
    LDD #1
    STD RESULT
CE_19:
    LDD RESULT
    LBEQ IF_NEXT_17
    ; VPy_LINE:122
    JSR UPDATE_INPUT
    ; VPy_LINE:123
    JSR DRAW_TABLE
    ; VPy_LINE:124
    JSR CHECK_WIN
    LBRA IF_END_16
IF_NEXT_17:
    ; VPy_LINE:126
    JSR DRAW_WIN_SCREEN
IF_END_16:
    RTS

    ; VPy_LINE:131
SHUFFLE: ; function
; --- function shuffle ---
    ; VPy_LINE:132
    LDD #51
    STD RESULT
    LDX RESULT
    LDU #VAR_G_C
    STU TMPPTR
    STX ,U
    ; VPy_LINE:133
WH_20: ; while start
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_22
    LDD #0
    STD RESULT
    BRA CE_23
CT_22:
    LDD #1
    STD RESULT
CE_23:
    LDD RESULT
    LBEQ WH_END_21
    ; VPy_LINE:134
    ; RAND_RANGE(min, max)
    LDD #0
    STD RESULT
    STD TMPPTR
    LDD VAR_G_C
    STD RESULT
    STD TMPPTR2
    JSR RAND_RANGE_HELPER
    STD RESULT
    LDX RESULT
    LDU #VAR_G_IDX
    STU TMPPTR
    STX ,U
    ; VPy_LINE:135
    LDD #VAR_DECK_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX RESULT
    LDU #VAR_G_CARD
    STU TMPPTR
    STX ,U
    ; VPy_LINE:136
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_DECK_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #VAR_DECK_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_G_IDX
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:137
    LDD VAR_G_IDX
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_DECK_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD VAR_G_CARD
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:138
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_G_C
    STU TMPPTR
    STX ,U
    LBRA WH_20
WH_END_21: ; while end
    RTS

    ; VPy_LINE:143
DEAL: ; function
; --- function deal ---
    ; VPy_LINE:144
    LDD #0
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_TAB_SZ_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #0
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:145
    LDD #1
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_TAB_SZ_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #0
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:146
    LDD #2
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_TAB_SZ_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #0
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:147
    LDD #3
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_TAB_SZ_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #0
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:148
    LDD #4
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_TAB_SZ_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #0
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:149
    LDD #5
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_TAB_SZ_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #0
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:150
    LDD #6
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_TAB_SZ_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #0
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:151
    LDD #0
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_TAB_HID_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #0
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:152
    LDD #1
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_TAB_HID_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #0
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:153
    LDD #2
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_TAB_HID_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #0
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:154
    LDD #3
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_TAB_HID_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #0
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:155
    LDD #4
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_TAB_HID_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #0
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:156
    LDD #5
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_TAB_HID_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #0
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:157
    LDD #6
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_TAB_HID_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #0
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:158
    LDD #0
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_FOUND_CNT_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #0
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:159
    LDD #1
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_FOUND_CNT_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #0
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:160
    LDD #2
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_FOUND_CNT_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #0
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:161
    LDD #3
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_FOUND_CNT_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #0
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:162
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_STK_SZ
    STU TMPPTR
    STX ,U
    ; VPy_LINE:163
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_WST_SZ
    STU TMPPTR
    STX ,U
    ; VPy_LINE:164
    LDD #-1
    STD RESULT
    LDX RESULT
    LDU #VAR_SEL_CARD
    STU TMPPTR
    STX ,U
    ; VPy_LINE:165
    LDD #-1
    STD RESULT
    LDX RESULT
    LDU #VAR_SEL_SRC
    STU TMPPTR
    STX ,U
    ; VPy_LINE:166
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_CURSOR
    STU TMPPTR
    STX ,U
    ; VPy_LINE:168
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_DEAL_IDX
    STU TMPPTR
    STX ,U
    ; VPy_LINE:169
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_G_C
    STU TMPPTR
    STX ,U
    ; VPy_LINE:170
WH_24: ; while start
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #7
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_26
    LDD #0
    STD RESULT
    BRA CE_27
CT_26:
    LDD #1
    STD RESULT
CE_27:
    LDD RESULT
    LBEQ WH_END_25
    ; VPy_LINE:171
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_G_ROW
    STU TMPPTR
    STX ,U
    ; VPy_LINE:172
WH_28: ; while start
    LDD VAR_G_ROW
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLE CT_30
    LDD #0
    STD RESULT
    BRA CE_31
CT_30:
    LDD #1
    STD RESULT
CE_31:
    LDD RESULT
    LBEQ WH_END_29
    ; VPy_LINE:173
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #20
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    STD MUL_A
    LDD TMPRIGHT
    STD MUL_B
    JSR MUL16
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD VAR_G_ROW
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_G_TIDX
    STU TMPPTR
    STX ,U
    ; VPy_LINE:174
    LDD VAR_G_TIDX
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_TAB_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #VAR_DECK_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_DEAL_IDX
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:175
    LDD VAR_DEAL_IDX
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_DEAL_IDX
    STU TMPPTR
    STX ,U
    ; VPy_LINE:176
    LDD VAR_G_ROW
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_G_ROW
    STU TMPPTR
    STX ,U
    LBRA WH_28
WH_END_29: ; while end
    ; VPy_LINE:177
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_TAB_SZ_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:178
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_TAB_HID_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD VAR_G_C
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:179
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_G_C
    STU TMPPTR
    STX ,U
    LBRA WH_24
WH_END_25: ; while end
    ; VPy_LINE:181
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_G_ROW
    STU TMPPTR
    STX ,U
    ; VPy_LINE:182
WH_32: ; while start
    LDD VAR_DEAL_IDX
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #52
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_34
    LDD #0
    STD RESULT
    BRA CE_35
CT_34:
    LDD #1
    STD RESULT
CE_35:
    LDD RESULT
    LBEQ WH_END_33
    ; VPy_LINE:183
    LDD VAR_G_ROW
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_STOCK_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #VAR_DECK_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_DEAL_IDX
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:184
    LDD VAR_DEAL_IDX
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_DEAL_IDX
    STU TMPPTR
    STX ,U
    ; VPy_LINE:185
    LDD VAR_G_ROW
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_G_ROW
    STU TMPPTR
    STX ,U
    LBRA WH_32
WH_END_33: ; while end
    ; VPy_LINE:186
    LDD VAR_G_ROW
    STD RESULT
    LDX RESULT
    LDU #VAR_STK_SZ
    STU TMPPTR
    STX ,U
    RTS

    ; VPy_LINE:191
UPDATE_INPUT: ; function
; --- function update_input ---
    ; VPy_LINE:192
; NATIVE_CALL: J1_X at line 192
    JSR J1X_BUILTIN
    STD RESULT
    LDX RESULT
    LDU #VAR_G_IDX
    STU TMPPTR
    STX ,U
    ; VPy_LINE:193
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_G_ROW
    STU TMPPTR
    STX ,U
    ; VPy_LINE:194
    LDD VAR_G_IDX
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #40
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_38
    LDD #0
    STD RESULT
    BRA CE_39
CT_38:
    LDD #1
    STD RESULT
CE_39:
    LDD RESULT
    LBEQ IF_NEXT_37
    ; VPy_LINE:195
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_G_ROW
    STU TMPPTR
    STX ,U
    LBRA IF_END_36
IF_NEXT_37:
    LDD VAR_G_IDX
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-40
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_40
    LDD #0
    STD RESULT
    BRA CE_41
CT_40:
    LDD #1
    STD RESULT
CE_41:
    LDD RESULT
    LBEQ IF_END_36
    ; VPy_LINE:197
    LDD #-1
    STD RESULT
    LDX RESULT
    LDU #VAR_G_ROW
    STU TMPPTR
    STX ,U
    LBRA IF_END_36
IF_END_36:
    ; VPy_LINE:198
    LDD VAR_G_ROW
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_44
    LDD #0
    STD RESULT
    BRA CE_45
CT_44:
    LDD #1
    STD RESULT
CE_45:
    LDD RESULT
    BEQ AND_FALSE_46
    LDD VAR_PREV_JX
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_48
    LDD #0
    STD RESULT
    BRA CE_49
CT_48:
    LDD #1
    STD RESULT
CE_49:
    LDD RESULT
    BEQ AND_FALSE_46
    LDD #1
    STD RESULT
    BRA AND_END_47
AND_FALSE_46:
    LDD #0
    STD RESULT
AND_END_47:
    LDD RESULT
    LBEQ IF_NEXT_43
    ; VPy_LINE:199
    LDD VAR_CURSOR
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_CURSOR
    STU TMPPTR
    STX ,U
    ; VPy_LINE:200
    LDD VAR_CURSOR
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #12
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_52
    LDD #0
    STD RESULT
    BRA CE_53
CT_52:
    LDD #1
    STD RESULT
CE_53:
    LDD RESULT
    LBEQ IF_NEXT_51
    ; VPy_LINE:201
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_CURSOR
    STU TMPPTR
    STX ,U
    LBRA IF_END_50
IF_NEXT_51:
IF_END_50:
    LBRA IF_END_42
IF_NEXT_43:
    LDD VAR_G_ROW
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_54
    LDD #0
    STD RESULT
    BRA CE_55
CT_54:
    LDD #1
    STD RESULT
CE_55:
    LDD RESULT
    BEQ AND_FALSE_56
    LDD VAR_PREV_JX
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_58
    LDD #0
    STD RESULT
    BRA CE_59
CT_58:
    LDD #1
    STD RESULT
CE_59:
    LDD RESULT
    BEQ AND_FALSE_56
    LDD #1
    STD RESULT
    BRA AND_END_57
AND_FALSE_56:
    LDD #0
    STD RESULT
AND_END_57:
    LDD RESULT
    LBEQ IF_END_42
    ; VPy_LINE:203
    LDD VAR_CURSOR
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_CURSOR
    STU TMPPTR
    STX ,U
    ; VPy_LINE:204
    LDD VAR_CURSOR
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_62
    LDD #0
    STD RESULT
    BRA CE_63
CT_62:
    LDD #1
    STD RESULT
CE_63:
    LDD RESULT
    LBEQ IF_NEXT_61
    ; VPy_LINE:205
    LDD #12
    STD RESULT
    LDX RESULT
    LDU #VAR_CURSOR
    STU TMPPTR
    STX ,U
    LBRA IF_END_60
IF_NEXT_61:
IF_END_60:
    LBRA IF_END_42
IF_END_42:
    ; VPy_LINE:206
    LDD VAR_G_ROW
    STD RESULT
    LDX RESULT
    LDU #VAR_PREV_JX
    STU TMPPTR
    STX ,U
    ; VPy_LINE:208
    LDD VAR_BTN2_FIRE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_66
    LDD #0
    STD RESULT
    BRA CE_67
CT_66:
    LDD #1
    STD RESULT
CE_67:
    LDD RESULT
    LBEQ IF_NEXT_65
    ; VPy_LINE:209
    JSR DO_DEAL_STOCK
    LBRA IF_END_64
IF_NEXT_65:
IF_END_64:
    ; VPy_LINE:211
    LDD VAR_BTN1_FIRE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_70
    LDD #0
    STD RESULT
    BRA CE_71
CT_70:
    LDD #1
    STD RESULT
CE_71:
    LDD RESULT
    LBEQ IF_NEXT_69
    ; VPy_LINE:212
    LDD VAR_SEL_CARD
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_74
    LDD #0
    STD RESULT
    BRA CE_75
CT_74:
    LDD #1
    STD RESULT
CE_75:
    LDD RESULT
    LBEQ IF_NEXT_73
    ; VPy_LINE:213
    JSR DO_PICK_UP
    LBRA IF_END_72
IF_NEXT_73:
    ; VPy_LINE:215
    JSR DO_PLACE
IF_END_72:
    LBRA IF_END_68
IF_NEXT_69:
IF_END_68:
    RTS

    ; VPy_LINE:217
DO_DEAL_STOCK: ; function
; --- function do_deal_stock ---
    ; VPy_LINE:218
    LDD VAR_STK_SZ
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_78
    LDD #0
    STD RESULT
    BRA CE_79
CT_78:
    LDD #1
    STD RESULT
CE_79:
    LDD RESULT
    LBEQ IF_NEXT_77
    ; VPy_LINE:219
    LDD VAR_STK_SZ
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_STK_SZ
    STU TMPPTR
    STX ,U
    ; VPy_LINE:220
    LDD VAR_WST_SZ
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_WASTE_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #VAR_STOCK_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_STK_SZ
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:221
    LDD VAR_WST_SZ
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_WST_SZ
    STU TMPPTR
    STX ,U
    LBRA IF_END_76
IF_NEXT_77:
    ; VPy_LINE:223
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_G_ROW
    STU TMPPTR
    STX ,U
    ; VPy_LINE:224
WH_80: ; while start
    LDD VAR_G_ROW
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD VAR_WST_SZ
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_82
    LDD #0
    STD RESULT
    BRA CE_83
CT_82:
    LDD #1
    STD RESULT
CE_83:
    LDD RESULT
    LBEQ WH_END_81
    ; VPy_LINE:225
    LDD VAR_G_ROW
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_STOCK_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #VAR_WASTE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_G_ROW
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:226
    LDD VAR_G_ROW
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_G_ROW
    STU TMPPTR
    STX ,U
    LBRA WH_80
WH_END_81: ; while end
    ; VPy_LINE:227
    LDD VAR_WST_SZ
    STD RESULT
    LDX RESULT
    LDU #VAR_STK_SZ
    STU TMPPTR
    STX ,U
    ; VPy_LINE:228
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_WST_SZ
    STU TMPPTR
    STX ,U
IF_END_76:
    RTS

    ; VPy_LINE:230
DO_PICK_UP: ; function
; --- function do_pick_up ---
    ; VPy_LINE:231
    LDD VAR_CURSOR
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #6
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLE CT_86
    LDD #0
    STD RESULT
    BRA CE_87
CT_86:
    LDD #1
    STD RESULT
CE_87:
    LDD RESULT
    LBEQ IF_NEXT_85
    ; VPy_LINE:232
    LDD VAR_CURSOR
    STD RESULT
    LDX RESULT
    LDU #VAR_G_C
    STU TMPPTR
    STX ,U
    ; VPy_LINE:233
    LDD #VAR_TAB_SZ_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX RESULT
    LDU #VAR_G_SZ
    STU TMPPTR
    STX ,U
    ; VPy_LINE:234
    LDD #VAR_TAB_HID_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX RESULT
    LDU #VAR_G_HD
    STU TMPPTR
    STX ,U
    ; VPy_LINE:235
    LDD VAR_G_SZ
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_90
    LDD #0
    STD RESULT
    BRA CE_91
CT_90:
    LDD #1
    STD RESULT
CE_91:
    LDD RESULT
    BEQ AND_FALSE_92
    LDD VAR_G_SZ
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD VAR_G_HD
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_94
    LDD #0
    STD RESULT
    BRA CE_95
CT_94:
    LDD #1
    STD RESULT
CE_95:
    LDD RESULT
    BEQ AND_FALSE_92
    LDD #1
    STD RESULT
    BRA AND_END_93
AND_FALSE_92:
    LDD #0
    STD RESULT
AND_END_93:
    LDD RESULT
    LBEQ IF_NEXT_89
    ; VPy_LINE:236
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #20
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    STD MUL_A
    LDD TMPRIGHT
    STD MUL_B
    JSR MUL16
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD VAR_G_SZ
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_G_TIDX
    STU TMPPTR
    STX ,U
    ; VPy_LINE:237
    LDD #VAR_TAB_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_G_TIDX
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX RESULT
    LDU #VAR_SEL_CARD
    STU TMPPTR
    STX ,U
    ; VPy_LINE:238
    LDD VAR_CURSOR
    STD RESULT
    LDX RESULT
    LDU #VAR_SEL_SRC
    STU TMPPTR
    STX ,U
    ; VPy_LINE:239
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_TAB_SZ_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD VAR_G_SZ
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:240
    LDD #VAR_TAB_SZ_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_98
    LDD #0
    STD RESULT
    BRA CE_99
CT_98:
    LDD #1
    STD RESULT
CE_99:
    LDD RESULT
    BEQ AND_FALSE_100
    LDD #VAR_TAB_SZ_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #VAR_TAB_HID_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLE CT_102
    LDD #0
    STD RESULT
    BRA CE_103
CT_102:
    LDD #1
    STD RESULT
CE_103:
    LDD RESULT
    BEQ AND_FALSE_100
    LDD #1
    STD RESULT
    BRA AND_END_101
AND_FALSE_100:
    LDD #0
    STD RESULT
AND_END_101:
    LDD RESULT
    LBEQ IF_NEXT_97
    ; VPy_LINE:241
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_TAB_HID_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #VAR_TAB_HID_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    LBRA IF_END_96
IF_NEXT_97:
IF_END_96:
    LBRA IF_END_88
IF_NEXT_89:
IF_END_88:
    LBRA IF_END_84
IF_NEXT_85:
    LDD VAR_CURSOR
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #8
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_104
    LDD #0
    STD RESULT
    BRA CE_105
CT_104:
    LDD #1
    STD RESULT
CE_105:
    LDD RESULT
    LBEQ IF_END_84
    ; VPy_LINE:243
    LDD VAR_WST_SZ
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_108
    LDD #0
    STD RESULT
    BRA CE_109
CT_108:
    LDD #1
    STD RESULT
CE_109:
    LDD RESULT
    LBEQ IF_NEXT_107
    ; VPy_LINE:244
    LDD #VAR_WASTE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_WST_SZ
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX RESULT
    LDU #VAR_SEL_CARD
    STU TMPPTR
    STX ,U
    ; VPy_LINE:245
    LDD #8
    STD RESULT
    LDX RESULT
    LDU #VAR_SEL_SRC
    STU TMPPTR
    STX ,U
    ; VPy_LINE:246
    LDD VAR_WST_SZ
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_WST_SZ
    STU TMPPTR
    STX ,U
    LBRA IF_END_106
IF_NEXT_107:
IF_END_106:
    LBRA IF_END_84
IF_END_84:
    RTS

    ; VPy_LINE:248
DO_PLACE: ; function
; --- function do_place ---
    ; VPy_LINE:249
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_G_PLACED
    STU TMPPTR
    STX ,U
    ; VPy_LINE:250
    LDD VAR_CURSOR
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #6
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLE CT_112
    LDD #0
    STD RESULT
    BRA CE_113
CT_112:
    LDD #1
    STD RESULT
CE_113:
    LDD RESULT
    LBEQ IF_NEXT_111
    ; VPy_LINE:251
    LDD VAR_SEL_CARD
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD VAR_CURSOR
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    JSR CAN_MOVE_TO_TAB
    ; VPy_LINE:252
    LDD VAR_G_RESULT
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_116
    LDD #0
    STD RESULT
    BRA CE_117
CT_116:
    LDD #1
    STD RESULT
CE_117:
    LDD RESULT
    LBEQ IF_NEXT_115
    ; VPy_LINE:253
    LDD VAR_CURSOR
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #20
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    STD MUL_A
    LDD TMPRIGHT
    STD MUL_B
    JSR MUL16
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #VAR_TAB_SZ_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_CURSOR
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_G_TIDX
    STU TMPPTR
    STX ,U
    ; VPy_LINE:254
    LDD VAR_G_TIDX
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_TAB_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD VAR_SEL_CARD
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:255
    LDD VAR_CURSOR
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_TAB_SZ_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #VAR_TAB_SZ_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_CURSOR
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:256
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_G_PLACED
    STU TMPPTR
    STX ,U
    LBRA IF_END_114
IF_NEXT_115:
IF_END_114:
    LBRA IF_END_110
IF_NEXT_111:
    LDD VAR_CURSOR
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #9
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGE CT_118
    LDD #0
    STD RESULT
    BRA CE_119
CT_118:
    LDD #1
    STD RESULT
CE_119:
    LDD RESULT
    BEQ AND_FALSE_120
    LDD VAR_CURSOR
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #12
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLE CT_122
    LDD #0
    STD RESULT
    BRA CE_123
CT_122:
    LDD #1
    STD RESULT
CE_123:
    LDD RESULT
    BEQ AND_FALSE_120
    LDD #1
    STD RESULT
    BRA AND_END_121
AND_FALSE_120:
    LDD #0
    STD RESULT
AND_END_121:
    LDD RESULT
    LBEQ IF_END_110
    ; VPy_LINE:258
    LDD VAR_CURSOR
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #9
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_G_SUIT
    STU TMPPTR
    STX ,U
    ; VPy_LINE:259
    LDD VAR_SEL_CARD
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD VAR_G_SUIT
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    JSR CAN_MOVE_TO_FOUND
    ; VPy_LINE:260
    LDD VAR_G_RESULT
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_126
    LDD #0
    STD RESULT
    BRA CE_127
CT_126:
    LDD #1
    STD RESULT
CE_127:
    LDD RESULT
    LBEQ IF_NEXT_125
    ; VPy_LINE:261
    LDD VAR_G_SUIT
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_FOUND_CNT_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #VAR_FOUND_CNT_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_G_SUIT
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:262
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_G_PLACED
    STU TMPPTR
    STX ,U
    LBRA IF_END_124
IF_NEXT_125:
IF_END_124:
    LBRA IF_END_110
IF_END_110:
    ; VPy_LINE:264
    LDD VAR_G_PLACED
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_130
    LDD #0
    STD RESULT
    BRA CE_131
CT_130:
    LDD #1
    STD RESULT
CE_131:
    LDD RESULT
    LBEQ IF_NEXT_129
    ; VPy_LINE:265
    LDD #-1
    STD RESULT
    LDX RESULT
    LDU #VAR_SEL_CARD
    STU TMPPTR
    STX ,U
    ; VPy_LINE:266
    LDD #-1
    STD RESULT
    LDX RESULT
    LDU #VAR_SEL_SRC
    STU TMPPTR
    STX ,U
    LBRA IF_END_128
IF_NEXT_129:
    ; VPy_LINE:268
    JSR RETURN_CARD_TO_SRC
IF_END_128:
    RTS

    ; VPy_LINE:270
RETURN_CARD_TO_SRC: ; function
; --- function return_card_to_src ---
    ; VPy_LINE:271
    LDD VAR_SEL_SRC
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGE CT_134
    LDD #0
    STD RESULT
    BRA CE_135
CT_134:
    LDD #1
    STD RESULT
CE_135:
    LDD RESULT
    BEQ AND_FALSE_136
    LDD VAR_SEL_SRC
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #6
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLE CT_138
    LDD #0
    STD RESULT
    BRA CE_139
CT_138:
    LDD #1
    STD RESULT
CE_139:
    LDD RESULT
    BEQ AND_FALSE_136
    LDD #1
    STD RESULT
    BRA AND_END_137
AND_FALSE_136:
    LDD #0
    STD RESULT
AND_END_137:
    LDD RESULT
    LBEQ IF_NEXT_133
    ; VPy_LINE:272
    LDD VAR_SEL_SRC
    STD RESULT
    LDX RESULT
    LDU #VAR_G_C
    STU TMPPTR
    STX ,U
    ; VPy_LINE:273
    LDD #VAR_TAB_SZ_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_142
    LDD #0
    STD RESULT
    BRA CE_143
CT_142:
    LDD #1
    STD RESULT
CE_143:
    LDD RESULT
    BEQ AND_FALSE_144
    LDD #VAR_TAB_SZ_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #VAR_TAB_HID_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_146
    LDD #0
    STD RESULT
    BRA CE_147
CT_146:
    LDD #1
    STD RESULT
CE_147:
    LDD RESULT
    BEQ AND_FALSE_144
    LDD #1
    STD RESULT
    BRA AND_END_145
AND_FALSE_144:
    LDD #0
    STD RESULT
AND_END_145:
    LDD RESULT
    LBEQ IF_NEXT_141
    ; VPy_LINE:274
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_TAB_HID_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #VAR_TAB_HID_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    LBRA IF_END_140
IF_NEXT_141:
IF_END_140:
    ; VPy_LINE:275
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #20
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    STD MUL_A
    LDD TMPRIGHT
    STD MUL_B
    JSR MUL16
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #VAR_TAB_SZ_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_G_TIDX
    STU TMPPTR
    STX ,U
    ; VPy_LINE:276
    LDD VAR_G_TIDX
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_TAB_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD VAR_SEL_CARD
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:277
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_TAB_SZ_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #VAR_TAB_SZ_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    LBRA IF_END_132
IF_NEXT_133:
    LDD VAR_SEL_SRC
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #8
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_148
    LDD #0
    STD RESULT
    BRA CE_149
CT_148:
    LDD #1
    STD RESULT
CE_149:
    LDD RESULT
    LBEQ IF_END_132
    ; VPy_LINE:279
    LDD VAR_WST_SZ
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_WASTE_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD VAR_SEL_CARD
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:280
    LDD VAR_WST_SZ
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_WST_SZ
    STU TMPPTR
    STX ,U
    LBRA IF_END_132
IF_END_132:
    ; VPy_LINE:281
    LDD #-1
    STD RESULT
    LDX RESULT
    LDU #VAR_SEL_CARD
    STU TMPPTR
    STX ,U
    ; VPy_LINE:282
    LDD #-1
    STD RESULT
    LDX RESULT
    LDU #VAR_SEL_SRC
    STU TMPPTR
    STX ,U
    RTS

    ; VPy_LINE:287
CAN_MOVE_TO_TAB: ; function
; --- function can_move_to_tab ---
    LEAS -4,S ; allocate locals
    LDD VAR_ARG0
    STD 0,S ; param 0
    LDD VAR_ARG1
    STD 2,S ; param 1
    ; VPy_LINE:288
    LDD #VAR_TAB_SZ_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX RESULT
    LDU #VAR_G_SZ
    STU TMPPTR
    STX ,U
    ; VPy_LINE:289
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    LSRA
    RORB
    LSRA
    RORB
    STD RESULT
    LDX RESULT
    LDU #VAR_G_RANK
    STU TMPPTR
    STX ,U
    ; VPy_LINE:290
    LDD VAR_G_SZ
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_152
    LDD #0
    STD RESULT
    BRA CE_153
CT_152:
    LDD #1
    STD RESULT
CE_153:
    LDD RESULT
    LBEQ IF_NEXT_151
    ; VPy_LINE:291
    LDD VAR_G_RANK
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #12
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_156
    LDD #0
    STD RESULT
    BRA CE_157
CT_156:
    LDD #1
    STD RESULT
CE_157:
    LDD RESULT
    LBEQ IF_NEXT_155
    ; VPy_LINE:292
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_G_RESULT
    STU TMPPTR
    STX ,U
    LBRA IF_END_154
IF_NEXT_155:
    ; VPy_LINE:294
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_G_RESULT
    STU TMPPTR
    STX ,U
IF_END_154:
    ; VPy_LINE:295
    LEAS 4 ,S ; free locals
    RTS
    LBRA IF_END_150
IF_NEXT_151:
IF_END_150:
    LEAS 4,S ; free locals
    RTS

    ; VPy_LINE:315
CAN_MOVE_TO_FOUND: ; function
; --- function can_move_to_found ---
    LEAS -4,S ; allocate locals
    LDD VAR_ARG0
    STD 0,S ; param 0
    LDD VAR_ARG1
    STD 2,S ; param 1
    ; VPy_LINE:316
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    LSRA
    RORB
    LSRA
    RORB
    STD RESULT
    LDX RESULT
    LDU #VAR_G_RANK
    STU TMPPTR
    STX ,U
    ; VPy_LINE:317
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD VAR_G_RANK
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ASLB
    ROLA
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_G_SUIT
    STU TMPPTR
    STX ,U
    ; VPy_LINE:318
    LDD VAR_G_SUIT
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BNE CT_160
    LDD #0
    STD RESULT
    BRA CE_161
CT_160:
    LDD #1
    STD RESULT
CE_161:
    LDD RESULT
    LBEQ IF_NEXT_159
    ; VPy_LINE:319
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_G_RESULT
    STU TMPPTR
    STX ,U
    ; VPy_LINE:320
    LEAS 4 ,S ; free locals
    RTS
    LBRA IF_END_158
IF_NEXT_159:
IF_END_158:
    LEAS 4,S ; free locals
    RTS

    ; VPy_LINE:333
CHECK_WIN: ; function
; --- function check_win ---
    ; VPy_LINE:334
    LDD #VAR_FOUND_CNT_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD #0
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #13
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_164
    LDD #0
    STD RESULT
    BRA CE_165
CT_164:
    LDD #1
    STD RESULT
CE_165:
    LDD RESULT
    BEQ AND_FALSE_166
    LDD #VAR_FOUND_CNT_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD #1
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #13
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_168
    LDD #0
    STD RESULT
    BRA CE_169
CT_168:
    LDD #1
    STD RESULT
CE_169:
    LDD RESULT
    BEQ AND_FALSE_166
    LDD #1
    STD RESULT
    BRA AND_END_167
AND_FALSE_166:
    LDD #0
    STD RESULT
AND_END_167:
    LDD RESULT
    BEQ AND_FALSE_170
    LDD #VAR_FOUND_CNT_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD #2
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #13
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_172
    LDD #0
    STD RESULT
    BRA CE_173
CT_172:
    LDD #1
    STD RESULT
CE_173:
    LDD RESULT
    BEQ AND_FALSE_170
    LDD #1
    STD RESULT
    BRA AND_END_171
AND_FALSE_170:
    LDD #0
    STD RESULT
AND_END_171:
    LDD RESULT
    BEQ AND_FALSE_174
    LDD #VAR_FOUND_CNT_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD #3
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #13
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_176
    LDD #0
    STD RESULT
    BRA CE_177
CT_176:
    LDD #1
    STD RESULT
CE_177:
    LDD RESULT
    BEQ AND_FALSE_174
    LDD #1
    STD RESULT
    BRA AND_END_175
AND_FALSE_174:
    LDD #0
    STD RESULT
AND_END_175:
    LDD RESULT
    LBEQ IF_NEXT_163
    ; VPy_LINE:335
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_GAME_STATE
    STU TMPPTR
    STX ,U
    LBRA IF_END_162
IF_NEXT_163:
IF_END_162:
    RTS

    ; VPy_LINE:340
DRAW_TABLE: ; function
; --- function draw_table ---
    ; VPy_LINE:341
    JSR DRAW_STOCK
    ; VPy_LINE:342
    JSR DRAW_WASTE
    ; VPy_LINE:343
    JSR DRAW_FOUNDATIONS
    ; VPy_LINE:344
    JSR DRAW_TABLEAU
    ; VPy_LINE:345
    JSR DRAW_HELD_LABEL
    ; VPy_LINE:346
    JSR DRAW_CURSOR
    RTS

    ; VPy_LINE:348
GET_COL_X: ; function
; --- function get_col_x ---
    LEAS -2,S ; allocate locals
    LDD VAR_ARG0
    STD 0,S ; param 0
    ; VPy_LINE:349
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_180
    LDD #0
    STD RESULT
    BRA CE_181
CT_180:
    LDD #1
    STD RESULT
CE_181:
    LDD RESULT
    LBEQ IF_NEXT_179
    ; VPy_LINE:350
    LDD #-102
    STD RESULT
    LDX RESULT
    LDU #VAR_G_COL_X
    STU TMPPTR
    STX ,U
    LBRA IF_END_178
IF_NEXT_179:
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_183
    LDD #0
    STD RESULT
    BRA CE_184
CT_183:
    LDD #1
    STD RESULT
CE_184:
    LDD RESULT
    LBEQ IF_NEXT_182
    ; VPy_LINE:352
    LDD #-68
    STD RESULT
    LDX RESULT
    LDU #VAR_G_COL_X
    STU TMPPTR
    STX ,U
    LBRA IF_END_178
IF_NEXT_182:
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_186
    LDD #0
    STD RESULT
    BRA CE_187
CT_186:
    LDD #1
    STD RESULT
CE_187:
    LDD RESULT
    LBEQ IF_NEXT_185
    ; VPy_LINE:354
    LDD #-34
    STD RESULT
    LDX RESULT
    LDU #VAR_G_COL_X
    STU TMPPTR
    STX ,U
    LBRA IF_END_178
IF_NEXT_185:
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_189
    LDD #0
    STD RESULT
    BRA CE_190
CT_189:
    LDD #1
    STD RESULT
CE_190:
    LDD RESULT
    LBEQ IF_NEXT_188
    ; VPy_LINE:356
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_G_COL_X
    STU TMPPTR
    STX ,U
    LBRA IF_END_178
IF_NEXT_188:
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #4
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_192
    LDD #0
    STD RESULT
    BRA CE_193
CT_192:
    LDD #1
    STD RESULT
CE_193:
    LDD RESULT
    LBEQ IF_NEXT_191
    ; VPy_LINE:358
    LDD #34
    STD RESULT
    LDX RESULT
    LDU #VAR_G_COL_X
    STU TMPPTR
    STX ,U
    LBRA IF_END_178
IF_NEXT_191:
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #5
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_195
    LDD #0
    STD RESULT
    BRA CE_196
CT_195:
    LDD #1
    STD RESULT
CE_196:
    LDD RESULT
    LBEQ IF_NEXT_194
    ; VPy_LINE:360
    LDD #68
    STD RESULT
    LDX RESULT
    LDU #VAR_G_COL_X
    STU TMPPTR
    STX ,U
    LBRA IF_END_178
IF_NEXT_194:
    ; VPy_LINE:362
    LDD #102
    STD RESULT
    LDX RESULT
    LDU #VAR_G_COL_X
    STU TMPPTR
    STX ,U
IF_END_178:
    LEAS 2,S ; free locals
    RTS

    ; VPy_LINE:364
DRAW_STOCK: ; function
; --- function draw_stock ---
    ; VPy_LINE:365
    LDD VAR_STK_SZ
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_199
    LDD #0
    STD RESULT
    BRA CE_200
CT_199:
    LDD #1
    STD RESULT
CE_200:
    LDD RESULT
    LBEQ IF_NEXT_198
    ; VPy_LINE:366
    ; DRAW_RECT with variables not yet implemented in core
    LDD #0
    STD RESULT
    ; VPy_LINE:367
    LDD #40
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 367
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:368
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-102
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #4
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #85
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #10
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_0
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 368
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_197
IF_NEXT_198:
    ; VPy_LINE:370
    ; DRAW_RECT with variables not yet implemented in core
    LDD #0
    STD RESULT
    ; VPy_LINE:371
    LDD #25
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 371
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:372
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-102
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #4
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #85
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #10
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_19
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 372
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
IF_END_197:
    RTS

    ; VPy_LINE:374
DRAW_WASTE: ; function
; --- function draw_waste ---
    ; VPy_LINE:375
    LDD VAR_WST_SZ
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_203
    LDD #0
    STD RESULT
    BRA CE_204
CT_203:
    LDD #1
    STD RESULT
CE_204:
    LDD RESULT
    LBEQ IF_NEXT_202
    ; VPy_LINE:376
    LDD #VAR_WASTE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_WST_SZ
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX RESULT
    LDU #VAR_G_WCARD
    STU TMPPTR
    STX ,U
    ; VPy_LINE:377
    LDD #-68
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #85
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDD VAR_G_WCARD
    STD RESULT
    LDD RESULT
    STD VAR_ARG2
    LDD #70
    STD RESULT
    LDD RESULT
    STD VAR_ARG3
    JSR DRAW_CARD
    LBRA IF_END_201
IF_NEXT_202:
    ; VPy_LINE:379
    ; DRAW_RECT with variables not yet implemented in core
    LDD #0
    STD RESULT
    ; VPy_LINE:380
    LDD #25
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 380
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:381
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-68
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #4
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #85
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #10
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_20
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 381
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
IF_END_201:
    RTS

    ; VPy_LINE:383
DRAW_FOUNDATIONS: ; function
; --- function draw_foundations ---
    ; VPy_LINE:384
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_G_FX
    STU TMPPTR
    STX ,U
    ; VPy_LINE:385
    LDD VAR_G_FX
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    JSR DRAW_ONE_FOUNDATION
    ; VPy_LINE:386
    LDD #34
    STD RESULT
    LDX RESULT
    LDU #VAR_G_FX
    STU TMPPTR
    STX ,U
    ; VPy_LINE:387
    LDD VAR_G_FX
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    JSR DRAW_ONE_FOUNDATION
    ; VPy_LINE:388
    LDD #68
    STD RESULT
    LDX RESULT
    LDU #VAR_G_FX
    STU TMPPTR
    STX ,U
    ; VPy_LINE:389
    LDD VAR_G_FX
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #2
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    JSR DRAW_ONE_FOUNDATION
    ; VPy_LINE:390
    LDD #102
    STD RESULT
    LDX RESULT
    LDU #VAR_G_FX
    STU TMPPTR
    STX ,U
    ; VPy_LINE:391
    LDD VAR_G_FX
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #3
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    JSR DRAW_ONE_FOUNDATION
    RTS

    ; VPy_LINE:393
DRAW_ONE_FOUNDATION: ; function
; --- function draw_one_foundation ---
    LEAS -4,S ; allocate locals
    LDD VAR_ARG0
    STD 0,S ; param 0
    LDD VAR_ARG1
    STD 2,S ; param 1
    ; VPy_LINE:394
    LDD #VAR_FOUND_CNT_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX RESULT
    LDU #VAR_G_FC
    STU TMPPTR
    STX ,U
    ; VPy_LINE:395
    LDD VAR_G_FC
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_207
    LDD #0
    STD RESULT
    BRA CE_208
CT_207:
    LDD #1
    STD RESULT
CE_208:
    LDD RESULT
    LBEQ IF_NEXT_206
    ; VPy_LINE:396
    ; DRAW_RECT with variables not yet implemented in core
    LDD #0
    STD RESULT
    ; VPy_LINE:397
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #13
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #85
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #13
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG2
    JSR DRAW_SUIT_AT
    LBRA IF_END_205
IF_NEXT_206:
    ; VPy_LINE:399
    LDD VAR_G_FC
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_G_RANK
    STU TMPPTR
    STX ,U
    ; VPy_LINE:400
    LDD VAR_G_RANK
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ASLB
    ROLA
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_G_CARD
    STU TMPPTR
    STX ,U
    ; VPy_LINE:401
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #85
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDD VAR_G_CARD
    STD RESULT
    LDD RESULT
    STD VAR_ARG2
    LDD #70
    STD RESULT
    LDD RESULT
    STD VAR_ARG3
    JSR DRAW_CARD
IF_END_205:
    LEAS 4,S ; free locals
    RTS

    ; VPy_LINE:403
DRAW_TABLEAU: ; function
; --- function draw_tableau ---
    ; VPy_LINE:404
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_G_C
    STU TMPPTR
    STX ,U
    ; VPy_LINE:405
WH_209: ; while start
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #7
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_211
    LDD #0
    STD RESULT
    BRA CE_212
CT_211:
    LDD #1
    STD RESULT
CE_212:
    LDD RESULT
    LBEQ WH_END_210
    ; VPy_LINE:406
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    JSR GET_COL_X
    ; VPy_LINE:407
    LDD VAR_G_COL_X
    STD RESULT
    LDX RESULT
    LDU #VAR_G_CX
    STU TMPPTR
    STX ,U
    ; VPy_LINE:408
    LDD #VAR_TAB_SZ_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX RESULT
    LDU #VAR_G_SZ
    STU TMPPTR
    STX ,U
    ; VPy_LINE:409
    LDD #VAR_TAB_HID_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX RESULT
    LDU #VAR_G_HD
    STU TMPPTR
    STX ,U
    ; VPy_LINE:410
    LDD VAR_G_SZ
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_215
    LDD #0
    STD RESULT
    BRA CE_216
CT_215:
    LDD #1
    STD RESULT
CE_216:
    LDD RESULT
    LBEQ IF_NEXT_214
    ; VPy_LINE:411
    ; DRAW_RECT with variables not yet implemented in core
    LDD #0
    STD RESULT
    LBRA IF_END_213
IF_NEXT_214:
    ; VPy_LINE:414
    LDD VAR_G_HD
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_219
    LDD #0
    STD RESULT
    BRA CE_220
CT_219:
    LDD #1
    STD RESULT
CE_220:
    LDD RESULT
    LBEQ IF_NEXT_218
    ; VPy_LINE:415
    ; DRAW_RECT with variables not yet implemented in core
    LDD #0
    STD RESULT
    ; VPy_LINE:416
    ; DRAW_RECT with variables not yet implemented in core
    LDD #0
    STD RESULT
    LBRA IF_END_217
IF_NEXT_218:
IF_END_217:
    ; VPy_LINE:418
    LDD VAR_G_HD
    STD RESULT
    LDX RESULT
    LDU #VAR_G_ROW
    STU TMPPTR
    STX ,U
    ; VPy_LINE:419
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_G_IDX
    STU TMPPTR
    STX ,U
    ; VPy_LINE:420
WH_221: ; while start
    LDD VAR_G_ROW
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD VAR_G_SZ
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_223
    LDD #0
    STD RESULT
    BRA CE_224
CT_223:
    LDD #1
    STD RESULT
CE_224:
    LDD RESULT
    BEQ AND_FALSE_225
    LDD VAR_G_IDX
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #4
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_227
    LDD #0
    STD RESULT
    BRA CE_228
CT_227:
    LDD #1
    STD RESULT
CE_228:
    LDD RESULT
    BEQ AND_FALSE_225
    LDD #1
    STD RESULT
    BRA AND_END_226
AND_FALSE_225:
    LDD #0
    STD RESULT
AND_END_226:
    LDD RESULT
    LBEQ WH_END_222
    ; VPy_LINE:421
    LDD VAR_G_HD
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_231
    LDD #0
    STD RESULT
    BRA CE_232
CT_231:
    LDD #1
    STD RESULT
CE_232:
    LDD RESULT
    LBEQ IF_NEXT_230
    ; VPy_LINE:422
    CLRA
    CLRB
    STD RESULT
    LDX RESULT
    LDU #VAR_G_CY
    STU TMPPTR
    STX ,U
    LBRA IF_END_229
IF_NEXT_230:
    ; VPy_LINE:424
    LDD #30
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD VAR_G_ROW
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD VAR_G_HD
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #14
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    STD MUL_A
    LDD TMPRIGHT
    STD MUL_B
    JSR MUL16
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_G_CY
    STU TMPPTR
    STX ,U
IF_END_229:
    ; VPy_LINE:425
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #20
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    STD MUL_A
    LDD TMPRIGHT
    STD MUL_B
    JSR MUL16
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD VAR_G_ROW
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_G_TIDX
    STU TMPPTR
    STX ,U
    ; VPy_LINE:426
    LDD #VAR_TAB_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_G_TIDX
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX RESULT
    LDU #VAR_G_CARD
    STU TMPPTR
    STX ,U
    ; VPy_LINE:427
    LDD VAR_G_CX
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD VAR_G_CY
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDD VAR_G_CARD
    STD RESULT
    LDD RESULT
    STD VAR_ARG2
    LDD #70
    STD RESULT
    LDD RESULT
    STD VAR_ARG3
    JSR DRAW_CARD
    ; VPy_LINE:428
    LDD VAR_G_ROW
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_G_ROW
    STU TMPPTR
    STX ,U
    ; VPy_LINE:429
    LDD VAR_G_IDX
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_G_IDX
    STU TMPPTR
    STX ,U
    LBRA WH_221
WH_END_222: ; while end
IF_END_213:
    ; VPy_LINE:430
    LDD VAR_G_C
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_G_C
    STU TMPPTR
    STX ,U
    LBRA WH_209
WH_END_210: ; while end
    RTS

    ; VPy_LINE:432
DRAW_HELD_LABEL: ; function
; --- function draw_held_label ---
    ; VPy_LINE:433
    LDD VAR_SEL_CARD
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BNE CT_235
    LDD #0
    STD RESULT
    BRA CE_236
CT_235:
    LDD #1
    STD RESULT
CE_236:
    LDD RESULT
    LBEQ IF_NEXT_234
    ; VPy_LINE:434
    LDD #100
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 434
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:435
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-60
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-100
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_14
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 435
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:436
    LDD VAR_SEL_CARD
    STD RESULT
    LDD RESULT
    LSRA
    RORB
    LSRA
    RORB
    STD RESULT
    LDX RESULT
    LDU #VAR_G_RANK
    STU TMPPTR
    STX ,U
    ; VPy_LINE:437
    LDD VAR_SEL_CARD
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD VAR_G_RANK
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ASLB
    ROLA
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_G_SUIT
    STU TMPPTR
    STX ,U
    ; VPy_LINE:438
    LDD #-15
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-100
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDD VAR_G_RANK
    STD RESULT
    LDD RESULT
    STD VAR_ARG2
    JSR DRAW_RANK_AT
    ; VPy_LINE:439
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-100
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDD VAR_G_SUIT
    STD RESULT
    LDD RESULT
    STD VAR_ARG2
    JSR DRAW_SUIT_AT
    LBRA IF_END_233
IF_NEXT_234:
IF_END_233:
    RTS

    ; VPy_LINE:441
DRAW_CURSOR: ; function
; --- function draw_cursor ---
    ; VPy_LINE:442
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_G_CX
    STU TMPPTR
    STX ,U
    ; VPy_LINE:443
    LDD #85
    STD RESULT
    LDX RESULT
    LDU #VAR_G_CY
    STU TMPPTR
    STX ,U
    ; VPy_LINE:444
    LDD VAR_CURSOR
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #7
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_239
    LDD #0
    STD RESULT
    BRA CE_240
CT_239:
    LDD #1
    STD RESULT
CE_240:
    LDD RESULT
    LBEQ IF_NEXT_238
    ; VPy_LINE:445
    LDD #-102
    STD RESULT
    LDX RESULT
    LDU #VAR_G_CX
    STU TMPPTR
    STX ,U
    LBRA IF_END_237
IF_NEXT_238:
    LDD VAR_CURSOR
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #8
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_242
    LDD #0
    STD RESULT
    BRA CE_243
CT_242:
    LDD #1
    STD RESULT
CE_243:
    LDD RESULT
    LBEQ IF_NEXT_241
    ; VPy_LINE:447
    LDD #-68
    STD RESULT
    LDX RESULT
    LDU #VAR_G_CX
    STU TMPPTR
    STX ,U
    LBRA IF_END_237
IF_NEXT_241:
    LDD VAR_CURSOR
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #9
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_245
    LDD #0
    STD RESULT
    BRA CE_246
CT_245:
    LDD #1
    STD RESULT
CE_246:
    LDD RESULT
    LBEQ IF_NEXT_244
    ; VPy_LINE:449
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_G_CX
    STU TMPPTR
    STX ,U
    LBRA IF_END_237
IF_NEXT_244:
    LDD VAR_CURSOR
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #10
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_248
    LDD #0
    STD RESULT
    BRA CE_249
CT_248:
    LDD #1
    STD RESULT
CE_249:
    LDD RESULT
    LBEQ IF_NEXT_247
    ; VPy_LINE:451
    LDD #34
    STD RESULT
    LDX RESULT
    LDU #VAR_G_CX
    STU TMPPTR
    STX ,U
    LBRA IF_END_237
IF_NEXT_247:
    LDD VAR_CURSOR
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #11
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_251
    LDD #0
    STD RESULT
    BRA CE_252
CT_251:
    LDD #1
    STD RESULT
CE_252:
    LDD RESULT
    LBEQ IF_NEXT_250
    ; VPy_LINE:453
    LDD #68
    STD RESULT
    LDX RESULT
    LDU #VAR_G_CX
    STU TMPPTR
    STX ,U
    LBRA IF_END_237
IF_NEXT_250:
    LDD VAR_CURSOR
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #12
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_254
    LDD #0
    STD RESULT
    BRA CE_255
CT_254:
    LDD #1
    STD RESULT
CE_255:
    LDD RESULT
    LBEQ IF_NEXT_253
    ; VPy_LINE:455
    LDD #102
    STD RESULT
    LDX RESULT
    LDU #VAR_G_CX
    STU TMPPTR
    STX ,U
    LBRA IF_END_237
IF_NEXT_253:
    ; VPy_LINE:457
    LDD VAR_CURSOR
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    JSR GET_COL_X
    ; VPy_LINE:458
    LDD VAR_G_COL_X
    STD RESULT
    LDX RESULT
    LDU #VAR_G_CX
    STU TMPPTR
    STX ,U
    ; VPy_LINE:459
    LDD #VAR_TAB_SZ_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_CURSOR
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX RESULT
    LDU #VAR_G_SZ
    STU TMPPTR
    STX ,U
    ; VPy_LINE:460
    LDD #VAR_TAB_HID_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD VAR_CURSOR
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX RESULT
    LDU #VAR_G_HD
    STU TMPPTR
    STX ,U
    ; VPy_LINE:461
    LDD VAR_G_SZ
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_258
    LDD #0
    STD RESULT
    BRA CE_259
CT_258:
    LDD #1
    STD RESULT
CE_259:
    LDD RESULT
    LBEQ IF_NEXT_257
    ; VPy_LINE:462
    LDD #30
    STD RESULT
    LDX RESULT
    LDU #VAR_G_CY
    STU TMPPTR
    STX ,U
    LBRA IF_END_256
IF_NEXT_257:
    LDD VAR_G_HD
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_261
    LDD #0
    STD RESULT
    BRA CE_262
CT_261:
    LDD #1
    STD RESULT
CE_262:
    LDD RESULT
    LBEQ IF_NEXT_260
    ; VPy_LINE:464
    LDD #30
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD VAR_G_SZ
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #14
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    STD MUL_A
    LDD TMPRIGHT
    STD MUL_B
    JSR MUL16
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_G_CY
    STU TMPPTR
    STX ,U
    LBRA IF_END_256
IF_NEXT_260:
    ; VPy_LINE:466
    CLRA
    CLRB
    STD RESULT
    LDX RESULT
    LDU #VAR_G_CY
    STU TMPPTR
    STX ,U
IF_END_256:
IF_END_237:
    ; VPy_LINE:467
    LDD #127
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 467
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:468
    ; DRAW_RECT with variables not yet implemented in core
    LDD #0
    STD RESULT
    RTS

    ; VPy_LINE:471
DRAW_CARD: ; function
; --- function draw_card ---
    LEAS -8,S ; allocate locals
    LDD VAR_ARG0
    STD 0,S ; param 0
    LDD VAR_ARG1
    STD 2,S ; param 1
    LDD VAR_ARG2
    STD 4,S ; param 2
    LDD VAR_ARG3
    STD 6,S ; param 3
    ; VPy_LINE:472
    ; DRAW_RECT with variables not yet implemented in core
    LDD #0
    STD RESULT
    ; VPy_LINE:473
    LDD 6 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 473
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:474
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    LSRA
    RORB
    LSRA
    RORB
    STD RESULT
    LDX RESULT
    LDU #VAR_G_RANK
    STU TMPPTR
    STX ,U
    ; VPy_LINE:475
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD VAR_G_RANK
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ASLB
    ROLA
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_G_SUIT
    STU TMPPTR
    STX ,U
    ; VPy_LINE:476
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #26
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDD VAR_G_RANK
    STD RESULT
    LDD RESULT
    STD VAR_ARG2
    JSR DRAW_RANK_AT
    ; VPy_LINE:477
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #13
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #12
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDD VAR_G_SUIT
    STD RESULT
    LDD RESULT
    STD VAR_ARG2
    JSR DRAW_SUIT_AT
    LEAS 8,S ; free locals
    RTS

    ; VPy_LINE:479
DRAW_SMALL_COUNT: ; function
; --- function draw_small_count ---
    LEAS -6,S ; allocate locals
    LDD VAR_ARG0
    STD 0,S ; param 0
    LDD VAR_ARG1
    STD 2,S ; param 1
    LDD VAR_ARG2
    STD 4,S ; param 2
    ; VPy_LINE:480
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_265
    LDD #0
    STD RESULT
    BRA CE_266
CT_265:
    LDD #1
    STD RESULT
CE_266:
    LDD RESULT
    LBEQ IF_NEXT_264
    ; VPy_LINE:481
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_2
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 481
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_263
IF_NEXT_264:
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_268
    LDD #0
    STD RESULT
    BRA CE_269
CT_268:
    LDD #1
    STD RESULT
CE_269:
    LDD RESULT
    LBEQ IF_NEXT_267
    ; VPy_LINE:483
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_4
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 483
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_263
IF_NEXT_267:
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_271
    LDD #0
    STD RESULT
    BRA CE_272
CT_271:
    LDD #1
    STD RESULT
CE_272:
    LDD RESULT
    LBEQ IF_NEXT_270
    ; VPy_LINE:485
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_5
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 485
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_263
IF_NEXT_270:
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #4
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_274
    LDD #0
    STD RESULT
    BRA CE_275
CT_274:
    LDD #1
    STD RESULT
CE_275:
    LDD RESULT
    LBEQ IF_NEXT_273
    ; VPy_LINE:487
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_6
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 487
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_263
IF_NEXT_273:
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #5
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_277
    LDD #0
    STD RESULT
    BRA CE_278
CT_277:
    LDD #1
    STD RESULT
CE_278:
    LDD RESULT
    LBEQ IF_NEXT_276
    ; VPy_LINE:489
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_7
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 489
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_263
IF_NEXT_276:
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #6
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_280
    LDD #0
    STD RESULT
    BRA CE_281
CT_280:
    LDD #1
    STD RESULT
CE_281:
    LDD RESULT
    LBEQ IF_NEXT_279
    ; VPy_LINE:491
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_8
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 491
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_263
IF_NEXT_279:
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #7
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_283
    LDD #0
    STD RESULT
    BRA CE_284
CT_283:
    LDD #1
    STD RESULT
CE_284:
    LDD RESULT
    LBEQ IF_NEXT_282
    ; VPy_LINE:493
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_9
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 493
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_263
IF_NEXT_282:
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #8
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_286
    LDD #0
    STD RESULT
    BRA CE_287
CT_286:
    LDD #1
    STD RESULT
CE_287:
    LDD RESULT
    LBEQ IF_NEXT_285
    ; VPy_LINE:495
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_10
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 495
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_263
IF_NEXT_285:
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #9
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_289
    LDD #0
    STD RESULT
    BRA CE_290
CT_289:
    LDD #1
    STD RESULT
CE_290:
    LDD RESULT
    LBEQ IF_NEXT_288
    ; VPy_LINE:497
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_11
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 497
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_263
IF_NEXT_288:
    ; VPy_LINE:499
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_1
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 499
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
IF_END_263:
    LEAS 6,S ; free locals
    RTS

    ; VPy_LINE:501
DRAW_RANK_AT: ; function
; --- function draw_rank_at ---
    LEAS -6,S ; allocate locals
    LDD VAR_ARG0
    STD 0,S ; param 0
    LDD VAR_ARG1
    STD 2,S ; param 1
    LDD VAR_ARG2
    STD 4,S ; param 2
    ; VPy_LINE:502
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_293
    LDD #0
    STD RESULT
    BRA CE_294
CT_293:
    LDD #1
    STD RESULT
CE_294:
    LDD RESULT
    LBEQ IF_NEXT_292
    ; VPy_LINE:503
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_12
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 503
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_291
IF_NEXT_292:
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_296
    LDD #0
    STD RESULT
    BRA CE_297
CT_296:
    LDD #1
    STD RESULT
CE_297:
    LDD RESULT
    LBEQ IF_NEXT_295
    ; VPy_LINE:505
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_4
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 505
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_291
IF_NEXT_295:
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_299
    LDD #0
    STD RESULT
    BRA CE_300
CT_299:
    LDD #1
    STD RESULT
CE_300:
    LDD RESULT
    LBEQ IF_NEXT_298
    ; VPy_LINE:507
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_5
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 507
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_291
IF_NEXT_298:
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_302
    LDD #0
    STD RESULT
    BRA CE_303
CT_302:
    LDD #1
    STD RESULT
CE_303:
    LDD RESULT
    LBEQ IF_NEXT_301
    ; VPy_LINE:509
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_6
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 509
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_291
IF_NEXT_301:
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #4
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_305
    LDD #0
    STD RESULT
    BRA CE_306
CT_305:
    LDD #1
    STD RESULT
CE_306:
    LDD RESULT
    LBEQ IF_NEXT_304
    ; VPy_LINE:511
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_7
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 511
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_291
IF_NEXT_304:
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #5
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_308
    LDD #0
    STD RESULT
    BRA CE_309
CT_308:
    LDD #1
    STD RESULT
CE_309:
    LDD RESULT
    LBEQ IF_NEXT_307
    ; VPy_LINE:513
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_8
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 513
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_291
IF_NEXT_307:
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #6
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_311
    LDD #0
    STD RESULT
    BRA CE_312
CT_311:
    LDD #1
    STD RESULT
CE_312:
    LDD RESULT
    LBEQ IF_NEXT_310
    ; VPy_LINE:515
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_9
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 515
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_291
IF_NEXT_310:
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #7
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_314
    LDD #0
    STD RESULT
    BRA CE_315
CT_314:
    LDD #1
    STD RESULT
CE_315:
    LDD RESULT
    LBEQ IF_NEXT_313
    ; VPy_LINE:517
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_10
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 517
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_291
IF_NEXT_313:
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #8
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_317
    LDD #0
    STD RESULT
    BRA CE_318
CT_317:
    LDD #1
    STD RESULT
CE_318:
    LDD RESULT
    LBEQ IF_NEXT_316
    ; VPy_LINE:519
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_11
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 519
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_291
IF_NEXT_316:
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #9
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_320
    LDD #0
    STD RESULT
    BRA CE_321
CT_320:
    LDD #1
    STD RESULT
CE_321:
    LDD RESULT
    LBEQ IF_NEXT_319
    ; VPy_LINE:521
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_3
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 521
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_291
IF_NEXT_319:
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #10
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_323
    LDD #0
    STD RESULT
    BRA CE_324
CT_323:
    LDD #1
    STD RESULT
CE_324:
    LDD RESULT
    LBEQ IF_NEXT_322
    ; VPy_LINE:523
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_15
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 523
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_291
IF_NEXT_322:
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #11
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_326
    LDD #0
    STD RESULT
    BRA CE_327
CT_326:
    LDD #1
    STD RESULT
CE_327:
    LDD RESULT
    LBEQ IF_NEXT_325
    ; VPy_LINE:525
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_18
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 525
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_291
IF_NEXT_325:
    ; VPy_LINE:527
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_16
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 527
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
IF_END_291:
    LEAS 6,S ; free locals
    RTS

    ; VPy_LINE:529
DRAW_SUIT_AT: ; function
; --- function draw_suit_at ---
    LEAS -6,S ; allocate locals
    LDD VAR_ARG0
    STD 0,S ; param 0
    LDD VAR_ARG1
    STD 2,S ; param 1
    LDD VAR_ARG2
    STD 4,S ; param 2
    ; VPy_LINE:530
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_330
    LDD #0
    STD RESULT
    BRA CE_331
CT_330:
    LDD #1
    STD RESULT
CE_331:
    LDD RESULT
    LBEQ IF_NEXT_329
    ; VPy_LINE:531
; DRAW_VECTOR("suit_clubs", x, y) - 5 path(s) at position
    LDD 0 ,S
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD 2 ,S
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_SUIT_CLUBS_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_SUIT_CLUBS_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_SUIT_CLUBS_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_SUIT_CLUBS_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_SUIT_CLUBS_PATH4  ; Path 4
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_328
IF_NEXT_329:
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_333
    LDD #0
    STD RESULT
    BRA CE_334
CT_333:
    LDD #1
    STD RESULT
CE_334:
    LDD RESULT
    LBEQ IF_NEXT_332
    ; VPy_LINE:533
; DRAW_VECTOR("suit_diamonds", x, y) - 1 path(s) at position
    LDD 0 ,S
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD 2 ,S
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_SUIT_DIAMONDS_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_328
IF_NEXT_332:
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_336
    LDD #0
    STD RESULT
    BRA CE_337
CT_336:
    LDD #1
    STD RESULT
CE_337:
    LDD RESULT
    LBEQ IF_NEXT_335
    ; VPy_LINE:535
; DRAW_VECTOR("suit_hearts", x, y) - 1 path(s) at position
    LDD 0 ,S
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD 2 ,S
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_SUIT_HEARTS_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_328
IF_NEXT_335:
    ; VPy_LINE:537
; DRAW_VECTOR("suit_spades", x, y) - 3 path(s) at position
    LDD 0 ,S
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD 2 ,S
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_SUIT_SPADES_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_SUIT_SPADES_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_SUIT_SPADES_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
IF_END_328:
    LEAS 6,S ; free locals
    RTS

    ; VPy_LINE:540
DRAW_WIN_SCREEN: ; function
; --- function draw_win_screen ---
    ; VPy_LINE:541
    LDD VAR_WIN_BLINK
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_WIN_BLINK
    STU TMPPTR
    STX ,U
    ; VPy_LINE:542
    LDD #127
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 542
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:543
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-42
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #30
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_21
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 543
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:544
    LDD #80
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 544
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:545
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-63
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_13
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 545
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:546
    LDD VAR_WIN_BLINK
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #30
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_340
    LDD #0
    STD RESULT
    BRA CE_341
CT_340:
    LDD #1
    STD RESULT
CE_341:
    LDD RESULT
    LBEQ IF_NEXT_339
    ; VPy_LINE:547
    LDD #60
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 547
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:548
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-63
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-30
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_17
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 548
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_338
IF_NEXT_339:
IF_END_338:
    ; VPy_LINE:549
    LDD VAR_WIN_BLINK
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #60
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGE CT_344
    LDD #0
    STD RESULT
    BRA CE_345
CT_344:
    LDD #1
    STD RESULT
CE_345:
    LDD RESULT
    LBEQ IF_NEXT_343
    ; VPy_LINE:550
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_WIN_BLINK
    STU TMPPTR
    STX ,U
    LBRA IF_END_342
IF_NEXT_343:
IF_END_342:
    ; VPy_LINE:551
    LDD VAR_BTN1_FIRE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_348
    LDD #0
    STD RESULT
    BRA CE_349
CT_348:
    LDD #1
    STD RESULT
CE_349:
    LDD RESULT
    LBEQ IF_NEXT_347
    ; VPy_LINE:552
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_GAME_STATE
    STU TMPPTR
    STX ,U
    ; VPy_LINE:553
    JSR SHUFFLE
    ; VPy_LINE:554
    JSR DEAL
    LBRA IF_END_346
IF_NEXT_347:
IF_END_346:
    RTS

MUL16:
    LDD MUL_A
    BPL MUL16_APOS
    COMA
    COMB
    ADDD #1
    STD MUL_A
    LDA #1
    STA TMPPTR2+1
    BRA MUL16_BCHECK
MUL16_APOS:
    LDA #0
    STA TMPPTR2+1
MUL16_BCHECK:
    LDD MUL_B
    BPL MUL16_BPOS
    COMA
    COMB
    ADDD #1
    STD MUL_B
    LDA TMPPTR2+1
    EORA #1
    STA TMPPTR2+1
MUL16_BPOS:
    LDD MUL_A
    STD MUL_RES
    LDD #0
    STD MUL_TMP
    LDD MUL_B
    STD MUL_CNT
MUL16_LOOP:
    LDD MUL_CNT
    BEQ MUL16_DONE
    LDD MUL_CNT
    ANDB #1
    BEQ MUL16_SKIP
    LDD MUL_RES
    ADDD MUL_TMP
    STD MUL_TMP
MUL16_SKIP:
    LDD MUL_RES
    ASLB
    ROLA
    STD MUL_RES
    LDD MUL_CNT
    LSRA
    RORB
    STD MUL_CNT
    BRA MUL16_LOOP
MUL16_DONE:
    LDD MUL_TMP
    LDA TMPPTR2+1
    BEQ MUL16_STORE
    COMA
    COMB
    ADDD #1
MUL16_STORE:
    STD RESULT
    RTS

DIV16:
    LDD #0
    STD DIV_Q
    LDD DIV_A
    BPL DIV16_DPOS
    COMA
    COMB
    ADDD #1
    STD DIV_R
    LDA #1
    STA TMPPTR2+1
    BRA DIV16_RCHECK
DIV16_DPOS:
    STD DIV_R
    LDA #0
    STA TMPPTR2+1
DIV16_RCHECK:
    LDD DIV_B
    BEQ DIV16_DONE
    BPL DIV16_RPOS
    COMA
    COMB
    ADDD #1
    STD TMPPTR
    LDA TMPPTR2+1
    EORA #1
    STA TMPPTR2+1
    BRA DIV16_LOOP
DIV16_RPOS:
    STD TMPPTR
DIV16_LOOP:
    LDD DIV_R
    SUBD TMPPTR
    BLO DIV16_DONE
    STD DIV_R
    LDD DIV_Q
    ADDD #1
    STD DIV_Q
    BRA DIV16_LOOP
DIV16_DONE:
    LDD DIV_Q
    LDA TMPPTR2+1
    BEQ DIV16_STORE
    COMA
    COMB
    ADDD #1
DIV16_STORE:
    STD RESULT
    RTS

;***************************************************************************
; DATA SECTION
;***************************************************************************

; ========================================
; ASSET DATA SECTION
; Embedded 4 of 4 assets (unused assets excluded)
; ========================================

; Vector asset: suit_spades
; Generated from suit_spades.vec (Malban Draw_Sync_List format)
; Total paths: 3, points: 14
; X bounds: min=-6, max=6, width=12
; Center: (0, 0)

_SUIT_SPADES_WIDTH EQU 12
_SUIT_SPADES_CENTER_X EQU 0
_SUIT_SPADES_CENTER_Y EQU 0

_SUIT_SPADES_VECTORS:  ; Main entry (header + 3 path(s))
    FCB 3               ; path_count (runtime metadata)
    FDB _SUIT_SPADES_PATH0        ; pointer to path 0
    FDB _SUIT_SPADES_PATH1        ; pointer to path 1
    FDB _SUIT_SPADES_PATH2        ; pointer to path 2

_SUIT_SPADES_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $07,$00,0,0        ; path0: header (y=7, x=0, relative to center)
    FCB $FF,$FB,$05          ; flag=-1, dy=-5, dx=5
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$FC,$FE          ; flag=-1, dy=-4, dx=-2
    FCB $FF,$FF,$FD          ; flag=-1, dy=-1, dx=-3
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB $FF,$04,$FE          ; flag=-1, dy=4, dx=-2
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$05,$05          ; flag=-1, dy=5, dx=5
    FCB 2                ; End marker (path complete)

_SUIT_SPADES_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $FC,$00,0,0        ; path1: header (y=-4, x=0, relative to center)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_SUIT_SPADES_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $F9,$FD,0,0        ; path2: header (y=-7, x=-3, relative to center)
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB 2                ; End marker (path complete)

; Vector asset: suit_clubs
; Generated from suit_clubs.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 22
; X bounds: min=-5, max=5, width=10
; Center: (0, 0)

_SUIT_CLUBS_WIDTH EQU 10
_SUIT_CLUBS_CENTER_X EQU 0
_SUIT_CLUBS_CENTER_Y EQU 0

_SUIT_CLUBS_VECTORS:  ; Main entry (header + 5 path(s))
    FCB 5               ; path_count (runtime metadata)
    FDB _SUIT_CLUBS_PATH0        ; pointer to path 0
    FDB _SUIT_CLUBS_PATH1        ; pointer to path 1
    FDB _SUIT_CLUBS_PATH2        ; pointer to path 2
    FDB _SUIT_CLUBS_PATH3        ; pointer to path 3
    FDB _SUIT_CLUBS_PATH4        ; pointer to path 4

_SUIT_CLUBS_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $04,$02,0,0        ; path0: header (y=4, x=2, relative to center)
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB 2                ; End marker (path complete)

_SUIT_CLUBS_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $01,$FF,0,0        ; path1: header (y=1, x=-1, relative to center)
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB 2                ; End marker (path complete)

_SUIT_CLUBS_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $01,$05,0,0        ; path2: header (y=1, x=5, relative to center)
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB 2                ; End marker (path complete)

_SUIT_CLUBS_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $FF,$00,0,0        ; path3: header (y=-1, x=0, relative to center)
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_SUIT_CLUBS_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $FB,$FE,0,0        ; path4: header (y=-5, x=-2, relative to center)
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB 2                ; End marker (path complete)

; Vector asset: suit_diamonds
; Generated from suit_diamonds.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 4
; X bounds: min=-5, max=5, width=10
; Center: (0, 0)

_SUIT_DIAMONDS_WIDTH EQU 10
_SUIT_DIAMONDS_CENTER_X EQU 0
_SUIT_DIAMONDS_CENTER_Y EQU 0

_SUIT_DIAMONDS_VECTORS:  ; Main entry (header + 1 path(s))
    FCB 1               ; path_count (runtime metadata)
    FDB _SUIT_DIAMONDS_PATH0        ; pointer to path 0

_SUIT_DIAMONDS_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $07,$00,0,0        ; path0: header (y=7, x=0, relative to center)
    FCB $FF,$F9,$05          ; flag=-1, dy=-7, dx=5
    FCB $FF,$F9,$FB          ; flag=-1, dy=-7, dx=-5
    FCB $FF,$07,$FB          ; flag=-1, dy=7, dx=-5
    FCB $FF,$07,$05          ; flag=-1, dy=7, dx=5
    FCB 2                ; End marker (path complete)

; Vector asset: suit_hearts
; Generated from suit_hearts.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 10
; X bounds: min=-6, max=6, width=12
; Center: (0, 0)

_SUIT_HEARTS_WIDTH EQU 12
_SUIT_HEARTS_CENTER_X EQU 0
_SUIT_HEARTS_CENTER_Y EQU 0

_SUIT_HEARTS_VECTORS:  ; Main entry (header + 1 path(s))
    FCB 1               ; path_count (runtime metadata)
    FDB _SUIT_HEARTS_PATH0        ; pointer to path 0

_SUIT_HEARTS_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FA,$00,0,0        ; path0: header (y=-6, x=0, relative to center)
    FCB $FF,$05,$05          ; flag=-1, dy=5, dx=5
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$04,$FE          ; flag=-1, dy=4, dx=-2
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$FF,$FD          ; flag=-1, dy=-1, dx=-3
    FCB $FF,$FC,$FE          ; flag=-1, dy=-4, dx=-2
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$FB,$05          ; flag=-1, dy=-5, dx=5
    FCB 2                ; End marker (path complete)

; Array literal for variable 'deck' (52 elements)
ARRAY_0:
    FDB 0   ; Element 0
    FDB 1   ; Element 1
    FDB 2   ; Element 2
    FDB 3   ; Element 3
    FDB 4   ; Element 4
    FDB 5   ; Element 5
    FDB 6   ; Element 6
    FDB 7   ; Element 7
    FDB 8   ; Element 8
    FDB 9   ; Element 9
    FDB 10   ; Element 10
    FDB 11   ; Element 11
    FDB 12   ; Element 12
    FDB 13   ; Element 13
    FDB 14   ; Element 14
    FDB 15   ; Element 15
    FDB 16   ; Element 16
    FDB 17   ; Element 17
    FDB 18   ; Element 18
    FDB 19   ; Element 19
    FDB 20   ; Element 20
    FDB 21   ; Element 21
    FDB 22   ; Element 22
    FDB 23   ; Element 23
    FDB 24   ; Element 24
    FDB 25   ; Element 25
    FDB 26   ; Element 26
    FDB 27   ; Element 27
    FDB 28   ; Element 28
    FDB 29   ; Element 29
    FDB 30   ; Element 30
    FDB 31   ; Element 31
    FDB 32   ; Element 32
    FDB 33   ; Element 33
    FDB 34   ; Element 34
    FDB 35   ; Element 35
    FDB 36   ; Element 36
    FDB 37   ; Element 37
    FDB 38   ; Element 38
    FDB 39   ; Element 39
    FDB 40   ; Element 40
    FDB 41   ; Element 41
    FDB 42   ; Element 42
    FDB 43   ; Element 43
    FDB 44   ; Element 44
    FDB 45   ; Element 45
    FDB 46   ; Element 46
    FDB 47   ; Element 47
    FDB 48   ; Element 48
    FDB 49   ; Element 49
    FDB 50   ; Element 50
    FDB 51   ; Element 51

; Array literal for variable 'tab' (140 elements)
ARRAY_1:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7
    FDB 0   ; Element 8
    FDB 0   ; Element 9
    FDB 0   ; Element 10
    FDB 0   ; Element 11
    FDB 0   ; Element 12
    FDB 0   ; Element 13
    FDB 0   ; Element 14
    FDB 0   ; Element 15
    FDB 0   ; Element 16
    FDB 0   ; Element 17
    FDB 0   ; Element 18
    FDB 0   ; Element 19
    FDB 0   ; Element 20
    FDB 0   ; Element 21
    FDB 0   ; Element 22
    FDB 0   ; Element 23
    FDB 0   ; Element 24
    FDB 0   ; Element 25
    FDB 0   ; Element 26
    FDB 0   ; Element 27
    FDB 0   ; Element 28
    FDB 0   ; Element 29
    FDB 0   ; Element 30
    FDB 0   ; Element 31
    FDB 0   ; Element 32
    FDB 0   ; Element 33
    FDB 0   ; Element 34
    FDB 0   ; Element 35
    FDB 0   ; Element 36
    FDB 0   ; Element 37
    FDB 0   ; Element 38
    FDB 0   ; Element 39
    FDB 0   ; Element 40
    FDB 0   ; Element 41
    FDB 0   ; Element 42
    FDB 0   ; Element 43
    FDB 0   ; Element 44
    FDB 0   ; Element 45
    FDB 0   ; Element 46
    FDB 0   ; Element 47
    FDB 0   ; Element 48
    FDB 0   ; Element 49
    FDB 0   ; Element 50
    FDB 0   ; Element 51
    FDB 0   ; Element 52
    FDB 0   ; Element 53
    FDB 0   ; Element 54
    FDB 0   ; Element 55
    FDB 0   ; Element 56
    FDB 0   ; Element 57
    FDB 0   ; Element 58
    FDB 0   ; Element 59
    FDB 0   ; Element 60
    FDB 0   ; Element 61
    FDB 0   ; Element 62
    FDB 0   ; Element 63
    FDB 0   ; Element 64
    FDB 0   ; Element 65
    FDB 0   ; Element 66
    FDB 0   ; Element 67
    FDB 0   ; Element 68
    FDB 0   ; Element 69
    FDB 0   ; Element 70
    FDB 0   ; Element 71
    FDB 0   ; Element 72
    FDB 0   ; Element 73
    FDB 0   ; Element 74
    FDB 0   ; Element 75
    FDB 0   ; Element 76
    FDB 0   ; Element 77
    FDB 0   ; Element 78
    FDB 0   ; Element 79
    FDB 0   ; Element 80
    FDB 0   ; Element 81
    FDB 0   ; Element 82
    FDB 0   ; Element 83
    FDB 0   ; Element 84
    FDB 0   ; Element 85
    FDB 0   ; Element 86
    FDB 0   ; Element 87
    FDB 0   ; Element 88
    FDB 0   ; Element 89
    FDB 0   ; Element 90
    FDB 0   ; Element 91
    FDB 0   ; Element 92
    FDB 0   ; Element 93
    FDB 0   ; Element 94
    FDB 0   ; Element 95
    FDB 0   ; Element 96
    FDB 0   ; Element 97
    FDB 0   ; Element 98
    FDB 0   ; Element 99
    FDB 0   ; Element 100
    FDB 0   ; Element 101
    FDB 0   ; Element 102
    FDB 0   ; Element 103
    FDB 0   ; Element 104
    FDB 0   ; Element 105
    FDB 0   ; Element 106
    FDB 0   ; Element 107
    FDB 0   ; Element 108
    FDB 0   ; Element 109
    FDB 0   ; Element 110
    FDB 0   ; Element 111
    FDB 0   ; Element 112
    FDB 0   ; Element 113
    FDB 0   ; Element 114
    FDB 0   ; Element 115
    FDB 0   ; Element 116
    FDB 0   ; Element 117
    FDB 0   ; Element 118
    FDB 0   ; Element 119
    FDB 0   ; Element 120
    FDB 0   ; Element 121
    FDB 0   ; Element 122
    FDB 0   ; Element 123
    FDB 0   ; Element 124
    FDB 0   ; Element 125
    FDB 0   ; Element 126
    FDB 0   ; Element 127
    FDB 0   ; Element 128
    FDB 0   ; Element 129
    FDB 0   ; Element 130
    FDB 0   ; Element 131
    FDB 0   ; Element 132
    FDB 0   ; Element 133
    FDB 0   ; Element 134
    FDB 0   ; Element 135
    FDB 0   ; Element 136
    FDB 0   ; Element 137
    FDB 0   ; Element 138
    FDB 0   ; Element 139

; Array literal for variable 'tab_sz' (7 elements)
ARRAY_2:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6

; Array literal for variable 'tab_hid' (7 elements)
ARRAY_3:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6

; Array literal for variable 'found_cnt' (4 elements)
ARRAY_4:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3

; Array literal for variable 'stock' (24 elements)
ARRAY_5:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7
    FDB 0   ; Element 8
    FDB 0   ; Element 9
    FDB 0   ; Element 10
    FDB 0   ; Element 11
    FDB 0   ; Element 12
    FDB 0   ; Element 13
    FDB 0   ; Element 14
    FDB 0   ; Element 15
    FDB 0   ; Element 16
    FDB 0   ; Element 17
    FDB 0   ; Element 18
    FDB 0   ; Element 19
    FDB 0   ; Element 20
    FDB 0   ; Element 21
    FDB 0   ; Element 22
    FDB 0   ; Element 23

; Array literal for variable 'waste' (24 elements)
ARRAY_6:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7
    FDB 0   ; Element 8
    FDB 0   ; Element 9
    FDB 0   ; Element 10
    FDB 0   ; Element 11
    FDB 0   ; Element 12
    FDB 0   ; Element 13
    FDB 0   ; Element 14
    FDB 0   ; Element 15
    FDB 0   ; Element 16
    FDB 0   ; Element 17
    FDB 0   ; Element 18
    FDB 0   ; Element 19
    FDB 0   ; Element 20
    FDB 0   ; Element 21
    FDB 0   ; Element 22
    FDB 0   ; Element 23

; String literals (classic FCC + $80 terminator)
STR_0:
    FCC "##"
    FCB $80
STR_1:
    FCC "+"
    FCB $80
STR_2:
    FCC "1"
    FCB $80
STR_3:
    FCC "10"
    FCB $80
STR_4:
    FCC "2"
    FCB $80
STR_5:
    FCC "3"
    FCB $80
STR_6:
    FCC "4"
    FCB $80
STR_7:
    FCC "5"
    FCB $80
STR_8:
    FCC "6"
    FCB $80
STR_9:
    FCC "7"
    FCB $80
STR_10:
    FCC "8"
    FCB $80
STR_11:
    FCC "9"
    FCB $80
STR_12:
    FCC "A"
    FCB $80
STR_13:
    FCC "ALL SUITS COMPLETE"
    FCB $80
STR_14:
    FCC "HELD:"
    FCB $80
STR_15:
    FCC "J"
    FCB $80
STR_16:
    FCC "K"
    FCB $80
STR_17:
    FCC "PRESS B1 TO PLAY"
    FCB $80
STR_18:
    FCC "Q"
    FCB $80
STR_19:
    FCC "ST"
    FCB $80
STR_20:
    FCC "WS"
    FCB $80
STR_21:
    FCC "YOU WIN!"
    FCB $80
