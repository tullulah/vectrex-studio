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
DRAW_VEC_INTENSITY   EQU $C880+$21   ; Vector intensity override (0=use vector data) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$22   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$2C   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$2E   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$30   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$31   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$32   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$34   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$36   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$37   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_U8_VAL           EQU $C880+$38   ; User variable: U8_VAL (1 bytes)
VAR_I8_VAL           EQU $C880+$39   ; User variable: I8_VAL (1 bytes)
VAR_U16_VAL          EQU $C880+$3A   ; User variable: U16_VAL (2 bytes)
VAR_I16_VAL          EQU $C880+$3C   ; User variable: I16_VAL (2 bytes)
VAR_ROW_Y            EQU $C880+$3E   ; User variable: ROW_Y (2 bytes)
VAR_SELECTED         EQU $C880+$40   ; User variable: SELECTED (1 bytes)
VAR_COOLDOWN         EQU $C880+$41   ; User variable: COOLDOWN (1 bytes)
VAR_ARR_IDX          EQU $C880+$42   ; User variable: ARR_IDX (1 bytes)
VAR_ARR_TICK         EQU $C880+$43   ; User variable: ARR_TICK (1 bytes)
VAR_JOY_Y            EQU $C880+$44   ; User variable: JOY_Y (2 bytes)
VAR_U8_ARR           EQU $C880+$46   ; User variable: U8_ARR (2 bytes)
VAR_I8_ARR           EQU $C880+$48   ; User variable: I8_ARR (2 bytes)
VAR_U16_ARR          EQU $C880+$4A   ; User variable: U16_ARR (2 bytes)
VAR_I16_ARR          EQU $C880+$4C   ; User variable: I16_ARR (2 bytes)
VAR_U8_ARR_DATA      EQU $C880+$4E   ; Mutable array 'U8_ARR' data (4 elements x 1 bytes) (4 bytes)
VAR_I8_ARR_DATA      EQU $C880+$52   ; Mutable array 'I8_ARR' data (4 elements x 1 bytes) (4 bytes)
VAR_U16_ARR_DATA     EQU $C880+$56   ; Mutable array 'U16_ARR' data (4 elements x 2 bytes) (8 bytes)
VAR_I16_ARR_DATA     EQU $C880+$5E   ; Mutable array 'I16_ARR' data (4 elements x 2 bytes) (8 bytes)
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
CLEAR_SOUND EQU $F272
Dec_Counters EQU $F563
MUSIC5 EQU $FE38
PRINT_TEXT_STR_72349 EQU $4295
VECTREX_PRINT_NUMBER.PN_DIV1000 EQU $4050
Get_Run_Idx EQU $F5DB
PRINT_LIST_CHK EQU $F38C
DP_TO_C8 EQU $F1AF
DRAW_VLP_B EQU $F40E
Sound_Byte EQU $F256
Mov_Draw_VL_b EQU $F3B1
Vec_SWI3_Vector EQU $CBF2
XFORM_RUN_A EQU $F65B
Read_Btns_Mask EQU $F1B4
MOVETO_D_7F EQU $F2FC
VEC_NMI_VECTOR EQU $CBFB
Vec_Dot_Dwell EQU $C828
Vec_Music_Flag EQU $C856
VEC_COUNTER_2 EQU $C82F
music5 EQU $FE38
Print_List EQU $F38A
Dot_ix_b EQU $F2BE
VEC_BUTTON_2_3 EQU $C818
DRAW_VLCS EQU $F3D6
Vec_Duration EQU $C857
DELAY_RTS EQU $F57D
ADD_SCORE_D EQU $F87C
GET_RISE_RUN EQU $F5EF
musicd EQU $FF8F
VEC_TEXT_HW EQU $C82A
Intensity_a EQU $F2AB
MOVE_MEM_A_1 EQU $F67F
VEC_BUTTON_1_2 EQU $C813
Vec_RiseRun_Tmp EQU $C834
Draw_VL_a EQU $F3DA
MUSIC2 EQU $FD1D
MUSIC6 EQU $FE76
Random_3 EQU $F511
Vec_Expl_Flag EQU $C867
Vec_Button_2_1 EQU $C816
Vec_Joy_1_Y EQU $C81C
ROT_VL_MODE_A EQU $F61F
Vec_Num_Players EQU $C879
Init_Music_chk EQU $F687
MUSIC8 EQU $FEF8
PRINT_STR EQU $F495
Print_Str EQU $F495
STRIP_ZEROS EQU $F8B7
MOVETO_IX_7F EQU $F30C
DEC_6_COUNTERS EQU $F55E
Vec_Text_Width EQU $C82B
VEC_SND_SHADOW EQU $C800
DCR_intensity_5F EQU $4177
Reset0Ref EQU $F354
Delay_b EQU $F57A
MUSICA EQU $FF44
CLEAR_X_B EQU $F53F
CLEAR_SCORE EQU $F84F
INIT_VIA EQU $F14C
Vec_NMI_Vector EQU $CBFB
Set_Refresh EQU $F1A2
Clear_x_256 EQU $F545
Abs_b EQU $F58B
Intensity_5F EQU $F2A5
Vec_Expl_Chan EQU $C85C
INTENSITY_1F EQU $F29D
Mov_Draw_VL_a EQU $F3B9
Draw_Pat_VL_a EQU $F434
Vec_Music_Work EQU $C83F
Mov_Draw_VLc_a EQU $F3AD
Vec_Rfrsh EQU $C83D
RESET0REF_D0 EQU $F34A
INIT_MUSIC_X EQU $F692
Joy_Analog EQU $F1F5
Vec_Rfrsh_lo EQU $C83D
XFORM_RISE_A EQU $F661
Delay_0 EQU $F579
DCR_AFTER_INTENSITY EQU $417A
VEC_MUSIC_WORK EQU $C83F
MOD16.M16_RCHECK EQU $40FB
VEC_MUSIC_WK_6 EQU $C846
VEC_ADSR_TIMERS EQU $C85E
Mov_Draw_VL EQU $F3BC
Print_Ships EQU $F393
VEC_MISC_COUNT EQU $C823
Mov_Draw_VL_ab EQU $F3B7
XFORM_RUN EQU $F65D
INTENSITY_5F EQU $F2A5
VEC_STR_PTR EQU $C82C
MOV_DRAW_VL_D EQU $F3BE
VECTREX_PRINT_TEXT EQU $4000
RANDOM EQU $F517
RESET0INT EQU $F36B
VEC_RFRSH_LO EQU $C83D
Delay_1 EQU $F575
VEC_SWI2_VECTOR EQU $CBF2
VEC_JOY_2_X EQU $C81D
MOD16 EQU $40D6
MOVE_MEM_A EQU $F683
Draw_Line_d EQU $F3DF
COMPARE_SCORE EQU $F8C7
Reset_Pen EQU $F35B
VEC_TEXT_HEIGHT EQU $C82A
DOT_IX_B EQU $F2BE
Xform_Run_a EQU $F65B
VECTREX_PRINT_NUMBER EQU $4030
VEC_MAX_GAMES EQU $C850
MUSIC4 EQU $FDD3
VEC_BUTTON_2_4 EQU $C819
WARM_START EQU $F06C
Vec_Counter_1 EQU $C82E
VEC_MAX_PLAYERS EQU $C84F
VEC_EXPL_1 EQU $C858
Vec_Music_Wk_A EQU $C842
DP_TO_D0 EQU $F1AA
Print_Str_d EQU $F37A
VEC_RISE_INDEX EQU $C839
Vec_Expl_2 EQU $C859
VEC_EXPL_CHAN EQU $C85C
VEC_RFRSH EQU $C83D
DRAW_VLP_SCALE EQU $F40C
READ_BTNS_MASK EQU $F1B4
Vec_Run_Index EQU $C837
PRINT_LIST EQU $F38A
Vec_Counter_6 EQU $C833
VEC_MUSIC_FREQ EQU $C861
DELAY_3 EQU $F56D
Add_Score_a EQU $F85E
VEC_RFRSH_HI EQU $C83E
VEC_DEFAULT_STK EQU $CBEA
Sound_Byte_raw EQU $F25B
Vec_Button_1_4 EQU $C815
Vec_Seed_Ptr EQU $C87B
Recalibrate EQU $F2E6
VEC_HIGH_SCORE EQU $CBEB
Xform_Run EQU $F65D
Draw_VLcs EQU $F3D6
DOT_HERE EQU $F2C5
VEC_EXPL_CHANS EQU $C854
Wait_Recal EQU $F192
VEC_MUSIC_PTR EQU $C853
INIT_MUSIC EQU $F68D
music3 EQU $FD81
DELAY_2 EQU $F571
Vec_Num_Game EQU $C87A
VEC_EXPL_2 EQU $C859
DO_SOUND_X EQU $F28C
INTENSITY_3F EQU $F2A1
VEC_COUNTER_3 EQU $C830
Sound_Byte_x EQU $F259
Vec_Joy_Mux EQU $C81F
VEC_PREV_BTNS EQU $C810
Vec_Joy_2_Y EQU $C81E
Vec_Default_Stk EQU $CBEA
Abs_a_b EQU $F584
VEC_FREQ_TABLE EQU $C84D
VEC_EXPL_CHANB EQU $C85D
VEC_NUM_PLAYERS EQU $C879
DCR_after_intensity EQU $417A
PRINT_TEXT_STR_71921 EQU $4291
Vec_Music_Twang EQU $C858
DOT_D EQU $F2C3
VEC_MUSIC_WK_A EQU $C842
MOV_DRAW_VL EQU $F3BC
CLEAR_C8_RAM EQU $F542
Vec_RiseRun_Len EQU $C83B
music2 EQU $FD1D
INIT_MUSIC_BUF EQU $F533
VECTREX_PRINT_NUMBER.PN_L1000 EQU $4052
READ_BTNS EQU $F1BA
Draw_VL_mode EQU $F46E
VEC_EXPL_3 EQU $C85A
Vec_Button_1_2 EQU $C813
Clear_x_b EQU $F53F
RANDOM_3 EQU $F511
Vec_Max_Games EQU $C850
VEC_FIRQ_VECTOR EQU $CBF5
VEC_LOOP_COUNT EQU $C825
ARRAY_U16_ARR_DATA EQU $42A5
DEC_COUNTERS EQU $F563
Draw_VL EQU $F3DD
Dot_List_Reset EQU $F2DE
Cold_Start EQU $F000
Bitmask_a EQU $F57E
PRINT_TEXT_STR_2058 EQU $4287
Draw_VLp_7F EQU $F408
PRINT_SHIPS_X EQU $F391
VEC_JOY_RESLTN EQU $C81A
PRINT_STR_D EQU $F37A
Vec_Joy_Mux_1_X EQU $C81F
Init_Music_Buf EQU $F533
New_High_Score EQU $F8D8
Vec_Button_2_4 EQU $C819
VECTREX_PRINT_NUMBER.PN_AFTER_CONVERT EQU $40A9
SOUND_BYTE_RAW EQU $F25B
Draw_VLp_b EQU $F40E
Draw_Pat_VL_d EQU $F439
VEC_RUN_INDEX EQU $C837
VEC_EXPL_CHANA EQU $C853
MOVETO_IX EQU $F310
musica EQU $FF44
MOVETO_D EQU $F312
VEC_JOY_1_X EQU $C81B
Select_Game EQU $F7A9
Vec_Music_Ptr EQU $C853
VEC_BUTTON_1_1 EQU $C812
DRAW_GRID_VL EQU $FF9F
Obj_Hit EQU $F8FF
PRINT_SHIPS EQU $F393
Clear_x_d EQU $F548
Vec_Joy_Mux_2_Y EQU $C822
VEC_BUTTONS EQU $C811
VEC_MUSIC_FLAG EQU $C856
Vec_Text_Height EQU $C82A
RECALIBRATE EQU $F2E6
VEC_COUNTER_5 EQU $C832
VEC_BTN_STATE EQU $C80F
MOD16.M16_END EQU $411A
Print_List_hw EQU $F385
Init_VIA EQU $F14C
Vec_SWI_Vector EQU $CBFB
VEC_JOY_MUX_2_Y EQU $C822
Vec_Max_Players EQU $C84F
PRINT_TEXT_STR_2691 EQU $428A
Vec_Expl_4 EQU $C85B
Vec_Freq_Table EQU $C84D
Vec_Pattern EQU $C829
VEC_PATTERN EQU $C829
OBJ_WILL_HIT EQU $F8F3
DOT_LIST EQU $F2D5
Vec_Music_Chan EQU $C855
MOV_DRAW_VLCS EQU $F3B5
Mov_Draw_VL_d EQU $F3BE
PRINT_LIST_HW EQU $F385
ARRAY_I16_ARR_DATA EQU $42AD
DELAY_B EQU $F57A
Joy_Digital EQU $F1F8
DRAW_VL_AB EQU $F3D8
XFORM_RISE EQU $F663
musicc EQU $FF7A
Obj_Will_Hit_u EQU $F8E5
Strip_Zeros EQU $F8B7
Delay_2 EQU $F571
Vec_Expl_ChanB EQU $C85D
Vec_Button_1_1 EQU $C812
Dec_3_Counters EQU $F55A
DOT_IX EQU $F2C1
Draw_VLc EQU $F3CE
Vec_0Ref_Enable EQU $C824
COLD_START EQU $F000
OBJ_HIT EQU $F8FF
MUSIC1 EQU $FD0D
Clear_x_b_80 EQU $F550
Moveto_ix_FF EQU $F308
Dot_List EQU $F2D5
Random EQU $F517
Vec_FIRQ_Vector EQU $CBF5
VECTREX_PRINT_NUMBER.PN_L10 EQU $4086
MUSIC7 EQU $FEC6
music8 EQU $FEF8
DRAW_PAT_VL_D EQU $F439
Draw_VL_b EQU $F3D2
Explosion_Snd EQU $F92E
Intensity_1F EQU $F29D
Vec_SWI2_Vector EQU $CBF2
ROT_VL_AB EQU $F610
SOUND_BYTE_X EQU $F259
BITMASK_A EQU $F57E
VEC_MUSIC_WK_1 EQU $C84B
Moveto_ix_a EQU $F30E
Vec_Button_2_3 EQU $C818
Vec_Text_HW EQU $C82A
music6 EQU $FE76
music1 EQU $FD0D
VECTREX_PRINT_NUMBER.PN_L100 EQU $406C
Vec_Misc_Count EQU $C823
Print_Ships_x EQU $F391
Add_Score_d EQU $F87C
DRAW_VLC EQU $F3CE
Vec_Music_Wk_5 EQU $C847
Init_OS EQU $F18B
DP_to_C8 EQU $F1AF
Print_Str_hwyx EQU $F373
Moveto_d EQU $F312
Clear_x_b_a EQU $F552
VEC_BUTTON_2_1 EQU $C816
Draw_Grid_VL EQU $FF9F
ARRAY_U8_ARR_DATA EQU $429D
Vec_Expl_Chans EQU $C854
Vec_ADSR_Timers EQU $C85E
ROT_VL_DFT EQU $F637
Moveto_x_7F EQU $F2F2
MOVETO_IX_A EQU $F30E
Sound_Bytes EQU $F27D
Vec_Angle EQU $C836
SOUND_BYTES EQU $F27D
Vec_Expl_Timer EQU $C877
Vec_Music_Wk_7 EQU $C845
RESET0REF EQU $F354
Warm_Start EQU $F06C
INIT_OS EQU $F18B
Get_Rise_Run EQU $F5EF
VEC_COUNTER_6 EQU $C833
Vec_Music_Wk_1 EQU $C84B
DO_SOUND EQU $F289
PRINT_STR_HWYX EQU $F373
VEC_COUNTER_1 EQU $C82E
Vec_Button_2_2 EQU $C817
Rise_Run_Y EQU $F601
VEC_JOY_MUX_1_X EQU $C81F
Vec_Expl_3 EQU $C85A
DRAW_VLP_7F EQU $F408
DCR_INTENSITY_5F EQU $4177
Rot_VL_ab EQU $F610
SOUND_BYTES_X EQU $F284
Sound_Bytes_x EQU $F284
INIT_OS_RAM EQU $F164
VEC_NUM_GAME EQU $C87A
VEC_IRQ_VECTOR EQU $CBF8
Vec_Counter_2 EQU $C82F
Vec_Joy_2_X EQU $C81D
ABS_B EQU $F58B
Moveto_d_7F EQU $F2FC
VECTREX_PRINT_NUMBER.PN_D10 EQU $4098
SOUND_BYTE EQU $F256
Vec_IRQ_Vector EQU $CBF8
VEC_DOT_DWELL EQU $C828
RESET_PEN EQU $F35B
ROT_VL EQU $F616
Do_Sound EQU $F289
VEC_COLD_FLAG EQU $CBFE
VEC_RISERUN_TMP EQU $C834
Clear_Score EQU $F84F
VEC_JOY_1_Y EQU $C81C
Vec_Loop_Count EQU $C825
DELAY_0 EQU $F579
DRAW_VLP EQU $F410
VEC_JOY_2_Y EQU $C81E
JOY_ANALOG EQU $F1F5
SELECT_GAME EQU $F7A9
Vec_Music_Wk_6 EQU $C846
MUSIC9 EQU $FF26
Vec_Counter_3 EQU $C830
Read_Btns EQU $F1BA
VEC_0REF_ENABLE EQU $C824
Vec_Expl_1 EQU $C858
Draw_VL_ab EQU $F3D8
Vec_Buttons EQU $C811
Vec_Music_Freq EQU $C861
DRAW_PAT_VL EQU $F437
VEC_JOY_MUX EQU $C81F
GET_RISE_IDX EQU $F5D9
MOV_DRAW_VL_AB EQU $F3B7
VEC_MUSIC_WK_7 EQU $C845
MOV_DRAW_VLC_A EQU $F3AD
VEC_MUSIC_TWANG EQU $C858
OBJ_WILL_HIT_U EQU $F8E5
Vec_Joy_Resltn EQU $C81A
Vec_Random_Seed EQU $C87D
RISE_RUN_LEN EQU $F603
INIT_MUSIC_CHK EQU $F687
Intensity_3F EQU $F2A1
Mov_Draw_VLcs EQU $F3B5
Init_Music_x EQU $F692
CLEAR_X_B_80 EQU $F550
Reset0Ref_D0 EQU $F34A
Vec_Expl_ChanA EQU $C853
DRAW_VL_MODE EQU $F46E
Reset0Int EQU $F36B
musicb EQU $FF62
Vec_Brightness EQU $C827
VEC_MUSIC_CHAN EQU $C855
MOD16.M16_DPOS EQU $40F3
Rot_VL EQU $F616
VEC_EXPL_TIMER EQU $C877
Draw_VLp_scale EQU $F40C
Move_Mem_a_1 EQU $F67F
Compare_Score EQU $F8C7
MOVETO_X_7F EQU $F2F2
music7 EQU $FEC6
Rise_Run_Len EQU $F603
Vec_Rise_Index EQU $C839
Vec_Twang_Table EQU $C851
VEC_DURATION EQU $C857
VEC_RISERUN_LEN EQU $C83B
EXPLOSION_SND EQU $F92E
Vec_Counter_4 EQU $C831
PRINT_STR_YX EQU $F378
Vec_Button_1_3 EQU $C814
VEC_BUTTON_2_2 EQU $C817
RISE_RUN_X EQU $F5FF
Vec_Snd_Shadow EQU $C800
ARRAY_ROW_Y_DATA EQU $42B5
CLEAR_X_D EQU $F548
Rot_VL_dft EQU $F637
JOY_DIGITAL EQU $F1F8
Vec_Joy_Mux_2_X EQU $C821
Draw_Pat_VL EQU $F437
DRAW_CIRCLE_RUNTIME EQU $4142
DRAW_VL_A EQU $F3DA
Xform_Rise EQU $F663
Dot_d EQU $F2C3
Move_Mem_a EQU $F683
Vec_Counters EQU $C82E
MOV_DRAW_VL_B EQU $F3B1
Vec_Btn_State EQU $C80F
VEC_SWI3_VECTOR EQU $CBF2
MUSICC EQU $FF7A
VEC_SEED_PTR EQU $C87B
SET_REFRESH EQU $F1A2
VECTREX_PRINT_NUMBER.PN_D1000 EQU $4064
DELAY_1 EQU $F575
Xform_Rise_a EQU $F661
ROT_VL_MODE EQU $F62B
PRINT_TEXT_STR_71726 EQU $428D
Dot_here EQU $F2C5
Dot_ix EQU $F2C1
VEC_MUSIC_WK_5 EQU $C847
Vec_Joy_1_X EQU $C81B
Rise_Run_Angle EQU $F593
Delay_3 EQU $F56D
Vec_Str_Ptr EQU $C82C
Draw_VLp_FF EQU $F404
music4 EQU $FDD3
DRAW_VLP_FF EQU $F404
Print_List_chk EQU $F38C
VEC_COUNTERS EQU $C82E
CHECK0REF EQU $F34F
Vec_High_Score EQU $CBEB
VEC_RANDOM_SEED EQU $C87D
MUSIC3 EQU $FD81
Rot_VL_Mode_a EQU $F61F
DRAW_VL_B EQU $F3D2
VEC_COUNTER_4 EQU $C831
MOV_DRAW_VL_A EQU $F3B9
VEC_EXPL_FLAG EQU $C867
VEC_BUTTON_1_4 EQU $C815
Init_Music EQU $F68D
VEC_EXPL_4 EQU $C85B
Rise_Run_X EQU $F5FF
MOD16.M16_DONE EQU $4129
Vec_Cold_Flag EQU $CBFE
MOVETO_IX_FF EQU $F308
Do_Sound_x EQU $F28C
INTENSITY_A EQU $F2AB
Draw_VLp EQU $F410
Vec_Counter_5 EQU $C832
DEC_3_COUNTERS EQU $F55A
WAIT_RECAL EQU $F192
Moveto_ix_7F EQU $F30C
ADD_SCORE_A EQU $F85E
VEC_ANGLE EQU $C836
DRAW_LINE_D EQU $F3DF
RISE_RUN_ANGLE EQU $F593
VEC_JOY_MUX_1_Y EQU $C820
MUSICD EQU $FF8F
PRINT_TEXT_STR_83258 EQU $4299
MUSICB EQU $FF62
VEC_TWANG_TABLE EQU $C851
INTENSITY_7F EQU $F2A9
MOD16.M16_RPOS EQU $410A
Delay_RTS EQU $F57D
Dec_6_Counters EQU $F55E
J1Y_BUILTIN EQU $412A
Vec_Prev_Btns EQU $C810
Vec_ADSR_Table EQU $C84F
VEC_TEXT_WIDTH EQU $C82B
Vec_Rfrsh_hi EQU $C83E
Print_Str_yx EQU $F378
VEC_JOY_MUX_2_X EQU $C821
Obj_Will_Hit EQU $F8F3
RISE_RUN_Y EQU $F601
Clear_C8_RAM EQU $F542
Intensity_7F EQU $F2A9
GET_RUN_IDX EQU $F5DB
Get_Rise_Idx EQU $F5D9
MOD16.M16_LOOP EQU $410A
VEC_BRIGHTNESS EQU $C827
NEW_HIGH_SCORE EQU $F8D8
DRAW_PAT_VL_A EQU $F434
Moveto_ix EQU $F310
Rot_VL_Mode EQU $F62B
VEC_SWI_VECTOR EQU $CBFB
DOT_LIST_RESET EQU $F2DE
VECTREX_PRINT_NUMBER.PN_D100 EQU $407E
Vec_Joy_Mux_1_Y EQU $C820
VEC_BUTTON_1_3 EQU $C814
music9 EQU $FF26
ABS_A_B EQU $F584
Clear_Sound EQU $F272
Init_OS_RAM EQU $F164
CLEAR_X_B_A EQU $F552
VEC_ADSR_TABLE EQU $C84F
Check0Ref EQU $F34F
CLEAR_X_256 EQU $F545
DRAW_VL EQU $F3DD
ARRAY_I8_ARR_DATA EQU $42A1
DP_to_D0 EQU $F1AA


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "TYPED"
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
DRAW_VEC_INTENSITY   EQU $C880+$21   ; Vector intensity override (0=use vector data) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$22   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$2C   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$2E   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$30   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$31   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$32   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$34   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$36   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$37   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_U8_VAL           EQU $C880+$38   ; User variable: U8_VAL (1 bytes)
VAR_I8_VAL           EQU $C880+$39   ; User variable: I8_VAL (1 bytes)
VAR_U16_VAL          EQU $C880+$3A   ; User variable: U16_VAL (2 bytes)
VAR_I16_VAL          EQU $C880+$3C   ; User variable: I16_VAL (2 bytes)
VAR_ROW_Y            EQU $C880+$3E   ; User variable: ROW_Y (2 bytes)
VAR_SELECTED         EQU $C880+$40   ; User variable: SELECTED (1 bytes)
VAR_COOLDOWN         EQU $C880+$41   ; User variable: COOLDOWN (1 bytes)
VAR_ARR_IDX          EQU $C880+$42   ; User variable: ARR_IDX (1 bytes)
VAR_ARR_TICK         EQU $C880+$43   ; User variable: ARR_TICK (1 bytes)
VAR_JOY_Y            EQU $C880+$44   ; User variable: JOY_Y (2 bytes)
VAR_U8_ARR           EQU $C880+$46   ; User variable: U8_ARR (2 bytes)
VAR_I8_ARR           EQU $C880+$48   ; User variable: I8_ARR (2 bytes)
VAR_U16_ARR          EQU $C880+$4A   ; User variable: U16_ARR (2 bytes)
VAR_I16_ARR          EQU $C880+$4C   ; User variable: I16_ARR (2 bytes)
VAR_U8_ARR_DATA      EQU $C880+$4E   ; Mutable array 'U8_ARR' data (4 elements x 1 bytes) (4 bytes)
VAR_I8_ARR_DATA      EQU $C880+$52   ; Mutable array 'I8_ARR' data (4 elements x 1 bytes) (4 bytes)
VAR_U16_ARR_DATA     EQU $C880+$56   ; Mutable array 'U16_ARR' data (4 elements x 2 bytes) (8 bytes)
VAR_I16_ARR_DATA     EQU $C880+$5E   ; Mutable array 'I16_ARR' data (4 elements x 2 bytes) (8 bytes)
VAR_ARG0             EQU $CB80   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $CB82   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $CB84   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $CB86   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $CB88   ; Function argument 4 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $CB8A   ; Current ROM bank ID (multibank tracking) (1 bytes)

