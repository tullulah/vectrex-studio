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
DRAW_VEC_X_HI        EQU $C880+$0F   ; Vector draw X high byte (16-bit screen_x) (1 bytes)
DRAW_VEC_X           EQU $C880+$10   ; Vector draw X offset (1 bytes)
DRAW_VEC_Y           EQU $C880+$11   ; Vector draw Y offset (1 bytes)
MIRROR_PAD           EQU $C880+$12   ; Safety padding to prevent MIRROR flag corruption (16 bytes)
MIRROR_X             EQU $C880+$22   ; X mirror flag (0=normal, 1=flip) (1 bytes)
MIRROR_Y             EQU $C880+$23   ; Y mirror flag (0=normal, 1=flip) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$24   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$2E   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$30   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$32   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$33   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$34   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$36   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$38   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$39   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_BX               EQU $C880+$3A   ; User variable: BX (2 bytes)
VAR_BY               EQU $C880+$3C   ; User variable: BY (2 bytes)
VAR_VX               EQU $C880+$3E   ; User variable: VX (2 bytes)
VAR_VY               EQU $C880+$40   ; User variable: VY (2 bytes)
VAR_JX               EQU $C880+$42   ; User variable: JX (2 bytes)
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
DSWM_NO_NEGATE_DY EQU $42F2
Reset0Ref_D0 EQU $F34A
CLEAR_SOUND EQU $F272
CLEAR_SCORE EQU $F84F
VEC_COLD_FLAG EQU $CBFE
Vec_Counters EQU $C82E
DSWM_W2 EQU $4313
noay EQU $4545
ROT_VL_MODE_A EQU $F61F
VEC_MUSIC_PTR EQU $C853
Vec_Text_Height EQU $C82A
Vec_Text_HW EQU $C82A
ROT_VL_DFT EQU $F637
RESET0REF EQU $F354
Vec_0Ref_Enable EQU $C824
J1X_BUILTIN EQU $413E
VEC_COUNTER_5 EQU $C832
RECALIBRATE EQU $F2E6
VEC_IRQ_VECTOR EQU $CBF8
Draw_VLp_FF EQU $F404
VEC_EXPL_CHANS EQU $C854
SFX_NEXTFRAME EQU $45B4
Clear_x_b_80 EQU $F550
PMR_START_NEW EQU $43BF
AU_UPDATE_SFX EQU $4514
VEC_COUNTER_1 EQU $C82E
Print_List EQU $F38A
SET_REFRESH EQU $F1A2
VEC_DEFAULT_STK EQU $CBEA
SFX_CHECKNOISEFREQ EQU $4573
XFORM_RISE EQU $F663
MUSIC4 EQU $FDD3
CLEAR_X_D EQU $F548
VEC_JOY_2_X EQU $C81D
Warm_Start EQU $F06C
INIT_MUSIC_CHK EQU $F687
Init_OS EQU $F18B
Intensity_5F EQU $F2A5
DP_to_C8 EQU $F1AF
Dot_ix_b EQU $F2BE
Moveto_d EQU $F312
INIT_MUSIC_X EQU $F692
MOVETO_D EQU $F312
AU_MUSIC_PROCESS_WRITES EQU $44E1
VEC_PREV_BTNS EQU $C810
SFX_M_NOISE EQU $459F
XFORM_RISE_A EQU $F661
Vec_Default_Stk EQU $CBEA
VEC_JOY_2_Y EQU $C81E
MUSIC_ADDR_TABLE EQU $4004
DOT_D EQU $F2C3
INIT_VIA EQU $F14C
DRAW_VLP_7F EQU $F408
Clear_x_b_a EQU $F552
Vec_Button_2_2 EQU $C817
MOV_DRAW_VLC_A EQU $F3AD
Read_Btns EQU $F1BA
Get_Rise_Idx EQU $F5D9
DOT_IX_B EQU $F2BE
DRAW_VL_AB EQU $F3D8
Obj_Will_Hit_u EQU $F8E5
VEC_HIGH_SCORE EQU $CBEB
PRINT_STR EQU $F495
Reset0Int EQU $F36B
PRINT_TEXT_STR_73146331687 EQU $45EF
Print_Str_d EQU $F37A
VEC_DOT_DWELL EQU $C828
Print_List_hw EQU $F385
DLW_SEG1_DX_LO EQU $41BB
STRIP_ZEROS EQU $F8B7
music8 EQU $FEF8
Vec_ADSR_Timers EQU $C85E
Xform_Rise_a EQU $F661
music2 EQU $FD1D
Rot_VL_ab EQU $F610
MUSIC2 EQU $FD1D
Vec_Expl_Chans EQU $C854
Draw_VL_b EQU $F3D2
Dec_3_Counters EQU $F55A
Vec_Button_1_3 EQU $C814
Vec_Max_Games EQU $C850
VEC_MUSIC_WK_5 EQU $C847
Vec_Music_Wk_6 EQU $C846
BITMASK_A EQU $F57E
Init_Music_x EQU $F692
Draw_VL_mode EQU $F46E
MOVE_MEM_A_1 EQU $F67F
Vec_Button_2_4 EQU $C819
sfx_m_write EQU $45AC
Vec_Misc_Count EQU $C823
ASSET_BANK_TABLE EQU $400C
MOV_DRAW_VL_D EQU $F3BE
VEC_NUM_GAME EQU $C87A
Draw_Sync_List_At_With_Mirrors EQU $425E
Xform_Run EQU $F65D
INTENSITY_1F EQU $F29D
VEC_BUTTON_1_2 EQU $C813
VEC_BUTTON_2_3 EQU $C818
PLAY_SFX_RUNTIME EQU $4532
Delay_2 EQU $F571
Wait_Recal EQU $F192
RESET0REF_D0 EQU $F34A
MUSICA EQU $FF44
MUSIC_BANK_TABLE EQU $4003
SOUND_BYTES_X EQU $F284
INIT_MUSIC EQU $F68D
music6 EQU $FE76
Vec_Music_Wk_A EQU $C842
DP_to_D0 EQU $F1AA
AU_MUSIC_LOOP EQU $4506
DELAY_B EQU $F57A
Vec_Str_Ptr EQU $C82C
DELAY_3 EQU $F56D
VEC_RISERUN_LEN EQU $C83B
DRAW_SYNC_LIST_AT_WITH_MIRRORS EQU $425E
DELAY_1 EQU $F575
DRAW_VL_B EQU $F3D2
COLD_START EQU $F000
ABS_A_B EQU $F584
Vec_Prev_Btns EQU $C810
DSWM_NEXT_SET_INTENSITY EQU $4328
Draw_Grid_VL EQU $FF9F
MUSICD EQU $FF8F
sfx_checktonefreq EQU $4559
VEC_TEXT_WIDTH EQU $C82B
VEC_NMI_VECTOR EQU $CBFB
VEC_STR_PTR EQU $C82C
Reset_Pen EQU $F35B
sfx_doframe EQU $4546
VEC_MAX_GAMES EQU $C850
Vec_High_Score EQU $CBEB
COMPARE_SCORE EQU $F8C7
VEC_RISERUN_TMP EQU $C834
MOD16.M16_RPOS EQU $411E
PRINT_STR_HWYX EQU $F373
MOD16.M16_DPOS EQU $4107
DRAW_VL_A EQU $F3DA
ROT_VL_MODE EQU $F62B
VEC_MUSIC_FREQ EQU $C861
Vec_Num_Game EQU $C87A
Vec_ADSR_Table EQU $C84F
Init_OS_RAM EQU $F164
Vec_Expl_ChanB EQU $C85D
Clear_Score EQU $F84F
DLW_SEG1_DY_NO_CLAMP EQU $41A5
AU_MUSIC_HAS_DELAY EQU $44D7
DRAW_LINE_WRAPPER EQU $4156
Vec_Joy_1_Y EQU $C81C
OBJ_WILL_HIT EQU $F8F3
Vec_Counter_4 EQU $C831
DO_SOUND EQU $F289
Sound_Byte EQU $F256
DRAW_VLC EQU $F3CE
VEC_MUSIC_WK_1 EQU $C84B
SFX_M_NOISEDIS EQU $45AA
Vec_Twang_Table EQU $C851
VEC_EXPL_TIMER EQU $C877
SFX_BANK_TABLE EQU $4006
VEC_BUTTONS EQU $C811
MUSICC EQU $FF7A
WARM_START EQU $F06C
JOY_ANALOG EQU $F1F5
Print_Ships_x EQU $F391
RISE_RUN_Y EQU $F601
Rot_VL_Mode_a EQU $F61F
MUSIC6 EQU $FE76
VEC_MUSIC_WORK EQU $C83F
PRINT_SHIPS_X EQU $F391
Rot_VL_Mode EQU $F62B
MOVETO_IX_A EQU $F30E
VEC_BTN_STATE EQU $C80F
Dot_List_Reset EQU $F2DE
ROT_VL EQU $F616
GET_RISE_IDX EQU $F5D9
VEC_RISE_INDEX EQU $C839
MOVETO_IX EQU $F310
Clear_C8_RAM EQU $F542
NOAY EQU $4545
PLAY_SFX_BANKED EQU $408C
Random_3 EQU $F511
DEC_3_COUNTERS EQU $F55A
SFX_CHECKVOLUME EQU $4584
CLEAR_X_256 EQU $F545
MOD16.M16_DONE EQU $413D
PSG_UPDATE_DONE EQU $4454
VEC_EXPL_CHANA EQU $C853
MOV_DRAW_VL EQU $F3BC
Vec_Joy_Resltn EQU $C81A
Vec_Music_Twang EQU $C858
DRAW_VL_MODE EQU $F46E
sfx_checknoisefreq EQU $4573
Vec_Music_Flag EQU $C856
VEC_NUM_PLAYERS EQU $C879
music3 EQU $FD81
Mov_Draw_VLcs EQU $F3B5
Vec_Rise_Index EQU $C839
STOP_MUSIC_RUNTIME EQU $4458
Rise_Run_Y EQU $F601
PSG_update_done EQU $4454
_MUSIC1_MUSIC EQU $0000
Reset0Ref EQU $F354
Vec_Seed_Ptr EQU $C87B
Moveto_ix_FF EQU $F308
MOVE_MEM_A EQU $F683
VEC_FIRQ_VECTOR EQU $CBF5
MOV_DRAW_VL_A EQU $F3B9
Add_Score_a EQU $F85E
Vec_IRQ_Vector EQU $CBF8
Vec_Button_2_1 EQU $C816
Rot_VL_dft EQU $F637
INIT_OS EQU $F18B
VEC_RANDOM_SEED EQU $C87D
AU_MUSIC_NO_DELAY EQU $44C8
Check0Ref EQU $F34F
VEC_COUNTER_3 EQU $C830
DLW_SEG2_DY_NO_REMAIN EQU $421C
Set_Refresh EQU $F1A2
Vec_Expl_Flag EQU $C867
Joy_Digital EQU $F1F8
Vec_Angle EQU $C836
VEC_TEXT_HW EQU $C82A
DLW_SEG1_DX_READY EQU $41CB
Compare_Score EQU $F8C7
Delay_3 EQU $F56D
Intensity_3F EQU $F2A1
music4 EQU $FDD3
VEC_EXPL_CHAN EQU $C85C
Obj_Will_Hit EQU $F8F3
Cold_Start EQU $F000
Vec_Counter_1 EQU $C82E
DLW_SEG2_DY_POS EQU $4222
VEC_JOY_MUX_2_Y EQU $C822
Delay_1 EQU $F575
PRINT_LIST_HW EQU $F385
Mov_Draw_VL EQU $F3BC
Rise_Run_Len EQU $F603
DO_SOUND_X EQU $F28C
DLW_SEG2_DX_CHECK_NEG EQU $4239
Vec_SWI3_Vector EQU $CBF2
PMr_done EQU $43F1
VEC_ADSR_TABLE EQU $C84F
Clear_x_b EQU $F53F
VEC_MUSIC_FLAG EQU $C856
Vec_NMI_Vector EQU $CBFB
Vec_Joy_Mux_2_Y EQU $C822
VEC_ANGLE EQU $C836
musicd EQU $FF8F
Draw_VL_ab EQU $F3D8
PSG_music_ended EQU $4446
MOD16.M16_RCHECK EQU $410F
PMR_DONE EQU $43F1
Dot_List EQU $F2D5
AU_MUSIC_READ_COUNT EQU $44C8
Get_Run_Idx EQU $F5DB
INIT_MUSIC_BUF EQU $F533
Vec_Run_Index EQU $C837
PRINT_STR_D EQU $F37A
READ_BTNS_MASK EQU $F1B4
AU_MUSIC_READ EQU $44B7
Sound_Byte_raw EQU $F25B
DLW_SEG1_DY_LO EQU $4198
VEC_EXPL_1 EQU $C858
MUSIC5 EQU $FE38
Moveto_ix_a EQU $F30E
DSWM_NO_NEGATE_DX EQU $42FC
INTENSITY_3F EQU $F2A1
Sound_Bytes_x EQU $F284
Moveto_x_7F EQU $F2F2
Move_Mem_a EQU $F683
PSG_write_loop EQU $440F
VEC_DURATION EQU $C857
DRAW_VECTOR_BANKED EQU $4018
VEC_MUSIC_WK_7 EQU $C845
ABS_B EQU $F58B
VEC_EXPL_2 EQU $C859
Draw_VL EQU $F3DD
Vec_Rfrsh_lo EQU $C83D
Get_Rise_Run EQU $F5EF
VECTOR_BANK_TABLE EQU $4000
Draw_Line_d EQU $F3DF
sfx_nextframe EQU $45B4
Vec_Button_1_1 EQU $C812
UPDATE_MUSIC_PSG EQU $43F2
DLW_DONE EQU $4259
SFX_ENDOFEFFECT EQU $45B9
Moveto_ix_7F EQU $F30C
DSWM_DONE EQU $43B0
DOT_HERE EQU $F2C5
Do_Sound_x EQU $F28C
DRAW_PAT_VL EQU $F437
ADD_SCORE_A EQU $F85E
RANDOM_3 EQU $F511
VEC_JOY_RESLTN EQU $C81A
VEC_JOY_1_Y EQU $C81C
Vec_SWI2_Vector EQU $CBF2
PRINT_TEXT_STR_103315 EQU $45D7
DSWM_NEXT_PATH EQU $4322
VEC_SND_SHADOW EQU $C800
Vec_Text_Width EQU $C82B
Moveto_ix EQU $F310
PRINT_SHIPS EQU $F393
AU_DONE EQU $4527
MOVETO_X_7F EQU $F2F2
AU_MUSIC_DONE EQU $44FA
VEC_EXPL_CHANB EQU $C85D
Sound_Byte_x EQU $F259
music1 EQU $FD0D
DEC_6_COUNTERS EQU $F55E
PRINT_LIST EQU $F38A
AU_MUSIC_ENDED EQU $4500
Vec_Joy_2_X EQU $C81D
Vec_Expl_3 EQU $C85A
RANDOM EQU $F517
DSWM_NO_NEGATE_Y EQU $427A
PSG_FRAME_DONE EQU $4440
Vec_Expl_Timer EQU $C877
Clear_x_d EQU $F548
music7 EQU $FEC6
DRAW_LINE_D EQU $F3DF
sfx_m_tonedis EQU $459D
VEC_MUSIC_WK_6 EQU $C846
Draw_VLp_b EQU $F40E
PSG_WRITE_LOOP EQU $440F
Moveto_d_7F EQU $F2FC
MOD16 EQU $40EA
sfx_updatemixer EQU $458D
VEC_BUTTON_2_1 EQU $C816
PLAY_MUSIC_RUNTIME EQU $43B1
AU_BANK_OK EQU $4499
VEC_BUTTON_2_4 EQU $C819
SFX_UPDATEMIXER EQU $458D
DSWM_NO_NEGATE_X EQU $4287
Strip_Zeros EQU $F8B7
READ_BTNS EQU $F1BA
Vec_Duration EQU $C857
DSWM_NEXT_NO_NEGATE_X EQU $4341
CHECK0REF EQU $F34F
PMr_start_new EQU $43BF
Clear_Sound EQU $F272
MUSIC8 EQU $FEF8
musica EQU $FF44
Vec_Rfrsh_hi EQU $C83E
Dot_d EQU $F2C3
Vec_Music_Wk_7 EQU $C845
Delay_RTS EQU $F57D
VEC_MUSIC_CHAN EQU $C855
WAIT_RECAL EQU $F192
Dec_6_Counters EQU $F55E
VEC_MAX_PLAYERS EQU $C84F
DP_TO_D0 EQU $F1AA
EXPLOSION_SND EQU $F92E
RISE_RUN_ANGLE EQU $F593
Init_Music_Buf EQU $F533
GET_RUN_IDX EQU $F5DB
DSWM_LOOP EQU $42DA
Vec_RiseRun_Len EQU $C83B
Xform_Run_a EQU $F65B
PSG_frame_done EQU $4440
ROT_VL_AB EQU $F610
VEC_COUNTERS EQU $C82E
SOUND_BYTE EQU $F256
SELECT_GAME EQU $F7A9
CLEAR_X_B_A EQU $F552
INTENSITY_A EQU $F2AB
Rise_Run_X EQU $F5FF
XFORM_RUN_A EQU $F65B
Abs_a_b EQU $F584
Draw_VLp_scale EQU $F40C
VEC_LOOP_COUNT EQU $C825
Explosion_Snd EQU $F92E
Print_Str EQU $F495
MOV_DRAW_VL_AB EQU $F3B7
VEC_SWI2_VECTOR EQU $CBF2
DSWM_W1 EQU $42D1
VEC_MISC_COUNT EQU $C823
SOUND_BYTES EQU $F27D
DLW_SEG2_DX_NO_REMAIN EQU $4247
musicb EQU $FF62
CLEAR_C8_RAM EQU $F542
Init_VIA EQU $F14C
Vec_FIRQ_Vector EQU $CBF5
Print_Ships EQU $F393
VEC_JOY_MUX_2_X EQU $C821
VEC_SEED_PTR EQU $C87B
GET_RISE_RUN EQU $F5EF
MUSIC3 EQU $FD81
VEC_BUTTON_1_4 EQU $C815
Vec_Expl_ChanA EQU $C853
Intensity_7F EQU $F2A9
Mov_Draw_VL_b EQU $F3B1
Vec_Button_1_4 EQU $C815
DELAY_0 EQU $F579
SFX_DOFRAME EQU $4546
DOT_LIST_RESET EQU $F2DE
Abs_b EQU $F58B
VEC_RUN_INDEX EQU $C837
Print_Str_hwyx EQU $F373
MOVETO_IX_7F EQU $F30C
Draw_VLcs EQU $F3D6
DLW_SEG1_DX_NO_CLAMP EQU $41C8
DSWM_SET_INTENSITY EQU $4260
PSG_music_loop EQU $444C
DRAW_PAT_VL_D EQU $F439
MUSIC9 EQU $FF26
Vec_Music_Wk_5 EQU $C847
VEC_ADSR_TIMERS EQU $C85E
Vec_Pattern EQU $C829
Joy_Analog EQU $F1F5
Mov_Draw_VL_d EQU $F3BE
Draw_Pat_VL_d EQU $F439
NEW_HIGH_SCORE EQU $F8D8
Draw_Pat_VL_a EQU $F434
Vec_Btn_State EQU $C80F
SFX_UPDATE EQU $453B
AU_SKIP_MUSIC EQU $4511
VEC_SWI_VECTOR EQU $CBFB
INTENSITY_7F EQU $F2A9
VEC_BRIGHTNESS EQU $C827
VEC_EXPL_3 EQU $C85A
Move_Mem_a_1 EQU $F67F
Dec_Counters EQU $F563
Read_Btns_Mask EQU $F1B4
DLW_SEG1_DY_READY EQU $41A8
AU_MUSIC_WRITE_LOOP EQU $44E3
Vec_Joy_2_Y EQU $C81E
DRAW_PAT_VL_A EQU $F434
Draw_VLp EQU $F410
MOV_DRAW_VLCS EQU $F3B5
DLW_SEG2_DX_DONE EQU $424A
VEC_0REF_ENABLE EQU $C824
DLW_SEG2_DY_DONE EQU $4225
SOUND_BYTE_X EQU $F259
Draw_VLp_7F EQU $F408
Vec_Joy_Mux_2_X EQU $C821
XFORM_RUN EQU $F65D
Clear_x_256 EQU $F545
DRAW_GRID_VL EQU $FF9F
DSWM_NEXT_NO_NEGATE_Y EQU $4334
VEC_COUNTER_4 EQU $C831
Vec_Music_Freq EQU $C861
VEC_MUSIC_WK_A EQU $C842
Vec_Dot_Dwell EQU $C828
Draw_VL_a EQU $F3DA
Xform_Rise EQU $F663
PLAY_MUSIC_BANKED EQU $4054
Vec_Expl_1 EQU $C858
Init_Music EQU $F68D
Mov_Draw_VL_ab EQU $F3B7
DP_TO_C8 EQU $F1AF
Vec_Snd_Shadow EQU $C800
VEC_BUTTON_1_3 EQU $C814
JOY_DIGITAL EQU $F1F8
PRINT_LIST_CHK EQU $F38C
PRINT_TEXT_STR_60036694812 EQU $45E7
Vec_Counter_6 EQU $C833
Vec_Music_Ptr EQU $C853
MOD16.M16_LOOP EQU $411E
RISE_RUN_LEN EQU $F603
sfx_m_noisedis EQU $45AA
SFX_CHECKTONEFREQ EQU $4559
VEC_TEXT_HEIGHT EQU $C82A
Vec_Joy_1_X EQU $C81B
Vec_Counter_2 EQU $C82F
Select_Game EQU $F7A9
VEC_MUSIC_TWANG EQU $C858
PRINT_STR_YX EQU $F378
Intensity_a EQU $F2AB
PSG_MUSIC_ENDED EQU $4446
Print_Str_yx EQU $F378
Dot_here EQU $F2C5
SOUND_BYTE_RAW EQU $F25B
RISE_RUN_X EQU $F5FF
Intensity_1F EQU $F29D
PRINT_TEXT_STR_6459777946950754952 EQU $45F7
MOD16.M16_END EQU $412E
Delay_0 EQU $F579
Vec_Counter_5 EQU $C832
DOT_IX EQU $F2C1
SFX_ADDR_TABLE EQU $4008
Vec_Random_Seed EQU $C87D
MUSIC7 EQU $FEC6
OBJ_WILL_HIT_U EQU $F8E5
VEC_TWANG_TABLE EQU $C851
Vec_Expl_2 EQU $C859
Mov_Draw_VLc_a EQU $F3AD
Delay_b EQU $F57A
Add_Score_d EQU $F87C
CLEAR_X_B EQU $F53F
DELAY_RTS EQU $F57D
DRAW_VLP_FF EQU $F404
VEC_RFRSH EQU $C83D
Vec_Expl_4 EQU $C85B
DRAW_VLCS EQU $F3D6
Vec_Music_Work EQU $C83F
VEC_JOY_MUX_1_X EQU $C81F
New_High_Score EQU $F8D8
Vec_RiseRun_Tmp EQU $C834
Vec_Button_1_2 EQU $C813
SFX_M_TONEDIS EQU $459D
AUDIO_UPDATE EQU $447F
DSWM_W3 EQU $43A4
CLEAR_X_B_80 EQU $F550
DRAW_VLP_B EQU $F40E
Draw_VLc EQU $F3CE
ADD_SCORE_D EQU $F87C
Print_List_chk EQU $F38C
INTENSITY_5F EQU $F2A5
Mov_Draw_VL_a EQU $F3B9
DRAW_VLP EQU $F410
Vec_Joy_Mux_1_Y EQU $C820
PSG_MUSIC_LOOP EQU $444C
MOV_DRAW_VL_B EQU $F3B1
VEC_COUNTER_2 EQU $C82F
VECTOR_ADDR_TABLE EQU $4001
Vec_Joy_Mux_1_X EQU $C81F
Recalibrate EQU $F2E6
DEC_COUNTERS EQU $F563
Vec_Rfrsh EQU $C83D
Init_Music_chk EQU $F687
MOVETO_D_7F EQU $F2FC
DRAW_VL EQU $F3DD
Rise_Run_Angle EQU $F593
Vec_Music_Wk_1 EQU $C84B
VEC_BUTTON_2_2 EQU $C817
PRINT_TEXT_STR_3273774 EQU $45DB
Vec_Freq_Table EQU $C84D
Draw_Pat_VL EQU $F437
Vec_Joy_Mux EQU $C81F
Vec_Music_Chan EQU $C855
Do_Sound EQU $F289
sfx_endofeffect EQU $45B9
DLW_NEED_SEG2 EQU $4203
sfx_checkvolume EQU $4584
Obj_Hit EQU $F8FF
DELAY_2 EQU $F571
VEC_EXPL_4 EQU $C85B
Vec_Expl_Chan EQU $C85C
Vec_Loop_Count EQU $C825
sfx_m_noise EQU $459F
OBJ_HIT EQU $F8FF
Vec_Max_Players EQU $C84F
RESET0INT EQU $F36B
VEC_FREQ_TABLE EQU $C84D
Vec_Num_Players EQU $C879
Vec_SWI_Vector EQU $CBFB
_BUBBLE_MEDIUM_VECTORS EQU $0231
RESET_PEN EQU $F35B
music9 EQU $FF26
Sound_Bytes EQU $F27D
VEC_BUTTON_1_1 EQU $C812
Vec_Counter_3 EQU $C830
VEC_JOY_MUX EQU $C81F
MUSIC1 EQU $FD0D
Dot_ix EQU $F2C1
ASSET_ADDR_TABLE EQU $4010
DOT_LIST EQU $F2D5
musicc EQU $FF7A
VEC_EXPL_FLAG EQU $C867
SFX_M_WRITE EQU $45AC
VEC_JOY_MUX_1_Y EQU $C820
Vec_Brightness EQU $C827
INIT_OS_RAM EQU $F164
music5 EQU $FE38
VECTREX_PRINT_TEXT EQU $40BA
VEC_PATTERN EQU $C829
Vec_Buttons EQU $C811
Vec_Button_2_3 EQU $C818
MUSICB EQU $FF62
MOVETO_IX_FF EQU $F308
VEC_RFRSH_HI EQU $C83E
DRAW_VLP_SCALE EQU $F40C
_BUBBLE_MEDIUM_PATH0 EQU $0234
Vec_Cold_Flag EQU $CBFE
PRINT_TEXT_STR_3232159404 EQU $45E0
VEC_JOY_1_X EQU $C81B
Rot_VL EQU $F616
Random EQU $F517
Bitmask_a EQU $F57E
VEC_RFRSH_LO EQU $C83D
VEC_COUNTER_6 EQU $C833
VEC_SWI3_VECTOR EQU $CBF2


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "PHYSICS"
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
DRAW_VEC_INTENSITY   EQU $C880+$0E   ; Vector intensity override (0=use vector data) (1 bytes)
DRAW_VEC_X_HI        EQU $C880+$0F   ; Vector draw X high byte (16-bit screen_x) (1 bytes)
DRAW_VEC_X           EQU $C880+$10   ; Vector draw X offset (1 bytes)
DRAW_VEC_Y           EQU $C880+$11   ; Vector draw Y offset (1 bytes)
MIRROR_PAD           EQU $C880+$12   ; Safety padding to prevent MIRROR flag corruption (16 bytes)
MIRROR_X             EQU $C880+$22   ; X mirror flag (0=normal, 1=flip) (1 bytes)
MIRROR_Y             EQU $C880+$23   ; Y mirror flag (0=normal, 1=flip) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$24   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$2E   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$30   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$32   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$33   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$34   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$36   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$38   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$39   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_BX               EQU $C880+$3A   ; User variable: BX (2 bytes)
VAR_BY               EQU $C880+$3C   ; User variable: BY (2 bytes)
VAR_VX               EQU $C880+$3E   ; User variable: VX (2 bytes)
VAR_VY               EQU $C880+$40   ; User variable: VY (2 bytes)
VAR_JX               EQU $C880+$42   ; User variable: JX (2 bytes)
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
    LDD #0
    STD VAR_BX
    LDD #60
    STD VAR_BY
    LDD #1
    STD VAR_VX
    LDD #0
    STD VAR_VY
    LDD #0
    STD VAR_JX
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
    STD VAR_BX
    LDD #60
    STD VAR_BY
    LDD #1
    STD VAR_VX
    LDD #0
    STD VAR_VY

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    ; PRINT_TEXT: Print text at position
    LDD #-50
    STD VAR_ARG0
    LDD #100
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_73146331687      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-50
    STD VAR_ARG0
    LDD #85
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_60036694812      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD >VAR_VY
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_VY
    JSR J1X_BUILTIN
    STD RESULT
    STD VAR_JX
    LDD #40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JX
    CMPD TMPVAL
    LBGT .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_1
    LDD >VAR_VX
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_VX
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    LDD #-40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JX
    CMPD TMPVAL
    LBLT .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    LBEQ IF_NEXT_3
    LDD >VAR_VX
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_VX
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed
    BITA #$01
    LBNE .J1B1_0_ON
    LDD #0
    LBRA .J1B1_0_END
