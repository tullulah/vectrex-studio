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
NUM_STR              EQU $C880+$0E   ; Buffer for PRINT_NUMBER decimal output (5 digits + terminator) (6 bytes)
DRAW_CIRCLE_XC       EQU $C880+$14   ; Circle center X (1 bytes)
DRAW_CIRCLE_YC       EQU $C880+$15   ; Circle center Y (1 bytes)
DRAW_CIRCLE_DIAM     EQU $C880+$16   ; Circle diameter (1 bytes)
DRAW_CIRCLE_INTENSITY EQU $C880+$17   ; Circle intensity (1 bytes)
DRAW_CIRCLE_RADIUS   EQU $C880+$18   ; Circle radius (diam/2) - used in segment drawing (1 bytes)
DRAW_CIRCLE_TEMP     EQU $C880+$19   ; Circle temporary buffer (8 bytes: radius16, a, b, c, d, --, --)  a=0.383r b=0.324r c=0.217r d=0.076r (8 bytes)
DRAW_LINE_ARGS       EQU $C880+$21   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$2B   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$2D   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$2F   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$30   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$31   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$33   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$35   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$36   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_NUM_ITEMS        EQU $C880+$37   ; User variable: NUM_ITEMS (2 bytes)
VAR_ROW_Y            EQU $C880+$39   ; User variable: row_y (2 bytes)
VAR_SELECTED         EQU $C880+$3B   ; User variable: selected (2 bytes)
VAR_COOLDOWN         EQU $C880+$3D   ; User variable: cooldown (2 bytes)
VAR_JOY_Y            EQU $C880+$3F   ; User variable: joy_y (2 bytes)
VAR_CUR_SCORE        EQU $C880+$41   ; User variable: cur_score (2 bytes)
VAR_ITEM_SCORE       EQU $C880+$43   ; User variable: item_score (2 bytes)
VAR_ITEM_SCORE_DATA  EQU $C880+$45   ; Mutable array 'item_score' data (4 elements x 2 bytes) (8 bytes)
VAR_ARG0             EQU $CB80   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $CB82   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $CB84   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $CB86   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $CB88   ; Function argument 4 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $CB8A   ; Current ROM bank ID (multibank tracking) (1 bytes)
PSG_MUSIC_PTR        EQU $CBEB   ; PSG music data pointer (2 bytes)
PSG_MUSIC_START      EQU $CBED   ; PSG music start pointer (for loops) (2 bytes)
PSG_MUSIC_ACTIVE     EQU $CBEF   ; PSG music active flag (1 bytes)
PSG_IS_PLAYING       EQU $CBF0   ; PSG playing flag (1 bytes)
PSG_DELAY_FRAMES     EQU $CBF1   ; PSG frame delay counter (1 bytes)
PSG_MUSIC_BANK       EQU $CBF2   ; PSG music bank ID (for multibank) (1 bytes)
SFX_PTR              EQU $CBF3   ; SFX data pointer (2 bytes)
SFX_ACTIVE           EQU $CBF5   ; SFX active flag (1 bytes)
SFX_BANK             EQU $CBF6   ; SFX bank ID (for multibank) (1 bytes)


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
Vec_Counter_3 EQU $C830
VEC_COUNTERS EQU $C82E
Sound_Byte_x EQU $F259
Moveto_d EQU $F312
AU_DONE EQU $443B
OBJ_WILL_HIT EQU $F8F3
Vec_Prev_Btns EQU $C810
Joy_Digital EQU $F1F8
RESET0REF_D0 EQU $F34A
DOT_LIST EQU $F2D5
VEC_MUSIC_WK_5 EQU $C847
Xform_Rise_a EQU $F661
VEC_BUTTON_2_4 EQU $C819
Print_List_chk EQU $F38C
DCR_AFTER_INTENSITY EQU $41B8
MOVETO_IX EQU $F310
MOD16.M16_DONE EQU $4167
PMR_DONE EQU $4305
PRINT_STR_YX EQU $F378
MOVETO_IX_FF EQU $F308
SFX_DOFRAME EQU $445A
Joy_Analog EQU $F1F5
Vec_Num_Game EQU $C87A
DOT_D EQU $F2C3
Vec_SWI_Vector EQU $CBFB
Delay_RTS EQU $F57D
MOVE_MEM_A_1 EQU $F67F
sfx_m_noisedis EQU $44BE
Vec_Cold_Flag EQU $CBFE
MUSIC2 EQU $FD1D
Select_Game EQU $F7A9
DCR_INTENSITY_5F EQU $41B5
Do_Sound_x EQU $F28C
SOUND_BYTE_X EQU $F259
Init_OS EQU $F18B
Vec_Button_2_3 EQU $C818
PRINT_TEXT_STR_68021067281 EQU $4505
Reset0Ref EQU $F354
musicc EQU $FF7A
ABS_B EQU $F58B
VEC_DEFAULT_STK EQU $CBEA
sfx_updatemixer EQU $44A1
VEC_NMI_VECTOR EQU $CBFB
VEC_EXPL_CHANA EQU $C853
DELAY_RTS EQU $F57D
VEC_SEED_PTR EQU $C87B
Strip_Zeros EQU $F8B7
RANDOM_3 EQU $F511
Clear_x_b_80 EQU $F550
Vec_IRQ_Vector EQU $CBF8
Obj_Will_Hit EQU $F8F3
VEC_EXPL_3 EQU $C85A
SOUND_BYTES EQU $F27D
ADD_SCORE_A EQU $F85E
VEC_PREV_BTNS EQU $C810
Rise_Run_Len EQU $F603
Check0Ref EQU $F34F
Vec_Text_HW EQU $C82A
Rise_Run_Y EQU $F601
Obj_Will_Hit_u EQU $F8E5
MOD16.M16_RPOS EQU $4148
sfx_doframe EQU $445A
DELAY_3 EQU $F56D
MOV_DRAW_VLC_A EQU $F3AD
Vec_Str_Ptr EQU $C82C
SET_REFRESH EQU $F1A2
VEC_BRIGHTNESS EQU $C827
Dot_d EQU $F2C3
XFORM_RISE_A EQU $F661
DRAW_LINE_D EQU $F3DF
music6 EQU $FE76
Init_Music_Buf EQU $F533
VEC_EXPL_2 EQU $C859
DRAW_VLP_7F EQU $F408
MOVETO_IX_A EQU $F30E
MUSIC4 EQU $FDD3
Vec_Counter_4 EQU $C831
INTENSITY_1F EQU $F29D
AU_MUSIC_READ_COUNT EQU $43DC
MOVETO_X_7F EQU $F2F2
Vec_Button_2_4 EQU $C819
MOVETO_D_7F EQU $F2FC
sfx_endofeffect EQU $44CD
VEC_0REF_ENABLE EQU $C824
Mov_Draw_VL_a EQU $F3B9
music7 EQU $FEC6
VEC_COLD_FLAG EQU $CBFE
VEC_MUSIC_FREQ EQU $C861
DOT_IX_B EQU $F2BE
MUSIC8 EQU $FEF8
PRINT_LIST_HW EQU $F385
DCR_after_intensity EQU $41B8
MUSICB EQU $FF62
VEC_ADSR_TABLE EQU $C84F
CHECK0REF EQU $F34F
Vec_RiseRun_Tmp EQU $C834
DO_SOUND_X EQU $F28C
Intensity_1F EQU $F29D
VEC_MAX_GAMES EQU $C850
AU_MUSIC_DONE EQU $440E
Draw_Line_d EQU $F3DF
Dec_6_Counters EQU $F55E
Rot_VL_dft EQU $F637
VEC_BUTTON_1_4 EQU $C815
Dot_List_Reset EQU $F2DE
SFX_M_WRITE EQU $44C0
VEC_DURATION EQU $C857
VEC_NUM_PLAYERS EQU $C879
Init_OS_RAM EQU $F164
Get_Run_Idx EQU $F5DB
INTENSITY_A EQU $F2AB
VEC_RANDOM_SEED EQU $C87D
Vec_High_Score EQU $CBEB
music1 EQU $FD0D
SOUND_BYTE EQU $F256
Moveto_ix_FF EQU $F308
VEC_JOY_2_X EQU $C81D
PRINT_LIST_CHK EQU $F38C
VEC_EXPL_CHAN EQU $C85C
Vec_Music_Work EQU $C83F
VEC_BUTTON_2_2 EQU $C817
MUSIC9 EQU $FF26
MOV_DRAW_VL_D EQU $F3BE
DRAW_VLP_FF EQU $F404
Dot_ix_b EQU $F2BE
VECTREX_PRINT_NUMBER.PN_D1000 EQU $40A2
Vec_Music_Wk_6 EQU $C846
STRIP_ZEROS EQU $F8B7
Vec_Expl_Chan EQU $C85C
AU_MUSIC_PROCESS_WRITES EQU $43F5
MOV_DRAW_VL EQU $F3BC
INIT_MUSIC_CHK EQU $F687
PSG_MUSIC_ENDED EQU $435A
EXPLOSION_SND EQU $F92E
AU_MUSIC_READ EQU $43CB
COLD_START EQU $F000
ROT_VL_MODE_A EQU $F61F
Vec_Joy_Mux_2_Y EQU $C822
Clear_x_b EQU $F53F
CLEAR_X_B_A EQU $F552
Clear_x_256 EQU $F545
NOAY EQU $4459
Vec_ADSR_Table EQU $C84F
Mov_Draw_VLc_a EQU $F3AD
NEW_HIGH_SCORE EQU $F8D8
XFORM_RUN EQU $F65D
sfx_checktonefreq EQU $446D
Vec_Button_1_4 EQU $C815
SOUND_BYTE_RAW EQU $F25B
Xform_Rise EQU $F663
VEC_BUTTON_1_2 EQU $C813
SFX_CHECKNOISEFREQ EQU $4487
RESET0INT EQU $F36B
Recalibrate EQU $F2E6
VEC_SND_SHADOW EQU $C800
Vec_RiseRun_Len EQU $C83B
MUSIC1 EQU $FD0D
BITMASK_A EQU $F57E
Sound_Bytes EQU $F27D
Vec_Default_Stk EQU $CBEA
Vec_Rise_Index EQU $C839
Delay_3 EQU $F56D
DO_SOUND EQU $F289
sfx_nextframe EQU $44C8
VECTREX_PRINT_NUMBER.PN_AFTER_CONVERT EQU $40E7
MUSIC6 EQU $FE76
Clear_C8_RAM EQU $F542
Vec_SWI2_Vector EQU $CBF2
VEC_HIGH_SCORE EQU $CBEB
VEC_EXPL_CHANS EQU $C854
Rot_VL EQU $F616
DELAY_0 EQU $F579
Draw_Pat_VL_a EQU $F434
ROT_VL_AB EQU $F610
Intensity_a EQU $F2AB
XFORM_RUN_A EQU $F65B
VECTREX_PRINT_NUMBER.PN_L100 EQU $40AA
Clear_x_d EQU $F548
Vec_Run_Index EQU $C837
J1Y_BUILTIN EQU $4168
DOT_LIST_RESET EQU $F2DE
VEC_TWANG_TABLE EQU $C851
VECTREX_PRINT_NUMBER.PN_DIV1000 EQU $408E
Draw_VLcs EQU $F3D6
VEC_TEXT_HW EQU $C82A
Vec_Counter_6 EQU $C833
PLAY_SFX_RUNTIME EQU $4446
Moveto_ix EQU $F310
GET_RISE_RUN EQU $F5EF
Clear_Sound EQU $F272
GET_RISE_IDX EQU $F5D9
SFX_M_NOISE EQU $44B3
Draw_VL EQU $F3DD
SFX_UPDATE EQU $444F
CLEAR_X_B_80 EQU $F550
VEC_EXPL_1 EQU $C858
musica EQU $FF44
Vec_0Ref_Enable EQU $C824
AU_BANK_OK EQU $43AD
AU_MUSIC_LOOP EQU $441A
SFX_CHECKTONEFREQ EQU $446D
Vec_Button_1_1 EQU $C812
DP_TO_D0 EQU $F1AA
_MUSIC1_MUSIC EQU $0000
INTENSITY_7F EQU $F2A9
DCR_intensity_5F EQU $41B5
Delay_1 EQU $F575
Vec_Max_Players EQU $C84F
New_High_Score EQU $F8D8
Moveto_d_7F EQU $F2FC
PSG_music_loop EQU $4360
VEC_MUSIC_TWANG EQU $C858
Mov_Draw_VL_d EQU $F3BE
PRINT_SHIPS EQU $F393
PRINT_TEXT_STR_1939131706 EQU $44F7
Vec_Expl_1 EQU $C858
PRINT_TEXT_STR_2140 EQU $44F4
DEC_3_COUNTERS EQU $F55A
Vec_Music_Wk_A EQU $C842
VEC_FREQ_TABLE EQU $C84D
MOD16.M16_LOOP EQU $4148
Moveto_ix_7F EQU $F30C
Vec_Dot_Dwell EQU $C828
Draw_VLp_FF EQU $F404
Init_Music_chk EQU $F687
Rot_VL_ab EQU $F610
AU_MUSIC_HAS_DELAY EQU $43EB
XFORM_RISE EQU $F663
DRAW_VLP_SCALE EQU $F40C
Vec_Snd_Shadow EQU $C800
Vec_Expl_ChanB EQU $C85D
Draw_Grid_VL EQU $FF9F
INIT_VIA EQU $F14C
Warm_Start EQU $F06C
DRAW_VL_A EQU $F3DA
INTENSITY_3F EQU $F2A1
Vec_Button_1_2 EQU $C813
Add_Score_d EQU $F87C
INTENSITY_5F EQU $F2A5
sfx_m_tonedis EQU $44B1
Vec_Rfrsh EQU $C83D
PSG_update_done EQU $4368
Vec_Random_Seed EQU $C87D
SFX_M_TONEDIS EQU $44B1
sfx_checkvolume EQU $4498
VEC_ADSR_TIMERS EQU $C85E
Random_3 EQU $F511
Print_List EQU $F38A
RANDOM EQU $F517
DRAW_VLP EQU $F410
Vec_Button_1_3 EQU $C814
CLEAR_SCORE EQU $F84F
MOV_DRAW_VL_AB EQU $F3B7
VEC_STR_PTR EQU $C82C
VEC_MUSIC_CHAN EQU $C855
VEC_LOOP_COUNT EQU $C825
PMR_START_NEW EQU $42D3
Vec_Music_Ptr EQU $C853
DEC_COUNTERS EQU $F563
VEC_RISE_INDEX EQU $C839
JOY_ANALOG EQU $F1F5
Sound_Byte EQU $F256
Dot_List EQU $F2D5
Read_Btns EQU $F1BA
Abs_b EQU $F58B
Vec_FIRQ_Vector EQU $CBF5
VEC_BUTTONS EQU $C811
Move_Mem_a EQU $F683
PSG_music_ended EQU $435A
ASSET_ADDR_TABLE EQU $4004
music2 EQU $FD1D
Set_Refresh EQU $F1A2
Delay_0 EQU $F579
Vec_Text_Width EQU $C82B
Add_Score_a EQU $F85E
Draw_VLp_scale EQU $F40C
PRINT_SHIPS_X EQU $F391
Vec_Expl_Timer EQU $C877
DELAY_2 EQU $F571
VEC_COUNTER_1 EQU $C82E
Move_Mem_a_1 EQU $F67F
Cold_Start EQU $F000
sfx_checknoisefreq EQU $4487
MUSIC_BANK_TABLE EQU $4000
Print_Ships_x EQU $F391
VEC_MUSIC_WK_1 EQU $C84B
Moveto_ix_a EQU $F30E
VEC_DOT_DWELL EQU $C828
CLEAR_SOUND EQU $F272
Rise_Run_X EQU $F5FF
VEC_RFRSH_HI EQU $C83E
VEC_JOY_MUX_1_Y EQU $C820
MUSICA EQU $FF44
DRAW_VL_MODE EQU $F46E
VEC_COUNTER_4 EQU $C831
Vec_NMI_Vector EQU $CBFB
Vec_Pattern EQU $C829
music3 EQU $FD81
Draw_VL_a EQU $F3DA
Vec_Music_Flag EQU $C856
Vec_Expl_ChanA EQU $C853
RISE_RUN_ANGLE EQU $F593
Print_List_hw EQU $F385
Draw_VLc EQU $F3CE
Vec_Button_2_1 EQU $C816
PLAY_MUSIC_RUNTIME EQU $42C5
RISE_RUN_Y EQU $F601
OBJ_WILL_HIT_U EQU $F8E5
Delay_b EQU $F57A
VEC_SWI3_VECTOR EQU $CBF2
Draw_VL_mode EQU $F46E
VEC_RISERUN_TMP EQU $C834
VECTREX_PRINT_NUMBER.PN_L10 EQU $40C4
Intensity_5F EQU $F2A5
SFX_M_NOISEDIS EQU $44BE
AU_UPDATE_SFX EQU $4428
Rot_VL_Mode EQU $F62B
PSG_FRAME_DONE EQU $4354
STOP_MUSIC_RUNTIME EQU $436C
Get_Rise_Run EQU $F5EF
Vec_Counter_2 EQU $C82F
ABS_A_B EQU $F584
VEC_EXPL_4 EQU $C85B
VEC_COUNTER_2 EQU $C82F
Vec_Max_Games EQU $C850
VECTREX_PRINT_NUMBER.PN_D10 EQU $40D6
RISE_RUN_X EQU $F5FF
COMPARE_SCORE EQU $F8C7
Vec_Music_Freq EQU $C861
DP_to_D0 EQU $F1AA
Vec_Expl_3 EQU $C85A
sfx_m_noise EQU $44B3
VEC_MUSIC_WORK EQU $C83F
INIT_MUSIC_BUF EQU $F533
INIT_OS_RAM EQU $F164
SELECT_GAME EQU $F7A9
DRAW_VLP_B EQU $F40E
Print_Str EQU $F495
MOD16.M16_DPOS EQU $4131
Intensity_3F EQU $F2A1
PRINT_STR_D EQU $F37A
Vec_Seed_Ptr EQU $C87B
MOD16.M16_END EQU $4158
DRAW_CIRCLE_RUNTIME EQU $4180
Mov_Draw_VL_ab EQU $F3B7
VEC_JOY_1_X EQU $C81B
VEC_JOY_1_Y EQU $C81C
Reset_Pen EQU $F35B
PLAY_MUSIC_BANKED EQU $4006
VEC_EXPL_CHANB EQU $C85D
PRINT_STR EQU $F495
Wait_Recal EQU $F192
VEC_BTN_STATE EQU $C80F
VEC_MUSIC_WK_6 EQU $C846
VEC_MUSIC_WK_7 EQU $C845
Compare_Score EQU $F8C7
Read_Btns_Mask EQU $F1B4
Vec_Music_Wk_7 EQU $C845
Reset0Int EQU $F36B
VEC_JOY_MUX_2_Y EQU $C822
Vec_Freq_Table EQU $C84D
PRINT_LIST EQU $F38A
VEC_RFRSH_LO EQU $C83D
Draw_VLp_b EQU $F40E
Dot_ix EQU $F2C1
VEC_JOY_MUX_2_X EQU $C821
Vec_Counter_1 EQU $C82E
VEC_TEXT_HEIGHT EQU $C82A
Vec_Joy_2_Y EQU $C81E
Dec_Counters EQU $F563
DRAW_VLC EQU $F3CE
VEC_COUNTER_5 EQU $C832
Vec_Expl_2 EQU $C859
DRAW_PAT_VL_A EQU $F434
Clear_x_b_a EQU $F552
Vec_Misc_Count EQU $C823
VEC_MUSIC_FLAG EQU $C856
VEC_PATTERN EQU $C829
music9 EQU $FF26
DRAW_VL_AB EQU $F3D8
RECALIBRATE EQU $F2E6
Vec_Rfrsh_lo EQU $C83D
PSG_UPDATE_DONE EQU $4368
DRAW_VL EQU $F3DD
Mov_Draw_VL_b EQU $F3B1
MOVE_MEM_A EQU $F683
Draw_Pat_VL EQU $F437
VECTREX_PRINT_NUMBER.PN_L1000 EQU $4090
WARM_START EQU $F06C
PRINT_TEXT_STR_2109 EQU $44F1
Vec_Counters EQU $C82E
Get_Rise_Idx EQU $F5D9
AUDIO_UPDATE EQU $4393
VEC_EXPL_FLAG EQU $C867
DRAW_GRID_VL EQU $FF9F
Vec_Buttons EQU $C811
Vec_Duration EQU $C857
Draw_Pat_VL_d EQU $F439
VEC_MAX_PLAYERS EQU $C84F
VEC_IRQ_VECTOR EQU $CBF8
Clear_Score EQU $F84F
Vec_Expl_Flag EQU $C867
PRINT_TEXT_STR_2078 EQU $44EE
DELAY_1 EQU $F575
SFX_UPDATEMIXER EQU $44A1
DP_to_C8 EQU $F1AF
INIT_OS EQU $F18B
Print_Str_yx EQU $F378
VEC_RFRSH EQU $C83D
DELAY_B EQU $F57A
DOT_HERE EQU $F2C5
OBJ_HIT EQU $F8FF
musicd EQU $FF8F
MUSIC7 EQU $FEC6
Vec_Button_2_2 EQU $C817
Vec_ADSR_Timers EQU $C85E
VECTREX_PRINT_NUMBER EQU $406E
Xform_Run EQU $F65D
PRINT_TEXT_STR_57694326909443 EQU $450D
VEC_MUSIC_WK_A EQU $C842
Vec_Btn_State EQU $C80F
READ_BTNS_MASK EQU $F1B4
PSG_frame_done EQU $4354
music5 EQU $FE38
MOVETO_IX_7F EQU $F30C
Dec_3_Counters EQU $F55A
Vec_Text_Height EQU $C82A
Vec_Music_Wk_1 EQU $C84B
RESET_PEN EQU $F35B
CLEAR_C8_RAM EQU $F542
PMr_start_new EQU $42D3
DOT_IX EQU $F2C1
DRAW_PAT_VL EQU $F437
Init_Music EQU $F68D
VEC_SWI2_VECTOR EQU $CBF2
MOD16.M16_RCHECK EQU $4139
PSG_MUSIC_LOOP EQU $4360
PSG_write_loop EQU $4323
WAIT_RECAL EQU $F192
Random EQU $F517
music4 EQU $FDD3
VEC_ANGLE EQU $C836
SFX_NEXTFRAME EQU $44C8
PRINT_TEXT_STR_2047 EQU $44EB
SFX_ENDOFEFFECT EQU $44CD
sfx_m_write EQU $44C0
SOUND_BYTES_X EQU $F284
MUSICD EQU $FF8F
VEC_RUN_INDEX EQU $C837
Vec_Joy_Mux_2_X EQU $C821
Vec_Expl_Chans EQU $C854
READ_BTNS EQU $F1BA
RESET0REF EQU $F354
Reset0Ref_D0 EQU $F34A
DRAW_VLCS EQU $F3D6
Explosion_Snd EQU $F92E
Vec_Num_Players EQU $C879
Mov_Draw_VLcs EQU $F3B5
Vec_Music_Twang EQU $C858
Vec_Angle EQU $C836
VECTREX_PRINT_NUMBER.PN_D100 EQU $40BC
Vec_Joy_Mux_1_Y EQU $C820
Init_VIA EQU $F14C
Sound_Byte_raw EQU $F25B
AU_MUSIC_WRITE_LOOP EQU $43F7
DRAW_VL_B EQU $F3D2
ARRAY_ITEM_SCORE_DATA EQU $451F
VEC_BUTTON_1_3 EQU $C814
Vec_Expl_4 EQU $C85B
ROT_VL_MODE EQU $F62B
VEC_JOY_MUX EQU $C81F
VECTREX_PRINT_TEXT EQU $403E
VEC_BUTTON_2_1 EQU $C816
MUSIC5 EQU $FE38
Print_Ships EQU $F393
Dot_here EQU $F2C5
INIT_MUSIC_X EQU $F692
Vec_Joy_Mux_1_X EQU $C81F
ASSET_BANK_TABLE EQU $4003
MOV_DRAW_VL_B EQU $F3B1
Draw_VLp_7F EQU $F408
VEC_MUSIC_PTR EQU $C853
Draw_VL_b EQU $F3D2
Vec_Joy_1_X EQU $C81B
MOV_DRAW_VLCS EQU $F3B5
Vec_Music_Chan EQU $C855
MUSIC3 EQU $FD81
MOV_DRAW_VL_A EQU $F3B9
UPDATE_MUSIC_PSG EQU $4306
Xform_Run_a EQU $F65B
DRAW_PAT_VL_D EQU $F439
VEC_COUNTER_6 EQU $C833
VEC_NUM_GAME EQU $C87A
Vec_Joy_2_X EQU $C81D
Vec_Joy_1_Y EQU $C81C
PRINT_TEXT_STR_3232159404 EQU $44FE
AU_SKIP_MUSIC EQU $4425
Moveto_x_7F EQU $F2F2
Draw_VLp EQU $F410
VEC_FIRQ_VECTOR EQU $CBF5
ADD_SCORE_D EQU $F87C
VEC_BUTTON_2_3 EQU $C818
MUSIC_ADDR_TABLE EQU $4001
Vec_Brightness EQU $C827
Print_Str_d EQU $F37A
DP_TO_C8 EQU $F1AF
MOVETO_D EQU $F312
PSG_WRITE_LOOP EQU $4323
PMr_done EQU $4305
RISE_RUN_LEN EQU $F603
Do_Sound EQU $F289
Vec_Joy_Mux EQU $C81F
Sound_Bytes_x EQU $F284
DEC_6_COUNTERS EQU $F55E
VEC_MISC_COUNT EQU $C823
Draw_VL_ab EQU $F3D8
Obj_Hit EQU $F8FF
VEC_SWI_VECTOR EQU $CBFB
VEC_RISERUN_LEN EQU $C83B
VEC_JOY_2_Y EQU $C81E
ROT_VL EQU $F616
PRINT_STR_HWYX EQU $F373
Vec_Counter_5 EQU $C832
Vec_Rfrsh_hi EQU $C83E
AU_MUSIC_NO_DELAY EQU $43DC
musicb EQU $FF62
Vec_Music_Wk_5 EQU $C847
Rot_VL_Mode_a EQU $F61F
Vec_SWI3_Vector EQU $CBF2
VEC_JOY_MUX_1_X EQU $C81F
noay EQU $4459
MOD16 EQU $4114
Vec_Loop_Count EQU $C825
Vec_Joy_Resltn EQU $C81A
MUSICC EQU $FF7A
ROT_VL_DFT EQU $F637
VEC_JOY_RESLTN EQU $C81A
music8 EQU $FEF8
VEC_COUNTER_3 EQU $C830
CLEAR_X_D EQU $F548
VEC_EXPL_TIMER EQU $C877
CLEAR_X_256 EQU $F545
Intensity_7F EQU $F2A9
INIT_MUSIC EQU $F68D
GET_RUN_IDX EQU $F5DB
JOY_DIGITAL EQU $F1F8
ARRAY_ROW_Y_DATA EQU $4517
Init_Music_x EQU $F692
Delay_2 EQU $F571
VEC_BUTTON_1_1 EQU $C812
Mov_Draw_VL EQU $F3BC
SFX_CHECKVOLUME EQU $4498
Bitmask_a EQU $F57E
Print_Str_hwyx EQU $F373
Abs_a_b EQU $F584
VEC_TEXT_WIDTH EQU $C82B
Rise_Run_Angle EQU $F593
Vec_Twang_Table EQU $C851
AU_MUSIC_ENDED EQU $4414
CLEAR_X_B EQU $F53F


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "ARRAYS"
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
    JSR $F533        ; Init_Music_Buf: init BIOS sound work buffer at Vec_Default_Stk
    ; Initialize bank tracking vars to 0 (prevents spurious $DF00 writes)
    LDA #0
    STA >CURRENT_ROM_BANK   ; Bank 0 is always active at boot
    ; Initialize audio system variables to prevent random noise on startup
    CLR >SFX_ACTIVE         ; Mark SFX as inactive (0=off)
    LDD #$0000
    STD >SFX_PTR            ; Clear SFX pointer
    STA >PSG_MUSIC_BANK     ; Bank 0 for music (prevents garbage bank switch in emulator)
    STA >SFX_BANK           ; Bank 0 for SFX (prevents garbage bank switch in emulator)
    CLR >PSG_IS_PLAYING     ; No music playing at startup
    CLR >PSG_DELAY_FRAMES   ; Clear delay counter
    STD >PSG_MUSIC_PTR      ; Clear music pointer (D is already 0)
    STD >PSG_MUSIC_START    ; Clear loop pointer
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
NUM_STR              EQU $C880+$0E   ; Buffer for PRINT_NUMBER decimal output (5 digits + terminator) (6 bytes)
DRAW_CIRCLE_XC       EQU $C880+$14   ; Circle center X (1 bytes)
DRAW_CIRCLE_YC       EQU $C880+$15   ; Circle center Y (1 bytes)
DRAW_CIRCLE_DIAM     EQU $C880+$16   ; Circle diameter (1 bytes)
DRAW_CIRCLE_INTENSITY EQU $C880+$17   ; Circle intensity (1 bytes)
DRAW_CIRCLE_RADIUS   EQU $C880+$18   ; Circle radius (diam/2) - used in segment drawing (1 bytes)
DRAW_CIRCLE_TEMP     EQU $C880+$19   ; Circle temporary buffer (8 bytes: radius16, a, b, c, d, --, --)  a=0.383r b=0.324r c=0.217r d=0.076r (8 bytes)
DRAW_LINE_ARGS       EQU $C880+$21   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$2B   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$2D   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$2F   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$30   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$31   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$33   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$35   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$36   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_NUM_ITEMS        EQU $C880+$37   ; User variable: NUM_ITEMS (2 bytes)
VAR_ROW_Y            EQU $C880+$39   ; User variable: row_y (2 bytes)
VAR_SELECTED         EQU $C880+$3B   ; User variable: selected (2 bytes)
VAR_COOLDOWN         EQU $C880+$3D   ; User variable: cooldown (2 bytes)
VAR_JOY_Y            EQU $C880+$3F   ; User variable: joy_y (2 bytes)
VAR_CUR_SCORE        EQU $C880+$41   ; User variable: cur_score (2 bytes)
VAR_ITEM_SCORE       EQU $C880+$43   ; User variable: item_score (2 bytes)
VAR_ITEM_SCORE_DATA  EQU $C880+$45   ; Mutable array 'item_score' data (4 elements x 2 bytes) (8 bytes)
VAR_ARG0             EQU $CB80   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $CB82   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $CB84   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $CB86   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $CB88   ; Function argument 4 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $CB8A   ; Current ROM bank ID (multibank tracking) (1 bytes)
PSG_MUSIC_PTR        EQU $CBEB   ; PSG music data pointer (2 bytes)
PSG_MUSIC_START      EQU $CBED   ; PSG music start pointer (for loops) (2 bytes)
PSG_MUSIC_ACTIVE     EQU $CBEF   ; PSG music active flag (1 bytes)
PSG_IS_PLAYING       EQU $CBF0   ; PSG playing flag (1 bytes)
PSG_DELAY_FRAMES     EQU $CBF1   ; PSG frame delay counter (1 bytes)
PSG_MUSIC_BANK       EQU $CBF2   ; PSG music bank ID (for multibank) (1 bytes)
SFX_PTR              EQU $CBF3   ; SFX data pointer (2 bytes)
SFX_ACTIVE           EQU $CBF5   ; SFX active flag (1 bytes)
SFX_BANK             EQU $CBF6   ; SFX bank ID (for multibank) (1 bytes)

