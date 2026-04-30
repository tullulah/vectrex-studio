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
SLR_CUR_X            EQU $C880+$59   ; SHOW_LEVEL: tracked beam X for per-segment clipping (1 bytes)
LEVEL_GP_BUFFER      EQU $C880+$5A   ; GP objects RAM buffer (max 32 objects × 15 bytes) (480 bytes)
LCOL_PX              EQU $C880+$23A   ; LEVEL_COLLISION player world_x input (16-bit) (2 bytes)
LCOL_BEST_Y          EQU $C880+$23C   ; LEVEL_COLLISION_Y best floor y found (signed byte) (1 bytes)
LCOL_PY              EQU $C880+$23D   ; LEVEL_COLLISION player_y (lo byte) (1 bytes)
LCOL_PHH             EQU $C880+$23E   ; LEVEL_COLLISION player half_height (1 bytes)
LCOL_PHW             EQU $C880+$23F   ; LEVEL_COLLISION_X player half_width (1 bytes)
LCOL_THW             EQU $C880+$240   ; LEVEL_COLLISION_X total half_width (player_hw + obj_hw scratch) (1 bytes)
UGPC_OUTER_IDX       EQU $C880+$241   ; GP-GP outer loop index (1 bytes)
UGPC_OUTER_MAX       EQU $C880+$242   ; GP-GP outer loop max (count-1) (1 bytes)
UGPC_INNER_IDX       EQU $C880+$243   ; GP-GP inner loop index (1 bytes)
UGPC_DX              EQU $C880+$244   ; GP-GP |dx| (16-bit) (2 bytes)
UGPC_DIST            EQU $C880+$246   ; GP-GP Manhattan distance (16-bit) (2 bytes)
UGFC_GP_IDX          EQU $C880+$248   ; GP-FG outer loop GP index (1 bytes)
UGFC_FG_COUNT        EQU $C880+$249   ; GP-FG inner loop FG count (1 bytes)
UGFC_DX              EQU $C880+$24A   ; GP-FG |dx| (1 bytes)
UGFC_DY              EQU $C880+$24B   ; GP-FG |dy| (1 bytes)
ANIM_MARIO_WALK_STATE EQU $C880+$24C   ; DRAW_ANIM state for MARIO_WALK (frame_idx, ticks_left) (2 bytes)
DRAW_ANIM_MIRROR_X   EQU $C880+$24E   ; DRAW_ANIM mirror X flag (0=normal, 1=flip) (1 bytes)
VAR_MARIO_HH         EQU $C880+$24F   ; User variable: MARIO_HH (2 bytes)
VAR_MARIO_HW         EQU $C880+$251   ; User variable: MARIO_HW (2 bytes)
VAR_PLAYER_X         EQU $C880+$253   ; User variable: PLAYER_X (2 bytes)
VAR_PLAYER_Y         EQU $C880+$255   ; User variable: PLAYER_Y (2 bytes)
VAR_VEL_Y            EQU $C880+$257   ; User variable: VEL_Y (2 bytes)
VAR_ON_GROUND        EQU $C880+$259   ; User variable: ON_GROUND (1 bytes)
VAR_PREV_Y           EQU $C880+$25A   ; User variable: PREV_Y (2 bytes)
VAR_CAMERA_X         EQU $C880+$25C   ; User variable: CAMERA_X (2 bytes)
VAR_SCROLL_LEFT      EQU $C880+$25E   ; User variable: SCROLL_LEFT (2 bytes)
VAR_SCROLL_RIGHT     EQU $C880+$260   ; User variable: SCROLL_RIGHT (2 bytes)
VAR_SCROLL_RIGHT_EDGE EQU $C880+$262   ; User variable: SCROLL_RIGHT_EDGE (2 bytes)
VAR_SCREEN_X         EQU $C880+$264   ; User variable: SCREEN_X (2 bytes)
VAR_IS_WALKING       EQU $C880+$266   ; User variable: IS_WALKING (1 bytes)
VAR_FLOOR_Y          EQU $C880+$267   ; User variable: FLOOR_Y (2 bytes)
VAR_JOY_X            EQU $C880+$269   ; User variable: JOY_X (2 bytes)
VAR_BTN_JUMP         EQU $C880+$26B   ; User variable: BTN_JUMP (2 bytes)
VAR_DX_PUSH          EQU $C880+$26D   ; User variable: DX_PUSH (2 bytes)
VAR_ARG0             EQU $CB80   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $CB82   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $CB84   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $CB86   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $CB88   ; Function argument 4 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $CB8A   ; Current ROM bank ID (multibank tracking) (1 bytes)
PSG_MUSIC_PTR        EQU $CBEB   ; PSG music data pointer (2 bytes)
PSG_MUSIC_START      EQU $CBED   ; PSG music start pointer (for loops) (2 bytes)
PSG_MUSIC_ACTIVE     EQU $CBEF   ; PSG music active flag (1 bytes)
PSG_IS_PLAYING       EQU $CBF0   ; PSG playing flag (1 bytes)
PSG_DELAY_FRAMES     EQU $CBF1   ; PSG frame delay counter (1 bytes)
PSG_MUSIC_BANK       EQU $CBF2   ; PSG music bank ID (for multibank) (1 bytes)
SFX_PTR              EQU $CBF3   ; SFX data pointer (2 bytes)
SFX_ACTIVE           EQU $CBF5   ; SFX active flag (1 bytes)
SFX_BANK             EQU $CBF6   ; SFX bank ID (for multibank) (1 bytes)

;***************************************************************************
; MAIN PROGRAM
;***************************************************************************

MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    LDD #0
    STD VAR_PLAYER_X
    LDD #-62
    STD VAR_PLAYER_Y
    LDD #0
    STD VAR_VEL_Y
    LDD #1
    STD VAR_ON_GROUND
    LDD #-62
    STD VAR_PREV_Y
    LDD #0
    STD VAR_CAMERA_X
    LDD #0
    STD VAR_SCROLL_LEFT
    LDD #0
    STD VAR_SCROLL_RIGHT
    LDD #0
    STD VAR_SCROLL_RIGHT_EDGE
    LDD #-30
    STD VAR_SCREEN_X
    LDD #0
    STD VAR_IS_WALKING
    LDD #-62
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
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'world_1_1'
    LDX #_WORLD_1_1_LEVEL          ; Pointer to level data in ROM
    JSR LOAD_LEVEL_RUNTIME
    ; ===== GET_SCROLL_LIMIT_LEFT builtin =====
    LDD >SCROLL_LIMIT_LEFT
    STD RESULT
    STD VAR_SCROLL_LEFT
    ; ===== GET_SCROLL_LIMIT_RIGHT builtin =====
    LDD >SCROLL_LIMIT_RIGHT
    STD RESULT
    STD VAR_SCROLL_RIGHT
    LDD >VAR_SCROLL_RIGHT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #192
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_SCROLL_RIGHT_EDGE
    CLR >$C811  ; Force-clear Vec_Buttons before first loop() frame

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    JSR J1X_BUILTIN
    STD RESULT
    STD VAR_JOY_X
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
    LDD #0
    STB VAR_IS_WALKING
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
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #3
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_PLAYER_X
    LDD #1
    STB VAR_IS_WALKING
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
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
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #3
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_PLAYER_X
    LDD #1
    STB VAR_IS_WALKING
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    ; CLAMP: Clamp value to range [min, max]
    LDD >VAR_PLAYER_X
    STD TMPPTR     ; Save value
    LDD #-62
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
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_VEL_Y
    CMPD TMPVAL
    LBLE .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    LBEQ IF_NEXT_5
    ; ===== LEVEL_COLLISION_X builtin =====
    LDD >VAR_PLAYER_X
    STD >LCOL_PX         ; store player world_x (16-bit)
    LDD #8  ; const MARIO_HW
    STB >LCOL_PHW        ; store player half_width
    LDD #13  ; const MARIO_HH
    STB >LCOL_PHH        ; store player half_height for Y-overlap check
    LDD >VAR_PLAYER_Y
    STB >LCOL_PY         ; store player_y lo byte
    JSR LEVEL_COLLISION_X_RUNTIME
    STD VAR_DX_PUSH
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_DX_PUSH
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_PLAYER_X
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN_JUMP
    CMPD TMPVAL
    LBEQ .CMP_3_TRUE
    LDD #0
    LBRA .CMP_3_END
.CMP_3_TRUE:
    LDD #1
.CMP_3_END:
    LBEQ IF_NEXT_7
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_ON_GROUND
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBEQ .CMP_4_TRUE
    LDD #0
    LBRA .CMP_4_END
