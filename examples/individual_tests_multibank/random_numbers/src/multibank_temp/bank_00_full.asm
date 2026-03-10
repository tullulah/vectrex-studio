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
RAND_SEED            EQU $C880+$0E   ; Random seed for RAND() (2 bytes)
DRAW_CIRCLE_XC       EQU $C880+$10   ; Circle center X (1 bytes)
DRAW_CIRCLE_YC       EQU $C880+$11   ; Circle center Y (1 bytes)
DRAW_CIRCLE_DIAM     EQU $C880+$12   ; Circle diameter (1 bytes)
DRAW_CIRCLE_INTENSITY EQU $C880+$13   ; Circle intensity (1 bytes)
DRAW_CIRCLE_RADIUS   EQU $C880+$14   ; Circle radius (diam/2) - used in segment drawing (1 bytes)
DRAW_CIRCLE_TEMP     EQU $C880+$15   ; Circle temporary buffer (8 bytes: radius16, a, b, c, d, --, --)  a=0.383r b=0.324r c=0.217r d=0.076r (8 bytes)
DRAW_LINE_ARGS       EQU $C880+$1D   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$27   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$29   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$2B   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$2C   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$2D   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$2F   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$31   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$32   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_RX1              EQU $C880+$33   ; User variable: rx1 (2 bytes)
VAR_RY1              EQU $C880+$35   ; User variable: ry1 (2 bytes)
VAR_RX2              EQU $C880+$37   ; User variable: rx2 (2 bytes)
VAR_RY2              EQU $C880+$39   ; User variable: ry2 (2 bytes)
VAR_RX3              EQU $C880+$3B   ; User variable: rx3 (2 bytes)
VAR_RY4              EQU $C880+$3D   ; User variable: ry4 (2 bytes)
VAR_RY3              EQU $C880+$3F   ; User variable: ry3 (2 bytes)
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
GET_RISE_IDX EQU $F5D9
Init_OS_RAM EQU $F164
ROT_VL_MODE EQU $F62B
Dot_List_Reset EQU $F2DE
Vec_High_Score EQU $CBEB
VEC_DEFAULT_STK EQU $CBEA
Vec_Music_Work EQU $C83F
Compare_Score EQU $F8C7
Vec_Button_1_1 EQU $C812
SOUND_BYTE EQU $F256
Vec_RiseRun_Tmp EQU $C834
DP_to_D0 EQU $F1AA
VEC_MUSIC_FREQ EQU $C861
Vec_Joy_Mux_2_X EQU $C821
Read_Btns EQU $F1BA
MOD16.M16_DPOS EQU $404D
Vec_SWI_Vector EQU $CBFB
Intensity_1F EQU $F29D
OBJ_WILL_HIT_U EQU $F8E5
MOD16.M16_END EQU $4074
VEC_MUSIC_TWANG EQU $C858
Vec_Joy_Resltn EQU $C81A
DRAW_VL_B EQU $F3D2
MOV_DRAW_VLC_A EQU $F3AD
Vec_Cold_Flag EQU $CBFE
Vec_NMI_Vector EQU $CBFB
music8 EQU $FEF8
VEC_SND_SHADOW EQU $C800
Vec_Twang_Table EQU $C851
DELAY_1 EQU $F575
Vec_Snd_Shadow EQU $C800
CLEAR_SOUND EQU $F272
VEC_SEED_PTR EQU $C87B
Vec_Music_Wk_5 EQU $C847
Vec_Num_Players EQU $C879
Joy_Analog EQU $F1F5
ROT_VL_DFT EQU $F637
Draw_VLp EQU $F410
MUSIC4 EQU $FDD3
DELAY_3 EQU $F56D
Print_Str_d EQU $F37A
Vec_Dot_Dwell EQU $C828
New_High_Score EQU $F8D8
musicb EQU $FF62
VEC_EXPL_1 EQU $C858
Init_Music_Buf EQU $F533
DRAW_VLP_B EQU $F40E
Add_Score_d EQU $F87C
Print_List EQU $F38A
RAND_MUL_LOOP EQU $408F
Vec_Counter_3 EQU $C830
VEC_PREV_BTNS EQU $C810
ADD_SCORE_A EQU $F85E
VEC_EXPL_CHANB EQU $C85D
Clear_Score EQU $F84F
Delay_1 EQU $F575
Rise_Run_Len EQU $F603
Init_Music_x EQU $F692
Rot_VL_Mode_a EQU $F61F
DP_to_C8 EQU $F1AF
VEC_EXPL_CHAN EQU $C85C
Vec_Button_1_2 EQU $C813
Rot_VL EQU $F616
Rise_Run_X EQU $F5FF
MOD16 EQU $4030
Dec_3_Counters EQU $F55A
MUSIC8 EQU $FEF8
VEC_PATTERN EQU $C829
Vec_Loop_Count EQU $C825
Moveto_d EQU $F312
Vec_Expl_Chans EQU $C854
DCR_after_intensity EQU $40FE
VEC_COUNTER_3 EQU $C830
COMPARE_SCORE EQU $F8C7
Mov_Draw_VLc_a EQU $F3AD
VEC_JOY_2_Y EQU $C81E
Vec_Music_Twang EQU $C858
VEC_COUNTER_5 EQU $C832
VEC_EXPL_CHANA EQU $C853
Random EQU $F517
Vec_Expl_Chan EQU $C85C
DRAW_VLCS EQU $F3D6
DRAW_PAT_VL_D EQU $F439
DRAW_GRID_VL EQU $FF9F
Moveto_d_7F EQU $F2FC
Draw_VL_ab EQU $F3D8
DELAY_RTS EQU $F57D
Vec_FIRQ_Vector EQU $CBF5
Dec_6_Counters EQU $F55E
RAND_HELPER EQU $4084
Rot_VL_ab EQU $F610
DRAW_VLP_SCALE EQU $F40C
Delay_b EQU $F57A
VEC_RANDOM_SEED EQU $C87D
Move_Mem_a_1 EQU $F67F
Vec_Max_Games EQU $C850
Vec_Prev_Btns EQU $C810
DRAW_VL_A EQU $F3DA
PRINT_LIST_CHK EQU $F38C
MOV_DRAW_VL_D EQU $F3BE
DELAY_B EQU $F57A
Draw_Line_d EQU $F3DF
Moveto_ix_FF EQU $F308
Print_Str EQU $F495
PRINT_SHIPS EQU $F393
Vec_Expl_ChanA EQU $C853
Moveto_ix_a EQU $F30E
Init_VIA EQU $F14C
DO_SOUND EQU $F289
VEC_SWI_VECTOR EQU $CBFB
VEC_MUSIC_WK_1 EQU $C84B
Abs_b EQU $F58B
VEC_IRQ_VECTOR EQU $CBF8
VEC_EXPL_FLAG EQU $C867
VEC_BUTTON_1_3 EQU $C814
SOUND_BYTE_X EQU $F259
Rise_Run_Y EQU $F601
musica EQU $FF44
Vec_Misc_Count EQU $C823
MOVETO_D_7F EQU $F2FC
VEC_JOY_MUX_2_Y EQU $C822
VEC_COLD_FLAG EQU $CBFE
MUSIC1 EQU $FD0D
Clear_x_d EQU $F548
RAND_MUL_DONE EQU $409A
DRAW_VLP EQU $F410
Vec_Music_Wk_7 EQU $C845
Vec_Button_2_2 EQU $C817
Vec_Expl_1 EQU $C858
Vec_Run_Index EQU $C837
Vec_Text_Width EQU $C82B
Joy_Digital EQU $F1F8
NEW_HIGH_SCORE EQU $F8D8
MOVETO_IX_7F EQU $F30C
VEC_NMI_VECTOR EQU $CBFB
MOVETO_IX EQU $F310
VEC_SWI2_VECTOR EQU $CBF2
ADD_SCORE_D EQU $F87C
Vec_Music_Wk_A EQU $C842
CLEAR_X_256 EQU $F545
VEC_MUSIC_WK_7 EQU $C845
OBJ_WILL_HIT EQU $F8F3
VEC_LOOP_COUNT EQU $C825
Reset_Pen EQU $F35B
ABS_A_B EQU $F584
DRAW_PAT_VL EQU $F437
VEC_RISERUN_LEN EQU $C83B
Print_Ships_x EQU $F391
Vec_SWI3_Vector EQU $CBF2
VEC_FIRQ_VECTOR EQU $CBF5
WAIT_RECAL EQU $F192
CLEAR_X_B EQU $F53F
music7 EQU $FEC6
Clear_Sound EQU $F272
XFORM_RUN_A EQU $F65B
Vec_Expl_Timer EQU $C877
Intensity_5F EQU $F2A5
Dec_Counters EQU $F563
Vec_Rfrsh_lo EQU $C83D
Vec_Btn_State EQU $C80F
Clear_x_b_80 EQU $F550
Explosion_Snd EQU $F92E
PRINT_STR_YX EQU $F378
READ_BTNS_MASK EQU $F1B4
Dot_ix_b EQU $F2BE
VEC_JOY_2_X EQU $C81D
INIT_OS_RAM EQU $F164
Read_Btns_Mask EQU $F1B4
Vec_Counter_1 EQU $C82E
Vec_Brightness EQU $C827
INIT_MUSIC_CHK EQU $F687
Print_Ships EQU $F393
MOVETO_IX_FF EQU $F308
VEC_JOY_MUX_2_X EQU $C821
VEC_FREQ_TABLE EQU $C84D
VEC_BUTTON_1_1 EQU $C812
JOY_ANALOG EQU $F1F5
Print_List_chk EQU $F38C
VEC_BUTTON_1_2 EQU $C813
Vec_Button_2_4 EQU $C819
DOT_LIST_RESET EQU $F2DE
Vec_ADSR_Timers EQU $C85E
RISE_RUN_X EQU $F5FF
Reset0Ref_D0 EQU $F34A
Abs_a_b EQU $F584
VEC_RFRSH_LO EQU $C83D
VEC_MUSIC_CHAN EQU $C855
VEC_BTN_STATE EQU $C80F
MUSIC6 EQU $FE76
Init_Music EQU $F68D
music2 EQU $FD1D
MOVETO_D EQU $F312
MUSIC7 EQU $FEC6
MOD16.M16_DONE EQU $4083
Vec_Expl_3 EQU $C85A
Vec_Num_Game EQU $C87A
DOT_IX_B EQU $F2BE
Vec_Expl_4 EQU $C85B
Draw_VLp_FF EQU $F404
VEC_RFRSH_HI EQU $C83E
VEC_JOY_MUX_1_Y EQU $C820
CLEAR_X_D EQU $F548
VEC_TEXT_WIDTH EQU $C82B
DOT_IX EQU $F2C1
DEC_COUNTERS EQU $F563
Mov_Draw_VLcs EQU $F3B5
VEC_SWI3_VECTOR EQU $CBF2
INIT_VIA EQU $F14C
Vec_Expl_ChanB EQU $C85D
VEC_COUNTER_6 EQU $C833
Vec_Freq_Table EQU $C84D
MUSICA EQU $FF44
RRH_MOD EQU $40B8
VEC_RUN_INDEX EQU $C837
musicd EQU $FF8F
DRAW_VLP_FF EQU $F404
Vec_Random_Seed EQU $C87D
Vec_Text_Height EQU $C82A
Vec_Music_Chan EQU $C855
EXPLOSION_SND EQU $F92E
Sound_Byte_x EQU $F259
MUSIC3 EQU $FD81
Vec_Button_2_3 EQU $C818
Print_Str_yx EQU $F378
PRINT_LIST_HW EQU $F385
VEC_EXPL_CHANS EQU $C854
RESET_PEN EQU $F35B
VEC_COUNTERS EQU $C82E
Vec_Angle EQU $C836
RANDOM EQU $F517
Draw_VLc EQU $F3CE
Check0Ref EQU $F34F
WARM_START EQU $F06C
SET_REFRESH EQU $F1A2
SELECT_GAME EQU $F7A9
VEC_NUM_GAME EQU $C87A
VEC_RFRSH EQU $C83D
VEC_ADSR_TIMERS EQU $C85E
Vec_Music_Wk_1 EQU $C84B
RAND_RANGE_HELPER EQU $40A5
Draw_Grid_VL EQU $FF9F
Vec_Joy_1_Y EQU $C81C
Mov_Draw_VL_ab EQU $F3B7
INTENSITY_A EQU $F2AB
DOT_HERE EQU $F2C5
Draw_Pat_VL_a EQU $F434
SOUND_BYTES_X EQU $F284
Draw_Pat_VL_d EQU $F439
MOD16.M16_LOOP EQU $4064
VEC_COUNTER_2 EQU $C82F
Delay_RTS EQU $F57D
Rise_Run_Angle EQU $F593
VEC_BUTTON_2_4 EQU $C819
Set_Refresh EQU $F1A2
SOUND_BYTES EQU $F27D
Moveto_ix EQU $F310
PRINT_STR_HWYX EQU $F373
ROT_VL_MODE_A EQU $F61F
MOVETO_X_7F EQU $F2F2
VEC_JOY_RESLTN EQU $C81A
CLEAR_C8_RAM EQU $F542
INIT_MUSIC EQU $F68D
Vec_Music_Freq EQU $C861
music5 EQU $FE38
RECALIBRATE EQU $F2E6
MUSIC5 EQU $FE38
DRAW_PAT_VL_A EQU $F434
Vec_Counters EQU $C82E
Vec_Duration EQU $C857
VEC_MAX_PLAYERS EQU $C84F
VEC_COUNTER_1 EQU $C82E
PRINT_SHIPS_X EQU $F391
DRAW_CIRCLE_RUNTIME EQU $40C6
RISE_RUN_Y EQU $F601
Wait_Recal EQU $F192
Dot_here EQU $F2C5
Vec_Str_Ptr EQU $C82C
Vec_Rise_Index EQU $C839
Intensity_3F EQU $F2A1
music4 EQU $FDD3
Vec_Joy_Mux EQU $C81F
Do_Sound_x EQU $F28C
Draw_VL_a EQU $F3DA
MUSICB EQU $FF62
Draw_VLp_scale EQU $F40C
Mov_Draw_VL_a EQU $F3B9
MOV_DRAW_VL_A EQU $F3B9
Clear_x_256 EQU $F545
DRAW_LINE_D EQU $F3DF
Vec_Joy_Mux_2_Y EQU $C822
INIT_OS EQU $F18B
DRAW_VLP_7F EQU $F408
Vec_Buttons EQU $C811
Rot_VL_Mode EQU $F62B
Vec_Expl_2 EQU $C859
Vec_Button_1_3 EQU $C814
VEC_EXPL_3 EQU $C85A
JOY_DIGITAL EQU $F1F8
VEC_HIGH_SCORE EQU $CBEB
DOT_LIST EQU $F2D5
Bitmask_a EQU $F57E
PRINT_LIST EQU $F38A
COLD_START EQU $F000
Sound_Bytes_x EQU $F284
Vec_Music_Flag EQU $C856
Rot_VL_dft EQU $F637
VEC_BUTTONS EQU $C811
VEC_MAX_GAMES EQU $C850
DO_SOUND_X EQU $F28C
Draw_VL_mode EQU $F46E
VECTREX_PRINT_TEXT EQU $4000
VEC_MUSIC_WK_5 EQU $C847
Vec_Joy_2_Y EQU $C81E
Vec_Joy_Mux_1_X EQU $C81F
Vec_Counter_6 EQU $C833
VEC_BRIGHTNESS EQU $C827
PRINT_TEXT_STR_2410010819 EQU $420B
PRINT_STR_D EQU $F37A
Do_Sound EQU $F289
DP_TO_D0 EQU $F1AA
Select_Game EQU $F7A9
READ_BTNS EQU $F1BA
Vec_ADSR_Table EQU $C84F
Vec_Pattern EQU $C829
VEC_RISE_INDEX EQU $C839
Vec_Rfrsh EQU $C83D
Clear_C8_RAM EQU $F542
DRAW_VLC EQU $F3CE
STRIP_ZEROS EQU $F8B7
Vec_Counter_5 EQU $C832
Reset0Int EQU $F36B
Vec_Seed_Ptr EQU $C87B
music1 EQU $FD0D
Vec_Button_2_1 EQU $C816
DEC_6_COUNTERS EQU $F55E
RESET0REF_D0 EQU $F34A
DEC_3_COUNTERS EQU $F55A
SOUND_BYTE_RAW EQU $F25B
Xform_Rise_a EQU $F661
VEC_MUSIC_FLAG EQU $C856
DELAY_2 EQU $F571
XFORM_RISE_A EQU $F661
Vec_SWI2_Vector EQU $CBF2
Delay_0 EQU $F579
VEC_EXPL_TIMER EQU $C877
Moveto_x_7F EQU $F2F2
Vec_Joy_2_X EQU $C81D
XFORM_RUN EQU $F65D
Draw_VLcs EQU $F3D6
MOVE_MEM_A EQU $F683
VEC_RISERUN_TMP EQU $C834
Get_Rise_Run EQU $F5EF
music9 EQU $FF26
GET_RISE_RUN EQU $F5EF
Sound_Bytes EQU $F27D
INIT_MUSIC_BUF EQU $F533
INTENSITY_5F EQU $F2A5
VEC_MISC_COUNT EQU $C823
Vec_Counter_2 EQU $C82F
Vec_Text_HW EQU $C82A
RANDOM_3 EQU $F511
Vec_Counter_4 EQU $C831
Delay_3 EQU $F56D
VEC_ADSR_TABLE EQU $C84F
VEC_TWANG_TABLE EQU $C851
VEC_DOT_DWELL EQU $C828
GET_RUN_IDX EQU $F5DB
DCR_INTENSITY_5F EQU $40FB
DRAW_VL_MODE EQU $F46E
VEC_MUSIC_WORK EQU $C83F
RESET0REF EQU $F354
Get_Run_Idx EQU $F5DB
Draw_VLp_b EQU $F40E
VEC_ANGLE EQU $C836
MOV_DRAW_VL_AB EQU $F3B7
VEC_DURATION EQU $C857
DCR_AFTER_INTENSITY EQU $40FE
INTENSITY_1F EQU $F29D
Xform_Run EQU $F65D
MOV_DRAW_VL EQU $F3BC
DRAW_VL_AB EQU $F3D8
INIT_MUSIC_X EQU $F692
MOVETO_IX_A EQU $F30E
Vec_Default_Stk EQU $CBEA
VEC_JOY_1_X EQU $C81B
MUSICC EQU $FF7A
Clear_x_b_a EQU $F552
music6 EQU $FE76
Add_Score_a EQU $F85E
Obj_Will_Hit_u EQU $F8E5
Vec_0Ref_Enable EQU $C824
DP_TO_C8 EQU $F1AF
VEC_TEXT_HW EQU $C82A
Print_Str_hwyx EQU $F373
MOV_DRAW_VLCS EQU $F3B5
Mov_Draw_VL EQU $F3BC
Vec_Max_Players EQU $C84F
Obj_Will_Hit EQU $F8F3
Mov_Draw_VL_b EQU $F3B1
PRINT_STR EQU $F495
MUSIC2 EQU $FD1D
RESET0INT EQU $F36B
VEC_JOY_MUX EQU $C81F
DCR_intensity_5F EQU $40FB
VEC_JOY_MUX_1_X EQU $C81F
VEC_COUNTER_4 EQU $C831
Vec_Music_Ptr EQU $C853
Get_Rise_Idx EQU $F5D9
MUSICD EQU $FF8F
Intensity_7F EQU $F2A9
Init_OS EQU $F18B
Xform_Run_a EQU $F65B
Vec_Joy_Mux_1_Y EQU $C820
Clear_x_b EQU $F53F
DELAY_0 EQU $F579
Draw_VL EQU $F3DD
Delay_2 EQU $F571
MOD16.M16_RPOS EQU $4064
VEC_TEXT_HEIGHT EQU $C82A
Cold_Start EQU $F000
Xform_Rise EQU $F663
RISE_RUN_LEN EQU $F603
Vec_IRQ_Vector EQU $CBF8
Dot_List EQU $F2D5
VEC_STR_PTR EQU $C82C
Vec_Expl_Flag EQU $C867
VEC_NUM_PLAYERS EQU $C879
CLEAR_X_B_80 EQU $F550
VEC_MUSIC_WK_A EQU $C842
music3 EQU $FD81
ABS_B EQU $F58B
Sound_Byte EQU $F256
BITMASK_A EQU $F57E
Strip_Zeros EQU $F8B7
VEC_BUTTON_2_3 EQU $C818
Init_Music_chk EQU $F687
Print_List_hw EQU $F385
Reset0Ref EQU $F354
MUSIC9 EQU $FF26
Vec_Button_1_4 EQU $C815
INTENSITY_7F EQU $F2A9
VEC_BUTTON_2_2 EQU $C817
OBJ_HIT EQU $F8FF
VEC_MUSIC_WK_6 EQU $C846
Vec_RiseRun_Len EQU $C83B
DOT_D EQU $F2C3
VEC_0REF_ENABLE EQU $C824
musicc EQU $FF7A
Sound_Byte_raw EQU $F25B
Draw_VL_b EQU $F3D2
RISE_RUN_ANGLE EQU $F593
Vec_Music_Wk_6 EQU $C846
ROT_VL_AB EQU $F610
Intensity_a EQU $F2AB
MOD16.M16_RCHECK EQU $4055
Recalibrate EQU $F2E6
CLEAR_SCORE EQU $F84F
Dot_ix EQU $F2C1
Mov_Draw_VL_d EQU $F3BE
Moveto_ix_7F EQU $F30C
Random_3 EQU $F511
ROT_VL EQU $F616
Vec_Joy_1_X EQU $C81B
VEC_EXPL_4 EQU $C85B
VEC_BUTTON_1_4 EQU $C815
Vec_Rfrsh_hi EQU $C83E
MOVE_MEM_A_1 EQU $F67F
Obj_Hit EQU $F8FF
INTENSITY_3F EQU $F2A1
Draw_VLp_7F EQU $F408
Draw_Pat_VL EQU $F437
MOV_DRAW_VL_B EQU $F3B1
Dot_d EQU $F2C3
VEC_MUSIC_PTR EQU $C853
VEC_EXPL_2 EQU $C859
VEC_JOY_1_Y EQU $C81C
DRAW_VL EQU $F3DD
Move_Mem_a EQU $F683
CLEAR_X_B_A EQU $F552
XFORM_RISE EQU $F663
VEC_BUTTON_2_1 EQU $C816
CHECK0REF EQU $F34F
Warm_Start EQU $F06C


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "RAND"
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
RAND_SEED            EQU $C880+$0E   ; Random seed for RAND() (2 bytes)
DRAW_CIRCLE_XC       EQU $C880+$10   ; Circle center X (1 bytes)
DRAW_CIRCLE_YC       EQU $C880+$11   ; Circle center Y (1 bytes)
DRAW_CIRCLE_DIAM     EQU $C880+$12   ; Circle diameter (1 bytes)
DRAW_CIRCLE_INTENSITY EQU $C880+$13   ; Circle intensity (1 bytes)
DRAW_CIRCLE_RADIUS   EQU $C880+$14   ; Circle radius (diam/2) - used in segment drawing (1 bytes)
DRAW_CIRCLE_TEMP     EQU $C880+$15   ; Circle temporary buffer (8 bytes: radius16, a, b, c, d, --, --)  a=0.383r b=0.324r c=0.217r d=0.076r (8 bytes)
DRAW_LINE_ARGS       EQU $C880+$1D   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$27   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$29   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$2B   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$2C   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$2D   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$2F   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$31   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$32   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_RX1              EQU $C880+$33   ; User variable: rx1 (2 bytes)
VAR_RY1              EQU $C880+$35   ; User variable: ry1 (2 bytes)
VAR_RX2              EQU $C880+$37   ; User variable: rx2 (2 bytes)
VAR_RY2              EQU $C880+$39   ; User variable: ry2 (2 bytes)
VAR_RX3              EQU $C880+$3B   ; User variable: rx3 (2 bytes)
VAR_RY4              EQU $C880+$3D   ; User variable: ry4 (2 bytes)
VAR_RY3              EQU $C880+$3F   ; User variable: ry3 (2 bytes)
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
    STD VAR_RX1
    LDD #0
    STD VAR_RY1
    LDD #0
    STD VAR_RX2
    LDD #0
    STD VAR_RY2
    LDD #0
    STD VAR_RX3
    LDD #0
    STD VAR_RY4
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
    STD VAR_RX1
    LDD #0
    STD VAR_RY1
    LDD #0
    STD VAR_RX2
    LDD #0
    STD VAR_RY2
    LDD #0
    STD VAR_RX3
    LDD #0
    STD VAR_RY4

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    ; PRINT_TEXT: Print text at position
    LDD #-50
    STD VAR_ARG0
    LDD #90
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2410010819      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; RAND_RANGE: Random in range [min, max]
    LDD #-80
    STD TMPPTR     ; Save min
    LDD #80
    STD TMPPTR2    ; Save max
    JSR RAND_RANGE_HELPER
    STD RESULT
    STD VAR_RX1
    ; RAND_RANGE: Random in range [min, max]
    LDD #-60
    STD TMPPTR     ; Save min
    LDD #60
    STD TMPPTR2    ; Save max
    JSR RAND_RANGE_HELPER
    STD RESULT
    STD VAR_RY1
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD >VAR_RX1
    TFR B,A
    STA DRAW_CIRCLE_XC
    LDD >VAR_RY1
    TFR B,A
    STA DRAW_CIRCLE_YC
    LDD #20
    TFR B,A
    STA DRAW_CIRCLE_DIAM
    LDD #100
    TFR B,A
    STA DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    ; RAND_RANGE: Random in range [min, max]
    LDD #-80
    STD TMPPTR     ; Save min
    LDD #80
    STD TMPPTR2    ; Save max
    JSR RAND_RANGE_HELPER
    STD RESULT
    STD VAR_RX2
    ; RAND_RANGE: Random in range [min, max]
    LDD #-60
    STD TMPPTR     ; Save min
    LDD #60
    STD TMPPTR2    ; Save max
    JSR RAND_RANGE_HELPER
    STD RESULT
    STD VAR_RY2
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD >VAR_RX2
    TFR B,A
    STA DRAW_CIRCLE_XC
    LDD >VAR_RY2
    TFR B,A
    STA DRAW_CIRCLE_YC
    LDD #20
    TFR B,A
    STA DRAW_CIRCLE_DIAM
    LDD #80
    TFR B,A
    STA DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    ; RAND_RANGE: Random in range [min, max]
    LDD #-80
    STD TMPPTR     ; Save min
    LDD #80
    STD TMPPTR2    ; Save max
    JSR RAND_RANGE_HELPER
    STD RESULT
    STD VAR_RX3
    ; RAND_RANGE: Random in range [min, max]
    LDD #-60
    STD TMPPTR     ; Save min
    LDD #60
    STD TMPPTR2    ; Save max
    JSR RAND_RANGE_HELPER
    STD RESULT
    STD VAR_RY3
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD >VAR_RX3
    TFR B,A
    STA DRAW_CIRCLE_XC
    LDD >VAR_RY3
    TFR B,A
    STA DRAW_CIRCLE_YC
    LDD #20
    TFR B,A
    STA DRAW_CIRCLE_DIAM
    LDD #60
    TFR B,A
    STA DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    RTS


; ================================================
