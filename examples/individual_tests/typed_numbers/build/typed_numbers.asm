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
    FCC "TYPED"
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
NUM_STR              EQU $C880+$0E   ; Buffer for PRINT_NUMBER decimal output (5 digits + terminator) (6 bytes)
DRAW_CIRCLE_XC       EQU $C880+$14   ; Circle center X (1 bytes)
DRAW_CIRCLE_YC       EQU $C880+$15   ; Circle center Y (1 bytes)
DRAW_CIRCLE_DIAM     EQU $C880+$16   ; Circle diameter (1 bytes)
DRAW_CIRCLE_INTENSITY EQU $C880+$17   ; Circle intensity (1 bytes)
DRAW_CIRCLE_RADIUS   EQU $C880+$18   ; Circle radius (diam/2) - used in segment drawing (1 bytes)
DRAW_CIRCLE_TEMP     EQU $C880+$19   ; Circle temporary buffer (8 bytes: radius16, a, b, c, d, --, --)  a=0.383r b=0.324r c=0.217r d=0.076r (8 bytes)
DRAW_VEC_INTENSITY   EQU $C880+$21   ; Vector intensity override (0=use vector data) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$22   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$2C   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$2E   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$30   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$31   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$32   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$34   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$36   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$37   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
PN_LAST_VAL          EQU $C880+$38   ; PRINT_NUMBER: last rendered numeric value (cache key) (2 bytes)
PN_LAST_VALID        EQU $C880+$3A   ; PRINT_NUMBER: 1 if PN_LAST_VAL holds a valid render (1 bytes)
PN_LAST_X            EQU $C880+$3B   ; PRINT_NUMBER: last rendered X (cache key) (1 bytes)
PN_LAST_Y            EQU $C880+$3C   ; PRINT_NUMBER: last rendered Y (cache key) (1 bytes)
VAR_ARG0             EQU $C880+$3D   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $C880+$3F   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $C880+$41   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $C880+$43   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $C880+$45   ; Function argument 4 (16-bit) (2 bytes)
VAR_ARG5             EQU $C880+$47   ; Function argument 5 (16-bit) (2 bytes)
VAR_ARG6             EQU $C880+$49   ; Function argument 6 (16-bit) (2 bytes)
VAR_ARG7             EQU $C880+$4B   ; Function argument 7 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $C880+$4D   ; Current ROM bank ID (multibank tracking) (1 bytes)
VAR_U8_VAL           EQU $C880+$4E   ; User variable: U8_VAL (1 bytes)
VAR_I8_VAL           EQU $C880+$4F   ; User variable: I8_VAL (1 bytes)
VAR_U16_VAL          EQU $C880+$50   ; User variable: U16_VAL (2 bytes)
VAR_I16_VAL          EQU $C880+$52   ; User variable: I16_VAL (2 bytes)
VAR_ROW_Y            EQU $C880+$54   ; User variable: ROW_Y (2 bytes)
VAR_SELECTED         EQU $C880+$56   ; User variable: SELECTED (1 bytes)
VAR_COOLDOWN         EQU $C880+$57   ; User variable: COOLDOWN (1 bytes)
VAR_ARR_IDX          EQU $C880+$58   ; User variable: ARR_IDX (1 bytes)
VAR_ARR_TICK         EQU $C880+$59   ; User variable: ARR_TICK (1 bytes)
VAR_JOY_Y            EQU $C880+$5A   ; User variable: JOY_Y (2 bytes)
VAR_U8_ARR           EQU $C880+$5C   ; User variable: U8_ARR (2 bytes)
VAR_I8_ARR           EQU $C880+$5E   ; User variable: I8_ARR (2 bytes)
VAR_U16_ARR          EQU $C880+$60   ; User variable: U16_ARR (2 bytes)
VAR_I16_ARR          EQU $C880+$62   ; User variable: I16_ARR (2 bytes)
VAR_U8_ARR_DATA      EQU $C880+$64   ; Mutable array 'U8_ARR' data (4 elements x 1 bytes) (4 bytes)
VAR_I8_ARR_DATA      EQU $C880+$68   ; Mutable array 'I8_ARR' data (4 elements x 1 bytes) (4 bytes)
VAR_U16_ARR_DATA     EQU $C880+$6C   ; Mutable array 'U16_ARR' data (4 elements x 2 bytes) (8 bytes)
VAR_I16_ARR_DATA     EQU $C880+$74   ; Mutable array 'I16_ARR' data (4 elements x 2 bytes) (8 bytes)
; Array length constants
ARRAY_U8_ARR_LEN         EQU 4   ; 4 elements
ARRAY_I8_ARR_LEN         EQU 4   ; 4 elements
ARRAY_U16_ARR_LEN         EQU 4   ; 4 elements
ARRAY_I16_ARR_LEN         EQU 4   ; 4 elements
ARRAY_ROW_Y_LEN         EQU 4   ; 4 elements

