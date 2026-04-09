; VPy M6809 Assembly (Vectrex)
; ROM: 65536 bytes
; Multibank cartridge: 4 banks (16KB each)
; Helpers bank: 3 (fixed bank at $4000-$7FFF)

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
LEVEL_BG_ROM_PTR     EQU $C880+$48   ; BG layer ROM pointer (2 bytes)
LEVEL_GP_ROM_PTR     EQU $C880+$4A   ; GP layer ROM pointer (2 bytes)
LEVEL_FG_ROM_PTR     EQU $C880+$4C   ; FG layer ROM pointer (2 bytes)
LEVEL_GP_PTR         EQU $C880+$4E   ; GP active pointer (RAM buffer after LOAD_LEVEL) (2 bytes)
LEVEL_BANK           EQU $C880+$50   ; Bank ID for current level (for multibank) (1 bytes)
SLR_CUR_X            EQU $C880+$51   ; SHOW_LEVEL: tracked beam X for per-segment clipping (1 bytes)
LEVEL_GP_BUFFER      EQU $C880+$52   ; GP objects RAM buffer (max 32 objects × 15 bytes) (480 bytes)
LCOL_PX              EQU $C880+$232   ; LEVEL_COLLISION_Y player world_x input (16-bit) (2 bytes)
LCOL_BEST_Y          EQU $C880+$234   ; LEVEL_COLLISION_Y best floor y found (signed byte) (1 bytes)
LCOL_PY              EQU $C880+$235   ; LEVEL_COLLISION_Y player feet Y (player_y - player_hh) (1 bytes)
LCOL_PHH             EQU $C880+$236   ; LEVEL_COLLISION_Y player half_height (1 bytes)
UGPC_OUTER_IDX       EQU $C880+$237   ; GP-GP outer loop index (1 bytes)
UGPC_OUTER_MAX       EQU $C880+$238   ; GP-GP outer loop max (count-1) (1 bytes)
UGPC_INNER_IDX       EQU $C880+$239   ; GP-GP inner loop index (1 bytes)
UGPC_DX              EQU $C880+$23A   ; GP-GP |dx| (16-bit) (2 bytes)
UGPC_DIST            EQU $C880+$23C   ; GP-GP Manhattan distance (16-bit) (2 bytes)
UGFC_GP_IDX          EQU $C880+$23E   ; GP-FG outer loop GP index (1 bytes)
UGFC_FG_COUNT        EQU $C880+$23F   ; GP-FG inner loop FG count (1 bytes)
UGFC_DX              EQU $C880+$240   ; GP-FG |dx| (1 bytes)
UGFC_DY              EQU $C880+$241   ; GP-FG |dy| (1 bytes)
VAR_CAMERA_X         EQU $C880+$242   ; User variable: camera_x (2 bytes)
VAR_CAMERA_Y         EQU $C880+$244   ; User variable: camera_y (2 bytes)
VAR_JOY_X            EQU $C880+$246   ; User variable: joy_x (2 bytes)
VAR_JOY_Y            EQU $C880+$248   ; User variable: joy_y (2 bytes)
VAR_ARG0             EQU $CB80   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $CB82   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $CB84   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $CB86   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $CB88   ; Function argument 4 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $CB8A   ; Current ROM bank ID (multibank tracking) (1 bytes)


; ================================================

; VPy M6809 Assembly (Vectrex)
; ROM: 65536 bytes
; Multibank cartridge: 4 banks (16KB each)
; Helpers bank: 3 (fixed bank at $4000-$7FFF)

; ================================================

    ORG $0000

;***************************************************************************
; DEFINE SECTION
;***************************************************************************
    INCLUDE "VECTREX.I"
