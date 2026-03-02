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
    FCC "PANG"
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
    ; Initialize audio system variables to prevent random noise on startup
    CLR >SFX_ACTIVE         ; Mark SFX as inactive (0=off)
    LDD #$0000
    STD >SFX_PTR            ; Clear SFX pointer
    STA >PSG_MUSIC_BANK     ; Bank 0 for music (prevents garbage bank switch in emulator)
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
DRAW_VEC_X           EQU $C880+$0C   ; Vector draw X offset (1 bytes)
DRAW_VEC_Y           EQU $C880+$0D   ; Vector draw Y offset (1 bytes)
DRAW_VEC_INTENSITY   EQU $C880+$0E   ; Vector intensity override (0=use vector data) (1 bytes)
MIRROR_PAD           EQU $C880+$0F   ; Safety padding to prevent MIRROR flag corruption (16 bytes)
MIRROR_X             EQU $C880+$1F   ; X mirror flag (0=normal, 1=flip) (1 bytes)
MIRROR_Y             EQU $C880+$20   ; Y mirror flag (0=normal, 1=flip) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$21   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$2B   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$2D   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$2F   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$30   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$31   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$33   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
LEVEL_PTR            EQU $C880+$35   ; Pointer to currently loaded level header (2 bytes)
LEVEL_WIDTH          EQU $C880+$37   ; Level width (legacy tile API) (1 bytes)
LEVEL_HEIGHT         EQU $C880+$38   ; Level height (legacy tile API) (1 bytes)
LEVEL_TILE_SIZE      EQU $C880+$39   ; Tile size (legacy tile API) (1 bytes)
LEVEL_Y_IDX          EQU $C880+$3A   ; SHOW_LEVEL row counter (legacy) (1 bytes)
LEVEL_X_IDX          EQU $C880+$3B   ; SHOW_LEVEL column counter (legacy) (1 bytes)
LEVEL_TEMP           EQU $C880+$3C   ; SHOW_LEVEL temporary byte (legacy) (1 bytes)
LEVEL_BG_COUNT       EQU $C880+$3D   ; BG object count (1 bytes)
LEVEL_GP_COUNT       EQU $C880+$3E   ; GP object count (1 bytes)
LEVEL_FG_COUNT       EQU $C880+$3F   ; FG object count (1 bytes)
CAMERA_X             EQU $C880+$40   ; Camera X scroll offset (16-bit signed world units) (2 bytes)
LEVEL_BG_ROM_PTR     EQU $C880+$42   ; BG layer ROM pointer (2 bytes)
LEVEL_GP_ROM_PTR     EQU $C880+$44   ; GP layer ROM pointer (2 bytes)
LEVEL_FG_ROM_PTR     EQU $C880+$46   ; FG layer ROM pointer (2 bytes)
LEVEL_GP_PTR         EQU $C880+$48   ; GP active pointer (RAM buffer after LOAD_LEVEL) (2 bytes)
SLR_CUR_X            EQU $C880+$4A   ; SHOW_LEVEL: tracked beam X for per-segment clipping (1 bytes)
LEVEL_GP_BUFFER      EQU $C880+$4B   ; GP objects RAM buffer (max 8 objects × 15 bytes) (120 bytes)
UGPC_OUTER_IDX       EQU $C880+$C3   ; GP-GP outer loop index (1 bytes)
UGPC_OUTER_MAX       EQU $C880+$C4   ; GP-GP outer loop max (count-1) (1 bytes)
UGPC_INNER_IDX       EQU $C880+$C5   ; GP-GP inner loop index (1 bytes)
UGPC_DX              EQU $C880+$C6   ; GP-GP |dx| (16-bit) (2 bytes)
UGPC_DIST            EQU $C880+$C8   ; GP-GP Manhattan distance (16-bit) (2 bytes)
UGFC_GP_IDX          EQU $C880+$CA   ; GP-FG outer loop GP index (1 bytes)
UGFC_FG_COUNT        EQU $C880+$CB   ; GP-FG inner loop FG count (1 bytes)
UGFC_DX              EQU $C880+$CC   ; GP-FG |dx| (1 bytes)
UGFC_DY              EQU $C880+$CD   ; GP-FG |dy| (1 bytes)
TEXT_SCALE_H         EQU $C880+$CE   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$CF   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_STATE_TITLE      EQU $C880+$D0   ; User variable: STATE_TITLE (2 bytes)
VAR_STATE_MAP        EQU $C880+$D2   ; User variable: STATE_MAP (2 bytes)
VAR_STATE_GAME       EQU $C880+$D4   ; User variable: STATE_GAME (2 bytes)
VAR_SCREEN           EQU $C880+$D6   ; User variable: SCREEN (2 bytes)
VAR_TITLE_INTENSITY  EQU $C880+$D8   ; User variable: TITLE_INTENSITY (2 bytes)
VAR_TITLE_STATE      EQU $C880+$DA   ; User variable: TITLE_STATE (2 bytes)
VAR_CURRENT_MUSIC    EQU $C880+$DC   ; User variable: CURRENT_MUSIC (2 bytes)
VAR_LOCATION_X_COORDS EQU $C880+$DE   ; User variable: LOCATION_X_COORDS (2 bytes)
VAR_LOCATION_Y_COORDS EQU $C880+$E0   ; User variable: LOCATION_Y_COORDS (2 bytes)
VAR_LOCATION_NAMES   EQU $C880+$E2   ; User variable: LOCATION_NAMES (2 bytes)
VAR_LEVEL_BACKGROUNDS EQU $C880+$E4   ; User variable: LEVEL_BACKGROUNDS (2 bytes)
VAR_LEVEL_ENEMY_COUNT EQU $C880+$E6   ; User variable: LEVEL_ENEMY_COUNT (2 bytes)
VAR_LEVEL_ENEMY_SPEED EQU $C880+$E8   ; User variable: LEVEL_ENEMY_SPEED (2 bytes)
VAR_PREV_BTN1        EQU $C880+$EA   ; User variable: PREV_BTN1 (2 bytes)
VAR_PREV_BTN2        EQU $C880+$EC   ; User variable: PREV_BTN2 (2 bytes)
VAR_PREV_BTN3        EQU $C880+$EE   ; User variable: PREV_BTN3 (2 bytes)
VAR_PREV_BTN4        EQU $C880+$F0   ; User variable: PREV_BTN4 (2 bytes)
VAR_NUM_LOCATIONS    EQU $C880+$F2   ; User variable: NUM_LOCATIONS (2 bytes)
VAR_CURRENT_LOCATION EQU $C880+$F4   ; User variable: CURRENT_LOCATION (2 bytes)
VAR_LOCATION_GLOW_INTENSITY EQU $C880+$F6   ; User variable: LOCATION_GLOW_INTENSITY (2 bytes)
VAR_LOCATION_GLOW_DIRECTION EQU $C880+$F8   ; User variable: LOCATION_GLOW_DIRECTION (2 bytes)
VAR_JOY_X            EQU $C880+$FA   ; User variable: JOY_X (2 bytes)
VAR_JOY_Y            EQU $C880+$FC   ; User variable: JOY_Y (2 bytes)
VAR_PREV_JOY_X       EQU $C880+$FE   ; User variable: PREV_JOY_X (2 bytes)
VAR_PREV_JOY_Y       EQU $C880+$100   ; User variable: PREV_JOY_Y (2 bytes)
VAR_COUNTDOWN_TIMER  EQU $C880+$102   ; User variable: COUNTDOWN_TIMER (2 bytes)
VAR_COUNTDOWN_ACTIVE EQU $C880+$104   ; User variable: COUNTDOWN_ACTIVE (2 bytes)
VAR_JOYSTICK_POLL_COUNTER EQU $C880+$106   ; User variable: JOYSTICK_POLL_COUNTER (2 bytes)
VAR_HOOK_ACTIVE      EQU $C880+$108   ; User variable: HOOK_ACTIVE (2 bytes)
VAR_HOOK_X           EQU $C880+$10A   ; User variable: HOOK_X (2 bytes)
VAR_HOOK_Y           EQU $C880+$10C   ; User variable: HOOK_Y (2 bytes)
VAR_HOOK_MAX_Y       EQU $C880+$10E   ; User variable: HOOK_MAX_Y (2 bytes)
VAR_HOOK_GUN_X       EQU $C880+$110   ; User variable: HOOK_GUN_X (2 bytes)
VAR_HOOK_GUN_Y       EQU $C880+$112   ; User variable: HOOK_GUN_Y (2 bytes)
VAR_HOOK_INIT_Y      EQU $C880+$114   ; User variable: HOOK_INIT_Y (2 bytes)
VAR_PLAYER_X         EQU $C880+$116   ; User variable: PLAYER_X (2 bytes)
VAR_PLAYER_Y         EQU $C880+$118   ; User variable: PLAYER_Y (2 bytes)
VAR_MOVE_SPEED       EQU $C880+$11A   ; User variable: MOVE_SPEED (2 bytes)
VAR_ABS_JOY          EQU $C880+$11C   ; User variable: ABS_JOY (2 bytes)
VAR_PLAYER_ANIM_FRAME EQU $C880+$11E   ; User variable: PLAYER_ANIM_FRAME (2 bytes)
VAR_PLAYER_ANIM_COUNTER EQU $C880+$120   ; User variable: PLAYER_ANIM_COUNTER (2 bytes)
VAR_PLAYER_ANIM_SPEED EQU $C880+$122   ; User variable: PLAYER_ANIM_SPEED (2 bytes)
VAR_PLAYER_FACING    EQU $C880+$124   ; User variable: PLAYER_FACING (2 bytes)
VAR_MAX_ENEMIES      EQU $C880+$126   ; User variable: MAX_ENEMIES (2 bytes)
VAR_GRAVITY          EQU $C880+$128   ; User variable: GRAVITY (2 bytes)
VAR_BOUNCE_DAMPING   EQU $C880+$12A   ; User variable: BOUNCE_DAMPING (2 bytes)
VAR_MIN_BOUNCE_VY    EQU $C880+$12C   ; User variable: MIN_BOUNCE_VY (2 bytes)
VAR_GROUND_Y         EQU $C880+$12E   ; User variable: GROUND_Y (2 bytes)
VAR_JOYSTICK1_STATE  EQU $C880+$130   ; User variable: JOYSTICK1_STATE (2 bytes)
VAR_LOC_X            EQU $C880+$132   ; User variable: LOC_X (2 bytes)
VAR_LOC_Y            EQU $C880+$134   ; User variable: LOC_Y (2 bytes)
VAR_ANIM_THRESHOLD   EQU $C880+$136   ; User variable: ANIM_THRESHOLD (2 bytes)
VAR_MIRROR_MODE      EQU $C880+$138   ; User variable: MIRROR_MODE (2 bytes)
VAR_COUNT            EQU $C880+$13A   ; User variable: COUNT (2 bytes)
VAR_SPEED            EQU $C880+$13C   ; User variable: SPEED (2 bytes)
VAR_I                EQU $C880+$13E   ; User variable: I (2 bytes)
VAR_ENEMY_ACTIVE     EQU $C880+$140   ; User variable: ENEMY_ACTIVE (2 bytes)
VAR_ENEMY_SIZE       EQU $C880+$142   ; User variable: ENEMY_SIZE (2 bytes)
VAR_ENEMY_X          EQU $C880+$144   ; User variable: ENEMY_X (2 bytes)
VAR_ENEMY_Y          EQU $C880+$146   ; User variable: ENEMY_Y (2 bytes)
VAR_ENEMY_VX         EQU $C880+$148   ; User variable: ENEMY_VX (2 bytes)
VAR_ENEMY_VY         EQU $C880+$14A   ; User variable: ENEMY_VY (2 bytes)
VAR_START_X          EQU $C880+$154   ; User variable: start_x (2 bytes)
VAR_START_Y          EQU $C880+$156   ; User variable: start_y (2 bytes)
VAR_END_X            EQU $C880+$158   ; User variable: end_x (2 bytes)
VAR_END_Y            EQU $C880+$15A   ; User variable: end_y (2 bytes)
VAR_START_X          EQU $C880+$154   ; User variable: START_X (2 bytes)
VAR_START_Y          EQU $C880+$156   ; User variable: START_Y (2 bytes)
VAR_END_X            EQU $C880+$158   ; User variable: END_X (2 bytes)
VAR_END_Y            EQU $C880+$15A   ; User variable: END_Y (2 bytes)
VAR_JOYSTICK1_STATE_DATA EQU $C880+$15C   ; Mutable array 'JOYSTICK1_STATE' data (6 elements x 2 bytes) (12 bytes)
VAR_ENEMY_ACTIVE_DATA EQU $C880+$168   ; Mutable array 'ENEMY_ACTIVE' data (8 elements x 2 bytes) (16 bytes)
VAR_ENEMY_X_DATA     EQU $C880+$178   ; Mutable array 'ENEMY_X' data (8 elements x 2 bytes) (16 bytes)
VAR_ENEMY_Y_DATA     EQU $C880+$188   ; Mutable array 'ENEMY_Y' data (8 elements x 2 bytes) (16 bytes)
VAR_ENEMY_VX_DATA    EQU $C880+$198   ; Mutable array 'ENEMY_VX' data (8 elements x 2 bytes) (16 bytes)
VAR_ENEMY_VY_DATA    EQU $C880+$1A8   ; Mutable array 'ENEMY_VY' data (8 elements x 2 bytes) (16 bytes)
VAR_ENEMY_SIZE_DATA  EQU $C880+$1B8   ; Mutable array 'ENEMY_SIZE' data (8 elements x 2 bytes) (16 bytes)
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

; Array literal for variable 'JOYSTICK1_STATE' (6 elements, 2 bytes each)
ARRAY_JOYSTICK1_STATE_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5

; Array literal for variable 'ENEMY_ACTIVE' (8 elements, 2 bytes each)
ARRAY_ENEMY_ACTIVE_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

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

; Array literal for variable 'ENEMY_SIZE' (8 elements, 2 bytes each)
ARRAY_ENEMY_SIZE_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7


;***************************************************************************
; MAIN PROGRAM
;***************************************************************************

MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    LDA #$F8
    STA TEXT_SCALE_H      ; Default height = -8 (normal size)
    LDA #$48
    STA TEXT_SCALE_W      ; Default width = 72 (normal size)
    LDD #0  ; const STATE_TITLE
    STD RESULT
    STD VAR_SCREEN
    LDD #30
    STD RESULT
    STD VAR_TITLE_INTENSITY
    LDD #0
    STD RESULT
    STD VAR_TITLE_STATE
    LDD #-1
    STD RESULT
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
    STD RESULT
    STD VAR_PREV_BTN1
    LDD #0
    STD RESULT
    STD VAR_PREV_BTN2
    LDD #0
    STD RESULT
    STD VAR_PREV_BTN3
    LDD #0
    STD RESULT
    STD VAR_PREV_BTN4
    LDD #0
    STD RESULT
    STD VAR_CURRENT_LOCATION
    LDD #60
    STD RESULT
    STD VAR_LOCATION_GLOW_INTENSITY
    LDD #0
    STD RESULT
    STD VAR_LOCATION_GLOW_DIRECTION
    LDD #0
    STD RESULT
    STD VAR_JOY_X
    LDD #0
    STD RESULT
    STD VAR_JOY_Y
    LDD #0
    STD RESULT
    STD VAR_PREV_JOY_X
    LDD #0
    STD RESULT
    STD VAR_PREV_JOY_Y
    LDD #0
    STD RESULT
    STD VAR_COUNTDOWN_TIMER
    LDD #0
    STD RESULT
    STD VAR_COUNTDOWN_ACTIVE
    LDD #0
    STD RESULT
    STD VAR_JOYSTICK_POLL_COUNTER
    LDD #0
    STD RESULT
    STD VAR_HOOK_ACTIVE
    LDD #0
    STD RESULT
    STD VAR_HOOK_X
    LDD #-70
    STD RESULT
    STD VAR_HOOK_Y
    LDD #0
    STD RESULT
    STD VAR_HOOK_GUN_X
    LDD #0
    STD RESULT
    STD VAR_HOOK_GUN_Y
    LDD #0
    STD RESULT
    STD VAR_HOOK_INIT_Y
    LDD #0
    STD RESULT
    STD VAR_PLAYER_X
    LDD #0
    STD RESULT
    STD VAR_MOVE_SPEED
    LDD #0
    STD RESULT
    STD VAR_ABS_JOY
    LDD #1
    STD RESULT
    STD VAR_PLAYER_ANIM_FRAME
    LDD #0
    STD RESULT
    STD VAR_PLAYER_ANIM_COUNTER
    LDD #1
    STD RESULT
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

    ; Call main() for initialization
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_LOCATION
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_PREV_JOY_X
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_PREV_JOY_Y
    LDD #80
    STD RESULT
    LDD RESULT
    STD VAR_LOCATION_GLOW_INTENSITY
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_LOCATION_GLOW_DIRECTION
    LDD #0  ; const STATE_TITLE
    STD RESULT
    LDD RESULT
    STD VAR_SCREEN
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_COUNTDOWN_TIMER
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_COUNTDOWN_ACTIVE
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_ACTIVE
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_X
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_Y
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_JOYSTICK_POLL_COUNTER
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_PREV_BTN1
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_PREV_BTN2
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_PREV_BTN3
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_PREV_BTN4

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access
    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)
    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access
    JSR READ_JOYSTICK1_STATE
    LDD #0  ; const STATE_TITLE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SCREEN
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_1
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_MUSIC
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_3
    ; PLAY_MUSIC("pang_theme") - play music asset (index=1)
    LDX #_PANG_THEME_MUSIC  ; Load music data pointer
    JSR PLAY_MUSIC_RUNTIME
    LDD #0
    STD RESULT
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    JSR DRAW_TITLE_SCREEN
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #2
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_3_TRUE
    LDD #0
    LBRA .CMP_3_END
.CMP_3_TRUE:
    LDD #1
.CMP_3_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_2_FALSE
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_BTN1
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_4_TRUE
    LDD #0
    LBRA .CMP_4_END
.CMP_4_TRUE:
    LDD #1
.CMP_4_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_2_FALSE
    LDD #1
    LBRA .LOGIC_2_END
.LOGIC_2_FALSE:
    LDD #0
.LOGIC_2_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_5
    LDD #1  ; const STATE_MAP
    STD RESULT
    LDD RESULT
    STD VAR_SCREEN
    LDD #-1
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_4
IF_NEXT_5:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #3
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_6_TRUE
    LDD #0
    LBRA .CMP_6_END
.CMP_6_TRUE:
    LDD #1
.CMP_6_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_5_FALSE
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_BTN2
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_7_TRUE
    LDD #0
    LBRA .CMP_7_END
.CMP_7_TRUE:
    LDD #1
.CMP_7_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_5_FALSE
    LDD #1
    LBRA .LOGIC_5_END
.LOGIC_5_FALSE:
    LDD #0
.LOGIC_5_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_6
    LDD #1  ; const STATE_MAP
    STD RESULT
    LDD RESULT
    STD VAR_SCREEN
    LDD #-1
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_4
IF_NEXT_6:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #4
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_9_TRUE
    LDD #0
    LBRA .CMP_9_END
.CMP_9_TRUE:
    LDD #1
.CMP_9_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_8_FALSE
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_BTN3
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_10_TRUE
    LDD #0
    LBRA .CMP_10_END
.CMP_10_TRUE:
    LDD #1
.CMP_10_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_8_FALSE
    LDD #1
    LBRA .LOGIC_8_END
.LOGIC_8_FALSE:
    LDD #0
.LOGIC_8_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_7
    LDD #1  ; const STATE_MAP
    STD RESULT
    LDD RESULT
    STD VAR_SCREEN
    LDD #-1
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_4
IF_NEXT_7:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #5
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_12_TRUE
    LDD #0
    LBRA .CMP_12_END
.CMP_12_TRUE:
    LDD #1
.CMP_12_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_11_FALSE
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_BTN4
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_13_TRUE
    LDD #0
    LBRA .CMP_13_END
.CMP_13_TRUE:
    LDD #1
.CMP_13_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_11_FALSE
    LDD #1
    LBRA .LOGIC_11_END
.LOGIC_11_FALSE:
    LDD #0
.LOGIC_11_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_END_4
    LDD #1  ; const STATE_MAP
    STD RESULT
    LDD RESULT
    STD VAR_SCREEN
    LDD #-1
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_4
IF_END_4:
    LBRA IF_END_0
IF_NEXT_1:
    LDD #1  ; const STATE_MAP
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SCREEN
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_14_TRUE
    LDD #0
    LBRA .CMP_14_END
.CMP_14_TRUE:
    LDD #1
.CMP_14_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_8
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_MUSIC
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBNE .CMP_15_TRUE
    LDD #0
    LBRA .CMP_15_END
.CMP_15_TRUE:
    LDD #1
.CMP_15_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_10
    ; PLAY_MUSIC("map_theme") - play music asset (index=0)
    LDX #_MAP_THEME_MUSIC  ; Load music data pointer
    JSR PLAY_MUSIC_RUNTIME
    LDD #0
    STD RESULT
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_9
IF_NEXT_10:
IF_END_9:
    LDD >VAR_JOYSTICK_POLL_COUNTER
    STD TMPVAL          ; Save left operand
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + TMPVAL
    STD VAR_JOYSTICK_POLL_COUNTER
    LDD #15
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOYSTICK_POLL_COUNTER
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_16_TRUE
    LDD #0
    LBRA .CMP_16_END
.CMP_16_TRUE:
    LDD #1
.CMP_16_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_12
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_JOYSTICK_POLL_COUNTER
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #0
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_JOY_X
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #1
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_JOY_Y
    LBRA IF_END_11
IF_NEXT_12:
IF_END_11:
    LDD #40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_18_TRUE
    LDD #0
    LBRA .CMP_18_END
.CMP_18_TRUE:
    LDD #1
.CMP_18_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_17_FALSE
    LDD #40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLE .CMP_19_TRUE
    LDD #0
    LBRA .CMP_19_END
.CMP_19_TRUE:
    LDD #1
.CMP_19_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_17_FALSE
    LDD #1
    LBRA .LOGIC_17_END
.LOGIC_17_FALSE:
    LDD #0
.LOGIC_17_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_14
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_LOCATION
    LDD #17  ; const NUM_LOCATIONS
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_20_TRUE
    LDD #0
    LBRA .CMP_20_END
.CMP_20_TRUE:
    LDD #1
.CMP_20_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_16
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_LOCATION
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'fuji_level1_v2'
    LDX #_FUJI_LEVEL1_V2_LEVEL          ; Pointer to level data in ROM
    JSR LOAD_LEVEL_RUNTIME
    LBRA IF_END_15
IF_NEXT_16:
IF_END_15:
    LBRA IF_END_13
IF_NEXT_14:
    LDD #-40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_22_TRUE
    LDD #0
    LBRA .CMP_22_END
.CMP_22_TRUE:
    LDD #1
.CMP_22_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_21_FALSE
    LDD #-40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_23_TRUE
    LDD #0
    LBRA .CMP_23_END
.CMP_23_TRUE:
    LDD #1
.CMP_23_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_21_FALSE
    LDD #1
    LBRA .LOGIC_21_END
.LOGIC_21_FALSE:
    LDD #0
.LOGIC_21_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_17
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_LOCATION
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_24_TRUE
    LDD #0
    LBRA .CMP_24_END
.CMP_24_TRUE:
    LDD #1
.CMP_24_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_19
    LDD #17  ; const NUM_LOCATIONS
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_LOCATION
    LBRA IF_END_18
IF_NEXT_19:
IF_END_18:
    LBRA IF_END_13
IF_NEXT_17:
    LDD #40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_Y
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_26_TRUE
    LDD #0
    LBRA .CMP_26_END
.CMP_26_TRUE:
    LDD #1
.CMP_26_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_25_FALSE
    LDD #40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_JOY_Y
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLE .CMP_27_TRUE
    LDD #0
    LBRA .CMP_27_END
.CMP_27_TRUE:
    LDD #1
.CMP_27_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_25_FALSE
    LDD #1
    LBRA .LOGIC_25_END
.LOGIC_25_FALSE:
    LDD #0
.LOGIC_25_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_20
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_LOCATION
    LDD #17  ; const NUM_LOCATIONS
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_28_TRUE
    LDD #0
    LBRA .CMP_28_END
.CMP_28_TRUE:
    LDD #1
.CMP_28_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_22
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_LOCATION
    LBRA IF_END_21
IF_NEXT_22:
IF_END_21:
    LBRA IF_END_13
IF_NEXT_20:
    LDD #-40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_Y
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_30_TRUE
    LDD #0
    LBRA .CMP_30_END
.CMP_30_TRUE:
    LDD #1
.CMP_30_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_29_FALSE
    LDD #-40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_JOY_Y
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_31_TRUE
    LDD #0
    LBRA .CMP_31_END
.CMP_31_TRUE:
    LDD #1
.CMP_31_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_29_FALSE
    LDD #1
    LBRA .LOGIC_29_END
.LOGIC_29_FALSE:
    LDD #0
.LOGIC_29_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_END_13
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_LOCATION
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_32_TRUE
    LDD #0
    LBRA .CMP_32_END
.CMP_32_TRUE:
    LDD #1
.CMP_32_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_24
    LDD #17  ; const NUM_LOCATIONS
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_LOCATION
    LBRA IF_END_23
IF_NEXT_24:
IF_END_23:
    LBRA IF_END_13
IF_END_13:
    LDD >VAR_JOY_X
    STD RESULT
    LDD RESULT
    STD VAR_PREV_JOY_X
    LDD >VAR_JOY_Y
    STD RESULT
    LDD RESULT
    STD VAR_PREV_JOY_Y
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #2
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_34_TRUE
    LDD #0
    LBRA .CMP_34_END
.CMP_34_TRUE:
    LDD #1
.CMP_34_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_33_FALSE
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_BTN1
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_35_TRUE
    LDD #0
    LBRA .CMP_35_END
.CMP_35_TRUE:
    LDD #1
.CMP_35_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_33_FALSE
    LDD #1
    LBRA .LOGIC_33_END
.LOGIC_33_FALSE:
    LDD #0
.LOGIC_33_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_26
    LDD #2  ; const STATE_GAME
    STD RESULT
    LDD RESULT
    STD VAR_SCREEN
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_COUNTDOWN_ACTIVE
    LDD #180
    STD RESULT
    LDD RESULT
    STD VAR_COUNTDOWN_TIMER
    LBRA IF_END_25
IF_NEXT_26:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #3
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_37_TRUE
    LDD #0
    LBRA .CMP_37_END
.CMP_37_TRUE:
    LDD #1