;***************************************************************************
; ARRAY DATA (ROM literals)
;***************************************************************************
; Arrays are stored in ROM and accessed via pointers
; At startup, main() initializes VAR_{name} to point to ARRAY_{name}_DATA

; Array literal for variable 'U8_ARR' (4 elements, 1 bytes each)
ARRAY_U8_ARR_DATA:
    FCB $0A   ; Element 0
    FCB $32   ; Element 1
    FCB $96   ; Element 2
    FCB $FA   ; Element 3

; Array literal for variable 'I8_ARR' (4 elements, 1 bytes each)
ARRAY_I8_ARR_DATA:
    FCB $88   ; Element 0
    FCB $D8   ; Element 1
    FCB $28   ; Element 2
    FCB $78   ; Element 3

; Array literal for variable 'U16_ARR' (4 elements, 2 bytes each)
ARRAY_U16_ARR_DATA:
    FDB 0   ; Element 0
    FDB 1000   ; Element 1
    FDB 30000   ; Element 2
    FDB 65535   ; Element 3

; Array literal for variable 'I16_ARR' (4 elements, 2 bytes each)
ARRAY_I16_ARR_DATA:
    FDB -32000   ; Element 0
    FDB -500   ; Element 1
    FDB 500   ; Element 2
    FDB 32000   ; Element 3

; Array literal for variable 'ROW_Y' (4 elements, 2 bytes each)
ARRAY_ROW_Y_DATA:
    FDB 100   ; Element 0
    FDB 65   ; Element 1
    FDB 30   ; Element 2
    FDB -5   ; Element 3


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
    LDD #200
    STD VAR_U8_VAL
    LDD #-100
    STD VAR_I8_VAL
    LDD #60000
    STD VAR_U16_VAL
    LDD #-30000
    STD VAR_I16_VAL
    ; Copy array 'U8_ARR' from ROM to RAM (4 elements)
    LDX #ARRAY_U8_ARR_DATA       ; Source: ROM array data
    LDU #VAR_U8_ARR_DATA       ; Dest: RAM array space
    LDD #4        ; Number of elements
.COPY_LOOP_0:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_0 ; Loop until done (LBNE for long branch)
    LDX #VAR_U8_ARR_DATA    ; Array now in RAM
    STX VAR_U8_ARR
    ; Copy array 'I8_ARR' from ROM to RAM (4 elements)
    LDX #ARRAY_I8_ARR_DATA       ; Source: ROM array data
    LDU #VAR_I8_ARR_DATA       ; Dest: RAM array space
    LDD #4        ; Number of elements
.COPY_LOOP_1:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_1 ; Loop until done (LBNE for long branch)
    LDX #VAR_I8_ARR_DATA    ; Array now in RAM
    STX VAR_I8_ARR
    ; Copy array 'U16_ARR' from ROM to RAM (4 elements)
    LDX #ARRAY_U16_ARR_DATA       ; Source: ROM array data
    LDU #VAR_U16_ARR_DATA       ; Dest: RAM array space
    LDD #4        ; Number of elements
.COPY_LOOP_2:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_2 ; Loop until done (LBNE for long branch)
    LDX #VAR_U16_ARR_DATA    ; Array now in RAM
    STX VAR_U16_ARR
    ; Copy array 'I16_ARR' from ROM to RAM (4 elements)
    LDX #ARRAY_I16_ARR_DATA       ; Source: ROM array data
    LDU #VAR_I16_ARR_DATA       ; Dest: RAM array space
    LDD #4        ; Number of elements
.COPY_LOOP_3:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_3 ; Loop until done (LBNE for long branch)
    LDX #VAR_I16_ARR_DATA    ; Array now in RAM
    STX VAR_I16_ARR
    LDD #0
    STD VAR_SELECTED
    LDD #0
    STD VAR_COOLDOWN
    LDD #0
    STD VAR_ARR_IDX
    LDD #0
    STD VAR_ARR_TICK
    LDD #0
    STD VAR_JOY_Y
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
; VPy_LINE:32
; NATIVE_CALL: SET_INTENSITY at line 32
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:33
    LDD #0
    STB VAR_SELECTED
; VPy_LINE:34
    LDD #0
    STB VAR_COOLDOWN
; VPy_LINE:35
    LDD #0
    STB VAR_ARR_IDX
; VPy_LINE:36
    LDD #0
    STB VAR_ARR_TICK
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
; VPy_LINE:40
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDB >VAR_ARR_TICK
    CLRA            ; Zero-extend: A=0, B=value
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STB VAR_ARR_TICK
; VPy_LINE:41
    LDD #30
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_ARR_TICK
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBGT .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_1
; VPy_LINE:42
    LDD #0
    STB VAR_ARR_TICK
