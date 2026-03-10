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
LEVEL_BG_ROM_PTR     EQU $C880+$46   ; BG layer ROM pointer (2 bytes)
LEVEL_GP_ROM_PTR     EQU $C880+$48   ; GP layer ROM pointer (2 bytes)
LEVEL_FG_ROM_PTR     EQU $C880+$4A   ; FG layer ROM pointer (2 bytes)
LEVEL_GP_PTR         EQU $C880+$4C   ; GP active pointer (RAM buffer after LOAD_LEVEL) (2 bytes)
LEVEL_BANK           EQU $C880+$4E   ; Bank ID for current level (for multibank) (1 bytes)
SLR_CUR_X            EQU $C880+$4F   ; SHOW_LEVEL: tracked beam X for per-segment clipping (1 bytes)
LEVEL_GP_BUFFER      EQU $C880+$50   ; GP objects RAM buffer (max 8 objects × 15 bytes) (120 bytes)
UGPC_OUTER_IDX       EQU $C880+$C8   ; GP-GP outer loop index (1 bytes)
UGPC_OUTER_MAX       EQU $C880+$C9   ; GP-GP outer loop max (count-1) (1 bytes)
UGPC_INNER_IDX       EQU $C880+$CA   ; GP-GP inner loop index (1 bytes)
UGPC_DX              EQU $C880+$CB   ; GP-GP |dx| (16-bit) (2 bytes)
UGPC_DIST            EQU $C880+$CD   ; GP-GP Manhattan distance (16-bit) (2 bytes)
UGFC_GP_IDX          EQU $C880+$CF   ; GP-FG outer loop GP index (1 bytes)
UGFC_FG_COUNT        EQU $C880+$D0   ; GP-FG inner loop FG count (1 bytes)
UGFC_DX              EQU $C880+$D1   ; GP-FG |dx| (1 bytes)
UGFC_DY              EQU $C880+$D2   ; GP-FG |dy| (1 bytes)
TEXT_SCALE_H         EQU $C880+$D3   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$D4   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_STATE_TITLE      EQU $C880+$D5   ; User variable: STATE_TITLE (2 bytes)
VAR_STATE_INTRO      EQU $C880+$D7   ; User variable: STATE_INTRO (2 bytes)
VAR_STATE_ROOM       EQU $C880+$D9   ; User variable: STATE_ROOM (2 bytes)
VAR_STATE_ENDING     EQU $C880+$DB   ; User variable: STATE_ENDING (2 bytes)
VAR_STATE_TESTAMENT  EQU $C880+$DD   ; User variable: STATE_TESTAMENT (2 bytes)
VAR_ROOM_ENTRANCE    EQU $C880+$DF   ; User variable: ROOM_ENTRANCE (2 bytes)
VAR_ROOM_WORKSHOP    EQU $C880+$E1   ; User variable: ROOM_WORKSHOP (2 bytes)
VAR_ROOM_ANTEROOM    EQU $C880+$E3   ; User variable: ROOM_ANTEROOM (2 bytes)
VAR_ROOM_WEIGHTS     EQU $C880+$E5   ; User variable: ROOM_WEIGHTS (2 bytes)
VAR_ROOM_OPTICS      EQU $C880+$E7   ; User variable: ROOM_OPTICS (2 bytes)
VAR_ROOM_CONSERVATORY EQU $C880+$E9   ; User variable: ROOM_CONSERVATORY (2 bytes)
VAR_ROOM_VAULT_CORRIDOR EQU $C880+$EB   ; User variable: ROOM_VAULT_CORRIDOR (2 bytes)
VAR_VERB_EXAMINE     EQU $C880+$ED   ; User variable: VERB_EXAMINE (2 bytes)
VAR_VERB_TAKE        EQU $C880+$EF   ; User variable: VERB_TAKE (2 bytes)
VAR_VERB_USE         EQU $C880+$F1   ; User variable: VERB_USE (2 bytes)
VAR_VERB_GIVE        EQU $C880+$F3   ; User variable: VERB_GIVE (2 bytes)
VAR_NPC_CARETAKER    EQU $C880+$F5   ; User variable: NPC_CARETAKER (2 bytes)
VAR_NPC_HANS         EQU $C880+$F7   ; User variable: NPC_HANS (2 bytes)
VAR_NPC_ELISA        EQU $C880+$F9   ; User variable: NPC_ELISA (2 bytes)
VAR_NPC_APPRENTICE   EQU $C880+$FB   ; User variable: NPC_APPRENTICE (2 bytes)
VAR_ITEM_LENS        EQU $C880+$FD   ; User variable: ITEM_LENS (2 bytes)
VAR_ITEM_GEAR        EQU $C880+$FF   ; User variable: ITEM_GEAR (2 bytes)
VAR_ITEM_PRISM       EQU $C880+$101   ; User variable: ITEM_PRISM (2 bytes)
VAR_ITEM_BLANKET     EQU $C880+$103   ; User variable: ITEM_BLANKET (2 bytes)
VAR_ITEM_EYE         EQU $C880+$105   ; User variable: ITEM_EYE (2 bytes)
VAR_ITEM_OIL         EQU $C880+$107   ; User variable: ITEM_OIL (2 bytes)
VAR_ITEM_SHEET       EQU $C880+$109   ; User variable: ITEM_SHEET (2 bytes)
VAR_ITEM_KEY         EQU $C880+$10B   ; User variable: ITEM_KEY (2 bytes)
VAR_ITEM_COUNT       EQU $C880+$10D   ; User variable: ITEM_COUNT (2 bytes)
VAR_ITEM_WEIGHT      EQU $C880+$10F   ; User variable: ITEM_WEIGHT (2 bytes)
VAR_MUSIC_NONE       EQU $C880+$111   ; User variable: MUSIC_NONE (2 bytes)
VAR_MUSIC_TITLE      EQU $C880+$113   ; User variable: MUSIC_TITLE (2 bytes)
VAR_MUSIC_EXPLORATION EQU $C880+$115   ; User variable: MUSIC_EXPLORATION (2 bytes)
VAR_FL_DATE_KNOWN    EQU $C880+$117   ; User variable: FL_DATE_KNOWN (2 bytes)
VAR_FL_TALLER_OPEN   EQU $C880+$119   ; User variable: FL_TALLER_OPEN (2 bytes)
VAR_FL_SARC_OPEN     EQU $C880+$11B   ; User variable: FL_SARC_OPEN (2 bytes)
VAR_FL_CLOCK_READ    EQU $C880+$11D   ; User variable: FL_CLOCK_READ (2 bytes)
VAR_FL_PANEL_ACTIVE  EQU $C880+$11F   ; User variable: FL_PANEL_ACTIVE (2 bytes)
VAR_FL_ITEMS_DEPOSITED EQU $C880+$121   ; User variable: FL_ITEMS_DEPOSITED (2 bytes)
VAR_FL_OPTICS_SOLVED EQU $C880+$123   ; User variable: FL_OPTICS_SOLVED (2 bytes)
VAR_FL_OPTICS_OPEN   EQU $C880+$125   ; User variable: FL_OPTICS_OPEN (2 bytes)
VAR_FL_PLAT_DOWN     EQU $C880+$127   ; User variable: FL_PLAT_DOWN (2 bytes)
VAR_FL_ELISA_HELPED  EQU $C880+$129   ; User variable: FL_ELISA_HELPED (2 bytes)
VAR_FL_HANS_HELPED   EQU $C880+$12B   ; User variable: FL_HANS_HELPED (2 bytes)
VAR_FL_CARETAKER_DONE EQU $C880+$12D   ; User variable: FL_CARETAKER_DONE (2 bytes)
VAR_FL_EXIT_TESTAMENT EQU $C880+$12F   ; User variable: FL_EXIT_TESTAMENT (2 bytes)
VAR_FL_EXIT_ENDING   EQU $C880+$131   ; User variable: FL_EXIT_ENDING (2 bytes)
VAR_ENT_HS_PAINTING  EQU $C880+$133   ; User variable: ENT_HS_PAINTING (2 bytes)
VAR_ENT_HS_DOOR      EQU $C880+$135   ; User variable: ENT_HS_DOOR (2 bytes)
VAR_ENT_HS_CARETAKER EQU $C880+$137   ; User variable: ENT_HS_CARETAKER (2 bytes)
VAR_ENT_HS_CONS_DOOR EQU $C880+$139   ; User variable: ENT_HS_CONS_DOOR (2 bytes)
VAR_ENT_HS_X         EQU $C880+$13B   ; User variable: ENT_HS_X (2 bytes)
VAR_ENT_HS_Y         EQU $C880+$13D   ; User variable: ENT_HS_Y (2 bytes)
VAR_ENT_HS_W         EQU $C880+$13F   ; User variable: ENT_HS_W (2 bytes)
VAR_ENT_HS_H         EQU $C880+$141   ; User variable: ENT_HS_H (2 bytes)
VAR_CLOCK_HS_SARC    EQU $C880+$143   ; User variable: CLOCK_HS_SARC (2 bytes)
VAR_CLOCK_HS_CLOCK   EQU $C880+$145   ; User variable: CLOCK_HS_CLOCK (2 bytes)
VAR_CLOCK_HS_GEAR    EQU $C880+$147   ; User variable: CLOCK_HS_GEAR (2 bytes)
VAR_CLOCK_HS_HANS    EQU $C880+$149   ; User variable: CLOCK_HS_HANS (2 bytes)
VAR_CLOCK_HS_OIL     EQU $C880+$14B   ; User variable: CLOCK_HS_OIL (2 bytes)
VAR_CLOCK_HS_OPTICS  EQU $C880+$14D   ; User variable: CLOCK_HS_OPTICS (2 bytes)
VAR_CLOCK_HS_X       EQU $C880+$14F   ; User variable: CLOCK_HS_X (2 bytes)
VAR_CLOCK_HS_Y       EQU $C880+$151   ; User variable: CLOCK_HS_Y (2 bytes)
VAR_CLOCK_HS_W       EQU $C880+$153   ; User variable: CLOCK_HS_W (2 bytes)
VAR_CLOCK_HS_H       EQU $C880+$155   ; User variable: CLOCK_HS_H (2 bytes)
VAR_ANT_HS_DIARY     EQU $C880+$157   ; User variable: ANT_HS_DIARY (2 bytes)
VAR_ANT_HS_EXIT      EQU $C880+$159   ; User variable: ANT_HS_EXIT (2 bytes)
VAR_ANT_HS_SHELF     EQU $C880+$15B   ; User variable: ANT_HS_SHELF (2 bytes)
VAR_ANT_HS_CABINET   EQU $C880+$15D   ; User variable: ANT_HS_CABINET (2 bytes)
VAR_ANT_HS_X         EQU $C880+$15F   ; User variable: ANT_HS_X (2 bytes)
VAR_ANT_HS_Y         EQU $C880+$161   ; User variable: ANT_HS_Y (2 bytes)
VAR_ANT_HS_W         EQU $C880+$163   ; User variable: ANT_HS_W (2 bytes)
VAR_ANT_HS_H         EQU $C880+$165   ; User variable: ANT_HS_H (2 bytes)
VAR_WGT_HS_PEDESTAL  EQU $C880+$167   ; User variable: WGT_HS_PEDESTAL (2 bytes)
VAR_WGT_HS_EXIT      EQU $C880+$169   ; User variable: WGT_HS_EXIT (2 bytes)
VAR_WGT_HS_X         EQU $C880+$16B   ; User variable: WGT_HS_X (2 bytes)
VAR_WGT_HS_Y         EQU $C880+$16D   ; User variable: WGT_HS_Y (2 bytes)
VAR_WGT_HS_W         EQU $C880+$16F   ; User variable: WGT_HS_W (2 bytes)
VAR_WGT_HS_H         EQU $C880+$171   ; User variable: WGT_HS_H (2 bytes)
VAR_OPT_HS_PEDESTAL  EQU $C880+$173   ; User variable: OPT_HS_PEDESTAL (2 bytes)
VAR_OPT_HS_COMPARTMENT EQU $C880+$175   ; User variable: OPT_HS_COMPARTMENT (2 bytes)
VAR_OPT_HS_X         EQU $C880+$177   ; User variable: OPT_HS_X (2 bytes)
VAR_OPT_HS_Y         EQU $C880+$179   ; User variable: OPT_HS_Y (2 bytes)
VAR_OPT_HS_W         EQU $C880+$17B   ; User variable: OPT_HS_W (2 bytes)
VAR_OPT_HS_H         EQU $C880+$17D   ; User variable: OPT_HS_H (2 bytes)
VAR_CONS_HS_ELISA    EQU $C880+$17F   ; User variable: CONS_HS_ELISA (2 bytes)
VAR_CONS_HS_X        EQU $C880+$181   ; User variable: CONS_HS_X (2 bytes)
VAR_CONS_HS_Y        EQU $C880+$183   ; User variable: CONS_HS_Y (2 bytes)
VAR_CONS_HS_W        EQU $C880+$185   ; User variable: CONS_HS_W (2 bytes)
VAR_CONS_HS_H        EQU $C880+$187   ; User variable: CONS_HS_H (2 bytes)
VAR_VAULT_HS_APPR    EQU $C880+$189   ; User variable: VAULT_HS_APPR (2 bytes)
VAR_VAULT_HS_DOOR    EQU $C880+$18B   ; User variable: VAULT_HS_DOOR (2 bytes)
VAR_VAULT_HS_X       EQU $C880+$18D   ; User variable: VAULT_HS_X (2 bytes)
VAR_VAULT_HS_Y       EQU $C880+$18F   ; User variable: VAULT_HS_Y (2 bytes)
VAR_VAULT_HS_W       EQU $C880+$191   ; User variable: VAULT_HS_W (2 bytes)
VAR_VAULT_HS_H       EQU $C880+$193   ; User variable: VAULT_HS_H (2 bytes)
VAR_SCREEN           EQU $C880+$195   ; User variable: SCREEN (2 bytes)
VAR_BLINK_TIMER      EQU $C880+$197   ; User variable: BLINK_TIMER (2 bytes)
VAR_BLINK_ON         EQU $C880+$199   ; User variable: BLINK_ON (2 bytes)
VAR_INTRO_PAGE       EQU $C880+$19B   ; User variable: INTRO_PAGE (2 bytes)
VAR_CURRENT_ROOM     EQU $C880+$19D   ; User variable: CURRENT_ROOM (2 bytes)
VAR_PLAYER_X         EQU $C880+$19F   ; User variable: PLAYER_X (2 bytes)
VAR_PLAYER_Y         EQU $C880+$1A1   ; User variable: PLAYER_Y (2 bytes)
VAR_SCROLL_X         EQU $C880+$1A3   ; User variable: SCROLL_X (2 bytes)
VAR_PLAYER_SPEED     EQU $C880+$1A5   ; User variable: PLAYER_SPEED (2 bytes)
VAR_CURRENT_VERB     EQU $C880+$1A7   ; User variable: CURRENT_VERB (2 bytes)
VAR_NEAR_HS          EQU $C880+$1A9   ; User variable: NEAR_HS (2 bytes)
VAR_MSG_ID           EQU $C880+$1AB   ; User variable: MSG_ID (2 bytes)
VAR_MSG_TIMER        EQU $C880+$1AD   ; User variable: MSG_TIMER (2 bytes)
VAR_ROOM_EXIT        EQU $C880+$1AF   ; User variable: ROOM_EXIT (2 bytes)
VAR_FLAGS_A          EQU $C880+$1B1   ; User variable: FLAGS_A (2 bytes)
VAR_FLAGS_B          EQU $C880+$1B3   ; User variable: FLAGS_B (2 bytes)
VAR_EXIT_ROOM_TARGET EQU $C880+$1B5   ; User variable: EXIT_ROOM_TARGET (2 bytes)
VAR_CURRENT_MUSIC    EQU $C880+$1B7   ; User variable: CURRENT_MUSIC (2 bytes)
VAR_BTN1_FIRED       EQU $C880+$1B9   ; User variable: BTN1_FIRED (2 bytes)
VAR_BTN2_FIRED       EQU $C880+$1BB   ; User variable: BTN2_FIRED (2 bytes)
VAR_BTN3_FIRED       EQU $C880+$1BD   ; User variable: BTN3_FIRED (2 bytes)
VAR_PREV_BTN1        EQU $C880+$1BF   ; User variable: PREV_BTN1 (2 bytes)
VAR_PREV_BTN2        EQU $C880+$1C1   ; User variable: PREV_BTN2 (2 bytes)
VAR_PREV_BTN3        EQU $C880+$1C3   ; User variable: PREV_BTN3 (2 bytes)
VAR_INV_COUNT        EQU $C880+$1C5   ; User variable: INV_COUNT (2 bytes)
VAR_INV_WEIGHT       EQU $C880+$1C7   ; User variable: INV_WEIGHT (2 bytes)
VAR_SHOW_INVENTORY   EQU $C880+$1C9   ; User variable: SHOW_INVENTORY (2 bytes)
VAR_ACTIVE_ITEM      EQU $C880+$1CB   ; User variable: ACTIVE_ITEM (2 bytes)
VAR_INV_CURSOR       EQU $C880+$1CD   ; User variable: INV_CURSOR (2 bytes)
VAR_HEARTBEAT_TEMPO  EQU $C880+$1CF   ; User variable: HEARTBEAT_TEMPO (2 bytes)
VAR_HEARTBEAT_TIMER  EQU $C880+$1D1   ; User variable: HEARTBEAT_TIMER (2 bytes)
VAR_TESTAMENT_Y      EQU $C880+$1D3   ; User variable: TESTAMENT_Y (2 bytes)
VAR_TESTAMENT_PAGE   EQU $C880+$1D5   ; User variable: TESTAMENT_PAGE (2 bytes)
VAR_ENDING_Y         EQU $C880+$1D7   ; User variable: ENDING_Y (2 bytes)
VAR_SKIPPEDFRAMES    EQU $C880+$1D9   ; User variable: SKIPPEDFRAMES (2 bytes)
VAR_RAW1             EQU $C880+$1DB   ; User variable: RAW1 (2 bytes)
VAR_RAW2             EQU $C880+$1DD   ; User variable: RAW2 (2 bytes)
VAR_RAW3             EQU $C880+$1DF   ; User variable: RAW3 (2 bytes)
VAR_ROOM_ID          EQU $C880+$1E3   ; User variable: room_id (2 bytes)
VAR_ROOM_ID          EQU $C880+$1E3   ; User variable: ROOM_ID (2 bytes)
VAR_JOY_X            EQU $C880+$1E5   ; User variable: JOY_X (2 bytes)
VAR_INV_ITEMS        EQU $C880+$1E7   ; User variable: INV_ITEMS (2 bytes)
VAR_DX               EQU $C880+$1E9   ; User variable: DX (2 bytes)
VAR_DY               EQU $C880+$1EB   ; User variable: DY (2 bytes)
VAR_HS               EQU $C880+$1EF   ; User variable: hs (2 bytes)
VAR_HS               EQU $C880+$1EF   ; User variable: HS (2 bytes)
VAR_NPC_STATE        EQU $C880+$1F1   ; User variable: NPC_STATE (2 bytes)
VAR_CARETAKER_SX     EQU $C880+$1F3   ; User variable: CARETAKER_SX (2 bytes)
VAR_HANS_SX          EQU $C880+$1F5   ; User variable: HANS_SX (2 bytes)
VAR_PLAT_SX          EQU $C880+$1F7   ; User variable: PLAT_SX (2 bytes)
VAR_COMP_SX          EQU $C880+$1F9   ; User variable: COMP_SX (2 bytes)
VAR_SCREEN_X         EQU $C880+$1FB   ; User variable: SCREEN_X (2 bytes)
VAR_ITEM_ID          EQU $C880+$1FF   ; User variable: item_id (2 bytes)
VAR_ITEM_ID          EQU $C880+$1FF   ; User variable: ITEM_ID (2 bytes)
VAR_NPC_STATE_DATA   EQU $C880+$201   ; Mutable array 'NPC_STATE' data (4 elements x 2 bytes) (8 bytes)
VAR_INV_ITEMS_DATA   EQU $C880+$209   ; Mutable array 'INV_ITEMS' data (8 elements x 2 bytes) (16 bytes)
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



