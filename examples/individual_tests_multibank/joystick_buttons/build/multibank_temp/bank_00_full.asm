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
DRAW_CIRCLE_XC       EQU $C880+$14   ; Circle center X (1 bytes)
DRAW_CIRCLE_YC       EQU $C880+$15   ; Circle center Y (1 bytes)
DRAW_CIRCLE_DIAM     EQU $C880+$16   ; Circle diameter (1 bytes)
DRAW_CIRCLE_INTENSITY EQU $C880+$17   ; Circle intensity (1 bytes)
DRAW_CIRCLE_RADIUS   EQU $C880+$18   ; Circle radius (diam/2) - used in segment drawing (1 bytes)
DRAW_CIRCLE_TEMP     EQU $C880+$19   ; Circle temporary buffer (8 bytes: radius16, a, b, c, d, --, --)  a=0.383r b=0.324r c=0.217r d=0.076r (8 bytes)
DRAW_LINE_ARGS       EQU $C880+$21   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$2B   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$2D   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$2F   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$30   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$31   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$33   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$35   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$36   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_BTN1             EQU $C880+$37   ; User variable: BTN1 (2 bytes)
VAR_BTN2             EQU $C880+$39   ; User variable: BTN2 (2 bytes)
VAR_BTN3             EQU $C880+$3B   ; User variable: BTN3 (2 bytes)
VAR_BTN4             EQU $C880+$3D   ; User variable: BTN4 (2 bytes)
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
VEC_JOY_MUX EQU $C81F
Read_Btns_Mask EQU $F1B4
VEC_MUSIC_CHAN EQU $C855
Mov_Draw_VLc_a EQU $F3AD
Vec_Music_Wk_5 EQU $C847
DCR_INTENSITY_5F EQU $415F
Vec_Music_Wk_7 EQU $C845
INTENSITY_3F EQU $F2A1
MUSICD EQU $FF8F
VEC_ANGLE EQU $C836
VEC_EXPL_CHANS EQU $C854
XFORM_RUN EQU $F65D
Vec_Counters EQU $C82E
DRAW_PAT_VL EQU $F437
DRAW_VLC EQU $F3CE
SOUND_BYTE EQU $F256
VEC_JOY_1_X EQU $C81B
RECALIBRATE EQU $F2E6
Xform_Rise EQU $F663
Rise_Run_X EQU $F5FF
Vec_Button_1_1 EQU $C812
MUSIC6 EQU $FE76
Init_OS_RAM EQU $F164
Vec_Counter_3 EQU $C830
INIT_MUSIC_X EQU $F692
NEW_HIGH_SCORE EQU $F8D8
VECTREX_PRINT_NUMBER.PN_D1000 EQU $4064
MOVE_MEM_A EQU $F683
Vec_RiseRun_Tmp EQU $C834
Reset0Int EQU $F36B
ROT_VL_DFT EQU $F637
CLEAR_X_256 EQU $F545
MOV_DRAW_VLC_A EQU $F3AD
Draw_Grid_VL EQU $FF9F
INIT_VIA EQU $F14C
INIT_OS EQU $F18B
DRAW_LINE_D EQU $F3DF
DRAW_VL_A EQU $F3DA
Print_Str_hwyx EQU $F373
VEC_ADSR_TABLE EQU $C84F
Draw_VLc EQU $F3CE
MOV_DRAW_VL_AB EQU $F3B7
Mov_Draw_VL_b EQU $F3B1
Dot_d EQU $F2C3
Rot_VL_ab EQU $F610
Vec_Expl_Chans EQU $C854
Init_Music EQU $F68D
OBJ_WILL_HIT EQU $F8F3
VEC_MUSIC_FLAG EQU $C856
Reset_Pen EQU $F35B
MOD16.M16_DONE EQU $4129
VECTREX_PRINT_NUMBER.PN_L10 EQU $4086
Vec_Rfrsh_lo EQU $C83D
PRINT_TEXT_STR_2049399 EQU $4279
VEC_RFRSH_HI EQU $C83E
Vec_IRQ_Vector EQU $CBF8
DRAW_VLP_FF EQU $F404
VEC_EXPL_CHANB EQU $C85D
VEC_MUSIC_PTR EQU $C853
Moveto_ix_a EQU $F30E
CLEAR_C8_RAM EQU $F542
DP_to_C8 EQU $F1AF
VEC_LOOP_COUNT EQU $C825
Joy_Digital EQU $F1F8
ABS_A_B EQU $F584
VEC_RISERUN_TMP EQU $C834
COMPARE_SCORE EQU $F8C7
Cold_Start EQU $F000
SOUND_BYTE_X EQU $F259
Vec_Freq_Table EQU $C84D
DOT_LIST_RESET EQU $F2DE
VEC_COUNTER_5 EQU $C832
Vec_Brightness EQU $C827
Delay_1 EQU $F575
MOVETO_IX EQU $F310
VEC_TWANG_TABLE EQU $C851
Vec_Pattern EQU $C829
Draw_VLp EQU $F410
Vec_Duration EQU $C857
Delay_RTS EQU $F57D
DOT_IX EQU $F2C1
Vec_Button_2_3 EQU $C818
XFORM_RISE EQU $F663
MUSIC7 EQU $FEC6
Vec_Expl_ChanA EQU $C853
DRAW_PAT_VL_D EQU $F439
Dec_Counters EQU $F563
Vec_Joy_Mux_2_Y EQU $C822
VEC_SWI2_VECTOR EQU $CBF2
VEC_MUSIC_FREQ EQU $C861
Obj_Will_Hit EQU $F8F3
DP_TO_C8 EQU $F1AF
Vec_Counter_2 EQU $C82F
MOVETO_X_7F EQU $F2F2
DOT_D EQU $F2C3
Xform_Rise_a EQU $F661
RANDOM EQU $F517
music1 EQU $FD0D
MUSIC9 EQU $FF26
JOY_DIGITAL EQU $F1F8
Xform_Run_a EQU $F65B
Vec_Expl_Timer EQU $C877
VEC_STR_PTR EQU $C82C
MUSIC5 EQU $FE38
VECTREX_PRINT_NUMBER.PN_L100 EQU $406C
Add_Score_d EQU $F87C
Vec_Misc_Count EQU $C823
RESET0REF_D0 EQU $F34A
JOY_ANALOG EQU $F1F5
Vec_Music_Twang EQU $C858
Moveto_d EQU $F312
VEC_RISE_INDEX EQU $C839
MOV_DRAW_VLCS EQU $F3B5
Vec_Btn_State EQU $C80F
PRINT_TEXT_STR_2049400 EQU $427E
VEC_EXPL_CHAN EQU $C85C
VEC_EXPL_CHANA EQU $C853
Mov_Draw_VL_d EQU $F3BE
Draw_VLp_b EQU $F40E
MOV_DRAW_VL EQU $F3BC
VEC_BUTTON_2_2 EQU $C817
Rot_VL_Mode EQU $F62B
Mov_Draw_VL_ab EQU $F3B7
VECTREX_PRINT_NUMBER.PN_L1000 EQU $4052
Set_Refresh EQU $F1A2
PRINT_STR_HWYX EQU $F373
Vec_Rise_Index EQU $C839
Vec_SWI_Vector EQU $CBFB
SOUND_BYTES EQU $F27D
Reset0Ref EQU $F354
Vec_Expl_1 EQU $C858
VEC_COUNTER_1 EQU $C82E
Vec_Expl_3 EQU $C85A
MOD16 EQU $40D6
Draw_VLcs EQU $F3D6
music2 EQU $FD1D
Vec_Joy_2_X EQU $C81D
musicd EQU $FF8F
INIT_OS_RAM EQU $F164
Move_Mem_a EQU $F683
Draw_Pat_VL_d EQU $F439
CLEAR_SCORE EQU $F84F
Get_Rise_Run EQU $F5EF
Warm_Start EQU $F06C
VEC_HIGH_SCORE EQU $CBEB
DRAW_VLCS EQU $F3D6
Clear_C8_RAM EQU $F542
DCR_after_intensity EQU $4162
GET_RISE_RUN EQU $F5EF
Vec_0Ref_Enable EQU $C824
Init_VIA EQU $F14C
Mov_Draw_VL EQU $F3BC
Clear_Score EQU $F84F
music9 EQU $FF26
RISE_RUN_Y EQU $F601
MOD16.M16_LOOP EQU $410A
ROT_VL EQU $F616
Vec_Counter_1 EQU $C82E
Vec_ADSR_Table EQU $C84F
Get_Rise_Idx EQU $F5D9
Compare_Score EQU $F8C7
Draw_VLp_scale EQU $F40C
VEC_RISERUN_LEN EQU $C83B
Vec_Expl_Flag EQU $C867
GET_RUN_IDX EQU $F5DB
music4 EQU $FDD3
Draw_VL_ab EQU $F3D8
VEC_DEFAULT_STK EQU $CBEA
Vec_Snd_Shadow EQU $C800
VEC_MUSIC_WK_5 EQU $C847
VEC_BUTTONS EQU $C811
VEC_COUNTER_6 EQU $C833
MOVETO_D_7F EQU $F2FC
DOT_LIST EQU $F2D5
VEC_RANDOM_SEED EQU $C87D
DP_TO_D0 EQU $F1AA
Vec_SWI3_Vector EQU $CBF2
RISE_RUN_ANGLE EQU $F593
Vec_Cold_Flag EQU $CBFE
SOUND_BYTE_RAW EQU $F25B
DRAW_VLP_B EQU $F40E
DRAW_VLP EQU $F410
VEC_SND_SHADOW EQU $C800
Read_Btns EQU $F1BA
DELAY_2 EQU $F571
VEC_BUTTON_2_4 EQU $C819
Vec_Music_Flag EQU $C856
VEC_MAX_GAMES EQU $C850
Draw_VL_mode EQU $F46E
VEC_JOY_MUX_2_Y EQU $C822
BITMASK_A EQU $F57E
VEC_JOY_MUX_2_X EQU $C821
ROT_VL_MODE_A EQU $F61F
Draw_Pat_VL_a EQU $F434
SOUND_BYTES_X EQU $F284
musica EQU $FF44
VEC_EXPL_FLAG EQU $C867
DCR_AFTER_INTENSITY EQU $4162
VEC_NUM_PLAYERS EQU $C879
Print_Ships_x EQU $F391
Vec_Expl_Chan EQU $C85C
PRINT_STR_D EQU $F37A
DELAY_1 EQU $F575
VEC_0REF_ENABLE EQU $C824
DEC_COUNTERS EQU $F563
Rise_Run_Len EQU $F603
Vec_Random_Seed EQU $C87D
Vec_Music_Work EQU $C83F
Intensity_5F EQU $F2A5
VEC_BUTTON_2_1 EQU $C816
Vec_Run_Index EQU $C837
VEC_DOT_DWELL EQU $C828
New_High_Score EQU $F8D8
MOD16.M16_DPOS EQU $40F3
MOVETO_D EQU $F312
Draw_Pat_VL EQU $F437
VEC_FIRQ_VECTOR EQU $CBF5
Vec_Dot_Dwell EQU $C828
Vec_Rfrsh_hi EQU $C83E
Vec_Joy_1_X EQU $C81B
Vec_Music_Wk_6 EQU $C846
INTENSITY_5F EQU $F2A5
music7 EQU $FEC6
Sound_Bytes EQU $F27D
Clear_x_b_80 EQU $F550
MUSICA EQU $FF44
VEC_JOY_MUX_1_Y EQU $C820
Vec_Expl_4 EQU $C85B
Bitmask_a EQU $F57E
Sound_Byte_x EQU $F259
VEC_EXPL_2 EQU $C859
Vec_SWI2_Vector EQU $CBF2
Clear_x_b_a EQU $F552
Vec_Text_Height EQU $C82A
INIT_MUSIC_BUF EQU $F533
VEC_MUSIC_WORK EQU $C83F
MUSIC4 EQU $FDD3
PRINT_TEXT_STR_2049397 EQU $426F
ADD_SCORE_D EQU $F87C
OBJ_HIT EQU $F8FF
Print_List_hw EQU $F385
Vec_High_Score EQU $CBEB
Clear_x_b EQU $F53F
DO_SOUND_X EQU $F28C
Explosion_Snd EQU $F92E
DCR_intensity_5F EQU $415F
XFORM_RISE_A EQU $F661
Print_List_chk EQU $F38C
DRAW_VLP_7F EQU $F408
VEC_EXPL_1 EQU $C858
Vec_Music_Freq EQU $C861
Delay_3 EQU $F56D
VEC_RUN_INDEX EQU $C837
Draw_VL_b EQU $F3D2
Delay_0 EQU $F579
INTENSITY_7F EQU $F2A9
Do_Sound EQU $F289
Vec_FIRQ_Vector EQU $CBF5
Wait_Recal EQU $F192
Print_List EQU $F38A
VEC_JOY_2_X EQU $C81D
Draw_VL_a EQU $F3DA
Random_3 EQU $F511
Vec_Buttons EQU $C811
Vec_Expl_ChanB EQU $C85D
VEC_JOY_1_Y EQU $C81C
READ_BTNS_MASK EQU $F1B4
Abs_a_b EQU $F584
Select_Game EQU $F7A9
Dot_ix_b EQU $F2BE
Vec_Button_2_1 EQU $C816
Rise_Run_Angle EQU $F593
VECTREX_PRINT_NUMBER.PN_D100 EQU $407E
Vec_Prev_Btns EQU $C810
Vec_Joy_Mux EQU $C81F
Vec_Rfrsh EQU $C83D
Vec_Num_Players EQU $C879
DELAY_3 EQU $F56D
DRAW_VL_B EQU $F3D2
VECTREX_PRINT_NUMBER.PN_D10 EQU $4098
VEC_DURATION EQU $C857
Init_Music_Buf EQU $F533
RESET0REF EQU $F354
MOVETO_IX_FF EQU $F308
Moveto_ix EQU $F310
Joy_Analog EQU $F1F5
DELAY_B EQU $F57A
VEC_TEXT_HW EQU $C82A
MOD16.M16_RPOS EQU $410A
Clear_x_256 EQU $F545
PRINT_LIST EQU $F38A
Vec_Twang_Table EQU $C851
Vec_Music_Wk_A EQU $C842
Print_Str EQU $F495
music8 EQU $FEF8
Vec_Counter_6 EQU $C833
Delay_b EQU $F57A
Vec_Seed_Ptr EQU $C87B
VEC_RFRSH EQU $C83D
DOT_IX_B EQU $F2BE
VEC_JOY_RESLTN EQU $C81A
VEC_MUSIC_WK_6 EQU $C846
PRINT_LIST_HW EQU $F385
Vec_Button_2_4 EQU $C819
DRAW_VLP_SCALE EQU $F40C
ROT_VL_MODE EQU $F62B
Rot_VL EQU $F616
MUSIC1 EQU $FD0D
MOVETO_IX_7F EQU $F30C
Vec_Joy_Mux_1_Y EQU $C820
VEC_EXPL_3 EQU $C85A
Intensity_7F EQU $F2A9
Draw_Line_d EQU $F3DF
VEC_FREQ_TABLE EQU $C84D
DO_SOUND EQU $F289
Intensity_1F EQU $F29D
Rot_VL_Mode_a EQU $F61F
VEC_BRIGHTNESS EQU $C827
Obj_Will_Hit_u EQU $F8E5
Vec_Counter_5 EQU $C832
Vec_RiseRun_Len EQU $C83B
Vec_Num_Game EQU $C87A
MOVE_MEM_A_1 EQU $F67F
RISE_RUN_LEN EQU $F603
Delay_2 EQU $F571
Vec_Text_HW EQU $C82A
DEC_3_COUNTERS EQU $F55A
VEC_TEXT_HEIGHT EQU $C82A
INTENSITY_A EQU $F2AB
MOV_DRAW_VL_D EQU $F3BE
Draw_VLp_7F EQU $F408
MOVETO_IX_A EQU $F30E
Vec_Counter_4 EQU $C831
PRINT_STR EQU $F495
MOD16.M16_END EQU $411A
Dec_3_Counters EQU $F55A
music3 EQU $FD81
SELECT_GAME EQU $F7A9
Do_Sound_x EQU $F28C
musicc EQU $FF7A
VECTREX_PRINT_NUMBER.PN_DIV1000 EQU $4050
DRAW_CIRCLE_RUNTIME EQU $412A
DELAY_0 EQU $F579
VEC_BUTTON_1_4 EQU $C815
DRAW_PAT_VL_A EQU $F434
Vec_Button_1_2 EQU $C813
Vec_Default_Stk EQU $CBEA
Draw_VL EQU $F3DD
VECTREX_PRINT_NUMBER EQU $4030
music6 EQU $FE76
Vec_Joy_Mux_2_X EQU $C821
CLEAR_SOUND EQU $F272
Vec_Music_Chan EQU $C855
Sound_Byte EQU $F256
VEC_SWI_VECTOR EQU $CBFB
Vec_Loop_Count EQU $C825
MUSIC3 EQU $FD81
Print_Str_yx EQU $F378
DOT_HERE EQU $F2C5
Recalibrate EQU $F2E6
Move_Mem_a_1 EQU $F67F
VEC_NMI_VECTOR EQU $CBFB
Add_Score_a EQU $F85E
Vec_Music_Ptr EQU $C853
Obj_Hit EQU $F8FF
Intensity_a EQU $F2AB
VEC_EXPL_TIMER EQU $C877
XFORM_RUN_A EQU $F65B
VEC_COUNTER_4 EQU $C831
Dot_List_Reset EQU $F2DE
INIT_MUSIC EQU $F68D
PRINT_TEXT_STR_2049398 EQU $4274
Random EQU $F517
VEC_IRQ_VECTOR EQU $CBF8
Init_OS EQU $F18B
RESET0INT EQU $F36B
VEC_BTN_STATE EQU $C80F
VEC_BUTTON_2_3 EQU $C818
VEC_PATTERN EQU $C829
Vec_Joy_Mux_1_X EQU $C81F
VEC_SEED_PTR EQU $C87B
Vec_ADSR_Timers EQU $C85E
MUSIC8 EQU $FEF8
DRAW_VL_AB EQU $F3D8
VECTREX_PRINT_TEXT EQU $4000
COLD_START EQU $F000
MOV_DRAW_VL_A EQU $F3B9
MOD16.M16_RCHECK EQU $40FB
Init_Music_chk EQU $F687
PRINT_LIST_CHK EQU $F38C
VEC_TEXT_WIDTH EQU $C82B
Moveto_x_7F EQU $F2F2
VEC_ADSR_TIMERS EQU $C85E
CLEAR_X_D EQU $F548
ADD_SCORE_A EQU $F85E
Xform_Run EQU $F65D
MOV_DRAW_VL_B EQU $F3B1
CHECK0REF EQU $F34F
Vec_NMI_Vector EQU $CBFB
Clear_x_d EQU $F548
DRAW_VL_MODE EQU $F46E
VEC_MUSIC_WK_1 EQU $C84B
INIT_MUSIC_CHK EQU $F687
Intensity_3F EQU $F2A1
OBJ_WILL_HIT_U EQU $F8E5
Vec_Button_1_3 EQU $C814
VEC_NUM_GAME EQU $C87A
Clear_Sound EQU $F272
Vec_Max_Players EQU $C84F
CLEAR_X_B_A EQU $F552
Init_Music_x EQU $F692
Strip_Zeros EQU $F8B7
MUSIC2 EQU $FD1D
READ_BTNS EQU $F1BA
Check0Ref EQU $F34F
WARM_START EQU $F06C
Moveto_ix_FF EQU $F308
INTENSITY_1F EQU $F29D
Mov_Draw_VL_a EQU $F3B9
Draw_VLp_FF EQU $F404
Vec_Joy_Resltn EQU $C81A
DEC_6_COUNTERS EQU $F55E
VEC_JOY_2_Y EQU $C81E
Reset0Ref_D0 EQU $F34A
VEC_BUTTON_1_1 EQU $C812
Moveto_d_7F EQU $F2FC
ABS_B EQU $F58B
VEC_MUSIC_WK_7 EQU $C845
VEC_BUTTON_1_3 EQU $C814
DRAW_GRID_VL EQU $FF9F
musicb EQU $FF62
Rot_VL_dft EQU $F637
VEC_COLD_FLAG EQU $CBFE
Rise_Run_Y EQU $F601
Vec_Text_Width EQU $C82B
Print_Str_d EQU $F37A
VEC_BUTTON_1_2 EQU $C813
music5 EQU $FE38
VEC_MUSIC_WK_A EQU $C842
VEC_COUNTER_2 EQU $C82F
DP_to_D0 EQU $F1AA
VEC_COUNTERS EQU $C82E
VEC_SWI3_VECTOR EQU $CBF2
PRINT_SHIPS_X EQU $F391
VEC_RFRSH_LO EQU $C83D
CLEAR_X_B EQU $F53F
Vec_Music_Wk_1 EQU $C84B
Get_Run_Idx EQU $F5DB
RANDOM_3 EQU $F511
PRINT_STR_YX EQU $F378
Vec_Joy_2_Y EQU $C81E
Vec_Button_2_2 EQU $C817
WAIT_RECAL EQU $F192
ROT_VL_AB EQU $F610
Vec_Max_Games EQU $C850
DRAW_VL EQU $F3DD
Abs_b EQU $F58B
MUSICC EQU $FF7A
VEC_MUSIC_TWANG EQU $C858
STRIP_ZEROS EQU $F8B7
Print_Ships EQU $F393
VEC_PREV_BTNS EQU $C810
VEC_JOY_MUX_1_X EQU $C81F
Vec_Angle EQU $C836
SET_REFRESH EQU $F1A2
Dot_ix EQU $F2C1
Dot_here EQU $F2C5
RESET_PEN EQU $F35B
VEC_MISC_COUNT EQU $C823
MUSICB EQU $FF62
PRINT_SHIPS EQU $F393
Vec_Button_1_4 EQU $C815
VEC_MAX_PLAYERS EQU $C84F
Vec_Expl_2 EQU $C859
Dec_6_Counters EQU $F55E
DELAY_RTS EQU $F57D
RISE_RUN_X EQU $F5FF
GET_RISE_IDX EQU $F5D9
Mov_Draw_VLcs EQU $F3B5
Vec_Str_Ptr EQU $C82C
CLEAR_X_B_80 EQU $F550
VEC_COUNTER_3 EQU $C830
Sound_Bytes_x EQU $F284
Sound_Byte_raw EQU $F25B
Moveto_ix_7F EQU $F30C
Dot_List EQU $F2D5
VEC_EXPL_4 EQU $C85B
EXPLOSION_SND EQU $F92E
VECTREX_PRINT_NUMBER.PN_AFTER_CONVERT EQU $40A9
Vec_Joy_1_Y EQU $C81C


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "J1_BUTTONS"
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
DRAW_CIRCLE_XC       EQU $C880+$14   ; Circle center X (1 bytes)
DRAW_CIRCLE_YC       EQU $C880+$15   ; Circle center Y (1 bytes)
DRAW_CIRCLE_DIAM     EQU $C880+$16   ; Circle diameter (1 bytes)
DRAW_CIRCLE_INTENSITY EQU $C880+$17   ; Circle intensity (1 bytes)
DRAW_CIRCLE_RADIUS   EQU $C880+$18   ; Circle radius (diam/2) - used in segment drawing (1 bytes)
DRAW_CIRCLE_TEMP     EQU $C880+$19   ; Circle temporary buffer (8 bytes: radius16, a, b, c, d, --, --)  a=0.383r b=0.324r c=0.217r d=0.076r (8 bytes)
DRAW_LINE_ARGS       EQU $C880+$21   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$2B   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$2D   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$2F   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$30   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$31   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$33   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$35   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$36   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_BTN1             EQU $C880+$37   ; User variable: BTN1 (2 bytes)
VAR_BTN2             EQU $C880+$39   ; User variable: BTN2 (2 bytes)
VAR_BTN3             EQU $C880+$3B   ; User variable: BTN3 (2 bytes)
VAR_BTN4             EQU $C880+$3D   ; User variable: BTN4 (2 bytes)
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
    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed
    BITA #$01
    LBNE .J1B1_0_ON
    LDD #0
    LBRA .J1B1_0_END
