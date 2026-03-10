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
VAR_JX               EQU $C880+$31   ; User variable: jx (2 bytes)
VAR_JY               EQU $C880+$33   ; User variable: jy (2 bytes)
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
READ_BTNS EQU $F1BA
Vec_Joy_Mux_1_X EQU $C81F
VEC_MUSIC_WORK EQU $C83F
Vec_Random_Seed EQU $C87D
DRAW_PAT_VL_D EQU $F439
Vec_Misc_Count EQU $C823
VEC_TEXT_WIDTH EQU $C82B
Vec_Button_2_1 EQU $C816
Get_Run_Idx EQU $F5DB
Abs_a_b EQU $F584
Moveto_d EQU $F312
Dot_d EQU $F2C3
Draw_Grid_VL EQU $FF9F
VEC_MUSIC_CHAN EQU $C855
SELECT_GAME EQU $F7A9
Init_OS EQU $F18B
Rot_VL_dft EQU $F637
Sound_Bytes EQU $F27D
VEC_COUNTER_2 EQU $C82F
Random_3 EQU $F511
Vec_Counter_1 EQU $C82E
RESET_PEN EQU $F35B
Mov_Draw_VL EQU $F3BC
VEC_NUM_PLAYERS EQU $C879
VEC_BUTTON_2_4 EQU $C819
MUSICB EQU $FF62
Vec_Button_1_1 EQU $C812
VEC_TEXT_HW EQU $C82A
Mov_Draw_VL_ab EQU $F3B7
DCR_intensity_5F EQU $414E
music9 EQU $FF26
Rise_Run_Len EQU $F603
Compare_Score EQU $F8C7
STRIP_ZEROS EQU $F8B7
VEC_SND_SHADOW EQU $C800
DRAW_LINE_WRAPPER EQU $425E
VEC_EXPL_CHANA EQU $C853
Cold_Start EQU $F000
DLW_DONE EQU $4361
Vec_Joy_Mux_2_Y EQU $C822
Set_Refresh EQU $F1A2
New_High_Score EQU $F8D8
Read_Btns_Mask EQU $F1B4
INIT_MUSIC_BUF EQU $F533
VEC_DOT_DWELL EQU $C828
Obj_Hit EQU $F8FF
OBJ_WILL_HIT EQU $F8F3
DOT_LIST EQU $F2D5
VEC_ANGLE EQU $C836
CLEAR_X_D EQU $F548
Clear_Sound EQU $F272
Draw_VL EQU $F3DD
CLEAR_X_B EQU $F53F
Clear_Score EQU $F84F
VEC_NUM_GAME EQU $C87A
DELAY_0 EQU $F579
Vec_Text_Width EQU $C82B
Draw_Pat_VL_a EQU $F434
Draw_VLp_FF EQU $F404
Dec_6_Counters EQU $F55E
Rise_Run_Y EQU $F601
JOY_ANALOG EQU $F1F5
DP_to_D0 EQU $F1AA
Rot_VL_ab EQU $F610
ROT_VL_MODE_A EQU $F61F
DRAW_VL EQU $F3DD
Check0Ref EQU $F34F
MOVETO_IX_7F EQU $F30C
MOVETO_D EQU $F312
Vec_Duration EQU $C857
DRAW_LINE_D EQU $F3DF
DRAW_VL_AB EQU $F3D8
VEC_FREQ_TABLE EQU $C84D
VEC_STR_PTR EQU $C82C
DRAW_GRID_VL EQU $FF9F
DIV16.D16_END EQU $408B
DOT_LIST_RESET EQU $F2DE
COMPARE_SCORE EQU $F8C7
VEC_MUSIC_TWANG EQU $C858
Draw_Line_d EQU $F3DF
MOVE_MEM_A_1 EQU $F67F
PRINT_LIST_HW EQU $F385
Vec_FIRQ_Vector EQU $CBF5
Rot_VL_Mode_a EQU $F61F
Delay_3 EQU $F56D
Warm_Start EQU $F06C
VEC_IRQ_VECTOR EQU $CBF8
Delay_1 EQU $F575
Vec_Expl_Timer EQU $C877
Rot_VL_Mode EQU $F62B
Vec_Joy_Mux EQU $C81F
VEC_JOY_2_X EQU $C81D
VEC_BUTTON_2_1 EQU $C816
music6 EQU $FE76
Vec_Expl_ChanA EQU $C853
Vec_Expl_1 EQU $C858
Vec_Expl_Flag EQU $C867
VEC_COUNTER_5 EQU $C832
MUSIC3 EQU $FD81
VEC_EXPL_FLAG EQU $C867
Vec_Brightness EQU $C827
DOT_D EQU $F2C3
Mov_Draw_VL_d EQU $F3BE
VEC_RFRSH_HI EQU $C83E
Vec_Counter_6 EQU $C833
VEC_MUSIC_FREQ EQU $C861
DCR_AFTER_INTENSITY EQU $4151
Move_Mem_a_1 EQU $F67F
Delay_b EQU $F57A
MOD16.M16_END EQU $40DF
RESET0INT EQU $F36B
Print_Ships EQU $F393
OBJ_HIT EQU $F8FF
Vec_Expl_2 EQU $C859
Vec_High_Score EQU $CBEB
DRAW_VLP_SCALE EQU $F40C
MUSICD EQU $FF8F
VEC_COUNTER_6 EQU $C833
INIT_OS EQU $F18B
MOVETO_IX_A EQU $F30E
DLW_SEG2_DY_DONE EQU $432D
Get_Rise_Run EQU $F5EF
Intensity_3F EQU $F2A1
PRINT_STR_HWYX EQU $F373
Vec_Counter_2 EQU $C82F
DRAW_PAT_VL_A EQU $F434
Sound_Bytes_x EQU $F284
Vec_Loop_Count EQU $C825
Vec_Twang_Table EQU $C851
PRINT_LIST EQU $F38A
VEC_JOY_MUX_2_Y EQU $C822
Vec_Rfrsh_hi EQU $C83E
Vec_Rfrsh EQU $C83D
VEC_BUTTON_1_3 EQU $C814
Dec_Counters EQU $F563
Moveto_d_7F EQU $F2FC
VEC_JOY_RESLTN EQU $C81A
CLEAR_SOUND EQU $F272
Vec_Button_1_4 EQU $C815
Vec_ADSR_Table EQU $C84F
MOVE_MEM_A EQU $F683
INTENSITY_7F EQU $F2A9
VEC_RFRSH_LO EQU $C83D
VEC_ADSR_TABLE EQU $C84F
DCR_after_intensity EQU $4151
RANDOM EQU $F517
Sound_Byte_raw EQU $F25B
VEC_MUSIC_WK_6 EQU $C846
XFORM_RISE EQU $F663
DLW_SEG1_DY_NO_CLAMP EQU $42AD
Xform_Run_a EQU $F65B
VEC_RANDOM_SEED EQU $C87D
DELAY_2 EQU $F571
NEW_HIGH_SCORE EQU $F8D8
VEC_PREV_BTNS EQU $C810
CLEAR_X_256 EQU $F545
DRAW_CIRCLE_RUNTIME EQU $4119
PRINT_SHIPS EQU $F393
SOUND_BYTES EQU $F27D
INTENSITY_1F EQU $F29D
J2X_BUILTIN EQU $40EF
VECTREX_PRINT_TEXT EQU $4000
VEC_RFRSH EQU $C83D
Clear_C8_RAM EQU $F542
VEC_BUTTON_2_2 EQU $C817
EXPLOSION_SND EQU $F92E
VEC_JOY_1_Y EQU $C81C
Vec_Expl_ChanB EQU $C85D
RISE_RUN_X EQU $F5FF
VEC_COUNTER_3 EQU $C830
VEC_BUTTON_1_4 EQU $C815
DELAY_RTS EQU $F57D
DLW_SEG2_DY_NO_REMAIN EQU $4324
MUSICA EQU $FF44
MOVETO_D_7F EQU $F2FC
MOD16.M16_RCHECK EQU $40C0
Vec_Joy_Mux_2_X EQU $C821
Vec_Buttons EQU $C811
DLW_SEG1_DX_NO_CLAMP EQU $42D0
musicd EQU $FF8F
Mov_Draw_VLcs EQU $F3B5
ABS_B EQU $F58B
ROT_VL_DFT EQU $F637
VEC_MAX_PLAYERS EQU $C84F
VEC_EXPL_2 EQU $C859
DRAW_VLP_FF EQU $F404
Clear_x_d EQU $F548
SOUND_BYTE_X EQU $F259
Joy_Digital EQU $F1F8
DLW_NEED_SEG2 EQU $430B
PRINT_STR_YX EQU $F378
DIV16.D16_RCHECK EQU $4055
Read_Btns EQU $F1BA
VEC_MUSIC_PTR EQU $C853
Dot_List_Reset EQU $F2DE
DELAY_3 EQU $F56D
VEC_RISE_INDEX EQU $C839
VEC_MUSIC_WK_5 EQU $C847
Vec_Max_Games EQU $C850
Dot_ix_b EQU $F2BE
Vec_RiseRun_Len EQU $C83B
Moveto_ix_FF EQU $F308
Vec_Btn_State EQU $C80F
CLEAR_X_B_A EQU $F552
MOV_DRAW_VL_AB EQU $F3B7
Vec_Str_Ptr EQU $C82C
ADD_SCORE_D EQU $F87C
VEC_RUN_INDEX EQU $C837
VEC_EXPL_3 EQU $C85A
PRINT_SHIPS_X EQU $F391
Vec_Joy_2_Y EQU $C81E
RISE_RUN_Y EQU $F601
READ_BTNS_MASK EQU $F1B4
VEC_TWANG_TABLE EQU $C851
Recalibrate EQU $F2E6
RISE_RUN_LEN EQU $F603
VEC_RISERUN_LEN EQU $C83B
Vec_IRQ_Vector EQU $CBF8
Draw_VLp EQU $F410
Xform_Run EQU $F65D
GET_RISE_RUN EQU $F5EF
Abs_b EQU $F58B
Move_Mem_a EQU $F683
DRAW_VLP_7F EQU $F408
Vec_Music_Wk_6 EQU $C846
Obj_Will_Hit EQU $F8F3
Vec_Rfrsh_lo EQU $C83D
Vec_Cold_Flag EQU $CBFE
VEC_0REF_ENABLE EQU $C824
Init_Music_x EQU $F692
MUSIC5 EQU $FE38
Print_List_chk EQU $F38C
WAIT_RECAL EQU $F192
MOV_DRAW_VL_A EQU $F3B9
Vec_Music_Wk_1 EQU $C84B
Add_Score_d EQU $F87C
Vec_Music_Ptr EQU $C853
Moveto_ix EQU $F310
MOV_DRAW_VLCS EQU $F3B5
MOD16 EQU $409B
Vec_Num_Players EQU $C879
Init_Music_chk EQU $F687
Vec_Joy_1_X EQU $C81B
Vec_Counters EQU $C82E
SOUND_BYTES_X EQU $F284
RECALIBRATE EQU $F2E6
VEC_COLD_FLAG EQU $CBFE
Intensity_a EQU $F2AB
music8 EQU $FEF8
Draw_VL_b EQU $F3D2
VEC_BUTTON_2_3 EQU $C818
Sound_Byte EQU $F256
Draw_VLp_scale EQU $F40C
MOD16.M16_LOOP EQU $40CF
Vec_Joy_Mux_1_Y EQU $C820
DLW_SEG1_DY_READY EQU $42B0
Moveto_x_7F EQU $F2F2
VEC_EXPL_1 EQU $C858
MUSIC7 EQU $FEC6
MOVETO_IX_FF EQU $F308
MUSIC2 EQU $FD1D
DOT_HERE EQU $F2C5
VEC_LOOP_COUNT EQU $C825
Reset0Ref_D0 EQU $F34A
PRINT_TEXT_STR_44450992618 EQU $436D
Vec_SWI_Vector EQU $CBFB
Dot_ix EQU $F2C1
DEC_3_COUNTERS EQU $F55A
INIT_VIA EQU $F14C
VEC_EXPL_CHANS EQU $C854
musicb EQU $FF62
Vec_Expl_4 EQU $C85B
Vec_Music_Wk_7 EQU $C845
Clear_x_b_80 EQU $F550
Mov_Draw_VLc_a EQU $F3AD
SOUND_BYTE_RAW EQU $F25B
CLEAR_X_B_80 EQU $F550
Draw_VLp_7F EQU $F408
Init_Music EQU $F68D
Vec_Freq_Table EQU $C84D
DLW_SEG1_DX_LO EQU $42C3
musicc EQU $FF7A
Print_List EQU $F38A
PRINT_STR EQU $F495
music3 EQU $FD81
VEC_MUSIC_FLAG EQU $C856
MUSIC4 EQU $FDD3
Draw_VLc EQU $F3CE
VEC_COUNTERS EQU $C82E
Vec_Angle EQU $C836
Draw_Pat_VL EQU $F437
Vec_Joy_1_Y EQU $C81C
MOD16.M16_DPOS EQU $40B8
Clear_x_256 EQU $F545
VEC_BUTTONS EQU $C811
INTENSITY_3F EQU $F2A1
Vec_Music_Wk_5 EQU $C847
VEC_MUSIC_WK_A EQU $C842
DLW_SEG1_DY_LO EQU $42A0
MOD16.M16_RPOS EQU $40CF
Print_Str_d EQU $F37A
Vec_Expl_3 EQU $C85A
DELAY_B EQU $F57A
Vec_Expl_Chan EQU $C85C
DRAW_VL_B EQU $F3D2
DELAY_1 EQU $F575
VEC_SWI_VECTOR EQU $CBFB
music1 EQU $FD0D
Draw_VL_a EQU $F3DA
Vec_Counter_4 EQU $C831
GET_RISE_IDX EQU $F5D9
DP_to_C8 EQU $F1AF
Random EQU $F517
Vec_Button_1_3 EQU $C814
PRINT_LIST_CHK EQU $F38C
VEC_SWI3_VECTOR EQU $CBF2
Dot_here EQU $F2C5
DRAW_VLP EQU $F410
SOUND_BYTE EQU $F256
RISE_RUN_ANGLE EQU $F593
VEC_JOY_MUX_1_Y EQU $C820
INTENSITY_A EQU $F2AB
DP_TO_C8 EQU $F1AF
DO_SOUND_X EQU $F28C
Xform_Rise EQU $F663
Reset0Int EQU $F36B
VEC_COUNTER_4 EQU $C831
music4 EQU $FDD3
Strip_Zeros EQU $F8B7
MOV_DRAW_VLC_A EQU $F3AD
VEC_EXPL_4 EQU $C85B
Vec_Num_Game EQU $C87A
VEC_BUTTON_1_2 EQU $C813
Xform_Rise_a EQU $F661
Bitmask_a EQU $F57E
Vec_Button_1_2 EQU $C813
Rot_VL EQU $F616
DOT_IX EQU $F2C1
Vec_Button_2_3 EQU $C818
VEC_JOY_1_X EQU $C81B
VEC_MISC_COUNT EQU $C823
Init_VIA EQU $F14C
DIV16.D16_LOOP EQU $4072
DRAW_PAT_VL EQU $F437
VEC_COUNTER_1 EQU $C82E
MUSIC6 EQU $FE76
RANDOM_3 EQU $F511
ADD_SCORE_A EQU $F85E
Vec_Joy_Resltn EQU $C81A
Delay_RTS EQU $F57D
Vec_SWI3_Vector EQU $CBF2
XFORM_RISE_A EQU $F661
GET_RUN_IDX EQU $F5DB
Dec_3_Counters EQU $F55A
DLW_SEG2_DX_CHECK_NEG EQU $4341
Vec_Text_HW EQU $C82A
VEC_BTN_STATE EQU $C80F
Add_Score_a EQU $F85E
VEC_EXPL_CHAN EQU $C85C
VEC_FIRQ_VECTOR EQU $CBF5
VEC_RISERUN_TMP EQU $C834
VEC_BRIGHTNESS EQU $C827
CLEAR_SCORE EQU $F84F
Get_Rise_Idx EQU $F5D9
MUSICC EQU $FF7A
Vec_RiseRun_Tmp EQU $C834
DLW_SEG2_DY_POS EQU $432A
VEC_BUTTON_1_1 EQU $C812
MOV_DRAW_VL_D EQU $F3BE
Delay_0 EQU $F579
Wait_Recal EQU $F192
ROT_VL_AB EQU $F610
Print_Str_yx EQU $F378
Vec_Pattern EQU $C829
VEC_JOY_2_Y EQU $C81E
DLW_SEG2_DX_DONE EQU $4352
MUSIC1 EQU $FD0D
Vec_Max_Players EQU $C84F
Clear_x_b_a EQU $F552
music7 EQU $FEC6
ROT_VL EQU $F616
DEC_COUNTERS EQU $F563
Do_Sound_x EQU $F28C
Joy_Analog EQU $F1F5
Print_Str EQU $F495
Rise_Run_X EQU $F5FF
Vec_Dot_Dwell EQU $C828
Vec_Counter_3 EQU $C830
VEC_JOY_MUX EQU $C81F
Vec_0Ref_Enable EQU $C824
INIT_OS_RAM EQU $F164
RESET0REF EQU $F354
DRAW_VLP_B EQU $F40E
CHECK0REF EQU $F34F
Moveto_ix_a EQU $F30E
DP_TO_D0 EQU $F1AA
VEC_DURATION EQU $C857
Vec_Rise_Index EQU $C839
music2 EQU $FD1D
Rise_Run_Angle EQU $F593
VEC_MAX_GAMES EQU $C850
INIT_MUSIC EQU $F68D
XFORM_RUN EQU $F65D
VEC_NMI_VECTOR EQU $CBFB
musica EQU $FF44
VEC_JOY_MUX_1_X EQU $C81F
CLEAR_C8_RAM EQU $F542
MOV_DRAW_VL_B EQU $F3B1
MUSIC9 EQU $FF26
Draw_VLp_b EQU $F40E
VEC_JOY_MUX_2_X EQU $C821
ABS_A_B EQU $F584
Moveto_ix_7F EQU $F30C
DCR_INTENSITY_5F EQU $414E
Vec_NMI_Vector EQU $CBFB
INIT_MUSIC_CHK EQU $F687
Vec_Button_2_2 EQU $C817
VEC_DEFAULT_STK EQU $CBEA
DRAW_VL_MODE EQU $F46E
BITMASK_A EQU $F57E
RESET0REF_D0 EQU $F34A
Vec_ADSR_Timers EQU $C85E
Reset0Ref EQU $F354
XFORM_RUN_A EQU $F65B
Init_Music_Buf EQU $F533
Vec_Run_Index EQU $C837
VEC_SWI2_VECTOR EQU $CBF2
Intensity_1F EQU $F29D
Explosion_Snd EQU $F92E
PRINT_TEXT_STR_2194200014 EQU $4366
Delay_2 EQU $F571
Vec_Button_2_4 EQU $C819
ROT_VL_MODE EQU $F62B
INTENSITY_5F EQU $F2A5
J2Y_BUILTIN EQU $4104
Vec_SWI2_Vector EQU $CBF2
DIV16 EQU $4030
DRAW_VLCS EQU $F3D6
VEC_SEED_PTR EQU $C87B
Vec_Music_Twang EQU $C858
Mov_Draw_VL_b EQU $F3B1
Vec_Snd_Shadow EQU $C800
Clear_x_b EQU $F53F
Draw_VLcs EQU $F3D6
music5 EQU $FE38
VEC_ADSR_TIMERS EQU $C85E
PRINT_STR_D EQU $F37A
VEC_HIGH_SCORE EQU $CBEB
Vec_Expl_Chans EQU $C854
VEC_MUSIC_WK_7 EQU $C845
Init_OS_RAM EQU $F164
Vec_Prev_Btns EQU $C810
Intensity_5F EQU $F2A5
DLW_SEG1_DX_READY EQU $42D3
Sound_Byte_x EQU $F259
MOVETO_IX EQU $F310
DEC_6_COUNTERS EQU $F55E
Vec_Music_Flag EQU $C856
Intensity_7F EQU $F2A9
Dot_List EQU $F2D5
Vec_Counter_5 EQU $C832
VEC_PATTERN EQU $C829
VEC_EXPL_CHANB EQU $C85D
MOV_DRAW_VL EQU $F3BC
Vec_Joy_2_X EQU $C81D
Reset_Pen EQU $F35B
Vec_Music_Freq EQU $C861
Vec_Music_Work EQU $C83F
Print_List_hw EQU $F385
Obj_Will_Hit_u EQU $F8E5
Draw_VL_mode EQU $F46E
DIV16.D16_RPOS EQU $406C
VEC_TEXT_HEIGHT EQU $C82A
Select_Game EQU $F7A9
JOY_DIGITAL EQU $F1F8
Print_Str_hwyx EQU $F373
Draw_VL_ab EQU $F3D8
DOT_IX_B EQU $F2BE
Draw_Pat_VL_d EQU $F439
VEC_MUSIC_WK_1 EQU $C84B
Print_Ships_x EQU $F391
INIT_MUSIC_X EQU $F692
DO_SOUND EQU $F289
Vec_Seed_Ptr EQU $C87B
COLD_START EQU $F000
DLW_SEG2_DX_NO_REMAIN EQU $434F
Do_Sound EQU $F289
MOD16.M16_DONE EQU $40EE
DRAW_VLC EQU $F3CE
DIV16.D16_DONE EQU $409A
DRAW_VL_A EQU $F3DA
WARM_START EQU $F06C
Vec_Music_Wk_A EQU $C842
Mov_Draw_VL_a EQU $F3B9
Vec_Default_Stk EQU $CBEA
VEC_EXPL_TIMER EQU $C877
OBJ_WILL_HIT_U EQU $F8E5
MOVETO_X_7F EQU $F2F2
MUSIC8 EQU $FEF8
Vec_Music_Chan EQU $C855
DIV16.D16_DPOS EQU $404D
Vec_Text_Height EQU $C82A
SET_REFRESH EQU $F1A2


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "JOY2"
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
VAR_JX               EQU $C880+$31   ; User variable: jx (2 bytes)
VAR_JY               EQU $C880+$33   ; User variable: jy (2 bytes)
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
    STD VAR_JX
    LDD #0
    STD VAR_JY
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
    STD VAR_JX
    LDD #0
    STD VAR_JY

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
    LDX #PRINT_TEXT_STR_2194200014      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    JSR J2X_BUILTIN
    STD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #2
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR DIV16       ; D = X / D
    STD VAR_JX
    JSR J2Y_BUILTIN
    STD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #2
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR DIV16       ; D = X / D
    STD VAR_JY
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_JX
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #8
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_JY
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_JX
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #8
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_JY
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #80
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_JX
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_JY
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #8
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_JX
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_JY
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #8
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #80
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    LDA $C812      ; Vec_Button_1_2 (Player 2 transition bits)
    ANDA #$01      ; Test bit 0
    LBEQ .J2B1_0_OFF
    LDD #1
    LBRA .J2B1_0_END
