; VPy M6809 Assembly (Vectrex)
; ROM: 131072 bytes
; Multibank cartridge: 8 banks (16KB each)
; Helpers bank: 7 (fixed bank at $4000-$7FFF)

; ================================================


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

; VPy M6809 Assembly (Vectrex)
; ROM: 131072 bytes
; Multibank cartridge: 8 banks (16KB each)
; Helpers bank: 7 (fixed bank at $4000-$7FFF)

; ================================================

    ORG $0000

;***************************************************************************
; DEFINE SECTION
;***************************************************************************
    INCLUDE "VECTREX.I"
; External symbols (helpers, BIOS, and shared data)
ABS_A_B EQU $F584
ABS_B EQU $F58B
ADD_SCORE_A EQU $F85E
ADD_SCORE_D EQU $F87C
ANIM_ADDR_TABLE EQU $4085
ANIM_BANK_TABLE EQU $4081
ARRAY_BALL_BOUNCES_DATA EQU $6852
ARRAY_BALL_COLLIDED_DATA EQU $6862
ARRAY_BALL_ROLLING_DATA EQU $6822
ARRAY_BALL_VX_ARR_DATA EQU $6832
ARRAY_BALL_VY_ARR_DATA EQU $6842
ARRAY_FROG_FIRE_DECAY_DATA EQU $6812
ARRAY_FROG_FIRE_TIMER_DATA EQU $6802
ARRAY_THAW_TIMERS_DATA EQU $67F2
ASSET_ADDR_TABLE EQU $420E
ASSET_BANK_TABLE EQU $41E3
AUDIO_UPDATE EQU $5D51
AU_BANK_OK EQU $5D6B
AU_DONE EQU $5E0F
AU_MUSIC_DONE EQU $5DE2
AU_MUSIC_ENDED EQU $5DE8
AU_MUSIC_HAS_DELAY EQU $5DA9
AU_MUSIC_LOOP EQU $5DEE
AU_MUSIC_NO_DELAY EQU $5D9A
AU_MUSIC_PROCESS_WRITES EQU $5DB7
AU_MUSIC_READ EQU $5D89
AU_MUSIC_READ_COUNT EQU $5D9A
AU_MUSIC_WRITE_LOOP EQU $5DB9
AU_SKIP_MUSIC EQU $5DF9
AU_UPDATE_SFX EQU $5DFC
Abs_a_b EQU $F584
Abs_b EQU $F58B
Add_Score_a EQU $F85E
Add_Score_d EQU $F87C
BITMASK_A EQU $F57E
Bitmask_a EQU $F57E
CHECK0REF EQU $F34F
CLEAR_C8_RAM EQU $F542
CLEAR_SCORE EQU $F84F
CLEAR_SOUND EQU $F272
CLEAR_X_256 EQU $F545
CLEAR_X_B EQU $F53F
CLEAR_X_B_80 EQU $F550
CLEAR_X_B_A EQU $F552
CLEAR_X_D EQU $F548
COLD_START EQU $F000
COMPARE_SCORE EQU $F8C7
Check0Ref EQU $F34F
Clear_C8_RAM EQU $F542
Clear_Score EQU $F84F
Clear_Sound EQU $F272
Clear_x_256 EQU $F545
Clear_x_b EQU $F53F
Clear_x_b_80 EQU $F550
Clear_x_b_a EQU $F552
Clear_x_d EQU $F548
Cold_Start EQU $F000
Compare_Score EQU $F8C7
DAR_BASE_LOOP EQU $5ED5
DAR_BASE_PATH_LOOP EQU $5EE7
DAR_BASE_SKIP EQU $5EF9
DAR_DONE EQU $5FF8
DAR_DRAW EQU $5F84
DAR_EMIT EQU $5F94
DAR_FREEZE EQU $5F4A
DAR_INIT EQU $5F5F
DAR_INLINE EQU $5FC9
DAR_NO_WRAP EQU $5F22
DAR_PATH_DONE EQU $5FF1
DAR_PATH_LOOP EQU $5FCF
DAR_SCAN EQU $5FDE
DAR_SPEED1 EQU $5F3D
DAR_SPEED1_OK EQU $5F45
DAR_SPEED2 EQU $5F77
DAR_SPEED2_OK EQU $5F7F
DAR_TICK EQU $5F05
DAR_VEC_DONE EQU $5FBD
DAR_VEC_LOOP EQU $5F9C
DAR_VEC_PATH_LOOP EQU $5FAB
DCR_AFTER_INTENSITY EQU $543A
DCR_INTENSITY_5F EQU $5437
DCR_after_intensity EQU $543A
DCR_intensity_5F EQU $5437
DEC_3_COUNTERS EQU $F55A
DEC_6_COUNTERS EQU $F55E
DEC_COUNTERS EQU $F563
DELAY_0 EQU $F579
DELAY_1 EQU $F575
DELAY_2 EQU $F571
DELAY_3 EQU $F56D
DELAY_B EQU $F57A
DELAY_RTS EQU $F57D
DIV16 EQU $52F9
DIV16.D16_DONE EQU $5363
DIV16.D16_DPOS EQU $5316
DIV16.D16_END EQU $5354
DIV16.D16_LOOP EQU $533B
DIV16.D16_RCHECK EQU $531E
DIV16.D16_RPOS EQU $5335
DOT_D EQU $F2C3
DOT_HERE EQU $F2C5
DOT_IX EQU $F2C1
DOT_IX_B EQU $F2BE
DOT_LIST EQU $F2D5
DOT_LIST_RESET EQU $F2DE
DO_SOUND EQU $F289
DO_SOUND_X EQU $F28C
DP_TO_C8 EQU $F1AF
DP_TO_D0 EQU $F1AA
DP_to_C8 EQU $F1AF
DP_to_D0 EQU $F1AA
DRAW_ANIM_BANKED EQU $436E
DRAW_ANIM_RUNTIME EQU $5EBF
DRAW_CIRCLE_RUNTIME EQU $5402
DRAW_ENEMIES_RUNTIME EQU $63F7
DRAW_GRID_VL EQU $FF9F
DRAW_LINE_D EQU $F3DF
DRAW_PAT_VL EQU $F437
DRAW_PAT_VL_A EQU $F434
DRAW_PAT_VL_D EQU $F439
DRAW_SYNC_LIST_AT_WITH_MIRRORS EQU $5553
DRAW_VECTOR_BANKED EQU $4264
DRAW_VL EQU $F3DD
DRAW_VLC EQU $F3CE
DRAW_VLCS EQU $F3D6
DRAW_VLP EQU $F410
DRAW_VLP_7F EQU $F408
DRAW_VLP_B EQU $F40E
DRAW_VLP_FF EQU $F404
DRAW_VLP_SCALE EQU $F40C
DRAW_VL_A EQU $F3DA
DRAW_VL_AB EQU $F3D8
DRAW_VL_B EQU $F3D2
DRAW_VL_MODE EQU $F46E
DRW_ENE_DONE EQU $649E
DRW_ENE_LOOP EQU $6402
DRW_ENE_NEXT_POP EQU $6494
DRW_ENE_VANIM EQU $6477
DSWM_DONE EQU $56A6
DSWM_LOOP EQU $55CE
DSWM_NEXT_NO_NEGATE_X EQU $5644
DSWM_NEXT_NO_NEGATE_Y EQU $5637
DSWM_NEXT_PATH EQU $5619
DSWM_NEXT_SET_INTENSITY EQU $562B
DSWM_NEXT_USE_OVERRIDE EQU $5629
DSWM_NO_NEGATE_DX EQU $55F0
DSWM_NO_NEGATE_DY EQU $55E6
DSWM_NO_NEGATE_X EQU $557B
DSWM_NO_NEGATE_Y EQU $556E
DSWM_SET_INTENSITY EQU $5561
DSWM_USE_OVERRIDE EQU $555F
DSWM_W1 EQU $55C5
DSWM_W2 EQU $5607
DSWM_W3 EQU $569A
DVB_DONE EQU $42A4
DVB_PATH_LOOP EQU $4292
Dec_3_Counters EQU $F55A
Dec_6_Counters EQU $F55E
Dec_Counters EQU $F563
Delay_0 EQU $F579
Delay_1 EQU $F575
Delay_2 EQU $F571
Delay_3 EQU $F56D
Delay_RTS EQU $F57D
Delay_b EQU $F57A
Do_Sound EQU $F289
Do_Sound_x EQU $F28C
Dot_List EQU $F2D5
Dot_List_Reset EQU $F2DE
Dot_d EQU $F2C3
Dot_here EQU $F2C5
Dot_ix EQU $F2C1
Dot_ix_b EQU $F2BE
Draw_Grid_VL EQU $FF9F
Draw_Line_d EQU $F3DF
Draw_Pat_VL EQU $F437
Draw_Pat_VL_a EQU $F434
Draw_Pat_VL_d EQU $F439
Draw_Sync_List_At_With_Mirrors EQU $5553
Draw_VL EQU $F3DD
Draw_VL_a EQU $F3DA
Draw_VL_ab EQU $F3D8
Draw_VL_b EQU $F3D2
Draw_VL_mode EQU $F46E
Draw_VLc EQU $F3CE
Draw_VLcs EQU $F3D6
Draw_VLp EQU $F410
Draw_VLp_7F EQU $F408
Draw_VLp_FF EQU $F404
Draw_VLp_b EQU $F40E
Draw_VLp_scale EQU $F40C
ENEMY_ADDR_TABLE EQU $4091
ENEMY_BANK_TABLE EQU $408D
ENEMY_FIRE_EVENT_RUNTIME EQU $64B4
EXPLOSION_SND EQU $F92E
Explosion_Snd EQU $F92E
FIRE_EVT_MATCH EQU $6509
FIRE_EVT_RTS EQU $6545
FIRE_EVT_SCAN EQU $64F9
GET_LEVEL_FLOOR_Y_RUNTIME EQU $56A7
GET_RISE_IDX EQU $F5D9
GET_RISE_RUN EQU $F5EF
GET_RUN_IDX EQU $F5DB
GLFYR_NO_LEVEL EQU $56D3
Get_Rise_Idx EQU $F5D9
Get_Rise_Run EQU $F5EF
Get_Run_Idx EQU $F5DB
INIT_MUSIC EQU $F68D
INIT_MUSIC_BUF EQU $F533
INIT_MUSIC_CHK EQU $F687
INIT_MUSIC_X EQU $F692
INIT_OS EQU $F18B
INIT_OS_RAM EQU $F164
INIT_VIA EQU $F14C
INTENSITY_1F EQU $F29D
INTENSITY_3F EQU $F2A1
INTENSITY_5F EQU $F2A5
INTENSITY_7F EQU $F2A9
INTENSITY_A EQU $F2AB
Init_Music EQU $F68D
Init_Music_Buf EQU $F533
Init_Music_chk EQU $F687
Init_Music_x EQU $F692
Init_OS EQU $F18B
Init_OS_RAM EQU $F164
Init_VIA EQU $F14C
Intensity_1F EQU $F29D
Intensity_3F EQU $F2A1
Intensity_5F EQU $F2A5
Intensity_7F EQU $F2A9
Intensity_a EQU $F2AB
J1X_BUILTIN EQU $53FA
JOY_ANALOG EQU $F1F5
JOY_DIGITAL EQU $F1F8
Joy_Analog EQU $F1F5
Joy_Digital EQU $F1F8
KILL_ENEMY_RUNTIME EQU $649F
LCOL_X_DONE EQU $5C26
LCOL_X_DXP EQU $5BE9
LCOL_X_LOOP EQU $5B62
LCOL_X_NEXT EQU $5C1C
LCOL_X_PUSH_LEFT EQU $5C0C
LCOL_X_WALL EQU $5B98
LCOL_X_WALL_ADV EQU $5C13
LCOL_Y_AABB EQU $5AEE
LCOL_Y_DONE EQU $5B12
LCOL_Y_LOOP EQU $5A5B
LCOL_Y_NEXT EQU $5B08
LCOL_Y_NOFLOOR EQU $5B25
LCOL_Y_RET EQU $5B28
LCOL_Y_SEG EQU $5AAE
LCOL_Y_SEG_ADV EQU $5AE1
LCOL_Y_SEG_DONE EQU $5AE9
LEVEL_ADDR_TABLE EQU $407F
LEVEL_BANK_TABLE EQU $407E
LEVEL_COLLISION_X_RUNTIME EQU $5B38
LEVEL_COLLISION_Y_RUNTIME EQU $5A31
LLR_COPY_DONE EQU $5797
LLR_COPY_LOOP EQU $5750
LLR_COPY_OBJECTS EQU $5750
LLR_GP_DONE EQU $5748
LLR_SKIP_GP EQU $5748
LOAD_LEVEL_BANKED EQU $4316
LOAD_LEVEL_RUNTIME EQU $56DD
MOD16 EQU $5364
MOD16.M16_DONE EQU $53B7
MOD16.M16_DPOS EQU $5381
MOD16.M16_END EQU $53A8
MOD16.M16_LOOP EQU $5398
MOD16.M16_RCHECK EQU $5389
MOD16.M16_RPOS EQU $5398
MOVETO_D EQU $F312
MOVETO_D_7F EQU $F2FC
MOVETO_IX EQU $F310
MOVETO_IX_7F EQU $F30C
MOVETO_IX_A EQU $F30E
MOVETO_IX_FF EQU $F308
MOVETO_X_7F EQU $F2F2
MOVE_MEM_A EQU $F683
MOVE_MEM_A_1 EQU $F67F
MOV_DRAW_VL EQU $F3BC
MOV_DRAW_VLCS EQU $F3B5
MOV_DRAW_VLC_A EQU $F3AD
MOV_DRAW_VL_A EQU $F3B9
MOV_DRAW_VL_AB EQU $F3B7
MOV_DRAW_VL_B EQU $F3B1
MOV_DRAW_VL_D EQU $F3BE
MUL16 EQU $52D1
MUSIC1 EQU $FD0D
MUSIC2 EQU $FD1D
MUSIC3 EQU $FD81
MUSIC4 EQU $FDD3
MUSIC5 EQU $FE38
MUSIC6 EQU $FE76
MUSIC7 EQU $FEC6
MUSIC8 EQU $FEF8
MUSIC9 EQU $FF26
MUSICA EQU $FF44
MUSICB EQU $FF62
MUSICC EQU $FF7A
MUSICD EQU $FF8F
MUSIC_ADDR_TABLE EQU $4071
MUSIC_BANK_TABLE EQU $406C
Mov_Draw_VL EQU $F3BC
Mov_Draw_VL_a EQU $F3B9
Mov_Draw_VL_ab EQU $F3B7
Mov_Draw_VL_b EQU $F3B1
Mov_Draw_VL_d EQU $F3BE
Mov_Draw_VLc_a EQU $F3AD
Mov_Draw_VLcs EQU $F3B5
Move_Mem_a EQU $F683
Move_Mem_a_1 EQU $F67F
Moveto_d EQU $F312
Moveto_d_7F EQU $F2FC
Moveto_ix EQU $F310
Moveto_ix_7F EQU $F30C
Moveto_ix_FF EQU $F308
Moveto_ix_a EQU $F30E
Moveto_x_7F EQU $F2F2
NEW_HIGH_SCORE EQU $F8D8
NOAY EQU $5E2D
New_High_Score EQU $F8D8
OBJ_HIT EQU $F8FF
OBJ_WILL_HIT EQU $F8F3
OBJ_WILL_HIT_U EQU $F8E5
Obj_Hit EQU $F8FF
Obj_Will_Hit EQU $F8F3
Obj_Will_Hit_u EQU $F8E5
PLAY_BOSS_MUSIC EQU $0D67
PLAY_MUSIC_BANKED EQU $42B0
PLAY_MUSIC_RUNTIME EQU $5C33
PLAY_SFX_BANKED EQU $42E8
PLAY_SFX_RUNTIME EQU $5E1A
PMR_DONE EQU $5C73
PMR_START_NEW EQU $5C41
PMr_done EQU $5C73
PMr_start_new EQU $5C41
PRINT_LIST EQU $F38A
PRINT_LIST_CHK EQU $F38C
PRINT_LIST_HW EQU $F385
PRINT_SHIPS EQU $F393
PRINT_SHIPS_X EQU $F391
PRINT_STR EQU $F495
PRINT_STR_D EQU $F37A
PRINT_STR_HWYX EQU $F373
PRINT_STR_YX EQU $F378
PRINT_TEXT_STR_100361836 EQU $65FC
PRINT_TEXT_STR_104652296222070 EQU $6632
PRINT_TEXT_STR_10932524847759564817 EQU $66F0
PRINT_TEXT_STR_10932524847760005318 EQU $6703
PRINT_TEXT_STR_13399742582312315532 EQU $6716
PRINT_TEXT_STR_17169778266052697977 EQU $6727
PRINT_TEXT_STR_17825111777351717868 EQU $6735
PRINT_TEXT_STR_1785516508540691 EQU $663C
PRINT_TEXT_STR_1842954771884826 EQU $6647
PRINT_TEXT_STR_1989933374265095120 EQU $66D4
PRINT_TEXT_STR_2073804707667 EQU $6602
PRINT_TEXT_STR_2453707043877 EQU $660B
PRINT_TEXT_STR_3030638503962359 EQU $6652
PRINT_TEXT_STR_3030638504402860 EQU $665D
PRINT_TEXT_STR_62413928761410 EQU $6614
PRINT_TEXT_STR_63323706877185 EQU $661E
PRINT_TEXT_STR_78166382 EQU $65F0
PRINT_TEXT_STR_78726770 EQU $65F6
PRINT_TEXT_STR_89062161292953211 EQU $6668
PRINT_TEXT_STR_9120385685437879118 EQU $66E1
PRINT_TEXT_STR_94739999784554063 EQU $6674
PRINT_TEXT_STR_94739999784554064 EQU $6680
PRINT_TEXT_STR_94739999784554065 EQU $668C
PRINT_TEXT_STR_94739999784554066 EQU $6698
PRINT_TEXT_STR_94739999784698482 EQU $66A4
PRINT_TEXT_STR_94739999784744652 EQU $66B0
PRINT_TEXT_STR_94739999785112679 EQU $66BC
PRINT_TEXT_STR_97104923643965900 EQU $66C8
PRINT_TEXT_STR_97774210848817 EQU $6628
PSG_EVENT_DONE EQU $5CEF
PSG_MUSIC_ENDED EQU $5CF8
PSG_MUSIC_LOOP EQU $5D13
PSG_MUSIC_LOOP_D EQU $5D1E
PSG_PROCESS_EVENT EQU $5CAD
PSG_READ_DELAY EQU $5C92
PSG_UPDATE_DONE EQU $5D26
PSG_WRITE_LOOP EQU $5CBE
PSG_event_done EQU $5CEF
PSG_music_ended EQU $5CF8
PSG_music_loop EQU $5D13
PSG_music_loop_d EQU $5D1E
PSG_process_event EQU $5CAD
PSG_read_delay EQU $5C92
PSG_update_done EQU $5D26
PSG_write_loop EQU $5CBE
Print_List EQU $F38A
Print_List_chk EQU $F38C
Print_List_hw EQU $F385
Print_Ships EQU $F393
Print_Ships_x EQU $F391
Print_Str EQU $F495
Print_Str_d EQU $F37A
Print_Str_hwyx EQU $F373
Print_Str_yx EQU $F378
RANDOM EQU $F517
RANDOM_3 EQU $F511
RAND_HELPER EQU $53B8
RAND_MUL_DONE EQU $53CE
RAND_MUL_LOOP EQU $53C3
RAND_RANGE_HELPER EQU $53D9
READ_BTNS EQU $F1BA
READ_BTNS_MASK EQU $F1B4
RECALIBRATE EQU $F2E6
RESET0INT EQU $F36B
RESET0REF EQU $F354
RESET0REF_D0 EQU $F34A
RESET_PEN EQU $F35B
RISE_RUN_ANGLE EQU $F593
RISE_RUN_LEN EQU $F603
RISE_RUN_X EQU $F5FF
RISE_RUN_Y EQU $F601
ROT_VL EQU $F616
ROT_VL_AB EQU $F610
ROT_VL_DFT EQU $F637
ROT_VL_MODE EQU $F62B
ROT_VL_MODE_A EQU $F61F
RRH_MOD EQU $53EC
Random EQU $F517
Random_3 EQU $F511
Read_Btns EQU $F1BA
Read_Btns_Mask EQU $F1B4
Recalibrate EQU $F2E6
Reset0Int EQU $F36B
Reset0Ref EQU $F354
Reset0Ref_D0 EQU $F34A
Reset_Pen EQU $F35B
Rise_Run_Angle EQU $F593
Rise_Run_Len EQU $F603
Rise_Run_X EQU $F5FF
Rise_Run_Y EQU $F601
Rot_VL EQU $F616
Rot_VL_Mode EQU $F62B
Rot_VL_Mode_a EQU $F61F
Rot_VL_ab EQU $F610
Rot_VL_dft EQU $F637
SDCP_ABS_OK EQU $596C
SDCP_CHECK_POS EQU $5967
SDCP_CLIP EQU $5A0A
SDCP_DONE EQU $5A30
SDCP_MOVETO_W EQU $59B9
SDCP_SEG_LOOP EQU $59C2
SDCP_SET_INTENS EQU $5941
SDCP_SKIP_PATH EQU $596B
SDCP_USE_OVERRIDE EQU $593F
SDCP_W_DRAW EQU $59FB
SDCP_W_MOVE EQU $5A24
SEB_DONE EQU $436D
SELECT_GAME EQU $F7A9
SES_APPLY EQU $6557
SES_PLAIN EQU $65A8
SES_SKIP_ACTION EQU $659D
SET_ENEMY_STATE_RUNTIME EQU $6546
SET_REFRESH EQU $F1A2
SFX_ADDR_TABLE EQU $407C
SFX_BANK_TABLE EQU $407B
SFX_CHECKNOISEFREQ EQU $5E5B
SFX_CHECKTONEFREQ EQU $5E41
SFX_CHECKVOLUME EQU $5E6C
SFX_DOFRAME EQU $5E2E
SFX_ENDOFEFFECT EQU $5EA1
SFX_M_NOISE EQU $5E87
SFX_M_NOISEDIS EQU $5E92
SFX_M_TONEDIS EQU $5E85
SFX_M_WRITE EQU $5E94
SFX_NEXTFRAME EQU $5E9C
SFX_UPDATE EQU $5E23
SFX_UPDATEMIXER EQU $5E75
SHOW_LEVEL_RUNTIME EQU $5798
SLR_BG_LAYER EQU $580D
SLR_BOT_NOCLAMP EQU $580A
SLR_BOT_OK EQU $57F7
SLR_DONE EQU $5828
SLR_DRAW_CLIPPED_PATH EQU $5933
SLR_DRAW_OBJECTS EQU $5862
SLR_DRAW_SCREEN_RANGE EQU $5835
SLR_DRAW_VECTOR EQU $58FD
SLR_FOREGROUND EQU $581F
SLR_GAMEPLAY EQU $5816
SLR_OBJ_DONE EQU $5930
SLR_OBJ_LOOP EQU $5864
SLR_OBJ_NEXT EQU $5926
SLR_PATH_DONE EQU $591B
SLR_PATH_LOOP EQU $5903
SLR_ROM_A_ZERO EQU $58D5
SLR_ROM_OFFSETS EQU $586B
SLR_ROM_VISIBLE EQU $58DD
SLR_ROM_Y_VISIBLE EQU $589D
SLR_ROM_Y_ZERO EQU $5896
SLR_SR_DONE EQU $5861
SLR_SR_LOOP EQU $5838
SLR_SR_NEXT EQU $585B
SLR_TOP_OK EQU $57E1
SOUND_BYTE EQU $F256
SOUND_BYTES EQU $F27D
SOUND_BYTES_X EQU $F284
SOUND_BYTE_RAW EQU $F25B
SOUND_BYTE_X EQU $F259
SPAWN_ACT_DONE EQU $6103
SPAWN_CLR_LOOP EQU $600E
SPAWN_ENEMIES_BANKED EQU $434A
SPAWN_ENEMIES_RUNTIME EQU $6000
SPAWN_ENE_DONE EQU $6121
SPAWN_SCAN_LOOP EQU $6058
SPAWN_SKIP EQU $6112
SPAWN_SM_DONE EQU $60E4
SPAWN_SM_NOSM EQU $60E0
STOP_MUSIC_RUNTIME EQU $5D2A
STRIP_ZEROS EQU $F8B7
Select_Game EQU $F7A9
Set_Refresh EQU $F1A2
Sound_Byte EQU $F256
Sound_Byte_raw EQU $F25B
Sound_Byte_x EQU $F259
Sound_Bytes EQU $F27D
Sound_Bytes_x EQU $F284
Strip_Zeros EQU $F8B7
TRAMP_ON_PLAYER_DEATH EQU $6775
TRAMP_TRY_LAUNCH_BALL EQU $6743
TRAMP_TRY_SHOOT EQU $675C
TRAMP_UPDATE_FROG_BULLET EQU $67D9
TRAMP_UPDATE_FROG_FIRE EQU $67C0
TRAMP_UPDATE_PLAYER EQU $678E
TRAMP_UPDATE_SNOWBALLS EQU $67A7
TRAMP_on_player_death EQU $6775
TRAMP_try_launch_ball EQU $6743
TRAMP_try_shoot EQU $675C
TRAMP_update_frog_bullet EQU $67D9
TRAMP_update_frog_fire EQU $67C0
TRAMP_update_player EQU $678E
TRAMP_update_snowballs EQU $67A7
UDC_DONE EQU $65EF
UPDATE_ENEMIES_RUNTIME EQU $6122
UPDATE_MUSIC_PSG EQU $5C74
UPD_DECAY_CHECK EQU $65B1
UPD_ENE_DONE EQU $63F6
UPD_ENE_LOOP EQU $613B
UPD_ENE_NEXT_POP EQU $63E4
UPD_PATROL EQU $615F
UPD_P_CHECK_WP EQU $61BA
UPD_P_INC_X EQU $618F
UPD_P_INC_Y EQU $61B0
UPD_P_MOVE_Y EQU $6199
UPD_WANDER EQU $61D3
UPD_W_AIR EQU $6328
UPD_W_AIR_CHK_DOWN EQU $63A5
UPD_W_AIR_LAND EQU $63C1
UPD_W_AIR_NOLAND EQU $63BC
UPD_W_AIR_VYOK EQU $6378
UPD_W_AIR_X_OKL EQU $634D
UPD_W_AIR_X_OKR EQU $6362
UPD_W_AIR_X_R EQU $6352
UPD_W_AIR_Y EQU $6364
UPD_W_EDGE EQU $624C
UPD_W_EDGE_L EQU $6246
UPD_W_EDGE_R EQU $6226
UPD_W_IDLE EQU $6268
UPD_W_NEXT_TRY EQU $62C5
UPD_W_TO_WALK EQU $62CC
UPD_W_TRY_LOOP EQU $6289
UPD_W_TT EQU $62D6
UPD_W_TT_AIR EQU $6320
UPD_W_TT_FACE_R EQU $631D
UPD_W_TT_REACHED EQU $6300
UPD_W_TT_RIGHT EQU $62F3
UPD_W_WALK EQU $61EF
UPD_W_WALK_L EQU $622F
VECTOR_ADDR_TABLE EQU $4024
VECTOR_BANK_TABLE EQU $4000
VECTREX_PRINT_NUMBER EQU $520E
VECTREX_PRINT_NUMBER.PN_AFTER_CONVERT EQU $52C7
VECTREX_PRINT_NUMBER.PN_D10 EQU $52B6
VECTREX_PRINT_NUMBER.PN_D100 EQU $529C
VECTREX_PRINT_NUMBER.PN_D1000 EQU $5282
VECTREX_PRINT_NUMBER.PN_DIV1000 EQU $526E
VECTREX_PRINT_NUMBER.PN_L10 EQU $52A4
VECTREX_PRINT_NUMBER.PN_L100 EQU $528A
VECTREX_PRINT_NUMBER.PN_L1000 EQU $5270
VECTREX_PRINT_NUMBER.PN_NO_CACHE EQU $5237
VECTREX_PRINT_TEXT EQU $51D4
VEC_0REF_ENABLE EQU $C824
VEC_ADSR_TABLE EQU $C84F
VEC_ADSR_TIMERS EQU $C85E
VEC_ANGLE EQU $C836
VEC_BRIGHTNESS EQU $C827
VEC_BTN_STATE EQU $C80F
VEC_BUTTONS EQU $C811
VEC_BUTTON_1_1 EQU $C812
VEC_BUTTON_1_2 EQU $C813
VEC_BUTTON_1_3 EQU $C814
VEC_BUTTON_1_4 EQU $C815
VEC_BUTTON_2_1 EQU $C816
VEC_BUTTON_2_2 EQU $C817
VEC_BUTTON_2_3 EQU $C818
VEC_BUTTON_2_4 EQU $C819
VEC_COLD_FLAG EQU $CBFE
VEC_COUNTERS EQU $C82E
VEC_COUNTER_1 EQU $C82E
VEC_COUNTER_2 EQU $C82F
VEC_COUNTER_3 EQU $C830
VEC_COUNTER_4 EQU $C831
VEC_COUNTER_5 EQU $C832
VEC_COUNTER_6 EQU $C833
VEC_DEFAULT_STK EQU $CBEA
VEC_DOT_DWELL EQU $C828
VEC_DURATION EQU $C857
VEC_EXPL_1 EQU $C858
VEC_EXPL_2 EQU $C859
VEC_EXPL_3 EQU $C85A
VEC_EXPL_4 EQU $C85B
VEC_EXPL_CHAN EQU $C85C
VEC_EXPL_CHANA EQU $C853
VEC_EXPL_CHANB EQU $C85D
VEC_EXPL_CHANS EQU $C854
VEC_EXPL_FLAG EQU $C867
VEC_EXPL_TIMER EQU $C877
VEC_FIRQ_VECTOR EQU $CBF5
VEC_FREQ_TABLE EQU $C84D
VEC_HIGH_SCORE EQU $CBEB
VEC_IRQ_VECTOR EQU $CBF8
VEC_JOY_1_X EQU $C81B
VEC_JOY_1_Y EQU $C81C
VEC_JOY_2_X EQU $C81D
VEC_JOY_2_Y EQU $C81E
VEC_JOY_MUX EQU $C81F
VEC_JOY_MUX_1_X EQU $C81F
VEC_JOY_MUX_1_Y EQU $C820
VEC_JOY_MUX_2_X EQU $C821
VEC_JOY_MUX_2_Y EQU $C822
VEC_JOY_RESLTN EQU $C81A
VEC_LOOP_COUNT EQU $C825
VEC_MAX_GAMES EQU $C850
VEC_MAX_PLAYERS EQU $C84F
VEC_MISC_COUNT EQU $C823
VEC_MUSIC_CHAN EQU $C855
VEC_MUSIC_FLAG EQU $C856
VEC_MUSIC_FREQ EQU $C861
VEC_MUSIC_PTR EQU $C853
VEC_MUSIC_TWANG EQU $C858
VEC_MUSIC_WK_1 EQU $C84B
VEC_MUSIC_WK_5 EQU $C847
VEC_MUSIC_WK_6 EQU $C846
VEC_MUSIC_WK_7 EQU $C845
VEC_MUSIC_WK_A EQU $C842
VEC_MUSIC_WORK EQU $C83F
VEC_NMI_VECTOR EQU $CBFB
VEC_NUM_GAME EQU $C87A
VEC_NUM_PLAYERS EQU $C879
VEC_PATTERN EQU $C829
VEC_PREV_BTNS EQU $C810
VEC_RANDOM_SEED EQU $C87D
VEC_RFRSH EQU $C83D
VEC_RFRSH_HI EQU $C83E
VEC_RFRSH_LO EQU $C83D
VEC_RISERUN_LEN EQU $C83B
VEC_RISERUN_TMP EQU $C834
VEC_RISE_INDEX EQU $C839
VEC_RUN_INDEX EQU $C837
VEC_SEED_PTR EQU $C87B
VEC_SND_SHADOW EQU $C800
VEC_STR_PTR EQU $C82C
VEC_SWI2_VECTOR EQU $CBF2
VEC_SWI3_VECTOR EQU $CBF2
VEC_SWI_VECTOR EQU $CBFB
VEC_TEXT_HEIGHT EQU $C82A
VEC_TEXT_HW EQU $C82A
VEC_TEXT_WIDTH EQU $C82B
VEC_TWANG_TABLE EQU $C851
Vec_0Ref_Enable EQU $C824
Vec_ADSR_Table EQU $C84F
Vec_ADSR_Timers EQU $C85E
Vec_Angle EQU $C836
Vec_Brightness EQU $C827
Vec_Btn_State EQU $C80F
Vec_Button_1_1 EQU $C812
Vec_Button_1_2 EQU $C813
Vec_Button_1_3 EQU $C814
Vec_Button_1_4 EQU $C815
Vec_Button_2_1 EQU $C816
Vec_Button_2_2 EQU $C817
Vec_Button_2_3 EQU $C818
Vec_Button_2_4 EQU $C819
Vec_Buttons EQU $C811
Vec_Cold_Flag EQU $CBFE
Vec_Counter_1 EQU $C82E
Vec_Counter_2 EQU $C82F
Vec_Counter_3 EQU $C830
Vec_Counter_4 EQU $C831
Vec_Counter_5 EQU $C832
Vec_Counter_6 EQU $C833
Vec_Counters EQU $C82E
Vec_Default_Stk EQU $CBEA
Vec_Dot_Dwell EQU $C828
Vec_Duration EQU $C857
Vec_Expl_1 EQU $C858
Vec_Expl_2 EQU $C859
Vec_Expl_3 EQU $C85A
Vec_Expl_4 EQU $C85B
Vec_Expl_Chan EQU $C85C
Vec_Expl_ChanA EQU $C853
Vec_Expl_ChanB EQU $C85D
Vec_Expl_Chans EQU $C854
Vec_Expl_Flag EQU $C867
Vec_Expl_Timer EQU $C877
Vec_FIRQ_Vector EQU $CBF5
Vec_Freq_Table EQU $C84D
Vec_High_Score EQU $CBEB
Vec_IRQ_Vector EQU $CBF8
Vec_Joy_1_X EQU $C81B
Vec_Joy_1_Y EQU $C81C
Vec_Joy_2_X EQU $C81D
Vec_Joy_2_Y EQU $C81E
Vec_Joy_Mux EQU $C81F
Vec_Joy_Mux_1_X EQU $C81F
Vec_Joy_Mux_1_Y EQU $C820
Vec_Joy_Mux_2_X EQU $C821
Vec_Joy_Mux_2_Y EQU $C822
Vec_Joy_Resltn EQU $C81A
Vec_Loop_Count EQU $C825
Vec_Max_Games EQU $C850
Vec_Max_Players EQU $C84F
Vec_Misc_Count EQU $C823
Vec_Music_Chan EQU $C855
Vec_Music_Flag EQU $C856
Vec_Music_Freq EQU $C861
Vec_Music_Ptr EQU $C853
Vec_Music_Twang EQU $C858
Vec_Music_Wk_1 EQU $C84B
Vec_Music_Wk_5 EQU $C847
Vec_Music_Wk_6 EQU $C846
Vec_Music_Wk_7 EQU $C845
Vec_Music_Wk_A EQU $C842
Vec_Music_Work EQU $C83F
Vec_NMI_Vector EQU $CBFB
Vec_Num_Game EQU $C87A
Vec_Num_Players EQU $C879
Vec_Pattern EQU $C829
Vec_Prev_Btns EQU $C810
Vec_Random_Seed EQU $C87D
Vec_Rfrsh EQU $C83D
Vec_Rfrsh_hi EQU $C83E
Vec_Rfrsh_lo EQU $C83D
Vec_RiseRun_Len EQU $C83B
Vec_RiseRun_Tmp EQU $C834
Vec_Rise_Index EQU $C839
Vec_Run_Index EQU $C837
Vec_SWI2_Vector EQU $CBF2
Vec_SWI3_Vector EQU $CBF2
Vec_SWI_Vector EQU $CBFB
Vec_Seed_Ptr EQU $C87B
Vec_Snd_Shadow EQU $C800
Vec_Str_Ptr EQU $C82C
Vec_Text_HW EQU $C82A
Vec_Text_Height EQU $C82A
Vec_Text_Width EQU $C82B
Vec_Twang_Table EQU $C851
WAIT_RECAL EQU $F192
WARM_START EQU $F06C
Wait_Recal EQU $F192
Warm_Start EQU $F06C
XFORM_RISE EQU $F663
XFORM_RISE_A EQU $F661
XFORM_RUN EQU $F65D
XFORM_RUN_A EQU $F65B
Xform_Rise EQU $F663
Xform_Rise_a EQU $F661
Xform_Run EQU $F65D
Xform_Run_a EQU $F65B
_ANIM_FROG_WALK EQU $439E
_ANIM_FROG_WALK_F0 EQU $43A8
_ANIM_FROG_WALK_F1 EQU $43AD
_ANIM_FROG_WALK_F2 EQU $43B2
_ANIM_PLAYER_WALK EQU $43B7
_ANIM_PLAYER_WALK_F0 EQU $43C3
_ANIM_PLAYER_WALK_F1 EQU $43C8
_ANIM_PLAYER_WALK_F2 EQU $43CD
_ANIM_PLAYER_WALK_F3 EQU $43D2
_ANIM_TITCHI_WALK EQU $43D7
_ANIM_TITCHI_WALK_F0 EQU $43E3
_ANIM_TITCHI_WALK_F1 EQU $43E8
_ANIM_TITCHI_WALK_F2 EQU $43ED
_ANIM_TITCHI_WALK_F3 EQU $43F2
_ANIM_YELLOW_TROLL_WALK EQU $43F7
_ANIM_YELLOW_TROLL_WALK_F0 EQU $4401
_ANIM_YELLOW_TROLL_WALK_F1 EQU $4406
_ANIM_YELLOW_TROLL_WALK_F2 EQU $440B
_BOSS_INTRO_MUSIC EQU $0271
_ENEMY1_ENEMY EQU $4099
_ENEMY1_ENEMY_ACTIONS EQU $40A0
_FONT_G_21 EQU $4D2A
_FONT_G_22 EQU $4D37
_FONT_G_2B EQU $4D44
_FONT_G_2C EQU $4D51
_FONT_G_2D EQU $4D58
_FONT_G_2E EQU $4D5F
_FONT_G_2F EQU $4D66
_FONT_G_30 EQU $4D6D
_FONT_G_31 EQU $4D7D
_FONT_G_32 EQU $4D84
_FONT_G_33 EQU $4D97
_FONT_G_34 EQU $4DAA
_FONT_G_35 EQU $4DBA
_FONT_G_36 EQU $4DCD
_FONT_G_37 EQU $4DE0
_FONT_G_38 EQU $4DEA
_FONT_G_39 EQU $4E00
_FONT_G_3A EQU $4E10
_FONT_G_3B EQU $4E1D
_FONT_G_3C EQU $4E2A
_FONT_G_3D EQU $4E34
_FONT_G_3E EQU $4E41
_FONT_G_3F EQU $4E4B
_FONT_G_41 EQU $4E5E
_FONT_G_42 EQU $4E6E
_FONT_G_43 EQU $4E87
_FONT_G_44 EQU $4E94
_FONT_G_45 EQU $4EAA
_FONT_G_46 EQU $4EBD
_FONT_G_47 EQU $4ECD
_FONT_G_48 EQU $4EE0
_FONT_G_49 EQU $4EF3
_FONT_G_4A EQU $4F06
_FONT_G_4B EQU $4F19
_FONT_G_4C EQU $4F2C
_FONT_G_4D EQU $4F36
_FONT_G_4E EQU $4F46
_FONT_G_4F EQU $4F53
_FONT_G_50 EQU $4F63
_FONT_G_51 EQU $4F79
_FONT_G_52 EQU $4F8F
_FONT_G_53 EQU $4FA8
_FONT_G_54 EQU $4FBB
_FONT_G_55 EQU $4FC8
_FONT_G_56 EQU $4FD5
_FONT_G_57 EQU $4FDF
_FONT_G_58 EQU $4FEF
_FONT_G_59 EQU $4FFC
_FONT_G_5A EQU $500C
_FONT_G_61 EQU $5019
_FONT_G_62 EQU $5029
_FONT_G_63 EQU $5042
_FONT_G_64 EQU $504F
_FONT_G_65 EQU $5065
_FONT_G_66 EQU $5078
_FONT_G_67 EQU $5088
_FONT_G_68 EQU $509B
_FONT_G_69 EQU $50AE
_FONT_G_6A EQU $50C1
_FONT_G_6B EQU $50D4
_FONT_G_6C EQU $50E7
_FONT_G_6D EQU $50F1
_FONT_G_6E EQU $5101
_FONT_G_6F EQU $510E
_FONT_G_70 EQU $511E
_FONT_G_71 EQU $5134
_FONT_G_72 EQU $514A
_FONT_G_73 EQU $5163
_FONT_G_74 EQU $5176
_FONT_G_75 EQU $5183
_FONT_G_76 EQU $5190
_FONT_G_77 EQU $519A
_FONT_G_78 EQU $51AA
_FONT_G_79 EQU $51B7
_FONT_G_7A EQU $51C7
_FONT_PTRS EQU $4C6A
_FROG_ENEMY EQU $40AC
_FROG_ENEMY_ACTIONS EQU $40B3
_FROG_FIREBALL_DOWN_PATH0 EQU $0373
_FROG_FIREBALL_DOWN_PATH1 EQU $037C
_FROG_FIREBALL_DOWN_VECTORS EQU $036D
_FROG_FIREBALL_SIDE_PATH0 EQU $03B2
_FROG_FIREBALL_SIDE_PATH1 EQU $03BB
_FROG_FIREBALL_SIDE_VECTORS EQU $03AC
_FROG_FIRE_DOWN_PATH0 EQU $3864
_FROG_FIRE_DOWN_PATH1 EQU $387C
_FROG_FIRE_DOWN_PATH2 EQU $3888
_FROG_FIRE_DOWN_PATH3 EQU $38A0
_FROG_FIRE_DOWN_PATH4 EQU $38A9
_FROG_FIRE_DOWN_PATH5 EQU $38B2
_FROG_FIRE_DOWN_PATH6 EQU $38CD
_FROG_FIRE_DOWN_PATH7 EQU $38DC
_FROG_FIRE_DOWN_PATH8 EQU $38EE
_FROG_FIRE_DOWN_VECTORS EQU $3850
_FROG_FIRE_SIDE_PATH0 EQU $0134
_FROG_FIRE_SIDE_PATH1 EQU $0146
_FROG_FIRE_SIDE_PATH2 EQU $016A
_FROG_FIRE_SIDE_PATH3 EQU $019A
_FROG_FIRE_SIDE_VECTORS EQU $012A
_FROG_IDLE_PATH0 EQU $3914
_FROG_IDLE_PATH1 EQU $392C
_FROG_IDLE_PATH2 EQU $3938
_FROG_IDLE_PATH3 EQU $3950
_FROG_IDLE_PATH4 EQU $395F
_FROG_IDLE_PATH5 EQU $3971
_FROG_IDLE_PATH6 EQU $3983
_FROG_IDLE_PATH7 EQU $398C
_FROG_IDLE_PATH8 EQU $39A7
_FROG_IDLE_VECTORS EQU $3900
_FROG_SM EQU $40DD
_FROG_SM_STATES EQU $40DF
_FROG_WALK1_PATH0 EQU $4BFB
_FROG_WALK1_PATH1 EQU $4C0D
_FROG_WALK1_PATH2 EQU $4C31
_FROG_WALK1_PATH3 EQU $4C61
_FROG_WALK1_VECTORS EQU $4BF1
_FROG_WALK2_PATH0 EQU $4B85
_FROG_WALK2_PATH1 EQU $4B97
_FROG_WALK2_PATH2 EQU $4BB8
_FROG_WALK2_PATH3 EQU $4BE8
_FROG_WALK2_VECTORS EQU $4B7B
_FROG_WALK3_PATH0 EQU $4721
_FROG_WALK3_PATH1 EQU $4733
_FROG_WALK3_PATH2 EQU $4754
_FROG_WALK3_PATH3 EQU $4784
_FROG_WALK3_VECTORS EQU $4717
_GAME_OVER_MUSIC EQU $33E8
_HENSHOKU_MUSIC EQU $0000
_INIT_SCREEN_PATH0 EQU $357D
_INIT_SCREEN_PATH1 EQU $358F
_INIT_SCREEN_PATH10 EQU $3640
_INIT_SCREEN_PATH11 EQU $364C
_INIT_SCREEN_PATH12 EQU $365B
_INIT_SCREEN_PATH13 EQU $3664
_INIT_SCREEN_PATH14 EQU $366D
_INIT_SCREEN_PATH15 EQU $3676
_INIT_SCREEN_PATH16 EQU $367F
_INIT_SCREEN_PATH17 EQU $368B
_INIT_SCREEN_PATH18 EQU $369D
_INIT_SCREEN_PATH19 EQU $36A6
_INIT_SCREEN_PATH2 EQU $359B
_INIT_SCREEN_PATH20 EQU $36BB
_INIT_SCREEN_PATH21 EQU $36C4
_INIT_SCREEN_PATH22 EQU $36D0
_INIT_SCREEN_PATH23 EQU $36DC
_INIT_SCREEN_PATH24 EQU $36E5
_INIT_SCREEN_PATH25 EQU $36EE
_INIT_SCREEN_PATH26 EQU $36F7
_INIT_SCREEN_PATH27 EQU $3700
_INIT_SCREEN_PATH28 EQU $3709
_INIT_SCREEN_PATH29 EQU $3715
_INIT_SCREEN_PATH3 EQU $35AD
_INIT_SCREEN_PATH30 EQU $371E
_INIT_SCREEN_PATH31 EQU $3727
_INIT_SCREEN_PATH32 EQU $3730
_INIT_SCREEN_PATH33 EQU $375D
_INIT_SCREEN_PATH34 EQU $376F
_INIT_SCREEN_PATH35 EQU $378D
_INIT_SCREEN_PATH36 EQU $379F
_INIT_SCREEN_PATH37 EQU $37C0
_INIT_SCREEN_PATH38 EQU $37D2
_INIT_SCREEN_PATH39 EQU $37ED
_INIT_SCREEN_PATH4 EQU $35BF
_INIT_SCREEN_PATH40 EQU $37F6
_INIT_SCREEN_PATH41 EQU $37FF
_INIT_SCREEN_PATH42 EQU $3808
_INIT_SCREEN_PATH43 EQU $3814
_INIT_SCREEN_PATH44 EQU $381D
_INIT_SCREEN_PATH45 EQU $3826
_INIT_SCREEN_PATH46 EQU $382F
_INIT_SCREEN_PATH47 EQU $383B
_INIT_SCREEN_PATH48 EQU $3847
_INIT_SCREEN_PATH49 EQU $3850
_INIT_SCREEN_PATH5 EQU $35D7
_INIT_SCREEN_PATH50 EQU $3859
_INIT_SCREEN_PATH51 EQU $3862
_INIT_SCREEN_PATH52 EQU $3874
_INIT_SCREEN_PATH53 EQU $38AA
_INIT_SCREEN_PATH54 EQU $38CE
_INIT_SCREEN_PATH55 EQU $38EC
_INIT_SCREEN_PATH56 EQU $3901
_INIT_SCREEN_PATH6 EQU $35E9
_INIT_SCREEN_PATH7 EQU $35FE
_INIT_SCREEN_PATH8 EQU $3628
_INIT_SCREEN_PATH9 EQU $3634
_INIT_SCREEN_VECTORS EQU $3509
_INTRO_MUSIC EQU $02FF
_PLATFORM10_PATH0 EQU $0558
_PLATFORM10_VECTORS EQU $0554
_PLATFORM11_PATH0 EQU $056E
_PLATFORM11_VECTORS EQU $056A
_PLATFORM12_PATH0 EQU $0584
_PLATFORM12_VECTORS EQU $0580
_PLATFORM13_PATH0 EQU $059A
_PLATFORM13_VECTORS EQU $0596
_PLATFORM14_PATH0 EQU $05B0
_PLATFORM14_VECTORS EQU $05AC
_PLATFORM15_PATH0 EQU $353C
_PLATFORM15_PATH1 EQU $354E
_PLATFORM15_PATH2 EQU $356F
_PLATFORM15_PATH3 EQU $357B
_PLATFORM15_PATH4 EQU $3587
_PLATFORM15_PATH5 EQU $3590
_PLATFORM15_PATH6 EQU $35A2
_PLATFORM15_PATH7 EQU $35BA
_PLATFORM15_PATH8 EQU $35D2
_PLATFORM15_PATH9 EQU $35DB
_PLATFORM15_VECTORS EQU $3526
_PLATFORM16_PATH0 EQU $3230
_PLATFORM16_PATH1 EQU $3242
_PLATFORM16_PATH2 EQU $3275
_PLATFORM16_PATH3 EQU $3287
_PLATFORM16_PATH4 EQU $3299
_PLATFORM16_PATH5 EQU $32A2
_PLATFORM16_PATH6 EQU $32B4
_PLATFORM16_PATH7 EQU $32D2
_PLATFORM16_PATH8 EQU $32EA
_PLATFORM16_VECTORS EQU $321C
_PLATFORM17_PATH0 EQU $3316
_PLATFORM17_PATH1 EQU $3328
_PLATFORM17_PATH2 EQU $335B
_PLATFORM17_PATH3 EQU $336D
_PLATFORM17_PATH4 EQU $337F
_PLATFORM17_PATH5 EQU $3388
_PLATFORM17_PATH6 EQU $339A
_PLATFORM17_PATH7 EQU $33B8
_PLATFORM17_PATH8 EQU $33D0
_PLATFORM17_VECTORS EQU $3302
_PLATFORM18_PATH0 EQU $0436
_PLATFORM18_PATH1 EQU $043F
_PLATFORM18_PATH2 EQU $0451
_PLATFORM18_VECTORS EQU $042E
_PLATFORM19_PATH0 EQU $3DC5
_PLATFORM19_PATH1 EQU $3DEC
_PLATFORM19_PATH2 EQU $3DF5
_PLATFORM19_VECTORS EQU $3DBD
_PLATFORM1_PATH0 EQU $04AC
_PLATFORM1_PATH1 EQU $04B5
_PLATFORM1_PATH2 EQU $04C7
_PLATFORM1_VECTORS EQU $04A4
_PLATFORM20_PATH0 EQU $01AD
_PLATFORM20_PATH1 EQU $01CB
_PLATFORM20_PATH2 EQU $01D4
_PLATFORM20_PATH3 EQU $01EC
_PLATFORM20_VECTORS EQU $01A3
_PLATFORM20__PATH0 EQU $0214
_PLATFORM20__PATH1 EQU $0232
_PLATFORM20__PATH2 EQU $023B
_PLATFORM20__PATH3 EQU $0253
_PLATFORM20__VECTORS EQU $020A
_PLATFORM2_PATH0 EQU $0471
_PLATFORM2_PATH1 EQU $047A
_PLATFORM2_PATH2 EQU $0492
_PLATFORM2_VECTORS EQU $0469
_PLATFORM3_PATH0 EQU $04E1
_PLATFORM3_PATH1 EQU $04EA
_PLATFORM3_PATH2 EQU $04FC
_PLATFORM3_VECTORS EQU $04D9
_PLATFORM4_PATH0 EQU $3129
_PLATFORM4_PATH1 EQU $3135
_PLATFORM4_PATH10 EQU $31CE
_PLATFORM4_PATH11 EQU $31F8
_PLATFORM4_PATH12 EQU $3204
_PLATFORM4_PATH13 EQU $3210
_PLATFORM4_PATH2 EQU $3141
_PLATFORM4_PATH3 EQU $314D
_PLATFORM4_PATH4 EQU $316E
_PLATFORM4_PATH5 EQU $317A
_PLATFORM4_PATH6 EQU $3192
_PLATFORM4_PATH7 EQU $31A4
_PLATFORM4_PATH8 EQU $31B6
_PLATFORM4_PATH9 EQU $31C2
_PLATFORM4_VECTORS EQU $310B
_PLATFORM7_PATH0 EQU $3609
_PLATFORM7_PATH1 EQU $361B
_PLATFORM7_PATH2 EQU $363C
_PLATFORM7_PATH3 EQU $3648
_PLATFORM7_PATH4 EQU $3654
_PLATFORM7_PATH5 EQU $365D
_PLATFORM7_PATH6 EQU $366F
_PLATFORM7_PATH7 EQU $3687
_PLATFORM7_PATH8 EQU $369F
_PLATFORM7_PATH9 EQU $36A8
_PLATFORM7_VECTORS EQU $35F3
_PLATFORM8_PATH0 EQU $03F5
_PLATFORM8_PATH1 EQU $03FE
_PLATFORM8_PATH2 EQU $040A
_PLATFORM8_PATH3 EQU $041C
_PLATFORM8_VECTORS EQU $03EB
_PLATFORM9_PATH0 EQU $0516
_PLATFORM9_PATH1 EQU $051F
_PLATFORM9_PATH2 EQU $0531
_PLATFORM9_VECTORS EQU $050E
_PLAYER_DIE1_PATH0 EQU $39CC
_PLAYER_DIE1_PATH1 EQU $39D8
_PLAYER_DIE1_PATH10 EQU $3A3E
_PLAYER_DIE1_PATH11 EQU $3A47
_PLAYER_DIE1_PATH12 EQU $3A53
_PLAYER_DIE1_PATH2 EQU $39E4
_PLAYER_DIE1_PATH3 EQU $39ED
_PLAYER_DIE1_PATH4 EQU $39F9
_PLAYER_DIE1_PATH5 EQU $3A05
_PLAYER_DIE1_PATH6 EQU $3A11
_PLAYER_DIE1_PATH7 EQU $3A1A
_PLAYER_DIE1_PATH8 EQU $3A26
_PLAYER_DIE1_PATH9 EQU $3A32
_PLAYER_DIE1_VECTORS EQU $39B0
_PLAYER_DIE2_PATH0 EQU $3B27
_PLAYER_DIE2_PATH1 EQU $3B33
_PLAYER_DIE2_PATH10 EQU $3BA2
_PLAYER_DIE2_PATH11 EQU $3BAE
_PLAYER_DIE2_PATH2 EQU $3B3F
_PLAYER_DIE2_PATH3 EQU $3B4E
_PLAYER_DIE2_PATH4 EQU $3B5A
_PLAYER_DIE2_PATH5 EQU $3B66
_PLAYER_DIE2_PATH6 EQU $3B72
_PLAYER_DIE2_PATH7 EQU $3B7E
_PLAYER_DIE2_PATH8 EQU $3B87
_PLAYER_DIE2_PATH9 EQU $3B96
_PLAYER_DIE2_VECTORS EQU $3B0D
_PLAYER_DIE3_PATH0 EQU $3BD4
_PLAYER_DIE3_PATH1 EQU $3BE0
_PLAYER_DIE3_PATH10 EQU $3C4F
_PLAYER_DIE3_PATH11 EQU $3C58
_PLAYER_DIE3_PATH2 EQU $3BEC
_PLAYER_DIE3_PATH3 EQU $3BF8
_PLAYER_DIE3_PATH4 EQU $3C04
_PLAYER_DIE3_PATH5 EQU $3C10
_PLAYER_DIE3_PATH6 EQU $3C1C
_PLAYER_DIE3_PATH7 EQU $3C25
_PLAYER_DIE3_PATH8 EQU $3C31
_PLAYER_DIE3_PATH9 EQU $3C43
_PLAYER_DIE3_VECTORS EQU $3BBA
_PLAYER_DIE4_PATH0 EQU $3C86
_PLAYER_DIE4_PATH1 EQU $3C8F
_PLAYER_DIE4_PATH10 EQU $3CE0
_PLAYER_DIE4_PATH11 EQU $3CE9
_PLAYER_DIE4_PATH12 EQU $3CF2
_PLAYER_DIE4_PATH13 EQU $3CFB
_PLAYER_DIE4_PATH14 EQU $3D04
_PLAYER_DIE4_PATH15 EQU $3D0D
_PLAYER_DIE4_PATH2 EQU $3C98
_PLAYER_DIE4_PATH3 EQU $3CA1
_PLAYER_DIE4_PATH4 EQU $3CAA
_PLAYER_DIE4_PATH5 EQU $3CB3
_PLAYER_DIE4_PATH6 EQU $3CBC
_PLAYER_DIE4_PATH7 EQU $3CC5
_PLAYER_DIE4_PATH8 EQU $3CCE
_PLAYER_DIE4_PATH9 EQU $3CD7
_PLAYER_DIE4_VECTORS EQU $3C64
_PLAYER_IDLE_PATH0 EQU $00B2
_PLAYER_IDLE_PATH1 EQU $00C1
_PLAYER_IDLE_PATH2 EQU $00CD
_PLAYER_IDLE_PATH3 EQU $00E2
_PLAYER_IDLE_PATH4 EQU $00EE
_PLAYER_IDLE_PATH5 EQU $00FD
_PLAYER_IDLE_PATH6 EQU $0109
_PLAYER_IDLE_PATH7 EQU $0118
_PLAYER_IDLE_VECTORS EQU $00A0
_PLAYER_JUMP_PATH0 EQU $3D30
_PLAYER_JUMP_PATH1 EQU $3D39
_PLAYER_JUMP_PATH10 EQU $3D9C
_PLAYER_JUMP_PATH11 EQU $3DAE
_PLAYER_JUMP_PATH2 EQU $3D42
_PLAYER_JUMP_PATH3 EQU $3D51
_PLAYER_JUMP_PATH4 EQU $3D5A
_PLAYER_JUMP_PATH5 EQU $3D66
_PLAYER_JUMP_PATH6 EQU $3D6F
_PLAYER_JUMP_PATH7 EQU $3D7B
_PLAYER_JUMP_PATH8 EQU $3D87
_PLAYER_JUMP_PATH9 EQU $3D93
_PLAYER_JUMP_VECTORS EQU $3D16
_PLAYER_WALK1_PATH0 EQU $4426
_PLAYER_WALK1_PATH1 EQU $4432
_PLAYER_WALK1_PATH2 EQU $443B
_PLAYER_WALK1_PATH3 EQU $4447
_PLAYER_WALK1_PATH4 EQU $4453
_PLAYER_WALK1_PATH5 EQU $445F
_PLAYER_WALK1_PATH6 EQU $446B
_PLAYER_WALK1_PATH7 EQU $447D
_PLAYER_WALK1_PATH8 EQU $4486
_PLAYER_WALK1_PATH9 EQU $4492
_PLAYER_WALK1_VECTORS EQU $4410
_PLAYER_WALK2_PATH0 EQU $48FB
_PLAYER_WALK2_PATH1 EQU $4907
_PLAYER_WALK2_PATH10 EQU $4970
_PLAYER_WALK2_PATH2 EQU $4910
_PLAYER_WALK2_PATH3 EQU $491C
_PLAYER_WALK2_PATH4 EQU $4928
_PLAYER_WALK2_PATH5 EQU $4934
_PLAYER_WALK2_PATH6 EQU $4940
_PLAYER_WALK2_PATH7 EQU $4952
_PLAYER_WALK2_PATH8 EQU $495B
_PLAYER_WALK2_PATH9 EQU $4967
_PLAYER_WALK2_VECTORS EQU $48E3
_PLAYER_WALK3_PATH0 EQU $44A9
_PLAYER_WALK3_PATH1 EQU $44B5
_PLAYER_WALK3_PATH2 EQU $44BE
_PLAYER_WALK3_PATH3 EQU $44E5
_PLAYER_WALK3_PATH4 EQU $44F1
_PLAYER_WALK3_PATH5 EQU $44FA
_PLAYER_WALK3_VECTORS EQU $449B
_PLAYER_WALK4_PATH0 EQU $4862
_PLAYER_WALK4_PATH1 EQU $486E
_PLAYER_WALK4_PATH2 EQU $488C
_PLAYER_WALK4_PATH3 EQU $4898
_PLAYER_WALK4_PATH4 EQU $48A1
_PLAYER_WALK4_PATH5 EQU $48B3
_PLAYER_WALK4_PATH6 EQU $48BC
_PLAYER_WALK4_PATH7 EQU $48C8
_PLAYER_WALK4_PATH8 EQU $48D1
_PLAYER_WALK4_PATH9 EQU $48DA
_PLAYER_WALK4_VECTORS EQU $484C
_TITCHI_BALL_PATH0 EQU $393E
_TITCHI_BALL_PATH1 EQU $3947
_TITCHI_BALL_PATH2 EQU $3953
_TITCHI_BALL_PATH3 EQU $3977
_TITCHI_BALL_PATH4 EQU $3980
_TITCHI_BALL_PATH5 EQU $3989
_TITCHI_BALL_PATH6 EQU $3992
_TITCHI_BALL_VECTORS EQU $392E
_TITCHI_ENEMY EQU $412D
_TITCHI_ENEMY_ACTIONS EQU $4134
_TITCHI_IDLE_PATH0 EQU $0016
_TITCHI_IDLE_PATH1 EQU $0025
_TITCHI_IDLE_PATH2 EQU $002E
_TITCHI_IDLE_PATH3 EQU $003D
_TITCHI_IDLE_PATH4 EQU $0058
_TITCHI_IDLE_PATH5 EQU $0064
_TITCHI_IDLE_PATH6 EQU $006D
_TITCHI_IDLE_PATH7 EQU $007C
_TITCHI_IDLE_PATH8 EQU $0088
_TITCHI_IDLE_PATH9 EQU $0094
_TITCHI_IDLE_VECTORS EQU $0000
_TITCHI_SM EQU $4152
_TITCHI_SM_STATES EQU $4154
_TITCHI_SNOW1_PATH0 EQU $379F
_TITCHI_SNOW1_PATH1 EQU $37AE
_TITCHI_SNOW1_PATH10 EQU $3835
_TITCHI_SNOW1_PATH11 EQU $3844
_TITCHI_SNOW1_PATH2 EQU $37B7
_TITCHI_SNOW1_PATH3 EQU $37C6
_TITCHI_SNOW1_PATH4 EQU $37E1
_TITCHI_SNOW1_PATH5 EQU $37ED
_TITCHI_SNOW1_PATH6 EQU $37F6
_TITCHI_SNOW1_PATH7 EQU $3805
_TITCHI_SNOW1_PATH8 EQU $381D
_TITCHI_SNOW1_PATH9 EQU $3829
_TITCHI_SNOW1_VECTORS EQU $3785
_TITCHI_SNOW2_PATH0 EQU $3A77
_TITCHI_SNOW2_PATH1 EQU $3A86
_TITCHI_SNOW2_PATH2 EQU $3AAA
_TITCHI_SNOW2_PATH3 EQU $3AB9
_TITCHI_SNOW2_PATH4 EQU $3AD4
_TITCHI_SNOW2_PATH5 EQU $3AE0
_TITCHI_SNOW2_PATH6 EQU $3AEF
_TITCHI_SNOW2_PATH7 EQU $3B01
_TITCHI_SNOW2_VECTORS EQU $3A65
_TITCHI_WALK1_PATH0 EQU $4A4E
_TITCHI_WALK1_PATH1 EQU $4A5D
_TITCHI_WALK1_PATH2 EQU $4A66
_TITCHI_WALK1_PATH3 EQU $4A75
_TITCHI_WALK1_PATH4 EQU $4A90
_TITCHI_WALK1_PATH5 EQU $4A9F
_TITCHI_WALK1_PATH6 EQU $4AA8
_TITCHI_WALK1_PATH7 EQU $4AB4
_TITCHI_WALK1_PATH8 EQU $4AC3
_TITCHI_WALK1_PATH9 EQU $4ACF
_TITCHI_WALK1_VECTORS EQU $4A38
_TITCHI_WALK2_PATH0 EQU $468D
_TITCHI_WALK2_PATH1 EQU $469C
_TITCHI_WALK2_PATH2 EQU $46A5
_TITCHI_WALK2_PATH3 EQU $46B1
_TITCHI_WALK2_PATH4 EQU $46CC
_TITCHI_WALK2_PATH5 EQU $46DB
_TITCHI_WALK2_PATH6 EQU $46E4
_TITCHI_WALK2_PATH7 EQU $46F0
_TITCHI_WALK2_PATH8 EQU $46FF
_TITCHI_WALK2_PATH9 EQU $470B
_TITCHI_WALK2_VECTORS EQU $4677
_TITCHI_WALK3_PATH0 EQU $4525
_TITCHI_WALK3_PATH1 EQU $4534
_TITCHI_WALK3_PATH2 EQU $453D
_TITCHI_WALK3_PATH3 EQU $4549
_TITCHI_WALK3_PATH4 EQU $4564
_TITCHI_WALK3_PATH5 EQU $4573
_TITCHI_WALK3_PATH6 EQU $457C
_TITCHI_WALK3_PATH7 EQU $4588
_TITCHI_WALK3_PATH8 EQU $4597
_TITCHI_WALK3_PATH9 EQU $45A3
_TITCHI_WALK3_VECTORS EQU $450F
_TITCHI_WALK4_PATH0 EQU $4AF1
_TITCHI_WALK4_PATH1 EQU $4B00
_TITCHI_WALK4_PATH2 EQU $4B09
_TITCHI_WALK4_PATH3 EQU $4B15
_TITCHI_WALK4_PATH4 EQU $4B30
_TITCHI_WALK4_PATH5 EQU $4B3F
_TITCHI_WALK4_PATH6 EQU $4B48
_TITCHI_WALK4_PATH7 EQU $4B54
_TITCHI_WALK4_PATH8 EQU $4B63
_TITCHI_WALK4_PATH9 EQU $4B6F
_TITCHI_WALK4_VECTORS EQU $4ADB
_YELLOW_TROLL_ENEMY EQU $4188
_YELLOW_TROLL_ENEMY_ACTIONS EQU $418F
_YELLOW_TROLL_IDLE_PATH0 EQU $36D4
_YELLOW_TROLL_IDLE_PATH1 EQU $36EF
_YELLOW_TROLL_IDLE_PATH2 EQU $36FB
_YELLOW_TROLL_IDLE_PATH3 EQU $370A
_YELLOW_TROLL_IDLE_PATH4 EQU $3719
_YELLOW_TROLL_IDLE_PATH5 EQU $374C
_YELLOW_TROLL_IDLE_PATH6 EQU $375E
_YELLOW_TROLL_IDLE_PATH7 EQU $376D
_YELLOW_TROLL_IDLE_PATH8 EQU $3779
_YELLOW_TROLL_IDLE_VECTORS EQU $36C0
_YELLOW_TROLL_SM EQU $41AD
_YELLOW_TROLL_SM_STATES EQU $41AF
_YELLOW_TROLL_WALK1_PATH0 EQU $45C3
_YELLOW_TROLL_WALK1_PATH1 EQU $45DE
_YELLOW_TROLL_WALK1_PATH2 EQU $45EA
_YELLOW_TROLL_WALK1_PATH3 EQU $45FC
_YELLOW_TROLL_WALK1_PATH4 EQU $460B
_YELLOW_TROLL_WALK1_PATH5 EQU $463E
_YELLOW_TROLL_WALK1_PATH6 EQU $4650
_YELLOW_TROLL_WALK1_PATH7 EQU $465F
_YELLOW_TROLL_WALK1_PATH8 EQU $466B
_YELLOW_TROLL_WALK1_VECTORS EQU $45AF
_YELLOW_TROLL_WALK2_PATH0 EQU $498D
_YELLOW_TROLL_WALK2_PATH1 EQU $49C0
_YELLOW_TROLL_WALK2_PATH2 EQU $49D5
_YELLOW_TROLL_WALK2_PATH3 EQU $49E1
_YELLOW_TROLL_WALK2_PATH4 EQU $49F0
_YELLOW_TROLL_WALK2_PATH5 EQU $49FC
_YELLOW_TROLL_WALK2_PATH6 EQU $4A0E
_YELLOW_TROLL_WALK2_PATH7 EQU $4A1D
_YELLOW_TROLL_WALK2_PATH8 EQU $4A29
_YELLOW_TROLL_WALK2_VECTORS EQU $4979
_YELLOW_TROLL_WALK3_PATH0 EQU $47A1
_YELLOW_TROLL_WALK3_PATH1 EQU $47D4
_YELLOW_TROLL_WALK3_PATH2 EQU $47E9
_YELLOW_TROLL_WALK3_PATH3 EQU $47F8
_YELLOW_TROLL_WALK3_PATH4 EQU $4804
_YELLOW_TROLL_WALK3_PATH5 EQU $4810
_YELLOW_TROLL_WALK3_PATH6 EQU $4822
_YELLOW_TROLL_WALK3_PATH7 EQU $4831
_YELLOW_TROLL_WALK3_PATH8 EQU $483D
_YELLOW_TROLL_WALK3_VECTORS EQU $478D
_YUKIDAMA_ONDO_MUSIC EQU $0E3B
music1 EQU $FD0D
music2 EQU $FD1D
music3 EQU $FD81
music4 EQU $FDD3
music5 EQU $FE38
music6 EQU $FE76
music7 EQU $FEC6
music8 EQU $FEF8
music9 EQU $FF26
musica EQU $FF44
musicb EQU $FF62
musicc EQU $FF7A
musicd EQU $FF8F
noay EQU $5E2D
sfx_checknoisefreq EQU $5E5B
sfx_checktonefreq EQU $5E41
sfx_checkvolume EQU $5E6C
sfx_doframe EQU $5E2E
sfx_endofeffect EQU $5EA1
sfx_m_noise EQU $5E87
sfx_m_noisedis EQU $5E92
sfx_m_tonedis EQU $5E85
sfx_m_write EQU $5E94
sfx_nextframe EQU $5E9C
sfx_updatemixer EQU $5E75


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "SNOW BROS"
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
    CLR >ENEMY_COUNT        ; No enemies until SPAWN_ENEMIES runs
    CLR >ANIM_ENEMY_ENEMY1_WALK_STATE
    CLR >ANIM_ENEMY_ENEMY1_WALK_STATE+1
    CLR >ANIM_ENEMY_FROG_WALK_STATE
    CLR >ANIM_ENEMY_FROG_WALK_STATE+1
    CLR >ANIM_ENEMY_TITCHI_WALK_STATE
    CLR >ANIM_ENEMY_TITCHI_WALK_STATE+1
    CLR >ANIM_ENEMY_YELLOW_TROLL_WALK_STATE
    CLR >ANIM_ENEMY_YELLOW_TROLL_WALK_STATE+1
