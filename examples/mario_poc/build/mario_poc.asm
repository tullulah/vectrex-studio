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
    FCC "SUPER MARIO POC"
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
    CLR >LEVEL_LOADED       ; No level loaded yet (flag, not a pointer)
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
DRAW_LINE_ARGS       EQU $C880+$24   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$2E   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$30   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$32   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$33   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$34   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$36   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
LEVEL_PTR            EQU $C880+$38   ; Pointer to currently loaded level header (2 bytes)
LEVEL_LOADED         EQU $C880+$3A   ; Level loaded flag (0=not loaded, 1=loaded) (1 bytes)
LEVEL_WIDTH          EQU $C880+$3B   ; Level width (legacy tile API) (1 bytes)
LEVEL_HEIGHT         EQU $C880+$3C   ; Level height (legacy tile API) (1 bytes)
LEVEL_TILE_SIZE      EQU $C880+$3D   ; Tile size (legacy tile API) (1 bytes)
LEVEL_Y_IDX          EQU $C880+$3E   ; SHOW_LEVEL row counter (legacy) (1 bytes)
LEVEL_X_IDX          EQU $C880+$3F   ; SHOW_LEVEL column counter (legacy) (1 bytes)
LEVEL_TEMP           EQU $C880+$40   ; SHOW_LEVEL temporary byte (legacy) (1 bytes)
LEVEL_BG_COUNT       EQU $C880+$41   ; BG object count (1 bytes)
LEVEL_GP_COUNT       EQU $C880+$42   ; GP object count (1 bytes)
LEVEL_FG_COUNT       EQU $C880+$43   ; FG object count (1 bytes)
CAMERA_X             EQU $C880+$44   ; Camera X scroll offset (16-bit signed world units) (2 bytes)
CAMERA_Y             EQU $C880+$46   ; Camera Y scroll offset (16-bit signed world units) (2 bytes)
SCROLL_LIMIT_LEFT    EQU $C880+$48   ; Camera scroll limit: left world X (2 bytes)
SCROLL_LIMIT_RIGHT   EQU $C880+$4A   ; Camera scroll limit: right world X (2 bytes)
SCROLL_LIMIT_TOP     EQU $C880+$4C   ; Camera scroll limit: top world Y (2 bytes)
SCROLL_LIMIT_BOTTOM  EQU $C880+$4E   ; Camera scroll limit: bottom world Y (2 bytes)
LEVEL_BG_ROM_PTR     EQU $C880+$50   ; BG layer ROM pointer (2 bytes)
LEVEL_GP_ROM_PTR     EQU $C880+$52   ; GP layer ROM pointer (2 bytes)
LEVEL_FG_ROM_PTR     EQU $C880+$54   ; FG layer ROM pointer (2 bytes)
LEVEL_GP_PTR         EQU $C880+$56   ; GP active pointer (RAM buffer after LOAD_LEVEL) (2 bytes)
LEVEL_BANK           EQU $C880+$58   ; Bank ID for current level (for multibank) (1 bytes)
LEVEL_ENEMY_COUNT    EQU $C880+$59   ; Enemy count from current level header (1 bytes)
LEVEL_ENEMY_INSTANCES_PTR EQU $C880+$5A   ; Ptr to enemy instances table in level bank (2 bytes)
LEVEL_SCREEN_COUNT   EQU $C880+$5C   ; Total Y screens partitioning the level (1 bytes)
LEVEL_BG_SCREENS_PTR EQU $C880+$5D   ; Per-screen BG index ptr (3 bytes per screen) (2 bytes)
LEVEL_GP_SCREENS_PTR EQU $C880+$5F   ; Per-screen GP index ptr (2 bytes)
LEVEL_FG_SCREENS_PTR EQU $C880+$61   ; Per-screen FG index ptr (2 bytes)
SLR_CUR_X            EQU $C880+$63   ; SHOW_LEVEL: clamped (visible) beam X — actually written to integrator (1 bytes)
SLR_TRUE_X           EQU $C880+$64   ; SHOW_LEVEL: 16-bit unclamped abs_x for per-segment line clipping (2 bytes)
DRAW_T1_SCALED       EQU $C880+$66   ; SHOW_LEVEL: effective T1 for current object (DRAW_SCALE * object_scale) (1 bytes)
SDCP_ABS_Y           EQU $C880+$67   ; SHOW_LEVEL: abs_y temporary for SDCP (cannot share TMPVAL — would corrupt top_screen between layers) (1 bytes)
SLR_TOP_SCREEN       EQU $C880+$68   ; SHOW_LEVEL: top Y screen idx (lives across all 3 layers — must not be in TMPVAL) (1 bytes)
SLR_BOT_SCREEN       EQU $C880+$69   ; SHOW_LEVEL: bot Y screen idx (lives across all 3 layers) (1 bytes)
LCOL_PX              EQU $C880+$6A   ; LEVEL_COLLISION player world_x input (16-bit) (2 bytes)
LCOL_BEST_Y          EQU $C880+$6C   ; LEVEL_COLLISION_Y best floor y found (16-bit signed) (2 bytes)
LCOL_PY              EQU $C880+$6E   ; LEVEL_COLLISION player_top (16-bit signed) (2 bytes)
LCOL_PHH             EQU $C880+$70   ; LEVEL_COLLISION player half_height (1 bytes)
LCOL_PHW             EQU $C880+$71   ; LEVEL_COLLISION_X player half_width (1 bytes)
LCOL_THW             EQU $C880+$72   ; LEVEL_COLLISION_X total half_width (player_hw + obj_hw scratch) (1 bytes)
LCOL_OBJ_Y           EQU $C880+$73   ; LEVEL_COLLISION_Y current object world_y (16-bit) (2 bytes)
LCOL_LOCAL_PX        EQU $C880+$75   ; LEVEL_COLLISION_Y player_x in object-local coords (16-bit) (2 bytes)
LCOL_OBJ_CNT         EQU $C880+$77   ; LEVEL_COLLISION_Y GP objects remaining (1 bytes)
LCOL_SEG_CNT         EQU $C880+$78   ; LEVEL_COLLISION_Y mesh floor segments remaining (1 bytes)
DRAW_SCALE           EQU $C880+$79   ; Current T1 scale for Draw_Sync_List_At_With_Mirrors ($7F=normal) (1 bytes)
VAR_ARG0             EQU $C880+$7A   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $C880+$7C   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $C880+$7E   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $C880+$80   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $C880+$82   ; Function argument 4 (16-bit) (2 bytes)
VAR_ARG5             EQU $C880+$84   ; Function argument 5 (16-bit) (2 bytes)
VAR_ARG6             EQU $C880+$86   ; Function argument 6 (16-bit) (2 bytes)
VAR_ARG7             EQU $C880+$88   ; Function argument 7 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $C880+$8A   ; Current ROM bank ID (multibank tracking) (1 bytes)
VAR_PLAYER_X         EQU $C880+$8B   ; User variable: PLAYER_X (2 bytes)
VAR_PLAYER_Y         EQU $C880+$8D   ; User variable: PLAYER_Y (2 bytes)
VAR_VEL_Y            EQU $C880+$8F   ; User variable: VEL_Y (2 bytes)
VAR_ON_GROUND        EQU $C880+$91   ; User variable: ON_GROUND (1 bytes)
VAR_PREV_Y           EQU $C880+$92   ; User variable: PREV_Y (2 bytes)
VAR_CAMERA_X         EQU $C880+$94   ; User variable: CAMERA_X (2 bytes)
VAR_FLOOR_Y          EQU $C880+$96   ; User variable: FLOOR_Y (2 bytes)
VAR_JOY_X            EQU $C880+$98   ; User variable: JOY_X (2 bytes)
VAR_BTN_JUMP         EQU $C880+$9A   ; User variable: BTN_JUMP (2 bytes)
PSG_MUSIC_PTR        EQU $C880+$9C   ; PSG music data pointer (2 bytes)
PSG_MUSIC_START      EQU $C880+$9E   ; PSG music start pointer (for loops) (2 bytes)
PSG_MUSIC_ACTIVE     EQU $C880+$A0   ; PSG music active flag (1 bytes)
PSG_IS_PLAYING       EQU $C880+$A1   ; PSG playing flag (1 bytes)
PSG_DELAY_FRAMES     EQU $C880+$A2   ; PSG frame delay counter (1 bytes)
PSG_MUSIC_BANK       EQU $C880+$A3   ; PSG music bank ID (for multibank) (1 bytes)
SFX_PTR              EQU $C880+$A4   ; SFX data pointer (2 bytes)
SFX_ACTIVE           EQU $C880+$A6   ; SFX active flag (1 bytes)
SFX_BANK             EQU $C880+$A7   ; SFX bank ID (for multibank) (1 bytes)

