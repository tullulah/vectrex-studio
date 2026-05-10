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
    FCC "DRAW_VECTOR"
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
DRAW_LINE_ARGS       EQU $C880+$24   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$2E   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$30   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$32   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$33   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$34   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$36   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
DRAW_SCALE           EQU $C880+$38   ; Current T1 scale for Draw_Sync_List_At_With_Mirrors ($7F=normal) (1 bytes)
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
    ; TODO: Statement Pass { source_line: 10 }
    CLR >$C811  ; Force-clear Vec_Buttons before first loop() frame

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: platform (21 paths) with mirror + intensity
    LDD #0
    TFR B,A       ; X position (low byte) — B already holds it
    STA DRAW_VEC_X
    LDD #50
    TFR B,A       ; Y position (low byte) — B already holds it
    STA DRAW_VEC_Y
    LDD #0
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_0_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_0_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_0_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_0_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_0_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_0_CALL:
    ; Set intensity override for drawing
    LDD #0
    TFR B,A       ; Intensity (0-127) — B already holds it
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDA #$18
    STA >$D00B       ; ACR=$18: SR shift-out mode for drawing
    LDX #_PLATFORM_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH7  ; Load path 7
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH8  ; Load path 8
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH9  ; Load path 9
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH10  ; Load path 10
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH11  ; Load path 11
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH12  ; Load path 12
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH13  ; Load path 13
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH14  ; Load path 14
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH15  ; Load path 15
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH16  ; Load path 16
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH17  ; Load path 17
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH18  ; Load path 18
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH19  ; Load path 19
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLATFORM_PATH20  ; Load path 20
    JSR Draw_Sync_List_At_With_Mirrors
    LDA #$98
    STA >$D00B       ; ACR=$98: Restore BIOS standard (T1PB7 output)
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    RTS

;***************************************************************************
; EMBEDDED ASSETS (vectors, music, levels, SFX)
;***************************************************************************

; Generated from platform.vec (Malban Draw_Sync_List format)
; Total paths: 21, points: 76
; X bounds: min=-58, max=57, width=115
; Center: (0, -56)

_PLATFORM_WIDTH EQU 115
_PLATFORM_HALF_WIDTH EQU 57
_PLATFORM_HEIGHT EQU 131
_PLATFORM_HALF_HEIGHT EQU 65
_PLATFORM_CENTER_X EQU 0
_PLATFORM_CENTER_Y EQU -56

_PLATFORM_VECTORS:  ; Main entry (header + 21 path(s))
    FCB 21               ; path_count (runtime metadata)
    FDB _PLATFORM_PATH0        ; pointer to path 0
    FDB _PLATFORM_PATH1        ; pointer to path 1
    FDB _PLATFORM_PATH2        ; pointer to path 2
    FDB _PLATFORM_PATH3        ; pointer to path 3
    FDB _PLATFORM_PATH4        ; pointer to path 4
    FDB _PLATFORM_PATH5        ; pointer to path 5
    FDB _PLATFORM_PATH6        ; pointer to path 6
    FDB _PLATFORM_PATH7        ; pointer to path 7
    FDB _PLATFORM_PATH8        ; pointer to path 8
    FDB _PLATFORM_PATH9        ; pointer to path 9
    FDB _PLATFORM_PATH10        ; pointer to path 10
    FDB _PLATFORM_PATH11        ; pointer to path 11
    FDB _PLATFORM_PATH12        ; pointer to path 12
    FDB _PLATFORM_PATH13        ; pointer to path 13
    FDB _PLATFORM_PATH14        ; pointer to path 14
    FDB _PLATFORM_PATH15        ; pointer to path 15
    FDB _PLATFORM_PATH16        ; pointer to path 16
    FDB _PLATFORM_PATH17        ; pointer to path 17
    FDB _PLATFORM_PATH18        ; pointer to path 18
    FDB _PLATFORM_PATH19        ; pointer to path 19
    FDB _PLATFORM_PATH20        ; pointer to path 20