.CMP_4_TRUE:
    LDD #1
.CMP_4_END:
    LBEQ IF_NEXT_9
    LDD #12
    STD VAR_VEL_Y
    LDD #0
    STB VAR_ON_GROUND
    ; PLAY_SFX("jump") - play SFX asset (index=0)
    LDX #_JUMP_SFX  ; Load SFX data pointer
    JSR PLAY_SFX_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_8
IF_NEXT_9:
IF_END_8:
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_ON_GROUND
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBEQ .CMP_5_TRUE
    LDD #0
    LBRA .CMP_5_END
.CMP_5_TRUE:
    LDD #1
.CMP_5_END:
    LBEQ IF_NEXT_11
    LDD >VAR_PLAYER_Y
    STD VAR_PREV_Y
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_VEL_Y
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_PLAYER_Y
    LDD >VAR_VEL_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_VEL_Y
    ; ===== LEVEL_COLLISION_Y builtin =====
    LDD >VAR_PLAYER_X
    STD >LCOL_PX         ; store player world_x (16-bit)
    LDD #13  ; const MARIO_HH
    STB >LCOL_PHH        ; store player half_height
    LDD >VAR_PREV_Y
    ADDB >LCOL_PHH       ; B = player_y_lo + player_hh = player_top
    STB >LCOL_PY         ; store player top Y for surface filter
    JSR LEVEL_COLLISION_Y_RUNTIME
    STD VAR_FLOOR_Y
    ; MAX: Return maximum of two values
    LDD >VAR_FLOOR_Y
    STD TMPPTR     ; Save first value
    LDD #-120
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
    LDD >VAR_FLOOR_Y
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_Y
    CMPD TMPVAL
    LBLE .CMP_6_TRUE
    LDD #0
    LBRA .CMP_6_END
.CMP_6_TRUE:
    LDD #1
.CMP_6_END:
    LBEQ IF_NEXT_13
    LDD >VAR_FLOOR_Y
    STD VAR_PLAYER_Y
    LDD #0
    STD VAR_VEL_Y
    LDD #1
    STB VAR_ON_GROUND
    LBRA IF_END_12
IF_NEXT_13:
IF_END_12:
    LBRA IF_END_10
IF_NEXT_11:
IF_END_10:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_ON_GROUND
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBEQ .CMP_7_TRUE
    LDD #0
    LBRA .CMP_7_END
.CMP_7_TRUE:
    LDD #1
.CMP_7_END:
    LBEQ IF_NEXT_15
    ; ===== LEVEL_COLLISION_Y builtin =====
    LDD >VAR_PLAYER_X
    STD >LCOL_PX         ; store player world_x (16-bit)
    LDD #13  ; const MARIO_HH
    STB >LCOL_PHH        ; store player half_height
    LDD >VAR_PLAYER_Y
    ADDB >LCOL_PHH       ; B = player_y_lo + player_hh = player_top
    STB >LCOL_PY         ; store player top Y for surface filter
    JSR LEVEL_COLLISION_Y_RUNTIME
    STD VAR_FLOOR_Y
    ; MAX: Return maximum of two values
    LDD >VAR_FLOOR_Y
    STD TMPPTR     ; Save first value
    LDD #-120
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
    LDD >VAR_FLOOR_Y
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_Y
    CMPD TMPVAL
    LBGT .CMP_8_TRUE
    LDD #0
    LBRA .CMP_8_END
.CMP_8_TRUE:
    LDD #1
.CMP_8_END:
    LBEQ IF_NEXT_17
    LDD #0
    STB VAR_ON_GROUND
    LBRA IF_END_16
IF_NEXT_17:
IF_END_16:
    LBRA IF_END_14
IF_NEXT_15:
IF_END_14:
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #30
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_CAMERA_X
    ; CLAMP: Clamp value to range [min, max]
    LDD >VAR_CAMERA_X
    STD TMPPTR     ; Save value
    LDD >VAR_SCROLL_LEFT
    STD TMPPTR+2   ; Save min
    LDD >VAR_SCROLL_RIGHT_EDGE
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
    ; ===== SET_CAMERA_X builtin =====
    LDD >VAR_CAMERA_X
    STD >CAMERA_X    ; Store 16-bit camera X scroll offset
    LDD #0
    STD RESULT
    ; ===== SHOW_LEVEL builtin =====
    JSR SHOW_LEVEL_RUNTIME
    LDD #0
    STD RESULT
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_CAMERA_X
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_SCREEN_X
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_IS_WALKING
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBEQ .CMP_9_TRUE
    LDD #0
    LBRA .CMP_9_END
.CMP_9_TRUE:
    LDD #1
.CMP_9_END:
    LBEQ IF_NEXT_19
    ; DRAW_ANIM: draw animation 'mario_walk'
    LDD >VAR_SCREEN_X
    TFR B,A
    STA DRAW_VEC_X
    LDD >VAR_PLAYER_Y
    TFR B,A
    STA DRAW_VEC_Y
    CLR DRAW_ANIM_MIRROR_X
    LDX #_ANIM_MARIO_WALK
    LDU #ANIM_MARIO_WALK_STATE
    JSR DRAW_ANIM_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_18
IF_NEXT_19:
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: mario_body (index=2, 6 paths)
    LDD >VAR_SCREEN_X
    TFR B,A       ; X position (low byte) — B already holds it
    STA TMPPTR    ; Save X to temporary storage
    LDD >VAR_PLAYER_Y
    TFR B,A       ; Y position (low byte) — B already holds it
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_MARIO_BODY_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MARIO_BODY_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MARIO_BODY_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MARIO_BODY_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MARIO_BODY_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MARIO_BODY_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Reset: next DRAW_VECTOR uses .vec intensities
    LDD #0
    STD RESULT
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: mario_legs_straight (index=3, 2 paths)
    LDD >VAR_SCREEN_X
    TFR B,A       ; X position (low byte) — B already holds it
    STA TMPPTR    ; Save X to temporary storage
    LDD >VAR_PLAYER_Y
    TFR B,A       ; Y position (low byte) — B already holds it
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_MARIO_LEGS_STRAIGHT_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MARIO_LEGS_STRAIGHT_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Reset: next DRAW_VECTOR uses .vec intensities
    LDD #0
    STD RESULT
IF_END_18:
    LDD >VAR_FLOOR_Y
    ; DEBUG_PRINT(FLOOR_Y)
    STA $C002
    STB $C000
    LDA #$FE
    STA $C001
    LDX #DEBUG_LABEL_FLOOR_Y
    STX $C004
    BRA DEBUG_SKIP_0
DEBUG_LABEL_FLOOR_Y:
    FCC "FLOOR_Y"
    FCB $00
DEBUG_SKIP_0:
    LDD #0
    STD RESULT
    LDD >VAR_PLAYER_Y
    ; DEBUG_PRINT(PLAYER_Y)
    STA $C002
    STB $C000
    LDA #$FE
    STA $C001
    LDX #DEBUG_LABEL_PLAYER_Y
    STX $C004
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
    FDB 1               ; path_count (runtime metadata, 2 bytes)
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
    FDB 7               ; path_count (runtime metadata, 2 bytes)
    FDB _GROUND_TILE_PATH0        ; pointer to path 0
    FDB _GROUND_TILE_PATH1        ; pointer to path 1
    FDB _GROUND_TILE_PATH2        ; pointer to path 2
    FDB _GROUND_TILE_PATH3        ; pointer to path 3
    FDB _GROUND_TILE_PATH4        ; pointer to path 4
    FDB _GROUND_TILE_PATH5        ; pointer to path 5
    FDB _GROUND_TILE_PATH6        ; pointer to path 6

_GROUND_TILE_PATH0:    ; Path 0
    FCB 80              ; path0: intensity
    FCB $F8,$E2,0,0        ; path0: header (y=-8, x=-30)
    FCB $FF,$00,$3C          ; flag=-1, dy=0, dx=60
    FCB $FF,$10,$00          ; flag=-1, dy=16, dx=0
    FCB $FF,$00,$C4          ; flag=-1, dy=0, dx=-60
    FCB $FF,$F0,$00          ; flag=-1, dy=-16, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_GROUND_TILE_PATH1:    ; Path 1
    FCB 60              ; path1: intensity
    FCB $00,$E2,0,0        ; path1: header (y=0, x=-30)
    FCB $FF,$00,$3C          ; flag=-1, dy=0, dx=60
    FCB 2                ; End marker (path complete)

_GROUND_TILE_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $08,$EC,0,0        ; path2: header (y=8, x=-20)
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_GROUND_TILE_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $00,$F7,0,0        ; path3: header (y=0, x=-9)
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_GROUND_TILE_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $00,$02,0,0        ; path4: header (y=0, x=2)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB 2                ; End marker (path complete)