; VPy_LINE:43
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDB >VAR_ARR_IDX
    CLRA            ; Zero-extend: A=0, B=value
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STB VAR_ARR_IDX
; VPy_LINE:44
    LDD #3
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_ARR_IDX
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBGT .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    LBEQ IF_NEXT_3
; VPy_LINE:45
    LDD #0
    STB VAR_ARR_IDX
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
; VPy_LINE:48
; NATIVE_CALL: J1_Y at line 48
    JSR J1Y_BUILTIN
    STD RESULT
    STD VAR_JOY_Y
; VPy_LINE:50
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_COOLDOWN
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBGT .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    LBEQ IF_NEXT_5
; VPy_LINE:51
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDB >VAR_COOLDOWN
    CLRA            ; Zero-extend: A=0, B=value
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STB VAR_COOLDOWN
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
; VPy_LINE:53
    LDB >VAR_COOLDOWN
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #0
    LBNE IF_NEXT_7
; VPy_LINE:55
    LDD #60
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_Y
    CMPD TMPVAL
    LBGT .CMP_3_TRUE
    LDD #0
    LBRA .CMP_3_END
.CMP_3_TRUE:
    LDD #1
.CMP_3_END:
    LBEQ IF_NEXT_9
; VPy_LINE:56
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBGT .CMP_4_TRUE
    LDD #0
    LBRA .CMP_4_END
.CMP_4_TRUE:
    LDD #1
.CMP_4_END:
    LBEQ IF_NEXT_11
; VPy_LINE:57
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STB VAR_SELECTED
    LBRA IF_END_10
IF_NEXT_11:
IF_END_10:
; VPy_LINE:58
    LDD #15
    STB VAR_COOLDOWN
    LBRA IF_END_8
IF_NEXT_9:
IF_END_8:
; VPy_LINE:60
    LDD #-60
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_Y
    CMPD TMPVAL
    LBLT .CMP_5_TRUE
    LDD #0
    LBRA .CMP_5_END
.CMP_5_TRUE:
    LDD #1
.CMP_5_END:
    LBEQ IF_NEXT_13
; VPy_LINE:61
    LDD #3
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    CMPD TMPVAL
    LBLT .CMP_6_TRUE
    LDD #0
    LBRA .CMP_6_END
.CMP_6_TRUE:
    LDD #1
.CMP_6_END:
    LBEQ IF_NEXT_15
; VPy_LINE:62
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STB VAR_SELECTED
    LBRA IF_END_14
IF_NEXT_15:
IF_END_14:
; VPy_LINE:63
    LDD #15
    STB VAR_COOLDOWN
    LBRA IF_END_12
IF_NEXT_13:
IF_END_12:
; VPy_LINE:66
    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed
    BITA #$01
    BNE .J1B1_0_ON
    LDD #0
    BRA .J1B1_0_END
.J1B1_0_ON:
    LDD #1
.J1B1_0_END:
    STD RESULT
    LBEQ IF_NEXT_17
; VPy_LINE:67
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #0
    LBNE IF_NEXT_19
; VPy_LINE:68
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDB >VAR_U8_VAL
    CLRA            ; Zero-extend: A=0, B=value
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STB VAR_U8_VAL
    LBRA IF_END_18
IF_NEXT_19:
IF_END_18:
; VPy_LINE:69
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #1
    LBNE IF_NEXT_21
; VPy_LINE:70
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDB >VAR_I8_VAL
    SEX             ; Sign-extend B -> D
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STB VAR_I8_VAL
    LBRA IF_END_20
IF_NEXT_21:
IF_END_20:
; VPy_LINE:71
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #2
    LBNE IF_NEXT_23
; VPy_LINE:72
    LDD #100
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_U16_VAL
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_U16_VAL
    LBRA IF_END_22
IF_NEXT_23:
IF_END_22:
; VPy_LINE:73
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #3
    LBNE IF_NEXT_25
; VPy_LINE:74
    LDD #100
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I16_VAL
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_I16_VAL
    LBRA IF_END_24
IF_NEXT_25:
IF_END_24:
; VPy_LINE:75
    LDD #4
    STB VAR_COOLDOWN
    LBRA IF_END_16
IF_NEXT_17:
IF_END_16:
; VPy_LINE:78
    LDA >$C80F   ; Vec_Btns_1: bit1=1 means btn2 pressed
    BITA #$02
    BNE .J1B2_1_ON
    LDD #0
    BRA .J1B2_1_END
.J1B2_1_ON:
    LDD #1
.J1B2_1_END:
    STD RESULT
    LBEQ IF_NEXT_27
; VPy_LINE:79
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #0
    LBNE IF_NEXT_29
; VPy_LINE:80
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDB >VAR_U8_VAL
    CLRA            ; Zero-extend: A=0, B=value
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STB VAR_U8_VAL
    LBRA IF_END_28
IF_NEXT_29:
IF_END_28:
; VPy_LINE:81
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #1
    LBNE IF_NEXT_31
