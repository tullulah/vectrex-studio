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
    LDS #$CFFF       ; Stack -> top of Vectrex 2KB RAM (avoids user var collision)

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
SLR_CUR_X            EQU $C880+$2B   ; DRAW_VECTOR: clamped (visible) beam X for clipping (1 bytes)
SLR_TRUE_X           EQU $C880+$2C   ; DRAW_VECTOR: 16-bit unclamped abs_x for line clipping (2 bytes)
DRAW_T1_SCALED       EQU $C880+$2E   ; DRAW_VECTOR: T1 scale ($7F default for non-SHOW_LEVEL) (1 bytes)
SDCP_ABS_Y           EQU $C880+$2F   ; DRAW_VECTOR: abs_y temporary for SDCP (cannot share TMPVAL — would corrupt SHOW_LEVEL's top_screen between layers) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$30   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$3A   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$3C   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$3E   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$3F   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$40   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$42   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$44   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$45   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
DRAW_SCALE           EQU $C880+$46   ; Current T1 scale for Draw_Sync_List_At_With_Mirrors ($7F=normal) (1 bytes)
VAR_ARG0             EQU $C880+$47   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $C880+$49   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $C880+$4B   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $C880+$4D   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $C880+$4F   ; Function argument 4 (16-bit) (2 bytes)
VAR_ARG5             EQU $C880+$51   ; Function argument 5 (16-bit) (2 bytes)
VAR_ARG6             EQU $C880+$53   ; Function argument 6 (16-bit) (2 bytes)
VAR_ARG7             EQU $C880+$55   ; Function argument 7 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $C880+$57   ; Current ROM bank ID (multibank tracking) (1 bytes)
VAR_STK_SZ           EQU $C880+$58   ; User variable: STK_SZ (2 bytes)
VAR_WST_SZ           EQU $C880+$5A   ; User variable: WST_SZ (2 bytes)
VAR_CURSOR           EQU $C880+$5C   ; User variable: CURSOR (2 bytes)
VAR_SEL_CARD         EQU $C880+$5E   ; User variable: SEL_CARD (2 bytes)
VAR_SEL_SRC          EQU $C880+$60   ; User variable: SEL_SRC (2 bytes)
VAR_GAME_STATE       EQU $C880+$62   ; User variable: GAME_STATE (2 bytes)
VAR_WIN_BLINK        EQU $C880+$64   ; User variable: WIN_BLINK (2 bytes)
VAR_PREV_BTN1        EQU $C880+$66   ; User variable: PREV_BTN1 (2 bytes)
VAR_PREV_BTN2        EQU $C880+$68   ; User variable: PREV_BTN2 (2 bytes)
VAR_BTN1_FIRE        EQU $C880+$6A   ; User variable: BTN1_FIRE (2 bytes)
VAR_BTN2_FIRE        EQU $C880+$6C   ; User variable: BTN2_FIRE (2 bytes)
VAR_PREV_JX          EQU $C880+$6E   ; User variable: PREV_JX (2 bytes)
VAR_G_RESULT         EQU $C880+$70   ; User variable: G_RESULT (2 bytes)
VAR_G_COL_X          EQU $C880+$72   ; User variable: G_COL_X (2 bytes)
VAR_G_CARD           EQU $C880+$74   ; User variable: G_CARD (2 bytes)
VAR_G_RANK           EQU $C880+$76   ; User variable: G_RANK (2 bytes)
VAR_G_SUIT           EQU $C880+$78   ; User variable: G_SUIT (2 bytes)
VAR_G_SZ             EQU $C880+$7A   ; User variable: G_SZ (2 bytes)
VAR_G_HD             EQU $C880+$7C   ; User variable: G_HD (2 bytes)
VAR_G_IDX            EQU $C880+$7E   ; User variable: G_IDX (2 bytes)
VAR_G_CY             EQU $C880+$80   ; User variable: G_CY (2 bytes)
VAR_G_TIDX           EQU $C880+$82   ; User variable: G_TIDX (2 bytes)
VAR_G_TOP            EQU $C880+$84   ; User variable: G_TOP (2 bytes)
VAR_G_TR             EQU $C880+$86   ; User variable: G_TR (2 bytes)
VAR_G_TC             EQU $C880+$88   ; User variable: G_TC (2 bytes)
VAR_G_TOP_RED        EQU $C880+$8A   ; User variable: G_TOP_RED (2 bytes)
VAR_G_CARD_RED       EQU $C880+$8C   ; User variable: G_CARD_RED (2 bytes)
VAR_G_PLACED         EQU $C880+$8E   ; User variable: G_PLACED (2 bytes)
VAR_DEAL_IDX         EQU $C880+$90   ; User variable: DEAL_IDX (2 bytes)
VAR_G_ROW            EQU $C880+$92   ; User variable: G_ROW (2 bytes)
VAR_G_C              EQU $C880+$94   ; User variable: G_C (2 bytes)
VAR_G_CX             EQU $C880+$96   ; User variable: G_CX (2 bytes)
VAR_G_FC             EQU $C880+$98   ; User variable: G_FC (2 bytes)
VAR_G_WCARD          EQU $C880+$9A   ; User variable: G_WCARD (2 bytes)
VAR_G_FX             EQU $C880+$9C   ; User variable: G_FX (2 bytes)
VAR_DECK             EQU $C880+$9E   ; User variable: DECK (2 bytes)
VAR_TAB_SZ           EQU $C880+$A0   ; User variable: TAB_SZ (2 bytes)
VAR_TAB_HID          EQU $C880+$A2   ; User variable: TAB_HID (2 bytes)
VAR_FOUND_CNT        EQU $C880+$A4   ; User variable: FOUND_CNT (2 bytes)
VAR_TAB              EQU $C880+$A6   ; User variable: TAB (2 bytes)
VAR_STOCK            EQU $C880+$A8   ; User variable: STOCK (2 bytes)
VAR_WASTE            EQU $C880+$AA   ; User variable: WASTE (2 bytes)
VAR_CARD             EQU $C880+$AC   ; User variable: card (2 bytes)
VAR_COL              EQU $C880+$AE   ; User variable: col (2 bytes)
VAR_SUIT             EQU $C880+$B0   ; User variable: suit (2 bytes)
VAR_FX               EQU $C880+$B2   ; User variable: fx (2 bytes)
VAR_X                EQU $C880+$B4   ; User variable: x (2 bytes)
VAR_Y                EQU $C880+$B6   ; User variable: y (2 bytes)
VAR_INTENSITY        EQU $C880+$B8   ; User variable: intensity (2 bytes)
VAR_N                EQU $C880+$BA   ; User variable: n (2 bytes)
VAR_R                EQU $C880+$BC   ; User variable: r (2 bytes)
VAR_S                EQU $C880+$BE   ; User variable: s (2 bytes)
VAR_DECK_DATA        EQU $C880+$C0   ; Mutable array 'DECK' data (52 elements x 2 bytes) (104 bytes)
VAR_TAB_DATA         EQU $C880+$128   ; Mutable array 'TAB' data (140 elements x 2 bytes) (280 bytes)
VAR_TAB_SZ_DATA      EQU $C880+$240   ; Mutable array 'TAB_SZ' data (7 elements x 2 bytes) (14 bytes)
VAR_TAB_HID_DATA     EQU $C880+$24E   ; Mutable array 'TAB_HID' data (7 elements x 2 bytes) (14 bytes)
VAR_FOUND_CNT_DATA   EQU $C880+$25C   ; Mutable array 'FOUND_CNT' data (4 elements x 2 bytes) (8 bytes)
VAR_STOCK_DATA       EQU $C880+$264   ; Mutable array 'STOCK' data (24 elements x 2 bytes) (48 bytes)
VAR_WASTE_DATA       EQU $C880+$294   ; Mutable array 'WASTE' data (24 elements x 2 bytes) (48 bytes)
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

; Array literal for variable 'DECK' (52 elements, 2 bytes each)
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

; Array literal for variable 'TAB' (140 elements, 2 bytes each)
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

; Array literal for variable 'TAB_SZ' (7 elements, 2 bytes each)
ARRAY_TAB_SZ_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6

; Array literal for variable 'TAB_HID' (7 elements, 2 bytes each)
ARRAY_TAB_HID_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6

; Array literal for variable 'FOUND_CNT' (4 elements, 2 bytes each)
ARRAY_FOUND_CNT_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3

; Array literal for variable 'STOCK' (24 elements, 2 bytes each)
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

; Array literal for variable 'WASTE' (24 elements, 2 bytes each)
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
    CLR DRAW_VEC_INTENSITY ; 0 = use recorded/vector intensity (no override)
    LDA #$F8
    STA TEXT_SCALE_H      ; Default height = -8 (normal size)
    LDA #$48
    STA TEXT_SCALE_W      ; Default width = 72 (normal size)
    LDA #$7F
    STA DRAW_SCALE        ; Default T1 scale = $7F (127 = full BIOS scale)
    ; Copy array 'DECK' from ROM to RAM (52 elements)
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
    ; Copy array 'TAB' from ROM to RAM (140 elements)
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
    ; Copy array 'TAB_SZ' from ROM to RAM (7 elements)
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
    ; Copy array 'TAB_HID' from ROM to RAM (7 elements)
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
    ; Copy array 'FOUND_CNT' from ROM to RAM (4 elements)
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
    ; Copy array 'STOCK' from ROM to RAM (24 elements)
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
    ; Copy array 'WASTE' from ROM to RAM (24 elements)
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
; VPy_LINE:104
    LDD #0  ; const STATE_PLAY
    STD VAR_GAME_STATE
; VPy_LINE:105
    JSR SHUFFLE
; VPy_LINE:106
    JSR DEAL
    CLR >$C811  ; Force-clear Vec_Buttons before first loop() frame

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
; VPy_LINE:110
; NATIVE_CALL: J1_BUTTON_1 at line 110
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
; VPy_LINE:111
; NATIVE_CALL: J1_BUTTON_2 at line 111
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
; VPy_LINE:112
    LDD #0
    STD VAR_BTN1_FIRE
; VPy_LINE:113
    LDD #0
    STD VAR_BTN2_FIRE
; VPy_LINE:114
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
; VPy_LINE:115
    LDD #1
    STD VAR_BTN1_FIRE
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
; VPy_LINE:116
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
; VPy_LINE:117
    LDD #1
    STD VAR_BTN2_FIRE
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
; VPy_LINE:118
    LDD >VAR_G_CARD
    STD VAR_PREV_BTN1
; VPy_LINE:119
    LDD >VAR_G_RANK
    STD VAR_PREV_BTN2
; VPy_LINE:121
    LDD >VAR_GAME_STATE
    CMPD #0
    LBNE IF_NEXT_5
; VPy_LINE:122
    JSR UPDATE_INPUT
; VPy_LINE:123
    JSR DRAW_TABLE
; VPy_LINE:124
    JSR CHECK_WIN
    LBRA IF_END_4
IF_NEXT_5:
; VPy_LINE:126
    JSR DRAW_WIN_SCREEN
IF_END_4:
    RTS

; Function: SHUFFLE
SHUFFLE:
; VPy_LINE:132
    LDD #51
    STD VAR_G_C
; VPy_LINE:133
WH_6: ; while start
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_C
    CMPD TMPVAL
    LBGT .CMP_6_TRUE
    LDD #0
    LBRA .CMP_6_END
.CMP_6_TRUE:
    LDD #1
.CMP_6_END:
    LBEQ WH_END_7
; VPy_LINE:134
    ; RAND_RANGE: Random in range [min, max]
    LDD #0
    STD TMPPTR     ; Save min
    LDD >VAR_G_C
    STD TMPPTR2    ; Save max
    JSR RAND_RANGE_HELPER
    STD RESULT
    STD VAR_G_IDX
; VPy_LINE:135
    LDX #VAR_DECK_DATA  ; Array base
    LDD >VAR_G_C
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_CARD
; VPy_LINE:136
    LDD >VAR_G_C
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_DECK_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDX #VAR_DECK_DATA  ; Array base
    LDD >VAR_G_IDX
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:137
    LDD >VAR_G_IDX
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_DECK_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD >VAR_G_CARD
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:138
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_C
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_G_C
    LBRA WH_6
WH_END_7: ; while end
    RTS

; Function: DEAL
DEAL:
; VPy_LINE:144
    LDD #0
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_SZ_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #0
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:145
    LDD #1
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_SZ_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #0
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:146
    LDD #2
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_SZ_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #0
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:147
    LDD #3
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_SZ_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #0
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:148
    LDD #4
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_SZ_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #0
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:149
    LDD #5
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_SZ_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #0
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:150
    LDD #6
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_SZ_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #0
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:151
    LDD #0
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_HID_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #0
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:152
    LDD #1
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_HID_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #0
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:153
    LDD #2
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_HID_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #0
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:154
    LDD #3
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_HID_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #0
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:155
    LDD #4
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_HID_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #0
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:156
    LDD #5
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_HID_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #0
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:157
    LDD #6
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_HID_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #0
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:158
    LDD #0
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_FOUND_CNT_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #0
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:159
    LDD #1
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_FOUND_CNT_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #0
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:160
    LDD #2
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_FOUND_CNT_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #0
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:161
    LDD #3
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_FOUND_CNT_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #0
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:162
    LDD #0
    STD VAR_STK_SZ
; VPy_LINE:163
    LDD #0
    STD VAR_WST_SZ
; VPy_LINE:164
    LDD #-1
    STD VAR_SEL_CARD
; VPy_LINE:165
    LDD #-1
    STD VAR_SEL_SRC
; VPy_LINE:166
    LDD #0
    STD VAR_CURSOR
; VPy_LINE:168
    LDD #0
    STD VAR_DEAL_IDX
; VPy_LINE:169
    LDD #0
    STD VAR_G_C
; VPy_LINE:170
WH_8: ; while start
    LDD #7
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_C
    CMPD TMPVAL
    LBLT .CMP_7_TRUE
    LDD #0
    LBRA .CMP_7_END
.CMP_7_TRUE:
    LDD #1
.CMP_7_END:
    LBEQ WH_END_9
; VPy_LINE:171
    LDD #0
    STD VAR_G_ROW
; VPy_LINE:172
WH_10: ; while start
    LDD >VAR_G_C
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_ROW
    CMPD TMPVAL
    LBLE .CMP_8_TRUE
    LDD #0
    LBRA .CMP_8_END
.CMP_8_TRUE:
    LDD #1
.CMP_8_END:
    LBEQ WH_END_11
; VPy_LINE:173
    LDD #20
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_C
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD TMPVAL          ; LEFT → TMPVAL (RIGHT simple, commutative)
    LDD >VAR_G_ROW
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_G_TIDX
; VPy_LINE:174
    LDD >VAR_G_TIDX
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDX #VAR_DECK_DATA  ; Array base
    LDD >VAR_DEAL_IDX
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:175
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_DEAL_IDX
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_DEAL_IDX
; VPy_LINE:176
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_ROW
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_G_ROW
    LBRA WH_10
WH_END_11: ; while end
; VPy_LINE:177
    LDD >VAR_G_C
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_SZ_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_C
    ADDD TMPVAL         ; D = LEFT + RIGHT
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:178
    LDD >VAR_G_C
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_HID_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD >VAR_G_C
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:179
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_C
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_G_C
    LBRA WH_8
WH_END_9: ; while end
; VPy_LINE:181
    LDD #0
    STD VAR_G_ROW
; VPy_LINE:182
WH_12: ; while start
    LDD #52
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_DEAL_IDX
    CMPD TMPVAL
    LBLT .CMP_9_TRUE
    LDD #0
    LBRA .CMP_9_END
.CMP_9_TRUE:
    LDD #1
.CMP_9_END:
    LBEQ WH_END_13
; VPy_LINE:183
    LDD >VAR_G_ROW
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_STOCK_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDX #VAR_DECK_DATA  ; Array base
    LDD >VAR_DEAL_IDX
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:184
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_DEAL_IDX
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_DEAL_IDX
; VPy_LINE:185
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_ROW
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_G_ROW
    LBRA WH_12
WH_END_13: ; while end
; VPy_LINE:186
    LDD >VAR_G_ROW
    STD VAR_STK_SZ
    RTS

; Function: UPDATE_INPUT
UPDATE_INPUT:
; VPy_LINE:192
; NATIVE_CALL: J1_X at line 192
    JSR J1X_BUILTIN
    STD RESULT
    STD VAR_G_IDX
; VPy_LINE:193
    LDD #0
    STD VAR_G_ROW
; VPy_LINE:194
    LDD #40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_IDX
    CMPD TMPVAL
    LBGT .CMP_10_TRUE
    LDD #0
    LBRA .CMP_10_END
.CMP_10_TRUE:
    LDD #1
.CMP_10_END:
    LBEQ IF_NEXT_15
; VPy_LINE:195
    LDD #1
    STD VAR_G_ROW
    LBRA IF_END_14
IF_NEXT_15:
    LDD #-40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_IDX
    CMPD TMPVAL
    LBLT .CMP_11_TRUE
    LDD #0
    LBRA .CMP_11_END
.CMP_11_TRUE:
    LDD #1
.CMP_11_END:
    LBEQ IF_END_14
; VPy_LINE:197
    LDD #-1
    STD VAR_G_ROW
    LBRA IF_END_14
IF_END_14:
; VPy_LINE:198
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_ROW
    CMPD TMPVAL
    LBEQ .CMP_13_TRUE
    LDD #0
    LBRA .CMP_13_END
.CMP_13_TRUE:
    LDD #1
.CMP_13_END:
    LBEQ .LOGIC_12_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_JX
    CMPD TMPVAL
    LBEQ .CMP_14_TRUE
    LDD #0
    LBRA .CMP_14_END
.CMP_14_TRUE:
    LDD #1
.CMP_14_END:
    LBEQ .LOGIC_12_FALSE
    LDD #1
    LBRA .LOGIC_12_END
.LOGIC_12_FALSE:
    LDD #0
.LOGIC_12_END:
    LBEQ IF_NEXT_17
; VPy_LINE:199
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_CURSOR
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_CURSOR
; VPy_LINE:200
    LDD #12
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURSOR
    CMPD TMPVAL
    LBGT .CMP_15_TRUE
    LDD #0
    LBRA .CMP_15_END
.CMP_15_TRUE:
    LDD #1
.CMP_15_END:
    LBEQ IF_NEXT_19
; VPy_LINE:201
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
    LBEQ .CMP_17_TRUE
    LDD #0
    LBRA .CMP_17_END
.CMP_17_TRUE:
    LDD #1
.CMP_17_END:
    LBEQ .LOGIC_16_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_JX
    CMPD TMPVAL
    LBEQ .CMP_18_TRUE
    LDD #0
    LBRA .CMP_18_END
.CMP_18_TRUE:
    LDD #1
.CMP_18_END:
    LBEQ .LOGIC_16_FALSE
    LDD #1
    LBRA .LOGIC_16_END
.LOGIC_16_FALSE:
    LDD #0
.LOGIC_16_END:
    LBEQ IF_END_16
; VPy_LINE:203
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_CURSOR
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_CURSOR
; VPy_LINE:204
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURSOR
    CMPD TMPVAL
    LBLT .CMP_19_TRUE
    LDD #0
    LBRA .CMP_19_END
.CMP_19_TRUE:
    LDD #1
.CMP_19_END:
    LBEQ IF_NEXT_21
; VPy_LINE:205
    LDD #12
    STD VAR_CURSOR
    LBRA IF_END_20
IF_NEXT_21:
IF_END_20:
    LBRA IF_END_16
IF_END_16:
; VPy_LINE:206
    LDD >VAR_G_ROW
    STD VAR_PREV_JX
; VPy_LINE:208
    LDD >VAR_BTN2_FIRE
    CMPD #1
    LBNE IF_NEXT_23
; VPy_LINE:209
    JSR DO_DEAL_STOCK
    LBRA IF_END_22
IF_NEXT_23:
IF_END_22:
; VPy_LINE:211
    LDD >VAR_BTN1_FIRE
    CMPD #1
    LBNE IF_NEXT_25
; VPy_LINE:212
    LDD >VAR_SEL_CARD
    CMPD #-1
    LBNE IF_NEXT_27
; VPy_LINE:213
    JSR DO_PICK_UP
    LBRA IF_END_26
IF_NEXT_27:
; VPy_LINE:215
    JSR DO_PLACE
IF_END_26:
    LBRA IF_END_24
IF_NEXT_25:
IF_END_24:
    RTS

; Function: DO_DEAL_STOCK
DO_DEAL_STOCK:
; VPy_LINE:218
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_STK_SZ
    CMPD TMPVAL
    LBGT .CMP_20_TRUE
    LDD #0
    LBRA .CMP_20_END
.CMP_20_TRUE:
    LDD #1
.CMP_20_END:
    LBEQ IF_NEXT_29
; VPy_LINE:219
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_STK_SZ
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_STK_SZ
; VPy_LINE:220
    LDD >VAR_WST_SZ
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_WASTE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDX #VAR_STOCK_DATA  ; Array base
    LDD >VAR_STK_SZ
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:221
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_WST_SZ
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_WST_SZ
    LBRA IF_END_28
IF_NEXT_29:
; VPy_LINE:223
    LDD #0
    STD VAR_G_ROW
; VPy_LINE:224
WH_30: ; while start
    LDD >VAR_WST_SZ
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_ROW
    CMPD TMPVAL
    LBLT .CMP_21_TRUE
    LDD #0
    LBRA .CMP_21_END
.CMP_21_TRUE:
    LDD #1
.CMP_21_END:
    LBEQ WH_END_31
; VPy_LINE:225
    LDD >VAR_G_ROW
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_STOCK_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDX #VAR_WASTE_DATA  ; Array base
    LDD >VAR_G_ROW
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:226
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_ROW
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_G_ROW
    LBRA WH_30
WH_END_31: ; while end
; VPy_LINE:227
    LDD >VAR_WST_SZ
    STD VAR_STK_SZ
; VPy_LINE:228
    LDD #0
    STD VAR_WST_SZ
IF_END_28:
    RTS

; Function: DO_PICK_UP
DO_PICK_UP:
; VPy_LINE:231
    LDD #6
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURSOR
    CMPD TMPVAL
    LBLE .CMP_22_TRUE
    LDD #0
    LBRA .CMP_22_END
.CMP_22_TRUE:
    LDD #1
.CMP_22_END:
    LBEQ IF_NEXT_33
; VPy_LINE:232
    LDD >VAR_CURSOR
    STD VAR_G_C
; VPy_LINE:233
    LDX #VAR_TAB_SZ_DATA  ; Array base
    LDD >VAR_G_C
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_SZ
; VPy_LINE:234
    LDX #VAR_TAB_HID_DATA  ; Array base
    LDD >VAR_G_C
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_HD
; VPy_LINE:235
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_SZ
    CMPD TMPVAL
    LBGT .CMP_24_TRUE
    LDD #0
    LBRA .CMP_24_END
.CMP_24_TRUE:
    LDD #1
.CMP_24_END:
    LBEQ .LOGIC_23_FALSE
    LDD >VAR_G_HD
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_SZ
    CMPD TMPVAL
    LBGT .CMP_25_TRUE
    LDD #0
    LBRA .CMP_25_END
.CMP_25_TRUE:
    LDD #1
.CMP_25_END:
    LBEQ .LOGIC_23_FALSE
    LDD #1
    LBRA .LOGIC_23_END
.LOGIC_23_FALSE:
    LDD #0
.LOGIC_23_END:
    LBEQ IF_NEXT_35
; VPy_LINE:236
    LDD #20
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_C
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD TMPVAL          ; LEFT → TMPVAL (RIGHT simple, commutative)
    LDD >VAR_G_SZ
    ADDD TMPVAL         ; D = LEFT + RIGHT
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_G_TIDX
; VPy_LINE:237
    LDX #VAR_TAB_DATA  ; Array base
    LDD >VAR_G_TIDX
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_SEL_CARD
; VPy_LINE:238
    LDD >VAR_CURSOR
    STD VAR_SEL_SRC
; VPy_LINE:239
    LDD >VAR_G_C
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_SZ_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_SZ
    SUBD TMPVAL         ; D = LEFT - RIGHT
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:240
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
    LBGT .CMP_27_TRUE
    LDD #0
    LBRA .CMP_27_END
.CMP_27_TRUE:
    LDD #1
.CMP_27_END:
    LBEQ .LOGIC_26_FALSE
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
    LBLE .CMP_28_TRUE
    LDD #0
    LBRA .CMP_28_END
.CMP_28_TRUE:
    LDD #1
.CMP_28_END:
    LBEQ .LOGIC_26_FALSE
    LDD #1
    LBRA .LOGIC_26_END
.LOGIC_26_FALSE:
    LDD #0
.LOGIC_26_END:
    LBEQ IF_NEXT_37
; VPy_LINE:241
    LDD >VAR_G_C
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_HID_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDX #VAR_TAB_HID_DATA  ; Array base
    LDD >VAR_G_C
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    SUBD TMPVAL         ; D = LEFT - RIGHT
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
    LBRA IF_END_36
IF_NEXT_37:
IF_END_36:
    LBRA IF_END_34
IF_NEXT_35:
IF_END_34:
    LBRA IF_END_32
IF_NEXT_33:
    LDD >VAR_CURSOR
    CMPD #8
    LBNE IF_END_32
; VPy_LINE:243
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_WST_SZ
    CMPD TMPVAL
    LBGT .CMP_29_TRUE
    LDD #0
    LBRA .CMP_29_END
.CMP_29_TRUE:
    LDD #1
.CMP_29_END:
    LBEQ IF_NEXT_39
; VPy_LINE:244
    LDX #VAR_WASTE_DATA  ; Array base
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_WST_SZ
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_SEL_CARD
; VPy_LINE:245
    LDD #8
    STD VAR_SEL_SRC
; VPy_LINE:246
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_WST_SZ
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_WST_SZ
    LBRA IF_END_38
IF_NEXT_39:
IF_END_38:
    LBRA IF_END_32
IF_END_32:
    RTS

; Function: DO_PLACE
DO_PLACE:
; VPy_LINE:249
    LDD #0
    STD VAR_G_PLACED
; VPy_LINE:250
    LDD #6
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURSOR
    CMPD TMPVAL
    LBLE .CMP_30_TRUE
    LDD #0
    LBRA .CMP_30_END
.CMP_30_TRUE:
    LDD #1
.CMP_30_END:
    LBEQ IF_NEXT_41
; VPy_LINE:251
    LDD >VAR_SEL_CARD
    STD VAR_ARG0
    LDD >VAR_CURSOR
    STD VAR_ARG1
    JSR CAN_MOVE_TO_TAB
; VPy_LINE:252
    LDD >VAR_G_RESULT
    CMPD #1
    LBNE IF_NEXT_43
; VPy_LINE:253
    LDD #20
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_CURSOR
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDX #VAR_TAB_SZ_DATA  ; Array base
    LDD >VAR_CURSOR
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_G_TIDX
; VPy_LINE:254
    LDD >VAR_G_TIDX
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD >VAR_SEL_CARD
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:255
    LDD >VAR_CURSOR
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_SZ_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDX #VAR_TAB_SZ_DATA  ; Array base
    LDD >VAR_CURSOR
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; LEFT → TMPVAL (RIGHT simple, commutative)
    LDD #1
    ADDD TMPVAL         ; D = LEFT + RIGHT
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:256
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
    LBGE .CMP_32_TRUE
    LDD #0
    LBRA .CMP_32_END
.CMP_32_TRUE:
    LDD #1
.CMP_32_END:
    LBEQ .LOGIC_31_FALSE
    LDD #12
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURSOR
    CMPD TMPVAL
    LBLE .CMP_33_TRUE
    LDD #0
    LBRA .CMP_33_END
.CMP_33_TRUE:
    LDD #1
.CMP_33_END:
    LBEQ .LOGIC_31_FALSE
    LDD #1
    LBRA .LOGIC_31_END
.LOGIC_31_FALSE:
    LDD #0
.LOGIC_31_END:
    LBEQ IF_END_40
; VPy_LINE:258
    LDD #9
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_CURSOR
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_G_SUIT
; VPy_LINE:259
    LDD >VAR_SEL_CARD
    STD VAR_ARG0
    LDD >VAR_G_SUIT
    STD VAR_ARG1
    JSR CAN_MOVE_TO_FOUND
; VPy_LINE:260
    LDD >VAR_G_RESULT
    CMPD #1
    LBNE IF_NEXT_45
; VPy_LINE:261
    LDD >VAR_G_SUIT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_FOUND_CNT_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDX #VAR_FOUND_CNT_DATA  ; Array base
    LDD >VAR_G_SUIT
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; LEFT → TMPVAL (RIGHT simple, commutative)
    LDD #1
    ADDD TMPVAL         ; D = LEFT + RIGHT
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:262
    LDD #1
    STD VAR_G_PLACED
    LBRA IF_END_44
IF_NEXT_45:
IF_END_44:
    LBRA IF_END_40
IF_END_40:
; VPy_LINE:264
    LDD >VAR_G_PLACED
    CMPD #1
    LBNE IF_NEXT_47
; VPy_LINE:265
    LDD #-1
    STD VAR_SEL_CARD
; VPy_LINE:266
    LDD #-1
    STD VAR_SEL_SRC
    LBRA IF_END_46
IF_NEXT_47:
; VPy_LINE:268
    JSR RETURN_CARD_TO_SRC
IF_END_46:
    RTS

; Function: RETURN_CARD_TO_SRC
RETURN_CARD_TO_SRC:
; VPy_LINE:271
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SEL_SRC
    CMPD TMPVAL
    LBGE .CMP_35_TRUE
    LDD #0
    LBRA .CMP_35_END
.CMP_35_TRUE:
    LDD #1
.CMP_35_END:
    LBEQ .LOGIC_34_FALSE
    LDD #6
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SEL_SRC
    CMPD TMPVAL
    LBLE .CMP_36_TRUE
    LDD #0
    LBRA .CMP_36_END
.CMP_36_TRUE:
    LDD #1
.CMP_36_END:
    LBEQ .LOGIC_34_FALSE
    LDD #1
    LBRA .LOGIC_34_END
.LOGIC_34_FALSE:
    LDD #0
.LOGIC_34_END:
    LBEQ IF_NEXT_49
; VPy_LINE:272
    LDD >VAR_SEL_SRC
    STD VAR_G_C
; VPy_LINE:273
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
    LBGT .CMP_38_TRUE
    LDD #0
    LBRA .CMP_38_END
.CMP_38_TRUE:
    LDD #1
.CMP_38_END:
    LBEQ .LOGIC_37_FALSE
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
    LBEQ .CMP_39_TRUE
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
    LBEQ IF_NEXT_51
; VPy_LINE:274
    LDD >VAR_G_C
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_HID_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDX #VAR_TAB_HID_DATA  ; Array base
    LDD >VAR_G_C
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; LEFT → TMPVAL (RIGHT simple, commutative)
    LDD #1
    ADDD TMPVAL         ; D = LEFT + RIGHT
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
    LBRA IF_END_50
IF_NEXT_51:
IF_END_50:
; VPy_LINE:275
    LDD #20
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_C
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDX #VAR_TAB_SZ_DATA  ; Array base
    LDD >VAR_G_C
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_G_TIDX
; VPy_LINE:276
    LDD >VAR_G_TIDX
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD >VAR_SEL_CARD
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:277
    LDD >VAR_G_C
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_TAB_SZ_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDX #VAR_TAB_SZ_DATA  ; Array base
    LDD >VAR_G_C
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; LEFT → TMPVAL (RIGHT simple, commutative)
    LDD #1
    ADDD TMPVAL         ; D = LEFT + RIGHT
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
    LBRA IF_END_48
IF_NEXT_49:
    LDD >VAR_SEL_SRC
    CMPD #8
    LBNE IF_END_48
; VPy_LINE:279
    LDD >VAR_WST_SZ
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_WASTE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD >VAR_SEL_CARD
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:280
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_WST_SZ
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_WST_SZ
    LBRA IF_END_48
IF_END_48:
; VPy_LINE:281
    LDD #-1
    STD VAR_SEL_CARD
; VPy_LINE:282
    LDD #-1
    STD VAR_SEL_SRC
    RTS

; Function: CAN_MOVE_TO_TAB
CAN_MOVE_TO_TAB:
; VPy_LINE:288
    LDX #VAR_TAB_SZ_DATA  ; Array base
    LDD >VAR_ARG1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_SZ
; VPy_LINE:289
    LDD #4
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ARG0
    TFR D,X             ; X = LEFT (dividend)
    LDD TMPVAL          ; D = RIGHT (divisor)
    JSR DIV16           ; D = X / D
    STD VAR_G_RANK
; VPy_LINE:290
    LDD >VAR_G_SZ
    CMPD #0
    LBNE IF_NEXT_53
; VPy_LINE:291
    LDD >VAR_G_RANK
    CMPD #12
    LBNE IF_NEXT_55
; VPy_LINE:292
    LDD #1
    STD VAR_G_RESULT
    LBRA IF_END_54
IF_NEXT_55:
; VPy_LINE:294
    LDD #0
    STD VAR_G_RESULT
IF_END_54:
; VPy_LINE:295
    RTS
    LBRA IF_END_52
IF_NEXT_53:
IF_END_52:
; VPy_LINE:296
    LDD #20
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ARG1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD TMPVAL          ; LEFT → TMPVAL (RIGHT simple, commutative)
    LDD >VAR_G_SZ
    ADDD TMPVAL         ; D = LEFT + RIGHT
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_G_TIDX
; VPy_LINE:297
    LDX #VAR_TAB_DATA  ; Array base
    LDD >VAR_G_TIDX
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_TOP
; VPy_LINE:298
    LDD #4
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_TOP
    TFR D,X             ; X = LEFT (dividend)
    LDD TMPVAL          ; D = RIGHT (divisor)
    JSR DIV16           ; D = X / D
    STD VAR_G_TR
; VPy_LINE:299
    LDD #4
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_TR
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_TOP
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_G_TC
; VPy_LINE:300
    LDD #4
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_RANK
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ARG0
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_G_SUIT
; VPy_LINE:301
    LDD #0
    STD VAR_G_TOP_RED
; VPy_LINE:302
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_TC
    CMPD TMPVAL
    LBEQ .CMP_41_TRUE
    LDD #0
    LBRA .CMP_41_END
.CMP_41_TRUE:
    LDD #1
.CMP_41_END:
    LBNE .LOGIC_40_TRUE
    LDD #2
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_TC
    CMPD TMPVAL
    LBEQ .CMP_42_TRUE
    LDD #0
    LBRA .CMP_42_END
.CMP_42_TRUE:
    LDD #1
.CMP_42_END:
    LBNE .LOGIC_40_TRUE
    LDD #0
    LBRA .LOGIC_40_END
.LOGIC_40_TRUE:
    LDD #1
.LOGIC_40_END:
    LBEQ IF_NEXT_57
; VPy_LINE:303
    LDD #1
    STD VAR_G_TOP_RED
    LBRA IF_END_56
IF_NEXT_57:
IF_END_56:
; VPy_LINE:304
    LDD #0
    STD VAR_G_CARD_RED
; VPy_LINE:305
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_SUIT
    CMPD TMPVAL
    LBEQ .CMP_44_TRUE
    LDD #0
    LBRA .CMP_44_END
.CMP_44_TRUE:
    LDD #1
.CMP_44_END:
    LBNE .LOGIC_43_TRUE
    LDD #2
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_SUIT
    CMPD TMPVAL
    LBEQ .CMP_45_TRUE
    LDD #0
    LBRA .CMP_45_END
.CMP_45_TRUE:
    LDD #1
.CMP_45_END:
    LBNE .LOGIC_43_TRUE
    LDD #0
    LBRA .LOGIC_43_END
.LOGIC_43_TRUE:
    LDD #1
.LOGIC_43_END:
    LBEQ IF_NEXT_59
; VPy_LINE:306
    LDD #1
    STD VAR_G_CARD_RED
    LBRA IF_END_58
IF_NEXT_59:
IF_END_58:
; VPy_LINE:307
    LDD >VAR_G_CARD_RED
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_TOP_RED
    CMPD TMPVAL
    LBEQ .CMP_46_TRUE
    LDD #0
    LBRA .CMP_46_END
.CMP_46_TRUE:
    LDD #1
.CMP_46_END:
    LBEQ IF_NEXT_61
; VPy_LINE:308
    LDD #0
    STD VAR_G_RESULT
; VPy_LINE:309
    RTS
    LBRA IF_END_60
IF_NEXT_61:
IF_END_60:
; VPy_LINE:310
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_TR
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_RANK
    CMPD TMPVAL
    LBEQ .CMP_47_TRUE
    LDD #0
    LBRA .CMP_47_END
.CMP_47_TRUE:
    LDD #1
.CMP_47_END:
    LBEQ IF_NEXT_63
; VPy_LINE:311
    LDD #1
    STD VAR_G_RESULT
    LBRA IF_END_62
IF_NEXT_63:
; VPy_LINE:313
    LDD #0
    STD VAR_G_RESULT
IF_END_62:
    RTS

; Function: CAN_MOVE_TO_FOUND
CAN_MOVE_TO_FOUND:
; VPy_LINE:316
    LDD #4
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ARG0
    TFR D,X             ; X = LEFT (dividend)
    LDD TMPVAL          ; D = RIGHT (divisor)
    JSR DIV16           ; D = X / D
    STD VAR_G_RANK
; VPy_LINE:317
    LDD #4
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_RANK
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ARG0
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_G_SUIT
; VPy_LINE:318
    LDD >VAR_ARG1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_SUIT
    CMPD TMPVAL
    LBNE .CMP_48_TRUE
    LDD #0
    LBRA .CMP_48_END
.CMP_48_TRUE:
    LDD #1
.CMP_48_END:
    LBEQ IF_NEXT_65
; VPy_LINE:319
    LDD #0
    STD VAR_G_RESULT
; VPy_LINE:320
    RTS
    LBRA IF_END_64
IF_NEXT_65:
IF_END_64:
; VPy_LINE:321
    LDX #VAR_FOUND_CNT_DATA  ; Array base
    LDD >VAR_ARG1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_FC
; VPy_LINE:322
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_FC
    CMPD TMPVAL
    LBEQ .CMP_50_TRUE
    LDD #0
    LBRA .CMP_50_END
.CMP_50_TRUE:
    LDD #1
.CMP_50_END:
    LBEQ .LOGIC_49_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_RANK
    CMPD TMPVAL
    LBEQ .CMP_51_TRUE
    LDD #0
    LBRA .CMP_51_END
.CMP_51_TRUE:
    LDD #1
.CMP_51_END:
    LBEQ .LOGIC_49_FALSE
    LDD #1
    LBRA .LOGIC_49_END
.LOGIC_49_FALSE:
    LDD #0
.LOGIC_49_END:
    LBEQ IF_NEXT_67
; VPy_LINE:323
    LDD #1
    STD VAR_G_RESULT
; VPy_LINE:324
    RTS
    LBRA IF_END_66
IF_NEXT_67:
IF_END_66:
; VPy_LINE:325
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_FC
    CMPD TMPVAL
    LBGT .CMP_53_TRUE
    LDD #0
    LBRA .CMP_53_END
.CMP_53_TRUE:
    LDD #1
.CMP_53_END:
    LBEQ .LOGIC_52_FALSE
    LDD >VAR_G_FC
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_RANK
    CMPD TMPVAL
    LBEQ .CMP_54_TRUE
    LDD #0
    LBRA .CMP_54_END
.CMP_54_TRUE:
    LDD #1
.CMP_54_END:
    LBEQ .LOGIC_52_FALSE
    LDD #1
    LBRA .LOGIC_52_END
.LOGIC_52_FALSE:
    LDD #0
.LOGIC_52_END:
    LBEQ IF_NEXT_69
; VPy_LINE:326
    LDD #1
    STD VAR_G_RESULT
; VPy_LINE:327
    RTS
    LBRA IF_END_68
IF_NEXT_69:
IF_END_68:
; VPy_LINE:328
    LDD #0
    STD VAR_G_RESULT
    RTS

; Function: CHECK_WIN
CHECK_WIN:
; VPy_LINE:334
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
    LBEQ .CMP_58_TRUE
    LDD #0
    LBRA .CMP_58_END
.CMP_58_TRUE:
    LDD #1
.CMP_58_END:
    LBEQ .LOGIC_57_FALSE
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
    LBEQ .CMP_59_TRUE
    LDD #0
    LBRA .CMP_59_END
.CMP_59_TRUE:
    LDD #1
.CMP_59_END:
    LBEQ .LOGIC_57_FALSE
    LDD #1
    LBRA .LOGIC_57_END
.LOGIC_57_FALSE:
    LDD #0
.LOGIC_57_END:
    LBEQ .LOGIC_56_FALSE
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
    LBEQ .CMP_60_TRUE
    LDD #0
    LBRA .CMP_60_END
.CMP_60_TRUE:
    LDD #1
.CMP_60_END:
    LBEQ .LOGIC_56_FALSE
    LDD #1
    LBRA .LOGIC_56_END
.LOGIC_56_FALSE:
    LDD #0
.LOGIC_56_END:
    LBEQ .LOGIC_55_FALSE
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
    LBEQ .CMP_61_TRUE
    LDD #0
    LBRA .CMP_61_END
.CMP_61_TRUE:
    LDD #1
.CMP_61_END:
    LBEQ .LOGIC_55_FALSE
    LDD #1
    LBRA .LOGIC_55_END
.LOGIC_55_FALSE:
    LDD #0
.LOGIC_55_END:
    LBEQ IF_NEXT_71
; VPy_LINE:335
    LDD #1  ; const STATE_WIN
    STD VAR_GAME_STATE
    LBRA IF_END_70
IF_NEXT_71:
IF_END_70:
    RTS

; Function: DRAW_TABLE
DRAW_TABLE:
; VPy_LINE:341
    JSR DRAW_STOCK
; VPy_LINE:342
    JSR DRAW_WASTE
; VPy_LINE:343
    JSR DRAW_FOUNDATIONS
; VPy_LINE:344
    JSR DRAW_TABLEAU
; VPy_LINE:345
    JSR DRAW_HELD_LABEL
; VPy_LINE:346
    JSR DRAW_CURSOR
    RTS

; Function: GET_COL_X
GET_COL_X:
; VPy_LINE:349
    LDD >VAR_ARG0
    CMPD #0
    LBNE IF_NEXT_73
; VPy_LINE:350
    LDD #-102  ; const TAB_X0
    STD VAR_G_COL_X
    LBRA IF_END_72
IF_NEXT_73:
    LDD >VAR_ARG0
    CMPD #1
    LBNE IF_NEXT_74
; VPy_LINE:352
    LDD #-68  ; const TAB_X1
    STD VAR_G_COL_X
    LBRA IF_END_72
IF_NEXT_74:
    LDD >VAR_ARG0
    CMPD #2
    LBNE IF_NEXT_75
; VPy_LINE:354
    LDD #-34  ; const TAB_X2
    STD VAR_G_COL_X
    LBRA IF_END_72
IF_NEXT_75:
    LDD >VAR_ARG0
    CMPD #3
    LBNE IF_NEXT_76
; VPy_LINE:356
    LDD #0  ; const TAB_X3
    STD VAR_G_COL_X
    LBRA IF_END_72
IF_NEXT_76:
    LDD >VAR_ARG0
    CMPD #4
    LBNE IF_NEXT_77
; VPy_LINE:358
    LDD #34  ; const TAB_X4
    STD VAR_G_COL_X
    LBRA IF_END_72
IF_NEXT_77:
    LDD >VAR_ARG0
    CMPD #5
    LBNE IF_NEXT_78
; VPy_LINE:360
    LDD #68  ; const TAB_X5
    STD VAR_G_COL_X
    LBRA IF_END_72
IF_NEXT_78:
; VPy_LINE:362
    LDD #102  ; const TAB_X6
    STD VAR_G_COL_X
IF_END_72:
    RTS

; Function: DRAW_STOCK
DRAW_STOCK:
; VPy_LINE:365
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_STK_SZ
    CMPD TMPVAL
    LBGT .CMP_62_TRUE
    LDD #0
    LBRA .CMP_62_END
.CMP_62_TRUE:
    LDD #1
.CMP_62_END:
    LBEQ IF_NEXT_80
; VPy_LINE:366
; NATIVE_CALL: DRAW_RECT at line 366
    ; DRAW_RECT: x, y, width, height[, intensity] (variable args)
    LDD #-102  ; const STK_X
    TFR B,A
    STA DRAW_RECT_X
    LDD #85  ; const TOP_Y
    TFR B,A
    STA DRAW_RECT_Y
    LDD #26  ; const CARD_W
    TFR B,A
    STA DRAW_RECT_WIDTH
    LDD #32  ; const CARD_H
    TFR B,A
    STA DRAW_RECT_HEIGHT
    LDD #40  ; const INT_FACEDN
    TFR B,A
    STA DRAW_RECT_INTENSITY
    JSR DRAW_RECT_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:367
; NATIVE_CALL: SET_INTENSITY at line 367
    ; SET_INTENSITY: Set drawing intensity
    LDD #40  ; const INT_FACEDN
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:368
; NATIVE_CALL: PRINT_TEXT at line 368
    ; PRINT_TEXT: Print text at position
    LDD #4
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-102  ; const STK_X
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD >VAR_ARG0
    LDD #10
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #85  ; const TOP_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_1120      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_79
IF_NEXT_80:
; VPy_LINE:370
; NATIVE_CALL: DRAW_RECT at line 370
    ; DRAW_RECT: x, y, width, height[, intensity] (variable args)
    LDD #-102  ; const STK_X
    TFR B,A
    STA DRAW_RECT_X
    LDD #85  ; const TOP_Y
    TFR B,A
    STA DRAW_RECT_Y
    LDD #26  ; const CARD_W
    TFR B,A
    STA DRAW_RECT_WIDTH
    LDD #32  ; const CARD_H
    TFR B,A
    STA DRAW_RECT_HEIGHT
    LDD #25  ; const INT_EMPTY
    TFR B,A
    STA DRAW_RECT_INTENSITY
    JSR DRAW_RECT_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:371
; NATIVE_CALL: SET_INTENSITY at line 371
    ; SET_INTENSITY: Set drawing intensity
    LDD #25  ; const INT_EMPTY
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:372
; NATIVE_CALL: PRINT_TEXT at line 372
    ; PRINT_TEXT: Print text at position
    LDD #4
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-102  ; const STK_X
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD >VAR_ARG0
    LDD #10
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #85  ; const TOP_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2657      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
IF_END_79:
    RTS

; Function: DRAW_WASTE
DRAW_WASTE:
; VPy_LINE:375
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_WST_SZ
    CMPD TMPVAL
    LBGT .CMP_63_TRUE
    LDD #0
    LBRA .CMP_63_END
.CMP_63_TRUE:
    LDD #1
.CMP_63_END:
    LBEQ IF_NEXT_82
; VPy_LINE:376
    LDX #VAR_WASTE_DATA  ; Array base
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_WST_SZ
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_WCARD
; VPy_LINE:377
    LDD #-68  ; const WST_X
    STD VAR_ARG0
    LDD #85  ; const TOP_Y
    STD VAR_ARG1
    LDD >VAR_G_WCARD
    STD VAR_ARG2
    LDD #70  ; const INT_CARD
    STD VAR_ARG3
    JSR DRAW_CARD
    LBRA IF_END_81
IF_NEXT_82:
; VPy_LINE:379
; NATIVE_CALL: DRAW_RECT at line 379
    ; DRAW_RECT: x, y, width, height[, intensity] (variable args)
    LDD #-68  ; const WST_X
    TFR B,A
    STA DRAW_RECT_X
    LDD #85  ; const TOP_Y
    TFR B,A
    STA DRAW_RECT_Y
    LDD #26  ; const CARD_W
    TFR B,A
    STA DRAW_RECT_WIDTH
    LDD #32  ; const CARD_H
    TFR B,A
    STA DRAW_RECT_HEIGHT
    LDD #25  ; const INT_EMPTY
    TFR B,A
    STA DRAW_RECT_INTENSITY
    JSR DRAW_RECT_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:380
; NATIVE_CALL: SET_INTENSITY at line 380
    ; SET_INTENSITY: Set drawing intensity
    LDD #25  ; const INT_EMPTY
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:381
; NATIVE_CALL: PRINT_TEXT at line 381
    ; PRINT_TEXT: Print text at position
    LDD #4
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-68  ; const WST_X
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD >VAR_ARG0
    LDD #10
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #85  ; const TOP_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2780      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
IF_END_81:
    RTS

; Function: DRAW_FOUNDATIONS
DRAW_FOUNDATIONS:
; VPy_LINE:384
    LDD #0  ; const F0_X
    STD VAR_G_FX
; VPy_LINE:385
    LDD >VAR_G_FX
    STD VAR_ARG0
    LDD #0
    STD VAR_ARG1
    JSR DRAW_ONE_FOUNDATION
; VPy_LINE:386
    LDD #34  ; const F1_X
    STD VAR_G_FX
; VPy_LINE:387
    LDD >VAR_G_FX
    STD VAR_ARG0
    LDD #1
    STD VAR_ARG1
    JSR DRAW_ONE_FOUNDATION
; VPy_LINE:388
    LDD #68  ; const F2_X
    STD VAR_G_FX
; VPy_LINE:389
    LDD >VAR_G_FX
    STD VAR_ARG0
    LDD #2
    STD VAR_ARG1
    JSR DRAW_ONE_FOUNDATION
; VPy_LINE:390
    LDD #102  ; const F3_X
    STD VAR_G_FX
; VPy_LINE:391
    LDD >VAR_G_FX
    STD VAR_ARG0
    LDD #3
    STD VAR_ARG1
    JSR DRAW_ONE_FOUNDATION
    RTS

; Function: DRAW_ONE_FOUNDATION
DRAW_ONE_FOUNDATION:
; VPy_LINE:394
    LDX #VAR_FOUND_CNT_DATA  ; Array base
    LDD >VAR_ARG1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_FC
; VPy_LINE:395
    LDD >VAR_G_FC
    CMPD #0
    LBNE IF_NEXT_84
; VPy_LINE:396
; NATIVE_CALL: DRAW_RECT at line 396
    ; DRAW_RECT: x, y, width, height[, intensity] (variable args)
    LDD >VAR_ARG0
    TFR B,A
    STA DRAW_RECT_X
    LDD #85  ; const TOP_Y
    TFR B,A
    STA DRAW_RECT_Y
    LDD #26  ; const CARD_W
    TFR B,A
    STA DRAW_RECT_WIDTH
    LDD #32  ; const CARD_H
    TFR B,A
    STA DRAW_RECT_HEIGHT
    LDD #25  ; const INT_EMPTY
    TFR B,A
    STA DRAW_RECT_INTENSITY
    JSR DRAW_RECT_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:397
    LDD #13  ; const HALF_W
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ARG0
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_ARG0
    LDD #13  ; const HALF_W
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #85  ; const TOP_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_ARG1
    LDD >VAR_ARG1
    STD VAR_ARG2
    JSR DRAW_SUIT_AT
    LBRA IF_END_83
IF_NEXT_84:
; VPy_LINE:399
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_FC
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_G_RANK
; VPy_LINE:400
    LDD #4
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_RANK
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD TMPVAL          ; LEFT → TMPVAL (RIGHT simple, commutative)
    LDD >VAR_ARG1
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_G_CARD
; VPy_LINE:401
    LDD >VAR_ARG0
    STD VAR_ARG0
    LDD #85  ; const TOP_Y
    STD VAR_ARG1
    LDD >VAR_G_CARD
    STD VAR_ARG2
    LDD #70  ; const INT_CARD
    STD VAR_ARG3
    JSR DRAW_CARD
IF_END_83:
    RTS

; Function: DRAW_TABLEAU
DRAW_TABLEAU:
; VPy_LINE:404
    LDD #0
    STD VAR_G_C
; VPy_LINE:405
WH_85: ; while start
    LDD #7
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_C
    CMPD TMPVAL
    LBLT .CMP_64_TRUE
    LDD #0
    LBRA .CMP_64_END
.CMP_64_TRUE:
    LDD #1
.CMP_64_END:
    LBEQ WH_END_86
; VPy_LINE:406
    LDD >VAR_G_C
    STD VAR_ARG0
    JSR GET_COL_X
; VPy_LINE:407
    LDD >VAR_G_COL_X
    STD VAR_G_CX
; VPy_LINE:408
    LDX #VAR_TAB_SZ_DATA  ; Array base
    LDD >VAR_G_C
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_SZ
; VPy_LINE:409
    LDX #VAR_TAB_HID_DATA  ; Array base
    LDD >VAR_G_C
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_HD
; VPy_LINE:410
    LDD >VAR_G_SZ
    CMPD #0
    LBNE IF_NEXT_88
; VPy_LINE:411
; NATIVE_CALL: DRAW_RECT at line 411
    ; DRAW_RECT: x, y, width, height[, intensity] (variable args)
    LDD >VAR_G_CX
    TFR B,A
    STA DRAW_RECT_X
    LDD #30  ; const TAB_Y
    TFR B,A
    STA DRAW_RECT_Y
    LDD #26  ; const CARD_W
    TFR B,A
    STA DRAW_RECT_WIDTH
    LDD #32  ; const CARD_H
    TFR B,A
    STA DRAW_RECT_HEIGHT
    LDD #25  ; const INT_EMPTY
    TFR B,A
    STA DRAW_RECT_INTENSITY
    JSR DRAW_RECT_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_87
IF_NEXT_88:
; VPy_LINE:414
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_HD
    CMPD TMPVAL
    LBGT .CMP_65_TRUE
    LDD #0
    LBRA .CMP_65_END
.CMP_65_TRUE:
    LDD #1
.CMP_65_END:
    LBEQ IF_NEXT_90
; VPy_LINE:415
; NATIVE_CALL: DRAW_RECT at line 415
    ; DRAW_RECT: x, y, width, height[, intensity] (variable args)
    LDD >VAR_G_CX
    TFR B,A
    STA DRAW_RECT_X
    LDD #30  ; const TAB_Y
    TFR B,A
    STA DRAW_RECT_Y
    LDD #26  ; const CARD_W
    TFR B,A
    STA DRAW_RECT_WIDTH
    LDD #32  ; const CARD_H
    TFR B,A
    STA DRAW_RECT_HEIGHT
    LDD #40  ; const INT_FACEDN
    TFR B,A
    STA DRAW_RECT_INTENSITY
    JSR DRAW_RECT_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:416
; NATIVE_CALL: DRAW_RECT at line 416
    ; DRAW_RECT: x, y, width, height[, intensity] (variable args)
    LDD #3
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_CX
    ADDD TMPVAL         ; D = LEFT + RIGHT
    TFR B,A
    STA DRAW_RECT_X
    LDD #4
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #30  ; const TAB_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    TFR B,A
    STA DRAW_RECT_Y
    LDD #6
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #26  ; const CARD_W
    SUBD TMPVAL         ; D = LEFT - RIGHT
    TFR B,A
    STA DRAW_RECT_WIDTH
    LDD #8
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #32  ; const CARD_H
    SUBD TMPVAL         ; D = LEFT - RIGHT
    TFR B,A
    STA DRAW_RECT_HEIGHT
    LDD #40  ; const INT_FACEDN
    TFR B,A
    STA DRAW_RECT_INTENSITY
    JSR DRAW_RECT_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_89
IF_NEXT_90:
IF_END_89:
; VPy_LINE:418
    LDD >VAR_G_HD
    STD VAR_G_ROW
; VPy_LINE:419
    LDD #0
    STD VAR_G_IDX
; VPy_LINE:420
WH_91: ; while start
    LDD >VAR_G_SZ
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_ROW
    CMPD TMPVAL
    LBLT .CMP_67_TRUE
    LDD #0
    LBRA .CMP_67_END
.CMP_67_TRUE:
    LDD #1
.CMP_67_END:
    LBEQ .LOGIC_66_FALSE
    LDD #4
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_IDX
    CMPD TMPVAL
    LBLT .CMP_68_TRUE
    LDD #0
    LBRA .CMP_68_END
.CMP_68_TRUE:
    LDD #1
.CMP_68_END:
    LBEQ .LOGIC_66_FALSE
    LDD #1
    LBRA .LOGIC_66_END
.LOGIC_66_FALSE:
    LDD #0
.LOGIC_66_END:
    LBEQ WH_END_92
; VPy_LINE:421
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_G_HD
    CMPD TMPVAL
    LBGT .CMP_69_TRUE
    LDD #0
    LBRA .CMP_69_END
.CMP_69_TRUE:
    LDD #1
.CMP_69_END:
    LBEQ IF_NEXT_94
; VPy_LINE:422
    LDD #32  ; const CARD_H
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #30  ; const TAB_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD >VAR_G_HD
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_ROW
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD TMPVAL          ; LEFT → TMPVAL (RIGHT simple, commutative)
    LDD #14  ; const COL_DY
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_G_CY
    LBRA IF_END_93
IF_NEXT_94:
; VPy_LINE:424
    LDD >VAR_G_HD
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_ROW
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD TMPVAL          ; LEFT → TMPVAL (RIGHT simple, commutative)
    LDD #14  ; const COL_DY
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #30  ; const TAB_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_G_CY
IF_END_93:
; VPy_LINE:425
    LDD #20
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_C
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD TMPVAL          ; LEFT → TMPVAL (RIGHT simple, commutative)
    LDD >VAR_G_ROW
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_G_TIDX
; VPy_LINE:426
    LDX #VAR_TAB_DATA  ; Array base
    LDD >VAR_G_TIDX
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_CARD
; VPy_LINE:427
    LDD >VAR_G_CX
    STD VAR_ARG0
    LDD >VAR_G_CY
    STD VAR_ARG1
    LDD >VAR_G_CARD
    STD VAR_ARG2
    LDD #70  ; const INT_CARD
    STD VAR_ARG3
    JSR DRAW_CARD
; VPy_LINE:428
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_ROW
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_G_ROW
; VPy_LINE:429
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_IDX
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_G_IDX
    LBRA WH_91
WH_END_92: ; while end
IF_END_87:
; VPy_LINE:430
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_C
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_G_C
    LBRA WH_85
WH_END_86: ; while end
    RTS

; Function: DRAW_HELD_LABEL
DRAW_HELD_LABEL:
; VPy_LINE:433
    LDD >VAR_SEL_CARD
    CMPD #-1
    LBEQ IF_NEXT_96
; VPy_LINE:434
; NATIVE_CALL: SET_INTENSITY at line 434
    ; SET_INTENSITY: Set drawing intensity
    LDD #100  ; const INT_HELD
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:435
; NATIVE_CALL: PRINT_TEXT at line 435
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD >VAR_ARG0
    LDD #-100
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_68624293      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:436
    LDD #4
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_SEL_CARD
    TFR D,X             ; X = LEFT (dividend)
    LDD TMPVAL          ; D = RIGHT (divisor)
    JSR DIV16           ; D = X / D
    STD VAR_G_RANK
; VPy_LINE:437
    LDD #4
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_RANK
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_SEL_CARD
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_G_SUIT
; VPy_LINE:438
    LDD #-15
    STD VAR_ARG0
    LDD #-100
    STD VAR_ARG1
    LDD >VAR_G_RANK
    STD VAR_ARG2
    JSR DRAW_RANK_AT
; VPy_LINE:439
    LDD #0
    STD VAR_ARG0
    LDD #-100
    STD VAR_ARG1
    LDD >VAR_G_SUIT
    STD VAR_ARG2
    JSR DRAW_SUIT_AT
    LBRA IF_END_95
IF_NEXT_96:
IF_END_95:
    RTS

; Function: DRAW_CURSOR
DRAW_CURSOR:
; VPy_LINE:442
    LDD #0
    STD VAR_G_CX
; VPy_LINE:443
    LDD #85  ; const TOP_Y
    STD VAR_G_CY
; VPy_LINE:444
    LDD >VAR_CURSOR
    CMPD #7
    LBNE IF_NEXT_98
; VPy_LINE:445
    LDD #-102  ; const STK_X
    STD VAR_G_CX
    LBRA IF_END_97
IF_NEXT_98:
    LDD >VAR_CURSOR
    CMPD #8
    LBNE IF_NEXT_99
; VPy_LINE:447
    LDD #-68  ; const WST_X
    STD VAR_G_CX
    LBRA IF_END_97
IF_NEXT_99:
    LDD >VAR_CURSOR
    CMPD #9
    LBNE IF_NEXT_100
; VPy_LINE:449
    LDD #0  ; const F0_X
    STD VAR_G_CX
    LBRA IF_END_97
IF_NEXT_100:
    LDD >VAR_CURSOR
    CMPD #10
    LBNE IF_NEXT_101
; VPy_LINE:451
    LDD #34  ; const F1_X
    STD VAR_G_CX
    LBRA IF_END_97
IF_NEXT_101:
    LDD >VAR_CURSOR
    CMPD #11
    LBNE IF_NEXT_102
; VPy_LINE:453
    LDD #68  ; const F2_X
    STD VAR_G_CX
    LBRA IF_END_97
IF_NEXT_102:
    LDD >VAR_CURSOR
    CMPD #12
    LBNE IF_NEXT_103
; VPy_LINE:455
    LDD #102  ; const F3_X
    STD VAR_G_CX
    LBRA IF_END_97
IF_NEXT_103:
; VPy_LINE:457
    LDD >VAR_CURSOR
    STD VAR_ARG0
    JSR GET_COL_X
; VPy_LINE:458
    LDD >VAR_G_COL_X
    STD VAR_G_CX
; VPy_LINE:459
    LDX #VAR_TAB_SZ_DATA  ; Array base
    LDD >VAR_CURSOR
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_SZ
; VPy_LINE:460
    LDX #VAR_TAB_HID_DATA  ; Array base
    LDD >VAR_CURSOR
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_G_HD
; VPy_LINE:461
    LDD >VAR_G_SZ
    CMPD #0
    LBNE IF_NEXT_105
; VPy_LINE:462
    LDD #30  ; const TAB_Y
    STD VAR_G_CY
    LBRA IF_END_104
IF_NEXT_105:
    LDD >VAR_G_HD
    CMPD #0
    LBNE IF_NEXT_106
; VPy_LINE:464
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_SZ
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD TMPVAL          ; LEFT → TMPVAL (RIGHT simple, commutative)
    LDD #14  ; const COL_DY
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #30  ; const TAB_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_G_CY
    LBRA IF_END_104
IF_NEXT_106:
; VPy_LINE:466
    LDD #32  ; const CARD_H
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #30  ; const TAB_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD >VAR_G_HD
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_SZ
    SUBD TMPVAL         ; D = LEFT - RIGHT
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD TMPVAL          ; LEFT → TMPVAL (RIGHT simple, commutative)
    LDD #14  ; const COL_DY
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_G_CY
IF_END_104:
IF_END_97:
; VPy_LINE:467
; NATIVE_CALL: SET_INTENSITY at line 467
    ; SET_INTENSITY: Set drawing intensity
    LDD #127  ; const INT_CURSOR
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:468
; NATIVE_CALL: DRAW_RECT at line 468
    ; DRAW_RECT: x, y, width, height[, intensity] (variable args)
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_CX
    SUBD TMPVAL         ; D = LEFT - RIGHT
    TFR B,A
    STA DRAW_RECT_X
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_CY
    ADDD TMPVAL         ; D = LEFT + RIGHT
    TFR B,A
    STA DRAW_RECT_Y
    LDD #2
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #26  ; const CARD_W
    ADDD TMPVAL         ; D = LEFT + RIGHT
    TFR B,A
    STA DRAW_RECT_WIDTH
    LDD #2
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #32  ; const CARD_H
    ADDD TMPVAL         ; D = LEFT + RIGHT
    TFR B,A
    STA DRAW_RECT_HEIGHT
    LDD #127  ; const INT_CURSOR
    TFR B,A
    STA DRAW_RECT_INTENSITY
    JSR DRAW_RECT_RUNTIME
    LDD #0
    STD RESULT
    RTS

; Function: DRAW_CARD
DRAW_CARD:
; VPy_LINE:472
; NATIVE_CALL: DRAW_RECT at line 472
    ; DRAW_RECT: x, y, width, height[, intensity] (variable args)
    LDD >VAR_ARG0
    TFR B,A
    STA DRAW_RECT_X
    LDD >VAR_ARG1
    TFR B,A
    STA DRAW_RECT_Y
    LDD #26  ; const CARD_W
    TFR B,A
    STA DRAW_RECT_WIDTH
    LDD #32  ; const CARD_H
    TFR B,A
    STA DRAW_RECT_HEIGHT
    LDD >VAR_ARG3
    TFR B,A
    STA DRAW_RECT_INTENSITY
    JSR DRAW_RECT_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:473
; NATIVE_CALL: SET_INTENSITY at line 473
    ; SET_INTENSITY: Set drawing intensity
    LDD >VAR_ARG3
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:474
    LDD #4
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ARG2
    TFR D,X             ; X = LEFT (dividend)
    LDD TMPVAL          ; D = RIGHT (divisor)
    JSR DIV16           ; D = X / D
    STD VAR_G_RANK
; VPy_LINE:475
    LDD #4
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_G_RANK
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ARG2
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_G_SUIT
; VPy_LINE:476
    LDD #3
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ARG0
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_ARG0
    LDD #26
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ARG1
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_ARG1
    LDD >VAR_G_RANK
    STD VAR_ARG2
    JSR DRAW_RANK_AT
; VPy_LINE:477
    LDD #13  ; const HALF_W
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ARG0
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_ARG0
    LDD #12
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ARG1
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_ARG1
    LDD >VAR_G_SUIT
    STD VAR_ARG2
    JSR DRAW_SUIT_AT
    RTS

; Function: DRAW_SMALL_COUNT
DRAW_SMALL_COUNT:
; VPy_LINE:480
    LDD >VAR_ARG2
    CMPD #1
    LBNE IF_NEXT_108
; VPy_LINE:481
; NATIVE_CALL: PRINT_TEXT at line 481
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD >VAR_ARG0
    LDD >VAR_ARG1
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_49      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_107
IF_NEXT_108:
    LDD >VAR_ARG2
    CMPD #2
    LBNE IF_NEXT_109
; VPy_LINE:483
; NATIVE_CALL: PRINT_TEXT at line 483
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD >VAR_ARG0
    LDD >VAR_ARG1
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_50      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_107
IF_NEXT_109:
    LDD >VAR_ARG2
    CMPD #3
    LBNE IF_NEXT_110
; VPy_LINE:485
; NATIVE_CALL: PRINT_TEXT at line 485
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD >VAR_ARG0
    LDD >VAR_ARG1
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_51      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_107
IF_NEXT_110:
    LDD >VAR_ARG2
    CMPD #4
    LBNE IF_NEXT_111
; VPy_LINE:487
; NATIVE_CALL: PRINT_TEXT at line 487
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD >VAR_ARG0
    LDD >VAR_ARG1
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_52      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_107
IF_NEXT_111:
    LDD >VAR_ARG2
    CMPD #5
    LBNE IF_NEXT_112
; VPy_LINE:489
; NATIVE_CALL: PRINT_TEXT at line 489
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD >VAR_ARG0
    LDD >VAR_ARG1
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_53      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_107
IF_NEXT_112:
    LDD >VAR_ARG2
    CMPD #6
    LBNE IF_NEXT_113
; VPy_LINE:491
; NATIVE_CALL: PRINT_TEXT at line 491
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD >VAR_ARG0
    LDD >VAR_ARG1
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_54      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_107
IF_NEXT_113:
    LDD >VAR_ARG2
    CMPD #7
    LBNE IF_NEXT_114
; VPy_LINE:493
; NATIVE_CALL: PRINT_TEXT at line 493
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD >VAR_ARG0
    LDD >VAR_ARG1
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_55      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_107
IF_NEXT_114:
    LDD >VAR_ARG2
    CMPD #8
    LBNE IF_NEXT_115
; VPy_LINE:495
; NATIVE_CALL: PRINT_TEXT at line 495
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD >VAR_ARG0
    LDD >VAR_ARG1
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_56      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_107
IF_NEXT_115:
    LDD >VAR_ARG2
    CMPD #9
    LBNE IF_NEXT_116
; VPy_LINE:497
; NATIVE_CALL: PRINT_TEXT at line 497
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD >VAR_ARG0
    LDD >VAR_ARG1
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_57      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_107
IF_NEXT_116:
; VPy_LINE:499
; NATIVE_CALL: PRINT_TEXT at line 499
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD >VAR_ARG0
    LDD >VAR_ARG1
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_43      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
IF_END_107:
    RTS

; Function: DRAW_RANK_AT
DRAW_RANK_AT:
; VPy_LINE:502
    LDD >VAR_ARG2
    CMPD #0
    LBNE IF_NEXT_118
; VPy_LINE:503
; NATIVE_CALL: PRINT_TEXT at line 503
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD >VAR_ARG0
    LDD >VAR_ARG1
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_65      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_117
IF_NEXT_118:
    LDD >VAR_ARG2
    CMPD #1
    LBNE IF_NEXT_119
; VPy_LINE:505
; NATIVE_CALL: PRINT_TEXT at line 505
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD >VAR_ARG0
    LDD >VAR_ARG1
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_50      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_117
IF_NEXT_119:
    LDD >VAR_ARG2
    CMPD #2
    LBNE IF_NEXT_120
; VPy_LINE:507
; NATIVE_CALL: PRINT_TEXT at line 507
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD >VAR_ARG0
    LDD >VAR_ARG1
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_51      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_117
IF_NEXT_120:
    LDD >VAR_ARG2
    CMPD #3
    LBNE IF_NEXT_121
; VPy_LINE:509
; NATIVE_CALL: PRINT_TEXT at line 509
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD >VAR_ARG0
    LDD >VAR_ARG1
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_52      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_117
IF_NEXT_121:
    LDD >VAR_ARG2
    CMPD #4
    LBNE IF_NEXT_122
; VPy_LINE:511
; NATIVE_CALL: PRINT_TEXT at line 511
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD >VAR_ARG0
    LDD >VAR_ARG1
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_53      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_117
IF_NEXT_122:
    LDD >VAR_ARG2
    CMPD #5
    LBNE IF_NEXT_123
; VPy_LINE:513
; NATIVE_CALL: PRINT_TEXT at line 513
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD >VAR_ARG0
    LDD >VAR_ARG1
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_54      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_117
IF_NEXT_123:
    LDD >VAR_ARG2
    CMPD #6
    LBNE IF_NEXT_124
; VPy_LINE:515
; NATIVE_CALL: PRINT_TEXT at line 515
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD >VAR_ARG0
    LDD >VAR_ARG1
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_55      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_117
IF_NEXT_124:
    LDD >VAR_ARG2
    CMPD #7
    LBNE IF_NEXT_125
; VPy_LINE:517
; NATIVE_CALL: PRINT_TEXT at line 517
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD >VAR_ARG0
    LDD >VAR_ARG1
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_56      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_117
IF_NEXT_125:
    LDD >VAR_ARG2
    CMPD #8
    LBNE IF_NEXT_126
; VPy_LINE:519
; NATIVE_CALL: PRINT_TEXT at line 519
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD >VAR_ARG0
    LDD >VAR_ARG1
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_57      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_117
IF_NEXT_126:
    LDD >VAR_ARG2
    CMPD #9
    LBNE IF_NEXT_127
; VPy_LINE:521
; NATIVE_CALL: PRINT_TEXT at line 521
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD >VAR_ARG0
    LDD >VAR_ARG1
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_1567      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_117
IF_NEXT_127:
    LDD >VAR_ARG2
    CMPD #10
    LBNE IF_NEXT_128
; VPy_LINE:523
; NATIVE_CALL: PRINT_TEXT at line 523
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD >VAR_ARG0
    LDD >VAR_ARG1
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_74      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_117
IF_NEXT_128:
    LDD >VAR_ARG2
    CMPD #11
    LBNE IF_NEXT_129
; VPy_LINE:525
; NATIVE_CALL: PRINT_TEXT at line 525
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD >VAR_ARG0
    LDD >VAR_ARG1
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_81      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_117
IF_NEXT_129:
; VPy_LINE:527
; NATIVE_CALL: PRINT_TEXT at line 527
    ; PRINT_TEXT: Print text at position
    LDD >VAR_ARG0
    STD >VAR_ARG0
    LDD >VAR_ARG1
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_75      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
IF_END_117:
    RTS

; Function: DRAW_SUIT_AT
DRAW_SUIT_AT:
; VPy_LINE:530
    LDD >VAR_ARG2
    CMPD #0
    LBNE IF_NEXT_131
; VPy_LINE:531
; NATIVE_CALL: DRAW_VECTOR at line 531
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: suit_clubs (index=0, 5 paths)
    LDD >VAR_ARG0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_2          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_ARG1
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_2
    LDB #$FF
.sx_pos_2:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
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
DRVEC_SKIP_2:
    LDD #0
    STD RESULT
    LBRA IF_END_130
IF_NEXT_131:
    LDD >VAR_ARG2
    CMPD #1
    LBNE IF_NEXT_132
; VPy_LINE:533
; NATIVE_CALL: DRAW_VECTOR at line 533
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: suit_diamonds (index=1, 1 paths)
    LDD >VAR_ARG0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_3          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_ARG1
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_3
    LDB #$FF
.sx_pos_3:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_SUIT_DIAMONDS_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_3:
    LDD #0
    STD RESULT
    LBRA IF_END_130
IF_NEXT_132:
    LDD >VAR_ARG2
    CMPD #2
    LBNE IF_NEXT_133
; VPy_LINE:535
; NATIVE_CALL: DRAW_VECTOR at line 535
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: suit_hearts (index=2, 1 paths)
    LDD >VAR_ARG0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_4          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_ARG1
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_4
    LDB #$FF
.sx_pos_4:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_SUIT_HEARTS_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_4:
    LDD #0
    STD RESULT
    LBRA IF_END_130
IF_NEXT_133:
; VPy_LINE:537
; NATIVE_CALL: DRAW_VECTOR at line 537
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: suit_spades (index=3, 3 paths)
    LDD >VAR_ARG0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_5          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_ARG1
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_5
    LDB #$FF
.sx_pos_5:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_SUIT_SPADES_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_SUIT_SPADES_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_SUIT_SPADES_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_5:
    LDD #0
    STD RESULT
IF_END_130:
    RTS

; Function: DRAW_WIN_SCREEN
DRAW_WIN_SCREEN:
; VPy_LINE:541
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_WIN_BLINK
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_WIN_BLINK
; VPy_LINE:542
; NATIVE_CALL: SET_INTENSITY at line 542
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:543
; NATIVE_CALL: PRINT_TEXT at line 543
    ; PRINT_TEXT: Print text at position
    LDD #-42
    STD >VAR_ARG0
    LDD #30
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2521201141606      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:544
; NATIVE_CALL: SET_INTENSITY at line 544
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:545
; NATIVE_CALL: PRINT_TEXT at line 545
    ; PRINT_TEXT: Print text at position
    LDD #-63
    STD >VAR_ARG0
    LDD #0
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_3321124269434895794      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:546
    LDD #30
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_WIN_BLINK
    CMPD TMPVAL
    LBLT .CMP_70_TRUE
    LDD #0
    LBRA .CMP_70_END
.CMP_70_TRUE:
    LDD #1
.CMP_70_END:
    LBEQ IF_NEXT_135
; VPy_LINE:547
; NATIVE_CALL: SET_INTENSITY at line 547
    ; SET_INTENSITY: Set drawing intensity
    LDD #60
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:548
; NATIVE_CALL: PRINT_TEXT at line 548
    ; PRINT_TEXT: Print text at position
    LDD #-63
    STD >VAR_ARG0
    LDD #-30
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2487248696027089637      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_134
IF_NEXT_135:
IF_END_134:
; VPy_LINE:549
    LDD #60
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_WIN_BLINK
    CMPD TMPVAL
    LBGE .CMP_71_TRUE
    LDD #0
    LBRA .CMP_71_END
.CMP_71_TRUE:
    LDD #1
.CMP_71_END:
    LBEQ IF_NEXT_137
; VPy_LINE:550
    LDD #0
    STD VAR_WIN_BLINK
    LBRA IF_END_136
IF_NEXT_137:
IF_END_136:
; VPy_LINE:551
    LDD >VAR_BTN1_FIRE
    CMPD #1
    LBNE IF_NEXT_139
; VPy_LINE:552
    LDD #0  ; const STATE_PLAY
    STD VAR_GAME_STATE
; VPy_LINE:553
    JSR SHUFFLE
; VPy_LINE:554
    JSR DEAL
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
    FDB 5               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
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
    FDB 1               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
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
    FDB 1               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _SUIT_HEARTS_PATH0        ; pointer to path 0

_SUIT_HEARTS_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FA,$00,0,0        ; path0: header (y=-6, x=0)
    FCB $FF,$05,$05          ; flag=-1, dy=5, dx=5
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$04,$FE          ; flag=-1, dy=4, dx=-2
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
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
    FDB 3               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
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
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$04,$02          ; flag=-1, dy=4, dx=2
    FCB $FF,$08,$FA          ; flag=-1, dy=8, dx=-6
    FCB $FF,$FB,$FB          ; flag=-1, dy=-5, dx=-5
    FCB 2                ; End marker (path complete)
;***************************************************************************
; RUNTIME HELPERS
;***************************************************************************

VECTREX_PRINT_TEXT:
    ; VPy signature: PRINT_TEXT(x, y, string)
    ; BIOS signature: Print_Str_d(A=Y, B=X, U=string)
    LDA #$D0
    TFR A,DP
    JSR Intensity_5F
    JSR Reset0Ref
    LDU >VAR_ARG2
    LDA >TEXT_SCALE_H
    STA >$C82A          ; Vec_Text_Height
    LDA >TEXT_SCALE_W
    STA >$C82B          ; Vec_Text_Width
    LDA >VAR_ARG1+1
    LDB >VAR_ARG0+1
    LDX >$C82C
    PSHS X
    JSR Print_Str_d
    PULS X
    STX >$C82C
    LDA #$F8
    STA >$C82A
    LDA #$48
    STA >$C82B
    JSR $F1AF
    RTS

MUL16:
    ; Signed 16x16->16 multiply: D = X * D (lower 16 bits, sign-correct)
    ; Uses 6809 MUL (8x8->16) for constant-time execution.
    ; Stack after PSHS X,B,A: [SP+0]=A=D_hi=b_hi, [SP+1]=B=D_lo=b_lo,
    ;                         [SP+2]=X_hi=a_hi,  [SP+3]=X_lo=a_lo
    ; Result = a_lo*b_lo + (a_hi*b_lo + a_lo*b_hi)*256  (mod 65536)
    PSHS X,B,A
    ; Step 1: a_lo * b_lo -> 16-bit partial product
    LDA 3,S         ; A = a_lo (X low byte)
    LDB 1,S         ; B = b_lo (D low byte)
    MUL             ; D = a_lo * b_lo (unsigned 16-bit)
    STA TMPPTR      ; TMPPTR   = P0_hi (carry into result bits [15:8])
    STB TMPPTR+1    ; TMPPTR+1 = P0_lo (result bits [7:0])
    ; Step 2: a_hi * b_lo -> only low byte adds to result[15:8]
    LDA 2,S         ; A = a_hi (X high byte)
    LDB 1,S         ; B = b_lo (D low byte)
    MUL             ; D = a_hi * b_lo
    ADDB TMPPTR     ; B += P0_hi (ignore carry = mod 256)
    STB TMPPTR      ; TMPPTR = accumulated result[15:8]
    ; Step 3: a_lo * b_hi -> only low byte adds to result[15:8]
    LDA 3,S         ; A = a_lo (X low byte)
    LDB 0,S         ; B = b_hi (D high byte)
    MUL             ; D = a_lo * b_hi
    ADDB TMPPTR     ; B += accumulated result[15:8] (mod 256)
    TFR B,A         ; A = result_hi
    LDB TMPPTR+1    ; B = result_lo
    LEAS 4,S        ; restore stack
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

; === JOYSTICK BUILTIN SUBROUTINES (cached, Joy_Analog runs once per frame) ===
; J1_X() - Read Joystick 1 X axis from cached BIOS value at $C81B
J1X_BUILTIN:
    LDB >$C81B   ; Vec_Joy_1_X (populated each frame by auto-injected Joy_Analog)
    SEX          ; Sign-extend B to D
    ADDD #2      ; Calibrate center offset
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
    
    ; Draw up side (close rectangle: +height closes the -height of down side)
    CLR Vec_Misc_Count
    LDA 3,S             ; +height
    LDB #0
    JSR Draw_Line_d
    
    LDA #$C8
    TFR A,DP            ; Restore DP=$C8 before return
    LEAS 5,S            ; Clean stack
    RTS

Draw_Sync_List_At_With_Mirrors:
; Unified mirror support using flags: MIRROR_X and MIRROR_Y
; Conditionally negates X and/or Y coordinates and deltas
; NOTE: Caller has DP=$D0 for VIA access — RAM vars need '>' extended addressing
LDA >DRAW_VEC_INTENSITY ; Check if intensity override is set
BNE DSWM_USE_OVERRIDE   ; If non-zero, use override
LDA ,X+                 ; Otherwise, read intensity from vector data
BRA DSWM_SET_INTENSITY
DSWM_USE_OVERRIDE:
LEAX 1,X                ; Skip intensity byte in vector data
DSWM_SET_INTENSITY:
STA >$C832              ; Vec_Misc_Count (direct, DP-safe — JSR Intensity_a corrupts DDRB with DP=$D0)
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
; Timing setup (match core: hardcoded $7F)
LDA #$7F
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
CLR VIA_port_a          ; stop X integrator drift between segments
CLR VIA_shift_reg       ; beam off (PB stays 1 for next segment)
LBRA DSWM_LOOP          ; Long branch
; Next path: repeat mirror logic for new path header
DSWM_NEXT_PATH:
TFR X,D
PSHS D
; Check intensity override (same logic as start)
LDA >DRAW_VEC_INTENSITY ; Check if intensity override is set
BNE DSWM_NEXT_USE_OVERRIDE   ; If non-zero, use override
LDA ,X+                 ; Otherwise, read intensity from vector data
BRA DSWM_NEXT_SET_INTENSITY
DSWM_NEXT_USE_OVERRIDE:
LEAX 1,X                ; Skip intensity byte in vector data
DSWM_NEXT_SET_INTENSITY:
PSHS A
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
PULS A                  ; Get intensity back
STA >$C832              ; Vec_Misc_Count (direct, DP-safe)
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
; Timing setup (match core: hardcoded $7F)
LDA #$7F
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
; === SLR_DRAW_CLIPPED_PATH ===
SLR_DRAW_CLIPPED_PATH:
    LDA >DRAW_VEC_INTENSITY ; check override
    BNE SDCP_USE_OVERRIDE
    LDA ,X+                 ; read intensity from path data
    BRA SDCP_SET_INTENS
SDCP_USE_OVERRIDE:
    LEAX 1,X                ; skip intensity byte
SDCP_SET_INTENS:
    STA >$C832              ; Vec_Misc_Count (DDRB-safe, no JSR)
    LDB ,X+                 ; B = y_start (relative to center)
    LDA ,X+                 ; A = x_start (relative to center)
    ADDB >DRAW_VEC_Y        ; B = abs_y
    STB >SDCP_ABS_Y         ; save abs_y for moveto (NOT TMPVAL — SHOW_LEVEL's top_screen lives there)
    TFR A,B                 ; B = x_start (SEX extends B, not A)
    SEX                      ; sign-extend B→D (A=sign, B=x_start)
    ADDD >DRAW_VEC_X_HI     ; D = abs_x_16 = SEX(x_start) + screen_x_16
    ; D = abs_x_16. Save it in 16-bit tracker SLR_TRUE_X (unclamped).
    STD >SLR_TRUE_X
    ; Compute clamped beam position for hardware Moveto.
    TSTA
    BEQ SDCP_INIT_POS
    INCA
    BEQ SDCP_INIT_NEG_OK    ; A was $FF (small negative)
    ; Way off — clamp to nearest edge by sign of original A (now in INCA result)
    LDB #$80                ; default to left edge
    LDA >SLR_TRUE_X         ; original hi byte
    BMI SDCP_USE_CLAMPED    ; negative → -128 (left)
    LDB #$7F                ; positive way off → +127 (right)
    BRA SDCP_USE_CLAMPED
SDCP_INIT_NEG_OK:
    CMPB #$80
    BHS SDCP_USE_CLAMPED    ; -128..-1, valid
    LDB #$80                ; clamp
    BRA SDCP_USE_CLAMPED
SDCP_INIT_POS:
    CMPB #$7F
    BLS SDCP_USE_CLAMPED
    LDB #$7F                ; clamp positive
SDCP_USE_CLAMPED:
    TFR B,A                  ; A = clamped beam x
    STA >SLR_CUR_X          ; clamped value goes to integrator
    CLR VIA_shift_reg
    LDA #$CC
    STA VIA_cntl
    CLR VIA_port_a
    LDA #$03
    STA VIA_port_b
    LDA #$02
    STA VIA_port_b
    LDA #$02
    STA VIA_port_b
    LDA #$01
    STA VIA_port_b
    LDB >SDCP_ABS_Y         ; B = abs_y
    STB VIA_port_a          ; DY → DAC (PB=1: hold)
    CLR VIA_port_b          ; PB=0: enable mux, beam tracks Y
    LDA >SLR_CUR_X          ; abs_x (load = settling for Y)
    PSHS A                  ; ~4 more settling cycles
    LDA #$CE
    STA VIA_cntl            ; PCR=$CE: /ZERO high
    CLR VIA_shift_reg       ; SR=0: beam off
    INC VIA_port_b          ; PB=1: lock Y direction
    PULS A                  ; restore abs_x
    STA VIA_port_a          ; DX → DAC
    LDA >DRAW_T1_SCALED     ; effective T1 for this object (scale * 127)
    STA VIA_t1_cnt_lo       ; load T1 latch
    LEAX 2,X                ; skip next_y, next_x (the 0,0)
    CLR VIA_t1_cnt_hi       ; start T1 → ramp
SDCP_MOVETO_W:
    LDA VIA_int_flags
    ANDA #$40
    BEQ SDCP_MOVETO_W
    ; PB=1 on exit — draw loop ready
SDCP_SEG_LOOP:
    LDA ,X+                 ; flags
    CMPA #2
    LBEQ SDCP_DONE
    LDB ,X+                 ; B = dy
    STB >TMPPTR2            ; save dy
    LDA ,X+                 ; A = dx (8-bit signed)
    ; --- 16-bit add: true_new_x_16 = SLR_TRUE_X + SEX(dx) ---
    TFR A,B                 ; B = dx
    SEX                      ; D = sign-extended dx (A=sign, B=dx)
    ADDD >SLR_TRUE_X        ; D = new true_x_16
    STD >SLR_TRUE_X         ; update 16-bit tracker
    ; --- Clamp D to [-128, +127] → 8-bit clamped_new_x in B ---
    TSTA
    BEQ SDCP_SEG_POS
    INCA
    BEQ SDCP_SEG_NEG_OK     ; A was $FF
    ; Way off — clamp by sign of original D
    LDA >SLR_TRUE_X         ; reload hi byte
    BMI SDCP_SEG_CLAMP_LEFT
    LDB #$7F                ; positive way off → +127
    BRA SDCP_SEG_CLAMPED
SDCP_SEG_CLAMP_LEFT:
    LDB #$80                ; negative way off → -128
    BRA SDCP_SEG_CLAMPED
SDCP_SEG_NEG_OK:
    CMPB #$80
    BHS SDCP_SEG_CLAMPED
    LDB #$80
    BRA SDCP_SEG_CLAMPED
SDCP_SEG_POS:
    CMPB #$7F
    BLS SDCP_SEG_CLAMPED
    LDB #$7F
SDCP_SEG_CLAMPED:
    ; B = clamped_new_x. Compute beam_dx = B - SLR_CUR_X (8-bit signed).
    LDA >SLR_CUR_X
    PSHS B                  ; save clamped_new_x
    NEGA                    ; A = -cur_x
    ADDA ,S                 ; A = clamped_new_x - cur_x = beam_dx
    PULS B                  ; B = clamped_new_x
    ; Update SLR_CUR_X to new clamped position
    STB >SLR_CUR_X
    ; Decide beam ON/OFF/skip:
    ; - beam_dx != 0                       → beam ON,  ramp(beam_dx, dy)
    ; - beam_dx == 0 AND cur at edge AND dy==0 → skip (zero motion)
    ; - beam_dx == 0 AND cur at edge AND dy!=0 → beam OFF ramp(0, dy)
    ;   (Y must track logical position so subsequent segments draw at correct Y)
    ; - beam_dx == 0 AND not at edge       → beam ON,  ramp(0, dy) — vertical
    TSTA
    BNE SDCP_SEG_DRAW       ; non-zero beam_dx → draw
    CMPB #$80               ; at left edge?
    BEQ SDCP_SEG_OFF_X      ; yes → fully off-screen left
    CMPB #$7F               ; at right edge?
    BEQ SDCP_SEG_OFF_X      ; yes → fully off-screen right
SDCP_SEG_DRAW:
    LDB >TMPPTR2            ; restore dy
    ; A = beam_dx (visible X delta), B = dy. Beam ON ramp.
    STB VIA_port_a          ; DY → DAC (PB=1: hold)
    CLR VIA_port_b          ; PB=0: mux for DY
    NOP
    NOP
    NOP
    INC VIA_port_b          ; PB=1: lock DY
    STA VIA_port_a          ; DX → DAC
    LDA #$FF
    STA VIA_shift_reg       ; beam ON
    CLR VIA_t1_cnt_hi       ; start T1
SDCP_W_DRAW:
    LDA VIA_int_flags
    ANDA #$40
    BEQ SDCP_W_DRAW
    CLR VIA_shift_reg       ; beam OFF
    LBRA SDCP_SEG_LOOP

    ; --- Off-screen-X path: dx contribution is invisible, but Y must track ---
SDCP_SEG_OFF_X:
    LDB >TMPPTR2            ; B = dy
    TSTB                     ; dy == 0?
    LBEQ SDCP_SEG_LOOP      ; no Y motion either → skip entire segment
    ; Ramp(0, dy) with beam OFF. A is already 0 (beam_dx).
    CLRA                     ; defensive: ensure dx=0
    STB VIA_port_a          ; DY → DAC
    CLR VIA_port_b
    NOP
    NOP
    NOP
    INC VIA_port_b
    STA VIA_port_a          ; DX = 0
    ; beam stays OFF (no STA VIA_shift_reg)
    CLR VIA_t1_cnt_hi       ; start T1 (ramp, beam off)
SDCP_W_OFF_X:
    LDA VIA_int_flags
    ANDA #$40
    BEQ SDCP_W_OFF_X
    LBRA SDCP_SEG_LOOP

SDCP_DONE:
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

