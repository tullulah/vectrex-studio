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
VAR_PLAYING          EQU $C880+$37   ; User variable: playing (2 bytes)
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
Vec_Music_Ptr EQU $C853
MUSICC EQU $FF7A
AU_UPDATE_SFX EQU $43CC
VEC_COUNTER_6 EQU $C833
Vec_Str_Ptr EQU $C82C
VEC_PATTERN EQU $C829
Move_Mem_a EQU $F683
GET_RISE_IDX EQU $F5D9
PSG_FRAME_DONE EQU $42F8
MUSIC8 EQU $FEF8
Vec_Text_Height EQU $C82A
INIT_MUSIC_BUF EQU $F533
Xform_Rise_a EQU $F661
VEC_SWI2_VECTOR EQU $CBF2
VEC_ANGLE EQU $C836
VEC_BUTTON_2_3 EQU $C818
DRAW_PAT_VL EQU $F437
Vec_SWI3_Vector EQU $CBF2
INTENSITY_5F EQU $F2A5
Draw_VLp EQU $F410
OBJ_HIT EQU $F8FF
Vec_Angle EQU $C836
Rise_Run_X EQU $F5FF
Intensity_1F EQU $F29D
DP_to_D0 EQU $F1AA
MOD16.M16_RPOS EQU $40A2
Delay_b EQU $F57A
MOV_DRAW_VL_A EQU $F3B9
Vec_Pattern EQU $C829
SFX_M_NOISEDIS EQU $4459
UPDATE_MUSIC_PSG EQU $42AA
STOP_MUSIC_RUNTIME EQU $4310
music7 EQU $FEC6
COLD_START EQU $F000
Vec_Counter_5 EQU $C832
Draw_VLp_scale EQU $F40C
Random_3 EQU $F511
RISE_RUN_X EQU $F5FF
VEC_COUNTER_1 EQU $C82E
DELAY_2 EQU $F571
GET_RUN_IDX EQU $F5DB
VEC_COUNTER_4 EQU $C831
CLEAR_SCORE EQU $F84F
VEC_MAX_PLAYERS EQU $C84F
Xform_Run EQU $F65D
DELAY_RTS EQU $F57D
Print_Str_d EQU $F37A
Vec_Joy_1_Y EQU $C81C
MUSICB EQU $FF62
Xform_Rise EQU $F663
MOVETO_IX_7F EQU $F30C
PMR_DONE EQU $42A9
Vec_Text_HW EQU $C82A
Sound_Byte EQU $F256
PSG_frame_done EQU $42F8
VEC_MUSIC_FREQ EQU $C861
VEC_STR_PTR EQU $C82C
CLEAR_X_B_A EQU $F552
VEC_RANDOM_SEED EQU $C87D
Compare_Score EQU $F8C7
XFORM_RISE_A EQU $F661
VEC_MISC_COUNT EQU $C823
Clear_x_b_a EQU $F552
Select_Game EQU $F7A9
DEC_COUNTERS EQU $F563
Obj_Will_Hit_u EQU $F8E5
Init_Music_Buf EQU $F533
VEC_SND_SHADOW EQU $C800
PRINT_TEXT_STR_3232159404 EQU $44A5
MOV_DRAW_VLCS EQU $F3B5
RANDOM_3 EQU $F511
Dec_Counters EQU $F563
VEC_JOY_2_Y EQU $C81E
Mov_Draw_VLc_a EQU $F3AD
sfx_nextframe EQU $4463
SOUND_BYTE_X EQU $F259
Vec_Num_Players EQU $C879
WAIT_RECAL EQU $F192
VEC_RISERUN_LEN EQU $C83B
DRAW_PAT_VL_A EQU $F434
RESET0INT EQU $F36B
Vec_Brightness EQU $C827
Check0Ref EQU $F34F
Vec_Button_2_4 EQU $C819
VEC_JOY_MUX_2_Y EQU $C822
VEC_MUSIC_TWANG EQU $C858
MUSIC6 EQU $FE76
INIT_MUSIC_CHK EQU $F687
Vec_Max_Games EQU $C850
PRINT_STR_D EQU $F37A
AU_MUSIC_DONE EQU $43B2
DCR_after_intensity EQU $40FA
BITMASK_A EQU $F57E
PMr_done EQU $42A9
VEC_MUSIC_WK_6 EQU $C846
MUSIC7 EQU $FEC6
DRAW_VL EQU $F3DD
VEC_TEXT_HW EQU $C82A
DP_TO_C8 EQU $F1AF
Vec_Joy_2_Y EQU $C81E
VEC_IRQ_VECTOR EQU $CBF8
DOT_LIST EQU $F2D5
PSG_UPDATE_DONE EQU $430C
DRAW_VL_A EQU $F3DA
Vec_0Ref_Enable EQU $C824
Vec_Rise_Index EQU $C839
Vec_Prev_Btns EQU $C810
INTENSITY_7F EQU $F2A9
VEC_DURATION EQU $C857
Vec_Max_Players EQU $C84F
Add_Score_a EQU $F85E
Clear_C8_RAM EQU $F542
Vec_Btn_State EQU $C80F
VEC_EXPL_1 EQU $C858
INIT_VIA EQU $F14C
Init_Music_x EQU $F692
Do_Sound_x EQU $F28C
Vec_Joy_Resltn EQU $C81A
Draw_Pat_VL EQU $F437
MOV_DRAW_VL_D EQU $F3BE
RISE_RUN_LEN EQU $F603
JOY_DIGITAL EQU $F1F8
Vec_Joy_Mux EQU $C81F
Vec_Music_Work EQU $C83F
Vec_Music_Wk_6 EQU $C846
NEW_HIGH_SCORE EQU $F8D8
Vec_RiseRun_Len EQU $C83B
Moveto_ix_7F EQU $F30C
INTENSITY_A EQU $F2AB
Vec_High_Score EQU $CBEB
DELAY_0 EQU $F579
VEC_JOY_MUX EQU $C81F
Rise_Run_Angle EQU $F593
music9 EQU $FF26
Move_Mem_a_1 EQU $F67F
MOV_DRAW_VL EQU $F3BC
Vec_Expl_2 EQU $C859
MOVETO_IX_FF EQU $F308
WARM_START EQU $F06C
Draw_VLp_7F EQU $F408
Init_OS EQU $F18B
Cold_Start EQU $F000
Delay_RTS EQU $F57D
PSG_MUSIC_ENDED EQU $42FE
Vec_Expl_1 EQU $C858
Vec_Joy_Mux_2_X EQU $C821
sfx_updatemixer EQU $443C
AU_MUSIC_READ_COUNT EQU $4380
MOV_DRAW_VL_B EQU $F3B1
Mov_Draw_VL_b EQU $F3B1
ABS_A_B EQU $F584
Dot_List_Reset EQU $F2DE
GET_RISE_RUN EQU $F5EF
Sound_Bytes_x EQU $F284
MUSIC2 EQU $FD1D
READ_BTNS_MASK EQU $F1B4
MOD16 EQU $406E
Draw_VL_b EQU $F3D2
Draw_VL EQU $F3DD
Vec_Random_Seed EQU $C87D
Vec_Expl_ChanB EQU $C85D
DOT_IX EQU $F2C1
Rot_VL EQU $F616
VEC_BUTTON_2_4 EQU $C819
music4 EQU $FDD3
Init_VIA EQU $F14C
MOVETO_D_7F EQU $F2FC
DRAW_CIRCLE_RUNTIME EQU $40C2
VEC_JOY_MUX_1_X EQU $C81F
CLEAR_SOUND EQU $F272
VEC_TEXT_WIDTH EQU $C82B
Print_List_hw EQU $F385
SFX_M_WRITE EQU $445B
Rise_Run_Y EQU $F601
Vec_Button_2_2 EQU $C817
XFORM_RUN EQU $F65D
VEC_DEFAULT_STK EQU $CBEA
VEC_EXPL_TIMER EQU $C877
Delay_3 EQU $F56D
PSG_write_loop EQU $42C7
sfx_doframe EQU $43F5
SFX_UPDATEMIXER EQU $443C
Vec_RiseRun_Tmp EQU $C834
ABS_B EQU $F58B
Vec_Music_Twang EQU $C858
DRAW_VL_B EQU $F3D2
Vec_Music_Freq EQU $C861
VEC_BUTTON_1_4 EQU $C815
Draw_Grid_VL EQU $FF9F
VEC_0REF_ENABLE EQU $C824
CLEAR_X_256 EQU $F545
Vec_Joy_Mux_1_X EQU $C81F
Read_Btns EQU $F1BA
DRAW_PAT_VL_D EQU $F439
VEC_BUTTONS EQU $C811
Vec_Buttons EQU $C811
Joy_Digital EQU $F1F8
PLAY_MUSIC_RUNTIME EQU $4269
DRAW_VL_AB EQU $F3D8
DRAW_VLCS EQU $F3D6
INTENSITY_3F EQU $F2A1
Vec_Run_Index EQU $C837
Reset0Ref_D0 EQU $F34A
Read_Btns_Mask EQU $F1B4
VEC_NUM_GAME EQU $C87A
DRAW_VLP_SCALE EQU $F40C
Vec_Button_1_1 EQU $C812
Vec_Counter_4 EQU $C831
Vec_Music_Flag EQU $C856
ASSET_BANK_TABLE EQU $4003
Dec_6_Counters EQU $F55E
Random EQU $F517
VEC_ADSR_TABLE EQU $C84F
CLEAR_X_B_80 EQU $F550
Vec_Joy_Mux_1_Y EQU $C820
Vec_NMI_Vector EQU $CBFB
SFX_CHECKTONEFREQ EQU $4408
VEC_SWI_VECTOR EQU $CBFB
PSG_MUSIC_LOOP EQU $4304
VEC_MUSIC_WK_1 EQU $C84B
DRAW_VLP_B EQU $F40E
PMR_START_NEW EQU $4277
AU_MUSIC_PROCESS_WRITES EQU $4399
RISE_RUN_Y EQU $F601
DOT_IX_B EQU $F2BE
Mov_Draw_VL_d EQU $F3BE
Moveto_x_7F EQU $F2F2
AU_DONE EQU $43D6
MOD16.M16_RCHECK EQU $4093
Vec_Rfrsh_hi EQU $C83E
INIT_OS EQU $F18B
Dot_ix_b EQU $F2BE
Reset0Int EQU $F36B
PLAY_MUSIC_BANKED EQU $4006
Vec_Seed_Ptr EQU $C87B
VEC_BTN_STATE EQU $C80F
Print_Str_hwyx EQU $F373
Vec_Duration EQU $C857
VEC_BUTTON_1_3 EQU $C814
VEC_NMI_VECTOR EQU $CBFB
New_High_Score EQU $F8D8
Rot_VL_dft EQU $F637
Vec_Counter_3 EQU $C830
music8 EQU $FEF8
VEC_LOOP_COUNT EQU $C825
Clear_x_b_80 EQU $F550
Clear_x_256 EQU $F545
Vec_SWI_Vector EQU $CBFB
Print_List_chk EQU $F38C
Intensity_7F EQU $F2A9
Clear_x_d EQU $F548
Reset_Pen EQU $F35B
STRIP_ZEROS EQU $F8B7
Add_Score_d EQU $F87C
MOD16.M16_END EQU $40B2
Draw_VLp_b EQU $F40E
VEC_HIGH_SCORE EQU $CBEB
RESET_PEN EQU $F35B
Strip_Zeros EQU $F8B7
VEC_EXPL_4 EQU $C85B
Vec_Twang_Table EQU $C851
MUSIC4 EQU $FDD3
MOD16.M16_LOOP EQU $40A2
OBJ_WILL_HIT EQU $F8F3
VEC_MUSIC_WK_7 EQU $C845
PRINT_SHIPS_X EQU $F391
INTENSITY_1F EQU $F29D
VEC_JOY_1_Y EQU $C81C
MOVE_MEM_A EQU $F683
PSG_music_ended EQU $42FE
sfx_m_tonedis EQU $444C
Recalibrate EQU $F2E6
MUSIC3 EQU $FD81
Vec_Button_1_4 EQU $C815
VEC_JOY_MUX_1_Y EQU $C820
DRAW_RECT_RUNTIME EQU $4207
DP_TO_D0 EQU $F1AA
AU_SKIP_MUSIC EQU $43C9
VEC_COUNTER_3 EQU $C830
Draw_VL_ab EQU $F3D8
Warm_Start EQU $F06C
VEC_RFRSH_HI EQU $C83E
music2 EQU $FD1D
Vec_Joy_2_X EQU $C81D
Init_OS_RAM EQU $F164
RECALIBRATE EQU $F2E6
Vec_Music_Wk_1 EQU $C84B
Moveto_d_7F EQU $F2FC
CLEAR_X_D EQU $F548
VEC_MUSIC_WORK EQU $C83F
INIT_MUSIC_X EQU $F692
Vec_Music_Wk_7 EQU $C845
ADD_SCORE_D EQU $F87C
DOT_HERE EQU $F2C5
musicc EQU $FF7A
EXPLOSION_SND EQU $F92E
music5 EQU $FE38
VEC_EXPL_FLAG EQU $C867
DRAW_LINE_D EQU $F3DF
VEC_NUM_PLAYERS EQU $C879
PRINT_LIST_HW EQU $F385
VEC_JOY_1_X EQU $C81B
VEC_MAX_GAMES EQU $C850
PRINT_TEXT_STR_2110696929079206 EQU $44C4
NOAY EQU $43F4
VEC_TWANG_TABLE EQU $C851
MUSIC1 EQU $FD0D
MOD16.M16_DONE EQU $40C1
Get_Rise_Run EQU $F5EF
OBJ_WILL_HIT_U EQU $F8E5
SFX_CHECKVOLUME EQU $4433
XFORM_RISE EQU $F663
AU_MUSIC_NO_DELAY EQU $4380
Print_List EQU $F38A
VEC_EXPL_2 EQU $C859
MUSICA EQU $FF44
VEC_MUSIC_WK_A EQU $C842
Vec_Expl_Timer EQU $C877
VEC_MUSIC_FLAG EQU $C856
VEC_COUNTER_2 EQU $C82F
RANDOM EQU $F517
PLAY_SFX_RUNTIME EQU $43E1
VEC_EXPL_CHANS EQU $C854
Moveto_ix_FF EQU $F308
Delay_2 EQU $F571
sfx_checkvolume EQU $4433
MOV_DRAW_VL_AB EQU $F3B7
sfx_m_noisedis EQU $4459
Vec_Counter_6 EQU $C833
Vec_Music_Chan EQU $C855
PSG_WRITE_LOOP EQU $42C7
SFX_M_TONEDIS EQU $444C
PRINT_TEXT_STR_60065591183 EQU $44B4
PRINT_SHIPS EQU $F393
Explosion_Snd EQU $F92E
Print_Ships EQU $F393
sfx_endofeffect EQU $4468
PRINT_LIST EQU $F38A
Vec_Music_Wk_A EQU $C842
Reset0Ref EQU $F354
Mov_Draw_VL EQU $F3BC
Vec_Snd_Shadow EQU $C800
music6 EQU $FE76
Do_Sound EQU $F289
VEC_COUNTER_5 EQU $C832
SET_REFRESH EQU $F1A2
musicd EQU $FF8F
DP_to_C8 EQU $F1AF
Vec_Button_2_3 EQU $C818
VEC_COUNTERS EQU $C82E
DO_SOUND EQU $F289
SFX_NEXTFRAME EQU $4463
VEC_SWI3_VECTOR EQU $CBF2
Vec_Expl_ChanA EQU $C853
READ_BTNS EQU $F1BA
DEC_6_COUNTERS EQU $F55E
Intensity_3F EQU $F2A1
ROT_VL EQU $F616
Print_Str_yx EQU $F378
PRINT_TEXT_STR_60093699162 EQU $44BC
Vec_Button_2_1 EQU $C816
VEC_BUTTON_1_2 EQU $C813
noay EQU $43F4
PMr_start_new EQU $4277
MOD16.M16_DPOS EQU $408B
Vec_Expl_Chan EQU $C85C
Xform_Run_a EQU $F65B
VECTREX_PRINT_TEXT EQU $403E
Vec_ADSR_Timers EQU $C85E
DELAY_B EQU $F57A
SOUND_BYTE_RAW EQU $F25B
Vec_FIRQ_Vector EQU $CBF5
Intensity_5F EQU $F2A5
Vec_Freq_Table EQU $C84D
Abs_b EQU $F58B
PSG_update_done EQU $430C
MOVETO_IX_A EQU $F30E
VEC_TEXT_HEIGHT EQU $C82A
SFX_CHECKNOISEFREQ EQU $4422
VEC_ADSR_TIMERS EQU $C85E
AU_MUSIC_HAS_DELAY EQU $438F
DO_SOUND_X EQU $F28C
INIT_MUSIC EQU $F68D
MUSIC9 EQU $FF26
Vec_Counter_2 EQU $C82F
Sound_Byte_raw EQU $F25B
MUSICD EQU $FF8F
RISE_RUN_ANGLE EQU $F593
Vec_Dot_Dwell EQU $C828
MUSIC_BANK_TABLE EQU $4000
VEC_EXPL_CHANA EQU $C853
ASSET_ADDR_TABLE EQU $4004
ROT_VL_DFT EQU $F637
Draw_Pat_VL_d EQU $F439
VEC_COLD_FLAG EQU $CBFE
Vec_Loop_Count EQU $C825
MOVETO_X_7F EQU $F2F2
Rot_VL_ab EQU $F610
SFX_ENDOFEFFECT EQU $4468
Clear_x_b EQU $F53F
SOUND_BYTES EQU $F27D
RESET0REF_D0 EQU $F34A
AU_MUSIC_READ EQU $436F
BEEP_UPDATE_RUNTIME EQU $4486
PRINT_TEXT_STR_60036864546 EQU $44AC
VEC_EXPL_3 EQU $C85A
Delay_0 EQU $F579
DOT_LIST_RESET EQU $F2DE
Dot_List EQU $F2D5
CLEAR_X_B EQU $F53F
SOUND_BYTES_X EQU $F284
Rot_VL_Mode_a EQU $F61F
DRAW_VLP_FF EQU $F404
Moveto_d EQU $F312
Obj_Will_Hit EQU $F8F3
Draw_VL_a EQU $F3DA
RESET0REF EQU $F354
MUSIC_ADDR_TABLE EQU $4001
MUSIC5 EQU $FE38
VEC_RISERUN_TMP EQU $C834
VEC_BUTTON_1_1 EQU $C812
Dot_ix EQU $F2C1
SFX_DOFRAME EQU $43F5
XFORM_RUN_A EQU $F65B
musicb EQU $FF62
ADD_SCORE_A EQU $F85E
VEC_PREV_BTNS EQU $C810
PSG_music_loop EQU $4304
music3 EQU $FD81
Draw_VLcs EQU $F3D6
DELAY_3 EQU $F56D
VEC_JOY_RESLTN EQU $C81A
Vec_Default_Stk EQU $CBEA
VEC_JOY_MUX_2_X EQU $C821
Obj_Hit EQU $F8FF
Vec_Expl_3 EQU $C85A
musica EQU $FF44
Dec_3_Counters EQU $F55A
VEC_SEED_PTR EQU $C87B
DCR_AFTER_INTENSITY EQU $40FA
sfx_m_write EQU $445B
Vec_Counter_1 EQU $C82E
Vec_Button_1_2 EQU $C813
VEC_BUTTON_2_2 EQU $C817
ROT_VL_MODE EQU $F62B
AU_MUSIC_ENDED EQU $43B8
VEC_BRIGHTNESS EQU $C827
DOT_D EQU $F2C3
Sound_Byte_x EQU $F259
Init_Music_chk EQU $F687
VEC_RISE_INDEX EQU $C839
VEC_FIRQ_VECTOR EQU $CBF5
SOUND_BYTE EQU $F256
SELECT_GAME EQU $F7A9
AUDIO_UPDATE EQU $4337
Draw_Line_d EQU $F3DF
Abs_a_b EQU $F584
PRINT_STR_YX EQU $F378
SFX_UPDATE EQU $43EA
PRINT_STR EQU $F495
Draw_VLc EQU $F3CE
Clear_Score EQU $F84F
Wait_Recal EQU $F192
CLEAR_C8_RAM EQU $F542
Print_Ships_x EQU $F391
AU_MUSIC_LOOP EQU $43BE
CHECK0REF EQU $F34F
DRAW_VL_MODE EQU $F46E
sfx_checknoisefreq EQU $4422
Vec_Rfrsh EQU $C83D
MOVETO_D EQU $F312
JOY_ANALOG EQU $F1F5
Vec_Expl_Chans EQU $C854
Vec_Button_1_3 EQU $C814
Vec_Counters EQU $C82E
VEC_RUN_INDEX EQU $C837
VEC_EXPL_CHAN EQU $C85C
Delay_1 EQU $F575
Rise_Run_Len EQU $F603
VEC_RFRSH EQU $C83D
SFX_M_NOISE EQU $444E
VEC_FREQ_TABLE EQU $C84D
BEEP_UPDATE_DONE EQU $44A4
Joy_Analog EQU $F1F5
Vec_Text_Width EQU $C82B
Vec_Misc_Count EQU $C823
Mov_Draw_VL_ab EQU $F3B7
Bitmask_a EQU $F57E
Get_Run_Idx EQU $F5DB
Vec_Expl_4 EQU $C85B
Mov_Draw_VLcs EQU $F3B5
PRINT_LIST_CHK EQU $F38C
Moveto_ix EQU $F310
Dot_here EQU $F2C5
Intensity_a EQU $F2AB
DEC_3_COUNTERS EQU $F55A
Vec_Joy_1_X EQU $C81B
VEC_JOY_2_X EQU $C81D
sfx_m_noise EQU $444E
Draw_VLp_FF EQU $F404
ROT_VL_MODE_A EQU $F61F
Vec_Expl_Flag EQU $C867
VEC_EXPL_CHANB EQU $C85D
Set_Refresh EQU $F1A2
DRAW_VLP EQU $F410
Vec_Num_Game EQU $C87A
COMPARE_SCORE EQU $F8C7
Vec_ADSR_Table EQU $C84F
Draw_Pat_VL_a EQU $F434
Dot_d EQU $F2C3
Moveto_ix_a EQU $F30E
AU_MUSIC_WRITE_LOOP EQU $439B
DRAW_GRID_VL EQU $FF9F
VEC_MUSIC_PTR EQU $C853
Init_Music EQU $F68D
Clear_Sound EQU $F272
MOVETO_IX EQU $F310
DCR_intensity_5F EQU $40F7
ROT_VL_AB EQU $F610
AU_BANK_OK EQU $4351
Vec_Music_Wk_5 EQU $C847
music1 EQU $FD0D
Sound_Bytes EQU $F27D
Vec_IRQ_Vector EQU $CBF8
Rot_VL_Mode EQU $F62B
Vec_SWI2_Vector EQU $CBF2
Vec_Rfrsh_lo EQU $C83D
Vec_Joy_Mux_2_Y EQU $C822
VEC_BUTTON_2_1 EQU $C816
Vec_Cold_Flag EQU $CBFE
PRINT_STR_HWYX EQU $F373
Mov_Draw_VL_a EQU $F3B9
Print_Str EQU $F495
INIT_OS_RAM EQU $F164
VEC_MUSIC_WK_5 EQU $C847
MOVE_MEM_A_1 EQU $F67F
DRAW_VLP_7F EQU $F408
DRAW_VLC EQU $F3CE
Get_Rise_Idx EQU $F5D9
VEC_MUSIC_CHAN EQU $C855
DELAY_1 EQU $F575
DCR_INTENSITY_5F EQU $40F7
VEC_DOT_DWELL EQU $C828
_MUSIC1_MUSIC EQU $0000
VEC_RFRSH_LO EQU $C83D
Draw_VL_mode EQU $F46E
sfx_checktonefreq EQU $4408
MOV_DRAW_VLC_A EQU $F3AD


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
VAR_PLAYING          EQU $C880+$37   ; User variable: playing (2 bytes)
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