;***************************************************************************
; MAIN PROGRAM
;***************************************************************************

MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    ; Init camera ONCE at boot (RAM not zero-init); LOAD_LEVEL must NOT reset it.
    LDD #0
    STD >CAMERA_X
    STD >CAMERA_Y
    LDA #$7F
    STA DRAW_SCALE        ; Default T1 scale = $7F (127 = full BIOS scale)
    LDD #0
    STD VAR_PLAYER_X
    LDD #-57
    STD VAR_PLAYER_Y
    LDD #0
    STD VAR_VEL_Y
    LDD #1
    STD VAR_ON_GROUND
    LDD #-57
    STD VAR_PREV_Y
    LDD #0
    STD VAR_CAMERA_X
    LDD #-57
    STD VAR_FLOOR_Y
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
; VPy_LINE:22
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'world_1_1'
    LDX #_WORLD_1_1_LEVEL          ; Pointer to level data in ROM
    JSR LOAD_LEVEL_RUNTIME
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
; VPy_LINE:26
; NATIVE_CALL: J1_X at line 26
    JSR J1X_BUILTIN
    STD RESULT
    STD VAR_JOY_X
; VPy_LINE:27
; NATIVE_CALL: J1_BUTTON_1 at line 27
    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed
    BITA #$01
    BNE .J1B1_0_ON
    LDD #0
    BRA .J1B1_0_END
.J1B1_0_ON:
    LDD #1
.J1B1_0_END:
    STD RESULT
    STD VAR_BTN_JUMP
; VPy_LINE:30
    LDD #20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBGT .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_1
; VPy_LINE:31
    LDD #3
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_PLAYER_X
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
; VPy_LINE:32
    LDD #-20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBLT .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    LBEQ IF_NEXT_3
; VPy_LINE:33
    LDD #3
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_PLAYER_X
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
; VPy_LINE:36
    ; CLAMP: Clamp value to range [min, max]
    LDD >VAR_PLAYER_X
    STD TMPPTR     ; Save value
    LDD #-100
    STD TMPPTR+2   ; Save min
    LDD #1050
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
; VPy_LINE:39
    LDD >VAR_BTN_JUMP
    CMPD #1
    LBNE IF_NEXT_5
; VPy_LINE:40
    LDB >VAR_ON_GROUND
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #1
    LBNE IF_NEXT_7
; VPy_LINE:41
    LDD #12
    STD VAR_VEL_Y
; VPy_LINE:42
    LDD #0
    STB VAR_ON_GROUND
; VPy_LINE:43
; NATIVE_CALL: PLAY_SFX at line 43
    ; PLAY_SFX("jump") - play SFX asset (index=0)
    LDX #_JUMP_SFX  ; Load SFX data pointer
    JSR PLAY_SFX_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
; VPy_LINE:46
    LDB >VAR_ON_GROUND
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #0
    LBNE IF_NEXT_9
; VPy_LINE:47
    LDD >VAR_PLAYER_Y
    STD VAR_PREV_Y
; VPy_LINE:48
    LDD >VAR_VEL_Y
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_PLAYER_Y
; VPy_LINE:49
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_VEL_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_VEL_Y
; VPy_LINE:53
; NATIVE_CALL: LEVEL_COLLISION_Y at line 53
    ; ===== LEVEL_COLLISION_Y builtin =====
    LDD >VAR_PLAYER_X
    STD >LCOL_PX         ; store player world_x (16-bit)
    LDD #13  ; const MARIO_HH
    STB >LCOL_PHH        ; store player half_height
    LDD >VAR_PREV_Y
    ; Compute player_feet = player_y - player_hh (16-bit)
    STD >TMPVAL          ; save player_y
    LDB >LCOL_PHH        ; B = player_hh
    CLRA
    STD >LCOL_PY         ; reuse as scratch (16-bit hh)
    LDD >TMPVAL          ; D = player_y
    SUBD >LCOL_PY        ; D = player_y - player_hh = player_feet
    STD >LCOL_PY         ; store player_feet Y (16-bit) for surface filter
    JSR LEVEL_COLLISION_Y_RUNTIME
    STD VAR_FLOOR_Y
; VPy_LINE:55
; NATIVE_CALL: MAX at line 55
    ; MAX: Return maximum of two values
    LDD >VAR_FLOOR_Y
    STD TMPPTR     ; Save first value
    LDD #-57
    STD TMPPTR2    ; Save second value
    LDD TMPPTR     ; Load first value
    CMPD TMPPTR2   ; Compare first vs second
    BGE .MAX_1_FIRST ; Branch if first >= second
    LDD TMPPTR2    ; Second is larger
    STD RESULT
    BRA .MAX_1_END
.MAX_1_FIRST:
    STD RESULT     ; First is larger (D still = first from LDD TMPPTR)
.MAX_1_END:
    STD VAR_FLOOR_Y
; VPy_LINE:58
    LDD >VAR_FLOOR_Y
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_Y
    CMPD TMPVAL
    LBLE .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    LBEQ IF_NEXT_11
; VPy_LINE:59
    LDD >VAR_FLOOR_Y
    STD VAR_PLAYER_Y
; VPy_LINE:60
    LDD #0
    STD VAR_VEL_Y
; VPy_LINE:61
    LDD #1
    STB VAR_ON_GROUND
    LBRA IF_END_10
IF_NEXT_11:
IF_END_10:
    LBRA IF_END_8
IF_NEXT_9:
IF_END_8:
; VPy_LINE:64
    LDB >VAR_ON_GROUND
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #1
    LBNE IF_NEXT_13
; VPy_LINE:65
; NATIVE_CALL: LEVEL_COLLISION_Y at line 65
    ; ===== LEVEL_COLLISION_Y builtin =====
    LDD >VAR_PLAYER_X
    STD >LCOL_PX         ; store player world_x (16-bit)
    LDD #13  ; const MARIO_HH
    STB >LCOL_PHH        ; store player half_height
    LDD >VAR_PLAYER_Y
    ; Compute player_feet = player_y - player_hh (16-bit)
    STD >TMPVAL          ; save player_y
    LDB >LCOL_PHH        ; B = player_hh
    CLRA
    STD >LCOL_PY         ; reuse as scratch (16-bit hh)
    LDD >TMPVAL          ; D = player_y
    SUBD >LCOL_PY        ; D = player_y - player_hh = player_feet
    STD >LCOL_PY         ; store player_feet Y (16-bit) for surface filter
    JSR LEVEL_COLLISION_Y_RUNTIME
    STD VAR_FLOOR_Y
; VPy_LINE:66
; NATIVE_CALL: MAX at line 66
    ; MAX: Return maximum of two values
    LDD >VAR_FLOOR_Y
    STD TMPPTR     ; Save first value
    LDD #-57
    STD TMPPTR2    ; Save second value
    LDD TMPPTR     ; Load first value
    CMPD TMPPTR2   ; Compare first vs second
    BGE .MAX_2_FIRST ; Branch if first >= second
    LDD TMPPTR2    ; Second is larger
    STD RESULT
    BRA .MAX_2_END
.MAX_2_FIRST:
    STD RESULT     ; First is larger (D still = first from LDD TMPPTR)
.MAX_2_END:
    STD VAR_FLOOR_Y
; VPy_LINE:67
    LDD >VAR_FLOOR_Y
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_Y
    CMPD TMPVAL
    LBGT .CMP_3_TRUE
    LDD #0
    LBRA .CMP_3_END
.CMP_3_TRUE:
    LDD #1
.CMP_3_END:
    LBEQ IF_NEXT_15
; VPy_LINE:68
    LDD #0
    STB VAR_ON_GROUND
    LBRA IF_END_14
IF_NEXT_15:
IF_END_14:
    LBRA IF_END_12
