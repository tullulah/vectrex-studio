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
VAR_COUNTER          EQU $C880+$2A   ; User variable: counter (2 bytes)
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
VEC_EXPL_CHAN EQU $C85C
Intensity_5F EQU $F2A5
VEC_BUTTON_1_4 EQU $C815
PRINT_LIST EQU $F38A
CHECK0REF EQU $F34F
Vec_Seed_Ptr EQU $C87B
VEC_RANDOM_SEED EQU $C87D
MUSIC7 EQU $FEC6
Vec_Music_Ptr EQU $C853
VEC_MUSIC_PTR EQU $C853
VEC_TWANG_TABLE EQU $C851
DOT_LIST EQU $F2D5
SOUND_BYTES_X EQU $F284
JOY_ANALOG EQU $F1F5
Vec_Joy_Mux_1_X EQU $C81F
VEC_BUTTON_2_1 EQU $C816
Draw_VLp EQU $F410
MUSIC9 EQU $FF26
ROT_VL_DFT EQU $F637
Vec_Counter_5 EQU $C832
VEC_MUSIC_FLAG EQU $C856
VEC_MISC_COUNT EQU $C823
RESET_PEN EQU $F35B
Vec_Misc_Count EQU $C823
VEC_JOY_MUX_2_X EQU $C821
VEC_MUSIC_FREQ EQU $C861
INIT_OS EQU $F18B
VEC_COUNTER_6 EQU $C833
VEC_NMI_VECTOR EQU $CBFB
PRINT_SHIPS EQU $F393
Vec_Dot_Dwell EQU $C828
VEC_RUN_INDEX EQU $C837
VEC_RISERUN_TMP EQU $C834
MUSICD EQU $FF8F
DEC_3_COUNTERS EQU $F55A
VEC_EXPL_2 EQU $C859
PRINT_STR_D EQU $F37A
Abs_b EQU $F58B
Vec_Text_Width EQU $C82B
Vec_Button_2_2 EQU $C817
music4 EQU $FDD3
MOD16.M16_RCHECK EQU $40FB
Dot_d EQU $F2C3
Vec_Joy_Resltn EQU $C81A
DRAW_LINE_D EQU $F3DF
VEC_RISE_INDEX EQU $C839
Vec_Music_Twang EQU $C858
Do_Sound EQU $F289
Draw_VL_ab EQU $F3D8
VEC_JOY_MUX_1_Y EQU $C820
XFORM_RUN EQU $F65D
INIT_MUSIC EQU $F68D
DELAY_1 EQU $F575
VEC_MAX_PLAYERS EQU $C84F
Vec_Btn_State EQU $C80F
VEC_ADSR_TABLE EQU $C84F
Vec_Joy_Mux_2_X EQU $C821
music8 EQU $FEF8
CLEAR_C8_RAM EQU $F542
COLD_START EQU $F000
Draw_VLp_b EQU $F40E
Vec_Music_Wk_5 EQU $C847
VEC_ADSR_TIMERS EQU $C85E
Sound_Bytes EQU $F27D
Add_Score_d EQU $F87C
Vec_Loop_Count EQU $C825
RISE_RUN_LEN EQU $F603
Dec_3_Counters EQU $F55A
SOUND_BYTES EQU $F27D
Obj_Hit EQU $F8FF
Init_Music_x EQU $F692
Delay_1 EQU $F575
Vec_Music_Work EQU $C83F
Vec_Expl_Chan EQU $C85C
VEC_SWI3_VECTOR EQU $CBF2
Vec_Counter_4 EQU $C831
Vec_Random_Seed EQU $C87D
MOVE_MEM_A_1 EQU $F67F
DOT_HERE EQU $F2C5
MOD16.M16_RPOS EQU $410A
Vec_ADSR_Timers EQU $C85E
Vec_Rfrsh_lo EQU $C83D
INIT_VIA EQU $F14C
VEC_SND_SHADOW EQU $C800
RESET0REF_D0 EQU $F34A
INIT_OS_RAM EQU $F164
CLEAR_SCORE EQU $F84F
MOV_DRAW_VLC_A EQU $F3AD
READ_BTNS EQU $F1BA
VEC_EXPL_1 EQU $C858
Vec_Counter_2 EQU $C82F
Vec_Angle EQU $C836
RISE_RUN_ANGLE EQU $F593
Vec_Expl_Flag EQU $C867
MUSICA EQU $FF44
MOVETO_D EQU $F312
VEC_PATTERN EQU $C829
Vec_Counter_6 EQU $C833
DELAY_3 EQU $F56D
Vec_Expl_ChanA EQU $C853
Moveto_d_7F EQU $F2FC
ADD_SCORE_D EQU $F87C
VECTREX_PRINT_NUMBER.PN_L1000 EQU $4052
DRAW_VLP_7F EQU $F408
Get_Run_Idx EQU $F5DB
Vec_Expl_ChanB EQU $C85D
Compare_Score EQU $F8C7
MOV_DRAW_VL_A EQU $F3B9
MOD16.M16_LOOP EQU $410A
VEC_JOY_MUX_2_Y EQU $C822
SET_REFRESH EQU $F1A2
Intensity_a EQU $F2AB
Init_Music EQU $F68D
VEC_EXPL_FLAG EQU $C867
Draw_VLcs EQU $F3D6
Recalibrate EQU $F2E6
Print_Str_hwyx EQU $F373
MUSICC EQU $FF7A
Vec_Counter_3 EQU $C830
JOY_DIGITAL EQU $F1F8
MUSIC2 EQU $FD1D
Vec_0Ref_Enable EQU $C824
DP_TO_C8 EQU $F1AF
musicc EQU $FF7A
Draw_Pat_VL EQU $F437
Mov_Draw_VL_ab EQU $F3B7
Warm_Start EQU $F06C
VEC_COUNTER_3 EQU $C830
BITMASK_A EQU $F57E
Vec_Max_Games EQU $C850
Bitmask_a EQU $F57E
CLEAR_X_B_A EQU $F552
PRINT_SHIPS_X EQU $F391
PRINT_TEXT_STR_61805355484 EQU $412A
VEC_DURATION EQU $C857
VEC_LOOP_COUNT EQU $C825
Vec_Num_Game EQU $C87A
Dot_ix_b EQU $F2BE
VEC_BUTTONS EQU $C811
DOT_IX_B EQU $F2BE
Vec_Button_2_3 EQU $C818
DRAW_VLCS EQU $F3D6
VEC_FIRQ_VECTOR EQU $CBF5
Moveto_ix EQU $F310
Draw_Pat_VL_d EQU $F439
VEC_BUTTON_2_3 EQU $C818
VEC_JOY_MUX EQU $C81F
Print_List_hw EQU $F385
RISE_RUN_X EQU $F5FF
Vec_Joy_2_X EQU $C81D
VEC_SWI2_VECTOR EQU $CBF2
VEC_NUM_PLAYERS EQU $C879
VEC_JOY_MUX_1_X EQU $C81F
DOT_LIST_RESET EQU $F2DE
Vec_Music_Wk_1 EQU $C84B
VEC_MUSIC_WK_5 EQU $C847
SOUND_BYTE_X EQU $F259
Vec_Max_Players EQU $C84F
Vec_Button_1_3 EQU $C814
DRAW_VLP EQU $F410
Sound_Byte_raw EQU $F25B
Draw_VLp_FF EQU $F404
XFORM_RUN_A EQU $F65B
Clear_x_256 EQU $F545
music5 EQU $FE38
DRAW_VLP_FF EQU $F404
VECTREX_PRINT_NUMBER.PN_D10 EQU $4098
PRINT_STR_HWYX EQU $F373
Vec_Joy_1_X EQU $C81B
OBJ_WILL_HIT EQU $F8F3
Vec_Button_2_1 EQU $C816
ROT_VL_AB EQU $F610
MOD16.M16_DPOS EQU $40F3
Delay_3 EQU $F56D
DRAW_VL_B EQU $F3D2
Check0Ref EQU $F34F
music7 EQU $FEC6
Vec_Music_Freq EQU $C861
Vec_Expl_Timer EQU $C877
VECTREX_PRINT_NUMBER.PN_L10 EQU $4086
VECTREX_PRINT_NUMBER.PN_D100 EQU $407E
DRAW_VL_A EQU $F3DA
Delay_RTS EQU $F57D
GET_RISE_IDX EQU $F5D9
VEC_RFRSH_HI EQU $C83E
Vec_Expl_4 EQU $C85B
Vec_Music_Flag EQU $C856
Reset0Ref_D0 EQU $F34A
MOVE_MEM_A EQU $F683
RESET0REF EQU $F354
Vec_NMI_Vector EQU $CBFB
VEC_MUSIC_WORK EQU $C83F
ABS_B EQU $F58B
Xform_Rise_a EQU $F661
Vec_Rfrsh_hi EQU $C83E
Init_VIA EQU $F14C
INIT_MUSIC_BUF EQU $F533
MUSICB EQU $FF62
VEC_TEXT_HEIGHT EQU $C82A
Vec_High_Score EQU $CBEB
VEC_MUSIC_CHAN EQU $C855
Dot_here EQU $F2C5
Print_List EQU $F38A
VEC_0REF_ENABLE EQU $C824
MOVETO_IX EQU $F310
VEC_DEFAULT_STK EQU $CBEA
Vec_Run_Index EQU $C837
SOUND_BYTE_RAW EQU $F25B
Delay_2 EQU $F571
VEC_BUTTON_1_2 EQU $C813
MUSIC1 EQU $FD0D
Xform_Run_a EQU $F65B
MUSIC3 EQU $FD81
Vec_FIRQ_Vector EQU $CBF5
INIT_MUSIC_CHK EQU $F687
Print_Ships_x EQU $F391
VEC_BRIGHTNESS EQU $C827
Vec_Rfrsh EQU $C83D
Vec_Music_Wk_A EQU $C842
VEC_COUNTER_2 EQU $C82F
Vec_Expl_Chans EQU $C854
Moveto_ix_a EQU $F30E
Vec_Rise_Index EQU $C839
Vec_Snd_Shadow EQU $C800
VEC_JOY_2_X EQU $C81D
DRAW_PAT_VL EQU $F437
CLEAR_X_256 EQU $F545
New_High_Score EQU $F8D8
Clear_Sound EQU $F272
Mov_Draw_VLc_a EQU $F3AD
Sound_Byte EQU $F256
Clear_C8_RAM EQU $F542
Vec_Music_Wk_7 EQU $C845
PRINT_LIST_HW EQU $F385
Dec_Counters EQU $F563
Vec_Joy_Mux_1_Y EQU $C820
STRIP_ZEROS EQU $F8B7
Move_Mem_a_1 EQU $F67F
Dot_List EQU $F2D5
RANDOM EQU $F517
DP_TO_D0 EQU $F1AA
music6 EQU $FE76
Rot_VL_Mode_a EQU $F61F
VEC_BUTTON_1_1 EQU $C812
VEC_COUNTERS EQU $C82E
Draw_VLc EQU $F3CE
Clear_x_b_80 EQU $F550
WAIT_RECAL EQU $F192
Clear_x_b EQU $F53F
Draw_VLp_scale EQU $F40C
Vec_Freq_Table EQU $C84D
Draw_VL_a EQU $F3DA
GET_RISE_RUN EQU $F5EF
Delay_0 EQU $F579
Vec_Joy_Mux EQU $C81F
VEC_BTN_STATE EQU $C80F
VEC_PREV_BTNS EQU $C810
music3 EQU $FD81
Rot_VL EQU $F616
musica EQU $FF44
Init_Music_Buf EQU $F533
Vec_Cold_Flag EQU $CBFE
Clear_Score EQU $F84F
INTENSITY_A EQU $F2AB
Rot_VL_ab EQU $F610
Draw_Pat_VL_a EQU $F434
RECALIBRATE EQU $F2E6
VEC_BUTTON_2_4 EQU $C819
DELAY_B EQU $F57A
VEC_RFRSH_LO EQU $C83D
VEC_EXPL_3 EQU $C85A
Dec_6_Counters EQU $F55E
Mov_Draw_VL_d EQU $F3BE
VEC_BUTTON_1_3 EQU $C814
DO_SOUND EQU $F289
Vec_RiseRun_Len EQU $C83B
DRAW_PAT_VL_A EQU $F434
OBJ_WILL_HIT_U EQU $F8E5
Rot_VL_Mode EQU $F62B
VEC_TEXT_HW EQU $C82A
Clear_x_d EQU $F548
DRAW_VLP_SCALE EQU $F40C
Do_Sound_x EQU $F28C
Move_Mem_a EQU $F683
PRINT_STR EQU $F495
Vec_Num_Players EQU $C879
Vec_SWI3_Vector EQU $CBF2
DRAW_VL EQU $F3DD
Rise_Run_Y EQU $F601
Vec_SWI_Vector EQU $CBFB
VEC_JOY_1_Y EQU $C81C
XFORM_RISE EQU $F663
Joy_Analog EQU $F1F5
VEC_MUSIC_WK_A EQU $C842
DEC_6_COUNTERS EQU $F55E
Vec_Counters EQU $C82E
Vec_Joy_Mux_2_Y EQU $C822
VECTREX_PRINT_NUMBER.PN_AFTER_CONVERT EQU $40A9
Mov_Draw_VL_a EQU $F3B9
Intensity_3F EQU $F2A1
music9 EQU $FF26
PRINT_TEXT_STR_61790933023797 EQU $4132
SOUND_BYTE EQU $F256
Init_OS_RAM EQU $F164
Vec_Str_Ptr EQU $C82C
VEC_DOT_DWELL EQU $C828
VEC_IRQ_VECTOR EQU $CBF8
DP_to_C8 EQU $F1AF
VEC_MUSIC_WK_6 EQU $C846
ABS_A_B EQU $F584
DRAW_VL_AB EQU $F3D8
Draw_Grid_VL EQU $FF9F
SELECT_GAME EQU $F7A9
VEC_NUM_GAME EQU $C87A
Delay_b EQU $F57A
Vec_Text_Height EQU $C82A
DRAW_VL_MODE EQU $F46E
VEC_COUNTER_4 EQU $C831
Vec_Expl_3 EQU $C85A
Xform_Rise EQU $F663
MOD16.M16_END EQU $411A
Reset0Int EQU $F36B
Vec_Prev_Btns EQU $C810
Random_3 EQU $F511
ADD_SCORE_A EQU $F85E
Add_Score_a EQU $F85E
READ_BTNS_MASK EQU $F1B4
Vec_Button_2_4 EQU $C819
DP_to_D0 EQU $F1AA
DRAW_VLC EQU $F3CE
Obj_Will_Hit_u EQU $F8E5
INIT_MUSIC_X EQU $F692
Vec_Buttons EQU $C811
OBJ_HIT EQU $F8FF
MOD16.M16_DONE EQU $4129
Vec_Music_Wk_6 EQU $C846
Reset0Ref EQU $F354
Intensity_7F EQU $F2A9
MOV_DRAW_VL EQU $F3BC
DRAW_PAT_VL_D EQU $F439
CLEAR_X_B EQU $F53F
INTENSITY_5F EQU $F2A5
Rise_Run_X EQU $F5FF
Vec_Button_1_1 EQU $C812
Draw_VL EQU $F3DD
INTENSITY_7F EQU $F2A9
Rot_VL_dft EQU $F637
Print_Ships EQU $F393
PRINT_STR_YX EQU $F378
VECTREX_PRINT_NUMBER.PN_DIV1000 EQU $4050
MOD16 EQU $40D6
Read_Btns EQU $F1BA
Init_OS EQU $F18B
NEW_HIGH_SCORE EQU $F8D8
VEC_BUTTON_2_2 EQU $C817
MOV_DRAW_VL_B EQU $F3B1
Mov_Draw_VLcs EQU $F3B5
Vec_ADSR_Table EQU $C84F
VEC_EXPL_TIMER EQU $C877
Draw_VL_b EQU $F3D2
Draw_Line_d EQU $F3DF
DELAY_0 EQU $F579
Vec_Default_Stk EQU $CBEA
VEC_COUNTER_5 EQU $C832
RESET0INT EQU $F36B
VEC_RISERUN_LEN EQU $C83B
Rise_Run_Angle EQU $F593
Sound_Byte_x EQU $F259
CLEAR_SOUND EQU $F272
Vec_IRQ_Vector EQU $CBF8
Vec_Brightness EQU $C827
Vec_Expl_1 EQU $C858
DEC_COUNTERS EQU $F563
Moveto_ix_FF EQU $F308
Abs_a_b EQU $F584
Get_Rise_Idx EQU $F5D9
INTENSITY_1F EQU $F29D
DELAY_RTS EQU $F57D
Intensity_1F EQU $F29D
VEC_ANGLE EQU $C836
Explosion_Snd EQU $F92E
ROT_VL_MODE_A EQU $F61F
Print_Str_yx EQU $F378
Select_Game EQU $F7A9
WARM_START EQU $F06C
MOVETO_D_7F EQU $F2FC
Xform_Run EQU $F65D
Strip_Zeros EQU $F8B7
Draw_VL_mode EQU $F46E
VEC_EXPL_CHANB EQU $C85D
VEC_EXPL_CHANA EQU $C853
Set_Refresh EQU $F1A2
VEC_JOY_2_Y EQU $C81E
Vec_Button_1_2 EQU $C813
VECTREX_PRINT_NUMBER EQU $4030
RANDOM_3 EQU $F511
Vec_Twang_Table EQU $C851
VEC_SWI_VECTOR EQU $CBFB
DELAY_2 EQU $F571
Moveto_d EQU $F312
Sound_Bytes_x EQU $F284
CLEAR_X_B_80 EQU $F550
musicd EQU $FF8F
VEC_COLD_FLAG EQU $CBFE
Init_Music_chk EQU $F687
VEC_TEXT_WIDTH EQU $C82B
MUSIC6 EQU $FE76
Obj_Will_Hit EQU $F8F3
MUSIC4 EQU $FDD3
MUSIC5 EQU $FE38
Vec_Joy_2_Y EQU $C81E
musicb EQU $FF62
VEC_MAX_GAMES EQU $C850
MOVETO_IX_FF EQU $F308
music1 EQU $FD0D
INTENSITY_3F EQU $F2A1
VEC_FREQ_TABLE EQU $C84D
VECTREX_PRINT_NUMBER.PN_D1000 EQU $4064
ROT_VL EQU $F616
DRAW_VLP_B EQU $F40E
VEC_MUSIC_WK_7 EQU $C845
DOT_D EQU $F2C3
ROT_VL_MODE EQU $F62B
Print_List_chk EQU $F38C
music2 EQU $FD1D
CLEAR_X_D EQU $F548
COMPARE_SCORE EQU $F8C7
Print_Str EQU $F495
Vec_Joy_1_Y EQU $C81C
VEC_JOY_1_X EQU $C81B
Mov_Draw_VL_b EQU $F3B1
MOV_DRAW_VL_D EQU $F3BE
RISE_RUN_Y EQU $F601
Vec_Duration EQU $C857
Dot_ix EQU $F2C1
DOT_IX EQU $F2C1
MUSIC8 EQU $FEF8
Mov_Draw_VL EQU $F3BC
Clear_x_b_a EQU $F552
Vec_SWI2_Vector EQU $CBF2
MOV_DRAW_VLCS EQU $F3B5
XFORM_RISE_A EQU $F661
VEC_MUSIC_TWANG EQU $C858
MOV_DRAW_VL_AB EQU $F3B7
Vec_Counter_1 EQU $C82E
PRINT_LIST_CHK EQU $F38C
MOVETO_X_7F EQU $F2F2
VEC_STR_PTR EQU $C82C
Print_Str_d EQU $F37A
DRAW_GRID_VL EQU $FF9F
MOVETO_IX_7F EQU $F30C
Vec_RiseRun_Tmp EQU $C834
Dot_List_Reset EQU $F2DE
Draw_VLp_7F EQU $F408
Moveto_x_7F EQU $F2F2
Reset_Pen EQU $F35B
VEC_HIGH_SCORE EQU $CBEB
Vec_Pattern EQU $C829
VEC_COUNTER_1 EQU $C82E
VECTREX_PRINT_TEXT EQU $4000
VEC_EXPL_4 EQU $C85B
Vec_Expl_2 EQU $C859
Read_Btns_Mask EQU $F1B4
EXPLOSION_SND EQU $F92E
VEC_EXPL_CHANS EQU $C854
Random EQU $F517
VEC_MUSIC_WK_1 EQU $C84B
Vec_Text_HW EQU $C82A
MOVETO_IX_A EQU $F30E
Rise_Run_Len EQU $F603
VEC_JOY_RESLTN EQU $C81A
VEC_RFRSH EQU $C83D
Cold_Start EQU $F000
Vec_Button_1_4 EQU $C815
Vec_Music_Chan EQU $C855
Joy_Digital EQU $F1F8
Get_Rise_Run EQU $F5EF
Wait_Recal EQU $F192
DO_SOUND_X EQU $F28C
Moveto_ix_7F EQU $F30C
VEC_SEED_PTR EQU $C87B
GET_RUN_IDX EQU $F5DB
VECTREX_PRINT_NUMBER.PN_L100 EQU $406C


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
VAR_COUNTER          EQU $C880+$2A   ; User variable: counter (2 bytes)
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
