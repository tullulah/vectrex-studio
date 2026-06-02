; VPy M6809 Assembly (Vectrex)
; ROM: 32768 bytes


    ORG $0000

;***************************************************************************
; DEFINE SECTION
;***************************************************************************
    INCLUDE "VECTREX.I"

;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "SOLITAIRE"
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
RAND_SEED            EQU $C880+$0E   ; Random seed for RAND() (2 bytes)
DRAW_RECT_X          EQU $C880+$10   ; Rectangle X (1 bytes)
DRAW_RECT_Y          EQU $C880+$11   ; Rectangle Y (1 bytes)
DRAW_RECT_WIDTH      EQU $C880+$12   ; Rectangle width (1 bytes)
DRAW_RECT_HEIGHT     EQU $C880+$13   ; Rectangle height (1 bytes)
DRAW_RECT_INTENSITY  EQU $C880+$14   ; Rectangle intensity (1 bytes)
DRAW_VEC_INTENSITY   EQU $C880+$15   ; Vector intensity override (0=use vector data) (1 bytes)
DRAW_VEC_X_HI        EQU $C880+$16   ; Vector draw X high byte (16-bit screen_x) (1 bytes)
DRAW_VEC_X           EQU $C880+$17   ; Vector draw X offset (1 bytes)
DRAW_VEC_Y           EQU $C880+$18   ; Vector draw Y offset (1 bytes)
MIRROR_PAD           EQU $C880+$19   ; Safety padding to prevent MIRROR flag corruption (16 bytes)
MIRROR_X             EQU $C880+$29   ; X mirror flag (0=normal, 1=flip) (1 bytes)
MIRROR_Y             EQU $C880+$2A   ; Y mirror flag (0=normal, 1=flip) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$2B   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$35   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$37   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$39   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$3A   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$3B   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$3D   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$3F   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$40   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
DRAW_SCALE           EQU $C880+$41   ; Current T1 scale for Draw_Sync_List_At_With_Mirrors ($7F=normal) (1 bytes)
VAR_CARD_W           EQU $C880+$42   ; User variable: CARD_W (2 bytes)
VAR_CARD_H           EQU $C880+$44   ; User variable: CARD_H (2 bytes)
VAR_COL_DY           EQU $C880+$46   ; User variable: COL_DY (2 bytes)
VAR_HALF_W           EQU $C880+$48   ; User variable: HALF_W (2 bytes)
VAR_TOP_Y            EQU $C880+$4A   ; User variable: TOP_Y (2 bytes)
VAR_TAB_Y            EQU $C880+$4C   ; User variable: TAB_Y (2 bytes)
VAR_STK_X            EQU $C880+$4E   ; User variable: STK_X (2 bytes)
VAR_WST_X            EQU $C880+$50   ; User variable: WST_X (2 bytes)
VAR_F0_X             EQU $C880+$52   ; User variable: F0_X (2 bytes)
VAR_F1_X             EQU $C880+$54   ; User variable: F1_X (2 bytes)
VAR_F2_X             EQU $C880+$56   ; User variable: F2_X (2 bytes)
VAR_F3_X             EQU $C880+$58   ; User variable: F3_X (2 bytes)
VAR_TAB_X0           EQU $C880+$5A   ; User variable: TAB_X0 (2 bytes)
VAR_TAB_X1           EQU $C880+$5C   ; User variable: TAB_X1 (2 bytes)
VAR_TAB_X2           EQU $C880+$5E   ; User variable: TAB_X2 (2 bytes)
VAR_TAB_X3           EQU $C880+$60   ; User variable: TAB_X3 (2 bytes)
VAR_TAB_X4           EQU $C880+$62   ; User variable: TAB_X4 (2 bytes)
VAR_TAB_X5           EQU $C880+$64   ; User variable: TAB_X5 (2 bytes)
VAR_TAB_X6           EQU $C880+$66   ; User variable: TAB_X6 (2 bytes)
VAR_INT_CARD         EQU $C880+$68   ; User variable: INT_CARD (2 bytes)
VAR_INT_CURSOR       EQU $C880+$6A   ; User variable: INT_CURSOR (2 bytes)
VAR_INT_FACEDN       EQU $C880+$6C   ; User variable: INT_FACEDN (2 bytes)
VAR_INT_EMPTY        EQU $C880+$6E   ; User variable: INT_EMPTY (2 bytes)
VAR_INT_HELD         EQU $C880+$70   ; User variable: INT_HELD (2 bytes)
VAR_STATE_PLAY       EQU $C880+$72   ; User variable: STATE_PLAY (2 bytes)
VAR_STATE_WIN        EQU $C880+$74   ; User variable: STATE_WIN (2 bytes)
VAR_STK_SZ           EQU $C880+$76   ; User variable: stk_sz (2 bytes)
VAR_WST_SZ           EQU $C880+$78   ; User variable: wst_sz (2 bytes)
VAR_CURSOR           EQU $C880+$7A   ; User variable: cursor (2 bytes)
VAR_SEL_CARD         EQU $C880+$7C   ; User variable: sel_card (2 bytes)
VAR_SEL_SRC          EQU $C880+$7E   ; User variable: sel_src (2 bytes)
VAR_GAME_STATE       EQU $C880+$80   ; User variable: game_state (2 bytes)
VAR_WIN_BLINK        EQU $C880+$82   ; User variable: win_blink (2 bytes)
VAR_PREV_BTN1        EQU $C880+$84   ; User variable: prev_btn1 (2 bytes)
VAR_PREV_BTN2        EQU $C880+$86   ; User variable: prev_btn2 (2 bytes)
VAR_BTN1_FIRE        EQU $C880+$88   ; User variable: btn1_fire (2 bytes)
VAR_BTN2_FIRE        EQU $C880+$8A   ; User variable: btn2_fire (2 bytes)
VAR_PREV_JX          EQU $C880+$8C   ; User variable: prev_jx (2 bytes)
VAR_G_RESULT         EQU $C880+$8E   ; User variable: g_result (2 bytes)
VAR_G_COL_X          EQU $C880+$90   ; User variable: g_col_x (2 bytes)
VAR_G_CARD           EQU $C880+$92   ; User variable: g_card (2 bytes)
VAR_G_RANK           EQU $C880+$94   ; User variable: g_rank (2 bytes)
VAR_G_SUIT           EQU $C880+$96   ; User variable: g_suit (2 bytes)
VAR_G_SZ             EQU $C880+$98   ; User variable: g_sz (2 bytes)
VAR_G_HD             EQU $C880+$9A   ; User variable: g_hd (2 bytes)
VAR_G_IDX            EQU $C880+$9C   ; User variable: g_idx (2 bytes)
VAR_G_CY             EQU $C880+$9E   ; User variable: g_cy (2 bytes)
VAR_G_TIDX           EQU $C880+$A0   ; User variable: g_tidx (2 bytes)
VAR_G_TOP            EQU $C880+$A2   ; User variable: g_top (2 bytes)
VAR_G_TR             EQU $C880+$A4   ; User variable: g_tr (2 bytes)
VAR_G_TC             EQU $C880+$A6   ; User variable: g_tc (2 bytes)
VAR_G_TOP_RED        EQU $C880+$A8   ; User variable: g_top_red (2 bytes)
VAR_G_CARD_RED       EQU $C880+$AA   ; User variable: g_card_red (2 bytes)
VAR_G_PLACED         EQU $C880+$AC   ; User variable: g_placed (2 bytes)
VAR_DEAL_IDX         EQU $C880+$AE   ; User variable: deal_idx (2 bytes)
VAR_G_ROW            EQU $C880+$B0   ; User variable: g_row (2 bytes)
VAR_G_C              EQU $C880+$B2   ; User variable: g_c (2 bytes)
VAR_G_CX             EQU $C880+$B4   ; User variable: g_cx (2 bytes)
VAR_G_FC             EQU $C880+$B6   ; User variable: g_fc (2 bytes)
VAR_G_WCARD          EQU $C880+$B8   ; User variable: g_wcard (2 bytes)
VAR_G_FX             EQU $C880+$BA   ; User variable: g_fx (2 bytes)
VAR_DECK             EQU $C880+$BC   ; User variable: deck (2 bytes)
VAR_TAB_SZ           EQU $C880+$BE   ; User variable: tab_sz (2 bytes)
VAR_TAB_HID          EQU $C880+$C0   ; User variable: tab_hid (2 bytes)
VAR_FOUND_CNT        EQU $C880+$C2   ; User variable: found_cnt (2 bytes)
VAR_TAB              EQU $C880+$C4   ; User variable: tab (2 bytes)
VAR_STOCK            EQU $C880+$C6   ; User variable: stock (2 bytes)
VAR_WASTE            EQU $C880+$C8   ; User variable: waste (2 bytes)
VAR_CARD             EQU $C880+$CA   ; User variable: card (2 bytes)
VAR_COL              EQU $C880+$CC   ; User variable: col (2 bytes)
VAR_SUIT             EQU $C880+$CE   ; User variable: suit (2 bytes)
VAR_FX               EQU $C880+$D0   ; User variable: fx (2 bytes)
VAR_X                EQU $C880+$D2   ; User variable: x (2 bytes)
VAR_Y                EQU $C880+$D4   ; User variable: y (2 bytes)
VAR_INTENSITY        EQU $C880+$D6   ; User variable: intensity (2 bytes)
VAR_N                EQU $C880+$D8   ; User variable: n (2 bytes)
VAR_R                EQU $C880+$DA   ; User variable: r (2 bytes)
VAR_S                EQU $C880+$DC   ; User variable: s (2 bytes)
VAR_DECK_DATA        EQU $C880+$DE   ; Mutable array 'deck' data (52 elements x 2 bytes) (104 bytes)
VAR_TAB_DATA         EQU $C880+$146   ; Mutable array 'tab' data (140 elements x 2 bytes) (280 bytes)
VAR_TAB_SZ_DATA      EQU $C880+$25E   ; Mutable array 'tab_sz' data (7 elements x 2 bytes) (14 bytes)
VAR_TAB_HID_DATA     EQU $C880+$26C   ; Mutable array 'tab_hid' data (7 elements x 2 bytes) (14 bytes)
VAR_FOUND_CNT_DATA   EQU $C880+$27A   ; Mutable array 'found_cnt' data (4 elements x 2 bytes) (8 bytes)
VAR_STOCK_DATA       EQU $C880+$282   ; Mutable array 'stock' data (24 elements x 2 bytes) (48 bytes)
VAR_WASTE_DATA       EQU $C880+$2B2   ; Mutable array 'waste' data (24 elements x 2 bytes) (48 bytes)
VAR_ARG0             EQU $CB80   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $CB82   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $CB84   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $CB86   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $CB88   ; Function argument 4 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $CB8A   ; Current ROM bank ID (multibank tracking) (1 bytes)
; Array length constants
ARRAY_DECK_LEN         EQU 52   ; 52 elements
ARRAY_TAB_LEN         EQU 140   ; 140 elements
ARRAY_TAB_SZ_LEN         EQU 7   ; 7 elements
ARRAY_TAB_HID_LEN         EQU 7   ; 7 elements
ARRAY_FOUND_CNT_LEN         EQU 4   ; 4 elements
ARRAY_STOCK_LEN         EQU 24   ; 24 elements
ARRAY_WASTE_LEN         EQU 24   ; 24 elements

;***************************************************************************
; ARRAY DATA (ROM literals)
;***************************************************************************
; Arrays are stored in ROM and accessed via pointers
; At startup, main() initializes VAR_{name} to point to ARRAY_{name}_DATA

; Array literal for variable 'deck' (52 elements, 2 bytes each)
ARRAY_DECK_DATA:
    FDB 0   ; Element 0
    FDB 1   ; Element 1
    FDB 2   ; Element 2
    FDB 3   ; Element 3
    FDB 4   ; Element 4
    FDB 5   ; Element 5
    FDB 6   ; Element 6
    FDB 7   ; Element 7
    FDB 8   ; Element 8
    FDB 9   ; Element 9
    FDB 10   ; Element 10
    FDB 11   ; Element 11
    FDB 12   ; Element 12
    FDB 13   ; Element 13
    FDB 14   ; Element 14
    FDB 15   ; Element 15
    FDB 16   ; Element 16
    FDB 17   ; Element 17
    FDB 18   ; Element 18
    FDB 19   ; Element 19
    FDB 20   ; Element 20
    FDB 21   ; Element 21
    FDB 22   ; Element 22
    FDB 23   ; Element 23
    FDB 24   ; Element 24
    FDB 25   ; Element 25
    FDB 26   ; Element 26
    FDB 27   ; Element 27
    FDB 28   ; Element 28
    FDB 29   ; Element 29
    FDB 30   ; Element 30
    FDB 31   ; Element 31
    FDB 32   ; Element 32
    FDB 33   ; Element 33
    FDB 34   ; Element 34
    FDB 35   ; Element 35
    FDB 36   ; Element 36
    FDB 37   ; Element 37
    FDB 38   ; Element 38
    FDB 39   ; Element 39
    FDB 40   ; Element 40
    FDB 41   ; Element 41
    FDB 42   ; Element 42
    FDB 43   ; Element 43
    FDB 44   ; Element 44
    FDB 45   ; Element 45
    FDB 46   ; Element 46
    FDB 47   ; Element 47
    FDB 48   ; Element 48
    FDB 49   ; Element 49
    FDB 50   ; Element 50
    FDB 51   ; Element 51

