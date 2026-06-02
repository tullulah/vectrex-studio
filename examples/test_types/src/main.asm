; --- Motorola 6809 backend (Vectrex) title='UNTITLED' origin=$0000 ---
        ORG $0000
;***************************************************************************
; DEFINE SECTION
;***************************************************************************
    INCLUDE "VECTREX.I"

;***************************************************************************
; HEADER SECTION
;***************************************************************************
    FCC "g GCE 1982"
    FCB $80
    FDB music1
    FCB $F8
    FCB $50
    FCB $20
    FCB $BB
    FCC "UNTITLED"
    FCB $80
    FCB 0

;***************************************************************************
; CODE SECTION
;***************************************************************************

; === RAM VARIABLE DEFINITIONS (EQU) ===
; AUTO-GENERATED - All offsets calculated automatically
; Total RAM used: 97 bytes
RESULT               EQU $C880+$00   ; Main result temporary (2 bytes)
TMPLEFT              EQU $C880+$02   ; Left operand temp (2 bytes)
TMPLEFT2             EQU $C880+$04   ; Left operand temp 2 (for nested operations) (2 bytes)
TMPRIGHT             EQU $C880+$06   ; Right operand temp (2 bytes)
TMPRIGHT2            EQU $C880+$08   ; Right operand temp 2 (for nested operations) (2 bytes)
TMPPTR               EQU $C880+$0A   ; Pointer temp (used by DRAW_VECTOR, arrays, structs) (2 bytes)
TMPPTR2              EQU $C880+$0C   ; Pointer temp 2 (for nested array operations) (2 bytes)
TEMP_YX              EQU $C880+$0E   ; Temporary y,x storage (2 bytes)
TEMP_X               EQU $C880+$10   ; Temporary x storage (1 bytes)
TEMP_Y               EQU $C880+$11   ; Temporary y storage (1 bytes)
VPY_MOVE_X           EQU $C880+$12   ; MOVE() current X offset (signed byte, 0 by default) (1 bytes)
VPY_MOVE_Y           EQU $C880+$13   ; MOVE() current Y offset (signed byte, 0 by default) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$14   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity as i16x5) (10 bytes)
NUM_STR              EQU $C880+$1E   ; String buffer for PRINT_NUMBER (5 digits + terminator) (6 bytes)
TEXT_SCALE_H         EQU $C880+$24   ; Character height for Print_Str_d (default $F8=-8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$25   ; Character width for Print_Str_d (default $48=72, normal) (1 bytes)
VLINE_DX_16          EQU $C880+$26   ; x1-x0 (16-bit) for line drawing (2 bytes)
VLINE_DY_16          EQU $C880+$28   ; y1-y0 (16-bit) for line drawing (2 bytes)
VLINE_DX             EQU $C880+$2A   ; Clamped dx (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$2B   ; Clamped dy (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$2C   ; Remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$2E   ; Remaining dx for segment 2 (16-bit) (2 bytes)
VLINE_STEPS          EQU $C880+$30   ; Line drawing step counter (1 bytes)
VLINE_LIST           EQU $C880+$31   ; 2-byte vector list (Y|endbit, X) (2 bytes)
DRAW_CIRCLE_XC       EQU $C880+$33   ; Circle center X (byte) (1 bytes)
DRAW_CIRCLE_YC       EQU $C880+$34   ; Circle center Y (byte) (1 bytes)
DRAW_CIRCLE_DIAM     EQU $C880+$35   ; Circle diameter (byte) (1 bytes)
DRAW_CIRCLE_INTENSITY EQU $C880+$36   ; Circle intensity (byte) (1 bytes)
DRAW_CIRCLE_TEMP     EQU $C880+$37   ; Circle drawing temporaries (radius=2, xc=2, yc=2, spare=2) (8 bytes)
VAR_COUNTER          EQU $C880+$3F   ; User variable (2 bytes)
VAR_STATE            EQU $C880+$41   ; User variable (2 bytes)
VAR_SHAPE_TYPE       EQU $C880+$43   ; User variable (2 bytes)
VAR_DIRECTION_X      EQU $C880+$45   ; User variable (2 bytes)
VAR_DIRECTION_Y      EQU $C880+$47   ; User variable (2 bytes)
VAR_POS_X            EQU $C880+$49   ; User variable (2 bytes)
VAR_POS_Y            EQU $C880+$4B   ; User variable (2 bytes)
VAR_JOY_X            EQU $C880+$4D   ; User variable (2 bytes)
VAR_BASE_INTENSITY   EQU $C880+$4F   ; User variable (2 bytes)
VAR_MAX_X            EQU $C880+$51   ; User variable (2 bytes)
VAR_MIN_X            EQU $C880+$53   ; User variable (2 bytes)
VAR_ARG0             EQU $C880+$55   ; Function argument 0 (2 bytes)
VAR_ARG1             EQU $C880+$57   ; Function argument 1 (2 bytes)
VAR_ARG2             EQU $C880+$59   ; Function argument 2 (2 bytes)
VAR_ARG3             EQU $C880+$5B   ; Function argument 3 (2 bytes)
VAR_ARG4             EQU $C880+$5D   ; Function argument 4 (2 bytes)
VAR_ARG5             EQU $C880+$5F   ; Function argument 5 (2 bytes)

    JMP START

;**** CONST DECLARATIONS (NUMBER-ONLY) ****
; VPy_LINE:19
; _CONST_DECL_0:  ; const BASE_INTENSITY
; VPy_LINE:20
; _CONST_DECL_1:  ; const MAX_X
; VPy_LINE:21
; _CONST_DECL_2:  ; const MIN_X

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

; J1_Y() - Read Joystick 1 Y axis (INCREMENTAL - with state preservation)
; Returns: D = raw value from $C81C after Joy_Analog call
J1Y_BUILTIN:
    PSHS X       ; Save X (Joy_Analog uses it)
    JSR $F1AA    ; DP_to_D0 (required for Joy_Analog BIOS call)
    JSR $F1F5    ; Joy_Analog (updates $C81C from hardware)
    JSR Reset0Ref ; Full beam reset: zeros DAC (VIA_port_a=0) via Reset_Pen + grounds integrators
    JSR $F1AF    ; DP_to_C8 (required to read RAM $C81C)
    LDB $C81C    ; Vec_Joy_1_Y (BIOS writes ~$FE at center)
    SEX          ; Sign-extend B to D
    ADDD #2      ; Calibrate center offset
    PULS X       ; Restore X
    RTS

; === BUTTON SYSTEM - BIOS TRANSITIONS ===
; J1_BUTTON_1-4() - Read transition bits from $C811
; Read_Btns (auto-injected) calculates: ~(new) OR Vec_Prev_Btns
; Result: bit=1 ONLY on rising edge (0→1 transition)
; Returns: D = 1 (just pressed), 0 (not pressed or still held)

J1B1_BUILTIN:
    LDA $C811      ; Read transition bits (Vec_Button_1_1)
    ANDA #$01      ; Test bit 0 (Button 1)
    BEQ .J1B1_OFF
    LDD #1         ; Return pressed (rising edge)
    RTS
.J1B1_OFF:
    LDD #0         ; Return not pressed
    RTS

J1B2_BUILTIN:
    LDA $C811
    ANDA #$02      ; Test bit 1 (Button 2)
    BEQ .J1B2_OFF
    LDD #1
    RTS
.J1B2_OFF:
    LDD #0
    RTS

J1B3_BUILTIN:
    LDA $C811
    ANDA #$04      ; Test bit 2 (Button 3)
    BEQ .J1B3_OFF
    LDD #1
    RTS
.J1B3_OFF:
    LDD #0
    RTS

J1B4_BUILTIN:
    LDA $C811
    ANDA #$08      ; Test bit 3 (Button 4)
    BEQ .J1B4_OFF
    LDD #1
    RTS
.J1B4_OFF:
    LDD #0
    RTS

VECTREX_PRINT_TEXT:
    ; Print_Str_d requires DP=$D0 and signature is (Y, X, string)
    ; VPy signature: PRINT_TEXT(x, y, string) -> args (ARG0=x, ARG1=y, ARG2=string)
    ; BIOS signature: Print_Str_d(A=Y, B=X, U=string)
    LDA #$D0
    TFR A,DP       ; Set Direct Page to $D0 for BIOS
    JSR Intensity_5F ; Ensure consistent text brightness (DP=$D0 required)
    JSR Reset0Ref  ; Reset beam to center for absolute text positioning
    LDU VAR_ARG2   ; string pointer (ARG2 = third param)
    LDA >TEXT_SCALE_H ; height (signed byte, -n)
    STA >$C82A     ; Vec_Text_Height: character Y scale
    LDA >TEXT_SCALE_W ; width (unsigned byte, n*9)
    STA >$C82B     ; Vec_Text_Width: character X spacing
    LDA VAR_ARG1+1 ; Y (ARG1 = second param)
    LDB VAR_ARG0+1 ; X (ARG0 = first param)
    JSR Print_Str_d
    LDA #$F8
    STA >$C82A     ; Restore Vec_Text_Height to normal (-8)
    LDA #$48
    STA >$C82B     ; Restore Vec_Text_Width to normal (72)
    JSR $F1AF      ; DP_to_C8 (restore before return)
    RTS
VECTREX_PRINT_NUMBER:
    ; Print signed decimal number (-9999 to 9999)
    ; ARG0=X, ARG1=Y, ARG2=value
    ; STEP 1: Convert number to decimal string (DP=$C8)
    LDD >VAR_ARG2   ; Load 16-bit value (safe: DP=$C8)
    STD >RESULT      ; Save to temp
    LDX #NUM_STR    ; String buffer pointer
    ; Check sign: negative values get '-' prefix and are negated
    CMPD #0
    BPL .PN_DIV1000  ; D >= 0: go directly to digit conversion
    LDA #'-'
    STA ,X+          ; Store '-', advance buffer pointer
    LDD >RESULT
    COMA
    COMB
    ADDD #1          ; Two's complement negation -> absolute value
    STD >RESULT
    ; --- 1000s digit ---
.PN_DIV1000:
    CLR ,X           ; Counter = 0 (in buffer)
.PN_L1000:
    LDD >RESULT
    SUBD #1000
    BMI .PN_D1000
    STD >RESULT
    INC ,X
    BRA .PN_L1000
.PN_D1000:
    LDA ,X
    ADDA #'0'
    STA ,X+
    ; --- 100s digit ---
    CLR ,X
.PN_L100:
    LDD >RESULT
    SUBD #100
    BMI .PN_D100
    STD >RESULT
    INC ,X
    BRA .PN_L100
.PN_D100:
    LDA ,X
    ADDA #'0'
    STA ,X+
    ; --- 10s digit ---
    CLR ,X
.PN_L10:
    LDD >RESULT
    SUBD #10
    BMI .PN_D10
    STD >RESULT
    INC ,X
    BRA .PN_L10
.PN_D10:
    LDA ,X
    ADDA #'0'
    STA ,X+
    ; --- 1s digit (remainder) ---
    LDD >RESULT
    ADDB #'0'
    STB ,X+
    LDA #$80          ; Terminator (same format as FCC/FCB strings)
    STA ,X
.PN_AFTER_CONVERT:
    ; STEP 2: Set up BIOS and print (NOW change DP to $D0)
    LDA #$D0
    TFR A,DP         ; Set Direct Page to $D0 for BIOS
    JSR Reset0Ref    ; Reset beam to center for absolute text positioning
    LDU #NUM_STR     ; String pointer
    LDA >TEXT_SCALE_H ; height (signed byte, -n)
    STA >$C82A       ; Vec_Text_Height: character Y scale
    LDA >TEXT_SCALE_W ; width (unsigned byte, n*9)
    STA >$C82B       ; Vec_Text_Width: character X spacing
    LDA >VAR_ARG1+1  ; Y coordinate
    LDB >VAR_ARG0+1  ; X coordinate
    JSR Print_Str_d  ; Print using BIOS (A=Y, B=X, U=string)
    LDA #$F8
    STA >$C82A       ; Restore Vec_Text_Height to normal (-8)
    LDA #$48
    STA >$C82B       ; Restore Vec_Text_Width to normal (72)
    JSR $F1AF        ; DP_to_C8 - restore DP
    RTS
; DRAW_LINE unified wrapper - handles 16-bit signed coordinates
; Args in DRAW_LINE_ARGS[0..9]: x0,y0,x1,y1,intensity (5x i16, low byte used for coords)
; Resets beam to center, moves to (x0,y0), draws to (x1,y1)
DRAW_LINE_WRAPPER:
    ; Set DP to hardware registers
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref   ; Reset beam to center (0,0) before positioning
    LDA #$80
    STA <$04        ; VIA_t1_cnt_lo = $80 (ensure correct scale regardless of prior builtins)
    ; Set intensity
    LDA >DRAW_LINE_ARGS+9  ; intensity (low byte)
    JSR Intensity_a
    ; Move to start position (y in A, x in B)
    LDA >DRAW_LINE_ARGS+3  ; Y start (low byte)
    ADDA >VPY_MOVE_Y       ; Add MOVE Y offset
    LDB >DRAW_LINE_ARGS+1  ; X start (low byte)
    ADDB >VPY_MOVE_X       ; Add MOVE X offset
    JSR Moveto_d
    ; Compute deltas using 16-bit arithmetic
    ; dx = x1 - x0 (treating as signed 16-bit)
    LDD >DRAW_LINE_ARGS+4  ; x1 (16-bit)
    SUBD >DRAW_LINE_ARGS+0 ; subtract x0 (16-bit)
    STD VLINE_DX_16        ; Store full 16-bit dx
    ; dy = y1 - y0 (treating as signed 16-bit)
    LDD >DRAW_LINE_ARGS+6  ; y1 (16-bit)
    SUBD >DRAW_LINE_ARGS+2 ; subtract y0 (16-bit)
    STD VLINE_DY_16        ; Store full 16-bit dy
    ; SEGMENT 1: Clamp dy to ±127 and draw
    LDD VLINE_DY_16 ; Load full dy
    CMPD #127
    BLE DLW_SEG1_DY_LO
    LDA #127        ; dy > 127: use 127
    BRA DLW_SEG1_DY_READY
DLW_SEG1_DY_LO:
    CMPD #-128
    BGE DLW_SEG1_DY_NO_CLAMP  ; -128 <= dy <= 127: use original (sign-extended)
    LDA #$80        ; dy < -128: use -128
    BRA DLW_SEG1_DY_READY
DLW_SEG1_DY_NO_CLAMP:
    LDA VLINE_DY_16+1  ; Use original low byte (already in valid range)
DLW_SEG1_DY_READY:
    STA VLINE_DY    ; Save clamped dy for segment 1
    ; Clamp dx to ±127
    LDD VLINE_DX_16
    CMPD #127
    BLE DLW_SEG1_DX_LO
    LDB #127        ; dx > 127: use 127
    BRA DLW_SEG1_DX_READY
DLW_SEG1_DX_LO:
    CMPD #-128
    BGE DLW_SEG1_DX_NO_CLAMP  ; -128 <= dx <= 127: use original (sign-extended)
    LDB #$80        ; dx < -128: use -128
    BRA DLW_SEG1_DX_READY
DLW_SEG1_DX_NO_CLAMP:
    LDB VLINE_DX_16+1  ; Use original low byte (already in valid range)
DLW_SEG1_DX_READY:
    STB VLINE_DX    ; Save clamped dx for segment 1
    ; Draw segment 1
    CLR Vec_Misc_Count
    LDA VLINE_DY
    LDB VLINE_DX
    JSR Draw_Line_d ; Beam moves automatically
    ; Check if we need SEGMENT 2 (dy OR dx outside ±127 range)
    LDD VLINE_DY_16 ; Reload original dy
    CMPD #127
    BGT DLW_NEED_SEG2  ; dy > 127: needs segment 2
    CMPD #-128
    BLT DLW_NEED_SEG2  ; dy < -128: needs segment 2
    LDD VLINE_DX_16 ; Also check dx
    CMPD #127
    BGT DLW_NEED_SEG2  ; dx > 127: needs segment 2
    CMPD #-128
    BLT DLW_NEED_SEG2  ; dx < -128: needs segment 2
    BRA DLW_DONE       ; both dy and dx in range: no segment 2
DLW_NEED_SEG2:
    ; SEGMENT 2: Draw remaining dy and dx
    ; Calculate remaining dy
    LDD VLINE_DY_16 ; Load original full dy
    CMPD #127
    BGT DLW_SEG2_DY_POS  ; dy > 127: remaining = dy - 127
    CMPD #-128
    BGE DLW_SEG2_DY_NO_REMAIN  ; -128 <= dy <= 127: no remaining dy
    ; dy < -128, so we drew -128 in segment 1
    ; remaining = dy - (-128) = dy + 128
    ADDD #128       ; Add back the -128 we already drew
    BRA DLW_SEG2_DY_DONE
DLW_SEG2_DY_NO_REMAIN:
    LDD #0          ; dy in range: no remaining
    BRA DLW_SEG2_DY_DONE
DLW_SEG2_DY_POS:
    ; dy > 127, so we drew 127 in segment 1
    ; remaining = dy - 127
    SUBD #127       ; Subtract 127 we already drew
DLW_SEG2_DY_DONE:
    STD VLINE_DY_REMAINING  ; Store remaining dy (16-bit)
    ; Calculate remaining dx
    LDD VLINE_DX_16 ; Load original full dx
    CMPD #127
    BLE DLW_SEG2_DX_CHECK_NEG
    ; dx > 127, so we drew 127 in segment 1
    ; remaining = dx - 127
    SUBD #127
    BRA DLW_SEG2_DX_DONE
DLW_SEG2_DX_CHECK_NEG:
    CMPD #-128
    BGE DLW_SEG2_DX_NO_REMAIN  ; -128 <= dx <= 127: no remaining dx
    ; dx < -128, so we drew -128 in segment 1
    ; remaining = dx - (-128) = dx + 128
    ADDD #128
    BRA DLW_SEG2_DX_DONE
DLW_SEG2_DX_NO_REMAIN:
    LDD #0          ; No remaining dx
DLW_SEG2_DX_DONE:
    STD VLINE_DX_REMAINING  ; Store remaining dx (16-bit) in VLINE_DX_REMAINING
    ; Setup for Draw_Line_d: A=dy, B=dx (CRITICAL: order matters!)
    ; Load remaining dy from VLINE_DY_REMAINING (already saved)
    LDA VLINE_DY_REMAINING+1  ; Low byte of remaining dy
    LDB VLINE_DX_REMAINING+1  ; Low byte of remaining dx
    CLR Vec_Misc_Count
    JSR Draw_Line_d ; Beam continues from segment 1 endpoint
DLW_DONE:
    LDA #$C8       ; CRITICAL: Restore DP to $C8 for our code
    TFR A,DP
    RTS
VECTREX_SET_INTENSITY:
    ; CRITICAL: Set VIA to DAC mode BEFORE calling BIOS (don't assume state)
    LDA #$98       ; VIA_cntl = $98 (DAC mode)
    STA >$D00C     ; VIA_cntl
    LDA #$D0
    TFR A,DP       ; Set Direct Page to $D0 for BIOS
    LDA VAR_ARG0+1
    JSR __Intensity_a
    RTS
; BIOS Wrappers - VIDE compatible (ensure DP=$D0 per call)
__Intensity_a:
TFR B,A         ; Move B to A (BIOS expects intensity in A)
JMP Intensity_a ; JMP (not JSR) - BIOS returns to original caller
__Reset0Ref:
JMP Reset0Ref   ; JMP (not JSR) - BIOS returns to original caller
__Moveto_d:
LDA 2,S         ; Get Y from stack (after return address)
JMP Moveto_d    ; JMP (not JSR) - BIOS returns to original caller
__Draw_Line_d:
LDA 2,S         ; Get dy from stack (after return address)
JMP Draw_Line_d ; JMP (not JSR) - BIOS returns to original caller
; ============================================================================
; DRAW_CIRCLE_RUNTIME - Draw circle with runtime parameters
; ============================================================================
; Follows Draw_Sync_List_At pattern: read params BEFORE DP change
; Inputs: DRAW_CIRCLE_XC, DRAW_CIRCLE_YC, DRAW_CIRCLE_DIAM, DRAW_CIRCLE_INTENSITY (bytes in RAM)
; Uses 16-segment polygon (same as constant path) via MUL scaling of fixed fractions
; 4 unique delta fractions of radius r (16-gon, vertices at k*22.5 deg):
;   a = 0.3827*r (sin22.5) via MUL #98 /256, stored at DRAW_CIRCLE_TEMP+2
;   b = 0.3244*r (sin45-sin22.5) via MUL #83 /256, stored at DRAW_CIRCLE_TEMP+3
;   c = 0.2168*r via MUL #56 /256, stored at DRAW_CIRCLE_TEMP+4
;   d = 0.0761*r via MUL #19 /256, stored at DRAW_CIRCLE_TEMP+5
; DRAW_CIRCLE_TEMP layout: [radius16][a][b][c][d][--][--]
DRAW_CIRCLE_RUNTIME:
; Read ALL parameters into registers/stack BEFORE changing DP (critical!)
; (These are byte variables, use LDB not LDD)
LDB DRAW_CIRCLE_INTENSITY
PSHS B                 ; Save intensity on stack

LDB DRAW_CIRCLE_DIAM
SEX                    ; Sign-extend to 16-bit (diameter is unsigned 0..255)
LSRA                   ; Divide by 2 to get radius
RORB
STD DRAW_CIRCLE_TEMP   ; DRAW_CIRCLE_TEMP = radius (16-bit, big-endian: +0=hi, +1=lo)

LDB DRAW_CIRCLE_XC     ; xc (signed -128..127)
SEX
STD DRAW_CIRCLE_TEMP+2 ; Save xc (16-bit, reused for 'a' after Moveto)

LDB DRAW_CIRCLE_YC     ; yc (signed -128..127)
SEX
STD DRAW_CIRCLE_TEMP+4 ; Save yc (16-bit, reused for 'c' after Moveto)

; NOW safe to setup BIOS (all params are in DRAW_CIRCLE_TEMP+stack)
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
; radius = DRAW_CIRCLE_TEMP, xc = DRAW_CIRCLE_TEMP+2, yc = DRAW_CIRCLE_TEMP+4
LDD DRAW_CIRCLE_TEMP   ; D = radius (16-bit)
ADDD DRAW_CIRCLE_TEMP+2 ; D = xc + radius
TFR B,B                ; Keep X in B (low byte)
PSHS B                 ; Save X on stack
LDD DRAW_CIRCLE_TEMP+4 ; Load yc
TFR B,A                ; Y to A
PULS B                 ; X to B
JSR Moveto_d

; Precompute 4 delta fractions using MUL (same fractions as constant 16-gon path)
; radius is at DRAW_CIRCLE_TEMP+1 (low byte, 0..127)
; DRAW_CIRCLE_TEMP+2..5 now free to reuse for a,b,c,d
; MUL: A * B -> D (unsigned); A_after = floor(frac * r) when frac byte = round(frac*256)
LDB DRAW_CIRCLE_TEMP+1 ; radius
LDA #98                ; 98/256 = 0.3828 ~ sin(22.5 deg) = 0.3827
MUL                    ; A = floor(0.3828 * r) = a
STA DRAW_CIRCLE_TEMP+2 ; Store a
LDB DRAW_CIRCLE_TEMP+1 ; radius
LDA #83                ; 83/256 = 0.3242 ~ 0.3244
MUL                    ; A = b
STA DRAW_CIRCLE_TEMP+3 ; Store b
LDB DRAW_CIRCLE_TEMP+1 ; radius
LDA #56                ; 56/256 = 0.2188 ~ 0.2168
MUL                    ; A = c
STA DRAW_CIRCLE_TEMP+4 ; Store c
LDB DRAW_CIRCLE_TEMP+1 ; radius
LDA #19                ; 19/256 = 0.0742 ~ 0.0761
MUL                    ; A = d
STA DRAW_CIRCLE_TEMP+5 ; Store d

; Draw 16 unrolled segments - 16-gon counterclockwise from (xc+r, yc)
; Draw_Line_d(A=dy, B=dx). Symmetry pattern by quadrant:
;   Q1 (0->90):   (+a,-d), (+b,-c), (+c,-b), (+d,-a)
;   Q2 (90->180): (-d,-a), (-c,-b), (-b,-c), (-a,-d)
;   Q3 (180->270):(-a,+d), (-b,+c), (-c,+b), (-d,+a)
;   Q4 (270->360):(+d,+a), (+c,+b), (+b,+c), (+a,+d)

; --- Q1 ---
; Seg 0: dy=+a, dx=-d
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+2  ; a
LDB DRAW_CIRCLE_TEMP+5  ; d
NEGB
JSR Draw_Line_d
; Seg 1: dy=+b, dx=-c
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+3  ; b
LDB DRAW_CIRCLE_TEMP+4  ; c
NEGB
JSR Draw_Line_d
; Seg 2: dy=+c, dx=-b
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+4  ; c
LDB DRAW_CIRCLE_TEMP+3  ; b
NEGB
JSR Draw_Line_d
; Seg 3: dy=+d, dx=-a
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+5  ; d
LDB DRAW_CIRCLE_TEMP+2  ; a
NEGB
JSR Draw_Line_d

; --- Q2 ---
; Seg 4: dy=-d, dx=-a
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+5  ; d
NEGA
LDB DRAW_CIRCLE_TEMP+2  ; a
NEGB
JSR Draw_Line_d
; Seg 5: dy=-c, dx=-b
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+4  ; c
NEGA
LDB DRAW_CIRCLE_TEMP+3  ; b
NEGB
JSR Draw_Line_d
; Seg 6: dy=-b, dx=-c
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+3  ; b
NEGA
LDB DRAW_CIRCLE_TEMP+4  ; c
NEGB
JSR Draw_Line_d
; Seg 7: dy=-a, dx=-d
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+2  ; a
NEGA
LDB DRAW_CIRCLE_TEMP+5  ; d
NEGB
JSR Draw_Line_d

; --- Q3 ---
; Seg 8: dy=-a, dx=+d
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+2  ; a
NEGA
LDB DRAW_CIRCLE_TEMP+5  ; d (positive)
JSR Draw_Line_d
; Seg 9: dy=-b, dx=+c
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+3  ; b
NEGA
LDB DRAW_CIRCLE_TEMP+4  ; c (positive)
JSR Draw_Line_d
; Seg 10: dy=-c, dx=+b
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+4  ; c
NEGA
LDB DRAW_CIRCLE_TEMP+3  ; b (positive)
JSR Draw_Line_d
; Seg 11: dy=-d, dx=+a
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+5  ; d
NEGA
LDB DRAW_CIRCLE_TEMP+2  ; a (positive)
JSR Draw_Line_d

; --- Q4 ---
; Seg 12: dy=+d, dx=+a
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+5  ; d (positive)
LDB DRAW_CIRCLE_TEMP+2  ; a (positive)
JSR Draw_Line_d
; Seg 13: dy=+c, dx=+b
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+4  ; c (positive)
LDB DRAW_CIRCLE_TEMP+3  ; b (positive)
JSR Draw_Line_d
; Seg 14: dy=+b, dx=+c
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+3  ; b (positive)
LDB DRAW_CIRCLE_TEMP+4  ; c (positive)
JSR Draw_Line_d
; Seg 15: dy=+a, dx=+d
CLR Vec_Misc_Count
LDA DRAW_CIRCLE_TEMP+2  ; a (positive)
LDB DRAW_CIRCLE_TEMP+5  ; d (positive)
JSR Draw_Line_d

LDA #$C8
TFR A,DP           ; Restore DP=$C8 before return
RTS

START:
    LDA #$D0
    TFR A,DP        ; Set Direct Page for BIOS (CRITICAL - do once at startup)
    CLR $C80E        ; Initialize Vec_Prev_Btns to 0 for Read_Btns debounce
    LDA #$80
    STA VIA_t1_cnt_lo
    LDX #Vec_Default_Stk
    TFR X,S

    ; *** DEBUG *** main() function code inline (initialization)
    ; VPy_LINE:23
    ; VPy_LINE:6
    LDD #0
    STD VAR_COUNTER
    ; VPy_LINE:7
    LDD #0
    STD VAR_STATE
    ; VPy_LINE:8
    LDD #0
    STD VAR_SHAPE_TYPE
    ; VPy_LINE:11
    LDD #0
    STD VAR_DIRECTION_X
    ; VPy_LINE:12
    LDD #0
    STD VAR_DIRECTION_Y
    ; VPy_LINE:15
    LDD #0
    STD VAR_POS_X
    ; VPy_LINE:16
    LDD #0
    STD VAR_POS_Y
    ; VPy_LINE:17
    LDD #0
    STD VAR_JOY_X
    ; VPy_LINE:25
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_COUNTER
    STU TMPPTR
    STX ,U
    ; VPy_LINE:26
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_STATE
    STU TMPPTR
    STX ,U
    ; VPy_LINE:27
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_SHAPE_TYPE
    STU TMPPTR
    STX ,U
    ; VPy_LINE:28
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_DIRECTION_X
    STU TMPPTR
    STX ,U
    ; VPy_LINE:29
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_DIRECTION_Y
    STU TMPPTR
    STX ,U
    ; VPy_LINE:30
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_POS_X
    STU TMPPTR
    STX ,U
    ; VPy_LINE:31
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_POS_Y
    STU TMPPTR
    STX ,U
    ; VPy_LINE:32
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_JOY_X
    STU TMPPTR
    STX ,U
    ; VPy_LINE:33
    LDD #100
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 33
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT

MAIN:
    JSR $F1AF    ; DP_to_C8 (required for RAM access)
    ; === Initialize Joystick (one-time setup) ===
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

    ; JSR Wait_Recal is now called at start of LOOP_BODY (see auto-inject)
    LDA #$80
    STA VIA_t1_cnt_lo
    CLR VPY_MOVE_X  ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y  ; MOVE offset defaults to 0
    LDA #$F8
    STA TEXT_SCALE_H  ; Default height = -8 (normal size)
    LDA #$48
    STA TEXT_SCALE_W  ; Default width = 72 (normal size)
    ; *** Call loop() as subroutine (executed every frame)
    JSR LOOP_BODY
    BRA MAIN

BASE_INTENSITY EQU 100
MAX_X EQU 120
MIN_X EQU 65416
    ; VPy_LINE:35
LOOP_BODY:
    JSR Wait_Recal  ; CRITICAL: Sync with CRT refresh (50Hz frame timing)
    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access
    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)
    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access
    ; DEBUG: Statement 0 - Discriminant(0)
    ; VPy_LINE:37
; NATIVE_CALL: J1_X at line 37
    JSR J1X_BUILTIN
    STD RESULT
    LDX RESULT
    LDU #VAR_JOY_X
    STU TMPPTR
    STX ,U
    ; DEBUG: Statement 1 - Discriminant(9)
    ; VPy_LINE:40
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_2
    LDD #0
    STD RESULT
    BRA CE_3
CT_2:
    LDD #1
    STD RESULT
CE_3:
    LDD RESULT
    LBEQ IF_NEXT_1
    ; VPy_LINE:41
    LDD #-1
    STD RESULT
    LDX RESULT
    LDU #VAR_DIRECTION_X
    STU TMPPTR
    STX ,U
    LBRA IF_END_0
IF_NEXT_1:
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_5
    LDD #0
    STD RESULT
    BRA CE_6
CT_5:
    LDD #1
    STD RESULT
CE_6:
    LDD RESULT
    LBEQ IF_NEXT_4
    ; VPy_LINE:43
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_DIRECTION_X
    STU TMPPTR
    STX ,U
    LBRA IF_END_0
IF_NEXT_4:
    ; VPy_LINE:45
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_DIRECTION_X
    STU TMPPTR
    STX ,U
IF_END_0:
    ; DEBUG: Statement 2 - Discriminant(0)
    ; VPy_LINE:48
    LDD VAR_POS_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD VAR_DIRECTION_X
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_POS_X
    STU TMPPTR
    STX ,U
    ; DEBUG: Statement 3 - Discriminant(9)
    ; VPy_LINE:49
    LDD VAR_POS_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #120
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_9
    LDD #0
    STD RESULT
    BRA CE_10
CT_9:
    LDD #1
    STD RESULT
CE_10:
    LDD RESULT
    LBEQ IF_NEXT_8
    ; VPy_LINE:50
    LDD #120
    STD RESULT
    LDX RESULT
    LDU #VAR_POS_X
    STU TMPPTR
    STX ,U
    LBRA IF_END_7
IF_NEXT_8:
IF_END_7:
    ; DEBUG: Statement 4 - Discriminant(9)
    ; VPy_LINE:51
    LDD VAR_POS_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-120
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_13
    LDD #0
    STD RESULT
    BRA CE_14
CT_13:
    LDD #1
    STD RESULT
CE_14:
    LDD RESULT
    LBEQ IF_NEXT_12
    ; VPy_LINE:52
    LDD #-120
    STD RESULT
    LDX RESULT
    LDU #VAR_POS_X
    STU TMPPTR
    STX ,U
    LBRA IF_END_11
IF_NEXT_12:
IF_END_11:
    ; DEBUG: Statement 5 - Discriminant(9)
    ; VPy_LINE:55
    LDD VAR_COUNTER
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #32
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_17
    LDD #0
    STD RESULT
    BRA CE_18
CT_17:
    LDD #1
    STD RESULT
CE_18:
    LDD RESULT
    LBEQ IF_NEXT_16
    ; VPy_LINE:56
    LDD VAR_COUNTER
    STD RESULT
    LDX RESULT
    LDU #VAR_POS_Y
    STU TMPPTR
    STX ,U
    LBRA IF_END_15
IF_NEXT_16:
    LDD VAR_COUNTER
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #64
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_20
    LDD #0
    STD RESULT
    BRA CE_21
CT_20:
    LDD #1
    STD RESULT
CE_21:
    LDD RESULT
    LBEQ IF_NEXT_19
    ; VPy_LINE:58
    LDD #64
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD VAR_COUNTER
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_POS_Y
    STU TMPPTR
    STX ,U
    LBRA IF_END_15
IF_NEXT_19:
    ; VPy_LINE:60
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_POS_Y
    STU TMPPTR
    STX ,U
IF_END_15:
    ; DEBUG: Statement 6 - Discriminant(0)
    ; VPy_LINE:63
    LDD VAR_COUNTER
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_COUNTER
    STU TMPPTR
    STX ,U
    ; DEBUG: Statement 7 - Discriminant(9)
    ; VPy_LINE:66
; NATIVE_CALL: J1_BUTTON_1 at line 66
    JSR J1B1_BUILTIN
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_24
    LDD #0
    STD RESULT
    BRA CE_25
CT_24:
    LDD #1
    STD RESULT
CE_25:
    LDD RESULT
    LBEQ IF_NEXT_23
    ; VPy_LINE:67
    LDD VAR_SHAPE_TYPE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_SHAPE_TYPE
    STU TMPPTR
    STX ,U
    ; VPy_LINE:68
    LDD VAR_SHAPE_TYPE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_28
    LDD #0
    STD RESULT
    BRA CE_29
CT_28:
    LDD #1
    STD RESULT
CE_29:
    LDD RESULT
    LBEQ IF_NEXT_27
    ; VPy_LINE:69
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_SHAPE_TYPE
    STU TMPPTR
    STX ,U
    LBRA IF_END_26
IF_NEXT_27:
IF_END_26:
    LBRA IF_END_22
IF_NEXT_23:
IF_END_22:
    ; DEBUG: Statement 8 - Discriminant(8)
    ; VPy_LINE:72
    LDD VAR_POS_X
    STD RESULT
    STB VPY_MOVE_X  ; MOVE X (low byte)
    LDD VAR_POS_Y
    STD RESULT
    STB VPY_MOVE_Y  ; MOVE Y (low byte)
    LDD #0
    STD RESULT
    ; DEBUG: Statement 9 - Discriminant(9)
    ; VPy_LINE:74
    LDD VAR_SHAPE_TYPE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_32
    LDD #0
    STD RESULT
    BRA CE_33
CT_32:
    LDD #1
    STD RESULT
CE_33:
    LDD RESULT
    LBEQ IF_NEXT_31
    ; VPy_LINE:75
    LDD VAR_POS_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #10
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    STD >DRAW_LINE_ARGS+0
    LDD VAR_POS_Y
    STD RESULT
    STD >DRAW_LINE_ARGS+2
    LDD VAR_POS_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #10
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    STD >DRAW_LINE_ARGS+4
    LDD VAR_POS_Y
    STD RESULT
    STD >DRAW_LINE_ARGS+6
    LDD #100
    STD RESULT
    STD >DRAW_LINE_ARGS+8
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    LBRA IF_END_30
IF_NEXT_31:
    LDD VAR_SHAPE_TYPE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_35
    LDD #0
    STD RESULT
    BRA CE_36
CT_35:
    LDD #1
    STD RESULT
CE_36:
    LDD RESULT
    LBEQ IF_NEXT_34
    ; VPy_LINE:77
    LDD VAR_POS_X
    STD RESULT
    LDB RESULT+1  ; xc (low byte, signed -128..127)
    STB DRAW_CIRCLE_XC
    LDD VAR_POS_Y
    STD RESULT
    LDB RESULT+1  ; yc (low byte, signed -128..127)
    STB DRAW_CIRCLE_YC
    LDD #10
    STD RESULT
    LDB RESULT+1  ; diameter (low byte, 0..255)
    STB DRAW_CIRCLE_DIAM
    LDD #100
    STD RESULT
    LDB RESULT+1  ; intensity (low byte, 0..127)
    STB DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_30
IF_NEXT_34:
    ; VPy_LINE:79
    LDD #3
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #100
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDD VAR_POS_X
    STD RESULT
    LDD RESULT
    STD VAR_ARG2
    LDD VAR_POS_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #10
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDD RESULT
    STD VAR_ARG3
    LDD VAR_POS_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #10
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDD RESULT
    STD VAR_ARG4
; NATIVE_CALL: DRAW_POLYGON at line 79
    JSR DRAW_POLYGON
    CLRA
    CLRB
    STD RESULT
IF_END_30:
    ; DEBUG: Statement 10 - Discriminant(8)
    ; VPy_LINE:82
    LDD #80
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 82
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; DEBUG: Statement 11 - Discriminant(8)
    ; VPy_LINE:83
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #110
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_0
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 83
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; DEBUG: Statement 12 - Discriminant(8)
    ; VPy_LINE:84
    LDD #-120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #100
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDD VAR_COUNTER
    STD RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_NUMBER at line 84
    JSR VECTREX_PRINT_NUMBER
    CLRA
    CLRB
    STD RESULT
    RTS

;***************************************************************************
; DATA SECTION
;***************************************************************************
; String literals (classic FCC + $80 terminator)
STR_0:
    FCC "TYPES TEST"
    FCB $80