.CMP_37_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_36_FALSE
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_BTN2
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_38_TRUE
    LDD #0
    LBRA .CMP_38_END
.CMP_38_TRUE:
    LDD #1
.CMP_38_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_36_FALSE
    LDD #1
    LBRA .LOGIC_36_END
.LOGIC_36_FALSE:
    LDD #0
.LOGIC_36_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_27
    LDD #2  ; const STATE_GAME
    STD RESULT
    LDD RESULT
    STD VAR_SCREEN
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_COUNTDOWN_ACTIVE
    LDD #180
    STD RESULT
    LDD RESULT
    STD VAR_COUNTDOWN_TIMER
    LBRA IF_END_25
IF_NEXT_27:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #4
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_40_TRUE
    LDD #0
    LBRA .CMP_40_END
.CMP_40_TRUE:
    LDD #1
.CMP_40_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_39_FALSE
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_BTN3
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_41_TRUE
    LDD #0
    LBRA .CMP_41_END
.CMP_41_TRUE:
    LDD #1
.CMP_41_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_39_FALSE
    LDD #1
    LBRA .LOGIC_39_END
.LOGIC_39_FALSE:
    LDD #0
.LOGIC_39_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_28
    LDD #2  ; const STATE_GAME
    STD RESULT
    LDD RESULT
    STD VAR_SCREEN
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_COUNTDOWN_ACTIVE
    LDD #180
    STD RESULT
    LDD RESULT
    STD VAR_COUNTDOWN_TIMER
    LBRA IF_END_25
IF_NEXT_28:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #5
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_43_TRUE
    LDD #0
    LBRA .CMP_43_END
.CMP_43_TRUE:
    LDD #1
.CMP_43_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_42_FALSE
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_BTN4
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_44_TRUE
    LDD #0
    LBRA .CMP_44_END
.CMP_44_TRUE:
    LDD #1
.CMP_44_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_42_FALSE
    LDD #1
    LBRA .LOGIC_42_END
.LOGIC_42_FALSE:
    LDD #0
.LOGIC_42_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_END_25
    LDD #2  ; const STATE_GAME
    STD RESULT
    LDD RESULT
    STD VAR_SCREEN
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_COUNTDOWN_ACTIVE
    LDD #180
    STD RESULT
    LDD RESULT
    STD VAR_COUNTDOWN_TIMER
    LBRA IF_END_25
IF_END_25:
    JSR DRAW_MAP_SCREEN
    LBRA IF_END_0
IF_NEXT_8:
    LDD #2  ; const STATE_GAME
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SCREEN
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_45_TRUE
    LDD #0
    LBRA .CMP_45_END
.CMP_45_TRUE:
    LDD #1
.CMP_45_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_END_0
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_COUNTDOWN_ACTIVE
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_46_TRUE
    LDD #0
    LBRA .CMP_46_END
.CMP_46_TRUE:
    LDD #1
.CMP_46_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_30
    JSR DRAW_LEVEL_BACKGROUND
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-50
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_62529178322969      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-85
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-20
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #ARRAY_LOCATION_NAMES_DATA  ; Array base
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD >VAR_COUNTDOWN_TIMER
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDD RESULT
    STD VAR_COUNTDOWN_TIMER
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_COUNTDOWN_TIMER
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLE .CMP_47_TRUE
    LDD #0
    LBRA .CMP_47_END
.CMP_47_TRUE:
    LDD #1
.CMP_47_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_32
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_COUNTDOWN_ACTIVE
    JSR SPAWN_ENEMIES
    LBRA IF_END_31
IF_NEXT_32:
IF_END_31:
    LBRA IF_END_29
IF_NEXT_30:
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_HOOK_ACTIVE
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_48_TRUE
    LDD #0
    LBRA .CMP_48_END
.CMP_48_TRUE:
    LDD #1
.CMP_48_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_34
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #2
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_52_TRUE
    LDD #0
    LBRA .CMP_52_END
.CMP_52_TRUE:
    LDD #1
.CMP_52_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_51_TRUE
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #3
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_53_TRUE
    LDD #0
    LBRA .CMP_53_END
.CMP_53_TRUE:
    LDD #1
.CMP_53_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_51_TRUE
    LDD #0
    LBRA .LOGIC_51_END
.LOGIC_51_TRUE:
    LDD #1
.LOGIC_51_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_50_TRUE
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #4
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_54_TRUE
    LDD #0
    LBRA .CMP_54_END
.CMP_54_TRUE:
    LDD #1
.CMP_54_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_50_TRUE
    LDD #0
    LBRA .LOGIC_50_END
.LOGIC_50_TRUE:
    LDD #1
.LOGIC_50_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_49_TRUE
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #5
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_55_TRUE
    LDD #0
    LBRA .CMP_55_END
.CMP_55_TRUE:
    LDD #1
.CMP_55_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_49_TRUE
    LDD #0
    LBRA .LOGIC_49_END
.LOGIC_49_TRUE:
    LDD #1
.LOGIC_49_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_36
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_ACTIVE
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_Y
    LDD >VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_GUN_X
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_FACING
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_56_TRUE
    LDD #0
    LBRA .CMP_56_END
.CMP_56_TRUE:
    LDD #1
.CMP_56_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_38
    LDD >VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #11
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_GUN_X
    LBRA IF_END_37
IF_NEXT_38:
    LDD >VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #11
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_GUN_X
IF_END_37:
    LDD #-70  ; const PLAYER_Y
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #3
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_GUN_Y
    LDD >VAR_HOOK_GUN_Y
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_INIT_Y
    LDD >VAR_HOOK_GUN_X
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_X
    LBRA IF_END_35
IF_NEXT_36:
IF_END_35:
    LBRA IF_END_33
IF_NEXT_34:
IF_END_33:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_HOOK_ACTIVE
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_57_TRUE
    LDD #0
    LBRA .CMP_57_END
.CMP_57_TRUE:
    LDD #1
.CMP_57_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_40
    LDD >VAR_HOOK_Y
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #3
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_Y
    LDD #127  ; const HOOK_MAX_Y
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_HOOK_Y
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_58_TRUE
    LDD #0
    LBRA .CMP_58_END
.CMP_58_TRUE:
    LDD #1
.CMP_58_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_42
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_ACTIVE
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_Y
    LBRA IF_END_41
IF_NEXT_42:
IF_END_41:
    LBRA IF_END_39
IF_NEXT_40:
IF_END_39:
    JSR DRAW_GAME_LEVEL
IF_END_29:
    LBRA IF_END_0
IF_END_0:
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #2
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_PREV_BTN1
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #3
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_PREV_BTN2
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #4
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_PREV_BTN3
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #5
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_PREV_BTN4
    ; META MUSIC_TIMER: catch up if game frame was slow
    LDA >$D00D              ; VIA_int_flags (extended addr, DP=$C8)
    BITA #$20               ; Bit 5 = T2 elapsed (>1 frame of user code)
    BEQ MUSIC_CATCHUP_SKIP  ; On time — skip extra tick
    JSR AUDIO_UPDATE        ; Catch-up tick: game was slow
MUSIC_CATCHUP_SKIP:
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX
    RTS

; Function: DRAW_MAP_SCREEN
DRAW_MAP_SCREEN:
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: map (15 paths) with mirror + intensity
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD #20
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD #0
    STD RESULT
    LDB RESULT+1  ; Mirror mode (0=normal, 1=X, 2=Y, 3=both)
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
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
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
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_LOCATION_GLOW_DIRECTION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_59_TRUE
    LDD #0
    LBRA .CMP_59_END
.CMP_59_TRUE:
    LDD #1
.CMP_59_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_44
    LDD >VAR_LOCATION_GLOW_INTENSITY
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #3
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_LOCATION_GLOW_INTENSITY
    LDD #127
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_LOCATION_GLOW_INTENSITY
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_60_TRUE
    LDD #0
    LBRA .CMP_60_END
.CMP_60_TRUE:
    LDD #1
.CMP_60_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_46
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_LOCATION_GLOW_DIRECTION
    LBRA IF_END_45
IF_NEXT_46:
IF_END_45:
    LBRA IF_END_43
IF_NEXT_44:
    LDD >VAR_LOCATION_GLOW_INTENSITY
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDD RESULT
    STD VAR_LOCATION_GLOW_INTENSITY
    LDD #80
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_LOCATION_GLOW_INTENSITY
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLE .CMP_61_TRUE
    LDD #0
    LBRA .CMP_61_END
.CMP_61_TRUE:
    LDD #1
.CMP_61_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_48
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_LOCATION_GLOW_DIRECTION
    LBRA IF_END_47
IF_NEXT_48:
IF_END_47:
IF_END_43:
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-80
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #ARRAY_LOCATION_NAMES_DATA  ; Array base
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDX #ARRAY_LOCATION_X_COORDS_DATA  ; Array base
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_LOC_X
    LDX #ARRAY_LOCATION_Y_COORDS_DATA  ; Array base
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_LOC_Y
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: location_marker (1 paths) with mirror + intensity
    LDD >VAR_LOC_Y
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD >VAR_LOC_X
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD #0
    STD RESULT
    LDB RESULT+1  ; Mirror mode (0=normal, 1=X, 2=Y, 3=both)
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
    LDD >VAR_LOCATION_GLOW_INTENSITY
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
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
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: logo (index=17, 7 paths)
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #70
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
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
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD >VAR_TITLE_INTENSITY
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-90
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_9120385685437879118      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-50
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-20
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2382167728733      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_TITLE_STATE
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_62_TRUE
    LDD #0
    LBRA .CMP_62_END
.CMP_62_TRUE:
    LDD #1
.CMP_62_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_50
    LDD >VAR_TITLE_INTENSITY
    STD TMPVAL          ; Save left operand
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + TMPVAL
    STD VAR_TITLE_INTENSITY
    LBRA IF_END_49
IF_NEXT_50:
IF_END_49:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_TITLE_STATE
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_63_TRUE
    LDD #0
    LBRA .CMP_63_END
.CMP_63_TRUE:
    LDD #1
.CMP_63_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_52
    LDD >VAR_TITLE_INTENSITY
    STD TMPVAL          ; Save left operand
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPPTR          ; Save right operand
    LDD TMPVAL          ; Get left operand
    SUBD TMPPTR         ; D = left - right
    STD VAR_TITLE_INTENSITY
    LBRA IF_END_51
IF_NEXT_52:
IF_END_51:
    LDD #80
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_TITLE_INTENSITY
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_64_TRUE
    LDD #0
    LBRA .CMP_64_END
.CMP_64_TRUE:
    LDD #1
.CMP_64_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_54
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_TITLE_STATE
    LBRA IF_END_53
IF_NEXT_54:
IF_END_53:
    LDD #30
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_TITLE_INTENSITY
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_65_TRUE
    LDD #0
    LBRA .CMP_65_END
.CMP_65_TRUE:
    LDD #1
.CMP_65_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_56
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_TITLE_STATE
    LBRA IF_END_55
IF_NEXT_56:
IF_END_55:
    RTS

; Function: DRAW_LEVEL_BACKGROUND
DRAW_LEVEL_BACKGROUND:
    ; SET_INTENSITY: Set drawing intensity
    LDD #60
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_66_TRUE
    LDD #0
    LBRA .CMP_66_END
.CMP_66_TRUE:
    LDD #1
.CMP_66_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_58
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: fuji_bg (index=11, 6 paths)
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
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
    LDX #_FUJI_BG_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_58:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_67_TRUE
    LDD #0
    LBRA .CMP_67_END
.CMP_67_TRUE:
    LDD #1
.CMP_67_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_59
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: keirin_bg (index=13, 3 paths)
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_KEIRIN_BG_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_KEIRIN_BG_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_KEIRIN_BG_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_59:
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_68_TRUE
    LDD #0
    LBRA .CMP_68_END
.CMP_68_TRUE:
    LDD #1
.CMP_68_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_60
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: buddha_bg (index=9, 4 paths)
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
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
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_60:
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_69_TRUE
    LDD #0
    LBRA .CMP_69_END
.CMP_69_TRUE:
    LDD #1
.CMP_69_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_61
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: angkor_bg (index=0, 192 paths)
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
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
    LDX #_ANGKOR_BG_PATH170  ; Load path 170
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH171  ; Load path 171
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH172  ; Load path 172
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH173  ; Load path 173
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH174  ; Load path 174
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH175  ; Load path 175
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH176  ; Load path 176
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH177  ; Load path 177
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH178  ; Load path 178
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH179  ; Load path 179
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH180  ; Load path 180
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH181  ; Load path 181
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH182  ; Load path 182
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH183  ; Load path 183
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH184  ; Load path 184
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH185  ; Load path 185
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH186  ; Load path 186
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH187  ; Load path 187
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH188  ; Load path 188
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH189  ; Load path 189
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH190  ; Load path 190
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ANGKOR_BG_PATH191  ; Load path 191
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_61:
    LDD #4
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_70_TRUE
    LDD #0
    LBRA .CMP_70_END
.CMP_70_TRUE:
    LDD #1
.CMP_70_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_62
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: ayers_bg (index=3, 18 paths)
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
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
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_62:
    LDD #5
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_71_TRUE
    LDD #0
    LBRA .CMP_71_END
.CMP_71_TRUE:
    LDD #1
.CMP_71_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_63
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: taj_bg (index=29, 4 paths)
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
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
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_63:
    LDD #6
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_72_TRUE
    LDD #0
    LBRA .CMP_72_END
.CMP_72_TRUE:
    LDD #1
.CMP_72_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_64
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: leningrad_bg (index=15, 5 paths)
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
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
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_64:
    LDD #7
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_73_TRUE
    LDD #0
    LBRA .CMP_73_END
.CMP_73_TRUE:
    LDD #1
.CMP_73_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_65
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: paris_bg (index=22, 5 paths)
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
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
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_65:
    LDD #8
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_74_TRUE
    LDD #0
    LBRA .CMP_74_END
.CMP_74_TRUE:
    LDD #1
.CMP_74_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_66
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: london_bg (index=18, 4 paths)
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
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
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_66:
    LDD #9
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_75_TRUE
    LDD #0
    LBRA .CMP_75_END
.CMP_75_TRUE:
    LDD #1
.CMP_75_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_67
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: barcelona_bg (index=4, 60 paths)
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
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
    LDX #_BARCELONA_BG_PATH50  ; Load path 50
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH51  ; Load path 51
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH52  ; Load path 52
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH53  ; Load path 53
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH54  ; Load path 54
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH55  ; Load path 55
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH56  ; Load path 56
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH57  ; Load path 57
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH58  ; Load path 58
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_BARCELONA_BG_PATH59  ; Load path 59
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_67:
    LDD #10
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_76_TRUE
    LDD #0
    LBRA .CMP_76_END
.CMP_76_TRUE:
    LDD #1
.CMP_76_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_68
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: athens_bg (index=2, 41 paths)
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
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
    LDX #_ATHENS_BG_PATH33  ; Load path 33
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH34  ; Load path 34
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH35  ; Load path 35
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH36  ; Load path 36
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH37  ; Load path 37
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH38  ; Load path 38
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH39  ; Load path 39
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_ATHENS_BG_PATH40  ; Load path 40
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_68:
    LDD #11
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_77_TRUE
    LDD #0
    LBRA .CMP_77_END
.CMP_77_TRUE:
    LDD #1
.CMP_77_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_69
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: pyramids_bg (index=28, 4 paths)
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
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
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_69:
    LDD #12
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_78_TRUE
    LDD #0
    LBRA .CMP_78_END
.CMP_78_TRUE:
    LDD #1
.CMP_78_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_70
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: kilimanjaro_bg (index=14, 4 paths)
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
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
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_70:
    LDD #13
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_79_TRUE
    LDD #0
    LBRA .CMP_79_END
.CMP_79_TRUE:
    LDD #1
.CMP_79_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_71
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: newyork_bg (index=21, 5 paths)
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
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
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_71:
    LDD #14
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_80_TRUE
    LDD #0
    LBRA .CMP_80_END
.CMP_80_TRUE:
    LDD #1
.CMP_80_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_72
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: mayan_bg (index=20, 5 paths)
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
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
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_72:
    LDD #15
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_81_TRUE
    LDD #0
    LBRA .CMP_81_END
.CMP_81_TRUE:
    LDD #1
.CMP_81_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_73
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: antarctica_bg (index=1, 20 paths)
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
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
    LDX #_ANTARCTICA_BG_PATH19  ; Load path 19
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_73:
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: easter_bg (index=10, 5 paths)
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
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
    LDD #0
    STD RESULT
IF_END_57:
    RTS

; Function: DRAW_GAME_LEVEL
DRAW_GAME_LEVEL:
    JSR DRAW_LEVEL_BACKGROUND
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #0
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_JOY_X
    LDD #-20
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_83_TRUE
    LDD #0
    LBRA .CMP_83_END
.CMP_83_TRUE:
    LDD #1
.CMP_83_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_82_TRUE
    LDD #20
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_84_TRUE
    LDD #0
    LBRA .CMP_84_END
.CMP_84_TRUE:
    LDD #1
.CMP_84_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_82_TRUE
    LDD #0
    LBRA .LOGIC_82_END
.LOGIC_82_TRUE:
    LDD #1
.LOGIC_82_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_75
    LDD >VAR_JOY_X
    STD RESULT
    LDD RESULT
    STD VAR_ABS_JOY
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ABS_JOY
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_85_TRUE
    LDD #0
    LBRA .CMP_85_END
.CMP_85_TRUE:
    LDD #1
.CMP_85_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_77
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_ABS_JOY
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD RESULT
    LDD RESULT
    STD VAR_ABS_JOY
    LBRA IF_END_76
IF_NEXT_77:
IF_END_76:
    LDD #40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ABS_JOY
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_86_TRUE
    LDD #0
    LBRA .CMP_86_END
.CMP_86_TRUE:
    LDD #1
.CMP_86_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_79
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_MOVE_SPEED
    LBRA IF_END_78
IF_NEXT_79:
    LDD #70
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ABS_JOY
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_87_TRUE
    LDD #0
    LBRA .CMP_87_END
.CMP_87_TRUE:
    LDD #1
.CMP_87_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_80
    LDD #2
    STD RESULT
    LDD RESULT
    STD VAR_MOVE_SPEED
    LBRA IF_END_78
IF_NEXT_80:
    LDD #100
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ABS_JOY
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_88_TRUE
    LDD #0
    LBRA .CMP_88_END
.CMP_88_TRUE:
    LDD #1
.CMP_88_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_81
    LDD #3
    STD RESULT
    LDD RESULT
    STD VAR_MOVE_SPEED
    LBRA IF_END_78
IF_NEXT_81:
    LDD #4
    STD RESULT
    LDD RESULT
    STD VAR_MOVE_SPEED
IF_END_78:
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_89_TRUE
    LDD #0
    LBRA .CMP_89_END
.CMP_89_TRUE:
    LDD #1
.CMP_89_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_83
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_MOVE_SPEED
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD RESULT
    LDD RESULT
    STD VAR_MOVE_SPEED
    LBRA IF_END_82
IF_NEXT_83:
IF_END_82:
    LDD >VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_MOVE_SPEED
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_X
    LDD #-110
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_90_TRUE
    LDD #0
    LBRA .CMP_90_END
.CMP_90_TRUE:
    LDD #1
.CMP_90_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_85
    LDD #-110
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_X
    LBRA IF_END_84
IF_NEXT_85:
IF_END_84:
    LDD #110
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_91_TRUE
    LDD #0
    LBRA .CMP_91_END
.CMP_91_TRUE:
    LDD #1
.CMP_91_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_87
    LDD #110
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_X
    LBRA IF_END_86
IF_NEXT_87:
IF_END_86:
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_92_TRUE
    LDD #0
    LBRA .CMP_92_END
.CMP_92_TRUE:
    LDD #1
.CMP_92_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_89
    LDD #-1
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_FACING
    LBRA IF_END_88
IF_NEXT_89:
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_FACING
IF_END_88:
    LDD >VAR_PLAYER_ANIM_COUNTER
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_ANIM_COUNTER
    LDD #5  ; const PLAYER_ANIM_SPEED
    STD RESULT
    LDD RESULT
    STD VAR_ANIM_THRESHOLD
    LDD #-80
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_94_TRUE
    LDD #0
    LBRA .CMP_94_END
.CMP_94_TRUE:
    LDD #1
.CMP_94_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_93_TRUE
    LDD #80
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_95_TRUE
    LDD #0
    LBRA .CMP_95_END
.CMP_95_TRUE:
    LDD #1
.CMP_95_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_93_TRUE
    LDD #0
    LBRA .LOGIC_93_END
.LOGIC_93_TRUE:
    LDD #1
.LOGIC_93_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_91
    LDD #5  ; const PLAYER_ANIM_SPEED
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #2
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR DIV16       ; D = X / D
    STD RESULT
    LDD RESULT
    STD VAR_ANIM_THRESHOLD
    LBRA IF_END_90
IF_NEXT_91:
IF_END_90:
    LDD >VAR_ANIM_THRESHOLD
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_ANIM_COUNTER
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_96_TRUE
    LDD #0
    LBRA .CMP_96_END
.CMP_96_TRUE:
    LDD #1
.CMP_96_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_93
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_ANIM_COUNTER
    LDD >VAR_PLAYER_ANIM_FRAME
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_ANIM_FRAME
    LDD #5
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_ANIM_FRAME
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_97_TRUE
    LDD #0
    LBRA .CMP_97_END
.CMP_97_TRUE:
    LDD #1
.CMP_97_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_95
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_ANIM_FRAME
    LBRA IF_END_94
IF_NEXT_95:
IF_END_94:
    LBRA IF_END_92
IF_NEXT_93:
IF_END_92:
    LBRA IF_END_74
IF_NEXT_75:
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_ANIM_FRAME
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_ANIM_COUNTER
IF_END_74:
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_MIRROR_MODE
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_FACING
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_98_TRUE
    LDD #0
    LBRA .CMP_98_END
.CMP_98_TRUE:
    LDD #1
.CMP_98_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_97
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_MIRROR_MODE
    LBRA IF_END_96
IF_NEXT_97:
IF_END_96:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_ANIM_FRAME
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_99_TRUE
    LDD #0
    LBRA .CMP_99_END
.CMP_99_TRUE:
    LDD #1
.CMP_99_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_99
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_1 (17 paths) with mirror + intensity
    LDD >VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD #-70  ; const PLAYER_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD >VAR_MIRROR_MODE
    STD RESULT
    LDB RESULT+1  ; Mirror mode (0=normal, 1=X, 2=Y, 3=both)
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_2_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_2_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_2_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_2_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_2_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_2_CALL:
    ; Set intensity override for drawing
    LDD #80
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
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
    LBRA IF_END_98
IF_NEXT_99:
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_ANIM_FRAME
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_100_TRUE
    LDD #0
    LBRA .CMP_100_END
.CMP_100_TRUE:
    LDD #1
.CMP_100_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_100
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_2 (17 paths) with mirror + intensity
    LDD >VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD #-70  ; const PLAYER_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD >VAR_MIRROR_MODE
    STD RESULT
    LDB RESULT+1  ; Mirror mode (0=normal, 1=X, 2=Y, 3=both)
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_3_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_3_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_3_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_3_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_3_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_3_CALL:
    ; Set intensity override for drawing
    LDD #80
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
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
    LBRA IF_END_98
IF_NEXT_100:
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_ANIM_FRAME
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_101_TRUE
    LDD #0
    LBRA .CMP_101_END
.CMP_101_TRUE:
    LDD #1
.CMP_101_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_101
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_3 (17 paths) with mirror + intensity
    LDD >VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD #-70  ; const PLAYER_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD >VAR_MIRROR_MODE
    STD RESULT
    LDB RESULT+1  ; Mirror mode (0=normal, 1=X, 2=Y, 3=both)
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_4_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_4_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_4_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_4_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_4_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_4_CALL:
    ; Set intensity override for drawing
    LDD #80
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
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
    LBRA IF_END_98
IF_NEXT_101:
    LDD #4
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_ANIM_FRAME
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_102_TRUE
    LDD #0
    LBRA .CMP_102_END
.CMP_102_TRUE:
    LDD #1
.CMP_102_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_102
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_4 (17 paths) with mirror + intensity
    LDD >VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD #-70  ; const PLAYER_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD >VAR_MIRROR_MODE
    STD RESULT
    LDB RESULT+1  ; Mirror mode (0=normal, 1=X, 2=Y, 3=both)
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_5_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_5_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_5_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_5_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_5_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_5_CALL:
    ; Set intensity override for drawing
    LDD #80
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
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
    LBRA IF_END_98
IF_NEXT_102:
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_5 (17 paths) with mirror + intensity
    LDD >VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD #-70  ; const PLAYER_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD >VAR_MIRROR_MODE
    STD RESULT
    LDB RESULT+1  ; Mirror mode (0=normal, 1=X, 2=Y, 3=both)
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_6_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_6_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_6_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_6_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_6_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_6_CALL:
    ; Set intensity override for drawing
    LDD #80
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
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
IF_END_98:
    JSR UPDATE_ENEMIES
    JSR DRAW_ENEMIES
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_HOOK_ACTIVE
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_103_TRUE
    LDD #0
    LBRA .CMP_103_END
.CMP_103_TRUE:
    LDD #1
.CMP_103_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_104
    LDD >VAR_HOOK_GUN_X
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD >VAR_HOOK_INIT_Y
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDD >VAR_HOOK_X
    STD RESULT
    LDD RESULT
    STD VAR_ARG2
    LDD >VAR_HOOK_Y
    STD RESULT
    LDD RESULT
    STD VAR_ARG3
    JSR DRAW_HOOK_ROPE
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: hook (1 paths) with mirror + intensity
    LDD >VAR_HOOK_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD >VAR_HOOK_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD #0
    STD RESULT
    LDB RESULT+1  ; Mirror mode (0=normal, 1=X, 2=Y, 3=both)
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_7_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_7_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_7_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_7_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_7_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_7_CALL:
    ; Set intensity override for drawing
    LDD #100
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_HOOK_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    LBRA IF_END_103
IF_NEXT_104:
IF_END_103:
    RTS

; Function: SPAWN_ENEMIES
SPAWN_ENEMIES:
    LDX #ARRAY_LEVEL_ENEMY_COUNT_DATA  ; Array base
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_COUNT
    LDX #ARRAY_LEVEL_ENEMY_SPEED_DATA  ; Array base
    LDD >VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_SPEED
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_COUNT
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_104_TRUE
    LDD #0
    LBRA .CMP_104_END
.CMP_104_TRUE:
    LDD #1
.CMP_104_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_106
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_COUNT
    LBRA IF_END_105
