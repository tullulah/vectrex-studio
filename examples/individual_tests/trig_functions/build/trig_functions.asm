; --- Motorola 6809 backend (Vectrex) title='TRIG' origin=$0000 ---
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
    FCC "TRIG"
    FCB $80
    FCB 0

;***************************************************************************
; CODE SECTION
;***************************************************************************

; === RAM VARIABLE DEFINITIONS (EQU) ===
; AUTO-GENERATED - All offsets calculated automatically
; Total RAM used: 58 bytes
RESULT               EQU $C880+$00   ; Main result temporary (2 bytes)
TMPLEFT              EQU $C880+$02   ; Left operand temp (2 bytes)
TMPLEFT2             EQU $C880+$04   ; Left operand temp 2 (for nested operations) (2 bytes)
TMPRIGHT             EQU $C880+$06   ; Right operand temp (2 bytes)
TMPRIGHT2            EQU $C880+$08   ; Right operand temp 2 (for nested operations) (2 bytes)
TMPPTR               EQU $C880+$0A   ; Pointer temp (used by DRAW_VECTOR, arrays, structs) (2 bytes)
TMPPTR2              EQU $C880+$0C   ; Pointer temp 2 (for nested array operations) (2 bytes)
DIV_A                EQU $C880+$0E   ; Dividend (2 bytes)
DIV_B                EQU $C880+$10   ; Divisor (2 bytes)
DIV_Q                EQU $C880+$12   ; Quotient (2 bytes)
DIV_R                EQU $C880+$14   ; Remainder (2 bytes)
TEMP_YX              EQU $C880+$16   ; Temporary y,x storage (2 bytes)
TEMP_X               EQU $C880+$18   ; Temporary x storage (1 bytes)
TEMP_Y               EQU $C880+$19   ; Temporary y storage (1 bytes)
VPY_MOVE_X           EQU $C880+$1A   ; MOVE() current X offset (signed byte, 0 by default) (1 bytes)
VPY_MOVE_Y           EQU $C880+$1B   ; MOVE() current Y offset (signed byte, 0 by default) (1 bytes)
NUM_STR              EQU $C880+$1C   ; String buffer for PRINT_NUMBER (5 digits + terminator) (6 bytes)
DRAW_CIRCLE_XC       EQU $C880+$22   ; Circle center X (byte) (1 bytes)
DRAW_CIRCLE_YC       EQU $C880+$23   ; Circle center Y (byte) (1 bytes)
DRAW_CIRCLE_DIAM     EQU $C880+$24   ; Circle diameter (byte) (1 bytes)
DRAW_CIRCLE_INTENSITY EQU $C880+$25   ; Circle intensity (byte) (1 bytes)
DRAW_CIRCLE_TEMP     EQU $C880+$26   ; Circle drawing temporaries (radius=2, xc=2, yc=2, spare=2) (8 bytes)
VAR_ANGLE            EQU $C880+$2E   ; User variable (2 bytes)
VAR_ARG0             EQU $C880+$30   ; Function argument 0 (2 bytes)
VAR_ARG1             EQU $C880+$32   ; Function argument 1 (2 bytes)
VAR_ARG2             EQU $C880+$34   ; Function argument 2 (2 bytes)
VAR_ARG3             EQU $C880+$36   ; Function argument 3 (2 bytes)
VAR_ARG4             EQU $C880+$38   ; Function argument 4 (2 bytes)

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
    JSR Reset0Ref  ; Reset beam to center for absolute text positioning
    LDU VAR_ARG2   ; string pointer (ARG2 = third param)
    LDA VAR_ARG1+1 ; Y (ARG1 = second param)
    LDB VAR_ARG0+1 ; X (ARG0 = first param)
    JSR Print_Str_d
    LDA #$80
    STA $D004      ; Restore VIA_t1_cnt_lo=$80 (Moveto_d_7F sets it to $7F)
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
; DRAW_CIRCLE_RUNTIME - Draw circle with runtime parameters
; ============================================================================
; Follows Draw_Sync_List_At pattern: read params BEFORE DP change
; Inputs: DRAW_CIRCLE_XC, DRAW_CIRCLE_YC, DRAW_CIRCLE_DIAM, DRAW_CIRCLE_INTENSITY (bytes in RAM)
; Uses 16-segment polygon (same as constant path) via MUL scaling of fixed fractions
; 4 unique delta fractions of radius r (16-gon, vertices at k*22.5 deg):
;   a = 0.3827*r (sin22.5) via MUL #98 /256, stored at DRAW_CIRCLE_TEMP+2
;   b = 0.3244*r (sin45-sin22.5) via MUL #83 /256, stored at DRAW_CIRCLE_TEMP+3
;   c = 0.2168*r via MUL #56 /256, stored at DRAW_CIRCLE_TEMP+4
;   d = 0.0761*r via MUL #19 /256, stored at DRAW_CIRCLE_TEMP+5
; DRAW_CIRCLE_TEMP layout: [radius16][a][b][c][d][--][--]
DRAW_CIRCLE_RUNTIME:
; Read ALL parameters into registers/stack BEFORE changing DP (critical!)
; (These are byte variables, use LDB not LDD)
LDB DRAW_CIRCLE_INTENSITY
PSHS B                 ; Save intensity on stack

