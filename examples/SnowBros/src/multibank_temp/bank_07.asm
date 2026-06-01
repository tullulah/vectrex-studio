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
LEVEL_SCREEN_COUNT   EQU $C880+$71   ; Total Y screens partitioning the level (1 bytes)
LEVEL_BG_SCREENS_PTR EQU $C880+$72   ; Per-screen BG index ptr (3 bytes per screen) (2 bytes)
LEVEL_GP_SCREENS_PTR EQU $C880+$74   ; Per-screen GP index ptr (2 bytes)
LEVEL_FG_SCREENS_PTR EQU $C880+$76   ; Per-screen FG index ptr (2 bytes)
SLR_CUR_X            EQU $C880+$78   ; SHOW_LEVEL: tracked beam X for per-segment clipping (1 bytes)
DRAW_T1_SCALED       EQU $C880+$79   ; SHOW_LEVEL: effective T1 for current object (DRAW_SCALE * object_scale) (1 bytes)
LCOL_PX              EQU $C880+$7A   ; LEVEL_COLLISION player world_x input (16-bit) (2 bytes)
LCOL_BEST_Y          EQU $C880+$7C   ; LEVEL_COLLISION_Y best floor y found (16-bit signed) (2 bytes)
LCOL_PY              EQU $C880+$7E   ; LEVEL_COLLISION player_top (16-bit signed) (2 bytes)
LCOL_PHH             EQU $C880+$80   ; LEVEL_COLLISION player half_height (1 bytes)
LCOL_PHW             EQU $C880+$81   ; LEVEL_COLLISION_X player half_width (1 bytes)
LCOL_THW             EQU $C880+$82   ; LEVEL_COLLISION_X total half_width (player_hw + obj_hw scratch) (1 bytes)
LCOL_OBJ_Y           EQU $C880+$83   ; LEVEL_COLLISION_Y current object world_y (16-bit) (2 bytes)
LCOL_LOCAL_PX        EQU $C880+$85   ; LEVEL_COLLISION_Y player_x in object-local coords (16-bit) (2 bytes)
LCOL_OBJ_CNT         EQU $C880+$87   ; LEVEL_COLLISION_Y GP objects remaining (1 bytes)
LCOL_SEG_CNT         EQU $C880+$88   ; LEVEL_COLLISION_Y mesh floor segments remaining (1 bytes)
ENEMY_POOL           EQU $C880+$89   ; Enemy instances pool (Phase 2 wander: +18 sub_state, +19 cur_area_idx, +20 idle_timer, +21 trans_type, +22..23 target_x, +24..25 vy/from_x, +26 feet_offset × N) (280 bytes)
ENEMY_LOOP_IDX       EQU $C880+$1A1   ; Enemy loop counter (1 bytes)
ENEMY_COUNT          EQU $C880+$1A2   ; Active enemy count (1 bytes)
ENEMY_SCRATCH_PTR    EQU $C880+$1A3   ; Scratch pointer for enemy iteration (2 bytes)
ENEMY_SCRATCH_X      EQU $C880+$1A5   ; Enemy scratch X (2 bytes)
ENEMY_SCRATCH_Y      EQU $C880+$1A7   ; Enemy scratch Y (2 bytes)
ANIM_ENEMY_ENEMY1_WALK_STATE EQU $C880+$1A9   ; Enemy 'enemy1' action 'walk' animation state (frame_idx, ticks_left) (2 bytes)
ANIM_ENEMY_FROG_WALK_STATE EQU $C880+$1AB   ; Enemy 'frog' action 'walk' animation state (frame_idx, ticks_left) (2 bytes)
ANIM_ENEMY_TITCHI_WALK_STATE EQU $C880+$1AD   ; Enemy 'titchi' action 'walk' animation state (frame_idx, ticks_left) (2 bytes)
ANIM_ENEMY_YELLOW_TROLL_WALK_STATE EQU $C880+$1AF   ; Enemy 'yellow_troll' action 'walk' animation state (frame_idx, ticks_left) (2 bytes)
TEXT_SCALE_H         EQU $C880+$1B1   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$1B2   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
PT_BASE_X            EQU $C880+$1B3   ; PRINT_TEXT: current char origin X (signed byte) (1 bytes)
PT_BASE_Y            EQU $C880+$1B4   ; PRINT_TEXT: text baseline Y (signed byte) (1 bytes)
PT_CUR_X             EQU $C880+$1B5   ; PRINT_TEXT: current beam X for delta computation (1 bytes)
PT_CUR_Y             EQU $C880+$1B6   ; PRINT_TEXT: current beam Y for delta computation (1 bytes)
PT_GX                EQU $C880+$1B7   ; PRINT_TEXT: current stroke glyph X (0..4) (1 bytes)
PT_GY                EQU $C880+$1B8   ; PRINT_TEXT: current stroke glyph Y (0..6) (1 bytes)
PN_LAST_VAL          EQU $C880+$1B9   ; PRINT_NUMBER: last rendered numeric value (cache key) (2 bytes)
PN_LAST_VALID        EQU $C880+$1BB   ; PRINT_NUMBER: 1 if PN_LAST_VAL holds a valid render (1 bytes)
PN_LAST_X            EQU $C880+$1BC   ; PRINT_NUMBER: last rendered X (cache key) (1 bytes)
PN_LAST_Y            EQU $C880+$1BD   ; PRINT_NUMBER: last rendered Y (cache key) (1 bytes)
ANIM_PLAYER_WALK_STATE EQU $C880+$1BE   ; DRAW_ANIM state for PLAYER_WALK (frame_idx, ticks_left) (2 bytes)
DRAW_ANIM_MIRROR_X   EQU $C880+$1C0   ; DRAW_ANIM mirror X flag (0=normal, 1=flip) (1 bytes)
DRAW_ANIM_SCALE      EQU $C880+$1C1   ; DRAW_ANIM T1 scale ($7F=normal) (1 bytes)
DRAW_ANIM_SPEED_MUL  EQU $C880+$1C2   ; DRAW_ANIM tick multiplier (1=normal) (1 bytes)
DRAW_SCALE           EQU $C880+$1C3   ; Current T1 scale for Draw_Sync_List_At_With_Mirrors ($7F=normal) (1 bytes)
VAR_ARG0             EQU $C880+$1C4   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $C880+$1C6   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $C880+$1C8   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $C880+$1CA   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $C880+$1CC   ; Function argument 4 (16-bit) (2 bytes)
VAR_ARG5             EQU $C880+$1CE   ; Function argument 5 (16-bit) (2 bytes)
VAR_ARG6             EQU $C880+$1D0   ; Function argument 6 (16-bit) (2 bytes)
VAR_ARG7             EQU $C880+$1D2   ; Function argument 7 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $C880+$1D4   ; Current ROM bank ID (multibank tracking) (1 bytes)
VAR_FROG_BULLET_ACTIVE EQU $C880+$1D5   ; User variable: frog_bullet_active (2 bytes)
VAR_FROG_BULLET_X    EQU $C880+$1D7   ; User variable: frog_bullet_x (2 bytes)
VAR_FROG_BULLET_Y    EQU $C880+$1D9   ; User variable: frog_bullet_y (2 bytes)
VAR_FROG_BULLET_VX   EQU $C880+$1DB   ; User variable: frog_bullet_vx (2 bytes)
VAR_FROG_BULLET_VY   EQU $C880+$1DD   ; User variable: frog_bullet_vy (2 bytes)
VAR_FROG_BULLET_DIR  EQU $C880+$1DF   ; User variable: frog_bullet_dir (2 bytes)
VAR_FROG_BULLET_MIRROR EQU $C880+$1E1   ; User variable: frog_bullet_mirror (2 bytes)
VAR_BALL_LAUNCHED    EQU $C880+$1E3   ; User variable: ball_launched (2 bytes)
VAR_GAME_STATE       EQU $C880+$1E5   ; User variable: game_state (2 bytes)
VAR_SCORE            EQU $C880+$1E7   ; User variable: score (2 bytes)
VAR_LIVES            EQU $C880+$1E9   ; User variable: lives (2 bytes)
VAR_CURRENT_LEVEL    EQU $C880+$1EB   ; User variable: current_level (2 bytes)
VAR_TIME_LEFT        EQU $C880+$1ED   ; User variable: time_left (2 bytes)
VAR_ENEMY_COUNT      EQU $C880+$1EF   ; User variable: enemy_count (2 bytes)
VAR_FRAME_TIMER      EQU $C880+$1F1   ; User variable: frame_timer (2 bytes)
VAR__T0              EQU $C880+$1F3   ; User variable: _t0 (2 bytes)
VAR__T1              EQU $C880+$1F5   ; User variable: _t1 (2 bytes)
VAR__T2              EQU $C880+$1F7   ; User variable: _t2 (2 bytes)
VAR__T3              EQU $C880+$1F9   ; User variable: _t3 (2 bytes)
VAR__T4              EQU $C880+$1FB   ; User variable: _t4 (2 bytes)
VAR__DBG_CTR         EQU $C880+$1FD   ; User variable: _dbg_ctr (2 bytes)
VAR_NEXT_IS_BOSS     EQU $C880+$1FF   ; User variable: next_is_boss (2 bytes)
VAR_SPAWN_FLOOR_Y    EQU $C880+$201   ; User variable: spawn_floor_y (2 bytes)
VAR_PLAYER_X         EQU $C880+$203   ; User variable: player_x (2 bytes)
VAR_PLAYER_Y         EQU $C880+$205   ; User variable: player_y (2 bytes)
VAR_PLAYER_VX        EQU $C880+$207   ; User variable: player_vx (2 bytes)
VAR_PLAYER_VY        EQU $C880+$209   ; User variable: player_vy (2 bytes)
VAR_PLAYER_FACING    EQU $C880+$20B   ; User variable: player_facing (2 bytes)
VAR_PLAYER_ON_GROUND EQU $C880+$20D   ; User variable: player_on_ground (2 bytes)
VAR_FLOOR_Y          EQU $C880+$20F   ; User variable: floor_y (2 bytes)
VAR_PREV_Y           EQU $C880+$211   ; User variable: prev_y (2 bytes)
VAR_PUSH_DX          EQU $C880+$213   ; User variable: push_dx (2 bytes)
VAR_CAMERA_Y         EQU $C880+$215   ; User variable: camera_y (2 bytes)
VAR_SCROLL_TARGET    EQU $C880+$217   ; User variable: scroll_target (2 bytes)
VAR_SHOOT_COOLDOWN   EQU $C880+$219   ; User variable: shoot_cooldown (2 bytes)
VAR_PLAYER_HAS_POWER EQU $C880+$21B   ; User variable: player_has_power (2 bytes)
VAR_SNOW_LIFE_MAX    EQU $C880+$21D   ; User variable: snow_life_max (2 bytes)
VAR_SNOW_SPAWN_VX    EQU $C880+$21F   ; User variable: snow_spawn_vx (2 bytes)
VAR_SNOW0_ACTIVE     EQU $C880+$221   ; User variable: snow0_active (2 bytes)
VAR_SNOW0_X          EQU $C880+$223   ; User variable: snow0_x (2 bytes)
VAR_SNOW0_Y          EQU $C880+$225   ; User variable: snow0_y (2 bytes)
VAR_SNOW0_VX         EQU $C880+$227   ; User variable: snow0_vx (2 bytes)
VAR_SNOW0_VY         EQU $C880+$229   ; User variable: snow0_vy (2 bytes)
VAR_SNOW0_LIFE       EQU $C880+$22B   ; User variable: snow0_life (2 bytes)
VAR_SNOW1_ACTIVE     EQU $C880+$22D   ; User variable: snow1_active (2 bytes)
VAR_SNOW1_X          EQU $C880+$22F   ; User variable: snow1_x (2 bytes)
VAR_SNOW1_Y          EQU $C880+$231   ; User variable: snow1_y (2 bytes)
VAR_SNOW1_VX         EQU $C880+$233   ; User variable: snow1_vx (2 bytes)
VAR_SNOW1_VY         EQU $C880+$235   ; User variable: snow1_vy (2 bytes)
VAR_SNOW1_LIFE       EQU $C880+$237   ; User variable: snow1_life (2 bytes)
VAR_SNOW2_ACTIVE     EQU $C880+$239   ; User variable: snow2_active (2 bytes)
VAR_SNOW2_X          EQU $C880+$23B   ; User variable: snow2_x (2 bytes)
VAR_SNOW2_Y          EQU $C880+$23D   ; User variable: snow2_y (2 bytes)
VAR_SNOW2_VX         EQU $C880+$23F   ; User variable: snow2_vx (2 bytes)
VAR_SNOW2_VY         EQU $C880+$241   ; User variable: snow2_vy (2 bytes)
VAR_SNOW2_LIFE       EQU $C880+$243   ; User variable: snow2_life (2 bytes)
VAR_ELAPSED          EQU $C880+$245   ; User variable: elapsed (2 bytes)
VAR_SCREEN_BOTTOM    EQU $C880+$247   ; User variable: screen_bottom (2 bytes)
VAR_SCREEN_FLOOR     EQU $C880+$249   ; User variable: screen_floor (2 bytes)
VAR_I                EQU $C880+$24B   ; User variable: i (2 bytes)
VAR_EX               EQU $C880+$24D   ; User variable: ex (2 bytes)
VAR_EY               EQU $C880+$24F   ; User variable: ey (2 bytes)
VAR_IDX              EQU $C880+$251   ; User variable: idx (2 bytes)
VAR_THW              EQU $C880+$253   ; User variable: thw (2 bytes)
VAR_THH              EQU $C880+$255   ; User variable: thh (2 bytes)
VAR_DX               EQU $C880+$257   ; User variable: dx (2 bytes)
VAR_DY               EQU $C880+$259   ; User variable: dy (2 bytes)
VAR_NEW_STATE        EQU $C880+$25B   ; User variable: new_state (2 bytes)
VAR_TICKS            EQU $C880+$25D   ; User variable: ticks (2 bytes)
VAR_THAW_TIMERS      EQU $C880+$25F   ; User variable: thaw_timers (2 bytes)
VAR_ST               EQU $C880+$261   ; User variable: st (2 bytes)
VAR_BALL_ROLLING     EQU $C880+$263   ; User variable: ball_rolling (2 bytes)
VAR_N                EQU $C880+$265   ; User variable: n (2 bytes)
VAR_SCREEN_MIN       EQU $C880+$267   ; User variable: screen_min (2 bytes)
VAR_SCREEN_MAX       EQU $C880+$269   ; User variable: screen_max (2 bytes)
VAR_BALL_VX_ARR      EQU $C880+$26B   ; User variable: ball_vx_arr (2 bytes)
VAR_BALL_VY_ARR      EQU $C880+$26D   ; User variable: ball_vy_arr (2 bytes)
VAR_BALL_BOUNCES     EQU $C880+$26F   ; User variable: ball_bounces (2 bytes)
VAR_BALL_COLLIDED    EQU $C880+$271   ; User variable: ball_collided (2 bytes)
VAR_FOUND            EQU $C880+$273   ; User variable: found (2 bytes)
VAR_PREV_BY          EQU $C880+$275   ; User variable: prev_by (2 bytes)
VAR_BX               EQU $C880+$277   ; User variable: bx (2 bytes)
VAR_BY               EQU $C880+$279   ; User variable: by (2 bytes)
VAR_FLOOR            EQU $C880+$27B   ; User variable: floor (2 bytes)
VAR_K                EQU $C880+$27D   ; User variable: k (2 bytes)
VAR_J                EQU $C880+$27F   ; User variable: j (2 bytes)
VAR_SKIP             EQU $C880+$281   ; User variable: skip (2 bytes)
VAR_EJX              EQU $C880+$283   ; User variable: ejx (2 bytes)
VAR_EJY              EQU $C880+$285   ; User variable: ejy (2 bytes)
VAR_OLD_VX           EQU $C880+$287   ; User variable: old_vx (2 bytes)
VAR_FROG_FIRE_TIMER  EQU $C880+$289   ; User variable: frog_fire_timer (2 bytes)
VAR_FROG_FIRE_DECAY  EQU $C880+$28B   ; User variable: frog_fire_decay (2 bytes)
VAR_FIRE_DOWN_FLAG   EQU $C880+$28D   ; User variable: fire_down_flag (2 bytes)
VAR_NEW_ST           EQU $C880+$28F   ; User variable: new_st (2 bytes)
VAR_FACE_LEFT        EQU $C880+$291   ; User variable: face_left (2 bytes)
VAR_SCR_Y            EQU $C880+$293   ; User variable: scr_y (2 bytes)
VAR_THAW_TIMERS_DATA EQU $C880+$295   ; Mutable array 'thaw_timers' data (8 elements x 2 bytes) (16 bytes)
VAR_FROG_FIRE_TIMER_DATA EQU $C880+$2A5   ; Mutable array 'frog_fire_timer' data (8 elements x 2 bytes) (16 bytes)
VAR_FROG_FIRE_DECAY_DATA EQU $C880+$2B5   ; Mutable array 'frog_fire_decay' data (8 elements x 2 bytes) (16 bytes)
VAR_BALL_ROLLING_DATA EQU $C880+$2C5   ; Mutable array 'ball_rolling' data (8 elements x 2 bytes) (16 bytes)
VAR_BALL_VX_ARR_DATA EQU $C880+$2D5   ; Mutable array 'ball_vx_arr' data (8 elements x 2 bytes) (16 bytes)
VAR_BALL_VY_ARR_DATA EQU $C880+$2E5   ; Mutable array 'ball_vy_arr' data (8 elements x 2 bytes) (16 bytes)
VAR_BALL_BOUNCES_DATA EQU $C880+$2F5   ; Mutable array 'ball_bounces' data (8 elements x 2 bytes) (16 bytes)
VAR_BALL_COLLIDED_DATA EQU $C880+$305   ; Mutable array 'ball_collided' data (8 elements x 2 bytes) (16 bytes)
PSG_MUSIC_PTR        EQU $C880+$315   ; PSG music data pointer (2 bytes)
PSG_MUSIC_START      EQU $C880+$317   ; PSG music start pointer (for loops) (2 bytes)
PSG_MUSIC_ACTIVE     EQU $C880+$319   ; PSG music active flag (1 bytes)
PSG_IS_PLAYING       EQU $C880+$31A   ; PSG playing flag (1 bytes)
PSG_DELAY_FRAMES     EQU $C880+$31B   ; PSG frame delay counter (1 bytes)
PSG_MUSIC_BANK       EQU $C880+$31C   ; PSG music bank ID (for multibank) (1 bytes)
SFX_PTR              EQU $C880+$31D   ; SFX data pointer (2 bytes)
SFX_ACTIVE           EQU $C880+$31F   ; SFX active flag (1 bytes)
SFX_BANK             EQU $C880+$320   ; SFX bank ID (for multibank) (1 bytes)
; Array length constants
ARRAY_THAW_TIMERS_LEN         EQU 8   ; 8 elements
ARRAY_FROG_FIRE_TIMER_LEN         EQU 8   ; 8 elements
ARRAY_FROG_FIRE_DECAY_LEN         EQU 8   ; 8 elements
ARRAY_BALL_ROLLING_LEN         EQU 8   ; 8 elements
ARRAY_BALL_VX_ARR_LEN         EQU 8   ; 8 elements
ARRAY_BALL_VY_ARR_LEN         EQU 8   ; 8 elements
ARRAY_BALL_BOUNCES_LEN         EQU 8   ; 8 elements
ARRAY_BALL_COLLIDED_LEN         EQU 8   ; 8 elements



