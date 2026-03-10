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
VAR_RADIUS           EQU $C880+$2F   ; User variable: radius (2 bytes)
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
MOVETO_X_7F EQU $F2F2
Sound_Byte EQU $F256
MOVE_MEM_A_1 EQU $F67F
DRAW_VL_MODE EQU $F46E
music7 EQU $FEC6
Clear_x_256 EQU $F545
music3 EQU $FD81
Print_List_hw EQU $F385
DP_TO_D0 EQU $F1AA
VEC_EXPL_CHANB EQU $C85D
Vec_Expl_Chan EQU $C85C
ROT_VL_MODE EQU $F62B
Vec_Pattern EQU $C829
Abs_b EQU $F58B
Random_3 EQU $F511
Print_Str_hwyx EQU $F373
Moveto_ix_FF EQU $F308
WARM_START EQU $F06C
music2 EQU $FD1D
VEC_NUM_GAME EQU $C87A
Vec_Rfrsh_lo EQU $C83D
Vec_Music_Flag EQU $C856
DCR_AFTER_INTENSITY EQU $408C
Dot_ix_b EQU $F2BE
VEC_JOY_MUX_2_Y EQU $C822
Vec_Music_Wk_1 EQU $C84B
Rot_VL_ab EQU $F610
VEC_RUN_INDEX EQU $C837
Vec_Buttons EQU $C811
Vec_ADSR_Table EQU $C84F
Vec_Num_Game EQU $C87A
Obj_Hit EQU $F8FF
RISE_RUN_ANGLE EQU $F593
Vec_RiseRun_Len EQU $C83B
Delay_3 EQU $F56D
Intensity_5F EQU $F2A5
Vec_Counter_4 EQU $C831
MUSIC4 EQU $FDD3
ADD_SCORE_D EQU $F87C
Vec_Snd_Shadow EQU $C800
Print_Str_d EQU $F37A
MOD16.M16_DPOS EQU $401D
musicc EQU $FF7A
MOVE_MEM_A EQU $F683
Vec_Music_Work EQU $C83F
Vec_Button_1_1 EQU $C812
DRAW_VL_A EQU $F3DA
Vec_Expl_4 EQU $C85B
Xform_Rise_a EQU $F661
VEC_BUTTON_2_1 EQU $C816
Draw_VL_a EQU $F3DA
Vec_Expl_Timer EQU $C877
VEC_BUTTONS EQU $C811
PRINT_LIST_CHK EQU $F38C
VEC_BUTTON_2_4 EQU $C819
VEC_RFRSH_LO EQU $C83D
RESET0INT EQU $F36B
Draw_VLp_scale EQU $F40C
DEC_6_COUNTERS EQU $F55E
DRAW_PAT_VL_A EQU $F434
DOT_LIST EQU $F2D5
Reset0Int EQU $F36B
VEC_BUTTON_2_2 EQU $C817
VEC_RFRSH EQU $C83D
Cold_Start EQU $F000
MUSICB EQU $FF62
VEC_BTN_STATE EQU $C80F
DO_SOUND_X EQU $F28C
Vec_Counter_5 EQU $C832
VEC_DOT_DWELL EQU $C828
OBJ_HIT EQU $F8FF
MOVETO_IX EQU $F310
MOD16.M16_RCHECK EQU $4025
Vec_Twang_Table EQU $C851
Print_Str EQU $F495
Vec_RiseRun_Tmp EQU $C834
Mov_Draw_VL EQU $F3BC
Compare_Score EQU $F8C7
DP_TO_C8 EQU $F1AF
VEC_COUNTERS EQU $C82E
Delay_0 EQU $F579
Sound_Byte_x EQU $F259
VEC_JOY_MUX_1_X EQU $C81F
RESET_PEN EQU $F35B
VEC_BUTTON_1_1 EQU $C812
Bitmask_a EQU $F57E
MUSICA EQU $FF44
DRAW_VLP_7F EQU $F408
Get_Rise_Idx EQU $F5D9
Print_Ships EQU $F393
Vec_Brightness EQU $C827
DP_to_C8 EQU $F1AF
Print_List EQU $F38A
PRINT_STR_D EQU $F37A
Rot_VL_Mode EQU $F62B
DRAW_VL_AB EQU $F3D8
DEC_COUNTERS EQU $F563
Delay_RTS EQU $F57D
DRAW_PAT_VL_D EQU $F439
VEC_SND_SHADOW EQU $C800
Draw_Grid_VL EQU $FF9F
MOV_DRAW_VL_D EQU $F3BE
ROT_VL_DFT EQU $F637
MOVETO_IX_A EQU $F30E
Moveto_ix_a EQU $F30E
PRINT_STR_YX EQU $F378
VEC_TWANG_TABLE EQU $C851
Vec_SWI2_Vector EQU $CBF2
VEC_MUSIC_WK_1 EQU $C84B
ROT_VL EQU $F616
Dec_3_Counters EQU $F55A
Dot_here EQU $F2C5
INIT_MUSIC EQU $F68D
Mov_Draw_VLc_a EQU $F3AD
Init_Music_x EQU $F692
Rise_Run_Angle EQU $F593
DRAW_VLP EQU $F410
Draw_VL_mode EQU $F46E
VEC_DURATION EQU $C857
MOV_DRAW_VL_A EQU $F3B9
PRINT_SHIPS_X EQU $F391
Vec_Text_Width EQU $C82B
Vec_Max_Games EQU $C850
VEC_MAX_PLAYERS EQU $C84F
Add_Score_d EQU $F87C
VEC_SEED_PTR EQU $C87B
Vec_Duration EQU $C857
Moveto_x_7F EQU $F2F2
VEC_EXPL_3 EQU $C85A
VEC_SWI2_VECTOR EQU $CBF2
Mov_Draw_VL_b EQU $F3B1
DRAW_VLP_FF EQU $F404
Rise_Run_Len EQU $F603
VEC_MUSIC_WK_5 EQU $C847
DRAW_VLC EQU $F3CE
CLEAR_C8_RAM EQU $F542
Sound_Bytes EQU $F27D
VEC_JOY_2_Y EQU $C81E
musicb EQU $FF62
Set_Refresh EQU $F1A2
Vec_Joy_Mux_1_X EQU $C81F
DCR_intensity_5F EQU $4089
Clear_C8_RAM EQU $F542
ROT_VL_AB EQU $F610
DCR_INTENSITY_5F EQU $4089
Clear_x_b_80 EQU $F550
Vec_SWI_Vector EQU $CBFB
Explosion_Snd EQU $F92E
Vec_Num_Players EQU $C879
Init_VIA EQU $F14C
COLD_START EQU $F000
INTENSITY_A EQU $F2AB
VEC_ADSR_TIMERS EQU $C85E
Vec_Music_Wk_7 EQU $C845
VEC_COLD_FLAG EQU $CBFE
Vec_0Ref_Enable EQU $C824
Vec_IRQ_Vector EQU $CBF8
INTENSITY_7F EQU $F2A9
DOT_IX EQU $F2C1
DELAY_1 EQU $F575
Mov_Draw_VL_d EQU $F3BE
INIT_MUSIC_X EQU $F692
MOV_DRAW_VL EQU $F3BC
Do_Sound_x EQU $F28C
XFORM_RUN_A EQU $F65B
VEC_ANGLE EQU $C836
Vec_Seed_Ptr EQU $C87B
VEC_STR_PTR EQU $C82C
ROT_VL_MODE_A EQU $F61F
VEC_NMI_VECTOR EQU $CBFB
VEC_DEFAULT_STK EQU $CBEA
VEC_COUNTER_2 EQU $C82F
VEC_BRIGHTNESS EQU $C827
Clear_Sound EQU $F272
MUSIC3 EQU $FD81
OBJ_WILL_HIT_U EQU $F8E5
Vec_Music_Chan EQU $C855
MOVETO_D_7F EQU $F2FC
Vec_Music_Twang EQU $C858
VEC_EXPL_1 EQU $C858
VEC_MUSIC_WK_7 EQU $C845
PRINT_SHIPS EQU $F393
Draw_Pat_VL_a EQU $F434
Vec_Button_2_2 EQU $C817
Xform_Run EQU $F65D
Rot_VL_dft EQU $F637
VEC_LOOP_COUNT EQU $C825
VEC_MUSIC_WK_6 EQU $C846
SOUND_BYTE_RAW EQU $F25B
Vec_Counter_6 EQU $C833
VEC_RISERUN_TMP EQU $C834
GET_RUN_IDX EQU $F5DB
Rot_VL EQU $F616
COMPARE_SCORE EQU $F8C7
Vec_Joy_1_X EQU $C81B
Draw_Pat_VL_d EQU $F439
Mov_Draw_VLcs EQU $F3B5
Draw_Pat_VL EQU $F437
Dec_6_Counters EQU $F55E
DELAY_B EQU $F57A
Vec_Music_Freq EQU $C861
Dot_List EQU $F2D5
INIT_MUSIC_CHK EQU $F687
Clear_x_b_a EQU $F552
DELAY_0 EQU $F579
XFORM_RISE_A EQU $F661
Dec_Counters EQU $F563
Sound_Bytes_x EQU $F284
VEC_RANDOM_SEED EQU $C87D
Vec_Music_Wk_6 EQU $C846
Clear_x_b EQU $F53F
Obj_Will_Hit_u EQU $F8E5
Reset0Ref EQU $F354
musicd EQU $FF8F
VEC_JOY_1_Y EQU $C81C
Wait_Recal EQU $F192
Strip_Zeros EQU $F8B7
Get_Rise_Run EQU $F5EF
SOUND_BYTES EQU $F27D
VEC_COUNTER_4 EQU $C831
VEC_FIRQ_VECTOR EQU $CBF5
RESET0REF_D0 EQU $F34A
Vec_Angle EQU $C836
Vec_Button_2_1 EQU $C816
DO_SOUND EQU $F289
SOUND_BYTE_X EQU $F259
MOD16.M16_END EQU $4044
MUSIC2 EQU $FD1D
VEC_EXPL_CHANS EQU $C854
DRAW_GRID_VL EQU $FF9F
VEC_COUNTER_5 EQU $C832
Vec_Prev_Btns EQU $C810
INTENSITY_3F EQU $F2A1
MOVETO_IX_FF EQU $F308
music9 EQU $FF26
Delay_1 EQU $F575
Print_List_chk EQU $F38C
Vec_Joy_2_X EQU $C81D
Vec_SWI3_Vector EQU $CBF2
RECALIBRATE EQU $F2E6
SET_REFRESH EQU $F1A2
ABS_B EQU $F58B
VEC_NUM_PLAYERS EQU $C879
INTENSITY_1F EQU $F29D
Moveto_ix_7F EQU $F30C
VEC_PATTERN EQU $C829
SOUND_BYTE EQU $F256
Delay_2 EQU $F571
Draw_VLc EQU $F3CE
VEC_BUTTON_1_4 EQU $C815
Dot_d EQU $F2C3
Vec_Random_Seed EQU $C87D
XFORM_RISE EQU $F663
MOVETO_IX_7F EQU $F30C
Vec_Btn_State EQU $C80F
INIT_OS_RAM EQU $F164
Random EQU $F517
Vec_Cold_Flag EQU $CBFE
VEC_RISERUN_LEN EQU $C83B
Intensity_3F EQU $F2A1
MOVETO_D EQU $F312
Joy_Digital EQU $F1F8
VEC_EXPL_2 EQU $C859
Vec_Dot_Dwell EQU $C828
RISE_RUN_X EQU $F5FF
VEC_MUSIC_TWANG EQU $C858
MOD16 EQU $4000
SELECT_GAME EQU $F7A9
Xform_Run_a EQU $F65B
Vec_Expl_2 EQU $C859
VEC_TEXT_WIDTH EQU $C82B
CLEAR_X_B_80 EQU $F550
DRAW_VL_B EQU $F3D2
Moveto_ix EQU $F310
Vec_Rfrsh_hi EQU $C83E
VEC_TEXT_HEIGHT EQU $C82A
Reset_Pen EQU $F35B
Vec_Joy_1_Y EQU $C81C
Vec_Button_1_2 EQU $C813
Select_Game EQU $F7A9
Mov_Draw_VL_a EQU $F3B9
DRAW_VLCS EQU $F3D6
EXPLOSION_SND EQU $F92E
JOY_ANALOG EQU $F1F5
VEC_BUTTON_2_3 EQU $C818
VEC_RISE_INDEX EQU $C839
DRAW_CIRCLE_RUNTIME EQU $4054
VEC_RFRSH_HI EQU $C83E
Vec_Joy_2_Y EQU $C81E
RANDOM_3 EQU $F511
Draw_VL_b EQU $F3D2
MUSICD EQU $FF8F
Intensity_7F EQU $F2A9
Vec_High_Score EQU $CBEB
Draw_VLp_FF EQU $F404
Vec_Music_Wk_5 EQU $C847
GET_RISE_RUN EQU $F5EF
Print_Ships_x EQU $F391
Vec_FIRQ_Vector EQU $CBF5
Vec_Freq_Table EQU $C84D
Vec_Joy_Mux_2_Y EQU $C822
Moveto_d_7F EQU $F2FC
Sound_Byte_raw EQU $F25B
CLEAR_SOUND EQU $F272
VEC_EXPL_FLAG EQU $C867
Vec_Counters EQU $C82E
Xform_Rise EQU $F663
MUSIC6 EQU $FE76
VEC_SWI3_VECTOR EQU $CBF2
VEC_HIGH_SCORE EQU $CBEB
RISE_RUN_LEN EQU $F603
VEC_JOY_2_X EQU $C81D
Vec_NMI_Vector EQU $CBFB
Vec_Counter_1 EQU $C82E
READ_BTNS_MASK EQU $F1B4
VEC_COUNTER_3 EQU $C830
RESET0REF EQU $F354
DOT_IX_B EQU $F2BE
MUSIC9 EQU $FF26
Vec_Expl_ChanA EQU $C853
ADD_SCORE_A EQU $F85E
Vec_Joy_Resltn EQU $C81A
Vec_Rfrsh EQU $C83D
VEC_EXPL_CHAN EQU $C85C
Vec_Button_2_4 EQU $C819
Rot_VL_Mode_a EQU $F61F
music5 EQU $FE38
Vec_ADSR_Timers EQU $C85E
PRINT_STR_HWYX EQU $F373
Vec_Max_Players EQU $C84F
Vec_Expl_Chans EQU $C854
Init_Music_Buf EQU $F533
MOD16.M16_LOOP EQU $4034
VEC_PREV_BTNS EQU $C810
VEC_JOY_MUX_2_X EQU $C821
VEC_TEXT_HW EQU $C82A
DRAW_VLP_B EQU $F40E
MUSIC5 EQU $FE38
MOD16.M16_DONE EQU $4053
VEC_EXPL_4 EQU $C85B
Draw_VL_ab EQU $F3D8
JOY_DIGITAL EQU $F1F8
Init_OS EQU $F18B
Read_Btns_Mask EQU $F1B4
RANDOM EQU $F517
music1 EQU $FD0D
Warm_Start EQU $F06C
Vec_Button_1_3 EQU $C814
Vec_Misc_Count EQU $C823
VEC_BUTTON_1_2 EQU $C813
Abs_a_b EQU $F584
Vec_Expl_3 EQU $C85A
INIT_MUSIC_BUF EQU $F533
Joy_Analog EQU $F1F5
NEW_HIGH_SCORE EQU $F8D8
DP_to_D0 EQU $F1AA
VEC_MISC_COUNT EQU $C823
Vec_Joy_Mux_1_Y EQU $C820
PRINT_LIST_HW EQU $F385
Add_Score_a EQU $F85E
Draw_VL EQU $F3DD
VEC_EXPL_CHANA EQU $C853
VEC_JOY_MUX_1_Y EQU $C820
musica EQU $FF44
CLEAR_X_256 EQU $F545
VEC_MUSIC_PTR EQU $C853
music4 EQU $FDD3
VEC_BUTTON_1_3 EQU $C814
Vec_Joy_Mux_2_X EQU $C821
WAIT_RECAL EQU $F192
music6 EQU $FE76
CLEAR_X_D EQU $F548
CLEAR_SCORE EQU $F84F
Vec_Text_Height EQU $C82A
Vec_Default_Stk EQU $CBEA
Vec_Counter_3 EQU $C830
VEC_COUNTER_6 EQU $C833
Draw_VLp EQU $F410
Reset0Ref_D0 EQU $F34A
Vec_Expl_Flag EQU $C867
CLEAR_X_B EQU $F53F
CLEAR_X_B_A EQU $F552
Delay_b EQU $F57A
CHECK0REF EQU $F34F
VEC_FREQ_TABLE EQU $C84D
Move_Mem_a_1 EQU $F67F
Print_Str_yx EQU $F378
Move_Mem_a EQU $F683
Do_Sound EQU $F289
VEC_SWI_VECTOR EQU $CBFB
VEC_MUSIC_FREQ EQU $C861
RISE_RUN_Y EQU $F601
Init_OS_RAM EQU $F164
Clear_x_d EQU $F548
Dot_List_Reset EQU $F2DE
PRINT_LIST EQU $F38A
DOT_HERE EQU $F2C5
DOT_LIST_RESET EQU $F2DE
DEC_3_COUNTERS EQU $F55A
MUSIC7 EQU $FEC6
VEC_COUNTER_1 EQU $C82E
MUSICC EQU $FF7A
Vec_Music_Wk_A EQU $C842
DOT_D EQU $F2C3
Intensity_a EQU $F2AB
VEC_MUSIC_CHAN EQU $C855
Moveto_d EQU $F312
music8 EQU $FEF8
INTENSITY_5F EQU $F2A5
Clear_Score EQU $F84F
Vec_Counter_2 EQU $C82F
DRAW_VL EQU $F3DD
Read_Btns EQU $F1BA
MOV_DRAW_VLC_A EQU $F3AD
OBJ_WILL_HIT EQU $F8F3
READ_BTNS EQU $F1BA
VEC_JOY_1_X EQU $C81B
New_High_Score EQU $F8D8
Init_Music EQU $F68D
ABS_A_B EQU $F584
PRINT_STR EQU $F495
VEC_ADSR_TABLE EQU $C84F
MUSIC1 EQU $FD0D
MOV_DRAW_VL_B EQU $F3B1
Rise_Run_Y EQU $F601
DCR_after_intensity EQU $408C
VEC_MUSIC_FLAG EQU $C856
Recalibrate EQU $F2E6
Draw_VLp_7F EQU $F408
XFORM_RUN EQU $F65D
MUSIC8 EQU $FEF8
VEC_IRQ_VECTOR EQU $CBF8
Mov_Draw_VL_ab EQU $F3B7
VEC_0REF_ENABLE EQU $C824
DELAY_RTS EQU $F57D
DELAY_3 EQU $F56D
Draw_Line_d EQU $F3DF
MOV_DRAW_VL_AB EQU $F3B7
Draw_VLcs EQU $F3D6
Vec_Button_2_3 EQU $C818
DELAY_2 EQU $F571
Vec_Button_1_4 EQU $C815
Draw_VLp_b EQU $F40E
SOUND_BYTES_X EQU $F284
Vec_Music_Ptr EQU $C853
INIT_VIA EQU $F14C
Vec_Expl_ChanB EQU $C85D
VEC_MUSIC_WK_A EQU $C842
DRAW_VLP_SCALE EQU $F40C
Vec_Text_HW EQU $C82A
Dot_ix EQU $F2C1
MOD16.M16_RPOS EQU $4034
BITMASK_A EQU $F57E
INIT_OS EQU $F18B
Init_Music_chk EQU $F687
GET_RISE_IDX EQU $F5D9
Vec_Rise_Index EQU $C839
VEC_JOY_RESLTN EQU $C81A
Vec_Run_Index EQU $C837
MOV_DRAW_VLCS EQU $F3B5
Vec_Loop_Count EQU $C825
Intensity_1F EQU $F29D
VEC_JOY_MUX EQU $C81F
VEC_EXPL_TIMER EQU $C877
Vec_Expl_1 EQU $C858
Vec_Str_Ptr EQU $C82C
STRIP_ZEROS EQU $F8B7
Obj_Will_Hit EQU $F8F3
Vec_Joy_Mux EQU $C81F
VEC_MAX_GAMES EQU $C850
VEC_MUSIC_WORK EQU $C83F
Rise_Run_X EQU $F5FF
Check0Ref EQU $F34F
DRAW_PAT_VL EQU $F437
DRAW_LINE_D EQU $F3DF
Get_Run_Idx EQU $F5DB


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "DRAW_CIRCLE"
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
VAR_RADIUS           EQU $C880+$2F   ; User variable: radius (2 bytes)
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
    LDD #20
    STD VAR_RADIUS
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
    LDD #20
    STD VAR_RADIUS

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
    LDA #$00
    LDB #$0F
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$06
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$05
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$FB
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
    LDA #$FD
    LDB #$FB
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FB
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FA
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FA
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FB
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$05
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
    LDA #$03
    LDB #$05
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$05
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$06
    LDB #$01
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
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
    LDB #$CE
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
    LDA #$02
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FC
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FC
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FD
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
    LDA #$FD
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$04
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$04
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$04
    LDB #$01
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD #60
    TFR B,A
    STA DRAW_CIRCLE_XC
    LDD #0
    TFR B,A
    STA DRAW_CIRCLE_YC
    LDD >VAR_RADIUS
    TFR B,A
    STA DRAW_CIRCLE_DIAM
    LDD #80
    TFR B,A
    STA DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$50
    JSR Intensity_a
    LDA #$3C
    LDB #$08
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$01
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LDD >VAR_RADIUS
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_RADIUS
    LDD #35
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_RADIUS
    CMPD TMPVAL
    LBGT .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_1
    LDD #15
    STD VAR_RADIUS
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    RTS


; ================================================
