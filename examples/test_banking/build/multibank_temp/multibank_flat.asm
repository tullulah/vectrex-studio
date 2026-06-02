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
    FCC "TEST BANKING"
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
    JSR $F533        ; Init_Music_Buf: init BIOS sound work buffer at Vec_Default_Stk
    LDS #$CFFF       ; Stack -> top of Vectrex 2KB RAM (avoids user var collision)

    ; Initialize bank tracking vars to 0 (prevents spurious $DF00 writes)
    LDA #0
    STA >CURRENT_ROM_BANK   ; Bank 0 is always active at boot
    ; Initialize audio system variables to prevent random noise on startup
    CLR >SFX_ACTIVE         ; Mark SFX as inactive (0=off)
    LDD #$0000
    STD >SFX_PTR            ; Clear SFX pointer
    STA >PSG_MUSIC_BANK     ; Bank 0 for music (prevents garbage bank switch in emulator)
    STA >SFX_BANK           ; Bank 0 for SFX (prevents garbage bank switch in emulator)
    CLR >PSG_IS_PLAYING     ; No music playing at startup
    CLR >PSG_DELAY_FRAMES   ; Clear delay counter
    STD >PSG_MUSIC_PTR      ; Clear music pointer (D is already 0)
    STD >PSG_MUSIC_START    ; Clear loop pointer
; Bank 0 ($0000) is active; fixed bank 3 ($4000-$7FFF) always visible
    JMP MAIN

;***************************************************************************
MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    LDA #$7F
    STA DRAW_SCALE        ; Default T1 scale = $7F (127 = full BIOS scale)
    LDD #0
    STD VAR_STATE
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
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed
    BITA #$01
    BNE .J1B1_0_ON
    LDD #0
    BRA .J1B1_0_END
.J1B1_0_ON:
    LDD #1
.J1B1_0_END:
    STD RESULT
    STD VAR_BTN1
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN1
    CMPD TMPVAL
    LBEQ .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_1
    LDD #1
    STD VAR_STATE
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_STATE
    CMPD TMPVAL
    LBEQ .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    LBEQ IF_NEXT_3
    ; PLAY_MUSIC("intro") - play music asset (index=1)
    LDX #1        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: crypt_logo (index=0, 40 paths)
    LDD #0
    TFR B,A       ; X position (low byte) — B already holds it
    STA TMPPTR    ; Save X to temporary storage
    LDD #10
    TFR B,A       ; Y position (low byte) — B already holds it
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #0        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_STATE
    CMPD TMPVAL
    LBEQ .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    LBEQ IF_NEXT_5
    ; PLAY_MUSIC("exploration") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: crypt_logo (index=0, 40 paths)
    LDD #0
    TFR B,A       ; X position (low byte) — B already holds it
    STA TMPPTR    ; Save X to temporary storage
    LDD #10
    TFR B,A       ; Y position (low byte) — B already holds it
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #0        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX (after all game logic)
    RTS


; ================================================


; ===== BANK #01 (physical offset $04000) =====

    ORG $0000  ; Sequential bank model

;***************************************************************************
; ASSETS IN BANK #1 (3 assets)
;***************************************************************************

; Generated from crypt_logo.vec (Malban Draw_Sync_List format)
; Total paths: 40, points: 169
; X bounds: min=-83, max=83, width=166
; Center: (0, 16)

_CRYPT_LOGO_WIDTH EQU 166
_CRYPT_LOGO_HALF_WIDTH EQU 83
_CRYPT_LOGO_HEIGHT EQU 163
_CRYPT_LOGO_HALF_HEIGHT EQU 81
_CRYPT_LOGO_CENTER_X EQU 0
_CRYPT_LOGO_CENTER_Y EQU 16

_CRYPT_LOGO_VECTORS:  ; Main entry (header + 40 path(s))
    FDB 40               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _CRYPT_LOGO_PATH0        ; pointer to path 0
    FDB _CRYPT_LOGO_PATH1        ; pointer to path 1
    FDB _CRYPT_LOGO_PATH2        ; pointer to path 2
    FDB _CRYPT_LOGO_PATH3        ; pointer to path 3
    FDB _CRYPT_LOGO_PATH4        ; pointer to path 4
    FDB _CRYPT_LOGO_PATH5        ; pointer to path 5
    FDB _CRYPT_LOGO_PATH6        ; pointer to path 6
    FDB _CRYPT_LOGO_PATH7        ; pointer to path 7
    FDB _CRYPT_LOGO_PATH8        ; pointer to path 8
    FDB _CRYPT_LOGO_PATH9        ; pointer to path 9
    FDB _CRYPT_LOGO_PATH10        ; pointer to path 10
    FDB _CRYPT_LOGO_PATH11        ; pointer to path 11
    FDB _CRYPT_LOGO_PATH12        ; pointer to path 12
    FDB _CRYPT_LOGO_PATH13        ; pointer to path 13
    FDB _CRYPT_LOGO_PATH14        ; pointer to path 14
    FDB _CRYPT_LOGO_PATH15        ; pointer to path 15
    FDB _CRYPT_LOGO_PATH16        ; pointer to path 16
    FDB _CRYPT_LOGO_PATH17        ; pointer to path 17
    FDB _CRYPT_LOGO_PATH18        ; pointer to path 18
    FDB _CRYPT_LOGO_PATH19        ; pointer to path 19
    FDB _CRYPT_LOGO_PATH20        ; pointer to path 20
    FDB _CRYPT_LOGO_PATH21        ; pointer to path 21
    FDB _CRYPT_LOGO_PATH22        ; pointer to path 22
    FDB _CRYPT_LOGO_PATH23        ; pointer to path 23
    FDB _CRYPT_LOGO_PATH24        ; pointer to path 24
    FDB _CRYPT_LOGO_PATH25        ; pointer to path 25
    FDB _CRYPT_LOGO_PATH26        ; pointer to path 26
    FDB _CRYPT_LOGO_PATH27        ; pointer to path 27
    FDB _CRYPT_LOGO_PATH28        ; pointer to path 28
    FDB _CRYPT_LOGO_PATH29        ; pointer to path 29
    FDB _CRYPT_LOGO_PATH30        ; pointer to path 30
    FDB _CRYPT_LOGO_PATH31        ; pointer to path 31
    FDB _CRYPT_LOGO_PATH32        ; pointer to path 32
    FDB _CRYPT_LOGO_PATH33        ; pointer to path 33
    FDB _CRYPT_LOGO_PATH34        ; pointer to path 34
    FDB _CRYPT_LOGO_PATH35        ; pointer to path 35
    FDB _CRYPT_LOGO_PATH36        ; pointer to path 36
    FDB _CRYPT_LOGO_PATH37        ; pointer to path 37
    FDB _CRYPT_LOGO_PATH38        ; pointer to path 38
    FDB _CRYPT_LOGO_PATH39        ; pointer to path 39