LDB DRAW_CIRCLE_DIAM
SEX                    ; Sign-extend to 16-bit (diameter is unsigned 0..255)
LSRA                   ; Divide by 2 to get radius
RORB
STD DRAW_CIRCLE_TEMP   ; DRAW_CIRCLE_TEMP = radius (16-bit, big-endian: +0=hi, +1=lo)

LDB DRAW_CIRCLE_XC     ; xc (signed -128..127)
SEX
STD DRAW_CIRCLE_TEMP+2 ; Save xc (16-bit, reused for 'a' after Moveto)

LDB DRAW_CIRCLE_YC     ; yc (signed -128..127)
SEX
STD DRAW_CIRCLE_TEMP+4 ; Save yc (16-bit, reused for 'c' after Moveto)

; NOW safe to setup BIOS (all params are in DRAW_CIRCLE_TEMP+stack)
LDA #$D0
TFR A,DP
JSR Reset0Ref
LDA #$80
STA <$04           ; VIA_t1_cnt_lo = $80 (ensure correct scale)

; Set intensity (from stack)
PULS A                 ; Get intensity from stack
CMPA #$5F
BEQ DCR_intensity_5F
JSR Intensity_a
BRA DCR_after_intensity
DCR_intensity_5F:
JSR Intensity_5F
DCR_after_intensity:

; Move to start position: (xc + radius, yc)  [vertex 0 of 16-gon = rightmost]
; radius = DRAW_CIRCLE_TEMP, xc = DRAW_CIRCLE_TEMP+2, yc = DRAW_CIRCLE_TEMP+4
LDD DRAW_CIRCLE_TEMP   ; D = radius (16-bit)
ADDD DRAW_CIRCLE_TEMP+2 ; D = xc + radius
TFR B,B                ; Keep X in B (low byte)
PSHS B                 ; Save X on stack
LDD DRAW_CIRCLE_TEMP+4 ; Load yc
TFR B,A                ; Y to A
PULS B                 ; X to B
JSR Moveto_d