.J1B1_0_ON:
    LDD #1
.J1B1_0_END:
    STD RESULT
    LBEQ IF_NEXT_5
    LDD #8
    STD VAR_VY
    ; PLAY_SFX("jump") - play SFX asset (index=1)
    LDX #1        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    LDD #6
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_VX
    CMPD TMPVAL
    LBGT .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    LBEQ IF_NEXT_7
    LDD #6
    STD VAR_VX
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
    LDD #-6
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_VX
    CMPD TMPVAL
    LBLT .CMP_3_TRUE
    LDD #0
    LBRA .CMP_3_END
.CMP_3_TRUE:
    LDD #1
.CMP_3_END:
    LBEQ IF_NEXT_9
    LDD #-6
    STD VAR_VX
    LBRA IF_END_8
IF_NEXT_9:
IF_END_8:
    LDD >VAR_BX
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_VX
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_BX
    LDD >VAR_BY
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_VY
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_BY
    LDD #-90
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BY
    CMPD TMPVAL
    LBLT .CMP_4_TRUE
    LDD #0
    LBRA .CMP_4_END
.CMP_4_TRUE:
    LDD #1
.CMP_4_END:
    LBEQ IF_NEXT_11
    LDD #-90
    STD VAR_BY
    LDD #0
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_VY
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_VY
    LDD #12
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_VY
    CMPD TMPVAL
    LBGT .CMP_5_TRUE
    LDD #0
    LBRA .CMP_5_END
