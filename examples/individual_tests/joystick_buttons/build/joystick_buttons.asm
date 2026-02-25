; VPy M6809 Assembly (Vectrex)
; ROM: 32768 bytes


    ORG $0000

;***************************************************************************
; DEFINE SECTION
;***************************************************************************
    INCLUDE "VECTREX.I"

;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "J1_BUTTONS"
    FCB $80                 ; String terminator
    FCB 0                   ; End of header

;***************************************************************************
; CODE SECTION
;***************************************************************************

START:
    LDA #$D0
    TFR A,DP        ; Set Direct Page for BIOS
    CLR $C80E        ; Initialize Vec_Prev_Btns
    LDA #$80
    STA VIA_t1_cnt_lo
    LDX #Vec_Default_Stk ; Same stack as BIOS default ($CBEA)
    TFR X,S
    ; Initialize bank tracking vars to 0 (prevents spurious $DF00 writes)
    LDA #0
    STA >CURRENT_ROM_BANK   ; Bank 0 is always active at boot
    JMP MAIN

;***************************************************************************
; === RAM VARIABLE DEFINITIONS ===
;***************************************************************************
RESULT               EQU $C880+$00   ; Main result temporary (2 bytes)
TMPVAL               EQU $C880+$02   ; Temporary value storage (alias for RESULT) (2 bytes)
TMPPTR               EQU $C880+$04   ; Temporary pointer (2 bytes)
TMPPTR2              EQU $C880+$06   ; Temporary pointer 2 (2 bytes)
TEMP_YX              EQU $C880+$08   ; Temporary Y/X coordinate storage (2 bytes)
NUM_STR              EQU $C880+$0A   ; Buffer for PRINT_NUMBER decimal output (5 digits + terminator) (6 bytes)
DRAW_CIRCLE_XC       EQU $C880+$10   ; Circle center X (1 bytes)
DRAW_CIRCLE_YC       EQU $C880+$11   ; Circle center Y (1 bytes)
DRAW_CIRCLE_DIAM     EQU $C880+$12   ; Circle diameter (1 bytes)
DRAW_CIRCLE_INTENSITY EQU $C880+$13   ; Circle intensity (1 bytes)
DRAW_CIRCLE_RADIUS   EQU $C880+$14   ; Circle radius (diam/2) - used in segment drawing (1 bytes)
DRAW_CIRCLE_TEMP     EQU $C880+$15   ; Circle temporary buffer (8 bytes: radius16, xc16, yc16, r/4, 3r/4) (8 bytes)
DRAW_LINE_ARGS       EQU $C880+$1D   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$27   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$29   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$2B   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$2C   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$2D   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$2F   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
VAR_BTN1             EQU $C880+$31   ; User variable: BTN1 (2 bytes)
VAR_BTN2             EQU $C880+$33   ; User variable: BTN2 (2 bytes)
VAR_BTN3             EQU $C880+$35   ; User variable: BTN3 (2 bytes)
VAR_BTN4             EQU $C880+$37   ; User variable: BTN4 (2 bytes)
VAR_ARG0             EQU $CB80   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $CB82   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $CB84   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $CB86   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $CB88   ; Function argument 4 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $CB8A   ; Current ROM bank ID (multibank tracking) (1 bytes)


;***************************************************************************
; MAIN PROGRAM
;***************************************************************************

MAIN:
    ; Initialize global variables
    ; === Initialize Joystick (one-time setup) ===
    JSR $F1AF    ; DP_to_C8 (required for RAM access)
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

    ; Call main() for initialization
    ; TODO: Statement Pass { source_line: 9 }

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access
    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)
    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access
    LDA $C811      ; Vec_Button_1_1 (transition bits, rising edge = debounce)
    ANDA #$01      ; Test bit 0 (Button 1)
    LBEQ .J1B1_0_OFF
    LDD #1
    LBRA .J1B1_0_END
.J1B1_0_OFF:
    LDD #0
.J1B1_0_END:
    STD RESULT
    LDD RESULT
    STD VAR_BTN1
    LDA $C811      ; Vec_Button_1_1 (transition bits, rising edge = debounce)
    ANDA #$02      ; Test bit 1 (Button 2)
    LBEQ .J1B2_1_OFF
    LDD #1
    LBRA .J1B2_1_END
.J1B2_1_OFF:
    LDD #0