; Precompute 4 delta fractions using MUL (same fractions as constant 16-gon path)
; radius is at DRAW_CIRCLE_TEMP+1 (low byte, 0..127)
; DRAW_CIRCLE_TEMP+2..5 now free to reuse for a,b,c,d
; MUL: A * B -> D (unsigned); A_after = floor(frac * r) when frac byte = round(frac*256)
LDB DRAW_CIRCLE_TEMP+1 ; radius
LDA #98                ; 98/256 = 0.3828 ~ sin(22.5 deg) = 0.3827
MUL                    ; A = floor(0.3828 * r) = a
STA DRAW_CIRCLE_TEMP+2 ; Store a
LDB DRAW_CIRCLE_TEMP+1 ; radius
LDA #83                ; 83/256 = 0.3242 ~ 0.3244
MUL                    ; A = b
STA DRAW_CIRCLE_TEMP+3 ; Store b
LDB DRAW_CIRCLE_TEMP+1 ; radius
LDA #56                ; 56/256 = 0.2188 ~ 0.2168
MUL                    ; A = c
STA DRAW_CIRCLE_TEMP+4 ; Store c
LDB DRAW_CIRCLE_TEMP+1 ; radius
LDA #19                ; 19/256 = 0.0742 ~ 0.0761
MUL                    ; A = d
STA DRAW_CIRCLE_TEMP+5 ; Store d

; Draw 16 unrolled segments - 16-gon counterclockwise from (xc+r, yc)
; Draw_Line_d(A=dy, B=dx). Symmetry pattern by quadrant:
;   Q1 (0->90):   (+a,-d), (+b,-c), (+c,-b), (+d,-a)
;   Q2 (90->180): (-d,-a), (-c,-b), (-b,-c), (-a,-d)
;   Q3 (180->270):(-a,+d), (-b,+c), (-c,+b), (-d,+a)
;   Q4 (270->360):(+d,+a), (+c,+b), (+b,+c), (+a,+d)

; --- Q1 ---
; Seg 0: dy=+a, dx=-d
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+2  ; a
LDB DRAW_CIRCLE_TEMP+5  ; d
NEGB
JSR Draw_Line_d
; Seg 1: dy=+b, dx=-c
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+3  ; b
LDB DRAW_CIRCLE_TEMP+4  ; c
NEGB
JSR Draw_Line_d
; Seg 2: dy=+c, dx=-b
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+4  ; c
LDB DRAW_CIRCLE_TEMP+3  ; b
NEGB
JSR Draw_Line_d
; Seg 3: dy=+d, dx=-a
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+5  ; d
LDB DRAW_CIRCLE_TEMP+2  ; a
NEGB
JSR Draw_Line_d

; --- Q2 ---
; Seg 4: dy=-d, dx=-a
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+5  ; d
NEGA
LDB DRAW_CIRCLE_TEMP+2  ; a
NEGB
JSR Draw_Line_d
; Seg 5: dy=-c, dx=-b
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+4  ; c
NEGA
LDB DRAW_CIRCLE_TEMP+3  ; b
NEGB
JSR Draw_Line_d
; Seg 6: dy=-b, dx=-c
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+3  ; b
NEGA
LDB DRAW_CIRCLE_TEMP+4  ; c
NEGB
JSR Draw_Line_d
; Seg 7: dy=-a, dx=-d
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+2  ; a
NEGA
LDB DRAW_CIRCLE_TEMP+5  ; d
NEGB
JSR Draw_Line_d

; --- Q3 ---
; Seg 8: dy=-a, dx=+d
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+2  ; a
NEGA
LDB DRAW_CIRCLE_TEMP+5  ; d (positive)
JSR Draw_Line_d
; Seg 9: dy=-b, dx=+c
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+3  ; b
NEGA
LDB DRAW_CIRCLE_TEMP+4  ; c (positive)
JSR Draw_Line_d
; Seg 10: dy=-c, dx=+b
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+4  ; c
NEGA
LDB DRAW_CIRCLE_TEMP+3  ; b (positive)
JSR Draw_Line_d
; Seg 11: dy=-d, dx=+a
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+5  ; d
NEGA
LDB DRAW_CIRCLE_TEMP+2  ; a (positive)
JSR Draw_Line_d

