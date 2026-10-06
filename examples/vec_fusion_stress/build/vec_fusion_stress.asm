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
    FCC "FUSION STRESS"
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
DRAW_VEC_X_HI        EQU $C880+$0F   ; Vector draw X high byte (16-bit screen_x) (1 bytes)
DRAW_VEC_X           EQU $C880+$10   ; Vector draw X offset (1 bytes)
DRAW_VEC_Y           EQU $C880+$11   ; Vector draw Y offset (1 bytes)
MIRROR_PAD           EQU $C880+$12   ; Safety padding to prevent MIRROR flag corruption (16 bytes)
MIRROR_X             EQU $C880+$22   ; X mirror flag (0=normal, 1=flip) (1 bytes)
MIRROR_Y             EQU $C880+$23   ; Y mirror flag (0=normal, 1=flip) (1 bytes)
SLR_CUR_X            EQU $C880+$24   ; DRAW_VECTOR: clamped (visible) beam X for clipping (1 bytes)
SLR_TRUE_X           EQU $C880+$25   ; DRAW_VECTOR: 16-bit unclamped abs_x for line clipping (2 bytes)
DRAW_T1_SCALED       EQU $C880+$27   ; DRAW_VECTOR: T1 scale ($7F default for non-SHOW_LEVEL) (1 bytes)
SDCP_ABS_Y           EQU $C880+$28   ; DRAW_VECTOR: abs_y temporary for SDCP (cannot share TMPVAL — would corrupt SHOW_LEVEL's top_screen between layers) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$29   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$33   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$35   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$37   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$38   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$39   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$3B   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
DRAW_SCALE           EQU $C880+$3D   ; Current T1 scale for Draw_Sync_List_At_With_Mirrors ($7F=normal) (1 bytes)
VAR_ARG0             EQU $C880+$3E   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $C880+$40   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $C880+$42   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $C880+$44   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $C880+$46   ; Function argument 4 (16-bit) (2 bytes)
VAR_ARG5             EQU $C880+$48   ; Function argument 5 (16-bit) (2 bytes)
VAR_ARG6             EQU $C880+$4A   ; Function argument 6 (16-bit) (2 bytes)
VAR_ARG7             EQU $C880+$4C   ; Function argument 7 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $C880+$4E   ; Current ROM bank ID (multibank tracking) (1 bytes)

;***************************************************************************
; MAIN PROGRAM
;***************************************************************************

MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    CLR DRAW_VEC_INTENSITY ; 0 = use recorded/vector intensity (no override)
    LDA #$7F
    STA DRAW_SCALE        ; Default T1 scale = $7F (127 = full BIOS scale)
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
; VPy_LINE:12
    ; TODO: Statement Pass { source_line: 12 }
    CLR >$C811  ; Force-clear Vec_Buttons before first loop() frame

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
; VPy_LINE:15
; NATIVE_CALL: SET_INTENSITY at line 15
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:16
; NATIVE_CALL: DRAW_VECTOR at line 16
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: stress (index=0, 90 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_0          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #0
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_0
    LDB #$FF
.sx_pos_0:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_STRESS_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH7  ; Load path 7
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH8  ; Load path 8
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH9  ; Load path 9
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH10  ; Load path 10
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH11  ; Load path 11
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH12  ; Load path 12
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH13  ; Load path 13
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH14  ; Load path 14
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH15  ; Load path 15
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH16  ; Load path 16
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH17  ; Load path 17
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH18  ; Load path 18
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH19  ; Load path 19
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH20  ; Load path 20
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH21  ; Load path 21
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH22  ; Load path 22
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH23  ; Load path 23
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH24  ; Load path 24
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH25  ; Load path 25
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH26  ; Load path 26
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH27  ; Load path 27
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH28  ; Load path 28
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH29  ; Load path 29
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH30  ; Load path 30
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH31  ; Load path 31
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH32  ; Load path 32
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH33  ; Load path 33
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH34  ; Load path 34
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH35  ; Load path 35
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH36  ; Load path 36
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH37  ; Load path 37
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH38  ; Load path 38
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH39  ; Load path 39
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH40  ; Load path 40
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH41  ; Load path 41
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH42  ; Load path 42
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH43  ; Load path 43
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH44  ; Load path 44
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH45  ; Load path 45
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH46  ; Load path 46
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH47  ; Load path 47
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH48  ; Load path 48
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH49  ; Load path 49
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH50  ; Load path 50
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH51  ; Load path 51
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH52  ; Load path 52
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH53  ; Load path 53
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH54  ; Load path 54
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH55  ; Load path 55
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH56  ; Load path 56
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH57  ; Load path 57
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH58  ; Load path 58
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH59  ; Load path 59
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH60  ; Load path 60
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH61  ; Load path 61
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH62  ; Load path 62
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH63  ; Load path 63
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH64  ; Load path 64
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH65  ; Load path 65
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH66  ; Load path 66
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH67  ; Load path 67
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH68  ; Load path 68
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH69  ; Load path 69
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH70  ; Load path 70
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH71  ; Load path 71
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH72  ; Load path 72
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH73  ; Load path 73
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH74  ; Load path 74
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH75  ; Load path 75
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH76  ; Load path 76
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH77  ; Load path 77
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH78  ; Load path 78
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH79  ; Load path 79
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH80  ; Load path 80
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH81  ; Load path 81
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH82  ; Load path 82
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH83  ; Load path 83
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH84  ; Load path 84
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH85  ; Load path 85
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH86  ; Load path 86
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH87  ; Load path 87
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH88  ; Load path 88
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_STRESS_PATH89  ; Load path 89
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_0:
    LDD #0
    STD RESULT
    RTS

;***************************************************************************
; EMBEDDED ASSETS (vectors, music, levels, SFX)
;***************************************************************************

; Generated from stress.vec (Malban Draw_Sync_List format)
; Total paths: 90, points: 180
; X bounds: min=-100, max=100, width=200
; Center: (0, 0)

_STRESS_WIDTH EQU 200
_STRESS_HALF_WIDTH EQU 100
_STRESS_HEIGHT EQU 200
_STRESS_HALF_HEIGHT EQU 100
_STRESS_CENTER_X EQU 0
_STRESS_CENTER_Y EQU 0

_STRESS_VECTORS:  ; Main entry (header + 3 path(s))
    FDB 3               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _STRESS_PATH0        ; pointer to path 0
    FDB _STRESS_PATH1        ; pointer to path 1
    FDB _STRESS_PATH2        ; pointer to path 2

_STRESS_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $62,$11,0,0        ; path0: header (y=98, x=17)
    FCB $FF,$FB,$14          ; flag=-1, dy=-5, dx=20
    FCB $FF,$FA,$0D          ; flag=-1, dy=-6, dx=13
    FCB $FF,$F8,$0C          ; flag=-1, dy=-8, dx=12
    FCB $FF,$EC,$13          ; flag=-1, dy=-20, dx=19
    FCB $FF,$EE,$0A          ; flag=-1, dy=-18, dx=10
    FCB $FF,$F3,$05          ; flag=-1, dy=-13, dx=5
    FCB $FF,$EB,$04          ; flag=-1, dy=-21, dx=4
    FCB $FF,$E4,$FE          ; flag=-1, dy=-28, dx=-2
    FCB $FF,$F3,$FC          ; flag=-1, dy=-13, dx=-4
    FCB $FF,$ED,$F7          ; flag=-1, dy=-19, dx=-9
    FCB $FF,$F5,$F8          ; flag=-1, dy=-11, dx=-8
    FCB $FF,$F6,$F6          ; flag=-1, dy=-10, dx=-10
    FCB 2                ; End marker (path complete)

_STRESS_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $B6,$43,0,0        ; path1: header (y=-74, x=67)
    FCB $FF,$F3,$EF          ; flag=-1, dy=-13, dx=-17
    FCB $FF,$F6,$E6          ; flag=-1, dy=-10, dx=-26
    FCB $FF,$FD,$E5          ; flag=-1, dy=-3, dx=-27
    FCB $FF,$03,$EB          ; flag=-1, dy=3, dx=-21
    FCB $FF,$04,$F3          ; flag=-1, dy=4, dx=-13
    FCB $FF,$06,$F3          ; flag=-1, dy=6, dx=-13
    FCB $FF,$08,$F4          ; flag=-1, dy=8, dx=-12
    FCB $FF,$14,$ED          ; flag=-1, dy=20, dx=-19
    FCB $FF,$19,$F3          ; flag=-1, dy=25, dx=-13
    FCB $FF,$0D,$FC          ; flag=-1, dy=13, dx=-4
    FCB $FF,$0E,$FE          ; flag=-1, dy=14, dx=-2
    FCB 2                ; End marker (path complete)

_STRESS_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $F9,$9C,0,0        ; path2: header (y=-7, x=-100)
    FCB $FF,$1C,$02          ; flag=-1, dy=28, dx=2
    FCB $FF,$14,$07          ; flag=-1, dy=20, dx=7
    FCB $FF,$12,$0A          ; flag=-1, dy=18, dx=10
    FCB $FF,$14,$13          ; flag=-1, dy=20, dx=19
    FCB $FF,$0B,$12          ; flag=-1, dy=11, dx=18
    FCB $FF,$07,$14          ; flag=-1, dy=7, dx=20
    FCB $FF,$03,$15          ; flag=-1, dy=3, dx=21
    FCB $FF,$FE,$14          ; flag=-1, dy=-2, dx=20
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
PRINT_TEXT_STR_3402977716:
    FCC "stress"
    FCB $80          ; Vectrex string terminator