;***************************************************************************
; ARRAY DATA (ROM literals)
;***************************************************************************
; Arrays are stored in ROM and accessed via pointers
; At startup, main() initializes VAR_{name} to point to ARRAY_{name}_DATA

; Array literal for variable 'U8_ARR' (4 elements, 1 bytes each)
MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    LDA #$F8
    STA TEXT_SCALE_H      ; Default height = -8 (normal size)
    LDA #$48
    STA TEXT_SCALE_W      ; Default width = 72 (normal size)
    LDD #200
    STD VAR_U8_VAL
    LDD #-100
    STD VAR_I8_VAL
    LDD #60000
    STD VAR_U16_VAL
    LDD #-30000
    STD VAR_I16_VAL
    ; Copy array 'U8_ARR' from ROM to RAM (4 elements)
    LDX #ARRAY_U8_ARR_DATA       ; Source: ROM array data
    LDU #VAR_U8_ARR_DATA       ; Dest: RAM array space
    LDD #4        ; Number of elements
.COPY_LOOP_0:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_0 ; Loop until done (LBNE for long branch)
    LDX #VAR_U8_ARR_DATA    ; Array now in RAM
    STX VAR_U8_ARR
    ; Copy array 'I8_ARR' from ROM to RAM (4 elements)
    LDX #ARRAY_I8_ARR_DATA       ; Source: ROM array data
    LDU #VAR_I8_ARR_DATA       ; Dest: RAM array space
    LDD #4        ; Number of elements
