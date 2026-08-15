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
    FCC "SPACE TEST"
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
NUM_STR              EQU $C880+$0E   ; Buffer for PRINT_NUMBER decimal output (5 digits + terminator) (6 bytes)
DRAW_RECT_X          EQU $C880+$14   ; Rectangle X (1 bytes)
DRAW_RECT_Y          EQU $C880+$15   ; Rectangle Y (1 bytes)
DRAW_RECT_WIDTH      EQU $C880+$16   ; Rectangle width (1 bytes)
DRAW_RECT_HEIGHT     EQU $C880+$17   ; Rectangle height (1 bytes)
DRAW_RECT_INTENSITY  EQU $C880+$18   ; Rectangle intensity (1 bytes)
DRAW_VEC_INTENSITY   EQU $C880+$19   ; Vector intensity override (0=use vector data) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$1A   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$24   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$26   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$28   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$29   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$2A   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$2C   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$2E   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$2F   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
PN_LAST_VAL          EQU $C880+$30   ; PRINT_NUMBER: last rendered numeric value (cache key) (2 bytes)
PN_LAST_VALID        EQU $C880+$32   ; PRINT_NUMBER: 1 if PN_LAST_VAL holds a valid render (1 bytes)
PN_LAST_X            EQU $C880+$33   ; PRINT_NUMBER: last rendered X (cache key) (1 bytes)
PN_LAST_Y            EQU $C880+$34   ; PRINT_NUMBER: last rendered Y (cache key) (1 bytes)
VAR_ARG0             EQU $C880+$35   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $C880+$37   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $C880+$39   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $C880+$3B   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $C880+$3D   ; Function argument 4 (16-bit) (2 bytes)
VAR_ARG5             EQU $C880+$3F   ; Function argument 5 (16-bit) (2 bytes)
VAR_ARG6             EQU $C880+$41   ; Function argument 6 (16-bit) (2 bytes)
VAR_ARG7             EQU $C880+$43   ; Function argument 7 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $C880+$45   ; Current ROM bank ID (multibank tracking) (1 bytes)
VAR_SCREEN_WIDTH     EQU $C880+$46   ; User variable: SCREEN_WIDTH (2 bytes)
VAR_SCREEN_HEIGHT    EQU $C880+$48   ; User variable: SCREEN_HEIGHT (2 bytes)
VAR_PLAYER_SIZE      EQU $C880+$4A   ; User variable: PLAYER_SIZE (2 bytes)
VAR_ENEMY_SIZE       EQU $C880+$4C   ; User variable: ENEMY_SIZE (2 bytes)
VAR_BULLET_SPEED     EQU $C880+$4E   ; User variable: BULLET_SPEED (1 bytes)
VAR_GAME_STATE       EQU $C880+$4F   ; User variable: GAME_STATE (1 bytes)
VAR_SCORE            EQU $C880+$50   ; User variable: SCORE (2 bytes)
VAR_PLAYER_X         EQU $C880+$52   ; User variable: PLAYER_X (2 bytes)
VAR_PLAYER_Y         EQU $C880+$54   ; User variable: PLAYER_Y (2 bytes)
VAR_BULLET_ACTIVE    EQU $C880+$56   ; User variable: BULLET_ACTIVE (1 bytes)
VAR_BULLET_X         EQU $C880+$57   ; User variable: BULLET_X (2 bytes)
VAR_BULLET_Y         EQU $C880+$59   ; User variable: BULLET_Y (2 bytes)
VAR_ENEMY_ACTIVE     EQU $C880+$5B   ; User variable: ENEMY_ACTIVE (1 bytes)
VAR_ENEMY_X          EQU $C880+$5C   ; User variable: ENEMY_X (2 bytes)
VAR_ENEMY_Y          EQU $C880+$5E   ; User variable: ENEMY_Y (2 bytes)
VAR_ENEMY_VX         EQU $C880+$60   ; User variable: ENEMY_VX (1 bytes)

;***************************************************************************
; MAIN PROGRAM
;***************************************************************************

MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    CLR DRAW_VEC_INTENSITY ; 0 = use recorded/vector intensity (no override)
    LDA #$F8
    STA TEXT_SCALE_H      ; Default height = -8 (normal size)
    LDA #$48
    STA TEXT_SCALE_W      ; Default width = 72 (normal size)
    LDD #115
    STD VAR_SCREEN_WIDTH
    LDD #115
    STD VAR_SCREEN_HEIGHT
    LDD #8
    STD VAR_PLAYER_SIZE
    LDD #6
    STD VAR_ENEMY_SIZE
    LDD #4
    STD VAR_BULLET_SPEED
    LDD #0
    STD VAR_GAME_STATE
    LDD #0
    STD VAR_SCORE
    LDD #0
    STD VAR_PLAYER_X
    LDD #-90
    STD VAR_PLAYER_Y
    LDD #0
    STD VAR_BULLET_ACTIVE
    LDD #0
    STD VAR_BULLET_X
    LDD #0
    STD VAR_BULLET_Y
    LDD #1
    STD VAR_ENEMY_ACTIVE
    LDD #0
    STD VAR_ENEMY_X
    LDD #100
    STD VAR_ENEMY_Y
    LDD #1
    STD VAR_ENEMY_VX
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
    JSR $F1AA    ; DP_to_D0 (Joy_Analog requires DP=$D0)
    JSR $F1F5    ; Joy_Analog: poll all 4 axes once → $C81B-$C81E
    JSR Reset0Ref ; Restore beam state after Joy_Analog
    JSR $F1AF    ; DP_to_C8 (restore DP for RAM access)
; VPy_LINE:50
; NATIVE_CALL: UPDATE_BUTTONS at line 50
    JSR $F1AA     ; DP_to_D0
    JSR $F1BA     ; Read_Btns
    JSR $F1AF     ; DP_to_C8
    LDD #0
    STD RESULT
; VPy_LINE:52
    LDB >VAR_GAME_STATE
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #0
    LBNE IF_NEXT_1
; VPy_LINE:53
; NATIVE_CALL: PRINT_TEXT at line 53
    ; PRINT_TEXT: Print text at position
    LDD #-50
    STD >VAR_ARG0
    LDD #20
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_12123564084056612786      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:54
; NATIVE_CALL: PRINT_TEXT at line 54
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD >VAR_ARG0
    LDD #0
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_9120385760502433312      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:55
    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed
    BITA #$01
    BNE .J1B1_0_ON
    LDD #0
    BRA .J1B1_0_END
.J1B1_0_ON:
    LDD #1
.J1B1_0_END:
    STD RESULT
    CMPD #1
    LBNE IF_NEXT_3
; VPy_LINE:56
    LDD #1
    STB VAR_GAME_STATE
; VPy_LINE:57
    LDD #0
    STD VAR_SCORE
; VPy_LINE:58
    JSR RESET_ENEMY
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LBRA IF_END_0
IF_NEXT_1:
    LDB >VAR_GAME_STATE
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #1
    LBNE IF_NEXT_4
; VPy_LINE:62
; NATIVE_CALL: J1_X at line 62
    JSR J1X_BUILTIN
    STD RESULT
    STD VAR_PLAYER_X
; VPy_LINE:65
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed
    BITA #$01
    BNE .J1B1_1_ON
    LDD #0
    BRA .J1B1_1_END
.J1B1_1_ON:
    LDD #1
.J1B1_1_END:
    STD RESULT
    CMPD TMPVAL
    LBEQ .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    LBEQ .LOGIC_0_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_BULLET_ACTIVE
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBEQ .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    LBEQ .LOGIC_0_FALSE
    LDD #1
    LBRA .LOGIC_0_END
.LOGIC_0_FALSE:
    LDD #0
.LOGIC_0_END:
    LBEQ IF_NEXT_6
; VPy_LINE:66
    LDD #1
    STB VAR_BULLET_ACTIVE
; VPy_LINE:67
    LDD >VAR_PLAYER_X
    STD VAR_BULLET_X
; VPy_LINE:68
    LDD >VAR_PLAYER_Y
    STD VAR_BULLET_Y
    LBRA IF_END_5
IF_NEXT_6:
IF_END_5:
; VPy_LINE:71
    LDB >VAR_BULLET_ACTIVE
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #1
    LBNE IF_NEXT_8
; VPy_LINE:72
    LDB >VAR_BULLET_SPEED
    SEX             ; Sign-extend B -> D
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_BULLET_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_BULLET_Y
; VPy_LINE:73
    LDD >VAR_SCREEN_HEIGHT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BULLET_Y
    CMPD TMPVAL
    LBGT .CMP_3_TRUE
    LDD #0
    LBRA .CMP_3_END
.CMP_3_TRUE:
    LDD #1
.CMP_3_END:
    LBEQ IF_NEXT_10
; VPy_LINE:74
    LDD #0
    STB VAR_BULLET_ACTIVE
    LBRA IF_END_9
IF_NEXT_10:
IF_END_9:
; VPy_LINE:77
    LDB >VAR_ENEMY_ACTIVE
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #1
    LBNE IF_NEXT_12