.J1B2_1_END:
    STD RESULT
    LDD RESULT
    STD VAR_BTN2
    LDA $C811      ; Vec_Button_1_1 (transition bits, rising edge = debounce)
    ANDA #$04      ; Test bit 2 (Button 3)
    LBEQ .J1B3_2_OFF
    LDD #1
    LBRA .J1B3_2_END
.J1B3_2_OFF:
    LDD #0
.J1B3_2_END:
    STD RESULT
    LDD RESULT
    STD VAR_BTN3
    LDA $C811      ; Vec_Button_1_1 (transition bits, rising edge = debounce)
    ANDA #$08      ; Test bit 3 (Button 4)
    LBEQ .J1B4_3_OFF
    LDD #1
    LBRA .J1B4_3_END
.J1B4_3_OFF:
    LDD #0
.J1B4_3_END:
    STD RESULT
    LDD RESULT
    STD VAR_BTN4
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #80
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2049397      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_ARG0    ; X position
    LDD #80
    STD RESULT
    LDD RESULT
    STD VAR_ARG1    ; Y position
    LDD >VAR_BTN1
    STD RESULT
    LDD RESULT
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #60
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2049398      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_ARG0    ; X position
    LDD #60
    STD RESULT
    LDD RESULT
    STD VAR_ARG1    ; Y position
    LDD >VAR_BTN2
    STD RESULT
    LDD RESULT
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #40
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2049399      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_ARG0    ; X position
    LDD #40
    STD RESULT
    LDD RESULT
    STD VAR_ARG1    ; Y position
    LDD >VAR_BTN3
    STD RESULT
    LDD RESULT
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #20
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2049400      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_ARG0    ; X position
    LDD #20
    STD RESULT
    LDD RESULT
    STD VAR_ARG1    ; Y position
    LDD >VAR_BTN4
    STD RESULT
    LDD RESULT
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN1
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_1
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD #-40
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_XC
    LDD #0
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_YC
    LDD #10
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_DIAM
    LDD #80
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN2
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_3
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD #0
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_XC
    LDD #0
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_YC
    LDD #10
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_DIAM
    LDD #80
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN3
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_5
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD #40
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_XC
    LDD #0
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_YC
    LDD #10
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_DIAM
    LDD #80
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN4
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_3_TRUE
    LDD #0
    LBRA .CMP_3_END
.CMP_3_TRUE:
    LDD #1
.CMP_3_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_7
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD #0
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_XC
    LDD #-40
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_YC
    LDD #10
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_DIAM
    LDD #80
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
    RTS

;***************************************************************************
; RUNTIME HELPERS
;***************************************************************************

VECTREX_PRINT_TEXT:
    ; VPy signature: PRINT_TEXT(x, y, string)
    ; BIOS signature: Print_Str_d(A=Y, B=X, U=string)
    ; NOTE: Do NOT set VIA_cntl=$98 here - would release /ZERO prematurely
    ;       causing integrators to drift toward joystick DAC value.
    ;       Moveto_d_7F (called by Print_Str_d) handles VIA_cntl via $CE.
    LDA #$D0
    TFR A,DP       ; Set Direct Page to $D0 for BIOS
    JSR Intensity_5F ; Ensure consistent text brightness (DP=$D0 required)
    JSR Reset0Ref   ; Reset beam to center before positioning text
    LDU VAR_ARG2   ; string pointer
    LDA >VAR_ARG1+1 ; Y coordinate
    LDB >VAR_ARG0+1 ; X coordinate
    JSR Print_Str_d
    LDA #$80
    STA >$D004      ; Restore VIA_t1_cnt_lo: Moveto_d_7F sets it to $7F, corrupting DRAW_LINE scale
    JSR $F1AF      ; DP_to_C8 - restore DP before return
    RTS

VECTREX_PRINT_NUMBER:
    ; Print signed decimal number (-9999 to 9999)
    ; ARG0=x, ARG1=y, ARG2=value
    ;
    ; STEP 1: Convert number to decimal string (DP=$C8)
    LDD >VAR_ARG2   ; Load 16-bit value (safe: DP=$C8)
    STD >TMPVAL      ; Save to temp
    LDX #NUM_STR    ; String buffer pointer
    
    ; Check sign: negative values get '-' prefix and are negated
    CMPD #0
    BPL .PN_DIV1000  ; D >= 0: go directly to digit conversion
    LDA #'-'
    STA ,X+          ; Store '-', advance buffer pointer
    LDD >TMPVAL
    COMA
    COMB
    ADDD #1          ; Two's complement negation -> absolute value
    STD >TMPVAL
    
    ; --- 1000s digit ---
