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
DRAW_LINE_ARGS       EQU $C880+$0F   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$19   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$1B   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$1D   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$1E   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$1F   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$21   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$23   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$24   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_BRIGHTNESS       EQU $C880+$25   ; User variable: BRIGHTNESS (2 bytes)
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
Clear_x_d EQU $F548
CHECK0REF EQU $F34F
CLEAR_X_B_A EQU $F552
Draw_Pat_VL_d EQU $F439
Set_Refresh EQU $F1A2
Clear_C8_RAM EQU $F542
Vec_SWI3_Vector EQU $CBF2
MOVETO_IX EQU $F310
Vec_Joy_Mux EQU $C81F
DP_TO_D0 EQU $F1AA
VEC_TEXT_WIDTH EQU $C82B
Vec_RiseRun_Tmp EQU $C834
Delay_3 EQU $F56D
VEC_RFRSH_HI EQU $C83E
Vec_Pattern EQU $C829
music1 EQU $FD0D
Vec_Counter_2 EQU $C82F
ROT_VL_MODE_A EQU $F61F
INTENSITY_3F EQU $F2A1
VEC_JOY_1_X EQU $C81B
Init_OS EQU $F18B
OBJ_HIT EQU $F8FF
Vec_Counter_5 EQU $C832
Vec_Expl_ChanB EQU $C85D
Dot_d EQU $F2C3
Rot_VL_Mode_a EQU $F61F
INTENSITY_A EQU $F2AB
VEC_SWI_VECTOR EQU $CBFB
RESET0INT EQU $F36B
Vec_Rfrsh_hi EQU $C83E
Vec_Button_1_1 EQU $C812
STRIP_ZEROS EQU $F8B7
VEC_COUNTER_6 EQU $C833
INIT_VIA EQU $F14C
Vec_Music_Wk_5 EQU $C847
music9 EQU $FF26
CLEAR_X_D EQU $F548
Intensity_7F EQU $F2A9
VEC_MAX_PLAYERS EQU $C84F
Vec_IRQ_Vector EQU $CBF8
VEC_BUTTON_2_2 EQU $C817
Vec_Joy_Mux_1_X EQU $C81F
Draw_VLc EQU $F3CE
VEC_MUSIC_FREQ EQU $C861
CLEAR_X_B_80 EQU $F550
Get_Run_Idx EQU $F5DB
Vec_Music_Wk_6 EQU $C846
Reset0Int EQU $F36B
DRAW_VLP_7F EQU $F408
Moveto_ix EQU $F310
WARM_START EQU $F06C
DLW_SEG1_DX_NO_CLAMP EQU $40F6
VEC_JOY_2_Y EQU $C81E
Xform_Run_a EQU $F65B
Draw_VL_mode EQU $F46E
Vec_SWI_Vector EQU $CBFB
INIT_MUSIC_X EQU $F692
VEC_MUSIC_CHAN EQU $C855
VEC_JOY_MUX_1_Y EQU $C820
Vec_Num_Game EQU $C87A
Draw_Grid_VL EQU $FF9F
VEC_TEXT_HEIGHT EQU $C82A
Clear_x_b_a EQU $F552
Moveto_ix_a EQU $F30E
VEC_PREV_BTNS EQU $C810
SOUND_BYTES EQU $F27D
Add_Score_a EQU $F85E
Init_Music_Buf EQU $F533
Intensity_5F EQU $F2A5
ABS_B EQU $F58B
Vec_Duration EQU $C857
Vec_Button_1_4 EQU $C815
Delay_RTS EQU $F57D
VEC_EXPL_TIMER EQU $C877
Vec_Cold_Flag EQU $CBFE
Vec_Prev_Btns EQU $C810
MUSIC2 EQU $FD1D
Select_Game EQU $F7A9
VEC_BUTTON_1_4 EQU $C815
VEC_COUNTER_2 EQU $C82F
INIT_MUSIC_BUF EQU $F533
Vec_0Ref_Enable EQU $C824
VEC_TWANG_TABLE EQU $C851
DP_TO_C8 EQU $F1AF
Vec_Joy_Mux_2_Y EQU $C822
DRAW_LINE_D EQU $F3DF
VEC_COUNTER_4 EQU $C831
Print_Str EQU $F495
Vec_Music_Freq EQU $C861
Vec_Buttons EQU $C811
Random_3 EQU $F511
INTENSITY_1F EQU $F29D
PRINT_STR_D EQU $F37A
GET_RISE_RUN EQU $F5EF
VEC_MUSIC_WK_1 EQU $C84B
Draw_VLp_b EQU $F40E
DELAY_1 EQU $F575
Rise_Run_X EQU $F5FF
Moveto_ix_FF EQU $F308
VEC_FIRQ_VECTOR EQU $CBF5
Xform_Run EQU $F65D
musica EQU $FF44
Print_Str_hwyx EQU $F373
DRAW_PAT_VL EQU $F437
Init_Music EQU $F68D
VEC_JOY_RESLTN EQU $C81A
VEC_MUSIC_WORK EQU $C83F
Vec_RiseRun_Len EQU $C83B
Draw_VLp_7F EQU $F408
Vec_Random_Seed EQU $C87D
DRAW_VL_B EQU $F3D2
Vec_Joy_Resltn EQU $C81A
MOV_DRAW_VL_AB EQU $F3B7
RANDOM EQU $F517
DRAW_VL_AB EQU $F3D8
Get_Rise_Run EQU $F5EF
Draw_Pat_VL_a EQU $F434
Vec_Text_Height EQU $C82A
Vec_Expl_4 EQU $C85B
DP_to_D0 EQU $F1AA
musicb EQU $FF62
Clear_x_b EQU $F53F
VEC_NUM_GAME EQU $C87A
VEC_ANGLE EQU $C836
Intensity_a EQU $F2AB
Vec_Str_Ptr EQU $C82C
MOD16.M16_END EQU $4074
DEC_COUNTERS EQU $F563
SOUND_BYTE_RAW EQU $F25B
Vec_Max_Games EQU $C850
Vec_Counter_4 EQU $C831
DLW_SEG1_DY_LO EQU $40C6
VEC_RISERUN_TMP EQU $C834
music6 EQU $FE76
Vec_Loop_Count EQU $C825
VEC_RISERUN_LEN EQU $C83B
Vec_Expl_Chan EQU $C85C
READ_BTNS EQU $F1BA
DOT_IX_B EQU $F2BE
Delay_b EQU $F57A
MOD16 EQU $4030
VEC_NUM_PLAYERS EQU $C879
Vec_Button_2_4 EQU $C819
GET_RISE_IDX EQU $F5D9
DELAY_RTS EQU $F57D
VEC_SND_SHADOW EQU $C800
Mov_Draw_VL_b EQU $F3B1
DLW_SEG2_DX_DONE EQU $4178
Dot_List EQU $F2D5
MUSIC1 EQU $FD0D
Moveto_d_7F EQU $F2FC
BITMASK_A EQU $F57E
PRINT_TEXT_STR_166972285132112481 EQU $4197
Recalibrate EQU $F2E6
VEC_EXPL_1 EQU $C858
PRINT_TEXT_STR_1817025702533201 EQU $418C
MOV_DRAW_VLCS EQU $F3B5
VEC_PATTERN EQU $C829
VEC_DOT_DWELL EQU $C828
Vec_Run_Index EQU $C837
DRAW_VLCS EQU $F3D6
MOD16.M16_DONE EQU $4083
VEC_BRIGHTNESS EQU $C827
DLW_SEG2_DX_CHECK_NEG EQU $4167
Draw_VL EQU $F3DD
Vec_FIRQ_Vector EQU $CBF5
VEC_BUTTON_2_1 EQU $C816
VEC_BUTTON_1_3 EQU $C814
Print_List_hw EQU $F385
SOUND_BYTE EQU $F256
SET_REFRESH EQU $F1A2
RESET0REF EQU $F354
Mov_Draw_VLcs EQU $F3B5
Vec_Button_2_1 EQU $C816
XFORM_RUN EQU $F65D
Dot_ix_b EQU $F2BE
RISE_RUN_ANGLE EQU $F593
DEC_6_COUNTERS EQU $F55E
Init_OS_RAM EQU $F164
Vec_Joy_1_Y EQU $C81C
CLEAR_SOUND EQU $F272
RISE_RUN_X EQU $F5FF
Do_Sound EQU $F289
PRINT_STR_YX EQU $F378
PRINT_LIST EQU $F38A
VEC_SWI2_VECTOR EQU $CBF2
DLW_SEG2_DY_DONE EQU $4153
Dec_Counters EQU $F563
Vec_Music_Chan EQU $C855
DLW_SEG1_DX_READY EQU $40F9
VEC_BTN_STATE EQU $C80F
Vec_Expl_Flag EQU $C867
RESET_PEN EQU $F35B
DRAW_VLP_SCALE EQU $F40C
DLW_NEED_SEG2 EQU $4131
READ_BTNS_MASK EQU $F1B4
VEC_COUNTERS EQU $C82E
Obj_Hit EQU $F8FF
New_High_Score EQU $F8D8
MUSICA EQU $FF44
Print_List EQU $F38A
VEC_BUTTON_2_3 EQU $C818
Vec_ADSR_Timers EQU $C85E
VEC_IRQ_VECTOR EQU $CBF8
PRINT_LIST_CHK EQU $F38C
ROT_VL_AB EQU $F610
Draw_VLp_scale EQU $F40C
COMPARE_SCORE EQU $F8C7
VEC_SEED_PTR EQU $C87B
ROT_VL_MODE EQU $F62B
ADD_SCORE_A EQU $F85E
Dec_3_Counters EQU $F55A
DOT_LIST EQU $F2D5
MUSIC7 EQU $FEC6
Vec_Joy_Mux_2_X EQU $C821
Compare_Score EQU $F8C7
music2 EQU $FD1D
Intensity_1F EQU $F29D
ROT_VL_DFT EQU $F637
INIT_OS EQU $F18B
DRAW_VL EQU $F3DD
Draw_VL_ab EQU $F3D8
INIT_MUSIC EQU $F68D
Add_Score_d EQU $F87C
VECTREX_PRINT_TEXT EQU $4000
Xform_Rise_a EQU $F661
VEC_MAX_GAMES EQU $C850
VEC_MUSIC_TWANG EQU $C858
MOVE_MEM_A_1 EQU $F67F
RESET0REF_D0 EQU $F34A
Joy_Digital EQU $F1F8
Obj_Will_Hit_u EQU $F8E5
Draw_VL_a EQU $F3DA
OBJ_WILL_HIT_U EQU $F8E5
VEC_COUNTER_5 EQU $C832
Print_Ships EQU $F393
Vec_Btn_State EQU $C80F
VEC_JOY_1_Y EQU $C81C
MOVETO_D_7F EQU $F2FC
DLW_SEG1_DY_READY EQU $40D6
Vec_NMI_Vector EQU $CBFB
Vec_Misc_Count EQU $C823
VEC_EXPL_3 EQU $C85A
Vec_Music_Twang EQU $C858
Print_Ships_x EQU $F391
VEC_EXPL_CHAN EQU $C85C
Rot_VL_Mode EQU $F62B
DLW_SEG2_DY_NO_REMAIN EQU $414A
Obj_Will_Hit EQU $F8F3
PRINT_LIST_HW EQU $F385
Strip_Zeros EQU $F8B7
VEC_MUSIC_WK_5 EQU $C847
Init_Music_chk EQU $F687
Vec_Music_Flag EQU $C856
Init_Music_x EQU $F692
Vec_Joy_2_Y EQU $C81E
DOT_D EQU $F2C3
VEC_DURATION EQU $C857
MUSIC3 EQU $FD81
Vec_ADSR_Table EQU $C84F
Cold_Start EQU $F000
Do_Sound_x EQU $F28C
VEC_JOY_MUX_2_X EQU $C821
Wait_Recal EQU $F192
MOVETO_IX_A EQU $F30E
CLEAR_X_256 EQU $F545
Delay_1 EQU $F575
CLEAR_SCORE EQU $F84F
MOV_DRAW_VL_D EQU $F3BE
Vec_Button_1_2 EQU $C813
Mov_Draw_VL_ab EQU $F3B7
DRAW_VLC EQU $F3CE
Xform_Rise EQU $F663
Rot_VL_dft EQU $F637
Vec_Music_Wk_7 EQU $C845
Random EQU $F517
DO_SOUND EQU $F289
MUSIC6 EQU $FE76
RECALIBRATE EQU $F2E6
PRINT_SHIPS EQU $F393
DRAW_VL_A EQU $F3DA
VEC_EXPL_CHANA EQU $C853
SELECT_GAME EQU $F7A9
Print_List_chk EQU $F38C
Vec_Button_1_3 EQU $C814
VEC_FREQ_TABLE EQU $C84D
CLEAR_C8_RAM EQU $F542
Vec_Counters EQU $C82E
VEC_MUSIC_WK_6 EQU $C846
Vec_Seed_Ptr EQU $C87B
musicd EQU $FF8F
MUSIC8 EQU $FEF8
Rise_Run_Y EQU $F601
Read_Btns_Mask EQU $F1B4
DRAW_VLP_B EQU $F40E
MOD16.M16_RCHECK EQU $4055
VEC_EXPL_FLAG EQU $C867
Vec_Music_Work EQU $C83F
Vec_Brightness EQU $C827
MOVETO_X_7F EQU $F2F2
VEC_JOY_MUX EQU $C81F
Sound_Bytes EQU $F27D
music7 EQU $FEC6
Moveto_x_7F EQU $F2F2
MOD16.M16_RPOS EQU $4064
SOUND_BYTES_X EQU $F284
Abs_b EQU $F58B
Vec_Text_Width EQU $C82B
VEC_MUSIC_PTR EQU $C853
Vec_Counter_1 EQU $C82E
Sound_Byte EQU $F256
Vec_Expl_2 EQU $C859
Init_VIA EQU $F14C
Dec_6_Counters EQU $F55E
DP_to_C8 EQU $F1AF
Vec_Dot_Dwell EQU $C828
VEC_STR_PTR EQU $C82C
Vec_Button_2_2 EQU $C817
Clear_Score EQU $F84F
ABS_A_B EQU $F584
VEC_RFRSH_LO EQU $C83D
CLEAR_X_B EQU $F53F
VEC_BUTTON_1_1 EQU $C812
VEC_MISC_COUNT EQU $C823
DELAY_2 EQU $F571
Vec_Expl_Timer EQU $C877
GET_RUN_IDX EQU $F5DB
Vec_Joy_2_X EQU $C81D
DRAW_LINE_WRAPPER EQU $4084
Vec_High_Score EQU $CBEB
Mov_Draw_VL_d EQU $F3BE
NEW_HIGH_SCORE EQU $F8D8
VEC_EXPL_4 EQU $C85B
MOD16.M16_LOOP EQU $4064
music4 EQU $FDD3
MUSIC4 EQU $FDD3
VEC_RUN_INDEX EQU $C837
Clear_x_b_80 EQU $F550
Dot_List_Reset EQU $F2DE
DLW_SEG1_DX_LO EQU $40E9
DRAW_VLP_FF EQU $F404
PRINT_SHIPS_X EQU $F391
music3 EQU $FD81
Joy_Analog EQU $F1F5
DOT_HERE EQU $F2C5
Mov_Draw_VL EQU $F3BC
Rot_VL EQU $F616
Vec_Max_Players EQU $C84F
RISE_RUN_Y EQU $F601
DEC_3_COUNTERS EQU $F55A
MOV_DRAW_VL_B EQU $F3B1
VEC_RANDOM_SEED EQU $C87D
music5 EQU $FE38
Vec_Expl_1 EQU $C858
COLD_START EQU $F000
ROT_VL EQU $F616
VEC_COUNTER_1 EQU $C82E
INTENSITY_5F EQU $F2A5
Vec_Music_Ptr EQU $C853
Read_Btns EQU $F1BA
INIT_MUSIC_CHK EQU $F687
MUSICB EQU $FF62
Draw_Line_d EQU $F3DF
musicc EQU $FF7A
Rot_VL_ab EQU $F610
WAIT_RECAL EQU $F192
Moveto_ix_7F EQU $F30C
EXPLOSION_SND EQU $F92E
DRAW_PAT_VL_D EQU $F439
MOVE_MEM_A EQU $F683
Vec_Rfrsh_lo EQU $C83D
Dot_ix EQU $F2C1
Vec_SWI2_Vector EQU $CBF2
Explosion_Snd EQU $F92E
PRINT_STR EQU $F495
DELAY_0 EQU $F579
VEC_MUSIC_FLAG EQU $C856
Abs_a_b EQU $F584
Vec_Button_2_3 EQU $C818
Intensity_3F EQU $F2A1
OBJ_WILL_HIT EQU $F8F3
Sound_Byte_x EQU $F259
Dot_here EQU $F2C5
Vec_Joy_Mux_1_Y EQU $C820
DLW_SEG2_DX_NO_REMAIN EQU $4175
Draw_VLcs EQU $F3D6
MUSIC9 EQU $FF26
JOY_ANALOG EQU $F1F5
MOVETO_D EQU $F312
Vec_Num_Players EQU $C879
Vec_Expl_3 EQU $C85A
VEC_RFRSH EQU $C83D
Vec_Counter_6 EQU $C833
Get_Rise_Idx EQU $F5D9
MUSIC5 EQU $FE38
MUSICC EQU $FF7A
XFORM_RUN_A EQU $F65B
Draw_VL_b EQU $F3D2
DLW_DONE EQU $4187
Delay_0 EQU $F579
XFORM_RISE EQU $F663
Reset0Ref EQU $F354
ADD_SCORE_D EQU $F87C
MOD16.M16_DPOS EQU $404D
VEC_LOOP_COUNT EQU $C825
DOT_LIST_RESET EQU $F2DE
VEC_DEFAULT_STK EQU $CBEA
Vec_Snd_Shadow EQU $C800
Vec_Angle EQU $C836
DRAW_PAT_VL_A EQU $F434
VEC_RISE_INDEX EQU $C839
Moveto_d EQU $F312
Rise_Run_Angle EQU $F593
MOVETO_IX_7F EQU $F30C
Sound_Byte_raw EQU $F25B
Draw_VLp_FF EQU $F404
Vec_Expl_ChanA EQU $C853
Move_Mem_a_1 EQU $F67F
VEC_BUTTON_1_2 EQU $C813
VEC_NMI_VECTOR EQU $CBFB
DRAW_VL_MODE EQU $F46E
Draw_VLp EQU $F410
MOV_DRAW_VL EQU $F3BC
DLW_SEG1_DY_NO_CLAMP EQU $40D3
DELAY_B EQU $F57A
music8 EQU $FEF8
Reset0Ref_D0 EQU $F34A
Mov_Draw_VLc_a EQU $F3AD
PRINT_STR_HWYX EQU $F373
VEC_JOY_MUX_2_Y EQU $C822
VEC_JOY_2_X EQU $C81D
Vec_Rise_Index EQU $C839
Clear_Sound EQU $F272
MOVETO_IX_FF EQU $F308
Vec_Freq_Table EQU $C84D
MUSICD EQU $FF8F
Vec_Twang_Table EQU $C851
DLW_SEG2_DY_POS EQU $4150
VEC_JOY_MUX_1_X EQU $C81F
Check0Ref EQU $F34F
VEC_ADSR_TIMERS EQU $C85E
Reset_Pen EQU $F35B
DELAY_3 EQU $F56D
Vec_Counter_3 EQU $C830
Vec_Music_Wk_A EQU $C842
VEC_MUSIC_WK_A EQU $C842
SOUND_BYTE_X EQU $F259
Print_Str_d EQU $F37A
VEC_MUSIC_WK_7 EQU $C845
VEC_EXPL_CHANS EQU $C854
INIT_OS_RAM EQU $F164
INTENSITY_7F EQU $F2A9
DRAW_VLP EQU $F410
Vec_Joy_1_X EQU $C81B
VEC_TEXT_HW EQU $C82A
Mov_Draw_VL_a EQU $F3B9
Draw_Pat_VL EQU $F437
VEC_BUTTONS EQU $C811
Vec_Expl_Chans EQU $C854
Vec_Default_Stk EQU $CBEA
VEC_EXPL_CHANB EQU $C85D
Warm_Start EQU $F06C
JOY_DIGITAL EQU $F1F8
Sound_Bytes_x EQU $F284
Bitmask_a EQU $F57E
XFORM_RISE_A EQU $F661
Move_Mem_a EQU $F683
VEC_ADSR_TABLE EQU $C84F
RANDOM_3 EQU $F511
DO_SOUND_X EQU $F28C
MOV_DRAW_VL_A EQU $F3B9
VEC_COLD_FLAG EQU $CBFE
VEC_EXPL_2 EQU $C859
VEC_SWI3_VECTOR EQU $CBF2
Vec_Text_HW EQU $C82A
MOV_DRAW_VLC_A EQU $F3AD
RISE_RUN_LEN EQU $F603
Vec_Music_Wk_1 EQU $C84B
Rise_Run_Len EQU $F603
Print_Str_yx EQU $F378
Vec_Rfrsh EQU $C83D
DOT_IX EQU $F2C1
VEC_0REF_ENABLE EQU $C824
DRAW_GRID_VL EQU $FF9F
VEC_BUTTON_2_4 EQU $C819
Clear_x_256 EQU $F545
Delay_2 EQU $F571
VEC_HIGH_SCORE EQU $CBEB
VEC_COUNTER_3 EQU $C830


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "FADE"
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
DRAW_LINE_ARGS       EQU $C880+$0F   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$19   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$1B   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$1D   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$1E   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$1F   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$21   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$23   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$24   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_BRIGHTNESS       EQU $C880+$25   ; User variable: BRIGHTNESS (2 bytes)
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
    LDD #100
    STD VAR_BRIGHTNESS
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
    LDD #100
    STD VAR_BRIGHTNESS

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD VAR_ARG0
    LDD #90
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_1817025702533201      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-80
    STD VAR_ARG0
    LDD #70
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_166972285132112481      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed
    BITA #$01
    LBNE .J1B1_0_ON
    LDD #0
    LBRA .J1B1_0_END
