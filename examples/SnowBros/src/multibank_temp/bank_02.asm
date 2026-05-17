
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

;***************************************************************************
; ASSETS IN BANK #2 (3 assets)
;***************************************************************************

; Generated from Henshoku.vmus (internal name: Imported MIDI)
; Tempo: 120 BPM, Total events: 604 (PSG Direct format)
; Format: FCB count, FCB reg, val, ... (per frame), FCB 0 (end)

_HENSHOKU_MUSIC:
    ; Frame-based PSG register writes
    FCB     0              ; Delay 0 frames (maintain previous state)
    FCB     10              ; Frame 0 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     8              ; Frame 4 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 5 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     8              ; Frame 9 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 10 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 11 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 15 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 16 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 20 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 22 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     6              ; Frame 27 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 28 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 32 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 33 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 37 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 39 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 43 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 44 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $21             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 48 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 51 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $21             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 55 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 56 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $04             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 60 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 62 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 66 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 67 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 71 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 72 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     6              ; Frame 77 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 79 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 81 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $EE             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3A             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     4              ; Frame 83 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 84 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 88 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 90 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 94 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 95 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     6              ; Frame 100 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     4              ; Frame 101 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 102 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 106 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     8              ; Frame 107 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 111 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 113 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 117 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 118 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 122 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     8              ; Frame 123 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $04             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 128 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 130 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 134 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 135 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $21             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 139 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 141 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $21             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 145 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 146 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $B1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $04             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 151 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 153 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 157 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 158 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     8              ; Frame 162 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 163 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     8              ; Frame 167 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     4              ; Frame 168 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 169 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 173 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     6              ; Frame 175 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $B9             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 179 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 181 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 185 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 186 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 190 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     4              ; Frame 191 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 192 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 196 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 197 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
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
    FCB     10              ; Frame 204 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 208 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 209 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 213 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     8              ; Frame 214 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $04             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 218 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 220 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 224 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 226 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $21             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 230 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 232 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $21             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 236 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     8              ; Frame 237 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $B1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $04             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $44             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $05             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 241 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 243 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 247 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 248 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 253 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 254 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 258 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 260 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 264 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 265 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 269 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 271 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     8              ; Frame 276 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 277 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     8              ; Frame 281 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 282 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 283 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 287 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 288 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 292 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 294 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 298 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 300 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 304 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 305 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 309 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 311 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 315 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 316 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $21             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 320 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 322 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $21             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     6              ; Frame 327 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     8              ; Frame 328 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $B1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $04             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 332 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 334 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 338 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 339 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     11              ; Delay 11 frames (maintain previous state)
    FCB     6              ; Frame 350 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 351 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 353 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $EE             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3A             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
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
    FCB     6              ; Frame 356 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $B9             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 360 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 362 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     8              ; Frame 366 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 367 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     8              ; Frame 371 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 372 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 373 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     6              ; Frame 378 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 379 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 383 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 385 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 389 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 390 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 394 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 395 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     6              ; Frame 400 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 402 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 406 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 407 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $21             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 411 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 413 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $21             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 417 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 418 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $04             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 422 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 424 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     6              ; Frame 429 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 430 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 434 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 435 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 439 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 441 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 443 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $EE             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3A             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     4              ; Frame 445 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 446 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 451 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 453 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 457 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 458 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 462 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     4              ; Frame 463 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 464 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 468 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     8              ; Frame 469 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 473 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 476 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 480 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 481 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 485 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     8              ; Frame 486 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $04             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 490 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 492 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 496 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 497 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $21             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 502 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 504 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $21             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 508 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 509 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $B1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $04             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 513 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 515 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 519 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 520 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     8              ; Frame 525 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 526 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     8              ; Frame 530 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     4              ; Frame 531 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 532 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 536 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 537 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $B9             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 541 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 543 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 547 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 548 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     6              ; Frame 553 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     4              ; Frame 554 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 555 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 559 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 560 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 564 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 566 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 570 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 571 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 576 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     8              ; Frame 577 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $04             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 581 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 583 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 587 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     8              ; Frame 588 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $21             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 592 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 594 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $21             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 598 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 600 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $B1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $04             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $44             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $05             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 604 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 606 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 610 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 611 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 615 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 616 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 620 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 622 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 627 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 628 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 632 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 634 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     8              ; Frame 638 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 639 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     8              ; Frame 643 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 644 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 645 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     6              ; Frame 650 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 651 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 655 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 657 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 661 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 662 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 666 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 667 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 671 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 673 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     6              ; Frame 678 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 679 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $21             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 683 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 685 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $21             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 689 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     8              ; Frame 690 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $B1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $04             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 694 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 696 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     6              ; Frame 701 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 702 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     6              ; Frame 712 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 713 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 715 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $EE             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3A             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     4              ; Frame 717 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 718 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $B9             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 722 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 725 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $17             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     8              ; Frame 729 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $17             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 730 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $17             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     8              ; Frame 734 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $17             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 735 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 736 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 740 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 741 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 745 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 747 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     6              ; Frame 752 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 753 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 757 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 758 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 762 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 764 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 768 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 769 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     8              ; Frame 773 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 776 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 780 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 781 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 785 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 787 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 791 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 792 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 796 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 797 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     6              ; Frame 802 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 804 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 806 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3A             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     4              ; Frame 808 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 809 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 813 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 815 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $21             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 819 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 820 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $21             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 824 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 827 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 831 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 832 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $51             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 836 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 838 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 842 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 843 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 847 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     8              ; Frame 848 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $51             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $04             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 853 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 855 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 859 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 860 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $21             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
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
    FCB     $21             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 870 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 871 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 876 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 878 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $51             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 882 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 883 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 887 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 888 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 892 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 894 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $51             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $04             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 898 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 899 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 904 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 906 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $17             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 910 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $17             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 911 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $17             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 915 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $17             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     4              ; Frame 916 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 917 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 921 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 922 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $51             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 927 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 929 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 933 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 934 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 938 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     8              ; Frame 939 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $51             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $04             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 943 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 945 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 949 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 951 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 955 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 957 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 961 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 962 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 966 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 968 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 972 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 973 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 978 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 979 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 983 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 985 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $04             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 989 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 990 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 994 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 996 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     6              ; Frame 1001 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1002 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1006 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1008 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1012 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1013 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1017 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1019 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1023 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1025 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1029 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1030 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1034 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1036 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1040 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1041 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1045 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1047 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     6              ; Frame 1052 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1053 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1057 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1059 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1063 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1064 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1068 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1069 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1073 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 1076 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 1078 - 8 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $39             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     4              ; Frame 1080 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1081 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1085 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1087 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $17             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     8              ; Frame 1091 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $17             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1092 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $17             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     8              ; Frame 1096 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $17             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     6              ; Frame 1097 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1098 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     6              ; Frame 1103 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1104 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1108 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1110 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1114 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1115 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1119 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1120 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     6              ; Frame 1125 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1127 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1131 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1132 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     8              ; Frame 1136 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1138 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1142 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1143 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1147 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 1150 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1154 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1155 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1159 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1160 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1164 - 6 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3D             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1166 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 1168 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3A             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
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
    FCB     10              ; Frame 1171 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1176 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1178 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $21             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1182 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1183 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $21             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1187 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1189 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1193 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1194 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $51             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1198 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 1201 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1205 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1206 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1210 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     8              ; Frame 1211 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $51             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $04             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1215 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1217 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1221 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1222 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $21             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1227 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1229 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $21             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1233 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1234 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1238 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1240 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $51             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1244 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1245 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1250 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1251 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1255 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 1257 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $51             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $03             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $04             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1261 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1262 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B2             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1266 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1268 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $17             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1272 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $17             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1273 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $17             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     6              ; Frame 1278 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $17             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     4              ; Frame 1279 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1280 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1284 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1285 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $51             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1289 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1291 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1295 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1296 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1301 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     8              ; Frame 1302 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $51             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $04             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1306 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1308 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1312 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1313 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1317 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1319 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1323 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1325 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1329 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1331 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1335 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1336 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1340 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1341 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1345 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1347 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $04             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     4              ; Frame 1352 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1353 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1357 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1359 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1363 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1364 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1368 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1370 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
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
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     6              ; Frame 1375 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1376 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1380 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1382 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1386 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1387 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1391 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1392 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1396 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1398 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
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
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     6              ; Frame 1403 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1404 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1408 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1410 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1414 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1415 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1419 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1421 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     6              ; Frame 1426 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1427 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1431 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1432 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
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
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     6              ; Frame 1436 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3E             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 1438 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 1440 - 8 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $39             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     4              ; Frame 1442 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1443 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B9             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     4              ; Frame 1447 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 1450 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     8              ; Frame 1454 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     1              ; Delay 1 frames (maintain previous state)
    FCB     10              ; Frame 1455 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $21             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $03             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     8              ; Frame 1459 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $36             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $02             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $7C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     32              ; Delay 32 frames before loop
    FCB     $FF             ; Loop command ($FF never valid as count)
    FDB     _HENSHOKU_MUSIC       ; Jump to start (absolute address)