IF_NEXT_106:
IF_END_105:
    LDD #8  ; const MAX_ENEMIES
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_COUNT
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_105_TRUE
    LDD #0
    LBRA .CMP_105_END
.CMP_105_TRUE:
    LDD #1
.CMP_105_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_108
    LDD #8  ; const MAX_ENEMIES
    STD RESULT
    LDD RESULT
    STD VAR_COUNT
    LBRA IF_END_107
IF_NEXT_108:
IF_END_107:
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_I
WH_109: ; while start
    LDD >VAR_COUNT
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_107_TRUE
    LDD #0
    LBRA .CMP_107_END
.CMP_107_TRUE:
    LDD #1
.CMP_107_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_106_FALSE
    LDD #8  ; const MAX_ENEMIES
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_108_TRUE
    LDD #0
    LBRA .CMP_108_END
.CMP_108_TRUE:
    LDD #1
.CMP_108_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_106_FALSE
    LDD #1
    LBRA .LOGIC_106_END
.LOGIC_106_FALSE:
    LDD #0
.LOGIC_106_END:
    STD RESULT
    LDD RESULT
    LBEQ WH_END_110
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_ACTIVE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #1
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_SIZE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #4
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_X_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #-80
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #50
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_Y_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #60
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VX_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD >VAR_SPEED
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #2
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MOD16       ; D = X % D
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_109_TRUE
    LDD #0
    LBRA .CMP_109_END
.CMP_109_TRUE:
    LDD #1
.CMP_109_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_112
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VX_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_SPEED
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LBRA IF_END_111
IF_NEXT_112:
IF_END_111:
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VY_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_I
    LBRA WH_109
WH_END_110: ; while end
    RTS

; Function: UPDATE_ENEMIES
UPDATE_ENEMIES:
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_I
WH_113: ; while start
    LDD #8  ; const MAX_ENEMIES
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_110_TRUE
    LDD #0
    LBRA .CMP_110_END
.CMP_110_TRUE:
    LDD #1
.CMP_110_END:
    STD RESULT
    LDD RESULT
    LBEQ WH_END_114
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_ACTIVE_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_111_TRUE
    LDD #0
    LBRA .CMP_111_END
.CMP_111_TRUE:
    LDD #1
.CMP_111_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_116
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VY_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_ENEMY_VY_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1  ; const GRAVITY
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_X_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_VX_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_Y_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_VY_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD #-70  ; const GROUND_Y
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLE .CMP_112_TRUE
    LDD #0
    LBRA .CMP_112_END
.CMP_112_TRUE:
    LDD #1
.CMP_112_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_118
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_Y_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #-70  ; const GROUND_Y
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VY_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_VY_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VY_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_ENEMY_VY_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #17  ; const BOUNCE_DAMPING
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #20
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR DIV16       ; D = X / D
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD #10  ; const MIN_BOUNCE_VY
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_VY_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_113_TRUE
    LDD #0
    LBRA .CMP_113_END
.CMP_113_TRUE:
    LDD #1
.CMP_113_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_120
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VY_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #10  ; const MIN_BOUNCE_VY
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LBRA IF_END_119
IF_NEXT_120:
IF_END_119:
    LBRA IF_END_117
IF_NEXT_118:
IF_END_117:
    LDD #-85
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLE .CMP_114_TRUE
    LDD #0
    LBRA .CMP_114_END
.CMP_114_TRUE:
    LDD #1
.CMP_114_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_122
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_X_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #-85
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VX_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_VX_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LBRA IF_END_121
IF_NEXT_122:
IF_END_121:
    LDD #85
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_115_TRUE
    LDD #0
    LBRA .CMP_115_END
.CMP_115_TRUE:
    LDD #1
.CMP_115_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_124
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_X_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #85
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VX_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_VX_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LBRA IF_END_123
IF_NEXT_124:
IF_END_123:
    LBRA IF_END_115
IF_NEXT_116:
IF_END_115:
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_I
    LBRA WH_113
WH_END_114: ; while end
    RTS

; Function: DRAW_ENEMIES
DRAW_ENEMIES:
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_I
WH_125: ; while start
    LDD #8  ; const MAX_ENEMIES
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_116_TRUE
    LDD #0
    LBRA .CMP_116_END
.CMP_116_TRUE:
    LDD #1
.CMP_116_END:
    STD RESULT
    LDD RESULT
    LBEQ WH_END_126
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_ACTIVE_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_117_TRUE
    LDD #0
    LBRA .CMP_117_END
.CMP_117_TRUE:
    LDD #1
.CMP_117_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_128
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    LDD #4
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_SIZE_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_118_TRUE
    LDD #0
    LBRA .CMP_118_END
.CMP_118_TRUE:
    LDD #1
.CMP_118_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_130
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bubble_huge (index=5, 1 paths)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_BUBBLE_HUGE_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_129
IF_NEXT_130:
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_SIZE_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_119_TRUE
    LDD #0
    LBRA .CMP_119_END
.CMP_119_TRUE:
    LDD #1
.CMP_119_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_131
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bubble_large (index=6, 1 paths)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_BUBBLE_LARGE_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_129
IF_NEXT_131:
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_SIZE_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_120_TRUE
    LDD #0
    LBRA .CMP_120_END
.CMP_120_TRUE:
    LDD #1
.CMP_120_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_132
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bubble_medium (index=7, 1 paths)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_BUBBLE_MEDIUM_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_129
IF_NEXT_132:
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bubble_small (index=8, 1 paths)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD >VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_BUBBLE_SMALL_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
IF_END_129:
    LBRA IF_END_127
IF_NEXT_128:
IF_END_127:
    LDD >VAR_I
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_I
    LBRA WH_125
WH_END_126: ; while end
    RTS

; Function: DRAW_HOOK_ROPE
DRAW_HOOK_ROPE:
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_START_X
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_START_Y
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_END_X
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_END_Y
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #127
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    RTS

; Function: READ_JOYSTICK1_STATE
READ_JOYSTICK1_STATE:
    LDD #0
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_JOYSTICK1_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    JSR J1X_BUILTIN
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD #1
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_JOYSTICK1_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    JSR J1Y_BUILTIN
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD #2
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_JOYSTICK1_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDA $C811      ; Vec_Button_1_1 (transition bits, rising edge = debounce)
    ANDA #$01      ; Test bit 0 (Button 1)
    LBEQ .J1B1_8_OFF
    LDD #1
    LBRA .J1B1_8_END
.J1B1_8_OFF:
    LDD #0
.J1B1_8_END:
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD #3
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_JOYSTICK1_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDA $C811      ; Vec_Button_1_1 (transition bits, rising edge = debounce)
    ANDA #$02      ; Test bit 1 (Button 2)
    LBEQ .J1B2_9_OFF
    LDD #1
    LBRA .J1B2_9_END
.J1B2_9_OFF:
    LDD #0
.J1B2_9_END:
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD #4
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_JOYSTICK1_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDA $C811      ; Vec_Button_1_1 (transition bits, rising edge = debounce)
    ANDA #$04      ; Test bit 2 (Button 3)
    LBEQ .J1B3_10_OFF
    LDD #1
    LBRA .J1B3_10_END
.J1B3_10_OFF:
    LDD #0
.J1B3_10_END:
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD #5
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_JOYSTICK1_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDA $C811      ; Vec_Button_1_1 (transition bits, rising edge = debounce)
    ANDA #$08      ; Test bit 3 (Button 4)
    LBEQ .J1B4_11_OFF
    LDD #1
    LBRA .J1B4_11_END
.J1B4_11_OFF:
    LDD #0
.J1B4_11_END:
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
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
_ANGKOR_BG_CENTER_X EQU 0
_ANGKOR_BG_CENTER_Y EQU 8

_ANGKOR_BG_VECTORS:  ; Main entry (header + 192 path(s))
    FCB 192               ; path_count (runtime metadata)
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
    FDB _ANGKOR_BG_PATH139        ; pointer to path 139
    FDB _ANGKOR_BG_PATH140        ; pointer to path 140
    FDB _ANGKOR_BG_PATH141        ; pointer to path 141
    FDB _ANGKOR_BG_PATH142        ; pointer to path 142
    FDB _ANGKOR_BG_PATH143        ; pointer to path 143
    FDB _ANGKOR_BG_PATH144        ; pointer to path 144
    FDB _ANGKOR_BG_PATH145        ; pointer to path 145
    FDB _ANGKOR_BG_PATH146        ; pointer to path 146
    FDB _ANGKOR_BG_PATH147        ; pointer to path 147
    FDB _ANGKOR_BG_PATH148        ; pointer to path 148
    FDB _ANGKOR_BG_PATH149        ; pointer to path 149
    FDB _ANGKOR_BG_PATH150        ; pointer to path 150
    FDB _ANGKOR_BG_PATH151        ; pointer to path 151
    FDB _ANGKOR_BG_PATH152        ; pointer to path 152
    FDB _ANGKOR_BG_PATH153        ; pointer to path 153
    FDB _ANGKOR_BG_PATH154        ; pointer to path 154
    FDB _ANGKOR_BG_PATH155        ; pointer to path 155
    FDB _ANGKOR_BG_PATH156        ; pointer to path 156
    FDB _ANGKOR_BG_PATH157        ; pointer to path 157
    FDB _ANGKOR_BG_PATH158        ; pointer to path 158
    FDB _ANGKOR_BG_PATH159        ; pointer to path 159
    FDB _ANGKOR_BG_PATH160        ; pointer to path 160
    FDB _ANGKOR_BG_PATH161        ; pointer to path 161
    FDB _ANGKOR_BG_PATH162        ; pointer to path 162
    FDB _ANGKOR_BG_PATH163        ; pointer to path 163
    FDB _ANGKOR_BG_PATH164        ; pointer to path 164
    FDB _ANGKOR_BG_PATH165        ; pointer to path 165
    FDB _ANGKOR_BG_PATH166        ; pointer to path 166
    FDB _ANGKOR_BG_PATH167        ; pointer to path 167
    FDB _ANGKOR_BG_PATH168        ; pointer to path 168
    FDB _ANGKOR_BG_PATH169        ; pointer to path 169
    FDB _ANGKOR_BG_PATH170        ; pointer to path 170
    FDB _ANGKOR_BG_PATH171        ; pointer to path 171
    FDB _ANGKOR_BG_PATH172        ; pointer to path 172
    FDB _ANGKOR_BG_PATH173        ; pointer to path 173
    FDB _ANGKOR_BG_PATH174        ; pointer to path 174
    FDB _ANGKOR_BG_PATH175        ; pointer to path 175
    FDB _ANGKOR_BG_PATH176        ; pointer to path 176
    FDB _ANGKOR_BG_PATH177        ; pointer to path 177
    FDB _ANGKOR_BG_PATH178        ; pointer to path 178
    FDB _ANGKOR_BG_PATH179        ; pointer to path 179
    FDB _ANGKOR_BG_PATH180        ; pointer to path 180
    FDB _ANGKOR_BG_PATH181        ; pointer to path 181
    FDB _ANGKOR_BG_PATH182        ; pointer to path 182
    FDB _ANGKOR_BG_PATH183        ; pointer to path 183
    FDB _ANGKOR_BG_PATH184        ; pointer to path 184
    FDB _ANGKOR_BG_PATH185        ; pointer to path 185
    FDB _ANGKOR_BG_PATH186        ; pointer to path 186
    FDB _ANGKOR_BG_PATH187        ; pointer to path 187
    FDB _ANGKOR_BG_PATH188        ; pointer to path 188
    FDB _ANGKOR_BG_PATH189        ; pointer to path 189
    FDB _ANGKOR_BG_PATH190        ; pointer to path 190
    FDB _ANGKOR_BG_PATH191        ; pointer to path 191

