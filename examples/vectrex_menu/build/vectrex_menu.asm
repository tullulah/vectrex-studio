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
    FCC "VS MENU"
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
DRAW_LINE_ARGS       EQU $C880+$0F   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$19   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$1B   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$1D   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$1E   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$1F   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$21   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$23   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$24   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_ARG0             EQU $C880+$25   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $C880+$27   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $C880+$29   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $C880+$2B   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $C880+$2D   ; Function argument 4 (16-bit) (2 bytes)
VAR_ARG5             EQU $C880+$2F   ; Function argument 5 (16-bit) (2 bytes)
VAR_ARG6             EQU $C880+$31   ; Function argument 6 (16-bit) (2 bytes)
VAR_ARG7             EQU $C880+$33   ; Function argument 7 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $C880+$35   ; Current ROM bank ID (multibank tracking) (1 bytes)
VAR_SELECTED         EQU $C880+$36   ; User variable: SELECTED (2 bytes)
VAR_T                EQU $C880+$38   ; User variable: T (2 bytes)
VAR_LAST_JY          EQU $C880+$3A   ; User variable: LAST_JY (2 bytes)
VAR_FLASH            EQU $C880+$3C   ; User variable: FLASH (2 bytes)
VAR_GAME_COUNT       EQU $C880+$3E   ; User variable: GAME_COUNT (2 bytes)
VAR_LIST_X           EQU $C880+$40   ; User variable: LIST_X (2 bytes)
VAR_LIST_Y0          EQU $C880+$42   ; User variable: LIST_Y0 (2 bytes)
VAR_LIST_DY          EQU $C880+$44   ; User variable: LIST_DY (2 bytes)
VAR_PREV_X           EQU $C880+$46   ; User variable: PREV_X (2 bytes)
VAR_PREV_Y           EQU $C880+$48   ; User variable: PREV_Y (2 bytes)
VAR_PREV_HALF        EQU $C880+$4A   ; User variable: PREV_HALF (2 bytes)
VAR_JY               EQU $C880+$4C   ; User variable: JY (2 bytes)
VAR_I                EQU $C880+$4E   ; User variable: I (2 bytes)
VAR_Y                EQU $C880+$50   ; User variable: Y (2 bytes)
VAR_BOX              EQU $C880+$52   ; User variable: BOX (2 bytes)

;***************************************************************************
; MAIN PROGRAM
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
    STD VAR_SELECTED
    LDD #0
    STD VAR_T
    LDD #0
    STD VAR_LAST_JY
    LDD #0
    STD VAR_FLASH
    LDD #3
    STD VAR_GAME_COUNT
    LDD #-110
    STD VAR_LIST_X
    LDD #30
    STD VAR_LIST_Y0
    LDD #-24
    STD VAR_LIST_DY
    LDD #55
    STD VAR_PREV_X
    LDD #0
    STD VAR_PREV_Y
    LDD #45
    STD VAR_PREV_HALF
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
; VPy_LINE:30
    ; TODO: Statement Pass { source_line: 30 }
    CLR >$C811  ; Force-clear Vec_Buttons before first loop() frame

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    JSR $F1AA    ; DP_to_D0 (Joy_Analog requires DP=$D0)
    JSR $F1F5    ; Joy_Analog: poll all 4 axes once → $C81B-$C81E
    JSR Reset0Ref ; Restore beam state after Joy_Analog
    JSR $F1AF    ; DP_to_C8 (restore DP for RAM access)
; VPy_LINE:34
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_T
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_T
; VPy_LINE:37
; NATIVE_CALL: J1_Y at line 37
    JSR J1Y_BUILTIN
    STD RESULT
    STD VAR_JY
; VPy_LINE:38
    LDD #-40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JY
    CMPD TMPVAL
    LBLT .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_1
; VPy_LINE:39
    LDD #-40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_LAST_JY
    CMPD TMPVAL
    LBGE .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    LBEQ IF_NEXT_3
; VPy_LINE:40
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_SELECTED
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_SELECTED
; VPy_LINE:41
    LDD >VAR_GAME_COUNT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SELECTED
    CMPD TMPVAL
    LBGE .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    LBEQ IF_NEXT_5
