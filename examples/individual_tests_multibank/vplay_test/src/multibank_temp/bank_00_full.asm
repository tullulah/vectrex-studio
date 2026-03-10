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
Vec_SWI2_Vector EQU $CBF2
Vec_Rfrsh_lo EQU $C83D
SDCP_SKIP_PATH EQU $44BE
SLR_ROM_ADDR_LOOP EQU $439F
Intensity_1F EQU $F29D
Dot_d EQU $F2C3
VECTOR_ADDR_TABLE EQU $4001
Draw_VL_mode EQU $F46E
PRINT_STR_YX EQU $F378
Delay_3 EQU $F56D
Read_Btns_Mask EQU $F1B4
PRINT_SHIPS EQU $F393
VEC_BRIGHTNESS EQU $C827
VEC_MUSIC_WK_1 EQU $C84B
Mov_Draw_VL EQU $F3BC
VEC_LOOP_COUNT EQU $C825
SLR_PATH_LOOP EQU $445F
VEC_EXPL_4 EQU $C85B
SDCP_SET_INTENS EQU $4494
Vec_Num_Game EQU $C87A
VEC_FIRQ_VECTOR EQU $CBF5
_PLATFORM_VECTORS EQU $003D
Vec_Music_Chan EQU $C855
SLR_DONE EQU $4377
VEC_EXPL_3 EQU $C85A
DOT_LIST EQU $F2D5
Warm_Start EQU $F06C
ULR_NEXT EQU $46B6
music3 EQU $FD81
VEC_RISE_INDEX EQU $C839
Intensity_a EQU $F2AB
music4 EQU $FDD3
Vec_Rfrsh_hi EQU $C83E
VEC_DOT_DWELL EQU $C828
Vec_Counters EQU $C82E
Vec_Music_Flag EQU $C856
VEC_BUTTONS EQU $C811
Clear_x_b_80 EQU $F550
SOUND_BYTE_RAW EQU $F25B
DOT_IX_B EQU $F2BE
LLR_COPY_LOOP EQU $42CB
LEVEL_ADDR_TABLE EQU $4004
SLR_DRAW_OBJECTS EQU $4384
Explosion_Snd EQU $F92E
DSWM_NO_NEGATE_DY EQU $41A7
Vec_Expl_3 EQU $C85A
Vec_NMI_Vector EQU $CBFB
Xform_Rise EQU $F663
Vec_Pattern EQU $C829
MOV_DRAW_VL_D EQU $F3BE
MUSIC5 EQU $FE38
SDCP_DONE EQU $4582
DRAW_PAT_VL_D EQU $F439
Clear_Score EQU $F84F
musicb EQU $FF62
SLR_ROM_VISIBLE EQU $4450
Mov_Draw_VL_d EQU $F3BE
VEC_MISC_COUNT EQU $C823
VEC_RFRSH EQU $C83D
VEC_BTN_STATE EQU $C80F
Draw_VL_a EQU $F3DA
Print_List_chk EQU $F38C
DRAW_VLP_FF EQU $F404
Vec_Dot_Dwell EQU $C828
Vec_Rise_Index EQU $C839
SLR_DRAW_VECTOR EQU $4459
Dot_List_Reset EQU $F2DE
Abs_b EQU $F58B
music8 EQU $FEF8
Dot_List EQU $F2D5
Print_List EQU $F38A
VEC_JOY_MUX_1_X EQU $C81F
ULR_UPDATE_LAYER EQU $45B2
VEC_STR_PTR EQU $C82C
UGPC_INNER_DONE EQU $4788
VEC_MUSIC_PTR EQU $C853
Vec_Music_Wk_1 EQU $C84B
MOD16.M16_RCHECK EQU $40E4
Vec_Btn_State EQU $C80F
Vec_Button_1_2 EQU $C813
CLEAR_X_256 EQU $F545
Moveto_d_7F EQU $F2FC
VEC_EXPL_CHANB EQU $C85D
Print_Str_yx EQU $F378
VEC_IRQ_VECTOR EQU $CBF8
Vec_Counter_3 EQU $C830
Vec_Prev_Btns EQU $C810
VEC_BUTTON_1_1 EQU $C812
Moveto_ix_a EQU $F30E
ULR_X_MAX_CHECK EQU $463C
Draw_VLp_b EQU $F40E
VEC_NUM_GAME EQU $C87A
GET_RISE_IDX EQU $F5D9
DEC_3_COUNTERS EQU $F55A
Reset_Pen EQU $F35B
DOT_LIST_RESET EQU $F2DE
DELAY_B EQU $F57A
LLR_COPY_DONE EQU $4312
WAIT_RECAL EQU $F192
PRINT_STR_HWYX EQU $F373
Intensity_7F EQU $F2A9
SLR_ROM_A_ZERO EQU $4448
Clear_x_256 EQU $F545
LLR_GP_DONE EQU $42C3
DSWM_NO_NEGATE_X EQU $413C
DRAW_VL EQU $F3DD
Vec_Joy_Mux_1_Y EQU $C820
Sound_Byte_raw EQU $F25B
SLR_BG_COUNT EQU $4341
VEC_COUNTER_6 EQU $C833
VEC_JOY_MUX_1_Y EQU $C820
Vec_Button_2_2 EQU $C817
Vec_Brightness EQU $C827
Vec_Button_1_1 EQU $C812
DRAW_LINE_D EQU $F3DF
VEC_COUNTER_5 EQU $C832
DSWM_W3 EQU $4259
SOUND_BYTE_X EQU $F259
ADD_SCORE_A EQU $F85E
Clear_x_b_a EQU $F552
Compare_Score EQU $F8C7
DO_SOUND EQU $F289
RESET_PEN EQU $F35B
COMPARE_SCORE EQU $F8C7
Vec_Counter_5 EQU $C832
VEC_ANGLE EQU $C836
ROT_VL EQU $F616
ROT_VL_DFT EQU $F637
Vec_Expl_ChanA EQU $C853
DRAW_VL_MODE EQU $F46E
VEC_MUSIC_WK_A EQU $C842
Vec_Run_Index EQU $C837
Draw_VLcs EQU $F3D6
DRAW_VLP_SCALE EQU $F40C
Vec_Random_Seed EQU $C87D
Draw_VLp EQU $F410
UGPC_SKIP_OUTER_MUL EQU $46E2
Vec_Freq_Table EQU $C84D
VEC_COUNTER_1 EQU $C82E
VEC_SWI2_VECTOR EQU $CBF2
Sound_Bytes_x EQU $F284
PRINT_STR_D EQU $F37A
UGFC_GP_MUL EQU $47B7
STRIP_ZEROS EQU $F8B7
MOV_DRAW_VL_A EQU $F3B9
Vec_Snd_Shadow EQU $C800
DRAW_VLC EQU $F3CE
Dec_6_Counters EQU $F55E
Reset0Int EQU $F36B
Mov_Draw_VLc_a EQU $F3AD
INTENSITY_A EQU $F2AB
READ_BTNS_MASK EQU $F1B4
Vec_Expl_4 EQU $C85B
Print_Ships_x EQU $F391
MOD16.M16_DPOS EQU $40DC
INIT_MUSIC_BUF EQU $F533
Vec_Music_Wk_7 EQU $C845
MOV_DRAW_VL EQU $F3BC
INIT_OS_RAM EQU $F164
SDCP_SEG_LOOP EQU $4514
Vec_Button_2_1 EQU $C816
ULR_GP_FG_COLLISIONS EQU $4799
VEC_NMI_VECTOR EQU $CBFB
music6 EQU $FE76
DVB_DONE EQU $404F
musicc EQU $FF7A
UGFC_NEXT_FG EQU $4863
DSWM_NEXT_NO_NEGATE_Y EQU $41E9
ABS_A_B EQU $F584
RISE_RUN_X EQU $F5FF
VEC_COLD_FLAG EQU $CBFE
MUSICC EQU $FF7A
SLR_FOREGROUND EQU $4365
ULR_GAMEPLAY_COLLISIONS EQU $46C0
Vec_Music_Work EQU $C83F
Draw_Pat_VL_a EQU $F434
Xform_Run EQU $F65D
MUSIC8 EQU $FEF8
INTENSITY_5F EQU $F2A5
INIT_MUSIC_CHK EQU $F687
MUSIC2 EQU $FD1D
DRAW_VLP EQU $F410
Rot_VL EQU $F616
DP_TO_C8 EQU $F1AF
UGFC_GP_ADDR_DONE EQU $47BE
Vec_Joy_1_X EQU $C81B
musicd EQU $FF8F
Init_VIA EQU $F14C
VEC_EXPL_CHANS EQU $C854
Rise_Run_Angle EQU $F593
VEC_MAX_GAMES EQU $C850
UGFC_HORIZ_BOUNCE EQU $481C
RESET0REF_D0 EQU $F34A
Sound_Byte_x EQU $F259
ULR_LAYER_EXIT EQU $46BF
Vec_Expl_Timer EQU $C877
Vec_Joy_2_X EQU $C81D
DSWM_NO_NEGATE_Y EQU $412F
Mov_Draw_VL_a EQU $F3B9
Vec_Button_1_4 EQU $C815
SDCP_W_DRAW EQU $454D
Vec_Music_Wk_6 EQU $C846
Rot_VL_ab EQU $F610
ULR_EXIT EQU $45A7
VEC_TEXT_HEIGHT EQU $C82A
Add_Score_d EQU $F87C
SET_REFRESH EQU $F1A2
Joy_Digital EQU $F1F8
CLEAR_SCORE EQU $F84F
SLR_FG_COUNT EQU $4365
VEC_FREQ_TABLE EQU $C84D
VEC_JOY_MUX EQU $C81F
music1 EQU $FD0D
Moveto_ix_FF EQU $F308
VEC_MUSIC_FLAG EQU $C856
Delay_0 EQU $F579
Init_Music_chk EQU $F687
MOVETO_IX_7F EQU $F30C
Random EQU $F517
Mov_Draw_VL_ab EQU $F3B7
VEC_RFRSH_HI EQU $C83E
SLR_INTENSITY_READ EQU $43AA
Obj_Hit EQU $F8FF
Strip_Zeros EQU $F8B7
SLR_OBJ_NEXT EQU $4479
VEC_MUSIC_WK_7 EQU $C845
Print_Ships EQU $F393
UGPC_COLLISION EQU $4772
MOVE_MEM_A_1 EQU $F67F
JOY_DIGITAL EQU $F1F8
CLEAR_X_B_80 EQU $F550
XFORM_RISE EQU $F663
Vec_Button_2_3 EQU $C818
Mov_Draw_VLcs EQU $F3B5
DRAW_VLCS EQU $F3D6
CLEAR_X_B_A EQU $F552
VEC_MUSIC_CHAN EQU $C855
ROT_VL_AB EQU $F610
UGPC_NEXT_INNER EQU $4782
DVB_PATH_LOOP EQU $403F
SLR_GAMEPLAY EQU $4353
Obj_Will_Hit EQU $F8F3
VEC_MUSIC_TWANG EQU $C858
Vec_Music_Wk_5 EQU $C847
VEC_COUNTERS EQU $C82E
Dot_ix_b EQU $F2BE
DELAY_3 EQU $F56D
Init_Music_Buf EQU $F533
DRAW_PAT_VL EQU $F437
INTENSITY_3F EQU $F2A1
Init_OS_RAM EQU $F164
Vec_Expl_Flag EQU $C867
Dec_3_Counters EQU $F55A
music5 EQU $FE38
Print_Str EQU $F495
READ_BTNS EQU $F1BA
OBJ_HIT EQU $F8FF
Draw_VL EQU $F3DD
CLEAR_X_D EQU $F548
DSWM_NEXT_NO_NEGATE_X EQU $41F6
Print_Str_hwyx EQU $F373
Get_Rise_Run EQU $F5EF
MOV_DRAW_VLCS EQU $F3B5
VEC_BUTTON_2_2 EQU $C817
DELAY_0 EQU $F579
Delay_b EQU $F57A
VEC_TWANG_TABLE EQU $C851
ULR_Y_NOT_MIN EQU $460E
RISE_RUN_ANGLE EQU $F593
VEC_HIGH_SCORE EQU $CBEB
Rot_VL_Mode_a EQU $F61F
VEC_EXPL_TIMER EQU $C877
NEW_HIGH_SCORE EQU $F8D8
UGFC_PUSH_DOWN EQU $485D
UGPC_NEXT_OUTER EQU $4788
VEC_JOY_MUX_2_Y EQU $C822
DRAW_GRID_VL EQU $FF9F
SOUND_BYTE EQU $F256
VEC_JOY_1_Y EQU $C81C
ULR_Y_MAX_CHECK EQU $468B
Draw_VLp_7F EQU $F408
VEC_TEXT_HW EQU $C82A
Draw_Grid_VL EQU $FF9F
Draw_VL_ab EQU $F3D8
Recalibrate EQU $F2E6
Vec_SWI3_Vector EQU $CBF2
SOUND_BYTES_X EQU $F284
Get_Run_Idx EQU $F5DB
UGPC_SKIP_INNER_MUL EQU $470D
RESET0INT EQU $F36B
Intensity_3F EQU $F2A1
Vec_Joy_Resltn EQU $C81A
MUSIC6 EQU $FE76
VEC_SWI3_VECTOR EQU $CBF2
MOVETO_IX_FF EQU $F308
VECTREX_PRINT_TEXT EQU $408F
DSWM_NO_NEGATE_DX EQU $41B1
JOY_ANALOG EQU $F1F5
RANDOM EQU $F517
Vec_Num_Players EQU $C879
BITMASK_A EQU $F57E
DRAW_SYNC_LIST_AT_WITH_MIRRORS EQU $4113
VEC_EXPL_CHAN EQU $C85C
Vec_FIRQ_Vector EQU $CBF5
SDCP_CLIP EQU $455C
ASSET_BANK_TABLE EQU $4006
Vec_Misc_Count EQU $C823
Moveto_ix EQU $F310
MOVETO_D EQU $F312
RANDOM_3 EQU $F511
VEC_EXPL_2 EQU $C859
DOT_IX EQU $F2C1
VEC_NUM_PLAYERS EQU $C879
VEC_EXPL_1 EQU $C858
DSWM_NEXT_PATH EQU $41D7
Clear_Sound EQU $F272
SLR_GP_COUNT EQU $4353
RISE_RUN_LEN EQU $F603
DP_TO_D0 EQU $F1AA
Vec_Joy_2_Y EQU $C81E
DP_to_C8 EQU $F1AF
DRAW_VL_A EQU $F3DA
Vec_Expl_2 EQU $C859
Rise_Run_Y EQU $F601
MOD16.M16_END EQU $4103
VEC_SEED_PTR EQU $C87B
Vec_Buttons EQU $C811
VEC_JOY_2_Y EQU $C81E
VEC_EXPL_FLAG EQU $C867
VEC_BUTTON_2_1 EQU $C816
INIT_MUSIC_X EQU $F692
ULR_VY_OK EQU $45DD
LOAD_LEVEL_BANKED EQU $405B
Vec_Button_1_3 EQU $C814
MUSICB EQU $FF62
UGPC_INNER_MUL EQU $4706
DP_to_D0 EQU $F1AA
SDCP_MOVETO_W EQU $450B
MOD16.M16_LOOP EQU $40F3
Vec_Seed_Ptr EQU $C87B
VEC_MUSIC_WK_6 EQU $C846
Vec_Default_Stk EQU $CBEA
VEC_COUNTER_2 EQU $C82F
VEC_JOY_2_X EQU $C81D
MUSIC3 EQU $FD81
New_High_Score EQU $F8D8
VEC_PATTERN EQU $C829
MUSICA EQU $FF44
MUSIC9 EQU $FF26
PRINT_LIST_CHK EQU $F38C
MOD16.M16_DONE EQU $4112
Draw_Sync_List_At_With_Mirrors EQU $4113
MOVETO_X_7F EQU $F2F2
VEC_TEXT_WIDTH EQU $C82B
PRINT_STR EQU $F495
MUSICD EQU $FF8F
DELAY_1 EQU $F575
RISE_RUN_Y EQU $F601
DRAW_PAT_VL_A EQU $F434
LLR_SKIP_GP EQU $42C3
Vec_Joy_1_Y EQU $C81C
Dot_ix EQU $F2C1
SLR_RAM_VISIBLE EQU $43F3
VEC_0REF_ENABLE EQU $C824
Xform_Run_a EQU $F65B
Vec_Expl_Chan EQU $C85C
Get_Rise_Idx EQU $F5D9
Delay_2 EQU $F571
Dot_here EQU $F2C5
Vec_Counter_2 EQU $C82F
VEC_RUN_INDEX EQU $C837
Reset0Ref_D0 EQU $F34A
PRINT_SHIPS_X EQU $F391
PRINT_LIST_HW EQU $F385
Vec_Angle EQU $C836
MOVETO_D_7F EQU $F2FC
MOVETO_IX EQU $F310
DSWM_W1 EQU $4186
VEC_BUTTON_1_3 EQU $C814
VEC_SWI_VECTOR EQU $CBFB
PRINT_TEXT_STR_2344190015343208 EQU $487E
LOAD_LEVEL_RUNTIME EQU $4266
Move_Mem_a EQU $F683
SOUND_BYTES EQU $F27D
OBJ_WILL_HIT EQU $F8F3
Intensity_5F EQU $F2A5
Vec_Expl_Chans EQU $C854
Vec_Button_2_4 EQU $C819
Vec_Text_Width EQU $C82B
Delay_1 EQU $F575
VEC_MAX_PLAYERS EQU $C84F
VEC_SND_SHADOW EQU $C800
Add_Score_a EQU $F85E
Clear_C8_RAM EQU $F542
VEC_JOY_MUX_2_X EQU $C821
Abs_a_b EQU $F584
SDCP_USE_OVERRIDE EQU $4492
Draw_Pat_VL EQU $F437
music9 EQU $FF26
INIT_OS EQU $F18B
Vec_Loop_Count EQU $C825
SLR_PATH_DONE EQU $4477
Vec_Joy_Mux_1_X EQU $C81F
Xform_Rise_a EQU $F661
Vec_RiseRun_Len EQU $C83B
SHOW_LEVEL_RUNTIME EQU $4313
DSWM_DONE EQU $4265
Vec_Text_HW EQU $C82A
Vec_Rfrsh EQU $C83D
Vec_ADSR_Timers EQU $C85E
Moveto_d EQU $F312
VEC_BUTTON_2_3 EQU $C818
DO_SOUND_X EQU $F28C
VEC_JOY_RESLTN EQU $C81A
Vec_Music_Freq EQU $C861
LEVEL_BANK_TABLE EQU $4003
VEC_BUTTON_1_2 EQU $C813
UGPC_OUTER_LOOP EQU $46D1
Vec_Duration EQU $C857
Draw_VLp_scale EQU $F40C
SLR_OBJ_LOOP EQU $4386
Vec_0Ref_Enable EQU $C824
DSWM_LOOP EQU $418F
GET_RISE_RUN EQU $F5EF
DEC_COUNTERS EQU $F563
Vec_Counter_6 EQU $C833
INIT_VIA EQU $F14C
VECTOR_BANK_TABLE EQU $4000
ROT_VL_MODE_A EQU $F61F
DSWM_NEXT_SET_INTENSITY EQU $41DD
UPDATE_LEVEL_RUNTIME EQU $4583
INTENSITY_1F EQU $F29D
VEC_COUNTER_3 EQU $C830
Vec_Music_Ptr EQU $C853
UGPC_INNER_LOOP EQU $46F1
SLR_DRAW_CLIPPED_PATH EQU $4486
Wait_Recal EQU $F192
Vec_Str_Ptr EQU $C82C
Vec_Expl_1 EQU $C858
Vec_Music_Twang EQU $C858
VEC_DURATION EQU $C857
Vec_Text_Height EQU $C82A
UGFC_VX_ABS EQU $4815
COLD_START EQU $F000
SDCP_ABS_OK EQU $44BF
VEC_ADSR_TIMERS EQU $C85E
OBJ_WILL_HIT_U EQU $F8E5
SELECT_GAME EQU $F7A9
UGFC_VERT_BOUNCE EQU $4841
Mov_Draw_VL_b EQU $F3B1
Vec_Counter_1 EQU $C82E
PRINT_TEXT_STR_110251488 EQU $4878
Delay_RTS EQU $F57D
Draw_VL_b EQU $F3D2
Vec_Twang_Table EQU $C851
WARM_START EQU $F06C
CHECK0REF EQU $F34F
Obj_Will_Hit_u EQU $F8E5
Print_Str_d EQU $F37A
UGFC_DY_POS EQU $47EF
MOVETO_IX_A EQU $F30E
VEC_MUSIC_WK_5 EQU $C847
VEC_EXPL_CHANA EQU $C853
VEC_MUSIC_FREQ EQU $C861
ULR_Y_BOUNDS EQU $4666
VEC_DEFAULT_STK EQU $CBEA
VEC_RISERUN_TMP EQU $C834
VEC_RFRSH_LO EQU $C83D
Print_List_hw EQU $F385
ULR_NO_GRAVITY EQU $45DF
MOV_DRAW_VL_AB EQU $F3B7
VEC_RISERUN_LEN EQU $C83B
Clear_x_b EQU $F53F
DSWM_W2 EQU $41C8
Vec_Max_Games EQU $C850
Vec_Joy_Mux_2_Y EQU $C822
ADD_SCORE_D EQU $F87C
UGPC_DY_POS EQU $475C
ABS_B EQU $F58B
UGPC_OUTER_MUL EQU $46DB
VEC_MUSIC_WORK EQU $C83F
Sound_Byte EQU $F256
Do_Sound EQU $F289
musica EQU $FF44
Cold_Start EQU $F000
Init_Music_x EQU $F692
Set_Refresh EQU $F1A2
music2 EQU $FD1D
ASSET_ADDR_TABLE EQU $4008
Rot_VL_dft EQU $F637
UGFC_GP_LOOP EQU $47AD
DEC_6_COUNTERS EQU $F55E
SDCP_CHECK_POS EQU $44BA
DRAW_VL_AB EQU $F3D8
Vec_Joy_Mux EQU $C81F
Vec_SWI_Vector EQU $CBFB
Vec_High_Score EQU $CBEB
MOD16.M16_RPOS EQU $40F3
INTENSITY_7F EQU $F2A9
VEC_BUTTON_1_4 EQU $C815
Move_Mem_a_1 EQU $F67F
DOT_D EQU $F2C3
MUSIC7 EQU $FEC6
UGPC_DX_POS EQU $4737
Select_Game EQU $F7A9
DRAW_VECTOR_BANKED EQU $400C
DELAY_RTS EQU $F57D
Draw_VLc EQU $F3CE
UGFC_DX_POS EQU $47E3
MOVE_MEM_A EQU $F683
_PLATFORM_PATH0 EQU $0040
SDCP_W_MOVE EQU $4576
Draw_VLp_FF EQU $F404
Vec_Joy_Mux_2_X EQU $C821
Rise_Run_X EQU $F5FF
MOV_DRAW_VL_B EQU $F3B1
XFORM_RUN EQU $F65D
UGFC_FG_LOOP EQU $47CC
RECALIBRATE EQU $F2E6
UGPC_START EQU $46CA
Draw_Line_d EQU $F3DF
VEC_ADSR_TABLE EQU $C84F
XFORM_RISE_A EQU $F661
ULR_Y_NOT_MAX EQU $4603
MUSIC1 EQU $FD0D
ROT_VL_MODE EQU $F62B
VEC_PREV_BTNS EQU $C810
Init_Music EQU $F68D
Check0Ref EQU $F34F
CLEAR_C8_RAM EQU $F542
Rise_Run_Len EQU $F603
Random_3 EQU $F511
Vec_Music_Wk_A EQU $C842
UGFC_NEXT_GP EQU $486A
Reset0Ref EQU $F354
Vec_Counter_4 EQU $C831
Sound_Bytes EQU $F27D
Vec_RiseRun_Tmp EQU $C834
UGFC_VY_ABS EQU $480B
VEC_BUTTON_2_4 EQU $C819
EXPLOSION_SND EQU $F92E
Vec_Cold_Flag EQU $CBFE
SLR_ROM_OFFSETS EQU $4403
music7 EQU $FEC6
VEC_RANDOM_SEED EQU $C87D
CLEAR_SOUND EQU $F272
CLEAR_X_B EQU $F53F
UGFC_PUSH_LEFT EQU $4838
Joy_Analog EQU $F1F5
Dec_Counters EQU $F563
XFORM_RUN_A EQU $F65B
INIT_MUSIC EQU $F68D
Clear_x_d EQU $F548
Moveto_ix_7F EQU $F30C
MUSIC4 EQU $FDD3
LLR_COPY_OBJECTS EQU $42CB
Read_Btns EQU $F1BA
RESET0REF EQU $F354
VEC_JOY_1_X EQU $C81B
VEC_COUNTER_4 EQU $C831
MOV_DRAW_VLC_A EQU $F3AD
UGFC_EXIT EQU $4877
Vec_ADSR_Table EQU $C84F
SLR_OBJ_DONE EQU $4483
UGPC_EXIT EQU $4798
LLR_CLR_GP_LOOP EQU $42A4
Vec_Max_Players EQU $C84F
PRINT_LIST EQU $F38A
GET_RUN_IDX EQU $F5DB
Bitmask_a EQU $F57E
Draw_Pat_VL_d EQU $F439
DELAY_2 EQU $F571
DRAW_VLP_B EQU $F40E
Vec_Expl_ChanB EQU $C85D
Do_Sound_x EQU $F28C
MOD16 EQU $40BF
DSWM_SET_INTENSITY EQU $4115
SLR_RAM_A_ZERO EQU $43EB
Vec_IRQ_Vector EQU $CBF8
DRAW_VLP_7F EQU $F408
Init_OS EQU $F18B
DRAW_VL_B EQU $F3D2
DOT_HERE EQU $F2C5
ULR_LOOP EQU $45BC
Rot_VL_Mode EQU $F62B
Moveto_x_7F EQU $F2F2


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "VPLAYTST"
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
    LDA #$F8
    STA TEXT_SCALE_H      ; Default height = -8 (normal size)
    LDA #$48
    STA TEXT_SCALE_W      ; Default width = 72 (normal size)
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
    ; Load level: 'test2'
    ; Level asset index: 0 (multibank)
    LDX #0
    JSR LOAD_LEVEL_BANKED

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    ; PRINT_TEXT: Print text at position
    LDD #-55
    STD VAR_ARG0
    LDD #120
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2344190015343208      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; ===== UPDATE_LEVEL builtin =====
    JSR UPDATE_LEVEL_RUNTIME
    LDD #0
    STD RESULT
    ; ===== SHOW_LEVEL builtin =====
    JSR SHOW_LEVEL_RUNTIME
    LDD #0
    STD RESULT
    RTS


; ================================================