.COPY_LOOP_1:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_1 ; Loop until done (LBNE for long branch)
    LDX #VAR_I8_ARR_DATA    ; Array now in RAM
    STX VAR_I8_ARR
    ; Copy array 'U16_ARR' from ROM to RAM (4 elements)
    LDX #ARRAY_U16_ARR_DATA       ; Source: ROM array data
    LDU #VAR_U16_ARR_DATA       ; Dest: RAM array space
    LDD #4        ; Number of elements
.COPY_LOOP_2:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_2 ; Loop until done (LBNE for long branch)
    LDX #VAR_U16_ARR_DATA    ; Array now in RAM
    STX VAR_U16_ARR
    ; Copy array 'I16_ARR' from ROM to RAM (4 elements)
    LDX #ARRAY_I16_ARR_DATA       ; Source: ROM array data
    LDU #VAR_I16_ARR_DATA       ; Dest: RAM array space
    LDD #4        ; Number of elements
.COPY_LOOP_3:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_3 ; Loop until done (LBNE for long branch)
    LDX #VAR_I16_ARR_DATA    ; Array now in RAM
    STX VAR_I16_ARR
    LDD #0
    STD VAR_SELECTED
    LDD #0
    STD VAR_COOLDOWN
    LDD #0
    STD VAR_ARR_IDX
    LDD #0
    STD VAR_ARR_TICK
    LDD #0
    STD VAR_JOY_Y
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
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    LDD #0
    STB VAR_SELECTED
    LDD #0
    STB VAR_COOLDOWN
    LDD #0
    STB VAR_ARR_IDX
    LDD #0
    STB VAR_ARR_TICK

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    LDB >VAR_ARR_TICK
    CLRA            ; Zero-extend: A=0, B=value
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STB VAR_ARR_TICK
    LDD #30
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_ARR_TICK
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBGT .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_1
    LDD #0
    STB VAR_ARR_TICK
    LDB >VAR_ARR_IDX
    CLRA            ; Zero-extend: A=0, B=value
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STB VAR_ARR_IDX
    LDD #3
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_ARR_IDX
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBGT .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    LBEQ IF_NEXT_3
    LDD #0
    STB VAR_ARR_IDX
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    JSR J1Y_BUILTIN
    STD RESULT
    STD VAR_JOY_Y
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_COOLDOWN
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBGT .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    LBEQ IF_NEXT_5
    LDB >VAR_COOLDOWN
    CLRA            ; Zero-extend: A=0, B=value
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STB VAR_COOLDOWN
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_COOLDOWN
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBEQ .CMP_3_TRUE
    LDD #0
    LBRA .CMP_3_END
