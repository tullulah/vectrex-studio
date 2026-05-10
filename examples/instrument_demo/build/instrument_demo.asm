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
    FCC "VPY GAME"
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
DRAW_LINE_ARGS       EQU $C880+$0F   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$19   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$1B   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$1D   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$1E   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$1F   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$21   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$23   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$24   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
NOTE_STATE           EQU $C880+$25   ; Pitched note state (10 bytes x 3 channels) (30 bytes)
NOTE_ARG_INSTR       EQU $C880+$43   ; PLAY_NOTE argument: instrument ROM block address (2 bytes)
NOTE_ARG_CHANNEL     EQU $C880+$45   ; PLAY_NOTE argument: channel (0/1/2) (1 bytes)
NOTE_ARG_NOTE        EQU $C880+$46   ; PLAY_NOTE argument: MIDI note (24-107) (1 bytes)
VAR_MELODY           EQU $C880+$47   ; User variable: melody (2 bytes)
VAR_MELODY_LEN       EQU $C880+$49   ; User variable: melody_len (2 bytes)
VAR_BASS             EQU $C880+$4B   ; User variable: bass (2 bytes)
VAR_NOTE_TIMER       EQU $C880+$4D   ; User variable: note_timer (2 bytes)
VAR_NOTE_INDEX       EQU $C880+$4F   ; User variable: note_index (2 bytes)
VAR_ARG0             EQU $CB80   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $CB82   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $CB84   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $CB86   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $CB88   ; Function argument 4 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $CB8A   ; Current ROM bank ID (multibank tracking) (1 bytes)
; Array length constants
ARRAY_MELODY_LEN         EQU 14   ; 14 elements
ARRAY_BASS_LEN         EQU 14   ; 14 elements

;***************************************************************************
; ARRAY DATA (ROM literals)
;***************************************************************************
; Arrays are stored in ROM and accessed via pointers
; At startup, main() initializes VAR_{name} to point to ARRAY_{name}_DATA

; Array literal for variable 'melody' (14 elements, 2 bytes each)
ARRAY_MELODY_DATA:
    FDB 60   ; Element 0
    FDB 60   ; Element 1
    FDB 67   ; Element 2
    FDB 67   ; Element 3
    FDB 69   ; Element 4
    FDB 69   ; Element 5
    FDB 67   ; Element 6
    FDB 65   ; Element 7
    FDB 65   ; Element 8
    FDB 64   ; Element 9
    FDB 64   ; Element 10
    FDB 62   ; Element 11
    FDB 62   ; Element 12
    FDB 60   ; Element 13

; Array literal for variable 'bass' (14 elements, 2 bytes each)
ARRAY_BASS_DATA:
    FDB 48   ; Element 0
    FDB 48   ; Element 1
    FDB 55   ; Element 2
    FDB 55   ; Element 3
    FDB 57   ; Element 4
    FDB 57   ; Element 5
    FDB 55   ; Element 6
    FDB 53   ; Element 7
    FDB 53   ; Element 8
    FDB 52   ; Element 9
    FDB 52   ; Element 10
    FDB 50   ; Element 11
    FDB 50   ; Element 12
    FDB 48   ; Element 13


;***************************************************************************
; MAIN PROGRAM
;***************************************************************************

MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    LDA #$F8
    STA TEXT_SCALE_H      ; Default height = -8 (normal size)
    LDA #$48
    STA TEXT_SCALE_W      ; Default width = 72 (normal size)
    ; Initialize NOTE_STATE channel IDs (pre-clear active flags)
    LDA #0
    STA NOTE_STATE        ; channel A: id=0, active=0 (initial)
    CLR NOTE_STATE+1      ; active=0
    LDA #1
    STA NOTE_STATE+10     ; channel B: id=1
    CLR NOTE_STATE+11     ; active=0
    LDA #2
    STA NOTE_STATE+20     ; channel C: id=2
    CLR NOTE_STATE+21     ; active=0
    LDD #0
    STD VAR_NOTE_TIMER
    LDD #0
    STD VAR_NOTE_INDEX
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
    CLR >$C811  ; Force-clear Vec_Buttons before first loop() frame

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    JSR NOTE_UPDATE_RUNTIME  ; Auto-injected: tick note timers + arpeggio
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_NOTE_TIMER
    CMPD TMPVAL
    LBLE .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_1
    ; PLAY_NOTE("pluck", channel, note)
    LDX #_PLUCK_INSTR
    STX >NOTE_ARG_INSTR
    LDD #0
    STB >NOTE_ARG_CHANNEL
    LDX #ARRAY_MELODY_DATA  ; Array base
    LDD >VAR_NOTE_INDEX
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STB >NOTE_ARG_NOTE
    JSR PLAY_NOTE_RUNTIME
    LDD #0
    STD RESULT
    ; PLAY_NOTE("bell", channel, note)
    LDX #_BELL_INSTR
    STX >NOTE_ARG_INSTR
    LDD #1
    STB >NOTE_ARG_CHANNEL
    LDX #ARRAY_BASS_DATA  ; Array base
    LDD >VAR_NOTE_INDEX
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STB >NOTE_ARG_NOTE
    JSR PLAY_NOTE_RUNTIME
    LDD #0
    STD RESULT
    LDD >VAR_NOTE_INDEX
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_NOTE_INDEX
    LDD #14  ; const melody_len
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_NOTE_INDEX
    CMPD TMPVAL
    LBGE .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    LBEQ IF_NEXT_3
    LDD #0
    STD VAR_NOTE_INDEX
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LDD #12
    STD VAR_NOTE_TIMER
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    LDD >VAR_NOTE_TIMER
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_NOTE_TIMER
    ; SET_INTENSITY: Set drawing intensity
    LDD #64
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD VAR_ARG0
    LDD #40
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_7255613315621351036      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD VAR_ARG0
    LDD #20
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_4519249404345677336      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    RTS

;***************************************************************************
; EMBEDDED ASSETS (vectors, music, levels, SFX)
;***************************************************************************

; Instrument: bell (duration=18fr, vol=13, arp=2)
_BELL_INSTR:
	FCB $12          ; [0] duration_frames
	FCB $0D          ; [1] volume (0-15)
	FCB $02          ; [2] arpeggio_count
	FCB $04          ; [3] arpeggio_speed_frames
	FCB $00          ; [4] arpeggio_intervals[0] (signed)
	FCB $04          ; [5] arpeggio_intervals[1]
	FCB $00          ; [6] arpeggio_intervals[2]
	FCB $00          ; [7] arpeggio_intervals[3]
	FCB $00          ; [8] noise_enabled
	FCB $0F          ; [9] noise_period
	FCB $00          ; [10] pitch_sweep_delta (signed)
	FCB $00          ; [11] pitch_sweep_duration_frames
	FCB $00,$00,$00,$00   ; [12-15] reserved

; Instrument: pluck (duration=10fr, vol=14, arp=0)
_PLUCK_INSTR:
	FCB $0A          ; [0] duration_frames
	FCB $0E          ; [1] volume (0-15)
	FCB $00          ; [2] arpeggio_count
	FCB $02          ; [3] arpeggio_speed_frames
	FCB $00          ; [4] arpeggio_intervals[0] (signed)
	FCB $00          ; [5] arpeggio_intervals[1]
	FCB $00          ; [6] arpeggio_intervals[2]
	FCB $00          ; [7] arpeggio_intervals[3]
	FCB $00          ; [8] noise_enabled
	FCB $0F          ; [9] noise_period
	FCB $FF          ; [10] pitch_sweep_delta (signed)
	FCB $08          ; [11] pitch_sweep_duration_frames
	FCB $00,$00,$00,$00   ; [12-15] reserved

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
    LDA >TEXT_SCALE_H ; height (signed byte, e.g. $F8=-8)
    STA >$C82A      ; Vec_Text_Height: controls character Y scale
    LDA >TEXT_SCALE_W ; width (unsigned byte, e.g. 72)
    STA >$C82B      ; Vec_Text_Width: controls character X spacing
    LDA >VAR_ARG1+1 ; Y coordinate
    LDB >VAR_ARG0+1 ; X coordinate
    JSR Print_Str_d
    LDA #$F8
    STA >$C82A      ; Restore Vec_Text_Height to normal (-8)
    LDA #$48
    STA >$C82B      ; Restore Vec_Text_Width to normal (72)
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

