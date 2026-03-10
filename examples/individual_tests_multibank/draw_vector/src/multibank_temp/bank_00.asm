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
TEXT_SCALE_H         EQU $C880+$38   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$39   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
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
VEC_FREQ_TABLE EQU $C84D
Vec_High_Score EQU $CBEB
Vec_Counter_2 EQU $C82F
VEC_DEFAULT_STK EQU $CBEA
Dot_ix EQU $F2C1
Intensity_a EQU $F2AB
Warm_Start EQU $F06C
Rot_VL EQU $F616
JOY_ANALOG EQU $F1F5
Abs_b EQU $F58B
Draw_VL_a EQU $F3DA
Vec_Run_Index EQU $C837
Vec_IRQ_Vector EQU $CBF8
VEC_STR_PTR EQU $C82C
DRAW_VL_AB EQU $F3D8
Draw_Grid_VL EQU $FF9F
Vec_NMI_Vector EQU $CBFB
Vec_Counter_6 EQU $C833
VEC_COLD_FLAG EQU $CBFE
DRAW_VLP_B EQU $F40E
musicb EQU $FF62
EXPLOSION_SND EQU $F92E
WAIT_RECAL EQU $F192
VEC_MUSIC_WK_6 EQU $C846
Vec_Pattern EQU $C829
Moveto_x_7F EQU $F2F2
Vec_Angle EQU $C836
VEC_MUSIC_WK_1 EQU $C84B
Init_VIA EQU $F14C
DSWM_NO_NEGATE_DY EQU $416D
VEC_JOY_2_X EQU $C81D
Vec_Music_Flag EQU $C856
VEC_EXPL_CHANA EQU $C853
RESET0INT EQU $F36B
VEC_COUNTERS EQU $C82E
CHECK0REF EQU $F34F
Vec_Expl_ChanB EQU $C85D
Vec_Joy_Mux_2_Y EQU $C822
NEW_HIGH_SCORE EQU $F8D8
DRAW_VL_MODE EQU $F46E
Rot_VL_Mode_a EQU $F61F
MUSIC3 EQU $FD81
music7 EQU $FEC6
Vec_Button_2_4 EQU $C819
VEC_MUSIC_WK_7 EQU $C845
VEC_BUTTON_1_2 EQU $C813
MOVETO_IX_FF EQU $F308
Reset_Pen EQU $F35B
OBJ_WILL_HIT_U EQU $F8E5
Vec_ADSR_Table EQU $C84F
VEC_SND_SHADOW EQU $C800
INIT_MUSIC EQU $F68D
Clear_x_b_80 EQU $F550
DSWM_NEXT_PATH EQU $419D
BITMASK_A EQU $F57E
ADD_SCORE_D EQU $F87C
Sound_Byte EQU $F256
MUSICD EQU $FF8F
VECTOR_BANK_TABLE EQU $4000
MUSICC EQU $FF7A
Reset0Int EQU $F36B
RECALIBRATE EQU $F2E6
VEC_JOY_MUX_1_X EQU $C81F
DP_TO_D0 EQU $F1AA
Obj_Hit EQU $F8FF
COLD_START EQU $F000
Vec_Num_Players EQU $C879
PRINT_LIST_CHK EQU $F38C
Intensity_3F EQU $F2A1
VEC_FIRQ_VECTOR EQU $CBF5
PRINT_STR_HWYX EQU $F373
Delay_2 EQU $F571
Intensity_7F EQU $F2A9
Dec_6_Counters EQU $F55E
Get_Rise_Idx EQU $F5D9
VEC_RUN_INDEX EQU $C837
OBJ_WILL_HIT EQU $F8F3
DP_to_C8 EQU $F1AF
RISE_RUN_X EQU $F5FF
VEC_NMI_VECTOR EQU $CBFB
DEC_6_COUNTERS EQU $F55E
INIT_OS EQU $F18B
VEC_DURATION EQU $C857
Vec_Expl_3 EQU $C85A
VEC_COUNTER_1 EQU $C82E
VEC_PATTERN EQU $C829
DOT_IX EQU $F2C1
Vec_SWI2_Vector EQU $CBF2
_VEC_VECTORS EQU $0000
music2 EQU $FD1D
Print_Ships_x EQU $F391
PRINT_STR EQU $F495
Vec_Counter_3 EQU $C830
VEC_JOY_MUX_1_Y EQU $C820
VEC_RANDOM_SEED EQU $C87D
Vec_Button_1_4 EQU $C815
Intensity_1F EQU $F29D
XFORM_RISE EQU $F663
MUSIC9 EQU $FF26
COMPARE_SCORE EQU $F8C7
Print_List_chk EQU $F38C
Draw_VLp_b EQU $F40E
MOVETO_D EQU $F312
Bitmask_a EQU $F57E
VEC_JOY_1_Y EQU $C81C
Clear_x_b_a EQU $F552
Draw_VL_ab EQU $F3D8
RANDOM_3 EQU $F511
MOVETO_IX EQU $F310
Vec_Music_Twang EQU $C858
Init_Music_x EQU $F692
Moveto_ix_FF EQU $F308
STRIP_ZEROS EQU $F8B7
VEC_0REF_ENABLE EQU $C824
VEC_SWI3_VECTOR EQU $CBF2
MOV_DRAW_VL_D EQU $F3BE
SELECT_GAME EQU $F7A9
VEC_ADSR_TIMERS EQU $C85E
READ_BTNS_MASK EQU $F1B4
Vec_Freq_Table EQU $C84D
VEC_EXPL_1 EQU $C858
MOVETO_IX_A EQU $F30E
MOVE_MEM_A_1 EQU $F67F
Draw_VLp_FF EQU $F404
Compare_Score EQU $F8C7
Vec_Rise_Index EQU $C839
VEC_SEED_PTR EQU $C87B
Set_Refresh EQU $F1A2
Vec_Max_Players EQU $C84F
DSWM_NO_NEGATE_Y EQU $40F5
VEC_MUSIC_WK_A EQU $C842
VEC_HIGH_SCORE EQU $CBEB
VEC_NUM_PLAYERS EQU $C879
Moveto_d EQU $F312
Obj_Will_Hit EQU $F8F3
VEC_JOY_MUX_2_X EQU $C821
Vec_Loop_Count EQU $C825
Vec_Random_Seed EQU $C87D
Vec_Joy_2_X EQU $C81D
Vec_RiseRun_Len EQU $C83B
Vec_Expl_Timer EQU $C877
DRAW_VLP_SCALE EQU $F40C
Vec_Button_1_2 EQU $C813
Sound_Bytes EQU $F27D
Dot_here EQU $F2C5
MOVETO_IX_7F EQU $F30C
Delay_b EQU $F57A
DSWM_LOOP EQU $4155
music6 EQU $FE76
VEC_COUNTER_2 EQU $C82F
DOT_IX_B EQU $F2BE
DELAY_0 EQU $F579
Vec_Expl_1 EQU $C858
Do_Sound_x EQU $F28C
Draw_Pat_VL_d EQU $F439
Rise_Run_Len EQU $F603
MOD16.M16_LOOP EQU $40B9
Delay_1 EQU $F575
DO_SOUND_X EQU $F28C
DSWM_NEXT_NO_NEGATE_X EQU $41BC
CLEAR_X_B EQU $F53F
VEC_RISERUN_LEN EQU $C83B
DSWM_W2 EQU $418E
MOD16.M16_DPOS EQU $40A2
DRAW_VL_B EQU $F3D2
Vec_FIRQ_Vector EQU $CBF5
MOVE_MEM_A EQU $F683
Vec_Misc_Count EQU $C823
DSWM_NO_NEGATE_X EQU $4102
Xform_Run EQU $F65D
DRAW_LINE_D EQU $F3DF
Delay_RTS EQU $F57D
Vec_Music_Work EQU $C83F
VEC_RFRSH_HI EQU $C83E
VEC_TEXT_WIDTH EQU $C82B
VEC_ANGLE EQU $C836
PRINT_SHIPS EQU $F393
Vec_Expl_Chan EQU $C85C
Vec_Dot_Dwell EQU $C828
Vec_Expl_Chans EQU $C854
DSWM_DONE EQU $422B
PRINT_STR_D EQU $F37A
Delay_0 EQU $F579
INTENSITY_5F EQU $F2A5
Rise_Run_Angle EQU $F593
Vec_Brightness EQU $C827
VEC_MUSIC_FREQ EQU $C861
Vec_Music_Ptr EQU $C853
Vec_Music_Wk_6 EQU $C846
JOY_DIGITAL EQU $F1F8
MUSIC7 EQU $FEC6
SOUND_BYTE EQU $F256
VEC_EXPL_CHANS EQU $C854
Draw_Pat_VL EQU $F437
Vec_SWI_Vector EQU $CBFB
Recalibrate EQU $F2E6
Draw_VL EQU $F3DD
DRAW_VLC EQU $F3CE
Random EQU $F517
DRAW_VLCS EQU $F3D6
Vec_Default_Stk EQU $CBEA
Moveto_ix EQU $F310
Rise_Run_Y EQU $F601
CLEAR_X_256 EQU $F545
Add_Score_d EQU $F87C
VEC_MUSIC_CHAN EQU $C855
VEC_BUTTON_1_1 EQU $C812
Vec_Button_2_1 EQU $C816
VEC_MUSIC_WK_5 EQU $C847
CLEAR_X_D EQU $F548
ROT_VL_MODE_A EQU $F61F
GET_RISE_IDX EQU $F5D9
Print_Str_yx EQU $F378
music8 EQU $FEF8
ROT_VL_DFT EQU $F637
MOD16.M16_DONE EQU $40D8
ASSET_ADDR_TABLE EQU $4004
Xform_Run_a EQU $F65B
Draw_Line_d EQU $F3DF
Vec_Text_Width EQU $C82B
PRINT_LIST EQU $F38A
Rot_VL_Mode EQU $F62B
RESET0REF_D0 EQU $F34A
Do_Sound EQU $F289
SET_REFRESH EQU $F1A2
VEC_COUNTER_4 EQU $C831
Dec_3_Counters EQU $F55A
DRAW_VLP EQU $F410
VEC_EXPL_4 EQU $C85B
Mov_Draw_VL_d EQU $F3BE
Draw_VL_mode EQU $F46E
Vec_ADSR_Timers EQU $C85E
New_High_Score EQU $F8D8
Clear_x_256 EQU $F545
RESET0REF EQU $F354
GET_RISE_RUN EQU $F5EF
Rise_Run_X EQU $F5FF
DOT_HERE EQU $F2C5
DVB_PATH_LOOP EQU $4039
Intensity_5F EQU $F2A5
Clear_x_d EQU $F548
Mov_Draw_VL_a EQU $F3B9
MOV_DRAW_VLCS EQU $F3B5
VEC_COUNTER_6 EQU $C833
VEC_LOOP_COUNT EQU $C825
VEC_MISC_COUNT EQU $C823
Vec_Joy_Mux EQU $C81F
Draw_VLp EQU $F410
MOD16 EQU $4085
Vec_Counter_5 EQU $C832
PRINT_LIST_HW EQU $F385
Moveto_ix_a EQU $F30E
Draw_Pat_VL_a EQU $F434
Get_Rise_Run EQU $F5EF
VEC_DOT_DWELL EQU $C828
Vec_Buttons EQU $C811
Vec_Expl_ChanA EQU $C853
Abs_a_b EQU $F584
Print_Str EQU $F495
Explosion_Snd EQU $F92E
MUSICB EQU $FF62
MOVETO_D_7F EQU $F2FC
Sound_Byte_x EQU $F259
OBJ_HIT EQU $F8FF
PRINT_SHIPS_X EQU $F391
Vec_Button_2_3 EQU $C818
DEC_3_COUNTERS EQU $F55A
READ_BTNS EQU $F1BA
Rot_VL_dft EQU $F637
Vec_Duration EQU $C857
VEC_JOY_MUX EQU $C81F
INIT_MUSIC_BUF EQU $F533
MOD16.M16_RPOS EQU $40B9
Vec_Music_Wk_A EQU $C842
INIT_VIA EQU $F14C
VECTREX_PRINT_TEXT EQU $4055
RISE_RUN_ANGLE EQU $F593
PRINT_TEXT_STR_2223292 EQU $4230
Vec_Button_1_3 EQU $C814
DRAW_VLP_FF EQU $F404
Move_Mem_a EQU $F683
MOD16.M16_RCHECK EQU $40AA
Add_Score_a EQU $F85E
DSWM_SET_INTENSITY EQU $40DB
VEC_TWANG_TABLE EQU $C851
DOT_LIST_RESET EQU $F2DE
Vec_Text_Height EQU $C82A
DP_to_D0 EQU $F1AA
Vec_Music_Chan EQU $C855
Reset0Ref_D0 EQU $F34A
MUSIC2 EQU $FD1D
Sound_Bytes_x EQU $F284
SOUND_BYTE_X EQU $F259
INIT_OS_RAM EQU $F164
Joy_Analog EQU $F1F5
VEC_BUTTON_1_3 EQU $C814
SOUND_BYTE_RAW EQU $F25B
Vec_Max_Games EQU $C850
Vec_Counters EQU $C82E
VEC_BUTTONS EQU $C811
Wait_Recal EQU $F192
Vec_Button_1_1 EQU $C812
MUSIC8 EQU $FEF8
MOV_DRAW_VL_AB EQU $F3B7
music3 EQU $FD81
VEC_JOY_1_X EQU $C81B
VEC_BUTTON_2_1 EQU $C816
MUSIC1 EQU $FD0D
PRINT_STR_YX EQU $F378
Init_OS EQU $F18B
SOUND_BYTES EQU $F27D
Vec_Expl_2 EQU $C859
XFORM_RUN EQU $F65D
Clear_C8_RAM EQU $F542
Vec_Joy_1_Y EQU $C81C
Mov_Draw_VLc_a EQU $F3AD
DOT_LIST EQU $F2D5
Dot_ix_b EQU $F2BE
Strip_Zeros EQU $F8B7
Print_List_hw EQU $F385
Obj_Will_Hit_u EQU $F8E5
Draw_VL_b EQU $F3D2
MOV_DRAW_VLC_A EQU $F3AD
GET_RUN_IDX EQU $F5DB
CLEAR_X_B_80 EQU $F550
Vec_Joy_Mux_1_Y EQU $C820
Vec_Text_HW EQU $C82A
DRAW_VECTOR_BANKED EQU $4006
ROT_VL_AB EQU $F610
music5 EQU $FE38
Vec_Cold_Flag EQU $CBFE
INIT_MUSIC_X EQU $F692
VEC_SWI2_VECTOR EQU $CBF2
Vec_Joy_Mux_2_X EQU $C821
DSWM_NEXT_SET_INTENSITY EQU $41A3
DRAW_VL EQU $F3DD
VEC_JOY_RESLTN EQU $C81A
DO_SOUND EQU $F289
Clear_Sound EQU $F272
Init_OS_RAM EQU $F164
Moveto_ix_7F EQU $F30C
VEC_BUTTON_1_4 EQU $C815
DELAY_B EQU $F57A
Print_Ships EQU $F393
Init_Music EQU $F68D
Vec_Rfrsh_hi EQU $C83E
MOV_DRAW_VL_A EQU $F3B9
ROT_VL EQU $F616
VEC_MAX_PLAYERS EQU $C84F
VEC_COUNTER_5 EQU $C832
ABS_A_B EQU $F584
WARM_START EQU $F06C
ABS_B EQU $F58B
Draw_VLp_7F EQU $F408
Select_Game EQU $F7A9
MUSIC6 EQU $FE76
XFORM_RUN_A EQU $F65B
DSWM_W3 EQU $421F
SOUND_BYTES_X EQU $F284
Delay_3 EQU $F56D
INTENSITY_1F EQU $F29D
Vec_RiseRun_Tmp EQU $C834
Init_Music_chk EQU $F687
Vec_0Ref_Enable EQU $C824
Vec_Snd_Shadow EQU $C800
RANDOM EQU $F517
INTENSITY_3F EQU $F2A1
Mov_Draw_VL_ab EQU $F3B7
VEC_MUSIC_FLAG EQU $C856
Vec_Num_Game EQU $C87A
DP_TO_C8 EQU $F1AF
MOV_DRAW_VL EQU $F3BC
VEC_BUTTON_2_2 EQU $C817
VEC_EXPL_2 EQU $C859
VEC_JOY_MUX_2_Y EQU $C822
Read_Btns EQU $F1BA
Draw_VLcs EQU $F3D6
VEC_RISERUN_TMP EQU $C834
Init_Music_Buf EQU $F533
Draw_Sync_List_At_With_Mirrors EQU $40D9
VEC_MUSIC_TWANG EQU $C858
Vec_Joy_1_X EQU $C81B
Vec_Music_Wk_7 EQU $C845
VEC_JOY_2_Y EQU $C81E
Vec_Rfrsh EQU $C83D
Dot_List EQU $F2D5
musicd EQU $FF8F
DELAY_2 EQU $F571
music9 EQU $FF26
Vec_Str_Ptr EQU $C82C
VEC_ADSR_TABLE EQU $C84F
ASSET_BANK_TABLE EQU $4003
Dot_d EQU $F2C3
DRAW_PAT_VL_A EQU $F434
DRAW_PAT_VL EQU $F437
Vec_Prev_Btns EQU $C810
Print_Str_d EQU $F37A
Clear_Score EQU $F84F
VEC_EXPL_FLAG EQU $C867
Print_List EQU $F38A
Read_Btns_Mask EQU $F1B4
musica EQU $FF44
Check0Ref EQU $F34F
ADD_SCORE_A EQU $F85E
VEC_SWI_VECTOR EQU $CBFB
VEC_MAX_GAMES EQU $C850
Vec_Expl_4 EQU $C85B
DELAY_1 EQU $F575
Draw_VLc EQU $F3CE
VEC_BUTTON_2_4 EQU $C819
_VEC_PATH0 EQU $0003
Xform_Rise EQU $F663
Mov_Draw_VL EQU $F3BC
VEC_EXPL_3 EQU $C85A
VEC_MUSIC_PTR EQU $C853
DRAW_PAT_VL_D EQU $F439
Mov_Draw_VL_b EQU $F3B1
CLEAR_SCORE EQU $F84F
CLEAR_X_B_A EQU $F552
DRAW_VLP_7F EQU $F408
XFORM_RISE_A EQU $F661
Dec_Counters EQU $F563
Moveto_d_7F EQU $F2FC
Vec_Joy_Resltn EQU $C81A
musicc EQU $FF7A
music4 EQU $FDD3
VECTOR_ADDR_TABLE EQU $4001
VEC_RISE_INDEX EQU $C839
Vec_Joy_2_Y EQU $C81E
Dot_List_Reset EQU $F2DE
Rot_VL_ab EQU $F610
VEC_EXPL_TIMER EQU $C877
CLEAR_SOUND EQU $F272
INTENSITY_7F EQU $F2A9
VEC_EXPL_CHANB EQU $C85D
VEC_RFRSH EQU $C83D
Reset0Ref EQU $F354
Clear_x_b EQU $F53F
DSWM_NEXT_NO_NEGATE_Y EQU $41AF
Joy_Digital EQU $F1F8
MOVETO_X_7F EQU $F2F2
Vec_Btn_State EQU $C80F
VEC_NUM_GAME EQU $C87A
PRINT_TEXT_STR_116628 EQU $422C
Cold_Start EQU $F000
RESET_PEN EQU $F35B
Move_Mem_a_1 EQU $F67F
DELAY_3 EQU $F56D
music1 EQU $FD0D
Vec_SWI3_Vector EQU $CBF2
DRAW_SYNC_LIST_AT_WITH_MIRRORS EQU $40D9
VEC_BTN_STATE EQU $C80F
VEC_COUNTER_3 EQU $C830
MUSIC4 EQU $FDD3
DELAY_RTS EQU $F57D
Vec_Rfrsh_lo EQU $C83D
VEC_IRQ_VECTOR EQU $CBF8
VEC_EXPL_CHAN EQU $C85C
DSWM_NO_NEGATE_DX EQU $4177
Vec_Seed_Ptr EQU $C87B
MUSIC5 EQU $FE38
VEC_BUTTON_2_3 EQU $C818
VEC_TEXT_HEIGHT EQU $C82A
ROT_VL_MODE EQU $F62B
Vec_Expl_Flag EQU $C867
DOT_D EQU $F2C3
Print_Str_hwyx EQU $F373
Xform_Rise_a EQU $F661
INTENSITY_A EQU $F2AB
Vec_Counter_1 EQU $C82E
Vec_Joy_Mux_1_X EQU $C81F
RISE_RUN_LEN EQU $F603
MUSICA EQU $FF44
DRAW_GRID_VL EQU $FF9F
Vec_Music_Wk_5 EQU $C847
Mov_Draw_VLcs EQU $F3B5
INIT_MUSIC_CHK EQU $F687
MOD16.M16_END EQU $40C9
MOV_DRAW_VL_B EQU $F3B1
Random_3 EQU $F511
VEC_RFRSH_LO EQU $C83D
VEC_MUSIC_WORK EQU $C83F
VEC_PREV_BTNS EQU $C810
DSWM_W1 EQU $414C
DRAW_VL_A EQU $F3DA
Draw_VLp_scale EQU $F40C
DEC_COUNTERS EQU $F563
Vec_Twang_Table EQU $C851
Vec_Counter_4 EQU $C831
Vec_Music_Wk_1 EQU $C84B
VEC_TEXT_HW EQU $C82A
VEC_BRIGHTNESS EQU $C827
Vec_Button_2_2 EQU $C817
Vec_Music_Freq EQU $C861
Sound_Byte_raw EQU $F25B
DVB_DONE EQU $4049
CLEAR_C8_RAM EQU $F542
RISE_RUN_Y EQU $F601
Get_Run_Idx EQU $F5DB


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "DRAW_VECTOR"
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
TEXT_SCALE_H         EQU $C880+$38   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$39   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
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
    ; TODO: Statement Pass { source_line: 12 }

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: vec (index=0, 1 paths)
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
    LDX #0        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    CLR DRAW_VEC_INTENSITY  ; Reset: next DRAW_VECTOR uses .vec intensities
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #0
    STD VAR_ARG0
    LDD #0
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2223292      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    RTS


; ================================================