; External symbols (helpers, BIOS, and shared data)
VEC_MAX_PLAYERS EQU $C84F
Vec_Music_Flag EQU $C856
Init_Music EQU $F68D
SLR_PATH_DONE EQU $44C7
ADD_SCORE_A EQU $F85E
VEC_RISERUN_LEN EQU $C83B
DEC_3_COUNTERS EQU $F55A
Clear_x_b EQU $F53F
SLR_DRAW_CLIPPED_PATH EQU $44D6
Clear_x_b_a EQU $F552
Print_List EQU $F38A
CLEAR_X_256 EQU $F545
SDCP_W_DRAW EQU $459D
DSWM_NO_NEGATE_DY EQU $41B9
Vec_Joy_Mux_1_Y EQU $C820
INTENSITY_1F EQU $F29D
SLR_OBJ_NEXT EQU $44C9
Moveto_d_7F EQU $F2FC
VEC_SWI3_VECTOR EQU $CBF2
VEC_TEXT_HW EQU $C82A
Mov_Draw_VLcs EQU $F3B5
DSWM_NEXT_PATH EQU $41E9
Bitmask_a EQU $F57E
MOV_DRAW_VL_AB EQU $F3B7
Moveto_ix_7F EQU $F30C
Vec_Text_HW EQU $C82A
VEC_EXPL_4 EQU $C85B
Vec_Text_Height EQU $C82A
VEC_BUTTON_1_4 EQU $C815
Vec_Random_Seed EQU $C87D
SLR_DONE EQU $438C
VEC_RFRSH EQU $C83D
Intensity_a EQU $F2AB
SLR_PATH_LOOP EQU $44AF
Vec_Rfrsh_hi EQU $C83E
MOD16.M16_RCHECK EQU $40C6
music6 EQU $FE76
Do_Sound_x EQU $F28C
SLR_ROM_ADDR_LOOP EQU $43B4
Vec_Button_2_2 EQU $C817
Compare_Score EQU $F8C7
Rise_Run_Angle EQU $F593
Init_OS_RAM EQU $F164
PRINT_TEXT_STR_3213661242 EQU $45D9
DSWM_NO_NEGATE_Y EQU $4141
ROT_VL_MODE_A EQU $F61F
VEC_MAX_GAMES EQU $C850
VEC_NUM_PLAYERS EQU $C879
SDCP_CHECK_POS EQU $450A
Sound_Bytes EQU $F27D
Delay_3 EQU $F56D
JOY_DIGITAL EQU $F1F8
Vec_Num_Players EQU $C879
RISE_RUN_ANGLE EQU $F593
Clear_x_256 EQU $F545
VEC_BUTTONS EQU $C811
EXPLOSION_SND EQU $F92E
Reset_Pen EQU $F35B
music4 EQU $FDD3
VEC_JOY_1_Y EQU $C81C
DP_TO_C8 EQU $F1AF
DRAW_VLC EQU $F3CE
VEC_COLD_FLAG EQU $CBFE
PRINT_STR_D EQU $F37A
INTENSITY_3F EQU $F2A1
Move_Mem_a_1 EQU $F67F
VEC_STR_PTR EQU $C82C
DSWM_W2 EQU $41DA
Vec_SWI3_Vector EQU $CBF2
SLR_FOREGROUND EQU $437A
DRAW_VLP_FF EQU $F404
Print_Ships EQU $F393
Vec_Loop_Count EQU $C825
Vec_Expl_3 EQU $C85A
SLR_OBJ_LOOP EQU $439B
SLR_GP_COUNT EQU $4368
LLR_COPY_DONE EQU $4327
Rot_VL EQU $F616
DRAW_SYNC_LIST_AT_WITH_MIRRORS EQU $4125
Vec_Button_1_1 EQU $C812
Vec_Expl_Chan EQU $C85C
Draw_Pat_VL EQU $F437
Vec_Counter_6 EQU $C833
Recalibrate EQU $F2E6
Delay_1 EQU $F575
Print_Str_yx EQU $F378
Vec_Music_Chan EQU $C855
Vec_Expl_4 EQU $C85B
Strip_Zeros EQU $F8B7
SDCP_DONE EQU $45D2
Random EQU $F517
Xform_Rise_a EQU $F661
Vec_Snd_Shadow EQU $C800
VEC_JOY_2_Y EQU $C81E
VEC_MUSIC_CHAN EQU $C855
DSWM_DONE EQU $4277
VEC_BUTTON_1_1 EQU $C812
Vec_Joy_Mux_1_X EQU $C81F
VEC_MISC_COUNT EQU $C823
OBJ_WILL_HIT EQU $F8F3
Dot_here EQU $F2C5
Draw_VL_a EQU $F3DA
VEC_SEED_PTR EQU $C87B
Vec_High_Score EQU $CBEB
CLEAR_X_B_80 EQU $F550
Joy_Digital EQU $F1F8
Moveto_ix EQU $F310
SHOW_LEVEL_RUNTIME EQU $4328
Vec_Prev_Btns EQU $C810
INIT_VIA EQU $F14C
DVB_DONE EQU $4061
VEC_PATTERN EQU $C829
INIT_MUSIC_BUF EQU $F533
VEC_COUNTER_1 EQU $C82E
GET_RUN_IDX EQU $F5DB
Check0Ref EQU $F34F
Reset0Int EQU $F36B
Vec_Music_Wk_7 EQU $C845
Cold_Start EQU $F000
ASSET_ADDR_TABLE EQU $4010
VEC_BUTTON_1_3 EQU $C814
LOAD_LEVEL_RUNTIME EQU $4278
Vec_Twang_Table EQU $C851
MOD16 EQU $40A1
MOV_DRAW_VLCS EQU $F3B5
VEC_EXPL_1 EQU $C858
VEC_EXPL_3 EQU $C85A
Select_Game EQU $F7A9
Get_Run_Idx EQU $F5DB
Draw_VLp EQU $F410
PRINT_LIST_CHK EQU $F38C
DOT_LIST EQU $F2D5
Vec_Btn_State EQU $C80F
SDCP_SEG_LOOP EQU $4564
VEC_HIGH_SCORE EQU $CBEB
Vec_Music_Ptr EQU $C853
VEC_MUSIC_FLAG EQU $C856
INIT_MUSIC EQU $F68D
VEC_COUNTER_4 EQU $C831
DELAY_1 EQU $F575
Read_Btns_Mask EQU $F1B4
DELAY_2 EQU $F571
Delay_RTS EQU $F57D
DOT_IX_B EQU $F2BE
SLR_RAM_Y_VISIBLE EQU $442E
PRINT_SHIPS EQU $F393
Vec_Brightness EQU $C827
music2 EQU $FD1D
XFORM_RUN EQU $F65D
SLR_RAM_A_ZERO EQU $4400
Sound_Bytes_x EQU $F284
INIT_OS_RAM EQU $F164
MUSICA EQU $FF44
ROT_VL_AB EQU $F610
musica EQU $FF44
SLR_RAM_VISIBLE EQU $4408
Intensity_3F EQU $F2A1
music3 EQU $FD81
MUSIC9 EQU $FF26
Rise_Run_Len EQU $F603
Dot_ix_b EQU $F2BE
DRAW_VLP_SCALE EQU $F40C
Sound_Byte_x EQU $F259
VEC_MUSIC_WK_5 EQU $C847
MOD16.M16_DONE EQU $40F4
Print_Str EQU $F495
LLR_CLR_GP_LOOP EQU $42B9
Vec_Max_Games EQU $C850
DRAW_VL_A EQU $F3DA
LEVEL_BANK_TABLE EQU $4009
Clear_C8_RAM EQU $F542
VEC_BRIGHTNESS EQU $C827
LOAD_LEVEL_BANKED EQU $406D
SDCP_ABS_OK EQU $450F
Reset0Ref_D0 EQU $F34A
CLEAR_X_B EQU $F53F
Vec_Seed_Ptr EQU $C87B
Delay_2 EQU $F571
Clear_Score EQU $F84F
SLR_ROM_A_ZERO EQU $4498
_GROUND_PATH0 EQU $014B
MOVETO_D EQU $F312
Moveto_ix_FF EQU $F308
VEC_JOY_MUX EQU $C81F
MOD16.M16_RPOS EQU $40D5
Vec_Rise_Index EQU $C839
PRINT_STR_HWYX EQU $F373
MUSICC EQU $FF7A
Vec_Angle EQU $C836
DSWM_NO_NEGATE_X EQU $414E
Draw_Pat_VL_d EQU $F439
Wait_Recal EQU $F192
MOVETO_D_7F EQU $F2FC
DO_SOUND EQU $F289
ROT_VL EQU $F616
INIT_OS EQU $F18B
Draw_VLp_scale EQU $F40C
DEC_6_COUNTERS EQU $F55E
Print_Str_hwyx EQU $F373
Vec_Joy_Mux_2_X EQU $C821
VEC_EXPL_TIMER EQU $C877
DVB_PATH_LOOP EQU $404F
Dec_6_Counters EQU $F55E
Explosion_Snd EQU $F92E
PRINT_LIST EQU $F38A
DSWM_W1 EQU $4198
Init_Music_Buf EQU $F533
MOD16.M16_LOOP EQU $40D5
Vec_Music_Wk_1 EQU $C84B
Set_Refresh EQU $F1A2
ROT_VL_DFT EQU $F637
RESET0REF_D0 EQU $F34A
Random_3 EQU $F511
MOVE_MEM_A EQU $F683
MOD16.M16_END EQU $40E5
CLEAR_C8_RAM EQU $F542
Print_Str_d EQU $F37A
LEVEL_ADDR_TABLE EQU $400A
PRINT_STR EQU $F495
ROT_VL_MODE EQU $F62B
Vec_Joy_Mux_2_Y EQU $C822
Delay_b EQU $F57A
Vec_IRQ_Vector EQU $CBF8
Get_Rise_Run EQU $F5EF
VEC_LOOP_COUNT EQU $C825
DP_to_C8 EQU $F1AF
VEC_TEXT_WIDTH EQU $C82B
Get_Rise_Idx EQU $F5D9
DEC_COUNTERS EQU $F563
RESET_PEN EQU $F35B
Obj_Hit EQU $F8FF
Dot_ix EQU $F2C1
Vec_Joy_2_X EQU $C81D
GET_RISE_IDX EQU $F5D9
SDCP_MOVETO_W EQU $455B
LLR_COPY_OBJECTS EQU $42E0
Vec_RiseRun_Tmp EQU $C834
VEC_ADSR_TIMERS EQU $C85E
VEC_RISE_INDEX EQU $C839
VEC_JOY_MUX_2_X EQU $C821
Read_Btns EQU $F1BA
SDCP_W_MOVE EQU $45C6
Dec_Counters EQU $F563
Vec_Joy_1_X EQU $C81B
VEC_ADSR_TABLE EQU $C84F
VEC_EXPL_2 EQU $C859
MOVETO_X_7F EQU $F2F2
Obj_Will_Hit EQU $F8F3
VEC_BUTTON_1_2 EQU $C813
VEC_SWI_VECTOR EQU $CBFB
Rise_Run_Y EQU $F601
Vec_FIRQ_Vector EQU $CBF5
Draw_Grid_VL EQU $FF9F
Draw_VLcs EQU $F3D6
DRAW_VLP_B EQU $F40E
Joy_Analog EQU $F1F5
VECTOR_BANK_TABLE EQU $4000
XFORM_RISE_A EQU $F661
Xform_Run_a EQU $F65B
VEC_RUN_INDEX EQU $C837
Vec_Music_Freq EQU $C861
Draw_VLc EQU $F3CE
SOUND_BYTE_X EQU $F259
VECTOR_ADDR_TABLE EQU $4003
VEC_NUM_GAME EQU $C87A
DO_SOUND_X EQU $F28C
ASSET_BANK_TABLE EQU $400C
DRAW_LINE_D EQU $F3DF
DRAW_PAT_VL EQU $F437
J1X_BUILTIN EQU $40F5
Vec_Buttons EQU $C811
VEC_BUTTON_2_2 EQU $C817
VEC_SND_SHADOW EQU $C800
Draw_VLp_FF EQU $F404
OBJ_WILL_HIT_U EQU $F8E5
RISE_RUN_LEN EQU $F603
Vec_Counter_1 EQU $C82E
SLR_GAMEPLAY EQU $4368
GET_RISE_RUN EQU $F5EF
VEC_FIRQ_VECTOR EQU $CBF5
VEC_EXPL_FLAG EQU $C867
DP_to_D0 EQU $F1AA
READ_BTNS_MASK EQU $F1B4
DELAY_RTS EQU $F57D
VEC_MUSIC_WK_1 EQU $C84B
DOT_LIST_RESET EQU $F2DE
Vec_ADSR_Table EQU $C84F
VEC_RANDOM_SEED EQU $C87D
Clear_Sound EQU $F272
Init_Music_x EQU $F692
Print_List_chk EQU $F38C
Vec_SWI2_Vector EQU $CBF2
_MARKER_PATH1 EQU $0128
Reset0Ref EQU $F354
Rot_VL_Mode EQU $F62B
Draw_VLp_b EQU $F40E
VEC_BUTTON_2_3 EQU $C818
DSWM_NEXT_SET_INTENSITY EQU $41EF
Draw_VL_mode EQU $F46E
MOV_DRAW_VL_A EQU $F3B9
VEC_0REF_ENABLE EQU $C824
music5 EQU $FE38
RISE_RUN_X EQU $F5FF
Vec_Expl_Flag EQU $C867
VEC_MUSIC_WK_6 EQU $C846
VEC_IRQ_VECTOR EQU $CBF8
VEC_DOT_DWELL EQU $C828
INIT_MUSIC_X EQU $F692
LLR_GP_DONE EQU $42D8
Vec_Button_2_3 EQU $C818
VEC_BUTTON_2_1 EQU $C816
CLEAR_SCORE EQU $F84F
COLD_START EQU $F000
DSWM_SET_INTENSITY EQU $4127
SOUND_BYTES EQU $F27D
DELAY_0 EQU $F579
SLR_DRAW_OBJECTS EQU $4399
MUSIC2 EQU $FD1D
SLR_ROM_Y_VISIBLE EQU $4460
Vec_Duration EQU $C857
Vec_Freq_Table EQU $C84D
Vec_Counter_2 EQU $C82F
Vec_ADSR_Timers EQU $C85E
Add_Score_d EQU $F87C
ABS_B EQU $F58B
MUSICD EQU $FF8F
Vec_Counter_4 EQU $C831
DRAW_VECTOR_BANKED EQU $4018
SLR_INTENSITY_READ EQU $43BF
NEW_HIGH_SCORE EQU $F8D8
MOVETO_IX_FF EQU $F308
RECALIBRATE EQU $F2E6
SOUND_BYTE_RAW EQU $F25B
Vec_Music_Work EQU $C83F
INIT_MUSIC_CHK EQU $F687
MOV_DRAW_VL_D EQU $F3BE
Intensity_1F EQU $F29D
VEC_MUSIC_FREQ EQU $C861
MUSIC6 EQU $FE76
Draw_Pat_VL_a EQU $F434
Vec_Run_Index EQU $C837
INTENSITY_7F EQU $F2A9
VEC_COUNTER_2 EQU $C82F
LLR_COPY_LOOP EQU $42E0
Vec_SWI_Vector EQU $CBFB
MOVE_MEM_A_1 EQU $F67F
OBJ_HIT EQU $F8FF
VEC_EXPL_CHANS EQU $C854
DSWM_LOOP EQU $41A1
ABS_A_B EQU $F584
DRAW_VL_B EQU $F3D2
Moveto_x_7F EQU $F2F2
Vec_Counters EQU $C82E
VEC_PREV_BTNS EQU $C810
DSWM_NEXT_NO_NEGATE_X EQU $4208
Vec_Rfrsh EQU $C83D
Sound_Byte_raw EQU $F25B
Vec_Button_1_4 EQU $C815
Draw_VL_b EQU $F3D2
Mov_Draw_VLc_a EQU $F3AD
PRINT_SHIPS_X EQU $F391
Vec_Music_Wk_A EQU $C842
Vec_Expl_2 EQU $C859
Vec_Expl_ChanA EQU $C853
SET_REFRESH EQU $F1A2
Dec_3_Counters EQU $F55A
VEC_JOY_RESLTN EQU $C81A
VEC_COUNTER_6 EQU $C833
INTENSITY_A EQU $F2AB
RANDOM_3 EQU $F511
VEC_MUSIC_WK_A EQU $C842
VEC_BTN_STATE EQU $C80F
MUSIC4 EQU $FDD3
MOVETO_IX_A EQU $F30E
Rot_VL_ab EQU $F610
musicc EQU $FF7A
VEC_EXPL_CHANA EQU $C853
Abs_a_b EQU $F584
DSWM_W3 EQU $426B
DOT_HERE EQU $F2C5
PRINT_TEXT_STR_113318802 EQU $45D3
Mov_Draw_VL_d EQU $F3BE
MUSIC1 EQU $FD0D
Vec_Joy_Resltn EQU $C81A
VEC_DURATION EQU $C857
Vec_Dot_Dwell EQU $C828
Moveto_ix_a EQU $F30E
DRAW_VLCS EQU $F3D6
VEC_NMI_VECTOR EQU $CBFB
Vec_Text_Width EQU $C82B
Draw_VL_ab EQU $F3D8
RISE_RUN_Y EQU $F601
DRAW_VL_MODE EQU $F46E
Vec_Default_Stk EQU $CBEA
Vec_Joy_2_Y EQU $C81E
VEC_EXPL_CHANB EQU $C85D
VEC_RFRSH_LO EQU $C83D
INTENSITY_5F EQU $F2A5
Xform_Run EQU $F65D
SLR_FG_COUNT EQU $437A
MOVETO_IX EQU $F310
Rot_VL_Mode_a EQU $F61F
MOD16.M16_DPOS EQU $40BE
LLR_SKIP_GP EQU $42D8
Delay_0 EQU $F579
Vec_RiseRun_Len EQU $C83B
music9 EQU $FF26
Xform_Rise EQU $F663
SDCP_CLIP EQU $45AC
Vec_Expl_1 EQU $C858
Vec_Misc_Count EQU $C823
DRAW_VLP_7F EQU $F408
PRINT_LIST_HW EQU $F385
Sound_Byte EQU $F256
Rise_Run_X EQU $F5FF
VEC_EXPL_CHAN EQU $C85C
Vec_Music_Twang EQU $C858
DOT_IX EQU $F2C1
DRAW_VLP EQU $F410
Vec_Cold_Flag EQU $CBFE
WAIT_RECAL EQU $F192
Intensity_5F EQU $F2A5
DRAW_VL_AB EQU $F3D8
RESET0REF EQU $F354
CLEAR_X_D EQU $F548
VEC_RFRSH_HI EQU $C83E
READ_BTNS EQU $F1BA
Dot_List_Reset EQU $F2DE
Vec_Button_2_4 EQU $C819
Mov_Draw_VL EQU $F3BC
MUSIC3 EQU $FD81
VEC_TEXT_HEIGHT EQU $C82A
DRAW_GRID_VL EQU $FF9F
Vec_NMI_Vector EQU $CBFB
_MARKER_VECTORS EQU $0119
VEC_ANGLE EQU $C836
Vec_Expl_Chans EQU $C854
Moveto_d EQU $F312
RESET0INT EQU $F36B
Init_VIA EQU $F14C
Vec_Num_Game EQU $C87A
Vec_Str_Ptr EQU $C82C
VEC_JOY_MUX_1_X EQU $C81F
_TILE_PATH0 EQU $0135
VEC_DEFAULT_STK EQU $CBEA
Clear_x_d EQU $F548
New_High_Score EQU $F8D8
CHECK0REF EQU $F34F
BITMASK_A EQU $F57E
DRAW_PAT_VL_A EQU $F434
DRAW_PAT_VL_D EQU $F439
DELAY_B EQU $F57A
Dot_List EQU $F2D5
musicb EQU $FF62
SDCP_USE_OVERRIDE EQU $44E2
MUSIC7 EQU $FEC6
DSWM_NO_NEGATE_DX EQU $41C3
VEC_TWANG_TABLE EQU $C851
Draw_Line_d EQU $F3DF
Vec_Counter_3 EQU $C830
SLR_RAM_Y_ZERO EQU $4427
_MARKER_PATH0 EQU $011F
COMPARE_SCORE EQU $F8C7
STRIP_ZEROS EQU $F8B7
SDCP_SET_INTENS EQU $44E4
_TILE_VECTORS EQU $0131
SLR_ROM_Y_ZERO EQU $4459
SDCP_SKIP_PATH EQU $450E
VEC_COUNTER_3 EQU $C830
VEC_JOY_1_X EQU $C81B
Draw_VL EQU $F3DD
Mov_Draw_VL_a EQU $F3B9
musicd EQU $FF8F
VEC_SWI2_VECTOR EQU $CBF2
Intensity_7F EQU $F2A9
Do_Sound EQU $F289
PRINT_STR_YX EQU $F378
VEC_COUNTERS EQU $C82E
Abs_b EQU $F58B
XFORM_RISE EQU $F663
Obj_Will_Hit_u EQU $F8E5
Vec_Music_Wk_5 EQU $C847
Print_List_hw EQU $F385
Warm_Start EQU $F06C
JOY_ANALOG EQU $F1F5
XFORM_RUN_A EQU $F65B
MUSIC8 EQU $FEF8
Draw_VLp_7F EQU $F408
J1Y_BUILTIN EQU $410D
Draw_Sync_List_At_With_Mirrors EQU $4125
music8 EQU $FEF8
DOT_D EQU $F2C3
VEC_MUSIC_TWANG EQU $C858
Dot_d EQU $F2C3
SLR_ROM_OFFSETS EQU $4436
Vec_Pattern EQU $C829
MOVETO_IX_7F EQU $F30C
DRAW_VL EQU $F3DD
SOUND_BYTES_X EQU $F284
MUSICB EQU $FF62
Mov_Draw_VL_ab EQU $F3B7
Vec_Max_Players EQU $C84F
DSWM_NEXT_NO_NEGATE_Y EQU $41FB
MOV_DRAW_VL EQU $F3BC
Vec_Music_Wk_6 EQU $C846
music1 EQU $FD0D
SELECT_GAME EQU $F7A9
SOUND_BYTE EQU $F256
ADD_SCORE_D EQU $F87C
VEC_COUNTER_5 EQU $C832
DELAY_3 EQU $F56D
Mov_Draw_VL_b EQU $F3B1
DP_TO_D0 EQU $F1AA
Rot_VL_dft EQU $F637
Vec_Button_1_3 EQU $C814
VEC_JOY_MUX_1_Y EQU $C820
Init_Music_chk EQU $F687
SLR_ROM_VISIBLE EQU $44A0
VEC_BUTTON_2_4 EQU $C819
CLEAR_X_B_A EQU $F552
_GROUND_VECTORS EQU $0147
RANDOM EQU $F517
VEC_MUSIC_WORK EQU $C83F
WARM_START EQU $F06C
Vec_Counter_5 EQU $C832
VEC_MUSIC_WK_7 EQU $C845
MOV_DRAW_VL_B EQU $F3B1
Print_Ships_x EQU $F391
SLR_DRAW_VECTOR EQU $44A9
MOV_DRAW_VLC_A EQU $F3AD
Vec_Joy_1_Y EQU $C81C
Vec_Expl_ChanB EQU $C85D
Add_Score_a EQU $F85E
VEC_JOY_MUX_2_Y EQU $C822
Move_Mem_a EQU $F683
CLEAR_SOUND EQU $F272
SLR_OBJ_DONE EQU $44D3
Vec_Button_1_2 EQU $C813
Vec_0Ref_Enable EQU $C824
VEC_RISERUN_TMP EQU $C834
Init_OS EQU $F18B
Vec_Rfrsh_lo EQU $C83D
Vec_Expl_Timer EQU $C877
VEC_MUSIC_PTR EQU $C853
Clear_x_b_80 EQU $F550
SLR_BG_COUNT EQU $4356
Vec_Joy_Mux EQU $C81F
Vec_Button_2_1 EQU $C816
VEC_FREQ_TABLE EQU $C84D
VEC_JOY_2_X EQU $C81D
MUSIC5 EQU $FE38
music7 EQU $FEC6


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "SCROLL TEST"
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
    ; Initialize bank tracking vars to 0 (prevents spurious $DF00 writes)
    LDA #0
    STA >CURRENT_ROM_BANK   ; Bank 0 is always active at boot
    CLR >LEVEL_LOADED       ; No level loaded yet (flag, not a pointer)