_CRYPT_LOGO_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $F0,$00,0,0        ; path0: header (y=-16, x=0)
    FCB $FF,$EC,$00          ; flag=-1, dy=-20, dx=0
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $DC,$EC,0,0        ; path1: header (y=-36, x=-20)
    FCB $FF,$13,$F8          ; flag=-1, dy=19, dx=-8
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $EF,$D0,0,0        ; path2: header (y=-17, x=-48)
    FCB $FF,$00,$14          ; flag=-1, dy=0, dx=20
    FCB $FF,$05,$08          ; flag=-1, dy=5, dx=8
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$06,$F8          ; flag=-1, dy=6, dx=-8
    FCB $FF,$00,$EC          ; flag=-1, dy=0, dx=-20
    FCB $FF,$D8,$00          ; flag=-1, dy=-40, dx=0
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $FE,$CA,0,0        ; path3: header (y=-2, x=-54)
    FCB $FF,$00,$E9          ; flag=-1, dy=0, dx=-23
    FCB $FF,$E4,$00          ; flag=-1, dy=-28, dx=0
    FCB $FF,$00,$17          ; flag=-1, dy=0, dx=23
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$E4          ; flag=-1, dy=0, dx=-28
    FCB $FF,$28,$00          ; flag=-1, dy=40, dx=0
    FCB $FF,$00,$1C          ; flag=-1, dy=0, dx=28
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH4:    ; Path 4
    FCB 70              ; path4: intensity
    FCB $09,$C5,0,0        ; path4: header (y=9, x=-59)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH5:    ; Path 5
    FCB 70              ; path5: intensity
    FCB $09,$B9,0,0        ; path5: header (y=9, x=-71)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH6:    ; Path 6
    FCB 70              ; path6: intensity
    FCB $13,$B5,0,0        ; path6: header (y=19, x=-75)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH7:    ; Path 7
    FCB 70              ; path7: intensity
    FCB $13,$C7,0,0        ; path7: header (y=19, x=-57)
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH8:    ; Path 8
    FCB 70              ; path8: intensity
    FCB $12,$D7,0,0        ; path8: header (y=18, x=-41)
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH9:    ; Path 9
    FCB 70              ; path9: intensity
    FCB $13,$D9,0,0        ; path9: header (y=19, x=-39)
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH10:    ; Path 10
    FCB 70              ; path10: intensity
    FCB $09,$E1,0,0        ; path10: header (y=9, x=-31)
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH11:    ; Path 11
    FCB 70              ; path11: intensity
    FCB $12,$EF,0,0        ; path11: header (y=18, x=-17)
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH12:    ; Path 12
    FCB 70              ; path12: intensity
    FCB $0E,$F1,0,0        ; path12: header (y=14, x=-15)
    FCB $FF,$05,$05          ; flag=-1, dy=5, dx=5
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH13:    ; Path 13
    FCB 70              ; path13: intensity
    FCB $13,$F1,0,0        ; path13: header (y=19, x=-15)
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH14:    ; Path 14
    FCB 70              ; path14: intensity
    FCB $0E,$F1,0,0        ; path14: header (y=14, x=-15)
    FCB $FF,$FB,$05          ; flag=-1, dy=-5, dx=5
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH15:    ; Path 15
    FCB 70              ; path15: intensity
    FCB $09,$F9,0,0        ; path15: header (y=9, x=-7)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$FB,$03          ; flag=-1, dy=-5, dx=3
    FCB $FF,$05,$03          ; flag=-1, dy=5, dx=3
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH16:    ; Path 16
    FCB 70              ; path16: intensity
    FCB $09,$01,0,0        ; path16: header (y=9, x=1)
    FCB $FF,$0A,$03          ; flag=-1, dy=10, dx=3
    FCB $FF,$F6,$03          ; flag=-1, dy=-10, dx=3
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH17:    ; Path 17
    FCB 70              ; path17: intensity
    FCB $09,$09,0,0        ; path17: header (y=9, x=9)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH18:    ; Path 18
    FCB 70              ; path18: intensity
    FCB $0E,$09,0,0        ; path18: header (y=14, x=9)
    FCB $FF,$05,$05          ; flag=-1, dy=5, dx=5
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH19:    ; Path 19
    FCB 70              ; path19: intensity
    FCB $13,$11,0,0        ; path19: header (y=19, x=17)
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH20:    ; Path 20
    FCB 70              ; path20: intensity
    FCB $09,$19,0,0        ; path20: header (y=9, x=25)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH21:    ; Path 21
    FCB 70              ; path21: intensity
    FCB $0A,$24,0,0        ; path21: header (y=10, x=36)
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH22:    ; Path 22
    FCB 127              ; path22: intensity
    FCB $04,$36,0,0        ; path22: header (y=4, x=54)
    FCB $FF,$00,$1C          ; flag=-1, dy=0, dx=28
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH23:    ; Path 23
    FCB 70              ; path23: intensity
    FCB $06,$53,0,0        ; path23: header (y=6, x=83)
    FCB $FF,$00,$AD          ; sub-seg 1/2 of line 0: dy=0, dx=-83
    FCB $FF,$00,$AD          ; sub-seg 2/2 of line 0: dy=0, dx=-83
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH24:    ; Path 24
    FCB 100              ; path24: intensity
    FCB $D8,$AD,0,0        ; path24: header (y=-40, x=-83)
    FCB $FF,$00,$53          ; sub-seg 1/2 of line 0: dy=0, dx=83
    FCB $FF,$00,$53          ; sub-seg 2/2 of line 0: dy=0, dx=83
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH25:    ; Path 25
    FCB 127              ; path25: intensity
    FCB $DC,$44,0,0        ; path25: header (y=-36, x=68)
    FCB $FF,$28,$00          ; flag=-1, dy=40, dx=0
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH26:    ; Path 26
    FCB 127              ; path26: intensity
    FCB $EF,$14,0,0        ; path26: header (y=-17, x=20)
    FCB $FF,$00,$14          ; flag=-1, dy=0, dx=20
    FCB $FF,$05,$08          ; flag=-1, dy=5, dx=8
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$06,$F8          ; flag=-1, dy=6, dx=-8
    FCB $FF,$00,$EC          ; flag=-1, dy=0, dx=-20
    FCB $FF,$D8,$00          ; flag=-1, dy=-40, dx=0
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH27:    ; Path 27
    FCB 80              ; path27: intensity
    FCB $C8,$00,0,0        ; path27: header (y=-56, x=0)
    FCB $FF,$FD,$05          ; flag=-1, dy=-3, dx=5
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$FD,$FB          ; flag=-1, dy=-3, dx=-5
    FCB $FF,$03,$FB          ; flag=-1, dy=3, dx=-5
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$03,$05          ; flag=-1, dy=3, dx=5
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH28:    ; Path 28
    FCB 80              ; path28: intensity
    FCB $BD,$00,0,0        ; path28: header (y=-67, x=0)
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH29:    ; Path 29
    FCB 80              ; path29: intensity
    FCB $B2,$00,0,0        ; path29: header (y=-78, x=0)
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH30:    ; Path 30
    FCB 80              ; path30: intensity
    FCB $B7,$05,0,0        ; path30: header (y=-73, x=5)
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH31:    ; Path 31
    FCB 127              ; path31: intensity
    FCB $04,$F2,0,0        ; path31: header (y=4, x=-14)
    FCB $FF,$EC,$0E          ; flag=-1, dy=-20, dx=14
    FCB $FF,$14,$0E          ; flag=-1, dy=20, dx=14
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH32:    ; Path 32
    FCB 70              ; path32: intensity
    FCB $09,$0E,0,0        ; path32: header (y=9, x=14)
    FCB $FF,$05,$FB          ; flag=-1, dy=5, dx=-5
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH33:    ; Path 33
    FCB 70              ; path33: intensity
    FCB $0E,$06,0,0        ; path33: header (y=14, x=6)
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH34:    ; Path 34
    FCB 60              ; path34: intensity
    FCB $18,$00,0,0        ; path34: header (y=24, x=0)
    FCB $FF,$12,$00          ; flag=-1, dy=18, dx=0
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH35:    ; Path 35
    FCB 70              ; path35: intensity
    FCB $1D,$00,0,0        ; path35: header (y=29, x=0)
    FCB $FF,$FB,$FC          ; flag=-1, dy=-5, dx=-4
    FCB $FF,$FB,$04          ; flag=-1, dy=-5, dx=4
    FCB $FF,$05,$04          ; flag=-1, dy=5, dx=4
    FCB $FF,$05,$FC          ; flag=-1, dy=5, dx=-4
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH36:    ; Path 36
    FCB 90              ; path36: intensity
    FCB $3E,$02,0,0        ; path36: header (y=62, x=2)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH37:    ; Path 37
    FCB 90              ; path37: intensity
    FCB $3E,$00,0,0        ; path37: header (y=62, x=0)
    FCB $FF,$12,$00          ; flag=-1, dy=18, dx=0
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH38:    ; Path 38
    FCB 28              ; path38: intensity
    FCB $52,$00,0,0        ; path38: header (y=82, x=0)
    FCB $FF,$FD,$0A          ; flag=-1, dy=-3, dx=10
    FCB $FF,$F9,$08          ; flag=-1, dy=-7, dx=8
    FCB $FF,$F6,$02          ; flag=-1, dy=-10, dx=2
    FCB $FF,$F6,$FE          ; flag=-1, dy=-10, dx=-2
    FCB $FF,$F9,$F8          ; flag=-1, dy=-7, dx=-8
    FCB $FF,$FD,$F6          ; flag=-1, dy=-3, dx=-10
    FCB $FF,$03,$F6          ; flag=-1, dy=3, dx=-10
    FCB $FF,$07,$F8          ; flag=-1, dy=7, dx=-8
    FCB $FF,$0A,$FE          ; flag=-1, dy=10, dx=-2
    FCB $FF,$0A,$02          ; flag=-1, dy=10, dx=2
    FCB $FF,$07,$08          ; flag=-1, dy=7, dx=8
    FCB $FF,$03,$0A          ; flag=-1, dy=3, dx=10
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH39:    ; Path 39
    FCB 90              ; path39: intensity
    FCB $4A,$F3,0,0        ; path39: header (y=74, x=-13)
    FCB $FF,$F4,$0D          ; flag=-1, dy=-12, dx=13
    FCB 2                ; End marker (path complete)

