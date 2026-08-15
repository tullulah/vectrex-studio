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
    FCC "SMOOTH CURVES"
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
DRAW_VEC_INTENSITY   EQU $C880+$0E   ; Vector intensity override (0=use vector data) (1 bytes)
DRAW_VEC_X_HI        EQU $C880+$0F   ; Vector draw X high byte (16-bit screen_x) (1 bytes)
DRAW_VEC_X           EQU $C880+$10   ; Vector draw X offset (1 bytes)
DRAW_VEC_Y           EQU $C880+$11   ; Vector draw Y offset (1 bytes)
MIRROR_PAD           EQU $C880+$12   ; Safety padding to prevent MIRROR flag corruption (16 bytes)
MIRROR_X             EQU $C880+$22   ; X mirror flag (0=normal, 1=flip) (1 bytes)
MIRROR_Y             EQU $C880+$23   ; Y mirror flag (0=normal, 1=flip) (1 bytes)
SLR_CUR_X            EQU $C880+$24   ; DRAW_VECTOR: clamped (visible) beam X for clipping (1 bytes)
SLR_TRUE_X           EQU $C880+$25   ; DRAW_VECTOR: 16-bit unclamped abs_x for line clipping (2 bytes)
DRAW_T1_SCALED       EQU $C880+$27   ; DRAW_VECTOR: T1 scale ($7F default for non-SHOW_LEVEL) (1 bytes)
SDCP_ABS_Y           EQU $C880+$28   ; DRAW_VECTOR: abs_y temporary for SDCP (cannot share TMPVAL — would corrupt SHOW_LEVEL's top_screen between layers) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$29   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$33   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$35   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$37   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$38   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$39   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$3B   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
DRAW_SCALE           EQU $C880+$3D   ; Current T1 scale for Draw_Sync_List_At_With_Mirrors ($7F=normal) (1 bytes)
VAR_ARG0             EQU $C880+$3E   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $C880+$40   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $C880+$42   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $C880+$44   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $C880+$46   ; Function argument 4 (16-bit) (2 bytes)
VAR_ARG5             EQU $C880+$48   ; Function argument 5 (16-bit) (2 bytes)
VAR_ARG6             EQU $C880+$4A   ; Function argument 6 (16-bit) (2 bytes)
VAR_ARG7             EQU $C880+$4C   ; Function argument 7 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $C880+$4E   ; Current ROM bank ID (multibank tracking) (1 bytes)

;***************************************************************************
; MAIN PROGRAM
;***************************************************************************

MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    CLR DRAW_VEC_INTENSITY ; 0 = use recorded/vector intensity (no override)
    LDA #$7F
    STA DRAW_SCALE        ; Default T1 scale = $7F (127 = full BIOS scale)
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
    CLR >$C811  ; Force-clear Vec_Buttons before first loop() frame

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
; VPy_LINE:19
; NATIVE_CALL: SET_INTENSITY at line 19
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:27
; NATIVE_CALL: DRAW_BEZIER at line 27
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$64
    JSR Intensity_a
    LDA #$00
    LDB #$37
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$06
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$05
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$05
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$05
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$05
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$05
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$04
    LDB #$FC
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$04
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$FC
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$04
    LDB #$FC
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$FB
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$FB
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FB
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$FB
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FB
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FA
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP
    LDD #0
    STD RESULT
; VPy_LINE:29
; NATIVE_CALL: DRAW_BEZIER at line 29
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$64
    JSR Intensity_a
    LDA #$37
    LDB #$00
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FA
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FB
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FB
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FB
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$FB
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FB
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FC
    LDB #$FC
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$FC
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FC
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FC
    LDB #$FC
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FB
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FB
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FB
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FB
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FB
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FA
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP
    LDD #0
    STD RESULT
; VPy_LINE:31
; NATIVE_CALL: DRAW_BEZIER at line 31
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$64
    JSR Intensity_a
    LDA #$00
    LDB #$C9
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$FA
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FB
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FB
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FB
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FB
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FB
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FC
    LDB #$04
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FC
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$04
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FC
    LDB #$04
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$05
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$05
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$05
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$05
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$05
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$06
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP
    LDD #0
    STD RESULT
; VPy_LINE:33
; NATIVE_CALL: DRAW_BEZIER at line 33
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$64
    JSR Intensity_a
    LDA #$C9
    LDB #$00
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$06
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$05
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$05
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$05
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$05
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$05
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$04
    LDB #$04
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$04
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$04
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$04
    LDB #$04
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$05
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$05
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$05
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$05
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$05
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$06
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP
    LDD #0
    STD RESULT
; VPy_LINE:43
; NATIVE_CALL: DRAW_BEZIER at line 43
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$50
    JSR Intensity_a
    LDA #$0E
    LDB #$00
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP
    LDD #0
    STD RESULT
; VPy_LINE:45
; NATIVE_CALL: DRAW_BEZIER at line 45
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$50
    JSR Intensity_a
    LDA #$00
    LDB #$EC
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$03
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP
    LDD #0
    STD RESULT
; VPy_LINE:47
; NATIVE_CALL: DRAW_BEZIER at line 47
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$50
    JSR Intensity_a
    LDA #$E6
    LDB #$00
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$04
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$04
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$04
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$04
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$04
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$04
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP
    LDD #0
    STD RESULT
; VPy_LINE:51
; NATIVE_CALL: DRAW_BEZIER at line 51
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$50
    JSR Intensity_a
    LDA #$00
    LDB #$20
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$05
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$04
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$05
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$04
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$04
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$04
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$FC
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FC
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$FB
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FB
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP
    LDD #0
    STD RESULT
; VPy_LINE:53
; NATIVE_CALL: DRAW_BEZIER at line 53
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$50
    JSR Intensity_a
    LDA #$26
    LDB #$00
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FB
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FA
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FB
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FB
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FC
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$FB
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$FC
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FC
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FB
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FB
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FB
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FA
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP
    LDD #0
    STD RESULT
; VPy_LINE:55
; NATIVE_CALL: DRAW_BEZIER at line 55
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$50
    JSR Intensity_a
    LDA #$00
    LDB #$D4
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$FA
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FA
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FA
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FA
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FB
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FB
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FC
    LDB #$05
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FC
    LDB #$04
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FC
    LDB #$05
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$06
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$06
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$07
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP
    LDD #0
    STD RESULT
; VPy_LINE:57
; NATIVE_CALL: DRAW_BEZIER at line 57
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$50
    JSR Intensity_a
    LDA #$CE
    LDB #$00
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$07
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$07
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$07
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$06
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$06
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$04
    LDB #$06
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$05
    LDB #$04
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$05
    LDB #$05
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$06
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$07
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$07
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$07
    LDB #$01
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP
    LDD #0
    STD RESULT
; VPy_LINE:59
; NATIVE_CALL: DRAW_VECTOR at line 59
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: test (index=0, 1 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_0          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #-70
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_0
    LDB #$FF
.sx_pos_0:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_TEST_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_0:
    LDD #0
    STD RESULT
    RTS

;***************************************************************************
; EMBEDDED ASSETS (vectors, music, levels, SFX)
;***************************************************************************

; Generated from test.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 15
; X bounds: min=-38, max=37, width=75
; Center: (0, 4)

_TEST_WIDTH EQU 75
_TEST_HALF_WIDTH EQU 37
_TEST_HEIGHT EQU 113
_TEST_HALF_HEIGHT EQU 56
_TEST_CENTER_X EQU 0
_TEST_CENTER_Y EQU 4

_TEST_VECTORS:  ; Main entry (header + 1 path(s))
    FDB 1               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _TEST_PATH0        ; pointer to path 0

_TEST_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $25,$E0,0,0        ; path0: header (y=37, x=-32)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$08,$0D          ; flag=-1, dy=8, dx=13
    FCB $FF,$04,$0C          ; flag=-1, dy=4, dx=12
    FCB $FF,$FF,$13          ; flag=-1, dy=-1, dx=19
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$F9,$06          ; flag=-1, dy=-7, dx=6
    FCB $FF,$F8,$03          ; flag=-1, dy=-8, dx=3
    FCB $FF,$F4,$02          ; flag=-1, dy=-12, dx=2
    FCB $FF,$F3,$FD          ; flag=-1, dy=-13, dx=-3
    FCB $FF,$FC,$FC          ; flag=-1, dy=-4, dx=-4
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$FD,$FD          ; flag=-1, dy=-3, dx=-3
    FCB $FF,$F2,$FC          ; flag=-1, dy=-14, dx=-4
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$FB,$03          ; flag=-1, dy=-5, dx=3
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$FC,$04          ; flag=-1, dy=-4, dx=4
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB $FF,$FD,$03          ; flag=-1, dy=-3, dx=3
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FD,$03          ; flag=-1, dy=-3, dx=3
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$F6,$F6          ; flag=-1, dy=-10, dx=-10
    FCB $FF,$FC,$F0          ; flag=-1, dy=-4, dx=-16
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)
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

Draw_Sync_List_At_With_Mirrors:
; Unified mirror support using flags: MIRROR_X and MIRROR_Y
; Conditionally negates X and/or Y coordinates and deltas
; NOTE: Caller has DP=$D0 for VIA access — RAM vars need '>' extended addressing
LDA >DRAW_VEC_INTENSITY ; Check if intensity override is set
BNE DSWM_USE_OVERRIDE   ; If non-zero, use override
LDA ,X+                 ; Otherwise, read intensity from vector data
BRA DSWM_SET_INTENSITY
DSWM_USE_OVERRIDE:
LEAX 1,X                ; Skip intensity byte in vector data
DSWM_SET_INTENSITY:
STA >$C832              ; Vec_Misc_Count (direct, DP-safe — JSR Intensity_a corrupts DDRB with DP=$D0)
LDB ,X+                 ; y_start from .vec (already relative to center)
; Check if Y mirroring is enabled
TST >MIRROR_Y
BEQ DSWM_NO_NEGATE_Y
NEGB                    ; ← Negate Y if flag set
DSWM_NO_NEGATE_Y:
ADDB >DRAW_VEC_Y        ; Add Y offset
LDA ,X+                 ; x_start from .vec (already relative to center)
; Check if X mirroring is enabled
TST >MIRROR_X
BEQ DSWM_NO_NEGATE_X
NEGA                    ; ← Negate X if flag set
DSWM_NO_NEGATE_X:
ADDA >DRAW_VEC_X        ; Add X offset
STD >TEMP_YX            ; Save adjusted position
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
LDD >TEMP_YX
STB VIA_port_a          ; Y to DAC (PB=1: integrators hold)
CLR VIA_port_b          ; PB=0: enable mux, beam tracks Y
PSHS A                  ; ~4 cycle settling delay for Y
LDA #$CE
STA VIA_cntl            ; PCR=$CE: /ZERO high, integrators active
CLR VIA_shift_reg       ; SR=0: no draw during moveto
INC VIA_port_b          ; PB=1: disable mux, lock direction at Y
PULS A                  ; Restore X
STA VIA_port_a          ; X to DAC
; Timing setup (match core: hardcoded $7F)
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
TST >MIRROR_Y
BEQ DSWM_NO_NEGATE_DY
NEGB                    ; ← Negate dy if flag set
DSWM_NO_NEGATE_DY:
LDA ,X+                 ; dx
; Check if X mirroring is enabled
TST >MIRROR_X
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
LDA >DRAW_VEC_INTENSITY ; Check if intensity override is set
BNE DSWM_NEXT_USE_OVERRIDE   ; If non-zero, use override
LDA ,X+                 ; Otherwise, read intensity from vector data
BRA DSWM_NEXT_SET_INTENSITY
DSWM_NEXT_USE_OVERRIDE:
LEAX 1,X                ; Skip intensity byte in vector data
DSWM_NEXT_SET_INTENSITY:
PSHS A
LDB ,X+                 ; y_start
TST >MIRROR_Y
BEQ DSWM_NEXT_NO_NEGATE_Y
NEGB
DSWM_NEXT_NO_NEGATE_Y:
ADDB >DRAW_VEC_Y        ; Add Y offset
LDA ,X+                 ; x_start
TST >MIRROR_X
BEQ DSWM_NEXT_NO_NEGATE_X
NEGA
DSWM_NEXT_NO_NEGATE_X:
ADDA >DRAW_VEC_X        ; Add X offset
STD >TEMP_YX
PULS A                  ; Get intensity back
STA >$C832              ; Vec_Misc_Count (direct, DP-safe)
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
LDD >TEMP_YX
STB VIA_port_a          ; Y to DAC (PB=1: integrators hold)
CLR VIA_port_b          ; PB=0: enable mux, beam tracks Y
PSHS A                  ; ~4 cycle settling delay for Y
LDA #$CE
STA VIA_cntl            ; PCR=$CE: /ZERO high, integrators active
CLR VIA_shift_reg       ; SR=0: no draw during moveto
INC VIA_port_b          ; PB=1: disable mux, lock direction at Y
PULS A
STA VIA_port_a          ; X to DAC
; Timing setup (match core: hardcoded $7F)
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
; === SLR_DRAW_CLIPPED_PATH ===
SLR_DRAW_CLIPPED_PATH:
    LDA >DRAW_VEC_INTENSITY ; check override
    BNE SDCP_USE_OVERRIDE
    LDA ,X+                 ; read intensity from path data
    BRA SDCP_SET_INTENS
SDCP_USE_OVERRIDE:
    LEAX 1,X                ; skip intensity byte
SDCP_SET_INTENS:
    STA >$C832              ; Vec_Misc_Count (DDRB-safe, no JSR)
    LDB ,X+                 ; B = y_start (relative to center)
    LDA ,X+                 ; A = x_start (relative to center)
    ADDB >DRAW_VEC_Y        ; B = abs_y
    STB >SDCP_ABS_Y         ; save abs_y for moveto (NOT TMPVAL — SHOW_LEVEL's top_screen lives there)
    TFR A,B                 ; B = x_start (SEX extends B, not A)
    SEX                      ; sign-extend B→D (A=sign, B=x_start)
    ADDD >DRAW_VEC_X_HI     ; D = abs_x_16 = SEX(x_start) + screen_x_16
    ; D = abs_x_16. Save it in 16-bit tracker SLR_TRUE_X (unclamped).
    STD >SLR_TRUE_X
    ; Compute clamped beam position for hardware Moveto.
    TSTA
    BEQ SDCP_INIT_POS
    INCA
    BEQ SDCP_INIT_NEG_OK    ; A was $FF (small negative)
    ; Way off — clamp to nearest edge by sign of original A (now in INCA result)
    LDB #$80                ; default to left edge
    LDA >SLR_TRUE_X         ; original hi byte
    BMI SDCP_USE_CLAMPED    ; negative → -128 (left)
    LDB #$7F                ; positive way off → +127 (right)
    BRA SDCP_USE_CLAMPED
SDCP_INIT_NEG_OK:
    CMPB #$80
    BHS SDCP_USE_CLAMPED    ; -128..-1, valid
    LDB #$80                ; clamp
    BRA SDCP_USE_CLAMPED
SDCP_INIT_POS:
    CMPB #$7F
    BLS SDCP_USE_CLAMPED
    LDB #$7F                ; clamp positive
SDCP_USE_CLAMPED:
    TFR B,A                  ; A = clamped beam x
    STA >SLR_CUR_X          ; clamped value goes to integrator
    CLR VIA_shift_reg
    LDA #$CC
    STA VIA_cntl
    CLR VIA_port_a
    LDA #$03
    STA VIA_port_b
    LDA #$02
    STA VIA_port_b
    LDA #$02
    STA VIA_port_b
    LDA #$01
    STA VIA_port_b
    LDB >SDCP_ABS_Y         ; B = abs_y
    STB VIA_port_a          ; DY → DAC (PB=1: hold)
    CLR VIA_port_b          ; PB=0: enable mux, beam tracks Y
    LDA >SLR_CUR_X          ; abs_x (load = settling for Y)
    PSHS A                  ; ~4 more settling cycles
    LDA #$CE
    STA VIA_cntl            ; PCR=$CE: /ZERO high
    CLR VIA_shift_reg       ; SR=0: beam off
    INC VIA_port_b          ; PB=1: lock Y direction
    PULS A                  ; restore abs_x
    STA VIA_port_a          ; DX → DAC
    LDA >DRAW_T1_SCALED     ; effective T1 for this object (scale * 127)
    STA VIA_t1_cnt_lo       ; load T1 latch
    LEAX 2,X                ; skip next_y, next_x (the 0,0)
    CLR VIA_t1_cnt_hi       ; start T1 → ramp
SDCP_MOVETO_W:
    LDA VIA_int_flags
    ANDA #$40
    BEQ SDCP_MOVETO_W
    ; PB=1 on exit — draw loop ready
SDCP_SEG_LOOP:
    LDA ,X+                 ; flags
    CMPA #2
    LBEQ SDCP_DONE
    LDB ,X+                 ; B = dy
    STB >TMPPTR2            ; save dy
    LDA ,X+                 ; A = dx (8-bit signed)
    ; --- 16-bit add: true_new_x_16 = SLR_TRUE_X + SEX(dx) ---
    TFR A,B                 ; B = dx
    SEX                      ; D = sign-extended dx (A=sign, B=dx)
    ADDD >SLR_TRUE_X        ; D = new true_x_16
    STD >SLR_TRUE_X         ; update 16-bit tracker
    ; --- Clamp D to [-128, +127] → 8-bit clamped_new_x in B ---
    TSTA
    BEQ SDCP_SEG_POS
    INCA
    BEQ SDCP_SEG_NEG_OK     ; A was $FF
    ; Way off — clamp by sign of original D
    LDA >SLR_TRUE_X         ; reload hi byte
    BMI SDCP_SEG_CLAMP_LEFT
    LDB #$7F                ; positive way off → +127
    BRA SDCP_SEG_CLAMPED
SDCP_SEG_CLAMP_LEFT:
    LDB #$80                ; negative way off → -128
    BRA SDCP_SEG_CLAMPED
SDCP_SEG_NEG_OK:
    CMPB #$80
    BHS SDCP_SEG_CLAMPED
    LDB #$80
    BRA SDCP_SEG_CLAMPED
SDCP_SEG_POS:
    CMPB #$7F
    BLS SDCP_SEG_CLAMPED
    LDB #$7F
SDCP_SEG_CLAMPED:
    ; B = clamped_new_x. Compute beam_dx = B - SLR_CUR_X (8-bit signed).
    LDA >SLR_CUR_X
    PSHS B                  ; save clamped_new_x
    NEGA                    ; A = -cur_x
    ADDA ,S                 ; A = clamped_new_x - cur_x = beam_dx
    PULS B                  ; B = clamped_new_x
    ; Update SLR_CUR_X to new clamped position
    STB >SLR_CUR_X
    ; Decide beam ON/OFF/skip:
    ; - beam_dx != 0                       → beam ON,  ramp(beam_dx, dy)
    ; - beam_dx == 0 AND cur at edge AND dy==0 → skip (zero motion)
    ; - beam_dx == 0 AND cur at edge AND dy!=0 → beam OFF ramp(0, dy)
    ;   (Y must track logical position so subsequent segments draw at correct Y)
    ; - beam_dx == 0 AND not at edge       → beam ON,  ramp(0, dy) — vertical
    TSTA
    BNE SDCP_SEG_DRAW       ; non-zero beam_dx → draw
    CMPB #$80               ; at left edge?
    BEQ SDCP_SEG_OFF_X      ; yes → fully off-screen left
    CMPB #$7F               ; at right edge?
    BEQ SDCP_SEG_OFF_X      ; yes → fully off-screen right
SDCP_SEG_DRAW:
    LDB >TMPPTR2            ; restore dy
    ; A = beam_dx (visible X delta), B = dy. Beam ON ramp.
    STB VIA_port_a          ; DY → DAC (PB=1: hold)
    CLR VIA_port_b          ; PB=0: mux for DY
    NOP
    NOP
    NOP
    INC VIA_port_b          ; PB=1: lock DY
    STA VIA_port_a          ; DX → DAC
    LDA #$FF
    STA VIA_shift_reg       ; beam ON
    CLR VIA_t1_cnt_hi       ; start T1
SDCP_W_DRAW:
    LDA VIA_int_flags
    ANDA #$40
    BEQ SDCP_W_DRAW
    CLR VIA_shift_reg       ; beam OFF
    LBRA SDCP_SEG_LOOP

    ; --- Off-screen-X path: dx contribution is invisible, but Y must track ---
SDCP_SEG_OFF_X:
    LDB >TMPPTR2            ; B = dy
    TSTB                     ; dy == 0?
    LBEQ SDCP_SEG_LOOP      ; no Y motion either → skip entire segment
    ; Ramp(0, dy) with beam OFF. A is already 0 (beam_dx).
    CLRA                     ; defensive: ensure dx=0
    STB VIA_port_a          ; DY → DAC
    CLR VIA_port_b
    NOP
    NOP
    NOP
    INC VIA_port_b
    STA VIA_port_a          ; DX = 0
    ; beam stays OFF (no STA VIA_shift_reg)
    CLR VIA_t1_cnt_hi       ; start T1 (ramp, beam off)
SDCP_W_OFF_X:
    LDA VIA_int_flags
    ANDA #$40
    BEQ SDCP_W_OFF_X
    LBRA SDCP_SEG_LOOP

SDCP_DONE:
    RTS

;**** PRINT_TEXT String Data ****
PRINT_TEXT_STR_3556498:
    FCC "test"
    FCB $80          ; Vectrex string terminator