; Bank 0 ($0000) is active; fixed bank 3 ($4000-$7FFF) always visible
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
LEVEL_BG_ROM_PTR     EQU $C880+$48   ; BG layer ROM pointer (2 bytes)
LEVEL_GP_ROM_PTR     EQU $C880+$4A   ; GP layer ROM pointer (2 bytes)
LEVEL_FG_ROM_PTR     EQU $C880+$4C   ; FG layer ROM pointer (2 bytes)
LEVEL_GP_PTR         EQU $C880+$4E   ; GP active pointer (RAM buffer after LOAD_LEVEL) (2 bytes)
LEVEL_BANK           EQU $C880+$50   ; Bank ID for current level (for multibank) (1 bytes)
SLR_CUR_X            EQU $C880+$51   ; SHOW_LEVEL: tracked beam X for per-segment clipping (1 bytes)
LEVEL_GP_BUFFER      EQU $C880+$52   ; GP objects RAM buffer (max 32 objects × 15 bytes) (480 bytes)
LCOL_PX              EQU $C880+$232   ; LEVEL_COLLISION_Y player world_x input (16-bit) (2 bytes)
LCOL_BEST_Y          EQU $C880+$234   ; LEVEL_COLLISION_Y best floor y found (signed byte) (1 bytes)
LCOL_PY              EQU $C880+$235   ; LEVEL_COLLISION_Y player feet Y (player_y - player_hh) (1 bytes)
LCOL_PHH             EQU $C880+$236   ; LEVEL_COLLISION_Y player half_height (1 bytes)
UGPC_OUTER_IDX       EQU $C880+$237   ; GP-GP outer loop index (1 bytes)
UGPC_OUTER_MAX       EQU $C880+$238   ; GP-GP outer loop max (count-1) (1 bytes)
UGPC_INNER_IDX       EQU $C880+$239   ; GP-GP inner loop index (1 bytes)
UGPC_DX              EQU $C880+$23A   ; GP-GP |dx| (16-bit) (2 bytes)
UGPC_DIST            EQU $C880+$23C   ; GP-GP Manhattan distance (16-bit) (2 bytes)
UGFC_GP_IDX          EQU $C880+$23E   ; GP-FG outer loop GP index (1 bytes)
UGFC_FG_COUNT        EQU $C880+$23F   ; GP-FG inner loop FG count (1 bytes)
UGFC_DX              EQU $C880+$240   ; GP-FG |dx| (1 bytes)
UGFC_DY              EQU $C880+$241   ; GP-FG |dy| (1 bytes)
VAR_CAMERA_X         EQU $C880+$242   ; User variable: camera_x (2 bytes)
VAR_CAMERA_Y         EQU $C880+$244   ; User variable: camera_y (2 bytes)
VAR_JOY_X            EQU $C880+$246   ; User variable: joy_x (2 bytes)
VAR_JOY_Y            EQU $C880+$248   ; User variable: joy_y (2 bytes)
VAR_ARG0             EQU $CB80   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $CB82   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $CB84   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $CB86   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $CB88   ; Function argument 4 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $CB8A   ; Current ROM bank ID (multibank tracking) (1 bytes)