; Bank 0 ($0000) is active; fixed bank 7 ($4000-$7FFF) always visible
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

;***************************************************************************
; ARRAY DATA (ROM literals)
;***************************************************************************
; Arrays are stored in ROM and accessed via pointers
; At startup, main() initializes VAR_{name} to point to ARRAY_{name}_DATA

; Array literal for variable 'thaw_timers' (8 elements, 2 bytes each)
MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    ; Init camera ONCE at boot (RAM not zero-init). LOAD_LEVEL must NOT
    ; reset it (matches pitrex): the game sets it via SET_CAMERA_Y before
    ; LOAD_LEVEL/SPAWN, and GET_LEVEL_FLOOR_Y / the spawn Y-filter read it.
    LDD #0
    STD >CAMERA_X
    STD >CAMERA_Y
    LDA #$F8
    STA TEXT_SCALE_H      ; Default height = -8 (normal size)
    LDA #$48
    STA TEXT_SCALE_W      ; Default width = 72 (normal size)
    LDA #$7F
    STA DRAW_SCALE        ; Default T1 scale = $7F (127 = full BIOS scale)
    LDA #$7F
    STA DRAW_ANIM_SCALE   ; Default anim scale = $7F (127 = full BIOS scale)
    CLR DRAW_ANIM_SPEED_MUL ; Default speed=0 (use vanim timing)
    CLR ANIM_PLAYER_WALK_STATE     ; frame_idx = 0
    CLR ANIM_PLAYER_WALK_STATE+1   ; ticks_left = 0 (forces DAR_INIT)
    ; Copy array 'thaw_timers' from ROM to RAM (8 elements)
    LDX #ARRAY_THAW_TIMERS_DATA       ; Source: ROM array data
    LDU #VAR_THAW_TIMERS_DATA       ; Dest: RAM array space
    LDD #8        ; Number of elements