; Array literal for variable 'tab' (140 elements, 2 bytes each)
ARRAY_TAB_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7
    FDB 0   ; Element 8
    FDB 0   ; Element 9
    FDB 0   ; Element 10
    FDB 0   ; Element 11
    FDB 0   ; Element 12
    FDB 0   ; Element 13
    FDB 0   ; Element 14
    FDB 0   ; Element 15
    FDB 0   ; Element 16
    FDB 0   ; Element 17
    FDB 0   ; Element 18
    FDB 0   ; Element 19
    FDB 0   ; Element 20
    FDB 0   ; Element 21
    FDB 0   ; Element 22
    FDB 0   ; Element 23
    FDB 0   ; Element 24
    FDB 0   ; Element 25
    FDB 0   ; Element 26
    FDB 0   ; Element 27
    FDB 0   ; Element 28
    FDB 0   ; Element 29
    FDB 0   ; Element 30
    FDB 0   ; Element 31
    FDB 0   ; Element 32
    FDB 0   ; Element 33
    FDB 0   ; Element 34
    FDB 0   ; Element 35
    FDB 0   ; Element 36
    FDB 0   ; Element 37
    FDB 0   ; Element 38
    FDB 0   ; Element 39
    FDB 0   ; Element 40
    FDB 0   ; Element 41
    FDB 0   ; Element 42
    FDB 0   ; Element 43
    FDB 0   ; Element 44
    FDB 0   ; Element 45
    FDB 0   ; Element 46
    FDB 0   ; Element 47
    FDB 0   ; Element 48
    FDB 0   ; Element 49
    FDB 0   ; Element 50
    FDB 0   ; Element 51
    FDB 0   ; Element 52
    FDB 0   ; Element 53
    FDB 0   ; Element 54
    FDB 0   ; Element 55
    FDB 0   ; Element 56
    FDB 0   ; Element 57
    FDB 0   ; Element 58
    FDB 0   ; Element 59
    FDB 0   ; Element 60
    FDB 0   ; Element 61
    FDB 0   ; Element 62
    FDB 0   ; Element 63
    FDB 0   ; Element 64
    FDB 0   ; Element 65
    FDB 0   ; Element 66
    FDB 0   ; Element 67
    FDB 0   ; Element 68
    FDB 0   ; Element 69
    FDB 0   ; Element 70
    FDB 0   ; Element 71
    FDB 0   ; Element 72
    FDB 0   ; Element 73
    FDB 0   ; Element 74
    FDB 0   ; Element 75
    FDB 0   ; Element 76
    FDB 0   ; Element 77
    FDB 0   ; Element 78
    FDB 0   ; Element 79
    FDB 0   ; Element 80
    FDB 0   ; Element 81
    FDB 0   ; Element 82
    FDB 0   ; Element 83
    FDB 0   ; Element 84
    FDB 0   ; Element 85
    FDB 0   ; Element 86
    FDB 0   ; Element 87
    FDB 0   ; Element 88
    FDB 0   ; Element 89
    FDB 0   ; Element 90
    FDB 0   ; Element 91
    FDB 0   ; Element 92
    FDB 0   ; Element 93
    FDB 0   ; Element 94
    FDB 0   ; Element 95
    FDB 0   ; Element 96
    FDB 0   ; Element 97
    FDB 0   ; Element 98
    FDB 0   ; Element 99
    FDB 0   ; Element 100
    FDB 0   ; Element 101
    FDB 0   ; Element 102
    FDB 0   ; Element 103
    FDB 0   ; Element 104
    FDB 0   ; Element 105
    FDB 0   ; Element 106
    FDB 0   ; Element 107
    FDB 0   ; Element 108
    FDB 0   ; Element 109
    FDB 0   ; Element 110
    FDB 0   ; Element 111
    FDB 0   ; Element 112
    FDB 0   ; Element 113
    FDB 0   ; Element 114
    FDB 0   ; Element 115
    FDB 0   ; Element 116
    FDB 0   ; Element 117
    FDB 0   ; Element 118
    FDB 0   ; Element 119
    FDB 0   ; Element 120
    FDB 0   ; Element 121
    FDB 0   ; Element 122
    FDB 0   ; Element 123
    FDB 0   ; Element 124
    FDB 0   ; Element 125
    FDB 0   ; Element 126
    FDB 0   ; Element 127
    FDB 0   ; Element 128
    FDB 0   ; Element 129
    FDB 0   ; Element 130
    FDB 0   ; Element 131
    FDB 0   ; Element 132
    FDB 0   ; Element 133
    FDB 0   ; Element 134
    FDB 0   ; Element 135
    FDB 0   ; Element 136
    FDB 0   ; Element 137
    FDB 0   ; Element 138
    FDB 0   ; Element 139

; Array literal for variable 'tab_sz' (7 elements, 2 bytes each)
ARRAY_TAB_SZ_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6

; Array literal for variable 'tab_hid' (7 elements, 2 bytes each)
ARRAY_TAB_HID_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6

; Array literal for variable 'found_cnt' (4 elements, 2 bytes each)
ARRAY_FOUND_CNT_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3

; Array literal for variable 'stock' (24 elements, 2 bytes each)
ARRAY_STOCK_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7
    FDB 0   ; Element 8
    FDB 0   ; Element 9
    FDB 0   ; Element 10
    FDB 0   ; Element 11
    FDB 0   ; Element 12
    FDB 0   ; Element 13
    FDB 0   ; Element 14
    FDB 0   ; Element 15
    FDB 0   ; Element 16
    FDB 0   ; Element 17
    FDB 0   ; Element 18
    FDB 0   ; Element 19
    FDB 0   ; Element 20
    FDB 0   ; Element 21
    FDB 0   ; Element 22
    FDB 0   ; Element 23

; Array literal for variable 'waste' (24 elements, 2 bytes each)
ARRAY_WASTE_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7
    FDB 0   ; Element 8
    FDB 0   ; Element 9
    FDB 0   ; Element 10
    FDB 0   ; Element 11
    FDB 0   ; Element 12
    FDB 0   ; Element 13
    FDB 0   ; Element 14
    FDB 0   ; Element 15
    FDB 0   ; Element 16
    FDB 0   ; Element 17
    FDB 0   ; Element 18
    FDB 0   ; Element 19
    FDB 0   ; Element 20
    FDB 0   ; Element 21
    FDB 0   ; Element 22
    FDB 0   ; Element 23


;***************************************************************************
; MAIN PROGRAM
;***************************************************************************

MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    LDA #$F8
    STA TEXT_SCALE_H      ; Default height = -8 (normal size)
    LDA #$48
    STA TEXT_SCALE_W      ; Default width = 72 (normal size)
    LDA #$7F
    STA DRAW_SCALE        ; Default T1 scale = $7F (127 = full BIOS scale)
    ; Copy array 'deck' from ROM to RAM (52 elements)
    LDX #ARRAY_DECK_DATA       ; Source: ROM array data
    LDU #VAR_DECK_DATA       ; Dest: RAM array space
    LDD #52        ; Number of elements
.COPY_LOOP_0:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_0 ; Loop until done (LBNE for long branch)
    LDX #VAR_DECK_DATA    ; Array now in RAM
    STX VAR_DECK
    ; Copy array 'tab' from ROM to RAM (140 elements)
    LDX #ARRAY_TAB_DATA       ; Source: ROM array data
    LDU #VAR_TAB_DATA       ; Dest: RAM array space
    LDD #140        ; Number of elements
.COPY_LOOP_1:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_1 ; Loop until done (LBNE for long branch)
    LDX #VAR_TAB_DATA    ; Array now in RAM
    STX VAR_TAB
    ; Copy array 'tab_sz' from ROM to RAM (7 elements)
    LDX #ARRAY_TAB_SZ_DATA       ; Source: ROM array data
    LDU #VAR_TAB_SZ_DATA       ; Dest: RAM array space
    LDD #7        ; Number of elements
.COPY_LOOP_2:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_2 ; Loop until done (LBNE for long branch)
    LDX #VAR_TAB_SZ_DATA    ; Array now in RAM
    STX VAR_TAB_SZ
    ; Copy array 'tab_hid' from ROM to RAM (7 elements)
    LDX #ARRAY_TAB_HID_DATA       ; Source: ROM array data
    LDU #VAR_TAB_HID_DATA       ; Dest: RAM array space
    LDD #7        ; Number of elements
.COPY_LOOP_3:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_3 ; Loop until done (LBNE for long branch)
    LDX #VAR_TAB_HID_DATA    ; Array now in RAM
    STX VAR_TAB_HID
    ; Copy array 'found_cnt' from ROM to RAM (4 elements)
    LDX #ARRAY_FOUND_CNT_DATA       ; Source: ROM array data
    LDU #VAR_FOUND_CNT_DATA       ; Dest: RAM array space
    LDD #4        ; Number of elements
.COPY_LOOP_4:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_4 ; Loop until done (LBNE for long branch)
    LDX #VAR_FOUND_CNT_DATA    ; Array now in RAM
    STX VAR_FOUND_CNT
    ; Copy array 'stock' from ROM to RAM (24 elements)
    LDX #ARRAY_STOCK_DATA       ; Source: ROM array data
    LDU #VAR_STOCK_DATA       ; Dest: RAM array space
    LDD #24        ; Number of elements
.COPY_LOOP_5:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_5 ; Loop until done (LBNE for long branch)
    LDX #VAR_STOCK_DATA    ; Array now in RAM
    STX VAR_STOCK
    LDD #0
    STD VAR_STK_SZ
    ; Copy array 'waste' from ROM to RAM (24 elements)
    LDX #ARRAY_WASTE_DATA       ; Source: ROM array data
    LDU #VAR_WASTE_DATA       ; Dest: RAM array space
    LDD #24        ; Number of elements
.COPY_LOOP_6:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_6 ; Loop until done (LBNE for long branch)
    LDX #VAR_WASTE_DATA    ; Array now in RAM
    STX VAR_WASTE
    LDD #0
    STD VAR_WST_SZ
    LDD #0
    STD VAR_CURSOR
    LDD #-1
    STD VAR_SEL_CARD
    LDD #-1
    STD VAR_SEL_SRC
    LDD #0  ; const STATE_PLAY
    STD VAR_GAME_STATE
    LDD #0
    STD VAR_WIN_BLINK
    LDD #0
    STD VAR_PREV_BTN1
    LDD #0
    STD VAR_PREV_BTN2
    LDD #0
    STD VAR_BTN1_FIRE
    LDD #0
    STD VAR_BTN2_FIRE
    LDD #0
    STD VAR_PREV_JX
    LDD #0
    STD VAR_G_RESULT
    LDD #0
    STD VAR_G_COL_X
    LDD #0
    STD VAR_G_CARD
    LDD #0
    STD VAR_G_RANK
    LDD #0
    STD VAR_G_SUIT
    LDD #0
    STD VAR_G_SZ
    LDD #0
    STD VAR_G_HD
    LDD #0
    STD VAR_G_IDX
    LDD #0
    STD VAR_G_CY
    LDD #0
    STD VAR_G_TIDX
    LDD #0
    STD VAR_G_TOP
    LDD #0
    STD VAR_G_TR
    LDD #0
    STD VAR_G_TC
    LDD #0
    STD VAR_G_TOP_RED
    LDD #0
    STD VAR_G_CARD_RED
    LDD #0
    STD VAR_G_PLACED
    LDD #0
    STD VAR_DEAL_IDX
    LDD #0
    STD VAR_G_ROW
    LDD #0
    STD VAR_G_C
    LDD #0
    STD VAR_G_CX
    LDD #0
    STD VAR_G_FC
    LDD #0
    STD VAR_G_WCARD
    LDD #0
    STD VAR_G_FX
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

    ; Prime BIOS button state at startup
    JSR $F1BA    ; Read_Btns: reads PSG reg14 -> $C80F, $C811, $C80E
    ; Call main() for initialization
    LDD #0  ; const STATE_PLAY
    STD VAR_GAME_STATE
    JSR shuffle
    JSR deal
    CLR >$C811  ; Force-clear Vec_Buttons before first loop() frame

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed
    BITA #$01
    BNE .J1B1_0_ON
    LDD #0
    BRA .J1B1_0_END
.J1B1_0_ON:
    LDD #1
.J1B1_0_END:
    STD RESULT
    STD VAR_G_CARD
    LDA >$C80F   ; Vec_Btns_1: bit1=1 means btn2 pressed
    BITA #$02
    BNE .J1B2_1_ON
    LDD #0
    BRA .J1B2_1_END
.J1B2_1_ON:
    LDD #1
.J1B2_1_END:
    STD RESULT
    STD VAR_G_RANK
    LDD #0
    STD VAR_BTN1_FIRE
    LDD #0
    STD VAR_BTN2_FIRE
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_CARD
    CMPD TMPVAL
    LBEQ .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    LBEQ .LOGIC_0_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_BTN1
    CMPD TMPVAL
    LBEQ .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    LBEQ .LOGIC_0_FALSE
    LDD #1
    LBRA .LOGIC_0_END
.LOGIC_0_FALSE:
    LDD #0
.LOGIC_0_END:
    LBEQ IF_NEXT_1
    LDD #1
    STD VAR_BTN1_FIRE
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_RANK
    CMPD TMPVAL
    LBEQ .CMP_4_TRUE
    LDD #0
    LBRA .CMP_4_END
.CMP_4_TRUE:
    LDD #1
.CMP_4_END:
    LBEQ .LOGIC_3_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_BTN2
    CMPD TMPVAL
    LBEQ .CMP_5_TRUE
    LDD #0
    LBRA .CMP_5_END
.CMP_5_TRUE:
    LDD #1
.CMP_5_END:
    LBEQ .LOGIC_3_FALSE
    LDD #1
    LBRA .LOGIC_3_END
.LOGIC_3_FALSE:
    LDD #0
.LOGIC_3_END:
    LBEQ IF_NEXT_3
    LDD #1
    STD VAR_BTN2_FIRE
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LDD >VAR_G_CARD
    STD VAR_PREV_BTN1
    LDD >VAR_G_RANK
    STD VAR_PREV_BTN2
    LDD #0  ; const STATE_PLAY
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_GAME_STATE
    CMPD TMPVAL
    LBEQ .CMP_6_TRUE
    LDD #0
    LBRA .CMP_6_END
