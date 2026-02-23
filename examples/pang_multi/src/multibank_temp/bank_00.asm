; VPy M6809 Assembly (Vectrex)
; ROM: 524288 bytes
; Multibank cartridge: 32 banks (16KB each)
; Helpers bank: 31 (fixed bank at $4000-$7FFF)

; ================================================


; === RAM VARIABLE DEFINITIONS ===
;***************************************************************************
RESULT               EQU $C880+$00   ; Main result temporary (2 bytes)
TMPVAL               EQU $C880+$02   ; Temporary value storage (alias for RESULT) (2 bytes)
TMPPTR               EQU $C880+$04   ; Temporary pointer (2 bytes)
TMPPTR2              EQU $C880+$06   ; Temporary pointer 2 (2 bytes)
TEMP_YX              EQU $C880+$08   ; Temporary Y/X coordinate storage (2 bytes)
DRAW_VEC_X           EQU $C880+$0A   ; Vector draw X offset (1 bytes)
DRAW_VEC_Y           EQU $C880+$0B   ; Vector draw Y offset (1 bytes)
DRAW_VEC_INTENSITY   EQU $C880+$0C   ; Vector intensity override (0=use vector data) (1 bytes)
MIRROR_PAD           EQU $C880+$0D   ; Safety padding to prevent MIRROR flag corruption (16 bytes)
MIRROR_X             EQU $C880+$1D   ; X mirror flag (0=normal, 1=flip) (1 bytes)
MIRROR_Y             EQU $C880+$1E   ; Y mirror flag (0=normal, 1=flip) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$1F   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$29   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$2B   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$2D   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$2E   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$2F   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$31   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
LEVEL_PTR            EQU $C880+$33   ; Pointer to currently loaded level data (2 bytes)
LEVEL_WIDTH          EQU $C880+$35   ; Level width (1 bytes)
LEVEL_HEIGHT         EQU $C880+$36   ; Level height (1 bytes)
LEVEL_TILE_SIZE      EQU $C880+$37   ; Tile size (1 bytes)
PSG_MUSIC_PTR        EQU $C880+$38   ; PSG music data pointer (2 bytes)
PSG_MUSIC_START      EQU $C880+$3A   ; PSG music start pointer (for loops) (2 bytes)
PSG_MUSIC_ACTIVE     EQU $C880+$3C   ; PSG music active flag (1 bytes)
PSG_IS_PLAYING       EQU $C880+$3D   ; PSG playing flag (1 bytes)
PSG_DELAY_FRAMES     EQU $C880+$3E   ; PSG frame delay counter (1 bytes)
PSG_MUSIC_BANK       EQU $C880+$3F   ; PSG music bank ID (for multibank) (1 bytes)
SFX_PTR              EQU $C880+$40   ; SFX data pointer (2 bytes)
SFX_ACTIVE           EQU $C880+$42   ; SFX active flag (1 bytes)
VAR_STATE_TITLE      EQU $C880+$43   ; User variable: STATE_TITLE (2 bytes)
VAR_STATE_MAP        EQU $C880+$45   ; User variable: STATE_MAP (2 bytes)
VAR_STATE_GAME       EQU $C880+$47   ; User variable: STATE_GAME (2 bytes)
VAR_SCREEN           EQU $C880+$49   ; User variable: screen (2 bytes)
VAR_TITLE_INTENSITY  EQU $C880+$4B   ; User variable: title_intensity (2 bytes)
VAR_TITLE_STATE      EQU $C880+$4D   ; User variable: title_state (2 bytes)
VAR_CURRENT_MUSIC    EQU $C880+$4F   ; User variable: current_music (2 bytes)
VAR_LOCATION_X_COORDS EQU $C880+$51   ; User variable: location_x_coords (2 bytes)
VAR_LOCATION_Y_COORDS EQU $C880+$53   ; User variable: location_y_coords (2 bytes)
VAR_LOCATION_NAMES   EQU $C880+$55   ; User variable: location_names (2 bytes)
VAR_LEVEL_BACKGROUNDS EQU $C880+$57   ; User variable: level_backgrounds (2 bytes)
VAR_LEVEL_ENEMY_COUNT EQU $C880+$59   ; User variable: level_enemy_count (2 bytes)
VAR_LEVEL_ENEMY_SPEED EQU $C880+$5B   ; User variable: level_enemy_speed (2 bytes)
VAR_NUM_LOCATIONS    EQU $C880+$5D   ; User variable: num_locations (2 bytes)
VAR_CURRENT_LOCATION EQU $C880+$5F   ; User variable: current_location (2 bytes)
VAR_LOCATION_GLOW_INTENSITY EQU $C880+$61   ; User variable: location_glow_intensity (2 bytes)
VAR_LOCATION_GLOW_DIRECTION EQU $C880+$63   ; User variable: location_glow_direction (2 bytes)
VAR_JOY_X            EQU $C880+$65   ; User variable: joy_x (2 bytes)
VAR_JOY_Y            EQU $C880+$67   ; User variable: joy_y (2 bytes)
VAR_PREV_JOY_X       EQU $C880+$69   ; User variable: prev_joy_x (2 bytes)
VAR_PREV_JOY_Y       EQU $C880+$6B   ; User variable: prev_joy_y (2 bytes)
VAR_COUNTDOWN_TIMER  EQU $C880+$6D   ; User variable: countdown_timer (2 bytes)
VAR_COUNTDOWN_ACTIVE EQU $C880+$6F   ; User variable: countdown_active (2 bytes)
VAR_JOYSTICK_POLL_COUNTER EQU $C880+$71   ; User variable: joystick_poll_counter (2 bytes)
VAR_HOOK_ACTIVE      EQU $C880+$73   ; User variable: hook_active (2 bytes)
VAR_HOOK_X           EQU $C880+$75   ; User variable: hook_x (2 bytes)
VAR_HOOK_Y           EQU $C880+$77   ; User variable: hook_y (2 bytes)
VAR_HOOK_MAX_Y       EQU $C880+$79   ; User variable: hook_max_y (2 bytes)
VAR_HOOK_GUN_X       EQU $C880+$7B   ; User variable: hook_gun_x (2 bytes)
VAR_HOOK_GUN_Y       EQU $C880+$7D   ; User variable: hook_gun_y (2 bytes)
VAR_HOOK_INIT_Y      EQU $C880+$7F   ; User variable: hook_init_y (2 bytes)
VAR_PLAYER_X         EQU $C880+$81   ; User variable: player_x (2 bytes)
VAR_PLAYER_Y         EQU $C880+$83   ; User variable: player_y (2 bytes)
VAR_MOVE_SPEED       EQU $C880+$85   ; User variable: move_speed (2 bytes)
VAR_ABS_JOY          EQU $C880+$87   ; User variable: abs_joy (2 bytes)
VAR_PLAYER_ANIM_FRAME EQU $C880+$89   ; User variable: player_anim_frame (2 bytes)
VAR_PLAYER_ANIM_COUNTER EQU $C880+$8B   ; User variable: player_anim_counter (2 bytes)
VAR_PLAYER_ANIM_SPEED EQU $C880+$8D   ; User variable: player_anim_speed (2 bytes)
VAR_PLAYER_FACING    EQU $C880+$8F   ; User variable: player_facing (2 bytes)
VAR_MAX_ENEMIES      EQU $C880+$91   ; User variable: MAX_ENEMIES (2 bytes)
VAR_GRAVITY          EQU $C880+$93   ; User variable: GRAVITY (2 bytes)
VAR_BOUNCE_DAMPING   EQU $C880+$95   ; User variable: BOUNCE_DAMPING (2 bytes)
VAR_MIN_BOUNCE_VY    EQU $C880+$97   ; User variable: MIN_BOUNCE_VY (2 bytes)
VAR_GROUND_Y         EQU $C880+$99   ; User variable: GROUND_Y (2 bytes)
VAR_JOYSTICK1_STATE  EQU $C880+$9B   ; User variable: joystick1_state (2 bytes)
VAR_LOC_X            EQU $C880+$9D   ; User variable: loc_x (2 bytes)
VAR_LOC_Y            EQU $C880+$9F   ; User variable: loc_y (2 bytes)
VAR_ANIM_THRESHOLD   EQU $C880+$A1   ; User variable: anim_threshold (2 bytes)
VAR_MIRROR_MODE      EQU $C880+$A3   ; User variable: mirror_mode (2 bytes)
VAR_ACTIVE_COUNT     EQU $C880+$A5   ; User variable: active_count (2 bytes)
VAR_I                EQU $C880+$A7   ; User variable: i (2 bytes)
VAR_ENEMY_ACTIVE     EQU $C880+$A9   ; User variable: enemy_active (2 bytes)
VAR_COUNT            EQU $C880+$AB   ; User variable: count (2 bytes)
VAR_SPEED            EQU $C880+$AD   ; User variable: speed (2 bytes)
VAR_ENEMY_SIZE       EQU $C880+$AF   ; User variable: enemy_size (2 bytes)
VAR_ENEMY_X          EQU $C880+$B1   ; User variable: enemy_x (2 bytes)
VAR_ENEMY_Y          EQU $C880+$B3   ; User variable: enemy_y (2 bytes)
VAR_ENEMY_VX         EQU $C880+$B5   ; User variable: enemy_vx (2 bytes)
VAR_ENEMY_VY         EQU $C880+$B7   ; User variable: enemy_vy (2 bytes)
VAR_START_X          EQU $C880+$B9   ; User variable: start_x (2 bytes)
VAR_START_Y          EQU $C880+$BB   ; User variable: start_y (2 bytes)
VAR_END_X            EQU $C880+$BD   ; User variable: end_x (2 bytes)
VAR_END_Y            EQU $C880+$BF   ; User variable: end_y (2 bytes)
VAR_JOYSTICK1_STATE_DATA EQU $C880+$C1   ; Mutable array 'joystick1_state' data (6 elements x 2 bytes) (12 bytes)
VAR_ENEMY_ACTIVE_DATA EQU $C880+$CD   ; Mutable array 'enemy_active' data (8 elements x 2 bytes) (16 bytes)
VAR_ENEMY_X_DATA     EQU $C880+$DD   ; Mutable array 'enemy_x' data (8 elements x 2 bytes) (16 bytes)
VAR_ENEMY_Y_DATA     EQU $C880+$ED   ; Mutable array 'enemy_y' data (8 elements x 2 bytes) (16 bytes)
VAR_ENEMY_VX_DATA    EQU $C880+$FD   ; Mutable array 'enemy_vx' data (8 elements x 2 bytes) (16 bytes)
VAR_ENEMY_VY_DATA    EQU $C880+$10D   ; Mutable array 'enemy_vy' data (8 elements x 2 bytes) (16 bytes)
VAR_ENEMY_SIZE_DATA  EQU $C880+$11D   ; Mutable array 'enemy_size' data (8 elements x 2 bytes) (16 bytes)
VAR_ARG0             EQU $CFE0   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $CFE2   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $CFE4   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $CFE6   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $CFE8   ; Function argument 4 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $CFEA   ; Current ROM bank ID (multibank tracking) (1 bytes)


; ================================================

; VPy M6809 Assembly (Vectrex)
; ROM: 524288 bytes
; Multibank cartridge: 32 banks (16KB each)
; Helpers bank: 31 (fixed bank at $4000-$7FFF)

; ================================================

    ORG $0000

;***************************************************************************
; DEFINE SECTION
;***************************************************************************
    INCLUDE "VECTREX.I"
