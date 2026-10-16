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
    FCC "JETPAC MINIMAL"
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
    JSR $F533        ; Init_Music_Buf: init BIOS sound work buffer at Vec_Default_Stk
    LDS #$CFFF       ; Stack -> top of Vectrex 2KB RAM (avoids user var collision)

    ; Initialize bank tracking vars to 0 (prevents spurious $DF00 writes)
    LDA #0
    STA >CURRENT_ROM_BANK   ; Bank 0 is always active at boot
    ; Initialize audio system variables to prevent random noise on startup
    CLR >SFX_ACTIVE         ; Mark SFX as inactive (0=off)
    LDD #$0000
    STD >SFX_PTR            ; Clear SFX pointer
    STA >PSG_MUSIC_BANK     ; Bank 0 for music (prevents garbage bank switch in emulator)
    STA >SFX_BANK           ; Bank 0 for SFX (prevents garbage bank switch in emulator)
    CLR >PSG_IS_PLAYING     ; No music playing at startup
    CLR >PSG_DELAY_FRAMES   ; Clear delay counter
    STD >PSG_MUSIC_PTR      ; Clear music pointer (D is already 0)
    STD >PSG_MUSIC_START    ; Clear loop pointer
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
VAR_SCREEN           EQU $C880+$4F   ; User variable: SCREEN (2 bytes)
VAR_LOGO_TIMER       EQU $C880+$51   ; User variable: LOGO_TIMER (2 bytes)
VAR_LOGO_DRAW_COUNTER EQU $C880+$53   ; User variable: LOGO_DRAW_COUNTER (2 bytes)
VAR_FUEL_LEVEL       EQU $C880+$55   ; User variable: FUEL_LEVEL (2 bytes)
VAR_CARRIED_PART     EQU $C880+$57   ; User variable: CARRIED_PART (2 bytes)
VAR_ENEMY_X          EQU $C880+$59   ; User variable: ENEMY_X (2 bytes)
VAR_ENEMY_Y          EQU $C880+$5B   ; User variable: ENEMY_Y (2 bytes)
VAR_ENEMY_DX         EQU $C880+$5D   ; User variable: ENEMY_DX (2 bytes)
VAR_PART1_X          EQU $C880+$5F   ; User variable: PART1_X (2 bytes)
VAR_PART1_Y          EQU $C880+$61   ; User variable: PART1_Y (2 bytes)
VAR_PART1_STATE      EQU $C880+$63   ; User variable: PART1_STATE (2 bytes)
VAR_PART2_X          EQU $C880+$65   ; User variable: PART2_X (2 bytes)
VAR_PART2_Y          EQU $C880+$67   ; User variable: PART2_Y (2 bytes)
VAR_PART2_STATE      EQU $C880+$69   ; User variable: PART2_STATE (2 bytes)
VAR_PART3_X          EQU $C880+$6B   ; User variable: PART3_X (2 bytes)
VAR_PART3_Y          EQU $C880+$6D   ; User variable: PART3_Y (2 bytes)
VAR_PART3_STATE      EQU $C880+$6F   ; User variable: PART3_STATE (2 bytes)
VAR_SHIP_BASE_X      EQU $C880+$71   ; User variable: SHIP_BASE_X (2 bytes)
VAR_SHIP_BASE_Y      EQU $C880+$73   ; User variable: SHIP_BASE_Y (2 bytes)
VAR_PLAT1_Y          EQU $C880+$75   ; User variable: PLAT1_Y (2 bytes)
VAR_PLAT2_Y          EQU $C880+$77   ; User variable: PLAT2_Y (2 bytes)
VAR_PLAT3_Y          EQU $C880+$79   ; User variable: PLAT3_Y (2 bytes)
VAR_PLAYER_X         EQU $C880+$7B   ; User variable: PLAYER_X (2 bytes)
VAR_PLAYER_Y         EQU $C880+$7D   ; User variable: PLAYER_Y (2 bytes)
VAR_PLAYER_DIR       EQU $C880+$7F   ; User variable: PLAYER_DIR (2 bytes)
VAR_JOY_X            EQU $C880+$81   ; User variable: JOY_X (2 bytes)
VAR_JOY_Y            EQU $C880+$83   ; User variable: JOY_Y (2 bytes)
VAR_DIST_X           EQU $C880+$85   ; User variable: DIST_X (2 bytes)
VAR_DIST_Y           EQU $C880+$87   ; User variable: DIST_Y (2 bytes)
PSG_MUSIC_PTR        EQU $C880+$89   ; PSG music data pointer (2 bytes)
PSG_MUSIC_START      EQU $C880+$8B   ; PSG music start pointer (for loops) (2 bytes)
PSG_MUSIC_ACTIVE     EQU $C880+$8D   ; PSG music active flag (1 bytes)
PSG_IS_PLAYING       EQU $C880+$8E   ; PSG playing flag (1 bytes)
PSG_DELAY_FRAMES     EQU $C880+$8F   ; PSG frame delay counter (1 bytes)
PSG_MUSIC_BANK       EQU $C880+$90   ; PSG music bank ID (for multibank) (1 bytes)
SFX_PTR              EQU $C880+$91   ; SFX data pointer (2 bytes)
SFX_ACTIVE           EQU $C880+$93   ; SFX active flag (1 bytes)
SFX_BANK             EQU $C880+$94   ; SFX bank ID (for multibank) (1 bytes)

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
    LDD #0
    STD VAR_SCREEN
    LDD #0
    STD VAR_LOGO_TIMER
    LDD #0
    STD VAR_LOGO_DRAW_COUNTER
    LDD #0
    STD VAR_FUEL_LEVEL
    LDD #0
    STD VAR_CARRIED_PART
    LDD #100
    STD VAR_ENEMY_X
    LDD #50
    STD VAR_ENEMY_Y
    LDD #-2
    STD VAR_ENEMY_DX
    LDD #-80
    STD VAR_PART1_X
    LDD #-40
    STD VAR_PART1_Y
    LDD #0
    STD VAR_PART1_STATE
    LDD #0
    STD VAR_PART2_X
    LDD #-15
    STD VAR_PART2_Y
    LDD #0
    STD VAR_PART2_STATE
    LDD #80
    STD VAR_PART3_X
    LDD #15
    STD VAR_PART3_Y
    LDD #0
    STD VAR_PART3_STATE
    LDD #0
    STD VAR_SHIP_BASE_X
    LDD #-85
    STD VAR_SHIP_BASE_Y
    LDD #-70
    STD VAR_PLAT1_Y
    LDD #-20
    STD VAR_PLAT2_Y
    LDD #30
    STD VAR_PLAT3_Y
    LDD #0
    STD VAR_PLAYER_X
    LDD #-80
    STD VAR_PLAYER_Y
    LDD #0
    STD VAR_PLAYER_DIR
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
; VPy_LINE:119
; NATIVE_CALL: PLAY_MUSIC at line 119
    ; PLAY_MUSIC("jetpac_theme") - play music asset (index=0)
    LDX #_JETPAC_THEME_MUSIC  ; Load music data pointer
    JSR PLAY_MUSIC_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:120
    ; TODO: Statement Pass { source_line: 120 }
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
; VPy_LINE:124
    LDD >VAR_SCREEN
    CMPD #0
    LBNE IF_NEXT_1
; VPy_LINE:126
    JSR DRAW_LOGO_SCREEN
; VPy_LINE:127
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_LOGO_TIMER
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_LOGO_TIMER
; VPy_LINE:129
    LDD #300
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_LOGO_TIMER
    CMPD TMPVAL
    LBGT .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_3
; VPy_LINE:130
    LDD #1
    STD VAR_SCREEN
; VPy_LINE:131
    LDD #0
    STD VAR_LOGO_TIMER
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
; VPy_LINE:133
    LDD >VAR_SCREEN
    CMPD #1
    LBNE IF_NEXT_5
; VPy_LINE:137
; NATIVE_CALL: J1_X at line 137
    JSR J1X_BUILTIN
    STD RESULT
    STD VAR_JOY_X
; VPy_LINE:138
; NATIVE_CALL: J1_Y at line 138
    JSR J1Y_BUILTIN
    STD RESULT
    STD VAR_JOY_Y
; VPy_LINE:142
    LDD >VAR_JOY_X
    CMPD #-1
    LBNE IF_NEXT_7
; VPy_LINE:143
    LDD #3
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_PLAYER_X
; VPy_LINE:144
    LDD #1
    STD VAR_PLAYER_DIR
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
; VPy_LINE:145
    LDD >VAR_JOY_X
    CMPD #1
    LBNE IF_NEXT_9
; VPy_LINE:146
    LDD #3
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_PLAYER_X
; VPy_LINE:147
    LDD #0
    STD VAR_PLAYER_DIR
    LBRA IF_END_8
