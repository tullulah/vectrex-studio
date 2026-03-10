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
DRAW_LINE_ARGS       EQU $C880+$0E   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$18   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$1A   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$1C   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$1D   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$1E   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$20   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
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
Clear_x_256 EQU $F545
Vec_Expl_2 EQU $C859
Vec_Rfrsh EQU $C83D
Draw_Pat_VL_a EQU $F434
Vec_Music_Twang EQU $C858
VEC_BUTTONS EQU $C811
ROT_VL_MODE EQU $F62B
DELAY_0 EQU $F579
Warm_Start EQU $F06C
Draw_VL_a EQU $F3DA
VEC_0REF_ENABLE EQU $C824
DRAW_VLCS EQU $F3D6
NEW_HIGH_SCORE EQU $F8D8
Vec_Angle EQU $C836
XFORM_RISE_A EQU $F661
musica EQU $FF44
VEC_HIGH_SCORE EQU $CBEB
Vec_Misc_Count EQU $C823
Draw_VLp_FF EQU $F404
Print_Str EQU $F495
Vec_Prev_Btns EQU $C810
PRINT_STR_HWYX EQU $F373
Vec_0Ref_Enable EQU $C824
Print_Str_d EQU $F37A
Sound_Byte_x EQU $F259
Draw_Pat_VL_d EQU $F439
XFORM_RUN EQU $F65D
RISE_RUN_ANGLE EQU $F593
VEC_RANDOM_SEED EQU $C87D
Move_Mem_a EQU $F683
Check0Ref EQU $F34F
VEC_BUTTON_2_3 EQU $C818
Vec_Music_Chan EQU $C855
MUSIC7 EQU $FEC6
Moveto_d_7F EQU $F2FC
VEC_SWI2_VECTOR EQU $CBF2
DP_TO_D0 EQU $F1AA
VEC_COUNTER_1 EQU $C82E
Vec_Loop_Count EQU $C825
GET_RISE_IDX EQU $F5D9
VEC_COLD_FLAG EQU $CBFE
Vec_Joy_1_X EQU $C81B
Vec_Run_Index EQU $C837
Clear_x_d EQU $F548
CLEAR_X_256 EQU $F545
DLW_SEG1_DX_NO_CLAMP EQU $40C6
PRINT_SHIPS_X EQU $F391
Reset0Ref_D0 EQU $F34A
Do_Sound EQU $F289
VEC_MUSIC_CHAN EQU $C855
RESET0REF_D0 EQU $F34A
VEC_EXPL_CHAN EQU $C85C
Vec_Counters EQU $C82E
INTENSITY_7F EQU $F2A9
VEC_DOT_DWELL EQU $C828
VEC_MUSIC_WORK EQU $C83F
VEC_EXPL_2 EQU $C859
MUSICA EQU $FF44
DO_SOUND EQU $F289
DRAW_VL_MODE EQU $F46E
MUSIC8 EQU $FEF8
DRAW_VLP_FF EQU $F404
DP_to_C8 EQU $F1AF
DLW_SEG2_DX_DONE EQU $4148
Rot_VL_ab EQU $F610
VEC_ANGLE EQU $C836
PRINT_LIST EQU $F38A
MOVETO_IX_A EQU $F30E
RANDOM EQU $F517
DO_SOUND_X EQU $F28C
Strip_Zeros EQU $F8B7
Vec_Rfrsh_hi EQU $C83E
Mov_Draw_VL_a EQU $F3B9
Draw_VL_ab EQU $F3D8
Clear_Score EQU $F84F
VEC_NUM_PLAYERS EQU $C879
Intensity_5F EQU $F2A5
Moveto_ix_FF EQU $F308
DELAY_B EQU $F57A
Abs_b EQU $F58B
MOD16.M16_DPOS EQU $401D
Dot_here EQU $F2C5
Vec_Music_Wk_7 EQU $C845
VEC_TEXT_HW EQU $C82A
Vec_Joy_Mux_2_X EQU $C821
Mov_Draw_VL_b EQU $F3B1
Intensity_3F EQU $F2A1
VEC_TEXT_WIDTH EQU $C82B
Moveto_d EQU $F312
MOD16.M16_RPOS EQU $4034
VEC_SWI_VECTOR EQU $CBFB
READ_BTNS EQU $F1BA
DLW_SEG1_DY_NO_CLAMP EQU $40A3
PRINT_LIST_CHK EQU $F38C
Vec_Music_Freq EQU $C861
WAIT_RECAL EQU $F192
PRINT_SHIPS EQU $F393
Delay_1 EQU $F575
Vec_Expl_3 EQU $C85A
Delay_0 EQU $F579
VEC_ADSR_TIMERS EQU $C85E
VEC_MUSIC_WK_6 EQU $C846
Vec_Counter_2 EQU $C82F
Vec_Button_1_1 EQU $C812
DRAW_VLP EQU $F410
PRINT_LIST_HW EQU $F385
VEC_BUTTON_1_2 EQU $C813
MOV_DRAW_VL_B EQU $F3B1
Add_Score_a EQU $F85E
VEC_SEED_PTR EQU $C87B
READ_BTNS_MASK EQU $F1B4
Vec_Max_Players EQU $C84F
DEC_3_COUNTERS EQU $F55A
DOT_IX EQU $F2C1
Moveto_ix_a EQU $F30E
Read_Btns_Mask EQU $F1B4
VEC_RUN_INDEX EQU $C837
DRAW_PAT_VL_A EQU $F434
Vec_Counter_3 EQU $C830
DRAW_LINE_WRAPPER EQU $4054
Vec_Joy_Mux_2_Y EQU $C822
ADD_SCORE_A EQU $F85E
VEC_JOY_RESLTN EQU $C81A
VEC_SWI3_VECTOR EQU $CBF2
Init_Music EQU $F68D
BITMASK_A EQU $F57E
Delay_2 EQU $F571
Get_Run_Idx EQU $F5DB
INIT_VIA EQU $F14C
Vec_Text_Width EQU $C82B
SELECT_GAME EQU $F7A9
Draw_VLp EQU $F410
Xform_Rise_a EQU $F661
XFORM_RISE EQU $F663
music9 EQU $FF26
Read_Btns EQU $F1BA
DLW_NEED_SEG2 EQU $4101
MUSIC5 EQU $FE38
Do_Sound_x EQU $F28C
Sound_Bytes_x EQU $F284
Draw_VLp_scale EQU $F40C
INTENSITY_1F EQU $F29D
MUSIC1 EQU $FD0D
Rot_VL_dft EQU $F637
Vec_Text_Height EQU $C82A
GET_RISE_RUN EQU $F5EF
VEC_RISERUN_LEN EQU $C83B
Draw_VLcs EQU $F3D6
RESET_PEN EQU $F35B
VEC_MUSIC_PTR EQU $C853
Vec_Max_Games EQU $C850
VEC_JOY_MUX_2_Y EQU $C822
OBJ_WILL_HIT_U EQU $F8E5
Vec_SWI3_Vector EQU $CBF2
DELAY_1 EQU $F575
DOT_LIST_RESET EQU $F2DE
Vec_Pattern EQU $C829
Vec_ADSR_Timers EQU $C85E
Init_OS_RAM EQU $F164
Init_OS EQU $F18B
Rot_VL_Mode EQU $F62B
Clear_C8_RAM EQU $F542
DLW_DONE EQU $4157
VEC_BUTTON_2_1 EQU $C816
VEC_RFRSH EQU $C83D
CLEAR_X_B EQU $F53F
Vec_Music_Wk_6 EQU $C846
Joy_Digital EQU $F1F8
Vec_Expl_ChanA EQU $C853
Random_3 EQU $F511
MOVE_MEM_A EQU $F683
Clear_x_b_80 EQU $F550
PRINT_STR_YX EQU $F378
Print_Str_hwyx EQU $F373
VEC_EXPL_CHANA EQU $C853
Vec_Button_2_3 EQU $C818
DP_to_D0 EQU $F1AA
VEC_BUTTON_1_1 EQU $C812
VEC_EXPL_CHANS EQU $C854
CLEAR_SCORE EQU $F84F
MUSIC4 EQU $FDD3
VEC_EXPL_CHANB EQU $C85D
STRIP_ZEROS EQU $F8B7
Vec_Rise_Index EQU $C839
MUSIC9 EQU $FF26
Random EQU $F517
MOV_DRAW_VLCS EQU $F3B5
INIT_MUSIC_BUF EQU $F533
VEC_MUSIC_WK_A EQU $C842
Print_List_hw EQU $F385
VEC_JOY_MUX_1_Y EQU $C820
VEC_JOY_1_Y EQU $C81C
DOT_D EQU $F2C3
MOD16.M16_LOOP EQU $4034
VEC_JOY_MUX_1_X EQU $C81F
DLW_SEG2_DY_POS EQU $4120
Dot_List_Reset EQU $F2DE
VEC_PREV_BTNS EQU $C810
VEC_JOY_MUX EQU $C81F
musicd EQU $FF8F
Vec_Joy_Mux_1_Y EQU $C820
Vec_Seed_Ptr EQU $C87B
Select_Game EQU $F7A9
Draw_VLc EQU $F3CE
Vec_Joy_2_X EQU $C81D
Clear_Sound EQU $F272
DRAW_VL_A EQU $F3DA
VEC_BRIGHTNESS EQU $C827
Obj_Hit EQU $F8FF
DRAW_VL EQU $F3DD
RISE_RUN_X EQU $F5FF
Vec_Counter_6 EQU $C833
DRAW_VL_B EQU $F3D2
Vec_Text_HW EQU $C82A
MUSIC2 EQU $FD1D
DOT_IX_B EQU $F2BE
music8 EQU $FEF8
MOV_DRAW_VL_AB EQU $F3B7
MUSIC3 EQU $FD81
DRAW_VLP_B EQU $F40E
Moveto_ix_7F EQU $F30C
Intensity_a EQU $F2AB
VEC_ADSR_TABLE EQU $C84F
ROT_VL_DFT EQU $F637
DELAY_3 EQU $F56D
WARM_START EQU $F06C
music5 EQU $FE38
Draw_Grid_VL EQU $FF9F
Vec_Joy_Mux_1_X EQU $C81F
MOD16.M16_END EQU $4044
VEC_FREQ_TABLE EQU $C84D
VEC_LOOP_COUNT EQU $C825
RISE_RUN_Y EQU $F601
DLW_SEG1_DX_LO EQU $40B9
DP_TO_C8 EQU $F1AF
DRAW_LINE_D EQU $F3DF
MUSICC EQU $FF7A
Init_Music_Buf EQU $F533
VEC_TEXT_HEIGHT EQU $C82A
Vec_Button_1_2 EQU $C813
MOVE_MEM_A_1 EQU $F67F
Vec_Expl_Flag EQU $C867
MUSICB EQU $FF62
VEC_RFRSH_HI EQU $C83E
DRAW_VLC EQU $F3CE
VEC_MAX_GAMES EQU $C850
MOVETO_D_7F EQU $F2FC
Vec_Expl_Chans EQU $C854
Vec_Duration EQU $C857
VEC_BUTTON_1_4 EQU $C815
Print_List_chk EQU $F38C
Draw_VLp_7F EQU $F408
VEC_STR_PTR EQU $C82C
INIT_MUSIC EQU $F68D
ROT_VL EQU $F616
musicc EQU $FF7A
Obj_Will_Hit EQU $F8F3
Reset_Pen EQU $F35B
VEC_DEFAULT_STK EQU $CBEA
Get_Rise_Run EQU $F5EF
Draw_VL EQU $F3DD
VEC_BUTTON_1_3 EQU $C814
Vec_Buttons EQU $C811
music3 EQU $FD81
Explosion_Snd EQU $F92E
XFORM_RUN_A EQU $F65B
DELAY_2 EQU $F571
INIT_OS EQU $F18B
VEC_COUNTERS EQU $C82E
Vec_Joy_Mux EQU $C81F
MOD16.M16_RCHECK EQU $4025
Vec_Button_2_2 EQU $C817
JOY_DIGITAL EQU $F1F8
Intensity_7F EQU $F2A9
VEC_PATTERN EQU $C829
Rise_Run_X EQU $F5FF
RECALIBRATE EQU $F2E6
Cold_Start EQU $F000
VEC_BUTTON_2_2 EQU $C817
INTENSITY_3F EQU $F2A1
Vec_Rfrsh_lo EQU $C83D
Mov_Draw_VL EQU $F3BC
Mov_Draw_VL_d EQU $F3BE
Print_List EQU $F38A
Vec_Expl_Chan EQU $C85C
Draw_Line_d EQU $F3DF
SOUND_BYTE_RAW EQU $F25B
music2 EQU $FD1D
VEC_COUNTER_3 EQU $C830
Vec_Expl_1 EQU $C858
Init_Music_x EQU $F692
RESET0REF EQU $F354
DLW_SEG1_DY_LO EQU $4096
Delay_b EQU $F57A
VEC_MUSIC_TWANG EQU $C858
VEC_EXPL_TIMER EQU $C877
Draw_VL_mode EQU $F46E
Joy_Analog EQU $F1F5
VEC_MUSIC_WK_5 EQU $C847
Rise_Run_Angle EQU $F593
Vec_FIRQ_Vector EQU $CBF5
RISE_RUN_LEN EQU $F603
Xform_Run_a EQU $F65B
COLD_START EQU $F000
VEC_COUNTER_4 EQU $C831
Recalibrate EQU $F2E6
DEC_COUNTERS EQU $F563
Vec_SWI2_Vector EQU $CBF2
New_High_Score EQU $F8D8
VEC_EXPL_1 EQU $C858
VEC_TWANG_TABLE EQU $C851
Move_Mem_a_1 EQU $F67F
INIT_MUSIC_CHK EQU $F687
Xform_Rise EQU $F663
Vec_Music_Wk_1 EQU $C84B
MOV_DRAW_VLC_A EQU $F3AD
Vec_RiseRun_Tmp EQU $C834
Get_Rise_Idx EQU $F5D9
EXPLOSION_SND EQU $F92E
Xform_Run EQU $F65D
DLW_SEG2_DX_NO_REMAIN EQU $4145
Init_Music_chk EQU $F687
Set_Refresh EQU $F1A2
Vec_Btn_State EQU $C80F
VEC_MISC_COUNT EQU $C823
Reset0Ref EQU $F354
DRAW_PAT_VL EQU $F437
Sound_Bytes EQU $F27D
Vec_Button_2_1 EQU $C816
ABS_B EQU $F58B
Vec_Music_Ptr EQU $C853
music6 EQU $FE76
Vec_Music_Work EQU $C83F
Clear_x_b_a EQU $F552
VEC_COUNTER_5 EQU $C832
CLEAR_X_B_80 EQU $F550
Dot_List EQU $F2D5
MOVETO_D EQU $F312
Vec_Counter_4 EQU $C831
DELAY_RTS EQU $F57D
Print_Str_yx EQU $F378
VEC_JOY_2_X EQU $C81D
VEC_BTN_STATE EQU $C80F
SOUND_BYTE EQU $F256
VEC_JOY_1_X EQU $C81B
Rise_Run_Len EQU $F603
VEC_FIRQ_VECTOR EQU $CBF5
ABS_A_B EQU $F584
Vec_Dot_Dwell EQU $C828
MUSICD EQU $FF8F
Wait_Recal EQU $F192
Vec_Joy_1_Y EQU $C81C
RANDOM_3 EQU $F511
Vec_Music_Flag EQU $C856
CHECK0REF EQU $F34F
COMPARE_SCORE EQU $F8C7
Vec_Default_Stk EQU $CBEA
musicb EQU $FF62
Mov_Draw_VLc_a EQU $F3AD
JOY_ANALOG EQU $F1F5
DRAW_GRID_VL EQU $FF9F
Add_Score_d EQU $F87C
Vec_Num_Game EQU $C87A
VEC_EXPL_4 EQU $C85B
VEC_JOY_MUX_2_X EQU $C821
INTENSITY_5F EQU $F2A5
Moveto_x_7F EQU $F2F2
Print_Ships_x EQU $F391
music1 EQU $FD0D
VEC_RISERUN_TMP EQU $C834
Delay_RTS EQU $F57D
VEC_DURATION EQU $C857
Draw_Pat_VL EQU $F437
Vec_Num_Players EQU $C879
DOT_LIST EQU $F2D5
Obj_Will_Hit_u EQU $F8E5
Rot_VL EQU $F616
Bitmask_a EQU $F57E
VEC_COUNTER_2 EQU $C82F
Mov_Draw_VL_ab EQU $F3B7
Rot_VL_Mode_a EQU $F61F
MOV_DRAW_VL_A EQU $F3B9
Vec_Expl_Timer EQU $C877
Vec_SWI_Vector EQU $CBFB
PRINT_STR EQU $F495
INIT_OS_RAM EQU $F164
SET_REFRESH EQU $F1A2
Vec_High_Score EQU $CBEB
VEC_BUTTON_2_4 EQU $C819
Dec_3_Counters EQU $F55A
GET_RUN_IDX EQU $F5DB
Moveto_ix EQU $F310
Sound_Byte_raw EQU $F25B
VEC_RFRSH_LO EQU $C83D
OBJ_HIT EQU $F8FF
music7 EQU $FEC6
VEC_IRQ_VECTOR EQU $CBF8
INTENSITY_A EQU $F2AB
VEC_MUSIC_WK_1 EQU $C84B
MOVETO_IX_FF EQU $F308
Vec_Freq_Table EQU $C84D
Vec_Joy_Resltn EQU $C81A
Vec_ADSR_Table EQU $C84F
Intensity_1F EQU $F29D
CLEAR_X_B_A EQU $F552
Vec_Joy_2_Y EQU $C81E
Dot_ix EQU $F2C1
SOUND_BYTE_X EQU $F259
Vec_Random_Seed EQU $C87D
DRAW_VL_AB EQU $F3D8
VEC_MUSIC_WK_7 EQU $C845
Dec_Counters EQU $F563
Sound_Byte EQU $F256
Dec_6_Counters EQU $F55E
Vec_Music_Wk_A EQU $C842
ROT_VL_AB EQU $F610
music4 EQU $FDD3
MUSIC6 EQU $FE76
MOV_DRAW_VL EQU $F3BC
Vec_Button_1_4 EQU $C815
Vec_Button_1_3 EQU $C814
Dot_ix_b EQU $F2BE
RESET0INT EQU $F36B
MOVETO_IX EQU $F310
ADD_SCORE_D EQU $F87C
SOUND_BYTES EQU $F27D
Draw_VLp_b EQU $F40E
Vec_NMI_Vector EQU $CBFB
MOD16 EQU $4000
Delay_3 EQU $F56D
DLW_SEG1_DY_READY EQU $40A6
Rise_Run_Y EQU $F601
Compare_Score EQU $F8C7
CLEAR_C8_RAM EQU $F542
DRAW_VLP_7F EQU $F408
Mov_Draw_VLcs EQU $F3B5
Vec_Expl_ChanB EQU $C85D
Vec_Str_Ptr EQU $C82C
DLW_SEG1_DX_READY EQU $40C9
VEC_NMI_VECTOR EQU $CBFB
VEC_MAX_PLAYERS EQU $C84F
VEC_NUM_GAME EQU $C87A
Vec_Button_2_4 EQU $C819
Dot_d EQU $F2C3
DEC_6_COUNTERS EQU $F55E
MOV_DRAW_VL_D EQU $F3BE
SOUND_BYTES_X EQU $F284
Vec_Counter_1 EQU $C82E
DLW_SEG2_DY_DONE EQU $4123
VEC_MUSIC_FLAG EQU $C856
VEC_JOY_2_Y EQU $C81E
OBJ_WILL_HIT EQU $F8F3
Vec_RiseRun_Len EQU $C83B
DRAW_PAT_VL_D EQU $F439
MOD16.M16_DONE EQU $4053
Vec_Brightness EQU $C827
DRAW_VLP_SCALE EQU $F40C
Vec_Twang_Table EQU $C851
DOT_HERE EQU $F2C5
Abs_a_b EQU $F584
Vec_Cold_Flag EQU $CBFE
VEC_EXPL_3 EQU $C85A
PRINT_STR_D EQU $F37A
MOVETO_X_7F EQU $F2F2
MOVETO_IX_7F EQU $F30C
Vec_Counter_5 EQU $C832
Print_Ships EQU $F393
VEC_SND_SHADOW EQU $C800
Draw_VL_b EQU $F3D2
Vec_Expl_4 EQU $C85B
Vec_IRQ_Vector EQU $CBF8
VEC_COUNTER_6 EQU $C833
CLEAR_SOUND EQU $F272
INIT_MUSIC_X EQU $F692
CLEAR_X_D EQU $F548
DLW_SEG2_DY_NO_REMAIN EQU $411A
VEC_MUSIC_FREQ EQU $C861
Clear_x_b EQU $F53F
Vec_Snd_Shadow EQU $C800
Vec_Music_Wk_5 EQU $C847
Init_VIA EQU $F14C
DLW_SEG2_DX_CHECK_NEG EQU $4137
Reset0Int EQU $F36B
ROT_VL_MODE_A EQU $F61F
VEC_EXPL_FLAG EQU $C867
VEC_RISE_INDEX EQU $C839


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "DRAW_MOVE"
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
DRAW_LINE_ARGS       EQU $C880+$0E   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$18   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$1A   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$1C   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$1D   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$1E   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$20   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
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
    ; ===== MOVE builtin =====
    LDA #$C4                ; X coordinate
    STA VPY_MOVE_X
    LDA #$3C                ; Y coordinate
    STA VPY_MOVE_Y
    LDD #0
    STD RESULT
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #0
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #0
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #40
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #-40
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #80
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    ; ===== MOVE builtin =====
    LDA #$3C                ; X coordinate
    STA VPY_MOVE_X
    LDA #$3C                ; Y coordinate
    STA VPY_MOVE_Y
    LDD #0
    STD RESULT
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #0
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #0
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #-40
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #-40
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #80
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    ; ===== MOVE builtin =====
    LDA #$00                ; X coordinate
    STA VPY_MOVE_X
    LDA #$00                ; Y coordinate
    STA VPY_MOVE_Y
    LDD #0
    STD RESULT
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #-30
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #0
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #30
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #0
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #80
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    RTS


; ================================================
