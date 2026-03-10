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
Intensity_5F EQU $F2A5
OBJ_WILL_HIT EQU $F8F3
RESET0REF_D0 EQU $F34A
MOD16.M16_DPOS EQU $404D
Sound_Byte EQU $F256
Vec_Rfrsh_lo EQU $C83D
JOY_DIGITAL EQU $F1F8
Vec_Brightness EQU $C827
Clear_x_256 EQU $F545
VEC_ADSR_TIMERS EQU $C85E
Xform_Run EQU $F65D
RISE_RUN_LEN EQU $F603
DRAW_LINE_D EQU $F3DF
Clear_x_d EQU $F548
Vec_Misc_Count EQU $C823
music1 EQU $FD0D
Moveto_x_7F EQU $F2F2
Xform_Rise EQU $F663
Vec_Music_Ptr EQU $C853
Cold_Start EQU $F000
PRINT_LIST_HW EQU $F385
VEC_COUNTER_1 EQU $C82E
Vec_Joy_1_Y EQU $C81C
VEC_MAX_GAMES EQU $C850
music4 EQU $FDD3
Draw_VLp_b EQU $F40E
VEC_EXPL_3 EQU $C85A
VEC_BUTTON_1_1 EQU $C812
Print_Ships_x EQU $F391
Draw_Grid_VL EQU $FF9F
GET_RISE_IDX EQU $F5D9
Vec_Joy_2_X EQU $C81D
Vec_Music_Twang EQU $C858
PRINT_STR EQU $F495
VEC_JOY_2_Y EQU $C81E
MOV_DRAW_VL_D EQU $F3BE
Vec_Expl_Flag EQU $C867
MOVETO_IX_A EQU $F30E
Warm_Start EQU $F06C
Add_Score_d EQU $F87C
ADD_SCORE_D EQU $F87C
DELAY_B EQU $F57A
Vec_Counter_3 EQU $C830
DRAW_VLC EQU $F3CE
RECALIBRATE EQU $F2E6
INTENSITY_7F EQU $F2A9
NEW_HIGH_SCORE EQU $F8D8
VEC_BRIGHTNESS EQU $C827
Draw_VLc EQU $F3CE
Clear_x_b_80 EQU $F550
Init_OS_RAM EQU $F164
DRAW_VL_B EQU $F3D2
Dot_d EQU $F2C3
MOV_DRAW_VL_AB EQU $F3B7
Dot_List EQU $F2D5
Vec_Pattern EQU $C829
ROT_VL_AB EQU $F610
Vec_Counter_1 EQU $C82E
Set_Refresh EQU $F1A2
VEC_PREV_BTNS EQU $C810
Reset0Ref EQU $F354
PRINT_LIST_CHK EQU $F38C
DELAY_0 EQU $F579
Vec_Music_Freq EQU $C861
VEC_DEFAULT_STK EQU $CBEA
DEC_3_COUNTERS EQU $F55A
Init_Music EQU $F68D
RISE_RUN_Y EQU $F601
Print_Str_hwyx EQU $F373
WAIT_RECAL EQU $F192
SELECT_GAME EQU $F7A9
Draw_VLp_scale EQU $F40C
INIT_MUSIC_BUF EQU $F533
VEC_JOY_MUX_1_Y EQU $C820
VEC_COUNTERS EQU $C82E
VEC_SWI_VECTOR EQU $CBFB
DRAW_VLP_SCALE EQU $F40C
XFORM_RISE_A EQU $F661
MOD16.M16_DONE EQU $4083
music7 EQU $FEC6
VEC_BUTTONS EQU $C811
VEC_DOT_DWELL EQU $C828
VEC_BUTTON_2_4 EQU $C819
WARM_START EQU $F06C
Draw_Line_d EQU $F3DF
VEC_BUTTON_2_2 EQU $C817
VEC_DURATION EQU $C857
MUSIC1 EQU $FD0D
Vec_Music_Wk_6 EQU $C846
Draw_VLp_FF EQU $F404
VEC_FIRQ_VECTOR EQU $CBF5
INTENSITY_1F EQU $F29D
VEC_SEED_PTR EQU $C87B
Draw_VL_ab EQU $F3D8
Vec_Counter_4 EQU $C831
Sound_Bytes EQU $F27D
Intensity_a EQU $F2AB
PRINT_TEXT_STR_68624562 EQU $4084
DELAY_RTS EQU $F57D
OBJ_HIT EQU $F8FF
VEC_TEXT_HW EQU $C82A
Mov_Draw_VL_a EQU $F3B9
SOUND_BYTE_X EQU $F259
VEC_RFRSH_HI EQU $C83E
Vec_Max_Players EQU $C84F
VEC_IRQ_VECTOR EQU $CBF8
VEC_HIGH_SCORE EQU $CBEB
Init_OS EQU $F18B
Rot_VL_ab EQU $F610
Recalibrate EQU $F2E6
Clear_x_b_a EQU $F552
Vec_Angle EQU $C836
Reset0Int EQU $F36B
Vec_RiseRun_Len EQU $C83B
VEC_EXPL_CHANB EQU $C85D
DRAW_PAT_VL EQU $F437
Vec_Button_2_4 EQU $C819
Vec_ADSR_Timers EQU $C85E
RISE_RUN_X EQU $F5FF
Vec_Text_HW EQU $C82A
VEC_JOY_MUX_2_Y EQU $C822
Vec_Num_Game EQU $C87A
Vec_Expl_3 EQU $C85A
Joy_Digital EQU $F1F8
Draw_VLp_7F EQU $F408
RESET0REF EQU $F354
VEC_NUM_GAME EQU $C87A
VEC_RFRSH EQU $C83D
PRINT_STR_D EQU $F37A
Vec_Joy_Mux EQU $C81F
Vec_Music_Flag EQU $C856
Intensity_3F EQU $F2A1
INTENSITY_A EQU $F2AB
VEC_MAX_PLAYERS EQU $C84F
MOD16.M16_RPOS EQU $4064
VEC_JOY_MUX_1_X EQU $C81F
Vec_Button_1_2 EQU $C813
Read_Btns EQU $F1BA
Vec_Expl_Chans EQU $C854
MOD16 EQU $4030
Vec_Rfrsh EQU $C83D
VEC_BUTTON_2_1 EQU $C816
Vec_Joy_Mux_2_X EQU $C821
Clear_Sound EQU $F272
Delay_2 EQU $F571
Mov_Draw_VLcs EQU $F3B5
EXPLOSION_SND EQU $F92E
CLEAR_SCORE EQU $F84F
XFORM_RUN_A EQU $F65B
Rot_VL_Mode EQU $F62B
Vec_Text_Height EQU $C82A
VEC_MUSIC_CHAN EQU $C855
DOT_IX EQU $F2C1
music3 EQU $FD81
Print_Str EQU $F495
VEC_BUTTON_2_3 EQU $C818
VEC_NUM_PLAYERS EQU $C879
SOUND_BYTES EQU $F27D
VEC_COUNTER_6 EQU $C833
Vec_Joy_Mux_1_Y EQU $C820
VEC_EXPL_CHANS EQU $C854
Vec_Joy_1_X EQU $C81B
DRAW_PAT_VL_D EQU $F439
Strip_Zeros EQU $F8B7
ROT_VL_DFT EQU $F637
DO_SOUND EQU $F289
MUSICA EQU $FF44
VECTREX_PRINT_TEXT EQU $4000
DRAW_VL_A EQU $F3DA
Print_Str_yx EQU $F378
Delay_0 EQU $F579
VEC_EXPL_CHAN EQU $C85C
RANDOM_3 EQU $F511
Rise_Run_X EQU $F5FF
JOY_ANALOG EQU $F1F5
VEC_COUNTER_3 EQU $C830
STRIP_ZEROS EQU $F8B7
CLEAR_X_B EQU $F53F
Vec_Joy_Mux_1_X EQU $C81F
Vec_Expl_ChanA EQU $C853
GET_RUN_IDX EQU $F5DB
INTENSITY_3F EQU $F2A1
Vec_0Ref_Enable EQU $C824
VEC_ANGLE EQU $C836
Moveto_d EQU $F312
Moveto_ix_7F EQU $F30C
VEC_EXPL_1 EQU $C858
Bitmask_a EQU $F57E
Vec_Button_1_3 EQU $C814
Delay_RTS EQU $F57D
DO_SOUND_X EQU $F28C
VEC_RISERUN_LEN EQU $C83B
DEC_6_COUNTERS EQU $F55E
Vec_Loop_Count EQU $C825
Clear_Score EQU $F84F
Abs_a_b EQU $F584
PRINT_TEXT_STR_82781042 EQU $408A
MUSIC8 EQU $FEF8
Reset0Ref_D0 EQU $F34A
Random_3 EQU $F511
Vec_Music_Wk_5 EQU $C847
Draw_VL EQU $F3DD
Vec_Buttons EQU $C811
CLEAR_SOUND EQU $F272
Sound_Byte_x EQU $F259
SOUND_BYTE EQU $F256
Vec_Snd_Shadow EQU $C800
Clear_x_b EQU $F53F
CLEAR_X_B_80 EQU $F550
VEC_MUSIC_WK_7 EQU $C845
Check0Ref EQU $F34F
MOV_DRAW_VL_B EQU $F3B1
Vec_Joy_2_Y EQU $C81E
Vec_Rfrsh_hi EQU $C83E
Intensity_7F EQU $F2A9
Random EQU $F517
MOVETO_D_7F EQU $F2FC
VEC_EXPL_FLAG EQU $C867
Rise_Run_Angle EQU $F593
VEC_BUTTON_1_3 EQU $C814
Vec_Twang_Table EQU $C851
Draw_Pat_VL EQU $F437
musica EQU $FF44
Xform_Rise_a EQU $F661
music9 EQU $FF26
MUSIC6 EQU $FE76
VEC_COUNTER_4 EQU $C831
RANDOM EQU $F517
DOT_IX_B EQU $F2BE
musicb EQU $FF62
DP_TO_D0 EQU $F1AA
VEC_FREQ_TABLE EQU $C84D
DRAW_VLP_7F EQU $F408
OBJ_WILL_HIT_U EQU $F8E5
SET_REFRESH EQU $F1A2
CLEAR_X_256 EQU $F545
Rot_VL_Mode_a EQU $F61F
Vec_Expl_ChanB EQU $C85D
Vec_Freq_Table EQU $C84D
Init_VIA EQU $F14C
VEC_JOY_1_Y EQU $C81C
VEC_SWI3_VECTOR EQU $CBF2
VEC_RISERUN_TMP EQU $C834
VEC_MUSIC_WK_6 EQU $C846
music6 EQU $FE76
Add_Score_a EQU $F85E
Delay_1 EQU $F575
DRAW_VLP_B EQU $F40E
Init_Music_Buf EQU $F533
CLEAR_X_B_A EQU $F552
INTENSITY_5F EQU $F2A5
VEC_MUSIC_WK_1 EQU $C84B
Mov_Draw_VL_d EQU $F3BE
DOT_D EQU $F2C3
DRAW_VLP EQU $F410
Vec_FIRQ_Vector EQU $CBF5
PRINT_SHIPS_X EQU $F391
Print_Str_d EQU $F37A
PRINT_LIST EQU $F38A
XFORM_RUN EQU $F65D
Vec_Music_Wk_A EQU $C842
Delay_b EQU $F57A
VEC_TWANG_TABLE EQU $C851
MOVETO_IX_FF EQU $F308
ROT_VL_MODE EQU $F62B
Select_Game EQU $F7A9
BITMASK_A EQU $F57E
INIT_MUSIC_CHK EQU $F687
Wait_Recal EQU $F192
Vec_Cold_Flag EQU $CBFE
VEC_RUN_INDEX EQU $C837
Dec_Counters EQU $F563
Rot_VL_dft EQU $F637
Get_Run_Idx EQU $F5DB
Vec_Default_Stk EQU $CBEA
Vec_Button_1_1 EQU $C812
SOUND_BYTES_X EQU $F284
Move_Mem_a EQU $F683
Obj_Will_Hit_u EQU $F8E5
Vec_Button_2_2 EQU $C817
Draw_VL_mode EQU $F46E
VEC_RFRSH_LO EQU $C83D
ABS_B EQU $F58B
Draw_Pat_VL_d EQU $F439
Print_List_hw EQU $F385
VEC_COLD_FLAG EQU $CBFE
Dec_3_Counters EQU $F55A
Vec_Button_2_3 EQU $C818
Read_Btns_Mask EQU $F1B4
Rise_Run_Y EQU $F601
VEC_JOY_MUX EQU $C81F
VEC_EXPL_CHANA EQU $C853
Dot_ix EQU $F2C1
Vec_SWI_Vector EQU $CBFB
READ_BTNS_MASK EQU $F1B4
Vec_Btn_State EQU $C80F
Draw_VLp EQU $F410
Vec_Counter_6 EQU $C833
Vec_Expl_1 EQU $C858
COMPARE_SCORE EQU $F8C7
Vec_Dot_Dwell EQU $C828
VEC_MISC_COUNT EQU $C823
PRINT_SHIPS EQU $F393
Print_List EQU $F38A
INIT_OS_RAM EQU $F164
XFORM_RISE EQU $F663
VEC_EXPL_2 EQU $C859
Vec_Seed_Ptr EQU $C87B
DRAW_GRID_VL EQU $FF9F
Vec_NMI_Vector EQU $CBFB
VEC_JOY_2_X EQU $C81D
VEC_BUTTON_1_2 EQU $C813
INIT_VIA EQU $F14C
Sound_Bytes_x EQU $F284
INIT_OS EQU $F18B
VEC_EXPL_TIMER EQU $C877
VEC_BUTTON_1_4 EQU $C815
Reset_Pen EQU $F35B
Draw_VL_b EQU $F3D2
VEC_STR_PTR EQU $C82C
Delay_3 EQU $F56D
MUSICC EQU $FF7A
MOVETO_D EQU $F312
RESET_PEN EQU $F35B
MUSIC3 EQU $FD81
Xform_Run_a EQU $F65B
MOV_DRAW_VLCS EQU $F3B5
VEC_BTN_STATE EQU $C80F
DRAW_VLCS EQU $F3D6
DRAW_VLP_FF EQU $F404
Vec_Joy_Resltn EQU $C81A
Vec_Counter_2 EQU $C82F
VEC_MUSIC_TWANG EQU $C858
Dot_List_Reset EQU $F2DE
DELAY_1 EQU $F575
VEC_TEXT_WIDTH EQU $C82B
ABS_A_B EQU $F584
Rot_VL EQU $F616
Print_List_chk EQU $F38C
Obj_Hit EQU $F8FF
Draw_VLcs EQU $F3D6
VEC_RANDOM_SEED EQU $C87D
Vec_Button_2_1 EQU $C816
VEC_ADSR_TABLE EQU $C84F
VEC_SND_SHADOW EQU $C800
Joy_Analog EQU $F1F5
VEC_RISE_INDEX EQU $C839
Mov_Draw_VL_ab EQU $F3B7
Vec_Music_Work EQU $C83F
Init_Music_chk EQU $F687
Vec_Music_Wk_1 EQU $C84B
Vec_Max_Games EQU $C850
Print_Ships EQU $F393
Draw_Pat_VL_a EQU $F434
Compare_Score EQU $F8C7
Vec_IRQ_Vector EQU $CBF8
Moveto_ix_FF EQU $F308
GET_RISE_RUN EQU $F5EF
MUSIC4 EQU $FDD3
MOD16.M16_LOOP EQU $4064
MOVE_MEM_A EQU $F683
Explosion_Snd EQU $F92E
VEC_PATTERN EQU $C829
Get_Rise_Idx EQU $F5D9
Dot_ix_b EQU $F2BE
Vec_Music_Wk_7 EQU $C845
Vec_Num_Players EQU $C879
DP_to_D0 EQU $F1AA
MUSIC7 EQU $FEC6
MOD16.M16_RCHECK EQU $4055
Vec_SWI2_Vector EQU $CBF2
Sound_Byte_raw EQU $F25B
New_High_Score EQU $F8D8
Do_Sound EQU $F289
Vec_Expl_Chan EQU $C85C
VEC_JOY_RESLTN EQU $C81A
Intensity_1F EQU $F29D
DP_TO_C8 EQU $F1AF
MOD16.M16_END EQU $4074
SOUND_BYTE_RAW EQU $F25B
ROT_VL EQU $F616
Dec_6_Counters EQU $F55E
VEC_NMI_VECTOR EQU $CBFB
MOVE_MEM_A_1 EQU $F67F
VEC_SWI2_VECTOR EQU $CBF2
MOVETO_X_7F EQU $F2F2
VEC_MUSIC_FLAG EQU $C856
DP_to_C8 EQU $F1AF
Moveto_ix EQU $F310
Do_Sound_x EQU $F28C
INIT_MUSIC EQU $F68D
VEC_LOOP_COUNT EQU $C825
MUSICD EQU $FF8F
DRAW_VL EQU $F3DD
music5 EQU $FE38
Vec_Music_Chan EQU $C855
RISE_RUN_ANGLE EQU $F593
Vec_Duration EQU $C857
DOT_LIST EQU $F2D5
Vec_RiseRun_Tmp EQU $C834
Vec_Run_Index EQU $C837
MOV_DRAW_VL EQU $F3BC
VEC_MUSIC_WORK EQU $C83F
MOVETO_IX EQU $F310
Moveto_ix_a EQU $F30E
VEC_JOY_1_X EQU $C81B
RESET0INT EQU $F36B
music2 EQU $FD1D
MUSIC5 EQU $FE38
CHECK0REF EQU $F34F
MUSIC9 EQU $FF26
VEC_MUSIC_FREQ EQU $C861
VEC_MUSIC_WK_A EQU $C842
PRINT_TEXT_STR_2439665226547 EQU $4090
INIT_MUSIC_X EQU $F692
Vec_Counter_5 EQU $C832
PRINT_STR_HWYX EQU $F373
Vec_ADSR_Table EQU $C84F
Rise_Run_Len EQU $F603
VEC_EXPL_4 EQU $C85B
Vec_Button_1_4 EQU $C815
Vec_Expl_4 EQU $C85B
DRAW_PAT_VL_A EQU $F434
Dot_here EQU $F2C5
Clear_C8_RAM EQU $F542
Move_Mem_a_1 EQU $F67F
MUSIC2 EQU $FD1D
Vec_Text_Width EQU $C82B
VEC_MUSIC_WK_5 EQU $C847
musicc EQU $FF7A
musicd EQU $FF8F
Vec_High_Score EQU $CBEB
MOVETO_IX_7F EQU $F30C
Vec_Rise_Index EQU $C839
Vec_Random_Seed EQU $C87D
Get_Rise_Run EQU $F5EF
READ_BTNS EQU $F1BA
VEC_COUNTER_5 EQU $C832
Mov_Draw_VL EQU $F3BC
VEC_TEXT_HEIGHT EQU $C82A
music8 EQU $FEF8
DRAW_VL_AB EQU $F3D8
DRAW_VL_MODE EQU $F46E
Vec_Joy_Mux_2_Y EQU $C822
Moveto_d_7F EQU $F2FC
PRINT_STR_YX EQU $F378
MOV_DRAW_VLC_A EQU $F3AD
ROT_VL_MODE_A EQU $F61F
DEC_COUNTERS EQU $F563
DOT_HERE EQU $F2C5
MUSICB EQU $FF62
COLD_START EQU $F000
Obj_Will_Hit EQU $F8F3
CLEAR_X_D EQU $F548
DOT_LIST_RESET EQU $F2DE
DELAY_3 EQU $F56D
MOV_DRAW_VL_A EQU $F3B9
DELAY_2 EQU $F571
Vec_Str_Ptr EQU $C82C
Mov_Draw_VL_b EQU $F3B1
VEC_0REF_ENABLE EQU $C824
VEC_COUNTER_2 EQU $C82F
Mov_Draw_VLc_a EQU $F3AD
Draw_VL_a EQU $F3DA
VEC_JOY_MUX_2_X EQU $C821
CLEAR_C8_RAM EQU $F542
ADD_SCORE_A EQU $F85E
Vec_Expl_2 EQU $C859
Init_Music_x EQU $F692
Abs_b EQU $F58B
Vec_SWI3_Vector EQU $CBF2
Vec_Counters EQU $C82E
Vec_Prev_Btns EQU $C810
Vec_Expl_Timer EQU $C877
VEC_MUSIC_PTR EQU $C853


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