IF_NEXT_9:
IF_END_8:
; VPy_LINE:150
    LDD >VAR_JOY_Y
    CMPD #-1
    LBNE IF_NEXT_11
; VPy_LINE:151
    LDD #3
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_PLAYER_Y
    LBRA IF_END_10
IF_NEXT_11:
IF_END_10:
; VPy_LINE:152
    LDD >VAR_JOY_Y
    CMPD #1
    LBNE IF_NEXT_13
; VPy_LINE:153
    LDD #3
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_PLAYER_Y
    LBRA IF_END_12
IF_NEXT_13:
IF_END_12:
; VPy_LINE:156
    LDD #-110
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    CMPD TMPVAL
    LBLT .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    LBEQ IF_NEXT_15
; VPy_LINE:157
    LDD #-110
    STD VAR_PLAYER_X
    LBRA IF_END_14
IF_NEXT_15:
IF_END_14:
; VPy_LINE:158
    LDD #110
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    CMPD TMPVAL
    LBGT .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    LBEQ IF_NEXT_17
; VPy_LINE:159
    LDD #110
    STD VAR_PLAYER_X
    LBRA IF_END_16
IF_NEXT_17:
IF_END_16:
; VPy_LINE:160
    LDD #-90
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_Y
    CMPD TMPVAL
    LBLT .CMP_3_TRUE
    LDD #0
    LBRA .CMP_3_END
.CMP_3_TRUE:
    LDD #1
.CMP_3_END:
    LBEQ IF_NEXT_19
; VPy_LINE:161
    LDD #-90
    STD VAR_PLAYER_Y
    LBRA IF_END_18
IF_NEXT_19:
IF_END_18:
; VPy_LINE:162
    LDD #90
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_Y
    CMPD TMPVAL
    LBGT .CMP_4_TRUE
    LDD #0
    LBRA .CMP_4_END
.CMP_4_TRUE:
    LDD #1
.CMP_4_END:
    LBEQ IF_NEXT_21
; VPy_LINE:163
    LDD #90
    STD VAR_PLAYER_Y
    LBRA IF_END_20
IF_NEXT_21:
IF_END_20:
; VPy_LINE:167
    LDD >VAR_CARRIED_PART
    CMPD #0
    LBNE IF_NEXT_23
; VPy_LINE:176
    LDD >VAR_PART2_STATE
    CMPD #0
    LBNE IF_NEXT_25
; VPy_LINE:177
    LDD >VAR_PART2_X
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DIST_X
; VPy_LINE:178
    LDD >VAR_PART2_Y
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DIST_Y
; VPy_LINE:179
    LDD #20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DIST_X
    CMPD TMPVAL
    LBLT .CMP_8_TRUE
    LDD #0
    LBRA .CMP_8_END
.CMP_8_TRUE:
    LDD #1
.CMP_8_END:
    LBEQ .LOGIC_7_FALSE
    LDD #-20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DIST_X
    CMPD TMPVAL
    LBGT .CMP_9_TRUE
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
    LBEQ .LOGIC_6_FALSE
    LDD #20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DIST_Y
    CMPD TMPVAL
    LBLT .CMP_10_TRUE
    LDD #0
    LBRA .CMP_10_END
.CMP_10_TRUE:
    LDD #1
.CMP_10_END:
    LBEQ .LOGIC_6_FALSE
    LDD #1
    LBRA .LOGIC_6_END
.LOGIC_6_FALSE:
    LDD #0
.LOGIC_6_END:
    LBEQ .LOGIC_5_FALSE
    LDD #-20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DIST_Y
    CMPD TMPVAL
    LBGT .CMP_11_TRUE
    LDD #0
    LBRA .CMP_11_END
.CMP_11_TRUE:
    LDD #1
.CMP_11_END:
    LBEQ .LOGIC_5_FALSE
    LDD #1
    LBRA .LOGIC_5_END
.LOGIC_5_FALSE:
    LDD #0
.LOGIC_5_END:
    LBEQ IF_NEXT_27
; VPy_LINE:180
    LDD #2
    STD VAR_CARRIED_PART
; VPy_LINE:181
    LDD #1
    STD VAR_PART2_STATE
    LBRA IF_END_26
IF_NEXT_27:
IF_END_26:
    LBRA IF_END_24
IF_NEXT_25:
IF_END_24:
; VPy_LINE:183
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PART3_STATE
    CMPD TMPVAL
    LBEQ .CMP_13_TRUE
    LDD #0
    LBRA .CMP_13_END
.CMP_13_TRUE:
    LDD #1
.CMP_13_END:
    LBEQ .LOGIC_12_FALSE
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PART2_STATE
    CMPD TMPVAL
    LBEQ .CMP_14_TRUE
    LDD #0
    LBRA .CMP_14_END
.CMP_14_TRUE:
    LDD #1
.CMP_14_END:
    LBEQ .LOGIC_12_FALSE
    LDD #1
    LBRA .LOGIC_12_END
.LOGIC_12_FALSE:
    LDD #0
.LOGIC_12_END:
    LBEQ IF_NEXT_29
; VPy_LINE:184
    LDD >VAR_PART3_X
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DIST_X
; VPy_LINE:185
    LDD >VAR_PART3_Y
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DIST_Y
; VPy_LINE:186
    LDD #20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DIST_X
    CMPD TMPVAL
    LBLT .CMP_18_TRUE
    LDD #0
    LBRA .CMP_18_END
.CMP_18_TRUE:
    LDD #1
.CMP_18_END:
    LBEQ .LOGIC_17_FALSE
    LDD #-20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DIST_X
    CMPD TMPVAL
    LBGT .CMP_19_TRUE
    LDD #0
    LBRA .CMP_19_END
.CMP_19_TRUE:
    LDD #1
.CMP_19_END:
    LBEQ .LOGIC_17_FALSE
    LDD #1
    LBRA .LOGIC_17_END
.LOGIC_17_FALSE:
    LDD #0
.LOGIC_17_END:
    LBEQ .LOGIC_16_FALSE
    LDD #20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DIST_Y
    CMPD TMPVAL
    LBLT .CMP_20_TRUE
    LDD #0
    LBRA .CMP_20_END
.CMP_20_TRUE:
    LDD #1
.CMP_20_END:
    LBEQ .LOGIC_16_FALSE
    LDD #1
    LBRA .LOGIC_16_END
.LOGIC_16_FALSE:
    LDD #0
.LOGIC_16_END:
    LBEQ .LOGIC_15_FALSE
    LDD #-20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DIST_Y
    CMPD TMPVAL
    LBGT .CMP_21_TRUE
    LDD #0
    LBRA .CMP_21_END
.CMP_21_TRUE:
    LDD #1
.CMP_21_END:
    LBEQ .LOGIC_15_FALSE
    LDD #1
    LBRA .LOGIC_15_END
.LOGIC_15_FALSE:
    LDD #0
.LOGIC_15_END:
    LBEQ IF_NEXT_31
; VPy_LINE:187
    LDD #3
    STD VAR_CARRIED_PART
; VPy_LINE:188
    LDD #1
    STD VAR_PART3_STATE
    LBRA IF_END_30
IF_NEXT_31:
IF_END_30:
    LBRA IF_END_28
IF_NEXT_29:
IF_END_28:
    LBRA IF_END_22
IF_NEXT_23:
IF_END_22:
; VPy_LINE:192
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CARRIED_PART
    CMPD TMPVAL
    LBGT .CMP_22_TRUE
    LDD #0
    LBRA .CMP_22_END
.CMP_22_TRUE:
    LDD #1
.CMP_22_END:
    LBEQ IF_NEXT_33
; VPy_LINE:193
    LDD >VAR_SHIP_BASE_X
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DIST_X
; VPy_LINE:194
    LDD >VAR_SHIP_BASE_Y
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DIST_Y
; VPy_LINE:195
    LDD #25
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DIST_X
    CMPD TMPVAL
    LBLT .CMP_26_TRUE
    LDD #0
    LBRA .CMP_26_END
.CMP_26_TRUE:
    LDD #1
.CMP_26_END:
    LBEQ .LOGIC_25_FALSE
    LDD #-25
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DIST_X
    CMPD TMPVAL
    LBGT .CMP_27_TRUE
    LDD #0
    LBRA .CMP_27_END
.CMP_27_TRUE:
    LDD #1
.CMP_27_END:
    LBEQ .LOGIC_25_FALSE
    LDD #1
    LBRA .LOGIC_25_END
.LOGIC_25_FALSE:
    LDD #0
.LOGIC_25_END:
    LBEQ .LOGIC_24_FALSE
    LDD #25
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DIST_Y
    CMPD TMPVAL
    LBLT .CMP_28_TRUE
    LDD #0
    LBRA .CMP_28_END
.CMP_28_TRUE:
    LDD #1
