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
    FCC "VPLAYTST"
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
DRAW_VEC_X           EQU $C880+$0C   ; Vector draw X offset (1 bytes)
DRAW_VEC_Y           EQU $C880+$0D   ; Vector draw Y offset (1 bytes)
DRAW_VEC_INTENSITY   EQU $C880+$0E   ; Vector intensity override (0=use vector data) (1 bytes)
MIRROR_PAD           EQU $C880+$0F   ; Safety padding to prevent MIRROR flag corruption (16 bytes)
MIRROR_X             EQU $C880+$1F   ; X mirror flag (0=normal, 1=flip) (1 bytes)
MIRROR_Y             EQU $C880+$20   ; Y mirror flag (0=normal, 1=flip) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$21   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$2B   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$2D   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$2F   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$30   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$31   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$33   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
LEVEL_PTR            EQU $C880+$35   ; Pointer to currently loaded level header (2 bytes)
LEVEL_WIDTH          EQU $C880+$37   ; Level width (legacy tile API) (1 bytes)
LEVEL_HEIGHT         EQU $C880+$38   ; Level height (legacy tile API) (1 bytes)
LEVEL_TILE_SIZE      EQU $C880+$39   ; Tile size (legacy tile API) (1 bytes)
LEVEL_Y_IDX          EQU $C880+$3A   ; SHOW_LEVEL row counter (legacy) (1 bytes)
LEVEL_X_IDX          EQU $C880+$3B   ; SHOW_LEVEL column counter (legacy) (1 bytes)
LEVEL_TEMP           EQU $C880+$3C   ; SHOW_LEVEL temporary byte (legacy) (1 bytes)
LEVEL_BG_COUNT       EQU $C880+$3D   ; BG object count (1 bytes)
LEVEL_GP_COUNT       EQU $C880+$3E   ; GP object count (1 bytes)
LEVEL_FG_COUNT       EQU $C880+$3F   ; FG object count (1 bytes)
LEVEL_BG_ROM_PTR     EQU $C880+$40   ; BG layer ROM pointer (2 bytes)
LEVEL_GP_ROM_PTR     EQU $C880+$42   ; GP layer ROM pointer (2 bytes)
LEVEL_FG_ROM_PTR     EQU $C880+$44   ; FG layer ROM pointer (2 bytes)
LEVEL_GP_PTR         EQU $C880+$46   ; GP active pointer (RAM buffer after LOAD_LEVEL) (2 bytes)
LEVEL_GP_BUFFER      EQU $C880+$48   ; GP objects RAM buffer (max 8 objects × 14 bytes) (112 bytes)
UGPC_OUTER_IDX       EQU $C880+$B8   ; GP-GP outer loop index (1 bytes)
UGPC_OUTER_MAX       EQU $C880+$B9   ; GP-GP outer loop max (count-1) (1 bytes)
UGPC_INNER_IDX       EQU $C880+$BA   ; GP-GP inner loop index (1 bytes)
UGPC_DX              EQU $C880+$BB   ; GP-GP |dx| (16-bit) (2 bytes)
UGPC_DIST            EQU $C880+$BD   ; GP-GP Manhattan distance (16-bit) (2 bytes)
UGFC_GP_IDX          EQU $C880+$BF   ; GP-FG outer loop GP index (1 bytes)
UGFC_FG_COUNT        EQU $C880+$C0   ; GP-FG inner loop FG count (1 bytes)
UGFC_DX              EQU $C880+$C1   ; GP-FG |dx| (1 bytes)
UGFC_DY              EQU $C880+$C2   ; GP-FG |dy| (1 bytes)
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

    ; Call main() for initialization
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'demo_level'
    LDX #_DEMO_LEVEL_LEVEL          ; Pointer to level data in ROM
    JSR LOAD_LEVEL_RUNTIME

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access
    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)
    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access
    ; PRINT_TEXT: Print text at position
    LDD #-55
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #120
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2344190015343208      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; ===== UPDATE_LEVEL builtin =====
    JSR UPDATE_LEVEL_RUNTIME
    LDD #0
    STD RESULT
    ; ===== SHOW_LEVEL builtin =====
    JSR SHOW_LEVEL_RUNTIME
    LDD #0
    STD RESULT
    RTS

;***************************************************************************
; EMBEDDED ASSETS (vectors, music, levels, SFX)
;***************************************************************************

; Generated from ball.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 16
; X bounds: min=-16, max=16, width=32
; Center: (0, 0)

_BALL_WIDTH EQU 32
_BALL_CENTER_X EQU 0
_BALL_CENTER_Y EQU 0

_BALL_VECTORS:  ; Main entry (header + 1 path(s))
    FCB 1               ; path_count (runtime metadata)
    FDB _BALL_PATH0        ; pointer to path 0

_BALL_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $00,$10,0,0        ; path0: header (y=0, x=16, relative to center)
    FCB $FF,$06,$FF          ; flag=-1, dy=6, dx=-1
    FCB $FF,$05,$FC          ; flag=-1, dy=5, dx=-4
    FCB $FF,$04,$FB          ; flag=-1, dy=4, dx=-5
    FCB $FF,$01,$FA          ; flag=-1, dy=1, dx=-6
    FCB $FF,$FF,$FA          ; flag=-1, dy=-1, dx=-6
    FCB $FF,$FC,$FB          ; flag=-1, dy=-4, dx=-5
    FCB $FF,$FB,$FC          ; flag=-1, dy=-5, dx=-4
    FCB $FF,$FA,$FF          ; flag=-1, dy=-6, dx=-1
    FCB $FF,$FA,$01          ; flag=-1, dy=-6, dx=1
    FCB $FF,$FB,$04          ; flag=-1, dy=-5, dx=4
    FCB $FF,$FC,$05          ; flag=-1, dy=-4, dx=5
    FCB $FF,$FF,$06          ; flag=-1, dy=-1, dx=6
    FCB $FF,$01,$06          ; flag=-1, dy=1, dx=6
    FCB $FF,$04,$05          ; flag=-1, dy=4, dx=5
    FCB $FF,$05,$04          ; flag=-1, dy=5, dx=4
    FCB $FF,$06,$01          ; flag=-1, dy=6, dx=1
    FCB 2                ; End marker (path complete)