; VPy_LINE:82
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDB >VAR_I8_VAL
    SEX             ; Sign-extend B -> D
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STB VAR_I8_VAL
    LBRA IF_END_30
IF_NEXT_31:
IF_END_30:
; VPy_LINE:83
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #2
    LBNE IF_NEXT_33
; VPy_LINE:84
    LDD #100
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_U16_VAL
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_U16_VAL
    LBRA IF_END_32
IF_NEXT_33:
IF_END_32:
; VPy_LINE:85
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    CMPD #3
    LBNE IF_NEXT_35
; VPy_LINE:86
    LDD #100
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I16_VAL
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_I16_VAL
    LBRA IF_END_34
IF_NEXT_35:
IF_END_34:
; VPy_LINE:87
    LDD #4
    STB VAR_COOLDOWN
    LBRA IF_END_26
IF_NEXT_27:
IF_END_26:
; VPy_LINE:90
    LDA >$C80F   ; Vec_Btns_1: bit2=1 means btn3 pressed
    BITA #$04
    BNE .J1B3_2_ON
    LDD #0
    BRA .J1B3_2_END
.J1B3_2_ON:
    LDD #1
.J1B3_2_END:
    STD RESULT
    LBEQ IF_NEXT_37
; VPy_LINE:91
    LDD #200
    STB VAR_U8_VAL
; VPy_LINE:92
    LDD #-100
    STB VAR_I8_VAL
; VPy_LINE:93
    LDD #60000
    STD VAR_U16_VAL
; VPy_LINE:94
    LDD #-30000
    STD VAR_I16_VAL
; VPy_LINE:95
    LDD #0
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_U8_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #10
    PULS X          ; Restore computed address
    STB ,X          ; Store 8-bit value
; VPy_LINE:96
    LDD #1
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_U8_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #50
    PULS X          ; Restore computed address
    STB ,X          ; Store 8-bit value
; VPy_LINE:97
    LDD #2
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_U8_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #150
    PULS X          ; Restore computed address
    STB ,X          ; Store 8-bit value
; VPy_LINE:98
    LDD #3
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_U8_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #250
    PULS X          ; Restore computed address
    STB ,X          ; Store 8-bit value
; VPy_LINE:99
    LDD #0
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_I8_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #-120
    PULS X          ; Restore computed address
    STB ,X          ; Store 8-bit value
; VPy_LINE:100
    LDD #1
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_I8_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #-40
    PULS X          ; Restore computed address
    STB ,X          ; Store 8-bit value
; VPy_LINE:101
    LDD #2
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_I8_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #40
    PULS X          ; Restore computed address
    STB ,X          ; Store 8-bit value
; VPy_LINE:102
    LDD #3
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_I8_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #120
    PULS X          ; Restore computed address
    STB ,X          ; Store 8-bit value
; VPy_LINE:103
    LDD #0
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_U16_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #0
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:104
    LDD #1
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_U16_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #1000
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:105
    LDD #2
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_U16_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #30000
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:106
    LDD #3
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_U16_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #65535
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:107
    LDD #0
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_I16_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #-32000
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:108
    LDD #1
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_I16_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #-500
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:109
    LDD #2
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_I16_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #500
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:110
    LDD #3
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_I16_ARR_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #32000
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:111
    LDD #15
    STB VAR_COOLDOWN
    LBRA IF_END_36
IF_NEXT_37:
IF_END_36:
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
; VPy_LINE:118
; NATIVE_CALL: PRINT_TEXT at line 118
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD >VAR_ARG0
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2691      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:119
; NATIVE_CALL: PRINT_NUMBER at line 119
    ; PRINT_NUMBER(x, y, num)
    LDD #-55
    STD >VAR_ARG0    ; X position
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD >VAR_ARG1    ; Y position
    LDB >VAR_U8_VAL
    CLRA            ; Zero-extend: A=0, B=value
    STD >VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
; VPy_LINE:120
; NATIVE_CALL: PRINT_TEXT at line 120
    ; PRINT_TEXT: Print text at position
    LDD #5
    STD >VAR_ARG0
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2058      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:121
; NATIVE_CALL: PRINT_NUMBER at line 121
    ; PRINT_NUMBER(x, y, num)
    LDD #30
    STD >VAR_ARG0    ; X position
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD >VAR_ARG1    ; Y position
    LDX #VAR_U8_ARR_DATA  ; Array base
    LDB >VAR_ARR_IDX
    CLRA            ; Zero-extend: A=0, B=value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    STD >VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
; VPy_LINE:124
; NATIVE_CALL: PRINT_TEXT at line 124
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD >VAR_ARG0
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_71921      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:125
; NATIVE_CALL: PRINT_NUMBER at line 125
    ; PRINT_NUMBER(x, y, num)
    LDD #-55
    STD >VAR_ARG0    ; X position
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD >VAR_ARG1    ; Y position
    LDB >VAR_I8_VAL
    SEX             ; Sign-extend B -> D
    STD >VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
