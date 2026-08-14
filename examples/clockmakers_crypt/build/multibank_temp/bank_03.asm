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
LEVEL_GP_BUFFER      EQU $C880+$6A   ; GP objects RAM buffer (max 32 objects × 15 bytes) (480 bytes)
LCOL_PX              EQU $C880+$24A   ; LEVEL_COLLISION player world_x input (16-bit) (2 bytes)
LCOL_BEST_Y          EQU $C880+$24C   ; LEVEL_COLLISION_Y best floor y found (16-bit signed) (2 bytes)
LCOL_PY              EQU $C880+$24E   ; LEVEL_COLLISION player_top (16-bit signed) (2 bytes)
LCOL_PHH             EQU $C880+$250   ; LEVEL_COLLISION player half_height (1 bytes)
LCOL_PHW             EQU $C880+$251   ; LEVEL_COLLISION_X player half_width (1 bytes)
LCOL_THW             EQU $C880+$252   ; LEVEL_COLLISION_X total half_width (player_hw + obj_hw scratch) (1 bytes)
LCOL_OBJ_Y           EQU $C880+$253   ; LEVEL_COLLISION_Y current object world_y (16-bit) (2 bytes)
LCOL_LOCAL_PX        EQU $C880+$255   ; LEVEL_COLLISION_Y player_x in object-local coords (16-bit) (2 bytes)
LCOL_OBJ_CNT         EQU $C880+$257   ; LEVEL_COLLISION_Y GP objects remaining (1 bytes)
LCOL_SEG_CNT         EQU $C880+$258   ; LEVEL_COLLISION_Y mesh floor segments remaining (1 bytes)
UGPC_OUTER_IDX       EQU $C880+$259   ; GP-GP outer loop index (1 bytes)
UGPC_OUTER_MAX       EQU $C880+$25A   ; GP-GP outer loop max (count-1) (1 bytes)
UGPC_INNER_IDX       EQU $C880+$25B   ; GP-GP inner loop index (1 bytes)
UGPC_DX              EQU $C880+$25C   ; GP-GP |dx| (16-bit) (2 bytes)
UGPC_DIST            EQU $C880+$25E   ; GP-GP Manhattan distance (16-bit) (2 bytes)
UGFC_GP_IDX          EQU $C880+$260   ; GP-FG outer loop GP index (1 bytes)
UGFC_FG_COUNT        EQU $C880+$261   ; GP-FG inner loop FG count (1 bytes)
UGFC_DX              EQU $C880+$262   ; GP-FG |dx| (1 bytes)
UGFC_DY              EQU $C880+$263   ; GP-FG |dy| (1 bytes)
TEXT_SCALE_H         EQU $C880+$264   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$265   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
DRAW_SCALE           EQU $C880+$266   ; Current T1 scale for Draw_Sync_List_At_With_Mirrors ($7F=normal) (1 bytes)
VAR_ARG0             EQU $C880+$267   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $C880+$269   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $C880+$26B   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $C880+$26D   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $C880+$26F   ; Function argument 4 (16-bit) (2 bytes)
VAR_ARG5             EQU $C880+$271   ; Function argument 5 (16-bit) (2 bytes)
VAR_ARG6             EQU $C880+$273   ; Function argument 6 (16-bit) (2 bytes)
VAR_ARG7             EQU $C880+$275   ; Function argument 7 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $C880+$277   ; Current ROM bank ID (multibank tracking) (1 bytes)
VAR_ITEM_WEIGHT      EQU $C880+$278   ; User variable: ITEM_WEIGHT (2 bytes)
VAR_ENT_HS_X         EQU $C880+$27A   ; User variable: ENT_HS_X (2 bytes)
VAR_ENT_HS_Y         EQU $C880+$27C   ; User variable: ENT_HS_Y (2 bytes)
VAR_ENT_HS_W         EQU $C880+$27E   ; User variable: ENT_HS_W (2 bytes)
VAR_ENT_HS_H         EQU $C880+$280   ; User variable: ENT_HS_H (2 bytes)
VAR_CLOCK_HS_X       EQU $C880+$282   ; User variable: CLOCK_HS_X (2 bytes)
VAR_CLOCK_HS_Y       EQU $C880+$284   ; User variable: CLOCK_HS_Y (2 bytes)
VAR_CLOCK_HS_W       EQU $C880+$286   ; User variable: CLOCK_HS_W (2 bytes)
VAR_CLOCK_HS_H       EQU $C880+$288   ; User variable: CLOCK_HS_H (2 bytes)
VAR_ANT_HS_X         EQU $C880+$28A   ; User variable: ANT_HS_X (2 bytes)
VAR_ANT_HS_Y         EQU $C880+$28C   ; User variable: ANT_HS_Y (2 bytes)
VAR_ANT_HS_W         EQU $C880+$28E   ; User variable: ANT_HS_W (2 bytes)
VAR_ANT_HS_H         EQU $C880+$290   ; User variable: ANT_HS_H (2 bytes)
VAR_WGT_HS_X         EQU $C880+$292   ; User variable: WGT_HS_X (2 bytes)
VAR_WGT_HS_Y         EQU $C880+$294   ; User variable: WGT_HS_Y (2 bytes)
VAR_WGT_HS_W         EQU $C880+$296   ; User variable: WGT_HS_W (2 bytes)
VAR_WGT_HS_H         EQU $C880+$298   ; User variable: WGT_HS_H (2 bytes)
VAR_OPT_HS_X         EQU $C880+$29A   ; User variable: OPT_HS_X (2 bytes)
VAR_OPT_HS_Y         EQU $C880+$29C   ; User variable: OPT_HS_Y (2 bytes)
VAR_OPT_HS_W         EQU $C880+$29E   ; User variable: OPT_HS_W (2 bytes)
VAR_OPT_HS_H         EQU $C880+$2A0   ; User variable: OPT_HS_H (2 bytes)
VAR_CONS_HS_X        EQU $C880+$2A2   ; User variable: CONS_HS_X (2 bytes)
VAR_CONS_HS_Y        EQU $C880+$2A4   ; User variable: CONS_HS_Y (2 bytes)
VAR_CONS_HS_W        EQU $C880+$2A6   ; User variable: CONS_HS_W (2 bytes)
VAR_CONS_HS_H        EQU $C880+$2A8   ; User variable: CONS_HS_H (2 bytes)
VAR_VAULT_HS_X       EQU $C880+$2AA   ; User variable: VAULT_HS_X (2 bytes)
VAR_VAULT_HS_Y       EQU $C880+$2AC   ; User variable: VAULT_HS_Y (2 bytes)
VAR_VAULT_HS_W       EQU $C880+$2AE   ; User variable: VAULT_HS_W (2 bytes)
VAR_VAULT_HS_H       EQU $C880+$2B0   ; User variable: VAULT_HS_H (2 bytes)
VAR_SCREEN           EQU $C880+$2B2   ; User variable: SCREEN (2 bytes)
VAR_BLINK_TIMER      EQU $C880+$2B4   ; User variable: BLINK_TIMER (2 bytes)
VAR_BLINK_ON         EQU $C880+$2B6   ; User variable: BLINK_ON (2 bytes)
VAR_INTRO_PAGE       EQU $C880+$2B8   ; User variable: INTRO_PAGE (2 bytes)
VAR_CURRENT_ROOM     EQU $C880+$2BA   ; User variable: CURRENT_ROOM (2 bytes)
VAR_PLAYER_X         EQU $C880+$2BC   ; User variable: PLAYER_X (2 bytes)
VAR_PLAYER_Y         EQU $C880+$2BE   ; User variable: PLAYER_Y (2 bytes)
VAR_SCROLL_X         EQU $C880+$2C0   ; User variable: SCROLL_X (2 bytes)
VAR_PLAYER_SPEED     EQU $C880+$2C2   ; User variable: PLAYER_SPEED (2 bytes)
VAR_CURRENT_VERB     EQU $C880+$2C4   ; User variable: CURRENT_VERB (2 bytes)
VAR_NEAR_HS          EQU $C880+$2C6   ; User variable: NEAR_HS (2 bytes)
VAR_MSG_ID           EQU $C880+$2C8   ; User variable: MSG_ID (2 bytes)
VAR_MSG_TIMER        EQU $C880+$2CA   ; User variable: MSG_TIMER (2 bytes)
VAR_ROOM_EXIT        EQU $C880+$2CC   ; User variable: ROOM_EXIT (2 bytes)
VAR_FLAGS_A          EQU $C880+$2CE   ; User variable: FLAGS_A (2 bytes)
VAR_FLAGS_B          EQU $C880+$2D0   ; User variable: FLAGS_B (2 bytes)
VAR_EXIT_ROOM_TARGET EQU $C880+$2D2   ; User variable: EXIT_ROOM_TARGET (2 bytes)
VAR_CURRENT_MUSIC    EQU $C880+$2D4   ; User variable: CURRENT_MUSIC (1 bytes)
VAR_BTN1_FIRED       EQU $C880+$2D5   ; User variable: BTN1_FIRED (2 bytes)
VAR_BTN2_FIRED       EQU $C880+$2D7   ; User variable: BTN2_FIRED (2 bytes)
VAR_BTN3_FIRED       EQU $C880+$2D9   ; User variable: BTN3_FIRED (2 bytes)
VAR_PREV_BTN1        EQU $C880+$2DB   ; User variable: PREV_BTN1 (2 bytes)
VAR_PREV_BTN2        EQU $C880+$2DD   ; User variable: PREV_BTN2 (2 bytes)
VAR_PREV_BTN3        EQU $C880+$2DF   ; User variable: PREV_BTN3 (2 bytes)
VAR_INV_COUNT        EQU $C880+$2E1   ; User variable: INV_COUNT (2 bytes)
VAR_INV_WEIGHT       EQU $C880+$2E3   ; User variable: INV_WEIGHT (2 bytes)
VAR_SHOW_INVENTORY   EQU $C880+$2E5   ; User variable: SHOW_INVENTORY (2 bytes)
VAR_ACTIVE_ITEM      EQU $C880+$2E7   ; User variable: ACTIVE_ITEM (2 bytes)
VAR_INV_CURSOR       EQU $C880+$2E9   ; User variable: INV_CURSOR (2 bytes)
VAR_HEARTBEAT_TEMPO  EQU $C880+$2EB   ; User variable: HEARTBEAT_TEMPO (2 bytes)
VAR_HEARTBEAT_TIMER  EQU $C880+$2ED   ; User variable: HEARTBEAT_TIMER (2 bytes)
VAR_TESTAMENT_Y      EQU $C880+$2EF   ; User variable: TESTAMENT_Y (2 bytes)
VAR_TESTAMENT_PAGE   EQU $C880+$2F1   ; User variable: TESTAMENT_PAGE (2 bytes)
VAR_ENDING_Y         EQU $C880+$2F3   ; User variable: ENDING_Y (2 bytes)
VAR_SKIPPEDFRAMES    EQU $C880+$2F5   ; User variable: SKIPPEDFRAMES (2 bytes)
VAR_RAW1             EQU $C880+$2F7   ; User variable: RAW1 (2 bytes)
VAR_RAW2             EQU $C880+$2F9   ; User variable: RAW2 (2 bytes)
VAR_RAW3             EQU $C880+$2FB   ; User variable: RAW3 (2 bytes)
VAR_ROOM_ID          EQU $C880+$2FD   ; User variable: room_id (2 bytes)
VAR_JOY_X            EQU $C880+$2FF   ; User variable: JOY_X (2 bytes)
VAR_INV_ITEMS        EQU $C880+$301   ; User variable: INV_ITEMS (2 bytes)
VAR_DX               EQU $C880+$303   ; User variable: DX (2 bytes)
VAR_DY               EQU $C880+$305   ; User variable: DY (2 bytes)
VAR_HS               EQU $C880+$307   ; User variable: hs (2 bytes)
VAR_NPC_STATE        EQU $C880+$309   ; User variable: NPC_STATE (2 bytes)
VAR_CARETAKER_SX     EQU $C880+$30B   ; User variable: CARETAKER_SX (2 bytes)
VAR_HANS_SX          EQU $C880+$30D   ; User variable: HANS_SX (2 bytes)
VAR_PLAT_SX          EQU $C880+$30F   ; User variable: PLAT_SX (2 bytes)
VAR_COMP_SX          EQU $C880+$311   ; User variable: COMP_SX (2 bytes)
VAR_SCREEN_X         EQU $C880+$313   ; User variable: SCREEN_X (2 bytes)
VAR_ITEM_ID          EQU $C880+$315   ; User variable: item_id (2 bytes)
VAR_NPC_STATE_DATA   EQU $C880+$317   ; Mutable array 'NPC_STATE' data (4 elements x 2 bytes) (8 bytes)
VAR_INV_ITEMS_DATA   EQU $C880+$31F   ; Mutable array 'INV_ITEMS' data (8 elements x 2 bytes) (16 bytes)
PSG_MUSIC_PTR        EQU $C880+$32F   ; PSG music data pointer (2 bytes)
PSG_MUSIC_START      EQU $C880+$331   ; PSG music start pointer (for loops) (2 bytes)
PSG_MUSIC_ACTIVE     EQU $C880+$333   ; PSG music active flag (1 bytes)
PSG_IS_PLAYING       EQU $C880+$334   ; PSG playing flag (1 bytes)
PSG_DELAY_FRAMES     EQU $C880+$335   ; PSG frame delay counter (1 bytes)
PSG_MUSIC_BANK       EQU $C880+$336   ; PSG music bank ID (for multibank) (1 bytes)
SFX_PTR              EQU $C880+$337   ; SFX data pointer (2 bytes)
SFX_ACTIVE           EQU $C880+$339   ; SFX active flag (1 bytes)
SFX_BANK             EQU $C880+$33A   ; SFX bank ID (for multibank) (1 bytes)
; Array length constants
ARRAY_ITEM_WEIGHT_LEN         EQU 8   ; 8 elements
ARRAY_ENT_HS_X_LEN         EQU 4   ; 4 elements
ARRAY_ENT_HS_Y_LEN         EQU 4   ; 4 elements
ARRAY_ENT_HS_W_LEN         EQU 4   ; 4 elements
ARRAY_ENT_HS_H_LEN         EQU 4   ; 4 elements
ARRAY_CLOCK_HS_X_LEN         EQU 6   ; 6 elements
ARRAY_CLOCK_HS_Y_LEN         EQU 6   ; 6 elements
ARRAY_CLOCK_HS_W_LEN         EQU 6   ; 6 elements
ARRAY_CLOCK_HS_H_LEN         EQU 6   ; 6 elements
ARRAY_ANT_HS_X_LEN         EQU 4   ; 4 elements
ARRAY_ANT_HS_Y_LEN         EQU 4   ; 4 elements
ARRAY_ANT_HS_W_LEN         EQU 4   ; 4 elements
ARRAY_ANT_HS_H_LEN         EQU 4   ; 4 elements
ARRAY_WGT_HS_X_LEN         EQU 2   ; 2 elements
ARRAY_WGT_HS_Y_LEN         EQU 2   ; 2 elements
ARRAY_WGT_HS_W_LEN         EQU 2   ; 2 elements
ARRAY_WGT_HS_H_LEN         EQU 2   ; 2 elements
ARRAY_OPT_HS_X_LEN         EQU 2   ; 2 elements
ARRAY_OPT_HS_Y_LEN         EQU 2   ; 2 elements
ARRAY_OPT_HS_W_LEN         EQU 2   ; 2 elements
ARRAY_OPT_HS_H_LEN         EQU 2   ; 2 elements
ARRAY_CONS_HS_X_LEN         EQU 1   ; 1 elements
ARRAY_CONS_HS_Y_LEN         EQU 1   ; 1 elements
ARRAY_CONS_HS_W_LEN         EQU 1   ; 1 elements
ARRAY_CONS_HS_H_LEN         EQU 1   ; 1 elements
ARRAY_VAULT_HS_X_LEN         EQU 2   ; 2 elements
ARRAY_VAULT_HS_Y_LEN         EQU 2   ; 2 elements
ARRAY_VAULT_HS_W_LEN         EQU 2   ; 2 elements
ARRAY_VAULT_HS_H_LEN         EQU 2   ; 2 elements
ARRAY_NPC_STATE_LEN         EQU 4   ; 4 elements
ARRAY_INV_ITEMS_LEN         EQU 8   ; 8 elements