; External symbols (helpers, BIOS, and shared data)
OBJ_WILL_HIT EQU $F8F3
VEC_SWI3_VECTOR EQU $CBF2
Vec_Music_Wk_A EQU $C842
_PLAYER_WALK_2_PATH5 EQU $087C
DRAW_VLP_SCALE EQU $F40C
_PLAYER_WALK_1_PATH14 EQU $07DB
PRINT_TEXT_STR_94134666982268 EQU $46EB
_PLAYER_WALK_3_PATH4 EQU $09AD
DELAY_B EQU $F57A
DRAW_PAT_VL_A EQU $F434
VEC_BUTTON_2_2 EQU $C817
PRINT_TEXT_STR_107868 EQU $4672
MUSIC4 EQU $FDD3
Clear_Score EQU $F84F
Vec_Expl_Chan EQU $C85C
Rise_Run_Angle EQU $F593
_PANG_THEME_MUSIC EQU $04DF
_PLAYER_WALK_5_PATH11 EQU $0C8D
LEVEL_ADDR_TABLE EQU $4067
VEC_EXPL_2 EQU $C859
SOUND_BYTE EQU $F256
_BARCELONA_BG_PATH1 EQU $1168
VEC_SEED_PTR EQU $C87B
DELAY_2 EQU $F571
VEC_BTN_STATE EQU $C80F
Vec_Counters EQU $C82E
MOVE_MEM_A EQU $F683
_MAYAN_BG_PATH2 EQU $1025
VEC_RFRSH EQU $C83D
DSWM_NEXT_PATH EQU $43F1
_PARIS_BG_PATH4 EQU $12CF
Wait_Recal EQU $F192
_LONDON_BG_PATH3 EQU $130E
Get_Rise_Run EQU $F5EF
MOV_DRAW_VLC_A EQU $F3AD
ABS_A_B EQU $F584
Vec_Text_Width EQU $C82B
STRIP_ZEROS EQU $F8B7
Delay_1 EQU $F575
LOAD_LEVEL_BANKED EQU $416F
_PLAYER_WALK_3_PATH14 EQU $0A4F
Dec_Counters EQU $F563
PRINT_TEXT_STR_17258163498655081052 EQU $47DE
_FUJI_BG_PATH4 EQU $0E65
XFORM_RUN EQU $F65D
SELECT_GAME EQU $F7A9
AU_MUSIC_LOOP EQU $459C
Vec_Rfrsh EQU $C83D
_PLAYER_WALK_3_PATH11 EQU $0A19
Vec_Joy_1_Y EQU $C81C
music3 EQU $FD81
Mov_Draw_VLc_a EQU $F3AD
Vec_Counter_3 EQU $C830
_PLAYER_WALK_1_PATH1 EQU $070C
Vec_Loop_Count EQU $C825
AU_MUSIC_NO_DELAY EQU $455E
_PLAYER_WALK_2_PATH9 EQU $08BB
Vec_Joy_Mux_1_X EQU $C81F
VEC_SWI_VECTOR EQU $CBFB
ASSET_BANK_TABLE EQU $4069
_ANTARCTICA_BG_VECTORS EQU $13D5
PLAY_SFX_BANKED EQU $4144
VEC_MUSIC_WK_6 EQU $C846
Vec_Button_1_3 EQU $C814
PRINT_TEXT_STR_86894009833752 EQU $46D7
_PLAYER_WALK_1_PATH6 EQU $0754
_ATHENS_BG_PATH0 EQU $110B
VEC_MUSIC_WK_A EQU $C842
_ANTARCTICA_BG_PATH1 EQU $13EA
_PLAYER_WALK_1_PATH11 EQU $07A5
_HOOK_PATH0 EQU $1506
SFX_CHECKTONEDISABLE EQU $461A
_PYRAMIDS_BG_PATH2 EQU $1496
_PLAYER_WALK_4_PATH1 EQU $0ABA
Vec_FIRQ_Vector EQU $CBF5
PSG_write_loop EQU $44BA
DLW_SEG1_DY_READY EQU $429C
Vec_Music_Wk_5 EQU $C847
Vec_Cold_Flag EQU $CBFE
_PLAYER_WALK_3_VECTORS EQU $094B
_PLAYER_WALK_3_PATH9 EQU $09F5
_EASTER_BG_PATH2 EQU $10D2
_MAP_PATH6 EQU $03E0
Delay_2 EQU $F571
CLEAR_SOUND EQU $F272
DRAW_VL_MODE EQU $F46E
Vec_Duration EQU $C857
Print_List EQU $F38A
_AYERS_BG_PATH0 EQU $1415
Get_Run_Idx EQU $F5DB
NEW_HIGH_SCORE EQU $F8D8
Print_List_chk EQU $F38C
SFX_ENABLENOISE EQU $464E
Obj_Will_Hit EQU $F8F3
PRINT_TEXT_STR_88916199021370 EQU $46E1
SFX_CHECKNOISEDISABLE EQU $4639
MUSIC6 EQU $FE76
_ANTARCTICA_BG_PATH0 EQU $13DE
_PLAYER_WALK_1_PATH15 EQU $07ED
_PLAYER_WALK_4_PATH8 EQU $0B1D
PSG_music_loop EQU $44F7
Draw_VLp_FF EQU $F404
Dot_ix_b EQU $F2BE
_TAJ_BG_PATH0 EQU $13A2
RESET0INT EQU $F36B
PSG_update_done EQU $44FF
UPDATE_MUSIC_PSG EQU $4499
DLW_DONE EQU $432C
_FUJI_BG_PATH5 EQU $0E77
STOP_MUSIC_RUNTIME EQU $4503
INTENSITY_3F EQU $F2A1
COLD_START EQU $F000
Print_List_hw EQU $F385
_PLAYER_WALK_5_PATH5 EQU $0C2A
RISE_RUN_Y EQU $F601
Add_Score_a EQU $F85E
VEC_JOY_MUX EQU $C81F
_PYRAMIDS_BG_PATH1 EQU $148D
_MAP_VECTORS EQU $02A4
Vec_Music_Chan EQU $C855
Joy_Digital EQU $F1F8
_PARIS_BG_PATH0 EQU $129C
Mov_Draw_VL EQU $F3BC
VEC_NUM_PLAYERS EQU $C879
Bitmask_a EQU $F57E
_PYRAMIDS_BG_PATH0 EQU $1481
ROT_VL EQU $F616
VEC_DOT_DWELL EQU $C828
Vec_Expl_3 EQU $C85A
DLW_SEG1_DX_READY EQU $42BF
_PLAYER_WALK_3_PATH2 EQU $0989
_FUJI_BG_VECTORS EQU $0DE0
PRINT_LIST_CHK EQU $F38C
DOT_LIST_RESET EQU $F2DE
DLW_SEG2_DX_NO_REMAIN EQU $431A
Set_Refresh EQU $F1A2
ADD_SCORE_A EQU $F85E
VEC_JOY_RESLTN EQU $C81A
SFX_NEXTFRAME EQU $4658
AU_UPDATE_SFX EQU $45AA
PRINT_TEXT_STR_103315 EQU $466E
Move_Mem_a EQU $F683
SFX_ADDR_TABLE EQU $4062
_BUBBLE_HUGE_VECTORS EQU $1527
Compare_Score EQU $F8C7
Vec_Angle EQU $C836
INIT_VIA EQU $F14C
PRINT_TEXT_STR_3047088743154868 EQU $4714
Sound_Byte_raw EQU $F25B
Draw_VLp_scale EQU $F40C
CLEAR_X_D EQU $F548
PRINT_TEXT_STR_86017190903439 EQU $46CD
Select_Game EQU $F7A9
_PLAYER_WALK_3_PATH12 EQU $0A2B
RISE_RUN_X EQU $F5FF
Dot_here EQU $F2C5
DO_SOUND EQU $F289
READ_BTNS_MASK EQU $F1B4
VEC_EXPL_CHANA EQU $C853
DRAW_VL EQU $F3DD
DOT_HERE EQU $F2C5
Random_3 EQU $F511
PSG_WRITE_LOOP EQU $44BA
_PLAYER_WALK_2_PATH12 EQU $08F1
DRAW_VLP_7F EQU $F408
VEC_MUSIC_WK_5 EQU $C847
VEC_EXPL_CHANB EQU $C85D
VEC_MUSIC_FREQ EQU $C861
Intensity_5F EQU $F2A5
Reset0Ref_D0 EQU $F34A
Vec_Max_Games EQU $C850
Vec_SWI_Vector EQU $CBFB
Vec_Joy_2_Y EQU $C81E
Abs_b EQU $F58B
JOY_DIGITAL EQU $F1F8
VEC_MUSIC_WK_1 EQU $C84B
VEC_MAX_PLAYERS EQU $C84F
VECTOR_BANK_TABLE EQU $4000
DELAY_0 EQU $F579
Vec_Music_Wk_7 EQU $C845
_PLAYER_WALK_3_PATH13 EQU $0A3D
_MAP_PATH14 EQU $04C4
Vec_Joy_Mux_2_Y EQU $C822
sfx_checknoisedisable EQU $4639
VEC_MUSIC_WORK EQU $C83F
VEC_RISERUN_LEN EQU $C83B
DP_TO_D0 EQU $F1AA
_KEIRIN_BG_PATH1 EQU $14C4
_ATHENS_BG_PATH4 EQU $1132
CLEAR_SCORE EQU $F84F
Rise_Run_X EQU $F5FF
ADD_SCORE_D EQU $F87C
Vec_Music_Work EQU $C83F
AU_MUSIC_READ EQU $4549
VEC_PREV_BTNS EQU $C810
PLAY_SFX_RUNTIME EQU $45BF
Vec_Expl_ChanB EQU $C85D
VEC_DURATION EQU $C857
VEC_BUTTON_1_1 EQU $C812
PRINT_TEXT_STR_85851400383728 EQU $46C3
_BARCELONA_BG_PATH0 EQU $1156
SFX_ENDOFEFFECT EQU $465D
_BUDDHA_BG_VECTORS EQU $1445
Delay_b EQU $F57A
VEC_EXPL_3 EQU $C85A
VEC_TWANG_TABLE EQU $C851
MOV_DRAW_VLCS EQU $F3B5
_EASTER_BG_PATH1 EQU $10C9
_BARCELONA_BG_VECTORS EQU $114D
sfx_checktonedisable EQU $461A
Init_OS_RAM EQU $F164
DOT_D EQU $F2C3
_PLAYER_WALK_4_PATH13 EQU $0B77
VEC_COUNTERS EQU $C82E
DSWM_W2 EQU $43E2
PRINT_TEXT_STR_3413815335 EQU $4686
Init_Music_x EQU $F692
_BUBBLE_LARGE_VECTORS EQU $119E
DELAY_RTS EQU $F57D
Draw_VLc EQU $F3CE
DSWM_W1 EQU $439D
_BUBBLE_MEDIUM_PATH0 EQU $11F2
NOAY EQU $45D2
VEC_ADSR_TABLE EQU $C84F
Vec_High_Score EQU $CBEB
_PLAYER_WALK_5_PATH14 EQU $0CC3
_LONDON_BG_VECTORS EQU $12D8
PMR_START_NEW EQU $448A
_FUJI_BG_PATH0 EQU $0DED
VEC_ADSR_TIMERS EQU $C85E
_MAYAN_BG_PATH4 EQU $1043
Draw_VL_ab EQU $F3D8
MOV_DRAW_VL_B EQU $F3B1
VEC_BUTTON_1_4 EQU $C815
DP_to_D0 EQU $F1AA
_BUBBLE_LARGE_PATH0 EQU $11A1
_ATHENS_BG_PATH2 EQU $1120
Vec_Rfrsh_hi EQU $C83E
PRINT_TEXT_STR_4990555610362249649 EQU $477A
DLW_SEG1_DX_NO_CLAMP EQU $42BC
OBJ_WILL_HIT_U EQU $F8E5
_BUDDHA_BG_PATH3 EQU $146F
DSWM_W3 EQU $446C
VEC_BUTTON_2_4 EQU $C819
DLW_SEG2_DY_DONE EQU $42F8
VEC_COUNTER_5 EQU $C832
Abs_a_b EQU $F584
_NEWYORK_BG_PATH3 EQU $0F44
INIT_MUSIC EQU $F68D
VEC_STR_PTR EQU $C82C
Vec_Text_HW EQU $C82A
SFX_CHECKNOISEFREQ EQU $4600
MOVETO_IX_7F EQU $F30C
DSWM_DONE EQU $447B
Moveto_x_7F EQU $F2F2
PSG_FRAME_DONE EQU $44EB
_KILIMANJARO_BG_PATH3 EQU $1390
_BUDDHA_BG_PATH0 EQU $144E
VEC_COUNTER_3 EQU $C830
Xform_Run EQU $F65D
Move_Mem_a_1 EQU $F67F
DLW_SEG2_DX_DONE EQU $431D
_PYRAMIDS_BG_VECTORS EQU $1478
MUSICB EQU $FF62
_LOCATION_MARKER_PATH0 EQU $14DF
J1X_BUILTIN EQU $4220
MOV_DRAW_VL EQU $F3BC
VEC_BUTTON_2_1 EQU $C816
DLW_SEG1_DY_LO EQU $428C
_LOGO_VECTORS EQU $0CF9
PRINT_TEXT_STR_2997885107879189 EQU $4709
Vec_Prev_Btns EQU $C810
MUSIC8 EQU $FEF8
Vec_Rfrsh_lo EQU $C83D
Xform_Run_a EQU $F65B
MUSIC3 EQU $FD81
VEC_MUSIC_CHAN EQU $C855
Vec_Brightness EQU $C827
_EASTER_BG_PATH4 EQU $10F3
Obj_Will_Hit_u EQU $F8E5
DSWM_NO_NEGATE_Y EQU $434C
_PLAYER_WALK_2_PATH7 EQU $08A0
Clear_x_d EQU $F548
_PLAYER_WALK_1_PATH4 EQU $0739
_MAP_PATH4 EQU $03B6
sfx_disablenoise EQU $4641
_KILIMANJARO_BG_PATH1 EQU $1378
_PLAYER_WALK_3_PATH0 EQU $096E
_EASTER_BG_VECTORS EQU $10A9
Vec_Snd_Shadow EQU $C800
_AYERS_BG_VECTORS EQU $140E
EXPLOSION_SND EQU $F92E
_PLAYER_WALK_5_PATH9 EQU $0C69
_PLAYER_WALK_5_VECTORS EQU $0BBF
Vec_Expl_2 EQU $C859
Vec_SWI3_Vector EQU $CBF2
DSWM_NEXT_NO_NEGATE_X EQU $441C
Intensity_a EQU $F2AB
_ANTARCTICA_BG_PATH2 EQU $13F9
Clear_x_b EQU $F53F
_NEWYORK_BG_PATH2 EQU $0F35
_MAP_PATH9 EQU $0428
PMR_DONE EQU $4498
PRINT_TEXT_STR_3088519875410 EQU $46A7
OBJ_HIT EQU $F8FF
VEC_JOY_MUX_1_X EQU $C81F
_PYRAMIDS_BG_PATH3 EQU $149F
MOVETO_IX_FF EQU $F308
_AYERS_BG_PATH2 EQU $1439
sfx_checkvolume EQU $4611
VEC_EXPL_4 EQU $C85B
_LOGO_PATH5 EQU $0DA7
_BUBBLE_SMALL_VECTORS EQU $1240
music4 EQU $FDD3
Vec_Btn_State EQU $C80F
_LENINGRAD_BG_PATH1 EQU $0FC6
VECTOR_ADDR_TABLE EQU $401E
_TAJ_BG_VECTORS EQU $1399
PRINT_TEXT_STR_2829898994950197404 EQU $475E
Get_Rise_Idx EQU $F5D9
Vec_Max_Players EQU $C84F
VEC_FIRQ_VECTOR EQU $CBF5
sfx_checknoisefreq EQU $4600
_PLAYER_WALK_2_PATH16 EQU $0939
RESET0REF EQU $F354
Draw_VL_a EQU $F3DA
DOT_LIST EQU $F2D5
VEC_JOY_2_Y EQU $C81E
_KILIMANJARO_BG_PATH0 EQU $1366
AU_SKIP_MUSIC EQU $45A7
_ANTARCTICA_BG_PATH3 EQU $1405
Dot_d EQU $F2C3
_BARCELONA_BG_PATH3 EQU $118C
_PLAYER_WALK_5_PATH8 EQU $0C57
Vec_Music_Flag EQU $C856
Vec_Random_Seed EQU $C87D
Obj_Hit EQU $F8FF
Clear_x_256 EQU $F545
AU_MUSIC_WRITE_LOOP EQU $4579
MUSICA EQU $FF44
Vec_Button_2_2 EQU $C817
Moveto_ix_a EQU $F30E
MUL16.MUL16_END EQU $41D7
VEC_RUN_INDEX EQU $C837
Sound_Byte EQU $F256
_LOGO_PATH2 EQU $0D5C
SFX_DOFRAME EQU $45D3
DSWM_NEXT_USE_OVERRIDE EQU $4401
CLEAR_C8_RAM EQU $F542
Mov_Draw_VLcs EQU $F3B5
PRINT_TEXT_STR_83503386307659390 EQU $471F
Delay_RTS EQU $F57D
Clear_Sound EQU $F272
_PLAYER_WALK_2_PATH10 EQU $08CD
MOVETO_X_7F EQU $F2F2
PRINT_TEXT_STR_17258163498655081049 EQU $47B4
Vec_Str_Ptr EQU $C82C
DEC_COUNTERS EQU $F563
Init_Music_chk EQU $F687
Print_Str_d EQU $F37A
INIT_OS_RAM EQU $F164
SET_REFRESH EQU $F1A2
Draw_VLcs EQU $F3D6
DIV16.DIV16_LOOP EQU $41DF
Vec_Music_Twang EQU $C858
VEC_RISE_INDEX EQU $C839
_MAP_PATH8 EQU $040A
Draw_Pat_VL_a EQU $F434
Rise_Run_Y EQU $F601
RANDOM_3 EQU $F511
J1Y_BUILTIN EQU $4239
_PLAYER_WALK_3_PATH8 EQU $09E3
BITMASK_A EQU $F57E
_PLAYER_WALK_5_PATH16 EQU $0CE7
MOVETO_D_7F EQU $F2FC
DSWM_NO_NEGATE_DY EQU $43BE
INTENSITY_5F EQU $F2A5
_ATHENS_BG_PATH3 EQU $1129
SOUND_BYTES EQU $F27D
_PLAYER_WALK_4_PATH14 EQU $0B89
RESET_PEN EQU $F35B
Draw_VL_mode EQU $F46E
_PLAYER_WALK_2_PATH8 EQU $08A9
music6 EQU $FE76
_KILIMANJARO_BG_PATH2 EQU $1384
New_High_Score EQU $F8D8
_PLAYER_WALK_5_PATH0 EQU $0BE2
_LENINGRAD_BG_PATH2 EQU $0FCF
sfx_enablenoise EQU $464E
DRAW_VLP_FF EQU $F404
INIT_MUSIC_BUF EQU $F533
_PLAYER_WALK_2_PATH3 EQU $0861
PRINT_SHIPS EQU $F393
_ANGKOR_BG_PATH1 EQU $1339
ROT_VL_MODE_A EQU $F61F
SFX_DISABLENOISE EQU $4641
VEC_RFRSH_HI EQU $C83E
Mov_Draw_VL_d EQU $F3BE
VEC_EXPL_CHAN EQU $C85C
_KILIMANJARO_BG_VECTORS EQU $135D
_PLAYER_WALK_4_VECTORS EQU $0A85
VEC_NUM_GAME EQU $C87A
Vec_Rise_Index EQU $C839
_ANGKOR_BG_PATH2 EQU $134B
DP_TO_C8 EQU $F1AF
_LOGO_PATH4 EQU $0D80
VEC_BUTTON_2_3 EQU $C818
PRINT_TEXT_STR_2572636110730664281 EQU $4737
Vec_Twang_Table EQU $C851
PRINT_TEXT_STR_6459777946950754952 EQU $4797
_PLAYER_WALK_4_PATH11 EQU $0B53
Intensity_3F EQU $F2A1
PRINT_TEXT_STR_3208483 EQU $4676
VEC_HIGH_SCORE EQU $CBEB
Vec_Text_Height EQU $C82A
Vec_Button_2_1 EQU $C816
Rot_VL_Mode_a EQU $F61F
PRINT_TEXT_STR_95736077158694 EQU $46FF
Vec_Num_Game EQU $C87A
CLEAR_X_B_A EQU $F552
Delay_3 EQU $F56D
_PLAYER_WALK_2_PATH2 EQU $084F
Vec_Expl_1 EQU $C858
Vec_SWI2_Vector EQU $CBF2
Dot_List EQU $F2D5
_PLAYER_WALK_1_PATH5 EQU $0742
Joy_Analog EQU $F1F5
MOV_DRAW_VL_D EQU $F3BE
Delay_0 EQU $F579
Add_Score_d EQU $F87C
MUSIC1 EQU $FD0D
Vec_Music_Wk_1 EQU $C84B
DOT_IX EQU $F2C1
MOVETO_IX_A EQU $F30E
VEC_0REF_ENABLE EQU $C824
Vec_Button_1_2 EQU $C813
_LOGO_PATH3 EQU $0D6E
_NEWYORK_BG_PATH0 EQU $0F1A
musicb EQU $FF62
Cold_Start EQU $F000
Draw_VL EQU $F3DD
_PLAYER_WALK_4_PATH10 EQU $0B41
_MAP_PATH13 EQU $04B2
_PLAYER_WALK_5_PATH3 EQU $0C0F
Reset_Pen EQU $F35B
Dec_3_Counters EQU $F55A
_BUDDHA_BG_PATH2 EQU $1466
_ANGKOR_BG_VECTORS EQU $131D
music9 EQU $FF26
_PLAYER_WALK_1_PATH8 EQU $076F
VEC_IRQ_VECTOR EQU $CBF8
_PLAYER_WALK_2_PATH0 EQU $0834
DLW_SEG1_DY_NO_CLAMP EQU $4299
ROT_VL_MODE EQU $F62B
Vec_Counter_2 EQU $C82F
INTENSITY_1F EQU $F29D
_PLAYER_WALK_1_PATH0 EQU $06FA
Intensity_7F EQU $F2A9
Vec_Joy_2_X EQU $C81D
DRAW_LINE_D EQU $F3DF
VEC_EXPL_TIMER EQU $C877
PSG_UPDATE_DONE EQU $44FF
VEC_SND_SHADOW EQU $C800
MUSIC5 EQU $FE38
_ATHENS_BG_VECTORS EQU $10FC
_PLAYER_WALK_2_PATH13 EQU $0903
Vec_Music_Ptr EQU $C853
PMr_start_new EQU $448A
COMPARE_SCORE EQU $F8C7
Sound_Byte_x EQU $F259
VEC_JOY_1_X EQU $C81B
_KEIRIN_BG_PATH0 EQU $14B2
_ATHENS_BG_PATH6 EQU $1144
VEC_MISC_COUNT EQU $C823
_AYERS_BG_PATH1 EQU $142D
_FUJI_BG_PATH3 EQU $0E47
Read_Btns_Mask EQU $F1B4
_PARIS_BG_PATH3 EQU $12C3
VEC_RISERUN_TMP EQU $C834
_HOOK_VECTORS EQU $1503
SOUND_BYTE_RAW EQU $F25B
_LENINGRAD_BG_PATH4 EQU $0FF0
Vec_Music_Wk_6 EQU $C846
INTENSITY_A EQU $F2AB
Moveto_d_7F EQU $F2FC
VEC_DEFAULT_STK EQU $CBEA
VECTREX_PRINT_TEXT EQU $41AA
_BUBBLE_SMALL_PATH0 EQU $1243
sfx_endofeffect EQU $465D
VEC_SWI2_VECTOR EQU $CBF2
_PLAYER_WALK_4_PATH12 EQU $0B65
Vec_RiseRun_Len EQU $C83B
PRINT_STR_YX EQU $F378
_PLAYER_WALK_4_PATH4 EQU $0AE7
XFORM_RISE EQU $F663
Vec_Button_1_4 EQU $C815
GET_RISE_IDX EQU $F5D9
LEVEL_BANK_TABLE EQU $4066
Vec_Joy_Mux_1_Y EQU $C820
VEC_TEXT_WIDTH EQU $C82B
VEC_JOY_1_Y EQU $C81C
PRINT_TEXT_STR_17258163498655081050 EQU $47C2
Vec_Counter_4 EQU $C831
Vec_Expl_4 EQU $C85B
_LONDON_BG_PATH2 EQU $1302
INIT_OS EQU $F18B
Moveto_ix EQU $F310
AU_BANK_OK EQU $4527
DLW_SEG1_DX_LO EQU $42AF
Vec_Joy_Mux_2_X EQU $C821
music8 EQU $FEF8
_PLAYER_WALK_4_PATH15 EQU $0B9B
_TAJ_BG_PATH2 EQU $13C3
_LOGO_PATH6 EQU $0DCE
_MAP_PATH10 EQU $0464
DRAW_VLCS EQU $F3D6
_LONDON_BG_PATH1 EQU $12F0
VEC_BRIGHTNESS EQU $C827
DEC_6_COUNTERS EQU $F55E
_EASTER_BG_PATH3 EQU $10E4
_PLAYER_WALK_5_PATH12 EQU $0C9F
music1 EQU $FD0D
VEC_JOY_2_X EQU $C81D
_KEIRIN_BG_PATH2 EQU $14D0
DRAW_VL_B EQU $F3D2
noay EQU $45D2
PRINT_STR_HWYX EQU $F373
_PLAYER_WALK_2_PATH14 EQU $0915
RANDOM EQU $F517
DIV16 EQU $41DA
AU_MUSIC_HAS_DELAY EQU $456D
sfx_checktonefreq EQU $45E6
SFX_DISABLETONE EQU $4622
DLW_SEG2_DX_CHECK_NEG EQU $430C
_PLAYER_WALK_2_PATH15 EQU $0927
_PLAYER_WALK_5_PATH15 EQU $0CD5
Vec_Default_Stk EQU $CBEA
_MAP_THEME_MUSIC EQU $0000
Vec_Buttons EQU $C811
PRINT_STR EQU $F495
PRINT_TEXT_STR_93976101846 EQU $468D
_MAP_PATH0 EQU $02C3
_PLAYER_WALK_5_PATH2 EQU $0BFD
Draw_Sync_List_At_With_Mirrors EQU $4331
Vec_NMI_Vector EQU $CBFB
Vec_Expl_ChanA EQU $C853
_LOGO_PATH1 EQU $0D35
_PLAYER_WALK_1_PATH12 EQU $07B7
Draw_VLp EQU $F410
_PLAYER_WALK_4_PATH9 EQU $0B2F
_MAYAN_BG_PATH1 EQU $1016
Vec_Counter_5 EQU $C832
VEC_TEXT_HW EQU $C82A
MOV_DRAW_VL_A EQU $F3B9
_PLAYER_WALK_5_PATH10 EQU $0C7B
Vec_IRQ_Vector EQU $CBF8
_BUBBLE_MEDIUM_VECTORS EQU $11EF
VEC_BUTTONS EQU $C811
PMr_done EQU $4498
_MAP_PATH12 EQU $049D
_NEWYORK_BG_PATH4 EQU $0F62
PLAY_MUSIC_BANKED EQU $410C
Init_Music_Buf EQU $F533
_PLAYER_WALK_4_PATH5 EQU $0AF0
VEC_RFRSH_LO EQU $C83D
Print_Ships EQU $F393
VEC_FREQ_TABLE EQU $C84D
DLW_NEED_SEG2 EQU $42E4
ABS_B EQU $F58B
Vec_Num_Players EQU $C879
Explosion_Snd EQU $F92E
Random EQU $F517
Vec_Pattern EQU $C829
DIV16.DIV16_END EQU $41FE
DRAW_LINE_WRAPPER EQU $4252
VEC_JOY_MUX_2_X EQU $C821
PRINT_TEXT_STR_9120385685437879118 EQU $47A5
music7 EQU $FEC6
_BUDDHA_BG_PATH1 EQU $145D
GET_RISE_RUN EQU $F5EF
_PLAYER_WALK_4_PATH3 EQU $0AD5
Print_Ships_x EQU $F391
VEC_COUNTER_4 EQU $C831
VEC_JOY_MUX_2_Y EQU $C822
Recalibrate EQU $F2E6
Dot_List_Reset EQU $F2DE
DO_SOUND_X EQU $F28C
MUL16 EQU $41C5
VEC_TEXT_HEIGHT EQU $C82A
_PLAYER_WALK_2_VECTORS EQU $0811
Draw_Pat_VL_d EQU $F439
VEC_MUSIC_TWANG EQU $C858
Reset0Int EQU $F36B
SFX_CHECKTONEFREQ EQU $45E6
INIT_MUSIC_CHK EQU $F687
MOD16.MOD16_LOOP EQU $4203
PRINT_TEXT_STR_62529178322969 EQU $46B9
_PLAYER_WALK_4_PATH7 EQU $0B14
Clear_x_b_a EQU $F552
Print_Str EQU $F495
Strip_Zeros EQU $F8B7
_KEIRIN_BG_VECTORS EQU $14AB
AU_MUSIC_ENDED EQU $4596
PRINT_TEXT_STR_17258163498655081051 EQU $47D0
INIT_MUSIC_X EQU $F692
sfx_disabletone EQU $4622
CLEAR_X_256 EQU $F545
RESET0REF_D0 EQU $F34A
_PLAYER_WALK_2_PATH1 EQU $0846
Vec_Counter_1 EQU $C82E
DRAW_VLP EQU $F410
WAIT_RECAL EQU $F192
_LENINGRAD_BG_PATH3 EQU $0FDE
ROT_VL_AB EQU $F610
Vec_Joy_Mux EQU $C81F
_LONDON_BG_PATH0 EQU $12E1
_PLAYER_WALK_4_PATH6 EQU $0B02
_PLAYER_WALK_2_PATH6 EQU $088E
_PLAYER_WALK_4_PATH2 EQU $0AC3
_MAYAN_BG_PATH3 EQU $1034
_PARIS_BG_VECTORS EQU $1291
_PLAYER_WALK_3_PATH15 EQU $0A61
PRINT_TEXT_STR_5508987775272975622 EQU $4789
_BUBBLE_HUGE_PATH0 EQU $152A
_PLAYER_WALK_3_PATH16 EQU $0A73
Vec_Seed_Ptr EQU $C87B
RISE_RUN_LEN EQU $F603
_PLAYER_WALK_1_PATH10 EQU $0793
MOD16.MOD16_END EQU $421B
Read_Btns EQU $F1BA
DELAY_1 EQU $F575
PRINT_LIST EQU $F38A
PRINT_TEXT_STR_2382167728733 EQU $4695
Vec_ADSR_Timers EQU $C85E
_PLAYER_WALK_1_PATH9 EQU $0781
Vec_Dot_Dwell EQU $C828
_PLAYER_WALK_5_PATH6 EQU $0C3C
MUSIC9 EQU $FF26
Vec_RiseRun_Tmp EQU $C834
_PLAYER_WALK_4_PATH16 EQU $0BAD
_PLAYER_WALK_3_PATH7 EQU $09DA
Warm_Start EQU $F06C
VEC_COUNTER_6 EQU $C833
_PLAYER_WALK_5_PATH7 EQU $0C4E
SFX_UPDATE EQU $45C8
DRAW_VL_AB EQU $F3D8
MUL16.MUL16_LOOP EQU $41CC
SFX_ENABLETONE EQU $462F
Draw_Line_d EQU $F3DF
AU_MUSIC_READ_COUNT EQU $455E
MOVETO_D EQU $F312
VEC_ANGLE EQU $C836
_PLAYER_WALK_5_PATH4 EQU $0C21
Moveto_ix_7F EQU $F30C
Check0Ref EQU $F34F
_PLAYER_WALK_3_PATH3 EQU $099B
JOY_ANALOG EQU $F1F5
Vec_Freq_Table EQU $C84D
PSG_MUSIC_ENDED EQU $44F1
VEC_MAX_GAMES EQU $C850
_MAP_PATH3 EQU $0392
Vec_Joy_Resltn EQU $C81A
PRINT_TEXT_STR_3327403 EQU $467B
music5 EQU $FE38
_PLAYER_WALK_3_PATH1 EQU $0980
PRINT_TEXT_STR_2779111860214 EQU $469E
VEC_EXPL_CHANS EQU $C854
VEC_COUNTER_1 EQU $C82E
Dot_ix EQU $F2C1
PRINT_TEXT_STR_2984064007298942493 EQU $476B
Print_Str_hwyx EQU $F373
VEC_RANDOM_SEED EQU $C87D
DSWM_NEXT_SET_INTENSITY EQU $4403
_PLAYER_WALK_2_PATH11 EQU $08DF
Rot_VL_dft EQU $F637
Do_Sound EQU $F289
SOUND_BYTE_X EQU $F259
PRINT_TEXT_STR_2588604975540550088 EQU $4744
PRINT_TEXT_STR_95097560564962529 EQU $472B
_ANGKOR_BG_PATH0 EQU $1324
MOV_DRAW_VL_AB EQU $F3B7
_EASTER_BG_PATH0 EQU $10B4
sfx_doframe EQU $45D3
SFX_CHECKVOLUME EQU $4611
ASSET_ADDR_TABLE EQU $408C
_PLAYER_WALK_5_PATH1 EQU $0BF4
AU_MUSIC_DONE EQU $4590
sfx_enabletone EQU $462F
Do_Sound_x EQU $F28C
PRINT_TEXT_STR_3170864850809 EQU $46B0
READ_BTNS EQU $F1BA
_NEWYORK_BG_VECTORS EQU $0F0F
_PLAYER_WALK_5_PATH13 EQU $0CB1
Xform_Rise EQU $F663
_PLAYER_WALK_1_PATH3 EQU $0727
MUSIC7 EQU $FEC6
_BARCELONA_BG_PATH2 EQU $117A
musicd EQU $FF8F
_TAJ_BG_PATH3 EQU $13CC
Clear_C8_RAM EQU $F542
VEC_NMI_VECTOR EQU $CBFB
Clear_x_b_80 EQU $F550
Init_OS EQU $F18B
DSWM_NO_NEGATE_DX EQU $43C8
_NEWYORK_BG_PATH1 EQU $0F29
Vec_Button_2_3 EQU $C818
DSWM_USE_OVERRIDE EQU $433D
Moveto_d EQU $F312
_FUJI_BG_PATH1 EQU $0DF3
DELAY_3 EQU $F56D
Vec_0Ref_Enable EQU $C824
_PLAYER_WALK_2_PATH4 EQU $0873
_MAP_PATH11 EQU $0488
Init_VIA EQU $F14C
_MAP_PATH2 EQU $0374
RISE_RUN_ANGLE EQU $F593
VEC_EXPL_FLAG EQU $C867
VEC_PATTERN EQU $C829
PRINT_TEXT_STR_17852485805690375172 EQU $47FA
_PLAYER_WALK_1_VECTORS EQU $06D7
AUDIO_UPDATE EQU $450D
MOVETO_IX EQU $F310
RECALIBRATE EQU $F2E6
sfx_nextframe EQU $4658
_PLAYER_WALK_3_PATH10 EQU $0A07
_PLAYER_WALK_4_PATH0 EQU $0AA8
PRINT_TEXT_STR_102743755 EQU $4680
SOUND_BYTES_X EQU $F284
_LOCATION_MARKER_VECTORS EQU $14DC
_MAP_PATH5 EQU $03CB
Mov_Draw_VL_b EQU $F3B1
musica EQU $FF44
MOD16 EQU $4201
Dec_6_Counters EQU $F55E
PSG_music_ended EQU $44F1
_PLAYER_WALK_1_PATH7 EQU $0766
Intensity_1F EQU $F29D
Moveto_ix_FF EQU $F308
Reset0Ref EQU $F354
Vec_Counter_6 EQU $C833
Vec_Button_1_1 EQU $C812
DRAW_PAT_VL EQU $F437
CHECK0REF EQU $F34F
_LENINGRAD_BG_VECTORS EQU $0FA9
DRAW_SYNC_LIST_AT_WITH_MIRRORS EQU $4331
_FUJI_BG_PATH2 EQU $0E2F
MUSICC EQU $FF7A
_MAYAN_BG_VECTORS EQU $1002
musicc EQU $FF7A
Vec_Expl_Flag EQU $C867
DLW_SEG2_DY_POS EQU $42F5
CLEAR_X_B EQU $F53F
Mov_Draw_VL_ab EQU $F3B7
Vec_Expl_Chans EQU $C854
DEC_3_COUNTERS EQU $F55A
_PLAYER_WALK_3_PATH5 EQU $09B6
SFX_BANK_TABLE EQU $4060
Rise_Run_Len EQU $F603
DSWM_SET_INTENSITY EQU $433F
XFORM_RISE_A EQU $F661
PLAY_MUSIC_RUNTIME EQU $447C
VEC_COLD_FLAG EQU $CBFE
DRAW_VLP_B EQU $F40E
Vec_Joy_1_X EQU $C81B
VEC_MUSIC_WK_7 EQU $C845
DSWM_NO_NEGATE_X EQU $4359
AU_MUSIC_PROCESS_WRITES EQU $4577
PSG_frame_done EQU $44EB
VEC_MUSIC_PTR EQU $C853
VEC_BUTTON_1_3 EQU $C814
VEC_LOOP_COUNT EQU $C825
_PLAYER_WALK_1_PATH13 EQU $07C9
DSWM_NEXT_NO_NEGATE_Y EQU $440F
Draw_Pat_VL EQU $F437
INTENSITY_7F EQU $F2A9
PRINT_TEXT_STR_95266726412236 EQU $46F5
DRAW_VECTOR_BANKED EQU $40D2
DOT_IX_B EQU $F2BE
DRAW_GRID_VL EQU $FF9F
PRINT_LIST_HW EQU $F385
Draw_VLp_b EQU $F40E
Sound_Bytes EQU $F27D
MUSIC2 EQU $FD1D
Rot_VL_ab EQU $F610
Rot_VL EQU $F616
DRAW_PAT_VL_D EQU $F439
GET_RUN_IDX EQU $F5DB
_PLAYER_WALK_3_PATH6 EQU $09C8
PSG_MUSIC_LOOP EQU $44F7
VEC_EXPL_1 EQU $C858
AU_DONE EQU $45B4
_TAJ_BG_PATH1 EQU $13B4
DSWM_LOOP EQU $43A6
VEC_BUTTON_1_2 EQU $C813
Vec_Music_Freq EQU $C861
_MAYAN_BG_PATH0 EQU $100D
CLEAR_X_B_80 EQU $F550
Xform_Rise_a EQU $F661
VEC_JOY_MUX_1_Y EQU $C820
music2 EQU $FD1D
DRAW_VLC EQU $F3CE
_LENINGRAD_BG_PATH0 EQU $0FB4
ROT_VL_DFT EQU $F637
Vec_Button_2_4 EQU $C819
VEC_COUNTER_2 EQU $C82F
Rot_VL_Mode EQU $F62B
Sound_Bytes_x EQU $F284
VEC_MUSIC_FLAG EQU $C856
MUSIC_ADDR_TABLE EQU $405C
Print_Str_yx EQU $F378
WARM_START EQU $F06C
MUSICD EQU $FF8F
PRINT_TEXT_STR_2588604975547356052 EQU $4751
_ATHENS_BG_PATH1 EQU $1117
XFORM_RUN_A EQU $F65B
MUSIC_BANK_TABLE EQU $405A
PRINT_STR_D EQU $F37A
_PARIS_BG_PATH2 EQU $12B4
Mov_Draw_VL_a EQU $F3B9
DRAW_VL_A EQU $F3DA
Vec_Misc_Count EQU $C823
Vec_Run_Index EQU $C837
Draw_VL_b EQU $F3D2
Init_Music EQU $F68D
_PLAYER_WALK_1_PATH2 EQU $0715
_MAP_PATH1 EQU $035C
PRINT_TEXT_STR_17258163498655081053 EQU $47EC
_PARIS_BG_PATH1 EQU $12A8
Draw_VLp_7F EQU $F408
DP_to_C8 EQU $F1AF
_PLAYER_WALK_1_PATH16 EQU $07FF
Vec_ADSR_Table EQU $C84F
Draw_Grid_VL EQU $FF9F
Vec_Expl_Timer EQU $C877
PRINT_SHIPS_X EQU $F391
_LOGO_PATH0 EQU $0D08
MOVE_MEM_A_1 EQU $F67F
_MAP_PATH7 EQU $03F5
_ATHENS_BG_PATH5 EQU $113B


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
    LDS #$CBFF       ; Initialize stack
    ; Initialize CURRENT_ROM_BANK to Bank 0 (current switchable window on boot)
    LDA #0
    STA >CURRENT_ROM_BANK   ; Initialize bank tracker (Bank 0 is visible at boot)
    ; Initialize SFX variables to prevent random noise on startup
    CLR >SFX_ACTIVE         ; Mark SFX as inactive (0=off)
    LDD #$0000
    STD >SFX_PTR            ; Clear SFX pointer
    CLR >PSG_MUSIC_BANK     ; Initialize to 0 (prevents garbage bank switches)
