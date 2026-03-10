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
TEXT_SCALE_H         EQU $C880+$2F   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$30   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_MUSIC_PLAYING    EQU $C880+$31   ; User variable: music_playing (2 bytes)
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
DRAW_PAT_VL_A EQU $F434
XFORM_RISE EQU $F663
GET_RISE_RUN EQU $F5EF
Vec_RiseRun_Tmp EQU $C834
Dec_3_Counters EQU $F55A
Random EQU $F517
COMPARE_SCORE EQU $F8C7
VEC_COUNTERS EQU $C82E
VEC_COUNTER_4 EQU $C831
Vec_Expl_Chan EQU $C85C
Vec_Max_Games EQU $C850
Init_VIA EQU $F14C
VEC_BUTTON_1_1 EQU $C812
Vec_Joy_Resltn EQU $C81A
Clear_x_b EQU $F53F
MOVETO_D EQU $F312
Vec_Music_Wk_6 EQU $C846
Vec_Expl_Chans EQU $C854
Draw_VL_b EQU $F3D2
Vec_ADSR_Timers EQU $C85E
VEC_BUTTON_2_3 EQU $C818
DRAW_GRID_VL EQU $FF9F
RISE_RUN_ANGLE EQU $F593
Mov_Draw_VLcs EQU $F3B5
Dec_Counters EQU $F563
Vec_Music_Wk_5 EQU $C847
VEC_EXPL_CHANA EQU $C853
MOVE_MEM_A EQU $F683
DRAW_PAT_VL EQU $F437
PMr_start_new EQU $4215
MUSIC4 EQU $FDD3
noay EQU $4392
PSG_update_done EQU $42AA
VEC_JOY_MUX EQU $C81F
ROT_VL_MODE_A EQU $F61F
Vec_Button_1_1 EQU $C812
MOV_DRAW_VLC_A EQU $F3AD
MOVETO_IX_FF EQU $F308
INTENSITY_A EQU $F2AB
Explosion_Snd EQU $F92E
Draw_VLp EQU $F410
VEC_IRQ_VECTOR EQU $CBF8
Vec_Joy_2_Y EQU $C81E
Rise_Run_X EQU $F5FF
Draw_VLp_7F EQU $F408
Recalibrate EQU $F2E6
Vec_IRQ_Vector EQU $CBF8
RESET0REF EQU $F354
MOVE_MEM_A_1 EQU $F67F
Xform_Rise EQU $F663
VEC_LOOP_COUNT EQU $C825
Vec_Button_2_1 EQU $C816
PRINT_STR_YX EQU $F378
Reset_Pen EQU $F35B
VEC_JOY_2_X EQU $C81D
Vec_Num_Game EQU $C87A
INTENSITY_1F EQU $F29D
SOUND_BYTES_X EQU $F284
DOT_LIST_RESET EQU $F2DE
RESET0REF_D0 EQU $F34A
DRAW_CIRCLE_RUNTIME EQU $40C2
MUSICD EQU $FF8F
INIT_MUSIC_BUF EQU $F533
Vec_Pattern EQU $C829
ASSET_ADDR_TABLE EQU $4004
VEC_NUM_GAME EQU $C87A
VEC_EXPL_TIMER EQU $C877
Vec_Random_Seed EQU $C87D
Add_Score_d EQU $F87C
MOD16.M16_RPOS EQU $40A2
Print_List EQU $F38A
Mov_Draw_VL_b EQU $F3B1
Print_Str_hwyx EQU $F373
Vec_Default_Stk EQU $CBEA
PSG_FRAME_DONE EQU $4296
Vec_Rfrsh_lo EQU $C83D
Vec_Expl_Timer EQU $C877
Vec_Freq_Table EQU $C84D
ADD_SCORE_A EQU $F85E
Moveto_d_7F EQU $F2FC
CHECK0REF EQU $F34F
OBJ_WILL_HIT_U EQU $F8E5
Xform_Run EQU $F65D
Draw_VLp_FF EQU $F404
Print_Ships EQU $F393
Vec_Expl_3 EQU $C85A
SOUND_BYTES EQU $F27D
Dot_d EQU $F2C3
Clear_C8_RAM EQU $F542
VEC_RFRSH EQU $C83D
SFX_UPDATE EQU $4388
VEC_RFRSH_LO EQU $C83D
GET_RISE_IDX EQU $F5D9
WAIT_RECAL EQU $F192
MUSIC5 EQU $FE38
Rot_VL_Mode_a EQU $F61F
COLD_START EQU $F000
VEC_BRIGHTNESS EQU $C827
Joy_Digital EQU $F1F8
Print_Str_yx EQU $F378
VEC_JOY_1_Y EQU $C81C
DEC_COUNTERS EQU $F563
VEC_MAX_PLAYERS EQU $C84F
Vec_Counter_5 EQU $C832
SFX_CHECKVOLUME EQU $43D1
VEC_JOY_1_X EQU $C81B
Vec_Joy_Mux_1_X EQU $C81F
Vec_Prev_Btns EQU $C810
sfx_checktonefreq EQU $43A6
Vec_Button_1_4 EQU $C815
Vec_Joy_Mux EQU $C81F
Vec_Joy_1_X EQU $C81B
Draw_VL_mode EQU $F46E
WARM_START EQU $F06C
MOV_DRAW_VL_AB EQU $F3B7
MOV_DRAW_VL_B EQU $F3B1
SOUND_BYTE_X EQU $F259
AU_MUSIC_READ EQU $430D
Moveto_x_7F EQU $F2F2
Delay_b EQU $F57A
Vec_Joy_Mux_2_Y EQU $C822
Mov_Draw_VL_a EQU $F3B9
PLAY_MUSIC_RUNTIME EQU $4207
Sound_Byte_raw EQU $F25B
SFX_CHECKNOISEFREQ EQU $43C0
PSG_write_loop EQU $4265
Print_Ships_x EQU $F391
Init_Music_Buf EQU $F533
CLEAR_SOUND EQU $F272
MOVETO_X_7F EQU $F2F2
sfx_updatemixer EQU $43DA
Rot_VL_dft EQU $F637
PRINT_LIST_HW EQU $F385
Joy_Analog EQU $F1F5
MUSIC3 EQU $FD81
VEC_STR_PTR EQU $C82C
Vec_Expl_Flag EQU $C867
PSG_MUSIC_ENDED EQU $429C
VEC_SWI3_VECTOR EQU $CBF2
Reset0Ref_D0 EQU $F34A
Init_Music_chk EQU $F687
RISE_RUN_LEN EQU $F603
MOD16.M16_DONE EQU $40C1
Clear_x_d EQU $F548
Draw_VLp_scale EQU $F40C
Init_Music_x EQU $F692
AU_SKIP_MUSIC EQU $4367
SFX_M_TONEDIS EQU $43EA
Vec_Run_Index EQU $C837
Draw_Grid_VL EQU $FF9F
Draw_Pat_VL EQU $F437
Vec_Button_1_3 EQU $C814
Mov_Draw_VL_d EQU $F3BE
DRAW_VL_MODE EQU $F46E
Obj_Hit EQU $F8FF
DRAW_VL_B EQU $F3D2
Delay_RTS EQU $F57D
OBJ_HIT EQU $F8FF
music3 EQU $FD81
sfx_m_write EQU $43F9
Sound_Byte EQU $F256
Bitmask_a EQU $F57E
OBJ_WILL_HIT EQU $F8F3
MOVETO_IX_A EQU $F30E
DO_SOUND_X EQU $F28C
MOD16.M16_LOOP EQU $40A2
INIT_OS_RAM EQU $F164
VEC_NMI_VECTOR EQU $CBFB
Vec_Music_Twang EQU $C858
VEC_RFRSH_HI EQU $C83E
DELAY_2 EQU $F571
Delay_2 EQU $F571
Vec_Counter_2 EQU $C82F
PSG_UPDATE_DONE EQU $42AA
Vec_Loop_Count EQU $C825
Compare_Score EQU $F8C7
VEC_EXPL_CHANS EQU $C854
_MUSIC1_MUSIC EQU $0000
Draw_VLcs EQU $F3D6
DRAW_VLP_SCALE EQU $F40C
Set_Refresh EQU $F1A2
VEC_ADSR_TABLE EQU $C84F
MOD16.M16_DPOS EQU $408B
AU_MUSIC_LOOP EQU $435C
PRINT_LIST EQU $F38A
INIT_MUSIC_CHK EQU $F687
VEC_JOY_RESLTN EQU $C81A
EXPLOSION_SND EQU $F92E
PMR_START_NEW EQU $4215
SFX_M_WRITE EQU $43F9
VEC_RISERUN_TMP EQU $C834
JOY_DIGITAL EQU $F1F8
VEC_0REF_ENABLE EQU $C824
PRINT_TEXT_STR_73238862862 EQU $4431
Vec_Joy_Mux_2_X EQU $C821
VEC_EXPL_4 EQU $C85B
DRAW_PAT_VL_D EQU $F439
MUSICA EQU $FF44
Vec_ADSR_Table EQU $C84F
VEC_SND_SHADOW EQU $C800
Read_Btns EQU $F1BA
Mov_Draw_VL_ab EQU $F3B7
VEC_DEFAULT_STK EQU $CBEA
READ_BTNS EQU $F1BA
Delay_3 EQU $F56D
Cold_Start EQU $F000
Delay_0 EQU $F579
CLEAR_X_256 EQU $F545
Reset0Int EQU $F36B
DELAY_0 EQU $F579
Intensity_5F EQU $F2A5
Dot_here EQU $F2C5
VEC_MISC_COUNT EQU $C823
Draw_VL_a EQU $F3DA
Vec_Rise_Index EQU $C839
INTENSITY_3F EQU $F2A1
STRIP_ZEROS EQU $F8B7
VEC_MUSIC_TWANG EQU $C858
Draw_VLp_b EQU $F40E
Vec_Music_Flag EQU $C856
ABS_B EQU $F58B
CLEAR_X_D EQU $F548
Vec_FIRQ_Vector EQU $CBF5
DRAW_VLCS EQU $F3D6
MUSIC9 EQU $FF26
DP_to_D0 EQU $F1AA
Print_Str EQU $F495
ADD_SCORE_D EQU $F87C
Vec_Dot_Dwell EQU $C828
Vec_Music_Ptr EQU $C853
Vec_Button_2_3 EQU $C818
musicc EQU $FF7A
PLAY_SFX_RUNTIME EQU $437F
MOD16.M16_END EQU $40B2
RESET0INT EQU $F36B
VEC_TEXT_WIDTH EQU $C82B
CLEAR_X_B_A EQU $F552
Rise_Run_Len EQU $F603
musicd EQU $FF8F
Add_Score_a EQU $F85E
ASSET_BANK_TABLE EQU $4003
INIT_VIA EQU $F14C
sfx_checknoisefreq EQU $43C0
VEC_BTN_STATE EQU $C80F
VEC_MUSIC_WK_1 EQU $C84B
PRINT_STR EQU $F495
DRAW_VL EQU $F3DD
VEC_SEED_PTR EQU $C87B
AU_MUSIC_ENDED EQU $4356
VEC_EXPL_3 EQU $C85A
PRINT_SHIPS_X EQU $F391
VEC_ADSR_TIMERS EQU $C85E
INTENSITY_5F EQU $F2A5
VEC_MUSIC_WK_5 EQU $C847
sfx_doframe EQU $4393
Init_OS EQU $F18B
RANDOM_3 EQU $F511
SOUND_BYTE EQU $F256
sfx_m_tonedis EQU $43EA
VEC_BUTTON_1_3 EQU $C814
VEC_BUTTONS EQU $C811
ABS_A_B EQU $F584
VEC_SWI_VECTOR EQU $CBFB
SELECT_GAME EQU $F7A9
VEC_MUSIC_FLAG EQU $C856
MOV_DRAW_VLCS EQU $F3B5
DEC_3_COUNTERS EQU $F55A
Print_List_chk EQU $F38C
Rise_Run_Angle EQU $F593
Intensity_a EQU $F2AB
Moveto_ix EQU $F310
Rot_VL EQU $F616
INIT_OS EQU $F18B
INIT_MUSIC EQU $F68D
RISE_RUN_Y EQU $F601
Moveto_d EQU $F312
VEC_MAX_GAMES EQU $C850
PRINT_SHIPS EQU $F393
Vec_Btn_State EQU $C80F
PSG_WRITE_LOOP EQU $4265
DP_TO_D0 EQU $F1AA
INTENSITY_7F EQU $F2A9
SET_REFRESH EQU $F1A2
Check0Ref EQU $F34F
GET_RUN_IDX EQU $F5DB
VEC_SWI2_VECTOR EQU $CBF2
VEC_MUSIC_PTR EQU $C853
SFX_UPDATEMIXER EQU $43DA
DOT_IX_B EQU $F2BE
DEC_6_COUNTERS EQU $F55E
Mov_Draw_VLc_a EQU $F3AD
PMR_DONE EQU $4247
ROT_VL_DFT EQU $F637
PSG_music_loop EQU $42A2
Dot_List_Reset EQU $F2DE
Vec_Seed_Ptr EQU $C87B
Warm_Start EQU $F06C
music5 EQU $FE38
XFORM_RUN_A EQU $F65B
sfx_nextframe EQU $4401
Draw_VLc EQU $F3CE
VEC_NUM_PLAYERS EQU $C879
Vec_Joy_1_Y EQU $C81C
AU_MUSIC_READ_COUNT EQU $431E
music8 EQU $FEF8
SFX_CHECKTONEFREQ EQU $43A6
DP_TO_C8 EQU $F1AF
Vec_SWI2_Vector EQU $CBF2
Intensity_1F EQU $F29D
CLEAR_X_B_80 EQU $F550
MUSIC1 EQU $FD0D
Vec_Expl_ChanA EQU $C853
DO_SOUND EQU $F289
Vec_Joy_Mux_1_Y EQU $C820
Vec_Counter_4 EQU $C831
CLEAR_SCORE EQU $F84F
AU_MUSIC_WRITE_LOOP EQU $4339
Print_Str_d EQU $F37A
Vec_Rfrsh_hi EQU $C83E
VEC_JOY_2_Y EQU $C81E
Get_Run_Idx EQU $F5DB
RESET_PEN EQU $F35B
Vec_Buttons EQU $C811
MOD16 EQU $406E
DRAW_VLP_7F EQU $F408
AU_MUSIC_PROCESS_WRITES EQU $4337
sfx_endofeffect EQU $4406
DRAW_VLC EQU $F3CE
Moveto_ix_a EQU $F30E
RANDOM EQU $F517
Vec_Snd_Shadow EQU $C800
PMr_done EQU $4247
Move_Mem_a EQU $F683
VEC_DOT_DWELL EQU $C828
Delay_1 EQU $F575
NOAY EQU $4392
music4 EQU $FDD3
Vec_RiseRun_Len EQU $C83B
MUSICB EQU $FF62
Do_Sound EQU $F289
Vec_Text_Width EQU $C82B
sfx_m_noisedis EQU $43F7
Dot_List EQU $F2D5
VEC_EXPL_2 EQU $C859
MOVETO_D_7F EQU $F2FC
CLEAR_X_B EQU $F53F
Vec_High_Score EQU $CBEB
Vec_Button_2_4 EQU $C819
DRAW_VLP EQU $F410
PLAY_MUSIC_BANKED EQU $4006
Vec_0Ref_Enable EQU $C824
Mov_Draw_VL EQU $F3BC
CLEAR_C8_RAM EQU $F542
Vec_SWI_Vector EQU $CBFB
MOVETO_IX EQU $F310
Vec_Twang_Table EQU $C851
Clear_Sound EQU $F272
READ_BTNS_MASK EQU $F1B4
VEC_BUTTON_1_2 EQU $C813
DRAW_LINE_D EQU $F3DF
Rot_VL_ab EQU $F610
VEC_RISE_INDEX EQU $C839
Clear_x_b_80 EQU $F550
Vec_Counter_3 EQU $C830
SFX_NEXTFRAME EQU $4401
Select_Game EQU $F7A9
MUSIC8 EQU $FEF8
DRAW_VL_A EQU $F3DA
VEC_FREQ_TABLE EQU $C84D
VEC_COUNTER_3 EQU $C830
Vec_SWI3_Vector EQU $CBF2
VEC_BUTTON_1_4 EQU $C815
Vec_Expl_ChanB EQU $C85D
VEC_COLD_FLAG EQU $CBFE
music6 EQU $FE76
VEC_DURATION EQU $C857
DOT_HERE EQU $F2C5
BITMASK_A EQU $F57E
AU_BANK_OK EQU $42EF
VEC_COUNTER_5 EQU $C832
Intensity_7F EQU $F2A9
SFX_DOFRAME EQU $4393
MOD16.M16_RCHECK EQU $4093
PRINT_TEXT_STR_73725445 EQU $4424
PRINT_STR_D EQU $F37A
Move_Mem_a_1 EQU $F67F
Rise_Run_Y EQU $F601
VEC_BUTTON_2_2 EQU $C817
DCR_intensity_5F EQU $40F7
MUSIC2 EQU $FD1D
DRAW_VLP_B EQU $F40E
Vec_Expl_1 EQU $C858
SFX_M_NOISE EQU $43EC
New_High_Score EQU $F8D8
Vec_NMI_Vector EQU $CBFB
PSG_MUSIC_LOOP EQU $42A2
AU_MUSIC_HAS_DELAY EQU $432D
DRAW_VLP_FF EQU $F404
INIT_MUSIC_X EQU $F692
Read_Btns_Mask EQU $F1B4
Dot_ix_b EQU $F2BE
Random_3 EQU $F511
Draw_VL EQU $F3DD
Vec_Angle EQU $C836
Vec_Counter_1 EQU $C82E
NEW_HIGH_SCORE EQU $F8D8
VEC_RISERUN_LEN EQU $C83B
VEC_EXPL_CHANB EQU $C85D
Wait_Recal EQU $F192
Vec_Max_Players EQU $C84F
DOT_IX EQU $F2C1
AU_MUSIC_NO_DELAY EQU $431E
SFX_M_NOISEDIS EQU $43F7
VEC_TEXT_HEIGHT EQU $C82A
music7 EQU $FEC6
ROT_VL EQU $F616
PSG_music_ended EQU $429C
Vec_Expl_2 EQU $C859
Vec_Str_Ptr EQU $C82C
VEC_JOY_MUX_1_Y EQU $C820
Draw_VL_ab EQU $F3D8
Init_OS_RAM EQU $F164
Draw_Line_d EQU $F3DF
VEC_MUSIC_WORK EQU $C83F
Obj_Will_Hit EQU $F8F3
Vec_Duration EQU $C857
VEC_MUSIC_WK_7 EQU $C845
Draw_Pat_VL_a EQU $F434
Get_Rise_Idx EQU $F5D9
DELAY_3 EQU $F56D
UPDATE_MUSIC_PSG EQU $4248
Vec_Music_Work EQU $C83F
XFORM_RISE_A EQU $F661
VEC_TWANG_TABLE EQU $C851
Vec_Music_Freq EQU $C861
VEC_MUSIC_WK_A EQU $C842
Dot_ix EQU $F2C1
VEC_MUSIC_CHAN EQU $C855
Vec_Cold_Flag EQU $CBFE
Vec_Button_2_2 EQU $C817
Abs_b EQU $F58B
Xform_Rise_a EQU $F661
DCR_AFTER_INTENSITY EQU $40FA
Intensity_3F EQU $F2A1
DOT_D EQU $F2C3
VEC_COUNTER_6 EQU $C833
DRAW_VL_AB EQU $F3D8
Vec_Rfrsh EQU $C83D
Obj_Will_Hit_u EQU $F8E5
SFX_ENDOFEFFECT EQU $4406
MUSIC6 EQU $FE76
musicb EQU $FF62
VEC_PREV_BTNS EQU $C810
Strip_Zeros EQU $F8B7
MUSICC EQU $FF7A
Sound_Bytes EQU $F27D
STOP_MUSIC_RUNTIME EQU $42AE
Get_Rise_Run EQU $F5EF
music2 EQU $FD1D
Dec_6_Counters EQU $F55E
Vec_Brightness EQU $C827
MUSIC_BANK_TABLE EQU $4000
Reset0Ref EQU $F354
Vec_Button_1_2 EQU $C813
Init_Music EQU $F68D
DP_to_C8 EQU $F1AF
VEC_BUTTON_2_1 EQU $C816
Xform_Run_a EQU $F65B
sfx_checkvolume EQU $43D1
DCR_INTENSITY_5F EQU $40F7
Clear_x_b_a EQU $F552
MUSIC7 EQU $FEC6
Vec_Num_Players EQU $C879
Vec_Music_Chan EQU $C855
Vec_Text_HW EQU $C82A
AUDIO_UPDATE EQU $42D5
AU_DONE EQU $4374
music1 EQU $FD0D
Vec_Misc_Count EQU $C823
VEC_COUNTER_1 EQU $C82E
Clear_x_256 EQU $F545
VEC_TEXT_HW EQU $C82A
PRINT_STR_HWYX EQU $F373
sfx_m_noise EQU $43EC
VEC_FIRQ_VECTOR EQU $CBF5
Vec_Counters EQU $C82E
DOT_LIST EQU $F2D5
AU_UPDATE_SFX EQU $436A
Vec_Music_Wk_A EQU $C842
VEC_MUSIC_FREQ EQU $C861
JOY_ANALOG EQU $F1F5
VEC_PATTERN EQU $C829
DELAY_B EQU $F57A
XFORM_RUN EQU $F65D
PRINT_LIST_CHK EQU $F38C
Sound_Bytes_x EQU $F284
ROT_VL_AB EQU $F610
RECALIBRATE EQU $F2E6
DCR_after_intensity EQU $40FA
MOV_DRAW_VL_D EQU $F3BE
DELAY_RTS EQU $F57D
MOV_DRAW_VL EQU $F3BC
music9 EQU $FF26
Clear_Score EQU $F84F
VEC_EXPL_FLAG EQU $C867
VEC_BUTTON_2_4 EQU $C819
VECTREX_PRINT_TEXT EQU $403E
DELAY_1 EQU $F575
Sound_Byte_x EQU $F259
VEC_JOY_MUX_2_X EQU $C821
Rot_VL_Mode EQU $F62B
SOUND_BYTE_RAW EQU $F25B
VEC_RUN_INDEX EQU $C837
MOVETO_IX_7F EQU $F30C
Vec_Music_Wk_7 EQU $C845
Vec_Joy_2_X EQU $C81D
PRINT_TEXT_STR_3232159404 EQU $442A
VEC_HIGH_SCORE EQU $CBEB
Vec_Music_Wk_1 EQU $C84B
PSG_frame_done EQU $4296
Moveto_ix_7F EQU $F30C
Vec_Counter_6 EQU $C833
Abs_a_b EQU $F584
ROT_VL_MODE EQU $F62B
VEC_EXPL_1 EQU $C858
MUSIC_ADDR_TABLE EQU $4001
Vec_Expl_4 EQU $C85B
VEC_COUNTER_2 EQU $C82F
Do_Sound_x EQU $F28C
VEC_MUSIC_WK_6 EQU $C846
RISE_RUN_X EQU $F5FF
VEC_ANGLE EQU $C836
musica EQU $FF44
VEC_JOY_MUX_2_Y EQU $C822
AU_MUSIC_DONE EQU $4350
VEC_JOY_MUX_1_X EQU $C81F
Vec_Text_Height EQU $C82A
Draw_Pat_VL_d EQU $F439
VEC_EXPL_CHAN EQU $C85C
VEC_RANDOM_SEED EQU $C87D
Moveto_ix_FF EQU $F308
MOV_DRAW_VL_A EQU $F3B9
Print_List_hw EQU $F385


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "PLAY_MUSIC"
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
DRAW_LINE_ARGS       EQU $C880+$1B   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$25   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$27   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$29   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$2A   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$2B   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$2D   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$2F   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$30   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_MUSIC_PLAYING    EQU $C880+$31   ; User variable: music_playing (2 bytes)
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
    STD VAR_MUSIC_PLAYING
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
    LDD #1
    STD VAR_MUSIC_PLAYING
    ; PLAY_MUSIC("music1") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD VAR_ARG0
    LDD #80
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_73725445      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #0
    STD VAR_ARG0
    LDD #80
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_73238862862      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MUSIC_PLAYING
    CMPD TMPVAL
    LBEQ .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_1
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$50
    JSR Intensity_a
    LDA #$00
    LDB #$0A
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
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX (after all game logic)
    RTS


; ================================================
