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
DRAW_CIRCLE_XC       EQU $C880+$0E   ; Circle center X (1 bytes)
DRAW_CIRCLE_YC       EQU $C880+$0F   ; Circle center Y (1 bytes)
DRAW_CIRCLE_DIAM     EQU $C880+$10   ; Circle diameter (1 bytes)
DRAW_CIRCLE_INTENSITY EQU $C880+$11   ; Circle intensity (1 bytes)
DRAW_CIRCLE_RADIUS   EQU $C880+$12   ; Circle radius (diam/2) - used in segment drawing (1 bytes)
DRAW_CIRCLE_TEMP     EQU $C880+$13   ; Circle temporary buffer (8 bytes: radius16, a, b, c, d, --, --)  a=0.383r b=0.324r c=0.217r d=0.076r (8 bytes)
DRAW_LINE_ARGS       EQU $C880+$1B   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$25   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$27   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$29   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$2A   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$2B   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$2D   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$2F   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$30   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
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
DEC_6_COUNTERS EQU $F55E
VEC_BUTTON_1_3 EQU $C814
Moveto_ix EQU $F310
COLD_START EQU $F000
Vec_Music_Wk_7 EQU $C845
VEC_MUSIC_FLAG EQU $C856
VEC_COUNTERS EQU $C82E
MUSICA EQU $FF44
VEC_BUTTON_1_2 EQU $C813
Xform_Rise EQU $F663
Print_Str_yx EQU $F378
CLEAR_X_B_A EQU $F552
SOUND_BYTE EQU $F256
DRAW_VL_B EQU $F3D2
INIT_VIA EQU $F14C
VEC_COUNTER_6 EQU $C833
Vec_Music_Wk_5 EQU $C847
Vec_Joy_Mux_1_X EQU $C81F
INTENSITY_5F EQU $F2A5
Delay_2 EQU $F571
DRAW_LINE_D EQU $F3DF
VEC_BUTTON_2_1 EQU $C816
Warm_Start EQU $F06C
MUSICB EQU $FF62
Vec_Cold_Flag EQU $CBFE
CLEAR_SOUND EQU $F272
VEC_PATTERN EQU $C829
Draw_Pat_VL_a EQU $F434
Rise_Run_X EQU $F5FF
Draw_VL_ab EQU $F3D8
Xform_Run_a EQU $F65B
DELAY_B EQU $F57A
CLEAR_C8_RAM EQU $F542
New_High_Score EQU $F8D8
Mov_Draw_VL_a EQU $F3B9
VEC_EXPL_FLAG EQU $C867
Vec_0Ref_Enable EQU $C824
Draw_VLcs EQU $F3D6
MOD16 EQU $4030
Mov_Draw_VL_b EQU $F3B1
RISE_RUN_X EQU $F5FF
DRAW_VLP_FF EQU $F404
Dot_ix EQU $F2C1
Read_Btns EQU $F1BA
DRAW_VLP_SCALE EQU $F40C
VEC_STR_PTR EQU $C82C
Vec_High_Score EQU $CBEB
MUSIC3 EQU $FD81
PRINT_STR_D EQU $F37A
Print_Ships_x EQU $F391
VEC_RFRSH EQU $C83D
MUSICC EQU $FF7A
VEC_EXPL_4 EQU $C85B
INIT_OS EQU $F18B
OBJ_WILL_HIT EQU $F8F3
Vec_Duration EQU $C857
Draw_VLp_scale EQU $F40C
musica EQU $FF44
VEC_ANGLE EQU $C836
Vec_Brightness EQU $C827
MOVETO_D_7F EQU $F2FC
Vec_Music_Flag EQU $C856
INTENSITY_1F EQU $F29D
Dot_ix_b EQU $F2BE
VEC_NUM_PLAYERS EQU $C879
Read_Btns_Mask EQU $F1B4
Vec_Snd_Shadow EQU $C800
RISE_RUN_Y EQU $F601
VEC_RFRSH_HI EQU $C83E
Select_Game EQU $F7A9
ROT_VL_MODE EQU $F62B
READ_BTNS_MASK EQU $F1B4
Clear_Sound EQU $F272
Check0Ref EQU $F34F
VEC_0REF_ENABLE EQU $C824
Sound_Byte_raw EQU $F25B
DOT_IX EQU $F2C1
MOV_DRAW_VLC_A EQU $F3AD
VEC_TEXT_HW EQU $C82A
MOVE_MEM_A_1 EQU $F67F
VEC_ADSR_TIMERS EQU $C85E
Vec_Expl_ChanB EQU $C85D
DRAW_VL_A EQU $F3DA
Init_OS EQU $F18B
musicb EQU $FF62
Vec_Counter_3 EQU $C830
JOY_DIGITAL EQU $F1F8
WAIT_RECAL EQU $F192
Vec_Pattern EQU $C829
RANDOM_3 EQU $F511
Draw_Grid_VL EQU $FF9F
music6 EQU $FE76
NEW_HIGH_SCORE EQU $F8D8
Vec_Btn_State EQU $C80F
Vec_RiseRun_Tmp EQU $C834
VEC_BUTTONS EQU $C811
Vec_Rfrsh_lo EQU $C83D
VEC_DEFAULT_STK EQU $CBEA
Reset0Int EQU $F36B
VEC_MAX_GAMES EQU $C850
Init_Music_Buf EQU $F533
DRAW_CIRCLE_RUNTIME EQU $4084
SOUND_BYTES_X EQU $F284
Vec_Expl_2 EQU $C859
VEC_FIRQ_VECTOR EQU $CBF5
musicc EQU $FF7A
Delay_1 EQU $F575
Vec_SWI2_Vector EQU $CBF2
Vec_Num_Game EQU $C87A
Print_List_chk EQU $F38C
DRAW_VLCS EQU $F3D6
VEC_JOY_2_Y EQU $C81E
Do_Sound_x EQU $F28C
Cold_Start EQU $F000
VEC_JOY_MUX EQU $C81F
Mov_Draw_VLcs EQU $F3B5
Vec_Button_1_4 EQU $C815
VEC_EXPL_2 EQU $C859
DRAW_VL EQU $F3DD
music7 EQU $FEC6
VEC_JOY_1_Y EQU $C81C
Rot_VL_Mode EQU $F62B
SELECT_GAME EQU $F7A9
ROT_VL_MODE_A EQU $F61F
DELAY_1 EQU $F575
Vec_Button_1_3 EQU $C814
VEC_BTN_STATE EQU $C80F
Print_List EQU $F38A
OBJ_HIT EQU $F8FF
Dec_3_Counters EQU $F55A
Compare_Score EQU $F8C7
MUSIC9 EQU $FF26
Get_Rise_Idx EQU $F5D9
VEC_RISERUN_LEN EQU $C83B
VEC_RISE_INDEX EQU $C839
MOV_DRAW_VLCS EQU $F3B5
VEC_NUM_GAME EQU $C87A
VEC_MUSIC_WK_A EQU $C842
XFORM_RUN EQU $F65D
Bitmask_a EQU $F57E
PRINT_STR_HWYX EQU $F373
RESET0INT EQU $F36B
VEC_EXPL_CHANB EQU $C85D
Draw_Pat_VL EQU $F437
Intensity_7F EQU $F2A9
DRAW_PAT_VL_A EQU $F434
DO_SOUND_X EQU $F28C
Print_Str_d EQU $F37A
DELAY_RTS EQU $F57D
PRINT_TEXT_STR_1691 EQU $41CC
Vec_Text_Width EQU $C82B
Print_List_hw EQU $F385
Vec_Joy_Mux_2_Y EQU $C822
VEC_EXPL_CHANA EQU $C853
MOVETO_IX EQU $F310
VEC_SND_SHADOW EQU $C800
Reset0Ref_D0 EQU $F34A
VEC_RFRSH_LO EQU $C83D
Mov_Draw_VL_d EQU $F3BE
VEC_EXPL_CHAN EQU $C85C
Vec_Counters EQU $C82E
ADD_SCORE_D EQU $F87C
Move_Mem_a_1 EQU $F67F
SET_REFRESH EQU $F1A2
music9 EQU $FF26
Draw_VL_a EQU $F3DA
Rot_VL_dft EQU $F637
Intensity_5F EQU $F2A5
Rot_VL_Mode_a EQU $F61F
VEC_BUTTON_1_4 EQU $C815
Moveto_ix_7F EQU $F30C
Vec_Twang_Table EQU $C851
DP_TO_C8 EQU $F1AF
Vec_Max_Games EQU $C850
VEC_MISC_COUNT EQU $C823
CLEAR_X_B_80 EQU $F550
DOT_IX_B EQU $F2BE
Draw_VL EQU $F3DD
Joy_Analog EQU $F1F5
DRAW_PAT_VL_D EQU $F439
music2 EQU $FD1D
Vec_Music_Chan EQU $C855
Vec_Expl_Flag EQU $C867
Vec_Freq_Table EQU $C84D
Clear_x_d EQU $F548
VEC_COUNTER_2 EQU $C82F
Obj_Will_Hit EQU $F8F3
VEC_JOY_2_X EQU $C81D
Vec_Counter_5 EQU $C832
VEC_JOY_RESLTN EQU $C81A
Xform_Run EQU $F65D
PRINT_SHIPS_X EQU $F391
VEC_MUSIC_FREQ EQU $C861
DRAW_GRID_VL EQU $FF9F
Vec_Angle EQU $C836
Set_Refresh EQU $F1A2
DOT_LIST EQU $F2D5
DCR_AFTER_INTENSITY EQU $40BC
Init_Music_x EQU $F692
INIT_MUSIC_BUF EQU $F533
MUSIC2 EQU $FD1D
Sound_Byte_x EQU $F259
PRINT_LIST_CHK EQU $F38C
Random EQU $F517
Vec_Run_Index EQU $C837
Vec_Button_2_3 EQU $C818
VEC_IRQ_VECTOR EQU $CBF8
Clear_C8_RAM EQU $F542
DRAW_VLP_7F EQU $F408
MOV_DRAW_VL EQU $F3BC
DRAW_VLP EQU $F410
VEC_HIGH_SCORE EQU $CBEB
Random_3 EQU $F511
Mov_Draw_VLc_a EQU $F3AD
XFORM_RISE_A EQU $F661
VEC_RUN_INDEX EQU $C837
INIT_MUSIC EQU $F68D
PRINT_TEXT_STR_48694 EQU $41D6
ROT_VL_DFT EQU $F637
VEC_MUSIC_WK_6 EQU $C846
Vec_Music_Twang EQU $C858
VEC_MUSIC_TWANG EQU $C858
INIT_MUSIC_CHK EQU $F687
Vec_Button_2_2 EQU $C817
VEC_MUSIC_PTR EQU $C853
Vec_Joy_2_Y EQU $C81E
Clear_x_b_a EQU $F552
VEC_COUNTER_1 EQU $C82E
VEC_BUTTON_2_4 EQU $C819
Clear_x_256 EQU $F545
Vec_Button_1_1 EQU $C812
OBJ_WILL_HIT_U EQU $F8E5
Vec_Joy_1_X EQU $C81B
RISE_RUN_LEN EQU $F603
VEC_COUNTER_3 EQU $C830
MOV_DRAW_VL_D EQU $F3BE
Vec_Loop_Count EQU $C825
INTENSITY_7F EQU $F2A9
Reset_Pen EQU $F35B
DCR_intensity_5F EQU $40B9
Delay_3 EQU $F56D
GET_RISE_RUN EQU $F5EF
DOT_HERE EQU $F2C5
DRAW_VLP_B EQU $F40E
musicd EQU $FF8F
MOV_DRAW_VL_A EQU $F3B9
MOVE_MEM_A EQU $F683
XFORM_RISE EQU $F663
Moveto_ix_FF EQU $F308
Dot_List_Reset EQU $F2DE
DP_to_D0 EQU $F1AA
Explosion_Snd EQU $F92E
Dot_List EQU $F2D5
MOV_DRAW_VL_B EQU $F3B1
GET_RUN_IDX EQU $F5DB
MOD16.M16_END EQU $4074
DRAW_VL_MODE EQU $F46E
VEC_BUTTON_2_3 EQU $C818
SOUND_BYTES EQU $F27D
VEC_COUNTER_5 EQU $C832
PRINT_STR_YX EQU $F378
COMPARE_SCORE EQU $F8C7
Joy_Digital EQU $F1F8
WARM_START EQU $F06C
Vec_Num_Players EQU $C879
Draw_VLc EQU $F3CE
VEC_MUSIC_WK_5 EQU $C847
Vec_Rfrsh_hi EQU $C83E
XFORM_RUN_A EQU $F65B
VEC_SWI_VECTOR EQU $CBFB
music1 EQU $FD0D
VEC_DURATION EQU $C857
Draw_Line_d EQU $F3DF
DP_TO_D0 EQU $F1AA
Sound_Bytes EQU $F27D
Vec_Rise_Index EQU $C839
Vec_Expl_Timer EQU $C877
Vec_Music_Work EQU $C83F
VEC_JOY_MUX_1_X EQU $C81F
BITMASK_A EQU $F57E
DEC_3_COUNTERS EQU $F55A
Vec_SWI3_Vector EQU $CBF2
Strip_Zeros EQU $F8B7
RESET0REF EQU $F354
VEC_LOOP_COUNT EQU $C825
Vec_Music_Wk_6 EQU $C846
Vec_Music_Wk_A EQU $C842
PRINT_SHIPS EQU $F393
CLEAR_SCORE EQU $F84F
Vec_Seed_Ptr EQU $C87B
VEC_MUSIC_WK_1 EQU $C84B
SOUND_BYTE_X EQU $F259
VEC_PREV_BTNS EQU $C810
Intensity_1F EQU $F29D
VEC_TEXT_WIDTH EQU $C82B
Wait_Recal EQU $F192
VEC_EXPL_3 EQU $C85A
VEC_TEXT_HEIGHT EQU $C82A
Vec_Expl_ChanA EQU $C853
RISE_RUN_ANGLE EQU $F593
Obj_Hit EQU $F8FF
Vec_SWI_Vector EQU $CBFB
Vec_Joy_Mux_2_X EQU $C821
Mov_Draw_VL_ab EQU $F3B7
VEC_TWANG_TABLE EQU $C851
Clear_x_b EQU $F53F
Draw_VLp_7F EQU $F408
Obj_Will_Hit_u EQU $F8E5
Vec_Rfrsh EQU $C83D
DRAW_PAT_VL EQU $F437
DCR_INTENSITY_5F EQU $40B9
Delay_b EQU $F57A
Vec_NMI_Vector EQU $CBFB
INTENSITY_A EQU $F2AB
MOV_DRAW_VL_AB EQU $F3B7
Delay_0 EQU $F579
Move_Mem_a EQU $F683
Draw_Pat_VL_d EQU $F439
VEC_COLD_FLAG EQU $CBFE
Vec_Counter_1 EQU $C82E
READ_BTNS EQU $F1BA
DELAY_2 EQU $F571
Print_Str EQU $F495
VEC_SEED_PTR EQU $C87B
MOVETO_IX_7F EQU $F30C
VEC_BUTTON_1_1 EQU $C812
Add_Score_d EQU $F87C
VEC_NMI_VECTOR EQU $CBFB
CLEAR_X_B EQU $F53F
Vec_Expl_Chans EQU $C854
Abs_b EQU $F58B
music5 EQU $FE38
INTENSITY_3F EQU $F2A1
Vec_Text_Height EQU $C82A
Vec_Expl_3 EQU $C85A
Print_Ships EQU $F393
MOVETO_X_7F EQU $F2F2
Intensity_3F EQU $F2A1
Vec_Counter_6 EQU $C833
VEC_MAX_PLAYERS EQU $C84F
DRAW_VL_AB EQU $F3D8
MUSIC8 EQU $FEF8
VECTREX_PRINT_TEXT EQU $4000
Vec_Button_2_1 EQU $C816
Vec_Joy_2_X EQU $C81D
music8 EQU $FEF8
CLEAR_X_D EQU $F548
ADD_SCORE_A EQU $F85E
VEC_EXPL_CHANS EQU $C854
VEC_JOY_MUX_2_Y EQU $C822
Vec_Buttons EQU $C811
Vec_Counter_4 EQU $C831
Vec_Expl_1 EQU $C858
MOVETO_IX_FF EQU $F308
Draw_VLp EQU $F410
VEC_RANDOM_SEED EQU $C87D
Draw_VL_mode EQU $F46E
Moveto_x_7F EQU $F2F2
SOUND_BYTE_RAW EQU $F25B
ROT_VL EQU $F616
Intensity_a EQU $F2AB
PRINT_LIST_HW EQU $F385
Moveto_d EQU $F312
Moveto_ix_a EQU $F30E
Vec_Joy_Mux_1_Y EQU $C820
MUSIC5 EQU $FE38
MUSICD EQU $FF8F
Vec_RiseRun_Len EQU $C83B
VEC_MUSIC_WORK EQU $C83F
Vec_Joy_Mux EQU $C81F
DRAW_VLC EQU $F3CE
ABS_B EQU $F58B
Vec_Button_2_4 EQU $C819
Vec_Music_Wk_1 EQU $C84B
STRIP_ZEROS EQU $F8B7
Moveto_d_7F EQU $F2FC
Dot_d EQU $F2C3
ABS_A_B EQU $F584
Abs_a_b EQU $F584
Mov_Draw_VL EQU $F3BC
Vec_Random_Seed EQU $C87D
MOD16.M16_DPOS EQU $404D
Vec_Joy_Resltn EQU $C81A
PRINT_TEXT_STR_64483629934611 EQU $41DA
CLEAR_X_256 EQU $F545
Reset0Ref EQU $F354
Vec_Music_Freq EQU $C861
RECALIBRATE EQU $F2E6
VEC_DOT_DWELL EQU $C828
Draw_VL_b EQU $F3D2
Xform_Rise_a EQU $F661
VEC_BUTTON_2_2 EQU $C817
Rot_VL_ab EQU $F610
Vec_Max_Players EQU $C84F
MUSIC7 EQU $FEC6
Init_Music EQU $F68D
DELAY_0 EQU $F579
Vec_Expl_Chan EQU $C85C
Clear_Score EQU $F84F
DO_SOUND EQU $F289
VEC_BRIGHTNESS EQU $C827
Vec_ADSR_Timers EQU $C85E
Vec_Music_Ptr EQU $C853
Vec_Text_HW EQU $C82A
Get_Rise_Run EQU $F5EF
RESET_PEN EQU $F35B
CHECK0REF EQU $F34F
MUSIC4 EQU $FDD3
Dot_here EQU $F2C5
VEC_ADSR_TABLE EQU $C84F
VEC_SWI2_VECTOR EQU $CBF2
Delay_RTS EQU $F57D
music3 EQU $FD81
MUSIC6 EQU $FE76
Vec_Joy_1_Y EQU $C81C
DOT_D EQU $F2C3
Vec_Prev_Btns EQU $C810
GET_RISE_IDX EQU $F5D9
VEC_FREQ_TABLE EQU $C84D
Vec_Default_Stk EQU $CBEA
VEC_RISERUN_TMP EQU $C834
JOY_ANALOG EQU $F1F5
VEC_COUNTER_4 EQU $C831
Get_Run_Idx EQU $F5DB
VEC_SWI3_VECTOR EQU $CBF2
VEC_MUSIC_CHAN EQU $C855
VEC_JOY_1_X EQU $C81B
PRINT_LIST EQU $F38A
Vec_Str_Ptr EQU $C82C
VEC_JOY_MUX_1_Y EQU $C820
VEC_EXPL_TIMER EQU $C877
Init_OS_RAM EQU $F164
Init_VIA EQU $F14C
Do_Sound EQU $F289
VEC_MUSIC_WK_7 EQU $C845
Rise_Run_Y EQU $F601
MUSIC1 EQU $FD0D
Dec_Counters EQU $F563
Vec_Counter_2 EQU $C82F
DCR_after_intensity EQU $40BC
RANDOM EQU $F517
MOVETO_D EQU $F312
INIT_MUSIC_X EQU $F692
Rise_Run_Len EQU $F603
music4 EQU $FDD3
INIT_OS_RAM EQU $F164
RESET0REF_D0 EQU $F34A
Vec_Expl_4 EQU $C85B
ROT_VL_AB EQU $F610
Sound_Bytes_x EQU $F284
MOD16.M16_DONE EQU $4083
Init_Music_chk EQU $F687
MOVETO_IX_A EQU $F30E
Vec_Misc_Count EQU $C823
Draw_VLp_b EQU $F40E
VEC_EXPL_1 EQU $C858
Vec_IRQ_Vector EQU $CBF8
Add_Score_a EQU $F85E
DP_to_C8 EQU $F1AF
Sound_Byte EQU $F256
DOT_LIST_RESET EQU $F2DE
Dec_6_Counters EQU $F55E
Vec_Dot_Dwell EQU $C828
DEC_COUNTERS EQU $F563
Vec_FIRQ_Vector EQU $CBF5
VEC_JOY_MUX_2_X EQU $C821
DELAY_3 EQU $F56D
PRINT_TEXT_STR_48656 EQU $41D2
Rot_VL EQU $F616
PRINT_TEXT_STR_1598 EQU $41C9
MOD16.M16_LOOP EQU $4064
MOD16.M16_RCHECK EQU $4055
Print_Str_hwyx EQU $F373
Recalibrate EQU $F2E6
Rise_Run_Angle EQU $F593
PRINT_TEXT_STR_1784 EQU $41CF
Clear_x_b_80 EQU $F550
MOD16.M16_RPOS EQU $4064
EXPLOSION_SND EQU $F92E
Vec_ADSR_Table EQU $C84F
Vec_Button_1_2 EQU $C813
PRINT_STR EQU $F495
Draw_VLp_FF EQU $F404


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "INTENSITY"
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
DRAW_CIRCLE_XC       EQU $C880+$0E   ; Circle center X (1 bytes)
DRAW_CIRCLE_YC       EQU $C880+$0F   ; Circle center Y (1 bytes)
DRAW_CIRCLE_DIAM     EQU $C880+$10   ; Circle diameter (1 bytes)
DRAW_CIRCLE_INTENSITY EQU $C880+$11   ; Circle intensity (1 bytes)
DRAW_CIRCLE_RADIUS   EQU $C880+$12   ; Circle radius (diam/2) - used in segment drawing (1 bytes)
DRAW_CIRCLE_TEMP     EQU $C880+$13   ; Circle temporary buffer (8 bytes: radius16, a, b, c, d, --, --)  a=0.383r b=0.324r c=0.217r d=0.076r (8 bytes)
DRAW_LINE_ARGS       EQU $C880+$1B   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$25   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$27   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$29   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$2A   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$2B   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$2D   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$2F   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$30   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
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
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD VAR_ARG0
    LDD #80
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_64483629934611      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$14
    JSR Intensity_a
    LDA #$00
    LDB #$A3
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$32
    JSR Intensity_a
    LDA #$00
    LDB #$D5
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$50
    JSR Intensity_a
    LDA #$00
    LDB #$08
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$01
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$6E
    JSR Intensity_a
    LDA #$00
    LDB #$3A
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$01
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$7F
    JSR Intensity_a
    LDA #$00
    LDB #$6C
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$01
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD VAR_ARG0
    LDD #-30
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_1598      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD VAR_ARG0
    LDD #-30
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_1691      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-20
    STD VAR_ARG0
    LDD #-30
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_1784      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #30
    STD VAR_ARG0
    LDD #-30
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_48656      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #80
    STD VAR_ARG0
    LDD #-30
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_48694      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    RTS


; ================================================
