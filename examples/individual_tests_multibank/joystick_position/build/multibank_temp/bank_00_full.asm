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
VAR_X                EQU $C880+$37   ; User variable: X (2 bytes)
VAR_Y                EQU $C880+$39   ; User variable: Y (2 bytes)
VAR_CIRCLE_X         EQU $C880+$3B   ; User variable: CIRCLE_X (2 bytes)
VAR_CIRCLE_Y         EQU $C880+$3D   ; User variable: CIRCLE_Y (2 bytes)
VAR_BTN1             EQU $C880+$3F   ; User variable: BTN1 (2 bytes)
VAR_BTN2             EQU $C880+$41   ; User variable: BTN2 (2 bytes)
VAR_BTN3             EQU $C880+$43   ; User variable: BTN3 (2 bytes)
VAR_BTN4             EQU $C880+$45   ; User variable: BTN4 (2 bytes)
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
music8 EQU $FEF8
XFORM_RUN EQU $F65D
musicb EQU $FF62
MOVETO_X_7F EQU $F2F2
DRAW_VLP_SCALE EQU $F40C
VEC_JOY_2_X EQU $C81D
EXPLOSION_SND EQU $F92E
Draw_VL_b EQU $F3D2
PRINT_TEXT_STR_2049397 EQU $430A
VEC_ADSR_TABLE EQU $C84F
Vec_Joy_1_X EQU $C81B
Read_Btns EQU $F1BA
Joy_Digital EQU $F1F8
DRAW_VL EQU $F3DD
MOV_DRAW_VL_B EQU $F3B1
DRAW_VL_A EQU $F3DA
VEC_COUNTER_6 EQU $C833
SELECT_GAME EQU $F7A9
Intensity_3F EQU $F2A1
Mov_Draw_VLcs EQU $F3B5
music5 EQU $FE38
Vec_ADSR_Table EQU $C84F
Draw_VL_ab EQU $F3D8
Print_List EQU $F38A
INIT_VIA EQU $F14C
RISE_RUN_X EQU $F5FF
VEC_MAX_PLAYERS EQU $C84F
Clear_x_b_80 EQU $F550
Get_Run_Idx EQU $F5DB
Draw_VLp_scale EQU $F40C
Vec_Joy_Mux_1_Y EQU $C820
DELAY_0 EQU $F579
VEC_MUSIC_WK_7 EQU $C845
Clear_C8_RAM EQU $F542
Rot_VL_Mode_a EQU $F61F
Draw_VLp_FF EQU $F404
SOUND_BYTE EQU $F256
CLEAR_SOUND EQU $F272
VEC_0REF_ENABLE EQU $C824
CLEAR_SCORE EQU $F84F
VEC_COUNTERS EQU $C82E
Vec_Rfrsh_hi EQU $C83E
Moveto_ix EQU $F310
DIV16.D16_LOOP EQU $4118
READ_BTNS_MASK EQU $F1B4
Vec_Music_Flag EQU $C856
Vec_Button_1_2 EQU $C813
DEC_3_COUNTERS EQU $F55A
Reset0Int EQU $F36B
Vec_Expl_Chans EQU $C854
Vec_Button_1_4 EQU $C815
ROT_VL EQU $F616
Vec_Text_Width EQU $C82B
MUSIC7 EQU $FEC6
VEC_JOY_1_X EQU $C81B
VEC_EXPL_TIMER EQU $C877
musicc EQU $FF7A
Vec_Duration EQU $C857
RISE_RUN_LEN EQU $F603
Init_VIA EQU $F14C
NEW_HIGH_SCORE EQU $F8D8
VECTREX_PRINT_NUMBER.PN_D10 EQU $4098
MUSIC8 EQU $FEF8
Vec_Freq_Table EQU $C84D
VEC_TWANG_TABLE EQU $C851
RISE_RUN_Y EQU $F601
Sound_Bytes EQU $F27D
VEC_BUTTON_1_3 EQU $C814
VEC_DEFAULT_STK EQU $CBEA
DELAY_RTS EQU $F57D
DCR_INTENSITY_5F EQU $41FA
Vec_Music_Work EQU $C83F
VEC_EXPL_CHANB EQU $C85D
VEC_RANDOM_SEED EQU $C87D
VEC_JOY_MUX_1_Y EQU $C820
Clear_x_256 EQU $F545
music9 EQU $FF26
PRINT_TEXT_STR_76316012 EQU $431E
XFORM_RISE EQU $F663
VEC_NUM_GAME EQU $C87A
MOD16.M16_RCHECK EQU $4166
Vec_RiseRun_Tmp EQU $C834
SOUND_BYTES_X EQU $F284
VEC_MUSIC_WK_5 EQU $C847
MUSICC EQU $FF7A
DEC_COUNTERS EQU $F563
VEC_BRIGHTNESS EQU $C827
Vec_Counters EQU $C82E
JOY_ANALOG EQU $F1F5
DCR_intensity_5F EQU $41FA
VEC_MUSIC_CHAN EQU $C855
Rot_VL_dft EQU $F637
Vec_Rfrsh_lo EQU $C83D
Draw_Pat_VL EQU $F437
VEC_BUTTON_2_3 EQU $C818
MUSICD EQU $FF8F
Dot_here EQU $F2C5
Draw_Pat_VL_a EQU $F434
Rot_VL EQU $F616
VEC_COUNTER_5 EQU $C832
ADD_SCORE_A EQU $F85E
PRINT_SHIPS EQU $F393
Vec_IRQ_Vector EQU $CBF8
CLEAR_X_B EQU $F53F
VEC_NMI_VECTOR EQU $CBFB
DCR_AFTER_INTENSITY EQU $41FD
Draw_Pat_VL_d EQU $F439
VEC_JOY_2_Y EQU $C81E
DRAW_VL_B EQU $F3D2
Vec_Music_Freq EQU $C861
PRINT_LIST_CHK EQU $F38C
ADD_SCORE_D EQU $F87C
Print_Str_hwyx EQU $F373
VEC_EXPL_CHANS EQU $C854
Vec_Twang_Table EQU $C851
ABS_B EQU $F58B
Draw_Line_d EQU $F3DF
DOT_D EQU $F2C3
DP_TO_C8 EQU $F1AF
MOVETO_IX EQU $F310
VEC_EXPL_2 EQU $C859
Sound_Byte_raw EQU $F25B
Set_Refresh EQU $F1A2
DCR_after_intensity EQU $41FD
Abs_a_b EQU $F584
musicd EQU $FF8F
DP_TO_D0 EQU $F1AA
Moveto_d EQU $F312
Vec_Music_Ptr EQU $C853
Rot_VL_Mode EQU $F62B
VEC_MUSIC_TWANG EQU $C858
Dot_d EQU $F2C3
Vec_ADSR_Timers EQU $C85E
SOUND_BYTE_RAW EQU $F25B
Vec_Joy_Mux_2_Y EQU $C822
RESET0INT EQU $F36B
VECTREX_PRINT_NUMBER.PN_D1000 EQU $4064
Moveto_ix_FF EQU $F308
Obj_Will_Hit EQU $F8F3
VEC_IRQ_VECTOR EQU $CBF8
PRINT_SHIPS_X EQU $F391
DOT_IX_B EQU $F2BE
VEC_ANGLE EQU $C836
ROT_VL_AB EQU $F610
VEC_BUTTON_1_4 EQU $C815
COLD_START EQU $F000
Abs_b EQU $F58B
VEC_SEED_PTR EQU $C87B
Vec_Music_Wk_5 EQU $C847
Dot_ix EQU $F2C1
Vec_Joy_Mux_1_X EQU $C81F
Vec_Text_Height EQU $C82A
VEC_BUTTONS EQU $C811
Vec_Joy_1_Y EQU $C81C
PRINT_TEXT_STR_2049399 EQU $4314
MOD16.M16_END EQU $4185
New_High_Score EQU $F8D8
VEC_COUNTER_2 EQU $C82F
DRAW_VLCS EQU $F3D6
DRAW_VLP_B EQU $F40E
Vec_Joy_Resltn EQU $C81A
DRAW_LINE_D EQU $F3DF
Vec_Misc_Count EQU $C823
VECTREX_PRINT_NUMBER.PN_L10 EQU $4086
DOT_HERE EQU $F2C5
ROT_VL_DFT EQU $F637
DRAW_VLP_FF EQU $F404
Mov_Draw_VL_d EQU $F3BE
PRINT_TEXT_STR_2049398 EQU $430F
music1 EQU $FD0D
VEC_SWI3_VECTOR EQU $CBF2
VEC_JOY_MUX_2_X EQU $C821
Moveto_x_7F EQU $F2F2
MOVETO_D EQU $F312
VEC_MUSIC_WK_A EQU $C842
MUSIC9 EQU $FF26
Vec_Expl_Timer EQU $C877
Strip_Zeros EQU $F8B7
Rise_Run_Angle EQU $F593
VEC_MUSIC_FLAG EQU $C856
Vec_Music_Twang EQU $C858
Random_3 EQU $F511
DRAW_PAT_VL EQU $F437
DIV16.D16_DONE EQU $4140
Init_Music_x EQU $F692
OBJ_HIT EQU $F8FF
INIT_MUSIC_CHK EQU $F687
MOVETO_IX_FF EQU $F308
Mov_Draw_VLc_a EQU $F3AD
Draw_VLp_7F EQU $F408
VEC_BTN_STATE EQU $C80F
Wait_Recal EQU $F192
GET_RUN_IDX EQU $F5DB
Clear_x_d EQU $F548
VEC_SWI_VECTOR EQU $CBFB
Sound_Byte_x EQU $F259
DP_to_D0 EQU $F1AA
MUSIC1 EQU $FD0D
Vec_Default_Stk EQU $CBEA
DP_to_C8 EQU $F1AF
Draw_VLc EQU $F3CE
Rise_Run_Len EQU $F603
Init_OS EQU $F18B
VEC_MUSIC_PTR EQU $C853
DIV16.D16_RCHECK EQU $40FB
Joy_Analog EQU $F1F5
DIV16.D16_END EQU $4131
Vec_Max_Players EQU $C84F
MOD16.M16_DONE EQU $4194
DELAY_2 EQU $F571
Vec_Music_Chan EQU $C855
INIT_MUSIC EQU $F68D
Vec_Buttons EQU $C811
VEC_RISERUN_TMP EQU $C834
Vec_FIRQ_Vector EQU $CBF5
Vec_Expl_Flag EQU $C867
music3 EQU $FD81
Vec_Music_Wk_6 EQU $C846
MOD16 EQU $4141
INIT_OS_RAM EQU $F164
Reset0Ref_D0 EQU $F34A
OBJ_WILL_HIT_U EQU $F8E5
VEC_PREV_BTNS EQU $C810
XFORM_RUN_A EQU $F65B
Vec_Counter_3 EQU $C830
Check0Ref EQU $F34F
Vec_Angle EQU $C836
INTENSITY_5F EQU $F2A5
Vec_Expl_Chan EQU $C85C
Moveto_ix_a EQU $F30E
Vec_Snd_Shadow EQU $C800
Init_Music_chk EQU $F687
J1Y_BUILTIN EQU $41AD
Vec_Counter_5 EQU $C832
Do_Sound_x EQU $F28C
VECTREX_PRINT_NUMBER EQU $4030
SET_REFRESH EQU $F1A2
MOV_DRAW_VLCS EQU $F3B5
Obj_Hit EQU $F8FF
Rise_Run_X EQU $F5FF
Vec_Seed_Ptr EQU $C87B
DEC_6_COUNTERS EQU $F55E
Mov_Draw_VL_b EQU $F3B1
Vec_Rise_Index EQU $C839
Delay_1 EQU $F575
MOVETO_D_7F EQU $F2FC
PRINT_TEXT_STR_2049400 EQU $4319
Dot_List EQU $F2D5
Vec_Expl_1 EQU $C858
Delay_2 EQU $F571
Dec_Counters EQU $F563
Vec_Max_Games EQU $C850
SOUND_BYTE_X EQU $F259
VEC_RFRSH EQU $C83D
Dec_6_Counters EQU $F55E
VEC_JOY_MUX EQU $C81F
RESET0REF EQU $F354
DRAW_PAT_VL_D EQU $F439
XFORM_RISE_A EQU $F661
Random EQU $F517
Delay_b EQU $F57A
PRINT_STR_HWYX EQU $F373
Intensity_7F EQU $F2A9
Delay_3 EQU $F56D
VEC_JOY_MUX_2_Y EQU $C822
PRINT_LIST EQU $F38A
Vec_Counter_1 EQU $C82E
DIV16 EQU $40D6
Explosion_Snd EQU $F92E
ROT_VL_MODE_A EQU $F61F
Sound_Byte EQU $F256
Add_Score_a EQU $F85E
Move_Mem_a EQU $F683
Vec_0Ref_Enable EQU $C824
VEC_COLD_FLAG EQU $CBFE
VECTREX_PRINT_NUMBER.PN_AFTER_CONVERT EQU $40A9
Vec_Rfrsh EQU $C83D
Vec_Expl_3 EQU $C85A
VEC_JOY_RESLTN EQU $C81A
PRINT_TEXT_STR_76316013 EQU $4324
Vec_Expl_ChanB EQU $C85D
Reset0Ref EQU $F354
Vec_Joy_2_X EQU $C81D
Vec_Brightness EQU $C827
PRINT_LIST_HW EQU $F385
Clear_x_b EQU $F53F
DOT_LIST_RESET EQU $F2DE
Add_Score_d EQU $F87C
Vec_Joy_Mux_2_X EQU $C821
Vec_Counter_2 EQU $C82F
VEC_SWI2_VECTOR EQU $CBF2
Draw_VLp_b EQU $F40E
VEC_RFRSH_HI EQU $C83E
Vec_Counter_6 EQU $C833
VECTREX_PRINT_NUMBER.PN_DIV1000 EQU $4050
INTENSITY_1F EQU $F29D
VEC_DOT_DWELL EQU $C828
music2 EQU $FD1D
DELAY_1 EQU $F575
VECTREX_PRINT_NUMBER.PN_L1000 EQU $4052
VEC_EXPL_CHAN EQU $C85C
Print_Str_yx EQU $F378
STRIP_ZEROS EQU $F8B7
VEC_COUNTER_4 EQU $C831
Mov_Draw_VL_ab EQU $F3B7
Warm_Start EQU $F06C
INTENSITY_7F EQU $F2A9
INIT_MUSIC_X EQU $F692
DRAW_VLP EQU $F410
MOVE_MEM_A_1 EQU $F67F
Do_Sound EQU $F289
DIV16.D16_DPOS EQU $40F3
PRINT_STR EQU $F495
Vec_Str_Ptr EQU $C82C
Print_Str_d EQU $F37A
ROT_VL_MODE EQU $F62B
Mov_Draw_VL_a EQU $F3B9
MOV_DRAW_VL_A EQU $F3B9
DRAW_VLC EQU $F3CE
Draw_VL_a EQU $F3DA
DRAW_GRID_VL EQU $FF9F
Read_Btns_Mask EQU $F1B4
MUSICB EQU $FF62
VEC_JOY_MUX_1_X EQU $C81F
VEC_SND_SHADOW EQU $C800
Print_Ships_x EQU $F391
VEC_NUM_PLAYERS EQU $C879
Rot_VL_ab EQU $F610
VEC_EXPL_1 EQU $C858
Vec_Prev_Btns EQU $C810
musica EQU $FF44
Draw_VLp EQU $F410
VEC_MUSIC_WK_6 EQU $C846
VEC_JOY_1_Y EQU $C81C
Vec_Btn_State EQU $C80F
DO_SOUND_X EQU $F28C
MUSIC3 EQU $FD81
CLEAR_X_256 EQU $F545
Delay_0 EQU $F579
Print_Str EQU $F495
RANDOM EQU $F517
Vec_NMI_Vector EQU $CBFB
Vec_Button_1_1 EQU $C812
Vec_Num_Players EQU $C879
Vec_SWI3_Vector EQU $CBF2
Vec_Run_Index EQU $C837
VEC_PATTERN EQU $C829
MOV_DRAW_VL EQU $F3BC
DRAW_VLP_7F EQU $F408
DRAW_PAT_VL_A EQU $F434
GET_RISE_RUN EQU $F5EF
DOT_IX EQU $F2C1
VEC_MISC_COUNT EQU $C823
Draw_VLcs EQU $F3D6
DRAW_CIRCLE_RUNTIME EQU $41C5
music6 EQU $FE76
Get_Rise_Run EQU $F5EF
RISE_RUN_ANGLE EQU $F593
Xform_Rise EQU $F663
VEC_EXPL_CHANA EQU $C853
VEC_MUSIC_WK_1 EQU $C84B
VEC_COUNTER_3 EQU $C830
VEC_COUNTER_1 EQU $C82E
VEC_TEXT_WIDTH EQU $C82B
Vec_Expl_2 EQU $C859
Vec_Button_2_4 EQU $C819
MOVETO_IX_A EQU $F30E
VEC_EXPL_4 EQU $C85B
VEC_BUTTON_1_2 EQU $C813
Xform_Run EQU $F65D
Cold_Start EQU $F000
Intensity_5F EQU $F2A5
PRINT_STR_YX EQU $F378
VEC_RISERUN_LEN EQU $C83B
CLEAR_X_D EQU $F548
RESET0REF_D0 EQU $F34A
READ_BTNS EQU $F1BA
Vec_Dot_Dwell EQU $C828
Vec_Random_Seed EQU $C87D
VEC_RFRSH_LO EQU $C83D
Draw_Grid_VL EQU $FF9F
BITMASK_A EQU $F57E
VEC_EXPL_3 EQU $C85A
MOVETO_IX_7F EQU $F30C
MUSIC2 EQU $FD1D
Vec_RiseRun_Len EQU $C83B
Vec_Text_HW EQU $C82A
Obj_Will_Hit_u EQU $F8E5
Vec_Cold_Flag EQU $CBFE
Xform_Rise_a EQU $F661
ABS_A_B EQU $F584
VEC_BUTTON_1_1 EQU $C812
WARM_START EQU $F06C
VEC_HIGH_SCORE EQU $CBEB
Print_Ships EQU $F393
RESET_PEN EQU $F35B
RANDOM_3 EQU $F511
VEC_RUN_INDEX EQU $C837
Vec_Music_Wk_A EQU $C842
Vec_SWI_Vector EQU $CBFB
Vec_Joy_2_Y EQU $C81E
VEC_MAX_GAMES EQU $C850
Init_Music EQU $F68D
VEC_BUTTON_2_1 EQU $C816
Vec_Pattern EQU $C829
Sound_Bytes_x EQU $F284
MUSIC6 EQU $FE76
Mov_Draw_VL EQU $F3BC
CLEAR_X_B_A EQU $F552
Reset_Pen EQU $F35B
Vec_Expl_ChanA EQU $C853
Vec_Num_Game EQU $C87A
MOVE_MEM_A EQU $F683
Dot_ix_b EQU $F2BE
Draw_VL_mode EQU $F46E
Vec_Expl_4 EQU $C85B
Vec_Joy_Mux EQU $C81F
Bitmask_a EQU $F57E
VEC_BUTTON_2_2 EQU $C817
Vec_Button_2_3 EQU $C818
VECTREX_PRINT_NUMBER.PN_L100 EQU $406C
VECTREX_PRINT_NUMBER.PN_D100 EQU $407E
MUSICA EQU $FF44
VEC_DURATION EQU $C857
Vec_High_Score EQU $CBEB
OBJ_WILL_HIT EQU $F8F3
RECALIBRATE EQU $F2E6
Vec_Music_Wk_7 EQU $C845
VEC_RISE_INDEX EQU $C839
Xform_Run_a EQU $F65B
Intensity_a EQU $F2AB
VEC_FREQ_TABLE EQU $C84D
Vec_Counter_4 EQU $C831
DOT_LIST EQU $F2D5
CLEAR_C8_RAM EQU $F542
WAIT_RECAL EQU $F192
VEC_TEXT_HEIGHT EQU $C82A
VEC_FIRQ_VECTOR EQU $CBF5
Vec_SWI2_Vector EQU $CBF2
VEC_MUSIC_WORK EQU $C83F
MOD16.M16_DPOS EQU $415E
music4 EQU $FDD3
Dot_List_Reset EQU $F2DE
Rise_Run_Y EQU $F601
Print_List_chk EQU $F38C
Vec_Button_2_1 EQU $C816
music7 EQU $FEC6
DRAW_VL_AB EQU $F3D8
CLEAR_X_B_80 EQU $F550
COMPARE_SCORE EQU $F8C7
Dec_3_Counters EQU $F55A
DELAY_3 EQU $F56D
Vec_Music_Wk_1 EQU $C84B
VEC_EXPL_FLAG EQU $C867
Compare_Score EQU $F8C7
VEC_STR_PTR EQU $C82C
Vec_Button_2_2 EQU $C817
MOV_DRAW_VLC_A EQU $F3AD
Vec_Button_1_3 EQU $C814
Draw_VL EQU $F3DD
Clear_Score EQU $F84F
MOD16.M16_LOOP EQU $4175
MUSIC5 EQU $FE38
Recalibrate EQU $F2E6
Print_List_hw EQU $F385
JOY_DIGITAL EQU $F1F8
DO_SOUND EQU $F289
Moveto_d_7F EQU $F2FC
GET_RISE_IDX EQU $F5D9
INTENSITY_3F EQU $F2A1
Move_Mem_a_1 EQU $F67F
Clear_x_b_a EQU $F552
DRAW_VL_MODE EQU $F46E
INIT_MUSIC_BUF EQU $F533
VEC_BUTTON_2_4 EQU $C819
Select_Game EQU $F7A9
VEC_TEXT_HW EQU $C82A
VEC_MUSIC_FREQ EQU $C861
Moveto_ix_7F EQU $F30C
Intensity_1F EQU $F29D
DIV16.D16_RPOS EQU $4112
Init_Music_Buf EQU $F533
DELAY_B EQU $F57A
INIT_OS EQU $F18B
VEC_LOOP_COUNT EQU $C825
PRINT_STR_D EQU $F37A
Delay_RTS EQU $F57D
Init_OS_RAM EQU $F164
CHECK0REF EQU $F34F
MOD16.M16_RPOS EQU $4175
VECTREX_PRINT_TEXT EQU $4000
INTENSITY_A EQU $F2AB
VEC_ADSR_TIMERS EQU $C85E
MUSIC4 EQU $FDD3
Get_Rise_Idx EQU $F5D9
Vec_Loop_Count EQU $C825
MOV_DRAW_VL_D EQU $F3BE
Clear_Sound EQU $F272
J1X_BUILTIN EQU $4195
MOV_DRAW_VL_AB EQU $F3B7
SOUND_BYTES EQU $F27D


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "JOYSTICK_POS"
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
VAR_X                EQU $C880+$37   ; User variable: X (2 bytes)
VAR_Y                EQU $C880+$39   ; User variable: Y (2 bytes)
VAR_CIRCLE_X         EQU $C880+$3B   ; User variable: CIRCLE_X (2 bytes)
VAR_CIRCLE_Y         EQU $C880+$3D   ; User variable: CIRCLE_Y (2 bytes)
VAR_BTN1             EQU $C880+$3F   ; User variable: BTN1 (2 bytes)
VAR_BTN2             EQU $C880+$41   ; User variable: BTN2 (2 bytes)
VAR_BTN3             EQU $C880+$43   ; User variable: BTN3 (2 bytes)
VAR_BTN4             EQU $C880+$45   ; User variable: BTN4 (2 bytes)
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
    STD VAR_X
    LDD #0
    STD VAR_Y
    LDD #0
    STD VAR_CIRCLE_X
    LDD #0
    STD VAR_CIRCLE_Y
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
    ; TODO: Statement Pass { source_line: 17 }

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    JSR J1X_BUILTIN
    STD RESULT
    STD VAR_X
    JSR J1Y_BUILTIN
    STD RESULT
    STD VAR_Y
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD VAR_ARG0
    LDD #80
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_76316012      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #10
    STD VAR_ARG0    ; X position
    LDD #80
    STD VAR_ARG1    ; Y position
    LDD >VAR_X
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD VAR_ARG0
    LDD #60
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_76316013      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #10
    STD VAR_ARG0    ; X position
    LDD #60
    STD VAR_ARG1    ; Y position
    LDD >VAR_Y
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    LDD >VAR_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #2
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR DIV16       ; D = X / D
    STD VAR_CIRCLE_X
    LDD >VAR_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #2
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR DIV16       ; D = X / D
    STD VAR_CIRCLE_Y
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD >VAR_CIRCLE_X
    TFR B,A
    STA DRAW_CIRCLE_XC
    LDD >VAR_CIRCLE_Y
    TFR B,A
    STA DRAW_CIRCLE_YC
    LDD #15
    TFR B,A
    STA DRAW_CIRCLE_DIAM
    LDD #80
    TFR B,A
    STA DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
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
    LDD #40
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2049397      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #0
    STD VAR_ARG0    ; X position
    LDD #40
    STD VAR_ARG1    ; Y position
    LDD >VAR_BTN1
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD VAR_ARG0
    LDD #20
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2049398      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #0
    STD VAR_ARG0    ; X position
    LDD #20
    STD VAR_ARG1    ; Y position
    LDD >VAR_BTN2
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD VAR_ARG0
    LDD #0
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2049399      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #0
    STD VAR_ARG0    ; X position
    LDD #0
    STD VAR_ARG1    ; Y position
    LDD >VAR_BTN3
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD VAR_ARG0
    LDD #-20
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2049400      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #0
    STD VAR_ARG0    ; X position
    LDD #-20
    STD VAR_ARG1    ; Y position
    LDD >VAR_BTN4
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    RTS


; ================================================