; Bank 0 ($0000) is active; fixed bank 31 ($4000-$7FFF) always visible
    JMP MAIN

;***************************************************************************
; === RAM VARIABLE DEFINITIONS ===
;***************************************************************************
RESULT               EQU $C880+$00   ; Main result temporary (2 bytes)
TMPVAL               EQU $C880+$02   ; Temporary value storage (alias for RESULT) (2 bytes)
TMPPTR               EQU $C880+$04   ; Temporary pointer (2 bytes)
TMPPTR2              EQU $C880+$06   ; Temporary pointer 2 (2 bytes)
TEMP_YX              EQU $C880+$08   ; Temporary Y/X coordinate storage (2 bytes)
DRAW_VEC_X           EQU $C880+$0A   ; Vector draw X offset (1 bytes)
DRAW_VEC_Y           EQU $C880+$0B   ; Vector draw Y offset (1 bytes)
DRAW_VEC_INTENSITY   EQU $C880+$0C   ; Vector intensity override (0=use vector data) (1 bytes)
MIRROR_PAD           EQU $C880+$0D   ; Safety padding to prevent MIRROR flag corruption (16 bytes)
MIRROR_X             EQU $C880+$1D   ; X mirror flag (0=normal, 1=flip) (1 bytes)
MIRROR_Y             EQU $C880+$1E   ; Y mirror flag (0=normal, 1=flip) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$1F   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$29   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$2B   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$2D   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$2E   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$2F   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$31   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
LEVEL_PTR            EQU $C880+$33   ; Pointer to currently loaded level data (2 bytes)
LEVEL_WIDTH          EQU $C880+$35   ; Level width (1 bytes)
LEVEL_HEIGHT         EQU $C880+$36   ; Level height (1 bytes)
LEVEL_TILE_SIZE      EQU $C880+$37   ; Tile size (1 bytes)
PSG_MUSIC_PTR        EQU $C880+$38   ; PSG music data pointer (2 bytes)
PSG_MUSIC_START      EQU $C880+$3A   ; PSG music start pointer (for loops) (2 bytes)
PSG_MUSIC_ACTIVE     EQU $C880+$3C   ; PSG music active flag (1 bytes)
PSG_IS_PLAYING       EQU $C880+$3D   ; PSG playing flag (1 bytes)
PSG_DELAY_FRAMES     EQU $C880+$3E   ; PSG frame delay counter (1 bytes)
PSG_MUSIC_BANK       EQU $C880+$3F   ; PSG music bank ID (for multibank) (1 bytes)
SFX_PTR              EQU $C880+$40   ; SFX data pointer (2 bytes)
SFX_ACTIVE           EQU $C880+$42   ; SFX active flag (1 bytes)
VAR_STATE_TITLE      EQU $C880+$43   ; User variable: STATE_TITLE (2 bytes)
VAR_STATE_MAP        EQU $C880+$45   ; User variable: STATE_MAP (2 bytes)
VAR_STATE_GAME       EQU $C880+$47   ; User variable: STATE_GAME (2 bytes)
VAR_SCREEN           EQU $C880+$49   ; User variable: screen (2 bytes)
VAR_TITLE_INTENSITY  EQU $C880+$4B   ; User variable: title_intensity (2 bytes)
VAR_TITLE_STATE      EQU $C880+$4D   ; User variable: title_state (2 bytes)
VAR_CURRENT_MUSIC    EQU $C880+$4F   ; User variable: current_music (2 bytes)
VAR_LOCATION_X_COORDS EQU $C880+$51   ; User variable: location_x_coords (2 bytes)
VAR_LOCATION_Y_COORDS EQU $C880+$53   ; User variable: location_y_coords (2 bytes)
VAR_LOCATION_NAMES   EQU $C880+$55   ; User variable: location_names (2 bytes)
VAR_LEVEL_BACKGROUNDS EQU $C880+$57   ; User variable: level_backgrounds (2 bytes)
VAR_LEVEL_ENEMY_COUNT EQU $C880+$59   ; User variable: level_enemy_count (2 bytes)
VAR_LEVEL_ENEMY_SPEED EQU $C880+$5B   ; User variable: level_enemy_speed (2 bytes)
VAR_NUM_LOCATIONS    EQU $C880+$5D   ; User variable: num_locations (2 bytes)
VAR_CURRENT_LOCATION EQU $C880+$5F   ; User variable: current_location (2 bytes)
VAR_LOCATION_GLOW_INTENSITY EQU $C880+$61   ; User variable: location_glow_intensity (2 bytes)
VAR_LOCATION_GLOW_DIRECTION EQU $C880+$63   ; User variable: location_glow_direction (2 bytes)
VAR_JOY_X            EQU $C880+$65   ; User variable: joy_x (2 bytes)
VAR_JOY_Y            EQU $C880+$67   ; User variable: joy_y (2 bytes)
VAR_PREV_JOY_X       EQU $C880+$69   ; User variable: prev_joy_x (2 bytes)
VAR_PREV_JOY_Y       EQU $C880+$6B   ; User variable: prev_joy_y (2 bytes)
VAR_COUNTDOWN_TIMER  EQU $C880+$6D   ; User variable: countdown_timer (2 bytes)
VAR_COUNTDOWN_ACTIVE EQU $C880+$6F   ; User variable: countdown_active (2 bytes)
VAR_JOYSTICK_POLL_COUNTER EQU $C880+$71   ; User variable: joystick_poll_counter (2 bytes)
VAR_HOOK_ACTIVE      EQU $C880+$73   ; User variable: hook_active (2 bytes)
VAR_HOOK_X           EQU $C880+$75   ; User variable: hook_x (2 bytes)
VAR_HOOK_Y           EQU $C880+$77   ; User variable: hook_y (2 bytes)
VAR_HOOK_MAX_Y       EQU $C880+$79   ; User variable: hook_max_y (2 bytes)
VAR_HOOK_GUN_X       EQU $C880+$7B   ; User variable: hook_gun_x (2 bytes)
VAR_HOOK_GUN_Y       EQU $C880+$7D   ; User variable: hook_gun_y (2 bytes)
VAR_HOOK_INIT_Y      EQU $C880+$7F   ; User variable: hook_init_y (2 bytes)
VAR_PLAYER_X         EQU $C880+$81   ; User variable: player_x (2 bytes)
VAR_PLAYER_Y         EQU $C880+$83   ; User variable: player_y (2 bytes)
VAR_MOVE_SPEED       EQU $C880+$85   ; User variable: move_speed (2 bytes)
VAR_ABS_JOY          EQU $C880+$87   ; User variable: abs_joy (2 bytes)
VAR_PLAYER_ANIM_FRAME EQU $C880+$89   ; User variable: player_anim_frame (2 bytes)
VAR_PLAYER_ANIM_COUNTER EQU $C880+$8B   ; User variable: player_anim_counter (2 bytes)
VAR_PLAYER_ANIM_SPEED EQU $C880+$8D   ; User variable: player_anim_speed (2 bytes)
VAR_PLAYER_FACING    EQU $C880+$8F   ; User variable: player_facing (2 bytes)
VAR_MAX_ENEMIES      EQU $C880+$91   ; User variable: MAX_ENEMIES (2 bytes)
VAR_GRAVITY          EQU $C880+$93   ; User variable: GRAVITY (2 bytes)
VAR_BOUNCE_DAMPING   EQU $C880+$95   ; User variable: BOUNCE_DAMPING (2 bytes)
VAR_MIN_BOUNCE_VY    EQU $C880+$97   ; User variable: MIN_BOUNCE_VY (2 bytes)
VAR_GROUND_Y         EQU $C880+$99   ; User variable: GROUND_Y (2 bytes)
VAR_JOYSTICK1_STATE  EQU $C880+$9B   ; User variable: joystick1_state (2 bytes)
VAR_LOC_X            EQU $C880+$9D   ; User variable: loc_x (2 bytes)
VAR_LOC_Y            EQU $C880+$9F   ; User variable: loc_y (2 bytes)
VAR_ANIM_THRESHOLD   EQU $C880+$A1   ; User variable: anim_threshold (2 bytes)
VAR_MIRROR_MODE      EQU $C880+$A3   ; User variable: mirror_mode (2 bytes)
VAR_ACTIVE_COUNT     EQU $C880+$A5   ; User variable: active_count (2 bytes)
VAR_I                EQU $C880+$A7   ; User variable: i (2 bytes)
VAR_ENEMY_ACTIVE     EQU $C880+$A9   ; User variable: enemy_active (2 bytes)
VAR_COUNT            EQU $C880+$AB   ; User variable: count (2 bytes)
VAR_SPEED            EQU $C880+$AD   ; User variable: speed (2 bytes)
VAR_ENEMY_SIZE       EQU $C880+$AF   ; User variable: enemy_size (2 bytes)
VAR_ENEMY_X          EQU $C880+$B1   ; User variable: enemy_x (2 bytes)
VAR_ENEMY_Y          EQU $C880+$B3   ; User variable: enemy_y (2 bytes)
VAR_ENEMY_VX         EQU $C880+$B5   ; User variable: enemy_vx (2 bytes)
VAR_ENEMY_VY         EQU $C880+$B7   ; User variable: enemy_vy (2 bytes)
VAR_START_X          EQU $C880+$B9   ; User variable: start_x (2 bytes)
VAR_START_Y          EQU $C880+$BB   ; User variable: start_y (2 bytes)
VAR_END_X            EQU $C880+$BD   ; User variable: end_x (2 bytes)
VAR_END_Y            EQU $C880+$BF   ; User variable: end_y (2 bytes)
VAR_JOYSTICK1_STATE_DATA EQU $C880+$C1   ; Mutable array 'joystick1_state' data (6 elements x 2 bytes) (12 bytes)
VAR_ENEMY_ACTIVE_DATA EQU $C880+$CD   ; Mutable array 'enemy_active' data (8 elements x 2 bytes) (16 bytes)
VAR_ENEMY_X_DATA     EQU $C880+$DD   ; Mutable array 'enemy_x' data (8 elements x 2 bytes) (16 bytes)
VAR_ENEMY_Y_DATA     EQU $C880+$ED   ; Mutable array 'enemy_y' data (8 elements x 2 bytes) (16 bytes)
VAR_ENEMY_VX_DATA    EQU $C880+$FD   ; Mutable array 'enemy_vx' data (8 elements x 2 bytes) (16 bytes)
VAR_ENEMY_VY_DATA    EQU $C880+$10D   ; Mutable array 'enemy_vy' data (8 elements x 2 bytes) (16 bytes)
VAR_ENEMY_SIZE_DATA  EQU $C880+$11D   ; Mutable array 'enemy_size' data (8 elements x 2 bytes) (16 bytes)
VAR_ARG0             EQU $CFE0   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $CFE2   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $CFE4   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $CFE6   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $CFE8   ; Function argument 4 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $CFEA   ; Current ROM bank ID (multibank tracking) (1 bytes)

