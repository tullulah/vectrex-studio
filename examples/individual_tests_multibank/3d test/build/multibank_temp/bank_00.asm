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
ROT3D_AX             EQU $C880+$24   ; 3D raw angle X (0-127) (1 bytes)
ROT3D_AY             EQU $C880+$25   ; 3D raw angle Y (0-127) (1 bytes)
ROT3D_AZ             EQU $C880+$26   ; 3D raw angle Z (0-127) (1 bytes)
ROT3D_SIN_X          EQU $C880+$27   ; 3D rotation sin(ax) i8 (1 bytes)
ROT3D_COS_X          EQU $C880+$28   ; 3D rotation cos(ax) i8 (1 bytes)
ROT3D_SIN_Y          EQU $C880+$29   ; 3D rotation sin(ay) i8 (1 bytes)
ROT3D_COS_Y          EQU $C880+$2A   ; 3D rotation cos(ay) i8 (1 bytes)
ROT3D_SIN_Z          EQU $C880+$2B   ; 3D rotation sin(az) i8 (1 bytes)
ROT3D_COS_Z          EQU $C880+$2C   ; 3D rotation cos(az) i8 (1 bytes)
ROT3D_OX             EQU $C880+$2D   ; 3D draw X offset (1 bytes)
ROT3D_OY             EQU $C880+$2E   ; 3D draw Y offset (1 bytes)
ROT3D_PC             EQU $C880+$2F   ; 3D path count remaining (1 bytes)
ROT3D_PT_TOTAL       EQU $C880+$30   ; 3D total points in path (1 bytes)
ROT3D_PT_REM         EQU $C880+$31   ; 3D remaining points (1 bytes)
ROT3D_CLOSED         EQU $C880+$32   ; 3D path closed flag (1 bytes)
ROT3D_RX             EQU $C880+$33   ; 3D raw x (1 bytes)
ROT3D_RY             EQU $C880+$34   ; 3D raw y (1 bytes)
ROT3D_RZ             EQU $C880+$35   ; 3D raw z (1 bytes)
ROT3D_Y1             EQU $C880+$36   ; 3D intermediate y after X-axis rotation (1 bytes)
ROT3D_Z1             EQU $C880+$37   ; 3D intermediate z after X-axis rotation (1 bytes)
ROT3D_X2             EQU $C880+$38   ; 3D intermediate x after Y-axis rotation (1 bytes)
ROT3D_SCR_X          EQU $C880+$39   ; 3D final screen x (1 bytes)
ROT3D_SCR_Y          EQU $C880+$3A   ; 3D final screen y (1 bytes)
ROT3D_PREV_X         EQU $C880+$3B   ; 3D previous screen x (1 bytes)
ROT3D_PREV_Y         EQU $C880+$3C   ; 3D previous screen y (1 bytes)
ROT3D_FIRST_X        EQU $C880+$3D   ; 3D first screen x (for closed path) (1 bytes)
ROT3D_FIRST_Y        EQU $C880+$3E   ; 3D first screen y (for closed path) (1 bytes)
ROT3D_SIGN           EQU $C880+$3F   ; SMUL8 sign tracking byte (1 bytes)
ROT3D_TEMP           EQU $C880+$40   ; 3D rotation temp 1 (1 bytes)
ROT3D_TEMP2          EQU $C880+$41   ; 3D rotation temp 2 (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$42   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$4C   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$4E   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$50   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$51   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$52   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$54   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
VAR_ANGLE_X          EQU $C880+$56   ; User variable: ANGLE_X (2 bytes)
VAR_ANGLE_Y          EQU $C880+$58   ; User variable: ANGLE_Y (2 bytes)
VAR_ANGLE_Z          EQU $C880+$5A   ; User variable: ANGLE_Z (2 bytes)
VAR_ARG0             EQU $CB80   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $CB82   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $CB84   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $CB86   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $CB88   ; Function argument 4 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $CB8A   ; Current ROM bank ID (multibank tracking) (1 bytes)


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
Abs_b EQU $F58B
_BENCHY_PATH57 EQU $030B
Draw_VLc EQU $F3CE
_BENCHY_PATH74 EQU $03A4
RANDOM EQU $F517
Vec_Text_HW EQU $C82A
_BENCHY_PATH1 EQU $0113
Obj_Hit EQU $F8FF
_BENCHY_PATH122 EQU $0554
VEC_EXPL_CHANB EQU $C85D
VEC_EXPL_CHANA EQU $C853
Dec_3_Counters EQU $F55A
VEC_RFRSH_HI EQU $C83E
_BENCHY_PATH16 EQU $019A
Vec_Expl_1 EQU $C858
CLEAR_SCORE EQU $F84F
VEC_EXPL_2 EQU $C859
Vec_Rfrsh_lo EQU $C83D
ROT_VL_MODE EQU $F62B
DP_to_C8 EQU $F1AF
Draw_Line_d EQU $F3DF
Mov_Draw_VLcs EQU $F3B5
DRAW_VL_MODE EQU $F46E
Check0Ref EQU $F34F
_BENCHY_PATH43 EQU $028D
Vec_Twang_Table EQU $C851
Xform_Run_a EQU $F65B
MOVETO_D EQU $F312
Vec_Num_Game EQU $C87A
Draw_Pat_VL EQU $F437
Draw_VL_a EQU $F3DA
_BENCHY_PATH22 EQU $01D0
Mov_Draw_VL_d EQU $F3BE
VEC_BUTTON_2_3 EQU $C818
VEC_NUM_GAME EQU $C87A
_BENCHY_PATH50 EQU $02CC
INTENSITY_A EQU $F2AB
_BENCHY_PATH51 EQU $02D5
ADD_SCORE_D EQU $F87C
Get_Rise_Run EQU $F5EF
INTENSITY_3F EQU $F2A1
VEC_COUNTER_5 EQU $C832
XFORM_RUN EQU $F65D
MOVETO_D_7F EQU $F2FC
_BENCHY_PATH37 EQU $0257
_BENCHY_PATH117 EQU $0527
RESET0REF_D0 EQU $F34A
_BENCHY_PATH103 EQU $04A9
_BENCHY_PATH116 EQU $051E
VEC_COUNTER_2 EQU $C82F
Draw_Pat_VL_a EQU $F434
VEC_MUSIC_WK_1 EQU $C84B
VEC_BUTTON_1_1 EQU $C812
_BENCHY_PATH128 EQU $058A
DRAW_VECTOR_3D_RUNTIME EQU $42C2
Vec_Snd_Shadow EQU $C800
Init_OS EQU $F18B
RISE_RUN_X EQU $F5FF
Add_Score_d EQU $F87C
VEC_HIGH_SCORE EQU $CBEB
musicb EQU $FF62
_BENCHY_PATH118 EQU $0530
Compare_Score EQU $F8C7
MUSIC8 EQU $FEF8
DOT_LIST_RESET EQU $F2DE
VEC_ADSR_TABLE EQU $C84F
_BENCHY_PATH93 EQU $044F
_BENCHY_PATH5 EQU $0137
VEC_NMI_VECTOR EQU $CBFB
INIT_MUSIC_BUF EQU $F533
Clear_x_d EQU $F548
Vec_Duration EQU $C857
ROT_VL_DFT EQU $F637
VEC_LOOP_COUNT EQU $C825
CLEAR_X_D EQU $F548
_BENCHY_PATH18 EQU $01AC
_BENCHY_PATH90 EQU $0434
Vec_Button_1_4 EQU $C815
DELAY_B EQU $F57A
STRIP_ZEROS EQU $F8B7
_BENCHY_PATH106 EQU $04C4
TAN_TABLE EQU $4614
VEC_EXPL_CHANS EQU $C854
Init_VIA EQU $F14C
VEC_BUTTON_2_1 EQU $C816
music6 EQU $FE76
VEC_DEFAULT_STK EQU $CBEA
PRINT_TEXT_STR_2902307913 EQU $4714
Clear_x_b EQU $F53F
_BENCHY_PATH3 EQU $0125
_BENCHY_PATH2 EQU $011C
Moveto_ix_a EQU $F30E
DRAW_VL_B EQU $F3D2
VEC_TEXT_WIDTH EQU $C82B
Clear_x_b_a EQU $F552
MOV_DRAW_VL_AB EQU $F3B7
_BENCHY_PATH94 EQU $0458
Strip_Zeros EQU $F8B7
_BENCHY_PATH55 EQU $02F9
VEC_JOY_2_Y EQU $C81E
VEC_MUSIC_PTR EQU $C853
DSWM_W3 EQU $41F5
_BENCHY_PATH11 EQU $016D
Reset0Ref_D0 EQU $F34A
PRINT_LIST_CHK EQU $F38C
DELAY_RTS EQU $F57D
CLEAR_SOUND EQU $F272
Vec_Music_Wk_1 EQU $C84B
VEC_BTN_STATE EQU $C80F
Xform_Rise_a EQU $F661
Print_Ships EQU $F393
MOVETO_IX_7F EQU $F30C
Vec_Button_2_2 EQU $C817
Vec_Expl_ChanB EQU $C85D
Clear_x_256 EQU $F545
VEC_RISERUN_LEN EQU $C83B
Moveto_ix EQU $F310
DVB_DONE EQU $404F
Vec_0Ref_Enable EQU $C824
DRAW_PAT_VL EQU $F437
DSWM_DONE EQU $4201
_BENCHY_PATH81 EQU $03E3
_BENCHY_PATH92 EQU $0446
Vec_RiseRun_Tmp EQU $C834
_BENCHY_PATH13 EQU $017F
Random_3 EQU $F511
_BENCHY_PATH15 EQU $0191
Vec_Prev_Btns EQU $C810
DRAW_SYNC_LIST_AT_WITH_MIRRORS EQU $40AF
INIT_MUSIC_CHK EQU $F687
_BENCHY_PATH95 EQU $0461
Joy_Digital EQU $F1F8
DP_to_D0 EQU $F1AA
MUSICA EQU $FF44
Print_List_chk EQU $F38C
Print_Str_hwyx EQU $F373
Vec_Rfrsh EQU $C83D
_BENCHY_PATH24 EQU $01E2
DRAW_VLP_SCALE EQU $F40C
_BENCHY_PATH38 EQU $0260
DOT_IX_B EQU $F2BE
OBJ_WILL_HIT EQU $F8F3
VEC_RUN_INDEX EQU $C837
_BENCHY_PATH87 EQU $0419
PRINT_LIST_HW EQU $F385
Vec_Run_Index EQU $C837
_BENCHY_PATH65 EQU $0353
MOD16.M16_END EQU $409F
music2 EQU $FD1D
_BENCHY_PATH68 EQU $036E
PRINT_SHIPS EQU $F393
Print_Str_d EQU $F37A
MOD16.M16_DONE EQU $40AE
INIT_MUSIC_X EQU $F692
_BENCHY_3D_DATA EQU $471B
XFORM_RISE_A EQU $F661
music4 EQU $FDD3
_BENCHY_PATH42 EQU $0284
DSWM_LOOP EQU $412B
ABS_B EQU $F58B
Mov_Draw_VL EQU $F3BC
DV3D_ROTATE EQU $4228
_BENCHY_PATH4 EQU $012E
DV3D_PATH_LOOP EQU $433C
DRAW_GRID_VL EQU $FF9F
_BENCHY_PATH12 EQU $0176
Vec_NMI_Vector EQU $CBFB
MOVETO_IX_A EQU $F30E
Xform_Rise EQU $F663
Vec_Text_Height EQU $C82A
Clear_Sound EQU $F272
Vec_Joy_Mux_2_Y EQU $C822
VEC_MISC_COUNT EQU $C823
Reset0Ref EQU $F354
MOD16 EQU $405B
VEC_ANGLE EQU $C836
Vec_Dot_Dwell EQU $C828
SOUND_BYTE_RAW EQU $F25B
MOVETO_IX_FF EQU $F308
NEW_HIGH_SCORE EQU $F8D8
ROT_VL_AB EQU $F610
musicd EQU $FF8F
Clear_x_b_80 EQU $F550
_BENCHY_PATH10 EQU $0164
VEC_MUSIC_FREQ EQU $C861
Vec_Rfrsh_hi EQU $C83E
MOV_DRAW_VL EQU $F3BC
DSWM_NEXT_NO_NEGATE_X EQU $4192
_BENCHY_PATH91 EQU $043D
WAIT_RECAL EQU $F192
Vec_Music_Flag EQU $C856
MUSIC7 EQU $FEC6
GET_RISE_IDX EQU $F5D9
Vec_Cold_Flag EQU $CBFE
VEC_STR_PTR EQU $C82C
VEC_EXPL_TIMER EQU $C877
Rot_VL_ab EQU $F610
Init_Music_Buf EQU $F533
Delay_3 EQU $F56D
music7 EQU $FEC6
Vec_Max_Games EQU $C850
_BENCHY_PATH109 EQU $04DF
Dot_ix_b EQU $F2BE
_BENCHY_PATH121 EQU $054B
_BENCHY_PATH6 EQU $0140
Init_Music_x EQU $F692
Vec_Music_Wk_6 EQU $C846
_BENCHY_PATH8 EQU $0152
Rise_Run_Angle EQU $F593
_BENCHY_PATH129 EQU $0593
music5 EQU $FE38
Get_Run_Idx EQU $F5DB
_BENCHY_PATH114 EQU $050C
music3 EQU $FD81
DSWM_W2 EQU $4164
DRAW_VL EQU $F3DD
VEC_JOY_MUX_1_X EQU $C81F
_BENCHY_PATH76 EQU $03B6
Moveto_ix_FF EQU $F308
GET_RUN_IDX EQU $F5DB
_BENCHY_PATH99 EQU $0485
INTENSITY_5F EQU $F2A5
Print_Str EQU $F495
Rise_Run_Y EQU $F601
VEC_BRIGHTNESS EQU $C827
_BENCHY_PATH33 EQU $0233
Dec_Counters EQU $F563
Vec_Default_Stk EQU $CBEA
Rot_VL_dft EQU $F637
music9 EQU $FF26
_BENCHY_PATH44 EQU $0296
Vec_Joy_Mux_1_Y EQU $C820
MOD16.M16_RPOS EQU $408F
Sound_Byte_x EQU $F259
MUSIC4 EQU $FDD3
_BENCHY_PATH130 EQU $059C
VEC_MUSIC_WORK EQU $C83F
Vec_SWI2_Vector EQU $CBF2
Vec_Random_Seed EQU $C87D
Vec_Text_Width EQU $C82B
Reset0Int EQU $F36B
Vec_Joy_Mux_1_X EQU $C81F
RECALIBRATE EQU $F2E6
VEC_FREQ_TABLE EQU $C84D
Do_Sound_x EQU $F28C
VEC_0REF_ENABLE EQU $C824
JOY_DIGITAL EQU $F1F8
_BENCHY_PATH82 EQU $03EC
MOVE_MEM_A EQU $F683
_BENCHY_PATH108 EQU $04D6
SMUL8_END EQU $4227
_BENCHY_PATH126 EQU $0578
INTENSITY_1F EQU $F29D
_BENCHY_PATH46 EQU $02A8
RISE_RUN_Y EQU $F601
Vec_SWI3_Vector EQU $CBF2
SMUL8_BP EQU $4217
Read_Btns_Mask EQU $F1B4
Obj_Will_Hit EQU $F8F3
Vec_Expl_4 EQU $C85B
_BENCHY_PATH41 EQU $027B
Vec_Counters EQU $C82E
_BENCHY_PATH56 EQU $0302
Do_Sound EQU $F289
VEC_EXPL_CHAN EQU $C85C
VEC_BUTTON_2_4 EQU $C819
DV3D_CLOSE_CHECK EQU $43DA
Vec_Counter_3 EQU $C830
_BENCHY_PATH100 EQU $048E
ADD_SCORE_A EQU $F85E
Vec_Music_Freq EQU $C861
Vec_Counter_5 EQU $C832
Clear_C8_RAM EQU $F542
Vec_Buttons EQU $C811
_BENCHY_PATH104 EQU $04B2
Move_Mem_a EQU $F683
VEC_MUSIC_WK_A EQU $C842
ROT_VL EQU $F616
Warm_Start EQU $F06C
VEC_COUNTER_1 EQU $C82E
Moveto_d EQU $F312
DRAW_VECTOR_BANKED EQU $4006
_BENCHY_PATH64 EQU $034A
VEC_BUTTONS EQU $C811
COLD_START EQU $F000
VEC_DOT_DWELL EQU $C828
Vec_Music_Chan EQU $C855
DELAY_2 EQU $F571
_BENCHY_PATH63 EQU $0341
JOY_ANALOG EQU $F1F5
Intensity_5F EQU $F2A5
Sound_Byte_raw EQU $F25B
_BENCHY_PATH7 EQU $0149
Draw_VLp_scale EQU $F40C
WARM_START EQU $F06C
Vec_Button_1_2 EQU $C813
DRAW_VLCS EQU $F3D6
_BENCHY_PATH23 EQU $01D9
CLEAR_X_B_80 EQU $F550
EXPLOSION_SND EQU $F92E
Vec_Music_Work EQU $C83F
Abs_a_b EQU $F584
Explosion_Snd EQU $F92E
ASSET_BANK_TABLE EQU $4003
Vec_Max_Players EQU $C84F
Intensity_a EQU $F2AB
DELAY_0 EQU $F579
DV3D_ALL_DONE EQU $4410
VEC_JOY_1_Y EQU $C81C
Cold_Start EQU $F000
_BENCHY_PATH85 EQU $0407
CLEAR_X_B_A EQU $F552
Vec_Joy_Mux_2_X EQU $C821
DRAW_VLP EQU $F410
_BENCHY_PATH125 EQU $056F
VEC_JOY_MUX_2_Y EQU $C822
VEC_MUSIC_WK_7 EQU $C845
VEC_BUTTON_1_4 EQU $C815
Init_Music EQU $F68D
Reset_Pen EQU $F35B
_BENCHY_VECTORS EQU $0000
_BENCHY_PATH25 EQU $01EB
MUSIC6 EQU $FE76
MOV_DRAW_VLC_A EQU $F3AD
_BENCHY_PATH110 EQU $04E8
DRAW_PAT_VL_A EQU $F434
VEC_DURATION EQU $C857
_BENCHY_PATH19 EQU $01B5
Recalibrate EQU $F2E6
DSWM_NO_NEGATE_DY EQU $4143
Select_Game EQU $F7A9
DRAW_LINE_D EQU $F3DF
_BENCHY_PATH60 EQU $0326
_BENCHY_PATH0 EQU $010A
Sound_Bytes_x EQU $F284
_BENCHY_PATH88 EQU $0422
DV3D_NEXT_PATH EQU $440D
VEC_MAX_GAMES EQU $C850
VEC_COLD_FLAG EQU $CBFE
Draw_Grid_VL EQU $FF9F
DP_TO_C8 EQU $F1AF
DSWM_W1 EQU $4122
DRAW_VL_AB EQU $F3D8
VECTOR_ADDR_TABLE EQU $4001
Delay_0 EQU $F579
Delay_2 EQU $F571
Dot_List_Reset EQU $F2DE
COS_TABLE EQU $4514
ABS_A_B EQU $F584
_BENCHY_PATH52 EQU $02DE
Dot_ix EQU $F2C1
_BENCHY_PATH39 EQU $0269
Vec_Rise_Index EQU $C839
Init_OS_RAM EQU $F164
Print_Str_yx EQU $F378
Clear_Score EQU $F84F
VEC_MUSIC_WK_6 EQU $C846
_BENCHY_PATH53 EQU $02E7
DSWM_NEXT_NO_NEGATE_Y EQU $4185
INTENSITY_7F EQU $F2A9
Vec_Counter_1 EQU $C82E
musicc EQU $FF7A
MUSIC9 EQU $FF26
Moveto_d_7F EQU $F2FC
Rise_Run_Len EQU $F603
VEC_JOY_MUX EQU $C81F
RESET_PEN EQU $F35B
SOUND_BYTES_X EQU $F284
Move_Mem_a_1 EQU $F67F
PRINT_LIST EQU $F38A
DO_SOUND EQU $F289
Vec_Button_2_4 EQU $C819
_BENCHY_PATH9 EQU $015B
SOUND_BYTE_X EQU $F259
Print_List EQU $F38A
_BENCHY_PATH58 EQU $0314
Dot_List EQU $F2D5
Joy_Analog EQU $F1F5
Vec_RiseRun_Len EQU $C83B
musica EQU $FF44
_BENCHY_PATH49 EQU $02C3
_BENCHY_PATH83 EQU $03F5
VEC_ADSR_TIMERS EQU $C85E
_BENCHY_PATH17 EQU $01A3
VEC_MUSIC_TWANG EQU $C858
Draw_VLp EQU $F410
DELAY_3 EQU $F56D
VECTOR_BANK_TABLE EQU $4000
VEC_RFRSH_LO EQU $C83D
_BENCHY_PATH32 EQU $022A
SET_REFRESH EQU $F1A2
VEC_MUSIC_CHAN EQU $C855
_BENCHY_PATH115 EQU $0515
Vec_ADSR_Timers EQU $C85E
VEC_TWANG_TABLE EQU $C851
SIN_TABLE EQU $4414
_BENCHY_PATH107 EQU $04CD
Vec_Joy_2_Y EQU $C81E
VEC_JOY_1_X EQU $C81B
RISE_RUN_ANGLE EQU $F593
_BENCHY_PATH29 EQU $020F
Vec_Expl_Chan EQU $C85C
_BENCHY_PATH98 EQU $047C
DSWM_NO_NEGATE_DX EQU $414D
INIT_OS_RAM EQU $F164
_BENCHY_PATH14 EQU $0188
PRINT_STR_HWYX EQU $F373
_BENCHY_PATH30 EQU $0218
RANDOM_3 EQU $F511
_BENCHY_PATH71 EQU $0389
Vec_Str_Ptr EQU $C82C
_BENCHY_PATH67 EQU $0365
DSWM_NEXT_SET_INTENSITY EQU $4179
DRAW_VLP_7F EQU $F408
_BENCHY_PATH127 EQU $0581
_BENCHY_PATH112 EQU $04FA
Draw_VL_mode EQU $F46E
_BENCHY_PATH66 EQU $035C
DO_SOUND_X EQU $F28C
Moveto_ix_7F EQU $F30C
Vec_Brightness EQU $C827
VEC_BUTTON_1_3 EQU $C814
DRAW_VLP_FF EQU $F404
Vec_Expl_Flag EQU $C867
CHECK0REF EQU $F34F
MUSIC1 EQU $FD0D
MUSIC5 EQU $FE38
Vec_Loop_Count EQU $C825
_BENCHY_PATH28 EQU $0206
SELECT_GAME EQU $F7A9
Vec_Angle EQU $C836
VEC_PATTERN EQU $C829
Mov_Draw_VL_a EQU $F3B9
DRAW_VL_A EQU $F3DA
CLEAR_C8_RAM EQU $F542
VEC_TEXT_HEIGHT EQU $C82A
Vec_Button_2_3 EQU $C818
Vec_Counter_4 EQU $C831
_BENCHY_PATH70 EQU $0380
Vec_Joy_2_X EQU $C81D
RESET0REF EQU $F354
DP_TO_D0 EQU $F1AA
Vec_High_Score EQU $CBEB
DRAW_VLC EQU $F3CE
_BENCHY_PATH47 EQU $02B1
Intensity_1F EQU $F29D
Draw_Sync_List_At_With_Mirrors EQU $40AF
PRINT_STR_D EQU $F37A
Vec_SWI_Vector EQU $CBFB
INIT_VIA EQU $F14C
MOV_DRAW_VL_A EQU $F3B9
Wait_Recal EQU $F192
_BENCHY_PATH80 EQU $03DA
DEC_3_COUNTERS EQU $F55A
Set_Refresh EQU $F1A2
VEC_COUNTER_4 EQU $C831
MOD16.M16_DPOS EQU $4078
_BENCHY_PATH86 EQU $0410
_BENCHY_PATH36 EQU $024E
Obj_Will_Hit_u EQU $F8E5
Vec_Expl_Chans EQU $C854
_BENCHY_PATH73 EQU $039B
Dec_6_Counters EQU $F55E
MUSIC2 EQU $FD1D
VEC_RISERUN_TMP EQU $C834
Draw_VLp_7F EQU $F408
GET_RISE_RUN EQU $F5EF
Random EQU $F517
Init_Music_chk EQU $F687
VEC_COUNTER_3 EQU $C830
Read_Btns EQU $F1BA
Vec_Music_Wk_A EQU $C842
VEC_RANDOM_SEED EQU $C87D
_BENCHY_PATH21 EQU $01C7
VEC_MAX_PLAYERS EQU $C84F
_BENCHY_PATH31 EQU $0221
SMUL8 EQU $4202
VEC_PREV_BTNS EQU $C810
DSWM_SET_INTENSITY EQU $40B1
Moveto_x_7F EQU $F2F2
PRINT_SHIPS_X EQU $F391
PRINT_STR_YX EQU $F378
_BENCHY_PATH123 EQU $055D
music8 EQU $FEF8
DRAW_PAT_VL_D EQU $F439
READ_BTNS_MASK EQU $F1B4
Draw_VLp_b EQU $F40E
XFORM_RUN_A EQU $F65B
Sound_Byte EQU $F256
_BENCHY_PATH131 EQU $05A5
Vec_Counter_6 EQU $C833
_BENCHY_PATH69 EQU $0377
MOV_DRAW_VLCS EQU $F3B5
VEC_SEED_PTR EQU $C87B
CLEAR_X_B EQU $F53F
_BENCHY_PATH20 EQU $01BE
Vec_ADSR_Table EQU $C84F
_BENCHY_PATH105 EQU $04BB
Vec_Num_Players EQU $C879
INIT_MUSIC EQU $F68D
CLEAR_X_256 EQU $F545
DOT_D EQU $F2C3
_BENCHY_PATH26 EQU $01F4
Sound_Bytes EQU $F27D
_BENCHY_PATH61 EQU $032F
DSWM_NO_NEGATE_X EQU $40D8
Vec_Btn_State EQU $C80F
_BENCHY_PATH113 EQU $0503
VEC_FIRQ_VECTOR EQU $CBF5
MUSICC EQU $FF7A
SMUL8_AP EQU $420E
Vec_Freq_Table EQU $C84D
Vec_Music_Ptr EQU $C853
DV3D_SEG_LOOP EQU $4390
_BENCHY_PATH54 EQU $02F0
VEC_MUSIC_FLAG EQU $C856
Rot_VL_Mode EQU $F62B
Delay_RTS EQU $F57D
Vec_Music_Twang EQU $C858
Intensity_7F EQU $F2A9
MUSIC3 EQU $FD81
_BENCHY_PATH59 EQU $031D
Mov_Draw_VLc_a EQU $F3AD
MOD16.M16_RCHECK EQU $4080
Vec_Counter_2 EQU $C82F
RESET0INT EQU $F36B
Vec_Music_Wk_5 EQU $C847
MOVETO_X_7F EQU $F2F2
music1 EQU $FD0D
VEC_COUNTERS EQU $C82E
Vec_IRQ_Vector EQU $CBF8
Get_Rise_Idx EQU $F5D9
Rot_VL EQU $F616
RISE_RUN_LEN EQU $F603
DEC_COUNTERS EQU $F563
READ_BTNS EQU $F1BA
Rot_VL_Mode_a EQU $F61F
COMPARE_SCORE EQU $F8C7
INIT_OS EQU $F18B
Draw_VLcs EQU $F3D6
Vec_Expl_ChanA EQU $C853
MOVE_MEM_A_1 EQU $F67F
Draw_VL EQU $F3DD
_BENCHY_PATH84 EQU $03FE
_BENCHY_PATH96 EQU $046A
_BENCHY_PATH102 EQU $04A0
Dot_d EQU $F2C3
ROT_VL_MODE_A EQU $F61F
Delay_b EQU $F57A
PRINT_STR EQU $F495
VEC_RFRSH EQU $C83D
VEC_MUSIC_WK_5 EQU $C847
Vec_Button_1_1 EQU $C812
Vec_Button_1_3 EQU $C814
_BENCHY_PATH101 EQU $0497
VEC_EXPL_3 EQU $C85A
Mov_Draw_VL_ab EQU $F3B7
Draw_Pat_VL_d EQU $F439
VEC_EXPL_1 EQU $C858
_BENCHY_PATH120 EQU $0542
Intensity_3F EQU $F2A1
Print_List_hw EQU $F385
Vec_Expl_2 EQU $C859
_BENCHY_PATH111 EQU $04F1
MOV_DRAW_VL_D EQU $F3BE
VEC_JOY_MUX_1_Y EQU $C820
SOUND_BYTES EQU $F27D
Dot_here EQU $F2C5
_BENCHY_PATH40 EQU $0272
OBJ_HIT EQU $F8FF
_BENCHY_PATH45 EQU $029F
DRAW_VLP_B EQU $F40E
_BENCHY_PATH35 EQU $0245
MOV_DRAW_VL_B EQU $F3B1
Vec_Expl_3 EQU $C85A
VEC_COUNTER_6 EQU $C833
Vec_Button_2_1 EQU $C816
_BENCHY_PATH27 EQU $01FD
Vec_Joy_Resltn EQU $C81A
DELAY_1 EQU $F575
XFORM_RISE EQU $F663
Vec_FIRQ_Vector EQU $CBF5
VEC_SND_SHADOW EQU $C800
Draw_VL_b EQU $F3D2
Xform_Run EQU $F65D
DVB_PATH_LOOP EQU $403D
Rise_Run_X EQU $F5FF
VEC_IRQ_VECTOR EQU $CBF8
MUSICB EQU $FF62
Vec_Joy_1_Y EQU $C81C
_BENCHY_PATH77 EQU $03BF
_BENCHY_PATH62 EQU $0338
_BENCHY_PATH78 EQU $03C8
MUSICD EQU $FF8F
Vec_Expl_Timer EQU $C877
MOVETO_IX EQU $F310
VEC_EXPL_FLAG EQU $C867
_BENCHY_PATH97 EQU $0473
DEC_6_COUNTERS EQU $F55E
VEC_SWI3_VECTOR EQU $CBF2
Vec_Joy_Mux EQU $C81F
ASSET_ADDR_TABLE EQU $4004
DOT_HERE EQU $F2C5
DSWM_NO_NEGATE_Y EQU $40CB
Draw_VL_ab EQU $F3D8
SOUND_BYTE EQU $F256
New_High_Score EQU $F8D8
VEC_JOY_RESLTN EQU $C81A
VEC_JOY_MUX_2_X EQU $C821
_BENCHY_PATH79 EQU $03D1
VEC_RISE_INDEX EQU $C839
Delay_1 EQU $F575
BITMASK_A EQU $F57E
Draw_VLp_FF EQU $F404
DSWM_NEXT_PATH EQU $4173
OBJ_WILL_HIT_U EQU $F8E5
VEC_SWI2_VECTOR EQU $CBF2
VEC_TEXT_HW EQU $C82A
DOT_LIST EQU $F2D5
VEC_BUTTON_2_2 EQU $C817
Vec_Pattern EQU $C829
Vec_Joy_1_X EQU $C81B
Add_Score_a EQU $F85E
VEC_EXPL_4 EQU $C85B
DOT_IX EQU $F2C1
_BENCHY_PATH124 EQU $0566
_BENCHY_PATH75 EQU $03AD
Vec_Seed_Ptr EQU $C87B
Mov_Draw_VL_b EQU $F3B1
Print_Ships_x EQU $F391
VEC_SWI_VECTOR EQU $CBFB
VEC_JOY_2_X EQU $C81D
MOD16.M16_LOOP EQU $408F
Vec_Misc_Count EQU $C823
_BENCHY_PATH89 EQU $042B
_BENCHY_PATH48 EQU $02BA
_BENCHY_PATH119 EQU $0539
Vec_Music_Wk_7 EQU $C845
_BENCHY_PATH34 EQU $023C
Bitmask_a EQU $F57E
_BENCHY_PATH72 EQU $0392
VEC_NUM_PLAYERS EQU $C879
VEC_BUTTON_1_2 EQU $C813


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "3D ROTATE"
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
    ; Initialize bank tracking vars to 0 (prevents spurious $DF00 writes)
    LDA #0
    STA >CURRENT_ROM_BANK   ; Bank 0 is always active at boot
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
ROT3D_AX             EQU $C880+$24   ; 3D raw angle X (0-127) (1 bytes)
ROT3D_AY             EQU $C880+$25   ; 3D raw angle Y (0-127) (1 bytes)
ROT3D_AZ             EQU $C880+$26   ; 3D raw angle Z (0-127) (1 bytes)
ROT3D_SIN_X          EQU $C880+$27   ; 3D rotation sin(ax) i8 (1 bytes)
ROT3D_COS_X          EQU $C880+$28   ; 3D rotation cos(ax) i8 (1 bytes)
ROT3D_SIN_Y          EQU $C880+$29   ; 3D rotation sin(ay) i8 (1 bytes)
ROT3D_COS_Y          EQU $C880+$2A   ; 3D rotation cos(ay) i8 (1 bytes)
ROT3D_SIN_Z          EQU $C880+$2B   ; 3D rotation sin(az) i8 (1 bytes)
ROT3D_COS_Z          EQU $C880+$2C   ; 3D rotation cos(az) i8 (1 bytes)
ROT3D_OX             EQU $C880+$2D   ; 3D draw X offset (1 bytes)
ROT3D_OY             EQU $C880+$2E   ; 3D draw Y offset (1 bytes)
ROT3D_PC             EQU $C880+$2F   ; 3D path count remaining (1 bytes)
ROT3D_PT_TOTAL       EQU $C880+$30   ; 3D total points in path (1 bytes)
ROT3D_PT_REM         EQU $C880+$31   ; 3D remaining points (1 bytes)
ROT3D_CLOSED         EQU $C880+$32   ; 3D path closed flag (1 bytes)
ROT3D_RX             EQU $C880+$33   ; 3D raw x (1 bytes)
ROT3D_RY             EQU $C880+$34   ; 3D raw y (1 bytes)
ROT3D_RZ             EQU $C880+$35   ; 3D raw z (1 bytes)
ROT3D_Y1             EQU $C880+$36   ; 3D intermediate y after X-axis rotation (1 bytes)
ROT3D_Z1             EQU $C880+$37   ; 3D intermediate z after X-axis rotation (1 bytes)
ROT3D_X2             EQU $C880+$38   ; 3D intermediate x after Y-axis rotation (1 bytes)
ROT3D_SCR_X          EQU $C880+$39   ; 3D final screen x (1 bytes)
ROT3D_SCR_Y          EQU $C880+$3A   ; 3D final screen y (1 bytes)
ROT3D_PREV_X         EQU $C880+$3B   ; 3D previous screen x (1 bytes)
ROT3D_PREV_Y         EQU $C880+$3C   ; 3D previous screen y (1 bytes)
ROT3D_FIRST_X        EQU $C880+$3D   ; 3D first screen x (for closed path) (1 bytes)
ROT3D_FIRST_Y        EQU $C880+$3E   ; 3D first screen y (for closed path) (1 bytes)
ROT3D_SIGN           EQU $C880+$3F   ; SMUL8 sign tracking byte (1 bytes)
ROT3D_TEMP           EQU $C880+$40   ; 3D rotation temp 1 (1 bytes)
ROT3D_TEMP2          EQU $C880+$41   ; 3D rotation temp 2 (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$42   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$4C   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$4E   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$50   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$51   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$52   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$54   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
VAR_ANGLE_X          EQU $C880+$56   ; User variable: ANGLE_X (2 bytes)
VAR_ANGLE_Y          EQU $C880+$58   ; User variable: ANGLE_Y (2 bytes)
VAR_ANGLE_Z          EQU $C880+$5A   ; User variable: ANGLE_Z (2 bytes)
VAR_ARG0             EQU $CB80   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $CB82   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $CB84   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $CB86   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $CB88   ; Function argument 4 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $CB8A   ; Current ROM bank ID (multibank tracking) (1 bytes)


;***************************************************************************
; MAIN PROGRAM (Bank #0)
;***************************************************************************

MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    LDD #0
    STD VAR_ANGLE_X
    LDD #0
    STD VAR_ANGLE_Y
    LDD #0
    STD VAR_ANGLE_Z
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
    STD VAR_ANGLE_X
    LDD #0
    STD VAR_ANGLE_Y
    LDD #0
    STD VAR_ANGLE_Z

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    LDD >VAR_ANGLE_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ANGLE_X
    LDD >VAR_ANGLE_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #2
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ANGLE_Y
    LDD >VAR_ANGLE_Z
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ANGLE_Z
    ; DRAW_VECTOR_3D: Draw vector asset with 3D rotation
    ; Asset: benchy (3D rotation)
    LDD >VAR_ANGLE_X
    STB >ROT3D_AX       ; angle X (0-127)
    LDD >VAR_ANGLE_Y
    STB >ROT3D_AY       ; angle Y (0-127)
    LDD >VAR_ANGLE_Z
    STB >ROT3D_AZ       ; angle Z (0-127)
    LDD #0
    STB >ROT3D_OX       ; screen X offset
    LDD #0
    STB >ROT3D_OY       ; screen Y offset
    LDX #_BENCHY_3D_DATA  ; pointer to 3D data table
    JSR DRAW_VECTOR_3D_RUNTIME
    LDD #0
    STD RESULT
    RTS


; ================================================
