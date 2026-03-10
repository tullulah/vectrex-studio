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
VAR_SFX_TIMER        EQU $C880+$31   ; User variable: SFX_TIMER (2 bytes)
VAR_LAST_SFX         EQU $C880+$33   ; User variable: LAST_SFX (2 bytes)
VAR_RADIUS           EQU $C880+$35   ; User variable: RADIUS (2 bytes)
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
sfx_checktonefreq EQU $44F1
Draw_Pat_VL EQU $F437
Init_Music EQU $F68D
READ_BTNS EQU $F1BA
MUSICB EQU $FF62
AU_MUSIC_NO_DELAY EQU $4469
DRAW_VL_B EQU $F3D2
PRINT_SHIPS EQU $F393
Draw_VL_ab EQU $F3D8
Vec_0Ref_Enable EQU $C824
VEC_RANDOM_SEED EQU $C87D
Vec_Dot_Dwell EQU $C828
PLAY_MUSIC_BANKED EQU $401E
Mov_Draw_VLcs EQU $F3B5
RECALIBRATE EQU $F2E6
VEC_0REF_ENABLE EQU $C824
DP_TO_C8 EQU $F1AF
AU_BANK_OK EQU $443A
Draw_Grid_VL EQU $FF9F
DRAW_VL_A EQU $F3DA
EXPLOSION_SND EQU $F92E
ROT_VL_MODE_A EQU $F61F
Intensity_a EQU $F2AB
Vec_Text_Height EQU $C82A
SFX_UPDATEMIXER EQU $4525
CLEAR_X_B_A EQU $F552
VEC_RUN_INDEX EQU $C837
VEC_DEFAULT_STK EQU $CBEA
BITMASK_A EQU $F57E
Move_Mem_a_1 EQU $F67F
VEC_LOOP_COUNT EQU $C825
DOT_D EQU $F2C3
Print_List_hw EQU $F385
DOT_IX EQU $F2C1
Vec_Joy_Mux_1_X EQU $C81F
DRAW_VLP_B EQU $F40E
VEC_ADSR_TABLE EQU $C84F
DRAW_VLP EQU $F410
INIT_VIA EQU $F14C
Vec_Text_HW EQU $C82A
Delay_3 EQU $F56D
VEC_JOY_MUX EQU $C81F
_MUSIC1_MUSIC EQU $0000
OBJ_HIT EQU $F8FF
Dot_ix_b EQU $F2BE
Dec_6_Counters EQU $F55E
Vec_Button_2_2 EQU $C817
VEC_BTN_STATE EQU $C80F
ABS_A_B EQU $F584
VEC_BRIGHTNESS EQU $C827
musica EQU $FF44
Delay_0 EQU $F579
Draw_VL EQU $F3DD
DLW_SEG1_DX_READY EQU $42BF
Intensity_3F EQU $F2A1
PSG_frame_done EQU $43E1
Dot_d EQU $F2C3
VEC_JOY_MUX_1_Y EQU $C820
DLW_SEG1_DX_LO EQU $42AF
INIT_MUSIC_CHK EQU $F687
Joy_Analog EQU $F1F5
DRAW_LINE_D EQU $F3DF
AU_MUSIC_DONE EQU $449B
Sound_Byte_x EQU $F259
MOD16.M16_DPOS EQU $40CE
DELAY_1 EQU $F575
sfx_m_noisedis EQU $4542
VEC_BUTTON_2_4 EQU $C819
CLEAR_SCORE EQU $F84F
MOVETO_X_7F EQU $F2F2
Cold_Start EQU $F000
Vec_Button_2_4 EQU $C819
Delay_RTS EQU $F57D
Clear_x_d EQU $F548
READ_BTNS_MASK EQU $F1B4
Vec_Counter_1 EQU $C82E
PSG_music_loop EQU $43ED
Vec_Cold_Flag EQU $CBFE
VEC_EXPL_CHANS EQU $C854
Vec_Random_Seed EQU $C87D
MUSIC3 EQU $FD81
VEC_MAX_GAMES EQU $C850
PRINT_TEXT_STR_2775929313177532 EQU $45B1
DP_TO_D0 EQU $F1AA
Reset_Pen EQU $F35B
CLEAR_X_B EQU $F53F
INIT_MUSIC_X EQU $F692
VEC_ADSR_TIMERS EQU $C85E
Set_Refresh EQU $F1A2
Vec_Expl_ChanA EQU $C853
music9 EQU $FF26
Vec_Music_Wk_7 EQU $C845
Vec_Joy_2_X EQU $C81D
MUSICD EQU $FF8F
DRAW_VLP_7F EQU $F408
Warm_Start EQU $F06C
SELECT_GAME EQU $F7A9
VEC_RISERUN_LEN EQU $C83B
DLW_SEG2_DX_CHECK_NEG EQU $432D
Vec_Joy_Resltn EQU $C81A
Vec_Button_2_1 EQU $C816
Delay_b EQU $F57A
Xform_Rise EQU $F663
Vec_Counter_2 EQU $C82F
VEC_DURATION EQU $C857
Recalibrate EQU $F2E6
Random EQU $F517
DLW_SEG2_DY_POS EQU $4316
VEC_JOY_2_Y EQU $C81E
Draw_VLcs EQU $F3D6
INIT_OS EQU $F18B
SFX_M_TONEDIS EQU $4535
PSG_MUSIC_ENDED EQU $43E7
VEC_MUSIC_WORK EQU $C83F
Xform_Run EQU $F65D
VEC_MUSIC_TWANG EQU $C858
PSG_UPDATE_DONE EQU $43F5
Draw_VLp_7F EQU $F408
MUSIC8 EQU $FEF8
Vec_Joy_2_Y EQU $C81E
DP_to_C8 EQU $F1AF
PRINT_TEXT_STR_3273774 EQU $4574
music3 EQU $FD81
Abs_a_b EQU $F584
Vec_Num_Game EQU $C87A
GET_RISE_RUN EQU $F5EF
AU_MUSIC_WRITE_LOOP EQU $4484
Print_List EQU $F38A
CLEAR_SOUND EQU $F272
noay EQU $44DD
sfx_nextframe EQU $454C
VEC_JOY_RESLTN EQU $C81A
music8 EQU $FEF8
DLW_DONE EQU $434D
SOUND_BYTE_RAW EQU $F25B
Clear_x_b_a EQU $F552
DELAY_B EQU $F57A
Draw_VLp_b EQU $F40E
Vec_Brightness EQU $C827
Moveto_ix_7F EQU $F30C
SFX_M_NOISE EQU $4537
Sound_Bytes EQU $F27D
SET_REFRESH EQU $F1A2
VEC_RFRSH EQU $C83D
VEC_NMI_VECTOR EQU $CBFB
VEC_COUNTER_5 EQU $C832
music4 EQU $FDD3
SFX_ENDOFEFFECT EQU $4551
Vec_Music_Work EQU $C83F
Vec_Music_Ptr EQU $C853
VEC_EXPL_CHANB EQU $C85D
VEC_EXPL_3 EQU $C85A
Clear_x_b EQU $F53F
PMR_DONE EQU $4392
Get_Run_Idx EQU $F5DB
Rise_Run_X EQU $F5FF
VECTREX_PRINT_TEXT EQU $4081
New_High_Score EQU $F8D8
DLW_SEG2_DX_NO_REMAIN EQU $433B
Vec_SWI_Vector EQU $CBFB
VEC_FIRQ_VECTOR EQU $CBF5
Reset0Ref EQU $F354
PRINT_STR_HWYX EQU $F373
Vec_Snd_Shadow EQU $C800
VEC_EXPL_CHANA EQU $C853
Moveto_ix_FF EQU $F308
VEC_JOY_MUX_2_X EQU $C821
Vec_Max_Players EQU $C84F
DLW_SEG2_DX_DONE EQU $433E
Vec_Joy_Mux_2_Y EQU $C822
DRAW_PAT_VL_D EQU $F439
SFX_ADDR_TABLE EQU $4007
INIT_MUSIC EQU $F68D
Bitmask_a EQU $F57E
Draw_VLc EQU $F3CE
Clear_Sound EQU $F272
MOVE_MEM_A_1 EQU $F67F
Sound_Byte EQU $F256
Vec_Buttons EQU $C811
sfx_m_tonedis EQU $4535
GET_RUN_IDX EQU $F5DB
MUSIC9 EQU $FF26
MUSIC6 EQU $FE76
music5 EQU $FE38
VEC_MUSIC_WK_6 EQU $C846
VEC_SWI2_VECTOR EQU $CBF2
Moveto_ix EQU $F310
musicc EQU $FF7A
DRAW_CIRCLE_RUNTIME EQU $4105
NOAY EQU $44DD
VEC_PATTERN EQU $C829
VEC_BUTTON_1_4 EQU $C815
Draw_VL_b EQU $F3D2
Mov_Draw_VL_ab EQU $F3B7
CHECK0REF EQU $F34F
SFX_NEXTFRAME EQU $454C
Reset0Int EQU $F36B
MOV_DRAW_VL_B EQU $F3B1
MUSIC_BANK_TABLE EQU $4000
Vec_Text_Width EQU $C82B
sfx_m_noise EQU $4537
MOV_DRAW_VL_A EQU $F3B9
MOVETO_IX_A EQU $F30E
DCR_AFTER_INTENSITY EQU $413D
STOP_MUSIC_RUNTIME EQU $43F9
VEC_MUSIC_CHAN EQU $C855
Vec_Num_Players EQU $C879
CLEAR_X_256 EQU $F545
Vec_ADSR_Timers EQU $C85E
WAIT_RECAL EQU $F192
Print_List_chk EQU $F38C
VEC_EXPL_CHAN EQU $C85C
PSG_music_ended EQU $43E7
Vec_Misc_Count EQU $C823
SFX_DOFRAME EQU $44DE
RANDOM EQU $F517
Random_3 EQU $F511
VEC_TEXT_HW EQU $C82A
ADD_SCORE_A EQU $F85E
PRINT_STR_YX EQU $F378
PLAY_SFX_BANKED EQU $4056
Init_Music_chk EQU $F687
Vec_Counter_6 EQU $C833
AU_UPDATE_SFX EQU $44B5
sfx_checkvolume EQU $451C
Clear_Score EQU $F84F
Vec_Music_Wk_1 EQU $C84B
VEC_MUSIC_WK_7 EQU $C845
Abs_b EQU $F58B
PRINT_TEXT_STR_60065079928 EQU $4586
SFX_CHECKNOISEFREQ EQU $450B
VEC_NUM_PLAYERS EQU $C879
Vec_High_Score EQU $CBEB
ROT_VL_MODE EQU $F62B
VEC_COLD_FLAG EQU $CBFE
Vec_Twang_Table EQU $C851
Vec_Joy_1_Y EQU $C81C
RESET0REF EQU $F354
CLEAR_X_B_80 EQU $F550
VEC_DOT_DWELL EQU $C828
Draw_VLp EQU $F410
AU_MUSIC_READ EQU $4458
Add_Score_a EQU $F85E
Print_Str_yx EQU $F378
Explosion_Snd EQU $F92E
DLW_NEED_SEG2 EQU $42F7
Init_Music_x EQU $F692
Moveto_ix_a EQU $F30E
Moveto_d EQU $F312
MUSIC1 EQU $FD0D
VEC_TWANG_TABLE EQU $C851
VEC_RISE_INDEX EQU $C839
DRAW_VLP_SCALE EQU $F40C
VEC_FREQ_TABLE EQU $C84D
PSG_update_done EQU $43F5
STRIP_ZEROS EQU $F8B7
SOUND_BYTES_X EQU $F284
Vec_Button_1_2 EQU $C813
PRINT_LIST_CHK EQU $F38C
Print_Str_hwyx EQU $F373
PSG_WRITE_LOOP EQU $43B0
DRAW_PAT_VL_A EQU $F434
CLEAR_X_D EQU $F548
Vec_Angle EQU $C836
PSG_MUSIC_LOOP EQU $43ED
INTENSITY_A EQU $F2AB
Vec_FIRQ_Vector EQU $CBF5
VEC_SEED_PTR EQU $C87B
Vec_Joy_1_X EQU $C81B
ROT_VL_DFT EQU $F637
Obj_Hit EQU $F8FF
DP_to_D0 EQU $F1AA
MOVETO_IX_7F EQU $F30C
Obj_Will_Hit_u EQU $F8E5
Clear_C8_RAM EQU $F542
Get_Rise_Run EQU $F5EF
PSG_FRAME_DONE EQU $43E1
AU_MUSIC_HAS_DELAY EQU $4478
PRINT_LIST_HW EQU $F385
DLW_SEG2_DY_DONE EQU $4319
DRAW_GRID_VL EQU $FF9F
DOT_IX_B EQU $F2BE
VEC_STR_PTR EQU $C82C
Dot_List EQU $F2D5
Vec_Music_Freq EQU $C861
Read_Btns_Mask EQU $F1B4
JOY_DIGITAL EQU $F1F8
VEC_HIGH_SCORE EQU $CBEB
Rise_Run_Len EQU $F603
Print_Ships_x EQU $F391
DELAY_0 EQU $F579
Reset0Ref_D0 EQU $F34A
Obj_Will_Hit EQU $F8F3
DEC_COUNTERS EQU $F563
VEC_NUM_GAME EQU $C87A
VEC_COUNTER_4 EQU $C831
DOT_LIST EQU $F2D5
VEC_SWI_VECTOR EQU $CBFB
Vec_Counter_4 EQU $C831
DEC_3_COUNTERS EQU $F55A
DOT_LIST_RESET EQU $F2DE
Draw_VLp_FF EQU $F404
ADD_SCORE_D EQU $F87C
VEC_JOY_MUX_1_X EQU $C81F
Vec_Expl_Flag EQU $C867
VEC_SWI3_VECTOR EQU $CBF2
ABS_B EQU $F58B
Vec_Rise_Index EQU $C839
SOUND_BYTE_X EQU $F259
MOD16.M16_END EQU $40F5
Moveto_d_7F EQU $F2FC
SFX_CHECKVOLUME EQU $451C
Add_Score_d EQU $F87C
PRINT_TEXT_STR_1861138795901 EQU $459E
Vec_Rfrsh EQU $C83D
DRAW_LINE_WRAPPER EQU $424A
Print_Ships EQU $F393
WARM_START EQU $F06C
MOD16.M16_DONE EQU $4104
Read_Btns EQU $F1BA
PRINT_SHIPS_X EQU $F391
Vec_Rfrsh_hi EQU $C83E
Vec_Joy_Mux EQU $C81F
RESET0REF_D0 EQU $F34A
NEW_HIGH_SCORE EQU $F8D8
Rot_VL EQU $F616
VEC_SND_SHADOW EQU $C800
INTENSITY_1F EQU $F29D
Dec_3_Counters EQU $F55A
PRINT_STR EQU $F495
Rise_Run_Angle EQU $F593
VEC_PREV_BTNS EQU $C810
VEC_TEXT_WIDTH EQU $C82B
MOVETO_IX_FF EQU $F308
Vec_Music_Wk_5 EQU $C847
music6 EQU $FE76
INIT_MUSIC_BUF EQU $F533
Vec_Default_Stk EQU $CBEA
AU_MUSIC_READ_COUNT EQU $4469
Xform_Rise_a EQU $F661
VEC_RFRSH_HI EQU $C83E
VEC_EXPL_TIMER EQU $C877
Vec_Expl_1 EQU $C858
SOUND_BYTES EQU $F27D
DEC_6_COUNTERS EQU $F55E
DLW_SEG1_DY_LO EQU $428C
PRINT_TEXT_STR_3059345 EQU $456F
PRINT_TEXT_STR_60122367836 EQU $4596
VEC_MUSIC_FLAG EQU $C856
MOV_DRAW_VL EQU $F3BC
Sound_Bytes_x EQU $F284
INIT_OS_RAM EQU $F164
Rise_Run_Y EQU $F601
Check0Ref EQU $F34F
VEC_JOY_1_X EQU $C81B
Vec_Loop_Count EQU $C825
Intensity_5F EQU $F2A5
VEC_BUTTONS EQU $C811
RESET0INT EQU $F36B
sfx_endofeffect EQU $4551
RISE_RUN_ANGLE EQU $F593
VEC_MISC_COUNT EQU $C823
Intensity_1F EQU $F29D
RISE_RUN_Y EQU $F601
VEC_TEXT_HEIGHT EQU $C82A
Vec_SWI3_Vector EQU $CBF2
ASSET_ADDR_TABLE EQU $4014
Mov_Draw_VL EQU $F3BC
VEC_RFRSH_LO EQU $C83D
Intensity_7F EQU $F2A9
Vec_Music_Flag EQU $C856
sfx_m_write EQU $4544
Joy_Digital EQU $F1F8
MOD16.M16_RCHECK EQU $40D6
VEC_BUTTON_2_3 EQU $C818
Vec_Prev_Btns EQU $C810
VEC_MUSIC_WK_5 EQU $C847
Dot_List_Reset EQU $F2DE
Vec_Music_Wk_A EQU $C842
OBJ_WILL_HIT EQU $F8F3
XFORM_RUN_A EQU $F65B
Vec_Btn_State EQU $C80F
Dec_Counters EQU $F563
Mov_Draw_VL_a EQU $F3B9
sfx_updatemixer EQU $4525
VEC_BUTTON_1_1 EQU $C812
Sound_Byte_raw EQU $F25B
music1 EQU $FD0D
AU_MUSIC_LOOP EQU $44A7
Move_Mem_a EQU $F683
VEC_COUNTERS EQU $C82E
ROT_VL_AB EQU $F610
Clear_x_b_80 EQU $F550
Delay_1 EQU $F575
DELAY_RTS EQU $F57D
Clear_x_256 EQU $F545
MUSIC_ADDR_TABLE EQU $4001
VEC_EXPL_1 EQU $C858
Print_Str_d EQU $F37A
DRAW_VLC EQU $F3CE
Draw_VLp_scale EQU $F40C
Vec_Expl_4 EQU $C85B
Vec_Expl_Chans EQU $C854
sfx_checknoisefreq EQU $450B
Vec_Button_1_3 EQU $C814
VEC_COUNTER_1 EQU $C82E
PMr_done EQU $4392
Init_OS EQU $F18B
Moveto_x_7F EQU $F2F2
MOVETO_D_7F EQU $F2FC
DRAW_VL_AB EQU $F3D8
Get_Rise_Idx EQU $F5D9
Do_Sound_x EQU $F28C
DO_SOUND_X EQU $F28C
VEC_JOY_2_X EQU $C81D
Vec_Button_1_1 EQU $C812
Vec_Max_Games EQU $C850
Vec_Joy_Mux_1_Y EQU $C820
PRINT_LIST EQU $F38A
Draw_Pat_VL_d EQU $F439
COMPARE_SCORE EQU $F8C7
Vec_Str_Ptr EQU $C82C
GET_RISE_IDX EQU $F5D9
RISE_RUN_LEN EQU $F603
Vec_NMI_Vector EQU $CBFB
Vec_Counters EQU $C82E
MOVE_MEM_A EQU $F683
Draw_VL_mode EQU $F46E
Mov_Draw_VL_b EQU $F3B1
VEC_MAX_PLAYERS EQU $C84F
musicb EQU $FF62
VEC_MUSIC_PTR EQU $C853
DRAW_VLCS EQU $F3D6
Vec_Expl_Chan EQU $C85C
ASSET_BANK_TABLE EQU $400F
Vec_SWI2_Vector EQU $CBF2
Dot_here EQU $F2C5
SFX_CHECKTONEFREQ EQU $44F1
SOUND_BYTE EQU $F256
XFORM_RISE EQU $F663
AUDIO_UPDATE EQU $4420
Vec_Rfrsh_lo EQU $C83D
MUSICA EQU $FF44
MOD16 EQU $40B1
DRAW_VL_MODE EQU $F46E
MOV_DRAW_VL_AB EQU $F3B7
MOV_DRAW_VLCS EQU $F3B5
MOD16.M16_RPOS EQU $40E5
VEC_EXPL_FLAG EQU $C867
CLEAR_C8_RAM EQU $F542
VEC_COUNTER_3 EQU $C830
DRAW_PAT_VL EQU $F437
VEC_COUNTER_2 EQU $C82F
PRINT_TEXT_STR_68086998054879 EQU $45A7
Draw_Line_d EQU $F3DF
PLAY_MUSIC_RUNTIME EQU $4352
VEC_BUTTON_2_2 EQU $C817
MOD16.M16_LOOP EQU $40E5
Vec_Joy_Mux_2_X EQU $C821
RESET_PEN EQU $F35B
DELAY_3 EQU $F56D
AU_MUSIC_PROCESS_WRITES EQU $4482
DOT_HERE EQU $F2C5
DCR_after_intensity EQU $413D
Draw_VL_a EQU $F3DA
Init_VIA EQU $F14C
Xform_Run_a EQU $F65B
VEC_BUTTON_2_1 EQU $C816
AU_SKIP_MUSIC EQU $44B2
ROT_VL EQU $F616
MOV_DRAW_VLC_A EQU $F3AD
RANDOM_3 EQU $F511
Dot_ix EQU $F2C1
DRAW_VL EQU $F3DD
VEC_MUSIC_WK_A EQU $C842
Rot_VL_dft EQU $F637
PMR_START_NEW EQU $4360
Do_Sound EQU $F289
INTENSITY_7F EQU $F2A9
Vec_Counter_5 EQU $C832
DELAY_2 EQU $F571
DLW_SEG1_DY_NO_CLAMP EQU $4299
Vec_Duration EQU $C857
MOV_DRAW_VL_D EQU $F3BE
Vec_Pattern EQU $C829
Rot_VL_Mode EQU $F62B
VEC_BUTTON_1_2 EQU $C813
Draw_Pat_VL_a EQU $F434
Mov_Draw_VLc_a EQU $F3AD
musicd EQU $FF8F
Init_OS_RAM EQU $F164
Vec_Expl_3 EQU $C85A
Vec_RiseRun_Len EQU $C83B
Vec_Expl_Timer EQU $C877
DRAW_VLP_FF EQU $F404
VEC_COUNTER_6 EQU $C833
DLW_SEG1_DY_READY EQU $429C
VEC_JOY_1_Y EQU $C81C
Vec_Expl_ChanB EQU $C85D
sfx_doframe EQU $44DE
PLAY_SFX_RUNTIME EQU $44CA
Rot_VL_Mode_a EQU $F61F
Vec_ADSR_Table EQU $C84F
PSG_write_loop EQU $43B0
PRINT_STR_D EQU $F37A
PRINT_TEXT_STR_3232159404 EQU $457F
Vec_Seed_Ptr EQU $C87B
MUSIC5 EQU $FE38
VEC_BUTTON_1_3 EQU $C814
DCR_intensity_5F EQU $413A
MUSIC7 EQU $FEC6
SFX_UPDATE EQU $44D3
music7 EQU $FEC6
Vec_Music_Chan EQU $C855
MOVETO_IX EQU $F310
Strip_Zeros EQU $F8B7
SFX_M_WRITE EQU $4544
Vec_Music_Twang EQU $C858
XFORM_RISE_A EQU $F661
Delay_2 EQU $F571
RISE_RUN_X EQU $F5FF
SFX_BANK_TABLE EQU $4003
DLW_SEG2_DY_NO_REMAIN EQU $4310
VEC_ANGLE EQU $C836
DCR_INTENSITY_5F EQU $413A
MUSICC EQU $FF7A
VEC_EXPL_4 EQU $C85B
Vec_Freq_Table EQU $C84D
VEC_EXPL_2 EQU $C859
Vec_Music_Wk_6 EQU $C846
DO_SOUND EQU $F289
INTENSITY_5F EQU $F2A5
JOY_ANALOG EQU $F1F5
Wait_Recal EQU $F192
SFX_M_NOISEDIS EQU $4542
Rot_VL_ab EQU $F610
XFORM_RUN EQU $F65D
Vec_Run_Index EQU $C837
Vec_IRQ_Vector EQU $CBF8
DLW_SEG1_DX_NO_CLAMP EQU $42BC
PMr_start_new EQU $4360
AU_DONE EQU $44BF
Vec_Button_2_3 EQU $C818
COLD_START EQU $F000
Compare_Score EQU $F8C7
Vec_Button_1_4 EQU $C815
PRINT_TEXT_STR_102743755 EQU $4579
Init_Music_Buf EQU $F533
PRINT_TEXT_STR_60093953114 EQU $458E
MUSIC2 EQU $FD1D
Select_Game EQU $F7A9
VEC_MUSIC_FREQ EQU $C861
VEC_JOY_MUX_2_Y EQU $C822
Vec_RiseRun_Tmp EQU $C834
UPDATE_MUSIC_PSG EQU $4393
MUSIC4 EQU $FDD3
Vec_Expl_2 EQU $C859
OBJ_WILL_HIT_U EQU $F8E5
INTENSITY_3F EQU $F2A1
music2 EQU $FD1D
AU_MUSIC_ENDED EQU $44A1
Mov_Draw_VL_d EQU $F3BE
Print_Str EQU $F495
Vec_Counter_3 EQU $C830
VEC_MUSIC_WK_1 EQU $C84B
VEC_RISERUN_TMP EQU $C834
VEC_IRQ_VECTOR EQU $CBF8
MOVETO_D EQU $F312


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "MUSICSFX"
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
VAR_SFX_TIMER        EQU $C880+$31   ; User variable: SFX_TIMER (2 bytes)
VAR_LAST_SFX         EQU $C880+$33   ; User variable: LAST_SFX (2 bytes)
VAR_RADIUS           EQU $C880+$35   ; User variable: RADIUS (2 bytes)
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
    STD VAR_SFX_TIMER
    LDD #0
    STD VAR_LAST_SFX
    LDD #0
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
    ; PLAY_MUSIC("music1") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LDD #0
    STD VAR_SFX_TIMER
    LDD #0
    STD VAR_LAST_SFX

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
    LDX #PRINT_TEXT_STR_68086998054879      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD VAR_ARG0
    LDD #55
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_1861138795901      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD VAR_ARG0
    LDD #38
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_60065079928      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD VAR_ARG0
    LDD #21
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_60093953114      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD VAR_ARG0
    LDD #4
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_60122367836      ; Pointer to string in helpers bank
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
    ; PLAY_SFX("laser") - play SFX asset (index=3)
    LDX #3        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LDD #20
    STD VAR_SFX_TIMER
    LDD #1
    STD VAR_LAST_SFX
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
    ; PLAY_SFX("explosion1") - play SFX asset (index=1)
    LDX #1        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LDD #20
    STD VAR_SFX_TIMER
    LDD #2
    STD VAR_LAST_SFX
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
    ; PLAY_SFX("jump") - play SFX asset (index=2)
    LDX #2        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LDD #20
    STD VAR_SFX_TIMER
    LDD #3
    STD VAR_LAST_SFX
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    LDA >$C80F   ; Vec_Btns_1: bit3=1 means btn4 pressed
    BITA #$08
    LBNE .J1B4_3_ON
    LDD #0
    LBRA .J1B4_3_END
