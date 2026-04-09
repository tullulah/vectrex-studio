    ORG $4000  ; Fixed bank window (runtime helpers + interrupt vectors)


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
    ; Runtime helpers (accessible from all banks)

;***************************************************************************
; ASSET LOOKUP TABLES (for banked asset access)
; Total: 1 vectors, 0 music, 0 sfx, 0 levels
;***************************************************************************

; Vector Asset Index Mapping:
;   0 = benchy (Bank #1)

VECTOR_BANK_TABLE:
    FCB 1              ; Bank ID

VECTOR_ADDR_TABLE:
    FDB _BENCHY_VECTORS    ; benchy

; Legacy unified tables (all assets)
ASSET_BANK_TABLE:
    FCB 1              ; Bank ID

ASSET_ADDR_TABLE:
    FDB _BENCHY_VECTORS    ; benchy

;***************************************************************************
; DRAW_VECTOR_BANKED - Draw vector asset with automatic bank switching
; Input: X = asset index (0-based), DRAW_VEC_X/Y set for position
; Uses: A, B, X, Y
; Preserves: CURRENT_ROM_BANK (restored after drawing)
;***************************************************************************
DRAW_VECTOR_BANKED:
    ; Save index to U register (avoid stack order issues)
    TFR X,U              ; U = vector index
    ; Save context: original bank on stack
    LDA CURRENT_ROM_BANK
    PSHS A               ; Stack: [A]

    ; Get asset's bank from lookup table
    TFR X,D              ; D = asset index
    LDX #VECTOR_BANK_TABLE
    LDA D,X              ; A = bank ID for this asset
    STA CURRENT_ROM_BANK ; Update RAM tracker
    STA $DF00            ; Switch bank hardware register

    ; Get asset's address from lookup table (2 bytes per entry)
    TFR U,D              ; D = asset index (saved in U at entry)
    ASLB                 ; *2 for FDB entries
    ROLA
    LDX #VECTOR_ADDR_TABLE
    LEAX D,X             ; X points to address entry
    LDX ,X               ; X = _VEC_VECTORS header address in banked ROM

    ; Set up for drawing
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY
    JSR $F1AA            ; DP_to_D0

    ; Loop over all paths (header bytes 0-1 = path_count FDB, +2.. = FDB table)
    LDD ,X               ; D = path_count (16-bit)
    CMPD #0
    LBEQ DVB_DONE        ; No paths
    LEAY 2,X             ; Y = pointer to first FDB entry (after 2-byte header)
DVB_PATH_LOOP:
    PSHS D               ; Save remaining path count (2 bytes)
    LDX ,Y               ; X = path data address (FDB entry)
    JSR Draw_Sync_List_At_With_Mirrors
    LEAY 2,Y             ; Advance to next FDB entry
    PULS D               ; Restore count
    SUBD #1
    BNE DVB_PATH_LOOP
DVB_DONE:

    JSR $F1AF            ; DP_to_C8

    ; Restore original bank from stack (only A was pushed with PSHS A)
    PULS A               ; A = original bank
    STA CURRENT_ROM_BANK
    STA $DF00            ; Restore bank

    RTS

;***************************************************************************
; RUNTIME HELPERS
;***************************************************************************

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

Draw_Sync_List_At_With_Mirrors:
; Unified mirror support using flags: MIRROR_X and MIRROR_Y
; Conditionally negates X and/or Y coordinates and deltas
; NOTE: Caller must ensure DP=$D0 for VIA access
; CRITICAL: Do NOT call JSR $F2AB (Intensity_a) here! Intensity_a manipulates
; VIA Port B through states $05->$04->$01 which resets the analog hardware
; (zero-reference sequence) and would disrupt the beam position mid-drawing.
; Instead we replicate only the VIA Port A write + Port B Z-axis strobe inline.
LDA ,X+                 ; Read per-path intensity from vector data
DSWM_SET_INTENSITY:
STA >$C832              ; Update BIOS variable (Vec_Misc_Count)
STA >$D001              ; Port A = intensity (alg_xsh = intensity XOR $80)
LDA #$04
STA >$D000              ; Port B=$04: Z-axis mux enabled -> alg_zsh updated
LDA #$01
STA >$D000              ; Port B=$01: restore normal mux
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
; T1 fixed at $7F (constant scale; brightness is set via $C832 above, independently)
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
CLR VIA_shift_reg       ; beam off (PB stays 1 for next segment)
LBRA DSWM_LOOP          ; Long branch
; Next path: repeat mirror logic for new path header
DSWM_NEXT_PATH:
TFR X,D
PSHS D
; Read per-path intensity from vector data
LDA ,X+                 ; Read intensity from vector data
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
STA >$C832              ; Update BIOS variable (Vec_Misc_Count)
STA >$D001              ; Port A = intensity (alg_xsh = intensity XOR $80)
LDA #$04
STA >$D000              ; Port B=$04: Z-axis mux enabled -> alg_zsh updated
LDA #$01
STA >$D000              ; Port B=$01: restore normal mux
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
; T1 fixed at $7F (constant scale; brightness set via $C832 above)
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
; ============================================================================
; SMUL8 - Signed 8x8 multiply, result = (A * B) / 128  (i8)
; ============================================================================
; Input:  A = op1 (i8), B = op2 (i8)
; Output: A = result (i8)
; Destroys: B, ROT3D_SIGN
SMUL8:
CLR >ROT3D_SIGN
TSTA
BPL SMUL8_AP
NEGA
INC >ROT3D_SIGN
SMUL8_AP:
TSTB
BPL SMUL8_BP
NEGB
INC >ROT3D_SIGN
SMUL8_BP:
MUL             ; D = |A|*|B| unsigned (0..16129)
ASLB            ; C <- B[7] (high bit of low byte)
ROLA            ; A = (D >> 7) = result/128 magnitude
PSHS A          ; save magnitude on stack (PSHS does not touch C)
LDA >ROT3D_SIGN
LSRA            ; C = bit0 of SIGN (odd count = negative)
PULS A          ; restore magnitude (PULS A does not touch C on MC6809)
BCC SMUL8_END
NEGA
SMUL8_END:
RTS

; ============================================================================
; DV3D_ROTATE - Apply X/Y/Z Euler rotation to a single point
; ============================================================================
; Input:  ROT3D_RX, ROT3D_RY, ROT3D_RZ (i8 world coords)
;         ROT3D_SIN/COS_X/Y/Z (i8 rotation factors)
;         ROT3D_OX, ROT3D_OY (i8 screen offsets)
; Output: ROT3D_SCR_X, ROT3D_SCR_Y (screen coordinates with offset)
; Destroys: A, B, ROT3D_TEMP, ROT3D_TEMP2, ROT3D_Y1, ROT3D_Z1, ROT3D_X2
DV3D_ROTATE:
; -- X-axis rotation: y1 = y*cX - z*sX,  z1 = y*sX + z*cX --
LDA >ROT3D_RY
LDB >ROT3D_COS_X
JSR SMUL8
STA >ROT3D_TEMP
LDA >ROT3D_RZ
LDB >ROT3D_SIN_X
JSR SMUL8
STA >ROT3D_TEMP2
LDA >ROT3D_TEMP
SUBA >ROT3D_TEMP2
STA >ROT3D_Y1

LDA >ROT3D_RY
LDB >ROT3D_SIN_X
JSR SMUL8
STA >ROT3D_TEMP
LDA >ROT3D_RZ
LDB >ROT3D_COS_X
JSR SMUL8
ADDA >ROT3D_TEMP
STA >ROT3D_Z1

; -- Y-axis rotation: x2 = x*cY + z1*sY --
LDA >ROT3D_RX
LDB >ROT3D_COS_Y
JSR SMUL8
STA >ROT3D_TEMP
LDA >ROT3D_Z1
LDB >ROT3D_SIN_Y
JSR SMUL8
ADDA >ROT3D_TEMP
STA >ROT3D_X2

; -- Z-axis rotation: sx = x2*cZ - y1*sZ + OX,  sy = x2*sZ + y1*cZ + OY --
LDA >ROT3D_X2
LDB >ROT3D_COS_Z
JSR SMUL8
STA >ROT3D_TEMP
LDA >ROT3D_Y1
LDB >ROT3D_SIN_Z
JSR SMUL8
STA >ROT3D_TEMP2
LDA >ROT3D_TEMP
SUBA >ROT3D_TEMP2
ADDA >ROT3D_OX
STA >ROT3D_SCR_X

LDA >ROT3D_X2
LDB >ROT3D_SIN_Z
JSR SMUL8
STA >ROT3D_TEMP
LDA >ROT3D_Y1
LDB >ROT3D_COS_Z
JSR SMUL8
ADDA >ROT3D_TEMP
ADDA >ROT3D_OY
STA >ROT3D_SCR_Y
RTS

; ============================================================================
; DRAW_VECTOR_3D_RUNTIME - Draw 3D-rotated vector from compact data table
; ============================================================================
; Input:  X = pointer to _NAME_3D_DATA
;         ROT3D_AX, ROT3D_AY, ROT3D_AZ = raw angles (0-127)
;         ROT3D_OX, ROT3D_OY = screen offsets
;         DP must be $D0 on entry (caller does JSR $F1AA before this)
; Destroys: A, B, X, all ROT3D_* vars
DRAW_VECTOR_3D_RUNTIME:
; --- Compute sin/cos for each axis from LUT (tables in this bank) ---
PSHS X              ; save data pointer
; angle X
LDB >ROT3D_AX
ANDB #$7F           ; mask to 0-127
CLRA
ASLB
ROLA                ; D = angle*2 (FDB byte offset)
STD >TMPVAL
LDX #SIN_TABLE
LEAX D,X
LDA 1,X             ; low byte of FDB = i8 sin
STA >ROT3D_SIN_X
LDD >TMPVAL
LDX #COS_TABLE
LEAX D,X
LDA 1,X
STA >ROT3D_COS_X
; angle Y
LDB >ROT3D_AY
ANDB #$7F
CLRA
ASLB
ROLA
STD >TMPVAL
LDX #SIN_TABLE
LEAX D,X
LDA 1,X
STA >ROT3D_SIN_Y
LDD >TMPVAL
LDX #COS_TABLE
LEAX D,X
LDA 1,X
STA >ROT3D_COS_Y
; angle Z
LDB >ROT3D_AZ
ANDB #$7F
CLRA
ASLB
ROLA
STD >TMPVAL
LDX #SIN_TABLE
LEAX D,X
LDA 1,X
STA >ROT3D_SIN_Z
LDD >TMPVAL
LDX #COS_TABLE
LEAX D,X
LDA 1,X
STA >ROT3D_COS_Z
PULS X              ; restore data pointer

; Use BIOS for drawing — Reset0Ref/Moveto_d/Draw_Line_d require DP=$D0
LDA #$D0
TFR A,DP

; Save data pointer in U (free to use, caller doesn't depend on it)
TFR X,U

; Set intensity $7F in BIOS shadow so Intensity_a picks it up
LDA #$7F
STA >$C832          ; Vec_Brightness

LDB ,U+             ; B = path count
STB >ROT3D_PC

DV3D_PATH_LOOP:
TST >ROT3D_PC
LBEQ DV3D_ALL_DONE
DEC >ROT3D_PC

LDB ,U+             ; B = point count
STB >ROT3D_PT_TOTAL
STB >ROT3D_PT_REM
LDA ,U+             ; A = closed flag
STA >ROT3D_CLOSED

; Reset integrators to origin via BIOS
JSR $F354           ; Reset0Ref — zeros integrators, sets ACR
LDA >$C832          ; A = brightness
JSR $F2AB           ; Intensity_a

; --- Load and rotate first point ---
TFR U,X
LDA ,X+
STA >ROT3D_RX
LDA ,X+
STA >ROT3D_RY
LDA ,X+
STA >ROT3D_RZ
TFR X,U             ; U now past first point
JSR DV3D_ROTATE     ; -> ROT3D_SCR_X, ROT3D_SCR_Y

; Moveto first rotated point (absolute, beam off)
LDA >ROT3D_SCR_Y    ; A = absolute Y
LDB >ROT3D_SCR_X    ; B = absolute X
JSR $F312           ; Moveto_d

; Save first and prev
LDA >ROT3D_SCR_X
STA >ROT3D_FIRST_X
STA >ROT3D_PREV_X
LDA >ROT3D_SCR_Y
STA >ROT3D_FIRST_Y
STA >ROT3D_PREV_Y

DEC >ROT3D_PT_REM

DV3D_SEG_LOOP:
TST >ROT3D_PT_REM
LBEQ DV3D_CLOSE_CHECK
DEC >ROT3D_PT_REM

TFR U,X
LDA ,X+
STA >ROT3D_RX
LDA ,X+
STA >ROT3D_RY
LDA ,X+
STA >ROT3D_RZ
TFR X,U
JSR DV3D_ROTATE     ; -> ROT3D_SCR_X, ROT3D_SCR_Y

; Compute deltas
LDA >ROT3D_SCR_Y
SUBA >ROT3D_PREV_Y
STA >ROT3D_TEMP     ; dy
LDA >ROT3D_SCR_X
SUBA >ROT3D_PREV_X
STA >ROT3D_TEMP2    ; dx
LDA >ROT3D_SCR_Y
STA >ROT3D_PREV_Y
LDA >ROT3D_SCR_X
STA >ROT3D_PREV_X

; Draw segment via BIOS
LDA >ROT3D_TEMP     ; A = dy
LDB >ROT3D_TEMP2    ; B = dx
JSR $F3DF           ; Draw_Line_d
LBRA DV3D_SEG_LOOP

DV3D_CLOSE_CHECK:
TST >ROT3D_CLOSED
BEQ DV3D_NEXT_PATH

; Draw closing segment to first point
LDA >ROT3D_FIRST_Y
SUBA >ROT3D_PREV_Y
STA >ROT3D_TEMP
LDA >ROT3D_FIRST_X
SUBA >ROT3D_PREV_X
LDA >ROT3D_TEMP     ; A = dy
LDB >ROT3D_TEMP2    ; B = dx (still in TEMP2 from last store... no, clobbered)
; Recalculate
LDA >ROT3D_FIRST_Y
SUBA >ROT3D_PREV_Y  ; A = closing dy
STA >ROT3D_TEMP
LDA >ROT3D_FIRST_X
SUBA >ROT3D_PREV_X  ; A = closing dx
TFR A,B             ; B = closing dx
LDA >ROT3D_TEMP     ; A = closing dy
JSR $F3DF           ; Draw_Line_d

DV3D_NEXT_PATH:
LBRA DV3D_PATH_LOOP

DV3D_ALL_DONE:
JSR $F1AF           ; DP_to_C8: restore DP=$C8 for RAM access
RTS

;***************************************************************************
; TRIGONOMETRY LOOKUP TABLES (128 entries each)
;***************************************************************************
SIN_TABLE:
    FDB 0    ; angle 0
    FDB 6    ; angle 1
    FDB 12    ; angle 2
    FDB 19    ; angle 3
    FDB 25    ; angle 4
    FDB 31    ; angle 5
    FDB 37    ; angle 6
    FDB 43    ; angle 7
    FDB 49    ; angle 8
    FDB 54    ; angle 9
    FDB 60    ; angle 10
    FDB 65    ; angle 11
    FDB 71    ; angle 12
    FDB 76    ; angle 13
    FDB 81    ; angle 14
    FDB 85    ; angle 15
    FDB 90    ; angle 16
    FDB 94    ; angle 17
    FDB 98    ; angle 18
    FDB 102    ; angle 19
    FDB 106    ; angle 20
    FDB 109    ; angle 21
    FDB 112    ; angle 22
    FDB 115    ; angle 23
    FDB 117    ; angle 24
    FDB 120    ; angle 25
    FDB 122    ; angle 26
    FDB 123    ; angle 27
    FDB 125    ; angle 28
    FDB 126    ; angle 29
    FDB 126    ; angle 30
    FDB 127    ; angle 31
    FDB 127    ; angle 32
    FDB 127    ; angle 33
    FDB 126    ; angle 34
    FDB 126    ; angle 35
    FDB 125    ; angle 36
    FDB 123    ; angle 37
    FDB 122    ; angle 38
    FDB 120    ; angle 39
    FDB 117    ; angle 40
    FDB 115    ; angle 41
    FDB 112    ; angle 42
    FDB 109    ; angle 43
    FDB 106    ; angle 44
    FDB 102    ; angle 45
    FDB 98    ; angle 46
    FDB 94    ; angle 47
    FDB 90    ; angle 48
    FDB 85    ; angle 49
    FDB 81    ; angle 50
    FDB 76    ; angle 51
    FDB 71    ; angle 52
    FDB 65    ; angle 53
    FDB 60    ; angle 54
    FDB 54    ; angle 55
    FDB 49    ; angle 56
    FDB 43    ; angle 57
    FDB 37    ; angle 58
    FDB 31    ; angle 59
    FDB 25    ; angle 60
    FDB 19    ; angle 61
    FDB 12    ; angle 62
    FDB 6    ; angle 63
    FDB 0    ; angle 64
    FDB -6    ; angle 65
    FDB -12    ; angle 66
    FDB -19    ; angle 67
    FDB -25    ; angle 68
    FDB -31    ; angle 69
    FDB -37    ; angle 70
    FDB -43    ; angle 71
    FDB -49    ; angle 72
    FDB -54    ; angle 73
    FDB -60    ; angle 74
    FDB -65    ; angle 75
    FDB -71    ; angle 76
    FDB -76    ; angle 77
    FDB -81    ; angle 78
    FDB -85    ; angle 79
    FDB -90    ; angle 80
    FDB -94    ; angle 81
    FDB -98    ; angle 82
    FDB -102    ; angle 83
    FDB -106    ; angle 84
    FDB -109    ; angle 85
    FDB -112    ; angle 86
    FDB -115    ; angle 87
    FDB -117    ; angle 88
    FDB -120    ; angle 89
    FDB -122    ; angle 90
    FDB -123    ; angle 91
    FDB -125    ; angle 92
    FDB -126    ; angle 93
    FDB -126    ; angle 94
    FDB -127    ; angle 95
    FDB -127    ; angle 96
    FDB -127    ; angle 97
    FDB -126    ; angle 98
    FDB -126    ; angle 99
    FDB -125    ; angle 100
    FDB -123    ; angle 101
    FDB -122    ; angle 102
    FDB -120    ; angle 103
    FDB -117    ; angle 104
    FDB -115    ; angle 105
    FDB -112    ; angle 106
    FDB -109    ; angle 107
    FDB -106    ; angle 108
    FDB -102    ; angle 109
    FDB -98    ; angle 110
    FDB -94    ; angle 111
    FDB -90    ; angle 112
    FDB -85    ; angle 113
    FDB -81    ; angle 114
    FDB -76    ; angle 115
    FDB -71    ; angle 116
    FDB -65    ; angle 117
    FDB -60    ; angle 118
    FDB -54    ; angle 119
    FDB -49    ; angle 120
    FDB -43    ; angle 121
    FDB -37    ; angle 122
    FDB -31    ; angle 123
    FDB -25    ; angle 124
    FDB -19    ; angle 125
    FDB -12    ; angle 126
    FDB -6    ; angle 127

COS_TABLE:
    FDB 127    ; angle 0
    FDB 127    ; angle 1
    FDB 126    ; angle 2
    FDB 126    ; angle 3
    FDB 125    ; angle 4
    FDB 123    ; angle 5
    FDB 122    ; angle 6
    FDB 120    ; angle 7
    FDB 117    ; angle 8
    FDB 115    ; angle 9
    FDB 112    ; angle 10
    FDB 109    ; angle 11
    FDB 106    ; angle 12
    FDB 102    ; angle 13
    FDB 98    ; angle 14
    FDB 94    ; angle 15
    FDB 90    ; angle 16
    FDB 85    ; angle 17
    FDB 81    ; angle 18
    FDB 76    ; angle 19
    FDB 71    ; angle 20
    FDB 65    ; angle 21
    FDB 60    ; angle 22
    FDB 54    ; angle 23
    FDB 49    ; angle 24
    FDB 43    ; angle 25
    FDB 37    ; angle 26
    FDB 31    ; angle 27
    FDB 25    ; angle 28
    FDB 19    ; angle 29
    FDB 12    ; angle 30
    FDB 6    ; angle 31
    FDB 0    ; angle 32
    FDB -6    ; angle 33
    FDB -12    ; angle 34
    FDB -19    ; angle 35
    FDB -25    ; angle 36
    FDB -31    ; angle 37
    FDB -37    ; angle 38
    FDB -43    ; angle 39
    FDB -49    ; angle 40
    FDB -54    ; angle 41
    FDB -60    ; angle 42
    FDB -65    ; angle 43
    FDB -71    ; angle 44
    FDB -76    ; angle 45
    FDB -81    ; angle 46
    FDB -85    ; angle 47
    FDB -90    ; angle 48
    FDB -94    ; angle 49
    FDB -98    ; angle 50
    FDB -102    ; angle 51
    FDB -106    ; angle 52
    FDB -109    ; angle 53
    FDB -112    ; angle 54
    FDB -115    ; angle 55
    FDB -117    ; angle 56
    FDB -120    ; angle 57
    FDB -122    ; angle 58
    FDB -123    ; angle 59
    FDB -125    ; angle 60
    FDB -126    ; angle 61
    FDB -126    ; angle 62
    FDB -127    ; angle 63
    FDB -127    ; angle 64
    FDB -127    ; angle 65
    FDB -126    ; angle 66
    FDB -126    ; angle 67
    FDB -125    ; angle 68
    FDB -123    ; angle 69
    FDB -122    ; angle 70
    FDB -120    ; angle 71
    FDB -117    ; angle 72
    FDB -115    ; angle 73
    FDB -112    ; angle 74
    FDB -109    ; angle 75
    FDB -106    ; angle 76
    FDB -102    ; angle 77
    FDB -98    ; angle 78
    FDB -94    ; angle 79
    FDB -90    ; angle 80
    FDB -85    ; angle 81
    FDB -81    ; angle 82
    FDB -76    ; angle 83
    FDB -71    ; angle 84
    FDB -65    ; angle 85
    FDB -60    ; angle 86
    FDB -54    ; angle 87
    FDB -49    ; angle 88
    FDB -43    ; angle 89
    FDB -37    ; angle 90
    FDB -31    ; angle 91
    FDB -25    ; angle 92
    FDB -19    ; angle 93
    FDB -12    ; angle 94
    FDB -6    ; angle 95
    FDB 0    ; angle 96
    FDB 6    ; angle 97
    FDB 12    ; angle 98
    FDB 19    ; angle 99
    FDB 25    ; angle 100
    FDB 31    ; angle 101
    FDB 37    ; angle 102
    FDB 43    ; angle 103
    FDB 49    ; angle 104
    FDB 54    ; angle 105
    FDB 60    ; angle 106
    FDB 65    ; angle 107
    FDB 71    ; angle 108
    FDB 76    ; angle 109
    FDB 81    ; angle 110
    FDB 85    ; angle 111
    FDB 90    ; angle 112
    FDB 94    ; angle 113
    FDB 98    ; angle 114
    FDB 102    ; angle 115
    FDB 106    ; angle 116
    FDB 109    ; angle 117
    FDB 112    ; angle 118
    FDB 115    ; angle 119
    FDB 117    ; angle 120
    FDB 120    ; angle 121
    FDB 122    ; angle 122
    FDB 123    ; angle 123
    FDB 125    ; angle 124
    FDB 126    ; angle 125
    FDB 126    ; angle 126
    FDB 127    ; angle 127

TAN_TABLE:
    FDB 0    ; angle 0
    FDB 1    ; angle 1
    FDB 2    ; angle 2
    FDB 3    ; angle 3
    FDB 4    ; angle 4
    FDB 5    ; angle 5
    FDB 6    ; angle 6
    FDB 7    ; angle 7
    FDB 8    ; angle 8
    FDB 9    ; angle 9
    FDB 11    ; angle 10
    FDB 12    ; angle 11
    FDB 13    ; angle 12
    FDB 15    ; angle 13
    FDB 16    ; angle 14
    FDB 18    ; angle 15
    FDB 20    ; angle 16
    FDB 22    ; angle 17
    FDB 24    ; angle 18
    FDB 27    ; angle 19
    FDB 30    ; angle 20
    FDB 33    ; angle 21
    FDB 37    ; angle 22
    FDB 42    ; angle 23
    FDB 48    ; angle 24
    FDB 56    ; angle 25
    FDB 66    ; angle 26
    FDB 80    ; angle 27
    FDB 101    ; angle 28
    FDB 120    ; angle 29
    FDB 120    ; angle 30
    FDB 120    ; angle 31
    FDB -120    ; angle 32
    FDB -120    ; angle 33
    FDB -120    ; angle 34
    FDB -120    ; angle 35
    FDB -101    ; angle 36
    FDB -80    ; angle 37
    FDB -66    ; angle 38
    FDB -56    ; angle 39
    FDB -48    ; angle 40
    FDB -42    ; angle 41
    FDB -37    ; angle 42
    FDB -33    ; angle 43
    FDB -30    ; angle 44
    FDB -27    ; angle 45
    FDB -24    ; angle 46
    FDB -22    ; angle 47
    FDB -20    ; angle 48
    FDB -18    ; angle 49
    FDB -16    ; angle 50
    FDB -15    ; angle 51
    FDB -13    ; angle 52
    FDB -12    ; angle 53
    FDB -11    ; angle 54
    FDB -9    ; angle 55
    FDB -8    ; angle 56
    FDB -7    ; angle 57
    FDB -6    ; angle 58
    FDB -5    ; angle 59
    FDB -4    ; angle 60
    FDB -3    ; angle 61
    FDB -2    ; angle 62
    FDB -1    ; angle 63
    FDB 0    ; angle 64
    FDB 1    ; angle 65
    FDB 2    ; angle 66
    FDB 3    ; angle 67
    FDB 4    ; angle 68
    FDB 5    ; angle 69
    FDB 6    ; angle 70
    FDB 7    ; angle 71
    FDB 8    ; angle 72
    FDB 9    ; angle 73
    FDB 11    ; angle 74
    FDB 12    ; angle 75
    FDB 13    ; angle 76
    FDB 15    ; angle 77
    FDB 16    ; angle 78
    FDB 18    ; angle 79
    FDB 20    ; angle 80
    FDB 22    ; angle 81
    FDB 24    ; angle 82
    FDB 27    ; angle 83
    FDB 30    ; angle 84
    FDB 33    ; angle 85
    FDB 37    ; angle 86
    FDB 42    ; angle 87
    FDB 48    ; angle 88
    FDB 56    ; angle 89
    FDB 66    ; angle 90
    FDB 80    ; angle 91
    FDB 101    ; angle 92
    FDB 120    ; angle 93
    FDB 120    ; angle 94
    FDB 120    ; angle 95
    FDB -120    ; angle 96
    FDB -120    ; angle 97
    FDB -120    ; angle 98
    FDB -120    ; angle 99
    FDB -101    ; angle 100
    FDB -80    ; angle 101
    FDB -66    ; angle 102
    FDB -56    ; angle 103
    FDB -48    ; angle 104
    FDB -42    ; angle 105
    FDB -37    ; angle 106
    FDB -33    ; angle 107
    FDB -30    ; angle 108
    FDB -27    ; angle 109
    FDB -24    ; angle 110
    FDB -22    ; angle 111
    FDB -20    ; angle 112
    FDB -18    ; angle 113
    FDB -16    ; angle 114
    FDB -15    ; angle 115
    FDB -13    ; angle 116
    FDB -12    ; angle 117
    FDB -11    ; angle 118
    FDB -9    ; angle 119
    FDB -8    ; angle 120
    FDB -7    ; angle 121
    FDB -6    ; angle 122
    FDB -5    ; angle 123
    FDB -4    ; angle 124
    FDB -3    ; angle 125
    FDB -2    ; angle 126
    FDB -1    ; angle 127

;**** PRINT_TEXT String Data ****
PRINT_TEXT_STR_2902307913:
    FCC "benchy"
    FCB $80          ; Vectrex string terminator

;***************************************************************************
; 3D COMPACT DATA TABLES (for DRAW_VECTOR_3D)
;***************************************************************************


; 3D data table for DRAW_VECTOR_3D
_BENCHY_3D_DATA:
    FCB 132               ; path count
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $F5,$2A,$FE          ; x=-11,y=42,z=-2
    FCB $F5,$20,$FE          ; x=-11,y=32,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $F5,$2A,$FE          ; x=-11,y=42,z=-2
    FCB $F5,$2A,$02          ; x=-11,y=42,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $F5,$2A,$FE          ; x=-11,y=42,z=-2
    FCB $EB,$2A,$FE          ; x=-21,y=42,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $F5,$20,$FE          ; x=-11,y=32,z=-2
    FCB $F5,$20,$02          ; x=-11,y=32,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $F5,$20,$FE          ; x=-11,y=32,z=-2
    FCB $EB,$20,$FE          ; x=-21,y=32,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $F5,$2A,$02          ; x=-11,y=42,z=2
    FCB $F5,$20,$02          ; x=-11,y=32,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $F5,$2A,$02          ; x=-11,y=42,z=2
    FCB $EB,$2A,$02          ; x=-21,y=42,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $F5,$20,$02          ; x=-11,y=32,z=2
    FCB $EB,$20,$02          ; x=-21,y=32,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $EB,$2A,$FE          ; x=-21,y=42,z=-2
    FCB $EB,$2A,$02          ; x=-21,y=42,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $EB,$2A,$FE          ; x=-21,y=42,z=-2
    FCB $EB,$20,$FE          ; x=-21,y=32,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $EB,$2A,$02          ; x=-21,y=42,z=2
    FCB $EB,$20,$02          ; x=-21,y=32,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $EB,$20,$FE          ; x=-21,y=32,z=-2
    FCB $EB,$20,$02          ; x=-21,y=32,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $E5,$EF,$FE          ; x=-27,y=-17,z=-2
    FCB $F1,$EF,$FE          ; x=-15,y=-17,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $E5,$EF,$FE          ; x=-27,y=-17,z=-2
    FCB $E5,$EF,$02          ; x=-27,y=-17,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $E5,$EF,$FE          ; x=-27,y=-17,z=-2
    FCB $E5,$F9,$FE          ; x=-27,y=-7,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $F1,$EF,$FE          ; x=-15,y=-17,z=-2
    FCB $F1,$EF,$02          ; x=-15,y=-17,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $F1,$EF,$FE          ; x=-15,y=-17,z=-2
    FCB $F1,$06,$FE          ; x=-15,y=6,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $E5,$EF,$02          ; x=-27,y=-17,z=2
    FCB $F1,$EF,$02          ; x=-15,y=-17,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $E5,$EF,$02          ; x=-27,y=-17,z=2
    FCB $E5,$F9,$02          ; x=-27,y=-7,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $F1,$EF,$02          ; x=-15,y=-17,z=2
    FCB $F1,$06,$02          ; x=-15,y=6,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $E5,$F9,$FE          ; x=-27,y=-7,z=-2
    FCB $E5,$F9,$02          ; x=-27,y=-7,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $E5,$F9,$FE          ; x=-27,y=-7,z=-2
    FCB $DC,$F9,$FE          ; x=-36,y=-7,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $E5,$F9,$02          ; x=-27,y=-7,z=2
    FCB $DC,$F9,$02          ; x=-36,y=-7,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $DC,$F9,$FE          ; x=-36,y=-7,z=-2
    FCB $DC,$F9,$02          ; x=-36,y=-7,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $DC,$F9,$FE          ; x=-36,y=-7,z=-2
    FCB $DC,$1A,$FE          ; x=-36,y=26,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $DC,$F9,$02          ; x=-36,y=-7,z=2
    FCB $DC,$1A,$02          ; x=-36,y=26,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $DC,$1A,$FE          ; x=-36,y=26,z=-2
    FCB $DC,$1A,$02          ; x=-36,y=26,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $DC,$1A,$FE          ; x=-36,y=26,z=-2
    FCB $E6,$1A,$FE          ; x=-26,y=26,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $DC,$1A,$02          ; x=-36,y=26,z=2
    FCB $E6,$1A,$02          ; x=-26,y=26,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $E6,$1A,$FE          ; x=-26,y=26,z=-2
    FCB $E6,$1A,$02          ; x=-26,y=26,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $E6,$1A,$FE          ; x=-26,y=26,z=-2
    FCB $E6,$2F,$FE          ; x=-26,y=47,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $E6,$1A,$02          ; x=-26,y=26,z=2
    FCB $E6,$2F,$02          ; x=-26,y=47,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $E6,$2F,$FE          ; x=-26,y=47,z=-2
    FCB $E6,$2F,$02          ; x=-26,y=47,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $E6,$2F,$FE          ; x=-26,y=47,z=-2
    FCB $07,$2F,$FE          ; x=7,y=47,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $E6,$2F,$02          ; x=-26,y=47,z=2
    FCB $07,$2F,$02          ; x=7,y=47,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $07,$2F,$FE          ; x=7,y=47,z=-2
    FCB $07,$2F,$02          ; x=7,y=47,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $07,$2F,$FE          ; x=7,y=47,z=-2
    FCB $07,$1A,$FE          ; x=7,y=26,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $07,$2F,$02          ; x=7,y=47,z=2
    FCB $07,$1A,$02          ; x=7,y=26,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $07,$1A,$FE          ; x=7,y=26,z=-2
    FCB $07,$1A,$02          ; x=7,y=26,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $07,$1A,$FE          ; x=7,y=26,z=-2
    FCB $11,$1A,$FE          ; x=17,y=26,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $07,$1A,$02          ; x=7,y=26,z=2
    FCB $11,$1A,$02          ; x=17,y=26,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $11,$1A,$FE          ; x=17,y=26,z=-2
    FCB $11,$1A,$02          ; x=17,y=26,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $11,$1A,$FE          ; x=17,y=26,z=-2
    FCB $11,$0F,$FE          ; x=17,y=15,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $11,$1A,$02          ; x=17,y=26,z=2
    FCB $11,$0F,$02          ; x=17,y=15,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $11,$0F,$FE          ; x=17,y=15,z=-2
    FCB $11,$0F,$02          ; x=17,y=15,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $11,$0F,$FE          ; x=17,y=15,z=-2
    FCB $FB,$0F,$FE          ; x=-5,y=15,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $11,$0F,$02          ; x=17,y=15,z=2
    FCB $FB,$0F,$02          ; x=-5,y=15,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $FB,$0F,$FE          ; x=-5,y=15,z=-2
    FCB $FB,$0F,$02          ; x=-5,y=15,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $FB,$0F,$FE          ; x=-5,y=15,z=-2
    FCB $FB,$06,$FE          ; x=-5,y=6,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $FB,$0F,$02          ; x=-5,y=15,z=2
    FCB $FB,$06,$02          ; x=-5,y=6,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $FB,$06,$FE          ; x=-5,y=6,z=-2
    FCB $FB,$06,$02          ; x=-5,y=6,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $FB,$06,$FE          ; x=-5,y=6,z=-2
    FCB $F1,$06,$FE          ; x=-15,y=6,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $FB,$06,$02          ; x=-5,y=6,z=2
    FCB $F1,$06,$02          ; x=-15,y=6,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $F1,$06,$FE          ; x=-15,y=6,z=-2
    FCB $F1,$06,$02          ; x=-15,y=6,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $0F,$0D,$FE          ; x=15,y=13,z=-2
    FCB $FD,$0D,$FE          ; x=-3,y=13,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $0F,$0D,$FE          ; x=15,y=13,z=-2
    FCB $0F,$0D,$02          ; x=15,y=13,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $0F,$0D,$FE          ; x=15,y=13,z=-2
    FCB $0F,$FA,$FE          ; x=15,y=-6,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $FD,$0D,$FE          ; x=-3,y=13,z=-2
    FCB $FD,$0D,$02          ; x=-3,y=13,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $FD,$0D,$FE          ; x=-3,y=13,z=-2
    FCB $FD,$04,$FE          ; x=-3,y=4,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $0F,$0D,$02          ; x=15,y=13,z=2
    FCB $FD,$0D,$02          ; x=-3,y=13,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $0F,$0D,$02          ; x=15,y=13,z=2
    FCB $0F,$FA,$02          ; x=15,y=-6,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $FD,$0D,$02          ; x=-3,y=13,z=2
    FCB $FD,$04,$02          ; x=-3,y=4,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $0F,$FA,$FE          ; x=15,y=-6,z=-2
    FCB $0F,$FA,$02          ; x=15,y=-6,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $0F,$FA,$FE          ; x=15,y=-6,z=-2
    FCB $05,$FA,$FE          ; x=5,y=-6,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $0F,$FA,$02          ; x=15,y=-6,z=2
    FCB $05,$FA,$02          ; x=5,y=-6,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $05,$FA,$FE          ; x=5,y=-6,z=-2
    FCB $05,$FA,$02          ; x=5,y=-6,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $05,$FA,$FE          ; x=5,y=-6,z=-2
    FCB $05,$F1,$FE          ; x=5,y=-15,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $05,$FA,$02          ; x=5,y=-6,z=2
    FCB $05,$F1,$02          ; x=5,y=-15,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $05,$F1,$FE          ; x=5,y=-15,z=-2
    FCB $05,$F1,$02          ; x=5,y=-15,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $05,$F1,$FE          ; x=5,y=-15,z=-2
    FCB $F3,$F1,$FE          ; x=-13,y=-15,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $05,$F1,$02          ; x=5,y=-15,z=2
    FCB $F3,$F1,$02          ; x=-13,y=-15,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $F3,$F1,$FE          ; x=-13,y=-15,z=-2
    FCB $F3,$F1,$02          ; x=-13,y=-15,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $F3,$F1,$FE          ; x=-13,y=-15,z=-2
    FCB $F3,$04,$FE          ; x=-13,y=4,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $F3,$F1,$02          ; x=-13,y=-15,z=2
    FCB $F3,$04,$02          ; x=-13,y=4,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $F3,$04,$FE          ; x=-13,y=4,z=-2
    FCB $F3,$04,$02          ; x=-13,y=4,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $F3,$04,$FE          ; x=-13,y=4,z=-2
    FCB $FD,$04,$FE          ; x=-3,y=4,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $F3,$04,$02          ; x=-13,y=4,z=2
    FCB $FD,$04,$02          ; x=-3,y=4,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $FD,$04,$FE          ; x=-3,y=4,z=-2
    FCB $FD,$04,$02          ; x=-3,y=4,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $17,$D4,$FE          ; x=23,y=-44,z=-2
    FCB $0D,$D4,$FE          ; x=13,y=-44,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $17,$D4,$FE          ; x=23,y=-44,z=-2
    FCB $17,$D4,$02          ; x=23,y=-44,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $17,$D4,$FE          ; x=23,y=-44,z=-2
    FCB $17,$DE,$FE          ; x=23,y=-34,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $0D,$D4,$FE          ; x=13,y=-44,z=-2
    FCB $0D,$D4,$02          ; x=13,y=-44,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $0D,$D4,$FE          ; x=13,y=-44,z=-2
    FCB $0D,$DE,$FE          ; x=13,y=-34,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $17,$D4,$02          ; x=23,y=-44,z=2
    FCB $0D,$D4,$02          ; x=13,y=-44,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $17,$D4,$02          ; x=23,y=-44,z=2
    FCB $17,$DE,$02          ; x=23,y=-34,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $0D,$D4,$02          ; x=13,y=-44,z=2
    FCB $0D,$DE,$02          ; x=13,y=-34,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $17,$DE,$FE          ; x=23,y=-34,z=-2
    FCB $17,$DE,$02          ; x=23,y=-34,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $17,$DE,$FE          ; x=23,y=-34,z=-2
    FCB $0D,$DE,$FE          ; x=13,y=-34,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $17,$DE,$02          ; x=23,y=-34,z=2
    FCB $0D,$DE,$02          ; x=13,y=-34,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $0D,$DE,$FE          ; x=13,y=-34,z=-2
    FCB $0D,$DE,$02          ; x=13,y=-34,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $FD,$D1,$FE          ; x=-3,y=-47,z=-2
    FCB $1A,$D1,$FE          ; x=26,y=-47,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $FD,$D1,$FE          ; x=-3,y=-47,z=-2
    FCB $FD,$D1,$02          ; x=-3,y=-47,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $FD,$D1,$FE          ; x=-3,y=-47,z=-2
    FCB $FD,$E6,$FE          ; x=-3,y=-26,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $1A,$D1,$FE          ; x=26,y=-47,z=-2
    FCB $1A,$D1,$02          ; x=26,y=-47,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $1A,$D1,$FE          ; x=26,y=-47,z=-2
    FCB $1A,$E6,$FE          ; x=26,y=-26,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $FD,$D1,$02          ; x=-3,y=-47,z=2
    FCB $1A,$D1,$02          ; x=26,y=-47,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $FD,$D1,$02          ; x=-3,y=-47,z=2
    FCB $FD,$E6,$02          ; x=-3,y=-26,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $1A,$D1,$02          ; x=26,y=-47,z=2
    FCB $1A,$E6,$02          ; x=26,y=-26,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $FD,$E6,$FE          ; x=-3,y=-26,z=-2
    FCB $FD,$E6,$02          ; x=-3,y=-26,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $FD,$E6,$FE          ; x=-3,y=-26,z=-2
    FCB $F3,$E6,$FE          ; x=-13,y=-26,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $FD,$E6,$02          ; x=-3,y=-26,z=2
    FCB $F3,$E6,$02          ; x=-13,y=-26,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $F3,$E6,$FE          ; x=-13,y=-26,z=-2
    FCB $F3,$E6,$02          ; x=-13,y=-26,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $F3,$E6,$FE          ; x=-13,y=-26,z=-2
    FCB $F3,$EF,$FE          ; x=-13,y=-17,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $F3,$E6,$02          ; x=-13,y=-26,z=2
    FCB $F3,$EF,$02          ; x=-13,y=-17,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $F3,$EF,$FE          ; x=-13,y=-17,z=-2
    FCB $F3,$EF,$02          ; x=-13,y=-17,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $F3,$EF,$FE          ; x=-13,y=-17,z=-2
    FCB $07,$EF,$FE          ; x=7,y=-17,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $F3,$EF,$02          ; x=-13,y=-17,z=2
    FCB $07,$EF,$02          ; x=7,y=-17,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $07,$EF,$FE          ; x=7,y=-17,z=-2
    FCB $07,$EF,$02          ; x=7,y=-17,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $07,$EF,$FE          ; x=7,y=-17,z=-2
    FCB $07,$F9,$FE          ; x=7,y=-7,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $07,$EF,$02          ; x=7,y=-17,z=2
    FCB $07,$F9,$02          ; x=7,y=-7,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $07,$F9,$FE          ; x=7,y=-7,z=-2
    FCB $07,$F9,$02          ; x=7,y=-7,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $07,$F9,$FE          ; x=7,y=-7,z=-2
    FCB $11,$F9,$FE          ; x=17,y=-7,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $07,$F9,$02          ; x=7,y=-7,z=2
    FCB $11,$F9,$02          ; x=17,y=-7,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $11,$F9,$FE          ; x=17,y=-7,z=-2
    FCB $11,$F9,$02          ; x=17,y=-7,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $11,$F9,$FE          ; x=17,y=-7,z=-2
    FCB $11,$0D,$FE          ; x=17,y=13,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $11,$F9,$02          ; x=17,y=-7,z=2
    FCB $11,$0D,$02          ; x=17,y=13,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $11,$0D,$FE          ; x=17,y=13,z=-2
    FCB $11,$0D,$02          ; x=17,y=13,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $11,$0D,$FE          ; x=17,y=13,z=-2
    FCB $1B,$0D,$FE          ; x=27,y=13,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $11,$0D,$02          ; x=17,y=13,z=2
    FCB $1B,$0D,$02          ; x=27,y=13,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $1B,$0D,$FE          ; x=27,y=13,z=-2
    FCB $1B,$0D,$02          ; x=27,y=13,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $1B,$0D,$FE          ; x=27,y=13,z=-2
    FCB $1B,$04,$FE          ; x=27,y=4,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $1B,$0D,$02          ; x=27,y=13,z=2
    FCB $1B,$04,$02          ; x=27,y=4,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $1B,$04,$FE          ; x=27,y=4,z=-2
    FCB $1B,$04,$02          ; x=27,y=4,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $1B,$04,$FE          ; x=27,y=4,z=-2
    FCB $24,$04,$FE          ; x=36,y=4,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $1B,$04,$02          ; x=27,y=4,z=2
    FCB $24,$04,$02          ; x=36,y=4,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $24,$04,$FE          ; x=36,y=4,z=-2
    FCB $24,$04,$02          ; x=36,y=4,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $24,$04,$FE          ; x=36,y=4,z=-2
    FCB $24,$E6,$FE          ; x=36,y=-26,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $24,$04,$02          ; x=36,y=4,z=2
    FCB $24,$E6,$02          ; x=36,y=-26,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $24,$E6,$FE          ; x=36,y=-26,z=-2
    FCB $24,$E6,$02          ; x=36,y=-26,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $24,$E6,$FE          ; x=36,y=-26,z=-2
    FCB $1A,$E6,$FE          ; x=26,y=-26,z=-2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $24,$E6,$02          ; x=36,y=-26,z=2
    FCB $1A,$E6,$02          ; x=26,y=-26,z=2
    FCB 2               ; point count
    FCB 0               ; closed flag
    FCB $1A,$E6,$FE          ; x=26,y=-26,z=-2
    FCB $1A,$E6,$02          ; x=26,y=-26,z=2