; ================================================
    ; Runtime helpers (accessible from all banks)

;***************************************************************************
; ASSET LOOKUP TABLES (for banked asset access)
; Total: 20 vectors, 2 music, 5 sfx, 7 levels
;***************************************************************************

; Vector Asset Index Mapping:
;   0 = canvas (Bank #1)
;   1 = caretaker (Bank #1)
;   2 = conservatory (Bank #1)
;   3 = crypt_logo (Bank #1)
;   4 = crystal_apprentice (Bank #1)
;   5 = desk (Bank #1)
;   6 = door_locked (Bank #1)
;   7 = elisa_ghost (Bank #1)
;   8 = entrance_arc (Bank #1)
;   9 = floor (Bank #1)
;   10 = hans_automata (Bank #1)
;   11 = lamp (Bank #1)
;   12 = locked_door (Bank #1)
;   13 = optics_pedestal (Bank #1)
;   14 = painting (Bank #1)
;   15 = platform_down (Bank #1)
;   16 = platform_up (Bank #1)
;   17 = player (Bank #1)
;   18 = vault_corridor (Bank #1)
;   19 = wall_compartment (Bank #1)

VECTOR_BANK_TABLE:
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
;   1 = heartbeat (Bank #1)
;   2 = item_pickup (Bank #1)
;   3 = puzzle_fail (Bank #1)
;   4 = puzzle_success (Bank #1)

SFX_BANK_TABLE:
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID

SFX_ADDR_TABLE:
    FDB _DOOR_UNLOCK_SFX    ; door_unlock
    FDB _HEARTBEAT_SFX    ; heartbeat
    FDB _ITEM_PICKUP_SFX    ; item_pickup
    FDB _PUZZLE_FAIL_SFX    ; puzzle_fail
    FDB _PUZZLE_SUCCESS_SFX    ; puzzle_success

; Level Asset Index Mapping:
;   0 = anteroom (Bank #1)
;   1 = clockroom (Bank #1)
;   2 = conservatory (Bank #1)
;   3 = entrance (Bank #1)
;   4 = optics_lab (Bank #1)
;   5 = vault_corridor (Bank #1)
;   6 = weights_room (Bank #1)

LEVEL_BANK_TABLE:
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
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
    FDB _EXPLORATION_MUSIC    ; exploration
    FDB _INTRO_MUSIC    ; intro
    FDB _CRYPT_LOGO_VECTORS    ; crypt_logo
    FDB _DOOR_LOCKED_VECTORS    ; door_locked
    FDB _PAINTING_VECTORS    ; painting
    FDB _CONSERVATORY_LEVEL    ; conservatory
    FDB _VAULT_CORRIDOR_LEVEL    ; vault_corridor
    FDB _VAULT_CORRIDOR_VECTORS    ; vault_corridor
    FDB _CONSERVATORY_VECTORS    ; conservatory
    FDB _PUZZLE_SUCCESS_SFX    ; puzzle_success
    FDB _CRYSTAL_APPRENTICE_VECTORS    ; crystal_apprentice
    FDB _DOOR_UNLOCK_SFX    ; door_unlock
    FDB _DESK_VECTORS    ; desk
    FDB _HANS_AUTOMATA_VECTORS    ; hans_automata
    FDB _PLAYER_VECTORS    ; player
    FDB _ANTEROOM_LEVEL    ; anteroom
    FDB _CLOCKROOM_LEVEL    ; clockroom
    FDB _ENTRANCE_LEVEL    ; entrance
    FDB _FLOOR_VECTORS    ; floor
    FDB _LAMP_VECTORS    ; lamp
    FDB _PLATFORM_DOWN_VECTORS    ; platform_down
    FDB _CARETAKER_VECTORS    ; caretaker
    FDB _WEIGHTS_ROOM_LEVEL    ; weights_room
    FDB _HEARTBEAT_SFX    ; heartbeat
    FDB _ENTRANCE_ARC_VECTORS    ; entrance_arc
    FDB _LOCKED_DOOR_VECTORS    ; locked_door
    FDB _OPTICS_PEDESTAL_VECTORS    ; optics_pedestal
    FDB _WALL_COMPARTMENT_VECTORS    ; wall_compartment
    FDB _PLATFORM_UP_VECTORS    ; platform_up
    FDB _OPTICS_LAB_LEVEL    ; optics_lab
    FDB _CANVAS_VECTORS    ; canvas
    FDB _ITEM_PICKUP_SFX    ; item_pickup
    FDB _ELISA_GHOST_VECTORS    ; elisa_ghost
    FDB _PUZZLE_FAIL_SFX    ; puzzle_fail

;***************************************************************************
; DRAW_VECTOR_BANKED - Draw vector asset with automatic bank switching
; Input: X = asset index (0-based), DRAW_VEC_X/Y set for position
; Uses: A, B, X, Y
; Preserves: CURRENT_ROM_BANK (restored after drawing)
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

    ; Set up for drawing
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY
    JSR $F1AA            ; DP_to_D0

    ; Loop over all paths (header byte 0 = path_count, +1.. = FDB table)
    LDB ,X               ; B = path_count
    LBEQ DVB_DONE        ; No paths
    LEAY 1,X             ; Y = pointer to first FDB entry
DVB_PATH_LOOP:
    PSHS B               ; Save remaining path count
    LDX ,Y               ; X = path data address (FDB entry)
    JSR Draw_Sync_List_At_With_Mirrors
    LEAY 2,Y             ; Advance to next FDB entry
    PULS B               ; Restore count
    DECB
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
    JSR Print_Str_d
    LDA #$F8
    STA >$C82A      ; Restore Vec_Text_Height to normal (-8)
    LDA #$48
    STA >$C82B      ; Restore Vec_Text_Width to normal (72)
    JSR $F1AF      ; DP_to_C8 - restore DP before return
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
    
    ; === Copy GP objects from ROM to RAM buffer ===
    LDB >LEVEL_GP_COUNT
    BEQ LLR_SKIP_GP  ; Skip if no GP objects
    
    ; Clear GP buffer with $FF marker (empty sentinel)
    LDA #$FF
    LDU #LEVEL_GP_BUFFER
    LDB #8           ; Max 8 objects
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
;   +14-15: spawn_delay(FDB), +16-17: vector_ptr(FDB), +18: half_width, +19: reserved
; RAM object layout (15 bytes):
;   +0-1: world_x(FDB i16), +2: y(i8), +3: scale(low), +4: rotation,
;   +5: velocity_x, +6: velocity_y, +7: physics_flags, +8: collision_flags,
;   +9: collision_size, +10: spawn_delay(low), +11-12: vector_ptr, +13: half_width, +14: reserved
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
    BEQ SLR_ROM_OFFSETS
    
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
    LDB 2,X          ; y at RAM +2
    STB >DRAW_VEC_Y
    LDU 11,X         ; vector_ptr at RAM +11
    BRA SLR_DRAW_VECTOR
    
SLR_ROM_OFFSETS:
    ; === ROM object (stride=20) ===
    CLR >MIRROR_X    ; DP=$D0, must use extended addressing
    CLR >MIRROR_Y
    LDA 8,X          ; intensity at ROM +8
    STA >DRAW_VEC_INTENSITY
    LDD 3,X          ; y FDB at ROM +3; low byte into B
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
    
    ; Read path_count from vector header byte 0
    LDB ,X+          ; B = path_count, X now at pointer table
    
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
    LEAX 20,X        ; Next FG object (ROM stride 20)
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
; ============================================================================
UPDATE_MUSIC_PSG:
; CRITICAL: Set VIA to PSG mode BEFORE accessing PSG (don't assume state)
; DISABLED: Conflicts with SFX which uses Sound_Byte (HANDSHAKE mode)
; LDA #$00       ; VIA_cntl = $00 (PSG mode)
; STA >$D00C     ; VIA_cntl
LDA #$01
STA >PSG_MUSIC_ACTIVE   ; Mark music system active (for PSG logging)
LDA >PSG_IS_PLAYING     ; Check if playing (extended - var at 0xC8A0)
BEQ PSG_update_done     ; Not playing, exit

LDX >PSG_MUSIC_PTR      ; Load pointer (force extended - LDX has no DP mode)

; Read frame count byte (number of register writes)
LDB ,X+
BEQ PSG_music_ended     ; Count=0 means end (no loop)
CMPB #$FF               ; Check for loop command
BEQ PSG_music_loop      ; $FF means loop (never valid as count)

; Process frame - push counter to stack
PSHS B                  ; Save count on stack

; Write register/value pairs to PSG
PSG_write_loop:
LDA ,X+                 ; Load register number
LDB ,X+                 ; Load register value
PSHS X                  ; Save pointer (after reads)

; WRITE_PSG sequence
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
DECB                    ; Decrement
BEQ PSG_frame_done      ; Done with this frame
PSHS B                  ; Save counter back
BRA PSG_write_loop

PSG_frame_done:

; Frame complete - update pointer and done
STX >PSG_MUSIC_PTR      ; Update pointer (force extended)
BRA PSG_update_done

PSG_music_ended:
CLR >PSG_IS_PLAYING     ; Stop playback (extended - var at 0xC8A0)
; NOTE: Do NOT write PSG registers here - corrupts VIA for vector drawing
; Music will fade naturally as frame data stops updating
BRA PSG_update_done

PSG_music_loop:
; Loop command: $FF followed by 2-byte address (FDB)
; X points past $FF, read the target address
LDD ,X                  ; Load 2-byte loop target address
STD >PSG_MUSIC_PTR      ; Update pointer to loop start
; Exit - next frame will start from loop target
BRA PSG_update_done

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

;**** PRINT_TEXT String Data ****
PRINT_TEXT_STR_84327:
    FCC "USE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2188049:
    FCC "GIVE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2567303:
    FCC "TAKE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_100361836:
    FCC "intro"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3309214433:
    FCC "player"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_63819514689:
    FCC "EXAMINE"
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

PRINT_TEXT_STR_2376966947138:
    FCC "THE END."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2769766737209:
    FCC "anteroom"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2879828691638:
    FCC "entrance"
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

PRINT_TEXT_STR_91568903647484:
    FCC "heartbeat"
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

PRINT_TEXT_STR_66746456558499436:
    FCC "OIL      W1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_67802925852799259:
    FCC "PRISM    W1"
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

PRINT_TEXT_STR_3317733282004581041:
    FCC "PRESS B1 TO START"
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

PRINT_TEXT_STR_17954386693183881976:
    FCC "THE TICKING FOUND"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_18135904787860682873:
    FCC "YOU FOLLOW HER VOICE"
    FCB $80          ; Vectrex string terminator

;**** PRINT_MSG Dispatch ****
PRINT_MSG_DISPATCH:
    ; VAR_ARG0 = msg_id (set by PRINT_MSG caller)
    LDB VAR_ARG0+1      ; B = msg_id (low byte)
    BEQ PRINT_MSG_SKIP  ; id=0 → nothing to print
    DECB                ; 0-based index (id starts at 1)
    LSLB               ; B = index * 2
    LSLB               ; B = index * 4
    LDX #PRINT_MSG_TABLE
    ABX                ; X = &table[index * 4]
    LDB ,X+            ; B = x (signed byte)
    SEX                ; D = sign-extended x
    STD VAR_ARG0
    LDB ,X+            ; B = y (signed byte)
    SEX                ; D = sign-extended y
    STD VAR_ARG1
    LDX ,X             ; X = string pointer
    STX VAR_ARG2
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
TRAMP_DRAW_TESTAMENT:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$01  ; switch to bank #1
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR DRAW_TESTAMENT
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_DRAW_ENDING:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$01  ; switch to bank #1
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR DRAW_ENDING
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_ENTER_ROOM:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$01  ; switch to bank #1
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR ENTER_ROOM
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_PICKUP_ITEM:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$01  ; switch to bank #1
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR PICKUP_ITEM
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_DRAW_VERB_INDICATOR:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$01  ; switch to bank #1
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR DRAW_VERB_INDICATOR
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
TRAMP_INTERACT_ENTRANCE:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR INTERACT_ENTRANCE
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_INTERACT_WORKSHOP:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR INTERACT_WORKSHOP
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_INTERACT_ANTEROOM:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR INTERACT_ANTEROOM
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_INTERACT_WEIGHTS:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR INTERACT_WEIGHTS
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
TRAMP_INTERACT_VAULT:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR INTERACT_VAULT
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