IF_NEXT_13:
IF_END_12:
; VPy_LINE:71
    LDD #30
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_CAMERA_X
; VPy_LINE:72
    ; CLAMP: Clamp value to range [min, max]
    LDD >VAR_CAMERA_X
    STD TMPPTR     ; Save value
    LDD #0
    STD TMPPTR+2   ; Save min
    LDD #970
    STD TMPPTR+4   ; Save max
    LDD TMPPTR     ; Load value
    CMPD TMPPTR+2  ; Compare with min
    BGE .CLAMP_3_CHK_MAX ; Branch if value >= min
    LDD TMPPTR+2
    STD RESULT
    BRA .CLAMP_3_END
.CLAMP_3_CHK_MAX:
    LDD TMPPTR     ; Load value again
    CMPD TMPPTR+4  ; Compare with max
    BLE .CLAMP_3_OK  ; Branch if value <= max
    LDD TMPPTR+4
    STD RESULT
    BRA .CLAMP_3_END
.CLAMP_3_OK:
    LDD TMPPTR
    STD RESULT
.CLAMP_3_END:
    STD VAR_CAMERA_X
; VPy_LINE:74
; NATIVE_CALL: SET_CAMERA_X at line 74
    ; ===== SET_CAMERA_X builtin =====
    LDD >VAR_CAMERA_X
    STD >CAMERA_X    ; Store 16-bit camera X scroll offset
    LDD #0
    STD RESULT
; VPy_LINE:75
    ; ===== SHOW_LEVEL builtin =====
    JSR SHOW_LEVEL_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:78
; NATIVE_CALL: DRAW_VECTOR at line 78
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: mario (index=2, 10 paths)
    LDD #-30
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_1          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_PLAYER_Y
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
    LDX #_MARIO_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MARIO_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MARIO_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MARIO_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MARIO_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MARIO_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MARIO_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MARIO_PATH7  ; Load path 7
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MARIO_PATH8  ; Load path 8
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MARIO_PATH9  ; Load path 9
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_1:
    LDD #0
    STD RESULT
; VPy_LINE:79
; NATIVE_CALL: DEBUG_PRINT at line 79
    LDD >VAR_FLOOR_Y
    ; DEBUG_PRINT(FLOOR_Y)
    STB $C000
    STA $C002
    LDX #DEBUG_LABEL_FLOOR_Y
    STX $C004
    LDA #$FE
    STA $C001
    BRA DEBUG_SKIP_0
DEBUG_LABEL_FLOOR_Y:
    FCC "FLOOR_Y"
    FCB $00
DEBUG_SKIP_0:
    LDD #0
    STD RESULT
; VPy_LINE:80
; NATIVE_CALL: DEBUG_PRINT at line 80
    LDD >VAR_PLAYER_Y
    ; DEBUG_PRINT(PLAYER_Y)
    STB $C000
    STA $C002
    LDX #DEBUG_LABEL_PLAYER_Y
    STX $C004
    LDA #$FE
    STA $C001
    BRA DEBUG_SKIP_1
DEBUG_LABEL_PLAYER_Y:
    FCC "PLAYER_Y"
    FCB $00
DEBUG_SKIP_1:
    LDD #0
    STD RESULT
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX
    RTS

;***************************************************************************
; EMBEDDED ASSETS (vectors, music, levels, SFX)
;***************************************************************************

; Generated from cloud.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 12
; X bounds: min=-25, max=25, width=50
; Center: (0, 0)

_CLOUD_WIDTH EQU 50
_CLOUD_HALF_WIDTH EQU 25
_CLOUD_HEIGHT EQU 20
_CLOUD_HALF_HEIGHT EQU 10
_CLOUD_CENTER_X EQU 0
_CLOUD_CENTER_Y EQU 0

_CLOUD_VECTORS:  ; Main entry (header + 1 path(s))
    FDB 1               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _CLOUD_PATH0        ; pointer to path 0

_CLOUD_PATH0:    ; Path 0
    FCB 55              ; path0: intensity
    FCB $F6,$E7,0,0        ; path0: header (y=-10, x=-25)
    FCB $FF,$00,$32          ; flag=-1, dy=0, dx=50
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$EC          ; flag=-1, dy=0, dx=-20
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)
; Generated from ground_tile.vec (Malban Draw_Sync_List format)
; Total paths: 7, points: 17
; X bounds: min=-30, max=30, width=60
; Center: (0, 0)

_GROUND_TILE_WIDTH EQU 60
_GROUND_TILE_HALF_WIDTH EQU 30
_GROUND_TILE_HEIGHT EQU 16
_GROUND_TILE_HALF_HEIGHT EQU 8
_GROUND_TILE_CENTER_X EQU 0
_GROUND_TILE_CENTER_Y EQU 0

_GROUND_TILE_VECTORS:  ; Main entry (header + 7 path(s))
    FDB 7               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _GROUND_TILE_PATH0        ; pointer to path 0
    FDB _GROUND_TILE_PATH1        ; pointer to path 1
    FDB _GROUND_TILE_PATH2        ; pointer to path 2
    FDB _GROUND_TILE_PATH3        ; pointer to path 3
    FDB _GROUND_TILE_PATH4        ; pointer to path 4
    FDB _GROUND_TILE_PATH5        ; pointer to path 5
    FDB _GROUND_TILE_PATH6        ; pointer to path 6

_GROUND_TILE_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $00,$02,0,0        ; path0: header (y=0, x=2)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB 2                ; End marker (path complete)

_GROUND_TILE_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $00,$0B,0,0        ; path1: header (y=0, x=11)
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_GROUND_TILE_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $00,$17,0,0        ; path2: header (y=0, x=23)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB 2                ; End marker (path complete)

_GROUND_TILE_PATH3:    ; Path 3
    FCB 60              ; path3: intensity
    FCB $00,$1E,0,0        ; path3: header (y=0, x=30)
    FCB $FF,$00,$C4          ; flag=-1, dy=0, dx=-60
    FCB 2                ; End marker (path complete)

_GROUND_TILE_PATH4:    ; Path 4
    FCB 80              ; path4: intensity
    FCB $F8,$E2,0,0        ; path4: header (y=-8, x=-30)
    FCB $FF,$00,$3C          ; flag=-1, dy=0, dx=60
    FCB $FF,$10,$00          ; flag=-1, dy=16, dx=0
    FCB $FF,$00,$C4          ; flag=-1, dy=0, dx=-60
    FCB $FF,$F0,$00          ; flag=-1, dy=-16, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_GROUND_TILE_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $00,$EC,0,0        ; path5: header (y=0, x=-20)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB 2                ; End marker (path complete)

_GROUND_TILE_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $00,$F7,0,0        ; path6: header (y=0, x=-9)
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)
; Generated from mario.vec (Malban Draw_Sync_List format)
; Total paths: 10, points: 26
; X bounds: min=-7, max=7, width=14
; Center: (0, 2)

_MARIO_WIDTH EQU 14
_MARIO_HALF_WIDTH EQU 7
_MARIO_HEIGHT EQU 26
_MARIO_HALF_HEIGHT EQU 13
_MARIO_CENTER_X EQU 0
_MARIO_CENTER_Y EQU 2

_MARIO_VECTORS:  ; Main entry (header + 10 path(s))
    FDB 10               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _MARIO_PATH0        ; pointer to path 0
    FDB _MARIO_PATH1        ; pointer to path 1
    FDB _MARIO_PATH2        ; pointer to path 2
    FDB _MARIO_PATH3        ; pointer to path 3
    FDB _MARIO_PATH4        ; pointer to path 4
    FDB _MARIO_PATH5        ; pointer to path 5
    FDB _MARIO_PATH6        ; pointer to path 6
    FDB _MARIO_PATH7        ; pointer to path 7
    FDB _MARIO_PATH8        ; pointer to path 8
    FDB _MARIO_PATH9        ; pointer to path 9

_MARIO_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $01,$FA,0,0        ; path0: header (y=1, x=-6)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$F4          ; flag=-1, dy=0, dx=-12
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MARIO_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $09,$F9,0,0        ; path1: header (y=9, x=-7)
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB 2                ; End marker (path complete)

_MARIO_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $09,$05,0,0        ; path2: header (y=9, x=5)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_MARIO_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $0D,$05,0,0        ; path3: header (y=13, x=5)
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_MARIO_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $0D,$FB,0,0        ; path4: header (y=13, x=-5)
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_MARIO_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $F9,$F9,0,0        ; path5: header (y=-7, x=-7)
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MARIO_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $F9,$F9,0,0        ; path6: header (y=-7, x=-7)
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_MARIO_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $F3,$F9,0,0        ; path7: header (y=-13, x=-7)
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB 2                ; End marker (path complete)

