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
    FCC "Vectrex 3D Logo"
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
ROT3D_COS_X          EQU $C880+$27   ; 3D cos angle offset for X axis: (AX+32)&0x7F (1 bytes)
ROT3D_COS_Y          EQU $C880+$28   ; 3D cos angle offset for Y axis: (AY+32)&0x7F (1 bytes)
ROT3D_COS_Z          EQU $C880+$29   ; 3D cos angle offset for Z axis: (AZ+32)&0x7F (1 bytes)
ROT3D_OX             EQU $C880+$2A   ; 3D draw X offset (1 bytes)
ROT3D_OY             EQU $C880+$2B   ; 3D draw Y offset (1 bytes)
ROT3D_PC             EQU $C880+$2C   ; 3D path/vertex count remaining (1 bytes)
ROT3D_PT_REM         EQU $C880+$2D   ; 3D remaining points in current path (1 bytes)
ROT3D_CLOSED         EQU $C880+$2E   ; 3D path closed flag (1 bytes)
ROT3D_RX             EQU $C880+$2F   ; 3D raw x (1 bytes)
ROT3D_RY             EQU $C880+$30   ; 3D raw y (1 bytes)
ROT3D_RZ             EQU $C880+$31   ; 3D raw z (1 bytes)
ROT3D_Y1             EQU $C880+$32   ; 3D intermediate y after X-axis rotation (1 bytes)
ROT3D_Z1             EQU $C880+$33   ; 3D intermediate z after X-axis rotation (1 bytes)
ROT3D_X2             EQU $C880+$34   ; 3D intermediate x after Y-axis rotation (1 bytes)
ROT3D_SCR_X          EQU $C880+$35   ; 3D final screen x (1 bytes)
ROT3D_SCR_Y          EQU $C880+$36   ; 3D final screen y (1 bytes)
ROT3D_PREV_X         EQU $C880+$37   ; 3D previous screen x (1 bytes)
ROT3D_PREV_Y         EQU $C880+$38   ; 3D previous screen y (1 bytes)
ROT3D_FIRST_X        EQU $C880+$39   ; 3D first screen x (for closed path) (1 bytes)
ROT3D_FIRST_Y        EQU $C880+$3A   ; 3D first screen y (for closed path) (1 bytes)
ROT3D_TEMP           EQU $C880+$3B   ; 3D rotation temp 1 (1 bytes)
ROT3D_TEMP2          EQU $C880+$3C   ; 3D rotation temp 2 (1 bytes)
ROT3D_VBUF           EQU $C880+$3D   ; 3D rotated vertex cache (127 verts × 2 bytes: x',y') (254 bytes)
DRAW_LINE_ARGS       EQU $C880+$13B   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$145   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$147   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$149   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$14A   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$14B   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$14D   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
DRAW_SCALE           EQU $C880+$14F   ; Current T1 scale for Draw_Sync_List_At_With_Mirrors ($7F=normal) (1 bytes)
VAR_ROT_X            EQU $C880+$150   ; User variable: rot_x (2 bytes)
VAR_ROT_Y            EQU $C880+$152   ; User variable: rot_y (2 bytes)
VAR_ROT_Z            EQU $C880+$154   ; User variable: rot_z (2 bytes)
VAR_ROT_SPEED_X      EQU $C880+$156   ; User variable: rot_speed_x (2 bytes)
VAR_ROT_SPEED_Y      EQU $C880+$158   ; User variable: rot_speed_y (2 bytes)
VAR_ROT_SPEED_Z      EQU $C880+$15A   ; User variable: rot_speed_z (2 bytes)
VAR_JOY_X            EQU $C880+$15C   ; User variable: joy_x (2 bytes)
VAR_JOY_Y            EQU $C880+$15E   ; User variable: joy_y (2 bytes)
VAR_ARG0             EQU $CB80   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $CB82   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $CB84   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $CB86   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $CB88   ; Function argument 4 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $CB8A   ; Current ROM bank ID (multibank tracking) (1 bytes)

;***************************************************************************
; MAIN PROGRAM
;***************************************************************************

MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    LDD #0
    STD VAR_ROT_X
    LDD #0
    STD VAR_ROT_Y
    LDD #0
    STD VAR_ROT_Z
    LDD #1
    STD VAR_ROT_SPEED_X
    LDD #2
    STD VAR_ROT_SPEED_Y
    LDD #1
    STD VAR_ROT_SPEED_Z
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
    ; TODO: Statement Pass { source_line: 14 }
    CLR >$C811  ; Force-clear Vec_Buttons before first loop() frame

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    LDD >VAR_ROT_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_ROT_SPEED_X
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ROT_X
    LDD >VAR_ROT_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_ROT_SPEED_Y
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ROT_Y
    LDD >VAR_ROT_Z
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_ROT_SPEED_Z
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ROT_Z
    LDD #256
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ROT_X
    CMPD TMPVAL
    LBGE .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_1
    LDD >VAR_ROT_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #256
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_ROT_X
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    LDD #256
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ROT_Y
    CMPD TMPVAL
    LBGE .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    LBEQ IF_NEXT_3
    LDD >VAR_ROT_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #256
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_ROT_Y
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LDD #256
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ROT_Z
    CMPD TMPVAL
    LBGE .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    LBEQ IF_NEXT_5
    LDD >VAR_ROT_Z
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #256
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_ROT_Z
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    JSR J1X_BUILTIN
    STD RESULT
    STD VAR_JOY_X
    JSR J1Y_BUILTIN
    STD RESULT
    STD VAR_JOY_Y
    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed
    BITA #$01
    BNE .J1B1_0_ON
    LDD #0
    BRA .J1B1_0_END
.J1B1_0_ON:
    LDD #1
.J1B1_0_END:
    STD RESULT
    LBEQ IF_NEXT_7
    LDD >VAR_ROT_SPEED_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ROT_SPEED_X
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
    LDA >$C80F   ; Vec_Btns_1: bit1=1 means btn2 pressed
    BITA #$02
    BNE .J1B2_1_ON
    LDD #0
    BRA .J1B2_1_END
.J1B2_1_ON:
    LDD #1
.J1B2_1_END:
    STD RESULT
    LBEQ IF_NEXT_9
    ; CLAMP: Clamp value to range [min, max]
    LDD >VAR_ROT_SPEED_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD TMPPTR     ; Save value
    LDD #0
    STD TMPPTR+2   ; Save min
    LDD #10
    STD TMPPTR+4   ; Save max
    LDD TMPPTR     ; Load value
    CMPD TMPPTR+2  ; Compare with min
    BGE .CLAMP_0_CHK_MAX ; Branch if value >= min
    LDD TMPPTR+2
    STD RESULT
    BRA .CLAMP_0_END
.CLAMP_0_CHK_MAX:
    LDD TMPPTR     ; Load value again
    CMPD TMPPTR+4  ; Compare with max
    BLE .CLAMP_0_OK  ; Branch if value <= max
    LDD TMPPTR+4
    STD RESULT
    BRA .CLAMP_0_END
.CLAMP_0_OK:
    LDD TMPPTR
    STD RESULT
.CLAMP_0_END:
    STD VAR_ROT_SPEED_X
    LBRA IF_END_8
IF_NEXT_9:
IF_END_8:
    LDA >$C80F   ; Vec_Btns_1: bit2=1 means btn3 pressed
    BITA #$04
    BNE .J1B3_2_ON
    LDD #0
    BRA .J1B3_2_END
.J1B3_2_ON:
    LDD #1
.J1B3_2_END:
    STD RESULT
    LBEQ IF_NEXT_11
    LDD >VAR_ROT_SPEED_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ROT_SPEED_Y
    LBRA IF_END_10
IF_NEXT_11:
IF_END_10:
    LDA >$C80F   ; Vec_Btns_1: bit3=1 means btn4 pressed
    BITA #$08
    BNE .J1B4_3_ON
    LDD #0
    BRA .J1B4_3_END
.J1B4_3_ON:
    LDD #1
.J1B4_3_END:
    STD RESULT
    LBEQ IF_NEXT_13
    ; CLAMP: Clamp value to range [min, max]
    LDD >VAR_ROT_SPEED_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD TMPPTR     ; Save value
    LDD #0
    STD TMPPTR+2   ; Save min
    LDD #10
    STD TMPPTR+4   ; Save max
    LDD TMPPTR     ; Load value
    CMPD TMPPTR+2  ; Compare with min
    BGE .CLAMP_1_CHK_MAX ; Branch if value >= min
    LDD TMPPTR+2
    STD RESULT
    BRA .CLAMP_1_END
.CLAMP_1_CHK_MAX:
    LDD TMPPTR     ; Load value again
    CMPD TMPPTR+4  ; Compare with max
    BLE .CLAMP_1_OK  ; Branch if value <= max
    LDD TMPPTR+4
    STD RESULT
    BRA .CLAMP_1_END
.CLAMP_1_OK:
    LDD TMPPTR
    STD RESULT
.CLAMP_1_END:
    STD VAR_ROT_SPEED_Y
    LBRA IF_END_12
IF_NEXT_13:
IF_END_12:
    ; DRAW_VECTOR_3D: Draw vector asset with 3D rotation
    ; Asset: logo (3D rotation)
    LDD >VAR_ROT_X
    STB >ROT3D_AX       ; angle X (0-127)
    LDD >VAR_ROT_Y
    STB >ROT3D_AY       ; angle Y (0-127)
    LDD >VAR_ROT_Z
    STB >ROT3D_AZ       ; angle Z (0-127)
    LDD #0
    STB >ROT3D_OX       ; screen X offset
    LDD #0
    STB >ROT3D_OY       ; screen Y offset
    LDX #_LOGO_3D_DATA  ; pointer to 3D data table
    JSR DRAW_VECTOR_3D_RUNTIME
    LDD #0
    STD RESULT
    RTS

;***************************************************************************
; EMBEDDED ASSETS (vectors, music, levels, SFX)
;***************************************************************************

; Generated from logo.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 13
; X bounds: min=-34, max=12, width=46
; Center: (-11, 40)

_LOGO_WIDTH EQU 46
_LOGO_HALF_WIDTH EQU 23
_LOGO_HEIGHT EQU 50
_LOGO_HALF_HEIGHT EQU 25
_LOGO_CENTER_X EQU -11
_LOGO_CENTER_Y EQU 40

_LOGO_VECTORS:  ; Main entry (header + 1 path(s))
    FDB 1               ; path_count (runtime metadata, 2 bytes)
    FDB _LOGO_PATH0        ; pointer to path 0