;***************************************************************************
; ARRAY DATA (ROM literals)
;***************************************************************************
; Arrays are stored in ROM and accessed via pointers
; At startup, main() initializes VAR_{name} to point to ARRAY_{name}_DATA

; Array literal for variable 'row_y' (4 elements, 2 bytes each)
MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    LDA #$F8
    STA TEXT_SCALE_H      ; Default height = -8 (normal size)
    LDA #$48
    STA TEXT_SCALE_W      ; Default width = 72 (normal size)
    ; Copy array 'item_score' from ROM to RAM (4 elements)
    LDX #ARRAY_ITEM_SCORE_DATA       ; Source: ROM array data
    LDU #VAR_ITEM_SCORE_DATA       ; Dest: RAM array space
    LDD #4        ; Number of elements
.COPY_LOOP_0:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_0 ; Loop until done (LBNE for long branch)
    LDX #VAR_ITEM_SCORE_DATA    ; Array now in RAM
    STX VAR_ITEM_SCORE
    LDD #0
    STD VAR_SELECTED
    LDD #0
    STD VAR_COOLDOWN
    LDD #0
    STD VAR_JOY_Y
    LDD #0
    STD VAR_CUR_SCORE
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
    ; PLAY_MUSIC("music1") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LDD #0
    STD VAR_SELECTED
    LDD #0
    STD VAR_COOLDOWN
    LDD #0
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ITEM_SCORE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #1
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ITEM_SCORE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #2
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ITEM_SCORE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #3
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ITEM_SCORE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    ; PRINT_TEXT: Print text at position
    LDD #-80
    STD VAR_ARG0
    LDD #120
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_1939131706      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-80
    STD VAR_ARG0
    LDD #106
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_68021067281      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-80
    STD VAR_ARG0
    LDD #92
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_57694326909443      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    JSR J1Y_BUILTIN
    STD RESULT
    STD VAR_JOY_Y
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_COOLDOWN
    CMPD TMPVAL
    LBGT .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_1
    LDD >VAR_COOLDOWN
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_COOLDOWN
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_COOLDOWN
    CMPD TMPVAL
    LBEQ .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    LBEQ IF_NEXT_3
    LDD #60
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_Y
    CMPD TMPVAL
    LBGT .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    LBEQ IF_NEXT_5
    LDD >VAR_SELECTED
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_SELECTED
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SELECTED
    CMPD TMPVAL
    LBLT .CMP_3_TRUE
    LDD #0
    LBRA .CMP_3_END