; VPy_LINE:78
    LDD >VAR_ENEMY_SIZE
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENEMY_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BULLET_X
    CMPD TMPVAL
    LBGT .CMP_5_TRUE
    LDD #0
    LBRA .CMP_5_END
.CMP_5_TRUE:
    LDD #1
.CMP_5_END:
    LBEQ .LOGIC_4_FALSE
    LDD >VAR_ENEMY_SIZE
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENEMY_X
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BULLET_X
    CMPD TMPVAL
    LBLT .CMP_6_TRUE
    LDD #0
    LBRA .CMP_6_END
.CMP_6_TRUE:
    LDD #1
.CMP_6_END:
    LBEQ .LOGIC_4_FALSE
    LDD #1
    LBRA .LOGIC_4_END
.LOGIC_4_FALSE:
    LDD #0
.LOGIC_4_END:
    LBEQ IF_NEXT_14
; VPy_LINE:79
    LDD >VAR_ENEMY_SIZE
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENEMY_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BULLET_Y
    CMPD TMPVAL
    LBGT .CMP_8_TRUE
    LDD #0
    LBRA .CMP_8_END
.CMP_8_TRUE:
    LDD #1
.CMP_8_END:
    LBEQ .LOGIC_7_FALSE
    LDD >VAR_ENEMY_SIZE
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENEMY_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BULLET_Y
    CMPD TMPVAL
    LBLT .CMP_9_TRUE
    LDD #0
    LBRA .CMP_9_END
.CMP_9_TRUE:
    LDD #1
.CMP_9_END:
    LBEQ .LOGIC_7_FALSE
    LDD #1
    LBRA .LOGIC_7_END
.LOGIC_7_FALSE:
    LDD #0
.LOGIC_7_END:
    LBEQ IF_NEXT_16
; VPy_LINE:80
    LDD #0
    STB VAR_ENEMY_ACTIVE
; VPy_LINE:81
    LDD #0
    STB VAR_BULLET_ACTIVE
; VPy_LINE:82
    LDD #10
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_SCORE
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_SCORE
    LBRA IF_END_15
IF_NEXT_16:
IF_END_15:
    LBRA IF_END_13
IF_NEXT_14:
IF_END_13:
    LBRA IF_END_11
IF_NEXT_12:
IF_END_11:
    LBRA IF_END_7
IF_NEXT_8:
IF_END_7:
; VPy_LINE:85
    LDB >VAR_ENEMY_ACTIVE
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #1
    LBNE IF_NEXT_18
; VPy_LINE:86
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENEMY_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_ENEMY_Y
; VPy_LINE:87
    LDB >VAR_ENEMY_VX
    SEX             ; Sign-extend B -> D
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENEMY_X
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_ENEMY_X
; VPy_LINE:88
    LDD #100
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ENEMY_X
    CMPD TMPVAL
    LBGT .CMP_11_TRUE
    LDD #0
    LBRA .CMP_11_END
.CMP_11_TRUE:
    LDD #1
.CMP_11_END:
    LBNE .LOGIC_10_TRUE
    LDD #-100
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ENEMY_X
    CMPD TMPVAL
    LBLT .CMP_12_TRUE
    LDD #0
    LBRA .CMP_12_END
.CMP_12_TRUE:
    LDD #1
.CMP_12_END:
    LBNE .LOGIC_10_TRUE
    LDD #0
    LBRA .LOGIC_10_END
.LOGIC_10_TRUE:
    LDD #1
.LOGIC_10_END:
    LBEQ IF_NEXT_20
; VPy_LINE:89
    LDB >VAR_ENEMY_VX
    SEX             ; Sign-extend B -> D
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STB VAR_ENEMY_VX
    LBRA IF_END_19
IF_NEXT_20:
IF_END_19:
; VPy_LINE:91
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ENEMY_Y
    CMPD TMPVAL
    LBLT .CMP_13_TRUE
    LDD #0
    LBRA .CMP_13_END
.CMP_13_TRUE:
    LDD #1
.CMP_13_END:
    LBEQ IF_NEXT_22
; VPy_LINE:92
    LDD #2
    STB VAR_GAME_STATE
    LBRA IF_END_21
IF_NEXT_22:
IF_END_21:
    LBRA IF_END_17
IF_NEXT_18:
; VPy_LINE:94
    JSR RESET_ENEMY
IF_END_17:
; VPy_LINE:97
    JSR DRAW_PLAYER
; VPy_LINE:98
    JSR DRAW_ENEMY
; VPy_LINE:99
    JSR DRAW_BULLET