.CMP_3_TRUE:
    LDD #1
.CMP_3_END:
    LBEQ IF_NEXT_7
    LDD #60
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_Y
    CMPD TMPVAL
    LBGT .CMP_4_TRUE
    LDD #0
    LBRA .CMP_4_END
.CMP_4_TRUE:
    LDD #1
.CMP_4_END:
    LBEQ IF_NEXT_9
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBGT .CMP_5_TRUE
    LDD #0
    LBRA .CMP_5_END
.CMP_5_TRUE:
    LDD #1
.CMP_5_END:
    LBEQ IF_NEXT_11
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STB VAR_SELECTED
    LBRA IF_END_10
IF_NEXT_11:
IF_END_10:
    LDD #15
    STB VAR_COOLDOWN
    LBRA IF_END_8
IF_NEXT_9:
IF_END_8:
    LDD #-60
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_Y
    CMPD TMPVAL
    LBLT .CMP_6_TRUE
    LDD #0
    LBRA .CMP_6_END
.CMP_6_TRUE:
    LDD #1
.CMP_6_END:
    LBEQ IF_NEXT_13
    LDD #3
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBLT .CMP_7_TRUE
    LDD #0
    LBRA .CMP_7_END
.CMP_7_TRUE:
    LDD #1
.CMP_7_END:
    LBEQ IF_NEXT_15
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STB VAR_SELECTED
    LBRA IF_END_14