.CMP_28_END:
    LBEQ .LOGIC_24_FALSE
    LDD #1
    LBRA .LOGIC_24_END
.LOGIC_24_FALSE:
    LDD #0
.LOGIC_24_END:
    LBEQ .LOGIC_23_FALSE
    LDD #-25
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DIST_Y
    CMPD TMPVAL
    LBGT .CMP_29_TRUE
    LDD #0
    LBRA .CMP_29_END
.CMP_29_TRUE:
    LDD #1
.CMP_29_END:
    LBEQ .LOGIC_23_FALSE
    LDD #1
    LBRA .LOGIC_23_END
.LOGIC_23_FALSE:
    LDD #0
.LOGIC_23_END:
    LBEQ IF_NEXT_35
; VPy_LINE:197
    LDD >VAR_CARRIED_PART
    CMPD #1
    LBNE IF_NEXT_37
; VPy_LINE:198
    LDD #2
    STD VAR_PART1_STATE
    LBRA IF_END_36
IF_NEXT_37:
IF_END_36:
; VPy_LINE:199
    LDD >VAR_CARRIED_PART
    CMPD #2
    LBNE IF_NEXT_39
; VPy_LINE:200
    LDD #2
    STD VAR_PART2_STATE
    LBRA IF_END_38
IF_NEXT_39:
IF_END_38:
; VPy_LINE:201
    LDD >VAR_CARRIED_PART
    CMPD #3
    LBNE IF_NEXT_41
; VPy_LINE:202
    LDD #2
    STD VAR_PART3_STATE
    LBRA IF_END_40
IF_NEXT_41:
IF_END_40:
; VPy_LINE:203
    LDD #0
    STD VAR_CARRIED_PART
    LBRA IF_END_34
IF_NEXT_35:
IF_END_34:
    LBRA IF_END_32
IF_NEXT_33:
IF_END_32:
; VPy_LINE:206
; NATIVE_CALL: DEBUG_PRINT at line 206
    LDD >VAR_PLAYER_DIR
    ; DEBUG_PRINT(PLAYER_DIR)
    STB $C000
    STA $C002
    LDX #DEBUG_LABEL_PLAYER_DIR
    STX $C004
    LDA #$FE
    STA $C001
    BRA DEBUG_SKIP_0
DEBUG_LABEL_PLAYER_DIR:
    FCC "PLAYER_DIR"
    FCB $00
DEBUG_SKIP_0:
    LDD #0
    STD RESULT
; VPy_LINE:210
; NATIVE_CALL: SET_INTENSITY at line 210
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:211
; NATIVE_CALL: DRAW_VECTOR at line 211
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: platform (index=3, 4 paths)
    LDD #-80
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_0          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_PLAT1_Y
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
    LDX #_PLATFORM_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_0:
    LDD #0
    STD RESULT