_MARIO_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $F3,$02,0,0        ; path8: header (y=-13, x=2)
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB 2                ; End marker (path complete)

_MARIO_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $F3,$07,0,0        ; path9: header (y=-13, x=7)
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)
; Generated from mountain.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 19
; X bounds: min=-30, max=30, width=60
; Center: (0, 0)

_MOUNTAIN_WIDTH EQU 60
_MOUNTAIN_HALF_WIDTH EQU 30
_MOUNTAIN_HEIGHT EQU 38
_MOUNTAIN_HALF_HEIGHT EQU 19
_MOUNTAIN_CENTER_X EQU 0
_MOUNTAIN_CENTER_Y EQU 0

_MOUNTAIN_VECTORS:  ; Main entry (header + 1 path(s))
    FDB 1               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _MOUNTAIN_PATH0        ; pointer to path 0

_MOUNTAIN_PATH0:    ; Path 0
    FCB 45              ; path0: intensity
    FCB $ED,$E2,0,0        ; path0: header (y=-19, x=-30)
    FCB $FF,$00,$3C          ; flag=-1, dy=0, dx=60
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$08,$FA          ; flag=-1, dy=8, dx=-6
    FCB $FF,$F8,$FA          ; flag=-1, dy=-8, dx=-6
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)
; Generated from pipe.vec (Malban Draw_Sync_List format)
; Total paths: 3, points: 9
; X bounds: min=-12, max=10, width=22
; Center: (-1, 0)

_PIPE_WIDTH EQU 22
_PIPE_HALF_WIDTH EQU 11
_PIPE_HEIGHT EQU 50
_PIPE_HALF_HEIGHT EQU 25
_PIPE_CENTER_X EQU -1
_PIPE_CENTER_Y EQU 0

_PIPE_VECTORS:  ; Main entry (header + 3 path(s))
    FDB 3               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PIPE_PATH0        ; pointer to path 0
    FDB _PIPE_PATH1        ; pointer to path 1
    FDB _PIPE_PATH2        ; pointer to path 2

_PIPE_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $14,$F5,0,0        ; path0: header (y=20, x=-11)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_PIPE_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $19,$F7,0,0        ; path1: header (y=25, x=-9)
    FCB $FF,$00,$14          ; flag=-1, dy=0, dx=20
    FCB 2                ; End marker (path complete)

_PIPE_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $E7,$F7,0,0        ; path2: header (y=-25, x=-9)
    FCB $FF,$00,$14          ; flag=-1, dy=0, dx=20
    FCB $FF,$32,$00          ; flag=-1, dy=50, dx=0
    FCB $FF,$00,$EC          ; flag=-1, dy=0, dx=-20
    FCB $FF,$CE,$00          ; flag=-1, dy=-50, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)
; Generated from question_block.vec (Malban Draw_Sync_List format)
; Total paths: 3, points: 11
; X bounds: min=-8, max=8, width=16
; Center: (0, 0)

_QUESTION_BLOCK_WIDTH EQU 16
_QUESTION_BLOCK_HALF_WIDTH EQU 8
_QUESTION_BLOCK_HEIGHT EQU 16
_QUESTION_BLOCK_HALF_HEIGHT EQU 8
_QUESTION_BLOCK_CENTER_X EQU 0
_QUESTION_BLOCK_CENTER_Y EQU 0

_QUESTION_BLOCK_VECTORS:  ; Main entry (header + 3 path(s))
    FDB 3               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _QUESTION_BLOCK_PATH0        ; pointer to path 0
    FDB _QUESTION_BLOCK_PATH1        ; pointer to path 1
    FDB _QUESTION_BLOCK_PATH2        ; pointer to path 2

_QUESTION_BLOCK_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $00,$00,0,0        ; path0: header (y=0, x=0)
    FCB $FF,$02,$04          ; flag=-1, dy=2, dx=4
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB 2                ; End marker (path complete)

_QUESTION_BLOCK_PATH1:    ; Path 1
    FCB 100              ; path1: intensity
    FCB $FC,$FF,0,0        ; path1: header (y=-4, x=-1)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB 2                ; End marker (path complete)

_QUESTION_BLOCK_PATH2:    ; Path 2
    FCB 120              ; path2: intensity
    FCB $F8,$F8,0,0        ; path2: header (y=-8, x=-8)
    FCB $FF,$00,$10          ; flag=-1, dy=0, dx=16
    FCB $FF,$10,$00          ; flag=-1, dy=16, dx=0
    FCB $FF,$00,$F0          ; flag=-1, dy=0, dx=-16
    FCB $FF,$F0,$00          ; flag=-1, dy=-16, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)
; ==== Level: WORLD_1_1 ====
; Author: 
; Difficulty: medium

_WORLD_1_1_LEVEL:
    FDB -96  ; World bounds: xMin (16-bit signed)
    FDB 1055  ; xMax (16-bit signed)
    FDB -128  ; yMin (16-bit signed)
    FDB 127  ; yMax (16-bit signed)
    FDB 0  ; Time limit (seconds)
    FDB 0  ; Target score
    FCB 22  ; Background object count
    FCB 10  ; Gameplay object count
    FCB 1  ; Foreground object count
    FDB _WORLD_1_1_BG_OBJECTS
    FDB _WORLD_1_1_GAMEPLAY_OBJECTS
    FDB _WORLD_1_1_FG_OBJECTS
    FDB 0  ; scrollLimit left (camera left cannot go below this)
    FDB 1020  ; scrollLimit right (camera right cannot exceed this)
    FDB 127  ; scrollLimit top
    FDB -128  ; scrollLimit bottom
    FCB 0  ; enemy_count
    FDB 0  ; enemy_instances_ptr (0 if none)
    FDB 42  ; groundBottomOffset (floor surface offset from screen bottom)
    FCB 1    ; +34 screen_count
    FDB _WORLD_1_1_BG_SCREENS  ; +35 BG screens index
    FDB _WORLD_1_1_GP_SCREENS  ; +37 GP screens index
    FDB _WORLD_1_1_FG_SCREENS  ; +39 FG screens index

_WORLD_1_1_BG_OBJECTS:
_WORLD_1_1_BG_OBJECTS_S0:
; Object: obj_bg_cloud_1 (decoration)
    FCB 255  ; type
    FDB 100  ; x
    FDB 30  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _CLOUD_VECTORS  ; vector_ptr (ROM+17)
    FCB 25  ; half_width (1.00x, ROM+19)
    FCB 10  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_bg_cloud_2 (decoration)
    FCB 255  ; type
    FDB 350  ; x
    FDB 45  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _CLOUD_VECTORS  ; vector_ptr (ROM+17)
    FCB 25  ; half_width (1.00x, ROM+19)
    FCB 10  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_bg_cloud_3 (decoration)
    FCB 255  ; type
    FDB 600  ; x
    FDB 20  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _CLOUD_VECTORS  ; vector_ptr (ROM+17)
    FCB 25  ; half_width (1.00x, ROM+19)
    FCB 10  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_bg_cloud_4 (decoration)
    FCB 255  ; type
    FDB 850  ; x
    FDB 38  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _CLOUD_VECTORS  ; vector_ptr (ROM+17)
    FCB 25  ; half_width (1.00x, ROM+19)
    FCB 10  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_bg_7 (tile)
    FCB 255  ; type
    FDB 245  ; x
    FDB -78  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _GROUND_TILE_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 8  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_bg_3 (tile)
    FCB 255  ; type
    FDB 59  ; x
    FDB -78  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _GROUND_TILE_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 8  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_bg_4 (tile)
    FCB 255  ; type
    FDB 121  ; x
    FDB -78  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _GROUND_TILE_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 8  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_bg_6 (tile)
    FCB 255  ; type
    FDB 183  ; x
    FDB -78  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _GROUND_TILE_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 8  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_bg_8 (tile)
    FCB 255  ; type
    FDB 307  ; x
    FDB -78  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _GROUND_TILE_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 8  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_bg_9 (tile)
    FCB 255  ; type
    FDB 369  ; x
    FDB -78  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _GROUND_TILE_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 8  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_bg_10 (tile)
    FCB 255  ; type
    FDB 431  ; x
    FDB -78  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _GROUND_TILE_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 8  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_bg_11 (tile)
    FCB 255  ; type
    FDB 493  ; x
    FDB -78  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _GROUND_TILE_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 8  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_bg_12 (tile)
    FCB 255  ; type
    FDB 555  ; x
    FDB -78  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _GROUND_TILE_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 8  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_bg_13 (tile)
    FCB 255  ; type
    FDB 617  ; x
    FDB -78  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _GROUND_TILE_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 8  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_bg_14 (tile)
    FCB 255  ; type
    FDB 679  ; x
    FDB -78  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _GROUND_TILE_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 8  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_bg_15 (tile)
    FCB 255  ; type
    FDB 741  ; x
    FDB -78  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _GROUND_TILE_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 8  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_bg_16 (tile)
    FCB 255  ; type
    FDB 803  ; x
    FDB -78  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _GROUND_TILE_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 8  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_bg_17 (tile)
    FCB 255  ; type
    FDB 865  ; x
    FDB -78  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _GROUND_TILE_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 8  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_bg_18 (tile)
    FCB 255  ; type
    FDB 927  ; x
    FDB -78  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _GROUND_TILE_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 8  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_bg_19 (tile)
    FCB 255  ; type
    FDB 989  ; x
    FDB -78  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _GROUND_TILE_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 8  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_bg_1 (tile)
    FCB 255  ; type
    FDB -65  ; x
    FDB -78  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _GROUND_TILE_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 8  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_bg_2 (tile)
    FCB 255  ; type
    FDB -3  ; x
    FDB -78  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _GROUND_TILE_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 8  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)