IF_NEXT_15:
IF_END_14:
    LDD #15
    STB VAR_COOLDOWN
    LBRA IF_END_12
IF_NEXT_13:
IF_END_12:
    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed
    BITA #$01
    LBNE .J1B1_0_ON
    LDD #0
    LBRA .J1B1_0_END
.J1B1_0_ON:
    LDD #1
.J1B1_0_END:
    STD RESULT
    LBEQ IF_NEXT_17
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBEQ .CMP_8_TRUE
    LDD #0
    LBRA .CMP_8_END
.CMP_8_TRUE:
    LDD #1
.CMP_8_END:
    LBEQ IF_NEXT_19
    LDB >VAR_U8_VAL
    CLRA            ; Zero-extend: A=0, B=value
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STB VAR_U8_VAL
    LBRA IF_END_18
IF_NEXT_19:
IF_END_18:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBEQ .CMP_9_TRUE
    LDD #0
    LBRA .CMP_9_END
.CMP_9_TRUE:
    LDD #1
.CMP_9_END:
    LBEQ IF_NEXT_21
    LDB >VAR_I8_VAL
    SEX             ; Sign-extend B -> D
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STB VAR_I8_VAL
    LBRA IF_END_20
IF_NEXT_21:
IF_END_20:
    LDD #2
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBEQ .CMP_10_TRUE
    LDD #0
    LBRA .CMP_10_END
