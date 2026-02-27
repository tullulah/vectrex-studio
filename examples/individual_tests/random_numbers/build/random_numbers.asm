; --- Motorola 6809 backend (Vectrex) title='RAND' origin=$0000 ---
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
    FCC "RAND"
    FCB $80
    FCB 0

;***************************************************************************
; CODE SECTION
;***************************************************************************

; === RAM VARIABLE DEFINITIONS (EQU) ===
; AUTO-GENERATED - All offsets calculated automatically
; Total RAM used: 64 bytes
RESULT               EQU $C880+$00   ; Main result temporary (2 bytes)
TMPPTR               EQU $C880+$02   ; Pointer temp (used by DRAW_VECTOR, arrays, structs) (2 bytes)
TMPPTR2              EQU $C880+$04   ; Pointer temp 2 (for nested array operations) (2 bytes)
TEMP_YX              EQU $C880+$06   ; Temporary y,x storage (2 bytes)
TEMP_X               EQU $C880+$08   ; Temporary x storage (1 bytes)
TEMP_Y               EQU $C880+$09   ; Temporary y storage (1 bytes)
VPY_MOVE_X           EQU $C880+$0A   ; MOVE() current X offset (signed byte, 0 by default) (1 bytes)
VPY_MOVE_Y           EQU $C880+$0B   ; MOVE() current Y offset (signed byte, 0 by default) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$0C   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity as i16x5) (10 bytes)
RAND_SEED            EQU $C880+$16   ; Random seed for RAND() LCG (2 bytes)
NUM_STR              EQU $C880+$18   ; String buffer for PRINT_NUMBER (5 digits + terminator) (6 bytes)
DRAW_CIRCLE_XC       EQU $C880+$1E   ; Circle center X (byte) (1 bytes)
DRAW_CIRCLE_YC       EQU $C880+$1F   ; Circle center Y (byte) (1 bytes)
DRAW_CIRCLE_DIAM     EQU $C880+$20   ; Circle diameter (byte) (1 bytes)
DRAW_CIRCLE_INTENSITY EQU $C880+$21   ; Circle intensity (byte) (1 bytes)
DRAW_CIRCLE_TEMP     EQU $C880+$22   ; Circle drawing temporaries (radius=2, xc=2, yc=2, spare=2) (8 bytes)
VAR_RX1              EQU $C880+$2A   ; User variable (2 bytes)
VAR_RY1              EQU $C880+$2C   ; User variable (2 bytes)
VAR_RX2              EQU $C880+$2E   ; User variable (2 bytes)
VAR_RY2              EQU $C880+$30   ; User variable (2 bytes)
VAR_RX3              EQU $C880+$32   ; User variable (2 bytes)
VAR_RY4              EQU $C880+$34   ; User variable (2 bytes)
VAR_ARG0             EQU $C880+$36   ; Function argument 0 (2 bytes)
VAR_ARG1             EQU $C880+$38   ; Function argument 1 (2 bytes)
VAR_ARG2             EQU $C880+$3A   ; Function argument 2 (2 bytes)
VAR_ARG3             EQU $C880+$3C   ; Function argument 3 (2 bytes)
VAR_ARG4             EQU $C880+$3E   ; Function argument 4 (2 bytes)

    JMP START

;**** CONST DECLARATIONS (NUMBER-ONLY) ****

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
    JSR Reset0Ref  ; Reset beam to center for absolute text positioning
    LDU VAR_ARG2   ; string pointer (ARG2 = third param)
    LDA VAR_ARG1+1 ; Y (ARG1 = second param)
    LDB VAR_ARG0+1 ; X (ARG0 = first param)
    JSR Print_Str_d
    LDA #$80
    STA $D004      ; Restore VIA_t1_cnt_lo=$80 (Moveto_d_7F sets it to $7F)
    JSR $F1AF      ; DP_to_C8 (restore before return)
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

; === RAND_HELPER - LCG random number generator ===
; Returns D = random value 0..$7FFF
RAND_HELPER:
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
    ADDD #13
    STD RAND_SEED  ; Store full 16-bit state BEFORE masking output
    ANDA #$7F      ; Mask output to positive 15-bit (state stays full)
    RTS

; === RAND_RANGE_HELPER - Random in [min, max] ===
; Inputs: TMPPTR = min (i16), TMPPTR2 = max (i16)
; Returns: D = min + (rand % (max - min + 1))
RAND_RANGE_HELPER:
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

START:
    LDA #$D0
    TFR A,DP        ; Set Direct Page for BIOS (CRITICAL - do once at startup)
    CLR $C80E        ; Initialize Vec_Prev_Btns to 0 for Read_Btns debounce
    LDA #$80
    STA VIA_t1_cnt_lo
    LDX #Vec_Default_Stk
    TFR X,S

    ; *** DEBUG *** main() function code inline (initialization)
    ; VPy_LINE:15
    ; VPy_LINE:8
    LDD #0
    STD VAR_RX1
    ; VPy_LINE:9
    LDD #0
    STD VAR_RY1
    ; VPy_LINE:10
    LDD #0
    STD VAR_RX2
    ; VPy_LINE:11
    LDD #0
    STD VAR_RY2
    ; VPy_LINE:12
    LDD #0
    STD VAR_RX3
    ; VPy_LINE:13
    LDD #0
    STD VAR_RY4
    ; VPy_LINE:16
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_RX1
    STU TMPPTR
    STX ,U
    ; VPy_LINE:17
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_RY1
    STU TMPPTR
    STX ,U
    ; VPy_LINE:18
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_RX2
    STU TMPPTR
    STX ,U
    ; VPy_LINE:19
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_RY2
    STU TMPPTR
    STX ,U
    ; VPy_LINE:20
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_RX3
    STU TMPPTR
    STX ,U
    ; VPy_LINE:21
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_RY4
    STU TMPPTR
    STX ,U

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
    ; *** Call loop() as subroutine (executed every frame)
    JSR LOOP_BODY
    BRA MAIN

    ; VPy_LINE:23