; VPy_LINE:212
; NATIVE_CALL: DRAW_VECTOR at line 212
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: platform (index=3, 4 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_1          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_PLAT2_Y
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_1
    LDB #$FF
.sx_pos_1:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_PLATFORM_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_1:
    LDD #0
    STD RESULT
; VPy_LINE:213
; NATIVE_CALL: DRAW_VECTOR at line 213
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: platform (index=3, 4 paths)
    LDD #80
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_2          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_PLAT3_Y
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_2
    LDB #$FF
.sx_pos_2:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_PLATFORM_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_2:
    LDD #0
    STD RESULT
; VPy_LINE:216
; NATIVE_CALL: SET_INTENSITY at line 216
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:219
    LDD >VAR_PART2_STATE
    CMPD #0
    LBNE IF_NEXT_43
; VPy_LINE:220
; NATIVE_CALL: DRAW_VECTOR at line 220
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: rocket_middle (index=5, 4 paths)
    LDD >VAR_PART2_X
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_3          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_PART2_Y
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_3
    LDB #$FF
.sx_pos_3:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_ROCKET_MIDDLE_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ROCKET_MIDDLE_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ROCKET_MIDDLE_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ROCKET_MIDDLE_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_3:
    LDD #0
    STD RESULT
    LBRA IF_END_42
IF_NEXT_43:
IF_END_42:
; VPy_LINE:221
    LDD >VAR_PART3_STATE
    CMPD #0
    LBNE IF_NEXT_45
; VPy_LINE:222
; NATIVE_CALL: DRAW_VECTOR at line 222
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: rocket_top (index=6, 2 paths)
    LDD >VAR_PART3_X
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_4          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_PART3_Y
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_4
    LDB #$FF
.sx_pos_4:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_ROCKET_TOP_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ROCKET_TOP_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_4:
    LDD #0
    STD RESULT
    LBRA IF_END_44
IF_NEXT_45:
IF_END_44:
; VPy_LINE:225
; NATIVE_CALL: SET_INTENSITY at line 225
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:226
; NATIVE_CALL: DRAW_VECTOR at line 226
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: rocket_base (index=4, 4 paths)
    LDD >VAR_SHIP_BASE_X
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_5          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_SHIP_BASE_Y
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_5
    LDB #$FF
.sx_pos_5:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_ROCKET_BASE_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ROCKET_BASE_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ROCKET_BASE_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ROCKET_BASE_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_5:
    LDD #0
    STD RESULT
; VPy_LINE:229
    LDD >VAR_PART1_STATE
    CMPD #2
    LBNE IF_NEXT_47
; VPy_LINE:230
; NATIVE_CALL: SET_INTENSITY at line 230
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:231
; NATIVE_CALL: DRAW_VECTOR at line 231
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: rocket_base (index=4, 4 paths)
    LDD >VAR_SHIP_BASE_X
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_6          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_SHIP_BASE_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_6
    LDB #$FF
.sx_pos_6:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_ROCKET_BASE_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ROCKET_BASE_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ROCKET_BASE_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ROCKET_BASE_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_6:
    LDD #0
    STD RESULT
    LBRA IF_END_46
IF_NEXT_47:
IF_END_46:
; VPy_LINE:232
    LDD >VAR_PART2_STATE
    CMPD #2
    LBNE IF_NEXT_49
; VPy_LINE:233
; NATIVE_CALL: SET_INTENSITY at line 233
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:234
; NATIVE_CALL: DRAW_VECTOR at line 234
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: rocket_middle (index=5, 4 paths)
    LDD >VAR_SHIP_BASE_X
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_7          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_SHIP_BASE_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_7
    LDB #$FF
.sx_pos_7:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_ROCKET_MIDDLE_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ROCKET_MIDDLE_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ROCKET_MIDDLE_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ROCKET_MIDDLE_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_7:
    LDD #0
    STD RESULT
    LBRA IF_END_48
IF_NEXT_49:
IF_END_48:
; VPy_LINE:235
    LDD >VAR_PART3_STATE
    CMPD #2
    LBNE IF_NEXT_51
; VPy_LINE:236
; NATIVE_CALL: SET_INTENSITY at line 236
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:237
; NATIVE_CALL: DRAW_VECTOR at line 237
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: rocket_top (index=6, 2 paths)
    LDD >VAR_SHIP_BASE_X
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_8          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_SHIP_BASE_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_8
    LDB #$FF
.sx_pos_8:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_ROCKET_TOP_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ROCKET_TOP_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_8:
    LDD #0
    STD RESULT
    LBRA IF_END_50
IF_NEXT_51:
IF_END_50:
; VPy_LINE:240
; NATIVE_CALL: SET_INTENSITY at line 240
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:241
; NATIVE_CALL: DRAW_VECTOR at line 241
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: enemy_alien (index=1, 7 paths)
    LDD >VAR_ENEMY_X
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_9          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_ENEMY_Y
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_9
    LDB #$FF
.sx_pos_9:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_ENEMY_ALIEN_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ENEMY_ALIEN_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ENEMY_ALIEN_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ENEMY_ALIEN_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ENEMY_ALIEN_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ENEMY_ALIEN_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ENEMY_ALIEN_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_9:
    LDD #0
    STD RESULT
; VPy_LINE:244
    LDD >VAR_ENEMY_DX
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENEMY_X
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_ENEMY_X
; VPy_LINE:247
    LDD #-100
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ENEMY_X
    CMPD TMPVAL
    LBLT .CMP_30_TRUE
    LDD #0
    LBRA .CMP_30_END
.CMP_30_TRUE:
    LDD #1
.CMP_30_END:
    LBEQ IF_NEXT_53
; VPy_LINE:248
    LDD #2
    STD VAR_ENEMY_DX
    LBRA IF_END_52
IF_NEXT_53:
IF_END_52:
; VPy_LINE:249
    LDD #100
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ENEMY_X
    CMPD TMPVAL
    LBGT .CMP_31_TRUE
    LDD #0
    LBRA .CMP_31_END
.CMP_31_TRUE:
    LDD #1
.CMP_31_END:
    LBEQ IF_NEXT_55
; VPy_LINE:250
    LDD #-2
    STD VAR_ENEMY_DX
    LBRA IF_END_54
IF_NEXT_55:
IF_END_54:
; VPy_LINE:253
; NATIVE_CALL: SET_INTENSITY at line 253
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:254
; NATIVE_CALL: DRAW_VECTOR_EX at line 254
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: astronaut_armed (index=0, 10 paths) with mirror + intensity
    LDD >VAR_PLAYER_X
    TFR B,A       ; X position (low byte) — B already holds it
    STA DRAW_VEC_X
    LDD >VAR_PLAYER_Y
    TFR B,A       ; Y position (low byte) — B already holds it
    STA DRAW_VEC_Y
    LDD >VAR_PLAYER_DIR
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_10_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_10_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_10_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_10_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_10_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_10_CALL:
    ; Set intensity override for drawing
    LDD #100
    TFR B,A       ; Intensity (0-127) — B already holds it
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_ASTRONAUT_ARMED_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ASTRONAUT_ARMED_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ASTRONAUT_ARMED_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ASTRONAUT_ARMED_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ASTRONAUT_ARMED_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ASTRONAUT_ARMED_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ASTRONAUT_ARMED_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ASTRONAUT_ARMED_PATH7  ; Load path 7
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ASTRONAUT_ARMED_PATH8  ; Load path 8
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ASTRONAUT_ARMED_PATH9  ; Load path 9
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
; VPy_LINE:258
    LDD >VAR_CARRIED_PART
    CMPD #1
    LBNE IF_NEXT_57
; VPy_LINE:259
; NATIVE_CALL: SET_INTENSITY at line 259
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:260
; NATIVE_CALL: DRAW_VECTOR at line 260
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: rocket_base (index=4, 4 paths)
    LDD >VAR_PLAYER_X
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_11          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #12
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_11
    LDB #$FF
.sx_pos_11:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_ROCKET_BASE_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ROCKET_BASE_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ROCKET_BASE_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ROCKET_BASE_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_11:
    LDD #0
    STD RESULT
    LBRA IF_END_56
IF_NEXT_57:
IF_END_56:
; VPy_LINE:261
    LDD >VAR_CARRIED_PART
    CMPD #2
    LBNE IF_NEXT_59
; VPy_LINE:262
; NATIVE_CALL: SET_INTENSITY at line 262
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:263
; NATIVE_CALL: DRAW_VECTOR at line 263
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: rocket_middle (index=5, 4 paths)
    LDD >VAR_PLAYER_X
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_12          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #12
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_12
    LDB #$FF
.sx_pos_12:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_ROCKET_MIDDLE_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ROCKET_MIDDLE_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ROCKET_MIDDLE_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ROCKET_MIDDLE_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_12:
    LDD #0
    STD RESULT
    LBRA IF_END_58
IF_NEXT_59:
IF_END_58:
; VPy_LINE:264
    LDD >VAR_CARRIED_PART
    CMPD #3
    LBNE IF_NEXT_61
; VPy_LINE:265
; NATIVE_CALL: SET_INTENSITY at line 265
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:266
; NATIVE_CALL: DRAW_VECTOR at line 266
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: rocket_top (index=6, 2 paths)
    LDD >VAR_PLAYER_X
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_13          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #12
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_13
    LDB #$FF
.sx_pos_13:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_ROCKET_TOP_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ROCKET_TOP_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_13:
    LDD #0
    STD RESULT
    LBRA IF_END_60
IF_NEXT_61:
IF_END_60:
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX
    RTS

; Function: DRAW_LOGO_SCREEN
DRAW_LOGO_SCREEN:
; VPy_LINE:273
; NATIVE_CALL: SET_INTENSITY at line 273
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:274
; NATIVE_CALL: DRAW_VECTOR at line 274
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: jetpac_logo (index=2, 10 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_14          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #20
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_14
    LDB #$FF
.sx_pos_14:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_JETPAC_LOGO_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_JETPAC_LOGO_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_JETPAC_LOGO_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_JETPAC_LOGO_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_JETPAC_LOGO_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_JETPAC_LOGO_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_JETPAC_LOGO_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_JETPAC_LOGO_PATH7  ; Load path 7
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_JETPAC_LOGO_PATH8  ; Load path 8
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_JETPAC_LOGO_PATH9  ; Load path 9
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_14:
    LDD #0
    STD RESULT
    RTS

;***************************************************************************
; EMBEDDED ASSETS (vectors, music, levels, SFX)
;***************************************************************************

; Generated from astronaut_armed.vec (Malban Draw_Sync_List format)
; Total paths: 10, points: 29
; X bounds: min=-6, max=8, width=14
; Center: (1, 0)

_ASTRONAUT_ARMED_WIDTH EQU 14
_ASTRONAUT_ARMED_HALF_WIDTH EQU 7
_ASTRONAUT_ARMED_HEIGHT EQU 18
_ASTRONAUT_ARMED_HALF_HEIGHT EQU 9
_ASTRONAUT_ARMED_CENTER_X EQU 1
_ASTRONAUT_ARMED_CENTER_Y EQU 0

_ASTRONAUT_ARMED_VECTORS:  ; Main entry (header + 10 path(s))
    FDB 10               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _ASTRONAUT_ARMED_PATH0        ; pointer to path 0
    FDB _ASTRONAUT_ARMED_PATH1        ; pointer to path 1
    FDB _ASTRONAUT_ARMED_PATH2        ; pointer to path 2
    FDB _ASTRONAUT_ARMED_PATH3        ; pointer to path 3
    FDB _ASTRONAUT_ARMED_PATH4        ; pointer to path 4
    FDB _ASTRONAUT_ARMED_PATH5        ; pointer to path 5
    FDB _ASTRONAUT_ARMED_PATH6        ; pointer to path 6
    FDB _ASTRONAUT_ARMED_PATH7        ; pointer to path 7
    FDB _ASTRONAUT_ARMED_PATH8        ; pointer to path 8
    FDB _ASTRONAUT_ARMED_PATH9        ; pointer to path 9

_ASTRONAUT_ARMED_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $FF,$FE,0,0        ; path0: header (y=-1, x=-2)
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_ASTRONAUT_ARMED_PATH1:    ; Path 1
    FCB 100              ; path1: intensity
    FCB $F7,$02,0,0        ; path1: header (y=-9, x=2)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB 2                ; End marker (path complete)

_ASTRONAUT_ARMED_PATH2:    ; Path 2
    FCB 110              ; path2: intensity
    FCB $FC,$04,0,0        ; path2: header (y=-4, x=4)
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_ASTRONAUT_ARMED_PATH3:    ; Path 3
    FCB 110              ; path3: intensity
    FCB $FC,$04,0,0        ; path3: header (y=-4, x=4)
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB 2                ; End marker (path complete)

_ASTRONAUT_ARMED_PATH4:    ; Path 4
    FCB 110              ; path4: intensity
    FCB $FC,$FB,0,0        ; path4: header (y=-4, x=-5)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB 2                ; End marker (path complete)

_ASTRONAUT_ARMED_PATH5:    ; Path 5
    FCB 100              ; path5: intensity
    FCB $03,$F9,0,0        ; path5: header (y=3, x=-7)
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB 2                ; End marker (path complete)

_ASTRONAUT_ARMED_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $08,$FB,0,0        ; path6: header (y=8, x=-5)
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB 2                ; End marker (path complete)

_ASTRONAUT_ARMED_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $08,$02,0,0        ; path7: header (y=8, x=2)
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB $FF,$00,$F9          ; flag=-1, dy=0, dx=-7
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB 2                ; End marker (path complete)

_ASTRONAUT_ARMED_PATH8:    ; Path 8
    FCB 100              ; path8: intensity
    FCB $05,$02,0,0        ; path8: header (y=5, x=2)
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ASTRONAUT_ARMED_PATH9:    ; Path 9
    FCB 100              ; path9: intensity
    FCB $00,$07,0,0        ; path9: header (y=0, x=7)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB 2                ; End marker (path complete)
; Generated from enemy_alien.vec (Malban Draw_Sync_List format)
; Total paths: 7, points: 18
; X bounds: min=-4, max=5, width=9
; Center: (0, 0)

_ENEMY_ALIEN_WIDTH EQU 9
_ENEMY_ALIEN_HALF_WIDTH EQU 4
_ENEMY_ALIEN_HEIGHT EQU 18
_ENEMY_ALIEN_HALF_HEIGHT EQU 9
_ENEMY_ALIEN_CENTER_X EQU 0
_ENEMY_ALIEN_CENTER_Y EQU 0

_ENEMY_ALIEN_VECTORS:  ; Main entry (header + 7 path(s))
    FDB 7               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _ENEMY_ALIEN_PATH0        ; pointer to path 0
    FDB _ENEMY_ALIEN_PATH1        ; pointer to path 1
    FDB _ENEMY_ALIEN_PATH2        ; pointer to path 2
    FDB _ENEMY_ALIEN_PATH3        ; pointer to path 3
    FDB _ENEMY_ALIEN_PATH4        ; pointer to path 4
    FDB _ENEMY_ALIEN_PATH5        ; pointer to path 5
    FDB _ENEMY_ALIEN_PATH6        ; pointer to path 6

_ENEMY_ALIEN_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $03,$FC,0,0        ; path0: header (y=3, x=-4)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB 2                ; End marker (path complete)

_ENEMY_ALIEN_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $03,$05,0,0        ; path1: header (y=3, x=5)
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB 2                ; End marker (path complete)

_ENEMY_ALIEN_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $08,$FC,0,0        ; path2: header (y=8, x=-4)
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_ENEMY_ALIEN_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $09,$05,0,0        ; path3: header (y=9, x=5)
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB 2                ; End marker (path complete)

_ENEMY_ALIEN_PATH4:    ; Path 4
    FCB 90              ; path4: intensity
    FCB $FA,$05,0,0        ; path4: header (y=-6, x=5)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ENEMY_ALIEN_PATH5:    ; Path 5
    FCB 90              ; path5: intensity
    FCB $F7,$00,0,0        ; path5: header (y=-9, x=0)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB 2                ; End marker (path complete)

_ENEMY_ALIEN_PATH6:    ; Path 6
    FCB 90              ; path6: intensity
    FCB $FA,$FC,0,0        ; path6: header (y=-6, x=-4)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)
; Generated from jetpac_logo.vec (Malban Draw_Sync_List format)
; Total paths: 10, points: 87
; X bounds: min=-94, max=96, width=190
; Center: (1, 0)

_JETPAC_LOGO_WIDTH EQU 190
_JETPAC_LOGO_HALF_WIDTH EQU 95
_JETPAC_LOGO_HEIGHT EQU 65
_JETPAC_LOGO_HALF_HEIGHT EQU 32
_JETPAC_LOGO_CENTER_X EQU 1
_JETPAC_LOGO_CENTER_Y EQU 0

_JETPAC_LOGO_VECTORS:  ; Main entry (header + 10 path(s))
    FDB 10               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _JETPAC_LOGO_PATH0        ; pointer to path 0
    FDB _JETPAC_LOGO_PATH1        ; pointer to path 1
    FDB _JETPAC_LOGO_PATH2        ; pointer to path 2
    FDB _JETPAC_LOGO_PATH3        ; pointer to path 3
    FDB _JETPAC_LOGO_PATH4        ; pointer to path 4
    FDB _JETPAC_LOGO_PATH5        ; pointer to path 5
    FDB _JETPAC_LOGO_PATH6        ; pointer to path 6
    FDB _JETPAC_LOGO_PATH7        ; pointer to path 7
    FDB _JETPAC_LOGO_PATH8        ; pointer to path 8
    FDB _JETPAC_LOGO_PATH9        ; pointer to path 9

_JETPAC_LOGO_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $00,$F2,0,0        ; path0: header (y=0, x=-14)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$EA,$00          ; flag=-1, dy=-22, dx=0
    FCB $FF,$00,$17          ; flag=-1, dy=0, dx=23
    FCB $FF,$16,$00          ; flag=-1, dy=22, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$15,$00          ; flag=-1, dy=21, dx=0
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB $FF,$EB,$00          ; flag=-1, dy=-21, dx=0
    FCB $FF,$15,$FF          ; flag=-1, dy=21, dx=-1
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB $FF,$EB,$00          ; flag=-1, dy=-21, dx=0
    FCB $FF,$00,$F9          ; flag=-1, dy=0, dx=-7
    FCB $FF,$15,$00          ; flag=-1, dy=21, dx=0
    FCB $FF,$00,$F1          ; flag=-1, dy=0, dx=-15
    FCB 2                ; End marker (path complete)

_JETPAC_LOGO_PATH1:    ; Path 1
    FCB 80              ; path1: intensity
    FCB $1B,$F9,0,0        ; path1: header (y=27, x=-7)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$06,$FF          ; flag=-1, dy=6, dx=-1
    FCB $FF,$FB,$FB          ; flag=-1, dy=-5, dx=-5
    FCB 2                ; End marker (path complete)

_JETPAC_LOGO_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $FF,$11,0,0        ; path2: header (y=-1, x=17)
    FCB $FF,$01,$16          ; flag=-1, dy=1, dx=22
    FCB $FF,$0E,$00          ; flag=-1, dy=14, dx=0
    FCB $FF,$07,$FC          ; flag=-1, dy=7, dx=-4
    FCB $FF,$00,$EE          ; flag=-1, dy=0, dx=-18
    FCB $FF,$D5,$00          ; flag=-1, dy=-43, dx=0
    FCB 2                ; End marker (path complete)

_JETPAC_LOGO_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $EA,$2F,0,0        ; path3: header (y=-22, x=47)
    FCB $FF,$2B,$00          ; flag=-1, dy=43, dx=0
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$EB,$0C          ; flag=-1, dy=-21, dx=12
    FCB $FF,$EA,$00          ; flag=-1, dy=-22, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$15,$00          ; flag=-1, dy=21, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$EB,$00          ; flag=-1, dy=-21, dx=0
    FCB 2                ; End marker (path complete)

_JETPAC_LOGO_PATH4:    ; Path 4
    FCB 100              ; path4: intensity
    FCB $DF,$5F,0,0        ; path4: header (y=-33, x=95)
    FCB $FF,$00,$A7          ; sub-seg 1/2 of line 0: dy=0, dx=-89
    FCB $FF,$00,$A7          ; sub-seg 2/2 of line 0: dy=0, dx=-89
    FCB 2                ; End marker (path complete)

_JETPAC_LOGO_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $F3,$AE,0,0        ; path5: header (y=-13, x=-82)
    FCB $FF,$F7,$08          ; flag=-1, dy=-9, dx=8
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$09,$04          ; flag=-1, dy=9, dx=4
    FCB $FF,$22,$00          ; flag=-1, dy=34, dx=0
    FCB $FF,$00,$EE          ; flag=-1, dy=0, dx=-18
    FCB 2                ; End marker (path complete)

_JETPAC_LOGO_PATH6:    ; Path 6
    FCB 80              ; path6: intensity
    FCB $1B,$A8,0,0        ; path6: header (y=27, x=-88)
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB $FF,$FF,$FB          ; flag=-1, dy=-1, dx=-5
    FCB $FF,$FB,$05          ; flag=-1, dy=-5, dx=5
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB $FF,$01,$03          ; flag=-1, dy=1, dx=3
    FCB 2                ; End marker (path complete)

_JETPAC_LOGO_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $15,$C9,0,0        ; path7: header (y=21, x=-55)
    FCB $FF,$D5,$00          ; flag=-1, dy=-43, dx=0
    FCB $FF,$00,$12          ; flag=-1, dy=0, dx=18
    FCB $FF,$10,$00          ; flag=-1, dy=16, dx=0
    FCB $FF,$00,$F3          ; flag=-1, dy=0, dx=-13
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$0D          ; flag=-1, dy=0, dx=13
    FCB $FF,$15,$00          ; flag=-1, dy=21, dx=0
    FCB $FF,$00,$EE          ; flag=-1, dy=0, dx=-18
    FCB 2                ; End marker (path complete)

_JETPAC_LOGO_PATH8:    ; Path 8
    FCB 80              ; path8: intensity
    FCB $1A,$4F,0,0        ; path8: header (y=26, x=79)
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$05,$FC          ; flag=-1, dy=5, dx=-4
    FCB $FF,$01,$04          ; flag=-1, dy=1, dx=4
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB 2                ; End marker (path complete)

_JETPAC_LOGO_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $15,$59,0,0        ; path9: header (y=21, x=89)
    FCB $FF,$00,$EE          ; flag=-1, dy=0, dx=-18
    FCB $FF,$D5,$00          ; flag=-1, dy=-43, dx=0
    FCB $FF,$00,$12          ; flag=-1, dy=0, dx=18
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$21,$00          ; flag=-1, dy=33, dx=0
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB 2                ; End marker (path complete)
; Generated from platform.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 8
; X bounds: min=-19, max=21, width=40
; Center: (1, 2)

_PLATFORM_WIDTH EQU 40
_PLATFORM_HALF_WIDTH EQU 20
_PLATFORM_HEIGHT EQU 6
_PLATFORM_HALF_HEIGHT EQU 3
_PLATFORM_CENTER_X EQU 1
_PLATFORM_CENTER_Y EQU 2

_PLATFORM_VECTORS:  ; Main entry (header + 4 path(s))
    FDB 4               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLATFORM_PATH0        ; pointer to path 0
    FDB _PLATFORM_PATH1        ; pointer to path 1
    FDB _PLATFORM_PATH2        ; pointer to path 2
    FDB _PLATFORM_PATH3        ; pointer to path 3

_PLATFORM_PATH0:    ; Path 0
    FCB 80              ; path0: intensity
    FCB $03,$F0,0,0        ; path0: header (y=3, x=-16)
    FCB $FF,$FA,$FC          ; flag=-1, dy=-6, dx=-4
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $FD,$EC,0,0        ; path1: header (y=-3, x=-20)
    FCB $FF,$00,$28          ; flag=-1, dy=0, dx=40
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH2:    ; Path 2
    FCB 80              ; path2: intensity
    FCB $FD,$14,0,0        ; path2: header (y=-3, x=20)
    FCB $FF,$06,$FD          ; flag=-1, dy=6, dx=-3
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $03,$14,0,0        ; path3: header (y=3, x=20)
    FCB $FF,$00,$D8          ; flag=-1, dy=0, dx=-40
    FCB 2                ; End marker (path complete)
; Generated from rocket_base.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 14
; X bounds: min=-13, max=14, width=27
; Center: (0, 1)

_ROCKET_BASE_WIDTH EQU 27
_ROCKET_BASE_HALF_WIDTH EQU 13
_ROCKET_BASE_HEIGHT EQU 14
_ROCKET_BASE_HALF_HEIGHT EQU 7
_ROCKET_BASE_CENTER_X EQU 0
_ROCKET_BASE_CENTER_Y EQU 1

_ROCKET_BASE_VECTORS:  ; Main entry (header + 4 path(s))
    FDB 4               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _ROCKET_BASE_PATH0        ; pointer to path 0
    FDB _ROCKET_BASE_PATH1        ; pointer to path 1
    FDB _ROCKET_BASE_PATH2        ; pointer to path 2
    FDB _ROCKET_BASE_PATH3        ; pointer to path 3

_ROCKET_BASE_PATH0:    ; Path 0
    FCB 90              ; path0: intensity
    FCB $FB,$FC,0,0        ; path0: header (y=-5, x=-4)
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB 2                ; End marker (path complete)

_ROCKET_BASE_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $FB,$09,0,0        ; path1: header (y=-5, x=9)
    FCB $FF,$0C,$00          ; flag=-1, dy=12, dx=0
    FCB $FF,$00,$EE          ; flag=-1, dy=0, dx=-18
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB $FF,$00,$12          ; flag=-1, dy=0, dx=18
    FCB 2                ; End marker (path complete)

_ROCKET_BASE_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $FB,$F7,0,0        ; path2: header (y=-5, x=-9)
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$03,$04          ; flag=-1, dy=3, dx=4
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ROCKET_BASE_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $FE,$09,0,0        ; path3: header (y=-2, x=9)
    FCB $FF,$FD,$05          ; flag=-1, dy=-3, dx=5
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB 2                ; End marker (path complete)
; Generated from rocket_middle.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 12
; X bounds: min=-9, max=12, width=21
; Center: (1, 1)

_ROCKET_MIDDLE_WIDTH EQU 21
_ROCKET_MIDDLE_HALF_WIDTH EQU 10
_ROCKET_MIDDLE_HEIGHT EQU 14
_ROCKET_MIDDLE_HALF_HEIGHT EQU 7
_ROCKET_MIDDLE_CENTER_X EQU 1
_ROCKET_MIDDLE_CENTER_Y EQU 1

_ROCKET_MIDDLE_VECTORS:  ; Main entry (header + 4 path(s))
    FDB 4               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _ROCKET_MIDDLE_PATH0        ; pointer to path 0
    FDB _ROCKET_MIDDLE_PATH1        ; pointer to path 1
    FDB _ROCKET_MIDDLE_PATH2        ; pointer to path 2
    FDB _ROCKET_MIDDLE_PATH3        ; pointer to path 3

_ROCKET_MIDDLE_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $FF,$F9,0,0        ; path0: header (y=-1, x=-7)
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB 2                ; End marker (path complete)

_ROCKET_MIDDLE_PATH1:    ; Path 1
    FCB 80              ; path1: intensity
    FCB $FE,$07,0,0        ; path1: header (y=-2, x=7)
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ROCKET_MIDDLE_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $F9,$0B,0,0        ; path2: header (y=-7, x=11)
    FCB $FF,$0E,$00          ; flag=-1, dy=14, dx=0
    FCB $FF,$00,$EB          ; flag=-1, dy=0, dx=-21
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB $FF,$00,$15          ; flag=-1, dy=0, dx=21
    FCB 2                ; End marker (path complete)

_ROCKET_MIDDLE_PATH3:    ; Path 3
    FCB 80              ; path3: intensity
    FCB $FE,$F9,0,0        ; path3: header (y=-2, x=-7)
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)
; Generated from rocket_top.vec (Malban Draw_Sync_List format)
; Total paths: 2, points: 7
; X bounds: min=-9, max=12, width=21
; Center: (1, 1)

