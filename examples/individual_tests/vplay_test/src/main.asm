; --- Motorola 6809 backend (Vectrex) title='VPLAYTST' origin=$0000 ---
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
    FCC "VPLAYTST"
    FCB $80
    FCB 0

;***************************************************************************
; CODE SECTION
;***************************************************************************

; === RAM VARIABLE DEFINITIONS (EQU) ===
; AUTO-GENERATED - All offsets calculated automatically
; Total RAM used: 60 bytes
RESULT               EQU $C880+$00   ; Main result temporary (2 bytes)
TMPPTR               EQU $C880+$02   ; Pointer temp (used by DRAW_VECTOR, arrays, structs) (2 bytes)
TMPPTR2              EQU $C880+$04   ; Pointer temp 2 (for nested array operations) (2 bytes)
TEMP_YX              EQU $C880+$06   ; Temporary y,x storage (2 bytes)
TEMP_X               EQU $C880+$08   ; Temporary x storage (1 bytes)
TEMP_Y               EQU $C880+$09   ; Temporary y storage (1 bytes)
VPY_MOVE_X           EQU $C880+$0A   ; MOVE() current X offset (signed byte, 0 by default) (1 bytes)
VPY_MOVE_Y           EQU $C880+$0B   ; MOVE() current Y offset (signed byte, 0 by default) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$0C   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity as i16x5) (10 bytes)
NUM_STR              EQU $C880+$16   ; String buffer for PRINT_NUMBER (5 digits + terminator) (6 bytes)
TEXT_SCALE_H         EQU $C880+$1C   ; Character height for Print_Str_d (default $F8=-8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$1D   ; Character width for Print_Str_d (default $48=72, normal) (1 bytes)
DRAW_VEC_X           EQU $C880+$1E   ; X position offset for vector drawing (1 bytes)
DRAW_VEC_Y           EQU $C880+$1F   ; Y position offset for vector drawing (1 bytes)
MIRROR_X             EQU $C880+$20   ; X-axis mirror flag (0=normal, 1=flip) (1 bytes)
MIRROR_Y             EQU $C880+$21   ; Y-axis mirror flag (0=normal, 1=flip) (1 bytes)
DRAW_VEC_INTENSITY   EQU $C880+$22   ; Intensity override (0=use vector's, >0=override) (1 bytes)
LEVEL_PTR            EQU $C880+$23   ; Pointer to currently loaded level data (2 bytes)
LEVEL_BG_COUNT       EQU $C880+$25   ; SHOW_LEVEL: background object count (1 bytes)
LEVEL_GP_COUNT       EQU $C880+$26   ; SHOW_LEVEL: gameplay object count (1 bytes)
LEVEL_FG_COUNT       EQU $C880+$27   ; SHOW_LEVEL: foreground object count (1 bytes)
LEVEL_BG_PTR         EQU $C880+$28   ; SHOW_LEVEL: background objects pointer (RAM buffer) (2 bytes)
LEVEL_GP_PTR         EQU $C880+$2A   ; SHOW_LEVEL: gameplay objects pointer (RAM buffer) (2 bytes)
LEVEL_FG_PTR         EQU $C880+$2C   ; SHOW_LEVEL: foreground objects pointer (RAM buffer) (2 bytes)
LEVEL_BG_ROM_PTR     EQU $C880+$2E   ; LOAD_LEVEL: background objects pointer (ROM) (2 bytes)
LEVEL_GP_ROM_PTR     EQU $C880+$30   ; LOAD_LEVEL: gameplay objects pointer (ROM) (2 bytes)
LEVEL_FG_ROM_PTR     EQU $C880+$32   ; LOAD_LEVEL: foreground objects pointer (ROM) (2 bytes)
VAR_ARG0             EQU $C880+$34   ; Function argument 0 (2 bytes)
VAR_ARG1             EQU $C880+$36   ; Function argument 1 (2 bytes)
VAR_ARG2             EQU $C880+$38   ; Function argument 2 (2 bytes)
VAR_ARG3             EQU $C880+$3A   ; Function argument 3 (2 bytes)

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

; ============================================================================
; Draw_Sync_List_At - Draw vector at offset position (DRAW_VEC_X, DRAW_VEC_Y)
; Same as Draw_Sync_List but adds offset to y_start, x_start coordinates
; Uses: DRAW_VEC_X, DRAW_VEC_Y (set by DRAW_VECTOR before calling this)
; ============================================================================
Draw_Sync_List_At:
LDA ,X+                 ; intensity
PSHS A                  ; Save intensity
LDA #$D0
PULS A                  ; Restore intensity
JSR $F2AB               ; BIOS Intensity_a
LDB ,X+                 ; y_start from .vec
ADDB DRAW_VEC_Y         ; Add Y offset
LDA ,X+                 ; x_start from .vec
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
LDD TEMP_YX             ; Recuperar y,x ajustado
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
DSLA_W1:
LDA VIA_int_flags
ANDA #$40
BEQ DSLA_W1
; PB stays 1 — draw loop begins with PB=1
; Loop de dibujo (same as Draw_Sync_List)
DSLA_LOOP:
LDA ,X+                 ; Read flag
CMPA #2                 ; Check end marker
LBEQ DSLA_DONE
CMPA #1                 ; Check next path marker
LBEQ DSLA_NEXT_PATH
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
DSLA_W2:
LDA VIA_int_flags
ANDA #$40
BEQ DSLA_W2
CLR VIA_shift_reg       ; beam off (PB stays 1 for next segment)
LBRA DSLA_LOOP           ; Long branch
; Next path: add offset to new coordinates too
DSLA_NEXT_PATH:
TFR X,D
PSHS D
LDA ,X+                 ; Read intensity
PSHS A
LDB ,X+                 ; y_start
ADDB DRAW_VEC_Y         ; Add Y offset to new path
LDA ,X+                 ; x_start
ADDA DRAW_VEC_X         ; Add X offset to new path
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
; Moveto new start position (Moveto_d order, offset-adjusted)
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
DSLA_W3:
LDA VIA_int_flags
ANDA #$40
BEQ DSLA_W3
; PB stays 1 — draw loop continues with PB=1
LBRA DSLA_LOOP           ; Long branch
DSLA_DONE:
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
; === LOAD_LEVEL_RUNTIME ===
; Load level data from ROM and copy objects to RAM
; Input: X = pointer to level data in ROM
; Output: LEVEL_PTR = pointer to level header (persistent)
;         RESULT    = pointer to level header (return value)
;         OPTIMIZATION: BG and FG are static → read from ROM directly
;                       Only GP is copied to RAM (has dynamic objects)
;           LEVEL_GP_BUFFER (max 16 objects * 20 bytes = 320 bytes)
LOAD_LEVEL_RUNTIME:
    PSHS D,X,Y,U     ; Preserve registers
    
    ; Store level pointer persistently
    STX >LEVEL_PTR
    
    ; Skip world bounds (8 bytes) + time/score (4 bytes)
    LEAX 12,X        ; X now points to object counts
    
    ; Read object counts
    LDB ,X+          ; B = bgCount
    STB >LEVEL_BG_COUNT
    LDB ,X+          ; B = gameplayCount
    STB >LEVEL_GP_COUNT
    LDB ,X+          ; B = fgCount
    STB >LEVEL_FG_COUNT
    
    ; Read layer pointers (ROM)
    LDD ,X++         ; D = bgObjectsPtr (ROM)
    STD >LEVEL_BG_ROM_PTR
    LDD ,X++         ; D = gameplayObjectsPtr (ROM)
    STD >LEVEL_GP_ROM_PTR
    LDD ,X++         ; D = fgObjectsPtr (ROM)
    STD >LEVEL_FG_ROM_PTR
    
    ; === Setup GP pointer: RAM buffer if physics, ROM if static ===
    LDB >LEVEL_GP_COUNT
    BEQ LLR_SKIP_GP  ; Skip if zero objects
    
    ; No physics → GP reads from ROM like BG/FG
    LDD >LEVEL_GP_ROM_PTR ; Just point to ROM
    STD >LEVEL_GP_PTR    ; Store ROM pointer
LLR_GP_DONE:
LLR_SKIP_GP:
    
    ; Return level pointer in RESULT
    LDX >LEVEL_PTR
    STX RESULT
    
    PULS D,X,Y,U,PC  ; Restore and return
    
; === Subroutine: Copy N Objects ===
; Input: B = count, X = source (ROM), U = destination (RAM)
; OPTIMIZATION: Skip 'type' field (+0) - read from ROM when needed
; Each ROM object is 20 bytes, but we copy only 19 bytes to RAM (skip type)
; Clobbers: A, B, X, U
LLR_COPY_OBJECTS:
LLR_COPY_LOOP:
    TSTB
    BEQ LLR_COPY_DONE
    PSHS B           ; Save counter (LDD will clobber B!)
    
    ; Skip type (offset +0) and intensity (offset +8) fields in ROM
    LEAX 1,X         ; X now points to +1 (x position)
    
    ; Copy 14 bytes optimized: x,y,scale,spawn_delay as 1-byte values
    LDA 1,X          ; ROM +2 (x low byte) → RAM +0
    STA ,U+
    LDA 3,X          ; ROM +4 (y low byte) → RAM +1
    STA ,U+
    LDA 5,X          ; ROM +6 (scale low byte) → RAM +2
    STA ,U+
    LDA 6,X          ; ROM +7 (rotation) → RAM +3
    STA ,U+
    LEAX 8,X         ; Skip to ROM +9 (past intensity at +8)
    LDA ,X+          ; ROM +9 (velocity_x) → RAM +4
    STA ,U+
    LDA ,X+          ; ROM +10 (velocity_y) → RAM +5
    STA ,U+
    LDA ,X+          ; ROM +11 (physics_flags) → RAM +6
    STA ,U+
    LDA ,X+          ; ROM +12 (collision_flags) → RAM +7
    STA ,U+
    LDA ,X+          ; ROM +13 (collision_size) → RAM +8
    STA ,U+
    LDA 1,X          ; ROM +15 (spawn_delay low byte) → RAM +9
    STA ,U+
    LEAX 2,X         ; Skip spawn_delay (2 bytes)
    LDD ,X++         ; ROM +16-17 (vector_ptr) → RAM +10-11
    STD ,U++
    LDD ,X++         ; ROM +18-19 (properties_ptr) → RAM +12-13
    STD ,U++
    
    PULS B           ; Restore counter
    DECB             ; Decrement after copy
    BRA LLR_COPY_LOOP
LLR_COPY_DONE:
    RTS

; === SHOW_LEVEL_RUNTIME ===
; Draw all level objects from loaded level
; Input: LEVEL_PTR = pointer to level data
; Level structure (from levelres.rs):
;   +0:  FDB xMin, xMax (world bounds)
;   +4:  FDB yMin, yMax
;   +8:  FDB timeLimit, targetScore
;   +12: FCB bgCount, gameplayCount, fgCount
;   +15: FDB bgObjectsPtr, gameplayObjectsPtr, fgObjectsPtr
; RAM object structure (19 bytes each, 'type' omitted - read from ROM):
;   +0:  FDB x, y (position)
;   +4:  FDB scale (8.8 fixed point)
;   +6:  FCB rotation, intensity
;   +8:  FCB velocity_x, velocity_y
;   +10: FCB physics_flags, collision_flags, collision_size
;   +13: FDB spawn_delay
;   +15: FDB vector_ptr
;   +17: FDB properties_ptr
SHOW_LEVEL_RUNTIME:
    PSHS D,X,Y,U     ; Preserve registers
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access - ONCE at start)
    
    ; Get level pointer (persistent)
    LDX >LEVEL_PTR
    CMPX #0
    BEQ SLR_DONE     ; No level loaded
    
    ; Skip world bounds (8 bytes) + time/score (4 bytes)
    LEAX 12,X        ; X now points to object counts
    
    ; Read object counts (use LDB+STB to ensure 1-byte operations)
    LDB ,X+          ; B = bgCount
    STB >LEVEL_BG_COUNT
    LDB ,X+          ; B = gameplayCount
    STB >LEVEL_GP_COUNT
    LDB ,X+          ; B = fgCount
    STB >LEVEL_FG_COUNT
    
    ; NOTE: Layer pointers already set by LOAD_LEVEL
    ; - LEVEL_BG_PTR points to ROM (set by LOAD_LEVEL)
    ; - LEVEL_GP_PTR points to RAM buffer if physics, ROM if static (set by LOAD_LEVEL)
    ; - LEVEL_FG_PTR points to ROM (set by LOAD_LEVEL)
    
    ; === Draw Background Layer (from ROM) ===
SLR_BG_COUNT:
    CLRB             ; Clear high byte to prevent corruption
    LDB >LEVEL_BG_COUNT
    CMPB #0
    BEQ SLR_GAMEPLAY
SLR_BG_PTR:
    LDA #20          ; ROM objects are 20 bytes (with 'type' field)
    LDX >LEVEL_BG_ROM_PTR ; Read from ROM directly (no RAM copy)
    JSR SLR_DRAW_OBJECTS
    
    ; === Draw Gameplay Layer (from RAM) ===
SLR_GAMEPLAY:
SLR_GP_COUNT:
    CLRB             ; Clear high byte to prevent corruption
    LDB >LEVEL_GP_COUNT
    CMPB #0
    BEQ SLR_FOREGROUND
SLR_GP_PTR:
    LDA #20          ; GP objects read from ROM (20 bytes)
    LDX >LEVEL_GP_PTR ; Read from pointer (RAM if physics, ROM if static)
    JSR SLR_DRAW_OBJECTS
    
    ; === Draw Foreground Layer (from ROM) ===
SLR_FOREGROUND:
SLR_FG_COUNT:
    CLRB             ; Clear high byte to prevent corruption
    LDB >LEVEL_FG_COUNT
    CMPB #0
    BEQ SLR_DONE
SLR_FG_PTR:
    LDA #20          ; ROM objects are 20 bytes (with 'type' field)
    LDX >LEVEL_FG_ROM_PTR ; Read from ROM directly (no RAM copy)
    JSR SLR_DRAW_OBJECTS
    
SLR_DONE:
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access - ONCE at end)
    PULS D,X,Y,U,PC  ; Restore and return
    