; VPy_LINE:100
; NATIVE_CALL: PRINT_NUMBER at line 100
    ; PRINT_NUMBER(x, y, num)
    LDD #-100
    STD >VAR_ARG0    ; X position
    LDD #100
    STD >VAR_ARG1    ; Y position
    LDD >VAR_SCORE
    STD >VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    LBRA IF_END_0
IF_NEXT_4:
    LDB >VAR_GAME_STATE
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #2
    LBNE IF_END_0
; VPy_LINE:103
; NATIVE_CALL: PRINT_TEXT at line 103
    ; PRINT_TEXT: Print text at position
    LDD #-30
    STD >VAR_ARG0
    LDD #20
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_62413928761410      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:104
; NATIVE_CALL: PRINT_TEXT at line 104
    ; PRINT_TEXT: Print text at position
    LDD #-20
    STD >VAR_ARG0
    LDD #0
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2440529928      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:105
; NATIVE_CALL: PRINT_NUMBER at line 105
    ; PRINT_NUMBER(x, y, num)
    LDD #10
    STD >VAR_ARG0    ; X position
    LDD #0
    STD >VAR_ARG1    ; Y position
    LDD >VAR_SCORE
    STD >VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
; VPy_LINE:106
    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed
    BITA #$01
    BNE .J1B1_2_ON
    LDD #0
    BRA .J1B1_2_END
.J1B1_2_ON:
    LDD #1
.J1B1_2_END:
    STD RESULT
    CMPD #1
    LBNE IF_NEXT_24
; VPy_LINE:107
    LDD #0
    STB VAR_GAME_STATE
    LBRA IF_END_23
IF_NEXT_24:
IF_END_23:
    LBRA IF_END_0
IF_END_0:
    RTS

; Function: RESET_ENEMY
RESET_ENEMY:
; VPy_LINE:27
    LDD #0
    STD VAR_ENEMY_X
; VPy_LINE:28
    LDD #100
    STD VAR_ENEMY_Y
; VPy_LINE:29
    LDD #1
    STB VAR_ENEMY_ACTIVE
    RTS

; Function: DRAW_PLAYER
DRAW_PLAYER:
; VPy_LINE:33
; NATIVE_CALL: DRAW_LINE at line 33
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_PLAYER_X
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_PLAYER_Y
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_PLAYER_SIZE
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_PLAYER_SIZE
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #80
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
; VPy_LINE:34
; NATIVE_CALL: DRAW_LINE at line 34
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_PLAYER_X
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_PLAYER_Y
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_PLAYER_SIZE
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_PLAYER_SIZE
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #80
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
; VPy_LINE:35
; NATIVE_CALL: DRAW_LINE at line 35
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_PLAYER_SIZE
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_PLAYER_SIZE
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_PLAYER_SIZE
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_PLAYER_SIZE
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #80
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    RTS

; Function: DRAW_ENEMY
DRAW_ENEMY:
; VPy_LINE:38
    LDB >VAR_ENEMY_ACTIVE
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #1
    LBNE IF_NEXT_26
; VPy_LINE:39
; NATIVE_CALL: DRAW_RECT at line 39
    ; DRAW_RECT: x, y, width, height[, intensity] (variable args)
    LDD >VAR_ENEMY_X
    TFR B,A
    STA DRAW_RECT_X
    LDD >VAR_ENEMY_Y
    TFR B,A
    STA DRAW_RECT_Y
    LDD >VAR_ENEMY_SIZE
    TFR B,A
    STA DRAW_RECT_WIDTH
    LDD >VAR_ENEMY_SIZE
    TFR B,A
    STA DRAW_RECT_HEIGHT
    LDD #80
    TFR B,A
    STA DRAW_RECT_INTENSITY
    JSR DRAW_RECT_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_25
IF_NEXT_26:
IF_END_25:
    RTS

; Function: DRAW_BULLET
DRAW_BULLET:
; VPy_LINE:42
    LDB >VAR_BULLET_ACTIVE
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #1
    LBNE IF_NEXT_28
; VPy_LINE:43
; NATIVE_CALL: DRAW_LINE at line 43
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_BULLET_X
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_BULLET_Y
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_BULLET_X
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #2
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_BULLET_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #80
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    LBRA IF_END_27
IF_NEXT_28:
IF_END_27:
    RTS

; Function: SETUP
SETUP:
; VPy_LINE:46
; NATIVE_CALL: SET_INTENSITY at line 46
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:47
    LDD #0
    STB VAR_GAME_STATE
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

