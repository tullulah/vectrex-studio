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
DRAW_RECT_X          EQU $C880+$0E   ; Rectangle X (1 bytes)
DRAW_RECT_Y          EQU $C880+$0F   ; Rectangle Y (1 bytes)
DRAW_RECT_WIDTH      EQU $C880+$10   ; Rectangle width (1 bytes)
DRAW_RECT_HEIGHT     EQU $C880+$11   ; Rectangle height (1 bytes)
DRAW_RECT_INTENSITY  EQU $C880+$12   ; Rectangle intensity (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$13   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$1D   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$1F   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$21   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$22   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$23   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$25   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
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
VEC_JOY_MUX_2_Y EQU $C822
VEC_MUSIC_WK_5 EQU $C847
OBJ_WILL_HIT_U EQU $F8E5
Get_Run_Idx EQU $F5DB
MOV_DRAW_VL_B EQU $F3B1
Reset_Pen EQU $F35B
Draw_VL_b EQU $F3D2
MOD16.M16_DPOS EQU $401D
PRINT_LIST EQU $F38A
Draw_VLcs EQU $F3D6
Vec_Brightness EQU $C827
VEC_DEFAULT_STK EQU $CBEA
Rise_Run_Angle EQU $F593
Moveto_d EQU $F312
VEC_EXPL_3 EQU $C85A
Wait_Recal EQU $F192
MUSIC3 EQU $FD81
Vec_Button_1_2 EQU $C813
Clear_x_256 EQU $F545
DRAW_GRID_VL EQU $FF9F
Rise_Run_Y EQU $F601
Mov_Draw_VLc_a EQU $F3AD
Moveto_d_7F EQU $F2FC
MOVETO_D EQU $F312
Init_OS EQU $F18B
Vec_Music_Freq EQU $C861
Dec_3_Counters EQU $F55A
Vec_Twang_Table EQU $C851
Clear_Sound EQU $F272
Joy_Digital EQU $F1F8
ROT_VL_AB EQU $F610
VEC_RFRSH_LO EQU $C83D
VEC_RFRSH_HI EQU $C83E
OBJ_HIT EQU $F8FF
VEC_RFRSH EQU $C83D
DELAY_B EQU $F57A
CLEAR_X_256 EQU $F545
Vec_Counters EQU $C82E
Joy_Analog EQU $F1F5
RANDOM EQU $F517
Delay_b EQU $F57A
Vec_Dot_Dwell EQU $C828
Vec_Freq_Table EQU $C84D
VEC_JOY_MUX EQU $C81F
musicc EQU $FF7A
musicd EQU $FF8F
Vec_Random_Seed EQU $C87D
musicb EQU $FF62
DO_SOUND EQU $F289
Vec_Expl_1 EQU $C858
music6 EQU $FE76
Dec_6_Counters EQU $F55E
INIT_MUSIC EQU $F68D
MUSICD EQU $FF8F
Xform_Rise_a EQU $F661
RESET0INT EQU $F36B
VEC_COLD_FLAG EQU $CBFE
COLD_START EQU $F000
Vec_IRQ_Vector EQU $CBF8
VEC_HIGH_SCORE EQU $CBEB
Vec_ADSR_Table EQU $C84F
DELAY_2 EQU $F571
DELAY_RTS EQU $F57D
MOV_DRAW_VL EQU $F3BC
Moveto_ix_a EQU $F30E
Vec_Expl_Chans EQU $C854
DRAW_RECT_RUNTIME EQU $4054
Vec_Str_Ptr EQU $C82C
Reset0Ref_D0 EQU $F34A
DRAW_VLP EQU $F410
Vec_Button_1_3 EQU $C814
MOV_DRAW_VL_D EQU $F3BE
Do_Sound_x EQU $F28C
Add_Score_a EQU $F85E
Draw_Pat_VL_a EQU $F434
Draw_VLp_b EQU $F40E
music2 EQU $FD1D
Vec_Joy_Resltn EQU $C81A
Vec_Music_Wk_7 EQU $C845
Vec_Max_Players EQU $C84F
music8 EQU $FEF8
Clear_x_b_80 EQU $F550
VEC_COUNTER_4 EQU $C831
Sound_Byte_x EQU $F259
DRAW_VLCS EQU $F3D6
MOVE_MEM_A_1 EQU $F67F
MOVE_MEM_A EQU $F683
Vec_Joy_Mux_2_X EQU $C821
Vec_Music_Flag EQU $C856
Reset0Ref EQU $F354
ADD_SCORE_D EQU $F87C
Print_Str EQU $F495
Set_Refresh EQU $F1A2
VEC_MUSIC_WK_6 EQU $C846
Init_Music_chk EQU $F687
Move_Mem_a_1 EQU $F67F
Vec_Rise_Index EQU $C839
VEC_FREQ_TABLE EQU $C84D
Vec_Joy_Mux_1_Y EQU $C820
Vec_Music_Twang EQU $C858
Vec_Button_2_3 EQU $C818
Vec_Expl_2 EQU $C859
music3 EQU $FD81
Vec_Misc_Count EQU $C823
MOV_DRAW_VL_AB EQU $F3B7
VEC_TEXT_HW EQU $C82A
Vec_Run_Index EQU $C837
Warm_Start EQU $F06C
Print_Str_yx EQU $F378
VEC_TWANG_TABLE EQU $C851
DEC_3_COUNTERS EQU $F55A
Intensity_3F EQU $F2A1
Print_Ships EQU $F393
VEC_0REF_ENABLE EQU $C824
VEC_EXPL_CHANS EQU $C854
Vec_Music_Wk_6 EQU $C846
Xform_Rise EQU $F663
XFORM_RISE EQU $F663
Sound_Bytes EQU $F27D
VEC_JOY_MUX_1_X EQU $C81F
music9 EQU $FF26
Random_3 EQU $F511
ROT_VL_MODE_A EQU $F61F
VEC_JOY_2_X EQU $C81D
VEC_NUM_PLAYERS EQU $C879
Vec_Music_Wk_5 EQU $C847
Clear_Score EQU $F84F
Dot_here EQU $F2C5
Vec_Max_Games EQU $C850
Sound_Byte EQU $F256
Xform_Run_a EQU $F65B
Dot_d EQU $F2C3
VEC_BUTTON_1_4 EQU $C815
VEC_MISC_COUNT EQU $C823
Vec_Angle EQU $C836
DELAY_3 EQU $F56D
VEC_RISERUN_TMP EQU $C834
Intensity_a EQU $F2AB
VEC_COUNTER_3 EQU $C830
Delay_1 EQU $F575
Dot_ix_b EQU $F2BE
EXPLOSION_SND EQU $F92E
Draw_Pat_VL EQU $F437
DP_to_C8 EQU $F1AF
VEC_PREV_BTNS EQU $C810
Vec_Rfrsh EQU $C83D
CLEAR_X_B_80 EQU $F550
VEC_BUTTON_2_2 EQU $C817
SOUND_BYTES_X EQU $F284
RISE_RUN_X EQU $F5FF
VEC_JOY_1_Y EQU $C81C
Vec_Expl_4 EQU $C85B
Check0Ref EQU $F34F
MUSICA EQU $FF44
music1 EQU $FD0D
READ_BTNS_MASK EQU $F1B4
MUSICC EQU $FF7A
DOT_HERE EQU $F2C5
VEC_MUSIC_WK_1 EQU $C84B
Vec_Seed_Ptr EQU $C87B
INTENSITY_1F EQU $F29D
Vec_Expl_Timer EQU $C877
Rot_VL_Mode EQU $F62B
ROT_VL_MODE EQU $F62B
VEC_IRQ_VECTOR EQU $CBF8
Intensity_1F EQU $F29D
ROT_VL_DFT EQU $F637
Vec_Rfrsh_lo EQU $C83D
Vec_NMI_Vector EQU $CBFB
Get_Rise_Run EQU $F5EF
SELECT_GAME EQU $F7A9
Draw_VL_a EQU $F3DA
VEC_EXPL_TIMER EQU $C877
CLEAR_X_B_A EQU $F552
Vec_Counter_1 EQU $C82E
Moveto_x_7F EQU $F2F2
CLEAR_SCORE EQU $F84F
Clear_x_b_a EQU $F552
MOD16.M16_END EQU $4044
MOVETO_IX_A EQU $F30E
musica EQU $FF44
PRINT_STR_D EQU $F37A
VEC_TEXT_WIDTH EQU $C82B
VEC_MUSIC_FREQ EQU $C861
VEC_MAX_PLAYERS EQU $C84F
Draw_VLp EQU $F410
Vec_Pattern EQU $C829
VEC_LOOP_COUNT EQU $C825
VEC_SEED_PTR EQU $C87B
VEC_EXPL_FLAG EQU $C867
DP_TO_C8 EQU $F1AF
VEC_SWI3_VECTOR EQU $CBF2
JOY_DIGITAL EQU $F1F8
CLEAR_SOUND EQU $F272
VEC_DOT_DWELL EQU $C828
VEC_STR_PTR EQU $C82C
VEC_SND_SHADOW EQU $C800
XFORM_RUN EQU $F65D
Xform_Run EQU $F65D
RESET0REF EQU $F354
Vec_Expl_ChanB EQU $C85D
Vec_Cold_Flag EQU $CBFE
GET_RUN_IDX EQU $F5DB
VEC_BUTTON_2_4 EQU $C819
Vec_Duration EQU $C857
PRINT_STR EQU $F495
SOUND_BYTE_X EQU $F259
VEC_BUTTON_1_2 EQU $C813
DRAW_VL_B EQU $F3D2
DRAW_VLP_FF EQU $F404
Print_List_hw EQU $F385
DRAW_VLC EQU $F3CE
Draw_VLp_7F EQU $F408
VEC_MUSIC_FLAG EQU $C856
Cold_Start EQU $F000
Select_Game EQU $F7A9
Vec_Expl_3 EQU $C85A
VEC_JOY_RESLTN EQU $C81A
Vec_0Ref_Enable EQU $C824
MOVETO_IX EQU $F310
COMPARE_SCORE EQU $F8C7
Abs_b EQU $F58B
music4 EQU $FDD3
DELAY_0 EQU $F579
Vec_Counter_5 EQU $C832
Random EQU $F517
VEC_EXPL_2 EQU $C859
VEC_DURATION EQU $C857
Draw_Line_d EQU $F3DF
Moveto_ix_FF EQU $F308
DRAW_VL_MODE EQU $F46E
Rise_Run_Len EQU $F603
music5 EQU $FE38
NEW_HIGH_SCORE EQU $F8D8
Bitmask_a EQU $F57E
PRINT_STR_HWYX EQU $F373
Vec_Num_Players EQU $C879
Vec_Text_Height EQU $C82A
Vec_Music_Wk_A EQU $C842
JOY_ANALOG EQU $F1F5
VEC_MUSIC_WORK EQU $C83F
VEC_RANDOM_SEED EQU $C87D
VEC_EXPL_4 EQU $C85B
Init_Music_x EQU $F692
VEC_RISERUN_LEN EQU $C83B
PRINT_STR_YX EQU $F378
Vec_Music_Wk_1 EQU $C84B
Abs_a_b EQU $F584
Add_Score_d EQU $F87C
MUSIC7 EQU $FEC6
Init_Music EQU $F68D
Do_Sound EQU $F289
DRAW_VLP_7F EQU $F408
RECALIBRATE EQU $F2E6
VEC_ADSR_TIMERS EQU $C85E
Delay_0 EQU $F579
Init_Music_Buf EQU $F533
Draw_VLp_FF EQU $F404
Vec_Counter_2 EQU $C82F
VEC_MUSIC_CHAN EQU $C855
Intensity_5F EQU $F2A5
Clear_x_b EQU $F53F
Mov_Draw_VL_ab EQU $F3B7
WARM_START EQU $F06C
DELAY_1 EQU $F575
VEC_COUNTER_2 EQU $C82F
Mov_Draw_VLcs EQU $F3B5
MUSIC1 EQU $FD0D
VEC_FIRQ_VECTOR EQU $CBF5
INTENSITY_3F EQU $F2A1
MUSIC6 EQU $FE76
Move_Mem_a EQU $F683
Clear_x_d EQU $F548
RANDOM_3 EQU $F511
Rot_VL_ab EQU $F610
Moveto_ix_7F EQU $F30C
VEC_MUSIC_WK_A EQU $C842
MUSIC9 EQU $FF26
Vec_SWI3_Vector EQU $CBF2
Print_Str_d EQU $F37A
Mov_Draw_VL EQU $F3BC
Sound_Bytes_x EQU $F284
Strip_Zeros EQU $F8B7
Mov_Draw_VL_a EQU $F3B9
Vec_Joy_Mux EQU $C81F
Vec_Button_2_1 EQU $C816
VEC_BUTTON_1_3 EQU $C814
Clear_C8_RAM EQU $F542
DOT_IX EQU $F2C1
Draw_VLp_scale EQU $F40C
VEC_RISE_INDEX EQU $C839
Vec_Joy_Mux_1_X EQU $C81F
VEC_MAX_GAMES EQU $C850
INTENSITY_7F EQU $F2A9
MUSIC4 EQU $FDD3
CLEAR_C8_RAM EQU $F542
INIT_MUSIC_BUF EQU $F533
RESET0REF_D0 EQU $F34A
DRAW_PAT_VL_D EQU $F439
VEC_RUN_INDEX EQU $C837
Vec_Button_1_4 EQU $C815
DRAW_VLP_B EQU $F40E
music7 EQU $FEC6
Vec_Btn_State EQU $C80F
PRINT_SHIPS_X EQU $F391
SOUND_BYTE_RAW EQU $F25B
Vec_Counter_4 EQU $C831
Vec_Music_Chan EQU $C855
Vec_Rfrsh_hi EQU $C83E
SOUND_BYTES EQU $F27D
MOD16.M16_DONE EQU $4053
Dot_ix EQU $F2C1
VEC_TEXT_HEIGHT EQU $C82A
Vec_Text_Width EQU $C82B
PRINT_LIST_CHK EQU $F38C
VEC_BTN_STATE EQU $C80F
DRAW_VL_A EQU $F3DA
DP_to_D0 EQU $F1AA
Compare_Score EQU $F8C7
RESET_PEN EQU $F35B
VEC_BRIGHTNESS EQU $C827
MOVETO_IX_FF EQU $F308
OBJ_WILL_HIT EQU $F8F3
MOVETO_X_7F EQU $F2F2
Delay_3 EQU $F56D
STRIP_ZEROS EQU $F8B7
VEC_JOY_MUX_1_Y EQU $C820
DRAW_VL EQU $F3DD
XFORM_RUN_A EQU $F65B
Vec_SWI2_Vector EQU $CBF2
Vec_Counter_6 EQU $C833
Rot_VL_dft EQU $F637
VEC_EXPL_CHAN EQU $C85C
ABS_A_B EQU $F584
Vec_Joy_2_X EQU $C81D
VEC_EXPL_1 EQU $C858
VEC_COUNTER_5 EQU $C832
VEC_SWI_VECTOR EQU $CBFB
Vec_Joy_2_Y EQU $C81E
Init_VIA EQU $F14C
DOT_IX_B EQU $F2BE
MOVETO_IX_7F EQU $F30C
Vec_Default_Stk EQU $CBEA
WAIT_RECAL EQU $F192
MOVETO_D_7F EQU $F2FC
Draw_VL_mode EQU $F46E
ABS_B EQU $F58B
CHECK0REF EQU $F34F
DOT_LIST_RESET EQU $F2DE
Vec_SWI_Vector EQU $CBFB
Obj_Will_Hit EQU $F8F3
Vec_Expl_Chan EQU $C85C
VEC_COUNTER_1 EQU $C82E
DRAW_PAT_VL_A EQU $F434
Vec_RiseRun_Len EQU $C83B
Vec_Music_Work EQU $C83F
VEC_SWI2_VECTOR EQU $CBF2
CLEAR_X_D EQU $F548
Draw_VLc EQU $F3CE
MOV_DRAW_VLCS EQU $F3B5
Vec_Button_1_1 EQU $C812
MOV_DRAW_VL_A EQU $F3B9
INTENSITY_A EQU $F2AB
Vec_Music_Ptr EQU $C853
VEC_COUNTER_6 EQU $C833
Vec_Num_Game EQU $C87A
RISE_RUN_ANGLE EQU $F593
MUSIC2 EQU $FD1D
VEC_BUTTON_1_1 EQU $C812
SOUND_BYTE EQU $F256
DEC_COUNTERS EQU $F563
DRAW_PAT_VL EQU $F437
GET_RISE_RUN EQU $F5EF
Obj_Hit EQU $F8FF
XFORM_RISE_A EQU $F661
Vec_Counter_3 EQU $C830
Vec_Joy_1_X EQU $C81B
Vec_Buttons EQU $C811
Explosion_Snd EQU $F92E
Print_Str_hwyx EQU $F373
MOV_DRAW_VLC_A EQU $F3AD
Vec_Joy_1_Y EQU $C81C
BITMASK_A EQU $F57E
Moveto_ix EQU $F310
Vec_Loop_Count EQU $C825
Recalibrate EQU $F2E6
Draw_Pat_VL_d EQU $F439
Vec_High_Score EQU $CBEB
Vec_Joy_Mux_2_Y EQU $C822
MUSIC8 EQU $FEF8
Rot_VL_Mode_a EQU $F61F
READ_BTNS EQU $F1BA
Dot_List EQU $F2D5
Draw_VL_ab EQU $F3D8
MOD16.M16_LOOP EQU $4034
Print_List EQU $F38A
DO_SOUND_X EQU $F28C
VEC_JOY_1_X EQU $C81B
VEC_BUTTON_2_1 EQU $C816
Mov_Draw_VL_b EQU $F3B1
DRAW_VL_AB EQU $F3D8
New_High_Score EQU $F8D8
RISE_RUN_LEN EQU $F603
RISE_RUN_Y EQU $F601
VEC_MUSIC_WK_7 EQU $C845
Read_Btns EQU $F1BA
Sound_Byte_raw EQU $F25B
VEC_NUM_GAME EQU $C87A
Vec_ADSR_Timers EQU $C85E
VEC_JOY_2_Y EQU $C81E
Vec_Button_2_4 EQU $C819
MOD16.M16_RPOS EQU $4034
Intensity_7F EQU $F2A9
GET_RISE_IDX EQU $F5D9
Dec_Counters EQU $F563
Delay_2 EQU $F571
Vec_Prev_Btns EQU $C810
Get_Rise_Idx EQU $F5D9
CLEAR_X_B EQU $F53F
Init_OS_RAM EQU $F164
Draw_Grid_VL EQU $FF9F
Obj_Will_Hit_u EQU $F8E5
DEC_6_COUNTERS EQU $F55E
VEC_MUSIC_PTR EQU $C853
Vec_RiseRun_Tmp EQU $C834
VEC_ANGLE EQU $C836
VEC_NMI_VECTOR EQU $CBFB
DP_TO_D0 EQU $F1AA
MOD16.M16_RCHECK EQU $4025
MUSICB EQU $FF62
ROT_VL EQU $F616
VEC_EXPL_CHANB EQU $C85D
PRINT_LIST_HW EQU $F385
Vec_FIRQ_Vector EQU $CBF5
Vec_Snd_Shadow EQU $C800
DOT_LIST EQU $F2D5
INIT_VIA EQU $F14C
VEC_MUSIC_TWANG EQU $C858
VEC_ADSR_TABLE EQU $C84F
Vec_Text_HW EQU $C82A
Rise_Run_X EQU $F5FF
VEC_COUNTERS EQU $C82E
Read_Btns_Mask EQU $F1B4
Vec_Expl_Flag EQU $C867
INIT_OS EQU $F18B
DRAW_LINE_D EQU $F3DF
VEC_BUTTONS EQU $C811
VEC_PATTERN EQU $C829
INTENSITY_5F EQU $F2A5
DOT_D EQU $F2C3
VEC_JOY_MUX_2_X EQU $C821
Vec_Button_2_2 EQU $C817
MUSIC5 EQU $FE38
Reset0Int EQU $F36B
Dot_List_Reset EQU $F2DE
Draw_VL EQU $F3DD
MOD16 EQU $4000
VEC_BUTTON_2_3 EQU $C818
VEC_EXPL_CHANA EQU $C853
ADD_SCORE_A EQU $F85E
Vec_Expl_ChanA EQU $C853
DRAW_VLP_SCALE EQU $F40C
Print_Ships_x EQU $F391
Mov_Draw_VL_d EQU $F3BE
Delay_RTS EQU $F57D
INIT_MUSIC_CHK EQU $F687
Print_List_chk EQU $F38C
PRINT_SHIPS EQU $F393
INIT_MUSIC_X EQU $F692
SET_REFRESH EQU $F1A2
INIT_OS_RAM EQU $F164
Rot_VL EQU $F616


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "DRAW_RECT"
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
DRAW_RECT_X          EQU $C880+$0E   ; Rectangle X (1 bytes)
DRAW_RECT_Y          EQU $C880+$0F   ; Rectangle Y (1 bytes)
DRAW_RECT_WIDTH      EQU $C880+$10   ; Rectangle width (1 bytes)
DRAW_RECT_HEIGHT     EQU $C880+$11   ; Rectangle height (1 bytes)
DRAW_RECT_INTENSITY  EQU $C880+$12   ; Rectangle intensity (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$13   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$1D   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$1F   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$21   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$22   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$23   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$25   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
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
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$50
    JSR Intensity_a
    LDA #$D8
    LDB #$B0
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$50
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$E2
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$B0
    LDB #$00
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
    LDA #$D8
    LDB #$32
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$50
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$E2
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$B0
    LDB #$00
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
    LDA #$F1
    LDB #$F1
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$1E
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$E2
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$E2
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8
    LDD #0
    STD RESULT
    RTS


; ================================================
