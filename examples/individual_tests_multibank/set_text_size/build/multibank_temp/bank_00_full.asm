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
PRINT_STR_YX EQU $F378
VEC_MUSIC_WK_7 EQU $C845
VEC_TEXT_HW EQU $C82A
Mov_Draw_VL_b EQU $F3B1
RISE_RUN_ANGLE EQU $F593
PRINT_TEXT_STR_2446385111 EQU $4092
VEC_RFRSH EQU $C83D
COMPARE_SCORE EQU $F8C7
Draw_Grid_VL EQU $FF9F
MUSIC3 EQU $FD81
MUSIC5 EQU $FE38
PRINT_TEXT_STR_11966217390444143374 EQU $40A6
Vec_Joy_Mux_2_Y EQU $C822
VEC_MUSIC_WORK EQU $C83F
Vec_Counter_5 EQU $C832
ROT_VL_MODE EQU $F62B
Add_Score_a EQU $F85E
DOT_IX_B EQU $F2BE
MUSIC9 EQU $FF26
INTENSITY_A EQU $F2AB
VEC_EXPL_TIMER EQU $C877
DRAW_VLC EQU $F3CE
MUSIC6 EQU $FE76
Vec_Seed_Ptr EQU $C87B
VEC_PREV_BTNS EQU $C810
DEC_COUNTERS EQU $F563
VEC_EXPL_CHAN EQU $C85C
VEC_ADSR_TABLE EQU $C84F
Init_Music_Buf EQU $F533
Do_Sound EQU $F289
GET_RUN_IDX EQU $F5DB
Rot_VL_Mode_a EQU $F61F
Reset0Ref_D0 EQU $F34A
Vec_Joy_Resltn EQU $C81A
MOV_DRAW_VL EQU $F3BC
Sound_Bytes EQU $F27D
VEC_COUNTERS EQU $C82E
VEC_BRIGHTNESS EQU $C827
RANDOM_3 EQU $F511
Vec_Music_Flag EQU $C856
ADD_SCORE_D EQU $F87C
musicd EQU $FF8F
Vec_Counter_2 EQU $C82F
music6 EQU $FE76
Vec_Expl_Chans EQU $C854
Vec_SWI_Vector EQU $CBFB
Print_Str EQU $F495
Compare_Score EQU $F8C7
Vec_Joy_1_X EQU $C81B
VEC_0REF_ENABLE EQU $C824
Delay_3 EQU $F56D
VEC_RANDOM_SEED EQU $C87D
Vec_Button_2_4 EQU $C819
MOVE_MEM_A_1 EQU $F67F
INTENSITY_3F EQU $F2A1
MUSIC2 EQU $FD1D
CLEAR_X_D EQU $F548
Vec_Pattern EQU $C829
Vec_Num_Game EQU $C87A
New_High_Score EQU $F8D8
CLEAR_X_B_80 EQU $F550
Init_VIA EQU $F14C
Vec_Duration EQU $C857
Draw_VLp EQU $F410
VEC_COUNTER_4 EQU $C831
DRAW_PAT_VL_A EQU $F434
Vec_Cold_Flag EQU $CBFE
VEC_RISERUN_TMP EQU $C834
SELECT_GAME EQU $F7A9
VEC_BUTTON_1_2 EQU $C813
Print_Str_yx EQU $F378
Moveto_x_7F EQU $F2F2
VEC_EXPL_1 EQU $C858
Check0Ref EQU $F34F
VEC_JOY_MUX_1_Y EQU $C820
Dot_d EQU $F2C3
JOY_ANALOG EQU $F1F5
Xform_Rise EQU $F663
Draw_VLcs EQU $F3D6
Sound_Byte EQU $F256
PRINT_STR_HWYX EQU $F373
Init_OS_RAM EQU $F164
VEC_SWI2_VECTOR EQU $CBF2
VEC_TEXT_WIDTH EQU $C82B
Draw_Pat_VL_a EQU $F434
Draw_VLp_b EQU $F40E
PRINT_SHIPS_X EQU $F391
musicb EQU $FF62
Mov_Draw_VLc_a EQU $F3AD
VEC_JOY_MUX_2_X EQU $C821
Select_Game EQU $F7A9
SOUND_BYTE_RAW EQU $F25B
Mov_Draw_VL_d EQU $F3BE
VEC_DURATION EQU $C857
Vec_Joy_Mux_2_X EQU $C821
Vec_Joy_1_Y EQU $C81C
Draw_Pat_VL_d EQU $F439
VEC_JOY_MUX EQU $C81F
MUSICC EQU $FF7A
VEC_MUSIC_PTR EQU $C853
Clear_x_b EQU $F53F
VECTREX_PRINT_TEXT EQU $4000
Explosion_Snd EQU $F92E
Init_OS EQU $F18B
VEC_BUTTON_1_1 EQU $C812
MUSIC4 EQU $FDD3
Intensity_3F EQU $F2A1
Vec_Joy_2_X EQU $C81D
DRAW_VL_MODE EQU $F46E
VEC_EXPL_4 EQU $C85B
Vec_Music_Twang EQU $C858
VEC_IRQ_VECTOR EQU $CBF8
Vec_IRQ_Vector EQU $CBF8
Vec_RiseRun_Len EQU $C83B
VEC_RUN_INDEX EQU $C837
Delay_RTS EQU $F57D
Vec_Music_Ptr EQU $C853
VEC_EXPL_2 EQU $C859
Vec_Dot_Dwell EQU $C828
VEC_SEED_PTR EQU $C87B
Rise_Run_X EQU $F5FF
DRAW_PAT_VL_D EQU $F439
MOVETO_IX_A EQU $F30E
DRAW_VL_A EQU $F3DA
DP_to_C8 EQU $F1AF
VEC_MUSIC_CHAN EQU $C855
Get_Rise_Idx EQU $F5D9
PRINT_LIST_HW EQU $F385
DELAY_1 EQU $F575
Vec_Expl_Chan EQU $C85C
VEC_MUSIC_FREQ EQU $C861
DRAW_VL_B EQU $F3D2
INIT_MUSIC_X EQU $F692
Vec_Joy_2_Y EQU $C81E
VEC_MUSIC_FLAG EQU $C856
Vec_Str_Ptr EQU $C82C
Init_Music_chk EQU $F687
Clear_Score EQU $F84F
Draw_VLp_scale EQU $F40C
Read_Btns_Mask EQU $F1B4
Vec_Btn_State EQU $C80F
Vec_Joy_Mux EQU $C81F
DRAW_VLP_SCALE EQU $F40C
VEC_BUTTONS EQU $C811
DOT_IX EQU $F2C1
Vec_Expl_Flag EQU $C867
Vec_0Ref_Enable EQU $C824
Mov_Draw_VL_ab EQU $F3B7
Vec_Twang_Table EQU $C851
Clear_x_b_a EQU $F552
RESET0REF EQU $F354
MOD16.M16_DONE EQU $4083
Vec_Expl_3 EQU $C85A
MOV_DRAW_VLCS EQU $F3B5
MOV_DRAW_VLC_A EQU $F3AD
Vec_ADSR_Table EQU $C84F
Clear_x_b_80 EQU $F550
Dot_List EQU $F2D5
Vec_Music_Wk_6 EQU $C846
Vec_Counter_6 EQU $C833
PRINT_TEXT_STR_2446385107 EQU $4084
VEC_SWI_VECTOR EQU $CBFB
VEC_MUSIC_TWANG EQU $C858
Get_Run_Idx EQU $F5DB
VEC_RFRSH_LO EQU $C83D
VEC_JOY_2_X EQU $C81D
Vec_Run_Index EQU $C837
Abs_a_b EQU $F584
MUSIC1 EQU $FD0D
RANDOM EQU $F517
MUSIC7 EQU $FEC6
GET_RISE_RUN EQU $F5EF
MOD16.M16_RPOS EQU $4064
Joy_Analog EQU $F1F5
DO_SOUND EQU $F289
Vec_Counters EQU $C82E
Get_Rise_Run EQU $F5EF
DRAW_VLCS EQU $F3D6
Dec_6_Counters EQU $F55E
VEC_MUSIC_WK_5 EQU $C847
Init_Music_x EQU $F692
Draw_VLp_FF EQU $F404
Wait_Recal EQU $F192
Obj_Will_Hit_u EQU $F8E5
VEC_EXPL_CHANA EQU $C853
VEC_RISERUN_LEN EQU $C83B
SOUND_BYTE EQU $F256
Print_List_chk EQU $F38C
Clear_C8_RAM EQU $F542
ABS_B EQU $F58B
DP_TO_C8 EQU $F1AF
INIT_MUSIC_BUF EQU $F533
Dot_List_Reset EQU $F2DE
Xform_Rise_a EQU $F661
GET_RISE_IDX EQU $F5D9
Print_Ships_x EQU $F391
VEC_ADSR_TIMERS EQU $C85E
Vec_Random_Seed EQU $C87D
Print_Str_d EQU $F37A
ABS_A_B EQU $F584
DRAW_LINE_D EQU $F3DF
VEC_TWANG_TABLE EQU $C851
Vec_Counter_1 EQU $C82E
VEC_COUNTER_2 EQU $C82F
Draw_VL_a EQU $F3DA
Moveto_d_7F EQU $F2FC
OBJ_WILL_HIT EQU $F8F3
VEC_JOY_1_X EQU $C81B
ROT_VL_MODE_A EQU $F61F
Dot_ix_b EQU $F2BE
Sound_Byte_raw EQU $F25B
VEC_JOY_1_Y EQU $C81C
DRAW_VL_AB EQU $F3D8
Sound_Bytes_x EQU $F284
Vec_Freq_Table EQU $C84D
Dec_Counters EQU $F563
DRAW_VLP_FF EQU $F404
RECALIBRATE EQU $F2E6
VEC_DOT_DWELL EQU $C828
VEC_MISC_COUNT EQU $C823
VEC_COUNTER_1 EQU $C82E
music1 EQU $FD0D
PRINT_STR_D EQU $F37A
Strip_Zeros EQU $F8B7
Rot_VL_dft EQU $F637
Move_Mem_a_1 EQU $F67F
VEC_NMI_VECTOR EQU $CBFB
MUSIC8 EQU $FEF8
music7 EQU $FEC6
RISE_RUN_X EQU $F5FF
Vec_Music_Freq EQU $C861
INTENSITY_5F EQU $F2A5
Reset0Ref EQU $F354
MOV_DRAW_VL_D EQU $F3BE
MOD16.M16_LOOP EQU $4064
Vec_Snd_Shadow EQU $C800
Bitmask_a EQU $F57E
SET_REFRESH EQU $F1A2
Rise_Run_Angle EQU $F593
INTENSITY_7F EQU $F2A9
Vec_Button_1_2 EQU $C813
READ_BTNS EQU $F1BA
MOD16 EQU $4030
WAIT_RECAL EQU $F192
Clear_Sound EQU $F272
Dot_ix EQU $F2C1
DELAY_2 EQU $F571
OBJ_HIT EQU $F8FF
VEC_EXPL_3 EQU $C85A
music3 EQU $FD81
Mov_Draw_VL EQU $F3BC
RISE_RUN_LEN EQU $F603
DOT_HERE EQU $F2C5
MOV_DRAW_VL_A EQU $F3B9
CLEAR_X_B_A EQU $F552
Print_Ships EQU $F393
RISE_RUN_Y EQU $F601
DP_to_D0 EQU $F1AA
PRINT_TEXT_STR_2446385109 EQU $408B
DRAW_VLP_7F EQU $F408
Xform_Run EQU $F65D
musica EQU $FF44
Vec_Default_Stk EQU $CBEA
MOV_DRAW_VL_AB EQU $F3B7
XFORM_RUN_A EQU $F65B
DOT_LIST_RESET EQU $F2DE
Intensity_1F EQU $F29D
DELAY_3 EQU $F56D
Vec_SWI3_Vector EQU $CBF2
BITMASK_A EQU $F57E
Vec_Expl_1 EQU $C858
Vec_Rfrsh_hi EQU $C83E
Rot_VL_ab EQU $F610
VEC_MUSIC_WK_A EQU $C842
MOD16.M16_END EQU $4074
Init_Music EQU $F68D
Dec_3_Counters EQU $F55A
Vec_Button_2_2 EQU $C817
Vec_Button_2_3 EQU $C818
Draw_Pat_VL EQU $F437
Vec_Expl_ChanB EQU $C85D
Random_3 EQU $F511
Draw_VL_ab EQU $F3D8
Vec_Rfrsh EQU $C83D
Print_List EQU $F38A
ROT_VL EQU $F616
Reset0Int EQU $F36B
VEC_NUM_PLAYERS EQU $C879
READ_BTNS_MASK EQU $F1B4
PRINT_LIST_CHK EQU $F38C
Draw_VLp_7F EQU $F408
Draw_VLc EQU $F3CE
VEC_JOY_RESLTN EQU $C81A
Print_List_hw EQU $F385
VEC_FIRQ_VECTOR EQU $CBF5
Set_Refresh EQU $F1A2
INIT_VIA EQU $F14C
Vec_Music_Wk_1 EQU $C84B
Mov_Draw_VL_a EQU $F3B9
Mov_Draw_VLcs EQU $F3B5
MOVETO_IX_7F EQU $F30C
music9 EQU $FF26
Read_Btns EQU $F1BA
DRAW_PAT_VL EQU $F437
Delay_0 EQU $F579
Vec_Counter_3 EQU $C830
DOT_D EQU $F2C3
Draw_VL EQU $F3DD
VEC_COUNTER_6 EQU $C833
Moveto_ix EQU $F310
Vec_Button_1_4 EQU $C815
VEC_BUTTON_2_4 EQU $C819
Vec_Num_Players EQU $C879
VEC_COLD_FLAG EQU $CBFE
VEC_STR_PTR EQU $C82C
Vec_Text_Height EQU $C82A
Vec_SWI2_Vector EQU $CBF2
Vec_Misc_Count EQU $C823
Add_Score_d EQU $F87C
Vec_NMI_Vector EQU $CBFB
VEC_RISE_INDEX EQU $C839
INIT_MUSIC EQU $F68D
MOVETO_X_7F EQU $F2F2
music8 EQU $FEF8
CLEAR_SOUND EQU $F272
XFORM_RISE_A EQU $F661
RESET_PEN EQU $F35B
Vec_Music_Work EQU $C83F
VEC_HIGH_SCORE EQU $CBEB
RESET0REF_D0 EQU $F34A
Draw_Line_d EQU $F3DF
Joy_Digital EQU $F1F8
DRAW_VL EQU $F3DD
DRAW_GRID_VL EQU $FF9F
VEC_COUNTER_3 EQU $C830
MOVETO_D EQU $F312
SOUND_BYTES EQU $F27D
OBJ_WILL_HIT_U EQU $F8E5
CLEAR_X_B EQU $F53F
Vec_Button_1_3 EQU $C814
Vec_Music_Chan EQU $C855
COLD_START EQU $F000
Vec_Text_HW EQU $C82A
DELAY_B EQU $F57A
Obj_Hit EQU $F8FF
RESET0INT EQU $F36B
VEC_BUTTON_1_3 EQU $C814
Random EQU $F517
VEC_MUSIC_WK_1 EQU $C84B
Vec_Joy_Mux_1_Y EQU $C820
Clear_x_256 EQU $F545
Rot_VL EQU $F616
VEC_JOY_MUX_2_Y EQU $C822
VEC_BUTTON_1_4 EQU $C815
Cold_Start EQU $F000
MUSICA EQU $FF44
Vec_Button_2_1 EQU $C816
MOD16.M16_DPOS EQU $404D
Rot_VL_Mode EQU $F62B
CHECK0REF EQU $F34F
PRINT_TEXT_STR_2171175787713719065 EQU $4099
VEC_JOY_2_Y EQU $C81E
Vec_Max_Games EQU $C850
Vec_Counter_4 EQU $C831
MUSICD EQU $FF8F
Vec_Joy_Mux_1_X EQU $C81F
NEW_HIGH_SCORE EQU $F8D8
VEC_EXPL_CHANS EQU $C854
Intensity_5F EQU $F2A5
DEC_3_COUNTERS EQU $F55A
MOVETO_D_7F EQU $F2FC
DO_SOUND_X EQU $F28C
VEC_SWI3_VECTOR EQU $CBF2
MOD16.M16_RCHECK EQU $4055
CLEAR_X_256 EQU $F545
ROT_VL_DFT EQU $F637
Vec_Music_Wk_5 EQU $C847
Vec_Music_Wk_A EQU $C842
VEC_COUNTER_5 EQU $C832
Vec_Angle EQU $C836
Vec_Expl_2 EQU $C859
INTENSITY_1F EQU $F29D
VEC_MAX_GAMES EQU $C850
DOT_LIST EQU $F2D5
DELAY_RTS EQU $F57D
WARM_START EQU $F06C
VEC_FREQ_TABLE EQU $C84D
Intensity_7F EQU $F2A9
Draw_VL_b EQU $F3D2
SOUND_BYTES_X EQU $F284
Vec_Text_Width EQU $C82B
VEC_JOY_MUX_1_X EQU $C81F
music4 EQU $FDD3
Xform_Run_a EQU $F65B
VEC_BUTTON_2_2 EQU $C817
ADD_SCORE_A EQU $F85E
Intensity_a EQU $F2AB
Vec_ADSR_Timers EQU $C85E
Moveto_ix_FF EQU $F308
JOY_DIGITAL EQU $F1F8
DP_TO_D0 EQU $F1AA
MOVETO_IX EQU $F310
VEC_EXPL_CHANB EQU $C85D
VEC_ANGLE EQU $C836
Warm_Start EQU $F06C
VEC_EXPL_FLAG EQU $C867
Vec_High_Score EQU $CBEB
Vec_Buttons EQU $C811
PRINT_LIST EQU $F38A
Dot_here EQU $F2C5
Vec_Expl_ChanA EQU $C853
VEC_MAX_PLAYERS EQU $C84F
Rise_Run_Y EQU $F601
Vec_RiseRun_Tmp EQU $C834
Delay_1 EQU $F575
Do_Sound_x EQU $F28C
XFORM_RISE EQU $F663
CLEAR_C8_RAM EQU $F542
Moveto_d EQU $F312
Vec_Music_Wk_7 EQU $C845
VEC_DEFAULT_STK EQU $CBEA
VEC_BUTTON_2_1 EQU $C816
Print_Str_hwyx EQU $F373
Sound_Byte_x EQU $F259
VEC_PATTERN EQU $C829
Vec_Rfrsh_lo EQU $C83D
Draw_VL_mode EQU $F46E
DRAW_VLP EQU $F410
DRAW_VLP_B EQU $F40E
MUSICB EQU $FF62
VEC_SND_SHADOW EQU $C800
Reset_Pen EQU $F35B
ROT_VL_AB EQU $F610
INIT_OS EQU $F18B
Vec_Rise_Index EQU $C839
VEC_MUSIC_WK_6 EQU $C846
STRIP_ZEROS EQU $F8B7
DEC_6_COUNTERS EQU $F55E
Vec_Expl_4 EQU $C85B
Vec_Prev_Btns EQU $C810
Recalibrate EQU $F2E6
DELAY_0 EQU $F579
INIT_OS_RAM EQU $F164
Delay_b EQU $F57A
musicc EQU $FF7A
EXPLOSION_SND EQU $F92E
PRINT_STR EQU $F495
Vec_Loop_Count EQU $C825
MOVETO_IX_FF EQU $F308
CLEAR_SCORE EQU $F84F
Vec_Max_Players EQU $C84F
Rise_Run_Len EQU $F603
VEC_BUTTON_2_3 EQU $C818
PRINT_SHIPS EQU $F393
music2 EQU $FD1D
XFORM_RUN EQU $F65D
Moveto_ix_a EQU $F30E
VEC_NUM_GAME EQU $C87A
MOV_DRAW_VL_B EQU $F3B1
Abs_b EQU $F58B
SOUND_BYTE_X EQU $F259
VEC_LOOP_COUNT EQU $C825
VEC_TEXT_HEIGHT EQU $C82A
VEC_BTN_STATE EQU $C80F
Obj_Will_Hit EQU $F8F3
Vec_Brightness EQU $C827
Vec_FIRQ_Vector EQU $CBF5
VEC_RFRSH_HI EQU $C83E
Delay_2 EQU $F571
Moveto_ix_7F EQU $F30C
Vec_Button_1_1 EQU $C812
Vec_Expl_Timer EQU $C877
Move_Mem_a EQU $F683
INIT_MUSIC_CHK EQU $F687
MOVE_MEM_A EQU $F683
music5 EQU $FE38
Clear_x_d EQU $F548


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
    JSR DRAW_SCALES
    RTS

; Function: DRAW_SCALES (Bank #0)
DRAW_SCALES:
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