; ================================================
    ; Runtime helpers (accessible from all banks)

;***************************************************************************
; ASSET LOOKUP TABLES (for banked asset access)
; Total: 20 vectors, 2 music, 4 sfx, 7 levels, 0 animations, 0 instruments, 0 enemies
;***************************************************************************

; Vector Asset Index Mapping:
;   0 = canvas (Bank #2)
;   1 = caretaker (Bank #1)
;   2 = conservatory (Bank #1)
;   3 = crypt_logo (Bank #1)
;   4 = crystal_apprentice (Bank #1)
;   5 = desk (Bank #1)
;   6 = door_locked (Bank #1)
;   7 = elisa_ghost (Bank #2)
;   8 = entrance_arc (Bank #1)
;   9 = floor (Bank #2)
;   10 = hans_automata (Bank #1)
;   11 = lamp (Bank #1)
;   12 = locked_door (Bank #2)
;   13 = optics_pedestal (Bank #2)
;   14 = painting (Bank #1)
;   15 = platform_down (Bank #1)
;   16 = platform_up (Bank #2)
;   17 = player (Bank #1)
;   18 = vault_corridor (Bank #1)
;   19 = wall_compartment (Bank #2)

VECTOR_BANK_TABLE:
    FCB 2              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 2              ; Bank ID
    FCB 1              ; Bank ID
    FCB 2              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 2              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 2              ; Bank ID

VECTOR_ADDR_TABLE:
    FDB _CANVAS_VECTORS    ; canvas
    FDB _CARETAKER_VECTORS    ; caretaker
    FDB _CONSERVATORY_VECTORS    ; conservatory
    FDB _CRYPT_LOGO_VECTORS    ; crypt_logo
    FDB _CRYSTAL_APPRENTICE_VECTORS    ; crystal_apprentice
    FDB _DESK_VECTORS    ; desk
    FDB _DOOR_LOCKED_VECTORS    ; door_locked
    FDB _ELISA_GHOST_VECTORS    ; elisa_ghost
    FDB _ENTRANCE_ARC_VECTORS    ; entrance_arc
    FDB _FLOOR_VECTORS    ; floor
    FDB _HANS_AUTOMATA_VECTORS    ; hans_automata
    FDB _LAMP_VECTORS    ; lamp
    FDB _LOCKED_DOOR_VECTORS    ; locked_door
    FDB _OPTICS_PEDESTAL_VECTORS    ; optics_pedestal
    FDB _PAINTING_VECTORS    ; painting
    FDB _PLATFORM_DOWN_VECTORS    ; platform_down
    FDB _PLATFORM_UP_VECTORS    ; platform_up
    FDB _PLAYER_VECTORS    ; player
    FDB _VAULT_CORRIDOR_VECTORS    ; vault_corridor
    FDB _WALL_COMPARTMENT_VECTORS    ; wall_compartment

; Music Asset Index Mapping:
;   0 = exploration (Bank #1)
;   1 = intro (Bank #1)

MUSIC_BANK_TABLE:
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID

MUSIC_ADDR_TABLE:
    FDB _EXPLORATION_MUSIC    ; exploration
    FDB _INTRO_MUSIC    ; intro

; SFX Asset Index Mapping:
;   0 = door_unlock (Bank #1)
;   1 = item_pickup (Bank #2)
;   2 = puzzle_fail (Bank #1)
;   3 = puzzle_success (Bank #1)

SFX_BANK_TABLE:
    FCB 1              ; Bank ID
    FCB 2              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID

SFX_ADDR_TABLE:
    FDB _DOOR_UNLOCK_SFX    ; door_unlock
    FDB _ITEM_PICKUP_SFX    ; item_pickup
    FDB _PUZZLE_FAIL_SFX    ; puzzle_fail
    FDB _PUZZLE_SUCCESS_SFX    ; puzzle_success

; Level Asset Index Mapping:
;   0 = anteroom (Bank #1)
;   1 = clockroom (Bank #1)
;   2 = conservatory (Bank #1)
;   3 = entrance (Bank #1)
;   4 = optics_lab (Bank #2)
;   5 = vault_corridor (Bank #1)
;   6 = weights_room (Bank #1)

LEVEL_BANK_TABLE:
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 2              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID

LEVEL_ADDR_TABLE:
    FDB _ANTEROOM_LEVEL    ; anteroom
    FDB _CLOCKROOM_LEVEL    ; clockroom
    FDB _CONSERVATORY_LEVEL    ; conservatory
    FDB _ENTRANCE_LEVEL    ; entrance
    FDB _OPTICS_LAB_LEVEL    ; optics_lab
    FDB _VAULT_CORRIDOR_LEVEL    ; vault_corridor
    FDB _WEIGHTS_ROOM_LEVEL    ; weights_room

; Legacy unified tables (all assets)
ASSET_BANK_TABLE:
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
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

ASSET_ADDR_TABLE:
    FDB _LOCKED_DOOR_VECTORS    ; locked_door
    FDB _OPTICS_PEDESTAL_VECTORS    ; optics_pedestal
    FDB _WALL_COMPARTMENT_VECTORS    ; wall_compartment
    FDB _OPTICS_LAB_LEVEL    ; optics_lab
    FDB _CANVAS_VECTORS    ; canvas
    FDB _PLATFORM_UP_VECTORS    ; platform_up
    FDB _ELISA_GHOST_VECTORS    ; elisa_ghost
    FDB _ITEM_PICKUP_SFX    ; item_pickup
    FDB _FLOOR_VECTORS    ; floor
    FDB _CRYPT_LOGO_VECTORS    ; crypt_logo
    FDB _EXPLORATION_MUSIC    ; exploration
    FDB _INTRO_MUSIC    ; intro
    FDB _DOOR_LOCKED_VECTORS    ; door_locked
    FDB _PAINTING_VECTORS    ; painting
    FDB _CONSERVATORY_LEVEL    ; conservatory
    FDB _VAULT_CORRIDOR_LEVEL    ; vault_corridor
    FDB _VAULT_CORRIDOR_VECTORS    ; vault_corridor
    FDB _CONSERVATORY_VECTORS    ; conservatory
    FDB _CRYSTAL_APPRENTICE_VECTORS    ; crystal_apprentice
    FDB _HANS_AUTOMATA_VECTORS    ; hans_automata
    FDB _DESK_VECTORS    ; desk
    FDB _ANTEROOM_LEVEL    ; anteroom
    FDB _CLOCKROOM_LEVEL    ; clockroom
    FDB _ENTRANCE_LEVEL    ; entrance
    FDB _PLAYER_VECTORS    ; player
    FDB _PUZZLE_SUCCESS_SFX    ; puzzle_success
    FDB _ENTRANCE_ARC_VECTORS    ; entrance_arc
    FDB _WEIGHTS_ROOM_LEVEL    ; weights_room
    FDB _DOOR_UNLOCK_SFX    ; door_unlock
    FDB _LAMP_VECTORS    ; lamp
    FDB _PLATFORM_DOWN_VECTORS    ; platform_down
    FDB _CARETAKER_VECTORS    ; caretaker
    FDB _PUZZLE_FAIL_SFX    ; puzzle_fail

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

    ; Set DRAW_T1_SCALED to BIOS default ($7F) — SLR_DRAW_CLIPPED_PATH reads it
    ; when the fallback path is taken.
    LDA #$7F
    STA >DRAW_T1_SCALED
    ; Loop over all paths (header: FDB path_count, then FDB table)
    LDD ,X               ; D = path_count (16-bit FDB at header start)
    CMPD #0
    LBEQ DVB_DONE        ; No paths
    LEAY 2,X             ; Y = pointer to first FDB entry (after 2-byte header)
DVB_PATH_LOOP:
    PSHS D               ; Save remaining path count (2 bytes)
    LDX ,Y               ; X = path data address (FDB entry)
    ; Hybrid clip decision: fast DSWM if screen_x deep inside, slow SDCP near edges.
    LDA >DRAW_VEC_X_HI
    BEQ DVB_CHECK_POS
    INCA
    BNE DVB_USE_SDCP
    LDA >DRAW_VEC_X
    CMPA #$B0            ; -80
    BHS DVB_USE_DSWM
    BRA DVB_USE_SDCP
DVB_CHECK_POS:
    LDA >DRAW_VEC_X
    CMPA #80
    BLS DVB_USE_DSWM
DVB_USE_SDCP:
    JSR SLR_DRAW_CLIPPED_PATH
    BRA DVB_PATH_AFTER
DVB_USE_DSWM:
    JSR Draw_Sync_List_At_With_Mirrors
DVB_PATH_AFTER:
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
    ; MULTIBANK: Restore original bank
    PULS A              ; A = saved bank
    STA >CURRENT_ROM_BANK
    STA $DF00           ; Restore bank
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

; === UPDATE_LEVEL_RUNTIME ===
; Update level physics: apply velocity, gravity, bounce walls
; GP-GP elastic collisions and GP-FG static collisions
; Only the GP layer (RAM buffer) is updated — BG/FG are static ROM.
UPDATE_LEVEL_RUNTIME:
    PSHS U,X,Y,D     ; Preserve all registers
    ; MULTIBANK: Switch to level bank so FG ROM pointers are valid
    LDA >CURRENT_ROM_BANK
    PSHS A              ; Save current bank
    LDA >LEVEL_BANK
    STA >CURRENT_ROM_BANK
    STA $DF00           ; Switch to level bank
    
    ; === Update Gameplay Objects ===
    LDB >LEVEL_GP_COUNT
    CMPB #0
    LBEQ ULR_EXIT    ; No objects
    LDU >LEVEL_GP_PTR  ; U = GP buffer (RAM)
    BSR ULR_UPDATE_LAYER
    
    ; === GP-to-GP Elastic Collisions ===
    JSR ULR_GAMEPLAY_COLLISIONS
    ; === GP vs FG Static Collisions ===
    JSR ULR_GP_FG_COLLISIONS
    
ULR_EXIT:
    ; MULTIBANK: Restore original bank
    PULS A              ; A = saved bank
    STA >CURRENT_ROM_BANK
    STA $DF00           ; Restore bank
    PULS D,Y,X,U     ; Restore registers
    RTS

; === ULR_UPDATE_LAYER - Apply physics to each object in GP buffer ===
; Input: B = object count, U = buffer base (15 bytes/object)
; RAM object layout:
;   +0-1: world_x(i16)  +2: y(i8)  +3: scale  +4: rotation
;   +5: velocity_x  +6: velocity_y  +7: physics_flags  +8: collision_flags
;   +9: collision_size  +10: spawn_delay_lo  +11-12: vector_ptr  +13-14: props_ptr
ULR_UPDATE_LAYER:
    TST >LEVEL_LOADED
    LBEQ ULR_LAYER_EXIT  ; No level loaded, skip
    LDX >LEVEL_PTR   ; Load level pointer for world bounds
    
ULR_LOOP:
    PSHS B           ; Save loop counter
    
    ; Check physics_flags (RAM +7)
    LDB 7,U
    CMPB #0
    LBEQ ULR_NEXT    ; No physics at all, skip
    
    ; Check dynamic bit (bit 0)
    BITB #$01
    LBEQ ULR_NEXT    ; Not dynamic, skip
    
    ; Check gravity bit (bit 1)
    BITB #$02
    LBEQ ULR_NO_GRAVITY
    
    ; Apply gravity: velocity_y -= 1, clamp to -15
    LDB 6,U          ; velocity_y (RAM +6)
    DECB
    CMPB #$F1        ; -15
    BGE ULR_VY_OK
    LDB #$F1
ULR_VY_OK:
    STB 6,U
    
ULR_NO_GRAVITY:
    ; Apply velocity: world_x += velocity_x (16-bit)
    LDD 0,U          ; world_x (16-bit signed)
    TFR D,Y          ; Y = world_x
    LDB 5,U          ; velocity_x (8-bit signed)
    SEX              ; D = sign-extended velocity_x
    LEAY D,Y         ; Y = world_x + velocity_x (16-bit addition)
    TFR Y,D          ; D = new world_x
    STD 0,U          ; Store 16-bit world_x
    
    ; Apply velocity: y += velocity_y (16-bit to avoid wraparound)
    LDB 2,U          ; y (8-bit signed, RAM +2)
    SEX              ; D = sign-extended y
    TFR D,Y          ; Y = y (16-bit)
    LDB 6,U          ; velocity_y (8-bit signed, RAM +6)
    SEX              ; D = sign-extended velocity_y
    LEAY D,Y         ; Y = y + velocity_y (16-bit addition)
    TFR Y,D          ; D = 16-bit result
    CMPD #127        ; Clamp to i8 max
    BLE ULR_Y_NOT_MAX
    LDD #127
ULR_Y_NOT_MAX:
    CMPD #-128       ; Clamp to i8 min
    BGE ULR_Y_NOT_MIN
    LDD #-128
ULR_Y_NOT_MIN:
    STB 2,U          ; Store clamped y (RAM +2)
    
    ; === World Bounds / Wall Bounce ===
    LDB 8,U          ; collision_flags (RAM +8)
    BITB #$02        ; bounce_walls flag (bit 1)
    LBEQ ULR_NEXT    ; Skip if not bouncing
    
    ; LDX already loaded = LEVEL_PTR
    ; World bounds at LEVEL_PTR: +0=xMin(FDB), +2=xMax(FDB), +4=yMin(FDB), +6=yMax(FDB)
    
    ; --- Check X left wall (xMin) ---
    LDB 9,U          ; collision_size (RAM +9)
    SEX              ; D = sign-extended collision_size
    PSHS D           ; Save collision_size
    LDD 0,U          ; world_x (16-bit)
    SUBD ,S++        ; D = world_x - collision_size (left edge), pop
    CMPD 0,X         ; Compare with xMin
    LBGE ULR_X_MAX_CHECK
    ; Hit left wall — bounce only if moving left (velocity_x < 0)
    LDB 5,U
    CMPB #0
    LBGE ULR_X_MAX_CHECK
    LDB 9,U          ; collision_size
    SEX
    ADDD 0,X         ; D = xMin + collision_size
    STD 0,U          ; world_x = corrected position (16-bit)
    LDB 5,U
    NEGB
    STB 5,U          ; velocity_x = -velocity_x
    
    ; --- Check X right wall (xMax) ---
ULR_X_MAX_CHECK:
    LDB 9,U
    SEX
    PSHS D
    LDD 0,U          ; world_x (16-bit)
    ADDD ,S++        ; D = world_x + collision_size (right edge), pop
    CMPD 2,X         ; Compare with xMax
    LBLE ULR_Y_BOUNDS
    ; Hit right wall — bounce only if moving right (velocity_x > 0)
    LDB 5,U
    CMPB #0
    LBLE ULR_Y_BOUNDS
    LDB 9,U
    SEX
    TFR D,Y
    LDD 2,X          ; D = xMax
    PSHS Y
    SUBD ,S++        ; D = xMax - collision_size, pop
    STD 0,U          ; world_x = corrected position (16-bit)
    LDB 5,U
    NEGB
    STB 5,U
    
    ; --- Check Y bottom wall (yMin) ---
ULR_Y_BOUNDS:
    LDB 9,U
    SEX
    PSHS D
    LDB 2,U          ; y (8-bit, RAM +2)
    SEX
    SUBD ,S++        ; D = y - collision_size, pop
    CMPD 4,X         ; Compare with yMin
    LBGE ULR_Y_MAX_CHECK
    LDB 6,U
    CMPB #0
    LBGE ULR_Y_MAX_CHECK
    LDB 9,U
    SEX
    ADDD 4,X         ; D = yMin + collision_size
    STB 2,U          ; y = low byte (RAM +2)
    LDB 6,U
    NEGB
    STB 6,U
    
    ; --- Check Y top wall (yMax) ---
ULR_Y_MAX_CHECK:
    LDB 9,U
    SEX
    PSHS D
    LDB 2,U          ; y (8-bit, RAM +2)
    SEX
    ADDD ,S++        ; D = y + collision_size, pop
    CMPD 6,X         ; Compare with yMax
    LBLE ULR_NEXT
    LDB 6,U
    CMPB #0
    LBLE ULR_NEXT
    LDB 9,U
    SEX
    TFR D,Y
    LDD 6,X          ; D = yMax
    PSHS Y
    SUBD ,S++        ; D = yMax - collision_size, pop
    STB 2,U          ; y = low byte (RAM +2)
    LDB 6,U
    NEGB
    STB 6,U
    
ULR_NEXT:
    PULS B           ; Restore loop counter
    LEAU 15,U        ; Next object (15 bytes)
    DECB
    LBNE ULR_LOOP
    
ULR_LAYER_EXIT:
    RTS

; === ULR_GAMEPLAY_COLLISIONS - GP-to-GP elastic collisions ===
; Checks all pairs of GP objects; swaps velocities on collision.
; Uses Manhattan distance for speed. RAM indices via UGPC_ vars.
ULR_GAMEPLAY_COLLISIONS:
    LDA >LEVEL_GP_COUNT
    CMPA #2
    BHS UGPC_START
    RTS              ; Need at least 2 objects
UGPC_START:
    DECA
    STA UGPC_OUTER_MAX
    CLR UGPC_OUTER_IDX
    
UGPC_OUTER_LOOP:
    ; U = LEVEL_GP_BUFFER + (UGPC_OUTER_IDX * 15)
    LDU #LEVEL_GP_BUFFER
    LDB UGPC_OUTER_IDX
    BEQ UGPC_SKIP_OUTER_MUL
UGPC_OUTER_MUL:
    LEAU 15,U
    DECB
    BNE UGPC_OUTER_MUL
UGPC_SKIP_OUTER_MUL:
    ; Check if outer object is collidable (collision_flags bit 0 at RAM +8)
    LDB 8,U
    BITB #$01
    LBEQ UGPC_NEXT_OUTER
    
    LDA UGPC_OUTER_IDX
    INCA
    STA UGPC_INNER_IDX
    
UGPC_INNER_LOOP:
    LDA UGPC_INNER_IDX
    CMPA >LEVEL_GP_COUNT
    LBHS UGPC_INNER_DONE
    
    ; Y = LEVEL_GP_BUFFER + (UGPC_INNER_IDX * 15)
    LDY #LEVEL_GP_BUFFER
    LDB UGPC_INNER_IDX
    BEQ UGPC_SKIP_INNER_MUL
UGPC_INNER_MUL:
    LEAY 15,Y
    DECB
    BNE UGPC_INNER_MUL
UGPC_SKIP_INNER_MUL:
    ; Check inner collidable (RAM +8)
    LDB 8,Y
    BITB #$01
    LBEQ UGPC_NEXT_INNER
    
    ; Manhattan distance: |x1-x2| + |y1-y2|
    ; Use low byte of world_x (RAM +1) for approximate screen-relative collision
    ; Compute |dx| = |x1 - x2|
    LDB 1,U          ; x1 low byte (8-bit at RAM +1)
    SEX
    PSHS D           ; Save x1 (16-bit)
    LDB 1,Y          ; x2 low byte (8-bit at RAM +1)
    SEX
    TFR D,X
    PULS D           ; D = x1
    PSHS X
    TFR X,D          ; D = x2
    PULS X
    PSHS D           ; Push x2
    LDB 1,U
    SEX
    SUBD ,S++        ; x1 - x2, pop
    BPL UGPC_DX_POS
    COMA
    COMB
    ADDD #1          ; negate
UGPC_DX_POS:
    STD UGPC_DX
    
    ; Compute |dy| = |y1 - y2|
    LDB 2,U          ; y1 (8-bit at RAM +2)
    SEX
    PSHS D
    LDB 2,Y          ; y2 (8-bit at RAM +2)
    SEX
    TFR D,X
    PULS D
    PSHS X
    TFR X,D
    PULS X
    PSHS D           ; Push y2
    LDB 2,U
    SEX
    SUBD ,S++        ; y1 - y2, pop
    BPL UGPC_DY_POS
    COMA
    COMB
    ADDD #1
UGPC_DY_POS:
    ADDD UGPC_DX     ; D = |dx| + |dy|
    STD UGPC_DIST
    
    ; Sum of radii
    LDB 9,U          ; collision_size obj1 (RAM +9)
    ADDB 9,Y         ; + collision_size obj2
    SEX              ; D = sum_radius
    CMPD UGPC_DIST
    LBHI UGPC_COLLISION
    LBRA UGPC_NEXT_INNER
    
UGPC_COLLISION:
    ; Elastic collision: swap velocities
    LDA 5,U          ; vel_x obj1 (RAM +5)
    LDB 5,Y          ; vel_x obj2 (RAM +5)
    STB 5,U
    STA 5,Y
    LDA 6,U          ; vel_y obj1 (RAM +6)
    LDB 6,Y          ; vel_y obj2 (RAM +6)
    STB 6,U
    STA 6,Y
    
UGPC_NEXT_INNER:
    INC UGPC_INNER_IDX
    LBRA UGPC_INNER_LOOP
    
UGPC_INNER_DONE:
UGPC_NEXT_OUTER:
    INC UGPC_OUTER_IDX
    LDA UGPC_OUTER_IDX
    CMPA UGPC_OUTER_MAX
    LBHI UGPC_EXIT
    LBRA UGPC_OUTER_LOOP
    
UGPC_EXIT:
    RTS
    
; === ULR_GP_FG_COLLISIONS - GP objects vs static FG ROM collidables ===
; For each GP object (RAM, collidable) check against each FG (ROM, collidable).
; Axis-split bounce: |dy|>|dx| → negate vy; else → negate vx.
; FG ROM offsets: +0=type, +1-2=x FDB, +3-4=y FDB, +12=collision_flags, +13=collision_size
ULR_GP_FG_COLLISIONS:
    LDA >LEVEL_FG_COUNT
    LBEQ UGFC_EXIT
    STA UGFC_FG_COUNT
    LDA >LEVEL_GP_COUNT
    LBEQ UGFC_EXIT
    CLR UGFC_GP_IDX
    
UGFC_GP_LOOP:
    ; U = LEVEL_GP_BUFFER + (UGFC_GP_IDX * 15)
    LDU #LEVEL_GP_BUFFER
    LDB UGFC_GP_IDX
    BEQ UGFC_GP_ADDR_DONE
UGFC_GP_MUL:
    LEAU 15,U
    DECB
    BNE UGFC_GP_MUL
UGFC_GP_ADDR_DONE:
    ; Check GP collidable (collision_flags bit 0 at RAM +8)
    LDB 8,U
    BITB #$01
    LBEQ UGFC_NEXT_GP
    
    ; Walk FG ROM objects
    LDX >LEVEL_FG_ROM_PTR
    LDB UGFC_FG_COUNT
    
UGFC_FG_LOOP:
    CMPB #0
    LBEQ UGFC_NEXT_GP
    ; Check FG collidable (ROM +12 = collision_flags)
    LDA 12,X
    BITA #$01
    BEQ UGFC_NEXT_FG
    
    ; |dx| = |GP.x_lo - FG.x_lo|  (GP RAM +1, FG ROM +2)
    LDA 1,U          ; GP x low byte (RAM +1, world_x low byte)
    SUBA 2,X         ; A = GP.x_lo - FG.x_lo
    BPL UGFC_DX_POS
    NEGA
UGFC_DX_POS:
    STA UGFC_DX
    
    ; |dy| = |GP.y - FG.y_lo|  (GP RAM +2, FG ROM +4)
    LDA 2,U          ; GP y (RAM +2)
    SUBA 4,X         ; A = GP.y - FG.y_lo
    BPL UGFC_DY_POS
    NEGA
UGFC_DY_POS:
    STA UGFC_DY
    
    ; sum_r = GP.collision_size + FG.collision_size
    LDA 9,U          ; GP collision_size (RAM +9)
    ADDA 13,X        ; + FG collision_size (ROM +13)
    
    ; Collision if |dx| + |dy| < sum_r
    PSHS A           ; Save sum_r
    LDA UGFC_DX
    ADDA UGFC_DY
    CMPA ,S+         ; Compare distance with sum_r (pop)
    BHS UGFC_NEXT_FG ; No collision
    
    ; COLLISION! Axis-split by velocity: |vy|>|vx| → vert bounce, else horiz bounce
    LDA 6,U          ; velocity_y (RAM +6)
    BPL UGFC_VY_ABS
    NEGA
UGFC_VY_ABS:
    STA UGFC_DY      ; |vy|
    LDA 5,U          ; velocity_x (RAM +5)
    BPL UGFC_VX_ABS
    NEGA
UGFC_VX_ABS:
    CMPA UGFC_DY     ; |vx| vs |vy|
    BLT UGFC_VERT_BOUNCE ; |vx| < |vy| → vert bounce
    
UGFC_HORIZ_BOUNCE:
    LDA 5,U          ; velocity_x (RAM +5)
    NEGA
    STA 5,U
    LDA 9,U          ; collision_size (RAM +9)
    ADDA 13,X
    PSHS A           ; Save separation
    LDA 1,U          ; x low byte (RAM +1)
    CMPA 2,X
    BLT UGFC_PUSH_LEFT
    LDA 2,X
    ADDA ,S+
    STA 1,U          ; store back x low byte (RAM +1)
    BRA UGFC_NEXT_FG
UGFC_PUSH_LEFT:
    LDA 2,X
    SUBA ,S+
    STA 1,U          ; store back x low byte (RAM +1)
    BRA UGFC_NEXT_FG
    
UGFC_VERT_BOUNCE:
    LDA 6,U          ; velocity_y (RAM +6)
    NEGA
    STA 6,U
    LDA 9,U          ; collision_size (RAM +9)
    ADDA 13,X
    PSHS A
    LDA 2,U          ; y (RAM +2)
    CMPA 4,X
    BLT UGFC_PUSH_DOWN
    LDA 4,X
    ADDA ,S+
    STA 2,U          ; store back y (RAM +2)
    BRA UGFC_NEXT_FG
UGFC_PUSH_DOWN:
    LDA 4,X
    SUBA ,S+
    STA 2,U          ; store back y (RAM +2)
    
UGFC_NEXT_FG:
    LEAX 23,X        ; Next FG object (ROM stride 23)
    DECB
    LBRA UGFC_FG_LOOP
    
UGFC_NEXT_GP:
    INC UGFC_GP_IDX
    LDA UGFC_GP_IDX
    CMPA >LEVEL_GP_COUNT
    LBLO UGFC_GP_LOOP
    
UGFC_EXIT:
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

;**** PRINT_TEXT String Data ****
PRINT_TEXT_STR_84327:
    FCC "USE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2188049:
    FCC "GIVE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2209918:
    FCC "HANS"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2567303:
    FCC "TAKE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_64218094:
    FCC "CLOCK"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_65039267:
    FCC "DIARY"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_66059856:
    FCC "ELISA"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_100361836:
    FCC "intro"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3309214433:
    FCC "player"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_61386845752:
    FCC "CABINET"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_63819514689:
    FCC "EXAMINE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_72273926210:
    FCC "OIL CAN"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1863858565675:
    FCC "AT LAST."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2020710997544:
    FCC "GIVE:EYE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2020711002710:
    FCC "GIVE:KEY"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2020711006665:
    FCC "GIVE:OIL"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2260861405892:
    FCC "PAINTING"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2264259943554:
    FCC "PEDESTAL"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2376966947138:
    FCC "THE END."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2769766737209:
    FCC "anteroom"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2879828691638:
    FCC "entrance"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_59006849725498:
    FCC "CARETAKER"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_61337815899504:
    FCC "EXIT DOOR"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_62642040964184:
    FCC "GIVE:GEAR"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_62642041113543:
    FCC "GIVE:LENS"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_64485404977468:
    FCC "INVENTORY"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_69586596903166:
    FCC "ONE FREED"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_76166780098692:
    FCC "WEIGHT OK"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_87209113363546:
    FCC "caretaker"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_87509024548329:
    FCC "clockroom"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1789082557890417:
    FCC "APPRENTICE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1937924742238227:
    FCC "GEAR PANEL"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1941903265492996:
    FCC "GIVE:BLNKT"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1941903278596472:
    FCC "GIVE:PRISM"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1941903281064854:
    FCC "GIVE:SHEET"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2290510677130451:
    FCC "TOO HEAVY."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2331653882236156:
    FCC "VAULT DOOR"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2718184010937820:
    FCC "crypt_logo"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3033609450579156:
    FCC "optics_lab"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_56162530743028252:
    FCC "BLANKET  W0"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_56993795800368113:
    FCC "CLOCK LIES."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_57071759112686642:
    FCC "COMPARTMENT"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_58967237406000075:
    FCC "EYE      W1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_60075665603304044:
    FCC "GEAR     W2"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_64184922134308892:
    FCC "LENS     W1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_64184923654817225:
    FCC "LENS TAKEN."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_65431604815861807:
    FCC "MUSIC SHELF"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_66746456558499436:
    FCC "OIL      W1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_66939517582935176:
    FCC "OPTICS DOOR"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_67802925852799259:
    FCC "PRISM    W1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_67802925895808570:
    FCC "PRISM MOUNT"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_69819576141689452:
    FCC "SARCOPHAGUS"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_69993623963913400:
    FCC "SHEET    W0"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_70966799469806525:
    FCC "TO FREEDOM."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_71091249681780729:
    FCC "TRUE ENDING"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_72649866947832674:
    FCC "VOSS KEY W1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_84995521868454133:
    FCC "door_unlock"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_85730742593925120:
    FCC "elisa_ghost"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_86053808672632355:
    FCC "exploration"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_89217194792681768:
    FCC "item_pickup"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_94739863040905703:
    FCC "platform_up"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_94999312012949119:
    FCC "puzzle_fail"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_561378197138974931:
    FCC "NEEDS VOSS KEY."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_679393960477689362:
    FCC "SOME THINGS CANNOT"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_894489252191113018:
    FCC "THE VAULTED DARK."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1294369330382807152:
    FCC "DEPOSIT ITEMS."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1357395807964332428:
    FCC "* OVERWEIGHT *"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1423984413427534561:
    FCC "B2:INV    B3:VERB"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1694552686414567337:
    FCC "ELISA'S SONG FILLS"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1862347038366201699:
    FCC "GEARS TAKEN."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1961155566409942910:
    FCC "JOY:MOVE  B1:ACT"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2040298819312631916:
    FCC "NEED A CLUE."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2040300194473462220:
    FCC "NEEDS MUSIC."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2502506564742786359:
    FCC "DAWN WAITS OUTSIDE."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2609427276926758987:
    FCC "conservatory"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2725988333465993402:
    FCC "FIND CLUES. SOLVE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2980434551938874269:
    FCC "VOSS 1887. NO EYE."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3054387366258387060:
    FCC "IT IS A SPRING TO WIND."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3109258183406850463:
    FCC "weights_room"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3134159664534957280:
    FCC "YOUR MIND STAYS IN,"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3443128850001289426:
    FCC "HOLLOW ESCAPE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3569223757657551064:
    FCC "SARC. HOUR LOCK."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3688976395448209650:
    FCC "THE MECHANISM HALTS."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_4088011977317884966:
    FCC "KONRAD VOSS IS DEAD."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_4134672786914975283:
    FCC "11:07. BLNKT+KEY!"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_4475750633065476197:
    FCC "NO ITEM SELECTED."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_4588030343759193236:
    FCC "HIS WINDING CLOCK."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_4750152274843692088:
    FCC "ELISA'S CURSE LIFTS."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_4810967809196323313:
    FCC "THE CRYPT SEALED."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_5194980316262412902:
    FCC "WORKSHOP BEYOND."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_5266085525079663479:
    FCC "4-DIGIT LOCK."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_5393684617976031258:
    FCC "crystal_apprentice"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_5995724771220415910:
    FCC "PUZZLES. ESCAPE."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_6038144227778049379:
    FCC "WHALE OIL CAN."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_6391486935903418068:
    FCC "B3:SEL B1:EQUIP"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_6491622880375508119:
    FCC "OPTICS LAB LOCKED."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_6586363433779781634:
    FCC "BE WOUND DOWN."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_6894498445181154440:
    FCC "A NEW HOME IN YOU."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_6950660334503696963:
    FCC "OLD SHEET MUSIC."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_7582700907259536897:
    FCC "WARM. OPTICS OPEN."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_7616489895533870322:
    FCC "HIDDEN COMPARTMENT."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_7772660912310229250:
    FCC "puzzle_success"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_7909031177940311606:
    FCC "NEED A PRISM."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_7909073815850340594:
    FCC "NEEDS WARMTH."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_8058628335699392711:
    FCC "YOUR BODY WALKS OUT."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_8802356165028628829:
    FCC "wall_compartment"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_9013778969627065598:
    FCC "FIND CLUE FIRST."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_9120385760502433312:
    FCC "PRESS BUTTON 1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_9259163830802518359:
    FCC "vault_corridor"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_9347069291597612016:
    FCC "A GLASS PRISM."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_9679949307385682704:
    FCC "SMALL SIDE DOOR."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_10687858946875495377:
    FCC "hans_automata"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_11231926301297463383:
    FCC "TICK... NEED OIL..."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_11476744573813328057:
    FCC "BALANCE SHIFTS."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_11654038037461762538:
    FCC "THE CRYPT IS SILENT"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_11740726934691799833:
    FCC "DIARY: LENS INSIDE."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_12512026909897550613:
    FCC "PANEL SLIDES OPEN!"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_12688323002745966939:
    FCC "1-8-8-7. OPENS!"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_12694600541101677361:
    FCC "TIME IS NOT A RIVER."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_12942139072472107330:
    FCC "ALREADY TOOK IT."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_12951030068845256446:
    FCC "VAULT UNSEALED!"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_13801705626177845190:
    FCC "SHE SMILES. C-E-G."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_14011047070412848655:
    FCC "CANNOT DO THAT."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_14122068582122076643:
    FCC "VAULT AWAITS."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_14476289871539234619:
    FCC "VOSS IS DEAD."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_14647010181714948705:
    FCC "TRIES TO SING."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_15001388746321493806:
    FCC "WEIGHTS ROOM."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_15031599020925928582:
    FCC "THE CRYPT OPENS."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_15031601608756456041:
    FCC "THE CRYSTAL EYE!"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_15262964977784735399:
    FCC "WORKSHOP DOOR"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_15373067420087200981:
    FCC "BTN1 TO RESTART"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_15647433387823626580:
    FCC "LONG LIVE THE MECHANISM."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_16142505063574718582:
    FCC "NEED LENS FIRST."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_16477571072303887030:
    FCC "WANTS THE GEARS."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_16517487495056338189:
    FCC "PRISM MOUNT. EMPTY."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_16762347117432342118:
    FCC "WOUND LIKE A SPRING."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_16812907733027968162:
    FCC "BARELY ALIVE."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17028423667663067371:
    FCC "YOU ARE THE ASSESSOR."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17236580857328069985:
    FCC "HANS NEEDS OIL."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17258032087471670510:
    FCC "platform_down"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17345789615299082788:
    FCC "HANS FINDS HIS REST."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17643359177242884552:
    FCC "HANS TICKS ON ALONE."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17850884399050856369:
    FCC "SWITZERLAND, 1887."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17877550292306147137:
    FCC "CLOCK: 11:07."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17953374719443405528:
    FCC "CONSERV. DOOR"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17954386693183881976:
    FCC "THE TICKING FOUND"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_18135904787860682873:
    FCC "YOU FOLLOW HER VOICE"
    FCB $80          ; Vectrex string terminator

;**** PRINT_MSG Dispatch ****
PRINT_MSG_DISPATCH:
    ; VAR_ARG0 = msg_id (set by PRINT_MSG caller)
    LDB >VAR_ARG0+1      ; B = msg_id (low byte)
    BEQ PRINT_MSG_SKIP  ; id=0 → nothing to print
    DECB                ; 0-based index (id starts at 1)
    LSLB               ; B = index * 2
    LSLB               ; B = index * 4
    LDX #PRINT_MSG_TABLE
    ABX                ; X = &table[index * 4]
    LDB ,X+            ; B = x (signed byte)
    SEX                ; D = sign-extended x
    STD >VAR_ARG0
    LDB ,X+            ; B = y (signed byte)
    SEX                ; D = sign-extended y
    STD >VAR_ARG1
    LDX ,X             ; X = string pointer
    STX >VAR_ARG2
    JMP VECTREX_PRINT_TEXT  ; tail call (no RTS needed)
PRINT_MSG_SKIP:
    RTS

PRINT_MSG_TABLE:
    ; 4 bytes/entry: x(signed), y(signed), string_ptr(2)
    FCB -70  ; msg 1 x
    FCB 114  ; msg 1 y
    FDB PRINT_TEXT_STR_2980434551938874269  ; msg 1 "VOSS 1887. NO EYE."
    FCB -63  ; msg 2 x
    FCB 114  ; msg 2 y
    FDB PRINT_TEXT_STR_5266085525079663479  ; msg 2 "4-DIGIT LOCK."
    FCB -63  ; msg 3 x
    FCB 114  ; msg 3 y
    FDB PRINT_TEXT_STR_2040298819312631916  ; msg 3 "NEED A CLUE."
    FCB -70  ; msg 4 x
    FCB 114  ; msg 4 y
    FDB PRINT_TEXT_STR_12688323002745966939  ; msg 4 "1-8-8-7. OPENS!"
    FCB -70  ; msg 5 x
    FCB 114  ; msg 5 y
    FDB PRINT_TEXT_STR_14011047070412848655  ; msg 5 "CANNOT DO THAT."
    FCB -63  ; msg 6 x
    FCB 114  ; msg 6 y
    FDB PRINT_TEXT_STR_3569223757657551064  ; msg 6 "SARC. HOUR LOCK."
    FCB -77  ; msg 7 x
    FCB 114  ; msg 7 y
    FDB PRINT_TEXT_STR_4134672786914975283  ; msg 7 "11:07. BLNKT+KEY!"
    FCB -70  ; msg 8 x
    FCB 114  ; msg 8 y
    FDB PRINT_TEXT_STR_17877550292306147137  ; msg 8 "CLOCK: 11:07."
    FCB -63  ; msg 9 x
    FCB 114  ; msg 9 y
    FDB PRINT_TEXT_STR_11740726934691799833  ; msg 9 "DIARY: LENS INSIDE."
    FCB -63  ; msg 10 x
    FCB 114  ; msg 10 y
    FDB PRINT_TEXT_STR_64184923654817225  ; msg 10 "LENS TAKEN."
    FCB -63  ; msg 11 x
    FCB 114  ; msg 11 y
    FDB PRINT_TEXT_STR_12942139072472107330  ; msg 11 "ALREADY TOOK IT."
    FCB -63  ; msg 12 x
    FCB 114  ; msg 12 y
    FDB PRINT_TEXT_STR_15001388746321493806  ; msg 12 "WEIGHTS ROOM."
    FCB -70  ; msg 13 x
    FCB 114  ; msg 13 y
    FDB PRINT_TEXT_STR_1294369330382807152  ; msg 13 "DEPOSIT ITEMS."
    FCB -63  ; msg 14 x
    FCB 114  ; msg 14 y
    FDB PRINT_TEXT_STR_11476744573813328057  ; msg 14 "BALANCE SHIFTS."
    FCB -63  ; msg 15 x
    FCB 114  ; msg 15 y
    FDB PRINT_TEXT_STR_5194980316262412902  ; msg 15 "WORKSHOP BEYOND."
    FCB -56  ; msg 16 x
    FCB 114  ; msg 16 y
    FDB PRINT_TEXT_STR_2290510677130451  ; msg 16 "TOO HEAVY."
    FCB -70  ; msg 17 x
    FCB 114  ; msg 17 y
    FDB PRINT_TEXT_STR_16517487495056338189  ; msg 17 "PRISM MOUNT. EMPTY."
    FCB -63  ; msg 18 x
    FCB 114  ; msg 18 y
    FDB PRINT_TEXT_STR_7909031177940311606  ; msg 18 "NEED A PRISM."
    FCB -63  ; msg 19 x
    FCB 114  ; msg 19 y
    FDB PRINT_TEXT_STR_12512026909897550613  ; msg 19 "PANEL SLIDES OPEN!"
    FCB -70  ; msg 20 x
    FCB 114  ; msg 20 y
    FDB PRINT_TEXT_STR_7616489895533870322  ; msg 20 "HIDDEN COMPARTMENT."
    FCB -63  ; msg 21 x
    FCB 114  ; msg 21 y
    FDB PRINT_TEXT_STR_15031601608756456041  ; msg 21 "THE CRYSTAL EYE!"
    FCB -63  ; msg 22 x
    FCB 114  ; msg 22 y
    FDB PRINT_TEXT_STR_16142505063574718582  ; msg 22 "NEED LENS FIRST."
    FCB -56  ; msg 23 x
    FCB 114  ; msg 23 y
    FDB PRINT_TEXT_STR_9013778969627065598  ; msg 23 "FIND CLUE FIRST."
    FCB -70  ; msg 24 x
    FCB 114  ; msg 24 y
    FDB PRINT_TEXT_STR_16812907733027968162  ; msg 24 "BARELY ALIVE."
    FCB -63  ; msg 25 x
    FCB 114  ; msg 25 y
    FDB PRINT_TEXT_STR_1862347038366201699  ; msg 25 "GEARS TAKEN."
    FCB -63  ; msg 26 x
    FCB 114  ; msg 26 y
    FDB PRINT_TEXT_STR_7582700907259536897  ; msg 26 "WARM. OPTICS OPEN."
    FCB -63  ; msg 27 x
    FCB 114  ; msg 27 y
    FDB PRINT_TEXT_STR_11231926301297463383  ; msg 27 "TICK... NEED OIL..."
    FCB -70  ; msg 28 x
    FCB 114  ; msg 28 y
    FDB PRINT_TEXT_STR_56993795800368113  ; msg 28 "CLOCK LIES."
    FCB -70  ; msg 29 x
    FCB 114  ; msg 29 y
    FDB PRINT_TEXT_STR_14647010181714948705  ; msg 29 "TRIES TO SING."
    FCB -63  ; msg 30 x
    FCB 114  ; msg 30 y
    FDB PRINT_TEXT_STR_13801705626177845190  ; msg 30 "SHE SMILES. C-E-G."
    FCB -70  ; msg 31 x
    FCB 114  ; msg 31 y
    FDB PRINT_TEXT_STR_4588030343759193236  ; msg 31 "HIS WINDING CLOCK."
    FCB -56  ; msg 32 x
    FCB 114  ; msg 32 y
    FDB PRINT_TEXT_STR_14122068582122076643  ; msg 32 "VAULT AWAITS."
    FCB -63  ; msg 33 x
    FCB 114  ; msg 33 y
    FDB PRINT_TEXT_STR_6950660334503696963  ; msg 33 "OLD SHEET MUSIC."
    FCB -56  ; msg 34 x
    FCB 114  ; msg 34 y
    FDB PRINT_TEXT_STR_6038144227778049379  ; msg 34 "WHALE OIL CAN."
    FCB -56  ; msg 35 x
    FCB 114  ; msg 35 y
    FDB PRINT_TEXT_STR_9347069291597612016  ; msg 35 "A GLASS PRISM."
    FCB -56  ; msg 36 x
    FCB 114  ; msg 36 y
    FDB PRINT_TEXT_STR_7909073815850340594  ; msg 36 "NEEDS WARMTH."
    FCB -56  ; msg 37 x
    FCB 114  ; msg 37 y
    FDB PRINT_TEXT_STR_17236580857328069985  ; msg 37 "HANS NEEDS OIL."
    FCB -49  ; msg 38 x
    FCB 114  ; msg 38 y
    FDB PRINT_TEXT_STR_2040300194473462220  ; msg 38 "NEEDS MUSIC."
    FCB -70  ; msg 39 x
    FCB 114  ; msg 39 y
    FDB PRINT_TEXT_STR_16477571072303887030  ; msg 39 "WANTS THE GEARS."
    FCB -63  ; msg 40 x
    FCB 114  ; msg 40 y
    FDB PRINT_TEXT_STR_6491622880375508119  ; msg 40 "OPTICS LAB LOCKED."
    FCB -63  ; msg 41 x
    FCB 114  ; msg 41 y
    FDB PRINT_TEXT_STR_4475750633065476197  ; msg 41 "NO ITEM SELECTED."
    FCB -63  ; msg 42 x
    FCB 114  ; msg 42 y
    FDB PRINT_TEXT_STR_561378197138974931  ; msg 42 "NEEDS VOSS KEY."
    FCB -63  ; msg 43 x
    FCB 114  ; msg 43 y
    FDB PRINT_TEXT_STR_9679949307385682704  ; msg 43 "SMALL SIDE DOOR."
    FCB -63  ; msg 44 x
    FCB 114  ; msg 44 y
    FDB PRINT_TEXT_STR_12951030068845256446  ; msg 44 "VAULT UNSEALED!"

; === CROSS-BANK USER FUNCTION TRAMPOLINES ===
TRAMP_CHECK_ENTRANCE_HOTSPOTS:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR CHECK_ENTRANCE_HOTSPOTS
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_ENTER_ROOM:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR ENTER_ROOM
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_CHECK_WORKSHOP_HOTSPOTS:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR CHECK_WORKSHOP_HOTSPOTS
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_CHECK_ANTEROOM_HOTSPOTS:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR CHECK_ANTEROOM_HOTSPOTS
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_CHECK_WEIGHTS_HOTSPOTS:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR CHECK_WEIGHTS_HOTSPOTS
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_CHECK_OPTICS_HOTSPOTS:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR CHECK_OPTICS_HOTSPOTS
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_CHECK_CONSERVATORY_HOTSPOTS:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR CHECK_CONSERVATORY_HOTSPOTS
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_CHECK_VAULT_HOTSPOTS:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR CHECK_VAULT_HOTSPOTS
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_INTERACT_CONSERVATORY:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR INTERACT_CONSERVATORY
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_ACCELERATE_HEARTBEAT:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR ACCELERATE_HEARTBEAT
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_DROP_ITEM:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR DROP_ITEM
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_PICKUP_ITEM:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR PICKUP_ITEM
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_UPDATE_ROOM:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$01  ; switch to bank #1
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR UPDATE_ROOM
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS

; === CONST ARRAY DATA (relocated to fixed bank - accessible from any bank) ===
ARRAY_ITEM_WEIGHT_DATA:
    FDB 1   ; Element 0
    FDB 2   ; Element 1
    FDB 1   ; Element 2
    FDB 0   ; Element 3
    FDB 1   ; Element 4
    FDB 1   ; Element 5
    FDB 0   ; Element 6
    FDB 1   ; Element 7

; Array literal for variable 'ENT_HS_X' (4 elements, 2 bytes each)
ARRAY_ENT_HS_X_DATA:
    FDB 260   ; Element 0
    FDB 738   ; Element 1
    FDB 100   ; Element 2
    FDB 40   ; Element 3

; Array literal for variable 'ENT_HS_Y' (4 elements, 2 bytes each)
ARRAY_ENT_HS_Y_DATA:
    FDB -98   ; Element 0
    FDB -88   ; Element 1
    FDB -110   ; Element 2
    FDB -95   ; Element 3

; Array literal for variable 'ENT_HS_W' (4 elements, 2 bytes each)
ARRAY_ENT_HS_W_DATA:
    FDB 25   ; Element 0
    FDB 40   ; Element 1
    FDB 22   ; Element 2
    FDB 18   ; Element 3

; Array literal for variable 'ENT_HS_H' (4 elements, 2 bytes each)
ARRAY_ENT_HS_H_DATA:
    FDB 35   ; Element 0
    FDB 45   ; Element 1
    FDB 30   ; Element 2
    FDB 28   ; Element 3

; Array literal for variable 'CLOCK_HS_X' (6 elements, 2 bytes each)
ARRAY_CLOCK_HS_X_DATA:
    FDB 190   ; Element 0
    FDB 400   ; Element 1
    FDB 520   ; Element 2
    FDB 280   ; Element 3
    FDB 460   ; Element 4
    FDB 700   ; Element 5

; Array literal for variable 'CLOCK_HS_Y' (6 elements, 2 bytes each)
ARRAY_CLOCK_HS_Y_DATA:
    FDB -80   ; Element 0
    FDB -70   ; Element 1
    FDB -80   ; Element 2
    FDB -110   ; Element 3
    FDB -80   ; Element 4
    FDB -90   ; Element 5

; Array literal for variable 'CLOCK_HS_W' (6 elements, 2 bytes each)
ARRAY_CLOCK_HS_W_DATA:
    FDB 40   ; Element 0
    FDB 35   ; Element 1
    FDB 35   ; Element 2
    FDB 22   ; Element 3
    FDB 20   ; Element 4
    FDB 22   ; Element 5

; Array literal for variable 'CLOCK_HS_H' (6 elements, 2 bytes each)
ARRAY_CLOCK_HS_H_DATA:
    FDB 40   ; Element 0
    FDB 40   ; Element 1
    FDB 35   ; Element 2
    FDB 30   ; Element 3
    FDB 25   ; Element 4
    FDB 32   ; Element 5

; Array literal for variable 'ANT_HS_X' (4 elements, 2 bytes each)
ARRAY_ANT_HS_X_DATA:
    FDB 300   ; Element 0
    FDB 735   ; Element 1
    FDB 150   ; Element 2
    FDB 550   ; Element 3

; Array literal for variable 'ANT_HS_Y' (4 elements, 2 bytes each)
ARRAY_ANT_HS_Y_DATA:
    FDB -95   ; Element 0
    FDB -95   ; Element 1
    FDB -95   ; Element 2
    FDB -95   ; Element 3

; Array literal for variable 'ANT_HS_W' (4 elements, 2 bytes each)
ARRAY_ANT_HS_W_DATA:
    FDB 40   ; Element 0
    FDB 30   ; Element 1
    FDB 35   ; Element 2
    FDB 35   ; Element 3

; Array literal for variable 'ANT_HS_H' (4 elements, 2 bytes each)
ARRAY_ANT_HS_H_DATA:
    FDB 35   ; Element 0
    FDB 30   ; Element 1
    FDB 35   ; Element 2
    FDB 35   ; Element 3

; Array literal for variable 'WGT_HS_X' (2 elements, 2 bytes each)
ARRAY_WGT_HS_X_DATA:
    FDB 280   ; Element 0
    FDB 570   ; Element 1

; Array literal for variable 'WGT_HS_Y' (2 elements, 2 bytes each)
ARRAY_WGT_HS_Y_DATA:
    FDB -95   ; Element 0
    FDB -95   ; Element 1

; Array literal for variable 'WGT_HS_W' (2 elements, 2 bytes each)
ARRAY_WGT_HS_W_DATA:
    FDB 40   ; Element 0
    FDB 30   ; Element 1

; Array literal for variable 'WGT_HS_H' (2 elements, 2 bytes each)
ARRAY_WGT_HS_H_DATA:
    FDB 35   ; Element 0
    FDB 30   ; Element 1

; Array literal for variable 'OPT_HS_X' (2 elements, 2 bytes each)
ARRAY_OPT_HS_X_DATA:
    FDB 250   ; Element 0
    FDB 420   ; Element 1

; Array literal for variable 'OPT_HS_Y' (2 elements, 2 bytes each)
ARRAY_OPT_HS_Y_DATA:
    FDB -95   ; Element 0
    FDB -95   ; Element 1

; Array literal for variable 'OPT_HS_W' (2 elements, 2 bytes each)
ARRAY_OPT_HS_W_DATA:
    FDB 40   ; Element 0
    FDB 30   ; Element 1

; Array literal for variable 'OPT_HS_H' (2 elements, 2 bytes each)
ARRAY_OPT_HS_H_DATA:
    FDB 35   ; Element 0
    FDB 30   ; Element 1

; Array literal for variable 'CONS_HS_X' (1 elements, 2 bytes each)
ARRAY_CONS_HS_X_DATA:
    FDB 0   ; Element 0

; Array literal for variable 'CONS_HS_Y' (1 elements, 2 bytes each)
ARRAY_CONS_HS_Y_DATA:
    FDB -100   ; Element 0

; Array literal for variable 'CONS_HS_W' (1 elements, 2 bytes each)
ARRAY_CONS_HS_W_DATA:
    FDB 40   ; Element 0

; Array literal for variable 'CONS_HS_H' (1 elements, 2 bytes each)
ARRAY_CONS_HS_H_DATA:
    FDB 40   ; Element 0

; Array literal for variable 'VAULT_HS_X' (2 elements, 2 bytes each)
ARRAY_VAULT_HS_X_DATA:
    FDB -30   ; Element 0
    FDB 70   ; Element 1

; Array literal for variable 'VAULT_HS_Y' (2 elements, 2 bytes each)
ARRAY_VAULT_HS_Y_DATA:
    FDB -100   ; Element 0
    FDB -90   ; Element 1

; Array literal for variable 'VAULT_HS_W' (2 elements, 2 bytes each)
ARRAY_VAULT_HS_W_DATA:
    FDB 35   ; Element 0
    FDB 22   ; Element 1

; Array literal for variable 'VAULT_HS_H' (2 elements, 2 bytes each)
ARRAY_VAULT_HS_H_DATA:
    FDB 40   ; Element 0
    FDB 32   ; Element 1

; Array literal for variable 'NPC_STATE' (4 elements, 2 bytes each)
ARRAY_NPC_STATE_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3

; Array literal for variable 'INV_ITEMS' (8 elements, 2 bytes each)
ARRAY_INV_ITEMS_DATA:
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

