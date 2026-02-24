; --- Motorola 6809 backend (Vectrex) title='PLAY_MUSIC' origin=$0000 ---
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
    FCC "PLAY MUSIC"
    FCB $80
    FCB 0

;***************************************************************************
; CODE SECTION
;***************************************************************************

; === RAM VARIABLE DEFINITIONS (EQU) ===
; AUTO-GENERATED - All offsets calculated automatically
; Total RAM used: 31 bytes
RESULT               EQU $C880+$00   ; Main result temporary (2 bytes)
TMPPTR               EQU $C880+$02   ; Pointer temp (used by DRAW_VECTOR, arrays, structs) (2 bytes)
TMPPTR2              EQU $C880+$04   ; Pointer temp 2 (for nested array operations) (2 bytes)
TEMP_YX              EQU $C880+$06   ; Temporary y,x storage (2 bytes)
TEMP_X               EQU $C880+$08   ; Temporary x storage (1 bytes)
TEMP_Y               EQU $C880+$09   ; Temporary y storage (1 bytes)
PSG_MUSIC_PTR        EQU $C880+$0A   ; Current music position pointer (2 bytes)
PSG_MUSIC_START      EQU $C880+$0C   ; Music start pointer (for loops) (2 bytes)
PSG_IS_PLAYING       EQU $C880+$0E   ; Playing flag ($00=stopped, $01=playing) (1 bytes)
PSG_MUSIC_ACTIVE     EQU $C880+$0F   ; Set during UPDATE_MUSIC_PSG (1 bytes)
PSG_FRAME_COUNT      EQU $C880+$10   ; Frame register write count (1 bytes)
PSG_DELAY_FRAMES     EQU $C880+$11   ; Frames to wait before next read (1 bytes)
SFX_ACTIVE           EQU $C880+$12   ; SFX playback flag (always needed by AUDIO_UPDATE) (1 bytes)
NUM_STR              EQU $C880+$13   ; String buffer for PRINT_NUMBER (5 digits + terminator) (6 bytes)
VAR_MUSIC_PLAYING    EQU $C880+$19   ; User variable (2 bytes)
VAR_ARG0             EQU $C880+$1B   ; Function argument 0 (2 bytes)
VAR_ARG1             EQU $C880+$1D   ; Function argument 1 (2 bytes)
PSG_MUSIC_PTR_DP   EQU $0A  ; DP-relative
PSG_MUSIC_START_DP EQU $0C  ; DP-relative
PSG_IS_PLAYING_DP  EQU $0E  ; DP-relative
PSG_MUSIC_ACTIVE_DP EQU $0F  ; DP-relative
PSG_FRAME_COUNT_DP EQU $10  ; DP-relative
PSG_DELAY_FRAMES_DP EQU $11  ; DP-relative

    JMP START

;**** CONST DECLARATIONS (NUMBER-ONLY) ****

; === JOYSTICK BUILTIN SUBROUTINES ===
; J1_X() - Read Joystick 1 X axis (INCREMENTAL - with state preservation)
; Returns: D = raw value from $C81B after Joy_Analog call
J1X_BUILTIN:
    PSHS X       ; Save X (Joy_Analog uses it)
    JSR $F1AA    ; DP_to_D0 (required for Joy_Analog BIOS call)
    JSR $F1F5    ; Joy_Analog (updates $C81B from hardware)
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
CLR >PSG_IS_PLAYING ; Clear playing flag (extended - var at 0xC8A0)
CLR >PSG_MUSIC_PTR     ; Clear pointer high byte (force extended)
CLR >PSG_MUSIC_PTR+1   ; Clear pointer low byte (force extended)
; NOTE: Do NOT write PSG registers here - corrupts VIA for vector drawing
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
    ; VPy_LINE:10
    ; VPy_LINE:8
    LDD #0
    STD VAR_MUSIC_PLAYING
    ; VPy_LINE:11
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_MUSIC_PLAYING
    STU TMPPTR
    STX ,U
    ; VPy_LINE:12
; PLAY_MUSIC("music1") - play music asset
    LDX #_MUSIC1_MUSIC
    JSR PLAY_MUSIC_RUNTIME
    LDD #0
    STD RESULT

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
    ; *** Call loop() as subroutine (executed every frame)
    JSR LOOP_BODY
    BRA MAIN

    ; VPy_LINE:14
