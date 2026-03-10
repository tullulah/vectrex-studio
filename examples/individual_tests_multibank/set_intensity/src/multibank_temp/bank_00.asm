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
Strip_Zeros EQU $F8B7
VEC_EXPL_CHANS EQU $C854
Init_Music EQU $F68D
DELAY_2 EQU $F571
PRINT_SHIPS EQU $F393
Vec_High_Score EQU $CBEB
RECALIBRATE EQU $F2E6
MOD16.M16_END EQU $4074
Draw_VLp_b EQU $F40E
DEC_COUNTERS EQU $F563
Add_Score_d EQU $F87C
INIT_OS_RAM EQU $F164
Vec_Buttons EQU $C811
Dot_ix_b EQU $F2BE
Xform_Run EQU $F65D
DOT_IX_B EQU $F2BE
Draw_VLcs EQU $F3D6
Vec_Joy_Mux EQU $C81F
VEC_EXPL_CHAN EQU $C85C
Init_VIA EQU $F14C
INIT_VIA EQU $F14C
VEC_EXPL_TIMER EQU $C877
VEC_TEXT_HEIGHT EQU $C82A
MUSIC2 EQU $FD1D
DRAW_VL_AB EQU $F3D8
Read_Btns EQU $F1BA
Clear_x_d EQU $F548
Vec_Expl_Chans EQU $C854
DRAW_VL_B EQU $F3D2
CLEAR_SOUND EQU $F272
Mov_Draw_VL_ab EQU $F3B7
PRINT_TEXT_STR_48656 EQU $41D2
Vec_Joy_Mux_1_X EQU $C81F
Vec_Joy_1_X EQU $C81B
Rise_Run_Angle EQU $F593
VEC_BUTTON_1_3 EQU $C814
Draw_VLp_FF EQU $F404
MOVETO_IX EQU $F310
Vec_ADSR_Timers EQU $C85E
music9 EQU $FF26
VEC_JOY_MUX_2_X EQU $C821
Vec_Rfrsh_lo EQU $C83D
Vec_Counter_2 EQU $C82F
Vec_Music_Wk_1 EQU $C84B
VEC_JOY_MUX_1_X EQU $C81F
Init_OS_RAM EQU $F164
PRINT_TEXT_STR_1784 EQU $41CF
VEC_RFRSH_HI EQU $C83E
Vec_ADSR_Table EQU $C84F
music5 EQU $FE38
Draw_VLp_scale EQU $F40C
Moveto_d_7F EQU $F2FC
Do_Sound EQU $F289
Vec_Prev_Btns EQU $C810
CLEAR_C8_RAM EQU $F542
Vec_Dot_Dwell EQU $C828
BITMASK_A EQU $F57E
PRINT_TEXT_STR_1691 EQU $41CC
VEC_COLD_FLAG EQU $CBFE
DRAW_VLC EQU $F3CE
VEC_NMI_VECTOR EQU $CBFB
VEC_BUTTON_2_2 EQU $C817
Vec_Joy_Resltn EQU $C81A
Moveto_d EQU $F312
music4 EQU $FDD3
MUSIC5 EQU $FE38
DRAW_PAT_VL EQU $F437
Vec_Counter_3 EQU $C830
Vec_Expl_Chan EQU $C85C
VEC_COUNTER_6 EQU $C833
Mov_Draw_VL_b EQU $F3B1
Vec_SWI3_Vector EQU $CBF2
RESET0REF EQU $F354
MOD16.M16_DONE EQU $4083
VEC_BUTTONS EQU $C811
VEC_RISE_INDEX EQU $C839
Vec_Counter_5 EQU $C832
RESET_PEN EQU $F35B
Rot_VL_ab EQU $F610
VEC_JOY_1_Y EQU $C81C
DEC_3_COUNTERS EQU $F55A
INIT_MUSIC_CHK EQU $F687
GET_RISE_RUN EQU $F5EF
CLEAR_X_B_80 EQU $F550
Move_Mem_a_1 EQU $F67F
Print_List_chk EQU $F38C
VEC_MUSIC_WK_1 EQU $C84B
VEC_MUSIC_TWANG EQU $C858
Vec_Freq_Table EQU $C84D
VEC_BRIGHTNESS EQU $C827
OBJ_WILL_HIT EQU $F8F3
PRINT_TEXT_STR_48694 EQU $41D6
VEC_SWI2_VECTOR EQU $CBF2
ABS_B EQU $F58B
GET_RISE_IDX EQU $F5D9
INIT_MUSIC EQU $F68D
MUSICD EQU $FF8F
VEC_BUTTON_1_2 EQU $C813
Vec_NMI_Vector EQU $CBFB
EXPLOSION_SND EQU $F92E
Init_Music_x EQU $F692
RISE_RUN_Y EQU $F601
Vec_Expl_ChanB EQU $C85D
Vec_Angle EQU $C836
Vec_Num_Game EQU $C87A
Vec_Expl_3 EQU $C85A
Vec_Str_Ptr EQU $C82C
DOT_LIST_RESET EQU $F2DE
DCR_intensity_5F EQU $40B9
ROT_VL_MODE_A EQU $F61F
PRINT_STR EQU $F495
Wait_Recal EQU $F192
INTENSITY_1F EQU $F29D
Vec_Rise_Index EQU $C839
VEC_HIGH_SCORE EQU $CBEB
VEC_BTN_STATE EQU $C80F
VEC_EXPL_CHANA EQU $C853
VEC_COUNTERS EQU $C82E
VEC_COUNTER_2 EQU $C82F
Vec_Loop_Count EQU $C825
Vec_Text_Width EQU $C82B
Vec_Button_2_4 EQU $C819
Random_3 EQU $F511
New_High_Score EQU $F8D8
READ_BTNS_MASK EQU $F1B4
VEC_ANGLE EQU $C836
VEC_ADSR_TIMERS EQU $C85E
ADD_SCORE_D EQU $F87C
DP_TO_D0 EQU $F1AA
CLEAR_X_B EQU $F53F
COMPARE_SCORE EQU $F8C7
Vec_Duration EQU $C857
PRINT_LIST EQU $F38A
VEC_RANDOM_SEED EQU $C87D
Set_Refresh EQU $F1A2
VEC_DURATION EQU $C857
DELAY_3 EQU $F56D
Check0Ref EQU $F34F
Random EQU $F517
DRAW_LINE_D EQU $F3DF
Vec_Music_Ptr EQU $C853
DRAW_VLP_7F EQU $F408
Mov_Draw_VLc_a EQU $F3AD
VEC_EXPL_2 EQU $C859
Mov_Draw_VL_d EQU $F3BE
Do_Sound_x EQU $F28C
DELAY_0 EQU $F579
Vec_Counter_4 EQU $C831
Print_Str EQU $F495
VEC_JOY_MUX_2_Y EQU $C822
DELAY_1 EQU $F575
Delay_3 EQU $F56D
Abs_b EQU $F58B
Moveto_x_7F EQU $F2F2
Clear_x_b_80 EQU $F550
SOUND_BYTES EQU $F27D
Sound_Byte EQU $F256
XFORM_RISE_A EQU $F661
Get_Rise_Run EQU $F5EF
RISE_RUN_LEN EQU $F603
Warm_Start EQU $F06C
Clear_Sound EQU $F272
Intensity_a EQU $F2AB
Vec_Music_Freq EQU $C861
VEC_BUTTON_2_3 EQU $C818
DOT_D EQU $F2C3
Clear_x_256 EQU $F545
INTENSITY_7F EQU $F2A9
Delay_RTS EQU $F57D
Rise_Run_Y EQU $F601
DRAW_PAT_VL_A EQU $F434
VEC_EXPL_FLAG EQU $C867
Obj_Will_Hit_u EQU $F8E5
Vec_Twang_Table EQU $C851
Vec_Text_Height EQU $C82A
music6 EQU $FE76
VEC_JOY_MUX_1_Y EQU $C820
DP_to_C8 EQU $F1AF
ROT_VL_AB EQU $F610
Vec_Expl_ChanA EQU $C853
VEC_MAX_PLAYERS EQU $C84F
DRAW_VL_MODE EQU $F46E
Intensity_1F EQU $F29D
VEC_COUNTER_4 EQU $C831
SOUND_BYTES_X EQU $F284
DP_TO_C8 EQU $F1AF
Rot_VL_Mode EQU $F62B
Vec_RiseRun_Len EQU $C83B
Mov_Draw_VL EQU $F3BC
Vec_Rfrsh_hi EQU $C83E
DO_SOUND_X EQU $F28C
Reset_Pen EQU $F35B
Xform_Rise EQU $F663
INIT_MUSIC_BUF EQU $F533
Reset0Ref_D0 EQU $F34A
DRAW_VLP_FF EQU $F404
Clear_x_b_a EQU $F552
VEC_EXPL_3 EQU $C85A
Vec_Joy_2_Y EQU $C81E
DCR_INTENSITY_5F EQU $40B9
VEC_JOY_2_X EQU $C81D
Vec_SWI2_Vector EQU $CBF2
DELAY_B EQU $F57A
VEC_MUSIC_WORK EQU $C83F
Moveto_ix_7F EQU $F30C
VEC_RISERUN_LEN EQU $C83B
MOD16.M16_RCHECK EQU $4055
ABS_A_B EQU $F584
VEC_BUTTON_1_1 EQU $C812
Compare_Score EQU $F8C7
Bitmask_a EQU $F57E
Dot_d EQU $F2C3
VEC_SWI3_VECTOR EQU $CBF2
MOVETO_IX_7F EQU $F30C
MUSIC9 EQU $FF26
CLEAR_SCORE EQU $F84F
musicc EQU $FF7A
MOD16.M16_DPOS EQU $404D
DO_SOUND EQU $F289
Read_Btns_Mask EQU $F1B4
VEC_TEXT_WIDTH EQU $C82B
INIT_MUSIC_X EQU $F692
VEC_RFRSH EQU $C83D
Vec_Music_Wk_6 EQU $C846
DRAW_PAT_VL_D EQU $F439
Dot_List_Reset EQU $F2DE
Moveto_ix_a EQU $F30E
MUSIC3 EQU $FD81
RANDOM_3 EQU $F511
VEC_FREQ_TABLE EQU $C84D
Draw_VLp_7F EQU $F408
Vec_Expl_2 EQU $C859
music3 EQU $FD81
Vec_Music_Twang EQU $C858
COLD_START EQU $F000
VEC_MUSIC_WK_5 EQU $C847
musicb EQU $FF62
MUSICA EQU $FF44
MOV_DRAW_VLC_A EQU $F3AD
VEC_BUTTON_2_1 EQU $C816
Vec_Button_2_2 EQU $C817
VEC_COUNTER_1 EQU $C82E
VEC_MUSIC_WK_6 EQU $C846
RISE_RUN_X EQU $F5FF
MOD16.M16_RPOS EQU $4064
RESET0INT EQU $F36B
SOUND_BYTE EQU $F256
Print_List EQU $F38A
Rot_VL EQU $F616
RANDOM EQU $F517
Draw_VL_b EQU $F3D2
Vec_Music_Wk_A EQU $C842
OBJ_WILL_HIT_U EQU $F8E5
Vec_Joy_1_Y EQU $C81C
OBJ_HIT EQU $F8FF
VEC_MUSIC_PTR EQU $C853
Init_Music_Buf EQU $F533
VEC_TWANG_TABLE EQU $C851
Draw_VL EQU $F3DD
DRAW_GRID_VL EQU $FF9F
VEC_SND_SHADOW EQU $C800
XFORM_RUN EQU $F65D
READ_BTNS EQU $F1BA
Vec_Rfrsh EQU $C83D
VEC_STR_PTR EQU $C82C
ROT_VL_DFT EQU $F637
PRINT_STR_YX EQU $F378
music2 EQU $FD1D
DELAY_RTS EQU $F57D
VEC_JOY_2_Y EQU $C81E
PRINT_STR_HWYX EQU $F373
MOVE_MEM_A EQU $F683
Vec_Music_Wk_7 EQU $C845
Joy_Digital EQU $F1F8
Xform_Rise_a EQU $F661
MOV_DRAW_VLCS EQU $F3B5
Vec_Expl_1 EQU $C858
Vec_Max_Players EQU $C84F
Vec_Run_Index EQU $C837
VEC_LOOP_COUNT EQU $C825
Obj_Will_Hit EQU $F8F3
Draw_Pat_VL_a EQU $F434
VEC_RFRSH_LO EQU $C83D
Vec_Num_Players EQU $C879
VEC_MISC_COUNT EQU $C823
Rot_VL_dft EQU $F637
Vec_Misc_Count EQU $C823
Vec_Joy_Mux_2_Y EQU $C822
Vec_Music_Wk_5 EQU $C847
Draw_VL_a EQU $F3DA
INTENSITY_3F EQU $F2A1
Add_Score_a EQU $F85E
VEC_COUNTER_5 EQU $C832
VEC_TEXT_HW EQU $C82A
SELECT_GAME EQU $F7A9
PRINT_LIST_HW EQU $F385
Vec_Button_1_4 EQU $C815
ROT_VL_MODE EQU $F62B
VEC_RUN_INDEX EQU $C837
DRAW_VLP_B EQU $F40E
Draw_Grid_VL EQU $FF9F
Rise_Run_X EQU $F5FF
VEC_RISERUN_TMP EQU $C834
MOVETO_D EQU $F312
Vec_Joy_2_X EQU $C81D
Dec_Counters EQU $F563
Dot_ix EQU $F2C1
VEC_MUSIC_WK_7 EQU $C845
CLEAR_X_D EQU $F548
DOT_LIST EQU $F2D5
CLEAR_X_256 EQU $F545
Obj_Hit EQU $F8FF
ROT_VL EQU $F616
MOV_DRAW_VL_A EQU $F3B9
music1 EQU $FD0D
Select_Game EQU $F7A9
Dec_6_Counters EQU $F55E
WARM_START EQU $F06C
Print_Str_d EQU $F37A
NEW_HIGH_SCORE EQU $F8D8
DOT_IX EQU $F2C1
MUSIC1 EQU $FD0D
Vec_Button_1_3 EQU $C814
VEC_SEED_PTR EQU $C87B
Vec_FIRQ_Vector EQU $CBF5
VEC_IRQ_VECTOR EQU $CBF8
Reset0Int EQU $F36B
JOY_DIGITAL EQU $F1F8
Vec_Expl_Flag EQU $C867
JOY_ANALOG EQU $F1F5
PRINT_STR_D EQU $F37A
VEC_FIRQ_VECTOR EQU $CBF5
Vec_Counter_1 EQU $C82E
PRINT_SHIPS_X EQU $F391
MOVETO_X_7F EQU $F2F2
DP_to_D0 EQU $F1AA
VEC_MAX_GAMES EQU $C850
Draw_VL_ab EQU $F3D8
Cold_Start EQU $F000
Clear_x_b EQU $F53F
Dot_here EQU $F2C5
DRAW_VLCS EQU $F3D6
Vec_Random_Seed EQU $C87D
Init_Music_chk EQU $F687
MOV_DRAW_VL_D EQU $F3BE
MUSIC8 EQU $FEF8
Vec_Button_1_2 EQU $C813
MOD16.M16_LOOP EQU $4064
MOV_DRAW_VL_AB EQU $F3B7
Vec_Counters EQU $C82E
Abs_a_b EQU $F584
Get_Run_Idx EQU $F5DB
Sound_Byte_raw EQU $F25B
VEC_EXPL_1 EQU $C858
VEC_JOY_1_X EQU $C81B
Rot_VL_Mode_a EQU $F61F
Vec_Pattern EQU $C829
Moveto_ix_FF EQU $F308
Mov_Draw_VLcs EQU $F3B5
VEC_BUTTON_1_4 EQU $C815
Vec_Joy_Mux_1_Y EQU $C820
Clear_C8_RAM EQU $F542
SOUND_BYTE_X EQU $F259
VEC_ADSR_TABLE EQU $C84F
VEC_COUNTER_3 EQU $C830
Vec_Seed_Ptr EQU $C87B
Vec_Counter_6 EQU $C833
VEC_JOY_RESLTN EQU $C81A
VEC_MUSIC_FREQ EQU $C861
VEC_0REF_ENABLE EQU $C824
Vec_Max_Games EQU $C850
MOV_DRAW_VL_B EQU $F3B1
Intensity_7F EQU $F2A9
Draw_VLp EQU $F410
Joy_Analog EQU $F1F5
VECTREX_PRINT_TEXT EQU $4000
VEC_NUM_PLAYERS EQU $C879
DOT_HERE EQU $F2C5
VEC_SWI_VECTOR EQU $CBFB
RESET0REF_D0 EQU $F34A
Intensity_5F EQU $F2A5
VEC_PATTERN EQU $C829
MUSIC4 EQU $FDD3
Vec_Button_2_1 EQU $C816
Mov_Draw_VL_a EQU $F3B9
Vec_Music_Flag EQU $C856
Intensity_3F EQU $F2A1
VEC_DEFAULT_STK EQU $CBEA
Vec_Button_1_1 EQU $C812
Reset0Ref EQU $F354
Sound_Bytes_x EQU $F284
musica EQU $FF44
Init_OS EQU $F18B
PRINT_TEXT_STR_64483629934611 EQU $41DA
Vec_RiseRun_Tmp EQU $C834
music8 EQU $FEF8
VEC_DOT_DWELL EQU $C828
Dot_List EQU $F2D5
Print_Ships_x EQU $F391
VEC_MUSIC_WK_A EQU $C842
DCR_after_intensity EQU $40BC
DEC_6_COUNTERS EQU $F55E
Delay_1 EQU $F575
Draw_Line_d EQU $F3DF
MOVETO_D_7F EQU $F2FC
MUSICB EQU $FF62
DRAW_VL EQU $F3DD
Vec_Btn_State EQU $C80F
MOVETO_IX_A EQU $F30E
RISE_RUN_ANGLE EQU $F593
Draw_VL_mode EQU $F46E
Delay_2 EQU $F571
SET_REFRESH EQU $F1A2
Print_Str_yx EQU $F378
STRIP_ZEROS EQU $F8B7
DRAW_VL_A EQU $F3DA
Clear_Score EQU $F84F
DCR_AFTER_INTENSITY EQU $40BC
INTENSITY_A EQU $F2AB
CHECK0REF EQU $F34F
Vec_0Ref_Enable EQU $C824
XFORM_RUN_A EQU $F65B
VEC_NUM_GAME EQU $C87A
VEC_PREV_BTNS EQU $C810
VEC_JOY_MUX EQU $C81F
Vec_Brightness EQU $C827
MOV_DRAW_VL EQU $F3BC
Vec_Cold_Flag EQU $CBFE
MOD16 EQU $4030
Print_Ships EQU $F393
MOVE_MEM_A_1 EQU $F67F
Delay_b EQU $F57A
Vec_Music_Chan EQU $C855
INIT_OS EQU $F18B
Draw_Pat_VL_d EQU $F439
PRINT_LIST_CHK EQU $F38C
MUSICC EQU $FF7A
Xform_Run_a EQU $F65B
Recalibrate EQU $F2E6
Sound_Byte_x EQU $F259
VEC_MUSIC_CHAN EQU $C855
musicd EQU $FF8F
Vec_Snd_Shadow EQU $C800
DRAW_VLP_SCALE EQU $F40C
VEC_EXPL_CHANB EQU $C85D
Vec_Music_Work EQU $C83F
music7 EQU $FEC6
MUSIC7 EQU $FEC6
Move_Mem_a EQU $F683
VEC_MUSIC_FLAG EQU $C856
PRINT_TEXT_STR_1598 EQU $41C9
Vec_Joy_Mux_2_X EQU $C821
MOVETO_IX_FF EQU $F308
Vec_IRQ_Vector EQU $CBF8
Print_List_hw EQU $F385
SOUND_BYTE_RAW EQU $F25B
Vec_Button_2_3 EQU $C818
Explosion_Snd EQU $F92E
Dec_3_Counters EQU $F55A
Delay_0 EQU $F579
DRAW_VLP EQU $F410
Vec_Default_Stk EQU $CBEA
Draw_VLc EQU $F3CE
Sound_Bytes EQU $F27D
DRAW_CIRCLE_RUNTIME EQU $4084
Draw_Pat_VL EQU $F437
VEC_EXPL_4 EQU $C85B
VEC_BUTTON_2_4 EQU $C819
XFORM_RISE EQU $F663
Vec_Expl_4 EQU $C85B
INTENSITY_5F EQU $F2A5
Rise_Run_Len EQU $F603
Print_Str_hwyx EQU $F373
Moveto_ix EQU $F310
Vec_Text_HW EQU $C82A
CLEAR_X_B_A EQU $F552
MUSIC6 EQU $FE76
Vec_Expl_Timer EQU $C877
Vec_SWI_Vector EQU $CBFB
GET_RUN_IDX EQU $F5DB
WAIT_RECAL EQU $F192
ADD_SCORE_A EQU $F85E
Get_Rise_Idx EQU $F5D9


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