_PLATFORM_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $2F,$04,0,0        ; path0: header (y=47, x=4)
    FCB $FF,$12,$00          ; flag=-1, dy=18, dx=0
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $41,$F9,0,0        ; path1: header (y=65, x=-7)
    FCB $FF,$EE,$00          ; flag=-1, dy=-18, dx=0
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $2F,$EE,0,0        ; path2: header (y=47, x=-18)
    FCB $FF,$12,$00          ; flag=-1, dy=18, dx=0
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $41,$E1,0,0        ; path3: header (y=65, x=-31)
    FCB $FF,$EE,$00          ; flag=-1, dy=-18, dx=0
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $2F,$D6,0,0        ; path4: header (y=47, x=-42)
    FCB $FF,$12,$00          ; flag=-1, dy=18, dx=0
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $41,$CB,0,0        ; path5: header (y=65, x=-53)
    FCB $FF,$EE,$00          ; flag=-1, dy=-18, dx=0
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH6:    ; Path 6
    FCB 85              ; path6: intensity
    FCB $36,$C6,0,0        ; path6: header (y=54, x=-58)
    FCB $FF,$F9,$05          ; flag=-1, dy=-7, dx=5
    FCB $FF,$09,$05          ; flag=-1, dy=9, dx=5
    FCB $FF,$F7,$06          ; flag=-1, dy=-9, dx=6
    FCB $FF,$09,$06          ; flag=-1, dy=9, dx=6
    FCB $FF,$F7,$05          ; flag=-1, dy=-9, dx=5
    FCB $FF,$09,$07          ; flag=-1, dy=9, dx=7
    FCB $FF,$F7,$06          ; flag=-1, dy=-9, dx=6
    FCB $FF,$09,$06          ; flag=-1, dy=9, dx=6
    FCB $FF,$F7,$05          ; flag=-1, dy=-9, dx=5
    FCB $FF,$09,$06          ; flag=-1, dy=9, dx=6
    FCB $FF,$F7,$05          ; flag=-1, dy=-9, dx=5
    FCB $FF,$09,$07          ; flag=-1, dy=9, dx=7
    FCB $FF,$F7,$06          ; flag=-1, dy=-9, dx=6
    FCB $FF,$09,$05          ; flag=-1, dy=9, dx=5
    FCB $FF,$F7,$06          ; flag=-1, dy=-9, dx=6
    FCB $FF,$09,$06          ; flag=-1, dy=9, dx=6
    FCB $FF,$F7,$06          ; flag=-1, dy=-9, dx=6
    FCB $FF,$09,$05          ; flag=-1, dy=9, dx=5
    FCB $FF,$F7,$06          ; flag=-1, dy=-9, dx=6
    FCB $FF,$08,$06          ; flag=-1, dy=8, dx=6
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH7:    ; Path 7
    FCB 85              ; path7: intensity
    FCB $3D,$39,0,0        ; path7: header (y=61, x=57)
    FCB $FF,$00,$8D          ; flag=-1, dy=0, dx=-115
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH8:    ; Path 8
    FCB 85              ; path8: intensity
    FCB $41,$C6,0,0        ; path8: header (y=65, x=-58)
    FCB $FF,$00,$73          ; flag=-1, dy=0, dx=115
    FCB $FF,$EE,$00          ; flag=-1, dy=-18, dx=0
    FCB $FF,$00,$8D          ; flag=-1, dy=0, dx=-115
    FCB $FF,$12,$00          ; flag=-1, dy=18, dx=0
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH9:    ; Path 9
    FCB 85              ; path9: intensity
    FCB $10,$C7,0,0        ; path9: header (y=16, x=-57)
    FCB $FF,$AF,$00          ; flag=-1, dy=-81, dx=0
    FCB $FF,$00,$1D          ; flag=-1, dy=0, dx=29
    FCB $FF,$51,$00          ; flag=-1, dy=81, dx=0
    FCB $FF,$00,$E3          ; flag=-1, dy=0, dx=-29
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH10:    ; Path 10
    FCB 85              ; path10: intensity
    FCB $10,$C7,0,0        ; path10: header (y=16, x=-57)
    FCB $FF,$F6,$0D          ; flag=-1, dy=-10, dx=13
    FCB $FF,$F9,$F3          ; flag=-1, dy=-7, dx=-13
    FCB $FF,$F9,$0D          ; flag=-1, dy=-7, dx=13
    FCB $FF,$F8,$F3          ; flag=-1, dy=-8, dx=-13
    FCB $FF,$F8,$0D          ; flag=-1, dy=-8, dx=13
    FCB $FF,$F4,$F3          ; flag=-1, dy=-12, dx=-13
    FCB $FF,$F9,$0C          ; flag=-1, dy=-7, dx=12
    FCB $FF,$F8,$F4          ; flag=-1, dy=-8, dx=-12
    FCB $FF,$F9,$0D          ; flag=-1, dy=-7, dx=13
    FCB $FF,$F9,$F3          ; flag=-1, dy=-7, dx=-13
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $C6,$C7,0,0        ; path11: header (y=-58, x=-57)
    FCB $FF,$00,$0D          ; flag=-1, dy=0, dx=13
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH12:    ; Path 12
    FCB 85              ; path12: intensity
    FCB $BE,$D4,0,0        ; path12: header (y=-66, x=-44)
    FCB $FF,$52,$00          ; flag=-1, dy=82, dx=0
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $06,$D4,0,0        ; path13: header (y=6, x=-44)
    FCB $FF,$00,$F3          ; flag=-1, dy=0, dx=-13
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $F8,$C7,0,0        ; path14: header (y=-8, x=-57)
    FCB $FF,$00,$0D          ; flag=-1, dy=0, dx=13
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $E8,$D4,0,0        ; path15: header (y=-24, x=-44)
    FCB $FF,$00,$F3          ; flag=-1, dy=0, dx=-13
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $D5,$C7,0,0        ; path16: header (y=-43, x=-57)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $2F,$11,0,0        ; path17: header (y=47, x=17)
    FCB $FF,$12,$00          ; flag=-1, dy=18, dx=0
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH18:    ; Path 18
    FCB 127              ; path18: intensity
    FCB $41,$1C,0,0        ; path18: header (y=65, x=28)
    FCB $FF,$EE,$00          ; flag=-1, dy=-18, dx=0
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH19:    ; Path 19
    FCB 127              ; path19: intensity
    FCB $2F,$28,0,0        ; path19: header (y=47, x=40)
    FCB $FF,$12,$00          ; flag=-1, dy=18, dx=0
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH20:    ; Path 20
    FCB 127              ; path20: intensity
    FCB $41,$33,0,0        ; path20: header (y=65, x=51)
    FCB $FF,$EE,$00          ; flag=-1, dy=-18, dx=0
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
; NOTE: Caller must ensure DP=$D0 for VIA access
LDA DRAW_VEC_INTENSITY  ; Check if intensity override is set
BNE DSWM_USE_OVERRIDE   ; If non-zero, use override
LDA ,X+                 ; Otherwise, read intensity from vector data
BRA DSWM_SET_INTENSITY
DSWM_USE_OVERRIDE:
LEAX 1,X                ; Skip intensity byte in vector data
DSWM_SET_INTENSITY:
JSR $F2AB               ; BIOS Intensity_a
LDB ,X+                 ; y_start from .vec (already relative to center)
; Check if Y mirroring is enabled
TST MIRROR_Y
BEQ DSWM_NO_NEGATE_Y
NEGB                    ; ← Negate Y if flag set
DSWM_NO_NEGATE_Y:
ADDB DRAW_VEC_Y         ; Add Y offset
LDA ,X+                 ; x_start from .vec (already relative to center)
; Check if X mirroring is enabled
TST MIRROR_X
BEQ DSWM_NO_NEGATE_X
NEGA                    ; ← Negate X if flag set
DSWM_NO_NEGATE_X:
ADDA DRAW_VEC_X         ; Add X offset
STD TEMP_YX             ; Save adjusted position
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
LDD TEMP_YX
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
TST MIRROR_Y
BEQ DSWM_NO_NEGATE_DY
NEGB                    ; ← Negate dy if flag set
DSWM_NO_NEGATE_DY:
LDA ,X+                 ; dx
; Check if X mirroring is enabled
TST MIRROR_X
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
LDA DRAW_VEC_INTENSITY  ; Check if intensity override is set
BNE DSWM_NEXT_USE_OVERRIDE   ; If non-zero, use override
LDA ,X+                 ; Otherwise, read intensity from vector data
BRA DSWM_NEXT_SET_INTENSITY
DSWM_NEXT_USE_OVERRIDE:
LEAX 1,X                ; Skip intensity byte in vector data
DSWM_NEXT_SET_INTENSITY:
PSHS A
LDB ,X+                 ; y_start
TST MIRROR_Y
BEQ DSWM_NEXT_NO_NEGATE_Y
NEGB
DSWM_NEXT_NO_NEGATE_Y:
ADDB DRAW_VEC_Y         ; Add Y offset
LDA ,X+                 ; x_start
TST MIRROR_X
BEQ DSWM_NEXT_NO_NEGATE_X
NEGA
DSWM_NEXT_NO_NEGATE_X:
ADDA DRAW_VEC_X         ; Add X offset
STD TEMP_YX
PULS A                  ; Get intensity back
JSR $F2AB
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
LDD TEMP_YX
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
;**** PRINT_TEXT String Data ****
PRINT_TEXT_STR_3180150483059:
    FCC "platform"
    FCB $80          ; Vectrex string terminator