_GROUND_TILE_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $00,$0B,0,0        ; path5: header (y=0, x=11)
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_GROUND_TILE_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $00,$17,0,0        ; path6: header (y=0, x=23)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB 2                ; End marker (path complete)
; Generated from mario_body.vec (Malban Draw_Sync_List format)
; Total paths: 6, points: 18
; X bounds: min=-7, max=7, width=14
; Center: (0, 6)

_MARIO_BODY_WIDTH EQU 14
_MARIO_BODY_HALF_WIDTH EQU 7
_MARIO_BODY_HEIGHT EQU 18
_MARIO_BODY_HALF_HEIGHT EQU 9
_MARIO_BODY_CENTER_X EQU 0
_MARIO_BODY_CENTER_Y EQU 6

_MARIO_BODY_VECTORS:  ; Main entry (header + 6 path(s))
    FDB 6               ; path_count (runtime metadata, 2 bytes)
    FDB _MARIO_BODY_PATH0        ; pointer to path 0
    FDB _MARIO_BODY_PATH1        ; pointer to path 1
    FDB _MARIO_BODY_PATH2        ; pointer to path 2
    FDB _MARIO_BODY_PATH3        ; pointer to path 3
    FDB _MARIO_BODY_PATH4        ; pointer to path 4
    FDB _MARIO_BODY_PATH5        ; pointer to path 5

_MARIO_BODY_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $0B,$F9,0,0        ; path0: header (y=11, x=-7)
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB 2                ; End marker (path complete)

_MARIO_BODY_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $0B,$FB,0,0        ; path1: header (y=11, x=-5)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_MARIO_BODY_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $0B,$05,0,0        ; path2: header (y=11, x=5)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_MARIO_BODY_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $0F,$FB,0,0        ; path3: header (y=15, x=-5)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB 2                ; End marker (path complete)

_MARIO_BODY_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $03,$FA,0,0        ; path4: header (y=3, x=-6)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$F4          ; flag=-1, dy=0, dx=-12
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MARIO_BODY_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $FD,$F9,0,0        ; path5: header (y=-3, x=-7)
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)
; Generated from mario_legs_straight.vec (Malban Draw_Sync_List format)
; Total paths: 2, points: 6
; X bounds: min=-7, max=7, width=14
; Center: (0, -8)

_MARIO_LEGS_STRAIGHT_WIDTH EQU 14
_MARIO_LEGS_STRAIGHT_HALF_WIDTH EQU 7
_MARIO_LEGS_STRAIGHT_HEIGHT EQU 10
_MARIO_LEGS_STRAIGHT_HALF_HEIGHT EQU 5
_MARIO_LEGS_STRAIGHT_CENTER_X EQU 0
_MARIO_LEGS_STRAIGHT_CENTER_Y EQU -8

_MARIO_LEGS_STRAIGHT_VECTORS:  ; Main entry (header + 2 path(s))
    FDB 2               ; path_count (runtime metadata, 2 bytes)
    FDB _MARIO_LEGS_STRAIGHT_PATH0        ; pointer to path 0
    FDB _MARIO_LEGS_STRAIGHT_PATH1        ; pointer to path 1

_MARIO_LEGS_STRAIGHT_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FD,$F9,0,0        ; path0: header (y=-3, x=-7)
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB 2                ; End marker (path complete)

_MARIO_LEGS_STRAIGHT_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $FD,$07,0,0        ; path1: header (y=-3, x=7)
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB 2                ; End marker (path complete)
; Generated from mario_legs_stride_a.vec (Malban Draw_Sync_List format)
; Total paths: 2, points: 6
; X bounds: min=-11, max=9, width=20
; Center: (-1, -8)

_MARIO_LEGS_STRIDE_A_WIDTH EQU 20
_MARIO_LEGS_STRIDE_A_HALF_WIDTH EQU 10
_MARIO_LEGS_STRIDE_A_HEIGHT EQU 10
_MARIO_LEGS_STRIDE_A_HALF_HEIGHT EQU 5
_MARIO_LEGS_STRIDE_A_CENTER_X EQU -1
_MARIO_LEGS_STRIDE_A_CENTER_Y EQU -8

_MARIO_LEGS_STRIDE_A_VECTORS:  ; Main entry (header + 2 path(s))
    FDB 2               ; path_count (runtime metadata, 2 bytes)
    FDB _MARIO_LEGS_STRIDE_A_PATH0        ; pointer to path 0
    FDB _MARIO_LEGS_STRIDE_A_PATH1        ; pointer to path 1

_MARIO_LEGS_STRIDE_A_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FD,$F9,0,0        ; path0: header (y=-3, x=-7)
    FCB $FF,$F6,$FC          ; flag=-1, dy=-10, dx=-4
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB 2                ; End marker (path complete)

_MARIO_LEGS_STRIDE_A_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $FD,$07,0,0        ; path1: header (y=-3, x=7)
    FCB $FF,$F6,$FC          ; flag=-1, dy=-10, dx=-4
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB 2                ; End marker (path complete)
; Generated from mario_legs_stride_b.vec (Malban Draw_Sync_List format)
; Total paths: 2, points: 6
; X bounds: min=-7, max=11, width=18
; Center: (2, -8)

_MARIO_LEGS_STRIDE_B_WIDTH EQU 18
_MARIO_LEGS_STRIDE_B_HALF_WIDTH EQU 9
_MARIO_LEGS_STRIDE_B_HEIGHT EQU 10
_MARIO_LEGS_STRIDE_B_HALF_HEIGHT EQU 5
_MARIO_LEGS_STRIDE_B_CENTER_X EQU 2
_MARIO_LEGS_STRIDE_B_CENTER_Y EQU -8

_MARIO_LEGS_STRIDE_B_VECTORS:  ; Main entry (header + 2 path(s))
    FDB 2               ; path_count (runtime metadata, 2 bytes)
    FDB _MARIO_LEGS_STRIDE_B_PATH0        ; pointer to path 0
    FDB _MARIO_LEGS_STRIDE_B_PATH1        ; pointer to path 1

_MARIO_LEGS_STRIDE_B_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FD,$F9,0,0        ; path0: header (y=-3, x=-7)
    FCB $FF,$F6,$04          ; flag=-1, dy=-10, dx=4
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB 2                ; End marker (path complete)

_MARIO_LEGS_STRIDE_B_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $FD,$07,0,0        ; path1: header (y=-3, x=7)
    FCB $FF,$F6,$04          ; flag=-1, dy=-10, dx=4
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
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
    FDB 1               ; path_count (runtime metadata, 2 bytes)
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
    FDB 3               ; path_count (runtime metadata, 2 bytes)
    FDB _PIPE_PATH0        ; pointer to path 0
    FDB _PIPE_PATH1        ; pointer to path 1
    FDB _PIPE_PATH2        ; pointer to path 2

_PIPE_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $E7,$F6,0,0        ; path0: header (y=-25, x=-10)
    FCB $FF,$00,$14          ; flag=-1, dy=0, dx=20
    FCB $FF,$32,$00          ; flag=-1, dy=50, dx=0
    FCB $FF,$00,$EC          ; flag=-1, dy=0, dx=-20
    FCB $FF,$CE,$00          ; flag=-1, dy=-50, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_PIPE_PATH1:    ; Path 1
    FCB 100              ; path1: intensity
    FCB $14,$F4,0,0        ; path1: header (y=20, x=-12)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_PIPE_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $19,$F6,0,0        ; path2: header (y=25, x=-10)
    FCB $FF,$00,$14          ; flag=-1, dy=0, dx=20
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
    FDB 3               ; path_count (runtime metadata, 2 bytes)
    FDB _QUESTION_BLOCK_PATH0        ; pointer to path 0
    FDB _QUESTION_BLOCK_PATH1        ; pointer to path 1
    FDB _QUESTION_BLOCK_PATH2        ; pointer to path 2

_QUESTION_BLOCK_PATH0:    ; Path 0
    FCB 120              ; path0: intensity
    FCB $F8,$F8,0,0        ; path0: header (y=-8, x=-8)
    FCB $FF,$00,$10          ; flag=-1, dy=0, dx=16
    FCB $FF,$10,$00          ; flag=-1, dy=16, dx=0
    FCB $FF,$00,$F0          ; flag=-1, dy=0, dx=-16
    FCB $FF,$F0,$00          ; flag=-1, dy=-16, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_QUESTION_BLOCK_PATH1:    ; Path 1
    FCB 100              ; path1: intensity
    FCB $04,$FD,0,0        ; path1: header (y=4, x=-3)
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$FE,$FC          ; flag=-1, dy=-2, dx=-4
    FCB 2                ; End marker (path complete)