.CMP_5_TRUE:
    LDD #1
.CMP_5_END:
    LBEQ IF_NEXT_13
    LDD #12
    STD VAR_VY
    LBRA IF_END_12
IF_NEXT_13:
IF_END_12:
    ; PLAY_SFX("hit") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_10
IF_NEXT_11:
IF_END_10:
    LDD #90
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BY
    CMPD TMPVAL
    LBGT .CMP_6_TRUE
    LDD #0
    LBRA .CMP_6_END
.CMP_6_TRUE:
    LDD #1
.CMP_6_END:
    LBEQ IF_NEXT_15
    LDD #90
    STD VAR_BY
    LDD #0
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_VY
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_VY
    LBRA IF_END_14
IF_NEXT_15:
IF_END_14:
    LDD #100
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BX
    CMPD TMPVAL
    LBGT .CMP_7_TRUE
    LDD #0
    LBRA .CMP_7_END
.CMP_7_TRUE:
    LDD #1
.CMP_7_END:
    LBEQ IF_NEXT_17
    LDD #100
    STD VAR_BX
    LDD #0
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_VX
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_VX
    ; PLAY_SFX("hit") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_16
IF_NEXT_17:
IF_END_16:
    LDD #-100
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BX
    CMPD TMPVAL
    LBLT .CMP_8_TRUE
    LDD #0
    LBRA .CMP_8_END
.CMP_8_TRUE:
    LDD #1
.CMP_8_END:
    LBEQ IF_NEXT_19
    LDD #-100
    STD VAR_BX
    LDD #0
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_VX
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_VX
    ; PLAY_SFX("hit") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_18
IF_NEXT_19:
IF_END_18:
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bubble_medium (index=0, 1 paths)
    LDD >VAR_BX
    TFR B,A       ; X position (low byte) — B already holds it
    STA TMPPTR    ; Save X to temporary storage
    LDD >VAR_BY
    TFR B,A       ; Y position (low byte) — B already holds it
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    LDX #0        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    CLR DRAW_VEC_INTENSITY  ; Reset: next DRAW_VECTOR uses .vec intensities
    LDD #0
    STD RESULT
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #-100
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #-110
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #100
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #-110
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #60
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX (after all game logic)
    RTS


; ================================================
