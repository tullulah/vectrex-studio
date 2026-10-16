; --- Motorola 6809 backend (Vectrex) title='JETPAC MINIMAL' origin=$0000 ---
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
    FCC "JETPAC MINIMAL"
    FCB $80
    FCB 0

;***************************************************************************
; CODE SECTION
;***************************************************************************

; === RAM VARIABLE DEFINITIONS (EQU) ===
; AUTO-GENERATED - All offsets calculated automatically
; Total RAM used: 128 bytes
RESULT               EQU $C880+$00   ; Main result temporary (2 bytes)
TMPLEFT              EQU $C880+$02   ; Left operand temp (2 bytes)
TMPLEFT2             EQU $C880+$04   ; Left operand temp 2 (for nested operations) (2 bytes)
TMPRIGHT             EQU $C880+$06   ; Right operand temp (2 bytes)
TMPRIGHT2            EQU $C880+$08   ; Right operand temp 2 (for nested operations) (2 bytes)
TMPPTR               EQU $C880+$0A   ; Pointer temp (used by DRAW_VECTOR, arrays, structs) (2 bytes)
TMPPTR2              EQU $C880+$0C   ; Pointer temp 2 (for nested array operations) (2 bytes)
TEMP_YX              EQU $C880+$0E   ; Temporary y,x storage (2 bytes)
TEMP_X               EQU $C880+$10   ; Temporary x storage (1 bytes)
TEMP_Y               EQU $C880+$11   ; Temporary y storage (1 bytes)
VPY_MOVE_X           EQU $C880+$12   ; MOVE() current X offset (signed byte, 0 by default) (1 bytes)
VPY_MOVE_Y           EQU $C880+$13   ; MOVE() current Y offset (signed byte, 0 by default) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$14   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity as i16x5) (10 bytes)
PSG_MUSIC_PTR        EQU $C880+$1E   ; Current music position pointer (2 bytes)
PSG_MUSIC_START      EQU $C880+$20   ; Music start pointer (for loops) (2 bytes)
PSG_IS_PLAYING       EQU $C880+$22   ; Playing flag ($00=stopped, $01=playing) (1 bytes)
PSG_MUSIC_ACTIVE     EQU $C880+$23   ; Set during UPDATE_MUSIC_PSG (1 bytes)
PSG_FRAME_COUNT      EQU $C880+$24   ; Frame register write count (1 bytes)
PSG_DELAY_FRAMES     EQU $C880+$25   ; Frames to wait before next read (1 bytes)
SFX_PTR              EQU $C880+$26   ; Current SFX data pointer (2 bytes)
SFX_TICK             EQU $C880+$28   ; Current frame counter (2 bytes)
SFX_ACTIVE           EQU $C880+$2A   ; Playback state ($00=stopped, $01=playing) (1 bytes)
SFX_PHASE            EQU $C880+$2B   ; Envelope phase (0=A,1=D,2=S,3=R) (1 bytes)
SFX_VOL              EQU $C880+$2C   ; Current volume level (0-15) (1 bytes)
NUM_STR              EQU $C880+$2D   ; String buffer for PRINT_NUMBER (5 digits + terminator) (6 bytes)
TEXT_SCALE_H         EQU $C880+$33   ; Character height for Print_Str_d (default $F8=-8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$34   ; Character width for Print_Str_d (default $48=72, normal) (1 bytes)
DRAW_VEC_X           EQU $C880+$35   ; X position offset for vector drawing (1 bytes)
DRAW_VEC_Y           EQU $C880+$36   ; Y position offset for vector drawing (1 bytes)
MIRROR_X             EQU $C880+$37   ; X-axis mirror flag (0=normal, 1=flip) (1 bytes)
MIRROR_Y             EQU $C880+$38   ; Y-axis mirror flag (0=normal, 1=flip) (1 bytes)
DRAW_VEC_INTENSITY   EQU $C880+$39   ; Intensity override (0=use vector's, >0=override) (1 bytes)
VAR_SCREEN           EQU $C880+$3A   ; User variable (2 bytes)
VAR_LOGO_TIMER       EQU $C880+$3C   ; User variable (2 bytes)
VAR_LOGO_DRAW_COUNTER EQU $C880+$3E   ; User variable (2 bytes)
VAR_FUEL_LEVEL       EQU $C880+$40   ; User variable (2 bytes)
VAR_CARRIED_PART     EQU $C880+$42   ; User variable (2 bytes)
VAR_ENEMY_X          EQU $C880+$44   ; User variable (2 bytes)
VAR_ENEMY_Y          EQU $C880+$46   ; User variable (2 bytes)
VAR_ENEMY_DX         EQU $C880+$48   ; User variable (2 bytes)
VAR_PART1_X          EQU $C880+$4A   ; User variable (2 bytes)
VAR_PART1_Y          EQU $C880+$4C   ; User variable (2 bytes)
VAR_PART1_STATE      EQU $C880+$4E   ; User variable (2 bytes)
VAR_PART2_X          EQU $C880+$50   ; User variable (2 bytes)
VAR_PART2_Y          EQU $C880+$52   ; User variable (2 bytes)
VAR_PART2_STATE      EQU $C880+$54   ; User variable (2 bytes)
VAR_PART3_X          EQU $C880+$56   ; User variable (2 bytes)
VAR_PART3_Y          EQU $C880+$58   ; User variable (2 bytes)
VAR_PART3_STATE      EQU $C880+$5A   ; User variable (2 bytes)
VAR_SHIP_BASE_X      EQU $C880+$5C   ; User variable (2 bytes)
VAR_SHIP_BASE_Y      EQU $C880+$5E   ; User variable (2 bytes)
VAR_PLAT1_Y          EQU $C880+$60   ; User variable (2 bytes)
VAR_PLAT2_Y          EQU $C880+$62   ; User variable (2 bytes)
VAR_PLAT3_Y          EQU $C880+$64   ; User variable (2 bytes)
VAR_PLAYER_X         EQU $C880+$66   ; User variable (2 bytes)
VAR_PLAYER_Y         EQU $C880+$68   ; User variable (2 bytes)
VAR_PLAYER_DIR       EQU $C880+$6A   ; User variable (2 bytes)
VAR_DIST_X           EQU $C880+$6C   ; User variable (2 bytes)
VAR_DIST_Y           EQU $C880+$6E   ; User variable (2 bytes)
VAR_JOY_X            EQU $C880+$70   ; User variable (2 bytes)
VAR_JOY_Y            EQU $C880+$72   ; User variable (2 bytes)
VAR_ARG0             EQU $C880+$74   ; Function argument 0 (2 bytes)
VAR_ARG1             EQU $C880+$76   ; Function argument 1 (2 bytes)
VAR_ARG2             EQU $C880+$78   ; Function argument 2 (2 bytes)
VAR_ARG3             EQU $C880+$7A   ; Function argument 3 (2 bytes)
VAR_ARG4             EQU $C880+$7C   ; Function argument 4 (2 bytes)
VAR_ARG5             EQU $C880+$7E   ; Function argument 5 (2 bytes)
PSG_MUSIC_PTR_DP   EQU $1E  ; DP-relative
PSG_MUSIC_START_DP EQU $20  ; DP-relative
PSG_IS_PLAYING_DP  EQU $22  ; DP-relative
PSG_MUSIC_ACTIVE_DP EQU $23  ; DP-relative
PSG_FRAME_COUNT_DP EQU $24  ; DP-relative
PSG_DELAY_FRAMES_DP EQU $25  ; DP-relative
SFX_PTR_DP         EQU $26  ; DP-relative
SFX_TICK_DP        EQU $28  ; DP-relative
SFX_ACTIVE_DP      EQU $2A  ; DP-relative
SFX_PHASE_DP       EQU $2B  ; DP-relative
SFX_VOL_DP         EQU $2C  ; DP-relative

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

VECTREX_DEBUG_PRINT:
    ; Debug print to console - writes to gap area (C000-C7FF)
    ; Write both high and low bytes for proper 16-bit signed interpretation
    LDA VAR_ARG0     ; Load high byte (for signed interpretation)
    STA $C002        ; Debug output high byte in gap
    LDA VAR_ARG0+1   ; Load low byte
    STA $C000        ; Debug output low byte in unmapped gap
    LDA #$42         ; Debug marker
    STA $C001        ; Debug marker to indicate new output
    RTS
VECTREX_SET_INTENSITY:
    ; CRITICAL: Set VIA to DAC mode BEFORE calling BIOS (don't assume state)
    LDA #$98       ; VIA_cntl = $98 (DAC mode)
    STA >$D00C     ; VIA_cntl
    LDA #$D0
    TFR A,DP       ; Set Direct Page to $D0 for BIOS
    LDA VAR_ARG0+1
    JSR __Intensity_a
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

; RAM variables (defined via ram.allocate in mod.rs):
; PSG_MUSIC_PTR, PSG_MUSIC_START, PSG_IS_PLAYING,
; PSG_MUSIC_ACTIVE, PSG_DELAY_FRAMES

; PLAY_MUSIC_RUNTIME - Start PSG music playback
; Input: X = pointer to PSG music data
PLAY_MUSIC_RUNTIME:
STX >PSG_MUSIC_PTR     ; Store current music pointer (force extended)
STX >PSG_MUSIC_START   ; Store start pointer for loops (force extended)
CLR >PSG_DELAY_FRAMES  ; Clear delay counter
LDA #$01
STA >PSG_IS_PLAYING ; Mark as playing (extended - var at 0xC8A0)
RTS

; ============================================================================
; UPDATE_MUSIC_PSG - Update PSG (call every frame)
; ============================================================================
UPDATE_MUSIC_PSG:
; CRITICAL: Set VIA to PSG mode BEFORE accessing PSG (don't assume state)
; DISABLED: Conflicts with SFX which uses Sound_Byte (HANDSHAKE mode)
; LDA #$00       ; VIA_cntl = $00 (PSG mode)
; STA >$D00C     ; VIA_cntl
LDA #$01
STA >PSG_MUSIC_ACTIVE  ; Mark music system active (for PSG logging)
LDA >PSG_IS_PLAYING ; Check if playing (extended - var at 0xC8A0)
BEQ PSG_update_done    ; Not playing, exit

LDX >PSG_MUSIC_PTR     ; Load pointer (force extended - LDX has no DP mode)
BEQ PSG_update_done    ; No music loaded

; Read frame count byte (number of register writes)
LDB ,X+
BEQ PSG_music_ended    ; Count=0 means end (no loop)
CMPB #$FF              ; Check for loop command
BEQ PSG_music_loop     ; $FF means loop (never valid as count)

; Process frame - push counter to stack
PSHS B                 ; Save count on stack

; Write register/value pairs to PSG
PSG_write_loop:
LDA ,X+                ; Load register number
LDB ,X+                ; Load register value
PSHS X                 ; Save pointer (after reads)

; WRITE_PSG sequence
STA VIA_port_a         ; Store register number
LDA #$19               ; BDIR=1, BC1=1 (LATCH)
STA VIA_port_b
LDA #$01               ; BDIR=0, BC1=0 (INACTIVE)
STA VIA_port_b
LDA VIA_port_a         ; Read status
STB VIA_port_a         ; Store data
LDB #$11               ; BDIR=1, BC1=0 (WRITE)
STB VIA_port_b
LDB #$01               ; BDIR=0, BC1=0 (INACTIVE)
STB VIA_port_b

PULS X                 ; Restore pointer
PULS B                 ; Get counter
DECB                   ; Decrement
BEQ PSG_frame_done     ; Done with this frame
PSHS B                 ; Save counter back
BRA PSG_write_loop

PSG_frame_done:

; Frame complete - update pointer and done
STX >PSG_MUSIC_PTR     ; Update pointer (force extended)
BRA PSG_update_done

PSG_music_ended:
CLR >PSG_IS_PLAYING ; Stop playback (extended - var at 0xC8A0)
; NOTE: Do NOT write PSG registers here - corrupts VIA for vector drawing
; Music will fade naturally as frame data stops updating
BRA PSG_update_done

PSG_music_loop:
; Loop command: $FF followed by 2-byte address (FDB)
; X points past $FF, read the target address
LDD ,X                 ; Load 2-byte loop target address
STD >PSG_MUSIC_PTR     ; Update pointer to loop start
; Exit - next frame will start from loop target
BRA PSG_update_done

PSG_update_done:
CLR >PSG_MUSIC_ACTIVE  ; Clear flag (music system done)
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
; Processes both music (channel B) and SFX (channel C) in one pass
; Uses Sound_Byte (BIOS) for PSG writes - compatible with both systems
; Sets DP=$D0 once at entry, restores at exit
; RAM variables: SFX_PTR, SFX_ACTIVE (defined via ram.allocate in mod.rs)

AUDIO_UPDATE:
PSHS DP                 ; Save current DP
LDA #$D0                ; Set DP=$D0 (Sound_Byte requirement)
TFR A,DP

; UPDATE MUSIC (channel B: registers 9, 11-14)
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
BEQ AU_SKIP_MUSIC       ; Skip if null
BRA AU_MUSIC_READ_COUNT ; Skip delay read, go straight to count

AU_MUSIC_READ:
LDX >PSG_MUSIC_PTR      ; Load music pointer
BEQ AU_SKIP_MUSIC       ; Skip if null

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
STB >PSG_DELAY_FRAMES   ; Save delay counter
STX >PSG_MUSIC_PTR      ; Save pointer (X points to count byte)
BRA AU_UPDATE_SFX       ; Skip reading data this frame

AU_MUSIC_PROCESS_WRITES:
PSHS B                  ; Save count

; Mark that next time we should read delay, not count
; (This is implicit - after processing, X points to next delay byte)

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

JSR sfx_doframe         ; Process one SFX frame (uses Sound_Byte internally)

AU_DONE:
PULS DP                 ; Restore original DP
RTS

; sfx_doframe stub (SFX not used in this project)
sfx_doframe:
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
; Draw_Sync_List - EXACT port of Malban's draw_synced_list_c
; Data: FCB intensity, y_start, x_start, next_y, next_x, [flag, dy, dx]*, 2
; ============================================================================
Draw_Sync_List:
; ITERACIÓN 11: Loop completo dentro (bug assembler arreglado, datos embebidos OK)
LDA ,X+                 ; intensity
JSR $F2AB               ; BIOS Intensity_a (expects value in A)
LDB ,X+                 ; y_start
LDA ,X+                 ; x_start
STD TEMP_YX             ; Guardar en variable temporal (evita stack)
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
LDD TEMP_YX             ; Recuperar y,x
STB VIA_port_a          ; Y to DAC (PB=1: integrators hold)
CLR VIA_port_b          ; PB=0: enable mux, beam tracks Y
PSHS A                  ; ~4 cycle settling delay for Y
LDA #$CE
STA VIA_cntl            ; PCR=$CE: /ZERO high, integrators active
CLR VIA_shift_reg       ; SR=0: no draw during moveto
INC VIA_port_b          ; PB=1: disable mux, lock direction at Y
PULS A                  ; Restore x
STA VIA_port_a          ; x to DAC
; Timing setup
LDA #$7F
STA VIA_t1_cnt_lo
CLR VIA_t1_cnt_hi
LEAX 2,X                ; Skip next_y, next_x
; Wait for move to complete (PB=1 on exit)
DSL_W1:
LDA VIA_int_flags
ANDA #$40
BEQ DSL_W1
; PB stays 1 — draw loop begins with PB=1
; Loop de dibujo
DSL_LOOP:
LDA ,X+                 ; Read flag
CMPA #2                 ; Check end marker
LBEQ DSL_DONE           ; Exit if end (long branch)
CMPA #1                 ; Check next path marker
LBEQ DSL_NEXT_PATH      ; Process next path (long branch)
; Draw line
CLR Vec_Misc_Count      ; Clear for relative line drawing (CRITICAL for continuity)
LDB ,X+                 ; dy
LDA ,X+                 ; dx
; B=DY, A=DX, PB=1 on entry (from moveto or previous segment)
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
DSL_W2:
LDA VIA_int_flags
ANDA #$40
BEQ DSL_W2
CLR VIA_shift_reg       ; beam off (PB stays 1 for next segment)
LBRA DSL_LOOP            ; Long branch back to loop start
; Next path: read new intensity and header, then continue drawing
DSL_NEXT_PATH:
; Save current X position before reading anything
TFR X,D                 ; D = X (current position)
PSHS D                  ; Save X address
LDA ,X+                 ; Read intensity (X now points to y_start)
PSHS A                  ; Save intensity
LDB ,X+                 ; y_start
LDA ,X+                 ; x_start (X now points to next_y)
STD TEMP_YX             ; Save y,x
PULS A                  ; Get intensity back
PSHS A                  ; Save intensity again
LDA #$D0
TFR A,DP                ; Set DP=$D0 (BIOS requirement)
PULS A                  ; Restore intensity
JSR $F2AB               ; BIOS Intensity_a (may corrupt X!)
; Restore X to point to next_y,next_x (after the 3 bytes we read)
PULS D                  ; Get original X
ADDD #3                 ; Skip intensity, y_start, x_start
TFR D,X                 ; X now points to next_y
; Reset to zero (same as Draw_Sync_List start)
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
STA VIA_port_a          ; x to DAC
LDA #$7F
STA VIA_t1_cnt_lo
CLR VIA_t1_cnt_hi
LEAX 2,X                ; Skip next_y, next_x
; Wait for move (PB=1 on exit)
DSL_W3:
LDA VIA_int_flags
ANDA #$40
BEQ DSL_W3
; PB stays 1 — draw loop continues with PB=1
LBRA DSL_LOOP            ; Continue drawing - LONG BRANCH
DSL_DONE:
RTS

; ============================================================================
; Draw_Sync_List_At - Draw vector at offset position (DRAW_VEC_X, DRAW_VEC_Y)
; Same as Draw_Sync_List but adds offset to y_start, x_start coordinates
; Uses: DRAW_VEC_X, DRAW_VEC_Y (set by DRAW_VECTOR before calling this)
; ============================================================================
Draw_Sync_List_At:
LDA ,X+                 ; intensity
PSHS A                  ; Save intensity
LDA #$D0
PULS A                  ; Restore intensity
JSR $F2AB               ; BIOS Intensity_a
LDB ,X+                 ; y_start from .vec
ADDB DRAW_VEC_Y         ; Add Y offset
LDA ,X+                 ; x_start from .vec
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
LDD TEMP_YX             ; Recuperar y,x ajustado
STB VIA_port_a          ; Y to DAC (PB=1: integrators hold)
CLR VIA_port_b          ; PB=0: enable mux, beam tracks Y
PSHS A                  ; ~4 cycle settling delay for Y
LDA #$CE
STA VIA_cntl            ; PCR=$CE: /ZERO high, integrators active
CLR VIA_shift_reg       ; SR=0: no draw during moveto
INC VIA_port_b          ; PB=1: disable mux, lock direction at Y
PULS A                  ; Restore x
STA VIA_port_a          ; x to DAC
; Timing setup
LDA #$7F
STA VIA_t1_cnt_lo
CLR VIA_t1_cnt_hi
LEAX 2,X                ; Skip next_y, next_x
; Wait for move to complete (PB=1 on exit)
DSLA_W1:
LDA VIA_int_flags
ANDA #$40
BEQ DSLA_W1
; PB stays 1 — draw loop begins with PB=1
; Loop de dibujo (same as Draw_Sync_List)
DSLA_LOOP:
LDA ,X+                 ; Read flag
CMPA #2                 ; Check end marker
LBEQ DSLA_DONE
CMPA #1                 ; Check next path marker
LBEQ DSLA_NEXT_PATH
; Draw line
CLR Vec_Misc_Count      ; Clear for relative line drawing (CRITICAL for continuity)
LDB ,X+                 ; dy
LDA ,X+                 ; dx
; B=DY, A=DX, PB=1 on entry (from moveto or previous segment)
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
DSLA_W2:
LDA VIA_int_flags
ANDA #$40
BEQ DSLA_W2
CLR VIA_shift_reg       ; beam off (PB stays 1 for next segment)
LBRA DSLA_LOOP           ; Long branch
; Next path: add offset to new coordinates too
DSLA_NEXT_PATH:
TFR X,D
PSHS D
LDA ,X+                 ; Read intensity
PSHS A
LDB ,X+                 ; y_start
ADDB DRAW_VEC_Y         ; Add Y offset to new path
LDA ,X+                 ; x_start
ADDA DRAW_VEC_X         ; Add X offset to new path
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
; Moveto new start position (Moveto_d order, offset-adjusted)
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
DSLA_W3:
LDA VIA_int_flags
ANDA #$40
BEQ DSLA_W3
; PB stays 1 — draw loop continues with PB=1
LBRA DSLA_LOOP           ; Long branch
DSLA_DONE:
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
PULS A                  ; Restore x
STA VIA_port_a          ; x to DAC
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
START:
    LDA #$D0
    TFR A,DP        ; Set Direct Page for BIOS (CRITICAL - do once at startup)
    CLR $C80E        ; Initialize Vec_Prev_Btns to 0 for Read_Btns debounce
    LDA #$80
    STA VIA_t1_cnt_lo
    LDX #Vec_Default_Stk
    TFR X,S
    JSR $F533       ; Init_Music_Buf - Initialize BIOS music system to silence

    ; *** DEBUG *** main() function code inline (initialization)
    ; VPy_LINE:117
    ; VPy_LINE:80
    LDD #0
    STD VAR_SCREEN
    ; VPy_LINE:81
    LDD #0
    STD VAR_LOGO_TIMER
    ; VPy_LINE:82
    LDD #0
    STD VAR_LOGO_DRAW_COUNTER
    ; VPy_LINE:83
    LDD #0
    STD VAR_FUEL_LEVEL
    ; VPy_LINE:84
    LDD #0
    STD VAR_CARRIED_PART
    ; VPy_LINE:87
    LDD #100
    STD VAR_ENEMY_X
    ; VPy_LINE:88
    LDD #50
    STD VAR_ENEMY_Y
    ; VPy_LINE:89
    LDD #-2
    STD VAR_ENEMY_DX
    ; VPy_LINE:92
    LDD #-80
    STD VAR_PART1_X
    ; VPy_LINE:93
    LDD #-40
    STD VAR_PART1_Y
    ; VPy_LINE:94
    LDD #0
    STD VAR_PART1_STATE
    ; VPy_LINE:96
    LDD #0
    STD VAR_PART2_X
    ; VPy_LINE:97
    LDD #-15
    STD VAR_PART2_Y
    ; VPy_LINE:98
    LDD #0
    STD VAR_PART2_STATE
    ; VPy_LINE:100
    LDD #80
    STD VAR_PART3_X
    ; VPy_LINE:101
    LDD #15
    STD VAR_PART3_Y
    ; VPy_LINE:102
    LDD #0
    STD VAR_PART3_STATE
    ; VPy_LINE:104
    LDD #0
    STD VAR_SHIP_BASE_X
    ; VPy_LINE:105
    LDD #-85
    STD VAR_SHIP_BASE_Y
    ; VPy_LINE:108
    LDD #-70
    STD VAR_PLAT1_Y
    ; VPy_LINE:109
    LDD #-20
    STD VAR_PLAT2_Y
    ; VPy_LINE:110
    LDD #30
    STD VAR_PLAT3_Y
    ; VPy_LINE:113
    LDD #0
    STD VAR_PLAYER_X
    ; VPy_LINE:114
    LDD #-80
    STD VAR_PLAYER_Y
    ; VPy_LINE:115
    LDD #0
    STD VAR_PLAYER_DIR
    ; VPy_LINE:119
; PLAY_MUSIC("jetpac_theme") - play music asset
    LDX #_JETPAC_THEME_MUSIC
    JSR PLAY_MUSIC_RUNTIME
    LDD #0
    STD RESULT
    ; VPy_LINE:120
    ; pass (no-op)

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
    LDA #$F8
    STA TEXT_SCALE_H  ; Default height = -8 (normal size)
    LDA #$48
    STA TEXT_SCALE_W  ; Default width = 72 (normal size)
    ; *** Call loop() as subroutine (executed every frame)
    JSR LOOP_BODY
    BRA MAIN

    ; VPy_LINE:122
LOOP_BODY:
    JSR Wait_Recal  ; CRITICAL: Sync with CRT refresh (50Hz frame timing)
    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access
    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)
    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access
    ; DEBUG: Statement 0 - Discriminant(9)
    ; VPy_LINE:124
    LDD VAR_SCREEN
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_2
    LDD #0
    STD RESULT
    BRA CE_3
CT_2:
    LDD #1
    STD RESULT
CE_3:
    LDD RESULT
    LBEQ IF_NEXT_1
    ; VPy_LINE:126
    JSR DRAW_LOGO_SCREEN
    ; VPy_LINE:127
    LDD VAR_LOGO_TIMER
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_LOGO_TIMER
    STU TMPPTR
    STX ,U
    ; VPy_LINE:129
    LDD VAR_LOGO_TIMER
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #300
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_6
    LDD #0
    STD RESULT
    BRA CE_7
CT_6:
    LDD #1
    STD RESULT
CE_7:
    LDD RESULT
    LBEQ IF_NEXT_5
    ; VPy_LINE:130
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_SCREEN
    STU TMPPTR
    STX ,U
    ; VPy_LINE:131
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_LOGO_TIMER
    STU TMPPTR
    STX ,U
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    ; DEBUG: Statement 1 - Discriminant(9)
    ; VPy_LINE:133
    LDD VAR_SCREEN
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_10
    LDD #0
    STD RESULT
    BRA CE_11
CT_10:
    LDD #1
    STD RESULT
CE_11:
    LDD RESULT
    LBEQ IF_NEXT_9
    ; VPy_LINE:137
; NATIVE_CALL: J1_X at line 137
    JSR J1X_BUILTIN
    STD RESULT
    LDX RESULT
    LDU #VAR_JOY_X
    STU TMPPTR
    STX ,U
    ; VPy_LINE:138
; NATIVE_CALL: J1_Y at line 138
    JSR J1Y_BUILTIN
    STD RESULT
    LDX RESULT
    LDU #VAR_JOY_Y
    STU TMPPTR
    STX ,U
    ; VPy_LINE:142
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_14
    LDD #0
    STD RESULT
    BRA CE_15
CT_14:
    LDD #1
    STD RESULT
CE_15:
    LDD RESULT
    LBEQ IF_NEXT_13
    ; VPy_LINE:143
    LDD VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_PLAYER_X
    STU TMPPTR
    STX ,U
    ; VPy_LINE:144
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_PLAYER_DIR
    STU TMPPTR
    STX ,U
    LBRA IF_END_12
IF_NEXT_13:
IF_END_12:
    ; VPy_LINE:145
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_18
    LDD #0
    STD RESULT
    BRA CE_19
CT_18:
    LDD #1
    STD RESULT
CE_19:
    LDD RESULT
    LBEQ IF_NEXT_17
    ; VPy_LINE:146
    LDD VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_PLAYER_X
    STU TMPPTR
    STX ,U
    ; VPy_LINE:147
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_PLAYER_DIR
    STU TMPPTR
    STX ,U
    LBRA IF_END_16
IF_NEXT_17:
IF_END_16:
    ; VPy_LINE:150
    LDD VAR_JOY_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_22
    LDD #0
    STD RESULT
    BRA CE_23
CT_22:
    LDD #1
    STD RESULT
CE_23:
    LDD RESULT
    LBEQ IF_NEXT_21
    ; VPy_LINE:151
    LDD VAR_PLAYER_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_PLAYER_Y
    STU TMPPTR
    STX ,U
    LBRA IF_END_20
IF_NEXT_21:
IF_END_20:
    ; VPy_LINE:152
    LDD VAR_JOY_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_26
    LDD #0
    STD RESULT
    BRA CE_27
CT_26:
    LDD #1
    STD RESULT
CE_27:
    LDD RESULT
    LBEQ IF_NEXT_25
    ; VPy_LINE:153
    LDD VAR_PLAYER_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_PLAYER_Y
    STU TMPPTR
    STX ,U
    LBRA IF_END_24
IF_NEXT_25:
IF_END_24:
    ; VPy_LINE:156
    LDD VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-110
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_30
    LDD #0
    STD RESULT
    BRA CE_31
CT_30:
    LDD #1
    STD RESULT
CE_31:
    LDD RESULT
    LBEQ IF_NEXT_29
    ; VPy_LINE:157
    LDD #-110
    STD RESULT
    LDX RESULT
    LDU #VAR_PLAYER_X
    STU TMPPTR
    STX ,U
    LBRA IF_END_28
IF_NEXT_29:
IF_END_28:
    ; VPy_LINE:158
    LDD VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #110
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_34
    LDD #0
    STD RESULT
    BRA CE_35
CT_34:
    LDD #1
    STD RESULT
CE_35:
    LDD RESULT
    LBEQ IF_NEXT_33
    ; VPy_LINE:159
    LDD #110
    STD RESULT
    LDX RESULT
    LDU #VAR_PLAYER_X
    STU TMPPTR
    STX ,U
    LBRA IF_END_32
IF_NEXT_33:
IF_END_32:
    ; VPy_LINE:160
    LDD VAR_PLAYER_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-90
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_38
    LDD #0
    STD RESULT
    BRA CE_39
CT_38:
    LDD #1
    STD RESULT
CE_39:
    LDD RESULT
    LBEQ IF_NEXT_37
    ; VPy_LINE:161
    LDD #-90
    STD RESULT
    LDX RESULT
    LDU #VAR_PLAYER_Y
    STU TMPPTR
    STX ,U
    LBRA IF_END_36
IF_NEXT_37:
IF_END_36:
    ; VPy_LINE:162
    LDD VAR_PLAYER_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #90
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_42
    LDD #0
    STD RESULT
    BRA CE_43
CT_42:
    LDD #1
    STD RESULT
CE_43:
    LDD RESULT
    LBEQ IF_NEXT_41
    ; VPy_LINE:163
    LDD #90
    STD RESULT
    LDX RESULT
    LDU #VAR_PLAYER_Y
    STU TMPPTR
    STX ,U
    LBRA IF_END_40
IF_NEXT_41:
IF_END_40:
    ; VPy_LINE:167
    LDD VAR_CARRIED_PART
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_46
    LDD #0
    STD RESULT
    BRA CE_47
CT_46:
    LDD #1
    STD RESULT
CE_47:
    LDD RESULT
    LBEQ IF_NEXT_45
    ; VPy_LINE:176
    LDD VAR_PART2_STATE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_50
    LDD #0
    STD RESULT
    BRA CE_51
CT_50:
    LDD #1
    STD RESULT
CE_51:
    LDD RESULT
    LBEQ IF_NEXT_49
    ; VPy_LINE:177
    LDD VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD VAR_PART2_X
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_DIST_X
    STU TMPPTR
    STX ,U
    ; VPy_LINE:178
    LDD VAR_PLAYER_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD VAR_PART2_Y
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_DIST_Y
    STU TMPPTR
    STX ,U
    ; VPy_LINE:179
    LDD VAR_DIST_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #20
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_54
    LDD #0
    STD RESULT
    BRA CE_55
CT_54:
    LDD #1
    STD RESULT
CE_55:
    LDD RESULT
    BEQ AND_FALSE_56
    LDD VAR_DIST_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-20
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_58
    LDD #0
    STD RESULT
    BRA CE_59
CT_58:
    LDD #1
    STD RESULT
CE_59:
    LDD RESULT
    BEQ AND_FALSE_56
    LDD #1
    STD RESULT
    BRA AND_END_57
AND_FALSE_56:
    LDD #0
    STD RESULT
AND_END_57:
    LDD RESULT
    BEQ AND_FALSE_60
    LDD VAR_DIST_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #20
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_62
    LDD #0
    STD RESULT
    BRA CE_63
CT_62:
    LDD #1
    STD RESULT
CE_63:
    LDD RESULT
    BEQ AND_FALSE_60
    LDD #1
    STD RESULT
    BRA AND_END_61
AND_FALSE_60:
    LDD #0
    STD RESULT
AND_END_61:
    LDD RESULT
    BEQ AND_FALSE_64
    LDD VAR_DIST_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-20
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_66
    LDD #0
    STD RESULT
    BRA CE_67
CT_66:
    LDD #1
    STD RESULT
CE_67:
    LDD RESULT
    BEQ AND_FALSE_64
    LDD #1
    STD RESULT
    BRA AND_END_65
AND_FALSE_64:
    LDD #0
    STD RESULT
AND_END_65:
    LDD RESULT
    LBEQ IF_NEXT_53
    ; VPy_LINE:180
    LDD #2
    STD RESULT
    LDX RESULT
    LDU #VAR_CARRIED_PART
    STU TMPPTR
    STX ,U
    ; VPy_LINE:181
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_PART2_STATE
    STU TMPPTR
    STX ,U
    LBRA IF_END_52
IF_NEXT_53:
IF_END_52:
    LBRA IF_END_48
IF_NEXT_49:
IF_END_48:
    ; VPy_LINE:183
    LDD VAR_PART3_STATE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_70
    LDD #0
    STD RESULT
    BRA CE_71
CT_70:
    LDD #1
    STD RESULT
CE_71:
    LDD RESULT
    BEQ AND_FALSE_72
    LDD VAR_PART2_STATE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_74
    LDD #0
    STD RESULT
    BRA CE_75
CT_74:
    LDD #1
    STD RESULT
CE_75:
    LDD RESULT
    BEQ AND_FALSE_72
    LDD #1
    STD RESULT
    BRA AND_END_73
AND_FALSE_72:
    LDD #0
    STD RESULT
AND_END_73:
    LDD RESULT
    LBEQ IF_NEXT_69
    ; VPy_LINE:184
    LDD VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD VAR_PART3_X
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_DIST_X
    STU TMPPTR
    STX ,U
    ; VPy_LINE:185
    LDD VAR_PLAYER_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD VAR_PART3_Y
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_DIST_Y
    STU TMPPTR
    STX ,U
    ; VPy_LINE:186
    LDD VAR_DIST_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #20
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_78
    LDD #0
    STD RESULT
    BRA CE_79
CT_78:
    LDD #1
    STD RESULT
CE_79:
    LDD RESULT
    BEQ AND_FALSE_80
    LDD VAR_DIST_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-20
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_82
    LDD #0
    STD RESULT
    BRA CE_83
CT_82:
    LDD #1
    STD RESULT
CE_83:
    LDD RESULT
    BEQ AND_FALSE_80
    LDD #1
    STD RESULT
    BRA AND_END_81
AND_FALSE_80:
    LDD #0
    STD RESULT
AND_END_81:
    LDD RESULT
    BEQ AND_FALSE_84
    LDD VAR_DIST_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #20
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_86
    LDD #0
    STD RESULT
    BRA CE_87
CT_86:
    LDD #1
    STD RESULT
CE_87:
    LDD RESULT
    BEQ AND_FALSE_84
    LDD #1
    STD RESULT
    BRA AND_END_85
AND_FALSE_84:
    LDD #0
    STD RESULT
AND_END_85:
    LDD RESULT
    BEQ AND_FALSE_88
    LDD VAR_DIST_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-20
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_90
    LDD #0
    STD RESULT
    BRA CE_91
CT_90:
    LDD #1
    STD RESULT
CE_91:
    LDD RESULT
    BEQ AND_FALSE_88
    LDD #1
    STD RESULT
    BRA AND_END_89
AND_FALSE_88:
    LDD #0
    STD RESULT
AND_END_89:
    LDD RESULT
    LBEQ IF_NEXT_77
    ; VPy_LINE:187
    LDD #3
    STD RESULT
    LDX RESULT
    LDU #VAR_CARRIED_PART
    STU TMPPTR
    STX ,U
    ; VPy_LINE:188
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_PART3_STATE
    STU TMPPTR
    STX ,U
    LBRA IF_END_76
IF_NEXT_77:
IF_END_76:
    LBRA IF_END_68
IF_NEXT_69:
IF_END_68:
    LBRA IF_END_44
IF_NEXT_45:
IF_END_44:
    ; VPy_LINE:192
    LDD VAR_CARRIED_PART
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_94
    LDD #0
    STD RESULT
    BRA CE_95
CT_94:
    LDD #1
    STD RESULT
CE_95:
    LDD RESULT
    LBEQ IF_NEXT_93
    ; VPy_LINE:193
    LDD VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD VAR_SHIP_BASE_X
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_DIST_X
    STU TMPPTR
    STX ,U
    ; VPy_LINE:194
    LDD VAR_PLAYER_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD VAR_SHIP_BASE_Y
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_DIST_Y
    STU TMPPTR
    STX ,U
    ; VPy_LINE:195
    LDD VAR_DIST_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #25
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_98
    LDD #0
    STD RESULT
    BRA CE_99
CT_98:
    LDD #1
    STD RESULT
CE_99:
    LDD RESULT
    BEQ AND_FALSE_100
    LDD VAR_DIST_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-25
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_102
    LDD #0
    STD RESULT
    BRA CE_103
CT_102:
    LDD #1
    STD RESULT
CE_103:
    LDD RESULT
    BEQ AND_FALSE_100
    LDD #1
    STD RESULT
    BRA AND_END_101
AND_FALSE_100:
    LDD #0
    STD RESULT
AND_END_101:
    LDD RESULT
    BEQ AND_FALSE_104
    LDD VAR_DIST_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #25
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_106
    LDD #0
    STD RESULT
    BRA CE_107
CT_106:
    LDD #1
    STD RESULT
CE_107:
    LDD RESULT
    BEQ AND_FALSE_104
    LDD #1
    STD RESULT
    BRA AND_END_105
AND_FALSE_104:
    LDD #0
    STD RESULT
AND_END_105:
    LDD RESULT
    BEQ AND_FALSE_108
    LDD VAR_DIST_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-25
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_110
    LDD #0
    STD RESULT
    BRA CE_111
CT_110:
    LDD #1
    STD RESULT
CE_111:
    LDD RESULT
    BEQ AND_FALSE_108
    LDD #1
    STD RESULT
    BRA AND_END_109
AND_FALSE_108:
    LDD #0
    STD RESULT
AND_END_109:
    LDD RESULT
    LBEQ IF_NEXT_97
    ; VPy_LINE:197
    LDD VAR_CARRIED_PART
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_114
    LDD #0
    STD RESULT
    BRA CE_115
CT_114:
    LDD #1
    STD RESULT
CE_115:
    LDD RESULT
    LBEQ IF_NEXT_113
    ; VPy_LINE:198
    LDD #2
    STD RESULT
    LDX RESULT
    LDU #VAR_PART1_STATE
    STU TMPPTR
    STX ,U
    LBRA IF_END_112
IF_NEXT_113:
IF_END_112:
    ; VPy_LINE:199
    LDD VAR_CARRIED_PART
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_118
    LDD #0
    STD RESULT
    BRA CE_119
CT_118:
    LDD #1
    STD RESULT
CE_119:
    LDD RESULT
    LBEQ IF_NEXT_117
    ; VPy_LINE:200
    LDD #2
    STD RESULT
    LDX RESULT
    LDU #VAR_PART2_STATE
    STU TMPPTR
    STX ,U
    LBRA IF_END_116
IF_NEXT_117:
IF_END_116:
    ; VPy_LINE:201
    LDD VAR_CARRIED_PART
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_122
    LDD #0
    STD RESULT
    BRA CE_123
CT_122:
    LDD #1
    STD RESULT
CE_123:
    LDD RESULT
    LBEQ IF_NEXT_121
    ; VPy_LINE:202
    LDD #2
    STD RESULT
    LDX RESULT
    LDU #VAR_PART3_STATE
    STU TMPPTR
    STX ,U
    LBRA IF_END_120
IF_NEXT_121:
IF_END_120:
    ; VPy_LINE:203
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_CARRIED_PART
    STU TMPPTR
    STX ,U
    LBRA IF_END_96
IF_NEXT_97:
IF_END_96:
    LBRA IF_END_92
IF_NEXT_93:
IF_END_92:
    ; VPy_LINE:206
    LDD VAR_PLAYER_DIR
    STD RESULT
; NATIVE_CALL: DEBUG_PRINT(player_dir) at line 206
    LDD RESULT
    STA $C002
    STB $C000
    LDA #$FE
    STA $C001
    LDX #DEBUG_LABEL_PLAYER_DIR
    STX $C004
    BRA DEBUG_SKIP_DATA_124
DEBUG_LABEL_PLAYER_DIR:
    FCC "player_dir"
    FCB $00
DEBUG_SKIP_DATA_124:
    LDD #0
    STD RESULT
    ; VPy_LINE:210
    LDD #80
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 210
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:211
; DRAW_VECTOR("platform", x, y) - 4 path(s) at position
    LDD #-80
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD VAR_PLAT1_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_PLATFORM_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_PLATFORM_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_PLATFORM_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_PLATFORM_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    ; VPy_LINE:212
; DRAW_VECTOR("platform", x, y) - 4 path(s) at position
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD VAR_PLAT2_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_PLATFORM_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_PLATFORM_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_PLATFORM_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_PLATFORM_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    ; VPy_LINE:213
; DRAW_VECTOR("platform", x, y) - 4 path(s) at position
    LDD #80
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD VAR_PLAT3_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_PLATFORM_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_PLATFORM_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_PLATFORM_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_PLATFORM_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    ; VPy_LINE:216
    LDD #127
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 216
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:219
    LDD VAR_PART2_STATE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_127
    LDD #0
    STD RESULT
    BRA CE_128
CT_127:
    LDD #1
    STD RESULT
CE_128:
    LDD RESULT
    LBEQ IF_NEXT_126
    ; VPy_LINE:220
; DRAW_VECTOR("rocket_middle", x, y) - 4 path(s) at position
    LDD VAR_PART2_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD VAR_PART2_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_ROCKET_MIDDLE_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ROCKET_MIDDLE_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ROCKET_MIDDLE_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ROCKET_MIDDLE_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_125
IF_NEXT_126:
IF_END_125:
    ; VPy_LINE:221
    LDD VAR_PART3_STATE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_131
    LDD #0
    STD RESULT
    BRA CE_132
CT_131:
    LDD #1
    STD RESULT
CE_132:
    LDD RESULT
    LBEQ IF_NEXT_130
    ; VPy_LINE:222
; DRAW_VECTOR("rocket_top", x, y) - 2 path(s) at position
    LDD VAR_PART3_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD VAR_PART3_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_ROCKET_TOP_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ROCKET_TOP_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_129
IF_NEXT_130:
IF_END_129:
    ; VPy_LINE:225
    LDD #100
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 225
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:226
; DRAW_VECTOR("rocket_base", x, y) - 4 path(s) at position
    LDD VAR_SHIP_BASE_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD VAR_SHIP_BASE_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_ROCKET_BASE_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ROCKET_BASE_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ROCKET_BASE_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ROCKET_BASE_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    ; VPy_LINE:229
    LDD VAR_PART1_STATE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_135
    LDD #0
    STD RESULT
    BRA CE_136
CT_135:
    LDD #1
    STD RESULT
CE_136:
    LDD RESULT
    LBEQ IF_NEXT_134
    ; VPy_LINE:230
    LDD #127
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 230
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:231
; DRAW_VECTOR("rocket_base", x, y) - 4 path(s) at position
    LDD VAR_SHIP_BASE_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD VAR_SHIP_BASE_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_ROCKET_BASE_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ROCKET_BASE_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ROCKET_BASE_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ROCKET_BASE_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_133
IF_NEXT_134:
IF_END_133:
    ; VPy_LINE:232
    LDD VAR_PART2_STATE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_139
    LDD #0
    STD RESULT
    BRA CE_140
CT_139:
    LDD #1
    STD RESULT
CE_140:
    LDD RESULT
    LBEQ IF_NEXT_138
    ; VPy_LINE:233
    LDD #127
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 233
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:234
; DRAW_VECTOR("rocket_middle", x, y) - 4 path(s) at position
    LDD VAR_SHIP_BASE_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD VAR_SHIP_BASE_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_ROCKET_MIDDLE_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ROCKET_MIDDLE_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ROCKET_MIDDLE_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ROCKET_MIDDLE_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_137
IF_NEXT_138:
IF_END_137:
    ; VPy_LINE:235
    LDD VAR_PART3_STATE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_143
    LDD #0
    STD RESULT
    BRA CE_144
CT_143:
    LDD #1
    STD RESULT
CE_144:
    LDD RESULT
    LBEQ IF_NEXT_142
    ; VPy_LINE:236
    LDD #127
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 236
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:237
; DRAW_VECTOR("rocket_top", x, y) - 2 path(s) at position
    LDD VAR_SHIP_BASE_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD VAR_SHIP_BASE_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_ROCKET_TOP_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ROCKET_TOP_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_141
IF_NEXT_142:
IF_END_141:
    ; VPy_LINE:240
    LDD #127
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 240
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:241
; DRAW_VECTOR("enemy_alien", x, y) - 7 path(s) at position
    LDD VAR_ENEMY_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD VAR_ENEMY_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_ENEMY_ALIEN_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ENEMY_ALIEN_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ENEMY_ALIEN_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ENEMY_ALIEN_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ENEMY_ALIEN_PATH4  ; Path 4
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ENEMY_ALIEN_PATH5  ; Path 5
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ENEMY_ALIEN_PATH6  ; Path 6
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    ; VPy_LINE:244
    LDD VAR_ENEMY_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD VAR_ENEMY_DX
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_ENEMY_X
    STU TMPPTR
    STX ,U
    ; VPy_LINE:247
    LDD VAR_ENEMY_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-100
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_147
    LDD #0
    STD RESULT
    BRA CE_148
CT_147:
    LDD #1
    STD RESULT
CE_148:
    LDD RESULT
    LBEQ IF_NEXT_146
    ; VPy_LINE:248
    LDD #2
    STD RESULT
    LDX RESULT
    LDU #VAR_ENEMY_DX
    STU TMPPTR
    STX ,U
    LBRA IF_END_145
IF_NEXT_146:
IF_END_145:
    ; VPy_LINE:249
    LDD VAR_ENEMY_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #100
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_151
    LDD #0
    STD RESULT
    BRA CE_152
CT_151:
    LDD #1
    STD RESULT
CE_152:
    LDD RESULT
    LBEQ IF_NEXT_150
    ; VPy_LINE:250
    LDD #-2
    STD RESULT
    LDX RESULT
    LDU #VAR_ENEMY_DX
    STU TMPPTR
    STX ,U
    LBRA IF_END_149
IF_NEXT_150:
IF_END_149:
    ; VPy_LINE:253
    LDD #127
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 253
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:254
; DRAW_VECTOR_EX("astronaut_armed", x, y, mirror) - 10 path(s), width=14, center_x=1
    LDD VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD VAR_PLAYER_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD VAR_PLAYER_DIR
    STD RESULT
    LDB RESULT+1  ; Mirror mode (0=normal, 1=X, 2=Y, 3=both)
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    BNE DSVEX_CHK_Y_153
    LDA #1
    STA MIRROR_X
DSVEX_CHK_Y_153:
    CMPB #2       ; Check if Y-mirror (mode 2)
    BNE DSVEX_CHK_XY_154
    LDA #1
    STA MIRROR_Y
DSVEX_CHK_XY_154:
    CMPB #3       ; Check if both-mirror (mode 3)
    BNE DSVEX_CALL_155
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
DSVEX_CALL_155:
    ; Set intensity override for drawing
    LDD #100
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
    STA DRAW_VEC_INTENSITY  ; Store intensity override (function will use this)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_ASTRONAUT_ARMED_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_ASTRONAUT_ARMED_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_ASTRONAUT_ARMED_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_ASTRONAUT_ARMED_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_ASTRONAUT_ARMED_PATH4  ; Path 4
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_ASTRONAUT_ARMED_PATH5  ; Path 5
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_ASTRONAUT_ARMED_PATH6  ; Path 6
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_ASTRONAUT_ARMED_PATH7  ; Path 7
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_ASTRONAUT_ARMED_PATH8  ; Path 8
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_ASTRONAUT_ARMED_PATH9  ; Path 9
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    ; VPy_LINE:258
    LDD VAR_CARRIED_PART
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_158
    LDD #0
    STD RESULT
    BRA CE_159
CT_158:
    LDD #1
    STD RESULT
CE_159:
    LDD RESULT
    LBEQ IF_NEXT_157
    ; VPy_LINE:259
    LDD #100
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 259
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:260
; DRAW_VECTOR("rocket_base", x, y) - 4 path(s) at position
    LDD VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD VAR_PLAYER_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #12
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_ROCKET_BASE_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ROCKET_BASE_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ROCKET_BASE_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ROCKET_BASE_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_156
IF_NEXT_157:
IF_END_156:
    ; VPy_LINE:261
    LDD VAR_CARRIED_PART
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_162
    LDD #0
    STD RESULT
    BRA CE_163
CT_162:
    LDD #1
    STD RESULT
CE_163:
    LDD RESULT
    LBEQ IF_NEXT_161
    ; VPy_LINE:262
    LDD #100
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 262
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:263
; DRAW_VECTOR("rocket_middle", x, y) - 4 path(s) at position
    LDD VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD VAR_PLAYER_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #12
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_ROCKET_MIDDLE_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ROCKET_MIDDLE_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ROCKET_MIDDLE_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ROCKET_MIDDLE_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_160
IF_NEXT_161:
IF_END_160:
    ; VPy_LINE:264
    LDD VAR_CARRIED_PART
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_166
    LDD #0
    STD RESULT
    BRA CE_167
CT_166:
    LDD #1
    STD RESULT
CE_167:
    LDD RESULT
    LBEQ IF_NEXT_165
    ; VPy_LINE:265
    LDD #100
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 265
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:266
; DRAW_VECTOR("rocket_top", x, y) - 2 path(s) at position
    LDD VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD VAR_PLAYER_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #12
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_ROCKET_TOP_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ROCKET_TOP_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_164
IF_NEXT_165:
IF_END_164:
    LBRA IF_END_8
IF_NEXT_9:
IF_END_8:
    ; META MUSIC_TIMER: catch up if game frame was slow
    LDA >$D00D              ; VIA_int_flags (extended addr, DP=$C8)
    BITA #$20               ; Bit 5 = T2 elapsed (>1 frame of user code)
    BEQ MUSIC_CATCHUP_SKIP  ; On time — skip extra tick
    JSR AUDIO_UPDATE        ; Catch-up tick: game was slow
MUSIC_CATCHUP_SKIP:
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX
    RTS

    ; VPy_LINE:271
DRAW_LOGO_SCREEN: ; function
; --- function draw_logo_screen ---
    ; VPy_LINE:273
    LDD #127
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 273
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:274
; DRAW_VECTOR("jetpac_logo", x, y) - 10 path(s) at position
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #20
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Use intensity from vector data
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_JETPAC_LOGO_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_JETPAC_LOGO_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_JETPAC_LOGO_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_JETPAC_LOGO_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_JETPAC_LOGO_PATH4  ; Path 4
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_JETPAC_LOGO_PATH5  ; Path 5
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_JETPAC_LOGO_PATH6  ; Path 6
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_JETPAC_LOGO_PATH7  ; Path 7
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_JETPAC_LOGO_PATH8  ; Path 8
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_JETPAC_LOGO_PATH9  ; Path 9
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    RTS

;***************************************************************************
; DATA SECTION
;***************************************************************************

; ========================================
; ASSET DATA SECTION
; Embedded 8 of 17 assets (unused assets excluded)
; ========================================

; Vector asset: jetpac_logo
; Generated from jetpac_logo.vec (Malban Draw_Sync_List format)
; Total paths: 10, points: 87
; X bounds: min=-94, max=96, width=190
; Center: (1, 0)

_JETPAC_LOGO_WIDTH EQU 190
_JETPAC_LOGO_CENTER_X EQU 1
_JETPAC_LOGO_CENTER_Y EQU 0

_JETPAC_LOGO_VECTORS:  ; Main entry (header + 10 path(s))
    FCB 10               ; path_count (runtime metadata)
    FDB _JETPAC_LOGO_PATH0        ; pointer to path 0
    FDB _JETPAC_LOGO_PATH1        ; pointer to path 1
    FDB _JETPAC_LOGO_PATH2        ; pointer to path 2
    FDB _JETPAC_LOGO_PATH3        ; pointer to path 3
    FDB _JETPAC_LOGO_PATH4        ; pointer to path 4
    FDB _JETPAC_LOGO_PATH5        ; pointer to path 5
    FDB _JETPAC_LOGO_PATH6        ; pointer to path 6
    FDB _JETPAC_LOGO_PATH7        ; pointer to path 7
    FDB _JETPAC_LOGO_PATH8        ; pointer to path 8
    FDB _JETPAC_LOGO_PATH9        ; pointer to path 9

_JETPAC_LOGO_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $15,$AE,0,0        ; path0: header (y=21, x=-82, relative to center)
    FCB $FF,$00,$12          ; flag=-1, dy=0, dx=18
    FCB $FF,$DE,$00          ; flag=-1, dy=-34, dx=0
    FCB $FF,$F7,$FC          ; flag=-1, dy=-9, dx=-4
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$09,$F8          ; flag=-1, dy=9, dx=-8
    FCB 2                ; End marker (path complete)

_JETPAC_LOGO_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $15,$C9,0,0        ; path1: header (y=21, x=-55, relative to center)
    FCB $FF,$D5,$00          ; flag=-1, dy=-43, dx=0
    FCB $FF,$00,$12          ; flag=-1, dy=0, dx=18
    FCB $FF,$10,$00          ; flag=-1, dy=16, dx=0
    FCB $FF,$00,$F3          ; flag=-1, dy=0, dx=-13
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$0D          ; flag=-1, dy=0, dx=13
    FCB $FF,$15,$00          ; flag=-1, dy=21, dx=0
    FCB $FF,$00,$EE          ; flag=-1, dy=0, dx=-18
    FCB 2                ; End marker (path complete)

_JETPAC_LOGO_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $15,$E3,0,0        ; path2: header (y=21, x=-29, relative to center)
    FCB $FF,$00,$0F          ; flag=-1, dy=0, dx=15
    FCB $FF,$EB,$00          ; flag=-1, dy=-21, dx=0
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$15,$00          ; flag=-1, dy=21, dx=0
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB $FF,$EB,$00          ; flag=-1, dy=-21, dx=0
    FCB $FF,$00,$01          ; flag=-1, dy=0, dx=1
    FCB $FF,$15,$00          ; flag=-1, dy=21, dx=0
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB $FF,$EB,$00          ; flag=-1, dy=-21, dx=0
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$EA,$00          ; flag=-1, dy=-22, dx=0
    FCB $FF,$00,$E9          ; flag=-1, dy=0, dx=-23
    FCB $FF,$16,$00          ; flag=-1, dy=22, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB 2                ; End marker (path complete)

_JETPAC_LOGO_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $EA,$11,0,0        ; path3: header (y=-22, x=17, relative to center)
    FCB $FF,$2B,$00          ; flag=-1, dy=43, dx=0
    FCB $FF,$00,$12          ; flag=-1, dy=0, dx=18
    FCB $FF,$F9,$04          ; flag=-1, dy=-7, dx=4
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB $FF,$FF,$FC          ; flag=-1, dy=-1, dx=-4
    FCB $FF,$00,$EE          ; flag=-1, dy=0, dx=-18
    FCB 2                ; End marker (path complete)

_JETPAC_LOGO_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $EA,$2F,0,0        ; path4: header (y=-22, x=47, relative to center)
    FCB $FF,$2B,$00          ; flag=-1, dy=43, dx=0
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$EB,$0C          ; flag=-1, dy=-21, dx=12
    FCB $FF,$EA,$00          ; flag=-1, dy=-22, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$15,$00          ; flag=-1, dy=21, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$EB,$00          ; flag=-1, dy=-21, dx=0
    FCB 2                ; End marker (path complete)

_JETPAC_LOGO_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $15,$59,0,0        ; path5: header (y=21, x=89, relative to center)
    FCB $FF,$00,$EE          ; flag=-1, dy=0, dx=-18
    FCB $FF,$D5,$00          ; flag=-1, dy=-43, dx=0
    FCB $FF,$00,$12          ; flag=-1, dy=0, dx=18
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$21,$00          ; flag=-1, dy=33, dx=0
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB 2                ; End marker (path complete)

_JETPAC_LOGO_PATH6:    ; Path 6
    FCB 100              ; path6: intensity
    FCB $DF,$AD,0,0        ; path6: header (y=-33, x=-83, relative to center)
    FCB $FF,$00,$59          ; sub-seg 1/2 of line 0: dy=0, dx=89
    FCB $FF,$00,$59          ; sub-seg 2/2 of line 0: dy=0, dx=89
    FCB 2                ; End marker (path complete)

_JETPAC_LOGO_PATH7:    ; Path 7
    FCB 80              ; path7: intensity
    FCB $1B,$A8,0,0        ; path7: header (y=27, x=-88, relative to center)
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$01,$05          ; flag=-1, dy=1, dx=5
    FCB $FF,$FF,$FB          ; flag=-1, dy=-1, dx=-5
    FCB $FF,$FB,$05          ; flag=-1, dy=-5, dx=5
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB $FF,$01,$03          ; flag=-1, dy=1, dx=3
    FCB 2                ; End marker (path complete)

_JETPAC_LOGO_PATH8:    ; Path 8
    FCB 80              ; path8: intensity
    FCB $1B,$51,0,0        ; path8: header (y=27, x=81, relative to center)
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$01,$04          ; flag=-1, dy=1, dx=4
    FCB $FF,$FF,$FC          ; flag=-1, dy=-1, dx=-4
    FCB $FF,$FB,$04          ; flag=-1, dy=-5, dx=4
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB $FF,$01,$02          ; flag=-1, dy=1, dx=2
    FCB 2                ; End marker (path complete)

_JETPAC_LOGO_PATH9:    ; Path 9
    FCB 80              ; path9: intensity
    FCB $20,$FE,0,0        ; path9: header (y=32, x=-2, relative to center)
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$05,$01          ; flag=-1, dy=5, dx=1
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$01,$FF          ; flag=-1, dy=1, dx=-1
    FCB $FF,$FF,$FB          ; flag=-1, dy=-1, dx=-5
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$05,$05          ; flag=-1, dy=5, dx=5
    FCB 2                ; End marker (path complete)

; Vector asset: rocket_middle
; Generated from rocket_middle.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 12
; X bounds: min=-9, max=12, width=21
; Center: (1, 1)

_ROCKET_MIDDLE_WIDTH EQU 21
_ROCKET_MIDDLE_CENTER_X EQU 1
_ROCKET_MIDDLE_CENTER_Y EQU 1

_ROCKET_MIDDLE_VECTORS:  ; Main entry (header + 4 path(s))
    FCB 4               ; path_count (runtime metadata)
    FDB _ROCKET_MIDDLE_PATH0        ; pointer to path 0
    FDB _ROCKET_MIDDLE_PATH1        ; pointer to path 1
    FDB _ROCKET_MIDDLE_PATH2        ; pointer to path 2
    FDB _ROCKET_MIDDLE_PATH3        ; pointer to path 3

_ROCKET_MIDDLE_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $F9,$F6,0,0        ; path0: header (y=-7, x=-10, relative to center)
    FCB $FF,$0E,$00          ; flag=-1, dy=14, dx=0
    FCB $FF,$00,$15          ; flag=-1, dy=0, dx=21
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB $FF,$00,$EB          ; flag=-1, dy=0, dx=-21
    FCB 2                ; End marker (path complete)

_ROCKET_MIDDLE_PATH1:    ; Path 1
    FCB 100              ; path1: intensity
    FCB $FF,$F9,0,0        ; path1: header (y=-1, x=-7, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB 2                ; End marker (path complete)

_ROCKET_MIDDLE_PATH2:    ; Path 2
    FCB 80              ; path2: intensity
    FCB $FE,$F9,0,0        ; path2: header (y=-2, x=-7, relative to center)
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ROCKET_MIDDLE_PATH3:    ; Path 3
    FCB 80              ; path3: intensity
    FCB $FE,$07,0,0        ; path3: header (y=-2, x=7, relative to center)
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

; Vector asset: enemy_alien
; Generated from enemy_alien.vec (Malban Draw_Sync_List format)
; Total paths: 7, points: 18
; X bounds: min=-4, max=5, width=9
; Center: (0, 0)

_ENEMY_ALIEN_WIDTH EQU 9
_ENEMY_ALIEN_CENTER_X EQU 0
_ENEMY_ALIEN_CENTER_Y EQU 0

_ENEMY_ALIEN_VECTORS:  ; Main entry (header + 7 path(s))
    FCB 7               ; path_count (runtime metadata)
    FDB _ENEMY_ALIEN_PATH0        ; pointer to path 0
    FDB _ENEMY_ALIEN_PATH1        ; pointer to path 1
    FDB _ENEMY_ALIEN_PATH2        ; pointer to path 2
    FDB _ENEMY_ALIEN_PATH3        ; pointer to path 3
    FDB _ENEMY_ALIEN_PATH4        ; pointer to path 4
    FDB _ENEMY_ALIEN_PATH5        ; pointer to path 5
    FDB _ENEMY_ALIEN_PATH6        ; pointer to path 6

_ENEMY_ALIEN_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $03,$FC,0,0        ; path0: header (y=3, x=-4, relative to center)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB 2                ; End marker (path complete)

_ENEMY_ALIEN_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $03,$FC,0,0        ; path1: header (y=3, x=-4, relative to center)
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB 2                ; End marker (path complete)

_ENEMY_ALIEN_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $08,$FC,0,0        ; path2: header (y=8, x=-4, relative to center)
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_ENEMY_ALIEN_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $08,$05,0,0        ; path3: header (y=8, x=5, relative to center)
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_ENEMY_ALIEN_PATH4:    ; Path 4
    FCB 90              ; path4: intensity
    FCB $FA,$FC,0,0        ; path4: header (y=-6, x=-4, relative to center)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ENEMY_ALIEN_PATH5:    ; Path 5
    FCB 90              ; path5: intensity
    FCB $FA,$00,0,0        ; path5: header (y=-6, x=0, relative to center)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ENEMY_ALIEN_PATH6:    ; Path 6
    FCB 90              ; path6: intensity
    FCB $FA,$05,0,0        ; path6: header (y=-6, x=5, relative to center)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

; Vector asset: platform
; Generated from platform.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 8
; X bounds: min=-19, max=21, width=40
; Center: (1, 2)

_PLATFORM_WIDTH EQU 40
_PLATFORM_CENTER_X EQU 1
_PLATFORM_CENTER_Y EQU 2

_PLATFORM_VECTORS:  ; Main entry (header + 4 path(s))
    FCB 4               ; path_count (runtime metadata)
    FDB _PLATFORM_PATH0        ; pointer to path 0
    FDB _PLATFORM_PATH1        ; pointer to path 1
    FDB _PLATFORM_PATH2        ; pointer to path 2
    FDB _PLATFORM_PATH3        ; pointer to path 3

_PLATFORM_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $03,$EC,0,0        ; path0: header (y=3, x=-20, relative to center)
    FCB $FF,$00,$28          ; flag=-1, dy=0, dx=40
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH1:    ; Path 1
    FCB 80              ; path1: intensity
    FCB $03,$F0,0,0        ; path1: header (y=3, x=-16, relative to center)
    FCB $FF,$FA,$FC          ; flag=-1, dy=-6, dx=-4
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH2:    ; Path 2
    FCB 80              ; path2: intensity
    FCB $03,$11,0,0        ; path2: header (y=3, x=17, relative to center)
    FCB $FF,$FA,$03          ; flag=-1, dy=-6, dx=3
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $FD,$EC,0,0        ; path3: header (y=-3, x=-20, relative to center)
    FCB $FF,$00,$28          ; flag=-1, dy=0, dx=40
    FCB 2                ; End marker (path complete)

; Vector asset: rocket_top
; Generated from rocket_top.vec (Malban Draw_Sync_List format)
; Total paths: 2, points: 7
; X bounds: min=-9, max=12, width=21
; Center: (1, 1)

_ROCKET_TOP_WIDTH EQU 21
_ROCKET_TOP_CENTER_X EQU 1
_ROCKET_TOP_CENTER_Y EQU 1

_ROCKET_TOP_VECTORS:  ; Main entry (header + 2 path(s))
    FCB 2               ; path_count (runtime metadata)
    FDB _ROCKET_TOP_PATH0        ; pointer to path 0
    FDB _ROCKET_TOP_PATH1        ; pointer to path 1

_ROCKET_TOP_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $F6,$F6,0,0        ; path0: header (y=-10, x=-10, relative to center)
    FCB $FF,$15,$09          ; flag=-1, dy=21, dx=9
    FCB $FF,$EB,$0C          ; flag=-1, dy=-21, dx=12
    FCB $FF,$00,$EB          ; flag=-1, dy=0, dx=-21
    FCB 2                ; End marker (path complete)

_ROCKET_TOP_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $F6,$F6,0,0        ; path1: header (y=-10, x=-10, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$15          ; flag=-1, dy=0, dx=21
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$EB          ; flag=-1, dy=0, dx=-21
    FCB 2                ; End marker (path complete)

; Vector asset: astronaut_armed
; Generated from astronaut_armed.vec (Malban Draw_Sync_List format)
; Total paths: 10, points: 29
; X bounds: min=-6, max=8, width=14
; Center: (1, 0)

_ASTRONAUT_ARMED_WIDTH EQU 14
_ASTRONAUT_ARMED_CENTER_X EQU 1
_ASTRONAUT_ARMED_CENTER_Y EQU 0

_ASTRONAUT_ARMED_VECTORS:  ; Main entry (header + 10 path(s))
    FCB 10               ; path_count (runtime metadata)
    FDB _ASTRONAUT_ARMED_PATH0        ; pointer to path 0
    FDB _ASTRONAUT_ARMED_PATH1        ; pointer to path 1
    FDB _ASTRONAUT_ARMED_PATH2        ; pointer to path 2
    FDB _ASTRONAUT_ARMED_PATH3        ; pointer to path 3
    FDB _ASTRONAUT_ARMED_PATH4        ; pointer to path 4
    FDB _ASTRONAUT_ARMED_PATH5        ; pointer to path 5
    FDB _ASTRONAUT_ARMED_PATH6        ; pointer to path 6
    FDB _ASTRONAUT_ARMED_PATH7        ; pointer to path 7
    FDB _ASTRONAUT_ARMED_PATH8        ; pointer to path 8
    FDB _ASTRONAUT_ARMED_PATH9        ; pointer to path 9

_ASTRONAUT_ARMED_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $08,$FB,0,0        ; path0: header (y=8, x=-5, relative to center)
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB 2                ; End marker (path complete)

_ASTRONAUT_ARMED_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $08,$FB,0,0        ; path1: header (y=8, x=-5, relative to center)
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$00,$F9          ; flag=-1, dy=0, dx=-7
    FCB 2                ; End marker (path complete)

_ASTRONAUT_ARMED_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $05,$FB,0,0        ; path2: header (y=5, x=-5, relative to center)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB 2                ; End marker (path complete)

_ASTRONAUT_ARMED_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $05,$02,0,0        ; path3: header (y=5, x=2, relative to center)
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ASTRONAUT_ARMED_PATH4:    ; Path 4
    FCB 100              ; path4: intensity
    FCB $03,$07,0,0        ; path4: header (y=3, x=7, relative to center)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB 2                ; End marker (path complete)

_ASTRONAUT_ARMED_PATH5:    ; Path 5
    FCB 100              ; path5: intensity
    FCB $FF,$FE,0,0        ; path5: header (y=-1, x=-2, relative to center)
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_ASTRONAUT_ARMED_PATH6:    ; Path 6
    FCB 100              ; path6: intensity
    FCB $FF,$02,0,0        ; path6: header (y=-1, x=2, relative to center)
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_ASTRONAUT_ARMED_PATH7:    ; Path 7
    FCB 110              ; path7: intensity
    FCB $FC,$FB,0,0        ; path7: header (y=-4, x=-5, relative to center)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB 2                ; End marker (path complete)

_ASTRONAUT_ARMED_PATH8:    ; Path 8
    FCB 110              ; path8: intensity
    FCB $FC,$04,0,0        ; path8: header (y=-4, x=4, relative to center)
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_ASTRONAUT_ARMED_PATH9:    ; Path 9
    FCB 110              ; path9: intensity
    FCB $FC,$FB,0,0        ; path9: header (y=-4, x=-5, relative to center)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB 2                ; End marker (path complete)

; Vector asset: rocket_base
; Generated from rocket_base.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 14
; X bounds: min=-13, max=14, width=27
; Center: (0, 1)

_ROCKET_BASE_WIDTH EQU 27
_ROCKET_BASE_CENTER_X EQU 0
_ROCKET_BASE_CENTER_Y EQU 1

_ROCKET_BASE_VECTORS:  ; Main entry (header + 4 path(s))
    FCB 4               ; path_count (runtime metadata)
    FDB _ROCKET_BASE_PATH0        ; pointer to path 0
    FDB _ROCKET_BASE_PATH1        ; pointer to path 1
    FDB _ROCKET_BASE_PATH2        ; pointer to path 2
    FDB _ROCKET_BASE_PATH3        ; pointer to path 3

_ROCKET_BASE_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FB,$F7,0,0        ; path0: header (y=-5, x=-9, relative to center)
    FCB $FF,$0C,$00          ; flag=-1, dy=12, dx=0
    FCB $FF,$00,$12          ; flag=-1, dy=0, dx=18
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB $FF,$00,$EE          ; flag=-1, dy=0, dx=-18
    FCB 2                ; End marker (path complete)

_ROCKET_BASE_PATH1:    ; Path 1
    FCB 100              ; path1: intensity
    FCB $FE,$F7,0,0        ; path1: header (y=-2, x=-9, relative to center)
    FCB $FF,$FD,$FC          ; flag=-1, dy=-3, dx=-4
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB 2                ; End marker (path complete)

_ROCKET_BASE_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $FE,$09,0,0        ; path2: header (y=-2, x=9, relative to center)
    FCB $FF,$FD,$05          ; flag=-1, dy=-3, dx=5
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB 2                ; End marker (path complete)

_ROCKET_BASE_PATH3:    ; Path 3
    FCB 90              ; path3: intensity
    FCB $FB,$FC,0,0        ; path3: header (y=-5, x=-4, relative to center)
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB 2                ; End marker (path complete)

; Generated from jetpac_theme.vmus (internal name: Jetpac Theme)
; Tempo: 140 BPM, Total events: 5 (PSG Direct format)
; Format: FCB count, FCB reg, val, ... (per frame), FCB 0 (end)

_JETPAC_THEME_MUSIC:
    ; Frame-based PSG register writes
    FCB     0              ; Delay 0 frames (maintain previous state)
    FCB     7              ; Frame 0 - 7 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0C             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $DE             ; Reg 7 value
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     6              ; Frame 10 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FE             ; Reg 7 value
    FCB     11              ; Delay 11 frames (maintain previous state)
    FCB     6              ; Frame 21 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FE             ; Reg 7 value
    FCB     21              ; Delay 21 frames (maintain previous state)
    FCB     6              ; Frame 42 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $70             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FE             ; Reg 7 value
    FCB     22              ; Delay 22 frames (maintain previous state)
    FCB     6              ; Frame 64 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $54             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FE             ; Reg 7 value
    FCB     21              ; Delay 21 frames before loop
    FCB     $FF             ; Loop command ($FF never valid as count)
    FDB     _JETPAC_THEME_MUSIC       ; Jump to start (absolute address)


