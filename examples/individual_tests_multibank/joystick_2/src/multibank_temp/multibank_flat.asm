; AUTO-GENERATED FLATTENED MULTIBANK ASM
; Banks: 4 | Bank size: 16384 bytes | Total: 65536 bytes

ORG $0000

;***************************************************************************
; DEFINE SECTION
;***************************************************************************
    INCLUDE "VECTREX.I"

; ===== BANK #00 (physical offset $00000) =====
; VPy M6809 Assembly (Vectrex)
; ROM: 65536 bytes
; Multibank cartridge: 4 banks (16KB each)
; Helpers bank: 3 (fixed bank at $4000-$7FFF)

; ================================================


    ORG $0000

;***************************************************************************
; DEFINE SECTION
;***************************************************************************

;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "JOY2"
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
; Bank 0 ($0000) is active; fixed bank 3 ($4000-$7FFF) always visible
    JMP MAIN

;***************************************************************************
MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    LDA #$F8
    STA TEXT_SCALE_H      ; Default height = -8 (normal size)
    LDA #$48
    STA TEXT_SCALE_W      ; Default width = 72 (normal size)
    LDD #0
    STD VAR_JX
    LDD #0
    STD VAR_JY
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
    LDD #0
    STD VAR_JX
    LDD #0
    STD VAR_JY

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    ; PRINT_TEXT: Print text at position
    LDD #-50
    STD VAR_ARG0
    LDD #90
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2194200014      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    JSR J2X_BUILTIN
    STD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #2
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR DIV16       ; D = X / D
    STD VAR_JX
    JSR J2Y_BUILTIN
    STD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #2
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR DIV16       ; D = X / D
    STD VAR_JY
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_JX
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #8
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_JY
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_JX
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #8
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_JY
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #80
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_JX
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_JY
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #8
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_JX
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_JY
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #8
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #80
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    LDA $C812      ; Vec_Button_1_2 (Player 2 transition bits)
    ANDA #$01      ; Test bit 0
    BEQ .J2B1_0_OFF
    LDD #1
    BRA .J2B1_0_END
.J2B1_0_OFF:
    LDD #0
.J2B1_0_END:
    STD RESULT
    LBEQ IF_NEXT_1
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$64
    JSR Intensity_a
    LDA #$C4
    LDB #$D6
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$1E
    JSR Intensity_a
    LDA #$C4
    LDB #$D6
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LDA $C812      ; Vec_Button_1_2 (Player 2 transition bits)
    ANDA #$02      ; Test bit 1
    BEQ .J2B2_1_OFF
    LDD #1
    BRA .J2B2_1_END
.J2B2_1_OFF:
    LDD #0
.J2B2_1_END:
    STD RESULT
    LBEQ IF_NEXT_3
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$64
    JSR Intensity_a
    LDA #$C4
    LDB #$F4
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$1E
    JSR Intensity_a
    LDA #$C4
    LDB #$F4
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LDA $C812      ; Vec_Button_1_2 (Player 2 transition bits)
    ANDA #$04      ; Test bit 2
    BEQ .J2B3_2_OFF
    LDD #1
    BRA .J2B3_2_END
.J2B3_2_OFF:
    LDD #0
.J2B3_2_END:
    STD RESULT
    LBEQ IF_NEXT_5
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$64
    JSR Intensity_a
    LDA #$C4
    LDB #$12
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$1E
    JSR Intensity_a
    LDA #$C4
    LDB #$12
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LDA $C812      ; Vec_Button_1_2 (Player 2 transition bits)
    ANDA #$08      ; Test bit 3
    BEQ .J2B4_3_OFF
    LDD #1
    BRA .J2B4_3_END
.J2B4_3_OFF:
    LDD #0
.J2B4_3_END:
    STD RESULT
    LBEQ IF_NEXT_7
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$64
    JSR Intensity_a
    LDA #$C4
    LDB #$30
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$1E
    JSR Intensity_a
    LDA #$C4
    LDB #$30
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-52
    STD VAR_ARG0
    LDD #-75
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_44450992618      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    RTS


; ================================================


; ===== BANK #01 (physical offset $04000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #02 (physical offset $08000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #03 (physical offset $0C000) =====
    ORG $4000  ; Fixed bank window (runtime helpers + interrupt vectors)


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
    LDA >TEXT_SCALE_H ; height (signed byte, e.g. $F8=-8)
    STA >$C82A      ; Vec_Text_Height: controls character Y scale
    LDA >TEXT_SCALE_W ; width (unsigned byte, e.g. 72)
    STA >$C82B      ; Vec_Text_Width: controls character X spacing
    LDA >VAR_ARG1+1 ; Y coordinate
    LDB >VAR_ARG0+1 ; X coordinate
    JSR Print_Str_d
    LDA #$F8
    STA >$C82A      ; Restore Vec_Text_Height to normal (-8)
    LDA #$48
    STA >$C82B      ; Restore Vec_Text_Width to normal (72)
    JSR $F1AF      ; DP_to_C8 - restore DP before return
    RTS