_WORLD_1_1_GAMEPLAY_OBJECTS:
_WORLD_1_1_GAMEPLAY_OBJECTS_S0:
; Object: obj_bg_mountain_2 (decoration)
    FCB 255  ; type
    FDB 570  ; x
    FDB -50  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _MOUNTAIN_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 19  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_bg_mountain_3 (decoration)
    FCB 255  ; type
    FDB 750  ; x
    FDB -49  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _MOUNTAIN_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 19  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_1773216572040 (enemy)
    FCB 1  ; type
    FDB 270  ; x
    FDB -50  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _MOUNTAIN_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 19  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_gp_pipe_1 (obstacle)
    FCB 2  ; type
    FDB 200  ; x
    FDB -43  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _PIPE_VECTORS  ; vector_ptr (ROM+17)
    FCB 11  ; half_width (1.00x, ROM+19)
    FCB 25  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_gp_pipe_2 (obstacle)
    FCB 2  ; type
    FDB 420  ; x
    FDB -45  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _PIPE_VECTORS  ; vector_ptr (ROM+17)
    FCB 11  ; half_width (1.00x, ROM+19)
    FCB 25  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_gp_pipe_3 (obstacle)
    FCB 2  ; type
    FDB 680  ; x
    FDB -44  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _PIPE_VECTORS  ; vector_ptr (ROM+17)
    FCB 11  ; half_width (1.00x, ROM+19)
    FCB 25  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_gp_pipe_4 (obstacle)
    FCB 2  ; type
    FDB 850  ; x
    FDB -44  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _PIPE_VECTORS  ; vector_ptr (ROM+17)
    FCB 11  ; half_width (1.00x, ROM+19)
    FCB 25  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_gp_qblock_2 (item)
    FCB 255  ; type
    FDB 260  ; x
    FDB -10  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _QUESTION_BLOCK_VECTORS  ; vector_ptr (ROM+17)
    FCB 8  ; half_width (1.00x, ROM+19)
    FCB 8  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_gp_qblock_3 (item)
    FCB 255  ; type
    FDB 500  ; x
    FDB -10  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _QUESTION_BLOCK_VECTORS  ; vector_ptr (ROM+17)
    FCB 8  ; half_width (1.00x, ROM+19)
    FCB 8  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_gp_qblock_4 (item)
    FCB 255  ; type
    FDB 760  ; x
    FDB -10  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _QUESTION_BLOCK_VECTORS  ; vector_ptr (ROM+17)
    FCB 8  ; half_width (1.00x, ROM+19)
    FCB 8  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)


_WORLD_1_1_FG_OBJECTS:
_WORLD_1_1_FG_OBJECTS_S0:
; Object: obj_gp_qblock_1 (item)
    FCB 255  ; type
    FDB 130  ; x
    FDB -10  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _QUESTION_BLOCK_VECTORS  ; vector_ptr (ROM+17)
    FCB 8  ; half_width (1.00x, ROM+19)
    FCB 8  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)


_WORLD_1_1_BG_SCREENS:
    FCB 22  ; screen 0 count
    FDB _WORLD_1_1_BG_OBJECTS_S0  ; screen 0 ptr

_WORLD_1_1_GP_SCREENS:
    FCB 10  ; screen 0 count
    FDB _WORLD_1_1_GAMEPLAY_OBJECTS_S0  ; screen 0 ptr

_WORLD_1_1_FG_SCREENS:
    FCB 1  ; screen 0 count
    FDB _WORLD_1_1_FG_OBJECTS_S0  ; screen 0 ptr

_WORLD_1_1_ENEMY_COUNT EQU 0

_JUMP_SFX:
    ; SFX: jump (jump)
    ; Duration: 250ms (12fr), Freq: 440Hz, Channel: 0
    FCB $AF         ; Frame 0 - flags (vol=15, noisevol=0, tone=Y, noise=N)
    FCB $01, $0B  ; Tone period = 267 (big-endian)
    FCB $AE         ; Frame 1 - flags (vol=14, noisevol=0, tone=Y, noise=N)
    FCB $00, $E8  ; Tone period = 232 (big-endian)
    FCB $AD         ; Frame 2 - flags (vol=13, noisevol=0, tone=Y, noise=N)
    FCB $00, $CD  ; Tone period = 205 (big-endian)
    FCB $AB         ; Frame 3 - flags (vol=11, noisevol=0, tone=Y, noise=N)
    FCB $00, $B8  ; Tone period = 184 (big-endian)
    FCB $AA         ; Frame 4 - flags (vol=10, noisevol=0, tone=Y, noise=N)
    FCB $00, $A6  ; Tone period = 166 (big-endian)
    FCB $A9         ; Frame 5 - flags (vol=9, noisevol=0, tone=Y, noise=N)
    FCB $00, $98  ; Tone period = 152 (big-endian)
    FCB $A7         ; Frame 6 - flags (vol=7, noisevol=0, tone=Y, noise=N)
    FCB $00, $8C  ; Tone period = 140 (big-endian)
    FCB $A6         ; Frame 7 - flags (vol=6, noisevol=0, tone=Y, noise=N)
    FCB $00, $82  ; Tone period = 130 (big-endian)
    FCB $A5         ; Frame 8 - flags (vol=5, noisevol=0, tone=Y, noise=N)
    FCB $00, $79  ; Tone period = 121 (big-endian)
    FCB $A3         ; Frame 9 - flags (vol=3, noisevol=0, tone=Y, noise=N)
    FCB $00, $71  ; Tone period = 113 (big-endian)
    FCB $A2         ; Frame 10 - flags (vol=2, noisevol=0, tone=Y, noise=N)
    FCB $00, $6A  ; Tone period = 106 (big-endian)
    FCB $A0         ; Frame 11 - flags (vol=0, noisevol=0, tone=Y, noise=N)
    FCB $00, $64  ; Tone period = 100 (big-endian)
    FCB $D0, $20    ; End of effect marker

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
; === LOAD_LEVEL_RUNTIME ===
; Load level data from ROM and copy GP objects to RAM buffer
; Input:  X = pointer to level data in ROM
; Output: LEVEL_PTR = level header pointer
;         RESULT    = level header pointer (return value)
; BG and FG layers are static — read from ROM directly.
; GP layer is copied to LEVEL_GP_BUFFER (14 bytes/object).
LOAD_LEVEL_RUNTIME:
    PSHS D,X,Y,U     ; Preserve registers
    
    ; Store level pointer and mark as loaded
    STX >LEVEL_PTR
    LDA #1
    STA >LEVEL_LOADED    ; Mark level as loaded
    
    ; Camera is NOT reset here (matches pitrex/rp2350). It is initialised once
    ; at boot in MAIN; the game sets it via SET_CAMERA_Y before LOAD_LEVEL, and
    ; GET_LEVEL_FLOOR_Y / the SPAWN_ENEMIES Y-filter read it after this call.
    
    ; Skip world bounds (8 bytes) + time/score (4 bytes)
    LEAX 12,X        ; X now points to object counts (+12)
    
    ; Read object counts (one byte each)
    LDB ,X+          ; B = bgCount
    STB >LEVEL_BG_COUNT
    LDB ,X+          ; B = gpCount
    STB >LEVEL_GP_COUNT
    LDB ,X+          ; B = fgCount
    STB >LEVEL_FG_COUNT
    
    ; Read layer ROM pointers (FDB, 2 bytes each)
    LDD ,X++         ; D = bgObjectsPtr
    STD >LEVEL_BG_ROM_PTR
    LDD ,X++         ; D = gpObjectsPtr
    STD >LEVEL_GP_ROM_PTR
    LDD ,X++         ; D = fgObjectsPtr
    STD >LEVEL_FG_ROM_PTR
    
    ; Read scroll limits from ROM header (+21..+28)
    ; X is now at +21 (right after the 3 FDB layer pointers)
    LDD ,X++         ; D = scrollLimit left
    STD >SCROLL_LIMIT_LEFT
    LDD ,X++         ; D = scrollLimit right
    STD >SCROLL_LIMIT_RIGHT
    LDD ,X++         ; D = scrollLimit top
    STD >SCROLL_LIMIT_TOP
    LDD ,X++         ; D = scrollLimit bottom
    STD >SCROLL_LIMIT_BOTTOM
    
    ; Read enemy data from header (+29: count, +30,+31: instances_ptr)
    LDB ,X+         ; B = enemy_count
    STB >LEVEL_ENEMY_COUNT
    LDD ,X++        ; D = enemy_instances_ptr (advance past +30..+31)
    STD >LEVEL_ENEMY_INSTANCES_PTR
    LEAX 2,X        ; skip groundBottomOffset (+32..+33)
    
    ; Per-screen object index (+34..+40)
    LDB ,X+         ; B = screen_count
    STB >LEVEL_SCREEN_COUNT
    LDD ,X++        ; D = bg_screens_ptr
    STD >LEVEL_BG_SCREENS_PTR
    LDD ,X++        ; D = gp_screens_ptr
    STD >LEVEL_GP_SCREENS_PTR
    LDD ,X          ; D = fg_screens_ptr
    STD >LEVEL_FG_SCREENS_PTR
    
    ; === Setup GP pointer: point directly to ROM (matches core) ===
    ; GP objects are read from ROM with stride=21 (stride-21 format), same as BG/FG
    LDB >LEVEL_GP_COUNT
    BEQ LLR_SKIP_GP  ; Skip if no GP objects
    LDD >LEVEL_GP_ROM_PTR ; Just point to ROM
    STD >LEVEL_GP_PTR    ; Store ROM pointer
    