_QUESTION_BLOCK_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $FC,$FF,0,0        ; path2: header (y=-4, x=-1)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB 2                ; End marker (path complete)
; ==== Level: WORLD_1_1 ====
; Author: 
; Difficulty: medium

_WORLD_1_1_LEVEL:
    FDB -96  ; World bounds: xMin (16-bit signed)
    FDB 2207  ; xMax (16-bit signed)
    FDB -384  ; yMin (16-bit signed)
    FDB 127  ; yMax (16-bit signed)
    FDB 0  ; Time limit (seconds)
    FDB 0  ; Target score
    FCB 4  ; Background object count
    FCB 30  ; Gameplay object count
    FCB 0  ; Foreground object count
    FDB _WORLD_1_1_BG_OBJECTS
    FDB _WORLD_1_1_GAMEPLAY_OBJECTS
    FDB _WORLD_1_1_FG_OBJECTS
    FDB -96  ; scrollLimit left (camera left cannot go below this)
    FDB 1063  ; scrollLimit right (camera right cannot exceed this)
    FDB 127  ; scrollLimit top
    FDB -384  ; scrollLimit bottom

_WORLD_1_1_BG_OBJECTS:
; Object: obj_bg_cloud_1 (decoration)
    FCB 255  ; type
    FDB 225  ; x
    FDB 63  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _CLOUD_VECTORS  ; vector_ptr
    FCB _CLOUD_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _CLOUD_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_bg_cloud_2 (decoration)
    FCB 255  ; type
    FDB 350  ; x
    FDB 45  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _CLOUD_VECTORS  ; vector_ptr
    FCB _CLOUD_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _CLOUD_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_bg_cloud_3 (decoration)
    FCB 255  ; type
    FDB 600  ; x
    FDB 20  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _CLOUD_VECTORS  ; vector_ptr
    FCB _CLOUD_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _CLOUD_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_bg_cloud_4 (decoration)
    FCB 255  ; type
    FDB 850  ; x
    FDB 38  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _CLOUD_VECTORS  ; vector_ptr
    FCB _CLOUD_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _CLOUD_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)


_WORLD_1_1_GAMEPLAY_OBJECTS:
; Object: obj_bg_mountain_2 (decoration)
    FCB 255  ; type
    FDB 570  ; x
    FDB -50  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _MOUNTAIN_VECTORS  ; vector_ptr
    FCB _MOUNTAIN_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _MOUNTAIN_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_bg_mountain_3 (decoration)
    FCB 255  ; type
    FDB 730  ; x
    FDB 6  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _MOUNTAIN_VECTORS  ; vector_ptr
    FCB _MOUNTAIN_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _MOUNTAIN_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_1773216572040 (enemy)
    FCB 1  ; type
    FDB 270  ; x
    FDB -50  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _MOUNTAIN_VECTORS  ; vector_ptr
    FCB _MOUNTAIN_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _MOUNTAIN_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_bg_7 (tile)
    FCB 255  ; type
    FDB 300  ; x
    FDB -153  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _GROUND_TILE_VECTORS  ; vector_ptr
    FCB _GROUND_TILE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _GROUND_TILE_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_bg_1 (tile)
    FCB 255  ; type
    FDB -66  ; x
    FDB -153  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _GROUND_TILE_VECTORS  ; vector_ptr
    FCB _GROUND_TILE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _GROUND_TILE_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_bg_2 (tile)
    FCB 255  ; type
    FDB -5  ; x
    FDB -153  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _GROUND_TILE_VECTORS  ; vector_ptr
    FCB _GROUND_TILE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _GROUND_TILE_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_bg_3 (tile)
    FCB 255  ; type
    FDB 56  ; x
    FDB -153  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _GROUND_TILE_VECTORS  ; vector_ptr
    FCB _GROUND_TILE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _GROUND_TILE_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_bg_4 (tile)
    FCB 255  ; type
    FDB 117  ; x
    FDB -153  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _GROUND_TILE_VECTORS  ; vector_ptr
    FCB _GROUND_TILE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _GROUND_TILE_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_bg_5 (tile)
    FCB 255  ; type
    FDB 178  ; x
    FDB -153  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _GROUND_TILE_VECTORS  ; vector_ptr
    FCB _GROUND_TILE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _GROUND_TILE_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_bg_6 (tile)
    FCB 255  ; type
    FDB 239  ; x
    FDB -153  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _GROUND_TILE_VECTORS  ; vector_ptr
    FCB _GROUND_TILE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _GROUND_TILE_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_bg_8 (tile)
    FCB 255  ; type
    FDB 361  ; x
    FDB -153  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _GROUND_TILE_VECTORS  ; vector_ptr
    FCB _GROUND_TILE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _GROUND_TILE_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_bg_9 (tile)
    FCB 255  ; type
    FDB 422  ; x
    FDB -153  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _GROUND_TILE_VECTORS  ; vector_ptr
    FCB _GROUND_TILE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _GROUND_TILE_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_bg_10 (tile)
    FCB 255  ; type
    FDB 483  ; x
    FDB -153  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _GROUND_TILE_VECTORS  ; vector_ptr
    FCB _GROUND_TILE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _GROUND_TILE_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_bg_11 (tile)
    FCB 255  ; type
    FDB 544  ; x
    FDB -153  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _GROUND_TILE_VECTORS  ; vector_ptr
    FCB _GROUND_TILE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _GROUND_TILE_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_bg_12 (tile)
    FCB 255  ; type
    FDB 605  ; x
    FDB -153  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _GROUND_TILE_VECTORS  ; vector_ptr
    FCB _GROUND_TILE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _GROUND_TILE_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_bg_13 (tile)
    FCB 255  ; type
    FDB 666  ; x
    FDB -153  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _GROUND_TILE_VECTORS  ; vector_ptr
    FCB _GROUND_TILE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _GROUND_TILE_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_bg_14 (tile)
    FCB 255  ; type
    FDB 727  ; x
    FDB -153  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _GROUND_TILE_VECTORS  ; vector_ptr
    FCB _GROUND_TILE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _GROUND_TILE_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_bg_15 (tile)
    FCB 255  ; type
    FDB 788  ; x
    FDB -153  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _GROUND_TILE_VECTORS  ; vector_ptr
    FCB _GROUND_TILE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _GROUND_TILE_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_bg_16 (tile)
    FCB 255  ; type
    FDB 849  ; x
    FDB -153  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _GROUND_TILE_VECTORS  ; vector_ptr
    FCB _GROUND_TILE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _GROUND_TILE_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_bg_17 (tile)
    FCB 255  ; type
    FDB 910  ; x
    FDB -153  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _GROUND_TILE_VECTORS  ; vector_ptr
    FCB _GROUND_TILE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _GROUND_TILE_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_bg_18 (tile)
    FCB 255  ; type
    FDB 971  ; x
    FDB -153  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _GROUND_TILE_VECTORS  ; vector_ptr
    FCB _GROUND_TILE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _GROUND_TILE_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_bg_19 (tile)
    FCB 255  ; type
    FDB 1032  ; x
    FDB -153  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _GROUND_TILE_VECTORS  ; vector_ptr
    FCB _GROUND_TILE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _GROUND_TILE_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_gp_pipe_1 (obstacle)
    FCB 2  ; type
    FDB 218  ; x
    FDB -119  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PIPE_VECTORS  ; vector_ptr
    FCB _PIPE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _PIPE_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_gp_pipe_2 (obstacle)
    FCB 2  ; type
    FDB 420  ; x
    FDB -119  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PIPE_VECTORS  ; vector_ptr
    FCB _PIPE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _PIPE_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_gp_pipe_3 (obstacle)
    FCB 2  ; type
    FDB 682  ; x
    FDB -119  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PIPE_VECTORS  ; vector_ptr
    FCB _PIPE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _PIPE_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_gp_pipe_4 (obstacle)
    FCB 2  ; type
    FDB 850  ; x
    FDB -119  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PIPE_VECTORS  ; vector_ptr
    FCB _PIPE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _PIPE_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_gp_qblock_1 (item)
    FCB 255  ; type
    FDB 84  ; x
    FDB -88  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _QUESTION_BLOCK_VECTORS  ; vector_ptr
    FCB _QUESTION_BLOCK_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _QUESTION_BLOCK_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_gp_qblock_2 (item)
    FCB 255  ; type
    FDB 145  ; x
    FDB -49  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _QUESTION_BLOCK_VECTORS  ; vector_ptr
    FCB _QUESTION_BLOCK_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _QUESTION_BLOCK_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_gp_qblock_3 (item)
    FCB 255  ; type
    FDB 492  ; x
    FDB -88  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _QUESTION_BLOCK_VECTORS  ; vector_ptr
    FCB _QUESTION_BLOCK_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _QUESTION_BLOCK_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)