; Generated from coin.vec (Malban Draw_Sync_List format)
; Total paths: 2, points: 7
; X bounds: min=-12, max=5, width=17
; Center: (-3, 3)

_COIN_WIDTH EQU 17
_COIN_CENTER_X EQU -3
_COIN_CENTER_Y EQU 3

_COIN_VECTORS:  ; Main entry (header + 2 path(s))
    FCB 2               ; path_count (runtime metadata)
    FDB _COIN_PATH0        ; pointer to path 0
    FDB _COIN_PATH1        ; pointer to path 1

_COIN_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $04,$03,0,0        ; path0: header (y=4, x=3, relative to center)
    FCB $FF,$F9,$05          ; flag=-1, dy=-7, dx=5
    FCB $FF,$F9,$FB          ; flag=-1, dy=-7, dx=-5
    FCB $FF,$07,$FB          ; flag=-1, dy=7, dx=-5
    FCB $FF,$07,$05          ; flag=-1, dy=7, dx=5
    FCB 2                ; End marker (path complete)

_COIN_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $FA,$F7,0,0        ; path1: header (y=-6, x=-9, relative to center)
    FCB $FF,$10,$03          ; flag=-1, dy=16, dx=3
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)
; Generated from platform.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 4
; X bounds: min=-30, max=30, width=60
; Center: (0, 2)

_PLATFORM_WIDTH EQU 60
_PLATFORM_CENTER_X EQU 0
_PLATFORM_CENTER_Y EQU 2

_PLATFORM_VECTORS:  ; Main entry (header + 1 path(s))
    FCB 1               ; path_count (runtime metadata)
    FDB _PLATFORM_PATH0        ; pointer to path 0

_PLATFORM_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $FE,$E2,0,0        ; path0: header (y=-2, x=-30, relative to center)
    FCB $FF,$00,$3C          ; flag=-1, dy=0, dx=60
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$C4          ; flag=-1, dy=0, dx=-60
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)
; Generated from spawn.vec (Malban Draw_Sync_List format)
; Total paths: 6, points: 35
; X bounds: min=-11, max=12, width=23
; Center: (0, 8)

_SPAWN_WIDTH EQU 23
_SPAWN_CENTER_X EQU 0
_SPAWN_CENTER_Y EQU 8

_SPAWN_VECTORS:  ; Main entry (header + 6 path(s))
    FCB 6               ; path_count (runtime metadata)
    FDB _SPAWN_PATH0        ; pointer to path 0
    FDB _SPAWN_PATH1        ; pointer to path 1
    FDB _SPAWN_PATH2        ; pointer to path 2
    FDB _SPAWN_PATH3        ; pointer to path 3
    FDB _SPAWN_PATH4        ; pointer to path 4
    FDB _SPAWN_PATH5        ; pointer to path 5

_SPAWN_PATH0:    ; Path 0
    FCB 80              ; path0: intensity
    FCB $00,$00,0,0        ; path0: header (y=0, x=0, relative to center)
    FCB $FF,$F0,$FA          ; flag=-1, dy=-16, dx=-6
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB $FF,$10,$FA          ; flag=-1, dy=16, dx=-6
    FCB 2                ; End marker (path complete)

_SPAWN_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $0F,$0C,0,0        ; path1: header (y=15, x=12, relative to center)
    FCB $FF,$04,$FF          ; flag=-1, dy=4, dx=-1
    FCB $FF,$04,$FE          ; flag=-1, dy=4, dx=-2
    FCB $FF,$02,$FC          ; flag=-1, dy=2, dx=-4
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB $FF,$FF,$FC          ; flag=-1, dy=-1, dx=-4
    FCB $FF,$FE,$FC          ; flag=-1, dy=-2, dx=-4
    FCB $FF,$FC,$FE          ; flag=-1, dy=-4, dx=-2
    FCB $FF,$FC,$FF          ; flag=-1, dy=-4, dx=-1
    FCB $FF,$FC,$01          ; flag=-1, dy=-4, dx=1
    FCB $FF,$FC,$02          ; flag=-1, dy=-4, dx=2
    FCB $FF,$FE,$04          ; flag=-1, dy=-2, dx=4
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB $FF,$01,$04          ; flag=-1, dy=1, dx=4
    FCB $FF,$02,$04          ; flag=-1, dy=2, dx=4
    FCB $FF,$04,$02          ; flag=-1, dy=4, dx=2
    FCB $FF,$04,$01          ; flag=-1, dy=4, dx=1
    FCB 2                ; End marker (path complete)

_SPAWN_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $EF,$FD,0,0        ; path2: header (y=-17, x=-3, relative to center)
    FCB $FF,$F9,$FC          ; flag=-1, dy=-7, dx=-4
    FCB $FF,$FF,$01          ; flag=-1, dy=-1, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_SPAWN_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $EF,$03,0,0        ; path3: header (y=-17, x=3, relative to center)
    FCB $FF,$F9,$03          ; flag=-1, dy=-7, dx=3
    FCB $FF,$FF,$FF          ; flag=-1, dy=-1, dx=-1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_SPAWN_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $F7,$FC,0,0        ; path4: header (y=-9, x=-4, relative to center)
    FCB $FF,$05,$FC          ; flag=-1, dy=5, dx=-4
    FCB $FF,$FE,$FD          ; flag=-1, dy=-2, dx=-3
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_SPAWN_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $F8,$04,0,0        ; path5: header (y=-8, x=4, relative to center)
    FCB $FF,$04,$04          ; flag=-1, dy=4, dx=4
    FCB $FF,$FD,$03          ; flag=-1, dy=-3, dx=3
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)
; ==== Level: DEMO_LEVEL ====
; Author: 
; Difficulty: medium