; === Subroutine: Draw N Objects ===
; Input: A = stride (19=RAM, 20=ROM), B = count, X = objects ptr
SLR_DRAW_OBJECTS:
    PSHS A           ; Save stride on stack
    ; NOTE: Use register-based loop (no stack juggling).
    ; Input: B = count, X = objects ptr. Clobbers B,X,Y,U.
SLR_OBJ_LOOP:
    TSTB             ; Test if count is zero
    LBEQ SLR_OBJ_DONE ; Exit if zero (LONG branch - intensity calc made loop large)
    
    PSHS B           ; CRITICAL: Save counter (B gets clobbered by LDD operations)
    
    ; X points to current object
    ; ROM: 20 bytes with 'type' at +0 (offsets: intensity +8, y +3, x +1, vector_ptr +16)
    ; RAM: 18 bytes without 'type' and 'intensity' (offsets: y +2, x +0, vector_ptr +14)
    ; NOTE: intensity ALWAYS read from ROM (even for RAM objects)
    
    ; Determine object type based on stride (peek from stack)
    LDA 1,S          ; Load stride from stack (offset +1 because B is at top)
    CMPA #20
    BEQ SLR_ROM_OFFSETS
    
    ; RAM offsets (14 bytes, no 'type' or 'intensity')
    ; Calculate ROM address for intensity: ROM_PTR + (objIndex * 20) + 8
    ; objIndex = totalCount - currentCounter
    ; FIX: use X (not D) to walk ROM addresses — avoids LDB clobbering D
    PSHS X           ; Save RAM object pointer
    LDB >LEVEL_GP_COUNT
    SUBB 2,S         ; B = objIndex = totalCount - currentCounter
    LDX >LEVEL_GP_ROM_PTR ; X = ROM base (index 0)