.CMP_6_TRUE:
    LDD #1
.CMP_6_END:
    LBEQ IF_NEXT_5
    JSR update_input
    JSR draw_table
    JSR check_win
    LBRA IF_END_4
IF_NEXT_5:
    JSR draw_win_screen
IF_END_4:
    RTS

; Function: shuffle
shuffle:
    LDD #51
    STD VAR_G_C
WH_6: ; while start
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_C
    CMPD TMPVAL
    LBGT .CMP_7_TRUE
    LDD #0
    LBRA .CMP_7_END
.CMP_7_TRUE:
    LDD #1
.CMP_7_END:
    LBEQ WH_END_7
    ; RAND_RANGE: Random in range [min, max]
    LDD #0
    STD TMPPTR     ; Save min
    LDD >VAR_G_C
    STD TMPPTR2    ; Save max
    JSR RAND_RANGE_HELPER
    STD RESULT
    STD VAR_G_IDX
    LDX #VAR_DECK_DATA  ; Array base
    LDD >VAR_G_C
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_CARD
    LDD >VAR_G_C
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_DECK_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_DECK_DATA  ; Array base
    LDD >VAR_G_IDX
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD >VAR_G_IDX
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_DECK_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD >VAR_G_CARD
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD >VAR_G_C
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_G_C
    LBRA WH_6
WH_END_7: ; while end
    RTS

; Function: deal
deal:
    LDD #0
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_SZ_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #1
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_SZ_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #2
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_SZ_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #3
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_SZ_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #4
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_SZ_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #5
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_SZ_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #6
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_SZ_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #0
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_HID_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #1
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_HID_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #2
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_HID_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #3
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_HID_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #4
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_HID_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #5
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_HID_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #6
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_HID_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #0
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_FOUND_CNT_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #1
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_FOUND_CNT_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #2
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_FOUND_CNT_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #3
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_FOUND_CNT_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #0
    STD VAR_STK_SZ
    LDD #0
    STD VAR_WST_SZ
    LDD #-1
    STD VAR_SEL_CARD
    LDD #-1
    STD VAR_SEL_SRC
    LDD #0
    STD VAR_CURSOR
    LDD #0
    STD VAR_DEAL_IDX
    LDD #0
    STD VAR_G_C
WH_8: ; while start
    LDD #7
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_C
    CMPD TMPVAL
    LBLT .CMP_8_TRUE
    LDD #0
    LBRA .CMP_8_END
.CMP_8_TRUE:
    LDD #1
.CMP_8_END:
    LBEQ WH_END_9
    LDD #0
    STD VAR_G_ROW
WH_10: ; while start
    LDD >VAR_G_C
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_ROW
    CMPD TMPVAL
    LBLE .CMP_9_TRUE
    LDD #0
    LBRA .CMP_9_END
.CMP_9_TRUE:
    LDD #1
.CMP_9_END:
    LBEQ WH_END_11
    LDD >VAR_G_C
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #20
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_ROW
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_G_TIDX
    LDD >VAR_G_TIDX
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_DECK_DATA  ; Array base
    LDD >VAR_DEAL_IDX
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD >VAR_DEAL_IDX
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_DEAL_IDX
    LDD >VAR_G_ROW
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_G_ROW
    LBRA WH_10
WH_END_11: ; while end
    LDD >VAR_G_C
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_SZ_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD >VAR_G_C
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD >VAR_G_C
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_HID_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD >VAR_G_C
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD >VAR_G_C
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_G_C
    LBRA WH_8
WH_END_9: ; while end
    LDD #0
    STD VAR_G_ROW
WH_12: ; while start
    LDD #52
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DEAL_IDX
    CMPD TMPVAL
    LBLT .CMP_10_TRUE
    LDD #0
    LBRA .CMP_10_END
.CMP_10_TRUE:
    LDD #1
.CMP_10_END:
    LBEQ WH_END_13
    LDD >VAR_G_ROW
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_STOCK_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_DECK_DATA  ; Array base
    LDD >VAR_DEAL_IDX
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD >VAR_DEAL_IDX
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_DEAL_IDX
    LDD >VAR_G_ROW
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_G_ROW
    LBRA WH_12
WH_END_13: ; while end
    LDD >VAR_G_ROW
    STD VAR_STK_SZ
    RTS

; Function: update_input
update_input:
    JSR J1X_BUILTIN
    STD RESULT
    STD VAR_G_IDX
    LDD #0
    STD VAR_G_ROW
    LDD #40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_IDX
    CMPD TMPVAL
    LBGT .CMP_11_TRUE
    LDD #0
    LBRA .CMP_11_END
.CMP_11_TRUE:
    LDD #1
.CMP_11_END:
    LBEQ IF_NEXT_15
    LDD #1
    STD VAR_G_ROW
    LBRA IF_END_14
IF_NEXT_15:
    LDD #-40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_IDX
    CMPD TMPVAL
    LBLT .CMP_12_TRUE
    LDD #0
    LBRA .CMP_12_END
.CMP_12_TRUE:
    LDD #1
.CMP_12_END:
    LBEQ IF_END_14
    LDD #-1
    STD VAR_G_ROW
    LBRA IF_END_14
IF_END_14:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_ROW
    CMPD TMPVAL
    LBEQ .CMP_14_TRUE
    LDD #0
    LBRA .CMP_14_END
.CMP_14_TRUE:
    LDD #1
.CMP_14_END:
    LBEQ .LOGIC_13_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_JX
    CMPD TMPVAL
    LBEQ .CMP_15_TRUE
    LDD #0
    LBRA .CMP_15_END
.CMP_15_TRUE:
    LDD #1
.CMP_15_END:
    LBEQ .LOGIC_13_FALSE
    LDD #1
    LBRA .LOGIC_13_END
.LOGIC_13_FALSE:
    LDD #0
.LOGIC_13_END:
    LBEQ IF_NEXT_17
    LDD >VAR_CURSOR
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_CURSOR
    LDD #12
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURSOR
    CMPD TMPVAL
    LBGT .CMP_16_TRUE
    LDD #0
    LBRA .CMP_16_END
.CMP_16_TRUE:
    LDD #1
.CMP_16_END:
    LBEQ IF_NEXT_19
    LDD #0
    STD VAR_CURSOR
    LBRA IF_END_18
IF_NEXT_19:
IF_END_18:
    LBRA IF_END_16
IF_NEXT_17:
    LDD #-1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_ROW
    CMPD TMPVAL
    LBEQ .CMP_18_TRUE
    LDD #0
    LBRA .CMP_18_END
.CMP_18_TRUE:
    LDD #1
.CMP_18_END:
    LBEQ .LOGIC_17_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_JX
    CMPD TMPVAL
    LBEQ .CMP_19_TRUE
    LDD #0
    LBRA .CMP_19_END
.CMP_19_TRUE:
    LDD #1
.CMP_19_END:
    LBEQ .LOGIC_17_FALSE
    LDD #1
    LBRA .LOGIC_17_END
.LOGIC_17_FALSE:
    LDD #0
.LOGIC_17_END:
    LBEQ IF_END_16
    LDD >VAR_CURSOR
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_CURSOR
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURSOR
    CMPD TMPVAL
    LBLT .CMP_20_TRUE
    LDD #0
    LBRA .CMP_20_END
.CMP_20_TRUE:
    LDD #1
.CMP_20_END:
    LBEQ IF_NEXT_21
    LDD #12
    STD VAR_CURSOR
    LBRA IF_END_20
IF_NEXT_21:
IF_END_20:
    LBRA IF_END_16
IF_END_16:
    LDD >VAR_G_ROW
    STD VAR_PREV_JX
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN2_FIRE
    CMPD TMPVAL
    LBEQ .CMP_21_TRUE
    LDD #0
    LBRA .CMP_21_END
.CMP_21_TRUE:
    LDD #1
.CMP_21_END:
    LBEQ IF_NEXT_23
    JSR do_deal_stock
    LBRA IF_END_22
IF_NEXT_23:
IF_END_22:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN1_FIRE
    CMPD TMPVAL
    LBEQ .CMP_22_TRUE
    LDD #0
    LBRA .CMP_22_END
.CMP_22_TRUE:
    LDD #1
.CMP_22_END:
    LBEQ IF_NEXT_25
    LDD #-1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SEL_CARD
    CMPD TMPVAL
    LBEQ .CMP_23_TRUE
    LDD #0
    LBRA .CMP_23_END
.CMP_23_TRUE:
    LDD #1
.CMP_23_END:
    LBEQ IF_NEXT_27
    JSR do_pick_up
    LBRA IF_END_26
IF_NEXT_27:
    JSR do_place
IF_END_26:
    LBRA IF_END_24
IF_NEXT_25:
IF_END_24:
    RTS

; Function: do_deal_stock
do_deal_stock:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_STK_SZ
    CMPD TMPVAL
    LBGT .CMP_24_TRUE
    LDD #0
    LBRA .CMP_24_END
.CMP_24_TRUE:
    LDD #1
.CMP_24_END:
    LBEQ IF_NEXT_29
    LDD >VAR_STK_SZ
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_STK_SZ
    LDD >VAR_WST_SZ
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_WASTE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_STOCK_DATA  ; Array base
    LDD >VAR_STK_SZ
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD >VAR_WST_SZ
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_WST_SZ
    LBRA IF_END_28
IF_NEXT_29:
    LDD #0
    STD VAR_G_ROW
WH_30: ; while start
    LDD >VAR_WST_SZ
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_ROW
    CMPD TMPVAL
    LBLT .CMP_25_TRUE
    LDD #0
    LBRA .CMP_25_END
.CMP_25_TRUE:
    LDD #1
.CMP_25_END:
    LBEQ WH_END_31
    LDD >VAR_G_ROW
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_STOCK_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_WASTE_DATA  ; Array base
    LDD >VAR_G_ROW
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD >VAR_G_ROW
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_G_ROW
    LBRA WH_30
WH_END_31: ; while end
    LDD >VAR_WST_SZ
    STD VAR_STK_SZ
    LDD #0
    STD VAR_WST_SZ
IF_END_28:
    RTS

; Function: do_pick_up
do_pick_up:
    LDD #6
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURSOR
    CMPD TMPVAL
    LBLE .CMP_26_TRUE
    LDD #0
    LBRA .CMP_26_END
.CMP_26_TRUE:
    LDD #1
.CMP_26_END:
    LBEQ IF_NEXT_33
    LDD >VAR_CURSOR
    STD VAR_G_C
    LDX #VAR_TAB_SZ_DATA  ; Array base
    LDD >VAR_G_C
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_SZ
    LDX #VAR_TAB_HID_DATA  ; Array base
    LDD >VAR_G_C
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_HD
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_SZ
    CMPD TMPVAL
    LBGT .CMP_28_TRUE
    LDD #0
    LBRA .CMP_28_END
.CMP_28_TRUE:
    LDD #1
.CMP_28_END:
    LBEQ .LOGIC_27_FALSE
    LDD >VAR_G_HD
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_SZ
    CMPD TMPVAL
    LBGT .CMP_29_TRUE
    LDD #0
    LBRA .CMP_29_END
.CMP_29_TRUE:
    LDD #1
.CMP_29_END:
    LBEQ .LOGIC_27_FALSE
    LDD #1
    LBRA .LOGIC_27_END
.LOGIC_27_FALSE:
    LDD #0
.LOGIC_27_END:
    LBEQ IF_NEXT_35
    LDD >VAR_G_C
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #20
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_SZ
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_G_TIDX
    LDX #VAR_TAB_DATA  ; Array base
    LDD >VAR_G_TIDX
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_SEL_CARD
    LDD >VAR_CURSOR
    STD VAR_SEL_SRC
    LDD >VAR_G_C
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_SZ_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD >VAR_G_SZ
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_TAB_SZ_DATA  ; Array base
    LDD >VAR_G_C
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBGT .CMP_31_TRUE
    LDD #0
    LBRA .CMP_31_END
.CMP_31_TRUE:
    LDD #1
.CMP_31_END:
    LBEQ .LOGIC_30_FALSE
    LDX #VAR_TAB_HID_DATA  ; Array base
    LDD >VAR_G_C
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_TAB_SZ_DATA  ; Array base
    LDD >VAR_G_C
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBLE .CMP_32_TRUE
    LDD #0
    LBRA .CMP_32_END
.CMP_32_TRUE:
    LDD #1
.CMP_32_END:
    LBEQ .LOGIC_30_FALSE
    LDD #1
    LBRA .LOGIC_30_END
.LOGIC_30_FALSE:
    LDD #0
.LOGIC_30_END:
    LBEQ IF_NEXT_37
    LDD >VAR_G_C
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_HID_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_TAB_HID_DATA  ; Array base
    LDD >VAR_G_C
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LBRA IF_END_36
IF_NEXT_37:
IF_END_36:
    LBRA IF_END_34
IF_NEXT_35:
IF_END_34:
    LBRA IF_END_32
IF_NEXT_33:
    LDD #8
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURSOR
    CMPD TMPVAL
    LBEQ .CMP_33_TRUE
    LDD #0
    LBRA .CMP_33_END
.CMP_33_TRUE:
    LDD #1
.CMP_33_END:
    LBEQ IF_END_32
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_WST_SZ
    CMPD TMPVAL
    LBGT .CMP_34_TRUE
    LDD #0
    LBRA .CMP_34_END
.CMP_34_TRUE:
    LDD #1
.CMP_34_END:
    LBEQ IF_NEXT_39
    LDX #VAR_WASTE_DATA  ; Array base
    LDD >VAR_WST_SZ
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_SEL_CARD
    LDD #8
    STD VAR_SEL_SRC
    LDD >VAR_WST_SZ
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_WST_SZ
    LBRA IF_END_38
