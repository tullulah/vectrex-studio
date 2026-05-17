
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
RAND_SEED            EQU $C880+$14   ; Random seed for RAND() (2 bytes)
DRAW_CIRCLE_XC       EQU $C880+$16   ; Circle center X (1 bytes)
DRAW_CIRCLE_YC       EQU $C880+$17   ; Circle center Y (1 bytes)
DRAW_CIRCLE_DIAM     EQU $C880+$18   ; Circle diameter (1 bytes)
DRAW_CIRCLE_INTENSITY EQU $C880+$19   ; Circle intensity (1 bytes)
DRAW_CIRCLE_RADIUS   EQU $C880+$1A   ; Circle radius (diam/2) - used in segment drawing (1 bytes)
DRAW_CIRCLE_TEMP     EQU $C880+$1B   ; Circle temporary buffer (8 bytes: radius16, a, b, c, d, --, --)  a=0.383r b=0.324r c=0.217r d=0.076r (8 bytes)
DRAW_VEC_INTENSITY   EQU $C880+$23   ; Vector intensity override (0=use vector data) (1 bytes)
DRAW_VEC_X_HI        EQU $C880+$24   ; Vector draw X high byte (16-bit screen_x) (1 bytes)
DRAW_VEC_X           EQU $C880+$25   ; Vector draw X offset (1 bytes)
DRAW_VEC_Y           EQU $C880+$26   ; Vector draw Y offset (1 bytes)
MIRROR_PAD           EQU $C880+$27   ; Safety padding to prevent MIRROR flag corruption (16 bytes)
MIRROR_X             EQU $C880+$37   ; X mirror flag (0=normal, 1=flip) (1 bytes)
MIRROR_Y             EQU $C880+$38   ; Y mirror flag (0=normal, 1=flip) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$39   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$43   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$45   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$47   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$48   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$49   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$4B   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
LEVEL_PTR            EQU $C880+$4D   ; Pointer to currently loaded level header (2 bytes)
LEVEL_LOADED         EQU $C880+$4F   ; Level loaded flag (0=not loaded, 1=loaded) (1 bytes)
LEVEL_WIDTH          EQU $C880+$50   ; Level width (legacy tile API) (1 bytes)
LEVEL_HEIGHT         EQU $C880+$51   ; Level height (legacy tile API) (1 bytes)
LEVEL_TILE_SIZE      EQU $C880+$52   ; Tile size (legacy tile API) (1 bytes)
LEVEL_Y_IDX          EQU $C880+$53   ; SHOW_LEVEL row counter (legacy) (1 bytes)
LEVEL_X_IDX          EQU $C880+$54   ; SHOW_LEVEL column counter (legacy) (1 bytes)
LEVEL_TEMP           EQU $C880+$55   ; SHOW_LEVEL temporary byte (legacy) (1 bytes)
LEVEL_BG_COUNT       EQU $C880+$56   ; BG object count (1 bytes)
LEVEL_GP_COUNT       EQU $C880+$57   ; GP object count (1 bytes)
LEVEL_FG_COUNT       EQU $C880+$58   ; FG object count (1 bytes)
CAMERA_X             EQU $C880+$59   ; Camera X scroll offset (16-bit signed world units) (2 bytes)
CAMERA_Y             EQU $C880+$5B   ; Camera Y scroll offset (16-bit signed world units) (2 bytes)
SCROLL_LIMIT_LEFT    EQU $C880+$5D   ; Camera scroll limit: left world X (2 bytes)
SCROLL_LIMIT_RIGHT   EQU $C880+$5F   ; Camera scroll limit: right world X (2 bytes)
SCROLL_LIMIT_TOP     EQU $C880+$61   ; Camera scroll limit: top world Y (2 bytes)
SCROLL_LIMIT_BOTTOM  EQU $C880+$63   ; Camera scroll limit: bottom world Y (2 bytes)
LEVEL_BG_ROM_PTR     EQU $C880+$65   ; BG layer ROM pointer (2 bytes)
LEVEL_GP_ROM_PTR     EQU $C880+$67   ; GP layer ROM pointer (2 bytes)
LEVEL_FG_ROM_PTR     EQU $C880+$69   ; FG layer ROM pointer (2 bytes)
LEVEL_GP_PTR         EQU $C880+$6B   ; GP active pointer (RAM buffer after LOAD_LEVEL) (2 bytes)
LEVEL_BANK           EQU $C880+$6D   ; Bank ID for current level (for multibank) (1 bytes)
LEVEL_ENEMY_COUNT    EQU $C880+$6E   ; Enemy count from current level header (1 bytes)
LEVEL_ENEMY_INSTANCES_PTR EQU $C880+$6F   ; Ptr to enemy instances table in level bank (2 bytes)
SLR_CUR_X            EQU $C880+$71   ; SHOW_LEVEL: tracked beam X for per-segment clipping (1 bytes)
DRAW_T1_SCALED       EQU $C880+$72   ; SHOW_LEVEL: effective T1 for current object (DRAW_SCALE * object_scale) (1 bytes)
LEVEL_GP_BUFFER      EQU $C880+$73   ; GP objects RAM buffer (max 32 objects × 15 bytes) (480 bytes)
LCOL_PX              EQU $C880+$253   ; LEVEL_COLLISION player world_x input (16-bit) (2 bytes)
LCOL_BEST_Y          EQU $C880+$255   ; LEVEL_COLLISION_Y best floor y found (16-bit signed) (2 bytes)
LCOL_PY              EQU $C880+$257   ; LEVEL_COLLISION player_top (16-bit signed) (2 bytes)
LCOL_PHH             EQU $C880+$259   ; LEVEL_COLLISION player half_height (1 bytes)
LCOL_PHW             EQU $C880+$25A   ; LEVEL_COLLISION_X player half_width (1 bytes)
LCOL_THW             EQU $C880+$25B   ; LEVEL_COLLISION_X total half_width (player_hw + obj_hw scratch) (1 bytes)
UGPC_OUTER_IDX       EQU $C880+$25C   ; GP-GP outer loop index (1 bytes)
UGPC_OUTER_MAX       EQU $C880+$25D   ; GP-GP outer loop max (count-1) (1 bytes)
UGPC_INNER_IDX       EQU $C880+$25E   ; GP-GP inner loop index (1 bytes)
UGPC_DX              EQU $C880+$25F   ; GP-GP |dx| (16-bit) (2 bytes)
UGPC_DIST            EQU $C880+$261   ; GP-GP Manhattan distance (16-bit) (2 bytes)
UGFC_GP_IDX          EQU $C880+$263   ; GP-FG outer loop GP index (1 bytes)
UGFC_FG_COUNT        EQU $C880+$264   ; GP-FG inner loop FG count (1 bytes)
UGFC_DX              EQU $C880+$265   ; GP-FG |dx| (1 bytes)
UGFC_DY              EQU $C880+$266   ; GP-FG |dy| (1 bytes)
ENEMY_POOL           EQU $C880+$267   ; Enemy instances pool (active+x+y+type_ptr+action+ai+hp+wp_idx+wp_ptr+wp_count+sm_state+sm_timer × N) (136 bytes)
ENEMY_LOOP_IDX       EQU $C880+$2EF   ; Enemy loop counter (1 bytes)
ENEMY_COUNT          EQU $C880+$2F0   ; Active enemy count (1 bytes)
ENEMY_SCRATCH_PTR    EQU $C880+$2F1   ; Scratch pointer for enemy iteration (2 bytes)
ENEMY_SCRATCH_X      EQU $C880+$2F3   ; Enemy scratch X (2 bytes)
ENEMY_SCRATCH_Y      EQU $C880+$2F5   ; Enemy scratch Y (2 bytes)
ANIM_ENEMY_ENEMY1_WALK_STATE EQU $C880+$2F7   ; Enemy 'enemy1' action 'walk' animation state (frame_idx, ticks_left) (2 bytes)
ANIM_ENEMY_TITCHI_WALK_STATE EQU $C880+$2F9   ; Enemy 'titchi' action 'walk' animation state (frame_idx, ticks_left) (2 bytes)
TEXT_SCALE_H         EQU $C880+$2FB   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$2FC   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
ANIM_PLAYER_WALK_STATE EQU $C880+$2FD   ; DRAW_ANIM state for PLAYER_WALK (frame_idx, ticks_left) (2 bytes)
DRAW_ANIM_MIRROR_X   EQU $C880+$2FF   ; DRAW_ANIM mirror X flag (0=normal, 1=flip) (1 bytes)
DRAW_ANIM_SCALE      EQU $C880+$300   ; DRAW_ANIM T1 scale ($7F=normal) (1 bytes)
DRAW_ANIM_SPEED_MUL  EQU $C880+$301   ; DRAW_ANIM tick multiplier (1=normal) (1 bytes)
DRAW_SCALE           EQU $C880+$302   ; Current T1 scale for Draw_Sync_List_At_With_Mirrors ($7F=normal) (1 bytes)
VAR_ARG0             EQU $C880+$303   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $C880+$305   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $C880+$307   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $C880+$309   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $C880+$30B   ; Function argument 4 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $C880+$30D   ; Current ROM bank ID (multibank tracking) (1 bytes)
VAR_BALL_LAUNCHED    EQU $C880+$30E   ; User variable: ball_launched (2 bytes)
VAR_GAME_STATE       EQU $C880+$310   ; User variable: game_state (2 bytes)
VAR_SCORE            EQU $C880+$312   ; User variable: score (2 bytes)
VAR_LIVES            EQU $C880+$314   ; User variable: lives (2 bytes)
VAR_CURRENT_LEVEL    EQU $C880+$316   ; User variable: current_level (2 bytes)
VAR_TIME_LEFT        EQU $C880+$318   ; User variable: time_left (2 bytes)
VAR_ENEMY_COUNT      EQU $C880+$31A   ; User variable: enemy_count (2 bytes)
VAR_FRAME_TIMER      EQU $C880+$31C   ; User variable: frame_timer (2 bytes)
VAR_NEXT_IS_BOSS     EQU $C880+$31E   ; User variable: next_is_boss (2 bytes)
VAR_PLAYER_X         EQU $C880+$320   ; User variable: player_x (2 bytes)
VAR_PLAYER_Y         EQU $C880+$322   ; User variable: player_y (2 bytes)
VAR_PLAYER_VX        EQU $C880+$324   ; User variable: player_vx (2 bytes)
VAR_PLAYER_VY        EQU $C880+$326   ; User variable: player_vy (2 bytes)
VAR_PLAYER_FACING    EQU $C880+$328   ; User variable: player_facing (2 bytes)
VAR_PLAYER_ON_GROUND EQU $C880+$32A   ; User variable: player_on_ground (2 bytes)
VAR_FLOOR_Y          EQU $C880+$32C   ; User variable: floor_y (2 bytes)
VAR_PREV_Y           EQU $C880+$32E   ; User variable: prev_y (2 bytes)
VAR_CAMERA_Y         EQU $C880+$330   ; User variable: camera_y (2 bytes)
VAR_SHOOT_COOLDOWN   EQU $C880+$332   ; User variable: shoot_cooldown (2 bytes)
VAR_PLAYER_HAS_POWER EQU $C880+$334   ; User variable: player_has_power (2 bytes)
VAR_SNOW_LIFE_MAX    EQU $C880+$336   ; User variable: snow_life_max (2 bytes)
VAR_SNOW_SPAWN_VX    EQU $C880+$338   ; User variable: snow_spawn_vx (2 bytes)
VAR_SNOW0_ACTIVE     EQU $C880+$33A   ; User variable: snow0_active (2 bytes)
VAR_SNOW0_X          EQU $C880+$33C   ; User variable: snow0_x (2 bytes)
VAR_SNOW0_Y          EQU $C880+$33E   ; User variable: snow0_y (2 bytes)
VAR_SNOW0_VX         EQU $C880+$340   ; User variable: snow0_vx (2 bytes)
VAR_SNOW0_VY         EQU $C880+$342   ; User variable: snow0_vy (2 bytes)
VAR_SNOW0_LIFE       EQU $C880+$344   ; User variable: snow0_life (2 bytes)
VAR_SNOW1_ACTIVE     EQU $C880+$346   ; User variable: snow1_active (2 bytes)
VAR_SNOW1_X          EQU $C880+$348   ; User variable: snow1_x (2 bytes)
VAR_SNOW1_Y          EQU $C880+$34A   ; User variable: snow1_y (2 bytes)
VAR_SNOW1_VX         EQU $C880+$34C   ; User variable: snow1_vx (2 bytes)
VAR_SNOW1_VY         EQU $C880+$34E   ; User variable: snow1_vy (2 bytes)
VAR_SNOW1_LIFE       EQU $C880+$350   ; User variable: snow1_life (2 bytes)
VAR_SNOW2_ACTIVE     EQU $C880+$352   ; User variable: snow2_active (2 bytes)
VAR_SNOW2_X          EQU $C880+$354   ; User variable: snow2_x (2 bytes)
VAR_SNOW2_Y          EQU $C880+$356   ; User variable: snow2_y (2 bytes)
VAR_SNOW2_VX         EQU $C880+$358   ; User variable: snow2_vx (2 bytes)
VAR_SNOW2_VY         EQU $C880+$35A   ; User variable: snow2_vy (2 bytes)
VAR_SNOW2_LIFE       EQU $C880+$35C   ; User variable: snow2_life (2 bytes)
VAR_ELAPSED          EQU $C880+$35E   ; User variable: elapsed (2 bytes)
VAR_I                EQU $C880+$360   ; User variable: i (2 bytes)
VAR_EX               EQU $C880+$362   ; User variable: ex (2 bytes)
VAR_EY               EQU $C880+$364   ; User variable: ey (2 bytes)
VAR_IDX              EQU $C880+$366   ; User variable: idx (2 bytes)
VAR_THW              EQU $C880+$368   ; User variable: thw (2 bytes)
VAR_THH              EQU $C880+$36A   ; User variable: thh (2 bytes)
VAR_DX               EQU $C880+$36C   ; User variable: dx (2 bytes)
VAR_DY               EQU $C880+$36E   ; User variable: dy (2 bytes)
VAR_NEW_STATE        EQU $C880+$370   ; User variable: new_state (2 bytes)
VAR_TICKS            EQU $C880+$372   ; User variable: ticks (2 bytes)
VAR_THAW_TIMERS      EQU $C880+$374   ; User variable: thaw_timers (2 bytes)
VAR_ST               EQU $C880+$376   ; User variable: st (2 bytes)
VAR_BALL_ROLLING     EQU $C880+$378   ; User variable: ball_rolling (2 bytes)
VAR_N                EQU $C880+$37A   ; User variable: n (2 bytes)
VAR_BALL_VX_ARR      EQU $C880+$37C   ; User variable: ball_vx_arr (2 bytes)
VAR_BALL_VY_ARR      EQU $C880+$37E   ; User variable: ball_vy_arr (2 bytes)
VAR_BALL_BOUNCES     EQU $C880+$380   ; User variable: ball_bounces (2 bytes)
VAR_BALL_COLLIDED    EQU $C880+$382   ; User variable: ball_collided (2 bytes)
VAR_FOUND            EQU $C880+$384   ; User variable: found (2 bytes)
VAR_PREV_BY          EQU $C880+$386   ; User variable: prev_by (2 bytes)
VAR_BX               EQU $C880+$388   ; User variable: bx (2 bytes)
VAR_BY               EQU $C880+$38A   ; User variable: by (2 bytes)
VAR_FLOOR            EQU $C880+$38C   ; User variable: floor (2 bytes)
VAR_K                EQU $C880+$38E   ; User variable: k (2 bytes)
VAR_J                EQU $C880+$390   ; User variable: j (2 bytes)
VAR_SKIP             EQU $C880+$392   ; User variable: skip (2 bytes)
VAR_EJX              EQU $C880+$394   ; User variable: ejx (2 bytes)
VAR_EJY              EQU $C880+$396   ; User variable: ejy (2 bytes)
VAR_OLD_VX           EQU $C880+$398   ; User variable: old_vx (2 bytes)
VAR_THAW_TIMERS_DATA EQU $C880+$39A   ; Mutable array 'thaw_timers' data (8 elements x 2 bytes) (16 bytes)
VAR_BALL_ROLLING_DATA EQU $C880+$3AA   ; Mutable array 'ball_rolling' data (8 elements x 2 bytes) (16 bytes)
VAR_BALL_VX_ARR_DATA EQU $C880+$3BA   ; Mutable array 'ball_vx_arr' data (8 elements x 2 bytes) (16 bytes)
VAR_BALL_VY_ARR_DATA EQU $C880+$3CA   ; Mutable array 'ball_vy_arr' data (8 elements x 2 bytes) (16 bytes)
VAR_BALL_BOUNCES_DATA EQU $C880+$3DA   ; Mutable array 'ball_bounces' data (8 elements x 2 bytes) (16 bytes)
VAR_BALL_COLLIDED_DATA EQU $C880+$3EA   ; Mutable array 'ball_collided' data (8 elements x 2 bytes) (16 bytes)
PSG_MUSIC_PTR        EQU $C880+$3FA   ; PSG music data pointer (2 bytes)
PSG_MUSIC_START      EQU $C880+$3FC   ; PSG music start pointer (for loops) (2 bytes)
PSG_MUSIC_ACTIVE     EQU $C880+$3FE   ; PSG music active flag (1 bytes)
PSG_IS_PLAYING       EQU $C880+$3FF   ; PSG playing flag (1 bytes)
PSG_DELAY_FRAMES     EQU $C880+$400   ; PSG frame delay counter (1 bytes)
PSG_MUSIC_BANK       EQU $C880+$401   ; PSG music bank ID (for multibank) (1 bytes)
SFX_PTR              EQU $C880+$402   ; SFX data pointer (2 bytes)
SFX_ACTIVE           EQU $C880+$404   ; SFX active flag (1 bytes)
SFX_BANK             EQU $C880+$405   ; SFX bank ID (for multibank) (1 bytes)
; Array length constants
ARRAY_THAW_TIMERS_LEN         EQU 8   ; 8 elements
ARRAY_BALL_ROLLING_LEN         EQU 8   ; 8 elements
ARRAY_BALL_VX_ARR_LEN         EQU 8   ; 8 elements
ARRAY_BALL_VY_ARR_LEN         EQU 8   ; 8 elements
ARRAY_BALL_BOUNCES_LEN         EQU 8   ; 8 elements
ARRAY_BALL_COLLIDED_LEN         EQU 8   ; 8 elements


; ================================================
    ORG $0000  ; Sequential bank model