SLR_ROM_ADDR_LOOP:
    BEQ SLR_INTENSITY_READ  ; Exit if index=0 (X already at correct ROM obj)
    LEAX 20,X        ; X += ROM stride (20 bytes per object)
    DECB             ; Decrement index counter
    BRA SLR_ROM_ADDR_LOOP
SLR_INTENSITY_READ:
    LDA 8,X          ; intensity at ROM +8
    STA DRAW_VEC_INTENSITY
    PULS X           ; Restore RAM object pointer
    
    CLR MIRROR_X
    CLR MIRROR_Y
    LDB 1,X          ; y at +1 (1 byte)
    STB DRAW_VEC_Y
    LDB 0,X          ; x at +0 (1 byte)
    STB DRAW_VEC_X
    LDU 10,X         ; vector_ptr at +10
    BRA SLR_DRAW_VECTOR
    
SLR_ROM_OFFSETS:
    ; ROM offsets (20 bytes, with 'type' at +0)
    CLR MIRROR_X
    CLR MIRROR_Y
    LDA 8,X          ; intensity at +8
    STA DRAW_VEC_INTENSITY
    LDD 3,X          ; y at +3
    STB DRAW_VEC_Y
    LDD 1,X          ; x at +1
    STB DRAW_VEC_X
    LDU 16,X         ; vector_ptr at +16
    