IF_NEXT_39:
IF_END_38:
    LBRA IF_END_32
IF_END_32:
    RTS

; Function: do_place
do_place:
    LDD #0
    STD VAR_G_PLACED
    LDD #6
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURSOR
    CMPD TMPVAL
    LBLE .CMP_35_TRUE
    LDD #0
    LBRA .CMP_35_END
.CMP_35_TRUE:
    LDD #1
.CMP_35_END:
    LBEQ IF_NEXT_41
    LDD >VAR_SEL_CARD
    STD VAR_ARG0
    LDD >VAR_CURSOR
    STD VAR_ARG1
    JSR can_move_to_tab
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_RESULT
    CMPD TMPVAL
    LBEQ .CMP_36_TRUE
    LDD #0
    LBRA .CMP_36_END
.CMP_36_TRUE:
    LDD #1
.CMP_36_END:
    LBEQ IF_NEXT_43
    LDD >VAR_CURSOR
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #20
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #VAR_TAB_SZ_DATA  ; Array base
    LDD >VAR_CURSOR
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_G_TIDX
    LDD >VAR_G_TIDX
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD >VAR_SEL_CARD
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD >VAR_CURSOR
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_SZ_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_TAB_SZ_DATA  ; Array base
    LDD >VAR_CURSOR
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #1
    STD VAR_G_PLACED
    LBRA IF_END_42
IF_NEXT_43:
IF_END_42:
    LBRA IF_END_40
IF_NEXT_41:
    LDD #9
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURSOR
    CMPD TMPVAL
    LBGE .CMP_38_TRUE
    LDD #0
    LBRA .CMP_38_END
.CMP_38_TRUE:
    LDD #1
.CMP_38_END:
    LBEQ .LOGIC_37_FALSE
    LDD #12
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURSOR
    CMPD TMPVAL
    LBLE .CMP_39_TRUE
    LDD #0
    LBRA .CMP_39_END
.CMP_39_TRUE:
    LDD #1
.CMP_39_END:
    LBEQ .LOGIC_37_FALSE
    LDD #1
    LBRA .LOGIC_37_END
.LOGIC_37_FALSE:
    LDD #0
.LOGIC_37_END:
    LBEQ IF_END_40
    LDD >VAR_CURSOR
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #9
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_G_SUIT
    LDD >VAR_SEL_CARD
    STD VAR_ARG0
    LDD >VAR_G_SUIT
    STD VAR_ARG1
    JSR can_move_to_found
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_RESULT
    CMPD TMPVAL
    LBEQ .CMP_40_TRUE
    LDD #0
    LBRA .CMP_40_END
.CMP_40_TRUE:
    LDD #1
.CMP_40_END:
    LBEQ IF_NEXT_45
    LDD >VAR_G_SUIT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_FOUND_CNT_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_FOUND_CNT_DATA  ; Array base
    LDD >VAR_G_SUIT
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #1
    STD VAR_G_PLACED
    LBRA IF_END_44
IF_NEXT_45:
IF_END_44:
    LBRA IF_END_40
IF_END_40:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_PLACED
    CMPD TMPVAL
    LBEQ .CMP_41_TRUE
    LDD #0
    LBRA .CMP_41_END
.CMP_41_TRUE:
    LDD #1
.CMP_41_END:
    LBEQ IF_NEXT_47
    LDD #-1
    STD VAR_SEL_CARD
    LDD #-1
    STD VAR_SEL_SRC
    LBRA IF_END_46
IF_NEXT_47:
    JSR return_card_to_src
IF_END_46:
    RTS

; Function: return_card_to_src
return_card_to_src:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SEL_SRC
    CMPD TMPVAL
    LBGE .CMP_43_TRUE
    LDD #0
    LBRA .CMP_43_END
.CMP_43_TRUE:
    LDD #1
.CMP_43_END:
    LBEQ .LOGIC_42_FALSE
    LDD #6
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SEL_SRC
    CMPD TMPVAL
    LBLE .CMP_44_TRUE
    LDD #0
    LBRA .CMP_44_END
.CMP_44_TRUE:
    LDD #1
.CMP_44_END:
    LBEQ .LOGIC_42_FALSE
    LDD #1
    LBRA .LOGIC_42_END
.LOGIC_42_FALSE:
    LDD #0
.LOGIC_42_END:
    LBEQ IF_NEXT_49
    LDD >VAR_SEL_SRC
    STD VAR_G_C
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_TAB_SZ_DATA  ; Array base
    LDD >VAR_G_C
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBGT .CMP_46_TRUE
    LDD #0
    LBRA .CMP_46_END
.CMP_46_TRUE:
    LDD #1
.CMP_46_END:
    LBEQ .LOGIC_45_FALSE
    LDX #VAR_TAB_HID_DATA  ; Array base
    LDD >VAR_G_C
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_TAB_SZ_DATA  ; Array base
    LDD >VAR_G_C
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_47_TRUE
    LDD #0
    LBRA .CMP_47_END
.CMP_47_TRUE:
    LDD #1
.CMP_47_END:
    LBEQ .LOGIC_45_FALSE
    LDD #1
    LBRA .LOGIC_45_END
.LOGIC_45_FALSE:
    LDD #0
.LOGIC_45_END:
    LBEQ IF_NEXT_51
    LDD >VAR_G_C
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_HID_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_TAB_HID_DATA  ; Array base
    LDD >VAR_G_C
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LBRA IF_END_50
IF_NEXT_51:
IF_END_50:
    LDD >VAR_G_C
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #20
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #VAR_TAB_SZ_DATA  ; Array base
    LDD >VAR_G_C
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_G_TIDX
    LDD >VAR_G_TIDX
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD >VAR_SEL_CARD
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD >VAR_G_C
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_SZ_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_TAB_SZ_DATA  ; Array base
    LDD >VAR_G_C
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LBRA IF_END_48
IF_NEXT_49:
    LDD #8
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SEL_SRC
    CMPD TMPVAL
    LBEQ .CMP_48_TRUE
    LDD #0
    LBRA .CMP_48_END
.CMP_48_TRUE:
    LDD #1
.CMP_48_END:
    LBEQ IF_END_48
    LDD >VAR_WST_SZ
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_WASTE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD >VAR_SEL_CARD
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD >VAR_WST_SZ
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_WST_SZ
    LBRA IF_END_48
IF_END_48:
    LDD #-1
    STD VAR_SEL_CARD
    LDD #-1
    STD VAR_SEL_SRC
    RTS

; Function: can_move_to_tab
can_move_to_tab:
    LDX #VAR_TAB_SZ_DATA  ; Array base
    LDD >VAR_ARG1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_SZ
    LDD >VAR_ARG0
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #4
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR DIV16       ; D = X / D
    STD VAR_G_RANK
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_SZ
    CMPD TMPVAL
    LBEQ .CMP_49_TRUE
    LDD #0
    LBRA .CMP_49_END
.CMP_49_TRUE:
    LDD #1
.CMP_49_END:
    LBEQ IF_NEXT_53
    LDD #12
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_RANK
    CMPD TMPVAL
    LBEQ .CMP_50_TRUE
    LDD #0
    LBRA .CMP_50_END
.CMP_50_TRUE:
    LDD #1
.CMP_50_END:
    LBEQ IF_NEXT_55
    LDD #1
    STD VAR_G_RESULT
    LBRA IF_END_54
IF_NEXT_55:
    LDD #0
    STD VAR_G_RESULT
IF_END_54:
    RTS
    LBRA IF_END_52
IF_NEXT_53:
IF_END_52:
    LDD >VAR_ARG1
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #20
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_SZ
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_G_TIDX
    LDX #VAR_TAB_DATA  ; Array base
    LDD >VAR_G_TIDX
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_TOP
    LDD >VAR_G_TOP
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #4
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR DIV16       ; D = X / D
    STD VAR_G_TR
    LDD >VAR_G_TOP
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_TR
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #4
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_G_TC
    LDD >VAR_ARG0
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_RANK
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #4
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_G_SUIT
    LDD #0
    STD VAR_G_TOP_RED
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_TC
    CMPD TMPVAL
    LBEQ .CMP_52_TRUE
    LDD #0
    LBRA .CMP_52_END
.CMP_52_TRUE:
    LDD #1
.CMP_52_END:
    LBNE .LOGIC_51_TRUE
    LDD #2
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_TC
    CMPD TMPVAL
    LBEQ .CMP_53_TRUE
    LDD #0
    LBRA .CMP_53_END
.CMP_53_TRUE:
    LDD #1
.CMP_53_END:
    LBNE .LOGIC_51_TRUE
    LDD #0
    LBRA .LOGIC_51_END
.LOGIC_51_TRUE:
    LDD #1
.LOGIC_51_END:
    LBEQ IF_NEXT_57
    LDD #1
    STD VAR_G_TOP_RED
    LBRA IF_END_56
IF_NEXT_57:
IF_END_56:
    LDD #0
    STD VAR_G_CARD_RED
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_SUIT
    CMPD TMPVAL
    LBEQ .CMP_55_TRUE
    LDD #0
    LBRA .CMP_55_END
.CMP_55_TRUE:
    LDD #1
.CMP_55_END:
    LBNE .LOGIC_54_TRUE
    LDD #2
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_SUIT
    CMPD TMPVAL
    LBEQ .CMP_56_TRUE
    LDD #0
    LBRA .CMP_56_END
.CMP_56_TRUE:
    LDD #1
.CMP_56_END:
    LBNE .LOGIC_54_TRUE
    LDD #0
    LBRA .LOGIC_54_END
.LOGIC_54_TRUE:
    LDD #1
.LOGIC_54_END:
    LBEQ IF_NEXT_59
    LDD #1
    STD VAR_G_CARD_RED
    LBRA IF_END_58
IF_NEXT_59:
IF_END_58:
    LDD >VAR_G_CARD_RED
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_TOP_RED
    CMPD TMPVAL
    LBEQ .CMP_57_TRUE
    LDD #0
    LBRA .CMP_57_END
.CMP_57_TRUE:
    LDD #1
.CMP_57_END:
    LBEQ IF_NEXT_61
    LDD #0
    STD VAR_G_RESULT
    RTS
    LBRA IF_END_60
IF_NEXT_61:
IF_END_60:
    LDD >VAR_G_TR
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_RANK
    CMPD TMPVAL
    LBEQ .CMP_58_TRUE
    LDD #0
    LBRA .CMP_58_END
.CMP_58_TRUE:
    LDD #1
.CMP_58_END:
    LBEQ IF_NEXT_63
    LDD #1
    STD VAR_G_RESULT
    LBRA IF_END_62
IF_NEXT_63:
    LDD #0
    STD VAR_G_RESULT
IF_END_62:
    RTS

; Function: can_move_to_found
can_move_to_found:
    LDD >VAR_ARG0
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #4
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR DIV16       ; D = X / D
    STD VAR_G_RANK
    LDD >VAR_ARG0
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_RANK
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #4
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_G_SUIT
    LDD >VAR_ARG1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_SUIT
    CMPD TMPVAL
    LBNE .CMP_59_TRUE
    LDD #0
    LBRA .CMP_59_END
.CMP_59_TRUE:
    LDD #1
.CMP_59_END:
    LBEQ IF_NEXT_65
    LDD #0
    STD VAR_G_RESULT
    RTS
    LBRA IF_END_64
IF_NEXT_65:
IF_END_64:
    LDX #VAR_FOUND_CNT_DATA  ; Array base
    LDD >VAR_ARG1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_FC
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_FC
    CMPD TMPVAL
    LBEQ .CMP_61_TRUE
    LDD #0
    LBRA .CMP_61_END
.CMP_61_TRUE:
    LDD #1
.CMP_61_END:
    LBEQ .LOGIC_60_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_RANK
    CMPD TMPVAL
    LBEQ .CMP_62_TRUE
    LDD #0
    LBRA .CMP_62_END
.CMP_62_TRUE:
    LDD #1
.CMP_62_END:
    LBEQ .LOGIC_60_FALSE
    LDD #1
    LBRA .LOGIC_60_END
.LOGIC_60_FALSE:
    LDD #0
.LOGIC_60_END:
    LBEQ IF_NEXT_67
    LDD #1
    STD VAR_G_RESULT
    RTS
    LBRA IF_END_66
IF_NEXT_67:
IF_END_66:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_FC
    CMPD TMPVAL
    LBGT .CMP_64_TRUE
    LDD #0
    LBRA .CMP_64_END
.CMP_64_TRUE:
    LDD #1
.CMP_64_END:
    LBEQ .LOGIC_63_FALSE
    LDD >VAR_G_FC
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_RANK
    CMPD TMPVAL
    LBEQ .CMP_65_TRUE
    LDD #0
    LBRA .CMP_65_END
.CMP_65_TRUE:
    LDD #1
.CMP_65_END:
    LBEQ .LOGIC_63_FALSE
    LDD #1
    LBRA .LOGIC_63_END
.LOGIC_63_FALSE:
    LDD #0
.LOGIC_63_END:
    LBEQ IF_NEXT_69
    LDD #1
    STD VAR_G_RESULT
    RTS
    LBRA IF_END_68
IF_NEXT_69:
IF_END_68:
    LDD #0
    STD VAR_G_RESULT
    RTS

; Function: check_win
check_win:
    LDD #13
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_FOUND_CNT_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_69_TRUE
    LDD #0
    LBRA .CMP_69_END
.CMP_69_TRUE:
    LDD #1
.CMP_69_END:
    LBEQ .LOGIC_68_FALSE
    LDD #13
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_FOUND_CNT_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_70_TRUE
    LDD #0
    LBRA .CMP_70_END
.CMP_70_TRUE:
    LDD #1
.CMP_70_END:
    LBEQ .LOGIC_68_FALSE
    LDD #1
    LBRA .LOGIC_68_END