_ROCKET_TOP_WIDTH EQU 21
_ROCKET_TOP_HALF_WIDTH EQU 10
_ROCKET_TOP_HEIGHT EQU 21
_ROCKET_TOP_HALF_HEIGHT EQU 10
_ROCKET_TOP_CENTER_X EQU 1
_ROCKET_TOP_CENTER_Y EQU 1

_ROCKET_TOP_VECTORS:  ; Main entry (header + 2 path(s))
    FDB 2               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _ROCKET_TOP_PATH0        ; pointer to path 0
    FDB _ROCKET_TOP_PATH1        ; pointer to path 1

_ROCKET_TOP_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $F6,$F6,0,0        ; path0: header (y=-10, x=-10)
    FCB $FF,$15,$09          ; flag=-1, dy=21, dx=9
    FCB $FF,$EB,$0C          ; flag=-1, dy=-21, dx=12
    FCB $FF,$00,$EB          ; flag=-1, dy=0, dx=-21
    FCB 2                ; End marker (path complete)

_ROCKET_TOP_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $F6,$0B,0,0        ; path1: header (y=-10, x=11)
    FCB $FF,$00,$EB          ; flag=-1, dy=0, dx=-21
    FCB 2                ; End marker (path complete)
; Generated from jetpac_theme.vmus (internal name: Jetpac Theme)
; Tempo: 140 BPM, Total events: 5 (PSG Direct format)
; Format: FCB count, FCB reg, val, ... (per frame), FCB 0 (end)