.CMP_3_TRUE:
    LDD #1
.CMP_3_END:
    LBEQ IF_NEXT_7
    LDD #0
    STD VAR_SELECTED
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
    LDD #15
    STD VAR_COOLDOWN
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    LDD #-60
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_Y
    CMPD TMPVAL
    LBLT .CMP_4_TRUE
    LDD #0
    LBRA .CMP_4_END
.CMP_4_TRUE:
    LDD #1
.CMP_4_END:
    LBEQ IF_NEXT_9
    LDD >VAR_SELECTED
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_SELECTED
    LDD #3
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SELECTED
    CMPD TMPVAL
    LBGT .CMP_5_TRUE
    LDD #0
    LBRA .CMP_5_END
.CMP_5_TRUE:
    LDD #1
.CMP_5_END:
    LBEQ IF_NEXT_11
    LDD #4  ; const NUM_ITEMS
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_SELECTED
    LBRA IF_END_10
IF_NEXT_11:
IF_END_10:
    LDD #15
    STD VAR_COOLDOWN
    LBRA IF_END_8
IF_NEXT_9:
IF_END_8:
    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed
    BITA #$01
    LBNE .J1B1_0_ON
    LDD #0
    LBRA .J1B1_0_END
.J1B1_0_ON:
    LDD #1