; Generated from platform1.vec (Malban Draw_Sync_List format)
; Total paths: 3, points: 11
; X bounds: min=-24, max=23, width=47
; Center: (0, 0)

_PLATFORM1_WIDTH EQU 47
_PLATFORM1_HALF_WIDTH EQU 23
_PLATFORM1_HEIGHT EQU 9
_PLATFORM1_HALF_HEIGHT EQU 4
_PLATFORM1_CENTER_X EQU 0
_PLATFORM1_CENTER_Y EQU 0

_PLATFORM1_VECTORS:  ; Main entry (header + 3 path(s))
    FDB 3               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLATFORM1_PATH0        ; pointer to path 0
    FDB _PLATFORM1_PATH1        ; pointer to path 1
    FDB _PLATFORM1_PATH2        ; pointer to path 2

_PLATFORM1_PATH0:    ; Path 0
    FCB 85              ; path0: intensity
    FCB $FB,$16,0,0        ; path0: header (y=-5, x=22)
    FCB $FF,$09,$F5          ; flag=-1, dy=9, dx=-11
    FCB $FF,$F7,$F5          ; flag=-1, dy=-9, dx=-11
    FCB $FF,$09,$F4          ; flag=-1, dy=9, dx=-12
    FCB $FF,$F7,$F5          ; flag=-1, dy=-9, dx=-11
    FCB 2                ; End marker (path complete)

