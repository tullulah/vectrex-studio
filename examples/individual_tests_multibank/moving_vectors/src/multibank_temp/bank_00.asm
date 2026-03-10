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
VAR_BALL_X           EQU $C880+$3A   ; User variable: ball_x (2 bytes)
VAR_BALL_Y           EQU $C880+$3C   ; User variable: ball_y (2 bytes)
VAR_BALL_VX          EQU $C880+$3E   ; User variable: ball_vx (2 bytes)
VAR_BALL_VY          EQU $C880+$40   ; User variable: ball_vy (2 bytes)
VAR_BUB_X            EQU $C880+$42   ; User variable: bub_x (2 bytes)
VAR_BUB_Y            EQU $C880+$44   ; User variable: bub_y (2 bytes)
VAR_BUB_VX           EQU $C880+$46   ; User variable: bub_vx (2 bytes)
VAR_BUB_VY           EQU $C880+$48   ; User variable: bub_vy (2 bytes)
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
Vec_Default_Stk EQU $CBEA
Vec_Joy_Mux_1_Y EQU $C820
Vec_Expl_2 EQU $C859
Vec_Snd_Shadow EQU $C800
Init_Music_chk EQU $F687
Vec_Rfrsh EQU $C83D
Xform_Run_a EQU $F65B
Vec_Joy_Mux EQU $C81F
Vec_Counter_2 EQU $C82F
DRAW_VECTOR_BANKED EQU $4018
MOVETO_IX_FF EQU $F308
DRAW_PAT_VL_D EQU $F439
Init_OS_RAM EQU $F164
VEC_EXPL_FLAG EQU $C867
Random EQU $F517
INIT_OS_RAM EQU $F164
VEC_MUSIC_TWANG EQU $C858
VEC_MUSIC_WK_A EQU $C842
PLAY_MUSIC_RUNTIME EQU $4396
DRAW_VL_B EQU $F3D2
PRINT_STR EQU $F495
PSG_update_done EQU $4439
SFX_M_NOISEDIS EQU $4586
Rot_VL_Mode_a EQU $F61F
DRAW_PAT_VL_A EQU $F434
COLD_START EQU $F000
Vec_Freq_Table EQU $C84D
DO_SOUND_X EQU $F28C
DLW_DONE EQU $423E
MOD16.M16_DONE EQU $413A
XFORM_RISE EQU $F663
sfx_m_noise EQU $457B
VEC_ANGLE EQU $C836
Intensity_a EQU $F2AB
SELECT_GAME EQU $F7A9
CLEAR_X_B_A EQU $F552
Moveto_ix EQU $F310
DP_to_C8 EQU $F1AF
RECALIBRATE EQU $F2E6
PRINT_TEXT_STR_2588604975547356052 EQU $45CE
music9 EQU $FF26
SOUND_BYTES EQU $F27D
Draw_Pat_VL_a EQU $F434
Vec_Btn_State EQU $C80F
SFX_UPDATE EQU $4517
RESET0INT EQU $F36B
sfx_updatemixer EQU $4569
sfx_checktonefreq EQU $4535
VEC_EXPL_4 EQU $C85B
VEC_BUTTON_2_1 EQU $C816
MOV_DRAW_VL_A EQU $F3B9
Xform_Run EQU $F65D
DLW_SEG2_DX_NO_REMAIN EQU $422C
Vec_Counter_4 EQU $C831
ROT_VL EQU $F616
music2 EQU $FD1D
SFX_CHECKNOISEFREQ EQU $454F
Draw_Pat_VL_d EQU $F439
DRAW_GRID_VL EQU $FF9F
Clear_x_b_a EQU $F552
Abs_a_b EQU $F584
Clear_Score EQU $F84F
DRAW_VLC EQU $F3CE
VEC_NUM_PLAYERS EQU $C879
Vec_Music_Twang EQU $C858
Vec_Duration EQU $C857
Vec_Pattern EQU $C829
VEC_MUSIC_FREQ EQU $C861
Joy_Analog EQU $F1F5
Vec_Joy_2_Y EQU $C81E
Vec_SWI_Vector EQU $CBFB
Delay_0 EQU $F579
Vec_Expl_ChanA EQU $C853
MUSIC9 EQU $FF26
VEC_MUSIC_FLAG EQU $C856
Moveto_ix_a EQU $F30E
NOAY EQU $4521
Draw_VLp_scale EQU $F40C
PSG_WRITE_LOOP EQU $43F4
DELAY_0 EQU $F579
SFX_CHECKTONEFREQ EQU $4535
VEC_MUSIC_WK_5 EQU $C847
INIT_OS EQU $F18B
Vec_Misc_Count EQU $C823
SFX_M_NOISE EQU $457B
DRAW_LINE_D EQU $F3DF
ROT_VL_MODE_A EQU $F61F
VEC_EXPL_CHANB EQU $C85D
Mov_Draw_VL_a EQU $F3B9
Vec_Cold_Flag EQU $CBFE
PRINT_LIST EQU $F38A
VEC_HIGH_SCORE EQU $CBEB
PSG_UPDATE_DONE EQU $4439
DSWM_NEXT_NO_NEGATE_X EQU $4326
Vec_Max_Games EQU $C850
RISE_RUN_ANGLE EQU $F593
WAIT_RECAL EQU $F192
BITMASK_A EQU $F57E
PRINT_SHIPS_X EQU $F391
UPDATE_MUSIC_PSG EQU $43D7
Vec_Run_Index EQU $C837
Rot_VL EQU $F616
Init_Music_x EQU $F692
Reset0Ref_D0 EQU $F34A
Recalibrate EQU $F2E6
OBJ_HIT EQU $F8FF
musica EQU $FF44
MUSIC2 EQU $FD1D
DOT_IX_B EQU $F2BE
Rot_VL_dft EQU $F637
Vec_Counter_3 EQU $C830
DRAW_VL_AB EQU $F3D8
INTENSITY_5F EQU $F2A5
DOT_IX EQU $F2C1
music7 EQU $FEC6
Vec_NMI_Vector EQU $CBFB
Vec_Prev_Btns EQU $C810
VEC_EXPL_CHANA EQU $C853
VEC_MUSIC_WK_6 EQU $C846
Vec_Angle EQU $C836
DSWM_NO_NEGATE_DX EQU $42E1
Vec_Button_2_1 EQU $C816
_BALL_VECTORS EQU $032E
WARM_START EQU $F06C
Xform_Rise EQU $F663
DRAW_VL_MODE EQU $F46E
INTENSITY_3F EQU $F2A1
CHECK0REF EQU $F34F
VEC_BUTTON_1_3 EQU $C814
PMR_START_NEW EQU $43A4
Dec_3_Counters EQU $F55A
CLEAR_X_B_80 EQU $F550
Sound_Byte_x EQU $F259
VEC_PREV_BTNS EQU $C810
INIT_MUSIC_X EQU $F692
VEC_BRIGHTNESS EQU $C827
RISE_RUN_Y EQU $F601
VEC_SEED_PTR EQU $C87B
VEC_COUNTERS EQU $C82E
music5 EQU $FE38
Read_Btns EQU $F1BA
Vec_Button_1_1 EQU $C812
Sound_Byte EQU $F256
DSWM_W1 EQU $42B6
Select_Game EQU $F7A9
DSWM_NO_NEGATE_X EQU $426C
VEC_MUSIC_PTR EQU $C853
musicd EQU $FF8F
Draw_VLc EQU $F3CE
SET_REFRESH EQU $F1A2
VEC_STR_PTR EQU $C82C
PMr_done EQU $43D6
MUSIC_BANK_TABLE EQU $4006
Vec_Max_Players EQU $C84F
VEC_NMI_VECTOR EQU $CBFB
Mov_Draw_VL_ab EQU $F3B7
STOP_MUSIC_RUNTIME EQU $443D
MOVETO_IX_7F EQU $F30C
VEC_SWI2_VECTOR EQU $CBF2
DLW_SEG2_DX_DONE EQU $422F
Vec_Button_2_3 EQU $C818
Draw_VLp_7F EQU $F408
VEC_SWI_VECTOR EQU $CBFB
Vec_SWI3_Vector EQU $CBF2
Vec_Expl_4 EQU $C85B
Vec_Joy_Mux_2_X EQU $C821
DOT_HERE EQU $F2C5
Print_Str_hwyx EQU $F373
MOD16.M16_DPOS EQU $4104
Draw_VL EQU $F3DD
Vec_Buttons EQU $C811
ABS_A_B EQU $F584
VECTOR_BANK_TABLE EQU $4000
INIT_MUSIC_BUF EQU $F533
EXPLOSION_SND EQU $F92E
VEC_RISE_INDEX EQU $C839
sfx_endofeffect EQU $4595
VEC_MUSIC_CHAN EQU $C855
Vec_Brightness EQU $C827
Sound_Bytes EQU $F27D
AU_SKIP_MUSIC EQU $44F6
Obj_Will_Hit_u EQU $F8E5
Rot_VL_Mode EQU $F62B
DSWM_W3 EQU $4389
DLW_NEED_SEG2 EQU $41E8
Get_Rise_Run EQU $F5EF
VEC_EXPL_TIMER EQU $C877
Check0Ref EQU $F34F
VEC_COUNTER_6 EQU $C833
VEC_RISERUN_TMP EQU $C834
Moveto_ix_7F EQU $F30C
VEC_SND_SHADOW EQU $C800
GET_RISE_IDX EQU $F5D9
sfx_nextframe EQU $4590
SOUND_BYTE EQU $F256
Print_Str_yx EQU $F378
Vec_Joy_1_X EQU $C81B
sfx_checknoisefreq EQU $454F
DRAW_VLP_SCALE EQU $F40C
VEC_RISERUN_LEN EQU $C83B
Intensity_1F EQU $F29D
AU_MUSIC_NO_DELAY EQU $44AD
Vec_Text_Width EQU $C82B
Vec_Expl_Timer EQU $C877
Draw_VLp_b EQU $F40E
sfx_doframe EQU $4522
Xform_Rise_a EQU $F661
Vec_Counter_6 EQU $C833
CLEAR_SCORE EQU $F84F
Vec_Music_Chan EQU $C855
Init_Music EQU $F68D
DELAY_B EQU $F57A
Vec_Button_1_4 EQU $C815
MOVETO_IX_A EQU $F30E
DRAW_VLP_B EQU $F40E
Vec_Loop_Count EQU $C825
Vec_Button_1_3 EQU $C814
noay EQU $4521
DSWM_NEXT_PATH EQU $4307
Init_Music_Buf EQU $F533
music8 EQU $FEF8
JOY_DIGITAL EQU $F1F8
Vec_High_Score EQU $CBEB
Print_List_chk EQU $F38C
Init_VIA EQU $F14C
DLW_SEG2_DY_POS EQU $4207
DRAW_VL_A EQU $F3DA
DLW_SEG2_DY_DONE EQU $420A
PLAY_MUSIC_BANKED EQU $4054
DP_TO_C8 EQU $F1AF
PSG_MUSIC_ENDED EQU $442B
VEC_JOY_2_Y EQU $C81E
AU_DONE EQU $4503
Dot_d EQU $F2C3
STRIP_ZEROS EQU $F8B7
MUSIC6 EQU $FE76
Vec_Joy_2_X EQU $C81D
SFX_M_WRITE EQU $4588
SOUND_BYTE_RAW EQU $F25B
ROT_VL_DFT EQU $F637
Sound_Byte_raw EQU $F25B
VEC_RFRSH_LO EQU $C83D
MOVE_MEM_A_1 EQU $F67F
Vec_Music_Wk_6 EQU $C846
Print_Ships_x EQU $F391
DLW_SEG1_DY_NO_CLAMP EQU $418A
PSG_write_loop EQU $43F4
DLW_SEG1_DY_LO EQU $417D
Draw_VL_mode EQU $F46E
Print_List_hw EQU $F385
DEC_6_COUNTERS EQU $F55E
VEC_JOY_MUX_1_Y EQU $C820
Moveto_ix_FF EQU $F308
Mov_Draw_VL EQU $F3BC
Clear_x_d EQU $F548
music4 EQU $FDD3
Dot_List_Reset EQU $F2DE
DLW_SEG1_DX_READY EQU $41B0
Clear_Sound EQU $F272
PRINT_TEXT_STR_3232159404 EQU $45BC
Obj_Hit EQU $F8FF
PRINT_TEXT_STR_3016191 EQU $45B7
CLEAR_X_D EQU $F548
AU_MUSIC_HAS_DELAY EQU $44BC
Do_Sound EQU $F289
MOD16 EQU $40E7
Draw_VL_ab EQU $F3D8
Compare_Score EQU $F8C7
DO_SOUND EQU $F289
SOUND_BYTES_X EQU $F284
ADD_SCORE_A EQU $F85E
Vec_Joy_Mux_2_Y EQU $C822
MUSIC1 EQU $FD0D
VEC_MISC_COUNT EQU $C823
DSWM_NEXT_SET_INTENSITY EQU $430D
CLEAR_X_B EQU $F53F
DOT_LIST_RESET EQU $F2DE
VEC_TEXT_HEIGHT EQU $C82A
Draw_Grid_VL EQU $FF9F
XFORM_RUN_A EQU $F65B
MOVETO_X_7F EQU $F2F2
SFX_BANK_TABLE EQU $4009
DLW_SEG1_DX_NO_CLAMP EQU $41AD
Print_List EQU $F38A
_MUSIC1_MUSIC EQU $0000
INTENSITY_7F EQU $F2A9
Vec_IRQ_Vector EQU $CBF8
Vec_Joy_Mux_1_X EQU $C81F
sfx_m_noisedis EQU $4586
Dot_ix_b EQU $F2BE
Vec_ADSR_Timers EQU $C85E
PRINT_STR_HWYX EQU $F373
Print_Str_d EQU $F37A
Dot_List EQU $F2D5
SOUND_BYTE_X EQU $F259
Moveto_x_7F EQU $F2F2
VEC_COUNTER_2 EQU $C82F
VEC_TWANG_TABLE EQU $C851
DRAW_VL EQU $F3DD
VEC_EXPL_CHANS EQU $C854
MUSIC5 EQU $FE38
PSG_frame_done EQU $4425
Vec_Music_Flag EQU $C856
VEC_DURATION EQU $C857
VEC_BUTTON_1_4 EQU $C815
VEC_JOY_MUX EQU $C81F
VEC_IRQ_VECTOR EQU $CBF8
VEC_RFRSH EQU $C83D
Delay_b EQU $F57A
AU_MUSIC_WRITE_LOOP EQU $44C8
DSWM_NEXT_NO_NEGATE_Y EQU $4319
DP_TO_D0 EQU $F1AA
Rise_Run_Len EQU $F603
music3 EQU $FD81
Vec_Seed_Ptr EQU $C87B
VEC_JOY_MUX_2_X EQU $C821
Explosion_Snd EQU $F92E
GET_RISE_RUN EQU $F5EF
Vec_Music_Wk_7 EQU $C845
MUSIC4 EQU $FDD3
Dec_Counters EQU $F563
Dot_ix EQU $F2C1
Rise_Run_X EQU $F5FF
INTENSITY_1F EQU $F29D
CLEAR_C8_RAM EQU $F542
DELAY_3 EQU $F56D
DRAW_LINE_WRAPPER EQU $413B
VEC_MUSIC_WK_1 EQU $C84B
Vec_Rise_Index EQU $C839
Strip_Zeros EQU $F8B7
Vec_Button_2_2 EQU $C817
_BALL_PATH0 EQU $0331
Vec_Num_Game EQU $C87A
VEC_COUNTER_5 EQU $C832
DRAW_SYNC_LIST_AT_WITH_MIRRORS EQU $4243
musicc EQU $FF7A
Vec_Joy_Resltn EQU $C81A
MUSIC_ADDR_TABLE EQU $4007
Vec_Expl_ChanB EQU $C85D
Vec_Twang_Table EQU $C851
PMR_DONE EQU $43D6
VEC_MUSIC_WK_7 EQU $C845
MOD16.M16_RCHECK EQU $410C
VEC_BTN_STATE EQU $C80F
VEC_MUSIC_WORK EQU $C83F
MOVETO_IX EQU $F310
Mov_Draw_VL_b EQU $F3B1
musicb EQU $FF62
VEC_BUTTONS EQU $C811
AU_MUSIC_PROCESS_WRITES EQU $44C6
VEC_JOY_1_Y EQU $C81C
OBJ_WILL_HIT_U EQU $F8E5
Delay_2 EQU $F571
Vec_Button_2_4 EQU $C819
SFX_DOFRAME EQU $4522
Delay_3 EQU $F56D
Intensity_3F EQU $F2A1
Delay_RTS EQU $F57D
DLW_SEG1_DY_READY EQU $418D
VEC_FREQ_TABLE EQU $C84D
Vec_Counters EQU $C82E
READ_BTNS_MASK EQU $F1B4
MUSICB EQU $FF62
Obj_Will_Hit EQU $F8F3
MUSIC8 EQU $FEF8
Vec_Random_Seed EQU $C87D
Vec_Music_Freq EQU $C861
Get_Run_Idx EQU $F5DB
VEC_NUM_GAME EQU $C87A
SFX_UPDATEMIXER EQU $4569
VEC_DEFAULT_STK EQU $CBEA
VEC_EXPL_CHAN EQU $C85C
Random_3 EQU $F511
INIT_VIA EQU $F14C
Abs_b EQU $F58B
Dot_here EQU $F2C5
Vec_Music_Wk_A EQU $C842
ASSET_BANK_TABLE EQU $400C
Vec_FIRQ_Vector EQU $CBF5
VEC_RUN_INDEX EQU $C837
Vec_ADSR_Table EQU $C84F
MOV_DRAW_VL EQU $F3BC
Vec_Expl_3 EQU $C85A
sfx_m_tonedis EQU $4579
VEC_JOY_2_X EQU $C81D
VEC_EXPL_3 EQU $C85A
Sound_Bytes_x EQU $F284
AUDIO_UPDATE EQU $4464
PLAY_SFX_RUNTIME EQU $450E
ASSET_ADDR_TABLE EQU $4010
COMPARE_SCORE EQU $F8C7
DRAW_PAT_VL EQU $F437
VEC_COUNTER_1 EQU $C82E
Vec_Text_HW EQU $C82A
Draw_Sync_List_At_With_Mirrors EQU $4243
VEC_MAX_GAMES EQU $C850
XFORM_RUN EQU $F65D
VEC_FIRQ_VECTOR EQU $CBF5
Cold_Start EQU $F000
MOV_DRAW_VL_D EQU $F3BE
PMr_start_new EQU $43A4
DSWM_W2 EQU $42F8
DELAY_1 EQU $F575
AU_MUSIC_ENDED EQU $44E5
VEC_JOY_1_X EQU $C81B
VEC_TEXT_WIDTH EQU $C82B
AU_MUSIC_LOOP EQU $44EB
RESET0REF EQU $F354
VEC_SWI3_VECTOR EQU $CBF2
AU_MUSIC_READ EQU $449C
VEC_JOY_RESLTN EQU $C81A
Vec_Expl_Chan EQU $C85C
Draw_VLp EQU $F410
AU_BANK_OK EQU $447E
VEC_0REF_ENABLE EQU $C824
MUSIC7 EQU $FEC6
MUSICA EQU $FF44
Do_Sound_x EQU $F28C
DOT_D EQU $F2C3
RESET0REF_D0 EQU $F34A
MOVETO_D EQU $F312
PSG_FRAME_DONE EQU $4425
DSWM_SET_INTENSITY EQU $4245
DELAY_RTS EQU $F57D
Vec_Rfrsh_hi EQU $C83E
DRAW_VLCS EQU $F3D6
MOV_DRAW_VLCS EQU $F3B5
Draw_VL_b EQU $F3D2
Get_Rise_Idx EQU $F5D9
DELAY_2 EQU $F571
Wait_Recal EQU $F192
Draw_VL_a EQU $F3DA
INIT_MUSIC_CHK EQU $F687
ROT_VL_AB EQU $F610
Dec_6_Counters EQU $F55E
READ_BTNS EQU $F1BA
DEC_3_COUNTERS EQU $F55A
Delay_1 EQU $F575
MOD16.M16_END EQU $412B
RISE_RUN_X EQU $F5FF
Moveto_d_7F EQU $F2FC
ABS_B EQU $F58B
MUSICD EQU $FF8F
DLW_SEG2_DY_NO_REMAIN EQU $4201
Vec_Dot_Dwell EQU $C828
VEC_RFRSH_HI EQU $C83E
VEC_MAX_PLAYERS EQU $C84F
MUSIC3 EQU $FD81
DRAW_VLP EQU $F410
VECTREX_PRINT_TEXT EQU $40B7
Reset0Ref EQU $F354
sfx_m_write EQU $4588
INTENSITY_A EQU $F2AB
CLEAR_SOUND EQU $F272
MOV_DRAW_VL_AB EQU $F3B7
VEC_TEXT_HW EQU $C82A
VEC_BUTTON_2_4 EQU $C819
Move_Mem_a_1 EQU $F67F
MOV_DRAW_VLC_A EQU $F3AD
DSWM_LOOP EQU $42BF
music1 EQU $FD0D
AU_MUSIC_DONE EQU $44DF
VEC_JOY_MUX_1_X EQU $C81F
Vec_Str_Ptr EQU $C82C
Clear_x_b_80 EQU $F550
SFX_ENDOFEFFECT EQU $4595
CLEAR_X_256 EQU $F545
PRINT_TEXT_STR_103315 EQU $45B3
Intensity_5F EQU $F2A5
VEC_RANDOM_SEED EQU $C87D
OBJ_WILL_HIT EQU $F8F3
Rot_VL_ab EQU $F610
Vec_Music_Wk_1 EQU $C84B
Vec_Expl_1 EQU $C858
Mov_Draw_VL_d EQU $F3BE
VEC_BUTTON_1_1 EQU $C812
PSG_MUSIC_LOOP EQU $4431
RISE_RUN_LEN EQU $F603
Vec_Text_Height EQU $C82A
Clear_x_256 EQU $F545
MUSICC EQU $FF7A
VEC_ADSR_TIMERS EQU $C85E
MOV_DRAW_VL_B EQU $F3B1
Set_Refresh EQU $F1A2
DP_to_D0 EQU $F1AA
Vec_Expl_Flag EQU $C867
Vec_SWI2_Vector EQU $CBF2
PLAY_SFX_BANKED EQU $408C
VEC_JOY_MUX_2_Y EQU $C822
VEC_DOT_DWELL EQU $C828
Vec_Rfrsh_lo EQU $C83D
Mov_Draw_VLc_a EQU $F3AD
Vec_RiseRun_Tmp EQU $C834
VEC_LOOP_COUNT EQU $C825
DSWM_NO_NEGATE_Y EQU $425F
MOD16.M16_RPOS EQU $411B
Draw_Pat_VL EQU $F437
DOT_LIST EQU $F2D5
_BUBBLE_SMALL_VECTORS EQU $02DD
VEC_BUTTON_1_2 EQU $C813
Joy_Digital EQU $F1F8
RANDOM_3 EQU $F511
Vec_Music_Ptr EQU $C853
Vec_Button_1_2 EQU $C813
Move_Mem_a EQU $F683
AU_MUSIC_READ_COUNT EQU $44AD
VEC_BUTTON_2_3 EQU $C818
Vec_RiseRun_Len EQU $C83B
Vec_Joy_1_Y EQU $C81C
RANDOM EQU $F517
Add_Score_d EQU $F87C
PRINT_STR_YX EQU $F378
Clear_C8_RAM EQU $F542
DLW_SEG1_DX_LO EQU $41A0
Vec_Num_Players EQU $C879
VEC_BUTTON_2_2 EQU $C817
MOVE_MEM_A EQU $F683
Clear_x_b EQU $F53F
DSWM_NO_NEGATE_DY EQU $42D7
sfx_checkvolume EQU $4560
VEC_COUNTER_4 EQU $C831
Print_Ships EQU $F393
SFX_CHECKVOLUME EQU $4560
VEC_COLD_FLAG EQU $CBFE
music6 EQU $FE76
Draw_Line_d EQU $F3DF
Add_Score_a EQU $F85E
VEC_EXPL_2 EQU $C859
PRINT_TEXT_STR_2105662470593698 EQU $45C3
MOD16.M16_LOOP EQU $411B
Vec_Counter_5 EQU $C832
VEC_ADSR_TABLE EQU $C84F
ADD_SCORE_D EQU $F87C
Mov_Draw_VLcs EQU $F3B5
DRAW_VLP_7F EQU $F408
Reset0Int EQU $F36B
Warm_Start EQU $F06C
Vec_Expl_Chans EQU $C854
DEC_COUNTERS EQU $F563
DLW_SEG2_DX_CHECK_NEG EQU $421E
AU_UPDATE_SFX EQU $44F9
MOVETO_D_7F EQU $F2FC
Draw_VLcs EQU $F3D6
NEW_HIGH_SCORE EQU $F8D8
Init_OS EQU $F18B
Vec_0Ref_Enable EQU $C824
SFX_NEXTFRAME EQU $4590
Read_Btns_Mask EQU $F1B4
GET_RUN_IDX EQU $F5DB
PRINT_LIST_CHK EQU $F38C
Draw_VLp_FF EQU $F404
JOY_ANALOG EQU $F1F5
New_High_Score EQU $F8D8
DRAW_VLP_FF EQU $F404
VECTOR_ADDR_TABLE EQU $4002
VEC_EXPL_1 EQU $C858
Reset_Pen EQU $F35B
ROT_VL_MODE EQU $F62B
PRINT_LIST_HW EQU $F385
PSG_music_loop EQU $4431
Vec_Music_Work EQU $C83F
Vec_Counter_1 EQU $C82E
INIT_MUSIC EQU $F68D
Bitmask_a EQU $F57E
Rise_Run_Y EQU $F601
PSG_music_ended EQU $442B
PRINT_SHIPS EQU $F393
Intensity_7F EQU $F2A9
Vec_Music_Wk_5 EQU $C847
Rise_Run_Angle EQU $F593
_BUBBLE_SMALL_PATH0 EQU $02E0
VEC_COUNTER_3 EQU $C830
Print_Str EQU $F495
VEC_PATTERN EQU $C829
RESET_PEN EQU $F35B
SFX_M_TONEDIS EQU $4579
XFORM_RISE_A EQU $F661
DSWM_DONE EQU $4395
PRINT_STR_D EQU $F37A
Moveto_d EQU $F312
SFX_ADDR_TABLE EQU $400A


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "MOVINGVEC"
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
VAR_BALL_X           EQU $C880+$3A   ; User variable: ball_x (2 bytes)
VAR_BALL_Y           EQU $C880+$3C   ; User variable: ball_y (2 bytes)
VAR_BALL_VX          EQU $C880+$3E   ; User variable: ball_vx (2 bytes)
VAR_BALL_VY          EQU $C880+$40   ; User variable: ball_vy (2 bytes)
VAR_BUB_X            EQU $C880+$42   ; User variable: bub_x (2 bytes)
VAR_BUB_Y            EQU $C880+$44   ; User variable: bub_y (2 bytes)
VAR_BUB_VX           EQU $C880+$46   ; User variable: bub_vx (2 bytes)
VAR_BUB_VY           EQU $C880+$48   ; User variable: bub_vy (2 bytes)
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
    STD VAR_BALL_X
    LDD #20
    STD VAR_BALL_Y
    LDD #3
    STD VAR_BALL_VX
    LDD #2
    STD VAR_BALL_VY
    LDD #-30
    STD VAR_BUB_X
    LDD #-20
    STD VAR_BUB_Y
    LDD #-2
    STD VAR_BUB_VX
    LDD #3
    STD VAR_BUB_VY
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
    STD VAR_BALL_X
    LDD #20
    STD VAR_BALL_Y
    LDD #3
    STD VAR_BALL_VX
    LDD #2
    STD VAR_BALL_VY
    LDD #-30
    STD VAR_BUB_X
    LDD #-20
    STD VAR_BUB_Y
    LDD #-2
    STD VAR_BUB_VX
    LDD #3
    STD VAR_BUB_VY

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD VAR_ARG0
    LDD #110
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2105662470593698      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD >VAR_BALL_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_BALL_VX
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_BALL_X
    LDD >VAR_BALL_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_BALL_VY
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_BALL_Y
    LDD #97
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BALL_X
    CMPD TMPVAL
    LBGT .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_1
    LDD #0
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_BALL_VX
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_BALL_VX
    LDD #97
    STD VAR_BALL_X
    ; PLAY_SFX("hit") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    LDD #-97
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BALL_X
    CMPD TMPVAL
    LBLT .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    LBEQ IF_NEXT_3
    LDD #0
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_BALL_VX
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_BALL_VX
    LDD #-97
    STD VAR_BALL_X
    ; PLAY_SFX("hit") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LDD #77
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BALL_Y
    CMPD TMPVAL
    LBGT .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    LBEQ IF_NEXT_5
    LDD #0
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_BALL_VY
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_BALL_VY
    LDD #77
    STD VAR_BALL_Y
    ; PLAY_SFX("hit") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    LDD #-77
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BALL_Y
    CMPD TMPVAL
    LBLT .CMP_3_TRUE
    LDD #0
    LBRA .CMP_3_END