.PN_DIV1000:
    CLR ,X           ; Counter = 0 (in buffer)
.PN_L1000:
    LDD >TMPVAL
    SUBD #1000
    BMI .PN_D1000
    STD >TMPVAL      ; Store reduced value
    INC ,X           ; Increment digit counter
    BRA .PN_L1000
.PN_D1000:
    LDA ,X           ; Get count
    ADDA #'0'        ; Convert to ASCII
    STA ,X+          ; Store and advance
    
    ; --- 100s digit ---
    CLR ,X
.PN_L100:
    LDD >TMPVAL
    SUBD #100
    BMI .PN_D100
    STD >TMPVAL
    INC ,X
    BRA .PN_L100
.PN_D100:
    LDA ,X
    ADDA #'0'
    STA ,X+
    
    ; --- 10s digit ---
    CLR ,X
.PN_L10:
    LDD >TMPVAL
    SUBD #10
    BMI .PN_D10
    STD >TMPVAL
    INC ,X
    BRA .PN_L10
.PN_D10:
    LDA ,X
    ADDA #'0'
    STA ,X+
    
    ; --- 1s digit (remainder) ---
    LDD >TMPVAL
    ADDB #'0'        ; Low byte = ones digit
    STB ,X+          ; Store digit
    LDA #$80          ; Terminator (same format as FCC/FCB $80 strings)
    STA ,X
    
.PN_AFTER_CONVERT:
    ; STEP 2: Set up BIOS and print (NOW change DP to $D0)
    ; NOTE: Do NOT set VIA_cntl=$98 - would release /ZERO prematurely
    LDA #$D0
    TFR A,DP         ; Set Direct Page to $D0 for BIOS (inline - JSR $F1AA unreliable in emulator)
    JSR Reset0Ref    ; Reset beam to center before positioning text
    LDA >VAR_ARG1+1  ; Y coordinate
    LDB >VAR_ARG0+1  ; X coordinate
    LDU #NUM_STR     ; String pointer
    JSR Print_Str_d  ; Print using BIOS (A=Y, B=X, U=string)
    LDA #$80
    STA >$D004      ; Restore VIA_t1_cnt_lo: Moveto_d_7F sets it to $7F, corrupting DRAW_LINE scale
    JSR $F1AF      ; Restore DP to $C8
    RTS

MOD16:
    ; Signed 16-bit modulo: D = X % D (result has same sign as dividend)
    ; X = dividend (i16), D = divisor (i16) -> D = remainder
    STD TMPPTR          ; Save divisor
    TFR X,D             ; D = dividend (TFR does NOT set flags!)
    CMPD #0             ; Set flags from FULL D BEFORE any LDA corrupts high byte
    BPL .M16_DPOS       ; if dividend >= 0, skip negation
    COMA
    COMB
    ADDD #1             ; D = |dividend|
    STD TMPVAL          ; store |dividend| BEFORE LDA corrupts A (high byte of D)
    LDA #1
    STA TMPPTR2         ; sign_flag = 1
    BRA .M16_RCHECK
.M16_DPOS:
    STD TMPVAL          ; dividend is positive, store as-is
    LDA #0
    STA TMPPTR2         ; sign_flag = 0 (positive result)
.M16_RCHECK:
    LDD TMPPTR          ; D = divisor
    BPL .M16_RPOS       ; if divisor >= 0, skip negation
    COMA
    COMB
    ADDD #1             ; D = |divisor|
    STD TMPPTR          ; TMPPTR = |divisor|
.M16_RPOS:
.M16_LOOP:
    LDD TMPVAL
    SUBD TMPPTR         ; |dividend| - |divisor|
    BLO .M16_END        ; if |dividend| < |divisor|, done
    STD TMPVAL          ; update remainder
    BRA .M16_LOOP
.M16_END:
    LDD TMPVAL          ; D = |remainder|
    LDA TMPPTR2
    BEQ .M16_DONE       ; zero = positive result
    COMA
    COMB
    ADDD #1             ; negate (same sign as dividend)
.M16_DONE:
    RTS

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

LDA #$C8
TFR A,DP           ; Restore DP=$C8 before return
RTS

;**** PRINT_TEXT String Data ****
PRINT_TEXT_STR_2049397:
    FCC "BTN1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2049398:
    FCC "BTN2"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2049399:
    FCC "BTN3"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2049400:
    FCC "BTN4"
    FCB $80          ; Vectrex string terminator

