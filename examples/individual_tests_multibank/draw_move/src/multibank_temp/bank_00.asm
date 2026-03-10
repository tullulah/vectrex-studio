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
VEC_0REF_ENABLE EQU $C824
COLD_START EQU $F000
Init_Music_Buf EQU $F533
VEC_COUNTER_5 EQU $C832
Vec_Joy_Mux_1_X EQU $C81F
GET_RISE_IDX EQU $F5D9
DEC_6_COUNTERS EQU $F55E
Vec_Snd_Shadow EQU $C800
Moveto_d_7F EQU $F2FC
Draw_VLp_7F EQU $F408
STRIP_ZEROS EQU $F8B7
VEC_MUSIC_WK_7 EQU $C845
DO_SOUND_X EQU $F28C
VEC_RUN_INDEX EQU $C837
ROT_VL_MODE_A EQU $F61F
CLEAR_X_256 EQU $F545
CLEAR_X_B_80 EQU $F550
Delay_1 EQU $F575
INIT_MUSIC EQU $F68D
CHECK0REF EQU $F34F
DLW_SEG2_DY_DONE EQU $4123
Vec_ADSR_Table EQU $C84F
VEC_STR_PTR EQU $C82C
VEC_EXPL_CHANS EQU $C854
Dot_List EQU $F2D5
INIT_MUSIC_X EQU $F692
RISE_RUN_ANGLE EQU $F593
VEC_RISERUN_TMP EQU $C834
Vec_Expl_ChanB EQU $C85D
Vec_Counter_6 EQU $C833
Vec_Angle EQU $C836
Rise_Run_Len EQU $F603
XFORM_RISE EQU $F663
DRAW_VLC EQU $F3CE
Vec_Text_Width EQU $C82B
VEC_DOT_DWELL EQU $C828
VEC_RANDOM_SEED EQU $C87D
WARM_START EQU $F06C
Abs_b EQU $F58B
MOVETO_IX EQU $F310
Xform_Run EQU $F65D
Sound_Byte_x EQU $F259
DOT_LIST_RESET EQU $F2DE
Dec_Counters EQU $F563
VEC_EXPL_1 EQU $C858
VEC_COLD_FLAG EQU $CBFE
MUSIC9 EQU $FF26
Vec_SWI2_Vector EQU $CBF2
VEC_JOY_MUX_1_X EQU $C81F
MUSIC4 EQU $FDD3
MOD16 EQU $4000
Moveto_d EQU $F312
DRAW_VLCS EQU $F3D6
Sound_Byte_raw EQU $F25B
Rot_VL_Mode_a EQU $F61F
Draw_VL_ab EQU $F3D8
VEC_JOY_MUX EQU $C81F
Vec_Expl_Timer EQU $C877
RESET_PEN EQU $F35B
Get_Rise_Run EQU $F5EF
Vec_Music_Wk_5 EQU $C847
Mov_Draw_VL_b EQU $F3B1
VEC_HIGH_SCORE EQU $CBEB
Moveto_ix_7F EQU $F30C
DOT_LIST EQU $F2D5
OBJ_WILL_HIT EQU $F8F3
Vec_Expl_Flag EQU $C867
XFORM_RUN_A EQU $F65B
OBJ_WILL_HIT_U EQU $F8E5
PRINT_STR_YX EQU $F378
Vec_Button_1_3 EQU $C814
MOVETO_X_7F EQU $F2F2
DOT_IX_B EQU $F2BE
CLEAR_C8_RAM EQU $F542
Print_Str EQU $F495
ABS_B EQU $F58B
Print_Ships EQU $F393
VEC_MUSIC_CHAN EQU $C855
Mov_Draw_VL_a EQU $F3B9
VEC_SWI_VECTOR EQU $CBFB
MUSIC8 EQU $FEF8
VEC_EXPL_CHANA EQU $C853
VEC_JOY_2_X EQU $C81D
DP_to_C8 EQU $F1AF
Vec_Button_1_2 EQU $C813
Vec_Num_Players EQU $C879
New_High_Score EQU $F8D8
INIT_MUSIC_CHK EQU $F687
GET_RUN_IDX EQU $F5DB
DRAW_VL_AB EQU $F3D8
Vec_Dot_Dwell EQU $C828
MOVE_MEM_A EQU $F683
Vec_Counter_5 EQU $C832
Init_Music EQU $F68D
RISE_RUN_Y EQU $F601
Set_Refresh EQU $F1A2
Bitmask_a EQU $F57E
Print_Ships_x EQU $F391
VEC_BUTTON_2_3 EQU $C818
GET_RISE_RUN EQU $F5EF
MUSICC EQU $FF7A
Check0Ref EQU $F34F
OBJ_HIT EQU $F8FF
Intensity_7F EQU $F2A9
XFORM_RISE_A EQU $F661
Reset_Pen EQU $F35B
MOV_DRAW_VL_D EQU $F3BE
Sound_Bytes EQU $F27D
Vec_Rise_Index EQU $C839
PRINT_SHIPS EQU $F393
MUSIC3 EQU $FD81
DO_SOUND EQU $F289
SET_REFRESH EQU $F1A2
MOVETO_IX_7F EQU $F30C
DELAY_B EQU $F57A
Joy_Digital EQU $F1F8
VEC_RFRSH EQU $C83D
DELAY_0 EQU $F579
VEC_COUNTERS EQU $C82E
VEC_MUSIC_PTR EQU $C853
VEC_MUSIC_WK_A EQU $C842
MUSICD EQU $FF8F
Draw_VLp EQU $F410
VEC_MAX_GAMES EQU $C850
Vec_ADSR_Timers EQU $C85E
VEC_IRQ_VECTOR EQU $CBF8
DLW_SEG1_DX_NO_CLAMP EQU $40C6
VEC_EXPL_TIMER EQU $C877
Recalibrate EQU $F2E6
VEC_EXPL_CHANB EQU $C85D
Vec_Random_Seed EQU $C87D
Dot_List_Reset EQU $F2DE
DELAY_2 EQU $F571
music3 EQU $FD81
INTENSITY_7F EQU $F2A9
VEC_MUSIC_WK_1 EQU $C84B
VEC_JOY_MUX_1_Y EQU $C820
Vec_Music_Wk_7 EQU $C845
Vec_Button_1_1 EQU $C812
Vec_Pattern EQU $C829
VEC_SWI3_VECTOR EQU $CBF2
MOD16.M16_END EQU $4044
VEC_SWI2_VECTOR EQU $CBF2
music5 EQU $FE38
Dot_here EQU $F2C5
Vec_Music_Wk_1 EQU $C84B
CLEAR_SOUND EQU $F272
Init_Music_chk EQU $F687
MOV_DRAW_VL_AB EQU $F3B7
Warm_Start EQU $F06C
Vec_Buttons EQU $C811
CLEAR_X_B_A EQU $F552
VEC_SEED_PTR EQU $C87B
DLW_SEG2_DX_NO_REMAIN EQU $4145
Do_Sound_x EQU $F28C
Vec_Default_Stk EQU $CBEA
Obj_Will_Hit_u EQU $F8E5
musica EQU $FF44
DELAY_3 EQU $F56D
Vec_Music_Flag EQU $C856
Vec_0Ref_Enable EQU $C824
INTENSITY_1F EQU $F29D
VEC_RFRSH_LO EQU $C83D
Abs_a_b EQU $F584
DOT_IX EQU $F2C1
VEC_DEFAULT_STK EQU $CBEA
Vec_RiseRun_Tmp EQU $C834
DRAW_VL_A EQU $F3DA
DRAW_VLP_SCALE EQU $F40C
VEC_BUTTONS EQU $C811
PRINT_LIST_HW EQU $F385
Draw_VL EQU $F3DD
Delay_RTS EQU $F57D
MOD16.M16_RPOS EQU $4034
VEC_COUNTER_4 EQU $C831
Read_Btns_Mask EQU $F1B4
Print_Str_d EQU $F37A
DRAW_VL_B EQU $F3D2
Move_Mem_a_1 EQU $F67F
VEC_TEXT_WIDTH EQU $C82B
Vec_Music_Work EQU $C83F
VEC_JOY_1_X EQU $C81B
VEC_EXPL_CHAN EQU $C85C
Clear_C8_RAM EQU $F542
Vec_Expl_ChanA EQU $C853
Vec_Joy_Mux_2_X EQU $C821
Vec_Joy_2_X EQU $C81D
VEC_ADSR_TABLE EQU $C84F
Moveto_x_7F EQU $F2F2
Vec_Cold_Flag EQU $CBFE
Dot_ix_b EQU $F2BE
MUSIC2 EQU $FD1D
Vec_Counters EQU $C82E
Vec_Expl_Chan EQU $C85C
DLW_SEG2_DY_NO_REMAIN EQU $411A
VEC_MUSIC_WK_6 EQU $C846
Vec_Rfrsh_hi EQU $C83E
MUSIC1 EQU $FD0D
VEC_JOY_RESLTN EQU $C81A
Draw_VLp_FF EQU $F404
Vec_SWI3_Vector EQU $CBF2
VEC_JOY_MUX_2_Y EQU $C822
DLW_DONE EQU $4157
Draw_VL_a EQU $F3DA
Vec_Expl_4 EQU $C85B
Vec_Misc_Count EQU $C823
musicc EQU $FF7A
Print_Str_hwyx EQU $F373
Vec_Expl_2 EQU $C859
WAIT_RECAL EQU $F192
Vec_Music_Twang EQU $C858
RANDOM EQU $F517
DRAW_VLP_7F EQU $F408
VEC_TEXT_HEIGHT EQU $C82A
VEC_FREQ_TABLE EQU $C84D
Vec_Counter_2 EQU $C82F
Vec_Duration EQU $C857
PRINT_STR EQU $F495
VEC_COUNTER_6 EQU $C833
Vec_Expl_Chans EQU $C854
RESET0REF_D0 EQU $F34A
Moveto_ix_FF EQU $F308
Dot_d EQU $F2C3
Mov_Draw_VL EQU $F3BC
VEC_MUSIC_TWANG EQU $C858
VEC_COUNTER_1 EQU $C82E
VEC_RISERUN_LEN EQU $C83B
Random_3 EQU $F511
Move_Mem_a EQU $F683
VEC_FIRQ_VECTOR EQU $CBF5
RESET0INT EQU $F36B
VEC_SND_SHADOW EQU $C800
Get_Run_Idx EQU $F5DB
Vec_Loop_Count EQU $C825
Get_Rise_Idx EQU $F5D9
Init_VIA EQU $F14C
Print_List_hw EQU $F385
Vec_Button_2_2 EQU $C817
INIT_MUSIC_BUF EQU $F533
PRINT_STR_D EQU $F37A
DRAW_VLP EQU $F410
PRINT_STR_HWYX EQU $F373
INIT_OS_RAM EQU $F164
DP_to_D0 EQU $F1AA
Draw_Pat_VL_a EQU $F434
Draw_VLcs EQU $F3D6
PRINT_SHIPS_X EQU $F391
Vec_Text_HW EQU $C82A
MOVETO_IX_FF EQU $F308
Vec_Joy_1_Y EQU $C81C
Vec_Num_Game EQU $C87A
MOD16.M16_DONE EQU $4053
VEC_MAX_PLAYERS EQU $C84F
DRAW_PAT_VL EQU $F437
Rot_VL_ab EQU $F610
VEC_BUTTON_1_1 EQU $C812
VEC_TEXT_HW EQU $C82A
Vec_Music_Wk_6 EQU $C846
Mov_Draw_VLcs EQU $F3B5
DLW_SEG1_DY_READY EQU $40A6
Obj_Hit EQU $F8FF
ABS_A_B EQU $F584
Vec_Str_Ptr EQU $C82C
DLW_NEED_SEG2 EQU $4101
Joy_Analog EQU $F1F5
MOVETO_D EQU $F312
INTENSITY_5F EQU $F2A5
Vec_Seed_Ptr EQU $C87B
VEC_COUNTER_3 EQU $C830
Vec_Button_2_1 EQU $C816
DLW_SEG2_DX_DONE EQU $4148
DEC_3_COUNTERS EQU $F55A
Draw_Pat_VL EQU $F437
Vec_Expl_1 EQU $C858
Vec_Counter_3 EQU $C830
DLW_SEG2_DX_CHECK_NEG EQU $4137
Rot_VL_Mode EQU $F62B
MOVETO_D_7F EQU $F2FC
MOV_DRAW_VL_B EQU $F3B1
Init_Music_x EQU $F692
Draw_Grid_VL EQU $FF9F
VEC_BUTTON_2_1 EQU $C816
MUSICB EQU $FF62
Init_OS EQU $F18B
VEC_LOOP_COUNT EQU $C825
DLW_SEG2_DY_POS EQU $4120
JOY_ANALOG EQU $F1F5
Delay_3 EQU $F56D
MUSICA EQU $FF44
MOV_DRAW_VL EQU $F3BC
SELECT_GAME EQU $F7A9
Vec_NMI_Vector EQU $CBFB
RISE_RUN_LEN EQU $F603
Clear_x_b EQU $F53F
Vec_Music_Ptr EQU $C853
music1 EQU $FD0D
DEC_COUNTERS EQU $F563
Vec_Joy_1_X EQU $C81B
VEC_BRIGHTNESS EQU $C827
Delay_0 EQU $F579
CLEAR_X_B EQU $F53F
Compare_Score EQU $F8C7
VEC_JOY_2_Y EQU $C81E
DRAW_VL_MODE EQU $F46E
Mov_Draw_VL_d EQU $F3BE
Vec_Joy_2_Y EQU $C81E
Vec_IRQ_Vector EQU $CBF8
INTENSITY_3F EQU $F2A1
DRAW_LINE_WRAPPER EQU $4054
NEW_HIGH_SCORE EQU $F8D8
Vec_Music_Freq EQU $C861
VEC_BUTTON_2_4 EQU $C819
DRAW_VLP_FF EQU $F404
music4 EQU $FDD3
VEC_EXPL_FLAG EQU $C867
Obj_Will_Hit EQU $F8F3
Wait_Recal EQU $F192
ROT_VL EQU $F616
Rise_Run_X EQU $F5FF
Vec_Twang_Table EQU $C851
Vec_High_Score EQU $CBEB
INIT_OS EQU $F18B
MOD16.M16_RCHECK EQU $4025
VEC_ADSR_TIMERS EQU $C85E
Vec_Expl_3 EQU $C85A
Vec_Joy_Mux EQU $C81F
Vec_Btn_State EQU $C80F
Select_Game EQU $F7A9
ROT_VL_MODE EQU $F62B
Vec_Joy_Mux_2_Y EQU $C822
Clear_Sound EQU $F272
music7 EQU $FEC6
VEC_PREV_BTNS EQU $C810
Vec_Music_Chan EQU $C855
Vec_Rfrsh_lo EQU $C83D
VEC_BUTTON_2_2 EQU $C817
Draw_VL_mode EQU $F46E
Xform_Run_a EQU $F65B
Print_List_chk EQU $F38C
Vec_RiseRun_Len EQU $C83B
Mov_Draw_VLc_a EQU $F3AD
Vec_Run_Index EQU $C837
Add_Score_d EQU $F87C
Sound_Bytes_x EQU $F284
Reset0Ref_D0 EQU $F34A
Draw_VLp_b EQU $F40E
Init_OS_RAM EQU $F164
MOVETO_IX_A EQU $F30E
XFORM_RUN EQU $F65D
SOUND_BYTES_X EQU $F284
Vec_Rfrsh EQU $C83D
ADD_SCORE_D EQU $F87C
VEC_RISE_INDEX EQU $C839
Moveto_ix_a EQU $F30E
Vec_FIRQ_Vector EQU $CBF5
RANDOM_3 EQU $F511
VEC_BTN_STATE EQU $C80F
Rot_VL EQU $F616
DP_TO_D0 EQU $F1AA
VEC_RFRSH_HI EQU $C83E
DLW_SEG1_DY_NO_CLAMP EQU $40A3
Delay_2 EQU $F571
VEC_TWANG_TABLE EQU $C851
VEC_MUSIC_WK_5 EQU $C847
READ_BTNS EQU $F1BA
DOT_D EQU $F2C3
Clear_x_b_a EQU $F552
Vec_Prev_Btns EQU $C810
MOD16.M16_DPOS EQU $401D
Clear_x_256 EQU $F545
MOV_DRAW_VLCS EQU $F3B5
VEC_JOY_1_Y EQU $C81C
Vec_Text_Height EQU $C82A
Intensity_5F EQU $F2A5
Intensity_3F EQU $F2A1
DP_TO_C8 EQU $F1AF
Vec_Max_Games EQU $C850
Print_Str_yx EQU $F378
SOUND_BYTE EQU $F256
RECALIBRATE EQU $F2E6
Vec_Counter_1 EQU $C82E
musicb EQU $FF62
MUSIC6 EQU $FE76
MOV_DRAW_VLC_A EQU $F3AD
Cold_Start EQU $F000
DLW_SEG1_DX_READY EQU $40C9
Xform_Rise_a EQU $F661
Dec_6_Counters EQU $F55E
SOUND_BYTE_X EQU $F259
DRAW_VLP_B EQU $F40E
MOD16.M16_LOOP EQU $4034
music6 EQU $FE76
DRAW_LINE_D EQU $F3DF
COMPARE_SCORE EQU $F8C7
Print_List EQU $F38A
Strip_Zeros EQU $F8B7
MOVE_MEM_A_1 EQU $F67F
RISE_RUN_X EQU $F5FF
VEC_NUM_PLAYERS EQU $C879
VEC_NMI_VECTOR EQU $CBFB
music9 EQU $FF26
DRAW_PAT_VL_D EQU $F439
DOT_HERE EQU $F2C5
MUSIC7 EQU $FEC6
Dot_ix EQU $F2C1
DLW_SEG1_DX_LO EQU $40B9
DRAW_GRID_VL EQU $FF9F
INIT_VIA EQU $F14C
Rise_Run_Angle EQU $F593
VEC_JOY_MUX_2_X EQU $C821
Read_Btns EQU $F1BA
Rot_VL_dft EQU $F637
PRINT_LIST_CHK EQU $F38C
VEC_BUTTON_1_3 EQU $C814
Vec_Brightness EQU $C827
RESET0REF EQU $F354
DELAY_1 EQU $F575
Draw_Pat_VL_d EQU $F439
Vec_Music_Wk_A EQU $C842
ROT_VL_AB EQU $F610
Dec_3_Counters EQU $F55A
VEC_DURATION EQU $C857
Vec_Joy_Resltn EQU $C81A
music2 EQU $FD1D
BITMASK_A EQU $F57E
Xform_Rise EQU $F663
Vec_Button_2_3 EQU $C818
Add_Score_a EQU $F85E
VEC_EXPL_4 EQU $C85B
Vec_Counter_4 EQU $C831
INTENSITY_A EQU $F2AB
Vec_SWI_Vector EQU $CBFB
Reset0Int EQU $F36B
Vec_Joy_Mux_1_Y EQU $C820
Clear_Score EQU $F84F
DELAY_RTS EQU $F57D
Draw_VLp_scale EQU $F40C
Rise_Run_Y EQU $F601
Draw_VLc EQU $F3CE
SOUND_BYTE_RAW EQU $F25B
VEC_BUTTON_1_4 EQU $C815
Draw_Line_d EQU $F3DF
DRAW_VL EQU $F3DD
Intensity_a EQU $F2AB
Vec_Max_Players EQU $C84F
Moveto_ix EQU $F310
MUSIC5 EQU $FE38
Draw_VL_b EQU $F3D2
MOV_DRAW_VL_A EQU $F3B9
CLEAR_SCORE EQU $F84F
Explosion_Snd EQU $F92E
DRAW_PAT_VL_A EQU $F434
music8 EQU $FEF8
VEC_ANGLE EQU $C836
DLW_SEG1_DY_LO EQU $4096
PRINT_LIST EQU $F38A
VEC_BUTTON_1_2 EQU $C813
EXPLOSION_SND EQU $F92E
ROT_VL_DFT EQU $F637
CLEAR_X_D EQU $F548
Vec_Button_2_4 EQU $C819
VEC_PATTERN EQU $C829
Random EQU $F517
musicd EQU $FF8F
Mov_Draw_VL_ab EQU $F3B7
Clear_x_d EQU $F548
Intensity_1F EQU $F29D
Do_Sound EQU $F289
SOUND_BYTES EQU $F27D
Reset0Ref EQU $F354
Vec_Button_1_4 EQU $C815
VEC_EXPL_2 EQU $C859
Delay_b EQU $F57A
ADD_SCORE_A EQU $F85E
Vec_Freq_Table EQU $C84D
Clear_x_b_80 EQU $F550
VEC_MUSIC_WORK EQU $C83F
VEC_NUM_GAME EQU $C87A
Sound_Byte EQU $F256
VEC_EXPL_3 EQU $C85A
READ_BTNS_MASK EQU $F1B4
VEC_MISC_COUNT EQU $C823
JOY_DIGITAL EQU $F1F8
VEC_COUNTER_2 EQU $C82F
VEC_MUSIC_FLAG EQU $C856
VEC_MUSIC_FREQ EQU $C861


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