_JETPAC_THEME_MUSIC:
    ; Frame-based PSG register writes
    FCB     0              ; Delay 0 frames (maintain previous state)
    FCB     7              ; Frame 0 - 7 register writes
    FCB     0               ; Reg 0 number
    FCB     $B3             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0C             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1E             ; Reg 7 value
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     6              ; Frame 10 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $B3             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     11              ; Delay 11 frames (maintain previous state)
    FCB     6              ; Frame 21 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     21              ; Delay 21 frames (maintain previous state)
    FCB     6              ; Frame 42 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $78             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     22              ; Delay 22 frames (maintain previous state)
    FCB     6              ; Frame 64 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $5A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     4               ; Tail delay before force-silence (preserve last note release)
    FCB     4               ; silence event (4 regs)
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     17              ; Delay 17 frames before loop
    FCB     $FF             ; Loop command ($FF never valid as count)
    FDB     _JETPAC_THEME_MUSIC       ; Jump to start (absolute address)

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

; === JOYSTICK BUILTIN SUBROUTINES (cached, Joy_Analog runs once per frame) ===
; J1_X() - Read Joystick 1 X axis from cached BIOS value at $C81B
J1X_BUILTIN:
    LDB >$C81B   ; Vec_Joy_1_X (populated each frame by auto-injected Joy_Analog)
    SEX          ; Sign-extend B to D
    ADDD #2      ; Calibrate center offset
    RTS

; J1_Y() - Read Joystick 1 Y axis from cached BIOS value at $C81C
J1Y_BUILTIN:
    LDB >$C81C   ; Vec_Joy_1_Y
    SEX
    ADDD #2
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

; ============================================================================
; PSG DIRECT MUSIC PLAYER (inspired by Christman2024/malbanGit)
; ============================================================================
; Writes directly to PSG chip using WRITE_PSG sequence
;
; Music data format (frame-based):
;   FCB count           ; Number of register writes this frame
;   FCB reg, val        ; PSG register/value pairs
;   ...                 ; Repeat for each register
;   FCB $FF             ; End marker
;
; PSG Registers:
;   0-1: Channel A frequency (12-bit)
;   2-3: Channel B frequency
;   4-5: Channel C frequency
;   6:   Noise period
;   7:   Mixer control (enable/disable channels)
;   8-10: Channel A/B/C volume
;   11-12: Envelope period
;   13:  Envelope shape
; ============================================================================