; --- Q4 ---
; Seg 12: dy=+d, dx=+a
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+5  ; d (positive)
LDB DRAW_CIRCLE_TEMP+2  ; a (positive)
JSR Draw_Line_d
; Seg 13: dy=+c, dx=+b
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+4  ; c (positive)
LDB DRAW_CIRCLE_TEMP+3  ; b (positive)
JSR Draw_Line_d
; Seg 14: dy=+b, dx=+c
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+3  ; b (positive)
LDB DRAW_CIRCLE_TEMP+4  ; c (positive)
JSR Draw_Line_d
; Seg 15: dy=+a, dx=+d
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+2  ; a (positive)
LDB DRAW_CIRCLE_TEMP+5  ; d (positive)
JSR Draw_Line_d

LDA #$C8
TFR A,DP           ; Restore DP=$C8 before return
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
    ; VPy_LINE:11
    ; VPy_LINE:9
    LDD #0
    STD VAR_ANGLE
    ; VPy_LINE:12
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_ANGLE
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

    ; VPy_LINE:14
LOOP_BODY:
    LEAS -4,S ; allocate locals
    JSR Wait_Recal  ; CRITICAL: Sync with CRT refresh (50Hz frame timing)
    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access
    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)
    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access
    ; DEBUG: Statement 0 - Discriminant(8)
    ; VPy_LINE:15
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-50
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #90
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_0
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 15
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; DEBUG: Statement 1 - Discriminant(0)
    ; VPy_LINE:19
    LDD VAR_ANGLE
    STD RESULT
    LDD RESULT
    ANDB #$7F
    CLRA
    ASLB
    ROLA
    LDX #SIN_TABLE
    LDX #COS_TABLE
    ABX
    LDD ,X
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
    STD DIV_A
    LDD TMPRIGHT
    STD DIV_B
    JSR DIV16
    LDX RESULT
    STX 0 ,S
    ; DEBUG: Statement 2 - Discriminant(0)
    ; VPy_LINE:20
    LDD VAR_ANGLE
    STD RESULT
    LDD RESULT
    ANDB #$7F
    CLRA
    ASLB
    ROLA
    LDX #SIN_TABLE
    ABX
    LDD ,X
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
    STD DIV_A
    LDD TMPRIGHT
    STD DIV_B
    JSR DIV16
    LDX RESULT
    STX 2 ,S
    ; DEBUG: Statement 3 - Discriminant(8)
    ; VPy_LINE:23
    LDD 0 ,S
    STD RESULT
    LDB RESULT+1  ; xc (low byte, signed -128..127)
    STB DRAW_CIRCLE_XC
    LDD 2 ,S
    STD RESULT
    LDB RESULT+1  ; yc (low byte, signed -128..127)
    STB DRAW_CIRCLE_YC
    LDD #30
    STD RESULT
    LDB RESULT+1  ; diameter (low byte, 0..255)
    STB DRAW_CIRCLE_DIAM
    LDD #100
    STD RESULT
    LDB RESULT+1  ; intensity (low byte, 0..127)
    STB DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    ; DEBUG: Statement 4 - Discriminant(8)
    ; VPy_LINE:26
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$28
    JSR Intensity_a
    LDA #$FB
    ADDA VPY_MOVE_Y
    LDB #$00
    ADDB VPY_MOVE_X
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$0A
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP
    LDD #0
    STD RESULT
    ; DEBUG: Statement 5 - Discriminant(8)
    ; VPy_LINE:27
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$28
    JSR Intensity_a
    LDA #$00
    ADDA VPY_MOVE_Y
    LDB #$FB
    ADDB VPY_MOVE_X
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$0A
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP
    LDD #0
    STD RESULT
    ; DEBUG: Statement 6 - Discriminant(8)
    ; VPy_LINE:30
    LDA #$50
    JSR Intensity_a
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$00
    LDB #$15
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$08
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$07
    LDB #$FC
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$04
    LDB #$F9
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$F8
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$F8
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FC
    LDB #$F9
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$F9
    LDB #$FC
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$F8
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$F8
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$F9
    LDB #$04
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FC
    LDB #$07
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$08
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$08
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$04
    LDB #$07
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$07
    LDB #$04
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$08
    LDB #$02
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    ; DEBUG: Statement 7 - Discriminant(0)
    ; VPy_LINE:33
    LDD VAR_ANGLE
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
    LDU #VAR_ANGLE
    STU TMPPTR
    STX ,U
    ; DEBUG: Statement 8 - Discriminant(9)
    ; VPy_LINE:34
    LDD VAR_ANGLE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #127
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_2
    LDD #0
    STD RESULT
    BRA CE_3