.COPY_LOOP_0:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_0 ; Loop until done (LBNE for long branch)
    LDX #VAR_THAW_TIMERS_DATA    ; Array now in RAM
    STX VAR_THAW_TIMERS
    ; Copy array 'frog_fire_timer' from ROM to RAM (8 elements)
    LDX #ARRAY_FROG_FIRE_TIMER_DATA       ; Source: ROM array data
    LDU #VAR_FROG_FIRE_TIMER_DATA       ; Dest: RAM array space
    LDD #8        ; Number of elements
.COPY_LOOP_1:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_1 ; Loop until done (LBNE for long branch)
    LDX #VAR_FROG_FIRE_TIMER_DATA    ; Array now in RAM
    STX VAR_FROG_FIRE_TIMER
    ; Copy array 'frog_fire_decay' from ROM to RAM (8 elements)
    LDX #ARRAY_FROG_FIRE_DECAY_DATA       ; Source: ROM array data
    LDU #VAR_FROG_FIRE_DECAY_DATA       ; Dest: RAM array space
    LDD #8        ; Number of elements
.COPY_LOOP_2:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_2 ; Loop until done (LBNE for long branch)
    LDX #VAR_FROG_FIRE_DECAY_DATA    ; Array now in RAM
    STX VAR_FROG_FIRE_DECAY
    LDD #0
    STD VAR_FROG_BULLET_ACTIVE
    LDD #0
    STD VAR_FROG_BULLET_X
    LDD #0
    STD VAR_FROG_BULLET_Y
    LDD #0
    STD VAR_FROG_BULLET_VX
    LDD #0
    STD VAR_FROG_BULLET_VY
    LDD #0
    STD VAR_FROG_BULLET_DIR
    LDD #0
    STD VAR_FROG_BULLET_MIRROR
    ; Copy array 'ball_rolling' from ROM to RAM (8 elements)
    LDX #ARRAY_BALL_ROLLING_DATA       ; Source: ROM array data
    LDU #VAR_BALL_ROLLING_DATA       ; Dest: RAM array space
    LDD #8        ; Number of elements
