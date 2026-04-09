; AUTO-GENERATED FLATTENED MULTIBANK ASM
; Banks: 4 | Bank size: 16384 bytes | Total: 65536 bytes

ORG $0000

;***************************************************************************
; DEFINE SECTION
;***************************************************************************
    INCLUDE "VECTREX.I"

; ===== BANK #00 (physical offset $00000) =====
; VPy M6809 Assembly (Vectrex)
; ROM: 65536 bytes
; Multibank cartridge: 4 banks (16KB each)
; Helpers bank: 3 (fixed bank at $4000-$7FFF)

; ================================================


    ORG $0000

;***************************************************************************
; DEFINE SECTION
;***************************************************************************

;***************************************************************************
; CARTRIDGE HEADER
;***************************************************************************
    FCC "g GCE 2025"
    FCB $80                 ; String terminator
    FDB music1              ; Music pointer
    FCB $F8,$50,$20,$BB     ; Height, Width, Rel Y, Rel X
    FCC "3D ROTATE"
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
; Bank 0 ($0000) is active; fixed bank 3 ($4000-$7FFF) always visible
    JMP MAIN

;***************************************************************************
MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    LDD #0
    STD VAR_ANGLE_X
    LDD #0
    STD VAR_ANGLE_Y
    LDD #0
    STD VAR_ANGLE_Z
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
    LDD #0
    STD VAR_ANGLE_X
    LDD #0
    STD VAR_ANGLE_Y
    LDD #0
    STD VAR_ANGLE_Z

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    LDD >VAR_ANGLE_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ANGLE_X
    LDD >VAR_ANGLE_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #2
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ANGLE_Y
    LDD >VAR_ANGLE_Z
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ANGLE_Z
    ; DRAW_VECTOR_3D: Draw vector asset with 3D rotation
    ; Asset: benchy (3D rotation)
    LDD >VAR_ANGLE_X
    STB >ROT3D_AX       ; angle X (0-127)
    LDD >VAR_ANGLE_Y
    STB >ROT3D_AY       ; angle Y (0-127)
    LDD >VAR_ANGLE_Z
    STB >ROT3D_AZ       ; angle Z (0-127)
    LDD #0
    STB >ROT3D_OX       ; screen X offset
    LDD #0
    STB >ROT3D_OY       ; screen Y offset
    LDX #_BENCHY_3D_DATA  ; pointer to 3D data table
    JSR DRAW_VECTOR_3D_RUNTIME
    LDD #0
    STD RESULT
    RTS


; ================================================


; ===== BANK #01 (physical offset $04000) =====

    ORG $0000  ; Sequential bank model

;***************************************************************************
; ASSETS IN BANK #1 (1 assets)
;***************************************************************************

; Generated from benchy.vec (Malban Draw_Sync_List format)
; Total paths: 132, points: 264
; X bounds: min=-36, max=36, width=72
; Center: (0, 0)

_BENCHY_WIDTH EQU 72
_BENCHY_HALF_WIDTH EQU 36
_BENCHY_HEIGHT EQU 94
_BENCHY_HALF_HEIGHT EQU 47
_BENCHY_CENTER_X EQU 0
_BENCHY_CENTER_Y EQU 0