;***************************************************************************
; MAIN PROGRAM (Bank #0)
;***************************************************************************

MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    LDD #0
    STD VAR_CAMERA_X
    LDD #0
    STD VAR_CAMERA_Y
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
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'world'
    ; Level asset index: 0 (multibank)
    LDX #0
    JSR LOAD_LEVEL_BANKED

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    JSR J1X_BUILTIN
    STD RESULT
    STD VAR_JOY_X
    JSR J1Y_BUILTIN
    STD RESULT
    STD VAR_JOY_Y
    LDD #20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBGT .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_1
    LDD >VAR_CAMERA_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #3
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_CAMERA_X
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    LDD #-20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBLT .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    LBEQ IF_NEXT_3
    LDD >VAR_CAMERA_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #3
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_CAMERA_X
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LDD #20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_Y
    CMPD TMPVAL
    LBGT .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    LBEQ IF_NEXT_5
    LDD >VAR_CAMERA_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #3
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_CAMERA_Y
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    LDD #-20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_Y
    CMPD TMPVAL
    LBLT .CMP_3_TRUE
    LDD #0
    LBRA .CMP_3_END
.CMP_3_TRUE:
    LDD #1
.CMP_3_END:
    LBEQ IF_NEXT_7
    LDD >VAR_CAMERA_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #3
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_CAMERA_Y
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
    ; CLAMP: Clamp value to range [min, max]
    LDD >VAR_CAMERA_X
    STD TMPPTR     ; Save value
    LDD #-128
    STD TMPPTR+2   ; Save min
    LDD #400
    STD TMPPTR+4   ; Save max
    LDD TMPPTR     ; Load value
    CMPD TMPPTR+2  ; Compare with min
    LBGE .CLAMP_0_CHK_MAX ; Branch if value >= min
    LDD TMPPTR+2
    STD RESULT
    LBRA .CLAMP_0_END
.CLAMP_0_CHK_MAX:
    LDD TMPPTR     ; Load value again
    CMPD TMPPTR+4  ; Compare with max
    LBLE .CLAMP_0_OK  ; Branch if value <= max
    LDD TMPPTR+4
    STD RESULT
    LBRA .CLAMP_0_END
.CLAMP_0_OK:
    LDD TMPPTR
    STD RESULT
.CLAMP_0_END:
    STD VAR_CAMERA_X
    ; CLAMP: Clamp value to range [min, max]
    LDD >VAR_CAMERA_Y
    STD TMPPTR     ; Save value
    LDD #-300
    STD TMPPTR+2   ; Save min
    LDD #127
    STD TMPPTR+4   ; Save max
    LDD TMPPTR     ; Load value
    CMPD TMPPTR+2  ; Compare with min
    LBGE .CLAMP_1_CHK_MAX ; Branch if value >= min
    LDD TMPPTR+2
    STD RESULT
    LBRA .CLAMP_1_END
.CLAMP_1_CHK_MAX:
    LDD TMPPTR     ; Load value again
    CMPD TMPPTR+4  ; Compare with max
    LBLE .CLAMP_1_OK  ; Branch if value <= max
    LDD TMPPTR+4
    STD RESULT
    LBRA .CLAMP_1_END
.CLAMP_1_OK:
    LDD TMPPTR
    STD RESULT
.CLAMP_1_END:
    STD VAR_CAMERA_Y
    ; ===== SET_CAMERA_X builtin =====
    LDD >VAR_CAMERA_X
    STD >CAMERA_X    ; Store 16-bit camera X scroll offset
    LDD #0
    STD RESULT
    ; ===== SET_CAMERA_Y builtin =====
    LDD >VAR_CAMERA_Y
    STD >CAMERA_Y    ; Store 16-bit camera Y scroll offset
    LDD #0
    STD RESULT
    ; ===== SHOW_LEVEL builtin =====
    JSR SHOW_LEVEL_RUNTIME
    LDD #0
    STD RESULT
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: marker (index=1, 2 paths)
    LDD #0
    TFR B,A       ; X position (low byte) — B already holds it
    STA TMPPTR    ; Save X to temporary storage
    LDD #0
    TFR B,A       ; Y position (low byte) — B already holds it
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    LDX #1        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    CLR DRAW_VEC_INTENSITY  ; Reset: next DRAW_VECTOR uses .vec intensities
    LDD #0
    STD RESULT
    RTS


; ================================================