; VPy_LINE:126
; NATIVE_CALL: PRINT_TEXT at line 126
    ; PRINT_TEXT: Print text at position
    LDD #5
    STD >VAR_ARG0
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2058      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:127
; NATIVE_CALL: PRINT_NUMBER at line 127
    ; PRINT_NUMBER(x, y, num)
    LDD #30
    STD >VAR_ARG0    ; X position
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD >VAR_ARG1    ; Y position
    LDX #VAR_I8_ARR_DATA  ; Array base
    LDB >VAR_ARR_IDX
    CLRA            ; Zero-extend: A=0, B=value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index (stride = 1 for 8-bit)
    LEAX D,X    ; X = base + (index * element_size)
    LDB ,X      ; Load 8-bit value
    CLRA        ; Zero-extend to 16-bit (arrays are typically unsigned)
    STD >VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
; VPy_LINE:130
; NATIVE_CALL: PRINT_TEXT at line 130
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD >VAR_ARG0
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_83258      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:131
; NATIVE_CALL: PRINT_NUMBER at line 131
    ; PRINT_NUMBER(x, y, num)
    LDD #-55
    STD >VAR_ARG0    ; X position
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD >VAR_ARG1    ; Y position
    LDD >VAR_U16_VAL
    STD >VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
; VPy_LINE:132
; NATIVE_CALL: PRINT_TEXT at line 132
    ; PRINT_TEXT: Print text at position
    LDD #5
    STD >VAR_ARG0
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2058      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:133
; NATIVE_CALL: PRINT_NUMBER at line 133
    ; PRINT_NUMBER(x, y, num)
    LDD #30
    STD >VAR_ARG0    ; X position
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD >VAR_ARG1    ; Y position
    LDX #VAR_U16_ARR_DATA  ; Array base
    LDB >VAR_ARR_IDX
    CLRA            ; Zero-extend: A=0, B=value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD >VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
; VPy_LINE:136
; NATIVE_CALL: PRINT_TEXT at line 136
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD >VAR_ARG0
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_71726      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:137
; NATIVE_CALL: PRINT_NUMBER at line 137
    ; PRINT_NUMBER(x, y, num)
    LDD #-55
    STD >VAR_ARG0    ; X position
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD >VAR_ARG1    ; Y position
    LDD >VAR_I16_VAL
    STD >VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
; VPy_LINE:138
; NATIVE_CALL: PRINT_TEXT at line 138
    ; PRINT_TEXT: Print text at position
    LDD #5
    STD >VAR_ARG0
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2058      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:139
; NATIVE_CALL: PRINT_NUMBER at line 139
    ; PRINT_NUMBER(x, y, num)
    LDD #30
    STD >VAR_ARG0    ; X position
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD >VAR_ARG1    ; Y position
    LDX #VAR_I16_ARR_DATA  ; Array base
    LDB >VAR_ARR_IDX
    CLRA            ; Zero-extend: A=0, B=value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD >VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
; VPy_LINE:142
; NATIVE_CALL: PRINT_TEXT at line 142
    ; PRINT_TEXT: Print text at position
    LDD #-40
    STD >VAR_ARG0
    LDD #-22
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_72349      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:143
; NATIVE_CALL: PRINT_NUMBER at line 143
    ; PRINT_NUMBER(x, y, num)
    LDD #10
    STD >VAR_ARG0    ; X position
    LDD #-22
    STD >VAR_ARG1    ; Y position
    LDB >VAR_ARR_IDX
    CLRA            ; Zero-extend: A=0, B=value
    STD >VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
; VPy_LINE:146
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with radius
    LDD #-125
    TFR B,A
    STA DRAW_CIRCLE_XC
    LDX #ARRAY_ROW_Y_DATA  ; Array base
    LDB >VAR_SELECTED
    CLRA            ; Zero-extend: A=0, B=value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    TFR B,A
    STA DRAW_CIRCLE_YC
    LDD #10
    TFR B,A
    STA DRAW_CIRCLE_DIAM
    LDD #60
    TFR B,A
    STA DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    RTS

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

VECTREX_PRINT_NUMBER:
    ; Print signed decimal number (-9999 to 9999)
    ; ARG0=x, ARG1=y, ARG2=value
    ;
    ; CACHE CHECK: if (value,x,y) matches the previous render, skip the
    ; entire DIVMOD pipeline (saves ~200 cycles) and reuse NUM_STR as-is.
    ; Drawing must still happen every frame (phosphor decay) so we go
    ; straight to PN_AFTER_CONVERT with NUM_STR already populated.
    LDA >PN_LAST_VALID
    BEQ .PN_NO_CACHE       ; first call → must convert
    LDD >VAR_ARG2
    CMPD >PN_LAST_VAL
    BNE .PN_NO_CACHE
    LDA >VAR_ARG0+1
    CMPA >PN_LAST_X
    BNE .PN_NO_CACHE
    LDA >VAR_ARG1+1
    CMPA >PN_LAST_Y
    BNE .PN_NO_CACHE
    LBRA .PN_AFTER_CONVERT  ; cache hit — NUM_STR still valid
