; --- Motorola 6809 backend (Vectrex) title='JOYSTICK_POS' origin=$0000 ---
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
    FCC "JOYSTICK POS"
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
NUM_STR              EQU $C880+$1A   ; String buffer for PRINT_NUMBER (5 digits + terminator) (6 bytes)
DRAW_CIRCLE_XC       EQU $C880+$20   ; Circle center X (byte) (1 bytes)
DRAW_CIRCLE_YC       EQU $C880+$21   ; Circle center Y (byte) (1 bytes)
DRAW_CIRCLE_DIAM     EQU $C880+$22   ; Circle diameter (byte) (1 bytes)
DRAW_CIRCLE_INTENSITY EQU $C880+$23   ; Circle intensity (byte) (1 bytes)
DRAW_CIRCLE_TEMP     EQU $C880+$24   ; Circle drawing temporaries (radius=2, xc=2, yc=2, spare=2) (8 bytes)
VAR_X                EQU $C880+$2C   ; User variable (2 bytes)
VAR_Y                EQU $C880+$2E   ; User variable (2 bytes)
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
    ; CRITICAL: Print_Str_d requires DP=$D0 and signature is (Y, X, string)
    ; VPy signature: PRINT_TEXT(x, y, string) -> args (ARG0=x, ARG1=y, ARG2=string)
    ; BIOS signature: Print_Str_d(A=Y, B=X, U=string)
    ; NOTE: Do NOT set VIA_cntl here - Reset0Int already set $CC (/ZERO active)
    ;       Setting $98 would release /ZERO prematurely, causing integrators to drift
    ;       toward joystick DAC value. Let Moveto_d_7F handle VIA_cntl via $CE.
    LDA #$D0
    TFR A,DP       ; Set Direct Page to $D0 for BIOS
    LDU VAR_ARG2   ; string pointer (ARG2 = third param)
    LDA VAR_ARG1+1 ; Y (ARG1 = second param)
    LDB VAR_ARG0+1 ; X (ARG0 = first param)
    JSR Print_Str_d
    JSR $F1AF      ; DP_to_C8 (restore before return - CRITICAL for TMPPTR access)
    RTS
VECTREX_PRINT_NUMBER:
    ; Print signed decimal number (-9999 to 9999)
    ; ARG0=X, ARG1=Y, ARG2=value
    ; STEP 1: Convert number to decimal string (DP=$C8)
    LDD >VAR_ARG2   ; Load 16-bit value (safe: DP=$C8)
    STD >RESULT      ; Save to temp
    LDX #NUM_STR    ; String buffer pointer
    ; Check sign: negative values get '-' prefix and are negated
    CMPD #0
    BPL .PN_DIV1000  ; D >= 0: go directly to digit conversion
    LDA #'-'
    STA ,X+          ; Store '-', advance buffer pointer
    LDD >RESULT
    COMA
    COMB
    ADDD #1          ; Two's complement negation -> absolute value
    STD >RESULT
    ; --- 1000s digit ---
.PN_DIV1000:
    CLR ,X           ; Counter = 0 (in buffer)
.PN_L1000:
    LDD >RESULT
    SUBD #1000
    BMI .PN_D1000
    STD >RESULT
    INC ,X
    BRA .PN_L1000
.PN_D1000:
    LDA ,X
    ADDA #'0'
    STA ,X+
    ; --- 100s digit ---
    CLR ,X
.PN_L100:
    LDD >RESULT
    SUBD #100
    BMI .PN_D100
    STD >RESULT
    INC ,X
    BRA .PN_L100
.PN_D100:
    LDA ,X
    ADDA #'0'
    STA ,X+
    ; --- 10s digit ---
    CLR ,X
.PN_L10:
    LDD >RESULT
    SUBD #10
    BMI .PN_D10
    STD >RESULT
    INC ,X
    BRA .PN_L10
.PN_D10:
    LDA ,X
    ADDA #'0'
    STA ,X+
    ; --- 1s digit (remainder) ---
    LDD >RESULT
    ADDB #'0'
    STB ,X+
    LDA #$80          ; Terminator (same format as FCC/FCB strings)
    STA ,X