.J2B1_0_OFF:
    LDD #0
.J2B1_0_END:
    STD RESULT
    LBEQ IF_NEXT_1
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$64
    JSR Intensity_a
    LDA #$C4
    LDB #$D6
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$1E
    JSR Intensity_a
    LDA #$C4
    LDB #$D6
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LDA $C812      ; Vec_Button_1_2 (Player 2 transition bits)
    ANDA #$02      ; Test bit 1
    LBEQ .J2B2_1_OFF
    LDD #1
    LBRA .J2B2_1_END
.J2B2_1_OFF:
    LDD #0
.J2B2_1_END:
    STD RESULT
    LBEQ IF_NEXT_3
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$64
    JSR Intensity_a
    LDA #$C4
    LDB #$F4
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$1E
    JSR Intensity_a
    LDA #$C4
    LDB #$F4
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LDA $C812      ; Vec_Button_1_2 (Player 2 transition bits)
    ANDA #$04      ; Test bit 2
    LBEQ .J2B3_2_OFF
    LDD #1
    LBRA .J2B3_2_END
.J2B3_2_OFF:
    LDD #0
.J2B3_2_END:
    STD RESULT
    LBEQ IF_NEXT_5
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$64
    JSR Intensity_a
    LDA #$C4
    LDB #$12
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$1E
    JSR Intensity_a
    LDA #$C4
    LDB #$12
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LDA $C812      ; Vec_Button_1_2 (Player 2 transition bits)
    ANDA #$08      ; Test bit 3
    LBEQ .J2B4_3_OFF
    LDD #1
    LBRA .J2B4_3_END
.J2B4_3_OFF:
    LDD #0
.J2B4_3_END:
    STD RESULT
    LBEQ IF_NEXT_7
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$64
    JSR Intensity_a
    LDA #$C4
    LDB #$30
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$1E
    JSR Intensity_a
    LDA #$C4
    LDB #$30
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-52
    STD VAR_ARG0
    LDD #-75
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_44450992618      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    RTS


; ================================================