; VPy_LINE:42
    LDD #0
    STD VAR_SELECTED
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
; VPy_LINE:43
    LDD #40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JY
    CMPD TMPVAL
    LBGT .CMP_3_TRUE
    LDD #0
    LBRA .CMP_3_END
.CMP_3_TRUE:
    LDD #1
.CMP_3_END:
    LBEQ IF_NEXT_7
; VPy_LINE:44
    LDD #40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_LAST_JY
    CMPD TMPVAL
    LBLE .CMP_4_TRUE
    LDD #0
    LBRA .CMP_4_END
.CMP_4_TRUE:
    LDD #1
.CMP_4_END:
    LBEQ IF_NEXT_9
; VPy_LINE:45
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_SELECTED
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_SELECTED
; VPy_LINE:46
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SELECTED
    CMPD TMPVAL
    LBLT .CMP_5_TRUE
    LDD #0
    LBRA .CMP_5_END
.CMP_5_TRUE:
    LDD #1
.CMP_5_END:
    LBEQ IF_NEXT_11
; VPy_LINE:47
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_GAME_COUNT
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_SELECTED
    LBRA IF_END_10
IF_NEXT_11:
IF_END_10:
    LBRA IF_END_8
IF_NEXT_9:
IF_END_8:
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
; VPy_LINE:48
    LDD >VAR_JY
    STD VAR_LAST_JY
; VPy_LINE:51
    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed
    BITA #$01
    BNE .J1B1_0_ON
    LDD #0
    BRA .J1B1_0_END
.J1B1_0_ON:
    LDD #1
.J1B1_0_END:
    STD RESULT
    LBEQ IF_NEXT_13
; VPy_LINE:52
    LDD #12
    STD VAR_FLASH
    LBRA IF_END_12
IF_NEXT_13:
IF_END_12:
; VPy_LINE:53
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLASH
    CMPD TMPVAL
    LBGT .CMP_6_TRUE
    LDD #0
    LBRA .CMP_6_END
.CMP_6_TRUE:
    LDD #1
.CMP_6_END:
    LBEQ IF_NEXT_15
; VPy_LINE:54
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLASH
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_FLASH
    LBRA IF_END_14
IF_NEXT_15:
IF_END_14:
; VPy_LINE:57
; NATIVE_CALL: SET_INTENSITY at line 57
    ; SET_INTENSITY: Set drawing intensity
    LDD #110
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:58
; NATIVE_CALL: SET_TEXT_SIZE at line 58
    LDD #7
    STD TMPPTR2     ; Save n (TMPPTR2+1 = n)
    NEGB            ; B = -n -> TEXT_SCALE_H
    STB >TEXT_SCALE_H
    LDB TMPPTR2+1   ; Reload n (from TMPPTR2, not RESULT)
    ASLB            ; n*2
    ASLB            ; n*4
    ASLB            ; n*8
    ADDB TMPPTR2+1  ; n*8 + n = n*9 -> TEXT_SCALE_W
    STB >TEXT_SCALE_W
; VPy_LINE:59
; NATIVE_CALL: PRINT_TEXT at line 59
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD >VAR_ARG0
    LDD #85
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_16208847190006433073      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:62
; NATIVE_CALL: SET_TEXT_SIZE at line 62
    LDD #6
    STD TMPPTR2     ; Save n (TMPPTR2+1 = n)
    NEGB            ; B = -n -> TEXT_SCALE_H
    STB >TEXT_SCALE_H
    LDB TMPPTR2+1   ; Reload n (from TMPPTR2, not RESULT)
    ASLB            ; n*2
    ASLB            ; n*4
    ASLB            ; n*8
    ADDB TMPPTR2+1  ; n*8 + n = n*9 -> TEXT_SCALE_W
    STB >TEXT_SCALE_W
; VPy_LINE:63
    LDD #0
    STD VAR_I
; VPy_LINE:64
WH_16: ; while start
    LDD >VAR_GAME_COUNT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    CMPD TMPVAL
    LBLT .CMP_7_TRUE
    LDD #0
    LBRA .CMP_7_END
.CMP_7_TRUE:
    LDD #1
.CMP_7_END:
    LBEQ WH_END_17