.CMP_10_TRUE:
    LDD #1
.CMP_10_END:
    LBEQ IF_NEXT_23
    LDD >VAR_U16_VAL
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #100
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_U16_VAL
    LBRA IF_END_22
IF_NEXT_23:
IF_END_22:
    LDD #3
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBEQ .CMP_11_TRUE
    LDD #0
    LBRA .CMP_11_END
.CMP_11_TRUE:
    LDD #1
.CMP_11_END:
    LBEQ IF_NEXT_25
    LDD >VAR_I16_VAL
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #100
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_I16_VAL
    LBRA IF_END_24
IF_NEXT_25:
IF_END_24:
    LDD #4
    STB VAR_COOLDOWN
    LBRA IF_END_16
IF_NEXT_17:
IF_END_16:
    LDA >$C80F   ; Vec_Btns_1: bit1=1 means btn2 pressed
    BITA #$02
    LBNE .J1B2_1_ON
    LDD #0
    LBRA .J1B2_1_END
.J1B2_1_ON:
    LDD #1
.J1B2_1_END:
    STD RESULT
    LBEQ IF_NEXT_27
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBEQ .CMP_12_TRUE
    LDD #0
    LBRA .CMP_12_END
.CMP_12_TRUE:
    LDD #1
.CMP_12_END:
    LBEQ IF_NEXT_29
    LDB >VAR_U8_VAL
    CLRA            ; Zero-extend: A=0, B=value
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STB VAR_U8_VAL
    LBRA IF_END_28
