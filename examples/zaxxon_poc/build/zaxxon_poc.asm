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
    FCC "ZAXXON POC"
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
NUM_STR              EQU $C880+$0E   ; Buffer for PRINT_NUMBER decimal output (5 digits + terminator) (6 bytes)
DRAW_VEC_INTENSITY   EQU $C880+$14   ; Vector intensity override (0=use vector data) (1 bytes)
DRAW_VEC_X_HI        EQU $C880+$15   ; Vector draw X high byte (16-bit screen_x) (1 bytes)
DRAW_VEC_X           EQU $C880+$16   ; Vector draw X offset (1 bytes)
DRAW_VEC_Y           EQU $C880+$17   ; Vector draw Y offset (1 bytes)
MIRROR_PAD           EQU $C880+$18   ; Safety padding to prevent MIRROR flag corruption (16 bytes)
MIRROR_X             EQU $C880+$28   ; X mirror flag (0=normal, 1=flip) (1 bytes)
MIRROR_Y             EQU $C880+$29   ; Y mirror flag (0=normal, 1=flip) (1 bytes)
SLR_CUR_X            EQU $C880+$2A   ; DRAW_VECTOR: clamped (visible) beam X for clipping (1 bytes)
SLR_TRUE_X           EQU $C880+$2B   ; DRAW_VECTOR: 16-bit unclamped abs_x for line clipping (2 bytes)
DRAW_T1_SCALED       EQU $C880+$2D   ; DRAW_VECTOR: T1 scale ($7F default for non-SHOW_LEVEL) (1 bytes)
SDCP_ABS_Y           EQU $C880+$2E   ; DRAW_VECTOR: abs_y temporary for SDCP (cannot share TMPVAL — would corrupt SHOW_LEVEL's top_screen between layers) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$2F   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$39   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$3B   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$3D   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$3E   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$3F   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$41   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$43   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$44   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
PN_LAST_VAL          EQU $C880+$45   ; PRINT_NUMBER: last rendered numeric value (cache key) (2 bytes)
PN_LAST_VALID        EQU $C880+$47   ; PRINT_NUMBER: 1 if PN_LAST_VAL holds a valid render (1 bytes)
PN_LAST_X            EQU $C880+$48   ; PRINT_NUMBER: last rendered X (cache key) (1 bytes)
PN_LAST_Y            EQU $C880+$49   ; PRINT_NUMBER: last rendered Y (cache key) (1 bytes)
DRAW_SCALE           EQU $C880+$4A   ; Current T1 scale for Draw_Sync_List_At_With_Mirrors ($7F=normal) (1 bytes)
VAR_ARG0             EQU $C880+$4B   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $C880+$4D   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $C880+$4F   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $C880+$51   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $C880+$53   ; Function argument 4 (16-bit) (2 bytes)
VAR_ARG5             EQU $C880+$55   ; Function argument 5 (16-bit) (2 bytes)
VAR_ARG6             EQU $C880+$57   ; Function argument 6 (16-bit) (2 bytes)
VAR_ARG7             EQU $C880+$59   ; Function argument 7 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $C880+$5B   ; Current ROM bank ID (multibank tracking) (1 bytes)
VAR_BLD_X            EQU $C880+$5C   ; User variable: BLD_X (2 bytes)
VAR_BLD_Z            EQU $C880+$5E   ; User variable: BLD_Z (2 bytes)
VAR_BLD_W            EQU $C880+$60   ; User variable: BLD_W (2 bytes)
VAR_BLD_H            EQU $C880+$62   ; User variable: BLD_H (2 bytes)
VAR_PLAYER_X         EQU $C880+$64   ; User variable: PLAYER_X (2 bytes)
VAR_PLAYER_Y         EQU $C880+$66   ; User variable: PLAYER_Y (2 bytes)
VAR_CAM_Z            EQU $C880+$68   ; User variable: CAM_Z (2 bytes)
VAR_SCROLL_TICK      EQU $C880+$6A   ; User variable: SCROLL_TICK (1 bytes)
VAR_SCORE            EQU $C880+$6B   ; User variable: SCORE (2 bytes)
VAR_B0ALIVE          EQU $C880+$6D   ; User variable: B0ALIVE (1 bytes)
VAR_B1ALIVE          EQU $C880+$6E   ; User variable: B1ALIVE (1 bytes)
VAR_B2ALIVE          EQU $C880+$6F   ; User variable: B2ALIVE (1 bytes)
VAR_B3ALIVE          EQU $C880+$70   ; User variable: B3ALIVE (1 bytes)
VAR_B4ALIVE          EQU $C880+$71   ; User variable: B4ALIVE (1 bytes)
VAR_B5ALIVE          EQU $C880+$72   ; User variable: B5ALIVE (1 bytes)
VAR_BULLET_ALIVE     EQU $C880+$73   ; User variable: BULLET_ALIVE (1 bytes)
VAR_BULLET_ABS_Z     EQU $C880+$74   ; User variable: BULLET_ABS_Z (2 bytes)
VAR_BULLET_RX        EQU $C880+$76   ; User variable: BULLET_RX (2 bytes)
VAR_BULLET_RY        EQU $C880+$78   ; User variable: BULLET_RY (2 bytes)
VAR_BTN_PREV         EQU $C880+$7A   ; User variable: BTN_PREV (1 bytes)
VAR_EXPL_FRAMES      EQU $C880+$7B   ; User variable: EXPL_FRAMES (1 bytes)
VAR_EXPL_SX          EQU $C880+$7C   ; User variable: EXPL_SX (2 bytes)
VAR_EXPL_SY          EQU $C880+$7E   ; User variable: EXPL_SY (2 bytes)
VAR_P_RX             EQU $C880+$80   ; User variable: P_RX (2 bytes)
VAR_P_WY             EQU $C880+$82   ; User variable: P_WY (2 bytes)
VAR_P_RZ             EQU $C880+$84   ; User variable: P_RZ (2 bytes)
VAR_P_SX             EQU $C880+$86   ; User variable: P_SX (2 bytes)
VAR_P_SY             EQU $C880+$88   ; User variable: P_SY (2 bytes)
VAR_C0X              EQU $C880+$8A   ; User variable: C0X (2 bytes)
VAR_C0Y              EQU $C880+$8C   ; User variable: C0Y (2 bytes)
VAR_C1X              EQU $C880+$8E   ; User variable: C1X (2 bytes)
VAR_C1Y              EQU $C880+$90   ; User variable: C1Y (2 bytes)
VAR_C2X              EQU $C880+$92   ; User variable: C2X (2 bytes)
VAR_C2Y              EQU $C880+$94   ; User variable: C2Y (2 bytes)
VAR_C3X              EQU $C880+$96   ; User variable: C3X (2 bytes)
VAR_C3Y              EQU $C880+$98   ; User variable: C3Y (2 bytes)
VAR_C4X              EQU $C880+$9A   ; User variable: C4X (2 bytes)
VAR_C4Y              EQU $C880+$9C   ; User variable: C4Y (2 bytes)
VAR_C5X              EQU $C880+$9E   ; User variable: C5X (2 bytes)
VAR_C5Y              EQU $C880+$A0   ; User variable: C5Y (2 bytes)
VAR_BI               EQU $C880+$A2   ; User variable: BI (2 bytes)
VAR_BX               EQU $C880+$A4   ; User variable: BX (2 bytes)
VAR_BZ               EQU $C880+$A6   ; User variable: BZ (2 bytes)
VAR_BW               EQU $C880+$A8   ; User variable: BW (2 bytes)
VAR_BH               EQU $C880+$AA   ; User variable: BH (2 bytes)
VAR_RZ               EQU $C880+$AC   ; User variable: RZ (2 bytes)
VAR_ALIVE            EQU $C880+$AE   ; User variable: ALIVE (1 bytes)
VAR_HIT_BI           EQU $C880+$AF   ; User variable: HIT_BI (2 bytes)
VAR_BULLET_RZ        EQU $C880+$B1   ; User variable: BULLET_RZ (2 bytes)
VAR_BZ_CHECK         EQU $C880+$B3   ; User variable: BZ_CHECK (2 bytes)
VAR_BX_CHECK         EQU $C880+$B5   ; User variable: BX_CHECK (2 bytes)
VAR_BW_CHECK         EQU $C880+$B7   ; User variable: BW_CHECK (2 bytes)
VAR_BH_CHECK         EQU $C880+$B9   ; User variable: BH_CHECK (2 bytes)
VAR_PLAYER_SY        EQU $C880+$BB   ; User variable: PLAYER_SY (2 bytes)
VAR_ALT_BAR          EQU $C880+$BD   ; User variable: ALT_BAR (2 bytes)
VAR_GI               EQU $C880+$BF   ; User variable: GI (2 bytes)
VAR_GRZ              EQU $C880+$C1   ; User variable: GRZ (2 bytes)
VAR_GSX_L            EQU $C880+$C3   ; User variable: GSX_L (2 bytes)
VAR_GSY_L            EQU $C880+$C5   ; User variable: GSY_L (2 bytes)
VAR_GSX_R            EQU $C880+$C7   ; User variable: GSX_R (2 bytes)
VAR_GSY_R            EQU $C880+$C9   ; User variable: GSY_R (2 bytes)
VAR_JOY_X            EQU $C880+$CB   ; User variable: JOY_X (2 bytes)
VAR_JOY_Y            EQU $C880+$CD   ; User variable: JOY_Y (2 bytes)
VAR_BTN1             EQU $C880+$CF   ; User variable: BTN1 (2 bytes)
PSG_MUSIC_PTR        EQU $C880+$D1   ; PSG music data pointer (2 bytes)
PSG_MUSIC_START      EQU $C880+$D3   ; PSG music start pointer (for loops) (2 bytes)
PSG_MUSIC_ACTIVE     EQU $C880+$D5   ; PSG music active flag (1 bytes)
PSG_IS_PLAYING       EQU $C880+$D6   ; PSG playing flag (1 bytes)
PSG_DELAY_FRAMES     EQU $C880+$D7   ; PSG frame delay counter (1 bytes)
PSG_MUSIC_BANK       EQU $C880+$D8   ; PSG music bank ID (for multibank) (1 bytes)
SFX_PTR              EQU $C880+$D9   ; SFX data pointer (2 bytes)
SFX_ACTIVE           EQU $C880+$DB   ; SFX active flag (1 bytes)
SFX_BANK             EQU $C880+$DC   ; SFX bank ID (for multibank) (1 bytes)
; Array length constants
ARRAY_BLD_X_LEN         EQU 6   ; 6 elements
ARRAY_BLD_Z_LEN         EQU 6   ; 6 elements
ARRAY_BLD_W_LEN         EQU 6   ; 6 elements
ARRAY_BLD_H_LEN         EQU 6   ; 6 elements

;***************************************************************************
; ARRAY DATA (ROM literals)
;***************************************************************************
; Arrays are stored in ROM and accessed via pointers
; At startup, main() initializes VAR_{name} to point to ARRAY_{name}_DATA

; Array literal for variable 'BLD_X' (6 elements, 2 bytes each)
ARRAY_BLD_X_DATA:
    FDB 8   ; Element 0
    FDB -22   ; Element 1
    FDB 18   ; Element 2
    FDB -10   ; Element 3
    FDB 26   ; Element 4
    FDB -6   ; Element 5

; Array literal for variable 'BLD_Z' (6 elements, 2 bytes each)
ARRAY_BLD_Z_DATA:
    FDB 60   ; Element 0
    FDB 100   ; Element 1
    FDB 140   ; Element 2
    FDB 185   ; Element 3
    FDB 225   ; Element 4
    FDB 270   ; Element 5

; Array literal for variable 'BLD_W' (6 elements, 2 bytes each)
ARRAY_BLD_W_DATA:
    FDB 14   ; Element 0
    FDB 20   ; Element 1
    FDB 10   ; Element 2
    FDB 24   ; Element 3
    FDB 12   ; Element 4
    FDB 18   ; Element 5

; Array literal for variable 'BLD_H' (6 elements, 2 bytes each)
ARRAY_BLD_H_DATA:
    FDB 14   ; Element 0
    FDB 24   ; Element 1
    FDB 18   ; Element 2
    FDB 14   ; Element 3
    FDB 26   ; Element 4
    FDB 18   ; Element 5


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
    LDA #$7F
    STA DRAW_SCALE        ; Default T1 scale = $7F (127 = full BIOS scale)
    LDD #0
    STD VAR_PLAYER_X
    LDD #8
    STD VAR_PLAYER_Y
    LDD #0
    STD VAR_CAM_Z
    LDD #0
    STD VAR_SCROLL_TICK
    LDD #0
    STD VAR_SCORE
    LDD #1
    STD VAR_B0ALIVE
    LDD #1
    STD VAR_B1ALIVE
    LDD #1
    STD VAR_B2ALIVE
    LDD #1
    STD VAR_B3ALIVE
    LDD #1
    STD VAR_B4ALIVE
    LDD #1
    STD VAR_B5ALIVE
    LDD #0
    STD VAR_BULLET_ALIVE
    LDD #0
    STD VAR_BULLET_ABS_Z
    LDD #0
    STD VAR_BULLET_RX
    LDD #0
    STD VAR_BULLET_RY
    LDD #0
    STD VAR_BTN_PREV
    LDD #0
    STD VAR_EXPL_FRAMES
    LDD #0
    STD VAR_EXPL_SX
    LDD #0
    STD VAR_EXPL_SY
    LDD #0
    STD VAR_P_RX
    LDD #0
    STD VAR_P_WY
    LDD #0
    STD VAR_P_RZ
    LDD #0
    STD VAR_P_SX
    LDD #0
    STD VAR_P_SY
    LDD #0
    STD VAR_C0X
    LDD #0
    STD VAR_C0Y
    LDD #0
    STD VAR_C1X
    LDD #0
    STD VAR_C1Y
    LDD #0
    STD VAR_C2X
    LDD #0
    STD VAR_C2Y
    LDD #0
    STD VAR_C3X
    LDD #0
    STD VAR_C3Y
    LDD #0
    STD VAR_C4X
    LDD #0
    STD VAR_C4Y
    LDD #0
    STD VAR_C5X
    LDD #0
    STD VAR_C5Y
    LDD #0
    STD VAR_BI
    LDD #0
    STD VAR_BX
    LDD #0
    STD VAR_BZ
    LDD #0
    STD VAR_BW
    LDD #0
    STD VAR_BH
    LDD #0
    STD VAR_RZ
    LDD #0
    STD VAR_ALIVE
    LDD #-1
    STD VAR_HIT_BI
    LDD #0
    STD VAR_BULLET_RZ
    LDD #0
    STD VAR_BZ_CHECK
    LDD #0
    STD VAR_BX_CHECK
    LDD #0
    STD VAR_BW_CHECK
    LDD #0
    STD VAR_BH_CHECK
    LDD #-40
    STD VAR_PLAYER_SY
    LDD #0
    STD VAR_ALT_BAR
    LDD #0
    STD VAR_GI
    LDD #0
    STD VAR_GRZ
    LDD #0
    STD VAR_GSX_L
    LDD #0
    STD VAR_GSY_L
    LDD #0
    STD VAR_GSX_R
    LDD #0
    STD VAR_GSY_R
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
; VPy_LINE:159
    ; TODO: Statement Pass { source_line: 159 }
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
; VPy_LINE:162
; NATIVE_CALL: J1_X at line 162
    JSR J1X_BUILTIN
    STD RESULT
    STD VAR_JOY_X
; VPy_LINE:163
; NATIVE_CALL: J1_Y at line 163
    JSR J1Y_BUILTIN
    STD RESULT
    STD VAR_JOY_Y
; VPy_LINE:164
; NATIVE_CALL: J1_BUTTON_1 at line 164
    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed
    BITA #$01
    BNE .J1B1_0_ON
    LDD #0
    BRA .J1B1_0_END
.J1B1_0_ON:
    LDD #1
.J1B1_0_END:
    STD RESULT
    STD VAR_BTN1
; VPy_LINE:167
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDB >VAR_SCROLL_TICK
    CLRA            ; Zero-extend: A=0, B=value
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STB VAR_SCROLL_TICK
; VPy_LINE:168
    LDD #2
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_SCROLL_TICK
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBGE .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_1
; VPy_LINE:169
    LDD #0
    STB VAR_SCROLL_TICK
; VPy_LINE:170
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_CAM_Z
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_CAM_Z
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
; VPy_LINE:171
    LDD #320  ; const LEVEL_LEN
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CAM_Z
    CMPD TMPVAL
    LBGE .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    LBEQ IF_NEXT_3
; VPy_LINE:172
    LDD #0
    STD VAR_CAM_Z
; VPy_LINE:173
    LDD #1
    STB VAR_B0ALIVE
; VPy_LINE:174
    LDD #1
    STB VAR_B1ALIVE
; VPy_LINE:175
    LDD #1
    STB VAR_B2ALIVE
; VPy_LINE:176
    LDD #1
    STB VAR_B3ALIVE
; VPy_LINE:177
    LDD #1
    STB VAR_B4ALIVE
; VPy_LINE:178
    LDD #1
    STB VAR_B5ALIVE
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
; VPy_LINE:181
    LDD #20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBGT .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    LBEQ IF_NEXT_5
; VPy_LINE:182
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_PLAYER_X
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
; VPy_LINE:183
    LDD #-20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBLT .CMP_3_TRUE
    LDD #0
    LBRA .CMP_3_END
.CMP_3_TRUE:
    LDD #1
.CMP_3_END:
    LBEQ IF_NEXT_7
; VPy_LINE:184
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_PLAYER_X
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
; VPy_LINE:185
    LDD #20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_Y
    CMPD TMPVAL
    LBGT .CMP_4_TRUE
    LDD #0
    LBRA .CMP_4_END
.CMP_4_TRUE:
    LDD #1
.CMP_4_END:
    LBEQ IF_NEXT_9
; VPy_LINE:186
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_PLAYER_Y
    LBRA IF_END_8
IF_NEXT_9:
IF_END_8:
; VPy_LINE:187
    LDD #-20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_Y
    CMPD TMPVAL
    LBLT .CMP_5_TRUE
    LDD #0
    LBRA .CMP_5_END
.CMP_5_TRUE:
    LDD #1
.CMP_5_END:
    LBEQ IF_NEXT_11
; VPy_LINE:188
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_PLAYER_Y
    LBRA IF_END_10
IF_NEXT_11:
IF_END_10:
; VPy_LINE:189
    ; CLAMP: Clamp value to range [min, max]
    LDD >VAR_PLAYER_X
    STD TMPPTR     ; Save value
    LDD #-30
    STD TMPPTR+2   ; Save min
    LDD #30
    STD TMPPTR+4   ; Save max
    LDD TMPPTR     ; Load value
    CMPD TMPPTR+2  ; Compare with min
    BGE .CLAMP_0_CHK_MAX ; Branch if value >= min
    LDD TMPPTR+2
    STD RESULT
    BRA .CLAMP_0_END
.CLAMP_0_CHK_MAX:
    LDD TMPPTR     ; Load value again
    CMPD TMPPTR+4  ; Compare with max
    BLE .CLAMP_0_OK  ; Branch if value <= max
    LDD TMPPTR+4
    STD RESULT
    BRA .CLAMP_0_END
.CLAMP_0_OK:
    LDD TMPPTR
    STD RESULT
.CLAMP_0_END:
    STD VAR_PLAYER_X
; VPy_LINE:190
    ; CLAMP: Clamp value to range [min, max]
    LDD >VAR_PLAYER_Y
    STD TMPPTR     ; Save value
    LDD #0
    STD TMPPTR+2   ; Save min
    LDD #32
    STD TMPPTR+4   ; Save max
    LDD TMPPTR     ; Load value
    CMPD TMPPTR+2  ; Compare with min
    BGE .CLAMP_1_CHK_MAX ; Branch if value >= min
    LDD TMPPTR+2
    STD RESULT
    BRA .CLAMP_1_END
.CLAMP_1_CHK_MAX:
    LDD TMPPTR     ; Load value again
    CMPD TMPPTR+4  ; Compare with max
    BLE .CLAMP_1_OK  ; Branch if value <= max
    LDD TMPPTR+4
    STD RESULT
    BRA .CLAMP_1_END
.CLAMP_1_OK:
    LDD TMPPTR
    STD RESULT
.CLAMP_1_END:
    STD VAR_PLAYER_Y
; VPy_LINE:193
    LDD >VAR_BTN1
    CMPD #1
    LBNE IF_NEXT_13
; VPy_LINE:194
    LDB >VAR_BTN_PREV
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #0
    LBNE IF_NEXT_15
; VPy_LINE:195
    LDB >VAR_BULLET_ALIVE
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #0
    LBNE IF_NEXT_17
; VPy_LINE:196
    LDD #1
    STB VAR_BULLET_ALIVE
; VPy_LINE:197
    LDD #10
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_CAM_Z
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_BULLET_ABS_Z
; VPy_LINE:198
    LDD >VAR_PLAYER_X
    STD VAR_BULLET_RX
; VPy_LINE:199
    LDD >VAR_PLAYER_Y
    STD VAR_BULLET_RY
; VPy_LINE:200
; NATIVE_CALL: PLAY_SFX at line 200
    ; PLAY_SFX("laser") - play SFX asset (index=0)
    LDX #_LASER_SFX  ; Load SFX data pointer
    JSR PLAY_SFX_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_16
IF_NEXT_17:
IF_END_16:
    LBRA IF_END_14
IF_NEXT_15:
IF_END_14:
    LBRA IF_END_12
IF_NEXT_13:
IF_END_12:
; VPy_LINE:201
    LDD >VAR_BTN1
    STB VAR_BTN_PREV
; VPy_LINE:204
    LDB >VAR_BULLET_ALIVE
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #1
    LBNE IF_NEXT_19
; VPy_LINE:205
    LDD #4
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_BULLET_ABS_Z
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_BULLET_ABS_Z
; VPy_LINE:206
    LDD >VAR_CAM_Z
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_BULLET_ABS_Z
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_BULLET_RZ
; VPy_LINE:207
    LDD #200  ; const VIS_FAR
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BULLET_RZ
    CMPD TMPVAL
    LBGE .CMP_6_TRUE
    LDD #0
    LBRA .CMP_6_END
.CMP_6_TRUE:
    LDD #1
.CMP_6_END:
    LBEQ IF_NEXT_21
; VPy_LINE:208
    LDD #0
    STB VAR_BULLET_ALIVE
    LBRA IF_END_20
IF_NEXT_21:
; VPy_LINE:210
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_BULLET_RX
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_P_RX
; VPy_LINE:211
    LDD >VAR_BULLET_RY
    STD VAR_P_WY
; VPy_LINE:212
    LDD >VAR_BULLET_RZ
    STD VAR_P_RZ
; VPy_LINE:213
    JSR PROJECT
; VPy_LINE:214
; NATIVE_CALL: DRAW_VECTOR at line 214
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bullet (index=0, 2 paths)
    LDD >VAR_P_SX
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_1          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_P_SY
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
    LDX #_BULLET_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BULLET_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_1:
    LDD #0
    STD RESULT
; VPy_LINE:217
    LDD #-1
    STD VAR_HIT_BI
; VPy_LINE:218
    LDD #0
    STD VAR_BI
; VPy_LINE:219
WH_22: ; while start
    LDD #6  ; const BLD_COUNT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BI
    CMPD TMPVAL
    LBLT .CMP_7_TRUE
    LDD #0
    LBRA .CMP_7_END
.CMP_7_TRUE:
    LDD #1
.CMP_7_END:
    LBEQ WH_END_23
; VPy_LINE:220
    LDX #ARRAY_BLD_Z_DATA  ; Array base
    LDD >VAR_BI
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_BZ_CHECK
; VPy_LINE:221
    LDX #ARRAY_BLD_X_DATA  ; Array base
    LDD >VAR_BI
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_BX_CHECK
; VPy_LINE:222
    LDX #ARRAY_BLD_W_DATA  ; Array base
    LDD >VAR_BI
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_BW_CHECK
; VPy_LINE:223
    LDX #ARRAY_BLD_H_DATA  ; Array base
    LDD >VAR_BI
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_BH_CHECK
; VPy_LINE:224
    LDD >VAR_BZ_CHECK
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BULLET_ABS_Z
    CMPD TMPVAL
    LBGE .CMP_8_TRUE
    LDD #0
    LBRA .CMP_8_END
.CMP_8_TRUE:
    LDD #1
.CMP_8_END:
    LBEQ IF_NEXT_25
; VPy_LINE:225
    LDD #8
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_BZ_CHECK
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BULLET_ABS_Z
    CMPD TMPVAL
    LBLE .CMP_9_TRUE
    LDD #0
    LBRA .CMP_9_END
.CMP_9_TRUE:
    LDD #1
.CMP_9_END:
    LBEQ IF_NEXT_27
; VPy_LINE:226
    LDD >VAR_BX_CHECK
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BULLET_RX
    CMPD TMPVAL
    LBGE .CMP_10_TRUE
    LDD #0
    LBRA .CMP_10_END
.CMP_10_TRUE:
    LDD #1
.CMP_10_END:
    LBEQ IF_NEXT_29
; VPy_LINE:227
    LDD >VAR_BW_CHECK
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_BX_CHECK
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BULLET_RX
    CMPD TMPVAL
    LBLE .CMP_11_TRUE
    LDD #0
    LBRA .CMP_11_END
.CMP_11_TRUE:
    LDD #1
.CMP_11_END:
    LBEQ IF_NEXT_31
; VPy_LINE:228
    LDD >VAR_BH_CHECK
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BULLET_RY
    CMPD TMPVAL
    LBLE .CMP_12_TRUE
    LDD #0
    LBRA .CMP_12_END
.CMP_12_TRUE:
    LDD #1
.CMP_12_END:
    LBEQ IF_NEXT_33
; VPy_LINE:229
    LDD >VAR_BI
    STD VAR_HIT_BI
; VPy_LINE:230
    LDD #6  ; const BLD_COUNT
    STD VAR_BI
    LBRA IF_END_32
IF_NEXT_33:
IF_END_32:
    LBRA IF_END_30
IF_NEXT_31:
IF_END_30:
    LBRA IF_END_28
IF_NEXT_29:
IF_END_28:
    LBRA IF_END_26
IF_NEXT_27:
IF_END_26:
    LBRA IF_END_24
IF_NEXT_25:
IF_END_24:
; VPy_LINE:231
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_BI
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_BI
    LBRA WH_22
WH_END_23: ; while end
; VPy_LINE:234
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_HIT_BI
    CMPD TMPVAL
    LBGE .CMP_13_TRUE
    LDD #0
    LBRA .CMP_13_END
.CMP_13_TRUE:
    LDD #1
.CMP_13_END:
    LBEQ IF_NEXT_35
; VPy_LINE:235
    LDD #0
    STB VAR_BULLET_ALIVE
; VPy_LINE:236
    LDD #14
    STB VAR_EXPL_FRAMES
; VPy_LINE:237
    LDD >VAR_P_SX
    STD VAR_EXPL_SX
; VPy_LINE:238
    LDD >VAR_P_SY
    STD VAR_EXPL_SY
; VPy_LINE:239
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_SCORE
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_SCORE
; VPy_LINE:240
    LDD >VAR_HIT_BI
    CMPD #0
    LBNE IF_NEXT_37
; VPy_LINE:241
    LDD #0
    STB VAR_B0ALIVE
    LBRA IF_END_36
IF_NEXT_37:
IF_END_36:
; VPy_LINE:242
    LDD >VAR_HIT_BI
    CMPD #1
    LBNE IF_NEXT_39
; VPy_LINE:243
    LDD #0
    STB VAR_B1ALIVE
    LBRA IF_END_38
IF_NEXT_39:
IF_END_38:
; VPy_LINE:244
    LDD >VAR_HIT_BI
    CMPD #2
    LBNE IF_NEXT_41
; VPy_LINE:245
    LDD #0
    STB VAR_B2ALIVE
    LBRA IF_END_40
IF_NEXT_41:
IF_END_40:
; VPy_LINE:246
    LDD >VAR_HIT_BI
    CMPD #3
    LBNE IF_NEXT_43
; VPy_LINE:247
    LDD #0
    STB VAR_B3ALIVE
    LBRA IF_END_42
IF_NEXT_43:
IF_END_42:
; VPy_LINE:248
    LDD >VAR_HIT_BI
    CMPD #4
    LBNE IF_NEXT_45
; VPy_LINE:249
    LDD #0
    STB VAR_B4ALIVE
    LBRA IF_END_44
IF_NEXT_45:
IF_END_44:
; VPy_LINE:250
    LDD >VAR_HIT_BI
    CMPD #5
    LBNE IF_NEXT_47
; VPy_LINE:251
    LDD #0
    STB VAR_B5ALIVE
    LBRA IF_END_46
IF_NEXT_47:
IF_END_46:
    LBRA IF_END_34
IF_NEXT_35:
IF_END_34:
IF_END_20:
    LBRA IF_END_18
IF_NEXT_19:
IF_END_18:
; VPy_LINE:254
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_EXPL_FRAMES
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBGT .CMP_14_TRUE
    LDD #0
    LBRA .CMP_14_END
.CMP_14_TRUE:
    LDD #1
.CMP_14_END:
    LBEQ IF_NEXT_49
; VPy_LINE:255
; NATIVE_CALL: DRAW_VECTOR at line 255
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: explosion (index=1, 4 paths)
    LDD >VAR_EXPL_SX
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_2          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_EXPL_SY
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
    LDX #_EXPLOSION_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_EXPLOSION_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_EXPLOSION_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_EXPLOSION_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_2:
    LDD #0
    STD RESULT
; VPy_LINE:256
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDB >VAR_EXPL_FRAMES
    CLRA            ; Zero-extend: A=0, B=value
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STB VAR_EXPL_FRAMES
    LBRA IF_END_48
IF_NEXT_49:
IF_END_48:
; VPy_LINE:261
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-30
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_P_RX
; VPy_LINE:262
    LDD #0
    STD VAR_P_WY
; VPy_LINE:263
    LDD #-80
    STD VAR_P_RZ
; VPy_LINE:264
    JSR PROJECT
; VPy_LINE:265
    LDD >VAR_P_SX
    STD VAR_GSX_L
; VPy_LINE:266
    LDD >VAR_P_SY
    STD VAR_GSY_L
; VPy_LINE:267
    LDD #200
    STD VAR_P_RZ
; VPy_LINE:268
    JSR PROJECT
; VPy_LINE:269
    LDD >VAR_P_SX
    STD VAR_GSX_R
; VPy_LINE:270
    LDD >VAR_P_SY
    STD VAR_GSY_R
; VPy_LINE:271
; NATIVE_CALL: DRAW_LINE at line 271
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_GSX_L
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_GSY_L
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_GSX_R
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_GSY_R
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #25
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
; VPy_LINE:274
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #30
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_P_RX
; VPy_LINE:275
    LDD #0
    STD VAR_P_WY
; VPy_LINE:276
    LDD #-80
    STD VAR_P_RZ
; VPy_LINE:277
    JSR PROJECT
; VPy_LINE:278
    LDD >VAR_P_SX
    STD VAR_GSX_L
; VPy_LINE:279
    LDD >VAR_P_SY
    STD VAR_GSY_L
; VPy_LINE:280
    LDD #200
    STD VAR_P_RZ
; VPy_LINE:281
    JSR PROJECT
; VPy_LINE:282
    LDD >VAR_P_SX
    STD VAR_GSX_R
; VPy_LINE:283
    LDD >VAR_P_SY
    STD VAR_GSY_R
; VPy_LINE:284
; NATIVE_CALL: DRAW_LINE at line 284
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_GSX_L
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_GSY_L
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_GSX_R
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_GSY_R
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #25
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
; VPy_LINE:287
    LDD #0
    STD VAR_GI
; VPy_LINE:288
WH_50: ; while start
    LDD #8
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_GI
    CMPD TMPVAL
    LBLT .CMP_15_TRUE
    LDD #0
    LBRA .CMP_15_END
.CMP_15_TRUE:
    LDD #1
.CMP_15_END:
    LBEQ WH_END_51
; VPy_LINE:289
    LDD #40
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_GI
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD #80
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_GRZ
; VPy_LINE:290
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-30
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_P_RX
; VPy_LINE:291
    LDD #0
    STD VAR_P_WY
; VPy_LINE:292
    LDD >VAR_GRZ
    STD VAR_P_RZ
; VPy_LINE:293
    JSR PROJECT
; VPy_LINE:294
    LDD >VAR_P_SX
    STD VAR_GSX_L
; VPy_LINE:295
    LDD >VAR_P_SY
    STD VAR_GSY_L
; VPy_LINE:296
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #30
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_P_RX
; VPy_LINE:297
    JSR PROJECT
; VPy_LINE:298
    LDD >VAR_P_SX
    STD VAR_GSX_R
; VPy_LINE:299
    LDD >VAR_P_SY
    STD VAR_GSY_R
; VPy_LINE:300
; NATIVE_CALL: DRAW_LINE at line 300
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_GSX_L
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_GSY_L
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_GSX_R
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_GSY_R
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #18
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
; VPy_LINE:301
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_GI
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_GI
    LBRA WH_50
WH_END_51: ; while end
; VPy_LINE:304
    LDD #0
    STD VAR_BI
; VPy_LINE:305
WH_52: ; while start
    LDD #6  ; const BLD_COUNT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BI
    CMPD TMPVAL
    LBLT .CMP_16_TRUE
    LDD #0
    LBRA .CMP_16_END
.CMP_16_TRUE:
    LDD #1
.CMP_16_END:
    LBEQ WH_END_53
; VPy_LINE:306
    LDX #ARRAY_BLD_X_DATA  ; Array base
    LDD >VAR_BI
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_BX
; VPy_LINE:307
    LDX #ARRAY_BLD_Z_DATA  ; Array base
    LDD >VAR_BI
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_BZ
; VPy_LINE:308
    LDX #ARRAY_BLD_W_DATA  ; Array base
    LDD >VAR_BI
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_BW
; VPy_LINE:309
    LDX #ARRAY_BLD_H_DATA  ; Array base
    LDD >VAR_BI
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_BH
; VPy_LINE:310
    LDD >VAR_CAM_Z
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_BZ
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_RZ
; VPy_LINE:313
    LDB >VAR_B0ALIVE
    CLRA            ; Zero-extend: A=0, B=value
    STB VAR_ALIVE
; VPy_LINE:314
    LDD >VAR_BI
    CMPD #1
    LBNE IF_NEXT_55
; VPy_LINE:315
    LDB >VAR_B1ALIVE
    CLRA            ; Zero-extend: A=0, B=value
    STB VAR_ALIVE
    LBRA IF_END_54
IF_NEXT_55:
IF_END_54:
; VPy_LINE:316
    LDD >VAR_BI
    CMPD #2
    LBNE IF_NEXT_57
; VPy_LINE:317
    LDB >VAR_B2ALIVE
    CLRA            ; Zero-extend: A=0, B=value
    STB VAR_ALIVE
    LBRA IF_END_56
IF_NEXT_57:
IF_END_56:
; VPy_LINE:318
    LDD >VAR_BI
    CMPD #3
    LBNE IF_NEXT_59
; VPy_LINE:319
    LDB >VAR_B3ALIVE
    CLRA            ; Zero-extend: A=0, B=value
    STB VAR_ALIVE
    LBRA IF_END_58
IF_NEXT_59:
IF_END_58:
; VPy_LINE:320
    LDD >VAR_BI
    CMPD #4
    LBNE IF_NEXT_61
; VPy_LINE:321
    LDB >VAR_B4ALIVE
    CLRA            ; Zero-extend: A=0, B=value
    STB VAR_ALIVE
    LBRA IF_END_60
IF_NEXT_61:
IF_END_60:
; VPy_LINE:322
    LDD >VAR_BI
    CMPD #5
    LBNE IF_NEXT_63
; VPy_LINE:323
    LDB >VAR_B5ALIVE
    CLRA            ; Zero-extend: A=0, B=value
    STB VAR_ALIVE
    LBRA IF_END_62
IF_NEXT_63:
IF_END_62:
; VPy_LINE:325
    LDB >VAR_ALIVE
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #1
    LBNE IF_NEXT_65
; VPy_LINE:326
    LDD #-20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_RZ
    CMPD TMPVAL
    LBGT .CMP_17_TRUE
    LDD #0
    LBRA .CMP_17_END
.CMP_17_TRUE:
    LDD #1
.CMP_17_END:
    LBEQ IF_NEXT_67
; VPy_LINE:327
    LDD #200  ; const VIS_FAR
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_RZ
    CMPD TMPVAL
    LBLT .CMP_18_TRUE
    LDD #0
    LBRA .CMP_18_END
.CMP_18_TRUE:
    LDD #1
.CMP_18_END:
    LBEQ IF_NEXT_69
; VPy_LINE:328
    JSR DRAW_BOX
    LBRA IF_END_68
IF_NEXT_69:
IF_END_68:
    LBRA IF_END_66
IF_NEXT_67:
IF_END_66:
    LBRA IF_END_64
IF_NEXT_65:
IF_END_64:
; VPy_LINE:330
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_BI
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_BI
    LBRA WH_52
WH_END_53: ; while end
; VPy_LINE:333
    LDD #40
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_PLAYER_SY
; VPy_LINE:334
; NATIVE_CALL: DRAW_VECTOR at line 334
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: ship (index=2, 5 paths)
    LDD #-20
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_3          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_PLAYER_SY
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
    LDX #_SHIP_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_SHIP_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_SHIP_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_SHIP_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_SHIP_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_3:
    LDD #0
    STD RESULT
; VPy_LINE:337
    LDD #0
    STD VAR_P_RX
; VPy_LINE:338
    LDD #0
    STD VAR_P_WY
; VPy_LINE:339
    LDD #0
    STD VAR_P_RZ
; VPy_LINE:340
    JSR PROJECT
; VPy_LINE:341
; NATIVE_CALL: DRAW_LINE at line 341
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #2
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_P_SX
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_P_SY
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #2
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_P_SX
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_P_SY
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #35
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
; VPy_LINE:344
    LDD #2
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD VAR_ALT_BAR
; VPy_LINE:345
; NATIVE_CALL: DRAW_LINE at line 345
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #-93
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #-120
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #-93
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #64
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-120
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #22
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
; VPy_LINE:346
; NATIVE_CALL: DRAW_LINE at line 346
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #-90
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #-120
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #-90
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_ALT_BAR
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-120
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #55
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
; VPy_LINE:349
; NATIVE_CALL: PRINT_NUMBER at line 349
    ; PRINT_NUMBER(x, y, num)
    LDD #-90
    STD >VAR_ARG0    ; X position
    LDD #110
    STD >VAR_ARG1    ; Y position
    LDD >VAR_SCORE
    STD >VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX
    RTS

; Function: PROJECT
PROJECT:
; VPy_LINE:103
    LDD #2
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_P_RZ
    TFR D,X             ; X = LEFT (dividend)
    LDD TMPVAL          ; D = RIGHT (divisor)
    JSR DIV16           ; D = X / D
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD #2
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_P_RX
    TFR D,X             ; X = LEFT (dividend)
    LDD TMPVAL          ; D = RIGHT (divisor)
    JSR DIV16           ; D = X / D
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    ADDD TMPVAL         ; D = LEFT + RIGHT
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD #20
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_P_SX
; VPy_LINE:104
    LDD #2
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_P_RZ
    TFR D,X             ; X = LEFT (dividend)
    LDD TMPVAL          ; D = RIGHT (divisor)
    JSR DIV16           ; D = X / D
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD #2
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_P_RX
    TFR D,X             ; X = LEFT (dividend)
    LDD TMPVAL          ; D = RIGHT (divisor)
    JSR DIV16           ; D = X / D
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD TMPVAL          ; LEFT → TMPVAL (RIGHT simple, commutative)
    LDD >VAR_P_WY
    ADDD TMPVAL         ; D = LEFT + RIGHT
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD #40
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_P_SY
    RTS

; Function: DRAW_BOX
DRAW_BOX:
; VPy_LINE:108
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_BX
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_P_RX
; VPy_LINE:109
    LDD #0
    STD VAR_P_WY
; VPy_LINE:110
    LDD >VAR_RZ
    STD VAR_P_RZ
; VPy_LINE:111
    JSR PROJECT
; VPy_LINE:112
    LDD >VAR_P_SX
    STD VAR_C0X
; VPy_LINE:113
    LDD >VAR_P_SY
    STD VAR_C0Y
; VPy_LINE:115
    LDD >VAR_BW
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_BX
    ADDD TMPVAL         ; D = LEFT + RIGHT
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_P_RX
; VPy_LINE:116
    LDD #0
    STD VAR_P_WY
; VPy_LINE:117
    LDD >VAR_RZ
    STD VAR_P_RZ
; VPy_LINE:118
    JSR PROJECT
; VPy_LINE:119
    LDD >VAR_P_SX
    STD VAR_C1X
; VPy_LINE:120
    LDD >VAR_P_SY
    STD VAR_C1Y
; VPy_LINE:122
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_BX
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_P_RX
; VPy_LINE:123
    LDD >VAR_BH
    STD VAR_P_WY
; VPy_LINE:124
    LDD >VAR_RZ
    STD VAR_P_RZ
; VPy_LINE:125
    JSR PROJECT
; VPy_LINE:126
    LDD >VAR_P_SX
    STD VAR_C2X
; VPy_LINE:127
    LDD >VAR_P_SY
    STD VAR_C2Y
; VPy_LINE:129
    LDD >VAR_BW
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_BX
    ADDD TMPVAL         ; D = LEFT + RIGHT
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_P_RX
; VPy_LINE:130
    LDD >VAR_BH
    STD VAR_P_WY
; VPy_LINE:131
    LDD >VAR_RZ
    STD VAR_P_RZ
; VPy_LINE:132
    JSR PROJECT
; VPy_LINE:133
    LDD >VAR_P_SX
    STD VAR_C3X
; VPy_LINE:134
    LDD >VAR_P_SY
    STD VAR_C3Y
; VPy_LINE:136
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_BX
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_P_RX
; VPy_LINE:137
    LDD >VAR_BH
    STD VAR_P_WY
; VPy_LINE:138
    LDD #8
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_RZ
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_P_RZ
; VPy_LINE:139
    JSR PROJECT
; VPy_LINE:140
    LDD >VAR_P_SX
    STD VAR_C4X
; VPy_LINE:141
    LDD >VAR_P_SY
    STD VAR_C4Y
; VPy_LINE:143
    LDD >VAR_BW
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_BX
    ADDD TMPVAL         ; D = LEFT + RIGHT
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_P_RX
; VPy_LINE:144
    LDD >VAR_BH
    STD VAR_P_WY
; VPy_LINE:145
    LDD #8
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_RZ
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_P_RZ
; VPy_LINE:146
    JSR PROJECT
; VPy_LINE:147
    LDD >VAR_P_SX
    STD VAR_C5X
; VPy_LINE:148
    LDD >VAR_P_SY
    STD VAR_C5Y
; VPy_LINE:150
; NATIVE_CALL: DRAW_LINE at line 150
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_C0X
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_C0Y
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_C1X
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_C1Y
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #70
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
; VPy_LINE:151
; NATIVE_CALL: DRAW_LINE at line 151
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_C0X
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_C0Y
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_C2X
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_C2Y
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #70
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
; VPy_LINE:152
; NATIVE_CALL: DRAW_LINE at line 152
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_C1X
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_C1Y
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_C3X
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_C3Y
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #70
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
; VPy_LINE:153
; NATIVE_CALL: DRAW_LINE at line 153
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_C2X
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_C2Y
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_C3X
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_C3Y
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #70
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
; VPy_LINE:154
; NATIVE_CALL: DRAW_LINE at line 154
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_C2X
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_C2Y
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_C4X
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_C4Y
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #50
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
; VPy_LINE:155
; NATIVE_CALL: DRAW_LINE at line 155
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_C3X
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_C3Y
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_C5X
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_C5Y
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #50
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
; VPy_LINE:156
; NATIVE_CALL: DRAW_LINE at line 156
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_C4X
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_C4Y
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_C5X
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_C5Y
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #50
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    RTS

;***************************************************************************
; EMBEDDED ASSETS (vectors, music, levels, SFX)
;***************************************************************************

; Generated from bullet.vec (Malban Draw_Sync_List format)
; Total paths: 2, points: 4
; X bounds: min=-5, max=5, width=10
; Center: (0, 0)

_BULLET_WIDTH EQU 10
_BULLET_HALF_WIDTH EQU 5
_BULLET_HEIGHT EQU 4
_BULLET_HALF_HEIGHT EQU 2
_BULLET_CENTER_X EQU 0
_BULLET_CENTER_Y EQU 0

_BULLET_VECTORS:  ; Main entry (header + 2 path(s))
    FDB 2               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _BULLET_PATH0        ; pointer to path 0
    FDB _BULLET_PATH1        ; pointer to path 1

_BULLET_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FE,$00,0,0        ; path0: header (y=-2, x=0)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_BULLET_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $00,$FB,0,0        ; path1: header (y=0, x=-5)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB 2                ; End marker (path complete)
; Generated from explosion.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 8
; X bounds: min=-10, max=10, width=20
; Center: (0, 0)

_EXPLOSION_WIDTH EQU 20
_EXPLOSION_HALF_WIDTH EQU 10
_EXPLOSION_HEIGHT EQU 20
_EXPLOSION_HALF_HEIGHT EQU 10
_EXPLOSION_CENTER_X EQU 0
_EXPLOSION_CENTER_Y EQU 0

_EXPLOSION_VECTORS:  ; Main entry (header + 4 path(s))
    FDB 4               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _EXPLOSION_PATH0        ; pointer to path 0
    FDB _EXPLOSION_PATH1        ; pointer to path 1
    FDB _EXPLOSION_PATH2        ; pointer to path 2
    FDB _EXPLOSION_PATH3        ; pointer to path 3

_EXPLOSION_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $F9,$F9,0,0        ; path0: header (y=-7, x=-7)
    FCB $FF,$0E,$0E          ; flag=-1, dy=14, dx=14
    FCB 2                ; End marker (path complete)

_EXPLOSION_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $00,$0A,0,0        ; path1: header (y=0, x=10)
    FCB $FF,$00,$EC          ; flag=-1, dy=0, dx=-20
    FCB 2                ; End marker (path complete)

_EXPLOSION_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $07,$F9,0,0        ; path2: header (y=7, x=-7)
    FCB $FF,$F2,$0E          ; flag=-1, dy=-14, dx=14
    FCB 2                ; End marker (path complete)

_EXPLOSION_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $F6,$00,0,0        ; path3: header (y=-10, x=0)
    FCB $FF,$14,$00          ; flag=-1, dy=20, dx=0
    FCB 2                ; End marker (path complete)
; Generated from ship.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 26
; X bounds: min=-13, max=12, width=25
; Center: (0, 0)

_SHIP_WIDTH EQU 25
_SHIP_HALF_WIDTH EQU 12
_SHIP_HEIGHT EQU 30
_SHIP_HALF_HEIGHT EQU 15
_SHIP_CENTER_X EQU 0
_SHIP_CENTER_Y EQU 0

_SHIP_VECTORS:  ; Main entry (header + 5 path(s))
    FDB 5               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _SHIP_PATH0        ; pointer to path 0
    FDB _SHIP_PATH1        ; pointer to path 1
    FDB _SHIP_PATH2        ; pointer to path 2
    FDB _SHIP_PATH3        ; pointer to path 3
    FDB _SHIP_PATH4        ; pointer to path 4

_SHIP_PATH0:    ; Path 0
    FCB 70              ; path0: intensity
    FCB $02,$03,0,0        ; path0: header (y=2, x=3)
    FCB $FF,$03,$04          ; flag=-1, dy=3, dx=4
    FCB $FF,$03,$FE          ; flag=-1, dy=3, dx=-2
    FCB $FF,$FE,$FC          ; flag=-1, dy=-2, dx=-4
    FCB $FF,$FC,$02          ; flag=-1, dy=-4, dx=2
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_SHIP_PATH1:    ; Path 1
    FCB 85              ; path1: intensity
    FCB $05,$FE,0,0        ; path1: header (y=5, x=-2)
    FCB $FF,$03,$F7          ; flag=-1, dy=3, dx=-9
    FCB $FF,$07,$03          ; flag=-1, dy=7, dx=3
    FCB $FF,$FB,$0B          ; flag=-1, dy=-5, dx=11
    FCB $FF,$FB,$FB          ; flag=-1, dy=-5, dx=-5
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_SHIP_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $FB,$02,0,0        ; path2: header (y=-5, x=2)
    FCB $FF,$FD,$09          ; flag=-1, dy=-3, dx=9
    FCB $FF,$F9,$FD          ; flag=-1, dy=-7, dx=-3
    FCB $FF,$05,$F5          ; flag=-1, dy=5, dx=-11
    FCB $FF,$05,$05          ; flag=-1, dy=5, dx=5
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_SHIP_PATH3:    ; Path 3
    FCB 55              ; path3: intensity
    FCB $F7,$F7,0,0        ; path3: header (y=-9, x=-9)
    FCB $FF,$FE,$FC          ; flag=-1, dy=-2, dx=-4
    FCB $FF,$FC,$01          ; flag=-1, dy=-4, dx=1
    FCB $FF,$03,$04          ; flag=-1, dy=3, dx=4
    FCB 2                ; End marker (path complete)

_SHIP_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $F8,$F4,0,0        ; path4: header (y=-8, x=-12)
    FCB $FF,$FB,$05          ; flag=-1, dy=-5, dx=5
    FCB $FF,$15,$13          ; flag=-1, dy=21, dx=19
    FCB $FF,$05,$FB          ; flag=-1, dy=5, dx=-5
    FCB $FF,$EB,$ED          ; flag=-1, dy=-21, dx=-19
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)
_LASER_SFX:
    ; SFX: laser (laser)
    ; Duration: 80ms (4fr), Freq: 1400Hz, Channel: 0
    FCB $A8         ; Frame 0 - flags (vol=8, noisevol=0, tone=Y, noise=N)
    FCB $00, $30  ; Tone period = 48 (big-endian)
    FCB $A8         ; Frame 1 - flags (vol=8, noisevol=0, tone=Y, noise=N)
    FCB $00, $3B  ; Tone period = 59 (big-endian)
    FCB $A5         ; Frame 2 - flags (vol=5, noisevol=0, tone=Y, noise=N)
    FCB $00, $4D  ; Tone period = 77 (big-endian)
    FCB $A2         ; Frame 3 - flags (vol=2, noisevol=0, tone=Y, noise=N)
    FCB $00, $70  ; Tone period = 112 (big-endian)
    FCB $D0, $20    ; End of effect marker

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
PRINT_TEXT_STR_3529276:
    FCC "ship"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_102743755:
    FCC "laser"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2917033218:
    FCC "bullet"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_89546106876693:
    FCC "explosion"
    FCB $80          ; Vectrex string terminator