_DEMO_LEVEL_LEVEL:
    FDB -96  ; World bounds: xMin (16-bit signed)
    FDB 95  ; xMax (16-bit signed)
    FDB -128  ; yMin (16-bit signed)
    FDB 127  ; yMax (16-bit signed)
    FDB 0  ; Time limit (seconds)
    FDB 0  ; Target score
    FCB 0  ; Background object count
    FCB 4  ; Gameplay object count
    FCB 3  ; Foreground object count
    FDB _DEMO_LEVEL_BG_OBJECTS
    FDB _DEMO_LEVEL_GAMEPLAY_OBJECTS
    FDB _DEMO_LEVEL_FG_OBJECTS

_DEMO_LEVEL_BG_OBJECTS:

_DEMO_LEVEL_GAMEPLAY_OBJECTS:
; Object: obj_1772212957260 (enemy)
    FCB 1  ; type
    FDB -23  ; x
    FDB -74  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 255  ; velocity_x
    FCB 255  ; velocity_y
    FCB 3  ; physics_flags
    FCB 3  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _SPAWN_VECTORS  ; vector_ptr
    FDB 0  ; properties_ptr (reserved)

; Object: obj_1772212984369 (enemy)
    FCB 1  ; type
    FDB -49  ; x
    FDB 25  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 1  ; velocity_x
    FCB 0  ; velocity_y
    FCB 3  ; physics_flags
    FCB 3  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _BALL_VECTORS  ; vector_ptr
    FDB 0  ; properties_ptr (reserved)

; Object: obj_1772212988693 (enemy)
    FCB 1  ; type
    FDB 59  ; x
    FDB 12  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 255  ; velocity_y
    FCB 3  ; physics_flags
    FCB 3  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _BALL_VECTORS  ; vector_ptr
    FDB 0  ; properties_ptr (reserved)

; Object: obj_1772214807272 (enemy)
    FCB 1  ; type
    FDB -52  ; x
    FDB 68  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 255  ; velocity_x
    FCB 255  ; velocity_y
    FCB 3  ; physics_flags
    FCB 3  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _COIN_VECTORS  ; vector_ptr
    FDB 0  ; properties_ptr (reserved)


_DEMO_LEVEL_FG_OBJECTS:
; Object: obj_1772202959556 (enemy)
    FCB 1  ; type
    FDB -63  ; x
    FDB -35  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 3  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM_VECTORS  ; vector_ptr
    FDB 0  ; properties_ptr (reserved)

; Object: obj_1772202962079 (enemy)
    FCB 1  ; type
    FDB 53  ; x
    FDB -69  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 3  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM_VECTORS  ; vector_ptr
    FDB 0  ; properties_ptr (reserved)

; Object: obj_1772202964449 (enemy)
    FCB 1  ; type
    FDB 43  ; x
    FDB 44  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 3  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PLATFORM_VECTORS  ; vector_ptr
    FDB 0  ; properties_ptr (reserved)


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
    LDA >VAR_ARG1+1 ; Y coordinate
    LDB >VAR_ARG0+1 ; X coordinate
    JSR Print_Str_d
    LDA #$80
    STA >$D004      ; Restore VIA_t1_cnt_lo: Moveto_d_7F sets it to $7F, corrupting DRAW_LINE scale
    JSR $F1AF      ; DP_to_C8 - restore DP before return
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
; Timing setup
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
; === LOAD_LEVEL_RUNTIME ===
; Load level data from ROM and copy GP objects to RAM buffer
; Input:  X = pointer to level data in ROM
; Output: LEVEL_PTR = level header pointer
;         RESULT    = level header pointer (return value)
; BG and FG layers are static — read from ROM directly.
; GP layer is copied to LEVEL_GP_BUFFER (14 bytes/object).
LOAD_LEVEL_RUNTIME:
    PSHS D,X,Y,U     ; Preserve registers
    
    ; Store level pointer persistently
    STX >LEVEL_PTR
    
    ; Skip world bounds (8 bytes) + time/score (4 bytes)
    LEAX 12,X        ; X now points to object counts (+12)
    
    ; Read object counts (one byte each)
    LDB ,X+          ; B = bgCount
    STB >LEVEL_BG_COUNT
    LDB ,X+          ; B = gpCount
    STB >LEVEL_GP_COUNT
    LDB ,X+          ; B = fgCount
    STB >LEVEL_FG_COUNT
    
    ; Read layer ROM pointers (FDB, 2 bytes each)
    LDD ,X++         ; D = bgObjectsPtr
    STD >LEVEL_BG_ROM_PTR
    LDD ,X++         ; D = gpObjectsPtr
    STD >LEVEL_GP_ROM_PTR
    LDD ,X++         ; D = fgObjectsPtr
    STD >LEVEL_FG_ROM_PTR
    
    ; === Copy GP objects from ROM to RAM buffer ===
    LDB >LEVEL_GP_COUNT
    BEQ LLR_SKIP_GP  ; Skip if no GP objects
    
    ; Clear GP buffer with $FF marker (empty sentinel)
    LDA #$FF
    LDU #LEVEL_GP_BUFFER
    LDB #8           ; Max 8 objects