; VPy_LINE:65
    LDD >VAR_LIST_DY
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_LIST_Y0
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_Y
; VPy_LINE:66
    LDD >VAR_SELECTED
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    CMPD TMPVAL
    LBEQ .CMP_8_TRUE
    LDD #0
    LBRA .CMP_8_END
.CMP_8_TRUE:
    LDD #1
.CMP_8_END:
    LBEQ IF_NEXT_19
; VPy_LINE:67
; NATIVE_CALL: SET_INTENSITY at line 67
    ; SET_INTENSITY: Set drawing intensity
    LDD #120
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:69
; NATIVE_CALL: DRAW_LINE at line 69
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #14
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_LIST_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #8
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #6
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_LIST_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #4
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #120
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
; VPy_LINE:70
; NATIVE_CALL: DRAW_LINE at line 70
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #6
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_LIST_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #4
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #14
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_LIST_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_Y
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #120
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    LBRA IF_END_18
IF_NEXT_19:
; VPy_LINE:72
; NATIVE_CALL: SET_INTENSITY at line 72
    ; SET_INTENSITY: Set drawing intensity
    LDD #55
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
IF_END_18:
; VPy_LINE:73
    LDD >VAR_I
    CMPD #0
    LBNE IF_NEXT_21
; VPy_LINE:74
; NATIVE_CALL: PRINT_TEXT at line 74
    ; PRINT_TEXT: Print text at position
    LDD >VAR_LIST_X
    STD >VAR_ARG0
    LDD >VAR_Y
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_73008575135409      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_20
IF_NEXT_21:
IF_END_20:
; VPy_LINE:75
    LDD >VAR_I
    CMPD #1
    LBNE IF_NEXT_23
; VPy_LINE:76
; NATIVE_CALL: PRINT_TEXT at line 76
    ; PRINT_TEXT: Print text at position
    LDD >VAR_LIST_X
    STD >VAR_ARG0
    LDD >VAR_Y
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2448234      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_22
IF_NEXT_23:
IF_END_22:
; VPy_LINE:77
    LDD >VAR_I
    CMPD #2
    LBNE IF_NEXT_25
; VPy_LINE:78
; NATIVE_CALL: PRINT_TEXT at line 78
    ; PRINT_TEXT: Print text at position
    LDD >VAR_LIST_X
    STD >VAR_ARG0
    LDD >VAR_Y
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_69824076      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_24
IF_NEXT_25:
IF_END_24:
; VPy_LINE:79
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_I
    LBRA WH_16
WH_END_17: ; while end
; VPy_LINE:82
    LDD #70
    STD VAR_BOX
; VPy_LINE:83
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLASH
    CMPD TMPVAL
    LBGT .CMP_9_TRUE
    LDD #0
    LBRA .CMP_9_END
.CMP_9_TRUE:
    LDD #1
.CMP_9_END:
    LBEQ IF_NEXT_27
; VPy_LINE:84
    LDD #127
    STD VAR_BOX
    LBRA IF_END_26
IF_NEXT_27:
IF_END_26:
; VPy_LINE:85
; NATIVE_CALL: DRAW_LINE at line 85
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_PREV_HALF
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PREV_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_PREV_HALF
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PREV_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_PREV_HALF
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PREV_X
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_PREV_HALF
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PREV_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD DRAW_LINE_ARGS+6    ; y1
    LDD >VAR_BOX
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
; VPy_LINE:86
; NATIVE_CALL: DRAW_LINE at line 86
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_PREV_HALF
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PREV_X
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_PREV_HALF
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PREV_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_PREV_HALF
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PREV_X
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_PREV_HALF
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PREV_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD DRAW_LINE_ARGS+6    ; y1
    LDD >VAR_BOX
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
; VPy_LINE:87
; NATIVE_CALL: DRAW_LINE at line 87
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_PREV_HALF
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PREV_X
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_PREV_HALF
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PREV_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_PREV_HALF
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PREV_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_PREV_HALF
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PREV_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD DRAW_LINE_ARGS+6    ; y1
    LDD >VAR_BOX
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
; VPy_LINE:88
; NATIVE_CALL: DRAW_LINE at line 88
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_PREV_HALF
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PREV_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_PREV_HALF
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PREV_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_PREV_HALF
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PREV_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_PREV_HALF
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PREV_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD DRAW_LINE_ARGS+6    ; y1
    LDD >VAR_BOX
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
; VPy_LINE:94
    LDD >VAR_SELECTED
    CMPD #0
    LBNE IF_NEXT_29
