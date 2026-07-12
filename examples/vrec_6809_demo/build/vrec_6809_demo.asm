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
    FCC "VREC DEMO"
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
DRAW_VEC_INTENSITY   EQU $C880+$0E   ; Vector intensity override (0=use vector data) (1 bytes)
DRAW_REC_PTR         EQU $C880+$0F   ; DRAW_RECORDING: _<NAME>_VREC header base (2 bytes)
DRAW_REC_FRAME       EQU $C880+$11   ; DRAW_RECORDING: caller frame counter (i16, non-negative) (2 bytes)
DRAW_REC_X           EQU $C880+$13   ; DRAW_RECORDING: center X (i8) (1 bytes)
DRAW_REC_Y           EQU $C880+$14   ; DRAW_RECORDING: center Y (i8) (1 bytes)
DRAW_REC_SCALE       EQU $C880+$15   ; DRAW_RECORDING: scale 0-128 (128=100%) (1 bytes)
DRAW_REC_SEGCNT      EQU $C880+$16   ; DRAW_RECORDING: remaining segment count (2 bytes)
DRAW_REC_SEGPTR      EQU $C880+$18   ; DRAW_RECORDING: current segment pointer (survives BIOS calls) (2 bytes)
DRAW_REC_SX0         EQU $C880+$1A   ; DRAW_RECORDING: scaled+centered x0 (i8) (1 bytes)
DRAW_REC_SY0         EQU $C880+$1B   ; DRAW_RECORDING: scaled+centered y0 (i8) (1 bytes)
DRAW_REC_SX1         EQU $C880+$1C   ; DRAW_RECORDING: scaled+centered x1 (i8) (1 bytes)
DRAW_REC_SY1         EQU $C880+$1D   ; DRAW_RECORDING: scaled+centered y1 (i8) (1 bytes)
DRAW_REC_I           EQU $C880+$1E   ; DRAW_RECORDING: per-segment intensity (u8) (1 bytes)
DRAW_REC_TMP16       EQU $C880+$1F   ; DRAW_RECORDING: 16-bit scratch for clamped coord/delta math (2 bytes)
DRAW_LINE_ARGS       EQU $C880+$21   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$2B   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$2D   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$2F   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$30   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$31   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$33   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
VAR_ARG0             EQU $C880+$35   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $C880+$37   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $C880+$39   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $C880+$3B   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $C880+$3D   ; Function argument 4 (16-bit) (2 bytes)
VAR_ARG5             EQU $C880+$3F   ; Function argument 5 (16-bit) (2 bytes)
VAR_ARG6             EQU $C880+$41   ; Function argument 6 (16-bit) (2 bytes)
VAR_ARG7             EQU $C880+$43   ; Function argument 7 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $C880+$45   ; Current ROM bank ID (multibank tracking) (1 bytes)
VAR_FRAME            EQU $C880+$46   ; User variable: FRAME (2 bytes)
VAR_TICK             EQU $C880+$48   ; User variable: TICK (2 bytes)

;***************************************************************************
; MAIN PROGRAM
;***************************************************************************

MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    LDD #0
    STD VAR_FRAME
    LDD #0
    STD VAR_TICK
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
; VPy_LINE:22
    ; TODO: Statement Pass { source_line: 22 }
    CLR >$C811  ; Force-clear Vec_Buttons before first loop() frame

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
; VPy_LINE:26
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_TICK
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_TICK
; VPy_LINE:27
    LDD #3
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_TICK
    CMPD TMPVAL
    LBGE .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_1
; VPy_LINE:28
    LDD #0
    STD VAR_TICK
; VPy_LINE:29
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FRAME
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_FRAME
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
; VPy_LINE:31
; NATIVE_CALL: DRAW_RECORDING at line 31
    ; DRAW_RECORDING("spin", x, y, scale, frame)
    LDD #0
    TFR B,A          ; X center (low byte)
    STA >DRAW_REC_X
    LDD #0
    TFR B,A          ; Y center (low byte)
    STA >DRAW_REC_Y
    LDD #128
    TFR B,A          ; scale (low byte)
    STA >DRAW_REC_SCALE
    LDD >VAR_FRAME
    STD >DRAW_REC_FRAME
    LDX #_SPIN_VREC      ; recording header
    JSR DRAW_RECORDING_RUNTIME
    LDD #0
    STD RESULT
    RTS

;***************************************************************************
; EMBEDDED ASSETS (vectors, music, levels, SFX)
;***************************************************************************