SLR_DRAW_VECTOR:
    PSHS X           ; Save object pointer on stack (Y may be corrupted by Draw_Sync_List)
    TFR U,X          ; X = vector data pointer (points to header)
    
    ; Read path_count from header (byte 0)
    LDB ,X+          ; B = path_count, X now points to pointer table
    
    ; Draw all paths using pointer table (DP already set to $D0 by SHOW_LEVEL_RUNTIME)
SLR_PATH_LOOP:
    TSTB             ; Check if count is zero
    BEQ SLR_PATH_DONE ; Exit if no paths left
    DECB             ; Decrement count
    PSHS B           ; Save decremented count
    
    ; Read next path pointer from table (X points to current FDB entry)
    LDU ,X++         ; U = path pointer, X advances to next entry
    PSHS X           ; Save pointer table position
    TFR U,X          ; X = actual path data
    JSR Draw_Sync_List_At_With_Mirrors  ; Draw this path
    PULS X           ; Restore pointer table position
    PULS B           ; Restore counter for next iteration
    BRA SLR_PATH_LOOP
    
SLR_PATH_DONE:
    PULS X           ; Restore object pointer from stack
    
    ; Advance to next object using stride from stack
    LDA 1,S          ; Load stride from stack (offset +1 because B is at top)
    LEAX A,X         ; X += stride (18 or 20 bytes)
    
    PULS B           ; Restore counter
    DECB             ; Decrement count AFTER drawing
    LBRA SLR_OBJ_LOOP  ; LONG branch - intensity calc made loop large
    