LLR_GP_DONE:
LLR_SKIP_GP:
    
    ; Return level pointer in RESULT
    LDX >LEVEL_PTR
    STX RESULT
    
    PULS D,X,Y,U,PC  ; Restore and return
    
; === LLR_COPY_OBJECTS - LEGACY (not called; GP objects read from ROM directly)
; Input:  B = count, X = source (ROM, 21 bytes/obj stride-21), U = dest (RAM)
; ROM object layout (21 bytes, stride-21):
;   +0: type, +1-2: x(FDB), +3-4: y(FDB), +5-6: scale(FDB),
;   +7: rotation, +8: intensity, +9: velocity_x, +10: velocity_y,
;   +11: physics_flags, +12: collision_flags, +13: collision_size,
;   +14-15: spawn_delay(FDB), +16: vector_bank(FCB), +17-18: vector_ptr(FDB),
;   +19: half_width, +20: half_height
; RAM object layout (15 bytes):
;   +0-1: world_x(FDB i16), +2: y(i8), +3: scale(low), +4: rotation,
;   +5: velocity_x, +6: velocity_y, +7: physics_flags, +8: collision_flags,
;   +9: collision_size, +10: spawn_delay(low), +11-12: vector_ptr, +13: half_width, +14: half_height
; Clobbers: A, B, X, U
LLR_COPY_OBJECTS:
LLR_COPY_LOOP:
    TSTB
    BEQ LLR_COPY_DONE
    PSHS B           ; Save counter (LDD will clobber B)
    
    ; X points to ROM object start (+0 = type)
    LEAX 1,X         ; Skip type (+0), X now at +1 (x FDB high)
    
    ; RAM +0-1: world_x FDB (16-bit, ROM +1-2)
    LDA ,X           ; ROM +1 = high byte of x FDB
    STA ,U+
    LDA 1,X          ; ROM +2 = low byte of x FDB
    STA ,U+
    ; RAM +2: y low byte (ROM +4, low byte of y FDB)
    LDA 3,X          ; ROM +4 = low byte of y FDB
    STA ,U+
    ; RAM +3: scale low byte (ROM +6, low byte of scale FDB)
    LDA 5,X          ; ROM +6 = low byte of scale FDB
    STA ,U+
    ; RAM +4: rotation (ROM +7)
    LDA 6,X          ; ROM +7 = rotation
    STA ,U+
    ; Skip to ROM +9 (past intensity at ROM +8)
    LEAX 8,X         ; X now points to ROM +9 (velocity_x)
    ; RAM +5: velocity_x (ROM +9)
    LDA ,X+          ; ROM +9
    STA ,U+
    ; RAM +6: velocity_y (ROM +10)
    LDA ,X+          ; ROM +10
    STA ,U+
    ; RAM +7: physics_flags (ROM +11)
    LDA ,X+          ; ROM +11
    STA ,U+
    ; RAM +8: collision_flags (ROM +12)
    LDA ,X+          ; ROM +12
    STA ,U+
    ; RAM +9: collision_size (ROM +13)
    LDA ,X+          ; ROM +13
    STA ,U+
    ; RAM +10: spawn_delay low byte (ROM +15, skip high at ROM +14)
    LDA 1,X          ; ROM +15 = low byte of spawn_delay FDB
    STA ,U+
    LEAX 3,X         ; Skip spawn_delay FDB (2 bytes) + vector_bank (1), X now at ROM+17
    ; RAM +11-12: vector_ptr FDB (ROM +17-18, stride-21)
    LDD ,X++         ; ROM +17-18 = vector_ptr FDB
    STD ,U++
    ; RAM +13-14: half_width + half_height (ROM +19-20, stride-21)
    LDD ,X++         ; ROM +19-20
    STD ,U++
    ; X is now past end of this ROM object (ROM+1 + 8 + 5 + 3 + 2 + 2 = +21 total)
    ; NOTE: We started at ROM+1 (after LEAX 1,X), walked:
    ;   ,X and 1,X and 3,X and 5,X and 6,X via indexed → X unchanged
    ;   then LEAX 8,X (X now at ROM+9)
    ;   then 5 post-increment ,X+ → X at ROM+14
    ;   then LEAX 3,X (X at ROM+17)
    ;   then 2x LDD ,X++ → X at ROM+21
    ;   ROM+21 from original ROM+0 = next object start (stride-21)
    
    PULS B           ; Restore counter
    DECB
    BRA LLR_COPY_LOOP
LLR_COPY_DONE:
    RTS

; === SHOW_LEVEL_RUNTIME ===
; Draw all level objects from all layers
; Input:  LEVEL_PTR = pointer to level header
; Layers: BG (ROM stride 21), GP (ROM stride 21), FG (ROM stride 21)
; ROM object layout (21 bytes, stride-21):
;   +0: type, +1-2: x(FDB), +3-4: y(FDB), +5-6: scale(FDB),
;   +7: rotation, +8: intensity, +9: velocity_x, +10: velocity_y,
;   +11: physics_flags, +12: collision_flags, +13: collision_size,
;   +14-15: spawn_delay(FDB), +16: vector_bank(FCB, $FF=null),
;   +17-18: vector_ptr(FDB), +19: half_width(FCB), +20: half_height(FCB)
; Each object: load intensity, x, y, vector_bank, vector_ptr, call SLR_DRAW_OBJECTS
SHOW_LEVEL_RUNTIME:
    PSHS D,X,Y,U     ; Preserve registers
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    
    ; Check if level is loaded
    TST >LEVEL_LOADED
    BEQ SLR_DONE     ; No level loaded, skip
    LDX >LEVEL_PTR
    
    ; Re-read object counts from header (legacy: kept for any caller that reads RAM vars)
    LEAX 12,X        ; X points to counts (+12)
    LDB ,X+          ; B = bgCount
    STB >LEVEL_BG_COUNT
    LDB ,X+          ; B = gpCount
    STB >LEVEL_GP_COUNT
    LDB ,X+          ; B = fgCount
    STB >LEVEL_FG_COUNT
    
    ; ── PER-SCREEN VISIBLE RANGE ─────────────────────────────────────
    ; Compute top_screen, bot_screen — only iterate objects whose screen
    ; band overlaps the camera's ±128 Y window. For SnowBros (1 screen
    ; visible) this is normally 1 screen, occasionally 2 during scroll.
    LDX >LEVEL_PTR
    LDD 6,X          ; D = yMax
    STD >TMPPTR      ; cache yMax
    LDD >CAMERA_Y
    ADDD #128        ; D = top_y (camera_y + 128, higher Y = top of screen)
    PSHS D
    LDD >TMPPTR      ; yMax
    SUBD ,S++        ; D = yMax - top_y
    TSTA             ; sign byte
    BPL SLR_TOP_OK   ; positive → A is the screen idx (D / 256)
    CLRA             ; negative → clamp top_screen to 0
