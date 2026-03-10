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
Rot_VL EQU $F616
PSG_WRITE_LOOP EQU $4261
Moveto_ix EQU $F310
DO_SOUND EQU $F289
Vec_Music_Wk_A EQU $C842
VEC_MAX_GAMES EQU $C850
Draw_VLcs EQU $F3D6
VEC_DEFAULT_STK EQU $CBEA
SFX_CHECKNOISEFREQ EQU $43C5
MOV_DRAW_VL_B EQU $F3B1
MUSICB EQU $FF62
Vec_Expl_3 EQU $C85A
MOV_DRAW_VL_D EQU $F3BE
Vec_Joy_Mux EQU $C81F
Dot_List EQU $F2D5
RESET0INT EQU $F36B
DCR_AFTER_INTENSITY EQU $40F6
DELAY_B EQU $F57A
ABS_B EQU $F58B
INTENSITY_5F EQU $F2A5
RESET_PEN EQU $F35B
Mov_Draw_VL_a EQU $F3B9
Vec_Joy_2_Y EQU $C81E
OBJ_HIT EQU $F8FF
Moveto_ix_7F EQU $F30C
RISE_RUN_LEN EQU $F603
VEC_PREV_BTNS EQU $C810
Vec_Expl_Chans EQU $C854
MOVETO_IX_7F EQU $F30C
VEC_BRIGHTNESS EQU $C827
Vec_Music_Chan EQU $C855
music2 EQU $FD1D
PRINT_TEXT_STR_58672583180530 EQU $4441
Vec_Expl_Timer EQU $C877
MUSIC3 EQU $FD81
Vec_Default_Stk EQU $CBEA
Obj_Hit EQU $F8FF
sfx_endofeffect EQU $440B
DOT_LIST_RESET EQU $F2DE
VEC_EXPL_1 EQU $C858
Vec_Music_Wk_5 EQU $C847
ROT_VL EQU $F616
Xform_Rise EQU $F663
Add_Score_d EQU $F87C
MOV_DRAW_VL_AB EQU $F3B7
Print_Ships EQU $F393
Vec_Seed_Ptr EQU $C87B
MOV_DRAW_VL EQU $F3BC
Vec_Expl_2 EQU $C859
VEC_JOY_RESLTN EQU $C81A
DRAW_VLC EQU $F3CE
DELAY_0 EQU $F579
sfx_nextframe EQU $4406
Vec_SWI2_Vector EQU $CBF2
Xform_Run EQU $F65D
MOV_DRAW_VL_A EQU $F3B9
VEC_MUSIC_WORK EQU $C83F
MUSIC1 EQU $FD0D
VEC_DURATION EQU $C857
MUSIC6 EQU $FE76
VEC_EXPL_CHANB EQU $C85D
Vec_Joy_1_X EQU $C81B
VEC_MUSIC_WK_7 EQU $C845
RISE_RUN_ANGLE EQU $F593
Rise_Run_Y EQU $F601
Vec_Expl_ChanB EQU $C85D
Add_Score_a EQU $F85E
VEC_PATTERN EQU $C829
VEC_EXPL_4 EQU $C85B
Vec_Text_Height EQU $C82A
CLEAR_SCORE EQU $F84F
SFX_UPDATE EQU $438D
Draw_VL_a EQU $F3DA
VEC_RISE_INDEX EQU $C839
Vec_IRQ_Vector EQU $CBF8
ASSET_ADDR_TABLE EQU $4008
Clear_Score EQU $F84F
musicb EQU $FF62
DRAW_PAT_VL_D EQU $F439
DCR_INTENSITY_5F EQU $40F3
Abs_b EQU $F58B
DOT_HERE EQU $F2C5
AU_MUSIC_DONE EQU $434C
VEC_BUTTON_1_1 EQU $C812
DELAY_2 EQU $F571
Vec_Music_Flag EQU $C856
music4 EQU $FDD3
VEC_FREQ_TABLE EQU $C84D
Vec_Expl_Chan EQU $C85C
Get_Rise_Run EQU $F5EF
Init_Music_x EQU $F692
PRINT_TEXT_STR_89546106876693 EQU $444B
VEC_STR_PTR EQU $C82C
DRAW_GRID_VL EQU $FF9F
VEC_TWANG_TABLE EQU $C851
Dot_ix_b EQU $F2BE
VEC_RISERUN_LEN EQU $C83B
Vec_Freq_Table EQU $C84D
DRAW_VL_MODE EQU $F46E
Intensity_5F EQU $F2A5
Vec_SWI_Vector EQU $CBFB
Vec_Button_1_4 EQU $C815
Vec_Num_Players EQU $C879
MOVETO_X_7F EQU $F2F2
DOT_LIST EQU $F2D5
DEC_3_COUNTERS EQU $F55A
Draw_VL_b EQU $F3D2
Do_Sound_x EQU $F28C
Vec_RiseRun_Len EQU $C83B
PRINT_STR_YX EQU $F378
VEC_BUTTON_1_2 EQU $C813
VEC_ADSR_TIMERS EQU $C85E
DRAW_VLCS EQU $F3D6
Reset_Pen EQU $F35B
Random EQU $F517
VEC_MUSIC_CHAN EQU $C855
Delay_RTS EQU $F57D
Vec_FIRQ_Vector EQU $CBF5
VEC_RFRSH EQU $C83D
AU_MUSIC_PROCESS_WRITES EQU $4333
Vec_Max_Games EQU $C850
ROT_VL_DFT EQU $F637
Vec_Buttons EQU $C811
Vec_Expl_1 EQU $C858
Sound_Byte EQU $F256
Vec_Text_Width EQU $C82B
VEC_NUM_PLAYERS EQU $C879
SFX_UPDATEMIXER EQU $43DF
DELAY_1 EQU $F575
VEC_ADSR_TABLE EQU $C84F
Move_Mem_a EQU $F683
Draw_VLp_b EQU $F40E
Draw_Pat_VL EQU $F437
AU_UPDATE_SFX EQU $4366
Cold_Start EQU $F000
Clear_x_d EQU $F548
PRINT_STR EQU $F495
ASSET_BANK_TABLE EQU $4006
DEC_COUNTERS EQU $F563
PRINT_TEXT_STR_2348223718253 EQU $442E
INIT_VIA EQU $F14C
VEC_RANDOM_SEED EQU $C87D
SOUND_BYTES_X EQU $F284
Vec_Music_Freq EQU $C861
Vec_Joy_1_Y EQU $C81C
Init_OS EQU $F18B
MOD16.M16_LOOP EQU $409E
PMR_START_NEW EQU $4211
VEC_COUNTER_5 EQU $C832
VEC_RFRSH_HI EQU $C83E
PLAY_MUSIC_RUNTIME EQU $4203
Clear_x_256 EQU $F545
GET_RISE_RUN EQU $F5EF
MOD16 EQU $406A
SFX_DOFRAME EQU $4398
musica EQU $FF44
MUSIC4 EQU $FDD3
Dot_ix EQU $F2C1
Vec_Counter_4 EQU $C831
VEC_JOY_2_Y EQU $C81E
VEC_MUSIC_WK_5 EQU $C847
DRAW_PAT_VL EQU $F437
sfx_m_write EQU $43FE
MOD16.M16_RCHECK EQU $408F
RISE_RUN_Y EQU $F601
Print_Str_yx EQU $F378
VEC_MISC_COUNT EQU $C823
Vec_Joy_Mux_1_Y EQU $C820
sfx_m_noise EQU $43F1
VEC_COUNTER_1 EQU $C82E
PSG_UPDATE_DONE EQU $42A6
Dec_3_Counters EQU $F55A
VEC_COUNTER_3 EQU $C830
Vec_Joy_Resltn EQU $C81A
XFORM_RUN EQU $F65D
VEC_MUSIC_TWANG EQU $C858
PSG_frame_done EQU $4292
AU_MUSIC_READ EQU $4309
VEC_DOT_DWELL EQU $C828
music5 EQU $FE38
Draw_VLp_scale EQU $F40C
Sound_Bytes_x EQU $F284
SFX_M_WRITE EQU $43FE
SFX_M_TONEDIS EQU $43EF
Delay_0 EQU $F579
VEC_COUNTER_6 EQU $C833
sfx_checktonefreq EQU $43AB
VEC_TEXT_HW EQU $C82A
Random_3 EQU $F511
AU_MUSIC_LOOP EQU $4358
Draw_Pat_VL_d EQU $F439
PSG_music_loop EQU $429E
GET_RUN_IDX EQU $F5DB
VEC_MAX_PLAYERS EQU $C84F
VEC_JOY_MUX_2_Y EQU $C822
DCR_intensity_5F EQU $40F3
Vec_Button_1_1 EQU $C812
VEC_BTN_STATE EQU $C80F
Draw_Grid_VL EQU $FF9F
Do_Sound EQU $F289
VEC_0REF_ENABLE EQU $C824
Compare_Score EQU $F8C7
ABS_A_B EQU $F584
Rot_VL_ab EQU $F610
music6 EQU $FE76
DO_SOUND_X EQU $F28C
Clear_C8_RAM EQU $F542
PRINT_STR_D EQU $F37A
SELECT_GAME EQU $F7A9
VEC_EXPL_CHANA EQU $C853
musicd EQU $FF8F
INTENSITY_A EQU $F2AB
sfx_checknoisefreq EQU $43C5
SOUND_BYTE EQU $F256
INIT_MUSIC_BUF EQU $F533
Rise_Run_Len EQU $F603
musicc EQU $FF7A
AU_MUSIC_HAS_DELAY EQU $4329
Rot_VL_dft EQU $F637
VEC_JOY_2_X EQU $C81D
Dec_6_Counters EQU $F55E
Vec_Expl_4 EQU $C85B
Vec_Counters EQU $C82E
DRAW_VL_A EQU $F3DA
Vec_ADSR_Table EQU $C84F
Vec_Dot_Dwell EQU $C828
Print_Str EQU $F495
VEC_JOY_MUX_1_X EQU $C81F
Read_Btns_Mask EQU $F1B4
STRIP_ZEROS EQU $F8B7
DRAW_LINE_D EQU $F3DF
VEC_BUTTON_2_3 EQU $C818
PRINT_STR_HWYX EQU $F373
Vec_Expl_ChanA EQU $C853
AU_MUSIC_READ_COUNT EQU $431A
Explosion_Snd EQU $F92E
VEC_SEED_PTR EQU $C87B
VEC_HIGH_SCORE EQU $CBEB
PSG_MUSIC_LOOP EQU $429E
VEC_MUSIC_WK_6 EQU $C846
DRAW_VLP_7F EQU $F408
New_High_Score EQU $F8D8
Draw_VL_mode EQU $F46E
Clear_x_b_80 EQU $F550
CLEAR_X_D EQU $F548
STOP_MUSIC_RUNTIME EQU $42AA
Xform_Rise_a EQU $F661
NEW_HIGH_SCORE EQU $F8D8
DOT_D EQU $F2C3
PSG_update_done EQU $42A6
Dot_here EQU $F2C5
Moveto_d EQU $F312
COLD_START EQU $F000
VEC_COUNTERS EQU $C82E
Clear_x_b EQU $F53F
Vec_RiseRun_Tmp EQU $C834
Vec_Joy_Mux_1_X EQU $C81F
BITMASK_A EQU $F57E
Bitmask_a EQU $F57E
Mov_Draw_VL EQU $F3BC
PMR_DONE EQU $4243
DP_to_C8 EQU $F1AF
Rise_Run_X EQU $F5FF
Mov_Draw_VL_b EQU $F3B1
Read_Btns EQU $F1BA
Dec_Counters EQU $F563
PRINT_TEXT_STR_3273774 EQU $4429
PSG_write_loop EQU $4261
sfx_checkvolume EQU $43D6
music8 EQU $FEF8
AU_DONE EQU $4379
CHECK0REF EQU $F34F
DP_TO_C8 EQU $F1AF
Vec_Button_2_2 EQU $C817
Vec_NMI_Vector EQU $CBFB
Vec_Button_2_3 EQU $C818
MUSICC EQU $FF7A
INIT_MUSIC_CHK EQU $F687
VEC_EXPL_FLAG EQU $C867
sfx_m_noisedis EQU $43FC
Warm_Start EQU $F06C
Vec_Button_2_1 EQU $C816
Rot_VL_Mode_a EQU $F61F
Vec_Cold_Flag EQU $CBFE
Vec_Button_2_4 EQU $C819
JOY_DIGITAL EQU $F1F8
noay EQU $4397
Draw_VLp EQU $F410
Vec_Misc_Count EQU $C823
VEC_COUNTER_4 EQU $C831
Mov_Draw_VLcs EQU $F3B5
SFX_ADDR_TABLE EQU $4002
Vec_Button_1_3 EQU $C814
VEC_RUN_INDEX EQU $C837
Intensity_a EQU $F2AB
Draw_VLp_7F EQU $F408
SFX_BANK_TABLE EQU $4000
Vec_Twang_Table EQU $C851
Vec_Prev_Btns EQU $C810
AU_MUSIC_NO_DELAY EQU $431A
VEC_JOY_1_X EQU $C81B
Strip_Zeros EQU $F8B7
MOVETO_IX EQU $F310
VEC_MUSIC_PTR EQU $C853
Clear_Sound EQU $F272
Draw_Line_d EQU $F3DF
EXPLOSION_SND EQU $F92E
Clear_x_b_a EQU $F552
Vec_Music_Twang EQU $C858
Sound_Byte_raw EQU $F25B
VEC_NUM_GAME EQU $C87A
Vec_Text_HW EQU $C82A
VEC_SWI2_VECTOR EQU $CBF2
SFX_NEXTFRAME EQU $4406
INIT_MUSIC_X EQU $F692
MOVETO_IX_A EQU $F30E
VEC_JOY_MUX EQU $C81F
Set_Refresh EQU $F1A2
RISE_RUN_X EQU $F5FF
Reset0Ref_D0 EQU $F34A
MOVETO_D_7F EQU $F2FC
VEC_SND_SHADOW EQU $C800
Vec_Music_Wk_6 EQU $C846
VEC_MUSIC_FLAG EQU $C856
JOY_ANALOG EQU $F1F5
VEC_EXPL_CHAN EQU $C85C
music3 EQU $FD81
sfx_m_tonedis EQU $43EF
VEC_SWI3_VECTOR EQU $CBF2
Moveto_x_7F EQU $F2F2
Vec_Brightness EQU $C827
Moveto_ix_FF EQU $F308
VEC_MUSIC_WK_A EQU $C842
CLEAR_C8_RAM EQU $F542
Rise_Run_Angle EQU $F593
VEC_COUNTER_2 EQU $C82F
Vec_SWI3_Vector EQU $CBF2
Init_Music EQU $F68D
Vec_Rfrsh_hi EQU $C83E
PSG_FRAME_DONE EQU $4292
PRINT_LIST_HW EQU $F385
CLEAR_X_B_80 EQU $F550
Sound_Byte_x EQU $F259
DRAW_VL EQU $F3DD
MOD16.M16_END EQU $40AE
PSG_music_ended EQU $4298
VEC_BUTTON_1_4 EQU $C815
VEC_JOY_1_Y EQU $C81C
Vec_Counter_6 EQU $C833
Vec_Rise_Index EQU $C839
AUDIO_UPDATE EQU $42D1
MOV_DRAW_VLC_A EQU $F3AD
VEC_IRQ_VECTOR EQU $CBF8
INIT_MUSIC EQU $F68D
VEC_SWI_VECTOR EQU $CBFB
Vec_High_Score EQU $CBEB
Vec_Str_Ptr EQU $C82C
Mov_Draw_VL_ab EQU $F3B7
AU_BANK_OK EQU $42EB
Vec_Button_1_2 EQU $C813
Obj_Will_Hit_u EQU $F8E5
Sound_Bytes EQU $F27D
Vec_Rfrsh_lo EQU $C83D
VEC_JOY_MUX_1_Y EQU $C820
Vec_Loop_Count EQU $C825
DP_TO_D0 EQU $F1AA
VEC_MUSIC_WK_1 EQU $C84B
Vec_Joy_Mux_2_Y EQU $C822
OBJ_WILL_HIT EQU $F8F3
READ_BTNS_MASK EQU $F1B4
DRAW_PAT_VL_A EQU $F434
VEC_JOY_MUX_2_X EQU $C821
VEC_BUTTONS EQU $C811
DRAW_VLP_SCALE EQU $F40C
VEC_TEXT_HEIGHT EQU $C82A
Vec_Max_Players EQU $C84F
MUSIC8 EQU $FEF8
MOV_DRAW_VLCS EQU $F3B5
Intensity_3F EQU $F2A1
Init_VIA EQU $F14C
Reset0Int EQU $F36B
SET_REFRESH EQU $F1A2
MOVETO_D EQU $F312
Print_Str_d EQU $F37A
VEC_BUTTON_1_3 EQU $C814
MUSIC9 EQU $FF26
Mov_Draw_VL_d EQU $F3BE
ROT_VL_MODE EQU $F62B
Wait_Recal EQU $F192
Draw_Pat_VL_a EQU $F434
AU_MUSIC_ENDED EQU $4352
SOUND_BYTE_RAW EQU $F25B
ROT_VL_AB EQU $F610
Init_OS_RAM EQU $F164
Delay_1 EQU $F575
Vec_Joy_2_X EQU $C81D
Delay_3 EQU $F56D
Vec_Counter_1 EQU $C82E
VEC_COLD_FLAG EQU $CBFE
Check0Ref EQU $F34F
Vec_Counter_3 EQU $C830
MUSIC7 EQU $FEC6
Intensity_1F EQU $F29D
Moveto_ix_a EQU $F30E
VEC_RFRSH_LO EQU $C83D
Vec_Pattern EQU $C829
Vec_Music_Work EQU $C83F
Joy_Digital EQU $F1F8
ROT_VL_MODE_A EQU $F61F
Get_Run_Idx EQU $F5DB
PRINT_LIST EQU $F38A
XFORM_RISE EQU $F663
Vec_Num_Game EQU $C87A
PRINT_TEXT_STR_58672554795414 EQU $4437
Xform_Run_a EQU $F65B
Print_List_hw EQU $F385
Delay_b EQU $F57A
DEC_6_COUNTERS EQU $F55E
DRAW_CIRCLE_RUNTIME EQU $40BE
Mov_Draw_VLc_a EQU $F3AD
DRAW_VLP EQU $F410
MUSICA EQU $FF44
MOD16.M16_DONE EQU $40BD
Delay_2 EQU $F571
Vec_Random_Seed EQU $C87D
VEC_LOOP_COUNT EQU $C825
INTENSITY_3F EQU $F2A1
AU_SKIP_MUSIC EQU $4363
DELAY_3 EQU $F56D
VEC_TEXT_WIDTH EQU $C82B
VEC_BUTTON_2_4 EQU $C819
MOVE_MEM_A EQU $F683
Get_Rise_Idx EQU $F5D9
CLEAR_X_256 EQU $F545
DOT_IX EQU $F2C1
DRAW_VL_AB EQU $F3D8
Dot_d EQU $F2C3
UPDATE_MUSIC_PSG EQU $4244
DRAW_VLP_B EQU $F40E
Vec_Run_Index EQU $C837
Intensity_7F EQU $F2A9
VEC_ANGLE EQU $C836
VEC_EXPL_2 EQU $C859
Print_List_chk EQU $F38C
music7 EQU $FEC6
DOT_IX_B EQU $F2BE
ADD_SCORE_D EQU $F87C
SFX_CHECKTONEFREQ EQU $43AB
VEC_EXPL_CHANS EQU $C854
DP_to_D0 EQU $F1AA
CLEAR_SOUND EQU $F272
INTENSITY_1F EQU $F29D
Dot_List_Reset EQU $F2DE
Reset0Ref EQU $F354
XFORM_RUN_A EQU $F65B
CLEAR_X_B EQU $F53F
INIT_OS_RAM EQU $F164
VEC_FIRQ_VECTOR EQU $CBF5
Vec_ADSR_Timers EQU $C85E
Draw_VLp_FF EQU $F404
SFX_M_NOISE EQU $43F1
Moveto_d_7F EQU $F2FC
Recalibrate EQU $F2E6
MOVE_MEM_A_1 EQU $F67F
RESET0REF EQU $F354
PSG_MUSIC_ENDED EQU $4298
MUSIC5 EQU $FE38
VEC_RISERUN_TMP EQU $C834
Draw_VL EQU $F3DD
RANDOM EQU $F517
MOD16.M16_DPOS EQU $4087
Rot_VL_Mode EQU $F62B
Vec_Duration EQU $C857
Init_Music_Buf EQU $F533
RESET0REF_D0 EQU $F34A
OBJ_WILL_HIT_U EQU $F8E5
Draw_VL_ab EQU $F3D8
Vec_Music_Wk_7 EQU $C845
MOD16.M16_RPOS EQU $409E
Print_List EQU $F38A
VEC_NMI_VECTOR EQU $CBFB
SFX_M_NOISEDIS EQU $43FC
ADD_SCORE_A EQU $F85E
Vec_Btn_State EQU $C80F
PLAY_SFX_RUNTIME EQU $4384
PMr_start_new EQU $4211
RANDOM_3 EQU $F511
VEC_EXPL_TIMER EQU $C877
Select_Game EQU $F7A9
PLAY_SFX_BANKED EQU $400C
Vec_Expl_Flag EQU $C867
Print_Ships_x EQU $F391
Vec_Counter_5 EQU $C832
Vec_Joy_Mux_2_X EQU $C821
SOUND_BYTE_X EQU $F259
sfx_doframe EQU $4398
DRAW_VLP_FF EQU $F404
PRINT_LIST_CHK EQU $F38C
VEC_MUSIC_FREQ EQU $C861
NOAY EQU $4397
GET_RISE_IDX EQU $F5D9
VEC_BUTTON_2_1 EQU $C816
SOUND_BYTES EQU $F27D
VEC_BUTTON_2_2 EQU $C817
DRAW_VL_B EQU $F3D2
VECTREX_PRINT_TEXT EQU $403A
SFX_CHECKVOLUME EQU $43D6
Vec_Rfrsh EQU $C83D
MOVETO_IX_FF EQU $F308
Vec_Snd_Shadow EQU $C800
sfx_updatemixer EQU $43DF
Draw_VLc EQU $F3CE
Vec_Angle EQU $C836
AU_MUSIC_WRITE_LOOP EQU $4335
Joy_Analog EQU $F1F5
Move_Mem_a_1 EQU $F67F
Vec_Music_Ptr EQU $C853
Vec_Counter_2 EQU $C82F
PRINT_SHIPS EQU $F393
Abs_a_b EQU $F584
WARM_START EQU $F06C
WAIT_RECAL EQU $F192
COMPARE_SCORE EQU $F8C7
Print_Str_hwyx EQU $F373
Obj_Will_Hit EQU $F8F3
music1 EQU $FD0D
CLEAR_X_B_A EQU $F552
PRINT_SHIPS_X EQU $F391
Vec_Music_Wk_1 EQU $C84B
INIT_OS EQU $F18B
DCR_after_intensity EQU $40F6
RECALIBRATE EQU $F2E6
Init_Music_chk EQU $F687
music9 EQU $FF26
MUSIC2 EQU $FD1D
VEC_EXPL_3 EQU $C85A
Vec_0Ref_Enable EQU $C824
DELAY_RTS EQU $F57D
XFORM_RISE_A EQU $F661
PMr_done EQU $4243
READ_BTNS EQU $F1BA
MUSICD EQU $FF8F
SFX_ENDOFEFFECT EQU $440B
INTENSITY_7F EQU $F2A9


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
