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
LEVEL_GP_BUFFER      EQU $C880+$52   ; GP objects RAM buffer (max 8 objects × 15 bytes) (120 bytes)
UGPC_OUTER_IDX       EQU $C880+$CA   ; GP-GP outer loop index (1 bytes)
UGPC_OUTER_MAX       EQU $C880+$CB   ; GP-GP outer loop max (count-1) (1 bytes)
UGPC_INNER_IDX       EQU $C880+$CC   ; GP-GP inner loop index (1 bytes)
UGPC_DX              EQU $C880+$CD   ; GP-GP |dx| (16-bit) (2 bytes)
UGPC_DIST            EQU $C880+$CF   ; GP-GP Manhattan distance (16-bit) (2 bytes)
UGFC_GP_IDX          EQU $C880+$D1   ; GP-FG outer loop GP index (1 bytes)
UGFC_FG_COUNT        EQU $C880+$D2   ; GP-FG inner loop FG count (1 bytes)
UGFC_DX              EQU $C880+$D3   ; GP-FG |dx| (1 bytes)
UGFC_DY              EQU $C880+$D4   ; GP-FG |dy| (1 bytes)
VAR_CAMERA_X         EQU $C880+$D5   ; User variable: CAMERA_X (2 bytes)
VAR_CAMERA_Y         EQU $C880+$D7   ; User variable: CAMERA_Y (2 bytes)
VAR_JOY_X            EQU $C880+$D9   ; User variable: JOY_X (2 bytes)
VAR_JOY_Y            EQU $C880+$DB   ; User variable: JOY_Y (2 bytes)
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
MOVETO_IX_7F EQU $F30C
Sound_Bytes EQU $F27D
DVB_PATH_LOOP EQU $404B
DRAW_VLC EQU $F3CE
DRAW_PAT_VL_D EQU $F439
LLR_GP_DONE EQU $42D2
Vec_Music_Work EQU $C83F
ADD_SCORE_D EQU $F87C
RANDOM EQU $F517
VEC_MAX_PLAYERS EQU $C84F
DRAW_VLP EQU $F410
Draw_Pat_VL EQU $F437
MOV_DRAW_VL_AB EQU $F3B7
Vec_Brightness EQU $C827
music6 EQU $FE76
Vec_Button_2_3 EQU $C818
VEC_JOY_2_Y EQU $C81E
RANDOM_3 EQU $F511
VEC_MUSIC_WK_7 EQU $C845
DVB_DONE EQU $405B
GET_RUN_IDX EQU $F5DB
PRINT_LIST_HW EQU $F385
Mov_Draw_VL_ab EQU $F3B7
Vec_Counter_2 EQU $C82F
VEC_EXPL_2 EQU $C859
DP_TO_C8 EQU $F1AF
Intensity_3F EQU $F2A1
CLEAR_X_256 EQU $F545
VEC_BUTTON_2_1 EQU $C816
Vec_Expl_3 EQU $C85A
Vec_NMI_Vector EQU $CBFB
DRAW_PAT_VL EQU $F437
Vec_Freq_Table EQU $C84D
Intensity_7F EQU $F2A9
Dot_ix EQU $F2C1
Vec_Music_Chan EQU $C855
Vec_Joy_2_Y EQU $C81E
Bitmask_a EQU $F57E
Obj_Will_Hit_u EQU $F8E5
SDCP_DONE EQU $45CC
SLR_DRAW_CLIPPED_PATH EQU $44D0
MUSIC1 EQU $FD0D
SLR_PATH_LOOP EQU $44A9
musicb EQU $FF62
VEC_EXPL_CHANS EQU $C854
Vec_Joy_1_X EQU $C81B
PRINT_SHIPS EQU $F393
VEC_RANDOM_SEED EQU $C87D
Delay_b EQU $F57A
SLR_INTENSITY_READ EQU $43B9
LEVEL_BANK_TABLE EQU $4009
Vec_Music_Wk_7 EQU $C845
SLR_OBJ_DONE EQU $44CD
Vec_Rise_Index EQU $C839
VEC_BTN_STATE EQU $C80F
SLR_RAM_Y_VISIBLE EQU $4428
INIT_MUSIC_CHK EQU $F687
SLR_ROM_ADDR_LOOP EQU $43AE
SOUND_BYTES EQU $F27D
SLR_BG_COUNT EQU $4350
VEC_RISE_INDEX EQU $C839
Rot_VL EQU $F616
DEC_COUNTERS EQU $F563
Sound_Byte_x EQU $F259
XFORM_RUN EQU $F65D
DOT_LIST_RESET EQU $F2DE
Obj_Will_Hit EQU $F8F3
DRAW_VECTOR_BANKED EQU $4018
RESET_PEN EQU $F35B
RISE_RUN_LEN EQU $F603
VEC_MUSIC_WK_A EQU $C842
SLR_ROM_Y_VISIBLE EQU $445A
Vec_IRQ_Vector EQU $CBF8
New_High_Score EQU $F8D8
LLR_COPY_OBJECTS EQU $42DA
CLEAR_SOUND EQU $F272
Vec_Music_Wk_1 EQU $C84B
Mov_Draw_VLc_a EQU $F3AD
MOV_DRAW_VL_B EQU $F3B1
Mov_Draw_VLcs EQU $F3B5
Random EQU $F517
MOVETO_IX EQU $F310
VEC_IRQ_VECTOR EQU $CBF8
Init_Music_x EQU $F692
SLR_PATH_DONE EQU $44C1
Sound_Byte_raw EQU $F25B
Vec_Music_Wk_5 EQU $C847
LLR_COPY_LOOP EQU $42DA
Print_Str EQU $F495
Draw_VL_ab EQU $F3D8
Vec_Button_2_4 EQU $C819
MOD16.M16_DPOS EQU $40B8
Wait_Recal EQU $F192
Init_OS_RAM EQU $F164
SOUND_BYTE_RAW EQU $F25B
DELAY_0 EQU $F579
INTENSITY_5F EQU $F2A5
music9 EQU $FF26
INIT_MUSIC_BUF EQU $F533
Clear_x_256 EQU $F545
CLEAR_X_D EQU $F548
Moveto_ix_FF EQU $F308
musicd EQU $FF8F
VEC_SWI_VECTOR EQU $CBFB
MUSIC3 EQU $FD81
VEC_RISERUN_LEN EQU $C83B
Vec_Button_1_2 EQU $C813
SLR_ROM_A_ZERO EQU $4492
Abs_b EQU $F58B
Vec_High_Score EQU $CBEB
_MARKER_PATH1 EQU $0127
Dot_ix_b EQU $F2BE
VEC_EXPL_TIMER EQU $C877
XFORM_RISE EQU $F663
SLR_RAM_Y_ZERO EQU $4421
PRINT_STR_HWYX EQU $F373
SELECT_GAME EQU $F7A9
XFORM_RISE_A EQU $F661
Mov_Draw_VL EQU $F3BC
Vec_Rfrsh_lo EQU $C83D
Vec_Expl_ChanB EQU $C85D
VEC_JOY_2_X EQU $C81D
Draw_VLp_scale EQU $F40C
VEC_MUSIC_WK_5 EQU $C847
MOD16.M16_LOOP EQU $40CF
Clear_Sound EQU $F272
DP_to_C8 EQU $F1AF
WAIT_RECAL EQU $F192
VEC_COUNTERS EQU $C82E
SDCP_W_DRAW EQU $4597
VEC_BUTTONS EQU $C811
Dot_here EQU $F2C5
Vec_Twang_Table EQU $C851
Add_Score_d EQU $F87C
Dot_d EQU $F2C3
MOV_DRAW_VLCS EQU $F3B5
Select_Game EQU $F7A9
DRAW_VLP_7F EQU $F408
DO_SOUND EQU $F289
VEC_MUSIC_FLAG EQU $C856
RISE_RUN_X EQU $F5FF
Rise_Run_Angle EQU $F593
DRAW_VL EQU $F3DD
VEC_MUSIC_PTR EQU $C853
CLEAR_X_B_A EQU $F552
VEC_NMI_VECTOR EQU $CBFB
Delay_2 EQU $F571
Vec_Default_Stk EQU $CBEA
Strip_Zeros EQU $F8B7
Compare_Score EQU $F8C7
SOUND_BYTE EQU $F256
Draw_Pat_VL_d EQU $F439
VECTOR_ADDR_TABLE EQU $4003
BITMASK_A EQU $F57E
Sound_Byte EQU $F256
RISE_RUN_Y EQU $F601
ROT_VL_AB EQU $F610
Draw_VL_b EQU $F3D2
Dec_6_Counters EQU $F55E
Reset0Int EQU $F36B
Draw_VL EQU $F3DD
Vec_Joy_1_Y EQU $C81C
Moveto_ix EQU $F310
Vec_Expl_Timer EQU $C877
Vec_ADSR_Timers EQU $C85E
VEC_PATTERN EQU $C829
SHOW_LEVEL_RUNTIME EQU $4322
LLR_SKIP_GP EQU $42D2
SLR_OBJ_NEXT EQU $44C3
Draw_VLp_7F EQU $F408
MOD16.M16_RCHECK EQU $40C0
Vec_Expl_4 EQU $C85B
DSWM_W1 EQU $4192
VEC_TEXT_HEIGHT EQU $C82A
Reset0Ref EQU $F354
CLEAR_X_B_80 EQU $F550
DOT_D EQU $F2C3
VEC_NUM_PLAYERS EQU $C879
Vec_0Ref_Enable EQU $C824
Joy_Digital EQU $F1F8
MOV_DRAW_VL_A EQU $F3B9
Dec_3_Counters EQU $F55A
VEC_STR_PTR EQU $C82C
Vec_Button_1_1 EQU $C812
J1Y_BUILTIN EQU $4107
_MARKER_PATH0 EQU $011E
Vec_Music_Twang EQU $C858
DEC_6_COUNTERS EQU $F55E
VEC_LOOP_COUNT EQU $C825
Add_Score_a EQU $F85E
Print_Str_yx EQU $F378
Rise_Run_Y EQU $F601
SLR_FOREGROUND EQU $4374
Vec_Random_Seed EQU $C87D
WARM_START EQU $F06C
Clear_x_d EQU $F548
INIT_OS EQU $F18B
Read_Btns_Mask EQU $F1B4
SLR_GAMEPLAY EQU $4362
Vec_SWI_Vector EQU $CBFB
Vec_Music_Freq EQU $C861
Reset0Ref_D0 EQU $F34A
Vec_Music_Flag EQU $C856
VEC_RUN_INDEX EQU $C837
SLR_DONE EQU $4386
PRINT_TEXT_STR_113318802 EQU $45CD
VEC_FREQ_TABLE EQU $C84D
JOY_DIGITAL EQU $F1F8
Print_Str_hwyx EQU $F373
Delay_RTS EQU $F57D
VEC_JOY_1_X EQU $C81B
DSWM_NO_NEGATE_X EQU $4148
VEC_COUNTER_1 EQU $C82E
Clear_Score EQU $F84F
Vec_Expl_Chan EQU $C85C
MOVE_MEM_A_1 EQU $F67F
Intensity_a EQU $F2AB
INIT_OS_RAM EQU $F164
Xform_Run EQU $F65D
VEC_COUNTER_5 EQU $C832
MOV_DRAW_VLC_A EQU $F3AD
Vec_ADSR_Table EQU $C84F
Vec_Cold_Flag EQU $CBFE
RESET0REF EQU $F354
DP_to_D0 EQU $F1AA
LOAD_LEVEL_RUNTIME EQU $4272
Clear_C8_RAM EQU $F542
DSWM_NO_NEGATE_DY EQU $41B3
VEC_HIGH_SCORE EQU $CBEB
SOUND_BYTE_X EQU $F259
Vec_Max_Players EQU $C84F
VEC_MAX_GAMES EQU $C850
Vec_Joy_Mux_1_X EQU $C81F
SDCP_W_MOVE EQU $45C0
Vec_Prev_Btns EQU $C810
SLR_DRAW_OBJECTS EQU $4393
VEC_JOY_MUX_2_X EQU $C821
Init_Music_chk EQU $F687
Read_Btns EQU $F1BA
Vec_Duration EQU $C857
Draw_Grid_VL EQU $FF9F
VEC_ADSR_TIMERS EQU $C85E
VEC_ANGLE EQU $C836
VEC_SWI2_VECTOR EQU $CBF2
VEC_JOY_MUX_1_Y EQU $C820
LLR_COPY_DONE EQU $4321
Vec_Pattern EQU $C829
Abs_a_b EQU $F584
PRINT_TEXT_STR_3213661242 EQU $45D3
INTENSITY_7F EQU $F2A9
DRAW_GRID_VL EQU $FF9F
MOVETO_X_7F EQU $F2F2
DRAW_VL_MODE EQU $F46E
VEC_TEXT_HW EQU $C82A
MOVETO_IX_FF EQU $F308
Print_Str_d EQU $F37A
VEC_RFRSH EQU $C83D
Vec_Button_1_3 EQU $C814
ABS_B EQU $F58B
Vec_Max_Games EQU $C850
INTENSITY_1F EQU $F29D
Vec_Buttons EQU $C811
INIT_MUSIC EQU $F68D
VEC_MUSIC_WORK EQU $C83F
OBJ_WILL_HIT EQU $F8F3
Vec_RiseRun_Tmp EQU $C834
Sound_Bytes_x EQU $F284
Vec_Music_Wk_6 EQU $C846
Vec_Run_Index EQU $C837
MOV_DRAW_VL_D EQU $F3BE
DOT_HERE EQU $F2C5
music8 EQU $FEF8
Moveto_d EQU $F312
SDCP_CLIP EQU $45A6
ROT_VL EQU $F616
Vec_Num_Players EQU $C879
SDCP_SET_INTENS EQU $44DE
Init_Music EQU $F68D
Draw_Pat_VL_a EQU $F434
Vec_Seed_Ptr EQU $C87B
LOAD_LEVEL_BANKED EQU $4067
SDCP_USE_OVERRIDE EQU $44DC
DRAW_VL_B EQU $F3D2
Do_Sound EQU $F289
DRAW_LINE_D EQU $F3DF
VEC_RISERUN_TMP EQU $C834
READ_BTNS EQU $F1BA
DOT_IX EQU $F2C1
MOD16.M16_DONE EQU $40EE
Print_List_hw EQU $F385
Vec_Rfrsh EQU $C83D
music3 EQU $FD81
VEC_EXPL_3 EQU $C85A
CLEAR_X_B EQU $F53F
INIT_VIA EQU $F14C
Move_Mem_a EQU $F683
PRINT_LIST EQU $F38A
Draw_VLp_FF EQU $F404
DSWM_NEXT_NO_NEGATE_Y EQU $41F5
Vec_Joy_Mux_2_X EQU $C821
VEC_JOY_MUX_2_Y EQU $C822
VEC_SND_SHADOW EQU $C800
ROT_VL_MODE_A EQU $F61F
Vec_Expl_1 EQU $C858
VEC_BUTTON_1_1 EQU $C812
ASSET_ADDR_TABLE EQU $4010
DRAW_SYNC_LIST_AT_WITH_MIRRORS EQU $411F
SLR_FG_COUNT EQU $4374
SOUND_BYTES_X EQU $F284
Vec_Misc_Count EQU $C823
DELAY_B EQU $F57A
Vec_Angle EQU $C836
OBJ_HIT EQU $F8FF
VEC_BUTTON_2_2 EQU $C817
Vec_Music_Wk_A EQU $C842
ROT_VL_DFT EQU $F637
VEC_MUSIC_FREQ EQU $C861
NEW_HIGH_SCORE EQU $F8D8
VEC_DURATION EQU $C857
DELAY_2 EQU $F571
INTENSITY_A EQU $F2AB
VEC_MUSIC_TWANG EQU $C858
Xform_Run_a EQU $F65B
MOV_DRAW_VL EQU $F3BC
Vec_Dot_Dwell EQU $C828
VEC_ADSR_TABLE EQU $C84F
DSWM_NEXT_PATH EQU $41E3
Print_Ships EQU $F393
DRAW_VLP_FF EQU $F404
DRAW_VLP_B EQU $F40E
Vec_Button_2_1 EQU $C816
RECALIBRATE EQU $F2E6
Vec_Joy_Mux_2_Y EQU $C822
Vec_Text_Width EQU $C82B
VEC_RFRSH_LO EQU $C83D
Vec_Expl_ChanA EQU $C853
VEC_JOY_1_Y EQU $C81C
VEC_BUTTON_2_3 EQU $C818
SDCP_SEG_LOOP EQU $455E
Random_3 EQU $F511
Explosion_Snd EQU $F92E
Dot_List_Reset EQU $F2DE
SDCP_SKIP_PATH EQU $4508
RESET0INT EQU $F36B
Vec_Num_Game EQU $C87A
READ_BTNS_MASK EQU $F1B4
Rot_VL_Mode_a EQU $F61F
DRAW_VLCS EQU $F3D6
VEC_EXPL_CHANB EQU $C85D
Mov_Draw_VL_d EQU $F3BE
Get_Rise_Run EQU $F5EF
Vec_Counter_1 EQU $C82E
XFORM_RUN_A EQU $F65B
VEC_COLD_FLAG EQU $CBFE
DSWM_NEXT_SET_INTENSITY EQU $41E9
MOVETO_D_7F EQU $F2FC
SLR_ROM_Y_ZERO EQU $4453
VEC_MUSIC_WK_1 EQU $C84B
Vec_FIRQ_Vector EQU $CBF5
SET_REFRESH EQU $F1A2
Vec_Snd_Shadow EQU $C800
SLR_GP_COUNT EQU $4362
GET_RISE_RUN EQU $F5EF
DOT_LIST EQU $F2D5
Vec_Rfrsh_hi EQU $C83E
Vec_Counter_3 EQU $C830
SLR_ROM_OFFSETS EQU $4430
Recalibrate EQU $F2E6
MOVETO_IX_A EQU $F30E
Delay_1 EQU $F575
ASSET_BANK_TABLE EQU $400C
VEC_COUNTER_6 EQU $C833
PRINT_LIST_CHK EQU $F38C
Vec_Button_1_4 EQU $C815
VEC_EXPL_1 EQU $C858
VEC_EXPL_FLAG EQU $C867
Vec_Expl_Chans EQU $C854
Print_Ships_x EQU $F391
MUSICB EQU $FF62
RESET0REF_D0 EQU $F34A
J1X_BUILTIN EQU $40EF
DRAW_PAT_VL_A EQU $F434
Rot_VL_ab EQU $F610
Dec_Counters EQU $F563
VEC_MISC_COUNT EQU $C823
SLR_ROM_VISIBLE EQU $449A
Vec_Text_HW EQU $C82A
Rot_VL_dft EQU $F637
Joy_Analog EQU $F1F5
DELAY_3 EQU $F56D
Intensity_5F EQU $F2A5
MUSICC EQU $FF7A
SLR_RAM_VISIBLE EQU $4402
CLEAR_C8_RAM EQU $F542
Check0Ref EQU $F34F
Vec_Expl_Flag EQU $C867
DSWM_NO_NEGATE_DX EQU $41BD
music2 EQU $FD1D
Vec_SWI2_Vector EQU $CBF2
Vec_Button_2_2 EQU $C817
Vec_Counter_4 EQU $C831
Draw_VLp EQU $F410
VEC_EXPL_CHAN EQU $C85C
VEC_EXPL_4 EQU $C85B
Vec_Counter_6 EQU $C833
SDCP_MOVETO_W EQU $4555
Set_Refresh EQU $F1A2
VEC_BRIGHTNESS EQU $C827
Vec_Joy_Resltn EQU $C81A
Xform_Rise EQU $F663
MUSICA EQU $FF44
JOY_ANALOG EQU $F1F5
DSWM_NEXT_NO_NEGATE_X EQU $4202
Vec_Joy_Mux_1_Y EQU $C820
RISE_RUN_ANGLE EQU $F593
VEC_TEXT_WIDTH EQU $C82B
MOVE_MEM_A EQU $F683
INTENSITY_3F EQU $F2A1
MUSIC8 EQU $FEF8
SLR_RAM_A_ZERO EQU $43FA
DEC_3_COUNTERS EQU $F55A
Print_List_chk EQU $F38C
DO_SOUND_X EQU $F28C
DSWM_SET_INTENSITY EQU $4121
VEC_JOY_MUX EQU $C81F
VEC_BUTTON_2_4 EQU $C819
MUSIC7 EQU $FEC6
DOT_IX_B EQU $F2BE
Intensity_1F EQU $F29D
DELAY_1 EQU $F575
CLEAR_SCORE EQU $F84F
ROT_VL_MODE EQU $F62B
Delay_0 EQU $F579
VEC_COUNTER_3 EQU $C830
VEC_BUTTON_1_3 EQU $C814
Draw_VLcs EQU $F3D6
Vec_Str_Ptr EQU $C82C
Vec_Joy_2_X EQU $C81D
DSWM_W2 EQU $41D4
DSWM_LOOP EQU $419B
VEC_COUNTER_4 EQU $C831
VEC_FIRQ_VECTOR EQU $CBF5
VEC_NUM_GAME EQU $C87A
MUSIC2 EQU $FD1D
DSWM_DONE EQU $4271
VEC_SEED_PTR EQU $C87B
Vec_Loop_Count EQU $C825
Vec_Expl_2 EQU $C859
Delay_3 EQU $F56D
ABS_A_B EQU $F584
_GROUND_PATH0 EQU $0148
Do_Sound_x EQU $F28C
Reset_Pen EQU $F35B
Vec_Joy_Mux EQU $C81F
Vec_Counter_5 EQU $C832
SDCP_ABS_OK EQU $4509
VEC_MUSIC_WK_6 EQU $C846
ADD_SCORE_A EQU $F85E
Draw_VLp_b EQU $F40E
Vec_RiseRun_Len EQU $C83B
PRINT_SHIPS_X EQU $F391
VEC_JOY_MUX_1_X EQU $C81F
MUSIC9 EQU $FF26
VEC_PREV_BTNS EQU $C810
SDCP_CHECK_POS EQU $4504
DP_TO_D0 EQU $F1AA
Init_OS EQU $F18B
Clear_x_b_80 EQU $F550
Vec_Music_Ptr EQU $C853
Draw_VLc EQU $F3CE
Vec_Btn_State EQU $C80F
Move_Mem_a_1 EQU $F67F
music4 EQU $FDD3
MOVETO_D EQU $F312
VEC_0REF_ENABLE EQU $C824
Clear_x_b_a EQU $F552
LEVEL_ADDR_TABLE EQU $400A
VEC_DOT_DWELL EQU $C828
music5 EQU $FE38
Rise_Run_Len EQU $F603
Draw_VL_a EQU $F3DA
Init_VIA EQU $F14C
Moveto_x_7F EQU $F2F2
_TILE_VECTORS EQU $0130
LLR_CLR_GP_LOOP EQU $42B3
music7 EQU $FEC6
Print_List EQU $F38A
MOD16 EQU $409B
musicc EQU $FF7A
Warm_Start EQU $F06C
SLR_OBJ_LOOP EQU $4395
PRINT_STR EQU $F495
_MARKER_VECTORS EQU $0119
Vec_Counters EQU $C82E
MUSICD EQU $FF8F
VEC_MUSIC_CHAN EQU $C855
Xform_Rise_a EQU $F661
Mov_Draw_VL_b EQU $F3B1
COMPARE_SCORE EQU $F8C7
VEC_DEFAULT_STK EQU $CBEA
DELAY_RTS EQU $F57D
COLD_START EQU $F000
VEC_JOY_RESLTN EQU $C81A
Clear_x_b EQU $F53F
Moveto_ix_7F EQU $F30C
Draw_Sync_List_At_With_Mirrors EQU $411F
OBJ_WILL_HIT_U EQU $F8E5
MOD16.M16_END EQU $40DF
DRAW_VL_A EQU $F3DA
CHECK0REF EQU $F34F
Rot_VL_Mode EQU $F62B
Mov_Draw_VL_a EQU $F3B9
musica EQU $FF44
MUSIC4 EQU $FDD3
Draw_VL_mode EQU $F46E
DSWM_NO_NEGATE_Y EQU $413B
Cold_Start EQU $F000
_GROUND_VECTORS EQU $0145
MOD16.M16_RPOS EQU $40CF
GET_RISE_IDX EQU $F5D9
VEC_BUTTON_1_4 EQU $C815
music1 EQU $FD0D
Dot_List EQU $F2D5
PRINT_STR_D EQU $F37A
MUSIC5 EQU $FE38
Vec_SWI3_Vector EQU $CBF2
VEC_EXPL_CHANA EQU $C853
SLR_DRAW_VECTOR EQU $44A3
_TILE_PATH0 EQU $0133
Get_Run_Idx EQU $F5DB
Draw_Line_d EQU $F3DF
DRAW_VLP_SCALE EQU $F40C
Obj_Hit EQU $F8FF
PRINT_STR_YX EQU $F378
DRAW_VL_AB EQU $F3D8
Moveto_ix_a EQU $F30E
INIT_MUSIC_X EQU $F692
Vec_Text_Height EQU $C82A
VECTOR_BANK_TABLE EQU $4000
EXPLOSION_SND EQU $F92E
VEC_RFRSH_HI EQU $C83E
VEC_BUTTON_1_2 EQU $C813
VEC_TWANG_TABLE EQU $C851
MUSIC6 EQU $FE76
VEC_SWI3_VECTOR EQU $CBF2
STRIP_ZEROS EQU $F8B7
Rise_Run_X EQU $F5FF
VEC_COUNTER_2 EQU $C82F
DSWM_W3 EQU $4265
Moveto_d_7F EQU $F2FC
Init_Music_Buf EQU $F533
Get_Rise_Idx EQU $F5D9


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
LEVEL_GP_BUFFER      EQU $C880+$52   ; GP objects RAM buffer (max 8 objects × 15 bytes) (120 bytes)
UGPC_OUTER_IDX       EQU $C880+$CA   ; GP-GP outer loop index (1 bytes)
UGPC_OUTER_MAX       EQU $C880+$CB   ; GP-GP outer loop max (count-1) (1 bytes)
UGPC_INNER_IDX       EQU $C880+$CC   ; GP-GP inner loop index (1 bytes)
UGPC_DX              EQU $C880+$CD   ; GP-GP |dx| (16-bit) (2 bytes)
UGPC_DIST            EQU $C880+$CF   ; GP-GP Manhattan distance (16-bit) (2 bytes)
UGFC_GP_IDX          EQU $C880+$D1   ; GP-FG outer loop GP index (1 bytes)
UGFC_FG_COUNT        EQU $C880+$D2   ; GP-FG inner loop FG count (1 bytes)
UGFC_DX              EQU $C880+$D3   ; GP-FG |dx| (1 bytes)
UGFC_DY              EQU $C880+$D4   ; GP-FG |dy| (1 bytes)
VAR_CAMERA_X         EQU $C880+$D5   ; User variable: CAMERA_X (2 bytes)
VAR_CAMERA_Y         EQU $C880+$D7   ; User variable: CAMERA_Y (2 bytes)
VAR_JOY_X            EQU $C880+$D9   ; User variable: JOY_X (2 bytes)
VAR_JOY_Y            EQU $C880+$DB   ; User variable: JOY_Y (2 bytes)
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
