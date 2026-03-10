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
VAR_BTN1             EQU $C880+$37   ; User variable: btn1 (2 bytes)
VAR_BTN2             EQU $C880+$39   ; User variable: btn2 (2 bytes)
VAR_BTN3             EQU $C880+$3B   ; User variable: btn3 (2 bytes)
VAR_BTN4             EQU $C880+$3D   ; User variable: btn4 (2 bytes)
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
VEC_JOY_2_X EQU $C81D
Rot_VL_dft EQU $F637
Compare_Score EQU $F8C7
VEC_RISERUN_TMP EQU $C834
Vec_SWI2_Vector EQU $CBF2
Vec_Expl_Chan EQU $C85C
VEC_EXPL_CHANS EQU $C854
Joy_Digital EQU $F1F8
Mov_Draw_VL_d EQU $F3BE
VEC_COUNTER_6 EQU $C833
SOUND_BYTE EQU $F256
Vec_Rise_Index EQU $C839
Vec_Rfrsh_lo EQU $C83D
VEC_JOY_MUX_1_X EQU $C81F
Vec_Prev_Btns EQU $C810
Move_Mem_a EQU $F683
Get_Run_Idx EQU $F5DB
BITMASK_A EQU $F57E
Recalibrate EQU $F2E6
Draw_VLp_FF EQU $F404
DRAW_LINE_D EQU $F3DF
Delay_0 EQU $F579
Sound_Byte_raw EQU $F25B
Clear_x_b_a EQU $F552
Sound_Byte_x EQU $F259
VEC_MUSIC_FREQ EQU $C861
Vec_Expl_1 EQU $C858
PRINT_STR_YX EQU $F378
Vec_Text_HW EQU $C82A
ROT_VL_DFT EQU $F637
Vec_Button_1_3 EQU $C814
VEC_MUSIC_WK_1 EQU $C84B
Moveto_ix_FF EQU $F308
MUSICB EQU $FF62
VEC_RUN_INDEX EQU $C837
Vec_Button_1_4 EQU $C815
DCR_intensity_5F EQU $415F
INIT_MUSIC_CHK EQU $F687
VEC_RFRSH EQU $C83D
VEC_RFRSH_HI EQU $C83E
DRAW_VL_AB EQU $F3D8
Print_Ships_x EQU $F391
Vec_Buttons EQU $C811
Draw_VLp EQU $F410
VEC_COLD_FLAG EQU $CBFE
Reset_Pen EQU $F35B
Dec_Counters EQU $F563
Xform_Rise EQU $F663
Strip_Zeros EQU $F8B7
ROT_VL_MODE_A EQU $F61F
VECTREX_PRINT_NUMBER.PN_D1000 EQU $4064
DRAW_VLP EQU $F410
VEC_BUTTON_2_2 EQU $C817
VEC_BUTTON_2_1 EQU $C816
Print_Str_hwyx EQU $F373
CLEAR_C8_RAM EQU $F542
MUSIC6 EQU $FE76
Delay_b EQU $F57A
Vec_Counter_5 EQU $C832
Vec_Button_2_1 EQU $C816
CLEAR_X_B EQU $F53F
INIT_MUSIC_X EQU $F692
VEC_BUTTON_2_4 EQU $C819
Vec_Music_Wk_7 EQU $C845
Vec_Default_Stk EQU $CBEA
VEC_STR_PTR EQU $C82C
Add_Score_a EQU $F85E
Vec_ADSR_Timers EQU $C85E
PRINT_TEXT_STR_2049398 EQU $4274
music5 EQU $FE38
Moveto_d EQU $F312
XFORM_RISE EQU $F663
VECTREX_PRINT_NUMBER.PN_D10 EQU $4098
VEC_MUSIC_WK_5 EQU $C847
Dot_List_Reset EQU $F2DE
PRINT_LIST EQU $F38A
Vec_Expl_4 EQU $C85B
Explosion_Snd EQU $F92E
Bitmask_a EQU $F57E
VEC_TEXT_HEIGHT EQU $C82A
DP_TO_C8 EQU $F1AF
Clear_C8_RAM EQU $F542
MOVETO_D_7F EQU $F2FC
MOD16.M16_RPOS EQU $410A
Vec_Music_Ptr EQU $C853
Vec_Counter_4 EQU $C831
VECTREX_PRINT_NUMBER.PN_L1000 EQU $4052
Move_Mem_a_1 EQU $F67F
DP_TO_D0 EQU $F1AA
MOVETO_X_7F EQU $F2F2
VEC_SWI_VECTOR EQU $CBFB
Rot_VL_ab EQU $F610
DELAY_2 EQU $F571
Vec_Button_2_2 EQU $C817
Delay_2 EQU $F571
Draw_VLp_scale EQU $F40C
MOV_DRAW_VL_AB EQU $F3B7
Mov_Draw_VL_a EQU $F3B9
VEC_EXPL_4 EQU $C85B
Mov_Draw_VL EQU $F3BC
Vec_Rfrsh EQU $C83D
Print_Str EQU $F495
VEC_MUSIC_FLAG EQU $C856
Init_OS_RAM EQU $F164
VEC_ANGLE EQU $C836
Moveto_d_7F EQU $F2FC
Init_OS EQU $F18B
Moveto_ix EQU $F310
Vec_Str_Ptr EQU $C82C
Vec_Expl_3 EQU $C85A
MOV_DRAW_VL_B EQU $F3B1
INTENSITY_5F EQU $F2A5
ABS_A_B EQU $F584
New_High_Score EQU $F8D8
VEC_PREV_BTNS EQU $C810
Check0Ref EQU $F34F
RESET0REF_D0 EQU $F34A
Clear_x_b EQU $F53F
VEC_MUSIC_WK_7 EQU $C845
Random EQU $F517
STRIP_ZEROS EQU $F8B7
MOD16.M16_LOOP EQU $410A
VEC_IRQ_VECTOR EQU $CBF8
Draw_Grid_VL EQU $FF9F
Vec_Music_Chan EQU $C855
DRAW_VL EQU $F3DD
OBJ_HIT EQU $F8FF
VEC_ADSR_TABLE EQU $C84F
ROT_VL_MODE EQU $F62B
Vec_RiseRun_Tmp EQU $C834
RECALIBRATE EQU $F2E6
Vec_Joy_Resltn EQU $C81A
VEC_EXPL_CHANA EQU $C853
VECTREX_PRINT_TEXT EQU $4000
INIT_MUSIC EQU $F68D
VEC_RISE_INDEX EQU $C839
Reset0Int EQU $F36B
MOD16.M16_DONE EQU $4129
Obj_Will_Hit_u EQU $F8E5
Vec_Button_1_1 EQU $C812
READ_BTNS EQU $F1BA
musicb EQU $FF62
VEC_BTN_STATE EQU $C80F
Get_Rise_Idx EQU $F5D9
Clear_x_d EQU $F548
musicd EQU $FF8F
INTENSITY_3F EQU $F2A1
MOD16.M16_DPOS EQU $40F3
Moveto_x_7F EQU $F2F2
INTENSITY_7F EQU $F2A9
VEC_MUSIC_TWANG EQU $C858
VEC_BUTTON_1_4 EQU $C815
Mov_Draw_VL_ab EQU $F3B7
MUSIC8 EQU $FEF8
SOUND_BYTES EQU $F27D
Vec_Seed_Ptr EQU $C87B
Vec_Counter_6 EQU $C833
CHECK0REF EQU $F34F
Vec_High_Score EQU $CBEB
DCR_AFTER_INTENSITY EQU $4162
PRINT_STR EQU $F495
VEC_MAX_PLAYERS EQU $C84F
Vec_Brightness EQU $C827
VEC_JOY_2_Y EQU $C81E
DO_SOUND EQU $F289
Vec_Misc_Count EQU $C823
VEC_0REF_ENABLE EQU $C824
VEC_COUNTER_3 EQU $C830
VEC_JOY_MUX_2_Y EQU $C822
Dot_List EQU $F2D5
Get_Rise_Run EQU $F5EF
Vec_Joy_Mux_2_Y EQU $C822
COLD_START EQU $F000
Init_Music_Buf EQU $F533
Vec_IRQ_Vector EQU $CBF8
Clear_Score EQU $F84F
VEC_BUTTON_1_3 EQU $C814
Draw_VL_ab EQU $F3D8
music2 EQU $FD1D
Sound_Bytes EQU $F27D
Mov_Draw_VLcs EQU $F3B5
Vec_RiseRun_Len EQU $C83B
Draw_VL_a EQU $F3DA
VEC_JOY_MUX_2_X EQU $C821
Xform_Run_a EQU $F65B
VEC_JOY_MUX EQU $C81F
Vec_Counters EQU $C82E
Read_Btns EQU $F1BA
VEC_NUM_GAME EQU $C87A
MOVETO_IX_7F EQU $F30C
OBJ_WILL_HIT_U EQU $F8E5
Vec_Music_Twang EQU $C858
DRAW_CIRCLE_RUNTIME EQU $412A
DEC_3_COUNTERS EQU $F55A
MUSIC9 EQU $FF26
VEC_RISERUN_LEN EQU $C83B
DOT_HERE EQU $F2C5
VEC_SWI2_VECTOR EQU $CBF2
VECTREX_PRINT_NUMBER.PN_L100 EQU $406C
Vec_Music_Work EQU $C83F
Vec_NMI_Vector EQU $CBFB
INIT_VIA EQU $F14C
PRINT_TEXT_STR_2049400 EQU $427E
DCR_INTENSITY_5F EQU $415F
MUSIC3 EQU $FD81
Vec_Music_Wk_A EQU $C842
Vec_Snd_Shadow EQU $C800
Vec_Run_Index EQU $C837
VEC_MAX_GAMES EQU $C850
Vec_Cold_Flag EQU $CBFE
ROT_VL_AB EQU $F610
Vec_Music_Flag EQU $C856
MOVE_MEM_A_1 EQU $F67F
Vec_ADSR_Table EQU $C84F
VEC_RFRSH_LO EQU $C83D
Wait_Recal EQU $F192
Draw_VL_b EQU $F3D2
Vec_Joy_2_Y EQU $C81E
Rot_VL_Mode_a EQU $F61F
MOV_DRAW_VLCS EQU $F3B5
MUSIC4 EQU $FDD3
DRAW_VL_B EQU $F3D2
Draw_VLp_b EQU $F40E
MOV_DRAW_VL_A EQU $F3B9
Reset0Ref_D0 EQU $F34A
DP_to_C8 EQU $F1AF
Vec_Max_Players EQU $C84F
Draw_Pat_VL_d EQU $F439
WARM_START EQU $F06C
Vec_Joy_1_X EQU $C81B
Do_Sound_x EQU $F28C
MOV_DRAW_VLC_A EQU $F3AD
RANDOM EQU $F517
Vec_Button_1_2 EQU $C813
DOT_LIST EQU $F2D5
DRAW_GRID_VL EQU $FF9F
Vec_Joy_Mux_1_X EQU $C81F
MUSIC1 EQU $FD0D
Warm_Start EQU $F06C
NEW_HIGH_SCORE EQU $F8D8
VEC_FIRQ_VECTOR EQU $CBF5
RISE_RUN_ANGLE EQU $F593
Vec_Max_Games EQU $C850
DELAY_RTS EQU $F57D
DRAW_VL_A EQU $F3DA
Vec_Counter_3 EQU $C830
ADD_SCORE_A EQU $F85E
DRAW_VLP_SCALE EQU $F40C
Vec_Button_2_3 EQU $C818
MUSICD EQU $FF8F
Draw_VL EQU $F3DD
Draw_VLcs EQU $F3D6
CLEAR_X_B_80 EQU $F550
Mov_Draw_VLc_a EQU $F3AD
VECTREX_PRINT_NUMBER.PN_AFTER_CONVERT EQU $40A9
MOV_DRAW_VL_D EQU $F3BE
VECTREX_PRINT_NUMBER.PN_DIV1000 EQU $4050
Rise_Run_X EQU $F5FF
MOVETO_IX_FF EQU $F308
CLEAR_X_D EQU $F548
Rise_Run_Len EQU $F603
VEC_ADSR_TIMERS EQU $C85E
DELAY_1 EQU $F575
OBJ_WILL_HIT EQU $F8F3
Vec_Rfrsh_hi EQU $C83E
Mov_Draw_VL_b EQU $F3B1
Draw_VL_mode EQU $F46E
Intensity_7F EQU $F2A9
Vec_Pattern EQU $C829
INIT_MUSIC_BUF EQU $F533
VEC_EXPL_3 EQU $C85A
VEC_RANDOM_SEED EQU $C87D
VEC_JOY_1_X EQU $C81B
VEC_MISC_COUNT EQU $C823
Print_List_chk EQU $F38C
Vec_Freq_Table EQU $C84D
Vec_Expl_ChanA EQU $C853
ABS_B EQU $F58B
VEC_MUSIC_WK_A EQU $C842
MOD16.M16_RCHECK EQU $40FB
DRAW_VL_MODE EQU $F46E
RISE_RUN_LEN EQU $F603
ADD_SCORE_D EQU $F87C
VEC_BUTTON_1_2 EQU $C813
PRINT_STR_D EQU $F37A
MUSIC2 EQU $FD1D
Vec_Expl_2 EQU $C859
Draw_Line_d EQU $F3DF
Vec_Expl_ChanB EQU $C85D
Clear_Sound EQU $F272
WAIT_RECAL EQU $F192
PRINT_LIST_HW EQU $F385
Read_Btns_Mask EQU $F1B4
VEC_FREQ_TABLE EQU $C84D
Print_List EQU $F38A
Dec_3_Counters EQU $F55A
PRINT_SHIPS_X EQU $F391
MUSIC5 EQU $FE38
Vec_Music_Wk_1 EQU $C84B
VEC_MUSIC_WK_6 EQU $C846
Draw_VLc EQU $F3CE
RANDOM_3 EQU $F511
Print_Ships EQU $F393
DRAW_VLP_FF EQU $F404
VEC_COUNTER_1 EQU $C82E
DRAW_PAT_VL_A EQU $F434
DOT_D EQU $F2C3
Cold_Start EQU $F000
DEC_COUNTERS EQU $F563
Vec_Joy_Mux EQU $C81F
VECTREX_PRINT_NUMBER.PN_D100 EQU $407E
music8 EQU $FEF8
Sound_Bytes_x EQU $F284
Delay_1 EQU $F575
Vec_Duration EQU $C857
music4 EQU $FDD3
Add_Score_d EQU $F87C
Intensity_3F EQU $F2A1
Draw_Pat_VL_a EQU $F434
VECTREX_PRINT_NUMBER.PN_L10 EQU $4086
Xform_Rise_a EQU $F661
Obj_Hit EQU $F8FF
VEC_COUNTER_5 EQU $C832
Vec_Button_2_4 EQU $C819
VEC_BUTTON_2_3 EQU $C818
music7 EQU $FEC6
Rise_Run_Y EQU $F601
Vec_Expl_Chans EQU $C854
DRAW_VLP_7F EQU $F408
Vec_Music_Freq EQU $C861
XFORM_RUN EQU $F65D
Vec_Music_Wk_6 EQU $C846
Vec_Joy_2_X EQU $C81D
Clear_x_b_80 EQU $F550
VEC_HIGH_SCORE EQU $CBEB
VEC_MUSIC_CHAN EQU $C855
PRINT_SHIPS EQU $F393
JOY_ANALOG EQU $F1F5
SOUND_BYTE_X EQU $F259
Init_Music_x EQU $F692
Do_Sound EQU $F289
VEC_JOY_MUX_1_Y EQU $C820
Vec_FIRQ_Vector EQU $CBF5
EXPLOSION_SND EQU $F92E
DP_to_D0 EQU $F1AA
Vec_Joy_Mux_1_Y EQU $C820
CLEAR_SOUND EQU $F272
VEC_EXPL_CHANB EQU $C85D
VEC_JOY_RESLTN EQU $C81A
RESET0INT EQU $F36B
VEC_EXPL_CHAN EQU $C85C
PRINT_LIST_CHK EQU $F38C
DRAW_VLP_B EQU $F40E
Abs_b EQU $F58B
Dec_6_Counters EQU $F55E
Vec_SWI_Vector EQU $CBFB
DEC_6_COUNTERS EQU $F55E
DOT_IX_B EQU $F2BE
Intensity_5F EQU $F2A5
Moveto_ix_7F EQU $F30C
MOVETO_D EQU $F312
Vec_Dot_Dwell EQU $C828
music9 EQU $FF26
DRAW_PAT_VL_D EQU $F439
GET_RISE_RUN EQU $F5EF
Rot_VL_Mode EQU $F62B
Select_Game EQU $F7A9
VEC_JOY_1_Y EQU $C81C
Delay_3 EQU $F56D
Vec_SWI3_Vector EQU $CBF2
VEC_MUSIC_WORK EQU $C83F
Dot_d EQU $F2C3
SELECT_GAME EQU $F7A9
VEC_EXPL_2 EQU $C859
Vec_Counter_2 EQU $C82F
music6 EQU $FE76
music3 EQU $FD81
MUSICC EQU $FF7A
VEC_NMI_VECTOR EQU $CBFB
VEC_TEXT_HW EQU $C82A
VEC_COUNTERS EQU $C82E
Vec_Expl_Timer EQU $C877
Xform_Run EQU $F65D
MOVE_MEM_A EQU $F683
RESET0REF EQU $F354
Vec_Music_Wk_5 EQU $C847
Draw_VLp_7F EQU $F408
MUSICA EQU $FF44
VEC_TEXT_WIDTH EQU $C82B
RESET_PEN EQU $F35B
SOUND_BYTE_RAW EQU $F25B
SOUND_BYTES_X EQU $F284
VEC_SWI3_VECTOR EQU $CBF2
Draw_Pat_VL EQU $F437
musicc EQU $FF7A
VEC_BUTTONS EQU $C811
VEC_DEFAULT_STK EQU $CBEA
INIT_OS_RAM EQU $F164
VEC_PATTERN EQU $C829
VEC_LOOP_COUNT EQU $C825
Print_List_hw EQU $F385
VEC_DOT_DWELL EQU $C828
Intensity_a EQU $F2AB
DOT_LIST_RESET EQU $F2DE
Vec_Num_Players EQU $C879
Vec_Text_Height EQU $C82A
Vec_Angle EQU $C836
Vec_Joy_Mux_2_X EQU $C821
VEC_COUNTER_2 EQU $C82F
VEC_EXPL_FLAG EQU $C867
MOD16 EQU $40D6
MOVETO_IX EQU $F310
Init_Music_chk EQU $F687
Dot_ix_b EQU $F2BE
COMPARE_SCORE EQU $F8C7
VEC_EXPL_1 EQU $C858
DELAY_B EQU $F57A
RISE_RUN_X EQU $F5FF
JOY_DIGITAL EQU $F1F8
READ_BTNS_MASK EQU $F1B4
Vec_0Ref_Enable EQU $C824
Obj_Will_Hit EQU $F8F3
music1 EQU $FD0D
Vec_Counter_1 EQU $C82E
Abs_a_b EQU $F584
Vec_Random_Seed EQU $C87D
GET_RISE_IDX EQU $F5D9
Print_Str_d EQU $F37A
MOVETO_IX_A EQU $F30E
RISE_RUN_Y EQU $F601
XFORM_RISE_A EQU $F661
MOD16.M16_END EQU $411A
CLEAR_X_256 EQU $F545
INTENSITY_A EQU $F2AB
VEC_EXPL_TIMER EQU $C877
CLEAR_SCORE EQU $F84F
PRINT_TEXT_STR_2049397 EQU $426F
DRAW_VLCS EQU $F3D6
MUSIC7 EQU $FEC6
Vec_Twang_Table EQU $C851
PRINT_TEXT_STR_2049399 EQU $4279
CLEAR_X_B_A EQU $F552
VEC_NUM_PLAYERS EQU $C879
Vec_Expl_Flag EQU $C867
MOV_DRAW_VL EQU $F3BC
Reset0Ref EQU $F354
DOT_IX EQU $F2C1
Vec_Loop_Count EQU $C825
Vec_Joy_1_Y EQU $C81C
Intensity_1F EQU $F29D
Print_Str_yx EQU $F378
VEC_BUTTON_1_1 EQU $C812
ROT_VL EQU $F616
Init_Music EQU $F68D
VEC_SEED_PTR EQU $C87B
SET_REFRESH EQU $F1A2
Moveto_ix_a EQU $F30E
Delay_RTS EQU $F57D
Joy_Analog EQU $F1F5
INTENSITY_1F EQU $F29D
Clear_x_256 EQU $F545
Rise_Run_Angle EQU $F593
Dot_here EQU $F2C5
VECTREX_PRINT_NUMBER EQU $4030
Init_VIA EQU $F14C
musica EQU $FF44
INIT_OS EQU $F18B
VEC_BRIGHTNESS EQU $C827
VEC_TWANG_TABLE EQU $C851
Set_Refresh EQU $F1A2
VEC_DURATION EQU $C857
XFORM_RUN_A EQU $F65B
PRINT_STR_HWYX EQU $F373
DCR_after_intensity EQU $4162
Vec_Num_Game EQU $C87A
VEC_SND_SHADOW EQU $C800
VEC_COUNTER_4 EQU $C831
Random_3 EQU $F511
DELAY_3 EQU $F56D
DO_SOUND_X EQU $F28C
VEC_MUSIC_PTR EQU $C853
Vec_Text_Width EQU $C82B
DRAW_PAT_VL EQU $F437
Vec_Btn_State EQU $C80F
DRAW_VLC EQU $F3CE
Dot_ix EQU $F2C1
DELAY_0 EQU $F579
GET_RUN_IDX EQU $F5DB
Rot_VL EQU $F616
Sound_Byte EQU $F256


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
VAR_BTN1             EQU $C880+$37   ; User variable: btn1 (2 bytes)
VAR_BTN2             EQU $C880+$39   ; User variable: btn2 (2 bytes)
VAR_BTN3             EQU $C880+$3B   ; User variable: btn3 (2 bytes)
VAR_BTN4             EQU $C880+$3D   ; User variable: btn4 (2 bytes)
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