.LOGIC_68_FALSE:
    LDD #0
.LOGIC_68_END:
    LBEQ .LOGIC_67_FALSE
    LDD #13
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_FOUND_CNT_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_71_TRUE
    LDD #0
    LBRA .CMP_71_END
.CMP_71_TRUE:
    LDD #1
.CMP_71_END:
    LBEQ .LOGIC_67_FALSE
    LDD #1
    LBRA .LOGIC_67_END
.LOGIC_67_FALSE:
    LDD #0
.LOGIC_67_END:
    LBEQ .LOGIC_66_FALSE
    LDD #13
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_FOUND_CNT_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_72_TRUE
    LDD #0
    LBRA .CMP_72_END
.CMP_72_TRUE:
    LDD #1
.CMP_72_END:
    LBEQ .LOGIC_66_FALSE
    LDD #1
    LBRA .LOGIC_66_END
.LOGIC_66_FALSE:
    LDD #0
.LOGIC_66_END:
    LBEQ IF_NEXT_71
    LDD #1  ; const STATE_WIN
    STD VAR_GAME_STATE
    LBRA IF_END_70
IF_NEXT_71:
IF_END_70:
    RTS

; Function: draw_table
draw_table:
    JSR draw_stock
    JSR draw_waste
    JSR draw_foundations
    JSR draw_tableau
    JSR draw_held_label
    JSR draw_cursor
    RTS

; Function: get_col_x
get_col_x:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_73_TRUE
    LDD #0
    LBRA .CMP_73_END
.CMP_73_TRUE:
    LDD #1
.CMP_73_END:
    LBEQ IF_NEXT_73
    LDD #-102  ; const TAB_X0
    STD VAR_G_COL_X
    LBRA IF_END_72
IF_NEXT_73:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_74_TRUE
    LDD #0
    LBRA .CMP_74_END
.CMP_74_TRUE:
    LDD #1
.CMP_74_END:
    LBEQ IF_NEXT_74
    LDD #-68  ; const TAB_X1
    STD VAR_G_COL_X
    LBRA IF_END_72
IF_NEXT_74:
    LDD #2
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_75_TRUE
    LDD #0
    LBRA .CMP_75_END
.CMP_75_TRUE:
    LDD #1
.CMP_75_END:
    LBEQ IF_NEXT_75
    LDD #-34  ; const TAB_X2
    STD VAR_G_COL_X
    LBRA IF_END_72
IF_NEXT_75:
    LDD #3
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_76_TRUE
    LDD #0
    LBRA .CMP_76_END
.CMP_76_TRUE:
    LDD #1
.CMP_76_END:
    LBEQ IF_NEXT_76
    LDD #0  ; const TAB_X3
    STD VAR_G_COL_X
    LBRA IF_END_72
IF_NEXT_76:
    LDD #4
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_77_TRUE
    LDD #0
    LBRA .CMP_77_END
.CMP_77_TRUE:
    LDD #1
.CMP_77_END:
    LBEQ IF_NEXT_77
    LDD #34  ; const TAB_X4
    STD VAR_G_COL_X
    LBRA IF_END_72
IF_NEXT_77:
    LDD #5
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_78_TRUE
    LDD #0
    LBRA .CMP_78_END
.CMP_78_TRUE:
    LDD #1
.CMP_78_END:
    LBEQ IF_NEXT_78
    LDD #68  ; const TAB_X5
    STD VAR_G_COL_X
    LBRA IF_END_72
IF_NEXT_78:
    LDD #102  ; const TAB_X6
    STD VAR_G_COL_X
IF_END_72:
    RTS

; Function: draw_stock
draw_stock:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_STK_SZ
    CMPD TMPVAL
    LBGT .CMP_79_TRUE
    LDD #0
    LBRA .CMP_79_END
.CMP_79_TRUE:
    LDD #1
.CMP_79_END:
    LBEQ IF_NEXT_80
    ; ERROR: DRAW_RECT with variables requires expressions module access
    ; Use constant values for now
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #40  ; const INT_FACEDN
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-102  ; const STK_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #4
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG0
    LDD #85  ; const TOP_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #10
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_1120      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_79
IF_NEXT_80:
    ; ERROR: DRAW_RECT with variables requires expressions module access
    ; Use constant values for now
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #25  ; const INT_EMPTY
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-102  ; const STK_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #4
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG0
    LDD #85  ; const TOP_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #10
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2657      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
IF_END_79:
    RTS

; Function: draw_waste
draw_waste:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_WST_SZ
    CMPD TMPVAL
    LBGT .CMP_80_TRUE
    LDD #0
    LBRA .CMP_80_END
.CMP_80_TRUE:
    LDD #1
.CMP_80_END:
    LBEQ IF_NEXT_82
    LDX #VAR_WASTE_DATA  ; Array base
    LDD >VAR_WST_SZ
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_WCARD
    LDD #-68  ; const WST_X
    STD VAR_ARG0
    LDD #85  ; const TOP_Y
    STD VAR_ARG1
    LDD >VAR_G_WCARD
    STD VAR_ARG2
    LDD #70  ; const INT_CARD
    STD VAR_ARG3
    JSR draw_card
    LBRA IF_END_81
IF_NEXT_82:
    ; ERROR: DRAW_RECT with variables requires expressions module access
    ; Use constant values for now
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #25  ; const INT_EMPTY
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-68  ; const WST_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #4
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG0
    LDD #85  ; const TOP_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #10
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2780      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
IF_END_81:
    RTS

; Function: draw_foundations
draw_foundations:
    LDD #0  ; const F0_X
    STD VAR_G_FX
    LDD >VAR_G_FX
    STD VAR_ARG0
    LDD #0
    STD VAR_ARG1
    JSR draw_one_foundation
    LDD #34  ; const F1_X
    STD VAR_G_FX
    LDD >VAR_G_FX
    STD VAR_ARG0
    LDD #1
    STD VAR_ARG1
    JSR draw_one_foundation
    LDD #68  ; const F2_X
    STD VAR_G_FX
    LDD >VAR_G_FX
    STD VAR_ARG0
    LDD #2
    STD VAR_ARG1
    JSR draw_one_foundation
    LDD #102  ; const F3_X
    STD VAR_G_FX
    LDD >VAR_G_FX
    STD VAR_ARG0
    LDD #3
    STD VAR_ARG1
    JSR draw_one_foundation
    RTS

; Function: draw_one_foundation
draw_one_foundation:
    LDX #VAR_FOUND_CNT_DATA  ; Array base
    LDD >VAR_ARG1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_FC
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_FC
    CMPD TMPVAL
    LBEQ .CMP_81_TRUE
    LDD #0
    LBRA .CMP_81_END
.CMP_81_TRUE:
    LDD #1
.CMP_81_END:
    LBEQ IF_NEXT_84
    ; ERROR: DRAW_RECT with variables requires expressions module access
    ; Use constant values for now
    LDD #0
    STD RESULT
    LDD >VAR_ARG0
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #13  ; const HALF_W
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG0
    LDD #85  ; const TOP_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #13  ; const HALF_W
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG1
    LDD >VAR_ARG1
    STD VAR_ARG2
    JSR draw_suit_at
    LBRA IF_END_83
IF_NEXT_84:
    LDD >VAR_G_FC
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_G_RANK
    LDD >VAR_G_RANK
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #4
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_G_CARD
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD #85  ; const TOP_Y
    STD VAR_ARG1
    LDD >VAR_G_CARD
    STD VAR_ARG2
    LDD #70  ; const INT_CARD
    STD VAR_ARG3
    JSR draw_card
IF_END_83:
    RTS

; Function: draw_tableau
draw_tableau:
    LDD #0
    STD VAR_G_C
WH_85: ; while start
    LDD #7
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_C
    CMPD TMPVAL
    LBLT .CMP_82_TRUE
    LDD #0
    LBRA .CMP_82_END
.CMP_82_TRUE:
    LDD #1
.CMP_82_END:
    LBEQ WH_END_86
    LDD >VAR_G_C
    STD VAR_ARG0
    JSR get_col_x
    LDD >VAR_G_COL_X
    STD VAR_G_CX
    LDX #VAR_TAB_SZ_DATA  ; Array base
    LDD >VAR_G_C
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_SZ
    LDX #VAR_TAB_HID_DATA  ; Array base
    LDD >VAR_G_C
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_HD
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_SZ
    CMPD TMPVAL
    LBEQ .CMP_83_TRUE
    LDD #0
    LBRA .CMP_83_END
.CMP_83_TRUE:
    LDD #1
.CMP_83_END:
    LBEQ IF_NEXT_88
    ; ERROR: DRAW_RECT with variables requires expressions module access
    ; Use constant values for now
    LDD #0
    STD RESULT
    LBRA IF_END_87
IF_NEXT_88:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_HD
    CMPD TMPVAL
    LBGT .CMP_84_TRUE
    LDD #0
    LBRA .CMP_84_END
.CMP_84_TRUE:
    LDD #1
.CMP_84_END:
    LBEQ IF_NEXT_90
    ; ERROR: DRAW_RECT with variables requires expressions module access
    ; Use constant values for now
    LDD #0
    STD RESULT
    ; ERROR: DRAW_RECT with variables requires expressions module access
    ; Use constant values for now
    LDD #0
    STD RESULT
    LBRA IF_END_89
IF_NEXT_90:
IF_END_89:
    LDD >VAR_G_HD
    STD VAR_G_ROW
    LDD #0
    STD VAR_G_IDX
WH_91: ; while start
    LDD >VAR_G_SZ
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_ROW
    CMPD TMPVAL
    LBLT .CMP_86_TRUE
    LDD #0
    LBRA .CMP_86_END
.CMP_86_TRUE:
    LDD #1
.CMP_86_END:
    LBEQ .LOGIC_85_FALSE
    LDD #4
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_IDX
    CMPD TMPVAL
    LBLT .CMP_87_TRUE
    LDD #0
    LBRA .CMP_87_END
.CMP_87_TRUE:
    LDD #1
.CMP_87_END:
    LBEQ .LOGIC_85_FALSE
    LDD #1
    LBRA .LOGIC_85_END
.LOGIC_85_FALSE:
    LDD #0
.LOGIC_85_END:
    LBEQ WH_END_92
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_HD
    CMPD TMPVAL
    LBGT .CMP_88_TRUE
    LDD #0
    LBRA .CMP_88_END
.CMP_88_TRUE:
    LDD #1
.CMP_88_END:
    LBEQ IF_NEXT_94
    LDD #30  ; const TAB_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #32  ; const CARD_H
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_ROW
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_HD
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #14  ; const COL_DY
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_G_CY
    LBRA IF_END_93
IF_NEXT_94:
    LDD #30  ; const TAB_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_ROW
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_HD
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #14  ; const COL_DY
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_G_CY
IF_END_93:
    LDD >VAR_G_C
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #20
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_ROW
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_G_TIDX
    LDX #VAR_TAB_DATA  ; Array base
    LDD >VAR_G_TIDX
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_CARD
    LDD >VAR_G_CX
    STD VAR_ARG0
    LDD >VAR_G_CY
    STD VAR_ARG1
    LDD >VAR_G_CARD
    STD VAR_ARG2
    LDD #70  ; const INT_CARD
    STD VAR_ARG3
    JSR draw_card
    LDD >VAR_G_ROW
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_G_ROW
    LDD >VAR_G_IDX
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_G_IDX
    LBRA WH_91
WH_END_92: ; while end
IF_END_87:
    LDD >VAR_G_C
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_G_C
    LBRA WH_85
WH_END_86: ; while end
    RTS

; Function: draw_held_label
draw_held_label:
    LDD #-1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SEL_CARD
    CMPD TMPVAL
    LBNE .CMP_89_TRUE
    LDD #0
    LBRA .CMP_89_END
.CMP_89_TRUE:
    LDD #1
.CMP_89_END:
    LBEQ IF_NEXT_96
    ; SET_INTENSITY: Set drawing intensity
    LDD #100  ; const INT_HELD
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD VAR_ARG0
    LDD #-100
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_68624293      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD >VAR_SEL_CARD
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #4
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR DIV16       ; D = X / D
    STD VAR_G_RANK
    LDD >VAR_SEL_CARD
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_RANK
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #4
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_G_SUIT
    LDD #-15
    STD VAR_ARG0
    LDD #-100
    STD VAR_ARG1
    LDD >VAR_G_RANK
    STD VAR_ARG2
    JSR draw_rank_at
    LDD #0
    STD VAR_ARG0
    LDD #-100
    STD VAR_ARG1
    LDD >VAR_G_SUIT
    STD VAR_ARG2
    JSR draw_suit_at
    LBRA IF_END_95
IF_NEXT_96:
IF_END_95:
    RTS

; Function: draw_cursor
draw_cursor:
    LDD #0
    STD VAR_G_CX
    LDD #85  ; const TOP_Y
    STD VAR_G_CY
    LDD #7
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURSOR
    CMPD TMPVAL
    LBEQ .CMP_90_TRUE
    LDD #0
    LBRA .CMP_90_END
.CMP_90_TRUE:
    LDD #1
.CMP_90_END:
    LBEQ IF_NEXT_98
    LDD #-102  ; const STK_X
    STD VAR_G_CX
    LBRA IF_END_97
IF_NEXT_98:
    LDD #8
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURSOR
    CMPD TMPVAL
    LBEQ .CMP_91_TRUE
    LDD #0
    LBRA .CMP_91_END
.CMP_91_TRUE:
    LDD #1
.CMP_91_END:
    LBEQ IF_NEXT_99
    LDD #-68  ; const WST_X
    STD VAR_G_CX
    LBRA IF_END_97
IF_NEXT_99:
    LDD #9
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURSOR
    CMPD TMPVAL
    LBEQ .CMP_92_TRUE
    LDD #0
    LBRA .CMP_92_END
