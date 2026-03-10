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
VAR_VAL1             EQU $C880+$2A   ; User variable: val1 (2 bytes)
VAR_VAL2             EQU $C880+$2C   ; User variable: val2 (2 bytes)
VAR_VAL3             EQU $C880+$2E   ; User variable: val3 (2 bytes)
VAR_VAL4             EQU $C880+$30   ; User variable: val4 (2 bytes)
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
Dec_6_Counters EQU $F55E
Mov_Draw_VL_d EQU $F3BE
Dot_List EQU $F2D5
RISE_RUN_X EQU $F5FF
ADD_SCORE_A EQU $F85E
DOT_LIST EQU $F2D5
VEC_SWI2_VECTOR EQU $CBF2
MUSIC4 EQU $FDD3
DELAY_2 EQU $F571
Draw_VL_mode EQU $F46E
Recalibrate EQU $F2E6
MUSIC8 EQU $FEF8
PRINT_TEXT_STR_2093746939775237 EQU $413E
Print_Str EQU $F495
Mov_Draw_VLcs EQU $F3B5
Intensity_5F EQU $F2A5
MOV_DRAW_VL_AB EQU $F3B7
Vec_Expl_2 EQU $C859
PRINT_LIST_HW EQU $F385
Vec_Expl_Chans EQU $C854
VEC_MUSIC_WK_1 EQU $C84B
MOV_DRAW_VLC_A EQU $F3AD
Delay_RTS EQU $F57D
Vec_Num_Game EQU $C87A
STRIP_ZEROS EQU $F8B7
VECTREX_PRINT_NUMBER.PN_DIV1000 EQU $4050
music4 EQU $FDD3
Vec_Expl_Flag EQU $C867
Dot_List_Reset EQU $F2DE
Abs_b EQU $F58B
MUSIC6 EQU $FE76
VEC_TWANG_TABLE EQU $C851
VEC_PATTERN EQU $C829
Init_Music_chk EQU $F687
Clear_Score EQU $F84F
Vec_Rise_Index EQU $C839
VEC_RUN_INDEX EQU $C837
VEC_MUSIC_WORK EQU $C83F
Vec_Button_2_4 EQU $C819
Vec_Expl_3 EQU $C85A
music3 EQU $FD81
Explosion_Snd EQU $F92E
Draw_VLc EQU $F3CE
DEC_6_COUNTERS EQU $F55E
Vec_Freq_Table EQU $C84D
MOVETO_IX EQU $F310
Clear_C8_RAM EQU $F542
DOT_IX_B EQU $F2BE
DELAY_1 EQU $F575
VEC_JOY_MUX_2_Y EQU $C822
Rot_VL_Mode EQU $F62B
MOVE_MEM_A_1 EQU $F67F
DOT_D EQU $F2C3
Vec_Seed_Ptr EQU $C87B
Rise_Run_Angle EQU $F593
JOY_DIGITAL EQU $F1F8
PRINT_LIST EQU $F38A
Vec_Button_1_3 EQU $C814
Rise_Run_X EQU $F5FF
VEC_MUSIC_CHAN EQU $C855
ROT_VL_MODE EQU $F62B
MUSICB EQU $FF62
DOT_IX EQU $F2C1
Clear_x_256 EQU $F545
Wait_Recal EQU $F192
VEC_LOOP_COUNT EQU $C825
Print_Str_yx EQU $F378
MUSICA EQU $FF44
Draw_VLp_scale EQU $F40C
Read_Btns_Mask EQU $F1B4
VEC_DEFAULT_STK EQU $CBEA
Vec_Run_Index EQU $C837
VEC_BUTTON_2_2 EQU $C817
Vec_Text_Width EQU $C82B
Init_Music EQU $F68D
VEC_MUSIC_WK_A EQU $C842
RESET0REF EQU $F354
Moveto_d_7F EQU $F2FC
XFORM_RUN EQU $F65D
VECTREX_PRINT_NUMBER.PN_AFTER_CONVERT EQU $40A9
INTENSITY_5F EQU $F2A5
music9 EQU $FF26
PRINT_SHIPS EQU $F393
Sound_Byte_raw EQU $F25B
Bitmask_a EQU $F57E
CLEAR_X_B_A EQU $F552
Draw_VLp_b EQU $F40E
DRAW_GRID_VL EQU $FF9F
Vec_Button_2_3 EQU $C818
DP_TO_C8 EQU $F1AF
Vec_Twang_Table EQU $C851
RESET_PEN EQU $F35B
OBJ_HIT EQU $F8FF
Vec_Music_Wk_6 EQU $C846
Warm_Start EQU $F06C
VEC_JOY_RESLTN EQU $C81A
Vec_Expl_Chan EQU $C85C
MOVETO_IX_7F EQU $F30C
DELAY_0 EQU $F579
VECTREX_PRINT_NUMBER.PN_D100 EQU $407E
Vec_Pattern EQU $C829
INTENSITY_7F EQU $F2A9
Do_Sound_x EQU $F28C
MOVETO_D_7F EQU $F2FC
MOV_DRAW_VL_B EQU $F3B1
VEC_NMI_VECTOR EQU $CBFB
RESET0REF_D0 EQU $F34A
MUSICD EQU $FF8F
INIT_OS EQU $F18B
Get_Rise_Run EQU $F5EF
XFORM_RISE EQU $F663
Vec_Random_Seed EQU $C87D
MOD16.M16_RPOS EQU $410A
VEC_FIRQ_VECTOR EQU $CBF5
Vec_Music_Freq EQU $C861
Vec_Joy_2_X EQU $C81D
Moveto_ix_a EQU $F30E
Draw_VLcs EQU $F3D6
VEC_MUSIC_TWANG EQU $C858
VEC_JOY_MUX EQU $C81F
Vec_Counter_3 EQU $C830
VEC_BUTTON_1_1 EQU $C812
DRAW_VLC EQU $F3CE
VEC_JOY_MUX_2_X EQU $C821
CHECK0REF EQU $F34F
Vec_ADSR_Table EQU $C84F
CLEAR_X_B EQU $F53F
VEC_JOY_1_Y EQU $C81C
Rot_VL_ab EQU $F610
Vec_Joy_Mux EQU $C81F
PRINT_STR_D EQU $F37A
VEC_JOY_2_X EQU $C81D
Mov_Draw_VLc_a EQU $F3AD
Clear_x_b_a EQU $F552
DOT_LIST_RESET EQU $F2DE
Vec_Buttons EQU $C811
Rot_VL EQU $F616
Set_Refresh EQU $F1A2
DELAY_3 EQU $F56D
SOUND_BYTE_X EQU $F259
VECTREX_PRINT_NUMBER.PN_L100 EQU $406C
VEC_JOY_MUX_1_Y EQU $C820
Vec_Num_Players EQU $C879
Obj_Hit EQU $F8FF
Vec_Music_Twang EQU $C858
SET_REFRESH EQU $F1A2
Vec_Max_Games EQU $C850
Move_Mem_a_1 EQU $F67F
MOD16.M16_DPOS EQU $40F3
Vec_Button_1_1 EQU $C812
VEC_MUSIC_WK_7 EQU $C845
Move_Mem_a EQU $F683
VEC_SEED_PTR EQU $C87B
DRAW_VLP EQU $F410
MOD16.M16_END EQU $411A
VEC_RISERUN_TMP EQU $C834
VEC_TEXT_HEIGHT EQU $C82A
PRINT_TEXT_STR_1849309713591 EQU $412A
RANDOM_3 EQU $F511
Vec_SWI3_Vector EQU $CBF2
Moveto_x_7F EQU $F2F2
Compare_Score EQU $F8C7
OBJ_WILL_HIT_U EQU $F8E5
VEC_COUNTER_5 EQU $C832
INIT_OS_RAM EQU $F164
Add_Score_d EQU $F87C
Draw_VLp_7F EQU $F408
MOV_DRAW_VL EQU $F3BC
VEC_BRIGHTNESS EQU $C827
Vec_Music_Wk_7 EQU $C845
VEC_RFRSH EQU $C83D
Draw_VLp_FF EQU $F404
VEC_MUSIC_WK_5 EQU $C847
Vec_Counters EQU $C82E
Clear_x_d EQU $F548
VEC_TEXT_HW EQU $C82A
DRAW_VLP_B EQU $F40E
DOT_HERE EQU $F2C5
VEC_EXPL_2 EQU $C859
Vec_Expl_4 EQU $C85B
Moveto_ix EQU $F310
Draw_Pat_VL_d EQU $F439
VEC_BUTTON_2_1 EQU $C816
Vec_Dot_Dwell EQU $C828
Vec_IRQ_Vector EQU $CBF8
VEC_JOY_2_Y EQU $C81E
Moveto_ix_FF EQU $F308
Moveto_ix_7F EQU $F30C
INIT_MUSIC_BUF EQU $F533
CLEAR_X_D EQU $F548
DO_SOUND EQU $F289
Vec_Counter_6 EQU $C833
Vec_ADSR_Timers EQU $C85E
Joy_Analog EQU $F1F5
VEC_JOY_MUX_1_X EQU $C81F
INIT_MUSIC EQU $F68D
Mov_Draw_VL EQU $F3BC
VEC_MUSIC_FREQ EQU $C861
Draw_VLp EQU $F410
MOVE_MEM_A EQU $F683
Vec_Music_Wk_1 EQU $C84B
CLEAR_SOUND EQU $F272
PRINT_LIST_CHK EQU $F38C
Draw_Pat_VL_a EQU $F434
DRAW_PAT_VL_A EQU $F434
Vec_Music_Wk_A EQU $C842
Obj_Will_Hit_u EQU $F8E5
VEC_BUTTON_1_4 EQU $C815
SELECT_GAME EQU $F7A9
Reset0Ref EQU $F354
Print_Str_hwyx EQU $F373
DRAW_VL_AB EQU $F3D8
VEC_EXPL_CHANB EQU $C85D
Rise_Run_Y EQU $F601
Reset_Pen EQU $F35B
Vec_Loop_Count EQU $C825
Vec_Text_Height EQU $C82A
Dot_ix_b EQU $F2BE
Vec_Counter_5 EQU $C832
PRINT_STR EQU $F495
GET_RISE_IDX EQU $F5D9
Draw_VL_b EQU $F3D2
MUSIC1 EQU $FD0D
DO_SOUND_X EQU $F28C
INTENSITY_3F EQU $F2A1
MOD16 EQU $40D6
Draw_Pat_VL EQU $F437
Joy_Digital EQU $F1F8
music1 EQU $FD0D
Get_Rise_Idx EQU $F5D9
SOUND_BYTE EQU $F256
Vec_Angle EQU $C836
Clear_x_b EQU $F53F
Vec_Music_Flag EQU $C856
Sound_Byte EQU $F256
VECTREX_PRINT_NUMBER.PN_D1000 EQU $4064
Xform_Run EQU $F65D
VEC_DURATION EQU $C857
MUSIC9 EQU $FF26
Delay_2 EQU $F571
OBJ_WILL_HIT EQU $F8F3
Vec_Expl_1 EQU $C858
VEC_BUTTONS EQU $C811
Dot_here EQU $F2C5
VEC_RFRSH_LO EQU $C83D
Vec_Prev_Btns EQU $C810
VEC_RISE_INDEX EQU $C839
VECTREX_PRINT_NUMBER.PN_L1000 EQU $4052
VEC_RISERUN_LEN EQU $C83B
READ_BTNS EQU $F1BA
DRAW_PAT_VL EQU $F437
Vec_Music_Work EQU $C83F
musica EQU $FF44
Do_Sound EQU $F289
Vec_Button_2_2 EQU $C817
Delay_1 EQU $F575
DRAW_VL EQU $F3DD
Vec_Music_Ptr EQU $C853
Print_Ships_x EQU $F391
VEC_MUSIC_FLAG EQU $C856
Draw_Line_d EQU $F3DF
CLEAR_SCORE EQU $F84F
VEC_COUNTERS EQU $C82E
COMPARE_SCORE EQU $F8C7
Mov_Draw_VL_a EQU $F3B9
Rise_Run_Len EQU $F603
Draw_Grid_VL EQU $FF9F
Vec_Rfrsh EQU $C83D
Dec_3_Counters EQU $F55A
MOVETO_IX_A EQU $F30E
Vec_Counter_4 EQU $C831
PRINT_SHIPS_X EQU $F391
Vec_Joy_Mux_1_X EQU $C81F
VEC_MAX_PLAYERS EQU $C84F
Reset0Ref_D0 EQU $F34A
Vec_Expl_ChanA EQU $C853
Draw_VL_ab EQU $F3D8
MOVETO_X_7F EQU $F2F2
SOUND_BYTE_RAW EQU $F25B
DP_TO_D0 EQU $F1AA
VEC_EXPL_FLAG EQU $C867
Reset0Int EQU $F36B
JOY_ANALOG EQU $F1F5
MUSIC5 EQU $FE38
Mov_Draw_VL_ab EQU $F3B7
Vec_Btn_State EQU $C80F
Clear_Sound EQU $F272
WAIT_RECAL EQU $F192
DEC_3_COUNTERS EQU $F55A
MUSIC2 EQU $FD1D
Vec_0Ref_Enable EQU $C824
Vec_RiseRun_Len EQU $C83B
VEC_EXPL_4 EQU $C85B
Sound_Byte_x EQU $F259
Vec_Music_Chan EQU $C855
MOD16.M16_RCHECK EQU $40FB
DRAW_VL_B EQU $F3D2
Rot_VL_Mode_a EQU $F61F
Vec_FIRQ_Vector EQU $CBF5
XFORM_RISE_A EQU $F661
Init_OS_RAM EQU $F164
Vec_Snd_Shadow EQU $C800
Vec_Joy_1_Y EQU $C81C
Vec_Joy_1_X EQU $C81B
music6 EQU $FE76
VEC_RANDOM_SEED EQU $C87D
VEC_HIGH_SCORE EQU $CBEB
Check0Ref EQU $F34F
Vec_Max_Players EQU $C84F
Delay_b EQU $F57A
INTENSITY_A EQU $F2AB
Vec_Music_Wk_5 EQU $C847
RECALIBRATE EQU $F2E6
VEC_COUNTER_6 EQU $C833
Select_Game EQU $F7A9
VEC_ADSR_TIMERS EQU $C85E
Add_Score_a EQU $F85E
VEC_SWI_VECTOR EQU $CBFB
Intensity_a EQU $F2AB
Init_Music_x EQU $F692
Read_Btns EQU $F1BA
WARM_START EQU $F06C
DRAW_VLP_7F EQU $F408
XFORM_RUN_A EQU $F65B
DELAY_B EQU $F57A
musicb EQU $FF62
PRINT_STR_HWYX EQU $F373
MOV_DRAW_VLCS EQU $F3B5
MOD16.M16_LOOP EQU $410A
Vec_Expl_Timer EQU $C877
INIT_MUSIC_X EQU $F692
READ_BTNS_MASK EQU $F1B4
Vec_RiseRun_Tmp EQU $C834
MUSIC3 EQU $FD81
Moveto_d EQU $F312
VECTREX_PRINT_NUMBER.PN_D10 EQU $4098
Abs_a_b EQU $F584
Vec_Rfrsh_hi EQU $C83E
DRAW_VL_A EQU $F3DA
VEC_TEXT_WIDTH EQU $C82B
ABS_B EQU $F58B
Vec_SWI_Vector EQU $CBFB
Xform_Rise EQU $F663
Dec_Counters EQU $F563
Print_Str_d EQU $F37A
music5 EQU $FE38
DRAW_VLCS EQU $F3D6
Vec_Button_2_1 EQU $C816
Print_List_hw EQU $F385
Vec_Expl_ChanB EQU $C85D
MOV_DRAW_VL_D EQU $F3BE
DRAW_VLP_FF EQU $F404
MUSIC7 EQU $FEC6
VEC_ANGLE EQU $C836
Vec_Joy_Resltn EQU $C81A
VEC_BUTTON_2_4 EQU $C819
VEC_SWI3_VECTOR EQU $CBF2
ROT_VL_MODE_A EQU $F61F
Vec_Joy_Mux_2_X EQU $C821
Draw_VL_a EQU $F3DA
Vec_Button_1_2 EQU $C813
VEC_BTN_STATE EQU $C80F
Random EQU $F517
Vec_Counter_2 EQU $C82F
Vec_High_Score EQU $CBEB
ADD_SCORE_D EQU $F87C
VEC_COLD_FLAG EQU $CBFE
SOUND_BYTES_X EQU $F284
Vec_SWI2_Vector EQU $CBF2
GET_RISE_RUN EQU $F5EF
Vec_Rfrsh_lo EQU $C83D
VEC_JOY_1_X EQU $C81B
VEC_IRQ_VECTOR EQU $CBF8
VEC_FREQ_TABLE EQU $C84D
Vec_NMI_Vector EQU $CBFB
RESET0INT EQU $F36B
Xform_Run_a EQU $F65B
RISE_RUN_Y EQU $F601
SOUND_BYTES EQU $F27D
VEC_COUNTER_3 EQU $C830
Rot_VL_dft EQU $F637
New_High_Score EQU $F8D8
VEC_EXPL_3 EQU $C85A
COLD_START EQU $F000
Delay_3 EQU $F56D
Mov_Draw_VL_b EQU $F3B1
ROT_VL EQU $F616
Init_Music_Buf EQU $F533
DELAY_RTS EQU $F57D
PRINT_TEXT_STR_2100294941933655 EQU $4149
DP_to_D0 EQU $F1AA
VEC_BUTTON_1_2 EQU $C813
Vec_Counter_1 EQU $C82E
RISE_RUN_LEN EQU $F603
Dot_ix EQU $F2C1
BITMASK_A EQU $F57E
music2 EQU $FD1D
CLEAR_X_B_80 EQU $F550
VEC_COUNTER_2 EQU $C82F
VEC_SND_SHADOW EQU $C800
MOD16.M16_DONE EQU $4129
VEC_BUTTON_2_3 EQU $C818
VEC_0REF_ENABLE EQU $C824
ROT_VL_AB EQU $F610
VEC_STR_PTR EQU $C82C
VEC_COUNTER_4 EQU $C831
VEC_BUTTON_1_3 EQU $C814
musicd EQU $FF8F
MOV_DRAW_VL_A EQU $F3B9
VECTREX_PRINT_NUMBER EQU $4030
MOVETO_IX_FF EQU $F308
Sound_Bytes EQU $F27D
Dot_d EQU $F2C3
VECTREX_PRINT_TEXT EQU $4000
Get_Run_Idx EQU $F5DB
DRAW_PAT_VL_D EQU $F439
PRINT_TEXT_STR_1838133390096266 EQU $4133
VEC_DOT_DWELL EQU $C828
Vec_Brightness EQU $C827
Vec_Text_HW EQU $C82A
Vec_Button_1_4 EQU $C815
VECTREX_PRINT_NUMBER.PN_L10 EQU $4086
Intensity_3F EQU $F2A1
Vec_Joy_Mux_2_Y EQU $C822
VEC_PREV_BTNS EQU $C810
VEC_NUM_GAME EQU $C87A
DRAW_VL_MODE EQU $F46E
ABS_A_B EQU $F584
VEC_MUSIC_WK_6 EQU $C846
EXPLOSION_SND EQU $F92E
INIT_VIA EQU $F14C
VEC_EXPL_CHAN EQU $C85C
Vec_Cold_Flag EQU $CBFE
VEC_MAX_GAMES EQU $C850
music8 EQU $FEF8
musicc EQU $FF7A
DRAW_LINE_D EQU $F3DF
Vec_Duration EQU $C857
Vec_Joy_Mux_1_Y EQU $C820
Vec_Str_Ptr EQU $C82C
Cold_Start EQU $F000
Random_3 EQU $F511
VEC_EXPL_1 EQU $C858
Intensity_1F EQU $F29D
MUSICC EQU $FF7A
ROT_VL_DFT EQU $F637
VEC_EXPL_CHANS EQU $C854
Init_OS EQU $F18B
NEW_HIGH_SCORE EQU $F8D8
RISE_RUN_ANGLE EQU $F593
PRINT_STR_YX EQU $F378
INTENSITY_1F EQU $F29D
Xform_Rise_a EQU $F661
Strip_Zeros EQU $F8B7
DEC_COUNTERS EQU $F563
Vec_Default_Stk EQU $CBEA
Delay_0 EQU $F579
CLEAR_X_256 EQU $F545
Init_VIA EQU $F14C
VEC_ADSR_TABLE EQU $C84F
Vec_Misc_Count EQU $C823
music7 EQU $FEC6
Vec_Joy_2_Y EQU $C81E
Sound_Bytes_x EQU $F284
DRAW_VLP_SCALE EQU $F40C
CLEAR_C8_RAM EQU $F542
GET_RUN_IDX EQU $F5DB
VEC_COUNTER_1 EQU $C82E
Clear_x_b_80 EQU $F550
RANDOM EQU $F517
Obj_Will_Hit EQU $F8F3
MOVETO_D EQU $F312
VEC_EXPL_TIMER EQU $C877
Intensity_7F EQU $F2A9
Print_List EQU $F38A
VEC_RFRSH_HI EQU $C83E
Print_Ships EQU $F393
VEC_MISC_COUNT EQU $C823
Print_List_chk EQU $F38C
INIT_MUSIC_CHK EQU $F687
VEC_MUSIC_PTR EQU $C853
Draw_VL EQU $F3DD
VEC_EXPL_CHANA EQU $C853
DP_to_C8 EQU $F1AF
VEC_NUM_PLAYERS EQU $C879


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
VAR_VAL1             EQU $C880+$2A   ; User variable: val1 (2 bytes)
VAR_VAL2             EQU $C880+$2C   ; User variable: val2 (2 bytes)
VAR_VAL3             EQU $C880+$2E   ; User variable: val3 (2 bytes)
VAR_VAL4             EQU $C880+$30   ; User variable: val4 (2 bytes)
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
