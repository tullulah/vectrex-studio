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
DRAW_RECT_X          EQU $C880+$1B   ; Rectangle X (1 bytes)
DRAW_RECT_Y          EQU $C880+$1C   ; Rectangle Y (1 bytes)
DRAW_RECT_WIDTH      EQU $C880+$1D   ; Rectangle width (1 bytes)
DRAW_RECT_HEIGHT     EQU $C880+$1E   ; Rectangle height (1 bytes)
DRAW_RECT_INTENSITY  EQU $C880+$1F   ; Rectangle intensity (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$20   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$2A   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$2C   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$2E   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$2F   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$30   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$32   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$34   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$35   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
BEEP_FRAMES_LEFT     EQU $C880+$36   ; Beep countdown timer (frames remaining) (1 bytes)
VAR_PLAYING          EQU $C880+$37   ; User variable: PLAYING (2 bytes)
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
Draw_VLc EQU $F3CE
Vec_Counter_5 EQU $C832
VEC_MISC_COUNT EQU $C823
MUSIC7 EQU $FEC6
sfx_checkvolume EQU $4433
VEC_BUTTON_1_2 EQU $C813
VEC_COUNTER_1 EQU $C82E
Do_Sound EQU $F289
SOUND_BYTE_RAW EQU $F25B
ADD_SCORE_D EQU $F87C
DRAW_VL_B EQU $F3D2
SOUND_BYTE EQU $F256
VEC_COUNTER_2 EQU $C82F
VEC_ADSR_TABLE EQU $C84F
Sound_Bytes EQU $F27D
CLEAR_C8_RAM EQU $F542
Draw_VL EQU $F3DD
Mov_Draw_VL_d EQU $F3BE
SET_REFRESH EQU $F1A2
Vec_NMI_Vector EQU $CBFB
Delay_RTS EQU $F57D
VEC_JOY_RESLTN EQU $C81A
Vec_SWI3_Vector EQU $CBF2
Vec_SWI2_Vector EQU $CBF2
MOVETO_IX_A EQU $F30E
music3 EQU $FD81
VEC_MUSIC_FLAG EQU $C856
Do_Sound_x EQU $F28C
MOV_DRAW_VLC_A EQU $F3AD
VEC_MUSIC_PTR EQU $C853
INTENSITY_A EQU $F2AB
Rise_Run_Angle EQU $F593
sfx_checktonefreq EQU $4408
DELAY_RTS EQU $F57D
Draw_Pat_VL EQU $F437
Vec_Expl_ChanB EQU $C85D
MOV_DRAW_VL EQU $F3BC
MOV_DRAW_VLCS EQU $F3B5
Vec_Random_Seed EQU $C87D
MOVE_MEM_A_1 EQU $F67F
Draw_VLcs EQU $F3D6
Vec_Counter_1 EQU $C82E
ROT_VL_MODE EQU $F62B
INIT_MUSIC_CHK EQU $F687
MOVE_MEM_A EQU $F683
VEC_EXPL_CHAN EQU $C85C
Vec_RiseRun_Tmp EQU $C834
Clear_x_b EQU $F53F
INIT_OS_RAM EQU $F164
WARM_START EQU $F06C
PSG_update_done EQU $430C
Draw_VLp_scale EQU $F40C
INTENSITY_5F EQU $F2A5
Print_Ships_x EQU $F391
Vec_Joy_2_X EQU $C81D
SOUND_BYTES EQU $F27D
SOUND_BYTES_X EQU $F284
PSG_WRITE_LOOP EQU $42C7
Vec_Misc_Count EQU $C823
Vec_Joy_Mux_1_X EQU $C81F
Moveto_x_7F EQU $F2F2
MUSIC2 EQU $FD1D
Get_Rise_Run EQU $F5EF
sfx_endofeffect EQU $4468
Rot_VL EQU $F616
Vec_Counter_6 EQU $C833
Vec_Counter_3 EQU $C830
Vec_0Ref_Enable EQU $C824
VEC_EXPL_1 EQU $C858
ABS_B EQU $F58B
Mov_Draw_VL_a EQU $F3B9
SFX_ENDOFEFFECT EQU $4468
Vec_Angle EQU $C836
Vec_Counter_4 EQU $C831
PSG_UPDATE_DONE EQU $430C
PSG_MUSIC_ENDED EQU $42FE
Vec_Expl_ChanA EQU $C853
COMPARE_SCORE EQU $F8C7
VEC_STR_PTR EQU $C82C
MOD16.M16_RCHECK EQU $4093
VEC_ANGLE EQU $C836
music2 EQU $FD1D
Mov_Draw_VL_ab EQU $F3B7
Explosion_Snd EQU $F92E
Dot_here EQU $F2C5
Vec_Music_Wk_1 EQU $C84B
Vec_Button_2_2 EQU $C817
DRAW_VLP_B EQU $F40E
DRAW_VLP_SCALE EQU $F40C
UPDATE_MUSIC_PSG EQU $42AA
VEC_TEXT_WIDTH EQU $C82B
VEC_BUTTON_1_3 EQU $C814
ROT_VL_DFT EQU $F637
Vec_RiseRun_Len EQU $C83B
SOUND_BYTE_X EQU $F259
SFX_M_NOISE EQU $444E
INIT_MUSIC_BUF EQU $F533
CLEAR_X_B_80 EQU $F550
Sound_Byte_x EQU $F259
MUSICB EQU $FF62
PMr_done EQU $42A9
INIT_MUSIC_X EQU $F692
DRAW_VLC EQU $F3CE
Init_OS_RAM EQU $F164
OBJ_HIT EQU $F8FF
MOVETO_D_7F EQU $F2FC
VEC_NMI_VECTOR EQU $CBFB
VEC_BUTTON_2_1 EQU $C816
Reset_Pen EQU $F35B
Vec_Expl_Flag EQU $C867
music6 EQU $FE76
SFX_DOFRAME EQU $43F5
Moveto_ix EQU $F310
Draw_VL_mode EQU $F46E
GET_RISE_RUN EQU $F5EF
STOP_MUSIC_RUNTIME EQU $4310
DOT_IX_B EQU $F2BE
Clear_Score EQU $F84F
Strip_Zeros EQU $F8B7
Random EQU $F517
Vec_Text_HW EQU $C82A
Vec_Counter_2 EQU $C82F
VEC_RFRSH EQU $C83D
VEC_RFRSH_LO EQU $C83D
Moveto_ix_7F EQU $F30C
VEC_DEFAULT_STK EQU $CBEA
music7 EQU $FEC6
VEC_COLD_FLAG EQU $CBFE
Vec_Music_Ptr EQU $C853
Vec_Rfrsh EQU $C83D
Vec_Joy_Mux EQU $C81F
VEC_MUSIC_WORK EQU $C83F
VEC_SWI2_VECTOR EQU $CBF2
Vec_Button_2_3 EQU $C818
VEC_SWI_VECTOR EQU $CBFB
sfx_m_noisedis EQU $4459
Vec_Expl_Chans EQU $C854
Joy_Analog EQU $F1F5
VEC_JOY_MUX_1_Y EQU $C820
MUSIC1 EQU $FD0D
DOT_IX EQU $F2C1
DRAW_CIRCLE_RUNTIME EQU $40C2
XFORM_RISE_A EQU $F661
Rot_VL_Mode EQU $F62B
Obj_Hit EQU $F8FF
PMR_DONE EQU $42A9
Xform_Run_a EQU $F65B
VEC_DURATION EQU $C857
VEC_NUM_PLAYERS EQU $C879
Init_Music_x EQU $F692
PSG_music_ended EQU $42FE
AU_BANK_OK EQU $4351
VEC_ADSR_TIMERS EQU $C85E
Vec_Text_Height EQU $C82A
Dec_3_Counters EQU $F55A
Rot_VL_dft EQU $F637
Set_Refresh EQU $F1A2
sfx_m_noise EQU $444E
Draw_VLp_FF EQU $F404
PSG_music_loop EQU $4304
DCR_after_intensity EQU $40FA
Move_Mem_a_1 EQU $F67F
Vec_Rfrsh_hi EQU $C83E
DELAY_1 EQU $F575
Vec_Max_Players EQU $C84F
Rot_VL_Mode_a EQU $F61F
Init_OS EQU $F18B
AU_MUSIC_ENDED EQU $43B8
READ_BTNS_MASK EQU $F1B4
Reset0Int EQU $F36B
SFX_UPDATEMIXER EQU $443C
VEC_MAX_GAMES EQU $C850
RANDOM_3 EQU $F511
Vec_Num_Game EQU $C87A
VEC_JOY_2_X EQU $C81D
Moveto_d_7F EQU $F2FC
sfx_m_write EQU $445B
ABS_A_B EQU $F584
VEC_TWANG_TABLE EQU $C851
RANDOM EQU $F517
Delay_1 EQU $F575
Mov_Draw_VL_b EQU $F3B1
PRINT_TEXT_STR_3232159404 EQU $44A5
Vec_Counters EQU $C82E
VEC_BUTTON_2_4 EQU $C819
Mov_Draw_VLc_a EQU $F3AD
CLEAR_X_D EQU $F548
Vec_Joy_Mux_1_Y EQU $C820
PRINT_TEXT_STR_2110696929079206 EQU $44C4
VEC_RUN_INDEX EQU $C837
Wait_Recal EQU $F192
RISE_RUN_X EQU $F5FF
Vec_FIRQ_Vector EQU $CBF5
DCR_AFTER_INTENSITY EQU $40FA
AU_MUSIC_READ_COUNT EQU $4380
DP_to_C8 EQU $F1AF
music8 EQU $FEF8
Draw_Pat_VL_d EQU $F439
Vec_Expl_Timer EQU $C877
PRINT_LIST_CHK EQU $F38C
CLEAR_SOUND EQU $F272
VEC_TEXT_HEIGHT EQU $C82A
MOV_DRAW_VL_AB EQU $F3B7
Vec_Freq_Table EQU $C84D
MOVETO_X_7F EQU $F2F2
VEC_MUSIC_WK_1 EQU $C84B
VEC_RISE_INDEX EQU $C839
MUSICA EQU $FF44
READ_BTNS EQU $F1BA
Vec_Btn_State EQU $C80F
DRAW_PAT_VL EQU $F437
PSG_write_loop EQU $42C7
VEC_JOY_1_Y EQU $C81C
DCR_INTENSITY_5F EQU $40F7
VEC_BUTTON_2_2 EQU $C817
Vec_Music_Freq EQU $C861
DRAW_LINE_D EQU $F3DF
VEC_JOY_1_X EQU $C81B
VEC_EXPL_2 EQU $C859
Vec_Prev_Btns EQU $C810
Vec_High_Score EQU $CBEB
Dec_6_Counters EQU $F55E
VEC_EXPL_CHANA EQU $C853
musica EQU $FF44
VEC_BRIGHTNESS EQU $C827
Vec_Rfrsh_lo EQU $C83D
Vec_Snd_Shadow EQU $C800
Draw_VLp EQU $F410
VEC_BUTTON_2_3 EQU $C818
MUSICD EQU $FF8F
VEC_MUSIC_WK_5 EQU $C847
Bitmask_a EQU $F57E
Vec_Joy_Resltn EQU $C81A
DRAW_RECT_RUNTIME EQU $4207
VEC_SWI3_VECTOR EQU $CBF2
Obj_Will_Hit EQU $F8F3
Vec_Joy_2_Y EQU $C81E
sfx_doframe EQU $43F5
INTENSITY_1F EQU $F29D
Vec_Default_Stk EQU $CBEA
SFX_M_WRITE EQU $445B
DELAY_3 EQU $F56D
New_High_Score EQU $F8D8
SFX_CHECKVOLUME EQU $4433
Vec_Music_Wk_6 EQU $C846
GET_RISE_IDX EQU $F5D9
PRINT_TEXT_STR_60036864546 EQU $44AC
VEC_HIGH_SCORE EQU $CBEB
Clear_x_b_a EQU $F552
OBJ_WILL_HIT EQU $F8F3
VEC_JOY_MUX EQU $C81F
VEC_COUNTER_4 EQU $C831
Sound_Byte EQU $F256
INIT_VIA EQU $F14C
AU_MUSIC_READ EQU $436F
Joy_Digital EQU $F1F8
Vec_Loop_Count EQU $C825
Sound_Byte_raw EQU $F25B
MOD16.M16_DONE EQU $40C1
DRAW_VL_A EQU $F3DA
Draw_VLp_b EQU $F40E
DOT_D EQU $F2C3
INTENSITY_3F EQU $F2A1
Vec_Seed_Ptr EQU $C87B
ROT_VL_AB EQU $F610
Draw_VL_a EQU $F3DA
Select_Game EQU $F7A9
Xform_Rise EQU $F663
music1 EQU $FD0D
MOV_DRAW_VL_A EQU $F3B9
music5 EQU $FE38
VEC_JOY_MUX_2_Y EQU $C822
MOD16.M16_DPOS EQU $408B
VEC_PREV_BTNS EQU $C810
VEC_BUTTON_1_1 EQU $C812
Init_Music_Buf EQU $F533
Print_Str_hwyx EQU $F373
XFORM_RUN EQU $F65D
Dot_List_Reset EQU $F2DE
ADD_SCORE_A EQU $F85E
DRAW_VLCS EQU $F3D6
Vec_Cold_Flag EQU $CBFE
Draw_VL_b EQU $F3D2
PRINT_STR_YX EQU $F378
Dec_Counters EQU $F563
Vec_Expl_Chan EQU $C85C
VEC_MUSIC_WK_6 EQU $C846
VEC_NUM_GAME EQU $C87A
INIT_OS EQU $F18B
ASSET_ADDR_TABLE EQU $4004
Moveto_ix_FF EQU $F308
sfx_nextframe EQU $4463
Vec_Button_1_4 EQU $C815
Vec_Expl_4 EQU $C85B
RESET_PEN EQU $F35B
VEC_JOY_2_Y EQU $C81E
Mov_Draw_VL EQU $F3BC
VEC_IRQ_VECTOR EQU $CBF8
VEC_MUSIC_WK_7 EQU $C845
Draw_VL_ab EQU $F3D8
DELAY_0 EQU $F579
Print_Ships EQU $F393
Dot_ix_b EQU $F2BE
_MUSIC1_MUSIC EQU $0000
VEC_0REF_ENABLE EQU $C824
Reset0Ref EQU $F354
VEC_TEXT_HW EQU $C82A
AU_MUSIC_PROCESS_WRITES EQU $4399
RESET0REF_D0 EQU $F34A
MUSIC_ADDR_TABLE EQU $4001
musicc EQU $FF7A
VEC_RANDOM_SEED EQU $C87D
AU_MUSIC_LOOP EQU $43BE
MOV_DRAW_VL_D EQU $F3BE
Moveto_ix_a EQU $F30E
Intensity_7F EQU $F2A9
VEC_FREQ_TABLE EQU $C84D
VEC_BUTTONS EQU $C811
VEC_MUSIC_FREQ EQU $C861
VEC_FIRQ_VECTOR EQU $CBF5
MUSIC5 EQU $FE38
Moveto_d EQU $F312
ROT_VL_MODE_A EQU $F61F
Vec_ADSR_Timers EQU $C85E
Vec_Expl_3 EQU $C85A
MOVETO_IX EQU $F310
RISE_RUN_Y EQU $F601
PMR_START_NEW EQU $4277
Vec_Button_1_2 EQU $C813
Delay_2 EQU $F571
SFX_UPDATE EQU $43EA
Vec_Joy_Mux_2_Y EQU $C822
ROT_VL EQU $F616
DOT_LIST EQU $F2D5
VEC_DOT_DWELL EQU $C828
STRIP_ZEROS EQU $F8B7
BEEP_UPDATE_RUNTIME EQU $4486
musicd EQU $FF8F
PRINT_SHIPS EQU $F393
Vec_Button_2_4 EQU $C819
DRAW_PAT_VL_A EQU $F434
Clear_x_d EQU $F548
PLAY_SFX_RUNTIME EQU $43E1
DP_to_D0 EQU $F1AA
VEC_JOY_MUX_1_X EQU $C81F
Intensity_1F EQU $F29D
PRINT_TEXT_STR_60093699162 EQU $44BC
VEC_RISERUN_LEN EQU $C83B
music4 EQU $FDD3
COLD_START EQU $F000
NOAY EQU $43F4
Vec_Expl_2 EQU $C859
MOVETO_D EQU $F312
PSG_FRAME_DONE EQU $42F8
Vec_Rise_Index EQU $C839
VEC_BTN_STATE EQU $C80F
RESET0INT EQU $F36B
RESET0REF EQU $F354
DP_TO_D0 EQU $F1AA
VEC_EXPL_TIMER EQU $C877
DOT_HERE EQU $F2C5
Add_Score_d EQU $F87C
Cold_Start EQU $F000
Vec_Brightness EQU $C827
Read_Btns_Mask EQU $F1B4
PLAY_MUSIC_BANKED EQU $4006
Vec_Num_Players EQU $C879
AU_MUSIC_WRITE_LOOP EQU $439B
DELAY_B EQU $F57A
DEC_3_COUNTERS EQU $F55A
VEC_LOOP_COUNT EQU $C825
VEC_COUNTER_3 EQU $C830
OBJ_WILL_HIT_U EQU $F8E5
Print_List EQU $F38A
Move_Mem_a EQU $F683
Dot_ix EQU $F2C1
Print_Str EQU $F495
VEC_EXPL_CHANS EQU $C854
DRAW_VLP EQU $F410
Check0Ref EQU $F34F
VEC_COUNTER_5 EQU $C832
ASSET_BANK_TABLE EQU $4003
DO_SOUND EQU $F289
Init_Music EQU $F68D
MOV_DRAW_VL_B EQU $F3B1
Vec_Button_1_3 EQU $C814
Intensity_5F EQU $F2A5
MUSIC3 EQU $FD81
Vec_Run_Index EQU $C837
Vec_Music_Wk_5 EQU $C847
Rise_Run_Len EQU $F603
PSG_MUSIC_LOOP EQU $4304
MUSIC4 EQU $FDD3
Abs_a_b EQU $F584
SFX_M_NOISEDIS EQU $4459
CHECK0REF EQU $F34F
PRINT_TEXT_STR_60065591183 EQU $44B4
AUDIO_UPDATE EQU $4337
PRINT_STR_HWYX EQU $F373
Dot_d EQU $F2C3
SFX_M_TONEDIS EQU $444C
DRAW_GRID_VL EQU $FF9F
DRAW_VL_MODE EQU $F46E
SFX_NEXTFRAME EQU $4463
XFORM_RUN_A EQU $F65B
Rot_VL_ab EQU $F610
Xform_Run EQU $F65D
GET_RUN_IDX EQU $F5DB
PLAY_MUSIC_RUNTIME EQU $4269
PRINT_STR EQU $F495
Vec_Joy_1_Y EQU $C81C
Vec_Pattern EQU $C829
Vec_Button_2_1 EQU $C816
Draw_VLp_7F EQU $F408
VEC_PATTERN EQU $C829
Add_Score_a EQU $F85E
AU_UPDATE_SFX EQU $43CC
Vec_Buttons EQU $C811
Print_List_chk EQU $F38C
SFX_CHECKNOISEFREQ EQU $4422
BEEP_UPDATE_DONE EQU $44A4
PRINT_LIST_HW EQU $F385
RISE_RUN_ANGLE EQU $F593
Clear_x_b_80 EQU $F550
VEC_EXPL_4 EQU $C85B
INIT_MUSIC EQU $F68D
INTENSITY_7F EQU $F2A9
AU_DONE EQU $43D6
PRINT_LIST EQU $F38A
MOD16.M16_END EQU $40B2
Clear_Sound EQU $F272
Get_Rise_Idx EQU $F5D9
VEC_EXPL_3 EQU $C85A
Vec_Joy_Mux_2_X EQU $C821
VEC_SEED_PTR EQU $C87B
Reset0Ref_D0 EQU $F34A
PRINT_STR_D EQU $F37A
DRAW_PAT_VL_D EQU $F439
Vec_Music_Twang EQU $C858
Abs_b EQU $F58B
Vec_Button_1_1 EQU $C812
Print_Str_yx EQU $F378
noay EQU $43F4
DEC_COUNTERS EQU $F563
Sound_Bytes_x EQU $F284
Vec_Dot_Dwell EQU $C828
BITMASK_A EQU $F57E
VEC_MUSIC_TWANG EQU $C858
sfx_checknoisefreq EQU $4422
WAIT_RECAL EQU $F192
musicb EQU $FF62
sfx_updatemixer EQU $443C
DRAW_VL EQU $F3DD
Vec_ADSR_Table EQU $C84F
Delay_0 EQU $F579
Compare_Score EQU $F8C7
Vec_SWI_Vector EQU $CBFB
MOVETO_IX_FF EQU $F308
MUSICC EQU $FF7A
Vec_Music_Wk_A EQU $C842
MOD16 EQU $406E
JOY_DIGITAL EQU $F1F8
Draw_Grid_VL EQU $FF9F
MUSIC8 EQU $FEF8
Print_List_hw EQU $F385
AU_MUSIC_NO_DELAY EQU $4380
DRAW_VLP_FF EQU $F404
SELECT_GAME EQU $F7A9
VEC_RFRSH_HI EQU $C83E
DEC_6_COUNTERS EQU $F55E
MUSIC_BANK_TABLE EQU $4000
MOVETO_IX_7F EQU $F30C
NEW_HIGH_SCORE EQU $F8D8
Obj_Will_Hit_u EQU $F8E5
AU_MUSIC_DONE EQU $43B2
JOY_ANALOG EQU $F1F5
CLEAR_SCORE EQU $F84F
Vec_Joy_1_X EQU $C81B
CLEAR_X_256 EQU $F545
VEC_COUNTERS EQU $C82E
MOD16.M16_LOOP EQU $40A2
DO_SOUND_X EQU $F28C
VEC_EXPL_FLAG EQU $C867
Delay_b EQU $F57A
DELAY_2 EQU $F571
Delay_3 EQU $F56D
VEC_BUTTON_1_4 EQU $C815
Dot_List EQU $F2D5
Vec_Duration EQU $C857
VEC_COUNTER_6 EQU $C833
RECALIBRATE EQU $F2E6
Vec_Twang_Table EQU $C851
VEC_MUSIC_CHAN EQU $C855
MUSIC6 EQU $FE76
MUSIC9 EQU $FF26
Init_Music_chk EQU $F687
Warm_Start EQU $F06C
AU_MUSIC_HAS_DELAY EQU $438F
Draw_Pat_VL_a EQU $F434
Init_VIA EQU $F14C
Clear_C8_RAM EQU $F542
Vec_Str_Ptr EQU $C82C
Draw_Line_d EQU $F3DF
Vec_Music_Chan EQU $C855
XFORM_RISE EQU $F663
Random_3 EQU $F511
Clear_x_256 EQU $F545
Vec_Music_Flag EQU $C856
DCR_intensity_5F EQU $40F7
SFX_CHECKTONEFREQ EQU $4408
RISE_RUN_LEN EQU $F603
MOD16.M16_RPOS EQU $40A2
Xform_Rise_a EQU $F661
VEC_SND_SHADOW EQU $C800
Recalibrate EQU $F2E6
Vec_Music_Work EQU $C83F
Vec_IRQ_Vector EQU $CBF8
Rise_Run_Y EQU $F601
EXPLOSION_SND EQU $F92E
DOT_LIST_RESET EQU $F2DE
PRINT_SHIPS_X EQU $F391
VEC_RISERUN_TMP EQU $C834
CLEAR_X_B EQU $F53F
VEC_MUSIC_WK_A EQU $C842
Get_Run_Idx EQU $F5DB
VEC_MAX_PLAYERS EQU $C84F
Mov_Draw_VLcs EQU $F3B5
Vec_Max_Games EQU $C850
Vec_Expl_1 EQU $C858
PSG_frame_done EQU $42F8
PMr_start_new EQU $4277
music9 EQU $FF26
sfx_m_tonedis EQU $444C
Intensity_a EQU $F2AB
DP_TO_C8 EQU $F1AF
Rise_Run_X EQU $F5FF
VEC_JOY_MUX_2_X EQU $C821
Print_Str_d EQU $F37A
AU_SKIP_MUSIC EQU $43C9
VECTREX_PRINT_TEXT EQU $403E
VEC_EXPL_CHANB EQU $C85D
DRAW_VLP_7F EQU $F408
DRAW_VL_AB EQU $F3D8
Vec_Text_Width EQU $C82B
Vec_Music_Wk_7 EQU $C845
CLEAR_X_B_A EQU $F552
Intensity_3F EQU $F2A1
Read_Btns EQU $F1BA


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "STOPMUSIC"
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
DRAW_CIRCLE_XC       EQU $C880+$0E   ; Circle center X (1 bytes)
DRAW_CIRCLE_YC       EQU $C880+$0F   ; Circle center Y (1 bytes)
DRAW_CIRCLE_DIAM     EQU $C880+$10   ; Circle diameter (1 bytes)
DRAW_CIRCLE_INTENSITY EQU $C880+$11   ; Circle intensity (1 bytes)
DRAW_CIRCLE_RADIUS   EQU $C880+$12   ; Circle radius (diam/2) - used in segment drawing (1 bytes)
DRAW_CIRCLE_TEMP     EQU $C880+$13   ; Circle temporary buffer (8 bytes: radius16, a, b, c, d, --, --)  a=0.383r b=0.324r c=0.217r d=0.076r (8 bytes)
DRAW_RECT_X          EQU $C880+$1B   ; Rectangle X (1 bytes)
DRAW_RECT_Y          EQU $C880+$1C   ; Rectangle Y (1 bytes)
DRAW_RECT_WIDTH      EQU $C880+$1D   ; Rectangle width (1 bytes)
DRAW_RECT_HEIGHT     EQU $C880+$1E   ; Rectangle height (1 bytes)
DRAW_RECT_INTENSITY  EQU $C880+$1F   ; Rectangle intensity (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$20   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$2A   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$2C   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$2E   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$2F   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$30   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$32   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$34   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$35   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
BEEP_FRAMES_LEFT     EQU $C880+$36   ; Beep countdown timer (frames remaining) (1 bytes)
VAR_PLAYING          EQU $C880+$37   ; User variable: PLAYING (2 bytes)
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
    STD VAR_PLAYING
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
    LDD #0
    STD VAR_PLAYING

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    JSR BEEP_UPDATE_RUNTIME  ; Auto-injected: tick beep countdown timer
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD VAR_ARG0
    LDD #80
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2110696929079206      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-80
    STD VAR_ARG0
    LDD #50
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_60036864546      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-80
    STD VAR_ARG0
    LDD #30
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_60065591183      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-80
    STD VAR_ARG0
    LDD #10
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_60093699162      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
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
    ; PLAY_MUSIC("music1") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LDD #1
    STD VAR_PLAYING
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
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
    ; STOP_MUSIC: Stop music playback
    JSR STOP_MUSIC_RUNTIME
    LDD #0
    STD RESULT
    LDD #0
    STD VAR_PLAYING
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LDA >$C80F   ; Vec_Btns_1: bit2=1 means btn3 pressed
    BITA #$04
    LBNE .J1B3_2_ON
    LDD #0
    LBRA .J1B3_2_END
.J1B3_2_ON:
    LDD #1
.J1B3_2_END:
    STD RESULT
    LBEQ IF_NEXT_5
    ; ===== BEEP builtin (non-blocking) =====
    PSHS DP
    LDA #$D0
    TFR A,DP            ; DP=$D0 for Sound_Byte
    LDA #0              ; PSG reg 0 = freq low
    LDB #50             ; frequency period (50)
    JSR Sound_Byte
    LDA #1              ; PSG reg 1 = freq high
    LDB #0
    JSR Sound_Byte
    LDA #7              ; PSG reg 7 = mixer
    LDB #$3E            ; Enable tone A, disable noise
    JSR Sound_Byte
    LDA #8              ; PSG reg 8 = volume A
    LDB #15             ; Max volume
    JSR Sound_Byte
    PULS DP             ; Restore DP=$C8
    LDA #8             ; Beep duration: 8 frames
    STA >BEEP_FRAMES_LEFT
    LDD #0
    STD RESULT
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYING
    CMPD TMPVAL
    LBEQ .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_7
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$64
    JSR Intensity_a
    LDA #$E7
    LDB #$09
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$FF
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
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
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
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$01
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
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
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
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYING
    CMPD TMPVAL
    LBEQ .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    LBEQ IF_NEXT_9
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$28
    JSR Intensity_a
    LDA #$E2
    LDB #$00
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$10
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$10
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$F0
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$F0
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8
    LDD #0
    STD RESULT
    LBRA IF_END_8
IF_NEXT_9:
IF_END_8:
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX (after all game logic)
    RTS


; ================================================
