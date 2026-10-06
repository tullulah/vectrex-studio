; VPy M6809 Assembly (Vectrex)
; ROM: 65536 bytes
; Multibank cartridge: 4 banks (16KB each)
; Helpers bank: 3 (fixed bank at $4000-$7FFF)

; ================================================
; BANK #0 - Entry point and main code
; ================================================

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
    FCC "PHYSICS"
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
TEXT_SCALE_H         EQU $C880+$3D   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$3E   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
DRAW_SCALE           EQU $C880+$3F   ; Current T1 scale for Draw_Sync_List_At_With_Mirrors ($7F=normal) (1 bytes)
VAR_ARG0             EQU $C880+$40   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $C880+$42   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $C880+$44   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $C880+$46   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $C880+$48   ; Function argument 4 (16-bit) (2 bytes)
VAR_ARG5             EQU $C880+$4A   ; Function argument 5 (16-bit) (2 bytes)
VAR_ARG6             EQU $C880+$4C   ; Function argument 6 (16-bit) (2 bytes)
VAR_ARG7             EQU $C880+$4E   ; Function argument 7 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $C880+$50   ; Current ROM bank ID (multibank tracking) (1 bytes)
VAR_BX               EQU $C880+$51   ; User variable: BX (2 bytes)
VAR_BY               EQU $C880+$53   ; User variable: BY (2 bytes)
VAR_VX               EQU $C880+$55   ; User variable: VX (2 bytes)
VAR_VY               EQU $C880+$57   ; User variable: VY (2 bytes)
VAR_JX               EQU $C880+$59   ; User variable: JX (2 bytes)
PSG_MUSIC_PTR        EQU $C880+$5B   ; PSG music data pointer (2 bytes)
PSG_MUSIC_START      EQU $C880+$5D   ; PSG music start pointer (for loops) (2 bytes)
PSG_MUSIC_ACTIVE     EQU $C880+$5F   ; PSG music active flag (1 bytes)
PSG_IS_PLAYING       EQU $C880+$60   ; PSG playing flag (1 bytes)
PSG_DELAY_FRAMES     EQU $C880+$61   ; PSG frame delay counter (1 bytes)
PSG_MUSIC_BANK       EQU $C880+$62   ; PSG music bank ID (for multibank) (1 bytes)
SFX_PTR              EQU $C880+$63   ; SFX data pointer (2 bytes)
SFX_ACTIVE           EQU $C880+$65   ; SFX active flag (1 bytes)
SFX_BANK             EQU $C880+$66   ; SFX bank ID (for multibank) (1 bytes)

