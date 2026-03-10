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
DRAW_VEC_INTENSITY   EQU $C880+$0E   ; Vector intensity override (0=use vector data) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$0F   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$19   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$1B   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$1D   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$1E   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$1F   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$21   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$23   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$24   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
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
Mov_Draw_VL_ab EQU $F3B7
INTENSITY_1F EQU $F29D
Warm_Start EQU $F06C
Vec_Joy_2_X EQU $C81D
DEC_3_COUNTERS EQU $F55A
Dot_d EQU $F2C3
Obj_Will_Hit_u EQU $F8E5
PRINT_LIST_HW EQU $F385
Read_Btns_Mask EQU $F1B4
Vec_Expl_ChanB EQU $C85D
Vec_Cold_Flag EQU $CBFE
VEC_0REF_ENABLE EQU $C824
PRINT_SHIPS EQU $F393
XFORM_RISE EQU $F663
CHECK0REF EQU $F34F
MOVETO_D_7F EQU $F2FC
CLEAR_X_D EQU $F548
VEC_EXPL_1 EQU $C858
VEC_MUSIC_FREQ EQU $C861
Vec_Loop_Count EQU $C825
DP_TO_D0 EQU $F1AA
Vec_Seed_Ptr EQU $C87B
Mov_Draw_VL EQU $F3BC
MOV_DRAW_VLCS EQU $F3B5
Mov_Draw_VLcs EQU $F3B5
GET_RUN_IDX EQU $F5DB
JOY_DIGITAL EQU $F1F8
ABS_A_B EQU $F584
Vec_ADSR_Timers EQU $C85E
Vec_Text_HW EQU $C82A
INTENSITY_A EQU $F2AB
VEC_DURATION EQU $C857
VEC_EXPL_CHAN EQU $C85C
Delay_1 EQU $F575
Bitmask_a EQU $F57E
VEC_BRIGHTNESS EQU $C827
Vec_Button_2_3 EQU $C818
Intensity_7F EQU $F2A9
Vec_Duration EQU $C857
MOD16.M16_DONE EQU $4083
Clear_C8_RAM EQU $F542
DRAW_VLC EQU $F3CE
VEC_STR_PTR EQU $C82C
VEC_EXPL_4 EQU $C85B
VEC_JOY_2_Y EQU $C81E
WAIT_RECAL EQU $F192
Sound_Bytes EQU $F27D
VEC_EXPL_CHANS EQU $C854
VEC_COUNTER_6 EQU $C833
CLEAR_SCORE EQU $F84F
Intensity_a EQU $F2AB
INIT_OS EQU $F18B
Xform_Run_a EQU $F65B
Vec_Dot_Dwell EQU $C828
MOD16.M16_LOOP EQU $4064
Add_Score_d EQU $F87C
VECTREX_PRINT_TEXT EQU $4000
MUSIC9 EQU $FF26
Move_Mem_a_1 EQU $F67F
XFORM_RUN EQU $F65D
music4 EQU $FDD3
Rise_Run_Angle EQU $F593
GET_RISE_RUN EQU $F5EF
XFORM_RISE_A EQU $F661
Moveto_ix EQU $F310
ABS_B EQU $F58B
Get_Rise_Idx EQU $F5D9
Draw_Grid_VL EQU $FF9F
VEC_BUTTON_2_2 EQU $C817
VEC_EXPL_FLAG EQU $C867
Vec_Joy_Mux EQU $C81F
VEC_COUNTER_1 EQU $C82E
music7 EQU $FEC6
Add_Score_a EQU $F85E
Vec_Button_2_2 EQU $C817
Vec_Max_Players EQU $C84F
Clear_x_b_a EQU $F552
PRINT_TEXT_STR_11966217390444143374 EQU $40A6
VEC_MUSIC_PTR EQU $C853
Vec_Button_1_3 EQU $C814
CLEAR_SOUND EQU $F272
DRAW_VLP_7F EQU $F408
Rot_VL_Mode EQU $F62B
VEC_TEXT_HEIGHT EQU $C82A
Draw_Pat_VL_a EQU $F434
VEC_RFRSH_HI EQU $C83E
OBJ_HIT EQU $F8FF
Vec_Random_Seed EQU $C87D
Xform_Rise EQU $F663
Vec_Music_Flag EQU $C856
Do_Sound EQU $F289
Init_Music_Buf EQU $F533
Vec_Expl_2 EQU $C859
Vec_High_Score EQU $CBEB
Vec_Music_Work EQU $C83F
Vec_0Ref_Enable EQU $C824
Sound_Byte_x EQU $F259
Vec_Snd_Shadow EQU $C800
CLEAR_X_256 EQU $F545
INIT_MUSIC EQU $F68D
BITMASK_A EQU $F57E
VEC_SWI_VECTOR EQU $CBFB
CLEAR_C8_RAM EQU $F542
Draw_VLp EQU $F410
Moveto_ix_FF EQU $F308
MOVETO_IX EQU $F310
Recalibrate EQU $F2E6
PRINT_STR_YX EQU $F378
Draw_VL_a EQU $F3DA
Vec_Music_Chan EQU $C855
VEC_ADSR_TIMERS EQU $C85E
Vec_Counter_6 EQU $C833
Mov_Draw_VLc_a EQU $F3AD
RISE_RUN_ANGLE EQU $F593
VEC_SWI3_VECTOR EQU $CBF2
Vec_Joy_Mux_1_X EQU $C81F
PRINT_SHIPS_X EQU $F391
MUSIC3 EQU $FD81
Vec_Joy_Mux_2_Y EQU $C822
VEC_RANDOM_SEED EQU $C87D
Init_VIA EQU $F14C
DEC_COUNTERS EQU $F563
Print_Str_d EQU $F37A
COLD_START EQU $F000
VEC_NMI_VECTOR EQU $CBFB
VEC_RISERUN_LEN EQU $C83B
Vec_Joy_Resltn EQU $C81A
DRAW_VL_AB EQU $F3D8
Mov_Draw_VL_b EQU $F3B1
DRAW_VL EQU $F3DD
NEW_HIGH_SCORE EQU $F8D8
Vec_RiseRun_Tmp EQU $C834
VEC_MUSIC_TWANG EQU $C858
VEC_COLD_FLAG EQU $CBFE
Vec_Expl_ChanA EQU $C853
VEC_DOT_DWELL EQU $C828
VEC_COUNTER_4 EQU $C831
VEC_EXPL_2 EQU $C859
Rot_VL_Mode_a EQU $F61F
VEC_BTN_STATE EQU $C80F
SOUND_BYTES_X EQU $F284
VEC_COUNTERS EQU $C82E
MUSICB EQU $FF62
Obj_Hit EQU $F8FF
Vec_Default_Stk EQU $CBEA
VEC_PATTERN EQU $C829
VEC_RISE_INDEX EQU $C839
Vec_Expl_Chan EQU $C85C
DELAY_3 EQU $F56D
VEC_BUTTON_1_1 EQU $C812
SOUND_BYTE EQU $F256
Vec_Text_Width EQU $C82B
Vec_Expl_Flag EQU $C867
INIT_MUSIC_BUF EQU $F533
DRAW_VLP EQU $F410
Dot_ix_b EQU $F2BE
Clear_x_b EQU $F53F
Rise_Run_Len EQU $F603
RESET_PEN EQU $F35B
MUSIC2 EQU $FD1D
Vec_Music_Freq EQU $C861
MUSIC5 EQU $FE38
DO_SOUND EQU $F289
OBJ_WILL_HIT_U EQU $F8E5
Random_3 EQU $F511
Delay_RTS EQU $F57D
VEC_RFRSH_LO EQU $C83D
Vec_Music_Wk_7 EQU $C845
Vec_Joy_2_Y EQU $C81E
Vec_Rfrsh_lo EQU $C83D
PRINT_LIST EQU $F38A
MOD16 EQU $4030
MOVE_MEM_A_1 EQU $F67F
Clear_Sound EQU $F272
VEC_MUSIC_WK_7 EQU $C845
VEC_JOY_2_X EQU $C81D
SOUND_BYTES EQU $F27D
MOV_DRAW_VL_A EQU $F3B9
VEC_MUSIC_WK_1 EQU $C84B
VEC_JOY_MUX_2_Y EQU $C822
music8 EQU $FEF8
MOD16.M16_END EQU $4074
Draw_VLp_7F EQU $F408
Vec_Counter_1 EQU $C82E
Vec_Button_1_4 EQU $C815
VEC_SWI2_VECTOR EQU $CBF2
Print_Str_yx EQU $F378
Select_Game EQU $F7A9
STRIP_ZEROS EQU $F8B7
Random EQU $F517
Draw_VLcs EQU $F3D6
Clear_x_b_80 EQU $F550
Draw_VL_ab EQU $F3D8
VEC_RUN_INDEX EQU $C837
VEC_TEXT_WIDTH EQU $C82B
Do_Sound_x EQU $F28C
MOVETO_D EQU $F312
Reset0Ref EQU $F354
INIT_VIA EQU $F14C
Rise_Run_X EQU $F5FF
DOT_IX EQU $F2C1
DRAW_VLCS EQU $F3D6
DRAW_PAT_VL_D EQU $F439
VEC_BUTTON_2_3 EQU $C818
DEC_6_COUNTERS EQU $F55E
VEC_JOY_MUX_1_X EQU $C81F
DRAW_VL_MODE EQU $F46E
VEC_LOOP_COUNT EQU $C825
VEC_TWANG_TABLE EQU $C851
Print_Str_hwyx EQU $F373
Vec_Music_Twang EQU $C858
VEC_EXPL_3 EQU $C85A
Vec_Pattern EQU $C829
MOV_DRAW_VL_D EQU $F3BE
Print_Ships_x EQU $F391
Vec_Rfrsh_hi EQU $C83E
Init_Music_x EQU $F692
Vec_Rfrsh EQU $C83D
Init_OS_RAM EQU $F164
Print_Str EQU $F495
Moveto_d EQU $F312
Vec_Counter_2 EQU $C82F
VEC_BUTTON_2_4 EQU $C819
MUSIC4 EQU $FDD3
Vec_Btn_State EQU $C80F
VEC_COUNTER_3 EQU $C830
Set_Refresh EQU $F1A2
PRINT_TEXT_STR_2446385111 EQU $4092
INTENSITY_5F EQU $F2A5
Intensity_5F EQU $F2A5
Draw_VL_b EQU $F3D2
Print_List_hw EQU $F385
DRAW_VLP_FF EQU $F404
VEC_BUTTON_1_3 EQU $C814
ROT_VL EQU $F616
PRINT_STR_D EQU $F37A
Dot_List EQU $F2D5
MUSIC7 EQU $FEC6
VEC_COUNTER_5 EQU $C832
Moveto_ix_a EQU $F30E
VEC_MAX_GAMES EQU $C850
musicb EQU $FF62
Draw_VLp_b EQU $F40E
Delay_0 EQU $F579
VEC_PREV_BTNS EQU $C810
VEC_JOY_RESLTN EQU $C81A
RANDOM EQU $F517
SELECT_GAME EQU $F7A9
VEC_BUTTON_2_1 EQU $C816
SOUND_BYTE_X EQU $F259
Vec_Button_1_1 EQU $C812
VEC_JOY_1_Y EQU $C81C
VEC_BUTTONS EQU $C811
MUSIC1 EQU $FD0D
SOUND_BYTE_RAW EQU $F25B
MUSICA EQU $FF44
VEC_EXPL_CHANA EQU $C853
MUSICC EQU $FF7A
Print_List_chk EQU $F38C
Init_OS EQU $F18B
EXPLOSION_SND EQU $F92E
Obj_Will_Hit EQU $F8F3
VEC_MAX_PLAYERS EQU $C84F
Vec_FIRQ_Vector EQU $CBF5
RECALIBRATE EQU $F2E6
RISE_RUN_LEN EQU $F603
DRAW_LINE_D EQU $F3DF
DOT_LIST_RESET EQU $F2DE
Vec_Expl_Timer EQU $C877
INTENSITY_3F EQU $F2A1
ADD_SCORE_D EQU $F87C
MOD16.M16_RPOS EQU $4064
CLEAR_X_B_80 EQU $F550
MOVE_MEM_A EQU $F683
Print_List EQU $F38A
Init_Music_chk EQU $F687
New_High_Score EQU $F8D8
DRAW_VL_A EQU $F3DA
Delay_b EQU $F57A
music6 EQU $FE76
Vec_Joy_Mux_2_X EQU $C821
Get_Rise_Run EQU $F5EF
VEC_MUSIC_WK_A EQU $C842
RISE_RUN_Y EQU $F601
Abs_b EQU $F58B
Vec_Twang_Table EQU $C851
RISE_RUN_X EQU $F5FF
CLEAR_X_B EQU $F53F
VEC_JOY_1_X EQU $C81B
Sound_Byte EQU $F256
Vec_Counter_4 EQU $C831
Draw_Pat_VL_d EQU $F439
Vec_Button_1_2 EQU $C813
PRINT_TEXT_STR_2446385107 EQU $4084
RESET0REF_D0 EQU $F34A
Vec_NMI_Vector EQU $CBFB
Reset_Pen EQU $F35B
INIT_MUSIC_X EQU $F692
VEC_COUNTER_2 EQU $C82F
DP_to_C8 EQU $F1AF
DOT_LIST EQU $F2D5
Delay_2 EQU $F571
Draw_Line_d EQU $F3DF
DRAW_PAT_VL_A EQU $F434
DRAW_VLP_B EQU $F40E
DELAY_0 EQU $F579
RANDOM_3 EQU $F511
VEC_RISERUN_TMP EQU $C834
VEC_MUSIC_WK_5 EQU $C847
MOV_DRAW_VL EQU $F3BC
Vec_Counter_5 EQU $C832
music2 EQU $FD1D
Vec_Prev_Btns EQU $C810
DELAY_2 EQU $F571
VEC_FIRQ_VECTOR EQU $CBF5
Intensity_1F EQU $F29D
Strip_Zeros EQU $F8B7
VEC_MUSIC_FLAG EQU $C856
Cold_Start EQU $F000
VEC_ADSR_TABLE EQU $C84F
ROT_VL_MODE EQU $F62B
PRINT_LIST_CHK EQU $F38C
INIT_OS_RAM EQU $F164
ADD_SCORE_A EQU $F85E
Vec_Expl_Chans EQU $C854
Sound_Bytes_x EQU $F284
INIT_MUSIC_CHK EQU $F687
music3 EQU $FD81
RESET0INT EQU $F36B
VEC_EXPL_TIMER EQU $C877
Vec_Misc_Count EQU $C823
Check0Ref EQU $F34F
Get_Run_Idx EQU $F5DB
MOVETO_IX_A EQU $F30E
DO_SOUND_X EQU $F28C
Vec_Counter_3 EQU $C830
Vec_Run_Index EQU $C837
Draw_VLp_scale EQU $F40C
Init_Music EQU $F68D
VEC_DEFAULT_STK EQU $CBEA
DELAY_1 EQU $F575
musica EQU $FF44
VEC_FREQ_TABLE EQU $C84D
Dot_List_Reset EQU $F2DE
PRINT_STR EQU $F495
Vec_Music_Ptr EQU $C853
Mov_Draw_VL_a EQU $F3B9
MUSIC8 EQU $FEF8
Compare_Score EQU $F8C7
Rot_VL EQU $F616
READ_BTNS_MASK EQU $F1B4
PRINT_TEXT_STR_2446385109 EQU $408B
CLEAR_X_B_A EQU $F552
Vec_Buttons EQU $C811
Draw_Pat_VL EQU $F437
music5 EQU $FE38
Move_Mem_a EQU $F683
Delay_3 EQU $F56D
XFORM_RUN_A EQU $F65B
MUSIC6 EQU $FE76
VEC_TEXT_HW EQU $C82A
INTENSITY_7F EQU $F2A9
Vec_Num_Game EQU $C87A
COMPARE_SCORE EQU $F8C7
Vec_Music_Wk_1 EQU $C84B
Abs_a_b EQU $F584
Draw_VLp_FF EQU $F404
Vec_Joy_1_X EQU $C81B
Vec_Max_Games EQU $C850
Clear_x_d EQU $F548
Vec_SWI_Vector EQU $CBFB
musicd EQU $FF8F
MUSICD EQU $FF8F
DOT_HERE EQU $F2C5
music9 EQU $FF26
Rise_Run_Y EQU $F601
Rot_VL_ab EQU $F610
Vec_Music_Wk_A EQU $C842
JOY_ANALOG EQU $F1F5
Clear_Score EQU $F84F
Moveto_ix_7F EQU $F30C
Vec_Freq_Table EQU $C84D
Print_Ships EQU $F393
Vec_SWI3_Vector EQU $CBF2
Moveto_x_7F EQU $F2F2
Intensity_3F EQU $F2A1
DP_TO_C8 EQU $F1AF
VEC_MISC_COUNT EQU $C823
Explosion_Snd EQU $F92E
DELAY_B EQU $F57A
VEC_MUSIC_WORK EQU $C83F
Vec_Expl_3 EQU $C85A
Draw_VLc EQU $F3CE
READ_BTNS EQU $F1BA
VEC_BUTTON_1_4 EQU $C815
OBJ_WILL_HIT EQU $F8F3
Vec_Num_Players EQU $C879
Vec_Joy_Mux_1_Y EQU $C820
Vec_Music_Wk_6 EQU $C846
DRAW_VLP_SCALE EQU $F40C
music1 EQU $FD0D
ROT_VL_DFT EQU $F637
VEC_JOY_MUX EQU $C81F
Read_Btns EQU $F1BA
DOT_D EQU $F2C3
MOV_DRAW_VL_AB EQU $F3B7
Vec_SWI2_Vector EQU $CBF2
Mov_Draw_VL_d EQU $F3BE
VEC_RFRSH EQU $C83D
DRAW_GRID_VL EQU $FF9F
Draw_VL EQU $F3DD
Vec_Joy_1_Y EQU $C81C
Moveto_d_7F EQU $F2FC
DOT_IX_B EQU $F2BE
VEC_NUM_GAME EQU $C87A
Reset0Ref_D0 EQU $F34A
Vec_Rise_Index EQU $C839
Vec_Button_2_1 EQU $C816
Dot_here EQU $F2C5
DELAY_RTS EQU $F57D
Joy_Digital EQU $F1F8
VEC_BUTTON_1_2 EQU $C813
Dec_3_Counters EQU $F55A
MOVETO_X_7F EQU $F2F2
PRINT_STR_HWYX EQU $F373
MOV_DRAW_VLC_A EQU $F3AD
ROT_VL_MODE_A EQU $F61F
VEC_MUSIC_CHAN EQU $C855
Vec_Expl_1 EQU $C858
MOD16.M16_DPOS EQU $404D
VEC_MUSIC_WK_6 EQU $C846
PRINT_TEXT_STR_2171175787713719065 EQU $4099
musicc EQU $FF7A
Vec_Str_Ptr EQU $C82C
Joy_Analog EQU $F1F5
VEC_SND_SHADOW EQU $C800
DRAW_VL_B EQU $F3D2
VEC_JOY_MUX_1_Y EQU $C820
Vec_IRQ_Vector EQU $CBF8
Xform_Run EQU $F65D
Vec_RiseRun_Len EQU $C83B
MOV_DRAW_VL_B EQU $F3B1
ROT_VL_AB EQU $F610
VEC_EXPL_CHANB EQU $C85D
Vec_Music_Wk_5 EQU $C847
Dec_Counters EQU $F563
VEC_NUM_PLAYERS EQU $C879
Rot_VL_dft EQU $F637
Dot_ix EQU $F2C1
VEC_IRQ_VECTOR EQU $CBF8
MOVETO_IX_FF EQU $F308
DP_to_D0 EQU $F1AA
VEC_SEED_PTR EQU $C87B
Vec_Text_Height EQU $C82A
Clear_x_256 EQU $F545
Vec_Button_2_4 EQU $C819
GET_RISE_IDX EQU $F5D9
VEC_HIGH_SCORE EQU $CBEB
Wait_Recal EQU $F192
WARM_START EQU $F06C
Vec_Angle EQU $C836
Vec_ADSR_Table EQU $C84F
RESET0REF EQU $F354
MOD16.M16_RCHECK EQU $4055
Xform_Rise_a EQU $F661
SET_REFRESH EQU $F1A2
Vec_Counters EQU $C82E
MOVETO_IX_7F EQU $F30C
Dec_6_Counters EQU $F55E
VEC_JOY_MUX_2_X EQU $C821
Vec_Brightness EQU $C827
Sound_Byte_raw EQU $F25B
Reset0Int EQU $F36B
VEC_ANGLE EQU $C836
Vec_Expl_4 EQU $C85B
DRAW_PAT_VL EQU $F437
Draw_VL_mode EQU $F46E


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "TXTSIZE"
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
DRAW_VEC_INTENSITY   EQU $C880+$0E   ; Vector intensity override (0=use vector data) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$0F   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$19   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$1B   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$1D   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$1E   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$1F   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$21   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$23   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$24   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
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
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    JSR draw_scales
    RTS