; Object: obj_gp_qblock_4 (item)
    FCB 255  ; type
    FDB 808  ; x
    FDB -88  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _QUESTION_BLOCK_VECTORS  ; vector_ptr
    FCB _QUESTION_BLOCK_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB _QUESTION_BLOCK_HALF_HEIGHT  ; half_height (collision AABB, ROM+19)


_WORLD_1_1_FG_OBJECTS:

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

; .vanim animation data: mario_walk (4 frames, loop=true, base_refs=1)

_ANIM_MARIO_WALK:
    FCB 4               ; frame_count
    FCB 1               ; loop flag (1=loop, 0=freeze)
    FCB 1               ; base_ref_count
    FCB 6               ; frame_table_offset
    FDB _MARIO_BODY_VECTORS      ; base_ref: mario_body
    FDB _ANIM_MARIO_WALK_F0       ; frame 0 pointer
    FDB _ANIM_MARIO_WALK_F1       ; frame 1 pointer
    FDB _ANIM_MARIO_WALK_F2       ; frame 2 pointer
    FDB _ANIM_MARIO_WALK_F3       ; frame 3 pointer

_ANIM_MARIO_WALK_F0:
    FCB 6               ; duration_ticks
    FCB 1               ; vec_ref_count
    FDB _MARIO_LEGS_STRAIGHT_VECTORS      ; vec_ref: mario_legs_straight
    FCB 0               ; inline_path_count

_ANIM_MARIO_WALK_F1:
    FCB 6               ; duration_ticks
    FCB 1               ; vec_ref_count
    FDB _MARIO_LEGS_STRIDE_A_VECTORS      ; vec_ref: mario_legs_stride_a
    FCB 0               ; inline_path_count

_ANIM_MARIO_WALK_F2:
    FCB 6               ; duration_ticks
    FCB 1               ; vec_ref_count
    FDB _MARIO_LEGS_STRAIGHT_VECTORS      ; vec_ref: mario_legs_straight
    FCB 0               ; inline_path_count

_ANIM_MARIO_WALK_F3:
    FCB 6               ; duration_ticks
    FCB 1               ; vec_ref_count
    FDB _MARIO_LEGS_STRIDE_B_VECTORS      ; vec_ref: mario_legs_stride_b
    FCB 0               ; inline_path_count

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

; === JOYSTICK BUILTIN SUBROUTINES ===
; J1_X() - Read Joystick 1 X axis (INCREMENTAL - with state preservation)
; Returns: D = raw value from $C81B after Joy_Analog call
J1X_BUILTIN:
    PSHS X       ; Save X (Joy_Analog uses it)
    JSR $F1AA    ; DP_to_D0 (required for Joy_Analog BIOS call)
    JSR $F1F5    ; Joy_Analog (updates $C81B from hardware)
    JSR Reset0Ref ; Full beam reset: zeros DAC (VIA_port_a=0) via Reset_Pen + grounds integrators
    JSR $F1AF    ; DP_to_C8 (required to read RAM $C81B)
    LDB $C81B    ; Vec_Joy_1_X (BIOS writes ~$FE at center)
    SEX          ; Sign-extend B to D
    ADDD #2      ; Calibrate center offset
    PULS X       ; Restore X
    RTS

Draw_Sync_List_At_With_Mirrors:
; Unified mirror support using flags: MIRROR_X and MIRROR_Y
; Conditionally negates X and/or Y coordinates and deltas
; NOTE: Caller must ensure DP=$D0 for VIA access
; CRITICAL: Do NOT call JSR $F2AB (Intensity_a) here! Intensity_a manipulates
; VIA Port B through states $05->$04->$01 which resets the analog hardware
; (zero-reference sequence) and would disrupt the beam position mid-drawing.
; Instead we replicate only the VIA Port A write + Port B Z-axis strobe inline.
LDA ,X+                 ; Read per-path intensity from vector data
DSWM_SET_INTENSITY:
STA >$C832              ; Update BIOS variable (Vec_Misc_Count)
STA >$D001              ; Port A = intensity (alg_xsh = intensity XOR $80)
LDA #$04
STA >$D000              ; Port B=$04: Z-axis mux enabled -> alg_zsh updated
LDA #$01
STA >$D000              ; Port B=$01: restore normal mux
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
; T1 fixed at $7F (constant scale; brightness is set via $C832 above, independently)
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
CLR VIA_shift_reg       ; beam off (PB stays 1 for next segment)
LBRA DSWM_LOOP          ; Long branch
; Next path: repeat mirror logic for new path header
DSWM_NEXT_PATH:
TFR X,D
PSHS D
; Read per-path intensity from vector data
LDA ,X+                 ; Read intensity from vector data
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
STA >$C832              ; Update BIOS variable (Vec_Misc_Count)
STA >$D001              ; Port A = intensity (alg_xsh = intensity XOR $80)
LDA #$04
STA >$D000              ; Port B=$04: Z-axis mux enabled -> alg_zsh updated
LDA #$01
STA >$D000              ; Port B=$01: restore normal mux
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
; T1 fixed at $7F (constant scale; brightness set via $C832 above)
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
    
    ; Reset camera to world origin — JSVecX RAM is NOT zero-initialized
    LDD #0
    STD >CAMERA_X
    STD >CAMERA_Y
    
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
    
    ; === Copy GP objects from ROM to RAM buffer ===
    LDB >LEVEL_GP_COUNT
    BEQ LLR_SKIP_GP  ; Skip if no GP objects
    
    ; Clear GP buffer with $FF marker (empty sentinel)
    LDA #$FF
    LDU #LEVEL_GP_BUFFER
    LDB #32          ; Max 32 objects
LLR_CLR_GP_LOOP:
    STA ,U           ; Write $FF to first byte of object slot
    LEAU 15,U        ; Advance by 15 bytes (RAM object stride)
    DECB
    BNE LLR_CLR_GP_LOOP
    
    ; Copy GP objects: ROM (20 bytes each) → RAM buffer (14 bytes each)
    LDB >LEVEL_GP_COUNT   ; Reload count after clear loop
    LDX >LEVEL_GP_ROM_PTR ; X = source (ROM)
    LDU #LEVEL_GP_BUFFER  ; U = destination (RAM)
    PSHS U               ; Save buffer start
    JSR LLR_COPY_OBJECTS  ; Copy B objects from X(ROM) to U(RAM)
    PULS D               ; Restore buffer start into D
    STD >LEVEL_GP_PTR    ; LEVEL_GP_PTR → RAM buffer
    BRA LLR_GP_DONE
    
LLR_GP_DONE:
LLR_SKIP_GP:
    
    ; Return level pointer in RESULT
    LDX >LEVEL_PTR
    STX RESULT
    
    PULS D,X,Y,U,PC  ; Restore and return
    
; === LLR_COPY_OBJECTS - Copy N ROM objects to RAM buffer ===
; Input:  B = count, X = source (ROM, 20 bytes/obj), U = dest (RAM, 15 bytes/obj)
; ROM object layout (20 bytes):
;   +0: type, +1-2: x(FDB), +3-4: y(FDB), +5-6: scale(FDB),
;   +7: rotation, +8: intensity, +9: velocity_x, +10: velocity_y,
;   +11: physics_flags, +12: collision_flags, +13: collision_size,
;   +14-15: spawn_delay(FDB), +16-17: vector_ptr(FDB), +18: half_width, +19: half_height
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
    LEAX 2,X         ; Skip spawn_delay FDB (2 bytes), X now at ROM +16
    ; RAM +11-12: vector_ptr FDB (ROM +16-17)
    LDD ,X++         ; ROM +16-17
    STD ,U++
    ; RAM +13-14: properties_ptr FDB (ROM +18-19)
    LDD ,X++         ; ROM +18-19
    STD ,U++
    ; X is now past end of this ROM object (ROM +1 + 8 + 5 + 2 + 2 + 2 = +20 total)
    ; NOTE: We started at ROM+1 (after LEAX 1,X), walked:
    ;   ,X and 1,X and 3,X and 5,X and 6,X via indexed → X unchanged
    ;   then LEAX 8,X (X now at ROM+9)
    ;   then 5 post-increment ,X+ → X at ROM+14
    ;   then LEAX 2,X (X at ROM+16)
    ;   then 2x LDD ,X++ → X at ROM+20
    ;   ROM+20 from original ROM+0 = next object start
    
    PULS B           ; Restore counter
    DECB
    BRA LLR_COPY_LOOP
