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
    FCC "FADE"
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
VPY_MOVE_X           EQU $C880+$08   ; MOVE() current X offset (signed byte, 0 by default) (1 bytes)
VPY_MOVE_Y           EQU $C880+$09   ; MOVE() current Y offset (signed byte, 0 by default) (1 bytes)
TEMP_YX              EQU $C880+$0A   ; Temporary Y/X coordinate storage (2 bytes)
DRAW_LINE_ARGS       EQU $C880+$0C   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$16   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$18   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$1A   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$1B   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$1C   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$1E   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
VAR_BRIGHTNESS       EQU $C880+$20   ; User variable: BRIGHTNESS (2 bytes)
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
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    LDD #100
    STD VAR_BRIGHTNESS
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
    LDD #100
    STD RESULT
    LDD RESULT
    STD VAR_BRIGHTNESS

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access
    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)
    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #90
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_1817025702533201      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-80
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #70
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_166972285132112481      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
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
    LBEQ IF_NEXT_1
    LDD #5
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BRIGHTNESS
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_3
    LDD >VAR_BRIGHTNESS
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #5
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDD RESULT
    STD VAR_BRIGHTNESS
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
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
    LBEQ IF_NEXT_5
    LDD #120
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BRIGHTNESS
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_7
    LDD >VAR_BRIGHTNESS
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #5
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_BRIGHTNESS
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #-40
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #-40
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #40
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #-40
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+6    ; y1
    LDD >VAR_BRIGHTNESS
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #40
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #-40
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #40
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #40
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+6    ; y1
    LDD >VAR_BRIGHTNESS
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #40
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #40
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #-40
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #40
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+6    ; y1
    LDD >VAR_BRIGHTNESS
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #-40
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #40
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #-40
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #-40
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+6    ; y1
    LDD >VAR_BRIGHTNESS
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #-40
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #-40
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #40
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #40
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+6    ; y1
    LDD >VAR_BRIGHTNESS
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #40
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #-40
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #-40
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #40
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+6    ; y1
    LDD >VAR_BRIGHTNESS
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
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

; DRAW_LINE unified wrapper - handles 16-bit signed coordinates
; Args: DRAW_LINE_ARGS+0=x0, +2=y0, +4=x1, +6=y1, +8=intensity
; Resets beam to center, moves to (x0,y0), draws to (x1,y1)
DRAW_LINE_WRAPPER:
    ; Set DP to hardware registers
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref   ; Reset beam to center (0,0) before positioning
    LDA #$80
    STA <$04        ; VIA_t1_cnt_lo = $80 (ensure correct scale regardless of prior builtins)
    ; ALWAYS set intensity (no optimization)
    LDA >DRAW_LINE_ARGS+8+1  ; intensity (low byte) - EXTENDED addressing
    JSR Intensity_a
    ; Move to start position (y in A, x in B) - use low bytes (8-bit signed -127..+127)
    LDA >DRAW_LINE_ARGS+2+1  ; Y start (low byte) - EXTENDED addressing
    ADDA >VPY_MOVE_Y         ; Add MOVE Y offset
    LDB >DRAW_LINE_ARGS+0+1  ; X start (low byte) - EXTENDED addressing
    ADDB >VPY_MOVE_X         ; Add MOVE X offset
    JSR Moveto_d
    ; Compute deltas using 16-bit arithmetic
    ; dx = x1 - x0 (treating as signed 16-bit)
    LDD >DRAW_LINE_ARGS+4    ; x1 (16-bit) - EXTENDED
    SUBD >DRAW_LINE_ARGS+0   ; subtract x0 (16-bit) - EXTENDED
    STD >VLINE_DX_16 ; Store full 16-bit dx - EXTENDED
    ; dy = y1 - y0 (treating as signed 16-bit)
    LDD >DRAW_LINE_ARGS+6    ; y1 (16-bit) - EXTENDED
    SUBD >DRAW_LINE_ARGS+2   ; subtract y0 (16-bit) - EXTENDED
    STD >VLINE_DY_16 ; Store full 16-bit dy - EXTENDED
    ; SEGMENT 1: Clamp dy to ±127 and draw
    LDD >VLINE_DY_16 ; Load full dy - EXTENDED
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
    LDA >VLINE_DY_16+1  ; Use original low byte - EXTENDED
DLW_SEG1_DY_READY:
    STA >VLINE_DY    ; Save clamped dy for segment 1 - EXTENDED
    ; Clamp dx to ±127
    LDD >VLINE_DX_16  ; EXTENDED
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
    LDB >VLINE_DX_16+1  ; Use original low byte - EXTENDED
DLW_SEG1_DX_READY:
    STB >VLINE_DX    ; Save clamped dx for segment 1 - EXTENDED
    ; Draw segment 1
    CLR Vec_Misc_Count
    LDA >VLINE_DY  ; EXTENDED
    LDB >VLINE_DX  ; EXTENDED
    JSR Draw_Line_d ; Beam moves automatically
    ; Check if we need SEGMENT 2 (dy outside ±127 range)
    LDD >VLINE_DY_16 ; Reload original dy - EXTENDED
    CMPD #127
    BGT DLW_NEED_SEG2  ; dy > 127: needs segment 2
    CMPD #-128
    BLT DLW_NEED_SEG2  ; dy < -128: needs segment 2
    BRA DLW_DONE       ; dy in range ±127: no segment 2
DLW_NEED_SEG2:
    ; SEGMENT 2: Draw remaining dy and dx
    ; Calculate remaining dy
    LDD >VLINE_DY_16 ; Load original full dy - EXTENDED
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
    STD >VLINE_DY_REMAINING  ; Store remaining dy (16-bit) - EXTENDED
    ; Calculate remaining dx
    LDD >VLINE_DX_16 ; Load original full dx - EXTENDED
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
    STD >VLINE_DX_REMAINING  ; Store remaining dx (16-bit) - EXTENDED
    ; Setup for Draw_Line_d: A=dy, B=dx (CRITICAL: order matters!)
    LDA >VLINE_DY_REMAINING+1  ; Low byte of remaining dy - EXTENDED
    LDB >VLINE_DX_REMAINING+1  ; Low byte of remaining dx - EXTENDED
    CLR Vec_Misc_Count
    JSR Draw_Line_d ; Beam continues from segment 1 endpoint
DLW_DONE:
    LDA #$C8       ; CRITICAL: Restore DP to $C8 for our code
    TFR A,DP
    RTS

;**** PRINT_TEXT String Data ****
PRINT_TEXT_STR_1817025702533201:
    FCC "BRIGHTNESS"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_166972285132112481:
    FCC "B1=DIM B2=BRIGHT"
    FCB $80          ; Vectrex string terminator