.PN_NO_CACHE:
    ; Update cache key BEFORE conversion (value/x/y will be needed later)
    LDD >VAR_ARG2
    STD >PN_LAST_VAL
    LDA >VAR_ARG0+1
    STA >PN_LAST_X
    LDA >VAR_ARG1+1
    STA >PN_LAST_Y
    LDA #1
    STA >PN_LAST_VALID
    ;
    ; STEP 1: Convert number to decimal string (DP=$C8)
    LDD >VAR_ARG2   ; Load 16-bit value (safe: DP=$C8)
    STD >TMPVAL      ; Save to temp
    LDX #NUM_STR    ; String buffer pointer
    
    ; Check sign: negative values get '-' prefix and are negated
    CMPD #0
    BPL .PN_DIV1000  ; D >= 0: go directly to digit conversion
    LDA #'-'
    STA ,X+          ; Store '-', advance buffer pointer
    LDD >TMPVAL
    COMA
    COMB
    ADDD #1          ; Two's complement negation -> absolute value
    STD >TMPVAL
    
    ; --- 1000s digit ---
.PN_DIV1000:
    CLR ,X           ; Counter = 0 (in buffer)
.PN_L1000:
    LDD >TMPVAL
    SUBD #1000
    BMI .PN_D1000
    STD >TMPVAL      ; Store reduced value
    INC ,X           ; Increment digit counter
    BRA .PN_L1000
.PN_D1000:
    LDA ,X           ; Get count
    ADDA #'0'        ; Convert to ASCII
    STA ,X+          ; Store and advance
    
    ; --- 100s digit ---
    CLR ,X
.PN_L100:
    LDD >TMPVAL
    SUBD #100
    BMI .PN_D100
    STD >TMPVAL
    INC ,X
    BRA .PN_L100
.PN_D100:
    LDA ,X
    ADDA #'0'
    STA ,X+
    
    ; --- 10s digit ---
    CLR ,X
.PN_L10:
    LDD >TMPVAL
    SUBD #10
    BMI .PN_D10
    STD >TMPVAL
    INC ,X
    BRA .PN_L10
.PN_D10:
    LDA ,X
    ADDA #'0'
    STA ,X+
    
    ; --- 1s digit (remainder) ---
    LDD >TMPVAL
    ADDB #'0'        ; Low byte = ones digit
    STB ,X+          ; Store digit
    LDA #$80          ; Terminator (same format as FCC/FCB $80 strings)
    STA ,X
    
    ; --- RIGHT-ALIGN: shift significant digits LEFT, pad right with spaces ---
    ; Keeps the buffer at 4 chars (BIOS Print_Str needs minimum width) but
    ; lets the number start at the call's X coordinate. Examples:
    ;   PRINT_NUMBER(x, y, 6)    → "6   "  (6 at x, then 3 trailing spaces)
    ;   PRINT_NUMBER(x, y, 12)   → "12  "
    ;   PRINT_NUMBER(x, y, 1234) → "1234"
    ;   PRINT_NUMBER(x, y, -5)   → "-5  "
    LDX #NUM_STR
    LDA ,X
    CMPA #'-'           ; if negative, '-' stays at [0]; sig digits start at [1]
    BNE .PN_RP_START
    LEAX 1,X
.PN_RP_START:
    TFR X,U             ; U = dest (start of digit area, after optional '-')
    LDB #0              ; B = leading-zero count
.PN_RP_FIND:
    LDA ,X
    CMPA #'0'
    BNE .PN_RP_FOUND    ; first non-'0' → start of sig digits
    LDA 1,X             ; check next byte
    CMPA #$80           ; if terminator, current '0' is the units digit — keep it
    BEQ .PN_RP_FOUND
    INCB
    LEAX 1,X
    BRA .PN_RP_FIND
.PN_RP_FOUND:
    TSTB
    BEQ .PN_RP_DONE     ; no leading zeros → nothing to shift
    ; Copy from X (first sig digit) to U (start), include $80 terminator
.PN_RP_COPY:
    LDA ,X+
    STA ,U+
    CMPA #$80
    BNE .PN_RP_COPY
    ; U is past the copied $80. Back up to that position and overwrite
    ; with B spaces, then place new $80 terminator at end.
    LEAU -1,U           ; U = where the $80 was just written
.PN_RP_PAD:
    LDA #' '
    STA ,U+
    DECB
    BNE .PN_RP_PAD
    LDA #$80
    STA ,U              ; final terminator