;***************************************************************************
; ARRAY DATA (ROM literals)
;***************************************************************************
; Arrays are stored in ROM and accessed via pointers
; At startup, main() initializes VAR_{name} to point to ARRAY_{name}_DATA

; Array literal for variable 'location_x_coords' (17 elements, 2 bytes each)
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

; Array literal for variable 'location_y_coords' (17 elements, 2 bytes each)
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

; String array literal for variable 'location_names' (17 elements)
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

ARRAY_LOCATION_NAMES_DATA:  ; Pointer table for location_names
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

; String array literal for variable 'level_backgrounds' (17 elements)
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

ARRAY_LEVEL_BACKGROUNDS_DATA:  ; Pointer table for level_backgrounds
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

; Array literal for variable 'level_enemy_count' (17 elements, 2 bytes each)
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

; Array literal for variable 'level_enemy_speed' (17 elements, 2 bytes each)
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

; Array literal for variable 'joystick1_state' (6 elements, 2 bytes each)
ARRAY_JOYSTICK1_STATE_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5

; Array literal for variable 'enemy_active' (8 elements, 2 bytes each)
ARRAY_ENEMY_ACTIVE_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'enemy_x' (8 elements, 2 bytes each)
ARRAY_ENEMY_X_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'enemy_y' (8 elements, 2 bytes each)
ARRAY_ENEMY_Y_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'enemy_vx' (8 elements, 2 bytes each)
ARRAY_ENEMY_VX_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'enemy_vy' (8 elements, 2 bytes each)
ARRAY_ENEMY_VY_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'enemy_size' (8 elements, 2 bytes each)
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
    LDD #30
    STD VAR_TITLE_INTENSITY
    LDD #0
    STD VAR_TITLE_STATE
    LDD #-1
    STD VAR_CURRENT_MUSIC
    ; Copy array 'joystick1_state' from ROM to RAM (6 elements)
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
    ; Copy array 'enemy_active' from ROM to RAM (8 elements)
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
    ; Copy array 'enemy_x' from ROM to RAM (8 elements)
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
    ; Copy array 'enemy_y' from ROM to RAM (8 elements)
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
    ; Copy array 'enemy_vx' from ROM to RAM (8 elements)
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
    ; Copy array 'enemy_vy' from ROM to RAM (8 elements)
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
    ; Copy array 'enemy_size' from ROM to RAM (8 elements)
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
    LDD VAR_STATE_TITLE
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

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR Reset0Ref    ; Reset beam to center (0,0)
    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access
    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)
    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access
    JSR read_joystick1_state
    LDD VAR_STATE_TITLE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_SCREEN
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
    LDD VAR_CURRENT_MUSIC
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
    LDX #1        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    JSR draw_title_screen
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #2
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_5_TRUE
    LDD #0
    LBRA .CMP_5_END