; RAM variables (defined in SYSTEM RAM VARIABLES section):
; PSG_MUSIC_PTR, PSG_MUSIC_START, PSG_IS_PLAYING,
; PSG_MUSIC_ACTIVE, PSG_DELAY_FRAMES

; PLAY_MUSIC_RUNTIME - Start PSG music playback
; Input: X = pointer to PSG music data
PLAY_MUSIC_RUNTIME:
CMPX >PSG_MUSIC_START   ; Check if already playing this music
BNE PMr_start_new       ; If different, start fresh
LDA >PSG_IS_PLAYING     ; Check if currently playing
BNE PMr_done            ; If playing same song, ignore
PMr_start_new:
; Silence PSG before switching tracks (prevents noise bleed-through)
PSHS X,DP               ; Save music pointer and DP
LDA #$D0
TFR A,DP                ; Set DP=$D0 for Sound_Byte
LDA #7                  ; PSG reg 7 = Mixer
LDB #$3F                ; All channels disabled (bits 0-5 only; bits 6-7=0=IOA/IOB input!)
JSR Sound_Byte
LDA #8                  ; PSG reg 8 = Volume channel A
LDB #0
JSR Sound_Byte
LDA #9                  ; PSG reg 9 = Volume channel B
LDB #0
JSR Sound_Byte
LDA #10                 ; PSG reg 10 = Volume channel C
LDB #0
JSR Sound_Byte
PULS X,DP               ; Restore music pointer and DP
STX >PSG_MUSIC_PTR      ; Store current music pointer (force extended)
STX >PSG_MUSIC_START    ; Store start pointer for loops (force extended)
CLR >PSG_DELAY_FRAMES   ; Clear delay counter
LDA #$01
STA >PSG_IS_PLAYING     ; Mark as playing (extended - var at 0xC8A0)
PMr_done:
RTS

; ============================================================================
; UPDATE_MUSIC_PSG - Update PSG (call every frame)
; Data format per event: FCB delay, FCB count, (FCB reg, FCB val)*N
; delay = frames since previous event (0 = apply immediately)
; End marker: FCB 0 after last event's count
; Loop marker: delay=$FF is treated as loop; OR count=$FF followed by FDB addr
; PSG_DELAY_FRAMES counts down to the next event fire point.
; PSG_MUSIC_PTR always points to delay byte of next pending event.
; ============================================================================
UPDATE_MUSIC_PSG:
LDA #$01
STA >PSG_MUSIC_ACTIVE   ; Mark music system active
LDA >PSG_IS_PLAYING
LBEQ PSG_update_done    ; Not playing

; Check if delay counter is running
LDA >PSG_DELAY_FRAMES
BEQ PSG_read_delay      ; Counter=0: time to read next delay byte
DECA
STA >PSG_DELAY_FRAMES
LBNE PSG_update_done    ; Still waiting
BRA PSG_process_event   ; Counter just hit 0: apply the event

PSG_read_delay:
LDX >PSG_MUSIC_PTR      ; PTR → delay byte of current event
LDB ,X+                 ; Consume delay byte, X → count byte
CMPB #$FF
LBEQ PSG_music_loop_d   ; $FF as delay = loop command
STB >PSG_DELAY_FRAMES   ; Store delay count
STX >PSG_MUSIC_PTR      ; Advance PTR past delay byte (now at count byte)
BEQ PSG_process_event   ; delay=0: apply immediately
DEC >PSG_DELAY_FRAMES   ; Decrement once (fires after delay-1 more frames)
LBRA PSG_update_done    ; Wait

PSG_process_event:
LDX >PSG_MUSIC_PTR      ; PTR is at count byte
LDB ,X+
LBEQ PSG_music_ended    ; Count=0 means end
CMPB #$FF
LBEQ PSG_music_loop     ; Count=$FF means loop

PSHS B                  ; Save count on stack
PSG_write_loop:
LDA ,X+                 ; Load register number
LDB ,X+                 ; Load register value
PSHS X                  ; Save pointer

; WRITE_PSG sequence (direct VIA access)
STA VIA_port_a          ; Store register number
LDA #$19                ; BDIR=1, BC1=1 (LATCH)
STA VIA_port_b
LDA #$01                ; BDIR=0, BC1=0 (INACTIVE)
STA VIA_port_b
LDA VIA_port_a          ; Read status
STB VIA_port_a          ; Store data
LDB #$11                ; BDIR=1, BC1=0 (WRITE)
STB VIA_port_b
LDB #$01                ; BDIR=0, BC1=0 (INACTIVE)
STB VIA_port_b

PULS X                  ; Restore pointer
PULS B                  ; Get counter
DECB
BEQ PSG_event_done      ; Done with this event
PSHS B                  ; Save counter back
BRA PSG_write_loop

PSG_event_done:
STX >PSG_MUSIC_PTR      ; PTR → delay byte of next event
CLR >PSG_DELAY_FRAMES   ; Trigger PSG_read_delay next frame
LBRA PSG_update_done

PSG_music_ended:
CLR >PSG_IS_PLAYING
; Silence all 3 PSG channels so the last note doesn't keep ringing
; until the next PLAY_MUSIC. DP is already $D0 (set by AUDIO_UPDATE).
LDA #8                  ; PSG reg 8 = Volume Channel A
LDB #0
JSR Sound_Byte
LDA #9                  ; PSG reg 9 = Volume Channel B
LDB #0
JSR Sound_Byte
LDA #10                 ; PSG reg 10 = Volume Channel C
LDB #0
JSR Sound_Byte
LBRA PSG_update_done

PSG_music_loop:
; count=$FF: X points after $FF, at FDB loop address
LDD ,X
STD >PSG_MUSIC_PTR
CLR >PSG_DELAY_FRAMES
LBRA PSG_update_done

PSG_music_loop_d:
; delay=$FF: X points after $FF, at FDB loop address
LDD ,X
STD >PSG_MUSIC_PTR
CLR >PSG_DELAY_FRAMES

PSG_update_done:
CLR >PSG_MUSIC_ACTIVE   ; Clear flag (music system done)
RTS

; ============================================================================
; STOP_MUSIC_RUNTIME - Stop music playback
; ============================================================================
STOP_MUSIC_RUNTIME:
CLR >PSG_IS_PLAYING     ; Clear playing flag
CLR >PSG_MUSIC_PTR      ; Clear pointer high byte
CLR >PSG_MUSIC_PTR+1    ; Clear pointer low byte
; Mute all PSG channels so the last note doesn't keep sounding
PSHS DP
LDA #$D0
TFR A,DP                ; Set DP=$D0 for Sound_Byte
LDA #8                  ; PSG reg 8 = Volume Channel A
LDB #0
JSR Sound_Byte
LDA #9                  ; PSG reg 9 = Volume Channel B
LDB #0
JSR Sound_Byte
LDA #10                 ; PSG reg 10 = Volume Channel C
LDB #0
JSR Sound_Byte
PULS DP
RTS

; ============================================================================
; AUDIO_UPDATE - Unified music + SFX update (auto-injected after WAIT_RECAL)
; ============================================================================
; Uses Sound_Byte (BIOS) for PSG writes - compatible with both systems
; Sets DP=$D0 once at entry, restores at exit

AUDIO_UPDATE:
PSHS DP                 ; Save current DP
LDA #$D0                ; Set DP=$D0 (Sound_Byte requirement)
TFR A,DP

        ; UPDATE MUSIC
LDA >PSG_IS_PLAYING     ; Check if music is playing
BEQ AU_SKIP_MUSIC       ; Skip if not

; Check delay counter first
LDA >PSG_DELAY_FRAMES   ; Load delay counter
BEQ AU_MUSIC_READ       ; If zero, read next frame data
DECA                    ; Decrement delay
STA >PSG_DELAY_FRAMES   ; Store back
CMPA #0                 ; Check if it just reached zero
BNE AU_UPDATE_SFX       ; If not zero yet, skip this frame

; Delay just reached zero, X points to count byte already
LDX >PSG_MUSIC_PTR      ; Load music pointer (points to count)
BRA AU_MUSIC_READ_COUNT ; Skip delay read, go straight to count

AU_MUSIC_READ:
LDX >PSG_MUSIC_PTR      ; Load music pointer

; Check if we need to read delay or we're ready for count
; PSG_DELAY_FRAMES just reached 0, so we read delay byte first
LDB ,X+                 ; Read delay counter (X now points to count byte)
CMPB #$FF               ; Check for loop marker
BEQ AU_MUSIC_LOOP       ; Handle loop
CMPB #0                 ; Check if delay is 0
BNE AU_MUSIC_HAS_DELAY  ; If not 0, process delay