.CMP_3_TRUE:
    LDD #1
.CMP_3_END:
    LBEQ IF_NEXT_7
    LDD #0
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_BALL_VY
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_BALL_VY
    LDD #-77
    STD VAR_BALL_Y
    ; PLAY_SFX("hit") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
    LDD >VAR_BUB_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_BUB_VX
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_BUB_X
    LDD >VAR_BUB_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_BUB_VY
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_BUB_Y
    LDD #90
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BUB_X
    CMPD TMPVAL
    LBGT .CMP_4_TRUE
    LDD #0
    LBRA .CMP_4_END
.CMP_4_TRUE:
    LDD #1
.CMP_4_END:
    LBEQ IF_NEXT_9
    LDD #0
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_BUB_VX
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_BUB_VX
    LDD #90
    STD VAR_BUB_X
    ; PLAY_SFX("hit") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_8
IF_NEXT_9:
IF_END_8:
    LDD #-90
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BUB_X
    CMPD TMPVAL
    LBLT .CMP_5_TRUE
    LDD #0
    LBRA .CMP_5_END
.CMP_5_TRUE:
    LDD #1
.CMP_5_END:
    LBEQ IF_NEXT_11
    LDD #0
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_BUB_VX
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_BUB_VX
    LDD #-90
    STD VAR_BUB_X
    ; PLAY_SFX("hit") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_10
