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
NUM_STR              EQU $C880+$0E   ; Buffer for PRINT_NUMBER decimal output (5 digits + terminator) (6 bytes)
DRAW_LINE_ARGS       EQU $C880+$14   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$1E   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$20   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$22   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$23   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$24   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$26   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$28   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$29   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_VAL1             EQU $C880+$2A   ; User variable: VAL1 (2 bytes)
VAR_VAL2             EQU $C880+$2C   ; User variable: VAL2 (2 bytes)
VAR_VAL3             EQU $C880+$2E   ; User variable: VAL3 (2 bytes)
VAR_VAL4             EQU $C880+$30   ; User variable: VAL4 (2 bytes)
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
DOT_D EQU $F2C3
Clear_Sound EQU $F272
VEC_NUM_PLAYERS EQU $C879
Check0Ref EQU $F34F
MOD16.M16_DPOS EQU $40F3
DRAW_VLP_FF EQU $F404
Vec_Brightness EQU $C827
GET_RUN_IDX EQU $F5DB
MOD16.M16_LOOP EQU $410A
MOV_DRAW_VLC_A EQU $F3AD
MOV_DRAW_VL_D EQU $F3BE
MOD16 EQU $40D6
Print_Ships EQU $F393
DOT_IX EQU $F2C1
DRAW_VL_B EQU $F3D2
RESET0REF_D0 EQU $F34A
Dot_ix EQU $F2C1
Draw_VL_a EQU $F3DA
VEC_COUNTER_1 EQU $C82E
CLEAR_X_B_A EQU $F552
Vec_Music_Wk_1 EQU $C84B
VEC_IRQ_VECTOR EQU $CBF8
DRAW_VLCS EQU $F3D6
Print_List_hw EQU $F385
Obj_Will_Hit EQU $F8F3
VEC_EXPL_CHANS EQU $C854
DP_to_D0 EQU $F1AA
Vec_Music_Wk_6 EQU $C846
VEC_JOY_MUX_1_Y EQU $C820
Xform_Rise EQU $F663
MUSIC1 EQU $FD0D
MUSIC6 EQU $FE76
Vec_IRQ_Vector EQU $CBF8
Vec_Expl_4 EQU $C85B
Moveto_d EQU $F312
Vec_Music_Freq EQU $C861
RISE_RUN_Y EQU $F601
VEC_SWI_VECTOR EQU $CBFB
VEC_DOT_DWELL EQU $C828
Clear_x_b EQU $F53F
Clear_x_b_a EQU $F552
Obj_Will_Hit_u EQU $F8E5
VEC_SEED_PTR EQU $C87B
Moveto_ix_a EQU $F30E
music7 EQU $FEC6
DELAY_1 EQU $F575
Mov_Draw_VL EQU $F3BC
PRINT_STR EQU $F495
Read_Btns_Mask EQU $F1B4
Vec_Joy_Mux EQU $C81F
Xform_Rise_a EQU $F661
Vec_High_Score EQU $CBEB
Vec_Rfrsh_lo EQU $C83D
Abs_a_b EQU $F584
DRAW_VLP_7F EQU $F408
READ_BTNS EQU $F1BA
INTENSITY_5F EQU $F2A5
RISE_RUN_ANGLE EQU $F593
MOV_DRAW_VL_AB EQU $F3B7
VEC_MUSIC_WK_1 EQU $C84B
Strip_Zeros EQU $F8B7
Vec_Text_Width EQU $C82B
VECTREX_PRINT_NUMBER.PN_D100 EQU $407E
Vec_Music_Chan EQU $C855
Vec_Music_Work EQU $C83F
Vec_Expl_1 EQU $C858
DRAW_VLP_B EQU $F40E
INTENSITY_A EQU $F2AB
Explosion_Snd EQU $F92E
INTENSITY_3F EQU $F2A1
INIT_VIA EQU $F14C
Vec_Expl_Flag EQU $C867
DEC_COUNTERS EQU $F563
Rise_Run_Len EQU $F603
Vec_Counter_5 EQU $C832
Print_Str EQU $F495
Vec_NMI_Vector EQU $CBFB
Vec_Rfrsh EQU $C83D
Abs_b EQU $F58B
BITMASK_A EQU $F57E
Vec_Btn_State EQU $C80F
DOT_HERE EQU $F2C5
VEC_PREV_BTNS EQU $C810
VEC_COUNTER_6 EQU $C833
OBJ_HIT EQU $F8FF
DOT_IX_B EQU $F2BE
VEC_COUNTER_4 EQU $C831
COLD_START EQU $F000
Vec_Random_Seed EQU $C87D
Obj_Hit EQU $F8FF
Vec_Music_Flag EQU $C856
Draw_VL_b EQU $F3D2
XFORM_RUN EQU $F65D
Vec_Expl_Timer EQU $C877
VEC_PATTERN EQU $C829
DOT_LIST EQU $F2D5
Vec_0Ref_Enable EQU $C824
CLEAR_X_B EQU $F53F
Vec_Button_1_2 EQU $C813
VEC_JOY_2_Y EQU $C81E
RESET0INT EQU $F36B
SOUND_BYTES EQU $F27D
Dot_d EQU $F2C3
Clear_Score EQU $F84F
Vec_Snd_Shadow EQU $C800
Draw_Grid_VL EQU $FF9F
Mov_Draw_VL_d EQU $F3BE
VEC_EXPL_CHANB EQU $C85D
MUSIC9 EQU $FF26
SET_REFRESH EQU $F1A2
Vec_ADSR_Timers EQU $C85E
Vec_Expl_3 EQU $C85A
Rot_VL EQU $F616
Mov_Draw_VLcs EQU $F3B5
Do_Sound_x EQU $F28C
Clear_x_256 EQU $F545
RESET_PEN EQU $F35B
music8 EQU $FEF8
Init_VIA EQU $F14C
PRINT_TEXT_STR_2093746939775237 EQU $413E
PRINT_LIST EQU $F38A
Vec_Rise_Index EQU $C839
Mov_Draw_VL_a EQU $F3B9
VEC_FREQ_TABLE EQU $C84D
VEC_RFRSH EQU $C83D
Vec_Counter_6 EQU $C833
VEC_MUSIC_PTR EQU $C853
Vec_Counter_3 EQU $C830
Vec_Joy_Mux_2_Y EQU $C822
DELAY_0 EQU $F579
Dot_List_Reset EQU $F2DE
ROT_VL_DFT EQU $F637
Moveto_x_7F EQU $F2F2
Vec_Pattern EQU $C829
DRAW_PAT_VL_A EQU $F434
Draw_VLp_scale EQU $F40C
VEC_JOY_MUX_2_X EQU $C821
CLEAR_X_D EQU $F548
Vec_Joy_2_Y EQU $C81E
Intensity_7F EQU $F2A9
Set_Refresh EQU $F1A2
VEC_EXPL_TIMER EQU $C877
READ_BTNS_MASK EQU $F1B4
MOVETO_IX_7F EQU $F30C
Vec_Buttons EQU $C811
Vec_Counter_1 EQU $C82E
Get_Rise_Run EQU $F5EF
Vec_SWI3_Vector EQU $CBF2
VEC_NUM_GAME EQU $C87A
VECTREX_PRINT_NUMBER.PN_D1000 EQU $4064
RESET0REF EQU $F354
DRAW_PAT_VL_D EQU $F439
VEC_ADSR_TABLE EQU $C84F
Delay_0 EQU $F579
Init_OS_RAM EQU $F164
MOV_DRAW_VL EQU $F3BC
STRIP_ZEROS EQU $F8B7
SOUND_BYTE EQU $F256
VEC_COLD_FLAG EQU $CBFE
Draw_Pat_VL_a EQU $F434
Dot_ix_b EQU $F2BE
VEC_EXPL_3 EQU $C85A
VEC_DURATION EQU $C857
CLEAR_SCORE EQU $F84F
VEC_EXPL_FLAG EQU $C867
ABS_A_B EQU $F584
Read_Btns EQU $F1BA
VEC_JOY_RESLTN EQU $C81A
Xform_Run_a EQU $F65B
Vec_Prev_Btns EQU $C810
VEC_DEFAULT_STK EQU $CBEA
SOUND_BYTE_X EQU $F259
XFORM_RISE EQU $F663
MUSICC EQU $FF7A
Vec_Expl_ChanB EQU $C85D
Draw_VL_mode EQU $F46E
VEC_RUN_INDEX EQU $C837
VEC_SND_SHADOW EQU $C800
MUSIC3 EQU $FD81
Moveto_ix EQU $F310
DO_SOUND EQU $F289
GET_RISE_RUN EQU $F5EF
Vec_Button_2_2 EQU $C817
Mov_Draw_VL_ab EQU $F3B7
Clear_C8_RAM EQU $F542
MOD16.M16_DONE EQU $4129
Vec_Joy_Mux_1_Y EQU $C820
MOV_DRAW_VL_B EQU $F3B1
MOV_DRAW_VLCS EQU $F3B5
VEC_COUNTER_5 EQU $C832
VEC_JOY_2_X EQU $C81D
Vec_Text_Height EQU $C82A
VEC_ADSR_TIMERS EQU $C85E
PRINT_STR_HWYX EQU $F373
Joy_Digital EQU $F1F8
Print_Str_yx EQU $F378
Intensity_5F EQU $F2A5
DRAW_VL EQU $F3DD
VEC_FIRQ_VECTOR EQU $CBF5
music3 EQU $FD81
VEC_0REF_ENABLE EQU $C824
Vec_Default_Stk EQU $CBEA
DO_SOUND_X EQU $F28C
INTENSITY_1F EQU $F29D
Move_Mem_a_1 EQU $F67F
VEC_NMI_VECTOR EQU $CBFB
SELECT_GAME EQU $F7A9
Compare_Score EQU $F8C7
PRINT_TEXT_STR_1838133390096266 EQU $4133
DRAW_VL_AB EQU $F3D8
Print_Ships_x EQU $F391
EXPLOSION_SND EQU $F92E
Vec_Num_Players EQU $C879
JOY_ANALOG EQU $F1F5
Dec_3_Counters EQU $F55A
VEC_COUNTER_2 EQU $C82F
Vec_Expl_2 EQU $C859
Vec_Joy_Mux_1_X EQU $C81F
CLEAR_C8_RAM EQU $F542
Draw_VLp_b EQU $F40E
Draw_VLcs EQU $F3D6
musicc EQU $FF7A
CLEAR_SOUND EQU $F272
Cold_Start EQU $F000
Vec_Rfrsh_hi EQU $C83E
Delay_3 EQU $F56D
Rot_VL_Mode EQU $F62B
VECTREX_PRINT_TEXT EQU $4000
Vec_Music_Wk_5 EQU $C847
VEC_RANDOM_SEED EQU $C87D
Vec_Music_Wk_A EQU $C842
DRAW_LINE_D EQU $F3DF
Init_OS EQU $F18B
Clear_x_d EQU $F548
VEC_MUSIC_CHAN EQU $C855
VEC_EXPL_1 EQU $C858
VEC_EXPL_4 EQU $C85B
musicb EQU $FF62
VEC_MUSIC_FREQ EQU $C861
Draw_Pat_VL_d EQU $F439
Rise_Run_X EQU $F5FF
VECTREX_PRINT_NUMBER.PN_L100 EQU $406C
Vec_Button_1_1 EQU $C812
ROT_VL_MODE EQU $F62B
DEC_6_COUNTERS EQU $F55E
VEC_BUTTON_2_2 EQU $C817
Vec_Button_2_3 EQU $C818
Vec_RiseRun_Len EQU $C83B
DRAW_VLP EQU $F410
XFORM_RUN_A EQU $F65B
ROT_VL_MODE_A EQU $F61F
MOD16.M16_RCHECK EQU $40FB
music2 EQU $FD1D
GET_RISE_IDX EQU $F5D9
PRINT_STR_YX EQU $F378
Sound_Bytes EQU $F27D
VEC_SWI2_VECTOR EQU $CBF2
Print_Str_hwyx EQU $F373
Dot_List EQU $F2D5
OBJ_WILL_HIT_U EQU $F8E5
Rot_VL_dft EQU $F637
MOVETO_IX_FF EQU $F308
Vec_Music_Twang EQU $C858
Vec_Dot_Dwell EQU $C828
music4 EQU $FDD3
Add_Score_a EQU $F85E
Dot_here EQU $F2C5
DELAY_3 EQU $F56D
VEC_RISERUN_TMP EQU $C834
Get_Run_Idx EQU $F5DB
PRINT_LIST_HW EQU $F385
VEC_RISERUN_LEN EQU $C83B
Sound_Bytes_x EQU $F284
Rot_VL_Mode_a EQU $F61F
VEC_SWI3_VECTOR EQU $CBF2
Vec_Expl_Chan EQU $C85C
music9 EQU $FF26
VEC_TEXT_WIDTH EQU $C82B
Vec_Joy_Resltn EQU $C81A
musicd EQU $FF8F
MUSIC8 EQU $FEF8
Dec_6_Counters EQU $F55E
VEC_JOY_MUX_1_X EQU $C81F
Delay_RTS EQU $F57D
MUSIC2 EQU $FD1D
Random_3 EQU $F511
Print_List_chk EQU $F38C
Vec_Music_Wk_7 EQU $C845
Vec_Cold_Flag EQU $CBFE
Vec_Button_1_3 EQU $C814
Init_Music EQU $F68D
VECTREX_PRINT_NUMBER EQU $4030
VEC_MUSIC_WORK EQU $C83F
DRAW_PAT_VL EQU $F437
VEC_EXPL_CHANA EQU $C853
Vec_Angle EQU $C836
Vec_Seed_Ptr EQU $C87B
VEC_RISE_INDEX EQU $C839
Moveto_d_7F EQU $F2FC
Draw_VL EQU $F3DD
PRINT_SHIPS EQU $F393
ADD_SCORE_A EQU $F85E
VECTREX_PRINT_NUMBER.PN_D10 EQU $4098
Wait_Recal EQU $F192
Vec_Button_2_4 EQU $C819
Sound_Byte_x EQU $F259
Warm_Start EQU $F06C
Vec_Freq_Table EQU $C84D
Vec_Counters EQU $C82E
DRAW_VL_A EQU $F3DA
COMPARE_SCORE EQU $F8C7
Draw_VLp_7F EQU $F408
Intensity_a EQU $F2AB
Draw_Pat_VL EQU $F437
VEC_TEXT_HW EQU $C82A
VEC_BRIGHTNESS EQU $C827
VEC_HIGH_SCORE EQU $CBEB
INIT_MUSIC_CHK EQU $F687
MUSIC5 EQU $FE38
Init_Music_Buf EQU $F533
VEC_MUSIC_WK_6 EQU $C846
music6 EQU $FE76
VEC_LOOP_COUNT EQU $C825
Vec_SWI2_Vector EQU $CBF2
VEC_MAX_GAMES EQU $C850
Draw_VLc EQU $F3CE
Vec_Expl_Chans EQU $C854
INTENSITY_7F EQU $F2A9
DELAY_2 EQU $F571
JOY_DIGITAL EQU $F1F8
MOVETO_IX_A EQU $F30E
DP_TO_C8 EQU $F1AF
VEC_BUTTON_2_1 EQU $C816
MOV_DRAW_VL_A EQU $F3B9
Init_Music_x EQU $F692
Vec_Duration EQU $C857
VEC_MUSIC_WK_A EQU $C842
DRAW_GRID_VL EQU $FF9F
MUSIC4 EQU $FDD3
VEC_JOY_1_Y EQU $C81C
Delay_1 EQU $F575
Mov_Draw_VL_b EQU $F3B1
Vec_SWI_Vector EQU $CBFB
Sound_Byte_raw EQU $F25B
WARM_START EQU $F06C
VEC_JOY_MUX EQU $C81F
VEC_JOY_MUX_2_Y EQU $C822
Select_Game EQU $F7A9
Print_List EQU $F38A
Get_Rise_Idx EQU $F5D9
Draw_VLp EQU $F410
CLEAR_X_B_80 EQU $F550
Clear_x_b_80 EQU $F550
Move_Mem_a EQU $F683
VECTREX_PRINT_NUMBER.PN_L10 EQU $4086
Moveto_ix_7F EQU $F30C
RISE_RUN_X EQU $F5FF
VEC_TEXT_HEIGHT EQU $C82A
MUSIC7 EQU $FEC6
SOUND_BYTE_RAW EQU $F25B
INIT_MUSIC_X EQU $F692
VEC_MUSIC_FLAG EQU $C856
Delay_b EQU $F57A
music1 EQU $FD0D
Vec_Counter_4 EQU $C831
Reset0Int EQU $F36B
RANDOM_3 EQU $F511
VEC_COUNTERS EQU $C82E
Rise_Run_Y EQU $F601
NEW_HIGH_SCORE EQU $F8D8
Xform_Run EQU $F65D
Vec_Button_2_1 EQU $C816
Rot_VL_ab EQU $F610
RISE_RUN_LEN EQU $F603
VEC_BUTTONS EQU $C811
Joy_Analog EQU $F1F5
DELAY_RTS EQU $F57D
RECALIBRATE EQU $F2E6
RANDOM EQU $F517
Delay_2 EQU $F571
VEC_MUSIC_TWANG EQU $C858
Vec_Max_Games EQU $C850
MOVETO_X_7F EQU $F2F2
MOVETO_D EQU $F312
VEC_RFRSH_HI EQU $C83E
Draw_VL_ab EQU $F3D8
MOD16.M16_END EQU $411A
Intensity_1F EQU $F29D
Add_Score_d EQU $F87C
VEC_BUTTON_1_2 EQU $C813
Vec_Text_HW EQU $C82A
CHECK0REF EQU $F34F
Do_Sound EQU $F289
Draw_Line_d EQU $F3DF
Rise_Run_Angle EQU $F593
MOVE_MEM_A EQU $F683
Print_Str_d EQU $F37A
Vec_Twang_Table EQU $C851
INIT_MUSIC EQU $F68D
Reset_Pen EQU $F35B
VEC_RFRSH_LO EQU $C83D
Vec_Music_Ptr EQU $C853
music5 EQU $FE38
Vec_Joy_1_X EQU $C81B
Dec_Counters EQU $F563
DP_to_C8 EQU $F1AF
Draw_VLp_FF EQU $F404
OBJ_WILL_HIT EQU $F8F3
DOT_LIST_RESET EQU $F2DE
Init_Music_chk EQU $F687
Vec_Joy_Mux_2_X EQU $C821
Vec_Joy_2_X EQU $C81D
Random EQU $F517
Recalibrate EQU $F2E6
INIT_OS_RAM EQU $F164
Vec_Misc_Count EQU $C823
MOVE_MEM_A_1 EQU $F67F
VEC_BTN_STATE EQU $C80F
VEC_BUTTON_1_4 EQU $C815
VECTREX_PRINT_NUMBER.PN_L1000 EQU $4052
VEC_EXPL_CHAN EQU $C85C
Vec_Max_Players EQU $C84F
Mov_Draw_VLc_a EQU $F3AD
PRINT_TEXT_STR_2100294941933655 EQU $4149
VEC_COUNTER_3 EQU $C830
ROT_VL_AB EQU $F610
Vec_Num_Game EQU $C87A
MOD16.M16_RPOS EQU $410A
ROT_VL EQU $F616
MOVETO_D_7F EQU $F2FC
PRINT_SHIPS_X EQU $F391
DP_TO_D0 EQU $F1AA
Vec_Button_1_4 EQU $C815
Vec_Run_Index EQU $C837
PRINT_TEXT_STR_1849309713591 EQU $412A
XFORM_RISE_A EQU $F661
DELAY_B EQU $F57A
Bitmask_a EQU $F57E
VECTREX_PRINT_NUMBER.PN_AFTER_CONVERT EQU $40A9
Reset0Ref_D0 EQU $F34A
DRAW_VL_MODE EQU $F46E
musica EQU $FF44
Moveto_ix_FF EQU $F308
VEC_MUSIC_WK_7 EQU $C845
ADD_SCORE_D EQU $F87C
Intensity_3F EQU $F2A1
VEC_MUSIC_WK_5 EQU $C847
Vec_ADSR_Table EQU $C84F
INIT_MUSIC_BUF EQU $F533
VEC_TWANG_TABLE EQU $C851
MOVETO_IX EQU $F310
VEC_EXPL_2 EQU $C859
VEC_BUTTON_2_3 EQU $C818
Vec_Joy_1_Y EQU $C81C
Sound_Byte EQU $F256
SOUND_BYTES_X EQU $F284
DRAW_VLP_SCALE EQU $F40C
VEC_JOY_1_X EQU $C81B
Vec_Counter_2 EQU $C82F
Reset0Ref EQU $F354
Vec_FIRQ_Vector EQU $CBF5
Vec_RiseRun_Tmp EQU $C834
VEC_MISC_COUNT EQU $C823
VEC_STR_PTR EQU $C82C
VECTREX_PRINT_NUMBER.PN_DIV1000 EQU $4050
INIT_OS EQU $F18B
ABS_B EQU $F58B
PRINT_STR_D EQU $F37A
Vec_Expl_ChanA EQU $C853
VEC_BUTTON_2_4 EQU $C819
PRINT_LIST_CHK EQU $F38C
WAIT_RECAL EQU $F192
Vec_Str_Ptr EQU $C82C
Vec_Loop_Count EQU $C825
MUSICA EQU $FF44
VEC_BUTTON_1_1 EQU $C812
MUSICD EQU $FF8F
CLEAR_X_256 EQU $F545
VEC_MAX_PLAYERS EQU $C84F
VEC_ANGLE EQU $C836
DRAW_VLC EQU $F3CE
DEC_3_COUNTERS EQU $F55A
VEC_BUTTON_1_3 EQU $C814
New_High_Score EQU $F8D8
MUSICB EQU $FF62


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "MATH_FUNC"
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
NUM_STR              EQU $C880+$0E   ; Buffer for PRINT_NUMBER decimal output (5 digits + terminator) (6 bytes)
DRAW_LINE_ARGS       EQU $C880+$14   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$1E   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$20   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$22   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$23   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$24   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$26   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$28   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$29   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_VAL1             EQU $C880+$2A   ; User variable: VAL1 (2 bytes)
VAR_VAL2             EQU $C880+$2C   ; User variable: VAL2 (2 bytes)
VAR_VAL3             EQU $C880+$2E   ; User variable: VAL3 (2 bytes)
VAR_VAL4             EQU $C880+$30   ; User variable: VAL4 (2 bytes)
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
    ; TODO: Statement Pass { source_line: 11 }

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    ; ABS: Absolute value
    LDD #-50
    TSTA           ; Test sign bit
    LBPL .ABS_0_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_0_POS:
    STD RESULT
    STD VAR_VAL1
    ; PRINT_TEXT: Print text at position
    LDD #-100
    STD VAR_ARG0
    LDD #80
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_1849309713591      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #30
    STD VAR_ARG0    ; X position
    LDD #80
    STD VAR_ARG1    ; Y position
    LDD >VAR_VAL1
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; MIN: Return minimum of two values
    LDD #30
    STD TMPPTR     ; Save first value
    LDD #70
    STD TMPPTR2    ; Save second value
    LDD TMPPTR     ; Load first value
    CMPD TMPPTR2   ; Compare first vs second
    LBLE .MIN_1_FIRST ; Branch if first <= second
    LDD TMPPTR2    ; Second is smaller
    STD RESULT
    LBRA .MIN_1_END
