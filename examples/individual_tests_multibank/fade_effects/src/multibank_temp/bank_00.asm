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
DRAW_LINE_ARGS       EQU $C880+$0E   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$18   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$1A   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$1C   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$1D   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$1E   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$20   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$22   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$23   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_BRIGHTNESS       EQU $C880+$24   ; User variable: brightness (2 bytes)
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
Sound_Byte_x EQU $F259
Random_3 EQU $F511
VEC_COUNTER_2 EQU $C82F
Vec_Counter_3 EQU $C830
Rot_VL EQU $F616
DELAY_RTS EQU $F57D
EXPLOSION_SND EQU $F92E
VEC_BUTTON_1_4 EQU $C815
VEC_SWI_VECTOR EQU $CBFB
Vec_Default_Stk EQU $CBEA
Move_Mem_a_1 EQU $F67F
READ_BTNS_MASK EQU $F1B4
Wait_Recal EQU $F192
Init_OS EQU $F18B
INTENSITY_5F EQU $F2A5
VEC_JOY_MUX_2_X EQU $C821
MUSIC3 EQU $FD81
Vec_Button_1_1 EQU $C812
VEC_COUNTERS EQU $C82E
Vec_Pattern EQU $C829
INIT_MUSIC_X EQU $F692
MUSICC EQU $FF7A
VEC_MUSIC_TWANG EQU $C858
Vec_Expl_1 EQU $C858
Sound_Bytes_x EQU $F284
Init_Music_chk EQU $F687
DEC_6_COUNTERS EQU $F55E
VEC_EXPL_CHANB EQU $C85D
Get_Rise_Idx EQU $F5D9
Draw_VLp_b EQU $F40E
VEC_MUSIC_WK_1 EQU $C84B
DELAY_0 EQU $F579
VEC_TWANG_TABLE EQU $C851
VEC_JOY_MUX EQU $C81F
music2 EQU $FD1D
VEC_ANGLE EQU $C836
Vec_Joy_1_Y EQU $C81C
Sound_Byte_raw EQU $F25B
MOD16.M16_RPOS EQU $4064
DRAW_VL_AB EQU $F3D8
CLEAR_SCORE EQU $F84F
DELAY_3 EQU $F56D
Vec_Duration EQU $C857
MOV_DRAW_VL_B EQU $F3B1
MOD16.M16_LOOP EQU $4064
DRAW_VL EQU $F3DD
Obj_Hit EQU $F8FF
Dot_ix_b EQU $F2BE
SOUND_BYTES_X EQU $F284
Vec_Joy_1_X EQU $C81B
Vec_RiseRun_Tmp EQU $C834
Vec_Joy_Mux_1_Y EQU $C820
MOVETO_IX EQU $F310
MOVETO_D_7F EQU $F2FC
Vec_Text_HW EQU $C82A
Print_Str EQU $F495
DRAW_LINE_D EQU $F3DF
Dot_List EQU $F2D5
VEC_JOY_2_Y EQU $C81E
Clear_x_b_80 EQU $F550
DOT_IX EQU $F2C1
Mov_Draw_VL_b EQU $F3B1
Warm_Start EQU $F06C
Vec_Seed_Ptr EQU $C87B
Read_Btns_Mask EQU $F1B4
Draw_VL_b EQU $F3D2
CLEAR_C8_RAM EQU $F542
VEC_RFRSH_HI EQU $C83E
DLW_NEED_SEG2 EQU $4131
MUSICB EQU $FF62
VEC_RISERUN_LEN EQU $C83B
Vec_Button_1_2 EQU $C813
RESET0INT EQU $F36B
VEC_RISE_INDEX EQU $C839
STRIP_ZEROS EQU $F8B7
INIT_VIA EQU $F14C
Draw_VLp_FF EQU $F404
Delay_b EQU $F57A
VEC_MUSIC_WORK EQU $C83F
Vec_Rise_Index EQU $C839
MOVETO_X_7F EQU $F2F2
COLD_START EQU $F000
ABS_A_B EQU $F584
VEC_HIGH_SCORE EQU $CBEB
ADD_SCORE_D EQU $F87C
DOT_LIST EQU $F2D5
Vec_Text_Width EQU $C82B
Mov_Draw_VL_ab EQU $F3B7
BITMASK_A EQU $F57E
DEC_COUNTERS EQU $F563
VEC_EXPL_3 EQU $C85A
DRAW_VLP_7F EQU $F408
RISE_RUN_X EQU $F5FF
VEC_JOY_2_X EQU $C81D
Vec_Joy_Mux_1_X EQU $C81F
RECALIBRATE EQU $F2E6
DP_TO_D0 EQU $F1AA
music3 EQU $FD81
Vec_Music_Twang EQU $C858
music5 EQU $FE38
VEC_STR_PTR EQU $C82C
VEC_BTN_STATE EQU $C80F
PRINT_LIST EQU $F38A
Vec_FIRQ_Vector EQU $CBF5
Delay_2 EQU $F571
Recalibrate EQU $F2E6
Vec_Text_Height EQU $C82A
OBJ_WILL_HIT EQU $F8F3
Sound_Bytes EQU $F27D
VEC_JOY_MUX_1_X EQU $C81F
OBJ_HIT EQU $F8FF
VEC_BUTTONS EQU $C811
Vec_Button_1_3 EQU $C814
DOT_IX_B EQU $F2BE
Do_Sound_x EQU $F28C
Reset_Pen EQU $F35B
VEC_BUTTON_2_1 EQU $C816
MUSICA EQU $FF44
Vec_Str_Ptr EQU $C82C
Moveto_d_7F EQU $F2FC
Vec_Expl_3 EQU $C85A
CLEAR_X_B_80 EQU $F550
PRINT_STR EQU $F495
RISE_RUN_Y EQU $F601
VEC_FREQ_TABLE EQU $C84D
NEW_HIGH_SCORE EQU $F8D8
Vec_ADSR_Table EQU $C84F
Cold_Start EQU $F000
WAIT_RECAL EQU $F192
VEC_MUSIC_CHAN EQU $C855
CLEAR_X_D EQU $F548
ROT_VL_MODE_A EQU $F61F
DLW_SEG2_DY_DONE EQU $4153
VEC_DURATION EQU $C857
Moveto_d EQU $F312
Vec_Num_Game EQU $C87A
Vec_Counter_2 EQU $C82F
Intensity_1F EQU $F29D
CLEAR_X_B EQU $F53F
VEC_BUTTON_2_4 EQU $C819
VEC_EXPL_CHANA EQU $C853
VEC_TEXT_HW EQU $C82A
Draw_VLc EQU $F3CE
JOY_ANALOG EQU $F1F5
MUSIC5 EQU $FE38
Vec_IRQ_Vector EQU $CBF8
CLEAR_SOUND EQU $F272
MOV_DRAW_VL_A EQU $F3B9
XFORM_RUN EQU $F65D
VEC_EXPL_FLAG EQU $C867
PRINT_TEXT_STR_166972285132112481 EQU $4197
VEC_MUSIC_WK_5 EQU $C847
Print_Ships_x EQU $F391
Intensity_5F EQU $F2A5
OBJ_WILL_HIT_U EQU $F8E5
XFORM_RUN_A EQU $F65B
VEC_ADSR_TABLE EQU $C84F
Clear_C8_RAM EQU $F542
PRINT_STR_YX EQU $F378
Vec_Rfrsh_lo EQU $C83D
Init_OS_RAM EQU $F164
VEC_JOY_MUX_2_Y EQU $C822
Rise_Run_X EQU $F5FF
VEC_RANDOM_SEED EQU $C87D
Vec_Loop_Count EQU $C825
DLW_SEG2_DX_DONE EQU $4178
VEC_MUSIC_FREQ EQU $C861
Vec_Button_2_3 EQU $C818
RESET0REF EQU $F354
ROT_VL_AB EQU $F610
SOUND_BYTE EQU $F256
music1 EQU $FD0D
Moveto_ix_7F EQU $F30C
Obj_Will_Hit EQU $F8F3
Vec_Button_2_2 EQU $C817
VEC_BUTTON_2_2 EQU $C817
VEC_BUTTON_1_2 EQU $C813
Vec_Btn_State EQU $C80F
MOV_DRAW_VL_D EQU $F3BE
Abs_b EQU $F58B
VEC_MISC_COUNT EQU $C823
ADD_SCORE_A EQU $F85E
Mov_Draw_VL_d EQU $F3BE
Draw_VLp_scale EQU $F40C
DLW_SEG1_DX_NO_CLAMP EQU $40F6
Print_Str_yx EQU $F378
DLW_SEG1_DY_NO_CLAMP EQU $40D3
Vec_Music_Ptr EQU $C853
INIT_OS EQU $F18B
Draw_VLcs EQU $F3D6
music8 EQU $FEF8
DLW_SEG2_DX_NO_REMAIN EQU $4175
Add_Score_d EQU $F87C
Draw_VL_ab EQU $F3D8
Print_List_hw EQU $F385
Vec_Music_Wk_A EQU $C842
DEC_3_COUNTERS EQU $F55A
MUSIC7 EQU $FEC6
DRAW_VL_MODE EQU $F46E
VEC_MAX_GAMES EQU $C850
VEC_NMI_VECTOR EQU $CBFB
DP_to_D0 EQU $F1AA
VEC_EXPL_CHAN EQU $C85C
musicb EQU $FF62
VEC_FIRQ_VECTOR EQU $CBF5
Print_Str_hwyx EQU $F373
VEC_TEXT_HEIGHT EQU $C82A
Vec_Counter_4 EQU $C831
Vec_Joy_Mux_2_Y EQU $C822
Vec_Joy_Resltn EQU $C81A
Delay_RTS EQU $F57D
VEC_PATTERN EQU $C829
Mov_Draw_VLcs EQU $F3B5
Print_List EQU $F38A
RANDOM EQU $F517
VEC_COUNTER_3 EQU $C830
Do_Sound EQU $F289
VEC_SWI2_VECTOR EQU $CBF2
DELAY_2 EQU $F571
VEC_RFRSH_LO EQU $C83D
DRAW_VLP_B EQU $F40E
music9 EQU $FF26
Compare_Score EQU $F8C7
Set_Refresh EQU $F1A2
Vec_Max_Players EQU $C84F
VEC_LOOP_COUNT EQU $C825
VEC_TEXT_WIDTH EQU $C82B
VEC_SND_SHADOW EQU $C800
DLW_SEG1_DY_LO EQU $40C6
Reset0Ref_D0 EQU $F34A
DRAW_PAT_VL EQU $F437
DLW_SEG1_DY_READY EQU $40D6
Moveto_ix EQU $F310
Select_Game EQU $F7A9
DRAW_VLP EQU $F410
DRAW_GRID_VL EQU $FF9F
CLEAR_X_256 EQU $F545
VEC_EXPL_2 EQU $C859
ROT_VL EQU $F616
Vec_Button_2_4 EQU $C819
XFORM_RISE EQU $F663
Vec_Random_Seed EQU $C87D
Read_Btns EQU $F1BA
VEC_BUTTON_1_3 EQU $C814
VEC_JOY_RESLTN EQU $C81A
MOD16.M16_DONE EQU $4083
MOD16.M16_RCHECK EQU $4055
Delay_1 EQU $F575
RESET0REF_D0 EQU $F34A
DELAY_B EQU $F57A
VEC_DOT_DWELL EQU $C828
Moveto_ix_FF EQU $F308
Bitmask_a EQU $F57E
PRINT_STR_HWYX EQU $F373
Vec_Angle EQU $C836
Vec_NMI_Vector EQU $CBFB
Vec_SWI2_Vector EQU $CBF2
Reset0Int EQU $F36B
INIT_MUSIC_BUF EQU $F533
VEC_EXPL_CHANS EQU $C854
Vec_Expl_2 EQU $C859
Explosion_Snd EQU $F92E
Vec_Snd_Shadow EQU $C800
MOVETO_IX_7F EQU $F30C
Vec_Misc_Count EQU $C823
Vec_Run_Index EQU $C837
CLEAR_X_B_A EQU $F552
Draw_VLp EQU $F410
INIT_MUSIC EQU $F68D
Vec_0Ref_Enable EQU $C824
VEC_RISERUN_TMP EQU $C834
Vec_Rfrsh_hi EQU $C83E
VEC_JOY_1_Y EQU $C81C
RISE_RUN_LEN EQU $F603
VEC_JOY_MUX_1_Y EQU $C820
Vec_Counters EQU $C82E
Vec_Music_Flag EQU $C856
Obj_Will_Hit_u EQU $F8E5
Get_Run_Idx EQU $F5DB
Moveto_ix_a EQU $F30E
VEC_COLD_FLAG EQU $CBFE
MOVETO_IX_FF EQU $F308
CHECK0REF EQU $F34F
SOUND_BYTE_RAW EQU $F25B
READ_BTNS EQU $F1BA
Dot_List_Reset EQU $F2DE
RESET_PEN EQU $F35B
VEC_DEFAULT_STK EQU $CBEA
Vec_Joy_Mux_2_X EQU $C821
Vec_High_Score EQU $CBEB
INTENSITY_7F EQU $F2A9
VEC_COUNTER_4 EQU $C831
Joy_Analog EQU $F1F5
VEC_COUNTER_1 EQU $C82E
Clear_x_256 EQU $F545
PRINT_SHIPS EQU $F393
DOT_HERE EQU $F2C5
Delay_3 EQU $F56D
Xform_Rise EQU $F663
DP_TO_C8 EQU $F1AF
Vec_Expl_Timer EQU $C877
SELECT_GAME EQU $F7A9
Dec_6_Counters EQU $F55E
musicd EQU $FF8F
Moveto_x_7F EQU $F2F2
Vec_Music_Freq EQU $C861
VEC_BUTTON_1_1 EQU $C812
Init_VIA EQU $F14C
music7 EQU $FEC6
Clear_x_d EQU $F548
Init_Music EQU $F68D
VEC_MUSIC_FLAG EQU $C856
Vec_Expl_4 EQU $C85B
Rot_VL_Mode EQU $F62B
Init_Music_Buf EQU $F533
DELAY_1 EQU $F575
VEC_COUNTER_5 EQU $C832
DRAW_VL_B EQU $F3D2
Print_Ships EQU $F393
Draw_Pat_VL EQU $F437
Vec_Music_Wk_1 EQU $C84B
Clear_x_b EQU $F53F
Dot_d EQU $F2C3
DLW_SEG2_DY_NO_REMAIN EQU $414A
MOV_DRAW_VL EQU $F3BC
MOD16 EQU $4030
Vec_Counter_1 EQU $C82E
musica EQU $FF44
VEC_RUN_INDEX EQU $C837
Rise_Run_Len EQU $F603
VEC_MUSIC_WK_6 EQU $C846
PRINT_LIST_HW EQU $F385
MOVETO_D EQU $F312
Sound_Byte EQU $F256
Clear_Sound EQU $F272
Strip_Zeros EQU $F8B7
PRINT_STR_D EQU $F37A
MUSIC4 EQU $FDD3
MUSIC8 EQU $FEF8
VEC_MUSIC_PTR EQU $C853
Dot_ix EQU $F2C1
Print_List_chk EQU $F38C
DP_to_C8 EQU $F1AF
Vec_ADSR_Timers EQU $C85E
Vec_SWI3_Vector EQU $CBF2
DLW_SEG2_DX_CHECK_NEG EQU $4167
GET_RUN_IDX EQU $F5DB
VEC_SWI3_VECTOR EQU $CBF2
Vec_Prev_Btns EQU $C810
Vec_Expl_ChanA EQU $C853
SET_REFRESH EQU $F1A2
Rot_VL_Mode_a EQU $F61F
Vec_Cold_Flag EQU $CBFE
Intensity_a EQU $F2AB
MUSICD EQU $FF8F
PRINT_SHIPS_X EQU $F391
INTENSITY_1F EQU $F29D
SOUND_BYTE_X EQU $F259
Vec_SWI_Vector EQU $CBFB
Random EQU $F517
Vec_Twang_Table EQU $C851
VEC_NUM_PLAYERS EQU $C879
DLW_SEG1_DX_READY EQU $40F9
VEC_RFRSH EQU $C83D
Vec_Counter_5 EQU $C832
Vec_Expl_Chan EQU $C85C
MOVE_MEM_A EQU $F683
VEC_MUSIC_WK_A EQU $C842
MOVE_MEM_A_1 EQU $F67F
JOY_DIGITAL EQU $F1F8
VEC_ADSR_TIMERS EQU $C85E
DO_SOUND EQU $F289
Draw_VL_mode EQU $F46E
Vec_Button_2_1 EQU $C816
VEC_NUM_GAME EQU $C87A
Mov_Draw_VL_a EQU $F3B9
Vec_Music_Chan EQU $C855
VEC_EXPL_4 EQU $C85B
DRAW_PAT_VL_A EQU $F434
MUSIC2 EQU $FD1D
Xform_Run_a EQU $F65B
RISE_RUN_ANGLE EQU $F593
DOT_LIST_RESET EQU $F2DE
Clear_Score EQU $F84F
Vec_Joy_2_Y EQU $C81E
VEC_EXPL_1 EQU $C858
Clear_x_b_a EQU $F552
Init_Music_x EQU $F692
Vec_Expl_Chans EQU $C854
VEC_COUNTER_6 EQU $C833
WARM_START EQU $F06C
DRAW_PAT_VL_D EQU $F439
VEC_MAX_PLAYERS EQU $C84F
XFORM_RISE_A EQU $F661
Xform_Run EQU $F65D
Rise_Run_Y EQU $F601
Vec_Num_Players EQU $C879
Vec_Button_1_4 EQU $C815
Vec_Music_Work EQU $C83F
Reset0Ref EQU $F354
Draw_Line_d EQU $F3DF
Xform_Rise_a EQU $F661
Joy_Digital EQU $F1F8
SOUND_BYTES EQU $F27D
INIT_MUSIC_CHK EQU $F687
DOT_D EQU $F2C3
Vec_Music_Wk_5 EQU $C847
PRINT_TEXT_STR_1817025702533201 EQU $418C
VEC_BUTTON_2_3 EQU $C818
ROT_VL_DFT EQU $F637
Intensity_3F EQU $F2A1
Draw_Grid_VL EQU $FF9F
Draw_VLp_7F EQU $F408
VEC_0REF_ENABLE EQU $C824
Rot_VL_ab EQU $F610
MOVETO_IX_A EQU $F30E
Get_Rise_Run EQU $F5EF
DRAW_VL_A EQU $F3DA
VEC_SEED_PTR EQU $C87B
DRAW_VLP_FF EQU $F404
MUSIC6 EQU $FE76
MOD16.M16_DPOS EQU $404D
Vec_Buttons EQU $C811
Vec_Freq_Table EQU $C84D
DRAW_VLC EQU $F3CE
VECTREX_PRINT_TEXT EQU $4000
DRAW_LINE_WRAPPER EQU $4084
Dec_3_Counters EQU $F55A
Vec_Max_Games EQU $C850
music6 EQU $FE76
MOV_DRAW_VLCS EQU $F3B5
Vec_RiseRun_Len EQU $C83B
Dot_here EQU $F2C5
Rise_Run_Angle EQU $F593
MUSIC9 EQU $FF26
Draw_Pat_VL_d EQU $F439
MOV_DRAW_VL_AB EQU $F3B7
Add_Score_a EQU $F85E
PRINT_LIST_CHK EQU $F38C
Vec_Rfrsh EQU $C83D
DLW_DONE EQU $4187
ABS_B EQU $F58B
New_High_Score EQU $F8D8
GET_RISE_IDX EQU $F5D9
Draw_VL_a EQU $F3DA
Check0Ref EQU $F34F
MOD16.M16_END EQU $4074
Abs_a_b EQU $F584
DLW_SEG1_DX_LO EQU $40E9
RANDOM_3 EQU $F511
Dec_Counters EQU $F563
Rot_VL_dft EQU $F637
VEC_JOY_1_X EQU $C81B
INIT_OS_RAM EQU $F164
Vec_Expl_ChanB EQU $C85D
MUSIC1 EQU $FD0D
GET_RISE_RUN EQU $F5EF
Move_Mem_a EQU $F683
Vec_Dot_Dwell EQU $C828
Vec_Brightness EQU $C827
VEC_MUSIC_WK_7 EQU $C845
Vec_Joy_2_X EQU $C81D
INTENSITY_3F EQU $F2A1
Intensity_7F EQU $F2A9
musicc EQU $FF7A
DRAW_VLP_SCALE EQU $F40C
DLW_SEG2_DY_POS EQU $4150
COMPARE_SCORE EQU $F8C7
music4 EQU $FDD3
MOV_DRAW_VLC_A EQU $F3AD
Draw_Pat_VL_a EQU $F434
DRAW_VLCS EQU $F3D6
ROT_VL_MODE EQU $F62B
VEC_EXPL_TIMER EQU $C877
VEC_IRQ_VECTOR EQU $CBF8
Vec_Counter_6 EQU $C833
VEC_BRIGHTNESS EQU $C827
Mov_Draw_VLc_a EQU $F3AD
Draw_VL EQU $F3DD
INTENSITY_A EQU $F2AB
DO_SOUND_X EQU $F28C
VEC_PREV_BTNS EQU $C810
Vec_Expl_Flag EQU $C867
Mov_Draw_VL EQU $F3BC
Delay_0 EQU $F579
Vec_Music_Wk_7 EQU $C845
Vec_Joy_Mux EQU $C81F
Vec_Music_Wk_6 EQU $C846
Print_Str_d EQU $F37A


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
DRAW_LINE_ARGS       EQU $C880+$0E   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$18   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$1A   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$1C   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$1D   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$1E   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$20   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$22   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$23   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_BRIGHTNESS       EQU $C880+$24   ; User variable: brightness (2 bytes)
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