;***************************************************************************
; MAIN PROGRAM (Bank #0)
;***************************************************************************

MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    CLR DRAW_VEC_INTENSITY ; 0 = use recorded/vector intensity (no override)
    LDA #$F8
    STA TEXT_SCALE_H      ; Default height = -8 (normal size)
    LDA #$48
    STA TEXT_SCALE_W      ; Default width = 72 (normal size)
    LDA #$7F
    STA DRAW_SCALE        ; Default T1 scale = $7F (127 = full BIOS scale)
    LDD #0
    STD VAR_BX
    LDD #60
    STD VAR_BY
    LDD #1
    STD VAR_VX
    LDD #0
    STD VAR_VY
    LDD #0
    STD VAR_JX
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
; VPy_LINE:18
; NATIVE_CALL: PLAY_MUSIC at line 18
    ; PLAY_MUSIC("music1") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
; VPy_LINE:19
    LDD #0
    STD VAR_BX
; VPy_LINE:20
    LDD #60
    STD VAR_BY
; VPy_LINE:21
    LDD #1
    STD VAR_VX
; VPy_LINE:22
    LDD #0
    STD VAR_VY

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    JSR $F1AA    ; DP_to_D0 (Joy_Analog requires DP=$D0)
    JSR $F1F5    ; Joy_Analog: poll all 4 axes once → $C81B-$C81E
    JSR Reset0Ref ; Restore beam state after Joy_Analog
    JSR $F1AF    ; DP_to_C8 (restore DP for RAM access)
; VPy_LINE:25
; NATIVE_CALL: PRINT_TEXT at line 25
    ; PRINT_TEXT: Print text at position
    LDD #-50
    STD >VAR_ARG0
    LDD #100
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_73146331687      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:26
; NATIVE_CALL: PRINT_TEXT at line 26
    ; PRINT_TEXT: Print text at position
    LDD #-50
    STD >VAR_ARG0
    LDD #85
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_60036694812      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:29
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_VY
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_VY
; VPy_LINE:32
; NATIVE_CALL: J1_X at line 32
    JSR J1X_BUILTIN
    STD RESULT
    STD VAR_JX
; VPy_LINE:33
    LDD #40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JX
    CMPD TMPVAL
    LBGT .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_1
; VPy_LINE:34
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_VX
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_VX
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
; VPy_LINE:35
    LDD #-40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JX
    CMPD TMPVAL
    LBLT .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    LBEQ IF_NEXT_3
; VPy_LINE:36
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_VX
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_VX
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
; VPy_LINE:39
    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed
    BITA #$01
    BNE .J1B1_0_ON
    LDD #0
    BRA .J1B1_0_END
.J1B1_0_ON:
    LDD #1
.J1B1_0_END:
    STD RESULT
    LBEQ IF_NEXT_5
; VPy_LINE:40
    LDD #8
    STD VAR_VY
; VPy_LINE:41
; NATIVE_CALL: PLAY_SFX at line 41
    ; PLAY_SFX("jump") - play SFX asset (index=1)
    LDX #1        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
; VPy_LINE:44
    LDD #6
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_VX
    CMPD TMPVAL
    LBGT .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    LBEQ IF_NEXT_7
; VPy_LINE:45
    LDD #6
    STD VAR_VX
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
; VPy_LINE:46
    LDD #-6
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_VX
    CMPD TMPVAL
    LBLT .CMP_3_TRUE
    LDD #0
    LBRA .CMP_3_END
.CMP_3_TRUE:
    LDD #1
.CMP_3_END:
    LBEQ IF_NEXT_9
; VPy_LINE:47
    LDD #-6
    STD VAR_VX
    LBRA IF_END_8
IF_NEXT_9:
IF_END_8:
; VPy_LINE:50
    LDD >VAR_VX
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_BX
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_BX
; VPy_LINE:51
    LDD >VAR_VY
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_BY
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_BY
; VPy_LINE:54
    LDD #-90
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BY
    CMPD TMPVAL
    LBLT .CMP_4_TRUE
    LDD #0
    LBRA .CMP_4_END
.CMP_4_TRUE:
    LDD #1
.CMP_4_END:
    LBEQ IF_NEXT_11
; VPy_LINE:55
    LDD #-90
    STD VAR_BY
; VPy_LINE:56
    LDD >VAR_VY
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #0
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_VY
; VPy_LINE:57
    LDD #12
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_VY
    CMPD TMPVAL
    LBGT .CMP_5_TRUE
    LDD #0
    LBRA .CMP_5_END
.CMP_5_TRUE:
    LDD #1
.CMP_5_END:
    LBEQ IF_NEXT_13
; VPy_LINE:58
    LDD #12
    STD VAR_VY
    LBRA IF_END_12
IF_NEXT_13:
IF_END_12:
; VPy_LINE:59
; NATIVE_CALL: PLAY_SFX at line 59
    ; PLAY_SFX("hit") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_10
IF_NEXT_11:
IF_END_10:
; VPy_LINE:62
    LDD #90
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BY
    CMPD TMPVAL
    LBGT .CMP_6_TRUE
    LDD #0
    LBRA .CMP_6_END
.CMP_6_TRUE:
    LDD #1
.CMP_6_END:
    LBEQ IF_NEXT_15
; VPy_LINE:63
    LDD #90
    STD VAR_BY
; VPy_LINE:64
    LDD >VAR_VY
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #0
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_VY
    LBRA IF_END_14
IF_NEXT_15:
IF_END_14:
; VPy_LINE:67
    LDD #100
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BX
    CMPD TMPVAL
    LBGT .CMP_7_TRUE
    LDD #0
    LBRA .CMP_7_END
.CMP_7_TRUE:
    LDD #1
.CMP_7_END:
    LBEQ IF_NEXT_17
; VPy_LINE:68
    LDD #100
    STD VAR_BX
; VPy_LINE:69
    LDD >VAR_VX
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #0
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_VX
; VPy_LINE:70
; NATIVE_CALL: PLAY_SFX at line 70
    ; PLAY_SFX("hit") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_16
IF_NEXT_17:
IF_END_16:
; VPy_LINE:72
    LDD #-100
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BX
    CMPD TMPVAL
    LBLT .CMP_8_TRUE
    LDD #0
    LBRA .CMP_8_END
.CMP_8_TRUE:
    LDD #1
.CMP_8_END:
    LBEQ IF_NEXT_19
; VPy_LINE:73
    LDD #-100
    STD VAR_BX
; VPy_LINE:74
    LDD >VAR_VX
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #0
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_VX
; VPy_LINE:75
; NATIVE_CALL: PLAY_SFX at line 75
    ; PLAY_SFX("hit") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_18
IF_NEXT_19:
IF_END_18:
; VPy_LINE:78
; NATIVE_CALL: DRAW_VECTOR at line 78
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bubble_medium (index=0, 1 paths)
    LDD >VAR_BX
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_1          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_BY
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_1
    LDB #$FF
.sx_pos_1:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #0        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_1:
    LDD #0
    STD RESULT
; VPy_LINE:81
; NATIVE_CALL: DRAW_LINE at line 81
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD #-100
    STD DRAW_LINE_ARGS+0    ; x0
    LDD #-110
    STD DRAW_LINE_ARGS+2    ; y0
    LDD #100
    STD DRAW_LINE_ARGS+4    ; x1
    LDD #-110
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #60
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX (after all game logic)
    RTS


; ================================================
; BANK #1 - 0 function(s), 1 asset(s)
; ================================================
    ORG $0000  ; Sequential bank model

;***************************************************************************
; ASSETS IN BANK #1 (4 assets)
;***************************************************************************

; Generated from music1.vmus (internal name: pang_theme)
; Tempo: 120 BPM, Total events: 34 (PSG Direct format)
; Format: FCB count, FCB reg, val, ... (per frame), FCB 0 (end)

_MUSIC1_MUSIC:
    ; Frame-based PSG register writes
    FCB     0              ; Delay 0 frames (maintain previous state)
    FCB     11              ; Frame 0 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $B3             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $99             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 12 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B3             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $99             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     13              ; Delay 13 frames (maintain previous state)
    FCB     10              ; Frame 25 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $8E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $99             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     25              ; Delay 25 frames (maintain previous state)
    FCB     11              ; Frame 50 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $78             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EF             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $99             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 62 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $78             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EF             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $99             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     13              ; Delay 13 frames (maintain previous state)
    FCB     10              ; Frame 75 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $5A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $EF             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $99             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     25              ; Delay 25 frames (maintain previous state)
    FCB     11              ; Frame 100 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $78             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B3             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $99             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 112 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $78             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B3             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $99             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 124 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $8E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $B3             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $99             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     26              ; Delay 26 frames (maintain previous state)
    FCB     11              ; Frame 150 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $B3             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $99             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 162 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B3             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $1C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $99             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     38              ; Delay 38 frames (maintain previous state)
    FCB     11              ; Frame 200 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $A0             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $0C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $FD             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 212 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A0             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $0C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $FD             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 224 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $86             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $0C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $FD             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     25              ; Delay 25 frames (maintain previous state)
    FCB     11              ; Frame 249 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $6B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $D5             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $FD             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     13              ; Delay 13 frames (maintain previous state)
    FCB     10              ; Frame 262 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $6B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $D5             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $FD             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     13              ; Delay 13 frames (maintain previous state)
    FCB     10              ; Frame 275 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $50             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $D5             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $FD             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     25              ; Delay 25 frames (maintain previous state)
    FCB     11              ; Frame 300 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $6B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A0             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $FD             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 312 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $6B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A0             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $FD             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     13              ; Delay 13 frames (maintain previous state)
    FCB     10              ; Frame 325 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $86             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A0             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $FD             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     25              ; Delay 25 frames (maintain previous state)
    FCB     11              ; Frame 350 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $A0             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $0C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $FD             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 362 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A0             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $0C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $FD             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     4               ; Tail delay before force-silence (preserve last note release)
    FCB     4               ; silence event (4 regs)
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3F             ; Reg 7 value
    FCB     34              ; Delay 34 frames before loop
    FCB     $FF             ; Loop command ($FF never valid as count)
    FDB     _MUSIC1_MUSIC       ; Jump to start (absolute address)


_HIT_SFX:
    ; SFX: hit (hit)
    ; Duration: 300ms (15fr), Freq: 200Hz, Channel: 0
    FCB $6C         ; Frame 0 - flags (vol=12, noisevol=12, tone=Y, noise=Y)
    FCB $01, $87  ; Tone period = 391 (big-endian)
    FCB $08         ; Noise period
    FCB $6B         ; Frame 1 - flags (vol=11, noisevol=11, tone=Y, noise=Y)
    FCB $01, $9D  ; Tone period = 413 (big-endian)
    FCB $08         ; Noise period
    FCB $6F         ; Frame 2 - flags (vol=15, noisevol=10, tone=Y, noise=Y)
    FCB $01, $B5  ; Tone period = 437 (big-endian)
    FCB $08         ; Noise period
    FCB $6F         ; Frame 3 - flags (vol=15, noisevol=8, tone=Y, noise=Y)
    FCB $01, $D1  ; Tone period = 465 (big-endian)
    FCB $08         ; Noise period
    FCB $6E         ; Frame 4 - flags (vol=14, noisevol=7, tone=Y, noise=Y)
    FCB $01, $F1  ; Tone period = 497 (big-endian)
    FCB $08         ; Noise period
    FCB $6D         ; Frame 5 - flags (vol=13, noisevol=6, tone=Y, noise=Y)
    FCB $02, $16  ; Tone period = 534 (big-endian)
    FCB $08         ; Noise period
    FCB $6C         ; Frame 6 - flags (vol=12, noisevol=5, tone=Y, noise=Y)
    FCB $02, $40  ; Tone period = 576 (big-endian)
    FCB $08         ; Noise period
    FCB $6C         ; Frame 7 - flags (vol=12, noisevol=4, tone=Y, noise=Y)
    FCB $02, $71  ; Tone period = 625 (big-endian)
    FCB $08         ; Noise period
    FCB $6C         ; Frame 8 - flags (vol=12, noisevol=2, tone=Y, noise=Y)
    FCB $02, $AC  ; Tone period = 684 (big-endian)
    FCB $08         ; Noise period
    FCB $6C         ; Frame 9 - flags (vol=12, noisevol=1, tone=Y, noise=Y)
    FCB $02, $F2  ; Tone period = 754 (big-endian)
    FCB $08         ; Noise period
    FCB $AC         ; Frame 10 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $03, $49  ; Tone period = 841 (big-endian)
    FCB $A9         ; Frame 11 - flags (vol=9, noisevol=0, tone=Y, noise=N)
    FCB $03, $B7  ; Tone period = 951 (big-endian)
    FCB $A7         ; Frame 12 - flags (vol=7, noisevol=0, tone=Y, noise=N)
    FCB $04, $46  ; Tone period = 1094 (big-endian)
    FCB $A4         ; Frame 13 - flags (vol=4, noisevol=0, tone=Y, noise=N)
    FCB $05, $07  ; Tone period = 1287 (big-endian)
    FCB $A2         ; Frame 14 - flags (vol=2, noisevol=0, tone=Y, noise=N)
    FCB $06, $1A  ; Tone period = 1562 (big-endian)
    FCB $D0, $20    ; End of effect marker


; Generated from bubble_medium.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 24
; X bounds: min=-15, max=15, width=30
; Center: (0, 0)

_BUBBLE_MEDIUM_WIDTH EQU 30
_BUBBLE_MEDIUM_HALF_WIDTH EQU 15
_BUBBLE_MEDIUM_HEIGHT EQU 30
_BUBBLE_MEDIUM_HALF_HEIGHT EQU 15
_BUBBLE_MEDIUM_CENTER_X EQU 0
_BUBBLE_MEDIUM_CENTER_Y EQU 0

_BUBBLE_MEDIUM_VECTORS:  ; Main entry (header + 1 path(s))
    FDB 1               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _BUBBLE_MEDIUM_PATH0        ; pointer to path 0

_BUBBLE_MEDIUM_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $00,$0F,0,0        ; path0: header (y=0, x=15)
    FCB $FF,$08,$FE          ; flag=-1, dy=8, dx=-2
    FCB $FF,$05,$FB          ; flag=-1, dy=5, dx=-5
    FCB $FF,$02,$F8          ; flag=-1, dy=2, dx=-8
    FCB $FF,$FE,$F8          ; flag=-1, dy=-2, dx=-8
    FCB $FF,$FB,$FB          ; flag=-1, dy=-5, dx=-5
    FCB $FF,$F8,$FE          ; flag=-1, dy=-8, dx=-2
    FCB $FF,$F8,$02          ; flag=-1, dy=-8, dx=2
    FCB $FF,$FB,$05          ; flag=-1, dy=-5, dx=5
    FCB $FF,$FE,$08          ; flag=-1, dy=-2, dx=8
    FCB $FF,$02,$08          ; flag=-1, dy=2, dx=8
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$07,$03          ; flag=-1, dy=7, dx=3
    FCB $FF,$04,$01          ; flag=-1, dy=4, dx=1
    FCB 2                ; End marker (path complete)

_JUMP_SFX:
    ; SFX: jump (jump)
    ; Duration: 180ms (9fr), Freq: 330Hz, Channel: 0
    FCB $A0         ; Frame 0 - flags (vol=0, noisevol=0, tone=Y, noise=N)
    FCB $01, $D9  ; Tone period = 473 (big-endian)
    FCB $AE         ; Frame 1 - flags (vol=14, noisevol=0, tone=Y, noise=N)
    FCB $01, $8F  ; Tone period = 399 (big-endian)
    FCB $AE         ; Frame 2 - flags (vol=14, noisevol=0, tone=Y, noise=N)
    FCB $01, $58  ; Tone period = 344 (big-endian)
    FCB $AD         ; Frame 3 - flags (vol=13, noisevol=0, tone=Y, noise=N)
    FCB $01, $2F  ; Tone period = 303 (big-endian)
    FCB $AC         ; Frame 4 - flags (vol=12, noisevol=0, tone=Y, noise=N)
    FCB $01, $0F  ; Tone period = 271 (big-endian)
    FCB $A9         ; Frame 5 - flags (vol=9, noisevol=0, tone=Y, noise=N)
    FCB $00, $F4  ; Tone period = 244 (big-endian)
    FCB $A7         ; Frame 6 - flags (vol=7, noisevol=0, tone=Y, noise=N)
    FCB $00, $DF  ; Tone period = 223 (big-endian)
    FCB $A4         ; Frame 7 - flags (vol=4, noisevol=0, tone=Y, noise=N)
    FCB $00, $CD  ; Tone period = 205 (big-endian)
    FCB $A2         ; Frame 8 - flags (vol=2, noisevol=0, tone=Y, noise=N)
    FCB $00, $BD  ; Tone period = 189 (big-endian)
    FCB $D0, $20    ; End of effect marker



; ================================================
; BANK #2 - 0 function(s) [EMPTY]
; ================================================
    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================
; BANK #3 - 0 function(s) [HELPERS ONLY]
; ================================================
    ORG $4000  ; Fixed bank (always visible at $4000-$7FFF)
    ; Runtime helpers (accessible from all banks)

;***************************************************************************
; ASSET LOOKUP TABLES (for banked asset access)
; Total: 1 vectors, 1 music, 2 sfx, 0 levels, 0 animations, 0 instruments, 0 enemies
;***************************************************************************

; Vector Asset Index Mapping:
;   0 = bubble_medium (Bank #1)

VECTOR_BANK_TABLE:
    FCB 1              ; Bank ID

VECTOR_ADDR_TABLE:
    FDB _BUBBLE_MEDIUM_VECTORS    ; bubble_medium

; Music Asset Index Mapping:
;   0 = music1 (Bank #1)

MUSIC_BANK_TABLE:
    FCB 1              ; Bank ID

MUSIC_ADDR_TABLE:
    FDB _MUSIC1_MUSIC    ; music1

; SFX Asset Index Mapping:
;   0 = hit (Bank #1)
;   1 = jump (Bank #1)

SFX_BANK_TABLE:
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID

SFX_ADDR_TABLE:
    FDB _HIT_SFX    ; hit
    FDB _JUMP_SFX    ; jump

; Legacy unified tables (all assets)
ASSET_BANK_TABLE:
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID

ASSET_ADDR_TABLE:
    FDB _MUSIC1_MUSIC    ; music1
    FDB _HIT_SFX    ; hit
    FDB _BUBBLE_MEDIUM_VECTORS    ; bubble_medium
    FDB _JUMP_SFX    ; jump

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

    ; Set DRAW_T1_SCALED to BIOS default ($7F) — SLR_DRAW_CLIPPED_PATH reads it
    ; when the fallback path is taken.
    LDA #$7F
    STA >DRAW_T1_SCALED
    ; Loop over all paths (header: FDB path_count, then FDB table)
    LDD ,X               ; D = path_count (16-bit FDB at header start)
    CMPD #0
    LBEQ DVB_DONE        ; No paths
    LEAY 2,X             ; Y = pointer to first FDB entry (after 2-byte header)
DVB_PATH_LOOP:
    PSHS D               ; Save remaining path count (2 bytes)
    LDX ,Y               ; X = path data address (FDB entry)
    ; Hybrid clip decision: fast DSWM if screen_x deep inside, slow SDCP near edges.
    LDA >DRAW_VEC_X_HI
    BEQ DVB_CHECK_POS
    INCA
    BNE DVB_USE_SDCP
    LDA >DRAW_VEC_X
    CMPA #$B0            ; -80
    BHS DVB_USE_DSWM
    BRA DVB_USE_SDCP
DVB_CHECK_POS:
    LDA >DRAW_VEC_X
    CMPA #80
    BLS DVB_USE_DSWM
DVB_USE_SDCP:
    JSR SLR_DRAW_CLIPPED_PATH
    BRA DVB_PATH_AFTER
DVB_USE_DSWM:
    JSR Draw_Sync_List_At_With_Mirrors
DVB_PATH_AFTER:
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
; PLAY_SFX_BANKED - Play SFX asset with automatic bank switching
; Input: X = SFX asset index (0-based)
; Uses: A, B, X
;***************************************************************************
PLAY_SFX_BANKED:
    ; Save index to U register (avoid stack order issues)
    TFR X,U              ; U = SFX index
    ; Save context: original bank on stack
    LDA CURRENT_ROM_BANK
    PSHS A               ; Stack: [A]

    ; Get SFX's bank from lookup table
    TFR U,D              ; D = SFX index (from U)
    LDX #SFX_BANK_TABLE
    LDA D,X              ; A = bank ID for this SFX
    STA CURRENT_ROM_BANK ; Update RAM tracker
    STA >SFX_BANK        ; Save SFX bank for AUDIO_UPDATE
    STA $DF00            ; Switch bank hardware register

    ; Get SFX's address from lookup table (2 bytes per entry)
    TFR U,D              ; Reload SFX index from U
    ASLB                 ; *2 for FDB entries
    ROLA
    LDX #SFX_ADDR_TABLE
    LEAX D,X             ; X points to address entry
    LDX ,X               ; X = actual SFX address in banked ROM

    ; Call PLAY_SFX_RUNTIME with X pointing to SFX data
    JSR PLAY_SFX_RUNTIME

    ; Restore original bank from stack
    PULS A               ; A = original bank
    STA CURRENT_ROM_BANK
    STA $DF00            ; Restore bank

    RTS

;***************************************************************************
; RUNTIME HELPERS
;***************************************************************************

VECTREX_PRINT_TEXT:
    ; VPy signature: PRINT_TEXT(x, y, string)
    ; BIOS signature: Print_Str_d(A=Y, B=X, U=string)
    LDA #$D0
    TFR A,DP
    JSR Intensity_5F
    JSR Reset0Ref
    LDU >VAR_ARG2
    LDA >TEXT_SCALE_H
    STA >$C82A          ; Vec_Text_Height
    LDA >TEXT_SCALE_W
    STA >$C82B          ; Vec_Text_Width
    LDA >VAR_ARG1+1
    LDB >VAR_ARG0+1
    LDX >$C82C
    PSHS X
    JSR Print_Str_d
    PULS X
    STX >$C82C
    LDA #$F8
    STA >$C82A
    LDA #$48
    STA >$C82B
    JSR $F1AF
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

; === JOYSTICK BUILTIN SUBROUTINES (cached, Joy_Analog runs once per frame) ===
; J1_X() - Read Joystick 1 X axis from cached BIOS value at $C81B
J1X_BUILTIN:
    LDB >$C81B   ; Vec_Joy_1_X (populated each frame by auto-injected Joy_Analog)
    SEX          ; Sign-extend B to D
    ADDD #2      ; Calibrate center offset
    RTS

; DRAW_LINE unified wrapper - handles 16-bit signed coordinates
; Args: DRAW_LINE_ARGS+0=x0, +2=y0, +4=x1, +6=y1, +8=intensity
; Resets beam to center, moves to (x0,y0), draws to (x1,y1)
DRAW_LINE_WRAPPER:
    ; Set DP to hardware registers
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref   ; Reset beam to center (0,0) before positioning
    LDA #$80
    STA <$04        ; VIA_t1_cnt_lo = $80 (ensure correct scale regardless of prior builtins)
    ; ALWAYS set intensity (no optimization)
    LDA >DRAW_LINE_ARGS+8+1  ; intensity (low byte) - EXTENDED addressing
    JSR Intensity_a
    ; Move to start position (y in A, x in B) - use low bytes (8-bit signed -127..+127)
    LDA >DRAW_LINE_ARGS+2+1  ; Y start (low byte) - EXTENDED addressing
    ADDA >VPY_MOVE_Y         ; Add MOVE Y offset
    LDB >DRAW_LINE_ARGS+0+1  ; X start (low byte) - EXTENDED addressing
    ADDB >VPY_MOVE_X         ; Add MOVE X offset
    JSR Moveto_d
    ; Compute deltas using 16-bit arithmetic
    ; dx = x1 - x0 (treating as signed 16-bit)
    LDD >DRAW_LINE_ARGS+4    ; x1 (16-bit) - EXTENDED
    SUBD >DRAW_LINE_ARGS+0   ; subtract x0 (16-bit) - EXTENDED
    STD >VLINE_DX_16 ; Store full 16-bit dx - EXTENDED
    ; dy = y1 - y0 (treating as signed 16-bit)
    LDD >DRAW_LINE_ARGS+6    ; y1 (16-bit) - EXTENDED
    SUBD >DRAW_LINE_ARGS+2   ; subtract y0 (16-bit) - EXTENDED
    STD >VLINE_DY_16 ; Store full 16-bit dy - EXTENDED
    ; SEGMENT 1: Clamp dy to ±127 and draw
    LDD >VLINE_DY_16 ; Load full dy - EXTENDED
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
    LDA >VLINE_DY_16+1  ; Use original low byte - EXTENDED
DLW_SEG1_DY_READY:
    STA >VLINE_DY    ; Save clamped dy for segment 1 - EXTENDED
    ; Clamp dx to ±127
    LDD >VLINE_DX_16  ; EXTENDED
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
    LDB >VLINE_DX_16+1  ; Use original low byte - EXTENDED
DLW_SEG1_DX_READY:
    STB >VLINE_DX    ; Save clamped dx for segment 1 - EXTENDED
    ; Draw segment 1
    CLR Vec_Misc_Count
    LDA >VLINE_DY  ; EXTENDED
    LDB >VLINE_DX  ; EXTENDED
    JSR Draw_Line_d ; Beam moves automatically
    ; Check if we need SEGMENT 2 (dy OR dx outside ±127 range)
    LDD >VLINE_DY_16 ; Reload original dy - EXTENDED
    CMPD #127
    BGT DLW_NEED_SEG2  ; dy > 127: needs segment 2
    CMPD #-128
    BLT DLW_NEED_SEG2  ; dy < -128: needs segment 2
    LDD >VLINE_DX_16 ; Also check dx - EXTENDED
    CMPD #127
    BGT DLW_NEED_SEG2  ; dx > 127: needs segment 2
    CMPD #-128
    BLT DLW_NEED_SEG2  ; dx < -128: needs segment 2
    BRA DLW_DONE       ; both dy and dx in range: no segment 2
DLW_NEED_SEG2:
    ; SEGMENT 2: Draw remaining dy and dx
    ; Calculate remaining dy
    LDD >VLINE_DY_16 ; Load original full dy - EXTENDED
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
    STD >VLINE_DY_REMAINING  ; Store remaining dy (16-bit) - EXTENDED
    ; Calculate remaining dx
    LDD >VLINE_DX_16 ; Load original full dx - EXTENDED
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
    STD >VLINE_DX_REMAINING  ; Store remaining dx (16-bit) - EXTENDED
    ; Setup for Draw_Line_d: A=dy, B=dx (CRITICAL: order matters!)
    LDA >VLINE_DY_REMAINING+1  ; Low byte of remaining dy - EXTENDED
    LDB >VLINE_DX_REMAINING+1  ; Low byte of remaining dx - EXTENDED
    CLR Vec_Misc_Count
    JSR Draw_Line_d ; Beam continues from segment 1 endpoint
DLW_DONE:
    LDA #$C8       ; CRITICAL: Restore DP to $C8 for our code
    TFR A,DP
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
; Silence all 3 PSG channels so the last note doesn't keep ringing
; until the next PLAY_MUSIC. DP is already $D0 (set by AUDIO_UPDATE).
LDA #8                  ; PSG reg 8 = Volume Channel A
LDB #0
JSR Sound_Byte
LDA #9                  ; PSG reg 9 = Volume Channel B
LDB #0
JSR Sound_Byte
LDA #10                 ; PSG reg 10 = Volume Channel C
LDB #0
JSR Sound_Byte
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
; Per-event write loop. Inlined PSG protocol instead of JSR Sound_Byte
; (~35 cycles vs ~92 incl JSR/RTS overhead — saves ~57 cycles per
; register write). For theme-style music with 8-10 writes per event,
; saves ~500-600 cycles per event frame → frees enough budget that the
; music event no longer pushes the frame over vsync. Mirrors the BIOS
; Sound_Byte protocol exactly (Vectrex VIA bits: BC1=bit3, BDIR=bit4).
PSHS B                  ; save register-write count on stack for in-place DEC
AU_MUSIC_WRITE_LOOP:
LDA ,X+                 ; A = register number
LDB ,X+                 ; B = register value
STA VIA_port_a          ; data bus = reg num
LDA #$19                ; BC1=1, BDIR=1 → LATCH ADDR
STA VIA_port_b
LDA #$01                ; back to INACTIVE (BC1=0, BDIR=0)
STA VIA_port_b
LDA VIA_port_a          ; READ STATUS — settling delay so PSG finishes
; latching the register address before we drive
; the value. Without this, the PSG occasionally
; writes the new value into the PREVIOUS register
; (audible as glitchy pitch / 'noisy' music,
; especially when other CPU activity perturbs
; the timing between this loop and adjacent code).
STB VIA_port_a          ; data bus = value
LDA #$11                ; BC1=0, BDIR=1 → WRITE DATA
STA VIA_port_b
LDA #$01                ; back to INACTIVE
STA VIA_port_b
DEC ,S                  ; decrement count on stack (in-place; no PSHS/PULS per iter)
BNE AU_MUSIC_WRITE_LOOP
LEAS 1,S                ; discard saved count

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
PRINT_TEXT_STR_103315:
    FCC "hit"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3273774:
    FCC "jump"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3232159404:
    FCC "music1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_60036694812:
    FCC "B1=JUMP"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_73146331687:
    FCC "PHYSICS"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_6459777946950754952:
    FCC "bubble_medium"
    FCB $80          ; Vectrex string terminator

