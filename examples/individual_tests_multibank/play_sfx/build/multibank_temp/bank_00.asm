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
DRAW_VEC_INTENSITY   EQU $C880+$1B   ; Vector intensity override (0=use vector data) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$1C   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$26   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$28   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$2A   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$2B   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$2C   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$2E   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$30   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$31   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_ARG0             EQU $C880+$32   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $C880+$34   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $C880+$36   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $C880+$38   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $C880+$3A   ; Function argument 4 (16-bit) (2 bytes)
VAR_ARG5             EQU $C880+$3C   ; Function argument 5 (16-bit) (2 bytes)
VAR_ARG6             EQU $C880+$3E   ; Function argument 6 (16-bit) (2 bytes)
VAR_ARG7             EQU $C880+$40   ; Function argument 7 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $C880+$42   ; Current ROM bank ID (multibank tracking) (1 bytes)
PSG_MUSIC_PTR        EQU $C880+$43   ; PSG music data pointer (2 bytes)
PSG_MUSIC_START      EQU $C880+$45   ; PSG music start pointer (for loops) (2 bytes)
PSG_MUSIC_ACTIVE     EQU $C880+$47   ; PSG music active flag (1 bytes)
PSG_IS_PLAYING       EQU $C880+$48   ; PSG playing flag (1 bytes)
PSG_DELAY_FRAMES     EQU $C880+$49   ; PSG frame delay counter (1 bytes)
PSG_MUSIC_BANK       EQU $C880+$4A   ; PSG music bank ID (for multibank) (1 bytes)
SFX_PTR              EQU $C880+$4B   ; SFX data pointer (2 bytes)
SFX_ACTIVE           EQU $C880+$4D   ; SFX active flag (1 bytes)
SFX_BANK             EQU $C880+$4E   ; SFX bank ID (for multibank) (1 bytes)


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
ABS_A_B EQU $F584
ABS_B EQU $F58B
ADD_SCORE_A EQU $F85E
ADD_SCORE_D EQU $F87C
ASSET_ADDR_TABLE EQU $4008
ASSET_BANK_TABLE EQU $4006
AUDIO_UPDATE EQU $4335
AU_BANK_OK EQU $434F
AU_DONE EQU $43F3
AU_MUSIC_DONE EQU $43C6
AU_MUSIC_ENDED EQU $43CC
AU_MUSIC_HAS_DELAY EQU $438D
AU_MUSIC_LOOP EQU $43D2
AU_MUSIC_NO_DELAY EQU $437E
AU_MUSIC_PROCESS_WRITES EQU $439B
AU_MUSIC_READ EQU $436D
AU_MUSIC_READ_COUNT EQU $437E
AU_MUSIC_WRITE_LOOP EQU $439D
AU_SKIP_MUSIC EQU $43DD
AU_UPDATE_SFX EQU $43E0
Abs_a_b EQU $F584
Abs_b EQU $F58B
Add_Score_a EQU $F85E
Add_Score_d EQU $F87C
BITMASK_A EQU $F57E
Bitmask_a EQU $F57E
CHECK0REF EQU $F34F
CLEAR_C8_RAM EQU $F542
CLEAR_SCORE EQU $F84F
CLEAR_SOUND EQU $F272
CLEAR_X_256 EQU $F545
CLEAR_X_B EQU $F53F
CLEAR_X_B_80 EQU $F550
CLEAR_X_B_A EQU $F552
CLEAR_X_D EQU $F548
COLD_START EQU $F000
COMPARE_SCORE EQU $F8C7
Check0Ref EQU $F34F
Clear_C8_RAM EQU $F542
Clear_Score EQU $F84F
Clear_Sound EQU $F272
Clear_x_256 EQU $F545
Clear_x_b EQU $F53F
Clear_x_b_80 EQU $F550
Clear_x_b_a EQU $F552
Clear_x_d EQU $F548
Cold_Start EQU $F000
Compare_Score EQU $F8C7
DCR_AFTER_INTENSITY EQU $40FE
DCR_INTENSITY_5F EQU $40FB
DCR_after_intensity EQU $40FE
DCR_intensity_5F EQU $40FB
DEC_3_COUNTERS EQU $F55A
DEC_6_COUNTERS EQU $F55E
DEC_COUNTERS EQU $F563
DELAY_0 EQU $F579
DELAY_1 EQU $F575
DELAY_2 EQU $F571
DELAY_3 EQU $F56D
DELAY_B EQU $F57A
DELAY_RTS EQU $F57D
DOT_D EQU $F2C3
DOT_HERE EQU $F2C5
DOT_IX EQU $F2C1
DOT_IX_B EQU $F2BE
DOT_LIST EQU $F2D5
DOT_LIST_RESET EQU $F2DE
DO_SOUND EQU $F289
DO_SOUND_X EQU $F28C
DP_TO_C8 EQU $F1AF
DP_TO_D0 EQU $F1AA
DP_to_C8 EQU $F1AF
DP_to_D0 EQU $F1AA
DRAW_CIRCLE_RUNTIME EQU $40C8
DRAW_GRID_VL EQU $FF9F
DRAW_LINE_D EQU $F3DF
DRAW_PAT_VL EQU $F437
DRAW_PAT_VL_A EQU $F434
DRAW_PAT_VL_D EQU $F439
DRAW_VL EQU $F3DD
DRAW_VLC EQU $F3CE
DRAW_VLCS EQU $F3D6
DRAW_VLP EQU $F410
DRAW_VLP_7F EQU $F408
DRAW_VLP_B EQU $F40E
DRAW_VLP_FF EQU $F404
DRAW_VLP_SCALE EQU $F40C
DRAW_VL_A EQU $F3DA
DRAW_VL_AB EQU $F3D8
DRAW_VL_B EQU $F3D2
DRAW_VL_MODE EQU $F46E
Dec_3_Counters EQU $F55A
Dec_6_Counters EQU $F55E
Dec_Counters EQU $F563
Delay_0 EQU $F579
Delay_1 EQU $F575
Delay_2 EQU $F571
Delay_3 EQU $F56D
Delay_RTS EQU $F57D
Delay_b EQU $F57A
Do_Sound EQU $F289
Do_Sound_x EQU $F28C
Dot_List EQU $F2D5
Dot_List_Reset EQU $F2DE
Dot_d EQU $F2C3
Dot_here EQU $F2C5
Dot_ix EQU $F2C1
Dot_ix_b EQU $F2BE
Draw_Grid_VL EQU $FF9F
Draw_Line_d EQU $F3DF
Draw_Pat_VL EQU $F437
Draw_Pat_VL_a EQU $F434
Draw_Pat_VL_d EQU $F439
Draw_VL EQU $F3DD
Draw_VL_a EQU $F3DA
Draw_VL_ab EQU $F3D8
Draw_VL_b EQU $F3D2
Draw_VL_mode EQU $F46E
Draw_VLc EQU $F3CE
Draw_VLcs EQU $F3D6
Draw_VLp EQU $F410
Draw_VLp_7F EQU $F408
Draw_VLp_FF EQU $F404
Draw_VLp_b EQU $F40E
Draw_VLp_scale EQU $F40C
EXPLOSION_SND EQU $F92E
Explosion_Snd EQU $F92E
GET_RISE_IDX EQU $F5D9
GET_RISE_RUN EQU $F5EF
GET_RUN_IDX EQU $F5DB
Get_Rise_Idx EQU $F5D9
Get_Rise_Run EQU $F5EF
Get_Run_Idx EQU $F5DB
INIT_MUSIC EQU $F68D
INIT_MUSIC_BUF EQU $F533
INIT_MUSIC_CHK EQU $F687
INIT_MUSIC_X EQU $F692
INIT_OS EQU $F18B
INIT_OS_RAM EQU $F164
INIT_VIA EQU $F14C
INTENSITY_1F EQU $F29D
INTENSITY_3F EQU $F2A1
INTENSITY_5F EQU $F2A5
INTENSITY_7F EQU $F2A9
INTENSITY_A EQU $F2AB
Init_Music EQU $F68D
Init_Music_Buf EQU $F533
Init_Music_chk EQU $F687
Init_Music_x EQU $F692
Init_OS EQU $F18B
Init_OS_RAM EQU $F164
Init_VIA EQU $F14C
Intensity_1F EQU $F29D
Intensity_3F EQU $F2A1
Intensity_5F EQU $F2A5
Intensity_7F EQU $F2A9
Intensity_a EQU $F2AB
JOY_ANALOG EQU $F1F5
JOY_DIGITAL EQU $F1F8
Joy_Analog EQU $F1F5
Joy_Digital EQU $F1F8
MOD16 EQU $4074
MOD16.M16_DONE EQU $40C7
MOD16.M16_DPOS EQU $4091
MOD16.M16_END EQU $40B8
MOD16.M16_LOOP EQU $40A8
MOD16.M16_RCHECK EQU $4099
MOD16.M16_RPOS EQU $40A8
MOVETO_D EQU $F312
MOVETO_D_7F EQU $F2FC
MOVETO_IX EQU $F310
MOVETO_IX_7F EQU $F30C
MOVETO_IX_A EQU $F30E
MOVETO_IX_FF EQU $F308
MOVETO_X_7F EQU $F2F2
MOVE_MEM_A EQU $F683
MOVE_MEM_A_1 EQU $F67F
MOV_DRAW_VL EQU $F3BC
MOV_DRAW_VLCS EQU $F3B5
MOV_DRAW_VLC_A EQU $F3AD
MOV_DRAW_VL_A EQU $F3B9
MOV_DRAW_VL_AB EQU $F3B7
MOV_DRAW_VL_B EQU $F3B1
MOV_DRAW_VL_D EQU $F3BE
MUSIC1 EQU $FD0D
MUSIC2 EQU $FD1D
MUSIC3 EQU $FD81
MUSIC4 EQU $FDD3
MUSIC5 EQU $FE38
MUSIC6 EQU $FE76
MUSIC7 EQU $FEC6
MUSIC8 EQU $FEF8
MUSIC9 EQU $FF26
MUSICA EQU $FF44
MUSICB EQU $FF62
MUSICC EQU $FF7A
MUSICD EQU $FF8F
Mov_Draw_VL EQU $F3BC
Mov_Draw_VL_a EQU $F3B9
Mov_Draw_VL_ab EQU $F3B7
Mov_Draw_VL_b EQU $F3B1
Mov_Draw_VL_d EQU $F3BE
Mov_Draw_VLc_a EQU $F3AD
Mov_Draw_VLcs EQU $F3B5
Move_Mem_a EQU $F683
Move_Mem_a_1 EQU $F67F
Moveto_d EQU $F312
Moveto_d_7F EQU $F2FC
Moveto_ix EQU $F310
Moveto_ix_7F EQU $F30C
Moveto_ix_FF EQU $F308
Moveto_ix_a EQU $F30E
Moveto_x_7F EQU $F2F2
NEW_HIGH_SCORE EQU $F8D8
NOAY EQU $4411
New_High_Score EQU $F8D8
OBJ_HIT EQU $F8FF
OBJ_WILL_HIT EQU $F8F3
OBJ_WILL_HIT_U EQU $F8E5
Obj_Hit EQU $F8FF
Obj_Will_Hit EQU $F8F3
Obj_Will_Hit_u EQU $F8E5
PLAY_MUSIC_RUNTIME EQU $4217
PLAY_SFX_BANKED EQU $400C
PLAY_SFX_RUNTIME EQU $43FE
PMR_DONE EQU $4257
PMR_START_NEW EQU $4225
PMr_done EQU $4257
PMr_start_new EQU $4225
PRINT_LIST EQU $F38A
PRINT_LIST_CHK EQU $F38C
PRINT_LIST_HW EQU $F385
PRINT_SHIPS EQU $F393
PRINT_SHIPS_X EQU $F391
PRINT_STR EQU $F495
PRINT_STR_D EQU $F37A
PRINT_STR_HWYX EQU $F373
PRINT_STR_YX EQU $F378
PRINT_TEXT_STR_2348223718253 EQU $44A8
PRINT_TEXT_STR_3273774 EQU $44A3
PRINT_TEXT_STR_58672554795414 EQU $44B1
PRINT_TEXT_STR_58672583180530 EQU $44BB
PRINT_TEXT_STR_89546106876693 EQU $44C5
PSG_EVENT_DONE EQU $42D3
PSG_MUSIC_ENDED EQU $42DC
PSG_MUSIC_LOOP EQU $42F7
PSG_MUSIC_LOOP_D EQU $4302
PSG_PROCESS_EVENT EQU $4291
PSG_READ_DELAY EQU $4276
PSG_UPDATE_DONE EQU $430A
PSG_WRITE_LOOP EQU $42A2
PSG_event_done EQU $42D3
PSG_music_ended EQU $42DC
PSG_music_loop EQU $42F7
PSG_music_loop_d EQU $4302
PSG_process_event EQU $4291
PSG_read_delay EQU $4276
PSG_update_done EQU $430A
PSG_write_loop EQU $42A2
Print_List EQU $F38A
Print_List_chk EQU $F38C
Print_List_hw EQU $F385
Print_Ships EQU $F393
Print_Ships_x EQU $F391
Print_Str EQU $F495
Print_Str_d EQU $F37A
Print_Str_hwyx EQU $F373
Print_Str_yx EQU $F378
RANDOM EQU $F517
RANDOM_3 EQU $F511
READ_BTNS EQU $F1BA
READ_BTNS_MASK EQU $F1B4
RECALIBRATE EQU $F2E6
RESET0INT EQU $F36B
RESET0REF EQU $F354
RESET0REF_D0 EQU $F34A
RESET_PEN EQU $F35B
RISE_RUN_ANGLE EQU $F593
RISE_RUN_LEN EQU $F603
RISE_RUN_X EQU $F5FF
RISE_RUN_Y EQU $F601
ROT_VL EQU $F616
ROT_VL_AB EQU $F610
ROT_VL_DFT EQU $F637
ROT_VL_MODE EQU $F62B
ROT_VL_MODE_A EQU $F61F
Random EQU $F517
Random_3 EQU $F511
Read_Btns EQU $F1BA
Read_Btns_Mask EQU $F1B4
Recalibrate EQU $F2E6
Reset0Int EQU $F36B
Reset0Ref EQU $F354
Reset0Ref_D0 EQU $F34A
Reset_Pen EQU $F35B
Rise_Run_Angle EQU $F593
Rise_Run_Len EQU $F603
Rise_Run_X EQU $F5FF
Rise_Run_Y EQU $F601
Rot_VL EQU $F616
Rot_VL_Mode EQU $F62B
Rot_VL_Mode_a EQU $F61F
Rot_VL_ab EQU $F610
Rot_VL_dft EQU $F637
SELECT_GAME EQU $F7A9
SET_REFRESH EQU $F1A2
SFX_ADDR_TABLE EQU $4002
SFX_BANK_TABLE EQU $4000
SFX_CHECKNOISEFREQ EQU $443F
SFX_CHECKTONEFREQ EQU $4425
SFX_CHECKVOLUME EQU $4450
SFX_DOFRAME EQU $4412
SFX_ENDOFEFFECT EQU $4485
SFX_M_NOISE EQU $446B
SFX_M_NOISEDIS EQU $4476
SFX_M_TONEDIS EQU $4469
SFX_M_WRITE EQU $4478
SFX_NEXTFRAME EQU $4480
SFX_UPDATE EQU $4407
SFX_UPDATEMIXER EQU $4459
SOUND_BYTE EQU $F256
SOUND_BYTES EQU $F27D
SOUND_BYTES_X EQU $F284
SOUND_BYTE_RAW EQU $F25B
SOUND_BYTE_X EQU $F259
STOP_MUSIC_RUNTIME EQU $430E
STRIP_ZEROS EQU $F8B7
Select_Game EQU $F7A9
Set_Refresh EQU $F1A2
Sound_Byte EQU $F256
Sound_Byte_raw EQU $F25B
Sound_Byte_x EQU $F259
Sound_Bytes EQU $F27D
Sound_Bytes_x EQU $F284
Strip_Zeros EQU $F8B7
UPDATE_MUSIC_PSG EQU $4258
VECTREX_PRINT_TEXT EQU $403A
VEC_0REF_ENABLE EQU $C824
VEC_ADSR_TABLE EQU $C84F
VEC_ADSR_TIMERS EQU $C85E
VEC_ANGLE EQU $C836
VEC_BRIGHTNESS EQU $C827
VEC_BTN_STATE EQU $C80F
VEC_BUTTONS EQU $C811
VEC_BUTTON_1_1 EQU $C812
VEC_BUTTON_1_2 EQU $C813
VEC_BUTTON_1_3 EQU $C814
VEC_BUTTON_1_4 EQU $C815
VEC_BUTTON_2_1 EQU $C816
VEC_BUTTON_2_2 EQU $C817
VEC_BUTTON_2_3 EQU $C818
VEC_BUTTON_2_4 EQU $C819
VEC_COLD_FLAG EQU $CBFE
VEC_COUNTERS EQU $C82E
VEC_COUNTER_1 EQU $C82E
VEC_COUNTER_2 EQU $C82F
VEC_COUNTER_3 EQU $C830
VEC_COUNTER_4 EQU $C831
VEC_COUNTER_5 EQU $C832
VEC_COUNTER_6 EQU $C833
VEC_DEFAULT_STK EQU $CBEA
VEC_DOT_DWELL EQU $C828
VEC_DURATION EQU $C857
VEC_EXPL_1 EQU $C858
VEC_EXPL_2 EQU $C859
VEC_EXPL_3 EQU $C85A
VEC_EXPL_4 EQU $C85B
VEC_EXPL_CHAN EQU $C85C
VEC_EXPL_CHANA EQU $C853
VEC_EXPL_CHANB EQU $C85D
VEC_EXPL_CHANS EQU $C854
VEC_EXPL_FLAG EQU $C867
VEC_EXPL_TIMER EQU $C877
VEC_FIRQ_VECTOR EQU $CBF5
VEC_FREQ_TABLE EQU $C84D
VEC_HIGH_SCORE EQU $CBEB
VEC_IRQ_VECTOR EQU $CBF8
VEC_JOY_1_X EQU $C81B
VEC_JOY_1_Y EQU $C81C
VEC_JOY_2_X EQU $C81D
VEC_JOY_2_Y EQU $C81E
VEC_JOY_MUX EQU $C81F
VEC_JOY_MUX_1_X EQU $C81F
VEC_JOY_MUX_1_Y EQU $C820
VEC_JOY_MUX_2_X EQU $C821
VEC_JOY_MUX_2_Y EQU $C822
VEC_JOY_RESLTN EQU $C81A
VEC_LOOP_COUNT EQU $C825
VEC_MAX_GAMES EQU $C850
VEC_MAX_PLAYERS EQU $C84F
VEC_MISC_COUNT EQU $C823
VEC_MUSIC_CHAN EQU $C855
VEC_MUSIC_FLAG EQU $C856
VEC_MUSIC_FREQ EQU $C861
VEC_MUSIC_PTR EQU $C853
VEC_MUSIC_TWANG EQU $C858
VEC_MUSIC_WK_1 EQU $C84B
VEC_MUSIC_WK_5 EQU $C847
VEC_MUSIC_WK_6 EQU $C846
VEC_MUSIC_WK_7 EQU $C845
VEC_MUSIC_WK_A EQU $C842
VEC_MUSIC_WORK EQU $C83F
VEC_NMI_VECTOR EQU $CBFB
VEC_NUM_GAME EQU $C87A
VEC_NUM_PLAYERS EQU $C879
VEC_PATTERN EQU $C829
VEC_PREV_BTNS EQU $C810
VEC_RANDOM_SEED EQU $C87D
VEC_RFRSH EQU $C83D
VEC_RFRSH_HI EQU $C83E
VEC_RFRSH_LO EQU $C83D
VEC_RISERUN_LEN EQU $C83B
VEC_RISERUN_TMP EQU $C834
VEC_RISE_INDEX EQU $C839
VEC_RUN_INDEX EQU $C837
VEC_SEED_PTR EQU $C87B
VEC_SND_SHADOW EQU $C800
VEC_STR_PTR EQU $C82C
VEC_SWI2_VECTOR EQU $CBF2
VEC_SWI3_VECTOR EQU $CBF2
VEC_SWI_VECTOR EQU $CBFB
VEC_TEXT_HEIGHT EQU $C82A
VEC_TEXT_HW EQU $C82A
VEC_TEXT_WIDTH EQU $C82B
VEC_TWANG_TABLE EQU $C851
Vec_0Ref_Enable EQU $C824
Vec_ADSR_Table EQU $C84F
Vec_ADSR_Timers EQU $C85E
Vec_Angle EQU $C836
Vec_Brightness EQU $C827
Vec_Btn_State EQU $C80F
Vec_Button_1_1 EQU $C812
Vec_Button_1_2 EQU $C813
Vec_Button_1_3 EQU $C814
Vec_Button_1_4 EQU $C815
Vec_Button_2_1 EQU $C816
Vec_Button_2_2 EQU $C817
Vec_Button_2_3 EQU $C818
Vec_Button_2_4 EQU $C819
Vec_Buttons EQU $C811
Vec_Cold_Flag EQU $CBFE
Vec_Counter_1 EQU $C82E
Vec_Counter_2 EQU $C82F
Vec_Counter_3 EQU $C830
Vec_Counter_4 EQU $C831
Vec_Counter_5 EQU $C832
Vec_Counter_6 EQU $C833
Vec_Counters EQU $C82E
Vec_Default_Stk EQU $CBEA
Vec_Dot_Dwell EQU $C828
Vec_Duration EQU $C857
Vec_Expl_1 EQU $C858
Vec_Expl_2 EQU $C859
Vec_Expl_3 EQU $C85A
Vec_Expl_4 EQU $C85B
Vec_Expl_Chan EQU $C85C
Vec_Expl_ChanA EQU $C853
Vec_Expl_ChanB EQU $C85D
Vec_Expl_Chans EQU $C854
Vec_Expl_Flag EQU $C867
Vec_Expl_Timer EQU $C877
Vec_FIRQ_Vector EQU $CBF5
Vec_Freq_Table EQU $C84D
Vec_High_Score EQU $CBEB
Vec_IRQ_Vector EQU $CBF8
Vec_Joy_1_X EQU $C81B
Vec_Joy_1_Y EQU $C81C
Vec_Joy_2_X EQU $C81D
Vec_Joy_2_Y EQU $C81E
Vec_Joy_Mux EQU $C81F
Vec_Joy_Mux_1_X EQU $C81F
Vec_Joy_Mux_1_Y EQU $C820
Vec_Joy_Mux_2_X EQU $C821
Vec_Joy_Mux_2_Y EQU $C822
Vec_Joy_Resltn EQU $C81A
Vec_Loop_Count EQU $C825
Vec_Max_Games EQU $C850
Vec_Max_Players EQU $C84F
Vec_Misc_Count EQU $C823
Vec_Music_Chan EQU $C855
Vec_Music_Flag EQU $C856
Vec_Music_Freq EQU $C861
Vec_Music_Ptr EQU $C853
Vec_Music_Twang EQU $C858
Vec_Music_Wk_1 EQU $C84B
Vec_Music_Wk_5 EQU $C847
Vec_Music_Wk_6 EQU $C846
Vec_Music_Wk_7 EQU $C845
Vec_Music_Wk_A EQU $C842
Vec_Music_Work EQU $C83F
Vec_NMI_Vector EQU $CBFB
Vec_Num_Game EQU $C87A
Vec_Num_Players EQU $C879
Vec_Pattern EQU $C829
Vec_Prev_Btns EQU $C810
Vec_Random_Seed EQU $C87D
Vec_Rfrsh EQU $C83D
Vec_Rfrsh_hi EQU $C83E
Vec_Rfrsh_lo EQU $C83D
Vec_RiseRun_Len EQU $C83B
Vec_RiseRun_Tmp EQU $C834
Vec_Rise_Index EQU $C839
Vec_Run_Index EQU $C837
Vec_SWI2_Vector EQU $CBF2
Vec_SWI3_Vector EQU $CBF2
Vec_SWI_Vector EQU $CBFB
Vec_Seed_Ptr EQU $C87B
Vec_Snd_Shadow EQU $C800
Vec_Str_Ptr EQU $C82C
Vec_Text_HW EQU $C82A
Vec_Text_Height EQU $C82A
Vec_Text_Width EQU $C82B
Vec_Twang_Table EQU $C851
WAIT_RECAL EQU $F192
WARM_START EQU $F06C
Wait_Recal EQU $F192
Warm_Start EQU $F06C
XFORM_RISE EQU $F663
XFORM_RISE_A EQU $F661
XFORM_RUN EQU $F65D
XFORM_RUN_A EQU $F65B
Xform_Rise EQU $F663
Xform_Rise_a EQU $F661
Xform_Run EQU $F65D
Xform_Run_a EQU $F65B
music1 EQU $FD0D
music2 EQU $FD1D
music3 EQU $FD81
music4 EQU $FDD3
music5 EQU $FE38
music6 EQU $FE76
music7 EQU $FEC6
music8 EQU $FEF8
music9 EQU $FF26
musica EQU $FF44
musicb EQU $FF62
musicc EQU $FF7A
musicd EQU $FF8F
noay EQU $4411
sfx_checknoisefreq EQU $443F
sfx_checktonefreq EQU $4425
sfx_checkvolume EQU $4450
sfx_doframe EQU $4412
sfx_endofeffect EQU $4485
sfx_m_noise EQU $446B
sfx_m_noisedis EQU $4476
sfx_m_tonedis EQU $4469
sfx_m_write EQU $4478
sfx_nextframe EQU $4480
sfx_updatemixer EQU $4459


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "PLAY_SFX"
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
    LDS #$CFFF       ; Stack -> top of Vectrex 2KB RAM (avoids user var collision)

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
DRAW_CIRCLE_XC       EQU $C880+$0E   ; Circle center X (1 bytes)
DRAW_CIRCLE_YC       EQU $C880+$0F   ; Circle center Y (1 bytes)
DRAW_CIRCLE_DIAM     EQU $C880+$10   ; Circle diameter (1 bytes)
DRAW_CIRCLE_INTENSITY EQU $C880+$11   ; Circle intensity (1 bytes)
DRAW_CIRCLE_RADIUS   EQU $C880+$12   ; Circle radius (diam/2) - used in segment drawing (1 bytes)
DRAW_CIRCLE_TEMP     EQU $C880+$13   ; Circle temporary buffer (8 bytes: radius16, a, b, c, d, --, --)  a=0.383r b=0.324r c=0.217r d=0.076r (8 bytes)
DRAW_VEC_INTENSITY   EQU $C880+$1B   ; Vector intensity override (0=use vector data) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$1C   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$26   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$28   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$2A   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$2B   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$2C   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$2E   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$30   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$31   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_ARG0             EQU $C880+$32   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $C880+$34   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $C880+$36   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $C880+$38   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $C880+$3A   ; Function argument 4 (16-bit) (2 bytes)
VAR_ARG5             EQU $C880+$3C   ; Function argument 5 (16-bit) (2 bytes)
VAR_ARG6             EQU $C880+$3E   ; Function argument 6 (16-bit) (2 bytes)
VAR_ARG7             EQU $C880+$40   ; Function argument 7 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $C880+$42   ; Current ROM bank ID (multibank tracking) (1 bytes)
PSG_MUSIC_PTR        EQU $C880+$43   ; PSG music data pointer (2 bytes)
PSG_MUSIC_START      EQU $C880+$45   ; PSG music start pointer (for loops) (2 bytes)
PSG_MUSIC_ACTIVE     EQU $C880+$47   ; PSG music active flag (1 bytes)
PSG_IS_PLAYING       EQU $C880+$48   ; PSG playing flag (1 bytes)
PSG_DELAY_FRAMES     EQU $C880+$49   ; PSG frame delay counter (1 bytes)
PSG_MUSIC_BANK       EQU $C880+$4A   ; PSG music bank ID (for multibank) (1 bytes)
SFX_PTR              EQU $C880+$4B   ; SFX data pointer (2 bytes)
SFX_ACTIVE           EQU $C880+$4D   ; SFX active flag (1 bytes)
SFX_BANK             EQU $C880+$4E   ; SFX bank ID (for multibank) (1 bytes)