.CMP_5_TRUE:
    LDD #1
.CMP_5_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_4_TRUE
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #3
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
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
    LBNE .LOGIC_4_TRUE
    LDD #0
    LBRA .LOGIC_4_END
.LOGIC_4_TRUE:
    LDD #1
.LOGIC_4_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_3_TRUE
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #4
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
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
    LBNE .LOGIC_3_TRUE
    LDD #0
    LBRA .LOGIC_3_END
.LOGIC_3_TRUE:
    LDD #1
.LOGIC_3_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_2_TRUE
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #5
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_8_TRUE
    LDD #0
    LBRA .CMP_8_END
.CMP_8_TRUE:
    LDD #1
.CMP_8_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_2_TRUE
    LDD #0
    LBRA .LOGIC_2_END
.LOGIC_2_TRUE:
    LDD #1
.LOGIC_2_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_5
    LDD VAR_STATE_MAP
    STD RESULT
    LDD RESULT
    STD VAR_SCREEN
    LDD #-1
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_MUSIC
    ; PLAY_SFX: Play sound effect
    JSR PLAY_SFX_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    LBRA IF_END_0
IF_NEXT_1:
    LDD VAR_STATE_MAP
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_SCREEN
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
    LBEQ IF_NEXT_6
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_MUSIC
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBNE .CMP_10_TRUE
    LDD #0
    LBRA .CMP_10_END