CT_2:
    LDD #1
    STD RESULT
CE_3:
    LDD RESULT
    LBEQ IF_NEXT_1
    ; VPy_LINE:35
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_ANGLE
    STU TMPPTR
    STX ,U
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    LEAS 4,S ; free locals
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
; String literals (classic FCC + $80 terminator)
STR_0:
    FCC "SIN/COS"
    FCB $80
; Trig tables (shared)
SIN_TABLE:
    FDB 0
    FDB 6
    FDB 12
    FDB 19
    FDB 25
    FDB 31
    FDB 37
    FDB 43
    FDB 49
    FDB 54
    FDB 60
    FDB 65
    FDB 71
    FDB 76
    FDB 81
    FDB 85
    FDB 90
    FDB 94
    FDB 98
    FDB 102
    FDB 106
    FDB 109
    FDB 112
    FDB 115
    FDB 117
    FDB 120
    FDB 122
    FDB 123
    FDB 125
    FDB 126
    FDB 126
    FDB 127
    FDB 127
    FDB 127
    FDB 126
    FDB 126
    FDB 125
    FDB 123
    FDB 122
    FDB 120
    FDB 117
    FDB 115
    FDB 112
    FDB 109
    FDB 106
    FDB 102
    FDB 98
    FDB 94
    FDB 90
    FDB 85
    FDB 81
    FDB 76
    FDB 71
    FDB 65
    FDB 60
    FDB 54
    FDB 49
    FDB 43
    FDB 37
    FDB 31
    FDB 25
    FDB 19
    FDB 12
    FDB 6
    FDB 0
    FDB -6
    FDB -12
    FDB -19
    FDB -25
    FDB -31
    FDB -37
    FDB -43
    FDB -49
    FDB -54
    FDB -60
    FDB -65
    FDB -71
    FDB -76
    FDB -81
    FDB -85
    FDB -90
    FDB -94
    FDB -98
    FDB -102
    FDB -106
    FDB -109
    FDB -112
    FDB -115
    FDB -117
    FDB -120
    FDB -122
    FDB -123
    FDB -125
    FDB -126
    FDB -126
    FDB -127
    FDB -127
    FDB -127
    FDB -126
    FDB -126
    FDB -125
    FDB -123
    FDB -122
    FDB -120
    FDB -117
    FDB -115
    FDB -112
    FDB -109
    FDB -106
    FDB -102
    FDB -98
    FDB -94
    FDB -90
    FDB -85
    FDB -81
    FDB -76
    FDB -71
    FDB -65
    FDB -60
    FDB -54
    FDB -49
    FDB -43
    FDB -37
    FDB -31
    FDB -25
    FDB -19
    FDB -12
    FDB -6