; ================================================
    ; Runtime helpers (accessible from all banks)

;***************************************************************************
; ASSET LOOKUP TABLES (for banked asset access)
; Total: 36 vectors, 5 music, 1 sfx, 1 levels, 4 animations, 0 instruments, 4 enemies
;***************************************************************************

; Vector Asset Index Mapping:
;   0 = frog_fire_down (Bank #2)
;   1 = frog_fire_side (Bank #3)
;   2 = frog_fireball_down (Bank #3)
;   3 = frog_fireball_side (Bank #3)
;   4 = frog_idle (Bank #2)
;   5 = init_screen (Bank #1)
;   6 = platform1 (Bank #3)
;   7 = platform10 (Bank #3)
;   8 = platform11 (Bank #3)
;   9 = platform12 (Bank #3)
;   10 = platform13 (Bank #3)
;   11 = platform14 (Bank #3)
;   12 = platform15 (Bank #2)
;   13 = platform16 (Bank #2)
;   14 = platform17 (Bank #2)
;   15 = platform18 (Bank #3)
;   16 = platform19 (Bank #2)
;   17 = platform2 (Bank #3)
;   18 = platform20 (Bank #3)
;   19 = platform20_ (Bank #3)
;   20 = platform3 (Bank #3)
;   21 = platform4 (Bank #2)
;   22 = platform7 (Bank #2)
;   23 = platform8 (Bank #3)
;   24 = platform9 (Bank #3)
;   25 = player_die1 (Bank #2)
;   26 = player_die2 (Bank #2)
;   27 = player_die3 (Bank #2)
;   28 = player_die4 (Bank #2)
;   29 = player_idle (Bank #3)
;   30 = player_jump (Bank #2)
;   31 = titchi_ball (Bank #1)
;   32 = titchi_idle (Bank #3)
;   33 = titchi_snow1 (Bank #2)
;   34 = titchi_snow2 (Bank #2)
;   35 = yellow_troll_idle (Bank #2)

VECTOR_BANK_TABLE:
    FCB 2              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 2              ; Bank ID
    FCB 1              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 3              ; Bank ID
    FCB 2              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 3              ; Bank ID
    FCB 2              ; Bank ID
    FCB 1              ; Bank ID
    FCB 3              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID

VECTOR_ADDR_TABLE:
    FDB _FROG_FIRE_DOWN_VECTORS    ; frog_fire_down
    FDB _FROG_FIRE_SIDE_VECTORS    ; frog_fire_side
    FDB _FROG_FIREBALL_DOWN_VECTORS    ; frog_fireball_down
    FDB _FROG_FIREBALL_SIDE_VECTORS    ; frog_fireball_side
    FDB _FROG_IDLE_VECTORS    ; frog_idle
    FDB _INIT_SCREEN_VECTORS    ; init_screen
    FDB _PLATFORM1_VECTORS    ; platform1
    FDB _PLATFORM10_VECTORS    ; platform10
    FDB _PLATFORM11_VECTORS    ; platform11
    FDB _PLATFORM12_VECTORS    ; platform12
    FDB _PLATFORM13_VECTORS    ; platform13
    FDB _PLATFORM14_VECTORS    ; platform14
    FDB _PLATFORM15_VECTORS    ; platform15
    FDB _PLATFORM16_VECTORS    ; platform16
    FDB _PLATFORM17_VECTORS    ; platform17
    FDB _PLATFORM18_VECTORS    ; platform18
    FDB _PLATFORM19_VECTORS    ; platform19
    FDB _PLATFORM2_VECTORS    ; platform2
    FDB _PLATFORM20_VECTORS    ; platform20
    FDB _PLATFORM20__VECTORS    ; platform20_
    FDB _PLATFORM3_VECTORS    ; platform3
    FDB _PLATFORM4_VECTORS    ; platform4
    FDB _PLATFORM7_VECTORS    ; platform7
    FDB _PLATFORM8_VECTORS    ; platform8
    FDB _PLATFORM9_VECTORS    ; platform9
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
    FDB _YELLOW_TROLL_IDLE_VECTORS    ; yellow_troll_idle

; Music Asset Index Mapping:
;   0 = Boss_Intro (Bank #3)
;   1 = Game_Over (Bank #2)
;   2 = Henshoku (Bank #2)
;   3 = Yukidama-Ondo (Bank #1)
;   4 = intro (Bank #3)

MUSIC_BANK_TABLE:
    FCB 3              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 1              ; Bank ID
    FCB 3              ; Bank ID

MUSIC_ADDR_TABLE:
    FDB _BOSS_INTRO_MUSIC    ; Boss_Intro
    FDB _GAME_OVER_MUSIC    ; Game_Over
    FDB _HENSHOKU_MUSIC    ; Henshoku
    FDB _YUKIDAMA_ONDO_MUSIC    ; Yukidama-Ondo
    FDB _INTRO_MUSIC    ; intro

; SFX Asset Index Mapping:
;   0 = shot_normal (Bank #3)

SFX_BANK_TABLE:
    FCB 3              ; Bank ID

SFX_ADDR_TABLE:
    FDB _SHOT_NORMAL_SFX    ; shot_normal

; Level Asset Index Mapping:
;   0 = world_1_1 (Bank #2)

LEVEL_BANK_TABLE:
    FCB 2              ; Bank ID

LEVEL_ADDR_TABLE:
    FDB _WORLD_1_1_LEVEL    ; world_1_1

; Animation Asset Index Mapping:
;   0 = frog_walk (Bank #7)
;   1 = player_walk (Bank #7)
;   2 = titchi_walk (Bank #7)
;   3 = yellow_troll_walk (Bank #7)

ANIM_BANK_TABLE:
    FCB 7              ; Bank ID
    FCB 7              ; Bank ID
    FCB 7              ; Bank ID
    FCB 7              ; Bank ID

ANIM_ADDR_TABLE:
    FDB _ANIM_FROG_WALK    ; frog_walk
    FDB _ANIM_PLAYER_WALK    ; player_walk
    FDB _ANIM_TITCHI_WALK    ; titchi_walk
    FDB _ANIM_YELLOW_TROLL_WALK    ; yellow_troll_walk

; Enemy Asset Index Mapping (all in helpers bank for direct access):
;   0 = enemy1 (Bank #7)
;   1 = frog (Bank #7)
;   2 = titchi (Bank #7)
;   3 = yellow_troll (Bank #7)

ENEMY_BANK_TABLE:
    FCB 7              ; Bank ID (helpers bank — always mapped)
    FCB 7              ; Bank ID (helpers bank — always mapped)
    FCB 7              ; Bank ID (helpers bank — always mapped)
    FCB 7              ; Bank ID (helpers bank — always mapped)

ENEMY_ADDR_TABLE:
    FDB _ENEMY1_ENEMY    ; enemy1
    FDB _FROG_ENEMY    ; frog
    FDB _TITCHI_ENEMY    ; titchi
    FDB _YELLOW_TROLL_ENEMY    ; yellow_troll

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
    FCB $1D   ; action 0 (idle) sprite_idx ($FF=none)
    FCB 0                   ; sprite_type: 0=vec, 1=vanim
    FCB 0                   ; loop=false
    FCB $00                  ; action_flags (b0=shoot b1=down b2=mirror)
    FDB 0                    ; [4-5] no anim state (vec action)
    FCB $01   ; action 1 (walk) sprite_idx ($FF=none)
    FCB 1                   ; sprite_type: 0=vec, 1=vanim
    FCB 1                   ; loop=true
    FCB $00                  ; action_flags (b0=shoot b1=down b2=mirror)
    FDB ANIM_ENEMY_ENEMY1_WALK_STATE    ; [4-5] anim state RAM ptr (frame_idx, ticks_left)

; ---- Enemy type: FROG (multibank indexed) ----
_FROG_ACTION_IDLE EQU 0
_FROG_ACTION_WALK EQU 1
_FROG_ACTION_SNOW1 EQU 2
_FROG_ACTION_SNOW2 EQU 3
_FROG_ACTION_BALL EQU 4
_FROG_ACTION_FIRE_SIDE EQU 5
_FROG_ACTION_FIRE_DOWN EQU 6

_FROG_ENEMY:
    FCB 3          ; [0] hp
    FCB 40          ; [1] speed
    FDB 180          ; [2-3] action_duration
    FCB 7          ; [4] action_count
    FDB _FROG_SM      ; [5-6] state machine ptr

_FROG_ENEMY_ACTIONS:
    FCB $04   ; action 0 (idle) sprite_idx ($FF=none)
    FCB 0                   ; sprite_type: 0=vec, 1=vanim
    FCB 1                   ; loop=true
    FCB $00                  ; action_flags (b0=shoot b1=down b2=mirror)
    FDB 0                    ; [4-5] no anim state (vec action)
    FCB $00   ; action 1 (walk) sprite_idx ($FF=none)
    FCB 1                   ; sprite_type: 0=vec, 1=vanim
    FCB 1                   ; loop=true
    FCB $00                  ; action_flags (b0=shoot b1=down b2=mirror)
    FDB ANIM_ENEMY_FROG_WALK_STATE    ; [4-5] anim state RAM ptr (frame_idx, ticks_left)
    FCB $21   ; action 2 (snow1) sprite_idx ($FF=none)
    FCB 0                   ; sprite_type: 0=vec, 1=vanim
    FCB 1                   ; loop=true
    FCB $00                  ; action_flags (b0=shoot b1=down b2=mirror)
    FDB 0                    ; [4-5] no anim state (vec action)
    FCB $22   ; action 3 (snow2) sprite_idx ($FF=none)
    FCB 0                   ; sprite_type: 0=vec, 1=vanim
    FCB 1                   ; loop=true
    FCB $00                  ; action_flags (b0=shoot b1=down b2=mirror)
    FDB 0                    ; [4-5] no anim state (vec action)
    FCB $1F   ; action 4 (ball) sprite_idx ($FF=none)
    FCB 0                   ; sprite_type: 0=vec, 1=vanim
    FCB 1                   ; loop=true
    FCB $00                  ; action_flags (b0=shoot b1=down b2=mirror)
    FDB 0                    ; [4-5] no anim state (vec action)
    FCB $01   ; action 5 (fire_side) sprite_idx ($FF=none)
    FCB 0                   ; sprite_type: 0=vec, 1=vanim
    FCB 0                   ; loop=false
    FCB $05                  ; action_flags (b0=shoot b1=down b2=mirror)
    FDB 0                    ; [4-5] no anim state (vec action)
    FCB $00   ; action 6 (fire_down) sprite_idx ($FF=none)
    FCB 0                   ; sprite_type: 0=vec, 1=vanim
    FCB 0                   ; loop=false
    FCB $03                  ; action_flags (b0=shoot b1=down b2=mirror)
    FDB 0                    ; [4-5] no anim state (vec action)

; ---- State machine: FROG ----
_FROG_SM:
    FCB 6          ; state_count
    FCB 0          ; initial_state_idx
_FROG_SM_STATES:
    ; state 0 (normal) — fixed 13-byte record
    FCB $01   ; [0] action_idx ($FF=keep)
    FDB 0       ; [1-2] decay_frames
    FCB $FF   ; [3] decay_to ($FF=none)
    FCB 3       ; [4] on_event_count
    FCB $1C   ; [5] event hash 'onSnowHit'
    FCB 1       ; [6] -> state snow1
    FCB $FF   ; [7] event hash 'onFireSide'
    FCB 4       ; [8] -> state fire_side
    FCB $00   ; [9] event hash 'onFireDown'
    FCB 5       ; [10] -> state fire_down
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
    ; state 4 (fire_side) — fixed 13-byte record
    FCB $05   ; [0] action_idx ($FF=keep)
    FDB 40       ; [1-2] decay_frames
    FCB $00   ; [3] decay_to ($FF=none)
    FCB 0       ; [4] on_event_count
    FCB $FF   ; [5] unused event slot hash
    FCB $FF   ; [6] unused event slot to
    FCB $FF   ; [7] unused event slot hash
    FCB $FF   ; [8] unused event slot to
    FCB $FF   ; [9] unused event slot hash
    FCB $FF   ; [10] unused event slot to
    FCB $FF   ; [11] unused event slot hash
    FCB $FF   ; [12] unused event slot to
    ; state 5 (fire_down) — fixed 13-byte record
    FCB $06   ; [0] action_idx ($FF=keep)
    FDB 40       ; [1-2] decay_frames
    FCB $00   ; [3] decay_to ($FF=none)
    FCB 0       ; [4] on_event_count
    FCB $FF   ; [5] unused event slot hash
    FCB $FF   ; [6] unused event slot to
    FCB $FF   ; [7] unused event slot hash
    FCB $FF   ; [8] unused event slot to
    FCB $FF   ; [9] unused event slot hash
    FCB $FF   ; [10] unused event slot to
    FCB $FF   ; [11] unused event slot hash
    FCB $FF   ; [12] unused event slot to

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
    FCB $20   ; action 0 (idle) sprite_idx ($FF=none)
    FCB 0                   ; sprite_type: 0=vec, 1=vanim
    FCB 1                   ; loop=true
    FCB $00                  ; action_flags (b0=shoot b1=down b2=mirror)
    FDB 0                    ; [4-5] no anim state (vec action)
    FCB $02   ; action 1 (walk) sprite_idx ($FF=none)
    FCB 1                   ; sprite_type: 0=vec, 1=vanim
    FCB 1                   ; loop=true
    FCB $00                  ; action_flags (b0=shoot b1=down b2=mirror)
    FDB ANIM_ENEMY_TITCHI_WALK_STATE    ; [4-5] anim state RAM ptr (frame_idx, ticks_left)
    FCB $21   ; action 2 (snow1) sprite_idx ($FF=none)
    FCB 0                   ; sprite_type: 0=vec, 1=vanim
    FCB 1                   ; loop=true
    FCB $00                  ; action_flags (b0=shoot b1=down b2=mirror)
    FDB 0                    ; [4-5] no anim state (vec action)
    FCB $22   ; action 3 (snow2) sprite_idx ($FF=none)
    FCB 0                   ; sprite_type: 0=vec, 1=vanim
    FCB 1                   ; loop=true
    FCB $00                  ; action_flags (b0=shoot b1=down b2=mirror)
    FDB 0                    ; [4-5] no anim state (vec action)
    FCB $1F   ; action 4 (ball) sprite_idx ($FF=none)
    FCB 0                   ; sprite_type: 0=vec, 1=vanim
    FCB 1                   ; loop=true
    FCB $00                  ; action_flags (b0=shoot b1=down b2=mirror)
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

; ---- Enemy type: YELLOW_TROLL (multibank indexed) ----
_YELLOW_TROLL_ACTION_IDLE EQU 0
_YELLOW_TROLL_ACTION_WALK EQU 1
_YELLOW_TROLL_ACTION_SNOW1 EQU 2
_YELLOW_TROLL_ACTION_SNOW2 EQU 3
_YELLOW_TROLL_ACTION_BALL EQU 4

_YELLOW_TROLL_ENEMY:
    FCB 3          ; [0] hp
    FCB 40          ; [1] speed
    FDB 180          ; [2-3] action_duration
    FCB 5          ; [4] action_count
    FDB _YELLOW_TROLL_SM      ; [5-6] state machine ptr

_YELLOW_TROLL_ENEMY_ACTIONS:
    FCB $23   ; action 0 (idle) sprite_idx ($FF=none)
    FCB 0                   ; sprite_type: 0=vec, 1=vanim
    FCB 1                   ; loop=true
    FCB $00                  ; action_flags (b0=shoot b1=down b2=mirror)
    FDB 0                    ; [4-5] no anim state (vec action)
    FCB $03   ; action 1 (walk) sprite_idx ($FF=none)
    FCB 1                   ; sprite_type: 0=vec, 1=vanim
    FCB 1                   ; loop=true
    FCB $00                  ; action_flags (b0=shoot b1=down b2=mirror)
    FDB ANIM_ENEMY_YELLOW_TROLL_WALK_STATE    ; [4-5] anim state RAM ptr (frame_idx, ticks_left)
    FCB $21   ; action 2 (snow1) sprite_idx ($FF=none)
    FCB 0                   ; sprite_type: 0=vec, 1=vanim
    FCB 1                   ; loop=true
    FCB $00                  ; action_flags (b0=shoot b1=down b2=mirror)
    FDB 0                    ; [4-5] no anim state (vec action)
    FCB $22   ; action 3 (snow2) sprite_idx ($FF=none)
    FCB 0                   ; sprite_type: 0=vec, 1=vanim
    FCB 1                   ; loop=true
    FCB $00                  ; action_flags (b0=shoot b1=down b2=mirror)
    FDB 0                    ; [4-5] no anim state (vec action)
    FCB $1F   ; action 4 (ball) sprite_idx ($FF=none)
    FCB 0                   ; sprite_type: 0=vec, 1=vanim
    FCB 1                   ; loop=true
    FCB $00                  ; action_flags (b0=shoot b1=down b2=mirror)
    FDB 0                    ; [4-5] no anim state (vec action)

; ---- State machine: YELLOW_TROLL ----
_YELLOW_TROLL_SM:
    FCB 4          ; state_count
    FCB 0          ; initial_state_idx
_YELLOW_TROLL_SM_STATES:
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
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 3              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID

ASSET_ADDR_TABLE:
    FDB _YUKIDAMA_ONDO_MUSIC    ; Yukidama-Ondo
    FDB _INIT_SCREEN_VECTORS    ; init_screen
    FDB _TITCHI_BALL_VECTORS    ; titchi_ball
    FDB _TITCHI_IDLE_VECTORS    ; titchi_idle
    FDB _PLAYER_IDLE_VECTORS    ; player_idle
    FDB _FROG_FIRE_SIDE_VECTORS    ; frog_fire_side
    FDB _PLATFORM20_VECTORS    ; platform20
    FDB _PLATFORM20__VECTORS    ; platform20_
    FDB _BOSS_INTRO_MUSIC    ; Boss_Intro
    FDB _INTRO_MUSIC    ; intro
    FDB _FROG_FIREBALL_DOWN_VECTORS    ; frog_fireball_down
    FDB _FROG_FIREBALL_SIDE_VECTORS    ; frog_fireball_side
    FDB _PLATFORM8_VECTORS    ; platform8
    FDB _PLATFORM18_VECTORS    ; platform18
    FDB _PLATFORM2_VECTORS    ; platform2
    FDB _PLATFORM1_VECTORS    ; platform1
    FDB _PLATFORM3_VECTORS    ; platform3
    FDB _PLATFORM9_VECTORS    ; platform9
    FDB _SHOT_NORMAL_SFX    ; shot_normal
    FDB _PLATFORM10_VECTORS    ; platform10
    FDB _PLATFORM11_VECTORS    ; platform11
    FDB _PLATFORM12_VECTORS    ; platform12
    FDB _PLATFORM13_VECTORS    ; platform13
    FDB _PLATFORM14_VECTORS    ; platform14
    FDB _HENSHOKU_MUSIC    ; Henshoku
    FDB _WORLD_1_1_LEVEL    ; world_1_1
    FDB _PLATFORM4_VECTORS    ; platform4
    FDB _PLATFORM16_VECTORS    ; platform16
    FDB _PLATFORM17_VECTORS    ; platform17
    FDB _GAME_OVER_MUSIC    ; Game_Over
    FDB _PLATFORM15_VECTORS    ; platform15
    FDB _PLATFORM7_VECTORS    ; platform7
    FDB _YELLOW_TROLL_IDLE_VECTORS    ; yellow_troll_idle
    FDB _TITCHI_SNOW1_VECTORS    ; titchi_snow1
    FDB _FROG_FIRE_DOWN_VECTORS    ; frog_fire_down
    FDB _FROG_IDLE_VECTORS    ; frog_idle
    FDB _PLAYER_DIE1_VECTORS    ; player_die1
    FDB _TITCHI_SNOW2_VECTORS    ; titchi_snow2
    FDB _PLAYER_DIE2_VECTORS    ; player_die2
    FDB _PLAYER_DIE3_VECTORS    ; player_die3
    FDB _PLAYER_DIE4_VECTORS    ; player_die4
    FDB _PLAYER_JUMP_VECTORS    ; player_jump
    FDB _PLATFORM19_VECTORS    ; platform19

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
    ; Set up animation draw parameters (defaults: normal size, vanim timing).
    ; NOTE: do NOT clear DRAW_ANIM_MIRROR_X or MIRROR_X here — DRAW_ENEMIES
    ; sets them from POOL_DIR right before calling us, and clearing would wipe
    ; the patrol-direction mirror. DRAW_ANIM_RUNTIME re-applies DRAW_ANIM_MIRROR_X
    ; to MIRROR_X per frame, so just leave both alone.
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

; .vanim animation data: frog_walk (3 frames, loop=true, base_refs=0)

_ANIM_FROG_WALK:
    FCB 3               ; frame_count
    FCB 1               ; loop flag (1=loop, 0=freeze)
    FCB 0               ; base_ref_count
    FCB 4               ; frame_table_offset
    FDB _ANIM_FROG_WALK_F0       ; frame 0 pointer
    FDB _ANIM_FROG_WALK_F1       ; frame 1 pointer
    FDB _ANIM_FROG_WALK_F2       ; frame 2 pointer

_ANIM_FROG_WALK_F0:
    FCB 8               ; duration_ticks
    FCB 1               ; vec_ref_count
    FDB _FROG_WALK1_VECTORS      ; vec_ref: frog_walk1
    FCB 0               ; inline_path_count

_ANIM_FROG_WALK_F1:
    FCB 8               ; duration_ticks
    FCB 1               ; vec_ref_count
    FDB _FROG_WALK2_VECTORS      ; vec_ref: frog_walk2
    FCB 0               ; inline_path_count

_ANIM_FROG_WALK_F2:
    FCB 8               ; duration_ticks
    FCB 1               ; vec_ref_count
    FDB _FROG_WALK3_VECTORS      ; vec_ref: frog_walk3
    FCB 0               ; inline_path_count


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


; .vanim animation data: titchi_walk (4 frames, loop=true, base_refs=0)

_ANIM_TITCHI_WALK:
    FCB 4               ; frame_count
    FCB 1               ; loop flag (1=loop, 0=freeze)
    FCB 0               ; base_ref_count
    FCB 4               ; frame_table_offset
    FDB _ANIM_TITCHI_WALK_F0       ; frame 0 pointer
    FDB _ANIM_TITCHI_WALK_F1       ; frame 1 pointer
    FDB _ANIM_TITCHI_WALK_F2       ; frame 2 pointer
    FDB _ANIM_TITCHI_WALK_F3       ; frame 3 pointer

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

_ANIM_TITCHI_WALK_F3:
    FCB 8               ; duration_ticks
    FCB 1               ; vec_ref_count
    FDB _TITCHI_WALK4_VECTORS      ; vec_ref: titchi_walk4
    FCB 0               ; inline_path_count


; .vanim animation data: yellow_troll_walk (3 frames, loop=true, base_refs=0)

_ANIM_YELLOW_TROLL_WALK:
    FCB 3               ; frame_count
    FCB 1               ; loop flag (1=loop, 0=freeze)
    FCB 0               ; base_ref_count
    FCB 4               ; frame_table_offset
    FDB _ANIM_YELLOW_TROLL_WALK_F0       ; frame 0 pointer
    FDB _ANIM_YELLOW_TROLL_WALK_F1       ; frame 1 pointer
    FDB _ANIM_YELLOW_TROLL_WALK_F2       ; frame 2 pointer

_ANIM_YELLOW_TROLL_WALK_F0:
    FCB 16               ; duration_ticks
    FCB 1               ; vec_ref_count
    FDB _YELLOW_TROLL_WALK1_VECTORS      ; vec_ref: yellow_troll_walk1
    FCB 0               ; inline_path_count

_ANIM_YELLOW_TROLL_WALK_F1:
    FCB 16               ; duration_ticks
    FCB 1               ; vec_ref_count
    FDB _YELLOW_TROLL_WALK2_VECTORS      ; vec_ref: yellow_troll_walk2
    FCB 0               ; inline_path_count

_ANIM_YELLOW_TROLL_WALK_F2:
    FCB 16               ; duration_ticks
    FCB 1               ; vec_ref_count
    FDB _YELLOW_TROLL_WALK3_VECTORS      ; vec_ref: yellow_troll_walk3
    FCB 0               ; inline_path_count


; Vec files referenced by animations (helpers bank for cross-bank safety)

; Generated from player_walk1.vec (Malban Draw_Sync_List format)
; Total paths: 10, points: 29
; X bounds: min=-5, max=5, width=10
; Center: (0, 0)

_PLAYER_WALK1_WIDTH EQU 10
_PLAYER_WALK1_HALF_WIDTH EQU 5
_PLAYER_WALK1_HEIGHT EQU 18
_PLAYER_WALK1_HALF_HEIGHT EQU 9
_PLAYER_WALK1_CENTER_X EQU 0
_PLAYER_WALK1_CENTER_Y EQU 0

_PLAYER_WALK1_VECTORS:  ; Main entry (header + 10 path(s))
    FDB 10               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLAYER_WALK1_PATH0        ; pointer to path 0
    FDB _PLAYER_WALK1_PATH1        ; pointer to path 1
    FDB _PLAYER_WALK1_PATH2        ; pointer to path 2
    FDB _PLAYER_WALK1_PATH3        ; pointer to path 3
    FDB _PLAYER_WALK1_PATH4        ; pointer to path 4
    FDB _PLAYER_WALK1_PATH5        ; pointer to path 5
    FDB _PLAYER_WALK1_PATH6        ; pointer to path 6
    FDB _PLAYER_WALK1_PATH7        ; pointer to path 7
    FDB _PLAYER_WALK1_PATH8        ; pointer to path 8
    FDB _PLAYER_WALK1_PATH9        ; pointer to path 9

_PLAYER_WALK1_PATH0:    ; Path 0
    FCB 85              ; path0: intensity
    FCB $02,$01,0,0        ; path0: header (y=2, x=1)
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK1_PATH1:    ; Path 1
    FCB 85              ; path1: intensity
    FCB $00,$03,0,0        ; path1: header (y=0, x=3)
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK1_PATH2:    ; Path 2
    FCB 85              ; path2: intensity
    FCB $FD,$02,0,0        ; path2: header (y=-3, x=2)
    FCB $FF,$FA,$FF          ; flag=-1, dy=-6, dx=-1
    FCB $FF,$05,$FB          ; flag=-1, dy=5, dx=-5
    FCB 2                ; End marker (path complete)

_PLAYER_WALK1_PATH3:    ; Path 3
    FCB 85              ; path3: intensity
    FCB $FB,$FD,0,0        ; path3: header (y=-5, x=-3)
    FCB $FF,$FC,$FE          ; flag=-1, dy=-4, dx=-2
    FCB $FF,$02,$04          ; flag=-1, dy=2, dx=4
    FCB 2                ; End marker (path complete)

_PLAYER_WALK1_PATH4:    ; Path 4
    FCB 85              ; path4: intensity
    FCB $F7,$01,0,0        ; path4: header (y=-9, x=1)
    FCB $FF,$01,$04          ; flag=-1, dy=1, dx=4
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK1_PATH5:    ; Path 5
    FCB 85              ; path5: intensity
    FCB $FD,$FF,0,0        ; path5: header (y=-3, x=-1)
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$05,$02          ; flag=-1, dy=5, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK1_PATH6:    ; Path 6
    FCB 85              ; path6: intensity
    FCB $06,$FE,0,0        ; path6: header (y=6, x=-2)
    FCB $FF,$FC,$FF          ; flag=-1, dy=-4, dx=-1
    FCB $FF,$FE,$04          ; flag=-1, dy=-2, dx=4
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$05,$FD          ; flag=-1, dy=5, dx=-3
    FCB 2                ; End marker (path complete)

_PLAYER_WALK1_PATH7:    ; Path 7
    FCB 85              ; path7: intensity
    FCB $07,$01,0,0        ; path7: header (y=7, x=1)
    FCB $FF,$02,$FD          ; flag=-1, dy=2, dx=-3
    FCB 2                ; End marker (path complete)

_PLAYER_WALK1_PATH8:    ; Path 8
    FCB 85              ; path8: intensity
    FCB $09,$FE,0,0        ; path8: header (y=9, x=-2)
    FCB $FF,$FF,$FF          ; flag=-1, dy=-1, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK1_PATH9:    ; Path 9
    FCB 85              ; path9: intensity
    FCB $06,$FE,0,0        ; path9: header (y=6, x=-2)
    FCB $FF,$01,$03          ; flag=-1, dy=1, dx=3
    FCB 2                ; End marker (path complete)

; Generated from player_walk3.vec (Malban Draw_Sync_List format)
; Total paths: 9, points: 31
; X bounds: min=-7, max=6, width=13
; Center: (0, 0)

_PLAYER_WALK3_WIDTH EQU 13
_PLAYER_WALK3_HALF_WIDTH EQU 6
_PLAYER_WALK3_HEIGHT EQU 19
_PLAYER_WALK3_HALF_HEIGHT EQU 9
_PLAYER_WALK3_CENTER_X EQU 0
_PLAYER_WALK3_CENTER_Y EQU 0

_PLAYER_WALK3_VECTORS:  ; Main entry (header + 6 path(s))
    FDB 6               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLAYER_WALK3_PATH0        ; pointer to path 0
    FDB _PLAYER_WALK3_PATH1        ; pointer to path 1
    FDB _PLAYER_WALK3_PATH2        ; pointer to path 2
    FDB _PLAYER_WALK3_PATH3        ; pointer to path 3
    FDB _PLAYER_WALK3_PATH4        ; pointer to path 4
    FDB _PLAYER_WALK3_PATH5        ; pointer to path 5

_PLAYER_WALK3_PATH0:    ; Path 0
    FCB 85              ; path0: intensity
    FCB $02,$00,0,0        ; path0: header (y=2, x=0)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB 2                ; End marker (path complete)

_PLAYER_WALK3_PATH1:    ; Path 1
    FCB 85              ; path1: intensity
    FCB $FF,$03,0,0        ; path1: header (y=-1, x=3)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK3_PATH2:    ; Path 2
    FCB 85              ; path2: intensity
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
    FCB 85              ; path3: intensity
    FCB $05,$FD,0,0        ; path3: header (y=5, x=-3)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK3_PATH4:    ; Path 4
    FCB 85              ; path4: intensity
    FCB $09,$FE,0,0        ; path4: header (y=9, x=-2)
    FCB $FF,$FE,$03          ; flag=-1, dy=-2, dx=3
    FCB 2                ; End marker (path complete)

_PLAYER_WALK3_PATH5:    ; Path 5
    FCB 85              ; path5: intensity
    FCB $07,$01,0,0        ; path5: header (y=7, x=1)
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

_TITCHI_WALK3_VECTORS:  ; Main entry (header + 10 path(s))
    FDB 10               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
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
    FCB $FA,$01,0,0        ; path2: header (y=-6, x=1)
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB 2                ; End marker (path complete)

_TITCHI_WALK3_PATH3:    ; Path 3
    FCB 85              ; path3: intensity
    FCB $00,$05,0,0        ; path3: header (y=0, x=5)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$FF,$FA          ; flag=-1, dy=-1, dx=-6
    FCB $FF,$FF,$03          ; flag=-1, dy=-1, dx=3
    FCB $FF,$FE,$FA          ; flag=-1, dy=-2, dx=-6
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$06,$FE          ; flag=-1, dy=6, dx=-2
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB 2                ; End marker (path complete)

_TITCHI_WALK3_PATH4:    ; Path 4
    FCB 85              ; path4: intensity
    FCB $04,$FE,0,0        ; path4: header (y=4, x=-2)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB 2                ; End marker (path complete)

_TITCHI_WALK3_PATH5:    ; Path 5
    FCB 85              ; path5: intensity
    FCB $06,$FF,0,0        ; path5: header (y=6, x=-1)
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB 2                ; End marker (path complete)

_TITCHI_WALK3_PATH6:    ; Path 6
    FCB 85              ; path6: intensity
    FCB $04,$04,0,0        ; path6: header (y=4, x=4)
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_TITCHI_WALK3_PATH7:    ; Path 7
    FCB 85              ; path7: intensity
    FCB $04,$02,0,0        ; path7: header (y=4, x=2)
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB 2                ; End marker (path complete)

_TITCHI_WALK3_PATH8:    ; Path 8
    FCB 85              ; path8: intensity
    FCB $04,$04,0,0        ; path8: header (y=4, x=4)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB 2                ; End marker (path complete)

_TITCHI_WALK3_PATH9:    ; Path 9
    FCB 85              ; path9: intensity
    FCB $02,$05,0,0        ; path9: header (y=2, x=5)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB 2                ; End marker (path complete)

; Generated from yellow_troll_walk1.vec (Malban Draw_Sync_List format)
; Total paths: 9, points: 51
; X bounds: min=-9, max=7, width=16
; Center: (-1, -2)

_YELLOW_TROLL_WALK1_WIDTH EQU 16
_YELLOW_TROLL_WALK1_HALF_WIDTH EQU 8
_YELLOW_TROLL_WALK1_HEIGHT EQU 18
_YELLOW_TROLL_WALK1_HALF_HEIGHT EQU 9
_YELLOW_TROLL_WALK1_CENTER_X EQU -1
_YELLOW_TROLL_WALK1_CENTER_Y EQU -2

_YELLOW_TROLL_WALK1_VECTORS:  ; Main entry (header + 9 path(s))
    FDB 9               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _YELLOW_TROLL_WALK1_PATH0        ; pointer to path 0
    FDB _YELLOW_TROLL_WALK1_PATH1        ; pointer to path 1
    FDB _YELLOW_TROLL_WALK1_PATH2        ; pointer to path 2
    FDB _YELLOW_TROLL_WALK1_PATH3        ; pointer to path 3
    FDB _YELLOW_TROLL_WALK1_PATH4        ; pointer to path 4
    FDB _YELLOW_TROLL_WALK1_PATH5        ; pointer to path 5
    FDB _YELLOW_TROLL_WALK1_PATH6        ; pointer to path 6
    FDB _YELLOW_TROLL_WALK1_PATH7        ; pointer to path 7
    FDB _YELLOW_TROLL_WALK1_PATH8        ; pointer to path 8

_YELLOW_TROLL_WALK1_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $03,$00,0,0        ; path0: header (y=3, x=0)
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$FD          ; flag=-1, dy=-2, dx=-3
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$FC,$FF          ; flag=-1, dy=-4, dx=-1
    FCB $FF,$FF,$03          ; flag=-1, dy=-1, dx=3
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB 2                ; End marker (path complete)

_YELLOW_TROLL_WALK1_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $FB,$FB,0,0        ; path1: header (y=-5, x=-5)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$03,$04          ; flag=-1, dy=3, dx=4
    FCB 2                ; End marker (path complete)

_YELLOW_TROLL_WALK1_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $FB,$00,0,0        ; path2: header (y=-5, x=0)
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB 2                ; End marker (path complete)

_YELLOW_TROLL_WALK1_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $F9,$FE,0,0        ; path3: header (y=-7, x=-2)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$02,$FA          ; flag=-1, dy=2, dx=-6
    FCB $FF,$00,$01          ; flag=-1, dy=0, dx=1
    FCB 2                ; End marker (path complete)

_YELLOW_TROLL_WALK1_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $00,$FF,0,0        ; path4: header (y=0, x=-1)
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$FC,$04          ; flag=-1, dy=-4, dx=4
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$FE,$04          ; flag=-1, dy=-2, dx=4
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$01,$FF          ; flag=-1, dy=1, dx=-1
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB $FF,$FE,$FC          ; flag=-1, dy=-2, dx=-4
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB 2                ; End marker (path complete)

_YELLOW_TROLL_WALK1_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $03,$00,0,0        ; path5: header (y=3, x=0)
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$00,$01          ; flag=-1, dy=0, dx=1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB 2                ; End marker (path complete)

_YELLOW_TROLL_WALK1_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $03,$07,0,0        ; path6: header (y=3, x=7)
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB 2                ; End marker (path complete)

_YELLOW_TROLL_WALK1_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $01,$06,0,0        ; path7: header (y=1, x=6)
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB 2                ; End marker (path complete)

_YELLOW_TROLL_WALK1_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $01,$02,0,0        ; path8: header (y=1, x=2)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
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

_TITCHI_WALK2_VECTORS:  ; Main entry (header + 10 path(s))
    FDB 10               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
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
    FCB $F9,$01,0,0        ; path2: header (y=-7, x=1)
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB $FF,$02,$FD          ; flag=-1, dy=2, dx=-3
    FCB 2                ; End marker (path complete)

_TITCHI_WALK2_PATH3:    ; Path 3
    FCB 85              ; path3: intensity
    FCB $FF,$05,0,0        ; path3: header (y=-1, x=5)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$FF,$FA          ; flag=-1, dy=-1, dx=-6
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$06,$FE          ; flag=-1, dy=6, dx=-2
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB 2                ; End marker (path complete)

_TITCHI_WALK2_PATH4:    ; Path 4
    FCB 85              ; path4: intensity
    FCB $03,$FE,0,0        ; path4: header (y=3, x=-2)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB 2                ; End marker (path complete)

_TITCHI_WALK2_PATH5:    ; Path 5
    FCB 85              ; path5: intensity
    FCB $05,$FF,0,0        ; path5: header (y=5, x=-1)
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB 2                ; End marker (path complete)

_TITCHI_WALK2_PATH6:    ; Path 6
    FCB 85              ; path6: intensity
    FCB $03,$04,0,0        ; path6: header (y=3, x=4)
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_TITCHI_WALK2_PATH7:    ; Path 7
    FCB 85              ; path7: intensity
    FCB $03,$02,0,0        ; path7: header (y=3, x=2)
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB 2                ; End marker (path complete)

_TITCHI_WALK2_PATH8:    ; Path 8
    FCB 85              ; path8: intensity
    FCB $03,$04,0,0        ; path8: header (y=3, x=4)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB 2                ; End marker (path complete)

_TITCHI_WALK2_PATH9:    ; Path 9
    FCB 85              ; path9: intensity
    FCB $01,$05,0,0        ; path9: header (y=1, x=5)
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB 2                ; End marker (path complete)

; Generated from frog_walk3.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 33
; X bounds: min=-7, max=7, width=14
; Center: (0, 0)

_FROG_WALK3_WIDTH EQU 14
_FROG_WALK3_HALF_WIDTH EQU 7
_FROG_WALK3_HEIGHT EQU 19
_FROG_WALK3_HALF_HEIGHT EQU 9
_FROG_WALK3_CENTER_X EQU 0
_FROG_WALK3_CENTER_Y EQU 0

_FROG_WALK3_VECTORS:  ; Main entry (header + 4 path(s))
    FDB 4               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _FROG_WALK3_PATH0        ; pointer to path 0
    FDB _FROG_WALK3_PATH1        ; pointer to path 1
    FDB _FROG_WALK3_PATH2        ; pointer to path 2
    FDB _FROG_WALK3_PATH3        ; pointer to path 3

_FROG_WALK3_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $01,$FF,0,0        ; path0: header (y=1, x=-1)
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB 2                ; End marker (path complete)

_FROG_WALK3_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $04,$FF,0,0        ; path1: header (y=4, x=-1)
    FCB $FF,$FD,$04          ; flag=-1, dy=-3, dx=4
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB 2                ; End marker (path complete)

_FROG_WALK3_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $FA,$FF,0,0        ; path2: header (y=-6, x=-1)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$01,$FF          ; flag=-1, dy=1, dx=-1
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB $FF,$04,$FD          ; flag=-1, dy=4, dx=-3
    FCB $FF,$04,$01          ; flag=-1, dy=4, dx=1
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$03,$03          ; flag=-1, dy=3, dx=3
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB $FF,$FD,$04          ; flag=-1, dy=-3, dx=4
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB 2                ; End marker (path complete)

_FROG_WALK3_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $07,$04,0,0        ; path3: header (y=7, x=4)
    FCB $FF,$FF,$01          ; flag=-1, dy=-1, dx=1
    FCB 2                ; End marker (path complete)

; Generated from yellow_troll_walk3.vec (Malban Draw_Sync_List format)
; Total paths: 9, points: 48
; X bounds: min=-7, max=9, width=16
; Center: (1, -2)

_YELLOW_TROLL_WALK3_WIDTH EQU 16
_YELLOW_TROLL_WALK3_HALF_WIDTH EQU 8
_YELLOW_TROLL_WALK3_HEIGHT EQU 18
_YELLOW_TROLL_WALK3_HALF_HEIGHT EQU 9
_YELLOW_TROLL_WALK3_CENTER_X EQU 1
_YELLOW_TROLL_WALK3_CENTER_Y EQU -2

_YELLOW_TROLL_WALK3_VECTORS:  ; Main entry (header + 9 path(s))
    FDB 9               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _YELLOW_TROLL_WALK3_PATH0        ; pointer to path 0
    FDB _YELLOW_TROLL_WALK3_PATH1        ; pointer to path 1
    FDB _YELLOW_TROLL_WALK3_PATH2        ; pointer to path 2
    FDB _YELLOW_TROLL_WALK3_PATH3        ; pointer to path 3
    FDB _YELLOW_TROLL_WALK3_PATH4        ; pointer to path 4
    FDB _YELLOW_TROLL_WALK3_PATH5        ; pointer to path 5
    FDB _YELLOW_TROLL_WALK3_PATH6        ; pointer to path 6
    FDB _YELLOW_TROLL_WALK3_PATH7        ; pointer to path 7
    FDB _YELLOW_TROLL_WALK3_PATH8        ; pointer to path 8

_YELLOW_TROLL_WALK3_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $01,$FE,0,0        ; path0: header (y=1, x=-2)
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FB,$01          ; flag=-1, dy=-5, dx=1
    FCB $FF,$04,$02          ; flag=-1, dy=4, dx=2
    FCB $FF,$FD,$05          ; flag=-1, dy=-3, dx=5
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB $FF,$01,$02          ; flag=-1, dy=1, dx=2
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$FE,$FD          ; flag=-1, dy=-2, dx=-3
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_YELLOW_TROLL_WALK3_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $03,$00,0,0        ; path1: header (y=3, x=0)
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB $FF,$FC,$FE          ; flag=-1, dy=-4, dx=-2
    FCB $FF,$FB,$FF          ; flag=-1, dy=-5, dx=-1
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB 2                ; End marker (path complete)

_YELLOW_TROLL_WALK3_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $FC,$F9,0,0        ; path2: header (y=-4, x=-7)
    FCB $FF,$FF,$FF          ; flag=-1, dy=-1, dx=-1
    FCB $FF,$FC,$02          ; flag=-1, dy=-4, dx=2
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB 2                ; End marker (path complete)

_YELLOW_TROLL_WALK3_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $FB,$FA,0,0        ; path3: header (y=-5, x=-6)
    FCB $FF,$FF,$01          ; flag=-1, dy=-1, dx=1
    FCB $FF,$03,$03          ; flag=-1, dy=3, dx=3
    FCB 2                ; End marker (path complete)

_YELLOW_TROLL_WALK3_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $FD,$02,0,0        ; path4: header (y=-3, x=2)
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_YELLOW_TROLL_WALK3_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $03,$00,0,0        ; path5: header (y=3, x=0)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB 2                ; End marker (path complete)

_YELLOW_TROLL_WALK3_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $03,$06,0,0        ; path6: header (y=3, x=6)
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$01,$02          ; flag=-1, dy=1, dx=2
    FCB 2                ; End marker (path complete)

_YELLOW_TROLL_WALK3_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $03,$04,0,0        ; path7: header (y=3, x=4)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB 2                ; End marker (path complete)

_YELLOW_TROLL_WALK3_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $FB,$02,0,0        ; path8: header (y=-5, x=2)
    FCB $FF,$FD,$06          ; flag=-1, dy=-3, dx=6
    FCB $FF,$03,$FE          ; flag=-1, dy=3, dx=-2
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB 2                ; End marker (path complete)

; Generated from player_walk4.vec (Malban Draw_Sync_List format)
; Total paths: 10, points: 33
; X bounds: min=-7, max=6, width=13
; Center: (0, 0)

_PLAYER_WALK4_WIDTH EQU 13
_PLAYER_WALK4_HALF_WIDTH EQU 6
_PLAYER_WALK4_HEIGHT EQU 19
_PLAYER_WALK4_HALF_HEIGHT EQU 9
_PLAYER_WALK4_CENTER_X EQU 0
_PLAYER_WALK4_CENTER_Y EQU 0

_PLAYER_WALK4_VECTORS:  ; Main entry (header + 10 path(s))
    FDB 10               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLAYER_WALK4_PATH0        ; pointer to path 0
    FDB _PLAYER_WALK4_PATH1        ; pointer to path 1
    FDB _PLAYER_WALK4_PATH2        ; pointer to path 2
    FDB _PLAYER_WALK4_PATH3        ; pointer to path 3
    FDB _PLAYER_WALK4_PATH4        ; pointer to path 4
    FDB _PLAYER_WALK4_PATH5        ; pointer to path 5
    FDB _PLAYER_WALK4_PATH6        ; pointer to path 6
    FDB _PLAYER_WALK4_PATH7        ; pointer to path 7
    FDB _PLAYER_WALK4_PATH8        ; pointer to path 8
    FDB _PLAYER_WALK4_PATH9        ; pointer to path 9

_PLAYER_WALK4_PATH0:    ; Path 0
    FCB 85              ; path0: intensity
    FCB $02,$00,0,0        ; path0: header (y=2, x=0)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB 2                ; End marker (path complete)

_PLAYER_WALK4_PATH1:    ; Path 1
    FCB 85              ; path1: intensity
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
    FCB 85              ; path2: intensity
    FCB $FE,$FE,0,0        ; path2: header (y=-2, x=-2)
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$03,$03          ; flag=-1, dy=3, dx=3
    FCB 2                ; End marker (path complete)

_PLAYER_WALK4_PATH3:    ; Path 3
    FCB 85              ; path3: intensity
    FCB $06,$FE,0,0        ; path3: header (y=6, x=-2)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK4_PATH4:    ; Path 4
    FCB 85              ; path4: intensity
    FCB $06,$FE,0,0        ; path4: header (y=6, x=-2)
    FCB $FF,$FB,$FF          ; flag=-1, dy=-5, dx=-1
    FCB $FF,$FF,$05          ; flag=-1, dy=-1, dx=5
    FCB $FF,$05,$02          ; flag=-1, dy=5, dx=2
    FCB $FF,$02,$FD          ; flag=-1, dy=2, dx=-3
    FCB 2                ; End marker (path complete)

_PLAYER_WALK4_PATH5:    ; Path 5
    FCB 85              ; path5: intensity
    FCB $07,$01,0,0        ; path5: header (y=7, x=1)
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK4_PATH6:    ; Path 6
    FCB 85              ; path6: intensity
    FCB $09,$FF,0,0        ; path6: header (y=9, x=-1)
    FCB $FF,$FF,$FF          ; flag=-1, dy=-1, dx=-1
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK4_PATH7:    ; Path 7
    FCB 85              ; path7: intensity
    FCB $06,$FE,0,0        ; path7: header (y=6, x=-2)
    FCB $FF,$01,$03          ; flag=-1, dy=1, dx=3
    FCB 2                ; End marker (path complete)

_PLAYER_WALK4_PATH8:    ; Path 8
    FCB 85              ; path8: intensity
    FCB $07,$01,0,0        ; path8: header (y=7, x=1)
    FCB $FF,$FF,$FD          ; flag=-1, dy=-1, dx=-3
    FCB 2                ; End marker (path complete)

_PLAYER_WALK4_PATH9:    ; Path 9
    FCB 85              ; path9: intensity
    FCB $FF,$03,0,0        ; path9: header (y=-1, x=3)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

; Generated from player_walk2.vec (Malban Draw_Sync_List format)
; Total paths: 12, points: 32
; X bounds: min=-5, max=5, width=10
; Center: (0, 0)

_PLAYER_WALK2_WIDTH EQU 10
_PLAYER_WALK2_HALF_WIDTH EQU 5
_PLAYER_WALK2_HEIGHT EQU 18
_PLAYER_WALK2_HALF_HEIGHT EQU 9
_PLAYER_WALK2_CENTER_X EQU 0
_PLAYER_WALK2_CENTER_Y EQU 0

_PLAYER_WALK2_VECTORS:  ; Main entry (header + 11 path(s))
    FDB 11               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLAYER_WALK2_PATH0        ; pointer to path 0
    FDB _PLAYER_WALK2_PATH1        ; pointer to path 1
    FDB _PLAYER_WALK2_PATH2        ; pointer to path 2
    FDB _PLAYER_WALK2_PATH3        ; pointer to path 3
    FDB _PLAYER_WALK2_PATH4        ; pointer to path 4
    FDB _PLAYER_WALK2_PATH5        ; pointer to path 5
    FDB _PLAYER_WALK2_PATH6        ; pointer to path 6
    FDB _PLAYER_WALK2_PATH7        ; pointer to path 7
    FDB _PLAYER_WALK2_PATH8        ; pointer to path 8
    FDB _PLAYER_WALK2_PATH9        ; pointer to path 9
    FDB _PLAYER_WALK2_PATH10        ; pointer to path 10

_PLAYER_WALK2_PATH0:    ; Path 0
    FCB 85              ; path0: intensity
    FCB $02,$01,0,0        ; path0: header (y=2, x=1)
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK2_PATH1:    ; Path 1
    FCB 85              ; path1: intensity
    FCB $00,$03,0,0        ; path1: header (y=0, x=3)
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK2_PATH2:    ; Path 2
    FCB 85              ; path2: intensity
    FCB $FC,$02,0,0        ; path2: header (y=-4, x=2)
    FCB $FF,$FB,$FF          ; flag=-1, dy=-5, dx=-1
    FCB $FF,$05,$FB          ; flag=-1, dy=5, dx=-5
    FCB 2                ; End marker (path complete)

_PLAYER_WALK2_PATH3:    ; Path 3
    FCB 85              ; path3: intensity
    FCB $FB,$FD,0,0        ; path3: header (y=-5, x=-3)
    FCB $FF,$FC,$FE          ; flag=-1, dy=-4, dx=-2
    FCB $FF,$02,$04          ; flag=-1, dy=2, dx=4
    FCB 2                ; End marker (path complete)

_PLAYER_WALK2_PATH4:    ; Path 4
    FCB 85              ; path4: intensity
    FCB $F7,$01,0,0        ; path4: header (y=-9, x=1)
    FCB $FF,$01,$04          ; flag=-1, dy=1, dx=4
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK2_PATH5:    ; Path 5
    FCB 85              ; path5: intensity
    FCB $FD,$FF,0,0        ; path5: header (y=-3, x=-1)
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$05,$02          ; flag=-1, dy=5, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK2_PATH6:    ; Path 6
    FCB 85              ; path6: intensity
    FCB $06,$FE,0,0        ; path6: header (y=6, x=-2)
    FCB $FF,$FC,$FF          ; flag=-1, dy=-4, dx=-1
    FCB $FF,$FE,$04          ; flag=-1, dy=-2, dx=4
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$05,$FD          ; flag=-1, dy=5, dx=-3
    FCB 2                ; End marker (path complete)

_PLAYER_WALK2_PATH7:    ; Path 7
    FCB 85              ; path7: intensity
    FCB $07,$01,0,0        ; path7: header (y=7, x=1)
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK2_PATH8:    ; Path 8
    FCB 85              ; path8: intensity
    FCB $09,$FF,0,0        ; path8: header (y=9, x=-1)
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK2_PATH9:    ; Path 9
    FCB 85              ; path9: intensity
    FCB $06,$FE,0,0        ; path9: header (y=6, x=-2)
    FCB $FF,$01,$03          ; flag=-1, dy=1, dx=3
    FCB 2                ; End marker (path complete)

_PLAYER_WALK2_PATH10:    ; Path 10
    FCB 85              ; path10: intensity
    FCB $07,$01,0,0        ; path10: header (y=7, x=1)
    FCB $FF,$FF,$FD          ; flag=-1, dy=-1, dx=-3
    FCB 2                ; End marker (path complete)

; Generated from yellow_troll_walk2.vec (Malban Draw_Sync_List format)
; Total paths: 9, points: 48
; X bounds: min=-6, max=9, width=15
; Center: (1, -2)

_YELLOW_TROLL_WALK2_WIDTH EQU 15
_YELLOW_TROLL_WALK2_HALF_WIDTH EQU 7
_YELLOW_TROLL_WALK2_HEIGHT EQU 18
_YELLOW_TROLL_WALK2_HALF_HEIGHT EQU 9
_YELLOW_TROLL_WALK2_CENTER_X EQU 1
_YELLOW_TROLL_WALK2_CENTER_Y EQU -2

_YELLOW_TROLL_WALK2_VECTORS:  ; Main entry (header + 9 path(s))
    FDB 9               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _YELLOW_TROLL_WALK2_PATH0        ; pointer to path 0
    FDB _YELLOW_TROLL_WALK2_PATH1        ; pointer to path 1
    FDB _YELLOW_TROLL_WALK2_PATH2        ; pointer to path 2
    FDB _YELLOW_TROLL_WALK2_PATH3        ; pointer to path 3
    FDB _YELLOW_TROLL_WALK2_PATH4        ; pointer to path 4
    FDB _YELLOW_TROLL_WALK2_PATH5        ; pointer to path 5
    FDB _YELLOW_TROLL_WALK2_PATH6        ; pointer to path 6
    FDB _YELLOW_TROLL_WALK2_PATH7        ; pointer to path 7
    FDB _YELLOW_TROLL_WALK2_PATH8        ; pointer to path 8

_YELLOW_TROLL_WALK2_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $01,$FE,0,0        ; path0: header (y=1, x=-2)
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FC,$04          ; flag=-1, dy=-4, dx=4
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$FE,$03          ; flag=-1, dy=-2, dx=3
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB $FF,$01,$02          ; flag=-1, dy=1, dx=2
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$FE,$FD          ; flag=-1, dy=-2, dx=-3
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_YELLOW_TROLL_WALK2_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $03,$00,0,0        ; path1: header (y=3, x=0)
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB $FF,$FC,$FE          ; flag=-1, dy=-4, dx=-2
    FCB $FF,$FB,$FF          ; flag=-1, dy=-5, dx=-1
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB 2                ; End marker (path complete)

_YELLOW_TROLL_WALK2_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $FB,$FA,0,0        ; path2: header (y=-5, x=-6)
    FCB $FF,$FF,$01          ; flag=-1, dy=-1, dx=1
    FCB $FF,$03,$03          ; flag=-1, dy=3, dx=3
    FCB 2                ; End marker (path complete)

_YELLOW_TROLL_WALK2_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $FB,$00,0,0        ; path3: header (y=-5, x=0)
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$01,$04          ; flag=-1, dy=1, dx=4
    FCB $FF,$03,$FC          ; flag=-1, dy=3, dx=-4
    FCB 2                ; End marker (path complete)

_YELLOW_TROLL_WALK2_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $FD,$02,0,0        ; path4: header (y=-3, x=2)
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_YELLOW_TROLL_WALK2_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $03,$00,0,0        ; path5: header (y=3, x=0)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB 2                ; End marker (path complete)

_YELLOW_TROLL_WALK2_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $03,$06,0,0        ; path6: header (y=3, x=6)
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$01,$02          ; flag=-1, dy=1, dx=2
    FCB 2                ; End marker (path complete)

_YELLOW_TROLL_WALK2_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $03,$04,0,0        ; path7: header (y=3, x=4)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB 2                ; End marker (path complete)

_YELLOW_TROLL_WALK2_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $FA,$FA,0,0        ; path8: header (y=-6, x=-6)
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
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

_TITCHI_WALK1_VECTORS:  ; Main entry (header + 10 path(s))
    FDB 10               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
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
    FCB $F9,$02,0,0        ; path2: header (y=-7, x=2)
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB $FF,$FF,$FB          ; flag=-1, dy=-1, dx=-5
    FCB 2                ; End marker (path complete)

_TITCHI_WALK1_PATH3:    ; Path 3
    FCB 85              ; path3: intensity
    FCB $FF,$05,0,0        ; path3: header (y=-1, x=5)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$FF,$FA          ; flag=-1, dy=-1, dx=-6
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$06,$FE          ; flag=-1, dy=6, dx=-2
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB 2                ; End marker (path complete)

_TITCHI_WALK1_PATH4:    ; Path 4
    FCB 85              ; path4: intensity
    FCB $03,$FE,0,0        ; path4: header (y=3, x=-2)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB 2                ; End marker (path complete)

_TITCHI_WALK1_PATH5:    ; Path 5
    FCB 85              ; path5: intensity
    FCB $05,$FF,0,0        ; path5: header (y=5, x=-1)
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB 2                ; End marker (path complete)

_TITCHI_WALK1_PATH6:    ; Path 6
    FCB 85              ; path6: intensity
    FCB $03,$04,0,0        ; path6: header (y=3, x=4)
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_TITCHI_WALK1_PATH7:    ; Path 7
    FCB 85              ; path7: intensity
    FCB $03,$02,0,0        ; path7: header (y=3, x=2)
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB 2                ; End marker (path complete)

_TITCHI_WALK1_PATH8:    ; Path 8
    FCB 85              ; path8: intensity
    FCB $03,$04,0,0        ; path8: header (y=3, x=4)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB 2                ; End marker (path complete)

_TITCHI_WALK1_PATH9:    ; Path 9
    FCB 85              ; path9: intensity
    FCB $01,$05,0,0        ; path9: header (y=1, x=5)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB 2                ; End marker (path complete)

; Generated from titchi_walk4.vec (Malban Draw_Sync_List format)
; Total paths: 13, points: 39
; X bounds: min=-7, max=7, width=14
; Center: (0, -1)

_TITCHI_WALK4_WIDTH EQU 14
_TITCHI_WALK4_HALF_WIDTH EQU 7
_TITCHI_WALK4_HEIGHT EQU 15
_TITCHI_WALK4_HALF_HEIGHT EQU 7
_TITCHI_WALK4_CENTER_X EQU 0
_TITCHI_WALK4_CENTER_Y EQU -1

_TITCHI_WALK4_VECTORS:  ; Main entry (header + 10 path(s))
    FDB 10               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _TITCHI_WALK4_PATH0        ; pointer to path 0
    FDB _TITCHI_WALK4_PATH1        ; pointer to path 1
    FDB _TITCHI_WALK4_PATH2        ; pointer to path 2
    FDB _TITCHI_WALK4_PATH3        ; pointer to path 3
    FDB _TITCHI_WALK4_PATH4        ; pointer to path 4
    FDB _TITCHI_WALK4_PATH5        ; pointer to path 5
    FDB _TITCHI_WALK4_PATH6        ; pointer to path 6
    FDB _TITCHI_WALK4_PATH7        ; pointer to path 7
    FDB _TITCHI_WALK4_PATH8        ; pointer to path 8
    FDB _TITCHI_WALK4_PATH9        ; pointer to path 9

_TITCHI_WALK4_PATH0:    ; Path 0
    FCB 85              ; path0: intensity
    FCB $00,$FE,0,0        ; path0: header (y=0, x=-2)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB 2                ; End marker (path complete)

_TITCHI_WALK4_PATH1:    ; Path 1
    FCB 85              ; path1: intensity
    FCB $FD,$FC,0,0        ; path1: header (y=-3, x=-4)
    FCB $FF,$FF,$FD          ; flag=-1, dy=-1, dx=-3
    FCB 2                ; End marker (path complete)

_TITCHI_WALK4_PATH2:    ; Path 2
    FCB 85              ; path2: intensity
    FCB $FA,$01,0,0        ; path2: header (y=-6, x=1)
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB 2                ; End marker (path complete)

_TITCHI_WALK4_PATH3:    ; Path 3
    FCB 85              ; path3: intensity
    FCB $00,$05,0,0        ; path3: header (y=0, x=5)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$FF,$FA          ; flag=-1, dy=-1, dx=-6
    FCB $FF,$FF,$03          ; flag=-1, dy=-1, dx=3
    FCB $FF,$FE,$FA          ; flag=-1, dy=-2, dx=-6
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$06,$FE          ; flag=-1, dy=6, dx=-2
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB 2                ; End marker (path complete)

_TITCHI_WALK4_PATH4:    ; Path 4
    FCB 85              ; path4: intensity
    FCB $04,$FE,0,0        ; path4: header (y=4, x=-2)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB 2                ; End marker (path complete)

_TITCHI_WALK4_PATH5:    ; Path 5
    FCB 85              ; path5: intensity
    FCB $06,$FF,0,0        ; path5: header (y=6, x=-1)
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB 2                ; End marker (path complete)

_TITCHI_WALK4_PATH6:    ; Path 6
    FCB 85              ; path6: intensity
    FCB $04,$04,0,0        ; path6: header (y=4, x=4)
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_TITCHI_WALK4_PATH7:    ; Path 7
    FCB 85              ; path7: intensity
    FCB $04,$02,0,0        ; path7: header (y=4, x=2)
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB 2                ; End marker (path complete)

_TITCHI_WALK4_PATH8:    ; Path 8
    FCB 85              ; path8: intensity
    FCB $04,$04,0,0        ; path8: header (y=4, x=4)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB 2                ; End marker (path complete)

_TITCHI_WALK4_PATH9:    ; Path 9
    FCB 85              ; path9: intensity
    FCB $02,$05,0,0        ; path9: header (y=2, x=5)
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB 2                ; End marker (path complete)

; Generated from frog_walk2.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 33
; X bounds: min=-7, max=7, width=14
; Center: (0, 0)

_FROG_WALK2_WIDTH EQU 14
_FROG_WALK2_HALF_WIDTH EQU 7
_FROG_WALK2_HEIGHT EQU 19
_FROG_WALK2_HALF_HEIGHT EQU 9
_FROG_WALK2_CENTER_X EQU 0
_FROG_WALK2_CENTER_Y EQU 0

_FROG_WALK2_VECTORS:  ; Main entry (header + 4 path(s))
    FDB 4               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _FROG_WALK2_PATH0        ; pointer to path 0
    FDB _FROG_WALK2_PATH1        ; pointer to path 1
    FDB _FROG_WALK2_PATH2        ; pointer to path 2
    FDB _FROG_WALK2_PATH3        ; pointer to path 3

_FROG_WALK2_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $01,$FF,0,0        ; path0: header (y=1, x=-1)
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB 2                ; End marker (path complete)

_FROG_WALK2_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $04,$FF,0,0        ; path1: header (y=4, x=-1)
    FCB $FF,$FD,$04          ; flag=-1, dy=-3, dx=4
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB 2                ; End marker (path complete)

_FROG_WALK2_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $FA,$FF,0,0        ; path2: header (y=-6, x=-1)
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$04,$FD          ; flag=-1, dy=4, dx=-3
    FCB $FF,$04,$01          ; flag=-1, dy=4, dx=1
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$03,$03          ; flag=-1, dy=3, dx=3
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB $FF,$FD,$04          ; flag=-1, dy=-3, dx=4
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB 2                ; End marker (path complete)

_FROG_WALK2_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $07,$04,0,0        ; path3: header (y=7, x=4)
    FCB $FF,$FF,$01          ; flag=-1, dy=-1, dx=1
    FCB 2                ; End marker (path complete)

; Generated from frog_walk1.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 34
; X bounds: min=-8, max=7, width=15
; Center: (0, 0)

_FROG_WALK1_WIDTH EQU 15
_FROG_WALK1_HALF_WIDTH EQU 7
_FROG_WALK1_HEIGHT EQU 18
_FROG_WALK1_HALF_HEIGHT EQU 9
_FROG_WALK1_CENTER_X EQU 0
_FROG_WALK1_CENTER_Y EQU 0

_FROG_WALK1_VECTORS:  ; Main entry (header + 4 path(s))
    FDB 4               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _FROG_WALK1_PATH0        ; pointer to path 0
    FDB _FROG_WALK1_PATH1        ; pointer to path 1
    FDB _FROG_WALK1_PATH2        ; pointer to path 2
    FDB _FROG_WALK1_PATH3        ; pointer to path 3

_FROG_WALK1_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $01,$FF,0,0        ; path0: header (y=1, x=-1)
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$03,$FE          ; flag=-1, dy=3, dx=-2
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB 2                ; End marker (path complete)

_FROG_WALK1_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $04,$FF,0,0        ; path1: header (y=4, x=-1)
    FCB $FF,$FD,$04          ; flag=-1, dy=-3, dx=4
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$FE,$FD          ; flag=-1, dy=-2, dx=-3
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB 2                ; End marker (path complete)

_FROG_WALK1_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $FA,$FF,0,0        ; path2: header (y=-6, x=-1)
    FCB $FF,$FD,$FE          ; flag=-1, dy=-3, dx=-2
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$01,$02          ; flag=-1, dy=1, dx=2
    FCB $FF,$01,$02          ; flag=-1, dy=1, dx=2
    FCB $FF,$03,$FD          ; flag=-1, dy=3, dx=-3
    FCB $FF,$04,$01          ; flag=-1, dy=4, dx=1
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$FC,$04          ; flag=-1, dy=-4, dx=4
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$02,$FA          ; flag=-1, dy=2, dx=-6
    FCB 2                ; End marker (path complete)

_FROG_WALK1_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $07,$04,0,0        ; path3: header (y=7, x=4)
    FCB $FF,$FF,$01          ; flag=-1, dy=-1, dx=1
    FCB 2                ; End marker (path complete)

;***************************************************************************
; RUNTIME HELPERS
;***************************************************************************

; === CUSTOM VECTOR FONT (M6809) ===
; _FONT_PTRS: 96 FDB entries for ASCII 32..127 → glyph_ptr or 0.
; Each glyph block: stream of (cmd, gx, gy) triples, terminated by FCB 0.
_FONT_PTRS:
    FDB 0       ; ' ' ($20) no glyph
    FDB _FONT_G_21    ; '!' ($21)
    FDB _FONT_G_22    ; '"' ($22)
    FDB 0       ; '#' ($23) no glyph
    FDB 0       ; '$' ($24) no glyph
    FDB 0       ; '%' ($25) no glyph
    FDB 0       ; '&' ($26) no glyph
    FDB 0       ; ''' ($27) no glyph
    FDB 0       ; '(' ($28) no glyph
    FDB 0       ; ')' ($29) no glyph
    FDB 0       ; '*' ($2A) no glyph
    FDB _FONT_G_2B    ; '+' ($2B)
    FDB _FONT_G_2C    ; ',' ($2C)
    FDB _FONT_G_2D    ; '-' ($2D)
    FDB _FONT_G_2E    ; '.' ($2E)
    FDB _FONT_G_2F    ; '/' ($2F)
    FDB _FONT_G_30    ; '0' ($30)
    FDB _FONT_G_31    ; '1' ($31)
    FDB _FONT_G_32    ; '2' ($32)
    FDB _FONT_G_33    ; '3' ($33)
    FDB _FONT_G_34    ; '4' ($34)
    FDB _FONT_G_35    ; '5' ($35)
    FDB _FONT_G_36    ; '6' ($36)
    FDB _FONT_G_37    ; '7' ($37)
    FDB _FONT_G_38    ; '8' ($38)
    FDB _FONT_G_39    ; '9' ($39)
    FDB _FONT_G_3A    ; ':' ($3A)
    FDB _FONT_G_3B    ; ';' ($3B)
    FDB _FONT_G_3C    ; '<' ($3C)
    FDB _FONT_G_3D    ; '=' ($3D)
    FDB _FONT_G_3E    ; '>' ($3E)
    FDB _FONT_G_3F    ; '?' ($3F)
    FDB 0       ; '@' ($40) no glyph
    FDB _FONT_G_41    ; 'A' ($41)
    FDB _FONT_G_42    ; 'B' ($42)
    FDB _FONT_G_43    ; 'C' ($43)
    FDB _FONT_G_44    ; 'D' ($44)
    FDB _FONT_G_45    ; 'E' ($45)
    FDB _FONT_G_46    ; 'F' ($46)
    FDB _FONT_G_47    ; 'G' ($47)
    FDB _FONT_G_48    ; 'H' ($48)
    FDB _FONT_G_49    ; 'I' ($49)
    FDB _FONT_G_4A    ; 'J' ($4A)
    FDB _FONT_G_4B    ; 'K' ($4B)
    FDB _FONT_G_4C    ; 'L' ($4C)
    FDB _FONT_G_4D    ; 'M' ($4D)
    FDB _FONT_G_4E    ; 'N' ($4E)
    FDB _FONT_G_4F    ; 'O' ($4F)
    FDB _FONT_G_50    ; 'P' ($50)
    FDB _FONT_G_51    ; 'Q' ($51)
    FDB _FONT_G_52    ; 'R' ($52)
    FDB _FONT_G_53    ; 'S' ($53)
    FDB _FONT_G_54    ; 'T' ($54)
    FDB _FONT_G_55    ; 'U' ($55)
    FDB _FONT_G_56    ; 'V' ($56)
    FDB _FONT_G_57    ; 'W' ($57)
    FDB _FONT_G_58    ; 'X' ($58)
    FDB _FONT_G_59    ; 'Y' ($59)
    FDB _FONT_G_5A    ; 'Z' ($5A)
    FDB 0       ; '[' ($5B) no glyph
    FDB 0       ; '\' ($5C) no glyph
    FDB 0       ; ']' ($5D) no glyph
    FDB 0       ; '^' ($5E) no glyph
    FDB 0       ; '_' ($5F) no glyph
    FDB 0       ; '`' ($60) no glyph
    FDB _FONT_G_61    ; 'a' ($61)
    FDB _FONT_G_62    ; 'b' ($62)
    FDB _FONT_G_63    ; 'c' ($63)
    FDB _FONT_G_64    ; 'd' ($64)
    FDB _FONT_G_65    ; 'e' ($65)
    FDB _FONT_G_66    ; 'f' ($66)
    FDB _FONT_G_67    ; 'g' ($67)
    FDB _FONT_G_68    ; 'h' ($68)
    FDB _FONT_G_69    ; 'i' ($69)
    FDB _FONT_G_6A    ; 'j' ($6A)
    FDB _FONT_G_6B    ; 'k' ($6B)
    FDB _FONT_G_6C    ; 'l' ($6C)
    FDB _FONT_G_6D    ; 'm' ($6D)
    FDB _FONT_G_6E    ; 'n' ($6E)
    FDB _FONT_G_6F    ; 'o' ($6F)
    FDB _FONT_G_70    ; 'p' ($70)
    FDB _FONT_G_71    ; 'q' ($71)
    FDB _FONT_G_72    ; 'r' ($72)
    FDB _FONT_G_73    ; 's' ($73)
    FDB _FONT_G_74    ; 't' ($74)
    FDB _FONT_G_75    ; 'u' ($75)
    FDB _FONT_G_76    ; 'v' ($76)
    FDB _FONT_G_77    ; 'w' ($77)
    FDB _FONT_G_78    ; 'x' ($78)
    FDB _FONT_G_79    ; 'y' ($79)
    FDB _FONT_G_7A    ; 'z' ($7A)
    FDB 0       ; '{' ($7B) no glyph
    FDB 0       ; '|' ($7C) no glyph
    FDB 0       ; '}' ($7D) no glyph
    FDB 0       ; '~' ($7E) no glyph
    FDB 0       ; '?' ($7F) no glyph

; --- Glyph stroke data ---
_FONT_G_21:
    FCB 1,2,6
    FCB 2,2,2
    FCB 1,2,0
    FCB 2,2,1
    FCB 0    ; end of glyph
_FONT_G_22:
    FCB 1,1,5
    FCB 2,1,6
    FCB 1,3,5
    FCB 2,3,6
    FCB 0    ; end of glyph
_FONT_G_2B:
    FCB 1,2,1
    FCB 2,2,5
    FCB 1,0,3
    FCB 2,4,3
    FCB 0    ; end of glyph
_FONT_G_2C:
    FCB 1,2,1
    FCB 2,1,0
    FCB 0    ; end of glyph
_FONT_G_2D:
    FCB 1,0,3
    FCB 2,4,3
    FCB 0    ; end of glyph
_FONT_G_2E:
    FCB 1,1,0
    FCB 2,2,0
    FCB 0    ; end of glyph
_FONT_G_2F:
    FCB 1,0,0
    FCB 2,4,6
    FCB 0    ; end of glyph
_FONT_G_30:
    FCB 1,0,0
    FCB 2,4,0
    FCB 2,4,6
    FCB 2,0,6
    FCB 2,0,0
    FCB 0    ; end of glyph
_FONT_G_31:
    FCB 1,2,0
    FCB 2,2,6
    FCB 0    ; end of glyph
_FONT_G_32:
    FCB 1,0,6
    FCB 2,4,6
    FCB 2,4,3
    FCB 2,0,3
    FCB 2,0,0
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_33:
    FCB 1,0,6
    FCB 2,4,6
    FCB 2,4,0
    FCB 2,0,0
    FCB 1,4,3
    FCB 2,1,3
    FCB 0    ; end of glyph
_FONT_G_34:
    FCB 1,0,6
    FCB 2,0,3
    FCB 2,4,3
    FCB 1,4,6
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_35:
    FCB 1,4,6
    FCB 2,0,6
    FCB 2,0,3
    FCB 2,4,3
    FCB 2,4,0
    FCB 2,0,0
    FCB 0    ; end of glyph
_FONT_G_36:
    FCB 1,4,6
    FCB 2,0,6
    FCB 2,0,0
    FCB 2,4,0
    FCB 2,4,3
    FCB 2,0,3
    FCB 0    ; end of glyph
_FONT_G_37:
    FCB 1,0,6
    FCB 2,4,6
    FCB 2,2,0
    FCB 0    ; end of glyph
_FONT_G_38:
    FCB 1,0,0
    FCB 2,4,0
    FCB 2,4,6
    FCB 2,0,6
    FCB 2,0,0
    FCB 1,0,3
    FCB 2,4,3
    FCB 0    ; end of glyph
_FONT_G_39:
    FCB 1,4,0
    FCB 2,4,6
    FCB 2,0,6
    FCB 2,0,3
    FCB 2,4,3
    FCB 0    ; end of glyph
_FONT_G_3A:
    FCB 1,2,1
    FCB 2,2,2
    FCB 1,2,4
    FCB 2,2,5
    FCB 0    ; end of glyph
_FONT_G_3B:
    FCB 1,2,4
    FCB 2,2,5
    FCB 1,2,1
    FCB 2,1,0
    FCB 0    ; end of glyph
_FONT_G_3C:
    FCB 1,3,6
    FCB 2,0,3
    FCB 2,3,0
    FCB 0    ; end of glyph
_FONT_G_3D:
    FCB 1,0,4
    FCB 2,4,4
    FCB 1,0,2
    FCB 2,4,2
    FCB 0    ; end of glyph
_FONT_G_3E:
    FCB 1,1,6
    FCB 2,4,3
    FCB 2,1,0
    FCB 0    ; end of glyph
_FONT_G_3F:
    FCB 1,0,6
    FCB 2,4,6
    FCB 2,4,4
    FCB 2,2,3
    FCB 1,2,1
    FCB 2,2,2
    FCB 0    ; end of glyph
_FONT_G_41:
    FCB 1,0,0
    FCB 2,2,6
    FCB 2,4,0
    FCB 1,0,3
    FCB 2,4,3
    FCB 0    ; end of glyph
_FONT_G_42:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,3,6
    FCB 2,3,3
    FCB 2,0,3
    FCB 2,3,3
    FCB 2,3,0
    FCB 2,0,0
    FCB 0    ; end of glyph
_FONT_G_43:
    FCB 1,4,6
    FCB 2,0,6
    FCB 2,0,0
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_44:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,3,6
    FCB 2,4,5
    FCB 2,4,1
    FCB 2,3,0
    FCB 2,0,0
    FCB 0    ; end of glyph
_FONT_G_45:
    FCB 1,4,0
    FCB 2,0,0
    FCB 2,0,6
    FCB 2,4,6
    FCB 1,0,3
    FCB 2,3,3
    FCB 0    ; end of glyph
_FONT_G_46:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,4,6
    FCB 1,0,3
    FCB 2,3,3
    FCB 0    ; end of glyph
_FONT_G_47:
    FCB 1,4,6
    FCB 2,0,6
    FCB 2,0,0
    FCB 2,4,0
    FCB 2,4,3
    FCB 2,2,3
    FCB 0    ; end of glyph
_FONT_G_48:
    FCB 1,0,0
    FCB 2,0,6
    FCB 1,4,0
    FCB 2,4,6
    FCB 1,0,3
    FCB 2,4,3
    FCB 0    ; end of glyph
_FONT_G_49:
    FCB 1,1,0
    FCB 2,3,0
    FCB 1,2,0
    FCB 2,2,6
    FCB 1,1,6
    FCB 2,3,6
    FCB 0    ; end of glyph
_FONT_G_4A:
    FCB 1,0,1
    FCB 2,1,0
    FCB 2,4,0
    FCB 2,4,6
    FCB 1,1,6
    FCB 2,3,6
    FCB 0    ; end of glyph
_FONT_G_4B:
    FCB 1,0,0
    FCB 2,0,6
    FCB 1,0,3
    FCB 2,4,6
    FCB 1,0,3
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_4C:
    FCB 1,0,6
    FCB 2,0,0
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_4D:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,2,3
    FCB 2,4,6
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_4E:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,4,0
    FCB 2,4,6
    FCB 0    ; end of glyph
_FONT_G_4F:
    FCB 1,0,0
    FCB 2,4,0
    FCB 2,4,6
    FCB 2,0,6
    FCB 2,0,0
    FCB 0    ; end of glyph
_FONT_G_50:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,3,6
    FCB 2,4,5
    FCB 2,4,4
    FCB 2,3,3
    FCB 2,0,3
    FCB 0    ; end of glyph
_FONT_G_51:
    FCB 1,0,0
    FCB 2,4,0
    FCB 2,4,6
    FCB 2,0,6
    FCB 2,0,0
    FCB 1,3,1
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_52:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,3,6
    FCB 2,4,5
    FCB 2,4,4
    FCB 2,3,3
    FCB 2,0,3
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_53:
    FCB 1,4,6
    FCB 2,0,6
    FCB 2,0,3
    FCB 2,4,3
    FCB 2,4,0
    FCB 2,0,0
    FCB 0    ; end of glyph
_FONT_G_54:
    FCB 1,0,6
    FCB 2,4,6
    FCB 1,2,6
    FCB 2,2,0
    FCB 0    ; end of glyph
_FONT_G_55:
    FCB 1,0,6
    FCB 2,0,0
    FCB 2,4,0
    FCB 2,4,6
    FCB 0    ; end of glyph
_FONT_G_56:
    FCB 1,0,6
    FCB 2,2,0
    FCB 2,4,6
    FCB 0    ; end of glyph
_FONT_G_57:
    FCB 1,0,6
    FCB 2,1,0
    FCB 2,2,3
    FCB 2,3,0
    FCB 2,4,6
    FCB 0    ; end of glyph
_FONT_G_58:
    FCB 1,0,0
    FCB 2,4,6
    FCB 1,0,6
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_59:
    FCB 1,0,6
    FCB 2,2,3
    FCB 2,4,6
    FCB 1,2,3
    FCB 2,2,0
    FCB 0    ; end of glyph
_FONT_G_5A:
    FCB 1,0,6
    FCB 2,4,6
    FCB 2,0,0
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_61:
    FCB 1,0,0
    FCB 2,2,6
    FCB 2,4,0
    FCB 1,0,3
    FCB 2,4,3
    FCB 0    ; end of glyph
_FONT_G_62:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,3,6
    FCB 2,3,3
    FCB 2,0,3
    FCB 2,3,3
    FCB 2,3,0
    FCB 2,0,0
    FCB 0    ; end of glyph
_FONT_G_63:
    FCB 1,4,6
    FCB 2,0,6
    FCB 2,0,0
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_64:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,3,6
    FCB 2,4,5
    FCB 2,4,1
    FCB 2,3,0
    FCB 2,0,0
    FCB 0    ; end of glyph
_FONT_G_65:
    FCB 1,4,0
    FCB 2,0,0
    FCB 2,0,6
    FCB 2,4,6
    FCB 1,0,3
    FCB 2,3,3
    FCB 0    ; end of glyph
_FONT_G_66:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,4,6
    FCB 1,0,3
    FCB 2,3,3
    FCB 0    ; end of glyph
_FONT_G_67:
    FCB 1,4,6
    FCB 2,0,6
    FCB 2,0,0
    FCB 2,4,0
    FCB 2,4,3
    FCB 2,2,3
    FCB 0    ; end of glyph
_FONT_G_68:
    FCB 1,0,0
    FCB 2,0,6
    FCB 1,4,0
    FCB 2,4,6
    FCB 1,0,3
    FCB 2,4,3
    FCB 0    ; end of glyph
_FONT_G_69:
    FCB 1,1,0
    FCB 2,3,0
    FCB 1,2,0
    FCB 2,2,6
    FCB 1,1,6
    FCB 2,3,6
    FCB 0    ; end of glyph
_FONT_G_6A:
    FCB 1,0,1
    FCB 2,1,0
    FCB 2,4,0
    FCB 2,4,6
    FCB 1,1,6
    FCB 2,3,6
    FCB 0    ; end of glyph
_FONT_G_6B:
    FCB 1,0,0
    FCB 2,0,6
    FCB 1,0,3
    FCB 2,4,6
    FCB 1,0,3
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_6C:
    FCB 1,0,6
    FCB 2,0,0
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_6D:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,2,3
    FCB 2,4,6
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_6E:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,4,0
    FCB 2,4,6
    FCB 0    ; end of glyph
_FONT_G_6F:
    FCB 1,0,0
    FCB 2,4,0
    FCB 2,4,6
    FCB 2,0,6
    FCB 2,0,0
    FCB 0    ; end of glyph
_FONT_G_70:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,3,6
    FCB 2,4,5
    FCB 2,4,4
    FCB 2,3,3
    FCB 2,0,3
    FCB 0    ; end of glyph
_FONT_G_71:
    FCB 1,0,0
    FCB 2,4,0
    FCB 2,4,6
    FCB 2,0,6
    FCB 2,0,0
    FCB 1,3,1
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_72:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,3,6
    FCB 2,4,5
    FCB 2,4,4
    FCB 2,3,3
    FCB 2,0,3
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_73:
    FCB 1,4,6
    FCB 2,0,6
    FCB 2,0,3
    FCB 2,4,3
    FCB 2,4,0
    FCB 2,0,0
    FCB 0    ; end of glyph
_FONT_G_74:
    FCB 1,0,6
    FCB 2,4,6
    FCB 1,2,6
    FCB 2,2,0
    FCB 0    ; end of glyph
_FONT_G_75:
    FCB 1,0,6
    FCB 2,0,0
    FCB 2,4,0
    FCB 2,4,6
    FCB 0    ; end of glyph
_FONT_G_76:
    FCB 1,0,6
    FCB 2,2,0
    FCB 2,4,6
    FCB 0    ; end of glyph
_FONT_G_77:
    FCB 1,0,6
    FCB 2,1,0
    FCB 2,2,3
    FCB 2,3,0
    FCB 2,4,6
    FCB 0    ; end of glyph
_FONT_G_78:
    FCB 1,0,0
    FCB 2,4,6
    FCB 1,0,6
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_79:
    FCB 1,0,6
    FCB 2,2,3
    FCB 2,4,6
    FCB 1,2,3
    FCB 2,2,0
    FCB 0    ; end of glyph
_FONT_G_7A:
    FCB 1,0,6
    FCB 2,4,6
    FCB 2,0,0
    FCB 2,4,0
    FCB 0    ; end of glyph

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

; === JOYSTICK BUILTIN SUBROUTINES (cached, Joy_Analog runs once per frame) ===
; J1_X() - Read Joystick 1 X axis from cached BIOS value at $C81B
J1X_BUILTIN:
    LDB >$C81B   ; Vec_Joy_1_X (populated each frame by auto-injected Joy_Analog)
    SEX          ; Sign-extend B to D
    ADDD #2      ; Calibrate center offset
    RTS

; ============================================================================
; DRAW_CIRCLE_RUNTIME - Draw circle with runtime parameters
; ============================================================================
; Follows Draw_Sync_List_At pattern: read params BEFORE DP change
; Inputs: DRAW_CIRCLE_XC, DRAW_CIRCLE_YC, DRAW_CIRCLE_DIAM, DRAW_CIRCLE_INTENSITY (bytes in RAM)
; Uses 16-segment polygon (same as constant path) via MUL scaling of fixed fractions
; 4 unique delta fractions of radius r (16-gon, vertices at k*22.5 deg):
;   a = 0.3827*r (sin22.5) via MUL #98 /256, stored at >DRAW_CIRCLE_TEMP+2
;   b = 0.3244*r (sin45-sin22.5) via MUL #83 /256, stored at >DRAW_CIRCLE_TEMP+3
;   c = 0.2168*r via MUL #56 /256, stored at >DRAW_CIRCLE_TEMP+4
;   d = 0.0761*r via MUL #19 /256, stored at >DRAW_CIRCLE_TEMP+5
; >DRAW_CIRCLE_TEMP layout: [radius16][a][b][c][d][--][--]
DRAW_CIRCLE_RUNTIME:
; Read ALL parameters into registers/stack BEFORE changing DP (critical!)
; (These are byte variables, use LDB not LDD)
LDB DRAW_CIRCLE_INTENSITY
PSHS B                 ; Save intensity on stack

LDB DRAW_CIRCLE_DIAM
SEX                    ; Sign-extend to 16-bit (diameter is unsigned 0..255)
LSRA                   ; Divide by 2 to get radius
RORB
STD >DRAW_CIRCLE_TEMP   ; >DRAW_CIRCLE_TEMP = radius (16-bit, big-endian: +0=hi, +1=lo)

LDB DRAW_CIRCLE_XC     ; xc (signed -128..127)
SEX
STD >DRAW_CIRCLE_TEMP+2 ; Save xc (16-bit, reused for 'a' after Moveto)

LDB DRAW_CIRCLE_YC     ; yc (signed -128..127)
SEX
STD >DRAW_CIRCLE_TEMP+4 ; Save yc (16-bit, reused for 'c' after Moveto)

; NOW safe to setup BIOS (all params are in >DRAW_CIRCLE_TEMP+stack)
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
; radius = >DRAW_CIRCLE_TEMP, xc = >DRAW_CIRCLE_TEMP+2, yc = >DRAW_CIRCLE_TEMP+4
LDD >DRAW_CIRCLE_TEMP   ; D = radius (16-bit)
ADDD >DRAW_CIRCLE_TEMP+2 ; D = xc + radius
TFR B,B                ; Keep X in B (low byte)
PSHS B                 ; Save X on stack
LDD >DRAW_CIRCLE_TEMP+4 ; Load yc
TFR B,A                ; Y to A
PULS B                 ; X to B
JSR Moveto_d

; Precompute 4 delta fractions using MUL (same fractions as constant 16-gon path)
; radius is at >DRAW_CIRCLE_TEMP+1 (low byte, 0..127)
; >DRAW_CIRCLE_TEMP+2..5 now free to reuse for a,b,c,d
; MUL: A * B -> D (unsigned); ADDD #128 then A = round(frac * r) (avoids floor-to-0 for small radii)
LDB >DRAW_CIRCLE_TEMP+1 ; radius
LDA #98                ; 98/256 = 0.3828 ~ sin(22.5 deg) = 0.3827
MUL                    ; D = 98 * r
ADDD #128              ; round before /256
STA >DRAW_CIRCLE_TEMP+2 ; Store a = round(0.3828 * r)
LDB >DRAW_CIRCLE_TEMP+1 ; radius
LDA #83                ; 83/256 = 0.3242 ~ 0.3244
MUL                    ; D = 83 * r
ADDD #128              ; round before /256
STA >DRAW_CIRCLE_TEMP+3 ; Store b
LDB >DRAW_CIRCLE_TEMP+1 ; radius
LDA #56                ; 56/256 = 0.2188 ~ 0.2168
MUL                    ; D = 56 * r
ADDD #128              ; round before /256
STA >DRAW_CIRCLE_TEMP+4 ; Store c
LDB >DRAW_CIRCLE_TEMP+1 ; radius
LDA #19                ; 19/256 = 0.0742 ~ 0.0761
MUL                    ; D = 19 * r
ADDD #128              ; round before /256
STA >DRAW_CIRCLE_TEMP+5 ; Store d

; Draw 16 unrolled segments - 16-gon counterclockwise from (xc+r, yc)
; Draw_Line_d(A=dy, B=dx). Symmetry pattern by quadrant:
;   Q1 (0->90):   (+a,-d), (+b,-c), (+c,-b), (+d,-a)
;   Q2 (90->180): (-d,-a), (-c,-b), (-b,-c), (-a,-d)
;   Q3 (180->270):(-a,+d), (-b,+c), (-c,+b), (-d,+a)
;   Q4 (270->360):(+d,+a), (+c,+b), (+b,+c), (+a,+d)

; --- Q1 ---
; Seg 0: dy=+a, dx=-d
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+2  ; a
LDB >DRAW_CIRCLE_TEMP+5  ; d
NEGB
JSR Draw_Line_d
; Seg 1: dy=+b, dx=-c
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+3  ; b
LDB >DRAW_CIRCLE_TEMP+4  ; c
NEGB
JSR Draw_Line_d
; Seg 2: dy=+c, dx=-b
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+4  ; c
LDB >DRAW_CIRCLE_TEMP+3  ; b
NEGB
JSR Draw_Line_d
; Seg 3: dy=+d, dx=-a
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+5  ; d
LDB >DRAW_CIRCLE_TEMP+2  ; a
NEGB
JSR Draw_Line_d

; --- Q2 ---
; Seg 4: dy=-d, dx=-a
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+5  ; d
NEGA
LDB >DRAW_CIRCLE_TEMP+2  ; a
NEGB
JSR Draw_Line_d
; Seg 5: dy=-c, dx=-b
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+4  ; c
NEGA
LDB >DRAW_CIRCLE_TEMP+3  ; b
NEGB
JSR Draw_Line_d
; Seg 6: dy=-b, dx=-c
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+3  ; b
NEGA
LDB >DRAW_CIRCLE_TEMP+4  ; c
NEGB
JSR Draw_Line_d
; Seg 7: dy=-a, dx=-d
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+2  ; a
NEGA
LDB >DRAW_CIRCLE_TEMP+5  ; d
NEGB
JSR Draw_Line_d

; --- Q3 ---
; Seg 8: dy=-a, dx=+d
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+2  ; a
NEGA
LDB >DRAW_CIRCLE_TEMP+5  ; d (positive)
JSR Draw_Line_d
; Seg 9: dy=-b, dx=+c
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+3  ; b
NEGA
LDB >DRAW_CIRCLE_TEMP+4  ; c (positive)
JSR Draw_Line_d
; Seg 10: dy=-c, dx=+b
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+4  ; c
NEGA
LDB >DRAW_CIRCLE_TEMP+3  ; b (positive)
JSR Draw_Line_d
; Seg 11: dy=-d, dx=+a
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+5  ; d
NEGA
LDB >DRAW_CIRCLE_TEMP+2  ; a (positive)
JSR Draw_Line_d

; --- Q4 ---
; Seg 12: dy=+d, dx=+a
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+5  ; d (positive)
LDB >DRAW_CIRCLE_TEMP+2  ; a (positive)
JSR Draw_Line_d
; Seg 13: dy=+c, dx=+b
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+4  ; c (positive)
LDB >DRAW_CIRCLE_TEMP+3  ; b (positive)
JSR Draw_Line_d
; Seg 14: dy=+b, dx=+c
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+3  ; b (positive)
LDB >DRAW_CIRCLE_TEMP+4  ; c (positive)
JSR Draw_Line_d
; Seg 15: dy=+a, dx=+d
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+2  ; a (positive)
LDB >DRAW_CIRCLE_TEMP+5  ; d (positive)
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
; === GET_LEVEL_FLOOR_Y_RUNTIME (multibank) ===
GET_LEVEL_FLOOR_Y_RUNTIME:
    LDX >LEVEL_PTR
    LDD #0              ; default offset = 0 if no level
    CMPX #0
    BEQ GLFYR_NO_LEVEL  ; no level loaded — keep offset 0
    LDA >CURRENT_ROM_BANK
    PSHS A              ; save current bank
    LDA >LEVEL_BANK
    STA >CURRENT_ROM_BANK
    STA $DF00           ; switch — safe: we're in fixed helpers bank
    LDD 32,X            ; groundBottomOffset FDB at header +32
    STD >TMPVAL         ; save across bank restore (PULS clobbers D's hi)
    PULS A              ; restore original bank
    STA >CURRENT_ROM_BANK
    STA $DF00
    LDD >TMPVAL
GLFYR_NO_LEVEL:
    ADDD >CAMERA_Y      ; + camera_y
    SUBD #128           ; - 128 (half screen height)
    STD RESULT
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
    STA >TMPVAL      ; TMPVAL = top_screen
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
    STB >TMPVAL+1    ; stash max_idx for compare (no CBA in assembler)
    CMPA >TMPVAL+1   ; A (bot_screen) vs max_idx
    BLS SLR_BOT_NOCLAMP
    LDA >TMPVAL+1    ; clamp bot_screen = max_idx
SLR_BOT_NOCLAMP:
    STA >TMPVAL+1    ; TMPVAL+1 = bot_screen
    
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
    ; MULTIBANK: Restore original bank
    PULS A              ; A = saved bank
    STA >CURRENT_ROM_BANK
    STA $DF00           ; Restore bank
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    PULS D,X,Y,U,PC  ; Restore and return
    
; === SLR_DRAW_SCREEN_RANGE — iterate screens in visible camera range ===
SLR_DRAW_SCREEN_RANGE:
    LDA >TMPVAL          ; A = current screen idx (start at top)
SLR_SR_LOOP:
    CMPA >TMPVAL+1
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
    ; Per-object cull with half_width (ROM+19, stride-21). SLR_DRAW_CLIPPED_PATH
    ; handles per-path wrap and per-segment beam-off moves, so widening
    ; the cull here lets partial objects render at the screen edges.
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
    ; MULTIBANK: NOW switch to the vector's bank.
    ; U = vector address valid in that bank; level data fully read above.
    ; Level bank is restored in SLR_PATH_DONE after all paths are drawn.
    LDA 16,X         ; reload vector_bank (LDA 6,X clobbered A)
    STA >CURRENT_ROM_BANK
    STA $DF00        ; switch to vector bank
    
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
    JSR Draw_Sync_List_At_With_Mirrors  ; stable BIOS-style VIA drawing (no flicker)
    PULS X           ; Restore pointer table position
    PULS B           ; Restore count
    BRA SLR_PATH_LOOP
    
SLR_PATH_DONE:
    PULS X           ; Restore object pointer
    ; MULTIBANK: Restore level bank now that all vector paths are drawn.
    ; SLR_OBJ_NEXT needs the level bank active to advance X through level objects.
    LDA >LEVEL_BANK
    STA >CURRENT_ROM_BANK
    STA $DF00        ; switch back to level bank
    
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
; ROM object offsets (stride-21): +0=type, +1-2=x(FDB), +3-4=y(FDB), +12=collision_flags,
;   +16=vector_bank, +17-18=vector_ptr, +19=half_width, +20=half_height. Stride=21.
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
    ; MULTIBANK: Restore original bank (result is in RESULT, will reload after)
    PULS A              ; A = saved bank
    STA >CURRENT_ROM_BANK
    STA $DF00           ; Restore bank
    LDD RESULT          ; Reload return value into D
    
    PULS X,Y,U,PC    ; Restore (NOT D - result stays in D)

; === LEVEL_COLLISION_X_RUNTIME ===
; Find first collidable GP object overlapping player horizontally.
; Input:  LCOL_PX (16-bit) = player world_x
;         LCOL_PY (16-bit) = player world_y
;         LCOL_PHW (u8) = player half_width
; Output: RESULT = signed push-out dx (16-bit). Positive=right, negative=left.
; Returns 0 if no overlap found.
; Scratch: uses LCOL_THW for total_hw (preserves LCOL_PHH=player_hh across iterations).
; ROM object offsets (stride-21): +0=type, +1-2=x(FDB), +3-4=y(FDB), +12=collision_flags,
;   +16=vector_bank, +17-18=vector_ptr, +19=half_width, +20=half_height. Stride=21.
LEVEL_COLLISION_X_RUNTIME:
    PSHS X,Y,U
    ; MULTIBANK: Switch to level bank so ROM GP pointer dereferences land in the right bank
    LDA >CURRENT_ROM_BANK
    PSHS A              ; Save current bank
    LDA >LEVEL_BANK
    STA >CURRENT_ROM_BANK
    STA $DF00           ; Switch to level bank
    LDD #0
    STD RESULT
    TST >LEVEL_LOADED
    LBEQ LCOL_X_DONE
    LDB >LEVEL_GP_COUNT
    LBEQ LCOL_X_DONE
    STB >LCOL_OBJ_CNT  ; GP objects remaining
    LDX >LEVEL_GP_PTR
LCOL_X_LOOP:
    ; collision flag (bit 0 at ROM+12)
    LDA 12,X
    BITA #$01
    LBEQ LCOL_X_NEXT
    ; coll_mesh_ptr (ROM+21); 0 = floor-only, no walls → no horizontal push
    LDD 21,X
    LBEQ LCOL_X_NEXT
    ; cache obj_x / obj_y for local→world conversion (X stays = obj ptr)
    LDD 1,X
    STD >LCOL_LOCAL_PX  ; reuse scratch as obj_x
    LDD 3,X
    STD >LCOL_OBJ_Y     ; obj_y
    ; navigate mesh: skip floor section to reach wall_count
    LDD 21,X
    TFR D,Y             ; Y = mesh ptr
    LDD ,Y              ; floor_count (FDB)
    ASLB
    ROLA
    ASLB
    ROLA
    ASLB
    ROLA               ; D = floor_count * 8 (bytes per floor seg)
    ADDD #2            ; + the floor_count word itself
    LEAY D,Y           ; Y -> wall_count
    LDD ,Y             ; wall_count (FDB)
    STB >LCOL_SEG_CNT  ; low byte (walls are few)
    LBEQ LCOL_X_NEXT   ; no walls
    LEAY 2,Y           ; Y -> first wall segment
LCOL_X_WALL:
    LDB >LCOL_SEG_CNT
    LBEQ LCOL_X_NEXT
    ; wall segment: x=,Y ymin=2,Y ymax=6,Y (local coords)
    LDD ,Y
    ADDD >LCOL_LOCAL_PX ; world_wall_x = x + obj_x
    STD >TMPVAL         ; TMPVAL = world_wall_x
    ; Y-overlap lower bound: skip if py <= world_y_min - player_hh
    LDD 2,Y
    ADDD >LCOL_OBJ_Y    ; world_y_min
    SUBB >LCOL_PHH
    SBCA #0             ; world_y_min - player_hh
    STD >TMPPTR
    LDD >LCOL_PY
    CMPD >TMPPTR
    LBLE LCOL_X_WALL_ADV ; py below wall
    ; Y-overlap upper bound: skip if py >= world_y_max + player_hh
    LDD 6,Y
    ADDD >LCOL_OBJ_Y    ; world_y_max
    ADDB >LCOL_PHH
    ADCA #0             ; world_y_max + player_hh
    STD >TMPPTR
    LDD >LCOL_PY
    CMPD >TMPPTR
    LBGE LCOL_X_WALL_ADV ; py above wall
    ; X-overlap: dx_raw = px - world_wall_x
    LDD >LCOL_PX
    SUBD >TMPVAL
    STD >TMPPTR         ; dx_raw (signed 16-bit; hi byte = sign)
    BPL LCOL_X_DXP
    COMA
    COMB
    ADDD #1             ; D = |dx_raw|
LCOL_X_DXP:
    TSTA
    LBNE LCOL_X_WALL_ADV ; |dx| > 255 → no overlap
    CMPB >LCOL_PHW
    LBHS LCOL_X_WALL_ADV ; |dx| >= player_hw → no overlap
    ; push_mag = player_hw - |dx|  (B = |dx|)
    LDA >LCOL_PHW
    PSHS B
    SUBA ,S+            ; A = player_hw - |dx|
    LDB >TMPPTR         ; B = dx_raw hi byte (sign)
    BMI LCOL_X_PUSH_LEFT
    ; push right (dx_raw >= 0): RESULT = +push_mag
    TFR A,B
    SEX
    STD RESULT
    BRA LCOL_X_WALL_ADV
LCOL_X_PUSH_LEFT:
    ; push left (dx_raw < 0): RESULT = -push_mag
    NEGA
    TFR A,B
    SEX
    STD RESULT
LCOL_X_WALL_ADV:
    LEAY 8,Y           ; next wall segment (4 FDB)
    DEC >LCOL_SEG_CNT
    LBNE LCOL_X_WALL
LCOL_X_NEXT:
    LEAX 23,X          ; next ROM object (stride 23)
    DEC >LCOL_OBJ_CNT
    LBNE LCOL_X_LOOP
LCOL_X_DONE:
    ; MULTIBANK: Restore original bank
    PULS A              ; A = saved bank
    STA >CURRENT_ROM_BANK
    STA $DF00           ; Restore bank
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
; ENEMY SYSTEM RUNTIME  (max 10 enemies, stride 28 bytes)
; ============================================================================
ENEMY_POOL_STRIDE EQU 28
ENEMY_POOL_MAX    EQU 10

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
POOL_DIR        EQU 17
POOL_SUB_STATE  EQU 18
POOL_AREA_IDX   EQU 19
POOL_IDLE_TIMER EQU 20
POOL_TRANS_TYPE EQU 21
POOL_TARGET_X_HI EQU 22
POOL_TARGET_X_LO EQU 23
POOL_FROMX_OR_VY_HI EQU 24
POOL_FROMX_OR_VY_LO EQU 25
POOL_FEET_OFFSET EQU 26
POOL_VY0_STASH EQU 27
;   POOL_FROMX_OR_VY (2) — WALK_TO_TAKEOFF: from_x (i16). AIRBORNE: vy (i16, low byte = i8 vy).
;   POOL_FEET_OFFSET (1) — set at SPAWN to enemy's sprite half-height. Used to snap
;     world_y = area.y + feet_offset on spawn and on land.
;   POOL_VY0_STASH (1) — initial vy of the in-progress transition (set at commit,
;     applied at takeoff). Comes from trans entry's vy0 byte (per-transition tuned).
;   POOL_DIR (1) — 0=facing right, 1=facing left. Written by UPDATE_ENEMIES when
;   patrol moves the enemy on X (LBGT path = right, LBLT/SUB path = left). Read by
;   DRAW_ENEMIES into MIRROR_X so the sprite reflects the current direction.
;   POOL_SUB_STATE (1) — wander only. 0=WALK, 1=IDLE, 2=AIRBORNE, 3=WALK_TO_TAKEOFF
;   POOL_AREA_IDX (1) — wander only. Current area index into level's AREAS table.
;   POOL_IDLE_TIMER (1) — wander only. Frames remaining in idle. Decremented each
;   frame while sub_state=1; on expire either commits a transition or returns to WALK.
;   POOL_TRANS_TYPE (1) — wander only. Type of in-progress transition: 1=jump_up, 2=drop, 3=jump_across.
;   POOL_TARGET_X (2) — wander only. Target X stashed at transition commit (i16).
;   POOL_VY (2) — wander only. AIRBORNE: signed vertical velocity (i16, only low byte typically used).
;     WALK_TO_TAKEOFF: stores from_x in same slot since vy isn't used yet.
; For wander enemies, wp_ptr (pool +11..12) is reused as areas_ptr (points to
;   _LVL_AREAS_HEADER), and wp_count (pool +16) holds area_count.
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
; Entry: B = total ROM instance count, X = ptr to instances table.
; Per-screen reuse (mirrors pitrex): only spawn enemies whose world Y is
; within +/-150 of CAMERA_Y, capped at the pool size (10).
LBEQ SPAWN_ENE_DONE
STB >ENEMY_LOOP_IDX        ; scan counter = total ROM entries to examine
; Zero-clear ALL pool slots so stale enemies from the previous screen vanish
LDY #ENEMY_POOL
LDB #10
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
STA ,Y+                    ; +17 dir (clears to 0=right)
STA ,Y+                    ; +18 sub_state (clears to 0=WALK)
STA ,Y+                    ; +19 cur_area_idx (clears to 0)
STA ,Y+                    ; +20 idle_timer (clears to 0)
STA ,Y+                    ; +21 trans_type (clears to 0)
STA ,Y+                    ; +22 target_x hi
STA ,Y+                    ; +23 target_x lo
STA ,Y+                    ; +24 from_x/vy hi
STA ,Y+                    ; +25 from_x/vy lo
STA ,Y+                    ; +26 feet_offset (set by SPAWN_FILL for wander)
STA ,Y+                    ; +27 pad
DECB
BNE SPAWN_CLR_LOOP
CLR >ENEMY_COUNT           ; spawned (in-range) count = 0
LDX >LEVEL_ENEMY_INSTANCES_PTR
STX >ENEMY_SCRATCH_PTR
LDY #ENEMY_POOL
SPAWN_SCAN_LOOP:
LDX >ENEMY_SCRATCH_PTR
LDD 4,X                    ; D = instance world Y (offset +4,+5)
SUBD >CAMERA_Y             ; D = spawn_y - camera_y
CMPD #150
LBGT SPAWN_SKIP            ; off-screen below (signed)
CMPD #$FF6A                ; -150: off-screen above (signed)
LBLT SPAWN_SKIP
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
; Wander (ai_type=4) starts in walk action and copies feet_offset+area_idx.
; CRITICAL: X is currently type_ptr or SM_state record (clobbered by SM init).
; Must reload X = ENEMY_SCRATCH_PTR (instance ptr) before reading instance bytes.
LDA 8,Y             ; ai_type
CMPA #4
BNE SPAWN_ACT_DONE
LDA #1
STA 7,Y             ; action=1 (walk)
LDX >ENEMY_SCRATCH_PTR  ; X = instance ptr (was clobbered by SM init)
LDA 12,X            ; instance.feet_offset (instance +12)
STA 26,Y            ; pool.feet_offset
LDA 13,X            ; instance.initial_area_idx (instance +13)
STA 19,Y            ; pool.cur_area_idx
SPAWN_ACT_DONE:
; filled a slot: advance pool ptr, bump spawned count, stop if pool full
LEAY 28,Y
INC >ENEMY_COUNT
LDA >ENEMY_COUNT
CMPA #10
BHS SPAWN_ENE_DONE         ; pool full -> stop scanning
SPAWN_SKIP:
; advance to next ROM instance (stride 14) and keep scanning
LDX >ENEMY_SCRATCH_PTR
LEAX 14,X
STX >ENEMY_SCRATCH_PTR
DEC >ENEMY_LOOP_IDX
LBNE SPAWN_SCAN_LOOP
SPAWN_ENE_DONE:
RTS

; UPDATE_ENEMIES_RUNTIME (multibank)
; Patrol (ai_type=1): waypoint loop. Wander (ai_type=4): area-based state machine.
; Areas table (per level, in level bank) format:
;   +0  FCB area_count
;   +1  FCB trans_count
;   +2  area[0]: FDB y, FDB x_min, FDB x_max, FCB pad, FCB pad (8 bytes)
;   +2+area_count*8: trans[0]: FCB from, FCB to, FCB type, FCB pad, FDB from_x, FDB to_x
; Wander pool fields:
;   +18 sub_state: 0=WALK 1=IDLE 2=AIRBORNE 3=WALK_TO_TAKEOFF
;   +19 cur_area_idx (set to target at commit)
;   +20 idle_timer (IDLE)
;   +21 trans_type (1=jump_up 2=drop 3=jump_across)
;   +22..23 target_x (to_x stashed at commit)
;   +24    airborne_timer / pad
;   +25    vy (i8, AIRBORNE)
;   +26    feet_offset
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
; ── SM auto-decay tick: walks states back through their declared decay_to
; chain at the cadence set by each state's decay_frames in the .venemy.
; Runs BEFORE the frozen-action guard so reaching state 0 (normal) can
; release the enemy in the same frame.
JSR UPD_DECAY_CHECK
; ── Frozen-action guard: action 0=idle, 1=walk are 'live'.
; Any action >= 2 (snow1, snow2, ball, ...) means the SM has frozen the
; enemy in place (snowed/captured). Skip all movement so it stays put,
; drawn with its current snowed sprite by DRAW_ENEMIES.
LDA 7,Y             ; pool.action
CMPA #2
LBHS UPD_ENE_NEXT_POP
LDA 8,Y             ; ai_type
CMPA #1
LBEQ UPD_PATROL
CMPA #4
LBEQ UPD_WANDER
LBRA UPD_ENE_NEXT_POP

; ============ PATROL (waypoint-based) ============
UPD_PATROL:
LDA 11,Y
LDB 12,Y
CMPD #0
LBEQ UPD_ENE_NEXT_POP
TFR D,X             ; X = wp_ptr base
LDA 10,Y            ; wp_idx
ASLA
ASLA                ; * 4 bytes per waypoint
LEAX A,X            ; X = &wp[wp_idx]
LDD ,X              ; target_x
CMPD 1,Y
LBEQ UPD_P_MOVE_Y
LBGT UPD_P_INC_X
LDD 1,Y
SUBD #1
STD 1,Y
LDA #1
STA 17,Y
LBRA UPD_P_MOVE_Y
UPD_P_INC_X:
LDD 1,Y
ADDD #1
STD 1,Y
CLR 17,Y
UPD_P_MOVE_Y:
LDD 2,X             ; target_y
CMPD 3,Y
LBEQ UPD_P_CHECK_WP
LBGT UPD_P_INC_Y
LDD 3,Y
SUBD #1
STD 3,Y
LBRA UPD_ENE_NEXT_POP
UPD_P_INC_Y:
LDD 3,Y
ADDD #1
STD 3,Y
LBRA UPD_ENE_NEXT_POP
UPD_P_CHECK_WP:
LDD ,X
CMPD 1,Y
LBNE UPD_ENE_NEXT_POP
INC 10,Y
LDA 10,Y
CMPA 16,Y
LBLO UPD_ENE_NEXT_POP
CLR 10,Y
LBRA UPD_ENE_NEXT_POP

; ============ WANDER (area-based state machine) ============
UPD_WANDER:
LDA 18,Y            ; sub_state
LBEQ UPD_W_WALK
CMPA #1
LBEQ UPD_W_IDLE
CMPA #2
LBEQ UPD_W_AIR
CMPA #3
LBEQ UPD_W_TT
LBRA UPD_ENE_NEXT_POP

UPD_W_WALK:
LDA 11,Y
LDB 12,Y
CMPD #0
LBEQ UPD_ENE_NEXT_POP
TFR D,X             ; X = areas_header_ptr
LDB 19,Y            ; cur_area_idx
LDA #8
MUL                 ; D = idx*8
ADDD #2             ; +2 to skip header
LEAX D,X            ; X = &area[idx]
LDA 17,Y            ; POOL_DIR
LBNE UPD_W_WALK_L
; dir=0 right: walk +1, clamp to x_max
LDD 1,Y
ADDD #1
PSHS D              ; save proposed x
LDD 4,X             ; x_max
CMPD ,S
LBLT UPD_W_EDGE_R   ; proposed > x_max → edge
PULS D
STD 1,Y
LBRA UPD_ENE_NEXT_POP
UPD_W_EDGE_R:
LEAS 2,S
LDD 4,X             ; clamp to x_max
STD 1,Y
LBRA UPD_W_EDGE
UPD_W_WALK_L:
LDD 1,Y
SUBD #1
PSHS D
LDD 2,X             ; x_min
CMPD ,S
LBGT UPD_W_EDGE_L
PULS D
STD 1,Y
LBRA UPD_ENE_NEXT_POP
UPD_W_EDGE_L:
LEAS 2,S
LDD 2,X             ; clamp to x_min
STD 1,Y
UPD_W_EDGE:
; Reached an edge: flip dir, enter IDLE
LDA 17,Y
EORA #1
STA 17,Y
LDA #1
STA 18,Y            ; sub_state = IDLE
CLR 7,Y             ; action = idle
JSR RAND_HELPER
ANDB #$3F
ADDB #90
STB 20,Y            ; idle_timer
LBRA UPD_ENE_NEXT_POP

UPD_W_IDLE:
DEC 20,Y
LBNE UPD_ENE_NEXT_POP
; Idle expired: try a transition (25% chance per matching entry)
LDA 11,Y
LDB 12,Y
TFR D,X             ; X = areas_header_ptr
LDB 1,X             ; trans_count
LBEQ UPD_W_TO_WALK
PSHS B              ; save trans_count
LDA ,X              ; area_count
LDB #8
MUL                 ; D = area_count*8
ADDD #2
LEAX D,X            ; X = trans_ptr (start of trans array)
PULS B              ; B = trans_count (loop counter)
UPD_W_TRY_LOOP:
LDA 19,Y            ; cur_area_idx
CMPA ,X             ; trans.from
BNE UPD_W_NEXT_TRY
; Match: roll 25% chance
PSHS B,X
JSR RAND_HELPER
ANDB #3
TSTB
PULS B,X
BNE UPD_W_NEXT_TRY
; Commit transition: X = &trans[matched]
LDA 1,X
STA 19,Y            ; cur_area_idx = to
LDA 2,X
STA 21,Y            ; trans_type
LDA 3,X
STA 27,Y            ; vy0_stash (precomputed by compiler for this transition)
LDD 4,X
STD 24,Y            ; from_x stashed at pool+24..25
LDD 6,X
STD 22,Y            ; target_x at pool+22..23
LDA #3
STA 18,Y            ; sub_state = WALK_TO_TAKEOFF
LDA #1
STA 7,Y             ; action = walk
LBRA UPD_ENE_NEXT_POP
UPD_W_NEXT_TRY:
LEAX 8,X
DECB
BNE UPD_W_TRY_LOOP
UPD_W_TO_WALK:
CLR 18,Y            ; sub_state = WALK
LDA #1
STA 7,Y             ; action = walk
LBRA UPD_ENE_NEXT_POP

UPD_W_TT:
; WALK_TO_TAKEOFF: walk X-only toward from_x at pool+24..25
LDD 24,Y            ; from_x
CMPD 1,Y
LBEQ UPD_W_TT_REACHED
LBGT UPD_W_TT_RIGHT
; cur_x > from_x: walk left
LDD 1,Y
SUBD #1
STD 1,Y
LDA #1
STA 17,Y
LBRA UPD_ENE_NEXT_POP
UPD_W_TT_RIGHT:
LDD 1,Y
ADDD #1
STD 1,Y
CLR 17,Y
LBRA UPD_ENE_NEXT_POP
UPD_W_TT_REACHED:
; Arrived at from_x: load precomputed vy0 and enter AIRBORNE.
LDA 27,Y            ; vy0_stash (set at commit from trans entry)
STA 25,Y            ; vy (i8)
LDA #120
STA 24,Y            ; airborne timeout (frames)
; Face toward target_x
LDD 22,Y
CMPD 1,Y
LBGT UPD_W_TT_FACE_R
LDA #1
STA 17,Y
LBRA UPD_W_TT_AIR
UPD_W_TT_FACE_R:
CLR 17,Y
UPD_W_TT_AIR:
LDA #2
STA 18,Y            ; sub_state = AIRBORNE
LBRA UPD_ENE_NEXT_POP

UPD_W_AIR:
; Check timeout first
DEC 24,Y
LBEQ UPD_W_AIR_LAND
; X interp toward target_x by 2 px/frame
LDD 22,Y
CMPD 1,Y
LBEQ UPD_W_AIR_Y    ; x at target
LBGT UPD_W_AIR_X_R
LDD 1,Y
SUBD #2
CMPD 22,Y
LBGT UPD_W_AIR_X_OKL
LDD 22,Y
UPD_W_AIR_X_OKL:
STD 1,Y
LBRA UPD_W_AIR_Y
UPD_W_AIR_X_R:
LDD 1,Y
ADDD #2
CMPD 22,Y
LBLT UPD_W_AIR_X_OKR
LDD 22,Y
UPD_W_AIR_X_OKR:
STD 1,Y
UPD_W_AIR_Y:
; y += vy (sign-extended), vy -= 1, clamp vy >= -4
LDB 25,Y
SEX                 ; D = signed vy
ADDD 3,Y
STD 3,Y
LDB 25,Y
DECB
CMPB #$FC           ; -4
BGE UPD_W_AIR_VYOK
LDB #$FC
UPD_W_AIR_VYOK:
STB 25,Y
; Check land: compute target_y = areas[cur_area].y + feet_offset and compare
LDA 11,Y
LDB 12,Y
TFR D,X
LDB 19,Y
LDA #8
MUL
ADDD #2
LEAX D,X            ; X = &area[cur_area_idx] (target)
LDB 26,Y            ; B = feet_offset (low byte)
CLRA                ; A = 0 (high byte)
ADDD ,X             ; D = feet_offset + area.y (16-bit at X)
; If trans_type=2 (drop) or vy<=0 (descending): land if cur_y <= target_y
; Else (ascending jump_up): just keep going
PSHS D              ; stash target_y (we'll need it twice)
LDA 21,Y
CMPA #2
BEQ UPD_W_AIR_CHK_DOWN
LDB 25,Y
TSTB
BPL UPD_W_AIR_NOLAND
UPD_W_AIR_CHK_DOWN:
LDD ,S              ; reload target_y
CMPD 3,Y            ; target_y vs cur_y
LBLT UPD_W_AIR_NOLAND  ; target_y < cur_y → still above
; cur_y <= target_y: land — snap and switch to WALK
PULS D              ; D = target_y
STD 3,Y             ; snap world_y
CLR 18,Y            ; sub_state = WALK
LDA #1
STA 7,Y             ; action = walk
LBRA UPD_ENE_NEXT_POP
UPD_W_AIR_NOLAND:
LEAS 2,S            ; discard saved target_y
LBRA UPD_ENE_NEXT_POP
UPD_W_AIR_LAND:
; Timeout path: recompute target_y, snap, switch to WALK
LDA 11,Y
LDB 12,Y
TFR D,X
LDB 19,Y
LDA #8
MUL
ADDD #2
LEAX D,X
LDB 26,Y
CLRA
ADDD ,X             ; D = feet_offset + area.y
STD 3,Y
CLR 18,Y            ; sub_state = WALK
LDA #1
STA 7,Y             ; action = walk
LBRA UPD_ENE_NEXT_POP

UPD_ENE_NEXT_POP:
PULS B              ; restore loop counter
LEAY 28,Y           ; next pool record
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
; screen_x = world_x(16-bit) - camera_x(16-bit), y unchanged
LDA 1,Y             ; world_x hi (POOL_X_HI)
LDB 2,Y             ; world_x lo (POOL_X_LO)
SUBD >CAMERA_X      ; D = world_x - camera_x (16-bit)
STA >TMPPTR2        ; save high byte for range check
TFR B,A
SEX                 ; A = sign-extend of B (0x00 or 0xFF)
CMPA >TMPPTR2       ; compare with actual high byte
LBNE DRW_ENE_NEXT_POP  ; out of 8-bit range — skip draw
STB >DRAW_VEC_X
CLR >DRAW_VEC_X_HI
LDB 4,Y             ; world_y lo (POOL_Y_LO)
STB >DRAW_VEC_Y
; Mirror: 0 = facing right (no mirror), 1 = facing left (flip X).
; POOL_DIR is set by UPDATE_ENEMIES based on patrol movement.
; Set BOTH MIRROR_X (vec path → DSWM) and DRAW_ANIM_MIRROR_X. DRAW_ANIM_BANKED
; clears MIRROR_X at entry so animated sprites need the persistent ANIM flag
; which DRAW_ANIM_RUNTIME re-applies to MIRROR_X for each frame's path loop.
LDA 17,Y            ; POOL_DIR (0=right, 1=left)
STA >MIRROR_X
STA >DRAW_ANIM_MIRROR_X
CLR >MIRROR_Y
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
LEAY 28,Y           ; next pool record
DECB
LBNE DRW_ENE_LOOP
DRW_ENE_DONE:
RTS


; KILL_ENEMY_RUNTIME
; Entry: A = enemy index (0-based)
; Effect: pool[A].active=0, ENEMY_COUNT--
; Return: RESULT = new ENEMY_COUNT (D)
KILL_ENEMY_RUNTIME:
LDB #28             ; ENEMY_POOL_STRIDE
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

; SET_ENEMY_STATE_RUNTIME
; Entry: A = enemy idx, B = target state_idx
; Thin wrapper: compute pool ptr from idx, then dispatch to SES_APPLY which
; does the actual state-record lookup and field writes. SES_APPLY is also
; called from UPD_DECAY_CHECK (auto-decay) using Y-derived pool ptr.
SET_ENEMY_STATE_RUNTIME:
STB >ENEMY_SCRATCH_X    ; save target state_idx
LDB #28                 ; ENEMY_POOL_STRIDE
MUL
LDX #ENEMY_POOL
LEAX D,X                ; X = &pool[idx]
STX >ENEMY_SCRATCH_PTR
JMP SES_APPLY

; SES_APPLY: apply a state transition to a pool entry.
; Entry: ENEMY_SCRATCH_PTR = pool entry ptr, ENEMY_SCRATCH_X = target_state_idx
; Updates pool.sm_state (+13), pool.action (+7) [unless action_idx=$FF=keep],
; and pool.sm_decay_timer (+14..15) from the type's SM state record.
; Falls back to plain STB 13,X if no SM exists. Preserves Y.
SES_APPLY:
LDX >ENEMY_SCRATCH_PTR
LDA 13,X                ; current sm_state
CMPA #$FF
BEQ SES_PLAIN           ; no SM → just store the byte
LDA 5,X                 ; type_ptr hi
LDB 6,X                 ; type_ptr lo
TFR D,X                 ; X = type header
LDA 5,X                 ; SM ptr hi
LDB 6,X                 ; SM ptr lo
CMPD #0
BEQ SES_PLAIN
TFR D,X                 ; X = SM header
LEAX 2,X                ; X = &states[0]
LDA >ENEMY_SCRATCH_X    ; target state_idx
LDB #13
MUL                     ; D = target * 13
LEAX D,X                ; X = &states[target]
LDA 1,X
LDB 2,X
STD >ENEMY_SCRATCH_Y    ; stash decay hi+lo
LDA ,X                  ; action_idx ($FF = keep)
PSHS A
LDX >ENEMY_SCRATCH_PTR  ; X = pool entry
LDB >ENEMY_SCRATCH_X    ; target state_idx
STB 13,X                ; pool.sm_state = target
PULS A
CMPA #$FF
BEQ SES_SKIP_ACTION
STA 7,X                 ; pool.action = state.action
SES_SKIP_ACTION:
LDA >ENEMY_SCRATCH_Y
STA 14,X                ; sm_decay_timer hi
LDA >ENEMY_SCRATCH_Y+1
STA 15,X                ; sm_decay_timer lo
RTS
SES_PLAIN:
LDX >ENEMY_SCRATCH_PTR
LDB >ENEMY_SCRATCH_X
STB 13,X
RTS

; UPD_DECAY_CHECK: auto-decay tick for one pool entry.
; Entry: Y = &pool[i] (preserved on exit)
; If pool.sm_decay_timer > 0: decrement. On reaching 0, look up the current
; state's decay_to_idx (state record offset +3) and apply that transition
; via SES_APPLY. If decay_to is $FF (none) the state stays put.
; Honours the per-state decay_frames declared in the .venemy SM, so SnowBros
; thaw walks ball→snow2→snow1→normal automatically with their own timings.
UPD_DECAY_CHECK:
LDD 14,Y                ; sm_decay_timer
LBEQ UDC_DONE           ; not decaying
SUBD #1
STD 14,Y
LBNE UDC_DONE           ; still counting
; Timer hit 0 → resolve current state's decay_to
LDA 5,Y
LDB 6,Y
TFR D,X                 ; X = type header
LDA 5,X
LDB 6,X
CMPD #0
BEQ UDC_DONE            ; no SM (defensive)
TFR D,X                 ; X = SM header
LEAX 2,X                ; X = &states[0]
LDA 13,Y                ; current sm_state
LDB #13
MUL
LEAX D,X                ; X = &states[current]
LDA 3,X                 ; decay_to_idx
CMPA #$FF
BEQ UDC_DONE            ; no decay target
; Apply transition via SES_APPLY (preserves Y)
STA >ENEMY_SCRATCH_X    ; target = decay_to_idx
STY >ENEMY_SCRATCH_PTR  ; pool ptr = current Y
JSR SES_APPLY
UDC_DONE:
RTS

;**** PRINT_TEXT String Data ****
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

PRINT_TEXT_STR_3030638503962359:
    FCC "onFireDown"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3030638504402860:
    FCC "onFireSide"
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

PRINT_TEXT_STR_10932524847759564817:
    FCC "frog_fireball_down"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_10932524847760005318:
    FCC "frog_fireball_side"
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
TRAMP_on_player_death:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR on_player_death
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
TRAMP_update_frog_fire:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$01  ; switch to bank #1
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR update_frog_fire
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_update_frog_bullet:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$01  ; switch to bank #1
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR update_frog_bullet
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

; Array literal for variable 'frog_fire_timer' (8 elements, 2 bytes each)
ARRAY_FROG_FIRE_TIMER_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'frog_fire_decay' (8 elements, 2 bytes each)
ARRAY_FROG_FIRE_DECAY_DATA:
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

