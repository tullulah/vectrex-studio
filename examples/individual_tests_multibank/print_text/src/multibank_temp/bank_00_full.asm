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
DRAW_GRID_VL EQU $FF9F
VEC_TEXT_WIDTH EQU $C82B
JOY_DIGITAL EQU $F1F8
DP_to_D0 EQU $F1AA
Draw_VL_a EQU $F3DA
VEC_BUTTON_1_2 EQU $C813
Vec_Seed_Ptr EQU $C87B
Draw_VLc EQU $F3CE
DRAW_PAT_VL_A EQU $F434
Mov_Draw_VL_b EQU $F3B1
Mov_Draw_VLc_a EQU $F3AD
Dot_List_Reset EQU $F2DE
DEC_COUNTERS EQU $F563
COLD_START EQU $F000
music6 EQU $FE76
RESET_PEN EQU $F35B
VEC_HIGH_SCORE EQU $CBEB
Vec_Music_Ptr EQU $C853
Intensity_a EQU $F2AB
DOT_IX_B EQU $F2BE
Vec_Duration EQU $C857
Draw_VLp_b EQU $F40E
Clear_x_256 EQU $F545
INIT_MUSIC_X EQU $F692
VEC_MAX_GAMES EQU $C850
Vec_Angle EQU $C836
Vec_Button_1_2 EQU $C813
RISE_RUN_LEN EQU $F603
Print_List_hw EQU $F385
Delay_3 EQU $F56D
MOV_DRAW_VL_D EQU $F3BE
NEW_HIGH_SCORE EQU $F8D8
MUSIC2 EQU $FD1D
VEC_BUTTON_1_3 EQU $C814
Vec_Button_2_4 EQU $C819
VEC_ANGLE EQU $C836
Vec_RiseRun_Len EQU $C83B
Select_Game EQU $F7A9
Vec_Text_Height EQU $C82A
DELAY_3 EQU $F56D
MOD16.M16_RCHECK EQU $4055
VEC_BUTTON_2_1 EQU $C816
ROT_VL_AB EQU $F610
Set_Refresh EQU $F1A2
Xform_Rise_a EQU $F661
ROT_VL_DFT EQU $F637
VEC_TEXT_HW EQU $C82A
MUSICD EQU $FF8F
SOUND_BYTE_RAW EQU $F25B
XFORM_RUN EQU $F65D
VEC_JOY_MUX_2_X EQU $C821
Vec_IRQ_Vector EQU $CBF8
Reset_Pen EQU $F35B
Draw_VLp_7F EQU $F408
MOVETO_IX_FF EQU $F308
VEC_MISC_COUNT EQU $C823
DRAW_PAT_VL EQU $F437
Abs_b EQU $F58B
Init_Music EQU $F68D
Vec_Button_2_1 EQU $C816
Vec_Expl_3 EQU $C85A
VEC_DURATION EQU $C857
Read_Btns_Mask EQU $F1B4
ADD_SCORE_D EQU $F87C
VEC_BRIGHTNESS EQU $C827
Dec_Counters EQU $F563
VEC_PATTERN EQU $C829
VEC_BUTTONS EQU $C811
OBJ_WILL_HIT EQU $F8F3
Do_Sound_x EQU $F28C
MUSIC5 EQU $FE38
COMPARE_SCORE EQU $F8C7
Delay_1 EQU $F575
Vec_Button_1_1 EQU $C812
Dot_List EQU $F2D5
ROT_VL_MODE_A EQU $F61F
VEC_COLD_FLAG EQU $CBFE
Sound_Byte EQU $F256
VEC_PREV_BTNS EQU $C810
DELAY_1 EQU $F575
VEC_MAX_PLAYERS EQU $C84F
Vec_Cold_Flag EQU $CBFE
Draw_VL_b EQU $F3D2
Vec_Music_Wk_7 EQU $C845
CLEAR_X_B EQU $F53F
Wait_Recal EQU $F192
CLEAR_SCORE EQU $F84F
Xform_Run_a EQU $F65B
VEC_JOY_1_X EQU $C81B
INTENSITY_7F EQU $F2A9
INIT_MUSIC EQU $F68D
Draw_Line_d EQU $F3DF
VEC_JOY_2_X EQU $C81D
Delay_0 EQU $F579
MOVETO_X_7F EQU $F2F2
SET_REFRESH EQU $F1A2
RESET0REF EQU $F354
RESET0REF_D0 EQU $F34A
DP_TO_D0 EQU $F1AA
musicd EQU $FF8F
VEC_MUSIC_WK_1 EQU $C84B
Rot_VL_Mode EQU $F62B
Abs_a_b EQU $F584
Get_Rise_Idx EQU $F5D9
Draw_VLp_FF EQU $F404
CLEAR_X_B_80 EQU $F550
Obj_Hit EQU $F8FF
GET_RISE_RUN EQU $F5EF
PRINT_STR_YX EQU $F378
Draw_VLp_scale EQU $F40C
Clear_x_b_80 EQU $F550
VEC_EXPL_CHAN EQU $C85C
Vec_Joy_2_X EQU $C81D
VEC_SWI2_VECTOR EQU $CBF2
Vec_SWI2_Vector EQU $CBF2
Sound_Bytes_x EQU $F284
Vec_Twang_Table EQU $C851
Vec_Music_Wk_6 EQU $C846
VEC_SWI3_VECTOR EQU $CBF2
INTENSITY_A EQU $F2AB
Clear_x_d EQU $F548
Intensity_1F EQU $F29D
Move_Mem_a EQU $F683
Vec_0Ref_Enable EQU $C824
RISE_RUN_ANGLE EQU $F593
Dec_6_Counters EQU $F55E
Add_Score_d EQU $F87C
DELAY_0 EQU $F579
Print_List EQU $F38A
MUSIC9 EQU $FF26
MUSICC EQU $FF7A
VEC_COUNTER_6 EQU $C833
Get_Rise_Run EQU $F5EF
JOY_ANALOG EQU $F1F5
MOV_DRAW_VLC_A EQU $F3AD
Vec_Pattern EQU $C829
PRINT_LIST EQU $F38A
PRINT_SHIPS EQU $F393
Sound_Byte_raw EQU $F25B
Vec_Music_Freq EQU $C861
PRINT_TEXT_STR_82781042 EQU $408A
CHECK0REF EQU $F34F
VEC_MUSIC_WK_6 EQU $C846
PRINT_STR EQU $F495
DRAW_VLP_7F EQU $F408
VEC_BUTTON_1_4 EQU $C815
MOVETO_D EQU $F312
MOVETO_IX EQU $F310
Vec_Max_Games EQU $C850
Vec_Music_Work EQU $C83F
VEC_RUN_INDEX EQU $C837
VEC_JOY_MUX EQU $C81F
Add_Score_a EQU $F85E
Intensity_3F EQU $F2A1
Random EQU $F517
Vec_Freq_Table EQU $C84D
PRINT_SHIPS_X EQU $F391
Vec_Music_Chan EQU $C855
MOVETO_IX_A EQU $F30E
DRAW_VL_MODE EQU $F46E
GET_RISE_IDX EQU $F5D9
New_High_Score EQU $F8D8
Mov_Draw_VL_d EQU $F3BE
VECTREX_PRINT_TEXT EQU $4000
Moveto_ix_7F EQU $F30C
VEC_STR_PTR EQU $C82C
Delay_RTS EQU $F57D
Vec_Btn_State EQU $C80F
Vec_Button_1_3 EQU $C814
MOV_DRAW_VL_AB EQU $F3B7
CLEAR_C8_RAM EQU $F542
Intensity_5F EQU $F2A5
Vec_Joy_Mux_1_Y EQU $C820
Vec_Joy_Mux_2_X EQU $C821
Vec_Button_1_4 EQU $C815
Draw_Pat_VL_a EQU $F434
Bitmask_a EQU $F57E
MUSIC6 EQU $FE76
DEC_3_COUNTERS EQU $F55A
Vec_Num_Game EQU $C87A
VEC_EXPL_1 EQU $C858
VEC_FREQ_TABLE EQU $C84D
Vec_Music_Wk_5 EQU $C847
Do_Sound EQU $F289
SELECT_GAME EQU $F7A9
Reset0Ref EQU $F354
Vec_Max_Players EQU $C84F
Vec_Counter_4 EQU $C831
VEC_DEFAULT_STK EQU $CBEA
Draw_VL EQU $F3DD
Dot_d EQU $F2C3
MOV_DRAW_VL_A EQU $F3B9
Clear_x_b EQU $F53F
Draw_Grid_VL EQU $FF9F
INIT_MUSIC_CHK EQU $F687
VEC_BUTTON_2_4 EQU $C819
VEC_MUSIC_TWANG EQU $C858
RESET0INT EQU $F36B
Vec_Joy_Resltn EQU $C81A
Vec_Num_Players EQU $C879
VEC_COUNTER_3 EQU $C830
Draw_VL_mode EQU $F46E
DELAY_RTS EQU $F57D
Mov_Draw_VLcs EQU $F3B5
Vec_Music_Wk_A EQU $C842
Clear_x_b_a EQU $F552
VEC_BUTTON_2_2 EQU $C817
VEC_COUNTER_1 EQU $C82E
MOD16 EQU $4030
MOV_DRAW_VL_B EQU $F3B1
RISE_RUN_X EQU $F5FF
VEC_0REF_ENABLE EQU $C824
EXPLOSION_SND EQU $F92E
Delay_b EQU $F57A
Print_Ships_x EQU $F391
Joy_Analog EQU $F1F5
VEC_MUSIC_WK_A EQU $C842
DO_SOUND_X EQU $F28C
VEC_RISE_INDEX EQU $C839
Vec_Expl_Chans EQU $C854
READ_BTNS_MASK EQU $F1B4
PRINT_TEXT_STR_68624562 EQU $4084
VEC_EXPL_FLAG EQU $C867
DELAY_B EQU $F57A
Vec_Music_Flag EQU $C856
VEC_RFRSH_LO EQU $C83D
Joy_Digital EQU $F1F8
music9 EQU $FF26
DOT_LIST_RESET EQU $F2DE
VEC_ADSR_TABLE EQU $C84F
XFORM_RISE_A EQU $F661
Vec_Counter_6 EQU $C833
PRINT_TEXT_STR_2439665226547 EQU $4090
Get_Run_Idx EQU $F5DB
DELAY_2 EQU $F571
Draw_VLcs EQU $F3D6
VEC_MUSIC_FLAG EQU $C856
VEC_EXPL_CHANA EQU $C853
Vec_Default_Stk EQU $CBEA
Rise_Run_X EQU $F5FF
VEC_RFRSH EQU $C83D
Init_OS EQU $F18B
Random_3 EQU $F511
Vec_Joy_Mux EQU $C81F
DRAW_VLCS EQU $F3D6
Cold_Start EQU $F000
MOV_DRAW_VL EQU $F3BC
Init_Music_x EQU $F692
Vec_Joy_1_Y EQU $C81C
DRAW_PAT_VL_D EQU $F439
Obj_Will_Hit EQU $F8F3
ROT_VL EQU $F616
VEC_MUSIC_CHAN EQU $C855
Moveto_x_7F EQU $F2F2
Moveto_d EQU $F312
MOVETO_IX_7F EQU $F30C
Moveto_d_7F EQU $F2FC
ABS_A_B EQU $F584
Vec_Joy_Mux_2_Y EQU $C822
VEC_IRQ_VECTOR EQU $CBF8
Moveto_ix_FF EQU $F308
Vec_High_Score EQU $CBEB
Intensity_7F EQU $F2A9
Compare_Score EQU $F8C7
music4 EQU $FDD3
VEC_MUSIC_PTR EQU $C853
SOUND_BYTES_X EQU $F284
Dot_here EQU $F2C5
CLEAR_X_256 EQU $F545
INTENSITY_1F EQU $F29D
Clear_Sound EQU $F272
VEC_NMI_VECTOR EQU $CBFB
MUSIC3 EQU $FD81
MOV_DRAW_VLCS EQU $F3B5
Vec_Expl_Timer EQU $C877
VEC_EXPL_TIMER EQU $C877
ABS_B EQU $F58B
Vec_Counters EQU $C82E
Vec_SWI3_Vector EQU $CBF2
Vec_Music_Wk_1 EQU $C84B
VEC_TWANG_TABLE EQU $C851
DRAW_VLP_B EQU $F40E
Vec_Expl_1 EQU $C858
Vec_Loop_Count EQU $C825
DEC_6_COUNTERS EQU $F55E
Print_List_chk EQU $F38C
VEC_TEXT_HEIGHT EQU $C82A
DRAW_VLC EQU $F3CE
Delay_2 EQU $F571
Init_VIA EQU $F14C
VEC_COUNTERS EQU $C82E
SOUND_BYTE EQU $F256
Vec_Counter_5 EQU $C832
Vec_Button_2_2 EQU $C817
Move_Mem_a_1 EQU $F67F
VEC_MUSIC_WK_5 EQU $C847
INIT_MUSIC_BUF EQU $F533
MOVETO_D_7F EQU $F2FC
Init_Music_chk EQU $F687
Vec_Counter_1 EQU $C82E
SOUND_BYTES EQU $F27D
Vec_Text_Width EQU $C82B
Warm_Start EQU $F06C
MUSICA EQU $FF44
Vec_NMI_Vector EQU $CBFB
Mov_Draw_VL_a EQU $F3B9
Obj_Will_Hit_u EQU $F8E5
PRINT_LIST_CHK EQU $F38C
Moveto_ix EQU $F310
PRINT_STR_HWYX EQU $F373
Draw_Pat_VL EQU $F437
VEC_RISERUN_LEN EQU $C83B
Mov_Draw_VL_ab EQU $F3B7
VEC_EXPL_4 EQU $C85B
Dec_3_Counters EQU $F55A
VEC_FIRQ_VECTOR EQU $CBF5
Sound_Bytes EQU $F27D
Print_Str_hwyx EQU $F373
musicc EQU $FF7A
DRAW_VL EQU $F3DD
XFORM_RISE EQU $F663
Vec_Misc_Count EQU $C823
music5 EQU $FE38
OBJ_HIT EQU $F8FF
MOD16.M16_LOOP EQU $4064
Rot_VL_dft EQU $F637
MUSICB EQU $FF62
Vec_Dot_Dwell EQU $C828
Strip_Zeros EQU $F8B7
RECALIBRATE EQU $F2E6
Print_Str_d EQU $F37A
RANDOM_3 EQU $F511
VEC_COUNTER_5 EQU $C832
Xform_Rise EQU $F663
Reset0Int EQU $F36B
MOVE_MEM_A EQU $F683
SOUND_BYTE_X EQU $F259
VEC_MUSIC_FREQ EQU $C861
MUSIC8 EQU $FEF8
VEC_JOY_1_Y EQU $C81C
Rot_VL_ab EQU $F610
music2 EQU $FD1D
MOD16.M16_END EQU $4074
Recalibrate EQU $F2E6
music7 EQU $FEC6
VEC_RFRSH_HI EQU $C83E
Vec_Expl_Flag EQU $C867
MUSIC7 EQU $FEC6
Vec_Joy_1_X EQU $C81B
VEC_SEED_PTR EQU $C87B
XFORM_RUN_A EQU $F65B
VEC_ADSR_TIMERS EQU $C85E
Vec_Expl_ChanA EQU $C853
Vec_ADSR_Timers EQU $C85E
Print_Ships EQU $F393
VEC_LOOP_COUNT EQU $C825
VEC_SWI_VECTOR EQU $CBFB
INTENSITY_5F EQU $F2A5
VEC_EXPL_2 EQU $C859
VEC_RISERUN_TMP EQU $C834
MUSIC4 EQU $FDD3
Rot_VL_Mode_a EQU $F61F
DP_to_C8 EQU $F1AF
INIT_VIA EQU $F14C
INIT_OS EQU $F18B
OBJ_WILL_HIT_U EQU $F8E5
RANDOM EQU $F517
Rise_Run_Angle EQU $F593
Rot_VL EQU $F616
Read_Btns EQU $F1BA
Init_Music_Buf EQU $F533
music8 EQU $FEF8
VEC_EXPL_CHANB EQU $C85D
Vec_Rfrsh_hi EQU $C83E
Vec_Rfrsh EQU $C83D
VEC_MUSIC_WK_7 EQU $C845
Vec_FIRQ_Vector EQU $CBF5
Rise_Run_Y EQU $F601
Vec_Joy_2_Y EQU $C81E
Xform_Run EQU $F65D
VEC_SND_SHADOW EQU $C800
DRAW_LINE_D EQU $F3DF
MOVE_MEM_A_1 EQU $F67F
DOT_HERE EQU $F2C5
BITMASK_A EQU $F57E
DP_TO_C8 EQU $F1AF
Vec_Text_HW EQU $C82A
Vec_RiseRun_Tmp EQU $C834
GET_RUN_IDX EQU $F5DB
DRAW_VLP EQU $F410
MOD16.M16_DONE EQU $4083
ROT_VL_MODE EQU $F62B
Draw_VL_ab EQU $F3D8
musica EQU $FF44
ADD_SCORE_A EQU $F85E
Vec_Brightness EQU $C827
DOT_IX EQU $F2C1
Vec_SWI_Vector EQU $CBFB
PRINT_STR_D EQU $F37A
VEC_COUNTER_2 EQU $C82F
MOD16.M16_RPOS EQU $4064
Vec_Expl_2 EQU $C859
VEC_EXPL_CHANS EQU $C854
INIT_OS_RAM EQU $F164
Check0Ref EQU $F34F
VEC_JOY_RESLTN EQU $C81A
DRAW_VL_B EQU $F3D2
Vec_Buttons EQU $C811
Vec_Run_Index EQU $C837
Vec_Rise_Index EQU $C839
INTENSITY_3F EQU $F2A1
VEC_BUTTON_2_3 EQU $C818
DOT_D EQU $F2C3
Mov_Draw_VL EQU $F3BC
Vec_Str_Ptr EQU $C82C
Vec_Expl_Chan EQU $C85C
CLEAR_SOUND EQU $F272
VEC_BTN_STATE EQU $C80F
VEC_MUSIC_WORK EQU $C83F
Print_Str_yx EQU $F378
Reset0Ref_D0 EQU $F34A
Vec_Joy_Mux_1_X EQU $C81F
Vec_Button_2_3 EQU $C818
VEC_BUTTON_1_1 EQU $C812
PRINT_LIST_HW EQU $F385
VEC_JOY_MUX_2_Y EQU $C822
Vec_Prev_Btns EQU $C810
VEC_NUM_PLAYERS EQU $C879
DO_SOUND EQU $F289
VEC_COUNTER_4 EQU $C831
Print_Str EQU $F495
DRAW_VL_A EQU $F3DA
Explosion_Snd EQU $F92E
Vec_Random_Seed EQU $C87D
Vec_Snd_Shadow EQU $C800
Vec_Rfrsh_lo EQU $C83D
Draw_VLp EQU $F410
Sound_Byte_x EQU $F259
READ_BTNS EQU $F1BA
Clear_C8_RAM EQU $F542
music3 EQU $FD81
Clear_Score EQU $F84F
DRAW_VL_AB EQU $F3D8
STRIP_ZEROS EQU $F8B7
CLEAR_X_D EQU $F548
DRAW_VLP_FF EQU $F404
Dot_ix EQU $F2C1
DOT_LIST EQU $F2D5
WARM_START EQU $F06C
RISE_RUN_Y EQU $F601
Moveto_ix_a EQU $F30E
MUSIC1 EQU $FD0D
Vec_Music_Twang EQU $C858
Vec_Counter_3 EQU $C830
Draw_Pat_VL_d EQU $F439
VEC_NUM_GAME EQU $C87A
VEC_JOY_2_Y EQU $C81E
VEC_RANDOM_SEED EQU $C87D
MOD16.M16_DPOS EQU $404D
Vec_Counter_2 EQU $C82F
VEC_JOY_MUX_1_X EQU $C81F
CLEAR_X_B_A EQU $F552
Vec_Expl_4 EQU $C85B
Vec_ADSR_Table EQU $C84F
VEC_DOT_DWELL EQU $C828
VEC_EXPL_3 EQU $C85A
WAIT_RECAL EQU $F192
DRAW_VLP_SCALE EQU $F40C
Init_OS_RAM EQU $F164
VEC_JOY_MUX_1_Y EQU $C820
Vec_Expl_ChanB EQU $C85D
music1 EQU $FD0D
Dot_ix_b EQU $F2BE
Rise_Run_Len EQU $F603
musicb EQU $FF62


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "PRINT_TEXT"
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
    ; TODO: Statement Pass { source_line: 10 }

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    ; PRINT_TEXT: Print text at position
    LDD #-40
    STD VAR_ARG0
    LDD #20
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_68624562      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-40
    STD VAR_ARG0
    LDD #0
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_82781042      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-55
    STD VAR_ARG0
    LDD #-20
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2439665226547      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    RTS


; ================================================