SLR_OBJ_DONE:
    PULS A           ; Clean up stride from stack
    RTS

; === UPDATE_LEVEL_RUNTIME ===
; Update level state (physics, velocity, spawn delays)
; OPTIMIZATION: Only updates GP layer (BG/FG are static, read from ROM)
; CRITICAL: Works on RAM BUFFERS, not ROM!
;
UPDATE_LEVEL_RUNTIME:
    PSHS U,X,Y,D  ; Preserve all registers
    
    ; === Skip Background (static, no updates) ===
    ; BG objects are read directly from ROM - no physics processing needed
    
    ; === Update Gameplay Objects ONLY ===
    LDB LEVEL_GP_COUNT
    CMPB #0
    LBEQ ULR_EXIT  ; Long branch (no objects to update)
    LDU LEVEL_GP_PTR  ; U = GP pointer (RAM if physics, ROM if static)
    BSR ULR_UPDATE_LAYER  ; Process objects
    
    
ULR_EXIT:
    PULS D,Y,X,U  ; Restore registers
    RTS

; === ULR_UPDATE_LAYER - Process all objects in a layer ===
; Input: B = object count, U = buffer base address
; Uses: X for world bounds
ULR_UPDATE_LAYER:
    LDX >LEVEL_PTR  ; Load level pointer for world bounds
    CMPX #0
    LBEQ ULR_LAYER_EXIT  ; No level loaded (long branch)
    
