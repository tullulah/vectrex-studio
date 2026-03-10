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
VAR_ROW_Y            EQU $C880+$39   ; User variable: ROW_Y (2 bytes)
VAR_SELECTED         EQU $C880+$3B   ; User variable: SELECTED (2 bytes)
VAR_COOLDOWN         EQU $C880+$3D   ; User variable: COOLDOWN (2 bytes)
VAR_JOY_Y            EQU $C880+$3F   ; User variable: JOY_Y (2 bytes)
VAR_CUR_SCORE        EQU $C880+$41   ; User variable: CUR_SCORE (2 bytes)
VAR_ITEM_SCORE       EQU $C880+$43   ; User variable: ITEM_SCORE (2 bytes)
VAR_ITEM_SCORE_DATA  EQU $C880+$45   ; Mutable array 'ITEM_SCORE' data (4 elements x 2 bytes) (8 bytes)
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
RANDOM_3 EQU $F511
AU_DONE EQU $443B
INTENSITY_7F EQU $F2A9
RISE_RUN_LEN EQU $F603
Vec_Music_Chan EQU $C855
RISE_RUN_X EQU $F5FF
MOVETO_IX_7F EQU $F30C
RISE_RUN_Y EQU $F601
DOT_IX_B EQU $F2BE
SET_REFRESH EQU $F1A2
SOUND_BYTE EQU $F256
Print_List_chk EQU $F38C
Abs_b EQU $F58B
Vec_Music_Flag EQU $C856
Vec_Counter_1 EQU $C82E
VEC_MUSIC_WK_6 EQU $C846
Cold_Start EQU $F000
ARRAY_ROW_Y_DATA EQU $4517
Rot_VL_ab EQU $F610
Vec_Random_Seed EQU $C87D
Draw_VL_ab EQU $F3D8
DOT_LIST_RESET EQU $F2DE
Reset0Int EQU $F36B
Draw_Pat_VL EQU $F437
VEC_NUM_PLAYERS EQU $C879
Rot_VL EQU $F616
Vec_Counter_2 EQU $C82F
PRINT_TEXT_STR_2047 EQU $44EB
ROT_VL_MODE_A EQU $F61F
RANDOM EQU $F517
Print_Str_d EQU $F37A
PSG_WRITE_LOOP EQU $4323
Vec_Joy_Resltn EQU $C81A
Vec_Expl_Timer EQU $C877
Vec_Music_Wk_A EQU $C842
musicb EQU $FF62
GET_RUN_IDX EQU $F5DB
PLAY_MUSIC_RUNTIME EQU $42C5
Vec_Music_Wk_1 EQU $C84B
DRAW_VLP_7F EQU $F408
DELAY_0 EQU $F579
PRINT_TEXT_STR_2140 EQU $44F4
ABS_A_B EQU $F584
PRINT_SHIPS_X EQU $F391
Strip_Zeros EQU $F8B7
VEC_COUNTER_5 EQU $C832
Mov_Draw_VL_b EQU $F3B1
RECALIBRATE EQU $F2E6
SFX_NEXTFRAME EQU $44C8
VEC_BRIGHTNESS EQU $C827
SOUND_BYTE_X EQU $F259
Vec_Expl_2 EQU $C859
CLEAR_X_256 EQU $F545
INTENSITY_5F EQU $F2A5
Obj_Hit EQU $F8FF
Rise_Run_Y EQU $F601
Vec_Music_Freq EQU $C861
DRAW_PAT_VL EQU $F437
MOD16 EQU $4114
Moveto_ix_a EQU $F30E
MOVETO_IX_FF EQU $F308
VECTREX_PRINT_TEXT EQU $403E
MUSICB EQU $FF62
Vec_Expl_Chans EQU $C854
DO_SOUND_X EQU $F28C
Get_Rise_Run EQU $F5EF
PRINT_STR_D EQU $F37A
Vec_Button_1_3 EQU $C814
Vec_Rfrsh_hi EQU $C83E
Mov_Draw_VL_ab EQU $F3B7
XFORM_RUN EQU $F65D
Check0Ref EQU $F34F
DRAW_VLP_B EQU $F40E
Vec_Expl_Chan EQU $C85C
Vec_Str_Ptr EQU $C82C
Vec_Button_2_4 EQU $C819
Xform_Run_a EQU $F65B
PSG_update_done EQU $4368
VEC_DURATION EQU $C857
INIT_OS_RAM EQU $F164
DELAY_1 EQU $F575
Moveto_d_7F EQU $F2FC
PRINT_TEXT_STR_57694326909443 EQU $450D
Print_List_hw EQU $F385
Vec_Default_Stk EQU $CBEA
PSG_write_loop EQU $4323
Vec_Expl_ChanA EQU $C853
Vec_Num_Game EQU $C87A
AU_UPDATE_SFX EQU $4428
Draw_VLcs EQU $F3D6
DOT_HERE EQU $F2C5
AU_MUSIC_NO_DELAY EQU $43DC
VEC_JOY_1_Y EQU $C81C
VEC_MUSIC_WK_5 EQU $C847
NEW_HIGH_SCORE EQU $F8D8
INIT_VIA EQU $F14C
PMR_START_NEW EQU $42D3
Vec_SWI2_Vector EQU $CBF2
VEC_RUN_INDEX EQU $C837
Vec_Loop_Count EQU $C825
VEC_MAX_GAMES EQU $C850
NOAY EQU $4459
Draw_Line_d EQU $F3DF
MOVETO_X_7F EQU $F2F2
VEC_FIRQ_VECTOR EQU $CBF5
Moveto_d EQU $F312
VEC_JOY_MUX_1_X EQU $C81F
sfx_doframe EQU $445A
MOD16.M16_END EQU $4158
VEC_FREQ_TABLE EQU $C84D
DCR_INTENSITY_5F EQU $41B5
Vec_Button_1_4 EQU $C815
INTENSITY_A EQU $F2AB
VEC_JOY_MUX_1_Y EQU $C820
Vec_Expl_4 EQU $C85B
DRAW_VL_MODE EQU $F46E
Vec_Text_Width EQU $C82B
DRAW_VLCS EQU $F3D6
SFX_UPDATEMIXER EQU $44A1
Mov_Draw_VL EQU $F3BC
VEC_TEXT_HW EQU $C82A
MUSIC_BANK_TABLE EQU $4000
Dot_ix_b EQU $F2BE
Dec_3_Counters EQU $F55A
VEC_MUSIC_TWANG EQU $C858
Init_OS_RAM EQU $F164
VEC_EXPL_CHANB EQU $C85D
PRINT_LIST_HW EQU $F385
VECTREX_PRINT_NUMBER.PN_AFTER_CONVERT EQU $40E7
Vec_Freq_Table EQU $C84D
PSG_UPDATE_DONE EQU $4368
Vec_Expl_Flag EQU $C867
AU_MUSIC_READ EQU $43CB
Draw_Grid_VL EQU $FF9F
Vec_Duration EQU $C857
MOD16.M16_DONE EQU $4167
DELAY_RTS EQU $F57D
Rot_VL_dft EQU $F637
Vec_Run_Index EQU $C837
Recalibrate EQU $F2E6
MUSIC4 EQU $FDD3
VEC_MISC_COUNT EQU $C823
Abs_a_b EQU $F584
Vec_SWI3_Vector EQU $CBF2
DELAY_B EQU $F57A
Mov_Draw_VL_a EQU $F3B9
Init_Music_chk EQU $F687
Vec_Buttons EQU $C811
VECTREX_PRINT_NUMBER.PN_L100 EQU $40AA
PRINT_TEXT_STR_2078 EQU $44EE
VEC_EXPL_TIMER EQU $C877
Moveto_ix EQU $F310
Xform_Rise EQU $F663
PSG_MUSIC_LOOP EQU $4360
PRINT_STR_YX EQU $F378
AU_MUSIC_HAS_DELAY EQU $43EB
Print_List EQU $F38A
Draw_VLp_FF EQU $F404
MOVETO_IX_A EQU $F30E
Vec_Music_Wk_5 EQU $C847
Obj_Will_Hit EQU $F8F3
Select_Game EQU $F7A9
Sound_Bytes_x EQU $F284
MUSIC6 EQU $FE76
Vec_Counter_4 EQU $C831
CLEAR_X_B_A EQU $F552
RISE_RUN_ANGLE EQU $F593
musicd EQU $FF8F
VEC_SEED_PTR EQU $C87B
PRINT_LIST EQU $F38A
Draw_VL EQU $F3DD
Intensity_7F EQU $F2A9
VEC_EXPL_CHANA EQU $C853
VEC_DEFAULT_STK EQU $CBEA
VEC_EXPL_CHAN EQU $C85C
Vec_Max_Players EQU $C84F
Clear_C8_RAM EQU $F542
CLEAR_SOUND EQU $F272
MOVETO_D_7F EQU $F2FC
ROT_VL EQU $F616
Do_Sound_x EQU $F28C
PLAY_MUSIC_BANKED EQU $4006
Move_Mem_a_1 EQU $F67F
Dec_6_Counters EQU $F55E
INIT_MUSIC EQU $F68D
Rot_VL_Mode EQU $F62B
VEC_SND_SHADOW EQU $C800
VECTREX_PRINT_NUMBER.PN_L10 EQU $40C4
New_High_Score EQU $F8D8
READ_BTNS EQU $F1BA
Dot_ix EQU $F2C1
music9 EQU $FF26
SFX_CHECKTONEFREQ EQU $446D
VEC_BUTTON_1_1 EQU $C812
VECTREX_PRINT_NUMBER.PN_DIV1000 EQU $408E
sfx_nextframe EQU $44C8
AU_MUSIC_READ_COUNT EQU $43DC
UPDATE_MUSIC_PSG EQU $4306
Dot_List EQU $F2D5
Vec_Joy_2_X EQU $C81D
INIT_OS EQU $F18B
Move_Mem_a EQU $F683
Rise_Run_Angle EQU $F593
SFX_M_TONEDIS EQU $44B1
VEC_SWI_VECTOR EQU $CBFB
DP_to_C8 EQU $F1AF
Vec_Counter_3 EQU $C830
VEC_EXPL_4 EQU $C85B
music5 EQU $FE38
Draw_VLp EQU $F410
MOV_DRAW_VLCS EQU $F3B5
Delay_3 EQU $F56D
Read_Btns EQU $F1BA
Vec_SWI_Vector EQU $CBFB
VEC_PREV_BTNS EQU $C810
MUSIC3 EQU $FD81
Vec_0Ref_Enable EQU $C824
Draw_VLc EQU $F3CE
OBJ_HIT EQU $F8FF
Vec_Cold_Flag EQU $CBFE
Intensity_3F EQU $F2A1
Print_Ships EQU $F393
CLEAR_X_D EQU $F548
PSG_MUSIC_ENDED EQU $435A
VECTREX_PRINT_NUMBER.PN_L1000 EQU $4090
Rise_Run_Len EQU $F603
Compare_Score EQU $F8C7
Vec_Expl_1 EQU $C858
MOD16.M16_LOOP EQU $4148
Vec_ADSR_Table EQU $C84F
VECTREX_PRINT_NUMBER.PN_D1000 EQU $40A2
XFORM_RISE_A EQU $F661
Delay_1 EQU $F575
Print_Ships_x EQU $F391
Draw_VL_mode EQU $F46E
Vec_Joy_Mux_2_X EQU $C821
MOD16.M16_DPOS EQU $4131
RESET0INT EQU $F36B
Init_Music_x EQU $F692
Vec_Expl_3 EQU $C85A
Vec_Music_Wk_6 EQU $C846
Obj_Will_Hit_u EQU $F8E5
Vec_Dot_Dwell EQU $C828
Vec_Music_Wk_7 EQU $C845
Moveto_ix_7F EQU $F30C
MOVE_MEM_A EQU $F683
Vec_Brightness EQU $C827
music3 EQU $FD81
PMr_start_new EQU $42D3
Vec_Prev_Btns EQU $C810
Vec_Music_Work EQU $C83F
Rise_Run_X EQU $F5FF
Delay_0 EQU $F579
JOY_DIGITAL EQU $F1F8
Dot_here EQU $F2C5
PLAY_SFX_RUNTIME EQU $4446
Add_Score_a EQU $F85E
VEC_COUNTER_6 EQU $C833
SOUND_BYTES EQU $F27D
Clear_Score EQU $F84F
VEC_BTN_STATE EQU $C80F
Vec_Button_1_2 EQU $C813
music6 EQU $FE76
ASSET_ADDR_TABLE EQU $4004
MOD16.M16_RPOS EQU $4148
Init_Music_Buf EQU $F533
Vec_Counter_6 EQU $C833
MUSIC7 EQU $FEC6
Random_3 EQU $F511
VEC_ANGLE EQU $C836
Random EQU $F517
Vec_Twang_Table EQU $C851
VECTREX_PRINT_NUMBER.PN_D10 EQU $40D6
DRAW_VL_AB EQU $F3D8
VEC_TEXT_WIDTH EQU $C82B
AU_MUSIC_LOOP EQU $441A
Clear_x_256 EQU $F545
Get_Run_Idx EQU $F5DB
Vec_Rfrsh EQU $C83D
Vec_Button_2_2 EQU $C817
sfx_endofeffect EQU $44CD
DRAW_VL_A EQU $F3DA
Wait_Recal EQU $F192
MUSIC2 EQU $FD1D
EXPLOSION_SND EQU $F92E
Vec_High_Score EQU $CBEB
AU_MUSIC_ENDED EQU $4414
Explosion_Snd EQU $F92E
Dot_d EQU $F2C3
DEC_COUNTERS EQU $F563
PRINT_TEXT_STR_3232159404 EQU $44FE
PSG_music_loop EQU $4360
INTENSITY_3F EQU $F2A1
Draw_VLp_b EQU $F40E
Reset0Ref EQU $F354
VEC_NUM_GAME EQU $C87A
SFX_M_WRITE EQU $44C0
sfx_updatemixer EQU $44A1
VEC_IRQ_VECTOR EQU $CBF8
Dec_Counters EQU $F563
VEC_MUSIC_WORK EQU $C83F
Reset0Ref_D0 EQU $F34A
Vec_Joy_Mux_1_Y EQU $C820
PMR_DONE EQU $4305
MUSICA EQU $FF44
sfx_m_write EQU $44C0
SFX_CHECKVOLUME EQU $4498
VEC_RFRSH_LO EQU $C83D
DOT_LIST EQU $F2D5
Sound_Byte_x EQU $F259
MOV_DRAW_VLC_A EQU $F3AD
Vec_Counters EQU $C82E
Xform_Rise_a EQU $F661
XFORM_RUN_A EQU $F65B
Draw_VLp_7F EQU $F408
SFX_ENDOFEFFECT EQU $44CD
Init_OS EQU $F18B
MUSIC8 EQU $FEF8
DRAW_VL_B EQU $F3D2
Vec_RiseRun_Len EQU $C83B
CLEAR_SCORE EQU $F84F
MOV_DRAW_VL_B EQU $F3B1
MUSIC1 EQU $FD0D
sfx_checkvolume EQU $4498
Warm_Start EQU $F06C
VEC_MUSIC_WK_1 EQU $C84B
VEC_JOY_2_X EQU $C81D
Sound_Byte EQU $F256
VEC_RANDOM_SEED EQU $C87D
Vec_Pattern EQU $C829
VEC_RFRSH EQU $C83D
J1Y_BUILTIN EQU $4168
Vec_Misc_Count EQU $C823
DP_to_D0 EQU $F1AA
Print_Str_hwyx EQU $F373
VEC_BUTTON_1_4 EQU $C815
VEC_JOY_MUX_2_Y EQU $C822
VEC_BUTTON_1_3 EQU $C814
Init_VIA EQU $F14C
Vec_Max_Games EQU $C850
VEC_COUNTER_4 EQU $C831
Vec_Joy_1_Y EQU $C81C
SFX_M_NOISE EQU $44B3
Vec_Button_2_3 EQU $C818
Vec_Rise_Index EQU $C839
DELAY_3 EQU $F56D
_MUSIC1_MUSIC EQU $0000
DO_SOUND EQU $F289
PSG_music_ended EQU $435A
DRAW_VLC EQU $F3CE
VEC_MUSIC_WK_7 EQU $C845
GET_RISE_IDX EQU $F5D9
VEC_ADSR_TABLE EQU $C84F
ADD_SCORE_D EQU $F87C
ABS_B EQU $F58B
DRAW_CIRCLE_RUNTIME EQU $4180
AU_BANK_OK EQU $43AD
Moveto_ix_FF EQU $F308
Draw_VLp_scale EQU $F40C
VEC_MUSIC_FREQ EQU $C861
Clear_x_b_a EQU $F552
PRINT_TEXT_STR_68021067281 EQU $4505
VECTREX_PRINT_NUMBER.PN_D100 EQU $40BC
Clear_x_b_80 EQU $F550
VEC_HIGH_SCORE EQU $CBEB
WAIT_RECAL EQU $F192
music4 EQU $FDD3
VEC_EXPL_1 EQU $C858
DRAW_VLP EQU $F410
MUSIC5 EQU $FE38
Sound_Byte_raw EQU $F25B
COLD_START EQU $F000
SFX_CHECKNOISEFREQ EQU $4487
OBJ_WILL_HIT EQU $F8F3
MUSICC EQU $FF7A
VEC_PATTERN EQU $C829
DRAW_VLP_FF EQU $F404
VEC_JOY_MUX EQU $C81F
music8 EQU $FEF8
Vec_Joy_1_X EQU $C81B
PMr_done EQU $4305
DRAW_GRID_VL EQU $FF9F
VEC_JOY_2_Y EQU $C81E
Reset_Pen EQU $F35B
MUSIC9 EQU $FF26
VEC_COUNTER_1 EQU $C82E
VEC_RISE_INDEX EQU $C839
Vec_Button_1_1 EQU $C812
RESET0REF EQU $F354
Mov_Draw_VL_d EQU $F3BE
Vec_Rfrsh_lo EQU $C83D
ROT_VL_MODE EQU $F62B
Vec_Expl_ChanB EQU $C85D
VEC_BUTTONS EQU $C811
DCR_after_intensity EQU $41B8
AUDIO_UPDATE EQU $4393
VEC_JOY_RESLTN EQU $C81A
DCR_AFTER_INTENSITY EQU $41B8
ARRAY_ITEM_SCORE_DATA EQU $451F
AU_MUSIC_DONE EQU $440E
VEC_BUTTON_2_1 EQU $C816
Draw_Pat_VL_d EQU $F439
Vec_Btn_State EQU $C80F
OBJ_WILL_HIT_U EQU $F8E5
PSG_frame_done EQU $4354
sfx_m_tonedis EQU $44B1
VECTREX_PRINT_NUMBER EQU $406E
Draw_VL_b EQU $F3D2
PSG_FRAME_DONE EQU $4354
Clear_x_d EQU $F548
MOVE_MEM_A_1 EQU $F67F
Draw_VL_a EQU $F3DA
DRAW_VLP_SCALE EQU $F40C
DOT_IX EQU $F2C1
Vec_Button_2_1 EQU $C816
Joy_Digital EQU $F1F8
Mov_Draw_VLc_a EQU $F3AD
Delay_RTS EQU $F57D
COMPARE_SCORE EQU $F8C7
ROT_VL_AB EQU $F610
DRAW_VL EQU $F3DD
VEC_ADSR_TIMERS EQU $C85E
DEC_3_COUNTERS EQU $F55A
sfx_m_noise EQU $44B3
RESET0REF_D0 EQU $F34A
Vec_Joy_Mux EQU $C81F
RESET_PEN EQU $F35B
Vec_Angle EQU $C836
Sound_Bytes EQU $F27D
VEC_COUNTER_2 EQU $C82F
DEC_6_COUNTERS EQU $F55E
VEC_RISERUN_TMP EQU $C834
music2 EQU $FD1D
Vec_NMI_Vector EQU $CBFB
Moveto_x_7F EQU $F2F2
Xform_Run EQU $F65D
VEC_STR_PTR EQU $C82C
Vec_Counter_5 EQU $C832
Vec_ADSR_Timers EQU $C85E
Init_Music EQU $F68D
music7 EQU $FEC6
SOUND_BYTE_RAW EQU $F25B
DP_TO_C8 EQU $F1AF
musicc EQU $FF7A
MOD16.M16_RCHECK EQU $4139
VEC_TEXT_HEIGHT EQU $C82A
Dot_List_Reset EQU $F2DE
INIT_MUSIC_BUF EQU $F533
VEC_COLD_FLAG EQU $CBFE
Vec_Music_Ptr EQU $C853
Delay_2 EQU $F571
CLEAR_C8_RAM EQU $F542
CLEAR_X_B_80 EQU $F550
Print_Str EQU $F495
VEC_RISERUN_LEN EQU $C83B
Rot_VL_Mode_a EQU $F61F
PRINT_STR EQU $F495
VEC_SWI2_VECTOR EQU $CBF2
Intensity_a EQU $F2AB
DRAW_PAT_VL_D EQU $F439
musica EQU $FF44
VEC_RFRSH_HI EQU $C83E
Vec_Joy_Mux_1_X EQU $C81F
VEC_BUTTON_1_2 EQU $C813
CHECK0REF EQU $F34F
VEC_MUSIC_FLAG EQU $C856
AU_MUSIC_PROCESS_WRITES EQU $43F5
VEC_EXPL_FLAG EQU $C867
Get_Rise_Idx EQU $F5D9
Vec_IRQ_Vector EQU $CBF8
PRINT_LIST_CHK EQU $F38C
Vec_Snd_Shadow EQU $C800
Vec_Music_Twang EQU $C858
VEC_LOOP_COUNT EQU $C825
DRAW_PAT_VL_A EQU $F434
music1 EQU $FD0D
PRINT_TEXT_STR_1939131706 EQU $44F7
Vec_Joy_Mux_2_Y EQU $C822
Print_Str_yx EQU $F378
SFX_M_NOISEDIS EQU $44BE
ADD_SCORE_A EQU $F85E
VEC_BUTTON_2_2 EQU $C817
VEC_MUSIC_CHAN EQU $C855
AU_SKIP_MUSIC EQU $4425
Draw_Pat_VL_a EQU $F434
BITMASK_A EQU $F57E
MOVETO_D EQU $F312
Vec_Joy_2_Y EQU $C81E
VEC_JOY_MUX_2_X EQU $C821
Vec_Seed_Ptr EQU $C87B
noay EQU $4459
CLEAR_X_B EQU $F53F
INIT_MUSIC_X EQU $F692
VEC_EXPL_2 EQU $C859
Add_Score_d EQU $F87C
SELECT_GAME EQU $F7A9
Vec_RiseRun_Tmp EQU $C834
STRIP_ZEROS EQU $F8B7
AU_MUSIC_WRITE_LOOP EQU $43F7
Mov_Draw_VLcs EQU $F3B5
VEC_NMI_VECTOR EQU $CBFB
Set_Refresh EQU $F1A2
MOV_DRAW_VL_D EQU $F3BE
VEC_EXPL_CHANS EQU $C854
INIT_MUSIC_CHK EQU $F687
SOUND_BYTES_X EQU $F284
Vec_Num_Players EQU $C879
VEC_MUSIC_WK_A EQU $C842
STOP_MUSIC_RUNTIME EQU $436C
VEC_COUNTER_3 EQU $C830
DRAW_LINE_D EQU $F3DF
VEC_JOY_1_X EQU $C81B
ASSET_BANK_TABLE EQU $4003
WARM_START EQU $F06C
XFORM_RISE EQU $F663
MUSICD EQU $FF8F
MOVETO_IX EQU $F310
sfx_checknoisefreq EQU $4487
VEC_MAX_PLAYERS EQU $C84F
MOV_DRAW_VL EQU $F3BC
Vec_FIRQ_Vector EQU $CBF5
Read_Btns_Mask EQU $F1B4
Vec_Text_HW EQU $C82A
PRINT_SHIPS EQU $F393
SFX_DOFRAME EQU $445A
Joy_Analog EQU $F1F5
INTENSITY_1F EQU $F29D
VEC_SWI3_VECTOR EQU $CBF2
MOV_DRAW_VL_A EQU $F3B9
VEC_DOT_DWELL EQU $C828
Do_Sound EQU $F289
VEC_BUTTON_2_4 EQU $C819
MUSIC_ADDR_TABLE EQU $4001
Clear_Sound EQU $F272
DELAY_2 EQU $F571
Delay_b EQU $F57A
VEC_COUNTERS EQU $C82E
JOY_ANALOG EQU $F1F5
GET_RISE_RUN EQU $F5EF
VEC_BUTTON_2_3 EQU $C818
MOV_DRAW_VL_AB EQU $F3B7
PRINT_TEXT_STR_2109 EQU $44F1
VEC_MUSIC_PTR EQU $C853
SFX_UPDATE EQU $444F
Clear_x_b EQU $F53F
READ_BTNS_MASK EQU $F1B4
VEC_0REF_ENABLE EQU $C824
DCR_intensity_5F EQU $41B5
Bitmask_a EQU $F57E
sfx_m_noisedis EQU $44BE
ROT_VL_DFT EQU $F637
Intensity_1F EQU $F29D
Vec_Text_Height EQU $C82A
PRINT_STR_HWYX EQU $F373
sfx_checktonefreq EQU $446D
DOT_D EQU $F2C3
VEC_TWANG_TABLE EQU $C851
Intensity_5F EQU $F2A5
VEC_EXPL_3 EQU $C85A
DP_TO_D0 EQU $F1AA


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
VAR_ROW_Y            EQU $C880+$39   ; User variable: ROW_Y (2 bytes)
VAR_SELECTED         EQU $C880+$3B   ; User variable: SELECTED (2 bytes)
VAR_COOLDOWN         EQU $C880+$3D   ; User variable: COOLDOWN (2 bytes)
VAR_JOY_Y            EQU $C880+$3F   ; User variable: JOY_Y (2 bytes)
VAR_CUR_SCORE        EQU $C880+$41   ; User variable: CUR_SCORE (2 bytes)
VAR_ITEM_SCORE       EQU $C880+$43   ; User variable: ITEM_SCORE (2 bytes)
VAR_ITEM_SCORE_DATA  EQU $C880+$45   ; Mutable array 'ITEM_SCORE' data (4 elements x 2 bytes) (8 bytes)
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

; Array literal for variable 'ROW_Y' (4 elements, 2 bytes each)
MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    LDA #$F8
    STA TEXT_SCALE_H      ; Default height = -8 (normal size)
    LDA #$48
    STA TEXT_SCALE_W      ; Default width = 72 (normal size)
    ; Copy array 'ITEM_SCORE' from ROM to RAM (4 elements)
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
