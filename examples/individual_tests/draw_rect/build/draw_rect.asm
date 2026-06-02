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
    FCC "DRAW_RECT"
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
    LDS #$CFFF       ; Stack -> top of Vectrex 2KB RAM (avoids user var collision)

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
BTN_PREV_STATE       EQU $C880+$0C   ; Button edge-detection: holds bit 7,6,5,4 = prev press state for btn 1,2,3,4 (1 bytes)
BTN_RAW              EQU $C880+$0D   ; Raw PSG reg 14 (active-LOW: 0=pressed, 1=released) - Vectorblade pattern (1 bytes)
DRAW_RECT_X          EQU $C880+$0E   ; Rectangle X (1 bytes)
DRAW_RECT_Y          EQU $C880+$0F   ; Rectangle Y (1 bytes)
DRAW_RECT_WIDTH      EQU $C880+$10   ; Rectangle width (1 bytes)
DRAW_RECT_HEIGHT     EQU $C880+$11   ; Rectangle height (1 bytes)
DRAW_RECT_INTENSITY  EQU $C880+$12   ; Rectangle intensity (1 bytes)
DRAW_VEC_INTENSITY   EQU $C880+$13   ; Vector intensity override (0=use vector data) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$14   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$1E   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$20   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$22   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$23   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$24   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$26   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
VAR_ARG0             EQU $C880+$28   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $C880+$2A   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $C880+$2C   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $C880+$2E   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $C880+$30   ; Function argument 4 (16-bit) (2 bytes)
VAR_ARG5             EQU $C880+$32   ; Function argument 5 (16-bit) (2 bytes)
VAR_ARG6             EQU $C880+$34   ; Function argument 6 (16-bit) (2 bytes)
VAR_ARG7             EQU $C880+$36   ; Function argument 7 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $C880+$38   ; Current ROM bank ID (multibank tracking) (1 bytes)

;***************************************************************************
; MAIN PROGRAM
;***************************************************************************

MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
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

    ; Prime BIOS button state at startup
    JSR $F1BA    ; Read_Btns: reads PSG reg14 -> $C80F, $C811, $C80E
    ; Call main() for initialization
; VPy_LINE:9
    ; TODO: Statement Pass { source_line: 9 }
    CLR >$C811  ; Force-clear Vec_Buttons before first loop() frame

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
; VPy_LINE:13
; NATIVE_CALL: DRAW_RECT at line 13
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$50
    JSR Intensity_a
    LDA #$D8
    LDB #$B0
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$50
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$E2
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$B0
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8
    LDD #0
    STD RESULT
; VPy_LINE:16
; NATIVE_CALL: DRAW_RECT at line 16
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$50
    JSR Intensity_a
    LDA #$D8
    LDB #$32
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$50
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$E2
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$B0
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8
    LDD #0
    STD RESULT
; VPy_LINE:19
; NATIVE_CALL: DRAW_RECT at line 19
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$50
    JSR Intensity_a
    LDA #$F1
    LDB #$F1
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$1E
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$E2
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$E2
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8
    LDD #0
    STD RESULT
    RTS

;***************************************************************************
; RUNTIME HELPERS
;***************************************************************************

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

DRAW_RECT_RUNTIME:
    ; Input: DRAW_RECT_X, DRAW_RECT_Y, DRAW_RECT_WIDTH, DRAW_RECT_HEIGHT, DRAW_RECT_INTENSITY
    ; Draws 4 sides of rectangle
    
    ; Save parameters to stack before DP change
    LDB DRAW_RECT_INTENSITY
    PSHS B
    LDB DRAW_RECT_HEIGHT
    PSHS B
    LDB DRAW_RECT_WIDTH
    PSHS B
    LDB DRAW_RECT_Y
    PSHS B
    LDB DRAW_RECT_X
    PSHS B
    
    ; Setup BIOS
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04            ; VIA_t1_cnt_lo = $80 (ensure correct scale)
    
    ; Set intensity
    LDA 4,S             ; intensity
    JSR Intensity_a
    
    ; Move to starting position (x, y)
    LDA 1,S             ; y
    LDB ,S              ; x
    JSR Moveto_d_7F
    
    ; Draw right side
    CLR Vec_Misc_Count
    LDA #0
    LDB 2,S             ; width
    JSR Draw_Line_d
    
    ; Draw down side
    CLR Vec_Misc_Count
    LDA 3,S             ; height
    NEGA                ; -height
    LDB #0
    JSR Draw_Line_d
    
    ; Draw left side
    CLR Vec_Misc_Count
    LDA #0
    LDB 2,S             ; width
    NEGB                ; -width
    JSR Draw_Line_d
    
    ; Draw up side (close rectangle: +height closes the -height of down side)
    CLR Vec_Misc_Count
    LDA 3,S             ; +height
    LDB #0
    JSR Draw_Line_d
    
    LDA #$C8
    TFR A,DP            ; Restore DP=$C8 before return
    LEAS 5,S            ; Clean stack
    RTS