COS_TABLE:
    FDB 127
    FDB 127
    FDB 126
    FDB 126
    FDB 125
    FDB 123
    FDB 122
    FDB 120
    FDB 117
    FDB 115
    FDB 112
    FDB 109
    FDB 106
    FDB 102
    FDB 98
    FDB 94
    FDB 90
    FDB 85
    FDB 81
    FDB 76
    FDB 71
    FDB 65
    FDB 60
    FDB 54
    FDB 49
    FDB 43
    FDB 37
    FDB 31
    FDB 25
    FDB 19
    FDB 12
    FDB 6
    FDB 0
    FDB -6
    FDB -12
    FDB -19
    FDB -25
    FDB -31
    FDB -37
    FDB -43
    FDB -49
    FDB -54
    FDB -60
    FDB -65
    FDB -71
    FDB -76
    FDB -81
    FDB -85
    FDB -90
    FDB -94
    FDB -98
    FDB -102
    FDB -106
    FDB -109
    FDB -112
    FDB -115
    FDB -117
    FDB -120
    FDB -122
    FDB -123
    FDB -125
    FDB -126
    FDB -126
    FDB -127
    FDB -127
    FDB -127
    FDB -126
    FDB -126
    FDB -125
    FDB -123
    FDB -122
    FDB -120
    FDB -117
    FDB -115
    FDB -112
    FDB -109
    FDB -106
    FDB -102
    FDB -98
    FDB -94
    FDB -90
    FDB -85
    FDB -81
    FDB -76
    FDB -71
    FDB -65
    FDB -60
    FDB -54
    FDB -49
    FDB -43
    FDB -37
    FDB -31
    FDB -25
    FDB -19
    FDB -12
    FDB -6
    FDB 0
    FDB 6
    FDB 12
    FDB 19
    FDB 25
    FDB 31
    FDB 37
    FDB 43
    FDB 49
    FDB 54
    FDB 60
    FDB 65
    FDB 71
    FDB 76
    FDB 81
    FDB 85
    FDB 90
    FDB 94
    FDB 98
    FDB 102
    FDB 106
    FDB 109
    FDB 112
    FDB 115
    FDB 117
    FDB 120
    FDB 122
    FDB 123
    FDB 125
    FDB 126
    FDB 126
    FDB 127
TAN_TABLE:
    FDB 0
    FDB 1
    FDB 2
    FDB 3
    FDB 4
    FDB 5
    FDB 6
    FDB 7
    FDB 8
    FDB 9
    FDB 11
    FDB 12
    FDB 13
    FDB 15
    FDB 16
    FDB 18
    FDB 20
    FDB 22
    FDB 24
    FDB 27
    FDB 30
    FDB 33
    FDB 37
    FDB 42
    FDB 48
    FDB 56
    FDB 66
    FDB 80
    FDB 101
    FDB 120
    FDB 120
    FDB 120
    FDB -120
    FDB -120
    FDB -120
    FDB -120
    FDB -101
    FDB -80
    FDB -66
    FDB -56
    FDB -48
    FDB -42
    FDB -37
    FDB -33
    FDB -30
    FDB -27
    FDB -24
    FDB -22
    FDB -20
    FDB -18
    FDB -16
    FDB -15
    FDB -13
    FDB -12
    FDB -11
    FDB -9
    FDB -8
    FDB -7
    FDB -6
    FDB -5
    FDB -4
    FDB -3
    FDB -2
    FDB -1
    FDB 0
    FDB 1
    FDB 2
    FDB 3
    FDB 4
    FDB 5
    FDB 6
    FDB 7
    FDB 8
    FDB 9
    FDB 11
    FDB 12
    FDB 13
    FDB 15
    FDB 16
    FDB 18
    FDB 20
    FDB 22
    FDB 24
    FDB 27
    FDB 30
    FDB 33
    FDB 37
    FDB 42
    FDB 48
    FDB 56
    FDB 66
    FDB 80
    FDB 101
    FDB 120
    FDB 120
    FDB 120
    FDB -120
    FDB -120
    FDB -120
    FDB -120
    FDB -101
    FDB -80
    FDB -66
    FDB -56
    FDB -48
    FDB -42
    FDB -37
    FDB -33
    FDB -30
    FDB -27
    FDB -24
    FDB -22
    FDB -20
    FDB -18
    FDB -16
    FDB -15
    FDB -13
    FDB -12
    FDB -11
    FDB -9
    FDB -8
    FDB -7
    FDB -6
    FDB -5
    FDB -4
    FDB -3
    FDB -2
    FDB -1