LLR_COPY_DONE:
    RTS

; === SHOW_LEVEL_RUNTIME ===
; Draw all level objects from all layers
; Input:  LEVEL_PTR = pointer to level header
; Layers: BG (ROM stride 20), GP (RAM stride 15), FG (ROM stride 20)
; Each object: load intensity, x, y, vector_ptr, call SLR_DRAW_OBJECTS
SHOW_LEVEL_RUNTIME:
    PSHS D,X,Y,U     ; Preserve registers
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDA #$18
    STA >$D00B       ; ACR=$18: SR shift-out PHI2, enable beam via SR
    
    ; Check if level is loaded
    TST >LEVEL_LOADED
    BEQ SLR_DONE     ; No level loaded, skip
    LDX >LEVEL_PTR
    
    ; Re-read object counts from header
    LEAX 12,X        ; X points to counts (+12)
    LDB ,X+          ; B = bgCount
    STB >LEVEL_BG_COUNT
    LDB ,X+          ; B = gpCount
    STB >LEVEL_GP_COUNT
    LDB ,X+          ; B = fgCount
    STB >LEVEL_FG_COUNT
    
    ; === Draw Background Layer (ROM, stride=20) ===
SLR_BG_COUNT:
    CLRB
    LDB >LEVEL_BG_COUNT
    CMPB #0
    BEQ SLR_GAMEPLAY
    LDA #20          ; ROM object stride
    LDX >LEVEL_BG_ROM_PTR
    JSR SLR_DRAW_OBJECTS
    
    ; === Draw Gameplay Layer (RAM, stride=15) ===
SLR_GAMEPLAY:
SLR_GP_COUNT:
    CLRB
    LDB >LEVEL_GP_COUNT
    CMPB #0
    BEQ SLR_FOREGROUND
    LDA #15          ; RAM object stride (15 bytes)
    LDX >LEVEL_GP_PTR
    JSR SLR_DRAW_OBJECTS
    
    ; === Draw Foreground Layer (ROM, stride=20) ===
SLR_FOREGROUND:
SLR_FG_COUNT:
    CLRB
    LDB >LEVEL_FG_COUNT
    CMPB #0
    BEQ SLR_DONE
    LDA #20          ; ROM object stride
    LDX >LEVEL_FG_ROM_PTR
    JSR SLR_DRAW_OBJECTS
    
SLR_DONE:
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    PULS D,X,Y,U,PC  ; Restore and return
    
; === SLR_DRAW_OBJECTS - Draw N objects from a layer ===
; Input:  A = stride (15=RAM, 20=ROM), B = count, X = objects ptr
; For ROM objects (stride=20): intensity at +8, y FDB at +3, x FDB at +1, vector_ptr FDB at +16
; For RAM objects (stride=15): look up intensity from ROM via LEVEL_GP_ROM_PTR,
;   world_x at +0-1 (16-bit), y at +2, vector_ptr FDB at +11
; Camera: SUBD >CAMERA_X applied to world_x; objects outside i8 range are culled
SLR_DRAW_OBJECTS:
    PSHS A           ; Save stride on stack (A=stride)
SLR_OBJ_LOOP:
    TSTB
    LBEQ SLR_OBJ_DONE
    
    PSHS B           ; Save counter (LDD clobbers B)
    
    ; Determine ROM vs RAM offsets via stride
    LDA 1,S          ; Peek stride from stack (+1 because B is on top)
    CMPA #20
    LBEQ SLR_ROM_OFFSETS
    
    ; === RAM object (stride=15) ===
    ; Need to look up intensity from ROM counterpart
    ; objIndex = LEVEL_GP_COUNT - currentCount
    PSHS X           ; Save RAM object pointer
    LDB >LEVEL_GP_COUNT
    SUBB 2,S         ; B = objIndex = totalCount - currentCounter
    LDX >LEVEL_GP_ROM_PTR  ; X = ROM base
SLR_ROM_ADDR_LOOP:
    BEQ SLR_INTENSITY_READ ; Done if index=0
    LEAX 20,X        ; Advance by ROM stride
    DECB
    BRA SLR_ROM_ADDR_LOOP
SLR_INTENSITY_READ:
    LDA 8,X          ; intensity at ROM +8
    STA >DRAW_VEC_INTENSITY  ; DP=$D0, must use extended addressing
    PULS X           ; Restore RAM object pointer
    
    CLR >MIRROR_X    ; DP=$D0, must use extended addressing
    CLR >MIRROR_Y
    ; Load world_x (16-bit), subtract CAMERA_X, check visibility
    LDD 0,X          ; RAM +0-1 = world_x (16-bit)
    SUBD >CAMERA_X   ; screen_x = world_x - camera_x
    STD >TMPVAL      ; save screen_x (overwritten by CMPB below)
    ; Per-object cull using half_width from RAM+13
    ; Wider culling: object stays until fully off-screen
    ; Visible range: [-(128+hw), 127+hw]
    ; right_limit = 127 + hw  (A=$00, B <= right_limit)
    ; left_limit  = 128 - hw  (A=$FF, B >= left_limit)
    LDB 13,X         ; B = half_width (RAM+13)
    STB >TMPPTR2     ; save hw
    LDA #127
    ADDA >TMPPTR2    ; A = 127 + hw (right boundary)
    STA >TMPPTR
    LDA #128
    SUBA >TMPPTR2    ; A = 128 - hw (left boundary, unsigned)
    STA >TMPPTR+1
    LDD >TMPVAL      ; restore screen_x into D
    TSTA
    BEQ SLR_RAM_A_ZERO
    INCA
    LBNE SLR_OBJ_NEXT        ; A not $FF: too far
    ; A=$FF: visible if B >= left_limit (128-hw)
    CMPB >TMPPTR+1
    BHS SLR_RAM_VISIBLE       ; unsigned >=
    LBRA SLR_OBJ_NEXT
SLR_RAM_A_ZERO:
    ; A=0: visible if B <= right_limit (127+hw)
    CMPB >TMPPTR
    BLS SLR_RAM_VISIBLE       ; unsigned <=
    LBRA SLR_OBJ_NEXT
SLR_RAM_VISIBLE:
    LDD >TMPVAL      ; reload full 16-bit screen_x (INCA corrupted A)
    STD >DRAW_VEC_X_HI ; store full 16-bit screen_x (A=hi, B=lo)
    ; Apply CAMERA_Y: sign-extend world_y (8-bit), subtract CAMERA_Y, cull
    LDB 2,X          ; world_y (signed byte at RAM +2)
    SEX              ; sign-extend B into D
    SUBD >CAMERA_Y   ; screen_y = world_y - camera_y
    TSTA
    BEQ SLR_RAM_Y_ZERO
    INCA
    LBNE SLR_OBJ_NEXT    ; A not $FF: too far above
    ; A=$FF: visible if B >= 128 (i.e. >= -128 signed)
    CMPB #128
    BHS SLR_RAM_Y_VISIBLE
    LBRA SLR_OBJ_NEXT
SLR_RAM_Y_ZERO:
    ; A=0: visible if B <= 127
    CMPB #127
    BLS SLR_RAM_Y_VISIBLE
    LBRA SLR_OBJ_NEXT
SLR_RAM_Y_VISIBLE:
    STB >DRAW_VEC_Y
    LDU 11,X         ; vector_ptr at RAM +11
    BRA SLR_DRAW_VECTOR
    
SLR_ROM_OFFSETS:
    ; === ROM object (stride=20) ===
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
    ; Per-object cull: half_width at ROM+18
    ; Wider culling: object stays until fully off-screen
    LDB 18,X         ; B = half_width (ROM+18)
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
    LDU 16,X         ; vector_ptr FDB at ROM +16
    
SLR_DRAW_VECTOR:
    PSHS X           ; Save object pointer
    TFR U,X          ; X = vector data pointer (header)
    
    ; Read path_count from vector header (FDB = 2 bytes big-endian, high byte is always $00)
    LDA ,X+          ; skip high byte of FDB path_count (always $00 for ≤255 paths)
    LDB ,X+          ; B = path_count (low byte), X now at pointer table
    
    ; DP is already $D0 (set by SHOW_LEVEL_RUNTIME at entry)