DIV16:
    ; Signed 16-bit division: D = X / D
    ; X = dividend (i16), D = divisor (i16) -> D = quotient
    STD TMPPTR          ; Save divisor
    TFR X,D             ; D = dividend (TFR does NOT set flags!)
    CMPD #0             ; Set flags from FULL D BEFORE any LDA corrupts high byte
    BPL .D16_DPOS       ; if dividend >= 0, skip negation
    COMA
    COMB
    ADDD #1             ; D = |dividend|
    STD TMPVAL          ; store |dividend| BEFORE LDA corrupts A (high byte of D)
    LDA #1
    STA TMPPTR2         ; sign_flag = 1 (dividend was negative)
    BRA .D16_RCHECK
.D16_DPOS:
    STD TMPVAL          ; dividend is positive, store as-is
    LDA #0
    STA TMPPTR2         ; sign_flag = 0 (positive result)
.D16_RCHECK:
    LDD TMPPTR          ; D = divisor
    BPL .D16_RPOS       ; if divisor >= 0, skip negation
    COMA
    COMB
    ADDD #1             ; D = |divisor|
    STD TMPPTR          ; TMPPTR = |divisor|
    LDA TMPPTR2
    EORA #1
    STA TMPPTR2         ; toggle sign flag (XOR with 1)
.D16_RPOS:
    LDD #0
    STD RESULT          ; quotient = 0
.D16_LOOP:
    LDD TMPVAL
    SUBD TMPPTR         ; |dividend| - |divisor|
    BLO .D16_END        ; if |dividend| < |divisor|, done
    STD TMPVAL          ; update remainder
    LDD RESULT
    ADDD #1
    STD RESULT          ; quotient++
    BRA .D16_LOOP
.D16_END:
    LDD RESULT          ; D = unsigned quotient
    LDA TMPPTR2
    BEQ .D16_DONE       ; zero = positive result
    COMA
    COMB
    ADDD #1             ; negate for negative result
.D16_DONE:
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

; J2_X() - Read Joystick 2 X axis (BIOS Joy_Analog)
J2X_BUILTIN:
    PSHS X       ; Save X
    JSR $F1AA    ; DP_to_D0
    JSR $F1F5    ; Joy_Analog
    JSR $F1AF    ; DP_to_C8
    LDB $C81D    ; Vec_Joy_2_X
    SEX          ; Sign-extend B to D
    ADDD #2      ; Calibrate center offset
    PULS X       ; Restore X
    RTS

; J2_Y() - Read Joystick 2 Y axis (BIOS Joy_Analog)
J2Y_BUILTIN:
    PSHS X       ; Save X
    JSR $F1AA    ; DP_to_D0
    JSR $F1F5    ; Joy_Analog
    JSR $F1AF    ; DP_to_C8
    LDB $C81E    ; Vec_Joy_2_Y
    SEX          ; Sign-extend B to D
    ADDD #2      ; Calibrate center offset
    PULS X       ; Restore X
    RTS

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
    ; Check if we need SEGMENT 2 (dy OR dx outside ±127 range)
    LDD >VLINE_DY_16 ; Reload original dy - EXTENDED
    CMPD #127
    BGT DLW_NEED_SEG2  ; dy > 127: needs segment 2
    CMPD #-128
    BLT DLW_NEED_SEG2  ; dy < -128: needs segment 2
    LDD >VLINE_DX_16 ; Also check dx - EXTENDED
    CMPD #127
    BGT DLW_NEED_SEG2  ; dx > 127: needs segment 2
    CMPD #-128
    BLT DLW_NEED_SEG2  ; dx < -128: needs segment 2
    BRA DLW_DONE       ; both dy and dx in range: no segment 2
DLW_NEED_SEG2:
    ; SEGMENT 2: Draw remaining dy and dx
    ; Calculate remaining dy
    LDD >VLINE_DY_16 ; Load original full dy - EXTENDED
    CMPD #127
    BGT DLW_SEG2_DY_POS  ; dy > 127: remaining = dy - 127
    CMPD #-128
    BGE DLW_SEG2_DY_NO_REMAIN  ; -128 <= dy <= 127: no remaining dy
    ; dy < -128, so we drew -128 in segment 1
    ; remaining = dy - (-128) = dy + 128
    ADDD #128       ; Add back the -128 we already drew
    BRA DLW_SEG2_DY_DONE
DLW_SEG2_DY_NO_REMAIN:
    LDD #0          ; dy in range: no remaining
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
PRINT_TEXT_STR_2194200014:
    FCC "JOY P2"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_44450992618:
    FCC "1 2 3 4"
    FCB $80          ; Vectrex string terminator



;***************************************************************************
; INTERRUPT VECTORS (Bank #31 Fixed Window)
;***************************************************************************
ORG $FFFE
FDB CUSTOM_RESET