; --- spin RECORDING (12 frame(s), fps=15) ---
_SPIN_VREC:
    FDB 12    ; frame_count
    FDB _SPIN_VREC_F0    ; frame 0 pointer
    FDB _SPIN_VREC_F1    ; frame 1 pointer
    FDB _SPIN_VREC_F2    ; frame 2 pointer
    FDB _SPIN_VREC_F3    ; frame 3 pointer
    FDB _SPIN_VREC_F4    ; frame 4 pointer
    FDB _SPIN_VREC_F5    ; frame 5 pointer
    FDB _SPIN_VREC_F6    ; frame 6 pointer
    FDB _SPIN_VREC_F7    ; frame 7 pointer
    FDB _SPIN_VREC_F8    ; frame 8 pointer
    FDB _SPIN_VREC_F9    ; frame 9 pointer
    FDB _SPIN_VREC_F10    ; frame 10 pointer
    FDB _SPIN_VREC_F11    ; frame 11 pointer
_SPIN_VREC_F0:
    FDB 4    ; segment_count
    FCB $31,$31,$CF,$31,$5F    ; (49,49)->(-49,49) i=95
    FCB $CF,$31,$CF,$CF,$5F    ; (-49,49)->(-49,-49) i=95
    FCB $CF,$CF,$31,$CF,$5F    ; (-49,-49)->(49,-49) i=95
    FCB $31,$CF,$31,$31,$5F    ; (49,-49)->(49,49) i=95
_SPIN_VREC_F1:
    FDB 4    ; segment_count
    FCB $2B,$38,$C8,$2B,$5F    ; (43,56)->(-56,43) i=95
    FCB $C8,$2B,$D5,$C8,$5F    ; (-56,43)->(-43,-56) i=95
    FCB $D5,$C8,$38,$D5,$5F    ; (-43,-56)->(56,-43) i=95
    FCB $38,$D5,$2B,$38,$5F    ; (56,-43)->(43,56) i=95
_SPIN_VREC_F2:
    FDB 4    ; segment_count
    FCB $23,$3D,$C3,$23,$5F    ; (35,61)->(-61,35) i=95
    FCB $C3,$23,$DD,$C3,$5F    ; (-61,35)->(-35,-61) i=95
    FCB $DD,$C3,$3D,$DD,$5F    ; (-35,-61)->(61,-35) i=95
    FCB $3D,$DD,$23,$3D,$5F    ; (61,-35)->(35,61) i=95
_SPIN_VREC_F3:
    FDB 4    ; segment_count
    FCB $1B,$41,$BF,$1B,$5F    ; (27,65)->(-65,27) i=95
    FCB $BF,$1B,$E5,$BF,$5F    ; (-65,27)->(-27,-65) i=95
    FCB $E5,$BF,$41,$E5,$5F    ; (-27,-65)->(65,-27) i=95
    FCB $41,$E5,$1B,$41,$5F    ; (65,-27)->(27,65) i=95
_SPIN_VREC_F4:
    FDB 4    ; segment_count
    FCB $12,$44,$BC,$12,$5F    ; (18,68)->(-68,18) i=95
    FCB $BC,$12,$EE,$BC,$5F    ; (-68,18)->(-18,-68) i=95
    FCB $EE,$BC,$44,$EE,$5F    ; (-18,-68)->(68,-18) i=95
    FCB $44,$EE,$12,$44,$5F    ; (68,-18)->(18,68) i=95
_SPIN_VREC_F5:
    FDB 4    ; segment_count
    FCB $09,$45,$BB,$09,$5F    ; (9,69)->(-69,9) i=95
    FCB $BB,$09,$F7,$BB,$5F    ; (-69,9)->(-9,-69) i=95
    FCB $F7,$BB,$45,$F7,$5F    ; (-9,-69)->(69,-9) i=95
    FCB $45,$F7,$09,$45,$5F    ; (69,-9)->(9,69) i=95
_SPIN_VREC_F6:
    FDB 4    ; segment_count
    FCB $00,$46,$BA,$00,$5F    ; (0,70)->(-70,0) i=95
    FCB $BA,$00,$00,$BA,$5F    ; (-70,0)->(0,-70) i=95
    FCB $00,$BA,$46,$00,$5F    ; (0,-70)->(70,0) i=95
    FCB $46,$00,$00,$46,$5F    ; (70,0)->(0,70) i=95
_SPIN_VREC_F7:
    FDB 4    ; segment_count
    FCB $F7,$45,$BB,$F7,$5F    ; (-9,69)->(-69,-9) i=95
    FCB $BB,$F7,$09,$BB,$5F    ; (-69,-9)->(9,-69) i=95
    FCB $09,$BB,$45,$09,$5F    ; (9,-69)->(69,9) i=95
    FCB $45,$09,$F7,$45,$5F    ; (69,9)->(-9,69) i=95