.J1B1_0_ON:
    LDD #1
.J1B1_0_END:
    STD RESULT
    STD VAR_BTN1
    LDA >$C80F   ; Vec_Btns_1: bit1=1 means btn2 pressed
    BITA #$02
    LBNE .J1B2_1_ON
    LDD #0
    LBRA .J1B2_1_END
.J1B2_1_ON:
    LDD #1
.J1B2_1_END:
    STD RESULT
    STD VAR_BTN2
    LDA >$C80F   ; Vec_Btns_1: bit2=1 means btn3 pressed
    BITA #$04
    LBNE .J1B3_2_ON
    LDD #0
    LBRA .J1B3_2_END
.J1B3_2_ON:
    LDD #1
.J1B3_2_END:
    STD RESULT
    STD VAR_BTN3
    LDA >$C80F   ; Vec_Btns_1: bit3=1 means btn4 pressed
    BITA #$08
    LBNE .J1B4_3_ON
    LDD #0
    LBRA .J1B4_3_END
.J1B4_3_ON:
    LDD #1
.J1B4_3_END:
    STD RESULT
    STD VAR_BTN4
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD VAR_ARG0
    LDD #80
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2049397      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #0
    STD VAR_ARG0    ; X position
    LDD #80
    STD VAR_ARG1    ; Y position
    LDD >VAR_BTN1
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD VAR_ARG0
    LDD #60
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2049398      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #0
    STD VAR_ARG0    ; X position
    LDD #60
    STD VAR_ARG1    ; Y position
    LDD >VAR_BTN2
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD VAR_ARG0
    LDD #40
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2049399      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #0
    STD VAR_ARG0    ; X position
    LDD #40
    STD VAR_ARG1    ; Y position
    LDD >VAR_BTN3
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD VAR_ARG0
    LDD #20
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2049400      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #0
    STD VAR_ARG0    ; X position
    LDD #20
    STD VAR_ARG1    ; Y position
    LDD >VAR_BTN4
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN1
    CMPD TMPVAL
    LBEQ .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_1
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$50
    JSR Intensity_a
    LDA #$00
    LDB #$DD
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN2
    CMPD TMPVAL
    LBEQ .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    LBEQ IF_NEXT_3
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$50
    JSR Intensity_a
    LDA #$00
    LDB #$05
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN3
    CMPD TMPVAL
    LBEQ .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    LBEQ IF_NEXT_5
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$50
    JSR Intensity_a
    LDA #$00
    LDB #$2D
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN4
    CMPD TMPVAL
    LBEQ .CMP_3_TRUE
    LDD #0
    LBRA .CMP_3_END
.CMP_3_TRUE:
    LDD #1
.CMP_3_END:
    LBEQ IF_NEXT_7
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$50
    JSR Intensity_a
    LDA #$D8
    LDB #$05
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
    RTS


; ================================================