SLR_TOP_OK:
    STA >SLR_TOP_SCREEN  ; top_screen (separate from TMPVAL — survives per-object cull)
    LDD >CAMERA_Y
    SUBD #128        ; D = bot_y (camera_y - 128)
    PSHS D
    LDD >TMPPTR      ; yMax
    SUBD ,S++        ; D = yMax - bot_y
    TSTA
    BPL SLR_BOT_OK
    CLRA
SLR_BOT_OK:
    ; Clamp bot_screen to (LEVEL_SCREEN_COUNT - 1) max
    LDB >LEVEL_SCREEN_COUNT
    LBEQ SLR_DONE    ; no screens → nothing to draw
    DECB             ; B = max_idx = screen_count - 1
    STB >SLR_BOT_SCREEN  ; stash max_idx for compare
    CMPA >SLR_BOT_SCREEN ; A (bot_screen) vs max_idx
    BLS SLR_BOT_NOCLAMP
    LDA >SLR_BOT_SCREEN  ; clamp bot_screen = max_idx
SLR_BOT_NOCLAMP:
    STA >SLR_BOT_SCREEN  ; bot_screen
    
    ; === Draw Background Layer ===
SLR_BG_LAYER:
    LDD >LEVEL_BG_SCREENS_PTR
    STD >TMPPTR      ; TMPPTR = table base for this layer
    JSR SLR_DRAW_SCREEN_RANGE
    
    ; === Draw Gameplay Layer ===
SLR_GAMEPLAY:
    LDD >LEVEL_GP_SCREENS_PTR
    STD >TMPPTR
    JSR SLR_DRAW_SCREEN_RANGE
    
    ; === Draw Foreground Layer ===
SLR_FOREGROUND:
    LDD >LEVEL_FG_SCREENS_PTR
    STD >TMPPTR
    JSR SLR_DRAW_SCREEN_RANGE
    
SLR_DONE:
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    PULS D,X,Y,U,PC  ; Restore and return
    
; === SLR_DRAW_SCREEN_RANGE — iterate screens in visible camera range ===
SLR_DRAW_SCREEN_RANGE:
    LDA >SLR_TOP_SCREEN  ; A = current screen idx (start at top)
SLR_SR_LOOP:
    CMPA >SLR_BOT_SCREEN
    BHI SLR_SR_DONE      ; current > bot → finished
    CMPA >LEVEL_SCREEN_COUNT
    BHS SLR_SR_DONE      ; defensive: don't index past table
    ; Compute &table[s] = TMPPTR + s*3
    PSHS A               ; save loop var
    LDB #3
    MUL                  ; D = s*3 (A=0 since s < 256/3, B = offset)
    LDX >TMPPTR          ; X = screens table base
    LEAX D,X             ; X = &table[s]
    LDB ,X               ; B = count for this screen
    BEQ SLR_SR_NEXT      ; empty screen → skip
    LDX 1,X              ; X = ptr to first object in this screen
    LDA #23              ; ROM object stride
    JSR SLR_DRAW_OBJECTS
SLR_SR_NEXT:
    PULS A
    INCA
    BRA SLR_SR_LOOP
SLR_SR_DONE:
    RTS
    
; === SLR_DRAW_OBJECTS - Draw N objects from a layer ===
; Input:  A = stride (21=ROM), B = count, X = objects ptr
; For ROM objects (stride=21, stride-21 format):
;   intensity at +8, y FDB at +3, x FDB at +1, half_width at +19
;   vector_bank at +16 ($FF=null), vector_ptr FDB at +17
; Camera: SUBD >CAMERA_X applied to world_x; objects outside i8 range are culled
SLR_DRAW_OBJECTS:
    PSHS A           ; Save stride on stack (A=stride)
SLR_OBJ_LOOP:
    TSTB
    LBEQ SLR_OBJ_DONE
    
    PSHS B           ; Save counter (LDD clobbers B)
    
    ; All layers use stride-21 ROM format — fall straight through
    
SLR_ROM_OFFSETS:
    ; === ROM object (stride=21, stride-21 format) ===
    ; Skip enemy spawn markers (type==1): drawn by DRAW_ENEMIES, not SHOW_LEVEL
    LDA ,X           ; type byte at ROM+0
    CMPA #1
    LBEQ SLR_OBJ_NEXT ; enemy marker: skip, handle via DRAW_ENEMIES
    CLR >MIRROR_X    ; DP=$D0, must use extended addressing
    CLR >MIRROR_Y
    LDA 8,X          ; intensity at ROM +8
    STA >DRAW_VEC_INTENSITY
    ; Apply CAMERA_Y: load world_y FDB at ROM +3, subtract CAMERA_Y, cull
    LDD 3,X          ; world_y FDB at ROM +3 (16-bit signed)
    SUBD >CAMERA_Y   ; screen_y = world_y - camera_y
    TSTA
    BEQ SLR_ROM_Y_ZERO
    INCA
    LBNE SLR_OBJ_NEXT    ; A not $FF: too far above
    ; A=$FF: visible if B >= 128 (i.e. >= -128 signed)
    CMPB #128
    BHS SLR_ROM_Y_VISIBLE
    LBRA SLR_OBJ_NEXT
SLR_ROM_Y_ZERO:
    ; A=0: visible if B <= 127
    CMPB #127
    BLS SLR_ROM_Y_VISIBLE
    LBRA SLR_OBJ_NEXT
SLR_ROM_Y_VISIBLE:
    STB >DRAW_VEC_Y  ; DP=$D0, must use extended addressing
    ; Load world_x (16-bit), subtract CAMERA_X, check visibility
    LDD 1,X          ; x FDB at ROM +1
    SUBD >CAMERA_X   ; screen_x = world_x - camera_x
    STD >TMPVAL
    ; Wide cull at ±(127+hw): partial-edge objects still render via SDCP.
    LDB 19,X         ; B = half_width (ROM+19)
    STB >TMPPTR2     ; save hw
    LDA #127
    ADDA >TMPPTR2    ; A = 127 + hw (right boundary)
    STA >TMPPTR
    LDA #128
    SUBA >TMPPTR2    ; A = 128 - hw (left boundary)
    STA >TMPPTR+1
    LDD >TMPVAL
    TSTA
    BEQ SLR_ROM_A_ZERO
    INCA
    LBNE SLR_OBJ_NEXT
    CMPB >TMPPTR+1
    BHS SLR_ROM_VISIBLE
    LBRA SLR_OBJ_NEXT
SLR_ROM_A_ZERO:
    CMPB >TMPPTR
    BLS SLR_ROM_VISIBLE
    LBRA SLR_OBJ_NEXT
SLR_ROM_VISIBLE:
    LDD >TMPVAL      ; reload full 16-bit screen_x (INCA corrupted A)
    STD >DRAW_VEC_X_HI ; store full 16-bit screen_x (A=hi, B=lo)
    ; Stride-21: vector_bank at ROM+16 ($FF=null), vector_ptr FDB at ROM+17
    ; CRITICAL: read ALL level-bank data BEFORE switching to vector bank.
    LDA 16,X         ; A = vector_bank (LEVEL BANK ACTIVE)
    CMPA #$FF        ; $FF = null (no visual for this object)
    LBEQ SLR_OBJ_NEXT ; null bank → skip draw
    LDU 17,X         ; vector_ptr FDB at ROM+17 (STILL IN LEVEL BANK)
    LDA 6,X          ; scale_t1 at ROM+6 (STILL IN LEVEL BANK)
    STA >DRAW_T1_SCALED
    
