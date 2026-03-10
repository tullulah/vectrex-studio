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
DRAW_VEC_INTENSITY   EQU $C880+$1D   ; Vector intensity override (0=use vector data) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$1E   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$28   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$2A   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$2C   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$2D   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$2E   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$30   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$32   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$33   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_RX1              EQU $C880+$34   ; User variable: RX1 (2 bytes)
VAR_RY1              EQU $C880+$36   ; User variable: RY1 (2 bytes)
VAR_RX2              EQU $C880+$38   ; User variable: RX2 (2 bytes)
VAR_RY2              EQU $C880+$3A   ; User variable: RY2 (2 bytes)
VAR_RX3              EQU $C880+$3C   ; User variable: RX3 (2 bytes)
VAR_RY4              EQU $C880+$3E   ; User variable: RY4 (2 bytes)
VAR_RY3              EQU $C880+$40   ; User variable: RY3 (2 bytes)
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
DRAW_PAT_VL_D EQU $F439
Sound_Byte EQU $F256
VEC_SND_SHADOW EQU $C800
DP_to_D0 EQU $F1AA
MUSIC4 EQU $FDD3
OBJ_WILL_HIT_U EQU $F8E5
VEC_RISE_INDEX EQU $C839
CLEAR_X_B_A EQU $F552
VEC_FIRQ_VECTOR EQU $CBF5
DRAW_LINE_D EQU $F3DF
VEC_PATTERN EQU $C829
PRINT_STR EQU $F495
Init_Music_x EQU $F692
VEC_EXPL_4 EQU $C85B
Select_Game EQU $F7A9
ROT_VL_AB EQU $F610
Moveto_d EQU $F312
MOVETO_X_7F EQU $F2F2
Clear_x_d EQU $F548
MOV_DRAW_VL_AB EQU $F3B7
Vec_Str_Ptr EQU $C82C
Clear_x_b EQU $F53F
Dec_6_Counters EQU $F55E
VEC_TEXT_HEIGHT EQU $C82A
SOUND_BYTES_X EQU $F284
GET_RISE_RUN EQU $F5EF
music1 EQU $FD0D
Delay_3 EQU $F56D
MOVE_MEM_A EQU $F683
MOD16.M16_DPOS EQU $404D
Vec_SWI2_Vector EQU $CBF2
Draw_VLp_b EQU $F40E
Vec_Text_Width EQU $C82B
INTENSITY_7F EQU $F2A9
Get_Run_Idx EQU $F5DB
Vec_ADSR_Timers EQU $C85E
MUSIC2 EQU $FD1D
Vec_Angle EQU $C836
DRAW_VL EQU $F3DD
Vec_Text_Height EQU $C82A
SOUND_BYTE_X EQU $F259
Intensity_3F EQU $F2A1
MOVETO_IX_FF EQU $F308
Vec_SWI3_Vector EQU $CBF2
VEC_EXPL_3 EQU $C85A
Vec_Freq_Table EQU $C84D
VEC_BUTTONS EQU $C811
VEC_JOY_2_X EQU $C81D
RESET0INT EQU $F36B
XFORM_RISE EQU $F663
DELAY_2 EQU $F571
Vec_RiseRun_Tmp EQU $C834
VEC_SWI2_VECTOR EQU $CBF2
Print_Str_d EQU $F37A
VEC_MUSIC_TWANG EQU $C858
Vec_ADSR_Table EQU $C84F
Vec_Run_Index EQU $C837
INIT_VIA EQU $F14C
Dot_ix EQU $F2C1
music4 EQU $FDD3
Vec_Random_Seed EQU $C87D
Obj_Will_Hit EQU $F8F3
Rot_VL_Mode EQU $F62B
VEC_COUNTER_5 EQU $C832
SELECT_GAME EQU $F7A9
VEC_JOY_MUX_1_Y EQU $C820
VEC_NMI_VECTOR EQU $CBFB
Vec_Max_Games EQU $C850
music5 EQU $FE38
XFORM_RISE_A EQU $F661
Vec_IRQ_Vector EQU $CBF8
Rise_Run_Angle EQU $F593
Abs_a_b EQU $F584
VEC_ADSR_TIMERS EQU $C85E
Xform_Run_a EQU $F65B
VEC_JOY_RESLTN EQU $C81A
DO_SOUND_X EQU $F28C
VEC_0REF_ENABLE EQU $C824
Vec_Music_Flag EQU $C856
Draw_Pat_VL_d EQU $F439
VEC_MUSIC_WK_5 EQU $C847
DRAW_PAT_VL_A EQU $F434
VEC_SWI_VECTOR EQU $CBFB
Intensity_a EQU $F2AB
Draw_VL_mode EQU $F46E
ADD_SCORE_D EQU $F87C
OBJ_WILL_HIT EQU $F8F3
DOT_LIST_RESET EQU $F2DE
GET_RISE_IDX EQU $F5D9
Abs_b EQU $F58B
VEC_EXPL_2 EQU $C859
Vec_Music_Wk_5 EQU $C847
Print_Str_yx EQU $F378
Vec_Seed_Ptr EQU $C87B
Moveto_d_7F EQU $F2FC
Vec_Pattern EQU $C829
Vec_Button_1_2 EQU $C813
Reset0Int EQU $F36B
MUSIC1 EQU $FD0D
Do_Sound EQU $F289
Vec_Joy_Mux_2_Y EQU $C822
VEC_JOY_MUX EQU $C81F
Mov_Draw_VL_ab EQU $F3B7
Vec_Counter_6 EQU $C833
VEC_MUSIC_WORK EQU $C83F
Vec_Dot_Dwell EQU $C828
CLEAR_C8_RAM EQU $F542
Sound_Bytes EQU $F27D
INIT_MUSIC_BUF EQU $F533
Dot_ix_b EQU $F2BE
MOD16.M16_LOOP EQU $4064
Draw_VLp_FF EQU $F404
DELAY_1 EQU $F575
VEC_BUTTON_2_2 EQU $C817
Draw_Line_d EQU $F3DF
Warm_Start EQU $F06C
music7 EQU $FEC6
EXPLOSION_SND EQU $F92E
Vec_Expl_Chan EQU $C85C
Intensity_7F EQU $F2A9
Init_OS_RAM EQU $F164
VEC_JOY_1_X EQU $C81B
VEC_BUTTON_2_4 EQU $C819
PRINT_LIST_HW EQU $F385
VEC_COUNTERS EQU $C82E
WARM_START EQU $F06C
DCR_intensity_5F EQU $40FB
Vec_Joy_2_Y EQU $C81E
musicc EQU $FF7A
VEC_TWANG_TABLE EQU $C851
Reset0Ref_D0 EQU $F34A
DOT_LIST EQU $F2D5
Random EQU $F517
INIT_MUSIC EQU $F68D
MOD16.M16_RCHECK EQU $4055
Print_Ships_x EQU $F391
VEC_BRIGHTNESS EQU $C827
Sound_Bytes_x EQU $F284
Vec_Joy_1_X EQU $C81B
VEC_RISERUN_TMP EQU $C834
New_High_Score EQU $F8D8
Init_VIA EQU $F14C
RAND_HELPER EQU $4084
VEC_SWI3_VECTOR EQU $CBF2
SOUND_BYTE EQU $F256
MUSIC6 EQU $FE76
PRINT_LIST EQU $F38A
Mov_Draw_VL EQU $F3BC
Mov_Draw_VLcs EQU $F3B5
VEC_TEXT_HW EQU $C82A
Vec_Buttons EQU $C811
JOY_DIGITAL EQU $F1F8
Bitmask_a EQU $F57E
ABS_A_B EQU $F584
Delay_0 EQU $F579
Check0Ref EQU $F34F
Vec_Rfrsh EQU $C83D
Vec_Counters EQU $C82E
Read_Btns_Mask EQU $F1B4
DELAY_0 EQU $F579
DRAW_VLCS EQU $F3D6
DEC_3_COUNTERS EQU $F55A
VEC_BUTTON_2_1 EQU $C816
VEC_RFRSH_LO EQU $C83D
DOT_IX EQU $F2C1
Vec_Music_Ptr EQU $C853
COMPARE_SCORE EQU $F8C7
RECALIBRATE EQU $F2E6
Vec_Joy_2_X EQU $C81D
Delay_2 EQU $F571
DOT_HERE EQU $F2C5
DRAW_VLP_B EQU $F40E
Vec_Joy_Mux_2_X EQU $C821
music2 EQU $FD1D
MOV_DRAW_VL_A EQU $F3B9
VEC_ADSR_TABLE EQU $C84F
MOV_DRAW_VL_D EQU $F3BE
Vec_NMI_Vector EQU $CBFB
Vec_FIRQ_Vector EQU $CBF5
Joy_Analog EQU $F1F5
Vec_Button_2_2 EQU $C817
VEC_BUTTON_2_3 EQU $C818
JOY_ANALOG EQU $F1F5
DRAW_VL_MODE EQU $F46E
Moveto_x_7F EQU $F2F2
Vec_Expl_ChanB EQU $C85D
Vec_Brightness EQU $C827
Vec_Expl_Chans EQU $C854
VEC_COUNTER_4 EQU $C831
DRAW_VL_B EQU $F3D2
READ_BTNS_MASK EQU $F1B4
Rise_Run_Len EQU $F603
MUSICC EQU $FF7A
INTENSITY_A EQU $F2AB
VEC_MISC_COUNT EQU $C823
Draw_Grid_VL EQU $FF9F
Vec_High_Score EQU $CBEB
Vec_Counter_4 EQU $C831
Dot_List EQU $F2D5
Vec_Twang_Table EQU $C851
MOD16.M16_DONE EQU $4083
DCR_INTENSITY_5F EQU $40FB
VEC_MUSIC_PTR EQU $C853
Print_List_hw EQU $F385
MOVETO_D EQU $F312
Xform_Run EQU $F65D
VEC_JOY_MUX_1_X EQU $C81F
music3 EQU $FD81
RRH_MOD EQU $40B8
ROT_VL_MODE_A EQU $F61F
VEC_NUM_GAME EQU $C87A
Reset_Pen EQU $F35B
Vec_Joy_Mux EQU $C81F
Moveto_ix_a EQU $F30E
NEW_HIGH_SCORE EQU $F8D8
Vec_Counter_2 EQU $C82F
BITMASK_A EQU $F57E
musicd EQU $FF8F
XFORM_RUN_A EQU $F65B
Draw_VL_b EQU $F3D2
Add_Score_a EQU $F85E
Vec_SWI_Vector EQU $CBFB
DRAW_PAT_VL EQU $F437
Vec_Music_Wk_7 EQU $C845
VEC_MUSIC_WK_6 EQU $C846
Clear_x_b_a EQU $F552
Mov_Draw_VL_d EQU $F3BE
VEC_PREV_BTNS EQU $C810
DRAW_GRID_VL EQU $FF9F
DELAY_3 EQU $F56D
MOD16.M16_END EQU $4074
VEC_DOT_DWELL EQU $C828
VEC_MUSIC_FLAG EQU $C856
Cold_Start EQU $F000
Draw_VL_ab EQU $F3D8
Intensity_1F EQU $F29D
Draw_Pat_VL EQU $F437
Vec_Joy_1_Y EQU $C81C
CLEAR_SCORE EQU $F84F
MUSICA EQU $FF44
Compare_Score EQU $F8C7
VEC_RISERUN_LEN EQU $C83B
Draw_VLp EQU $F410
Print_Ships EQU $F393
RAND_MUL_LOOP EQU $408F
ROT_VL_MODE EQU $F62B
SOUND_BYTES EQU $F27D
VEC_BUTTON_1_1 EQU $C812
DCR_after_intensity EQU $40FE
Strip_Zeros EQU $F8B7
MOD16.M16_RPOS EQU $4064
DP_TO_C8 EQU $F1AF
VEC_EXPL_CHANB EQU $C85D
VEC_EXPL_CHANS EQU $C854
Vec_Num_Game EQU $C87A
MOV_DRAW_VLC_A EQU $F3AD
MOVETO_IX_7F EQU $F30C
DRAW_VLP_FF EQU $F404
Vec_Rfrsh_lo EQU $C83D
Rise_Run_Y EQU $F601
MOV_DRAW_VLCS EQU $F3B5
ROT_VL_DFT EQU $F637
Joy_Digital EQU $F1F8
VEC_MAX_GAMES EQU $C850
VEC_JOY_1_Y EQU $C81C
RESET_PEN EQU $F35B
RESET0REF_D0 EQU $F34A
music8 EQU $FEF8
Intensity_5F EQU $F2A5
DRAW_VL_AB EQU $F3D8
RANDOM_3 EQU $F511
INIT_MUSIC_X EQU $F692
Init_Music EQU $F68D
Obj_Will_Hit_u EQU $F8E5
PRINT_SHIPS EQU $F393
Vec_Joy_Mux_1_X EQU $C81F
Draw_VL EQU $F3DD
PRINT_TEXT_STR_2410010819 EQU $420B
MOD16 EQU $4030
RESET0REF EQU $F354
Vec_Text_HW EQU $C82A
CLEAR_X_D EQU $F548
VEC_MUSIC_WK_7 EQU $C845
Vec_Button_1_3 EQU $C814
Vec_Rfrsh_hi EQU $C83E
Print_List EQU $F38A
COLD_START EQU $F000
VEC_MUSIC_WK_A EQU $C842
VEC_ANGLE EQU $C836
Vec_Music_Work EQU $C83F
Vec_Expl_2 EQU $C859
Set_Refresh EQU $F1A2
CHECK0REF EQU $F34F
DELAY_B EQU $F57A
MUSIC9 EQU $FF26
Vec_Duration EQU $C857
Vec_Expl_4 EQU $C85B
XFORM_RUN EQU $F65D
INTENSITY_5F EQU $F2A5
DCR_AFTER_INTENSITY EQU $40FE
Init_OS EQU $F18B
DRAW_VLP EQU $F410
PRINT_LIST_CHK EQU $F38C
VEC_RUN_INDEX EQU $C837
VEC_COUNTER_3 EQU $C830
Reset0Ref EQU $F354
Vec_Cold_Flag EQU $CBFE
Init_Music_chk EQU $F687
Print_Str_hwyx EQU $F373
VECTREX_PRINT_TEXT EQU $4000
READ_BTNS EQU $F1BA
VEC_EXPL_CHAN EQU $C85C
STRIP_ZEROS EQU $F8B7
VEC_EXPL_CHANA EQU $C853
Vec_Music_Freq EQU $C861
MUSIC5 EQU $FE38
VEC_EXPL_TIMER EQU $C877
CLEAR_X_256 EQU $F545
Draw_VLcs EQU $F3D6
Clear_x_256 EQU $F545
VEC_JOY_MUX_2_X EQU $C821
Vec_Counter_1 EQU $C82E
Init_Music_Buf EQU $F533
Xform_Rise_a EQU $F661
Mov_Draw_VL_a EQU $F3B9
Vec_Loop_Count EQU $C825
music6 EQU $FE76
Print_List_chk EQU $F38C
RISE_RUN_LEN EQU $F603
ABS_B EQU $F58B
MOV_DRAW_VL EQU $F3BC
Vec_Default_Stk EQU $CBEA
Vec_Rise_Index EQU $C839
Vec_Misc_Count EQU $C823
VEC_EXPL_FLAG EQU $C867
MOVE_MEM_A_1 EQU $F67F
MOVETO_D_7F EQU $F2FC
INIT_OS EQU $F18B
Sound_Byte_x EQU $F259
MOVETO_IX_A EQU $F30E
VEC_JOY_2_Y EQU $C81E
music9 EQU $FF26
INIT_OS_RAM EQU $F164
Mov_Draw_VL_b EQU $F3B1
Vec_0Ref_Enable EQU $C824
Draw_VLp_7F EQU $F408
SET_REFRESH EQU $F1A2
MUSIC8 EQU $FEF8
Vec_Music_Chan EQU $C855
Read_Btns EQU $F1BA
MUSICB EQU $FF62
Moveto_ix EQU $F310
Wait_Recal EQU $F192
VEC_COUNTER_2 EQU $C82F
Vec_Expl_3 EQU $C85A
Dec_3_Counters EQU $F55A
VEC_MUSIC_CHAN EQU $C855
GET_RUN_IDX EQU $F5DB
VEC_JOY_MUX_2_Y EQU $C822
Print_Str EQU $F495
VEC_BTN_STATE EQU $C80F
VEC_DURATION EQU $C857
VEC_EXPL_1 EQU $C858
ADD_SCORE_A EQU $F85E
Rot_VL EQU $F616
Recalibrate EQU $F2E6
VEC_COLD_FLAG EQU $CBFE
CLEAR_SOUND EQU $F272
ROT_VL EQU $F616
RISE_RUN_ANGLE EQU $F593
Rot_VL_dft EQU $F637
VEC_COUNTER_6 EQU $C833
Vec_Expl_ChanA EQU $C853
Add_Score_d EQU $F87C
Delay_RTS EQU $F57D
PRINT_STR_HWYX EQU $F373
Get_Rise_Idx EQU $F5D9
MUSIC7 EQU $FEC6
Get_Rise_Run EQU $F5EF
Mov_Draw_VLc_a EQU $F3AD
DRAW_VL_A EQU $F3DA
MUSICD EQU $FF8F
DOT_D EQU $F2C3
VEC_BUTTON_1_2 EQU $C813
RISE_RUN_X EQU $F5FF
Do_Sound_x EQU $F28C
PRINT_SHIPS_X EQU $F391
VEC_RANDOM_SEED EQU $C87D
musicb EQU $FF62
Vec_Button_1_4 EQU $C815
Vec_Music_Wk_6 EQU $C846
CLEAR_X_B EQU $F53F
Vec_Max_Players EQU $C84F
Vec_Snd_Shadow EQU $C800
VEC_SEED_PTR EQU $C87B
Vec_Music_Twang EQU $C858
Draw_VL_a EQU $F3DA
Obj_Hit EQU $F8FF
Moveto_ix_7F EQU $F30C
VEC_RFRSH_HI EQU $C83E
VEC_FREQ_TABLE EQU $C84D
PRINT_STR_YX EQU $F378
VEC_RFRSH EQU $C83D
Vec_Expl_1 EQU $C858
INTENSITY_3F EQU $F2A1
Vec_Prev_Btns EQU $C810
VEC_DEFAULT_STK EQU $CBEA
Moveto_ix_FF EQU $F308
MOVETO_IX EQU $F310
RISE_RUN_Y EQU $F601
CLEAR_X_B_80 EQU $F550
RAND_MUL_DONE EQU $409A
VEC_MAX_PLAYERS EQU $C84F
Dot_here EQU $F2C5
VEC_LOOP_COUNT EQU $C825
VEC_HIGH_SCORE EQU $CBEB
Xform_Rise EQU $F663
RANDOM EQU $F517
Clear_x_b_80 EQU $F550
Rot_VL_ab EQU $F610
DELAY_RTS EQU $F57D
Rot_VL_Mode_a EQU $F61F
Dot_List_Reset EQU $F2DE
Delay_1 EQU $F575
Move_Mem_a EQU $F683
VEC_TEXT_WIDTH EQU $C82B
VEC_COUNTER_1 EQU $C82E
Clear_Score EQU $F84F
Draw_VLp_scale EQU $F40C
Vec_Expl_Flag EQU $C867
Draw_VLc EQU $F3CE
VEC_MUSIC_FREQ EQU $C861
DP_to_C8 EQU $F1AF
Vec_Counter_5 EQU $C832
Clear_Sound EQU $F272
SOUND_BYTE_RAW EQU $F25B
Vec_Counter_3 EQU $C830
VEC_STR_PTR EQU $C82C
DEC_COUNTERS EQU $F563
DO_SOUND EQU $F289
VEC_NUM_PLAYERS EQU $C879
PRINT_STR_D EQU $F37A
Vec_Music_Wk_A EQU $C842
Sound_Byte_raw EQU $F25B
VEC_IRQ_VECTOR EQU $CBF8
Dot_d EQU $F2C3
INTENSITY_1F EQU $F29D
MOV_DRAW_VL_B EQU $F3B1
VEC_BUTTON_1_4 EQU $C815
Draw_Pat_VL_a EQU $F434
Vec_Btn_State EQU $C80F
Vec_Expl_Timer EQU $C877
Clear_C8_RAM EQU $F542
RAND_RANGE_HELPER EQU $40A5
VEC_BUTTON_1_3 EQU $C814
musica EQU $FF44
Delay_b EQU $F57A
DP_TO_D0 EQU $F1AA
Vec_Joy_Mux_1_Y EQU $C820
DRAW_VLP_7F EQU $F408
Vec_Button_1_1 EQU $C812
WAIT_RECAL EQU $F192
INIT_MUSIC_CHK EQU $F687
VEC_MUSIC_WK_1 EQU $C84B
Vec_Button_2_4 EQU $C819
Vec_Joy_Resltn EQU $C81A
Vec_Button_2_1 EQU $C816
DOT_IX_B EQU $F2BE
Vec_Music_Wk_1 EQU $C84B
DRAW_VLP_SCALE EQU $F40C
Vec_Button_2_3 EQU $C818
Vec_Num_Players EQU $C879
Explosion_Snd EQU $F92E
MUSIC3 EQU $FD81
OBJ_HIT EQU $F8FF
DEC_6_COUNTERS EQU $F55E
Move_Mem_a_1 EQU $F67F
Dec_Counters EQU $F563
DRAW_CIRCLE_RUNTIME EQU $40C6
Vec_RiseRun_Len EQU $C83B
DRAW_VLC EQU $F3CE
Random_3 EQU $F511
Rise_Run_X EQU $F5FF


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
DRAW_VEC_INTENSITY   EQU $C880+$1D   ; Vector intensity override (0=use vector data) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$1E   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$28   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$2A   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$2C   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$2D   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$2E   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$30   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$32   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$33   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_RX1              EQU $C880+$34   ; User variable: RX1 (2 bytes)
VAR_RY1              EQU $C880+$36   ; User variable: RY1 (2 bytes)
VAR_RX2              EQU $C880+$38   ; User variable: RX2 (2 bytes)
VAR_RY2              EQU $C880+$3A   ; User variable: RY2 (2 bytes)
VAR_RX3              EQU $C880+$3C   ; User variable: RX3 (2 bytes)
VAR_RY4              EQU $C880+$3E   ; User variable: RY4 (2 bytes)
VAR_RY3              EQU $C880+$40   ; User variable: RY3 (2 bytes)
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