.PN_RP_DONE:
.PN_AFTER_CONVERT:
    ; STEP 2: hand the rendered NUM_STR to VECTREX_PRINT_TEXT, which uses
    ; the custom vector font path (consistent visual with PiTrex/RP2350).
    LDX #NUM_STR
    STX >VAR_ARG2     ; PRINT_TEXT reads string ptr from VAR_ARG2
    JSR VECTREX_PRINT_TEXT
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

; J1_Y() - Read Joystick 1 Y axis from cached BIOS value at $C81C
J1Y_BUILTIN:
    LDB >$C81C   ; Vec_Joy_1_Y
    SEX
    ADDD #2
    RTS

; ============================================================================
; DRAW_CIRCLE_RUNTIME - Draw circle with runtime parameters
; ============================================================================
; Follows Draw_Sync_List_At pattern: read params BEFORE DP change
; Inputs: DRAW_CIRCLE_XC, DRAW_CIRCLE_YC, DRAW_CIRCLE_DIAM, DRAW_CIRCLE_INTENSITY (bytes in RAM)
; Uses 16-segment polygon (same as constant path) via MUL scaling of fixed fractions
; 4 unique delta fractions of radius r (16-gon, vertices at k*22.5 deg):
;   a = 0.3827*r (sin22.5) via MUL #98 /256, stored at >DRAW_CIRCLE_TEMP+2
;   b = 0.3244*r (sin45-sin22.5) via MUL #83 /256, stored at >DRAW_CIRCLE_TEMP+3
;   c = 0.2168*r via MUL #56 /256, stored at >DRAW_CIRCLE_TEMP+4
;   d = 0.0761*r via MUL #19 /256, stored at >DRAW_CIRCLE_TEMP+5
; >DRAW_CIRCLE_TEMP layout: [radius16][a][b][c][d][--][--]
DRAW_CIRCLE_RUNTIME:
; Read ALL parameters into registers/stack BEFORE changing DP (critical!)
; (These are byte variables, use LDB not LDD)
LDB DRAW_CIRCLE_INTENSITY
PSHS B                 ; Save intensity on stack

LDB DRAW_CIRCLE_DIAM
SEX                    ; Sign-extend to 16-bit (radius is the arg, 0..127)
STD >DRAW_CIRCLE_TEMP   ; >DRAW_CIRCLE_TEMP = radius (the 3rd arg IS the radius; was diameter/2)

LDB DRAW_CIRCLE_XC     ; xc (signed -128..127)
SEX
STD >DRAW_CIRCLE_TEMP+2 ; Save xc (16-bit, reused for 'a' after Moveto)

LDB DRAW_CIRCLE_YC     ; yc (signed -128..127)
SEX
STD >DRAW_CIRCLE_TEMP+4 ; Save yc (16-bit, reused for 'c' after Moveto)

; NOW safe to setup BIOS (all params are in >DRAW_CIRCLE_TEMP+stack)
LDA #$D0
TFR A,DP
JSR Reset0Ref
LDA #$80
STA <$04           ; VIA_t1_cnt_lo = $80 (ensure correct scale)

; Set intensity (from stack)
PULS A                 ; Get intensity from stack
CMPA #$5F
BEQ DCR_intensity_5F
JSR Intensity_a
BRA DCR_after_intensity
DCR_intensity_5F:
JSR Intensity_5F
DCR_after_intensity:

; Move to start position: (xc + radius, yc)  [vertex 0 of 16-gon = rightmost]
; radius = >DRAW_CIRCLE_TEMP, xc = >DRAW_CIRCLE_TEMP+2, yc = >DRAW_CIRCLE_TEMP+4
LDD >DRAW_CIRCLE_TEMP   ; D = radius (16-bit)
ADDD >DRAW_CIRCLE_TEMP+2 ; D = xc + radius
TFR B,B                ; Keep X in B (low byte)
PSHS B                 ; Save X on stack
LDD >DRAW_CIRCLE_TEMP+4 ; Load yc
TFR B,A                ; Y to A
PULS B                 ; X to B
JSR Moveto_d

; Precompute 4 delta fractions using MUL (same fractions as constant 16-gon path)
; radius is at >DRAW_CIRCLE_TEMP+1 (low byte, 0..127)
; >DRAW_CIRCLE_TEMP+2..5 now free to reuse for a,b,c,d
; MUL: A * B -> D (unsigned); ADDD #128 then A = round(frac * r) (avoids floor-to-0 for small radii)
LDB >DRAW_CIRCLE_TEMP+1 ; radius
LDA #98                ; 98/256 = 0.3828 ~ sin(22.5 deg) = 0.3827
MUL                    ; D = 98 * r
ADDD #128              ; round before /256
STA >DRAW_CIRCLE_TEMP+2 ; Store a = round(0.3828 * r)
LDB >DRAW_CIRCLE_TEMP+1 ; radius
LDA #83                ; 83/256 = 0.3242 ~ 0.3244
MUL                    ; D = 83 * r
ADDD #128              ; round before /256
STA >DRAW_CIRCLE_TEMP+3 ; Store b
LDB >DRAW_CIRCLE_TEMP+1 ; radius
LDA #56                ; 56/256 = 0.2188 ~ 0.2168
MUL                    ; D = 56 * r
ADDD #128              ; round before /256
STA >DRAW_CIRCLE_TEMP+4 ; Store c
LDB >DRAW_CIRCLE_TEMP+1 ; radius
LDA #19                ; 19/256 = 0.0742 ~ 0.0761
MUL                    ; D = 19 * r
ADDD #128              ; round before /256
STA >DRAW_CIRCLE_TEMP+5 ; Store d