SLR_DRAW_VECTOR:
    PSHS X           ; Save object pointer
    TFR U,X          ; X = vector data pointer (header)
    
    ; Read path_count from vector header (FDB = 2 bytes, high byte ignored)
    LDD ,X++         ; D = path_count FDB; B = low byte = actual count, X now at pointer table
    
    ; DP is already $D0 (set by SHOW_LEVEL_RUNTIME at entry)
SLR_PATH_LOOP:
    TSTB
    BEQ SLR_PATH_DONE
    DECB
    PSHS B           ; Save decremented count
    LDU ,X++         ; U = path pointer, X advances to next entry
    PSHS X           ; Save pointer table position
    TFR U,X          ; X = actual path data
    LDA >DRAW_VEC_X_HI
    BEQ SLR_PATH_CHECK_POS
    INCA
    BNE SLR_PATH_USE_SDCP
    LDA >DRAW_VEC_X
    CMPA #$B0
    BHS SLR_PATH_USE_DSWM
    BRA SLR_PATH_USE_SDCP
SLR_PATH_CHECK_POS:
    LDA >DRAW_VEC_X
    CMPA #80
    BLS SLR_PATH_USE_DSWM
SLR_PATH_USE_SDCP:
    JSR SLR_DRAW_CLIPPED_PATH
    BRA SLR_PATH_AFTER
SLR_PATH_USE_DSWM:
    JSR Draw_Sync_List_At_With_Mirrors
SLR_PATH_AFTER:
    PULS X           ; Restore pointer table position
    PULS B           ; Restore count
    BRA SLR_PATH_LOOP
    
SLR_PATH_DONE:
    PULS X           ; Restore object pointer
    
SLR_OBJ_NEXT:
    ; Advance to next object using stride
    ; Reached here after draw (X restored by PULS X above) OR from
    ; visibility skip (X never pushed, still points to current object)
    ; Stack state in both cases: B on top, A=stride below
    LDA 1,S          ; Load stride from stack (+1 because B is on top)
    LEAX A,X         ; X += stride
    
    PULS B           ; Restore counter
    DECB
    LBRA SLR_OBJ_LOOP
    
SLR_OBJ_DONE:
    PULS A           ; Clean up stride from stack
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

; === LEVEL_COLLISION_Y_RUNTIME ===
; Find the highest collidable floor Y at player_x in the GP layer.
; Input:  LCOL_PX (16-bit) = player world_x
;         LCOL_PY (16-bit) = player_feet (player_y - player_hh)
; Output: RESULT = highest floor landing Y (i16)
;         Returns $FF80 (-128) if no collidable surface found at that X.
; Algorithm: for each collidable GP object, check X AABB overlap,
;   compute surface_top = obj_y(16) + half_height, track max (16-bit).
; ROM object offsets (stride-21): +0=type, +1-2=x(FDB), +3-4=y(FDB), +12=collision_flags,
;   +16=vector_bank, +17-18=vector_ptr, +19=half_width, +20=half_height. Stride=21.
LEVEL_COLLISION_Y_RUNTIME:
    PSHS X,Y,U       ; Save regs (NOT D - result returns in D)
    
    ; Initialize best_floor = -32768 ($8000, no floor found)
    LDD #$8000
    STD >LCOL_BEST_Y
    
    ; Check level loaded
    TST >LEVEL_LOADED
    LBEQ LCOL_Y_DONE
    
    LDB >LEVEL_GP_COUNT
    LBEQ LCOL_Y_DONE
    STB >LCOL_OBJ_CNT  ; GP objects remaining
    LDX >LEVEL_GP_PTR  ; X = ROM GP objects
    
LCOL_Y_LOOP:
    ; --- collision flag (bit 0 at ROM+12) ---
    LDA 12,X
    BITA #$01
    LBEQ LCOL_Y_NEXT  ; not collidable
    ; --- broadphase X: obj_x - hw <= player_x <= obj_x + hw ---
    LDD 1,X          ; obj_x FDB (ROM+1)
    SUBB 19,X        ; - half_width (ROM+19)
    SBCA #0
    STD >TMPVAL      ; left_edge
    LDD >LCOL_PX
    CMPD >TMPVAL
    LBLT LCOL_Y_NEXT ; player_x < left_edge
    LDD 1,X
    ADDB 19,X        ; + half_width
    ADCA #0
    STD >TMPVAL      ; right_edge
    LDD >LCOL_PX
    CMPD >TMPVAL
    LBGT LCOL_Y_NEXT ; player_x > right_edge
    
    ; --- X overlaps. Ray-cast mesh if coll_mesh_ptr(ROM+21) != 0, else AABB ---
    LDD 21,X         ; coll_mesh_ptr
    LBEQ LCOL_Y_AABB
    PSHS X           ; preserve object ptr across the segment walk
    LDD >LCOL_PX
    SUBD 1,X         ; local_px = player_x - obj_x
    STD >LCOL_LOCAL_PX
    LDD 3,X          ; obj world_y (ROM+3)
    STD >LCOL_OBJ_Y
    LDY 21,X         ; Y = mesh data ptr (level bank)
    LDB 1,Y          ; floor_count low byte (FDB at mesh+0)
    STB >LCOL_SEG_CNT
    LEAY 2,Y         ; Y -> first floor segment
LCOL_Y_SEG:
    LDB >LCOL_SEG_CNT
    BEQ LCOL_Y_SEG_DONE
    ; floor segment: x1=,Y y1=2,Y x2=4,Y (y2=6,Y unused; y1==y2)
    LDD >LCOL_LOCAL_PX
    CMPD ,Y          ; local_px vs x1
    BLT LCOL_Y_SEG_ADV ; local_px < x1 → off this segment
    LDD >LCOL_LOCAL_PX
    CMPD 4,Y         ; local_px vs x2
    BGT LCOL_Y_SEG_ADV ; local_px > x2 → off this segment
    LDD 2,Y          ; y1 (local)
    ADDD >LCOL_OBJ_Y ; world_seg_y = y1 + obj_world_y
    CMPD >LCOL_PY    ; vs player_feet
    BGT LCOL_Y_SEG_ADV ; above feet → skip
    CMPD >LCOL_BEST_Y
    BLE LCOL_Y_SEG_ADV ; not higher than best
    STD >LCOL_BEST_Y ; new best floor top
LCOL_Y_SEG_ADV:
    LEAY 8,Y         ; next floor segment (4 FDB)
    DEC >LCOL_SEG_CNT
    BRA LCOL_Y_SEG
LCOL_Y_SEG_DONE:
    PULS X           ; restore object ptr
    BRA LCOL_Y_NEXT
    
LCOL_Y_AABB:
    ; AABB fallback: surface_top = obj_y(ROM+3) + half_height(ROM+20)
    LDD 3,X
    ADDB 20,X
    ADCA #0
    CMPD >LCOL_PY    ; vs player_feet
    BGT LCOL_Y_NEXT  ; above feet → skip
    CMPD >LCOL_BEST_Y
    BLE LCOL_Y_NEXT  ; not higher
    STD >LCOL_BEST_Y
    
LCOL_Y_NEXT:
    LEAX 23,X        ; next ROM object (stride 23)
    DEC >LCOL_OBJ_CNT
    LBNE LCOL_Y_LOOP
    
LCOL_Y_DONE:
    ; best holds floor_top (16-bit). Landing Y = floor_top + player_hh.
    LDD >LCOL_BEST_Y
    CMPD #$8000
    BEQ LCOL_Y_NOFLOOR
    ADDB >LCOL_PHH   ; + player_hh
    ADCA #0
    BRA LCOL_Y_RET
LCOL_Y_NOFLOOR:
    LDD #$FF80       ; -128 (no floor found)
LCOL_Y_RET:
    STD RESULT
    
    PULS X,Y,U,PC    ; Restore (NOT D - result stays in D)

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
PRINT_TEXT_STR_3273774:
    FCC "jump"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_103666436:
    FCC "mario"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_104652296222070:
    FCC "world_1_1"
    FCB $80          ; Vectrex string terminator