_SPIN_VREC_F8:
    FDB 4    ; segment_count
    FCB $EE,$44,$BC,$EE,$5F    ; (-18,68)->(-68,-18) i=95
    FCB $BC,$EE,$12,$BC,$5F    ; (-68,-18)->(18,-68) i=95
    FCB $12,$BC,$44,$12,$5F    ; (18,-68)->(68,18) i=95
    FCB $44,$12,$EE,$44,$5F    ; (68,18)->(-18,68) i=95
_SPIN_VREC_F9:
    FDB 4    ; segment_count
    FCB $E5,$41,$BF,$E5,$5F    ; (-27,65)->(-65,-27) i=95
    FCB $BF,$E5,$1B,$BF,$5F    ; (-65,-27)->(27,-65) i=95
    FCB $1B,$BF,$41,$1B,$5F    ; (27,-65)->(65,27) i=95
    FCB $41,$1B,$E5,$41,$5F    ; (65,27)->(-27,65) i=95
_SPIN_VREC_F10:
    FDB 4    ; segment_count
    FCB $DD,$3D,$C3,$DD,$5F    ; (-35,61)->(-61,-35) i=95
    FCB $C3,$DD,$23,$C3,$5F    ; (-61,-35)->(35,-61) i=95
    FCB $23,$C3,$3D,$23,$5F    ; (35,-61)->(61,35) i=95
    FCB $3D,$23,$DD,$3D,$5F    ; (61,35)->(-35,61) i=95
_SPIN_VREC_F11:
    FDB 4    ; segment_count
    FCB $D5,$38,$C8,$D5,$5F    ; (-43,56)->(-56,-43) i=95
    FCB $C8,$D5,$2B,$C8,$5F    ; (-56,-43)->(43,-56) i=95
    FCB $2B,$C8,$38,$2B,$5F    ; (43,-56)->(56,43) i=95
    FCB $38,$2B,$D5,$38,$5F    ; (56,43)->(-43,56) i=95

;***************************************************************************
; RUNTIME HELPERS
;***************************************************************************

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