;***************************************************************************
; MAIN PROGRAM (Bank #0)
;***************************************************************************

MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    CLR DRAW_VEC_INTENSITY ; 0 = use recorded/vector intensity (no override)
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
; VPy_LINE:11
    ; TODO: Statement Pass { source_line: 11 }

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
; VPy_LINE:14
; NATIVE_CALL: PRINT_TEXT at line 14
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD >VAR_ARG0
    LDD #80
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2348223718253      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:15
; NATIVE_CALL: PRINT_TEXT at line 15
    ; PRINT_TEXT: Print text at position
    LDD #-80
    STD >VAR_ARG0
    LDD #50
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_58672554795414      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:16
; NATIVE_CALL: PRINT_TEXT at line 16
    ; PRINT_TEXT: Print text at position
    LDD #-80
    STD >VAR_ARG0
    LDD #30
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_58672583180530      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:18
    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed
    BITA #$01
    LBNE .J1B1_0_ON
    LDD #0
    LBRA .J1B1_0_END
.J1B1_0_ON:
    LDD #1
.J1B1_0_END:
    STD RESULT
    LBEQ IF_NEXT_1
; VPy_LINE:19
; NATIVE_CALL: PLAY_SFX at line 19
    ; PLAY_SFX("jump") - play SFX asset (index=1)
    LDX #1        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
; VPy_LINE:20
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$64
    JSR Intensity_a
    LDA #$EC
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
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
; VPy_LINE:22
    LDA >$C80F   ; Vec_Btns_1: bit1=1 means btn2 pressed
    BITA #$02
    LBNE .J1B2_1_ON
    LDD #0
    LBRA .J1B2_1_END
.J1B2_1_ON:
    LDD #1
.J1B2_1_END:
    STD RESULT
    LBEQ IF_NEXT_3
; VPy_LINE:23
; NATIVE_CALL: PLAY_SFX at line 23
    ; PLAY_SFX("explosion") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
; VPy_LINE:24
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$64
    JSR Intensity_a
    LDA #$EC
    LDB #$1E
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$0B
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$0A
    LDB #$F9
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$07
    LDB #$F6
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$F5
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$F5
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$F9
    LDB #$F6
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$F6
    LDB #$F9
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$F5
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$F5
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$F6
    LDB #$07
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$F9
    LDB #$0A
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$0B
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$0B
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$07
    LDB #$0A
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$0A
    LDB #$07
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$0B
    LDB #$02
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
; VPy_LINE:27
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$28
    JSR Intensity_a
    LDA #$EC
    LDB #$05
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX (after all game logic)
    RTS


; ================================================