ULR_LOOP:
    ; U = pointer to object data (19 bytes per object in RAM)
    ; RAM object structure (type omitted - read from ROM if needed):
    ; +0: x (2 bytes signed)
    ; +2: y (2 bytes signed)
    ; +4: scale (2 bytes - not used by physics)
    ; +6: rotation (1 byte - not used by physics)
    ; +7: intensity (1 byte - not used by physics)
    ; +8: velocity_x (1 byte signed)
    ; +9: velocity_y (1 byte signed)
    ; +10: physics_flags (1 byte)
    ; +11: collision_flags (1 byte)
    ; +12-18: other fields (collision_size, spawn_delay, vector_ptr, properties_ptr)

    ; Check physics_flags (offset +9)
    PSHS B  ; Save loop counter
    LDB 6,U      ; Read flags
    CMPB #0
    LBEQ ULR_NEXT  ; Skip if no physics enabled (long branch)

    ; Check if dynamic physics enabled (bit 0)
    BITB #$01
    LBEQ ULR_NEXT  ; Skip if not dynamic (long branch)

    ; Check if gravity enabled (bit 1)
    BITB #$02
    LBEQ ULR_NO_GRAVITY  ; Long branch

    ; Apply gravity: velocity_y -= 1
    LDB 5,U       ; Read velocity_y (offset +5 in RAM buffer)
    DECB          ; Subtract gravity
    ; Clamp to -15..+15 (max velocity)
    CMPB #$F1     ; Compare with -15
    BGE ULR_VY_OK
    LDB #$F1      ; Clamp to -15
ULR_VY_OK:
    STB 5,U       ; Store updated velocity_y

ULR_NO_GRAVITY:
    ; Apply velocity to position (16-bit to avoid 8-bit wraparound)
    ; x += velocity_x
    LDB 0,U       ; x (8-bit signed)
    SEX           ; D = sign-extended x
    TFR D,Y       ; Y = x (16-bit)
    LDB 4,U       ; velocity_x (8-bit signed)
    SEX           ; D = sign-extended velocity_x
    LEAY D,Y      ; Y = x + velocity_x (16-bit addition)
    TFR Y,D       ; D = 16-bit result
    CMPD #127     ; Clamp to i8 max
    BLE ULR_X_NOT_MAX
    LDD #127
ULR_X_NOT_MAX:
    CMPD #-128    ; Clamp to i8 min
    BGE ULR_X_NOT_MIN
    LDD #-128
ULR_X_NOT_MIN:
    STB 0,U       ; Store clamped x

    ; y += velocity_y
    LDB 1,U       ; y (8-bit signed)
    SEX           ; D = sign-extended y
    TFR D,Y       ; Y = y (16-bit)
    LDB 5,U       ; velocity_y (8-bit signed)
    SEX           ; D = sign-extended velocity_y
    LEAY D,Y      ; Y = y + velocity_y (16-bit addition)
    TFR Y,D       ; D = 16-bit result
    CMPD #127     ; Clamp to i8 max
    BLE ULR_Y_NOT_MAX
    LDD #127
ULR_Y_NOT_MAX:
    CMPD #-128    ; Clamp to i8 min
    BGE ULR_Y_NOT_MIN
    LDD #-128
ULR_Y_NOT_MIN:
    STB 1,U       ; Store clamped y

    ; === Check World Bounds (Wall Collisions) ===
    LDB 7,U      ; Load collision_flags
    BITB #$02     ; Check bounce_walls flag (bit 1)
    LBEQ ULR_NEXT  ; Skip bounce if not enabled (long branch)

    ; Load world bounds pointer from LEVEL_PTR
    LDX >LEVEL_PTR
    ; LEVEL_PTR → +0: xMin, +2: xMax, +4: yMin, +6: yMax (direct values)

    ; === Check X Bounds (Left/Right walls) ===
    ; Check xMin: if (x - collision_size) < xMin then bounce
    LDB 8,U      ; collision_size (offset +8)
    SEX           ; Sign-extend to 16-bit in D
    PSHS D        ; Save collision_size on stack
    LDB 0,U       ; Load object x (8-bit at offset +0)
    SEX           ; Sign-extend x to 16-bit
    SUBD ,S++     ; D = x - collision_size (left edge), pop stack
    CMPD 0,X      ; Compare left edge with xMin
    LBGE ULR_X_MAX_CHECK  ; Skip if left_edge >= xMin (LONG)
    ; Hit xMin wall - only bounce if moving left (velocity_x < 0)
    LDB 4,U       ; velocity_x (offset +4)
    CMPB #0
    LBGE ULR_X_MAX_CHECK  ; Skip if moving right (LONG)
    ; Bounce: set position so left edge = xMin
    LDB 8,U      ; Reload collision_size
    SEX
    ADDD 0,X      ; D = xMin + collision_size (center position)
    STB 0,U       ; x = (xMin + collision_size) low byte (8-bit store)
    LDB 4,U       ; Reload velocity_x
    NEGB          ; velocity_x = -velocity_x
    STB 4,U

    ; Check xMax: if (x + collision_size) > xMax then bounce