.J1B4_3_ON:
    LDD #1
.J1B4_3_END:
    STD RESULT
    LBEQ IF_NEXT_7
    ; PLAY_SFX("coin") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LDD #20
    STD VAR_SFX_TIMER
    LDD #4
    STD VAR_LAST_SFX
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SFX_TIMER
    CMPD TMPVAL
    LBGT .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_9
    LDD >VAR_SFX_TIMER
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_SFX_TIMER
    LBRA IF_END_8
IF_NEXT_9:
IF_END_8:
    LDD #20
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_SFX_TIMER
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_RADIUS
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SFX_TIMER
    CMPD TMPVAL
    LBGT .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    LBEQ IF_NEXT_11
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD #0
    TFR B,A
    STA DRAW_CIRCLE_XC
    LDD #-30
    TFR B,A
    STA DRAW_CIRCLE_YC
    LDD >VAR_RADIUS
    TFR B,A
    STA DRAW_CIRCLE_DIAM
    LDD #100
    TFR B,A
    STA DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_LAST_SFX
    CMPD TMPVAL
    LBEQ .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    LBEQ IF_NEXT_13
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #-10
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #-30
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #10
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #-30
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #100
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    LBRA IF_END_12
IF_NEXT_13:
IF_END_12:
    LDD #2
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_LAST_SFX
    CMPD TMPVAL
    LBEQ .CMP_3_TRUE
    LDD #0
    LBRA .CMP_3_END
