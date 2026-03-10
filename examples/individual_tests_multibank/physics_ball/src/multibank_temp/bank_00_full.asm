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
DRAW_VEC_X_HI        EQU $C880+$0E   ; Vector draw X high byte (16-bit screen_x) (1 bytes)
DRAW_VEC_X           EQU $C880+$0F   ; Vector draw X offset (1 bytes)
DRAW_VEC_Y           EQU $C880+$10   ; Vector draw Y offset (1 bytes)
DRAW_VEC_INTENSITY   EQU $C880+$11   ; Vector intensity override (0=use vector data) (1 bytes)
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
VAR_BX               EQU $C880+$3A   ; User variable: bx (2 bytes)
VAR_BY               EQU $C880+$3C   ; User variable: by (2 bytes)
VAR_VX               EQU $C880+$3E   ; User variable: vx (2 bytes)
VAR_VY               EQU $C880+$40   ; User variable: vy (2 bytes)
VAR_JX               EQU $C880+$42   ; User variable: jx (2 bytes)
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
Vec_Counter_5 EQU $C832
WARM_START EQU $F06C
VEC_COLD_FLAG EQU $CBFE
Joy_Digital EQU $F1F8
Vec_Joy_Mux_2_X EQU $C821
Print_List EQU $F38A
MUSIC_ADDR_TABLE EQU $4004
VEC_JOY_MUX EQU $C81F
music7 EQU $FEC6
GET_RISE_IDX EQU $F5D9
STRIP_ZEROS EQU $F8B7
Vec_Expl_ChanB EQU $C85D
Draw_VL_mode EQU $F46E
ASSET_ADDR_TABLE EQU $4010
sfx_updatemixer EQU $458D
NEW_HIGH_SCORE EQU $F8D8
VEC_NUM_PLAYERS EQU $C879
SOUND_BYTE_RAW EQU $F25B
PMR_START_NEW EQU $43BF
Explosion_Snd EQU $F92E
Vec_Music_Flag EQU $C856
VEC_SWI2_VECTOR EQU $CBF2
Vec_RiseRun_Tmp EQU $C834
MUSIC_BANK_TABLE EQU $4003
DLW_SEG1_DX_LO EQU $41BB
Vec_Run_Index EQU $C837
Obj_Will_Hit EQU $F8F3
WAIT_RECAL EQU $F192
Vec_Music_Wk_A EQU $C842
DLW_NEED_SEG2 EQU $4203
Set_Refresh EQU $F1A2
MUSICC EQU $FF7A
DP_TO_D0 EQU $F1AA
PRINT_LIST EQU $F38A
DSWM_DONE EQU $43B0
Xform_Rise_a EQU $F661
DSWM_NEXT_NO_NEGATE_X EQU $4341
Vec_Expl_Flag EQU $C867
AU_MUSIC_PROCESS_WRITES EQU $44E1
VEC_JOY_1_X EQU $C81B
AU_MUSIC_ENDED EQU $4500
INIT_MUSIC_CHK EQU $F687
VEC_BUTTON_1_2 EQU $C813
DRAW_PAT_VL_D EQU $F439
DLW_DONE EQU $4259
DLW_SEG1_DY_LO EQU $4198
Vec_Expl_Chans EQU $C854
VECTOR_ADDR_TABLE EQU $4001
Vec_Num_Game EQU $C87A
DRAW_LINE_WRAPPER EQU $4156
VEC_COUNTER_4 EQU $C831
DEC_6_COUNTERS EQU $F55E
VEC_BUTTON_2_4 EQU $C819
Sound_Byte_x EQU $F259
MOVETO_X_7F EQU $F2F2
MUSICD EQU $FF8F
STOP_MUSIC_RUNTIME EQU $4458
musica EQU $FF44
MUSIC8 EQU $FEF8
Dot_here EQU $F2C5
Get_Rise_Idx EQU $F5D9
Vec_Max_Games EQU $C850
Init_Music_chk EQU $F687
VEC_COUNTER_5 EQU $C832
MOVETO_IX_A EQU $F30E
Do_Sound EQU $F289
Vec_Button_2_4 EQU $C819
DRAW_VL_AB EQU $F3D8
Vec_Angle EQU $C836
music3 EQU $FD81
Draw_VLp_scale EQU $F40C
Vec_Music_Wk_6 EQU $C846
Clear_x_b_a EQU $F552
Check0Ref EQU $F34F
CLEAR_X_B_80 EQU $F550
DSWM_W3 EQU $43A4
VEC_JOY_2_Y EQU $C81E
Rise_Run_Angle EQU $F593
INTENSITY_7F EQU $F2A9
DLW_SEG2_DY_DONE EQU $4225
_BUBBLE_MEDIUM_PATH0 EQU $0234
DP_to_D0 EQU $F1AA
Vec_Random_Seed EQU $C87D
Draw_VL_ab EQU $F3D8
Sound_Byte_raw EQU $F25B
DLW_SEG1_DX_READY EQU $41CB
MUSIC3 EQU $FD81
CLEAR_SOUND EQU $F272
DELAY_B EQU $F57A
MOV_DRAW_VL_AB EQU $F3B7
Vec_Expl_1 EQU $C858
Draw_VLp EQU $F410
PMR_DONE EQU $43F1
VEC_EXPL_3 EQU $C85A
XFORM_RUN EQU $F65D
sfx_checktonefreq EQU $4559
PLAY_SFX_BANKED EQU $408C
PRINT_STR EQU $F495
MOVETO_IX EQU $F310
MOD16 EQU $40EA
Bitmask_a EQU $F57E
Mov_Draw_VL EQU $F3BC
DRAW_VL_A EQU $F3DA
Intensity_5F EQU $F2A5
Vec_Button_1_1 EQU $C812
MOD16.M16_RPOS EQU $411E
SFX_CHECKTONEFREQ EQU $4559
Print_Ships EQU $F393
PSG_frame_done EQU $4440
SFX_UPDATEMIXER EQU $458D
Mov_Draw_VLc_a EQU $F3AD
Delay_b EQU $F57A
VEC_EXPL_CHANA EQU $C853
VEC_DOT_DWELL EQU $C828
ABS_B EQU $F58B
PSG_music_ended EQU $4446
XFORM_RISE_A EQU $F661
Draw_VL EQU $F3DD
Add_Score_d EQU $F87C
VEC_RISERUN_TMP EQU $C834
VEC_BUTTON_2_2 EQU $C817
MOV_DRAW_VLCS EQU $F3B5
VEC_MUSIC_TWANG EQU $C858
SFX_CHECKVOLUME EQU $4584
Wait_Recal EQU $F192
Draw_Pat_VL EQU $F437
MUSIC6 EQU $FE76
PRINT_LIST_CHK EQU $F38C
music6 EQU $FE76
VEC_MUSIC_WK_A EQU $C842
ROT_VL EQU $F616
Draw_Line_d EQU $F3DF
Vec_Rfrsh EQU $C83D
MOD16.M16_DONE EQU $413D
XFORM_RUN_A EQU $F65B
SFX_ADDR_TABLE EQU $4008
Vec_Music_Wk_1 EQU $C84B
VEC_NMI_VECTOR EQU $CBFB
DP_TO_C8 EQU $F1AF
VEC_NUM_GAME EQU $C87A
Sound_Bytes EQU $F27D
Vec_Joy_1_Y EQU $C81C
Rot_VL_Mode_a EQU $F61F
PRINT_SHIPS EQU $F393
AU_MUSIC_READ_COUNT EQU $44C8
OBJ_WILL_HIT EQU $F8F3
INIT_OS_RAM EQU $F164
Mov_Draw_VL_b EQU $F3B1
Draw_VLp_FF EQU $F404
RESET0REF EQU $F354
MUSIC7 EQU $FEC6
Vec_Button_2_3 EQU $C818
DOT_IX_B EQU $F2BE
VEC_PATTERN EQU $C829
DRAW_VL_MODE EQU $F46E
COMPARE_SCORE EQU $F8C7
Vec_Joy_Mux_1_Y EQU $C820
VEC_MUSIC_CHAN EQU $C855
Init_Music_Buf EQU $F533
VEC_JOY_MUX_2_Y EQU $C822
Init_OS EQU $F18B
Dot_ix EQU $F2C1
VEC_ADSR_TABLE EQU $C84F
sfx_nextframe EQU $45B4
DOT_HERE EQU $F2C5
Vec_Num_Players EQU $C879
Dec_6_Counters EQU $F55E
PLAY_SFX_RUNTIME EQU $4532
INIT_MUSIC_X EQU $F692
VEC_FIRQ_VECTOR EQU $CBF5
music1 EQU $FD0D
DRAW_PAT_VL_A EQU $F434
CHECK0REF EQU $F34F
MOD16.M16_DPOS EQU $4107
music8 EQU $FEF8
INTENSITY_A EQU $F2AB
Vec_Expl_4 EQU $C85B
VEC_TEXT_HEIGHT EQU $C82A
EXPLOSION_SND EQU $F92E
AU_DONE EQU $4527
Dot_List EQU $F2D5
VEC_MUSIC_WK_6 EQU $C846
VEC_TEXT_WIDTH EQU $C82B
AU_MUSIC_NO_DELAY EQU $44C8
VEC_EXPL_CHANB EQU $C85D
Reset0Ref_D0 EQU $F34A
DRAW_PAT_VL EQU $F437
PSG_update_done EQU $4454
ABS_A_B EQU $F584
VEC_RANDOM_SEED EQU $C87D
PRINT_TEXT_STR_3273774 EQU $45DB
INTENSITY_3F EQU $F2A1
MOV_DRAW_VL_B EQU $F3B1
VEC_RFRSH_LO EQU $C83D
VECTREX_PRINT_TEXT EQU $40BA
SFX_M_NOISE EQU $459F
Vec_SWI3_Vector EQU $CBF2
MUSICA EQU $FF44
music9 EQU $FF26
SFX_CHECKNOISEFREQ EQU $4573
Strip_Zeros EQU $F8B7
musicb EQU $FF62
Intensity_3F EQU $F2A1
Vec_Counter_4 EQU $C831
Clear_C8_RAM EQU $F542
VEC_COUNTER_1 EQU $C82E
Obj_Hit EQU $F8FF
PSG_MUSIC_ENDED EQU $4446
Vec_Joy_2_Y EQU $C81E
DLW_SEG2_DY_NO_REMAIN EQU $421C
Rot_VL EQU $F616
Intensity_7F EQU $F2A9
Reset0Int EQU $F36B
VEC_MUSIC_WK_7 EQU $C845
VEC_BUTTON_2_1 EQU $C816
Clear_Score EQU $F84F
Init_Music EQU $F68D
DOT_IX EQU $F2C1
MOVETO_IX_FF EQU $F308
Compare_Score EQU $F8C7
Clear_x_b_80 EQU $F550
DSWM_NO_NEGATE_X EQU $4287
Vec_Counter_6 EQU $C833
VEC_SEED_PTR EQU $C87B
VEC_BUTTON_2_3 EQU $C818
Moveto_x_7F EQU $F2F2
DELAY_0 EQU $F579
_MUSIC1_MUSIC EQU $0000
Dec_Counters EQU $F563
Vec_Pattern EQU $C829
Sound_Byte EQU $F256
AU_MUSIC_HAS_DELAY EQU $44D7
VEC_JOY_2_X EQU $C81D
sfx_m_noisedis EQU $45AA
CLEAR_X_256 EQU $F545
PSG_MUSIC_LOOP EQU $444C
Vec_Buttons EQU $C811
Vec_Prev_Btns EQU $C810
VEC_COUNTERS EQU $C82E
DRAW_VLC EQU $F3CE
Vec_Button_2_2 EQU $C817
Vec_Joy_Mux_1_X EQU $C81F
DSWM_SET_INTENSITY EQU $4260
MUSIC2 EQU $FD1D
Print_Str_hwyx EQU $F373
Random EQU $F517
PRINT_SHIPS_X EQU $F391
VEC_MUSIC_FLAG EQU $C856
VEC_MUSIC_WK_1 EQU $C84B
sfx_doframe EQU $4546
RISE_RUN_ANGLE EQU $F593
Mov_Draw_VL_a EQU $F3B9
Vec_Button_1_4 EQU $C815
VEC_MUSIC_WK_5 EQU $C847
Print_List_chk EQU $F38C
VEC_EXPL_TIMER EQU $C877
DRAW_LINE_D EQU $F3DF
ROT_VL_MODE EQU $F62B
Obj_Will_Hit_u EQU $F8E5
AU_BANK_OK EQU $4499
VEC_JOY_RESLTN EQU $C81A
Vec_Text_HW EQU $C82A
VEC_EXPL_4 EQU $C85B
NOAY EQU $4545
ADD_SCORE_A EQU $F85E
Vec_Brightness EQU $C827
VEC_SWI_VECTOR EQU $CBFB
ADD_SCORE_D EQU $F87C
Mov_Draw_VLcs EQU $F3B5
VEC_EXPL_2 EQU $C859
AU_MUSIC_WRITE_LOOP EQU $44E3
DSWM_W1 EQU $42D1
SFX_BANK_TABLE EQU $4006
musicc EQU $FF7A
Vec_Music_Wk_7 EQU $C845
Clear_x_d EQU $F548
Vec_Text_Height EQU $C82A
DO_SOUND EQU $F289
DSWM_NO_NEGATE_DX EQU $42FC
DSWM_NEXT_PATH EQU $4322
INIT_MUSIC_BUF EQU $F533
Clear_Sound EQU $F272
VEC_EXPL_1 EQU $C858
VEC_JOY_1_Y EQU $C81C
Vec_Twang_Table EQU $C851
Init_Music_x EQU $F692
CLEAR_SCORE EQU $F84F
Vec_Joy_Mux_2_Y EQU $C822
Vec_FIRQ_Vector EQU $CBF5
Draw_Pat_VL_d EQU $F439
CLEAR_C8_RAM EQU $F542
sfx_checkvolume EQU $4584
VEC_EXPL_CHAN EQU $C85C
Rot_VL_ab EQU $F610
DELAY_2 EQU $F571
DRAW_SYNC_LIST_AT_WITH_MIRRORS EQU $425E
PRINT_STR_YX EQU $F378
AU_MUSIC_READ EQU $44B7
RISE_RUN_LEN EQU $F603
PMr_done EQU $43F1
UPDATE_MUSIC_PSG EQU $43F2
DO_SOUND_X EQU $F28C
PRINT_TEXT_STR_3232159404 EQU $45E0
VEC_TWANG_TABLE EQU $C851
XFORM_RISE EQU $F663
DSWM_NEXT_SET_INTENSITY EQU $4328
ROT_VL_AB EQU $F610
SFX_DOFRAME EQU $4546
SOUND_BYTE_X EQU $F259
VECTOR_BANK_TABLE EQU $4000
INTENSITY_5F EQU $F2A5
Mov_Draw_VL_d EQU $F3BE
ROT_VL_DFT EQU $F637
Delay_2 EQU $F571
Print_List_hw EQU $F385
Vec_Text_Width EQU $C82B
Dot_ix_b EQU $F2BE
Read_Btns_Mask EQU $F1B4
VEC_EXPL_FLAG EQU $C867
Sound_Bytes_x EQU $F284
Joy_Analog EQU $F1F5
DSWM_W2 EQU $4313
DSWM_NEXT_NO_NEGATE_Y EQU $4334
MOD16.M16_END EQU $412E
Vec_Seed_Ptr EQU $C87B
Vec_0Ref_Enable EQU $C824
MUSIC5 EQU $FE38
DLW_SEG2_DX_DONE EQU $424A
DRAW_VLP_FF EQU $F404
Vec_Str_Ptr EQU $C82C
DRAW_VLCS EQU $F3D6
Moveto_d EQU $F312
VEC_LOOP_COUNT EQU $C825
DRAW_VLP_B EQU $F40E
Print_Str_yx EQU $F378
INIT_MUSIC EQU $F68D
Vec_Duration EQU $C857
CLEAR_X_B EQU $F53F
Vec_Freq_Table EQU $C84D
RECALIBRATE EQU $F2E6
Vec_Music_Chan EQU $C855
AU_MUSIC_DONE EQU $44FA
Vec_Counter_3 EQU $C830
MUSIC4 EQU $FDD3
Draw_VL_b EQU $F3D2
Rise_Run_Y EQU $F601
music4 EQU $FDD3
SFX_NEXTFRAME EQU $45B4
JOY_DIGITAL EQU $F1F8
PRINT_STR_HWYX EQU $F373
PRINT_TEXT_STR_73146331687 EQU $45EF
Moveto_ix_FF EQU $F308
Vec_IRQ_Vector EQU $CBF8
Print_Str EQU $F495
VEC_EXPL_CHANS EQU $C854
VEC_FREQ_TABLE EQU $C84D
DLW_SEG1_DX_NO_CLAMP EQU $41C8
Draw_VLc EQU $F3CE
INIT_VIA EQU $F14C
SFX_M_WRITE EQU $45AC
Add_Score_a EQU $F85E
Draw_VLp_b EQU $F40E
Get_Rise_Run EQU $F5EF
Vec_Counter_2 EQU $C82F
Intensity_1F EQU $F29D
INIT_OS EQU $F18B
Vec_RiseRun_Len EQU $C83B
Vec_Music_Freq EQU $C861
Rise_Run_X EQU $F5FF
VEC_ADSR_TIMERS EQU $C85E
SELECT_GAME EQU $F7A9
DLW_SEG2_DX_NO_REMAIN EQU $4247
Mov_Draw_VL_ab EQU $F3B7
Rise_Run_Len EQU $F603
RISE_RUN_Y EQU $F601
Delay_1 EQU $F575
VEC_RFRSH EQU $C83D
PSG_WRITE_LOOP EQU $440F
DOT_LIST_RESET EQU $F2DE
Init_OS_RAM EQU $F164
Xform_Run EQU $F65D
VEC_TEXT_HW EQU $C82A
RANDOM_3 EQU $F511
Intensity_a EQU $F2AB
Draw_VL_a EQU $F3DA
DRAW_VLP_SCALE EQU $F40C
noay EQU $4545
Vec_Expl_Timer EQU $C877
DEC_COUNTERS EQU $F563
Vec_Counters EQU $C82E
VEC_RUN_INDEX EQU $C837
Delay_0 EQU $F579
Draw_Sync_List_At_With_Mirrors EQU $425E
VEC_COUNTER_3 EQU $C830
Vec_SWI2_Vector EQU $CBF2
Delay_RTS EQU $F57D
OBJ_HIT EQU $F8FF
DOT_D EQU $F2C3
Vec_NMI_Vector EQU $CBFB
Vec_Music_Work EQU $C83F
Abs_a_b EQU $F584
VEC_BUTTON_1_3 EQU $C814
Reset0Ref EQU $F354
VEC_PREV_BTNS EQU $C810
Vec_Joy_1_X EQU $C81B
Vec_Snd_Shadow EQU $C800
DSWM_LOOP EQU $42DA
VEC_0REF_ENABLE EQU $C824
Cold_Start EQU $F000
Xform_Rise EQU $F663
BITMASK_A EQU $F57E
sfx_endofeffect EQU $45B9
DLW_SEG2_DX_CHECK_NEG EQU $4239
DRAW_VLP_7F EQU $F408
VEC_BUTTON_1_4 EQU $C815
MOVETO_D_7F EQU $F2FC
Vec_Expl_Chan EQU $C85C
RESET0INT EQU $F36B
Vec_Joy_2_X EQU $C81D
Vec_High_Score EQU $CBEB
PSG_music_loop EQU $444C
SOUND_BYTE EQU $F256
SFX_UPDATE EQU $453B
Draw_Grid_VL EQU $FF9F
Vec_Expl_2 EQU $C859
DELAY_3 EQU $F56D
VEC_MAX_PLAYERS EQU $C84F
Vec_Counter_1 EQU $C82E
AUDIO_UPDATE EQU $447F
MOV_DRAW_VL_D EQU $F3BE
DRAW_VLP EQU $F410
Rot_VL_dft EQU $F637
Vec_Music_Twang EQU $C858
MOVETO_IX_7F EQU $F30C
Rot_VL_Mode EQU $F62B
DELAY_RTS EQU $F57D
MOV_DRAW_VLC_A EQU $F3AD
SFX_ENDOFEFFECT EQU $45B9
PRINT_TEXT_STR_60036694812 EQU $45E7
Vec_Rfrsh_hi EQU $C83E
DRAW_VL EQU $F3DD
VEC_SWI3_VECTOR EQU $CBF2
VEC_RISERUN_LEN EQU $C83B
VEC_IRQ_VECTOR EQU $CBF8
ASSET_BANK_TABLE EQU $400C
Clear_x_256 EQU $F545
AU_UPDATE_SFX EQU $4514
PRINT_TEXT_STR_103315 EQU $45D7
PSG_UPDATE_DONE EQU $4454
Vec_ADSR_Timers EQU $C85E
RESET_PEN EQU $F35B
SET_REFRESH EQU $F1A2
Draw_VLcs EQU $F3D6
Warm_Start EQU $F06C
Read_Btns EQU $F1BA
PMr_start_new EQU $43BF
DLW_SEG2_DY_POS EQU $4222
AU_SKIP_MUSIC EQU $4511
VEC_HIGH_SCORE EQU $CBEB
DOT_LIST EQU $F2D5
VEC_JOY_MUX_1_X EQU $C81F
VEC_MUSIC_PTR EQU $C853
Print_Str_d EQU $F37A
Abs_b EQU $F58B
DRAW_VECTOR_BANKED EQU $4018
Vec_Dot_Dwell EQU $C828
VEC_BUTTON_1_1 EQU $C812
PRINT_LIST_HW EQU $F385
_BUBBLE_MEDIUM_VECTORS EQU $0231
Vec_Misc_Count EQU $C823
Vec_Btn_State EQU $C80F
Get_Run_Idx EQU $F5DB
Vec_Button_2_1 EQU $C816
Moveto_ix EQU $F310
CLEAR_X_B_A EQU $F552
SOUND_BYTES_X EQU $F284
Moveto_ix_7F EQU $F30C
GET_RUN_IDX EQU $F5DB
AU_MUSIC_LOOP EQU $4506
Dot_List_Reset EQU $F2DE
musicd EQU $FF8F
PSG_write_loop EQU $440F
Vec_SWI_Vector EQU $CBFB
Vec_Music_Wk_5 EQU $C847
DELAY_1 EQU $F575
VEC_RFRSH_HI EQU $C83E
VEC_BTN_STATE EQU $C80F
Vec_Rfrsh_lo EQU $C83D
Vec_Expl_3 EQU $C85A
Vec_ADSR_Table EQU $C84F
MOVE_MEM_A EQU $F683
New_High_Score EQU $F8D8
VEC_ANGLE EQU $C836
DSWM_NO_NEGATE_DY EQU $42F2
MOVE_MEM_A_1 EQU $F67F
Vec_Loop_Count EQU $C825
Vec_Music_Ptr EQU $C853
VEC_MISC_COUNT EQU $C823
Draw_Pat_VL_a EQU $F434
RESET0REF_D0 EQU $F34A
MOV_DRAW_VL EQU $F3BC
Init_VIA EQU $F14C
Clear_x_b EQU $F53F
Move_Mem_a EQU $F683
Vec_Button_1_2 EQU $C813
Dot_d EQU $F2C3
VEC_SND_SHADOW EQU $C800
RANDOM EQU $F517
Vec_Rise_Index EQU $C839
PRINT_STR_D EQU $F37A
Do_Sound_x EQU $F28C
GET_RISE_RUN EQU $F5EF
Xform_Run_a EQU $F65B
JOY_ANALOG EQU $F1F5
VEC_MUSIC_FREQ EQU $C861
Recalibrate EQU $F2E6
SFX_M_NOISEDIS EQU $45AA
RISE_RUN_X EQU $F5FF
Reset_Pen EQU $F35B
Vec_Joy_Mux EQU $C81F
sfx_checknoisefreq EQU $4573
Vec_Max_Players EQU $C84F
MUSIC9 EQU $FF26
COLD_START EQU $F000
DP_to_C8 EQU $F1AF
sfx_m_noise EQU $459F
music5 EQU $FE38
Dec_3_Counters EQU $F55A
Vec_Button_1_3 EQU $C814
Vec_Joy_Resltn EQU $C81A
VEC_JOY_MUX_1_Y EQU $C820
VEC_DURATION EQU $C857
music2 EQU $FD1D
PSG_FRAME_DONE EQU $4440
MUSIC1 EQU $FD0D
MOV_DRAW_VL_A EQU $F3B9
CLEAR_X_D EQU $F548
DLW_SEG1_DY_READY EQU $41A8
ROT_VL_MODE_A EQU $F61F
VEC_BUTTONS EQU $C811
VEC_STR_PTR EQU $C82C
MOVETO_D EQU $F312
PLAY_MUSIC_BANKED EQU $4054
VEC_MUSIC_WORK EQU $C83F
Draw_VLp_7F EQU $F408
OBJ_WILL_HIT_U EQU $F8E5
sfx_m_write EQU $45AC
Vec_Default_Stk EQU $CBEA
Delay_3 EQU $F56D
VEC_MAX_GAMES EQU $C850
Vec_Cold_Flag EQU $CBFE
PRINT_TEXT_STR_6459777946950754952 EQU $45F7
Print_Ships_x EQU $F391
VEC_COUNTER_6 EQU $C833
Random_3 EQU $F511
Vec_Expl_ChanA EQU $C853
DEC_3_COUNTERS EQU $F55A
MUSICB EQU $FF62
VEC_BRIGHTNESS EQU $C827
sfx_m_tonedis EQU $459D
Move_Mem_a_1 EQU $F67F
SOUND_BYTES EQU $F27D
MOD16.M16_LOOP EQU $411E
DRAW_GRID_VL EQU $FF9F
PLAY_MUSIC_RUNTIME EQU $43B1
VEC_DEFAULT_STK EQU $CBEA
Select_Game EQU $F7A9
SFX_M_TONEDIS EQU $459D
MOD16.M16_RCHECK EQU $410F
INTENSITY_1F EQU $F29D
DRAW_VL_B EQU $F3D2
Moveto_d_7F EQU $F2FC
VEC_COUNTER_2 EQU $C82F
Moveto_ix_a EQU $F30E
DSWM_NO_NEGATE_Y EQU $427A
VEC_RISE_INDEX EQU $C839
J1X_BUILTIN EQU $413E
DLW_SEG1_DY_NO_CLAMP EQU $41A5
VEC_JOY_MUX_2_X EQU $C821
READ_BTNS EQU $F1BA
READ_BTNS_MASK EQU $F1B4


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
DRAW_VEC_X_HI        EQU $C880+$0E   ; Vector draw X high byte (16-bit screen_x) (1 bytes)
DRAW_VEC_X           EQU $C880+$0F   ; Vector draw X offset (1 bytes)
DRAW_VEC_Y           EQU $C880+$10   ; Vector draw Y offset (1 bytes)
DRAW_VEC_INTENSITY   EQU $C880+$11   ; Vector intensity override (0=use vector data) (1 bytes)
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
VAR_BX               EQU $C880+$3A   ; User variable: bx (2 bytes)
VAR_BY               EQU $C880+$3C   ; User variable: by (2 bytes)
VAR_VX               EQU $C880+$3E   ; User variable: vx (2 bytes)
VAR_VY               EQU $C880+$40   ; User variable: vy (2 bytes)
VAR_JX               EQU $C880+$42   ; User variable: jx (2 bytes)
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