_BENCHY_VECTORS:  ; Main entry (header + 132 path(s))
    FDB 132               ; path_count (runtime metadata, 2 bytes)
    FDB _BENCHY_PATH0        ; pointer to path 0
    FDB _BENCHY_PATH1        ; pointer to path 1
    FDB _BENCHY_PATH2        ; pointer to path 2
    FDB _BENCHY_PATH3        ; pointer to path 3
    FDB _BENCHY_PATH4        ; pointer to path 4
    FDB _BENCHY_PATH5        ; pointer to path 5
    FDB _BENCHY_PATH6        ; pointer to path 6
    FDB _BENCHY_PATH7        ; pointer to path 7
    FDB _BENCHY_PATH8        ; pointer to path 8
    FDB _BENCHY_PATH9        ; pointer to path 9
    FDB _BENCHY_PATH10        ; pointer to path 10
    FDB _BENCHY_PATH11        ; pointer to path 11
    FDB _BENCHY_PATH12        ; pointer to path 12
    FDB _BENCHY_PATH13        ; pointer to path 13
    FDB _BENCHY_PATH14        ; pointer to path 14
    FDB _BENCHY_PATH15        ; pointer to path 15
    FDB _BENCHY_PATH16        ; pointer to path 16
    FDB _BENCHY_PATH17        ; pointer to path 17
    FDB _BENCHY_PATH18        ; pointer to path 18
    FDB _BENCHY_PATH19        ; pointer to path 19
    FDB _BENCHY_PATH20        ; pointer to path 20
    FDB _BENCHY_PATH21        ; pointer to path 21
    FDB _BENCHY_PATH22        ; pointer to path 22
    FDB _BENCHY_PATH23        ; pointer to path 23
    FDB _BENCHY_PATH24        ; pointer to path 24
    FDB _BENCHY_PATH25        ; pointer to path 25
    FDB _BENCHY_PATH26        ; pointer to path 26
    FDB _BENCHY_PATH27        ; pointer to path 27
    FDB _BENCHY_PATH28        ; pointer to path 28
    FDB _BENCHY_PATH29        ; pointer to path 29
    FDB _BENCHY_PATH30        ; pointer to path 30
    FDB _BENCHY_PATH31        ; pointer to path 31
    FDB _BENCHY_PATH32        ; pointer to path 32
    FDB _BENCHY_PATH33        ; pointer to path 33
    FDB _BENCHY_PATH34        ; pointer to path 34
    FDB _BENCHY_PATH35        ; pointer to path 35
    FDB _BENCHY_PATH36        ; pointer to path 36
    FDB _BENCHY_PATH37        ; pointer to path 37
    FDB _BENCHY_PATH38        ; pointer to path 38
    FDB _BENCHY_PATH39        ; pointer to path 39
    FDB _BENCHY_PATH40        ; pointer to path 40
    FDB _BENCHY_PATH41        ; pointer to path 41
    FDB _BENCHY_PATH42        ; pointer to path 42
    FDB _BENCHY_PATH43        ; pointer to path 43
    FDB _BENCHY_PATH44        ; pointer to path 44
    FDB _BENCHY_PATH45        ; pointer to path 45
    FDB _BENCHY_PATH46        ; pointer to path 46
    FDB _BENCHY_PATH47        ; pointer to path 47
    FDB _BENCHY_PATH48        ; pointer to path 48
    FDB _BENCHY_PATH49        ; pointer to path 49
    FDB _BENCHY_PATH50        ; pointer to path 50
    FDB _BENCHY_PATH51        ; pointer to path 51
    FDB _BENCHY_PATH52        ; pointer to path 52
    FDB _BENCHY_PATH53        ; pointer to path 53
    FDB _BENCHY_PATH54        ; pointer to path 54
    FDB _BENCHY_PATH55        ; pointer to path 55
    FDB _BENCHY_PATH56        ; pointer to path 56
    FDB _BENCHY_PATH57        ; pointer to path 57
    FDB _BENCHY_PATH58        ; pointer to path 58
    FDB _BENCHY_PATH59        ; pointer to path 59
    FDB _BENCHY_PATH60        ; pointer to path 60
    FDB _BENCHY_PATH61        ; pointer to path 61
    FDB _BENCHY_PATH62        ; pointer to path 62
    FDB _BENCHY_PATH63        ; pointer to path 63
    FDB _BENCHY_PATH64        ; pointer to path 64
    FDB _BENCHY_PATH65        ; pointer to path 65
    FDB _BENCHY_PATH66        ; pointer to path 66
    FDB _BENCHY_PATH67        ; pointer to path 67
    FDB _BENCHY_PATH68        ; pointer to path 68
    FDB _BENCHY_PATH69        ; pointer to path 69
    FDB _BENCHY_PATH70        ; pointer to path 70
    FDB _BENCHY_PATH71        ; pointer to path 71
    FDB _BENCHY_PATH72        ; pointer to path 72
    FDB _BENCHY_PATH73        ; pointer to path 73
    FDB _BENCHY_PATH74        ; pointer to path 74
    FDB _BENCHY_PATH75        ; pointer to path 75
    FDB _BENCHY_PATH76        ; pointer to path 76
    FDB _BENCHY_PATH77        ; pointer to path 77
    FDB _BENCHY_PATH78        ; pointer to path 78
    FDB _BENCHY_PATH79        ; pointer to path 79
    FDB _BENCHY_PATH80        ; pointer to path 80
    FDB _BENCHY_PATH81        ; pointer to path 81
    FDB _BENCHY_PATH82        ; pointer to path 82
    FDB _BENCHY_PATH83        ; pointer to path 83
    FDB _BENCHY_PATH84        ; pointer to path 84
    FDB _BENCHY_PATH85        ; pointer to path 85
    FDB _BENCHY_PATH86        ; pointer to path 86
    FDB _BENCHY_PATH87        ; pointer to path 87
    FDB _BENCHY_PATH88        ; pointer to path 88
    FDB _BENCHY_PATH89        ; pointer to path 89
    FDB _BENCHY_PATH90        ; pointer to path 90
    FDB _BENCHY_PATH91        ; pointer to path 91
    FDB _BENCHY_PATH92        ; pointer to path 92
    FDB _BENCHY_PATH93        ; pointer to path 93
    FDB _BENCHY_PATH94        ; pointer to path 94
    FDB _BENCHY_PATH95        ; pointer to path 95
    FDB _BENCHY_PATH96        ; pointer to path 96
    FDB _BENCHY_PATH97        ; pointer to path 97
    FDB _BENCHY_PATH98        ; pointer to path 98
    FDB _BENCHY_PATH99        ; pointer to path 99
    FDB _BENCHY_PATH100        ; pointer to path 100
    FDB _BENCHY_PATH101        ; pointer to path 101
    FDB _BENCHY_PATH102        ; pointer to path 102
    FDB _BENCHY_PATH103        ; pointer to path 103
    FDB _BENCHY_PATH104        ; pointer to path 104
    FDB _BENCHY_PATH105        ; pointer to path 105
    FDB _BENCHY_PATH106        ; pointer to path 106
    FDB _BENCHY_PATH107        ; pointer to path 107
    FDB _BENCHY_PATH108        ; pointer to path 108
    FDB _BENCHY_PATH109        ; pointer to path 109
    FDB _BENCHY_PATH110        ; pointer to path 110
    FDB _BENCHY_PATH111        ; pointer to path 111
    FDB _BENCHY_PATH112        ; pointer to path 112
    FDB _BENCHY_PATH113        ; pointer to path 113
    FDB _BENCHY_PATH114        ; pointer to path 114
    FDB _BENCHY_PATH115        ; pointer to path 115
    FDB _BENCHY_PATH116        ; pointer to path 116
    FDB _BENCHY_PATH117        ; pointer to path 117
    FDB _BENCHY_PATH118        ; pointer to path 118
    FDB _BENCHY_PATH119        ; pointer to path 119
    FDB _BENCHY_PATH120        ; pointer to path 120
    FDB _BENCHY_PATH121        ; pointer to path 121
    FDB _BENCHY_PATH122        ; pointer to path 122
    FDB _BENCHY_PATH123        ; pointer to path 123
    FDB _BENCHY_PATH124        ; pointer to path 124
    FDB _BENCHY_PATH125        ; pointer to path 125
    FDB _BENCHY_PATH126        ; pointer to path 126
    FDB _BENCHY_PATH127        ; pointer to path 127
    FDB _BENCHY_PATH128        ; pointer to path 128
    FDB _BENCHY_PATH129        ; pointer to path 129
    FDB _BENCHY_PATH130        ; pointer to path 130
    FDB _BENCHY_PATH131        ; pointer to path 131