_LOGO_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $41,$E9,0,0        ; path0: header (y=65, x=-23)
    FCB $FF,$F1,$00          ; flag=-1, dy=-15, dx=0
    FCB $FF,$00,$F5          ; flag=-1, dy=0, dx=-11
    FCB $FF,$E5,$00          ; flag=-1, dy=-27, dx=0
    FCB $FF,$00,$0B          ; flag=-1, dy=0, dx=11
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$1A          ; flag=-1, dy=0, dx=26
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB $FF,$1C,$00          ; flag=-1, dy=28, dx=0
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB $FF,$0F,$00          ; flag=-1, dy=15, dx=0
    FCB $FF,$00,$E6          ; flag=-1, dy=0, dx=-26
    FCB 2                ; End marker (path complete)
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
; ============================================================================
; SMUL_PROD - Product lookup table for SMUL_LUT
; SMUL_PROD[val][angle] = (val * sin(angle*2π/128)) >> 7  (i8)
; val=row (0-63, stride=128), angle=col (0-127) — 8KB total
; For cos: use angle=(ax+32)&0x7F — same table, shifted column
; Vertex coords must be ≤63 (clamped at data emit time)
SMUL_PROD:
    FCB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; val=0
    FCB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; val=1
    FCB $00,$00,$00,$00,$00,$00,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00  ; val=2
    FCB $00,$00,$00,$00,$01,$01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$01,$01,$01,$01,$01,$01,$01,$00,$00,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00  ; val=3
    FCB $00,$00,$00,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$03,$03,$03,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$03,$03,$03,$03,$03,$03,$03,$03,$02,$02,$02,$02,$02,$02,$01,$01,$01,$01,$01,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FE,$FE,$FE,$FE,$FE,$FE,$FF,$FF,$FF,$FF,$FF,$00,$00  ; val=4
    FCB $00,$00,$00,$01,$01,$01,$01,$02,$02,$02,$02,$03,$03,$03,$03,$03,$04,$04,$04,$04,$04,$04,$04,$04,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$04,$04,$04,$04,$04,$04,$04,$04,$03,$03,$03,$03,$03,$02,$02,$02,$02,$01,$01,$01,$01,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FD,$FD,$FD,$FD,$FD,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FD,$FD,$FD,$FD,$FD,$FE,$FE,$FE,$FE,$FF,$FF,$FF,$FF,$00,$00  ; val=5
    FCB $00,$00,$01,$01,$01,$01,$02,$02,$02,$03,$03,$03,$03,$04,$04,$04,$04,$04,$05,$05,$05,$05,$05,$05,$05,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$05,$05,$05,$05,$05,$05,$05,$04,$04,$04,$04,$04,$03,$03,$03,$03,$02,$02,$02,$01,$01,$01,$01,$00,$00,$00,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FD,$FD,$FD,$FD,$FC,$FC,$FC,$FC,$FC,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FA,$FA,$FA,$FA,$FA,$FA,$FA,$FA,$FA,$FA,$FA,$FA,$FA,$FA,$FA,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FC,$FC,$FC,$FC,$FC,$FD,$FD,$FD,$FD,$FE,$FE,$FE,$FF,$FF,$FF,$FF,$00  ; val=6
    FCB $00,$00,$01,$01,$01,$02,$02,$02,$03,$03,$03,$04,$04,$04,$04,$05,$05,$05,$05,$06,$06,$06,$06,$06,$06,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$06,$06,$06,$06,$06,$06,$05,$05,$05,$05,$04,$04,$04,$04,$03,$03,$03,$02,$02,$02,$01,$01,$01,$00,$00,$00,$FF,$FF,$FF,$FE,$FE,$FE,$FD,$FD,$FD,$FC,$FC,$FC,$FC,$FB,$FB,$FB,$FB,$FA,$FA,$FA,$FA,$FA,$FA,$F9,$F9,$F9,$F9,$F9,$F9,$F9,$F9,$F9,$F9,$F9,$F9,$F9,$F9,$F9,$FA,$FA,$FA,$FA,$FA,$FA,$FB,$FB,$FB,$FB,$FC,$FC,$FC,$FC,$FD,$FD,$FD,$FE,$FE,$FE,$FF,$FF,$FF,$00  ; val=7
    FCB $00,$00,$01,$01,$02,$02,$02,$03,$03,$03,$04,$04,$04,$05,$05,$05,$06,$06,$06,$06,$07,$07,$07,$07,$07,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$07,$07,$07,$07,$07,$06,$06,$06,$06,$05,$05,$05,$04,$04,$04,$03,$03,$03,$02,$02,$02,$01,$01,$00,$00,$00,$FF,$FF,$FE,$FE,$FE,$FD,$FD,$FD,$FC,$FC,$FC,$FB,$FB,$FB,$FA,$FA,$FA,$FA,$F9,$F9,$F9,$F9,$F9,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F9,$F9,$F9,$F9,$F9,$FA,$FA,$FA,$FA,$FB,$FB,$FB,$FC,$FC,$FC,$FD,$FD,$FD,$FE,$FE,$FE,$FF,$FF,$00  ; val=8
    FCB $00,$00,$01,$01,$02,$02,$03,$03,$03,$04,$04,$05,$05,$05,$06,$06,$06,$07,$07,$07,$07,$08,$08,$08,$08,$08,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$08,$08,$08,$08,$08,$07,$07,$07,$07,$06,$06,$06,$05,$05,$05,$04,$04,$03,$03,$03,$02,$02,$01,$01,$00,$00,$00,$FF,$FF,$FE,$FE,$FD,$FD,$FD,$FC,$FC,$FB,$FB,$FB,$FA,$FA,$FA,$F9,$F9,$F9,$F9,$F8,$F8,$F8,$F8,$F8,$F7,$F7,$F7,$F7,$F7,$F7,$F7,$F7,$F7,$F7,$F7,$F7,$F7,$F8,$F8,$F8,$F8,$F8,$F9,$F9,$F9,$F9,$FA,$FA,$FA,$FB,$FB,$FB,$FC,$FC,$FD,$FD,$FD,$FE,$FE,$FF,$FF,$00  ; val=9
    FCB $00,$00,$01,$01,$02,$02,$03,$03,$04,$04,$05,$05,$06,$06,$06,$07,$07,$07,$08,$08,$08,$09,$09,$09,$09,$09,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$09,$09,$09,$09,$09,$08,$08,$08,$07,$07,$07,$06,$06,$06,$05,$05,$04,$04,$03,$03,$02,$02,$01,$01,$00,$00,$00,$FF,$FF,$FE,$FE,$FD,$FD,$FC,$FC,$FB,$FB,$FA,$FA,$FA,$F9,$F9,$F9,$F8,$F8,$F8,$F7,$F7,$F7,$F7,$F7,$F6,$F6,$F6,$F6,$F6,$F6,$F6,$F6,$F6,$F6,$F6,$F6,$F6,$F7,$F7,$F7,$F7,$F7,$F8,$F8,$F8,$F9,$F9,$F9,$FA,$FA,$FA,$FB,$FB,$FC,$FC,$FD,$FD,$FE,$FE,$FF,$FF,$00  ; val=10
    FCB $00,$01,$01,$02,$02,$03,$03,$04,$04,$05,$05,$06,$06,$07,$07,$07,$08,$08,$08,$09,$09,$09,$0A,$0A,$0A,$0A,$0A,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0A,$0A,$0A,$0A,$0A,$09,$09,$09,$08,$08,$08,$07,$07,$07,$06,$06,$05,$05,$04,$04,$03,$03,$02,$02,$01,$01,$00,$FF,$FF,$FE,$FE,$FD,$FD,$FC,$FC,$FB,$FB,$FA,$FA,$F9,$F9,$F9,$F8,$F8,$F8,$F7,$F7,$F7,$F6,$F6,$F6,$F6,$F6,$F5,$F5,$F5,$F5,$F5,$F5,$F5,$F5,$F5,$F5,$F5,$F6,$F6,$F6,$F6,$F6,$F7,$F7,$F7,$F8,$F8,$F8,$F9,$F9,$F9,$FA,$FA,$FB,$FB,$FC,$FC,$FD,$FD,$FE,$FE,$FF,$FF  ; val=11
    FCB $00,$01,$01,$02,$02,$03,$03,$04,$05,$05,$06,$06,$07,$07,$08,$08,$08,$09,$09,$0A,$0A,$0A,$0B,$0B,$0B,$0B,$0B,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0B,$0B,$0B,$0B,$0B,$0A,$0A,$0A,$09,$09,$08,$08,$08,$07,$07,$06,$06,$05,$05,$04,$03,$03,$02,$02,$01,$01,$00,$FF,$FF,$FE,$FE,$FD,$FD,$FC,$FB,$FB,$FA,$FA,$F9,$F9,$F8,$F8,$F8,$F7,$F7,$F6,$F6,$F6,$F5,$F5,$F5,$F5,$F5,$F4,$F4,$F4,$F4,$F4,$F4,$F4,$F4,$F4,$F4,$F4,$F5,$F5,$F5,$F5,$F5,$F6,$F6,$F6,$F7,$F7,$F8,$F8,$F8,$F9,$F9,$FA,$FA,$FB,$FB,$FC,$FD,$FD,$FE,$FE,$FF,$FF  ; val=12
    FCB $00,$01,$01,$02,$03,$03,$04,$04,$05,$05,$06,$07,$07,$08,$08,$09,$09,$0A,$0A,$0A,$0B,$0B,$0B,$0C,$0C,$0C,$0C,$0C,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0C,$0C,$0C,$0C,$0C,$0B,$0B,$0B,$0A,$0A,$0A,$09,$09,$08,$08,$07,$07,$06,$05,$05,$04,$04,$03,$03,$02,$01,$01,$00,$FF,$FF,$FE,$FD,$FD,$FC,$FC,$FB,$FB,$FA,$F9,$F9,$F8,$F8,$F7,$F7,$F6,$F6,$F6,$F5,$F5,$F5,$F4,$F4,$F4,$F4,$F4,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F4,$F4,$F4,$F4,$F4,$F5,$F5,$F5,$F6,$F6,$F6,$F7,$F7,$F8,$F8,$F9,$F9,$FA,$FB,$FB,$FC,$FC,$FD,$FD,$FE,$FF,$FF  ; val=13
    FCB $00,$01,$01,$02,$03,$03,$04,$05,$05,$06,$07,$07,$08,$08,$09,$09,$0A,$0A,$0B,$0B,$0C,$0C,$0C,$0D,$0D,$0D,$0D,$0D,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0D,$0D,$0D,$0D,$0D,$0C,$0C,$0C,$0B,$0B,$0A,$0A,$09,$09,$08,$08,$07,$07,$06,$05,$05,$04,$03,$03,$02,$01,$01,$00,$FF,$FF,$FE,$FD,$FD,$FC,$FB,$FB,$FA,$F9,$F9,$F8,$F8,$F7,$F7,$F6,$F6,$F5,$F5,$F4,$F4,$F4,$F3,$F3,$F3,$F3,$F3,$F2,$F2,$F2,$F2,$F2,$F2,$F2,$F2,$F2,$F3,$F3,$F3,$F3,$F3,$F4,$F4,$F4,$F5,$F5,$F6,$F6,$F7,$F7,$F8,$F8,$F9,$F9,$FA,$FB,$FB,$FC,$FD,$FD,$FE,$FF,$FF  ; val=14
    FCB $00,$01,$01,$02,$03,$04,$04,$05,$06,$06,$07,$08,$08,$09,$09,$0A,$0B,$0B,$0B,$0C,$0C,$0D,$0D,$0D,$0E,$0E,$0E,$0E,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0E,$0E,$0E,$0E,$0D,$0D,$0D,$0C,$0C,$0B,$0B,$0B,$0A,$09,$09,$08,$08,$07,$06,$06,$05,$04,$04,$03,$02,$01,$01,$00,$FF,$FF,$FE,$FD,$FC,$FC,$FB,$FA,$FA,$F9,$F8,$F8,$F7,$F7,$F6,$F5,$F5,$F5,$F4,$F4,$F3,$F3,$F3,$F2,$F2,$F2,$F2,$F1,$F1,$F1,$F1,$F1,$F1,$F1,$F1,$F1,$F2,$F2,$F2,$F2,$F3,$F3,$F3,$F4,$F4,$F5,$F5,$F5,$F6,$F7,$F7,$F8,$F8,$F9,$FA,$FA,$FB,$FC,$FC,$FD,$FE,$FF,$FF  ; val=15
    FCB $00,$01,$02,$02,$03,$04,$05,$05,$06,$07,$08,$08,$09,$0A,$0A,$0B,$0B,$0C,$0C,$0D,$0D,$0E,$0E,$0E,$0F,$0F,$0F,$0F,$10,$10,$10,$10,$10,$10,$10,$10,$10,$0F,$0F,$0F,$0F,$0E,$0E,$0E,$0D,$0D,$0C,$0C,$0B,$0B,$0A,$0A,$09,$08,$08,$07,$06,$05,$05,$04,$03,$02,$02,$01,$00,$FF,$FE,$FE,$FD,$FC,$FB,$FB,$FA,$F9,$F8,$F8,$F7,$F6,$F6,$F5,$F5,$F4,$F4,$F3,$F3,$F2,$F2,$F2,$F1,$F1,$F1,$F1,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F1,$F1,$F1,$F1,$F2,$F2,$F2,$F3,$F3,$F4,$F4,$F5,$F5,$F6,$F6,$F7,$F8,$F8,$F9,$FA,$FB,$FB,$FC,$FD,$FE,$FE,$FF  ; val=16
    FCB $00,$01,$02,$03,$03,$04,$05,$06,$07,$07,$08,$09,$09,$0A,$0B,$0B,$0C,$0C,$0D,$0E,$0E,$0E,$0F,$0F,$10,$10,$10,$10,$11,$11,$11,$11,$11,$11,$11,$11,$11,$10,$10,$10,$10,$0F,$0F,$0E,$0E,$0E,$0D,$0C,$0C,$0B,$0B,$0A,$09,$09,$08,$07,$07,$06,$05,$04,$03,$03,$02,$01,$00,$FF,$FE,$FD,$FD,$FC,$FB,$FA,$F9,$F9,$F8,$F7,$F7,$F6,$F5,$F5,$F4,$F4,$F3,$F2,$F2,$F2,$F1,$F1,$F0,$F0,$F0,$F0,$EF,$EF,$EF,$EF,$EF,$EF,$EF,$EF,$EF,$F0,$F0,$F0,$F0,$F1,$F1,$F2,$F2,$F2,$F3,$F4,$F4,$F5,$F5,$F6,$F7,$F7,$F8,$F9,$F9,$FA,$FB,$FC,$FD,$FD,$FE,$FF  ; val=17
    FCB $00,$01,$02,$03,$04,$04,$05,$06,$07,$08,$08,$09,$0A,$0B,$0B,$0C,$0D,$0D,$0E,$0E,$0F,$0F,$10,$10,$10,$11,$11,$11,$12,$12,$12,$12,$12,$12,$12,$12,$12,$11,$11,$11,$10,$10,$10,$0F,$0F,$0E,$0E,$0D,$0D,$0C,$0B,$0B,$0A,$09,$08,$08,$07,$06,$05,$04,$04,$03,$02,$01,$00,$FF,$FE,$FD,$FC,$FC,$FB,$FA,$F9,$F8,$F8,$F7,$F6,$F5,$F5,$F4,$F3,$F3,$F2,$F2,$F1,$F1,$F0,$F0,$F0,$EF,$EF,$EF,$EE,$EE,$EE,$EE,$EE,$EE,$EE,$EE,$EE,$EF,$EF,$EF,$F0,$F0,$F0,$F1,$F1,$F2,$F2,$F3,$F3,$F4,$F5,$F5,$F6,$F7,$F8,$F8,$F9,$FA,$FB,$FC,$FC,$FD,$FE,$FF  ; val=18
    FCB $00,$01,$02,$03,$04,$05,$05,$06,$07,$08,$09,$0A,$0B,$0B,$0C,$0D,$0D,$0E,$0F,$0F,$10,$10,$11,$11,$11,$12,$12,$12,$13,$13,$13,$13,$13,$13,$13,$13,$13,$12,$12,$12,$11,$11,$11,$10,$10,$0F,$0F,$0E,$0D,$0D,$0C,$0B,$0B,$0A,$09,$08,$07,$06,$05,$05,$04,$03,$02,$01,$00,$FF,$FE,$FD,$FC,$FB,$FB,$FA,$F9,$F8,$F7,$F6,$F5,$F5,$F4,$F3,$F3,$F2,$F1,$F1,$F0,$F0,$EF,$EF,$EF,$EE,$EE,$EE,$ED,$ED,$ED,$ED,$ED,$ED,$ED,$ED,$ED,$EE,$EE,$EE,$EF,$EF,$EF,$F0,$F0,$F1,$F1,$F2,$F3,$F3,$F4,$F5,$F5,$F6,$F7,$F8,$F9,$FA,$FB,$FB,$FC,$FD,$FE,$FF  ; val=19
    FCB $00,$01,$02,$03,$04,$05,$06,$07,$08,$08,$09,$0A,$0B,$0C,$0D,$0D,$0E,$0F,$0F,$10,$11,$11,$12,$12,$12,$13,$13,$13,$14,$14,$14,$14,$14,$14,$14,$14,$14,$13,$13,$13,$12,$12,$12,$11,$11,$10,$0F,$0F,$0E,$0D,$0D,$0C,$0B,$0A,$09,$08,$08,$07,$06,$05,$04,$03,$02,$01,$00,$FF,$FE,$FD,$FC,$FB,$FA,$F9,$F8,$F8,$F7,$F6,$F5,$F4,$F3,$F3,$F2,$F1,$F1,$F0,$EF,$EF,$EE,$EE,$EE,$ED,$ED,$ED,$EC,$EC,$EC,$EC,$EC,$EC,$EC,$EC,$EC,$ED,$ED,$ED,$EE,$EE,$EE,$EF,$EF,$F0,$F1,$F1,$F2,$F3,$F3,$F4,$F5,$F6,$F7,$F8,$F8,$F9,$FA,$FB,$FC,$FD,$FE,$FF  ; val=20
    FCB $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0C,$0D,$0E,$0F,$0F,$10,$11,$11,$12,$12,$13,$13,$14,$14,$14,$15,$15,$15,$15,$15,$15,$15,$15,$15,$14,$14,$14,$13,$13,$12,$12,$11,$11,$10,$0F,$0F,$0E,$0D,$0C,$0C,$0B,$0A,$09,$08,$07,$06,$05,$04,$03,$02,$01,$00,$FF,$FE,$FD,$FC,$FB,$FA,$F9,$F8,$F7,$F6,$F5,$F4,$F4,$F3,$F2,$F1,$F1,$F0,$EF,$EF,$EE,$EE,$ED,$ED,$EC,$EC,$EC,$EB,$EB,$EB,$EB,$EB,$EB,$EB,$EB,$EB,$EC,$EC,$EC,$ED,$ED,$EE,$EE,$EF,$EF,$F0,$F1,$F1,$F2,$F3,$F4,$F4,$F5,$F6,$F7,$F8,$F9,$FA,$FB,$FC,$FD,$FE,$FF  ; val=21
    FCB $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F,$0F,$10,$11,$12,$12,$13,$13,$14,$14,$15,$15,$15,$15,$16,$16,$16,$16,$16,$16,$16,$15,$15,$15,$15,$14,$14,$13,$13,$12,$12,$11,$10,$0F,$0F,$0E,$0D,$0C,$0B,$0A,$09,$08,$07,$06,$05,$04,$03,$02,$01,$00,$FF,$FE,$FD,$FC,$FB,$FA,$F9,$F8,$F7,$F6,$F5,$F4,$F3,$F2,$F1,$F1,$F0,$EF,$EE,$EE,$ED,$ED,$EC,$EC,$EB,$EB,$EB,$EB,$EA,$EA,$EA,$EA,$EA,$EA,$EA,$EB,$EB,$EB,$EB,$EC,$EC,$ED,$ED,$EE,$EE,$EF,$F0,$F1,$F1,$F2,$F3,$F4,$F5,$F6,$F7,$F8,$F9,$FA,$FB,$FC,$FD,$FE,$FF  ; val=22
    FCB $00,$01,$02,$03,$04,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F,$0F,$10,$11,$12,$12,$13,$14,$14,$15,$15,$16,$16,$16,$16,$17,$17,$17,$17,$17,$17,$17,$16,$16,$16,$16,$15,$15,$14,$14,$13,$12,$12,$11,$10,$0F,$0F,$0E,$0D,$0C,$0B,$0A,$09,$08,$07,$06,$04,$03,$02,$01,$00,$FF,$FE,$FD,$FC,$FA,$F9,$F8,$F7,$F6,$F5,$F4,$F3,$F2,$F1,$F1,$F0,$EF,$EE,$EE,$ED,$EC,$EC,$EB,$EB,$EA,$EA,$EA,$EA,$E9,$E9,$E9,$E9,$E9,$E9,$E9,$EA,$EA,$EA,$EA,$EB,$EB,$EC,$EC,$ED,$EE,$EE,$EF,$F0,$F1,$F1,$F2,$F3,$F4,$F5,$F6,$F7,$F8,$F9,$FA,$FC,$FD,$FE,$FF  ; val=23
    FCB $00,$01,$02,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F,$10,$11,$12,$12,$13,$14,$14,$15,$16,$16,$17,$17,$17,$17,$18,$18,$18,$18,$18,$18,$18,$17,$17,$17,$17,$16,$16,$15,$14,$14,$13,$12,$12,$11,$10,$0F,$0E,$0D,$0C,$0B,$0A,$09,$08,$07,$06,$05,$04,$02,$01,$00,$FF,$FE,$FC,$FB,$FA,$F9,$F8,$F7,$F6,$F5,$F4,$F3,$F2,$F1,$F0,$EF,$EE,$EE,$ED,$EC,$EC,$EB,$EA,$EA,$E9,$E9,$E9,$E9,$E8,$E8,$E8,$E8,$E8,$E8,$E8,$E9,$E9,$E9,$E9,$EA,$EA,$EB,$EC,$EC,$ED,$EE,$EE,$EF,$F0,$F1,$F2,$F3,$F4,$F5,$F6,$F7,$F8,$F9,$FA,$FB,$FC,$FE,$FF  ; val=24
    FCB $00,$01,$02,$04,$05,$06,$07,$08,$0A,$0B,$0C,$0D,$0E,$0F,$10,$11,$12,$12,$13,$14,$15,$15,$16,$16,$17,$17,$18,$18,$18,$19,$19,$19,$19,$19,$19,$19,$18,$18,$18,$17,$17,$16,$16,$15,$15,$14,$13,$12,$12,$11,$10,$0F,$0E,$0D,$0C,$0B,$0A,$08,$07,$06,$05,$04,$02,$01,$00,$FF,$FE,$FC,$FB,$FA,$F9,$F8,$F6,$F5,$F4,$F3,$F2,$F1,$F0,$EF,$EE,$EE,$ED,$EC,$EB,$EB,$EA,$EA,$E9,$E9,$E8,$E8,$E8,$E7,$E7,$E7,$E7,$E7,$E7,$E7,$E8,$E8,$E8,$E9,$E9,$EA,$EA,$EB,$EB,$EC,$ED,$EE,$EE,$EF,$F0,$F1,$F2,$F3,$F4,$F5,$F6,$F8,$F9,$FA,$FB,$FC,$FE,$FF  ; val=25
    FCB $00,$01,$02,$04,$05,$06,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F,$10,$11,$12,$13,$14,$15,$16,$16,$17,$17,$18,$18,$19,$19,$19,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$19,$19,$19,$18,$18,$17,$17,$16,$16,$15,$14,$13,$12,$11,$10,$0F,$0E,$0D,$0C,$0B,$0A,$09,$08,$06,$05,$04,$02,$01,$00,$FF,$FE,$FC,$FB,$FA,$F8,$F7,$F6,$F5,$F4,$F3,$F2,$F1,$F0,$EF,$EE,$ED,$EC,$EB,$EA,$EA,$E9,$E9,$E8,$E8,$E7,$E7,$E7,$E6,$E6,$E6,$E6,$E6,$E6,$E6,$E7,$E7,$E7,$E8,$E8,$E9,$E9,$EA,$EA,$EB,$EC,$ED,$EE,$EF,$F0,$F1,$F2,$F3,$F4,$F5,$F6,$F7,$F8,$FA,$FB,$FC,$FE,$FF  ; val=26
    FCB $00,$01,$03,$04,$05,$07,$08,$09,$0A,$0B,$0D,$0E,$0F,$10,$11,$12,$13,$14,$15,$16,$16,$17,$18,$18,$19,$19,$1A,$1A,$1A,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1A,$1A,$1A,$19,$19,$18,$18,$17,$16,$16,$15,$14,$13,$12,$11,$10,$0F,$0E,$0D,$0B,$0A,$09,$08,$07,$05,$04,$03,$01,$00,$FF,$FD,$FC,$FB,$F9,$F8,$F7,$F6,$F5,$F3,$F2,$F1,$F0,$EF,$EE,$ED,$EC,$EB,$EA,$EA,$E9,$E8,$E8,$E7,$E7,$E6,$E6,$E6,$E5,$E5,$E5,$E5,$E5,$E5,$E5,$E6,$E6,$E6,$E7,$E7,$E8,$E8,$E9,$EA,$EA,$EB,$EC,$ED,$EE,$EF,$F0,$F1,$F2,$F3,$F5,$F6,$F7,$F8,$F9,$FB,$FC,$FD,$FF  ; val=27
    FCB $00,$01,$03,$04,$05,$07,$08,$09,$0B,$0C,$0D,$0E,$10,$11,$12,$13,$14,$15,$15,$16,$17,$18,$19,$19,$1A,$1A,$1B,$1B,$1B,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1B,$1B,$1B,$1A,$1A,$19,$19,$18,$17,$16,$15,$15,$14,$13,$12,$11,$10,$0E,$0D,$0C,$0B,$09,$08,$07,$05,$04,$03,$01,$00,$FF,$FD,$FC,$FB,$F9,$F8,$F7,$F5,$F4,$F3,$F2,$F0,$EF,$EE,$ED,$EC,$EB,$EB,$EA,$E9,$E8,$E7,$E7,$E6,$E6,$E5,$E5,$E5,$E4,$E4,$E4,$E4,$E4,$E4,$E4,$E5,$E5,$E5,$E6,$E6,$E7,$E7,$E8,$E9,$EA,$EB,$EB,$EC,$ED,$EE,$EF,$F0,$F2,$F3,$F4,$F5,$F7,$F8,$F9,$FB,$FC,$FD,$FF  ; val=28
    FCB $00,$01,$03,$04,$06,$07,$08,$0A,$0B,$0C,$0E,$0F,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$19,$1A,$1B,$1B,$1C,$1C,$1C,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1C,$1C,$1C,$1B,$1B,$1A,$19,$19,$18,$17,$16,$15,$14,$13,$12,$11,$10,$0F,$0E,$0C,$0B,$0A,$08,$07,$06,$04,$03,$01,$00,$FF,$FD,$FC,$FA,$F9,$F8,$F6,$F5,$F4,$F2,$F1,$F0,$EF,$EE,$ED,$EC,$EB,$EA,$E9,$E8,$E7,$E7,$E6,$E5,$E5,$E4,$E4,$E4,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E4,$E4,$E4,$E5,$E5,$E6,$E7,$E7,$E8,$E9,$EA,$EB,$EC,$ED,$EE,$EF,$F0,$F1,$F2,$F4,$F5,$F6,$F8,$F9,$FA,$FC,$FD,$FF  ; val=29
    FCB $00,$01,$03,$04,$06,$07,$09,$0A,$0B,$0D,$0E,$0F,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1A,$1A,$1B,$1B,$1C,$1D,$1D,$1D,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1D,$1D,$1D,$1C,$1B,$1B,$1A,$1A,$19,$18,$17,$16,$15,$14,$13,$12,$11,$0F,$0E,$0D,$0B,$0A,$09,$07,$06,$04,$03,$01,$00,$FF,$FD,$FC,$FA,$F9,$F7,$F6,$F5,$F3,$F2,$F1,$EF,$EE,$ED,$EC,$EB,$EA,$E9,$E8,$E7,$E6,$E6,$E5,$E5,$E4,$E3,$E3,$E3,$E2,$E2,$E2,$E2,$E2,$E2,$E2,$E3,$E3,$E3,$E4,$E5,$E5,$E6,$E6,$E7,$E8,$E9,$EA,$EB,$EC,$ED,$EE,$EF,$F1,$F2,$F3,$F5,$F6,$F7,$F9,$FA,$FC,$FD,$FF  ; val=30
    FCB $00,$01,$03,$05,$06,$08,$09,$0A,$0C,$0D,$0F,$10,$11,$12,$14,$15,$16,$17,$18,$19,$1A,$1A,$1B,$1C,$1C,$1D,$1E,$1E,$1E,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1E,$1E,$1E,$1D,$1C,$1C,$1B,$1A,$1A,$19,$18,$17,$16,$15,$14,$12,$11,$10,$0F,$0D,$0C,$0A,$09,$08,$06,$05,$03,$01,$00,$FF,$FD,$FB,$FA,$F8,$F7,$F6,$F4,$F3,$F1,$F0,$EF,$EE,$EC,$EB,$EA,$E9,$E8,$E7,$E6,$E6,$E5,$E4,$E4,$E3,$E2,$E2,$E2,$E1,$E1,$E1,$E1,$E1,$E1,$E1,$E2,$E2,$E2,$E3,$E4,$E4,$E5,$E6,$E6,$E7,$E8,$E9,$EA,$EB,$EC,$EE,$EF,$F0,$F1,$F3,$F4,$F6,$F7,$F8,$FA,$FB,$FD,$FF  ; val=31
    FCB $00,$02,$03,$05,$06,$08,$09,$0B,$0C,$0E,$0F,$10,$12,$13,$14,$15,$17,$18,$19,$1A,$1B,$1B,$1C,$1D,$1D,$1E,$1F,$1F,$1F,$20,$20,$20,$20,$20,$20,$20,$1F,$1F,$1F,$1E,$1D,$1D,$1C,$1B,$1B,$1A,$19,$18,$17,$15,$14,$13,$12,$10,$0F,$0E,$0C,$0B,$09,$08,$06,$05,$03,$02,$00,$FE,$FD,$FB,$FA,$F8,$F7,$F5,$F4,$F2,$F1,$F0,$EE,$ED,$EC,$EB,$E9,$E8,$E7,$E6,$E5,$E5,$E4,$E3,$E3,$E2,$E1,$E1,$E1,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E1,$E1,$E1,$E2,$E3,$E3,$E4,$E5,$E5,$E6,$E7,$E8,$E9,$EB,$EC,$ED,$EE,$F0,$F1,$F2,$F4,$F5,$F7,$F8,$FA,$FB,$FD,$FE  ; val=32
    FCB $00,$02,$03,$05,$06,$08,$0A,$0B,$0D,$0E,$0F,$11,$12,$14,$15,$16,$17,$18,$19,$1A,$1B,$1C,$1D,$1E,$1E,$1F,$1F,$20,$20,$20,$20,$21,$21,$21,$20,$20,$20,$20,$1F,$1F,$1E,$1E,$1D,$1C,$1B,$1A,$19,$18,$17,$16,$15,$14,$12,$11,$0F,$0E,$0D,$0B,$0A,$08,$06,$05,$03,$02,$00,$FE,$FD,$FB,$FA,$F8,$F6,$F5,$F3,$F2,$F1,$EF,$EE,$EC,$EB,$EA,$E9,$E8,$E7,$E6,$E5,$E4,$E3,$E2,$E2,$E1,$E1,$E0,$E0,$E0,$E0,$DF,$DF,$DF,$E0,$E0,$E0,$E0,$E1,$E1,$E2,$E2,$E3,$E4,$E5,$E6,$E7,$E8,$E9,$EA,$EB,$EC,$EE,$EF,$F1,$F2,$F3,$F5,$F6,$F8,$FA,$FB,$FD,$FE  ; val=33
    FCB $00,$02,$03,$05,$07,$08,$0A,$0B,$0D,$0E,$10,$11,$13,$14,$16,$17,$18,$19,$1A,$1B,$1C,$1D,$1E,$1F,$1F,$20,$20,$21,$21,$21,$21,$22,$22,$22,$21,$21,$21,$21,$20,$20,$1F,$1F,$1E,$1D,$1C,$1B,$1A,$19,$18,$17,$16,$14,$13,$11,$10,$0E,$0D,$0B,$0A,$08,$07,$05,$03,$02,$00,$FE,$FD,$FB,$F9,$F8,$F6,$F5,$F3,$F2,$F0,$EF,$ED,$EC,$EA,$E9,$E8,$E7,$E6,$E5,$E4,$E3,$E2,$E1,$E1,$E0,$E0,$DF,$DF,$DF,$DF,$DE,$DE,$DE,$DF,$DF,$DF,$DF,$E0,$E0,$E1,$E1,$E2,$E3,$E4,$E5,$E6,$E7,$E8,$E9,$EA,$EC,$ED,$EF,$F0,$F2,$F3,$F5,$F6,$F8,$F9,$FB,$FD,$FE  ; val=34
    FCB $00,$02,$03,$05,$07,$08,$0A,$0C,$0D,$0F,$10,$12,$13,$15,$16,$17,$19,$1A,$1B,$1C,$1D,$1E,$1F,$1F,$20,$21,$21,$22,$22,$22,$22,$23,$23,$23,$22,$22,$22,$22,$21,$21,$20,$1F,$1F,$1E,$1D,$1C,$1B,$1A,$19,$17,$16,$15,$13,$12,$10,$0F,$0D,$0C,$0A,$08,$07,$05,$03,$02,$00,$FE,$FD,$FB,$F9,$F8,$F6,$F4,$F3,$F1,$F0,$EE,$ED,$EB,$EA,$E9,$E7,$E6,$E5,$E4,$E3,$E2,$E1,$E1,$E0,$DF,$DF,$DE,$DE,$DE,$DE,$DD,$DD,$DD,$DE,$DE,$DE,$DE,$DF,$DF,$E0,$E1,$E1,$E2,$E3,$E4,$E5,$E6,$E7,$E9,$EA,$EB,$ED,$EE,$F0,$F1,$F3,$F4,$F6,$F8,$F9,$FB,$FD,$FE  ; val=35
    FCB $00,$02,$03,$05,$07,$09,$0A,$0C,$0E,$0F,$11,$12,$14,$15,$17,$18,$19,$1A,$1C,$1D,$1E,$1F,$20,$20,$21,$22,$22,$23,$23,$23,$23,$24,$24,$24,$23,$23,$23,$23,$22,$22,$21,$20,$20,$1F,$1E,$1D,$1C,$1A,$19,$18,$17,$15,$14,$12,$11,$0F,$0E,$0C,$0A,$09,$07,$05,$03,$02,$00,$FE,$FD,$FB,$F9,$F7,$F6,$F4,$F2,$F1,$EF,$EE,$EC,$EB,$E9,$E8,$E7,$E6,$E4,$E3,$E2,$E1,$E0,$E0,$DF,$DE,$DE,$DD,$DD,$DD,$DD,$DC,$DC,$DC,$DD,$DD,$DD,$DD,$DE,$DE,$DF,$E0,$E0,$E1,$E2,$E3,$E4,$E6,$E7,$E8,$E9,$EB,$EC,$EE,$EF,$F1,$F2,$F4,$F6,$F7,$F9,$FB,$FD,$FE  ; val=36
    FCB $00,$02,$03,$05,$07,$09,$0B,$0C,$0E,$10,$11,$13,$15,$16,$17,$19,$1A,$1B,$1C,$1D,$1F,$20,$20,$21,$22,$23,$23,$24,$24,$24,$24,$25,$25,$25,$24,$24,$24,$24,$23,$23,$22,$21,$20,$20,$1F,$1D,$1C,$1B,$1A,$19,$17,$16,$15,$13,$11,$10,$0E,$0C,$0B,$09,$07,$05,$03,$02,$00,$FE,$FD,$FB,$F9,$F7,$F5,$F4,$F2,$F0,$EF,$ED,$EB,$EA,$E9,$E7,$E6,$E5,$E4,$E3,$E1,$E0,$E0,$DF,$DE,$DD,$DD,$DC,$DC,$DC,$DC,$DB,$DB,$DB,$DC,$DC,$DC,$DC,$DD,$DD,$DE,$DF,$E0,$E0,$E1,$E3,$E4,$E5,$E6,$E7,$E9,$EA,$EB,$ED,$EF,$F0,$F2,$F4,$F5,$F7,$F9,$FB,$FD,$FE  ; val=37
    FCB $00,$02,$04,$06,$07,$09,$0B,$0D,$0F,$10,$12,$13,$15,$17,$18,$19,$1B,$1C,$1D,$1E,$1F,$20,$21,$22,$23,$24,$24,$25,$25,$25,$25,$26,$26,$26,$25,$25,$25,$25,$24,$24,$23,$22,$21,$20,$1F,$1E,$1D,$1C,$1B,$19,$18,$17,$15,$13,$12,$10,$0F,$0D,$0B,$09,$07,$06,$04,$02,$00,$FE,$FC,$FA,$F9,$F7,$F5,$F3,$F1,$F0,$EE,$ED,$EB,$E9,$E8,$E7,$E5,$E4,$E3,$E2,$E1,$E0,$DF,$DE,$DD,$DC,$DC,$DB,$DB,$DB,$DB,$DA,$DA,$DA,$DB,$DB,$DB,$DB,$DC,$DC,$DD,$DE,$DF,$E0,$E1,$E2,$E3,$E4,$E5,$E7,$E8,$E9,$EB,$ED,$EE,$F0,$F1,$F3,$F5,$F7,$F9,$FA,$FC,$FE  ; val=38
    FCB $00,$02,$04,$06,$08,$09,$0B,$0D,$0F,$10,$12,$14,$16,$17,$19,$1A,$1B,$1D,$1E,$1F,$20,$21,$22,$23,$24,$25,$25,$25,$26,$26,$26,$27,$27,$27,$26,$26,$26,$25,$25,$25,$24,$23,$22,$21,$20,$1F,$1E,$1D,$1B,$1A,$19,$17,$16,$14,$12,$10,$0F,$0D,$0B,$09,$08,$06,$04,$02,$00,$FE,$FC,$FA,$F8,$F7,$F5,$F3,$F1,$F0,$EE,$EC,$EA,$E9,$E7,$E6,$E5,$E3,$E2,$E1,$E0,$DF,$DE,$DD,$DC,$DB,$DB,$DB,$DA,$DA,$DA,$D9,$D9,$D9,$DA,$DA,$DA,$DB,$DB,$DB,$DC,$DD,$DE,$DF,$E0,$E1,$E2,$E3,$E5,$E6,$E7,$E9,$EA,$EC,$EE,$F0,$F1,$F3,$F5,$F7,$F8,$FA,$FC,$FE  ; val=39
    FCB $00,$02,$04,$06,$08,$0A,$0C,$0D,$0F,$11,$13,$14,$16,$18,$19,$1B,$1C,$1D,$1F,$20,$21,$22,$23,$24,$25,$26,$26,$26,$27,$27,$27,$28,$28,$28,$27,$27,$27,$26,$26,$26,$25,$24,$23,$22,$21,$20,$1F,$1D,$1C,$1B,$19,$18,$16,$14,$13,$11,$0F,$0D,$0C,$0A,$08,$06,$04,$02,$00,$FE,$FC,$FA,$F8,$F6,$F4,$F3,$F1,$EF,$ED,$EC,$EA,$E8,$E7,$E5,$E4,$E3,$E1,$E0,$DF,$DE,$DD,$DC,$DB,$DA,$DA,$DA,$D9,$D9,$D9,$D8,$D8,$D8,$D9,$D9,$D9,$DA,$DA,$DA,$DB,$DC,$DD,$DE,$DF,$E0,$E1,$E3,$E4,$E5,$E7,$E8,$EA,$EC,$ED,$EF,$F1,$F3,$F4,$F6,$F8,$FA,$FC,$FE  ; val=40
    FCB $00,$02,$04,$06,$08,$0A,$0C,$0E,$10,$11,$13,$15,$17,$18,$1A,$1B,$1D,$1E,$1F,$21,$22,$23,$24,$25,$25,$26,$27,$27,$28,$28,$28,$29,$29,$29,$28,$28,$28,$27,$27,$26,$25,$25,$24,$23,$22,$21,$1F,$1E,$1D,$1B,$1A,$18,$17,$15,$13,$11,$10,$0E,$0C,$0A,$08,$06,$04,$02,$00,$FE,$FC,$FA,$F8,$F6,$F4,$F2,$F0,$EF,$ED,$EB,$E9,$E8,$E6,$E5,$E3,$E2,$E1,$DF,$DE,$DD,$DC,$DB,$DB,$DA,$D9,$D9,$D8,$D8,$D8,$D7,$D7,$D7,$D8,$D8,$D8,$D9,$D9,$DA,$DB,$DB,$DC,$DD,$DE,$DF,$E1,$E2,$E3,$E5,$E6,$E8,$E9,$EB,$ED,$EF,$F0,$F2,$F4,$F6,$F8,$FA,$FC,$FE  ; val=41
    FCB $00,$02,$04,$06,$08,$0A,$0C,$0E,$10,$12,$14,$15,$17,$19,$1B,$1C,$1E,$1F,$20,$21,$23,$24,$25,$26,$26,$27,$28,$28,$29,$29,$29,$2A,$2A,$2A,$29,$29,$29,$28,$28,$27,$26,$26,$25,$24,$23,$21,$20,$1F,$1E,$1C,$1B,$19,$17,$15,$14,$12,$10,$0E,$0C,$0A,$08,$06,$04,$02,$00,$FE,$FC,$FA,$F8,$F6,$F4,$F2,$F0,$EE,$EC,$EB,$E9,$E7,$E5,$E4,$E2,$E1,$E0,$DF,$DD,$DC,$DB,$DA,$DA,$D9,$D8,$D8,$D7,$D7,$D7,$D6,$D6,$D6,$D7,$D7,$D7,$D8,$D8,$D9,$DA,$DA,$DB,$DC,$DD,$DF,$E0,$E1,$E2,$E4,$E5,$E7,$E9,$EB,$EC,$EE,$F0,$F2,$F4,$F6,$F8,$FA,$FC,$FE  ; val=42
    FCB $00,$02,$04,$06,$08,$0A,$0C,$0E,$10,$12,$14,$16,$18,$1A,$1B,$1D,$1E,$20,$21,$22,$24,$25,$26,$27,$27,$28,$29,$29,$2A,$2A,$2A,$2B,$2B,$2B,$2A,$2A,$2A,$29,$29,$28,$27,$27,$26,$25,$24,$22,$21,$20,$1E,$1D,$1B,$1A,$18,$16,$14,$12,$10,$0E,$0C,$0A,$08,$06,$04,$02,$00,$FE,$FC,$FA,$F8,$F6,$F4,$F2,$F0,$EE,$EC,$EA,$E8,$E6,$E5,$E3,$E2,$E0,$DF,$DE,$DC,$DB,$DA,$D9,$D9,$D8,$D7,$D7,$D6,$D6,$D6,$D5,$D5,$D5,$D6,$D6,$D6,$D7,$D7,$D8,$D9,$D9,$DA,$DB,$DC,$DE,$DF,$E0,$E2,$E3,$E5,$E6,$E8,$EA,$EC,$EE,$F0,$F2,$F4,$F6,$F8,$FA,$FC,$FE  ; val=43
    FCB $00,$02,$04,$07,$09,$0B,$0D,$0F,$11,$13,$15,$16,$18,$1A,$1C,$1D,$1F,$20,$22,$23,$24,$25,$27,$28,$28,$29,$2A,$2A,$2B,$2B,$2B,$2C,$2C,$2C,$2B,$2B,$2B,$2A,$2A,$29,$28,$28,$27,$25,$24,$23,$22,$20,$1F,$1D,$1C,$1A,$18,$16,$15,$13,$11,$0F,$0D,$0B,$09,$07,$04,$02,$00,$FE,$FC,$F9,$F7,$F5,$F3,$F1,$EF,$ED,$EB,$EA,$E8,$E6,$E4,$E3,$E1,$E0,$DE,$DD,$DC,$DB,$D9,$D8,$D8,$D7,$D6,$D6,$D5,$D5,$D5,$D4,$D4,$D4,$D5,$D5,$D5,$D6,$D6,$D7,$D8,$D8,$D9,$DB,$DC,$DD,$DE,$E0,$E1,$E3,$E4,$E6,$E8,$EA,$EB,$ED,$EF,$F1,$F3,$F5,$F7,$F9,$FC,$FE  ; val=44
    FCB $00,$02,$04,$07,$09,$0B,$0D,$0F,$11,$13,$15,$17,$19,$1B,$1C,$1E,$20,$21,$22,$24,$25,$26,$27,$28,$29,$2A,$2B,$2B,$2C,$2C,$2C,$2D,$2D,$2D,$2C,$2C,$2C,$2B,$2B,$2A,$29,$28,$27,$26,$25,$24,$22,$21,$20,$1E,$1C,$1B,$19,$17,$15,$13,$11,$0F,$0D,$0B,$09,$07,$04,$02,$00,$FE,$FC,$F9,$F7,$F5,$F3,$F1,$EF,$ED,$EB,$E9,$E7,$E5,$E4,$E2,$E0,$DF,$DE,$DC,$DB,$DA,$D9,$D8,$D7,$D6,$D5,$D5,$D4,$D4,$D4,$D3,$D3,$D3,$D4,$D4,$D4,$D5,$D5,$D6,$D7,$D8,$D9,$DA,$DB,$DC,$DE,$DF,$E0,$E2,$E4,$E5,$E7,$E9,$EB,$ED,$EF,$F1,$F3,$F5,$F7,$F9,$FC,$FE  ; val=45
    FCB $00,$02,$04,$07,$09,$0B,$0D,$0F,$12,$13,$16,$17,$1A,$1B,$1D,$1F,$20,$22,$23,$25,$26,$27,$28,$29,$2A,$2B,$2C,$2C,$2D,$2D,$2D,$2E,$2E,$2E,$2D,$2D,$2D,$2C,$2C,$2B,$2A,$29,$28,$27,$26,$25,$23,$22,$20,$1F,$1D,$1B,$1A,$17,$16,$13,$12,$0F,$0D,$0B,$09,$07,$04,$02,$00,$FE,$FC,$F9,$F7,$F5,$F3,$F1,$EE,$ED,$EA,$E9,$E6,$E5,$E3,$E1,$E0,$DE,$DD,$DB,$DA,$D9,$D8,$D7,$D6,$D5,$D4,$D4,$D3,$D3,$D3,$D2,$D2,$D2,$D3,$D3,$D3,$D4,$D4,$D5,$D6,$D7,$D8,$D9,$DA,$DB,$DD,$DE,$E0,$E1,$E3,$E5,$E6,$E9,$EA,$ED,$EE,$F1,$F3,$F5,$F7,$F9,$FC,$FE  ; val=46
    FCB $00,$02,$04,$07,$09,$0B,$0E,$10,$12,$14,$16,$18,$1A,$1C,$1E,$1F,$21,$23,$24,$25,$27,$28,$29,$2A,$2B,$2C,$2D,$2D,$2E,$2E,$2E,$2F,$2F,$2F,$2E,$2E,$2E,$2D,$2D,$2C,$2B,$2A,$29,$28,$27,$25,$24,$23,$21,$1F,$1E,$1C,$1A,$18,$16,$14,$12,$10,$0E,$0B,$09,$07,$04,$02,$00,$FE,$FC,$F9,$F7,$F5,$F2,$F0,$EE,$EC,$EA,$E8,$E6,$E4,$E2,$E1,$DF,$DD,$DC,$DB,$D9,$D8,$D7,$D6,$D5,$D4,$D3,$D3,$D2,$D2,$D2,$D1,$D1,$D1,$D2,$D2,$D2,$D3,$D3,$D4,$D5,$D6,$D7,$D8,$D9,$DB,$DC,$DD,$DF,$E1,$E2,$E4,$E6,$E8,$EA,$EC,$EE,$F0,$F2,$F5,$F7,$F9,$FC,$FE  ; val=47
    FCB $00,$02,$05,$07,$09,$0C,$0E,$10,$12,$14,$17,$18,$1B,$1D,$1E,$20,$22,$23,$25,$26,$28,$29,$2A,$2B,$2C,$2D,$2E,$2E,$2F,$2F,$2F,$30,$30,$30,$2F,$2F,$2F,$2E,$2E,$2D,$2C,$2B,$2A,$29,$28,$26,$25,$23,$22,$20,$1E,$1D,$1B,$18,$17,$14,$12,$10,$0E,$0C,$09,$07,$05,$02,$00,$FE,$FB,$F9,$F7,$F4,$F2,$F0,$EE,$EC,$E9,$E8,$E5,$E3,$E2,$E0,$DE,$DD,$DB,$DA,$D8,$D7,$D6,$D5,$D4,$D3,$D2,$D2,$D1,$D1,$D1,$D0,$D0,$D0,$D1,$D1,$D1,$D2,$D2,$D3,$D4,$D5,$D6,$D7,$D8,$DA,$DB,$DD,$DE,$E0,$E2,$E3,$E5,$E8,$E9,$EC,$EE,$F0,$F2,$F4,$F7,$F9,$FB,$FE  ; val=48
    FCB $00,$02,$05,$07,$0A,$0C,$0E,$10,$13,$15,$17,$19,$1B,$1D,$1F,$21,$22,$24,$26,$27,$29,$2A,$2B,$2C,$2D,$2E,$2F,$2F,$30,$30,$30,$31,$31,$31,$30,$30,$30,$2F,$2F,$2E,$2D,$2C,$2B,$2A,$29,$27,$26,$24,$22,$21,$1F,$1D,$1B,$19,$17,$15,$13,$10,$0E,$0C,$0A,$07,$05,$02,$00,$FE,$FB,$F9,$F6,$F4,$F2,$F0,$ED,$EB,$E9,$E7,$E5,$E3,$E1,$DF,$DE,$DC,$DA,$D9,$D7,$D6,$D5,$D4,$D3,$D2,$D1,$D1,$D0,$D0,$D0,$CF,$CF,$CF,$D0,$D0,$D0,$D1,$D1,$D2,$D3,$D4,$D5,$D6,$D7,$D9,$DA,$DC,$DE,$DF,$E1,$E3,$E5,$E7,$E9,$EB,$ED,$F0,$F2,$F4,$F6,$F9,$FB,$FE  ; val=49
    FCB $00,$02,$05,$07,$0A,$0C,$0E,$11,$13,$15,$17,$19,$1C,$1E,$20,$21,$23,$25,$26,$28,$29,$2B,$2C,$2D,$2E,$2F,$30,$30,$31,$31,$31,$32,$32,$32,$31,$31,$31,$30,$30,$2F,$2E,$2D,$2C,$2B,$29,$28,$26,$25,$23,$21,$20,$1E,$1C,$19,$17,$15,$13,$11,$0E,$0C,$0A,$07,$05,$02,$00,$FE,$FB,$F9,$F6,$F4,$F2,$EF,$ED,$EB,$E9,$E7,$E4,$E2,$E0,$DF,$DD,$DB,$DA,$D8,$D7,$D5,$D4,$D3,$D2,$D1,$D0,$D0,$CF,$CF,$CF,$CE,$CE,$CE,$CF,$CF,$CF,$D0,$D0,$D1,$D2,$D3,$D4,$D5,$D7,$D8,$DA,$DB,$DD,$DF,$E0,$E2,$E4,$E7,$E9,$EB,$ED,$EF,$F2,$F4,$F6,$F9,$FB,$FE  ; val=50
    FCB $00,$02,$05,$08,$0A,$0C,$0F,$11,$14,$16,$18,$1A,$1C,$1E,$20,$22,$24,$25,$27,$29,$2A,$2B,$2D,$2E,$2F,$30,$31,$31,$32,$32,$32,$33,$33,$33,$32,$32,$32,$31,$31,$30,$2F,$2E,$2D,$2B,$2A,$29,$27,$25,$24,$22,$20,$1E,$1C,$1A,$18,$16,$14,$11,$0F,$0C,$0A,$08,$05,$02,$00,$FE,$FB,$F8,$F6,$F4,$F1,$EF,$EC,$EA,$E8,$E6,$E4,$E2,$E0,$DE,$DC,$DB,$D9,$D7,$D6,$D5,$D3,$D2,$D1,$D0,$CF,$CF,$CE,$CE,$CE,$CD,$CD,$CD,$CE,$CE,$CE,$CF,$CF,$D0,$D1,$D2,$D3,$D5,$D6,$D7,$D9,$DB,$DC,$DE,$E0,$E2,$E4,$E6,$E8,$EA,$EC,$EF,$F1,$F4,$F6,$F8,$FB,$FE  ; val=51
    FCB $00,$02,$05,$08,$0A,$0D,$0F,$11,$14,$16,$18,$1A,$1D,$1F,$21,$23,$25,$26,$28,$29,$2B,$2C,$2E,$2F,$30,$31,$32,$32,$33,$33,$33,$34,$34,$34,$33,$33,$33,$32,$32,$31,$30,$2F,$2E,$2C,$2B,$29,$28,$26,$25,$23,$21,$1F,$1D,$1A,$18,$16,$14,$11,$0F,$0D,$0A,$08,$05,$02,$00,$FE,$FB,$F8,$F6,$F3,$F1,$EF,$EC,$EA,$E8,$E6,$E3,$E1,$DF,$DD,$DB,$DA,$D8,$D7,$D5,$D4,$D2,$D1,$D0,$CF,$CE,$CE,$CD,$CD,$CD,$CC,$CC,$CC,$CD,$CD,$CD,$CE,$CE,$CF,$D0,$D1,$D2,$D4,$D5,$D7,$D8,$DA,$DB,$DD,$DF,$E1,$E3,$E6,$E8,$EA,$EC,$EF,$F1,$F3,$F6,$F8,$FB,$FE  ; val=52
    FCB $00,$02,$05,$08,$0A,$0D,$0F,$12,$14,$16,$19,$1B,$1D,$1F,$22,$23,$25,$27,$29,$2A,$2C,$2D,$2E,$30,$30,$32,$33,$33,$34,$34,$34,$35,$35,$35,$34,$34,$34,$33,$33,$32,$30,$30,$2E,$2D,$2C,$2A,$29,$27,$25,$23,$22,$1F,$1D,$1B,$19,$16,$14,$12,$0F,$0D,$0A,$08,$05,$02,$00,$FE,$FB,$F8,$F6,$F3,$F1,$EE,$EC,$EA,$E7,$E5,$E3,$E1,$DE,$DD,$DB,$D9,$D7,$D6,$D4,$D3,$D2,$D0,$D0,$CE,$CD,$CD,$CC,$CC,$CC,$CB,$CB,$CB,$CC,$CC,$CC,$CD,$CD,$CE,$D0,$D0,$D2,$D3,$D4,$D6,$D7,$D9,$DB,$DD,$DE,$E1,$E3,$E5,$E7,$EA,$EC,$EE,$F1,$F3,$F6,$F8,$FB,$FE  ; val=53
    FCB $00,$03,$05,$08,$0B,$0D,$10,$12,$15,$17,$19,$1B,$1E,$20,$22,$24,$26,$28,$29,$2B,$2D,$2E,$2F,$31,$31,$33,$33,$34,$35,$35,$35,$36,$36,$36,$35,$35,$35,$34,$33,$33,$31,$31,$2F,$2E,$2D,$2B,$29,$28,$26,$24,$22,$20,$1E,$1B,$19,$17,$15,$12,$10,$0D,$0B,$08,$05,$03,$00,$FD,$FB,$F8,$F5,$F3,$F0,$EE,$EB,$E9,$E7,$E5,$E2,$E0,$DE,$DC,$DA,$D8,$D7,$D5,$D3,$D2,$D1,$CF,$CF,$CD,$CD,$CC,$CB,$CB,$CB,$CA,$CA,$CA,$CB,$CB,$CB,$CC,$CD,$CD,$CF,$CF,$D1,$D2,$D3,$D5,$D7,$D8,$DA,$DC,$DE,$E0,$E2,$E5,$E7,$E9,$EB,$EE,$F0,$F3,$F5,$F8,$FB,$FD  ; val=54
    FCB $00,$03,$05,$08,$0B,$0D,$10,$12,$15,$17,$1A,$1C,$1F,$21,$23,$25,$27,$28,$2A,$2C,$2E,$2F,$30,$31,$32,$34,$34,$35,$36,$36,$36,$37,$37,$37,$36,$36,$36,$35,$34,$34,$32,$31,$30,$2F,$2E,$2C,$2A,$28,$27,$25,$23,$21,$1F,$1C,$1A,$17,$15,$12,$10,$0D,$0B,$08,$05,$03,$00,$FD,$FB,$F8,$F5,$F3,$F0,$EE,$EB,$E9,$E6,$E4,$E1,$DF,$DD,$DB,$D9,$D8,$D6,$D4,$D2,$D1,$D0,$CF,$CE,$CC,$CC,$CB,$CA,$CA,$CA,$C9,$C9,$C9,$CA,$CA,$CA,$CB,$CC,$CC,$CE,$CF,$D0,$D1,$D2,$D4,$D6,$D8,$D9,$DB,$DD,$DF,$E1,$E4,$E6,$E9,$EB,$EE,$F0,$F3,$F5,$F8,$FB,$FD  ; val=55
    FCB $00,$03,$05,$08,$0B,$0E,$10,$13,$15,$18,$1A,$1C,$1F,$21,$23,$25,$27,$29,$2B,$2D,$2E,$30,$31,$32,$33,$35,$35,$36,$37,$37,$37,$38,$38,$38,$37,$37,$37,$36,$35,$35,$33,$32,$31,$30,$2E,$2D,$2B,$29,$27,$25,$23,$21,$1F,$1C,$1A,$18,$15,$13,$10,$0E,$0B,$08,$05,$03,$00,$FD,$FB,$F8,$F5,$F2,$F0,$ED,$EB,$E8,$E6,$E4,$E1,$DF,$DD,$DB,$D9,$D7,$D5,$D3,$D2,$D0,$CF,$CE,$CD,$CB,$CB,$CA,$C9,$C9,$C9,$C8,$C8,$C8,$C9,$C9,$C9,$CA,$CB,$CB,$CD,$CE,$CF,$D0,$D2,$D3,$D5,$D7,$D9,$DB,$DD,$DF,$E1,$E4,$E6,$E8,$EB,$ED,$F0,$F2,$F5,$F8,$FB,$FD  ; val=56
    FCB $00,$03,$05,$08,$0B,$0E,$10,$13,$16,$18,$1B,$1D,$20,$22,$24,$26,$28,$2A,$2C,$2D,$2F,$31,$32,$33,$34,$35,$36,$37,$38,$38,$38,$39,$39,$39,$38,$38,$38,$37,$36,$35,$34,$33,$32,$31,$2F,$2D,$2C,$2A,$28,$26,$24,$22,$20,$1D,$1B,$18,$16,$13,$10,$0E,$0B,$08,$05,$03,$00,$FD,$FB,$F8,$F5,$F2,$F0,$ED,$EA,$E8,$E5,$E3,$E0,$DE,$DC,$DA,$D8,$D6,$D4,$D3,$D1,$CF,$CE,$CD,$CC,$CB,$CA,$C9,$C8,$C8,$C8,$C7,$C7,$C7,$C8,$C8,$C8,$C9,$CA,$CB,$CC,$CD,$CE,$CF,$D1,$D3,$D4,$D6,$D8,$DA,$DC,$DE,$E0,$E3,$E5,$E8,$EA,$ED,$F0,$F2,$F5,$F8,$FB,$FD  ; val=57
    FCB $00,$03,$05,$09,$0B,$0E,$11,$13,$16,$18,$1B,$1D,$20,$22,$25,$27,$29,$2B,$2C,$2E,$30,$31,$33,$34,$35,$36,$37,$38,$39,$39,$39,$3A,$3A,$3A,$39,$39,$39,$38,$37,$36,$35,$34,$33,$31,$30,$2E,$2C,$2B,$29,$27,$25,$22,$20,$1D,$1B,$18,$16,$13,$11,$0E,$0B,$09,$05,$03,$00,$FD,$FB,$F7,$F5,$F2,$EF,$ED,$EA,$E8,$E5,$E3,$E0,$DE,$DB,$D9,$D7,$D5,$D4,$D2,$D0,$CF,$CD,$CC,$CB,$CA,$C9,$C8,$C7,$C7,$C7,$C6,$C6,$C6,$C7,$C7,$C7,$C8,$C9,$CA,$CB,$CC,$CD,$CF,$D0,$D2,$D4,$D5,$D7,$D9,$DB,$DE,$E0,$E3,$E5,$E8,$EA,$ED,$EF,$F2,$F5,$F7,$FB,$FD  ; val=58
    FCB $00,$03,$06,$09,$0C,$0E,$11,$14,$17,$19,$1C,$1E,$21,$23,$25,$27,$29,$2B,$2D,$2F,$31,$32,$34,$35,$36,$37,$38,$39,$3A,$3A,$3A,$3B,$3B,$3B,$3A,$3A,$3A,$39,$38,$37,$36,$35,$34,$32,$31,$2F,$2D,$2B,$29,$27,$25,$23,$21,$1E,$1C,$19,$17,$14,$11,$0E,$0C,$09,$06,$03,$00,$FD,$FA,$F7,$F4,$F2,$EF,$EC,$E9,$E7,$E4,$E2,$DF,$DD,$DB,$D9,$D7,$D5,$D3,$D1,$CF,$CE,$CC,$CB,$CA,$C9,$C8,$C7,$C6,$C6,$C6,$C5,$C5,$C5,$C6,$C6,$C6,$C7,$C8,$C9,$CA,$CB,$CC,$CE,$CF,$D1,$D3,$D5,$D7,$D9,$DB,$DD,$DF,$E2,$E4,$E7,$E9,$EC,$EF,$F2,$F4,$F7,$FA,$FD  ; val=59
    FCB $00,$03,$06,$09,$0C,$0F,$11,$14,$17,$19,$1C,$1E,$21,$24,$26,$28,$2A,$2C,$2E,$30,$32,$33,$35,$36,$37,$38,$39,$3A,$3B,$3B,$3B,$3C,$3C,$3C,$3B,$3B,$3B,$3A,$39,$38,$37,$36,$35,$33,$32,$30,$2E,$2C,$2A,$28,$26,$24,$21,$1E,$1C,$19,$17,$14,$11,$0F,$0C,$09,$06,$03,$00,$FD,$FA,$F7,$F4,$F1,$EF,$EC,$E9,$E7,$E4,$E2,$DF,$DC,$DA,$D8,$D6,$D4,$D2,$D0,$CE,$CD,$CB,$CA,$C9,$C8,$C7,$C6,$C5,$C5,$C5,$C4,$C4,$C4,$C5,$C5,$C5,$C6,$C7,$C8,$C9,$CA,$CB,$CD,$CE,$D0,$D2,$D4,$D6,$D8,$DA,$DC,$DF,$E2,$E4,$E7,$E9,$EC,$EF,$F1,$F4,$F7,$FA,$FD  ; val=60
    FCB $00,$03,$06,$09,$0C,$0F,$12,$14,$17,$1A,$1D,$1F,$22,$24,$27,$29,$2B,$2D,$2F,$31,$33,$34,$35,$37,$38,$39,$3A,$3B,$3C,$3C,$3C,$3D,$3D,$3D,$3C,$3C,$3C,$3B,$3A,$39,$38,$37,$35,$34,$33,$31,$2F,$2D,$2B,$29,$27,$24,$22,$1F,$1D,$1A,$17,$14,$12,$0F,$0C,$09,$06,$03,$00,$FD,$FA,$F7,$F4,$F1,$EE,$EC,$E9,$E6,$E3,$E1,$DE,$DC,$D9,$D7,$D5,$D3,$D1,$CF,$CD,$CC,$CB,$C9,$C8,$C7,$C6,$C5,$C4,$C4,$C4,$C3,$C3,$C3,$C4,$C4,$C4,$C5,$C6,$C7,$C8,$C9,$CB,$CC,$CD,$CF,$D1,$D3,$D5,$D7,$D9,$DC,$DE,$E1,$E3,$E6,$E9,$EC,$EE,$F1,$F4,$F7,$FA,$FD  ; val=61
    FCB $00,$03,$06,$09,$0C,$0F,$12,$15,$18,$1A,$1D,$1F,$22,$25,$27,$29,$2C,$2E,$2F,$31,$33,$35,$36,$38,$39,$3A,$3B,$3C,$3D,$3D,$3D,$3E,$3E,$3E,$3D,$3D,$3D,$3C,$3B,$3A,$39,$38,$36,$35,$33,$31,$2F,$2E,$2C,$29,$27,$25,$22,$1F,$1D,$1A,$18,$15,$12,$0F,$0C,$09,$06,$03,$00,$FD,$FA,$F7,$F4,$F1,$EE,$EB,$E8,$E6,$E3,$E1,$DE,$DB,$D9,$D7,$D4,$D2,$D1,$CF,$CD,$CB,$CA,$C8,$C7,$C6,$C5,$C4,$C3,$C3,$C3,$C2,$C2,$C2,$C3,$C3,$C3,$C4,$C5,$C6,$C7,$C8,$CA,$CB,$CD,$CF,$D1,$D2,$D4,$D7,$D9,$DB,$DE,$E1,$E3,$E6,$E8,$EB,$EE,$F1,$F4,$F7,$FA,$FD  ; val=62
    FCB $00,$03,$06,$09,$0C,$0F,$12,$15,$18,$1B,$1E,$20,$23,$25,$28,$2A,$2C,$2E,$30,$32,$34,$36,$37,$39,$3A,$3B,$3C,$3D,$3E,$3E,$3E,$3F,$3F,$3F,$3E,$3E,$3E,$3D,$3C,$3B,$3A,$39,$37,$36,$34,$32,$30,$2E,$2C,$2A,$28,$25,$23,$20,$1E,$1B,$18,$15,$12,$0F,$0C,$09,$06,$03,$00,$FD,$FA,$F7,$F4,$F1,$EE,$EB,$E8,$E5,$E2,$E0,$DD,$DB,$D8,$D6,$D4,$D2,$D0,$CE,$CC,$CA,$C9,$C7,$C6,$C5,$C4,$C3,$C2,$C2,$C2,$C1,$C1,$C1,$C2,$C2,$C2,$C3,$C4,$C5,$C6,$C7,$C9,$CA,$CC,$CE,$D0,$D2,$D4,$D6,$D8,$DB,$DD,$E0,$E2,$E5,$E8,$EB,$EE,$F1,$F4,$F7,$FA,$FD  ; val=63