.PN_AFTER_CONVERT:
    ; STEP 2: Set up BIOS and print (NOW change DP to $D0)
    ; NOTE: Do NOT set VIA_cntl=$98 here - would prematurely release /ZERO
    LDA #$D0
    TFR A,DP         ; Set Direct Page to $D0 for BIOS
    LDA >VAR_ARG1+1  ; Y coordinate
    LDB >VAR_ARG0+1  ; X coordinate
    LDU #NUM_STR     ; String pointer
    JSR Print_Str_d  ; Print using BIOS (A=Y, B=X, U=string)
    JSR $F1AF        ; DP_to_C8 - restore DP
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
; Uses 8 segments (regular octagon inscribed in circle) with unrolled loop
DRAW_CIRCLE_RUNTIME:
; Read ALL parameters into registers/stack BEFORE changing DP (critical!)
; (These are byte variables, use LDB not LDD)
LDB DRAW_CIRCLE_INTENSITY
PSHS B                 ; Save intensity on stack

LDB DRAW_CIRCLE_DIAM
SEX                    ; Sign-extend to 16-bit (diameter is unsigned 0..255)
LSRA                   ; Divide by 2 to get radius
RORB
STD DRAW_CIRCLE_TEMP   ; DRAW_CIRCLE_TEMP = radius (16-bit)

LDB DRAW_CIRCLE_XC     ; xc (signed -128..127)
SEX
STD DRAW_CIRCLE_TEMP+2 ; Save xc

LDB DRAW_CIRCLE_YC     ; yc (signed -128..127)
SEX
STD DRAW_CIRCLE_TEMP+4 ; Save yc

; NOW safe to setup BIOS (all params are in DRAW_CIRCLE_TEMP+stack)
LDA #$D0
TFR A,DP
JSR Reset0Ref

; Set intensity (from stack)
PULS A                 ; Get intensity from stack
CMPA #$5F
BEQ DCR_intensity_5F
JSR Intensity_a
BRA DCR_after_intensity
DCR_intensity_5F:
JSR Intensity_5F
DCR_after_intensity:

; Move to start position: (xc + radius, yc)
; radius = DRAW_CIRCLE_TEMP, xc = DRAW_CIRCLE_TEMP+2, yc = DRAW_CIRCLE_TEMP+4
LDD DRAW_CIRCLE_TEMP   ; D = radius
ADDD DRAW_CIRCLE_TEMP+2 ; D = xc + radius
TFR B,B                ; Keep X in B (low byte)
PSHS B                 ; Save X on stack
LDD DRAW_CIRCLE_TEMP+4 ; Load yc
TFR B,A                ; Y to A
PULS B                 ; X to B
JSR Moveto_d

; Precompute r/4 and 3r/4 for regular octagon segments
; Radius low byte is at DRAW_CIRCLE_TEMP+1
LDB DRAW_CIRCLE_TEMP+1 ; Load radius (low byte)
LSRB
LSRB                   ; B = r/4
STB DRAW_CIRCLE_TEMP+6 ; Save r/4 in spare byte
LDB DRAW_CIRCLE_TEMP+1 ; Load radius
SUBB DRAW_CIRCLE_TEMP+6 ; B = r - r/4 = 3r/4
STB DRAW_CIRCLE_TEMP+7 ; Save 3r/4 in spare byte

; Draw 8 unrolled segments - regular octagon inscribed in circle
; Counterclockwise from rightmost point (xc+r, yc)
; Draw_Line_d(A=dy, B=dx)

; Seg 0 (0->45 deg): dy=+3r/4, dx=-r/4
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+7  ; 3r/4
LDB DRAW_CIRCLE_TEMP+6  ; r/4
NEGB
JSR Draw_Line_d

; Seg 1 (45->90 deg): dy=+r/4, dx=-3r/4
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+6  ; r/4
LDB DRAW_CIRCLE_TEMP+7  ; 3r/4
NEGB
JSR Draw_Line_d

; Seg 2 (90->135 deg): dy=-r/4, dx=-3r/4
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+6  ; r/4
NEGA
LDB DRAW_CIRCLE_TEMP+7  ; 3r/4
NEGB
JSR Draw_Line_d

; Seg 3 (135->180 deg): dy=-3r/4, dx=-r/4
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+7  ; 3r/4
NEGA
LDB DRAW_CIRCLE_TEMP+6  ; r/4
NEGB
JSR Draw_Line_d

; Seg 4 (180->225 deg): dy=-3r/4, dx=+r/4
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+7  ; 3r/4
NEGA
LDB DRAW_CIRCLE_TEMP+6  ; r/4 (positive)
JSR Draw_Line_d

; Seg 5 (225->270 deg): dy=-r/4, dx=+3r/4
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+6  ; r/4
NEGA
LDB DRAW_CIRCLE_TEMP+7  ; 3r/4 (positive)
JSR Draw_Line_d

