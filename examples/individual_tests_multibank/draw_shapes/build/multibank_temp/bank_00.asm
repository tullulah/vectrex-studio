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
TEXT_SCALE_H         EQU $C880+$22   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$23   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
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
MOV_DRAW_VL_D EQU $F3BE
Init_OS_RAM EQU $F164
DRAW_PAT_VL_D EQU $F439
Moveto_ix_a EQU $F30E
INTENSITY_7F EQU $F2A9
Vec_Joy_1_X EQU $C81B
VEC_TWANG_TABLE EQU $C851
VEC_EXPL_1 EQU $C858
Vec_Max_Games EQU $C850
Abs_a_b EQU $F584
DO_SOUND_X EQU $F28C
VEC_JOY_2_Y EQU $C81E
Vec_RiseRun_Len EQU $C83B
DP_to_C8 EQU $F1AF
Obj_Will_Hit_u EQU $F8E5
ROT_VL_MODE EQU $F62B
VEC_COUNTERS EQU $C82E
Delay_2 EQU $F571
VEC_BUTTON_1_2 EQU $C813
VEC_BRIGHTNESS EQU $C827
Vec_Expl_Flag EQU $C867
MUSIC9 EQU $FF26
VEC_COUNTER_2 EQU $C82F
music8 EQU $FEF8
DRAW_VLP_7F EQU $F408
RISE_RUN_X EQU $F5FF
Vec_Num_Players EQU $C879
Moveto_ix EQU $F310
Dec_3_Counters EQU $F55A
Recalibrate EQU $F2E6
Rise_Run_X EQU $F5FF
Xform_Run_a EQU $F65B
Obj_Will_Hit EQU $F8F3
VEC_FIRQ_VECTOR EQU $CBF5
VEC_RFRSH_LO EQU $C83D
VEC_NUM_PLAYERS EQU $C879
music2 EQU $FD1D
Vec_Joy_Mux_2_X EQU $C821
PRINT_TEXT_STR_66062444 EQU $4092
Vec_RiseRun_Tmp EQU $C834
INTENSITY_3F EQU $F2A1
Draw_VL_mode EQU $F46E
SOUND_BYTES EQU $F27D
SOUND_BYTE_X EQU $F259
DOT_LIST EQU $F2D5
musicb EQU $FF62
MOD16.M16_RPOS EQU $4064
Draw_Line_d EQU $F3DF
VEC_MAX_PLAYERS EQU $C84F
Vec_Max_Players EQU $C84F
New_High_Score EQU $F8D8
NEW_HIGH_SCORE EQU $F8D8
JOY_ANALOG EQU $F1F5
Move_Mem_a_1 EQU $F67F
MOD16.M16_LOOP EQU $4064
Vec_Num_Game EQU $C87A
SELECT_GAME EQU $F7A9
Draw_VLp_FF EQU $F404
VEC_MUSIC_TWANG EQU $C858
VEC_EXPL_CHANB EQU $C85D
VEC_COUNTER_3 EQU $C830
Vec_Button_1_2 EQU $C813
DP_TO_C8 EQU $F1AF
MUSICC EQU $FF7A
INIT_MUSIC_CHK EQU $F687
VEC_MISC_COUNT EQU $C823
MUSICD EQU $FF8F
DRAW_VLC EQU $F3CE
DOT_D EQU $F2C3
VEC_RFRSH_HI EQU $C83E
Vec_Random_Seed EQU $C87D
DRAW_PAT_VL EQU $F437
Draw_VL_ab EQU $F3D8
Vec_Music_Chan EQU $C855
Draw_VL_b EQU $F3D2
musicc EQU $FF7A
Vec_Btn_State EQU $C80F
Init_Music EQU $F68D
music3 EQU $FD81
Vec_Joy_2_Y EQU $C81E
Vec_Counter_4 EQU $C831
Vec_Button_2_4 EQU $C819
Vec_Music_Wk_1 EQU $C84B
Sound_Bytes_x EQU $F284
DRAW_VL_B EQU $F3D2
VEC_BUTTON_1_4 EQU $C815
Vec_Joy_2_X EQU $C81D
Vec_Music_Freq EQU $C861
SOUND_BYTES_X EQU $F284
VEC_IRQ_VECTOR EQU $CBF8
VEC_SEED_PTR EQU $C87B
RANDOM_3 EQU $F511
Sound_Bytes EQU $F27D
Mov_Draw_VLcs EQU $F3B5
Clear_Sound EQU $F272
VEC_JOY_1_Y EQU $C81C
MOV_DRAW_VL_B EQU $F3B1
VEC_MUSIC_CHAN EQU $C855
Dot_ix_b EQU $F2BE
Mov_Draw_VL_a EQU $F3B9
READ_BTNS EQU $F1BA
VEC_EXPL_2 EQU $C859
VEC_JOY_MUX_1_X EQU $C81F
Vec_NMI_Vector EQU $CBFB
Rise_Run_Y EQU $F601
Dot_ix EQU $F2C1
VEC_NUM_GAME EQU $C87A
GET_RUN_IDX EQU $F5DB
Vec_Text_Width EQU $C82B
Vec_SWI3_Vector EQU $CBF2
Draw_VLcs EQU $F3D6
Compare_Score EQU $F8C7
CLEAR_SCORE EQU $F84F
VEC_COUNTER_4 EQU $C831
MOVETO_D_7F EQU $F2FC
Mov_Draw_VL_b EQU $F3B1
Print_List_chk EQU $F38C
Intensity_a EQU $F2AB
PRINT_STR_HWYX EQU $F373
Draw_Pat_VL_a EQU $F434
MUSIC1 EQU $FD0D
PRINT_TEXT_STR_2461644 EQU $408D
Delay_1 EQU $F575
CLEAR_SOUND EQU $F272
Moveto_d EQU $F312
Draw_VLp_scale EQU $F40C
INIT_MUSIC_X EQU $F692
Dot_here EQU $F2C5
Vec_Text_Height EQU $C82A
Vec_Music_Wk_7 EQU $C845
Rot_VL_ab EQU $F610
GET_RISE_IDX EQU $F5D9
VEC_COUNTER_6 EQU $C833
VEC_DOT_DWELL EQU $C828
READ_BTNS_MASK EQU $F1B4
VEC_MAX_GAMES EQU $C850
Random_3 EQU $F511
VEC_PATTERN EQU $C829
Print_List EQU $F38A
DELAY_3 EQU $F56D
Strip_Zeros EQU $F8B7
VEC_JOY_RESLTN EQU $C81A
Intensity_5F EQU $F2A5
Vec_Counter_2 EQU $C82F
DRAW_VLP_B EQU $F40E
MOV_DRAW_VLC_A EQU $F3AD
SOUND_BYTE EQU $F256
VECTREX_PRINT_TEXT EQU $4000
Reset_Pen EQU $F35B
MOV_DRAW_VL_AB EQU $F3B7
Wait_Recal EQU $F192
Delay_b EQU $F57A
Vec_Counter_5 EQU $C832
Dot_d EQU $F2C3
DEC_6_COUNTERS EQU $F55E
DRAW_VLP_SCALE EQU $F40C
CLEAR_X_256 EQU $F545
DELAY_1 EQU $F575
VEC_DEFAULT_STK EQU $CBEA
XFORM_RUN EQU $F65D
WARM_START EQU $F06C
DOT_HERE EQU $F2C5
MUSICA EQU $FF44
Vec_Counter_3 EQU $C830
Vec_Rise_Index EQU $C839
Vec_Music_Work EQU $C83F
Warm_Start EQU $F06C
MOD16.M16_DONE EQU $4083
Joy_Analog EQU $F1F5
VEC_FREQ_TABLE EQU $C84D
music9 EQU $FF26
XFORM_RUN_A EQU $F65B
PRINT_LIST EQU $F38A
Draw_Pat_VL_d EQU $F439
VEC_BUTTON_1_1 EQU $C812
Vec_SWI2_Vector EQU $CBF2
VEC_SND_SHADOW EQU $C800
Draw_VLc EQU $F3CE
PRINT_LIST_CHK EQU $F38C
PRINT_LIST_HW EQU $F385
Draw_VLp EQU $F410
Vec_Counter_6 EQU $C833
Xform_Rise EQU $F663
Vec_FIRQ_Vector EQU $CBF5
ROT_VL EQU $F616
Vec_Counter_1 EQU $C82E
STRIP_ZEROS EQU $F8B7
Vec_High_Score EQU $CBEB
MOD16.M16_END EQU $4074
Intensity_3F EQU $F2A1
Dot_List EQU $F2D5
VEC_SWI_VECTOR EQU $CBFB
Moveto_ix_FF EQU $F308
Clear_x_b_80 EQU $F550
RESET0REF_D0 EQU $F34A
Vec_Expl_4 EQU $C85B
VEC_EXPL_4 EQU $C85B
DP_TO_D0 EQU $F1AA
PRINT_SHIPS_X EQU $F391
VEC_MUSIC_WK_7 EQU $C845
Vec_Misc_Count EQU $C823
VEC_SWI3_VECTOR EQU $CBF2
Obj_Hit EQU $F8FF
VEC_MUSIC_WK_6 EQU $C846
Vec_Button_1_3 EQU $C814
Vec_Str_Ptr EQU $C82C
Bitmask_a EQU $F57E
Move_Mem_a EQU $F683
Init_OS EQU $F18B
DOT_IX EQU $F2C1
Print_Str_hwyx EQU $F373
Vec_Music_Wk_6 EQU $C846
MOV_DRAW_VL EQU $F3BC
Init_VIA EQU $F14C
Vec_Dot_Dwell EQU $C828
Vec_Button_2_1 EQU $C816
OBJ_WILL_HIT_U EQU $F8E5
Rise_Run_Len EQU $F603
MOVETO_IX_A EQU $F30E
INIT_OS EQU $F18B
VEC_NMI_VECTOR EQU $CBFB
DEC_3_COUNTERS EQU $F55A
Vec_Joy_Resltn EQU $C81A
DP_to_D0 EQU $F1AA
ABS_B EQU $F58B
Vec_Expl_Chans EQU $C854
MUSIC7 EQU $FEC6
DEC_COUNTERS EQU $F563
ADD_SCORE_A EQU $F85E
Draw_Grid_VL EQU $FF9F
Clear_C8_RAM EQU $F542
Draw_VL_a EQU $F3DA
Moveto_ix_7F EQU $F30C
INTENSITY_A EQU $F2AB
Moveto_d_7F EQU $F2FC
Read_Btns_Mask EQU $F1B4
RISE_RUN_Y EQU $F601
Vec_Expl_ChanA EQU $C853
Mov_Draw_VL_d EQU $F3BE
DRAW_VLP EQU $F410
MOD16.M16_RCHECK EQU $4055
Vec_Snd_Shadow EQU $C800
ADD_SCORE_D EQU $F87C
Draw_VLp_b EQU $F40E
Vec_Pattern EQU $C829
DO_SOUND EQU $F289
Vec_ADSR_Table EQU $C84F
DRAW_VLP_FF EQU $F404
Add_Score_a EQU $F85E
DELAY_0 EQU $F579
COLD_START EQU $F000
Vec_Rfrsh_lo EQU $C83D
DRAW_VL_AB EQU $F3D8
MOVETO_X_7F EQU $F2F2
VEC_BUTTONS EQU $C811
MOD16 EQU $4030
OBJ_HIT EQU $F8FF
INIT_MUSIC_BUF EQU $F533
Intensity_7F EQU $F2A9
VEC_STR_PTR EQU $C82C
VEC_EXPL_TIMER EQU $C877
RESET_PEN EQU $F35B
VEC_EXPL_3 EQU $C85A
VEC_MUSIC_FREQ EQU $C861
DELAY_2 EQU $F571
DELAY_RTS EQU $F57D
Print_Str EQU $F495
Vec_Seed_Ptr EQU $C87B
Explosion_Snd EQU $F92E
VEC_JOY_MUX_2_X EQU $C821
MOVETO_IX EQU $F310
VEC_JOY_1_X EQU $C81B
Get_Run_Idx EQU $F5DB
Vec_Expl_1 EQU $C858
Vec_Freq_Table EQU $C84D
VEC_COUNTER_5 EQU $C832
Vec_0Ref_Enable EQU $C824
XFORM_RISE_A EQU $F661
Vec_Run_Index EQU $C837
Sound_Byte_x EQU $F259
MOV_DRAW_VL_A EQU $F3B9
music5 EQU $FE38
Print_Ships_x EQU $F391
CHECK0REF EQU $F34F
XFORM_RISE EQU $F663
RISE_RUN_LEN EQU $F603
VEC_RISE_INDEX EQU $C839
WAIT_RECAL EQU $F192
Get_Rise_Idx EQU $F5D9
Vec_Music_Ptr EQU $C853
Reset0Int EQU $F36B
Rot_VL_Mode EQU $F62B
Delay_0 EQU $F579
Dec_Counters EQU $F563
Random EQU $F517
VEC_COLD_FLAG EQU $CBFE
Draw_VL EQU $F3DD
Vec_Button_1_4 EQU $C815
MOVE_MEM_A EQU $F683
PRINT_TEXT_STR_2157955 EQU $4088
MUSIC3 EQU $FD81
Init_Music_x EQU $F692
Moveto_x_7F EQU $F2F2
INIT_MUSIC EQU $F68D
MOD16.M16_DPOS EQU $404D
Vec_Music_Wk_5 EQU $C847
VEC_JOY_MUX_1_Y EQU $C820
Rise_Run_Angle EQU $F593
Intensity_1F EQU $F29D
MUSIC4 EQU $FDD3
MOVETO_IX_7F EQU $F30C
VEC_TEXT_HEIGHT EQU $C82A
MUSIC2 EQU $FD1D
Vec_Twang_Table EQU $C851
MUSIC8 EQU $FEF8
music7 EQU $FEC6
music1 EQU $FD0D
VEC_EXPL_FLAG EQU $C867
Vec_Joy_Mux_1_Y EQU $C820
Check0Ref EQU $F34F
RANDOM EQU $F517
Xform_Run EQU $F65D
Vec_Buttons EQU $C811
MOVETO_IX_FF EQU $F308
Vec_Rfrsh EQU $C83D
Joy_Digital EQU $F1F8
SOUND_BYTE_RAW EQU $F25B
RECALIBRATE EQU $F2E6
Vec_Button_1_1 EQU $C812
Get_Rise_Run EQU $F5EF
DOT_LIST_RESET EQU $F2DE
VEC_ADSR_TABLE EQU $C84F
Vec_IRQ_Vector EQU $CBF8
musicd EQU $FF8F
MOV_DRAW_VLCS EQU $F3B5
Vec_Text_HW EQU $C82A
RESET0INT EQU $F36B
VEC_MUSIC_PTR EQU $C853
Delay_RTS EQU $F57D
Rot_VL_dft EQU $F637
VEC_0REF_ENABLE EQU $C824
Print_Ships EQU $F393
DRAW_VL EQU $F3DD
VEC_RFRSH EQU $C83D
OBJ_WILL_HIT EQU $F8F3
Clear_x_b_a EQU $F552
VEC_HIGH_SCORE EQU $CBEB
Vec_ADSR_Timers EQU $C85E
VEC_ANGLE EQU $C836
Vec_Expl_2 EQU $C859
VEC_MUSIC_WK_1 EQU $C84B
VEC_JOY_MUX EQU $C81F
Vec_Expl_Timer EQU $C877
Vec_Expl_Chan EQU $C85C
Sound_Byte EQU $F256
VEC_LOOP_COUNT EQU $C825
Vec_SWI_Vector EQU $CBFB
VEC_RISERUN_LEN EQU $C83B
MOVE_MEM_A_1 EQU $F67F
Mov_Draw_VLc_a EQU $F3AD
Sound_Byte_raw EQU $F25B
VEC_DURATION EQU $C857
Vec_Angle EQU $C836
Abs_b EQU $F58B
ROT_VL_AB EQU $F610
VEC_BUTTON_2_2 EQU $C817
GET_RISE_RUN EQU $F5EF
DRAW_PAT_VL_A EQU $F434
Draw_Pat_VL EQU $F437
VEC_RANDOM_SEED EQU $C87D
Do_Sound_x EQU $F28C
Select_Game EQU $F7A9
VEC_SWI2_VECTOR EQU $CBF2
PRINT_STR EQU $F495
Vec_Expl_ChanB EQU $C85D
VEC_EXPL_CHAN EQU $C85C
Print_List_hw EQU $F385
VEC_BTN_STATE EQU $C80F
Dot_List_Reset EQU $F2DE
Clear_Score EQU $F84F
Add_Score_d EQU $F87C
Clear_x_d EQU $F548
Vec_Joy_Mux_1_X EQU $C81F
Vec_Cold_Flag EQU $CBFE
Vec_Expl_3 EQU $C85A
Cold_Start EQU $F000
INIT_VIA EQU $F14C
VEC_PREV_BTNS EQU $C810
Mov_Draw_VL_ab EQU $F3B7
Vec_Music_Flag EQU $C856
INIT_OS_RAM EQU $F164
PRINT_TEXT_STR_65074 EQU $4084
CLEAR_X_B EQU $F53F
Reset0Ref EQU $F354
VEC_RISERUN_TMP EQU $C834
Print_Str_d EQU $F37A
Vec_Music_Twang EQU $C858
Vec_Prev_Btns EQU $C810
Vec_Rfrsh_hi EQU $C83E
MUSIC6 EQU $FE76
VEC_MUSIC_FLAG EQU $C856
Vec_Button_2_3 EQU $C818
COMPARE_SCORE EQU $F8C7
PRINT_STR_D EQU $F37A
Do_Sound EQU $F289
SET_REFRESH EQU $F1A2
VEC_COUNTER_1 EQU $C82E
ROT_VL_DFT EQU $F637
Init_Music_chk EQU $F687
Reset0Ref_D0 EQU $F34A
Vec_Brightness EQU $C827
VEC_JOY_MUX_2_Y EQU $C822
EXPLOSION_SND EQU $F92E
Rot_VL_Mode_a EQU $F61F
VEC_BUTTON_2_4 EQU $C819
Vec_Joy_Mux EQU $C81F
RISE_RUN_ANGLE EQU $F593
VEC_BUTTON_2_3 EQU $C818
VEC_MUSIC_WK_A EQU $C842
musica EQU $FF44
Clear_x_256 EQU $F545
DRAW_VLCS EQU $F3D6
Vec_Default_Stk EQU $CBEA
CLEAR_X_B_A EQU $F552
VEC_TEXT_HW EQU $C82A
VEC_MUSIC_WK_5 EQU $C847
DRAW_LINE_D EQU $F3DF
INTENSITY_5F EQU $F2A5
DRAW_VL_A EQU $F3DA
DRAW_GRID_VL EQU $FF9F
Vec_Counters EQU $C82E
MUSICB EQU $FF62
Vec_Joy_1_Y EQU $C81C
Xform_Rise_a EQU $F661
Clear_x_b EQU $F53F
Vec_Joy_Mux_2_Y EQU $C822
VEC_JOY_2_X EQU $C81D
Dec_6_Counters EQU $F55E
JOY_DIGITAL EQU $F1F8
Rot_VL EQU $F616
Delay_3 EQU $F56D
Read_Btns EQU $F1BA
ROT_VL_MODE_A EQU $F61F
Init_Music_Buf EQU $F533
CLEAR_X_D EQU $F548
Vec_Button_2_2 EQU $C817
CLEAR_X_B_80 EQU $F550
Mov_Draw_VL EQU $F3BC
DELAY_B EQU $F57A
music4 EQU $FDD3
BITMASK_A EQU $F57E
DRAW_VL_MODE EQU $F46E
Draw_VLp_7F EQU $F408
MOVETO_D EQU $F312
MUSIC5 EQU $FE38
RESET0REF EQU $F354
VEC_EXPL_CHANS EQU $C854
Vec_Music_Wk_A EQU $C842
VEC_TEXT_WIDTH EQU $C82B
PRINT_SHIPS EQU $F393
Vec_Duration EQU $C857
ABS_A_B EQU $F584
VEC_BUTTON_1_3 EQU $C814
Print_Str_yx EQU $F378
VEC_RUN_INDEX EQU $C837
VEC_ADSR_TIMERS EQU $C85E
Set_Refresh EQU $F1A2
INTENSITY_1F EQU $F29D
music6 EQU $FE76
PRINT_STR_YX EQU $F378
VEC_MUSIC_WORK EQU $C83F
CLEAR_C8_RAM EQU $F542
DOT_IX_B EQU $F2BE
VEC_BUTTON_2_1 EQU $C816
VEC_EXPL_CHANA EQU $C853
Vec_Loop_Count EQU $C825


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "SHAPES"
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
TEXT_SCALE_H         EQU $C880+$22   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$23   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
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
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$50
    JSR Intensity_a
    LDA #$32
    LDB #$CE
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$14
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$14
    LDB #$F6
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$EC
    LDB #$F6
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8
    LDD #0
    STD RESULT
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$50
    JSR Intensity_a
    LDA #$32
    LDB #$1E
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$E2
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$E2
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$E2
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$E2
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$E2
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$E2
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$E2
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$E2
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$E2
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$E2
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$E2
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$E2
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$E2
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$E2
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$E2
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$E2
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$E2
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$E2
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$E2
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8
    LDD #0
    STD RESULT
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$50
    JSR Intensity_a
    LDA #$E2
    LDB #$F1
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$04
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$04
    LDB #$FC
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$FB
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$F9
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FA
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FA
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$F9
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FB
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FC
    LDB #$FC
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FC
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FC
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FC
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$04
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$05
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$07
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$06
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$06
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$07
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$05
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$04
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$04
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$04
    LDB #$01
    JSR Draw_Line_d
    LDD #0
    STD RESULT
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$50
    JSR Intensity_a
    LDA #$E2
    LDB #$3C
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$08
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$06
    LDB #$FC
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$04
    LDB #$FA
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
    LDB #$FA
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FA
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
    LDA #$FA
    LDB #$04
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FC
    LDB #$06
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$08
    JSR Draw_Line_d
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD VAR_ARG0
    LDD #95
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2461644      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #20
    STD VAR_ARG0
    LDD #95
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2157955      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD VAR_ARG0
    LDD #10
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_66062444      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #20
    STD VAR_ARG0
    LDD #10
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_65074      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    RTS


; ================================================