.CMP_10_TRUE:
    LDD #1
.CMP_10_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_8
    ; PLAY_MUSIC("map_theme") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_7
IF_NEXT_8:
IF_END_7:
    LDD VAR_joystick_poll_counter
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
    LDD VAR_JOYSTICK_POLL_COUNTER
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_11_TRUE
    LDD #0
    LBRA .CMP_11_END
.CMP_11_TRUE:
    LDD #1
.CMP_11_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_10
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_JOYSTICK_POLL_COUNTER
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #0
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
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
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_JOY_Y
    LBRA IF_END_9
IF_NEXT_10:
IF_END_9:
    LDD #40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_13_TRUE
    LDD #0
    LBRA .CMP_13_END
.CMP_13_TRUE:
    LDD #1
.CMP_13_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_12_FALSE
    LDD #40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PREV_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLE .CMP_14_TRUE
    LDD #0
    LBRA .CMP_14_END
.CMP_14_TRUE:
    LDD #1
.CMP_14_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_12_FALSE
    LDD #1
    LBRA .LOGIC_12_END
.LOGIC_12_FALSE:
    LDD #0
.LOGIC_12_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_12
    LDD VAR_CURRENT_LOCATION
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
    LDD VAR_NUM_LOCATIONS
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_15_TRUE
    LDD #0
    LBRA .CMP_15_END
.CMP_15_TRUE:
    LDD #1
.CMP_15_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_14
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_LOCATION
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'fuji_level1_v2'
    ; Level asset index: 0 (multibank)
    LDX #0
    JSR LOAD_LEVEL_BANKED  ; Switch bank, load level, return
    LBRA IF_END_13
IF_NEXT_14:
IF_END_13:
    LBRA IF_END_11
IF_NEXT_12:
    LDD #-40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_17_TRUE
    LDD #0
    LBRA .CMP_17_END
.CMP_17_TRUE:
    LDD #1
.CMP_17_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_16_FALSE
    LDD #-40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PREV_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_18_TRUE
    LDD #0
    LBRA .CMP_18_END
.CMP_18_TRUE:
    LDD #1
.CMP_18_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_16_FALSE
    LDD #1
    LBRA .LOGIC_16_END
.LOGIC_16_FALSE:
    LDD #0
.LOGIC_16_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_15
    LDD VAR_CURRENT_LOCATION
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
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_19_TRUE
    LDD #0
    LBRA .CMP_19_END
.CMP_19_TRUE:
    LDD #1
.CMP_19_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_17
    LDD VAR_NUM_LOCATIONS
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
    LBRA IF_END_16
IF_NEXT_17:
IF_END_16:
    LBRA IF_END_11
IF_NEXT_15:
    LDD #40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_JOY_Y
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_21_TRUE
    LDD #0
    LBRA .CMP_21_END
.CMP_21_TRUE:
    LDD #1
.CMP_21_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_20_FALSE
    LDD #40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PREV_JOY_Y
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLE .CMP_22_TRUE
    LDD #0
    LBRA .CMP_22_END
.CMP_22_TRUE:
    LDD #1
.CMP_22_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_20_FALSE
    LDD #1
    LBRA .LOGIC_20_END
.LOGIC_20_FALSE:
    LDD #0
.LOGIC_20_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_18
    LDD VAR_CURRENT_LOCATION
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
    LDD VAR_NUM_LOCATIONS
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
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
    LBEQ IF_NEXT_20
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_LOCATION
    LBRA IF_END_19
IF_NEXT_20:
IF_END_19:
    LBRA IF_END_11
IF_NEXT_18:
    LDD #-40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_JOY_Y
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_25_TRUE
    LDD #0
    LBRA .CMP_25_END
.CMP_25_TRUE:
    LDD #1
.CMP_25_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_24_FALSE
    LDD #-40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PREV_JOY_Y
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_26_TRUE
    LDD #0
    LBRA .CMP_26_END
.CMP_26_TRUE:
    LDD #1
.CMP_26_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_24_FALSE
    LDD #1
    LBRA .LOGIC_24_END
.LOGIC_24_FALSE:
    LDD #0
.LOGIC_24_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_END_11
    LDD VAR_CURRENT_LOCATION
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
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_27_TRUE
    LDD #0
    LBRA .CMP_27_END
