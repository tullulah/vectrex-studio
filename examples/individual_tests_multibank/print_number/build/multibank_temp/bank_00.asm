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
VAR_COUNTER          EQU $C880+$2A   ; User variable: COUNTER (2 bytes)
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
WAIT_RECAL EQU $F192
CLEAR_SCORE EQU $F84F
VEC_MISC_COUNT EQU $C823
VEC_COUNTER_5 EQU $C832
MUSICA EQU $FF44
DOT_D EQU $F2C3
Rise_Run_Angle EQU $F593
Xform_Run EQU $F65D
Mov_Draw_VLc_a EQU $F3AD
VEC_BUTTON_1_1 EQU $C812
Vec_Button_1_1 EQU $C812
Obj_Hit EQU $F8FF
DRAW_VL_A EQU $F3DA
Mov_Draw_VL_d EQU $F3BE
Clear_x_b EQU $F53F
Rise_Run_Len EQU $F603
VEC_NUM_PLAYERS EQU $C879
BITMASK_A EQU $F57E
ROT_VL_MODE EQU $F62B
VECTREX_PRINT_NUMBER.PN_D10 EQU $4098
Vec_Expl_3 EQU $C85A
Vec_Music_Work EQU $C83F
Vec_Counter_5 EQU $C832
Wait_Recal EQU $F192
CLEAR_C8_RAM EQU $F542
Get_Rise_Idx EQU $F5D9
Vec_Music_Wk_1 EQU $C84B
PRINT_STR EQU $F495
Intensity_1F EQU $F29D
MOD16 EQU $40D6
Vec_Dot_Dwell EQU $C828
ADD_SCORE_D EQU $F87C
RESET0INT EQU $F36B
Joy_Analog EQU $F1F5
Delay_RTS EQU $F57D
INIT_MUSIC_X EQU $F692
Vec_Rfrsh EQU $C83D
ROT_VL_MODE_A EQU $F61F
VEC_JOY_MUX_2_Y EQU $C822
Abs_b EQU $F58B
Vec_Counter_4 EQU $C831
MOVETO_IX_7F EQU $F30C
VEC_BUTTONS EQU $C811
Vec_Button_2_1 EQU $C816
VEC_ANGLE EQU $C836
SET_REFRESH EQU $F1A2
RISE_RUN_Y EQU $F601
VEC_PATTERN EQU $C829
Obj_Will_Hit_u EQU $F8E5
Sound_Byte_raw EQU $F25B
DOT_IX_B EQU $F2BE
PRINT_SHIPS_X EQU $F391
VEC_MUSIC_WK_A EQU $C842
Random EQU $F517
MOD16.M16_LOOP EQU $410A
MUSIC7 EQU $FEC6
MUSIC2 EQU $FD1D
VEC_BUTTON_2_1 EQU $C816
Compare_Score EQU $F8C7
JOY_DIGITAL EQU $F1F8
VEC_BUTTON_1_3 EQU $C814
VECTREX_PRINT_NUMBER.PN_D100 EQU $407E
Vec_Str_Ptr EQU $C82C
VEC_JOY_MUX_1_Y EQU $C820
DEC_3_COUNTERS EQU $F55A
MOVETO_X_7F EQU $F2F2
DELAY_1 EQU $F575
Vec_Cold_Flag EQU $CBFE
Check0Ref EQU $F34F
DRAW_VLP EQU $F410
Mov_Draw_VLcs EQU $F3B5
RANDOM_3 EQU $F511
Vec_Num_Game EQU $C87A
VEC_BTN_STATE EQU $C80F
Draw_VLp_7F EQU $F408
Vec_Buttons EQU $C811
Vec_Button_2_4 EQU $C819
Vec_Joy_Mux_1_Y EQU $C820
Draw_VLc EQU $F3CE
MUSICD EQU $FF8F
VEC_BRIGHTNESS EQU $C827
DRAW_PAT_VL EQU $F437
DELAY_2 EQU $F571
DP_to_D0 EQU $F1AA
music5 EQU $FE38
MOD16.M16_DPOS EQU $40F3
Moveto_d_7F EQU $F2FC
Vec_Snd_Shadow EQU $C800
Move_Mem_a EQU $F683
EXPLOSION_SND EQU $F92E
VEC_BUTTON_2_2 EQU $C817
GET_RISE_RUN EQU $F5EF
ADD_SCORE_A EQU $F85E
VEC_LOOP_COUNT EQU $C825
Draw_VLp EQU $F410
Dot_ix_b EQU $F2BE
VEC_MAX_GAMES EQU $C850
MOV_DRAW_VL EQU $F3BC
PRINT_LIST EQU $F38A
Vec_Expl_Chans EQU $C854
Vec_Rfrsh_lo EQU $C83D
COLD_START EQU $F000
Intensity_a EQU $F2AB
VEC_EXPL_4 EQU $C85B
Draw_VLcs EQU $F3D6
Rot_VL_Mode_a EQU $F61F
VEC_COUNTER_3 EQU $C830
Get_Rise_Run EQU $F5EF
PRINT_STR_YX EQU $F378
VEC_BUTTON_1_4 EQU $C815
Delay_b EQU $F57A
music4 EQU $FDD3
DRAW_PAT_VL_A EQU $F434
Get_Run_Idx EQU $F5DB
Vec_Counter_3 EQU $C830
VECTREX_PRINT_NUMBER.PN_DIV1000 EQU $4050
Dec_Counters EQU $F563
VEC_0REF_ENABLE EQU $C824
DEC_6_COUNTERS EQU $F55E
JOY_ANALOG EQU $F1F5
Print_Ships EQU $F393
Vec_Expl_ChanA EQU $C853
VEC_TEXT_HW EQU $C82A
VEC_JOY_1_X EQU $C81B
VEC_IRQ_VECTOR EQU $CBF8
Draw_Grid_VL EQU $FF9F
INTENSITY_3F EQU $F2A1
Vec_Pattern EQU $C829
Sound_Bytes_x EQU $F284
VECTREX_PRINT_NUMBER.PN_AFTER_CONVERT EQU $40A9
Do_Sound_x EQU $F28C
STRIP_ZEROS EQU $F8B7
DELAY_0 EQU $F579
VEC_MUSIC_TWANG EQU $C858
CLEAR_SOUND EQU $F272
Vec_Random_Seed EQU $C87D
INIT_MUSIC_BUF EQU $F533
Vec_Max_Players EQU $C84F
Moveto_d EQU $F312
Explosion_Snd EQU $F92E
VEC_MUSIC_FREQ EQU $C861
Vec_Expl_Chan EQU $C85C
MOVETO_IX EQU $F310
ABS_B EQU $F58B
Print_List EQU $F38A
Vec_NMI_Vector EQU $CBFB
DRAW_VLP_FF EQU $F404
VEC_NMI_VECTOR EQU $CBFB
Vec_Expl_1 EQU $C858
MUSICC EQU $FF7A
Dot_ix EQU $F2C1
SOUND_BYTE EQU $F256
MOVE_MEM_A_1 EQU $F67F
ROT_VL_DFT EQU $F637
INTENSITY_7F EQU $F2A9
VEC_RISERUN_LEN EQU $C83B
Vec_Music_Freq EQU $C861
VEC_EXPL_CHAN EQU $C85C
INIT_OS_RAM EQU $F164
VEC_JOY_1_Y EQU $C81C
Vec_Counter_1 EQU $C82E
Vec_Music_Chan EQU $C855
Vec_Btn_State EQU $C80F
DRAW_VLC EQU $F3CE
New_High_Score EQU $F8D8
Reset_Pen EQU $F35B
INTENSITY_A EQU $F2AB
Vec_IRQ_Vector EQU $CBF8
Vec_Joy_Mux_2_Y EQU $C822
Mov_Draw_VL_b EQU $F3B1
DELAY_RTS EQU $F57D
Dot_List EQU $F2D5
musicc EQU $FF7A
COMPARE_SCORE EQU $F8C7
Delay_3 EQU $F56D
Sound_Bytes EQU $F27D
Reset0Ref_D0 EQU $F34A
VEC_RFRSH EQU $C83D
Init_VIA EQU $F14C
VEC_FIRQ_VECTOR EQU $CBF5
Rot_VL_Mode EQU $F62B
Xform_Run_a EQU $F65B
Vec_Expl_ChanB EQU $C85D
RESET0REF_D0 EQU $F34A
VEC_EXPL_2 EQU $C859
DO_SOUND_X EQU $F28C
Draw_VLp_FF EQU $F404
RESET_PEN EQU $F35B
ROT_VL_AB EQU $F610
Rot_VL_ab EQU $F610
MOV_DRAW_VLCS EQU $F3B5
VEC_COLD_FLAG EQU $CBFE
VEC_TWANG_TABLE EQU $C851
MOVE_MEM_A EQU $F683
Sound_Byte_x EQU $F259
ROT_VL EQU $F616
DRAW_GRID_VL EQU $FF9F
Vec_Duration EQU $C857
DP_to_C8 EQU $F1AF
RECALIBRATE EQU $F2E6
VEC_HIGH_SCORE EQU $CBEB
Vec_FIRQ_Vector EQU $CBF5
Vec_Music_Flag EQU $C856
Vec_Max_Games EQU $C850
Print_List_hw EQU $F385
MOV_DRAW_VL_AB EQU $F3B7
VEC_JOY_2_X EQU $C81D
Vec_Misc_Count EQU $C823
MOD16.M16_RPOS EQU $410A
music3 EQU $FD81
Vec_Joy_Resltn EQU $C81A
Vec_Freq_Table EQU $C84D
VEC_PREV_BTNS EQU $C810
VEC_DURATION EQU $C857
Rise_Run_Y EQU $F601
VEC_SND_SHADOW EQU $C800
Dec_3_Counters EQU $F55A
CLEAR_X_B_A EQU $F552
Vec_Default_Stk EQU $CBEA
NEW_HIGH_SCORE EQU $F8D8
Dot_d EQU $F2C3
Add_Score_a EQU $F85E
Vec_ADSR_Timers EQU $C85E
Vec_Loop_Count EQU $C825
Vec_Button_1_3 EQU $C814
Reset0Int EQU $F36B
SOUND_BYTES EQU $F27D
Xform_Rise_a EQU $F661
DP_TO_D0 EQU $F1AA
VEC_COUNTER_1 EQU $C82E
WARM_START EQU $F06C
DRAW_LINE_D EQU $F3DF
Print_Str_hwyx EQU $F373
SELECT_GAME EQU $F7A9
VEC_DOT_DWELL EQU $C828
Moveto_x_7F EQU $F2F2
Vec_RiseRun_Tmp EQU $C834
MUSIC1 EQU $FD0D
Clear_x_b_a EQU $F552
Vec_Joy_Mux EQU $C81F
MOVETO_IX_FF EQU $F308
Draw_VLp_b EQU $F40E
VEC_MUSIC_WK_7 EQU $C845
Abs_a_b EQU $F584
Draw_VL_a EQU $F3DA
Warm_Start EQU $F06C
VEC_JOY_RESLTN EQU $C81A
Moveto_ix_FF EQU $F308
Delay_2 EQU $F571
INIT_VIA EQU $F14C
Read_Btns EQU $F1BA
Select_Game EQU $F7A9
Sound_Byte EQU $F256
Print_Str_yx EQU $F378
Vec_Expl_4 EQU $C85B
Vec_High_Score EQU $CBEB
DELAY_3 EQU $F56D
VEC_JOY_MUX_2_X EQU $C821
Vec_Joy_2_Y EQU $C81E
Clear_x_b_80 EQU $F550
INIT_MUSIC_CHK EQU $F687
Moveto_ix EQU $F310
Init_Music_chk EQU $F687
VEC_SWI2_VECTOR EQU $CBF2
Vec_Button_1_2 EQU $C813
Vec_Expl_2 EQU $C859
Dec_6_Counters EQU $F55E
XFORM_RUN EQU $F65D
INTENSITY_5F EQU $F2A5
Vec_SWI3_Vector EQU $CBF2
VEC_EXPL_3 EQU $C85A
Vec_Joy_Mux_2_X EQU $C821
Dot_List_Reset EQU $F2DE
INIT_MUSIC EQU $F68D
RISE_RUN_X EQU $F5FF
VEC_EXPL_FLAG EQU $C867
VEC_RISE_INDEX EQU $C839
Mov_Draw_VL_a EQU $F3B9
Mov_Draw_VL EQU $F3BC
Vec_0Ref_Enable EQU $C824
Clear_x_256 EQU $F545
VEC_RANDOM_SEED EQU $C87D
VEC_COUNTER_4 EQU $C831
VEC_BUTTON_1_2 EQU $C813
Init_Music_x EQU $F692
Bitmask_a EQU $F57E
Draw_Pat_VL_d EQU $F439
MOD16.M16_END EQU $411A
Rot_VL EQU $F616
Vec_Rfrsh_hi EQU $C83E
DRAW_VL_AB EQU $F3D8
Clear_x_d EQU $F548
DELAY_B EQU $F57A
VEC_JOY_MUX_1_X EQU $C81F
OBJ_HIT EQU $F8FF
musica EQU $FF44
PRINT_TEXT_STR_61805355484 EQU $412A
INIT_OS EQU $F18B
DOT_LIST_RESET EQU $F2DE
Init_OS_RAM EQU $F164
Dot_here EQU $F2C5
Vec_Run_Index EQU $C837
MUSIC4 EQU $FDD3
Vec_Text_Width EQU $C82B
RISE_RUN_ANGLE EQU $F593
Moveto_ix_7F EQU $F30C
Reset0Ref EQU $F354
VEC_MUSIC_FLAG EQU $C856
Clear_C8_RAM EQU $F542
VECTREX_PRINT_NUMBER.PN_L100 EQU $406C
Draw_VL_mode EQU $F46E
Vec_Num_Players EQU $C879
Intensity_5F EQU $F2A5
Print_List_chk EQU $F38C
musicb EQU $FF62
Vec_Counter_6 EQU $C833
VEC_COUNTERS EQU $C82E
Joy_Digital EQU $F1F8
GET_RUN_IDX EQU $F5DB
Vec_Joy_1_X EQU $C81B
Vec_Expl_Flag EQU $C867
VEC_MUSIC_WK_6 EQU $C846
Print_Str_d EQU $F37A
PRINT_SHIPS EQU $F393
VEC_EXPL_CHANB EQU $C85D
SOUND_BYTE_X EQU $F259
VEC_EXPL_CHANA EQU $C853
DEC_COUNTERS EQU $F563
Vec_Music_Wk_7 EQU $C845
VEC_DEFAULT_STK EQU $CBEA
MOD16.M16_RCHECK EQU $40FB
DRAW_VLP_SCALE EQU $F40C
Read_Btns_Mask EQU $F1B4
Vec_Text_Height EQU $C82A
Delay_1 EQU $F575
READ_BTNS EQU $F1BA
CHECK0REF EQU $F34F
Init_OS EQU $F18B
Vec_Prev_Btns EQU $C810
DRAW_PAT_VL_D EQU $F439
Vec_Twang_Table EQU $C851
music2 EQU $FD1D
music6 EQU $FE76
VEC_ADSR_TIMERS EQU $C85E
PRINT_LIST_CHK EQU $F38C
Obj_Will_Hit EQU $F8F3
Strip_Zeros EQU $F8B7
VEC_BUTTON_2_4 EQU $C819
Random_3 EQU $F511
PRINT_STR_HWYX EQU $F373
MUSICB EQU $FF62
Init_Music_Buf EQU $F533
VEC_COUNTER_2 EQU $C82F
VECTREX_PRINT_NUMBER.PN_L10 EQU $4086
RESET0REF EQU $F354
VEC_TEXT_HEIGHT EQU $C82A
DRAW_VL_B EQU $F3D2
VEC_MUSIC_PTR EQU $C853
MOVETO_IX_A EQU $F30E
Rise_Run_X EQU $F5FF
VEC_MAX_PLAYERS EQU $C84F
VEC_SEED_PTR EQU $C87B
DRAW_VLP_B EQU $F40E
XFORM_RISE_A EQU $F661
Vec_Expl_Timer EQU $C877
Vec_Music_Wk_5 EQU $C847
DRAW_VL_MODE EQU $F46E
Vec_Counter_2 EQU $C82F
MUSIC9 EQU $FF26
VEC_SWI_VECTOR EQU $CBFB
Do_Sound EQU $F289
Vec_Seed_Ptr EQU $C87B
Set_Refresh EQU $F1A2
MOV_DRAW_VL_A EQU $F3B9
Print_Str EQU $F495
Add_Score_d EQU $F87C
Vec_Brightness EQU $C827
VEC_JOY_MUX EQU $C81F
music7 EQU $FEC6
DOT_HERE EQU $F2C5
VECTREX_PRINT_NUMBER.PN_D1000 EQU $4064
VEC_JOY_2_Y EQU $C81E
Clear_Score EQU $F84F
Vec_Music_Twang EQU $C858
Mov_Draw_VL_ab EQU $F3B7
OBJ_WILL_HIT EQU $F8F3
Vec_Music_Ptr EQU $C853
Init_Music EQU $F68D
VEC_BUTTON_2_3 EQU $C818
VECTREX_PRINT_TEXT EQU $4000
VEC_STR_PTR EQU $C82C
Draw_VL_b EQU $F3D2
CLEAR_X_256 EQU $F545
VEC_EXPL_1 EQU $C858
VEC_MUSIC_WK_1 EQU $C84B
Vec_Angle EQU $C836
ABS_A_B EQU $F584
Draw_Pat_VL EQU $F437
XFORM_RUN_A EQU $F65B
CLEAR_X_B EQU $F53F
MOVETO_D_7F EQU $F2FC
VEC_FREQ_TABLE EQU $C84D
PRINT_STR_D EQU $F37A
music8 EQU $FEF8
Move_Mem_a_1 EQU $F67F
Rot_VL_dft EQU $F637
Vec_Text_HW EQU $C82A
Draw_VLp_scale EQU $F40C
Moveto_ix_a EQU $F30E
Vec_Joy_Mux_1_X EQU $C81F
Vec_Button_1_4 EQU $C815
Draw_VL EQU $F3DD
MUSIC6 EQU $FE76
PRINT_TEXT_STR_61790933023797 EQU $4132
VEC_SWI3_VECTOR EQU $CBF2
Print_Ships_x EQU $F391
DRAW_VLCS EQU $F3D6
Clear_Sound EQU $F272
Vec_RiseRun_Len EQU $C83B
Vec_Rise_Index EQU $C839
DOT_LIST EQU $F2D5
Vec_Music_Wk_A EQU $C842
Vec_SWI2_Vector EQU $CBF2
VECTREX_PRINT_NUMBER EQU $4030
DO_SOUND EQU $F289
MOV_DRAW_VLC_A EQU $F3AD
VEC_EXPL_CHANS EQU $C854
MUSIC3 EQU $FD81
VEC_RISERUN_TMP EQU $C834
Draw_Pat_VL_a EQU $F434
music9 EQU $FF26
Intensity_3F EQU $F2A1
VEC_RFRSH_LO EQU $C83D
Vec_Joy_2_X EQU $C81D
musicd EQU $FF8F
RANDOM EQU $F517
Vec_SWI_Vector EQU $CBFB
MUSIC8 EQU $FEF8
GET_RISE_IDX EQU $F5D9
SOUND_BYTES_X EQU $F284
CLEAR_X_D EQU $F548
READ_BTNS_MASK EQU $F1B4
Delay_0 EQU $F579
music1 EQU $FD0D
VEC_MUSIC_WK_5 EQU $C847
CLEAR_X_B_80 EQU $F550
MOV_DRAW_VL_D EQU $F3BE
VEC_EXPL_TIMER EQU $C877
Vec_Joy_1_Y EQU $C81C
VEC_RUN_INDEX EQU $C837
VEC_MUSIC_WORK EQU $C83F
VECTREX_PRINT_NUMBER.PN_L1000 EQU $4052
Vec_Music_Wk_6 EQU $C846
Draw_VL_ab EQU $F3D8
VEC_COUNTER_6 EQU $C833
DRAW_VL EQU $F3DD
VEC_RFRSH_HI EQU $C83E
Cold_Start EQU $F000
Vec_Button_2_2 EQU $C817
VEC_TEXT_WIDTH EQU $C82B
SOUND_BYTE_RAW EQU $F25B
DP_TO_C8 EQU $F1AF
VEC_ADSR_TABLE EQU $C84F
DRAW_VLP_7F EQU $F408
Recalibrate EQU $F2E6
Xform_Rise EQU $F663
PRINT_LIST_HW EQU $F385
Draw_Line_d EQU $F3DF
MOD16.M16_DONE EQU $4129
Vec_Counters EQU $C82E
Intensity_7F EQU $F2A9
MOVETO_D EQU $F312
OBJ_WILL_HIT_U EQU $F8E5
VEC_NUM_GAME EQU $C87A
RISE_RUN_LEN EQU $F603
INTENSITY_1F EQU $F29D
VEC_MUSIC_CHAN EQU $C855
DOT_IX EQU $F2C1
Vec_Button_2_3 EQU $C818
Vec_ADSR_Table EQU $C84F
MUSIC5 EQU $FE38
MOV_DRAW_VL_B EQU $F3B1
XFORM_RISE EQU $F663


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "PRINT_NUMBER"
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
VAR_COUNTER          EQU $C880+$2A   ; User variable: COUNTER (2 bytes)
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
    LDD #0
    STD VAR_COUNTER
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
    STD VAR_COUNTER

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    ; PRINT_TEXT: Print text at position
    LDD #-80
    STD VAR_ARG0
    LDD #0
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_61805355484      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #30
    STD VAR_ARG0    ; X position
    LDD #0
    STD VAR_ARG1    ; Y position
    LDD >VAR_COUNTER
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-80
    STD VAR_ARG0
    LDD #-30
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_61790933023797      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #30
    STD VAR_ARG0    ; X position
    LDD #-30
    STD VAR_ARG1    ; Y position
    LDD #9999
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    LDD >VAR_COUNTER
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_COUNTER
    RTS


; ================================================