LLR_CLR_GP_LOOP:
    STA ,U           ; Write $FF to first byte of object slot
    LEAU 14,U        ; Advance by 14 bytes (RAM object stride)
    DECB
    BNE LLR_CLR_GP_LOOP
    
    ; Copy GP objects: ROM (20 bytes each) → RAM buffer (14 bytes each)
    LDB >LEVEL_GP_COUNT   ; Reload count after clear loop
    LDX >LEVEL_GP_ROM_PTR ; X = source (ROM)
    LDU #LEVEL_GP_BUFFER  ; U = destination (RAM)
    PSHS U               ; Save buffer start
    JSR LLR_COPY_OBJECTS  ; Copy B objects from X(ROM) to U(RAM)
    PULS D               ; Restore buffer start into D
    STD >LEVEL_GP_PTR    ; LEVEL_GP_PTR → RAM buffer
    BRA LLR_GP_DONE
    
LLR_GP_DONE:
LLR_SKIP_GP:
    
    ; Return level pointer in RESULT
    LDX >LEVEL_PTR
    STX RESULT
    
    PULS D,X,Y,U,PC  ; Restore and return
    
; === LLR_COPY_OBJECTS - Copy N ROM objects to RAM buffer ===
; Input:  B = count, X = source (ROM, 20 bytes/obj), U = dest (RAM, 14 bytes/obj)
; ROM object layout (20 bytes):
;   +0: type, +1-2: x(FDB), +3-4: y(FDB), +5-6: scale(FDB),
;   +7: rotation, +8: intensity, +9: velocity_x, +10: velocity_y,
;   +11: physics_flags, +12: collision_flags, +13: collision_size,
;   +14-15: spawn_delay(FDB), +16-17: vector_ptr(FDB), +18-19: properties_ptr(FDB)
; RAM object layout (14 bytes):
;   +0: x(low), +1: y(low), +2: scale(low), +3: rotation,
;   +4: velocity_x, +5: velocity_y, +6: physics_flags, +7: collision_flags,
;   +8: collision_size, +9: spawn_delay(low), +10-11: vector_ptr, +12-13: properties_ptr
; Clobbers: A, B, X, U
LLR_COPY_OBJECTS:
LLR_COPY_LOOP:
    TSTB
    BEQ LLR_COPY_DONE
    PSHS B           ; Save counter (LDD will clobber B)
    
    ; X points to ROM object start (+0 = type)
    LEAX 1,X         ; Skip type (+0), X now at +1 (x FDB high)
    
    ; RAM +0: x low byte (ROM +2, low byte of x FDB)
    LDA 1,X          ; ROM +2 = low byte of x FDB
    STA ,U+
    ; RAM +1: y low byte (ROM +4, low byte of y FDB)
    LDA 3,X          ; ROM +4 = low byte of y FDB
    STA ,U+
    ; RAM +2: scale low byte (ROM +6, low byte of scale FDB)
    LDA 5,X          ; ROM +6 = low byte of scale FDB
    STA ,U+
    ; RAM +3: rotation (ROM +7)
    LDA 6,X          ; ROM +7 = rotation
    STA ,U+
    ; Skip to ROM +9 (past intensity at ROM +8)
    LEAX 8,X         ; X now points to ROM +9 (velocity_x)
    ; RAM +4: velocity_x (ROM +9)
    LDA ,X+          ; ROM +9
    STA ,U+
    ; RAM +5: velocity_y (ROM +10)
    LDA ,X+          ; ROM +10
    STA ,U+
    ; RAM +6: physics_flags (ROM +11)
    LDA ,X+          ; ROM +11
    STA ,U+
    ; RAM +7: collision_flags (ROM +12)
    LDA ,X+          ; ROM +12
    STA ,U+
    ; RAM +8: collision_size (ROM +13)
    LDA ,X+          ; ROM +13
    STA ,U+
    ; RAM +9: spawn_delay low byte (ROM +15, skip high at ROM +14)
    LDA 1,X          ; ROM +15 = low byte of spawn_delay FDB
    STA ,U+
    LEAX 2,X         ; Skip spawn_delay FDB (2 bytes), X now at ROM +16
    ; RAM +10-11: vector_ptr FDB (ROM +16-17)
    LDD ,X++         ; ROM +16-17
    STD ,U++
    ; RAM +12-13: properties_ptr FDB (ROM +18-19)
    LDD ,X++         ; ROM +18-19
    STD ,U++
    ; X is now past end of this ROM object (ROM +1 + 8 + 5 + 2 + 2 + 2 = +20 total)
    ; NOTE: We started at ROM+1 (after LEAX 1,X), walked:
    ;   1,X and 3,X and 5,X and 6,X via indexed → X unchanged
    ;   then LEAX 8,X (X now at ROM+9)
    ;   then 5 post-increment ,X+ → X at ROM+14
    ;   then LEAX 2,X (X at ROM+16)
    ;   then 2x LDD ,X++ → X at ROM+20
    ;   ROM+20 from original ROM+0 = next object start
    
    PULS B           ; Restore counter
    DECB
    BRA LLR_COPY_LOOP
LLR_COPY_DONE:
    RTS

; === SHOW_LEVEL_RUNTIME ===
; Draw all level objects from all layers
; Input:  LEVEL_PTR = pointer to level header
; Layers: BG (ROM stride 20), GP (RAM stride 14), FG (ROM stride 20)
; Each object: load intensity, x, y, vector_ptr, call SLR_DRAW_OBJECTS
SHOW_LEVEL_RUNTIME:
    PSHS D,X,Y,U     ; Preserve registers
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    
    ; Check if level is loaded
    LDX >LEVEL_PTR
    CMPX #0
    BEQ SLR_DONE     ; No level loaded, skip
    
    ; Re-read object counts from header
    LEAX 12,X        ; X points to counts (+12)
    LDB ,X+          ; B = bgCount
    STB >LEVEL_BG_COUNT
    LDB ,X+          ; B = gpCount
    STB >LEVEL_GP_COUNT
    LDB ,X+          ; B = fgCount
    STB >LEVEL_FG_COUNT
    
    ; === Draw Background Layer (ROM, stride=20) ===
