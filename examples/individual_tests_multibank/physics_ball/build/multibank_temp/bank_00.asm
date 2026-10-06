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
SLR_CUR_X            EQU $C880+$24   ; DRAW_VECTOR: clamped (visible) beam X for clipping (1 bytes)
SLR_TRUE_X           EQU $C880+$25   ; DRAW_VECTOR: 16-bit unclamped abs_x for line clipping (2 bytes)
DRAW_T1_SCALED       EQU $C880+$27   ; DRAW_VECTOR: T1 scale ($7F default for non-SHOW_LEVEL) (1 bytes)
SDCP_ABS_Y           EQU $C880+$28   ; DRAW_VECTOR: abs_y temporary for SDCP (cannot share TMPVAL — would corrupt SHOW_LEVEL's top_screen between layers) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$29   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$33   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$35   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$37   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$38   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$39   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$3B   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$3D   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$3E   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
DRAW_SCALE           EQU $C880+$3F   ; Current T1 scale for Draw_Sync_List_At_With_Mirrors ($7F=normal) (1 bytes)
VAR_ARG0             EQU $C880+$40   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $C880+$42   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $C880+$44   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $C880+$46   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $C880+$48   ; Function argument 4 (16-bit) (2 bytes)
VAR_ARG5             EQU $C880+$4A   ; Function argument 5 (16-bit) (2 bytes)
VAR_ARG6             EQU $C880+$4C   ; Function argument 6 (16-bit) (2 bytes)
VAR_ARG7             EQU $C880+$4E   ; Function argument 7 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $C880+$50   ; Current ROM bank ID (multibank tracking) (1 bytes)
VAR_BX               EQU $C880+$51   ; User variable: BX (2 bytes)
VAR_BY               EQU $C880+$53   ; User variable: BY (2 bytes)
VAR_VX               EQU $C880+$55   ; User variable: VX (2 bytes)
VAR_VY               EQU $C880+$57   ; User variable: VY (2 bytes)
VAR_JX               EQU $C880+$59   ; User variable: JX (2 bytes)
PSG_MUSIC_PTR        EQU $C880+$5B   ; PSG music data pointer (2 bytes)
PSG_MUSIC_START      EQU $C880+$5D   ; PSG music start pointer (for loops) (2 bytes)
PSG_MUSIC_ACTIVE     EQU $C880+$5F   ; PSG music active flag (1 bytes)
PSG_IS_PLAYING       EQU $C880+$60   ; PSG playing flag (1 bytes)
PSG_DELAY_FRAMES     EQU $C880+$61   ; PSG frame delay counter (1 bytes)
PSG_MUSIC_BANK       EQU $C880+$62   ; PSG music bank ID (for multibank) (1 bytes)
SFX_PTR              EQU $C880+$63   ; SFX data pointer (2 bytes)
SFX_ACTIVE           EQU $C880+$65   ; SFX active flag (1 bytes)
SFX_BANK             EQU $C880+$66   ; SFX bank ID (for multibank) (1 bytes)


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
ASSET_ADDR_TABLE EQU $4010
ASSET_BANK_TABLE EQU $400C
AUDIO_UPDATE EQU $465A
AU_BANK_OK EQU $4674
AU_DONE EQU $4718
AU_MUSIC_DONE EQU $46EB
AU_MUSIC_ENDED EQU $46F1
AU_MUSIC_HAS_DELAY EQU $46B2
AU_MUSIC_LOOP EQU $46F7
AU_MUSIC_NO_DELAY EQU $46A3
AU_MUSIC_PROCESS_WRITES EQU $46C0
AU_MUSIC_READ EQU $4692
AU_MUSIC_READ_COUNT EQU $46A3
AU_MUSIC_WRITE_LOOP EQU $46C2
AU_SKIP_MUSIC EQU $4702
AU_UPDATE_SFX EQU $4705
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
DEC_3_COUNTERS EQU $F55A
DEC_6_COUNTERS EQU $F55E
DEC_COUNTERS EQU $F563
DELAY_0 EQU $F579
DELAY_1 EQU $F575
DELAY_2 EQU $F571
DELAY_3 EQU $F56D
DELAY_B EQU $F57A
DELAY_RTS EQU $F57D
DLW_DONE EQU $428D
DLW_NEED_SEG2 EQU $4237
DLW_SEG1_DX_LO EQU $41EF
DLW_SEG1_DX_NO_CLAMP EQU $41FC
DLW_SEG1_DX_READY EQU $41FF
DLW_SEG1_DY_LO EQU $41CC
DLW_SEG1_DY_NO_CLAMP EQU $41D9
DLW_SEG1_DY_READY EQU $41DC
DLW_SEG2_DX_CHECK_NEG EQU $426D
DLW_SEG2_DX_DONE EQU $427E
DLW_SEG2_DX_NO_REMAIN EQU $427B
DLW_SEG2_DY_DONE EQU $4259
DLW_SEG2_DY_NO_REMAIN EQU $4250
DLW_SEG2_DY_POS EQU $4256
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
DRAW_GRID_VL EQU $FF9F
DRAW_LINE_D EQU $F3DF
DRAW_LINE_WRAPPER EQU $418A
DRAW_PAT_VL EQU $F437
DRAW_PAT_VL_A EQU $F434
DRAW_PAT_VL_D EQU $F439
DRAW_SYNC_LIST_AT_WITH_MIRRORS EQU $4292
DRAW_VECTOR_BANKED EQU $4018
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
DSWM_DONE EQU $43E5
DSWM_LOOP EQU $430D
DSWM_NEXT_NO_NEGATE_X EQU $4383
DSWM_NEXT_NO_NEGATE_Y EQU $4376
DSWM_NEXT_PATH EQU $4358
DSWM_NEXT_SET_INTENSITY EQU $436A
DSWM_NEXT_USE_OVERRIDE EQU $4368
DSWM_NO_NEGATE_DX EQU $432F
DSWM_NO_NEGATE_DY EQU $4325
DSWM_NO_NEGATE_X EQU $42BA
DSWM_NO_NEGATE_Y EQU $42AD
DSWM_SET_INTENSITY EQU $42A0
DSWM_USE_OVERRIDE EQU $429E
DSWM_W1 EQU $4304
DSWM_W2 EQU $4346
DSWM_W3 EQU $43D9
DVB_CHECK_POS EQU $4067
DVB_DONE EQU $4082
DVB_PATH_AFTER EQU $4077
DVB_PATH_LOOP EQU $404B
DVB_USE_DSWM EQU $4074
DVB_USE_SDCP EQU $406E
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
Draw_Sync_List_At_With_Mirrors EQU $4292
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
J1X_BUILTIN EQU $4182
JOY_ANALOG EQU $F1F5
JOY_DIGITAL EQU $F1F8
Joy_Analog EQU $F1F5
Joy_Digital EQU $F1F8
MOD16 EQU $412E
MOD16.M16_DONE EQU $4181
MOD16.M16_DPOS EQU $414B
MOD16.M16_END EQU $4172
MOD16.M16_LOOP EQU $4162
MOD16.M16_RCHECK EQU $4153
MOD16.M16_RPOS EQU $4162
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
MUSIC_ADDR_TABLE EQU $4004
MUSIC_BANK_TABLE EQU $4003
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
NOAY EQU $4736
New_High_Score EQU $F8D8
OBJ_HIT EQU $F8FF
OBJ_WILL_HIT EQU $F8F3
OBJ_WILL_HIT_U EQU $F8E5
Obj_Hit EQU $F8FF
Obj_Will_Hit EQU $F8F3
Obj_Will_Hit_u EQU $F8E5
PLAY_MUSIC_BANKED EQU $408E
PLAY_MUSIC_RUNTIME EQU $453C
PLAY_SFX_BANKED EQU $40C6
PLAY_SFX_RUNTIME EQU $4723
PMR_DONE EQU $457C
PMR_START_NEW EQU $454A
PMr_done EQU $457C
PMr_start_new EQU $454A
PRINT_LIST EQU $F38A
PRINT_LIST_CHK EQU $F38C
PRINT_LIST_HW EQU $F385
PRINT_SHIPS EQU $F393
PRINT_SHIPS_X EQU $F391
PRINT_STR EQU $F495
PRINT_STR_D EQU $F37A
PRINT_STR_HWYX EQU $F373
PRINT_STR_YX EQU $F378
PRINT_TEXT_STR_103315 EQU $47C8
PRINT_TEXT_STR_3232159404 EQU $47D1
PRINT_TEXT_STR_3273774 EQU $47CC
PRINT_TEXT_STR_60036694812 EQU $47D8
PRINT_TEXT_STR_6459777946950754952 EQU $47E8
PRINT_TEXT_STR_73146331687 EQU $47E0
PSG_EVENT_DONE EQU $45F8
PSG_MUSIC_ENDED EQU $4601
PSG_MUSIC_LOOP EQU $461C
PSG_MUSIC_LOOP_D EQU $4627
PSG_PROCESS_EVENT EQU $45B6
PSG_READ_DELAY EQU $459B
PSG_UPDATE_DONE EQU $462F
PSG_WRITE_LOOP EQU $45C7
PSG_event_done EQU $45F8
PSG_music_ended EQU $4601
PSG_music_loop EQU $461C
PSG_music_loop_d EQU $4627
PSG_process_event EQU $45B6
PSG_read_delay EQU $459B
PSG_update_done EQU $462F
PSG_write_loop EQU $45C7
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
SDCP_DONE EQU $453B
SDCP_INIT_NEG_OK EQU $4422
SDCP_INIT_POS EQU $442D
SDCP_MOVETO_W EQU $4480
SDCP_SEG_CLAMPED EQU $44CD
SDCP_SEG_CLAMP_LEFT EQU $44B7
SDCP_SEG_DRAW EQU $44EB
SDCP_SEG_LOOP EQU $4489
SDCP_SEG_NEG_OK EQU $44BC
SDCP_SEG_OFF_X EQU $4514
SDCP_SEG_POS EQU $44C7
SDCP_SET_INTENS EQU $43F4
SDCP_USE_CLAMPED EQU $4433
SDCP_USE_OVERRIDE EQU $43F2
SDCP_W_DRAW EQU $4505
SDCP_W_OFF_X EQU $452F
SELECT_GAME EQU $F7A9
SET_REFRESH EQU $F1A2
SFX_ADDR_TABLE EQU $4008
SFX_BANK_TABLE EQU $4006
SFX_CHECKNOISEFREQ EQU $4764
SFX_CHECKTONEFREQ EQU $474A
SFX_CHECKVOLUME EQU $4775
SFX_DOFRAME EQU $4737
SFX_ENDOFEFFECT EQU $47AA
SFX_M_NOISE EQU $4790
SFX_M_NOISEDIS EQU $479B
SFX_M_TONEDIS EQU $478E
SFX_M_WRITE EQU $479D
SFX_NEXTFRAME EQU $47A5
SFX_UPDATE EQU $472C
SFX_UPDATEMIXER EQU $477E
SLR_DRAW_CLIPPED_PATH EQU $43E6
SOUND_BYTE EQU $F256
SOUND_BYTES EQU $F27D
SOUND_BYTES_X EQU $F284
SOUND_BYTE_RAW EQU $F25B
SOUND_BYTE_X EQU $F259
STOP_MUSIC_RUNTIME EQU $4633
STRIP_ZEROS EQU $F8B7
Select_Game EQU $F7A9
Set_Refresh EQU $F1A2
Sound_Byte EQU $F256
Sound_Byte_raw EQU $F25B
Sound_Byte_x EQU $F259
Sound_Bytes EQU $F27D
Sound_Bytes_x EQU $F284
Strip_Zeros EQU $F8B7
UPDATE_MUSIC_PSG EQU $457D
VECTOR_ADDR_TABLE EQU $4001
VECTOR_BANK_TABLE EQU $4000
VECTREX_PRINT_TEXT EQU $40F4
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
_BUBBLE_MEDIUM_PATH0 EQU $023F
_BUBBLE_MEDIUM_VECTORS EQU $023B
_MUSIC1_MUSIC EQU $0000
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
noay EQU $4736
sfx_checknoisefreq EQU $4764
sfx_checktonefreq EQU $474A
sfx_checkvolume EQU $4775
sfx_doframe EQU $4737
sfx_endofeffect EQU $47AA
sfx_m_noise EQU $4790
sfx_m_noisedis EQU $479B
sfx_m_tonedis EQU $478E
sfx_m_write EQU $479D
sfx_nextframe EQU $47A5
sfx_updatemixer EQU $477E


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
SLR_CUR_X            EQU $C880+$24   ; DRAW_VECTOR: clamped (visible) beam X for clipping (1 bytes)
SLR_TRUE_X           EQU $C880+$25   ; DRAW_VECTOR: 16-bit unclamped abs_x for line clipping (2 bytes)
DRAW_T1_SCALED       EQU $C880+$27   ; DRAW_VECTOR: T1 scale ($7F default for non-SHOW_LEVEL) (1 bytes)
SDCP_ABS_Y           EQU $C880+$28   ; DRAW_VECTOR: abs_y temporary for SDCP (cannot share TMPVAL — would corrupt SHOW_LEVEL's top_screen between layers) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$29   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$33   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$35   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$37   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$38   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$39   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$3B   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$3D   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$3E   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
DRAW_SCALE           EQU $C880+$3F   ; Current T1 scale for Draw_Sync_List_At_With_Mirrors ($7F=normal) (1 bytes)
VAR_ARG0             EQU $C880+$40   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $C880+$42   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $C880+$44   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $C880+$46   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $C880+$48   ; Function argument 4 (16-bit) (2 bytes)
VAR_ARG5             EQU $C880+$4A   ; Function argument 5 (16-bit) (2 bytes)
VAR_ARG6             EQU $C880+$4C   ; Function argument 6 (16-bit) (2 bytes)
VAR_ARG7             EQU $C880+$4E   ; Function argument 7 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $C880+$50   ; Current ROM bank ID (multibank tracking) (1 bytes)
VAR_BX               EQU $C880+$51   ; User variable: BX (2 bytes)
VAR_BY               EQU $C880+$53   ; User variable: BY (2 bytes)
VAR_VX               EQU $C880+$55   ; User variable: VX (2 bytes)
VAR_VY               EQU $C880+$57   ; User variable: VY (2 bytes)
VAR_JX               EQU $C880+$59   ; User variable: JX (2 bytes)
PSG_MUSIC_PTR        EQU $C880+$5B   ; PSG music data pointer (2 bytes)
PSG_MUSIC_START      EQU $C880+$5D   ; PSG music start pointer (for loops) (2 bytes)
PSG_MUSIC_ACTIVE     EQU $C880+$5F   ; PSG music active flag (1 bytes)
PSG_IS_PLAYING       EQU $C880+$60   ; PSG playing flag (1 bytes)
PSG_DELAY_FRAMES     EQU $C880+$61   ; PSG frame delay counter (1 bytes)
PSG_MUSIC_BANK       EQU $C880+$62   ; PSG music bank ID (for multibank) (1 bytes)
SFX_PTR              EQU $C880+$63   ; SFX data pointer (2 bytes)
SFX_ACTIVE           EQU $C880+$65   ; SFX active flag (1 bytes)
SFX_BANK             EQU $C880+$66   ; SFX bank ID (for multibank) (1 bytes)

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
    LDA #$7F
    STA DRAW_SCALE        ; Default T1 scale = $7F (127 = full BIOS scale)
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
; VPy_LINE:18
; NATIVE_CALL: PLAY_MUSIC at line 18
    ; PLAY_MUSIC("music1") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
; VPy_LINE:19
    LDD #0
    STD VAR_BX
; VPy_LINE:20
    LDD #60
    STD VAR_BY
; VPy_LINE:21
    LDD #1
    STD VAR_VX
; VPy_LINE:22
    LDD #0
    STD VAR_VY

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    JSR $F1AA    ; DP_to_D0 (Joy_Analog requires DP=$D0)
    JSR $F1F5    ; Joy_Analog: poll all 4 axes once → $C81B-$C81E
    JSR Reset0Ref ; Restore beam state after Joy_Analog
    JSR $F1AF    ; DP_to_C8 (restore DP for RAM access)
; VPy_LINE:25
; NATIVE_CALL: PRINT_TEXT at line 25
    ; PRINT_TEXT: Print text at position
    LDD #-50
    STD >VAR_ARG0
    LDD #100
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_73146331687      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:26
; NATIVE_CALL: PRINT_TEXT at line 26
    ; PRINT_TEXT: Print text at position
    LDD #-50
    STD >VAR_ARG0
    LDD #85
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_60036694812      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:29
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_VY
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_VY
; VPy_LINE:32
; NATIVE_CALL: J1_X at line 32
    JSR J1X_BUILTIN
    STD RESULT
    STD VAR_JX
; VPy_LINE:33
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
; VPy_LINE:34
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_VX
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_VX
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
; VPy_LINE:35
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
; VPy_LINE:36
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_VX
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_VX
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
; VPy_LINE:39
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
; VPy_LINE:40
    LDD #8
    STD VAR_VY
; VPy_LINE:41
; NATIVE_CALL: PLAY_SFX at line 41
    ; PLAY_SFX("jump") - play SFX asset (index=1)
    LDX #1        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
; VPy_LINE:44
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
; VPy_LINE:45
    LDD #6
    STD VAR_VX
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
; VPy_LINE:46
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
; VPy_LINE:47
    LDD #-6
    STD VAR_VX
    LBRA IF_END_8
IF_NEXT_9:
IF_END_8:
; VPy_LINE:50
    LDD >VAR_VX
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_BX
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_BX
; VPy_LINE:51
    LDD >VAR_VY
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_BY
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_BY
; VPy_LINE:54
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
; VPy_LINE:55
    LDD #-90
    STD VAR_BY
; VPy_LINE:56
    LDD >VAR_VY
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #0
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_VY
; VPy_LINE:57
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
; VPy_LINE:58
    LDD #12
    STD VAR_VY
    LBRA IF_END_12
IF_NEXT_13:
IF_END_12:
; VPy_LINE:59
; NATIVE_CALL: PLAY_SFX at line 59
    ; PLAY_SFX("hit") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_10
IF_NEXT_11:
IF_END_10:
; VPy_LINE:62
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
; VPy_LINE:63
    LDD #90
    STD VAR_BY
; VPy_LINE:64
    LDD >VAR_VY
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #0
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_VY
    LBRA IF_END_14
IF_NEXT_15:
IF_END_14:
; VPy_LINE:67
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
; VPy_LINE:68
    LDD #100
    STD VAR_BX
; VPy_LINE:69
    LDD >VAR_VX
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #0
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_VX
; VPy_LINE:70
; NATIVE_CALL: PLAY_SFX at line 70
    ; PLAY_SFX("hit") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_16
IF_NEXT_17:
IF_END_16:
; VPy_LINE:72
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
; VPy_LINE:73
    LDD #-100
    STD VAR_BX
; VPy_LINE:74
    LDD >VAR_VX
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #0
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_VX
; VPy_LINE:75
; NATIVE_CALL: PLAY_SFX at line 75
    ; PLAY_SFX("hit") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_18
IF_NEXT_19:
IF_END_18:
; VPy_LINE:78
; NATIVE_CALL: DRAW_VECTOR at line 78
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bubble_medium (index=0, 1 paths)
    LDD >VAR_BX
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_1          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_BY
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    LBPL .sx_pos_1
    LDB #$FF
.sx_pos_1:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #0        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_1:
    LDD #0
    STD RESULT
; VPy_LINE:81
; NATIVE_CALL: DRAW_LINE at line 81
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