LOOP_BODY:
    JSR Wait_Recal  ; CRITICAL: Sync with CRT refresh (50Hz frame timing)
    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access
    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)
    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access
    ; DEBUG: Statement 0 - Discriminant(7)
    ; VPy_LINE:21
    ; pass (no-op)
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX (after all game logic)
    RTS

;***************************************************************************
; DATA SECTION
;***************************************************************************

; ========================================
; ASSET DATA SECTION
; Embedded 1 of 1 assets (unused assets excluded)
; ========================================

; Generated from music1.vmus (internal name: music1)
; Tempo: 120 BPM, Total events: 25 (PSG Direct format)
; Format: FCB count, FCB reg, val, ... (per frame), FCB 0 (end)

_MUSIC1_MUSIC:
    ; Frame-based PSG register writes
    FCB     0              ; Delay 0 frames (maintain previous state)
    FCB     9              ; Frame 0 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $B3             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $66             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0E             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $04             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $DC             ; Reg 7 value
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     8              ; Frame 10 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $B3             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $66             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FC             ; Reg 7 value
    FCB     15              ; Delay 15 frames (maintain previous state)
    FCB     8              ; Frame 25 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $8E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $66             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FC             ; Reg 7 value
    FCB     25              ; Delay 25 frames (maintain previous state)
    FCB     9              ; Frame 50 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $77             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $66             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0B             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0E             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $DC             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     8              ; Frame 58 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $77             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $66             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FC             ; Reg 7 value
    FCB     17              ; Delay 17 frames (maintain previous state)
    FCB     8              ; Frame 75 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0F             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $66             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FC             ; Reg 7 value
    FCB     25              ; Delay 25 frames (maintain previous state)
    FCB     9              ; Frame 100 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0F             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $DE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0E             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $04             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $DC             ; Reg 7 value
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     8              ; Frame 110 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0F             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $DE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FC             ; Reg 7 value
    FCB     14              ; Delay 14 frames (maintain previous state)
    FCB     8              ; Frame 124 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $77             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $DE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FC             ; Reg 7 value
    FCB     26              ; Delay 26 frames (maintain previous state)
    FCB     9              ; Frame 150 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $8E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $DE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0B             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0E             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $DC             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     8              ; Frame 158 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $8E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $DE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FC             ; Reg 7 value
    FCB     17              ; Delay 17 frames (maintain previous state)
    FCB     8              ; Frame 175 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $B3             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $DE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FC             ; Reg 7 value
    FCB     25              ; Delay 25 frames (maintain previous state)
    FCB     9              ; Frame 200 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $B3             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3F             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0E             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $04             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $DC             ; Reg 7 value
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     8              ; Frame 210 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $B3             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3F             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FC             ; Reg 7 value
    FCB     14              ; Delay 14 frames (maintain previous state)
    FCB     8              ; Frame 224 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3F             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FC             ; Reg 7 value
    FCB     25              ; Delay 25 frames (maintain previous state)
    FCB     9              ; Frame 249 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $86             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3F             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0B             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0E             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $DC             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     8              ; Frame 258 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $86             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3F             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FC             ; Reg 7 value
    FCB     17              ; Delay 17 frames (maintain previous state)
    FCB     8              ; Frame 275 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $3F             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FC             ; Reg 7 value
    FCB     25              ; Delay 25 frames (maintain previous state)
    FCB     9              ; Frame 300 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $5E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0F             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $AA             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0E             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $04             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $DC             ; Reg 7 value
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     8              ; Frame 310 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $5E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0F             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $AA             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FC             ; Reg 7 value
    FCB     40              ; Delay 40 frames (maintain previous state)
    FCB     9              ; Frame 350 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $AA             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0B             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0E             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $DC             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     8              ; Frame 358 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $AA             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FC             ; Reg 7 value
    FCB     17              ; Delay 17 frames (maintain previous state)
    FCB     8              ; Frame 375 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $86             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $AA             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FC             ; Reg 7 value
    FCB     25              ; Delay 25 frames before loop
    FCB     $FF             ; Loop command ($FF never valid as count)
    FDB     _MUSIC1_MUSIC       ; Jump to start (absolute address)