SLR_BG_COUNT:
    CLRB
    LDB >LEVEL_BG_COUNT
    CMPB #0
    BEQ SLR_GAMEPLAY
    LDA #20          ; ROM object stride
    LDX >LEVEL_BG_ROM_PTR
    JSR SLR_DRAW_OBJECTS
    
    ; === Draw Gameplay Layer (RAM, stride=14) ===
SLR_GAMEPLAY:
SLR_GP_COUNT:
    CLRB
    LDB >LEVEL_GP_COUNT
    CMPB #0
    BEQ SLR_FOREGROUND
    LDA #14          ; RAM object stride (14 bytes)
    LDX >LEVEL_GP_PTR
    JSR SLR_DRAW_OBJECTS
    
    ; === Draw Foreground Layer (ROM, stride=20) ===
SLR_FOREGROUND:
SLR_FG_COUNT:
    CLRB
    LDB >LEVEL_FG_COUNT
    CMPB #0
    BEQ SLR_DONE
    LDA #20          ; ROM object stride
    LDX >LEVEL_FG_ROM_PTR
    JSR SLR_DRAW_OBJECTS
    
SLR_DONE:
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    PULS D,X,Y,U,PC  ; Restore and return
    
; === SLR_DRAW_OBJECTS - Draw N objects from a layer ===
; Input:  A = stride (14=RAM, 20=ROM), B = count, X = objects ptr
; For ROM objects (stride=20): intensity at +8, y FDB at +3, x FDB at +1, vector_ptr FDB at +16
; For RAM objects (stride=14): look up intensity from ROM via LEVEL_GP_ROM_PTR,
;   y at +1, x at +0, vector_ptr FDB at +10
SLR_DRAW_OBJECTS:
    PSHS A           ; Save stride on stack (A=stride)
SLR_OBJ_LOOP:
    TSTB
    LBEQ SLR_OBJ_DONE
    
    PSHS B           ; Save counter (LDD clobbers B)
    
    ; Determine ROM vs RAM offsets via stride
    LDA 1,S          ; Peek stride from stack (+1 because B is on top)
    CMPA #20
    BEQ SLR_ROM_OFFSETS
    
    ; === RAM object (stride=14) ===
    ; Need to look up intensity from ROM counterpart
    ; objIndex = LEVEL_GP_COUNT - currentCount
    PSHS X           ; Save RAM object pointer
    LDB >LEVEL_GP_COUNT
    SUBB 2,S         ; B = objIndex = totalCount - currentCounter
    LDX >LEVEL_GP_ROM_PTR  ; X = ROM base
SLR_ROM_ADDR_LOOP:
    BEQ SLR_INTENSITY_READ ; Done if index=0
    LEAX 20,X        ; Advance by ROM stride
    DECB
    BRA SLR_ROM_ADDR_LOOP
SLR_INTENSITY_READ:
    LDA 8,X          ; intensity at ROM +8
    STA DRAW_VEC_INTENSITY
    PULS X           ; Restore RAM object pointer
    
    CLR MIRROR_X
    CLR MIRROR_Y
    LDB 1,X          ; y at RAM +1
    STB DRAW_VEC_Y
    LDB 0,X          ; x at RAM +0
    STB DRAW_VEC_X
    LDU 10,X         ; vector_ptr at RAM +10
    BRA SLR_DRAW_VECTOR
    
SLR_ROM_OFFSETS:
    ; === ROM object (stride=20) ===
    CLR MIRROR_X
    CLR MIRROR_Y
    LDA 8,X          ; intensity at ROM +8
    STA DRAW_VEC_INTENSITY
    LDD 3,X          ; y FDB at ROM +3; low byte into B
    STB DRAW_VEC_Y
    LDD 1,X          ; x FDB at ROM +1; low byte into B
    STB DRAW_VEC_X
    LDU 16,X         ; vector_ptr FDB at ROM +16
    
SLR_DRAW_VECTOR:
    PSHS X           ; Save object pointer
    TFR U,X          ; X = vector data pointer (header)
    
    ; Read path_count from vector header byte 0
    LDB ,X+          ; B = path_count, X now at pointer table
    
    ; DP is already $D0 (set by SHOW_LEVEL_RUNTIME at entry)
SLR_PATH_LOOP:
    TSTB
    BEQ SLR_PATH_DONE
    DECB
    PSHS B           ; Save decremented count
    LDU ,X++         ; U = path pointer, X advances to next entry
    PSHS X           ; Save pointer table position
    TFR U,X          ; X = actual path data
    JSR Draw_Sync_List_At_With_Mirrors
    PULS X           ; Restore pointer table position
    PULS B           ; Restore count
    BRA SLR_PATH_LOOP
    
SLR_PATH_DONE:
    PULS X           ; Restore object pointer
    
    ; Advance to next object using stride
    LDA 1,S          ; Load stride from stack (+1 because B is on top)
    LEAX A,X         ; X += stride
    
    PULS B           ; Restore counter
    DECB
    LBRA SLR_OBJ_LOOP
    
SLR_OBJ_DONE:
    PULS A           ; Clean up stride from stack
    RTS