; Draw 16 unrolled segments - 16-gon counterclockwise from (xc+r, yc)
; Draw_Line_d(A=dy, B=dx). Symmetry pattern by quadrant:
;   Q1 (0->90):   (+a,-d), (+b,-c), (+c,-b), (+d,-a)
;   Q2 (90->180): (-d,-a), (-c,-b), (-b,-c), (-a,-d)
;   Q3 (180->270):(-a,+d), (-b,+c), (-c,+b), (-d,+a)
;   Q4 (270->360):(+d,+a), (+c,+b), (+b,+c), (+a,+d)

; --- Q1 ---
; Seg 0: dy=+a, dx=-d
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+2  ; a
LDB >DRAW_CIRCLE_TEMP+5  ; d
NEGB
JSR Draw_Line_d
; Seg 1: dy=+b, dx=-c
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+3  ; b
LDB >DRAW_CIRCLE_TEMP+4  ; c
NEGB
JSR Draw_Line_d
; Seg 2: dy=+c, dx=-b
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+4  ; c
LDB >DRAW_CIRCLE_TEMP+3  ; b
NEGB
JSR Draw_Line_d
; Seg 3: dy=+d, dx=-a
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+5  ; d
LDB >DRAW_CIRCLE_TEMP+2  ; a
NEGB
JSR Draw_Line_d

; --- Q2 ---
; Seg 4: dy=-d, dx=-a
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+5  ; d
NEGA
LDB >DRAW_CIRCLE_TEMP+2  ; a
NEGB
JSR Draw_Line_d
; Seg 5: dy=-c, dx=-b
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+4  ; c
NEGA
LDB >DRAW_CIRCLE_TEMP+3  ; b
NEGB
JSR Draw_Line_d
; Seg 6: dy=-b, dx=-c
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+3  ; b
NEGA
LDB >DRAW_CIRCLE_TEMP+4  ; c
NEGB
JSR Draw_Line_d
; Seg 7: dy=-a, dx=-d
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+2  ; a
NEGA
LDB >DRAW_CIRCLE_TEMP+5  ; d
NEGB
JSR Draw_Line_d

; --- Q3 ---
; Seg 8: dy=-a, dx=+d
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+2  ; a
NEGA
LDB >DRAW_CIRCLE_TEMP+5  ; d (positive)
JSR Draw_Line_d
; Seg 9: dy=-b, dx=+c
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+3  ; b
NEGA
LDB >DRAW_CIRCLE_TEMP+4  ; c (positive)
JSR Draw_Line_d
; Seg 10: dy=-c, dx=+b
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+4  ; c
NEGA
LDB >DRAW_CIRCLE_TEMP+3  ; b (positive)
JSR Draw_Line_d
; Seg 11: dy=-d, dx=+a
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+5  ; d
NEGA
LDB >DRAW_CIRCLE_TEMP+2  ; a (positive)
JSR Draw_Line_d

; --- Q4 ---
; Seg 12: dy=+d, dx=+a
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+5  ; d (positive)
LDB >DRAW_CIRCLE_TEMP+2  ; a (positive)
JSR Draw_Line_d
; Seg 13: dy=+c, dx=+b
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+4  ; c (positive)
LDB >DRAW_CIRCLE_TEMP+3  ; b (positive)
JSR Draw_Line_d
; Seg 14: dy=+b, dx=+c
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+3  ; b (positive)
LDB >DRAW_CIRCLE_TEMP+4  ; c (positive)
JSR Draw_Line_d
; Seg 15: dy=+a, dx=+d
CLR Vec_Misc_Count
LDA >DRAW_CIRCLE_TEMP+2  ; a (positive)
LDB >DRAW_CIRCLE_TEMP+5  ; d (positive)
JSR Draw_Line_d

LDA #$C8
TFR A,DP           ; Restore DP=$C8 before return
RTS

;**** PRINT_TEXT String Data ****
PRINT_TEXT_STR_2058:
    FCC "A+"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2691:
    FCC "U8"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_71726:
    FCC "I16"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_71921:
    FCC "I8 "
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_72349:
    FCC "IDX"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_83258:
    FCC "U16"
    FCB $80          ; Vectrex string terminator