.J1B1_0_ON:
    LDD #1
.J1B1_0_END:
    STD RESULT
    LBEQ IF_NEXT_1
    LDD #5
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BRIGHTNESS
    CMPD TMPVAL
    LBGT .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_3
    LDD >VAR_BRIGHTNESS
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #5
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_BRIGHTNESS
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    LDA >$C80F   ; Vec_Btns_1: bit1=1 means btn2 pressed
    BITA #$02
    LBNE .J1B2_1_ON
    LDD #0
    LBRA .J1B2_1_END
.J1B2_1_ON:
    LDD #1
.J1B2_1_END:
    STD RESULT
    LBEQ IF_NEXT_5
    LDD #120
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BRIGHTNESS
    CMPD TMPVAL
    LBLT .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    LBEQ IF_NEXT_7
    LDD >VAR_BRIGHTNESS
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #5
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_BRIGHTNESS
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #-40
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #-40
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #40
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #-40
    STD DRAW_LINE_ARGS+6    ; y1
    LDD >VAR_BRIGHTNESS
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #40
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #-40
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #40
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #40
    STD DRAW_LINE_ARGS+6    ; y1
    LDD >VAR_BRIGHTNESS
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #40
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #40
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #-40
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #40
    STD DRAW_LINE_ARGS+6    ; y1
    LDD >VAR_BRIGHTNESS
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #-40
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #40
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #-40
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #-40
    STD DRAW_LINE_ARGS+6    ; y1
    LDD >VAR_BRIGHTNESS
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #-40
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #-40
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #40
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #40
    STD DRAW_LINE_ARGS+6    ; y1
    LDD >VAR_BRIGHTNESS
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #40
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #-40
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #-40
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #40
    STD DRAW_LINE_ARGS+6    ; y1
    LDD >VAR_BRIGHTNESS
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    RTS


; ================================================