; === UPDATE_LEVEL_RUNTIME ===
; Update level physics: apply velocity, gravity, bounce walls
; GP-GP elastic collisions and GP-FG static collisions
; Only the GP layer (RAM buffer) is updated — BG/FG are static ROM.
UPDATE_LEVEL_RUNTIME:
    PSHS U,X,Y,D     ; Preserve all registers
    
    ; === Update Gameplay Objects ===
    LDB >LEVEL_GP_COUNT
    CMPB #0
    LBEQ ULR_EXIT    ; No objects
    LDU >LEVEL_GP_PTR  ; U = GP buffer (RAM)
    BSR ULR_UPDATE_LAYER
    
    ; === GP-to-GP Elastic Collisions ===
    JSR ULR_GAMEPLAY_COLLISIONS
    ; === GP vs FG Static Collisions ===
    JSR ULR_GP_FG_COLLISIONS
    
ULR_EXIT:
    PULS D,Y,X,U     ; Restore registers
    RTS

; === ULR_UPDATE_LAYER - Apply physics to each object in GP buffer ===
; Input: B = object count, U = buffer base (14 bytes/object)
; RAM object layout:
;   +0: x(signed 8-bit)  +1: y(signed 8-bit)  +2: scale  +3: rotation
;   +4: velocity_x  +5: velocity_y  +6: physics_flags  +7: collision_flags
;   +8: collision_size  +9: spawn_delay_lo  +10-11: vector_ptr  +12-13: props_ptr
ULR_UPDATE_LAYER:
    LDX >LEVEL_PTR   ; Load level pointer for world bounds
    CMPX #0
    LBEQ ULR_LAYER_EXIT
    
ULR_LOOP:
    PSHS B           ; Save loop counter
    
    ; Check physics_flags (RAM +6)
    LDB 6,U
    CMPB #0
    LBEQ ULR_NEXT    ; No physics at all, skip
    
    ; Check dynamic bit (bit 0)
    BITB #$01
    LBEQ ULR_NEXT    ; Not dynamic, skip
    
    ; Check gravity bit (bit 1)
    BITB #$02
    LBEQ ULR_NO_GRAVITY
    
    ; Apply gravity: velocity_y -= 1, clamp to -15
    LDB 5,U          ; velocity_y (RAM +5)
    DECB
    CMPB #$F1        ; -15
    BGE ULR_VY_OK
    LDB #$F1
ULR_VY_OK:
    STB 5,U
    
ULR_NO_GRAVITY:
    ; Apply velocity: x += velocity_x (16-bit to avoid wraparound)
    LDB 0,U          ; x (8-bit signed)
    SEX              ; D = sign-extended x
    TFR D,Y          ; Y = x (16-bit)
    LDB 4,U          ; velocity_x (8-bit signed)
    SEX              ; D = sign-extended velocity_x
    LEAY D,Y         ; Y = x + velocity_x (16-bit addition)
    TFR Y,D          ; D = 16-bit result
    CMPD #127        ; Clamp to i8 max
    BLE ULR_X_NOT_MAX
    LDD #127
ULR_X_NOT_MAX:
    CMPD #-128       ; Clamp to i8 min
    BGE ULR_X_NOT_MIN
    LDD #-128
ULR_X_NOT_MIN:
    STB 0,U          ; Store clamped x
    
    ; Apply velocity: y += velocity_y (16-bit to avoid wraparound)
    LDB 1,U          ; y (8-bit signed)
    SEX              ; D = sign-extended y
    TFR D,Y          ; Y = y (16-bit)
    LDB 5,U          ; velocity_y (8-bit signed)
    SEX              ; D = sign-extended velocity_y
    LEAY D,Y         ; Y = y + velocity_y (16-bit addition)
    TFR Y,D          ; D = 16-bit result
    CMPD #127        ; Clamp to i8 max
    BLE ULR_Y_NOT_MAX
    LDD #127
ULR_Y_NOT_MAX:
    CMPD #-128       ; Clamp to i8 min
    BGE ULR_Y_NOT_MIN
    LDD #-128
ULR_Y_NOT_MIN:
    STB 1,U          ; Store clamped y
    
    ; === World Bounds / Wall Bounce ===
    LDB 7,U          ; collision_flags (RAM +7)
    BITB #$02        ; bounce_walls flag (bit 1)
    LBEQ ULR_NEXT    ; Skip if not bouncing
    
    ; LDX already loaded = LEVEL_PTR
    ; World bounds at LEVEL_PTR: +0=xMin(FDB), +2=xMax(FDB), +4=yMin(FDB), +6=yMax(FDB)
    
    ; --- Check X left wall (xMin) ---
    LDB 8,U          ; collision_size (RAM +8)
    SEX              ; D = sign-extended collision_size
    PSHS D           ; Save collision_size
    LDB 0,U          ; x (8-bit)
    SEX              ; sign-extend x to 16-bit
    SUBD ,S++        ; D = x - collision_size (left edge), pop
    CMPD 0,X         ; Compare with xMin
    LBGE ULR_X_MAX_CHECK
    ; Hit left wall — bounce only if moving left (velocity_x < 0)
    LDB 4,U
    CMPB #0
    LBGE ULR_X_MAX_CHECK
    LDB 8,U          ; collision_size
    SEX
    ADDD 0,X         ; D = xMin + collision_size
    STB 0,U          ; x = low byte
    LDB 4,U
    NEGB
    STB 4,U          ; velocity_x = -velocity_x
    
    ; --- Check X right wall (xMax) ---
ULR_X_MAX_CHECK:
    LDB 8,U
    SEX
    PSHS D
    LDB 0,U
    SEX
    ADDD ,S++        ; D = x + collision_size (right edge), pop
    CMPD 2,X         ; Compare with xMax
    LBLE ULR_Y_BOUNDS
    ; Hit right wall — bounce only if moving right (velocity_x > 0)
    LDB 4,U
    CMPB #0
    LBLE ULR_Y_BOUNDS
    LDB 8,U
    SEX
    TFR D,Y
    LDD 2,X          ; D = xMax
    PSHS Y
    SUBD ,S++        ; D = xMax - collision_size, pop
    STB 0,U
    LDB 4,U
    NEGB
    STB 4,U
    
    ; --- Check Y bottom wall (yMin) ---