SLR_PATH_LOOP:
    TSTB
    BEQ SLR_PATH_DONE
    DECB
    PSHS B           ; Save decremented count
    LDU ,X++         ; U = path pointer, X advances to next entry
    PSHS X           ; Save pointer table position
    TFR U,X          ; X = actual path data
    JSR SLR_DRAW_CLIPPED_PATH
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
; Per-segment X-axis clipping using direct VIA register writes.
; Mirrors the DSWM VIA pattern — no BIOS calls (Intensity_a corrupts
; DDRB with DP=$D0; Draw_Line_d / Moveto_d are BIOS-only).
; Segments whose new_x = cur_x+dx overflows a signed byte are moved
; with beam OFF, preventing screen-wrap at left/right edges.
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
    STB >TMPVAL             ; save abs_y for moveto
    TFR A,B                 ; B = x_start (SEX extends B, not A)
    SEX                      ; sign-extend B→D (A=sign, B=x_start)
    ADDD >DRAW_VEC_X_HI     ; D = abs_x_16 = SEX(x_start) + screen_x_16
    ; Range check: abs_x must fit in signed byte [-128, +127]
    ; If out of range, skip this path (can't position beam correctly).
    ; Progressive clipping works because paths starting on-screen are
    ; drawn normally, and their segments get clipped at the edge.
    TSTA
    BEQ SDCP_CHECK_POS       ; A=$00 → check positive range
    INCA                      ; was A=$FF?
    BNE SDCP_SKIP_PATH        ; A was not $00 or $FF → way off
    ; A was $FF: valid if B >= $80 (negative signed byte)
    CMPB #$80
    BHS SDCP_ABS_OK
    BRA SDCP_SKIP_PATH
SDCP_CHECK_POS:
    ; A=$00: valid if B <= $7F
    CMPB #$7F
    BLS SDCP_ABS_OK
SDCP_SKIP_PATH:
    RTS
SDCP_ABS_OK:
    ; B = abs_x (valid signed byte)
    TFR B,A                  ; A = abs_x for moveto
    STA >SLR_CUR_X          ; init beam-x tracker
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
    LDB >TMPVAL             ; B = abs_y
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
    LDA #$7F
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
    BEQ SDCP_DONE
    ; Read dy → B, dx → A (DSWM order)
    LDB ,X+                 ; B = dy
    LDA ,X+                 ; A = dx
    ; --- X-axis clip check: new_x = cur_x + dx ---
    STB >TMPPTR2            ; save dy
    PSHS A                  ; push dx
    LDA >SLR_CUR_X
    ADDA ,S                 ; A = cur_x + dx; V set on overflow
    BVS SDCP_CLIP           ; overflow → clip
    STA >SLR_CUR_X          ; update tracker
    PULS A                  ; restore dx
    LDB >TMPPTR2            ; restore dy
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
    BRA SDCP_SEG_LOOP
SDCP_CLIP:
    STA >SLR_CUR_X          ; store wrapped x (approx)
    PULS A                  ; restore dx
    LDB >TMPPTR2            ; restore dy
    STB VIA_port_a          ; DY → DAC
    CLR VIA_port_b
    NOP
    NOP
    NOP
    INC VIA_port_b
    STA VIA_port_a          ; DX → DAC
    ; beam stays OFF (no STA VIA_shift_reg)
    CLR VIA_t1_cnt_hi       ; start T1 (ramp, beam off)
SDCP_W_MOVE:
    LDA VIA_int_flags
    ANDA #$40
    BEQ SDCP_W_MOVE
    BRA SDCP_SEG_LOOP
SDCP_DONE:
    RTS

; === LEVEL_COLLISION_Y_RUNTIME ===
; Find the highest collidable floor Y at player_x in the GP layer.
; Input:  LCOL_PX (16-bit) = player world_x
;         LCOL_PY (i8) = player_y lo-byte + player_hh = player_top; surfaces above player_top are ignored
; Output: RESULT = highest floor surface_top (i16, sign-extended from i8)
;         Returns $FF80 (-128) if no collidable surface found at that X.
; Algorithm: for each collidable GP object, check X AABB overlap,
;   compute surface_top = obj_y + half_height (both i8), track max.
; RAM object offsets used: +0-1=world_x(i16), +2=y(i8), +8=collision_flags,
;   +13=half_width, +14=half_height
LEVEL_COLLISION_Y_RUNTIME:
    PSHS X,Y,U       ; Save regs (NOT D - result returns in D)
    
    ; Initialize best_floor = -128 (no floor found)
    LDA #$80         ; -128 as unsigned byte
    STA >LCOL_BEST_Y
    
    ; Check level loaded
    TST >LEVEL_LOADED
    BEQ LCOL_Y_DONE
    
    LDB >LEVEL_GP_COUNT
    BEQ LCOL_Y_DONE
    LDX >LEVEL_GP_PTR  ; X = GP buffer
    
LCOL_Y_LOOP:
    TSTB
    BEQ LCOL_Y_DONE
    PSHS B           ; save count
    
    ; --- Check collision flag (bit 0 at RAM+8) ---
    LDA 8,X
    BITA #$01
    BEQ LCOL_Y_NEXT  ; not collidable
    
    ; --- X AABB overlap: obj_x - hw <= player_x <= obj_x + hw ---
    ; Compute left_edge = obj_x - 0:hw (16-bit)
    LDA 0,X          ; obj_x high byte
    LDB 1,X          ; obj_x low byte
    SUBB 13,X        ; B = obj_x_lo - half_width
    SBCA #0          ; A = obj_x_hi - borrow
    STD >TMPVAL      ; TMPVAL = left_edge
    
    ; Compare player_x >= left_edge (signed 16-bit)
    LDD >LCOL_PX
    CMPD >TMPVAL
    LBLT LCOL_Y_NEXT ; player_x < left_edge → no overlap
    
    ; Compute right_edge = obj_x + 0:hw (16-bit)
    LDA 0,X
    LDB 1,X
    ADDB 13,X        ; B = obj_x_lo + half_width
    ADCA #0          ; A = obj_x_hi + carry
    STD >TMPVAL      ; TMPVAL = right_edge
    
    ; Compare player_x <= right_edge (signed 16-bit)
    LDD >LCOL_PX
    CMPD >TMPVAL
    LBGT LCOL_Y_NEXT ; player_x > right_edge → no overlap
    
    ; --- X overlaps — compute surface_top = obj_y + tile_half_height ---
    LDA 2,X          ; A = obj_y (signed byte)
    ADDA 14,X        ; A = tile surface_top = obj_y + tile_half_height
    ; Filter: skip surfaces above the player's head (surface_top > player_top)
    CMPA >LCOL_PY    ; signed compare surface_top to player_top
    BGT LCOL_Y_NEXT  ; surface_top > player_top → above player's head → skip
    ; Compute landing Y = surface_top + player_half_height
    ADDA >LCOL_PHH   ; A = tile_top + player_hh = where player center lands
    ; Update best_floor if this landing Y > current best
    CMPA >LCOL_BEST_Y
    BLE LCOL_Y_NEXT  ; not better
    STA >LCOL_BEST_Y ; new best landing Y
    
LCOL_Y_NEXT:
    LEAX 15,X        ; next object (stride 15)
    PULS B
    DECB
    BRA LCOL_Y_LOOP
    
LCOL_Y_DONE:
    ; Sign-extend best_floor (i8) → RESULT (i16)
    LDB >LCOL_BEST_Y
    SEX              ; D = sign_extend(B)
    STD RESULT
    
    PULS X,Y,U,PC    ; Restore (NOT D - result stays in D)

; === LEVEL_COLLISION_X_RUNTIME ===
; Find first collidable GP object overlapping player horizontally.
; Input:  LCOL_PX (16-bit) = player world_x
;         LCOL_PY (i8) = player world_y lo byte
;         LCOL_PHW (u8) = player half_width
; Output: RESULT = signed push-out dx (16-bit). Positive=right, negative=left.
; Returns 0 if no overlap found.
; Scratch: uses LCOL_THW for total_hw (preserves LCOL_PHH=player_hh across iterations).
; RAM object offsets: +0-1=world_x(i16), +2=y(i8), +8=collision_flags,
;   +13=half_width, +14=half_height
LEVEL_COLLISION_X_RUNTIME:
    PSHS X,Y,U
    LDD #0
    STD RESULT
    TST >LEVEL_LOADED
    LBEQ LCOL_X_DONE
    LDB >LEVEL_GP_COUNT
    LBEQ LCOL_X_DONE
    LDX >LEVEL_GP_PTR
LCOL_X_LOOP:
    TSTB
    LBEQ LCOL_X_DONE
    PSHS B
    LDA 8,X
    BITA #$01
    LBEQ LCOL_X_NEXT
    LDA >LCOL_PY
    SUBA 2,X
    BPL LCOL_X_YABS
    NEGA
LCOL_X_YABS:
    LDB 14,X
    ADDB >LCOL_PHH
    STB >TMPVAL
    CMPA >TMPVAL
    LBGE LCOL_X_NEXT
    LDA >LCOL_PHW
    ADDA 13,X
    STA >LCOL_THW
    LDA 0,X
    LDB 1,X
    SUBB >LCOL_THW
    SBCA #0
    STD >TMPVAL
    LDD >LCOL_PX
    CMPD >TMPVAL
    LBLT LCOL_X_NEXT
    LDA 0,X
    LDB 1,X
    ADDB >LCOL_THW
    ADCA #0
    STD >TMPVAL
    LDD >LCOL_PX
    CMPD >TMPVAL
    LBGT LCOL_X_NEXT
    LDD >LCOL_PX
    SUBB 1,X
    STB >TMPVAL
    TSTB
    BPL LCOL_X_DXABS
    NEGB
LCOL_X_DXABS:
    NEGB
    ADDB >LCOL_THW
    TFR B,A
    LDB >TMPVAL
    BMI LCOL_X_PUSH_LEFT
    TFR A,B
    SEX
    STD RESULT
    PULS B
    LBRA LCOL_X_DONE
LCOL_X_PUSH_LEFT:
    NEGA
    TFR A,B
    SEX
    STD RESULT
    PULS B
    LBRA LCOL_X_DONE
LCOL_X_NEXT:
    LEAX 15,X
    PULS B
    DECB
    LBRA LCOL_X_LOOP
LCOL_X_DONE:
    LDD RESULT
    PULS X,Y,U,PC

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
PSHS B                  ; Save count

AU_MUSIC_WRITE_LOOP:
LDA ,X+                 ; Load register number
LDB ,X+                 ; Load register value
PSHS X                  ; Save pointer
JSR Sound_Byte          ; Write to PSG using BIOS (DP=$D0)
PULS X                  ; Restore pointer
PULS B                  ; Get counter
DECB                    ; Decrement
BEQ AU_MUSIC_DONE       ; Done if count=0
PSHS B                  ; Save counter
BRA AU_MUSIC_WRITE_LOOP ; Continue

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

; ============================================================================
; DRAW_ANIM_RUNTIME
; Input: X = animation ROM header (_ANIM_XXX)
;        U = 2-byte RAM state (byte0=frame_idx, byte1=ticks_left)
;
; Header layout:
;   byte 0: frame_count
;   byte 1: loop_flag (1=loop, 0=freeze)
;   byte 2: base_ref_count  (static cel layer — drawn before every frame)
;   byte 3: frame_table_offset (= 4 + base_ref_count*2)
;   bytes 4..: FDB ptrs to base_ref _VECNAME_VECTORS
;   at frame_table_offset: FDB ptrs to per-frame data
; ============================================================================
DRAW_ANIM_RUNTIME:
LDA #$18
STA >$D00B          ; ACR=$18: SR shift-out PHI2, enable beam via SR
PSHS D,X,Y,U
; --- Draw base_refs (static cel layer, drawn before every frame) ---
LDB 2,X             ; base_ref_count
BEQ DAR_TICK        ; none: skip to tick management
LEAY 4,X            ; Y = first base_ref FDB entry
DAR_BASE_LOOP:
PSHS B,X,Y
LDX ,Y              ; X = _VECNAME_VECTORS header
LDA >DRAW_ANIM_MIRROR_X
STA >MIRROR_X
CLR >MIRROR_Y
JSR $F1AA           ; DP_to_D0
LDD ,X              ; D = path_count
BEQ DAR_BASE_SKIP
LEAY 2,X            ; Y = first path FDB in vec table
DAR_BASE_PATH_LOOP:
PSHS D,Y
LDX ,Y
JSR Draw_Sync_List_At_With_Mirrors
PULS D,Y
LEAY 2,Y
SUBD #1
BNE DAR_BASE_PATH_LOOP
DAR_BASE_SKIP:
JSR $F1AF           ; DP_to_C8
PULS B,X,Y
LEAY 2,Y            ; next base_ref FDB
DECB
LBNE DAR_BASE_LOOP
; --- Tick counter management ---
DAR_TICK:
LDU 6,S             ; reload U from stack — BIOS may corrupt live U
LDA 1,U             ; ticks_left
BEQ DAR_INIT        ; 0 = first call: initialize frame 0
DECA
BNE DAR_DRAW        ; still on this frame: skip frame advance
; ticks exhausted: advance frame index
LDB ,U              ; current frame_idx
INCB
CMPB ,X             ; frame_count (byte 0)
BLT DAR_NO_WRAP
LDA 1,X             ; loop flag (byte 1)
BEQ DAR_FREEZE      ; loop=0: freeze on last frame
CLRB                ; loop=1: back to frame 0
DAR_NO_WRAP:
STB ,U              ; save new frame_idx
; frame_ptr = X + frame_table_offset + frame_idx*2
LDB ,U              ; new frame_idx
CLRA
LSLB
ROLA                ; D = frame_idx*2
ADDB 3,X            ; D += frame_table_offset (byte 3)
ADCA #0
LEAY D,X            ; Y = &frame_table[frame_idx]
LDY ,Y              ; Y = frame data ptr
LDA ,Y              ; duration_ticks
STA 1,U             ; reset ticks_remaining
BRA DAR_EMIT
DAR_FREEZE:
LDA #1
STA 1,U
LDB ,U              ; last frame_idx
CLRA
LSLB
ROLA
ADDB 3,X
ADCA #0
LEAY D,X
LDY ,Y
BRA DAR_EMIT
DAR_INIT:
; First call: frame_idx=0, load frame 0 duration and draw it
CLRB                ; frame_idx = 0
STB ,U
CLRA                ; D = 0 (frame_idx*2 = 0)
ADDB 3,X            ; B = frame_table_offset (frame 0 offset from header)
ADCA #0
LEAY D,X            ; Y = frame_table[0] entry
LDY ,Y              ; Y = frame 0 data ptr
LDA ,Y              ; A = duration_ticks
STA 1,U             ; ticks_left = duration_ticks
BRA DAR_EMIT
DAR_DRAW:
STA 1,U             ; save decremented ticks
LDB ,U              ; frame_idx
CLRA
LSLB
ROLA
ADDB 3,X
ADCA #0
LEAY D,X
LDY ,Y              ; Y = frame data ptr
DAR_EMIT:
; frame data: byte 0=duration_ticks (skip), byte 1=vec_ref_count
LEAY 1,Y
LDB ,Y+             ; B = vec_ref_count, Y at first vec ptr
BEQ DAR_INLINE
DAR_VEC_LOOP:
PSHS B,Y
LDX ,Y
LDA >DRAW_ANIM_MIRROR_X
STA >MIRROR_X
CLR >MIRROR_Y
JSR $F1AA           ; DP_to_D0
LDD ,X              ; D = path_count
BEQ DAR_VEC_DONE
LEAY 2,X
DAR_VEC_PATH_LOOP:
PSHS D,Y
LDX ,Y
JSR Draw_Sync_List_At_With_Mirrors
PULS D,Y
LEAY 2,Y
SUBD #1
BNE DAR_VEC_PATH_LOOP
DAR_VEC_DONE:
JSR $F1AF           ; DP_to_C8
PULS B,Y
LEAY 2,Y
DECB
BNE DAR_VEC_LOOP
DAR_INLINE:
LDB ,Y+             ; B = inline_path_count
BEQ DAR_DONE
DAR_PATH_LOOP:
PSHS B
TFR Y,X
JSR $F1AA           ; DP_to_D0
LDA >DRAW_ANIM_MIRROR_X
STA >MIRROR_X
CLR >MIRROR_Y
JSR Draw_Sync_List_At_With_Mirrors
JSR $F1AF           ; DP_to_C8
LEAY 5,Y            ; skip intensity + 4-byte header
DAR_SCAN:
LDA ,Y+
CMPA #2
BEQ DAR_PATH_DONE
CMPA #$FF
BNE DAR_SCAN
LEAY 2,Y
BRA DAR_SCAN
DAR_PATH_DONE:
PULS B
DECB
BNE DAR_PATH_LOOP
DAR_DONE:
PULS D,X,Y,U
RTS

;**** PRINT_TEXT String Data ****
PRINT_TEXT_STR_3273774:
    FCC "jump"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_104652296222070:
    FCC "world_1_1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2967882140639741:
    FCC "mario_body"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2967882141252132:
    FCC "mario_walk"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_16466524589896934361:
    FCC "mario_legs_straight"
    FCB $80          ; Vectrex string terminator