.CMP_92_TRUE:
    LDD #1
.CMP_92_END:
    LBEQ IF_NEXT_100
    LDD #0  ; const F0_X
    STD VAR_G_CX
    LBRA IF_END_97
IF_NEXT_100:
    LDD #10
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURSOR
    CMPD TMPVAL
    LBEQ .CMP_93_TRUE
    LDD #0
    LBRA .CMP_93_END
.CMP_93_TRUE:
    LDD #1
.CMP_93_END:
    LBEQ IF_NEXT_101
    LDD #34  ; const F1_X
    STD VAR_G_CX
    LBRA IF_END_97
IF_NEXT_101:
    LDD #11
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURSOR
    CMPD TMPVAL
    LBEQ .CMP_94_TRUE
    LDD #0
    LBRA .CMP_94_END
.CMP_94_TRUE:
    LDD #1
.CMP_94_END:
    LBEQ IF_NEXT_102
    LDD #68  ; const F2_X
    STD VAR_G_CX
    LBRA IF_END_97
IF_NEXT_102:
    LDD #12
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURSOR
    CMPD TMPVAL
    LBEQ .CMP_95_TRUE
    LDD #0
    LBRA .CMP_95_END
.CMP_95_TRUE:
    LDD #1
.CMP_95_END:
    LBEQ IF_NEXT_103
    LDD #102  ; const F3_X
    STD VAR_G_CX
    LBRA IF_END_97
IF_NEXT_103:
    LDD >VAR_CURSOR
    STD VAR_ARG0
    JSR get_col_x
    LDD >VAR_G_COL_X
    STD VAR_G_CX
    LDX #VAR_TAB_SZ_DATA  ; Array base
    LDD >VAR_CURSOR
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_SZ
    LDX #VAR_TAB_HID_DATA  ; Array base
    LDD >VAR_CURSOR
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_HD
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_SZ
    CMPD TMPVAL
    LBEQ .CMP_96_TRUE
    LDD #0
    LBRA .CMP_96_END
.CMP_96_TRUE:
    LDD #1
.CMP_96_END:
    LBEQ IF_NEXT_105
    LDD #30  ; const TAB_Y
    STD VAR_G_CY
    LBRA IF_END_104
IF_NEXT_105:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_HD
    CMPD TMPVAL
    LBEQ .CMP_97_TRUE
    LDD #0
    LBRA .CMP_97_END
.CMP_97_TRUE:
    LDD #1
.CMP_97_END:
    LBEQ IF_NEXT_106
    LDD #30  ; const TAB_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_SZ
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #14  ; const COL_DY
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_G_CY
    LBRA IF_END_104
IF_NEXT_106:
    LDD #30  ; const TAB_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #32  ; const CARD_H
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_SZ
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_HD
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #14  ; const COL_DY
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_G_CY
IF_END_104:
IF_END_97:
    ; SET_INTENSITY: Set drawing intensity
    LDD #127  ; const INT_CURSOR
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
    ; ERROR: DRAW_RECT with variables requires expressions module access
    ; Use constant values for now
    LDD #0
    STD RESULT
    RTS

; Function: draw_card
draw_card:
    ; ERROR: DRAW_RECT with variables requires expressions module access
    ; Use constant values for now
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD >VAR_ARG3
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
    LDD >VAR_ARG2
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #4
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR DIV16       ; D = X / D
    STD VAR_G_RANK
    LDD >VAR_ARG2
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_RANK
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #4
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_G_SUIT
    LDD >VAR_ARG0
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #3
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #26
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG1
    LDD >VAR_G_RANK
    STD VAR_ARG2
    JSR draw_rank_at
    LDD >VAR_ARG0
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #13  ; const HALF_W
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #12
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG1
    LDD >VAR_G_SUIT
    STD VAR_ARG2
    JSR draw_suit_at
    RTS

; Function: draw_small_count
draw_small_count:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG2
    CMPD TMPVAL
    LBEQ .CMP_98_TRUE
    LDD #0
    LBRA .CMP_98_END
.CMP_98_TRUE:
    LDD #1
.CMP_98_END:
    LBEQ IF_NEXT_108
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_49      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_107
IF_NEXT_108:
    LDD #2
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG2
    CMPD TMPVAL
    LBEQ .CMP_99_TRUE
    LDD #0
    LBRA .CMP_99_END
.CMP_99_TRUE:
    LDD #1
.CMP_99_END:
    LBEQ IF_NEXT_109
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_50      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_107
IF_NEXT_109:
    LDD #3
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG2
    CMPD TMPVAL
    LBEQ .CMP_100_TRUE
    LDD #0
    LBRA .CMP_100_END
.CMP_100_TRUE:
    LDD #1
.CMP_100_END:
    LBEQ IF_NEXT_110
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_51      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_107
IF_NEXT_110:
    LDD #4
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG2
    CMPD TMPVAL
    LBEQ .CMP_101_TRUE
    LDD #0
    LBRA .CMP_101_END
.CMP_101_TRUE:
    LDD #1
.CMP_101_END:
    LBEQ IF_NEXT_111
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_52      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_107
IF_NEXT_111:
    LDD #5
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG2
    CMPD TMPVAL
    LBEQ .CMP_102_TRUE
    LDD #0
    LBRA .CMP_102_END
.CMP_102_TRUE:
    LDD #1
.CMP_102_END:
    LBEQ IF_NEXT_112
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_53      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_107
IF_NEXT_112:
    LDD #6
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG2
    CMPD TMPVAL
    LBEQ .CMP_103_TRUE
    LDD #0
    LBRA .CMP_103_END
.CMP_103_TRUE:
    LDD #1
.CMP_103_END:
    LBEQ IF_NEXT_113
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_54      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_107
IF_NEXT_113:
    LDD #7
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG2
    CMPD TMPVAL
    LBEQ .CMP_104_TRUE
    LDD #0
    LBRA .CMP_104_END
.CMP_104_TRUE:
    LDD #1
.CMP_104_END:
    LBEQ IF_NEXT_114
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_55      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_107
IF_NEXT_114:
    LDD #8
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG2
    CMPD TMPVAL
    LBEQ .CMP_105_TRUE
    LDD #0
    LBRA .CMP_105_END
.CMP_105_TRUE:
    LDD #1
.CMP_105_END:
    LBEQ IF_NEXT_115
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_56      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_107
IF_NEXT_115:
    LDD #9
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG2
    CMPD TMPVAL
    LBEQ .CMP_106_TRUE
    LDD #0
    LBRA .CMP_106_END
.CMP_106_TRUE:
    LDD #1
.CMP_106_END:
    LBEQ IF_NEXT_116
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_57      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_107
IF_NEXT_116:
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_43      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
IF_END_107:
    RTS

; Function: draw_rank_at
draw_rank_at:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG2
    CMPD TMPVAL
    LBEQ .CMP_107_TRUE
    LDD #0
    LBRA .CMP_107_END
.CMP_107_TRUE:
    LDD #1
.CMP_107_END:
    LBEQ IF_NEXT_118
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_65      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_117
IF_NEXT_118:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG2
    CMPD TMPVAL
    LBEQ .CMP_108_TRUE
    LDD #0
    LBRA .CMP_108_END
.CMP_108_TRUE:
    LDD #1
.CMP_108_END:
    LBEQ IF_NEXT_119
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_50      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_117
IF_NEXT_119:
    LDD #2
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG2
    CMPD TMPVAL
    LBEQ .CMP_109_TRUE
    LDD #0
    LBRA .CMP_109_END
.CMP_109_TRUE:
    LDD #1
.CMP_109_END:
    LBEQ IF_NEXT_120
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_51      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_117
IF_NEXT_120:
    LDD #3
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG2
    CMPD TMPVAL
    LBEQ .CMP_110_TRUE
    LDD #0
    LBRA .CMP_110_END
.CMP_110_TRUE:
    LDD #1
.CMP_110_END:
    LBEQ IF_NEXT_121
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_52      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_117
IF_NEXT_121:
    LDD #4
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG2
    CMPD TMPVAL
    LBEQ .CMP_111_TRUE
    LDD #0
    LBRA .CMP_111_END
.CMP_111_TRUE:
    LDD #1
.CMP_111_END:
    LBEQ IF_NEXT_122
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_53      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_117
IF_NEXT_122:
    LDD #5
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG2
    CMPD TMPVAL
    LBEQ .CMP_112_TRUE
    LDD #0
    LBRA .CMP_112_END
.CMP_112_TRUE:
    LDD #1
.CMP_112_END:
    LBEQ IF_NEXT_123
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_54      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_117
IF_NEXT_123:
    LDD #6
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG2
    CMPD TMPVAL
    LBEQ .CMP_113_TRUE
    LDD #0
    LBRA .CMP_113_END
.CMP_113_TRUE:
    LDD #1
.CMP_113_END:
    LBEQ IF_NEXT_124
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_55      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_117
IF_NEXT_124:
    LDD #7
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG2
    CMPD TMPVAL
    LBEQ .CMP_114_TRUE
    LDD #0
    LBRA .CMP_114_END
.CMP_114_TRUE:
    LDD #1
.CMP_114_END:
    LBEQ IF_NEXT_125
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_56      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_117
IF_NEXT_125:
    LDD #8
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG2
    CMPD TMPVAL
    LBEQ .CMP_115_TRUE
    LDD #0
    LBRA .CMP_115_END
.CMP_115_TRUE:
    LDD #1
.CMP_115_END:
    LBEQ IF_NEXT_126
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_57      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_117
IF_NEXT_126:
    LDD #9
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG2
    CMPD TMPVAL
    LBEQ .CMP_116_TRUE
    LDD #0
    LBRA .CMP_116_END
.CMP_116_TRUE:
    LDD #1
.CMP_116_END:
    LBEQ IF_NEXT_127
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_1567      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_117
IF_NEXT_127:
    LDD #10
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG2
    CMPD TMPVAL
    LBEQ .CMP_117_TRUE
    LDD #0
    LBRA .CMP_117_END
.CMP_117_TRUE:
    LDD #1
.CMP_117_END:
    LBEQ IF_NEXT_128
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_74      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_117
IF_NEXT_128:
    LDD #11
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG2
    CMPD TMPVAL
    LBEQ .CMP_118_TRUE
    LDD #0
    LBRA .CMP_118_END
.CMP_118_TRUE:
    LDD #1
.CMP_118_END:
    LBEQ IF_NEXT_129
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_81      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_117
IF_NEXT_129:
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD >VAR_ARG1
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_75      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
IF_END_117:
    RTS

; Function: draw_suit_at
draw_suit_at:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG2
    CMPD TMPVAL
    LBEQ .CMP_119_TRUE
    LDD #0
    LBRA .CMP_119_END
.CMP_119_TRUE:
    LDD #1
.CMP_119_END:
    LBEQ IF_NEXT_131
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: suit_clubs (index=0, 5 paths)
    LDD >VAR_ARG0
    TFR B,A       ; X position (low byte) — B already holds it
    STA TMPPTR    ; Save X to temporary storage
    LDD >VAR_ARG1
    TFR B,A       ; Y position (low byte) — B already holds it
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_SUIT_CLUBS_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_SUIT_CLUBS_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_SUIT_CLUBS_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_SUIT_CLUBS_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_SUIT_CLUBS_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Reset: next DRAW_VECTOR uses .vec intensities
    LDD #0
    STD RESULT
    LBRA IF_END_130
IF_NEXT_131:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG2
    CMPD TMPVAL
    LBEQ .CMP_120_TRUE
    LDD #0
    LBRA .CMP_120_END
.CMP_120_TRUE:
    LDD #1
.CMP_120_END:
    LBEQ IF_NEXT_132
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: suit_diamonds (index=1, 1 paths)
    LDD >VAR_ARG0
    TFR B,A       ; X position (low byte) — B already holds it
    STA TMPPTR    ; Save X to temporary storage
    LDD >VAR_ARG1
    TFR B,A       ; Y position (low byte) — B already holds it
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_SUIT_DIAMONDS_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Reset: next DRAW_VECTOR uses .vec intensities
    LDD #0
    STD RESULT
    LBRA IF_END_130
IF_NEXT_132:
    LDD #2
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG2
    CMPD TMPVAL
    LBEQ .CMP_121_TRUE
    LDD #0
    LBRA .CMP_121_END
.CMP_121_TRUE:
    LDD #1
.CMP_121_END:
    LBEQ IF_NEXT_133
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: suit_hearts (index=2, 1 paths)
    LDD >VAR_ARG0
    TFR B,A       ; X position (low byte) — B already holds it
    STA TMPPTR    ; Save X to temporary storage
    LDD >VAR_ARG1
    TFR B,A       ; Y position (low byte) — B already holds it
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_SUIT_HEARTS_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Reset: next DRAW_VECTOR uses .vec intensities
    LDD #0
    STD RESULT
    LBRA IF_END_130
IF_NEXT_133:
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: suit_spades (index=3, 3 paths)
    LDD >VAR_ARG0
    TFR B,A       ; X position (low byte) — B already holds it
    STA TMPPTR    ; Save X to temporary storage
    LDD >VAR_ARG1
    TFR B,A       ; Y position (low byte) — B already holds it
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_SUIT_SPADES_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_SUIT_SPADES_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_SUIT_SPADES_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Reset: next DRAW_VECTOR uses .vec intensities
    LDD #0
    STD RESULT
IF_END_130:
    RTS

; Function: draw_win_screen
draw_win_screen:
    LDD >VAR_WIN_BLINK
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_WIN_BLINK
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-42
    STD VAR_ARG0
    LDD #30
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2521201141606      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-63
    STD VAR_ARG0
    LDD #0
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_3321124269434895794      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD #30
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_WIN_BLINK
    CMPD TMPVAL
    LBLT .CMP_122_TRUE
    LDD #0
    LBRA .CMP_122_END
