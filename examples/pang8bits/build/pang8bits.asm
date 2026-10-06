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
    FCC "PANG8BIT"
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
RAND_SEED            EQU $C880+$0E   ; Random seed for RAND() (2 bytes)
DRAW_VEC_INTENSITY   EQU $C880+$10   ; Vector intensity override (0=use vector data) (1 bytes)
DRAW_VEC_X_HI        EQU $C880+$11   ; Vector draw X high byte (16-bit screen_x) (1 bytes)
DRAW_VEC_X           EQU $C880+$12   ; Vector draw X offset (1 bytes)
DRAW_VEC_Y           EQU $C880+$13   ; Vector draw Y offset (1 bytes)
MIRROR_PAD           EQU $C880+$14   ; Safety padding to prevent MIRROR flag corruption (16 bytes)
MIRROR_X             EQU $C880+$24   ; X mirror flag (0=normal, 1=flip) (1 bytes)
MIRROR_Y             EQU $C880+$25   ; Y mirror flag (0=normal, 1=flip) (1 bytes)
SLR_CUR_X            EQU $C880+$6A   ; DRAW_VECTOR: clamped (visible) beam X for clipping (1 bytes)
SLR_TRUE_X           EQU $C880+$6B   ; DRAW_VECTOR: 16-bit unclamped abs_x for line clipping (2 bytes)
DRAW_T1_SCALED       EQU $C880+$6D   ; DRAW_VECTOR: T1 scale ($7F default for non-SHOW_LEVEL) (1 bytes)
SDCP_ABS_Y           EQU $C880+$6E   ; DRAW_VECTOR: abs_y temporary for SDCP (cannot share TMPVAL — would corrupt SHOW_LEVEL's top_screen between layers) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$2B   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$35   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$37   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$39   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$3A   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$3B   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$3D   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
LEVEL_PTR            EQU $C880+$3F   ; Pointer to currently loaded level header (2 bytes)
LEVEL_LOADED         EQU $C880+$41   ; Level loaded flag (0=not loaded, 1=loaded) (1 bytes)
LEVEL_WIDTH          EQU $C880+$42   ; Level width (legacy tile API) (1 bytes)
LEVEL_HEIGHT         EQU $C880+$43   ; Level height (legacy tile API) (1 bytes)
LEVEL_TILE_SIZE      EQU $C880+$44   ; Tile size (legacy tile API) (1 bytes)
LEVEL_Y_IDX          EQU $C880+$45   ; SHOW_LEVEL row counter (legacy) (1 bytes)
LEVEL_X_IDX          EQU $C880+$46   ; SHOW_LEVEL column counter (legacy) (1 bytes)
LEVEL_TEMP           EQU $C880+$47   ; SHOW_LEVEL temporary byte (legacy) (1 bytes)
LEVEL_BG_COUNT       EQU $C880+$48   ; BG object count (1 bytes)
LEVEL_GP_COUNT       EQU $C880+$49   ; GP object count (1 bytes)
LEVEL_FG_COUNT       EQU $C880+$4A   ; FG object count (1 bytes)
CAMERA_X             EQU $C880+$4B   ; Camera X scroll offset (16-bit signed world units) (2 bytes)
CAMERA_Y             EQU $C880+$4D   ; Camera Y scroll offset (16-bit signed world units) (2 bytes)
SCROLL_LIMIT_LEFT    EQU $C880+$4F   ; Camera scroll limit: left world X (2 bytes)
SCROLL_LIMIT_RIGHT   EQU $C880+$51   ; Camera scroll limit: right world X (2 bytes)
SCROLL_LIMIT_TOP     EQU $C880+$53   ; Camera scroll limit: top world Y (2 bytes)
SCROLL_LIMIT_BOTTOM  EQU $C880+$55   ; Camera scroll limit: bottom world Y (2 bytes)
LEVEL_BG_ROM_PTR     EQU $C880+$57   ; BG layer ROM pointer (2 bytes)
LEVEL_GP_ROM_PTR     EQU $C880+$59   ; GP layer ROM pointer (2 bytes)
LEVEL_FG_ROM_PTR     EQU $C880+$5B   ; FG layer ROM pointer (2 bytes)
LEVEL_GP_PTR         EQU $C880+$5D   ; GP active pointer (RAM buffer after LOAD_LEVEL) (2 bytes)
LEVEL_BANK           EQU $C880+$5F   ; Bank ID for current level (for multibank) (1 bytes)
LEVEL_ENEMY_COUNT    EQU $C880+$60   ; Enemy count from current level header (1 bytes)
LEVEL_ENEMY_INSTANCES_PTR EQU $C880+$61   ; Ptr to enemy instances table in level bank (2 bytes)
LEVEL_SCREEN_COUNT   EQU $C880+$63   ; Total Y screens partitioning the level (1 bytes)
LEVEL_BG_SCREENS_PTR EQU $C880+$64   ; Per-screen BG index ptr (3 bytes per screen) (2 bytes)
LEVEL_GP_SCREENS_PTR EQU $C880+$66   ; Per-screen GP index ptr (2 bytes)
LEVEL_FG_SCREENS_PTR EQU $C880+$68   ; Per-screen FG index ptr (2 bytes)
SLR_CUR_X            EQU $C880+$6A   ; SHOW_LEVEL: clamped (visible) beam X — actually written to integrator (1 bytes)
SLR_TRUE_X           EQU $C880+$6B   ; SHOW_LEVEL: 16-bit unclamped abs_x for per-segment line clipping (2 bytes)
DRAW_T1_SCALED       EQU $C880+$6D   ; SHOW_LEVEL: effective T1 for current object (DRAW_SCALE * object_scale) (1 bytes)
SDCP_ABS_Y           EQU $C880+$6E   ; SHOW_LEVEL: abs_y temporary for SDCP (cannot share TMPVAL — would corrupt top_screen between layers) (1 bytes)
SLR_TOP_SCREEN       EQU $C880+$6F   ; SHOW_LEVEL: top Y screen idx (lives across all 3 layers — must not be in TMPVAL) (1 bytes)
SLR_BOT_SCREEN       EQU $C880+$70   ; SHOW_LEVEL: bot Y screen idx (lives across all 3 layers) (1 bytes)
LCOL_PX              EQU $C880+$71   ; LEVEL_COLLISION player world_x input (16-bit) (2 bytes)
LCOL_BEST_Y          EQU $C880+$73   ; LEVEL_COLLISION_Y best floor y found (16-bit signed) (2 bytes)
LCOL_PY              EQU $C880+$75   ; LEVEL_COLLISION player_top (16-bit signed) (2 bytes)
LCOL_PHH             EQU $C880+$77   ; LEVEL_COLLISION player half_height (1 bytes)
LCOL_PHW             EQU $C880+$78   ; LEVEL_COLLISION_X player half_width (1 bytes)
LCOL_THW             EQU $C880+$79   ; LEVEL_COLLISION_X total half_width (player_hw + obj_hw scratch) (1 bytes)
LCOL_OBJ_Y           EQU $C880+$7A   ; LEVEL_COLLISION_Y current object world_y (16-bit) (2 bytes)
LCOL_LOCAL_PX        EQU $C880+$7C   ; LEVEL_COLLISION_Y player_x in object-local coords (16-bit) (2 bytes)
LCOL_OBJ_CNT         EQU $C880+$7E   ; LEVEL_COLLISION_Y GP objects remaining (1 bytes)
LCOL_SEG_CNT         EQU $C880+$7F   ; LEVEL_COLLISION_Y mesh floor segments remaining (1 bytes)
ENEMY_POOL           EQU $C880+$80   ; Enemy instances pool (Phase 2 wander: +18 sub_state, +19 cur_area_idx, +20 idle_timer, +21 trans_type, +22..23 target_x, +24..25 vy/from_x, +26 feet_offset × N) (224 bytes)
ENEMY_LOOP_IDX       EQU $C880+$160   ; Enemy loop counter (1 bytes)
ENEMY_COUNT          EQU $C880+$161   ; Active enemy count (1 bytes)
ENEMY_SCRATCH_PTR    EQU $C880+$162   ; Scratch pointer for enemy iteration (2 bytes)
ENEMY_SCRATCH_X      EQU $C880+$164   ; Enemy scratch X (2 bytes)
ENEMY_SCRATCH_Y      EQU $C880+$166   ; Enemy scratch Y (2 bytes)
TEXT_SCALE_H         EQU $C880+$168   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$169   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
DRAW_ANIM_MIRROR_X   EQU $C880+$16A   ; DRAW_ANIM mirror X flag (0=normal, 1=flip) (1 bytes)
DRAW_ANIM_SCALE      EQU $C880+$16B   ; DRAW_ANIM T1 scale ($7F=normal) (1 bytes)
DRAW_ANIM_SPEED_MUL  EQU $C880+$16C   ; DRAW_ANIM tick multiplier (1=normal) (1 bytes)
DRAW_SCALE           EQU $C880+$16D   ; Current T1 scale for Draw_Sync_List_At_With_Mirrors ($7F=normal) (1 bytes)
VAR_ARG0             EQU $C880+$16E   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $C880+$170   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $C880+$172   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $C880+$174   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $C880+$176   ; Function argument 4 (16-bit) (2 bytes)
VAR_ARG5             EQU $C880+$178   ; Function argument 5 (16-bit) (2 bytes)
VAR_ARG6             EQU $C880+$17A   ; Function argument 6 (16-bit) (2 bytes)
VAR_ARG7             EQU $C880+$17C   ; Function argument 7 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $C880+$17E   ; Current ROM bank ID (multibank tracking) (1 bytes)
VAR_SCREEN           EQU $C880+$17F   ; User variable: SCREEN (1 bytes)
VAR_TITLE_INTENSITY  EQU $C880+$180   ; User variable: TITLE_INTENSITY (1 bytes)
VAR_TITLE_STATE      EQU $C880+$181   ; User variable: TITLE_STATE (1 bytes)
VAR_CURRENT_MUSIC    EQU $C880+$182   ; User variable: CURRENT_MUSIC (1 bytes)
VAR_LOCATION_X_COORDS EQU $C880+$183   ; User variable: LOCATION_X_COORDS (2 bytes)
VAR_LOCATION_Y_COORDS EQU $C880+$185   ; User variable: LOCATION_Y_COORDS (2 bytes)
VAR_LOCATION_NAMES   EQU $C880+$187   ; User variable: LOCATION_NAMES (2 bytes)
VAR_LEVEL_BACKGROUNDS EQU $C880+$189   ; User variable: LEVEL_BACKGROUNDS (2 bytes)
VAR_LEVEL_ENEMY_COUNT EQU $C880+$18B   ; User variable: LEVEL_ENEMY_COUNT (2 bytes)
VAR_LEVEL_ENEMY_SPEED EQU $C880+$18D   ; User variable: LEVEL_ENEMY_SPEED (2 bytes)
VAR_CURRENT_LOCATION EQU $C880+$18F   ; User variable: CURRENT_LOCATION (1 bytes)
VAR_LOCATION_GLOW_INTENSITY EQU $C880+$190   ; User variable: LOCATION_GLOW_INTENSITY (1 bytes)
VAR_LOCATION_GLOW_DIRECTION EQU $C880+$191   ; User variable: LOCATION_GLOW_DIRECTION (1 bytes)
VAR_JOY_X            EQU $C880+$192   ; User variable: JOY_X (2 bytes)
VAR_JOY_Y            EQU $C880+$194   ; User variable: JOY_Y (2 bytes)
VAR_PREV_JOY_X       EQU $C880+$196   ; User variable: PREV_JOY_X (2 bytes)
VAR_PREV_JOY_Y       EQU $C880+$198   ; User variable: PREV_JOY_Y (2 bytes)
VAR_COUNTDOWN_TIMER  EQU $C880+$19A   ; User variable: COUNTDOWN_TIMER (1 bytes)
VAR_COUNTDOWN_ACTIVE EQU $C880+$19B   ; User variable: COUNTDOWN_ACTIVE (1 bytes)
VAR_JOYSTICK_POLL_COUNTER EQU $C880+$19C   ; User variable: JOYSTICK_POLL_COUNTER (1 bytes)
VAR_HOOK_ACTIVE      EQU $C880+$19D   ; User variable: HOOK_ACTIVE (1 bytes)
VAR_HOOK_X           EQU $C880+$19E   ; User variable: HOOK_X (2 bytes)
VAR_HOOK_Y           EQU $C880+$1A0   ; User variable: HOOK_Y (2 bytes)
VAR_HOOK_GUN_X       EQU $C880+$1A2   ; User variable: HOOK_GUN_X (2 bytes)
VAR_HOOK_GUN_Y       EQU $C880+$1A4   ; User variable: HOOK_GUN_Y (2 bytes)
VAR_HOOK_INIT_Y      EQU $C880+$1A6   ; User variable: HOOK_INIT_Y (2 bytes)
VAR_PLAYER_X         EQU $C880+$1A8   ; User variable: PLAYER_X (2 bytes)
VAR_MOVE_SPEED       EQU $C880+$1AA   ; User variable: MOVE_SPEED (1 bytes)
VAR_ABS_JOY          EQU $C880+$1AB   ; User variable: ABS_JOY (1 bytes)
VAR_PLAYER_ANIM_FRAME EQU $C880+$1AC   ; User variable: PLAYER_ANIM_FRAME (1 bytes)
VAR_PLAYER_ANIM_COUNTER EQU $C880+$1AD   ; User variable: PLAYER_ANIM_COUNTER (1 bytes)
VAR_PLAYER_FACING    EQU $C880+$1AE   ; User variable: PLAYER_FACING (1 bytes)
VAR_JOYSTICK1_STATE  EQU $C880+$1AF   ; User variable: JOYSTICK1_STATE (2 bytes)
VAR_LOC_X            EQU $C880+$1B1   ; User variable: LOC_X (2 bytes)
VAR_LOC_Y            EQU $C880+$1B3   ; User variable: LOC_Y (2 bytes)
VAR_ANIM_THRESHOLD   EQU $C880+$1B5   ; User variable: ANIM_THRESHOLD (2 bytes)
VAR_MIRROR_MODE      EQU $C880+$1B7   ; User variable: MIRROR_MODE (2 bytes)
VAR_ACTIVE_COUNT     EQU $C880+$1B9   ; User variable: ACTIVE_COUNT (2 bytes)
VAR_I                EQU $C880+$1BB   ; User variable: I (2 bytes)
VAR_ENEMY_ACTIVE     EQU $C880+$1BD   ; User variable: ENEMY_ACTIVE (2 bytes)
VAR_COUNT            EQU $C880+$1BF   ; User variable: COUNT (2 bytes)
VAR_SPEED            EQU $C880+$1C1   ; User variable: SPEED (2 bytes)
VAR_ENEMY_SIZE       EQU $C880+$1C3   ; User variable: ENEMY_SIZE (2 bytes)
VAR_ENEMY_X          EQU $C880+$1C5   ; User variable: ENEMY_X (2 bytes)
VAR_ENEMY_Y          EQU $C880+$1C7   ; User variable: ENEMY_Y (2 bytes)
VAR_ENEMY_VX         EQU $C880+$1C9   ; User variable: ENEMY_VX (2 bytes)
VAR_ENEMY_VY         EQU $C880+$1CB   ; User variable: ENEMY_VY (2 bytes)
VAR_START_X          EQU $C880+$1CD   ; User variable: start_x (2 bytes)
VAR_START_Y          EQU $C880+$1CF   ; User variable: start_y (2 bytes)
VAR_END_X            EQU $C880+$1D1   ; User variable: end_x (2 bytes)
VAR_END_Y            EQU $C880+$1D3   ; User variable: end_y (2 bytes)
VAR_JOYSTICK1_STATE_DATA EQU $C880+$1D5   ; Mutable array 'JOYSTICK1_STATE' data (6 elements x 1 bytes) (6 bytes)
VAR_ENEMY_ACTIVE_DATA EQU $C880+$1DB   ; Mutable array 'ENEMY_ACTIVE' data (8 elements x 1 bytes) (8 bytes)
VAR_ENEMY_X_DATA     EQU $C880+$1E3   ; Mutable array 'ENEMY_X' data (8 elements x 2 bytes) (16 bytes)
VAR_ENEMY_Y_DATA     EQU $C880+$1F3   ; Mutable array 'ENEMY_Y' data (8 elements x 2 bytes) (16 bytes)
VAR_ENEMY_VX_DATA    EQU $C880+$203   ; Mutable array 'ENEMY_VX' data (8 elements x 2 bytes) (16 bytes)
VAR_ENEMY_VY_DATA    EQU $C880+$213   ; Mutable array 'ENEMY_VY' data (8 elements x 2 bytes) (16 bytes)
VAR_ENEMY_SIZE_DATA  EQU $C880+$223   ; Mutable array 'ENEMY_SIZE' data (8 elements x 1 bytes) (8 bytes)
PSG_MUSIC_PTR        EQU $C880+$22B   ; PSG music data pointer (2 bytes)
PSG_MUSIC_START      EQU $C880+$22D   ; PSG music start pointer (for loops) (2 bytes)
PSG_MUSIC_ACTIVE     EQU $C880+$22F   ; PSG music active flag (1 bytes)
PSG_IS_PLAYING       EQU $C880+$230   ; PSG playing flag (1 bytes)
PSG_DELAY_FRAMES     EQU $C880+$231   ; PSG frame delay counter (1 bytes)
PSG_MUSIC_BANK       EQU $C880+$232   ; PSG music bank ID (for multibank) (1 bytes)
SFX_PTR              EQU $C880+$233   ; SFX data pointer (2 bytes)
SFX_ACTIVE           EQU $C880+$235   ; SFX active flag (1 bytes)
SFX_BANK             EQU $C880+$236   ; SFX bank ID (for multibank) (1 bytes)
; Array length constants
ARRAY_LOCATION_X_COORDS_LEN         EQU 17   ; 17 elements
ARRAY_LOCATION_Y_COORDS_LEN         EQU 17   ; 17 elements
ARRAY_LOCATION_NAMES_LEN         EQU 17   ; 17 elements
ARRAY_LEVEL_BACKGROUNDS_LEN         EQU 17   ; 17 elements
ARRAY_LEVEL_ENEMY_COUNT_LEN         EQU 17   ; 17 elements
ARRAY_LEVEL_ENEMY_SPEED_LEN         EQU 17   ; 17 elements
ARRAY_JOYSTICK1_STATE_LEN         EQU 6   ; 6 elements
ARRAY_ENEMY_ACTIVE_LEN         EQU 8   ; 8 elements
ARRAY_ENEMY_X_LEN         EQU 8   ; 8 elements
ARRAY_ENEMY_Y_LEN         EQU 8   ; 8 elements
ARRAY_ENEMY_VX_LEN         EQU 8   ; 8 elements
ARRAY_ENEMY_VY_LEN         EQU 8   ; 8 elements
ARRAY_ENEMY_SIZE_LEN         EQU 8   ; 8 elements

;***************************************************************************
; ARRAY DATA (ROM literals)
;***************************************************************************
; Arrays are stored in ROM and accessed via pointers
; At startup, main() initializes VAR_{name} to point to ARRAY_{name}_DATA

; Array literal for variable 'LOCATION_X_COORDS' (17 elements, 2 bytes each)
ARRAY_LOCATION_X_COORDS_DATA:
    FDB 40   ; Element 0
    FDB 40   ; Element 1
    FDB -40   ; Element 2
    FDB -10   ; Element 3
    FDB 20   ; Element 4
    FDB 50   ; Element 5
    FDB 80   ; Element 6
    FDB -85   ; Element 7
    FDB -50   ; Element 8
    FDB -15   ; Element 9
    FDB 15   ; Element 10
    FDB 50   ; Element 11
    FDB 85   ; Element 12
    FDB -90   ; Element 13
    FDB -45   ; Element 14
    FDB 0   ; Element 15
    FDB 45   ; Element 16

; Array literal for variable 'LOCATION_Y_COORDS' (17 elements, 2 bytes each)
ARRAY_LOCATION_Y_COORDS_DATA:
    FDB 110   ; Element 0
    FDB 79   ; Element 1
    FDB -20   ; Element 2
    FDB 10   ; Element 3
    FDB 40   ; Element 4
    FDB 70   ; Element 5
    FDB 100   ; Element 6
    FDB -40   ; Element 7
    FDB -10   ; Element 8
    FDB 30   ; Element 9
    FDB 60   ; Element 10
    FDB 90   ; Element 11
    FDB 20   ; Element 12
    FDB 50   ; Element 13
    FDB 0   ; Element 14
    FDB -60   ; Element 15
    FDB -30   ; Element 16

; String array literal for variable 'LOCATION_NAMES' (17 elements)
ARRAY_LOCATION_NAMES_DATA_STR_0:
    FCC "MOUNT FUJI (JP)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_1:
    FCC "MOUNT KEIRIN (CN)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_2:
    FCC "EMERALD BUDDHA TEMPLE (TH)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_3:
    FCC "ANGKOR WAT (KH)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_4:
    FCC "AYERS ROCK (AU)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_5:
    FCC "TAJ MAHAL (IN)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_6:
    FCC "LENINGRAD (RU)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_7:
    FCC "PARIS (FR)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_8:
    FCC "LONDON (UK)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_9:
    FCC "BARCELONA (ES)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_10:
    FCC "ATHENS (GR)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_11:
    FCC "PYRAMIDS (EG)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_12:
    FCC "MOUNT KILIMANJARO (TZ)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_13:
    FCC "NEW YORK (US)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_14:
    FCC "MAYAN RUINS (MX)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_15:
    FCC "ANTARCTICA (AQ)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_16:
    FCC "EASTER ISLAND (CL)"
    FCB $80   ; String terminator (high bit)

ARRAY_LOCATION_NAMES_DATA:  ; Pointer table for LOCATION_NAMES
    FDB ARRAY_LOCATION_NAMES_DATA_STR_0  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_1  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_2  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_3  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_4  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_5  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_6  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_7  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_8  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_9  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_10  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_11  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_12  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_13  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_14  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_15  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_16  ; Pointer to string

; String array literal for variable 'LEVEL_BACKGROUNDS' (17 elements)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_0:
    FCC "FUJI_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_1:
    FCC "KEIRIN_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_2:
    FCC "BUDDHA_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_3:
    FCC "ANGKOR_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_4:
    FCC "AYERS_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_5:
    FCC "TAJ_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_6:
    FCC "LENINGRAD_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_7:
    FCC "PARIS_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_8:
    FCC "LONDON_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_9:
    FCC "BARCELONA_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_10:
    FCC "ATHENS_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_11:
    FCC "PYRAMIDS_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_12:
    FCC "KILIMANJARO_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_13:
    FCC "NEWYORK_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_14:
    FCC "MAYAN_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_15:
    FCC "ANTARCTICA_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_16:
    FCC "EASTER_BG"
    FCB $80   ; String terminator (high bit)

ARRAY_LEVEL_BACKGROUNDS_DATA:  ; Pointer table for LEVEL_BACKGROUNDS
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_0  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_1  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_2  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_3  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_4  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_5  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_6  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_7  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_8  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_9  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_10  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_11  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_12  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_13  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_14  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_15  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_16  ; Pointer to string

; Array literal for variable 'LEVEL_ENEMY_COUNT' (17 elements, 2 bytes each)
ARRAY_LEVEL_ENEMY_COUNT_DATA:
    FDB 1   ; Element 0
    FDB 1   ; Element 1
    FDB 2   ; Element 2
    FDB 2   ; Element 3
    FDB 2   ; Element 4
    FDB 3   ; Element 5
    FDB 3   ; Element 6
    FDB 3   ; Element 7
    FDB 4   ; Element 8
    FDB 4   ; Element 9
    FDB 4   ; Element 10
    FDB 5   ; Element 11
    FDB 5   ; Element 12
    FDB 5   ; Element 13
    FDB 6   ; Element 14
    FDB 6   ; Element 15
    FDB 7   ; Element 16

; Array literal for variable 'LEVEL_ENEMY_SPEED' (17 elements, 2 bytes each)
ARRAY_LEVEL_ENEMY_SPEED_DATA:
    FDB 1   ; Element 0
    FDB 1   ; Element 1
    FDB 1   ; Element 2
    FDB 2   ; Element 3
    FDB 2   ; Element 4
    FDB 2   ; Element 5
    FDB 2   ; Element 6
    FDB 3   ; Element 7
    FDB 3   ; Element 8
    FDB 3   ; Element 9
    FDB 3   ; Element 10
    FDB 4   ; Element 11
    FDB 4   ; Element 12
    FDB 4   ; Element 13
    FDB 4   ; Element 14
    FDB 5   ; Element 15
    FDB 5   ; Element 16

; Array literal for variable 'JOYSTICK1_STATE' (6 elements, 1 bytes each)
ARRAY_JOYSTICK1_STATE_DATA:
    FCB $00   ; Element 0
    FCB $00   ; Element 1
    FCB $00   ; Element 2
    FCB $00   ; Element 3
    FCB $00   ; Element 4
    FCB $00   ; Element 5

; Array literal for variable 'ENEMY_ACTIVE' (8 elements, 1 bytes each)
ARRAY_ENEMY_ACTIVE_DATA:
    FCB $00   ; Element 0
    FCB $00   ; Element 1
    FCB $00   ; Element 2
    FCB $00   ; Element 3
    FCB $00   ; Element 4
    FCB $00   ; Element 5
    FCB $00   ; Element 6
    FCB $00   ; Element 7

; Array literal for variable 'ENEMY_X' (8 elements, 2 bytes each)
ARRAY_ENEMY_X_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'ENEMY_Y' (8 elements, 2 bytes each)
ARRAY_ENEMY_Y_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'ENEMY_VX' (8 elements, 2 bytes each)
ARRAY_ENEMY_VX_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'ENEMY_VY' (8 elements, 2 bytes each)
ARRAY_ENEMY_VY_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'ENEMY_SIZE' (8 elements, 1 bytes each)
ARRAY_ENEMY_SIZE_DATA:
    FCB $00   ; Element 0
    FCB $00   ; Element 1
    FCB $00   ; Element 2
    FCB $00   ; Element 3
    FCB $00   ; Element 4
    FCB $00   ; Element 5
    FCB $00   ; Element 6
    FCB $00   ; Element 7


;***************************************************************************
; MAIN PROGRAM
;***************************************************************************

MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    CLR DRAW_VEC_INTENSITY ; 0 = use recorded/vector intensity (no override)
    ; Init camera ONCE at boot (RAM not zero-init); LOAD_LEVEL must NOT reset it.
    LDD #0
    STD >CAMERA_X
    STD >CAMERA_Y
    LDA #$F8
    STA TEXT_SCALE_H      ; Default height = -8 (normal size)
    LDA #$48
    STA TEXT_SCALE_W      ; Default width = 72 (normal size)
    LDA #$7F
    STA DRAW_SCALE        ; Default T1 scale = $7F (127 = full BIOS scale)
    LDD #0  ; const STATE_TITLE
    STD VAR_SCREEN
    LDD #30
    STD VAR_TITLE_INTENSITY
    LDD #0
    STD VAR_TITLE_STATE
    LDD #-1
    STD VAR_CURRENT_MUSIC
    ; Copy array 'JOYSTICK1_STATE' from ROM to RAM (6 elements)
    LDX #ARRAY_JOYSTICK1_STATE_DATA       ; Source: ROM array data
    LDU #VAR_JOYSTICK1_STATE_DATA       ; Dest: RAM array space
    LDD #6        ; Number of elements
.COPY_LOOP_0:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_0 ; Loop until done (LBNE for long branch)
    LDX #VAR_JOYSTICK1_STATE_DATA    ; Array now in RAM
    STX VAR_JOYSTICK1_STATE
    LDD #0
    STD VAR_CURRENT_LOCATION
    LDD #60
    STD VAR_LOCATION_GLOW_INTENSITY
    LDD #0
    STD VAR_LOCATION_GLOW_DIRECTION
    LDD #0
    STD VAR_JOY_X
    LDD #0
    STD VAR_JOY_Y
    LDD #0
    STD VAR_PREV_JOY_X
    LDD #0
    STD VAR_PREV_JOY_Y
    LDD #0
    STD VAR_COUNTDOWN_TIMER
    LDD #0
    STD VAR_COUNTDOWN_ACTIVE
    LDD #0
    STD VAR_JOYSTICK_POLL_COUNTER
    LDD #0
    STD VAR_HOOK_ACTIVE
    LDD #0
    STD VAR_HOOK_X
    LDD #-70
    STD VAR_HOOK_Y
    LDD #0
    STD VAR_HOOK_GUN_X
    LDD #0
    STD VAR_HOOK_GUN_Y
    LDD #0
    STD VAR_HOOK_INIT_Y
    LDD #0
    STD VAR_PLAYER_X
    LDD #0
    STD VAR_MOVE_SPEED
    LDD #0
    STD VAR_ABS_JOY
    LDD #1
    STD VAR_PLAYER_ANIM_FRAME
    LDD #0
    STD VAR_PLAYER_ANIM_COUNTER
    LDD #1
    STD VAR_PLAYER_FACING
    ; Copy array 'ENEMY_ACTIVE' from ROM to RAM (8 elements)
    LDX #ARRAY_ENEMY_ACTIVE_DATA       ; Source: ROM array data
    LDU #VAR_ENEMY_ACTIVE_DATA       ; Dest: RAM array space
    LDD #8        ; Number of elements
.COPY_LOOP_1:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_1 ; Loop until done (LBNE for long branch)
    LDX #VAR_ENEMY_ACTIVE_DATA    ; Array now in RAM
    STX VAR_ENEMY_ACTIVE
    ; Copy array 'ENEMY_X' from ROM to RAM (8 elements)
    LDX #ARRAY_ENEMY_X_DATA       ; Source: ROM array data
    LDU #VAR_ENEMY_X_DATA       ; Dest: RAM array space
    LDD #8        ; Number of elements
.COPY_LOOP_2:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_2 ; Loop until done (LBNE for long branch)
    LDX #VAR_ENEMY_X_DATA    ; Array now in RAM
    STX VAR_ENEMY_X
    ; Copy array 'ENEMY_Y' from ROM to RAM (8 elements)
    LDX #ARRAY_ENEMY_Y_DATA       ; Source: ROM array data
    LDU #VAR_ENEMY_Y_DATA       ; Dest: RAM array space
    LDD #8        ; Number of elements
.COPY_LOOP_3:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_3 ; Loop until done (LBNE for long branch)
    LDX #VAR_ENEMY_Y_DATA    ; Array now in RAM
    STX VAR_ENEMY_Y
    ; Copy array 'ENEMY_VX' from ROM to RAM (8 elements)
    LDX #ARRAY_ENEMY_VX_DATA       ; Source: ROM array data
    LDU #VAR_ENEMY_VX_DATA       ; Dest: RAM array space
    LDD #8        ; Number of elements
.COPY_LOOP_4:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_4 ; Loop until done (LBNE for long branch)
    LDX #VAR_ENEMY_VX_DATA    ; Array now in RAM
    STX VAR_ENEMY_VX
    ; Copy array 'ENEMY_VY' from ROM to RAM (8 elements)
    LDX #ARRAY_ENEMY_VY_DATA       ; Source: ROM array data
    LDU #VAR_ENEMY_VY_DATA       ; Dest: RAM array space
    LDD #8        ; Number of elements
.COPY_LOOP_5:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_5 ; Loop until done (LBNE for long branch)
    LDX #VAR_ENEMY_VY_DATA    ; Array now in RAM
    STX VAR_ENEMY_VY
    ; Copy array 'ENEMY_SIZE' from ROM to RAM (8 elements)
    LDX #ARRAY_ENEMY_SIZE_DATA       ; Source: ROM array data
    LDU #VAR_ENEMY_SIZE_DATA       ; Dest: RAM array space
    LDD #8        ; Number of elements
.COPY_LOOP_6:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_6 ; Loop until done (LBNE for long branch)
    LDX #VAR_ENEMY_SIZE_DATA    ; Array now in RAM
    STX VAR_ENEMY_SIZE
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
; VPy_LINE:82
    LDD #0
    STB VAR_CURRENT_LOCATION
; VPy_LINE:83
    LDD #0
    STD VAR_PREV_JOY_X
; VPy_LINE:84
    LDD #0
    STD VAR_PREV_JOY_Y
; VPy_LINE:85
    LDD #80
    STB VAR_LOCATION_GLOW_INTENSITY
; VPy_LINE:86
    LDD #0
    STB VAR_LOCATION_GLOW_DIRECTION
; VPy_LINE:87
    LDD #0  ; const STATE_TITLE
    STB VAR_SCREEN
; VPy_LINE:90
    LDD #0
    STB VAR_COUNTDOWN_TIMER
; VPy_LINE:91
    LDD #0
    STB VAR_COUNTDOWN_ACTIVE
; VPy_LINE:94
    LDD #0
    STB VAR_HOOK_ACTIVE
; VPy_LINE:95
    LDD #0
    STD VAR_HOOK_X
; VPy_LINE:96
    LDD #-70
    STD VAR_HOOK_Y
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
; VPy_LINE:100
    JSR READ_JOYSTICK1_STATE
; VPy_LINE:102
    LDB >VAR_SCREEN
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #0
    LBNE IF_NEXT_1
; VPy_LINE:103
    LDB >VAR_CURRENT_MUSIC
    SEX             ; Sign-extend B -> D
    CMPD #-1
    LBNE IF_NEXT_3
; VPy_LINE:104
; NATIVE_CALL: PLAY_MUSIC at line 104
    ; PLAY_MUSIC("pang_theme") - play music asset (index=1)
    LDX #_PANG_THEME_MUSIC  ; Load music data pointer
    JSR PLAY_MUSIC_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:105
    LDD #0
    STB VAR_CURRENT_MUSIC
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
; VPy_LINE:107
    JSR DRAW_TITLE_SCREEN
; VPy_LINE:109
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    CMPD TMPVAL
    LBEQ .CMP_3_TRUE
    LDD #0
    LBRA .CMP_3_END
.CMP_3_TRUE:
    LDD #1
.CMP_3_END:
    LBNE .LOGIC_2_TRUE
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    CMPD TMPVAL
    LBEQ .CMP_4_TRUE
    LDD #0
    LBRA .CMP_4_END
.CMP_4_TRUE:
    LDD #1
.CMP_4_END:
    LBNE .LOGIC_2_TRUE
    LDD #0
    LBRA .LOGIC_2_END
.LOGIC_2_TRUE:
    LDD #1
.LOGIC_2_END:
    LBNE .LOGIC_1_TRUE
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #4
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    CMPD TMPVAL
    LBEQ .CMP_5_TRUE
    LDD #0
    LBRA .CMP_5_END
.CMP_5_TRUE:
    LDD #1
.CMP_5_END:
    LBNE .LOGIC_1_TRUE
    LDD #0
    LBRA .LOGIC_1_END
.LOGIC_1_TRUE:
    LDD #1
.LOGIC_1_END:
    LBNE .LOGIC_0_TRUE
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #5
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    CMPD TMPVAL
    LBEQ .CMP_6_TRUE
    LDD #0
    LBRA .CMP_6_END
.CMP_6_TRUE:
    LDD #1
.CMP_6_END:
    LBNE .LOGIC_0_TRUE
    LDD #0
    LBRA .LOGIC_0_END
.LOGIC_0_TRUE:
    LDD #1
.LOGIC_0_END:
    LBEQ IF_NEXT_5
; VPy_LINE:110
    LDD #1  ; const STATE_MAP
    STB VAR_SCREEN
; VPy_LINE:111
    LDD #-1
    STB VAR_CURRENT_MUSIC
; VPy_LINE:112
; NATIVE_CALL: PLAY_SFX at line 112
    ; PLAY_SFX("laser") - play SFX asset (index=1)
    LDX #_LASER_SFX  ; Load SFX data pointer
    JSR PLAY_SFX_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    LBRA IF_END_0
IF_NEXT_1:
    LDB >VAR_SCREEN
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #1
    LBNE IF_NEXT_6
; VPy_LINE:115
    LDB >VAR_CURRENT_MUSIC
    SEX             ; Sign-extend B -> D
    CMPD #1
    LBEQ IF_NEXT_8
; VPy_LINE:116
; NATIVE_CALL: PLAY_MUSIC at line 116
    ; PLAY_MUSIC("map_theme") - play music asset (index=0)
    LDX #_MAP_THEME_MUSIC  ; Load music data pointer
    JSR PLAY_MUSIC_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:117
    LDD #1
    STB VAR_CURRENT_MUSIC
    LBRA IF_END_7
IF_NEXT_8:
IF_END_7:
; VPy_LINE:120
    LDD >VAR_JOYSTICK_POLL_COUNTER
    STD TMPVAL          ; Save left operand
    LDD #1
    ADDD TMPVAL         ; D = D + TMPVAL
    STD VAR_JOYSTICK_POLL_COUNTER
; VPy_LINE:121
    LDD #15
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_JOYSTICK_POLL_COUNTER
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBGE .CMP_7_TRUE
    LDD #0
    LBRA .CMP_7_END
.CMP_7_TRUE:
    LDD #1
.CMP_7_END:
    LBEQ IF_NEXT_10
; VPy_LINE:122
    LDD #0
    STB VAR_JOYSTICK_POLL_COUNTER
; VPy_LINE:123
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    STD VAR_JOY_X
; VPy_LINE:124
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    STD VAR_JOY_Y
    LBRA IF_END_9
IF_NEXT_10:
IF_END_9:
; VPy_LINE:128
    LDD #40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBGT .CMP_9_TRUE
    LDD #0
    LBRA .CMP_9_END
.CMP_9_TRUE:
    LDD #1
.CMP_9_END:
    LBEQ .LOGIC_8_FALSE
    LDD #40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_JOY_X
    CMPD TMPVAL
    LBLE .CMP_10_TRUE
    LDD #0
    LBRA .CMP_10_END
.CMP_10_TRUE:
    LDD #1
.CMP_10_END:
    LBEQ .LOGIC_8_FALSE
    LDD #1
    LBRA .LOGIC_8_END
.LOGIC_8_FALSE:
    LDD #0
.LOGIC_8_END:
    LBEQ IF_NEXT_12
; VPy_LINE:129
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STB VAR_CURRENT_LOCATION
; VPy_LINE:130
    LDD #17  ; const NUM_LOCATIONS
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBGE .CMP_11_TRUE
    LDD #0
    LBRA .CMP_11_END
.CMP_11_TRUE:
    LDD #1
.CMP_11_END:
    LBEQ IF_NEXT_14
; VPy_LINE:131
    LDD #0
    STB VAR_CURRENT_LOCATION
; VPy_LINE:132
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'fuji_level1_v2'
    LDX #_FUJI_LEVEL1_V2_LEVEL          ; Pointer to level data in ROM
    JSR LOAD_LEVEL_RUNTIME
    LBRA IF_END_13
IF_NEXT_14:
IF_END_13:
    LBRA IF_END_11
IF_NEXT_12:
    LDD #-40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBLT .CMP_13_TRUE
    LDD #0
    LBRA .CMP_13_END
.CMP_13_TRUE:
    LDD #1
.CMP_13_END:
    LBEQ .LOGIC_12_FALSE
    LDD #-40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_JOY_X
    CMPD TMPVAL
    LBGE .CMP_14_TRUE
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
    LBEQ IF_NEXT_15
; VPy_LINE:134
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STB VAR_CURRENT_LOCATION
; VPy_LINE:135
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBLT .CMP_15_TRUE
    LDD #0
    LBRA .CMP_15_END
.CMP_15_TRUE:
    LDD #1
.CMP_15_END:
    LBEQ IF_NEXT_17
; VPy_LINE:136
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #17  ; const NUM_LOCATIONS
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STB VAR_CURRENT_LOCATION
    LBRA IF_END_16
IF_NEXT_17:
IF_END_16:
    LBRA IF_END_11
IF_NEXT_15:
    LDD #40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_Y
    CMPD TMPVAL
    LBGT .CMP_17_TRUE
    LDD #0
    LBRA .CMP_17_END
.CMP_17_TRUE:
    LDD #1
.CMP_17_END:
    LBEQ .LOGIC_16_FALSE
    LDD #40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_JOY_Y
    CMPD TMPVAL
    LBLE .CMP_18_TRUE
    LDD #0
    LBRA .CMP_18_END
.CMP_18_TRUE:
    LDD #1
.CMP_18_END:
    LBEQ .LOGIC_16_FALSE
    LDD #1
    LBRA .LOGIC_16_END
.LOGIC_16_FALSE:
    LDD #0
.LOGIC_16_END:
    LBEQ IF_NEXT_18
; VPy_LINE:138
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STB VAR_CURRENT_LOCATION
; VPy_LINE:139
    LDD #17  ; const NUM_LOCATIONS
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBGE .CMP_19_TRUE
    LDD #0
    LBRA .CMP_19_END
.CMP_19_TRUE:
    LDD #1
.CMP_19_END:
    LBEQ IF_NEXT_20
; VPy_LINE:140
    LDD #0
    STB VAR_CURRENT_LOCATION
    LBRA IF_END_19
IF_NEXT_20:
IF_END_19:
    LBRA IF_END_11
IF_NEXT_18:
    LDD #-40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_Y
    CMPD TMPVAL
    LBLT .CMP_21_TRUE
    LDD #0
    LBRA .CMP_21_END
.CMP_21_TRUE:
    LDD #1
.CMP_21_END:
    LBEQ .LOGIC_20_FALSE
    LDD #-40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_JOY_Y
    CMPD TMPVAL
    LBGE .CMP_22_TRUE
    LDD #0
    LBRA .CMP_22_END
.CMP_22_TRUE:
    LDD #1
.CMP_22_END:
    LBEQ .LOGIC_20_FALSE
    LDD #1
    LBRA .LOGIC_20_END
.LOGIC_20_FALSE:
    LDD #0
.LOGIC_20_END:
    LBEQ IF_END_11
; VPy_LINE:142
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STB VAR_CURRENT_LOCATION
; VPy_LINE:143
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBLT .CMP_23_TRUE
    LDD #0
    LBRA .CMP_23_END
.CMP_23_TRUE:
    LDD #1
.CMP_23_END:
    LBEQ IF_NEXT_22
; VPy_LINE:144
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #17  ; const NUM_LOCATIONS
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STB VAR_CURRENT_LOCATION
    LBRA IF_END_21
IF_NEXT_22:
IF_END_21:
    LBRA IF_END_11
IF_END_11:
; VPy_LINE:146
    LDD >VAR_JOY_X
    STD VAR_PREV_JOY_X
; VPy_LINE:147
    LDD >VAR_JOY_Y
    STD VAR_PREV_JOY_Y
; VPy_LINE:149
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    CMPD TMPVAL
    LBEQ .CMP_27_TRUE
    LDD #0
    LBRA .CMP_27_END
.CMP_27_TRUE:
    LDD #1
.CMP_27_END:
    LBNE .LOGIC_26_TRUE
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    CMPD TMPVAL
    LBEQ .CMP_28_TRUE
    LDD #0
    LBRA .CMP_28_END
.CMP_28_TRUE:
    LDD #1
.CMP_28_END:
    LBNE .LOGIC_26_TRUE
    LDD #0
    LBRA .LOGIC_26_END
.LOGIC_26_TRUE:
    LDD #1
.LOGIC_26_END:
    LBNE .LOGIC_25_TRUE
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #4
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    CMPD TMPVAL
    LBEQ .CMP_29_TRUE
    LDD #0
    LBRA .CMP_29_END
.CMP_29_TRUE:
    LDD #1
.CMP_29_END:
    LBNE .LOGIC_25_TRUE
    LDD #0
    LBRA .LOGIC_25_END
.LOGIC_25_TRUE:
    LDD #1
.LOGIC_25_END:
    LBNE .LOGIC_24_TRUE
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #5
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    CMPD TMPVAL
    LBEQ .CMP_30_TRUE
    LDD #0
    LBRA .CMP_30_END
.CMP_30_TRUE:
    LDD #1
.CMP_30_END:
    LBNE .LOGIC_24_TRUE
    LDD #0
    LBRA .LOGIC_24_END
.LOGIC_24_TRUE:
    LDD #1
.LOGIC_24_END:
    LBEQ IF_NEXT_24
; VPy_LINE:151
; NATIVE_CALL: PLAY_SFX at line 151
    ; PLAY_SFX("laser") - play SFX asset (index=1)
    LDX #_LASER_SFX  ; Load SFX data pointer
    JSR PLAY_SFX_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:152
    LDD #2  ; const STATE_GAME
    STB VAR_SCREEN
; VPy_LINE:153
    LDD #1
    STB VAR_COUNTDOWN_ACTIVE
; VPy_LINE:154
    LDD #180
    STB VAR_COUNTDOWN_TIMER
    LBRA IF_END_23
IF_NEXT_24:
IF_END_23:
; VPy_LINE:156
    JSR DRAW_MAP_SCREEN
    LBRA IF_END_0
IF_NEXT_6:
    LDB >VAR_SCREEN
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #2
    LBNE IF_END_0
; VPy_LINE:160
    LDB >VAR_COUNTDOWN_ACTIVE
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #1
    LBNE IF_NEXT_26
; VPy_LINE:162
    JSR DRAW_LEVEL_BACKGROUND
; VPy_LINE:164
; NATIVE_CALL: SET_INTENSITY at line 164
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:165
; NATIVE_CALL: PRINT_TEXT at line 165
    ; PRINT_TEXT: Print text at position
    LDD #-50
    STD >VAR_ARG0
    LDD #0
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_62529178322969      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:168
; NATIVE_CALL: SET_INTENSITY at line 168
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:169
; NATIVE_CALL: PRINT_TEXT at line 169
    ; PRINT_TEXT: Print text at position
    LDD #-85
    STD >VAR_ARG0
    LDD #-20
    STD >VAR_ARG1
    LDX #ARRAY_LOCATION_NAMES_DATA  ; Array base
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:172
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDB >VAR_COUNTDOWN_TIMER
    CLRA            ; Zero-extend: A=0, B=value
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STB VAR_COUNTDOWN_TIMER
; VPy_LINE:175
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_COUNTDOWN_TIMER
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBLE .CMP_31_TRUE
    LDD #0
    LBRA .CMP_31_END
.CMP_31_TRUE:
    LDD #1
.CMP_31_END:
    LBEQ IF_NEXT_28
; VPy_LINE:176
    LDD #0
    STB VAR_COUNTDOWN_ACTIVE
; VPy_LINE:177
    ; ERROR: SPAWN_ENEMIES requires 1 argument (level name)
    LBRA IF_END_27
IF_NEXT_28:
IF_END_27:
    LBRA IF_END_25
IF_NEXT_26:
; VPy_LINE:182
    LDB >VAR_HOOK_ACTIVE
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #0
    LBNE IF_NEXT_30
; VPy_LINE:183
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    CMPD TMPVAL
    LBEQ .CMP_35_TRUE
    LDD #0
    LBRA .CMP_35_END
.CMP_35_TRUE:
    LDD #1
.CMP_35_END:
    LBNE .LOGIC_34_TRUE
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    CMPD TMPVAL
    LBEQ .CMP_36_TRUE
    LDD #0
    LBRA .CMP_36_END
.CMP_36_TRUE:
    LDD #1
.CMP_36_END:
    LBNE .LOGIC_34_TRUE
    LDD #0
    LBRA .LOGIC_34_END
.LOGIC_34_TRUE:
    LDD #1
.LOGIC_34_END:
    LBNE .LOGIC_33_TRUE
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #4
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    CMPD TMPVAL
    LBEQ .CMP_37_TRUE
    LDD #0
    LBRA .CMP_37_END
.CMP_37_TRUE:
    LDD #1
.CMP_37_END:
    LBNE .LOGIC_33_TRUE
    LDD #0
    LBRA .LOGIC_33_END
.LOGIC_33_TRUE:
    LDD #1
.LOGIC_33_END:
    LBNE .LOGIC_32_TRUE
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #5
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    CMPD TMPVAL
    LBEQ .CMP_38_TRUE
    LDD #0
    LBRA .CMP_38_END
.CMP_38_TRUE:
    LDD #1
.CMP_38_END:
    LBNE .LOGIC_32_TRUE
    LDD #0
    LBRA .LOGIC_32_END
.LOGIC_32_TRUE:
    LDD #1
.LOGIC_32_END:
    LBEQ IF_NEXT_32
; VPy_LINE:184
    LDD #1
    STB VAR_HOOK_ACTIVE
; VPy_LINE:185
    LDD #-70
    STD VAR_HOOK_Y
; VPy_LINE:186
; NATIVE_CALL: PLAY_SFX at line 186
    ; PLAY_SFX("hit") - play SFX asset (index=0)
    LDX #_HIT_SFX  ; Load SFX data pointer
    JSR PLAY_SFX_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:189
    LDD >VAR_PLAYER_X
    STD VAR_HOOK_GUN_X
; VPy_LINE:190
    LDB >VAR_PLAYER_FACING
    SEX             ; Sign-extend B -> D
    CMPD #1
    LBNE IF_NEXT_34
; VPy_LINE:191
    LDD #11
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_HOOK_GUN_X
    LBRA IF_END_33
IF_NEXT_34:
; VPy_LINE:193
    LDD #11
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_HOOK_GUN_X
IF_END_33:
; VPy_LINE:194
    LDD #3
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-70  ; const PLAYER_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_HOOK_GUN_Y
; VPy_LINE:195
    LDD >VAR_HOOK_GUN_Y
    STD VAR_HOOK_INIT_Y
; VPy_LINE:198
    LDD >VAR_HOOK_GUN_X
    STD VAR_HOOK_X
    LBRA IF_END_31
IF_NEXT_32:
IF_END_31:
    LBRA IF_END_29
IF_NEXT_30:
IF_END_29:
; VPy_LINE:201
    LDB >VAR_HOOK_ACTIVE
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #1
    LBNE IF_NEXT_36
; VPy_LINE:202
    LDD #3
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_HOOK_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_HOOK_Y
; VPy_LINE:205
    LDD #127  ; const HOOK_MAX_Y
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_HOOK_Y
    CMPD TMPVAL
    LBGE .CMP_39_TRUE
    LDD #0
    LBRA .CMP_39_END
.CMP_39_TRUE:
    LDD #1
.CMP_39_END:
    LBEQ IF_NEXT_38
; VPy_LINE:206
    LDD #0
    STB VAR_HOOK_ACTIVE
; VPy_LINE:207
    LDD #-70
    STD VAR_HOOK_Y
    LBRA IF_END_37
IF_NEXT_38:
IF_END_37:
    LBRA IF_END_35
IF_NEXT_36:
IF_END_35:
; VPy_LINE:209
    JSR DRAW_GAME_LEVEL
IF_END_25:
    LBRA IF_END_0
IF_END_0:
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX
    RTS

; Function: DRAW_MAP_SCREEN
DRAW_MAP_SCREEN:
; VPy_LINE:213
; NATIVE_CALL: SET_INTENSITY at line 213
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:214
; NATIVE_CALL: DRAW_VECTOR_EX at line 214
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: map (index=19, 15 paths) with mirror + intensity
    LDD #0
    TFR B,A       ; X position (low byte) — B already holds it
    STA DRAW_VEC_X
    LDD #20
    TFR B,A       ; Y position (low byte) — B already holds it
    STA DRAW_VEC_Y
    LDD #0
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_0_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_0_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_0_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_0_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_0_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_0_CALL:
    ; Set intensity override for drawing
    LDD #50
    TFR B,A       ; Intensity (0-127) — B already holds it
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_MAP_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH7  ; Load path 7
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH8  ; Load path 8
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH9  ; Load path 9
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH10  ; Load path 10
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH11  ; Load path 11
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH12  ; Load path 12
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH13  ; Load path 13
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH14  ; Load path 14
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
; VPy_LINE:217
    LDB >VAR_LOCATION_GLOW_DIRECTION
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #0
    LBNE IF_NEXT_40
; VPy_LINE:218
    LDD #3
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDB >VAR_LOCATION_GLOW_INTENSITY
    CLRA            ; Zero-extend: A=0, B=value
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STB VAR_LOCATION_GLOW_INTENSITY
; VPy_LINE:219
    LDD #127
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_LOCATION_GLOW_INTENSITY
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBGE .CMP_40_TRUE
    LDD #0
    LBRA .CMP_40_END
.CMP_40_TRUE:
    LDD #1
.CMP_40_END:
    LBEQ IF_NEXT_42
; VPy_LINE:220
    LDD #1
    STB VAR_LOCATION_GLOW_DIRECTION
    LBRA IF_END_41
IF_NEXT_42:
IF_END_41:
    LBRA IF_END_39
IF_NEXT_40:
; VPy_LINE:222
    LDD #3
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDB >VAR_LOCATION_GLOW_INTENSITY
    CLRA            ; Zero-extend: A=0, B=value
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STB VAR_LOCATION_GLOW_INTENSITY
; VPy_LINE:223
    LDD #80
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_LOCATION_GLOW_INTENSITY
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBLE .CMP_41_TRUE
    LDD #0
    LBRA .CMP_41_END
.CMP_41_TRUE:
    LDD #1
.CMP_41_END:
    LBEQ IF_NEXT_44
; VPy_LINE:224
    LDD #0
    STB VAR_LOCATION_GLOW_DIRECTION
    LBRA IF_END_43
IF_NEXT_44:
IF_END_43:
IF_END_39:
; VPy_LINE:226
; NATIVE_CALL: PRINT_TEXT at line 226
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD >VAR_ARG0
    LDD #-80
    STD >VAR_ARG1
    LDX #ARRAY_LOCATION_NAMES_DATA  ; Array base
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:229
    LDX #ARRAY_LOCATION_X_COORDS_DATA  ; Array base
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_LOC_X
; VPy_LINE:230
    LDX #ARRAY_LOCATION_Y_COORDS_DATA  ; Array base
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_LOC_Y
; VPy_LINE:232
; NATIVE_CALL: DRAW_VECTOR_EX at line 232
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: location_marker (index=16, 1 paths) with mirror + intensity
    LDD >VAR_LOC_Y
    TFR B,A       ; X position (low byte) — B already holds it
    STA DRAW_VEC_X
    LDD >VAR_LOC_X
    TFR B,A       ; Y position (low byte) — B already holds it
    STA DRAW_VEC_Y
    LDD #0
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_1_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_1_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_1_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_1_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_1_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_1_CALL:
    ; Set intensity override for drawing
    LDB >VAR_LOCATION_GLOW_INTENSITY
    CLRA            ; Zero-extend: A=0, B=value
    TFR B,A       ; Intensity (0-127) — B already holds it
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_LOCATION_MARKER_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    RTS

; Function: DRAW_TITLE_SCREEN
DRAW_TITLE_SCREEN:
; VPy_LINE:237
; NATIVE_CALL: SET_INTENSITY at line 237
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:238
; NATIVE_CALL: DRAW_VECTOR at line 238
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: logo (index=17, 7 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_2          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #70
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
    LDX #_LOGO_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_LOGO_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_LOGO_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_LOGO_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_LOGO_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_LOGO_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_LOGO_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_2:
    LDD #0
    STD RESULT
; VPy_LINE:240
; NATIVE_CALL: SET_INTENSITY at line 240
    ; SET_INTENSITY: Set drawing intensity
    LDB >VAR_TITLE_INTENSITY
    CLRA            ; Zero-extend: A=0, B=value
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:241
; NATIVE_CALL: PRINT_TEXT at line 241
    ; PRINT_TEXT: Print text at position
    LDD #-90
    STD >VAR_ARG0
    LDD #0
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_9120385685437879118      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:242
; NATIVE_CALL: PRINT_TEXT at line 242
    ; PRINT_TEXT: Print text at position
    LDD #-50
    STD >VAR_ARG0
    LDD #-20
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2382167728733      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:244
    LDB >VAR_TITLE_STATE
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #0
    LBNE IF_NEXT_46
; VPy_LINE:245
    LDD >VAR_TITLE_INTENSITY
    STD TMPVAL          ; Save left operand
    LDD #1
    ADDD TMPVAL         ; D = D + TMPVAL
    STD VAR_TITLE_INTENSITY
    LBRA IF_END_45
IF_NEXT_46:
IF_END_45:
; VPy_LINE:247
    LDB >VAR_TITLE_STATE
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #1
    LBNE IF_NEXT_48
; VPy_LINE:248
    LDD >VAR_TITLE_INTENSITY
    STD TMPVAL          ; Save left operand
    LDD #1
    STD TMPPTR          ; Save right operand
    LDD TMPVAL          ; Get left operand
    SUBD TMPPTR         ; D = left - right
    STD VAR_TITLE_INTENSITY
    LBRA IF_END_47
IF_NEXT_48:
IF_END_47:
; VPy_LINE:250
    LDB >VAR_TITLE_INTENSITY
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #80
    LBNE IF_NEXT_50
; VPy_LINE:251
    LDD #1
    STB VAR_TITLE_STATE
    LBRA IF_END_49
IF_NEXT_50:
IF_END_49:
; VPy_LINE:253
    LDB >VAR_TITLE_INTENSITY
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #30
    LBNE IF_NEXT_52
; VPy_LINE:254
    LDD #0
    STB VAR_TITLE_STATE
    LBRA IF_END_51
IF_NEXT_52:
IF_END_51:
    RTS

; Function: DRAW_LEVEL_BACKGROUND
DRAW_LEVEL_BACKGROUND:
; VPy_LINE:258
; NATIVE_CALL: SET_INTENSITY at line 258
    ; SET_INTENSITY: Set drawing intensity
    LDD #60
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:261
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #0
    LBNE IF_NEXT_54
; VPy_LINE:262
; NATIVE_CALL: DRAW_VECTOR at line 262
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: fuji_bg (index=11, 5 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_3          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
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
    LDX #_FUJI_BG_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_FUJI_BG_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_FUJI_BG_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_FUJI_BG_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_FUJI_BG_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_3:
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_54:
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #1
    LBNE IF_NEXT_55
; VPy_LINE:264
; NATIVE_CALL: DRAW_VECTOR at line 264
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: keirin_bg (index=13, 3 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_4          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
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
    LDX #_KEIRIN_BG_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_KEIRIN_BG_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_KEIRIN_BG_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_4:
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_55:
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #2
    LBNE IF_NEXT_56
; VPy_LINE:266
; NATIVE_CALL: DRAW_VECTOR at line 266
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: buddha_bg (index=9, 4 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_5          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
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
    LDX #_BUDDHA_BG_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BUDDHA_BG_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BUDDHA_BG_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BUDDHA_BG_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_5:
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_56:
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #3
    LBNE IF_NEXT_57
; VPy_LINE:268
; NATIVE_CALL: DRAW_VECTOR at line 268
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: angkor_bg (index=0, 170 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_6          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
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
    LDX #_ANGKOR_BG_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH7  ; Load path 7
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH8  ; Load path 8
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH9  ; Load path 9
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH10  ; Load path 10
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH11  ; Load path 11
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH12  ; Load path 12
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH13  ; Load path 13
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH14  ; Load path 14
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH15  ; Load path 15
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH16  ; Load path 16
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH17  ; Load path 17
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH18  ; Load path 18
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH19  ; Load path 19
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH20  ; Load path 20
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH21  ; Load path 21
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH22  ; Load path 22
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH23  ; Load path 23
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH24  ; Load path 24
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH25  ; Load path 25
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH26  ; Load path 26
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH27  ; Load path 27
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH28  ; Load path 28
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH29  ; Load path 29
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH30  ; Load path 30
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH31  ; Load path 31
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH32  ; Load path 32
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH33  ; Load path 33
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH34  ; Load path 34
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH35  ; Load path 35
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH36  ; Load path 36
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH37  ; Load path 37
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH38  ; Load path 38
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH39  ; Load path 39
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH40  ; Load path 40
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH41  ; Load path 41
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH42  ; Load path 42
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH43  ; Load path 43
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH44  ; Load path 44
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH45  ; Load path 45
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH46  ; Load path 46
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH47  ; Load path 47
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH48  ; Load path 48
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH49  ; Load path 49
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH50  ; Load path 50
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH51  ; Load path 51
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH52  ; Load path 52
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH53  ; Load path 53
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH54  ; Load path 54
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH55  ; Load path 55
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH56  ; Load path 56
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH57  ; Load path 57
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH58  ; Load path 58
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH59  ; Load path 59
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH60  ; Load path 60
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH61  ; Load path 61
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH62  ; Load path 62
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH63  ; Load path 63
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH64  ; Load path 64
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH65  ; Load path 65
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH66  ; Load path 66
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH67  ; Load path 67
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH68  ; Load path 68
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH69  ; Load path 69
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH70  ; Load path 70
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH71  ; Load path 71
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH72  ; Load path 72
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH73  ; Load path 73
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH74  ; Load path 74
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH75  ; Load path 75
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH76  ; Load path 76
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH77  ; Load path 77
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH78  ; Load path 78
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH79  ; Load path 79
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH80  ; Load path 80
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH81  ; Load path 81
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH82  ; Load path 82
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH83  ; Load path 83
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH84  ; Load path 84
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH85  ; Load path 85
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH86  ; Load path 86
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH87  ; Load path 87
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH88  ; Load path 88
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH89  ; Load path 89
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH90  ; Load path 90
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH91  ; Load path 91
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH92  ; Load path 92
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH93  ; Load path 93
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH94  ; Load path 94
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH95  ; Load path 95
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH96  ; Load path 96
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH97  ; Load path 97
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH98  ; Load path 98
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH99  ; Load path 99
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH100  ; Load path 100
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH101  ; Load path 101
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH102  ; Load path 102
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH103  ; Load path 103
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH104  ; Load path 104
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH105  ; Load path 105
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH106  ; Load path 106
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH107  ; Load path 107
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH108  ; Load path 108
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH109  ; Load path 109
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH110  ; Load path 110
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH111  ; Load path 111
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH112  ; Load path 112
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH113  ; Load path 113
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH114  ; Load path 114
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH115  ; Load path 115
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH116  ; Load path 116
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH117  ; Load path 117
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH118  ; Load path 118
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH119  ; Load path 119
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH120  ; Load path 120
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH121  ; Load path 121
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH122  ; Load path 122
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH123  ; Load path 123
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH124  ; Load path 124
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH125  ; Load path 125
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH126  ; Load path 126
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH127  ; Load path 127
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH128  ; Load path 128
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH129  ; Load path 129
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH130  ; Load path 130
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH131  ; Load path 131
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH132  ; Load path 132
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH133  ; Load path 133
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH134  ; Load path 134
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH135  ; Load path 135
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH136  ; Load path 136
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH137  ; Load path 137
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH138  ; Load path 138
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH139  ; Load path 139
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH140  ; Load path 140
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH141  ; Load path 141
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH142  ; Load path 142
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH143  ; Load path 143
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH144  ; Load path 144
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH145  ; Load path 145
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH146  ; Load path 146
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH147  ; Load path 147
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH148  ; Load path 148
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH149  ; Load path 149
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH150  ; Load path 150
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH151  ; Load path 151
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH152  ; Load path 152
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH153  ; Load path 153
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH154  ; Load path 154
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH155  ; Load path 155
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH156  ; Load path 156
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH157  ; Load path 157
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH158  ; Load path 158
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH159  ; Load path 159
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH160  ; Load path 160
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH161  ; Load path 161
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH162  ; Load path 162
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH163  ; Load path 163
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH164  ; Load path 164
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH165  ; Load path 165
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH166  ; Load path 166
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH167  ; Load path 167
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH168  ; Load path 168
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH169  ; Load path 169
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_6:
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_57:
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #4
    LBNE IF_NEXT_58
; VPy_LINE:270
; NATIVE_CALL: DRAW_VECTOR at line 270
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: ayers_bg (index=3, 18 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_7          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
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
    LDX #_AYERS_BG_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_AYERS_BG_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_AYERS_BG_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_AYERS_BG_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_AYERS_BG_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_AYERS_BG_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_AYERS_BG_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_AYERS_BG_PATH7  ; Load path 7
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_AYERS_BG_PATH8  ; Load path 8
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_AYERS_BG_PATH9  ; Load path 9
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_AYERS_BG_PATH10  ; Load path 10
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_AYERS_BG_PATH11  ; Load path 11
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_AYERS_BG_PATH12  ; Load path 12
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_AYERS_BG_PATH13  ; Load path 13
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_AYERS_BG_PATH14  ; Load path 14
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_AYERS_BG_PATH15  ; Load path 15
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_AYERS_BG_PATH16  ; Load path 16
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_AYERS_BG_PATH17  ; Load path 17
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_7:
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_58:
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #5
    LBNE IF_NEXT_59
; VPy_LINE:272
; NATIVE_CALL: DRAW_VECTOR at line 272
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: taj_bg (index=29, 4 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_8          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
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
    LDX #_TAJ_BG_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_TAJ_BG_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_TAJ_BG_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_TAJ_BG_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_8:
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_59:
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #6
    LBNE IF_NEXT_60
; VPy_LINE:274
; NATIVE_CALL: DRAW_VECTOR at line 274
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: leningrad_bg (index=15, 5 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_9          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
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
    LDX #_LENINGRAD_BG_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_LENINGRAD_BG_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_LENINGRAD_BG_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_LENINGRAD_BG_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_LENINGRAD_BG_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_9:
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_60:
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #7
    LBNE IF_NEXT_61
; VPy_LINE:276
; NATIVE_CALL: DRAW_VECTOR at line 276
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: paris_bg (index=22, 5 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_10          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_10
    LDB #$FF
.sx_pos_10:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_PARIS_BG_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PARIS_BG_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PARIS_BG_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PARIS_BG_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PARIS_BG_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_10:
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_61:
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #8
    LBNE IF_NEXT_62
; VPy_LINE:278
; NATIVE_CALL: DRAW_VECTOR at line 278
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: london_bg (index=18, 4 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_11          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
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
    LDX #_LONDON_BG_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_LONDON_BG_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_LONDON_BG_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_LONDON_BG_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_11:
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_62:
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #9
    LBNE IF_NEXT_63
; VPy_LINE:280
; NATIVE_CALL: DRAW_VECTOR at line 280
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: barcelona_bg (index=4, 50 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_12          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
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
    LDX #_BARCELONA_BG_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH7  ; Load path 7
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH8  ; Load path 8
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH9  ; Load path 9
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH10  ; Load path 10
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH11  ; Load path 11
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH12  ; Load path 12
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH13  ; Load path 13
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH14  ; Load path 14
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH15  ; Load path 15
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH16  ; Load path 16
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH17  ; Load path 17
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH18  ; Load path 18
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH19  ; Load path 19
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH20  ; Load path 20
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH21  ; Load path 21
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH22  ; Load path 22
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH23  ; Load path 23
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH24  ; Load path 24
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH25  ; Load path 25
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH26  ; Load path 26
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH27  ; Load path 27
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH28  ; Load path 28
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH29  ; Load path 29
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH30  ; Load path 30
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH31  ; Load path 31
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH32  ; Load path 32
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH33  ; Load path 33
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH34  ; Load path 34
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH35  ; Load path 35
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH36  ; Load path 36
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH37  ; Load path 37
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH38  ; Load path 38
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH39  ; Load path 39
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH40  ; Load path 40
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH41  ; Load path 41
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH42  ; Load path 42
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH43  ; Load path 43
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH44  ; Load path 44
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH45  ; Load path 45
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH46  ; Load path 46
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH47  ; Load path 47
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH48  ; Load path 48
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH49  ; Load path 49
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_12:
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_63:
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #10
    LBNE IF_NEXT_64
; VPy_LINE:282
; NATIVE_CALL: DRAW_VECTOR at line 282
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: athens_bg (index=2, 33 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_13          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
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
    LDX #_ATHENS_BG_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH7  ; Load path 7
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH8  ; Load path 8
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH9  ; Load path 9
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH10  ; Load path 10
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH11  ; Load path 11
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH12  ; Load path 12
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH13  ; Load path 13
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH14  ; Load path 14
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH15  ; Load path 15
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH16  ; Load path 16
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH17  ; Load path 17
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH18  ; Load path 18
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH19  ; Load path 19
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH20  ; Load path 20
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH21  ; Load path 21
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH22  ; Load path 22
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH23  ; Load path 23
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH24  ; Load path 24
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH25  ; Load path 25
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH26  ; Load path 26
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH27  ; Load path 27
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH28  ; Load path 28
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH29  ; Load path 29
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH30  ; Load path 30
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH31  ; Load path 31
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH32  ; Load path 32
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_13:
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_64:
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #11
    LBNE IF_NEXT_65
; VPy_LINE:284
; NATIVE_CALL: DRAW_VECTOR at line 284
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: pyramids_bg (index=28, 4 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_14          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
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
    LDX #_PYRAMIDS_BG_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PYRAMIDS_BG_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PYRAMIDS_BG_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PYRAMIDS_BG_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_14:
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_65:
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #12
    LBNE IF_NEXT_66
; VPy_LINE:286
; NATIVE_CALL: DRAW_VECTOR at line 286
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: kilimanjaro_bg (index=14, 4 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_15          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_15
    LDB #$FF
.sx_pos_15:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_KILIMANJARO_BG_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_KILIMANJARO_BG_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_KILIMANJARO_BG_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_KILIMANJARO_BG_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_15:
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_66:
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #13
    LBNE IF_NEXT_67
; VPy_LINE:288
; NATIVE_CALL: DRAW_VECTOR at line 288
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: newyork_bg (index=21, 5 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_16          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_16
    LDB #$FF
.sx_pos_16:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_NEWYORK_BG_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_NEWYORK_BG_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_NEWYORK_BG_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_NEWYORK_BG_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_NEWYORK_BG_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_16:
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_67:
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #14
    LBNE IF_NEXT_68
; VPy_LINE:290
; NATIVE_CALL: DRAW_VECTOR at line 290
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: mayan_bg (index=20, 5 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_17          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_17
    LDB #$FF
.sx_pos_17:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_MAYAN_BG_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAYAN_BG_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAYAN_BG_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAYAN_BG_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAYAN_BG_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_17:
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_68:
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #15
    LBNE IF_NEXT_69
; VPy_LINE:292
; NATIVE_CALL: DRAW_VECTOR at line 292
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: antarctica_bg (index=1, 19 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_18          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_18
    LDB #$FF
.sx_pos_18:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_ANTARCTICA_BG_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANTARCTICA_BG_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANTARCTICA_BG_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANTARCTICA_BG_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANTARCTICA_BG_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANTARCTICA_BG_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANTARCTICA_BG_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANTARCTICA_BG_PATH7  ; Load path 7
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANTARCTICA_BG_PATH8  ; Load path 8
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANTARCTICA_BG_PATH9  ; Load path 9
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANTARCTICA_BG_PATH10  ; Load path 10
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANTARCTICA_BG_PATH11  ; Load path 11
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANTARCTICA_BG_PATH12  ; Load path 12
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANTARCTICA_BG_PATH13  ; Load path 13
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANTARCTICA_BG_PATH14  ; Load path 14
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANTARCTICA_BG_PATH15  ; Load path 15
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANTARCTICA_BG_PATH16  ; Load path 16
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANTARCTICA_BG_PATH17  ; Load path 17
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANTARCTICA_BG_PATH18  ; Load path 18
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_18:
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_69:
; VPy_LINE:294
; NATIVE_CALL: DRAW_VECTOR at line 294
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: easter_bg (index=10, 5 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_19          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_19
    LDB #$FF
.sx_pos_19:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_EASTER_BG_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_EASTER_BG_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_EASTER_BG_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_EASTER_BG_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_EASTER_BG_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_19:
    LDD #0
    STD RESULT
IF_END_53:
    RTS

; Function: DRAW_GAME_LEVEL
DRAW_GAME_LEVEL:
; VPy_LINE:298
    JSR DRAW_LEVEL_BACKGROUND
; VPy_LINE:301
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    STD VAR_JOY_X
; VPy_LINE:305
    LDD #-20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBLT .CMP_43_TRUE
    LDD #0
    LBRA .CMP_43_END
.CMP_43_TRUE:
    LDD #1
.CMP_43_END:
    LBNE .LOGIC_42_TRUE
    LDD #20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBGT .CMP_44_TRUE
    LDD #0
    LBRA .CMP_44_END
.CMP_44_TRUE:
    LDD #1
.CMP_44_END:
    LBNE .LOGIC_42_TRUE
    LDD #0
    LBRA .LOGIC_42_END
.LOGIC_42_TRUE:
    LDD #1
.LOGIC_42_END:
    LBEQ IF_NEXT_71
; VPy_LINE:308
    LDD >VAR_JOY_X
    STB VAR_ABS_JOY
; VPy_LINE:309
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_ABS_JOY
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBLT .CMP_45_TRUE
    LDD #0
    LBRA .CMP_45_END
.CMP_45_TRUE:
    LDD #1
.CMP_45_END:
    LBEQ IF_NEXT_73
; VPy_LINE:310
    LDB >VAR_ABS_JOY
    CLRA            ; Zero-extend: A=0, B=value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STB VAR_ABS_JOY
    LBRA IF_END_72
IF_NEXT_73:
IF_END_72:
; VPy_LINE:315
    LDD #40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_ABS_JOY
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBLT .CMP_46_TRUE
    LDD #0
    LBRA .CMP_46_END
.CMP_46_TRUE:
    LDD #1
.CMP_46_END:
    LBEQ IF_NEXT_75
; VPy_LINE:316
    LDD #1
    STB VAR_MOVE_SPEED
    LBRA IF_END_74
IF_NEXT_75:
    LDD #70
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_ABS_JOY
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBLT .CMP_47_TRUE
    LDD #0
    LBRA .CMP_47_END
.CMP_47_TRUE:
    LDD #1
.CMP_47_END:
    LBEQ IF_NEXT_76
; VPy_LINE:318
    LDD #2
    STB VAR_MOVE_SPEED
    LBRA IF_END_74
IF_NEXT_76:
    LDD #100
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_ABS_JOY
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBLT .CMP_48_TRUE
    LDD #0
    LBRA .CMP_48_END
.CMP_48_TRUE:
    LDD #1
.CMP_48_END:
    LBEQ IF_NEXT_77
; VPy_LINE:320
    LDD #3
    STB VAR_MOVE_SPEED
    LBRA IF_END_74
IF_NEXT_77:
; VPy_LINE:322
    LDD #4
    STB VAR_MOVE_SPEED
IF_END_74:
; VPy_LINE:325
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBLT .CMP_49_TRUE
    LDD #0
    LBRA .CMP_49_END
.CMP_49_TRUE:
    LDD #1
.CMP_49_END:
    LBEQ IF_NEXT_79
; VPy_LINE:326
    LDB >VAR_MOVE_SPEED
    SEX             ; Sign-extend B -> D
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STB VAR_MOVE_SPEED
    LBRA IF_END_78
IF_NEXT_79:
IF_END_78:
; VPy_LINE:328
    LDB >VAR_MOVE_SPEED
    SEX             ; Sign-extend B -> D
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_PLAYER_X
; VPy_LINE:331
    LDD #-110
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    CMPD TMPVAL
    LBLT .CMP_50_TRUE
    LDD #0
    LBRA .CMP_50_END
.CMP_50_TRUE:
    LDD #1
.CMP_50_END:
    LBEQ IF_NEXT_81
; VPy_LINE:332
    LDD #-110
    STD VAR_PLAYER_X
    LBRA IF_END_80
IF_NEXT_81:
IF_END_80:
; VPy_LINE:333
    LDD #110
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    CMPD TMPVAL
    LBGT .CMP_51_TRUE
    LDD #0
    LBRA .CMP_51_END
.CMP_51_TRUE:
    LDD #1
.CMP_51_END:
    LBEQ IF_NEXT_83
; VPy_LINE:334
    LDD #110
    STD VAR_PLAYER_X
    LBRA IF_END_82
IF_NEXT_83:
IF_END_82:
; VPy_LINE:337
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBLT .CMP_52_TRUE
    LDD #0
    LBRA .CMP_52_END
.CMP_52_TRUE:
    LDD #1
.CMP_52_END:
    LBEQ IF_NEXT_85
; VPy_LINE:338
    LDD #-1
    STB VAR_PLAYER_FACING
    LBRA IF_END_84
IF_NEXT_85:
; VPy_LINE:340
    LDD #1
    STB VAR_PLAYER_FACING
IF_END_84:
; VPy_LINE:343
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDB >VAR_PLAYER_ANIM_COUNTER
    CLRA            ; Zero-extend: A=0, B=value
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STB VAR_PLAYER_ANIM_COUNTER
; VPy_LINE:345
    LDD #5  ; const PLAYER_ANIM_SPEED
    STD VAR_ANIM_THRESHOLD
; VPy_LINE:346
    LDD #-80
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBLT .CMP_54_TRUE
    LDD #0
    LBRA .CMP_54_END
.CMP_54_TRUE:
    LDD #1
.CMP_54_END:
    LBNE .LOGIC_53_TRUE
    LDD #80
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBGT .CMP_55_TRUE
    LDD #0
    LBRA .CMP_55_END
.CMP_55_TRUE:
    LDD #1
.CMP_55_END:
    LBNE .LOGIC_53_TRUE
    LDD #0
    LBRA .LOGIC_53_END
.LOGIC_53_TRUE:
    LDD #1
.LOGIC_53_END:
    LBEQ IF_NEXT_87
; VPy_LINE:347
    LDD #2
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #5  ; const PLAYER_ANIM_SPEED
    TFR D,X             ; X = LEFT (dividend)
    LDD TMPVAL          ; D = RIGHT (divisor)
    JSR DIV16           ; D = X / D
    STD VAR_ANIM_THRESHOLD
    LBRA IF_END_86
IF_NEXT_87:
IF_END_86:
; VPy_LINE:349
    LDD >VAR_ANIM_THRESHOLD
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_PLAYER_ANIM_COUNTER
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBGE .CMP_56_TRUE
    LDD #0
    LBRA .CMP_56_END
.CMP_56_TRUE:
    LDD #1
.CMP_56_END:
    LBEQ IF_NEXT_89
; VPy_LINE:350
    LDD #0
    STB VAR_PLAYER_ANIM_COUNTER
; VPy_LINE:351
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDB >VAR_PLAYER_ANIM_FRAME
    CLRA            ; Zero-extend: A=0, B=value
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STB VAR_PLAYER_ANIM_FRAME
; VPy_LINE:352
    LDD #5
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_PLAYER_ANIM_FRAME
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBGT .CMP_57_TRUE
    LDD #0
    LBRA .CMP_57_END
.CMP_57_TRUE:
    LDD #1
.CMP_57_END:
    LBEQ IF_NEXT_91
; VPy_LINE:353
    LDD #1
    STB VAR_PLAYER_ANIM_FRAME
    LBRA IF_END_90
IF_NEXT_91:
IF_END_90:
    LBRA IF_END_88
IF_NEXT_89:
IF_END_88:
    LBRA IF_END_70
IF_NEXT_71:
; VPy_LINE:356
    LDD #1
    STB VAR_PLAYER_ANIM_FRAME
; VPy_LINE:357
    LDD #0
    STB VAR_PLAYER_ANIM_COUNTER
IF_END_70:
; VPy_LINE:360
    LDD #0
    STD VAR_MIRROR_MODE
; VPy_LINE:361
    LDB >VAR_PLAYER_FACING
    SEX             ; Sign-extend B -> D
    CMPD #-1
    LBNE IF_NEXT_93
; VPy_LINE:362
    LDD #1
    STD VAR_MIRROR_MODE
    LBRA IF_END_92
IF_NEXT_93:
IF_END_92:
; VPy_LINE:365
    LDB >VAR_PLAYER_ANIM_FRAME
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #1
    LBNE IF_NEXT_95
; VPy_LINE:366
; NATIVE_CALL: DRAW_VECTOR_EX at line 366
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_1 (index=23, 17 paths) with mirror + intensity
    LDD >VAR_PLAYER_X
    TFR B,A       ; X position (low byte) — B already holds it
    STA DRAW_VEC_X
    LDD #-70  ; const PLAYER_Y
    TFR B,A       ; Y position (low byte) — B already holds it
    STA DRAW_VEC_Y
    LDD >VAR_MIRROR_MODE
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_20_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_20_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_20_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_20_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_20_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_20_CALL:
    ; Set intensity override for drawing
    LDD #80
    TFR B,A       ; Intensity (0-127) — B already holds it
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_PLAYER_WALK_1_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH7  ; Load path 7
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH8  ; Load path 8
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH9  ; Load path 9
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH10  ; Load path 10
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH11  ; Load path 11
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH12  ; Load path 12
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH13  ; Load path 13
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH14  ; Load path 14
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH15  ; Load path 15
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH16  ; Load path 16
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    LBRA IF_END_94
IF_NEXT_95:
    LDB >VAR_PLAYER_ANIM_FRAME
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #2
    LBNE IF_NEXT_96
; VPy_LINE:368
; NATIVE_CALL: DRAW_VECTOR_EX at line 368
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_2 (index=24, 17 paths) with mirror + intensity
    LDD >VAR_PLAYER_X
    TFR B,A       ; X position (low byte) — B already holds it
    STA DRAW_VEC_X
    LDD #-70  ; const PLAYER_Y
    TFR B,A       ; Y position (low byte) — B already holds it
    STA DRAW_VEC_Y
    LDD >VAR_MIRROR_MODE
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_21_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_21_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_21_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_21_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_21_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_21_CALL:
    ; Set intensity override for drawing
    LDD #80
    TFR B,A       ; Intensity (0-127) — B already holds it
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_PLAYER_WALK_2_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH7  ; Load path 7
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH8  ; Load path 8
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH9  ; Load path 9
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH10  ; Load path 10
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH11  ; Load path 11
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH12  ; Load path 12
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH13  ; Load path 13
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH14  ; Load path 14
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH15  ; Load path 15
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH16  ; Load path 16
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    LBRA IF_END_94
IF_NEXT_96:
    LDB >VAR_PLAYER_ANIM_FRAME
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #3
    LBNE IF_NEXT_97
; VPy_LINE:370
; NATIVE_CALL: DRAW_VECTOR_EX at line 370
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_3 (index=25, 17 paths) with mirror + intensity
    LDD >VAR_PLAYER_X
    TFR B,A       ; X position (low byte) — B already holds it
    STA DRAW_VEC_X
    LDD #-70  ; const PLAYER_Y
    TFR B,A       ; Y position (low byte) — B already holds it
    STA DRAW_VEC_Y
    LDD >VAR_MIRROR_MODE
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_22_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_22_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_22_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_22_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_22_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_22_CALL:
    ; Set intensity override for drawing
    LDD #80
    TFR B,A       ; Intensity (0-127) — B already holds it
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_PLAYER_WALK_3_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH7  ; Load path 7
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH8  ; Load path 8
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH9  ; Load path 9
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH10  ; Load path 10
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH11  ; Load path 11
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH12  ; Load path 12
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH13  ; Load path 13
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH14  ; Load path 14
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH15  ; Load path 15
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH16  ; Load path 16
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    LBRA IF_END_94
IF_NEXT_97:
    LDB >VAR_PLAYER_ANIM_FRAME
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #4
    LBNE IF_NEXT_98
; VPy_LINE:372
; NATIVE_CALL: DRAW_VECTOR_EX at line 372
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_4 (index=26, 17 paths) with mirror + intensity
    LDD >VAR_PLAYER_X
    TFR B,A       ; X position (low byte) — B already holds it
    STA DRAW_VEC_X
    LDD #-70  ; const PLAYER_Y
    TFR B,A       ; Y position (low byte) — B already holds it
    STA DRAW_VEC_Y
    LDD >VAR_MIRROR_MODE
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_23_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_23_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_23_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_23_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_23_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_23_CALL:
    ; Set intensity override for drawing
    LDD #80
    TFR B,A       ; Intensity (0-127) — B already holds it
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_PLAYER_WALK_4_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH7  ; Load path 7
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH8  ; Load path 8
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH9  ; Load path 9
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH10  ; Load path 10
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH11  ; Load path 11
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH12  ; Load path 12
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH13  ; Load path 13
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH14  ; Load path 14
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH15  ; Load path 15
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH16  ; Load path 16
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    LBRA IF_END_94
IF_NEXT_98:
; VPy_LINE:374
; NATIVE_CALL: DRAW_VECTOR_EX at line 374
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_5 (index=27, 17 paths) with mirror + intensity
    LDD >VAR_PLAYER_X
    TFR B,A       ; X position (low byte) — B already holds it
    STA DRAW_VEC_X
    LDD #-70  ; const PLAYER_Y
    TFR B,A       ; Y position (low byte) — B already holds it
    STA DRAW_VEC_Y
    LDD >VAR_MIRROR_MODE
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_24_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_24_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_24_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_24_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_24_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_24_CALL:
    ; Set intensity override for drawing
    LDD #80
    TFR B,A       ; Intensity (0-127) — B already holds it
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_PLAYER_WALK_5_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH7  ; Load path 7
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH8  ; Load path 8
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH9  ; Load path 9
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH10  ; Load path 10
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH11  ; Load path 11
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH12  ; Load path 12
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH13  ; Load path 13
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH14  ; Load path 14
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH15  ; Load path 15
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH16  ; Load path 16
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
IF_END_94:
; VPy_LINE:377
    ; UPDATE_ENEMIES: advance enemy AI and movement
    JSR UPDATE_ENEMIES_RUNTIME
; VPy_LINE:378
    ; DRAW_ENEMIES: render all active enemies
    JSR DRAW_ENEMIES_RUNTIME
; VPy_LINE:381
    LDB >VAR_HOOK_ACTIVE
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #1
    LBNE IF_NEXT_100
; VPy_LINE:384
    LDD >VAR_HOOK_GUN_X
    STD VAR_ARG0
    LDD >VAR_HOOK_INIT_Y
    STD VAR_ARG1
    LDD >VAR_HOOK_X
    STD VAR_ARG2
    LDD >VAR_HOOK_Y
    STD VAR_ARG3
    JSR DRAW_HOOK_ROPE
; VPy_LINE:386
; NATIVE_CALL: SET_INTENSITY at line 386
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:388
; NATIVE_CALL: DRAW_VECTOR_EX at line 388
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: hook (index=12, 1 paths) with mirror + intensity
    LDD >VAR_HOOK_X
    TFR B,A       ; X position (low byte) — B already holds it
    STA DRAW_VEC_X
    LDD >VAR_HOOK_Y
    TFR B,A       ; Y position (low byte) — B already holds it
    STA DRAW_VEC_Y
    LDD #0
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_25_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_25_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_25_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_25_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_25_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_25_CALL:
    ; Set intensity override for drawing
    LDD #100
    TFR B,A       ; Intensity (0-127) — B already holds it
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_HOOK_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    LBRA IF_END_99
IF_NEXT_100:
IF_END_99:
; VPy_LINE:391
    LDD #0
    STD VAR_ACTIVE_COUNT
; VPy_LINE:392
    LDD #0
    STD VAR_I
; VPy_LINE:393
WH_101: ; while start
    LDD #8  ; const MAX_ENEMIES
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    CMPD TMPVAL
    LBLT .CMP_58_TRUE
    LDD #0
    LBRA .CMP_58_END
.CMP_58_TRUE:
    LDD #1
.CMP_58_END:
    LBEQ WH_END_102
; VPy_LINE:394
    LDX #VAR_ENEMY_ACTIVE_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    CMPD #1
    LBNE IF_NEXT_104
; VPy_LINE:395
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ACTIVE_COUNT
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_ACTIVE_COUNT
    LBRA IF_END_103
IF_NEXT_104:
IF_END_103:
; VPy_LINE:396
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_I
    LBRA WH_101
WH_END_102: ; while end
    RTS

; Function: SPAWN_ENEMIES
SPAWN_ENEMIES:
; VPy_LINE:402
    LDX #ARRAY_LEVEL_ENEMY_COUNT_DATA  ; Array base
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_COUNT
; VPy_LINE:403
    LDX #ARRAY_LEVEL_ENEMY_SPEED_DATA  ; Array base
    LDB >VAR_CURRENT_LOCATION
    CLRA            ; Zero-extend: A=0, B=value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_SPEED
; VPy_LINE:405
    LDD #0
    STD VAR_I
; VPy_LINE:406
WH_105: ; while start
    LDD >VAR_COUNT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    CMPD TMPVAL
    LBLT .CMP_59_TRUE
    LDD #0
    LBRA .CMP_59_END
.CMP_59_TRUE:
    LDD #1
.CMP_59_END:
    LBEQ WH_END_106
; VPy_LINE:407
    LDD >VAR_I
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_ACTIVE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #1
    PULS X          ; Restore computed address
    STB ,X          ; Store 8-bit value
; VPy_LINE:408
    LDD >VAR_I
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_SIZE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #4
    PULS X          ; Restore computed address
    STB ,X          ; Store 8-bit value
; VPy_LINE:409
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_X_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #50
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-80
    ADDD TMPVAL         ; D = LEFT + RIGHT
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:410
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_Y_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #60
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:411
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VX_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD >VAR_SPEED
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:412
    LDD #2
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MOD16           ; D = X % D
    CMPD #1
    LBNE IF_NEXT_108
; VPy_LINE:413
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VX_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD >VAR_SPEED
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
    LBRA IF_END_107
IF_NEXT_108:
IF_END_107:
; VPy_LINE:414
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VY_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #0
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:415
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_I
    LBRA WH_105
WH_END_106: ; while end
    RTS

; Function: UPDATE_ENEMIES
UPDATE_ENEMIES:
; VPy_LINE:419
    LDD #0
    STD VAR_I
; VPy_LINE:420
WH_109: ; while start
    LDD #8  ; const MAX_ENEMIES
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    CMPD TMPVAL
    LBLT .CMP_60_TRUE
    LDD #0
    LBRA .CMP_60_END
.CMP_60_TRUE:
    LDD #1
.CMP_60_END:
    LBEQ WH_END_110
; VPy_LINE:421
    LDX #VAR_ENEMY_ACTIVE_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    CMPD #1
    LBNE IF_NEXT_112
; VPy_LINE:423
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VY_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDX #VAR_ENEMY_VY_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD #1  ; const GRAVITY
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    SUBD TMPVAL         ; D = LEFT - RIGHT
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:426
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_X_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDX #VAR_ENEMY_VX_DATA  ; Array base
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
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:427
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_Y_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDX #VAR_ENEMY_VY_DATA  ; Array base
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
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:430
    LDD #-70  ; const GROUND_Y
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBLE .CMP_61_TRUE
    LDD #0
    LBRA .CMP_61_END
.CMP_61_TRUE:
    LDD #1
.CMP_61_END:
    LBEQ IF_NEXT_114
; VPy_LINE:431
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_Y_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #-70  ; const GROUND_Y
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:432
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VY_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDX #VAR_ENEMY_VY_DATA  ; Array base
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
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:433
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VY_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDX #VAR_ENEMY_VY_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; LEFT → TMPVAL (RIGHT simple, commutative)
    LDD #17  ; const BOUNCE_DAMPING
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD #20
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    TFR D,X             ; X = LEFT (dividend)
    LDD TMPVAL          ; D = RIGHT (divisor)
    JSR DIV16           ; D = X / D
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:435
    LDD #10  ; const MIN_BOUNCE_VY
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_VY_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBLT .CMP_62_TRUE
    LDD #0
    LBRA .CMP_62_END
.CMP_62_TRUE:
    LDD #1
.CMP_62_END:
    LBEQ IF_NEXT_116
; VPy_LINE:436
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VY_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #10  ; const MIN_BOUNCE_VY
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
    LBRA IF_END_115
IF_NEXT_116:
IF_END_115:
    LBRA IF_END_113
IF_NEXT_114:
IF_END_113:
; VPy_LINE:439
    LDD #-85
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_X_DATA  ; Array base
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
    LBEQ IF_NEXT_118
; VPy_LINE:440
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_X_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #-85
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:441
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VX_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDX #VAR_ENEMY_VX_DATA  ; Array base
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
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
    LBRA IF_END_117
IF_NEXT_118:
IF_END_117:
; VPy_LINE:442
    LDD #85
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBGE .CMP_64_TRUE
    LDD #0
    LBRA .CMP_64_END
.CMP_64_TRUE:
    LDD #1
.CMP_64_END:
    LBEQ IF_NEXT_120
; VPy_LINE:443
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_X_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #85
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:444
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VX_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDX #VAR_ENEMY_VX_DATA  ; Array base
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
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
    LBRA IF_END_119
IF_NEXT_120:
IF_END_119:
    LBRA IF_END_111
IF_NEXT_112:
IF_END_111:
; VPy_LINE:446
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_I
    LBRA WH_109
WH_END_110: ; while end
    RTS

; Function: DRAW_ENEMIES
DRAW_ENEMIES:
; VPy_LINE:452
    LDD #0
    STD VAR_I
; VPy_LINE:453
WH_121: ; while start
    LDD #8  ; const MAX_ENEMIES
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    CMPD TMPVAL
    LBLT .CMP_65_TRUE
    LDD #0
    LBRA .CMP_65_END
.CMP_65_TRUE:
    LDD #1
.CMP_65_END:
    LBEQ WH_END_122
; VPy_LINE:454
    LDX #VAR_ENEMY_ACTIVE_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    CMPD #1
    LBNE IF_NEXT_124
; VPy_LINE:455
; NATIVE_CALL: SET_INTENSITY at line 455
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:456
    LDX #VAR_ENEMY_SIZE_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    CMPD #4
    LBNE IF_NEXT_126
; VPy_LINE:457
; NATIVE_CALL: DRAW_VECTOR at line 457
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bubble_huge (index=5, 1 paths)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_26          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_26
    LDB #$FF
.sx_pos_26:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_BUBBLE_HUGE_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_26:
    LDD #0
    STD RESULT
    LBRA IF_END_125
IF_NEXT_126:
    LDX #VAR_ENEMY_SIZE_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    CMPD #3
    LBNE IF_NEXT_127
; VPy_LINE:459
; NATIVE_CALL: DRAW_VECTOR at line 459
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bubble_large (index=6, 1 paths)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_27          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_27
    LDB #$FF
.sx_pos_27:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_BUBBLE_LARGE_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_27:
    LDD #0
    STD RESULT
    LBRA IF_END_125
IF_NEXT_127:
    LDX #VAR_ENEMY_SIZE_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    CMPD #2
    LBNE IF_NEXT_128
; VPy_LINE:461
; NATIVE_CALL: DRAW_VECTOR at line 461
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bubble_medium (index=7, 1 paths)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_28          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_28
    LDB #$FF
.sx_pos_28:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_BUBBLE_MEDIUM_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_28:
    LDD #0
    STD RESULT
    LBRA IF_END_125
IF_NEXT_128:
; VPy_LINE:463
; NATIVE_CALL: DRAW_VECTOR at line 463
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bubble_small (index=8, 1 paths)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_29          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_29
    LDB #$FF
.sx_pos_29:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_BUBBLE_SMALL_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_29:
    LDD #0
    STD RESULT
IF_END_125:
    LBRA IF_END_123
IF_NEXT_124:
IF_END_123:
; VPy_LINE:464
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_I
    LBRA WH_121
WH_END_122: ; while end
    RTS

; Function: DRAW_HOOK_ROPE
DRAW_HOOK_ROPE:
; VPy_LINE:470
; NATIVE_CALL: DRAW_LINE at line 470
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_ARG0
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_ARG1
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_ARG2
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_ARG3
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #127
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    RTS

; Function: READ_JOYSTICK1_STATE
READ_JOYSTICK1_STATE:
; VPy_LINE:477
; NATIVE_CALL: J1_X at line 477
    LDD #0
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_JOYSTICK1_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    JSR J1X_BUILTIN
    STD RESULT
    PULS X          ; Restore computed address
    STB ,X          ; Store 8-bit value
; VPy_LINE:478
; NATIVE_CALL: J1_Y at line 478
    LDD #1
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_JOYSTICK1_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    JSR J1Y_BUILTIN
    STD RESULT
    PULS X          ; Restore computed address
    STB ,X          ; Store 8-bit value
; VPy_LINE:481
; NATIVE_CALL: J1_BUTTON_1 at line 481
    LDD #2
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_JOYSTICK1_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed
    BITA #$01
    BNE .J1B1_30_ON
    LDD #0
    BRA .J1B1_30_END
.J1B1_30_ON:
    LDD #1
.J1B1_30_END:
    STD RESULT
    PULS X          ; Restore computed address
    STB ,X          ; Store 8-bit value
; VPy_LINE:482
; NATIVE_CALL: J1_BUTTON_2 at line 482
    LDD #3
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_JOYSTICK1_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDA >$C80F   ; Vec_Btns_1: bit1=1 means btn2 pressed
    BITA #$02
    BNE .J1B2_31_ON
    LDD #0
    BRA .J1B2_31_END
.J1B2_31_ON:
    LDD #1
.J1B2_31_END:
    STD RESULT
    PULS X          ; Restore computed address
    STB ,X          ; Store 8-bit value
; VPy_LINE:483
; NATIVE_CALL: J1_BUTTON_3 at line 483
    LDD #4
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_JOYSTICK1_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDA >$C80F   ; Vec_Btns_1: bit2=1 means btn3 pressed
    BITA #$04
    BNE .J1B3_32_ON
    LDD #0
    BRA .J1B3_32_END
.J1B3_32_ON:
    LDD #1
.J1B3_32_END:
    STD RESULT
    PULS X          ; Restore computed address
    STB ,X          ; Store 8-bit value
; VPy_LINE:484
; NATIVE_CALL: J1_BUTTON_4 at line 484
    LDD #5
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_JOYSTICK1_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDA >$C80F   ; Vec_Btns_1: bit3=1 means btn4 pressed
    BITA #$08
    BNE .J1B4_33_ON
    LDD #0
    BRA .J1B4_33_END
.J1B4_33_ON:
    LDD #1
.J1B4_33_END:
    STD RESULT
    PULS X          ; Restore computed address
    STB ,X          ; Store 8-bit value
    RTS

;***************************************************************************
; EMBEDDED ASSETS (vectors, music, levels, SFX)
;***************************************************************************

; Generated from angkor_bg.vec (Malban Draw_Sync_List format)
; Total paths: 192, points: 648
; X bounds: min=-96, max=96, width=192
; Center: (0, 8)

_ANGKOR_BG_WIDTH EQU 192
_ANGKOR_BG_HALF_WIDTH EQU 96
_ANGKOR_BG_HEIGHT EQU 129
_ANGKOR_BG_HALF_HEIGHT EQU 64
_ANGKOR_BG_CENTER_X EQU 0
_ANGKOR_BG_CENTER_Y EQU 8

_ANGKOR_BG_VECTORS:  ; Main entry (header + 139 path(s))
    FDB 139               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _ANGKOR_BG_PATH0        ; pointer to path 0
    FDB _ANGKOR_BG_PATH1        ; pointer to path 1
    FDB _ANGKOR_BG_PATH2        ; pointer to path 2
    FDB _ANGKOR_BG_PATH3        ; pointer to path 3
    FDB _ANGKOR_BG_PATH4        ; pointer to path 4
    FDB _ANGKOR_BG_PATH5        ; pointer to path 5
    FDB _ANGKOR_BG_PATH6        ; pointer to path 6
    FDB _ANGKOR_BG_PATH7        ; pointer to path 7
    FDB _ANGKOR_BG_PATH8        ; pointer to path 8
    FDB _ANGKOR_BG_PATH9        ; pointer to path 9
    FDB _ANGKOR_BG_PATH10        ; pointer to path 10
    FDB _ANGKOR_BG_PATH11        ; pointer to path 11
    FDB _ANGKOR_BG_PATH12        ; pointer to path 12
    FDB _ANGKOR_BG_PATH13        ; pointer to path 13
    FDB _ANGKOR_BG_PATH14        ; pointer to path 14
    FDB _ANGKOR_BG_PATH15        ; pointer to path 15
    FDB _ANGKOR_BG_PATH16        ; pointer to path 16
    FDB _ANGKOR_BG_PATH17        ; pointer to path 17
    FDB _ANGKOR_BG_PATH18        ; pointer to path 18
    FDB _ANGKOR_BG_PATH19        ; pointer to path 19
    FDB _ANGKOR_BG_PATH20        ; pointer to path 20
    FDB _ANGKOR_BG_PATH21        ; pointer to path 21
    FDB _ANGKOR_BG_PATH22        ; pointer to path 22
    FDB _ANGKOR_BG_PATH23        ; pointer to path 23
    FDB _ANGKOR_BG_PATH24        ; pointer to path 24
    FDB _ANGKOR_BG_PATH25        ; pointer to path 25
    FDB _ANGKOR_BG_PATH26        ; pointer to path 26
    FDB _ANGKOR_BG_PATH27        ; pointer to path 27
    FDB _ANGKOR_BG_PATH28        ; pointer to path 28
    FDB _ANGKOR_BG_PATH29        ; pointer to path 29
    FDB _ANGKOR_BG_PATH30        ; pointer to path 30
    FDB _ANGKOR_BG_PATH31        ; pointer to path 31
    FDB _ANGKOR_BG_PATH32        ; pointer to path 32
    FDB _ANGKOR_BG_PATH33        ; pointer to path 33
    FDB _ANGKOR_BG_PATH34        ; pointer to path 34
    FDB _ANGKOR_BG_PATH35        ; pointer to path 35
    FDB _ANGKOR_BG_PATH36        ; pointer to path 36
    FDB _ANGKOR_BG_PATH37        ; pointer to path 37
    FDB _ANGKOR_BG_PATH38        ; pointer to path 38
    FDB _ANGKOR_BG_PATH39        ; pointer to path 39
    FDB _ANGKOR_BG_PATH40        ; pointer to path 40
    FDB _ANGKOR_BG_PATH41        ; pointer to path 41
    FDB _ANGKOR_BG_PATH42        ; pointer to path 42
    FDB _ANGKOR_BG_PATH43        ; pointer to path 43
    FDB _ANGKOR_BG_PATH44        ; pointer to path 44
    FDB _ANGKOR_BG_PATH45        ; pointer to path 45
    FDB _ANGKOR_BG_PATH46        ; pointer to path 46
    FDB _ANGKOR_BG_PATH47        ; pointer to path 47
    FDB _ANGKOR_BG_PATH48        ; pointer to path 48
    FDB _ANGKOR_BG_PATH49        ; pointer to path 49
    FDB _ANGKOR_BG_PATH50        ; pointer to path 50
    FDB _ANGKOR_BG_PATH51        ; pointer to path 51
    FDB _ANGKOR_BG_PATH52        ; pointer to path 52
    FDB _ANGKOR_BG_PATH53        ; pointer to path 53
    FDB _ANGKOR_BG_PATH54        ; pointer to path 54
    FDB _ANGKOR_BG_PATH55        ; pointer to path 55
    FDB _ANGKOR_BG_PATH56        ; pointer to path 56
    FDB _ANGKOR_BG_PATH57        ; pointer to path 57
    FDB _ANGKOR_BG_PATH58        ; pointer to path 58
    FDB _ANGKOR_BG_PATH59        ; pointer to path 59
    FDB _ANGKOR_BG_PATH60        ; pointer to path 60
    FDB _ANGKOR_BG_PATH61        ; pointer to path 61
    FDB _ANGKOR_BG_PATH62        ; pointer to path 62
    FDB _ANGKOR_BG_PATH63        ; pointer to path 63
    FDB _ANGKOR_BG_PATH64        ; pointer to path 64
    FDB _ANGKOR_BG_PATH65        ; pointer to path 65
    FDB _ANGKOR_BG_PATH66        ; pointer to path 66
    FDB _ANGKOR_BG_PATH67        ; pointer to path 67
    FDB _ANGKOR_BG_PATH68        ; pointer to path 68
    FDB _ANGKOR_BG_PATH69        ; pointer to path 69
    FDB _ANGKOR_BG_PATH70        ; pointer to path 70
    FDB _ANGKOR_BG_PATH71        ; pointer to path 71
    FDB _ANGKOR_BG_PATH72        ; pointer to path 72
    FDB _ANGKOR_BG_PATH73        ; pointer to path 73
    FDB _ANGKOR_BG_PATH74        ; pointer to path 74
    FDB _ANGKOR_BG_PATH75        ; pointer to path 75
    FDB _ANGKOR_BG_PATH76        ; pointer to path 76
    FDB _ANGKOR_BG_PATH77        ; pointer to path 77
    FDB _ANGKOR_BG_PATH78        ; pointer to path 78
    FDB _ANGKOR_BG_PATH79        ; pointer to path 79
    FDB _ANGKOR_BG_PATH80        ; pointer to path 80
    FDB _ANGKOR_BG_PATH81        ; pointer to path 81
    FDB _ANGKOR_BG_PATH82        ; pointer to path 82
    FDB _ANGKOR_BG_PATH83        ; pointer to path 83
    FDB _ANGKOR_BG_PATH84        ; pointer to path 84
    FDB _ANGKOR_BG_PATH85        ; pointer to path 85
    FDB _ANGKOR_BG_PATH86        ; pointer to path 86
    FDB _ANGKOR_BG_PATH87        ; pointer to path 87
    FDB _ANGKOR_BG_PATH88        ; pointer to path 88
    FDB _ANGKOR_BG_PATH89        ; pointer to path 89
    FDB _ANGKOR_BG_PATH90        ; pointer to path 90
    FDB _ANGKOR_BG_PATH91        ; pointer to path 91
    FDB _ANGKOR_BG_PATH92        ; pointer to path 92
    FDB _ANGKOR_BG_PATH93        ; pointer to path 93
    FDB _ANGKOR_BG_PATH94        ; pointer to path 94
    FDB _ANGKOR_BG_PATH95        ; pointer to path 95
    FDB _ANGKOR_BG_PATH96        ; pointer to path 96
    FDB _ANGKOR_BG_PATH97        ; pointer to path 97
    FDB _ANGKOR_BG_PATH98        ; pointer to path 98
    FDB _ANGKOR_BG_PATH99        ; pointer to path 99
    FDB _ANGKOR_BG_PATH100        ; pointer to path 100
    FDB _ANGKOR_BG_PATH101        ; pointer to path 101
    FDB _ANGKOR_BG_PATH102        ; pointer to path 102
    FDB _ANGKOR_BG_PATH103        ; pointer to path 103
    FDB _ANGKOR_BG_PATH104        ; pointer to path 104
    FDB _ANGKOR_BG_PATH105        ; pointer to path 105
    FDB _ANGKOR_BG_PATH106        ; pointer to path 106
    FDB _ANGKOR_BG_PATH107        ; pointer to path 107
    FDB _ANGKOR_BG_PATH108        ; pointer to path 108
    FDB _ANGKOR_BG_PATH109        ; pointer to path 109
    FDB _ANGKOR_BG_PATH110        ; pointer to path 110
    FDB _ANGKOR_BG_PATH111        ; pointer to path 111
    FDB _ANGKOR_BG_PATH112        ; pointer to path 112
    FDB _ANGKOR_BG_PATH113        ; pointer to path 113
    FDB _ANGKOR_BG_PATH114        ; pointer to path 114
    FDB _ANGKOR_BG_PATH115        ; pointer to path 115
    FDB _ANGKOR_BG_PATH116        ; pointer to path 116
    FDB _ANGKOR_BG_PATH117        ; pointer to path 117
    FDB _ANGKOR_BG_PATH118        ; pointer to path 118
    FDB _ANGKOR_BG_PATH119        ; pointer to path 119
    FDB _ANGKOR_BG_PATH120        ; pointer to path 120
    FDB _ANGKOR_BG_PATH121        ; pointer to path 121
    FDB _ANGKOR_BG_PATH122        ; pointer to path 122
    FDB _ANGKOR_BG_PATH123        ; pointer to path 123
    FDB _ANGKOR_BG_PATH124        ; pointer to path 124
    FDB _ANGKOR_BG_PATH125        ; pointer to path 125
    FDB _ANGKOR_BG_PATH126        ; pointer to path 126
    FDB _ANGKOR_BG_PATH127        ; pointer to path 127
    FDB _ANGKOR_BG_PATH128        ; pointer to path 128
    FDB _ANGKOR_BG_PATH129        ; pointer to path 129
    FDB _ANGKOR_BG_PATH130        ; pointer to path 130
    FDB _ANGKOR_BG_PATH131        ; pointer to path 131
    FDB _ANGKOR_BG_PATH132        ; pointer to path 132
    FDB _ANGKOR_BG_PATH133        ; pointer to path 133
    FDB _ANGKOR_BG_PATH134        ; pointer to path 134
    FDB _ANGKOR_BG_PATH135        ; pointer to path 135
    FDB _ANGKOR_BG_PATH136        ; pointer to path 136
    FDB _ANGKOR_BG_PATH137        ; pointer to path 137
    FDB _ANGKOR_BG_PATH138        ; pointer to path 138

_ANGKOR_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FC,$00,0,0        ; path0: header (y=-4, x=0)
    FCB $FF,$F5,$F5          ; flag=-1, dy=-11, dx=-11
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$FE,$FB          ; flag=-1, dy=-2, dx=-5
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $E3,$F5,0,0        ; path1: header (y=-29, x=-11)
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB $FF,$12,$00          ; flag=-1, dy=18, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $F2,$F6,0,0        ; path2: header (y=-14, x=-10)
    FCB $FF,$02,$FD          ; flag=-1, dy=2, dx=-3
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$02,$04          ; flag=-1, dy=2, dx=4
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$03,$04          ; flag=-1, dy=3, dx=4
    FCB $FF,$00,$F5          ; flag=-1, dy=0, dx=-11
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $FD,$F5,0,0        ; path3: header (y=-3, x=-11)
    FCB $FF,$00,$E3          ; flag=-1, dy=0, dx=-29
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$00,$1D          ; flag=-1, dy=0, dx=29
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $06,$F5,0,0        ; path4: header (y=6, x=-11)
    FCB $FF,$01,$04          ; flag=-1, dy=1, dx=4
    FCB $FF,$05,$03          ; flag=-1, dy=5, dx=3
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $0B,$FB,0,0        ; path5: header (y=11, x=-5)
    FCB $FF,$00,$D3          ; flag=-1, dy=0, dx=-45
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $07,$CB,0,0        ; path6: header (y=7, x=-53)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $14,$CC,0,0        ; path7: header (y=20, x=-52)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $0E,$C7,0,0        ; path8: header (y=14, x=-57)
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $07,$C6,0,0        ; path9: header (y=7, x=-58)
    FCB $FF,$F0,$00          ; flag=-1, dy=-16, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $F7,$CE,0,0        ; path10: header (y=-9, x=-50)
    FCB $FF,$10,$00          ; flag=-1, dy=16, dx=0
    FCB $FF,$00,$E5          ; flag=-1, dy=0, dx=-27
    FCB $FF,$F0,$00          ; flag=-1, dy=-16, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $F7,$B9,0,0        ; path11: header (y=-9, x=-71)
    FCB $FF,$10,$00          ; flag=-1, dy=16, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $07,$B8,0,0        ; path12: header (y=7, x=-72)
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $0E,$B9,0,0        ; path13: header (y=14, x=-71)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $1C,$CB,0,0        ; path14: header (y=28, x=-53)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $16,$C6,0,0        ; path15: header (y=22, x=-58)
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $16,$C5,0,0        ; path16: header (y=22, x=-59)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$F5          ; flag=-1, dy=0, dx=-11
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $16,$B9,0,0        ; path17: header (y=22, x=-71)
    FCB $FF,$FE,$FA          ; flag=-1, dy=-2, dx=-6
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH18:    ; Path 18
    FCB 127              ; path18: intensity
    FCB $1C,$B4,0,0        ; path18: header (y=28, x=-76)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH19:    ; Path 19
    FCB 127              ; path19: intensity
    FCB $14,$B3,0,0        ; path19: header (y=20, x=-77)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH20:    ; Path 20
    FCB 127              ; path20: intensity
    FCB $12,$B1,0,0        ; path20: header (y=18, x=-79)
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$FE,$03          ; flag=-1, dy=-2, dx=3
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH21:    ; Path 21
    FCB 127              ; path21: intensity
    FCB $0C,$B1,0,0        ; path21: header (y=12, x=-79)
    FCB $FF,$02,$05          ; flag=-1, dy=2, dx=5
    FCB $FF,$00,$13          ; flag=-1, dy=0, dx=19
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH22:    ; Path 22
    FCB 127              ; path22: intensity
    FCB $07,$C2,0,0        ; path22: header (y=7, x=-62)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$02,$FD          ; flag=-1, dy=2, dx=-3
    FCB $FF,$FE,$FD          ; flag=-1, dy=-2, dx=-3
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH23:    ; Path 23
    FCB 127              ; path23: intensity
    FCB $04,$BC,0,0        ; path23: header (y=4, x=-68)
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB $FF,$00,$F9          ; flag=-1, dy=0, dx=-7
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH24:    ; Path 24
    FCB 127              ; path24: intensity
    FCB $F7,$BB,0,0        ; path24: header (y=-9, x=-69)
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH25:    ; Path 25
    FCB 127              ; path25: intensity
    FCB $E3,$BE,0,0        ; path25: header (y=-29, x=-66)
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH26:    ; Path 26
    FCB 127              ; path26: intensity
    FCB $D7,$CA,0,0        ; path26: header (y=-41, x=-54)
    FCB $FF,$0C,$00          ; flag=-1, dy=12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH27:    ; Path 27
    FCB 127              ; path27: intensity
    FCB $E3,$D8,0,0        ; path27: header (y=-29, x=-40)
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH28:    ; Path 28
    FCB 127              ; path28: intensity
    FCB $D7,$E5,0,0        ; path28: header (y=-41, x=-27)
    FCB $FF,$0C,$00          ; flag=-1, dy=12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH29:    ; Path 29
    FCB 127              ; path29: intensity
    FCB $E3,$EE,0,0        ; path29: header (y=-29, x=-18)
    FCB $FF,$00,$B6          ; flag=-1, dy=0, dx=-74
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$49          ; flag=-1, dy=0, dx=73
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH30:    ; Path 30
    FCB 127              ; path30: intensity
    FCB $E7,$EE,0,0        ; path30: header (y=-25, x=-18)
    FCB $FF,$F1,$00          ; flag=-1, dy=-15, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH31:    ; Path 31
    FCB 127              ; path31: intensity
    FCB $D8,$EC,0,0        ; path31: header (y=-40, x=-20)
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$FF,$09          ; flag=-1, dy=-1, dx=9
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH32:    ; Path 32
    FCB 127              ; path32: intensity
    FCB $D7,$EC,0,0        ; path32: header (y=-41, x=-20)
    FCB $FF,$00,$B4          ; flag=-1, dy=0, dx=-76
    FCB $FF,$F3,$00          ; flag=-1, dy=-13, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH33:    ; Path 33
    FCB 127              ; path33: intensity
    FCB $D2,$A0,0,0        ; path33: header (y=-46, x=-96)
    FCB $FF,$00,$4C          ; flag=-1, dy=0, dx=76
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH34:    ; Path 34
    FCB 127              ; path34: intensity
    FCB $D0,$EC,0,0        ; path34: header (y=-48, x=-20)
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB $FF,$00,$0B          ; flag=-1, dy=0, dx=11
    FCB $FF,$0E,$00          ; flag=-1, dy=14, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH35:    ; Path 35
    FCB 127              ; path35: intensity
    FCB $D1,$F6,0,0        ; path35: header (y=-47, x=-10)
    FCB $FF,$00,$14          ; flag=-1, dy=0, dx=20
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH36:    ; Path 36
    FCB 127              ; path36: intensity
    FCB $D4,$09,0,0        ; path36: header (y=-44, x=9)
    FCB $FF,$00,$EE          ; flag=-1, dy=0, dx=-18
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH37:    ; Path 37
    FCB 127              ; path37: intensity
    FCB $CC,$F4,0,0        ; path37: header (y=-52, x=-12)
    FCB $FF,$00,$18          ; flag=-1, dy=0, dx=24
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH38:    ; Path 38
    FCB 127              ; path38: intensity
    FCB $D0,$0F,0,0        ; path38: header (y=-48, x=15)
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB $FF,$00,$0B          ; flag=-1, dy=0, dx=11
    FCB $FF,$0E,$00          ; flag=-1, dy=14, dx=0
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH39:    ; Path 39
    FCB 127              ; path39: intensity
    FCB $D2,$14,0,0        ; path39: header (y=-46, x=20)
    FCB $FF,$00,$4C          ; flag=-1, dy=0, dx=76
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH40:    ; Path 40
    FCB 127              ; path40: intensity
    FCB $D7,$5B,0,0        ; path40: header (y=-41, x=91)
    FCB $FF,$0C,$00          ; flag=-1, dy=12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH41:    ; Path 41
    FCB 127              ; path41: intensity
    FCB $E3,$5C,0,0        ; path41: header (y=-29, x=92)
    FCB $FF,$00,$B6          ; flag=-1, dy=0, dx=-74
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH42:    ; Path 42
    FCB 127              ; path42: intensity
    FCB $E7,$12,0,0        ; path42: header (y=-25, x=18)
    FCB $FF,$F1,$00          ; flag=-1, dy=-15, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH43:    ; Path 43
    FCB 127              ; path43: intensity
    FCB $D8,$14,0,0        ; path43: header (y=-40, x=20)
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$FF,$F7          ; flag=-1, dy=-1, dx=-9
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH44:    ; Path 44
    FCB 127              ; path44: intensity
    FCB $D7,$14,0,0        ; path44: header (y=-41, x=20)
    FCB $FF,$00,$4C          ; flag=-1, dy=0, dx=76
    FCB $FF,$F3,$00          ; flag=-1, dy=-13, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH45:    ; Path 45
    FCB 127              ; path45: intensity
    FCB $D7,$4F,0,0        ; path45: header (y=-41, x=79)
    FCB $FF,$0C,$00          ; flag=-1, dy=12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH46:    ; Path 46
    FCB 127              ; path46: intensity
    FCB $E9,$57,0,0        ; path46: header (y=-23, x=87)
    FCB $FF,$0E,$00          ; flag=-1, dy=14, dx=0
    FCB $FF,$00,$CF          ; flag=-1, dy=0, dx=-49
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH47:    ; Path 47
    FCB 127              ; path47: intensity
    FCB $FD,$26,0,0        ; path47: header (y=-3, x=38)
    FCB $FF,$EC,$00          ; flag=-1, dy=-20, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH48:    ; Path 48
    FCB 127              ; path48: intensity
    FCB $E3,$28,0,0        ; path48: header (y=-29, x=40)
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH49:    ; Path 49
    FCB 127              ; path49: intensity
    FCB $D7,$1B,0,0        ; path49: header (y=-41, x=27)
    FCB $FF,$0C,$00          ; flag=-1, dy=12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH50:    ; Path 50
    FCB 127              ; path50: intensity
    FCB $E9,$13,0,0        ; path50: header (y=-23, x=19)
    FCB $FF,$00,$49          ; flag=-1, dy=0, dx=73
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH51:    ; Path 51
    FCB 127              ; path51: intensity
    FCB $F2,$57,0,0        ; path51: header (y=-14, x=87)
    FCB $FF,$00,$B6          ; flag=-1, dy=0, dx=-74
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH52:    ; Path 52
    FCB 127              ; path52: intensity
    FCB $F1,$0B,0,0        ; path52: header (y=-15, x=11)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH53:    ; Path 53
    FCB 127              ; path53: intensity
    FCB $E3,$0B,0,0        ; path53: header (y=-29, x=11)
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB $FF,$12,$00          ; flag=-1, dy=18, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH54:    ; Path 54
    FCB 127              ; path54: intensity
    FCB $F1,$0B,0,0        ; path54: header (y=-15, x=11)
    FCB $FF,$0B,$F5          ; flag=-1, dy=11, dx=-11
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH55:    ; Path 55
    FCB 127              ; path55: intensity
    FCB $01,$00,0,0        ; path55: header (y=1, x=0)
    FCB $FF,$00,$0B          ; flag=-1, dy=0, dx=11
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH56:    ; Path 56
    FCB 127              ; path56: intensity
    FCB $FD,$0B,0,0        ; path56: header (y=-3, x=11)
    FCB $FF,$00,$1D          ; flag=-1, dy=0, dx=29
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$00,$E3          ; flag=-1, dy=0, dx=-29
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH57:    ; Path 57
    FCB 127              ; path57: intensity
    FCB $06,$0B,0,0        ; path57: header (y=6, x=11)
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB $FF,$05,$FD          ; flag=-1, dy=5, dx=-3
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH58:    ; Path 58
    FCB 127              ; path58: intensity
    FCB $0B,$05,0,0        ; path58: header (y=11, x=5)
    FCB $FF,$00,$2D          ; flag=-1, dy=0, dx=45
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH59:    ; Path 59
    FCB 127              ; path59: intensity
    FCB $07,$35,0,0        ; path59: header (y=7, x=53)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$02,$FD          ; flag=-1, dy=2, dx=-3
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH60:    ; Path 60
    FCB 127              ; path60: intensity
    FCB $14,$34,0,0        ; path60: header (y=20, x=52)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH61:    ; Path 61
    FCB 127              ; path61: intensity
    FCB $0E,$39,0,0        ; path61: header (y=14, x=57)
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH62:    ; Path 62
    FCB 127              ; path62: intensity
    FCB $07,$3A,0,0        ; path62: header (y=7, x=58)
    FCB $FF,$F0,$00          ; flag=-1, dy=-16, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH63:    ; Path 63
    FCB 127              ; path63: intensity
    FCB $F7,$32,0,0        ; path63: header (y=-9, x=50)
    FCB $FF,$10,$00          ; flag=-1, dy=16, dx=0
    FCB $FF,$00,$1B          ; flag=-1, dy=0, dx=27
    FCB $FF,$F0,$00          ; flag=-1, dy=-16, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH64:    ; Path 64
    FCB 127              ; path64: intensity
    FCB $F7,$47,0,0        ; path64: header (y=-9, x=71)
    FCB $FF,$10,$00          ; flag=-1, dy=16, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH65:    ; Path 65
    FCB 127              ; path65: intensity
    FCB $07,$48,0,0        ; path65: header (y=7, x=72)
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH66:    ; Path 66
    FCB 127              ; path66: intensity
    FCB $0E,$47,0,0        ; path66: header (y=14, x=71)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$FE,$FB          ; flag=-1, dy=-2, dx=-5
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH67:    ; Path 67
    FCB 127              ; path67: intensity
    FCB $1C,$35,0,0        ; path67: header (y=28, x=53)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH68:    ; Path 68
    FCB 127              ; path68: intensity
    FCB $16,$3A,0,0        ; path68: header (y=22, x=58)
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH69:    ; Path 69
    FCB 127              ; path69: intensity
    FCB $16,$3B,0,0        ; path69: header (y=22, x=59)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$0B          ; flag=-1, dy=0, dx=11
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH70:    ; Path 70
    FCB 127              ; path70: intensity
    FCB $16,$47,0,0        ; path70: header (y=22, x=71)
    FCB $FF,$FE,$06          ; flag=-1, dy=-2, dx=6
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH71:    ; Path 71
    FCB 127              ; path71: intensity
    FCB $1C,$4C,0,0        ; path71: header (y=28, x=76)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH72:    ; Path 72
    FCB 127              ; path72: intensity
    FCB $14,$4D,0,0        ; path72: header (y=20, x=77)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH73:    ; Path 73
    FCB 127              ; path73: intensity
    FCB $12,$4F,0,0        ; path73: header (y=18, x=79)
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$FE,$FD          ; flag=-1, dy=-2, dx=-3
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH74:    ; Path 74
    FCB 127              ; path74: intensity
    FCB $0C,$4F,0,0        ; path74: header (y=12, x=79)
    FCB $FF,$02,$FB          ; flag=-1, dy=2, dx=-5
    FCB $FF,$00,$ED          ; flag=-1, dy=0, dx=-19
    FCB $FF,$FE,$FB          ; flag=-1, dy=-2, dx=-5
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH75:    ; Path 75
    FCB 127              ; path75: intensity
    FCB $07,$3E,0,0        ; path75: header (y=7, x=62)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$FE,$03          ; flag=-1, dy=-2, dx=3
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH76:    ; Path 76
    FCB 127              ; path76: intensity
    FCB $04,$44,0,0        ; path76: header (y=4, x=68)
    FCB $FF,$00,$F9          ; flag=-1, dy=0, dx=-7
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH77:    ; Path 77
    FCB 127              ; path77: intensity
    FCB $F7,$45,0,0        ; path77: header (y=-9, x=69)
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH78:    ; Path 78
    FCB 127              ; path78: intensity
    FCB $E3,$42,0,0        ; path78: header (y=-29, x=66)
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH79:    ; Path 79
    FCB 127              ; path79: intensity
    FCB $D7,$36,0,0        ; path79: header (y=-41, x=54)
    FCB $FF,$0C,$00          ; flag=-1, dy=12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH80:    ; Path 80
    FCB 127              ; path80: intensity
    FCB $F2,$0A,0,0        ; path80: header (y=-14, x=10)
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$02,$FC          ; flag=-1, dy=2, dx=-4
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$03,$FC          ; flag=-1, dy=3, dx=-4
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH81:    ; Path 81
    FCB 127              ; path81: intensity
    FCB $0C,$00,0,0        ; path81: header (y=12, x=0)
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH82:    ; Path 82
    FCB 127              ; path82: intensity
    FCB $11,$FD,0,0        ; path82: header (y=17, x=-3)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH83:    ; Path 83
    FCB 127              ; path83: intensity
    FCB $10,$06,0,0        ; path83: header (y=16, x=6)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH84:    ; Path 84
    FCB 127              ; path84: intensity
    FCB $10,$0B,0,0        ; path84: header (y=16, x=11)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$03,$03          ; flag=-1, dy=3, dx=3
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH85:    ; Path 85
    FCB 127              ; path85: intensity
    FCB $21,$0D,0,0        ; path85: header (y=33, x=13)
    FCB $FF,$FA,$FD          ; flag=-1, dy=-6, dx=-3
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH86:    ; Path 86
    FCB 127              ; path86: intensity
    FCB $1A,$08,0,0        ; path86: header (y=26, x=8)
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH87:    ; Path 87
    FCB 127              ; path87: intensity
    FCB $1A,$07,0,0        ; path87: header (y=26, x=7)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$FF,$06          ; flag=-1, dy=-1, dx=6
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH88:    ; Path 88
    FCB 127              ; path88: intensity
    FCB $28,$0B,0,0        ; path88: header (y=40, x=11)
    FCB $FF,$FC,$FE          ; flag=-1, dy=-4, dx=-2
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH89:    ; Path 89
    FCB 127              ; path89: intensity
    FCB $22,$07,0,0        ; path89: header (y=34, x=7)
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH90:    ; Path 90
    FCB 127              ; path90: intensity
    FCB $22,$FB,0,0        ; path90: header (y=34, x=-5)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH91:    ; Path 91
    FCB 127              ; path91: intensity
    FCB $2A,$05,0,0        ; path91: header (y=42, x=5)
    FCB $FF,$FE,$06          ; flag=-1, dy=-2, dx=6
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH92:    ; Path 92
    FCB 127              ; path92: intensity
    FCB $30,$08,0,0        ; path92: header (y=48, x=8)
    FCB $FF,$FB,$FE          ; flag=-1, dy=-5, dx=-2
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH93:    ; Path 93
    FCB 127              ; path93: intensity
    FCB $2A,$04,0,0        ; path93: header (y=42, x=4)
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH94:    ; Path 94
    FCB 127              ; path94: intensity
    FCB $2A,$FB,0,0        ; path94: header (y=42, x=-5)
    FCB $FF,$FE,$FA          ; flag=-1, dy=-2, dx=-6
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH95:    ; Path 95
    FCB 127              ; path95: intensity
    FCB $30,$F8,0,0        ; path95: header (y=48, x=-8)
    FCB $FF,$FB,$02          ; flag=-1, dy=-5, dx=2
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH96:    ; Path 96
    FCB 127              ; path96: intensity
    FCB $28,$F5,0,0        ; path96: header (y=40, x=-11)
    FCB $FF,$FC,$02          ; flag=-1, dy=-4, dx=2
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH97:    ; Path 97
    FCB 127              ; path97: intensity
    FCB $25,$F3,0,0        ; path97: header (y=37, x=-13)
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$01,$06          ; flag=-1, dy=1, dx=6
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH98:    ; Path 98
    FCB 127              ; path98: intensity
    FCB $1A,$F8,0,0        ; path98: header (y=26, x=-8)
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH99:    ; Path 99
    FCB 127              ; path99: intensity
    FCB $10,$FA,0,0        ; path99: header (y=16, x=-6)
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH100:    ; Path 100
    FCB 127              ; path100: intensity
    FCB $10,$F5,0,0        ; path100: header (y=16, x=-11)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$03,$FD          ; flag=-1, dy=3, dx=-3
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH101:    ; Path 101
    FCB 127              ; path101: intensity
    FCB $21,$F3,0,0        ; path101: header (y=33, x=-13)
    FCB $FF,$FA,$03          ; flag=-1, dy=-6, dx=3
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH102:    ; Path 102
    FCB 127              ; path102: intensity
    FCB $18,$F2,0,0        ; path102: header (y=24, x=-14)
    FCB $FF,$02,$05          ; flag=-1, dy=2, dx=5
    FCB $FF,$00,$12          ; flag=-1, dy=0, dx=18
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH103:    ; Path 103
    FCB 127              ; path103: intensity
    FCB $F4,$00,0,0        ; path103: header (y=-12, x=0)
    FCB $FF,$FF,$FC          ; flag=-1, dy=-1, dx=-4
    FCB $FF,$FC,$FD          ; flag=-1, dy=-4, dx=-3
    FCB $FF,$E9,$00          ; flag=-1, dy=-23, dx=0
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB $FF,$17,$00          ; flag=-1, dy=23, dx=0
    FCB $FF,$04,$FD          ; flag=-1, dy=4, dx=-3
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH104:    ; Path 104
    FCB 127              ; path104: intensity
    FCB $F2,$F3,0,0        ; path104: header (y=-14, x=-13)
    FCB $FF,$00,$B6          ; flag=-1, dy=0, dx=-74
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH105:    ; Path 105
    FCB 127              ; path105: intensity
    FCB $E9,$A9,0,0        ; path105: header (y=-23, x=-87)
    FCB $FF,$0E,$00          ; flag=-1, dy=14, dx=0
    FCB $FF,$00,$31          ; flag=-1, dy=0, dx=49
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH106:    ; Path 106
    FCB 127              ; path106: intensity
    FCB $FD,$DA,0,0        ; path106: header (y=-3, x=-38)
    FCB $FF,$EC,$00          ; flag=-1, dy=-20, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH107:    ; Path 107
    FCB 127              ; path107: intensity
    FCB $E3,$B1,0,0        ; path107: header (y=-29, x=-79)
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH108:    ; Path 108
    FCB 127              ; path108: intensity
    FCB $D7,$A5,0,0        ; path108: header (y=-41, x=-91)
    FCB $FF,$0C,$00          ; flag=-1, dy=12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH109:    ; Path 109
    FCB 127              ; path109: intensity
    FCB $1E,$B9,0,0        ; path109: header (y=30, x=-71)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH110:    ; Path 110
    FCB 127              ; path110: intensity
    FCB $24,$B9,0,0        ; path110: header (y=36, x=-71)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$0D          ; flag=-1, dy=0, dx=13
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH111:    ; Path 111
    FCB 127              ; path111: intensity
    FCB $23,$C8,0,0        ; path111: header (y=35, x=-56)
    FCB $FF,$00,$EF          ; flag=-1, dy=0, dx=-17
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH112:    ; Path 112
    FCB 127              ; path112: intensity
    FCB $21,$B4,0,0        ; path112: header (y=33, x=-76)
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$02,$06          ; flag=-1, dy=2, dx=6
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH113:    ; Path 113
    FCB 127              ; path113: intensity
    FCB $1E,$BC,0,0        ; path113: header (y=30, x=-68)
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH114:    ; Path 114
    FCB 127              ; path114: intensity
    FCB $29,$BA,0,0        ; path114: header (y=41, x=-70)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$0B          ; flag=-1, dy=0, dx=11
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH115:    ; Path 115
    FCB 127              ; path115: intensity
    FCB $27,$C8,0,0        ; path115: header (y=39, x=-56)
    FCB $FF,$F7,$FE          ; flag=-1, dy=-9, dx=-2
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH116:    ; Path 116
    FCB 127              ; path116: intensity
    FCB $1E,$C5,0,0        ; path116: header (y=30, x=-59)
    FCB $FF,$FE,$06          ; flag=-1, dy=-2, dx=6
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH117:    ; Path 117
    FCB 127              ; path117: intensity
    FCB $1E,$C3,0,0        ; path117: header (y=30, x=-61)
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH118:    ; Path 118
    FCB 127              ; path118: intensity
    FCB $2D,$C3,0,0        ; path118: header (y=45, x=-61)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$F9          ; flag=-1, dy=0, dx=-7
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH119:    ; Path 119
    FCB 127              ; path119: intensity
    FCB $30,$BD,0,0        ; path119: header (y=48, x=-67)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH120:    ; Path 120
    FCB 127              ; path120: intensity
    FCB $33,$F8,0,0        ; path120: header (y=51, x=-8)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$01,$04          ; flag=-1, dy=1, dx=4
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH121:    ; Path 121
    FCB 127              ; path121: intensity
    FCB $31,$FA,0,0        ; path121: header (y=49, x=-6)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH122:    ; Path 122
    FCB 127              ; path122: intensity
    FCB $31,$04,0,0        ; path122: header (y=49, x=4)
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH123:    ; Path 123
    FCB 127              ; path123: intensity
    FCB $36,$05,0,0        ; path123: header (y=54, x=5)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH124:    ; Path 124
    FCB 127              ; path124: intensity
    FCB $3A,$FD,0,0        ; path124: header (y=58, x=-3)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH125:    ; Path 125
    FCB 127              ; path125: intensity
    FCB $3D,$02,0,0        ; path125: header (y=61, x=2)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH126:    ; Path 126
    FCB 127              ; path126: intensity
    FCB $27,$38,0,0        ; path126: header (y=39, x=56)
    FCB $FF,$F7,$02          ; flag=-1, dy=-9, dx=2
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH127:    ; Path 127
    FCB 127              ; path127: intensity
    FCB $1E,$3B,0,0        ; path127: header (y=30, x=59)
    FCB $FF,$FE,$FA          ; flag=-1, dy=-2, dx=-6
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH128:    ; Path 128
    FCB 127              ; path128: intensity
    FCB $23,$38,0,0        ; path128: header (y=35, x=56)
    FCB $FF,$00,$11          ; flag=-1, dy=0, dx=17
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH129:    ; Path 129
    FCB 127              ; path129: intensity
    FCB $24,$47,0,0        ; path129: header (y=36, x=71)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$F3          ; flag=-1, dy=0, dx=-13
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH130:    ; Path 130
    FCB 127              ; path130: intensity
    FCB $24,$3D,0,0        ; path130: header (y=36, x=61)
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH131:    ; Path 131
    FCB 127              ; path131: intensity
    FCB $1E,$44,0,0        ; path131: header (y=30, x=68)
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH132:    ; Path 132
    FCB 127              ; path132: intensity
    FCB $29,$46,0,0        ; path132: header (y=41, x=70)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$F5          ; flag=-1, dy=0, dx=-11
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH133:    ; Path 133
    FCB 127              ; path133: intensity
    FCB $2D,$3D,0,0        ; path133: header (y=45, x=61)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH134:    ; Path 134
    FCB 127              ; path134: intensity
    FCB $30,$43,0,0        ; path134: header (y=48, x=67)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH135:    ; Path 135
    FCB 127              ; path135: intensity
    FCB $27,$49,0,0        ; path135: header (y=39, x=73)
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH136:    ; Path 136
    FCB 127              ; path136: intensity
    FCB $1E,$46,0,0        ; path136: header (y=30, x=70)
    FCB $FF,$FE,$06          ; flag=-1, dy=-2, dx=6
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH137:    ; Path 137
    FCB 127              ; path137: intensity
    FCB $C7,$0D,0,0        ; path137: header (y=-57, x=13)
    FCB $FF,$00,$E6          ; flag=-1, dy=0, dx=-26
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH138:    ; Path 138
    FCB 127              ; path138: intensity
    FCB $C0,$F2,0,0        ; path138: header (y=-64, x=-14)
    FCB $FF,$00,$1C          ; flag=-1, dy=0, dx=28
    FCB 2                ; End marker (path complete)
; Generated from antarctica_bg.vec (Malban Draw_Sync_List format)
; Total paths: 20, points: 91
; X bounds: min=-119, max=104, width=223
; Center: (-7, 46)

_ANTARCTICA_BG_WIDTH EQU 223
_ANTARCTICA_BG_HALF_WIDTH EQU 111
_ANTARCTICA_BG_HEIGHT EQU 93
_ANTARCTICA_BG_HALF_HEIGHT EQU 46
_ANTARCTICA_BG_CENTER_X EQU -7
_ANTARCTICA_BG_CENTER_Y EQU 46

_ANTARCTICA_BG_VECTORS:  ; Main entry (header + 17 path(s))
    FDB 17               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _ANTARCTICA_BG_PATH0        ; pointer to path 0
    FDB _ANTARCTICA_BG_PATH1        ; pointer to path 1
    FDB _ANTARCTICA_BG_PATH2        ; pointer to path 2
    FDB _ANTARCTICA_BG_PATH3        ; pointer to path 3
    FDB _ANTARCTICA_BG_PATH4        ; pointer to path 4
    FDB _ANTARCTICA_BG_PATH5        ; pointer to path 5
    FDB _ANTARCTICA_BG_PATH6        ; pointer to path 6
    FDB _ANTARCTICA_BG_PATH7        ; pointer to path 7
    FDB _ANTARCTICA_BG_PATH8        ; pointer to path 8
    FDB _ANTARCTICA_BG_PATH9        ; pointer to path 9
    FDB _ANTARCTICA_BG_PATH10        ; pointer to path 10
    FDB _ANTARCTICA_BG_PATH11        ; pointer to path 11
    FDB _ANTARCTICA_BG_PATH12        ; pointer to path 12
    FDB _ANTARCTICA_BG_PATH13        ; pointer to path 13
    FDB _ANTARCTICA_BG_PATH14        ; pointer to path 14
    FDB _ANTARCTICA_BG_PATH15        ; pointer to path 15
    FDB _ANTARCTICA_BG_PATH16        ; pointer to path 16

_ANTARCTICA_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $E9,$1A,0,0        ; path0: header (y=-23, x=26)
    FCB $FF,$09,$EB          ; flag=-1, dy=9, dx=-21
    FCB $FF,$F0,$D6          ; flag=-1, dy=-16, dx=-42
    FCB $FF,$F1,$FB          ; flag=-1, dy=-15, dx=-5
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $F7,$F3,0,0        ; path1: header (y=-9, x=-13)
    FCB $FF,$13,$FB          ; flag=-1, dy=19, dx=-5
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB $FF,$0F,$F8          ; flag=-1, dy=15, dx=-8
    FCB $FF,$02,$EF          ; flag=-1, dy=2, dx=-17
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $EF,$FD,0,0        ; path2: header (y=-17, x=-3)
    FCB $FF,$07,$F8          ; flag=-1, dy=7, dx=-8
    FCB $FF,$0A,$EA          ; flag=-1, dy=10, dx=-22
    FCB $FF,$E9,$DE          ; flag=-1, dy=-23, dx=-34
    FCB $FF,$FD,$DF          ; flag=-1, dy=-3, dx=-33
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $D3,$90,0,0        ; path3: header (y=-45, x=-112)
    FCB $FF,$00,$4C          ; sub-seg 1/2 of line 0: dy=0, dx=76
    FCB $FF,$00,$4D          ; sub-seg 2/2 of line 0: dy=0, dx=77
    FCB $FF,$41,$D5          ; flag=-1, dy=65, dx=-43
    FCB $FF,$FA,$F9          ; flag=-1, dy=-6, dx=-7
    FCB $FF,$21,$E4          ; flag=-1, dy=33, dx=-28
    FCB $FF,$DF,$E7          ; flag=-1, dy=-33, dx=-25
    FCB $FF,$07,$F7          ; flag=-1, dy=7, dx=-9
    FCB $FF,$BE,$D7          ; flag=-1, dy=-66, dx=-41
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $D9,$33,0,0        ; path4: header (y=-39, x=51)
    FCB $FF,$09,$06          ; flag=-1, dy=9, dx=6
    FCB $FF,$02,$05          ; flag=-1, dy=2, dx=5
    FCB $FF,$FA,$06          ; flag=-1, dy=-6, dx=6
    FCB $FF,$F4,$01          ; flag=-1, dy=-12, dx=1
    FCB $FF,$02,$FD          ; flag=-1, dy=2, dx=-3
    FCB $FF,$0C,$FC          ; flag=-1, dy=12, dx=-4
    FCB $FF,$FE,$FB          ; flag=-1, dy=-2, dx=-5
    FCB $FF,$FA,$FC          ; flag=-1, dy=-6, dx=-4
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $D9,$33,0,0        ; path5: header (y=-39, x=51)
    FCB $FF,$F9,$12          ; flag=-1, dy=-7, dx=18
    FCB $FF,$04,$07          ; flag=-1, dy=4, dx=7
    FCB $FF,$01,$1B          ; flag=-1, dy=1, dx=27
    FCB $FF,$03,$08          ; flag=-1, dy=3, dx=8
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$0A,$FB          ; flag=-1, dy=10, dx=-5
    FCB $FF,$06,$FC          ; flag=-1, dy=6, dx=-4
    FCB $FF,$04,$F8          ; flag=-1, dy=4, dx=-8
    FCB $FF,$00,$EE          ; flag=-1, dy=0, dx=-18
    FCB $FF,$F6,$F4          ; flag=-1, dy=-10, dx=-12
    FCB $FF,$F4,$F9          ; flag=-1, dy=-12, dx=-7
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $E4,$3E,0,0        ; path6: header (y=-28, x=62)
    FCB $FF,$02,$09          ; flag=-1, dy=2, dx=9
    FCB $FF,$FD,$03          ; flag=-1, dy=-3, dx=3
    FCB $FF,$FA,$02          ; flag=-1, dy=-6, dx=2
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $D6,$51,0,0        ; path7: header (y=-42, x=81)
    FCB $FF,$0B,$02          ; flag=-1, dy=11, dx=2
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $E1,$58,0,0        ; path8: header (y=-31, x=88)
    FCB $FF,$0B,$01          ; flag=-1, dy=11, dx=1
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $EB,$51,0,0        ; path9: header (y=-21, x=81)
    FCB $FF,$0A,$01          ; flag=-1, dy=10, dx=1
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $F6,$49,0,0        ; path10: header (y=-10, x=73)
    FCB $FF,$FF,$09          ; flag=-1, dy=-1, dx=9
    FCB $FF,$02,$0E          ; flag=-1, dy=2, dx=14
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $F6,$5B,0,0        ; path11: header (y=-10, x=91)
    FCB $FF,$F8,$07          ; flag=-1, dy=-8, dx=7
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $EE,$65,0,0        ; path12: header (y=-18, x=101)
    FCB $FF,$F5,$06          ; flag=-1, dy=-11, dx=6
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $E4,$6F,0,0        ; path13: header (y=-28, x=111)
    FCB $FF,$FC,$DC          ; flag=-1, dy=-4, dx=-36
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $E6,$47,0,0        ; path14: header (y=-26, x=71)
    FCB $FF,$05,$02          ; flag=-1, dy=5, dx=2
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $EC,$3F,0,0        ; path15: header (y=-20, x=63)
    FCB $FF,$FF,$15          ; flag=-1, dy=-1, dx=21
    FCB $FF,$04,$15          ; flag=-1, dy=4, dx=21
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $E2,$60,0,0        ; path16: header (y=-30, x=96)
    FCB $FF,$F5,$05          ; flag=-1, dy=-11, dx=5
    FCB 2                ; End marker (path complete)
; Generated from athens_bg.vec (Malban Draw_Sync_List format)
; Total paths: 41, points: 147
; X bounds: min=-80, max=80, width=160
; Center: (0, 0)

_ATHENS_BG_WIDTH EQU 160
_ATHENS_BG_HALF_WIDTH EQU 80
_ATHENS_BG_HEIGHT EQU 150
_ATHENS_BG_HALF_HEIGHT EQU 75
_ATHENS_BG_CENTER_X EQU 0
_ATHENS_BG_CENTER_Y EQU 0

_ATHENS_BG_VECTORS:  ; Main entry (header + 33 path(s))
    FDB 33               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _ATHENS_BG_PATH0        ; pointer to path 0
    FDB _ATHENS_BG_PATH1        ; pointer to path 1
    FDB _ATHENS_BG_PATH2        ; pointer to path 2
    FDB _ATHENS_BG_PATH3        ; pointer to path 3
    FDB _ATHENS_BG_PATH4        ; pointer to path 4
    FDB _ATHENS_BG_PATH5        ; pointer to path 5
    FDB _ATHENS_BG_PATH6        ; pointer to path 6
    FDB _ATHENS_BG_PATH7        ; pointer to path 7
    FDB _ATHENS_BG_PATH8        ; pointer to path 8
    FDB _ATHENS_BG_PATH9        ; pointer to path 9
    FDB _ATHENS_BG_PATH10        ; pointer to path 10
    FDB _ATHENS_BG_PATH11        ; pointer to path 11
    FDB _ATHENS_BG_PATH12        ; pointer to path 12
    FDB _ATHENS_BG_PATH13        ; pointer to path 13
    FDB _ATHENS_BG_PATH14        ; pointer to path 14
    FDB _ATHENS_BG_PATH15        ; pointer to path 15
    FDB _ATHENS_BG_PATH16        ; pointer to path 16
    FDB _ATHENS_BG_PATH17        ; pointer to path 17
    FDB _ATHENS_BG_PATH18        ; pointer to path 18
    FDB _ATHENS_BG_PATH19        ; pointer to path 19
    FDB _ATHENS_BG_PATH20        ; pointer to path 20
    FDB _ATHENS_BG_PATH21        ; pointer to path 21
    FDB _ATHENS_BG_PATH22        ; pointer to path 22
    FDB _ATHENS_BG_PATH23        ; pointer to path 23
    FDB _ATHENS_BG_PATH24        ; pointer to path 24
    FDB _ATHENS_BG_PATH25        ; pointer to path 25
    FDB _ATHENS_BG_PATH26        ; pointer to path 26
    FDB _ATHENS_BG_PATH27        ; pointer to path 27
    FDB _ATHENS_BG_PATH28        ; pointer to path 28
    FDB _ATHENS_BG_PATH29        ; pointer to path 29
    FDB _ATHENS_BG_PATH30        ; pointer to path 30
    FDB _ATHENS_BG_PATH31        ; pointer to path 31
    FDB _ATHENS_BG_PATH32        ; pointer to path 32

_ATHENS_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $0A,$ED,0,0        ; path0: header (y=10, x=-19)
    FCB $FF,$C5,$00          ; flag=-1, dy=-59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $CD,$EE,0,0        ; path1: header (y=-51, x=-18)
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $CF,$E3,0,0        ; path2: header (y=-49, x=-29)
    FCB $FF,$3B,$00          ; flag=-1, dy=59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $0C,$E2,0,0        ; path3: header (y=12, x=-30)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $0F,$F0,0,0        ; path4: header (y=15, x=-16)
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $0F,$D8,0,0        ; path5: header (y=15, x=-40)
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $0C,$CA,0,0        ; path6: header (y=12, x=-54)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $0A,$D5,0,0        ; path7: header (y=10, x=-43)
    FCB $FF,$C5,$00          ; flag=-1, dy=-59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $CD,$D6,0,0        ; path8: header (y=-51, x=-42)
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $CF,$CB,0,0        ; path9: header (y=-49, x=-53)
    FCB $FF,$3B,$00          ; flag=-1, dy=59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $14,$C6,0,0        ; path10: header (y=20, x=-58)
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$00,$7A          ; flag=-1, dy=0, dx=122
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $0F,$36,0,0        ; path11: header (y=15, x=54)
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $0C,$28,0,0        ; path12: header (y=12, x=40)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $0A,$33,0,0        ; path13: header (y=10, x=51)
    FCB $FF,$C5,$00          ; flag=-1, dy=-59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $CD,$34,0,0        ; path14: header (y=-51, x=52)
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $CF,$29,0,0        ; path15: header (y=-49, x=41)
    FCB $FF,$3B,$00          ; flag=-1, dy=59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $0F,$22,0,0        ; path16: header (y=15, x=34)
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $0C,$14,0,0        ; path17: header (y=12, x=20)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH18:    ; Path 18
    FCB 127              ; path18: intensity
    FCB $0A,$1F,0,0        ; path18: header (y=10, x=31)
    FCB $FF,$C5,$00          ; flag=-1, dy=-59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH19:    ; Path 19
    FCB 127              ; path19: intensity
    FCB $CD,$20,0,0        ; path19: header (y=-51, x=32)
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH20:    ; Path 20
    FCB 127              ; path20: intensity
    FCB $CF,$15,0,0        ; path20: header (y=-49, x=21)
    FCB $FF,$3B,$00          ; flag=-1, dy=59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH21:    ; Path 21
    FCB 127              ; path21: intensity
    FCB $1F,$39,0,0        ; path21: header (y=31, x=57)
    FCB $FF,$F5,$FF          ; flag=-1, dy=-11, dx=-1
    FCB $FF,$00,$8E          ; flag=-1, dy=0, dx=-114
    FCB $FF,$0B,$00          ; flag=-1, dy=11, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH22:    ; Path 22
    FCB 127              ; path22: intensity
    FCB $26,$C3,0,0        ; path22: header (y=38, x=-61)
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB $FF,$00,$78          ; flag=-1, dy=0, dx=120
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH23:    ; Path 23
    FCB 127              ; path23: intensity
    FCB $26,$38,0,0        ; path23: header (y=38, x=56)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH24:    ; Path 24
    FCB 127              ; path24: intensity
    FCB $CA,$26,0,0        ; path24: header (y=-54, x=38)
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH25:    ; Path 25
    FCB 127              ; path25: intensity
    FCB $C4,$44,0,0        ; path25: header (y=-60, x=68)
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$BD          ; sub-seg 1/2 of line 1: dy=0, dx=-67
    FCB $FF,$00,$BC          ; sub-seg 2/2 of line 1: dy=0, dx=-68
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH26:    ; Path 26
    FCB 127              ; path26: intensity
    FCB $BC,$B7,0,0        ; path26: header (y=-68, x=-73)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$49          ; sub-seg 1/2 of line 1: dy=0, dx=73
    FCB $FF,$00,$49          ; sub-seg 2/2 of line 1: dy=0, dx=73
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH27:    ; Path 27
    FCB 127              ; path27: intensity
    FCB $CA,$22,0,0        ; path27: header (y=-54, x=34)
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH28:    ; Path 28
    FCB 127              ; path28: intensity
    FCB $CA,$F0,0,0        ; path28: header (y=-54, x=-16)
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH29:    ; Path 29
    FCB 127              ; path29: intensity
    FCB $CA,$D8,0,0        ; path29: header (y=-54, x=-40)
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH30:    ; Path 30
    FCB 127              ; path30: intensity
    FCB $B5,$B0,0,0        ; path30: header (y=-75, x=-80)
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB $FF,$00,$50          ; sub-seg 1/2 of line 1: dy=0, dx=80
    FCB $FF,$00,$50          ; sub-seg 2/2 of line 1: dy=0, dx=80
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB $FF,$00,$B0          ; sub-seg 1/2 of line 3: dy=0, dx=-80
    FCB $FF,$00,$B0          ; sub-seg 2/2 of line 3: dy=0, dx=-80
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH31:    ; Path 31
    FCB 127              ; path31: intensity
    FCB $26,$C1,0,0        ; path31: header (y=38, x=-63)
    FCB $FF,$25,$3E          ; flag=-1, dy=37, dx=62
    FCB $FF,$DB,$3F          ; flag=-1, dy=-37, dx=63
    FCB $FF,$00,$83          ; flag=-1, dy=0, dx=-125
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH32:    ; Path 32
    FCB 127              ; path32: intensity
    FCB $29,$D2,0,0        ; path32: header (y=41, x=-46)
    FCB $FF,$1C,$2D          ; flag=-1, dy=28, dx=45
    FCB $FF,$E4,$2F          ; flag=-1, dy=-28, dx=47
    FCB $FF,$00,$A4          ; flag=-1, dy=0, dx=-92
    FCB 2                ; End marker (path complete)
; Generated from ayers_bg.vec (Malban Draw_Sync_List format)
; Total paths: 18, points: 106
; X bounds: min=-96, max=102, width=198
; Center: (3, 10)

_AYERS_BG_WIDTH EQU 198
_AYERS_BG_HALF_WIDTH EQU 99
_AYERS_BG_HEIGHT EQU 63
_AYERS_BG_HALF_HEIGHT EQU 31
_AYERS_BG_CENTER_X EQU 3
_AYERS_BG_CENTER_Y EQU 10

_AYERS_BG_VECTORS:  ; Main entry (header + 17 path(s))
    FDB 17               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _AYERS_BG_PATH0        ; pointer to path 0
    FDB _AYERS_BG_PATH1        ; pointer to path 1
    FDB _AYERS_BG_PATH2        ; pointer to path 2
    FDB _AYERS_BG_PATH3        ; pointer to path 3
    FDB _AYERS_BG_PATH4        ; pointer to path 4
    FDB _AYERS_BG_PATH5        ; pointer to path 5
    FDB _AYERS_BG_PATH6        ; pointer to path 6
    FDB _AYERS_BG_PATH7        ; pointer to path 7
    FDB _AYERS_BG_PATH8        ; pointer to path 8
    FDB _AYERS_BG_PATH9        ; pointer to path 9
    FDB _AYERS_BG_PATH10        ; pointer to path 10
    FDB _AYERS_BG_PATH11        ; pointer to path 11
    FDB _AYERS_BG_PATH12        ; pointer to path 12
    FDB _AYERS_BG_PATH13        ; pointer to path 13
    FDB _AYERS_BG_PATH14        ; pointer to path 14
    FDB _AYERS_BG_PATH15        ; pointer to path 15
    FDB _AYERS_BG_PATH16        ; pointer to path 16

_AYERS_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $E1,$07,0,0        ; path0: header (y=-31, x=7)
    FCB $FF,$07,$F5          ; flag=-1, dy=7, dx=-11
    FCB $FF,$13,$FC          ; flag=-1, dy=19, dx=-4
    FCB $FF,$F6,$FE          ; flag=-1, dy=-10, dx=-2
    FCB $FF,$F6,$01          ; flag=-1, dy=-10, dx=1
    FCB $FF,$00,$F3          ; flag=-1, dy=0, dx=-13
    FCB $FF,$03,$FD          ; flag=-1, dy=3, dx=-3
    FCB $FF,$FA,$FC          ; flag=-1, dy=-6, dx=-4
    FCB $FF,$04,$F5          ; flag=-1, dy=4, dx=-11
    FCB $FF,$20,$05          ; flag=-1, dy=32, dx=5
    FCB $FF,$F9,$FA          ; flag=-1, dy=-7, dx=-6
    FCB $FF,$E7,$FE          ; flag=-1, dy=-25, dx=-2
    FCB $FF,$FD,$FA          ; flag=-1, dy=-3, dx=-6
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $E2,$CF,0,0        ; path1: header (y=-30, x=-49)
    FCB $FF,$0E,$FF          ; flag=-1, dy=14, dx=-1
    FCB $FF,$29,$08          ; flag=-1, dy=41, dx=8
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $18,$D3,0,0        ; path2: header (y=24, x=-45)
    FCB $FF,$E0,$F9          ; flag=-1, dy=-32, dx=-7
    FCB $FF,$EA,$F8          ; flag=-1, dy=-22, dx=-8
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $E2,$BE,0,0        ; path3: header (y=-30, x=-66)
    FCB $FF,$24,$05          ; flag=-1, dy=36, dx=5
    FCB $FF,$F8,$FA          ; flag=-1, dy=-8, dx=-6
    FCB $FF,$E4,$FE          ; flag=-1, dy=-28, dx=-2
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $E2,$A7,0,0        ; path4: header (y=-30, x=-89)
    FCB $FF,$2F,$0F          ; flag=-1, dy=47, dx=15
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $19,$E9,0,0        ; path5: header (y=25, x=-23)
    FCB $FF,$EF,$FD          ; flag=-1, dy=-17, dx=-3
    FCB $FF,$F2,$03          ; flag=-1, dy=-14, dx=3
    FCB $FF,$F5,$00          ; flag=-1, dy=-11, dx=0
    FCB $FF,$15,$0B          ; flag=-1, dy=21, dx=11
    FCB $FF,$18,$06          ; flag=-1, dy=24, dx=6
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $1B,$F7,0,0        ; path6: header (y=27, x=-9)
    FCB $FF,$E4,$F6          ; flag=-1, dy=-28, dx=-10
    FCB $FF,$0A,$FD          ; flag=-1, dy=10, dx=-3
    FCB $FF,$11,$06          ; flag=-1, dy=17, dx=6
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $20,$07,0,0        ; path7: header (y=32, x=7)
    FCB $FF,$F0,$02          ; flag=-1, dy=-16, dx=2
    FCB $FF,$F2,$FA          ; flag=-1, dy=-14, dx=-6
    FCB $FF,$EF,$01          ; flag=-1, dy=-17, dx=1
    FCB $FF,$2C,$0E          ; flag=-1, dy=44, dx=14
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $19,$1F,0,0        ; path8: header (y=25, x=31)
    FCB $FF,$EB,$0A          ; flag=-1, dy=-21, dx=10
    FCB $FF,$DD,$00          ; flag=-1, dy=-35, dx=0
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $E1,$25,0,0        ; path9: header (y=-31, x=37)
    FCB $FF,$08,$F9          ; flag=-1, dy=8, dx=-7
    FCB $FF,$1A,$FC          ; flag=-1, dy=26, dx=-4
    FCB $FF,$E6,$FE          ; flag=-1, dy=-26, dx=-2
    FCB $FF,$F9,$F9          ; flag=-1, dy=-7, dx=-7
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $E2,$10,0,0        ; path10: header (y=-30, x=16)
    FCB $FF,$25,$01          ; flag=-1, dy=37, dx=1
    FCB $FF,$ED,$FA          ; flag=-1, dy=-19, dx=-6
    FCB $FF,$EE,$FF          ; flag=-1, dy=-18, dx=-1
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $E2,$2F,0,0        ; path11: header (y=-30, x=47)
    FCB $FF,$25,$FD          ; flag=-1, dy=37, dx=-3
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $06,$2C,0,0        ; path12: header (y=6, x=44)
    FCB $FF,$13,$F7          ; flag=-1, dy=19, dx=-9
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $16,$38,0,0        ; path13: header (y=22, x=56)
    FCB $FF,$CB,$04          ; flag=-1, dy=-53, dx=4
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $E1,$4C,0,0        ; path14: header (y=-31, x=76)
    FCB $FF,$15,$FC          ; flag=-1, dy=21, dx=-4
    FCB $FF,$03,$FD          ; flag=-1, dy=3, dx=-3
    FCB $FF,$10,$FE          ; flag=-1, dy=16, dx=-2
    FCB $FF,$EE,$FE          ; flag=-1, dy=-18, dx=-2
    FCB $FF,$1F,$F7          ; flag=-1, dy=31, dx=-9
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $00,$52,0,0        ; path15: header (y=0, x=82)
    FCB $FF,$E6,$05          ; flag=-1, dy=-26, dx=5
    FCB $FF,$1E,$F3          ; flag=-1, dy=30, dx=-13
    FCB $FF,$DD,$09          ; flag=-1, dy=-35, dx=9
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $E2,$9D,0,0        ; path16: header (y=-30, x=-99)
    FCB $FF,$2A,$0C          ; flag=-1, dy=42, dx=12
    FCB $FF,$05,$0D          ; flag=-1, dy=5, dx=13
    FCB $FF,$07,$1E          ; flag=-1, dy=7, dx=30
    FCB $FF,$05,$09          ; flag=-1, dy=5, dx=9
    FCB $FF,$FC,$0C          ; flag=-1, dy=-4, dx=12
    FCB $FF,$02,$0E          ; flag=-1, dy=2, dx=14
    FCB $FF,$05,$0C          ; flag=-1, dy=5, dx=12
    FCB $FF,$FF,$0C          ; flag=-1, dy=-1, dx=12
    FCB $FF,$FA,$0D          ; flag=-1, dy=-6, dx=13
    FCB $FF,$01,$10          ; flag=-1, dy=1, dx=16
    FCB $FF,$FB,$0E          ; flag=-1, dy=-5, dx=14
    FCB $FF,$F5,$10          ; flag=-1, dy=-11, dx=16
    FCB $FF,$F2,$0B          ; flag=-1, dy=-14, dx=11
    FCB $FF,$EE,$0B          ; flag=-1, dy=-18, dx=11
    FCB $FF,$F7,$03          ; flag=-1, dy=-9, dx=3
    FCB $FF,$00,$9D          ; sub-seg 1/2 of line 15: dy=0, dx=-99
    FCB $FF,$01,$9D          ; sub-seg 2/2 of line 15: dy=1, dx=-99
    FCB 2                ; End marker (path complete)
; Generated from barcelona_bg.vec (Malban Draw_Sync_List format)
; Total paths: 60, points: 193
; X bounds: min=-47, max=69, width=116
; Center: (11, 13)

_BARCELONA_BG_WIDTH EQU 116
_BARCELONA_BG_HALF_WIDTH EQU 58
_BARCELONA_BG_HEIGHT EQU 128
_BARCELONA_BG_HALF_HEIGHT EQU 64
_BARCELONA_BG_CENTER_X EQU 11
_BARCELONA_BG_CENTER_Y EQU 13

_BARCELONA_BG_VECTORS:  ; Main entry (header + 44 path(s))
    FDB 44               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _BARCELONA_BG_PATH0        ; pointer to path 0
    FDB _BARCELONA_BG_PATH1        ; pointer to path 1
    FDB _BARCELONA_BG_PATH2        ; pointer to path 2
    FDB _BARCELONA_BG_PATH3        ; pointer to path 3
    FDB _BARCELONA_BG_PATH4        ; pointer to path 4
    FDB _BARCELONA_BG_PATH5        ; pointer to path 5
    FDB _BARCELONA_BG_PATH6        ; pointer to path 6
    FDB _BARCELONA_BG_PATH7        ; pointer to path 7
    FDB _BARCELONA_BG_PATH8        ; pointer to path 8
    FDB _BARCELONA_BG_PATH9        ; pointer to path 9
    FDB _BARCELONA_BG_PATH10        ; pointer to path 10
    FDB _BARCELONA_BG_PATH11        ; pointer to path 11
    FDB _BARCELONA_BG_PATH12        ; pointer to path 12
    FDB _BARCELONA_BG_PATH13        ; pointer to path 13
    FDB _BARCELONA_BG_PATH14        ; pointer to path 14
    FDB _BARCELONA_BG_PATH15        ; pointer to path 15
    FDB _BARCELONA_BG_PATH16        ; pointer to path 16
    FDB _BARCELONA_BG_PATH17        ; pointer to path 17
    FDB _BARCELONA_BG_PATH18        ; pointer to path 18
    FDB _BARCELONA_BG_PATH19        ; pointer to path 19
    FDB _BARCELONA_BG_PATH20        ; pointer to path 20
    FDB _BARCELONA_BG_PATH21        ; pointer to path 21
    FDB _BARCELONA_BG_PATH22        ; pointer to path 22
    FDB _BARCELONA_BG_PATH23        ; pointer to path 23
    FDB _BARCELONA_BG_PATH24        ; pointer to path 24
    FDB _BARCELONA_BG_PATH25        ; pointer to path 25
    FDB _BARCELONA_BG_PATH26        ; pointer to path 26
    FDB _BARCELONA_BG_PATH27        ; pointer to path 27
    FDB _BARCELONA_BG_PATH28        ; pointer to path 28
    FDB _BARCELONA_BG_PATH29        ; pointer to path 29
    FDB _BARCELONA_BG_PATH30        ; pointer to path 30
    FDB _BARCELONA_BG_PATH31        ; pointer to path 31
    FDB _BARCELONA_BG_PATH32        ; pointer to path 32
    FDB _BARCELONA_BG_PATH33        ; pointer to path 33
    FDB _BARCELONA_BG_PATH34        ; pointer to path 34
    FDB _BARCELONA_BG_PATH35        ; pointer to path 35
    FDB _BARCELONA_BG_PATH36        ; pointer to path 36
    FDB _BARCELONA_BG_PATH37        ; pointer to path 37
    FDB _BARCELONA_BG_PATH38        ; pointer to path 38
    FDB _BARCELONA_BG_PATH39        ; pointer to path 39
    FDB _BARCELONA_BG_PATH40        ; pointer to path 40
    FDB _BARCELONA_BG_PATH41        ; pointer to path 41
    FDB _BARCELONA_BG_PATH42        ; pointer to path 42
    FDB _BARCELONA_BG_PATH43        ; pointer to path 43

_BARCELONA_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $F3,$F1,0,0        ; path0: header (y=-13, x=-15)
    FCB $FF,$0F,$00          ; flag=-1, dy=15, dx=0
    FCB $FF,$08,$03          ; flag=-1, dy=8, dx=3
    FCB $FF,$F7,$04          ; flag=-1, dy=-9, dx=4
    FCB $FF,$F2,$01          ; flag=-1, dy=-14, dx=1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $F2,$FC,0,0        ; path1: header (y=-14, x=-4)
    FCB $FF,$3A,$00          ; flag=-1, dy=58, dx=0
    FCB $FF,$0D,$03          ; flag=-1, dy=13, dx=3
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$B1,$0A          ; flag=-1, dy=-79, dx=10
    FCB $FF,$34,$FD          ; flag=-1, dy=52, dx=-3
    FCB $FF,$0E,$02          ; flag=-1, dy=14, dx=2
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$F1,$04          ; flag=-1, dy=-15, dx=4
    FCB $FF,$C7,$07          ; flag=-1, dy=-57, dx=7
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $F0,$13,0,0        ; path2: header (y=-16, x=19)
    FCB $FF,$10,$FE          ; flag=-1, dy=16, dx=-2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $02,$11,0,0        ; path3: header (y=2, x=17)
    FCB $FF,$17,$FD          ; flag=-1, dy=23, dx=-3
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $1C,$0F,0,0        ; path4: header (y=28, x=15)
    FCB $FF,$01,$FA          ; flag=-1, dy=1, dx=-6
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $1A,$0B,0,0        ; path5: header (y=26, x=11)
    FCB $FF,$E9,$01          ; flag=-1, dy=-23, dx=1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $00,$0C,0,0        ; path6: header (y=0, x=12)
    FCB $FF,$F3,$01          ; flag=-1, dy=-13, dx=1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $F1,$10,0,0        ; path7: header (y=-15, x=16)
    FCB $FF,$0F,$FF          ; flag=-1, dy=15, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $07,$05,0,0        ; path8: header (y=7, x=5)
    FCB $FF,$F0,$01          ; flag=-1, dy=-16, dx=1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $F9,$03,0,0        ; path9: header (y=-7, x=3)
    FCB $FF,$0E,$FF          ; flag=-1, dy=14, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $07,$FF,0,0        ; path10: header (y=7, x=-1)
    FCB $FF,$F4,$01          ; flag=-1, dy=-12, dx=1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $D7,$1A,0,0        ; path11: header (y=-41, x=26)
    FCB $FF,$0C,$FF          ; flag=-1, dy=12, dx=-1
    FCB $FF,$12,$DC          ; flag=-1, dy=18, dx=-36
    FCB $FF,$EE,$DC          ; flag=-1, dy=-18, dx=-36
    FCB $FF,$F5,$FE          ; flag=-1, dy=-11, dx=-2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $D5,$CD,0,0        ; path12: header (y=-43, x=-51)
    FCB $FF,$16,$28          ; flag=-1, dy=22, dx=40
    FCB $FF,$EA,$27          ; flag=-1, dy=-22, dx=39
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $C1,$21,0,0        ; path13: header (y=-63, x=33)
    FCB $FF,$13,$F6          ; flag=-1, dy=19, dx=-10
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$ED,$03          ; flag=-1, dy=-19, dx=3
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $C1,$14,0,0        ; path14: header (y=-63, x=20)
    FCB $FF,$18,$F9          ; flag=-1, dy=24, dx=-7
    FCB $FF,$01,$F7          ; flag=-1, dy=1, dx=-9
    FCB $FF,$E7,$05          ; flag=-1, dy=-25, dx=5
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $C1,$05,0,0        ; path15: header (y=-63, x=5)
    FCB $FF,$18,$F9          ; flag=-1, dy=24, dx=-7
    FCB $FF,$0A,$F7          ; flag=-1, dy=10, dx=-9
    FCB $FF,$F6,$F5          ; flag=-1, dy=-10, dx=-11
    FCB $FF,$E7,$F9          ; flag=-1, dy=-25, dx=-7
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $C0,$E1,0,0        ; path16: header (y=-64, x=-31)
    FCB $FF,$19,$04          ; flag=-1, dy=25, dx=4
    FCB $FF,$FF,$F7          ; flag=-1, dy=-1, dx=-9
    FCB $FF,$E8,$F8          ; flag=-1, dy=-24, dx=-8
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $C0,$D1,0,0        ; path17: header (y=-64, x=-47)
    FCB $FF,$14,$06          ; flag=-1, dy=20, dx=6
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$EC,$F9          ; flag=-1, dy=-20, dx=-7
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH18:    ; Path 18
    FCB 127              ; path18: intensity
    FCB $C0,$C6,0,0        ; path18: header (y=-64, x=-58)
    FCB $FF,$0D,$05          ; flag=-1, dy=13, dx=5
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$14,$2A          ; flag=-1, dy=20, dx=42
    FCB $FF,$EB,$2B          ; flag=-1, dy=-21, dx=43
    FCB $FF,$FD,$FD          ; flag=-1, dy=-3, dx=-3
    FCB $FF,$F3,$06          ; flag=-1, dy=-13, dx=6
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH19:    ; Path 19
    FCB 127              ; path19: intensity
    FCB $C1,$FA,0,0        ; path19: header (y=-63, x=-6)
    FCB $FF,$0B,$FF          ; flag=-1, dy=11, dx=-1
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB $FF,$FF,$FC          ; flag=-1, dy=-1, dx=-4
    FCB $FF,$F4,$FF          ; flag=-1, dy=-12, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH20:    ; Path 20
    FCB 127              ; path20: intensity
    FCB $E6,$F5,0,0        ; path20: header (y=-26, x=-11)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH21:    ; Path 21
    FCB 127              ; path21: intensity
    FCB $F1,$ED,0,0        ; path21: header (y=-15, x=-19)
    FCB $FF,$3C,$00          ; flag=-1, dy=60, dx=0
    FCB $FF,$0D,$FD          ; flag=-1, dy=13, dx=-3
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$F1,$FD          ; flag=-1, dy=-15, dx=-3
    FCB $FF,$FF,$01          ; flag=-1, dy=-1, dx=1
    FCB $FF,$C0,$FA          ; flag=-1, dy=-64, dx=-6
    FCB $FF,$35,$01          ; flag=-1, dy=53, dx=1
    FCB $FF,$0E,$FE          ; flag=-1, dy=14, dx=-2
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$B7,$F6          ; flag=-1, dy=-73, dx=-10
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH22:    ; Path 22
    FCB 127              ; path22: intensity
    FCB $F0,$D7,0,0        ; path22: header (y=-16, x=-41)
    FCB $FF,$10,$02          ; flag=-1, dy=16, dx=2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH23:    ; Path 23
    FCB 127              ; path23: intensity
    FCB $00,$DB,0,0        ; path23: header (y=0, x=-37)
    FCB $FF,$F1,$FF          ; flag=-1, dy=-15, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH24:    ; Path 24
    FCB 127              ; path24: intensity
    FCB $F3,$DD,0,0        ; path24: header (y=-13, x=-35)
    FCB $FF,$0D,$01          ; flag=-1, dy=13, dx=1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH25:    ; Path 25
    FCB 127              ; path25: intensity
    FCB $06,$DE,0,0        ; path25: header (y=6, x=-34)
    FCB $FF,$15,$00          ; flag=-1, dy=21, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH26:    ; Path 26
    FCB 127              ; path26: intensity
    FCB $1B,$DC,0,0        ; path26: header (y=27, x=-36)
    FCB $FF,$EB,$FE          ; flag=-1, dy=-21, dx=-2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH27:    ; Path 27
    FCB 127              ; path27: intensity
    FCB $07,$E5,0,0        ; path27: header (y=7, x=-27)
    FCB $FF,$F0,$FF          ; flag=-1, dy=-16, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH28:    ; Path 28
    FCB 127              ; path28: intensity
    FCB $F9,$E7,0,0        ; path28: header (y=-7, x=-25)
    FCB $FF,$0E,$01          ; flag=-1, dy=14, dx=1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH29:    ; Path 29
    FCB 127              ; path29: intensity
    FCB $07,$EB,0,0        ; path29: header (y=7, x=-21)
    FCB $FF,$F4,$FF          ; flag=-1, dy=-12, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH30:    ; Path 30
    FCB 127              ; path30: intensity
    FCB $0B,$ED,0,0        ; path30: header (y=11, x=-19)
    FCB $FF,$05,$07          ; flag=-1, dy=5, dx=7
    FCB $FF,$FC,$08          ; flag=-1, dy=-4, dx=8
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH31:    ; Path 31
    FCB 127              ; path31: intensity
    FCB $0E,$FE,0,0        ; path31: header (y=14, x=-2)
    FCB $FF,$1A,$00          ; flag=-1, dy=26, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH32:    ; Path 32
    FCB 127              ; path32: intensity
    FCB $2A,$FD,0,0        ; path32: header (y=42, x=-3)
    FCB $FF,$FF,$05          ; flag=-1, dy=-1, dx=5
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH33:    ; Path 33
    FCB 127              ; path33: intensity
    FCB $28,$01,0,0        ; path33: header (y=40, x=1)
    FCB $FF,$E5,$03          ; flag=-1, dy=-27, dx=3
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH34:    ; Path 34
    FCB 127              ; path34: intensity
    FCB $13,$FC,0,0        ; path34: header (y=19, x=-4)
    FCB $FF,$02,$F8          ; flag=-1, dy=2, dx=-8
    FCB $FF,$FD,$F9          ; flag=-1, dy=-3, dx=-7
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH35:    ; Path 35
    FCB 127              ; path35: intensity
    FCB $0E,$EB,0,0        ; path35: header (y=14, x=-21)
    FCB $FF,$1A,$00          ; flag=-1, dy=26, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH36:    ; Path 36
    FCB 127              ; path36: intensity
    FCB $28,$E8,0,0        ; path36: header (y=40, x=-24)
    FCB $FF,$E5,$FD          ; flag=-1, dy=-27, dx=-3
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH37:    ; Path 37
    FCB 127              ; path37: intensity
    FCB $0E,$E9,0,0        ; path37: header (y=14, x=-23)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH38:    ; Path 38
    FCB 127              ; path38: intensity
    FCB $1E,$E0,0,0        ; path38: header (y=30, x=-32)
    FCB $FF,$FF,$FB          ; flag=-1, dy=-1, dx=-5
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH39:    ; Path 39
    FCB 127              ; path39: intensity
    FCB $2D,$DF,0,0        ; path39: header (y=45, x=-33)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$03,$FE          ; flag=-1, dy=3, dx=-2
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$FD,$FE          ; flag=-1, dy=-3, dx=-2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH40:    ; Path 40
    FCB 127              ; path40: intensity
    FCB $2A,$E6,0,0        ; path40: header (y=42, x=-26)
    FCB $FF,$01,$06          ; flag=-1, dy=1, dx=6
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH41:    ; Path 41
    FCB 127              ; path41: intensity
    FCB $3A,$EA,0,0        ; path41: header (y=58, x=-22)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$FD,$FE          ; flag=-1, dy=-3, dx=-2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH42:    ; Path 42
    FCB 127              ; path42: intensity
    FCB $39,$01,0,0        ; path42: header (y=57, x=1)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$03,$FE          ; flag=-1, dy=3, dx=-2
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$FD,$FE          ; flag=-1, dy=-3, dx=-2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH43:    ; Path 43
    FCB 127              ; path43: intensity
    FCB $2E,$0E,0,0        ; path43: header (y=46, x=14)
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$FE,$04          ; flag=-1, dy=-2, dx=4
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB 2                ; End marker (path complete)
; Generated from bubble_huge.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 8
; X bounds: min=-25, max=27, width=52
; Center: (1, 0)

_BUBBLE_HUGE_WIDTH EQU 52
_BUBBLE_HUGE_HALF_WIDTH EQU 26
_BUBBLE_HUGE_HEIGHT EQU 52
_BUBBLE_HUGE_HALF_HEIGHT EQU 26
_BUBBLE_HUGE_CENTER_X EQU 1
_BUBBLE_HUGE_CENTER_Y EQU 0

_BUBBLE_HUGE_VECTORS:  ; Main entry (header + 1 path(s))
    FDB 1               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _BUBBLE_HUGE_PATH0        ; pointer to path 0

_BUBBLE_HUGE_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $00,$1A,0,0        ; path0: header (y=0, x=26)
    FCB $FF,$12,$F8          ; flag=-1, dy=18, dx=-8
    FCB $FF,$08,$EE          ; flag=-1, dy=8, dx=-18
    FCB $FF,$F8,$EE          ; flag=-1, dy=-8, dx=-18
    FCB $FF,$EE,$F8          ; flag=-1, dy=-18, dx=-8
    FCB $FF,$EE,$08          ; flag=-1, dy=-18, dx=8
    FCB $FF,$F8,$12          ; flag=-1, dy=-8, dx=18
    FCB $FF,$08,$12          ; flag=-1, dy=8, dx=18
    FCB $FF,$12,$08          ; flag=-1, dy=18, dx=8
    FCB 2                ; End marker (path complete)
; Generated from bubble_large.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 24
; X bounds: min=-20, max=20, width=40
; Center: (0, 0)

_BUBBLE_LARGE_WIDTH EQU 40
_BUBBLE_LARGE_HALF_WIDTH EQU 20
_BUBBLE_LARGE_HEIGHT EQU 40
_BUBBLE_LARGE_HALF_HEIGHT EQU 20
_BUBBLE_LARGE_CENTER_X EQU 0
_BUBBLE_LARGE_CENTER_Y EQU 0

_BUBBLE_LARGE_VECTORS:  ; Main entry (header + 1 path(s))
    FDB 1               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _BUBBLE_LARGE_PATH0        ; pointer to path 0

_BUBBLE_LARGE_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $00,$14,0,0        ; path0: header (y=0, x=20)
    FCB $FF,$0A,$FD          ; flag=-1, dy=10, dx=-3
    FCB $FF,$04,$FD          ; flag=-1, dy=4, dx=-3
    FCB $FF,$03,$FC          ; flag=-1, dy=3, dx=-4
    FCB $FF,$03,$F6          ; flag=-1, dy=3, dx=-10
    FCB $FF,$FD,$F6          ; flag=-1, dy=-3, dx=-10
    FCB $FF,$FD,$FC          ; flag=-1, dy=-3, dx=-4
    FCB $FF,$F7,$FB          ; flag=-1, dy=-9, dx=-5
    FCB $FF,$FB,$FF          ; flag=-1, dy=-5, dx=-1
    FCB $FF,$F6,$03          ; flag=-1, dy=-10, dx=3
    FCB $FF,$FC,$03          ; flag=-1, dy=-4, dx=3
    FCB $FF,$FB,$09          ; flag=-1, dy=-5, dx=9
    FCB $FF,$FF,$05          ; flag=-1, dy=-1, dx=5
    FCB $FF,$03,$0A          ; flag=-1, dy=3, dx=10
    FCB $FF,$03,$04          ; flag=-1, dy=3, dx=4
    FCB $FF,$09,$05          ; flag=-1, dy=9, dx=5
    FCB $FF,$05,$01          ; flag=-1, dy=5, dx=1
    FCB 2                ; End marker (path complete)
; Generated from bubble_medium.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 24
; X bounds: min=-15, max=15, width=30
; Center: (0, 0)

_BUBBLE_MEDIUM_WIDTH EQU 30
_BUBBLE_MEDIUM_HALF_WIDTH EQU 15
_BUBBLE_MEDIUM_HEIGHT EQU 30
_BUBBLE_MEDIUM_HALF_HEIGHT EQU 15
_BUBBLE_MEDIUM_CENTER_X EQU 0
_BUBBLE_MEDIUM_CENTER_Y EQU 0

_BUBBLE_MEDIUM_VECTORS:  ; Main entry (header + 1 path(s))
    FDB 1               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _BUBBLE_MEDIUM_PATH0        ; pointer to path 0

_BUBBLE_MEDIUM_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $00,$0F,0,0        ; path0: header (y=0, x=15)
    FCB $FF,$08,$FE          ; flag=-1, dy=8, dx=-2
    FCB $FF,$05,$FB          ; flag=-1, dy=5, dx=-5
    FCB $FF,$02,$F8          ; flag=-1, dy=2, dx=-8
    FCB $FF,$FE,$F8          ; flag=-1, dy=-2, dx=-8
    FCB $FF,$FB,$FB          ; flag=-1, dy=-5, dx=-5
    FCB $FF,$F8,$FE          ; flag=-1, dy=-8, dx=-2
    FCB $FF,$F8,$02          ; flag=-1, dy=-8, dx=2
    FCB $FF,$FB,$05          ; flag=-1, dy=-5, dx=5
    FCB $FF,$FE,$08          ; flag=-1, dy=-2, dx=8
    FCB $FF,$02,$08          ; flag=-1, dy=2, dx=8
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$07,$03          ; flag=-1, dy=7, dx=3
    FCB $FF,$04,$01          ; flag=-1, dy=4, dx=1
    FCB 2                ; End marker (path complete)
; Generated from bubble_small.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 24
; X bounds: min=-10, max=10, width=20
; Center: (0, 0)

_BUBBLE_SMALL_WIDTH EQU 20
_BUBBLE_SMALL_HALF_WIDTH EQU 10
_BUBBLE_SMALL_HEIGHT EQU 20
_BUBBLE_SMALL_HALF_HEIGHT EQU 10
_BUBBLE_SMALL_CENTER_X EQU 0
_BUBBLE_SMALL_CENTER_Y EQU 0

_BUBBLE_SMALL_VECTORS:  ; Main entry (header + 1 path(s))
    FDB 1               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _BUBBLE_SMALL_PATH0        ; pointer to path 0

_BUBBLE_SMALL_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $00,$0A,0,0        ; path0: header (y=0, x=10)
    FCB $FF,$05,$FF          ; flag=-1, dy=5, dx=-1
    FCB $FF,$04,$FC          ; flag=-1, dy=4, dx=-4
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$FC,$FC          ; flag=-1, dy=-4, dx=-4
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$FC,$04          ; flag=-1, dy=-4, dx=4
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$04,$04          ; flag=-1, dy=4, dx=4
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB 2                ; End marker (path complete)
; Generated from buddha_bg.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 10
; X bounds: min=-80, max=80, width=160
; Center: (0, 20)

_BUDDHA_BG_WIDTH EQU 160
_BUDDHA_BG_HALF_WIDTH EQU 80
_BUDDHA_BG_HEIGHT EQU 80
_BUDDHA_BG_HALF_HEIGHT EQU 40
_BUDDHA_BG_CENTER_X EQU 0
_BUDDHA_BG_CENTER_Y EQU 20

_BUDDHA_BG_VECTORS:  ; Main entry (header + 4 path(s))
    FDB 4               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _BUDDHA_BG_PATH0        ; pointer to path 0
    FDB _BUDDHA_BG_PATH1        ; pointer to path 1
    FDB _BUDDHA_BG_PATH2        ; pointer to path 2
    FDB _BUDDHA_BG_PATH3        ; pointer to path 3

_BUDDHA_BG_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $D8,$CE,0,0        ; path0: header (y=-40, x=-50)
    FCB $FF,$3C,$00          ; flag=-1, dy=60, dx=0
    FCB 2                ; End marker (path complete)

_BUDDHA_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $14,$B0,0,0        ; path1: header (y=20, x=-80)
    FCB $FF,$14,$14          ; flag=-1, dy=20, dx=20
    FCB $FF,$00,$78          ; flag=-1, dy=0, dx=120
    FCB $FF,$EC,$14          ; flag=-1, dy=-20, dx=20
    FCB 2                ; End marker (path complete)

_BUDDHA_BG_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $14,$32,0,0        ; path2: header (y=20, x=50)
    FCB $FF,$C4,$00          ; flag=-1, dy=-60, dx=0
    FCB 2                ; End marker (path complete)

_BUDDHA_BG_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $D8,$46,0,0        ; path3: header (y=-40, x=70)
    FCB $FF,$00,$BA          ; sub-seg 1/2 of line 0: dy=0, dx=-70
    FCB $FF,$00,$BA          ; sub-seg 2/2 of line 0: dy=0, dx=-70
    FCB 2                ; End marker (path complete)
; Generated from easter_bg.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 19
; X bounds: min=-35, max=35, width=70
; Center: (0, 15)

_EASTER_BG_WIDTH EQU 70
_EASTER_BG_HALF_WIDTH EQU 35
_EASTER_BG_HEIGHT EQU 90
_EASTER_BG_HALF_HEIGHT EQU 45
_EASTER_BG_CENTER_X EQU 0
_EASTER_BG_CENTER_Y EQU 15

_EASTER_BG_VECTORS:  ; Main entry (header + 5 path(s))
    FDB 5               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _EASTER_BG_PATH0        ; pointer to path 0
    FDB _EASTER_BG_PATH1        ; pointer to path 1
    FDB _EASTER_BG_PATH2        ; pointer to path 2
    FDB _EASTER_BG_PATH3        ; pointer to path 3
    FDB _EASTER_BG_PATH4        ; pointer to path 4

_EASTER_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $05,$E7,0,0        ; path0: header (y=5, x=-25)
    FCB $FF,$1E,$00          ; flag=-1, dy=30, dx=0
    FCB $FF,$0A,$05          ; flag=-1, dy=10, dx=5
    FCB $FF,$00,$28          ; flag=-1, dy=0, dx=40
    FCB $FF,$F6,$05          ; flag=-1, dy=-10, dx=5
    FCB $FF,$E2,$00          ; flag=-1, dy=-30, dx=0
    FCB 2                ; End marker (path complete)

_EASTER_BG_PATH1:    ; Path 1
    FCB 110              ; path1: intensity
    FCB $05,$1E,0,0        ; path1: header (y=5, x=30)
    FCB $FF,$CE,$00          ; flag=-1, dy=-50, dx=0
    FCB $FF,$00,$C4          ; flag=-1, dy=0, dx=-60
    FCB $FF,$32,$00          ; flag=-1, dy=50, dx=0
    FCB 2                ; End marker (path complete)

_EASTER_BG_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $1E,$F8,0,0        ; path2: header (y=30, x=-8)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB 2                ; End marker (path complete)

_EASTER_BG_PATH3:    ; Path 3
    FCB 110              ; path3: intensity
    FCB $19,$00,0,0        ; path3: header (y=25, x=0)
    FCB $FF,$FB,$0A          ; flag=-1, dy=-5, dx=10
    FCB 2                ; End marker (path complete)

_EASTER_BG_PATH4:    ; Path 4
    FCB 90              ; path4: intensity
    FCB $D3,$23,0,0        ; path4: header (y=-45, x=35)
    FCB $FF,$00,$BA          ; flag=-1, dy=0, dx=-70
    FCB 2                ; End marker (path complete)
; Generated from fuji_bg.vec (Malban Draw_Sync_List format)
; Total paths: 6, points: 65
; X bounds: min=-125, max=125, width=250
; Center: (0, 0)

_FUJI_BG_WIDTH EQU 250
_FUJI_BG_HALF_WIDTH EQU 125
_FUJI_BG_HEIGHT EQU 97
_FUJI_BG_HALF_HEIGHT EQU 48
_FUJI_BG_CENTER_X EQU 0
_FUJI_BG_CENTER_Y EQU 0

_FUJI_BG_VECTORS:  ; Main entry (header + 5 path(s))
    FDB 5               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _FUJI_BG_PATH0        ; pointer to path 0
    FDB _FUJI_BG_PATH1        ; pointer to path 1
    FDB _FUJI_BG_PATH2        ; pointer to path 2
    FDB _FUJI_BG_PATH3        ; pointer to path 3
    FDB _FUJI_BG_PATH4        ; pointer to path 4

_FUJI_BG_PATH0:    ; Path 0
    FCB 95              ; path0: intensity
    FCB $1A,$F1,0,0        ; path0: header (y=26, x=-15)
    FCB $FF,$0A,$06          ; flag=-1, dy=10, dx=6
    FCB $FF,$FD,$04          ; flag=-1, dy=-3, dx=4
    FCB $FF,$F9,$F6          ; flag=-1, dy=-7, dx=-10
    FCB 2                ; End marker (path complete)

_FUJI_BG_PATH1:    ; Path 1
    FCB 95              ; path1: intensity
    FCB $1F,$07,0,0        ; path1: header (y=31, x=7)
    FCB $FF,$F9,$FD          ; flag=-1, dy=-7, dx=-3
    FCB $FF,$FA,$02          ; flag=-1, dy=-6, dx=2
    FCB $FF,$F9,$FD          ; flag=-1, dy=-7, dx=-3
    FCB $FF,$FD,$04          ; flag=-1, dy=-3, dx=4
    FCB $FF,$08,$03          ; flag=-1, dy=8, dx=3
    FCB $FF,$07,$FE          ; flag=-1, dy=7, dx=-2
    FCB $FF,$06,$01          ; flag=-1, dy=6, dx=1
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB 2                ; End marker (path complete)

_FUJI_BG_PATH2:    ; Path 2
    FCB 95              ; path2: intensity
    FCB $21,$18,0,0        ; path2: header (y=33, x=24)
    FCB $FF,$F7,$05          ; flag=-1, dy=-9, dx=5
    FCB $FF,$F7,$0C          ; flag=-1, dy=-9, dx=12
    FCB $FF,$0B,$FA          ; flag=-1, dy=11, dx=-6
    FCB $FF,$07,$F5          ; flag=-1, dy=7, dx=-11
    FCB 2                ; End marker (path complete)

_FUJI_BG_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $02,$4D,0,0        ; path3: header (y=2, x=77)
    FCB $FF,$04,$EC          ; flag=-1, dy=4, dx=-20
    FCB $FF,$FC,$FE          ; flag=-1, dy=-4, dx=-2
    FCB $FF,$07,$F2          ; flag=-1, dy=7, dx=-14
    FCB $FF,$EE,$09          ; flag=-1, dy=-18, dx=9
    FCB $FF,$12,$ED          ; flag=-1, dy=18, dx=-19
    FCB $FF,$F0,$01          ; flag=-1, dy=-16, dx=1
    FCB $FF,$0B,$FB          ; flag=-1, dy=11, dx=-5
    FCB $FF,$F5,$FD          ; flag=-1, dy=-11, dx=-3
    FCB $FF,$03,$FC          ; flag=-1, dy=3, dx=-4
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$11,$FA          ; flag=-1, dy=17, dx=-6
    FCB $FF,$E4,$FB          ; flag=-1, dy=-28, dx=-5
    FCB $FF,$16,$FA          ; flag=-1, dy=22, dx=-6
    FCB $FF,$F6,$FB          ; flag=-1, dy=-10, dx=-5
    FCB $FF,$0F,$00          ; flag=-1, dy=15, dx=0
    FCB $FF,$F2,$F2          ; flag=-1, dy=-14, dx=-14
    FCB $FF,$06,$FF          ; flag=-1, dy=6, dx=-1
    FCB $FF,$09,$05          ; flag=-1, dy=9, dx=5
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$0E,$05          ; flag=-1, dy=14, dx=5
    FCB $FF,$E5,$DE          ; flag=-1, dy=-27, dx=-34
    FCB $FF,$11,$0E          ; flag=-1, dy=17, dx=14
    FCB $FF,$F7,$E6          ; flag=-1, dy=-9, dx=-26
    FCB 2                ; End marker (path complete)

_FUJI_BG_PATH4:    ; Path 4
    FCB 80              ; path4: intensity
    FCB $E8,$84,0,0        ; path4: header (y=-24, x=-124)
    FCB $FF,$0A,$1E          ; flag=-1, dy=10, dx=30
    FCB $FF,$0E,$1E          ; flag=-1, dy=14, dx=30
    FCB $FF,$20,$2C          ; flag=-1, dy=32, dx=44
    FCB $FF,$0E,$0E          ; flag=-1, dy=14, dx=14
    FCB $FF,$FE,$03          ; flag=-1, dy=-2, dx=3
    FCB $FF,$03,$04          ; flag=-1, dy=3, dx=4
    FCB $FF,$FE,$04          ; flag=-1, dy=-2, dx=4
    FCB $FF,$03,$0B          ; flag=-1, dy=3, dx=11
    FCB $FF,$FD,$06          ; flag=-1, dy=-3, dx=6
    FCB $FF,$03,$03          ; flag=-1, dy=3, dx=3
    FCB $FF,$EB,$11          ; flag=-1, dy=-21, dx=17
    FCB $FF,$E4,$27          ; flag=-1, dy=-28, dx=39
    FCB $FF,$EC,$2C          ; flag=-1, dy=-20, dx=44
    FCB 2                ; End marker (path complete)
; Generated from hook.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 10
; X bounds: min=-6, max=6, width=12
; Center: (0, 0)

_HOOK_WIDTH EQU 12
_HOOK_HALF_WIDTH EQU 6
_HOOK_HEIGHT EQU 15
_HOOK_HALF_HEIGHT EQU 7
_HOOK_CENTER_X EQU 0
_HOOK_CENTER_Y EQU 0

_HOOK_VECTORS:  ; Main entry (header + 1 path(s))
    FDB 1               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _HOOK_PATH0        ; pointer to path 0

_HOOK_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FC,$FA,0,0        ; path0: header (y=-4, x=-6)
    FCB $FF,$0B,$06          ; flag=-1, dy=11, dx=6
    FCB $FF,$F5,$06          ; flag=-1, dy=-11, dx=6
    FCB $FF,$04,$FB          ; flag=-1, dy=4, dx=-5
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$FC,$FB          ; flag=-1, dy=-4, dx=-5
    FCB 2                ; End marker (path complete)
; Generated from keirin_bg.vec (Malban Draw_Sync_List format)
; Total paths: 3, points: 11
; X bounds: min=-100, max=100, width=200
; Center: (0, 10)

_KEIRIN_BG_WIDTH EQU 200
_KEIRIN_BG_HALF_WIDTH EQU 100
_KEIRIN_BG_HEIGHT EQU 80
_KEIRIN_BG_HALF_HEIGHT EQU 40
_KEIRIN_BG_CENTER_X EQU 0
_KEIRIN_BG_CENTER_Y EQU 10

_KEIRIN_BG_VECTORS:  ; Main entry (header + 3 path(s))
    FDB 3               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _KEIRIN_BG_PATH0        ; pointer to path 0
    FDB _KEIRIN_BG_PATH1        ; pointer to path 1
    FDB _KEIRIN_BG_PATH2        ; pointer to path 2

_KEIRIN_BG_PATH0:    ; Path 0
    FCB 80              ; path0: intensity
    FCB $14,$F6,0,0        ; path0: header (y=20, x=-10)
    FCB $FF,$F6,$E2          ; flag=-1, dy=-10, dx=-30
    FCB $FF,$E2,$E2          ; flag=-1, dy=-30, dx=-30
    FCB 2                ; End marker (path complete)

_KEIRIN_BG_PATH1:    ; Path 1
    FCB 100              ; path1: intensity
    FCB $D8,$9C,0,0        ; path1: header (y=-40, x=-100)
    FCB $FF,$46,$32          ; flag=-1, dy=70, dx=50
    FCB $FF,$0A,$32          ; flag=-1, dy=10, dx=50
    FCB $FF,$F6,$32          ; flag=-1, dy=-10, dx=50
    FCB $FF,$BA,$32          ; flag=-1, dy=-70, dx=50
    FCB 2                ; End marker (path complete)

_KEIRIN_BG_PATH2:    ; Path 2
    FCB 80              ; path2: intensity
    FCB $EC,$46,0,0        ; path2: header (y=-20, x=70)
    FCB $FF,$1E,$E2          ; flag=-1, dy=30, dx=-30
    FCB $FF,$0A,$E2          ; flag=-1, dy=10, dx=-30
    FCB 2                ; End marker (path complete)
; Generated from kilimanjaro_bg.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 13
; X bounds: min=-100, max=100, width=200
; Center: (0, 12)

_KILIMANJARO_BG_WIDTH EQU 200
_KILIMANJARO_BG_HALF_WIDTH EQU 100
_KILIMANJARO_BG_HEIGHT EQU 85
_KILIMANJARO_BG_HALF_HEIGHT EQU 42
_KILIMANJARO_BG_CENTER_X EQU 0
_KILIMANJARO_BG_CENTER_Y EQU 12

_KILIMANJARO_BG_VECTORS:  ; Main entry (header + 4 path(s))
    FDB 4               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _KILIMANJARO_BG_PATH0        ; pointer to path 0
    FDB _KILIMANJARO_BG_PATH1        ; pointer to path 1
    FDB _KILIMANJARO_BG_PATH2        ; pointer to path 2
    FDB _KILIMANJARO_BG_PATH3        ; pointer to path 3

_KILIMANJARO_BG_PATH0:    ; Path 0
    FCB 110              ; path0: intensity
    FCB $1C,$00,0,0        ; path0: header (y=28, x=0)
    FCB $FF,$0F,$00          ; flag=-1, dy=15, dx=0
    FCB $FF,$F1,$E2          ; flag=-1, dy=-15, dx=-30
    FCB 2                ; End marker (path complete)

_KILIMANJARO_BG_PATH1:    ; Path 1
    FCB 90              ; path1: intensity
    FCB $08,$D8,0,0        ; path1: header (y=8, x=-40)
    FCB $FF,$EC,$E2          ; flag=-1, dy=-20, dx=-30
    FCB 2                ; End marker (path complete)

_KILIMANJARO_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $D6,$9C,0,0        ; path2: header (y=-42, x=-100)
    FCB $FF,$3C,$32          ; flag=-1, dy=60, dx=50
    FCB $FF,$19,$32          ; flag=-1, dy=25, dx=50
    FCB $FF,$E7,$32          ; flag=-1, dy=-25, dx=50
    FCB $FF,$C4,$32          ; flag=-1, dy=-60, dx=50
    FCB 2                ; End marker (path complete)

_KILIMANJARO_BG_PATH3:    ; Path 3
    FCB 110              ; path3: intensity
    FCB $1C,$1E,0,0        ; path3: header (y=28, x=30)
    FCB $FF,$0F,$E2          ; flag=-1, dy=15, dx=-30
    FCB $FF,$F1,$00          ; flag=-1, dy=-15, dx=0
    FCB 2                ; End marker (path complete)
; Generated from leningrad_bg.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 21
; X bounds: min=-30, max=30, width=60
; Center: (0, 30)

_LENINGRAD_BG_WIDTH EQU 60
_LENINGRAD_BG_HALF_WIDTH EQU 30
_LENINGRAD_BG_HEIGHT EQU 80
_LENINGRAD_BG_HALF_HEIGHT EQU 40
_LENINGRAD_BG_CENTER_X EQU 0
_LENINGRAD_BG_CENTER_Y EQU 30

_LENINGRAD_BG_VECTORS:  ; Main entry (header + 5 path(s))
    FDB 5               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _LENINGRAD_BG_PATH0        ; pointer to path 0
    FDB _LENINGRAD_BG_PATH1        ; pointer to path 1
    FDB _LENINGRAD_BG_PATH2        ; pointer to path 2
    FDB _LENINGRAD_BG_PATH3        ; pointer to path 3
    FDB _LENINGRAD_BG_PATH4        ; pointer to path 4

_LENINGRAD_BG_PATH0:    ; Path 0
    FCB 90              ; path0: intensity
    FCB $EC,$0A,0,0        ; path0: header (y=-20, x=10)
    FCB $FF,$0F,$00          ; flag=-1, dy=15, dx=0
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$F1,$00          ; flag=-1, dy=-15, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_LENINGRAD_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $05,$19,0,0        ; path1: header (y=5, x=25)
    FCB $FF,$14,$F6          ; flag=-1, dy=20, dx=-10
    FCB $FF,$05,$F1          ; flag=-1, dy=5, dx=-15
    FCB $FF,$FB,$F1          ; flag=-1, dy=-5, dx=-15
    FCB $FF,$EC,$F6          ; flag=-1, dy=-20, dx=-10
    FCB 2                ; End marker (path complete)

_LENINGRAD_BG_PATH2:    ; Path 2
    FCB 110              ; path2: intensity
    FCB $05,$E2,0,0        ; path2: header (y=5, x=-30)
    FCB $FF,$D3,$00          ; flag=-1, dy=-45, dx=0
    FCB $FF,$00,$3C          ; flag=-1, dy=0, dx=60
    FCB $FF,$2D,$00          ; flag=-1, dy=45, dx=0
    FCB 2                ; End marker (path complete)

_LENINGRAD_BG_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $1E,$00,0,0        ; path3: header (y=30, x=0)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_LENINGRAD_BG_PATH4:    ; Path 4
    FCB 90              ; path4: intensity
    FCB $EC,$EC,0,0        ; path4: header (y=-20, x=-20)
    FCB $FF,$0F,$00          ; flag=-1, dy=15, dx=0
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$F1,$00          ; flag=-1, dy=-15, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)
; Generated from location_marker.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 10
; X bounds: min=-11, max=11, width=22
; Center: (0, 1)

_LOCATION_MARKER_WIDTH EQU 22
_LOCATION_MARKER_HALF_WIDTH EQU 11
_LOCATION_MARKER_HEIGHT EQU 22
_LOCATION_MARKER_HALF_HEIGHT EQU 11
_LOCATION_MARKER_CENTER_X EQU 0
_LOCATION_MARKER_CENTER_Y EQU 1

_LOCATION_MARKER_VECTORS:  ; Main entry (header + 1 path(s))
    FDB 1               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _LOCATION_MARKER_PATH0        ; pointer to path 0

_LOCATION_MARKER_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $0B,$00,0,0        ; path0: header (y=11, x=0)
    FCB $FF,$F8,$04          ; flag=-1, dy=-8, dx=4
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$F9,$FC          ; flag=-1, dy=-7, dx=-4
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB $FF,$05,$F9          ; flag=-1, dy=5, dx=-7
    FCB $FF,$FB,$F9          ; flag=-1, dy=-5, dx=-7
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB $FF,$07,$FC          ; flag=-1, dy=7, dx=-4
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$08,$04          ; flag=-1, dy=8, dx=4
    FCB 2                ; End marker (path complete)
; Generated from logo.vec (Malban Draw_Sync_List format)
; Total paths: 7, points: 65
; X bounds: min=-82, max=81, width=163
; Center: (0, 0)

_LOGO_WIDTH EQU 163
_LOGO_HALF_WIDTH EQU 81
_LOGO_HEIGHT EQU 76
_LOGO_HALF_HEIGHT EQU 38
_LOGO_CENTER_X EQU 0
_LOGO_CENTER_Y EQU 0

_LOGO_VECTORS:  ; Main entry (header + 6 path(s))
    FDB 6               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _LOGO_PATH0        ; pointer to path 0
    FDB _LOGO_PATH1        ; pointer to path 1
    FDB _LOGO_PATH2        ; pointer to path 2
    FDB _LOGO_PATH3        ; pointer to path 3
    FDB _LOGO_PATH4        ; pointer to path 4
    FDB _LOGO_PATH5        ; pointer to path 5

_LOGO_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $04,$F5,0,0        ; path0: header (y=4, x=-11)
    FCB $FF,$FA,$03          ; flag=-1, dy=-6, dx=3
    FCB $FF,$FE,$F9          ; flag=-1, dy=-2, dx=-7
    FCB $FF,$0A,$03          ; flag=-1, dy=10, dx=3
    FCB 2                ; End marker (path complete)

_LOGO_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $FB,$E3,0,0        ; path1: header (y=-5, x=-29)
    FCB $FF,$E7,$F8          ; flag=-1, dy=-25, dx=-8
    FCB $FF,$04,$10          ; flag=-1, dy=4, dx=16
    FCB $FF,$0C,$02          ; flag=-1, dy=12, dx=2
    FCB $FF,$03,$0B          ; flag=-1, dy=3, dx=11
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$03,$0D          ; flag=-1, dy=3, dx=13
    FCB $FF,$22,$F7          ; flag=-1, dy=34, dx=-9
    FCB $FF,$FD,$F1          ; flag=-1, dy=-3, dx=-15
    FCB $FF,$F5,$FF          ; flag=-1, dy=-11, dx=-1
    FCB $FF,$F5,$F7          ; flag=-1, dy=-11, dx=-9
    FCB 2                ; End marker (path complete)

_LOGO_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $07,$CE,0,0        ; path2: header (y=7, x=-50)
    FCB $FF,$F8,$02          ; flag=-1, dy=-8, dx=2
    FCB $FF,$07,$08          ; flag=-1, dy=7, dx=8
    FCB $FF,$01,$F6          ; flag=-1, dy=1, dx=-10
    FCB 2                ; End marker (path complete)

_LOGO_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $13,$AE,0,0        ; path3: header (y=19, x=-82)
    FCB $FF,$EF,$06          ; flag=-1, dy=-17, dx=6
    FCB $FF,$02,$07          ; flag=-1, dy=2, dx=7
    FCB $FF,$D6,$09          ; flag=-1, dy=-42, dx=9
    FCB $FF,$0B,$11          ; flag=-1, dy=11, dx=17
    FCB $FF,$0C,$FC          ; flag=-1, dy=12, dx=-4
    FCB $FF,$0D,$10          ; flag=-1, dy=13, dx=16
    FCB $FF,$0B,$09          ; flag=-1, dy=11, dx=9
    FCB $FF,$0C,$01          ; flag=-1, dy=12, dx=1
    FCB $FF,$08,$F8          ; flag=-1, dy=8, dx=-8
    FCB $FF,$02,$F0          ; flag=-1, dy=2, dx=-16
    FCB $FF,$F4,$DB          ; flag=-1, dy=-12, dx=-37
    FCB 2                ; End marker (path complete)

_LOGO_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $F3,$0A,0,0        ; path4: header (y=-13, x=10)
    FCB $FF,$29,$02          ; flag=-1, dy=41, dx=2
    FCB $FF,$02,$0D          ; flag=-1, dy=2, dx=13
    FCB $FF,$EB,$0A          ; flag=-1, dy=-21, dx=10
    FCB $FF,$1A,$07          ; flag=-1, dy=26, dx=7
    FCB $FF,$03,$14          ; flag=-1, dy=3, dx=20
    FCB $FF,$D8,$EF          ; flag=-1, dy=-40, dx=-17
    FCB $FF,$FE,$F3          ; flag=-1, dy=-2, dx=-13
    FCB $FF,$0D,$F8          ; flag=-1, dy=13, dx=-8
    FCB $FF,$EE,$FC          ; flag=-1, dy=-18, dx=-4
    FCB $FF,$FC,$F6          ; flag=-1, dy=-4, dx=-10
    FCB 2                ; End marker (path complete)

_LOGO_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $FC,$23,0,0        ; path5: header (y=-4, x=35)
    FCB $FF,$F5,$08          ; flag=-1, dy=-11, dx=8
    FCB $FF,$FC,$10          ; flag=-1, dy=-4, dx=16
    FCB $FF,$07,$12          ; flag=-1, dy=7, dx=18
    FCB $FF,$0D,$03          ; flag=-1, dy=13, dx=3
    FCB $FF,$FE,$E9          ; flag=-1, dy=-2, dx=-23
    FCB $FF,$FB,$FF          ; flag=-1, dy=-5, dx=-1
    FCB $FF,$FD,$06          ; flag=-1, dy=-3, dx=6
    FCB $FF,$02,$F4          ; flag=-1, dy=2, dx=-12
    FCB $FF,$09,$FF          ; flag=-1, dy=9, dx=-1
    FCB $FF,$0C,$09          ; flag=-1, dy=12, dx=9
    FCB $FF,$F8,$0B          ; flag=-1, dy=-8, dx=11
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB $FF,$0C,$F8          ; flag=-1, dy=12, dx=-8
    FCB $FF,$03,$F0          ; flag=-1, dy=3, dx=-16
    FCB $FF,$FB,$FC          ; flag=-1, dy=-5, dx=-4
    FCB 2                ; End marker (path complete)
; Generated from london_bg.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 16
; X bounds: min=-20, max=20, width=40
; Center: (0, 15)

_LONDON_BG_WIDTH EQU 40
_LONDON_BG_HALF_WIDTH EQU 20
_LONDON_BG_HEIGHT EQU 90
_LONDON_BG_HALF_HEIGHT EQU 45
_LONDON_BG_CENTER_X EQU 0
_LONDON_BG_CENTER_Y EQU 15

_LONDON_BG_VECTORS:  ; Main entry (header + 4 path(s))
    FDB 4               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _LONDON_BG_PATH0        ; pointer to path 0
    FDB _LONDON_BG_PATH1        ; pointer to path 1
    FDB _LONDON_BG_PATH2        ; pointer to path 2
    FDB _LONDON_BG_PATH3        ; pointer to path 3

_LONDON_BG_PATH0:    ; Path 0
    FCB 110              ; path0: intensity
    FCB $D3,$EC,0,0        ; path0: header (y=-45, x=-20)
    FCB $FF,$46,$00          ; flag=-1, dy=70, dx=0
    FCB $FF,$00,$28          ; flag=-1, dy=0, dx=40
    FCB $FF,$BA,$00          ; flag=-1, dy=-70, dx=0
    FCB 2                ; End marker (path complete)

_LONDON_BG_PATH1:    ; Path 1
    FCB 120              ; path1: intensity
    FCB $19,$14,0,0        ; path1: header (y=25, x=20)
    FCB $FF,$0A,$FB          ; flag=-1, dy=10, dx=-5
    FCB $FF,$00,$E2          ; flag=-1, dy=0, dx=-30
    FCB $FF,$F6,$FB          ; flag=-1, dy=-10, dx=-5
    FCB 2                ; End marker (path complete)

_LONDON_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $23,$F1,0,0        ; path2: header (y=35, x=-15)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$1E          ; flag=-1, dy=0, dx=30
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$00,$E2          ; flag=-1, dy=0, dx=-30
    FCB 2                ; End marker (path complete)

_LONDON_BG_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $28,$00,0,0        ; path3: header (y=40, x=0)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$FB,$08          ; flag=-1, dy=-5, dx=8
    FCB 2                ; End marker (path complete)
; Generated from map.vec (Malban Draw_Sync_List format)
; Total paths: 15, points: 165
; X bounds: min=-127, max=115, width=242
; Center: (-6, -3)

_MAP_WIDTH EQU 242
_MAP_HALF_WIDTH EQU 121
_MAP_HEIGHT EQU 162
_MAP_HALF_HEIGHT EQU 81
_MAP_CENTER_X EQU -6
_MAP_CENTER_Y EQU -3

_MAP_VECTORS:  ; Main entry (header + 15 path(s))
    FDB 15               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _MAP_PATH0        ; pointer to path 0
    FDB _MAP_PATH1        ; pointer to path 1
    FDB _MAP_PATH2        ; pointer to path 2
    FDB _MAP_PATH3        ; pointer to path 3
    FDB _MAP_PATH4        ; pointer to path 4
    FDB _MAP_PATH5        ; pointer to path 5
    FDB _MAP_PATH6        ; pointer to path 6
    FDB _MAP_PATH7        ; pointer to path 7
    FDB _MAP_PATH8        ; pointer to path 8
    FDB _MAP_PATH9        ; pointer to path 9
    FDB _MAP_PATH10        ; pointer to path 10
    FDB _MAP_PATH11        ; pointer to path 11
    FDB _MAP_PATH12        ; pointer to path 12
    FDB _MAP_PATH13        ; pointer to path 13
    FDB _MAP_PATH14        ; pointer to path 14

_MAP_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $DD,$1A,0,0        ; path0: header (y=-35, x=26)
    FCB $FF,$09,$08          ; flag=-1, dy=9, dx=8
    FCB $FF,$01,$FA          ; flag=-1, dy=1, dx=-6
    FCB $FF,$F7,$FA          ; flag=-1, dy=-9, dx=-6
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB 2                ; End marker (path complete)

_MAP_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $EE,$57,0,0        ; path1: header (y=-18, x=87)
    FCB $FF,$F8,$05          ; flag=-1, dy=-8, dx=5
    FCB $FF,$F9,$FF          ; flag=-1, dy=-7, dx=-1
    FCB $FF,$05,$FA          ; flag=-1, dy=5, dx=-6
    FCB $FF,$0A,$02          ; flag=-1, dy=10, dx=2
    FCB 2                ; End marker (path complete)

_MAP_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $ED,$66,0,0        ; path2: header (y=-19, x=102)
    FCB $FF,$F1,$00          ; flag=-1, dy=-15, dx=0
    FCB $FF,$04,$F8          ; flag=-1, dy=4, dx=-8
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$06,$09          ; flag=-1, dy=6, dx=9
    FCB 2                ; End marker (path complete)

_MAP_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $E6,$72,0,0        ; path3: header (y=-26, x=114)
    FCB $FF,$FD,$FB          ; flag=-1, dy=-3, dx=-5
    FCB $FF,$FB,$08          ; flag=-1, dy=-5, dx=8
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$04,$FD          ; flag=-1, dy=4, dx=-3
    FCB 2                ; End marker (path complete)

_MAP_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $0E,$69,0,0        ; path4: header (y=14, x=105)
    FCB $FF,$08,$FC          ; flag=-1, dy=8, dx=-4
    FCB $FF,$03,$04          ; flag=-1, dy=3, dx=4
    FCB $FF,$F5,$00          ; flag=-1, dy=-11, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $21,$6D,0,0        ; path5: header (y=33, x=109)
    FCB $FF,$F9,$FD          ; flag=-1, dy=-7, dx=-3
    FCB $FF,$FB,$02          ; flag=-1, dy=-5, dx=2
    FCB $FF,$FF,$03          ; flag=-1, dy=-1, dx=3
    FCB $FF,$05,$04          ; flag=-1, dy=5, dx=4
    FCB $FF,$08,$FC          ; flag=-1, dy=8, dx=-4
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB 2                ; End marker (path complete)

_MAP_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $24,$69,0,0        ; path6: header (y=36, x=105)
    FCB $FF,$04,$07          ; flag=-1, dy=4, dx=7
    FCB $FF,$04,$F9          ; flag=-1, dy=4, dx=-7
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $BD,$70,0,0        ; path7: header (y=-67, x=112)
    FCB $FF,$08,$05          ; flag=-1, dy=8, dx=5
    FCB $FF,$14,$00          ; flag=-1, dy=20, dx=0
    FCB $FF,$06,$FB          ; flag=-1, dy=6, dx=-5
    FCB $FF,$F8,$FE          ; flag=-1, dy=-8, dx=-2
    FCB $FF,$06,$EE          ; flag=-1, dy=6, dx=-18
    FCB $FF,$F3,$F1          ; flag=-1, dy=-13, dx=-15
    FCB $FF,$F5,$07          ; flag=-1, dy=-11, dx=7
    FCB $FF,$03,$0C          ; flag=-1, dy=3, dx=12
    FCB $FF,$F4,$10          ; flag=-1, dy=-12, dx=16
    FCB 2                ; End marker (path complete)

_MAP_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $21,$D7,0,0        ; path8: header (y=33, x=-41)
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$01,$0D          ; flag=-1, dy=1, dx=13
    FCB $FF,$06,$12          ; flag=-1, dy=6, dx=18
    FCB $FF,$F7,$0C          ; flag=-1, dy=-9, dx=12
    FCB $FF,$FF,$DE          ; flag=-1, dy=-1, dx=-34
    FCB $FF,$F5,$F6          ; flag=-1, dy=-11, dx=-10
    FCB $FF,$F5,$00          ; flag=-1, dy=-11, dx=0
    FCB $FF,$F8,$08          ; flag=-1, dy=-8, dx=8
    FCB $FF,$00,$10          ; flag=-1, dy=0, dx=16
    FCB $FF,$F7,$08          ; flag=-1, dy=-9, dx=8
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB $FF,$F3,$0D          ; flag=-1, dy=-13, dx=13
    FCB $FF,$14,$13          ; flag=-1, dy=20, dx=19
    FCB $FF,$0D,$02          ; flag=-1, dy=13, dx=2
    FCB $FF,$0E,$09          ; flag=-1, dy=14, dx=9
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$0E,$F4          ; flag=-1, dy=14, dx=-12
    FCB $FF,$03,$03          ; flag=-1, dy=3, dx=3
    FCB $FF,$F2,$0D          ; flag=-1, dy=-14, dx=13
    FCB $FF,$0B,$07          ; flag=-1, dy=11, dx=7
    FCB $FF,$07,$FD          ; flag=-1, dy=7, dx=-3
    FCB $FF,$FB,$07          ; flag=-1, dy=-5, dx=7
    FCB $FF,$E0,$10          ; flag=-1, dy=-32, dx=16
    FCB $FF,$16,$09          ; flag=-1, dy=22, dx=9
    FCB $FF,$FA,$03          ; flag=-1, dy=-6, dx=3
    FCB $FF,$FB,$FF          ; flag=-1, dy=-5, dx=-1
    FCB $FF,$F2,$0A          ; flag=-1, dy=-14, dx=10
    FCB $FF,$04,$03          ; flag=-1, dy=4, dx=3
    FCB $FF,$09,$FB          ; flag=-1, dy=9, dx=-5
    FCB $FF,$01,$0A          ; flag=-1, dy=1, dx=10
    FCB $FF,$08,$02          ; flag=-1, dy=8, dx=2
    FCB $FF,$05,$05          ; flag=-1, dy=5, dx=5
    FCB $FF,$1E,$02          ; flag=-1, dy=30, dx=2
    FCB $FF,$0C,$FA          ; flag=-1, dy=12, dx=-6
    FCB $FF,$FE,$10          ; flag=-1, dy=-2, dx=16
    FCB $FF,$FA,$06          ; flag=-1, dy=-6, dx=6
    FCB $FF,$07,$02          ; flag=-1, dy=7, dx=2
    FCB $FF,$05,$04          ; flag=-1, dy=5, dx=4
    FCB $FF,$12,$E0          ; flag=-1, dy=18, dx=-32
    FCB $FF,$01,$EC          ; flag=-1, dy=1, dx=-20
    FCB $FF,$04,$FD          ; flag=-1, dy=4, dx=-3
    FCB $FF,$00,$DF          ; flag=-1, dy=0, dx=-33
    FCB $FF,$F8,$F6          ; flag=-1, dy=-8, dx=-10
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$F7,$F4          ; flag=-1, dy=-9, dx=-12
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$EB,$DA          ; flag=-1, dy=-21, dx=-38
    FCB 2                ; End marker (path complete)

_MAP_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $34,$E5,0,0        ; path9: header (y=52, x=-27)
    FCB $FF,$06,$0A          ; flag=-1, dy=6, dx=10
    FCB $FF,$06,$FE          ; flag=-1, dy=6, dx=-2
    FCB $FF,$02,$05          ; flag=-1, dy=2, dx=5
    FCB $FF,$FB,$FE          ; flag=-1, dy=-5, dx=-2
    FCB $FF,$F6,$02          ; flag=-1, dy=-10, dx=2
    FCB $FF,$FF,$F4          ; flag=-1, dy=-1, dx=-12
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB 2                ; End marker (path complete)

_MAP_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $38,$DE,0,0        ; path10: header (y=56, x=-34)
    FCB $FF,$04,$06          ; flag=-1, dy=4, dx=6
    FCB $FF,$FC,$01          ; flag=-1, dy=-4, dx=1
    FCB $FF,$FD,$FC          ; flag=-1, dy=-3, dx=-4
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $4C,$B0,0,0        ; path11: header (y=76, x=-80)
    FCB $FF,$FC,$0D          ; flag=-1, dy=-4, dx=13
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$FA,$08          ; flag=-1, dy=-6, dx=8
    FCB $FF,$09,$06          ; flag=-1, dy=9, dx=6
    FCB $FF,$09,$F2          ; flag=-1, dy=9, dx=-14
    FCB $FF,$FF,$F6          ; flag=-1, dy=-1, dx=-10
    FCB $FF,$FC,$FD          ; flag=-1, dy=-4, dx=-3
    FCB 2                ; End marker (path complete)

_MAP_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $2C,$88,0,0        ; path12: header (y=44, x=-120)
    FCB $FF,$21,$FF          ; flag=-1, dy=33, dx=-1
    FCB $FF,$FA,$19          ; flag=-1, dy=-6, dx=25
    FCB $FF,$F6,$12          ; flag=-1, dy=-10, dx=18
    FCB $FF,$F8,$FF          ; flag=-1, dy=-8, dx=-1
    FCB $FF,$FC,$0B          ; flag=-1, dy=-4, dx=11
    FCB $FF,$0C,$03          ; flag=-1, dy=12, dx=3
    FCB $FF,$F0,$0B          ; flag=-1, dy=-16, dx=11
    FCB $FF,$E8,$ED          ; flag=-1, dy=-24, dx=-19
    FCB $FF,$07,$FA          ; flag=-1, dy=7, dx=-6
    FCB $FF,$F7,$F2          ; flag=-1, dy=-9, dx=-14
    FCB $FF,$F3,$02          ; flag=-1, dy=-13, dx=2
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$F7,$0A          ; flag=-1, dy=-9, dx=10
    FCB $FF,$02,$EA          ; flag=-1, dy=2, dx=-22
    FCB $FF,$1C,$E9          ; flag=-1, dy=28, dx=-23
    FCB $FF,$09,$07          ; flag=-1, dy=9, dx=7
    FCB $FF,$09,$F8          ; flag=-1, dy=9, dx=-8
    FCB 2                ; End marker (path complete)

_MAP_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $04,$BE,0,0        ; path13: header (y=4, x=-66)
    FCB $FF,$ED,$F8          ; flag=-1, dy=-19, dx=-8
    FCB $FF,$F9,$06          ; flag=-1, dy=-7, dx=6
    FCB $FF,$E0,$05          ; flag=-1, dy=-32, dx=5
    FCB $FF,$19,$14          ; flag=-1, dy=25, dx=20
    FCB $FF,$FF,$08          ; flag=-1, dy=-1, dx=8
    FCB $FF,$10,$00          ; flag=-1, dy=16, dx=0
    FCB $FF,$03,$F7          ; flag=-1, dy=3, dx=-9
    FCB $FF,$09,$F8          ; flag=-1, dy=9, dx=-8
    FCB $FF,$07,$F3          ; flag=-1, dy=7, dx=-13
    FCB 2                ; End marker (path complete)

_MAP_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $B0,$AE,0,0        ; path14: header (y=-80, x=-82)
    FCB $FF,$0D,$0C          ; flag=-1, dy=13, dx=12
    FCB $FF,$FB,$0D          ; flag=-1, dy=-5, dx=13
    FCB $FF,$F9,$08          ; flag=-1, dy=-7, dx=8
    FCB $FF,$FE,$DF          ; flag=-1, dy=-2, dx=-33
    FCB 2                ; End marker (path complete)
; Generated from mayan_bg.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 20
; X bounds: min=-80, max=80, width=160
; Center: (0, 10)

_MAYAN_BG_WIDTH EQU 160
_MAYAN_BG_HALF_WIDTH EQU 80
_MAYAN_BG_HEIGHT EQU 80
_MAYAN_BG_HALF_HEIGHT EQU 40
_MAYAN_BG_CENTER_X EQU 0
_MAYAN_BG_CENTER_Y EQU 10

_MAYAN_BG_VECTORS:  ; Main entry (header + 5 path(s))
    FDB 5               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _MAYAN_BG_PATH0        ; pointer to path 0
    FDB _MAYAN_BG_PATH1        ; pointer to path 1
    FDB _MAYAN_BG_PATH2        ; pointer to path 2
    FDB _MAYAN_BG_PATH3        ; pointer to path 3
    FDB _MAYAN_BG_PATH4        ; pointer to path 4

_MAYAN_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $F6,$D8,0,0        ; path0: header (y=-10, x=-40)
    FCB $FF,$28,$00          ; flag=-1, dy=40, dx=0
    FCB $FF,$0A,$0A          ; flag=-1, dy=10, dx=10
    FCB $FF,$00,$3C          ; flag=-1, dy=0, dx=60
    FCB $FF,$F6,$0A          ; flag=-1, dy=-10, dx=10
    FCB $FF,$D8,$00          ; flag=-1, dy=-40, dx=0
    FCB 2                ; End marker (path complete)

_MAYAN_BG_PATH1:    ; Path 1
    FCB 120              ; path1: intensity
    FCB $EC,$32,0,0        ; path1: header (y=-20, x=50)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$9C          ; flag=-1, dy=0, dx=-100
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_MAYAN_BG_PATH2:    ; Path 2
    FCB 110              ; path2: intensity
    FCB $E2,$C4,0,0        ; path2: header (y=-30, x=-60)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$78          ; flag=-1, dy=0, dx=120
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_MAYAN_BG_PATH3:    ; Path 3
    FCB 110              ; path3: intensity
    FCB $D8,$46,0,0        ; path3: header (y=-40, x=70)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$BA          ; sub-seg 1/2 of line 1: dy=0, dx=-70
    FCB $FF,$00,$BA          ; sub-seg 2/2 of line 1: dy=0, dx=-70
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_MAYAN_BG_PATH4:    ; Path 4
    FCB 100              ; path4: intensity
    FCB $D8,$B0,0,0        ; path4: header (y=-40, x=-80)
    FCB $FF,$00,$50          ; sub-seg 1/2 of line 0: dy=0, dx=80
    FCB $FF,$00,$50          ; sub-seg 2/2 of line 0: dy=0, dx=80
    FCB 2                ; End marker (path complete)
; Generated from newyork_bg.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 22
; X bounds: min=-25, max=25, width=50
; Center: (0, 27)

_NEWYORK_BG_WIDTH EQU 50
_NEWYORK_BG_HALF_WIDTH EQU 25
_NEWYORK_BG_HEIGHT EQU 75
_NEWYORK_BG_HALF_HEIGHT EQU 37
_NEWYORK_BG_CENTER_X EQU 0
_NEWYORK_BG_CENTER_Y EQU 27

_NEWYORK_BG_VECTORS:  ; Main entry (header + 5 path(s))
    FDB 5               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _NEWYORK_BG_PATH0        ; pointer to path 0
    FDB _NEWYORK_BG_PATH1        ; pointer to path 1
    FDB _NEWYORK_BG_PATH2        ; pointer to path 2
    FDB _NEWYORK_BG_PATH3        ; pointer to path 3
    FDB _NEWYORK_BG_PATH4        ; pointer to path 4

_NEWYORK_BG_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $DB,$E7,0,0        ; path0: header (y=-37, x=-25)
    FCB $FF,$00,$32          ; flag=-1, dy=0, dx=50
    FCB 2                ; End marker (path complete)

_NEWYORK_BG_PATH1:    ; Path 1
    FCB 120              ; path1: intensity
    FCB $0D,$14,0,0        ; path1: header (y=13, x=20)
    FCB $FF,$0A,$FB          ; flag=-1, dy=10, dx=-5
    FCB $FF,$FB,$FB          ; flag=-1, dy=-5, dx=-5
    FCB $FF,$07,$FB          ; flag=-1, dy=7, dx=-5
    FCB $FF,$F9,$FB          ; flag=-1, dy=-7, dx=-5
    FCB $FF,$07,$FB          ; flag=-1, dy=7, dx=-5
    FCB $FF,$F9,$FB          ; flag=-1, dy=-7, dx=-5
    FCB $FF,$05,$FB          ; flag=-1, dy=5, dx=-5
    FCB $FF,$F6,$FB          ; flag=-1, dy=-10, dx=-5
    FCB 2                ; End marker (path complete)

_NEWYORK_BG_PATH2:    ; Path 2
    FCB 110              ; path2: intensity
    FCB $0D,$F1,0,0        ; path2: header (y=13, x=-15)
    FCB $FF,$CE,$00          ; flag=-1, dy=-50, dx=0
    FCB $FF,$00,$1E          ; flag=-1, dy=0, dx=30
    FCB $FF,$32,$00          ; flag=-1, dy=50, dx=0
    FCB 2                ; End marker (path complete)

_NEWYORK_BG_PATH3:    ; Path 3
    FCB 110              ; path3: intensity
    FCB $0D,$00,0,0        ; path3: header (y=13, x=0)
    FCB $FF,$0F,$0A          ; flag=-1, dy=15, dx=10
    FCB $FF,$05,$F6          ; flag=-1, dy=5, dx=-10
    FCB 2                ; End marker (path complete)

_NEWYORK_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $21,$FB,0,0        ; path4: header (y=33, x=-5)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)
; Generated from paris_bg.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 15
; X bounds: min=-50, max=50, width=100
; Center: (0, 17)

_PARIS_BG_WIDTH EQU 100
_PARIS_BG_HALF_WIDTH EQU 50
_PARIS_BG_HEIGHT EQU 95
_PARIS_BG_HALF_HEIGHT EQU 47
_PARIS_BG_CENTER_X EQU 0
_PARIS_BG_CENTER_Y EQU 17

_PARIS_BG_VECTORS:  ; Main entry (header + 5 path(s))
    FDB 5               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PARIS_BG_PATH0        ; pointer to path 0
    FDB _PARIS_BG_PATH1        ; pointer to path 1
    FDB _PARIS_BG_PATH2        ; pointer to path 2
    FDB _PARIS_BG_PATH3        ; pointer to path 3
    FDB _PARIS_BG_PATH4        ; pointer to path 4

_PARIS_BG_PATH0:    ; Path 0
    FCB 90              ; path0: intensity
    FCB $EF,$EC,0,0        ; path0: header (y=-17, x=-20)
    FCB $FF,$00,$28          ; flag=-1, dy=0, dx=40
    FCB 2                ; End marker (path complete)

_PARIS_BG_PATH1:    ; Path 1
    FCB 100              ; path1: intensity
    FCB $0D,$0A,0,0        ; path1: header (y=13, x=10)
    FCB $FF,$E2,$0A          ; flag=-1, dy=-30, dx=10
    FCB $FF,$E2,$1E          ; flag=-1, dy=-30, dx=30
    FCB 2                ; End marker (path complete)

_PARIS_BG_PATH2:    ; Path 2
    FCB 110              ; path2: intensity
    FCB $0D,$0A,0,0        ; path2: header (y=13, x=10)
    FCB $FF,$14,$FB          ; flag=-1, dy=20, dx=-5
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$EC,$FB          ; flag=-1, dy=-20, dx=-5
    FCB 2                ; End marker (path complete)

_PARIS_BG_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $0D,$F6,0,0        ; path3: header (y=13, x=-10)
    FCB $FF,$E2,$F6          ; flag=-1, dy=-30, dx=-10
    FCB $FF,$E2,$E2          ; flag=-1, dy=-30, dx=-30
    FCB 2                ; End marker (path complete)

_PARIS_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $21,$FB,0,0        ; path4: header (y=33, x=-5)
    FCB $FF,$0F,$05          ; flag=-1, dy=15, dx=5
    FCB $FF,$F1,$05          ; flag=-1, dy=-15, dx=5
    FCB 2                ; End marker (path complete)
; Generated from player_walk_1.vec (Malban Draw_Sync_List format)
; Total paths: 17, points: 62
; X bounds: min=-8, max=11, width=19
; Center: (1, 0)

_PLAYER_WALK_1_WIDTH EQU 19
_PLAYER_WALK_1_HALF_WIDTH EQU 9
_PLAYER_WALK_1_HEIGHT EQU 29
_PLAYER_WALK_1_HALF_HEIGHT EQU 14
_PLAYER_WALK_1_CENTER_X EQU 1
_PLAYER_WALK_1_CENTER_Y EQU 0

_PLAYER_WALK_1_VECTORS:  ; Main entry (header + 17 path(s))
    FDB 17               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLAYER_WALK_1_PATH0        ; pointer to path 0
    FDB _PLAYER_WALK_1_PATH1        ; pointer to path 1
    FDB _PLAYER_WALK_1_PATH2        ; pointer to path 2
    FDB _PLAYER_WALK_1_PATH3        ; pointer to path 3
    FDB _PLAYER_WALK_1_PATH4        ; pointer to path 4
    FDB _PLAYER_WALK_1_PATH5        ; pointer to path 5
    FDB _PLAYER_WALK_1_PATH6        ; pointer to path 6
    FDB _PLAYER_WALK_1_PATH7        ; pointer to path 7
    FDB _PLAYER_WALK_1_PATH8        ; pointer to path 8
    FDB _PLAYER_WALK_1_PATH9        ; pointer to path 9
    FDB _PLAYER_WALK_1_PATH10        ; pointer to path 10
    FDB _PLAYER_WALK_1_PATH11        ; pointer to path 11
    FDB _PLAYER_WALK_1_PATH12        ; pointer to path 12
    FDB _PLAYER_WALK_1_PATH13        ; pointer to path 13
    FDB _PLAYER_WALK_1_PATH14        ; pointer to path 14
    FDB _PLAYER_WALK_1_PATH15        ; pointer to path 15
    FDB _PLAYER_WALK_1_PATH16        ; pointer to path 16

_PLAYER_WALK_1_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FE,$01,0,0        ; path0: header (y=-2, x=1)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $F8,$01,0,0        ; path1: header (y=-8, x=1)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $F2,$01,0,0        ; path2: header (y=-14, x=1)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FF,$FD          ; flag=-1, dy=-1, dx=-3
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $F1,$FB,0,0        ; path3: header (y=-15, x=-5)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $F2,$FB,0,0        ; path4: header (y=-14, x=-5)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $F8,$FB,0,0        ; path5: header (y=-8, x=-5)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $FE,$FA,0,0        ; path6: header (y=-2, x=-6)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $08,$FB,0,0        ; path7: header (y=8, x=-5)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $0C,$FB,0,0        ; path8: header (y=12, x=-5)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $0C,$F9,0,0        ; path9: header (y=12, x=-7)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $07,$04,0,0        ; path10: header (y=7, x=4)
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $06,$06,0,0        ; path11: header (y=6, x=6)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $03,$06,0,0        ; path12: header (y=3, x=6)
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $03,$07,0,0        ; path13: header (y=3, x=7)
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $00,$F9,0,0        ; path14: header (y=0, x=-7)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $06,$F9,0,0        ; path15: header (y=6, x=-7)
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $00,$F9,0,0        ; path16: header (y=0, x=-7)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)
; Generated from player_walk_2.vec (Malban Draw_Sync_List format)
; Total paths: 17, points: 62
; X bounds: min=-10, max=11, width=21
; Center: (0, -1)

_PLAYER_WALK_2_WIDTH EQU 21
_PLAYER_WALK_2_HALF_WIDTH EQU 10
_PLAYER_WALK_2_HEIGHT EQU 31
_PLAYER_WALK_2_HALF_HEIGHT EQU 15
_PLAYER_WALK_2_CENTER_X EQU 0
_PLAYER_WALK_2_CENTER_Y EQU -1

_PLAYER_WALK_2_VECTORS:  ; Main entry (header + 17 path(s))
    FDB 17               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLAYER_WALK_2_PATH0        ; pointer to path 0
    FDB _PLAYER_WALK_2_PATH1        ; pointer to path 1
    FDB _PLAYER_WALK_2_PATH2        ; pointer to path 2
    FDB _PLAYER_WALK_2_PATH3        ; pointer to path 3
    FDB _PLAYER_WALK_2_PATH4        ; pointer to path 4
    FDB _PLAYER_WALK_2_PATH5        ; pointer to path 5
    FDB _PLAYER_WALK_2_PATH6        ; pointer to path 6
    FDB _PLAYER_WALK_2_PATH7        ; pointer to path 7
    FDB _PLAYER_WALK_2_PATH8        ; pointer to path 8
    FDB _PLAYER_WALK_2_PATH9        ; pointer to path 9
    FDB _PLAYER_WALK_2_PATH10        ; pointer to path 10
    FDB _PLAYER_WALK_2_PATH11        ; pointer to path 11
    FDB _PLAYER_WALK_2_PATH12        ; pointer to path 12
    FDB _PLAYER_WALK_2_PATH13        ; pointer to path 13
    FDB _PLAYER_WALK_2_PATH14        ; pointer to path 14
    FDB _PLAYER_WALK_2_PATH15        ; pointer to path 15
    FDB _PLAYER_WALK_2_PATH16        ; pointer to path 16

_PLAYER_WALK_2_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FF,$02,0,0        ; path0: header (y=-1, x=2)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$F9,$01          ; flag=-1, dy=-7, dx=1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$07,$FF          ; flag=-1, dy=7, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $F8,$03,0,0        ; path1: header (y=-8, x=3)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$F9,$01          ; flag=-1, dy=-7, dx=1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$07,$FF          ; flag=-1, dy=7, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $F1,$04,0,0        ; path2: header (y=-15, x=4)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FF,$FD          ; flag=-1, dy=-1, dx=-3
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $F2,$00,0,0        ; path3: header (y=-14, x=0)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $F3,$FE,0,0        ; path4: header (y=-13, x=-2)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $F9,$FC,0,0        ; path5: header (y=-7, x=-4)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$06,$FF          ; flag=-1, dy=6, dx=-1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FA,$01          ; flag=-1, dy=-6, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $FF,$FB,0,0        ; path6: header (y=-1, x=-5)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $09,$FC,0,0        ; path7: header (y=9, x=-4)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $0D,$FC,0,0        ; path8: header (y=13, x=-4)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $0D,$FA,0,0        ; path9: header (y=13, x=-6)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $08,$05,0,0        ; path10: header (y=8, x=5)
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $07,$07,0,0        ; path11: header (y=7, x=7)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $04,$07,0,0        ; path12: header (y=4, x=7)
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $04,$08,0,0        ; path13: header (y=4, x=8)
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $08,$FB,0,0        ; path14: header (y=8, x=-5)
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $07,$F9,0,0        ; path15: header (y=7, x=-7)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FC,$FF          ; flag=-1, dy=-4, dx=-1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$04,$01          ; flag=-1, dy=4, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $03,$F8,0,0        ; path16: header (y=3, x=-8)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)
; Generated from player_walk_3.vec (Malban Draw_Sync_List format)
; Total paths: 17, points: 62
; X bounds: min=-9, max=11, width=20
; Center: (1, -1)

_PLAYER_WALK_3_WIDTH EQU 20
_PLAYER_WALK_3_HALF_WIDTH EQU 10
_PLAYER_WALK_3_HEIGHT EQU 30
_PLAYER_WALK_3_HALF_HEIGHT EQU 15
_PLAYER_WALK_3_CENTER_X EQU 1
_PLAYER_WALK_3_CENTER_Y EQU -1

_PLAYER_WALK_3_VECTORS:  ; Main entry (header + 17 path(s))
    FDB 17               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLAYER_WALK_3_PATH0        ; pointer to path 0
    FDB _PLAYER_WALK_3_PATH1        ; pointer to path 1
    FDB _PLAYER_WALK_3_PATH2        ; pointer to path 2
    FDB _PLAYER_WALK_3_PATH3        ; pointer to path 3
    FDB _PLAYER_WALK_3_PATH4        ; pointer to path 4
    FDB _PLAYER_WALK_3_PATH5        ; pointer to path 5
    FDB _PLAYER_WALK_3_PATH6        ; pointer to path 6
    FDB _PLAYER_WALK_3_PATH7        ; pointer to path 7
    FDB _PLAYER_WALK_3_PATH8        ; pointer to path 8
    FDB _PLAYER_WALK_3_PATH9        ; pointer to path 9
    FDB _PLAYER_WALK_3_PATH10        ; pointer to path 10
    FDB _PLAYER_WALK_3_PATH11        ; pointer to path 11
    FDB _PLAYER_WALK_3_PATH12        ; pointer to path 12
    FDB _PLAYER_WALK_3_PATH13        ; pointer to path 13
    FDB _PLAYER_WALK_3_PATH14        ; pointer to path 14
    FDB _PLAYER_WALK_3_PATH15        ; pointer to path 15
    FDB _PLAYER_WALK_3_PATH16        ; pointer to path 16

_PLAYER_WALK_3_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FF,$02,0,0        ; path0: header (y=-1, x=2)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$F9,$01          ; flag=-1, dy=-7, dx=1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$07,$FF          ; flag=-1, dy=7, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $F8,$03,0,0        ; path1: header (y=-8, x=3)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $F2,$03,0,0        ; path2: header (y=-14, x=3)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FF,$FD          ; flag=-1, dy=-1, dx=-3
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $F1,$FB,0,0        ; path3: header (y=-15, x=-5)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $F2,$FB,0,0        ; path4: header (y=-14, x=-5)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $F8,$F9,0,0        ; path5: header (y=-8, x=-7)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$07,$01          ; flag=-1, dy=7, dx=1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$F9,$FF          ; flag=-1, dy=-7, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $FF,$FA,0,0        ; path6: header (y=-1, x=-6)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $09,$FB,0,0        ; path7: header (y=9, x=-5)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $0D,$FB,0,0        ; path8: header (y=13, x=-5)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $0D,$F9,0,0        ; path9: header (y=13, x=-7)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $08,$04,0,0        ; path10: header (y=8, x=4)
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $07,$06,0,0        ; path11: header (y=7, x=6)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $04,$06,0,0        ; path12: header (y=4, x=6)
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $04,$07,0,0        ; path13: header (y=4, x=7)
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $08,$FA,0,0        ; path14: header (y=8, x=-6)
    FCB $FF,$FF,$FF          ; flag=-1, dy=-1, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $07,$F9,0,0        ; path15: header (y=7, x=-7)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$F9,$FF          ; flag=-1, dy=-7, dx=-1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$07,$01          ; flag=-1, dy=7, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $00,$F8,0,0        ; path16: header (y=0, x=-8)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)
; Generated from player_walk_4.vec (Malban Draw_Sync_List format)
; Total paths: 17, points: 62
; X bounds: min=-8, max=11, width=19
; Center: (1, -1)

_PLAYER_WALK_4_WIDTH EQU 19
_PLAYER_WALK_4_HALF_WIDTH EQU 9
_PLAYER_WALK_4_HEIGHT EQU 31
_PLAYER_WALK_4_HALF_HEIGHT EQU 15
_PLAYER_WALK_4_CENTER_X EQU 1
_PLAYER_WALK_4_CENTER_Y EQU -1

_PLAYER_WALK_4_VECTORS:  ; Main entry (header + 17 path(s))
    FDB 17               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLAYER_WALK_4_PATH0        ; pointer to path 0
    FDB _PLAYER_WALK_4_PATH1        ; pointer to path 1
    FDB _PLAYER_WALK_4_PATH2        ; pointer to path 2
    FDB _PLAYER_WALK_4_PATH3        ; pointer to path 3
    FDB _PLAYER_WALK_4_PATH4        ; pointer to path 4
    FDB _PLAYER_WALK_4_PATH5        ; pointer to path 5
    FDB _PLAYER_WALK_4_PATH6        ; pointer to path 6
    FDB _PLAYER_WALK_4_PATH7        ; pointer to path 7
    FDB _PLAYER_WALK_4_PATH8        ; pointer to path 8
    FDB _PLAYER_WALK_4_PATH9        ; pointer to path 9
    FDB _PLAYER_WALK_4_PATH10        ; pointer to path 10
    FDB _PLAYER_WALK_4_PATH11        ; pointer to path 11
    FDB _PLAYER_WALK_4_PATH12        ; pointer to path 12
    FDB _PLAYER_WALK_4_PATH13        ; pointer to path 13
    FDB _PLAYER_WALK_4_PATH14        ; pointer to path 14
    FDB _PLAYER_WALK_4_PATH15        ; pointer to path 15
    FDB _PLAYER_WALK_4_PATH16        ; pointer to path 16

_PLAYER_WALK_4_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FF,$01,0,0        ; path0: header (y=-1, x=1)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $F9,$01,0,0        ; path1: header (y=-7, x=1)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$FF          ; flag=-1, dy=-6, dx=-1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$01          ; flag=-1, dy=6, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $F3,$00,0,0        ; path2: header (y=-13, x=0)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $F1,$FF,0,0        ; path3: header (y=-15, x=-1)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FF,$FD          ; flag=-1, dy=-1, dx=-3
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $F1,$FD,0,0        ; path4: header (y=-15, x=-3)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $F8,$FB,0,0        ; path5: header (y=-8, x=-5)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$07,$FF          ; flag=-1, dy=7, dx=-1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$F9,$01          ; flag=-1, dy=-7, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $FF,$FA,0,0        ; path6: header (y=-1, x=-6)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $09,$FB,0,0        ; path7: header (y=9, x=-5)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $0D,$FB,0,0        ; path8: header (y=13, x=-5)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $0D,$F9,0,0        ; path9: header (y=13, x=-7)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $08,$04,0,0        ; path10: header (y=8, x=4)
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $07,$06,0,0        ; path11: header (y=7, x=6)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $04,$06,0,0        ; path12: header (y=4, x=6)
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $04,$07,0,0        ; path13: header (y=4, x=7)
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $01,$F9,0,0        ; path14: header (y=1, x=-7)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $07,$F9,0,0        ; path15: header (y=7, x=-7)
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $01,$F9,0,0        ; path16: header (y=1, x=-7)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)
; Generated from player_walk_5.vec (Malban Draw_Sync_List format)
; Total paths: 17, points: 62
; X bounds: min=-8, max=11, width=19
; Center: (1, 0)

_PLAYER_WALK_5_WIDTH EQU 19
_PLAYER_WALK_5_HALF_WIDTH EQU 9
_PLAYER_WALK_5_HEIGHT EQU 29
_PLAYER_WALK_5_HALF_HEIGHT EQU 14
_PLAYER_WALK_5_CENTER_X EQU 1
_PLAYER_WALK_5_CENTER_Y EQU 0

_PLAYER_WALK_5_VECTORS:  ; Main entry (header + 17 path(s))
    FDB 17               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLAYER_WALK_5_PATH0        ; pointer to path 0
    FDB _PLAYER_WALK_5_PATH1        ; pointer to path 1
    FDB _PLAYER_WALK_5_PATH2        ; pointer to path 2
    FDB _PLAYER_WALK_5_PATH3        ; pointer to path 3
    FDB _PLAYER_WALK_5_PATH4        ; pointer to path 4
    FDB _PLAYER_WALK_5_PATH5        ; pointer to path 5
    FDB _PLAYER_WALK_5_PATH6        ; pointer to path 6
    FDB _PLAYER_WALK_5_PATH7        ; pointer to path 7
    FDB _PLAYER_WALK_5_PATH8        ; pointer to path 8
    FDB _PLAYER_WALK_5_PATH9        ; pointer to path 9
    FDB _PLAYER_WALK_5_PATH10        ; pointer to path 10
    FDB _PLAYER_WALK_5_PATH11        ; pointer to path 11
    FDB _PLAYER_WALK_5_PATH12        ; pointer to path 12
    FDB _PLAYER_WALK_5_PATH13        ; pointer to path 13
    FDB _PLAYER_WALK_5_PATH14        ; pointer to path 14
    FDB _PLAYER_WALK_5_PATH15        ; pointer to path 15
    FDB _PLAYER_WALK_5_PATH16        ; pointer to path 16

_PLAYER_WALK_5_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FE,$01,0,0        ; path0: header (y=-2, x=1)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $F8,$01,0,0        ; path1: header (y=-8, x=1)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $F2,$01,0,0        ; path2: header (y=-14, x=1)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FF,$FD          ; flag=-1, dy=-1, dx=-3
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $F1,$FB,0,0        ; path3: header (y=-15, x=-5)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $F2,$FB,0,0        ; path4: header (y=-14, x=-5)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $F8,$FB,0,0        ; path5: header (y=-8, x=-5)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $FE,$FA,0,0        ; path6: header (y=-2, x=-6)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $08,$FB,0,0        ; path7: header (y=8, x=-5)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $0C,$FB,0,0        ; path8: header (y=12, x=-5)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $0C,$F9,0,0        ; path9: header (y=12, x=-7)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $07,$04,0,0        ; path10: header (y=7, x=4)
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $06,$06,0,0        ; path11: header (y=6, x=6)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $03,$06,0,0        ; path12: header (y=3, x=6)
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $03,$07,0,0        ; path13: header (y=3, x=7)
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $01,$F9,0,0        ; path14: header (y=1, x=-7)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $06,$F9,0,0        ; path15: header (y=6, x=-7)
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $01,$F9,0,0        ; path16: header (y=1, x=-7)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)
; Generated from pyramids_bg.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 10
; X bounds: min=-90, max=90, width=180
; Center: (0, 0)

_PYRAMIDS_BG_WIDTH EQU 180
_PYRAMIDS_BG_HALF_WIDTH EQU 90
_PYRAMIDS_BG_HEIGHT EQU 90
_PYRAMIDS_BG_HALF_HEIGHT EQU 45
_PYRAMIDS_BG_CENTER_X EQU 0
_PYRAMIDS_BG_CENTER_Y EQU 0

_PYRAMIDS_BG_VECTORS:  ; Main entry (header + 4 path(s))
    FDB 4               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PYRAMIDS_BG_PATH0        ; pointer to path 0
    FDB _PYRAMIDS_BG_PATH1        ; pointer to path 1
    FDB _PYRAMIDS_BG_PATH2        ; pointer to path 2
    FDB _PYRAMIDS_BG_PATH3        ; pointer to path 3

_PYRAMIDS_BG_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $2D,$F6,0,0        ; path0: header (y=45, x=-10)
    FCB $FF,$A6,$B0          ; flag=-1, dy=-90, dx=-80
    FCB 2                ; End marker (path complete)

_PYRAMIDS_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $D3,$A6,0,0        ; path1: header (y=-45, x=-90)
    FCB $FF,$5A,$50          ; flag=-1, dy=90, dx=80
    FCB $FF,$A6,$50          ; flag=-1, dy=-90, dx=80
    FCB 2                ; End marker (path complete)

_PYRAMIDS_BG_PATH2:    ; Path 2
    FCB 80              ; path2: intensity
    FCB $D3,$46,0,0        ; path2: header (y=-45, x=70)
    FCB $FF,$5A,$B0          ; flag=-1, dy=90, dx=-80
    FCB 2                ; End marker (path complete)

_PYRAMIDS_BG_PATH3:    ; Path 3
    FCB 90              ; path3: intensity
    FCB $D3,$1E,0,0        ; path3: header (y=-45, x=30)
    FCB $FF,$2D,$1E          ; flag=-1, dy=45, dx=30
    FCB $FF,$D3,$1E          ; flag=-1, dy=-45, dx=30
    FCB 2                ; End marker (path complete)
; Generated from taj_bg.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 13
; X bounds: min=-70, max=70, width=140
; Center: (0, 22)

_TAJ_BG_WIDTH EQU 140
_TAJ_BG_HALF_WIDTH EQU 70
_TAJ_BG_HEIGHT EQU 85
_TAJ_BG_HALF_HEIGHT EQU 42
_TAJ_BG_CENTER_X EQU 0
_TAJ_BG_CENTER_Y EQU 22

_TAJ_BG_VECTORS:  ; Main entry (header + 4 path(s))
    FDB 4               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _TAJ_BG_PATH0        ; pointer to path 0
    FDB _TAJ_BG_PATH1        ; pointer to path 1
    FDB _TAJ_BG_PATH2        ; pointer to path 2
    FDB _TAJ_BG_PATH3        ; pointer to path 3

_TAJ_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $12,$E2,0,0        ; path0: header (y=18, x=-30)
    FCB $FF,$14,$0A          ; flag=-1, dy=20, dx=10
    FCB $FF,$05,$14          ; flag=-1, dy=5, dx=20
    FCB $FF,$FB,$14          ; flag=-1, dy=-5, dx=20
    FCB $FF,$EC,$0A          ; flag=-1, dy=-20, dx=10
    FCB 2                ; End marker (path complete)

_TAJ_BG_PATH1:    ; Path 1
    FCB 110              ; path1: intensity
    FCB $12,$28,0,0        ; path1: header (y=18, x=40)
    FCB $FF,$CE,$00          ; flag=-1, dy=-50, dx=0
    FCB $FF,$00,$B0          ; flag=-1, dy=0, dx=-80
    FCB $FF,$32,$00          ; flag=-1, dy=50, dx=0
    FCB 2                ; End marker (path complete)

_TAJ_BG_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $1C,$BA,0,0        ; path2: header (y=28, x=-70)
    FCB $FF,$BA,$00          ; flag=-1, dy=-70, dx=0
    FCB 2                ; End marker (path complete)

_TAJ_BG_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $D6,$46,0,0        ; path3: header (y=-42, x=70)
    FCB $FF,$46,$00          ; flag=-1, dy=70, dx=0
    FCB 2                ; End marker (path complete)
; Generated from map_theme.vmus (internal name: Space Groove)
; Tempo: 140 BPM, Total events: 36 (PSG Direct format)
; Format: FCB count, FCB reg, val, ... (per frame), FCB 0 (end)

_MAP_THEME_MUSIC:
    ; Frame-based PSG register writes
    FCB     0              ; Delay 0 frames (maintain previous state)
    FCB     11              ; Frame 0 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $14             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 5 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     11              ; Frame 10 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 13 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     9              ; Frame 21 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $32             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     8              ; Frame 24 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3A             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     9              ; Frame 32 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $32             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 34 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3A             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     11              ; Frame 42 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $14             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     10              ; Frame 48 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     11              ; Frame 53 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 56 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     9              ; Frame 64 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $C8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $32             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 66 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $C8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3A             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     9              ; Frame 75 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0B             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $32             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 77 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0B             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3A             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     11              ; Frame 85 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $E1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $14             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     10              ; Frame 91 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $E1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     11              ; Frame 96 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $E1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 99 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $E1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     9              ; Frame 107 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $70             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0F             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $E1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $32             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 109 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $70             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0F             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $E1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3A             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     9              ; Frame 117 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $70             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0F             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $E1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $32             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     8              ; Frame 120 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $70             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0F             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $E1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3A             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     11              ; Frame 128 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $14             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 133 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     11              ; Frame 139 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 141 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     9              ; Frame 150 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $32             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 152 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3A             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     9              ; Frame 160 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $32             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     8              ; Frame 163 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3A             ; Reg 7 value
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
    FCB     4              ; Delay 4 frames before loop
    FCB     $FF             ; Loop command ($FF never valid as count)
    FDB     _MAP_THEME_MUSIC       ; Jump to start (absolute address)

; Generated from pang_theme.vmus (internal name: pang_theme)
; Tempo: 120 BPM, Total events: 34 (PSG Direct format)
; Format: FCB count, FCB reg, val, ... (per frame), FCB 0 (end)

_PANG_THEME_MUSIC:
    ; Frame-based PSG register writes
    FCB     0              ; Delay 0 frames (maintain previous state)
    FCB     11              ; Frame 0 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $0B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 12 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $0B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     13              ; Delay 13 frames (maintain previous state)
    FCB     10              ; Frame 25 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $0B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     25              ; Delay 25 frames (maintain previous state)
    FCB     11              ; Frame 50 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $70             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $E1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 62 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $70             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $E1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     13              ; Delay 13 frames (maintain previous state)
    FCB     10              ; Frame 75 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $54             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $E1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     25              ; Delay 25 frames (maintain previous state)
    FCB     11              ; Frame 100 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $70             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 112 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $70             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 124 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     26              ; Delay 26 frames (maintain previous state)
    FCB     11              ; Frame 150 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $0B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 162 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $0B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     38              ; Delay 38 frames (maintain previous state)
    FCB     11              ; Frame 200 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $FC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 212 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $FC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 224 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $FC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     25              ; Delay 25 frames (maintain previous state)
    FCB     11              ; Frame 249 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $64             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     13              ; Delay 13 frames (maintain previous state)
    FCB     10              ; Frame 262 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $64             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     13              ; Delay 13 frames (maintain previous state)
    FCB     10              ; Frame 275 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $4B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     25              ; Delay 25 frames (maintain previous state)
    FCB     11              ; Frame 300 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $64             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $96             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 312 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $64             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $96             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     13              ; Delay 13 frames (maintain previous state)
    FCB     10              ; Frame 325 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $96             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     25              ; Delay 25 frames (maintain previous state)
    FCB     11              ; Frame 350 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $FC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 362 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $FC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
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
    FCB     34              ; Delay 34 frames before loop
    FCB     $FF             ; Loop command ($FF never valid as count)
    FDB     _PANG_THEME_MUSIC       ; Jump to start (absolute address)

; ==== Level: FUJI_LEVEL1_V2 ====
; Author: 
; Difficulty: medium

_FUJI_LEVEL1_V2_LEVEL:
    FDB -96  ; World bounds: xMin (16-bit signed)
    FDB 95  ; xMax (16-bit signed)
    FDB -128  ; yMin (16-bit signed)
    FDB 127  ; yMax (16-bit signed)
    FDB 0  ; Time limit (seconds)
    FDB 0  ; Target score
    FCB 1  ; Background object count
    FCB 2  ; Gameplay object count
    FCB 0  ; Foreground object count
    FDB _FUJI_LEVEL1_V2_BG_OBJECTS
    FDB _FUJI_LEVEL1_V2_GAMEPLAY_OBJECTS
    FDB _FUJI_LEVEL1_V2_FG_OBJECTS
    FDB -96  ; scrollLimit left (camera left cannot go below this)
    FDB 95  ; scrollLimit right (camera right cannot exceed this)
    FDB 127  ; scrollLimit top
    FDB -128  ; scrollLimit bottom
    FCB 0  ; enemy_count
    FDB 0  ; enemy_instances_ptr (0 if none)
    FDB 0  ; groundBottomOffset (floor surface offset from screen bottom)
    FCB 1    ; +34 screen_count
    FDB _FUJI_LEVEL1_V2_BG_SCREENS  ; +35 BG screens index
    FDB _FUJI_LEVEL1_V2_GP_SCREENS  ; +37 GP screens index
    FDB _FUJI_LEVEL1_V2_FG_SCREENS  ; +39 FG screens index

_FUJI_LEVEL1_V2_BG_OBJECTS:
_FUJI_LEVEL1_V2_BG_OBJECTS_S0:
; Object: obj_1767470884207 (enemy)
    FCB 1  ; type
    FDB 0  ; x
    FDB 0  ; y
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
    FDB _FUJI_BG_VECTORS  ; vector_ptr (ROM+17)
    FCB 125  ; half_width (1.00x, ROM+19)
    FCB 48  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)


_FUJI_LEVEL1_V2_GAMEPLAY_OBJECTS:
_FUJI_LEVEL1_V2_GAMEPLAY_OBJECTS_S0:
; Object: enemy_1 (enemy)
    FCB 1  ; type
    FDB -40  ; x
    FDB 60  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 127  ; intensity (0=use vec, >0=override)
    FCB 255  ; velocity_x
    FCB 255  ; velocity_y
    FCB 3  ; physics_flags
    FCB 7  ; collision_flags
    FCB 20  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _BUBBLE_LARGE_VECTORS  ; vector_ptr (ROM+17)
    FCB 20  ; half_width (1.00x, ROM+19)
    FCB 20  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: enemy_2 (enemy)
    FCB 1  ; type
    FDB 40  ; x
    FDB 60  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 127  ; intensity (0=use vec, >0=override)
    FCB 1  ; velocity_x
    FCB 255  ; velocity_y
    FCB 3  ; physics_flags
    FCB 7  ; collision_flags
    FCB 20  ; collision_size
    FDB 60  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _BUBBLE_LARGE_VECTORS  ; vector_ptr (ROM+17)
    FCB 20  ; half_width (1.00x, ROM+19)
    FCB 20  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)


_FUJI_LEVEL1_V2_FG_OBJECTS:
_FUJI_LEVEL1_V2_FG_OBJECTS_S0:

_FUJI_LEVEL1_V2_BG_SCREENS:
    FCB 1  ; screen 0 count
    FDB _FUJI_LEVEL1_V2_BG_OBJECTS_S0  ; screen 0 ptr

_FUJI_LEVEL1_V2_GP_SCREENS:
    FCB 2  ; screen 0 count
    FDB _FUJI_LEVEL1_V2_GAMEPLAY_OBJECTS_S0  ; screen 0 ptr

_FUJI_LEVEL1_V2_FG_SCREENS:
    FCB 0  ; screen 0 count
    FDB _FUJI_LEVEL1_V2_FG_OBJECTS_S0  ; screen 0 ptr

_FUJI_LEVEL1_V2_ENEMY_COUNT EQU 0

_HIT_SFX:
    ; SFX: hit (hit)
    ; Duration: 300ms (15fr), Freq: 200Hz, Channel: 0
    FCB $6C         ; Frame 0 - flags (vol=12, noisevol=12, tone=Y, noise=Y)
    FCB $01, $6F  ; Tone period = 367 (big-endian)
    FCB $08         ; Noise period
    FCB $6B         ; Frame 1 - flags (vol=11, noisevol=11, tone=Y, noise=Y)
    FCB $01, $84  ; Tone period = 388 (big-endian)
    FCB $08         ; Noise period
    FCB $6F         ; Frame 2 - flags (vol=15, noisevol=10, tone=Y, noise=Y)
    FCB $01, $9C  ; Tone period = 412 (big-endian)
    FCB $08         ; Noise period
    FCB $6F         ; Frame 3 - flags (vol=15, noisevol=8, tone=Y, noise=Y)
    FCB $01, $B6  ; Tone period = 438 (big-endian)
    FCB $08         ; Noise period
    FCB $6E         ; Frame 4 - flags (vol=14, noisevol=7, tone=Y, noise=Y)
    FCB $01, $D4  ; Tone period = 468 (big-endian)
    FCB $08         ; Noise period
    FCB $6D         ; Frame 5 - flags (vol=13, noisevol=6, tone=Y, noise=Y)
    FCB $01, $F6  ; Tone period = 502 (big-endian)
    FCB $08         ; Noise period
    FCB $6C         ; Frame 6 - flags (vol=12, noisevol=5, tone=Y, noise=Y)
    FCB $02, $1E  ; Tone period = 542 (big-endian)
    FCB $08         ; Noise period
    FCB $6C         ; Frame 7 - flags (vol=12, noisevol=4, tone=Y, noise=Y)
    FCB $02, $4C  ; Tone period = 588 (big-endian)
    FCB $08         ; Noise period
    FCB $6C         ; Frame 8 - flags (vol=12, noisevol=2, tone=Y, noise=Y)
    FCB $02, $83  ; Tone period = 643 (big-endian)
    FCB $08         ; Noise period
    FCB $6C         ; Frame 9 - flags (vol=12, noisevol=1, tone=Y, noise=Y)
    FCB $02, $C6  ; Tone period = 710 (big-endian)
    FCB $08         ; Noise period
    FCB $AC         ; Frame 10 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $03, $18  ; Tone period = 792 (big-endian)
    FCB $A9         ; Frame 11 - flags (vol=9, noisevol=0, tone=Y, noise=N)
    FCB $03, $7F  ; Tone period = 895 (big-endian)
    FCB $A7         ; Frame 12 - flags (vol=7, noisevol=0, tone=Y, noise=N)
    FCB $04, $05  ; Tone period = 1029 (big-endian)
    FCB $A4         ; Frame 13 - flags (vol=4, noisevol=0, tone=Y, noise=N)
    FCB $04, $BB  ; Tone period = 1211 (big-endian)
    FCB $A2         ; Frame 14 - flags (vol=2, noisevol=0, tone=Y, noise=N)
    FCB $05, $BE  ; Tone period = 1470 (big-endian)
    FCB $D0, $20    ; End of effect marker

_LASER_SFX:
    ; SFX: laser (laser)
    ; Duration: 500ms (25fr), Freq: 880Hz, Channel: 0
    FCB $AC         ; Frame 0 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $00, $32  ; Tone period = 50 (big-endian)
    FCB $AC         ; Frame 1 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $00, $34  ; Tone period = 52 (big-endian)
    FCB $AC         ; Frame 2 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $00, $35  ; Tone period = 53 (big-endian)
    FCB $AC         ; Frame 3 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $00, $37  ; Tone period = 55 (big-endian)
    FCB $AC         ; Frame 4 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $00, $39  ; Tone period = 57 (big-endian)
    FCB $AC         ; Frame 5 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $00, $3B  ; Tone period = 59 (big-endian)
    FCB $AC         ; Frame 6 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $00, $3E  ; Tone period = 62 (big-endian)
    FCB $AC         ; Frame 7 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $00, $40  ; Tone period = 64 (big-endian)
    FCB $AC         ; Frame 8 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $00, $43  ; Tone period = 67 (big-endian)
    FCB $AC         ; Frame 9 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $00, $46  ; Tone period = 70 (big-endian)
    FCB $AC         ; Frame 10 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $00, $49  ; Tone period = 73 (big-endian)
    FCB $AC         ; Frame 11 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $00, $4C  ; Tone period = 76 (big-endian)
    FCB $AC         ; Frame 12 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $00, $50  ; Tone period = 80 (big-endian)
    FCB $AC         ; Frame 13 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $00, $54  ; Tone period = 84 (big-endian)
    FCB $AC         ; Frame 14 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $00, $59  ; Tone period = 89 (big-endian)
    FCB $AC         ; Frame 15 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $00, $5E  ; Tone period = 94 (big-endian)
    FCB $AC         ; Frame 16 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $00, $64  ; Tone period = 100 (big-endian)
    FCB $AC         ; Frame 17 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $00, $6B  ; Tone period = 107 (big-endian)
    FCB $AC         ; Frame 18 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $00, $73  ; Tone period = 115 (big-endian)
    FCB $AC         ; Frame 19 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $00, $7B  ; Tone period = 123 (big-endian)
    FCB $AC         ; Frame 20 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $00, $86  ; Tone period = 134 (big-endian)
    FCB $A9         ; Frame 21 - flags (vol=9, noisevol=0, tone=Y, noise=N)
    FCB $00, $92  ; Tone period = 146 (big-endian)
    FCB $A7         ; Frame 22 - flags (vol=7, noisevol=0, tone=Y, noise=N)
    FCB $00, $A0  ; Tone period = 160 (big-endian)
    FCB $A4         ; Frame 23 - flags (vol=4, noisevol=0, tone=Y, noise=N)
    FCB $00, $B2  ; Tone period = 178 (big-endian)
    FCB $A2         ; Frame 24 - flags (vol=2, noisevol=0, tone=Y, noise=N)
    FCB $00, $C8  ; Tone period = 200 (big-endian)
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
; ENEMY SYSTEM RUNTIME  (max 8 enemies, stride 28 bytes)
; ============================================================================
ENEMY_POOL_STRIDE EQU 28
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
; within +/-150 of CAMERA_Y, capped at the pool size (8).
LBEQ SPAWN_ENE_DONE
STB >ENEMY_LOOP_IDX        ; scan counter = total ROM entries to examine
; Zero-clear ALL pool slots so stale enemies from the previous screen vanish
LDY #ENEMY_POOL
LDB #8
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
CMPA #8
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

; UPDATE_ENEMIES_RUNTIME (single-bank)
; Same as multibank version without bank switching.
UPDATE_ENEMIES_RUNTIME:
LDB >ENEMY_COUNT
LBEQ UPD_ENE_DONE
LDY #ENEMY_POOL
UPD_ENE_LOOP:
PSHS B
LDA ,Y
LBEQ UPD_ENE_NEXT_POP
JSR UPD_DECAY_CHECK   ; SM auto-decay (matches per-state decay_frames)
; Frozen-action guard: action >= 2 = SM-frozen (snow1/snow2/ball) → skip movement
LDA 7,Y
CMPA #2
LBHS UPD_ENE_NEXT_POP
LDA 8,Y
CMPA #1
LBEQ UPD_PATROL
CMPA #4
LBEQ UPD_WANDER
LBRA UPD_ENE_NEXT_POP

UPD_PATROL:
LDA 11,Y
LDB 12,Y
CMPD #0
LBEQ UPD_ENE_NEXT_POP
TFR D,X
LDA 10,Y
ASLA
ASLA
LEAX A,X
LDD ,X
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
LDD 2,X
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

UPD_WANDER:
LDA 18,Y
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
TFR D,X
LDB 19,Y
LDA #8
MUL
ADDD #2
LEAX D,X
LDA 17,Y
LBNE UPD_W_WALK_L
LDD 1,Y
ADDD #1
PSHS D
LDD 4,X
CMPD ,S
LBLT UPD_W_EDGE_R
PULS D
STD 1,Y
JSR UPD_W_SETY      ; world_y = surface_y_at(area, new_x) + feet_offset
LBRA UPD_ENE_NEXT_POP
UPD_W_EDGE_R:
LEAS 2,S
LDD 4,X
STD 1,Y
JSR UPD_W_SETY
LBRA UPD_W_EDGE
UPD_W_WALK_L:
LDD 1,Y
SUBD #1
PSHS D
LDD 2,X
CMPD ,S
LBGT UPD_W_EDGE_L
PULS D
STD 1,Y
JSR UPD_W_SETY      ; world_y = surface_y_at(area, new_x) + feet_offset
LBRA UPD_ENE_NEXT_POP
UPD_W_EDGE_L:
LEAS 2,S
LDD 2,X
STD 1,Y
JSR UPD_W_SETY
UPD_W_EDGE:
LDA 17,Y
EORA #1
STA 17,Y
LDA #1
STA 18,Y
CLR 7,Y
JSR RAND_HELPER
ANDB #$3F
ADDB #90
STB 20,Y
LBRA UPD_ENE_NEXT_POP

; Set pool world_y from the sloped surface at the enemy's current x.
; Entry: X = &area, Y = pool. Clobbers A,B,X.
UPD_W_SETY:
LDD 1,Y             ; query x = current x
JSR AREA_SURF_Y     ; D = surface_y_at(area, x)
ADDB 26,Y           ; + feet_offset (low)
ADCA #0
STD 3,Y             ; world_y
RTS

UPD_W_IDLE:
DEC 20,Y
LBNE UPD_ENE_NEXT_POP
LDA 11,Y
LDB 12,Y
TFR D,X
LDB 1,X
LBEQ UPD_W_TO_WALK
PSHS B
LDA ,X
LDB #8
MUL
ADDD #2
LEAX D,X
PULS B
UPD_W_TRY_LOOP:
LDA 19,Y
CMPA ,X
BNE UPD_W_NEXT_TRY
PSHS B,X
JSR RAND_HELPER
CMPA #32            ; ~25% commit. Use the high byte (A, 0..127): the LCG's
PULS B,X            ; low 2 bits flip +1/call, and with 2 rolls/idle cycle a
BHS UPD_W_NEXT_TRY  ; low-bit coin locks to {1,3} for odd seeds -> never fires.
LDA 1,X
STA 19,Y
LDA 2,X
STA 21,Y
LDA 3,X
STA 27,Y            ; vy0_stash from trans entry
LDD 4,X
STD 24,Y
LDD 6,X
STD 22,Y
LDA #3
STA 18,Y
LDA #1
STA 7,Y
LBRA UPD_ENE_NEXT_POP
UPD_W_NEXT_TRY:
LEAX 8,X
DECB
BNE UPD_W_TRY_LOOP
UPD_W_TO_WALK:
CLR 18,Y
LDA #1
STA 7,Y
LBRA UPD_ENE_NEXT_POP

UPD_W_TT:
LDD 24,Y
CMPD 1,Y
LBEQ UPD_W_TT_REACHED
LBGT UPD_W_TT_RIGHT
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
LDA 27,Y            ; vy0_stash from commit
STA 25,Y
LDA #120
STA 24,Y
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
STA 18,Y
LBRA UPD_ENE_NEXT_POP

UPD_W_AIR:
DEC 24,Y
LBEQ UPD_W_AIR_LAND
LDD 22,Y
CMPD 1,Y
LBEQ UPD_W_AIR_Y
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
LDB 25,Y
SEX
ADDD 3,Y
STD 3,Y
LDB 25,Y
DECB
CMPB #$FC
BGE UPD_W_AIR_VYOK
LDB #$FC
UPD_W_AIR_VYOK:
STB 25,Y
LDA 11,Y
LDB 12,Y
TFR D,X
LDB 19,Y
LDA #8
MUL
ADDD #2
LEAX D,X            ; X = &area[cur_area]
LDD 22,Y            ; target_x (to_x)
JSR AREA_SURF_Y     ; D = surface_y_at(area, to_x)
ADDB 26,Y           ; + feet_offset (low)
ADCA #0
PSHS D              ; stash target_y
LDA 21,Y
CMPA #2
BEQ UPD_W_AIR_CHK_DOWN
LDB 25,Y
TSTB
BPL UPD_W_AIR_NOLAND
UPD_W_AIR_CHK_DOWN:
LDD ,S
CMPD 3,Y
LBLT UPD_W_AIR_NOLAND
PULS D
STD 3,Y
CLR 18,Y
LDA #1
STA 7,Y
LBRA UPD_ENE_NEXT_POP
UPD_W_AIR_NOLAND:
LEAS 2,S
LBRA UPD_ENE_NEXT_POP
UPD_W_AIR_LAND:
LDA 11,Y
LDB 12,Y
TFR D,X
LDB 19,Y
LDA #8
MUL
ADDD #2
LEAX D,X
LDD 22,Y            ; target_x (to_x)
JSR AREA_SURF_Y     ; D = surface_y_at(area, to_x)
ADDB 26,Y           ; + feet_offset (low)
ADCA #0
STD 3,Y
CLR 18,Y
LDA #1
STA 7,Y
LBRA UPD_ENE_NEXT_POP

UPD_ENE_NEXT_POP:
PULS B
LEAY 28,Y
DECB
LBNE UPD_ENE_LOOP
UPD_ENE_DONE:
RTS

; ---- AREA_SURF_Y: sloped walkable-area surface height ----
AREA_SURF_Y:
PSHS D              ; [S+0..1] = query_x (saved for interp)
LDD 6,X             ; y2
CMPD 0,X            ; vs y1
BEQ ASY_FLAT        ; flat area -> y1
LDD 4,X             ; x_max
CMPD 2,X            ; vs x_min (signed)
BLE ASY_FLAT        ; x_max <= x_min -> y1
LDD ,S              ; query_x
CMPD 2,X            ; vs x_min (signed)
BLE ASY_FLAT        ; x <= x_min -> y1
CMPD 4,X            ; query_x vs x_max (signed)
BGE ASY_FAR         ; x >= x_max -> y2
BRA ASY_INTERP
ASY_FLAT:
LDD 0,X             ; return y1
LEAS 2,S            ; drop saved query_x
RTS
ASY_FAR:
LDD 6,X             ; return y2
LEAS 2,S
RTS
ASY_INTERP:
LEAS -14,S          ; locals: [0..3]P [4..5]w [6..7]t [8]sign [9..10]|dy| [11..12]y1 [13]cnt ; [14..15]query_x
LDD 0,X             ; y1
STD 11,S
LDD 6,X             ; y2
SUBD 0,X            ; dy = y2 - y1 (signed)
TSTA
BPL ASY_DYP
COMA
COMB
ADDD #1             ; |dy|
STD 9,S
LDA #1
STA 8,S             ; sign = negative
BRA ASY_DYD
ASY_DYP:
STD 9,S             ; |dy| = dy
CLR 8,S             ; sign = positive
ASY_DYD:
LDD 4,X             ; x_max
SUBD 2,X            ; w = x_max - x_min (>0)
STD 4,S
LDD 14,S            ; query_x
SUBD 2,X            ; t = query_x - x_min (>=1)
STD 6,S
; ---- X is now free; build 32-bit product P = |dy| * t ----
LDA 10,S            ; al = |dy| low
LDB 7,S             ; bl = t low
MUL                 ; D = al*bl (p_ll)
STD 2,S             ; P1:P0
LDA 9,S             ; ah = |dy| high
LDB 6,S             ; bh = t high
MUL                 ; D = ah*bh (p_hh)
STD 0,S             ; P3:P2
LDA 9,S             ; ah
LDB 7,S             ; bl
MUL                 ; D = ah*bl (mid1)
ADDB 2,S            ; add mid1<<8 into P
STB 2,S
ADCA 1,S
STA 1,S
LDA 0,S
ADCA #0
STA 0,S
LDA 10,S            ; al
LDB 6,S             ; bh
MUL                 ; D = al*bh (mid2)
ADDB 2,S            ; add mid2<<8 into P
STB 2,S
ADCA 1,S
STA 1,S
LDA 0,S
ADCA #0
STA 0,S
; ---- divide P (32-bit) by w -> Q in P1:P0, 16-iter shift-subtract ----
; The 32-bit dividend is shifted left through carry using only register
; rotates (ASLB/ROLA/ROLB); LDD/STD do not affect C, so the carry chains
; across the two 16-bit halves (the assembler has no indexed shifts).
LDA #16
STA 13,S            ; loop counter
ASY_DIVLOOP:
LDD 2,S             ; low word P1:P0
ASLB                ; P0<<1, bit0=0, C=old bit7(P0)
ROLA                ; P1<<1 | C, C=old bit7(P1)
STD 2,S             ; store low word (C preserved)
LDD 0,S             ; high word P3:P2 = rem (C preserved)
ROLB                ; P2<<1 | C, C=old bit7(P2)
ROLA                ; P3<<1 | C, C=old bit7(P3) = bit16
STD 0,S             ; store rem (C preserved), D still = rem
BCS ASY_DSUB        ; bit16 set -> rem definitely >= w
CMPD 4,S            ; rem vs w (unsigned); D = rem
BLO ASY_DNOSUB      ; rem < w -> quotient bit 0
ASY_DSUB:
LDD 0,S
SUBD 4,S            ; rem -= w
STD 0,S
INC 3,S             ; quotient bit = 1 (LSB of P0, was 0 after shift)
ASY_DNOSUB:
DEC 13,S
BNE ASY_DIVLOOP
; ---- apply sign (truncate toward zero) and add y1 ----
LDA 8,S             ; sign flag (0=pos, 1=neg); sets Z
BNE ASY_QNEG
LDD 2,S             ; Q (fits 16 bits)
ADDD 11,S           ; result = y1 + Q
LEAS 16,S           ; drop 14 locals + saved query_x
RTS
ASY_QNEG:
LDD 2,S             ; Q
COMA
COMB
ADDD #1             ; -Q (truncate toward zero)
ADDD 11,S           ; result = y1 - Q
LEAS 16,S           ; drop 14 locals + saved query_x
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
    LDB #4              ; 4 bytes per action entry (FDB sprite_ptr+FCB type+FCB loop)
MUL                 ; D = action_idx * 4
LEAX D,X            ; X = &actions[action]
LDD ,X              ; sprite_ptr = FDB at action[0,1] (_NAME_VECTORS address)
CMPD #0             ; 0 = no sprite assigned
LBEQ DRW_ENE_NEXT_POP
TFR D,X             ; X = _NAME_VECTORS header address
; screen_x = world_x(16-bit) - camera_x(16-bit), y unchanged
LDA 1,Y             ; world_x hi (POOL_X_HI)
LDB 2,Y             ; world_x lo (POOL_X_LO)
SUBD CAMERA_X       ; D = world_x - camera_x (16-bit, DP=$C8 relative)
STA TMPPTR2         ; save high byte for range check
TFR B,A
SEX                 ; A = sign-extend of B (0x00 or 0xFF)
CMPA TMPPTR2        ; compare with actual high byte
LBNE DRW_ENE_NEXT_POP  ; out of 8-bit range — skip draw
STB DRAW_VEC_X      ; screen_x lo byte
STA DRAW_VEC_X_HI   ; A holds sign-extension of B (set by SEX above)
LDB 4,Y             ; world_y lo (POOL_Y_LO)
STB DRAW_VEC_Y
CLR DRAW_VEC_INTENSITY  ; use vector's own intensity
; Mirror from POOL_DIR (set by UPDATE_ENEMIES patrol move): 0=right, 1=left.
; Set both MIRROR_X (path loop) and DRAW_ANIM_MIRROR_X (DAR re-applies it
; per frame because DRAW_ANIM_BANKED clears MIRROR_X at entry).
LDA 17,Y
STA MIRROR_X
STA DRAW_ANIM_MIRROR_X
CLR MIRROR_Y
; Draw paths — mirrors DRAW_VECTOR_BANKED path loop (no bank switch)
JSR $F1AA           ; DP_to_D0 (required before DSWM / VIA access)
LDD ,X              ; D = path_count (FDB at vector header start)
CMPD #0
LBEQ DRW_ENE_SB_DONE
PSHS Y              ; save pool ptr (Y used as path table ptr below)
LEAY 2,X            ; Y = first path FDB entry (skip 2-byte path_count)
DRW_ENE_SB_PATH:
PSHS D              ; save remaining path count
LDX ,Y              ; X = path data address (FDB entry)
JSR Draw_Sync_List_At_With_Mirrors
LEAY 2,Y            ; advance to next FDB entry
PULS D              ; restore count
SUBD #1
BNE DRW_ENE_SB_PATH
PULS Y              ; restore pool ptr
DRW_ENE_SB_DONE:
JSR $F1AF           ; DP_to_C8 (restore DP for RAM access)
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
LDB #28                 ; ENEMY_POOL_STRIDE — was hard-coded 17 which is WRONG (real stride=28); idx>0 wrote to wrong pool entry
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
PRINT_TEXT_STR_103315:
    FCC "hit"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_107868:
    FCC "map"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3208483:
    FCC "hook"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3327403:
    FCC "logo"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_102743755:
    FCC "laser"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3413815335:
    FCC "taj_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_93976101846:
    FCC "fuji_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2382167728733:
    FCC "TO START"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2779111860214:
    FCC "ayers_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3088519875410:
    FCC "mayan_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3170864850809:
    FCC "paris_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_62529178322969:
    FCC "GET READY"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_85851400383728:
    FCC "angkor_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_86017190903439:
    FCC "athens_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_86894009833752:
    FCC "buddha_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_88916199021370:
    FCC "easter_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_94134666982268:
    FCC "keirin_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_95266726412236:
    FCC "london_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_95736077158694:
    FCC "map_theme"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2997885107879189:
    FCC "newyork_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3047088743154868:
    FCC "pang_theme"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_83503386307659390:
    FCC "bubble_huge"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_95097560564962529:
    FCC "pyramids_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2572636110730664281:
    FCC "barcelona_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2588604975540550088:
    FCC "bubble_large"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2588604975547356052:
    FCC "bubble_small"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2829898994950197404:
    FCC "leningrad_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2984064007298942493:
    FCC "fuji_level1_v2"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_4990555610362249649:
    FCC "kilimanjaro_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_5508987775272975622:
    FCC "antarctica_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_6459777946950754952:
    FCC "bubble_medium"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_9120385685437879118:
    FCC "PRESS A BUTTON"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17258163498655081049:
    FCC "player_walk_1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17258163498655081050:
    FCC "player_walk_2"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17258163498655081051:
    FCC "player_walk_3"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17258163498655081052:
    FCC "player_walk_4"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17258163498655081053:
    FCC "player_walk_5"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17852485805690375172:
    FCC "location_marker"
    FCB $80          ; Vectrex string terminator

