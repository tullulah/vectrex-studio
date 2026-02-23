; --- Motorola 6809 backend (Vectrex) title='PRINT_NUMBER' origin=$0000 ---
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
    FCC "PRINT NUMBER"
    FCB $80
    FCB 0

;***************************************************************************
; CODE SECTION
;***************************************************************************

; === RAM VARIABLE DEFINITIONS (EQU) ===
; AUTO-GENERATED - All offsets calculated automatically
; Total RAM used: 34 bytes
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
NUM_STR              EQU $C880+$12   ; String buffer for PRINT_NUMBER (5 digits + terminator) (6 bytes)
VAR_COUNTER          EQU $C880+$18   ; User variable (2 bytes)
VAR_ARG0             EQU $C880+$1A   ; Function argument 0 (2 bytes)
VAR_ARG1             EQU $C880+$1C   ; Function argument 1 (2 bytes)
VAR_ARG2             EQU $C880+$1E   ; Function argument 2 (2 bytes)
VAR_ARG3             EQU $C880+$20   ; Function argument 3 (2 bytes)

    JMP START

;**** CONST DECLARATIONS (NUMBER-ONLY) ****

; === JOYSTICK BUILTIN SUBROUTINES ===
; J1_X() - Read Joystick 1 X axis (INCREMENTAL - with state preservation)
; Returns: D = raw value from $C81B after Joy_Analog call
J1X_BUILTIN:
    PSHS X       ; Save X (Joy_Analog uses it)
    JSR $F1AA    ; DP_to_D0 (required for Joy_Analog BIOS call)
    JSR $F1F5    ; Joy_Analog (updates $C81B from hardware)
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
    ; CRITICAL: Set VIA to DAC mode BEFORE calling BIOS (don't assume state)
    LDA #$98       ; VIA_cntl = $98 (DAC mode for text rendering)
    STA >$D00C     ; VIA_cntl
    LDA #$D0
    TFR A,DP       ; Set Direct Page to $D0 for BIOS
    LDU VAR_ARG2   ; string pointer (ARG2 = third param)
    LDA VAR_ARG1+1 ; Y (ARG1 = second param)
    LDB VAR_ARG0+1 ; X (ARG0 = first param)
    JSR Print_Str_d
    JSR $F1AF      ; DP_to_C8 (restore before return - CRITICAL for TMPPTR access)
    RTS
VECTREX_PRINT_NUMBER:
    ; Print decimal 0-9999
    ; ARG0=X, ARG1=Y, ARG2=value
    LDA #$98
    STA >$D00C     ; VIA DAC mode
    LDA #$D0
    TFR A,DP       ; DP=$D0
    
    LDD >VAR_ARG2
    LDX #NUM_STR
    
    ; Zero case
    CMPD #0
    BNE .PN_DIV1000
    LDA #'0'|$80
    STA ,X
    BRA .PN_MOVE
    
.PN_DIV1000:
    CLRA
.L1000: CMPD #1000
    BLT .D1000
    SUBD #1000
    INCA
    BRA .L1000
.D1000: ADDA #'0'
    STA ,X+
    
    CLRA
.L100:  CMPD #100
    BLT .D100
    SUBD #100
    INCA
    BRA .L100
.D100:  ADDA #'0'
    STA ,X+
    
    CLRA
.L10:   CMPD #10
    BLT .D10
    SUBD #10
    INCA
    BRA .L10
.D10:   ADDA #'0'
    STA ,X+
    
    ADDB #'0'|$80
    STB ,X
    
.PN_MOVE:
    LDA >VAR_ARG1+1
    LDB >VAR_ARG0+1
    JSR Moveto_d
    LDU #NUM_STR
    JSR Print_Str_d
    JSR $F1AF
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
    ; VPy_LINE:10
    ; VPy_LINE:8
    LDD #0
    STD VAR_COUNTER
    ; VPy_LINE:11
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_COUNTER
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
    ; *** Call loop() as subroutine (executed every frame)
    JSR LOOP_BODY
    BRA MAIN

    ; VPy_LINE:13
LOOP_BODY:
    JSR Wait_Recal  ; CRITICAL: Sync with CRT refresh (50Hz frame timing)
    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access
    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)
    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access
    ; DEBUG: Statement 0 - Discriminant(8)
    ; VPy_LINE:15
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-80
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
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 15
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; DEBUG: Statement 1 - Discriminant(8)
    ; VPy_LINE:16
    LDD #-40
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #80
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDD VAR_COUNTER
    STD RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_NUMBER at line 16
    JSR VECTREX_PRINT_NUMBER
    CLRA
    CLRB
    STD RESULT
    ; DEBUG: Statement 2 - Discriminant(8)
    ; VPy_LINE:19
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-80
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-50
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_1
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 19
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; DEBUG: Statement 3 - Discriminant(8)
    ; VPy_LINE:20
    LDD #-40
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-50
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDD #12345
    STD RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_NUMBER at line 20
    JSR VECTREX_PRINT_NUMBER
    CLRA
    CLRB
    STD RESULT
    ; DEBUG: Statement 4 - Discriminant(0)
    ; VPy_LINE:23
    LDD VAR_COUNTER
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
    LDU #VAR_COUNTER
    STU TMPPTR
    STX ,U
    ; DEBUG: Statement 5 - Discriminant(9)
    ; VPy_LINE:25
    LDD VAR_COUNTER
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #650
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
    ; VPy_LINE:26
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_COUNTER
    STU TMPPTR
    STX ,U
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    RTS

;***************************************************************************
; DATA SECTION
;***************************************************************************
; String literals (classic FCC + $80 terminator)
STR_0:
    FCC "COUNTER"
    FCB $80
STR_1:
    FCC "VAL"
    FCB $80
