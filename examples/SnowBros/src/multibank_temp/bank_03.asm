    ORG $4000  ; Fixed bank window (runtime helpers + interrupt vectors)


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
    ; Runtime helpers (accessible from all banks)

;***************************************************************************
; ASSET LOOKUP TABLES (for banked asset access)
; Total: 15 vectors, 5 music, 1 sfx, 1 levels, 2 animations, 0 instruments, 2 enemies
;***************************************************************************

; Vector Asset Index Mapping:
;   0 = init_screen (Bank #1)
;   1 = platform1 (Bank #2)
;   2 = platform2 (Bank #1)
;   3 = platform3 (Bank #2)
;   4 = platform4 (Bank #1)
;   5 = player_die1 (Bank #1)
;   6 = player_die2 (Bank #1)
;   7 = player_die3 (Bank #1)
;   8 = player_die4 (Bank #1)
;   9 = player_idle (Bank #1)
;   10 = player_jump (Bank #1)
;   11 = titchi_ball (Bank #1)
;   12 = titchi_idle (Bank #1)
;   13 = titchi_snow1 (Bank #1)
;   14 = titchi_snow2 (Bank #1)

VECTOR_BANK_TABLE:
    FCB 1              ; Bank ID
    FCB 2              ; Bank ID
    FCB 1              ; Bank ID
    FCB 2              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID

VECTOR_ADDR_TABLE:
    FDB _INIT_SCREEN_VECTORS    ; init_screen
    FDB _PLATFORM1_VECTORS    ; platform1
    FDB _PLATFORM2_VECTORS    ; platform2
    FDB _PLATFORM3_VECTORS    ; platform3
    FDB _PLATFORM4_VECTORS    ; platform4
    FDB _PLAYER_DIE1_VECTORS    ; player_die1
    FDB _PLAYER_DIE2_VECTORS    ; player_die2
    FDB _PLAYER_DIE3_VECTORS    ; player_die3
    FDB _PLAYER_DIE4_VECTORS    ; player_die4
    FDB _PLAYER_IDLE_VECTORS    ; player_idle
    FDB _PLAYER_JUMP_VECTORS    ; player_jump
    FDB _TITCHI_BALL_VECTORS    ; titchi_ball
    FDB _TITCHI_IDLE_VECTORS    ; titchi_idle
    FDB _TITCHI_SNOW1_VECTORS    ; titchi_snow1
    FDB _TITCHI_SNOW2_VECTORS    ; titchi_snow2

; Music Asset Index Mapping:
;   0 = Boss_Intro (Bank #1)
;   1 = Game_Over (Bank #1)
;   2 = Henshoku (Bank #2)
;   3 = Yukidama-Ondo (Bank #1)
;   4 = intro (Bank #1)

MUSIC_BANK_TABLE:
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 2              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID

MUSIC_ADDR_TABLE:
    FDB _BOSS_INTRO_MUSIC    ; Boss_Intro
    FDB _GAME_OVER_MUSIC    ; Game_Over
    FDB _HENSHOKU_MUSIC    ; Henshoku
    FDB _YUKIDAMA_ONDO_MUSIC    ; Yukidama-Ondo
    FDB _INTRO_MUSIC    ; intro

; SFX Asset Index Mapping:
;   0 = shot_normal (Bank #1)

SFX_BANK_TABLE:
    FCB 1              ; Bank ID

SFX_ADDR_TABLE:
    FDB _SHOT_NORMAL_SFX    ; shot_normal

; Level Asset Index Mapping:
;   0 = world_1_1 (Bank #1)

LEVEL_BANK_TABLE:
    FCB 1              ; Bank ID

LEVEL_ADDR_TABLE:
    FDB _WORLD_1_1_LEVEL    ; world_1_1

; Animation Asset Index Mapping:
;   0 = player_walk (Bank #3)
;   1 = titchi_walk (Bank #3)

ANIM_BANK_TABLE:
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID

ANIM_ADDR_TABLE:
    FDB _ANIM_PLAYER_WALK    ; player_walk
    FDB _ANIM_TITCHI_WALK    ; titchi_walk

; Enemy Asset Index Mapping (all in helpers bank for direct access):
;   0 = enemy1 (Bank #3)
;   1 = titchi (Bank #3)

ENEMY_BANK_TABLE:
    FCB 3              ; Bank ID (helpers bank — always mapped)
    FCB 3              ; Bank ID (helpers bank — always mapped)

ENEMY_ADDR_TABLE:
    FDB _ENEMY1_ENEMY    ; enemy1
    FDB _TITCHI_ENEMY    ; titchi

;***************************************************************************
; ENEMY TYPE DEFINITIONS (helpers bank — always accessible)
; Action table uses FCB sprite_idx for DRAW_VECTOR_BANKED compatibility
;***************************************************************************
; ---- Enemy type: ENEMY1 (multibank indexed) ----
_ENEMY1_ACTION_IDLE EQU 0
_ENEMY1_ACTION_WALK EQU 1

_ENEMY1_ENEMY:
    FCB 3          ; [0] hp
    FCB 30          ; [1] speed
    FDB 180          ; [2-3] action_duration
    FCB 2          ; [4] action_count
    FDB 0           ; [5-6] no state machine

_ENEMY1_ENEMY_ACTIONS:
    FCB $09   ; action 0 (idle) sprite_idx ($FF=none)
    FCB 0                   ; sprite_type: 0=vec, 1=vanim
    FCB 0                   ; loop=false
    FCB 0                    ; pad (entry byte [3])
    FDB 0                    ; [4-5] no anim state (vec action)
    FCB $00   ; action 1 (walk) sprite_idx ($FF=none)
    FCB 1                   ; sprite_type: 0=vec, 1=vanim
    FCB 1                   ; loop=true
    FCB 0                    ; pad (entry byte [3])
    FDB ANIM_ENEMY_ENEMY1_WALK_STATE    ; [4-5] anim state RAM ptr (frame_idx, ticks_left)

; ---- Enemy type: TITCHI (multibank indexed) ----
_TITCHI_ACTION_IDLE EQU 0
_TITCHI_ACTION_WALK EQU 1
_TITCHI_ACTION_SNOW1 EQU 2
_TITCHI_ACTION_SNOW2 EQU 3
_TITCHI_ACTION_BALL EQU 4

_TITCHI_ENEMY:
    FCB 3          ; [0] hp
    FCB 30          ; [1] speed
    FDB 180          ; [2-3] action_duration
    FCB 5          ; [4] action_count
    FDB _TITCHI_SM      ; [5-6] state machine ptr

_TITCHI_ENEMY_ACTIONS:
    FCB $0C   ; action 0 (idle) sprite_idx ($FF=none)
    FCB 0                   ; sprite_type: 0=vec, 1=vanim
    FCB 1                   ; loop=true
    FCB 0                    ; pad (entry byte [3])
    FDB 0                    ; [4-5] no anim state (vec action)
    FCB $01   ; action 1 (walk) sprite_idx ($FF=none)
    FCB 1                   ; sprite_type: 0=vec, 1=vanim
    FCB 1                   ; loop=true
    FCB 0                    ; pad (entry byte [3])
    FDB ANIM_ENEMY_TITCHI_WALK_STATE    ; [4-5] anim state RAM ptr (frame_idx, ticks_left)
    FCB $0D   ; action 2 (snow1) sprite_idx ($FF=none)
    FCB 0                   ; sprite_type: 0=vec, 1=vanim
    FCB 1                   ; loop=true
    FCB 0                    ; pad (entry byte [3])
    FDB 0                    ; [4-5] no anim state (vec action)
    FCB $0E   ; action 3 (snow2) sprite_idx ($FF=none)
    FCB 0                   ; sprite_type: 0=vec, 1=vanim
    FCB 1                   ; loop=true
    FCB 0                    ; pad (entry byte [3])
    FDB 0                    ; [4-5] no anim state (vec action)
    FCB $0B   ; action 4 (ball) sprite_idx ($FF=none)
    FCB 0                   ; sprite_type: 0=vec, 1=vanim
    FCB 1                   ; loop=true
    FCB 0                    ; pad (entry byte [3])
    FDB 0                    ; [4-5] no anim state (vec action)

; ---- State machine: TITCHI ----
_TITCHI_SM:
    FCB 4          ; state_count
    FCB 0          ; initial_state_idx
_TITCHI_SM_STATES:
    ; state 0 (normal) — fixed 13-byte record
    FCB $01   ; [0] action_idx ($FF=keep)
    FDB 0       ; [1-2] decay_frames
    FCB $FF   ; [3] decay_to ($FF=none)
    FCB 1       ; [4] on_event_count
    FCB $1C   ; [5] event hash 'onSnowHit'
    FCB 1       ; [6] -> state snow1
    FCB $FF   ; [7] unused event slot hash
    FCB $FF   ; [8] unused event slot to
    FCB $FF   ; [9] unused event slot hash
    FCB $FF   ; [10] unused event slot to
    FCB $FF   ; [11] unused event slot hash
    FCB $FF   ; [12] unused event slot to
    ; state 1 (snow1) — fixed 13-byte record
    FCB $02   ; [0] action_idx ($FF=keep)
    FDB 120       ; [1-2] decay_frames
    FCB $00   ; [3] decay_to ($FF=none)
    FCB 1       ; [4] on_event_count
    FCB $1C   ; [5] event hash 'onSnowHit'
    FCB 2       ; [6] -> state snow2
    FCB $FF   ; [7] unused event slot hash
    FCB $FF   ; [8] unused event slot to
    FCB $FF   ; [9] unused event slot hash
    FCB $FF   ; [10] unused event slot to
    FCB $FF   ; [11] unused event slot hash
    FCB $FF   ; [12] unused event slot to
    ; state 2 (snow2) — fixed 13-byte record
    FCB $03   ; [0] action_idx ($FF=keep)
    FDB 180       ; [1-2] decay_frames
    FCB $01   ; [3] decay_to ($FF=none)
    FCB 1       ; [4] on_event_count
    FCB $1C   ; [5] event hash 'onSnowHit'
    FCB 3       ; [6] -> state ball
    FCB $FF   ; [7] unused event slot hash
    FCB $FF   ; [8] unused event slot to
    FCB $FF   ; [9] unused event slot hash
    FCB $FF   ; [10] unused event slot to
    FCB $FF   ; [11] unused event slot hash
    FCB $FF   ; [12] unused event slot to
    ; state 3 (ball) — fixed 13-byte record
    FCB $04   ; [0] action_idx ($FF=keep)
    FDB 300       ; [1-2] decay_frames
    FCB $02   ; [3] decay_to ($FF=none)
    FCB 1       ; [4] on_event_count
    FCB $9E   ; [5] event hash 'onKick'
    FCB 0       ; [6] -> state normal
    FCB $FF   ; [7] unused event slot hash
    FCB $FF   ; [8] unused event slot to
    FCB $FF   ; [9] unused event slot hash
    FCB $FF   ; [10] unused event slot to
    FCB $FF   ; [11] unused event slot hash
    FCB $FF   ; [12] unused event slot to


; Legacy unified tables (all assets)
ASSET_BANK_TABLE:
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID

ASSET_ADDR_TABLE:
    FDB _YUKIDAMA_ONDO_MUSIC    ; Yukidama-Ondo
    FDB _WORLD_1_1_LEVEL    ; world_1_1
    FDB _INIT_SCREEN_VECTORS    ; init_screen
    FDB _GAME_OVER_MUSIC    ; Game_Over
    FDB _TITCHI_SNOW1_VECTORS    ; titchi_snow1
    FDB _PLATFORM4_VECTORS    ; platform4
    FDB _PLAYER_JUMP_VECTORS    ; player_jump
    FDB _PLAYER_DIE1_VECTORS    ; player_die1
    FDB _TITCHI_SNOW2_VECTORS    ; titchi_snow2
    FDB _PLAYER_DIE2_VECTORS    ; player_die2
    FDB _TITCHI_IDLE_VECTORS    ; titchi_idle
    FDB _PLAYER_DIE3_VECTORS    ; player_die3
    FDB _PLAYER_DIE4_VECTORS    ; player_die4
    FDB _PLAYER_IDLE_VECTORS    ; player_idle
    FDB _TITCHI_BALL_VECTORS    ; titchi_ball
    FDB _BOSS_INTRO_MUSIC    ; Boss_Intro
    FDB _INTRO_MUSIC    ; intro
    FDB _PLATFORM2_VECTORS    ; platform2
    FDB _SHOT_NORMAL_SFX    ; shot_normal
    FDB _HENSHOKU_MUSIC    ; Henshoku
    FDB _PLATFORM1_VECTORS    ; platform1
    FDB _PLATFORM3_VECTORS    ; platform3

;***************************************************************************
; DRAW_VECTOR_BANKED - Draw vector asset with automatic bank switching
; Input: X = asset index (0-based), DRAW_VEC_X/Y set for position
;        MIRROR_X, MIRROR_Y, DRAW_VEC_INTENSITY must be set by caller
; Uses: A, B, D, X, Y, U
; Preserves: CURRENT_ROM_BANK (restored after drawing)
; Note: DSWM handles beam positioning internally via DRAW_VEC_X/Y
;***************************************************************************
DRAW_VECTOR_BANKED:
    ; Save index to U register (avoid stack order issues)
    TFR X,U              ; U = vector index
    ; Save context: original bank on stack
    LDA CURRENT_ROM_BANK
    PSHS A               ; Stack: [A]

    ; Get asset's bank from lookup table
    TFR X,D              ; D = asset index
    LDX #VECTOR_BANK_TABLE
    LDA D,X              ; A = bank ID for this asset
    STA CURRENT_ROM_BANK ; Update RAM tracker
    STA $DF00            ; Switch bank hardware register

    ; Get asset's address from lookup table (2 bytes per entry)
    TFR U,D              ; D = asset index (saved in U at entry)
    ASLB                 ; *2 for FDB entries
    ROLA
    LDX #VECTOR_ADDR_TABLE
    LEAX D,X             ; X points to address entry
    LDX ,X               ; X = _VEC_VECTORS header address in banked ROM

    ; Set DP=$D0 for DSWM / VIA access (caller set MIRROR_X/Y/INTENSITY)
    JSR $F1AA            ; DP_to_D0

    ; Loop over all paths (header: FDB path_count, then FDB table)
    LDD ,X               ; D = path_count (16-bit FDB at header start)
    CMPD #0
    LBEQ DVB_DONE        ; No paths
    LEAY 2,X             ; Y = pointer to first FDB entry (after 2-byte header)
DVB_PATH_LOOP:
    PSHS D               ; Save remaining path count (2 bytes)
    LDX ,Y               ; X = path data address (FDB entry)
    JSR Draw_Sync_List_At_With_Mirrors
    LEAY 2,Y             ; Advance to next FDB entry
    PULS D               ; Restore count
    SUBD #1
    BNE DVB_PATH_LOOP
DVB_DONE:

    JSR $F1AF            ; DP_to_C8

    ; Restore original bank from stack (only A was pushed with PSHS A)
    PULS A               ; A = original bank
    STA CURRENT_ROM_BANK
    STA $DF00            ; Restore bank

    RTS

;***************************************************************************
; PLAY_MUSIC_BANKED - Play music asset with automatic bank switching
; Input: X = music asset index (0-based)
; Uses: A, B, X
; Note: Music data is COPIED to RAM, so bank switch is temporary
;***************************************************************************
PLAY_MUSIC_BANKED:
    ; Save index to U register (avoid stack order issues)
    TFR X,U              ; U = music index
    ; Save context: original bank on stack
    LDA CURRENT_ROM_BANK
    PSHS A               ; Stack: [A]

    ; CRITICAL: Read BOTH lookup tables BEFORE switching banks!
    ; (Tables are in Bank 31, which is always visible at $4000+)

    ; Get music's bank from lookup table (BEFORE switch)
    TFR U,D              ; D = music index (from U)
    LDX #MUSIC_BANK_TABLE
    LDA D,X              ; A = bank ID for this music
    STA >PSG_MUSIC_BANK  ; Save bank for AUDIO_UPDATE (multibank)
    PSHS A               ; Save bank ID on stack temporarily

    ; Get music's address from lookup table (BEFORE switch)
    TFR U,D              ; Reload music index from U
    ASLB                 ; *2 for FDB entries
    ROLA
    LDX #MUSIC_ADDR_TABLE
    LEAX D,X             ; X points to address entry
    LDX ,X               ; X = actual music address in banked ROM
    PSHS X               ; Save music address on stack

    ; NOW switch to music's bank
    LDA 2,S              ; Get bank ID from stack (behind X)
    STA CURRENT_ROM_BANK ; Update RAM tracker
    STA $DF00            ; Switch bank hardware register

    ; Restore music address and call runtime
    PULS X               ; X = music address (now valid in switched bank)
    LEAS 1,S             ; Discard bank ID from stack

    ; Call PLAY_MUSIC_RUNTIME with X pointing to music data
    JSR PLAY_MUSIC_RUNTIME

    ; Restore original bank from stack
    PULS A               ; A = original bank
    STA CURRENT_ROM_BANK
    STA $DF00            ; Restore bank

    RTS

;***************************************************************************
; PLAY_SFX_BANKED - Play SFX asset with automatic bank switching
; Input: X = SFX asset index (0-based)
; Uses: A, B, X
;***************************************************************************
PLAY_SFX_BANKED:
    ; Save index to U register (avoid stack order issues)
    TFR X,U              ; U = SFX index
    ; Save context: original bank on stack
    LDA CURRENT_ROM_BANK
    PSHS A               ; Stack: [A]

    ; Get SFX's bank from lookup table
    TFR U,D              ; D = SFX index (from U)
    LDX #SFX_BANK_TABLE
    LDA D,X              ; A = bank ID for this SFX
    STA CURRENT_ROM_BANK ; Update RAM tracker
    STA >SFX_BANK        ; Save SFX bank for AUDIO_UPDATE
    STA $DF00            ; Switch bank hardware register

    ; Get SFX's address from lookup table (2 bytes per entry)
    TFR U,D              ; Reload SFX index from U
    ASLB                 ; *2 for FDB entries
    ROLA
    LDX #SFX_ADDR_TABLE
    LEAX D,X             ; X points to address entry
    LDX ,X               ; X = actual SFX address in banked ROM

    ; Call PLAY_SFX_RUNTIME with X pointing to SFX data
    JSR PLAY_SFX_RUNTIME

    ; Restore original bank from stack
    PULS A               ; A = original bank
    STA CURRENT_ROM_BANK
    STA $DF00            ; Restore bank

    RTS

;***************************************************************************
; LOAD_LEVEL_BANKED - Load level asset with automatic bank switching
; Input: X = Level asset index (0-based)
; Output: LEVEL_PTR, LEVEL_WIDTH, LEVEL_HEIGHT set
; Uses: A, B, X, Y
;***************************************************************************
LOAD_LEVEL_BANKED:
    ; Save level index to U register, save context to stack
    TFR X,U              ; U = level index
    LDA CURRENT_ROM_BANK
    PSHS A               ; Stack: [A] - Only save original bank

    ; Get level's bank from lookup table
    TFR U,D              ; D = level index (from U)
    LDX #LEVEL_BANK_TABLE
    LDA D,X              ; A = bank ID for this level
    STA CURRENT_ROM_BANK ; Update RAM tracker
    STA >LEVEL_BANK      ; Save level bank for SHOW/UPDATE_LEVEL_RUNTIME
    STA $DF00            ; Switch bank hardware register

    ; Get level's address from lookup table (2 bytes per entry)
    TFR U,D              ; Reload level index from U
    ASLB                 ; *2 for FDB entries
    ROLA
    LDX #LEVEL_ADDR_TABLE
    LEAX D,X             ; X points to address entry
    LDX ,X               ; X = actual level address in banked ROM

    ; Full level init: call LOAD_LEVEL_RUNTIME with X = level address
    ; (level bank is active, LOAD_LEVEL_RUNTIME code is in fixed helpers bank)
    JSR LOAD_LEVEL_RUNTIME

    ; Restore original bank from stack
    PULS A               ; A = original bank
    STA CURRENT_ROM_BANK
    STA $DF00            ; Restore bank

    LDD #1               ; Return success
    STD RESULT

    RTS

;***************************************************************************
; SPAWN_ENEMIES_BANKED - Spawn enemies using level data with bank switching
; Reads LEVEL_BANK, LEVEL_ENEMY_COUNT, LEVEL_ENEMY_INSTANCES_PTR from RAM
; (all three set by LOAD_LEVEL_BANKED/LOAD_LEVEL_RUNTIME)
; Uses: A, B, X, Y
;***************************************************************************
SPAWN_ENEMIES_BANKED:
    LDB >LEVEL_ENEMY_COUNT
    BEQ SEB_DONE             ; no enemies in this level
    LDA CURRENT_ROM_BANK
    PSHS A                   ; save current bank
    LDA >LEVEL_BANK
    STA CURRENT_ROM_BANK
    STA $DF00                ; switch to level bank
    LDX >LEVEL_ENEMY_INSTANCES_PTR
    JSR SPAWN_ENEMIES_RUNTIME ; B=count, X=instances ptr
    PULS A
    STA CURRENT_ROM_BANK
    STA $DF00                ; restore bank
SEB_DONE:
    RTS

;***************************************************************************
; DRAW_ANIM_BANKED - Draw vanim sprite for enemies
; Animations are always in the helpers bank (fixed $4000+); no bank switch.
; Input: X = anim index (0-based into ANIM_ADDR_TABLE)
;        U = ptr to 2-byte RAM state (byte0=frame_idx, byte1=ticks_left)
;        DRAW_VEC_X / DRAW_VEC_Y set for enemy screen position
; Clobbers: A, B, X  (DRAW_ANIM_RUNTIME preserves D,X,Y,U via PSHS/PULS)
;***************************************************************************
DRAW_ANIM_BANKED:
    ; Set up animation draw parameters (defaults: normal size, no mirror, vanim timing)
    CLR >DRAW_ANIM_MIRROR_X
    CLR >MIRROR_X
    CLR >MIRROR_Y
    LDA #$7F
    STA >DRAW_ANIM_SCALE
    CLR >DRAW_ANIM_SPEED_MUL

    ; Look up anim header from ANIM_ADDR_TABLE[index * 2]
    TFR X,D              ; D = anim index
    ASLB                 ; *2 for FDB entries
    ROLA
    LDX #ANIM_ADDR_TABLE
    LEAX D,X             ; X points to FDB entry
    LDX ,X               ; X = _ANIM_XXX header ptr
    PSHS X               ; SAVE header ptr — Reset0Ref/Moveto_d may clobber X

    ; Position beam at enemy screen coordinates (DRAW_VEC_X/Y set by caller)
    JSR $F1AA            ; DP_to_D0 (required before BIOS positioning calls)
    JSR Reset0Ref        ; Reset integrators to centre (0, 0)
    LDA >DRAW_VEC_Y      ; A = Y position
    LDB >DRAW_VEC_X      ; B = X position
    JSR Moveto_d         ; Move beam to (Y, X)
    JSR $F1AF            ; DP_to_C8 (restore DP before DRAW_ANIM_RUNTIME)
    PULS X               ; RESTORE header ptr (Reset0Ref/Moveto_d may have clobbered X)

    ; Call animation runtime: X=header, U=state ptr
    JSR DRAW_ANIM_RUNTIME
    RTS

;***************************************************************************
; ANIMATION DATA (helpers bank — always accessible for DRAW_ANIM_RUNTIME)
;***************************************************************************

; .vanim animation data: player_walk (4 frames, loop=true, base_refs=0)

_ANIM_PLAYER_WALK:
    FCB 4               ; frame_count
    FCB 1               ; loop flag (1=loop, 0=freeze)
    FCB 0               ; base_ref_count
    FCB 4               ; frame_table_offset
    FDB _ANIM_PLAYER_WALK_F0       ; frame 0 pointer
    FDB _ANIM_PLAYER_WALK_F1       ; frame 1 pointer
    FDB _ANIM_PLAYER_WALK_F2       ; frame 2 pointer
    FDB _ANIM_PLAYER_WALK_F3       ; frame 3 pointer

_ANIM_PLAYER_WALK_F0:
    FCB 8               ; duration_ticks
    FCB 1               ; vec_ref_count
    FDB _PLAYER_WALK1_VECTORS      ; vec_ref: player_walk1
    FCB 0               ; inline_path_count

_ANIM_PLAYER_WALK_F1:
    FCB 8               ; duration_ticks
    FCB 1               ; vec_ref_count
    FDB _PLAYER_WALK2_VECTORS      ; vec_ref: player_walk2
    FCB 0               ; inline_path_count

_ANIM_PLAYER_WALK_F2:
    FCB 8               ; duration_ticks
    FCB 1               ; vec_ref_count
    FDB _PLAYER_WALK3_VECTORS      ; vec_ref: player_walk3
    FCB 0               ; inline_path_count

_ANIM_PLAYER_WALK_F3:
    FCB 8               ; duration_ticks
    FCB 1               ; vec_ref_count
    FDB _PLAYER_WALK4_VECTORS      ; vec_ref: player_walk4
    FCB 0               ; inline_path_count


; .vanim animation data: titchi_walk (3 frames, loop=true, base_refs=0)

_ANIM_TITCHI_WALK:
    FCB 3               ; frame_count
    FCB 1               ; loop flag (1=loop, 0=freeze)
    FCB 0               ; base_ref_count
    FCB 4               ; frame_table_offset
    FDB _ANIM_TITCHI_WALK_F0       ; frame 0 pointer
    FDB _ANIM_TITCHI_WALK_F1       ; frame 1 pointer
    FDB _ANIM_TITCHI_WALK_F2       ; frame 2 pointer

_ANIM_TITCHI_WALK_F0:
    FCB 8               ; duration_ticks
    FCB 1               ; vec_ref_count
    FDB _TITCHI_WALK1_VECTORS      ; vec_ref: titchi_walk1
    FCB 0               ; inline_path_count

_ANIM_TITCHI_WALK_F1:
    FCB 8               ; duration_ticks
    FCB 1               ; vec_ref_count
    FDB _TITCHI_WALK2_VECTORS      ; vec_ref: titchi_walk2
    FCB 0               ; inline_path_count

_ANIM_TITCHI_WALK_F2:
    FCB 8               ; duration_ticks
    FCB 1               ; vec_ref_count
    FDB _TITCHI_WALK3_VECTORS      ; vec_ref: titchi_walk3
    FCB 0               ; inline_path_count


; Vec files referenced by animations (helpers bank for cross-bank safety)

; Generated from player_walk1.vec (Malban Draw_Sync_List format)
; Total paths: 8, points: 25
; X bounds: min=-5, max=5, width=10
; Center: (0, 0)

_PLAYER_WALK1_WIDTH EQU 10
_PLAYER_WALK1_HALF_WIDTH EQU 5
_PLAYER_WALK1_HEIGHT EQU 17
_PLAYER_WALK1_HALF_HEIGHT EQU 8
_PLAYER_WALK1_CENTER_X EQU 0
_PLAYER_WALK1_CENTER_Y EQU 0

_PLAYER_WALK1_VECTORS:  ; Main entry (header + 8 path(s))
    FDB 8               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLAYER_WALK1_PATH0        ; pointer to path 0
    FDB _PLAYER_WALK1_PATH1        ; pointer to path 1
    FDB _PLAYER_WALK1_PATH2        ; pointer to path 2
    FDB _PLAYER_WALK1_PATH3        ; pointer to path 3
    FDB _PLAYER_WALK1_PATH4        ; pointer to path 4
    FDB _PLAYER_WALK1_PATH5        ; pointer to path 5
    FDB _PLAYER_WALK1_PATH6        ; pointer to path 6
    FDB _PLAYER_WALK1_PATH7        ; pointer to path 7

_PLAYER_WALK1_PATH0:    ; Path 0
    FCB 65              ; path0: intensity
    FCB $02,$01,0,0        ; path0: header (y=2, x=1)
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK1_PATH1:    ; Path 1
    FCB 65              ; path1: intensity
    FCB $00,$03,0,0        ; path1: header (y=0, x=3)
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK1_PATH2:    ; Path 2
    FCB 65              ; path2: intensity
    FCB $FD,$02,0,0        ; path2: header (y=-3, x=2)
    FCB $FF,$FA,$FF          ; flag=-1, dy=-6, dx=-1
    FCB $FF,$05,$FB          ; flag=-1, dy=5, dx=-5
    FCB 2                ; End marker (path complete)

_PLAYER_WALK1_PATH3:    ; Path 3
    FCB 65              ; path3: intensity
    FCB $FB,$FD,0,0        ; path3: header (y=-5, x=-3)
    FCB $FF,$FC,$FE          ; flag=-1, dy=-4, dx=-2
    FCB $FF,$02,$04          ; flag=-1, dy=2, dx=4
    FCB 2                ; End marker (path complete)

_PLAYER_WALK1_PATH4:    ; Path 4
    FCB 65              ; path4: intensity
    FCB $F7,$01,0,0        ; path4: header (y=-9, x=1)
    FCB $FF,$01,$04          ; flag=-1, dy=1, dx=4
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK1_PATH5:    ; Path 5
    FCB 65              ; path5: intensity
    FCB $FD,$FF,0,0        ; path5: header (y=-3, x=-1)
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$05,$02          ; flag=-1, dy=5, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK1_PATH6:    ; Path 6
    FCB 65              ; path6: intensity
    FCB $06,$FE,0,0        ; path6: header (y=6, x=-2)
    FCB $FF,$FC,$FF          ; flag=-1, dy=-4, dx=-1
    FCB $FF,$FE,$04          ; flag=-1, dy=-2, dx=4
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$05,$FD          ; flag=-1, dy=5, dx=-3
    FCB 2                ; End marker (path complete)

_PLAYER_WALK1_PATH7:    ; Path 7
    FCB 65              ; path7: intensity
    FCB $08,$FD,0,0        ; path7: header (y=8, x=-3)
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB 2                ; End marker (path complete)

; Generated from player_walk3.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 26
; X bounds: min=-7, max=6, width=13
; Center: (0, 0)

_PLAYER_WALK3_WIDTH EQU 13
_PLAYER_WALK3_HALF_WIDTH EQU 6
_PLAYER_WALK3_HEIGHT EQU 19
_PLAYER_WALK3_HALF_HEIGHT EQU 9
_PLAYER_WALK3_CENTER_X EQU 0
_PLAYER_WALK3_CENTER_Y EQU 0

_PLAYER_WALK3_VECTORS:  ; Main entry (header + 5 path(s))
    FDB 5               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLAYER_WALK3_PATH0        ; pointer to path 0
    FDB _PLAYER_WALK3_PATH1        ; pointer to path 1
    FDB _PLAYER_WALK3_PATH2        ; pointer to path 2
    FDB _PLAYER_WALK3_PATH3        ; pointer to path 3
    FDB _PLAYER_WALK3_PATH4        ; pointer to path 4

_PLAYER_WALK3_PATH0:    ; Path 0
    FCB 65              ; path0: intensity
    FCB $02,$00,0,0        ; path0: header (y=2, x=0)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB 2                ; End marker (path complete)

_PLAYER_WALK3_PATH1:    ; Path 1
    FCB 65              ; path1: intensity
    FCB $FF,$03,0,0        ; path1: header (y=-1, x=3)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK3_PATH2:    ; Path 2
    FCB 65              ; path2: intensity
    FCB $FE,$FE,0,0        ; path2: header (y=-2, x=-2)
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB $FF,$FF,$06          ; flag=-1, dy=-1, dx=6
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$FD,$04          ; flag=-1, dy=-3, dx=4
    FCB $FF,$FF,$FB          ; flag=-1, dy=-1, dx=-5
    FCB $FF,$04,$FF          ; flag=-1, dy=4, dx=-1
    FCB $FF,$FE,$FD          ; flag=-1, dy=-2, dx=-3
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$02,$FA          ; flag=-1, dy=2, dx=-6
    FCB $FF,$05,$02          ; flag=-1, dy=5, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK3_PATH3:    ; Path 3
    FCB 65              ; path3: intensity
    FCB $06,$FE,0,0        ; path3: header (y=6, x=-2)
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK3_PATH4:    ; Path 4
    FCB 65              ; path4: intensity
    FCB $07,$01,0,0        ; path4: header (y=7, x=1)
    FCB $FF,$FE,$FC          ; flag=-1, dy=-2, dx=-4
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$04,$01          ; flag=-1, dy=4, dx=1
    FCB $FF,$02,$FD          ; flag=-1, dy=2, dx=-3
    FCB 2                ; End marker (path complete)

; Generated from titchi_walk3.vec (Malban Draw_Sync_List format)
; Total paths: 13, points: 39
; X bounds: min=-7, max=7, width=14
; Center: (0, -1)

_TITCHI_WALK3_WIDTH EQU 14
_TITCHI_WALK3_HALF_WIDTH EQU 7
_TITCHI_WALK3_HEIGHT EQU 15
_TITCHI_WALK3_HALF_HEIGHT EQU 7
_TITCHI_WALK3_CENTER_X EQU 0
_TITCHI_WALK3_CENTER_Y EQU -1

_TITCHI_WALK3_VECTORS:  ; Main entry (header + 13 path(s))
    FDB 13               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _TITCHI_WALK3_PATH0        ; pointer to path 0
    FDB _TITCHI_WALK3_PATH1        ; pointer to path 1
    FDB _TITCHI_WALK3_PATH2        ; pointer to path 2
    FDB _TITCHI_WALK3_PATH3        ; pointer to path 3
    FDB _TITCHI_WALK3_PATH4        ; pointer to path 4
    FDB _TITCHI_WALK3_PATH5        ; pointer to path 5
    FDB _TITCHI_WALK3_PATH6        ; pointer to path 6
    FDB _TITCHI_WALK3_PATH7        ; pointer to path 7
    FDB _TITCHI_WALK3_PATH8        ; pointer to path 8
    FDB _TITCHI_WALK3_PATH9        ; pointer to path 9
    FDB _TITCHI_WALK3_PATH10        ; pointer to path 10
    FDB _TITCHI_WALK3_PATH11        ; pointer to path 11
    FDB _TITCHI_WALK3_PATH12        ; pointer to path 12

_TITCHI_WALK3_PATH0:    ; Path 0
    FCB 85              ; path0: intensity
    FCB $00,$FE,0,0        ; path0: header (y=0, x=-2)
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB 2                ; End marker (path complete)

_TITCHI_WALK3_PATH1:    ; Path 1
    FCB 85              ; path1: intensity
    FCB $FD,$FC,0,0        ; path1: header (y=-3, x=-4)
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB 2                ; End marker (path complete)

_TITCHI_WALK3_PATH2:    ; Path 2
    FCB 85              ; path2: intensity
    FCB $F8,$FD,0,0        ; path2: header (y=-8, x=-3)
    FCB 2                ; End marker (path complete)

_TITCHI_WALK3_PATH3:    ; Path 3
    FCB 85              ; path3: intensity
    FCB $FA,$00,0,0        ; path3: header (y=-6, x=0)
    FCB 2                ; End marker (path complete)

_TITCHI_WALK3_PATH4:    ; Path 4
    FCB 85              ; path4: intensity
    FCB $FA,$01,0,0        ; path4: header (y=-6, x=1)
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB 2                ; End marker (path complete)

_TITCHI_WALK3_PATH5:    ; Path 5
    FCB 85              ; path5: intensity
    FCB $FE,$05,0,0        ; path5: header (y=-2, x=5)
    FCB 2                ; End marker (path complete)

_TITCHI_WALK3_PATH6:    ; Path 6
    FCB 85              ; path6: intensity
    FCB $00,$05,0,0        ; path6: header (y=0, x=5)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$FF,$FA          ; flag=-1, dy=-1, dx=-6
    FCB $FF,$FF,$03          ; flag=-1, dy=-1, dx=3
    FCB $FF,$FE,$FA          ; flag=-1, dy=-2, dx=-6
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$06,$FE          ; flag=-1, dy=6, dx=-2
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB 2                ; End marker (path complete)

_TITCHI_WALK3_PATH7:    ; Path 7
    FCB 85              ; path7: intensity
    FCB $04,$FE,0,0        ; path7: header (y=4, x=-2)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB 2                ; End marker (path complete)

_TITCHI_WALK3_PATH8:    ; Path 8
    FCB 85              ; path8: intensity
    FCB $06,$FF,0,0        ; path8: header (y=6, x=-1)
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB 2                ; End marker (path complete)

_TITCHI_WALK3_PATH9:    ; Path 9
    FCB 85              ; path9: intensity
    FCB $04,$04,0,0        ; path9: header (y=4, x=4)
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_TITCHI_WALK3_PATH10:    ; Path 10
    FCB 85              ; path10: intensity
    FCB $04,$02,0,0        ; path10: header (y=4, x=2)
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB 2                ; End marker (path complete)

_TITCHI_WALK3_PATH11:    ; Path 11
    FCB 85              ; path11: intensity
    FCB $04,$04,0,0        ; path11: header (y=4, x=4)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB 2                ; End marker (path complete)

_TITCHI_WALK3_PATH12:    ; Path 12
    FCB 85              ; path12: intensity
    FCB $02,$05,0,0        ; path12: header (y=2, x=5)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB 2                ; End marker (path complete)

; Generated from player_walk2.vec (Malban Draw_Sync_List format)
; Total paths: 8, points: 25
; X bounds: min=-5, max=5, width=10
; Center: (0, 0)

_PLAYER_WALK2_WIDTH EQU 10
_PLAYER_WALK2_HALF_WIDTH EQU 5
_PLAYER_WALK2_HEIGHT EQU 17
_PLAYER_WALK2_HALF_HEIGHT EQU 8
_PLAYER_WALK2_CENTER_X EQU 0
_PLAYER_WALK2_CENTER_Y EQU 0

_PLAYER_WALK2_VECTORS:  ; Main entry (header + 8 path(s))
    FDB 8               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLAYER_WALK2_PATH0        ; pointer to path 0
    FDB _PLAYER_WALK2_PATH1        ; pointer to path 1
    FDB _PLAYER_WALK2_PATH2        ; pointer to path 2
    FDB _PLAYER_WALK2_PATH3        ; pointer to path 3
    FDB _PLAYER_WALK2_PATH4        ; pointer to path 4
    FDB _PLAYER_WALK2_PATH5        ; pointer to path 5
    FDB _PLAYER_WALK2_PATH6        ; pointer to path 6
    FDB _PLAYER_WALK2_PATH7        ; pointer to path 7

_PLAYER_WALK2_PATH0:    ; Path 0
    FCB 65              ; path0: intensity
    FCB $02,$01,0,0        ; path0: header (y=2, x=1)
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK2_PATH1:    ; Path 1
    FCB 65              ; path1: intensity
    FCB $00,$03,0,0        ; path1: header (y=0, x=3)
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK2_PATH2:    ; Path 2
    FCB 65              ; path2: intensity
    FCB $FC,$02,0,0        ; path2: header (y=-4, x=2)
    FCB $FF,$FB,$FF          ; flag=-1, dy=-5, dx=-1
    FCB $FF,$05,$FB          ; flag=-1, dy=5, dx=-5
    FCB 2                ; End marker (path complete)

_PLAYER_WALK2_PATH3:    ; Path 3
    FCB 65              ; path3: intensity
    FCB $FB,$FD,0,0        ; path3: header (y=-5, x=-3)
    FCB $FF,$FC,$FE          ; flag=-1, dy=-4, dx=-2
    FCB $FF,$02,$04          ; flag=-1, dy=2, dx=4
    FCB 2                ; End marker (path complete)

_PLAYER_WALK2_PATH4:    ; Path 4
    FCB 65              ; path4: intensity
    FCB $F7,$01,0,0        ; path4: header (y=-9, x=1)
    FCB $FF,$01,$04          ; flag=-1, dy=1, dx=4
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK2_PATH5:    ; Path 5
    FCB 65              ; path5: intensity
    FCB $FD,$FF,0,0        ; path5: header (y=-3, x=-1)
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$05,$02          ; flag=-1, dy=5, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK2_PATH6:    ; Path 6
    FCB 65              ; path6: intensity
    FCB $06,$FE,0,0        ; path6: header (y=6, x=-2)
    FCB $FF,$FC,$FF          ; flag=-1, dy=-4, dx=-1
    FCB $FF,$FE,$04          ; flag=-1, dy=-2, dx=4
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$05,$FD          ; flag=-1, dy=5, dx=-3
    FCB 2                ; End marker (path complete)

_PLAYER_WALK2_PATH7:    ; Path 7
    FCB 65              ; path7: intensity
    FCB $08,$FD,0,0        ; path7: header (y=8, x=-3)
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB 2                ; End marker (path complete)

; Generated from titchi_walk1.vec (Malban Draw_Sync_List format)
; Total paths: 13, points: 40
; X bounds: min=-7, max=7, width=14
; Center: (0, 0)

_TITCHI_WALK1_WIDTH EQU 14
_TITCHI_WALK1_HALF_WIDTH EQU 7
_TITCHI_WALK1_HEIGHT EQU 13
_TITCHI_WALK1_HALF_HEIGHT EQU 6
_TITCHI_WALK1_CENTER_X EQU 0
_TITCHI_WALK1_CENTER_Y EQU 0

_TITCHI_WALK1_VECTORS:  ; Main entry (header + 13 path(s))
    FDB 13               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _TITCHI_WALK1_PATH0        ; pointer to path 0
    FDB _TITCHI_WALK1_PATH1        ; pointer to path 1
    FDB _TITCHI_WALK1_PATH2        ; pointer to path 2
    FDB _TITCHI_WALK1_PATH3        ; pointer to path 3
    FDB _TITCHI_WALK1_PATH4        ; pointer to path 4
    FDB _TITCHI_WALK1_PATH5        ; pointer to path 5
    FDB _TITCHI_WALK1_PATH6        ; pointer to path 6
    FDB _TITCHI_WALK1_PATH7        ; pointer to path 7
    FDB _TITCHI_WALK1_PATH8        ; pointer to path 8
    FDB _TITCHI_WALK1_PATH9        ; pointer to path 9
    FDB _TITCHI_WALK1_PATH10        ; pointer to path 10
    FDB _TITCHI_WALK1_PATH11        ; pointer to path 11
    FDB _TITCHI_WALK1_PATH12        ; pointer to path 12

_TITCHI_WALK1_PATH0:    ; Path 0
    FCB 85              ; path0: intensity
    FCB $FF,$FE,0,0        ; path0: header (y=-1, x=-2)
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB 2                ; End marker (path complete)

_TITCHI_WALK1_PATH1:    ; Path 1
    FCB 85              ; path1: intensity
    FCB $FC,$FC,0,0        ; path1: header (y=-4, x=-4)
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB 2                ; End marker (path complete)

_TITCHI_WALK1_PATH2:    ; Path 2
    FCB 85              ; path2: intensity
    FCB $F9,$FB,0,0        ; path2: header (y=-7, x=-5)
    FCB 2                ; End marker (path complete)

_TITCHI_WALK1_PATH3:    ; Path 3
    FCB 85              ; path3: intensity
    FCB $F9,$01,0,0        ; path3: header (y=-7, x=1)
    FCB 2                ; End marker (path complete)

_TITCHI_WALK1_PATH4:    ; Path 4
    FCB 85              ; path4: intensity
    FCB $F9,$02,0,0        ; path4: header (y=-7, x=2)
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB $FF,$FF,$FB          ; flag=-1, dy=-1, dx=-5
    FCB 2                ; End marker (path complete)

_TITCHI_WALK1_PATH5:    ; Path 5
    FCB 85              ; path5: intensity
    FCB $FD,$05,0,0        ; path5: header (y=-3, x=5)
    FCB 2                ; End marker (path complete)

_TITCHI_WALK1_PATH6:    ; Path 6
    FCB 85              ; path6: intensity
    FCB $FF,$05,0,0        ; path6: header (y=-1, x=5)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$FF,$FA          ; flag=-1, dy=-1, dx=-6
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$06,$FE          ; flag=-1, dy=6, dx=-2
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB 2                ; End marker (path complete)

_TITCHI_WALK1_PATH7:    ; Path 7
    FCB 85              ; path7: intensity
    FCB $03,$FE,0,0        ; path7: header (y=3, x=-2)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB 2                ; End marker (path complete)

_TITCHI_WALK1_PATH8:    ; Path 8
    FCB 85              ; path8: intensity
    FCB $05,$FF,0,0        ; path8: header (y=5, x=-1)
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB 2                ; End marker (path complete)

_TITCHI_WALK1_PATH9:    ; Path 9
    FCB 85              ; path9: intensity
    FCB $03,$04,0,0        ; path9: header (y=3, x=4)
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_TITCHI_WALK1_PATH10:    ; Path 10
    FCB 85              ; path10: intensity
    FCB $03,$02,0,0        ; path10: header (y=3, x=2)
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB 2                ; End marker (path complete)

_TITCHI_WALK1_PATH11:    ; Path 11
    FCB 85              ; path11: intensity
    FCB $03,$04,0,0        ; path11: header (y=3, x=4)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB 2                ; End marker (path complete)

_TITCHI_WALK1_PATH12:    ; Path 12
    FCB 85              ; path12: intensity
    FCB $01,$05,0,0        ; path12: header (y=1, x=5)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB 2                ; End marker (path complete)

; Generated from titchi_walk2.vec (Malban Draw_Sync_List format)
; Total paths: 13, points: 39
; X bounds: min=-7, max=7, width=14
; Center: (0, 0)

_TITCHI_WALK2_WIDTH EQU 14
_TITCHI_WALK2_HALF_WIDTH EQU 7
_TITCHI_WALK2_HEIGHT EQU 13
_TITCHI_WALK2_HALF_HEIGHT EQU 6
_TITCHI_WALK2_CENTER_X EQU 0
_TITCHI_WALK2_CENTER_Y EQU 0

_TITCHI_WALK2_VECTORS:  ; Main entry (header + 13 path(s))
    FDB 13               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _TITCHI_WALK2_PATH0        ; pointer to path 0
    FDB _TITCHI_WALK2_PATH1        ; pointer to path 1
    FDB _TITCHI_WALK2_PATH2        ; pointer to path 2
    FDB _TITCHI_WALK2_PATH3        ; pointer to path 3
    FDB _TITCHI_WALK2_PATH4        ; pointer to path 4
    FDB _TITCHI_WALK2_PATH5        ; pointer to path 5
    FDB _TITCHI_WALK2_PATH6        ; pointer to path 6
    FDB _TITCHI_WALK2_PATH7        ; pointer to path 7
    FDB _TITCHI_WALK2_PATH8        ; pointer to path 8
    FDB _TITCHI_WALK2_PATH9        ; pointer to path 9
    FDB _TITCHI_WALK2_PATH10        ; pointer to path 10
    FDB _TITCHI_WALK2_PATH11        ; pointer to path 11
    FDB _TITCHI_WALK2_PATH12        ; pointer to path 12

_TITCHI_WALK2_PATH0:    ; Path 0
    FCB 85              ; path0: intensity
    FCB $FF,$FE,0,0        ; path0: header (y=-1, x=-2)
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB 2                ; End marker (path complete)

_TITCHI_WALK2_PATH1:    ; Path 1
    FCB 85              ; path1: intensity
    FCB $FC,$FC,0,0        ; path1: header (y=-4, x=-4)
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB 2                ; End marker (path complete)

_TITCHI_WALK2_PATH2:    ; Path 2
    FCB 85              ; path2: intensity
    FCB $F9,$FB,0,0        ; path2: header (y=-7, x=-5)
    FCB 2                ; End marker (path complete)

_TITCHI_WALK2_PATH3:    ; Path 3
    FCB 85              ; path3: intensity
    FCB $F9,$01,0,0        ; path3: header (y=-7, x=1)
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB $FF,$02,$FD          ; flag=-1, dy=2, dx=-3
    FCB 2                ; End marker (path complete)

_TITCHI_WALK2_PATH4:    ; Path 4
    FCB 85              ; path4: intensity
    FCB $FD,$05,0,0        ; path4: header (y=-3, x=5)
    FCB 2                ; End marker (path complete)

_TITCHI_WALK2_PATH5:    ; Path 5
    FCB 85              ; path5: intensity
    FCB $FF,$05,0,0        ; path5: header (y=-1, x=5)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$FF,$FA          ; flag=-1, dy=-1, dx=-6
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$06,$FE          ; flag=-1, dy=6, dx=-2
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB 2                ; End marker (path complete)

_TITCHI_WALK2_PATH6:    ; Path 6
    FCB 85              ; path6: intensity
    FCB $03,$FE,0,0        ; path6: header (y=3, x=-2)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB 2                ; End marker (path complete)

_TITCHI_WALK2_PATH7:    ; Path 7
    FCB 85              ; path7: intensity
    FCB $05,$FF,0,0        ; path7: header (y=5, x=-1)
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB 2                ; End marker (path complete)

_TITCHI_WALK2_PATH8:    ; Path 8
    FCB 85              ; path8: intensity
    FCB $03,$04,0,0        ; path8: header (y=3, x=4)
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_TITCHI_WALK2_PATH9:    ; Path 9
    FCB 85              ; path9: intensity
    FCB $03,$02,0,0        ; path9: header (y=3, x=2)
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB 2                ; End marker (path complete)

_TITCHI_WALK2_PATH10:    ; Path 10
    FCB 85              ; path10: intensity
    FCB $03,$04,0,0        ; path10: header (y=3, x=4)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB 2                ; End marker (path complete)

_TITCHI_WALK2_PATH11:    ; Path 11
    FCB 85              ; path11: intensity
    FCB $01,$05,0,0        ; path11: header (y=1, x=5)
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB 2                ; End marker (path complete)

_TITCHI_WALK2_PATH12:    ; Path 12
    FCB 85              ; path12: intensity
    FCB $F9,$01,0,0        ; path12: header (y=-7, x=1)
    FCB 2                ; End marker (path complete)

; Generated from player_walk4.vec (Malban Draw_Sync_List format)
; Total paths: 6, points: 26
; X bounds: min=-7, max=6, width=13
; Center: (0, 0)

_PLAYER_WALK4_WIDTH EQU 13
_PLAYER_WALK4_HALF_WIDTH EQU 6
_PLAYER_WALK4_HEIGHT EQU 19
_PLAYER_WALK4_HALF_HEIGHT EQU 9
_PLAYER_WALK4_CENTER_X EQU 0
_PLAYER_WALK4_CENTER_Y EQU 0

_PLAYER_WALK4_VECTORS:  ; Main entry (header + 6 path(s))
    FDB 6               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLAYER_WALK4_PATH0        ; pointer to path 0
    FDB _PLAYER_WALK4_PATH1        ; pointer to path 1
    FDB _PLAYER_WALK4_PATH2        ; pointer to path 2
    FDB _PLAYER_WALK4_PATH3        ; pointer to path 3
    FDB _PLAYER_WALK4_PATH4        ; pointer to path 4
    FDB _PLAYER_WALK4_PATH5        ; pointer to path 5

_PLAYER_WALK4_PATH0:    ; Path 0
    FCB 65              ; path0: intensity
    FCB $02,$00,0,0        ; path0: header (y=2, x=0)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB 2                ; End marker (path complete)

_PLAYER_WALK4_PATH1:    ; Path 1
    FCB 65              ; path1: intensity
    FCB $00,$02,0,0        ; path1: header (y=0, x=2)
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$FD,$04          ; flag=-1, dy=-3, dx=4
    FCB $FF,$FF,$FB          ; flag=-1, dy=-1, dx=-5
    FCB $FF,$04,$FF          ; flag=-1, dy=4, dx=-1
    FCB $FF,$FE,$FD          ; flag=-1, dy=-2, dx=-3
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$02,$FA          ; flag=-1, dy=2, dx=-6
    FCB $FF,$05,$02          ; flag=-1, dy=5, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK4_PATH2:    ; Path 2
    FCB 65              ; path2: intensity
    FCB $FE,$FE,0,0        ; path2: header (y=-2, x=-2)
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$03,$03          ; flag=-1, dy=3, dx=3
    FCB 2                ; End marker (path complete)

_PLAYER_WALK4_PATH3:    ; Path 3
    FCB 65              ; path3: intensity
    FCB $06,$FE,0,0        ; path3: header (y=6, x=-2)
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$FF,$FD          ; flag=-1, dy=-1, dx=-3
    FCB 2                ; End marker (path complete)

_PLAYER_WALK4_PATH4:    ; Path 4
    FCB 65              ; path4: intensity
    FCB $06,$FE,0,0        ; path4: header (y=6, x=-2)
    FCB $FF,$FB,$FF          ; flag=-1, dy=-5, dx=-1
    FCB $FF,$FF,$05          ; flag=-1, dy=-1, dx=5
    FCB $FF,$05,$02          ; flag=-1, dy=5, dx=2
    FCB $FF,$02,$FD          ; flag=-1, dy=2, dx=-3
    FCB 2                ; End marker (path complete)

_PLAYER_WALK4_PATH5:    ; Path 5
    FCB 65              ; path5: intensity
    FCB $FF,$03,0,0        ; path5: header (y=-1, x=3)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

;***************************************************************************
; RUNTIME HELPERS
;***************************************************************************

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
    LDX >$C82C      ; Save Vec_Str_Ptr (BIOS may dereference between frames)
    PSHS X
    JSR Print_Str_d
    PULS X
    STX >$C82C      ; Restore Vec_Str_Ptr to safe ROM value
    LDA #$F8
    STA >$C82A      ; Restore Vec_Text_Height to normal (-8)
    LDA #$48
    STA >$C82B      ; Restore Vec_Text_Width to normal (72)
    JSR $F1AF      ; DP_to_C8 - restore DP before return
    RTS

VECTREX_PRINT_NUMBER:
    ; Print signed decimal number (-9999 to 9999)
    ; ARG0=x, ARG1=y, ARG2=value
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
    
.PN_AFTER_CONVERT:
    ; STEP 2: Set up BIOS and print (NOW change DP to $D0)
    LDA #$D0
    TFR A,DP         ; Set Direct Page to $D0 for BIOS
    JSR Intensity_5F ; Set text brightness (mirrors PRINT_TEXT)
    JSR Reset0Ref    ; Reset beam to center before positioning text
    LDU #NUM_STR     ; String pointer
    LDA >TEXT_SCALE_H ; height (signed byte)
    STA >$C82A       ; Vec_Text_Height: character Y scale
    LDA >TEXT_SCALE_W ; width (unsigned byte)
    STA >$C82B       ; Vec_Text_Width: character X spacing
    LDA >VAR_ARG1+1  ; Y coordinate
    LDB >VAR_ARG0+1  ; X coordinate
    LDX >$C82C       ; Save Vec_Str_Ptr (BIOS may dereference between frames)
    PSHS X
    JSR Print_Str_d  ; Print using BIOS (A=Y, B=X, U=string)
    PULS X
    STX >$C82C       ; Restore Vec_Str_Ptr (NUM_STR is RAM, not ROM)
    LDA #$F8
    STA >$C82A       ; Restore Vec_Text_Height to normal (-8)
    LDA #$48
    STA >$C82B       ; Restore Vec_Text_Width to normal (72)
    JSR $F1AF      ; Restore DP to $C8
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

RAND_HELPER:
    ; LCG: seed = (seed * 1103515245 + 12345) & 0x7FFF
    ; Simplified for 6809: seed = (seed * 25 + 13) & 0x7FFF
    LDD RAND_SEED
    LDX #26
    ; Multiply by 25: loop runs 25 times (LCG a=25, Hull-Dobell ok)
    PSHS D
    LDD #0
RAND_MUL_LOOP:
    LEAX -1,X
    BEQ RAND_MUL_DONE
    ADDD ,S
    BRA RAND_MUL_LOOP
RAND_MUL_DONE:
    LEAS 2,S
    ADDD #13       ; Add constant c=13 (odd, Hull-Dobell ok)
    STD RAND_SEED  ; Store full 16-bit state BEFORE masking output
    ANDA #$7F      ; Mask output to positive 15-bit (state stays full)
    RTS

RAND_RANGE_HELPER:
    ; Input: TMPPTR = min (i16), TMPPTR2 = max (i16)
    ; Returns: D = min + (rand % (max - min + 1))
    JSR RAND_HELPER        ; D = rand (0..$7FFF)
    PSHS D                 ; Save rand
    LDD TMPPTR2            ; max
    SUBD TMPPTR            ; D = max - min
    ADDD #1                ; D = inclusive range
    STD TMPPTR2            ; TMPPTR2 = range
    PULS D                 ; Restore rand
RRH_MOD:
    SUBD TMPPTR2           ; D -= range
    BCC RRH_MOD            ; if no borrow (D >= range), keep subtracting
    ADDD TMPPTR2           ; Undo last subtract: now 0 <= D < range
    ADDD TMPPTR            ; Add min -> D in [min, max]
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
    
    ; Read enemy data from header (+29: count, +30,+31: instances_ptr)
    LDB ,X+         ; B = enemy_count
    STB >LEVEL_ENEMY_COUNT
    LDD ,X          ; D = enemy_instances_ptr
    STD >LEVEL_ENEMY_INSTANCES_PTR
    
    ; === Setup GP pointer: point directly to ROM (matches core) ===
    ; GP objects are read from ROM with stride=20, same as BG/FG
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
    ; MULTIBANK: Switch to level bank so ROM pointers are valid
    LDA >CURRENT_ROM_BANK
    PSHS A              ; Save current bank
    LDA >LEVEL_BANK
    STA >CURRENT_ROM_BANK
    STA $DF00           ; Switch to level bank
    
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
    LDA #20          ; GP objects read from ROM (20 bytes)
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
    ; MULTIBANK: Restore original bank
    PULS A              ; A = saved bank
    STA >CURRENT_ROM_BANK
    STA $DF00           ; Restore bank
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
    CMPU #0          ; null vector_ptr? (enemy type objects have no visual)
    LBEQ SLR_OBJ_NEXT ; skip draw if no vector assigned
    LDA 3,X          ; scale_t1 from RAM +3 (pre-computed T1 = scale*127)
    STA >DRAW_T1_SCALED
    LBRA SLR_DRAW_VECTOR
    
SLR_ROM_OFFSETS:
    ; === ROM object (stride=20) ===
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
    CMPU #0          ; null vector_ptr? (enemy type objects have no visual)
    LBEQ SLR_OBJ_NEXT ; skip draw if no vector assigned
    LDA 6,X          ; scale_t1 from ROM +6 (low byte of scale FDB; pre-computed T1 = scale*127)
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
    JSR Draw_Sync_List_At_With_Mirrors  ; Draw this path
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
;         LCOL_PY (16-bit) = player_feet (player_y - player_hh)
; Output: RESULT = highest floor landing Y (i16)
;         Returns $FF80 (-128) if no collidable surface found at that X.
; Algorithm: for each collidable GP object, check X AABB overlap,
;   compute surface_top = obj_y(16) + half_height, track max (16-bit).
; ROM object offsets: +0=type, +1-2=x(FDB), +3-4=y(FDB), +12=collision_flags,
;   +18=half_width, +19=half_height. Stride=20.
LEVEL_COLLISION_Y_RUNTIME:
    PSHS X,Y,U       ; Save regs (NOT D - result returns in D)
    ; MULTIBANK: Switch to level bank so ROM GP pointer dereferences land in the right bank
    LDA >CURRENT_ROM_BANK
    PSHS A              ; Save current bank
    LDA >LEVEL_BANK
    STA >CURRENT_ROM_BANK
    STA $DF00           ; Switch to level bank
    
    ; Initialize best_floor = -32768 ($8000, no floor found)
    LDD #$8000
    STD >LCOL_BEST_Y
    
    ; Check level loaded
    TST >LEVEL_LOADED
    BEQ LCOL_Y_DONE
    
    LDB >LEVEL_GP_COUNT
    BEQ LCOL_Y_DONE
    LDX >LEVEL_GP_PTR  ; X = ROM GP objects
    
LCOL_Y_LOOP:
    TSTB
    BEQ LCOL_Y_DONE
    PSHS B           ; save count
    
    ; --- Check collision flag (bit 0 at ROM+12) ---
    LDA 12,X
    BITA #$01
    BEQ LCOL_Y_NEXT  ; not collidable
    
    ; --- X AABB overlap: obj_x - hw <= player_x <= obj_x + hw ---
    ; Compute left_edge = obj_x - hw (16-bit, ROM+1=x FDB, ROM+18=half_width)
    LDD 1,X          ; D = world_x FDB (ROM+1-2)
    SUBB 18,X        ; B = world_x_lo - half_width
    SBCA #0          ; A = world_x_hi - borrow
    STD >TMPVAL      ; TMPVAL = left_edge
    
    ; Compare player_x >= left_edge (signed 16-bit)
    LDD >LCOL_PX
    CMPD >TMPVAL
    LBLT LCOL_Y_NEXT ; player_x < left_edge → no overlap
    
    ; Compute right_edge = obj_x + hw (16-bit)
    LDD 1,X          ; D = world_x FDB
    ADDB 18,X        ; B = world_x_lo + half_width
    ADCA #0          ; A = world_x_hi + carry
    STD >TMPVAL      ; TMPVAL = right_edge
    
    ; Compare player_x <= right_edge (signed 16-bit)
    LDD >LCOL_PX
    CMPD >TMPVAL
    LBGT LCOL_Y_NEXT ; player_x > right_edge → no overlap
    
    ; --- X overlaps — compute surface_top = obj_y(16-bit) + half_height ---
    LDD 3,X          ; D = world_y FDB (ROM+3-4, full 16-bit signed)
    ADDB 19,X        ; B = world_y_lo + half_height
    ADCA #0          ; propagate carry to high byte
    STD >TMPVAL      ; TMPVAL = surface_top (16-bit)
    ; Filter: skip surfaces above the player's feet (surface_top > player_feet)
    ;   — player can only land on surfaces at or below their feet level.
    CMPD >LCOL_PY    ; signed 16-bit compare surface_top vs player_feet
    LBGT LCOL_Y_NEXT ; surface_top > player_feet → already passed below → skip
    ; Compute landing Y = surface_top + player_half_height (16-bit)
    LDD >TMPVAL      ; reload surface_top
    ADDB >LCOL_PHH   ; add player_hh to low byte
    ADCA #0          ; propagate carry
    ; Update best_floor if this landing Y > current best (16-bit signed)
    CMPD >LCOL_BEST_Y
    BLE LCOL_Y_NEXT  ; not better
    STD >LCOL_BEST_Y ; new best landing Y (16-bit)
    
LCOL_Y_NEXT:
    LEAX 20,X        ; next ROM object (stride 20)
    PULS B
    DECB
    BRA LCOL_Y_LOOP
    
LCOL_Y_DONE:
    ; Return best_floor as RESULT (16-bit)
    LDD >LCOL_BEST_Y
    ; If no floor found ($8000), return -128 for backward compat
    CMPD #$8000
    BNE LCOL_Y_RET
    LDD #$FF80       ; -128
LCOL_Y_RET:
    STD RESULT
    ; MULTIBANK: Restore original bank (result is in RESULT, will reload after)
    PULS A              ; A = saved bank
    STA >CURRENT_ROM_BANK
    STA $DF00           ; Restore bank
    LDD RESULT          ; Reload return value into D
    
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

        ; MULTIBANK: Switch to music's bank before accessing data
LDA >CURRENT_ROM_BANK   ; Get current bank
PSHS A                  ; Save on stack
LDA >PSG_MUSIC_BANK     ; Get music's bank
CMPA ,S                 ; Compare with current bank
BEQ AU_BANK_OK          ; Skip switch if same
STA >CURRENT_ROM_BANK   ; Update RAM tracker
STA $DF00               ; Switch bank hardware register
AU_BANK_OK:

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

        ; MULTIBANK: Switch to SFX bank before reading SFX data
LDA >SFX_BANK           ; Get SFX bank ID
STA >CURRENT_ROM_BANK   ; Update RAM tracker
STA $DF00               ; Switch bank hardware register

        JSR sfx_doframe         ; Process one SFX frame (uses Sound_Byte internally)

AU_DONE:
        ; MULTIBANK: Restore original bank
PULS A                  ; Get saved bank from stack
STA >CURRENT_ROM_BANK   ; Update RAM tracker
STA $DF00               ; Restore bank hardware register
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
; NOTE: do NOT set ACR here. DRAW_VECTOR works without touching ACR;
; setting ACR=$18 (T1 no PB7) breaks T1 timing inside DSWM and hangs.
PSHS D,X,Y,U
; --- Refresh MIRROR_X from saved arg (re-assert before any BIOS call can corrupt A) ---
LDA >DRAW_ANIM_MIRROR_X
STA >MIRROR_X
; --- Apply scale: copy DRAW_ANIM_SCALE to DRAW_SCALE for DSWM ---
LDA >DRAW_ANIM_SCALE
STA >DRAW_SCALE
; --- Draw base_refs (static cel layer, drawn before every frame) ---
LDB 2,X             ; base_ref_count
BEQ DAR_TICK        ; none: skip to tick management
LEAY 4,X            ; Y = first base_ref FDB entry
DAR_BASE_LOOP:
PSHS B,X,Y
LDX ,Y              ; X = _VECNAME_VECTORS header
CLR >MIRROR_Y
JSR $F1AA           ; DP_to_D0
LDD ,X              ; D = path_count (FDB, 2 bytes)
BEQ DAR_BASE_SKIP
LEAY 2,X            ; Y = first path FDB in vec table (skip 2-byte count)
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
LDA ,Y              ; A = duration_ticks from vanim
LDB >DRAW_ANIM_SPEED_MUL
BEQ DAR_SPEED1      ; speed=0: use vanim's duration_ticks as-is
TFR B,A             ; speed>0: override with ticks_per_frame directly
DAR_SPEED1:
CMPA #1
BHS DAR_SPEED1_OK
LDA #1
DAR_SPEED1_OK:
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
LDA ,Y              ; A = duration_ticks from vanim
LDB >DRAW_ANIM_SPEED_MUL
BEQ DAR_SPEED2      ; speed=0: use vanim's duration_ticks as-is
TFR B,A             ; speed>0: override with ticks_per_frame directly
DAR_SPEED2:
CMPA #1
BHS DAR_SPEED2_OK
LDA #1
DAR_SPEED2_OK:
STA 1,U             ; ticks_left = ticks_per_frame
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
JSR $F1AA           ; DP_to_D0
LDD ,X              ; D = path_count (FDB, 2 bytes)
BEQ DAR_VEC_DONE
LEAY 2,X            ; Y = first path FDB (skip 2-byte count)
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
; Restore DRAW_SCALE to default ($7F) after animation draw
LDA #$7F
STA >DRAW_SCALE
PULS D,X,Y,U
RTS

; ============================================================================
; ENEMY SYSTEM RUNTIME  (max 8 enemies, stride 17 bytes)
; ============================================================================
ENEMY_POOL_STRIDE EQU 17
ENEMY_POOL_MAX    EQU 8

; Pool record offsets
POOL_ACTIVE  EQU 0
POOL_X_HI    EQU 1
POOL_X_LO    EQU 2
POOL_Y_HI    EQU 3
POOL_Y_LO    EQU 4
POOL_TYPE_HI EQU 5
POOL_TYPE_LO EQU 6
POOL_ACTION  EQU 7
POOL_AI      EQU 8
POOL_HP      EQU 9
POOL_WPIDX   EQU 10
POOL_WPPTR   EQU 11
POOL_SM_STATE EQU 13
POOL_SM_TMR_HI EQU 14
POOL_SM_TMR_LO EQU 15
POOL_WPCOUNT   EQU 16
; SM state record layout (SM_STATE_STRIDE = 13 bytes, max 4 events)
SM_STATE_STRIDE EQU 13
SM_HDR_INIT   EQU 1
SM_HDR_STATES EQU 2
SM_ST_ACTION  EQU 0
SM_ST_DCY_HI  EQU 1
SM_ST_DCY_LO  EQU 2
SM_ST_DCYTO   EQU 3
SM_ST_NEVT    EQU 4
SM_ST_EVT0H   EQU 5
SM_ST_EVT0T   EQU 6
SM_ST_EVT1H   EQU 7
SM_ST_EVT1T   EQU 8
SM_ST_EVT2H   EQU 9
SM_ST_EVT2T   EQU 10
SM_ST_EVT3H   EQU 11
SM_ST_EVT3T   EQU 12

; SPAWN_ENEMIES_RUNTIME
; Entry: B = instance count, X = ptr to _LEVEL_ENEMY_INSTANCES table
; Initialises ENEMY_POOL from the ROM instance table.
SPAWN_ENEMIES_RUNTIME:
STB >ENEMY_COUNT
LBEQ SPAWN_ENE_DONE
; Zero-clear the pool (B × 13 bytes)
STX >ENEMY_SCRATCH_PTR
LDY #ENEMY_POOL
CLRA
SPAWN_CLR_LOOP:
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
DECB
BNE SPAWN_CLR_LOOP
; Fill pool from instance table
LDB >ENEMY_COUNT
LDY #ENEMY_POOL
SPAWN_FILL_LOOP:
LDX >ENEMY_SCRATCH_PTR
LDA #1
STA ,Y              ; +0 active=1
LDA 2,X
STA 1,Y             ; +1 x hi
LDA 3,X
STA 2,Y             ; +2 x lo
LDA 4,X
STA 3,Y             ; +3 y hi
LDA 5,X
STA 4,Y             ; +4 y lo
LDA ,X
STA 5,Y             ; +5 type_ptr hi
LDA 1,X
STA 6,Y             ; +6 type_ptr lo
CLR 7,Y             ; +7 action=0 (idle)
LDA 6,X
STA 8,Y             ; +8 ai_type
; hp = first byte of enemy type block
LDX >ENEMY_SCRATCH_PTR  ; reload instance ptr (X still valid here)
PSHS B,X,Y
LDA 5,Y
LDB 6,Y
TFR D,X             ; X = type_ptr = _NAME_ENEMY header
LDA ,X              ; hp byte
PULS B,X,Y
STA 9,Y             ; +9 hp
CLR 10,Y            ; +10 wp_idx=0
LDA 9,X
STA 16,Y            ; +16 wp_count
LDA 10,X
STA 11,Y            ; +11 wp_ptr hi
LDA 11,X
STA 12,Y            ; +12 wp_ptr lo
; Init SM state (+13) from type header [5-6] = SM ptr
PSHS B              ; save loop counter (B clobbered by LDB below)
LDA 5,Y             ; type_ptr hi (pool)
LDB 6,Y             ; type_ptr lo (pool)
TFR D,X             ; X = _NAME_ENEMY header
LDA 5,X             ; SM ptr hi (header[5])
LDB 6,X             ; SM ptr lo (header[6])
CMPD #0
BEQ SPAWN_SM_NOSM   ; no state machine
TFR D,X             ; X = SM table header
PSHS X              ; save SM header ptr
LDA 1,X             ; initial_state_idx
STA 13,Y            ; pool.sm_state = initial
; Look up initial state action
TFR A,B             ; B = initial_state_idx
PULS X              ; X = SM header
LEAX 2,X            ; X = &states[0]
LDA #13             ; stride = 13 bytes per state record
MUL                 ; D = initial_state_idx * 13
LEAX D,X            ; X = &states[initial]
LDA ,X              ; action_idx from state[0]
STA 7,Y             ; pool.action = initial action
BRA SPAWN_SM_DONE
SPAWN_SM_NOSM:
LDA #$FF
STA 13,Y            ; pool.sm_state = $FF (no SM)
SPAWN_SM_DONE:
PULS B              ; restore loop counter
CLR 14,Y            ; pool.sm_decay_timer hi = 0
CLR 15,Y            ; pool.sm_decay_timer lo = 0
LDX >ENEMY_SCRATCH_PTR ; restore instance ptr (clobbered above)
; advance X by 12 (instance stride)
LEAX 12,X
STX >ENEMY_SCRATCH_PTR
; advance Y by 17 (pool stride)
LEAY 17,Y
DECB
LBNE SPAWN_FILL_LOOP
SPAWN_ENE_DONE:
RTS

; UPDATE_ENEMIES_RUNTIME (multibank)
; Waypoints live in the level bank. Bank is switched at entry and restored at exit.
; Waypoint table: each entry is 2x FDB = 4 bytes (x hi, x lo, y hi, y lo)
UPDATE_ENEMIES_RUNTIME:
LDB >ENEMY_COUNT
LBEQ UPD_ENE_DONE
LDA CURRENT_ROM_BANK
PSHS A              ; save current bank
LDA >LEVEL_BANK
STA CURRENT_ROM_BANK
STA $DF00           ; switch to level bank
LDY #ENEMY_POOL
UPD_ENE_LOOP:
PSHS B              ; save loop counter
LDA ,Y              ; active?
LBEQ UPD_ENE_NEXT_POP
LDA 8,Y             ; ai_type
CMPA #1
LBNE UPD_ENE_NEXT_POP ; only patrol handled
LDA 11,Y
LDB 12,Y
CMPD #0
LBEQ UPD_ENE_NEXT_POP ; no waypoint table
TFR D,X             ; X = wp_ptr base (level bank)
LDA 10,Y            ; wp_idx
ASLA
ASLA                ; × 4 bytes per waypoint (FDB x, FDB y)
LEAX A,X            ; X = &wp[wp_idx]
; ---- Move X (16-bit signed) ----
LDD ,X              ; D = target_x (FDB)
CMPD 1,Y            ; target_x - world_x
LBEQ UPD_MOVE_Y     ; x already at target
LBGT UPD_INC_X
LDD 1,Y
SUBD #1
STD 1,Y
LBRA UPD_MOVE_Y
UPD_INC_X:
LDD 1,Y
ADDD #1
STD 1,Y
UPD_MOVE_Y:
; ---- Move Y (16-bit signed) ----
LDD 2,X             ; D = target_y (FDB)
CMPD 3,Y            ; target_y - world_y
LBEQ UPD_CHECK_WP   ; y at target
LBGT UPD_INC_Y
LDD 3,Y
SUBD #1
STD 3,Y
LBRA UPD_ENE_NEXT_POP
UPD_INC_Y:
LDD 3,Y
ADDD #1
STD 3,Y
LBRA UPD_ENE_NEXT_POP
UPD_CHECK_WP:
; y at target: check x too
LDD ,X              ; D = target_x
CMPD 1,Y
LBNE UPD_ENE_NEXT_POP ; x not yet at target
; Both x and y at target: advance wp_idx
INC 10,Y            ; wp_idx++
LDA 10,Y
CMPA 16,Y           ; compare to wp_count (pool +16)
LBLO UPD_ENE_NEXT_POP ; if idx < count, done
CLR 10,Y            ; else wrap to 0
LBRA UPD_ENE_NEXT_POP
UPD_ENE_NEXT_POP:
PULS B              ; restore loop counter
LEAY 17,Y           ; next pool record
DECB
LBNE UPD_ENE_LOOP
PULS A              ; restore original bank
STA CURRENT_ROM_BANK
STA $DF00
UPD_ENE_DONE:
RTS

; DRAW_ENEMIES_RUNTIME
; For each active enemy, draws its current-action sprite.
; Enemy type header layout: FCB hp, FCB speed, FDB action_dur, FCB action_count
;   followed by _NAME_ENEMY_ACTIONS table.
; Multibank action entry (6 bytes):
;   [0] FCB sprite_idx   — 0-based index into VECTOR_ADDR_TABLE (vec) or ANIM_ADDR_TABLE (vanim); $FF=none
;   [1] FCB sprite_type  — 0=vec, 1=vanim
;   [2] FCB loop         — 0=one-shot, 1=loop
;   [3] FCB pad
;   [4-5] FDB anim_state — 16-bit RAM address of 2-byte animation state; 0 for vec actions
; Enemy type data resides in the helpers bank (always accessible).
DRAW_ENEMIES_RUNTIME:
LDB >ENEMY_COUNT
LBEQ DRW_ENE_DONE
LDY #ENEMY_POOL
DRW_ENE_LOOP:
PSHS B              ; save outer loop counter
LDA ,Y              ; active?
LBEQ DRW_ENE_NEXT_POP
; Resolve type header and action table entry
LDA 5,Y             ; type_ptr hi
LDB 6,Y             ; type_ptr lo
TFR D,X             ; X = _NAME_ENEMY header
LEAX 7,X            ; skip 7-byte header → action table
LDA 7,Y             ; action index
    LDB #6              ; 6 bytes per action entry (multibank)
MUL                 ; D = action_idx * 6
LEAX D,X            ; X = &actions[action]
; --- Multibank: FCB sprite_idx at action[+0], FCB sprite_type at action[+1] ---
LDA ,X              ; sprite_idx (byte [0])
CMPA #$FF           ; $FF = no sprite assigned
LBEQ DRW_ENE_NEXT_POP
STA >ENEMY_SCRATCH_PTR  ; save sprite_idx (hi byte of 2-byte scratch)
LDB 1,X             ; sprite_type (byte [1]): 0=vec, 1=vanim
STB >ENEMY_SCRATCH_Y    ; save sprite_type (lo byte of 2-byte scratch)
; Read FDB anim_state ptr from bytes [4,5] while X still points to action entry
LDA 4,X             ; anim_state addr hi
STA >ENEMY_SCRATCH_X    ; save hi
LDA 5,X             ; anim_state addr lo
STA >ENEMY_SCRATCH_X+1  ; save lo
; Set draw position from enemy pool: x at +2 (lo), y at +4 (lo)
LDA 2,Y             ; x lo
STA >DRAW_VEC_X
CLR >DRAW_VEC_X_HI
LDA 4,Y             ; y lo
STA >DRAW_VEC_Y
; Branch on sprite_type
LDB >ENEMY_SCRATCH_Y
CMPB #1
BEQ DRW_ENE_VANIM
; --- Vec path: DRAW_VECTOR_BANKED (bank-switches to vector's bank) ---
PSHS Y              ; save pool pointer (DRAW_VECTOR_BANKED clobbers Y)
CLRA
LDB >ENEMY_SCRATCH_PTR  ; B = sprite_idx (vec index)
TFR D,X             ; X = sprite_idx (16-bit, A=0)
JSR DRAW_VECTOR_BANKED
PULS Y              ; restore pool pointer
LBRA DRW_ENE_NEXT_POP
; --- Vanim path: DRAW_ANIM_BANKED ---
DRW_ENE_VANIM:
LDA >ENEMY_SCRATCH_X    ; anim_state ptr hi
LDB >ENEMY_SCRATCH_X+1  ; anim_state ptr lo
CMPD #0
LBEQ DRW_ENE_NEXT_POP    ; no state allocated → skip
TFR D,U             ; U = anim_state ptr (frame_idx, ticks_left)
PSHS Y              ; save pool pointer
CLRA
LDB >ENEMY_SCRATCH_PTR  ; B = sprite_idx (anim index)
TFR D,X             ; X = anim_idx (16-bit, A=0)
JSR DRAW_ANIM_BANKED
PULS Y              ; restore pool pointer
DRW_ENE_NEXT_POP:
PULS B              ; restore outer loop counter
LEAY 17,Y           ; next pool record
DECB
LBNE DRW_ENE_LOOP
DRW_ENE_DONE:
RTS


; KILL_ENEMY_RUNTIME
; Entry: A = enemy index (0-based)
; Effect: pool[A].active=0, ENEMY_COUNT--
; Return: RESULT = new ENEMY_COUNT (D)
KILL_ENEMY_RUNTIME:
LDB #17
MUL
LDX #ENEMY_POOL
LEAX D,X
CLR ,X              ; active = 0
DEC >ENEMY_COUNT
CLRA
LDB >ENEMY_COUNT
STD RESULT
RTS

; ENEMY_FIRE_EVENT_RUNTIME
; Entry: A = enemy index, B = event hash (FNV-1a u8)
; Looks up the current SM state, scans on_event table, applies transition.
; Uses ENEMY_SCRATCH_PTR (2 bytes) and ENEMY_SCRATCH_X (1 byte) as temporals.
ENEMY_FIRE_EVENT_RUNTIME:
STB >ENEMY_SCRATCH_X    ; save event hash (1 byte)
LDB #17
MUL                     ; D = A * stride
LDX #ENEMY_POOL
LEAX D,X                ; X = &pool[A]
STX >ENEMY_SCRATCH_PTR  ; save pool ptr
LDA 13,X     ; sm_state
CMPA #$FF
BEQ FIRE_EVT_RTS        ; no SM
LDA 5,X
LDB 6,X
TFR D,X                 ; X = type header
LDA 5,X                 ; SM hi
LDB 6,X                 ; SM lo
CMPD #0
BEQ FIRE_EVT_RTS
TFR D,X                 ; X = SM header
LEAX 2,X    ; X = &states[0]
PSHS X                  ; save states[0] ptr on stack
LDX >ENEMY_SCRATCH_PTR  ; X = pool entry
LDA 13,X     ; current state
PULS X                  ; X = states[0] again
LDB #13
MUL
LEAX D,X                ; X = &states[current]
LDB 4,X        ; event count
BEQ FIRE_EVT_RTS
LEAX 5,X      ; X = first event pair
LDA >ENEMY_SCRATCH_X    ; event hash
FIRE_EVT_SCAN:
CMPA ,X
BEQ FIRE_EVT_MATCH
LEAX 2,X
DECB
BNE FIRE_EVT_SCAN
BRA FIRE_EVT_RTS
FIRE_EVT_MATCH:
LDB 1,X                 ; to_state_idx
STB >ENEMY_SCRATCH_X    ; save to_state_idx
LDX >ENEMY_SCRATCH_PTR  ; X = pool entry
STB 13,X     ; apply new state
; Look up new state record for action/decay
LDA 5,X
LDB 6,X
TFR D,X                 ; X = type header
LDA 5,X
LDB 6,X
TFR D,X                 ; X = SM header
LEAX 2,X    ; X = &states[0]
LDA >ENEMY_SCRATCH_X    ; to_state_idx
LDB #13
MUL
LEAX D,X                ; X = &states[to]
; Store action/decay into pool without LDY (VASM LDY extended mode bug workaround)
LDA 1,X
LDB 2,X
STD >ENEMY_SCRATCH_Y    ; save decay hi+lo in 2-byte scratch
LDA 0,X      ; action_idx
PSHS A                  ; save action on stack
LDX >ENEMY_SCRATCH_PTR  ; X = pool entry
PULS A
STA 7,X       ; update pool action
LDA >ENEMY_SCRATCH_Y
STA 14,X
LDA >ENEMY_SCRATCH_Y+1
STA 15,X
FIRE_EVT_RTS:
RTS

;**** PRINT_TEXT String Data ****
PRINT_TEXT_STR_67:
    FCC "C"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_78166382:
    FCC "ROUND"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_78726770:
    FCC "SCORE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_100361836:
    FCC "intro"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2073804707667:
    FCC "Henshoku"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2453707043877:
    FCC "WARNING!"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_62413928761410:
    FCC "GAME OVER"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_63323706877185:
    FCC "Game_Over"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_97774210848817:
    FCC "onSnowHit"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_104652296222070:
    FCC "world_1_1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1785516508540691:
    FCC "ALL CLEAR!"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1842954771884826:
    FCC "Boss_Intro"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_89062161292953211:
    FCC "init_screen"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_94739999784554063:
    FCC "player_die1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_94739999784554064:
    FCC "player_die2"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_94739999784554065:
    FCC "player_die3"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_94739999784554066:
    FCC "player_die4"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_94739999784698482:
    FCC "player_idle"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_94739999784744652:
    FCC "player_jump"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_94739999785112679:
    FCC "player_walk"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_97104923643965900:
    FCC "shot_normal"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1989933374265095120:
    FCC "LEVEL CLEAR!"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_9120385685437879118:
    FCC "PRESS A BUTTON"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_13399742582312315532:
    FCC "CONGRATULATIONS!"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17169778266052697977:
    FCC "BOSS INCOMING"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17825111777351717868:
    FCC "Yukidama-Ondo"
    FCB $80          ; Vectrex string terminator

; === CROSS-BANK USER FUNCTION TRAMPOLINES ===
TRAMP_try_launch_ball:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR try_launch_ball
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_try_shoot:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR try_shoot
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_update_player:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$01  ; switch to bank #1
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR update_player
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_update_snowballs:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$01  ; switch to bank #1
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR update_snowballs
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS

; === CONST ARRAY DATA (relocated to fixed bank - accessible from any bank) ===
ARRAY_THAW_TIMERS_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'ball_rolling' (8 elements, 2 bytes each)
ARRAY_BALL_ROLLING_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'ball_vx_arr' (8 elements, 2 bytes each)
ARRAY_BALL_VX_ARR_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'ball_vy_arr' (8 elements, 2 bytes each)
ARRAY_BALL_VY_ARR_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'ball_bounces' (8 elements, 2 bytes each)
ARRAY_BALL_BOUNCES_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'ball_collided' (8 elements, 2 bytes each)
ARRAY_BALL_COLLIDED_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7


;***************************************************************************
; MAIN PROGRAM (Bank #0)
;***************************************************************************