.J1B1_0_END:
    STD RESULT
    LBEQ IF_NEXT_13
    LDX #VAR_ITEM_SCORE_DATA  ; Array base
    LDD >VAR_SELECTED
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_CUR_SCORE
    LDD #99
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CUR_SCORE
    CMPD TMPVAL
    LBGT .CMP_6_TRUE
    LDD #0
    LBRA .CMP_6_END
.CMP_6_TRUE:
    LDD #1
.CMP_6_END:
    LBEQ IF_NEXT_15
    LDD #99
    STD VAR_CUR_SCORE
    LBRA IF_END_14
IF_NEXT_15:
IF_END_14:
    LDD >VAR_SELECTED
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ITEM_SCORE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD >VAR_CUR_SCORE
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #8
    STD VAR_COOLDOWN
    LBRA IF_END_12
IF_NEXT_13:
IF_END_12:
    LDA >$C80F   ; Vec_Btns_1: bit1=1 means btn2 pressed
    BITA #$02
    LBNE .J1B2_1_ON
    LDD #0
    LBRA .J1B2_1_END
.J1B2_1_ON:
    LDD #1
.J1B2_1_END:
    STD RESULT
    LBEQ IF_NEXT_17
    LDX #VAR_ITEM_SCORE_DATA  ; Array base
    LDD >VAR_SELECTED
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_CUR_SCORE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CUR_SCORE
    CMPD TMPVAL
    LBLT .CMP_7_TRUE
    LDD #0
    LBRA .CMP_7_END