_ANGKOR_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $CA,$A0,0,0        ; path0: header (y=-54, x=-96, relative to center)
    FCB $FF,$0D,$00          ; flag=-1, dy=13, dx=0
    FCB $FF,$00,$4C          ; flag=-1, dy=0, dx=76
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $D2,$A0,0,0        ; path1: header (y=-46, x=-96, relative to center)
    FCB $FF,$00,$4C          ; flag=-1, dy=0, dx=76
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $D8,$EC,0,0        ; path2: header (y=-40, x=-20, relative to center)
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $D8,$EE,0,0        ; path3: header (y=-40, x=-18, relative to center)
    FCB $FF,$0F,$00          ; flag=-1, dy=15, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $E3,$EE,0,0        ; path4: header (y=-29, x=-18, relative to center)
    FCB $FF,$00,$B6          ; flag=-1, dy=0, dx=-74
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $E3,$A4,0,0        ; path5: header (y=-29, x=-92, relative to center)
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $E9,$A4,0,0        ; path6: header (y=-23, x=-92, relative to center)
    FCB $FF,$00,$49          ; flag=-1, dy=0, dx=73
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $E7,$F5,0,0        ; path7: header (y=-25, x=-11, relative to center)
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$01,$02          ; flag=-1, dy=1, dx=2
    FCB $FF,$01,$03          ; flag=-1, dy=1, dx=3
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $FC,$00,0,0        ; path8: header (y=-4, x=0, relative to center)
    FCB $FF,$F5,$F5          ; flag=-1, dy=-11, dx=-11
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $E3,$A5,0,0        ; path9: header (y=-29, x=-91, relative to center)
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $E3,$B1,0,0        ; path10: header (y=-29, x=-79, relative to center)
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $E3,$BE,0,0        ; path11: header (y=-29, x=-66, relative to center)
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $E3,$CA,0,0        ; path12: header (y=-29, x=-54, relative to center)
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $E3,$D8,0,0        ; path13: header (y=-29, x=-40, relative to center)
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $E9,$A9,0,0        ; path14: header (y=-23, x=-87, relative to center)
    FCB $FF,$0E,$00          ; flag=-1, dy=14, dx=0
    FCB $FF,$00,$31          ; flag=-1, dy=0, dx=49
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $F7,$BB,0,0        ; path15: header (y=-9, x=-69, relative to center)
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $F0,$A9,0,0        ; path16: header (y=-16, x=-87, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $F0,$BB,0,0        ; path17: header (y=-16, x=-69, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH18:    ; Path 18
    FCB 127              ; path18: intensity
    FCB $FD,$DA,0,0        ; path18: header (y=-3, x=-38, relative to center)
    FCB $FF,$EC,$00          ; flag=-1, dy=-20, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH19:    ; Path 19
    FCB 127              ; path19: intensity
    FCB $F7,$B3,0,0        ; path19: header (y=-9, x=-77, relative to center)
    FCB $FF,$10,$00          ; flag=-1, dy=16, dx=0
    FCB $FF,$00,$1B          ; flag=-1, dy=0, dx=27
    FCB $FF,$F0,$00          ; flag=-1, dy=-16, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH20:    ; Path 20
    FCB 127              ; path20: intensity
    FCB $07,$B4,0,0        ; path20: header (y=7, x=-76, relative to center)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$02,$FD          ; flag=-1, dy=2, dx=-3
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH21:    ; Path 21
    FCB 127              ; path21: intensity
    FCB $07,$B8,0,0        ; path21: header (y=7, x=-72, relative to center)
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH22:    ; Path 22
    FCB 127              ; path22: intensity
    FCB $07,$C7,0,0        ; path22: header (y=7, x=-57, relative to center)
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH23:    ; Path 23
    FCB 127              ; path23: intensity
    FCB $07,$CB,0,0        ; path23: header (y=7, x=-53, relative to center)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH24:    ; Path 24
    FCB 127              ; path24: intensity
    FCB $0C,$B1,0,0        ; path24: header (y=12, x=-79, relative to center)
    FCB $FF,$02,$05          ; flag=-1, dy=2, dx=5
    FCB $FF,$00,$10          ; flag=-1, dy=0, dx=16
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH25:    ; Path 25
    FCB 127              ; path25: intensity
    FCB $0E,$B9,0,0        ; path25: header (y=14, x=-71, relative to center)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH26:    ; Path 26
    FCB 127              ; path26: intensity
    FCB $16,$C6,0,0        ; path26: header (y=22, x=-58, relative to center)
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH27:    ; Path 27
    FCB 127              ; path27: intensity
    FCB $16,$B9,0,0        ; path27: header (y=22, x=-71, relative to center)
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$FE,$FB          ; flag=-1, dy=-2, dx=-5
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH28:    ; Path 28
    FCB 127              ; path28: intensity
    FCB $14,$CC,0,0        ; path28: header (y=20, x=-52, relative to center)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH29:    ; Path 29
    FCB 127              ; path29: intensity
    FCB $14,$B3,0,0        ; path29: header (y=20, x=-77, relative to center)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH30:    ; Path 30
    FCB 127              ; path30: intensity
    FCB $16,$BA,0,0        ; path30: header (y=22, x=-70, relative to center)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$0B          ; flag=-1, dy=0, dx=11
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH31:    ; Path 31
    FCB 127              ; path31: intensity
    FCB $1E,$BA,0,0        ; path31: header (y=30, x=-70, relative to center)
    FCB $FF,$FE,$FA          ; flag=-1, dy=-2, dx=-6
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH32:    ; Path 32
    FCB 127              ; path32: intensity
    FCB $1C,$B4,0,0        ; path32: header (y=28, x=-76, relative to center)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH33:    ; Path 33
    FCB 127              ; path33: intensity
    FCB $1E,$C5,0,0        ; path33: header (y=30, x=-59, relative to center)
    FCB $FF,$FE,$06          ; flag=-1, dy=-2, dx=6
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH34:    ; Path 34
    FCB 127              ; path34: intensity
    FCB $1C,$CB,0,0        ; path34: header (y=28, x=-53, relative to center)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH35:    ; Path 35
    FCB 127              ; path35: intensity
    FCB $1E,$B9,0,0        ; path35: header (y=30, x=-71, relative to center)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH36:    ; Path 36
    FCB 127              ; path36: intensity
    FCB $23,$B7,0,0        ; path36: header (y=35, x=-73, relative to center)
    FCB $FF,$01,$04          ; flag=-1, dy=1, dx=4
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH37:    ; Path 37
    FCB 127              ; path37: intensity
    FCB $1E,$C6,0,0        ; path37: header (y=30, x=-58, relative to center)
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH38:    ; Path 38
    FCB 127              ; path38: intensity
    FCB $24,$BC,0,0        ; path38: header (y=36, x=-68, relative to center)
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH39:    ; Path 39
    FCB 127              ; path39: intensity
    FCB $1E,$C3,0,0        ; path39: header (y=30, x=-61, relative to center)
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH40:    ; Path 40
    FCB 127              ; path40: intensity
    FCB $24,$B9,0,0        ; path40: header (y=36, x=-71, relative to center)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$0D          ; flag=-1, dy=0, dx=13
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH41:    ; Path 41
    FCB 127              ; path41: intensity
    FCB $29,$BA,0,0        ; path41: header (y=41, x=-70, relative to center)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$0B          ; flag=-1, dy=0, dx=11
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH42:    ; Path 42
    FCB 127              ; path42: intensity
    FCB $2D,$BC,0,0        ; path42: header (y=45, x=-68, relative to center)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH43:    ; Path 43
    FCB 127              ; path43: intensity
    FCB $30,$BD,0,0        ; path43: header (y=48, x=-67, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH44:    ; Path 44
    FCB 127              ; path44: intensity
    FCB $30,$C2,0,0        ; path44: header (y=48, x=-62, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH45:    ; Path 45
    FCB 127              ; path45: intensity
    FCB $33,$B7,0,0        ; path45: header (y=51, x=-73, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH46:    ; Path 46
    FCB 127              ; path46: intensity
    FCB $33,$C2,0,0        ; path46: header (y=51, x=-62, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH47:    ; Path 47
    FCB 127              ; path47: intensity
    FCB $30,$BD,0,0        ; path47: header (y=48, x=-67, relative to center)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH48:    ; Path 48
    FCB 127              ; path48: intensity
    FCB $30,$C2,0,0        ; path48: header (y=48, x=-62, relative to center)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH49:    ; Path 49
    FCB 127              ; path49: intensity
    FCB $07,$B9,0,0        ; path49: header (y=7, x=-71, relative to center)
    FCB $FF,$F0,$00          ; flag=-1, dy=-16, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH50:    ; Path 50
    FCB 127              ; path50: intensity
    FCB $F7,$C6,0,0        ; path50: header (y=-9, x=-58, relative to center)
    FCB $FF,$10,$00          ; flag=-1, dy=16, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH51:    ; Path 51
    FCB 127              ; path51: intensity
    FCB $04,$BC,0,0        ; path51: header (y=4, x=-68, relative to center)
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB $FF,$00,$F9          ; flag=-1, dy=0, dx=-7
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH52:    ; Path 52
    FCB 127              ; path52: intensity
    FCB $07,$BC,0,0        ; path52: header (y=7, x=-68, relative to center)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$FE,$03          ; flag=-1, dy=-2, dx=3
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH53:    ; Path 53
    FCB 127              ; path53: intensity
    FCB $E3,$E5,0,0        ; path53: header (y=-29, x=-27, relative to center)
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH54:    ; Path 54
    FCB 127              ; path54: intensity
    FCB $EC,$F5,0,0        ; path54: header (y=-20, x=-11, relative to center)
    FCB $FF,$EE,$00          ; flag=-1, dy=-18, dx=0
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH55:    ; Path 55
    FCB 127              ; path55: intensity
    FCB $F3,$FC,0,0        ; path55: header (y=-13, x=-4, relative to center)
    FCB $FF,$FC,$FD          ; flag=-1, dy=-4, dx=-3
    FCB $FF,$E9,$00          ; flag=-1, dy=-23, dx=0
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH56:    ; Path 56
    FCB 127              ; path56: intensity
    FCB $F3,$FC,0,0        ; path56: header (y=-13, x=-4, relative to center)
    FCB $FF,$01,$04          ; flag=-1, dy=1, dx=4
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH57:    ; Path 57
    FCB 127              ; path57: intensity
    FCB $F2,$A9,0,0        ; path57: header (y=-14, x=-87, relative to center)
    FCB $FF,$00,$4A          ; flag=-1, dy=0, dx=74
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH58:    ; Path 58
    FCB 127              ; path58: intensity
    FCB $D0,$EC,0,0        ; path58: header (y=-48, x=-20, relative to center)
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB $FF,$00,$0B          ; flag=-1, dy=0, dx=11
    FCB $FF,$0E,$00          ; flag=-1, dy=14, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH59:    ; Path 59
    FCB 127              ; path59: intensity
    FCB $D4,$F7,0,0        ; path59: header (y=-44, x=-9, relative to center)
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH60:    ; Path 60
    FCB 127              ; path60: intensity
    FCB $D1,$00,0,0        ; path60: header (y=-47, x=0, relative to center)
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH61:    ; Path 61
    FCB 127              ; path61: intensity
    FCB $CC,$F4,0,0        ; path61: header (y=-52, x=-12, relative to center)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH62:    ; Path 62
    FCB 127              ; path62: intensity
    FCB $C7,$00,0,0        ; path62: header (y=-57, x=0, relative to center)
    FCB $FF,$00,$F3          ; flag=-1, dy=0, dx=-13
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH63:    ; Path 63
    FCB 127              ; path63: intensity
    FCB $C0,$F2,0,0        ; path63: header (y=-64, x=-14, relative to center)
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH64:    ; Path 64
    FCB 127              ; path64: intensity
    FCB $FD,$F5,0,0        ; path64: header (y=-3, x=-11, relative to center)
    FCB $FF,$00,$E3          ; flag=-1, dy=0, dx=-29
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$00,$1D          ; flag=-1, dy=0, dx=29
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH65:    ; Path 65
    FCB 127              ; path65: intensity
    FCB $FD,$F5,0,0        ; path65: header (y=-3, x=-11, relative to center)
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH66:    ; Path 66
    FCB 127              ; path66: intensity
    FCB $07,$CE,0,0        ; path66: header (y=7, x=-50, relative to center)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$2D          ; flag=-1, dy=0, dx=45
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH67:    ; Path 67
    FCB 127              ; path67: intensity
    FCB $F4,$00,0,0        ; path67: header (y=-12, x=0, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH68:    ; Path 68
    FCB 127              ; path68: intensity
    FCB $FC,$00,0,0        ; path68: header (y=-4, x=0, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH69:    ; Path 69
    FCB 127              ; path69: intensity
    FCB $D0,$0E,0,0        ; path69: header (y=-48, x=14, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH70:    ; Path 70
    FCB 127              ; path70: intensity
    FCB $C1,$0F,0,0        ; path70: header (y=-63, x=15, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH71:    ; Path 71
    FCB 127              ; path71: intensity
    FCB $01,$F5,0,0        ; path71: header (y=1, x=-11, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH72:    ; Path 72
    FCB 127              ; path72: intensity
    FCB $06,$F0,0,0        ; path72: header (y=6, x=-16, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH73:    ; Path 73
    FCB 127              ; path73: intensity
    FCB $0C,$FA,0,0        ; path73: header (y=12, x=-6, relative to center)
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH74:    ; Path 74
    FCB 127              ; path74: intensity
    FCB $12,$FA,0,0        ; path74: header (y=18, x=-6, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH75:    ; Path 75
    FCB 127              ; path75: intensity
    FCB $0C,$FA,0,0        ; path75: header (y=12, x=-6, relative to center)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FF,$01          ; flag=-1, dy=-1, dx=1
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH76:    ; Path 76
    FCB 127              ; path76: intensity
    FCB $10,$F5,0,0        ; path76: header (y=16, x=-11, relative to center)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$03,$FD          ; flag=-1, dy=3, dx=-3
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH77:    ; Path 77
    FCB 127              ; path77: intensity
    FCB $10,$F8,0,0        ; path77: header (y=16, x=-8, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH78:    ; Path 78
    FCB 127              ; path78: intensity
    FCB $18,$F2,0,0        ; path78: header (y=24, x=-14, relative to center)
    FCB $FF,$02,$05          ; flag=-1, dy=2, dx=5
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH79:    ; Path 79
    FCB 127              ; path79: intensity
    FCB $1A,$F9,0,0        ; path79: header (y=26, x=-7, relative to center)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$FF,$FA          ; flag=-1, dy=-1, dx=-6
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH80:    ; Path 80
    FCB 127              ; path80: intensity
    FCB $21,$F3,0,0        ; path80: header (y=33, x=-13, relative to center)
    FCB $FF,$FC,$03          ; flag=-1, dy=-4, dx=3
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH81:    ; Path 81
    FCB 127              ; path81: intensity
    FCB $22,$F9,0,0        ; path81: header (y=34, x=-7, relative to center)
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH82:    ; Path 82
    FCB 127              ; path82: intensity
    FCB $22,$FB,0,0        ; path82: header (y=34, x=-5, relative to center)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH83:    ; Path 83
    FCB 127              ; path83: intensity
    FCB $2A,$FC,0,0        ; path83: header (y=42, x=-4, relative to center)
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH84:    ; Path 84
    FCB 127              ; path84: intensity
    FCB $31,$FC,0,0        ; path84: header (y=49, x=-4, relative to center)
    FCB $FF,$FF,$FC          ; flag=-1, dy=-1, dx=-4
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH85:    ; Path 85
    FCB 127              ; path85: intensity
    FCB $30,$F8,0,0        ; path85: header (y=48, x=-8, relative to center)
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH86:    ; Path 86
    FCB 127              ; path86: intensity
    FCB $2A,$FB,0,0        ; path86: header (y=42, x=-5, relative to center)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$FC          ; flag=-1, dy=-2, dx=-4
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH87:    ; Path 87
    FCB 127              ; path87: intensity
    FCB $28,$F5,0,0        ; path87: header (y=40, x=-11, relative to center)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH88:    ; Path 88
    FCB 127              ; path88: intensity
    FCB $31,$FA,0,0        ; path88: header (y=49, x=-6, relative to center)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH89:    ; Path 89
    FCB 127              ; path89: intensity
    FCB $36,$FB,0,0        ; path89: header (y=54, x=-5, relative to center)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH90:    ; Path 90
    FCB 127              ; path90: intensity
    FCB $3A,$FD,0,0        ; path90: header (y=58, x=-3, relative to center)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH91:    ; Path 91
    FCB 127              ; path91: intensity
    FCB $3D,$FE,0,0        ; path91: header (y=61, x=-2, relative to center)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH92:    ; Path 92
    FCB 127              ; path92: intensity
    FCB $11,$FD,0,0        ; path92: header (y=17, x=-3, relative to center)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH93:    ; Path 93
    FCB 127              ; path93: intensity
    FCB $06,$F5,0,0        ; path93: header (y=6, x=-11, relative to center)
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH94:    ; Path 94
    FCB 127              ; path94: intensity
    FCB $01,$F5,0,0        ; path94: header (y=1, x=-11, relative to center)
    FCB $FF,$00,$0B          ; flag=-1, dy=0, dx=11
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH95:    ; Path 95
    FCB 127              ; path95: intensity
    FCB $F2,$F6,0,0        ; path95: header (y=-14, x=-10, relative to center)
    FCB $FF,$02,$FD          ; flag=-1, dy=2, dx=-3
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$03,$04          ; flag=-1, dy=3, dx=4
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH96:    ; Path 96
    FCB 127              ; path96: intensity
    FCB $CA,$60,0,0        ; path96: header (y=-54, x=96, relative to center)
    FCB $FF,$0D,$00          ; flag=-1, dy=13, dx=0
    FCB $FF,$00,$B4          ; flag=-1, dy=0, dx=-76
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH97:    ; Path 97
    FCB 127              ; path97: intensity
    FCB $D2,$60,0,0        ; path97: header (y=-46, x=96, relative to center)
    FCB $FF,$00,$B4          ; flag=-1, dy=0, dx=-76
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH98:    ; Path 98
    FCB 127              ; path98: intensity
    FCB $D8,$14,0,0        ; path98: header (y=-40, x=20, relative to center)
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$F9          ; flag=-1, dy=0, dx=-7
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH99:    ; Path 99
    FCB 127              ; path99: intensity
    FCB $D8,$12,0,0        ; path99: header (y=-40, x=18, relative to center)
    FCB $FF,$0F,$00          ; flag=-1, dy=15, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH100:    ; Path 100
    FCB 127              ; path100: intensity
    FCB $E3,$12,0,0        ; path100: header (y=-29, x=18, relative to center)
    FCB $FF,$00,$4A          ; flag=-1, dy=0, dx=74
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH101:    ; Path 101
    FCB 127              ; path101: intensity
    FCB $E3,$5C,0,0        ; path101: header (y=-29, x=92, relative to center)
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH102:    ; Path 102
    FCB 127              ; path102: intensity
    FCB $E9,$5C,0,0        ; path102: header (y=-23, x=92, relative to center)
    FCB $FF,$00,$B7          ; flag=-1, dy=0, dx=-73
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH103:    ; Path 103
    FCB 127              ; path103: intensity
    FCB $E7,$0B,0,0        ; path103: header (y=-25, x=11, relative to center)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH104:    ; Path 104
    FCB 127              ; path104: intensity
    FCB $FC,$00,0,0        ; path104: header (y=-4, x=0, relative to center)
    FCB $FF,$F5,$0B          ; flag=-1, dy=-11, dx=11
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH105:    ; Path 105
    FCB 127              ; path105: intensity
    FCB $E3,$5B,0,0        ; path105: header (y=-29, x=91, relative to center)
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH106:    ; Path 106
    FCB 127              ; path106: intensity
    FCB $E3,$4F,0,0        ; path106: header (y=-29, x=79, relative to center)
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH107:    ; Path 107
    FCB 127              ; path107: intensity
    FCB $E3,$42,0,0        ; path107: header (y=-29, x=66, relative to center)
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH108:    ; Path 108
    FCB 127              ; path108: intensity
    FCB $E3,$36,0,0        ; path108: header (y=-29, x=54, relative to center)
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH109:    ; Path 109
    FCB 127              ; path109: intensity
    FCB $E3,$28,0,0        ; path109: header (y=-29, x=40, relative to center)
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH110:    ; Path 110
    FCB 127              ; path110: intensity
    FCB $E9,$57,0,0        ; path110: header (y=-23, x=87, relative to center)
    FCB $FF,$0E,$00          ; flag=-1, dy=14, dx=0
    FCB $FF,$00,$CF          ; flag=-1, dy=0, dx=-49
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH111:    ; Path 111
    FCB 127              ; path111: intensity
    FCB $F7,$45,0,0        ; path111: header (y=-9, x=69, relative to center)
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH112:    ; Path 112
    FCB 127              ; path112: intensity
    FCB $EC,$57,0,0        ; path112: header (y=-20, x=87, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH113:    ; Path 113
    FCB 127              ; path113: intensity
    FCB $F0,$26,0,0        ; path113: header (y=-16, x=38, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH114:    ; Path 114
    FCB 127              ; path114: intensity
    FCB $FD,$26,0,0        ; path114: header (y=-3, x=38, relative to center)
    FCB $FF,$EC,$00          ; flag=-1, dy=-20, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH115:    ; Path 115
    FCB 127              ; path115: intensity
    FCB $F7,$4D,0,0        ; path115: header (y=-9, x=77, relative to center)
    FCB $FF,$10,$00          ; flag=-1, dy=16, dx=0
    FCB $FF,$00,$E5          ; flag=-1, dy=0, dx=-27
    FCB $FF,$F0,$00          ; flag=-1, dy=-16, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH116:    ; Path 116
    FCB 127              ; path116: intensity
    FCB $07,$4C,0,0        ; path116: header (y=7, x=76, relative to center)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH117:    ; Path 117
    FCB 127              ; path117: intensity
    FCB $07,$48,0,0        ; path117: header (y=7, x=72, relative to center)
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH118:    ; Path 118
    FCB 127              ; path118: intensity
    FCB $07,$39,0,0        ; path118: header (y=7, x=57, relative to center)
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH119:    ; Path 119
    FCB 127              ; path119: intensity
    FCB $07,$35,0,0        ; path119: header (y=7, x=53, relative to center)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$02,$FD          ; flag=-1, dy=2, dx=-3
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH120:    ; Path 120
    FCB 127              ; path120: intensity
    FCB $0C,$4F,0,0        ; path120: header (y=12, x=79, relative to center)
    FCB $FF,$02,$FB          ; flag=-1, dy=2, dx=-5
    FCB $FF,$00,$F0          ; flag=-1, dy=0, dx=-16
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$FE,$FB          ; flag=-1, dy=-2, dx=-5
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH121:    ; Path 121
    FCB 127              ; path121: intensity
    FCB $0E,$47,0,0        ; path121: header (y=14, x=71, relative to center)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$FE,$FB          ; flag=-1, dy=-2, dx=-5
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH122:    ; Path 122
    FCB 127              ; path122: intensity
    FCB $16,$3A,0,0        ; path122: header (y=22, x=58, relative to center)
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH123:    ; Path 123
    FCB 127              ; path123: intensity
    FCB $16,$47,0,0        ; path123: header (y=22, x=71, relative to center)
    FCB $FF,$00,$01          ; flag=-1, dy=0, dx=1
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH124:    ; Path 124
    FCB 127              ; path124: intensity
    FCB $14,$34,0,0        ; path124: header (y=20, x=52, relative to center)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH125:    ; Path 125
    FCB 127              ; path125: intensity
    FCB $14,$4D,0,0        ; path125: header (y=20, x=77, relative to center)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH126:    ; Path 126
    FCB 127              ; path126: intensity
    FCB $16,$46,0,0        ; path126: header (y=22, x=70, relative to center)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$F5          ; flag=-1, dy=0, dx=-11
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH127:    ; Path 127
    FCB 127              ; path127: intensity
    FCB $1E,$46,0,0        ; path127: header (y=30, x=70, relative to center)
    FCB $FF,$FE,$06          ; flag=-1, dy=-2, dx=6
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH128:    ; Path 128
    FCB 127              ; path128: intensity
    FCB $1C,$4C,0,0        ; path128: header (y=28, x=76, relative to center)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH129:    ; Path 129
    FCB 127              ; path129: intensity
    FCB $1E,$3B,0,0        ; path129: header (y=30, x=59, relative to center)
    FCB $FF,$FE,$FA          ; flag=-1, dy=-2, dx=-6
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH130:    ; Path 130
    FCB 127              ; path130: intensity
    FCB $1C,$35,0,0        ; path130: header (y=28, x=53, relative to center)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH131:    ; Path 131
    FCB 127              ; path131: intensity
    FCB $1E,$47,0,0        ; path131: header (y=30, x=71, relative to center)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$01,$02          ; flag=-1, dy=1, dx=2
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH132:    ; Path 132
    FCB 127              ; path132: intensity
    FCB $23,$49,0,0        ; path132: header (y=35, x=73, relative to center)
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB $FF,$FF,$FC          ; flag=-1, dy=-1, dx=-4
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH133:    ; Path 133
    FCB 127              ; path133: intensity
    FCB $1E,$3A,0,0        ; path133: header (y=30, x=58, relative to center)
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$03,$FE          ; flag=-1, dy=3, dx=-2
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH134:    ; Path 134
    FCB 127              ; path134: intensity
    FCB $24,$44,0,0        ; path134: header (y=36, x=68, relative to center)
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH135:    ; Path 135
    FCB 127              ; path135: intensity
    FCB $1E,$3D,0,0        ; path135: header (y=30, x=61, relative to center)
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH136:    ; Path 136
    FCB 127              ; path136: intensity
    FCB $24,$47,0,0        ; path136: header (y=36, x=71, relative to center)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$F3          ; flag=-1, dy=0, dx=-13
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH137:    ; Path 137
    FCB 127              ; path137: intensity
    FCB $29,$46,0,0        ; path137: header (y=41, x=70, relative to center)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$F5          ; flag=-1, dy=0, dx=-11
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH138:    ; Path 138
    FCB 127              ; path138: intensity
    FCB $2D,$44,0,0        ; path138: header (y=45, x=68, relative to center)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$F9          ; flag=-1, dy=0, dx=-7
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH139:    ; Path 139
    FCB 127              ; path139: intensity
    FCB $30,$43,0,0        ; path139: header (y=48, x=67, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH140:    ; Path 140
    FCB 127              ; path140: intensity
    FCB $30,$3E,0,0        ; path140: header (y=48, x=62, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH141:    ; Path 141
    FCB 127              ; path141: intensity
    FCB $33,$49,0,0        ; path141: header (y=51, x=73, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH142:    ; Path 142
    FCB 127              ; path142: intensity
    FCB $33,$3E,0,0        ; path142: header (y=51, x=62, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH143:    ; Path 143
    FCB 127              ; path143: intensity
    FCB $30,$43,0,0        ; path143: header (y=48, x=67, relative to center)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH144:    ; Path 144
    FCB 127              ; path144: intensity
    FCB $30,$3E,0,0        ; path144: header (y=48, x=62, relative to center)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH145:    ; Path 145
    FCB 127              ; path145: intensity
    FCB $07,$47,0,0        ; path145: header (y=7, x=71, relative to center)
    FCB $FF,$F0,$00          ; flag=-1, dy=-16, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH146:    ; Path 146
    FCB 127              ; path146: intensity
    FCB $F7,$3A,0,0        ; path146: header (y=-9, x=58, relative to center)
    FCB $FF,$10,$00          ; flag=-1, dy=16, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH147:    ; Path 147
    FCB 127              ; path147: intensity
    FCB $04,$44,0,0        ; path147: header (y=4, x=68, relative to center)
    FCB $FF,$00,$F9          ; flag=-1, dy=0, dx=-7
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH148:    ; Path 148
    FCB 127              ; path148: intensity
    FCB $07,$44,0,0        ; path148: header (y=7, x=68, relative to center)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$02,$FD          ; flag=-1, dy=2, dx=-3
    FCB $FF,$FE,$FD          ; flag=-1, dy=-2, dx=-3
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH149:    ; Path 149
    FCB 127              ; path149: intensity
    FCB $E3,$1B,0,0        ; path149: header (y=-29, x=27, relative to center)
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH150:    ; Path 150
    FCB 127              ; path150: intensity
    FCB $EC,$0B,0,0        ; path150: header (y=-20, x=11, relative to center)
    FCB $FF,$EE,$00          ; flag=-1, dy=-18, dx=0
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH151:    ; Path 151
    FCB 127              ; path151: intensity
    FCB $F3,$04,0,0        ; path151: header (y=-13, x=4, relative to center)
    FCB $FF,$FC,$03          ; flag=-1, dy=-4, dx=3
    FCB $FF,$E9,$00          ; flag=-1, dy=-23, dx=0
    FCB $FF,$00,$F9          ; flag=-1, dy=0, dx=-7
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH152:    ; Path 152
    FCB 127              ; path152: intensity
    FCB $F3,$04,0,0        ; path152: header (y=-13, x=4, relative to center)
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH153:    ; Path 153
    FCB 127              ; path153: intensity
    FCB $F2,$57,0,0        ; path153: header (y=-14, x=87, relative to center)
    FCB $FF,$00,$B6          ; flag=-1, dy=0, dx=-74
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH154:    ; Path 154
    FCB 127              ; path154: intensity
    FCB $D0,$14,0,0        ; path154: header (y=-48, x=20, relative to center)
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB $FF,$00,$F5          ; flag=-1, dy=0, dx=-11
    FCB $FF,$0E,$00          ; flag=-1, dy=14, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH155:    ; Path 155
    FCB 127              ; path155: intensity
    FCB $D4,$09,0,0        ; path155: header (y=-44, x=9, relative to center)
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH156:    ; Path 156
    FCB 127              ; path156: intensity
    FCB $D1,$00,0,0        ; path156: header (y=-47, x=0, relative to center)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH157:    ; Path 157
    FCB 127              ; path157: intensity
    FCB $CC,$0C,0,0        ; path157: header (y=-52, x=12, relative to center)
    FCB $FF,$00,$F4          ; flag=-1, dy=0, dx=-12
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH158:    ; Path 158
    FCB 127              ; path158: intensity
    FCB $C7,$00,0,0        ; path158: header (y=-57, x=0, relative to center)
    FCB $FF,$00,$0D          ; flag=-1, dy=0, dx=13
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH159:    ; Path 159
    FCB 127              ; path159: intensity
    FCB $C0,$0E,0,0        ; path159: header (y=-64, x=14, relative to center)
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH160:    ; Path 160
    FCB 127              ; path160: intensity
    FCB $FD,$0B,0,0        ; path160: header (y=-3, x=11, relative to center)
    FCB $FF,$00,$1D          ; flag=-1, dy=0, dx=29
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$00,$E3          ; flag=-1, dy=0, dx=-29
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH161:    ; Path 161
    FCB 127              ; path161: intensity
    FCB $FD,$0B,0,0        ; path161: header (y=-3, x=11, relative to center)
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH162:    ; Path 162
    FCB 127              ; path162: intensity
    FCB $07,$32,0,0        ; path162: header (y=7, x=50, relative to center)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$D3          ; flag=-1, dy=0, dx=-45
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH163:    ; Path 163
    FCB 127              ; path163: intensity
    FCB $F4,$00,0,0        ; path163: header (y=-12, x=0, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH164:    ; Path 164
    FCB 127              ; path164: intensity
    FCB $FC,$00,0,0        ; path164: header (y=-4, x=0, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH165:    ; Path 165
    FCB 127              ; path165: intensity
    FCB $D0,$F2,0,0        ; path165: header (y=-48, x=-14, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH166:    ; Path 166
    FCB 127              ; path166: intensity
    FCB $C1,$F1,0,0        ; path166: header (y=-63, x=-15, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH167:    ; Path 167
    FCB 127              ; path167: intensity
    FCB $01,$0B,0,0        ; path167: header (y=1, x=11, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH168:    ; Path 168
    FCB 127              ; path168: intensity
    FCB $06,$10,0,0        ; path168: header (y=6, x=16, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH169:    ; Path 169
    FCB 127              ; path169: intensity
    FCB $0C,$06,0,0        ; path169: header (y=12, x=6, relative to center)
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH170:    ; Path 170
    FCB 127              ; path170: intensity
    FCB $12,$06,0,0        ; path170: header (y=18, x=6, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH171:    ; Path 171
    FCB 127              ; path171: intensity
    FCB $0C,$06,0,0        ; path171: header (y=12, x=6, relative to center)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FF,$FF          ; flag=-1, dy=-1, dx=-1
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH172:    ; Path 172
    FCB 127              ; path172: intensity
    FCB $10,$0B,0,0        ; path172: header (y=16, x=11, relative to center)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$03,$03          ; flag=-1, dy=3, dx=3
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH173:    ; Path 173
    FCB 127              ; path173: intensity
    FCB $10,$08,0,0        ; path173: header (y=16, x=8, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH174:    ; Path 174
    FCB 127              ; path174: intensity
    FCB $18,$0E,0,0        ; path174: header (y=24, x=14, relative to center)
    FCB $FF,$02,$FB          ; flag=-1, dy=2, dx=-5
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH175:    ; Path 175
    FCB 127              ; path175: intensity
    FCB $1A,$07,0,0        ; path175: header (y=26, x=7, relative to center)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$FF,$06          ; flag=-1, dy=-1, dx=6
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH176:    ; Path 176
    FCB 127              ; path176: intensity
    FCB $21,$0D,0,0        ; path176: header (y=33, x=13, relative to center)
    FCB $FF,$FC,$FD          ; flag=-1, dy=-4, dx=-3
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH177:    ; Path 177
    FCB 127              ; path177: intensity
    FCB $22,$07,0,0        ; path177: header (y=34, x=7, relative to center)
    FCB $FF,$00,$F9          ; flag=-1, dy=0, dx=-7
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH178:    ; Path 178
    FCB 127              ; path178: intensity
    FCB $22,$05,0,0        ; path178: header (y=34, x=5, relative to center)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH179:    ; Path 179
    FCB 127              ; path179: intensity
    FCB $2A,$04,0,0        ; path179: header (y=42, x=4, relative to center)
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH180:    ; Path 180
    FCB 127              ; path180: intensity
    FCB $31,$04,0,0        ; path180: header (y=49, x=4, relative to center)
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH181:    ; Path 181
    FCB 127              ; path181: intensity
    FCB $30,$08,0,0        ; path181: header (y=48, x=8, relative to center)
    FCB $FF,$FD,$FE          ; flag=-1, dy=-3, dx=-2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH182:    ; Path 182
    FCB 127              ; path182: intensity
    FCB $2A,$05,0,0        ; path182: header (y=42, x=5, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FE,$04          ; flag=-1, dy=-2, dx=4
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH183:    ; Path 183
    FCB 127              ; path183: intensity
    FCB $28,$0B,0,0        ; path183: header (y=40, x=11, relative to center)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH184:    ; Path 184
    FCB 127              ; path184: intensity
    FCB $31,$06,0,0        ; path184: header (y=49, x=6, relative to center)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH185:    ; Path 185
    FCB 127              ; path185: intensity
    FCB $36,$05,0,0        ; path185: header (y=54, x=5, relative to center)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH186:    ; Path 186
    FCB 127              ; path186: intensity
    FCB $3A,$03,0,0        ; path186: header (y=58, x=3, relative to center)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH187:    ; Path 187
    FCB 127              ; path187: intensity
    FCB $3D,$02,0,0        ; path187: header (y=61, x=2, relative to center)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH188:    ; Path 188
    FCB 127              ; path188: intensity
    FCB $11,$03,0,0        ; path188: header (y=17, x=3, relative to center)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH189:    ; Path 189
    FCB 127              ; path189: intensity
    FCB $06,$0B,0,0        ; path189: header (y=6, x=11, relative to center)
    FCB $FF,$01,$FF          ; flag=-1, dy=1, dx=-1
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH190:    ; Path 190
    FCB 127              ; path190: intensity
    FCB $01,$0B,0,0        ; path190: header (y=1, x=11, relative to center)
    FCB $FF,$00,$F5          ; flag=-1, dy=0, dx=-11
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH191:    ; Path 191
    FCB 127              ; path191: intensity
    FCB $F2,$0A,0,0        ; path191: header (y=-14, x=10, relative to center)
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$03,$FC          ; flag=-1, dy=3, dx=-4
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)
; Generated from antarctica_bg.vec (Malban Draw_Sync_List format)
; Total paths: 20, points: 91
; X bounds: min=-119, max=104, width=223
; Center: (-7, 46)

_ANTARCTICA_BG_WIDTH EQU 223
_ANTARCTICA_BG_HALF_WIDTH EQU 111
_ANTARCTICA_BG_CENTER_X EQU -7
_ANTARCTICA_BG_CENTER_Y EQU 46

_ANTARCTICA_BG_VECTORS:  ; Main entry (header + 20 path(s))
    FCB 20               ; path_count (runtime metadata)
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
    FDB _ANTARCTICA_BG_PATH17        ; pointer to path 17
    FDB _ANTARCTICA_BG_PATH18        ; pointer to path 18
    FDB _ANTARCTICA_BG_PATH19        ; pointer to path 19

_ANTARCTICA_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $D3,$90,0,0        ; path0: header (y=-45, x=-112, relative to center)
    FCB $FF,$00,$4C          ; sub-seg 1/2 of line 0: dy=0, dx=76
    FCB $FF,$00,$4D          ; sub-seg 2/2 of line 0: dy=0, dx=77
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $D3,$29,0,0        ; path1: header (y=-45, x=41, relative to center)
    FCB $FF,$41,$D5          ; flag=-1, dy=65, dx=-43
    FCB $FF,$FA,$F9          ; flag=-1, dy=-6, dx=-7
    FCB $FF,$21,$E4          ; flag=-1, dy=33, dx=-28
    FCB $FF,$DF,$E7          ; flag=-1, dy=-33, dx=-25
    FCB $FF,$07,$F7          ; flag=-1, dy=7, dx=-9
    FCB $FF,$BE,$D7          ; flag=-1, dy=-66, dx=-41
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $E6,$9C,0,0        ; path2: header (y=-26, x=-100, relative to center)
    FCB $FF,$03,$21          ; flag=-1, dy=3, dx=33
    FCB $FF,$17,$22          ; flag=-1, dy=23, dx=34
    FCB $FF,$F6,$16          ; flag=-1, dy=-10, dx=22
    FCB $FF,$F9,$08          ; flag=-1, dy=-7, dx=8
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $D3,$D6,0,0        ; path3: header (y=-45, x=-42, relative to center)
    FCB $FF,$0F,$05          ; flag=-1, dy=15, dx=5
    FCB $FF,$10,$2A          ; flag=-1, dy=16, dx=42
    FCB $FF,$F7,$15          ; flag=-1, dy=-9, dx=21
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $F7,$F3,0,0        ; path4: header (y=-9, x=-13, relative to center)
    FCB $FF,$13,$FB          ; flag=-1, dy=19, dx=-5
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB $FF,$0F,$F8          ; flag=-1, dy=15, dx=-8
    FCB $FF,$02,$EF          ; flag=-1, dy=2, dx=-17
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $D9,$33,0,0        ; path5: header (y=-39, x=51, relative to center)
    FCB $FF,$09,$06          ; flag=-1, dy=9, dx=6
    FCB $FF,$02,$05          ; flag=-1, dy=2, dx=5
    FCB $FF,$FA,$06          ; flag=-1, dy=-6, dx=6
    FCB $FF,$F4,$01          ; flag=-1, dy=-12, dx=1
    FCB $FF,$02,$FD          ; flag=-1, dy=2, dx=-3
    FCB $FF,$06,$FF          ; flag=-1, dy=6, dx=-1
    FCB $FF,$06,$FD          ; flag=-1, dy=6, dx=-3
    FCB $FF,$FE,$FB          ; flag=-1, dy=-2, dx=-5
    FCB $FF,$FA,$FC          ; flag=-1, dy=-6, dx=-4
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $D9,$33,0,0        ; path6: header (y=-39, x=51, relative to center)
    FCB $FF,$F9,$12          ; flag=-1, dy=-7, dx=18
    FCB $FF,$04,$07          ; flag=-1, dy=4, dx=7
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$00,$0D          ; flag=-1, dy=0, dx=13
    FCB $FF,$01,$0A          ; flag=-1, dy=1, dx=10
    FCB $FF,$03,$08          ; flag=-1, dy=3, dx=8
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $DA,$6F,0,0        ; path7: header (y=-38, x=111, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$0A,$FB          ; flag=-1, dy=10, dx=-5
    FCB $FF,$06,$FC          ; flag=-1, dy=6, dx=-4
    FCB $FF,$04,$F8          ; flag=-1, dy=4, dx=-8
    FCB $FF,$01,$F9          ; flag=-1, dy=1, dx=-7
    FCB $FF,$FF,$F5          ; flag=-1, dy=-1, dx=-11
    FCB $FF,$FB,$F9          ; flag=-1, dy=-5, dx=-7
    FCB $FF,$FB,$FB          ; flag=-1, dy=-5, dx=-5
    FCB $FF,$FA,$FC          ; flag=-1, dy=-6, dx=-4
    FCB $FF,$FA,$FD          ; flag=-1, dy=-6, dx=-3
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $D6,$4C,0,0        ; path8: header (y=-42, x=76, relative to center)
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB $FF,$06,$FE          ; flag=-1, dy=6, dx=-2
    FCB $FF,$03,$FD          ; flag=-1, dy=3, dx=-3
    FCB $FF,$FE,$F7          ; flag=-1, dy=-2, dx=-9
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $EC,$3F,0,0        ; path9: header (y=-20, x=63, relative to center)
    FCB $FF,$FF,$08          ; flag=-1, dy=-1, dx=8
    FCB $FF,$00,$0D          ; flag=-1, dy=0, dx=13
    FCB $FF,$02,$0B          ; flag=-1, dy=2, dx=11
    FCB $FF,$02,$0A          ; flag=-1, dy=2, dx=10
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $F6,$49,0,0        ; path10: header (y=-10, x=73, relative to center)
    FCB $FF,$FF,$09          ; flag=-1, dy=-1, dx=9
    FCB $FF,$01,$08          ; flag=-1, dy=1, dx=8
    FCB $FF,$01,$06          ; flag=-1, dy=1, dx=6
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $E0,$4B,0,0        ; path11: header (y=-32, x=75, relative to center)
    FCB $FF,$01,$0B          ; flag=-1, dy=1, dx=11
    FCB $FF,$02,$15          ; flag=-1, dy=2, dx=21
    FCB $FF,$01,$04          ; flag=-1, dy=1, dx=4
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $F5,$52,0,0        ; path12: header (y=-11, x=82, relative to center)
    FCB $FF,$F6,$FF          ; flag=-1, dy=-10, dx=-1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $F6,$5B,0,0        ; path13: header (y=-10, x=91, relative to center)
    FCB $FF,$F8,$07          ; flag=-1, dy=-8, dx=7
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $EC,$59,0,0        ; path14: header (y=-20, x=89, relative to center)
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $E2,$60,0,0        ; path15: header (y=-30, x=96, relative to center)
    FCB $FF,$F5,$05          ; flag=-1, dy=-11, dx=5
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $E1,$53,0,0        ; path16: header (y=-31, x=83, relative to center)
    FCB $FF,$F5,$FE          ; flag=-1, dy=-11, dx=-2
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $EB,$49,0,0        ; path17: header (y=-21, x=73, relative to center)
    FCB $FF,$FB,$FE          ; flag=-1, dy=-5, dx=-2
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH18:    ; Path 18
    FCB 127              ; path18: intensity
    FCB $EE,$65,0,0        ; path18: header (y=-18, x=101, relative to center)
    FCB $FF,$F5,$06          ; flag=-1, dy=-11, dx=6
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH19:    ; Path 19
    FCB 127              ; path19: intensity
    FCB $E1,$58,0,0        ; path19: header (y=-31, x=88, relative to center)
    FCB $FF,$0B,$01          ; flag=-1, dy=11, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)
; Generated from athens_bg.vec (Malban Draw_Sync_List format)
; Total paths: 41, points: 147
; X bounds: min=-80, max=80, width=160
; Center: (0, 0)

_ATHENS_BG_WIDTH EQU 160
_ATHENS_BG_HALF_WIDTH EQU 80
_ATHENS_BG_CENTER_X EQU 0
_ATHENS_BG_CENTER_Y EQU 0

_ATHENS_BG_VECTORS:  ; Main entry (header + 41 path(s))
    FCB 41               ; path_count (runtime metadata)
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
    FDB _ATHENS_BG_PATH33        ; pointer to path 33
    FDB _ATHENS_BG_PATH34        ; pointer to path 34
    FDB _ATHENS_BG_PATH35        ; pointer to path 35
    FDB _ATHENS_BG_PATH36        ; pointer to path 36
    FDB _ATHENS_BG_PATH37        ; pointer to path 37
    FDB _ATHENS_BG_PATH38        ; pointer to path 38
    FDB _ATHENS_BG_PATH39        ; pointer to path 39
    FDB _ATHENS_BG_PATH40        ; pointer to path 40

_ATHENS_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $26,$C1,0,0        ; path0: header (y=38, x=-63, relative to center)
    FCB $FF,$25,$3E          ; flag=-1, dy=37, dx=62
    FCB $FF,$DB,$3F          ; flag=-1, dy=-37, dx=63
    FCB $FF,$00,$83          ; flag=-1, dy=0, dx=-125
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $29,$D2,0,0        ; path1: header (y=41, x=-46, relative to center)
    FCB $FF,$1C,$2D          ; flag=-1, dy=28, dx=45
    FCB $FF,$E4,$2F          ; flag=-1, dy=-28, dx=47
    FCB $FF,$00,$A4          ; flag=-1, dy=0, dx=-92
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $26,$38,0,0        ; path2: header (y=38, x=56, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $26,$3B,0,0        ; path3: header (y=38, x=59, relative to center)
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB $FF,$00,$88          ; flag=-1, dy=0, dx=-120
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $1F,$C6,0,0        ; path4: header (y=31, x=-58, relative to center)
    FCB $FF,$F5,$00          ; flag=-1, dy=-11, dx=0
    FCB $FF,$00,$72          ; flag=-1, dy=0, dx=114
    FCB $FF,$0B,$00          ; flag=-1, dy=11, dx=0
    FCB $FF,$00,$01          ; flag=-1, dy=0, dx=1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $14,$C6,0,0        ; path5: header (y=20, x=-58, relative to center)
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$00,$7A          ; flag=-1, dy=0, dx=122
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $0F,$C8,0,0        ; path6: header (y=15, x=-56, relative to center)
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $0C,$CA,0,0        ; path7: header (y=12, x=-54, relative to center)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $0A,$CB,0,0        ; path8: header (y=10, x=-53, relative to center)
    FCB $FF,$C5,$00          ; flag=-1, dy=-59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $0A,$D5,0,0        ; path9: header (y=10, x=-43, relative to center)
    FCB $FF,$C5,$00          ; flag=-1, dy=-59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $CA,$C8,0,0        ; path10: header (y=-54, x=-56, relative to center)
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $CD,$CA,0,0        ; path11: header (y=-51, x=-54, relative to center)
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $CF,$CB,0,0        ; path12: header (y=-49, x=-53, relative to center)
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $CF,$D5,0,0        ; path13: header (y=-49, x=-43, relative to center)
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $0F,$E0,0,0        ; path14: header (y=15, x=-32, relative to center)
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $0C,$E2,0,0        ; path15: header (y=12, x=-30, relative to center)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $0A,$E3,0,0        ; path16: header (y=10, x=-29, relative to center)
    FCB $FF,$C5,$00          ; flag=-1, dy=-59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $0A,$ED,0,0        ; path17: header (y=10, x=-19, relative to center)
    FCB $FF,$C5,$00          ; flag=-1, dy=-59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH18:    ; Path 18
    FCB 127              ; path18: intensity
    FCB $CA,$E0,0,0        ; path18: header (y=-54, x=-32, relative to center)
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH19:    ; Path 19
    FCB 127              ; path19: intensity
    FCB $CD,$E2,0,0        ; path19: header (y=-51, x=-30, relative to center)
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH20:    ; Path 20
    FCB 127              ; path20: intensity
    FCB $CF,$E3,0,0        ; path20: header (y=-49, x=-29, relative to center)
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH21:    ; Path 21
    FCB 127              ; path21: intensity
    FCB $CF,$ED,0,0        ; path21: header (y=-49, x=-19, relative to center)
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH22:    ; Path 22
    FCB 127              ; path22: intensity
    FCB $0F,$12,0,0        ; path22: header (y=15, x=18, relative to center)
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH23:    ; Path 23
    FCB 127              ; path23: intensity
    FCB $0C,$14,0,0        ; path23: header (y=12, x=20, relative to center)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH24:    ; Path 24
    FCB 127              ; path24: intensity
    FCB $0A,$15,0,0        ; path24: header (y=10, x=21, relative to center)
    FCB $FF,$C5,$00          ; flag=-1, dy=-59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH25:    ; Path 25
    FCB 127              ; path25: intensity
    FCB $0A,$1F,0,0        ; path25: header (y=10, x=31, relative to center)
    FCB $FF,$C5,$00          ; flag=-1, dy=-59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH26:    ; Path 26
    FCB 127              ; path26: intensity
    FCB $CA,$12,0,0        ; path26: header (y=-54, x=18, relative to center)
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH27:    ; Path 27
    FCB 127              ; path27: intensity
    FCB $CD,$14,0,0        ; path27: header (y=-51, x=20, relative to center)
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH28:    ; Path 28
    FCB 127              ; path28: intensity
    FCB $CF,$15,0,0        ; path28: header (y=-49, x=21, relative to center)
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH29:    ; Path 29
    FCB 127              ; path29: intensity
    FCB $CF,$1F,0,0        ; path29: header (y=-49, x=31, relative to center)
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH30:    ; Path 30
    FCB 127              ; path30: intensity
    FCB $0F,$26,0,0        ; path30: header (y=15, x=38, relative to center)
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH31:    ; Path 31
    FCB 127              ; path31: intensity
    FCB $0C,$28,0,0        ; path31: header (y=12, x=40, relative to center)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH32:    ; Path 32
    FCB 127              ; path32: intensity
    FCB $0A,$29,0,0        ; path32: header (y=10, x=41, relative to center)
    FCB $FF,$C5,$00          ; flag=-1, dy=-59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH33:    ; Path 33
    FCB 127              ; path33: intensity
    FCB $0A,$33,0,0        ; path33: header (y=10, x=51, relative to center)
    FCB $FF,$C5,$00          ; flag=-1, dy=-59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH34:    ; Path 34
    FCB 127              ; path34: intensity
    FCB $CA,$26,0,0        ; path34: header (y=-54, x=38, relative to center)
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH35:    ; Path 35
    FCB 127              ; path35: intensity
    FCB $CD,$28,0,0        ; path35: header (y=-51, x=40, relative to center)
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH36:    ; Path 36
    FCB 127              ; path36: intensity
    FCB $CF,$29,0,0        ; path36: header (y=-49, x=41, relative to center)
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH37:    ; Path 37
    FCB 127              ; path37: intensity
    FCB $CF,$33,0,0        ; path37: header (y=-49, x=51, relative to center)
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH38:    ; Path 38
    FCB 127              ; path38: intensity
    FCB $B5,$B0,0,0        ; path38: header (y=-75, x=-80, relative to center)
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB $FF,$00,$50          ; sub-seg 1/2 of line 1: dy=0, dx=80
    FCB $FF,$00,$50          ; sub-seg 2/2 of line 1: dy=0, dx=80
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB $FF,$00,$B0          ; sub-seg 1/2 of line 3: dy=0, dx=-80
    FCB $FF,$00,$B0          ; sub-seg 2/2 of line 3: dy=0, dx=-80
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH39:    ; Path 39
    FCB 127              ; path39: intensity
    FCB $BC,$B7,0,0        ; path39: header (y=-68, x=-73, relative to center)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$49          ; sub-seg 1/2 of line 1: dy=0, dx=73
    FCB $FF,$00,$49          ; sub-seg 2/2 of line 1: dy=0, dx=73
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH40:    ; Path 40
    FCB 127              ; path40: intensity
    FCB $C4,$44,0,0        ; path40: header (y=-60, x=68, relative to center)
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$BD          ; sub-seg 1/2 of line 1: dy=0, dx=-67
    FCB $FF,$00,$BC          ; sub-seg 2/2 of line 1: dy=0, dx=-68
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)
; Generated from ayers_bg.vec (Malban Draw_Sync_List format)
; Total paths: 18, points: 106
; X bounds: min=-96, max=102, width=198
; Center: (3, 10)

_AYERS_BG_WIDTH EQU 198
_AYERS_BG_HALF_WIDTH EQU 99
_AYERS_BG_CENTER_X EQU 3
_AYERS_BG_CENTER_Y EQU 10

_AYERS_BG_VECTORS:  ; Main entry (header + 18 path(s))
    FCB 18               ; path_count (runtime metadata)
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
    FDB _AYERS_BG_PATH17        ; pointer to path 17

_AYERS_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $E2,$9D,0,0        ; path0: header (y=-30, x=-99, relative to center)
    FCB $FF,$2A,$0C          ; flag=-1, dy=42, dx=12
    FCB $FF,$05,$0D          ; flag=-1, dy=5, dx=13
    FCB $FF,$04,$0F          ; flag=-1, dy=4, dx=15
    FCB $FF,$03,$0F          ; flag=-1, dy=3, dx=15
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
    FCB $FF,$00,$9D          ; sub-seg 1/2 of line 16: dy=0, dx=-99
    FCB $FF,$01,$9D          ; sub-seg 2/2 of line 16: dy=1, dx=-99
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $11,$B6,0,0        ; path1: header (y=17, x=-74, relative to center)
    FCB $FF,$EA,$F9          ; flag=-1, dy=-22, dx=-7
    FCB $FF,$E7,$F8          ; flag=-1, dy=-25, dx=-8
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $E2,$BB,0,0        ; path2: header (y=-30, x=-69, relative to center)
    FCB $FF,$1C,$02          ; flag=-1, dy=28, dx=2
    FCB $FF,$08,$06          ; flag=-1, dy=8, dx=6
    FCB $FF,$F5,$FF          ; flag=-1, dy=-11, dx=-1
    FCB $FF,$E7,$FC          ; flag=-1, dy=-25, dx=-4
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $19,$E9,0,0        ; path3: header (y=25, x=-23, relative to center)
    FCB $FF,$EF,$FD          ; flag=-1, dy=-17, dx=-3
    FCB $FF,$F2,$03          ; flag=-1, dy=-14, dx=3
    FCB $FF,$F5,$00          ; flag=-1, dy=-11, dx=0
    FCB $FF,$09,$05          ; flag=-1, dy=9, dx=5
    FCB $FF,$0C,$06          ; flag=-1, dy=12, dx=6
    FCB $FF,$18,$06          ; flag=-1, dy=24, dx=6
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $1A,$F0,0,0        ; path4: header (y=26, x=-16, relative to center)
    FCB $FF,$EF,$FA          ; flag=-1, dy=-17, dx=-6
    FCB $FF,$F6,$03          ; flag=-1, dy=-10, dx=3
    FCB $FF,$09,$04          ; flag=-1, dy=9, dx=4
    FCB $FF,$13,$06          ; flag=-1, dy=19, dx=6
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $E2,$C4,0,0        ; path5: header (y=-30, x=-60, relative to center)
    FCB $FF,$16,$08          ; flag=-1, dy=22, dx=8
    FCB $FF,$20,$07          ; flag=-1, dy=32, dx=7
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $19,$D6,0,0        ; path6: header (y=25, x=-42, relative to center)
    FCB $FF,$E9,$FB          ; flag=-1, dy=-23, dx=-5
    FCB $FF,$EE,$FD          ; flag=-1, dy=-18, dx=-3
    FCB $FF,$F2,$01          ; flag=-1, dy=-14, dx=1
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $20,$07,0,0        ; path7: header (y=32, x=7, relative to center)
    FCB $FF,$F0,$02          ; flag=-1, dy=-16, dx=2
    FCB $FF,$F2,$FA          ; flag=-1, dy=-14, dx=-6
    FCB $FF,$EF,$01          ; flag=-1, dy=-17, dx=1
    FCB $FF,$0B,$03          ; flag=-1, dy=11, dx=3
    FCB $FF,$0E,$04          ; flag=-1, dy=14, dx=4
    FCB $FF,$13,$07          ; flag=-1, dy=19, dx=7
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $19,$1F,0,0        ; path8: header (y=25, x=31, relative to center)
    FCB $FF,$EB,$0A          ; flag=-1, dy=-21, dx=10
    FCB $FF,$E6,$01          ; flag=-1, dy=-26, dx=1
    FCB $FF,$F7,$FF          ; flag=-1, dy=-9, dx=-1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $E1,$25,0,0        ; path9: header (y=-31, x=37, relative to center)
    FCB $FF,$08,$F9          ; flag=-1, dy=8, dx=-7
    FCB $FF,$1A,$FC          ; flag=-1, dy=26, dx=-4
    FCB $FF,$E6,$FE          ; flag=-1, dy=-26, dx=-2
    FCB $FF,$F9,$F9          ; flag=-1, dy=-7, dx=-7
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $E2,$0A,0,0        ; path10: header (y=-30, x=10, relative to center)
    FCB $FF,$12,$01          ; flag=-1, dy=18, dx=1
    FCB $FF,$13,$06          ; flag=-1, dy=19, dx=6
    FCB $FF,$F1,$FF          ; flag=-1, dy=-15, dx=-1
    FCB $FF,$EA,$00          ; flag=-1, dy=-22, dx=0
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $E1,$07,0,0        ; path11: header (y=-31, x=7, relative to center)
    FCB $FF,$06,$F8          ; flag=-1, dy=6, dx=-8
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB $FF,$13,$FC          ; flag=-1, dy=19, dx=-4
    FCB $FF,$F6,$FE          ; flag=-1, dy=-10, dx=-2
    FCB $FF,$F6,$01          ; flag=-1, dy=-10, dx=1
    FCB $FF,$00,$F3          ; flag=-1, dy=0, dx=-13
    FCB $FF,$03,$FD          ; flag=-1, dy=3, dx=-3
    FCB $FF,$FA,$FC          ; flag=-1, dy=-6, dx=-4
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $E4,$E3,0,0        ; path12: header (y=-28, x=-29, relative to center)
    FCB $FF,$04,$F5          ; flag=-1, dy=4, dx=-11
    FCB $FF,$20,$05          ; flag=-1, dy=32, dx=5
    FCB $FF,$F9,$FA          ; flag=-1, dy=-7, dx=-6
    FCB $FF,$EF,$FE          ; flag=-1, dy=-17, dx=-2
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$FD,$FA          ; flag=-1, dy=-3, dx=-6
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $07,$2C,0,0        ; path13: header (y=7, x=44, relative to center)
    FCB $FF,$DB,$03          ; flag=-1, dy=-37, dx=3
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $E1,$3C,0,0        ; path14: header (y=-31, x=60, relative to center)
    FCB $FF,$1A,$FE          ; flag=-1, dy=26, dx=-2
    FCB $FF,$1B,$FE          ; flag=-1, dy=27, dx=-2
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $E1,$4C,0,0        ; path15: header (y=-31, x=76, relative to center)
    FCB $FF,$15,$FC          ; flag=-1, dy=21, dx=-4
    FCB $FF,$03,$FD          ; flag=-1, dy=3, dx=-3
    FCB $FF,$10,$FE          ; flag=-1, dy=16, dx=-2
    FCB $FF,$EE,$FE          ; flag=-1, dy=-18, dx=-2
    FCB $FF,$1F,$F7          ; flag=-1, dy=31, dx=-9
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $E1,$53,0,0        ; path16: header (y=-31, x=83, relative to center)
    FCB $FF,$23,$F7          ; flag=-1, dy=35, dx=-9
    FCB $FF,$E2,$0D          ; flag=-1, dy=-30, dx=13
    FCB $FF,$1A,$FB          ; flag=-1, dy=26, dx=-5
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $06,$2C,0,0        ; path17: header (y=6, x=44, relative to center)
    FCB $FF,$13,$F7          ; flag=-1, dy=19, dx=-9
    FCB 2                ; End marker (path complete)
; Generated from barcelona_bg.vec (Malban Draw_Sync_List format)
; Total paths: 60, points: 193
; X bounds: min=-47, max=69, width=116
; Center: (11, 13)

_BARCELONA_BG_WIDTH EQU 116
_BARCELONA_BG_HALF_WIDTH EQU 58
_BARCELONA_BG_CENTER_X EQU 11
_BARCELONA_BG_CENTER_Y EQU 13

_BARCELONA_BG_VECTORS:  ; Main entry (header + 60 path(s))
    FCB 60               ; path_count (runtime metadata)
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
    FDB _BARCELONA_BG_PATH44        ; pointer to path 44
    FDB _BARCELONA_BG_PATH45        ; pointer to path 45
    FDB _BARCELONA_BG_PATH46        ; pointer to path 46
    FDB _BARCELONA_BG_PATH47        ; pointer to path 47
    FDB _BARCELONA_BG_PATH48        ; pointer to path 48
    FDB _BARCELONA_BG_PATH49        ; pointer to path 49
    FDB _BARCELONA_BG_PATH50        ; pointer to path 50
    FDB _BARCELONA_BG_PATH51        ; pointer to path 51
    FDB _BARCELONA_BG_PATH52        ; pointer to path 52
    FDB _BARCELONA_BG_PATH53        ; pointer to path 53
    FDB _BARCELONA_BG_PATH54        ; pointer to path 54
    FDB _BARCELONA_BG_PATH55        ; pointer to path 55
    FDB _BARCELONA_BG_PATH56        ; pointer to path 56
    FDB _BARCELONA_BG_PATH57        ; pointer to path 57
    FDB _BARCELONA_BG_PATH58        ; pointer to path 58
    FDB _BARCELONA_BG_PATH59        ; pointer to path 59

_BARCELONA_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $C0,$C6,0,0        ; path0: header (y=-64, x=-58, relative to center)
    FCB $FF,$0D,$05          ; flag=-1, dy=13, dx=5
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$14,$2A          ; flag=-1, dy=20, dx=42
    FCB $FF,$EB,$2B          ; flag=-1, dy=-21, dx=43
    FCB $FF,$FD,$FD          ; flag=-1, dy=-3, dx=-3
    FCB $FF,$F3,$06          ; flag=-1, dy=-13, dx=6
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $C0,$CA,0,0        ; path1: header (y=-64, x=-54, relative to center)
    FCB $FF,$14,$07          ; flag=-1, dy=20, dx=7
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$EC,$FA          ; flag=-1, dy=-20, dx=-6
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $C0,$D4,0,0        ; path2: header (y=-64, x=-44, relative to center)
    FCB $FF,$18,$08          ; flag=-1, dy=24, dx=8
    FCB $FF,$01,$09          ; flag=-1, dy=1, dx=9
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $C1,$05,0,0        ; path3: header (y=-63, x=5, relative to center)
    FCB $FF,$18,$F9          ; flag=-1, dy=24, dx=-7
    FCB $FF,$0A,$F7          ; flag=-1, dy=10, dx=-9
    FCB $FF,$F6,$F5          ; flag=-1, dy=-10, dx=-11
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $C0,$F0,0,0        ; path4: header (y=-64, x=-16, relative to center)
    FCB $FF,$0C,$01          ; flag=-1, dy=12, dx=1
    FCB $FF,$01,$04          ; flag=-1, dy=1, dx=4
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $CC,$F9,0,0        ; path5: header (y=-52, x=-7, relative to center)
    FCB $FF,$F5,$01          ; flag=-1, dy=-11, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $D9,$EA,0,0        ; path6: header (y=-39, x=-22, relative to center)
    FCB $FF,$E7,$F9          ; flag=-1, dy=-25, dx=-7
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $D9,$E5,0,0        ; path7: header (y=-39, x=-27, relative to center)
    FCB $FF,$E7,$FC          ; flag=-1, dy=-25, dx=-4
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $C1,$3A,0,0        ; path8: header (y=-63, x=58, relative to center)
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $C1,$09,0,0        ; path9: header (y=-63, x=9, relative to center)
    FCB $FF,$11,$FC          ; flag=-1, dy=17, dx=-4
    FCB $FF,$08,$FF          ; flag=-1, dy=8, dx=-1
    FCB $FF,$FF,$09          ; flag=-1, dy=-1, dx=9
    FCB $FF,$E8,$07          ; flag=-1, dy=-24, dx=7
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $C1,$16,0,0        ; path10: header (y=-63, x=22, relative to center)
    FCB $FF,$13,$FD          ; flag=-1, dy=19, dx=-3
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$ED,$0A          ; flag=-1, dy=-19, dx=10
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $D5,$CD,0,0        ; path11: header (y=-43, x=-51, relative to center)
    FCB $FF,$16,$28          ; flag=-1, dy=22, dx=40
    FCB $FF,$EA,$27          ; flag=-1, dy=-22, dx=39
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $EB,$F5,0,0        ; path12: header (y=-21, x=-11, relative to center)
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $D8,$CF,0,0        ; path13: header (y=-40, x=-49, relative to center)
    FCB $FF,$0B,$02          ; flag=-1, dy=11, dx=2
    FCB $FF,$12,$24          ; flag=-1, dy=18, dx=36
    FCB $FF,$EE,$24          ; flag=-1, dy=-18, dx=36
    FCB $FF,$F4,$01          ; flag=-1, dy=-12, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $E4,$D3,0,0        ; path14: header (y=-28, x=-45, relative to center)
    FCB $FF,$3A,$08          ; flag=-1, dy=58, dx=8
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$0F,$03          ; flag=-1, dy=15, dx=3
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$F2,$02          ; flag=-1, dy=-14, dx=2
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$CB,$00          ; flag=-1, dy=-53, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $EA,$E0,0,0        ; path15: header (y=-22, x=-32, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$40,$06          ; flag=-1, dy=64, dx=6
    FCB $FF,$01,$FF          ; flag=-1, dy=1, dx=-1
    FCB $FF,$0F,$03          ; flag=-1, dy=15, dx=3
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$F3,$03          ; flag=-1, dy=-13, dx=3
    FCB $FF,$FF,$FF          ; flag=-1, dy=-1, dx=-1
    FCB $FF,$C5,$01          ; flag=-1, dy=-59, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $F2,$FC,0,0        ; path16: header (y=-14, x=-4, relative to center)
    FCB $FF,$39,$01          ; flag=-1, dy=57, dx=1
    FCB $FF,$01,$FF          ; flag=-1, dy=1, dx=-1
    FCB $FF,$0D,$03          ; flag=-1, dy=13, dx=3
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$F1,$02          ; flag=-1, dy=-15, dx=2
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $EA,$0B,0,0        ; path17: header (y=-22, x=11, relative to center)
    FCB $FF,$34,$FE          ; flag=-1, dy=52, dx=-2
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$0E,$02          ; flag=-1, dy=14, dx=2
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$F1,$04          ; flag=-1, dy=-15, dx=4
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$C7,$08          ; flag=-1, dy=-57, dx=8
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH18:    ; Path 18
    FCB 127              ; path18: intensity
    FCB $12,$ED,0,0        ; path18: header (y=18, x=-19, relative to center)
    FCB $FF,$03,$07          ; flag=-1, dy=3, dx=7
    FCB $FF,$FE,$08          ; flag=-1, dy=-2, dx=8
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH19:    ; Path 19
    FCB 127              ; path19: intensity
    FCB $0B,$ED,0,0        ; path19: header (y=11, x=-19, relative to center)
    FCB $FF,$05,$07          ; flag=-1, dy=5, dx=7
    FCB $FF,$FC,$08          ; flag=-1, dy=-4, dx=8
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH20:    ; Path 20
    FCB 127              ; path20: intensity
    FCB $F3,$F1,0,0        ; path20: header (y=-13, x=-15, relative to center)
    FCB $FF,$0F,$00          ; flag=-1, dy=15, dx=0
    FCB $FF,$08,$03          ; flag=-1, dy=8, dx=3
    FCB $FF,$F7,$04          ; flag=-1, dy=-9, dx=4
    FCB $FF,$F2,$01          ; flag=-1, dy=-14, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH21:    ; Path 21
    FCB 127              ; path21: intensity
    FCB $2A,$02,0,0        ; path21: header (y=42, x=2, relative to center)
    FCB $FF,$C0,$09          ; flag=-1, dy=-64, dx=9
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH22:    ; Path 22
    FCB 127              ; path22: intensity
    FCB $2A,$E6,0,0        ; path22: header (y=42, x=-26, relative to center)
    FCB $FF,$01,$06          ; flag=-1, dy=1, dx=6
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH23:    ; Path 23
    FCB 127              ; path23: intensity
    FCB $1D,$DB,0,0        ; path23: header (y=29, x=-37, relative to center)
    FCB $FF,$01,$05          ; flag=-1, dy=1, dx=5
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH24:    ; Path 24
    FCB 127              ; path24: intensity
    FCB $2A,$FD,0,0        ; path24: header (y=42, x=-3, relative to center)
    FCB $FF,$FF,$05          ; flag=-1, dy=-1, dx=5
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH25:    ; Path 25
    FCB 127              ; path25: intensity
    FCB $1D,$09,0,0        ; path25: header (y=29, x=9, relative to center)
    FCB $FF,$FF,$06          ; flag=-1, dy=-1, dx=6
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH26:    ; Path 26
    FCB 127              ; path26: intensity
    FCB $28,$FE,0,0        ; path26: header (y=40, x=-2, relative to center)
    FCB $FF,$E6,$00          ; flag=-1, dy=-26, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH27:    ; Path 27
    FCB 127              ; path27: intensity
    FCB $1A,$0B,0,0        ; path27: header (y=26, x=11, relative to center)
    FCB $FF,$E9,$01          ; flag=-1, dy=-23, dx=1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH28:    ; Path 28
    FCB 127              ; path28: intensity
    FCB $28,$E8,0,0        ; path28: header (y=40, x=-24, relative to center)
    FCB $FF,$E5,$FD          ; flag=-1, dy=-27, dx=-3
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH29:    ; Path 29
    FCB 127              ; path29: intensity
    FCB $28,$EB,0,0        ; path29: header (y=40, x=-21, relative to center)
    FCB $FF,$E6,$00          ; flag=-1, dy=-26, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH30:    ; Path 30
    FCB 127              ; path30: intensity
    FCB $0E,$E9,0,0        ; path30: header (y=14, x=-23, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH31:    ; Path 31
    FCB 127              ; path31: intensity
    FCB $28,$01,0,0        ; path31: header (y=40, x=1, relative to center)
    FCB $FF,$E5,$03          ; flag=-1, dy=-27, dx=3
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH32:    ; Path 32
    FCB 127              ; path32: intensity
    FCB $19,$0E,0,0        ; path32: header (y=25, x=14, relative to center)
    FCB $FF,$E9,$03          ; flag=-1, dy=-23, dx=3
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH33:    ; Path 33
    FCB 127              ; path33: intensity
    FCB $07,$E5,0,0        ; path33: header (y=7, x=-27, relative to center)
    FCB $FF,$F0,$FF          ; flag=-1, dy=-16, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH34:    ; Path 34
    FCB 127              ; path34: intensity
    FCB $07,$E8,0,0        ; path34: header (y=7, x=-24, relative to center)
    FCB $FF,$F2,$FF          ; flag=-1, dy=-14, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH35:    ; Path 35
    FCB 127              ; path35: intensity
    FCB $07,$EB,0,0        ; path35: header (y=7, x=-21, relative to center)
    FCB $FF,$F4,$FF          ; flag=-1, dy=-12, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH36:    ; Path 36
    FCB 127              ; path36: intensity
    FCB $F5,$00,0,0        ; path36: header (y=-11, x=0, relative to center)
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH37:    ; Path 37
    FCB 127              ; path37: intensity
    FCB $F3,$05,0,0        ; path37: header (y=-13, x=5, relative to center)
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH38:    ; Path 38
    FCB 127              ; path38: intensity
    FCB $F0,$08,0,0        ; path38: header (y=-16, x=8, relative to center)
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH39:    ; Path 39
    FCB 127              ; path39: intensity
    FCB $1B,$DC,0,0        ; path39: header (y=27, x=-36, relative to center)
    FCB $FF,$EB,$FE          ; flag=-1, dy=-21, dx=-2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH40:    ; Path 40
    FCB 127              ; path40: intensity
    FCB $1B,$DE,0,0        ; path40: header (y=27, x=-34, relative to center)
    FCB $FF,$EB,$00          ; flag=-1, dy=-21, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH41:    ; Path 41
    FCB 127              ; path41: intensity
    FCB $00,$D9,0,0        ; path41: header (y=0, x=-39, relative to center)
    FCB $FF,$F0,$FE          ; flag=-1, dy=-16, dx=-2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH42:    ; Path 42
    FCB 127              ; path42: intensity
    FCB $00,$DB,0,0        ; path42: header (y=0, x=-37, relative to center)
    FCB $FF,$F1,$FF          ; flag=-1, dy=-15, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH43:    ; Path 43
    FCB 127              ; path43: intensity
    FCB $00,$DE,0,0        ; path43: header (y=0, x=-34, relative to center)
    FCB $FF,$F3,$FF          ; flag=-1, dy=-13, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH44:    ; Path 44
    FCB 127              ; path44: intensity
    FCB $3D,$EC,0,0        ; path44: header (y=61, x=-20, relative to center)
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH45:    ; Path 45
    FCB 127              ; path45: intensity
    FCB $30,$E1,0,0        ; path45: header (y=48, x=-31, relative to center)
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$FD,$FE          ; flag=-1, dy=-3, dx=-2
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH46:    ; Path 46
    FCB 127              ; path46: intensity
    FCB $3C,$03,0,0        ; path46: header (y=60, x=3, relative to center)
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH47:    ; Path 47
    FCB 127              ; path47: intensity
    FCB $2E,$0E,0,0        ; path47: header (y=46, x=14, relative to center)
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH48:    ; Path 48
    FCB 127              ; path48: intensity
    FCB $F2,$0D,0,0        ; path48: header (y=-14, x=13, relative to center)
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH49:    ; Path 49
    FCB 127              ; path49: intensity
    FCB $F0,$10,0,0        ; path49: header (y=-16, x=16, relative to center)
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH50:    ; Path 50
    FCB 127              ; path50: intensity
    FCB $EE,$13,0,0        ; path50: header (y=-18, x=19, relative to center)
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH51:    ; Path 51
    FCB 127              ; path51: intensity
    FCB $01,$EE,0,0        ; path51: header (y=1, x=-18, relative to center)
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH52:    ; Path 52
    FCB 127              ; path52: intensity
    FCB $03,$F1,0,0        ; path52: header (y=3, x=-15, relative to center)
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH53:    ; Path 53
    FCB 127              ; path53: intensity
    FCB $05,$F4,0,0        ; path53: header (y=5, x=-12, relative to center)
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH54:    ; Path 54
    FCB 127              ; path54: intensity
    FCB $07,$05,0,0        ; path54: header (y=7, x=5, relative to center)
    FCB $FF,$F0,$01          ; flag=-1, dy=-16, dx=1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH55:    ; Path 55
    FCB 127              ; path55: intensity
    FCB $07,$02,0,0        ; path55: header (y=7, x=2, relative to center)
    FCB $FF,$F2,$01          ; flag=-1, dy=-14, dx=1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH56:    ; Path 56
    FCB 127              ; path56: intensity
    FCB $07,$FF,0,0        ; path56: header (y=7, x=-1, relative to center)
    FCB $FF,$F4,$01          ; flag=-1, dy=-12, dx=1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH57:    ; Path 57
    FCB 127              ; path57: intensity
    FCB $00,$11,0,0        ; path57: header (y=0, x=17, relative to center)
    FCB $FF,$F0,$02          ; flag=-1, dy=-16, dx=2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH58:    ; Path 58
    FCB 127              ; path58: intensity
    FCB $00,$0F,0,0        ; path58: header (y=0, x=15, relative to center)
    FCB $FF,$F1,$01          ; flag=-1, dy=-15, dx=1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH59:    ; Path 59
    FCB 127              ; path59: intensity
    FCB $00,$0C,0,0        ; path59: header (y=0, x=12, relative to center)
    FCB $FF,$F3,$01          ; flag=-1, dy=-13, dx=1
    FCB 2                ; End marker (path complete)
; Generated from bubble_huge.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 8
; X bounds: min=-25, max=27, width=52
; Center: (1, 0)

_BUBBLE_HUGE_WIDTH EQU 52
_BUBBLE_HUGE_HALF_WIDTH EQU 26
_BUBBLE_HUGE_CENTER_X EQU 1
_BUBBLE_HUGE_CENTER_Y EQU 0

_BUBBLE_HUGE_VECTORS:  ; Main entry (header + 1 path(s))
    FCB 1               ; path_count (runtime metadata)
    FDB _BUBBLE_HUGE_PATH0        ; pointer to path 0

_BUBBLE_HUGE_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $00,$1A,0,0        ; path0: header (y=0, x=26, relative to center)
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
_BUBBLE_LARGE_CENTER_X EQU 0
_BUBBLE_LARGE_CENTER_Y EQU 0

_BUBBLE_LARGE_VECTORS:  ; Main entry (header + 1 path(s))
    FCB 1               ; path_count (runtime metadata)
    FDB _BUBBLE_LARGE_PATH0        ; pointer to path 0

_BUBBLE_LARGE_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $00,$14,0,0        ; path0: header (y=0, x=20, relative to center)
    FCB $FF,$05,$FF          ; flag=-1, dy=5, dx=-1
    FCB $FF,$05,$FE          ; flag=-1, dy=5, dx=-2
    FCB $FF,$04,$FD          ; flag=-1, dy=4, dx=-3
    FCB $FF,$03,$FC          ; flag=-1, dy=3, dx=-4
    FCB $FF,$02,$FB          ; flag=-1, dy=2, dx=-5
    FCB $FF,$01,$FB          ; flag=-1, dy=1, dx=-5
    FCB $FF,$FF,$FB          ; flag=-1, dy=-1, dx=-5
    FCB $FF,$FE,$FB          ; flag=-1, dy=-2, dx=-5
    FCB $FF,$FD,$FC          ; flag=-1, dy=-3, dx=-4
    FCB $FF,$FC,$FD          ; flag=-1, dy=-4, dx=-3
    FCB $FF,$FB,$FE          ; flag=-1, dy=-5, dx=-2
    FCB $FF,$FB,$FF          ; flag=-1, dy=-5, dx=-1
    FCB $FF,$FB,$01          ; flag=-1, dy=-5, dx=1
    FCB $FF,$FB,$02          ; flag=-1, dy=-5, dx=2
    FCB $FF,$FC,$03          ; flag=-1, dy=-4, dx=3
    FCB $FF,$FD,$04          ; flag=-1, dy=-3, dx=4
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB $FF,$FF,$05          ; flag=-1, dy=-1, dx=5
    FCB $FF,$01,$05          ; flag=-1, dy=1, dx=5
    FCB $FF,$02,$05          ; flag=-1, dy=2, dx=5
    FCB $FF,$03,$04          ; flag=-1, dy=3, dx=4
    FCB $FF,$04,$03          ; flag=-1, dy=4, dx=3
    FCB $FF,$05,$02          ; flag=-1, dy=5, dx=2
    FCB $FF,$05,$01          ; flag=-1, dy=5, dx=1
    FCB 2                ; End marker (path complete)
; Generated from bubble_medium.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 24
; X bounds: min=-15, max=15, width=30
; Center: (0, 0)

_BUBBLE_MEDIUM_WIDTH EQU 30
_BUBBLE_MEDIUM_HALF_WIDTH EQU 15
_BUBBLE_MEDIUM_CENTER_X EQU 0
_BUBBLE_MEDIUM_CENTER_Y EQU 0

_BUBBLE_MEDIUM_VECTORS:  ; Main entry (header + 1 path(s))
    FCB 1               ; path_count (runtime metadata)
    FDB _BUBBLE_MEDIUM_PATH0        ; pointer to path 0

_BUBBLE_MEDIUM_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $00,$0F,0,0        ; path0: header (y=0, x=15, relative to center)
    FCB $FF,$04,$FF          ; flag=-1, dy=4, dx=-1
    FCB $FF,$04,$FF          ; flag=-1, dy=4, dx=-1
    FCB $FF,$03,$FE          ; flag=-1, dy=3, dx=-2
    FCB $FF,$02,$FD          ; flag=-1, dy=2, dx=-3
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB $FF,$FF,$FC          ; flag=-1, dy=-1, dx=-4
    FCB $FF,$FF,$FC          ; flag=-1, dy=-1, dx=-4
    FCB $FF,$FE,$FD          ; flag=-1, dy=-2, dx=-3
    FCB $FF,$FD,$FE          ; flag=-1, dy=-3, dx=-2
    FCB $FF,$FC,$FF          ; flag=-1, dy=-4, dx=-1
    FCB $FF,$FC,$FF          ; flag=-1, dy=-4, dx=-1
    FCB $FF,$FC,$01          ; flag=-1, dy=-4, dx=1
    FCB $FF,$FC,$01          ; flag=-1, dy=-4, dx=1
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$FE,$03          ; flag=-1, dy=-2, dx=3
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB $FF,$01,$04          ; flag=-1, dy=1, dx=4
    FCB $FF,$01,$04          ; flag=-1, dy=1, dx=4
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB $FF,$04,$01          ; flag=-1, dy=4, dx=1
    FCB $FF,$04,$01          ; flag=-1, dy=4, dx=1
    FCB 2                ; End marker (path complete)
; Generated from bubble_small.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 24
; X bounds: min=-10, max=10, width=20
; Center: (0, 0)

_BUBBLE_SMALL_WIDTH EQU 20
_BUBBLE_SMALL_HALF_WIDTH EQU 10
_BUBBLE_SMALL_CENTER_X EQU 0
_BUBBLE_SMALL_CENTER_Y EQU 0

_BUBBLE_SMALL_VECTORS:  ; Main entry (header + 1 path(s))
    FCB 1               ; path_count (runtime metadata)
    FDB _BUBBLE_SMALL_PATH0        ; pointer to path 0

_BUBBLE_SMALL_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $00,$0A,0,0        ; path0: header (y=0, x=10, relative to center)
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB $FF,$FF,$FD          ; flag=-1, dy=-1, dx=-3
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FF,$03          ; flag=-1, dy=-1, dx=3
    FCB $FF,$01,$03          ; flag=-1, dy=1, dx=3
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB 2                ; End marker (path complete)
; Generated from buddha_bg.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 10
; X bounds: min=-80, max=80, width=160
; Center: (0, 20)

_BUDDHA_BG_WIDTH EQU 160
_BUDDHA_BG_HALF_WIDTH EQU 80
_BUDDHA_BG_CENTER_X EQU 0
_BUDDHA_BG_CENTER_Y EQU 20

_BUDDHA_BG_VECTORS:  ; Main entry (header + 4 path(s))
    FCB 4               ; path_count (runtime metadata)
    FDB _BUDDHA_BG_PATH0        ; pointer to path 0
    FDB _BUDDHA_BG_PATH1        ; pointer to path 1
    FDB _BUDDHA_BG_PATH2        ; pointer to path 2
    FDB _BUDDHA_BG_PATH3        ; pointer to path 3

_BUDDHA_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $14,$B0,0,0        ; path0: header (y=20, x=-80, relative to center)
    FCB $FF,$14,$14          ; flag=-1, dy=20, dx=20
    FCB $FF,$00,$78          ; flag=-1, dy=0, dx=120
    FCB $FF,$EC,$14          ; flag=-1, dy=-20, dx=20
    FCB 2                ; End marker (path complete)

_BUDDHA_BG_PATH1:    ; Path 1
    FCB 100              ; path1: intensity
    FCB $14,$CE,0,0        ; path1: header (y=20, x=-50, relative to center)
    FCB $FF,$C4,$00          ; flag=-1, dy=-60, dx=0
    FCB 2                ; End marker (path complete)

_BUDDHA_BG_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $14,$32,0,0        ; path2: header (y=20, x=50, relative to center)
    FCB $FF,$C4,$00          ; flag=-1, dy=-60, dx=0
    FCB 2                ; End marker (path complete)

_BUDDHA_BG_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $D8,$BA,0,0        ; path3: header (y=-40, x=-70, relative to center)
    FCB $FF,$00,$46          ; sub-seg 1/2 of line 0: dy=0, dx=70
    FCB $FF,$00,$46          ; sub-seg 2/2 of line 0: dy=0, dx=70
    FCB 2                ; End marker (path complete)
; Generated from easter_bg.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 19
; X bounds: min=-35, max=35, width=70
; Center: (0, 15)

_EASTER_BG_WIDTH EQU 70
_EASTER_BG_HALF_WIDTH EQU 35
_EASTER_BG_CENTER_X EQU 0
_EASTER_BG_CENTER_Y EQU 15

_EASTER_BG_VECTORS:  ; Main entry (header + 5 path(s))
    FCB 5               ; path_count (runtime metadata)
    FDB _EASTER_BG_PATH0        ; pointer to path 0
    FDB _EASTER_BG_PATH1        ; pointer to path 1
    FDB _EASTER_BG_PATH2        ; pointer to path 2
    FDB _EASTER_BG_PATH3        ; pointer to path 3
    FDB _EASTER_BG_PATH4        ; pointer to path 4

_EASTER_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $05,$E7,0,0        ; path0: header (y=5, x=-25, relative to center)
    FCB $FF,$1E,$00          ; flag=-1, dy=30, dx=0
    FCB $FF,$0A,$05          ; flag=-1, dy=10, dx=5
    FCB $FF,$00,$28          ; flag=-1, dy=0, dx=40
    FCB $FF,$F6,$05          ; flag=-1, dy=-10, dx=5
    FCB $FF,$E2,$00          ; flag=-1, dy=-30, dx=0
    FCB 2                ; End marker (path complete)

_EASTER_BG_PATH1:    ; Path 1
    FCB 110              ; path1: intensity
    FCB $19,$00,0,0        ; path1: header (y=25, x=0, relative to center)
    FCB $FF,$FB,$0A          ; flag=-1, dy=-5, dx=10
    FCB 2                ; End marker (path complete)

_EASTER_BG_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $1E,$F8,0,0        ; path2: header (y=30, x=-8, relative to center)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB 2                ; End marker (path complete)

_EASTER_BG_PATH3:    ; Path 3
    FCB 110              ; path3: intensity
    FCB $05,$E2,0,0        ; path3: header (y=5, x=-30, relative to center)
    FCB $FF,$CE,$00          ; flag=-1, dy=-50, dx=0
    FCB $FF,$00,$3C          ; flag=-1, dy=0, dx=60
    FCB $FF,$32,$00          ; flag=-1, dy=50, dx=0
    FCB 2                ; End marker (path complete)

_EASTER_BG_PATH4:    ; Path 4
    FCB 90              ; path4: intensity
    FCB $D3,$DD,0,0        ; path4: header (y=-45, x=-35, relative to center)
    FCB $FF,$00,$46          ; flag=-1, dy=0, dx=70
    FCB 2                ; End marker (path complete)
; Generated from fuji_bg.vec (Malban Draw_Sync_List format)
; Total paths: 6, points: 65
; X bounds: min=-125, max=125, width=250
; Center: (0, 0)

_FUJI_BG_WIDTH EQU 250
_FUJI_BG_HALF_WIDTH EQU 125
_FUJI_BG_CENTER_X EQU 0
_FUJI_BG_CENTER_Y EQU 0

_FUJI_BG_VECTORS:  ; Main entry (header + 6 path(s))
    FCB 6               ; path_count (runtime metadata)
    FDB _FUJI_BG_PATH0        ; pointer to path 0
    FDB _FUJI_BG_PATH1        ; pointer to path 1
    FDB _FUJI_BG_PATH2        ; pointer to path 2
    FDB _FUJI_BG_PATH3        ; pointer to path 3
    FDB _FUJI_BG_PATH4        ; pointer to path 4
    FDB _FUJI_BG_PATH5        ; pointer to path 5

_FUJI_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $CF,$83,0,0        ; path0: header (y=-49, x=-125, relative to center)
    FCB 2                ; End marker (path complete)

_FUJI_BG_PATH1:    ; Path 1
    FCB 80              ; path1: intensity
    FCB $E8,$84,0,0        ; path1: header (y=-24, x=-124, relative to center)
    FCB $FF,$0A,$1E          ; flag=-1, dy=10, dx=30
    FCB $FF,$0E,$1E          ; flag=-1, dy=14, dx=30
    FCB $FF,$0F,$15          ; flag=-1, dy=15, dx=21
    FCB $FF,$11,$17          ; flag=-1, dy=17, dx=23
    FCB $FF,$0E,$0E          ; flag=-1, dy=14, dx=14
    FCB $FF,$FE,$03          ; flag=-1, dy=-2, dx=3
    FCB $FF,$03,$04          ; flag=-1, dy=3, dx=4
    FCB $FF,$FE,$04          ; flag=-1, dy=-2, dx=4
    FCB $FF,$01,$07          ; flag=-1, dy=1, dx=7
    FCB $FF,$02,$04          ; flag=-1, dy=2, dx=4
    FCB $FF,$FD,$06          ; flag=-1, dy=-3, dx=6
    FCB $FF,$03,$03          ; flag=-1, dy=3, dx=3
    FCB $FF,$EB,$11          ; flag=-1, dy=-21, dx=17
    FCB $FF,$F4,$11          ; flag=-1, dy=-12, dx=17
    FCB $FF,$F0,$16          ; flag=-1, dy=-16, dx=22
    FCB $FF,$F6,$14          ; flag=-1, dy=-10, dx=20
    FCB $FF,$F6,$18          ; flag=-1, dy=-10, dx=24
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_FUJI_BG_PATH2:    ; Path 2
    FCB 95              ; path2: intensity
    FCB $1A,$F1,0,0        ; path2: header (y=26, x=-15, relative to center)
    FCB $FF,$06,$03          ; flag=-1, dy=6, dx=3
    FCB $FF,$04,$03          ; flag=-1, dy=4, dx=3
    FCB $FF,$FD,$04          ; flag=-1, dy=-3, dx=4
    FCB $FF,$FC,$FC          ; flag=-1, dy=-4, dx=-4
    FCB $FF,$FD,$FA          ; flag=-1, dy=-3, dx=-6
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_FUJI_BG_PATH3:    ; Path 3
    FCB 95              ; path3: intensity
    FCB $1F,$07,0,0        ; path3: header (y=31, x=7, relative to center)
    FCB $FF,$F9,$FD          ; flag=-1, dy=-7, dx=-3
    FCB $FF,$FA,$02          ; flag=-1, dy=-6, dx=2
    FCB $FF,$F9,$FD          ; flag=-1, dy=-7, dx=-3
    FCB $FF,$FD,$04          ; flag=-1, dy=-3, dx=4
    FCB $FF,$08,$03          ; flag=-1, dy=8, dx=3
    FCB $FF,$07,$FE          ; flag=-1, dy=7, dx=-2
    FCB $FF,$06,$01          ; flag=-1, dy=6, dx=1
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB 2                ; End marker (path complete)

_FUJI_BG_PATH4:    ; Path 4
    FCB 95              ; path4: intensity
    FCB $21,$18,0,0        ; path4: header (y=33, x=24, relative to center)
    FCB $FF,$F7,$05          ; flag=-1, dy=-9, dx=5
    FCB $FF,$F7,$0C          ; flag=-1, dy=-9, dx=12
    FCB $FF,$0B,$FA          ; flag=-1, dy=11, dx=-6
    FCB $FF,$07,$F5          ; flag=-1, dy=7, dx=-11
    FCB 2                ; End marker (path complete)

_FUJI_BG_PATH5:    ; Path 5
    FCB 100              ; path5: intensity
    FCB $05,$C7,0,0        ; path5: header (y=5, x=-57, relative to center)
    FCB $FF,$09,$1A          ; flag=-1, dy=9, dx=26
    FCB $FF,$EF,$F2          ; flag=-1, dy=-17, dx=-14
    FCB $FF,$1B,$22          ; flag=-1, dy=27, dx=34
    FCB $FF,$F2,$FB          ; flag=-1, dy=-14, dx=-5
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$F7,$FB          ; flag=-1, dy=-9, dx=-5
    FCB $FF,$FA,$01          ; flag=-1, dy=-6, dx=1
    FCB $FF,$0E,$0E          ; flag=-1, dy=14, dx=14
    FCB $FF,$F1,$00          ; flag=-1, dy=-15, dx=0
    FCB $FF,$0A,$05          ; flag=-1, dy=10, dx=5
    FCB $FF,$EA,$06          ; flag=-1, dy=-22, dx=6
    FCB $FF,$1C,$05          ; flag=-1, dy=28, dx=5
    FCB $FF,$EF,$06          ; flag=-1, dy=-17, dx=6
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$FD,$04          ; flag=-1, dy=-3, dx=4
    FCB $FF,$0B,$03          ; flag=-1, dy=11, dx=3
    FCB $FF,$F5,$05          ; flag=-1, dy=-11, dx=5
    FCB $FF,$10,$FF          ; flag=-1, dy=16, dx=-1
    FCB $FF,$EE,$13          ; flag=-1, dy=-18, dx=19
    FCB $FF,$12,$F7          ; flag=-1, dy=18, dx=-9
    FCB $FF,$F9,$0E          ; flag=-1, dy=-7, dx=14
    FCB $FF,$04,$02          ; flag=-1, dy=4, dx=2
    FCB $FF,$FC,$14          ; flag=-1, dy=-4, dx=20
    FCB 2                ; End marker (path complete)
; Generated from hook.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 10
; X bounds: min=-6, max=6, width=12
; Center: (0, 0)

_HOOK_WIDTH EQU 12
_HOOK_HALF_WIDTH EQU 6
_HOOK_CENTER_X EQU 0
_HOOK_CENTER_Y EQU 0

_HOOK_VECTORS:  ; Main entry (header + 1 path(s))
    FCB 1               ; path_count (runtime metadata)
    FDB _HOOK_PATH0        ; pointer to path 0

_HOOK_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FC,$FA,0,0        ; path0: header (y=-4, x=-6, relative to center)
    FCB $FF,$0B,$06          ; flag=-1, dy=11, dx=6
    FCB $FF,$F5,$06          ; flag=-1, dy=-11, dx=6
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$04,$FC          ; flag=-1, dy=4, dx=-4
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$FC,$FC          ; flag=-1, dy=-4, dx=-4
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB 2                ; End marker (path complete)
; Generated from keirin_bg.vec (Malban Draw_Sync_List format)
; Total paths: 3, points: 11
; X bounds: min=-100, max=100, width=200
; Center: (0, 10)

_KEIRIN_BG_WIDTH EQU 200
_KEIRIN_BG_HALF_WIDTH EQU 100
_KEIRIN_BG_CENTER_X EQU 0
_KEIRIN_BG_CENTER_Y EQU 10

_KEIRIN_BG_VECTORS:  ; Main entry (header + 3 path(s))
    FCB 3               ; path_count (runtime metadata)
    FDB _KEIRIN_BG_PATH0        ; pointer to path 0
    FDB _KEIRIN_BG_PATH1        ; pointer to path 1
    FDB _KEIRIN_BG_PATH2        ; pointer to path 2

_KEIRIN_BG_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $D8,$9C,0,0        ; path0: header (y=-40, x=-100, relative to center)
    FCB $FF,$46,$32          ; flag=-1, dy=70, dx=50
    FCB $FF,$0A,$32          ; flag=-1, dy=10, dx=50
    FCB $FF,$F6,$32          ; flag=-1, dy=-10, dx=50
    FCB $FF,$BA,$32          ; flag=-1, dy=-70, dx=50
    FCB 2                ; End marker (path complete)

_KEIRIN_BG_PATH1:    ; Path 1
    FCB 80              ; path1: intensity
    FCB $EC,$BA,0,0        ; path1: header (y=-20, x=-70, relative to center)
    FCB $FF,$1E,$1E          ; flag=-1, dy=30, dx=30
    FCB $FF,$0A,$1E          ; flag=-1, dy=10, dx=30
    FCB 2                ; End marker (path complete)

_KEIRIN_BG_PATH2:    ; Path 2
    FCB 80              ; path2: intensity
    FCB $14,$0A,0,0        ; path2: header (y=20, x=10, relative to center)
    FCB $FF,$F6,$1E          ; flag=-1, dy=-10, dx=30
    FCB $FF,$E2,$1E          ; flag=-1, dy=-30, dx=30
    FCB 2                ; End marker (path complete)
; Generated from kilimanjaro_bg.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 13
; X bounds: min=-100, max=100, width=200
; Center: (0, 12)

_KILIMANJARO_BG_WIDTH EQU 200
_KILIMANJARO_BG_HALF_WIDTH EQU 100
_KILIMANJARO_BG_CENTER_X EQU 0
_KILIMANJARO_BG_CENTER_Y EQU 12

_KILIMANJARO_BG_VECTORS:  ; Main entry (header + 4 path(s))
    FCB 4               ; path_count (runtime metadata)
    FDB _KILIMANJARO_BG_PATH0        ; pointer to path 0
    FDB _KILIMANJARO_BG_PATH1        ; pointer to path 1
    FDB _KILIMANJARO_BG_PATH2        ; pointer to path 2
    FDB _KILIMANJARO_BG_PATH3        ; pointer to path 3

_KILIMANJARO_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $D6,$9C,0,0        ; path0: header (y=-42, x=-100, relative to center)
    FCB $FF,$3C,$32          ; flag=-1, dy=60, dx=50
    FCB $FF,$19,$32          ; flag=-1, dy=25, dx=50
    FCB $FF,$E7,$32          ; flag=-1, dy=-25, dx=50
    FCB $FF,$C4,$32          ; flag=-1, dy=-60, dx=50
    FCB 2                ; End marker (path complete)

_KILIMANJARO_BG_PATH1:    ; Path 1
    FCB 110              ; path1: intensity
    FCB $1C,$E2,0,0        ; path1: header (y=28, x=-30, relative to center)
    FCB $FF,$0F,$1E          ; flag=-1, dy=15, dx=30
    FCB $FF,$F1,$00          ; flag=-1, dy=-15, dx=0
    FCB 2                ; End marker (path complete)

_KILIMANJARO_BG_PATH2:    ; Path 2
    FCB 110              ; path2: intensity
    FCB $1C,$00,0,0        ; path2: header (y=28, x=0, relative to center)
    FCB $FF,$0F,$00          ; flag=-1, dy=15, dx=0
    FCB $FF,$F1,$1E          ; flag=-1, dy=-15, dx=30
    FCB 2                ; End marker (path complete)

_KILIMANJARO_BG_PATH3:    ; Path 3
    FCB 90              ; path3: intensity
    FCB $F4,$BA,0,0        ; path3: header (y=-12, x=-70, relative to center)
    FCB $FF,$14,$1E          ; flag=-1, dy=20, dx=30
    FCB 2                ; End marker (path complete)
; Generated from leningrad_bg.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 21
; X bounds: min=-30, max=30, width=60
; Center: (0, 30)

_LENINGRAD_BG_WIDTH EQU 60
_LENINGRAD_BG_HALF_WIDTH EQU 30
_LENINGRAD_BG_CENTER_X EQU 0
_LENINGRAD_BG_CENTER_Y EQU 30

_LENINGRAD_BG_VECTORS:  ; Main entry (header + 5 path(s))
    FCB 5               ; path_count (runtime metadata)
    FDB _LENINGRAD_BG_PATH0        ; pointer to path 0
    FDB _LENINGRAD_BG_PATH1        ; pointer to path 1
    FDB _LENINGRAD_BG_PATH2        ; pointer to path 2
    FDB _LENINGRAD_BG_PATH3        ; pointer to path 3
    FDB _LENINGRAD_BG_PATH4        ; pointer to path 4

_LENINGRAD_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $05,$E7,0,0        ; path0: header (y=5, x=-25, relative to center)
    FCB $FF,$14,$0A          ; flag=-1, dy=20, dx=10
    FCB $FF,$05,$0F          ; flag=-1, dy=5, dx=15
    FCB $FF,$FB,$0F          ; flag=-1, dy=-5, dx=15
    FCB $FF,$EC,$0A          ; flag=-1, dy=-20, dx=10
    FCB 2                ; End marker (path complete)

_LENINGRAD_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $1E,$00,0,0        ; path1: header (y=30, x=0, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_LENINGRAD_BG_PATH2:    ; Path 2
    FCB 110              ; path2: intensity
    FCB $05,$E2,0,0        ; path2: header (y=5, x=-30, relative to center)
    FCB $FF,$D3,$00          ; flag=-1, dy=-45, dx=0
    FCB $FF,$00,$3C          ; flag=-1, dy=0, dx=60
    FCB $FF,$2D,$00          ; flag=-1, dy=45, dx=0
    FCB 2                ; End marker (path complete)

_LENINGRAD_BG_PATH3:    ; Path 3
    FCB 90              ; path3: intensity
    FCB $EC,$EC,0,0        ; path3: header (y=-20, x=-20, relative to center)
    FCB $FF,$0F,$00          ; flag=-1, dy=15, dx=0
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$F1,$00          ; flag=-1, dy=-15, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_LENINGRAD_BG_PATH4:    ; Path 4
    FCB 90              ; path4: intensity
    FCB $EC,$0A,0,0        ; path4: header (y=-20, x=10, relative to center)
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
_LOCATION_MARKER_CENTER_X EQU 0
_LOCATION_MARKER_CENTER_Y EQU 1

_LOCATION_MARKER_VECTORS:  ; Main entry (header + 1 path(s))
    FCB 1               ; path_count (runtime metadata)
    FDB _LOCATION_MARKER_PATH0        ; pointer to path 0

_LOCATION_MARKER_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $0B,$00,0,0        ; path0: header (y=11, x=0, relative to center)
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
_LOGO_CENTER_X EQU 0
_LOGO_CENTER_Y EQU 0

_LOGO_VECTORS:  ; Main entry (header + 7 path(s))
    FCB 7               ; path_count (runtime metadata)
    FDB _LOGO_PATH0        ; pointer to path 0
    FDB _LOGO_PATH1        ; pointer to path 1
    FDB _LOGO_PATH2        ; pointer to path 2
    FDB _LOGO_PATH3        ; pointer to path 3
    FDB _LOGO_PATH4        ; pointer to path 4
    FDB _LOGO_PATH5        ; pointer to path 5
    FDB _LOGO_PATH6        ; pointer to path 6

_LOGO_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $13,$AE,0,0        ; path0: header (y=19, x=-82, relative to center)
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
    FCB $FF,$FC,$F1          ; flag=-1, dy=-4, dx=-15
    FCB $FF,$F8,$EA          ; flag=-1, dy=-8, dx=-22
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_LOGO_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $FB,$E3,0,0        ; path1: header (y=-5, x=-29, relative to center)
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
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_LOGO_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $07,$CE,0,0        ; path2: header (y=7, x=-50, relative to center)
    FCB $FF,$F8,$02          ; flag=-1, dy=-8, dx=2
    FCB $FF,$07,$08          ; flag=-1, dy=7, dx=8
    FCB $FF,$01,$F6          ; flag=-1, dy=1, dx=-10
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_LOGO_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $06,$F4,0,0        ; path3: header (y=6, x=-12, relative to center)
    FCB $FF,$F6,$FD          ; flag=-1, dy=-10, dx=-3
    FCB $FF,$02,$07          ; flag=-1, dy=2, dx=7
    FCB $FF,$08,$FC          ; flag=-1, dy=8, dx=-4
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB 2                ; End marker (path complete)

_LOGO_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $F3,$0A,0,0        ; path4: header (y=-13, x=10, relative to center)
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
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_LOGO_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $06,$45,0,0        ; path5: header (y=6, x=69, relative to center)
    FCB $FF,$08,$F5          ; flag=-1, dy=8, dx=-11
    FCB $FF,$F4,$F7          ; flag=-1, dy=-12, dx=-9
    FCB $FF,$F7,$01          ; flag=-1, dy=-9, dx=1
    FCB $FF,$FE,$0C          ; flag=-1, dy=-2, dx=12
    FCB $FF,$03,$FA          ; flag=-1, dy=3, dx=-6
    FCB $FF,$05,$01          ; flag=-1, dy=5, dx=1
    FCB $FF,$02,$17          ; flag=-1, dy=2, dx=23
    FCB $FF,$F3,$FD          ; flag=-1, dy=-13, dx=-3
    FCB $FF,$F9,$EE          ; flag=-1, dy=-7, dx=-18
    FCB $FF,$04,$F0          ; flag=-1, dy=4, dx=-16
    FCB $FF,$0B,$F8          ; flag=-1, dy=11, dx=-8
    FCB 2                ; End marker (path complete)

_LOGO_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $06,$45,0,0        ; path6: header (y=6, x=69, relative to center)
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
_LONDON_BG_CENTER_X EQU 0
_LONDON_BG_CENTER_Y EQU 15

_LONDON_BG_VECTORS:  ; Main entry (header + 4 path(s))
    FCB 4               ; path_count (runtime metadata)
    FDB _LONDON_BG_PATH0        ; pointer to path 0
    FDB _LONDON_BG_PATH1        ; pointer to path 1
    FDB _LONDON_BG_PATH2        ; pointer to path 2
    FDB _LONDON_BG_PATH3        ; pointer to path 3

_LONDON_BG_PATH0:    ; Path 0
    FCB 110              ; path0: intensity
    FCB $D3,$EC,0,0        ; path0: header (y=-45, x=-20, relative to center)
    FCB $FF,$46,$00          ; flag=-1, dy=70, dx=0
    FCB $FF,$00,$28          ; flag=-1, dy=0, dx=40
    FCB $FF,$BA,$00          ; flag=-1, dy=-70, dx=0
    FCB 2                ; End marker (path complete)

_LONDON_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $23,$F1,0,0        ; path1: header (y=35, x=-15, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$1E          ; flag=-1, dy=0, dx=30
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$00,$E2          ; flag=-1, dy=0, dx=-30
    FCB 2                ; End marker (path complete)

_LONDON_BG_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $28,$00,0,0        ; path2: header (y=40, x=0, relative to center)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$FB,$08          ; flag=-1, dy=-5, dx=8
    FCB 2                ; End marker (path complete)

_LONDON_BG_PATH3:    ; Path 3
    FCB 120              ; path3: intensity
    FCB $19,$EC,0,0        ; path3: header (y=25, x=-20, relative to center)
    FCB $FF,$0A,$05          ; flag=-1, dy=10, dx=5
    FCB $FF,$00,$1E          ; flag=-1, dy=0, dx=30
    FCB $FF,$F6,$05          ; flag=-1, dy=-10, dx=5
    FCB 2                ; End marker (path complete)
; Generated from map.vec (Malban Draw_Sync_List format)
; Total paths: 15, points: 165
; X bounds: min=-127, max=115, width=242
; Center: (-6, -3)

_MAP_WIDTH EQU 242
_MAP_HALF_WIDTH EQU 121
_MAP_CENTER_X EQU -6
_MAP_CENTER_Y EQU -3

_MAP_VECTORS:  ; Main entry (header + 15 path(s))
    FCB 15               ; path_count (runtime metadata)
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
    FCB $22,$D7,0,0        ; path0: header (y=34, x=-41, relative to center)
    FCB $FF,$0E,$1A          ; flag=-1, dy=14, dx=26
    FCB $FF,$07,$0C          ; flag=-1, dy=7, dx=12
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$09,$0C          ; flag=-1, dy=9, dx=12
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB $FF,$08,$0A          ; flag=-1, dy=8, dx=10
    FCB $FF,$00,$21          ; flag=-1, dy=0, dx=33
    FCB $FF,$FC,$03          ; flag=-1, dy=-4, dx=3
    FCB $FF,$FF,$14          ; flag=-1, dy=-1, dx=20
    FCB $FF,$EE,$20          ; flag=-1, dy=-18, dx=32
    FCB $FF,$FB,$FC          ; flag=-1, dy=-5, dx=-4
    FCB $FF,$F9,$FE          ; flag=-1, dy=-7, dx=-2
    FCB $FF,$06,$FA          ; flag=-1, dy=6, dx=-6
    FCB $FF,$02,$F0          ; flag=-1, dy=2, dx=-16
    FCB $FF,$F4,$06          ; flag=-1, dy=-12, dx=6
    FCB $FF,$E2,$FE          ; flag=-1, dy=-30, dx=-2
    FCB $FF,$FB,$FB          ; flag=-1, dy=-5, dx=-5
    FCB $FF,$F8,$FE          ; flag=-1, dy=-8, dx=-2
    FCB $FF,$FF,$F6          ; flag=-1, dy=-1, dx=-10
    FCB $FF,$F7,$05          ; flag=-1, dy=-9, dx=5
    FCB $FF,$FC,$FD          ; flag=-1, dy=-4, dx=-3
    FCB $FF,$0E,$F6          ; flag=-1, dy=14, dx=-10
    FCB $FF,$05,$01          ; flag=-1, dy=5, dx=1
    FCB $FF,$06,$FD          ; flag=-1, dy=6, dx=-3
    FCB $FF,$EA,$F7          ; flag=-1, dy=-22, dx=-9
    FCB $FF,$20,$F0          ; flag=-1, dy=32, dx=-16
    FCB $FF,$05,$F9          ; flag=-1, dy=5, dx=-7
    FCB $FF,$F9,$03          ; flag=-1, dy=-7, dx=3
    FCB $FF,$F5,$F9          ; flag=-1, dy=-11, dx=-7
    FCB $FF,$0E,$F3          ; flag=-1, dy=14, dx=-13
    FCB $FF,$FD,$FD          ; flag=-1, dy=-3, dx=-3
    FCB $FF,$F2,$0C          ; flag=-1, dy=-14, dx=12
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$F2,$F7          ; flag=-1, dy=-14, dx=-9
    FCB $FF,$F3,$FE          ; flag=-1, dy=-13, dx=-2
    FCB $FF,$EC,$ED          ; flag=-1, dy=-20, dx=-19
    FCB $FF,$0D,$F3          ; flag=-1, dy=13, dx=-13
    FCB $FF,$0E,$00          ; flag=-1, dy=14, dx=0
    FCB $FF,$09,$F8          ; flag=-1, dy=9, dx=-8
    FCB $FF,$00,$F0          ; flag=-1, dy=0, dx=-16
    FCB $FF,$08,$F8          ; flag=-1, dy=8, dx=-8
    FCB $FF,$0B,$00          ; flag=-1, dy=11, dx=0
    FCB $FF,$0B,$0A          ; flag=-1, dy=11, dx=10
    FCB $FF,$01,$22          ; flag=-1, dy=1, dx=34
    FCB $FF,$09,$F4          ; flag=-1, dy=9, dx=-12
    FCB $FF,$FA,$EE          ; flag=-1, dy=-6, dx=-18
    FCB $FF,$FF,$F3          ; flag=-1, dy=-1, dx=-13
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $38,$DE,0,0        ; path1: header (y=56, x=-34, relative to center)
    FCB $FF,$04,$06          ; flag=-1, dy=4, dx=6
    FCB $FF,$FC,$01          ; flag=-1, dy=-4, dx=1
    FCB $FF,$FD,$FC          ; flag=-1, dy=-3, dx=-4
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $34,$E5,0,0        ; path2: header (y=52, x=-27, relative to center)
    FCB $FF,$06,$0A          ; flag=-1, dy=6, dx=10
    FCB $FF,$06,$FE          ; flag=-1, dy=6, dx=-2
    FCB $FF,$02,$05          ; flag=-1, dy=2, dx=5
    FCB $FF,$FB,$FE          ; flag=-1, dy=-5, dx=-2
    FCB $FF,$F6,$02          ; flag=-1, dy=-10, dx=2
    FCB $FF,$FF,$F4          ; flag=-1, dy=-1, dx=-12
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $BD,$70,0,0        ; path3: header (y=-67, x=112, relative to center)
    FCB $FF,$08,$05          ; flag=-1, dy=8, dx=5
    FCB $FF,$14,$00          ; flag=-1, dy=20, dx=0
    FCB $FF,$06,$FB          ; flag=-1, dy=6, dx=-5
    FCB $FF,$F8,$FE          ; flag=-1, dy=-8, dx=-2
    FCB $FF,$06,$EE          ; flag=-1, dy=6, dx=-18
    FCB $FF,$F3,$F1          ; flag=-1, dy=-13, dx=-15
    FCB $FF,$F5,$07          ; flag=-1, dy=-11, dx=7
    FCB $FF,$03,$0C          ; flag=-1, dy=3, dx=12
    FCB $FF,$F4,$10          ; flag=-1, dy=-12, dx=16
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $ED,$66,0,0        ; path4: header (y=-19, x=102, relative to center)
    FCB $FF,$F1,$00          ; flag=-1, dy=-15, dx=0
    FCB $FF,$04,$F8          ; flag=-1, dy=4, dx=-8
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$06,$09          ; flag=-1, dy=6, dx=9
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $EE,$57,0,0        ; path5: header (y=-18, x=87, relative to center)
    FCB $FF,$F8,$05          ; flag=-1, dy=-8, dx=5
    FCB $FF,$F9,$FF          ; flag=-1, dy=-7, dx=-1
    FCB $FF,$05,$FA          ; flag=-1, dy=5, dx=-6
    FCB $FF,$0A,$02          ; flag=-1, dy=10, dx=2
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $E6,$72,0,0        ; path6: header (y=-26, x=114, relative to center)
    FCB $FF,$FD,$FB          ; flag=-1, dy=-3, dx=-5
    FCB $FF,$FB,$08          ; flag=-1, dy=-5, dx=8
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$04,$FD          ; flag=-1, dy=4, dx=-3
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $DD,$1A,0,0        ; path7: header (y=-35, x=26, relative to center)
    FCB $FF,$09,$08          ; flag=-1, dy=9, dx=8
    FCB $FF,$01,$FA          ; flag=-1, dy=1, dx=-6
    FCB $FF,$F7,$FA          ; flag=-1, dy=-9, dx=-6
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $4C,$B0,0,0        ; path8: header (y=76, x=-80, relative to center)
    FCB $FF,$FC,$0D          ; flag=-1, dy=-4, dx=13
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$FA,$08          ; flag=-1, dy=-6, dx=8
    FCB $FF,$09,$06          ; flag=-1, dy=9, dx=6
    FCB $FF,$09,$F2          ; flag=-1, dy=9, dx=-14
    FCB $FF,$FF,$F6          ; flag=-1, dy=-1, dx=-10
    FCB $FF,$FC,$FD          ; flag=-1, dy=-4, dx=-3
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $2D,$87,0,0        ; path9: header (y=45, x=-121, relative to center)
    FCB $FF,$F7,$08          ; flag=-1, dy=-9, dx=8
    FCB $FF,$F7,$F9          ; flag=-1, dy=-9, dx=-7
    FCB $FF,$E4,$17          ; flag=-1, dy=-28, dx=23
    FCB $FF,$FE,$16          ; flag=-1, dy=-2, dx=22
    FCB $FF,$09,$F6          ; flag=-1, dy=9, dx=-10
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$0D,$FE          ; flag=-1, dy=13, dx=-2
    FCB $FF,$09,$0E          ; flag=-1, dy=9, dx=14
    FCB $FF,$F9,$06          ; flag=-1, dy=-7, dx=6
    FCB $FF,$18,$13          ; flag=-1, dy=24, dx=19
    FCB $FF,$10,$F5          ; flag=-1, dy=16, dx=-11
    FCB $FF,$F4,$FD          ; flag=-1, dy=-12, dx=-3
    FCB $FF,$04,$F5          ; flag=-1, dy=4, dx=-11
    FCB $FF,$08,$01          ; flag=-1, dy=8, dx=1
    FCB $FF,$0A,$EE          ; flag=-1, dy=10, dx=-18
    FCB $FF,$06,$E7          ; flag=-1, dy=6, dx=-25
    FCB $FF,$DF,$01          ; flag=-1, dy=-33, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $04,$BE,0,0        ; path10: header (y=4, x=-66, relative to center)
    FCB $FF,$ED,$F8          ; flag=-1, dy=-19, dx=-8
    FCB $FF,$F9,$06          ; flag=-1, dy=-7, dx=6
    FCB $FF,$E0,$05          ; flag=-1, dy=-32, dx=5
    FCB $FF,$19,$14          ; flag=-1, dy=25, dx=20
    FCB $FF,$FF,$08          ; flag=-1, dy=-1, dx=8
    FCB $FF,$10,$00          ; flag=-1, dy=16, dx=0
    FCB $FF,$03,$F7          ; flag=-1, dy=3, dx=-9
    FCB $FF,$09,$F8          ; flag=-1, dy=9, dx=-8
    FCB $FF,$06,$F3          ; flag=-1, dy=6, dx=-13
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $B0,$AE,0,0        ; path11: header (y=-80, x=-82, relative to center)
    FCB $FF,$0D,$0C          ; flag=-1, dy=13, dx=12
    FCB $FF,$FB,$0D          ; flag=-1, dy=-5, dx=13
    FCB $FF,$F9,$08          ; flag=-1, dy=-7, dx=8
    FCB $FF,$FE,$DF          ; flag=-1, dy=-2, dx=-33
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $0E,$69,0,0        ; path12: header (y=14, x=105, relative to center)
    FCB $FF,$08,$FC          ; flag=-1, dy=8, dx=-4
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$F5,$00          ; flag=-1, dy=-11, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $24,$69,0,0        ; path13: header (y=36, x=105, relative to center)
    FCB $FF,$04,$07          ; flag=-1, dy=4, dx=7
    FCB $FF,$04,$F9          ; flag=-1, dy=4, dx=-7
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $21,$6D,0,0        ; path14: header (y=33, x=109, relative to center)
    FCB $FF,$F9,$FD          ; flag=-1, dy=-7, dx=-3
    FCB $FF,$FB,$02          ; flag=-1, dy=-5, dx=2
    FCB $FF,$FF,$03          ; flag=-1, dy=-1, dx=3
    FCB $FF,$05,$04          ; flag=-1, dy=5, dx=4
    FCB $FF,$08,$FC          ; flag=-1, dy=8, dx=-4
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)
; Generated from mayan_bg.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 20
; X bounds: min=-80, max=80, width=160
; Center: (0, 10)

_MAYAN_BG_WIDTH EQU 160
_MAYAN_BG_HALF_WIDTH EQU 80
_MAYAN_BG_CENTER_X EQU 0
_MAYAN_BG_CENTER_Y EQU 10

_MAYAN_BG_VECTORS:  ; Main entry (header + 5 path(s))
    FCB 5               ; path_count (runtime metadata)
    FDB _MAYAN_BG_PATH0        ; pointer to path 0
    FDB _MAYAN_BG_PATH1        ; pointer to path 1
    FDB _MAYAN_BG_PATH2        ; pointer to path 2
    FDB _MAYAN_BG_PATH3        ; pointer to path 3
    FDB _MAYAN_BG_PATH4        ; pointer to path 4

_MAYAN_BG_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $D8,$B0,0,0        ; path0: header (y=-40, x=-80, relative to center)
    FCB $FF,$00,$50          ; sub-seg 1/2 of line 0: dy=0, dx=80
    FCB $FF,$00,$50          ; sub-seg 2/2 of line 0: dy=0, dx=80
    FCB 2                ; End marker (path complete)

_MAYAN_BG_PATH1:    ; Path 1
    FCB 110              ; path1: intensity
    FCB $D8,$BA,0,0        ; path1: header (y=-40, x=-70, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$46          ; sub-seg 1/2 of line 1: dy=0, dx=70
    FCB $FF,$00,$46          ; sub-seg 2/2 of line 1: dy=0, dx=70
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_MAYAN_BG_PATH2:    ; Path 2
    FCB 110              ; path2: intensity
    FCB $E2,$C4,0,0        ; path2: header (y=-30, x=-60, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$78          ; flag=-1, dy=0, dx=120
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_MAYAN_BG_PATH3:    ; Path 3
    FCB 120              ; path3: intensity
    FCB $EC,$CE,0,0        ; path3: header (y=-20, x=-50, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$64          ; flag=-1, dy=0, dx=100
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_MAYAN_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $F6,$D8,0,0        ; path4: header (y=-10, x=-40, relative to center)
    FCB $FF,$28,$00          ; flag=-1, dy=40, dx=0
    FCB $FF,$0A,$0A          ; flag=-1, dy=10, dx=10
    FCB $FF,$00,$3C          ; flag=-1, dy=0, dx=60
    FCB $FF,$F6,$0A          ; flag=-1, dy=-10, dx=10
    FCB $FF,$D8,$00          ; flag=-1, dy=-40, dx=0
    FCB 2                ; End marker (path complete)
; Generated from newyork_bg.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 22
; X bounds: min=-25, max=25, width=50
; Center: (0, 27)

_NEWYORK_BG_WIDTH EQU 50
_NEWYORK_BG_HALF_WIDTH EQU 25
_NEWYORK_BG_CENTER_X EQU 0
_NEWYORK_BG_CENTER_Y EQU 27

_NEWYORK_BG_VECTORS:  ; Main entry (header + 5 path(s))
    FCB 5               ; path_count (runtime metadata)
    FDB _NEWYORK_BG_PATH0        ; pointer to path 0
    FDB _NEWYORK_BG_PATH1        ; pointer to path 1
    FDB _NEWYORK_BG_PATH2        ; pointer to path 2
    FDB _NEWYORK_BG_PATH3        ; pointer to path 3
    FDB _NEWYORK_BG_PATH4        ; pointer to path 4

_NEWYORK_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $21,$FB,0,0        ; path0: header (y=33, x=-5, relative to center)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

_NEWYORK_BG_PATH1:    ; Path 1
    FCB 110              ; path1: intensity
    FCB $0D,$00,0,0        ; path1: header (y=13, x=0, relative to center)
    FCB $FF,$0F,$0A          ; flag=-1, dy=15, dx=10
    FCB $FF,$05,$F6          ; flag=-1, dy=5, dx=-10
    FCB 2                ; End marker (path complete)

_NEWYORK_BG_PATH2:    ; Path 2
    FCB 110              ; path2: intensity
    FCB $0D,$F1,0,0        ; path2: header (y=13, x=-15, relative to center)
    FCB $FF,$CE,$00          ; flag=-1, dy=-50, dx=0
    FCB $FF,$00,$1E          ; flag=-1, dy=0, dx=30
    FCB $FF,$32,$00          ; flag=-1, dy=50, dx=0
    FCB 2                ; End marker (path complete)

_NEWYORK_BG_PATH3:    ; Path 3
    FCB 120              ; path3: intensity
    FCB $0D,$EC,0,0        ; path3: header (y=13, x=-20, relative to center)
    FCB $FF,$0A,$05          ; flag=-1, dy=10, dx=5
    FCB $FF,$FB,$05          ; flag=-1, dy=-5, dx=5
    FCB $FF,$07,$05          ; flag=-1, dy=7, dx=5
    FCB $FF,$F9,$05          ; flag=-1, dy=-7, dx=5
    FCB $FF,$07,$05          ; flag=-1, dy=7, dx=5
    FCB $FF,$F9,$05          ; flag=-1, dy=-7, dx=5
    FCB $FF,$05,$05          ; flag=-1, dy=5, dx=5
    FCB $FF,$F6,$05          ; flag=-1, dy=-10, dx=5
    FCB 2                ; End marker (path complete)

_NEWYORK_BG_PATH4:    ; Path 4
    FCB 100              ; path4: intensity
    FCB $DB,$E7,0,0        ; path4: header (y=-37, x=-25, relative to center)
    FCB $FF,$00,$32          ; flag=-1, dy=0, dx=50
    FCB 2                ; End marker (path complete)
; Generated from paris_bg.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 15
; X bounds: min=-50, max=50, width=100
; Center: (0, 17)

_PARIS_BG_WIDTH EQU 100
_PARIS_BG_HALF_WIDTH EQU 50
_PARIS_BG_CENTER_X EQU 0
_PARIS_BG_CENTER_Y EQU 17

_PARIS_BG_VECTORS:  ; Main entry (header + 5 path(s))
    FCB 5               ; path_count (runtime metadata)
    FDB _PARIS_BG_PATH0        ; pointer to path 0
    FDB _PARIS_BG_PATH1        ; pointer to path 1
    FDB _PARIS_BG_PATH2        ; pointer to path 2
    FDB _PARIS_BG_PATH3        ; pointer to path 3
    FDB _PARIS_BG_PATH4        ; pointer to path 4

_PARIS_BG_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $D1,$CE,0,0        ; path0: header (y=-47, x=-50, relative to center)
    FCB $FF,$1E,$1E          ; flag=-1, dy=30, dx=30
    FCB $FF,$1E,$0A          ; flag=-1, dy=30, dx=10
    FCB 2                ; End marker (path complete)

_PARIS_BG_PATH1:    ; Path 1
    FCB 100              ; path1: intensity
    FCB $D1,$32,0,0        ; path1: header (y=-47, x=50, relative to center)
    FCB $FF,$1E,$E2          ; flag=-1, dy=30, dx=-30
    FCB $FF,$1E,$F6          ; flag=-1, dy=30, dx=-10
    FCB 2                ; End marker (path complete)

_PARIS_BG_PATH2:    ; Path 2
    FCB 110              ; path2: intensity
    FCB $0D,$F6,0,0        ; path2: header (y=13, x=-10, relative to center)
    FCB $FF,$14,$05          ; flag=-1, dy=20, dx=5
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$EC,$05          ; flag=-1, dy=-20, dx=5
    FCB 2                ; End marker (path complete)

_PARIS_BG_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $21,$FB,0,0        ; path3: header (y=33, x=-5, relative to center)
    FCB $FF,$0F,$05          ; flag=-1, dy=15, dx=5
    FCB $FF,$F1,$05          ; flag=-1, dy=-15, dx=5
    FCB 2                ; End marker (path complete)

_PARIS_BG_PATH4:    ; Path 4
    FCB 90              ; path4: intensity
    FCB $EF,$EC,0,0        ; path4: header (y=-17, x=-20, relative to center)
    FCB $FF,$00,$28          ; flag=-1, dy=0, dx=40
    FCB 2                ; End marker (path complete)
; Generated from player_walk_1.vec (Malban Draw_Sync_List format)
; Total paths: 17, points: 62
; X bounds: min=-8, max=11, width=19
; Center: (1, 0)

_PLAYER_WALK_1_WIDTH EQU 19
_PLAYER_WALK_1_HALF_WIDTH EQU 9
_PLAYER_WALK_1_CENTER_X EQU 1
_PLAYER_WALK_1_CENTER_Y EQU 0

_PLAYER_WALK_1_VECTORS:  ; Main entry (header + 17 path(s))
    FCB 17               ; path_count (runtime metadata)
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
    FCB $0C,$FB,0,0        ; path0: header (y=12, x=-5, relative to center)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $0C,$F9,0,0        ; path1: header (y=12, x=-7, relative to center)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $0C,$FB,0,0        ; path2: header (y=12, x=-5, relative to center)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $08,$FA,0,0        ; path3: header (y=8, x=-6, relative to center)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $07,$FA,0,0        ; path4: header (y=7, x=-6, relative to center)
    FCB $FF,$FF,$FF          ; flag=-1, dy=-1, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $06,$F9,0,0        ; path5: header (y=6, x=-7, relative to center)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $00,$F9,0,0        ; path6: header (y=0, x=-7, relative to center)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $07,$04,0,0        ; path7: header (y=7, x=4, relative to center)
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $06,$06,0,0        ; path8: header (y=6, x=6, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $04,$06,0,0        ; path9: header (y=4, x=6, relative to center)
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $03,$07,0,0        ; path10: header (y=3, x=7, relative to center)
    FCB $FF,$00,$01          ; flag=-1, dy=0, dx=1
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $FE,$FB,0,0        ; path11: header (y=-2, x=-5, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $F8,$FB,0,0        ; path12: header (y=-8, x=-5, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $F2,$FB,0,0        ; path13: header (y=-14, x=-5, relative to center)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $FE,$01,0,0        ; path14: header (y=-2, x=1, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $F8,$01,0,0        ; path15: header (y=-8, x=1, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $F2,$01,0,0        ; path16: header (y=-14, x=1, relative to center)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)
; Generated from player_walk_2.vec (Malban Draw_Sync_List format)
; Total paths: 17, points: 62
; X bounds: min=-10, max=11, width=21
; Center: (0, -1)

_PLAYER_WALK_2_WIDTH EQU 21
_PLAYER_WALK_2_HALF_WIDTH EQU 10
_PLAYER_WALK_2_CENTER_X EQU 0
_PLAYER_WALK_2_CENTER_Y EQU -1

_PLAYER_WALK_2_VECTORS:  ; Main entry (header + 17 path(s))
    FCB 17               ; path_count (runtime metadata)
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
    FCB $0D,$FC,0,0        ; path0: header (y=13, x=-4, relative to center)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $0D,$FA,0,0        ; path1: header (y=13, x=-6, relative to center)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $0D,$FC,0,0        ; path2: header (y=13, x=-4, relative to center)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $09,$FB,0,0        ; path3: header (y=9, x=-5, relative to center)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $08,$FB,0,0        ; path4: header (y=8, x=-5, relative to center)
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $07,$F9,0,0        ; path5: header (y=7, x=-7, relative to center)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FC,$FF          ; flag=-1, dy=-4, dx=-1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$04,$01          ; flag=-1, dy=4, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $03,$F8,0,0        ; path6: header (y=3, x=-8, relative to center)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $08,$05,0,0        ; path7: header (y=8, x=5, relative to center)
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $07,$07,0,0        ; path8: header (y=7, x=7, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $05,$07,0,0        ; path9: header (y=5, x=7, relative to center)
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $04,$08,0,0        ; path10: header (y=4, x=8, relative to center)
    FCB $FF,$00,$01          ; flag=-1, dy=0, dx=1
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $FF,$FB,0,0        ; path11: header (y=-1, x=-5, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$01          ; flag=-1, dy=-6, dx=1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$FF          ; flag=-1, dy=6, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $F9,$FE,0,0        ; path12: header (y=-7, x=-2, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $F3,$00,0,0        ; path13: header (y=-13, x=0, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $FF,$02,0,0        ; path14: header (y=-1, x=2, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$F9,$01          ; flag=-1, dy=-7, dx=1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$07,$FF          ; flag=-1, dy=7, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $F8,$03,0,0        ; path15: header (y=-8, x=3, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$F9,$01          ; flag=-1, dy=-7, dx=1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$07,$FF          ; flag=-1, dy=7, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $F1,$04,0,0        ; path16: header (y=-15, x=4, relative to center)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)
; Generated from player_walk_3.vec (Malban Draw_Sync_List format)
; Total paths: 17, points: 62
; X bounds: min=-9, max=11, width=20
; Center: (1, -1)

_PLAYER_WALK_3_WIDTH EQU 20
_PLAYER_WALK_3_HALF_WIDTH EQU 10
_PLAYER_WALK_3_CENTER_X EQU 1
_PLAYER_WALK_3_CENTER_Y EQU -1

_PLAYER_WALK_3_VECTORS:  ; Main entry (header + 17 path(s))
    FCB 17               ; path_count (runtime metadata)
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
    FCB $0D,$FB,0,0        ; path0: header (y=13, x=-5, relative to center)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $0D,$F9,0,0        ; path1: header (y=13, x=-7, relative to center)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $0D,$FB,0,0        ; path2: header (y=13, x=-5, relative to center)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $09,$FA,0,0        ; path3: header (y=9, x=-6, relative to center)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $08,$FA,0,0        ; path4: header (y=8, x=-6, relative to center)
    FCB $FF,$FF,$FF          ; flag=-1, dy=-1, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $07,$F9,0,0        ; path5: header (y=7, x=-7, relative to center)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$F9,$FF          ; flag=-1, dy=-7, dx=-1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$07,$01          ; flag=-1, dy=7, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $00,$F8,0,0        ; path6: header (y=0, x=-8, relative to center)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $08,$04,0,0        ; path7: header (y=8, x=4, relative to center)
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $07,$06,0,0        ; path8: header (y=7, x=6, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $05,$06,0,0        ; path9: header (y=5, x=6, relative to center)
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $04,$07,0,0        ; path10: header (y=4, x=7, relative to center)
    FCB $FF,$00,$01          ; flag=-1, dy=0, dx=1
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $FF,$FA,0,0        ; path11: header (y=-1, x=-6, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$F9,$FF          ; flag=-1, dy=-7, dx=-1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$07,$01          ; flag=-1, dy=7, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $F8,$FB,0,0        ; path12: header (y=-8, x=-5, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $F2,$FB,0,0        ; path13: header (y=-14, x=-5, relative to center)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $FF,$02,0,0        ; path14: header (y=-1, x=2, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$F9,$01          ; flag=-1, dy=-7, dx=1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$07,$FF          ; flag=-1, dy=7, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $F8,$03,0,0        ; path15: header (y=-8, x=3, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $F2,$03,0,0        ; path16: header (y=-14, x=3, relative to center)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)
; Generated from player_walk_4.vec (Malban Draw_Sync_List format)
; Total paths: 17, points: 62
; X bounds: min=-8, max=11, width=19
; Center: (1, -1)

_PLAYER_WALK_4_WIDTH EQU 19
_PLAYER_WALK_4_HALF_WIDTH EQU 9
_PLAYER_WALK_4_CENTER_X EQU 1
_PLAYER_WALK_4_CENTER_Y EQU -1

_PLAYER_WALK_4_VECTORS:  ; Main entry (header + 17 path(s))
    FCB 17               ; path_count (runtime metadata)
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
    FCB $0D,$FB,0,0        ; path0: header (y=13, x=-5, relative to center)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $0D,$F9,0,0        ; path1: header (y=13, x=-7, relative to center)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $0D,$FB,0,0        ; path2: header (y=13, x=-5, relative to center)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $09,$FA,0,0        ; path3: header (y=9, x=-6, relative to center)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $08,$FA,0,0        ; path4: header (y=8, x=-6, relative to center)
    FCB $FF,$FF,$FF          ; flag=-1, dy=-1, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $07,$F9,0,0        ; path5: header (y=7, x=-7, relative to center)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $01,$F9,0,0        ; path6: header (y=1, x=-7, relative to center)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $08,$04,0,0        ; path7: header (y=8, x=4, relative to center)
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $07,$06,0,0        ; path8: header (y=7, x=6, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $05,$06,0,0        ; path9: header (y=5, x=6, relative to center)
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $04,$07,0,0        ; path10: header (y=4, x=7, relative to center)
    FCB $FF,$00,$01          ; flag=-1, dy=0, dx=1
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $FF,$FA,0,0        ; path11: header (y=-1, x=-6, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$F9,$01          ; flag=-1, dy=-7, dx=1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$07,$FF          ; flag=-1, dy=7, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $F8,$FD,0,0        ; path12: header (y=-8, x=-3, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $F1,$FF,0,0        ; path13: header (y=-15, x=-1, relative to center)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $FF,$01,0,0        ; path14: header (y=-1, x=1, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $F9,$01,0,0        ; path15: header (y=-7, x=1, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$FF          ; flag=-1, dy=-6, dx=-1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$01          ; flag=-1, dy=6, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $F3,$00,0,0        ; path16: header (y=-13, x=0, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)
; Generated from player_walk_5.vec (Malban Draw_Sync_List format)
; Total paths: 17, points: 62
; X bounds: min=-8, max=11, width=19
; Center: (1, 0)

_PLAYER_WALK_5_WIDTH EQU 19
_PLAYER_WALK_5_HALF_WIDTH EQU 9
_PLAYER_WALK_5_CENTER_X EQU 1
_PLAYER_WALK_5_CENTER_Y EQU 0

_PLAYER_WALK_5_VECTORS:  ; Main entry (header + 17 path(s))
    FCB 17               ; path_count (runtime metadata)
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
    FCB $0C,$FB,0,0        ; path0: header (y=12, x=-5, relative to center)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $0C,$F9,0,0        ; path1: header (y=12, x=-7, relative to center)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $0C,$FB,0,0        ; path2: header (y=12, x=-5, relative to center)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $08,$FA,0,0        ; path3: header (y=8, x=-6, relative to center)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $07,$FA,0,0        ; path4: header (y=7, x=-6, relative to center)
    FCB $FF,$FF,$FF          ; flag=-1, dy=-1, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $06,$F9,0,0        ; path5: header (y=6, x=-7, relative to center)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $01,$F9,0,0        ; path6: header (y=1, x=-7, relative to center)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $07,$04,0,0        ; path7: header (y=7, x=4, relative to center)
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $06,$06,0,0        ; path8: header (y=6, x=6, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $04,$06,0,0        ; path9: header (y=4, x=6, relative to center)
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $03,$07,0,0        ; path10: header (y=3, x=7, relative to center)
    FCB $FF,$00,$01          ; flag=-1, dy=0, dx=1
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $FE,$FB,0,0        ; path11: header (y=-2, x=-5, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $F8,$FB,0,0        ; path12: header (y=-8, x=-5, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $F2,$FB,0,0        ; path13: header (y=-14, x=-5, relative to center)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $FE,$01,0,0        ; path14: header (y=-2, x=1, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $F8,$01,0,0        ; path15: header (y=-8, x=1, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $F2,$01,0,0        ; path16: header (y=-14, x=1, relative to center)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)
; Generated from pyramids_bg.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 10
; X bounds: min=-90, max=90, width=180
; Center: (0, 0)

_PYRAMIDS_BG_WIDTH EQU 180
_PYRAMIDS_BG_HALF_WIDTH EQU 90
_PYRAMIDS_BG_CENTER_X EQU 0
_PYRAMIDS_BG_CENTER_Y EQU 0

_PYRAMIDS_BG_VECTORS:  ; Main entry (header + 4 path(s))
    FCB 4               ; path_count (runtime metadata)
    FDB _PYRAMIDS_BG_PATH0        ; pointer to path 0
    FDB _PYRAMIDS_BG_PATH1        ; pointer to path 1
    FDB _PYRAMIDS_BG_PATH2        ; pointer to path 2
    FDB _PYRAMIDS_BG_PATH3        ; pointer to path 3

_PYRAMIDS_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $D3,$A6,0,0        ; path0: header (y=-45, x=-90, relative to center)
    FCB $FF,$5A,$50          ; flag=-1, dy=90, dx=80
    FCB $FF,$A6,$50          ; flag=-1, dy=-90, dx=80
    FCB 2                ; End marker (path complete)

_PYRAMIDS_BG_PATH1:    ; Path 1
    FCB 100              ; path1: intensity
    FCB $D3,$A6,0,0        ; path1: header (y=-45, x=-90, relative to center)
    FCB $FF,$5A,$50          ; flag=-1, dy=90, dx=80
    FCB 2                ; End marker (path complete)

_PYRAMIDS_BG_PATH2:    ; Path 2
    FCB 80              ; path2: intensity
    FCB $2D,$F6,0,0        ; path2: header (y=45, x=-10, relative to center)
    FCB $FF,$A6,$50          ; flag=-1, dy=-90, dx=80
    FCB 2                ; End marker (path complete)

_PYRAMIDS_BG_PATH3:    ; Path 3
    FCB 90              ; path3: intensity
    FCB $D3,$1E,0,0        ; path3: header (y=-45, x=30, relative to center)
    FCB $FF,$2D,$1E          ; flag=-1, dy=45, dx=30
    FCB $FF,$D3,$1E          ; flag=-1, dy=-45, dx=30
    FCB 2                ; End marker (path complete)
; Generated from taj_bg.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 13
; X bounds: min=-70, max=70, width=140
; Center: (0, 22)

_TAJ_BG_WIDTH EQU 140
_TAJ_BG_HALF_WIDTH EQU 70
_TAJ_BG_CENTER_X EQU 0
_TAJ_BG_CENTER_Y EQU 22

_TAJ_BG_VECTORS:  ; Main entry (header + 4 path(s))
    FCB 4               ; path_count (runtime metadata)
    FDB _TAJ_BG_PATH0        ; pointer to path 0
    FDB _TAJ_BG_PATH1        ; pointer to path 1
    FDB _TAJ_BG_PATH2        ; pointer to path 2
    FDB _TAJ_BG_PATH3        ; pointer to path 3

_TAJ_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $12,$E2,0,0        ; path0: header (y=18, x=-30, relative to center)
    FCB $FF,$14,$0A          ; flag=-1, dy=20, dx=10
    FCB $FF,$05,$14          ; flag=-1, dy=5, dx=20
    FCB $FF,$FB,$14          ; flag=-1, dy=-5, dx=20
    FCB $FF,$EC,$0A          ; flag=-1, dy=-20, dx=10
    FCB 2                ; End marker (path complete)

_TAJ_BG_PATH1:    ; Path 1
    FCB 110              ; path1: intensity
    FCB $12,$D8,0,0        ; path1: header (y=18, x=-40, relative to center)
    FCB $FF,$CE,$00          ; flag=-1, dy=-50, dx=0
    FCB $FF,$00,$50          ; flag=-1, dy=0, dx=80
    FCB $FF,$32,$00          ; flag=-1, dy=50, dx=0
    FCB 2                ; End marker (path complete)

_TAJ_BG_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $D6,$BA,0,0        ; path2: header (y=-42, x=-70, relative to center)
    FCB $FF,$46,$00          ; flag=-1, dy=70, dx=0
    FCB 2                ; End marker (path complete)

_TAJ_BG_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $D6,$46,0,0        ; path3: header (y=-42, x=70, relative to center)
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
    FCB     $F0             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
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
    FCB     $F0             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
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
    FCB     $F2             ; Reg 7 value
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
    FCB     $FA             ; Reg 7 value
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
    FCB     $F2             ; Reg 7 value
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
    FCB     $FA             ; Reg 7 value
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
    FCB     $F0             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
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
    FCB     $F0             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
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
    FCB     $F2             ; Reg 7 value
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
    FCB     $FA             ; Reg 7 value
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
    FCB     $F2             ; Reg 7 value
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
    FCB     $FA             ; Reg 7 value
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
    FCB     $F0             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
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
    FCB     $F0             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
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
    FCB     $F2             ; Reg 7 value
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
    FCB     $FA             ; Reg 7 value
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
    FCB     $F2             ; Reg 7 value
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
    FCB     $FA             ; Reg 7 value
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
    FCB     $F0             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
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
    FCB     $F0             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
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
    FCB     $F2             ; Reg 7 value
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
    FCB     $FA             ; Reg 7 value
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
    FCB     $F2             ; Reg 7 value
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
    FCB     $FA             ; Reg 7 value
    FCB     8              ; Delay 8 frames before loop
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
    FCB     $F0             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
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
    FCB     $F0             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
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
    FCB     $F0             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
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
    FCB     $F0             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
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
    FCB     $F0             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
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
    FCB     $F0             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
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
    FCB     $F0             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
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
    FCB     $F0             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
    FCB     38              ; Delay 38 frames before loop
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

_FUJI_LEVEL1_V2_BG_OBJECTS:
; Object: obj_1767470884207 (enemy)
    FCB 1  ; type
    FDB 0  ; x
    FDB 0  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _FUJI_BG_VECTORS  ; vector_ptr
    FCB _FUJI_BG_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)


_FUJI_LEVEL1_V2_GAMEPLAY_OBJECTS:
; Object: enemy_1 (enemy)
    FCB 1  ; type
    FDB -40  ; x
    FDB 60  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 127  ; intensity (0=use vec, >0=override)
    FCB 255  ; velocity_x
    FCB 255  ; velocity_y
    FCB 3  ; physics_flags
    FCB 7  ; collision_flags
    FCB 20  ; collision_size
    FDB 0  ; spawn_delay
    FDB _BUBBLE_LARGE_VECTORS  ; vector_ptr
    FCB _BUBBLE_LARGE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)

; Object: enemy_2 (enemy)
    FCB 1  ; type
    FDB 40  ; x
    FDB 60  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 127  ; intensity (0=use vec, >0=override)
    FCB 1  ; velocity_x
    FCB 255  ; velocity_y
    FCB 3  ; physics_flags
    FCB 7  ; collision_flags
    FCB 20  ; collision_size
    FDB 60  ; spawn_delay
    FDB _BUBBLE_LARGE_VECTORS  ; vector_ptr
    FCB _BUBBLE_LARGE_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)


_FUJI_LEVEL1_V2_FG_OBJECTS:

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

MUL16:
    ; Multiply 16-bit X * D -> D
    ; Simple implementation (can be optimized)
    PSHS X,B,A
    LDD #0         ; Result accumulator
    LDX 2,S        ; Multiplier
.MUL16_LOOP:
    BEQ .MUL16_END
    ADDD ,S        ; Add multiplicand
    LEAX -1,X
    BRA .MUL16_LOOP
.MUL16_END:
    LEAS 4,S
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

; J1_Y() - Read Joystick 1 Y axis (INCREMENTAL - with state preservation)
; Returns: D = raw value from $C81C after Joy_Analog call
J1Y_BUILTIN:
    PSHS X       ; Save X (Joy_Analog uses it)
    JSR $F1AA    ; DP_to_D0 (required for Joy_Analog BIOS call)
    JSR $F1F5    ; Joy_Analog (updates $C81C from hardware)
    JSR Reset0Ref ; Full beam reset: zeros DAC (VIA_port_a=0) via Reset_Pen + grounds integrators
    JSR $F1AF    ; DP_to_C8 (required to read RAM $C81C)
    LDB $C81C    ; Vec_Joy_1_Y (BIOS writes ~$FE at center)
    SEX          ; Sign-extend B to D
    ADDD #2      ; Calibrate center offset
    PULS X       ; Restore X
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
; NOTE: Caller must ensure DP=$D0 for VIA access
; CRITICAL: Do NOT call JSR $F2AB (Intensity_a) here! With DP=$D0,
; Intensity_a does STA <$32 which hits $D032 = VIA DDRB (reg $02),
; setting PB0 as input and breaking the X/Y integrator mux entirely.
; Fix: write Vec_Misc_Count ($C832) directly via extended addressing.
LDA >DRAW_VEC_INTENSITY ; Check if intensity override is set
BNE DSWM_USE_OVERRIDE   ; If non-zero, use override
LDA ,X+                 ; Otherwise, read intensity from vector data
BRA DSWM_SET_INTENSITY
DSWM_USE_OVERRIDE:
LEAX 1,X                ; Skip intensity byte in vector data
DSWM_SET_INTENSITY:
STA >$C832              ; Set Vec_Misc_Count directly (DP-safe, no DDRB corruption)
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
; Timing setup
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
STA >$C832              ; Set Vec_Misc_Count directly (DP-safe, no DDRB corruption)
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
    
    ; Store level pointer persistently
    STX >LEVEL_PTR
    
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
LDB #$FF                ; All channels disabled
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
BEQ PSG_update_done     ; No music loaded

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
BEQ AU_SKIP_MUSIC       ; Skip if null
BRA AU_MUSIC_READ_COUNT ; Skip delay read, go straight to count

AU_MUSIC_READ:
LDX >PSG_MUSIC_PTR      ; Load music pointer
BEQ AU_SKIP_MUSIC       ; Skip if null

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
PRINT_TEXT_STR_107868:
    FCC "map"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3208483:
    FCC "hook"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3327403:
    FCC "logo"
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