ULR_X_MAX_CHECK:
    LDB 8,U      ; Reload collision_size
    SEX
    PSHS D        ; Save collision_size on stack
    LDB 0,U       ; Load object x (8-bit at offset +0)
    SEX           ; Sign-extend x to 16-bit
    ADDD ,S++     ; D = x + collision_size (right edge), pop stack
    CMPD 2,X      ; Compare right edge with xMax
    LBLE ULR_Y_BOUNDS  ; Skip if right_edge <= xMax (LONG)
    ; Hit xMax wall - only bounce if moving right (velocity_x > 0)
    LDB 4,U       ; velocity_x (offset +4)
    CMPB #0
    LBLE ULR_Y_BOUNDS  ; Skip if moving left (LONG)
    ; Bounce: set position so right edge = xMax
    LDB 8,U      ; Reload collision_size
    SEX
    TFR D,Y       ; Y = collision_size
    LDD 2,X       ; D = xMax
    PSHS Y        ; Push collision_size
    SUBD ,S++     ; D = xMax - collision_size (center position), pop
    STB 0,U       ; x = (xMax - collision_size) low byte (8-bit store)
    LDB 4,U       ; Reload velocity_x
    NEGB          ; velocity_x = -velocity_x
    STB 4,U

    ; === Check Y Bounds (Top/Bottom walls) ===
ULR_Y_BOUNDS:
    ; Check yMin: if (y - collision_size) < yMin then bounce
    LDB 8,U      ; Reload collision_size
    SEX
    PSHS D        ; Save collision_size on stack
    LDB 1,U       ; Load object y (8-bit at offset +1)
    SEX           ; Sign-extend y to 16-bit
    SUBD ,S++     ; D = y - collision_size (bottom edge), pop stack
    CMPD 4,X      ; Compare bottom edge with yMin
    LBGE ULR_Y_MAX_CHECK  ; Skip if bottom_edge >= yMin (LONG)
    ; Hit yMin wall - only bounce if moving down (velocity_y < 0)
    LDB 5,U       ; velocity_y (offset +5)
    CMPB #0
    LBGE ULR_Y_MAX_CHECK  ; Skip if moving up (LONG)
    ; Bounce: set position so bottom edge = yMin
    LDB 8,U      ; Reload collision_size
    SEX
    ADDD 4,X      ; D = yMin + collision_size (center position)
    STB 1,U       ; y = (yMin + collision_size) low byte (8-bit store)
    LDB 5,U       ; Reload velocity_y
    NEGB          ; velocity_y = -velocity_y
    STB 5,U

    ; Check yMax: if (y + collision_size) > yMax then bounce
ULR_Y_MAX_CHECK:
    LDB 8,U      ; Reload collision_size
    SEX
    PSHS D        ; Save collision_size on stack
    LDB 1,U       ; Load object y (8-bit at offset +1)
    SEX           ; Sign-extend y to 16-bit
    ADDD ,S++     ; D = y + collision_size (top edge), pop stack
    CMPD 6,X      ; Compare top edge with yMax
    LBLE ULR_NEXT  ; Skip if top_edge <= yMax (LONG)
    ; Hit yMax wall - only bounce if moving up (velocity_y > 0)
    LDB 5,U       ; velocity_y (offset +5)
    CMPB #0
    LBLE ULR_NEXT  ; Skip if moving down (LONG)
    ; Bounce: set position so top edge = yMax
    LDB 8,U      ; Reload collision_size
    SEX
    TFR D,Y       ; Y = collision_size
    LDD 6,X       ; D = yMax
    PSHS Y        ; Push collision_size
    SUBD ,S++     ; D = yMax - collision_size (center position), pop
    STB 1,U       ; y = (yMax - collision_size) low byte (8-bit store)
    LDB 5,U       ; Reload velocity_y
    NEGB          ; velocity_y = -velocity_y
    STB 5,U