; ============================================================================
; DRAW_RECORDING_RUNTIME  (.vrec vector-movie player — single-bank, video-only)
; ============================================================================
DRAW_RECORDING_RUNTIME:
PSHS D,X,Y,U
STX >DRAW_REC_PTR      ; save header base (survives MOD16 / BIOS clobber)
LDD ,X                 ; D = frame_count (FDB, big-endian)
LBEQ DREC_DONE         ; empty recording: nothing to draw
; --- frame_idx = frame % frame_count ---
LDX >DRAW_REC_FRAME    ; X = frame counter (MOD16 dividend)
JSR MOD16              ; D = frame % frame_count (0..frame_count-1)
; --- frame_ptr = offset_table[frame_idx]  (table starts at base+2) ---
LSLB
ROLA                   ; D = frame_idx * 2 (FDB entries)
LDX >DRAW_REC_PTR
LEAX 2,X               ; X = &offset_table[0] (skip frame_count word)
LEAX D,X               ; X = &offset_table[frame_idx]
LDX ,X                 ; X = frame data pointer (absolute)
LDD ,X                 ; D = segment_count
LBEQ DREC_DONE         ; empty frame
STD >DRAW_REC_SEGCNT
LEAX 2,X               ; X = first segment
STX >DRAW_REC_SEGPTR
DREC_SEG_LOOP:
; --- compute scaled+centered endpoints (DP=$C8), clamped to i8 ---
LDX >DRAW_REC_SEGPTR
LDA ,X                 ; x0 (i8)
LDB >DRAW_REC_X        ; center X (i8)
JSR DREC_COORD         ; B = clamp_i8((x0*scale>>7) + centerX)
STB >DRAW_REC_SX0
LDX >DRAW_REC_SEGPTR
LDA 1,X                ; y0
LDB >DRAW_REC_Y
JSR DREC_COORD
STB >DRAW_REC_SY0
LDX >DRAW_REC_SEGPTR
LDA 2,X                ; x1
LDB >DRAW_REC_X
JSR DREC_COORD
STB >DRAW_REC_SX1
LDX >DRAW_REC_SEGPTR
LDA 3,X                ; y1
LDB >DRAW_REC_Y
JSR DREC_COORD
STB >DRAW_REC_SY1
; --- intensity: SET_INTENSITY override (DRAW_VEC_INTENSITY) wins if nonzero ---
LDA >DRAW_VEC_INTENSITY
BNE DREC_HAVE_I
LDX >DRAW_REC_SEGPTR
LDA 4,X                ; recorded intensity
DREC_HAVE_I:
STA >DRAW_REC_I
; --- dx = clamp(x1-x0), dy = clamp(y1-y0) (i8 for Draw_Line_d deltas) ---
LDA >DRAW_REC_SY1
LDB >DRAW_REC_SY0
JSR DREC_DIFF          ; B = clamp_i8(y1 - y0)
STB >DRAW_REC_SY1      ; reuse as dy
LDA >DRAW_REC_SX1
LDB >DRAW_REC_SX0
JSR DREC_DIFF          ; B = clamp_i8(x1 - x0)
STB >DRAW_REC_SX1      ; reuse as dx
; --- draw one absolute line via BIOS (DP=$D0) ---
LDA #$D0
TFR A,DP               ; DP=$D0 for VIA/BIOS access
JSR Reset0Ref          ; beam does NOT auto-reset between segments
LDA #$80
STA <$04               ; ACR: SR shift-out (beam control)
LDA >DRAW_REC_I
JSR Intensity_a
LDA >DRAW_REC_SY0      ; A = Y0 (Moveto_d absolute: A=Y, B=X)
LDB >DRAW_REC_SX0
JSR Moveto_d
LDA >DRAW_REC_SY1      ; A = dy
LDB >DRAW_REC_SX1      ; B = dx
CLR Vec_Misc_Count
JSR Draw_Line_d
LDA #$C8
TFR A,DP               ; back to DP=$C8 for RAM/table reads
; --- advance to next segment (5 bytes) ---
LDX >DRAW_REC_SEGPTR
LEAX 5,X
STX >DRAW_REC_SEGPTR
LDD >DRAW_REC_SEGCNT
SUBD #1
STD >DRAW_REC_SEGCNT
LBNE DREC_SEG_LOOP
DREC_DONE:
LDA #$C8
TFR A,DP               ; ensure DP restored on all exit paths
PULS D,X,Y,U
RTS
; DREC_COORD: A = raw coord (i8), B = center (i8)
;   -> B = clamp_i8((coord*scale>>7) + center). Clobbers A,D,X. DP must be $C8.
DREC_COORD:
PSHS B                 ; save center (i8)
JSR DREC_SCALE         ; D = (coord*scale)>>7 as i16 (already in [-128,127])
STD >DRAW_REC_TMP16
LDB ,S                 ; B = center byte
SEX                    ; D = sign-extended center (i16)
ADDD >DRAW_REC_TMP16   ; D = scaled + center (i16)
JSR DREC_CLAMP8        ; D clamped to [-127,127]; low byte in B
LEAS 1,S               ; drop saved center
RTS
; DREC_DIFF: A = minuend (i8), B = subtrahend (i8)
;   -> B = clamp_i8(minuend - subtrahend). Clobbers A,D. DP must be $C8.
DREC_DIFF:
PSHS A                 ; save minuend (i8)
SEX                    ; D = sign-extended subtrahend (from B)
STD >DRAW_REC_TMP16
LDB ,S                 ; B = minuend byte
SEX                    ; D = sign-extended minuend (i16)
SUBD >DRAW_REC_TMP16   ; D = minuend - subtrahend (i16)
JSR DREC_CLAMP8        ; D clamped; low byte in B
LEAS 1,S               ; drop saved minuend
RTS
; DREC_CLAMP8: D (i16) -> D clamped to [-127,127] (signed). Low byte usable as i8.
DREC_CLAMP8:
CMPD #127
BLE DREC_CLAMP8_LO
LDD #127
DREC_CLAMP8_LO:
CMPD #-127
BGE DREC_CLAMP8_OK
LDD #-127
DREC_CLAMP8_OK:
RTS
; DREC_SCALE: A = raw coord (i8) -> D = (coord*scale)>>7 as i16 (in [-128,127])
;   scale from DRAW_REC_SCALE (0-128). Clobbers X. DP must be $C8.
DREC_SCALE:
TFR A,B
SEX                    ; D = sign-extended coord (i16)
TFR D,X                ; X = coord (MUL16 operand)
LDB >DRAW_REC_SCALE
CLRA                   ; D = scale (0-128, positive)
JSR MUL16              ; D = coord*scale (signed, fits 16-bit)
ASRA
RORB                   ; >>1 (arithmetic, sign into A)
ASRA
RORB                   ; >>2
ASRA
RORB                   ; >>3
ASRA
RORB                   ; >>4
ASRA
RORB                   ; >>5
ASRA
RORB                   ; >>6
ASRA
RORB                   ; >>7  (D now holds scaled coord, sign-extended in A)
RTS

;**** PRINT_TEXT String Data ****
PRINT_TEXT_STR_3536962:
    FCC "spin"
    FCB $80          ; Vectrex string terminator