LOOP_BODY:
    LEAS -2,S ; allocate locals
    JSR Wait_Recal  ; CRITICAL: Sync with CRT refresh (50Hz frame timing)
    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access
    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)
    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access
    ; DEBUG: Statement 0 - Discriminant(8)
    ; VPy_LINE:24
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-50
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #90
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_0
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 24
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; DEBUG: Statement 1 - Discriminant(0)
    ; VPy_LINE:27
    ; RAND_RANGE(min, max)
    LDD #-80
    STD RESULT
    STD TMPPTR
    LDD #80
    STD RESULT
    STD TMPPTR2
    JSR RAND_RANGE_HELPER
    STD RESULT
    LDX RESULT
    LDU #VAR_RX1
    STU TMPPTR
    STX ,U
    ; DEBUG: Statement 2 - Discriminant(0)
    ; VPy_LINE:28
    ; RAND_RANGE(min, max)
    LDD #-60
    STD RESULT
    STD TMPPTR
    LDD #60
    STD RESULT
    STD TMPPTR2
    JSR RAND_RANGE_HELPER
    STD RESULT
    LDX RESULT
    LDU #VAR_RY1
    STU TMPPTR
    STX ,U
    ; DEBUG: Statement 3 - Discriminant(8)
    ; VPy_LINE:29
    LDD VAR_RX1
    STD RESULT
    LDB RESULT+1  ; xc (low byte, signed -128..127)
    STB DRAW_CIRCLE_XC
    LDD VAR_RY1
    STD RESULT
    LDB RESULT+1  ; yc (low byte, signed -128..127)
    STB DRAW_CIRCLE_YC
    LDD #20
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
    ; DEBUG: Statement 4 - Discriminant(0)
    ; VPy_LINE:31
    ; RAND_RANGE(min, max)
    LDD #-80
    STD RESULT
    STD TMPPTR
    LDD #80
    STD RESULT
    STD TMPPTR2
    JSR RAND_RANGE_HELPER
    STD RESULT
    LDX RESULT
    LDU #VAR_RX2
    STU TMPPTR
    STX ,U
    ; DEBUG: Statement 5 - Discriminant(0)
    ; VPy_LINE:32
    ; RAND_RANGE(min, max)
    LDD #-60
    STD RESULT
    STD TMPPTR
    LDD #60
    STD RESULT
    STD TMPPTR2
    JSR RAND_RANGE_HELPER
    STD RESULT
    LDX RESULT
    LDU #VAR_RY2
    STU TMPPTR
    STX ,U
    ; DEBUG: Statement 6 - Discriminant(8)
    ; VPy_LINE:33
    LDD VAR_RX2
    STD RESULT
    LDB RESULT+1  ; xc (low byte, signed -128..127)
    STB DRAW_CIRCLE_XC
    LDD VAR_RY2
    STD RESULT
    LDB RESULT+1  ; yc (low byte, signed -128..127)
    STB DRAW_CIRCLE_YC
    LDD #20
    STD RESULT
    LDB RESULT+1  ; diameter (low byte, 0..255)
    STB DRAW_CIRCLE_DIAM
    LDD #80
    STD RESULT
    LDB RESULT+1  ; intensity (low byte, 0..127)
    STB DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    ; DEBUG: Statement 7 - Discriminant(0)
    ; VPy_LINE:35
    ; RAND_RANGE(min, max)
    LDD #-80
    STD RESULT
    STD TMPPTR
    LDD #80
    STD RESULT
    STD TMPPTR2
    JSR RAND_RANGE_HELPER
    STD RESULT
    LDX RESULT
    LDU #VAR_RX3
    STU TMPPTR
    STX ,U
    ; DEBUG: Statement 8 - Discriminant(0)
    ; VPy_LINE:36
    ; RAND_RANGE(min, max)
    LDD #-60
    STD RESULT
    STD TMPPTR
    LDD #60
    STD RESULT
    STD TMPPTR2
    JSR RAND_RANGE_HELPER
    STD RESULT
    LDX RESULT
    STX 0 ,S
    ; DEBUG: Statement 9 - Discriminant(8)
    ; VPy_LINE:37
    LDD VAR_RX3
    STD RESULT
    LDB RESULT+1  ; xc (low byte, signed -128..127)
    STB DRAW_CIRCLE_XC
    LDD 0 ,S
    STD RESULT
    LDB RESULT+1  ; yc (low byte, signed -128..127)
    STB DRAW_CIRCLE_YC
    LDD #20
    STD RESULT
    LDB RESULT+1  ; diameter (low byte, 0..255)
    STB DRAW_CIRCLE_DIAM
    LDD #60
    STD RESULT
    LDB RESULT+1  ; intensity (low byte, 0..127)
    STB DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    LEAS 2,S ; free locals
    RTS

;***************************************************************************
; DATA SECTION
;***************************************************************************
; String literals (classic FCC + $80 terminator)
STR_0:
    FCC "RANDOM"
    FCB $80