IF_NEXT_29:
IF_END_28:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBEQ .CMP_13_TRUE
    LDD #0
    LBRA .CMP_13_END
.CMP_13_TRUE:
    LDD #1
.CMP_13_END:
    LBEQ IF_NEXT_31
    LDB >VAR_I8_VAL
    SEX             ; Sign-extend B -> D
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STB VAR_I8_VAL
    LBRA IF_END_30
IF_NEXT_31:
IF_END_30:
    LDD #2
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBEQ .CMP_14_TRUE
    LDD #0
    LBRA .CMP_14_END
.CMP_14_TRUE:
    LDD #1
.CMP_14_END:
    LBEQ IF_NEXT_33
    LDD >VAR_U16_VAL
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #100
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_U16_VAL
    LBRA IF_END_32
IF_NEXT_33:
IF_END_32:
    LDD #3
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBEQ .CMP_15_TRUE
    LDD #0
    LBRA .CMP_15_END
.CMP_15_TRUE:
    LDD #1
.CMP_15_END:
    LBEQ IF_NEXT_35
    LDD >VAR_I16_VAL
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #100
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_I16_VAL
    LBRA IF_END_34
IF_NEXT_35:
IF_END_34:
    LDD #4
    STB VAR_COOLDOWN
    LBRA IF_END_26
