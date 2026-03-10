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
LEVEL_PTR            EQU $C880+$38   ; Pointer to currently loaded level header (2 bytes)
LEVEL_LOADED         EQU $C880+$3A   ; Level loaded flag (0=not loaded, 1=loaded) (1 bytes)
LEVEL_WIDTH          EQU $C880+$3B   ; Level width (legacy tile API) (1 bytes)
LEVEL_HEIGHT         EQU $C880+$3C   ; Level height (legacy tile API) (1 bytes)
LEVEL_TILE_SIZE      EQU $C880+$3D   ; Tile size (legacy tile API) (1 bytes)
LEVEL_Y_IDX          EQU $C880+$3E   ; SHOW_LEVEL row counter (legacy) (1 bytes)
LEVEL_X_IDX          EQU $C880+$3F   ; SHOW_LEVEL column counter (legacy) (1 bytes)
LEVEL_TEMP           EQU $C880+$40   ; SHOW_LEVEL temporary byte (legacy) (1 bytes)
LEVEL_BG_COUNT       EQU $C880+$41   ; BG object count (1 bytes)
LEVEL_GP_COUNT       EQU $C880+$42   ; GP object count (1 bytes)
LEVEL_FG_COUNT       EQU $C880+$43   ; FG object count (1 bytes)
CAMERA_X             EQU $C880+$44   ; Camera X scroll offset (16-bit signed world units) (2 bytes)
LEVEL_BG_ROM_PTR     EQU $C880+$46   ; BG layer ROM pointer (2 bytes)
LEVEL_GP_ROM_PTR     EQU $C880+$48   ; GP layer ROM pointer (2 bytes)
LEVEL_FG_ROM_PTR     EQU $C880+$4A   ; FG layer ROM pointer (2 bytes)
LEVEL_GP_PTR         EQU $C880+$4C   ; GP active pointer (RAM buffer after LOAD_LEVEL) (2 bytes)
LEVEL_BANK           EQU $C880+$4E   ; Bank ID for current level (for multibank) (1 bytes)
SLR_CUR_X            EQU $C880+$4F   ; SHOW_LEVEL: tracked beam X for per-segment clipping (1 bytes)
LEVEL_GP_BUFFER      EQU $C880+$50   ; GP objects RAM buffer (max 8 objects × 15 bytes) (120 bytes)
UGPC_OUTER_IDX       EQU $C880+$C8   ; GP-GP outer loop index (1 bytes)
UGPC_OUTER_MAX       EQU $C880+$C9   ; GP-GP outer loop max (count-1) (1 bytes)
UGPC_INNER_IDX       EQU $C880+$CA   ; GP-GP inner loop index (1 bytes)
UGPC_DX              EQU $C880+$CB   ; GP-GP |dx| (16-bit) (2 bytes)
UGPC_DIST            EQU $C880+$CD   ; GP-GP Manhattan distance (16-bit) (2 bytes)
UGFC_GP_IDX          EQU $C880+$CF   ; GP-FG outer loop GP index (1 bytes)
UGFC_FG_COUNT        EQU $C880+$D0   ; GP-FG inner loop FG count (1 bytes)
UGFC_DX              EQU $C880+$D1   ; GP-FG |dx| (1 bytes)
UGFC_DY              EQU $C880+$D2   ; GP-FG |dy| (1 bytes)
TEXT_SCALE_H         EQU $C880+$D3   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$D4   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
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
MOV_DRAW_VL_D EQU $F3BE
SELECT_GAME EQU $F7A9
INTENSITY_7F EQU $F2A9
MOV_DRAW_VL_B EQU $F3B1
Intensity_5F EQU $F2A5
VEC_JOY_MUX_2_X EQU $C821
VEC_DURATION EQU $C857
Print_Ships EQU $F393
Clear_x_256 EQU $F545
VEC_BTN_STATE EQU $C80F
ULR_X_MAX_CHECK EQU $463C
music8 EQU $FEF8
VEC_COUNTER_3 EQU $C830
SHOW_LEVEL_RUNTIME EQU $4313
CLEAR_X_D EQU $F548
WAIT_RECAL EQU $F192
Vec_Dot_Dwell EQU $C828
Vec_Buttons EQU $C811
ULR_LAYER_EXIT EQU $46BF
DELAY_3 EQU $F56D
SLR_DONE EQU $4377
Draw_VL_b EQU $F3D2
DSWM_W2 EQU $41C8
ROT_VL_DFT EQU $F637
DP_TO_C8 EQU $F1AF
VEC_MAX_GAMES EQU $C850
DOT_D EQU $F2C3
Draw_Pat_VL_d EQU $F439
Vec_Music_Ptr EQU $C853
RANDOM_3 EQU $F511
DVB_DONE EQU $404F
VEC_COUNTER_2 EQU $C82F
Delay_RTS EQU $F57D
JOY_ANALOG EQU $F1F5
PRINT_LIST EQU $F38A
Vec_0Ref_Enable EQU $C824
Init_Music EQU $F68D
Get_Rise_Run EQU $F5EF
VEC_JOY_2_Y EQU $C81E
RISE_RUN_LEN EQU $F603
Vec_Cold_Flag EQU $CBFE
SLR_GAMEPLAY EQU $4353
CLEAR_X_B_80 EQU $F550
MOV_DRAW_VL_A EQU $F3B9
Vec_ADSR_Timers EQU $C85E
VECTREX_PRINT_TEXT EQU $408F
ULR_GP_FG_COLLISIONS EQU $4799
Vec_ADSR_Table EQU $C84F
MUSIC9 EQU $FF26
VEC_BUTTON_2_1 EQU $C816
music7 EQU $FEC6
DO_SOUND EQU $F289
Dot_ix EQU $F2C1
Draw_Pat_VL_a EQU $F434
SLR_OBJ_DONE EQU $4483
SLR_RAM_A_ZERO EQU $43EB
VEC_BUTTON_1_3 EQU $C814
Clear_x_b EQU $F53F
SLR_OBJ_NEXT EQU $4479
CLEAR_SOUND EQU $F272
EXPLOSION_SND EQU $F92E
SLR_FOREGROUND EQU $4365
Read_Btns EQU $F1BA
Mov_Draw_VLcs EQU $F3B5
VEC_RFRSH_LO EQU $C83D
Vec_Music_Flag EQU $C856
VEC_MUSIC_FLAG EQU $C856
DRAW_LINE_D EQU $F3DF
OBJ_WILL_HIT EQU $F8F3
Mov_Draw_VL_ab EQU $F3B7
DRAW_VECTOR_BANKED EQU $400C
VEC_NMI_VECTOR EQU $CBFB
PRINT_TEXT_STR_110251488 EQU $4878
Delay_3 EQU $F56D
VEC_BUTTON_2_4 EQU $C819
DRAW_VL_MODE EQU $F46E
VEC_MUSIC_WK_1 EQU $C84B
RISE_RUN_Y EQU $F601
RESET0INT EQU $F36B
PRINT_TEXT_STR_2344190015343208 EQU $487E
MOVETO_X_7F EQU $F2F2
Clear_Sound EQU $F272
XFORM_RUN_A EQU $F65B
Draw_VLc EQU $F3CE
MOVETO_IX_FF EQU $F308
Add_Score_d EQU $F87C
SDCP_MOVETO_W EQU $450B
NEW_HIGH_SCORE EQU $F8D8
ULR_Y_NOT_MIN EQU $460E
Init_OS_RAM EQU $F164
Mov_Draw_VL_a EQU $F3B9
Print_List_hw EQU $F385
ADD_SCORE_A EQU $F85E
VEC_RISERUN_LEN EQU $C83B
UGPC_DY_POS EQU $475C
Vec_Num_Game EQU $C87A
RECALIBRATE EQU $F2E6
DRAW_VLP_7F EQU $F408
UGPC_COLLISION EQU $4772
Vec_Joy_Mux EQU $C81F
UGPC_INNER_LOOP EQU $46F1
ULR_Y_NOT_MAX EQU $4603
Print_List EQU $F38A
GET_RUN_IDX EQU $F5DB
Vec_Music_Freq EQU $C861
Moveto_d_7F EQU $F2FC
Dot_List_Reset EQU $F2DE
DRAW_PAT_VL EQU $F437
SOUND_BYTE_RAW EQU $F25B
MUSICD EQU $FF8F
DSWM_NO_NEGATE_Y EQU $412F
VEC_BUTTON_1_1 EQU $C812
Vec_Duration EQU $C857
Vec_Expl_4 EQU $C85B
music3 EQU $FD81
Sound_Bytes EQU $F27D
UGPC_OUTER_LOOP EQU $46D1
DSWM_W3 EQU $4259
Rise_Run_Y EQU $F601
Rot_VL_Mode_a EQU $F61F
UGPC_OUTER_MUL EQU $46DB
MOVETO_IX EQU $F310
DP_to_C8 EQU $F1AF
Vec_Joy_Mux_2_Y EQU $C822
Dec_Counters EQU $F563
DRAW_VLP_FF EQU $F404
Mov_Draw_VL_b EQU $F3B1
ABS_A_B EQU $F584
Rot_VL_dft EQU $F637
VEC_JOY_MUX_1_Y EQU $C820
LOAD_LEVEL_RUNTIME EQU $4266
UGFC_GP_ADDR_DONE EQU $47BE
VECTOR_BANK_TABLE EQU $4000
Intensity_7F EQU $F2A9
JOY_DIGITAL EQU $F1F8
Random EQU $F517
VEC_MUSIC_WK_7 EQU $C845
MOD16.M16_RCHECK EQU $40E4
Dec_3_Counters EQU $F55A
VEC_RISERUN_TMP EQU $C834
SDCP_USE_OVERRIDE EQU $4492
VEC_ADSR_TIMERS EQU $C85E
DOT_IX_B EQU $F2BE
MUSIC3 EQU $FD81
INTENSITY_1F EQU $F29D
Reset0Ref EQU $F354
Vec_Expl_ChanA EQU $C853
VEC_BUTTONS EQU $C811
PRINT_LIST_HW EQU $F385
Rise_Run_Len EQU $F603
LLR_COPY_DONE EQU $4312
VEC_SEED_PTR EQU $C87B
Draw_VL EQU $F3DD
VEC_TEXT_HEIGHT EQU $C82A
Clear_x_b_80 EQU $F550
SLR_DRAW_OBJECTS EQU $4384
Vec_Music_Chan EQU $C855
Init_OS EQU $F18B
Mov_Draw_VL EQU $F3BC
INTENSITY_A EQU $F2AB
DRAW_VLCS EQU $F3D6
PRINT_STR EQU $F495
UGFC_DX_POS EQU $47E3
RESET_PEN EQU $F35B
Moveto_ix EQU $F310
DOT_LIST_RESET EQU $F2DE
VEC_COUNTER_6 EQU $C833
Vec_Counter_6 EQU $C833
SLR_OBJ_LOOP EQU $4386
MUSIC6 EQU $FE76
PRINT_LIST_CHK EQU $F38C
Vec_Text_HW EQU $C82A
SDCP_CHECK_POS EQU $44BA
VEC_BUTTON_2_2 EQU $C817
PRINT_STR_YX EQU $F378
Init_Music_Buf EQU $F533
Vec_Button_2_4 EQU $C819
INIT_MUSIC_X EQU $F692
Delay_1 EQU $F575
Set_Refresh EQU $F1A2
Vec_RiseRun_Len EQU $C83B
DP_TO_D0 EQU $F1AA
RISE_RUN_X EQU $F5FF
UGPC_DX_POS EQU $4737
Vec_Joy_1_X EQU $C81B
COLD_START EQU $F000
VEC_MUSIC_WK_A EQU $C842
SOUND_BYTES_X EQU $F284
SDCP_ABS_OK EQU $44BF
INIT_MUSIC EQU $F68D
OBJ_WILL_HIT_U EQU $F8E5
SDCP_DONE EQU $4582
INIT_VIA EQU $F14C
Vec_Text_Width EQU $C82B
Vec_High_Score EQU $CBEB
Xform_Run_a EQU $F65B
VEC_MISC_COUNT EQU $C823
Vec_Random_Seed EQU $C87D
Moveto_d EQU $F312
MOV_DRAW_VLCS EQU $F3B5
SDCP_CLIP EQU $455C
UGFC_VY_ABS EQU $480B
Vec_FIRQ_Vector EQU $CBF5
Vec_Expl_Chans EQU $C854
RESET0REF_D0 EQU $F34A
VEC_ANGLE EQU $C836
UGPC_SKIP_OUTER_MUL EQU $46E2
VEC_JOY_RESLTN EQU $C81A
UGFC_GP_LOOP EQU $47AD
UGPC_SKIP_INNER_MUL EQU $470D
VEC_EXPL_CHANA EQU $C853
Print_Ships_x EQU $F391
Vec_Button_1_2 EQU $C813
VEC_LOOP_COUNT EQU $C825
XFORM_RUN EQU $F65D
VEC_JOY_2_X EQU $C81D
Joy_Digital EQU $F1F8
Init_Music_chk EQU $F687
ULR_LOOP EQU $45BC
CLEAR_X_256 EQU $F545
Mov_Draw_VL_d EQU $F3BE
music6 EQU $FE76
INIT_OS EQU $F18B
Vec_Prev_Btns EQU $C810
VEC_EXPL_FLAG EQU $C867
Vec_Joy_Mux_1_X EQU $C81F
MOVETO_IX_A EQU $F30E
Vec_Counters EQU $C82E
Sound_Bytes_x EQU $F284
Vec_IRQ_Vector EQU $CBF8
PRINT_SHIPS_X EQU $F391
LLR_CLR_GP_LOOP EQU $42A4
Select_Game EQU $F7A9
VEC_SWI2_VECTOR EQU $CBF2
DRAW_VL_A EQU $F3DA
Vec_Rfrsh_lo EQU $C83D
DSWM_NEXT_SET_INTENSITY EQU $41DD
Vec_NMI_Vector EQU $CBFB
SDCP_W_MOVE EQU $4576
Vec_Num_Players EQU $C879
VEC_BUTTON_1_2 EQU $C813
Clear_Score EQU $F84F
VEC_DEFAULT_STK EQU $CBEA
Draw_Grid_VL EQU $FF9F
VEC_EXPL_2 EQU $C859
Draw_VLp_7F EQU $F408
Vec_Button_2_2 EQU $C817
CHECK0REF EQU $F34F
Vec_Seed_Ptr EQU $C87B
Vec_Expl_2 EQU $C859
Draw_VLp_b EQU $F40E
DP_to_D0 EQU $F1AA
Get_Rise_Idx EQU $F5D9
VEC_EXPL_TIMER EQU $C877
DOT_LIST EQU $F2D5
Dot_List EQU $F2D5
Vec_Text_Height EQU $C82A
Vec_Joy_2_X EQU $C81D
Draw_Line_d EQU $F3DF
Read_Btns_Mask EQU $F1B4
SLR_ROM_A_ZERO EQU $4448
WARM_START EQU $F06C
VEC_BUTTON_2_3 EQU $C818
VEC_DOT_DWELL EQU $C828
MOVE_MEM_A_1 EQU $F67F
VEC_MAX_PLAYERS EQU $C84F
Sound_Byte_x EQU $F259
New_High_Score EQU $F8D8
SET_REFRESH EQU $F1A2
MOV_DRAW_VL_AB EQU $F3B7
INTENSITY_3F EQU $F2A1
DRAW_PAT_VL_A EQU $F434
MUSIC7 EQU $FEC6
VEC_BRIGHTNESS EQU $C827
MOVETO_D EQU $F312
DRAW_SYNC_LIST_AT_WITH_MIRRORS EQU $4113
Moveto_ix_a EQU $F30E
Intensity_a EQU $F2AB
Cold_Start EQU $F000
ULR_Y_BOUNDS EQU $4666
ASSET_BANK_TABLE EQU $4006
Clear_C8_RAM EQU $F542
Vec_Button_1_1 EQU $C812
SLR_DRAW_VECTOR EQU $4459
VEC_HIGH_SCORE EQU $CBEB
Vec_Joy_1_Y EQU $C81C
ABS_B EQU $F58B
musicb EQU $FF62
VEC_NUM_PLAYERS EQU $C879
Intensity_3F EQU $F2A1
VEC_NUM_GAME EQU $C87A
Vec_Default_Stk EQU $CBEA
VEC_0REF_ENABLE EQU $C824
GET_RISE_IDX EQU $F5D9
UGFC_FG_LOOP EQU $47CC
VEC_MUSIC_FREQ EQU $C861
DELAY_B EQU $F57A
Vec_Loop_Count EQU $C825
Vec_Expl_3 EQU $C85A
VEC_COUNTER_1 EQU $C82E
Draw_VL_mode EQU $F46E
Vec_Expl_Timer EQU $C877
music2 EQU $FD1D
VECTOR_ADDR_TABLE EQU $4001
SLR_INTENSITY_READ EQU $43AA
VEC_ADSR_TABLE EQU $C84F
MUSIC2 EQU $FD1D
LEVEL_BANK_TABLE EQU $4003
Vec_Brightness EQU $C827
MOVETO_D_7F EQU $F2FC
VEC_RUN_INDEX EQU $C837
Xform_Run EQU $F65D
UGFC_GP_MUL EQU $47B7
Vec_Joy_Mux_2_X EQU $C821
VEC_MUSIC_WK_6 EQU $C846
DSWM_NEXT_NO_NEGATE_Y EQU $41E9
VEC_EXPL_CHANB EQU $C85D
Vec_Music_Wk_7 EQU $C845
DELAY_0 EQU $F579
Draw_Pat_VL EQU $F437
MUSICA EQU $FF44
Do_Sound EQU $F289
PRINT_STR_D EQU $F37A
Print_Str_yx EQU $F378
UGPC_INNER_MUL EQU $4706
SLR_ROM_VISIBLE EQU $4450
DRAW_VL_AB EQU $F3D8
Vec_Joy_2_Y EQU $C81E
VEC_RANDOM_SEED EQU $C87D
Vec_Music_Work EQU $C83F
OBJ_HIT EQU $F8FF
RANDOM EQU $F517
Dot_here EQU $F2C5
VEC_JOY_1_Y EQU $C81C
Reset0Ref_D0 EQU $F34A
UGPC_NEXT_INNER EQU $4782
SLR_ROM_ADDR_LOOP EQU $439F
_PLATFORM_VECTORS EQU $003D
DRAW_PAT_VL_D EQU $F439
ULR_GAMEPLAY_COLLISIONS EQU $46C0
COMPARE_SCORE EQU $F8C7
SLR_GP_COUNT EQU $4353
Do_Sound_x EQU $F28C
CLEAR_SCORE EQU $F84F
musica EQU $FF44
Vec_Rfrsh EQU $C83D
VEC_TEXT_HW EQU $C82A
_PLATFORM_PATH0 EQU $0040
ULR_UPDATE_LAYER EQU $45B2
XFORM_RISE EQU $F663
DO_SOUND_X EQU $F28C
UGFC_VERT_BOUNCE EQU $4841
MUSIC4 EQU $FDD3
Obj_Will_Hit EQU $F8F3
DOT_IX EQU $F2C1
DSWM_W1 EQU $4186
LOAD_LEVEL_BANKED EQU $405B
Vec_Counter_4 EQU $C831
Print_List_chk EQU $F38C
GET_RISE_RUN EQU $F5EF
MOD16.M16_END EQU $4103
VEC_MUSIC_CHAN EQU $C855
SOUND_BYTE_X EQU $F259
Print_Str_d EQU $F37A
VEC_IRQ_VECTOR EQU $CBF8
Vec_Music_Wk_5 EQU $C847
Get_Run_Idx EQU $F5DB
DSWM_NO_NEGATE_DX EQU $41B1
INIT_MUSIC_BUF EQU $F533
VEC_MUSIC_WK_5 EQU $C847
UGPC_INNER_DONE EQU $4788
Vec_Button_1_3 EQU $C814
ULR_VY_OK EQU $45DD
SLR_PATH_DONE EQU $4477
VEC_EXPL_4 EQU $C85B
Vec_Twang_Table EQU $C851
Draw_Sync_List_At_With_Mirrors EQU $4113
SDCP_W_DRAW EQU $454D
Vec_Str_Ptr EQU $C82C
VEC_FREQ_TABLE EQU $C84D
Vec_Counter_5 EQU $C832
VEC_TWANG_TABLE EQU $C851
MOD16.M16_RPOS EQU $40F3
VEC_JOY_MUX EQU $C81F
MOD16.M16_DONE EQU $4112
DSWM_NEXT_PATH EQU $41D7
Xform_Rise_a EQU $F661
DEC_3_COUNTERS EQU $F55A
UGFC_HORIZ_BOUNCE EQU $481C
VEC_BUTTON_1_4 EQU $C815
Warm_Start EQU $F06C
Vec_SWI3_Vector EQU $CBF2
MUSICB EQU $FF62
musicd EQU $FF8F
Vec_Freq_Table EQU $C84D
Add_Score_a EQU $F85E
Check0Ref EQU $F34F
Vec_Joy_Mux_1_Y EQU $C820
Recalibrate EQU $F2E6
LLR_COPY_OBJECTS EQU $42CB
VEC_RISE_INDEX EQU $C839
UGFC_EXIT EQU $4877
Vec_Button_2_3 EQU $C818
LEVEL_ADDR_TABLE EQU $4004
Draw_VLcs EQU $F3D6
Vec_Expl_Chan EQU $C85C
VEC_SND_SHADOW EQU $C800
music4 EQU $FDD3
Vec_Counter_1 EQU $C82E
Obj_Hit EQU $F8FF
BITMASK_A EQU $F57E
Xform_Rise EQU $F663
VEC_JOY_1_X EQU $C81B
VEC_EXPL_CHAN EQU $C85C
CLEAR_C8_RAM EQU $F542
VEC_JOY_MUX_1_X EQU $C81F
VEC_RFRSH EQU $C83D
VEC_MUSIC_PTR EQU $C853
Delay_b EQU $F57A
DSWM_SET_INTENSITY EQU $4115
DSWM_NEXT_NO_NEGATE_X EQU $41F6
music1 EQU $FD0D
ROT_VL_MODE EQU $F62B
SDCP_SEG_LOOP EQU $4514
DRAW_VLP_SCALE EQU $F40C
DOT_HERE EQU $F2C5
Dot_ix_b EQU $F2BE
Init_VIA EQU $F14C
Wait_Recal EQU $F192
INIT_OS_RAM EQU $F164
Vec_SWI_Vector EQU $CBFB
UGPC_EXIT EQU $4798
Explosion_Snd EQU $F92E
Vec_Expl_1 EQU $C858
Vec_Max_Games EQU $C850
Reset0Int EQU $F36B
VEC_EXPL_1 EQU $C858
Rot_VL EQU $F616
VEC_SWI3_VECTOR EQU $CBF2
LLR_GP_DONE EQU $42C3
Move_Mem_a EQU $F683
UGFC_PUSH_DOWN EQU $485D
UGFC_NEXT_GP EQU $486A
VEC_EXPL_CHANS EQU $C854
MUSICC EQU $FF7A
musicc EQU $FF7A
SOUND_BYTE EQU $F256
READ_BTNS EQU $F1BA
ULR_Y_MAX_CHECK EQU $468B
VEC_MUSIC_TWANG EQU $C858
Sound_Byte_raw EQU $F25B
VEC_COUNTERS EQU $C82E
Mov_Draw_VLc_a EQU $F3AD
Vec_Button_2_1 EQU $C816
DSWM_DONE EQU $4265
SOUND_BYTES EQU $F27D
PRINT_SHIPS EQU $F393
MOD16.M16_DPOS EQU $40DC
Draw_VLp_FF EQU $F404
INIT_MUSIC_CHK EQU $F687
Rot_VL_ab EQU $F610
Rise_Run_Angle EQU $F593
DELAY_1 EQU $F575
Bitmask_a EQU $F57E
Vec_Expl_ChanB EQU $C85D
Vec_Music_Wk_1 EQU $C84B
ROT_VL EQU $F616
VEC_PATTERN EQU $C829
Vec_Music_Wk_6 EQU $C846
Strip_Zeros EQU $F8B7
Delay_2 EQU $F571
SDCP_SKIP_PATH EQU $44BE
DEC_COUNTERS EQU $F563
Vec_Snd_Shadow EQU $C800
VEC_COLD_FLAG EQU $CBFE
DRAW_VL_B EQU $F3D2
Vec_SWI2_Vector EQU $CBF2
SLR_RAM_VISIBLE EQU $43F3
MOD16.M16_LOOP EQU $40F3
DELAY_RTS EQU $F57D
RESET0REF EQU $F354
MOD16 EQU $40BF
music9 EQU $FF26
PRINT_STR_HWYX EQU $F373
Vec_Pattern EQU $C829
DVB_PATH_LOOP EQU $403F
ULR_NO_GRAVITY EQU $45DF
DSWM_LOOP EQU $418F
DRAW_VLP EQU $F410
UGFC_VX_ABS EQU $4815
VEC_STR_PTR EQU $C82C
VEC_JOY_MUX_2_Y EQU $C822
Vec_Rise_Index EQU $C839
INTENSITY_5F EQU $F2A5
SLR_BG_COUNT EQU $4341
ULR_NEXT EQU $46B6
Clear_x_d EQU $F548
Vec_Btn_State EQU $C80F
CLEAR_X_B_A EQU $F552
DRAW_GRID_VL EQU $FF9F
Intensity_1F EQU $F29D
Vec_Angle EQU $C836
UGFC_DY_POS EQU $47EF
VEC_COUNTER_4 EQU $C831
READ_BTNS_MASK EQU $F1B4
Vec_Run_Index EQU $C837
Vec_Max_Players EQU $C84F
ADD_SCORE_D EQU $F87C
Vec_Music_Wk_A EQU $C842
Obj_Will_Hit_u EQU $F8E5
Compare_Score EQU $F8C7
Vec_Counter_2 EQU $C82F
SDCP_SET_INTENS EQU $4494
Dot_d EQU $F2C3
VEC_FIRQ_VECTOR EQU $CBF5
Dec_6_Counters EQU $F55E
Vec_Joy_Resltn EQU $C81A
Vec_Counter_3 EQU $C830
ROT_VL_AB EQU $F610
ULR_EXIT EQU $45A7
RISE_RUN_ANGLE EQU $F593
Vec_Expl_Flag EQU $C867
Abs_b EQU $F58B
UGPC_NEXT_OUTER EQU $4788
MUSIC1 EQU $FD0D
Moveto_ix_FF EQU $F308
UPDATE_LEVEL_RUNTIME EQU $4583
DSWM_NO_NEGATE_DY EQU $41A7
Vec_Button_1_4 EQU $C815
XFORM_RISE_A EQU $F661
CLEAR_X_B EQU $F53F
LLR_SKIP_GP EQU $42C3
VEC_SWI_VECTOR EQU $CBFB
DEC_6_COUNTERS EQU $F55E
Rot_VL_Mode EQU $F62B
MOVE_MEM_A EQU $F683
Print_Str EQU $F495
Random_3 EQU $F511
Moveto_ix_7F EQU $F30C
Rise_Run_X EQU $F5FF
Draw_VL_ab EQU $F3D8
Delay_0 EQU $F579
DRAW_VLP_B EQU $F40E
UGFC_NEXT_FG EQU $4863
LLR_COPY_LOOP EQU $42CB
DRAW_VL EQU $F3DD
VEC_COUNTER_5 EQU $C832
VEC_MUSIC_WORK EQU $C83F
DELAY_2 EQU $F571
MUSIC8 EQU $FEF8
Init_Music_x EQU $F692
Draw_VL_a EQU $F3DA
Vec_RiseRun_Tmp EQU $C834
SLR_ROM_OFFSETS EQU $4403
Abs_a_b EQU $F584
ASSET_ADDR_TABLE EQU $4008
Moveto_x_7F EQU $F2F2
MOVETO_IX_7F EQU $F30C
Reset_Pen EQU $F35B
UGPC_START EQU $46CA
VEC_EXPL_3 EQU $C85A
Print_Str_hwyx EQU $F373
UGFC_PUSH_LEFT EQU $4838
Vec_Misc_Count EQU $C823
Vec_Rfrsh_hi EQU $C83E
MUSIC5 EQU $FE38
ROT_VL_MODE_A EQU $F61F
Clear_x_b_a EQU $F552
music5 EQU $FE38
DSWM_NO_NEGATE_X EQU $413C
Move_Mem_a_1 EQU $F67F
SLR_FG_COUNT EQU $4365
VEC_TEXT_WIDTH EQU $C82B
STRIP_ZEROS EQU $F8B7
SLR_PATH_LOOP EQU $445F
Joy_Analog EQU $F1F5
MOV_DRAW_VL EQU $F3BC
DRAW_VLC EQU $F3CE
VEC_PREV_BTNS EQU $C810
SLR_DRAW_CLIPPED_PATH EQU $4486
VEC_RFRSH_HI EQU $C83E
Draw_VLp_scale EQU $F40C
Draw_VLp EQU $F410
Vec_Music_Twang EQU $C858
Sound_Byte EQU $F256
MOV_DRAW_VLC_A EQU $F3AD