.MIN_1_FIRST:
    STD RESULT     ; First is smaller (D still = first from LDD TMPPTR)
.MIN_1_END:
    STD VAR_VAL2
    ; PRINT_TEXT: Print text at position
    LDD #-100
    STD VAR_ARG0
    LDD #60
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2100294941933655      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #30
    STD VAR_ARG0    ; X position
    LDD #60
    STD VAR_ARG1    ; Y position
    LDD >VAR_VAL2
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; MAX: Return maximum of two values
    LDD #30
    STD TMPPTR     ; Save first value
    LDD #70
    STD TMPPTR2    ; Save second value
    LDD TMPPTR     ; Load first value
    CMPD TMPPTR2   ; Compare first vs second
    LBGE .MAX_2_FIRST ; Branch if first >= second
    LDD TMPPTR2    ; Second is larger
    STD RESULT
    LBRA .MAX_2_END
.MAX_2_FIRST:
    STD RESULT     ; First is larger (D still = first from LDD TMPPTR)
.MAX_2_END:
    STD VAR_VAL3
    ; PRINT_TEXT: Print text at position
    LDD #-100
    STD VAR_ARG0
    LDD #40
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2093746939775237      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #30
    STD VAR_ARG0    ; X position
    LDD #40
    STD VAR_ARG1    ; Y position
    LDD >VAR_VAL3
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; CLAMP: Clamp value to range [min, max]
    LDD #150
    STD TMPPTR     ; Save value
    LDD #0
    STD TMPPTR+2   ; Save min
    LDD #100
    STD TMPPTR+4   ; Save max
    LDD TMPPTR     ; Load value
    CMPD TMPPTR+2  ; Compare with min
    LBGE .CLAMP_3_CHK_MAX ; Branch if value >= min
    LDD TMPPTR+2
    STD RESULT
    LBRA .CLAMP_3_END
.CLAMP_3_CHK_MAX:
    LDD TMPPTR     ; Load value again
    CMPD TMPPTR+4  ; Compare with max
    LBLE .CLAMP_3_OK  ; Branch if value <= max
    LDD TMPPTR+4
    STD RESULT
    LBRA .CLAMP_3_END
.CLAMP_3_OK:
    LDD TMPPTR
    STD RESULT
.CLAMP_3_END:
    STD VAR_VAL4
    ; PRINT_TEXT: Print text at position
    LDD #-100
    STD VAR_ARG0
    LDD #20
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_1838133390096266      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #30
    STD VAR_ARG0    ; X position
    LDD #20
    STD VAR_ARG1    ; Y position
    LDD >VAR_VAL4
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    RTS


; ================================================