; Function: update_player (Bank #1)
update_player:
    ; CLAMP: Clamp value to range [min, max]
    JSR J1X_BUILTIN
    STD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #32
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR DIV16       ; D = X / D
    STD TMPPTR     ; Save value
    LDD #-4
    STD TMPPTR+2   ; Save min
    LDD #4
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
    STD VAR_PLAYER_VX
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_VX
    CMPD TMPVAL
    LBGT .CMP_49_TRUE
    LDD #0
    LBRA .CMP_49_END
.CMP_49_TRUE:
    LDD #1
.CMP_49_END:
    LBEQ IF_NEXT_101
    LDD #0
    STD VAR_PLAYER_FACING
    LBRA IF_END_100
IF_NEXT_101:
IF_END_100:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_VX
    CMPD TMPVAL
    LBLT .CMP_50_TRUE
    LDD #0
    LBRA .CMP_50_END
.CMP_50_TRUE:
    LDD #1
.CMP_50_END:
    LBEQ IF_NEXT_103
    LDD #1
    STD VAR_PLAYER_FACING
    LBRA IF_END_102
IF_NEXT_103:
IF_END_102:
    ; CLAMP: Clamp value to range [min, max]
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_VX
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD TMPPTR     ; Save value
    LDD #-96  ; const WORLD_X_MIN
    STD TMPPTR+2   ; Save min
    LDD #95  ; const WORLD_X_MAX
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
    STD VAR_PLAYER_X
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_ON_GROUND
    CMPD TMPVAL
    LBEQ .CMP_51_TRUE
    LDD #0
    LBRA .CMP_51_END
.CMP_51_TRUE:
    LDD #1
.CMP_51_END:
    LBEQ IF_NEXT_105
    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed
    BITA #$01
    BNE .J1B1_1_ON
    LDD #0
    BRA .J1B1_1_END
.J1B1_1_ON:
    LDD #1
.J1B1_1_END:
    STD RESULT
    LBEQ IF_NEXT_107
    LDD #11  ; const JUMP_SPEED
    STD VAR_PLAYER_VY
    LDD #0
    STD VAR_PLAYER_ON_GROUND
    LBRA IF_END_106
IF_NEXT_107:
IF_END_106:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_ON_GROUND
    CMPD TMPVAL
    LBEQ .CMP_52_TRUE
    LDD #0
    LBRA .CMP_52_END
.CMP_52_TRUE:
    LDD #1
.CMP_52_END:
    LBEQ IF_NEXT_109
    ; ===== LEVEL_COLLISION_Y builtin =====
    LDD >VAR_PLAYER_X
    STD >LCOL_PX         ; store player world_x (16-bit)
    LDD #11  ; const PLAYER_HH
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
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLOOR_Y
    CMPD TMPVAL
    LBLT .CMP_53_TRUE
    LDD #0
    LBRA .CMP_53_END
.CMP_53_TRUE:
    LDD #1
.CMP_53_END:
    LBEQ IF_NEXT_111
    LDD #0
    STD VAR_PLAYER_ON_GROUND
    LBRA IF_END_110
IF_NEXT_111:
IF_END_110:
    LBRA IF_END_108
IF_NEXT_109:
IF_END_108:
    LBRA IF_END_104
IF_NEXT_105:
IF_END_104:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_ON_GROUND
    CMPD TMPVAL
    LBEQ .CMP_54_TRUE
    LDD #0
    LBRA .CMP_54_END
.CMP_54_TRUE:
    LDD #1
.CMP_54_END:
    LBEQ IF_NEXT_113
    LDD >VAR_PLAYER_VY
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1  ; const GRAVITY
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_PLAYER_VY
    LDD #-1
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #12  ; const MAX_FALL_SPEED
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_VY
    CMPD TMPVAL
    LBLT .CMP_55_TRUE
    LDD #0
    LBRA .CMP_55_END
.CMP_55_TRUE:
    LDD #1
.CMP_55_END:
    LBEQ IF_NEXT_115
    LDD #-1
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #12  ; const MAX_FALL_SPEED
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD VAR_PLAYER_VY
    LBRA IF_END_114
IF_NEXT_115:
IF_END_114:
    LDD >VAR_PLAYER_Y
    STD VAR_PREV_Y
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_VY
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_PLAYER_Y
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_VY
    CMPD TMPVAL
    LBLE .CMP_56_TRUE
    LDD #0
    LBRA .CMP_56_END
.CMP_56_TRUE:
    LDD #1
.CMP_56_END:
    LBEQ IF_NEXT_117
    ; ===== LEVEL_COLLISION_Y builtin =====
    LDD >VAR_PLAYER_X
    STD >LCOL_PX         ; store player world_x (16-bit)
    LDD #11  ; const PLAYER_HH
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
    LDD >VAR_FLOOR_Y
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_Y
    CMPD TMPVAL
    LBLE .CMP_57_TRUE
    LDD #0
    LBRA .CMP_57_END
.CMP_57_TRUE:
    LDD #1
.CMP_57_END:
    LBEQ IF_NEXT_119
    LDD >VAR_FLOOR_Y
    STD VAR_PLAYER_Y
    LDD #0
    STD VAR_PLAYER_VY
    LDD #1
    STD VAR_PLAYER_ON_GROUND
    LBRA IF_END_118
IF_NEXT_119:
IF_END_118:
    LBRA IF_END_116
IF_NEXT_117:
IF_END_116:
    LBRA IF_END_112
IF_NEXT_113:
IF_END_112:
    LDD #127  ; const WORLD_Y_MAX
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_Y
    CMPD TMPVAL
    LBGT .CMP_58_TRUE
    LDD #0
    LBRA .CMP_58_END
.CMP_58_TRUE:
    LDD #1
.CMP_58_END:
    LBEQ IF_NEXT_121
    LDD #127  ; const WORLD_Y_MAX
    STD VAR_PLAYER_Y
    LDD #0
    STD VAR_PLAYER_VY
    LBRA IF_END_120
IF_NEXT_121:
IF_END_120:
    LDD #-2403  ; const WORLD_Y_MIN
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_Y
    CMPD TMPVAL
    LBLT .CMP_59_TRUE
    LDD #0
    LBRA .CMP_59_END
.CMP_59_TRUE:
    LDD #1
.CMP_59_END:
    LBEQ IF_NEXT_123
    LDD #-2403  ; const WORLD_Y_MIN
    STD VAR_PLAYER_Y
    LDD #0
    STD VAR_PLAYER_VY
    LDD #1
    STD VAR_PLAYER_ON_GROUND
    LBRA IF_END_122
IF_NEXT_123:
IF_END_122:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SHOOT_COOLDOWN
    CMPD TMPVAL
    LBGT .CMP_60_TRUE
    LDD #0
    LBRA .CMP_60_END
.CMP_60_TRUE:
    LDD #1
.CMP_60_END:
    LBEQ IF_NEXT_125
    LDD >VAR_SHOOT_COOLDOWN
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_SHOOT_COOLDOWN
    LBRA IF_END_124
IF_NEXT_125:
IF_END_124:
    LDA >$C80F   ; Vec_Btns_1: bit1=1 means btn2 pressed
    BITA #$02
    BNE .J1B2_2_ON
    LDD #0
    BRA .J1B2_2_END
.J1B2_2_ON:
    LDD #1
.J1B2_2_END:
    STD RESULT
    LBEQ IF_NEXT_127
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SHOOT_COOLDOWN
    CMPD TMPVAL
    LBEQ .CMP_61_TRUE
    LDD #0
    LBRA .CMP_61_END
.CMP_61_TRUE:
    LDD #1
.CMP_61_END:
    LBEQ IF_NEXT_129
    LDD #0
    STD VAR_BALL_LAUNCHED
    JSR TRAMP_try_launch_ball  ; cross-bank trampoline (bank #1 -> bank #0)
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BALL_LAUNCHED
    CMPD TMPVAL
    LBEQ .CMP_62_TRUE
    LDD #0
    LBRA .CMP_62_END
.CMP_62_TRUE:
    LDD #1
.CMP_62_END:
    LBEQ IF_NEXT_131
    LDD #5  ; const SNOW_SPEED
    STD VAR_SNOW_SPAWN_VX
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_FACING
    CMPD TMPVAL
    LBEQ .CMP_63_TRUE
    LDD #0
    LBRA .CMP_63_END
.CMP_63_TRUE:
    LDD #1
.CMP_63_END:
    LBEQ IF_NEXT_133
    LDD #-1
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #5  ; const SNOW_SPEED
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD VAR_SNOW_SPAWN_VX
    LBRA IF_END_132
IF_NEXT_133:
IF_END_132:
    JSR TRAMP_try_shoot  ; cross-bank trampoline (bank #1 -> bank #0)
    LBRA IF_END_130
IF_NEXT_131:
IF_END_130:
    LBRA IF_END_128
IF_NEXT_129:
IF_END_128:
    LBRA IF_END_126
IF_NEXT_127:
IF_END_126:
    RTS

; Function: update_snowballs (Bank #1)
update_snowballs:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SNOW0_ACTIVE
    CMPD TMPVAL
    LBEQ .CMP_70_TRUE
    LDD #0
    LBRA .CMP_70_END
.CMP_70_TRUE:
    LDD #1
.CMP_70_END:
    LBEQ IF_NEXT_147
    LDD >VAR_SNOW0_VY
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1  ; const GRAVITY
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_SNOW0_VY
    LDD #-1
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #12  ; const MAX_FALL_SPEED
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SNOW0_VY
    CMPD TMPVAL
    LBLT .CMP_71_TRUE
    LDD #0
    LBRA .CMP_71_END
.CMP_71_TRUE:
    LDD #1
.CMP_71_END:
    LBEQ IF_NEXT_149
    LDD #-1
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #12  ; const MAX_FALL_SPEED
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD VAR_SNOW0_VY
    LBRA IF_END_148
IF_NEXT_149:
IF_END_148:
    LDD >VAR_SNOW0_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_SNOW0_VX
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_SNOW0_X
    LDD >VAR_SNOW0_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_SNOW0_VY
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_SNOW0_Y
    LDD >VAR_SNOW0_LIFE
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_SNOW0_LIFE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SNOW0_LIFE
    CMPD TMPVAL
    LBLE .CMP_72_TRUE
    LDD #0
    LBRA .CMP_72_END
.CMP_72_TRUE:
    LDD #1
.CMP_72_END:
    LBEQ IF_NEXT_151
    LDD #0
    STD VAR_SNOW0_ACTIVE
    LBRA IF_END_150
IF_NEXT_151:
IF_END_150:
    LDD #-110
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SNOW0_Y
    CMPD TMPVAL
    LBLT .CMP_73_TRUE
    LDD #0
    LBRA .CMP_73_END
.CMP_73_TRUE:
    LDD #1
.CMP_73_END:
    LBEQ IF_NEXT_153
    LDD #0
    STD VAR_SNOW0_ACTIVE
    LBRA IF_END_152
IF_NEXT_153:
IF_END_152:
    LDD #-127
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SNOW0_X
    CMPD TMPVAL
    LBLT .CMP_74_TRUE
    LDD #0
    LBRA .CMP_74_END
.CMP_74_TRUE:
    LDD #1
.CMP_74_END:
    LBEQ IF_NEXT_155
    LDD #0
    STD VAR_SNOW0_ACTIVE
    LBRA IF_END_154
IF_NEXT_155:
IF_END_154:
    LDD #127
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SNOW0_X
    CMPD TMPVAL
    LBGT .CMP_75_TRUE
    LDD #0
    LBRA .CMP_75_END
.CMP_75_TRUE:
    LDD #1
.CMP_75_END:
    LBEQ IF_NEXT_157
    LDD #0
    STD VAR_SNOW0_ACTIVE
    LBRA IF_END_156
IF_NEXT_157:
IF_END_156:
    LBRA IF_END_146
IF_NEXT_147:
IF_END_146:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SNOW1_ACTIVE
    CMPD TMPVAL
    LBEQ .CMP_76_TRUE
    LDD #0
    LBRA .CMP_76_END
.CMP_76_TRUE:
    LDD #1
.CMP_76_END:
    LBEQ IF_NEXT_159
    LDD >VAR_SNOW1_VY
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1  ; const GRAVITY
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_SNOW1_VY
    LDD #-1
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #12  ; const MAX_FALL_SPEED
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SNOW1_VY
    CMPD TMPVAL
    LBLT .CMP_77_TRUE
    LDD #0
    LBRA .CMP_77_END
.CMP_77_TRUE:
    LDD #1
.CMP_77_END:
    LBEQ IF_NEXT_161
    LDD #-1
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #12  ; const MAX_FALL_SPEED
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD VAR_SNOW1_VY
    LBRA IF_END_160
IF_NEXT_161:
IF_END_160:
    LDD >VAR_SNOW1_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_SNOW1_VX
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_SNOW1_X
    LDD >VAR_SNOW1_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_SNOW1_VY
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_SNOW1_Y
    LDD >VAR_SNOW1_LIFE
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_SNOW1_LIFE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SNOW1_LIFE
    CMPD TMPVAL
    LBLE .CMP_78_TRUE
    LDD #0
    LBRA .CMP_78_END
.CMP_78_TRUE:
    LDD #1
.CMP_78_END:
    LBEQ IF_NEXT_163
    LDD #0
    STD VAR_SNOW1_ACTIVE
    LBRA IF_END_162
IF_NEXT_163:
IF_END_162:
    LDD #-110
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SNOW1_Y
    CMPD TMPVAL
    LBLT .CMP_79_TRUE
    LDD #0
    LBRA .CMP_79_END
.CMP_79_TRUE:
    LDD #1
.CMP_79_END:
    LBEQ IF_NEXT_165
    LDD #0
    STD VAR_SNOW1_ACTIVE
    LBRA IF_END_164
IF_NEXT_165:
IF_END_164:
    LDD #-127
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SNOW1_X
    CMPD TMPVAL
    LBLT .CMP_80_TRUE
    LDD #0
    LBRA .CMP_80_END
.CMP_80_TRUE:
    LDD #1
.CMP_80_END:
    LBEQ IF_NEXT_167
    LDD #0
    STD VAR_SNOW1_ACTIVE
    LBRA IF_END_166
IF_NEXT_167:
IF_END_166:
    LDD #127
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SNOW1_X
    CMPD TMPVAL
    LBGT .CMP_81_TRUE
    LDD #0
    LBRA .CMP_81_END
.CMP_81_TRUE:
    LDD #1
.CMP_81_END:
    LBEQ IF_NEXT_169
    LDD #0
    STD VAR_SNOW1_ACTIVE
    LBRA IF_END_168
IF_NEXT_169:
IF_END_168:
    LBRA IF_END_158
IF_NEXT_159:
IF_END_158:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SNOW2_ACTIVE
    CMPD TMPVAL
    LBEQ .CMP_82_TRUE
    LDD #0
    LBRA .CMP_82_END
.CMP_82_TRUE:
    LDD #1
.CMP_82_END:
    LBEQ IF_NEXT_171
    LDD >VAR_SNOW2_VY
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1  ; const GRAVITY
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_SNOW2_VY
    LDD #-1
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #12  ; const MAX_FALL_SPEED
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SNOW2_VY
    CMPD TMPVAL
    LBLT .CMP_83_TRUE
    LDD #0
    LBRA .CMP_83_END
.CMP_83_TRUE:
    LDD #1
.CMP_83_END:
    LBEQ IF_NEXT_173
    LDD #-1
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #12  ; const MAX_FALL_SPEED
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD VAR_SNOW2_VY
    LBRA IF_END_172
IF_NEXT_173:
IF_END_172:
    LDD >VAR_SNOW2_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_SNOW2_VX
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_SNOW2_X
    LDD >VAR_SNOW2_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_SNOW2_VY
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_SNOW2_Y
    LDD >VAR_SNOW2_LIFE
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_SNOW2_LIFE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SNOW2_LIFE
    CMPD TMPVAL
    LBLE .CMP_84_TRUE
    LDD #0
    LBRA .CMP_84_END
.CMP_84_TRUE:
    LDD #1
.CMP_84_END:
    LBEQ IF_NEXT_175
    LDD #0
    STD VAR_SNOW2_ACTIVE
    LBRA IF_END_174
IF_NEXT_175:
IF_END_174:
    LDD #-110
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SNOW2_Y
    CMPD TMPVAL
    LBLT .CMP_85_TRUE
    LDD #0
    LBRA .CMP_85_END
.CMP_85_TRUE:
    LDD #1
.CMP_85_END:
    LBEQ IF_NEXT_177
    LDD #0
    STD VAR_SNOW2_ACTIVE
    LBRA IF_END_176
IF_NEXT_177:
IF_END_176:
    LDD #-127
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SNOW2_X
    CMPD TMPVAL
    LBLT .CMP_86_TRUE
    LDD #0
    LBRA .CMP_86_END
.CMP_86_TRUE:
    LDD #1
.CMP_86_END:
    LBEQ IF_NEXT_179
    LDD #0
    STD VAR_SNOW2_ACTIVE
    LBRA IF_END_178
IF_NEXT_179:
IF_END_178:
    LDD #127
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SNOW2_X
    CMPD TMPVAL
    LBGT .CMP_87_TRUE
    LDD #0
    LBRA .CMP_87_END
.CMP_87_TRUE:
    LDD #1
.CMP_87_END:
    LBEQ IF_NEXT_181
    LDD #0
    STD VAR_SNOW2_ACTIVE
    LBRA IF_END_180
IF_NEXT_181:
IF_END_180:
    LBRA IF_END_170
IF_NEXT_171:
IF_END_170:
    RTS

;***************************************************************************
; ASSETS IN BANK #1 (19 assets)
;***************************************************************************

; Generated from Yukidama-Ondo.vmus (internal name: Imported MIDI)
; Tempo: 120 BPM, Total events: 637 (PSG Direct format)
; Format: FCB count, FCB reg, val, ... (per frame), FCB 0 (end)

_YUKIDAMA_ONDO_MUSIC:
    ; Frame-based PSG register writes
    FCB     0              ; Delay 0 frames (maintain previous state)
    FCB     10              ; Frame 0 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $FC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $FC             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 3 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $FC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 8 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 10 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 13 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 18 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 19 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $FC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $FC             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 22 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $FC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     4              ; Frame 28 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 30 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 38 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     13              ; Delay 13 frames (maintain previous state)
    FCB     10              ; Frame 51 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $D4             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 59 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     11              ; Delay 11 frames (maintain previous state)
    FCB     6              ; Frame 70 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     4              ; Frame 79 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 81 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 89 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 91 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     4              ; Frame 100 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 102 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 110 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 111 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     19              ; Delay 19 frames (maintain previous state)
    FCB     4              ; Frame 130 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 132 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 135 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     7              ; Delay 7 frames (maintain previous state)
    FCB     8              ; Frame 142 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 145 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     8              ; Frame 153 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 156 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     6              ; Frame 162 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 170 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 172 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     4              ; Frame 181 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 183 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 191 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 193 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     4              ; Frame 202 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 204 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     11              ; Delay 11 frames (maintain previous state)
    FCB     4              ; Frame 215 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 217 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     4              ; Frame 229 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 231 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     11              ; Delay 11 frames (maintain previous state)
    FCB     4              ; Frame 242 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 244 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $70             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $70             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $8D             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     19              ; Delay 19 frames (maintain previous state)
    FCB     4              ; Frame 263 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 275 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $9F             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     18              ; Delay 18 frames (maintain previous state)
    FCB     4              ; Frame 293 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     33              ; Delay 33 frames (maintain previous state)
    FCB     10              ; Frame 326 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 329 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 334 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 336 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 344 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 346 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     4              ; Frame 355 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 356 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $FC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $3E             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 359 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     16              ; Delay 16 frames (maintain previous state)
    FCB     4              ; Frame 375 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 377 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $5E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 380 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $5E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     15              ; Delay 15 frames (maintain previous state)
    FCB     4              ; Frame 395 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 397 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $5E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $F9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 401 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $5E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 406 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 407 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $59             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 410 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $59             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 415 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 417 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $5E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     4              ; Frame 426 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 428 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 436 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 438 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $FC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $3E             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 441 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     16              ; Delay 16 frames (maintain previous state)
    FCB     4              ; Frame 457 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     8              ; Frame 458 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $3E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 461 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     18              ; Delay 18 frames (maintain previous state)
    FCB     8              ; Frame 479 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 482 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     7              ; Delay 7 frames (maintain previous state)
    FCB     10              ; Frame 489 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 492 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 497 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 498 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     4              ; Frame 507 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 509 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 517 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 519 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $E1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $1B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 522 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     4              ; Frame 528 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 530 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 538 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 540 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7A             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 543 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     17              ; Delay 17 frames (maintain previous state)
    FCB     8              ; Frame 560 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $7A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 563 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     7              ; Delay 7 frames (maintain previous state)
    FCB     10              ; Frame 570 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $36             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $02             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 573 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     4              ; Frame 579 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 581 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7A             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $F9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 584 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 589 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 590 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $DC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $36             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $02             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 593 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 598 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 601 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $77             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $C2             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 604 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $77             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 609 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 611 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $70             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 619 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     22              ; Delay 22 frames (maintain previous state)
    FCB     6              ; Frame 641 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     4              ; Frame 650 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 652 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 655 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 660 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 662 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 670 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 672 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     4              ; Frame 681 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 683 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 686 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     16              ; Delay 16 frames (maintain previous state)
    FCB     4              ; Frame 702 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 703 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 706 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     15              ; Delay 15 frames (maintain previous state)
    FCB     4              ; Frame 721 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 723 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $36             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $02             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 727 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 732 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 734 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 737 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 742 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 743 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     4              ; Frame 752 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 754 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 762 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 764 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 767 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     16              ; Delay 16 frames (maintain previous state)
    FCB     4              ; Frame 783 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     8              ; Frame 784 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $51             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 787 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     18              ; Delay 18 frames (maintain previous state)
    FCB     8              ; Frame 805 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $36             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 808 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     7              ; Delay 7 frames (maintain previous state)
    FCB     10              ; Frame 815 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 818 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 823 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 826 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 834 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 835 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 843 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 845 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 848 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     16              ; Delay 16 frames (maintain previous state)
    FCB     4              ; Frame 864 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 866 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 869 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     16              ; Delay 16 frames (maintain previous state)
    FCB     4              ; Frame 885 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 886 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $36             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $02             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 889 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 894 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 896 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $E1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $1B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     19              ; Delay 19 frames (maintain previous state)
    FCB     4              ; Frame 915 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 917 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $EE             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     4              ; Frame 926 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 927 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $FC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $3E             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     18              ; Delay 18 frames (maintain previous state)
    FCB     4              ; Frame 945 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     33              ; Delay 33 frames (maintain previous state)
    FCB     10              ; Frame 978 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 981 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 986 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 988 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 996 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 998 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     4              ; Frame 1007 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1009 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $FC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $3E             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1012 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1017 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 1029 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1032 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1037 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     13              ; Delay 13 frames (maintain previous state)
    FCB     10              ; Frame 1050 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $F9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1053 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1058 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1060 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $C2             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1063 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1068 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 1069 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     4              ; Frame 1078 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1080 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $70             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 1088 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1090 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1093 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     16              ; Delay 16 frames (maintain previous state)
    FCB     4              ; Frame 1109 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 1111 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1114 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     17              ; Delay 17 frames (maintain previous state)
    FCB     8              ; Frame 1131 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1134 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     7              ; Delay 7 frames (maintain previous state)
    FCB     10              ; Frame 1141 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1144 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     4              ; Frame 1150 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1152 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     18              ; Delay 18 frames (maintain previous state)
    FCB     4              ; Frame 1170 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     8              ; Frame 1171 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1175 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     7              ; Delay 7 frames (maintain previous state)
    FCB     6              ; Frame 1182 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 1190 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1192 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1195 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     4              ; Frame 1201 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1203 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 1211 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 1212 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1213 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $F9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1216 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1220 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1222 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1226 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     15              ; Delay 15 frames (maintain previous state)
    FCB     4              ; Frame 1241 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     13              ; Delay 13 frames (maintain previous state)
    FCB     8              ; Frame 1254 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $51             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $36             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1257 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     11              ; Delay 11 frames (maintain previous state)
    FCB     8              ; Frame 1268 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $51             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1271 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     8              ; Frame 1279 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $51             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1282 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 1284 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 1292 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 1294 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $51             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1297 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     10              ; Frame 1305 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1308 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1313 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1314 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1317 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1322 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 1325 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $EE             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1328 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1330 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1333 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1335 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $EE             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1338 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 1340 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $51             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1343 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1345 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     10              ; Frame 1351 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1354 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1356 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $EE             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     10              ; Frame 1360 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $EE             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1363 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $EE             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     4              ; Frame 1364 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1365 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     8              ; Frame 1368 - 8 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $39             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1370 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $EE             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1373 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 1376 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1379 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     7              ; Delay 7 frames (maintain previous state)
    FCB     10              ; Frame 1386 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1389 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1394 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1396 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1400 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1402 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1405 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1406 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1409 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1414 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1416 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 1421 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1425 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     7              ; Delay 7 frames (maintain previous state)
    FCB     10              ; Frame 1432 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1435 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1437 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 1442 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1445 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1447 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $FC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $1B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     4              ; Frame 1456 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1457 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1460 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1465 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1467 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $36             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $02             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1470 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     4              ; Frame 1476 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1478 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $36             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $02             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1481 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1486 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1488 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $EE             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $36             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $02             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1491 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1493 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1496 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1498 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $EE             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1502 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     8              ; Frame 1503 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $36             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1506 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1508 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 1513 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $36             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $02             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1516 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1518 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $EE             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 1523 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $EE             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $36             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $02             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1527 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1529 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     8              ; Frame 1532 - 8 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $39             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1534 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $EE             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1537 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1539 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $36             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $02             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1542 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     6              ; Frame 1548 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 1550 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7A             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1552 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7A             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     4              ; Frame 1553 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 1554 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1557 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1559 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1562 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1564 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1567 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1569 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1572 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     4              ; Frame 1578 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1580 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 1585 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1588 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     7              ; Delay 7 frames (maintain previous state)
    FCB     8              ; Frame 1595 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7A             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1598 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1600 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 1605 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1608 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1610 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $E1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $1B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 1618 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1620 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $EE             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1623 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $EE             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     4              ; Frame 1629 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1631 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $0B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1634 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $0B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1639 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1641 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1644 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1649 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1651 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1654 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1659 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1661 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $0B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1664 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1666 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1669 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1671 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     10              ; Frame 1677 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1680 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1682 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $0B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 1687 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $0B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1690 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1692 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $FC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $3E             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     4              ; Frame 1701 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1702 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1705 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1710 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1712 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $0B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 1720 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1722 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1726 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1731 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1733 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1736 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1741 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 1742 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $0B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1745 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1747 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1751 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1753 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 1758 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1761 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1763 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 1768 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1771 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1773 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $FC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $3E             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     4              ; Frame 1782 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1784 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1787 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1792 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1793 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1796 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     4              ; Frame 1802 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1804 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1807 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1812 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1814 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1817 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1822 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1824 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1828 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1830 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1833 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1835 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     10              ; Frame 1839 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1842 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     4              ; Frame 1843 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 1844 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 1849 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1853 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1855 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 1863 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1865 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1868 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1873 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1876 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 1884 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1885 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1888 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1893 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1895 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1898 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     4              ; Frame 1904 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1906 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1909 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1911 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1914 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1916 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 1921 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1924 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1927 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     10              ; Frame 1931 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1934 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     4              ; Frame 1935 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1936 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 1944 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1946 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1949 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     4              ; Frame 1955 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1957 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $0B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1960 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $0B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1965 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1967 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1970 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     4              ; Frame 1976 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1978 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 1981 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1986 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 1987 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $0B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1990 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1992 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 1995 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 1997 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     10              ; Frame 2003 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2006 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 2008 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $0B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 2013 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $0B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2016 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 2018 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $FC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $3E             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     4              ; Frame 2027 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 2028 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2031 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 2036 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 2038 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $0B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 2046 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 2048 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 2052 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 2057 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 2059 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2062 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 2067 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 2069 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $0B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2072 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 2075 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2078 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 2079 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 2084 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2087 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 2089 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $0B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 2094 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $0B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2097 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 2100 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $FC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $3E             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 2108 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 2110 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2113 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 2118 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 2120 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $FC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2123 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     4              ; Frame 2129 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 2130 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 2138 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 2140 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 2148 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 2151 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $E1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $2C             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2154 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 2159 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 2171 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $E1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $2C             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 2175 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 2180 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     11              ; Delay 11 frames (maintain previous state)
    FCB     10              ; Frame 2191 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $E1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $2C             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2194 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     4              ; Frame 2200 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 2202 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2205 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 2207 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2210 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     7              ; Delay 7 frames (maintain previous state)
    FCB     10              ; Frame 2217 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2220 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 2221 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 2225 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     7              ; Delay 7 frames (maintain previous state)
    FCB     10              ; Frame 2232 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2235 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 2240 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 2242 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2245 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     4              ; Frame 2251 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     32              ; Delay 32 frames (maintain previous state)
    FCB     10              ; Frame 2283 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $4F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2286 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $4F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 2291 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 2293 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $59             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 2295 - 8 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $39             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 2296 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $5E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     4              ; Frame 2298 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 2300 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     4              ; Frame 2302 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 2304 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2307 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     7              ; Delay 7 frames (maintain previous state)
    FCB     6              ; Frame 2314 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     10              ; Frame 2318 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2321 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     4              ; Frame 2322 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 2323 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     10              ; Frame 2329 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2332 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 2334 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 2339 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2342 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 2344 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     4              ; Frame 2353 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 2355 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2358 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 2363 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 2364 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $4F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 2372 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 2375 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $59             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 2377 - 8 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $39             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 2378 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $5E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     4              ; Frame 2380 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 2382 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     4              ; Frame 2384 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 2385 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2388 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     7              ; Delay 7 frames (maintain previous state)
    FCB     6              ; Frame 2395 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     10              ; Frame 2401 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2404 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 2406 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     8              ; Frame 2410 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 2411 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 2413 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3A             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     4              ; Frame 2414 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 2415 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 2420 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2423 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     8              ; Frame 2426 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 2434 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 2436 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2439 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 2444 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 2446 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 2450 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 2455 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 2457 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2460 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 2465 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 2466 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $77             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2469 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $77             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     4              ; Frame 2475 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 2477 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 2482 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2485 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 2487 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 2492 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2495 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 2497 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     10              ; Frame 2503 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2506 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 2508 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 2516 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 2517 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2520 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     4              ; Frame 2526 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 2528 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     10              ; Frame 2538 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2541 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 2546 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 2548 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $51             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 2552 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     11              ; Delay 11 frames (maintain previous state)
    FCB     8              ; Frame 2563 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $51             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2566 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     7              ; Delay 7 frames (maintain previous state)
    FCB     8              ; Frame 2573 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $51             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 2577 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     7              ; Delay 7 frames (maintain previous state)
    FCB     8              ; Frame 2584 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $51             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2587 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 2589 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $1B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 2597 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     8              ; Frame 2600 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $51             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2603 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     10              ; Frame 2609 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $4F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2612 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $4F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 2617 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 2619 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $59             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 2621 - 8 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $39             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 2622 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $5E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2625 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 2627 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     4              ; Frame 2629 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 2630 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2633 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     7              ; Delay 7 frames (maintain previous state)
    FCB     6              ; Frame 2640 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 2645 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2648 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2651 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     10              ; Frame 2655 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2658 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     4              ; Frame 2659 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 2660 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 2665 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2668 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 2670 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     4              ; Frame 2679 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 2681 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2684 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 2689 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 2691 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $4F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     4              ; Frame 2700 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 2701 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $59             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 2703 - 8 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $39             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     4              ; Frame 2704 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 2705 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $5E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     4              ; Frame 2707 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 2708 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     4              ; Frame 2710 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 2711 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2714 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     7              ; Delay 7 frames (maintain previous state)
    FCB     6              ; Frame 2721 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     10              ; Frame 2727 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2730 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 2732 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 2737 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2740 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 2742 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     10              ; Frame 2746 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 2750 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     4              ; Frame 2751 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     8              ; Frame 2752 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 2760 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 2762 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3E             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $A8             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2765 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 2770 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 2772 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 2776 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 2781 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 2783 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2786 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 2791 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 2793 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2796 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     4              ; Frame 2802 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 2803 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $77             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 2808 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $77             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2811 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 2813 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $70             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 2818 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $70             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2821 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 2823 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $77             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     10              ; Frame 2829 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $77             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     4              ; Frame 2832 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 2834 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $E1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $1B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     4              ; Frame 2842 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 2843 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2846 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     4              ; Frame 2852 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 2864 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2867 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 2872 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 2875 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2878 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 2883 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 2885 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2888 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 2893 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 2894 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7A             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 2897 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     38              ; Delay 38 frames before loop
    FCB     $FF             ; Loop command ($FF never valid as count)
    FDB     _YUKIDAMA_ONDO_MUSIC       ; Jump to start (absolute address)


; ==== Level: WORLD_1_1 ====
; Author: 
; Difficulty: medium

_WORLD_1_1_LEVEL:
    FDB -96  ; World bounds: xMin (16-bit signed)
    FDB 95  ; xMax (16-bit signed)
    FDB -2432  ; yMin (16-bit signed)
    FDB 127  ; yMax (16-bit signed)
    FDB 0  ; Time limit (seconds)
    FDB 0  ; Target score
    FCB 0  ; Background object count
    FCB 62  ; Gameplay object count
    FCB 0  ; Foreground object count
    FDB _WORLD_1_1_BG_OBJECTS
    FDB _WORLD_1_1_GAMEPLAY_OBJECTS
    FDB _WORLD_1_1_FG_OBJECTS
    FDB -96  ; scrollLimit left (camera left cannot go below this)
    FDB 95  ; scrollLimit right (camera right cannot exceed this)
    FDB 127  ; scrollLimit top
    FDB -2432  ; scrollLimit bottom
    FCB 5  ; enemy_count
    FDB _WORLD_1_1_ENEMY_INSTANCES  ; enemy_instances_ptr (0 if none)

_WORLD_1_1_BG_OBJECTS:

_WORLD_1_1_GAMEPLAY_OBJECTS:
; Object: obj_1777629435866 (obstacle)
    FCB 2  ; type
    FDB -71  ; x
    FDB -2377  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: obj_1777629603657 (obstacle)
    FCB 2  ; type
    FDB 72  ; x
    FDB -2377  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: obj_1777629716564 (obstacle)
    FCB 2  ; type
    FDB 0  ; x
    FDB -2377  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: obj_1777629652016 (obstacle)
    FCB 2  ; type
    FDB 0  ; x
    FDB -2331  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM2_VECTORS  ; vector_ptr
    FCB 57  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: obj_1777629837468 (obstacle)
    FCB 2  ; type
    FDB -54  ; x
    FDB -2283  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM3_VECTORS  ; vector_ptr
    FCB 40  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: obj_1777629850372 (obstacle)
    FCB 2  ; type
    FDB 54  ; x
    FDB -2282  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM3_VECTORS  ; vector_ptr
    FCB 40  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: obj_1777629612161 (obstacle)
    FCB 2  ; type
    FDB 0  ; x
    FDB -2237  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM4_VECTORS  ; vector_ptr
    FCB 70  ; half_width (1.00x, ROM+18)
    FCB 18  ; half_height (1.00x, ROM+19)

; Object: enemy_1778250201678 (enemy)
    FCB 1  ; type
    FDB -42  ; x
    FDB -2201  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB 0  ; vector_ptr (no visual for this object)
    FCB 8  ; half_width (default, ROM+18)
    FCB 8  ; half_height (default, ROM+19)

; Object: enemy_1778250209582 (enemy)
    FCB 1  ; type
    FDB 43  ; x
    FDB -2201  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB 0  ; vector_ptr (no visual for this object)
    FCB 8  ; half_width (default, ROM+18)
    FCB 8  ; half_height (default, ROM+19)

; Object: enemy_1778250211554 (enemy)
    FCB 1  ; type
    FDB -87  ; x
    FDB -2261  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB 0  ; vector_ptr (no visual for this object)
    FCB 8  ; half_width (default, ROM+18)
    FCB 8  ; half_height (default, ROM+19)

; Object: enemy_1778250212985 (enemy)
    FCB 1  ; type
    FDB 86  ; x
    FDB -2261  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB 0  ; vector_ptr (no visual for this object)
    FCB 8  ; half_width (default, ROM+18)
    FCB 8  ; half_height (default, ROM+19)

; Object: enemy_1778250214379 (enemy)
    FCB 1  ; type
    FDB -55  ; x
    FDB -2309  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB 0  ; vector_ptr (no visual for this object)
    FCB 8  ; half_width (default, ROM+18)
    FCB 8  ; half_height (default, ROM+19)

; Object: plat_f2_1 (obstacle)
    FCB 2  ; type
    FDB -76  ; x
    FDB -2121  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f2_2 (obstacle)
    FCB 2  ; type
    FDB 76  ; x
    FDB -2121  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f2_3 (obstacle)
    FCB 2  ; type
    FDB 0  ; x
    FDB -2075  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM2_VECTORS  ; vector_ptr
    FCB 57  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f2_4 (obstacle)
    FCB 2  ; type
    FDB -60  ; x
    FDB -2027  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f2_5 (obstacle)
    FCB 2  ; type
    FDB 60  ; x
    FDB -2027  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f2_6 (obstacle)
    FCB 2  ; type
    FDB 0  ; x
    FDB -1981  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM3_VECTORS  ; vector_ptr
    FCB 40  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f3_1 (obstacle)
    FCB 2  ; type
    FDB -82  ; x
    FDB -1865  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f3_2 (obstacle)
    FCB 2  ; type
    FDB -30  ; x
    FDB -1819  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM3_VECTORS  ; vector_ptr
    FCB 40  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f3_3 (obstacle)
    FCB 2  ; type
    FDB 30  ; x
    FDB -1771  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM3_VECTORS  ; vector_ptr
    FCB 40  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f3_4 (obstacle)
    FCB 2  ; type
    FDB 82  ; x
    FDB -1725  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f4_1 (obstacle)
    FCB 2  ; type
    FDB -55  ; x
    FDB -1609  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM3_VECTORS  ; vector_ptr
    FCB 40  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f4_2 (obstacle)
    FCB 2  ; type
    FDB 0  ; x
    FDB -1609  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f4_3 (obstacle)
    FCB 2  ; type
    FDB 55  ; x
    FDB -1609  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM3_VECTORS  ; vector_ptr
    FCB 40  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f4_4 (obstacle)
    FCB 2  ; type
    FDB 0  ; x
    FDB -1515  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM2_VECTORS  ; vector_ptr
    FCB 57  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f4_5 (obstacle)
    FCB 2  ; type
    FDB -75  ; x
    FDB -1469  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f4_6 (obstacle)
    FCB 2  ; type
    FDB 75  ; x
    FDB -1469  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f5_1 (obstacle)
    FCB 2  ; type
    FDB -50  ; x
    FDB -1353  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM3_VECTORS  ; vector_ptr
    FCB 40  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f5_2 (obstacle)
    FCB 2  ; type
    FDB 50  ; x
    FDB -1353  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM3_VECTORS  ; vector_ptr
    FCB 40  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f5_3 (obstacle)
    FCB 2  ; type
    FDB 0  ; x
    FDB -1307  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM2_VECTORS  ; vector_ptr
    FCB 57  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f5_4 (obstacle)
    FCB 2  ; type
    FDB -65  ; x
    FDB -1259  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f5_5 (obstacle)
    FCB 2  ; type
    FDB 65  ; x
    FDB -1259  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f6_1 (obstacle)
    FCB 2  ; type
    FDB -82  ; x
    FDB -1097  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f6_2 (obstacle)
    FCB 2  ; type
    FDB 82  ; x
    FDB -1097  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f6_3 (obstacle)
    FCB 2  ; type
    FDB -35  ; x
    FDB -1051  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM3_VECTORS  ; vector_ptr
    FCB 40  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f6_4 (obstacle)
    FCB 2  ; type
    FDB 35  ; x
    FDB -1051  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM3_VECTORS  ; vector_ptr
    FCB 40  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f6_5 (obstacle)
    FCB 2  ; type
    FDB 0  ; x
    FDB -957  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM2_VECTORS  ; vector_ptr
    FCB 57  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f7_1 (obstacle)
    FCB 2  ; type
    FDB 82  ; x
    FDB -841  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f7_2 (obstacle)
    FCB 2  ; type
    FDB 30  ; x
    FDB -795  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM3_VECTORS  ; vector_ptr
    FCB 40  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f7_3 (obstacle)
    FCB 2  ; type
    FDB -30  ; x
    FDB -747  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM3_VECTORS  ; vector_ptr
    FCB 40  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f7_4 (obstacle)
    FCB 2  ; type
    FDB -82  ; x
    FDB -701  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f8_1 (obstacle)
    FCB 2  ; type
    FDB -70  ; x
    FDB -585  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f8_2 (obstacle)
    FCB 2  ; type
    FDB 0  ; x
    FDB -585  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f8_3 (obstacle)
    FCB 2  ; type
    FDB 70  ; x
    FDB -585  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f8_4 (obstacle)
    FCB 2  ; type
    FDB -45  ; x
    FDB -539  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f8_5 (obstacle)
    FCB 2  ; type
    FDB 45  ; x
    FDB -539  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f8_6 (obstacle)
    FCB 2  ; type
    FDB 0  ; x
    FDB -491  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM2_VECTORS  ; vector_ptr
    FCB 57  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f8_7 (obstacle)
    FCB 2  ; type
    FDB -80  ; x
    FDB -445  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f8_8 (obstacle)
    FCB 2  ; type
    FDB 80  ; x
    FDB -445  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f9_1 (obstacle)
    FCB 2  ; type
    FDB -80  ; x
    FDB -329  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f9_2 (obstacle)
    FCB 2  ; type
    FDB -30  ; x
    FDB -329  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f9_3 (obstacle)
    FCB 2  ; type
    FDB 30  ; x
    FDB -329  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f9_4 (obstacle)
    FCB 2  ; type
    FDB 80  ; x
    FDB -329  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f9_5 (obstacle)
    FCB 2  ; type
    FDB -48  ; x
    FDB -283  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM3_VECTORS  ; vector_ptr
    FCB 40  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f9_6 (obstacle)
    FCB 2  ; type
    FDB 48  ; x
    FDB -283  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM3_VECTORS  ; vector_ptr
    FCB 40  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f9_7 (obstacle)
    FCB 2  ; type
    FDB -65  ; x
    FDB -235  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f9_8 (obstacle)
    FCB 2  ; type
    FDB 0  ; x
    FDB -235  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f9_9 (obstacle)
    FCB 2  ; type
    FDB 65  ; x
    FDB -235  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM1_VECTORS  ; vector_ptr
    FCB 23  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f10_1 (obstacle)
    FCB 2  ; type
    FDB -55  ; x
    FDB -73  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM3_VECTORS  ; vector_ptr
    FCB 40  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f10_2 (obstacle)
    FCB 2  ; type
    FDB 55  ; x
    FDB -73  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM3_VECTORS  ; vector_ptr
    FCB 40  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)

; Object: plat_f10_3 (obstacle)
    FCB 2  ; type
    FDB 0  ; x
    FDB 67  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM2_VECTORS  ; vector_ptr
    FCB 57  ; half_width (1.00x, ROM+18)
    FCB 4  ; half_height (1.00x, ROM+19)


_WORLD_1_1_FG_OBJECTS:

_WORLD_1_1_ENEMY_COUNT EQU 5

; ---- Enemy instances for level WORLD_1_1 ----
_WORLD_1_1_ENEMY_INSTANCES:
    ; instance 0
    FDB _TITCHI_ENEMY   ; enemy type ptr
    FDB -42                   ; spawn x
    FDB -2201                   ; spawn y
    FCB 1                    ; ai_type: 0=static,1=patrol,2=chase,3=flee
    FCB 0                    ; wave (0=always present)
    FCB 0                    ; respawn: 0=no, 1=yes
    FCB 2                    ; waypoint_count
    FDB _WORLD_1_1_ENEMY0_WPS   ; ptr to waypoints (0 if none)

    ; instance 1
    FDB _TITCHI_ENEMY   ; enemy type ptr
    FDB 43                   ; spawn x
    FDB -2201                   ; spawn y
    FCB 1                    ; ai_type: 0=static,1=patrol,2=chase,3=flee
    FCB 0                    ; wave (0=always present)
    FCB 0                    ; respawn: 0=no, 1=yes
    FCB 2                    ; waypoint_count
    FDB _WORLD_1_1_ENEMY1_WPS   ; ptr to waypoints (0 if none)

    ; instance 2
    FDB _TITCHI_ENEMY   ; enemy type ptr
    FDB -87                   ; spawn x
    FDB -2261                   ; spawn y
    FCB 1                    ; ai_type: 0=static,1=patrol,2=chase,3=flee
    FCB 0                    ; wave (0=always present)
    FCB 0                    ; respawn: 0=no, 1=yes
    FCB 2                    ; waypoint_count
    FDB _WORLD_1_1_ENEMY2_WPS   ; ptr to waypoints (0 if none)

    ; instance 3
    FDB _TITCHI_ENEMY   ; enemy type ptr
    FDB 86                   ; spawn x
    FDB -2261                   ; spawn y
    FCB 1                    ; ai_type: 0=static,1=patrol,2=chase,3=flee
    FCB 0                    ; wave (0=always present)
    FCB 0                    ; respawn: 0=no, 1=yes
    FCB 2                    ; waypoint_count
    FDB _WORLD_1_1_ENEMY3_WPS   ; ptr to waypoints (0 if none)

    ; instance 4
    FDB _TITCHI_ENEMY   ; enemy type ptr
    FDB -55                   ; spawn x
    FDB -2309                   ; spawn y
    FCB 1                    ; ai_type: 0=static,1=patrol,2=chase,3=flee
    FCB 0                    ; wave (0=always present)
    FCB 0                    ; respawn: 0=no, 1=yes
    FCB 2                    ; waypoint_count
    FDB _WORLD_1_1_ENEMY4_WPS   ; ptr to waypoints (0 if none)

_WORLD_1_1_ENEMY0_WPS:
    FDB -3  ; wp x
    FDB -2205  ; wp y
    FDB -42  ; wp x
    FDB -2205  ; wp y

_WORLD_1_1_ENEMY1_WPS:
    FDB 45  ; wp x
    FDB -2205  ; wp y
    FDB 3  ; wp x
    FDB -2205  ; wp y

_WORLD_1_1_ENEMY2_WPS:
    FDB -91  ; wp x
    FDB -2262  ; wp y
    FDB -14  ; wp x
    FDB -2262  ; wp y

_WORLD_1_1_ENEMY3_WPS:
    FDB 89  ; wp x
    FDB -2261  ; wp y
    FDB 14  ; wp x
    FDB -2261  ; wp y

_WORLD_1_1_ENEMY4_WPS:
    FDB -55  ; wp x
    FDB -2312  ; wp y
    FDB 56  ; wp x
    FDB -2312  ; wp y


; Generated from init_screen.vec (Malban Draw_Sync_List format)
; Total paths: 57, points: 257
; X bounds: min=-77, max=78, width=155
; Center: (0, 13)

_INIT_SCREEN_WIDTH EQU 155
_INIT_SCREEN_HALF_WIDTH EQU 77
_INIT_SCREEN_HEIGHT EQU 136
_INIT_SCREEN_HALF_HEIGHT EQU 68
_INIT_SCREEN_CENTER_X EQU 0
_INIT_SCREEN_CENTER_Y EQU 13

_INIT_SCREEN_VECTORS:  ; Main entry (header + 57 path(s))
    FDB 57               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _INIT_SCREEN_PATH0        ; pointer to path 0
    FDB _INIT_SCREEN_PATH1        ; pointer to path 1
    FDB _INIT_SCREEN_PATH2        ; pointer to path 2
    FDB _INIT_SCREEN_PATH3        ; pointer to path 3
    FDB _INIT_SCREEN_PATH4        ; pointer to path 4
    FDB _INIT_SCREEN_PATH5        ; pointer to path 5
    FDB _INIT_SCREEN_PATH6        ; pointer to path 6
    FDB _INIT_SCREEN_PATH7        ; pointer to path 7
    FDB _INIT_SCREEN_PATH8        ; pointer to path 8
    FDB _INIT_SCREEN_PATH9        ; pointer to path 9
    FDB _INIT_SCREEN_PATH10        ; pointer to path 10
    FDB _INIT_SCREEN_PATH11        ; pointer to path 11
    FDB _INIT_SCREEN_PATH12        ; pointer to path 12
    FDB _INIT_SCREEN_PATH13        ; pointer to path 13
    FDB _INIT_SCREEN_PATH14        ; pointer to path 14
    FDB _INIT_SCREEN_PATH15        ; pointer to path 15
    FDB _INIT_SCREEN_PATH16        ; pointer to path 16
    FDB _INIT_SCREEN_PATH17        ; pointer to path 17
    FDB _INIT_SCREEN_PATH18        ; pointer to path 18
    FDB _INIT_SCREEN_PATH19        ; pointer to path 19
    FDB _INIT_SCREEN_PATH20        ; pointer to path 20
    FDB _INIT_SCREEN_PATH21        ; pointer to path 21
    FDB _INIT_SCREEN_PATH22        ; pointer to path 22
    FDB _INIT_SCREEN_PATH23        ; pointer to path 23
    FDB _INIT_SCREEN_PATH24        ; pointer to path 24
    FDB _INIT_SCREEN_PATH25        ; pointer to path 25
    FDB _INIT_SCREEN_PATH26        ; pointer to path 26
    FDB _INIT_SCREEN_PATH27        ; pointer to path 27
    FDB _INIT_SCREEN_PATH28        ; pointer to path 28
    FDB _INIT_SCREEN_PATH29        ; pointer to path 29
    FDB _INIT_SCREEN_PATH30        ; pointer to path 30
    FDB _INIT_SCREEN_PATH31        ; pointer to path 31
    FDB _INIT_SCREEN_PATH32        ; pointer to path 32
    FDB _INIT_SCREEN_PATH33        ; pointer to path 33
    FDB _INIT_SCREEN_PATH34        ; pointer to path 34
    FDB _INIT_SCREEN_PATH35        ; pointer to path 35
    FDB _INIT_SCREEN_PATH36        ; pointer to path 36
    FDB _INIT_SCREEN_PATH37        ; pointer to path 37
    FDB _INIT_SCREEN_PATH38        ; pointer to path 38
    FDB _INIT_SCREEN_PATH39        ; pointer to path 39
    FDB _INIT_SCREEN_PATH40        ; pointer to path 40
    FDB _INIT_SCREEN_PATH41        ; pointer to path 41
    FDB _INIT_SCREEN_PATH42        ; pointer to path 42
    FDB _INIT_SCREEN_PATH43        ; pointer to path 43
    FDB _INIT_SCREEN_PATH44        ; pointer to path 44
    FDB _INIT_SCREEN_PATH45        ; pointer to path 45
    FDB _INIT_SCREEN_PATH46        ; pointer to path 46
    FDB _INIT_SCREEN_PATH47        ; pointer to path 47
    FDB _INIT_SCREEN_PATH48        ; pointer to path 48
    FDB _INIT_SCREEN_PATH49        ; pointer to path 49
    FDB _INIT_SCREEN_PATH50        ; pointer to path 50
    FDB _INIT_SCREEN_PATH51        ; pointer to path 51
    FDB _INIT_SCREEN_PATH52        ; pointer to path 52
    FDB _INIT_SCREEN_PATH53        ; pointer to path 53
    FDB _INIT_SCREEN_PATH54        ; pointer to path 54
    FDB _INIT_SCREEN_PATH55        ; pointer to path 55
    FDB _INIT_SCREEN_PATH56        ; pointer to path 56

_INIT_SCREEN_PATH0:    ; Path 0
    FCB 85              ; path0: intensity
    FCB $F6,$FC,0,0        ; path0: header (y=-10, x=-4)
    FCB $FF,$F7,$FB          ; flag=-1, dy=-9, dx=-5
    FCB $FF,$F4,$02          ; flag=-1, dy=-12, dx=2
    FCB $FF,$FF,$07          ; flag=-1, dy=-1, dx=7
    FCB $FF,$05,$03          ; flag=-1, dy=5, dx=3
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH1:    ; Path 1
    FCB 85              ; path1: intensity
    FCB $E5,$03,0,0        ; path1: header (y=-27, x=3)
    FCB $FF,$0E,$FE          ; flag=-1, dy=14, dx=-2
    FCB $FF,$03,$FB          ; flag=-1, dy=3, dx=-5
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH2:    ; Path 2
    FCB 85              ; path2: intensity
    FCB $ED,$FD,0,0        ; path2: header (y=-19, x=-3)
    FCB $FF,$F7,$02          ; flag=-1, dy=-9, dx=2
    FCB $FF,$08,$02          ; flag=-1, dy=8, dx=2
    FCB $FF,$03,$FE          ; flag=-1, dy=3, dx=-2
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH3:    ; Path 3
    FCB 85              ; path3: intensity
    FCB $ED,$09,0,0        ; path3: header (y=-19, x=9)
    FCB $FF,$F7,$02          ; flag=-1, dy=-9, dx=2
    FCB $FF,$08,$02          ; flag=-1, dy=8, dx=2
    FCB $FF,$03,$FE          ; flag=-1, dy=3, dx=-2
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH4:    ; Path 4
    FCB 85              ; path4: intensity
    FCB $F3,$09,0,0        ; path4: header (y=-13, x=9)
    FCB $FF,$F5,$FE          ; flag=-1, dy=-11, dx=-2
    FCB $FF,$F6,$06          ; flag=-1, dy=-10, dx=6
    FCB $FF,$08,$05          ; flag=-1, dy=8, dx=5
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$09,$FD          ; flag=-1, dy=9, dx=-3
    FCB $FF,$FE,$FA          ; flag=-1, dy=-2, dx=-6
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH5:    ; Path 5
    FCB 85              ; path5: intensity
    FCB $02,$F8,0,0        ; path5: header (y=2, x=-8)
    FCB $FF,$09,$F9          ; flag=-1, dy=9, dx=-7
    FCB $FF,$FE,$F3          ; flag=-1, dy=-2, dx=-13
    FCB $FF,$F9,$FA          ; flag=-1, dy=-7, dx=-6
    FCB $FF,$F4,$04          ; flag=-1, dy=-12, dx=4
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH6:    ; Path 6
    FCB 85              ; path6: intensity
    FCB $DC,$EF,0,0        ; path6: header (y=-36, x=-17)
    FCB $FF,$00,$29          ; flag=-1, dy=0, dx=41
    FCB $FF,$F4,$F6          ; flag=-1, dy=-12, dx=-10
    FCB $FF,$FC,$F7          ; flag=-1, dy=-4, dx=-9
    FCB $FF,$03,$F7          ; flag=-1, dy=3, dx=-9
    FCB $FF,$0D,$F3          ; flag=-1, dy=13, dx=-13
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH7:    ; Path 7
    FCB 85              ; path7: intensity
    FCB $CB,$EB,0,0        ; path7: header (y=-53, x=-21)
    FCB $FF,$FD,$15          ; flag=-1, dy=-3, dx=21
    FCB $FF,$02,$0E          ; flag=-1, dy=2, dx=14
    FCB $FF,$06,$0A          ; flag=-1, dy=6, dx=10
    FCB $FF,$11,$08          ; flag=-1, dy=17, dx=8
    FCB $FF,$15,$FA          ; flag=-1, dy=21, dx=-6
    FCB $FF,$08,$F7          ; flag=-1, dy=8, dx=-9
    FCB $FF,$04,$F4          ; flag=-1, dy=4, dx=-12
    FCB $FF,$00,$F3          ; flag=-1, dy=0, dx=-13
    FCB $FF,$FB,$F2          ; flag=-1, dy=-5, dx=-14
    FCB $FF,$F7,$F6          ; flag=-1, dy=-9, dx=-10
    FCB $FF,$F4,$FB          ; flag=-1, dy=-12, dx=-5
    FCB $FF,$F1,$00          ; flag=-1, dy=-15, dx=0
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH8:    ; Path 8
    FCB 85              ; path8: intensity
    FCB $D8,$D9,0,0        ; path8: header (y=-40, x=-39)
    FCB $FF,$F7,$F6          ; flag=-1, dy=-9, dx=-10
    FCB $FF,$EE,$00          ; flag=-1, dy=-18, dx=0
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH9:    ; Path 9
    FCB 85              ; path9: intensity
    FCB $BD,$CC,0,0        ; path9: header (y=-67, x=-52)
    FCB $FF,$FF,$21          ; flag=-1, dy=-1, dx=33
    FCB $FF,$0F,$FE          ; flag=-1, dy=15, dx=-2
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH10:    ; Path 10
    FCB 85              ; path10: intensity
    FCB $CB,$EB,0,0        ; path10: header (y=-53, x=-21)
    FCB $FF,$0C,$F8          ; flag=-1, dy=12, dx=-8
    FCB $FF,$01,$F6          ; flag=-1, dy=1, dx=-10
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH11:    ; Path 11
    FCB 85              ; path11: intensity
    FCB $C4,$DB,0,0        ; path11: header (y=-60, x=-37)
    FCB $FF,$06,$05          ; flag=-1, dy=6, dx=5
    FCB $FF,$FD,$07          ; flag=-1, dy=-3, dx=7
    FCB $FF,$F5,$FE          ; flag=-1, dy=-11, dx=-2
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH12:    ; Path 12
    FCB 85              ; path12: intensity
    FCB $C7,$E7,0,0        ; path12: header (y=-57, x=-25)
    FCB $FF,$04,$04          ; flag=-1, dy=4, dx=4
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH13:    ; Path 13
    FCB 85              ; path13: intensity
    FCB $C9,$F2,0,0        ; path13: header (y=-55, x=-14)
    FCB $FF,$F3,$03          ; flag=-1, dy=-13, dx=3
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH14:    ; Path 14
    FCB 85              ; path14: intensity
    FCB $C0,$F5,0,0        ; path14: header (y=-64, x=-11)
    FCB $FF,$00,$1D          ; flag=-1, dy=0, dx=29
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH15:    ; Path 15
    FCB 85              ; path15: intensity
    FCB $BC,$13,0,0        ; path15: header (y=-68, x=19)
    FCB $FF,$0E,$FB          ; flag=-1, dy=14, dx=-5
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH16:    ; Path 16
    FCB 85              ; path16: intensity
    FCB $CD,$13,0,0        ; path16: header (y=-51, x=19)
    FCB $FF,$EF,$06          ; flag=-1, dy=-17, dx=6
    FCB $FF,$00,$14          ; flag=-1, dy=0, dx=20
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH17:    ; Path 17
    FCB 85              ; path17: intensity
    FCB $BD,$2B,0,0        ; path17: header (y=-67, x=43)
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$07,$FB          ; flag=-1, dy=7, dx=-5
    FCB $FF,$FE,$F5          ; flag=-1, dy=-2, dx=-11
    FCB $FF,$FB,$FC          ; flag=-1, dy=-5, dx=-4
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH18:    ; Path 18
    FCB 85              ; path18: intensity
    FCB $CB,$1B,0,0        ; path18: header (y=-53, x=27)
    FCB $FF,$05,$FD          ; flag=-1, dy=5, dx=-3
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH19:    ; Path 19
    FCB 85              ; path19: intensity
    FCB $0A,$33,0,0        ; path19: header (y=10, x=51)
    FCB $FF,$FE,$FA          ; flag=-1, dy=-2, dx=-6
    FCB $FF,$06,$FE          ; flag=-1, dy=6, dx=-2
    FCB $FF,$02,$06          ; flag=-1, dy=2, dx=6
    FCB $FF,$FC,$02          ; flag=-1, dy=-4, dx=2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH20:    ; Path 20
    FCB 85              ; path20: intensity
    FCB $15,$3A,0,0        ; path20: header (y=21, x=58)
    FCB $FF,$0B,$13          ; flag=-1, dy=11, dx=19
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH21:    ; Path 21
    FCB 85              ; path21: intensity
    FCB $21,$4A,0,0        ; path21: header (y=33, x=74)
    FCB $FF,$FC,$FF          ; flag=-1, dy=-4, dx=-1
    FCB $FF,$FF,$03          ; flag=-1, dy=-1, dx=3
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH22:    ; Path 22
    FCB 85              ; path22: intensity
    FCB $18,$4D,0,0        ; path22: header (y=24, x=77)
    FCB $FF,$FF,$FC          ; flag=-1, dy=-1, dx=-4
    FCB $FF,$FC,$01          ; flag=-1, dy=-4, dx=1
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH23:    ; Path 23
    FCB 85              ; path23: intensity
    FCB $14,$4E,0,0        ; path23: header (y=20, x=78)
    FCB $FF,$0C,$EC          ; flag=-1, dy=12, dx=-20
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH24:    ; Path 24
    FCB 85              ; path24: intensity
    FCB $21,$3D,0,0        ; path24: header (y=33, x=61)
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH25:    ; Path 25
    FCB 85              ; path25: intensity
    FCB $1D,$3E,0,0        ; path25: header (y=29, x=62)
    FCB $FF,$FF,$FC          ; flag=-1, dy=-1, dx=-4
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH26:    ; Path 26
    FCB 85              ; path26: intensity
    FCB $18,$3A,0,0        ; path26: header (y=24, x=58)
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH27:    ; Path 27
    FCB 85              ; path27: intensity
    FCB $17,$3E,0,0        ; path27: header (y=23, x=62)
    FCB $FF,$FC,$FF          ; flag=-1, dy=-4, dx=-1
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH28:    ; Path 28
    FCB 85              ; path28: intensity
    FCB $11,$41,0,0        ; path28: header (y=17, x=65)
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB $FF,$FD,$03          ; flag=-1, dy=-3, dx=3
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH29:    ; Path 29
    FCB 85              ; path29: intensity
    FCB $0F,$43,0,0        ; path29: header (y=15, x=67)
    FCB $FF,$17,$00          ; flag=-1, dy=23, dx=0
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH30:    ; Path 30
    FCB 85              ; path30: intensity
    FCB $23,$40,0,0        ; path30: header (y=35, x=64)
    FCB $FF,$FD,$03          ; flag=-1, dy=-3, dx=3
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH31:    ; Path 31
    FCB 85              ; path31: intensity
    FCB $20,$43,0,0        ; path31: header (y=32, x=67)
    FCB $FF,$03,$03          ; flag=-1, dy=3, dx=3
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH32:    ; Path 32
    FCB 85              ; path32: intensity
    FCB $22,$2C,0,0        ; path32: header (y=34, x=44)
    FCB $FF,$03,$EE          ; flag=-1, dy=3, dx=-18
    FCB $FF,$F9,$FD          ; flag=-1, dy=-7, dx=-3
    FCB $FF,$F6,$0D          ; flag=-1, dy=-10, dx=13
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$05,$F4          ; flag=-1, dy=5, dx=-12
    FCB $FF,$F9,$FF          ; flag=-1, dy=-7, dx=-1
    FCB $FF,$FD,$11          ; flag=-1, dy=-3, dx=17
    FCB $FF,$08,$03          ; flag=-1, dy=8, dx=3
    FCB $FF,$06,$FC          ; flag=-1, dy=6, dx=-4
    FCB $FF,$04,$F8          ; flag=-1, dy=4, dx=-8
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$FB,$0B          ; flag=-1, dy=-5, dx=11
    FCB $FF,$06,$01          ; flag=-1, dy=6, dx=1
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH33:    ; Path 33
    FCB 85              ; path33: intensity
    FCB $22,$07,0,0        ; path33: header (y=34, x=7)
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$FE,$06          ; flag=-1, dy=-2, dx=6
    FCB $FF,$0C,$02          ; flag=-1, dy=12, dx=2
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH34:    ; Path 34
    FCB 85              ; path34: intensity
    FCB $24,$01,0,0        ; path34: header (y=36, x=1)
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB $FF,$FC,$04          ; flag=-1, dy=-4, dx=4
    FCB $FF,$FF,$0B          ; flag=-1, dy=-1, dx=11
    FCB $FF,$04,$05          ; flag=-1, dy=4, dx=5
    FCB $FF,$0E,$00          ; flag=-1, dy=14, dx=0
    FCB $FF,$06,$FC          ; flag=-1, dy=6, dx=-4
    FCB $FF,$00,$F5          ; flag=-1, dy=0, dx=-11
    FCB $FF,$FB,$FB          ; flag=-1, dy=-5, dx=-5
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH35:    ; Path 35
    FCB 85              ; path35: intensity
    FCB $24,$F1,0,0        ; path35: header (y=36, x=-15)
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$05,$FF          ; flag=-1, dy=5, dx=-1
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH36:    ; Path 36
    FCB 85              ; path36: intensity
    FCB $27,$E9,0,0        ; path36: header (y=39, x=-23)
    FCB $FF,$E9,$03          ; flag=-1, dy=-23, dx=3
    FCB $FF,$01,$07          ; flag=-1, dy=1, dx=7
    FCB $FF,$09,$FF          ; flag=-1, dy=9, dx=-1
    FCB $FF,$F8,$07          ; flag=-1, dy=-8, dx=7
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$09,$F9          ; flag=-1, dy=9, dx=-7
    FCB $FF,$03,$05          ; flag=-1, dy=3, dx=5
    FCB $FF,$09,$FF          ; flag=-1, dy=9, dx=-1
    FCB $FF,$00,$EC          ; flag=-1, dy=0, dx=-20
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH37:    ; Path 37
    FCB 85              ; path37: intensity
    FCB $1F,$D9,0,0        ; path37: header (y=31, x=-39)
    FCB $FF,$FB,$01          ; flag=-1, dy=-5, dx=1
    FCB $FF,$04,$07          ; flag=-1, dy=4, dx=7
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$FE,$F9          ; flag=-1, dy=-2, dx=-7
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH38:    ; Path 38
    FCB 85              ; path38: intensity
    FCB $22,$D0,0,0        ; path38: header (y=34, x=-48)
    FCB $FF,$E6,$07          ; flag=-1, dy=-26, dx=7
    FCB $FF,$06,$10          ; flag=-1, dy=6, dx=16
    FCB $FF,$05,$03          ; flag=-1, dy=5, dx=3
    FCB $FF,$07,$FB          ; flag=-1, dy=7, dx=-5
    FCB $FF,$04,$03          ; flag=-1, dy=4, dx=3
    FCB $FF,$08,$FC          ; flag=-1, dy=8, dx=-4
    FCB $FF,$FC,$EC          ; flag=-1, dy=-4, dx=-20
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH39:    ; Path 39
    FCB 85              ; path39: intensity
    FCB $20,$C6,0,0        ; path39: header (y=32, x=-58)
    FCB $FF,$F5,$ED          ; flag=-1, dy=-11, dx=-19
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH40:    ; Path 40
    FCB 85              ; path40: intensity
    FCB $18,$B3,0,0        ; path40: header (y=24, x=-77)
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH41:    ; Path 41
    FCB 85              ; path41: intensity
    FCB $17,$B7,0,0        ; path41: header (y=23, x=-73)
    FCB $FF,$FC,$FF          ; flag=-1, dy=-4, dx=-1
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH42:    ; Path 42
    FCB 85              ; path42: intensity
    FCB $11,$BA,0,0        ; path42: header (y=17, x=-70)
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB $FF,$FD,$03          ; flag=-1, dy=-3, dx=3
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH43:    ; Path 43
    FCB 85              ; path43: intensity
    FCB $0F,$BC,0,0        ; path43: header (y=15, x=-68)
    FCB $FF,$17,$00          ; flag=-1, dy=23, dx=0
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH44:    ; Path 44
    FCB 85              ; path44: intensity
    FCB $23,$B9,0,0        ; path44: header (y=35, x=-71)
    FCB $FF,$FD,$03          ; flag=-1, dy=-3, dx=3
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH45:    ; Path 45
    FCB 85              ; path45: intensity
    FCB $20,$BC,0,0        ; path45: header (y=32, x=-68)
    FCB $FF,$03,$03          ; flag=-1, dy=3, dx=3
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH46:    ; Path 46
    FCB 85              ; path46: intensity
    FCB $21,$C3,0,0        ; path46: header (y=33, x=-61)
    FCB $FF,$FC,$FF          ; flag=-1, dy=-4, dx=-1
    FCB $FF,$FF,$03          ; flag=-1, dy=-1, dx=3
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH47:    ; Path 47
    FCB 85              ; path47: intensity
    FCB $18,$C6,0,0        ; path47: header (y=24, x=-58)
    FCB $FF,$FF,$FC          ; flag=-1, dy=-1, dx=-4
    FCB $FF,$FC,$01          ; flag=-1, dy=-4, dx=1
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH48:    ; Path 48
    FCB 85              ; path48: intensity
    FCB $14,$C7,0,0        ; path48: header (y=20, x=-57)
    FCB $FF,$0C,$EC          ; flag=-1, dy=12, dx=-20
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH49:    ; Path 49
    FCB 85              ; path49: intensity
    FCB $21,$B6,0,0        ; path49: header (y=33, x=-74)
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH50:    ; Path 50
    FCB 85              ; path50: intensity
    FCB $1D,$B7,0,0        ; path50: header (y=29, x=-73)
    FCB $FF,$FF,$FC          ; flag=-1, dy=-1, dx=-4
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH51:    ; Path 51
    FCB 85              ; path51: intensity
    FCB $15,$DB,0,0        ; path51: header (y=21, x=-37)
    FCB $FF,$FB,$01          ; flag=-1, dy=-5, dx=1
    FCB $FF,$04,$07          ; flag=-1, dy=4, dx=7
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$FE,$F9          ; flag=-1, dy=-2, dx=-7
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH52:    ; Path 52
    FCB 85              ; path52: intensity
    FCB $3A,$E1,0,0        ; path52: header (y=58, x=-31)
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$FD,$EB          ; flag=-1, dy=-3, dx=-21
    FCB $FF,$FA,$FA          ; flag=-1, dy=-6, dx=-6
    FCB $FF,$F7,$02          ; flag=-1, dy=-9, dx=2
    FCB $FF,$01,$0E          ; flag=-1, dy=1, dx=14
    FCB $FF,$FC,$03          ; flag=-1, dy=-4, dx=3
    FCB $FF,$FC,$F4          ; flag=-1, dy=-4, dx=-12
    FCB $FF,$01,$F9          ; flag=-1, dy=1, dx=-7
    FCB $FF,$F8,$01          ; flag=-1, dy=-8, dx=1
    FCB $FF,$05,$15          ; flag=-1, dy=5, dx=21
    FCB $FF,$06,$05          ; flag=-1, dy=6, dx=5
    FCB $FF,$09,$FD          ; flag=-1, dy=9, dx=-3
    FCB $FF,$00,$F3          ; flag=-1, dy=0, dx=-13
    FCB $FF,$04,$FF          ; flag=-1, dy=4, dx=-1
    FCB $FF,$02,$0A          ; flag=-1, dy=2, dx=10
    FCB $FF,$FD,$07          ; flag=-1, dy=-3, dx=7
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH53:    ; Path 53
    FCB 85              ; path53: intensity
    FCB $44,$E5,0,0        ; path53: header (y=68, x=-27)
    FCB $FF,$E6,$00          ; flag=-1, dy=-26, dx=0
    FCB $FF,$02,$08          ; flag=-1, dy=2, dx=8
    FCB $FF,$0E,$00          ; flag=-1, dy=14, dx=0
    FCB $FF,$F3,$09          ; flag=-1, dy=-13, dx=9
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$17,$00          ; flag=-1, dy=23, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$F3,$01          ; flag=-1, dy=-13, dx=1
    FCB $FF,$0D,$F7          ; flag=-1, dy=13, dx=-9
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH54:    ; Path 54
    FCB 85              ; path54: intensity
    FCB $3F,$02,0,0        ; path54: header (y=63, x=2)
    FCB $FF,$05,$04          ; flag=-1, dy=5, dx=4
    FCB $FF,$00,$0F          ; flag=-1, dy=0, dx=15
    FCB $FF,$FB,$05          ; flag=-1, dy=-5, dx=5
    FCB $FF,$F1,$00          ; flag=-1, dy=-15, dx=0
    FCB $FF,$FC,$FA          ; flag=-1, dy=-4, dx=-6
    FCB $FF,$01,$F3          ; flag=-1, dy=1, dx=-13
    FCB $FF,$04,$FB          ; flag=-1, dy=4, dx=-5
    FCB $FF,$0E,$00          ; flag=-1, dy=14, dx=0
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH55:    ; Path 55
    FCB 85              ; path55: intensity
    FCB $3C,$09,0,0        ; path55: header (y=60, x=9)
    FCB $FF,$F5,$02          ; flag=-1, dy=-11, dx=2
    FCB $FF,$02,$08          ; flag=-1, dy=2, dx=8
    FCB $FF,$0C,$FE          ; flag=-1, dy=12, dx=-2
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$FD,$FE          ; flag=-1, dy=-3, dx=-2
    FCB 2                ; End marker (path complete)

_INIT_SCREEN_PATH56:    ; Path 56
    FCB 85              ; path56: intensity
    FCB $44,$1B,0,0        ; path56: header (y=68, x=27)
    FCB $FF,$E7,$06          ; flag=-1, dy=-25, dx=6
    FCB $FF,$FE,$06          ; flag=-1, dy=-2, dx=6
    FCB $FF,$0A,$05          ; flag=-1, dy=10, dx=5
    FCB $FF,$F4,$02          ; flag=-1, dy=-12, dx=2
    FCB $FF,$FE,$07          ; flag=-1, dy=-2, dx=7
    FCB $FF,$19,$08          ; flag=-1, dy=25, dx=8
    FCB $FF,$02,$F9          ; flag=-1, dy=2, dx=-7
    FCB $FF,$F3,$FC          ; flag=-1, dy=-13, dx=-4
    FCB $FF,$0E,$FD          ; flag=-1, dy=14, dx=-3
    FCB $FF,$01,$FB          ; flag=-1, dy=1, dx=-5
    FCB $FF,$F3,$FC          ; flag=-1, dy=-13, dx=-4
    FCB $FF,$0E,$FD          ; flag=-1, dy=14, dx=-3
    FCB $FF,$01,$F8          ; flag=-1, dy=1, dx=-8
    FCB 2                ; End marker (path complete)

; Generated from Game_Over.vmus (internal name: Imported MIDI)
; Tempo: 120 BPM, Total events: 19 (PSG Direct format)
; Format: FCB count, FCB reg, val, ... (per frame), FCB 0 (end)

_GAME_OVER_MUSIC:
    ; Frame-based PSG register writes
    FCB     0              ; Delay 0 frames (maintain previous state)
    FCB     10              ; Frame 0 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $59             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $6A             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $77             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     16              ; Delay 16 frames (maintain previous state)
    FCB     4              ; Frame 16 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     6              ; Frame 19 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     4              ; Frame 28 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 30 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $54             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $6A             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7E             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     7              ; Delay 7 frames (maintain previous state)
    FCB     8              ; Frame 37 - 8 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $6A             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7E             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $39             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 40 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $5E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $6A             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7E             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     7              ; Delay 7 frames (maintain previous state)
    FCB     8              ; Frame 47 - 8 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $6A             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7E             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $39             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     10              ; Frame 51 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $6A             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7E             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     7              ; Delay 7 frames (maintain previous state)
    FCB     8              ; Frame 58 - 8 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $6A             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7E             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $39             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 60 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $6A             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $7E             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     7              ; Delay 7 frames (maintain previous state)
    FCB     4              ; Frame 67 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     14              ; Delay 14 frames (maintain previous state)
    FCB     10              ; Frame 81 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $96             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $9F             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     7              ; Delay 7 frames (maintain previous state)
    FCB     4              ; Frame 88 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 91 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $96             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $9F             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     17              ; Delay 17 frames (maintain previous state)
    FCB     4              ; Frame 108 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     13              ; Delay 13 frames (maintain previous state)
    FCB     10              ; Frame 121 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $1B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     254             ; Delay 254 frames (filler chunk)
    FCB     10              ; 10 register writes (repeat state)
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $1B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     25              ; Delay 25 frames before loop
    FCB     $FF             ; Loop command ($FF never valid as count)
    FDB     _GAME_OVER_MUSIC       ; Jump to start (absolute address)


; Generated from titchi_snow1.vec (Malban Draw_Sync_List format)
; Total paths: 13, points: 48
; X bounds: min=-7, max=7, width=14
; Center: (0, 0)

_TITCHI_SNOW1_WIDTH EQU 14
_TITCHI_SNOW1_HALF_WIDTH EQU 7
_TITCHI_SNOW1_HEIGHT EQU 15
_TITCHI_SNOW1_HALF_HEIGHT EQU 7
_TITCHI_SNOW1_CENTER_X EQU 0
_TITCHI_SNOW1_CENTER_Y EQU 0

_TITCHI_SNOW1_VECTORS:  ; Main entry (header + 13 path(s))
    FDB 13               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _TITCHI_SNOW1_PATH0        ; pointer to path 0
    FDB _TITCHI_SNOW1_PATH1        ; pointer to path 1
    FDB _TITCHI_SNOW1_PATH2        ; pointer to path 2
    FDB _TITCHI_SNOW1_PATH3        ; pointer to path 3
    FDB _TITCHI_SNOW1_PATH4        ; pointer to path 4
    FDB _TITCHI_SNOW1_PATH5        ; pointer to path 5
    FDB _TITCHI_SNOW1_PATH6        ; pointer to path 6
    FDB _TITCHI_SNOW1_PATH7        ; pointer to path 7
    FDB _TITCHI_SNOW1_PATH8        ; pointer to path 8
    FDB _TITCHI_SNOW1_PATH9        ; pointer to path 9
    FDB _TITCHI_SNOW1_PATH10        ; pointer to path 10
    FDB _TITCHI_SNOW1_PATH11        ; pointer to path 11
    FDB _TITCHI_SNOW1_PATH12        ; pointer to path 12

_TITCHI_SNOW1_PATH0:    ; Path 0
    FCB 85              ; path0: intensity
    FCB $FF,$FE,0,0        ; path0: header (y=-1, x=-2)
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB 2                ; End marker (path complete)

_TITCHI_SNOW1_PATH1:    ; Path 1
    FCB 85              ; path1: intensity
    FCB $FC,$FC,0,0        ; path1: header (y=-4, x=-4)
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB 2                ; End marker (path complete)

_TITCHI_SNOW1_PATH2:    ; Path 2
    FCB 85              ; path2: intensity
    FCB $03,$FE,0,0        ; path2: header (y=3, x=-2)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB 2                ; End marker (path complete)

_TITCHI_SNOW1_PATH3:    ; Path 3
    FCB 85              ; path3: intensity
    FCB $04,$FD,0,0        ; path3: header (y=4, x=-3)
    FCB $FF,$FD,$FE          ; flag=-1, dy=-3, dx=-2
    FCB $FF,$FA,$02          ; flag=-1, dy=-6, dx=2
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$01,$06          ; flag=-1, dy=1, dx=6
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB 2                ; End marker (path complete)

_TITCHI_SNOW1_PATH4:    ; Path 4
    FCB 85              ; path4: intensity
    FCB $FF,$04,0,0        ; path4: header (y=-1, x=4)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB 2                ; End marker (path complete)

_TITCHI_SNOW1_PATH5:    ; Path 5
    FCB 85              ; path5: intensity
    FCB $03,$04,0,0        ; path5: header (y=3, x=4)
    FCB $FF,$02,$FB          ; flag=-1, dy=2, dx=-5
    FCB 2                ; End marker (path complete)

_TITCHI_SNOW1_PATH6:    ; Path 6
    FCB 100              ; path6: intensity
    FCB $04,$FD,0,0        ; path6: header (y=4, x=-3)
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB 2                ; End marker (path complete)

_TITCHI_SNOW1_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $05,$FB,0,0        ; path7: header (y=5, x=-5)
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB $FF,$01,$02          ; flag=-1, dy=1, dx=2
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB $FF,$01,$02          ; flag=-1, dy=1, dx=2
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB 2                ; End marker (path complete)

_TITCHI_SNOW1_PATH8:    ; Path 8
    FCB 85              ; path8: intensity
    FCB $04,$03,0,0        ; path8: header (y=4, x=3)
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB 2                ; End marker (path complete)

_TITCHI_SNOW1_PATH9:    ; Path 9
    FCB 85              ; path9: intensity
    FCB $03,$04,0,0        ; path9: header (y=3, x=4)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB 2                ; End marker (path complete)

_TITCHI_SNOW1_PATH10:    ; Path 10
    FCB 85              ; path10: intensity
    FCB $03,$02,0,0        ; path10: header (y=3, x=2)
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB 2                ; End marker (path complete)

_TITCHI_SNOW1_PATH11:    ; Path 11
    FCB 85              ; path11: intensity
    FCB $FD,$05,0,0        ; path11: header (y=-3, x=5)
    FCB 2                ; End marker (path complete)

_TITCHI_SNOW1_PATH12:    ; Path 12
    FCB 85              ; path12: intensity
    FCB $FB,$03,0,0        ; path12: header (y=-5, x=3)
    FCB $FF,$FE,$03          ; flag=-1, dy=-2, dx=3
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB 2                ; End marker (path complete)

; Generated from platform4.vec (Malban Draw_Sync_List format)
; Total paths: 9, points: 49
; X bounds: min=-70, max=70, width=140
; Center: (0, 0)

_PLATFORM4_WIDTH EQU 140
_PLATFORM4_HALF_WIDTH EQU 70
_PLATFORM4_HEIGHT EQU 36
_PLATFORM4_HALF_HEIGHT EQU 18
_PLATFORM4_CENTER_X EQU 0
_PLATFORM4_CENTER_Y EQU 0

_PLATFORM4_VECTORS:  ; Main entry (header + 9 path(s))
    FDB 9               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLATFORM4_PATH0        ; pointer to path 0
    FDB _PLATFORM4_PATH1        ; pointer to path 1
    FDB _PLATFORM4_PATH2        ; pointer to path 2
    FDB _PLATFORM4_PATH3        ; pointer to path 3
    FDB _PLATFORM4_PATH4        ; pointer to path 4
    FDB _PLATFORM4_PATH5        ; pointer to path 5
    FDB _PLATFORM4_PATH6        ; pointer to path 6
    FDB _PLATFORM4_PATH7        ; pointer to path 7
    FDB _PLATFORM4_PATH8        ; pointer to path 8

_PLATFORM4_PATH0:    ; Path 0
    FCB 85              ; path0: intensity
    FCB $FD,$05,0,0        ; path0: header (y=-3, x=5)
    FCB $FF,$FA,$FB          ; flag=-1, dy=-6, dx=-5
    FCB 2                ; End marker (path complete)

_PLATFORM4_PATH1:    ; Path 1
    FCB 85              ; path1: intensity
    FCB $F7,$00,0,0        ; path1: header (y=-9, x=0)
    FCB $FF,$05,$FB          ; flag=-1, dy=5, dx=-5
    FCB 2                ; End marker (path complete)

_PLATFORM4_PATH2:    ; Path 2
    FCB 85              ; path2: intensity
    FCB $00,$F5,0,0        ; path2: header (y=0, x=-11)
    FCB $FF,$00,$E8          ; flag=-1, dy=0, dx=-24
    FCB $FF,$EE,$00          ; flag=-1, dy=-18, dx=0
    FCB 2                ; End marker (path complete)

_PLATFORM4_PATH3:    ; Path 3
    FCB 85              ; path3: intensity
    FCB $EE,$EA,0,0        ; path3: header (y=-18, x=-22)
    FCB $FF,$05,$08          ; flag=-1, dy=5, dx=8
    FCB $FF,$08,$F9          ; flag=-1, dy=8, dx=-7
    FCB $FF,$02,$0B          ; flag=-1, dy=2, dx=11
    FCB $FF,$0D,$FE          ; flag=-1, dy=13, dx=-2
    FCB $FF,$FB,$08          ; flag=-1, dy=-5, dx=8
    FCB $FF,$0A,$04          ; flag=-1, dy=10, dx=4
    FCB $FF,$F5,$05          ; flag=-1, dy=-11, dx=5
    FCB $FF,$06,$07          ; flag=-1, dy=6, dx=7
    FCB $FF,$F4,$FF          ; flag=-1, dy=-12, dx=-1
    FCB $FF,$FE,$0B          ; flag=-1, dy=-2, dx=11
    FCB $FF,$F7,$FA          ; flag=-1, dy=-9, dx=-6
    FCB $FF,$FB,$06          ; flag=-1, dy=-5, dx=6
    FCB 2                ; End marker (path complete)

_PLATFORM4_PATH4:    ; Path 4
    FCB 85              ; path4: intensity
    FCB $EE,$10,0,0        ; path4: header (y=-18, x=16)
    FCB $FF,$0A,$FD          ; flag=-1, dy=10, dx=-3
    FCB $FF,$07,$FC          ; flag=-1, dy=7, dx=-4
    FCB $FF,$05,$F7          ; flag=-1, dy=5, dx=-9
    FCB $FF,$FD,$FA          ; flag=-1, dy=-3, dx=-6
    FCB $FF,$F8,$FA          ; flag=-1, dy=-8, dx=-6
    FCB $FF,$F5,$FE          ; flag=-1, dy=-11, dx=-2
    FCB 2                ; End marker (path complete)

_PLATFORM4_PATH5:    ; Path 5
    FCB 85              ; path5: intensity
    FCB $EE,$F4,0,0        ; path5: header (y=-18, x=-12)
    FCB $FF,$09,$03          ; flag=-1, dy=9, dx=3
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$FE,$03          ; flag=-1, dy=-2, dx=3
    FCB $FF,$F7,$02          ; flag=-1, dy=-9, dx=2
    FCB 2                ; End marker (path complete)

_PLATFORM4_PATH6:    ; Path 6
    FCB 85              ; path6: intensity
    FCB $EE,$02,0,0        ; path6: header (y=-18, x=2)
    FCB $FF,$09,$03          ; flag=-1, dy=9, dx=3
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$FE,$03          ; flag=-1, dy=-2, dx=3
    FCB $FF,$F7,$02          ; flag=-1, dy=-9, dx=2
    FCB 2                ; End marker (path complete)

_PLATFORM4_PATH7:    ; Path 7
    FCB 85              ; path7: intensity
    FCB $00,$0D,0,0        ; path7: header (y=0, x=13)
    FCB $FF,$00,$17          ; flag=-1, dy=0, dx=23
    FCB $FF,$EE,$00          ; flag=-1, dy=-18, dx=0
    FCB 2                ; End marker (path complete)

_PLATFORM4_PATH8:    ; Path 8
    FCB 85              ; path8: intensity
    FCB $00,$BA,0,0        ; path8: header (y=0, x=-70)
    FCB $FF,$00,$19          ; flag=-1, dy=0, dx=25
    FCB $FF,$12,$00          ; flag=-1, dy=18, dx=0
    FCB $FF,$00,$5C          ; flag=-1, dy=0, dx=92
    FCB $FF,$F0,$00          ; flag=-1, dy=-16, dx=0
    FCB $FF,$00,$17          ; flag=-1, dy=0, dx=23
    FCB $FF,$EC,$00          ; flag=-1, dy=-20, dx=0
    FCB $FF,$00,$BA          ; sub-seg 1/2 of line 6: dy=0, dx=-70
    FCB $FF,$00,$BA          ; sub-seg 2/2 of line 6: dy=0, dx=-70
    FCB $FF,$12,$00          ; flag=-1, dy=18, dx=0
    FCB 2                ; End marker (path complete)

; Generated from player_jump.vec (Malban Draw_Sync_List format)
; Total paths: 15, points: 40
; X bounds: min=-6, max=7, width=13
; Center: (0, -1)

_PLAYER_JUMP_WIDTH EQU 13
_PLAYER_JUMP_HALF_WIDTH EQU 6
_PLAYER_JUMP_HEIGHT EQU 20
_PLAYER_JUMP_HALF_HEIGHT EQU 10
_PLAYER_JUMP_CENTER_X EQU 0
_PLAYER_JUMP_CENTER_Y EQU -1

_PLAYER_JUMP_VECTORS:  ; Main entry (header + 15 path(s))
    FDB 15               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLAYER_JUMP_PATH0        ; pointer to path 0
    FDB _PLAYER_JUMP_PATH1        ; pointer to path 1
    FDB _PLAYER_JUMP_PATH2        ; pointer to path 2
    FDB _PLAYER_JUMP_PATH3        ; pointer to path 3
    FDB _PLAYER_JUMP_PATH4        ; pointer to path 4
    FDB _PLAYER_JUMP_PATH5        ; pointer to path 5
    FDB _PLAYER_JUMP_PATH6        ; pointer to path 6
    FDB _PLAYER_JUMP_PATH7        ; pointer to path 7
    FDB _PLAYER_JUMP_PATH8        ; pointer to path 8
    FDB _PLAYER_JUMP_PATH9        ; pointer to path 9
    FDB _PLAYER_JUMP_PATH10        ; pointer to path 10
    FDB _PLAYER_JUMP_PATH11        ; pointer to path 11
    FDB _PLAYER_JUMP_PATH12        ; pointer to path 12
    FDB _PLAYER_JUMP_PATH13        ; pointer to path 13
    FDB _PLAYER_JUMP_PATH14        ; pointer to path 14

_PLAYER_JUMP_PATH0:    ; Path 0
    FCB 65              ; path0: intensity
    FCB $00,$01,0,0        ; path0: header (y=0, x=1)
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_JUMP_PATH1:    ; Path 1
    FCB 65              ; path1: intensity
    FCB $FF,$01,0,0        ; path1: header (y=-1, x=1)
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_JUMP_PATH2:    ; Path 2
    FCB 65              ; path2: intensity
    FCB $00,$03,0,0        ; path2: header (y=0, x=3)
    FCB $FF,$03,$04          ; flag=-1, dy=3, dx=4
    FCB $FF,$FA,$FC          ; flag=-1, dy=-6, dx=-4
    FCB 2                ; End marker (path complete)

_PLAYER_JUMP_PATH3:    ; Path 3
    FCB 65              ; path3: intensity
    FCB $FE,$04,0,0        ; path3: header (y=-2, x=4)
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_JUMP_PATH4:    ; Path 4
    FCB 65              ; path4: intensity
    FCB $FB,$03,0,0        ; path4: header (y=-5, x=3)
    FCB $FF,$FB,$02          ; flag=-1, dy=-5, dx=2
    FCB $FF,$02,$FC          ; flag=-1, dy=2, dx=-4
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_JUMP_PATH5:    ; Path 5
    FCB 65              ; path5: intensity
    FCB $FE,$04,0,0        ; path5: header (y=-2, x=4)
    FCB $FF,$01,$FF          ; flag=-1, dy=1, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_JUMP_PATH6:    ; Path 6
    FCB 65              ; path6: intensity
    FCB $03,$01,0,0        ; path6: header (y=3, x=1)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB 2                ; End marker (path complete)

_PLAYER_JUMP_PATH7:    ; Path 7
    FCB 65              ; path7: intensity
    FCB $02,$FE,0,0        ; path7: header (y=2, x=-2)
    FCB $FF,$FE,$FD          ; flag=-1, dy=-2, dx=-3
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_JUMP_PATH8:    ; Path 8
    FCB 65              ; path8: intensity
    FCB $FF,$FD,0,0        ; path8: header (y=-1, x=-3)
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_JUMP_PATH9:    ; Path 9
    FCB 65              ; path9: intensity
    FCB $FD,$FD,0,0        ; path9: header (y=-3, x=-3)
    FCB $FF,$FB,$04          ; flag=-1, dy=-5, dx=4
    FCB 2                ; End marker (path complete)

_PLAYER_JUMP_PATH10:    ; Path 10
    FCB 65              ; path10: intensity
    FCB $FA,$FF,0,0        ; path10: header (y=-6, x=-1)
    FCB $FF,$FD,$FB          ; flag=-1, dy=-3, dx=-5
    FCB $FF,$06,$03          ; flag=-1, dy=6, dx=3
    FCB 2                ; End marker (path complete)

_PLAYER_JUMP_PATH11:    ; Path 11
    FCB 65              ; path11: intensity
    FCB $FA,$FE,0,0        ; path11: header (y=-6, x=-2)
    FCB 2                ; End marker (path complete)

_PLAYER_JUMP_PATH12:    ; Path 12
    FCB 65              ; path12: intensity
    FCB $07,$FE,0,0        ; path12: header (y=7, x=-2)
    FCB $FF,$01,$03          ; flag=-1, dy=1, dx=3
    FCB 2                ; End marker (path complete)

_PLAYER_JUMP_PATH13:    ; Path 13
    FCB 65              ; path13: intensity
    FCB $08,$01,0,0        ; path13: header (y=8, x=1)
    FCB $FF,$FD,$04          ; flag=-1, dy=-3, dx=4
    FCB $FF,$FB,$FD          ; flag=-1, dy=-5, dx=-3
    FCB $FF,$02,$FC          ; flag=-1, dy=2, dx=-4
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_JUMP_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $07,$FE,0,0        ; path14: header (y=7, x=-2)
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$01,$02          ; flag=-1, dy=1, dx=2
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB 2                ; End marker (path complete)

; Generated from player_die1.vec (Malban Draw_Sync_List format)
; Total paths: 13, points: 38
; X bounds: min=-6, max=9, width=15
; Center: (1, 0)

_PLAYER_DIE1_WIDTH EQU 15
_PLAYER_DIE1_HALF_WIDTH EQU 7
_PLAYER_DIE1_HEIGHT EQU 18
_PLAYER_DIE1_HALF_HEIGHT EQU 9
_PLAYER_DIE1_CENTER_X EQU 1
_PLAYER_DIE1_CENTER_Y EQU 0

_PLAYER_DIE1_VECTORS:  ; Main entry (header + 13 path(s))
    FDB 13               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLAYER_DIE1_PATH0        ; pointer to path 0
    FDB _PLAYER_DIE1_PATH1        ; pointer to path 1
    FDB _PLAYER_DIE1_PATH2        ; pointer to path 2
    FDB _PLAYER_DIE1_PATH3        ; pointer to path 3
    FDB _PLAYER_DIE1_PATH4        ; pointer to path 4
    FDB _PLAYER_DIE1_PATH5        ; pointer to path 5
    FDB _PLAYER_DIE1_PATH6        ; pointer to path 6
    FDB _PLAYER_DIE1_PATH7        ; pointer to path 7
    FDB _PLAYER_DIE1_PATH8        ; pointer to path 8
    FDB _PLAYER_DIE1_PATH9        ; pointer to path 9
    FDB _PLAYER_DIE1_PATH10        ; pointer to path 10
    FDB _PLAYER_DIE1_PATH11        ; pointer to path 11
    FDB _PLAYER_DIE1_PATH12        ; pointer to path 12

_PLAYER_DIE1_PATH0:    ; Path 0
    FCB 65              ; path0: intensity
    FCB $FF,$FE,0,0        ; path0: header (y=-1, x=-2)
    FCB $FF,$FC,$FE          ; flag=-1, dy=-4, dx=-2
    FCB $FF,$FC,$01          ; flag=-1, dy=-4, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_DIE1_PATH1:    ; Path 1
    FCB 65              ; path1: intensity
    FCB $F8,$FD,0,0        ; path1: header (y=-8, x=-3)
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$03,$03          ; flag=-1, dy=3, dx=3
    FCB 2                ; End marker (path complete)

_PLAYER_DIE1_PATH2:    ; Path 2
    FCB 65              ; path2: intensity
    FCB $F9,$FD,0,0        ; path2: header (y=-7, x=-3)
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB 2                ; End marker (path complete)

_PLAYER_DIE1_PATH3:    ; Path 3
    FCB 65              ; path3: intensity
    FCB $FF,$01,0,0        ; path3: header (y=-1, x=1)
    FCB $FF,$FC,$02          ; flag=-1, dy=-4, dx=2
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_DIE1_PATH4:    ; Path 4
    FCB 65              ; path4: intensity
    FCB $F7,$06,0,0        ; path4: header (y=-9, x=6)
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_DIE1_PATH5:    ; Path 5
    FCB 65              ; path5: intensity
    FCB $00,$07,0,0        ; path5: header (y=0, x=7)
    FCB $FF,$04,$01          ; flag=-1, dy=4, dx=1
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_DIE1_PATH6:    ; Path 6
    FCB 65              ; path6: intensity
    FCB $02,$07,0,0        ; path6: header (y=2, x=7)
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB 2                ; End marker (path complete)

_PLAYER_DIE1_PATH7:    ; Path 7
    FCB 65              ; path7: intensity
    FCB $03,$00,0,0        ; path7: header (y=3, x=0)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB 2                ; End marker (path complete)

_PLAYER_DIE1_PATH8:    ; Path 8
    FCB 65              ; path8: intensity
    FCB $04,$FE,0,0        ; path8: header (y=4, x=-2)
    FCB $FF,$03,$FC          ; flag=-1, dy=3, dx=-4
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_DIE1_PATH9:    ; Path 9
    FCB 65              ; path9: intensity
    FCB $09,$FD,0,0        ; path9: header (y=9, x=-3)
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB 2                ; End marker (path complete)

_PLAYER_DIE1_PATH10:    ; Path 10
    FCB 65              ; path10: intensity
    FCB $08,$FE,0,0        ; path10: header (y=8, x=-2)
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_DIE1_PATH11:    ; Path 11
    FCB 65              ; path11: intensity
    FCB $08,$00,0,0        ; path11: header (y=8, x=0)
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB $FF,$FF,$FF          ; flag=-1, dy=-1, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_DIE1_PATH12:    ; Path 12
    FCB 65              ; path12: intensity
    FCB $07,$01,0,0        ; path12: header (y=7, x=1)
    FCB $FF,$FD,$03          ; flag=-1, dy=-3, dx=3
    FCB $FF,$FB,$FD          ; flag=-1, dy=-5, dx=-3
    FCB $FF,$02,$FD          ; flag=-1, dy=2, dx=-3
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

; Generated from titchi_snow2.vec (Malban Draw_Sync_List format)
; Total paths: 8, points: 42
; X bounds: min=-7, max=7, width=14
; Center: (0, 1)

_TITCHI_SNOW2_WIDTH EQU 14
_TITCHI_SNOW2_HALF_WIDTH EQU 7
_TITCHI_SNOW2_HEIGHT EQU 16
_TITCHI_SNOW2_HALF_HEIGHT EQU 8
_TITCHI_SNOW2_CENTER_X EQU 0
_TITCHI_SNOW2_CENTER_Y EQU 1

_TITCHI_SNOW2_VECTORS:  ; Main entry (header + 8 path(s))
    FDB 8               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _TITCHI_SNOW2_PATH0        ; pointer to path 0
    FDB _TITCHI_SNOW2_PATH1        ; pointer to path 1
    FDB _TITCHI_SNOW2_PATH2        ; pointer to path 2
    FDB _TITCHI_SNOW2_PATH3        ; pointer to path 3
    FDB _TITCHI_SNOW2_PATH4        ; pointer to path 4
    FDB _TITCHI_SNOW2_PATH5        ; pointer to path 5
    FDB _TITCHI_SNOW2_PATH6        ; pointer to path 6
    FDB _TITCHI_SNOW2_PATH7        ; pointer to path 7

_TITCHI_SNOW2_PATH0:    ; Path 0
    FCB 40              ; path0: intensity
    FCB $FE,$FE,0,0        ; path0: header (y=-2, x=-2)
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB 2                ; End marker (path complete)

_TITCHI_SNOW2_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $01,$FA,0,0        ; path1: header (y=1, x=-6)
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB $FF,$01,$03          ; flag=-1, dy=1, dx=3
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FF,$03          ; flag=-1, dy=-1, dx=3
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FF,$FB          ; flag=-1, dy=-1, dx=-5
    FCB $FF,$02,$FB          ; flag=-1, dy=2, dx=-5
    FCB 2                ; End marker (path complete)

_TITCHI_SNOW2_PATH2:    ; Path 2
    FCB 110              ; path2: intensity
    FCB $02,$FB,0,0        ; path2: header (y=2, x=-5)
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$01,$02          ; flag=-1, dy=1, dx=2
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB 2                ; End marker (path complete)

_TITCHI_SNOW2_PATH3:    ; Path 3
    FCB 40              ; path3: intensity
    FCB $03,$FD,0,0        ; path3: header (y=3, x=-3)
    FCB $FF,$FD,$FE          ; flag=-1, dy=-3, dx=-2
    FCB $FF,$FA,$02          ; flag=-1, dy=-6, dx=2
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$01,$06          ; flag=-1, dy=1, dx=6
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB 2                ; End marker (path complete)

_TITCHI_SNOW2_PATH4:    ; Path 4
    FCB 40              ; path4: intensity
    FCB $FE,$04,0,0        ; path4: header (y=-2, x=4)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB 2                ; End marker (path complete)

_TITCHI_SNOW2_PATH5:    ; Path 5
    FCB 40              ; path5: intensity
    FCB $02,$02,0,0        ; path5: header (y=2, x=2)
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB 2                ; End marker (path complete)

_TITCHI_SNOW2_PATH6:    ; Path 6
    FCB 100              ; path6: intensity
    FCB $06,$02,0,0        ; path6: header (y=6, x=2)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$01,$FF          ; flag=-1, dy=1, dx=-1
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB 2                ; End marker (path complete)

_TITCHI_SNOW2_PATH7:    ; Path 7
    FCB 40              ; path7: intensity
    FCB $FA,$03,0,0        ; path7: header (y=-6, x=3)
    FCB $FF,$FE,$03          ; flag=-1, dy=-2, dx=3
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB 2                ; End marker (path complete)

; Generated from player_die2.vec (Malban Draw_Sync_List format)
; Total paths: 12, points: 37
; X bounds: min=-8, max=10, width=18
; Center: (1, 0)

_PLAYER_DIE2_WIDTH EQU 18
_PLAYER_DIE2_HALF_WIDTH EQU 9
_PLAYER_DIE2_HEIGHT EQU 20
_PLAYER_DIE2_HALF_HEIGHT EQU 10
_PLAYER_DIE2_CENTER_X EQU 1
_PLAYER_DIE2_CENTER_Y EQU 0

_PLAYER_DIE2_VECTORS:  ; Main entry (header + 12 path(s))
    FDB 12               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLAYER_DIE2_PATH0        ; pointer to path 0
    FDB _PLAYER_DIE2_PATH1        ; pointer to path 1
    FDB _PLAYER_DIE2_PATH2        ; pointer to path 2
    FDB _PLAYER_DIE2_PATH3        ; pointer to path 3
    FDB _PLAYER_DIE2_PATH4        ; pointer to path 4
    FDB _PLAYER_DIE2_PATH5        ; pointer to path 5
    FDB _PLAYER_DIE2_PATH6        ; pointer to path 6
    FDB _PLAYER_DIE2_PATH7        ; pointer to path 7
    FDB _PLAYER_DIE2_PATH8        ; pointer to path 8
    FDB _PLAYER_DIE2_PATH9        ; pointer to path 9
    FDB _PLAYER_DIE2_PATH10        ; pointer to path 10
    FDB _PLAYER_DIE2_PATH11        ; pointer to path 11

_PLAYER_DIE2_PATH0:    ; Path 0
    FCB 65              ; path0: intensity
    FCB $FD,$FD,0,0        ; path0: header (y=-3, x=-3)
    FCB $FF,$FC,$FD          ; flag=-1, dy=-4, dx=-3
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_DIE2_PATH1:    ; Path 1
    FCB 65              ; path1: intensity
    FCB $F9,$FA,0,0        ; path1: header (y=-7, x=-6)
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_DIE2_PATH2:    ; Path 2
    FCB 65              ; path2: intensity
    FCB $FC,$FD,0,0        ; path2: header (y=-4, x=-3)
    FCB $FF,$03,$03          ; flag=-1, dy=3, dx=3
    FCB $FF,$05,$05          ; flag=-1, dy=5, dx=5
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_DIE2_PATH3:    ; Path 3
    FCB 65              ; path3: intensity
    FCB $06,$03,0,0        ; path3: header (y=6, x=3)
    FCB $FF,$02,$FD          ; flag=-1, dy=2, dx=-3
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_DIE2_PATH4:    ; Path 4
    FCB 65              ; path4: intensity
    FCB $0A,$FE,0,0        ; path4: header (y=10, x=-2)
    FCB $FF,$FF,$FF          ; flag=-1, dy=-1, dx=-1
    FCB $FF,$FD,$03          ; flag=-1, dy=-3, dx=3
    FCB 2                ; End marker (path complete)

_PLAYER_DIE2_PATH5:    ; Path 5
    FCB 65              ; path5: intensity
    FCB $04,$01,0,0        ; path5: header (y=4, x=1)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_DIE2_PATH6:    ; Path 6
    FCB 65              ; path6: intensity
    FCB $07,$03,0,0        ; path6: header (y=7, x=3)
    FCB $FF,$FE,$03          ; flag=-1, dy=-2, dx=3
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_DIE2_PATH7:    ; Path 7
    FCB 65              ; path7: intensity
    FCB $06,$04,0,0        ; path7: header (y=6, x=4)
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_DIE2_PATH8:    ; Path 8
    FCB 65              ; path8: intensity
    FCB $03,$05,0,0        ; path8: header (y=3, x=5)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$FD,$FC          ; flag=-1, dy=-3, dx=-4
    FCB $FF,$FD,$FD          ; flag=-1, dy=-3, dx=-3
    FCB 2                ; End marker (path complete)

_PLAYER_DIE2_PATH9:    ; Path 9
    FCB 65              ; path9: intensity
    FCB $FB,$FF,0,0        ; path9: header (y=-5, x=-1)
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_DIE2_PATH10:    ; Path 10
    FCB 65              ; path10: intensity
    FCB $F7,$02,0,0        ; path10: header (y=-9, x=2)
    FCB $FF,$FF,$FD          ; flag=-1, dy=-1, dx=-3
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_DIE2_PATH11:    ; Path 11
    FCB 65              ; path11: intensity
    FCB $01,$04,0,0        ; path11: header (y=1, x=4)
    FCB $FF,$FE,$04          ; flag=-1, dy=-2, dx=4
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB 2                ; End marker (path complete)

; Generated from titchi_idle.vec (Malban Draw_Sync_List format)
; Total paths: 11, points: 37
; X bounds: min=-7, max=7, width=14
; Center: (0, 0)

_TITCHI_IDLE_WIDTH EQU 14
_TITCHI_IDLE_HALF_WIDTH EQU 7
_TITCHI_IDLE_HEIGHT EQU 13
_TITCHI_IDLE_HALF_HEIGHT EQU 6
_TITCHI_IDLE_CENTER_X EQU 0
_TITCHI_IDLE_CENTER_Y EQU 0

_TITCHI_IDLE_VECTORS:  ; Main entry (header + 11 path(s))
    FDB 11               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _TITCHI_IDLE_PATH0        ; pointer to path 0
    FDB _TITCHI_IDLE_PATH1        ; pointer to path 1
    FDB _TITCHI_IDLE_PATH2        ; pointer to path 2
    FDB _TITCHI_IDLE_PATH3        ; pointer to path 3
    FDB _TITCHI_IDLE_PATH4        ; pointer to path 4
    FDB _TITCHI_IDLE_PATH5        ; pointer to path 5
    FDB _TITCHI_IDLE_PATH6        ; pointer to path 6
    FDB _TITCHI_IDLE_PATH7        ; pointer to path 7
    FDB _TITCHI_IDLE_PATH8        ; pointer to path 8
    FDB _TITCHI_IDLE_PATH9        ; pointer to path 9
    FDB _TITCHI_IDLE_PATH10        ; pointer to path 10

_TITCHI_IDLE_PATH0:    ; Path 0
    FCB 85              ; path0: intensity
    FCB $FF,$FE,0,0        ; path0: header (y=-1, x=-2)
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB 2                ; End marker (path complete)

_TITCHI_IDLE_PATH1:    ; Path 1
    FCB 85              ; path1: intensity
    FCB $FC,$FC,0,0        ; path1: header (y=-4, x=-4)
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB 2                ; End marker (path complete)

_TITCHI_IDLE_PATH2:    ; Path 2
    FCB 85              ; path2: intensity
    FCB $03,$FE,0,0        ; path2: header (y=3, x=-2)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB 2                ; End marker (path complete)

_TITCHI_IDLE_PATH3:    ; Path 3
    FCB 85              ; path3: intensity
    FCB $04,$FD,0,0        ; path3: header (y=4, x=-3)
    FCB $FF,$FD,$FE          ; flag=-1, dy=-3, dx=-2
    FCB $FF,$FA,$02          ; flag=-1, dy=-6, dx=2
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$01,$06          ; flag=-1, dy=1, dx=6
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB 2                ; End marker (path complete)

_TITCHI_IDLE_PATH4:    ; Path 4
    FCB 85              ; path4: intensity
    FCB $FF,$04,0,0        ; path4: header (y=-1, x=4)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB 2                ; End marker (path complete)

_TITCHI_IDLE_PATH5:    ; Path 5
    FCB 85              ; path5: intensity
    FCB $03,$04,0,0        ; path5: header (y=3, x=4)
    FCB $FF,$02,$FB          ; flag=-1, dy=2, dx=-5
    FCB 2                ; End marker (path complete)

_TITCHI_IDLE_PATH6:    ; Path 6
    FCB 85              ; path6: intensity
    FCB $03,$02,0,0        ; path6: header (y=3, x=2)
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB 2                ; End marker (path complete)

_TITCHI_IDLE_PATH7:    ; Path 7
    FCB 85              ; path7: intensity
    FCB $04,$03,0,0        ; path7: header (y=4, x=3)
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB 2                ; End marker (path complete)

_TITCHI_IDLE_PATH8:    ; Path 8
    FCB 85              ; path8: intensity
    FCB $03,$04,0,0        ; path8: header (y=3, x=4)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB 2                ; End marker (path complete)

_TITCHI_IDLE_PATH9:    ; Path 9
    FCB 85              ; path9: intensity
    FCB $FD,$05,0,0        ; path9: header (y=-3, x=5)
    FCB 2                ; End marker (path complete)

_TITCHI_IDLE_PATH10:    ; Path 10
    FCB 85              ; path10: intensity
    FCB $FB,$03,0,0        ; path10: header (y=-5, x=3)
    FCB $FF,$FE,$03          ; flag=-1, dy=-2, dx=3
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB 2                ; End marker (path complete)

; Generated from player_die3.vec (Malban Draw_Sync_List format)
; Total paths: 12, points: 36
; X bounds: min=-8, max=8, width=16
; Center: (0, 0)

_PLAYER_DIE3_WIDTH EQU 16
_PLAYER_DIE3_HALF_WIDTH EQU 8
_PLAYER_DIE3_HEIGHT EQU 17
_PLAYER_DIE3_HALF_HEIGHT EQU 8
_PLAYER_DIE3_CENTER_X EQU 0
_PLAYER_DIE3_CENTER_Y EQU 0

_PLAYER_DIE3_VECTORS:  ; Main entry (header + 12 path(s))
    FDB 12               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLAYER_DIE3_PATH0        ; pointer to path 0
    FDB _PLAYER_DIE3_PATH1        ; pointer to path 1
    FDB _PLAYER_DIE3_PATH2        ; pointer to path 2
    FDB _PLAYER_DIE3_PATH3        ; pointer to path 3
    FDB _PLAYER_DIE3_PATH4        ; pointer to path 4
    FDB _PLAYER_DIE3_PATH5        ; pointer to path 5
    FDB _PLAYER_DIE3_PATH6        ; pointer to path 6
    FDB _PLAYER_DIE3_PATH7        ; pointer to path 7
    FDB _PLAYER_DIE3_PATH8        ; pointer to path 8
    FDB _PLAYER_DIE3_PATH9        ; pointer to path 9
    FDB _PLAYER_DIE3_PATH10        ; pointer to path 10
    FDB _PLAYER_DIE3_PATH11        ; pointer to path 11

_PLAYER_DIE3_PATH0:    ; Path 0
    FCB 65              ; path0: intensity
    FCB $FE,$01,0,0        ; path0: header (y=-2, x=1)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB 2                ; End marker (path complete)

_PLAYER_DIE3_PATH1:    ; Path 1
    FCB 65              ; path1: intensity
    FCB $00,$03,0,0        ; path1: header (y=0, x=3)
    FCB $FF,$04,$04          ; flag=-1, dy=4, dx=4
    FCB $FF,$FF,$01          ; flag=-1, dy=-1, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_DIE3_PATH2:    ; Path 2
    FCB 65              ; path2: intensity
    FCB $06,$04,0,0        ; path2: header (y=6, x=4)
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_DIE3_PATH3:    ; Path 3
    FCB 65              ; path3: intensity
    FCB $09,$05,0,0        ; path3: header (y=9, x=5)
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$FB,$FE          ; flag=-1, dy=-5, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_DIE3_PATH4:    ; Path 4
    FCB 65              ; path4: intensity
    FCB $01,$FE,0,0        ; path4: header (y=1, x=-2)
    FCB $FF,$05,$FF          ; flag=-1, dy=5, dx=-1
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_DIE3_PATH5:    ; Path 5
    FCB 65              ; path5: intensity
    FCB $09,$FE,0,0        ; path5: header (y=9, x=-2)
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_DIE3_PATH6:    ; Path 6
    FCB 65              ; path6: intensity
    FCB $08,$FC,0,0        ; path6: header (y=8, x=-4)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_DIE3_PATH7:    ; Path 7
    FCB 65              ; path7: intensity
    FCB $03,$F8,0,0        ; path7: header (y=3, x=-8)
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB $FF,$FC,$04          ; flag=-1, dy=-4, dx=4
    FCB 2                ; End marker (path complete)

_PLAYER_DIE3_PATH8:    ; Path 8
    FCB 65              ; path8: intensity
    FCB $FB,$FE,0,0        ; path8: header (y=-5, x=-2)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$01,$04          ; flag=-1, dy=1, dx=4
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$FC,$FD          ; flag=-1, dy=-4, dx=-3
    FCB 2                ; End marker (path complete)

_PLAYER_DIE3_PATH9:    ; Path 9
    FCB 65              ; path9: intensity
    FCB $FA,$01,0,0        ; path9: header (y=-6, x=1)
    FCB $FF,$FF,$01          ; flag=-1, dy=-1, dx=1
    FCB $FF,$01,$FF          ; flag=-1, dy=1, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_DIE3_PATH10:    ; Path 10
    FCB 65              ; path10: intensity
    FCB $F9,$00,0,0        ; path10: header (y=-7, x=0)
    FCB $FF,$FF,$01          ; flag=-1, dy=-1, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_DIE3_PATH11:    ; Path 11
    FCB 65              ; path11: intensity
    FCB $F9,$FF,0,0        ; path11: header (y=-7, x=-1)
    FCB $FF,$01,$03          ; flag=-1, dy=1, dx=3
    FCB $FF,$FF,$FD          ; flag=-1, dy=-1, dx=-3
    FCB 2                ; End marker (path complete)

; Generated from player_die4.vec (Malban Draw_Sync_List format)
; Total paths: 16, points: 32
; X bounds: min=-8, max=9, width=17
; Center: (0, 0)

_PLAYER_DIE4_WIDTH EQU 17
_PLAYER_DIE4_HALF_WIDTH EQU 8
_PLAYER_DIE4_HEIGHT EQU 14
_PLAYER_DIE4_HALF_HEIGHT EQU 7
_PLAYER_DIE4_CENTER_X EQU 0
_PLAYER_DIE4_CENTER_Y EQU 0

_PLAYER_DIE4_VECTORS:  ; Main entry (header + 16 path(s))
    FDB 16               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLAYER_DIE4_PATH0        ; pointer to path 0
    FDB _PLAYER_DIE4_PATH1        ; pointer to path 1
    FDB _PLAYER_DIE4_PATH2        ; pointer to path 2
    FDB _PLAYER_DIE4_PATH3        ; pointer to path 3
    FDB _PLAYER_DIE4_PATH4        ; pointer to path 4
    FDB _PLAYER_DIE4_PATH5        ; pointer to path 5
    FDB _PLAYER_DIE4_PATH6        ; pointer to path 6
    FDB _PLAYER_DIE4_PATH7        ; pointer to path 7
    FDB _PLAYER_DIE4_PATH8        ; pointer to path 8
    FDB _PLAYER_DIE4_PATH9        ; pointer to path 9
    FDB _PLAYER_DIE4_PATH10        ; pointer to path 10
    FDB _PLAYER_DIE4_PATH11        ; pointer to path 11
    FDB _PLAYER_DIE4_PATH12        ; pointer to path 12
    FDB _PLAYER_DIE4_PATH13        ; pointer to path 13
    FDB _PLAYER_DIE4_PATH14        ; pointer to path 14
    FDB _PLAYER_DIE4_PATH15        ; pointer to path 15

_PLAYER_DIE4_PATH0:    ; Path 0
    FCB 65              ; path0: intensity
    FCB $01,$00,0,0        ; path0: header (y=1, x=0)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_DIE4_PATH1:    ; Path 1
    FCB 65              ; path1: intensity
    FCB $FE,$02,0,0        ; path1: header (y=-2, x=2)
    FCB $FF,$FD,$FC          ; flag=-1, dy=-3, dx=-4
    FCB 2                ; End marker (path complete)

_PLAYER_DIE4_PATH2:    ; Path 2
    FCB 65              ; path2: intensity
    FCB $FB,$FC,0,0        ; path2: header (y=-5, x=-4)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_DIE4_PATH3:    ; Path 3
    FCB 65              ; path3: intensity
    FCB $F9,$FC,0,0        ; path3: header (y=-7, x=-4)
    FCB $FF,$04,$FD          ; flag=-1, dy=4, dx=-3
    FCB 2                ; End marker (path complete)

_PLAYER_DIE4_PATH4:    ; Path 4
    FCB 65              ; path4: intensity
    FCB $FB,$FA,0,0        ; path4: header (y=-5, x=-6)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_DIE4_PATH5:    ; Path 5
    FCB 65              ; path5: intensity
    FCB $FF,$00,0,0        ; path5: header (y=-1, x=0)
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_DIE4_PATH6:    ; Path 6
    FCB 65              ; path6: intensity
    FCB $05,$01,0,0        ; path6: header (y=5, x=1)
    FCB $FF,$FD,$FC          ; flag=-1, dy=-3, dx=-4
    FCB 2                ; End marker (path complete)

_PLAYER_DIE4_PATH7:    ; Path 7
    FCB 65              ; path7: intensity
    FCB $05,$FB,0,0        ; path7: header (y=5, x=-5)
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_DIE4_PATH8:    ; Path 8
    FCB 65              ; path8: intensity
    FCB $07,$FB,0,0        ; path8: header (y=7, x=-5)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_DIE4_PATH9:    ; Path 9
    FCB 65              ; path9: intensity
    FCB $03,$F8,0,0        ; path9: header (y=3, x=-8)
    FCB $FF,$03,$03          ; flag=-1, dy=3, dx=3
    FCB 2                ; End marker (path complete)

_PLAYER_DIE4_PATH10:    ; Path 10
    FCB 65              ; path10: intensity
    FCB $07,$04,0,0        ; path10: header (y=7, x=4)
    FCB $FF,$FE,$04          ; flag=-1, dy=-2, dx=4
    FCB 2                ; End marker (path complete)

_PLAYER_DIE4_PATH11:    ; Path 11
    FCB 65              ; path11: intensity
    FCB $05,$08,0,0        ; path11: header (y=5, x=8)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_DIE4_PATH12:    ; Path 12
    FCB 65              ; path12: intensity
    FCB $05,$06,0,0        ; path12: header (y=5, x=6)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_DIE4_PATH13:    ; Path 13
    FCB 65              ; path13: intensity
    FCB $FC,$08,0,0        ; path13: header (y=-4, x=8)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_DIE4_PATH14:    ; Path 14
    FCB 65              ; path14: intensity
    FCB $FC,$06,0,0        ; path14: header (y=-4, x=6)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_DIE4_PATH15:    ; Path 15
    FCB 65              ; path15: intensity
    FCB $FA,$09,0,0        ; path15: header (y=-6, x=9)
    FCB $FF,$02,$FC          ; flag=-1, dy=2, dx=-4
    FCB 2                ; End marker (path complete)

; Generated from player_idle.vec (Malban Draw_Sync_List format)
; Total paths: 9, points: 35
; X bounds: min=-6, max=6, width=12
; Center: (0, 0)

_PLAYER_IDLE_WIDTH EQU 12
_PLAYER_IDLE_HALF_WIDTH EQU 6
_PLAYER_IDLE_HEIGHT EQU 18
_PLAYER_IDLE_HALF_HEIGHT EQU 9
_PLAYER_IDLE_CENTER_X EQU 0
_PLAYER_IDLE_CENTER_Y EQU 0

_PLAYER_IDLE_VECTORS:  ; Main entry (header + 9 path(s))
    FDB 9               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLAYER_IDLE_PATH0        ; pointer to path 0
    FDB _PLAYER_IDLE_PATH1        ; pointer to path 1
    FDB _PLAYER_IDLE_PATH2        ; pointer to path 2
    FDB _PLAYER_IDLE_PATH3        ; pointer to path 3
    FDB _PLAYER_IDLE_PATH4        ; pointer to path 4
    FDB _PLAYER_IDLE_PATH5        ; pointer to path 5
    FDB _PLAYER_IDLE_PATH6        ; pointer to path 6
    FDB _PLAYER_IDLE_PATH7        ; pointer to path 7
    FDB _PLAYER_IDLE_PATH8        ; pointer to path 8

_PLAYER_IDLE_PATH0:    ; Path 0
    FCB 85              ; path0: intensity
    FCB $FF,$01,0,0        ; path0: header (y=-1, x=1)
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_IDLE_PATH1:    ; Path 1
    FCB 85              ; path1: intensity
    FCB $FF,$03,0,0        ; path1: header (y=-1, x=3)
    FCB $FF,$FF,$03          ; flag=-1, dy=-1, dx=3
    FCB $FF,$FE,$FD          ; flag=-1, dy=-2, dx=-3
    FCB 2                ; End marker (path complete)

_PLAYER_IDLE_PATH2:    ; Path 2
    FCB 85              ; path2: intensity
    FCB $FA,$03,0,0        ; path2: header (y=-6, x=3)
    FCB $FF,$FF,$03          ; flag=-1, dy=-1, dx=3
    FCB $FF,$FE,$FB          ; flag=-1, dy=-2, dx=-5
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_IDLE_PATH3:    ; Path 3
    FCB 85              ; path3: intensity
    FCB $F9,$FE,0,0        ; path3: header (y=-7, x=-2)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$01,$FB          ; flag=-1, dy=1, dx=-5
    FCB $FF,$04,$03          ; flag=-1, dy=4, dx=3
    FCB 2                ; End marker (path complete)

_PLAYER_IDLE_PATH4:    ; Path 4
    FCB 85              ; path4: intensity
    FCB $FD,$FD,0,0        ; path4: header (y=-3, x=-3)
    FCB $FF,$01,$02          ; flag=-1, dy=1, dx=2
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$03,$FE          ; flag=-1, dy=3, dx=-2
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB 2                ; End marker (path complete)

_PLAYER_IDLE_PATH5:    ; Path 5
    FCB 85              ; path5: intensity
    FCB $02,$01,0,0        ; path5: header (y=2, x=1)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB 2                ; End marker (path complete)

_PLAYER_IDLE_PATH6:    ; Path 6
    FCB 85              ; path6: intensity
    FCB $00,$03,0,0        ; path6: header (y=0, x=3)
    FCB $FF,$F7,$FE          ; flag=-1, dy=-9, dx=-2
    FCB $FF,$05,$FC          ; flag=-1, dy=5, dx=-4
    FCB $FF,$FC,$FD          ; flag=-1, dy=-4, dx=-3
    FCB $FF,$FF,$05          ; flag=-1, dy=-1, dx=5
    FCB $FF,$02,$FC          ; flag=-1, dy=2, dx=-4
    FCB 2                ; End marker (path complete)

_PLAYER_IDLE_PATH7:    ; Path 7
    FCB 85              ; path7: intensity
    FCB $06,$FE,0,0        ; path7: header (y=6, x=-2)
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_IDLE_PATH8:    ; Path 8
    FCB 85              ; path8: intensity
    FCB $07,$01,0,0        ; path8: header (y=7, x=1)
    FCB $FF,$FC,$FC          ; flag=-1, dy=-4, dx=-4
    FCB $FF,$FC,$05          ; flag=-1, dy=-4, dx=5
    FCB $FF,$05,$03          ; flag=-1, dy=5, dx=3
    FCB $FF,$03,$FC          ; flag=-1, dy=3, dx=-4
    FCB 2                ; End marker (path complete)

; Generated from titchi_ball.vec (Malban Draw_Sync_List format)
; Total paths: 7, points: 26
; X bounds: min=-6, max=6, width=12
; Center: (0, 0)

_TITCHI_BALL_WIDTH EQU 12
_TITCHI_BALL_HALF_WIDTH EQU 6
_TITCHI_BALL_HEIGHT EQU 8
_TITCHI_BALL_HALF_HEIGHT EQU 4
_TITCHI_BALL_CENTER_X EQU 0
_TITCHI_BALL_CENTER_Y EQU 0

_TITCHI_BALL_VECTORS:  ; Main entry (header + 7 path(s))
    FDB 7               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _TITCHI_BALL_PATH0        ; pointer to path 0
    FDB _TITCHI_BALL_PATH1        ; pointer to path 1
    FDB _TITCHI_BALL_PATH2        ; pointer to path 2
    FDB _TITCHI_BALL_PATH3        ; pointer to path 3
    FDB _TITCHI_BALL_PATH4        ; pointer to path 4
    FDB _TITCHI_BALL_PATH5        ; pointer to path 5
    FDB _TITCHI_BALL_PATH6        ; pointer to path 6

_TITCHI_BALL_PATH0:    ; Path 0
    FCB 85              ; path0: intensity
    FCB $FF,$00,0,0        ; path0: header (y=-1, x=0)
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_TITCHI_BALL_PATH1:    ; Path 1
    FCB 100              ; path1: intensity
    FCB $02,$FE,0,0        ; path1: header (y=2, x=-2)
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB 2                ; End marker (path complete)

_TITCHI_BALL_PATH2:    ; Path 2
    FCB 85              ; path2: intensity
    FCB $FD,$FD,0,0        ; path2: header (y=-3, x=-3)
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$01,$03          ; flag=-1, dy=1, dx=3
    FCB $FF,$FF,$03          ; flag=-1, dy=-1, dx=3
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FF,$FD          ; flag=-1, dy=-1, dx=-3
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB 2                ; End marker (path complete)

_TITCHI_BALL_PATH3:    ; Path 3
    FCB 70              ; path3: intensity
    FCB $FF,$FA,0,0        ; path3: header (y=-1, x=-6)
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB 2                ; End marker (path complete)

_TITCHI_BALL_PATH4:    ; Path 4
    FCB 70              ; path4: intensity
    FCB $00,$FA,0,0        ; path4: header (y=0, x=-6)
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB 2                ; End marker (path complete)

_TITCHI_BALL_PATH5:    ; Path 5
    FCB 70              ; path5: intensity
    FCB $01,$FA,0,0        ; path5: header (y=1, x=-6)
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB 2                ; End marker (path complete)

_TITCHI_BALL_PATH6:    ; Path 6
    FCB 60              ; path6: intensity
    FCB $00,$02,0,0        ; path6: header (y=0, x=2)
    FCB $FF,$FF,$01          ; flag=-1, dy=-1, dx=1
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

; Generated from Boss_Intro.vmus (internal name: Imported MIDI)
; Tempo: 120 BPM, Total events: 12 (PSG Direct format)
; Format: FCB count, FCB reg, val, ... (per frame), FCB 0 (end)

_BOSS_INTRO_MUSIC:
    ; Frame-based PSG register writes
    FCB     0              ; Delay 0 frames (maintain previous state)
    FCB     10              ; Frame 0 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $D4             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $EE             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     17              ; Delay 17 frames (maintain previous state)
    FCB     4              ; Frame 17 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     10              ; Frame 27 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $BD             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $EE             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     17              ; Delay 17 frames (maintain previous state)
    FCB     4              ; Frame 44 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     10              ; Frame 54 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $D4             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $EE             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     4              ; Frame 63 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     10              ; Frame 71 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $9F             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $D4             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     254             ; Delay 254 frames (filler chunk)
    FCB     10              ; 10 register writes (repeat state)
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $9F             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $D4             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     75              ; Delay 75 frames before loop
    FCB     $FF             ; Loop command ($FF never valid as count)
    FDB     _BOSS_INTRO_MUSIC       ; Jump to start (absolute address)


; Generated from intro.vmus (internal name: Imported MIDI)
; Tempo: 120 BPM, Total events: 4 (PSG Direct format)
; Format: FCB count, FCB reg, val, ... (per frame), FCB 0 (end)

_INTRO_MUSIC:
    ; Frame-based PSG register writes
    FCB     0              ; Delay 0 frames (maintain previous state)
    FCB     6              ; Frame 0 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 4 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 8 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 12 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     6              ; Frame 17 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 21 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     6              ; Frame 27 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     254             ; Delay 254 frames (filler chunk)
    FCB     6              ; 6 register writes (repeat state)
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     119              ; Delay 119 frames before loop
    FCB     $FF             ; Loop command ($FF never valid as count)
    FDB     _INTRO_MUSIC       ; Jump to start (absolute address)


; Generated from platform2.vec (Malban Draw_Sync_List format)
; Total paths: 3, points: 13
; X bounds: min=-58, max=57, width=115
; Center: (0, 0)

_PLATFORM2_WIDTH EQU 115
_PLATFORM2_HALF_WIDTH EQU 57
_PLATFORM2_HEIGHT EQU 9
_PLATFORM2_HALF_HEIGHT EQU 4
_PLATFORM2_CENTER_X EQU 0
_PLATFORM2_CENTER_Y EQU 0

_PLATFORM2_VECTORS:  ; Main entry (header + 3 path(s))
    FDB 3               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLATFORM2_PATH0        ; pointer to path 0
    FDB _PLATFORM2_PATH1        ; pointer to path 1
    FDB _PLATFORM2_PATH2        ; pointer to path 2

_PLATFORM2_PATH0:    ; Path 0
    FCB 85              ; path0: intensity
    FCB $00,$39,0,0        ; path0: header (y=0, x=57)
    FCB 2                ; End marker (path complete)

_PLATFORM2_PATH1:    ; Path 1
    FCB 85              ; path1: intensity
    FCB $FB,$39,0,0        ; path1: header (y=-5, x=57)
    FCB $FF,$09,$EB          ; flag=-1, dy=9, dx=-21
    FCB $FF,$F7,$EE          ; flag=-1, dy=-9, dx=-18
    FCB $FF,$09,$EE          ; flag=-1, dy=9, dx=-18
    FCB $FF,$F7,$EC          ; flag=-1, dy=-9, dx=-20
    FCB $FF,$09,$EE          ; flag=-1, dy=9, dx=-18
    FCB $FF,$F7,$EC          ; flag=-1, dy=-9, dx=-20
    FCB 2                ; End marker (path complete)

_PLATFORM2_PATH2:    ; Path 2
    FCB 85              ; path2: intensity
    FCB $04,$C6,0,0        ; path2: header (y=4, x=-58)
    FCB $FF,$00,$73          ; flag=-1, dy=0, dx=115
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB $FF,$00,$8D          ; flag=-1, dy=0, dx=-115
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB 2                ; End marker (path complete)

_SHOT_NORMAL_SFX:
    ; SFX: shot_normal (laser)
    ; Duration: 150ms (7fr), Freq: 199Hz, Channel: 0
    FCB $AA         ; Frame 0 - flags (vol=10, noisevol=0, tone=Y, noise=N)
    FCB $00, $DE  ; Tone period = 222 (big-endian)
    FCB $AA         ; Frame 1 - flags (vol=10, noisevol=0, tone=Y, noise=N)
    FCB $00, $FD  ; Tone period = 253 (big-endian)
    FCB $AA         ; Frame 2 - flags (vol=10, noisevol=0, tone=Y, noise=N)
    FCB $01, $27  ; Tone period = 295 (big-endian)
    FCB $AA         ; Frame 3 - flags (vol=10, noisevol=0, tone=Y, noise=N)
    FCB $01, $63  ; Tone period = 355 (big-endian)
    FCB $AA         ; Frame 4 - flags (vol=10, noisevol=0, tone=Y, noise=N)
    FCB $01, $BB  ; Tone period = 443 (big-endian)
    FCB $AC         ; Frame 5 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $02, $4F  ; Tone period = 591 (big-endian)
    FCB $A6         ; Frame 6 - flags (vol=6, noisevol=0, tone=Y, noise=N)
    FCB $03, $76  ; Tone period = 886 (big-endian)
    FCB $D0, $20    ; End of effect marker



; ================================================