;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "VPLAYTST"
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
    CLR >LEVEL_LOADED       ; No level loaded yet (flag, not a pointer)
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
LEVEL_PTR            EQU $C880+$38   ; Pointer to currently loaded level header (2 bytes)
LEVEL_LOADED         EQU $C880+$3A   ; Level loaded flag (0=not loaded, 1=loaded) (1 bytes)
LEVEL_WIDTH          EQU $C880+$3B   ; Level width (legacy tile API) (1 bytes)
LEVEL_HEIGHT         EQU $C880+$3C   ; Level height (legacy tile API) (1 bytes)
LEVEL_TILE_SIZE      EQU $C880+$3D   ; Tile size (legacy tile API) (1 bytes)
LEVEL_Y_IDX          EQU $C880+$3E   ; SHOW_LEVEL row counter (legacy) (1 bytes)
LEVEL_X_IDX          EQU $C880+$3F   ; SHOW_LEVEL column counter (legacy) (1 bytes)
LEVEL_TEMP           EQU $C880+$40   ; SHOW_LEVEL temporary byte (legacy) (1 bytes)
LEVEL_BG_COUNT       EQU $C880+$41   ; BG object count (1 bytes)
LEVEL_GP_COUNT       EQU $C880+$42   ; GP object count (1 bytes)
LEVEL_FG_COUNT       EQU $C880+$43   ; FG object count (1 bytes)
CAMERA_X             EQU $C880+$44   ; Camera X scroll offset (16-bit signed world units) (2 bytes)
LEVEL_BG_ROM_PTR     EQU $C880+$46   ; BG layer ROM pointer (2 bytes)
LEVEL_GP_ROM_PTR     EQU $C880+$48   ; GP layer ROM pointer (2 bytes)
LEVEL_FG_ROM_PTR     EQU $C880+$4A   ; FG layer ROM pointer (2 bytes)
LEVEL_GP_PTR         EQU $C880+$4C   ; GP active pointer (RAM buffer after LOAD_LEVEL) (2 bytes)
LEVEL_BANK           EQU $C880+$4E   ; Bank ID for current level (for multibank) (1 bytes)
SLR_CUR_X            EQU $C880+$4F   ; SHOW_LEVEL: tracked beam X for per-segment clipping (1 bytes)
LEVEL_GP_BUFFER      EQU $C880+$50   ; GP objects RAM buffer (max 8 objects × 15 bytes) (120 bytes)
UGPC_OUTER_IDX       EQU $C880+$C8   ; GP-GP outer loop index (1 bytes)
UGPC_OUTER_MAX       EQU $C880+$C9   ; GP-GP outer loop max (count-1) (1 bytes)
UGPC_INNER_IDX       EQU $C880+$CA   ; GP-GP inner loop index (1 bytes)
UGPC_DX              EQU $C880+$CB   ; GP-GP |dx| (16-bit) (2 bytes)
UGPC_DIST            EQU $C880+$CD   ; GP-GP Manhattan distance (16-bit) (2 bytes)
UGFC_GP_IDX          EQU $C880+$CF   ; GP-FG outer loop GP index (1 bytes)
UGFC_FG_COUNT        EQU $C880+$D0   ; GP-FG inner loop FG count (1 bytes)
UGFC_DX              EQU $C880+$D1   ; GP-FG |dx| (1 bytes)
UGFC_DY              EQU $C880+$D2   ; GP-FG |dy| (1 bytes)
TEXT_SCALE_H         EQU $C880+$D3   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$D4   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
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
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'test2'
    ; Level asset index: 0 (multibank)
    LDX #0
    JSR LOAD_LEVEL_BANKED

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    ; PRINT_TEXT: Print text at position
    LDD #-55
    STD VAR_ARG0
    LDD #120
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2344190015343208      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; ===== UPDATE_LEVEL builtin =====
    JSR UPDATE_LEVEL_RUNTIME
    LDD #0
    STD RESULT
    ; ===== SHOW_LEVEL builtin =====
    JSR SHOW_LEVEL_RUNTIME
    LDD #0
    STD RESULT
    RTS


; ================================================