; Function: draw_scales (Bank #0)
draw_scales:
    LDD #8
    STD TMPPTR2     ; Save n (TMPPTR2+1 = n)
    NEGB            ; B = -n -> TEXT_SCALE_H
    STB >TEXT_SCALE_H
    LDB TMPPTR2+1   ; Reload n (from TMPPTR2, not RESULT)
    ASLB            ; n*2
    ASLB            ; n*4
    ASLB            ; n*8
    ADDB TMPPTR2+1  ; n*8 + n = n*9 -> TEXT_SCALE_W
    STB >TEXT_SCALE_W
    ; PRINT_TEXT: Print text at position
    LDD #-80
    STD VAR_ARG0
    LDD #80
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_11966217390444143374      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD #6
    STD TMPPTR2     ; Save n (TMPPTR2+1 = n)
    NEGB            ; B = -n -> TEXT_SCALE_H
    STB >TEXT_SCALE_H
    LDB TMPPTR2+1   ; Reload n (from TMPPTR2, not RESULT)
    ASLB            ; n*2
    ASLB            ; n*4
    ASLB            ; n*8
    ADDB TMPPTR2+1  ; n*8 + n = n*9 -> TEXT_SCALE_W
    STB >TEXT_SCALE_W
    ; PRINT_TEXT: Print text at position
    LDD #-80
    STD VAR_ARG0
    LDD #40
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2446385111      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD #4
    STD TMPPTR2     ; Save n (TMPPTR2+1 = n)
    NEGB            ; B = -n -> TEXT_SCALE_H
    STB >TEXT_SCALE_H
    LDB TMPPTR2+1   ; Reload n (from TMPPTR2, not RESULT)
    ASLB            ; n*2
    ASLB            ; n*4
    ASLB            ; n*8
    ADDB TMPPTR2+1  ; n*8 + n = n*9 -> TEXT_SCALE_W
    STB >TEXT_SCALE_W
    ; PRINT_TEXT: Print text at position
    LDD #-80
    STD VAR_ARG0
    LDD #5
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2446385109      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD #2
    STD TMPPTR2     ; Save n (TMPPTR2+1 = n)
    NEGB            ; B = -n -> TEXT_SCALE_H
    STB >TEXT_SCALE_H
    LDB TMPPTR2+1   ; Reload n (from TMPPTR2, not RESULT)
    ASLB            ; n*2
    ASLB            ; n*4
    ASLB            ; n*8
    ADDB TMPPTR2+1  ; n*8 + n = n*9 -> TEXT_SCALE_W
    STB >TEXT_SCALE_W
    ; PRINT_TEXT: Print text at position
    LDD #-80
    STD VAR_ARG0
    LDD #-30
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2446385107      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD #1
    STD TMPPTR2     ; Save n (TMPPTR2+1 = n)
    NEGB            ; B = -n -> TEXT_SCALE_H
    STB >TEXT_SCALE_H
    LDB TMPPTR2+1   ; Reload n (from TMPPTR2, not RESULT)
    ASLB            ; n*2
    ASLB            ; n*4
    ASLB            ; n*8
    ADDB TMPPTR2+1  ; n*8 + n = n*9 -> TEXT_SCALE_W
    STB >TEXT_SCALE_W
    ; PRINT_TEXT: Print text at position
    LDD #-80
    STD VAR_ARG0
    LDD #-60
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2171175787713719065      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD #8
    STD TMPPTR2     ; Save n (TMPPTR2+1 = n)
    NEGB            ; B = -n -> TEXT_SCALE_H
    STB >TEXT_SCALE_H
    LDB TMPPTR2+1   ; Reload n (from TMPPTR2, not RESULT)
    ASLB            ; n*2
    ASLB            ; n*4
    ASLB            ; n*8
    ADDB TMPPTR2+1  ; n*8 + n = n*9 -> TEXT_SCALE_W
    STB >TEXT_SCALE_W
    RTS


; ================================================