ULR_Y_BOUNDS:
    LDB 8,U
    SEX
    PSHS D
    LDB 1,U
    SEX
    SUBD ,S++        ; D = y - collision_size, pop
    CMPD 4,X         ; Compare with yMin
    LBGE ULR_Y_MAX_CHECK
    LDB 5,U
    CMPB #0
    LBGE ULR_Y_MAX_CHECK
    LDB 8,U
    SEX
    ADDD 4,X         ; D = yMin + collision_size
    STB 1,U
    LDB 5,U
    NEGB
    STB 5,U
    
    ; --- Check Y top wall (yMax) ---
ULR_Y_MAX_CHECK:
    LDB 8,U
    SEX
    PSHS D
    LDB 1,U
    SEX
    ADDD ,S++        ; D = y + collision_size, pop
    CMPD 6,X         ; Compare with yMax
    LBLE ULR_NEXT
    LDB 5,U
    CMPB #0
    LBLE ULR_NEXT
    LDB 8,U
    SEX
    TFR D,Y
    LDD 6,X          ; D = yMax
    PSHS Y
    SUBD ,S++        ; D = yMax - collision_size, pop
    STB 1,U
    LDB 5,U
    NEGB
    STB 5,U
    
ULR_NEXT:
    PULS B           ; Restore loop counter
    LEAU 14,U        ; Next object (14 bytes)
    DECB
    LBNE ULR_LOOP
    
ULR_LAYER_EXIT:
    RTS

; === ULR_GAMEPLAY_COLLISIONS - GP-to-GP elastic collisions ===
; Checks all pairs of GP objects; swaps velocities on collision.
; Uses Manhattan distance for speed. RAM indices via UGPC_ vars.
ULR_GAMEPLAY_COLLISIONS:
    LDA >LEVEL_GP_COUNT
    CMPA #2
    BHS UGPC_START
    RTS              ; Need at least 2 objects
UGPC_START:
    DECA
    STA UGPC_OUTER_MAX
    CLR UGPC_OUTER_IDX
    
UGPC_OUTER_LOOP:
    ; U = LEVEL_GP_BUFFER + (UGPC_OUTER_IDX * 14)
    LDU #LEVEL_GP_BUFFER
    LDB UGPC_OUTER_IDX
    BEQ UGPC_SKIP_OUTER_MUL
UGPC_OUTER_MUL:
    LEAU 14,U
    DECB
    BNE UGPC_OUTER_MUL
UGPC_SKIP_OUTER_MUL:
    ; Check if outer object is collidable (collision_flags bit 0 at RAM +7)
    LDB 7,U
    BITB #$01
    LBEQ UGPC_NEXT_OUTER
    
    LDA UGPC_OUTER_IDX
    INCA
    STA UGPC_INNER_IDX
    
UGPC_INNER_LOOP:
    LDA UGPC_INNER_IDX
    CMPA >LEVEL_GP_COUNT
    LBHS UGPC_INNER_DONE
    
    ; Y = LEVEL_GP_BUFFER + (UGPC_INNER_IDX * 14)
    LDY #LEVEL_GP_BUFFER
    LDB UGPC_INNER_IDX
    BEQ UGPC_SKIP_INNER_MUL
UGPC_INNER_MUL:
    LEAY 14,Y
    DECB
    BNE UGPC_INNER_MUL
UGPC_SKIP_INNER_MUL:
    ; Check inner collidable (RAM +7)
    LDB 7,Y
    BITB #$01
    LBEQ UGPC_NEXT_INNER
    
    ; Manhattan distance: |x1-x2| + |y1-y2|
    ; Compute |dx| = |x1 - x2|
    LDB 0,U          ; x1 (8-bit at RAM +0)
    SEX
    PSHS D           ; Save x1 (16-bit)
    LDB 0,Y          ; x2 (8-bit at RAM +0)
    SEX
    TFR D,X
    PULS D           ; D = x1
    PSHS X
    TFR X,D          ; D = x2
    PULS X
    PSHS D           ; Push x2
    LDB 0,U
    SEX
    SUBD ,S++        ; x1 - x2, pop
    BPL UGPC_DX_POS
    COMA
    COMB
    ADDD #1          ; negate
UGPC_DX_POS:
    STD UGPC_DX
    
    ; Compute |dy| = |y1 - y2|
    LDB 1,U          ; y1 (8-bit at RAM +1)
    SEX
    PSHS D
    LDB 1,Y          ; y2
    SEX
    TFR D,X
    PULS D
    PSHS X
    TFR X,D
    PULS X
    PSHS D           ; Push y2
    LDB 1,U
    SEX
    SUBD ,S++        ; y1 - y2, pop
    BPL UGPC_DY_POS
    COMA
    COMB
    ADDD #1
UGPC_DY_POS:
    ADDD UGPC_DX     ; D = |dx| + |dy|
    STD UGPC_DIST
    
    ; Sum of radii
    LDB 8,U          ; collision_size obj1 (RAM +8)
    ADDB 8,Y         ; + collision_size obj2
    SEX              ; D = sum_radius
    CMPD UGPC_DIST
    LBHI UGPC_COLLISION
    LBRA UGPC_NEXT_INNER
    
UGPC_COLLISION:
    ; Elastic collision: swap velocities
    LDA 4,U          ; vel_x obj1
    LDB 4,Y          ; vel_x obj2
    STB 4,U
    STA 4,Y
    LDA 5,U          ; vel_y obj1
    LDB 5,Y          ; vel_y obj2
    STB 5,U
    STA 5,Y
    