IF_NEXT_11:
IF_END_10:
    LDD #70
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BUB_Y
    CMPD TMPVAL
    LBGT .CMP_6_TRUE
    LDD #0
    LBRA .CMP_6_END
.CMP_6_TRUE:
    LDD #1
.CMP_6_END:
    LBEQ IF_NEXT_13
    LDD #0
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_BUB_VY
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_BUB_VY
    LDD #70
    STD VAR_BUB_Y
    ; PLAY_SFX("hit") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_12
IF_NEXT_13:
IF_END_12:
    LDD #-70
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BUB_Y
    CMPD TMPVAL
    LBLT .CMP_7_TRUE
    LDD #0
    LBRA .CMP_7_END
.CMP_7_TRUE:
    LDD #1
.CMP_7_END:
    LBEQ IF_NEXT_15
    LDD #0
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_BUB_VY
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_BUB_VY
    LDD #-70
    STD VAR_BUB_Y
    ; PLAY_SFX("hit") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_14
IF_NEXT_15:
IF_END_14:
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: ball (index=0, 1 paths)
    LDD >VAR_BALL_X
    TFR B,A       ; X position (low byte) — B already holds it
    STA TMPPTR    ; Save X to temporary storage
    LDD >VAR_BALL_Y
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
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bubble_small (index=1, 1 paths)
    LDD >VAR_BUB_X
    TFR B,A       ; X position (low byte) — B already holds it
    STA TMPPTR    ; Save X to temporary storage
    LDD >VAR_BUB_Y
    TFR B,A       ; Y position (low byte) — B already holds it
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    LDX #1        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    CLR DRAW_VEC_INTENSITY  ; Reset: next DRAW_VECTOR uses .vec intensities
    LDD #0
    STD RESULT
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #-100
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #80
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #100
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #80
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #60
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #100
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #80
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #100
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #-80
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #60
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #100
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #-80
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #-100
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #-80
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #60
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #-100
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #-80
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #-100
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #80
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #60
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX (after all game logic)
    RTS


; ================================================