.CMP_122_TRUE:
    LDD #1
.CMP_122_END:
    LBEQ IF_NEXT_135
    ; SET_INTENSITY: Set drawing intensity
    LDD #60
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-63
    STD VAR_ARG0
    LDD #-30
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2487248696027089637      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_134
IF_NEXT_135:
IF_END_134:
    LDD #60
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_WIN_BLINK
    CMPD TMPVAL
    LBGE .CMP_123_TRUE
    LDD #0
    LBRA .CMP_123_END
.CMP_123_TRUE:
    LDD #1
.CMP_123_END:
    LBEQ IF_NEXT_137
    LDD #0
    STD VAR_WIN_BLINK
    LBRA IF_END_136
IF_NEXT_137:
IF_END_136:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN1_FIRE
    CMPD TMPVAL
    LBEQ .CMP_124_TRUE
    LDD #0
    LBRA .CMP_124_END
.CMP_124_TRUE:
    LDD #1
.CMP_124_END:
    LBEQ IF_NEXT_139
    LDD #0  ; const STATE_PLAY
    STD VAR_GAME_STATE
    JSR shuffle
    JSR deal
    LBRA IF_END_138
IF_NEXT_139:
IF_END_138:
    RTS

;***************************************************************************
; EMBEDDED ASSETS (vectors, music, levels, SFX)
;***************************************************************************

; Generated from suit_clubs.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 22
; X bounds: min=-5, max=5, width=10
; Center: (0, 0)

_SUIT_CLUBS_WIDTH EQU 10
_SUIT_CLUBS_HALF_WIDTH EQU 5
_SUIT_CLUBS_HEIGHT EQU 11
_SUIT_CLUBS_HALF_HEIGHT EQU 5
_SUIT_CLUBS_CENTER_X EQU 0
_SUIT_CLUBS_CENTER_Y EQU 0

_SUIT_CLUBS_VECTORS:  ; Main entry (header + 5 path(s))
    FDB 5               ; path_count (runtime metadata, 2 bytes)
    FDB _SUIT_CLUBS_PATH0        ; pointer to path 0
    FDB _SUIT_CLUBS_PATH1        ; pointer to path 1
    FDB _SUIT_CLUBS_PATH2        ; pointer to path 2
    FDB _SUIT_CLUBS_PATH3        ; pointer to path 3
    FDB _SUIT_CLUBS_PATH4        ; pointer to path 4

_SUIT_CLUBS_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FF,$00,0,0        ; path0: header (y=-1, x=0)
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_SUIT_CLUBS_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $FB,$FE,0,0        ; path1: header (y=-5, x=-2)
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB 2                ; End marker (path complete)

_SUIT_CLUBS_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $FF,$04,0,0        ; path2: header (y=-1, x=4)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB 2                ; End marker (path complete)

_SUIT_CLUBS_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $02,$01,0,0        ; path3: header (y=2, x=1)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB 2                ; End marker (path complete)

_SUIT_CLUBS_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $01,$FF,0,0        ; path4: header (y=1, x=-1)
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB 2                ; End marker (path complete)
; Generated from suit_diamonds.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 4
; X bounds: min=-5, max=5, width=10
; Center: (0, 0)

_SUIT_DIAMONDS_WIDTH EQU 10
_SUIT_DIAMONDS_HALF_WIDTH EQU 5
_SUIT_DIAMONDS_HEIGHT EQU 14
_SUIT_DIAMONDS_HALF_HEIGHT EQU 7
_SUIT_DIAMONDS_CENTER_X EQU 0
_SUIT_DIAMONDS_CENTER_Y EQU 0

_SUIT_DIAMONDS_VECTORS:  ; Main entry (header + 1 path(s))
    FDB 1               ; path_count (runtime metadata, 2 bytes)
    FDB _SUIT_DIAMONDS_PATH0        ; pointer to path 0

_SUIT_DIAMONDS_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $07,$00,0,0        ; path0: header (y=7, x=0)
    FCB $FF,$F9,$05          ; flag=-1, dy=-7, dx=5
    FCB $FF,$F9,$FB          ; flag=-1, dy=-7, dx=-5
    FCB $FF,$07,$FB          ; flag=-1, dy=7, dx=-5
    FCB $FF,$07,$05          ; flag=-1, dy=7, dx=5
    FCB 2                ; End marker (path complete)
; Generated from suit_hearts.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 10
; X bounds: min=-6, max=6, width=12
; Center: (0, 0)

_SUIT_HEARTS_WIDTH EQU 12
_SUIT_HEARTS_HALF_WIDTH EQU 6
_SUIT_HEARTS_HEIGHT EQU 13
_SUIT_HEARTS_HALF_HEIGHT EQU 6
_SUIT_HEARTS_CENTER_X EQU 0
_SUIT_HEARTS_CENTER_Y EQU 0

_SUIT_HEARTS_VECTORS:  ; Main entry (header + 1 path(s))
    FDB 1               ; path_count (runtime metadata, 2 bytes)
    FDB _SUIT_HEARTS_PATH0        ; pointer to path 0

_SUIT_HEARTS_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FA,$00,0,0        ; path0: header (y=-6, x=0)
    FCB $FF,$05,$05          ; flag=-1, dy=5, dx=5
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$04,$FE          ; flag=-1, dy=4, dx=-2
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$FF,$FD          ; flag=-1, dy=-1, dx=-3
    FCB $FF,$FC,$FE          ; flag=-1, dy=-4, dx=-2
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$FB,$05          ; flag=-1, dy=-5, dx=5
    FCB 2                ; End marker (path complete)
; Generated from suit_spades.vec (Malban Draw_Sync_List format)
; Total paths: 3, points: 14
; X bounds: min=-6, max=6, width=12
; Center: (0, 0)

_SUIT_SPADES_WIDTH EQU 12
_SUIT_SPADES_HALF_WIDTH EQU 6
_SUIT_SPADES_HEIGHT EQU 14
_SUIT_SPADES_HALF_HEIGHT EQU 7
_SUIT_SPADES_CENTER_X EQU 0
_SUIT_SPADES_CENTER_Y EQU 0

_SUIT_SPADES_VECTORS:  ; Main entry (header + 3 path(s))
    FDB 3               ; path_count (runtime metadata, 2 bytes)
    FDB _SUIT_SPADES_PATH0        ; pointer to path 0
    FDB _SUIT_SPADES_PATH1        ; pointer to path 1
    FDB _SUIT_SPADES_PATH2        ; pointer to path 2

_SUIT_SPADES_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FC,$00,0,0        ; path0: header (y=-4, x=0)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_SUIT_SPADES_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $F9,$FD,0,0        ; path1: header (y=-7, x=-3)
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB 2                ; End marker (path complete)

_SUIT_SPADES_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $02,$FB,0,0        ; path2: header (y=2, x=-5)
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$FC,$02          ; flag=-1, dy=-4, dx=2
    FCB $FF,$FF,$03          ; flag=-1, dy=-1, dx=3
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$01,$03          ; flag=-1, dy=1, dx=3
    FCB $FF,$04,$02          ; flag=-1, dy=4, dx=2
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$05,$FB          ; flag=-1, dy=5, dx=-5
    FCB $FF,$FB,$FB          ; flag=-1, dy=-5, dx=-5
    FCB 2                ; End marker (path complete)
;***************************************************************************
; RUNTIME HELPERS
;***************************************************************************

VECTREX_PRINT_TEXT:
    ; VPy signature: PRINT_TEXT(x, y, string)
    ; BIOS signature: Print_Str_d(A=Y, B=X, U=string)
    ; NOTE: Do NOT set VIA_cntl=$98 here - would release /ZERO prematurely
    ;       causing integrators to drift toward joystick DAC value.
    ;       Moveto_d_7F (called by Print_Str_d) handles VIA_cntl via $CE.
    LDA #$D0
    TFR A,DP       ; Set Direct Page to $D0 for BIOS
    JSR Intensity_5F ; Ensure consistent text brightness (DP=$D0 required)
    JSR Reset0Ref   ; Reset beam to center before positioning text
    LDU VAR_ARG2   ; string pointer
    LDA >TEXT_SCALE_H ; height (signed byte, e.g. $F8=-8)
    STA >$C82A      ; Vec_Text_Height: controls character Y scale
    LDA >TEXT_SCALE_W ; width (unsigned byte, e.g. 72)
    STA >$C82B      ; Vec_Text_Width: controls character X spacing
    LDA >VAR_ARG1+1 ; Y coordinate
    LDB >VAR_ARG0+1 ; X coordinate
    JSR Print_Str_d
    LDA #$F8
    STA >$C82A      ; Restore Vec_Text_Height to normal (-8)
    LDA #$48
    STA >$C82B      ; Restore Vec_Text_Width to normal (72)
    JSR $F1AF      ; DP_to_C8 - restore DP before return
    RTS

MUL16:
    ; Multiply 16-bit X * D -> D
    ; Simple implementation (can be optimized)
    PSHS X,B,A
    LDD #0         ; Result accumulator
    LDX 2,S        ; Multiplier
.MUL16_LOOP:
    BEQ .MUL16_END
    ADDD ,S        ; Add multiplicand
    LEAX -1,X
    BRA .MUL16_LOOP
.MUL16_END:
    LEAS 4,S
    RTS

DIV16:
    ; Signed 16-bit division: D = X / D
    ; X = dividend (i16), D = divisor (i16) -> D = quotient
    STD TMPPTR          ; Save divisor
    TFR X,D             ; D = dividend (TFR does NOT set flags!)
    CMPD #0             ; Set flags from FULL D BEFORE any LDA corrupts high byte
    BPL .D16_DPOS       ; if dividend >= 0, skip negation
    COMA
    COMB
    ADDD #1             ; D = |dividend|
    STD TMPVAL          ; store |dividend| BEFORE LDA corrupts A (high byte of D)
    LDA #1
    STA TMPPTR2         ; sign_flag = 1 (dividend was negative)
    BRA .D16_RCHECK
.D16_DPOS:
    STD TMPVAL          ; dividend is positive, store as-is
    LDA #0
    STA TMPPTR2         ; sign_flag = 0 (positive result)
.D16_RCHECK:
    LDD TMPPTR          ; D = divisor
    BPL .D16_RPOS       ; if divisor >= 0, skip negation
    COMA
    COMB
    ADDD #1             ; D = |divisor|
    STD TMPPTR          ; TMPPTR = |divisor|
    LDA TMPPTR2
    EORA #1
    STA TMPPTR2         ; toggle sign flag (XOR with 1)
.D16_RPOS:
    LDD #0
    STD RESULT          ; quotient = 0
.D16_LOOP:
    LDD TMPVAL
    SUBD TMPPTR         ; |dividend| - |divisor|
    BLO .D16_END        ; if |dividend| < |divisor|, done
    STD TMPVAL          ; update remainder
    LDD RESULT
    ADDD #1
    STD RESULT          ; quotient++
    BRA .D16_LOOP
.D16_END:
    LDD RESULT          ; D = unsigned quotient
    LDA TMPPTR2
    BEQ .D16_DONE       ; zero = positive result
    COMA
    COMB
    ADDD #1             ; negate for negative result
.D16_DONE:
    RTS

MOD16:
    ; Signed 16-bit modulo: D = X % D (result has same sign as dividend)
    ; X = dividend (i16), D = divisor (i16) -> D = remainder
    STD TMPPTR          ; Save divisor
    TFR X,D             ; D = dividend (TFR does NOT set flags!)
    CMPD #0             ; Set flags from FULL D BEFORE any LDA corrupts high byte
    BPL .M16_DPOS       ; if dividend >= 0, skip negation
    COMA
    COMB
    ADDD #1             ; D = |dividend|
    STD TMPVAL          ; store |dividend| BEFORE LDA corrupts A (high byte of D)
    LDA #1
    STA TMPPTR2         ; sign_flag = 1
    BRA .M16_RCHECK
.M16_DPOS:
    STD TMPVAL          ; dividend is positive, store as-is
    LDA #0
    STA TMPPTR2         ; sign_flag = 0 (positive result)
.M16_RCHECK:
    LDD TMPPTR          ; D = divisor
    BPL .M16_RPOS       ; if divisor >= 0, skip negation
    COMA
    COMB
    ADDD #1             ; D = |divisor|
    STD TMPPTR          ; TMPPTR = |divisor|
.M16_RPOS:
.M16_LOOP:
    LDD TMPVAL
    SUBD TMPPTR         ; |dividend| - |divisor|
    BLO .M16_END        ; if |dividend| < |divisor|, done
    STD TMPVAL          ; update remainder
    BRA .M16_LOOP
.M16_END:
    LDD TMPVAL          ; D = |remainder|
    LDA TMPPTR2
    BEQ .M16_DONE       ; zero = positive result
    COMA
    COMB
    ADDD #1             ; negate (same sign as dividend)
.M16_DONE:
    RTS

RAND_HELPER:
    ; LCG: seed = (seed * 1103515245 + 12345) & 0x7FFF
    ; Simplified for 6809: seed = (seed * 25 + 13) & 0x7FFF
    LDD RAND_SEED
    LDX #26
    ; Multiply by 25: loop runs 25 times (LCG a=25, Hull-Dobell ok)
    PSHS D
    LDD #0
RAND_MUL_LOOP:
    LEAX -1,X
    BEQ RAND_MUL_DONE
    ADDD ,S
    BRA RAND_MUL_LOOP
RAND_MUL_DONE:
    LEAS 2,S
    ADDD #13       ; Add constant c=13 (odd, Hull-Dobell ok)
    STD RAND_SEED  ; Store full 16-bit state BEFORE masking output
    ANDA #$7F      ; Mask output to positive 15-bit (state stays full)
    RTS