VECTREX_PRINT_NUMBER:
    ; Print signed decimal number (-9999 to 9999)
    ; ARG0=x, ARG1=y, ARG2=value
    ;
    ; CACHE CHECK: if (value,x,y) matches the previous render, skip the
    ; entire DIVMOD pipeline (saves ~200 cycles) and reuse NUM_STR as-is.
    ; Drawing must still happen every frame (phosphor decay) so we go
    ; straight to PN_AFTER_CONVERT with NUM_STR already populated.
    LDA >PN_LAST_VALID
    BEQ .PN_NO_CACHE       ; first call → must convert
    LDD >VAR_ARG2
    CMPD >PN_LAST_VAL
    BNE .PN_NO_CACHE
    LDA >VAR_ARG0+1
    CMPA >PN_LAST_X
    BNE .PN_NO_CACHE
    LDA >VAR_ARG1+1
    CMPA >PN_LAST_Y
    BNE .PN_NO_CACHE
    LBRA .PN_AFTER_CONVERT  ; cache hit — NUM_STR still valid
.PN_NO_CACHE:
    ; Update cache key BEFORE conversion (value/x/y will be needed later)
    LDD >VAR_ARG2
    STD >PN_LAST_VAL
    LDA >VAR_ARG0+1
    STA >PN_LAST_X
    LDA >VAR_ARG1+1
    STA >PN_LAST_Y
    LDA #1
    STA >PN_LAST_VALID
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
    
    ; --- RIGHT-ALIGN: shift significant digits LEFT, pad right with spaces ---
    ; Keeps the buffer at 4 chars (BIOS Print_Str needs minimum width) but
    ; lets the number start at the call's X coordinate. Examples:
    ;   PRINT_NUMBER(x, y, 6)    → "6   "  (6 at x, then 3 trailing spaces)
    ;   PRINT_NUMBER(x, y, 12)   → "12  "
    ;   PRINT_NUMBER(x, y, 1234) → "1234"
    ;   PRINT_NUMBER(x, y, -5)   → "-5  "
    LDX #NUM_STR
    LDA ,X
    CMPA #'-'           ; if negative, '-' stays at [0]; sig digits start at [1]
    BNE .PN_RP_START
    LEAX 1,X
.PN_RP_START:
    TFR X,U             ; U = dest (start of digit area, after optional '-')
    LDB #0              ; B = leading-zero count
.PN_RP_FIND:
    LDA ,X
    CMPA #'0'
    BNE .PN_RP_FOUND    ; first non-'0' → start of sig digits
    LDA 1,X             ; check next byte
    CMPA #$80           ; if terminator, current '0' is the units digit — keep it
    BEQ .PN_RP_FOUND
    INCB
    LEAX 1,X
    BRA .PN_RP_FIND
.PN_RP_FOUND:
    TSTB
    BEQ .PN_RP_DONE     ; no leading zeros → nothing to shift
    ; Copy from X (first sig digit) to U (start), include $80 terminator
.PN_RP_COPY:
    LDA ,X+
    STA ,U+
    CMPA #$80
    BNE .PN_RP_COPY
    ; U is past the copied $80. Back up to that position and overwrite
    ; with B spaces, then place new $80 terminator at end.
    LEAU -1,U           ; U = where the $80 was just written
.PN_RP_PAD:
    LDA #' '
    STA ,U+
    DECB
    BNE .PN_RP_PAD
    LDA #$80
    STA ,U              ; final terminator
.PN_RP_DONE:
.PN_AFTER_CONVERT:
    ; STEP 2: hand the rendered NUM_STR to VECTREX_PRINT_TEXT, which uses
    ; the custom vector font path (consistent visual with PiTrex/RP2350).
    LDX #NUM_STR
    STX >VAR_ARG2     ; PRINT_TEXT reads string ptr from VAR_ARG2
    JSR VECTREX_PRINT_TEXT
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

; === JOYSTICK BUILTIN SUBROUTINES (cached, Joy_Analog runs once per frame) ===
; J1_X() - Read Joystick 1 X axis from cached BIOS value at $C81B
J1X_BUILTIN:
    LDB >$C81B   ; Vec_Joy_1_X (populated each frame by auto-injected Joy_Analog)
    SEX          ; Sign-extend B to D
    ADDD #2      ; Calibrate center offset
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
PRINT_TEXT_STR_2440529928:
    FCC "SCORE:"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_62413928761410:
    FCC "GAME OVER"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_9120385760502433312:
    FCC "PRESS BUTTON 1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_12123564084056612786:
    FCC "SPACE SHOOTER"
    FCB $80          ; Vectrex string terminator

