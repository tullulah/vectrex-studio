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
DRAW_SCALE           EQU $C880+$38   ; Current T1 scale for Draw_Sync_List_At_With_Mirrors ($7F=normal) (1 bytes)
VAR_STATE            EQU $C880+$39   ; User variable: STATE (2 bytes)
VAR_BTN1             EQU $C880+$3B   ; User variable: BTN1 (2 bytes)
PSG_MUSIC_PTR        EQU $C880+$3D   ; PSG music data pointer (2 bytes)
PSG_MUSIC_START      EQU $C880+$3F   ; PSG music start pointer (for loops) (2 bytes)
PSG_MUSIC_ACTIVE     EQU $C880+$41   ; PSG music active flag (1 bytes)
PSG_IS_PLAYING       EQU $C880+$42   ; PSG playing flag (1 bytes)
PSG_DELAY_FRAMES     EQU $C880+$43   ; PSG frame delay counter (1 bytes)
PSG_MUSIC_BANK       EQU $C880+$44   ; PSG music bank ID (for multibank) (1 bytes)
SFX_PTR              EQU $C880+$45   ; SFX data pointer (2 bytes)
SFX_ACTIVE           EQU $C880+$47   ; SFX active flag (1 bytes)
SFX_BANK             EQU $C880+$48   ; SFX bank ID (for multibank) (1 bytes)
VAR_ARG0             EQU $C880+$49   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $C880+$4B   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $C880+$4D   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $C880+$4F   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $C880+$51   ; Function argument 4 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $C880+$53   ; Current ROM bank ID (multibank tracking) (1 bytes)


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
READ_BTNS EQU $F1BA
_CRYPT_LOGO_PATH38 EQU $02A7
_CRYPT_LOGO_PATH37 EQU $029E
VEC_MUSIC_WK_7 EQU $C845
Print_Ships EQU $F393
sfx_updatemixer EQU $4459
DEC_6_COUNTERS EQU $F55E
BITMASK_A EQU $F57E
PMr_start_new EQU $424C
_CRYPT_LOGO_PATH21 EQU $01C3
Vec_Text_HW EQU $C82A
CLEAR_C8_RAM EQU $F542
Delay_2 EQU $F571
RANDOM_3 EQU $F511
MOV_DRAW_VL_B EQU $F3B1
Vec_Expl_1 EQU $C858
Rise_Run_Angle EQU $F593
Reset0Int EQU $F36B
Clear_x_b_80 EQU $F550
Init_Music_Buf EQU $F533
ASSET_ADDR_TABLE EQU $400C
Wait_Recal EQU $F192
MUSIC_BANK_TABLE EQU $4003
Joy_Analog EQU $F1F5
VEC_EXPL_CHANB EQU $C85D
PMR_DONE EQU $427E
DELAY_3 EQU $F56D
_CRYPT_LOGO_PATH8 EQU $00E2
MUSICC EQU $FF7A
VEC_BRIGHTNESS EQU $C827
Reset0Ref_D0 EQU $F34A
_CRYPT_LOGO_PATH10 EQU $0109
VEC_JOY_1_Y EQU $C81C
_CRYPT_LOGO_PATH30 EQU $024A
SFX_DOFRAME EQU $4412
VEC_MUSIC_WK_1 EQU $C84B
VECTOR_ADDR_TABLE EQU $4001
_CRYPT_LOGO_PATH36 EQU $028C
INIT_MUSIC_X EQU $F692
Draw_VLp_b EQU $F40E
Init_OS_RAM EQU $F164
DRAW_VECTOR_BANKED EQU $4012
SFX_UPDATE EQU $4407
PRINT_LIST_HW EQU $F385
music5 EQU $FE38
_CRYPT_LOGO_PATH2 EQU $0064
CLEAR_X_256 EQU $F545
WAIT_RECAL EQU $F192
VEC_JOY_MUX_2_Y EQU $C822
Rot_VL_Mode EQU $F62B
PMr_done EQU $427E
VEC_COUNTER_1 EQU $C82E
Rot_VL EQU $F616
SOUND_BYTES_X EQU $F284
PSG_READ_DELAY EQU $429D
Init_Music_chk EQU $F687
VEC_RANDOM_SEED EQU $C87D
INTENSITY_7F EQU $F2A9
Vec_Default_Stk EQU $CBEA
Clear_Sound EQU $F272
DSWM_NEXT_USE_OVERRIDE EQU $41C0
Xform_Rise EQU $F663
Check0Ref EQU $F34F
Vec_Rise_Index EQU $C839
ROT_VL_MODE EQU $F62B
SET_REFRESH EQU $F1A2
sfx_m_noisedis EQU $4476
VEC_MAX_GAMES EQU $C850
Draw_VLp_scale EQU $F40C
Vec_Music_Freq EQU $C861
Vec_Music_Wk_7 EQU $C845
Reset_Pen EQU $F35B
VEC_BUTTON_2_1 EQU $C816
DRAW_VLP_FF EQU $F404
AU_MUSIC_READ EQU $437F
Rot_VL_ab EQU $F610
SELECT_GAME EQU $F7A9
_CRYPT_LOGO_PATH19 EQU $0181
Vec_Joy_Mux_1_Y EQU $C820
Draw_Pat_VL_d EQU $F439
ABS_A_B EQU $F584
AU_BANK_OK EQU $4361
RANDOM EQU $F517
SFX_M_WRITE EQU $4478
PLAY_MUSIC_BANKED EQU $405E
Clear_x_d EQU $F548
Vec_Misc_Count EQU $C823
STOP_MUSIC_RUNTIME EQU $4320
Do_Sound_x EQU $F28C
Vec_Button_2_1 EQU $C816
DSWM_NO_NEGATE_X EQU $4112
RECALIBRATE EQU $F2E6
_CRYPT_LOGO_PATH29 EQU $0241
VEC_JOY_1_X EQU $C81B
Xform_Rise_a EQU $F661
DRAW_VLP EQU $F410
PSG_MUSIC_LOOP_D EQU $4314
Moveto_d EQU $F312
RESET0REF EQU $F354
_INTRO_MUSIC EQU $0616
Vec_Joy_1_X EQU $C81B
XFORM_RUN EQU $F65D
Vec_Loop_Count EQU $C825
DELAY_2 EQU $F571
_EXPLORATION_MUSIC EQU $02DA
DSWM_USE_OVERRIDE EQU $40F6
Obj_Hit EQU $F8FF
DOT_LIST_RESET EQU $F2DE
ROT_VL_MODE_A EQU $F61F
XFORM_RUN_A EQU $F65B
DSWM_DONE EQU $423D
Init_OS EQU $F18B
Vec_Joy_Mux_2_Y EQU $C822
DRAW_VL EQU $F3DD
JOY_ANALOG EQU $F1F5
Vec_Button_2_4 EQU $C819
VEC_MUSIC_TWANG EQU $C858
XFORM_RISE_A EQU $F661
INTENSITY_3F EQU $F2A1
Clear_x_b EQU $F53F
VEC_COUNTER_3 EQU $C830
PSG_PROCESS_EVENT EQU $42B8
Vec_Num_Players EQU $C879
AU_MUSIC_PROCESS_WRITES EQU $43AD
Get_Run_Idx EQU $F5DB
INTENSITY_5F EQU $F2A5
GET_RISE_IDX EQU $F5D9
Vec_Music_Work EQU $C83F
Compare_Score EQU $F8C7
DSWM_NO_NEGATE_Y EQU $4105
VEC_COUNTER_2 EQU $C82F
VEC_FIRQ_VECTOR EQU $CBF5
_CRYPT_LOGO_PATH0 EQU $0052
VEC_MUSIC_CHAN EQU $C855
VEC_COUNTER_6 EQU $C833
SFX_M_NOISEDIS EQU $4476
_CRYPT_LOGO_PATH31 EQU $0253
Vec_Prev_Btns EQU $C810
Vec_Counter_2 EQU $C82F
Mov_Draw_VLcs EQU $F3B5
VEC_TEXT_HW EQU $C82A
VEC_0REF_ENABLE EQU $C824
sfx_checknoisefreq EQU $443F
Draw_VL_mode EQU $F46E
Init_Music_x EQU $F692
_CRYPT_LOGO_PATH3 EQU $007C
Sound_Bytes EQU $F27D
Vec_Brightness EQU $C827
Delay_b EQU $F57A
Vec_Buttons EQU $C811
VEC_BUTTON_2_2 EQU $C817
Draw_VL_b EQU $F3D2
RISE_RUN_Y EQU $F601
Xform_Run EQU $F65D
Draw_VL_ab EQU $F3D8
VEC_SEED_PTR EQU $C87B
Obj_Will_Hit EQU $F8F3
VEC_JOY_2_X EQU $C81D
RESET0INT EQU $F36B
sfx_endofeffect EQU $4485
MUSICA EQU $FF44
Vec_RiseRun_Len EQU $C83B
Vec_Rfrsh_hi EQU $C83E
DRAW_SYNC_LIST_AT_WITH_MIRRORS EQU $40EA
VEC_PREV_BTNS EQU $C810
MOD16.M16_RPOS EQU $40CA
_CRYPT_LOGO_PATH9 EQU $00FD
DRAW_VLP_SCALE EQU $F40C
MUSIC_ADDR_TABLE EQU $4005
CLEAR_SOUND EQU $F272
Explosion_Snd EQU $F92E
Vec_Max_Players EQU $C84F
Draw_VL_a EQU $F3DA
VEC_DOT_DWELL EQU $C828
Vec_Button_2_3 EQU $C818
MUSICB EQU $FF62
Dot_ix EQU $F2C1
VEC_COUNTER_5 EQU $C832
SOUND_BYTE_RAW EQU $F25B
Rise_Run_X EQU $F5FF
AU_SKIP_MUSIC EQU $43DD
Vec_Twang_Table EQU $C851
_CRYPT_LOGO_PATH17 EQU $016F
musica EQU $FF44
Vec_Counters EQU $C82E
DSWM_W3 EQU $4231
Clear_Score EQU $F84F
MUSIC1 EQU $FD0D
music7 EQU $FEC6
Move_Mem_a EQU $F683
_CRYPT_LOGO_PATH16 EQU $0163
music1 EQU $FD0D
Dec_3_Counters EQU $F55A
Print_Str_d EQU $F37A
VEC_SWI3_VECTOR EQU $CBF2
OBJ_HIT EQU $F8FF
DELAY_0 EQU $F579
Moveto_ix_FF EQU $F308
DP_to_D0 EQU $F1AA
CLEAR_X_B_80 EQU $F550
Vec_Button_2_2 EQU $C817
Read_Btns_Mask EQU $F1B4
CLEAR_X_D EQU $F548
Vec_Cold_Flag EQU $CBFE
DSWM_W2 EQU $419E
SFX_CHECKVOLUME EQU $4450
_CRYPT_LOGO_PATH6 EQU $00B5
Warm_Start EQU $F06C
DRAW_LINE_D EQU $F3DF
VEC_BUTTON_1_2 EQU $C813
Vec_Music_Chan EQU $C855
MUSICD EQU $FF8F
Print_Ships_x EQU $F391
GET_RISE_RUN EQU $F5EF
Mov_Draw_VL_a EQU $F3B9
Abs_b EQU $F58B
Moveto_ix_a EQU $F30E
COMPARE_SCORE EQU $F8C7
_CRYPT_LOGO_PATH13 EQU $013F
AU_MUSIC_READ_COUNT EQU $4390
Vec_Button_1_2 EQU $C813
VEC_MUSIC_FREQ EQU $C861
Vec_Button_1_4 EQU $C815
PSG_update_done EQU $431C
Move_Mem_a_1 EQU $F67F
Set_Refresh EQU $F1A2
Vec_Expl_Flag EQU $C867
Vec_Expl_Chan EQU $C85C
DRAW_GRID_VL EQU $FF9F
VEC_IRQ_VECTOR EQU $CBF8
musicb EQU $FF62
INTENSITY_1F EQU $F29D
Vec_RiseRun_Tmp EQU $C834
sfx_m_tonedis EQU $4469
Draw_VLcs EQU $F3D6
RESET_PEN EQU $F35B
RESET0REF_D0 EQU $F34A
PSG_music_loop EQU $4309
AU_UPDATE_SFX EQU $43E0
Vec_Music_Wk_6 EQU $C846
VEC_RUN_INDEX EQU $C837
Random EQU $F517
ADD_SCORE_D EQU $F87C
PRINT_SHIPS_X EQU $F391
Print_List EQU $F38A
music4 EQU $FDD3
VEC_BUTTON_2_4 EQU $C819
ASSET_BANK_TABLE EQU $4009
MOVETO_D_7F EQU $F2FC
music3 EQU $FD81
VEC_RFRSH_HI EQU $C83E
AU_MUSIC_LOOP EQU $43D2
Vec_High_Score EQU $CBEB
Vec_ADSR_Table EQU $C84F
VEC_BUTTON_1_4 EQU $C815
MOD16.M16_DPOS EQU $40B3
Vec_Run_Index EQU $C837
STRIP_ZEROS EQU $F8B7
Print_List_chk EQU $F38C
INIT_OS EQU $F18B
SOUND_BYTE_X EQU $F259
DSWM_LOOP EQU $4165
Draw_VLp_7F EQU $F408
Vec_Pattern EQU $C829
Intensity_3F EQU $F2A1
Select_Game EQU $F7A9
_CRYPT_LOGO_PATH39 EQU $02D1
DRAW_VL_A EQU $F3DA
VEC_PATTERN EQU $C829
PRINT_STR_HWYX EQU $F373
VEC_MUSIC_WK_6 EQU $C846
VEC_EXPL_2 EQU $C859
MUSIC9 EQU $FF26
Bitmask_a EQU $F57E
VEC_NUM_PLAYERS EQU $C879
DRAW_VL_MODE EQU $F46E
DRAW_PAT_VL EQU $F437
Vec_Counter_3 EQU $C830
VEC_MISC_COUNT EQU $C823
VEC_DEFAULT_STK EQU $CBEA
MUSIC4 EQU $FDD3
DRAW_VLC EQU $F3CE
Print_List_hw EQU $F385
VEC_JOY_2_Y EQU $C81E
Clear_x_256 EQU $F545
MUSIC2 EQU $FD1D
VEC_TEXT_HEIGHT EQU $C82A
VEC_ADSR_TABLE EQU $C84F
Add_Score_a EQU $F85E
PRINT_TEXT_STR_2718184010937820 EQU $44A9
Vec_Rfrsh EQU $C83D
Intensity_1F EQU $F29D
Vec_Dot_Dwell EQU $C828
PRINT_SHIPS EQU $F393
MUSIC8 EQU $FEF8
AU_MUSIC_NO_DELAY EQU $4390
Do_Sound EQU $F289
_CRYPT_LOGO_PATH1 EQU $005B
VEC_TWANG_TABLE EQU $C851
_CRYPT_LOGO_PATH15 EQU $0151
Vec_Joy_1_Y EQU $C81C
DSWM_NEXT_NO_NEGATE_Y EQU $41CE
AU_MUSIC_WRITE_LOOP EQU $43AF
RISE_RUN_ANGLE EQU $F593
Dot_ix_b EQU $F2BE
VEC_COUNTERS EQU $C82E
VEC_EXPL_1 EQU $C858
Vec_Seed_Ptr EQU $C87B
DO_SOUND_X EQU $F28C
Vec_Button_1_1 EQU $C812
OBJ_WILL_HIT EQU $F8F3
RISE_RUN_X EQU $F5FF
MOD16 EQU $4096
Vec_NMI_Vector EQU $CBFB
Vec_SWI3_Vector EQU $CBF2
Vec_Music_Wk_A EQU $C842
sfx_doframe EQU $4412
DRAW_VLCS EQU $F3D6
MOVE_MEM_A_1 EQU $F67F
DRAW_PAT_VL_A EQU $F434
Draw_VLp EQU $F410
_CRYPT_LOGO_PATH24 EQU $01F3
Vec_Joy_Mux EQU $C81F
_CRYPT_LOGO_PATH7 EQU $00BE
Vec_Counter_4 EQU $C831
DP_TO_C8 EQU $F1AF
VEC_LOOP_COUNT EQU $C825
Moveto_ix EQU $F310
PSG_EVENT_DONE EQU $42FA
VEC_SWI_VECTOR EQU $CBFB
_CRYPT_LOGO_PATH26 EQU $0208
Obj_Will_Hit_u EQU $F8E5
Vec_Text_Height EQU $C82A
VEC_JOY_MUX_2_X EQU $C821
Vec_Button_1_3 EQU $C814
MOV_DRAW_VL_D EQU $F3BE
INIT_MUSIC EQU $F68D
Moveto_x_7F EQU $F2F2
_CRYPT_LOGO_VECTORS EQU $0000
DRAW_VLP_7F EQU $F408
Vec_Counter_5 EQU $C832
Add_Score_d EQU $F87C
DP_TO_D0 EQU $F1AA
CLEAR_SCORE EQU $F84F
Vec_Angle EQU $C836
music6 EQU $FE76
EXPLOSION_SND EQU $F92E
PSG_write_loop EQU $42C9
DOT_HERE EQU $F2C5
Sound_Byte_raw EQU $F25B
Print_Str_yx EQU $F378
Intensity_5F EQU $F2A5
CHECK0REF EQU $F34F
VEC_EXPL_FLAG EQU $C867
MOV_DRAW_VLC_A EQU $F3AD
DELAY_B EQU $F57A
_CRYPT_LOGO_PATH33 EQU $0268
Dec_Counters EQU $F563
VEC_RFRSH_LO EQU $C83D
DELAY_1 EQU $F575
PLAY_MUSIC_RUNTIME EQU $423E
Vec_Str_Ptr EQU $C82C
_CRYPT_LOGO_PATH34 EQU $0271
ROT_VL_DFT EQU $F637
VEC_EXPL_3 EQU $C85A
AU_MUSIC_HAS_DELAY EQU $439F
_CRYPT_LOGO_PATH28 EQU $0238
DSWM_NO_NEGATE_DX EQU $4187
PSG_music_ended EQU $4303
Vec_Music_Flag EQU $C856
DELAY_RTS EQU $F57D
MOVETO_IX EQU $F310
Vec_Expl_ChanA EQU $C853
VEC_EXPL_TIMER EQU $C877
Vec_Joy_2_X EQU $C81D
AU_DONE EQU $43F3
Vec_Expl_Chans EQU $C854
ADD_SCORE_A EQU $F85E
VEC_BUTTON_1_3 EQU $C814
DRAW_PAT_VL_D EQU $F439
Init_Music EQU $F68D
VEC_SWI2_VECTOR EQU $CBF2
Draw_VLp_FF EQU $F404
Sound_Byte EQU $F256
MOV_DRAW_VL_AB EQU $F3B7
MOV_DRAW_VL EQU $F3BC
Draw_VL EQU $F3DD
VEC_NUM_GAME EQU $C87A
VEC_EXPL_4 EQU $C85B
DP_to_C8 EQU $F1AF
Rot_VL_Mode_a EQU $F61F
_CRYPT_LOGO_PATH32 EQU $025F
SFX_M_NOISE EQU $446B
Mov_Draw_VL_b EQU $F3B1
Draw_VLc EQU $F3CE
DSWM_NEXT_SET_INTENSITY EQU $41C2
DEC_3_COUNTERS EQU $F55A
VEC_MUSIC_WK_A EQU $C842
Vec_Max_Games EQU $C850
musicd EQU $FF8F
VEC_JOY_MUX EQU $C81F
MOVETO_D EQU $F312
VEC_STR_PTR EQU $C82C
Delay_RTS EQU $F57D
Dot_List_Reset EQU $F2DE
Moveto_ix_7F EQU $F30C
MUSIC7 EQU $FEC6
NEW_HIGH_SCORE EQU $F8D8
INIT_MUSIC_CHK EQU $F687
VEC_EXPL_CHANA EQU $C853
SOUND_BYTE EQU $F256
Abs_a_b EQU $F584
VEC_HIGH_SCORE EQU $CBEB
sfx_m_noise EQU $446B
DSWM_NEXT_NO_NEGATE_X EQU $41DB
Vec_Music_Ptr EQU $C853
PSG_process_event EQU $42B8
Sound_Byte_x EQU $F259
PRINT_LIST_CHK EQU $F38C
Init_VIA EQU $F14C
AUDIO_UPDATE EQU $4347
VEC_NMI_VECTOR EQU $CBFB
INIT_OS_RAM EQU $F164
PRINT_TEXT_STR_86053808672632355 EQU $44B4
DOT_LIST EQU $F2D5
Clear_C8_RAM EQU $F542
MOD16.M16_END EQU $40DA
Vec_0Ref_Enable EQU $C824
VEC_TEXT_WIDTH EQU $C82B
Vec_Counter_1 EQU $C82E
Mov_Draw_VL EQU $F3BC
VEC_BUTTON_2_3 EQU $C818
Intensity_7F EQU $F2A9
ROT_VL EQU $F616
VEC_MAX_PLAYERS EQU $C84F
VEC_DURATION EQU $C857
SFX_NEXTFRAME EQU $4480
MOV_DRAW_VL_A EQU $F3B9
Vec_IRQ_Vector EQU $CBF8
Dot_here EQU $F2C5
PRINT_STR_YX EQU $F378
MUSIC6 EQU $FE76
VEC_JOY_MUX_1_Y EQU $C820
Vec_FIRQ_Vector EQU $CBF5
_CRYPT_LOGO_PATH25 EQU $01FF
Vec_Music_Wk_1 EQU $C84B
UPDATE_MUSIC_PSG EQU $427F
DVB_PATH_LOOP EQU $4040
SFX_CHECKNOISEFREQ EQU $443F
PLAY_SFX_RUNTIME EQU $43FE
PSG_UPDATE_DONE EQU $431C
SFX_ENDOFEFFECT EQU $4485
Vec_Duration EQU $C857
Mov_Draw_VL_d EQU $F3BE
VEC_COLD_FLAG EQU $CBFE
Draw_Sync_List_At_With_Mirrors EQU $40EA
Vec_Expl_Timer EQU $C877
_CRYPT_LOGO_PATH5 EQU $00AC
Delay_0 EQU $F579
noay EQU $4411
MOD16.M16_DONE EQU $40E9
Xform_Run_a EQU $F65B
VEC_BUTTONS EQU $C811
Dec_6_Counters EQU $F55E
GET_RUN_IDX EQU $F5DB
Vec_Expl_4 EQU $C85B
VEC_MUSIC_WK_5 EQU $C847
_CRYPT_LOGO_PATH35 EQU $027A
Draw_Pat_VL EQU $F437
Dot_d EQU $F2C3
VEC_RFRSH EQU $C83D
_CRYPT_LOGO_PATH20 EQU $01A5
Vec_Joy_2_Y EQU $C81E
sfx_checkvolume EQU $4450
READ_BTNS_MASK EQU $F1B4
ROT_VL_AB EQU $F610
Get_Rise_Idx EQU $F5D9
CLEAR_X_B EQU $F53F
musicc EQU $FF7A
Vec_Joy_Mux_1_X EQU $C81F
Rise_Run_Len EQU $F603
SFX_CHECKTONEFREQ EQU $4425
_CRYPT_LOGO_PATH23 EQU $01E7
VEC_COUNTER_4 EQU $C831
Vec_Music_Twang EQU $C858
XFORM_RISE EQU $F663
PRINT_STR EQU $F495
sfx_nextframe EQU $4480
DSWM_NO_NEGATE_DY EQU $417D
Cold_Start EQU $F000
PSG_WRITE_LOOP EQU $42C9
MOVETO_IX_7F EQU $F30C
OBJ_WILL_HIT_U EQU $F8E5
DSWM_W1 EQU $415C
PRINT_LIST EQU $F38A
Vec_Num_Game EQU $C87A
NOAY EQU $4411
INIT_VIA EQU $F14C
WARM_START EQU $F06C
Vec_Expl_3 EQU $C85A
DSWM_NEXT_PATH EQU $41B0
MOVETO_IX_FF EQU $F308
JOY_DIGITAL EQU $F1F8
MOV_DRAW_VLCS EQU $F3B5
SFX_M_TONEDIS EQU $4469
Print_Str_hwyx EQU $F373
Delay_3 EQU $F56D
Mov_Draw_VL_ab EQU $F3B7
ABS_B EQU $F58B
VEC_FREQ_TABLE EQU $C84D
MOVE_MEM_A EQU $F683
SOUND_BYTES EQU $F27D
PSG_music_loop_d EQU $4314
DOT_IX EQU $F2C1
VEC_BUTTON_1_1 EQU $C812
sfx_m_write EQU $4478
CLEAR_X_B_A EQU $F552
PRINT_TEXT_STR_100361836 EQU $44A3
COLD_START EQU $F000
VEC_EXPL_CHANS EQU $C854
_CRYPT_LOGO_PATH14 EQU $0148
MOD16.M16_RCHECK EQU $40BB
Draw_Line_d EQU $F3DF
Vec_Rfrsh_lo EQU $C83D
Vec_SWI_Vector EQU $CBFB
Rot_VL_dft EQU $F637
_CRYPT_LOGO_PATH22 EQU $01DE
Vec_Expl_ChanB EQU $C85D
Draw_Grid_VL EQU $FF9F
PSG_MUSIC_ENDED EQU $4303
VEC_JOY_RESLTN EQU $C81A
PMR_START_NEW EQU $424C
VEC_JOY_MUX_1_X EQU $C81F
Intensity_a EQU $F2AB
DEC_COUNTERS EQU $F563
MOVETO_X_7F EQU $F2F2
Get_Rise_Run EQU $F5EF
INTENSITY_A EQU $F2AB
VEC_RISERUN_LEN EQU $C83B
MOVETO_IX_A EQU $F30E
VEC_EXPL_CHAN EQU $C85C
MUSIC5 EQU $FE38
Vec_Freq_Table EQU $C84D
_CRYPT_LOGO_PATH27 EQU $0220
VEC_SND_SHADOW EQU $C800
DRAW_VL_B EQU $F3D2
DRAW_VL_AB EQU $F3D8
Read_Btns EQU $F1BA
Vec_Random_Seed EQU $C87D
Draw_Pat_VL_a EQU $F434
DRAW_VLP_B EQU $F40E
PRINT_STR_D EQU $F37A
New_High_Score EQU $F8D8
DOT_IX_B EQU $F2BE
Vec_Counter_6 EQU $C833
VEC_MUSIC_WORK EQU $C83F
music2 EQU $FD1D
Rise_Run_Y EQU $F601
_CRYPT_LOGO_PATH4 EQU $0097
DVB_DONE EQU $4052
PSG_read_delay EQU $429D
Clear_x_b_a EQU $F552
Vec_Joy_Mux_2_X EQU $C821
Joy_Digital EQU $F1F8
Dot_List EQU $F2D5
MOD16.M16_LOOP EQU $40CA
VEC_BTN_STATE EQU $C80F
VECTOR_BANK_TABLE EQU $4000
AU_MUSIC_DONE EQU $43C6
sfx_checktonefreq EQU $4425
music8 EQU $FEF8
Vec_Btn_State EQU $C80F
VEC_MUSIC_FLAG EQU $C856
Vec_Text_Width EQU $C82B
_CRYPT_LOGO_PATH18 EQU $0178
DOT_D EQU $F2C3
Vec_Expl_2 EQU $C859
VEC_ANGLE EQU $C836
VEC_ADSR_TIMERS EQU $C85E
Reset0Ref EQU $F354
VEC_RISERUN_TMP EQU $C834
PSG_event_done EQU $42FA
Print_Str EQU $F495
Vec_SWI2_Vector EQU $CBF2
Vec_ADSR_Timers EQU $C85E
DO_SOUND EQU $F289
Vec_Snd_Shadow EQU $C800
AU_MUSIC_ENDED EQU $43CC
Moveto_d_7F EQU $F2FC
Recalibrate EQU $F2E6
PSG_MUSIC_LOOP EQU $4309
DSWM_SET_INTENSITY EQU $40F8
RISE_RUN_LEN EQU $F603
_CRYPT_LOGO_PATH12 EQU $0136
INIT_MUSIC_BUF EQU $F533
Random_3 EQU $F511
Vec_Music_Wk_5 EQU $C847
Sound_Bytes_x EQU $F284
MUSIC3 EQU $FD81
Vec_Joy_Resltn EQU $C81A
SFX_UPDATEMIXER EQU $4459
music9 EQU $FF26
VEC_RISE_INDEX EQU $C839
_CRYPT_LOGO_PATH11 EQU $011B
VEC_MUSIC_PTR EQU $C853
Delay_1 EQU $F575
Mov_Draw_VLc_a EQU $F3AD
Strip_Zeros EQU $F8B7


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "TEST BANKING"
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
DRAW_SCALE           EQU $C880+$38   ; Current T1 scale for Draw_Sync_List_At_With_Mirrors ($7F=normal) (1 bytes)
VAR_STATE            EQU $C880+$39   ; User variable: STATE (2 bytes)
VAR_BTN1             EQU $C880+$3B   ; User variable: BTN1 (2 bytes)
PSG_MUSIC_PTR        EQU $C880+$3D   ; PSG music data pointer (2 bytes)
PSG_MUSIC_START      EQU $C880+$3F   ; PSG music start pointer (for loops) (2 bytes)
PSG_MUSIC_ACTIVE     EQU $C880+$41   ; PSG music active flag (1 bytes)
PSG_IS_PLAYING       EQU $C880+$42   ; PSG playing flag (1 bytes)
PSG_DELAY_FRAMES     EQU $C880+$43   ; PSG frame delay counter (1 bytes)
PSG_MUSIC_BANK       EQU $C880+$44   ; PSG music bank ID (for multibank) (1 bytes)
SFX_PTR              EQU $C880+$45   ; SFX data pointer (2 bytes)
SFX_ACTIVE           EQU $C880+$47   ; SFX active flag (1 bytes)
SFX_BANK             EQU $C880+$48   ; SFX bank ID (for multibank) (1 bytes)
VAR_ARG0             EQU $C880+$49   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $C880+$4B   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $C880+$4D   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $C880+$4F   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $C880+$51   ; Function argument 4 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $C880+$53   ; Current ROM bank ID (multibank tracking) (1 bytes)