_PLATFORM1_PATH1:    ; Path 1
    FCB 85              ; path1: intensity
    FCB $04,$E8,0,0        ; path1: header (y=4, x=-24)
    FCB $FF,$00,$2F          ; flag=-1, dy=0, dx=47
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB $FF,$00,$D1          ; flag=-1, dy=0, dx=-47
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB 2                ; End marker (path complete)

_PLATFORM1_PATH2:    ; Path 2
    FCB 85              ; path2: intensity
    FCB $FF,$17,0,0        ; path2: header (y=-1, x=23)
    FCB 2                ; End marker (path complete)

; Generated from platform3.vec (Malban Draw_Sync_List format)
; Total paths: 3, points: 11
; X bounds: min=-41, max=40, width=81
; Center: (0, 0)

_PLATFORM3_WIDTH EQU 81
_PLATFORM3_HALF_WIDTH EQU 40
_PLATFORM3_HEIGHT EQU 9
_PLATFORM3_HALF_HEIGHT EQU 4
_PLATFORM3_CENTER_X EQU 0
_PLATFORM3_CENTER_Y EQU 0

_PLATFORM3_VECTORS:  ; Main entry (header + 3 path(s))
    FDB 3               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLATFORM3_PATH0        ; pointer to path 0
    FDB _PLATFORM3_PATH1        ; pointer to path 1
    FDB _PLATFORM3_PATH2        ; pointer to path 2

_PLATFORM3_PATH0:    ; Path 0
    FCB 85              ; path0: intensity
    FCB $00,$28,0,0        ; path0: header (y=0, x=40)
    FCB 2                ; End marker (path complete)

_PLATFORM3_PATH1:    ; Path 1
    FCB 85              ; path1: intensity
    FCB $FB,$28,0,0        ; path1: header (y=-5, x=40)
    FCB $FF,$09,$EC          ; flag=-1, dy=9, dx=-20
    FCB $FF,$F7,$EC          ; flag=-1, dy=-9, dx=-20
    FCB $FF,$09,$EC          ; flag=-1, dy=9, dx=-20
    FCB $FF,$F7,$EB          ; flag=-1, dy=-9, dx=-21
    FCB 2                ; End marker (path complete)

_PLATFORM3_PATH2:    ; Path 2
    FCB 85              ; path2: intensity
    FCB $04,$D7,0,0        ; path2: header (y=4, x=-41)
    FCB $FF,$00,$51          ; flag=-1, dy=0, dx=81
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB $FF,$00,$AF          ; flag=-1, dy=0, dx=-81
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB 2                ; End marker (path complete)


; ================================================