_BENCHY_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $2A,$F5,0,0        ; path0: header (y=42, x=-11, relative to center)
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $2A,$F5,0,0        ; path1: header (y=42, x=-11, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $2A,$F5,0,0        ; path2: header (y=42, x=-11, relative to center)
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $20,$F5,0,0        ; path3: header (y=32, x=-11, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $20,$F5,0,0        ; path4: header (y=32, x=-11, relative to center)
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $2A,$F5,0,0        ; path5: header (y=42, x=-11, relative to center)
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $2A,$F5,0,0        ; path6: header (y=42, x=-11, relative to center)
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $20,$F5,0,0        ; path7: header (y=32, x=-11, relative to center)
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $2A,$EB,0,0        ; path8: header (y=42, x=-21, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $2A,$EB,0,0        ; path9: header (y=42, x=-21, relative to center)
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $2A,$EB,0,0        ; path10: header (y=42, x=-21, relative to center)
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $20,$EB,0,0        ; path11: header (y=32, x=-21, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $EF,$E5,0,0        ; path12: header (y=-17, x=-27, relative to center)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_BENCHY_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $EF,$E5,0,0        ; path13: header (y=-17, x=-27, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $EF,$E5,0,0        ; path14: header (y=-17, x=-27, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $EF,$F1,0,0        ; path15: header (y=-17, x=-15, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $EF,$F1,0,0        ; path16: header (y=-17, x=-15, relative to center)
    FCB $FF,$17,$00          ; flag=-1, dy=23, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $EF,$E5,0,0        ; path17: header (y=-17, x=-27, relative to center)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_BENCHY_PATH18:    ; Path 18
    FCB 127              ; path18: intensity
    FCB $EF,$E5,0,0        ; path18: header (y=-17, x=-27, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH19:    ; Path 19
    FCB 127              ; path19: intensity
    FCB $EF,$F1,0,0        ; path19: header (y=-17, x=-15, relative to center)
    FCB $FF,$17,$00          ; flag=-1, dy=23, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH20:    ; Path 20
    FCB 127              ; path20: intensity
    FCB $F9,$E5,0,0        ; path20: header (y=-7, x=-27, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH21:    ; Path 21
    FCB 127              ; path21: intensity
    FCB $F9,$E5,0,0        ; path21: header (y=-7, x=-27, relative to center)
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB 2                ; End marker (path complete)

_BENCHY_PATH22:    ; Path 22
    FCB 127              ; path22: intensity
    FCB $F9,$E5,0,0        ; path22: header (y=-7, x=-27, relative to center)
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB 2                ; End marker (path complete)

_BENCHY_PATH23:    ; Path 23
    FCB 127              ; path23: intensity
    FCB $F9,$DC,0,0        ; path23: header (y=-7, x=-36, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH24:    ; Path 24
    FCB 127              ; path24: intensity
    FCB $F9,$DC,0,0        ; path24: header (y=-7, x=-36, relative to center)
    FCB $FF,$21,$00          ; flag=-1, dy=33, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH25:    ; Path 25
    FCB 127              ; path25: intensity
    FCB $F9,$DC,0,0        ; path25: header (y=-7, x=-36, relative to center)
    FCB $FF,$21,$00          ; flag=-1, dy=33, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH26:    ; Path 26
    FCB 127              ; path26: intensity
    FCB $1A,$DC,0,0        ; path26: header (y=26, x=-36, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH27:    ; Path 27
    FCB 127              ; path27: intensity
    FCB $1A,$DC,0,0        ; path27: header (y=26, x=-36, relative to center)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH28:    ; Path 28
    FCB 127              ; path28: intensity
    FCB $1A,$DC,0,0        ; path28: header (y=26, x=-36, relative to center)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH29:    ; Path 29
    FCB 127              ; path29: intensity
    FCB $1A,$E6,0,0        ; path29: header (y=26, x=-26, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH30:    ; Path 30
    FCB 127              ; path30: intensity
    FCB $1A,$E6,0,0        ; path30: header (y=26, x=-26, relative to center)
    FCB $FF,$15,$00          ; flag=-1, dy=21, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH31:    ; Path 31
    FCB 127              ; path31: intensity
    FCB $1A,$E6,0,0        ; path31: header (y=26, x=-26, relative to center)
    FCB $FF,$15,$00          ; flag=-1, dy=21, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH32:    ; Path 32
    FCB 127              ; path32: intensity
    FCB $2F,$E6,0,0        ; path32: header (y=47, x=-26, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH33:    ; Path 33
    FCB 127              ; path33: intensity
    FCB $2F,$E6,0,0        ; path33: header (y=47, x=-26, relative to center)
    FCB $FF,$00,$21          ; flag=-1, dy=0, dx=33
    FCB 2                ; End marker (path complete)

_BENCHY_PATH34:    ; Path 34
    FCB 127              ; path34: intensity
    FCB $2F,$E6,0,0        ; path34: header (y=47, x=-26, relative to center)
    FCB $FF,$00,$21          ; flag=-1, dy=0, dx=33
    FCB 2                ; End marker (path complete)

_BENCHY_PATH35:    ; Path 35
    FCB 127              ; path35: intensity
    FCB $2F,$07,0,0        ; path35: header (y=47, x=7, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH36:    ; Path 36
    FCB 127              ; path36: intensity
    FCB $2F,$07,0,0        ; path36: header (y=47, x=7, relative to center)
    FCB $FF,$EB,$00          ; flag=-1, dy=-21, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH37:    ; Path 37
    FCB 127              ; path37: intensity
    FCB $2F,$07,0,0        ; path37: header (y=47, x=7, relative to center)
    FCB $FF,$EB,$00          ; flag=-1, dy=-21, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH38:    ; Path 38
    FCB 127              ; path38: intensity
    FCB $1A,$07,0,0        ; path38: header (y=26, x=7, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH39:    ; Path 39
    FCB 127              ; path39: intensity
    FCB $1A,$07,0,0        ; path39: header (y=26, x=7, relative to center)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH40:    ; Path 40
    FCB 127              ; path40: intensity
    FCB $1A,$07,0,0        ; path40: header (y=26, x=7, relative to center)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH41:    ; Path 41
    FCB 127              ; path41: intensity
    FCB $1A,$11,0,0        ; path41: header (y=26, x=17, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH42:    ; Path 42
    FCB 127              ; path42: intensity
    FCB $1A,$11,0,0        ; path42: header (y=26, x=17, relative to center)
    FCB $FF,$F5,$00          ; flag=-1, dy=-11, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH43:    ; Path 43
    FCB 127              ; path43: intensity
    FCB $1A,$11,0,0        ; path43: header (y=26, x=17, relative to center)
    FCB $FF,$F5,$00          ; flag=-1, dy=-11, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH44:    ; Path 44
    FCB 127              ; path44: intensity
    FCB $0F,$11,0,0        ; path44: header (y=15, x=17, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH45:    ; Path 45
    FCB 127              ; path45: intensity
    FCB $0F,$11,0,0        ; path45: header (y=15, x=17, relative to center)
    FCB $FF,$00,$EA          ; flag=-1, dy=0, dx=-22
    FCB 2                ; End marker (path complete)

_BENCHY_PATH46:    ; Path 46
    FCB 127              ; path46: intensity
    FCB $0F,$11,0,0        ; path46: header (y=15, x=17, relative to center)
    FCB $FF,$00,$EA          ; flag=-1, dy=0, dx=-22
    FCB 2                ; End marker (path complete)

_BENCHY_PATH47:    ; Path 47
    FCB 127              ; path47: intensity
    FCB $0F,$FB,0,0        ; path47: header (y=15, x=-5, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH48:    ; Path 48
    FCB 127              ; path48: intensity
    FCB $0F,$FB,0,0        ; path48: header (y=15, x=-5, relative to center)
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH49:    ; Path 49
    FCB 127              ; path49: intensity
    FCB $0F,$FB,0,0        ; path49: header (y=15, x=-5, relative to center)
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH50:    ; Path 50
    FCB 127              ; path50: intensity
    FCB $06,$FB,0,0        ; path50: header (y=6, x=-5, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH51:    ; Path 51
    FCB 127              ; path51: intensity
    FCB $06,$FB,0,0        ; path51: header (y=6, x=-5, relative to center)
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH52:    ; Path 52
    FCB 127              ; path52: intensity
    FCB $06,$FB,0,0        ; path52: header (y=6, x=-5, relative to center)
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH53:    ; Path 53
    FCB 127              ; path53: intensity
    FCB $06,$F1,0,0        ; path53: header (y=6, x=-15, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH54:    ; Path 54
    FCB 127              ; path54: intensity
    FCB $0D,$0F,0,0        ; path54: header (y=13, x=15, relative to center)
    FCB $FF,$00,$EE          ; flag=-1, dy=0, dx=-18
    FCB 2                ; End marker (path complete)

_BENCHY_PATH55:    ; Path 55
    FCB 127              ; path55: intensity
    FCB $0D,$0F,0,0        ; path55: header (y=13, x=15, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH56:    ; Path 56
    FCB 127              ; path56: intensity
    FCB $0D,$0F,0,0        ; path56: header (y=13, x=15, relative to center)
    FCB $FF,$ED,$00          ; flag=-1, dy=-19, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH57:    ; Path 57
    FCB 127              ; path57: intensity
    FCB $0D,$FD,0,0        ; path57: header (y=13, x=-3, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH58:    ; Path 58
    FCB 127              ; path58: intensity
    FCB $0D,$FD,0,0        ; path58: header (y=13, x=-3, relative to center)
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH59:    ; Path 59
    FCB 127              ; path59: intensity
    FCB $0D,$0F,0,0        ; path59: header (y=13, x=15, relative to center)
    FCB $FF,$00,$EE          ; flag=-1, dy=0, dx=-18
    FCB 2                ; End marker (path complete)

_BENCHY_PATH60:    ; Path 60
    FCB 127              ; path60: intensity
    FCB $0D,$0F,0,0        ; path60: header (y=13, x=15, relative to center)
    FCB $FF,$ED,$00          ; flag=-1, dy=-19, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH61:    ; Path 61
    FCB 127              ; path61: intensity
    FCB $0D,$FD,0,0        ; path61: header (y=13, x=-3, relative to center)
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH62:    ; Path 62
    FCB 127              ; path62: intensity
    FCB $FA,$0F,0,0        ; path62: header (y=-6, x=15, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH63:    ; Path 63
    FCB 127              ; path63: intensity
    FCB $FA,$0F,0,0        ; path63: header (y=-6, x=15, relative to center)
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH64:    ; Path 64
    FCB 127              ; path64: intensity
    FCB $FA,$0F,0,0        ; path64: header (y=-6, x=15, relative to center)
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH65:    ; Path 65
    FCB 127              ; path65: intensity
    FCB $FA,$05,0,0        ; path65: header (y=-6, x=5, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH66:    ; Path 66
    FCB 127              ; path66: intensity
    FCB $FA,$05,0,0        ; path66: header (y=-6, x=5, relative to center)
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH67:    ; Path 67
    FCB 127              ; path67: intensity
    FCB $FA,$05,0,0        ; path67: header (y=-6, x=5, relative to center)
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH68:    ; Path 68
    FCB 127              ; path68: intensity
    FCB $F1,$05,0,0        ; path68: header (y=-15, x=5, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH69:    ; Path 69
    FCB 127              ; path69: intensity
    FCB $F1,$05,0,0        ; path69: header (y=-15, x=5, relative to center)
    FCB $FF,$00,$EE          ; flag=-1, dy=0, dx=-18
    FCB 2                ; End marker (path complete)

_BENCHY_PATH70:    ; Path 70
    FCB 127              ; path70: intensity
    FCB $F1,$05,0,0        ; path70: header (y=-15, x=5, relative to center)
    FCB $FF,$00,$EE          ; flag=-1, dy=0, dx=-18
    FCB 2                ; End marker (path complete)

_BENCHY_PATH71:    ; Path 71
    FCB 127              ; path71: intensity
    FCB $F1,$F3,0,0        ; path71: header (y=-15, x=-13, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH72:    ; Path 72
    FCB 127              ; path72: intensity
    FCB $F1,$F3,0,0        ; path72: header (y=-15, x=-13, relative to center)
    FCB $FF,$13,$00          ; flag=-1, dy=19, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH73:    ; Path 73
    FCB 127              ; path73: intensity
    FCB $F1,$F3,0,0        ; path73: header (y=-15, x=-13, relative to center)
    FCB $FF,$13,$00          ; flag=-1, dy=19, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH74:    ; Path 74
    FCB 127              ; path74: intensity
    FCB $04,$F3,0,0        ; path74: header (y=4, x=-13, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH75:    ; Path 75
    FCB 127              ; path75: intensity
    FCB $04,$F3,0,0        ; path75: header (y=4, x=-13, relative to center)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH76:    ; Path 76
    FCB 127              ; path76: intensity
    FCB $04,$F3,0,0        ; path76: header (y=4, x=-13, relative to center)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH77:    ; Path 77
    FCB 127              ; path77: intensity
    FCB $04,$FD,0,0        ; path77: header (y=4, x=-3, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH78:    ; Path 78
    FCB 127              ; path78: intensity
    FCB $D4,$17,0,0        ; path78: header (y=-44, x=23, relative to center)
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH79:    ; Path 79
    FCB 127              ; path79: intensity
    FCB $D4,$17,0,0        ; path79: header (y=-44, x=23, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH80:    ; Path 80
    FCB 127              ; path80: intensity
    FCB $D4,$17,0,0        ; path80: header (y=-44, x=23, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH81:    ; Path 81
    FCB 127              ; path81: intensity
    FCB $D4,$0D,0,0        ; path81: header (y=-44, x=13, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH82:    ; Path 82
    FCB 127              ; path82: intensity
    FCB $D4,$0D,0,0        ; path82: header (y=-44, x=13, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH83:    ; Path 83
    FCB 127              ; path83: intensity
    FCB $D4,$17,0,0        ; path83: header (y=-44, x=23, relative to center)
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH84:    ; Path 84
    FCB 127              ; path84: intensity
    FCB $D4,$17,0,0        ; path84: header (y=-44, x=23, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH85:    ; Path 85
    FCB 127              ; path85: intensity
    FCB $D4,$0D,0,0        ; path85: header (y=-44, x=13, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH86:    ; Path 86
    FCB 127              ; path86: intensity
    FCB $DE,$17,0,0        ; path86: header (y=-34, x=23, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH87:    ; Path 87
    FCB 127              ; path87: intensity
    FCB $DE,$17,0,0        ; path87: header (y=-34, x=23, relative to center)
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH88:    ; Path 88
    FCB 127              ; path88: intensity
    FCB $DE,$17,0,0        ; path88: header (y=-34, x=23, relative to center)
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH89:    ; Path 89
    FCB 127              ; path89: intensity
    FCB $DE,$0D,0,0        ; path89: header (y=-34, x=13, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH90:    ; Path 90
    FCB 127              ; path90: intensity
    FCB $D1,$FD,0,0        ; path90: header (y=-47, x=-3, relative to center)
    FCB $FF,$00,$1D          ; flag=-1, dy=0, dx=29
    FCB 2                ; End marker (path complete)

_BENCHY_PATH91:    ; Path 91
    FCB 127              ; path91: intensity
    FCB $D1,$FD,0,0        ; path91: header (y=-47, x=-3, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH92:    ; Path 92
    FCB 127              ; path92: intensity
    FCB $D1,$FD,0,0        ; path92: header (y=-47, x=-3, relative to center)
    FCB $FF,$15,$00          ; flag=-1, dy=21, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH93:    ; Path 93
    FCB 127              ; path93: intensity
    FCB $D1,$1A,0,0        ; path93: header (y=-47, x=26, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH94:    ; Path 94
    FCB 127              ; path94: intensity
    FCB $D1,$1A,0,0        ; path94: header (y=-47, x=26, relative to center)
    FCB $FF,$15,$00          ; flag=-1, dy=21, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH95:    ; Path 95
    FCB 127              ; path95: intensity
    FCB $D1,$FD,0,0        ; path95: header (y=-47, x=-3, relative to center)
    FCB $FF,$00,$1D          ; flag=-1, dy=0, dx=29
    FCB 2                ; End marker (path complete)

_BENCHY_PATH96:    ; Path 96
    FCB 127              ; path96: intensity
    FCB $D1,$FD,0,0        ; path96: header (y=-47, x=-3, relative to center)
    FCB $FF,$15,$00          ; flag=-1, dy=21, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH97:    ; Path 97
    FCB 127              ; path97: intensity
    FCB $D1,$1A,0,0        ; path97: header (y=-47, x=26, relative to center)
    FCB $FF,$15,$00          ; flag=-1, dy=21, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH98:    ; Path 98
    FCB 127              ; path98: intensity
    FCB $E6,$FD,0,0        ; path98: header (y=-26, x=-3, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH99:    ; Path 99
    FCB 127              ; path99: intensity
    FCB $E6,$FD,0,0        ; path99: header (y=-26, x=-3, relative to center)
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH100:    ; Path 100
    FCB 127              ; path100: intensity
    FCB $E6,$FD,0,0        ; path100: header (y=-26, x=-3, relative to center)
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH101:    ; Path 101
    FCB 127              ; path101: intensity
    FCB $E6,$F3,0,0        ; path101: header (y=-26, x=-13, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH102:    ; Path 102
    FCB 127              ; path102: intensity
    FCB $E6,$F3,0,0        ; path102: header (y=-26, x=-13, relative to center)
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH103:    ; Path 103
    FCB 127              ; path103: intensity
    FCB $E6,$F3,0,0        ; path103: header (y=-26, x=-13, relative to center)
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH104:    ; Path 104
    FCB 127              ; path104: intensity
    FCB $EF,$F3,0,0        ; path104: header (y=-17, x=-13, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH105:    ; Path 105
    FCB 127              ; path105: intensity
    FCB $EF,$F3,0,0        ; path105: header (y=-17, x=-13, relative to center)
    FCB $FF,$00,$14          ; flag=-1, dy=0, dx=20
    FCB 2                ; End marker (path complete)

_BENCHY_PATH106:    ; Path 106
    FCB 127              ; path106: intensity
    FCB $EF,$F3,0,0        ; path106: header (y=-17, x=-13, relative to center)
    FCB $FF,$00,$14          ; flag=-1, dy=0, dx=20
    FCB 2                ; End marker (path complete)

_BENCHY_PATH107:    ; Path 107
    FCB 127              ; path107: intensity
    FCB $EF,$07,0,0        ; path107: header (y=-17, x=7, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH108:    ; Path 108
    FCB 127              ; path108: intensity
    FCB $EF,$07,0,0        ; path108: header (y=-17, x=7, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH109:    ; Path 109
    FCB 127              ; path109: intensity
    FCB $EF,$07,0,0        ; path109: header (y=-17, x=7, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH110:    ; Path 110
    FCB 127              ; path110: intensity
    FCB $F9,$07,0,0        ; path110: header (y=-7, x=7, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH111:    ; Path 111
    FCB 127              ; path111: intensity
    FCB $F9,$07,0,0        ; path111: header (y=-7, x=7, relative to center)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH112:    ; Path 112
    FCB 127              ; path112: intensity
    FCB $F9,$07,0,0        ; path112: header (y=-7, x=7, relative to center)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH113:    ; Path 113
    FCB 127              ; path113: intensity
    FCB $F9,$11,0,0        ; path113: header (y=-7, x=17, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH114:    ; Path 114
    FCB 127              ; path114: intensity
    FCB $F9,$11,0,0        ; path114: header (y=-7, x=17, relative to center)
    FCB $FF,$14,$00          ; flag=-1, dy=20, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH115:    ; Path 115
    FCB 127              ; path115: intensity
    FCB $F9,$11,0,0        ; path115: header (y=-7, x=17, relative to center)
    FCB $FF,$14,$00          ; flag=-1, dy=20, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH116:    ; Path 116
    FCB 127              ; path116: intensity
    FCB $0D,$11,0,0        ; path116: header (y=13, x=17, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH117:    ; Path 117
    FCB 127              ; path117: intensity
    FCB $0D,$11,0,0        ; path117: header (y=13, x=17, relative to center)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH118:    ; Path 118
    FCB 127              ; path118: intensity
    FCB $0D,$11,0,0        ; path118: header (y=13, x=17, relative to center)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH119:    ; Path 119
    FCB 127              ; path119: intensity
    FCB $0D,$1B,0,0        ; path119: header (y=13, x=27, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH120:    ; Path 120
    FCB 127              ; path120: intensity
    FCB $0D,$1B,0,0        ; path120: header (y=13, x=27, relative to center)
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH121:    ; Path 121
    FCB 127              ; path121: intensity
    FCB $0D,$1B,0,0        ; path121: header (y=13, x=27, relative to center)
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH122:    ; Path 122
    FCB 127              ; path122: intensity
    FCB $04,$1B,0,0        ; path122: header (y=4, x=27, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH123:    ; Path 123
    FCB 127              ; path123: intensity
    FCB $04,$1B,0,0        ; path123: header (y=4, x=27, relative to center)
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB 2                ; End marker (path complete)

_BENCHY_PATH124:    ; Path 124
    FCB 127              ; path124: intensity
    FCB $04,$1B,0,0        ; path124: header (y=4, x=27, relative to center)
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB 2                ; End marker (path complete)

_BENCHY_PATH125:    ; Path 125
    FCB 127              ; path125: intensity
    FCB $04,$24,0,0        ; path125: header (y=4, x=36, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH126:    ; Path 126
    FCB 127              ; path126: intensity
    FCB $04,$24,0,0        ; path126: header (y=4, x=36, relative to center)
    FCB $FF,$E2,$00          ; flag=-1, dy=-30, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH127:    ; Path 127
    FCB 127              ; path127: intensity
    FCB $04,$24,0,0        ; path127: header (y=4, x=36, relative to center)
    FCB $FF,$E2,$00          ; flag=-1, dy=-30, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH128:    ; Path 128
    FCB 127              ; path128: intensity
    FCB $E6,$24,0,0        ; path128: header (y=-26, x=36, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BENCHY_PATH129:    ; Path 129
    FCB 127              ; path129: intensity
    FCB $E6,$24,0,0        ; path129: header (y=-26, x=36, relative to center)
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH130:    ; Path 130
    FCB 127              ; path130: intensity
    FCB $E6,$24,0,0        ; path130: header (y=-26, x=36, relative to center)
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_BENCHY_PATH131:    ; Path 131
    FCB 127              ; path131: intensity
    FCB $E6,$1A,0,0        ; path131: header (y=-26, x=26, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)


; ================================================


; ===== BANK #02 (physical offset $08000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #03 (physical offset $0C000) =====
    ORG $4000  ; Fixed bank window (runtime helpers + interrupt vectors)


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



;***************************************************************************
; INTERRUPT VECTORS (Bank #31 Fixed Window)
;***************************************************************************
ORG $FFFE
FDB CUSTOM_RESET