; ============================================================================
; NOTE_PERIOD_TABLE — MIDI note 24 (C1) to 107 (B7) → AY-3-8910 period
; Each entry is a 2-byte FDB (big-endian). Index = midi_note - 24.
; Formula: period = round(88200 / (440 * 2^((midi_note - 69) / 12)))
; ============================================================================
NOTE_PERIOD_TABLE:
    FDB 2697    ; MIDI 24 (C1) freq=32.7Hz
    FDB 2546    ; MIDI 25 (C#1) freq=34.6Hz
    FDB 2403    ; MIDI 26 (D1) freq=36.7Hz
    FDB 2268    ; MIDI 27 (D#1) freq=38.9Hz
    FDB 2141    ; MIDI 28 (E1) freq=41.2Hz
    FDB 2020    ; MIDI 29 (F1) freq=43.7Hz
    FDB 1907    ; MIDI 30 (F#1) freq=46.2Hz
    FDB 1800    ; MIDI 31 (G1) freq=49.0Hz
    FDB 1699    ; MIDI 32 (G#1) freq=51.9Hz
    FDB 1604    ; MIDI 33 (A1) freq=55.0Hz
    FDB 1514    ; MIDI 34 (A#1) freq=58.3Hz
    FDB 1429    ; MIDI 35 (B1) freq=61.7Hz
    FDB 1348    ; MIDI 36 (C2) freq=65.4Hz
    FDB 1273    ; MIDI 37 (C#2) freq=69.3Hz
    FDB 1201    ; MIDI 38 (D2) freq=73.4Hz
    FDB 1134    ; MIDI 39 (D#2) freq=77.8Hz
    FDB 1070    ; MIDI 40 (E2) freq=82.4Hz
    FDB 1010    ; MIDI 41 (F2) freq=87.3Hz
    FDB 954    ; MIDI 42 (F#2) freq=92.5Hz
    FDB 900    ; MIDI 43 (G2) freq=98.0Hz
    FDB 849    ; MIDI 44 (G#2) freq=103.8Hz
    FDB 802    ; MIDI 45 (A2) freq=110.0Hz
    FDB 757    ; MIDI 46 (A#2) freq=116.5Hz
    FDB 714    ; MIDI 47 (B2) freq=123.5Hz
    FDB 674    ; MIDI 48 (C3) freq=130.8Hz
    FDB 636    ; MIDI 49 (C#3) freq=138.6Hz
    FDB 601    ; MIDI 50 (D3) freq=146.8Hz
    FDB 567    ; MIDI 51 (D#3) freq=155.6Hz
    FDB 535    ; MIDI 52 (E3) freq=164.8Hz
    FDB 505    ; MIDI 53 (F3) freq=174.6Hz
    FDB 477    ; MIDI 54 (F#3) freq=185.0Hz
    FDB 450    ; MIDI 55 (G3) freq=196.0Hz
    FDB 425    ; MIDI 56 (G#3) freq=207.7Hz
    FDB 401    ; MIDI 57 (A3) freq=220.0Hz
    FDB 378    ; MIDI 58 (A#3) freq=233.1Hz
    FDB 357    ; MIDI 59 (B3) freq=246.9Hz
    FDB 337    ; MIDI 60 (C4) freq=261.6Hz
    FDB 318    ; MIDI 61 (C#4) freq=277.2Hz
    FDB 300    ; MIDI 62 (D4) freq=293.7Hz
    FDB 283    ; MIDI 63 (D#4) freq=311.1Hz
    FDB 268    ; MIDI 64 (E4) freq=329.6Hz
    FDB 253    ; MIDI 65 (F4) freq=349.2Hz
    FDB 238    ; MIDI 66 (F#4) freq=370.0Hz
    FDB 225    ; MIDI 67 (G4) freq=392.0Hz
    FDB 212    ; MIDI 68 (G#4) freq=415.3Hz
    FDB 200    ; MIDI 69 (A4) freq=440.0Hz
    FDB 189    ; MIDI 70 (A#4) freq=466.2Hz
    FDB 179    ; MIDI 71 (B4) freq=493.9Hz
    FDB 169    ; MIDI 72 (C5) freq=523.3Hz
    FDB 159    ; MIDI 73 (C#5) freq=554.4Hz
    FDB 150    ; MIDI 74 (D5) freq=587.3Hz
    FDB 142    ; MIDI 75 (D#5) freq=622.3Hz
    FDB 134    ; MIDI 76 (E5) freq=659.3Hz
    FDB 126    ; MIDI 77 (F5) freq=698.5Hz
    FDB 119    ; MIDI 78 (F#5) freq=740.0Hz
    FDB 113    ; MIDI 79 (G5) freq=784.0Hz
    FDB 106    ; MIDI 80 (G#5) freq=830.6Hz
    FDB 100    ; MIDI 81 (A5) freq=880.0Hz
    FDB 95    ; MIDI 82 (A#5) freq=932.3Hz
    FDB 89    ; MIDI 83 (B5) freq=987.8Hz
    FDB 84    ; MIDI 84 (C6) freq=1046.5Hz
    FDB 80    ; MIDI 85 (C#6) freq=1108.7Hz
    FDB 75    ; MIDI 86 (D6) freq=1174.7Hz
    FDB 71    ; MIDI 87 (D#6) freq=1244.5Hz
    FDB 67    ; MIDI 88 (E6) freq=1318.5Hz
    FDB 63    ; MIDI 89 (F6) freq=1396.9Hz
    FDB 60    ; MIDI 90 (F#6) freq=1480.0Hz
    FDB 56    ; MIDI 91 (G6) freq=1568.0Hz
    FDB 53    ; MIDI 92 (G#6) freq=1661.2Hz
    FDB 50    ; MIDI 93 (A6) freq=1760.0Hz
    FDB 47    ; MIDI 94 (A#6) freq=1864.7Hz
    FDB 45    ; MIDI 95 (B6) freq=1975.5Hz
    FDB 42    ; MIDI 96 (C7) freq=2093.0Hz
    FDB 40    ; MIDI 97 (C#7) freq=2217.5Hz
    FDB 38    ; MIDI 98 (D7) freq=2349.3Hz
    FDB 35    ; MIDI 99 (D#7) freq=2489.0Hz
    FDB 33    ; MIDI 100 (E7) freq=2637.0Hz
    FDB 32    ; MIDI 101 (F7) freq=2793.8Hz
    FDB 30    ; MIDI 102 (F#7) freq=2960.0Hz
    FDB 28    ; MIDI 103 (G7) freq=3136.0Hz
    FDB 27    ; MIDI 104 (G#7) freq=3322.4Hz
    FDB 25    ; MIDI 105 (A7) freq=3520.0Hz
    FDB 24    ; MIDI 106 (A#7) freq=3729.3Hz
    FDB 22    ; MIDI 107 (B7) freq=3951.1Hz

NOTE_CH_TONE_LO_REGS:
	FCB 0,2,4          ; R0(A), R2(B), R4(C) — tone period low
NOTE_CH_TONE_HI_REGS:
	FCB 1,3,5          ; R1(A), R3(B), R5(C) — tone period high
NOTE_CH_VOL_REGS:
	FCB 8,9,10         ; R8(A), R9(B), R10(C) — volume
NOTE_CH_MIX_TONE_BITS:
	FCB 1,2,4          ; mixer bit for tone A, B, C
NOTE_CH_MIX_NOISE_BITS:
	FCB 8,16,32        ; mixer bit for noise A, B, C

; ============================================================================
; PLAY_NOTE_RUNTIME
; Inputs (RAM): NOTE_ARG_INSTR (ptr), NOTE_ARG_CHANNEL (0/1/2), NOTE_ARG_NOTE (24-107)
; Fills NOTE_STATE slot and writes tone/volume/mixer to PSG via Sound_Byte.
; ============================================================================
PLAY_NOTE_RUNTIME:
    ; X = NOTE_STATE + channel*10
    LDA >NOTE_ARG_CHANNEL
    LDB #10
    MUL
    ADDD #NOTE_STATE
    TFR D,X
    STX >TMPPTR             ; save channel state ptr
    ; Fill state slot
    LDA >NOTE_ARG_CHANNEL
    STA ,X                  ; [+0] channel_id
    LDA #1
    STA 1,X                 ; [+1] active=1
    LDU >NOTE_ARG_INSTR     ; U = instrument block
    LDA ,U                  ; [instr+0] duration_frames
    STA 2,X                 ; [+2] frames_left
    LDA >NOTE_ARG_NOTE
    STA 3,X                 ; [+3] base_note
    STU 4,X                 ; [+4,5] instr_ptr
    CLR 6,X                 ; [+6] arp_pos=0
    LDA 2,U                 ; [instr+2] arpeggio_count
    BNE PNR_arp_on
    LDA #$FF
    BRA PNR_arp_store
PNR_arp_on:
    LDA 3,U                 ; [instr+3] arpeggio_speed_frames
PNR_arp_store:
    STA 7,X                 ; [+7] arp_timer
    ; Compute period for base_note
    LDA >NOTE_ARG_NOTE
    JSR pnr_note_to_period  ; D = AY period
    LDX >TMPPTR
    STD 8,X                 ; [+8,9] period hi:lo
    ; Write PSG (DP=$D0 required)
    LDA ,X
    STA >TMPVAL+1           ; save channel_id
    PSHS DP
    LDA #$D0
    TFR A,DP
    ; Tone period low
    LDB >TMPVAL+1
    LDU #NOTE_CH_TONE_LO_REGS
    LDA B,U                 ; A = PSG reg for tone-lo
    LDB 9,X                 ; B = period low byte
    JSR Sound_Byte
    ; Tone period high
    LDB >TMPVAL+1
    LDU #NOTE_CH_TONE_HI_REGS
    LDA B,U
    LDB 8,X                 ; B = period high (4 bits)
    ANDB #$0F
    JSR Sound_Byte
    ; Volume
    LDU >NOTE_ARG_INSTR
    LDB >TMPVAL+1
    PSHS X
    LDX #NOTE_CH_VOL_REGS
    LDA B,X
    PULS X
    LDB 1,U                 ; [instr+1] volume
    ANDB #$0F
    JSR Sound_Byte
    ; Mixer R7: clear tone-enable bit (0=enabled)
    LDB >TMPVAL+1
    PSHS X
    LDX #NOTE_CH_MIX_TONE_BITS
    LDA B,X
    PULS X
    COMA                    ; invert: NAND mask to clear tone bit
    ANDA >$C807             ; clear bit in mixer shadow
    STA >$C807
    LDA #7
    LDB >$C807
    JSR Sound_Byte
    PULS DP
    RTS

; pnr_note_to_period: A = MIDI note (24-107) -> D = AY period
pnr_note_to_period:
    SUBA #24
    LDB A
    CLRA
    ASLB                    ; *2 for FDB entries
    ROLA
    PSHS D
    LDU #NOTE_PERIOD_TABLE
    LDD D,U
    PULS U                  ; discard offset
    RTS

; ============================================================================
; NOTE_UPDATE_RUNTIME — tick note timers and arpeggio (called every frame)
; ============================================================================
NOTE_UPDATE_RUNTIME:
    LDX #NOTE_STATE
    JSR note_upd_ch
    LDX #NOTE_STATE+10
    JSR note_upd_ch
    LDX #NOTE_STATE+20
    JSR note_upd_ch
    RTS

; note_upd_ch: X = ptr to 10-byte channel slot
note_upd_ch:
    LDA 1,X                 ; active?
    BEQ note_upd_done
    DEC 2,X                 ; frames_left--
    BNE note_upd_arp
    ; Duration expired: mute volume register
    CLR 1,X                 ; active=0
    LDA ,X                  ; channel_id
    STA >TMPVAL+1
    PSHS DP
    LDA #$D0
    TFR A,DP
    LDB >TMPVAL+1
    LDX #NOTE_CH_VOL_REGS
    LDA B,X
    LDB #0
    JSR Sound_Byte
    PULS DP
note_upd_done:
    RTS

note_upd_arp:
    LDU 4,X                 ; U = instr_ptr
    LDA 2,U                 ; [instr+2] arpeggio_count
    BEQ note_upd_done
    DEC 7,X                 ; arp_timer--
    BNE note_upd_done
    ; Reload timer
    LDA 3,U
    STA 7,X
    ; Advance arp_pos
    LDA 6,X
    INCA
    CMPA 2,U
    BLO note_upd_arpok
    CLRA
note_upd_arpok:
    STA 6,X
    ; new_note = base_note + intervals[arp_pos]
    STX >TMPPTR
    LEAX 4,U                ; X = &intervals[0]
    LDB A,X                 ; B = signed semitone offset
    LDX >TMPPTR
    LDA 3,X                 ; A = base_note
    ABA                     ; A = base_note + offset
    ; Clamp 24-107
    CMPA #24
    BHS note_upd_hi
    LDA #24
    BRA note_upd_period
note_upd_hi:
    CMPA #107
    BLS note_upd_period
    LDA #107
note_upd_period:
    STX >TMPPTR
    JSR pnr_note_to_period  ; D = period
    LDX >TMPPTR
    STD 8,X
    ; Write tone period to PSG
    LDA ,X                  ; channel_id
    STA >TMPVAL+1
    PSHS DP
    LDA #$D0
    TFR A,DP
    LDB >TMPVAL+1
    LDU #NOTE_CH_TONE_LO_REGS
    LDA B,U
    LDB 9,X
    JSR Sound_Byte
    LDB >TMPVAL+1
    LDU #NOTE_CH_TONE_HI_REGS
    LDA B,U
    LDB 8,X
    ANDB #$0F
    JSR Sound_Byte
    PULS DP
    RTS

;**** PRINT_TEXT String Data ****
PRINT_TEXT_STR_3020035:
    FCC "bell"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_106767393:
    FCC "pluck"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_4519249404345677336:
    FCC "TWINKLE TWINKLE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_7255613315621351036:
    FCC "INSTRUMENT DEMO"
    FCB $80          ; Vectrex string terminator