; VPy_LINE:95
    LDX #PRINT_TEXT_STR_2716536067030786496      ; Pointer to string literal "snowbros_preview"
    TFR X,D
    STD VAR_ARG0
    LDD >VAR_PREV_X
    STD VAR_ARG1
    LDD >VAR_PREV_Y
    STD VAR_ARG2
    LDD #48
    STD VAR_ARG3
    LDD >VAR_T
    STD VAR_ARG4
    JSR DRAW_RECORDING
    LBRA IF_END_28
IF_NEXT_29:
IF_END_28:
    RTS

;***************************************************************************
; RUNTIME HELPERS
;***************************************************************************

VECTREX_PRINT_TEXT:
    ; VPy signature: PRINT_TEXT(x, y, string)
    ; BIOS signature: Print_Str_d(A=Y, B=X, U=string)
    LDA #$D0
    TFR A,DP
    JSR Intensity_5F
    JSR Reset0Ref
    LDU >VAR_ARG2
    LDA >TEXT_SCALE_H
    STA >$C82A          ; Vec_Text_Height
    LDA >TEXT_SCALE_W
    STA >$C82B          ; Vec_Text_Width
    LDA >VAR_ARG1+1
    LDB >VAR_ARG0+1
    LDX >$C82C
    PSHS X
    JSR Print_Str_d
    PULS X
    STX >$C82C
    LDA #$F8
    STA >$C82A
    LDA #$48
    STA >$C82B
    JSR $F1AF
    RTS

MUL16:
    ; Signed 16x16->16 multiply: D = X * D (lower 16 bits, sign-correct)
    ; Uses 6809 MUL (8x8->16) for constant-time execution.
    ; Stack after PSHS X,B,A: [SP+0]=A=D_hi=b_hi, [SP+1]=B=D_lo=b_lo,
    ;                         [SP+2]=X_hi=a_hi,  [SP+3]=X_lo=a_lo
    ; Result = a_lo*b_lo + (a_hi*b_lo + a_lo*b_hi)*256  (mod 65536)
    PSHS X,B,A
    ; Step 1: a_lo * b_lo -> 16-bit partial product
    LDA 3,S         ; A = a_lo (X low byte)
    LDB 1,S         ; B = b_lo (D low byte)
    MUL             ; D = a_lo * b_lo (unsigned 16-bit)
    STA TMPPTR      ; TMPPTR   = P0_hi (carry into result bits [15:8])
    STB TMPPTR+1    ; TMPPTR+1 = P0_lo (result bits [7:0])
    ; Step 2: a_hi * b_lo -> only low byte adds to result[15:8]
    LDA 2,S         ; A = a_hi (X high byte)
    LDB 1,S         ; B = b_lo (D low byte)
    MUL             ; D = a_hi * b_lo
    ADDB TMPPTR     ; B += P0_hi (ignore carry = mod 256)
    STB TMPPTR      ; TMPPTR = accumulated result[15:8]
    ; Step 3: a_lo * b_hi -> only low byte adds to result[15:8]
    LDA 3,S         ; A = a_lo (X low byte)
    LDB 0,S         ; B = b_hi (D high byte)
    MUL             ; D = a_lo * b_hi
    ADDB TMPPTR     ; B += accumulated result[15:8] (mod 256)
    TFR B,A         ; A = result_hi
    LDB TMPPTR+1    ; B = result_lo
    LEAS 4,S        ; restore stack
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

; J1_Y() - Read Joystick 1 Y axis from cached BIOS value at $C81C
J1Y_BUILTIN:
    LDB >$C81C   ; Vec_Joy_1_Y
    SEX
    ADDD #2
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
PRINT_TEXT_STR_2448234:
    FCC "PANG"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_69824076:
    FCC "INTRO"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_73008575135409:
    FCC "SNOW BROS"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2716536067030786496:
    FCC "snowbros_preview"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_16208847190006433073:
    FCC "VECTREX STUDIO"
    FCB $80          ; Vectrex string terminator