.CMP_27_TRUE:
    LDD #1
.CMP_27_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_22
    LDD VAR_NUM_LOCATIONS
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
    LBRA IF_END_21
IF_NEXT_22:
IF_END_21:
    LBRA IF_END_11
IF_END_11:
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    STD VAR_PREV_JOY_X
    LDD VAR_JOY_Y
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
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_31_TRUE
    LDD #0
    LBRA .CMP_31_END
.CMP_31_TRUE:
    LDD #1
.CMP_31_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_30_TRUE
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #3
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_32_TRUE
    LDD #0
    LBRA .CMP_32_END
.CMP_32_TRUE:
    LDD #1
.CMP_32_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_30_TRUE
    LDD #0
    LBRA .LOGIC_30_END
.LOGIC_30_TRUE:
    LDD #1
.LOGIC_30_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_29_TRUE
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #4
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_33_TRUE
    LDD #0
    LBRA .CMP_33_END
.CMP_33_TRUE:
    LDD #1
.CMP_33_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_29_TRUE
    LDD #0
    LBRA .LOGIC_29_END
.LOGIC_29_TRUE:
    LDD #1
.LOGIC_29_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_28_TRUE
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #5
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
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
    LBNE .LOGIC_28_TRUE
    LDD #0
    LBRA .LOGIC_28_END
.LOGIC_28_TRUE:
    LDD #1
.LOGIC_28_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_24
    ; PLAY_SFX: Play sound effect
    JSR PLAY_SFX_RUNTIME
    LDD #0
    STD RESULT
    LDD VAR_STATE_GAME
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
    LBRA IF_END_23
IF_NEXT_24:
IF_END_23:
    JSR draw_map_screen
    LBRA IF_END_0
IF_NEXT_6:
    LDD VAR_STATE_GAME
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_SCREEN
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
    LBEQ IF_END_0
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_COUNTDOWN_ACTIVE
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_36_TRUE
    LDD #0
    LBRA .CMP_36_END
.CMP_36_TRUE:
    LDD #1
.CMP_36_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_26
    JSR draw_level_background
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
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
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
    LDD VAR_COUNTDOWN_TIMER
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
    LDD VAR_COUNTDOWN_TIMER
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLE .CMP_37_TRUE
    LDD #0
    LBRA .CMP_37_END
.CMP_37_TRUE:
    LDD #1
.CMP_37_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_28
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_COUNTDOWN_ACTIVE
    JSR spawn_enemies
    LBRA IF_END_27
IF_NEXT_28:
IF_END_27:
    LBRA IF_END_25
IF_NEXT_26:
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_HOOK_ACTIVE
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
    LBEQ IF_NEXT_30
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #2
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_42_TRUE
    LDD #0
    LBRA .CMP_42_END
.CMP_42_TRUE:
    LDD #1
.CMP_42_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_41_TRUE
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #3
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
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
    LBNE .LOGIC_41_TRUE
    LDD #0
    LBRA .LOGIC_41_END
.LOGIC_41_TRUE:
    LDD #1
.LOGIC_41_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_40_TRUE
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #4
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
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
    LBNE .LOGIC_40_TRUE
    LDD #0
    LBRA .LOGIC_40_END
.LOGIC_40_TRUE:
    LDD #1
.LOGIC_40_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_39_TRUE
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #5
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
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
    LBNE .LOGIC_39_TRUE
    LDD #0
    LBRA .LOGIC_39_END
.LOGIC_39_TRUE:
    LDD #1
.LOGIC_39_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_32
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_ACTIVE
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_Y
    ; PLAY_SFX: Play sound effect
    JSR PLAY_SFX_RUNTIME
    LDD #0
    STD RESULT
    LDD VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_GUN_X
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PLAYER_FACING
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
    LBEQ IF_NEXT_34
    LDD VAR_PLAYER_X
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
    LBRA IF_END_33
IF_NEXT_34:
    LDD VAR_PLAYER_X
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
IF_END_33:
    LDD VAR_PLAYER_Y
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
    LDD VAR_HOOK_GUN_Y
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_INIT_Y
    LDD VAR_HOOK_GUN_X
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_X
    LBRA IF_END_31
IF_NEXT_32:
IF_END_31:
    LBRA IF_END_29
IF_NEXT_30:
IF_END_29:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_HOOK_ACTIVE
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_47_TRUE
    LDD #0
    LBRA .CMP_47_END
.CMP_47_TRUE:
    LDD #1
.CMP_47_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_36
    LDD VAR_HOOK_Y
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
    LDD VAR_HOOK_MAX_Y
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_HOOK_Y
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_48_TRUE
    LDD #0
    LBRA .CMP_48_END
.CMP_48_TRUE:
    LDD #1
.CMP_48_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_38
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_ACTIVE
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_Y
    LBRA IF_END_37
IF_NEXT_38:
IF_END_37:
    LBRA IF_END_35
IF_NEXT_36:
IF_END_35:
    JSR draw_game_level
IF_END_25:
    LBRA IF_END_0
IF_END_0:
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX (after all game logic)
    RTS

; Function: draw_map_screen
draw_map_screen:
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
    LDD VAR_LOCATION_GLOW_DIRECTION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_49_TRUE
    LDD #0
    LBRA .CMP_49_END
.CMP_49_TRUE:
    LDD #1
.CMP_49_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_40
    LDD VAR_LOCATION_GLOW_INTENSITY
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
    LDD VAR_LOCATION_GLOW_INTENSITY
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_50_TRUE
    LDD #0
    LBRA .CMP_50_END
.CMP_50_TRUE:
    LDD #1
.CMP_50_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_42
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_LOCATION_GLOW_DIRECTION
    LBRA IF_END_41
IF_NEXT_42:
IF_END_41:
    LBRA IF_END_39
IF_NEXT_40:
    LDD VAR_LOCATION_GLOW_INTENSITY
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
    LDD VAR_LOCATION_GLOW_INTENSITY
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLE .CMP_51_TRUE
    LDD #0
    LBRA .CMP_51_END
.CMP_51_TRUE:
    LDD #1
.CMP_51_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_44
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_LOCATION_GLOW_DIRECTION
    LBRA IF_END_43
IF_NEXT_44:
IF_END_43:
IF_END_39:
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
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
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
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_LOC_X
    LDX #ARRAY_LOCATION_Y_COORDS_DATA  ; Array base
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_LOC_Y
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: location_marker (1 paths) with mirror + intensity
    LDD VAR_LOC_Y
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD VAR_LOC_X
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
    LDD VAR_LOCATION_GLOW_INTENSITY
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

; Function: draw_title_screen
draw_title_screen:
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
    LDX #17        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD VAR_TITLE_INTENSITY
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
    LDD VAR_TITLE_STATE
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
    LBEQ IF_NEXT_46
    LDD VAR_title_intensity
    STD TMPVAL          ; Save left operand
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + TMPVAL
    STD VAR_TITLE_INTENSITY
    LBRA IF_END_45
IF_NEXT_46:
IF_END_45:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_TITLE_STATE
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
    LBEQ IF_NEXT_48
    LDD VAR_title_intensity
    STD TMPVAL          ; Save left operand
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPPTR          ; Save right operand
    LDD TMPVAL          ; Get left operand
    SUBD TMPPTR         ; D = left - right
    STD VAR_TITLE_INTENSITY
    LBRA IF_END_47
IF_NEXT_48:
IF_END_47:
    LDD #80
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_TITLE_INTENSITY
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
    LBEQ IF_NEXT_50
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_TITLE_STATE
    LBRA IF_END_49
IF_NEXT_50:
IF_END_49:
    LDD #30
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_TITLE_INTENSITY
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
    LBEQ IF_NEXT_52
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_TITLE_STATE
    LBRA IF_END_51
IF_NEXT_52:
IF_END_51:
    RTS

; Function: draw_level_background
draw_level_background:
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
    LDD VAR_CURRENT_LOCATION
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
    LBEQ IF_NEXT_54
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
    LDX #11        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_54:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
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
    LBEQ IF_NEXT_55
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
    LDX #13        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_55:
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_58_TRUE
    LDD #0
    LBRA .CMP_58_END
.CMP_58_TRUE:
    LDD #1
.CMP_58_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_56
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
    LDX #9        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_56:
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
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
    LBEQ IF_NEXT_57
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: angkor_bg (index=0, 3 paths)
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
    LDX #0        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_57:
    LDD #4
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_60_TRUE
    LDD #0
    LBRA .CMP_60_END
.CMP_60_TRUE:
    LDD #1
.CMP_60_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_58
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: ayers_bg (index=3, 3 paths)
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
    LDX #3        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_58:
    LDD #5
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_61_TRUE
    LDD #0
    LBRA .CMP_61_END
.CMP_61_TRUE:
    LDD #1
.CMP_61_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_59
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
    LDX #29        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_59:
    LDD #6
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
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
    LBEQ IF_NEXT_60
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
    LDX #15        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_60:
    LDD #7
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
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
    LBEQ IF_NEXT_61
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
    LDX #22        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_61:
    LDD #8
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
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
    LBEQ IF_NEXT_62
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
    LDX #18        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_62:
    LDD #9
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
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
    LBEQ IF_NEXT_63
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: barcelona_bg (index=4, 4 paths)
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
    LDX #4        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_63:
    LDD #10
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
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
    LBEQ IF_NEXT_64
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: athens_bg (index=2, 7 paths)
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
    LDX #2        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_64:
    LDD #11
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
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
    LBEQ IF_NEXT_65
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
    LDX #28        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_65:
    LDD #12
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
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
    LBEQ IF_NEXT_66
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
    LDX #14        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_66:
    LDD #13
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
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
    LBEQ IF_NEXT_67
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
    LDX #21        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_67:
    LDD #14
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
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
    LBEQ IF_NEXT_68
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
    LDX #20        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_68:
    LDD #15
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
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
    LBEQ IF_NEXT_69
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: antarctica_bg (index=1, 4 paths)
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
    LDX #1        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_69:
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
    LDX #10        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
IF_END_53:
    RTS

; Function: draw_game_level
draw_game_level:
    JSR draw_level_background
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #0
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
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
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_73_TRUE
    LDD #0
    LBRA .CMP_73_END
.CMP_73_TRUE:
    LDD #1
.CMP_73_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_72_TRUE
    LDD #20
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_74_TRUE
    LDD #0
    LBRA .CMP_74_END
.CMP_74_TRUE:
    LDD #1
.CMP_74_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_72_TRUE
    LDD #0
    LBRA .LOGIC_72_END
.LOGIC_72_TRUE:
    LDD #1
.LOGIC_72_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_71
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    STD VAR_ABS_JOY
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_ABS_JOY
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_75_TRUE
    LDD #0
    LBRA .CMP_75_END
.CMP_75_TRUE:
    LDD #1
.CMP_75_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_73
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD VAR_ABS_JOY
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD RESULT
    LDD RESULT
    STD VAR_ABS_JOY
    LBRA IF_END_72
IF_NEXT_73:
IF_END_72:
    LDD #40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_ABS_JOY
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_76_TRUE
    LDD #0
    LBRA .CMP_76_END
.CMP_76_TRUE:
    LDD #1
.CMP_76_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_75
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_MOVE_SPEED
    LBRA IF_END_74
IF_NEXT_75:
    LDD #70
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_ABS_JOY
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_77_TRUE
    LDD #0
    LBRA .CMP_77_END
.CMP_77_TRUE:
    LDD #1
.CMP_77_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_76
    LDD #2
    STD RESULT
    LDD RESULT
    STD VAR_MOVE_SPEED
    LBRA IF_END_74
IF_NEXT_76:
    LDD #100
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_ABS_JOY
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_78_TRUE
    LDD #0
    LBRA .CMP_78_END
.CMP_78_TRUE:
    LDD #1
.CMP_78_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_77
    LDD #3
    STD RESULT
    LDD RESULT
    STD VAR_MOVE_SPEED
    LBRA IF_END_74
IF_NEXT_77:
    LDD #4
    STD RESULT
    LDD RESULT
    STD VAR_MOVE_SPEED
