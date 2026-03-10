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
VAR_ANGLE            EQU $C880+$31   ; User variable: angle (2 bytes)
VAR_PX               EQU $C880+$33   ; User variable: px (2 bytes)
VAR_PY               EQU $C880+$35   ; User variable: py (2 bytes)
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
MOV_DRAW_VLCS EQU $F3B5
MUSICA EQU $FF44
Moveto_d_7F EQU $F2FC
Vec_Button_1_1 EQU $C812
Draw_VLp_scale EQU $F40C
Add_Score_d EQU $F87C
Moveto_x_7F EQU $F2F2
SOUND_BYTE EQU $F256
Vec_Joy_2_X EQU $C81D
Vec_Music_Ptr EQU $C853
VEC_RANDOM_SEED EQU $C87D
Vec_ADSR_Table EQU $C84F
Draw_VL_b EQU $F3D2
SOUND_BYTE_RAW EQU $F25B
SOUND_BYTES_X EQU $F284
Vec_Button_1_2 EQU $C813
DRAW_PAT_VL_A EQU $F434
Vec_Text_Width EQU $C82B
Vec_Counter_1 EQU $C82E
Vec_Expl_2 EQU $C859
Vec_Text_HW EQU $C82A
VEC_SWI2_VECTOR EQU $CBF2
musicc EQU $FF7A
Vec_0Ref_Enable EQU $C824
Print_Str_yx EQU $F378
VEC_HIGH_SCORE EQU $CBEB
Get_Rise_Idx EQU $F5D9
VEC_MUSIC_FREQ EQU $C861
Vec_Music_Chan EQU $C855
DRAW_VL EQU $F3DD
VEC_BUTTON_2_1 EQU $C816
Vec_Button_2_4 EQU $C819
CLEAR_SCORE EQU $F84F
Vec_Joy_2_Y EQU $C81E
MOV_DRAW_VL_B EQU $F3B1
MUSIC1 EQU $FD0D
VEC_BUTTON_1_3 EQU $C814
VEC_TEXT_WIDTH EQU $C82B
VEC_EXPL_TIMER EQU $C877
VEC_JOY_2_X EQU $C81D
Vec_ADSR_Timers EQU $C85E
Vec_Joy_Mux EQU $C81F
DIV16 EQU $4030
music4 EQU $FDD3
Dot_ix_b EQU $F2BE
Vec_Counter_2 EQU $C82F
INIT_VIA EQU $F14C
PRINT_STR EQU $F495
DCR_INTENSITY_5F EQU $4124
Warm_Start EQU $F06C
NEW_HIGH_SCORE EQU $F8D8
DIV16.D16_RCHECK EQU $4055
VEC_MUSIC_TWANG EQU $C858
CLEAR_X_B_A EQU $F552
Vec_Music_Wk_6 EQU $C846
Recalibrate EQU $F2E6
Random EQU $F517
Draw_VLc EQU $F3CE
DELAY_0 EQU $F579
Xform_Run_a EQU $F65B
Vec_Counters EQU $C82E
Draw_Pat_VL_a EQU $F434
DRAW_VLP EQU $F410
ABS_B EQU $F58B
BITMASK_A EQU $F57E
Print_Str_d EQU $F37A
Draw_VL_mode EQU $F46E
Vec_Music_Work EQU $C83F
MOVETO_IX_7F EQU $F30C
MUSICB EQU $FF62
Vec_Joy_Mux_2_Y EQU $C822
PRINT_STR_D EQU $F37A
Sound_Bytes EQU $F27D
Vec_Expl_ChanA EQU $C853
PRINT_STR_HWYX EQU $F373
VEC_EXPL_2 EQU $C859
Vec_Rfrsh_hi EQU $C83E
VEC_MUSIC_WORK EQU $C83F
Vec_Prev_Btns EQU $C810
MUSIC6 EQU $FE76
Draw_VLp_b EQU $F40E
Set_Refresh EQU $F1A2
Vec_Str_Ptr EQU $C82C
Obj_Hit EQU $F8FF
Vec_Rise_Index EQU $C839
OBJ_WILL_HIT EQU $F8F3
Vec_RiseRun_Tmp EQU $C834
musicd EQU $FF8F
VEC_EXPL_CHANB EQU $C85D
Vec_Expl_4 EQU $C85B
VEC_JOY_MUX_2_X EQU $C821
SIN_TABLE EQU $433C
CLEAR_X_B_80 EQU $F550
DLW_SEG1_DY_NO_CLAMP EQU $4283
Vec_Music_Flag EQU $C856
VECTREX_PRINT_TEXT EQU $4000
DLW_SEG2_DY_NO_REMAIN EQU $42FA
Cold_Start EQU $F000
VEC_NUM_PLAYERS EQU $C879
DP_TO_D0 EQU $F1AA
Vec_Music_Wk_A EQU $C842
DLW_SEG2_DX_DONE EQU $4328
VEC_PATTERN EQU $C829
Move_Mem_a_1 EQU $F67F
DIV16.D16_RPOS EQU $406C
RISE_RUN_Y EQU $F601
MOD16 EQU $409B
Intensity_3F EQU $F2A1
Moveto_ix_FF EQU $F308
Vec_Misc_Count EQU $C823
Intensity_a EQU $F2AB
DEC_6_COUNTERS EQU $F55E
Clear_Sound EQU $F272
XFORM_RISE EQU $F663
VEC_ADSR_TABLE EQU $C84F
CLEAR_X_256 EQU $F545
Delay_1 EQU $F575
MOV_DRAW_VL_A EQU $F3B9
Wait_Recal EQU $F192
MOV_DRAW_VL EQU $F3BC
MOD16.M16_RCHECK EQU $40C0
Rot_VL_ab EQU $F610
DCR_after_intensity EQU $4127
VEC_MAX_GAMES EQU $C850
Vec_Btn_State EQU $C80F
Vec_Angle EQU $C836
EXPLOSION_SND EQU $F92E
Vec_SWI2_Vector EQU $CBF2
DIV16.D16_LOOP EQU $4072
Vec_Cold_Flag EQU $CBFE
DIV16.D16_DPOS EQU $404D
Do_Sound_x EQU $F28C
INTENSITY_7F EQU $F2A9
DEC_3_COUNTERS EQU $F55A
Delay_0 EQU $F579
DRAW_VLP_FF EQU $F404
DELAY_RTS EQU $F57D
VEC_RFRSH_HI EQU $C83E
Vec_Button_1_3 EQU $C814
Vec_Rfrsh_lo EQU $C83D
Rot_VL_Mode_a EQU $F61F
JOY_DIGITAL EQU $F1F8
VEC_COUNTER_1 EQU $C82E
Read_Btns EQU $F1BA
Abs_a_b EQU $F584
RESET0REF_D0 EQU $F34A
INIT_MUSIC_X EQU $F692
VEC_MAX_PLAYERS EQU $C84F
PRINT_LIST_CHK EQU $F38C
Vec_IRQ_Vector EQU $CBF8
Vec_Expl_1 EQU $C858
VEC_MUSIC_WK_5 EQU $C847
VEC_NUM_GAME EQU $C87A
musicb EQU $FF62
MOD16.M16_DPOS EQU $40B8
Xform_Run EQU $F65D
DLW_NEED_SEG2 EQU $42E1
VEC_RUN_INDEX EQU $C837
Vec_Button_2_3 EQU $C818
Move_Mem_a EQU $F683
Vec_Num_Players EQU $C879
VEC_BUTTON_1_2 EQU $C813
music7 EQU $FEC6
Draw_VL_ab EQU $F3D8
DLW_SEG1_DY_LO EQU $4276
Vec_Duration EQU $C857
VEC_JOY_1_Y EQU $C81C
VEC_MISC_COUNT EQU $C823
musica EQU $FF44
MOVETO_D EQU $F312
WAIT_RECAL EQU $F192
Print_Ships_x EQU $F391
Dot_d EQU $F2C3
ADD_SCORE_A EQU $F85E
INIT_MUSIC_BUF EQU $F533
PRINT_SHIPS EQU $F393
Vec_Joy_Resltn EQU $C81A
Vec_Default_Stk EQU $CBEA
VEC_RISERUN_LEN EQU $C83B
VEC_RFRSH EQU $C83D
DELAY_2 EQU $F571
Draw_Line_d EQU $F3DF
MOV_DRAW_VL_D EQU $F3BE
Vec_Text_Height EQU $C82A
VEC_EXPL_CHAN EQU $C85C
DRAW_VL_B EQU $F3D2
Sound_Byte_x EQU $F259
VEC_COUNTERS EQU $C82E
Draw_Grid_VL EQU $FF9F
COLD_START EQU $F000
VEC_COUNTER_5 EQU $C832
CLEAR_X_B EQU $F53F
Clear_x_b_a EQU $F552
VEC_FREQ_TABLE EQU $C84D
MUSIC7 EQU $FEC6
CHECK0REF EQU $F34F
DELAY_B EQU $F57A
DCR_intensity_5F EQU $4124
Sound_Byte EQU $F256
INIT_MUSIC_CHK EQU $F687
VEC_BRIGHTNESS EQU $C827
Vec_Expl_Chans EQU $C854
Print_List_hw EQU $F385
SELECT_GAME EQU $F7A9
VEC_DOT_DWELL EQU $C828
DRAW_VL_MODE EQU $F46E
MOVETO_IX EQU $F310
Delay_3 EQU $F56D
GET_RUN_IDX EQU $F5DB
MUSIC3 EQU $FD81
OBJ_WILL_HIT_U EQU $F8E5
MUSIC5 EQU $FE38
VEC_MUSIC_CHAN EQU $C855
Vec_NMI_Vector EQU $CBFB
Intensity_7F EQU $F2A9
VEC_RISE_INDEX EQU $C839
GET_RISE_IDX EQU $F5D9
Vec_Freq_Table EQU $C84D
Vec_Counter_3 EQU $C830
VEC_JOY_MUX_1_X EQU $C81F
Vec_Music_Wk_1 EQU $C84B
Vec_Joy_Mux_1_Y EQU $C820
Clear_x_256 EQU $F545
Joy_Analog EQU $F1F5
TAN_TABLE EQU $453C
ROT_VL_DFT EQU $F637
Draw_VLp_7F EQU $F408
Vec_Buttons EQU $C811
Vec_Joy_1_Y EQU $C81C
music3 EQU $FD81
DP_to_C8 EQU $F1AF
VEC_COUNTER_3 EQU $C830
RESET0REF EQU $F354
Vec_Music_Wk_5 EQU $C847
Get_Run_Idx EQU $F5DB
DRAW_GRID_VL EQU $FF9F
Init_VIA EQU $F14C
XFORM_RUN EQU $F65D
Mov_Draw_VL_ab EQU $F3B7
VEC_RFRSH_LO EQU $C83D
Bitmask_a EQU $F57E
VEC_EXPL_CHANS EQU $C854
XFORM_RUN_A EQU $F65B
Vec_Dot_Dwell EQU $C828
VEC_LOOP_COUNT EQU $C825
VEC_COLD_FLAG EQU $CBFE
ROT_VL EQU $F616
XFORM_RISE_A EQU $F661
Vec_Expl_ChanB EQU $C85D
Vec_Expl_3 EQU $C85A
VEC_MUSIC_WK_1 EQU $C84B
Clear_x_b_80 EQU $F550
WARM_START EQU $F06C
RESET0INT EQU $F36B
VEC_FIRQ_VECTOR EQU $CBF5
PRINT_STR_YX EQU $F378
Vec_Num_Game EQU $C87A
INIT_OS EQU $F18B
DRAW_VLP_7F EQU $F408
VEC_ADSR_TIMERS EQU $C85E
VEC_SWI_VECTOR EQU $CBFB
DRAW_VL_A EQU $F3DA
VEC_DEFAULT_STK EQU $CBEA
Vec_FIRQ_Vector EQU $CBF5
New_High_Score EQU $F8D8
Compare_Score EQU $F8C7
DLW_DONE EQU $4337
DELAY_3 EQU $F56D
Vec_Loop_Count EQU $C825
Rot_VL_dft EQU $F637
INTENSITY_1F EQU $F29D
Rise_Run_X EQU $F5FF
MOD16.M16_END EQU $40DF
Intensity_1F EQU $F29D
DOT_IX_B EQU $F2BE
Clear_C8_RAM EQU $F542
Vec_Button_1_4 EQU $C815
MUSIC9 EQU $FF26
Vec_Run_Index EQU $C837
Vec_Joy_1_X EQU $C81B
Strip_Zeros EQU $F8B7
Mov_Draw_VL_a EQU $F3B9
VEC_JOY_2_Y EQU $C81E
DP_TO_C8 EQU $F1AF
ADD_SCORE_D EQU $F87C
Rise_Run_Len EQU $F603
Clear_x_b EQU $F53F
Init_Music_Buf EQU $F533
VEC_DURATION EQU $C857
Mov_Draw_VLcs EQU $F3B5
DIV16.D16_END EQU $408B
ROT_VL_MODE_A EQU $F61F
Vec_Twang_Table EQU $C851
music8 EQU $FEF8
DOT_LIST_RESET EQU $F2DE
DOT_IX EQU $F2C1
Explosion_Snd EQU $F92E
VEC_COUNTER_2 EQU $C82F
Rise_Run_Y EQU $F601
DRAW_LINE_D EQU $F3DF
Vec_SWI_Vector EQU $CBFB
Moveto_ix EQU $F310
DRAW_CIRCLE_RUNTIME EQU $40EF
Rot_VL_Mode EQU $F62B
VEC_BUTTON_2_3 EQU $C818
DOT_LIST EQU $F2D5
VEC_MUSIC_PTR EQU $C853
Rot_VL EQU $F616
Vec_Max_Games EQU $C850
DRAW_VLCS EQU $F3D6
Clear_x_d EQU $F548
DLW_SEG1_DY_READY EQU $4286
Random_3 EQU $F511
DRAW_PAT_VL_D EQU $F439
Select_Game EQU $F7A9
DLW_SEG2_DX_NO_REMAIN EQU $4325
PRINT_TEXT_STR_75826235280 EQU $463C
VEC_TWANG_TABLE EQU $C851
VEC_JOY_MUX_1_Y EQU $C820
Vec_Brightness EQU $C827
VEC_EXPL_CHANA EQU $C853
Clear_Score EQU $F84F
Print_Str EQU $F495
Do_Sound EQU $F289
VEC_STR_PTR EQU $C82C
VEC_MUSIC_WK_7 EQU $C845
Vec_Max_Players EQU $C84F
VEC_MUSIC_FLAG EQU $C856
DRAW_PAT_VL EQU $F437
RISE_RUN_LEN EQU $F603
VEC_PREV_BTNS EQU $C810
INTENSITY_5F EQU $F2A5
ROT_VL_AB EQU $F610
VEC_JOY_MUX EQU $C81F
VEC_JOY_1_X EQU $C81B
VEC_NMI_VECTOR EQU $CBFB
CLEAR_C8_RAM EQU $F542
MUSIC2 EQU $FD1D
Init_OS EQU $F18B
MOV_DRAW_VLC_A EQU $F3AD
Check0Ref EQU $F34F
Reset0Ref EQU $F354
DRAW_VL_AB EQU $F3D8
INIT_OS_RAM EQU $F164
VEC_EXPL_1 EQU $C858
DLW_SEG2_DY_DONE EQU $4303
SOUND_BYTES EQU $F27D
Intensity_5F EQU $F2A5
Draw_VL EQU $F3DD
music2 EQU $FD1D
MOD16.M16_RPOS EQU $40CF
DRAW_VLP_SCALE EQU $F40C
Sound_Bytes_x EQU $F284
Vec_Joy_Mux_2_X EQU $C821
Vec_Music_Freq EQU $C861
VEC_MUSIC_WK_6 EQU $C846
MUSIC8 EQU $FEF8
RANDOM EQU $F517
Reset0Int EQU $F36B
VEC_BUTTON_2_2 EQU $C817
DLW_SEG2_DX_CHECK_NEG EQU $4317
RESET_PEN EQU $F35B
COS_TABLE EQU $443C
Vec_Expl_Flag EQU $C867
Draw_Pat_VL_d EQU $F439
Dot_List EQU $F2D5
DLW_SEG1_DX_NO_CLAMP EQU $42A6
music6 EQU $FE76
STRIP_ZEROS EQU $F8B7
music9 EQU $FF26
Dec_3_Counters EQU $F55A
MOVETO_D_7F EQU $F2FC
Mov_Draw_VL_b EQU $F3B1
Get_Rise_Run EQU $F5EF
READ_BTNS EQU $F1BA
VEC_SEED_PTR EQU $C87B
COMPARE_SCORE EQU $F8C7
INTENSITY_A EQU $F2AB
MOVE_MEM_A EQU $F683
DO_SOUND EQU $F289
MOVE_MEM_A_1 EQU $F67F
PRINT_SHIPS_X EQU $F391
VEC_BUTTON_1_4 EQU $C815
MOVETO_IX_FF EQU $F308
Reset_Pen EQU $F35B
SET_REFRESH EQU $F1A2
Delay_2 EQU $F571
DEC_COUNTERS EQU $F563
Abs_b EQU $F58B
MUSIC4 EQU $FDD3
Vec_SWI3_Vector EQU $CBF2
RECALIBRATE EQU $F2E6
VEC_0REF_ENABLE EQU $C824
Delay_b EQU $F57A
OBJ_HIT EQU $F8FF
MUSICD EQU $FF8F
READ_BTNS_MASK EQU $F1B4
Vec_Music_Twang EQU $C858
CLEAR_X_D EQU $F548
MOD16.M16_DONE EQU $40EE
Dot_ix EQU $F2C1
Dec_Counters EQU $F563
Dec_6_Counters EQU $F55E
music5 EQU $FE38
DOT_D EQU $F2C3
Init_Music EQU $F68D
DELAY_1 EQU $F575
DRAW_VLC EQU $F3CE
CLEAR_SOUND EQU $F272
Moveto_ix_7F EQU $F30C
Draw_VLp EQU $F410
VEC_MUSIC_WK_A EQU $C842
Xform_Rise EQU $F663
Vec_Counter_4 EQU $C831
MUSICC EQU $FF7A
Obj_Will_Hit_u EQU $F8E5
MOVETO_IX_A EQU $F30E
Add_Score_a EQU $F85E
ABS_A_B EQU $F584
VEC_JOY_RESLTN EQU $C81A
VEC_BTN_STATE EQU $C80F
RISE_RUN_X EQU $F5FF
Sound_Byte_raw EQU $F25B
DO_SOUND_X EQU $F28C
music1 EQU $FD0D
GET_RISE_RUN EQU $F5EF
Print_List EQU $F38A
ROT_VL_MODE EQU $F62B
Vec_Button_2_1 EQU $C816
Vec_Expl_Timer EQU $C877
Xform_Rise_a EQU $F661
DCR_AFTER_INTENSITY EQU $4127
DIV16.D16_DONE EQU $409A
DOT_HERE EQU $F2C5
Joy_Digital EQU $F1F8
INTENSITY_3F EQU $F2A1
DRAW_VLP_B EQU $F40E
DP_to_D0 EQU $F1AA
VEC_TEXT_HEIGHT EQU $C82A
Reset0Ref_D0 EQU $F34A
Vec_Music_Wk_7 EQU $C845
Dot_List_Reset EQU $F2DE
Vec_Random_Seed EQU $C87D
Print_Ships EQU $F393
Obj_Will_Hit EQU $F8F3
PRINT_LIST_HW EQU $F385
Vec_Joy_Mux_1_X EQU $C81F
MOD16.M16_LOOP EQU $40CF
Vec_Button_2_2 EQU $C817
VEC_COUNTER_4 EQU $C831
MOVETO_X_7F EQU $F2F2
Mov_Draw_VL_d EQU $F3BE
DLW_SEG1_DX_READY EQU $42A9
JOY_ANALOG EQU $F1F5
Mov_Draw_VL EQU $F3BC
Mov_Draw_VLc_a EQU $F3AD
Vec_Expl_Chan EQU $C85C
RISE_RUN_ANGLE EQU $F593
MOV_DRAW_VL_AB EQU $F3B7
Rise_Run_Angle EQU $F593
VEC_SWI3_VECTOR EQU $CBF2
DLW_SEG1_DX_LO EQU $4299
Draw_Pat_VL EQU $F437
Draw_VLp_FF EQU $F404
VEC_JOY_MUX_2_Y EQU $C822
VEC_TEXT_HW EQU $C82A
Vec_Snd_Shadow EQU $C800
Draw_VL_a EQU $F3DA
VEC_EXPL_FLAG EQU $C867
Print_List_chk EQU $F38C
VEC_SND_SHADOW EQU $C800
Vec_Counter_6 EQU $C833
VEC_COUNTER_6 EQU $C833
Vec_High_Score EQU $CBEB
Init_Music_x EQU $F692
Read_Btns_Mask EQU $F1B4
PRINT_LIST EQU $F38A
VEC_BUTTONS EQU $C811
DRAW_LINE_WRAPPER EQU $4234
VEC_RISERUN_TMP EQU $C834
SOUND_BYTE_X EQU $F259
DLW_SEG2_DY_POS EQU $4300
Vec_Pattern EQU $C829
VEC_EXPL_3 EQU $C85A
Draw_VLcs EQU $F3D6
Vec_Seed_Ptr EQU $C87B
Vec_RiseRun_Len EQU $C83B
Init_Music_chk EQU $F687
Moveto_d EQU $F312
VEC_BUTTON_1_1 EQU $C812
Vec_Counter_5 EQU $C832
VEC_BUTTON_2_4 EQU $C819
VEC_EXPL_4 EQU $C85B
INIT_MUSIC EQU $F68D
Moveto_ix_a EQU $F30E
RANDOM_3 EQU $F511
Vec_Rfrsh EQU $C83D
Delay_RTS EQU $F57D
VEC_ANGLE EQU $C836
Print_Str_hwyx EQU $F373
Dot_here EQU $F2C5
Init_OS_RAM EQU $F164
VEC_IRQ_VECTOR EQU $CBF8


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "TRIG"
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
VAR_ANGLE            EQU $C880+$31   ; User variable: angle (2 bytes)
VAR_PX               EQU $C880+$33   ; User variable: px (2 bytes)
VAR_PY               EQU $C880+$35   ; User variable: py (2 bytes)
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
    STD VAR_ANGLE
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
    STD VAR_ANGLE

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
    LDX #PRINT_TEXT_STR_75826235280      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; COS: Cosine lookup
    LDD >VAR_ANGLE
    ANDB #$7F
    CLRA
    ASLB
    ROLA
    LDX #COS_TABLE
    ABX
    LDD ,X
    STD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #3
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR DIV16       ; D = X / D
    STD VAR_PX
    ; SIN: Sine lookup
    LDD >VAR_ANGLE
    ANDB #$7F      ; Mask to 0-127
    CLRA           ; Clear high byte
    ASLB
    ROLA
    LDX #SIN_TABLE
    ABX            ; Add offset to table base
    LDD ,X         ; Load 16-bit value
    STD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #3
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR DIV16       ; D = X / D
    STD VAR_PY
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD >VAR_PX
    TFR B,A
    STA DRAW_CIRCLE_XC
    LDD >VAR_PY
    TFR B,A
    STA DRAW_CIRCLE_YC
    LDD #30
    TFR B,A
    STA DRAW_CIRCLE_DIAM
    LDD #100
    TFR B,A
    STA DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #0
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #-5
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #0
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #5
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #40
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #-5
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #0
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #5
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #0
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #40
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
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
    LDB #$15
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$08
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$07
    LDB #$FC
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$04
    LDB #$F9
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$F8
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$F8
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FC
    LDB #$F9
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$F9
    LDB #$FC
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$F8
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$F8
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$F9
    LDB #$04
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FC
    LDB #$07
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$08
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$08
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$04
    LDB #$07
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$07
    LDB #$04
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$08
    LDB #$02
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LDD >VAR_ANGLE
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ANGLE
    LDD #127
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ANGLE
    CMPD TMPVAL
    LBGT .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_1
    LDD #0
    STD VAR_ANGLE
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    RTS


; ================================================