IF_NEXT_27:
IF_END_26:
    LDA >$C80F   ; Vec_Btns_1: bit2=1 means btn3 pressed
    BITA #$04
    LBNE .J1B3_2_ON
    LDD #0
    LBRA .J1B3_2_END
.J1B3_2_ON:
    LDD #1
.J1B3_2_END:
    STD RESULT
    LBEQ IF_NEXT_37
    LDD #200
    STB VAR_U8_VAL
    LDD #-100
    STB VAR_I8_VAL
    LDD #60000
    STD VAR_U16_VAL
    LDD #-30000
    STD VAR_I16_VAL
    LDD #0
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_U8_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #10
    LDX TMPPTR2     ; Load computed address
    STB ,X          ; Store 8-bit value
    LDD #1
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_U8_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #50
    LDX TMPPTR2     ; Load computed address
    STB ,X          ; Store 8-bit value
    LDD #2
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_U8_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #150
    LDX TMPPTR2     ; Load computed address
    STB ,X          ; Store 8-bit value
    LDD #3
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_U8_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #250
    LDX TMPPTR2     ; Load computed address
    STB ,X          ; Store 8-bit value
    LDD #0
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_I8_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #-120
    LDX TMPPTR2     ; Load computed address
    STB ,X          ; Store 8-bit value
    LDD #1
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_I8_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #-40
    LDX TMPPTR2     ; Load computed address
    STB ,X          ; Store 8-bit value
    LDD #2
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_I8_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #40
    LDX TMPPTR2     ; Load computed address
    STB ,X          ; Store 8-bit value
    LDD #3
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_I8_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #120
    LDX TMPPTR2     ; Load computed address
    STB ,X          ; Store 8-bit value
    LDD #0
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_U16_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #1
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_U16_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #1000
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #2
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_U16_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #30000
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #3
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_U16_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #65535
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #0
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_I16_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #-32000
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #1
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_I16_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #-500
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #2
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_I16_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #500
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #3
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_I16_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #32000
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #15
    STB VAR_COOLDOWN
    LBRA IF_END_36
IF_NEXT_37:
IF_END_36:
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD VAR_ARG0
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2691      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #-55
    STD VAR_ARG0    ; X position
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG1    ; Y position
    LDB >VAR_U8_VAL
    CLRA            ; Zero-extend: A=0, B=value
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #5
    STD VAR_ARG0
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2058      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #30
    STD VAR_ARG0    ; X position
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG1    ; Y position
    LDX #VAR_U8_ARR_DATA  ; Array base
    LDB >VAR_ARR_IDX
    CLRA            ; Zero-extend: A=0, B=value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD VAR_ARG0
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_71921      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #-55
    STD VAR_ARG0    ; X position
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG1    ; Y position
    LDB >VAR_I8_VAL
    SEX             ; Sign-extend B -> D
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #5
    STD VAR_ARG0
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2058      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #30
    STD VAR_ARG0    ; X position
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG1    ; Y position
    LDX #VAR_I8_ARR_DATA  ; Array base
    LDB >VAR_ARR_IDX
    CLRA            ; Zero-extend: A=0, B=value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD VAR_ARG0
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_83258      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #-55
    STD VAR_ARG0    ; X position
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG1    ; Y position
    LDD >VAR_U16_VAL
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #5
    STD VAR_ARG0
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2058      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #30
    STD VAR_ARG0    ; X position
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG1    ; Y position
    LDX #VAR_U16_ARR_DATA  ; Array base
    LDB >VAR_ARR_IDX
    CLRA            ; Zero-extend: A=0, B=value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD VAR_ARG0
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_71726      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #-55
    STD VAR_ARG0    ; X position
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG1    ; Y position
    LDD >VAR_I16_VAL
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #5
    STD VAR_ARG0
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2058      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #30
    STD VAR_ARG0    ; X position
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG1    ; Y position
    LDX #VAR_I16_ARR_DATA  ; Array base
    LDB >VAR_ARR_IDX
    CLRA            ; Zero-extend: A=0, B=value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-40
    STD VAR_ARG0
    LDD #-22
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_72349      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #10
    STD VAR_ARG0    ; X position
    LDD #-22
    STD VAR_ARG1    ; Y position
    LDB >VAR_ARR_IDX
    CLRA            ; Zero-extend: A=0, B=value
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD #-125
    TFR B,A
    STA DRAW_CIRCLE_XC
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    TFR B,A
    STA DRAW_CIRCLE_YC
    LDD #10
    TFR B,A
    STA DRAW_CIRCLE_DIAM
    LDD #100
    TFR B,A
    STA DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    RTS


; ================================================