; Seg 6 (270->315 deg): dy=+r/4, dx=+3r/4
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+6  ; r/4 (positive)
LDB DRAW_CIRCLE_TEMP+7  ; 3r/4 (positive)
JSR Draw_Line_d

; Seg 7 (315->360 deg): dy=+3r/4, dx=+r/4
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+7  ; 3r/4 (positive)
LDB DRAW_CIRCLE_TEMP+6  ; r/4 (positive)
JSR Draw_Line_d

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
    ; VPy_LINE:12
    ; VPy_LINE:9
    LDD #0
    STD VAR_X
    ; VPy_LINE:10
    LDD #0
    STD VAR_Y
    ; VPy_LINE:13
    ; pass (no-op)

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
    ; *** Call loop() as subroutine (executed every frame)
    JSR LOOP_BODY
    BRA MAIN

    ; VPy_LINE:15
LOOP_BODY:
    LEAS -4,S ; allocate locals
    JSR Wait_Recal  ; CRITICAL: Sync with CRT refresh (50Hz frame timing)
    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access
    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)
    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access
    ; DEBUG: Statement 0 - Discriminant(0)
    ; VPy_LINE:17
; NATIVE_CALL: J1_X at line 17
    JSR J1X_BUILTIN
    STD RESULT
    LDX RESULT
    LDU #VAR_X
    STU TMPPTR
    STX ,U
    ; DEBUG: Statement 1 - Discriminant(0)
    ; VPy_LINE:18
; NATIVE_CALL: J1_Y at line 18
    JSR J1Y_BUILTIN
    STD RESULT
    LDX RESULT
    LDU #VAR_Y
    STU TMPPTR
    STX ,U
    ; DEBUG: Statement 2 - Discriminant(8)
    ; VPy_LINE:21
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-60
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #80
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_0
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 21
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; DEBUG: Statement 3 - Discriminant(8)
    ; VPy_LINE:22
    LDD #10
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #80
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDD VAR_X
    STD RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_NUMBER at line 22
    JSR VECTREX_PRINT_NUMBER
    CLRA
    CLRB
    STD RESULT
    ; DEBUG: Statement 4 - Discriminant(8)
    ; VPy_LINE:24
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-60
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #60
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_1
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 24
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; DEBUG: Statement 5 - Discriminant(8)
    ; VPy_LINE:25
    LDD #10
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #60
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDD VAR_Y
    STD RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_NUMBER at line 25
    JSR VECTREX_PRINT_NUMBER
    CLRA
    CLRB
    STD RESULT
    ; DEBUG: Statement 6 - Discriminant(0)
    ; VPy_LINE:29
    LDD VAR_X
    STD RESULT
    LDD RESULT
    LSRA
    RORB
    STD RESULT
    LDX RESULT
    STX 0 ,S
    ; DEBUG: Statement 7 - Discriminant(0)
    ; VPy_LINE:30
    LDD VAR_Y
    STD RESULT
    LDD RESULT
    LSRA
    RORB
    STD RESULT
    LDX RESULT
    STX 2 ,S
    ; DEBUG: Statement 8 - Discriminant(8)
    ; VPy_LINE:31
    LDD 0 ,S
    STD RESULT
    LDB RESULT+1  ; xc (low byte, signed -128..127)
    STB DRAW_CIRCLE_XC
    LDD 2 ,S
    STD RESULT
    LDB RESULT+1  ; yc (low byte, signed -128..127)
    STB DRAW_CIRCLE_YC
    LDD #15
    STD RESULT
    LDB RESULT+1  ; diameter (low byte, 0..255)
    STB DRAW_CIRCLE_DIAM
    LDD #80
    STD RESULT
    LDB RESULT+1  ; intensity (low byte, 0..127)
    STB DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    LEAS 4,S ; free locals
    RTS

DIV16:
    LDD #0
    STD DIV_Q
    LDD DIV_A
    STD DIV_R
    LDD DIV_B
    BEQ DIV16_DONE
DIV16_LOOP:
    LDD DIV_R
    SUBD DIV_B
    BLO DIV16_DONE
    STD DIV_R
    LDD DIV_Q
    ADDD #1
    STD DIV_Q
    BRA DIV16_LOOP
DIV16_DONE:
    LDD DIV_Q
    STD RESULT
    RTS

;***************************************************************************
; DATA SECTION
;***************************************************************************
; String literals (classic FCC + $80 terminator)
STR_0:
    FCC "POS X"
    FCB $80
STR_1:
    FCC "POS Y"
    FCB $80