.CMP_7_TRUE:
    LDD #1
.CMP_7_END:
    LBEQ IF_NEXT_19
    LDD #0
    STD VAR_CUR_SCORE
    LBRA IF_END_18
IF_NEXT_19:
IF_END_18:
    LDD >VAR_SELECTED
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ITEM_SCORE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD >VAR_CUR_SCORE
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #8
    STD VAR_COOLDOWN
    LBRA IF_END_16
IF_NEXT_17:
IF_END_16:
    LDA >$C80F   ; Vec_Btns_1: bit2=1 means btn3 pressed
    BITA #$04
    LBNE .J1B3_2_ON
    LDD #0
    LBRA .J1B3_2_END
.J1B3_2_ON:
    LDD #1
.J1B3_2_END:
    STD RESULT
    LBEQ IF_NEXT_21
    LDD #0
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ITEM_SCORE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #1
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ITEM_SCORE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #2
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ITEM_SCORE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #3
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ITEM_SCORE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #15
    STD VAR_COOLDOWN
    LBRA IF_END_20
IF_NEXT_21:
IF_END_20:
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    ; PRINT_TEXT: Print text at position
    LDD #-55
    STD VAR_ARG0
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2047      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #0
    STD VAR_ARG0    ; X position
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG1    ; Y position
    LDX #VAR_ITEM_SCORE_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-55
    STD VAR_ARG0
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2078      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #0
    STD VAR_ARG0    ; X position
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG1    ; Y position
    LDX #VAR_ITEM_SCORE_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-55
    STD VAR_ARG0
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2109      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #0
    STD VAR_ARG0    ; X position
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG1    ; Y position
    LDX #VAR_ITEM_SCORE_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-55
    STD VAR_ARG0
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2140      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #0
    STD VAR_ARG0    ; X position
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG1    ; Y position
    LDX #VAR_ITEM_SCORE_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD #-70
    TFR B,A
    STA DRAW_CIRCLE_XC
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD >VAR_SELECTED
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    TFR B,A
    STA DRAW_CIRCLE_YC
    LDD #8
    TFR B,A
    STA DRAW_CIRCLE_DIAM
    LDD #100
    TFR B,A
    STA DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX (after all game logic)
    RTS


; ================================================
