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
INIT_MUSIC EQU $F68D
INIT_OS_RAM EQU $F164
PSG_music_loop EQU $429E
Draw_VLp_FF EQU $F404
Rise_Run_Y EQU $F601
Draw_VL_mode EQU $F46E
sfx_m_write EQU $43FE
Vec_ADSR_Table EQU $C84F
STOP_MUSIC_RUNTIME EQU $42AA
MOV_DRAW_VL EQU $F3BC
VEC_MUSIC_WK_5 EQU $C847
Moveto_x_7F EQU $F2F2
PSG_MUSIC_LOOP EQU $429E
DOT_IX EQU $F2C1
SET_REFRESH EQU $F1A2
Reset_Pen EQU $F35B
AU_MUSIC_NO_DELAY EQU $431A
DO_SOUND_X EQU $F28C
MUSIC5 EQU $FE38
Vec_Music_Wk_6 EQU $C846
Vec_Music_Work EQU $C83F
Vec_Max_Players EQU $C84F
SFX_DOFRAME EQU $4398
VEC_EXPL_CHANB EQU $C85D
Mov_Draw_VL_a EQU $F3B9
Vec_ADSR_Timers EQU $C85E
VEC_ADSR_TABLE EQU $C84F
SFX_M_NOISEDIS EQU $43FC
DEC_6_COUNTERS EQU $F55E
PRINT_STR_D EQU $F37A
Print_List_chk EQU $F38C
MUSIC6 EQU $FE76
Xform_Run EQU $F65D
OBJ_HIT EQU $F8FF
sfx_m_noisedis EQU $43FC
Vec_Button_1_1 EQU $C812
Xform_Rise_a EQU $F661
Strip_Zeros EQU $F8B7
sfx_updatemixer EQU $43DF
sfx_checkvolume EQU $43D6
Mov_Draw_VL_ab EQU $F3B7
AU_MUSIC_READ_COUNT EQU $431A
Vec_NMI_Vector EQU $CBFB
VEC_BUTTON_2_3 EQU $C818
SFX_UPDATE EQU $438D
PRINT_TEXT_STR_58672554795414 EQU $4437
Vec_Joy_2_Y EQU $C81E
Clear_x_256 EQU $F545
VEC_MUSIC_WORK EQU $C83F
Vec_Music_Flag EQU $C856
Vec_Expl_Chans EQU $C854
ROT_VL_DFT EQU $F637
PRINT_TEXT_STR_89546106876693 EQU $444B
ABS_B EQU $F58B
Delay_RTS EQU $F57D
Vec_Joy_Mux EQU $C81F
Vec_Max_Games EQU $C850
SOUND_BYTES_X EQU $F284
VEC_0REF_ENABLE EQU $C824
Print_Str_d EQU $F37A
GET_RISE_RUN EQU $F5EF
Print_Ships EQU $F393
VEC_MISC_COUNT EQU $C823
VEC_MUSIC_WK_7 EQU $C845
VEC_BTN_STATE EQU $C80F
AU_MUSIC_PROCESS_WRITES EQU $4333
SFX_ADDR_TABLE EQU $4002
PLAY_MUSIC_RUNTIME EQU $4203
DCR_after_intensity EQU $40F6
Draw_Grid_VL EQU $FF9F
Init_Music EQU $F68D
DRAW_CIRCLE_RUNTIME EQU $40BE
VEC_BUTTONS EQU $C811
Vec_Expl_4 EQU $C85B
music1 EQU $FD0D
JOY_ANALOG EQU $F1F5
EXPLOSION_SND EQU $F92E
DRAW_VLP_SCALE EQU $F40C
VEC_IRQ_VECTOR EQU $CBF8
Vec_Joy_Mux_1_X EQU $C81F
VEC_JOY_1_X EQU $C81B
PRINT_TEXT_STR_2348223718253 EQU $442E
UPDATE_MUSIC_PSG EQU $4244
CLEAR_X_B EQU $F53F
VEC_COLD_FLAG EQU $CBFE
COMPARE_SCORE EQU $F8C7
DRAW_VLP_FF EQU $F404
RESET_PEN EQU $F35B
Vec_Expl_ChanB EQU $C85D
VEC_DEFAULT_STK EQU $CBEA
Vec_Expl_ChanA EQU $C853
SFX_M_WRITE EQU $43FE
Print_Str_hwyx EQU $F373
Vec_Loop_Count EQU $C825
PSG_write_loop EQU $4261
VEC_EXPL_TIMER EQU $C877
Draw_VLp_7F EQU $F408
Vec_Counter_2 EQU $C82F
Vec_Music_Wk_7 EQU $C845
VEC_NUM_GAME EQU $C87A
VEC_BRIGHTNESS EQU $C827
Sound_Byte EQU $F256
AU_MUSIC_HAS_DELAY EQU $4329
MOV_DRAW_VL_A EQU $F3B9
XFORM_RISE_A EQU $F661
DRAW_PAT_VL_A EQU $F434
DRAW_GRID_VL EQU $FF9F
ROT_VL_MODE_A EQU $F61F
Add_Score_a EQU $F85E
VEC_BUTTON_1_3 EQU $C814
music5 EQU $FE38
DOT_D EQU $F2C3
GET_RISE_IDX EQU $F5D9
MUSIC9 EQU $FF26
AU_UPDATE_SFX EQU $4366
Dot_d EQU $F2C3
Clear_x_b_a EQU $F552
Intensity_3F EQU $F2A1
VEC_JOY_1_Y EQU $C81C
Vec_Seed_Ptr EQU $C87B
MOVETO_IX_FF EQU $F308
Draw_VLp EQU $F410
VEC_EXPL_1 EQU $C858
NEW_HIGH_SCORE EQU $F8D8
Init_Music_x EQU $F692
PMr_done EQU $4243
Dot_ix_b EQU $F2BE
DP_to_C8 EQU $F1AF
VEC_EXPL_CHANA EQU $C853
Joy_Digital EQU $F1F8
OBJ_WILL_HIT_U EQU $F8E5
ABS_A_B EQU $F584
VEC_COUNTER_5 EQU $C832
VEC_MUSIC_TWANG EQU $C858
PSG_FRAME_DONE EQU $4292
Xform_Run_a EQU $F65B
Draw_VL_b EQU $F3D2
Move_Mem_a EQU $F683
Read_Btns EQU $F1BA
Vec_Random_Seed EQU $C87D
Vec_Expl_Timer EQU $C877
DRAW_VLP_B EQU $F40E
Vec_Counter_4 EQU $C831
MOV_DRAW_VL_AB EQU $F3B7
MOVETO_IX_7F EQU $F30C
musicc EQU $FF7A
Obj_Will_Hit_u EQU $F8E5
Set_Refresh EQU $F1A2
PMR_START_NEW EQU $4211
ROT_VL_AB EQU $F610
RISE_RUN_X EQU $F5FF
Rot_VL EQU $F616
Rise_Run_Len EQU $F603
PRINT_LIST_HW EQU $F385
OBJ_WILL_HIT EQU $F8F3
VEC_ADSR_TIMERS EQU $C85E
MUSIC2 EQU $FD1D
VEC_FIRQ_VECTOR EQU $CBF5
VEC_MUSIC_PTR EQU $C853
Clear_x_b EQU $F53F
VEC_MUSIC_WK_1 EQU $C84B
SFX_CHECKTONEFREQ EQU $43AB
sfx_nextframe EQU $4406
Vec_Str_Ptr EQU $C82C
Sound_Bytes EQU $F27D
Vec_Pattern EQU $C829
DCR_INTENSITY_5F EQU $40F3
PRINT_STR EQU $F495
SFX_CHECKNOISEFREQ EQU $43C5
Vec_Rfrsh_lo EQU $C83D
Clear_x_b_80 EQU $F550
VEC_COUNTER_1 EQU $C82E
ADD_SCORE_A EQU $F85E
STRIP_ZEROS EQU $F8B7
Intensity_a EQU $F2AB
VEC_MAX_PLAYERS EQU $C84F
Vec_Expl_2 EQU $C859
Vec_Duration EQU $C857
PRINT_LIST_CHK EQU $F38C
SFX_BANK_TABLE EQU $4000
BITMASK_A EQU $F57E
CLEAR_C8_RAM EQU $F542
VEC_TWANG_TABLE EQU $C851
MOV_DRAW_VLC_A EQU $F3AD
Get_Run_Idx EQU $F5DB
PLAY_SFX_BANKED EQU $400C
RESET0REF_D0 EQU $F34A
ROT_VL_MODE EQU $F62B
PSG_MUSIC_ENDED EQU $4298
Delay_b EQU $F57A
Vec_Misc_Count EQU $C823
Dot_List EQU $F2D5
Vec_Expl_Flag EQU $C867
Rot_VL_Mode_a EQU $F61F
Reset0Ref EQU $F354
READ_BTNS EQU $F1BA
MOVETO_IX EQU $F310
VEC_BUTTON_1_2 EQU $C813
INIT_MUSIC_X EQU $F692
sfx_checknoisefreq EQU $43C5
Vec_Button_2_1 EQU $C816
Vec_Music_Wk_5 EQU $C847
MOVETO_D_7F EQU $F2FC
Vec_RiseRun_Tmp EQU $C834
Vec_Twang_Table EQU $C851
VEC_TEXT_WIDTH EQU $C82B
VEC_RISE_INDEX EQU $C839
Init_OS_RAM EQU $F164
Intensity_5F EQU $F2A5
VEC_MUSIC_WK_6 EQU $C846
AUDIO_UPDATE EQU $42D1
JOY_DIGITAL EQU $F1F8
VEC_LOOP_COUNT EQU $C825
DRAW_PAT_VL EQU $F437
Vec_Text_HW EQU $C82A
Draw_Line_d EQU $F3DF
MOD16.M16_DONE EQU $40BD
Clear_Score EQU $F84F
Vec_Counters EQU $C82E
INTENSITY_A EQU $F2AB
music9 EQU $FF26
Vec_Button_2_3 EQU $C818
Reset0Int EQU $F36B
musica EQU $FF44
MOVE_MEM_A_1 EQU $F67F
sfx_m_noise EQU $43F1
DELAY_3 EQU $F56D
MOV_DRAW_VL_B EQU $F3B1
SFX_ENDOFEFFECT EQU $440B
VEC_NUM_PLAYERS EQU $C879
INTENSITY_7F EQU $F2A9
Dot_ix EQU $F2C1
Vec_Joy_Mux_1_Y EQU $C820
Vec_Counter_1 EQU $C82E
Clear_x_d EQU $F548
VEC_MUSIC_CHAN EQU $C855
music8 EQU $FEF8
Cold_Start EQU $F000
Vec_Num_Players EQU $C879
VEC_EXPL_CHAN EQU $C85C
MOV_DRAW_VL_D EQU $F3BE
Reset0Ref_D0 EQU $F34A
Vec_Cold_Flag EQU $CBFE
Vec_Counter_3 EQU $C830
Vec_Joy_Mux_2_X EQU $C821
New_High_Score EQU $F8D8
VEC_SEED_PTR EQU $C87B
Vec_Joy_2_X EQU $C81D
Obj_Hit EQU $F8FF
DEC_COUNTERS EQU $F563
Vec_Buttons EQU $C811
ADD_SCORE_D EQU $F87C
DELAY_RTS EQU $F57D
Rise_Run_Angle EQU $F593
Vec_FIRQ_Vector EQU $CBF5
sfx_doframe EQU $4398
VEC_JOY_MUX_2_X EQU $C821
MOD16.M16_LOOP EQU $409E
PSG_update_done EQU $42A6
MOD16.M16_RCHECK EQU $408F
Dot_List_Reset EQU $F2DE
Vec_Num_Game EQU $C87A
Vec_Brightness EQU $C827
Vec_Counter_6 EQU $C833
DP_TO_C8 EQU $F1AF
Moveto_ix_a EQU $F30E
Vec_Joy_Mux_2_Y EQU $C822
RESET0INT EQU $F36B
VEC_BUTTON_2_1 EQU $C816
Select_Game EQU $F7A9
VEC_TEXT_HW EQU $C82A
VEC_COUNTER_6 EQU $C833
Get_Rise_Idx EQU $F5D9
RECALIBRATE EQU $F2E6
CLEAR_SCORE EQU $F84F
VEC_SWI3_VECTOR EQU $CBF2
Moveto_d EQU $F312
SOUND_BYTE_RAW EQU $F25B
sfx_m_tonedis EQU $43EF
CLEAR_X_B_80 EQU $F550
MOD16.M16_RPOS EQU $409E
XFORM_RUN EQU $F65D
INIT_MUSIC_CHK EQU $F687
CLEAR_SOUND EQU $F272
PRINT_SHIPS_X EQU $F391
Vec_Prev_Btns EQU $C810
Mov_Draw_VL_b EQU $F3B1
PSG_music_ended EQU $4298
SFX_M_TONEDIS EQU $43EF
AU_SKIP_MUSIC EQU $4363
Get_Rise_Run EQU $F5EF
DELAY_2 EQU $F571
AU_MUSIC_ENDED EQU $4352
DCR_AFTER_INTENSITY EQU $40F6
VEC_EXPL_FLAG EQU $C867
VEC_JOY_RESLTN EQU $C81A
WAIT_RECAL EQU $F192
DO_SOUND EQU $F289
VEC_FREQ_TABLE EQU $C84D
MUSIC1 EQU $FD0D
INIT_VIA EQU $F14C
VEC_JOY_2_Y EQU $C81E
Random EQU $F517
VEC_COUNTER_4 EQU $C831
Print_Str_yx EQU $F378
DEC_3_COUNTERS EQU $F55A
GET_RUN_IDX EQU $F5DB
INIT_OS EQU $F18B
Vec_Rfrsh EQU $C83D
INTENSITY_5F EQU $F2A5
Vec_Default_Stk EQU $CBEA
VEC_RFRSH_HI EQU $C83E
Vec_Music_Ptr EQU $C853
Vec_Dot_Dwell EQU $C828
Vec_Joy_1_Y EQU $C81C
SFX_NEXTFRAME EQU $4406
Vec_SWI2_Vector EQU $CBF2
AU_DONE EQU $4379
VECTREX_PRINT_TEXT EQU $403A
AU_MUSIC_DONE EQU $434C
Vec_Music_Chan EQU $C855
AU_MUSIC_READ EQU $4309
AU_MUSIC_WRITE_LOOP EQU $4335
DOT_IX_B EQU $F2BE
VEC_BUTTON_1_4 EQU $C815
Rot_VL_dft EQU $F637
VEC_ANGLE EQU $C836
VEC_RANDOM_SEED EQU $C87D
AU_BANK_OK EQU $42EB
VEC_DURATION EQU $C857
VEC_TEXT_HEIGHT EQU $C82A
VEC_SWI_VECTOR EQU $CBFB
CLEAR_X_256 EQU $F545
DOT_LIST EQU $F2D5
VEC_HIGH_SCORE EQU $CBEB
COLD_START EQU $F000
RISE_RUN_Y EQU $F601
Clear_Sound EQU $F272
Vec_Music_Wk_1 EQU $C84B
VEC_RFRSH_LO EQU $C83D
Draw_VLcs EQU $F3D6
VEC_JOY_MUX EQU $C81F
Draw_VL_a EQU $F3DA
Check0Ref EQU $F34F
Warm_Start EQU $F06C
DRAW_VLC EQU $F3CE
SFX_UPDATEMIXER EQU $43DF
MOD16 EQU $406A
Vec_Expl_1 EQU $C858
DOT_LIST_RESET EQU $F2DE
music3 EQU $FD81
VEC_MUSIC_FLAG EQU $C856
Vec_Snd_Shadow EQU $C800
Wait_Recal EQU $F192
MUSICB EQU $FF62
musicb EQU $FF62
MUSIC7 EQU $FEC6
PLAY_SFX_RUNTIME EQU $4384
noay EQU $4397
Move_Mem_a_1 EQU $F67F
INTENSITY_3F EQU $F2A1
Vec_Rfrsh_hi EQU $C83E
SFX_M_NOISE EQU $43F1
Draw_VLc EQU $F3CE
Print_Str EQU $F495
Vec_Music_Freq EQU $C861
Draw_VL EQU $F3DD
Vec_Counter_5 EQU $C832
CHECK0REF EQU $F34F
Draw_Pat_VL_d EQU $F439
VEC_RISERUN_TMP EQU $C834
VEC_COUNTERS EQU $C82E
Sound_Byte_x EQU $F259
Delay_1 EQU $F575
Vec_Angle EQU $C836
RISE_RUN_ANGLE EQU $F593
Abs_b EQU $F58B
music7 EQU $FEC6
DRAW_PAT_VL_D EQU $F439
Delay_0 EQU $F579
Dec_3_Counters EQU $F55A
CLEAR_X_D EQU $F548
Vec_SWI_Vector EQU $CBFB
Do_Sound EQU $F289
MOD16.M16_DPOS EQU $4087
SELECT_GAME EQU $F7A9
Print_Ships_x EQU $F391
Vec_Expl_3 EQU $C85A
ASSET_BANK_TABLE EQU $4006
CLEAR_X_B_A EQU $F552
INTENSITY_1F EQU $F29D
PRINT_TEXT_STR_58672583180530 EQU $4441
MUSIC8 EQU $FEF8
MUSICC EQU $FF7A
VEC_NMI_VECTOR EQU $CBFB
RANDOM EQU $F517
RISE_RUN_LEN EQU $F603
RANDOM_3 EQU $F511
Clear_C8_RAM EQU $F542
Vec_Text_Width EQU $C82B
Joy_Analog EQU $F1F5
Moveto_ix EQU $F310
VEC_SWI2_VECTOR EQU $CBF2
music2 EQU $FD1D
Vec_Run_Index EQU $C837
Sound_Byte_raw EQU $F25B
MOVETO_IX_A EQU $F30E
DELAY_0 EQU $F579
Draw_Pat_VL_a EQU $F434
Intensity_7F EQU $F2A9
Moveto_d_7F EQU $F2FC
DRAW_VL_MODE EQU $F46E
DRAW_VLP EQU $F410
Delay_2 EQU $F571
PSG_frame_done EQU $4292
VEC_EXPL_2 EQU $C859
SOUND_BYTE EQU $F256
MUSICA EQU $FF44
Sound_Bytes_x EQU $F284
Rot_VL_Mode EQU $F62B
SOUND_BYTES EQU $F27D
Obj_Will_Hit EQU $F8F3
MUSICD EQU $FF8F
Vec_Button_1_2 EQU $C813
Read_Btns_Mask EQU $F1B4
VEC_MAX_GAMES EQU $C850
VEC_PREV_BTNS EQU $C810
PRINT_LIST EQU $F38A
Dot_here EQU $F2C5
DRAW_VL_B EQU $F3D2
Vec_Button_2_2 EQU $C817
Vec_Btn_State EQU $C80F
Init_OS EQU $F18B
WARM_START EQU $F06C
Mov_Draw_VLcs EQU $F3B5
Rise_Run_X EQU $F5FF
Print_List EQU $F38A
SOUND_BYTE_X EQU $F259
READ_BTNS_MASK EQU $F1B4
Explosion_Snd EQU $F92E
VEC_JOY_MUX_1_Y EQU $C820
PRINT_SHIPS EQU $F393
Bitmask_a EQU $F57E
VEC_JOY_MUX_2_Y EQU $C822
DP_to_D0 EQU $F1AA
DRAW_VL EQU $F3DD
VEC_PATTERN EQU $C829
sfx_checktonefreq EQU $43AB
Compare_Score EQU $F8C7
Vec_Music_Twang EQU $C858
DELAY_1 EQU $F575
DRAW_VLCS EQU $F3D6
MOVETO_D EQU $F312
XFORM_RISE EQU $F663
PSG_WRITE_LOOP EQU $4261
DP_TO_D0 EQU $F1AA
Draw_VLp_b EQU $F40E
MOV_DRAW_VLCS EQU $F3B5
VEC_MUSIC_FREQ EQU $C861
MOVE_MEM_A EQU $F683
Vec_Joy_1_X EQU $C81B
Vec_Joy_Resltn EQU $C81A
Vec_Rise_Index EQU $C839
VEC_EXPL_CHANS EQU $C854
VEC_RISERUN_LEN EQU $C83B
PSG_UPDATE_DONE EQU $42A6
Moveto_ix_FF EQU $F308
Random_3 EQU $F511
musicd EQU $FF8F
MOD16.M16_END EQU $40AE
Draw_VLp_scale EQU $F40C
Vec_Text_Height EQU $C82A
sfx_endofeffect EQU $440B
PRINT_STR_HWYX EQU $F373
DRAW_VL_A EQU $F3DA
Vec_Music_Wk_A EQU $C842
Vec_0Ref_Enable EQU $C824
Init_Music_Buf EQU $F533
MOVETO_X_7F EQU $F2F2
VEC_DOT_DWELL EQU $C828
DCR_intensity_5F EQU $40F3
MUSIC3 EQU $FD81
Dec_6_Counters EQU $F55E
DRAW_VLP_7F EQU $F408
music4 EQU $FDD3
Add_Score_d EQU $F87C
NOAY EQU $4397
Init_VIA EQU $F14C
ASSET_ADDR_TABLE EQU $4008
PMR_DONE EQU $4243
Moveto_ix_7F EQU $F30C
VEC_COUNTER_2 EQU $C82F
DRAW_VL_AB EQU $F3D8
SFX_CHECKVOLUME EQU $43D6
AU_MUSIC_LOOP EQU $4358
VEC_BUTTON_2_4 EQU $C819
DELAY_B EQU $F57A
VEC_EXPL_4 EQU $C85B
Dec_Counters EQU $F563
Recalibrate EQU $F2E6
Vec_Button_1_4 EQU $C815
Mov_Draw_VLc_a EQU $F3AD
Vec_High_Score EQU $CBEB
Abs_a_b EQU $F584
DOT_HERE EQU $F2C5
XFORM_RUN_A EQU $F65B
DRAW_LINE_D EQU $F3DF
Rot_VL_ab EQU $F610
Vec_Button_1_3 EQU $C814
VEC_RUN_INDEX EQU $C837
MUSIC4 EQU $FDD3
music6 EQU $FE76
VEC_JOY_2_X EQU $C81D
Delay_3 EQU $F56D
RESET0REF EQU $F354
Vec_Freq_Table EQU $C84D
PRINT_STR_YX EQU $F378
INIT_MUSIC_BUF EQU $F533
Init_Music_chk EQU $F687
Vec_RiseRun_Len EQU $C83B
Xform_Rise EQU $F663
VEC_COUNTER_3 EQU $C830
Mov_Draw_VL_d EQU $F3BE
Vec_Expl_Chan EQU $C85C
Print_List_hw EQU $F385
Mov_Draw_VL EQU $F3BC
Do_Sound_x EQU $F28C
Vec_IRQ_Vector EQU $CBF8
Vec_Button_2_4 EQU $C819
Vec_SWI3_Vector EQU $CBF2
VEC_SND_SHADOW EQU $C800
ROT_VL EQU $F616
VEC_RFRSH EQU $C83D
Draw_Pat_VL EQU $F437
VEC_MUSIC_WK_A EQU $C842
VEC_EXPL_3 EQU $C85A
Intensity_1F EQU $F29D
Draw_VL_ab EQU $F3D8
VEC_JOY_MUX_1_X EQU $C81F
VEC_STR_PTR EQU $C82C
VEC_BUTTON_1_1 EQU $C812
PMr_start_new EQU $4211
PRINT_TEXT_STR_3273774 EQU $4429
VEC_BUTTON_2_2 EQU $C817


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
DRAW_LINE_ARGS       EQU $C880+$1B   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$25   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$27   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$29   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$2A   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$2B   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$2D   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$2F   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$30   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
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
    ; TODO: Statement Pass { source_line: 11 }

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
    LDX #PRINT_TEXT_STR_2348223718253      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-80
    STD VAR_ARG0
    LDD #50
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_58672554795414      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-80
    STD VAR_ARG0
    LDD #30
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_58672583180530      ; Pointer to string in helpers bank
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
    ; PLAY_SFX("jump") - play SFX asset (index=1)
    LDX #1        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$64
    JSR Intensity_a
    LDA #$EC
    LDB #$08
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$FD
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$FE
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FD
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FE
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
    LDB #$03
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$02
    LDB #$02
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$03
    LDB #$01
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
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
    ; PLAY_SFX("explosion") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
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
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04
    LDA #$28
    JSR Intensity_a
    LDA #$EC
    LDB #$03
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$01
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
    LDA #$FF
    LDB #$FF
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$FF
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
    LDA #$FF
    LDB #$01
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$01
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
    LDA #$01
    LDB #$01
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8 after circle drawing
    LDD #0
    STD RESULT
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX (after all game logic)
    RTS


; ================================================