; Delay is 0, read count immediately
AU_MUSIC_NO_DELAY:
AU_MUSIC_READ_COUNT:
LDB ,X+                 ; Read count (number of register writes)
BEQ AU_MUSIC_ENDED      ; If 0, end of music
CMPB #$FF               ; Check for loop marker (can appear after delay)
BEQ AU_MUSIC_LOOP       ; Handle loop
BRA AU_MUSIC_PROCESS_WRITES

AU_MUSIC_HAS_DELAY:
; B has delay > 0, store it and skip to next frame
DECB                    ; Delay-1 (we consume this frame)
BEQ AU_MUSIC_READ_COUNT ; delay was 1: X already at count byte, process immediately
STB >PSG_DELAY_FRAMES   ; Save delay counter
STX >PSG_MUSIC_PTR      ; Save pointer (X points to count byte)
BRA AU_UPDATE_SFX       ; Skip reading data this frame

AU_MUSIC_PROCESS_WRITES:
; Per-event write loop. Inlined PSG protocol instead of JSR Sound_Byte
; (~35 cycles vs ~92 incl JSR/RTS overhead — saves ~57 cycles per
; register write). For theme-style music with 8-10 writes per event,
; saves ~500-600 cycles per event frame → frees enough budget that the
; music event no longer pushes the frame over vsync. Mirrors the BIOS
; Sound_Byte protocol exactly (Vectrex VIA bits: BC1=bit3, BDIR=bit4).
PSHS B                  ; save register-write count on stack for in-place DEC
AU_MUSIC_WRITE_LOOP:
LDA ,X+                 ; A = register number
LDB ,X+                 ; B = register value
STA VIA_port_a          ; data bus = reg num
LDA #$19                ; BC1=1, BDIR=1 → LATCH ADDR
STA VIA_port_b
LDA #$01                ; back to INACTIVE (BC1=0, BDIR=0)
STA VIA_port_b
LDA VIA_port_a          ; READ STATUS — settling delay so PSG finishes
; latching the register address before we drive
; the value. Without this, the PSG occasionally
; writes the new value into the PREVIOUS register
; (audible as glitchy pitch / 'noisy' music,
; especially when other CPU activity perturbs
; the timing between this loop and adjacent code).
STB VIA_port_a          ; data bus = value
LDA #$11                ; BC1=0, BDIR=1 → WRITE DATA
STA VIA_port_b
LDA #$01                ; back to INACTIVE
STA VIA_port_b
DEC ,S                  ; decrement count on stack (in-place; no PSHS/PULS per iter)
BNE AU_MUSIC_WRITE_LOOP
LEAS 1,S                ; discard saved count

AU_MUSIC_DONE:
STX >PSG_MUSIC_PTR      ; Update music pointer
BRA AU_UPDATE_SFX       ; Now update SFX

AU_MUSIC_ENDED:
CLR >PSG_IS_PLAYING     ; Stop music
BRA AU_UPDATE_SFX       ; Continue to SFX

AU_MUSIC_LOOP:
LDD ,X                  ; Load loop target
STD >PSG_MUSIC_PTR      ; Set music pointer to loop
CLR >PSG_DELAY_FRAMES   ; Clear delay on loop
BRA AU_UPDATE_SFX       ; Continue to SFX

AU_SKIP_MUSIC:
BRA AU_UPDATE_SFX       ; Skip music, go to SFX

; UPDATE SFX (channel C: registers 4/5=tone, 6=noise, 10=volume, 7=mixer)
AU_UPDATE_SFX:
LDA >SFX_ACTIVE         ; Check if SFX is active
BEQ AU_DONE             ; Skip if not active

        JSR sfx_doframe         ; Process one SFX frame (uses Sound_Byte internally)

AU_DONE:
        PULS DP                 ; Restore original DP
RTS

; ============================================================================
; AYFX SOUND EFFECTS PLAYER (Richard Chadd original system)
; ============================================================================
; Uses channel C (registers 4/5=tone, 6=noise, 10=volume, 7=mixer bit2/bit5)
; RAM variables: SFX_PTR (16-bit), SFX_ACTIVE (8-bit)
; AYFX format: flag byte + optional data per frame, end marker $D0 $20
; Flag bits: 0-3=volume, 4=disable tone, 5=tone data present,
;            6=noise data present, 7=disable noise
; ============================================================================

; PLAY_SFX_RUNTIME - Start SFX playback
; Input: X = pointer to AYFX data
PLAY_SFX_RUNTIME:
STX >SFX_PTR           ; Store pointer (force extended addressing)
LDA #$01
STA >SFX_ACTIVE        ; Mark as active
RTS

; SFX_UPDATE - Process one AYFX frame (call once per frame in loop)
SFX_UPDATE:
LDA >SFX_ACTIVE        ; Check if active
BEQ noay               ; Not active, skip
JSR sfx_doframe        ; Process one frame
noay:
RTS

; sfx_doframe - AYFX frame parser (Richard Chadd original)
sfx_doframe:
LDU >SFX_PTR           ; Get current frame pointer
LDB ,U                 ; Read flag byte (NO auto-increment)
CMPB #$D0              ; Check end marker (first byte)
BNE sfx_checktonefreq  ; Not end, continue
LDB 1,U                ; Check second byte at offset 1
CMPB #$20              ; End marker $D0 $20?
BEQ sfx_endofeffect    ; Yes, stop

sfx_checktonefreq:
LEAY 1,U               ; Y = pointer to tone/noise data
LDB ,U                 ; Reload flag byte (Sound_Byte corrupts B)
BITB #$20              ; Bit 5: tone data present?
BEQ sfx_checknoisefreq ; No, skip tone
; Set tone frequency (channel C = reg 4/5)
LDB 2,U                ; Get LOW byte (fine tune)
LDA #$04               ; Register 4
JSR Sound_Byte         ; Write to PSG
LDB 1,U                ; Get HIGH byte (coarse tune)
LDA #$05               ; Register 5
JSR Sound_Byte         ; Write to PSG
LEAY 2,Y               ; Skip 2 tone bytes

sfx_checknoisefreq:
LDB ,U                 ; Reload flag byte
BITB #$40              ; Bit 6: noise data present?
BEQ sfx_checkvolume    ; No, skip noise
LDB ,Y                 ; Get noise period
LDA #$06               ; Register 6
JSR Sound_Byte         ; Write to PSG
LEAY 1,Y               ; Skip 1 noise byte

sfx_checkvolume:
LDB ,U                 ; Reload flag byte
ANDB #$0F              ; Get volume from bits 0-3
LDA #$0A               ; Register 10 (volume C)
JSR Sound_Byte         ; Write to PSG

; Combined mixer update: read shadow once, apply tone+noise, write once
sfx_updatemixer:
LDB $C807              ; Read mixer shadow ONCE
LDA ,U                 ; Load flag byte into A
; Handle tone (flag bit 4 → mixer bit 2)
BITA #$10              ; Bit 4: disable tone?
BNE sfx_m_tonedis
ANDB #$FB              ; Clear bit 2 (enable tone C)
BRA sfx_m_noise
sfx_m_tonedis:
ORB #$04               ; Set bit 2 (disable tone C)
sfx_m_noise:
; Handle noise (flag bit 7 → mixer bit 5)
BITA #$80              ; Bit 7: disable noise?
BNE sfx_m_noisedis
ANDB #$DF              ; Clear bit 5 (enable noise C)
BRA sfx_m_write
sfx_m_noisedis:
ORB #$20               ; Set bit 5 (disable noise C)
sfx_m_write:
STB $C807              ; Update mixer shadow
LDA #$07               ; Register 7 (mixer)
JSR Sound_Byte         ; Single write to PSG

sfx_nextframe:
STY >SFX_PTR            ; Update pointer for next frame
RTS

sfx_endofeffect:
; Stop SFX - silence channel C and restore mixer
CLR >SFX_ACTIVE         ; Mark as inactive
LDA #$0A                ; Register 10 (volume C)
LDB #$00                ; Volume = 0
JSR Sound_Byte
; Restore mixer: disable tone+noise on channel C
LDB $C807              ; Read mixer shadow
ORB #$24               ; Set bits 2+5 (disable tone C + noise C)
STB $C807              ; Update shadow
LDA #$07               ; Register 7
JSR Sound_Byte         ; Write mixer
LDD #$0000
STD >SFX_PTR            ; Clear pointer
RTS

;**** PRINT_TEXT String Data ****
PRINT_TEXT_STR_3180150483059:
    FCC "platform"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3111609544781162:
    FCC "rocket_top"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_85780066493072208:
    FCC "enemy_alien"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_89653106044521169:
    FCC "jetpac_logo"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_96459895887666524:
    FCC "rocket_base"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_464239579821635936:
    FCC "rocket_middle"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2779246287387333987:
    FCC "jetpac_theme"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_11758730126132164237:
    FCC "astronaut_armed"
    FCB $80          ; Vectrex string terminator