; Generated from exploration.vmus (internal name: The Clockmaker's Crypt - Exploration)
; Tempo: 90 BPM, Total events: 60 (PSG Direct format)
; Format: FCB count, FCB reg, val, ... (per frame), FCB 0 (end)

_EXPLORATION_MUSIC:
    ; Frame-based PSG register writes
    FCB     0              ; Delay 0 frames (maintain previous state)
    FCB     9              ; Frame 0 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $58             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0B             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     8              ; Frame 5 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $58             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     11              ; Delay 11 frames (maintain previous state)
    FCB     8              ; Frame 16 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $C8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $58             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     17              ; Delay 17 frames (maintain previous state)
    FCB     9              ; Frame 33 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0C             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     8              ; Frame 38 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     8              ; Frame 50 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $C8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     16              ; Delay 16 frames (maintain previous state)
    FCB     9              ; Frame 66 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $90             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0B             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     8              ; Frame 72 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $90             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     11              ; Delay 11 frames (maintain previous state)
    FCB     8              ; Frame 83 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $90             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     17              ; Delay 17 frames (maintain previous state)
    FCB     9              ; Frame 100 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0C             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     8              ; Frame 105 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     11              ; Delay 11 frames (maintain previous state)
    FCB     8              ; Frame 116 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $C8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $51             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     17              ; Delay 17 frames (maintain previous state)
    FCB     9              ; Frame 133 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0B             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $58             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0B             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     8              ; Frame 138 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0B             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $58             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     8              ; Frame 150 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0B             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $58             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     16              ; Delay 16 frames (maintain previous state)
    FCB     9              ; Frame 166 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $0B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0C             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     8              ; Frame 172 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $0B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     28              ; Delay 28 frames (maintain previous state)
    FCB     9              ; Frame 200 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0B             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F4             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0B             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     8              ; Frame 205 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0B             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F4             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     11              ; Delay 11 frames (maintain previous state)
    FCB     8              ; Frame 216 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0B             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F4             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     17              ; Delay 17 frames (maintain previous state)
    FCB     9              ; Frame 233 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $C8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0C             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     8              ; Frame 238 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $C8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     28              ; Delay 28 frames (maintain previous state)
    FCB     9              ; Frame 266 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $84             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0B             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     8              ; Frame 272 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $84             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     11              ; Delay 11 frames (maintain previous state)
    FCB     8              ; Frame 283 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $C8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0B             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $84             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     17              ; Delay 17 frames (maintain previous state)
    FCB     9              ; Frame 300 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0B             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F4             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0C             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     8              ; Frame 305 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0B             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F4             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     11              ; Delay 11 frames (maintain previous state)
    FCB     8              ; Frame 316 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0B             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F4             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     17              ; Delay 17 frames (maintain previous state)
    FCB     9              ; Frame 333 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $0B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0B             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $58             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0B             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     8              ; Frame 338 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $0B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0B             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $58             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     8              ; Frame 350 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $2C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0A             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $58             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     16              ; Delay 16 frames (maintain previous state)
    FCB     9              ; Frame 366 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $0B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0B             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0C             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     8              ; Frame 372 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $0B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0B             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     11              ; Delay 11 frames (maintain previous state)
    FCB     8              ; Frame 383 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0B             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     17              ; Delay 17 frames (maintain previous state)
    FCB     9              ; Frame 400 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $90             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0B             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     8              ; Frame 405 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $90             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     28              ; Delay 28 frames (maintain previous state)
    FCB     9              ; Frame 433 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0C             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     8              ; Frame 438 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     11              ; Delay 11 frames (maintain previous state)
    FCB     8              ; Frame 449 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     17              ; Delay 17 frames (maintain previous state)
    FCB     9              ; Frame 466 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $C8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0B             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     8              ; Frame 472 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $C8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     11              ; Delay 11 frames (maintain previous state)
    FCB     8              ; Frame 483 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0B             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     16              ; Delay 16 frames (maintain previous state)
    FCB     9              ; Frame 499 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $2C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $58             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0C             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     8              ; Frame 505 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $2C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $58             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     28              ; Delay 28 frames before loop
    FCB     $FF             ; Loop command ($FF never valid as count)
    FDB     _EXPLORATION_MUSIC       ; Jump to start (absolute address)


; Generated from intro.vmus (internal name: The Clockmaker's Crypt - Title Theme)
; Tempo: 130 BPM, Total events: 56 (PSG Direct format)
; Format: FCB count, FCB reg, val, ... (per frame), FCB 0 (end)

_INTRO_MUSIC:
    ; Frame-based PSG register writes
    FCB     0              ; Delay 0 frames (maintain previous state)
    FCB     9              ; Frame 0 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $58             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0C             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $04             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     7              ; Delay 7 frames (maintain previous state)
    FCB     8              ; Frame 7 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $58             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     16              ; Delay 16 frames (maintain previous state)
    FCB     9              ; Frame 23 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $07             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 25 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     8              ; Frame 34 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     9              ; Frame 46 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $90             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     8              ; Frame 51 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $90             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     18              ; Delay 18 frames (maintain previous state)
    FCB     9              ; Frame 69 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $07             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     8              ; Frame 72 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     8              ; Frame 80 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     9              ; Frame 92 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0C             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $04             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     8              ; Frame 100 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     15              ; Delay 15 frames (maintain previous state)
    FCB     9              ; Frame 115 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $07             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     8              ; Frame 118 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     8              ; Frame 126 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $C8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     9              ; Frame 138 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $17             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     8              ; Frame 144 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $17             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     17              ; Delay 17 frames (maintain previous state)
    FCB     9              ; Frame 161 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $C8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $07             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     8              ; Frame 164 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $C8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     20              ; Delay 20 frames (maintain previous state)
    FCB     9              ; Frame 184 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F4             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0C             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $04             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     8              ; Frame 192 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F4             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     4              ; Delay 4 frames (maintain previous state)
    FCB     8              ; Frame 196 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F4             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     11              ; Delay 11 frames (maintain previous state)
    FCB     9              ; Frame 207 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $58             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $07             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     8              ; Frame 210 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $58             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     20              ; Delay 20 frames (maintain previous state)
    FCB     9              ; Frame 230 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     8              ; Frame 236 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     8              ; Frame 242 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     11              ; Delay 11 frames (maintain previous state)
    FCB     9              ; Frame 253 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $07             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     8              ; Frame 256 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     8              ; Frame 265 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     11              ; Delay 11 frames (maintain previous state)
    FCB     9              ; Frame 276 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0F             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $58             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0C             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $04             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     8              ; Frame 284 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0F             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $58             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     16              ; Delay 16 frames (maintain previous state)
    FCB     9              ; Frame 300 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $07             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 302 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     8              ; Frame 311 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     9              ; Frame 323 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     8              ; Frame 328 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     8              ; Frame 334 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $F9             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $09             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     9              ; Frame 346 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $C8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $58             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $07             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $1C             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     8              ; Frame 349 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $C8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $58             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3C             ; Reg 7 value
    FCB     20              ; Delay 20 frames before loop
    FCB     $FF             ; Loop command ($FF never valid as count)
    FDB     _INTRO_MUSIC       ; Jump to start (absolute address)



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
    FDB _CRYPT_LOGO_VECTORS    ; crypt_logo

; Music Asset Index Mapping:
;   0 = exploration (Bank #1)
;   1 = intro (Bank #1)

MUSIC_BANK_TABLE:
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID

MUSIC_ADDR_TABLE:
    FDB _EXPLORATION_MUSIC    ; exploration
    FDB _INTRO_MUSIC    ; intro

; Legacy unified tables (all assets)
ASSET_BANK_TABLE:
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID

ASSET_ADDR_TABLE:
    FDB _CRYPT_LOGO_VECTORS    ; crypt_logo
    FDB _EXPLORATION_MUSIC    ; exploration
    FDB _INTRO_MUSIC    ; intro

;***************************************************************************
; DRAW_VECTOR_BANKED - Draw vector asset with automatic bank switching
; Input: X = asset index (0-based), DRAW_VEC_X/Y set for position
;        MIRROR_X, MIRROR_Y, DRAW_VEC_INTENSITY must be set by caller
; Uses: A, B, D, X, Y, U
; Preserves: CURRENT_ROM_BANK (restored after drawing)
; Note: DSWM handles beam positioning internally via DRAW_VEC_X/Y
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

    ; Set DP=$D0 for DSWM / VIA access (caller set MIRROR_X/Y/INTENSITY)
    JSR $F1AA            ; DP_to_D0

    ; Loop over all paths (header: FDB path_count, then FDB table)
    LDD ,X               ; D = path_count (16-bit FDB at header start)
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
; PLAY_MUSIC_BANKED - Play music asset with automatic bank switching
; Input: X = music asset index (0-based)
; Uses: A, B, X
; Note: Music data is COPIED to RAM, so bank switch is temporary
;***************************************************************************
PLAY_MUSIC_BANKED:
    ; Save index to U register (avoid stack order issues)
    TFR X,U              ; U = music index
    ; Save context: original bank on stack
    LDA CURRENT_ROM_BANK
    PSHS A               ; Stack: [A]

    ; CRITICAL: Read BOTH lookup tables BEFORE switching banks!
    ; (Tables are in Bank 31, which is always visible at $4000+)

    ; Get music's bank from lookup table (BEFORE switch)
    TFR U,D              ; D = music index (from U)
    LDX #MUSIC_BANK_TABLE
    LDA D,X              ; A = bank ID for this music
    STA >PSG_MUSIC_BANK  ; Save bank for AUDIO_UPDATE (multibank)
    PSHS A               ; Save bank ID on stack temporarily

    ; Get music's address from lookup table (BEFORE switch)
    TFR U,D              ; Reload music index from U
    ASLB                 ; *2 for FDB entries
    ROLA
    LDX #MUSIC_ADDR_TABLE
    LEAX D,X             ; X points to address entry
    LDX ,X               ; X = actual music address in banked ROM
    PSHS X               ; Save music address on stack

    ; NOW switch to music's bank
    LDA 2,S              ; Get bank ID from stack (behind X)
    STA CURRENT_ROM_BANK ; Update RAM tracker
    STA $DF00            ; Switch bank hardware register

    ; Restore music address and call runtime
    PULS X               ; X = music address (now valid in switched bank)
    LEAS 1,S             ; Discard bank ID from stack

    ; Call PLAY_MUSIC_RUNTIME with X pointing to music data
    JSR PLAY_MUSIC_RUNTIME

    ; Restore original bank from stack
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
; ============================================================================
; PSG DIRECT MUSIC PLAYER (inspired by Christman2024/malbanGit)
; ============================================================================
; Writes directly to PSG chip using WRITE_PSG sequence
;
; Music data format (frame-based):
;   FCB count           ; Number of register writes this frame
;   FCB reg, val        ; PSG register/value pairs
;   ...                 ; Repeat for each register
;   FCB $FF             ; End marker
;
; PSG Registers:
;   0-1: Channel A frequency (12-bit)
;   2-3: Channel B frequency
;   4-5: Channel C frequency
;   6:   Noise period
;   7:   Mixer control (enable/disable channels)
;   8-10: Channel A/B/C volume
;   11-12: Envelope period
;   13:  Envelope shape
; ============================================================================

; RAM variables (defined in SYSTEM RAM VARIABLES section):
; PSG_MUSIC_PTR, PSG_MUSIC_START, PSG_IS_PLAYING,
; PSG_MUSIC_ACTIVE, PSG_DELAY_FRAMES

; PLAY_MUSIC_RUNTIME - Start PSG music playback
; Input: X = pointer to PSG music data
PLAY_MUSIC_RUNTIME:
CMPX >PSG_MUSIC_START   ; Check if already playing this music
BNE PMr_start_new       ; If different, start fresh
LDA >PSG_IS_PLAYING     ; Check if currently playing
BNE PMr_done            ; If playing same song, ignore
PMr_start_new:
; Silence PSG before switching tracks (prevents noise bleed-through)
PSHS X,DP               ; Save music pointer and DP
LDA #$D0
TFR A,DP                ; Set DP=$D0 for Sound_Byte
LDA #7                  ; PSG reg 7 = Mixer
LDB #$3F                ; All channels disabled (bits 0-5 only; bits 6-7=0=IOA/IOB input!)
JSR Sound_Byte
LDA #8                  ; PSG reg 8 = Volume channel A
LDB #0
JSR Sound_Byte
LDA #9                  ; PSG reg 9 = Volume channel B
LDB #0
JSR Sound_Byte
LDA #10                 ; PSG reg 10 = Volume channel C
LDB #0
JSR Sound_Byte
PULS X,DP               ; Restore music pointer and DP
STX >PSG_MUSIC_PTR      ; Store current music pointer (force extended)
STX >PSG_MUSIC_START    ; Store start pointer for loops (force extended)
CLR >PSG_DELAY_FRAMES   ; Clear delay counter
LDA #$01
STA >PSG_IS_PLAYING     ; Mark as playing (extended - var at 0xC8A0)
PMr_done:
RTS

; ============================================================================
; UPDATE_MUSIC_PSG - Update PSG (call every frame)
; Data format per event: FCB delay, FCB count, (FCB reg, FCB val)*N
; delay = frames since previous event (0 = apply immediately)
; End marker: FCB 0 after last event's count
; Loop marker: delay=$FF is treated as loop; OR count=$FF followed by FDB addr
; PSG_DELAY_FRAMES counts down to the next event fire point.
; PSG_MUSIC_PTR always points to delay byte of next pending event.
; ============================================================================
UPDATE_MUSIC_PSG:
LDA #$01
STA >PSG_MUSIC_ACTIVE   ; Mark music system active
LDA >PSG_IS_PLAYING
LBEQ PSG_update_done    ; Not playing

; Check if delay counter is running
LDA >PSG_DELAY_FRAMES
BEQ PSG_read_delay      ; Counter=0: time to read next delay byte
DECA
STA >PSG_DELAY_FRAMES
LBNE PSG_update_done    ; Still waiting
BRA PSG_process_event   ; Counter just hit 0: apply the event

PSG_read_delay:
LDX >PSG_MUSIC_PTR      ; PTR → delay byte of current event
LDB ,X+                 ; Consume delay byte, X → count byte
CMPB #$FF
LBEQ PSG_music_loop_d   ; $FF as delay = loop command
STB >PSG_DELAY_FRAMES   ; Store delay count
STX >PSG_MUSIC_PTR      ; Advance PTR past delay byte (now at count byte)
BEQ PSG_process_event   ; delay=0: apply immediately
DEC >PSG_DELAY_FRAMES   ; Decrement once (fires after delay-1 more frames)
LBRA PSG_update_done    ; Wait

PSG_process_event:
LDX >PSG_MUSIC_PTR      ; PTR is at count byte
LDB ,X+
LBEQ PSG_music_ended    ; Count=0 means end
CMPB #$FF
LBEQ PSG_music_loop     ; Count=$FF means loop

PSHS B                  ; Save count on stack
PSG_write_loop:
LDA ,X+                 ; Load register number
LDB ,X+                 ; Load register value
PSHS X                  ; Save pointer

; WRITE_PSG sequence (direct VIA access)
STA VIA_port_a          ; Store register number
LDA #$19                ; BDIR=1, BC1=1 (LATCH)
STA VIA_port_b
LDA #$01                ; BDIR=0, BC1=0 (INACTIVE)
STA VIA_port_b
LDA VIA_port_a          ; Read status
STB VIA_port_a          ; Store data
LDB #$11                ; BDIR=1, BC1=0 (WRITE)
STB VIA_port_b
LDB #$01                ; BDIR=0, BC1=0 (INACTIVE)
STB VIA_port_b

PULS X                  ; Restore pointer
PULS B                  ; Get counter
DECB
BEQ PSG_event_done      ; Done with this event
PSHS B                  ; Save counter back
BRA PSG_write_loop

PSG_event_done:
STX >PSG_MUSIC_PTR      ; PTR → delay byte of next event
CLR >PSG_DELAY_FRAMES   ; Trigger PSG_read_delay next frame
LBRA PSG_update_done

PSG_music_ended:
CLR >PSG_IS_PLAYING
LBRA PSG_update_done

PSG_music_loop:
; count=$FF: X points after $FF, at FDB loop address
LDD ,X
STD >PSG_MUSIC_PTR
CLR >PSG_DELAY_FRAMES
LBRA PSG_update_done

PSG_music_loop_d:
; delay=$FF: X points after $FF, at FDB loop address
LDD ,X
STD >PSG_MUSIC_PTR
CLR >PSG_DELAY_FRAMES

PSG_update_done:
CLR >PSG_MUSIC_ACTIVE   ; Clear flag (music system done)
RTS

; ============================================================================
; STOP_MUSIC_RUNTIME - Stop music playback
; ============================================================================
STOP_MUSIC_RUNTIME:
CLR >PSG_IS_PLAYING     ; Clear playing flag
CLR >PSG_MUSIC_PTR      ; Clear pointer high byte
CLR >PSG_MUSIC_PTR+1    ; Clear pointer low byte
; Mute all PSG channels so the last note doesn't keep sounding
PSHS DP
LDA #$D0
TFR A,DP                ; Set DP=$D0 for Sound_Byte
LDA #8                  ; PSG reg 8 = Volume Channel A
LDB #0
JSR Sound_Byte
LDA #9                  ; PSG reg 9 = Volume Channel B
LDB #0
JSR Sound_Byte
LDA #10                 ; PSG reg 10 = Volume Channel C
LDB #0
JSR Sound_Byte
PULS DP
RTS

; ============================================================================
; AUDIO_UPDATE - Unified music + SFX update (auto-injected after WAIT_RECAL)
; ============================================================================
; Uses Sound_Byte (BIOS) for PSG writes - compatible with both systems
; Sets DP=$D0 once at entry, restores at exit

AUDIO_UPDATE:
PSHS DP                 ; Save current DP
LDA #$D0                ; Set DP=$D0 (Sound_Byte requirement)
TFR A,DP

        ; MULTIBANK: Switch to music's bank before accessing data
LDA >CURRENT_ROM_BANK   ; Get current bank
PSHS A                  ; Save on stack
LDA >PSG_MUSIC_BANK     ; Get music's bank
CMPA ,S                 ; Compare with current bank
BEQ AU_BANK_OK          ; Skip switch if same
STA >CURRENT_ROM_BANK   ; Update RAM tracker
STA $DF00               ; Switch bank hardware register
AU_BANK_OK:

        ; UPDATE MUSIC
LDA >PSG_IS_PLAYING     ; Check if music is playing
BEQ AU_SKIP_MUSIC       ; Skip if not

; Check delay counter first
LDA >PSG_DELAY_FRAMES   ; Load delay counter
BEQ AU_MUSIC_READ       ; If zero, read next frame data
DECA                    ; Decrement delay
STA >PSG_DELAY_FRAMES   ; Store back
CMPA #0                 ; Check if it just reached zero
BNE AU_UPDATE_SFX       ; If not zero yet, skip this frame

; Delay just reached zero, X points to count byte already
LDX >PSG_MUSIC_PTR      ; Load music pointer (points to count)
BRA AU_MUSIC_READ_COUNT ; Skip delay read, go straight to count

AU_MUSIC_READ:
LDX >PSG_MUSIC_PTR      ; Load music pointer

; Check if we need to read delay or we're ready for count
; PSG_DELAY_FRAMES just reached 0, so we read delay byte first
LDB ,X+                 ; Read delay counter (X now points to count byte)
CMPB #$FF               ; Check for loop marker
BEQ AU_MUSIC_LOOP       ; Handle loop
CMPB #0                 ; Check if delay is 0
BNE AU_MUSIC_HAS_DELAY  ; If not 0, process delay

; Delay is 0, read count immediately
AU_MUSIC_NO_DELAY:
AU_MUSIC_READ_COUNT:
LDB ,X+                 ; Read count (number of register writes)
BEQ AU_MUSIC_ENDED      ; If 0, end of music
CMPB #$FF               ; Check for loop marker (can appear after delay)
BEQ AU_MUSIC_LOOP       ; Handle loop
BRA AU_MUSIC_PROCESS_WRITES

AU_MUSIC_HAS_DELAY:
; B has delay > 0, store it and skip to next frame
DECB                    ; Delay-1 (we consume this frame)
BEQ AU_MUSIC_READ_COUNT ; delay was 1: X already at count byte, process immediately
STB >PSG_DELAY_FRAMES   ; Save delay counter
STX >PSG_MUSIC_PTR      ; Save pointer (X points to count byte)
BRA AU_UPDATE_SFX       ; Skip reading data this frame

AU_MUSIC_PROCESS_WRITES:
PSHS B                  ; Save count

AU_MUSIC_WRITE_LOOP:
LDA ,X+                 ; Load register number
LDB ,X+                 ; Load register value
PSHS X                  ; Save pointer
JSR Sound_Byte          ; Write to PSG using BIOS (DP=$D0)
PULS X                  ; Restore pointer
PULS B                  ; Get counter
DECB                    ; Decrement
BEQ AU_MUSIC_DONE       ; Done if count=0
PSHS B                  ; Save counter
BRA AU_MUSIC_WRITE_LOOP ; Continue

AU_MUSIC_DONE:
STX >PSG_MUSIC_PTR      ; Update music pointer
BRA AU_UPDATE_SFX       ; Now update SFX

AU_MUSIC_ENDED:
CLR >PSG_IS_PLAYING     ; Stop music
BRA AU_UPDATE_SFX       ; Continue to SFX

AU_MUSIC_LOOP:
LDD ,X                  ; Load loop target
STD >PSG_MUSIC_PTR      ; Set music pointer to loop
CLR >PSG_DELAY_FRAMES   ; Clear delay on loop
BRA AU_UPDATE_SFX       ; Continue to SFX

AU_SKIP_MUSIC:
BRA AU_UPDATE_SFX       ; Skip music, go to SFX

; UPDATE SFX (channel C: registers 4/5=tone, 6=noise, 10=volume, 7=mixer)
AU_UPDATE_SFX:
LDA >SFX_ACTIVE         ; Check if SFX is active
BEQ AU_DONE             ; Skip if not active

        ; MULTIBANK: Switch to SFX bank before reading SFX data
LDA >SFX_BANK           ; Get SFX bank ID
STA >CURRENT_ROM_BANK   ; Update RAM tracker
STA $DF00               ; Switch bank hardware register

        JSR sfx_doframe         ; Process one SFX frame (uses Sound_Byte internally)

AU_DONE:
        ; MULTIBANK: Restore original bank
PULS A                  ; Get saved bank from stack
STA >CURRENT_ROM_BANK   ; Update RAM tracker
STA $DF00               ; Restore bank hardware register
        PULS DP                 ; Restore original DP
RTS

; ============================================================================
; AYFX SOUND EFFECTS PLAYER (Richard Chadd original system)
; ============================================================================
; Uses channel C (registers 4/5=tone, 6=noise, 10=volume, 7=mixer bit2/bit5)
; RAM variables: SFX_PTR (16-bit), SFX_ACTIVE (8-bit)
; AYFX format: flag byte + optional data per frame, end marker $D0 $20
; Flag bits: 0-3=volume, 4=disable tone, 5=tone data present,
;            6=noise data present, 7=disable noise
; ============================================================================

; PLAY_SFX_RUNTIME - Start SFX playback
; Input: X = pointer to AYFX data
PLAY_SFX_RUNTIME:
STX >SFX_PTR           ; Store pointer (force extended addressing)
LDA #$01
STA >SFX_ACTIVE        ; Mark as active
RTS

; SFX_UPDATE - Process one AYFX frame (call once per frame in loop)
SFX_UPDATE:
LDA >SFX_ACTIVE        ; Check if active
BEQ noay               ; Not active, skip
JSR sfx_doframe        ; Process one frame
noay:
RTS

; sfx_doframe - AYFX frame parser (Richard Chadd original)
sfx_doframe:
LDU >SFX_PTR           ; Get current frame pointer
LDB ,U                 ; Read flag byte (NO auto-increment)
CMPB #$D0              ; Check end marker (first byte)
BNE sfx_checktonefreq  ; Not end, continue
LDB 1,U                ; Check second byte at offset 1
CMPB #$20              ; End marker $D0 $20?
BEQ sfx_endofeffect    ; Yes, stop

sfx_checktonefreq:
LEAY 1,U               ; Y = pointer to tone/noise data
LDB ,U                 ; Reload flag byte (Sound_Byte corrupts B)
BITB #$20              ; Bit 5: tone data present?
BEQ sfx_checknoisefreq ; No, skip tone
; Set tone frequency (channel C = reg 4/5)
LDB 2,U                ; Get LOW byte (fine tune)
LDA #$04               ; Register 4
JSR Sound_Byte         ; Write to PSG
LDB 1,U                ; Get HIGH byte (coarse tune)
LDA #$05               ; Register 5
JSR Sound_Byte         ; Write to PSG
LEAY 2,Y               ; Skip 2 tone bytes

sfx_checknoisefreq:
LDB ,U                 ; Reload flag byte
BITB #$40              ; Bit 6: noise data present?
BEQ sfx_checkvolume    ; No, skip noise
LDB ,Y                 ; Get noise period
LDA #$06               ; Register 6
JSR Sound_Byte         ; Write to PSG
LEAY 1,Y               ; Skip 1 noise byte

sfx_checkvolume:
LDB ,U                 ; Reload flag byte
ANDB #$0F              ; Get volume from bits 0-3
LDA #$0A               ; Register 10 (volume C)
JSR Sound_Byte         ; Write to PSG

; Combined mixer update: read shadow once, apply tone+noise, write once
sfx_updatemixer:
LDB $C807              ; Read mixer shadow ONCE
LDA ,U                 ; Load flag byte into A
; Handle tone (flag bit 4 → mixer bit 2)
BITA #$10              ; Bit 4: disable tone?
BNE sfx_m_tonedis
ANDB #$FB              ; Clear bit 2 (enable tone C)
BRA sfx_m_noise
sfx_m_tonedis:
ORB #$04               ; Set bit 2 (disable tone C)
sfx_m_noise:
; Handle noise (flag bit 7 → mixer bit 5)
BITA #$80              ; Bit 7: disable noise?
BNE sfx_m_noisedis
ANDB #$DF              ; Clear bit 5 (enable noise C)
BRA sfx_m_write
sfx_m_noisedis:
ORB #$20               ; Set bit 5 (disable noise C)
sfx_m_write:
STB $C807              ; Update mixer shadow
LDA #$07               ; Register 7 (mixer)
JSR Sound_Byte         ; Single write to PSG

sfx_nextframe:
STY >SFX_PTR            ; Update pointer for next frame
RTS

sfx_endofeffect:
; Stop SFX - silence channel C and restore mixer
CLR >SFX_ACTIVE         ; Mark as inactive
LDA #$0A                ; Register 10 (volume C)
LDB #$00                ; Volume = 0
JSR Sound_Byte
; Restore mixer: disable tone+noise on channel C
LDB $C807              ; Read mixer shadow
ORB #$24               ; Set bits 2+5 (disable tone C + noise C)
STB $C807              ; Update shadow
LDA #$07               ; Register 7
JSR Sound_Byte         ; Write mixer
LDD #$0000
STD >SFX_PTR            ; Clear pointer
RTS

;**** PRINT_TEXT String Data ****
PRINT_TEXT_STR_100361836:
    FCC "intro"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2718184010937820:
    FCC "crypt_logo"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_86053808672632355:
    FCC "exploration"
    FCB $80          ; Vectrex string terminator



;***************************************************************************
; INTERRUPT VECTORS (Bank #31 Fixed Window)
;***************************************************************************
ORG $FFFE
FDB CUSTOM_RESET