.COPY_LOOP_3:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_3 ; Loop until done (LBNE for long branch)
    LDX #VAR_BALL_ROLLING_DATA    ; Array now in RAM
    STX VAR_BALL_ROLLING
    ; Copy array 'ball_vx_arr' from ROM to RAM (8 elements)
    LDX #ARRAY_BALL_VX_ARR_DATA       ; Source: ROM array data
    LDU #VAR_BALL_VX_ARR_DATA       ; Dest: RAM array space
    LDD #8        ; Number of elements
.COPY_LOOP_4:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_4 ; Loop until done (LBNE for long branch)
    LDX #VAR_BALL_VX_ARR_DATA    ; Array now in RAM
    STX VAR_BALL_VX_ARR
    ; Copy array 'ball_vy_arr' from ROM to RAM (8 elements)
    LDX #ARRAY_BALL_VY_ARR_DATA       ; Source: ROM array data
    LDU #VAR_BALL_VY_ARR_DATA       ; Dest: RAM array space
    LDD #8        ; Number of elements
.COPY_LOOP_5:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_5 ; Loop until done (LBNE for long branch)
    LDX #VAR_BALL_VY_ARR_DATA    ; Array now in RAM
    STX VAR_BALL_VY_ARR
    ; Copy array 'ball_bounces' from ROM to RAM (8 elements)
    LDX #ARRAY_BALL_BOUNCES_DATA       ; Source: ROM array data
    LDU #VAR_BALL_BOUNCES_DATA       ; Dest: RAM array space
    LDD #8        ; Number of elements
.COPY_LOOP_6:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_6 ; Loop until done (LBNE for long branch)
    LDX #VAR_BALL_BOUNCES_DATA    ; Array now in RAM
    STX VAR_BALL_BOUNCES
    ; Copy array 'ball_collided' from ROM to RAM (8 elements)
    LDX #ARRAY_BALL_COLLIDED_DATA       ; Source: ROM array data
    LDU #VAR_BALL_COLLIDED_DATA       ; Dest: RAM array space
    LDD #8        ; Number of elements
.COPY_LOOP_7:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_7 ; Loop until done (LBNE for long branch)
    LDX #VAR_BALL_COLLIDED_DATA    ; Array now in RAM
    STX VAR_BALL_COLLIDED
    LDD #0
    STD VAR_BALL_LAUNCHED
    LDD #0
    STD VAR_GAME_STATE
    LDD #0
    STD VAR_SCORE
    LDD #3
    STD VAR_LIVES
    LDD #1
    STD VAR_CURRENT_LEVEL
    LDD #0
    STD VAR_TIME_LEFT
    LDD #0
    STD VAR_ENEMY_COUNT
    LDD #0
    STD VAR_FRAME_TIMER
    LDD #0
    STD VAR__T0
    LDD #0
    STD VAR__T1
    LDD #0
    STD VAR__T2
    LDD #0
    STD VAR__T3
    LDD #0
    STD VAR__T4
    LDD #0
    STD VAR__DBG_CTR
    LDD #0
    STD VAR_NEXT_IS_BOSS
    LDD #0
    STD VAR_SPAWN_FLOOR_Y
    LDD #0
    STD VAR_PLAYER_X
    LDD #-2424
    STD VAR_PLAYER_Y
    LDD #0
    STD VAR_PLAYER_VX
    LDD #0
    STD VAR_PLAYER_VY
    LDD #0
    STD VAR_PLAYER_FACING
    LDD #0
    STD VAR_PLAYER_ON_GROUND
    LDD #0
    STD VAR_FLOOR_Y
    LDD #0
    STD VAR_PREV_Y
    LDD #0
    STD VAR_PUSH_DX
    LDD #-2304
    STD VAR_CAMERA_Y
    LDD #-2304
    STD VAR_SCROLL_TARGET
    LDD #0
    STD VAR_SHOOT_COOLDOWN
    LDD #0
    STD VAR_PLAYER_HAS_POWER
    LDD #14
    STD VAR_SNOW_LIFE_MAX
    LDD #0
    STD VAR_SNOW_SPAWN_VX
    LDD #0
    STD VAR_SNOW0_ACTIVE
    LDD #0
    STD VAR_SNOW0_X
    LDD #0
    STD VAR_SNOW0_Y
    LDD #0
    STD VAR_SNOW0_VX
    LDD #0
    STD VAR_SNOW0_VY
    LDD #0
    STD VAR_SNOW0_LIFE
    LDD #0
    STD VAR_SNOW1_ACTIVE
    LDD #0
    STD VAR_SNOW1_X
    LDD #0
    STD VAR_SNOW1_Y
    LDD #0
    STD VAR_SNOW1_VX
    LDD #0
    STD VAR_SNOW1_VY
    LDD #0
    STD VAR_SNOW1_LIFE
    LDD #0
    STD VAR_SNOW2_ACTIVE
    LDD #0
    STD VAR_SNOW2_X
    LDD #0
    STD VAR_SNOW2_Y
    LDD #0
    STD VAR_SNOW2_VX
    LDD #0
    STD VAR_SNOW2_VY
    LDD #0
    STD VAR_SNOW2_LIFE
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

    ; Call main() for initialization
; VPy_LINE:170
; NATIVE_CALL: SET_INTENSITY at line 170
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:171
    LDD #0  ; const STATE_TITLE
    STD VAR_GAME_STATE

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
; VPy_LINE:174
    LDD >VAR_GAME_STATE
    CMPD #0
    LBNE IF_NEXT_1
; VPy_LINE:175
    JSR state_title
    LBRA IF_END_0
IF_NEXT_1:
    LDD >VAR_GAME_STATE
    CMPD #1
    LBNE IF_NEXT_2
; VPy_LINE:177
    JSR state_game_start
    LBRA IF_END_0
IF_NEXT_2:
    LDD >VAR_GAME_STATE
    CMPD #2
    LBNE IF_NEXT_3
; VPy_LINE:179
    JSR state_playing
    LBRA IF_END_0
IF_NEXT_3:
    LDD >VAR_GAME_STATE
    CMPD #3
    LBNE IF_NEXT_4
; VPy_LINE:181
    JSR state_player_dead
    LBRA IF_END_0
IF_NEXT_4:
    LDD >VAR_GAME_STATE
    CMPD #4
    LBNE IF_NEXT_5
; VPy_LINE:183
    JSR state_level_clear
    LBRA IF_END_0
IF_NEXT_5:
    LDD >VAR_GAME_STATE
    CMPD #5
    LBNE IF_NEXT_6
; VPy_LINE:185
    JSR state_boss_intro
    LBRA IF_END_0
IF_NEXT_6:
    LDD >VAR_GAME_STATE
    CMPD #6
    LBNE IF_NEXT_7
; VPy_LINE:187
    JSR state_boss
    LBRA IF_END_0
IF_NEXT_7:
    LDD >VAR_GAME_STATE
    CMPD #7
    LBNE IF_NEXT_8
; VPy_LINE:189
    JSR state_game_over
    LBRA IF_END_0
IF_NEXT_8:
    LDD >VAR_GAME_STATE
    CMPD #8
    LBNE IF_END_0
; VPy_LINE:191
    JSR state_all_clear
    LBRA IF_END_0
IF_END_0:
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX (after all game logic)
    RTS