ULR_NEXT:
    PULS B        ; Restore loop counter
    LEAU 14,U     ; Move to next object (14 bytes)
    DECB
    LBNE ULR_LOOP  ; Continue if more objects (long branch)

ULR_LAYER_EXIT:
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
    ; VPy_LINE:7
    ; VPy_LINE:8
; LOAD_LEVEL("demo_level") - load level data
    LDX #_DEMO_LEVEL_LEVEL
    JSR LOAD_LEVEL_RUNTIME
    LDD RESULT  ; Returns level pointer

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

    ; VPy_LINE:10
LOOP_BODY:
    JSR Wait_Recal  ; CRITICAL: Sync with CRT refresh (50Hz frame timing)
    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access
    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)
    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access
    ; DEBUG: Statement 0 - Discriminant(8)
    ; VPy_LINE:11
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-55
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #120
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_0
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 11
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; DEBUG: Statement 1 - Discriminant(8)
    ; VPy_LINE:13
; NATIVE_CALL: UPDATE_LEVEL at line 13
    JSR UPDATE_LEVEL_RUNTIME
    CLRA
    CLRB
    STD RESULT
    ; DEBUG: Statement 2 - Discriminant(8)
    ; VPy_LINE:14
; SHOW_LEVEL() - draw all level objects
    JSR SHOW_LEVEL_RUNTIME
    LDD #0
    STD RESULT
    ; DEBUG: Statement 3 - Discriminant(8)
    ; VPy_LINE:16
; DRAW_VECTOR("platform", x, y) - 1 path(s) at position
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #80
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
    LDX #_PLATFORM_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    RTS

;***************************************************************************
; DATA SECTION
;***************************************************************************

; ========================================
; ASSET DATA SECTION
; Embedded 2 of 6 assets (unused assets excluded)
; ========================================

; Vector asset: platform
; Generated from platform.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 4
; X bounds: min=-30, max=30, width=60
; Center: (0, 2)

_PLATFORM_WIDTH EQU 60
_PLATFORM_CENTER_X EQU 0
_PLATFORM_CENTER_Y EQU 2

_PLATFORM_VECTORS:  ; Main entry (header + 1 path(s))
    FCB 1               ; path_count (runtime metadata)
    FDB _PLATFORM_PATH0        ; pointer to path 0

_PLATFORM_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $FE,$E2,0,0        ; path0: header (y=-2, x=-30, relative to center)
    FCB $FF,$00,$3C          ; flag=-1, dy=0, dx=60
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$C4          ; flag=-1, dy=0, dx=-60
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

; Level Asset: demo_level (from /Users/daniel/projects/vectrex-pseudo-python/examples/individual_tests/vplay_test/assets/playground/demo_level.vplay)
; ==== Level: DEMO_LEVEL ====
; Author: 
; Difficulty: medium

_DEMO_LEVEL_LEVEL:
    FDB -96  ; World bounds: xMin (16-bit signed)
    FDB 95  ; xMax (16-bit signed)
    FDB -128  ; yMin (16-bit signed)
    FDB 127  ; yMax (16-bit signed)
    FDB 0  ; Time limit (seconds)
    FDB 0  ; Target score
    FCB 0  ; Background object count
    FCB 1  ; Gameplay object count
    FCB 0  ; Foreground object count
    FDB _DEMO_LEVEL_BG_OBJECTS
    FDB _DEMO_LEVEL_GAMEPLAY_OBJECTS
    FDB _DEMO_LEVEL_FG_OBJECTS

_DEMO_LEVEL_BG_OBJECTS:

_DEMO_LEVEL_GAMEPLAY_OBJECTS:
; Object: obj_1778358719583 (background)
    FCB 4  ; type
    FDB 0  ; x
    FDB 0  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM_VECTORS  ; vector_ptr
    FDB 0  ; properties_ptr (reserved)


_DEMO_LEVEL_FG_OBJECTS:


; String literals (classic FCC + $80 terminator)
STR_0:
    FCC "VPLAY TEST"
    FCB $80