;***************************************************************************
; MAIN PROGRAM (Bank #0)
;***************************************************************************

MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    LDA #$7F
    STA DRAW_SCALE        ; Default T1 scale = $7F (127 = full BIOS scale)
    LDD #0
    STD VAR_STATE
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
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed
    BITA #$01
    LBNE .J1B1_0_ON
    LDD #0
    LBRA .J1B1_0_END
.J1B1_0_ON:
    LDD #1
.J1B1_0_END:
    STD RESULT
    STD VAR_BTN1
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN1
    CMPD TMPVAL
    LBEQ .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_1
    LDD #1
    STD VAR_STATE
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_STATE
    CMPD TMPVAL
    LBEQ .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    LBEQ IF_NEXT_3
    ; PLAY_MUSIC("intro") - play music asset (index=1)
    LDX #1        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: crypt_logo (index=0, 40 paths)
    LDD #0
    TFR B,A       ; X position (low byte) — B already holds it
    STA TMPPTR    ; Save X to temporary storage
    LDD #10
    TFR B,A       ; Y position (low byte) — B already holds it
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #0        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_STATE
    CMPD TMPVAL
    LBEQ .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    LBEQ IF_NEXT_5
    ; PLAY_MUSIC("exploration") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: crypt_logo (index=0, 40 paths)
    LDD #0
    TFR B,A       ; X position (low byte) — B already holds it
    STA TMPPTR    ; Save X to temporary storage
    LDD #10
    TFR B,A       ; Y position (low byte) — B already holds it
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #0        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX (after all game logic)
    RTS


; ================================================