UGPC_NEXT_INNER:
    INC UGPC_INNER_IDX
    LBRA UGPC_INNER_LOOP
    
UGPC_INNER_DONE:
UGPC_NEXT_OUTER:
    INC UGPC_OUTER_IDX
    LDA UGPC_OUTER_IDX
    CMPA UGPC_OUTER_MAX
    LBHI UGPC_EXIT
    LBRA UGPC_OUTER_LOOP
    
UGPC_EXIT:
    RTS
    
; === ULR_GP_FG_COLLISIONS - GP objects vs static FG ROM collidables ===
; For each GP object (RAM, collidable) check against each FG (ROM, collidable).
; Axis-split bounce: |dy|>|dx| → negate vy; else → negate vx.
; FG ROM offsets: +0=type, +1-2=x FDB, +3-4=y FDB, +12=collision_flags, +13=collision_size
ULR_GP_FG_COLLISIONS:
    LDA >LEVEL_FG_COUNT
    LBEQ UGFC_EXIT
    STA UGFC_FG_COUNT
    LDA >LEVEL_GP_COUNT
    LBEQ UGFC_EXIT
    CLR UGFC_GP_IDX
    
UGFC_GP_LOOP:
    ; U = LEVEL_GP_BUFFER + (UGFC_GP_IDX * 14)
    LDU #LEVEL_GP_BUFFER
    LDB UGFC_GP_IDX
    BEQ UGFC_GP_ADDR_DONE
UGFC_GP_MUL:
    LEAU 14,U
    DECB
    BNE UGFC_GP_MUL
UGFC_GP_ADDR_DONE:
    ; Check GP collidable (collision_flags bit 0 at RAM +7)
    LDB 7,U
    BITB #$01
    LBEQ UGFC_NEXT_GP
    
    ; Walk FG ROM objects
    LDX >LEVEL_FG_ROM_PTR
    LDB UGFC_FG_COUNT
    
UGFC_FG_LOOP:
    CMPB #0
    LBEQ UGFC_NEXT_GP
    ; Check FG collidable (ROM +12 = collision_flags)
    LDA 12,X
    BITA #$01
    BEQ UGFC_NEXT_FG
    
    ; |dx| = |GP.x - FG.x_lo|  (FG ROM +2 = low byte of x FDB)
    LDA 0,U          ; GP x (RAM +0)
    SUBA 2,X         ; A = GP.x - FG.x_lo
    BPL UGFC_DX_POS
    NEGA
UGFC_DX_POS:
    STA UGFC_DX
    
    ; |dy| = |GP.y - FG.y_lo|  (FG ROM +4 = low byte of y FDB)
    LDA 1,U          ; GP y (RAM +1)
    SUBA 4,X         ; A = GP.y - FG.y_lo
    BPL UGFC_DY_POS
    NEGA
UGFC_DY_POS:
    STA UGFC_DY
    
    ; sum_r = GP.collision_size + FG.collision_size
    LDA 8,U          ; GP collision_size (RAM +8)
    ADDA 13,X        ; + FG collision_size (ROM +13)
    
    ; Collision if |dx| + |dy| < sum_r
    PSHS A           ; Save sum_r
    LDA UGFC_DX
    ADDA UGFC_DY
    CMPA ,S+         ; Compare distance with sum_r (pop)
    BHS UGFC_NEXT_FG ; No collision
    
    ; COLLISION! Axis-split by velocity: |vy|>|vx| → vert bounce, else horiz bounce
    LDA 5,U          ; velocity_y
    BPL UGFC_VY_ABS
    NEGA
UGFC_VY_ABS:
    STA UGFC_DY      ; |vy|
    LDA 4,U          ; velocity_x
    BPL UGFC_VX_ABS
    NEGA
UGFC_VX_ABS:
    CMPA UGFC_DY     ; |vx| vs |vy|
    BLT UGFC_VERT_BOUNCE ; |vx| < |vy| → vert bounce
    
UGFC_HORIZ_BOUNCE:
    LDA 4,U          ; velocity_x (RAM +4)
    NEGA
    STA 4,U
    LDA 8,U
    ADDA 13,X
    PSHS A           ; Save separation
    LDA 0,U
    CMPA 2,X
    BLT UGFC_PUSH_LEFT
    LDA 2,X
    ADDA ,S+
    STA 0,U
    BRA UGFC_NEXT_FG
UGFC_PUSH_LEFT:
    LDA 2,X
    SUBA ,S+
    STA 0,U
    BRA UGFC_NEXT_FG
    
UGFC_VERT_BOUNCE:
    LDA 5,U          ; velocity_y (RAM +5)
    NEGA
    STA 5,U
    LDA 8,U
    ADDA 13,X
    PSHS A
    LDA 1,U
    CMPA 4,X
    BLT UGFC_PUSH_DOWN
    LDA 4,X
    ADDA ,S+
    STA 1,U
    BRA UGFC_NEXT_FG
UGFC_PUSH_DOWN:
    LDA 4,X
    SUBA ,S+
    STA 1,U
    
UGFC_NEXT_FG:
    LEAX 20,X        ; Next FG object (ROM stride 20)
    DECB
    LBRA UGFC_FG_LOOP
    
UGFC_NEXT_GP:
    INC UGFC_GP_IDX
    LDA UGFC_GP_IDX
    CMPA >LEVEL_GP_COUNT
    LBLO UGFC_GP_LOOP
    
UGFC_EXIT:
    RTS

;**** PRINT_TEXT String Data ****
PRINT_TEXT_STR_2344190015343208:
    FCC "VPLAY TEST"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2733204421330472:
    FCC "demo_level"
    FCB $80          ; Vectrex string terminator