IF_END_74:
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_79_TRUE
    LDD #0
    LBRA .CMP_79_END
.CMP_79_TRUE:
    LDD #1
.CMP_79_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_79
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD VAR_MOVE_SPEED
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD RESULT
    LDD RESULT
    STD VAR_MOVE_SPEED
    LBRA IF_END_78
IF_NEXT_79:
IF_END_78:
    LDD VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD VAR_MOVE_SPEED
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
    LDD VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_80_TRUE
    LDD #0
    LBRA .CMP_80_END
.CMP_80_TRUE:
    LDD #1
.CMP_80_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_81
    LDD #-110
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_X
    LBRA IF_END_80
IF_NEXT_81:
IF_END_80:
    LDD #110
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_81_TRUE
    LDD #0
    LBRA .CMP_81_END
.CMP_81_TRUE:
    LDD #1
.CMP_81_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_83
    LDD #110
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_X
    LBRA IF_END_82
IF_NEXT_83:
IF_END_82:
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_82_TRUE
    LDD #0
    LBRA .CMP_82_END
.CMP_82_TRUE:
    LDD #1
.CMP_82_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_85
    LDD #-1
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_FACING
    LBRA IF_END_84
IF_NEXT_85:
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_FACING
IF_END_84:
    LDD VAR_PLAYER_ANIM_COUNTER
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
    LDD VAR_PLAYER_ANIM_SPEED
    STD RESULT
    LDD RESULT
    STD VAR_ANIM_THRESHOLD
    LDD #-80
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_84_TRUE
    LDD #0
    LBRA .CMP_84_END
.CMP_84_TRUE:
    LDD #1
.CMP_84_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_83_TRUE
    LDD #80
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_85_TRUE
    LDD #0
    LBRA .CMP_85_END
.CMP_85_TRUE:
    LDD #1
.CMP_85_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_83_TRUE
    LDD #0
    LBRA .LOGIC_83_END
.LOGIC_83_TRUE:
    LDD #1
.LOGIC_83_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_87
    LDD VAR_PLAYER_ANIM_SPEED
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
    LBRA IF_END_86
IF_NEXT_87:
IF_END_86:
    LDD VAR_ANIM_THRESHOLD
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PLAYER_ANIM_COUNTER
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_86_TRUE
    LDD #0
    LBRA .CMP_86_END
.CMP_86_TRUE:
    LDD #1
.CMP_86_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_89
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_ANIM_COUNTER
    LDD VAR_PLAYER_ANIM_FRAME
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
    LDD VAR_PLAYER_ANIM_FRAME
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_87_TRUE
    LDD #0
    LBRA .CMP_87_END
.CMP_87_TRUE:
    LDD #1
.CMP_87_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_91
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_ANIM_FRAME
    LBRA IF_END_90
IF_NEXT_91:
IF_END_90:
    LBRA IF_END_88
IF_NEXT_89:
IF_END_88:
    LBRA IF_END_70
IF_NEXT_71:
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_ANIM_FRAME
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_ANIM_COUNTER
IF_END_70:
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_MIRROR_MODE
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PLAYER_FACING
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_88_TRUE
    LDD #0
    LBRA .CMP_88_END
.CMP_88_TRUE:
    LDD #1
.CMP_88_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_93
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_MIRROR_MODE
    LBRA IF_END_92
IF_NEXT_93:
IF_END_92:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PLAYER_ANIM_FRAME
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_89_TRUE
    LDD #0
    LBRA .CMP_89_END
.CMP_89_TRUE:
    LDD #1
.CMP_89_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_95
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_1 (17 paths) with mirror + intensity
    LDD VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD VAR_PLAYER_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD VAR_MIRROR_MODE
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
    LBRA IF_END_94
IF_NEXT_95:
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PLAYER_ANIM_FRAME
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_90_TRUE
    LDD #0
    LBRA .CMP_90_END
.CMP_90_TRUE:
    LDD #1
.CMP_90_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_96
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_2 (17 paths) with mirror + intensity
    LDD VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD VAR_PLAYER_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD VAR_MIRROR_MODE
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
    LBRA IF_END_94
IF_NEXT_96:
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PLAYER_ANIM_FRAME
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_91_TRUE
    LDD #0
    LBRA .CMP_91_END
.CMP_91_TRUE:
    LDD #1
.CMP_91_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_97
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_3 (17 paths) with mirror + intensity
    LDD VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD VAR_PLAYER_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD VAR_MIRROR_MODE
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
    LBRA IF_END_94
IF_NEXT_97:
    LDD #4
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PLAYER_ANIM_FRAME
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_92_TRUE
    LDD #0
    LBRA .CMP_92_END
.CMP_92_TRUE:
    LDD #1
.CMP_92_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_98
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_4 (17 paths) with mirror + intensity
    LDD VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD VAR_PLAYER_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD VAR_MIRROR_MODE
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
    LBRA IF_END_94
IF_NEXT_98:
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_5 (17 paths) with mirror + intensity
    LDD VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD VAR_PLAYER_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD VAR_MIRROR_MODE
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
IF_END_94:
    JSR update_enemies
    JSR draw_enemies
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_HOOK_ACTIVE
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_93_TRUE
    LDD #0
    LBRA .CMP_93_END
.CMP_93_TRUE:
    LDD #1
.CMP_93_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_100
    LDD VAR_HOOK_GUN_X
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD VAR_HOOK_INIT_Y
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDD VAR_HOOK_X
    STD RESULT
    LDD RESULT
    STD VAR_ARG2
    LDD VAR_HOOK_Y
    STD RESULT
    LDD RESULT
    STD VAR_ARG3
    JSR draw_hook_rope
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: hook (1 paths) with mirror + intensity
    LDD VAR_HOOK_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD VAR_HOOK_Y
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
    LBRA IF_END_99
IF_NEXT_100:
IF_END_99:
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_ACTIVE_COUNT
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_I
WH_101: ; while start
    LDD VAR_MAX_ENEMIES
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_I
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
    LBEQ WH_END_102
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_ACTIVE_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_95_TRUE
    LDD #0
    LBRA .CMP_95_END
.CMP_95_TRUE:
    LDD #1
.CMP_95_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_104
    LDD VAR_ACTIVE_COUNT
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_ACTIVE_COUNT
    LBRA IF_END_103
IF_NEXT_104:
IF_END_103:
    LDD VAR_I
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
    LBRA WH_101
WH_END_102: ; while end
    RTS

; Function: spawn_enemies
spawn_enemies:
    LDX #ARRAY_LEVEL_ENEMY_COUNT_DATA  ; Array base
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_COUNT
    LDX #ARRAY_LEVEL_ENEMY_SPEED_DATA  ; Array base
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_SPEED
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_I
WH_105: ; while start
    LDD VAR_COUNT
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_I
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_96_TRUE
    LDD #0
    LBRA .CMP_96_END
.CMP_96_TRUE:
    LDD #1
.CMP_96_END:
    STD RESULT
    LDD RESULT
    LBEQ WH_END_106
    LDD VAR_I
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
    LDD VAR_I
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
    LDD VAR_I
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
    LDD VAR_I
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
    LDD VAR_I
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
    LDD VAR_I
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
    LDD VAR_SPEED
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_I
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
    LBEQ .CMP_97_TRUE
    LDD #0
    LBRA .CMP_97_END
.CMP_97_TRUE:
    LDD #1
.CMP_97_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_108
    LDD VAR_I
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
    LDD VAR_SPEED
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LBRA IF_END_107
IF_NEXT_108:
IF_END_107:
    LDD VAR_I
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
    LDD VAR_I
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
    LBRA WH_105
WH_END_106: ; while end
    RTS

; Function: update_enemies
update_enemies:
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_I
WH_109: ; while start
    LDD VAR_MAX_ENEMIES
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_I
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_98_TRUE
    LDD #0
    LBRA .CMP_98_END
.CMP_98_TRUE:
    LDD #1
.CMP_98_END:
    STD RESULT
    LDD RESULT
    LBEQ WH_END_110
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_ACTIVE_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
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
    LBEQ IF_NEXT_112
    LDD VAR_I
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
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD VAR_GRAVITY
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD VAR_I
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
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_VX_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
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
    LDD VAR_I
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
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_VY_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
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
    LDD VAR_GROUND_Y
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLE .CMP_100_TRUE
    LDD #0
    LBRA .CMP_100_END
.CMP_100_TRUE:
    LDD #1
.CMP_100_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_114
    LDD VAR_I
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
    LDD VAR_GROUND_Y
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD VAR_I
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
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
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
    LDD VAR_I
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
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD VAR_BOUNCE_DAMPING
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
    LDD VAR_MIN_BOUNCE_VY
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_VY_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_101_TRUE
    LDD #0
    LBRA .CMP_101_END
.CMP_101_TRUE:
    LDD #1
.CMP_101_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_116
    LDD VAR_I
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
    LDD VAR_MIN_BOUNCE_VY
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LBRA IF_END_115
IF_NEXT_116:
IF_END_115:
    LBRA IF_END_113
IF_NEXT_114:
IF_END_113:
    LDD #-85
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLE .CMP_102_TRUE
    LDD #0
    LBRA .CMP_102_END
.CMP_102_TRUE:
    LDD #1
.CMP_102_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_118
    LDD VAR_I
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
    LDD VAR_I
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
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
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
    LBRA IF_END_117
IF_NEXT_118:
IF_END_117:
    LDD #85
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_103_TRUE
    LDD #0
    LBRA .CMP_103_END
.CMP_103_TRUE:
    LDD #1
.CMP_103_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_120
    LDD VAR_I
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
    LDD VAR_I
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
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
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
    LBRA IF_END_119
IF_NEXT_120:
IF_END_119:
    LBRA IF_END_111
IF_NEXT_112:
IF_END_111:
    LDD VAR_I
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

; Function: draw_enemies
draw_enemies:
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_I
WH_121: ; while start
    LDD VAR_MAX_ENEMIES
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_I
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
    LBEQ WH_END_122
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_ACTIVE_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_105_TRUE
    LDD #0
    LBRA .CMP_105_END
.CMP_105_TRUE:
    LDD #1
.CMP_105_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_124
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
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_106_TRUE
    LDD #0
    LBRA .CMP_106_END
.CMP_106_TRUE:
    LDD #1
.CMP_106_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_126
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bubble_huge (index=5, 1 paths)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
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
    LDX #5        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_125
IF_NEXT_126:
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_SIZE_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_107_TRUE
    LDD #0
    LBRA .CMP_107_END
.CMP_107_TRUE:
    LDD #1
.CMP_107_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_127
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bubble_large (index=6, 1 paths)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
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
    LDX #6        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_125
IF_NEXT_127:
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_SIZE_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_108_TRUE
    LDD #0
    LBRA .CMP_108_END
.CMP_108_TRUE:
    LDD #1
.CMP_108_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_128
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bubble_medium (index=7, 1 paths)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
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
    LDX #7        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_125
IF_NEXT_128:
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bubble_small (index=8, 1 paths)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
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
    LDX #8        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
IF_END_125:
    LBRA IF_END_123
IF_NEXT_124:
IF_END_123:
    LDD VAR_I
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
    LBRA WH_121
WH_END_122: ; while end
    RTS

; Function: draw_hook_rope
draw_hook_rope:
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD VAR_START_X
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+0    ; x0
    LDD VAR_START_Y
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+2    ; y0
    LDD VAR_END_X
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+4    ; x1
    LDD VAR_END_Y
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

; Function: read_joystick1_state
read_joystick1_state:
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
    LDA $C80F      ; Vec_Btn_State (updated by Read_Btns)
    ANDA #$01      ; Test bit 0
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
    LDA $C80F      ; Vec_Btn_State (updated by Read_Btns)
    ANDA #$02      ; Test bit 1
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
    LDA $C80F      ; Vec_Btn_State (updated by Read_Btns)
    ANDA #$04      ; Test bit 2
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
    LDA $C80F      ; Vec_Btn_State (updated by Read_Btns)
    ANDA #$08      ; Test bit 3
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


; ================================================