.CMP_3_TRUE:
    LDD #1
.CMP_3_END:
    LBEQ IF_NEXT_15
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD #0
    TFR B,A
    STA DRAW_CIRCLE_XC
    LDD #-30
    TFR B,A
    STA DRAW_CIRCLE_YC
    LDD >VAR_RADIUS
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #8
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    TFR B,A
    STA DRAW_CIRCLE_DIAM
    LDD #80
    TFR B,A
    STA DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_14
IF_NEXT_15:
IF_END_14:
    LDD #3
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_LAST_SFX
    CMPD TMPVAL
    LBEQ .CMP_4_TRUE
    LDD #0
    LBRA .CMP_4_END
.CMP_4_TRUE:
    LDD #1
.CMP_4_END:
    LBEQ IF_NEXT_17
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #0
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #-20
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #0
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #-40
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #100
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    LBRA IF_END_16
IF_NEXT_17:
IF_END_16:
    LDD #4
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_LAST_SFX
    CMPD TMPVAL
    LBEQ .CMP_5_TRUE
    LDD #0
    LBRA .CMP_5_END
.CMP_5_TRUE:
    LDD #1
.CMP_5_END:
    LBEQ IF_NEXT_19
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$7F
    JSR Intensity_a
    LDA #$E2
    LDB #$02
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    LBRA IF_END_18
IF_NEXT_19:
IF_END_18:
    LBRA IF_END_10
IF_NEXT_11:
IF_END_10:
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX (after all game logic)
    RTS


; ================================================