RAND_RANGE_HELPER:
    ; Input: TMPPTR = min (i16), TMPPTR2 = max (i16)
    ; Returns: D = min + (rand % (max - min + 1))
    JSR RAND_HELPER        ; D = rand (0..$7FFF)
    PSHS D                 ; Save rand
    LDD TMPPTR2            ; max
    SUBD TMPPTR            ; D = max - min
    ADDD #1                ; D = inclusive range
    STD TMPPTR2            ; TMPPTR2 = range
    PULS D                 ; Restore rand
RRH_MOD:
    SUBD TMPPTR2           ; D -= range
    BCC RRH_MOD            ; if no borrow (D >= range), keep subtracting
    ADDD TMPPTR2           ; Undo last subtract: now 0 <= D < range
    ADDD TMPPTR            ; Add min -> D in [min, max]
    RTS

; === JOYSTICK BUILTIN SUBROUTINES ===
; J1_X() - Read Joystick 1 X axis (INCREMENTAL - with state preservation)
; Returns: D = raw value from $C81B after Joy_Analog call
J1X_BUILTIN:
    PSHS X       ; Save X (Joy_Analog uses it)
    JSR $F1AA    ; DP_to_D0 (required for Joy_Analog BIOS call)
    JSR $F1F5    ; Joy_Analog (updates $C81B from hardware)
    JSR Reset0Ref ; Full beam reset: zeros DAC (VIA_port_a=0) via Reset_Pen + grounds integrators
    JSR $F1AF    ; DP_to_C8 (required to read RAM $C81B)
    LDB $C81B    ; Vec_Joy_1_X (BIOS writes ~$FE at center)
    SEX          ; Sign-extend B to D
    ADDD #2      ; Calibrate center offset
    PULS X       ; Restore X
    RTS

DRAW_RECT_RUNTIME:
    ; Input: DRAW_RECT_X, DRAW_RECT_Y, DRAW_RECT_WIDTH, DRAW_RECT_HEIGHT, DRAW_RECT_INTENSITY
    ; Draws 4 sides of rectangle
    
    ; Save parameters to stack before DP change
    LDB DRAW_RECT_INTENSITY
    PSHS B
    LDB DRAW_RECT_HEIGHT
    PSHS B
    LDB DRAW_RECT_WIDTH
    PSHS B
    LDB DRAW_RECT_Y
    PSHS B
    LDB DRAW_RECT_X
    PSHS B
    
    ; Setup BIOS
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$80
    STA <$04            ; VIA_t1_cnt_lo = $80 (ensure correct scale)
    
    ; Set intensity
    LDA 4,S             ; intensity
    JSR Intensity_a
    
    ; Move to starting position (x, y)
    LDA 1,S             ; y
    LDB ,S              ; x
    JSR Moveto_d_7F
    
    ; Draw right side
    CLR Vec_Misc_Count
    LDA #0
    LDB 2,S             ; width
    JSR Draw_Line_d
    
    ; Draw down side
    CLR Vec_Misc_Count
    LDA 3,S             ; height
    NEGA                ; -height
    LDB #0
    JSR Draw_Line_d
    
    ; Draw left side
    CLR Vec_Misc_Count
    LDA #0
    LDB 2,S             ; width
    NEGB                ; -width
    JSR Draw_Line_d
    
    ; Draw up side
    CLR Vec_Misc_Count
    LDA 2,S             ; height
    NEGA                ; -height
    LDB #0
    JSR Draw_Line_d
    
    LDA #$C8
    TFR A,DP            ; Restore DP=$C8 before return
    LEAS 5,S            ; Clean stack
    RTS

Draw_Sync_List_At_With_Mirrors:
; Unified mirror support using flags: MIRROR_X and MIRROR_Y
; Conditionally negates X and/or Y coordinates and deltas
; NOTE: Caller must ensure DP=$D0 for VIA access
; Z-axis intensity: use exact BIOS Intensity_a sequence (PB=$05->$04, PA=val, PB=$00->$01)
; Caller (DRAW_ANIM_RUNTIME, DRAW_VECTOR) ensures DP=$D0 before JSR here.
LDA ,X+                 ; Read per-path intensity from vector data
DSWM_SET_INTENSITY:
TST >DRAW_VEC_INTENSITY  ; 0 = no override, use FCB value
BEQ DSWM_USE_FCB_INT
LDA >DRAW_VEC_INTENSITY  ; non-zero override (from SET_INTENSITY)
DSWM_USE_FCB_INT:
STA >$C832              ; Update BIOS variable (Vec_Misc_Count)
PSHS A                  ; save brightness
LDA #$05
STA >$D000              ; PB=$05: pre-condition Z-axis (mirrors BIOS Intensity_a)
LDA #$04
STA >$D000              ; PB=$04: select Z-axis channel
PULS A                  ; restore brightness
STA >$D001              ; PA=brightness while Z-axis selected -> charges S/H
LDA #$00
STA >$D000              ; PB=$00: deselect all channels
LDA #$01
STA >$D000              ; PB=$01: restore X-integrator channel
LDB ,X+                 ; y_start from .vec (already relative to center)
; Check if Y mirroring is enabled
TST >MIRROR_Y
BEQ DSWM_NO_NEGATE_Y
NEGB                    ; ← Negate Y if flag set
DSWM_NO_NEGATE_Y:
ADDB >DRAW_VEC_Y        ; Add Y offset
LDA ,X+                 ; x_start from .vec (already relative to center)
; Check if X mirroring is enabled
TST >MIRROR_X
BEQ DSWM_NO_NEGATE_X
NEGA                    ; ← Negate X if flag set
DSWM_NO_NEGATE_X:
ADDA >DRAW_VEC_X        ; Add X offset
STD >TEMP_YX            ; Save adjusted position
; Reset completo
CLR VIA_shift_reg
LDA #$CC
STA VIA_cntl
CLR VIA_port_a
LDA #$03
STA VIA_port_b          ; PB=$03: disable mux (Reset_Pen step 1)
LDA #$02
STA VIA_port_b          ; PB=$02: enable mux (Reset_Pen step 2)
LDA #$02
STA VIA_port_b          ; repeat
LDA #$01
STA VIA_port_b          ; PB=$01: disable mux (integrators zeroed)
; Moveto (BIOS Moveto_d: Y->PA, CLR PB, settle, #CE, CLR SR, INC PB, X->PA)
LDD >TEMP_YX
STB VIA_port_a          ; Y to DAC (PB=1: integrators hold)
CLR VIA_port_b          ; PB=0: enable mux, beam tracks Y
PSHS A                  ; ~4 cycle settling delay for Y
LDA #$CE
STA VIA_cntl            ; PCR=$CE: /ZERO high, integrators active
CLR VIA_shift_reg       ; SR=0: no draw during moveto
INC VIA_port_b          ; PB=1: disable mux, lock direction at Y
PULS A                  ; Restore X
STA VIA_port_a          ; X to DAC
; T1 scale from DRAW_SCALE variable ($7F=normal)
LDA >DRAW_SCALE
STA VIA_t1_cnt_lo
CLR VIA_t1_cnt_hi
LEAX 2,X                ; Skip next_y, next_x
; Wait for move to complete (PB=1 on exit)
DSWM_W1:
LDA VIA_int_flags
ANDA #$40
BEQ DSWM_W1
; PB stays 1 — draw loop begins with PB=1
; Loop de dibujo (conditional mirrors)
DSWM_LOOP:
LDA ,X+                 ; Read flag
CMPA #2                 ; Check end marker
LBEQ DSWM_DONE
CMPA #1                 ; Check next path marker
LBEQ DSWM_NEXT_PATH
; Draw line with conditional negations
LDB ,X+                 ; dy
; Check if Y mirroring is enabled
TST >MIRROR_Y
BEQ DSWM_NO_NEGATE_DY
NEGB                    ; ← Negate dy if flag set
DSWM_NO_NEGATE_DY:
LDA ,X+                 ; dx
; Check if X mirroring is enabled
TST >MIRROR_X
BEQ DSWM_NO_NEGATE_DX
NEGA                    ; ← Negate dx if flag set
DSWM_NO_NEGATE_DX:
; B=DY_final, A=DX_final, PB=1 on entry (from moveto or previous segment)
STB VIA_port_a          ; DY to DAC (PB=1: integrators hold position)
CLR VIA_port_b          ; PB=0: enable mux, beam tracks DY direction
NOP                     ; settling 1 (per BIOS Draw_Line_d: LEAX+NOP = ~7 cycles)
NOP                     ; settling 2
NOP                     ; settling 3
INC VIA_port_b          ; PB=1: disable mux, lock direction at DY
STA VIA_port_a          ; DX to DAC
LDA #$FF
STA VIA_shift_reg       ; beam ON first (ramp still off from T1PB7)
CLR VIA_t1_cnt_hi       ; THEN start T1 -> ramp ON (BIOS order)
; Wait for line draw
DSWM_W2:
LDA VIA_int_flags
ANDA #$40
BEQ DSWM_W2
CLR VIA_port_a          ; PA=0: stop X integrator FIRST (alg_xsh=128=rsh → dx=0)
CLR VIA_port_b          ; PB=0: Y mux enabled → ysh=0 (stop Y integrator)
INC VIA_port_b          ; PB=1: Y mux hold (lock Y at 0)
CLR VIA_shift_reg       ; beam off (rate=0 so no drift during these 3 insns)
LBRA DSWM_LOOP          ; Long branch
; Next path: repeat mirror logic for new path header
DSWM_NEXT_PATH:
TFR X,D
PSHS D
; Read per-path intensity from vector data (check DRAW_VEC_INTENSITY override)
LDA ,X+                 ; Read FCB intensity from vector data
DSWM_NEXT_SET_INTENSITY:
TST >DRAW_VEC_INTENSITY  ; 0 = no override, use FCB
BEQ DSWM_NEXT_USE_FCB_INT
LDA >DRAW_VEC_INTENSITY  ; non-zero override
DSWM_NEXT_USE_FCB_INT:
PSHS A                  ; save intensity for later
LDB ,X+                 ; y_start
TST >MIRROR_Y
BEQ DSWM_NEXT_NO_NEGATE_Y
NEGB
DSWM_NEXT_NO_NEGATE_Y:
ADDB >DRAW_VEC_Y        ; Add Y offset
LDA ,X+                 ; x_start
TST >MIRROR_X
BEQ DSWM_NEXT_NO_NEGATE_X
NEGA
DSWM_NEXT_NO_NEGATE_X:
ADDA >DRAW_VEC_X        ; Add X offset
STD >TEMP_YX
PULS A                  ; restore intensity
STA >$C832              ; Update BIOS variable (Vec_Misc_Count)
PSHS A                  ; save brightness for Z-axis write
LDA #$05
STA >$D000              ; PB=$05: pre-condition (BIOS Intensity_a step 1)
LDA #$04
STA >$D000              ; PB=$04: select Z-axis channel
PULS A                  ; restore brightness
STA >$D001              ; PA=brightness while Z-axis selected
LDA #$00
STA >$D000              ; PB=$00: deselect
LDA #$01
STA >$D000              ; PB=$01: restore X-integrator channel
PULS D
ADDD #3
TFR D,X
; Reset to zero
CLR VIA_shift_reg
LDA #$CC
STA VIA_cntl
CLR VIA_port_a
LDA #$03
STA VIA_port_b          ; PB=$03: disable mux (Reset_Pen step 1)
LDA #$02
STA VIA_port_b          ; PB=$02: enable mux (Reset_Pen step 2)
LDA #$02
STA VIA_port_b          ; repeat
LDA #$01
STA VIA_port_b          ; PB=$01: disable mux (integrators zeroed)
; Moveto new start position (BIOS Moveto_d order)
LDD >TEMP_YX
STB VIA_port_a          ; Y to DAC (PB=1: integrators hold)
CLR VIA_port_b          ; PB=0: enable mux, beam tracks Y
PSHS A                  ; ~4 cycle settling delay for Y
LDA #$CE
STA VIA_cntl            ; PCR=$CE: /ZERO high, integrators active
CLR VIA_shift_reg       ; SR=0: no draw during moveto
INC VIA_port_b          ; PB=1: disable mux, lock direction at Y
PULS A
STA VIA_port_a          ; X to DAC
; T1 scale from DRAW_SCALE variable ($7F=normal)
LDA >DRAW_SCALE
STA VIA_t1_cnt_lo
CLR VIA_t1_cnt_hi
LEAX 2,X
; Wait for move (PB=1 on exit)
DSWM_W3:
LDA VIA_int_flags
ANDA #$40
BEQ DSWM_W3
; PB stays 1 — draw loop continues with PB=1
LBRA DSWM_LOOP          ; Long branch
DSWM_DONE:
RTS
;**** PRINT_TEXT String Data ****
PRINT_TEXT_STR_43:
    FCC "+"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_49:
    FCC "1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_50:
    FCC "2"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_51:
    FCC "3"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_52:
    FCC "4"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_53:
    FCC "5"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_54:
    FCC "6"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_55:
    FCC "7"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_56:
    FCC "8"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_57:
    FCC "9"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_65:
    FCC "A"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_74:
    FCC "J"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_75:
    FCC "K"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_81:
    FCC "Q"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1120:
    FCC "##"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1567:
    FCC "10"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2657:
    FCC "ST"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2780:
    FCC "WS"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_68624293:
    FCC "HELD:"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2521201141606:
    FCC "YOU WIN!"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3143339389297355:
    FCC "suit_clubs"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_97443521204318815:
    FCC "suit_hearts"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_97443521529384288:
    FCC "suit_spades"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1409503402297413265:
    FCC "suit_diamonds"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2487248696027089637:
    FCC "PRESS B1 TO PLAY"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3321124269434895794:
    FCC "ALL SUITS COMPLETE"
    FCB $80          ; Vectrex string terminator