; Function: state_title (Bank #0)
state_title:
; VPy_LINE:195
; NATIVE_CALL: DRAW_VECTOR at line 195
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: init_screen (index=5, 57 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_0          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #40
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #5        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_0:
    LDD #0
    STD RESULT
; VPy_LINE:196
; NATIVE_CALL: PRINT_TEXT at line 196
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD >VAR_ARG0
    LDD #-40
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_9120385685437879118      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:197
    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed
    BITA #$01
    LBNE .J1B1_1_ON
    LDD #0
    LBRA .J1B1_1_END
.J1B1_1_ON:
    LDD #1
.J1B1_1_END:
    STD RESULT
    LBEQ IF_NEXT_10
; VPy_LINE:198
; NATIVE_CALL: PLAY_MUSIC at line 198
    ; PLAY_MUSIC("intro") - play music asset (index=4)
    LDX #4        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
; VPy_LINE:199
    LDD #0
    STD VAR_SCORE
; VPy_LINE:200
    LDD #3  ; const LIVES_START
    STD VAR_LIVES
; VPy_LINE:201
    LDD #1
    STD VAR_CURRENT_LEVEL
; VPy_LINE:202
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD #0  ; const START_FLOOR
    CMPD TMPVAL
    LBGT .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_12
; VPy_LINE:203
    LDD #0  ; const START_FLOOR
    STD VAR_CURRENT_LEVEL
    LBRA IF_END_11
IF_NEXT_12:
IF_END_11:
; VPy_LINE:204
    JSR enter_game_start
    LBRA IF_END_9
IF_NEXT_10:
IF_END_9:
    RTS

; Function: state_game_start (Bank #0)
state_game_start:
; VPy_LINE:212
    ; ===== SHOW_LEVEL builtin =====
    JSR SHOW_LEVEL_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:213
; NATIVE_CALL: PRINT_TEXT at line 213
    ; PRINT_TEXT: Print text at position
    LDD #-30
    STD >VAR_ARG0
    LDD #20
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_78166382      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:214
; NATIVE_CALL: PRINT_NUMBER at line 214
    ; PRINT_NUMBER(x, y, num)
    LDD #30
    STD >VAR_ARG0    ; X position
    LDD #20
    STD >VAR_ARG1    ; Y position
    LDD >VAR_CURRENT_LEVEL
    STD >VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
; VPy_LINE:215
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FRAME_TIMER
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_FRAME_TIMER
; VPy_LINE:216
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FRAME_TIMER
    CMPD TMPVAL
    LBLE .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    LBEQ IF_NEXT_14
; VPy_LINE:217
    JSR load_current_level
; VPy_LINE:218
    LDD #2  ; const STATE_PLAYING
    STD VAR_GAME_STATE
    LBRA IF_END_13
IF_NEXT_14:
IF_END_13:
    RTS

; Function: state_playing (Bank #0)
state_playing:
; VPy_LINE:223
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_TIME_LEFT
    CMPD TMPVAL
    LBLE .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    LBEQ IF_NEXT_16
; VPy_LINE:224
    LDD #1  ; const INVINCIBLE
    CMPD #0
    LBNE IF_NEXT_18
; VPy_LINE:225
    JSR on_player_death
    LBRA IF_END_17
IF_NEXT_18:
IF_END_17:
    LBRA IF_END_15
IF_NEXT_16:
IF_END_15:
; VPy_LINE:226
    JSR TRAMP_update_player  ; cross-bank trampoline (bank #0 -> bank #1)
; VPy_LINE:227
    JSR TRAMP_update_snowballs  ; cross-bank trampoline (bank #0 -> bank #1)
; VPy_LINE:228
    ; UPDATE_ENEMIES: advance enemy AI and movement
    JSR UPDATE_ENEMIES_RUNTIME
; VPy_LINE:229
    JSR update_thaw
; VPy_LINE:230
    JSR update_balls
; VPy_LINE:231
    JSR ball_ball_collision
; VPy_LINE:232
    JSR TRAMP_update_frog_fire  ; cross-bank trampoline (bank #0 -> bank #1)
; VPy_LINE:233
    JSR TRAMP_update_frog_bullet  ; cross-bank trampoline (bank #0 -> bank #1)
; VPy_LINE:234
    JSR check_snowball_enemy_collision
; VPy_LINE:235
    JSR check_player_enemy_collision
; VPy_LINE:237
; NATIVE_CALL: SET_CAMERA_Y at line 237
    ; ===== SET_CAMERA_Y builtin =====
    LDD >VAR_CAMERA_Y
    STD >CAMERA_Y    ; Store 16-bit camera Y scroll offset
    LDD #0
    STD RESULT
; VPy_LINE:239
    JSR draw_player
; VPy_LINE:240
    JSR draw_snowballs
; VPy_LINE:241
    JSR draw_frog_bullet
; VPy_LINE:242
; NATIVE_CALL: SET_INTENSITY at line 242
    ; SET_INTENSITY: Set drawing intensity
    LDD #85
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:243
    ; DRAW_ENEMIES: render all active enemies
    JSR DRAW_ENEMIES_RUNTIME
; VPy_LINE:244
    JSR draw_hud
; VPy_LINE:245
    JSR count_active_enemies
    STD VAR_ENEMY_COUNT
; VPy_LINE:246
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ENEMY_COUNT
    CMPD TMPVAL
    LBLE .CMP_3_TRUE
    LDD #0
    LBRA .CMP_3_END
.CMP_3_TRUE:
    LDD #1
.CMP_3_END:
    LBEQ IF_NEXT_20
; VPy_LINE:247
    JSR enter_level_clear
    LBRA IF_END_19
IF_NEXT_20:
IF_END_19:
; VPy_LINE:248
    ; ===== SHOW_LEVEL builtin =====
    JSR SHOW_LEVEL_RUNTIME
    LDD #0
    STD RESULT
    RTS

; Function: state_player_dead (Bank #0)
state_player_dead:
; VPy_LINE:261
    ; ===== SHOW_LEVEL builtin =====
    JSR SHOW_LEVEL_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:262
    JSR draw_hud
; VPy_LINE:263
    JSR draw_player_death
; VPy_LINE:264
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FRAME_TIMER
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_FRAME_TIMER
; VPy_LINE:265
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FRAME_TIMER
    CMPD TMPVAL
    LBLE .CMP_4_TRUE
    LDD #0
    LBRA .CMP_4_END
.CMP_4_TRUE:
    LDD #1
.CMP_4_END:
    LBEQ IF_NEXT_22
; VPy_LINE:266
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_LIVES
    CMPD TMPVAL
    LBLE .CMP_5_TRUE
    LDD #0
    LBRA .CMP_5_END
.CMP_5_TRUE:
    LDD #1
.CMP_5_END:
    LBEQ IF_NEXT_24
; VPy_LINE:267
; NATIVE_CALL: PLAY_MUSIC at line 267
    ; PLAY_MUSIC("Game_Over") - play music asset (index=1)
    LDX #1        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
; VPy_LINE:268
    LDD #300  ; const GAME_OVER_DELAY
    STD VAR_FRAME_TIMER
; VPy_LINE:269
    LDD #7  ; const STATE_GAME_OVER
    STD VAR_GAME_STATE
    LBRA IF_END_23
IF_NEXT_24:
IF_END_23:
; VPy_LINE:270
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_LIVES
    CMPD TMPVAL
    LBGT .CMP_6_TRUE
    LDD #0
    LBRA .CMP_6_END
.CMP_6_TRUE:
    LDD #1
.CMP_6_END:
    LBEQ IF_NEXT_26
; VPy_LINE:271
    JSR enter_game_start
    LBRA IF_END_25
IF_NEXT_26:
IF_END_25:
    LBRA IF_END_21
IF_NEXT_22:
IF_END_21:
    RTS

; Function: draw_player_death (Bank #0)
draw_player_death:
; VPy_LINE:274
; NATIVE_CALL: SET_INTENSITY at line 274
    ; SET_INTENSITY: Set drawing intensity
    LDD #65
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:275
; NATIVE_CALL: STOP_MUSIC at line 275
    ; STOP_MUSIC: Stop music playback
    JSR STOP_MUSIC_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:276
    LDD >VAR_FRAME_TIMER
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #120  ; const DEATH_DELAY
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_ELAPSED
; VPy_LINE:277
    LDD #12
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ELAPSED
    CMPD TMPVAL
    LBLT .CMP_7_TRUE
    LDD #0
    LBRA .CMP_7_END
.CMP_7_TRUE:
    LDD #1
.CMP_7_END:
    LBEQ IF_NEXT_28
; VPy_LINE:278
; NATIVE_CALL: DRAW_VECTOR at line 278
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: player_die1 (index=25, 13 paths)
    LDD >VAR_PLAYER_X
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_2          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_CAMERA_Y
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    LDD >VAR_PLAYER_FACING
    TFR B,A
    STA MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #25        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_2:
    LDD #0
    STD RESULT
    LBRA IF_END_27
IF_NEXT_28:
; VPy_LINE:280
    LDD #22
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ELAPSED
    CMPD TMPVAL
    LBLT .CMP_8_TRUE
    LDD #0
    LBRA .CMP_8_END
.CMP_8_TRUE:
    LDD #1
.CMP_8_END:
    LBEQ IF_NEXT_30
; VPy_LINE:281
; NATIVE_CALL: DRAW_VECTOR at line 281
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: player_die2 (index=26, 12 paths)
    LDD >VAR_PLAYER_X
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_3          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_CAMERA_Y
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    LDD >VAR_PLAYER_FACING
    TFR B,A
    STA MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #26        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_3:
    LDD #0
    STD RESULT
    LBRA IF_END_29
IF_NEXT_30:
; VPy_LINE:283
    LDD #32
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ELAPSED
    CMPD TMPVAL
    LBLT .CMP_9_TRUE
    LDD #0
    LBRA .CMP_9_END
.CMP_9_TRUE:
    LDD #1
.CMP_9_END:
    LBEQ IF_NEXT_32
; VPy_LINE:284
; NATIVE_CALL: DRAW_VECTOR at line 284
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: player_die3 (index=27, 12 paths)
    LDD >VAR_PLAYER_X
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_4          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_CAMERA_Y
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    LDD >VAR_PLAYER_FACING
    TFR B,A
    STA MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #27        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_4:
    LDD #0
    STD RESULT
    LBRA IF_END_31
IF_NEXT_32:
; VPy_LINE:286
; NATIVE_CALL: DRAW_VECTOR at line 286
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: player_die4 (index=28, 16 paths)
    LDD >VAR_PLAYER_X
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_5          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_CAMERA_Y
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    LDD >VAR_PLAYER_FACING
    TFR B,A
    STA MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #28        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_5:
    LDD #0
    STD RESULT
IF_END_31:
IF_END_29:
IF_END_27:
    RTS

; Function: state_level_clear (Bank #0)
state_level_clear:
; VPy_LINE:290
    LDD >VAR_SCROLL_TARGET
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CAMERA_Y
    CMPD TMPVAL
    LBLT .CMP_10_TRUE
    LDD #0
    LBRA .CMP_10_END
.CMP_10_TRUE:
    LDD #1
.CMP_10_END:
    LBEQ IF_NEXT_34
; VPy_LINE:291
    LDD #3
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_CAMERA_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_CAMERA_Y
; VPy_LINE:292
    LDD >VAR_SCROLL_TARGET
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CAMERA_Y
    CMPD TMPVAL
    LBGT .CMP_11_TRUE
    LDD #0
    LBRA .CMP_11_END
.CMP_11_TRUE:
    LDD #1
.CMP_11_END:
    LBEQ IF_NEXT_36
; VPy_LINE:293
    LDD >VAR_SCROLL_TARGET
    STD VAR_CAMERA_Y
    LBRA IF_END_35
IF_NEXT_36:
IF_END_35:
    LBRA IF_END_33
IF_NEXT_34:
IF_END_33:
; VPy_LINE:294
; NATIVE_CALL: SET_CAMERA_Y at line 294
    ; ===== SET_CAMERA_Y builtin =====
    LDD >VAR_CAMERA_Y
    STD >CAMERA_Y    ; Store 16-bit camera Y scroll offset
    LDD #0
    STD RESULT
; VPy_LINE:295
    ; ===== SHOW_LEVEL builtin =====
    JSR SHOW_LEVEL_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:296
    JSR draw_hud
; VPy_LINE:297
; NATIVE_CALL: PRINT_TEXT at line 297
    ; PRINT_TEXT: Print text at position
    LDD #-35
    STD >VAR_ARG0
    LDD #0
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_1989933374265095120      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:298
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FRAME_TIMER
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_FRAME_TIMER
; VPy_LINE:299
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FRAME_TIMER
    CMPD TMPVAL
    LBLE .CMP_12_TRUE
    LDD #0
    LBRA .CMP_12_END
.CMP_12_TRUE:
    LDD #1
.CMP_12_END:
    LBEQ IF_NEXT_38
; VPy_LINE:300
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_CURRENT_LEVEL
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_CURRENT_LEVEL
; VPy_LINE:301
    LDD #50
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LEVEL
    CMPD TMPVAL
    LBGT .CMP_13_TRUE
    LDD #0
    LBRA .CMP_13_END
.CMP_13_TRUE:
    LDD #1
.CMP_13_END:
    LBEQ IF_NEXT_40
; VPy_LINE:302
    LDD #300  ; const ALL_CLEAR_DELAY
    STD VAR_FRAME_TIMER
; VPy_LINE:303
; NATIVE_CALL: STOP_MUSIC at line 303
    ; STOP_MUSIC: Stop music playback
    JSR STOP_MUSIC_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:304
    LDD #8  ; const STATE_ALL_CLEAR
    STD VAR_GAME_STATE
    LBRA IF_END_39
IF_NEXT_40:
IF_END_39:
; VPy_LINE:305
    LDD #50
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LEVEL
    CMPD TMPVAL
    LBLE .CMP_14_TRUE
    LDD #0
    LBRA .CMP_14_END
.CMP_14_TRUE:
    LDD #1
.CMP_14_END:
    LBEQ IF_NEXT_42
; VPy_LINE:306
    JSR check_if_boss_level
; VPy_LINE:307
    LDD >VAR_NEXT_IS_BOSS
    CMPD #1
    LBNE IF_NEXT_44
; VPy_LINE:308
    JSR enter_boss_intro
    LBRA IF_END_43
IF_NEXT_44:
IF_END_43:
; VPy_LINE:309
    LDD >VAR_NEXT_IS_BOSS
    CMPD #0
    LBNE IF_NEXT_46
; VPy_LINE:310
    JSR enter_game_start
    LBRA IF_END_45
IF_NEXT_46:
IF_END_45:
    LBRA IF_END_41
IF_NEXT_42:
IF_END_41:
    LBRA IF_END_37
IF_NEXT_38:
IF_END_37:
    RTS

; Function: state_boss_intro (Bank #0)
state_boss_intro:
; VPy_LINE:314
; NATIVE_CALL: PRINT_TEXT at line 314
    ; PRINT_TEXT: Print text at position
    LDD #-30
    STD >VAR_ARG0
    LDD #20
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2453707043877      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:315
; NATIVE_CALL: PRINT_TEXT at line 315
    ; PRINT_TEXT: Print text at position
    LDD #-50
    STD >VAR_ARG0
    LDD #0
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_17169778266052697977      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:316
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FRAME_TIMER
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_FRAME_TIMER
; VPy_LINE:317
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FRAME_TIMER
    CMPD TMPVAL
    LBLE .CMP_15_TRUE
    LDD #0
    LBRA .CMP_15_END
.CMP_15_TRUE:
    LDD #1
.CMP_15_END:
    LBEQ IF_NEXT_48
; VPy_LINE:318
    JSR load_current_level
; VPy_LINE:319
    JSR play_boss_music
; VPy_LINE:320
    LDD #6  ; const STATE_BOSS
    STD VAR_GAME_STATE
    LBRA IF_END_47
IF_NEXT_48:
IF_END_47:
    RTS

; Function: state_boss (Bank #0)
state_boss:
; VPy_LINE:327
    JSR TRAMP_update_player  ; cross-bank trampoline (bank #0 -> bank #1)
; VPy_LINE:328
    JSR TRAMP_update_snowballs  ; cross-bank trampoline (bank #0 -> bank #1)
; VPy_LINE:329
    ; UPDATE_ENEMIES: advance enemy AI and movement
    JSR UPDATE_ENEMIES_RUNTIME
; VPy_LINE:330
    JSR check_snowball_enemy_collision
; VPy_LINE:331
    ; ===== SHOW_LEVEL builtin =====
    JSR SHOW_LEVEL_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:332
    JSR draw_player
; VPy_LINE:333
    JSR draw_snowballs
; VPy_LINE:334
; NATIVE_CALL: SET_INTENSITY at line 334
    ; SET_INTENSITY: Set drawing intensity
    LDD #85
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:335
    ; DRAW_ENEMIES: render all active enemies
    JSR DRAW_ENEMIES_RUNTIME
; VPy_LINE:336
    JSR draw_hud
    RTS

; Function: state_game_over (Bank #0)
state_game_over:
; VPy_LINE:340
; NATIVE_CALL: PRINT_TEXT at line 340
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
; VPy_LINE:341
; NATIVE_CALL: PRINT_TEXT at line 341
    ; PRINT_TEXT: Print text at position
    LDD #-30
    STD >VAR_ARG0
    LDD #0
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_78726770      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:342
; NATIVE_CALL: PRINT_NUMBER at line 342
    ; PRINT_NUMBER(x, y, num)
    LDD #30
    STD >VAR_ARG0    ; X position
    LDD #0
    STD >VAR_ARG1    ; Y position
    LDD >VAR_SCORE
    STD >VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
; VPy_LINE:343
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FRAME_TIMER
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_FRAME_TIMER
; VPy_LINE:344
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FRAME_TIMER
    CMPD TMPVAL
    LBLE .CMP_16_TRUE
    LDD #0
    LBRA .CMP_16_END
.CMP_16_TRUE:
    LDD #1
.CMP_16_END:
    LBEQ IF_NEXT_50
; VPy_LINE:345
; NATIVE_CALL: STOP_MUSIC at line 345
    ; STOP_MUSIC: Stop music playback
    JSR STOP_MUSIC_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:346
    LDD #0  ; const STATE_TITLE
    STD VAR_GAME_STATE
    LBRA IF_END_49
IF_NEXT_50:
IF_END_49:
    RTS

; Function: state_all_clear (Bank #0)
state_all_clear:
; VPy_LINE:350
; NATIVE_CALL: PRINT_TEXT at line 350
    ; PRINT_TEXT: Print text at position
    LDD #-55
    STD >VAR_ARG0
    LDD #30
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_13399742582312315532      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:351
; NATIVE_CALL: PRINT_TEXT at line 351
    ; PRINT_TEXT: Print text at position
    LDD #-30
    STD >VAR_ARG0
    LDD #5
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_1785516508540691      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:352
; NATIVE_CALL: PRINT_TEXT at line 352
    ; PRINT_TEXT: Print text at position
    LDD #-25
    STD >VAR_ARG0
    LDD #-20
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_78726770      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:353
; NATIVE_CALL: PRINT_NUMBER at line 353
    ; PRINT_NUMBER(x, y, num)
    LDD #30
    STD >VAR_ARG0    ; X position
    LDD #-20
    STD >VAR_ARG1    ; Y position
    LDD >VAR_SCORE
    STD >VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
; VPy_LINE:354
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FRAME_TIMER
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_FRAME_TIMER
; VPy_LINE:355
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FRAME_TIMER
    CMPD TMPVAL
    LBLE .CMP_17_TRUE
    LDD #0
    LBRA .CMP_17_END
.CMP_17_TRUE:
    LDD #1
.CMP_17_END:
    LBEQ IF_NEXT_52
; VPy_LINE:356
    LDD #0  ; const STATE_TITLE
    STD VAR_GAME_STATE
    LBRA IF_END_51
IF_NEXT_52:
IF_END_51:
    RTS

; Function: enter_game_start (Bank #0)
enter_game_start:
; VPy_LINE:360
    LDD #120  ; const GAME_START_DELAY
    STD VAR_FRAME_TIMER
; VPy_LINE:361
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_CURRENT_LEVEL
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD TMPVAL          ; LEFT → TMPVAL (RIGHT simple, commutative)
    LDD #256
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-2304  ; const CAMERA_Y_MIN
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_CAMERA_Y
; VPy_LINE:362
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CAMERA_Y
    CMPD TMPVAL
    LBGT .CMP_18_TRUE
    LDD #0
    LBRA .CMP_18_END
.CMP_18_TRUE:
    LDD #1
.CMP_18_END:
    LBEQ IF_NEXT_54
; VPy_LINE:363
    LDD #0
    STD VAR_CAMERA_Y
    LBRA IF_END_53
IF_NEXT_54:
IF_END_53:
; VPy_LINE:364
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'world_1_1'
    ; Level asset index: 0 (multibank)
    LDX #0
    JSR LOAD_LEVEL_BANKED
; VPy_LINE:365
; NATIVE_CALL: SET_CAMERA_Y at line 365
    ; ===== SET_CAMERA_Y builtin =====
    LDD >VAR_CAMERA_Y
    STD >CAMERA_Y    ; Store 16-bit camera Y scroll offset
    LDD #0
    STD RESULT
; VPy_LINE:366
    LDD #1  ; const STATE_GAME_START
    STD VAR_GAME_STATE
    RTS

; Function: enter_level_clear (Bank #0)
enter_level_clear:
; VPy_LINE:369
    LDD #150  ; const LEVEL_CLEAR_DELAY
    STD VAR_FRAME_TIMER
; VPy_LINE:370
    LDD #256
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_CAMERA_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_SCROLL_TARGET
; VPy_LINE:371
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SCROLL_TARGET
    CMPD TMPVAL
    LBGT .CMP_19_TRUE
    LDD #0
    LBRA .CMP_19_END
.CMP_19_TRUE:
    LDD #1
.CMP_19_END:
    LBEQ IF_NEXT_56
; VPy_LINE:372
    LDD #0
    STD VAR_SCROLL_TARGET
    LBRA IF_END_55
IF_NEXT_56:
IF_END_55:
; VPy_LINE:373
    LDD #4  ; const STATE_LEVEL_CLEAR
    STD VAR_GAME_STATE
    RTS

; Function: enter_boss_intro (Bank #0)
enter_boss_intro:
; VPy_LINE:376
; NATIVE_CALL: PLAY_MUSIC at line 376
    ; PLAY_MUSIC("Boss_Intro") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
; VPy_LINE:377
    LDD #180  ; const BOSS_INTRO_DELAY
    STD VAR_FRAME_TIMER
; VPy_LINE:378
    LDD #5  ; const STATE_BOSS_INTRO
    STD VAR_GAME_STATE
    RTS

; Function: on_player_death (Bank #0)
on_player_death:
; VPy_LINE:381
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_LIVES
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_LIVES
; VPy_LINE:382
    LDD #120  ; const DEATH_DELAY
    STD VAR_FRAME_TIMER
; VPy_LINE:383
    LDD #3  ; const STATE_PLAYER_DEAD
    STD VAR_GAME_STATE
    RTS

; Function: check_if_boss_level (Bank #0)
check_if_boss_level:
; VPy_LINE:387
    LDD #0
    STD VAR_NEXT_IS_BOSS
; VPy_LINE:388
    LDD >VAR_CURRENT_LEVEL
    CMPD #10
    LBNE IF_NEXT_58
; VPy_LINE:389
    LDD #1
    STD VAR_NEXT_IS_BOSS
    LBRA IF_END_57
IF_NEXT_58:
IF_END_57:
; VPy_LINE:390
    LDD >VAR_CURRENT_LEVEL
    CMPD #20
    LBNE IF_NEXT_60
; VPy_LINE:391
    LDD #1
    STD VAR_NEXT_IS_BOSS
    LBRA IF_END_59
IF_NEXT_60:
IF_END_59:
; VPy_LINE:392
    LDD >VAR_CURRENT_LEVEL
    CMPD #30
    LBNE IF_NEXT_62
; VPy_LINE:393
    LDD #1
    STD VAR_NEXT_IS_BOSS
    LBRA IF_END_61
IF_NEXT_62:
IF_END_61:
; VPy_LINE:394
    LDD >VAR_CURRENT_LEVEL
    CMPD #40
    LBNE IF_NEXT_64
; VPy_LINE:395
    LDD #1
    STD VAR_NEXT_IS_BOSS
    LBRA IF_END_63
IF_NEXT_64:
IF_END_63:
; VPy_LINE:396
    LDD >VAR_CURRENT_LEVEL
    CMPD #50
    LBNE IF_NEXT_66
; VPy_LINE:397
    LDD #1
    STD VAR_NEXT_IS_BOSS
    LBRA IF_END_65
IF_NEXT_66:
IF_END_65:
    RTS

; Function: load_current_level (Bank #0)
load_current_level:
; VPy_LINE:401
; NATIVE_CALL: STOP_MUSIC at line 401
    ; STOP_MUSIC: Stop music playback
    JSR STOP_MUSIC_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:402
    LDD #3600  ; const LEVEL_TIME
    STD VAR_TIME_LEFT
; VPy_LINE:403
    LDD #0
    STD VAR_PLAYER_X
; VPy_LINE:404
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_CURRENT_LEVEL
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD TMPVAL          ; LEFT → TMPVAL (RIGHT simple, commutative)
    LDD #256
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-2304  ; const CAMERA_Y_MIN
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_CAMERA_Y
; VPy_LINE:405
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CAMERA_Y
    CMPD TMPVAL
    LBGT .CMP_20_TRUE
    LDD #0
    LBRA .CMP_20_END
.CMP_20_TRUE:
    LDD #1
.CMP_20_END:
    LBEQ IF_NEXT_68
; VPy_LINE:406
    LDD #0
    STD VAR_CAMERA_Y
    LBRA IF_END_67
IF_NEXT_68:
IF_END_67:
; VPy_LINE:407
    LDD #77
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_CAMERA_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_PLAYER_Y
; VPy_LINE:408
    LDD #0
    STD VAR_PLAYER_VY
; VPy_LINE:409
    LDD #1
    STD VAR_PLAYER_ON_GROUND
; VPy_LINE:410
    LDD #0
    STD VAR_SHOOT_COOLDOWN
; VPy_LINE:411
    LDD #0
    STD VAR_SNOW0_ACTIVE
; VPy_LINE:412
    LDD #0
    STD VAR_SNOW1_ACTIVE
; VPy_LINE:413
    LDD #0
    STD VAR_SNOW2_ACTIVE
; VPy_LINE:414
    LDD #14  ; const SNOW_LIFE_NORMAL
    STD VAR_SNOW_LIFE_MAX
; VPy_LINE:415
    LDD #0
    STD VAR_PLAYER_HAS_POWER
; VPy_LINE:416
    JSR reset_balls
; VPy_LINE:417
    JSR reset_frog_fire
; VPy_LINE:422
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'world_1_1'
    ; Level asset index: 0 (multibank)
    LDX #0
    JSR LOAD_LEVEL_BANKED
; VPy_LINE:423
    ; SPAWN_ENEMIES("world_1_1")
    JSR SPAWN_ENEMIES_BANKED
; VPy_LINE:424
    JSR kill_offscreen_enemies
; VPy_LINE:427
    LDD >VAR_CURRENT_LEVEL
    CMPD #16
    LBNE IF_NEXT_70
; VPy_LINE:428
; NATIVE_CALL: PLAY_MUSIC at line 428
    ; PLAY_MUSIC("Henshoku") - play music asset (index=2)
    LDX #2        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_69
IF_NEXT_70:
    LDD >VAR_CURRENT_LEVEL
    CMPD #7
    LBNE IF_NEXT_71
; VPy_LINE:430
; NATIVE_CALL: PLAY_MUSIC at line 430
    ; PLAY_MUSIC("Henshoku") - play music asset (index=2)
    LDX #2        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_69
IF_NEXT_71:
; VPy_LINE:432
; NATIVE_CALL: PLAY_MUSIC at line 432
    ; PLAY_MUSIC("Yukidama-Ondo") - play music asset (index=3)
    LDX #3        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
IF_END_69:
; VPy_LINE:434
    ; ===== GET_LEVEL_FLOOR_Y builtin =====
    JSR GET_LEVEL_FLOOR_Y_RUNTIME
    STD TMPVAL          ; LEFT → TMPVAL (RIGHT simple, commutative)
    LDD #11  ; const PLAYER_HH
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_SPAWN_FLOOR_Y
; VPy_LINE:435
    LDD >VAR_SPAWN_FLOOR_Y
    STD VAR_PLAYER_Y
    RTS

; Function: play_boss_music (Bank #0)
play_boss_music:
; VPy_LINE:439
    LDD >VAR_CURRENT_LEVEL
    CMPD #10
    LBNE IF_NEXT_73
; VPy_LINE:440
; NATIVE_CALL: PLAY_MUSIC at line 440
    ; PLAY_MUSIC("Boss_Intro") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_72
IF_NEXT_73:
    LDD >VAR_CURRENT_LEVEL
    CMPD #20
    LBNE IF_NEXT_74
; VPy_LINE:442
; NATIVE_CALL: PLAY_MUSIC at line 442
    ; PLAY_MUSIC("Boss_Intro") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_72
IF_NEXT_74:
    LDD >VAR_CURRENT_LEVEL
    CMPD #30
    LBNE IF_NEXT_75
; VPy_LINE:444
; NATIVE_CALL: PLAY_MUSIC at line 444
    ; PLAY_MUSIC("Boss_Intro") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_72
IF_NEXT_75:
    LDD >VAR_CURRENT_LEVEL
    CMPD #40
    LBNE IF_NEXT_76
; VPy_LINE:446
; NATIVE_CALL: PLAY_MUSIC at line 446
    ; PLAY_MUSIC("Boss_Intro") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_72
IF_NEXT_76:
    LDD >VAR_CURRENT_LEVEL
    CMPD #50
    LBNE IF_END_72
; VPy_LINE:448
; NATIVE_CALL: PLAY_MUSIC at line 448
    ; PLAY_MUSIC("Boss_Intro") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_72
IF_END_72:
    RTS

; Function: draw_player (Bank #0)
draw_player:
; VPy_LINE:520
; NATIVE_CALL: SET_INTENSITY at line 520
    ; SET_INTENSITY: Set drawing intensity
    LDD #65
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:521
    LDD >VAR_PLAYER_ON_GROUND
    CMPD #0
    LBNE IF_NEXT_116
; VPy_LINE:522
; NATIVE_CALL: DRAW_VECTOR at line 522
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: player_jump (index=30, 12 paths)
    LDD >VAR_PLAYER_X
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_8          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_CAMERA_Y
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    LDD >VAR_PLAYER_FACING
    TFR B,A
    STA MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #30        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_8:
    LDD #0
    STD RESULT
    LBRA IF_END_115
IF_NEXT_116:
IF_END_115:
; VPy_LINE:523
    LDD >VAR_PLAYER_ON_GROUND
    CMPD #1
    LBNE IF_NEXT_118
; VPy_LINE:524
    LDD >VAR_PLAYER_VX
    CMPD #0
    LBNE IF_NEXT_120
; VPy_LINE:525
; NATIVE_CALL: DRAW_VECTOR at line 525
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: player_idle (index=29, 8 paths)
    LDD >VAR_PLAYER_X
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_9          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_CAMERA_Y
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    LDD >VAR_PLAYER_FACING
    TFR B,A
    STA MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #29        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_9:
    LDD #0
    STD RESULT
    LBRA IF_END_119
IF_NEXT_120:
; VPy_LINE:527
; NATIVE_CALL: DRAW_ANIM at line 527
    ; DRAW_ANIM: draw animation 'player_walk'
    LDD >VAR_PLAYER_X
    TFR B,A
    STA DRAW_VEC_X
    LDD >VAR_CAMERA_Y
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    TFR B,A
    STA DRAW_VEC_Y
    LDD >VAR_PLAYER_FACING
    TFR B,A
    STA >MIRROR_X
    STA >DRAW_ANIM_MIRROR_X
    CLR >MIRROR_Y
    LDA #$7F
    STA DRAW_ANIM_SCALE
    CLR DRAW_ANIM_SPEED_MUL
    LDX #_ANIM_PLAYER_WALK
    LDU #ANIM_PLAYER_WALK_STATE
    JSR DRAW_ANIM_RUNTIME
    LDD #0
    STD RESULT
IF_END_119:
    LBRA IF_END_117
IF_NEXT_118:
IF_END_117:
    RTS

; Function: try_shoot (Bank #0)
try_shoot:
; VPy_LINE:531
    LDD >VAR_SNOW0_ACTIVE
    CMPD #0
    LBNE IF_NEXT_122
; VPy_LINE:532
    LDD >VAR_PLAYER_X
    STD VAR_SNOW0_X
; VPy_LINE:533
    LDD >VAR_PLAYER_Y
    STD VAR_SNOW0_Y
; VPy_LINE:534
    LDD >VAR_SNOW_SPAWN_VX
    STD VAR_SNOW0_VX
; VPy_LINE:535
    LDD #3  ; const SNOW_LAUNCH_VY
    STD VAR_SNOW0_VY
; VPy_LINE:536
    LDD >VAR_SNOW_LIFE_MAX
    STD VAR_SNOW0_LIFE
; VPy_LINE:537
    LDD #1
    STD VAR_SNOW0_ACTIVE
; VPy_LINE:538
    LDD #15  ; const SHOOT_COOLDOWN_MAX
    STD VAR_SHOOT_COOLDOWN
; VPy_LINE:539
; NATIVE_CALL: PLAY_SFX at line 539
    ; PLAY_SFX("shot_normal") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_121
IF_NEXT_122:
; VPy_LINE:541
    LDD >VAR_SNOW1_ACTIVE
    CMPD #0
    LBNE IF_NEXT_124
; VPy_LINE:542
    LDD >VAR_PLAYER_X
    STD VAR_SNOW1_X
; VPy_LINE:543
    LDD >VAR_PLAYER_Y
    STD VAR_SNOW1_Y
; VPy_LINE:544
    LDD >VAR_SNOW_SPAWN_VX
    STD VAR_SNOW1_VX
; VPy_LINE:545
    LDD #3  ; const SNOW_LAUNCH_VY
    STD VAR_SNOW1_VY
; VPy_LINE:546
    LDD >VAR_SNOW_LIFE_MAX
    STD VAR_SNOW1_LIFE
; VPy_LINE:547
    LDD #1
    STD VAR_SNOW1_ACTIVE
; VPy_LINE:548
    LDD #15  ; const SHOOT_COOLDOWN_MAX
    STD VAR_SHOOT_COOLDOWN
; VPy_LINE:549
; NATIVE_CALL: PLAY_SFX at line 549
    ; PLAY_SFX("shot_normal") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_123
IF_NEXT_124:
; VPy_LINE:551
    LDD >VAR_SNOW2_ACTIVE
    CMPD #0
    LBNE IF_NEXT_126
; VPy_LINE:552
    LDD >VAR_PLAYER_X
    STD VAR_SNOW2_X
; VPy_LINE:553
    LDD >VAR_PLAYER_Y
    STD VAR_SNOW2_Y
; VPy_LINE:554
    LDD >VAR_SNOW_SPAWN_VX
    STD VAR_SNOW2_VX
; VPy_LINE:555
    LDD #3  ; const SNOW_LAUNCH_VY
    STD VAR_SNOW2_VY
; VPy_LINE:556
    LDD >VAR_SNOW_LIFE_MAX
    STD VAR_SNOW2_LIFE
; VPy_LINE:557
    LDD #1
    STD VAR_SNOW2_ACTIVE
; VPy_LINE:558
    LDD #15  ; const SHOOT_COOLDOWN_MAX
    STD VAR_SHOOT_COOLDOWN
; VPy_LINE:559
; NATIVE_CALL: PLAY_SFX at line 559
    ; PLAY_SFX("shot_normal") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_125
IF_NEXT_126:
IF_END_125:
IF_END_123:
IF_END_121:
    RTS

; Function: draw_snowballs (Bank #0)
draw_snowballs:
; VPy_LINE:609
    LDD >VAR_SNOW0_ACTIVE
    CMPD #1
    LBNE IF_NEXT_164
; VPy_LINE:610
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD >VAR_SNOW0_X
    TFR B,A
    STA DRAW_CIRCLE_XC
    LDD >VAR_CAMERA_Y
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_SNOW0_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    TFR B,A
    STA DRAW_CIRCLE_YC
    LDD #5
    TFR B,A
    STA DRAW_CIRCLE_DIAM
    LDD #120
    TFR B,A
    STA DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_163
IF_NEXT_164:
IF_END_163:
; VPy_LINE:611
    LDD >VAR_SNOW1_ACTIVE
    CMPD #1
    LBNE IF_NEXT_166
; VPy_LINE:612
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD >VAR_SNOW1_X
    TFR B,A
    STA DRAW_CIRCLE_XC
    LDD >VAR_CAMERA_Y
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_SNOW1_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    TFR B,A
    STA DRAW_CIRCLE_YC
    LDD #5
    TFR B,A
    STA DRAW_CIRCLE_DIAM
    LDD #120
    TFR B,A
    STA DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_165
IF_NEXT_166:
IF_END_165:
; VPy_LINE:613
    LDD >VAR_SNOW2_ACTIVE
    CMPD #1
    LBNE IF_NEXT_168
; VPy_LINE:614
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD >VAR_SNOW2_X
    TFR B,A
    STA DRAW_CIRCLE_XC
    LDD >VAR_CAMERA_Y
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_SNOW2_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    TFR B,A
    STA DRAW_CIRCLE_YC
    LDD #5
    TFR B,A
    STA DRAW_CIRCLE_DIAM
    LDD #120
    TFR B,A
    STA DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_167
IF_NEXT_168:
IF_END_167:
    RTS

; Function: draw_hud (Bank #0)
draw_hud:
; VPy_LINE:618
; NATIVE_CALL: PRINT_NUMBER at line 618
    ; PRINT_NUMBER(x, y, num)
    LDD #0
    STD >VAR_ARG0    ; X position
    LDD #127
    STD >VAR_ARG1    ; Y position
    LDD >VAR_SCORE
    STD >VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
; VPy_LINE:619
; NATIVE_CALL: PRINT_NUMBER at line 619
    ; PRINT_NUMBER(x, y, num)
    LDD #-78
    STD >VAR_ARG0    ; X position
    LDD #127
    STD >VAR_ARG1    ; Y position
    LDD >VAR_LIVES
    STD >VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
; VPy_LINE:620
; NATIVE_CALL: PRINT_NUMBER at line 620
    ; PRINT_NUMBER(x, y, num)
    LDD #58
    STD >VAR_ARG0    ; X position
    LDD #127
    STD >VAR_ARG1    ; Y position
    LDD #60
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_TIME_LEFT
    TFR D,X             ; X = LEFT (dividend)
    LDD TMPVAL          ; D = RIGHT (divisor)
    JSR DIV16           ; D = X / D
    STD >VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    RTS

; Function: check_snowball_enemy_collision (Bank #0)
check_snowball_enemy_collision:
; VPy_LINE:625
    LDD #0
    STD VAR_I
; VPy_LINE:626
WH_169: ; while start
    LDD #8
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    CMPD TMPVAL
    LBLT .CMP_47_TRUE
    LDD #0
    LBRA .CMP_47_END
.CMP_47_TRUE:
    LDD #1
.CMP_47_END:
    LBEQ WH_END_170
; VPy_LINE:627
    LDD >VAR_I
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    CLRA
    LDB ,X              ; active byte
    STD RESULT
    CMPD #1
    LBNE IF_NEXT_172
; VPy_LINE:628
; NATIVE_CALL: GET_ENEMY_X at line 628
    LDD >VAR_I
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    LDA 1,X             ; x hi
    LDB 2,X             ; x lo
    STD RESULT
    STD VAR_EX
; VPy_LINE:629
; NATIVE_CALL: GET_ENEMY_Y at line 629
    LDD >VAR_I
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    LDA 3,X             ; y hi
    LDB 4,X             ; y lo
    STD RESULT
    STD VAR_EY
; VPy_LINE:630
    LDD >VAR_I
    STD VAR_ARG0
    LDD >VAR_EX
    STD VAR_ARG1
    LDD >VAR_EY
    STD VAR_ARG2
    JSR check_snow_vs_enemy
    LBRA IF_END_171
IF_NEXT_172:
IF_END_171:
; VPy_LINE:631
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_I
    LBRA WH_169
WH_END_170: ; while end
    RTS

; Function: check_snow_vs_enemy (Bank #0)
check_snow_vs_enemy:
; VPy_LINE:634
    LDD #6  ; const ENEMY_HW
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #6  ; const SNOW_HW
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_THW
; VPy_LINE:635
    LDD #8  ; const ENEMY_HH
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #16  ; const SNOW_HH
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_THH
; VPy_LINE:636
    LDD >VAR_SNOW0_ACTIVE
    CMPD #1
    LBNE IF_NEXT_174
; VPy_LINE:637
    LDD >VAR_ARG1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_SNOW0_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:638
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DX
    CMPD TMPVAL
    LBLT .CMP_48_TRUE
    LDD #0
    LBRA .CMP_48_END
.CMP_48_TRUE:
    LDD #1
.CMP_48_END:
    LBEQ IF_NEXT_176
; VPy_LINE:639
    LDD >VAR_DX
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD VAR_DX
    LBRA IF_END_175
IF_NEXT_176:
IF_END_175:
; VPy_LINE:640
    LDD >VAR_ARG2
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_SNOW0_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:641
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DY
    CMPD TMPVAL
    LBLT .CMP_49_TRUE
    LDD #0
    LBRA .CMP_49_END
.CMP_49_TRUE:
    LDD #1
.CMP_49_END:
    LBEQ IF_NEXT_178
; VPy_LINE:642
    LDD >VAR_DY
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD VAR_DY
    LBRA IF_END_177
IF_NEXT_178:
IF_END_177:
; VPy_LINE:643
    LDD >VAR_THW
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DX
    CMPD TMPVAL
    LBLT .CMP_50_TRUE
    LDD #0
    LBRA .CMP_50_END
.CMP_50_TRUE:
    LDD #1
.CMP_50_END:
    LBEQ IF_NEXT_180
; VPy_LINE:644
    LDD >VAR_THH
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DY
    CMPD TMPVAL
    LBLT .CMP_51_TRUE
    LDD #0
    LBRA .CMP_51_END
.CMP_51_TRUE:
    LDD #1
.CMP_51_END:
    LBEQ IF_NEXT_182
; VPy_LINE:645
    LDD #0
    STD VAR_SNOW0_ACTIVE
; VPy_LINE:646
    LDD >VAR_ARG0
    STD VAR_ARG0
    JSR on_snow_hit_enemy
    LBRA IF_END_181
IF_NEXT_182:
IF_END_181:
    LBRA IF_END_179
IF_NEXT_180:
IF_END_179:
    LBRA IF_END_173
IF_NEXT_174:
IF_END_173:
; VPy_LINE:647
    LDD >VAR_SNOW1_ACTIVE
    CMPD #1
    LBNE IF_NEXT_184
; VPy_LINE:648
    LDD >VAR_ARG1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_SNOW1_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:649
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DX
    CMPD TMPVAL
    LBLT .CMP_52_TRUE
    LDD #0
    LBRA .CMP_52_END
.CMP_52_TRUE:
    LDD #1
.CMP_52_END:
    LBEQ IF_NEXT_186
; VPy_LINE:650
    LDD >VAR_DX
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD VAR_DX
    LBRA IF_END_185
IF_NEXT_186:
IF_END_185:
; VPy_LINE:651
    LDD >VAR_ARG2
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_SNOW1_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:652
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DY
    CMPD TMPVAL
    LBLT .CMP_53_TRUE
    LDD #0
    LBRA .CMP_53_END
.CMP_53_TRUE:
    LDD #1
.CMP_53_END:
    LBEQ IF_NEXT_188
; VPy_LINE:653
    LDD >VAR_DY
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD VAR_DY
    LBRA IF_END_187
IF_NEXT_188:
IF_END_187:
; VPy_LINE:654
    LDD >VAR_THW
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DX
    CMPD TMPVAL
    LBLT .CMP_54_TRUE
    LDD #0
    LBRA .CMP_54_END
.CMP_54_TRUE:
    LDD #1
.CMP_54_END:
    LBEQ IF_NEXT_190
; VPy_LINE:655
    LDD >VAR_THH
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DY
    CMPD TMPVAL
    LBLT .CMP_55_TRUE
    LDD #0
    LBRA .CMP_55_END
.CMP_55_TRUE:
    LDD #1
.CMP_55_END:
    LBEQ IF_NEXT_192
; VPy_LINE:656
    LDD #0
    STD VAR_SNOW1_ACTIVE
; VPy_LINE:657
    LDD >VAR_ARG0
    STD VAR_ARG0
    JSR on_snow_hit_enemy
    LBRA IF_END_191
IF_NEXT_192:
IF_END_191:
    LBRA IF_END_189
IF_NEXT_190:
IF_END_189:
    LBRA IF_END_183
IF_NEXT_184:
IF_END_183:
; VPy_LINE:658
    LDD >VAR_SNOW2_ACTIVE
    CMPD #1
    LBNE IF_NEXT_194
; VPy_LINE:659
    LDD >VAR_ARG1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_SNOW2_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:660
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DX
    CMPD TMPVAL
    LBLT .CMP_56_TRUE
    LDD #0
    LBRA .CMP_56_END
.CMP_56_TRUE:
    LDD #1
.CMP_56_END:
    LBEQ IF_NEXT_196
; VPy_LINE:661
    LDD >VAR_DX
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD VAR_DX
    LBRA IF_END_195
IF_NEXT_196:
IF_END_195:
; VPy_LINE:662
    LDD >VAR_ARG2
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_SNOW2_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:663
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DY
    CMPD TMPVAL
    LBLT .CMP_57_TRUE
    LDD #0
    LBRA .CMP_57_END
.CMP_57_TRUE:
    LDD #1
.CMP_57_END:
    LBEQ IF_NEXT_198
; VPy_LINE:664
    LDD >VAR_DY
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD VAR_DY
    LBRA IF_END_197
IF_NEXT_198:
IF_END_197:
; VPy_LINE:665
    LDD >VAR_THW
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DX
    CMPD TMPVAL
    LBLT .CMP_58_TRUE
    LDD #0
    LBRA .CMP_58_END
.CMP_58_TRUE:
    LDD #1
.CMP_58_END:
    LBEQ IF_NEXT_200
; VPy_LINE:666
    LDD >VAR_THH
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DY
    CMPD TMPVAL
    LBLT .CMP_59_TRUE
    LDD #0
    LBRA .CMP_59_END
.CMP_59_TRUE:
    LDD #1
.CMP_59_END:
    LBEQ IF_NEXT_202
; VPy_LINE:667
    LDD #0
    STD VAR_SNOW2_ACTIVE
; VPy_LINE:668
    LDD >VAR_ARG0
    STD VAR_ARG0
    JSR on_snow_hit_enemy
    LBRA IF_END_201
IF_NEXT_202:
IF_END_201:
    LBRA IF_END_199
IF_NEXT_200:
IF_END_199:
    LBRA IF_END_193
IF_NEXT_194:
IF_END_193:
    RTS

; Function: on_snow_hit_enemy (Bank #0)
on_snow_hit_enemy:
; VPy_LINE:671
; NATIVE_CALL: ENEMY_FIRE_EVENT at line 671
    LDD >VAR_ARG0
    TFR B,A             ; A = enemy index
    LDB #$1C              ; event hash 'onSnowHit'
    JSR ENEMY_FIRE_EVENT_RUNTIME
; VPy_LINE:672
; NATIVE_CALL: GET_ENEMY_STATE at line 672
    LDD >VAR_ARG0
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    CLRA
    LDB 13,X            ; sm_state byte
    STD RESULT
    STD VAR_NEW_STATE
; VPy_LINE:673
    LDD #180  ; const THAW_TICKS_SNOW
    STD VAR_TICKS
; VPy_LINE:674
    LDD >VAR_NEW_STATE
    CMPD #3
    LBNE IF_NEXT_204
; VPy_LINE:675
    LDD #300  ; const THAW_TICKS_BALL
    STD VAR_TICKS
    LBRA IF_END_203
IF_NEXT_204:
IF_END_203:
; VPy_LINE:676
    LDD >VAR_ARG0
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_THAW_TIMERS_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD >VAR_TICKS
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    RTS

; Function: update_thaw (Bank #0)
update_thaw:
; VPy_LINE:679
    LDD #0
    STD VAR_I
; VPy_LINE:680
WH_205: ; while start
    LDD #8
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    CMPD TMPVAL
    LBLT .CMP_60_TRUE
    LDD #0
    LBRA .CMP_60_END
.CMP_60_TRUE:
    LDD #1
.CMP_60_END:
    LBEQ WH_END_206
; VPy_LINE:681
; NATIVE_CALL: GET_ENEMY_STATE at line 681
    LDD >VAR_I
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    CLRA
    LDB 13,X            ; sm_state byte
    STD RESULT
    STD VAR_ST
; VPy_LINE:682
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ST
    CMPD TMPVAL
    LBGT .CMP_61_TRUE
    LDD #0
    LBRA .CMP_61_END
.CMP_61_TRUE:
    LDD #1
.CMP_61_END:
    LBEQ IF_NEXT_208
; VPy_LINE:683
    LDD #4
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ST
    CMPD TMPVAL
    LBLT .CMP_62_TRUE
    LDD #0
    LBRA .CMP_62_END
.CMP_62_TRUE:
    LDD #1
.CMP_62_END:
    LBEQ IF_NEXT_210
; VPy_LINE:684
    LDX #VAR_BALL_ROLLING_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #0
    LBNE IF_NEXT_212
; VPy_LINE:685
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_THAW_TIMERS_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_THAW_TIMERS_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    SUBD TMPVAL         ; D = LEFT - RIGHT
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:686
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_THAW_TIMERS_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBLE .CMP_63_TRUE
    LDD #0
    LBRA .CMP_63_END
.CMP_63_TRUE:
    LDD #1
.CMP_63_END:
    LBEQ IF_NEXT_214
; VPy_LINE:687
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ST
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_ST
; VPy_LINE:688
; NATIVE_CALL: SET_ENEMY_STATE at line 688
    LDD >VAR_ST
    STB >TMPVAL         ; stash state_idx
    LDD >VAR_I
    TFR B,A             ; A = enemy index
    LDB >TMPVAL         ; B = state_idx
    JSR SET_ENEMY_STATE_RUNTIME
; VPy_LINE:689
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ST
    CMPD TMPVAL
    LBGT .CMP_64_TRUE
    LDD #0
    LBRA .CMP_64_END
.CMP_64_TRUE:
    LDD #1
.CMP_64_END:
    LBEQ IF_NEXT_216
; VPy_LINE:690
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_THAW_TIMERS_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #180  ; const THAW_TICKS_SNOW
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LBRA IF_END_215
IF_NEXT_216:
IF_END_215:
    LBRA IF_END_213
IF_NEXT_214:
IF_END_213:
    LBRA IF_END_211
IF_NEXT_212:
IF_END_211:
    LBRA IF_END_209
IF_NEXT_210:
IF_END_209:
    LBRA IF_END_207
IF_NEXT_208:
IF_END_207:
; VPy_LINE:691
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_I
    LBRA WH_205
WH_END_206: ; while end
    RTS

; Function: count_active_enemies (Bank #0)
count_active_enemies:
; VPy_LINE:695
    LDD #0
    STD VAR_N
; VPy_LINE:696
    LDD #0
    STD VAR_I
; VPy_LINE:697
WH_217: ; while start
    LDD #8
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    CMPD TMPVAL
    LBLT .CMP_65_TRUE
    LDD #0
    LBRA .CMP_65_END
.CMP_65_TRUE:
    LDD #1
.CMP_65_END:
    LBEQ WH_END_218
; VPy_LINE:698
    LDD >VAR_I
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    CLRA
    LDB ,X              ; active byte
    STD RESULT
    CMPD #1
    LBNE IF_NEXT_220
; VPy_LINE:699
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_N
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_N
    LBRA IF_END_219
IF_NEXT_220:
IF_END_219:
; VPy_LINE:700
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_I
    LBRA WH_217
WH_END_218: ; while end
; VPy_LINE:701
    LDD >VAR_N
    STD VAR_ENEMY_COUNT
    RTS

; Function: kill_offscreen_enemies (Bank #0)
kill_offscreen_enemies:
; VPy_LINE:705
    LDD #0
    STD VAR_I
; VPy_LINE:706
    LDD #128
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_CAMERA_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_SCREEN_MIN
; VPy_LINE:707
    LDD #128
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_CAMERA_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_SCREEN_MAX
; VPy_LINE:708
WH_221: ; while start
    LDD #8
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    CMPD TMPVAL
    LBLT .CMP_66_TRUE
    LDD #0
    LBRA .CMP_66_END
.CMP_66_TRUE:
    LDD #1
.CMP_66_END:
    LBEQ WH_END_222
; VPy_LINE:709
    LDD >VAR_I
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    CLRA
    LDB ,X              ; active byte
    STD RESULT
    CMPD #1
    LBNE IF_NEXT_224
; VPy_LINE:710
; NATIVE_CALL: GET_ENEMY_Y at line 710
    LDD >VAR_I
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    LDA 3,X             ; y hi
    LDB 4,X             ; y lo
    STD RESULT
    STD VAR_EY
; VPy_LINE:711
    LDD >VAR_SCREEN_MIN
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_EY
    CMPD TMPVAL
    LBLT .CMP_67_TRUE
    LDD #0
    LBRA .CMP_67_END
.CMP_67_TRUE:
    LDD #1
.CMP_67_END:
    LBEQ IF_NEXT_226
; VPy_LINE:712
; NATIVE_CALL: KILL_ENEMY at line 712
    LDD >VAR_I
    TFR B,A             ; A = enemy index
    JSR KILL_ENEMY_RUNTIME
    LBRA IF_END_225
IF_NEXT_226:
IF_END_225:
; VPy_LINE:713
    LDD >VAR_SCREEN_MAX
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_EY
    CMPD TMPVAL
    LBGT .CMP_68_TRUE
    LDD #0
    LBRA .CMP_68_END
.CMP_68_TRUE:
    LDD #1
.CMP_68_END:
    LBEQ IF_NEXT_228
; VPy_LINE:714
; NATIVE_CALL: KILL_ENEMY at line 714
    LDD >VAR_I
    TFR B,A             ; A = enemy index
    JSR KILL_ENEMY_RUNTIME
    LBRA IF_END_227
IF_NEXT_228:
IF_END_227:
    LBRA IF_END_223
IF_NEXT_224:
IF_END_223:
; VPy_LINE:715
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_I
    LBRA WH_221
WH_END_222: ; while end
    RTS

; Function: reset_balls (Bank #0)
reset_balls:
; VPy_LINE:719
    LDD #0
    STD VAR_I
; VPy_LINE:720
WH_229: ; while start
    LDD #8
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    CMPD TMPVAL
    LBLT .CMP_69_TRUE
    LDD #0
    LBRA .CMP_69_END
.CMP_69_TRUE:
    LDD #1
.CMP_69_END:
    LBEQ WH_END_230
; VPy_LINE:721
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_ROLLING_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:722
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_VX_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:723
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_VY_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:724
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_BOUNCES_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:725
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_COLLIDED_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:726
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_I
    LBRA WH_229
WH_END_230: ; while end
    RTS

; Function: try_launch_ball (Bank #0)
try_launch_ball:
; VPy_LINE:730
    LDD #0
    STD VAR_I
; VPy_LINE:731
    LDD #0
    STD VAR_FOUND
; VPy_LINE:732
WH_231: ; while start
    LDD #8
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    CMPD TMPVAL
    LBLT .CMP_70_TRUE
    LDD #0
    LBRA .CMP_70_END
.CMP_70_TRUE:
    LDD #1
.CMP_70_END:
    LBEQ WH_END_232
; VPy_LINE:733
    LDD >VAR_FOUND
    CMPD #0
    LBNE IF_NEXT_234
; VPy_LINE:734
    LDD >VAR_I
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    CLRA
    LDB ,X              ; active byte
    STD RESULT
    CMPD #1
    LBNE IF_NEXT_236
; VPy_LINE:735
    LDD >VAR_I
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    CLRA
    LDB 13,X            ; sm_state byte
    STD RESULT
    CMPD #3
    LBNE IF_NEXT_238
; VPy_LINE:736
    LDX #VAR_BALL_ROLLING_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #0
    LBNE IF_NEXT_240
; VPy_LINE:737
; NATIVE_CALL: GET_ENEMY_X at line 737
    LDD >VAR_I
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    LDA 1,X             ; x hi
    LDB 2,X             ; x lo
    STD RESULT
    STD VAR_EX
; VPy_LINE:738
; NATIVE_CALL: GET_ENEMY_Y at line 738
    LDD >VAR_I
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    LDA 3,X             ; y hi
    LDB 4,X             ; y lo
    STD RESULT
    STD VAR_EY
; VPy_LINE:739
    LDD >VAR_EX
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:740
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DX
    CMPD TMPVAL
    LBLT .CMP_71_TRUE
    LDD #0
    LBRA .CMP_71_END
.CMP_71_TRUE:
    LDD #1
.CMP_71_END:
    LBEQ IF_NEXT_242
; VPy_LINE:741
    LDD >VAR_DX
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD VAR_DX
    LBRA IF_END_241
IF_NEXT_242:
IF_END_241:
; VPy_LINE:742
    LDD >VAR_EY
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:743
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DY
    CMPD TMPVAL
    LBLT .CMP_72_TRUE
    LDD #0
    LBRA .CMP_72_END
.CMP_72_TRUE:
    LDD #1
.CMP_72_END:
    LBEQ IF_NEXT_244
; VPy_LINE:744
    LDD >VAR_DY
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD VAR_DY
    LBRA IF_END_243
IF_NEXT_244:
IF_END_243:
; VPy_LINE:745
    LDD #25
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DX
    CMPD TMPVAL
    LBLT .CMP_73_TRUE
    LDD #0
    LBRA .CMP_73_END
.CMP_73_TRUE:
    LDD #1
.CMP_73_END:
    LBEQ IF_NEXT_246
; VPy_LINE:746
    LDD #25
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DY
    CMPD TMPVAL
    LBLT .CMP_74_TRUE
    LDD #0
    LBRA .CMP_74_END
.CMP_74_TRUE:
    LDD #1
.CMP_74_END:
    LBEQ IF_NEXT_248
; VPy_LINE:747
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_ROLLING_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #1
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:748
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_VX_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #4  ; const BALL_SPEED
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:749
    LDD >VAR_PLAYER_FACING
    CMPD #1
    LBNE IF_NEXT_250
; VPy_LINE:750
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_VX_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #4  ; const BALL_SPEED
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LBRA IF_END_249
IF_NEXT_250:
IF_END_249:
; VPy_LINE:751
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_VY_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:752
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_BOUNCES_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    ; RAND_RANGE: Random in range [min, max]
    LDD #3
    STD TMPPTR     ; Save min
    LDD #5
    STD TMPPTR2    ; Save max
    JSR RAND_RANGE_HELPER
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:753
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_THAW_TIMERS_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:754
    LDD #15  ; const SHOOT_COOLDOWN_MAX
    STD VAR_SHOOT_COOLDOWN
; VPy_LINE:755
    LDD #1
    STD VAR_BALL_LAUNCHED
; VPy_LINE:756
    LDD #1
    STD VAR_FOUND
    LBRA IF_END_247
IF_NEXT_248:
IF_END_247:
    LBRA IF_END_245
IF_NEXT_246:
IF_END_245:
    LBRA IF_END_239
IF_NEXT_240:
IF_END_239:
    LBRA IF_END_237
IF_NEXT_238:
IF_END_237:
    LBRA IF_END_235
IF_NEXT_236:
IF_END_235:
    LBRA IF_END_233
IF_NEXT_234:
IF_END_233:
; VPy_LINE:757
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_I
    LBRA WH_231
WH_END_232: ; while end
    RTS

; Function: update_balls (Bank #0)
update_balls:
; VPy_LINE:761
    LDD #0
    STD VAR_I
; VPy_LINE:762
WH_251: ; while start
    LDD #8
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    CMPD TMPVAL
    LBLT .CMP_75_TRUE
    LDD #0
    LBRA .CMP_75_END
.CMP_75_TRUE:
    LDD #1
.CMP_75_END:
    LBEQ WH_END_252
; VPy_LINE:763
    LDX #VAR_BALL_ROLLING_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #1
    LBNE IF_NEXT_254
; VPy_LINE:765
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_VY_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_BALL_VY_ARR_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD #1  ; const BALL_GRAVITY
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    SUBD TMPVAL         ; D = LEFT - RIGHT
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:766
    LDD #8  ; const BALL_MAX_FALL
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_BALL_VY_ARR_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBLT .CMP_76_TRUE
    LDD #0
    LBRA .CMP_76_END
.CMP_76_TRUE:
    LDD #1
.CMP_76_END:
    LBEQ IF_NEXT_256
; VPy_LINE:767
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_VY_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #8  ; const BALL_MAX_FALL
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LBRA IF_END_255
IF_NEXT_256:
IF_END_255:
; VPy_LINE:769
; NATIVE_CALL: GET_ENEMY_Y at line 769
    LDD >VAR_I
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    LDA 3,X             ; y hi
    LDB 4,X             ; y lo
    STD RESULT
    STD VAR_PREV_BY
; VPy_LINE:770
    LDD >VAR_I
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    LDA 1,X             ; x hi
    LDB 2,X             ; x lo
    STD RESULT
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDX #VAR_BALL_VX_ARR_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_BX
; VPy_LINE:771
    LDX #VAR_BALL_VY_ARR_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PREV_BY
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_BY
; VPy_LINE:774
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_BALL_VY_ARR_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBLT .CMP_77_TRUE
    LDD #0
    LBRA .CMP_77_END
.CMP_77_TRUE:
    LDD #1
.CMP_77_END:
    LBEQ IF_NEXT_258
; VPy_LINE:775
; NATIVE_CALL: LEVEL_COLLISION_Y at line 775
    ; ===== LEVEL_COLLISION_Y builtin =====
    LDD >VAR_BX
    STD >LCOL_PX         ; store player world_x (16-bit)
    LDD #8  ; const ENEMY_HH
    STB >LCOL_PHH        ; store player half_height
    LDD >VAR_PREV_BY
    ; Compute player_feet = player_y - player_hh (16-bit)
    STD >TMPVAL          ; save player_y
    LDB >LCOL_PHH        ; B = player_hh
    CLRA
    STD >LCOL_PY         ; reuse as scratch (16-bit hh)
    LDD >TMPVAL          ; D = player_y
    SUBD >LCOL_PY        ; D = player_y - player_hh = player_feet
    STD >LCOL_PY         ; store player_feet Y (16-bit) for surface filter
    JSR LEVEL_COLLISION_Y_RUNTIME
    STD VAR_FLOOR
; VPy_LINE:776
    LDD #127
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_CAMERA_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_SCREEN_BOTTOM
; VPy_LINE:777
    LDD >VAR_SCREEN_BOTTOM
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLOOR
    CMPD TMPVAL
    LBLT .CMP_78_TRUE
    LDD #0
    LBRA .CMP_78_END
.CMP_78_TRUE:
    LDD #1
.CMP_78_END:
    LBEQ IF_NEXT_260
; VPy_LINE:778
    LDD #86
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_CAMERA_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_FLOOR
    LBRA IF_END_259
IF_NEXT_260:
IF_END_259:
; VPy_LINE:779
    LDD >VAR_FLOOR
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BY
    CMPD TMPVAL
    LBLE .CMP_79_TRUE
    LDD #0
    LBRA .CMP_79_END
.CMP_79_TRUE:
    LDD #1
.CMP_79_END:
    LBEQ IF_NEXT_262
; VPy_LINE:780
    LDD >VAR_FLOOR
    STD VAR_BY
; VPy_LINE:781
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_VY_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LBRA IF_END_261
IF_NEXT_262:
IF_END_261:
    LBRA IF_END_257
IF_NEXT_258:
IF_END_257:
; VPy_LINE:783
    LDD #-2403  ; const WORLD_Y_MIN
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BY
    CMPD TMPVAL
    LBLT .CMP_80_TRUE
    LDD #0
    LBRA .CMP_80_END
.CMP_80_TRUE:
    LDD #1
.CMP_80_END:
    LBEQ IF_NEXT_264
; VPy_LINE:784
    LDD #-2403  ; const WORLD_Y_MIN
    STD VAR_BY
; VPy_LINE:785
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_VY_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LBRA IF_END_263
IF_NEXT_264:
IF_END_263:
; VPy_LINE:787
    LDD #-96  ; const WORLD_X_MIN
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BX
    CMPD TMPVAL
    LBLT .CMP_81_TRUE
    LDD #0
    LBRA .CMP_81_END
.CMP_81_TRUE:
    LDD #1
.CMP_81_END:
    LBEQ IF_NEXT_266
; VPy_LINE:788
    LDD #-96  ; const WORLD_X_MIN
    STD VAR_BX
; VPy_LINE:789
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_VX_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #4  ; const BALL_SPEED
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:790
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_BOUNCES_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_BALL_BOUNCES_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    SUBD TMPVAL         ; D = LEFT - RIGHT
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LBRA IF_END_265
IF_NEXT_266:
IF_END_265:
; VPy_LINE:791
    LDD #95  ; const WORLD_X_MAX
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BX
    CMPD TMPVAL
    LBGT .CMP_82_TRUE
    LDD #0
    LBRA .CMP_82_END
.CMP_82_TRUE:
    LDD #1
.CMP_82_END:
    LBEQ IF_NEXT_268
; VPy_LINE:792
    LDD #95  ; const WORLD_X_MAX
    STD VAR_BX
; VPy_LINE:793
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_VX_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #4  ; const BALL_SPEED
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:794
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_BOUNCES_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_BALL_BOUNCES_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    SUBD TMPVAL         ; D = LEFT - RIGHT
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LBRA IF_END_267
IF_NEXT_268:
IF_END_267:
; VPy_LINE:795
; NATIVE_CALL: LEVEL_COLLISION_X at line 795
    ; ===== LEVEL_COLLISION_X builtin =====
    LDD >VAR_BX
    STD >LCOL_PX         ; store player world_x (16-bit)
    LDD #6  ; const ENEMY_HW
    STB >LCOL_PHW        ; store player half_width
    LDD #8  ; const ENEMY_HH
    STB >LCOL_PHH        ; store player half_height for Y-overlap check
    LDD >VAR_BY
    STD >LCOL_PY         ; store player_y (16-bit)
    JSR LEVEL_COLLISION_X_RUNTIME
    STD VAR_PUSH_DX
; VPy_LINE:796
    LDD >VAR_PUSH_DX
    CMPD #0
    LBEQ IF_NEXT_270
; VPy_LINE:797
    LDD >VAR_PUSH_DX
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_BX
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_BX
; VPy_LINE:798
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_VX_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_BALL_VX_ARR_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LBRA IF_END_269
IF_NEXT_270:
IF_END_269:
; VPy_LINE:799
; NATIVE_CALL: SET_ENEMY_X at line 799
    LDD >VAR_I
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    STX >TMPPTR         ; save pool entry ptr across value eval
    LDD >VAR_BX
    LDX >TMPPTR         ; restore pool entry ptr
    STD 1,X             ; x hi @+1, x lo @+2
; VPy_LINE:800
; NATIVE_CALL: SET_ENEMY_Y at line 800
    LDD >VAR_I
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    STX >TMPPTR         ; save pool entry ptr across value eval
    LDD >VAR_BY
    LDX >TMPPTR         ; restore pool entry ptr
    STD 3,X             ; y hi @+3, y lo @+4
; VPy_LINE:802
    LDD >VAR_BX
    STD VAR_ARG0
    LDD >VAR_BY
    STD VAR_ARG1
    JSR ball_kill_enemies
; VPy_LINE:804
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_BALL_BOUNCES_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBLE .CMP_83_TRUE
    LDD #0
    LBRA .CMP_83_END
.CMP_83_TRUE:
    LDD #1
.CMP_83_END:
    LBEQ IF_NEXT_272
; VPy_LINE:805
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_ROLLING_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:806
; NATIVE_CALL: KILL_ENEMY at line 806
    LDD >VAR_I
    TFR B,A             ; A = enemy index
    JSR KILL_ENEMY_RUNTIME
    LBRA IF_END_271
IF_NEXT_272:
IF_END_271:
    LBRA IF_END_253
IF_NEXT_254:
IF_END_253:
; VPy_LINE:807
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_I
    LBRA WH_251
WH_END_252: ; while end
    RTS

; Function: ball_ball_collision (Bank #0)
ball_ball_collision:
; VPy_LINE:813
    LDD #0
    STD VAR_K
; VPy_LINE:814
WH_273: ; while start
    LDD #8
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_K
    CMPD TMPVAL
    LBLT .CMP_84_TRUE
    LDD #0
    LBRA .CMP_84_END
.CMP_84_TRUE:
    LDD #1
.CMP_84_END:
    LBEQ WH_END_274
; VPy_LINE:815
    LDD >VAR_K
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_COLLIDED_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:816
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_K
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_K
    LBRA WH_273
WH_END_274: ; while end
; VPy_LINE:817
    LDD #0
    STD VAR_I
; VPy_LINE:818
WH_275: ; while start
    LDD #8
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    CMPD TMPVAL
    LBLT .CMP_85_TRUE
    LDD #0
    LBRA .CMP_85_END
.CMP_85_TRUE:
    LDD #1
.CMP_85_END:
    LBEQ WH_END_276
; VPy_LINE:819
    LDX #VAR_BALL_ROLLING_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #1
    LBNE IF_NEXT_278
; VPy_LINE:820
    LDX #VAR_BALL_COLLIDED_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #0
    LBNE IF_NEXT_280
; VPy_LINE:821
; NATIVE_CALL: GET_ENEMY_X at line 821
    LDD >VAR_I
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    LDA 1,X             ; x hi
    LDB 2,X             ; x lo
    STD RESULT
    STD VAR_BX
; VPy_LINE:822
; NATIVE_CALL: GET_ENEMY_Y at line 822
    LDD >VAR_I
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    LDA 3,X             ; y hi
    LDB 4,X             ; y lo
    STD RESULT
    STD VAR_BY
; VPy_LINE:823
    LDD #0
    STD VAR_J
; VPy_LINE:824
WH_281: ; while start
    LDD #8
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_J
    CMPD TMPVAL
    LBLT .CMP_86_TRUE
    LDD #0
    LBRA .CMP_86_END
.CMP_86_TRUE:
    LDD #1
.CMP_86_END:
    LBEQ WH_END_282
; VPy_LINE:825
    LDD #0
    STD VAR_SKIP
; VPy_LINE:826
    LDD >VAR_J
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    CMPD TMPVAL
    LBEQ .CMP_87_TRUE
    LDD #0
    LBRA .CMP_87_END
.CMP_87_TRUE:
    LDD #1
.CMP_87_END:
    LBEQ IF_NEXT_284
; VPy_LINE:827
    LDD #1
    STD VAR_SKIP
    LBRA IF_END_283
IF_NEXT_284:
IF_END_283:
; VPy_LINE:828
    LDD >VAR_SKIP
    CMPD #0
    LBNE IF_NEXT_286
; VPy_LINE:829
    LDX #VAR_BALL_COLLIDED_DATA  ; Array base
    LDD >VAR_J
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #0
    LBNE IF_NEXT_288
; VPy_LINE:830
    LDD >VAR_J
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    CLRA
    LDB ,X              ; active byte
    STD RESULT
    CMPD #1
    LBNE IF_NEXT_290
; VPy_LINE:831
    LDD >VAR_J
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    CLRA
    LDB 13,X            ; sm_state byte
    STD RESULT
    CMPD #3
    LBNE IF_NEXT_292
; VPy_LINE:832
; NATIVE_CALL: GET_ENEMY_X at line 832
    LDD >VAR_J
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    LDA 1,X             ; x hi
    LDB 2,X             ; x lo
    STD RESULT
    STD VAR_EJX
; VPy_LINE:833
; NATIVE_CALL: GET_ENEMY_Y at line 833
    LDD >VAR_J
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    LDA 3,X             ; y hi
    LDB 4,X             ; y lo
    STD RESULT
    STD VAR_EJY
; VPy_LINE:834
    LDD >VAR_EJX
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_BX
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:835
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DX
    CMPD TMPVAL
    LBLT .CMP_88_TRUE
    LDD #0
    LBRA .CMP_88_END
.CMP_88_TRUE:
    LDD #1
.CMP_88_END:
    LBEQ IF_NEXT_294
; VPy_LINE:836
    LDD >VAR_DX
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD VAR_DX
    LBRA IF_END_293
IF_NEXT_294:
IF_END_293:
; VPy_LINE:837
    LDD >VAR_EJY
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_BY
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:838
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DY
    CMPD TMPVAL
    LBLT .CMP_89_TRUE
    LDD #0
    LBRA .CMP_89_END
.CMP_89_TRUE:
    LDD #1
.CMP_89_END:
    LBEQ IF_NEXT_296
; VPy_LINE:839
    LDD >VAR_DY
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD VAR_DY
    LBRA IF_END_295
IF_NEXT_296:
IF_END_295:
; VPy_LINE:840
    LDD #20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DX
    CMPD TMPVAL
    LBLT .CMP_90_TRUE
    LDD #0
    LBRA .CMP_90_END
.CMP_90_TRUE:
    LDD #1
.CMP_90_END:
    LBEQ IF_NEXT_298
; VPy_LINE:841
    LDD #20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DY
    CMPD TMPVAL
    LBLT .CMP_91_TRUE
    LDD #0
    LBRA .CMP_91_END
.CMP_91_TRUE:
    LDD #1
.CMP_91_END:
    LBEQ IF_NEXT_300
; VPy_LINE:842
    LDX #VAR_BALL_VX_ARR_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_OLD_VX
; VPy_LINE:843
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_VX_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD >VAR_OLD_VX
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:844
    LDD >VAR_J
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_VX_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD >VAR_OLD_VX
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:845
    LDD >VAR_J
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_ROLLING_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #1
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:846
    LDD >VAR_J
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_THAW_TIMERS_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:847
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_BALL_BOUNCES_DATA  ; Array base
    LDD >VAR_J
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBLE .CMP_92_TRUE
    LDD #0
    LBRA .CMP_92_END
.CMP_92_TRUE:
    LDD #1
.CMP_92_END:
    LBEQ IF_NEXT_302
; VPy_LINE:848
    LDD >VAR_J
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_BOUNCES_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    ; RAND_RANGE: Random in range [min, max]
    LDD #3
    STD TMPPTR     ; Save min
    LDD #5
    STD TMPPTR2    ; Save max
    JSR RAND_RANGE_HELPER
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LBRA IF_END_301
IF_NEXT_302:
IF_END_301:
; VPy_LINE:849
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_COLLIDED_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #1
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:850
    LDD >VAR_J
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_BALL_COLLIDED_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #1
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LBRA IF_END_299
IF_NEXT_300:
IF_END_299:
    LBRA IF_END_297
IF_NEXT_298:
IF_END_297:
    LBRA IF_END_291
IF_NEXT_292:
IF_END_291:
    LBRA IF_END_289
IF_NEXT_290:
IF_END_289:
    LBRA IF_END_287
IF_NEXT_288:
IF_END_287:
    LBRA IF_END_285
IF_NEXT_286:
IF_END_285:
; VPy_LINE:851
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_J
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_J
    LBRA WH_281
WH_END_282: ; while end
    LBRA IF_END_279
IF_NEXT_280:
IF_END_279:
    LBRA IF_END_277
IF_NEXT_278:
IF_END_277:
; VPy_LINE:852
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_I
    LBRA WH_275
WH_END_276: ; while end
    RTS

; Function: ball_kill_enemies (Bank #0)
ball_kill_enemies:
; VPy_LINE:856
    LDD #0
    STD VAR_J
; VPy_LINE:857
WH_303: ; while start
    LDD #8
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_J
    CMPD TMPVAL
    LBLT .CMP_93_TRUE
    LDD #0
    LBRA .CMP_93_END
.CMP_93_TRUE:
    LDD #1
.CMP_93_END:
    LBEQ WH_END_304
; VPy_LINE:858
    LDD >VAR_J
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    CLRA
    LDB ,X              ; active byte
    STD RESULT
    CMPD #1
    LBNE IF_NEXT_306
; VPy_LINE:859
; NATIVE_CALL: GET_ENEMY_STATE at line 859
    LDD >VAR_J
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    CLRA
    LDB 13,X            ; sm_state byte
    STD RESULT
    STD VAR_ST
; VPy_LINE:860
    LDD #3  ; const TITCHI_STATE_BALL
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ST
    CMPD TMPVAL
    LBLT .CMP_94_TRUE
    LDD #0
    LBRA .CMP_94_END
.CMP_94_TRUE:
    LDD #1
.CMP_94_END:
    LBEQ IF_NEXT_308
; VPy_LINE:861
; NATIVE_CALL: GET_ENEMY_X at line 861
    LDD >VAR_J
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    LDA 1,X             ; x hi
    LDB 2,X             ; x lo
    STD RESULT
    STD VAR_EJX
; VPy_LINE:862
; NATIVE_CALL: GET_ENEMY_Y at line 862
    LDD >VAR_J
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    LDA 3,X             ; y hi
    LDB 4,X             ; y lo
    STD RESULT
    STD VAR_EJY
; VPy_LINE:863
    LDD >VAR_EJX
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ARG0
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:864
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DX
    CMPD TMPVAL
    LBLT .CMP_95_TRUE
    LDD #0
    LBRA .CMP_95_END
.CMP_95_TRUE:
    LDD #1
.CMP_95_END:
    LBEQ IF_NEXT_310
; VPy_LINE:865
    LDD >VAR_DX
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD VAR_DX
    LBRA IF_END_309
IF_NEXT_310:
IF_END_309:
; VPy_LINE:866
    LDD >VAR_EJY
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ARG1
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:867
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DY
    CMPD TMPVAL
    LBLT .CMP_96_TRUE
    LDD #0
    LBRA .CMP_96_END
.CMP_96_TRUE:
    LDD #1
.CMP_96_END:
    LBEQ IF_NEXT_312
; VPy_LINE:868
    LDD >VAR_DY
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD VAR_DY
    LBRA IF_END_311
IF_NEXT_312:
IF_END_311:
; VPy_LINE:869
    LDD #24
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DX
    CMPD TMPVAL
    LBLT .CMP_97_TRUE
    LDD #0
    LBRA .CMP_97_END
.CMP_97_TRUE:
    LDD #1
.CMP_97_END:
    LBEQ IF_NEXT_314
; VPy_LINE:870
    LDD #24
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DY
    CMPD TMPVAL
    LBLT .CMP_98_TRUE
    LDD #0
    LBRA .CMP_98_END
.CMP_98_TRUE:
    LDD #1
.CMP_98_END:
    LBEQ IF_NEXT_316
; VPy_LINE:871
; NATIVE_CALL: KILL_ENEMY at line 871
    LDD >VAR_J
    TFR B,A             ; A = enemy index
    JSR KILL_ENEMY_RUNTIME
; VPy_LINE:872
    LDD #200
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_SCORE
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_SCORE
    LBRA IF_END_315
IF_NEXT_316:
IF_END_315:
    LBRA IF_END_313
IF_NEXT_314:
IF_END_313:
    LBRA IF_END_307
IF_NEXT_308:
IF_END_307:
    LBRA IF_END_305
IF_NEXT_306:
IF_END_305:
; VPy_LINE:873
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_J
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_J
    LBRA WH_303
WH_END_304: ; while end
    RTS

; Function: check_player_enemy_collision (Bank #0)
check_player_enemy_collision:
; VPy_LINE:877
    LDD #0
    STD VAR_I
; VPy_LINE:878
WH_317: ; while start
    LDD #8
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    CMPD TMPVAL
    LBLT .CMP_99_TRUE
    LDD #0
    LBRA .CMP_99_END
.CMP_99_TRUE:
    LDD #1
.CMP_99_END:
    LBEQ WH_END_318
; VPy_LINE:879
    LDD >VAR_I
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    CLRA
    LDB ,X              ; active byte
    STD RESULT
    CMPD #1
    LBNE IF_NEXT_320
; VPy_LINE:880
; NATIVE_CALL: GET_ENEMY_STATE at line 880
    LDD >VAR_I
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    CLRA
    LDB 13,X            ; sm_state byte
    STD RESULT
    STD VAR_ST
; VPy_LINE:881
; NATIVE_CALL: GET_ENEMY_X at line 881
    LDD >VAR_I
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    LDA 1,X             ; x hi
    LDB 2,X             ; x lo
    STD RESULT
    STD VAR_EX
; VPy_LINE:882
; NATIVE_CALL: GET_ENEMY_Y at line 882
    LDD >VAR_I
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    LDA 3,X             ; y hi
    LDB 4,X             ; y lo
    STD RESULT
    STD VAR_EY
; VPy_LINE:883
    LDD >VAR_EX
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:884
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DX
    CMPD TMPVAL
    LBLT .CMP_100_TRUE
    LDD #0
    LBRA .CMP_100_END
.CMP_100_TRUE:
    LDD #1
.CMP_100_END:
    LBEQ IF_NEXT_322
; VPy_LINE:885
    LDD >VAR_DX
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD VAR_DX
    LBRA IF_END_321
IF_NEXT_322:
IF_END_321:
; VPy_LINE:886
    LDD >VAR_EY
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:887
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DY
    CMPD TMPVAL
    LBLT .CMP_101_TRUE
    LDD #0
    LBRA .CMP_101_END
.CMP_101_TRUE:
    LDD #1
.CMP_101_END:
    LBEQ IF_NEXT_324
; VPy_LINE:888
    LDD >VAR_DY
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD VAR_DY
    LBRA IF_END_323
IF_NEXT_324:
IF_END_323:
; VPy_LINE:889
    LDD #20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DX
    CMPD TMPVAL
    LBLT .CMP_102_TRUE
    LDD #0
    LBRA .CMP_102_END
.CMP_102_TRUE:
    LDD #1
.CMP_102_END:
    LBEQ IF_NEXT_326
; VPy_LINE:890
    LDD #20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DY
    CMPD TMPVAL
    LBLT .CMP_103_TRUE
    LDD #0
    LBRA .CMP_103_END
.CMP_103_TRUE:
    LDD #1
.CMP_103_END:
    LBEQ IF_NEXT_328
; VPy_LINE:891
    LDD >VAR_ST
    CMPD #0
    LBNE IF_NEXT_330
; VPy_LINE:892
    LDD #1  ; const INVINCIBLE
    CMPD #0
    LBNE IF_NEXT_332
; VPy_LINE:893
    JSR on_player_death
    LBRA IF_END_331
IF_NEXT_332:
IF_END_331:
    LBRA IF_END_329
IF_NEXT_330:
IF_END_329:
; VPy_LINE:894
    LDD >VAR_ST
    CMPD #0
    LBEQ IF_NEXT_334
; VPy_LINE:896
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_EX
    CMPD TMPVAL
    LBGE .CMP_104_TRUE
    LDD #0
    LBRA .CMP_104_END
.CMP_104_TRUE:
    LDD #1
.CMP_104_END:
    LBEQ IF_NEXT_336
; VPy_LINE:897
; NATIVE_CALL: SET_ENEMY_X at line 897
    LDD >VAR_I
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    STX >TMPPTR         ; save pool entry ptr across value eval
    LDD #20
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    ADDD TMPVAL         ; D = LEFT + RIGHT
    LDX >TMPPTR         ; restore pool entry ptr
    STD 1,X             ; x hi @+1, x lo @+2
; VPy_LINE:898
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_PLAYER_X
    LBRA IF_END_335
IF_NEXT_336:
IF_END_335:
; VPy_LINE:899
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_EX
    CMPD TMPVAL
    LBLT .CMP_105_TRUE
    LDD #0
    LBRA .CMP_105_END
.CMP_105_TRUE:
    LDD #1
.CMP_105_END:
    LBEQ IF_NEXT_338
; VPy_LINE:900
; NATIVE_CALL: SET_ENEMY_X at line 900
    LDD >VAR_I
    TFR B,A             ; A = enemy index (low byte)
    LDB #28             ; ENEMY_POOL_STRIDE
    MUL                 ; D = A * stride
    LDX #ENEMY_POOL
    LEAX D,X            ; X = &pool[i]
    STX >TMPPTR         ; save pool entry ptr across value eval
    LDD #20
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    LDX >TMPPTR         ; restore pool entry ptr
    STD 1,X             ; x hi @+1, x lo @+2
; VPy_LINE:901
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_PLAYER_X
    LBRA IF_END_337
IF_NEXT_338:
IF_END_337:
    LBRA IF_END_333
IF_NEXT_334:
IF_END_333:
    LBRA IF_END_327
IF_NEXT_328:
IF_END_327:
    LBRA IF_END_325
IF_NEXT_326:
IF_END_325:
    LBRA IF_END_319
IF_NEXT_320:
IF_END_319:
; VPy_LINE:902
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_I
    LBRA WH_317
WH_END_318: ; while end
    RTS

; Function: reset_frog_fire (Bank #0)
reset_frog_fire:
; VPy_LINE:906
    LDD #0
    STD VAR_I
; VPy_LINE:907
    LDD #0
    STD VAR_FROG_BULLET_ACTIVE
; VPy_LINE:908
WH_339: ; while start
    LDD #8
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    CMPD TMPVAL
    LBLT .CMP_106_TRUE
    LDD #0
    LBRA .CMP_106_END
.CMP_106_TRUE:
    LDD #1
.CMP_106_END:
    LBEQ WH_END_340
; VPy_LINE:909
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_FROG_FIRE_TIMER_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #120  ; const FROG_FIRE_INTERVAL
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:910
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_FROG_FIRE_DECAY_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:911
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_I
    LBRA WH_339
WH_END_340: ; while end
    RTS

; Function: draw_frog_bullet (Bank #0)
draw_frog_bullet:
; VPy_LINE:1011
    LDD >VAR_FROG_BULLET_ACTIVE
    CMPD #1
    LBNE IF_NEXT_406
; VPy_LINE:1012
; NATIVE_CALL: SET_INTENSITY at line 1012
    ; SET_INTENSITY: Set drawing intensity
    LDD #110
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1013
    LDD >VAR_CAMERA_Y
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FROG_BULLET_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_SCR_Y
; VPy_LINE:1014
    LDD >VAR_FROG_BULLET_DIR
    CMPD #0
    LBNE IF_NEXT_408
; VPy_LINE:1015
; NATIVE_CALL: DRAW_VECTOR at line 1015
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: frog_fireball_side (index=3, 2 paths)
    LDD >VAR_FROG_BULLET_X
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_10          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_SCR_Y
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    LDD >VAR_FROG_BULLET_MIRROR
    TFR B,A
    STA MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #3        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_10:
    LDD #0
    STD RESULT
    LBRA IF_END_407
IF_NEXT_408:
IF_END_407:
; VPy_LINE:1016
    LDD >VAR_FROG_BULLET_DIR
    CMPD #1
    LBNE IF_NEXT_410
; VPy_LINE:1017
; NATIVE_CALL: DRAW_VECTOR at line 1017
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: frog_fireball_down (index=2, 2 paths)
    LDD >VAR_FROG_BULLET_X
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_11          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_SCR_Y
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    LDD #0
    TFR B,A
    STA MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #2        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_11:
    LDD #0
    STD RESULT
    LBRA IF_END_409
IF_NEXT_410:
IF_END_409:
    LBRA IF_END_405
IF_NEXT_406:
IF_END_405:
    RTS


; ================================================