; ============================================================================
; SMUL8 - Signed 8x8 multiply, result = (A * B) / 128  (i8)  [kept for compat]
; ============================================================================
; Input:  A = op1 (i8), B = op2 (i8)
; Output: A = result (i8)
; Destroys: B  (no RAM touched — sign tracked with branches)
SMUL8:
TSTA
BPL SMUL8_AP        ; A >= 0?
NEGA
TSTB
BPL SMUL8_NEGNEG    ; A<0, B: check sign
NEGB                ; A<0, B<0 -> result positive
MUL
ASLB
ROLA
RTS
SMUL8_NEGNEG:           ; A<0, B>=0 -> result negative
MUL
ASLB
ROLA
NEGA
RTS
SMUL8_AP:               ; A >= 0
TSTB
BPL SMUL8_POSPOS    ; A>=0, B>=0 -> result positive
NEGB                ; A>=0, B<0 -> result negative
MUL
ASLB
ROLA
NEGA
RTS
SMUL8_POSPOS:
MUL
ASLB
ROLA
RTS

; ============================================================================
; SMUL_LUT - LUT-based signed 8×8 multiply, result = (A * sin(B*2π/128)) / 128
; ============================================================================
; Input:  A = val (i8, |val|≤63), B = angle index (0-127)
;         Y = SMUL_PROD base address (caller pre-loads: LDY #SMUL_PROD)
; Output: A = result (i8)
; Strategy: LSRA trick — D = (|val|/2)*256 + (angle | (bit0*128)) → table offset
;           LDA D,Y — 7 cycles vs LDX+LEAX+LDA = 12 cycles. Saves 5c per call.
; Destroys: B  (Y preserved)
SMUL_LUT:
TSTA
BPL SMUL_LUT_P      ; A >= 0 ?
; --- negative val ---
NEGA                ; A = |val|
LSRA                ; A = |val|/2,  C = |val| bit0
BCC SMUL_LUT_N1
ORB #$80
SMUL_LUT_N1:
LDA D,Y             ; table[|val|/2][angle]
NEGA
RTS
SMUL_LUT_P:
LSRA                ; A = val/2,  C = val bit0
BCC SMUL_LUT_P1
ORB #$80
SMUL_LUT_P1:
LDA D,Y
RTS

; ============================================================================
; DV3D_ROTATE - Apply X/Y/Z Euler rotation to a single point (inlined LUT)
; ============================================================================
; Input:  ROT3D_RX, ROT3D_RY, ROT3D_RZ (i8 world coords, |val|≤63)
;         ROT3D_AX/AY/AZ = raw sin angle indices (0-127)
;         ROT3D_COS_X/Y/Z = cos angle offsets: (angle+32)&0x7F
;         ROT3D_OX, ROT3D_OY (i8 screen offsets)
; Output: ROT3D_SCR_X, ROT3D_SCR_Y
; Destroys: A, B, X, Y, ROT3D_TEMP, ROT3D_TEMP2, ROT3D_Y1, ROT3D_Z1, ROT3D_X2
DV3D_ROTATE:
LDY #SMUL_PROD      ; Y = table base — shared by all inlined SMUL_LUT calls
; -- X-axis rotation: y1 = y*cX - z*sX,  z1 = y*sX + z*cX --
LDA >ROT3D_RY
LDB >ROT3D_COS_X
    TSTA
BPL SL_P_0
NEGA
LSRA
BCC SL_N1_0
ORB #$80
SL_N1_0:
LDA D,Y
NEGA
BRA SL_END_0
SL_P_0:
LSRA
BCC SL_P1_0
ORB #$80
SL_P1_0:
LDA D,Y
SL_END_0:
    STA >ROT3D_TEMP
LDA >ROT3D_RZ
LDB >ROT3D_AX
    TSTA
BPL SL_P_1
NEGA
LSRA
BCC SL_N1_1
ORB #$80
SL_N1_1:
LDA D,Y
NEGA
BRA SL_END_1
SL_P_1:
LSRA
BCC SL_P1_1
ORB #$80
SL_P1_1:
LDA D,Y
SL_END_1:
    STA >ROT3D_TEMP2
LDA >ROT3D_TEMP
SUBA >ROT3D_TEMP2
STA >ROT3D_Y1

LDA >ROT3D_RY
LDB >ROT3D_AX
    TSTA
BPL SL_P_2
NEGA
LSRA
BCC SL_N1_2
ORB #$80
SL_N1_2:
LDA D,Y
NEGA
BRA SL_END_2
SL_P_2:
LSRA
BCC SL_P1_2
ORB #$80
SL_P1_2:
LDA D,Y
SL_END_2:
    STA >ROT3D_TEMP
LDA >ROT3D_RZ
LDB >ROT3D_COS_X
    TSTA
BPL SL_P_3
NEGA
LSRA
BCC SL_N1_3
ORB #$80
SL_N1_3:
LDA D,Y
NEGA
BRA SL_END_3
SL_P_3:
LSRA
BCC SL_P1_3
ORB #$80
SL_P1_3:
LDA D,Y
SL_END_3:
    ADDA >ROT3D_TEMP
STA >ROT3D_Z1

; -- Y-axis rotation: x2 = x*cY + z1*sY --
LDA >ROT3D_RX
LDB >ROT3D_COS_Y
    TSTA
BPL SL_P_4
NEGA
LSRA
BCC SL_N1_4
ORB #$80
SL_N1_4:
LDA D,Y
NEGA
BRA SL_END_4
SL_P_4:
LSRA
BCC SL_P1_4
ORB #$80
SL_P1_4:
LDA D,Y
SL_END_4:
    STA >ROT3D_TEMP
LDA >ROT3D_Z1
LDB >ROT3D_AY
    TSTA
BPL SL_P_5
NEGA
LSRA
BCC SL_N1_5
ORB #$80
SL_N1_5:
LDA D,Y
NEGA
BRA SL_END_5
SL_P_5:
LSRA
BCC SL_P1_5
ORB #$80
SL_P1_5:
LDA D,Y
SL_END_5:
    ADDA >ROT3D_TEMP
STA >ROT3D_X2

; -- Z-axis rotation: sx = x2*cZ - y1*sZ + OX,  sy = x2*sZ + y1*cZ + OY --
LDA >ROT3D_X2
LDB >ROT3D_COS_Z
    TSTA
BPL SL_P_6
NEGA
LSRA
BCC SL_N1_6
ORB #$80
SL_N1_6:
LDA D,Y
NEGA
BRA SL_END_6
SL_P_6:
LSRA
BCC SL_P1_6
ORB #$80
SL_P1_6:
LDA D,Y
SL_END_6:
    STA >ROT3D_TEMP
LDA >ROT3D_Y1
LDB >ROT3D_AZ
    TSTA
BPL SL_P_7
NEGA
LSRA
BCC SL_N1_7
ORB #$80
SL_N1_7:
LDA D,Y
NEGA
BRA SL_END_7
SL_P_7:
LSRA
BCC SL_P1_7
ORB #$80
SL_P1_7:
LDA D,Y
SL_END_7:
    STA >ROT3D_TEMP2
LDA >ROT3D_TEMP
SUBA >ROT3D_TEMP2
ADDA >ROT3D_OX
STA >ROT3D_SCR_X

LDA >ROT3D_X2
LDB >ROT3D_AZ
    TSTA
BPL SL_P_8
NEGA
LSRA
BCC SL_N1_8
ORB #$80
SL_N1_8:
LDA D,Y
NEGA
BRA SL_END_8
SL_P_8:
LSRA
BCC SL_P1_8
ORB #$80
SL_P1_8:
LDA D,Y
SL_END_8:
    STA >ROT3D_TEMP
LDA >ROT3D_Y1
LDB >ROT3D_COS_Z
    TSTA
BPL SL_P_9
NEGA
LSRA
BCC SL_N1_9
ORB #$80
SL_N1_9:
LDA D,Y
NEGA
BRA SL_END_9
SL_P_9:
LSRA
BCC SL_P1_9
ORB #$80
SL_P1_9:
LDA D,Y
SL_END_9:
    ADDA >ROT3D_TEMP
ADDA >ROT3D_OY
STA >ROT3D_SCR_Y
RTS

; ============================================================================
; DV3D_MOVETO - Move beam to absolute (X,Y) using direct VIA (same as DSWM)
; ============================================================================
; Input:  ROT3D_TEMP=dy, ROT3D_TEMP2=dx (delta from current beam pos)
;         DP must be $D0 on entry
; Destroys: A
; On exit: PB=1 (ready for draw loop)
DV3D_MOVETO:
LDA >ROT3D_TEMP     ; dy
STA VIA_port_a      ; Y to DAC
CLR VIA_port_b      ; PB=0: enable mux, beam tracks Y
NOP                 ; settling
LDA #$CE
STA VIA_cntl        ; PCR=$CE: /ZERO high, integrators active
CLR VIA_shift_reg   ; SR=0: beam off during move
INC VIA_port_b      ; PB=1: lock direction
LDA >ROT3D_TEMP2    ; dx
STA VIA_port_a      ; X to DAC
LDA #$7F
STA VIA_t1_cnt_lo   ; T1=$7F — same scale as DSWM
CLR VIA_t1_cnt_hi   ; start timer (ramp)
DV3D_MOVETO_WAIT:
LDA VIA_int_flags
ANDA #$40
BEQ DV3D_MOVETO_WAIT
RTS

; ============================================================================
; DV3D_DRAWLINE - Draw line with delta (dy,dx) using direct VIA (same as DSWM)
; ============================================================================
; Input:  ROT3D_TEMP=dy, ROT3D_TEMP2=dx
;         PB=1 on entry (left by previous moveto or drawline)
;         DP must be $D0 on entry
; Destroys: A
; On exit: PB=1
DV3D_DRAWLINE:
LDA >ROT3D_TEMP     ; dy
STA VIA_port_a      ; DY to DAC (PB=1: integrators hold)
CLR VIA_port_b      ; PB=0: enable mux, set direction
NOP
NOP
NOP                 ; settling (~same as DSWM)
INC VIA_port_b      ; PB=1: lock direction
LDA >ROT3D_TEMP2    ; dx
STA VIA_port_a      ; DX to DAC
LDA #$FF
STA VIA_shift_reg   ; SR=$FF: beam ON
CLR VIA_t1_cnt_hi   ; start T1 ramp (lo already $7F from moveto — reuse)
DV3D_DRAWLINE_WAIT:
LDA VIA_int_flags
ANDA #$40
BEQ DV3D_DRAWLINE_WAIT
CLR VIA_shift_reg   ; beam OFF
RTS

; ============================================================================
; DRAW_VECTOR_3D_RUNTIME - Draw 3D-rotated vector (vertex-dedup + LUT version)
; ============================================================================
; Input:  X = pointer to _NAME_3D_DATA (vertex-indexed format)
;         ROT3D_AX, ROT3D_AY, ROT3D_AZ = raw angles (0-127)
;         ROT3D_OX, ROT3D_OY = screen offsets
; Data format:
;   FDB vertex_count         ; unique vertex count (high byte skipped)
;   FCB x,y,z × count        ; vertex table (coords ±63)
;   FDB path_count           ; path count (high byte skipped)
;   per path: FCB pt_count, closed, idx0, idx1, ...
; Uses direct VIA access (DP=$D0 required) — same scale as DRAW_VECTOR/DSWM.
; Destroys: A, B, X, U, all ROT3D_* vars
DRAW_VECTOR_3D_RUNTIME:
TFR X,U             ; U = ROM data pointer

; --- Compute cos angle offsets: ROT3D_COS_X = (AX+32)&0x7F, etc. ---
LDA >ROT3D_AX
ADDA #32
ANDA #$7F
STA >ROT3D_COS_X
LDA >ROT3D_AY
ADDA #32
ANDA #$7F
STA >ROT3D_COS_Y
LDA >ROT3D_AZ
ADDA #32
ANDA #$7F
STA >ROT3D_COS_Z

; --- Phase 1: rotate unique vertices → ROT3D_VBUF ---
LDA ,U+             ; skip high byte of FDB vertex_count
LDB ,U+             ; B = vertex count
STB >ROT3D_PC
LDX #ROT3D_VBUF     ; X = write ptr into RAM cache

DV3D_VERT_LOOP:
TST >ROT3D_PC
BEQ DV3D_VERTS_DONE
DEC >ROT3D_PC
LDA ,U+
STA >ROT3D_RX
LDA ,U+
STA >ROT3D_RY
LDA ,U+
STA >ROT3D_RZ
PSHS X,U            ; save VBUF write ptr and ROM data ptr (DV3D_ROTATE uses X,Y)
JSR DV3D_ROTATE     ; -> ROT3D_SCR_X, ROT3D_SCR_Y
PULS X,U            ; Y was clobbered but not needed outside DV3D_ROTATE
LDA >ROT3D_SCR_X
STA ,X+
LDA >ROT3D_SCR_Y
STA ,X+
BRA DV3D_VERT_LOOP

DV3D_VERTS_DONE:
; U now points to FDB path_count in ROM
; Switch to DP=$D0 for direct VIA access (same as DSWM)
LDA #$D0
TFR A,DP

; --- Reset integrators (DSWM-style: PB sequence + PCR) ---
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

; Set intensity ($7F) via Port A + Z-axis strobe (DSWM-style)
LDA #$7F
STA VIA_port_a
LDA #$04
STA VIA_port_b
LDA #$01
STA VIA_port_b

; Beam at (0,0) after reset — PREV tracks beam position
CLR >ROT3D_PREV_X
CLR >ROT3D_PREV_Y
; T1 lo pre-loaded — reused by DV3D_DRAWLINE
LDA #$7F
STA VIA_t1_cnt_lo

; --- Phase 2: draw paths using VBUF lookup ---
LDA ,U+             ; skip high byte of FDB path_count
LDB ,U+             ; B = path count
STB >ROT3D_PC

DV3D_PATH_LOOP:
TST >ROT3D_PC
LBEQ DV3D_ALL_DONE
DEC >ROT3D_PC

LDB ,U+             ; B = point count for this path
STB >ROT3D_PT_REM
LDA ,U+             ; A = closed flag
STA >ROT3D_CLOSED

; Look up first vertex from VBUF
LDB ,U+             ; B = vertex index
ASLB                ; B = index*2 (VBUF stride = 2 bytes: x', y')
LDX #ROT3D_VBUF
ABX                 ; X = &VBUF[idx*2]
LDA ,X
STA >ROT3D_FIRST_X
LDA 1,X
STA >ROT3D_FIRST_Y

; Moveto: delta from current beam position (PREV)
LDA >ROT3D_FIRST_Y
SUBA >ROT3D_PREV_Y
STA >ROT3D_TEMP     ; dy
LDA >ROT3D_FIRST_X
SUBA >ROT3D_PREV_X
STA >ROT3D_TEMP2    ; dx
JSR DV3D_MOVETO     ; direct VIA move (T1=$7F, same scale as DSWM)

LDA >ROT3D_FIRST_X
STA >ROT3D_PREV_X
LDA >ROT3D_FIRST_Y
STA >ROT3D_PREV_Y
DEC >ROT3D_PT_REM

DV3D_SEG_LOOP:
TST >ROT3D_PT_REM
BEQ DV3D_CLOSE_CHECK
DEC >ROT3D_PT_REM

LDB ,U+             ; B = vertex index
ASLB
LDX #ROT3D_VBUF
ABX                 ; X = &VBUF[idx*2]
; Compute dx, update PREV_X: new_X - PREV_X = dx; new_X = dx + PREV_X
LDA ,X              ; new_X
SUBA >ROT3D_PREV_X  ; A = dx
STA >ROT3D_TEMP2    ; save dx
ADDA >ROT3D_PREV_X  ; A = new_X again
STA >ROT3D_PREV_X
; Compute dy, update PREV_Y
LDA 1,X             ; new_Y
SUBA >ROT3D_PREV_Y  ; A = dy
STA >ROT3D_TEMP     ; save dy
ADDA >ROT3D_PREV_Y  ; A = new_Y again
STA >ROT3D_PREV_Y
JSR DV3D_DRAWLINE
BRA DV3D_SEG_LOOP

DV3D_CLOSE_CHECK:
TST >ROT3D_CLOSED
BEQ DV3D_NEXT_PATH

LDA >ROT3D_FIRST_Y
SUBA >ROT3D_PREV_Y
STA >ROT3D_TEMP
LDA >ROT3D_FIRST_X
SUBA >ROT3D_PREV_X
STA >ROT3D_TEMP2
JSR DV3D_DRAWLINE
LDA >ROT3D_FIRST_X
STA >ROT3D_PREV_X
LDA >ROT3D_FIRST_Y
STA >ROT3D_PREV_Y

DV3D_NEXT_PATH:
LBRA DV3D_PATH_LOOP

DV3D_ALL_DONE:
; Restore DP=$C8 for normal RAM access
JSR $F1AF
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
PRINT_TEXT_STR_3327403:
    FCC "logo"
    FCB $80          ; Vectrex string terminator

;***************************************************************************
; 3D COMPACT DATA TABLES (for DRAW_VECTOR_3D)
;***************************************************************************


; 3D vertex-indexed data for DRAW_VECTOR_3D (12 unique verts, 1 paths, 13 total point refs)
_LOGO_3D_DATA:
    FDB 12               ; vertex count (unique)
    FCB $E9,$3F,$00          ; vert 0: x=-23,y=63,z=0
    FCB $E9,$32,$00          ; vert 1: x=-23,y=50,z=0
    FCB $DE,$32,$00          ; vert 2: x=-34,y=50,z=0
    FCB $DE,$17,$00          ; vert 3: x=-34,y=23,z=0
    FCB $E9,$17,$00          ; vert 4: x=-23,y=23,z=0
    FCB $E9,$0F,$00          ; vert 5: x=-23,y=15,z=0
    FCB $03,$0F,$00          ; vert 6: x=3,y=15,z=0
    FCB $03,$16,$00          ; vert 7: x=3,y=22,z=0
    FCB $0C,$16,$00          ; vert 8: x=12,y=22,z=0
    FCB $0C,$32,$00          ; vert 9: x=12,y=50,z=0
    FCB $03,$32,$00          ; vert 10: x=3,y=50,z=0
    FCB $03,$3F,$00          ; vert 11: x=3,y=63,z=0
    FDB 1               ; path count
    FCB 13               ; path 0: point count
    FCB 0               ; path 0: closed flag
    FCB 0               ; vertex index
    FCB 1               ; vertex index
    FCB 2               ; vertex index
    FCB 3               ; vertex index
    FCB 4               ; vertex index
    FCB 5               ; vertex index
    FCB 6               ; vertex index
    FCB 7               ; vertex index
    FCB 8               ; vertex index
    FCB 9               ; vertex index
    FCB 10               ; vertex index
    FCB 11               ; vertex index
    FCB 0               ; vertex index

