; --- Motorola 6809 backend (Vectrex) title='CLOCKCPT' origin=$0000 ---
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
    FCC "CLOCKCPT"
    FCB $80
    FCB 0

;***************************************************************************
; CODE SECTION
;***************************************************************************

; === RAM VARIABLE DEFINITIONS (EQU) ===
; AUTO-GENERATED - All offsets calculated automatically
; Total RAM used: 161 bytes
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
DRAW_VEC_X           EQU $C880+$33   ; X position offset for vector drawing (1 bytes)
DRAW_VEC_Y           EQU $C880+$34   ; Y position offset for vector drawing (1 bytes)
MIRROR_X             EQU $C880+$35   ; X-axis mirror flag (0=normal, 1=flip) (1 bytes)
MIRROR_Y             EQU $C880+$36   ; Y-axis mirror flag (0=normal, 1=flip) (1 bytes)
DRAW_VEC_INTENSITY   EQU $C880+$37   ; Intensity override (0=use vector's, >0=override) (1 bytes)
LEVEL_PTR            EQU $C880+$38   ; Pointer to currently loaded level data (2 bytes)
LEVEL_BG_COUNT       EQU $C880+$3A   ; SHOW_LEVEL: background object count (1 bytes)
LEVEL_GP_COUNT       EQU $C880+$3B   ; SHOW_LEVEL: gameplay object count (1 bytes)
LEVEL_FG_COUNT       EQU $C880+$3C   ; SHOW_LEVEL: foreground object count (1 bytes)
LEVEL_BG_PTR         EQU $C880+$3D   ; SHOW_LEVEL: background objects pointer (RAM buffer) (2 bytes)
LEVEL_GP_PTR         EQU $C880+$3F   ; SHOW_LEVEL: gameplay objects pointer (RAM buffer) (2 bytes)
LEVEL_FG_PTR         EQU $C880+$41   ; SHOW_LEVEL: foreground objects pointer (RAM buffer) (2 bytes)
LEVEL_BG_ROM_PTR     EQU $C880+$43   ; LOAD_LEVEL: background objects pointer (ROM) (2 bytes)
LEVEL_GP_ROM_PTR     EQU $C880+$45   ; LOAD_LEVEL: gameplay objects pointer (ROM) (2 bytes)
LEVEL_FG_ROM_PTR     EQU $C880+$47   ; LOAD_LEVEL: foreground objects pointer (ROM) (2 bytes)
VAR_SCREEN           EQU $C880+$49   ; User variable (2 bytes)
VAR_BLINK_TIMER      EQU $C880+$4B   ; User variable (2 bytes)
VAR_BLINK_ON         EQU $C880+$4D   ; User variable (2 bytes)
VAR_INTRO_PAGE       EQU $C880+$4F   ; User variable (2 bytes)
VAR_CURRENT_ROOM     EQU $C880+$51   ; User variable (2 bytes)
VAR_PLAYER_X         EQU $C880+$53   ; User variable (2 bytes)
VAR_PLAYER_Y         EQU $C880+$55   ; User variable (2 bytes)
VAR_CURRENT_VERB     EQU $C880+$57   ; User variable (2 bytes)
VAR_NEAR_HS          EQU $C880+$59   ; User variable (2 bytes)
VAR_MSG_ID           EQU $C880+$5B   ; User variable (2 bytes)
VAR_MSG_TIMER        EQU $C880+$5D   ; User variable (2 bytes)
VAR_ROOM_EXIT        EQU $C880+$5F   ; User variable (2 bytes)
VAR_FLAG_DATE_KNOWN  EQU $C880+$61   ; User variable (2 bytes)
VAR_FLAG_TALLER_OPEN EQU $C880+$63   ; User variable (2 bytes)
VAR_PREV_BTN1        EQU $C880+$65   ; User variable (2 bytes)
VAR_PREV_BTN3        EQU $C880+$67   ; User variable (2 bytes)
VAR_ENT_HS_DOOR      EQU $C880+$69   ; User variable (2 bytes)
VAR_ENT_HS_H         EQU $C880+$6B   ; User variable (2 bytes)
VAR_ENT_HS_PAINTING  EQU $C880+$6D   ; User variable (2 bytes)
VAR_ENT_HS_W         EQU $C880+$6F   ; User variable (2 bytes)
VAR_ENT_HS_X         EQU $C880+$71   ; User variable (2 bytes)
VAR_ENT_HS_Y         EQU $C880+$73   ; User variable (2 bytes)
VAR_ROOM_CLOCKROOM   EQU $C880+$75   ; User variable (2 bytes)
VAR_ROOM_ENTRANCE    EQU $C880+$77   ; User variable (2 bytes)
VAR_STATE_ENDING     EQU $C880+$79   ; User variable (2 bytes)
VAR_STATE_INTRO      EQU $C880+$7B   ; User variable (2 bytes)
VAR_STATE_ROOM       EQU $C880+$7D   ; User variable (2 bytes)
VAR_STATE_TITLE      EQU $C880+$7F   ; User variable (2 bytes)
VAR_VERB_EXAMINE     EQU $C880+$81   ; User variable (2 bytes)
VAR_VERB_TAKE        EQU $C880+$83   ; User variable (2 bytes)
VAR_VERB_USE         EQU $C880+$85   ; User variable (2 bytes)
VAR_BTN              EQU $C880+$87   ; User variable (2 bytes)
VAR_BTN1             EQU $C880+$89   ; User variable (2 bytes)
VAR_BTN3             EQU $C880+$8B   ; User variable (2 bytes)
VAR_DX               EQU $C880+$8D   ; User variable (2 bytes)
VAR_DY               EQU $C880+$8F   ; User variable (2 bytes)
VAR_HS               EQU $C880+$91   ; User variable (2 bytes)
VAR_I                EQU $C880+$93   ; User variable (2 bytes)
VAR_JOY_X            EQU $C880+$95   ; User variable (2 bytes)
VAR_ROOM_ID          EQU $C880+$97   ; User variable (2 bytes)
VAR_ARG0             EQU $C880+$99   ; Function argument 0 (2 bytes)
VAR_ARG1             EQU $C880+$9B   ; Function argument 1 (2 bytes)
VAR_ARG2             EQU $C880+$9D   ; Function argument 2 (2 bytes)
VAR_ARG3             EQU $C880+$9F   ; Function argument 3 (2 bytes)
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
; VPy_LINE:8
; _CONST_DECL_0:  ; const STATE_TITLE
; VPy_LINE:9
; _CONST_DECL_1:  ; const STATE_INTRO
; VPy_LINE:10
; _CONST_DECL_2:  ; const STATE_ROOM
; VPy_LINE:11
; _CONST_DECL_3:  ; const STATE_ENDING
; VPy_LINE:14
; _CONST_DECL_4:  ; const ROOM_ENTRANCE
; VPy_LINE:15
; _CONST_DECL_5:  ; const ROOM_CLOCKROOM
; VPy_LINE:18
; _CONST_DECL_6:  ; const VERB_EXAMINE
; VPy_LINE:19
; _CONST_DECL_7:  ; const VERB_TAKE
; VPy_LINE:20
; _CONST_DECL_8:  ; const VERB_USE
; VPy_LINE:27
; _CONST_DECL_9:  ; const ENT_HS_COUNT
; VPy_LINE:28
; _CONST_DECL_10:  ; const ENT_HS_PAINTING
; VPy_LINE:29
; _CONST_DECL_11:  ; const ENT_HS_DOOR

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

VECTREX_PRINT_TEXT:
    ; Print_Str_d requires DP=$D0 and signature is (Y, X, string)
    ; VPy signature: PRINT_TEXT(x, y, string) -> args (ARG0=x, ARG1=y, ARG2=string)
    ; BIOS signature: Print_Str_d(A=Y, B=X, U=string)
    LDA #$D0
    TFR A,DP       ; Set Direct Page to $D0 for BIOS
    JSR Intensity_5F ; Ensure consistent text brightness (DP=$D0 required)
    JSR Reset0Ref  ; Reset beam to center for absolute text positioning
    LDU VAR_ARG2   ; string pointer (ARG2 = third param)
    LDA VAR_ARG1+1 ; Y (ARG1 = second param)
    LDB VAR_ARG0+1 ; X (ARG0 = first param)
    JSR Print_Str_d
    LDA #$80
    STA $D004      ; Restore VIA_t1_cnt_lo=$80 (Moveto_d_7F sets it to $7F)
    JSR $F1AF      ; DP_to_C8 (restore before return)
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

; ============================================================================
; AYFX SOUND EFFECTS PLAYER (Richard Chadd original system)
; ============================================================================
; Uses channel C (registers 4/5=tone, 6=noise, 10=volume, 7=mixer bit2/bit5)
; RAM variables: SFX_PTR (16-bit), SFX_ACTIVE (8-bit)
; AYFX format: flag byte + optional data per frame, end marker $D0 $20
; Flag bits: 0-3=volume, 4=disable tone, 5=tone data present,
;            6=noise data present, 7=disable noise
; ============================================================================
; (RAM variables defined in AUDIO_UPDATE section above)

; PLAY_SFX_RUNTIME - Start SFX playback
; Input: X = pointer to AYFX data
PLAY_SFX_RUNTIME:
STX >SFX_PTR           ; Store pointer (force extended)
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

; sfx_doframe - AYFX frame parser
; Runs with DP=$D0 (inside AUDIO_UPDATE)
sfx_doframe:
LDU SFX_PTR            ; Get current frame pointer (LDU has no direct mode)
LDB ,U                 ; Read flag byte (NO auto-increment)
CMPB #$D0              ; Check end marker (first byte)
BNE sfx_checktonefreq  ; Not end, continue
LDB 1,U                ; Check second byte at offset 1
CMPB #$20              ; End marker $D0 $20?
BEQ sfx_endofeffect    ; Yes, stop

sfx_checktonefreq:
LEAY 1,U               ; Y = pointer to tone/noise data
LDB ,U                 ; Reload flag byte
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
; Handle tone (flag bit 4 -> mixer bit 2)
BITA #$10              ; Bit 4: disable tone?
BNE sfx_m_tonedis
ANDB #$FB              ; Clear bit 2 (enable tone C)
BRA sfx_m_noise
sfx_m_tonedis:
ORB #$04               ; Set bit 2 (disable tone C)
sfx_m_noise:
; Handle noise (flag bit 7 -> mixer bit 5)
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
STY SFX_PTR            ; Update pointer (STY has no direct mode)
RTS

sfx_endofeffect:
; Stop SFX - silence channel C and restore mixer
CLR >SFX_ACTIVE        ; Mark as inactive (force extended)
LDA #$0A               ; Register 10 (volume C)
LDB #$00               ; Volume = 0
JSR Sound_Byte
; Restore mixer: disable tone+noise on channel C
LDB $C807              ; Read mixer shadow
ORB #$24               ; Set bits 2+5 (disable tone C + noise C)
STB $C807              ; Update shadow
LDA #$07               ; Register 7
JSR Sound_Byte         ; Write mixer
LDD #$0000
STD >SFX_PTR           ; Clear pointer (force extended)
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
; Load level data from ROM and copy objects to RAM
; Input: X = pointer to level data in ROM
; Output: LEVEL_PTR = pointer to level header (persistent)
;         RESULT    = pointer to level header (return value)
;         OPTIMIZATION: BG and FG are static → read from ROM directly
;                       Only GP is copied to RAM (has dynamic objects)
;           LEVEL_GP_BUFFER (max 16 objects * 20 bytes = 320 bytes)
LOAD_LEVEL_RUNTIME:
    PSHS D,X,Y,U     ; Preserve registers
    
    ; Store level pointer persistently
    STX >LEVEL_PTR
    
    ; Skip world bounds (8 bytes) + time/score (4 bytes)
    LEAX 12,X        ; X now points to object counts
    
    ; Read object counts
    LDB ,X+          ; B = bgCount
    STB >LEVEL_BG_COUNT
    LDB ,X+          ; B = gameplayCount
    STB >LEVEL_GP_COUNT
    LDB ,X+          ; B = fgCount
    STB >LEVEL_FG_COUNT
    
    ; Read layer pointers (ROM)
    LDD ,X++         ; D = bgObjectsPtr (ROM)
    STD >LEVEL_BG_ROM_PTR
    LDD ,X++         ; D = gameplayObjectsPtr (ROM)
    STD >LEVEL_GP_ROM_PTR
    LDD ,X++         ; D = fgObjectsPtr (ROM)
    STD >LEVEL_FG_ROM_PTR
    
    ; === Setup GP pointer: RAM buffer if physics, ROM if static ===
    LDB >LEVEL_GP_COUNT
    BEQ LLR_SKIP_GP  ; Skip if zero objects
    
    ; No physics → GP reads from ROM like BG/FG
    LDD >LEVEL_GP_ROM_PTR ; Just point to ROM
    STD >LEVEL_GP_PTR    ; Store ROM pointer
LLR_GP_DONE:
LLR_SKIP_GP:
    
    ; Return level pointer in RESULT
    LDX >LEVEL_PTR
    STX RESULT
    
    PULS D,X,Y,U,PC  ; Restore and return
    
; === Subroutine: Copy N Objects ===
; Input: B = count, X = source (ROM), U = destination (RAM)
; OPTIMIZATION: Skip 'type' field (+0) - read from ROM when needed
; Each ROM object is 20 bytes, but we copy only 19 bytes to RAM (skip type)
; Clobbers: A, B, X, U
LLR_COPY_OBJECTS:
LLR_COPY_LOOP:
    TSTB
    BEQ LLR_COPY_DONE
    PSHS B           ; Save counter (LDD will clobber B!)
    
    ; Skip type (offset +0) and intensity (offset +8) fields in ROM
    LEAX 1,X         ; X now points to +1 (x position)
    
    ; Copy 14 bytes optimized: x,y,scale,spawn_delay as 1-byte values
    LDA 1,X          ; ROM +2 (x low byte) → RAM +0
    STA ,U+
    LDA 3,X          ; ROM +4 (y low byte) → RAM +1
    STA ,U+
    LDA 5,X          ; ROM +6 (scale low byte) → RAM +2
    STA ,U+
    LDA 6,X          ; ROM +7 (rotation) → RAM +3
    STA ,U+
    LEAX 8,X         ; Skip to ROM +9 (past intensity at +8)
    LDA ,X+          ; ROM +9 (velocity_x) → RAM +4
    STA ,U+
    LDA ,X+          ; ROM +10 (velocity_y) → RAM +5
    STA ,U+
    LDA ,X+          ; ROM +11 (physics_flags) → RAM +6
    STA ,U+
    LDA ,X+          ; ROM +12 (collision_flags) → RAM +7
    STA ,U+
    LDA ,X+          ; ROM +13 (collision_size) → RAM +8
    STA ,U+
    LDA 1,X          ; ROM +15 (spawn_delay low byte) → RAM +9
    STA ,U+
    LEAX 2,X         ; Skip spawn_delay (2 bytes)
    LDD ,X++         ; ROM +16-17 (vector_ptr) → RAM +10-11
    STD ,U++
    LDD ,X++         ; ROM +18-19 (properties_ptr) → RAM +12-13
    STD ,U++
    
    PULS B           ; Restore counter
    DECB             ; Decrement after copy
    BRA LLR_COPY_LOOP
LLR_COPY_DONE:
    RTS

; === SHOW_LEVEL_RUNTIME ===
; Draw all level objects from loaded level
; Input: LEVEL_PTR = pointer to level data
; Level structure (from levelres.rs):
;   +0:  FDB xMin, xMax (world bounds)
;   +4:  FDB yMin, yMax
;   +8:  FDB timeLimit, targetScore
;   +12: FCB bgCount, gameplayCount, fgCount
;   +15: FDB bgObjectsPtr, gameplayObjectsPtr, fgObjectsPtr
; RAM object structure (19 bytes each, 'type' omitted - read from ROM):
;   +0:  FDB x, y (position)
;   +4:  FDB scale (8.8 fixed point)
;   +6:  FCB rotation, intensity
;   +8:  FCB velocity_x, velocity_y
;   +10: FCB physics_flags, collision_flags, collision_size
;   +13: FDB spawn_delay
;   +15: FDB vector_ptr
;   +17: FDB properties_ptr
SHOW_LEVEL_RUNTIME:
    PSHS D,X,Y,U     ; Preserve registers
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access - ONCE at start)
    
    ; Get level pointer (persistent)
    LDX >LEVEL_PTR
    CMPX #0
    BEQ SLR_DONE     ; No level loaded
    
    ; Skip world bounds (8 bytes) + time/score (4 bytes)
    LEAX 12,X        ; X now points to object counts
    
    ; Read object counts (use LDB+STB to ensure 1-byte operations)
    LDB ,X+          ; B = bgCount
    STB >LEVEL_BG_COUNT
    LDB ,X+          ; B = gameplayCount
    STB >LEVEL_GP_COUNT
    LDB ,X+          ; B = fgCount
    STB >LEVEL_FG_COUNT
    
    ; NOTE: Layer pointers already set by LOAD_LEVEL
    ; - LEVEL_BG_PTR points to ROM (set by LOAD_LEVEL)
    ; - LEVEL_GP_PTR points to RAM buffer if physics, ROM if static (set by LOAD_LEVEL)
    ; - LEVEL_FG_PTR points to ROM (set by LOAD_LEVEL)
    
    ; === Draw Background Layer (from ROM) ===
SLR_BG_COUNT:
    CLRB             ; Clear high byte to prevent corruption
    LDB >LEVEL_BG_COUNT
    CMPB #0
    BEQ SLR_GAMEPLAY
SLR_BG_PTR:
    LDA #20          ; ROM objects are 20 bytes (with 'type' field)
    LDX >LEVEL_BG_ROM_PTR ; Read from ROM directly (no RAM copy)
    JSR SLR_DRAW_OBJECTS
    
    ; === Draw Gameplay Layer (from RAM) ===
SLR_GAMEPLAY:
SLR_GP_COUNT:
    CLRB             ; Clear high byte to prevent corruption
    LDB >LEVEL_GP_COUNT
    CMPB #0
    BEQ SLR_FOREGROUND
SLR_GP_PTR:
    LDA #20          ; GP objects read from ROM (20 bytes)
    LDX >LEVEL_GP_PTR ; Read from pointer (RAM if physics, ROM if static)
    JSR SLR_DRAW_OBJECTS
    
    ; === Draw Foreground Layer (from ROM) ===
SLR_FOREGROUND:
SLR_FG_COUNT:
    CLRB             ; Clear high byte to prevent corruption
    LDB >LEVEL_FG_COUNT
    CMPB #0
    BEQ SLR_DONE
SLR_FG_PTR:
    LDA #20          ; ROM objects are 20 bytes (with 'type' field)
    LDX >LEVEL_FG_ROM_PTR ; Read from ROM directly (no RAM copy)
    JSR SLR_DRAW_OBJECTS
    
SLR_DONE:
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access - ONCE at end)
    PULS D,X,Y,U,PC  ; Restore and return
    
; === Subroutine: Draw N Objects ===
; Input: A = stride (19=RAM, 20=ROM), B = count, X = objects ptr
SLR_DRAW_OBJECTS:
    PSHS A           ; Save stride on stack
    ; NOTE: Use register-based loop (no stack juggling).
    ; Input: B = count, X = objects ptr. Clobbers B,X,Y,U.
SLR_OBJ_LOOP:
    TSTB             ; Test if count is zero
    LBEQ SLR_OBJ_DONE ; Exit if zero (LONG branch - intensity calc made loop large)
    
    PSHS B           ; CRITICAL: Save counter (B gets clobbered by LDD operations)
    
    ; X points to current object
    ; ROM: 20 bytes with 'type' at +0 (offsets: intensity +8, y +3, x +1, vector_ptr +16)
    ; RAM: 18 bytes without 'type' and 'intensity' (offsets: y +2, x +0, vector_ptr +14)
    ; NOTE: intensity ALWAYS read from ROM (even for RAM objects)
    
    ; Determine object type based on stride (peek from stack)
    LDA 1,S          ; Load stride from stack (offset +1 because B is at top)
    CMPA #20
    BEQ SLR_ROM_OFFSETS
    
    ; RAM offsets (14 bytes, no 'type' or 'intensity')
    ; Calculate ROM address for intensity: ROM_PTR + (objIndex * 20) + 8
    ; objIndex = totalCount - currentCounter
    ; FIX: use X (not D) to walk ROM addresses — avoids LDB clobbering D
    PSHS X           ; Save RAM object pointer
    LDB >LEVEL_GP_COUNT
    SUBB 2,S         ; B = objIndex = totalCount - currentCounter
    LDX >LEVEL_GP_ROM_PTR ; X = ROM base (index 0)
SLR_ROM_ADDR_LOOP:
    BEQ SLR_INTENSITY_READ  ; Exit if index=0 (X already at correct ROM obj)
    LEAX 20,X        ; X += ROM stride (20 bytes per object)
    DECB             ; Decrement index counter
    BRA SLR_ROM_ADDR_LOOP
SLR_INTENSITY_READ:
    LDA 8,X          ; intensity at ROM +8
    STA DRAW_VEC_INTENSITY
    PULS X           ; Restore RAM object pointer
    
    CLR MIRROR_X
    CLR MIRROR_Y
    LDB 1,X          ; y at +1 (1 byte)
    STB DRAW_VEC_Y
    LDB 0,X          ; x at +0 (1 byte)
    STB DRAW_VEC_X
    LDU 10,X         ; vector_ptr at +10
    BRA SLR_DRAW_VECTOR
    
SLR_ROM_OFFSETS:
    ; ROM offsets (20 bytes, with 'type' at +0)
    CLR MIRROR_X
    CLR MIRROR_Y
    LDA 8,X          ; intensity at +8
    STA DRAW_VEC_INTENSITY
    LDD 3,X          ; y at +3
    STB DRAW_VEC_Y
    LDD 1,X          ; x at +1
    STB DRAW_VEC_X
    LDU 16,X         ; vector_ptr at +16
    
SLR_DRAW_VECTOR:
    PSHS X           ; Save object pointer on stack (Y may be corrupted by Draw_Sync_List)
    TFR U,X          ; X = vector data pointer (points to header)
    
    ; Read path_count from header (byte 0)
    LDB ,X+          ; B = path_count, X now points to pointer table
    
    ; Draw all paths using pointer table (DP already set to $D0 by SHOW_LEVEL_RUNTIME)
SLR_PATH_LOOP:
    TSTB             ; Check if count is zero
    BEQ SLR_PATH_DONE ; Exit if no paths left
    DECB             ; Decrement count
    PSHS B           ; Save decremented count
    
    ; Read next path pointer from table (X points to current FDB entry)
    LDU ,X++         ; U = path pointer, X advances to next entry
    PSHS X           ; Save pointer table position
    TFR U,X          ; X = actual path data
    JSR Draw_Sync_List_At_With_Mirrors  ; Draw this path
    PULS X           ; Restore pointer table position
    PULS B           ; Restore counter for next iteration
    BRA SLR_PATH_LOOP
    
SLR_PATH_DONE:
    PULS X           ; Restore object pointer from stack
    
    ; Advance to next object using stride from stack
    LDA 1,S          ; Load stride from stack (offset +1 because B is at top)
    LEAX A,X         ; X += stride (18 or 20 bytes)
    
    PULS B           ; Restore counter
    DECB             ; Decrement count AFTER drawing
    LBRA SLR_OBJ_LOOP  ; LONG branch - intensity calc made loop large
    
SLR_OBJ_DONE:
    PULS A           ; Clean up stride from stack
    RTS

; === UPDATE_LEVEL_RUNTIME ===
; Update level state (physics, velocity, spawn delays)
; OPTIMIZATION: Only updates GP layer (BG/FG are static, read from ROM)
; CRITICAL: Works on RAM BUFFERS, not ROM!
;
UPDATE_LEVEL_RUNTIME:
    PSHS U,X,Y,D  ; Preserve all registers
    
    ; === Skip Background (static, no updates) ===
    ; BG objects are read directly from ROM - no physics processing needed
    
    ; === Update Gameplay Objects ONLY ===
    LDB LEVEL_GP_COUNT
    CMPB #0
    LBEQ ULR_EXIT  ; Long branch (no objects to update)
    LDU LEVEL_GP_PTR  ; U = GP pointer (RAM if physics, ROM if static)
    BSR ULR_UPDATE_LAYER  ; Process objects
    
    
ULR_EXIT:
    PULS D,Y,X,U  ; Restore registers
    RTS

; === ULR_UPDATE_LAYER - Process all objects in a layer ===
; Input: B = object count, U = buffer base address
; Uses: X for world bounds
ULR_UPDATE_LAYER:
    LDX >LEVEL_PTR  ; Load level pointer for world bounds
    CMPX #0
    LBEQ ULR_LAYER_EXIT  ; No level loaded (long branch)
    
ULR_LOOP:
    ; U = pointer to object data (19 bytes per object in RAM)
    ; RAM object structure (type omitted - read from ROM if needed):
    ; +0: x (2 bytes signed)
    ; +2: y (2 bytes signed)
    ; +4: scale (2 bytes - not used by physics)
    ; +6: rotation (1 byte - not used by physics)
    ; +7: intensity (1 byte - not used by physics)
    ; +8: velocity_x (1 byte signed)
    ; +9: velocity_y (1 byte signed)
    ; +10: physics_flags (1 byte)
    ; +11: collision_flags (1 byte)
    ; +12-18: other fields (collision_size, spawn_delay, vector_ptr, properties_ptr)

    ; Check physics_flags (offset +9)
    PSHS B  ; Save loop counter
    LDB 6,U      ; Read flags
    CMPB #0
    LBEQ ULR_NEXT  ; Skip if no physics enabled (long branch)

    ; Check if dynamic physics enabled (bit 0)
    BITB #$01
    LBEQ ULR_NEXT  ; Skip if not dynamic (long branch)

    ; Check if gravity enabled (bit 1)
    BITB #$02
    LBEQ ULR_NO_GRAVITY  ; Long branch

    ; Apply gravity: velocity_y -= 1
    LDB 5,U       ; Read velocity_y (offset +5 in RAM buffer)
    DECB          ; Subtract gravity
    ; Clamp to -15..+15 (max velocity)
    CMPB #$F1     ; Compare with -15
    BGE ULR_VY_OK
    LDB #$F1      ; Clamp to -15
ULR_VY_OK:
    STB 5,U       ; Store updated velocity_y

ULR_NO_GRAVITY:
    ; Apply velocity to position (16-bit to avoid 8-bit wraparound)
    ; x += velocity_x
    LDB 0,U       ; x (8-bit signed)
    SEX           ; D = sign-extended x
    TFR D,Y       ; Y = x (16-bit)
    LDB 4,U       ; velocity_x (8-bit signed)
    SEX           ; D = sign-extended velocity_x
    LEAY D,Y      ; Y = x + velocity_x (16-bit addition)
    TFR Y,D       ; D = 16-bit result
    CMPD #127     ; Clamp to i8 max
    BLE ULR_X_NOT_MAX
    LDD #127
ULR_X_NOT_MAX:
    CMPD #-128    ; Clamp to i8 min
    BGE ULR_X_NOT_MIN
    LDD #-128
ULR_X_NOT_MIN:
    STB 0,U       ; Store clamped x

    ; y += velocity_y
    LDB 1,U       ; y (8-bit signed)
    SEX           ; D = sign-extended y
    TFR D,Y       ; Y = y (16-bit)
    LDB 5,U       ; velocity_y (8-bit signed)
    SEX           ; D = sign-extended velocity_y
    LEAY D,Y      ; Y = y + velocity_y (16-bit addition)
    TFR Y,D       ; D = 16-bit result
    CMPD #127     ; Clamp to i8 max
    BLE ULR_Y_NOT_MAX
    LDD #127
ULR_Y_NOT_MAX:
    CMPD #-128    ; Clamp to i8 min
    BGE ULR_Y_NOT_MIN
    LDD #-128
ULR_Y_NOT_MIN:
    STB 1,U       ; Store clamped y

    ; === Check World Bounds (Wall Collisions) ===
    LDB 7,U      ; Load collision_flags
    BITB #$02     ; Check bounce_walls flag (bit 1)
    LBEQ ULR_NEXT  ; Skip bounce if not enabled (long branch)

    ; Load world bounds pointer from LEVEL_PTR
    LDX >LEVEL_PTR
    ; LEVEL_PTR → +0: xMin, +2: xMax, +4: yMin, +6: yMax (direct values)

    ; === Check X Bounds (Left/Right walls) ===
    ; Check xMin: if (x - collision_size) < xMin then bounce
    LDB 8,U      ; collision_size (offset +8)
    SEX           ; Sign-extend to 16-bit in D
    PSHS D        ; Save collision_size on stack
    LDB 0,U       ; Load object x (8-bit at offset +0)
    SEX           ; Sign-extend x to 16-bit
    SUBD ,S++     ; D = x - collision_size (left edge), pop stack
    CMPD 0,X      ; Compare left edge with xMin
    LBGE ULR_X_MAX_CHECK  ; Skip if left_edge >= xMin (LONG)
    ; Hit xMin wall - only bounce if moving left (velocity_x < 0)
    LDB 4,U       ; velocity_x (offset +4)
    CMPB #0
    LBGE ULR_X_MAX_CHECK  ; Skip if moving right (LONG)
    ; Bounce: set position so left edge = xMin
    LDB 8,U      ; Reload collision_size
    SEX
    ADDD 0,X      ; D = xMin + collision_size (center position)
    STB 0,U       ; x = (xMin + collision_size) low byte (8-bit store)
    LDB 4,U       ; Reload velocity_x
    NEGB          ; velocity_x = -velocity_x
    STB 4,U

    ; Check xMax: if (x + collision_size) > xMax then bounce
ULR_X_MAX_CHECK:
    LDB 8,U      ; Reload collision_size
    SEX
    PSHS D        ; Save collision_size on stack
    LDB 0,U       ; Load object x (8-bit at offset +0)
    SEX           ; Sign-extend x to 16-bit
    ADDD ,S++     ; D = x + collision_size (right edge), pop stack
    CMPD 2,X      ; Compare right edge with xMax
    LBLE ULR_Y_BOUNDS  ; Skip if right_edge <= xMax (LONG)
    ; Hit xMax wall - only bounce if moving right (velocity_x > 0)
    LDB 4,U       ; velocity_x (offset +4)
    CMPB #0
    LBLE ULR_Y_BOUNDS  ; Skip if moving left (LONG)
    ; Bounce: set position so right edge = xMax
    LDB 8,U      ; Reload collision_size
    SEX
    TFR D,Y       ; Y = collision_size
    LDD 2,X       ; D = xMax
    PSHS Y        ; Push collision_size
    SUBD ,S++     ; D = xMax - collision_size (center position), pop
    STB 0,U       ; x = (xMax - collision_size) low byte (8-bit store)
    LDB 4,U       ; Reload velocity_x
    NEGB          ; velocity_x = -velocity_x
    STB 4,U

    ; === Check Y Bounds (Top/Bottom walls) ===
ULR_Y_BOUNDS:
    ; Check yMin: if (y - collision_size) < yMin then bounce
    LDB 8,U      ; Reload collision_size
    SEX
    PSHS D        ; Save collision_size on stack
    LDB 1,U       ; Load object y (8-bit at offset +1)
    SEX           ; Sign-extend y to 16-bit
    SUBD ,S++     ; D = y - collision_size (bottom edge), pop stack
    CMPD 4,X      ; Compare bottom edge with yMin
    LBGE ULR_Y_MAX_CHECK  ; Skip if bottom_edge >= yMin (LONG)
    ; Hit yMin wall - only bounce if moving down (velocity_y < 0)
    LDB 5,U       ; velocity_y (offset +5)
    CMPB #0
    LBGE ULR_Y_MAX_CHECK  ; Skip if moving up (LONG)
    ; Bounce: set position so bottom edge = yMin
    LDB 8,U      ; Reload collision_size
    SEX
    ADDD 4,X      ; D = yMin + collision_size (center position)
    STB 1,U       ; y = (yMin + collision_size) low byte (8-bit store)
    LDB 5,U       ; Reload velocity_y
    NEGB          ; velocity_y = -velocity_y
    STB 5,U

    ; Check yMax: if (y + collision_size) > yMax then bounce
ULR_Y_MAX_CHECK:
    LDB 8,U      ; Reload collision_size
    SEX
    PSHS D        ; Save collision_size on stack
    LDB 1,U       ; Load object y (8-bit at offset +1)
    SEX           ; Sign-extend y to 16-bit
    ADDD ,S++     ; D = y + collision_size (top edge), pop stack
    CMPD 6,X      ; Compare top edge with yMax
    LBLE ULR_NEXT  ; Skip if top_edge <= yMax (LONG)
    ; Hit yMax wall - only bounce if moving up (velocity_y > 0)
    LDB 5,U       ; velocity_y (offset +5)
    CMPB #0
    LBLE ULR_NEXT  ; Skip if moving down (LONG)
    ; Bounce: set position so top edge = yMax
    LDB 8,U      ; Reload collision_size
    SEX
    TFR D,Y       ; Y = collision_size
    LDD 6,X       ; D = yMax
    PSHS Y        ; Push collision_size
    SUBD ,S++     ; D = yMax - collision_size (center position), pop
    STB 1,U       ; y = (yMax - collision_size) low byte (8-bit store)
    LDB 5,U       ; Reload velocity_y
    NEGB          ; velocity_y = -velocity_y
    STB 5,U

ULR_NEXT:
    PULS B        ; Restore loop counter
    LEAU 14,U     ; Move to next object (14 bytes)
    DECB
    LBNE ULR_LOOP  ; Continue if more objects (long branch)

ULR_LAYER_EXIT:
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
    ; Initialize SFX variables to prevent random noise on startup
    CLR >SFX_ACTIVE         ; Mark SFX as inactive (0=off)
    LDD #$0000
    STD >SFX_PTR            ; Clear SFX pointer

    ; *** DEBUG *** main() function code inline (initialization)
    ; VPy_LINE:62
    ; VPy_LINE:38
    LDD #0
    STD RESULT
    STD VAR_SCREEN
    ; VPy_LINE:39
    LDD #0
    STD VAR_BLINK_TIMER
    ; VPy_LINE:40
    LDD #0
    STD VAR_BLINK_ON
    ; VPy_LINE:41
    LDD #0
    STD VAR_INTRO_PAGE
    ; VPy_LINE:44
    LDD #0
    STD RESULT
    STD VAR_CURRENT_ROOM
    ; VPy_LINE:45
    LDD #0
    STD VAR_PLAYER_X
    ; VPy_LINE:46
    LDD #-75
    STD VAR_PLAYER_Y
    ; VPy_LINE:47
    LDD #0
    STD RESULT
    STD VAR_CURRENT_VERB
    ; VPy_LINE:48
    LDD #-1
    STD VAR_NEAR_HS
    ; VPy_LINE:49
    LDD #0
    STD VAR_MSG_ID
    ; VPy_LINE:50
    LDD #0
    STD VAR_MSG_TIMER
    ; VPy_LINE:51
    LDD #0
    STD VAR_ROOM_EXIT
    ; VPy_LINE:54
    LDD #0
    STD VAR_FLAG_DATE_KNOWN
    ; VPy_LINE:55
    LDD #0
    STD VAR_FLAG_TALLER_OPEN
    ; VPy_LINE:58
    LDD #0
    STD VAR_PREV_BTN1
    ; VPy_LINE:59
    LDD #0
    STD VAR_PREV_BTN3
    ; VPy_LINE:63
    LDD #100
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 63
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:64
; LOAD_LEVEL("entrance") - load level data
    LDX #_ENTRANCE_LEVEL
    JSR LOAD_LEVEL_RUNTIME
    LDD RESULT  ; Returns level pointer

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
    ; *** Call loop() as subroutine (executed every frame)
    JSR LOOP_BODY
    BRA MAIN

STATE_TITLE EQU 0
STATE_INTRO EQU 1
STATE_ROOM EQU 2
STATE_ENDING EQU 3
ROOM_ENTRANCE EQU 0
ROOM_CLOCKROOM EQU 1
VERB_EXAMINE EQU 0
VERB_TAKE EQU 1
VERB_USE EQU 2
ENT_HS_COUNT EQU 2
ENT_HS_PAINTING EQU 0
ENT_HS_DOOR EQU 1
    ; VPy_LINE:67
LOOP_BODY:
    JSR Wait_Recal  ; CRITICAL: Sync with CRT refresh (50Hz frame timing)
    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access
    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)
    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access
    ; DEBUG: Statement 0 - Discriminant(9)
    ; VPy_LINE:68
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
    ; VPy_LINE:69
    JSR DRAW_TITLE
    LBRA IF_END_0
IF_NEXT_1:
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
    BEQ CT_5
    LDD #0
    STD RESULT
    BRA CE_6
CT_5:
    LDD #1
    STD RESULT
CE_6:
    LDD RESULT
    LBEQ IF_NEXT_4
    ; VPy_LINE:71
    JSR DRAW_INTRO
    LBRA IF_END_0
IF_NEXT_4:
    LDD VAR_SCREEN
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_8
    LDD #0
    STD RESULT
    BRA CE_9
CT_8:
    LDD #1
    STD RESULT
CE_9:
    LDD RESULT
    LBEQ IF_NEXT_7
    ; VPy_LINE:73
    JSR UPDATE_ROOM
    ; VPy_LINE:74
    JSR DRAW_ROOM
    LBRA IF_END_0
IF_NEXT_7:
    LDD VAR_SCREEN
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #3
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
    LBEQ IF_END_0
    ; VPy_LINE:76
    JSR DRAW_ENDING
    LBRA IF_END_0
IF_END_0:
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX (after all game logic)
    RTS

    ; VPy_LINE:81
DRAW_TITLE: ; function
; --- function draw_title ---
    ; VPy_LINE:82
    LDD #120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 82
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:83
; DRAW_VECTOR("crypt_logo", x, y) - 40 path(s) at position
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #10
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
    LDX #_CRYPT_LOGO_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH4  ; Path 4
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH5  ; Path 5
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH6  ; Path 6
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH7  ; Path 7
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH8  ; Path 8
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH9  ; Path 9
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH10  ; Path 10
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH11  ; Path 11
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH12  ; Path 12
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH13  ; Path 13
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH14  ; Path 14
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH15  ; Path 15
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH16  ; Path 16
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH17  ; Path 17
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH18  ; Path 18
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH19  ; Path 19
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH20  ; Path 20
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH21  ; Path 21
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH22  ; Path 22
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH23  ; Path 23
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH24  ; Path 24
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH25  ; Path 25
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH26  ; Path 26
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH27  ; Path 27
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH28  ; Path 28
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH29  ; Path 29
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH30  ; Path 30
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH31  ; Path 31
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH32  ; Path 32
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH33  ; Path 33
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH34  ; Path 34
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH35  ; Path 35
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH36  ; Path 36
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH37  ; Path 37
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH38  ; Path 38
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_CRYPT_LOGO_PATH39  ; Path 39
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    ; VPy_LINE:85
    LDD #65
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 85
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:86
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-128
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-72
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_19
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 86
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:88
    LDD VAR_BLINK_TIMER
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
    LDU #VAR_BLINK_TIMER
    STU TMPPTR
    STX ,U
    ; VPy_LINE:89
    LDD VAR_BLINK_TIMER
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #40
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGE CT_14
    LDD #0
    STD RESULT
    BRA CE_15
CT_14:
    LDD #1
    STD RESULT
CE_15:
    LDD RESULT
    LBEQ IF_NEXT_13
    ; VPy_LINE:90
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_BLINK_TIMER
    STU TMPPTR
    STX ,U
    ; VPy_LINE:91
    LDD VAR_BLINK_ON
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
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
    ; VPy_LINE:92
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_BLINK_ON
    STU TMPPTR
    STX ,U
    LBRA IF_END_16
IF_NEXT_17:
    ; VPy_LINE:94
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_BLINK_ON
    STU TMPPTR
    STX ,U
IF_END_16:
    LBRA IF_END_12
IF_NEXT_13:
IF_END_12:
    ; VPy_LINE:96
    LDD VAR_BLINK_ON
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
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
    ; VPy_LINE:97
    LDD #100
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 97
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:98
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-123
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-100
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_15
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 98
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_20
IF_NEXT_21:
IF_END_20:
    ; VPy_LINE:100
; NATIVE_CALL: J1_BUTTON_1 at line 100
    JSR J1B1_BUILTIN
    STD RESULT
    LDX RESULT
    LDU #VAR_BTN
    STU TMPPTR
    STX ,U
    ; VPy_LINE:101
    LDD VAR_BTN
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
    BEQ AND_FALSE_28
    LDD VAR_PREV_BTN1
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_30
    LDD #0
    STD RESULT
    BRA CE_31
CT_30:
    LDD #1
    STD RESULT
CE_31:
    LDD RESULT
    BEQ AND_FALSE_28
    LDD #1
    STD RESULT
    BRA AND_END_29
AND_FALSE_28:
    LDD #0
    STD RESULT
AND_END_29:
    LDD RESULT
    LBEQ IF_NEXT_25
    ; VPy_LINE:102
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_PREV_BTN1
    STU TMPPTR
    STX ,U
    ; VPy_LINE:103
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_INTRO_PAGE
    STU TMPPTR
    STX ,U
    ; VPy_LINE:104
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_SCREEN
    STU TMPPTR
    STX ,U
    LBRA IF_END_24
IF_NEXT_25:
IF_END_24:
    ; VPy_LINE:105
    LDD VAR_BTN
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_34
    LDD #0
    STD RESULT
    BRA CE_35
CT_34:
    LDD #1
    STD RESULT
CE_35:
    LDD RESULT
    LBEQ IF_NEXT_33
    ; VPy_LINE:106
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_PREV_BTN1
    STU TMPPTR
    STX ,U
    LBRA IF_END_32
IF_NEXT_33:
IF_END_32:
    RTS

    ; VPy_LINE:111
DRAW_INTRO: ; function
; --- function draw_intro ---
    ; VPy_LINE:112
    LDD VAR_INTRO_PAGE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_38
    LDD #0
    STD RESULT
    BRA CE_39
CT_38:
    LDD #1
    STD RESULT
CE_39:
    LDD RESULT
    LBEQ IF_NEXT_37
    ; VPy_LINE:113
    LDD #100
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 113
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:114
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-50
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #50
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_17
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 114
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:115
    LDD #80
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 115
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:116
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-63
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #25
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_23
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 116
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:117
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-56
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #10
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_13
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 117
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:118
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-63
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-5
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_24
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 118
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:119
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-42
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-20
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_32
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 119
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:120
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-63
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-35
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_28
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 120
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:121
    LDD #60
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 121
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:122
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-49
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-80
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_14
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 122
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_36
IF_NEXT_37:
    LDD VAR_INTRO_PAGE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_41
    LDD #0
    STD RESULT
    BRA CE_42
CT_41:
    LDD #1
    STD RESULT
CE_42:
    LDD RESULT
    LBEQ IF_NEXT_40
    ; VPy_LINE:124
    LDD #100
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 124
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:125
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-49
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #50
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_34
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 125
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:126
    LDD #80
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 126
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:127
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-63
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #25
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_22
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 127
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:128
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-35
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #10
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_37
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 128
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:129
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-63
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-10
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_10
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 129
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:130
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-63
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-25
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_26
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 130
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:131
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-56
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-40
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_11
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 131
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:132
    LDD #60
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 132
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:133
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-49
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-80
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_14
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 133
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_36
IF_NEXT_40:
    LDD VAR_INTRO_PAGE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_43
    LDD #0
    STD RESULT
    BRA CE_44
CT_43:
    LDD #1
    STD RESULT
CE_44:
    LDD RESULT
    LBEQ IF_END_36
    ; VPy_LINE:135
    LDD #100
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 135
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:136
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-49
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #40
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_9
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 136
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:137
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-49
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #25
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_16
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 137
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:138
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-56
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #10
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_6
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 138
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:139
    LDD #70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 139
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:140
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-49
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-20
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_12
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 140
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:141
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-63
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-35
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_3
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 141
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:142
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-63
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-50
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_4
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 142
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:143
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-63
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-65
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_5
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 143
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:144
    LDD #60
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 144
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:145
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-49
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-90
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_14
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 145
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_36
IF_END_36:
    ; VPy_LINE:147
; NATIVE_CALL: J1_BUTTON_1 at line 147
    JSR J1B1_BUILTIN
    STD RESULT
    LDX RESULT
    LDU #VAR_BTN
    STU TMPPTR
    STX ,U
    ; VPy_LINE:148
    LDD VAR_BTN
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_47
    LDD #0
    STD RESULT
    BRA CE_48
CT_47:
    LDD #1
    STD RESULT
CE_48:
    LDD RESULT
    BEQ AND_FALSE_49
    LDD VAR_PREV_BTN1
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_51
    LDD #0
    STD RESULT
    BRA CE_52
CT_51:
    LDD #1
    STD RESULT
CE_52:
    LDD RESULT
    BEQ AND_FALSE_49
    LDD #1
    STD RESULT
    BRA AND_END_50
AND_FALSE_49:
    LDD #0
    STD RESULT
AND_END_50:
    LDD RESULT
    LBEQ IF_NEXT_46
    ; VPy_LINE:149
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_PREV_BTN1
    STU TMPPTR
    STX ,U
    ; VPy_LINE:150
    LDD VAR_INTRO_PAGE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_55
    LDD #0
    STD RESULT
    BRA CE_56
CT_55:
    LDD #1
    STD RESULT
CE_56:
    LDD RESULT
    LBEQ IF_NEXT_54
    ; VPy_LINE:151
    LDD VAR_INTRO_PAGE
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
    LDU #VAR_INTRO_PAGE
    STU TMPPTR
    STX ,U
    LBRA IF_END_53
IF_NEXT_54:
    ; VPy_LINE:153
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    JSR ENTER_ROOM
    ; VPy_LINE:154
    LDD #2
    STD RESULT
    LDX RESULT
    LDU #VAR_SCREEN
    STU TMPPTR
    STX ,U
IF_END_53:
    LBRA IF_END_45
IF_NEXT_46:
IF_END_45:
    ; VPy_LINE:155
    LDD VAR_BTN
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_59
    LDD #0
    STD RESULT
    BRA CE_60
CT_59:
    LDD #1
    STD RESULT
CE_60:
    LDD RESULT
    LBEQ IF_NEXT_58
    ; VPy_LINE:156
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_PREV_BTN1
    STU TMPPTR
    STX ,U
    LBRA IF_END_57
IF_NEXT_58:
IF_END_57:
    RTS

    ; VPy_LINE:161
ENTER_ROOM: ; function
; --- function enter_room ---
    LEAS -2,S ; allocate locals
    LDD VAR_ARG0
    STD 0,S ; param 0
    ; VPy_LINE:162
    LDD 0 ,S
    STD RESULT
    LDX RESULT
    LDU #VAR_CURRENT_ROOM
    STU TMPPTR
    STX ,U
    ; VPy_LINE:163
    LDD #-1
    STD RESULT
    LDX RESULT
    LDU #VAR_NEAR_HS
    STU TMPPTR
    STX ,U
    ; VPy_LINE:164
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_MSG_ID
    STU TMPPTR
    STX ,U
    ; VPy_LINE:165
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_MSG_TIMER
    STU TMPPTR
    STX ,U
    ; VPy_LINE:166
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_ROOM_EXIT
    STU TMPPTR
    STX ,U
    ; VPy_LINE:167
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_63
    LDD #0
    STD RESULT
    BRA CE_64
CT_63:
    LDD #1
    STD RESULT
CE_64:
    LDD RESULT
    LBEQ IF_NEXT_62
    ; VPy_LINE:168
; LOAD_LEVEL("entrance") - load level data
    LDX #_ENTRANCE_LEVEL
    JSR LOAD_LEVEL_RUNTIME
    LDD RESULT  ; Returns level pointer
    ; VPy_LINE:169
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_PLAYER_X
    STU TMPPTR
    STX ,U
    ; VPy_LINE:170
    LDD #-75
    STD RESULT
    LDX RESULT
    LDU #VAR_PLAYER_Y
    STU TMPPTR
    STX ,U
    ; VPy_LINE:171
; PLAY_MUSIC("exploration") - play music asset
    LDX #_EXPLORATION_MUSIC
    JSR PLAY_MUSIC_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_61
IF_NEXT_62:
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_65
    LDD #0
    STD RESULT
    BRA CE_66
CT_65:
    LDD #1
    STD RESULT
CE_66:
    LDD RESULT
    LBEQ IF_END_61
    ; VPy_LINE:173
    LDD #70
    STD RESULT
    LDX RESULT
    LDU #VAR_PLAYER_X
    STU TMPPTR
    STX ,U
    ; VPy_LINE:174
    LDD #-75
    STD RESULT
    LDX RESULT
    LDU #VAR_PLAYER_Y
    STU TMPPTR
    STX ,U
    ; VPy_LINE:175
; PLAY_MUSIC("exploration") - play music asset
    LDX #_EXPLORATION_MUSIC
    JSR PLAY_MUSIC_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_61
IF_END_61:
    LEAS 2,S ; free locals
    RTS

    ; VPy_LINE:180
UPDATE_ROOM: ; function
; --- function update_room ---
    ; VPy_LINE:182
; NATIVE_CALL: J1_X at line 182
    JSR J1X_BUILTIN
    STD RESULT
    LDX RESULT
    LDU #VAR_JOY_X
    STU TMPPTR
    STX ,U
    ; VPy_LINE:183
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #30
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_69
    LDD #0
    STD RESULT
    BRA CE_70
CT_69:
    LDD #1
    STD RESULT
CE_70:
    LDD RESULT
    LBEQ IF_NEXT_68
    ; VPy_LINE:184
    LDD VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #2
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
    LBRA IF_END_67
IF_NEXT_68:
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-30
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_71
    LDD #0
    STD RESULT
    BRA CE_72
CT_71:
    LDD #1
    STD RESULT
CE_72:
    LDD RESULT
    LBEQ IF_END_67
    ; VPy_LINE:186
    LDD VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #2
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
    LBRA IF_END_67
IF_END_67:
    ; VPy_LINE:187
    LDD VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-82
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD #82
    STD RESULT
    LDD RESULT
    STD TMPLEFT2
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CLAMP_USE_LO_73
    BRA CLAMP_CHECK_HI_74
CLAMP_USE_LO_73:
    LDD TMPRIGHT
    BRA CLAMP_DONE_76
CLAMP_CHECK_HI_74:
    LDD TMPLEFT
    SUBD TMPLEFT2
    BGT CLAMP_USE_HI_75
    LDD TMPLEFT
    BRA CLAMP_DONE_76
CLAMP_USE_HI_75:
    LDD TMPLEFT2
CLAMP_DONE_76:
    STD RESULT
    LDX RESULT
    LDU #VAR_PLAYER_X
    STU TMPPTR
    STX ,U
    ; VPy_LINE:190
    LDD #-1
    STD RESULT
    LDX RESULT
    LDU #VAR_NEAR_HS
    STU TMPPTR
    STX ,U
    ; VPy_LINE:191
    LDD VAR_CURRENT_ROOM
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_79
    LDD #0
    STD RESULT
    BRA CE_80
CT_79:
    LDD #1
    STD RESULT
CE_80:
    LDD RESULT
    LBEQ IF_NEXT_78
    ; VPy_LINE:192
    JSR CHECK_ENTRANCE_HOTSPOTS
    LBRA IF_END_77
IF_NEXT_78:
IF_END_77:
    ; VPy_LINE:195
    LDD VAR_MSG_TIMER
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_83
    LDD #0
    STD RESULT
    BRA CE_84
CT_83:
    LDD #1
    STD RESULT
CE_84:
    LDD RESULT
    LBEQ IF_NEXT_82
    ; VPy_LINE:196
    LDD VAR_MSG_TIMER
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
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_MSG_TIMER
    STU TMPPTR
    STX ,U
    ; VPy_LINE:197
    LDD VAR_MSG_TIMER
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_87
    LDD #0
    STD RESULT
    BRA CE_88
CT_87:
    LDD #1
    STD RESULT
CE_88:
    LDD RESULT
    BEQ AND_FALSE_89
    LDD VAR_ROOM_EXIT
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_91
    LDD #0
    STD RESULT
    BRA CE_92
CT_91:
    LDD #1
    STD RESULT
CE_92:
    LDD RESULT
    BEQ AND_FALSE_89
    LDD #1
    STD RESULT
    BRA AND_END_90
AND_FALSE_89:
    LDD #0
    STD RESULT
AND_END_90:
    LDD RESULT
    LBEQ IF_NEXT_86
    ; VPy_LINE:198
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_ROOM_EXIT
    STU TMPPTR
    STX ,U
    ; VPy_LINE:199
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    JSR ENTER_ROOM
    LBRA IF_END_85
IF_NEXT_86:
IF_END_85:
    LBRA IF_END_81
IF_NEXT_82:
IF_END_81:
    ; VPy_LINE:202
; NATIVE_CALL: J1_BUTTON_3 at line 202
    JSR J1B3_BUILTIN
    STD RESULT
    LDX RESULT
    LDU #VAR_BTN3
    STU TMPPTR
    STX ,U
    ; VPy_LINE:203
    LDD VAR_BTN3
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_95
    LDD #0
    STD RESULT
    BRA CE_96
CT_95:
    LDD #1
    STD RESULT
CE_96:
    LDD RESULT
    BEQ AND_FALSE_97
    LDD VAR_PREV_BTN3
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_99
    LDD #0
    STD RESULT
    BRA CE_100
CT_99:
    LDD #1
    STD RESULT
CE_100:
    LDD RESULT
    BEQ AND_FALSE_97
    LDD #1
    STD RESULT
    BRA AND_END_98
AND_FALSE_97:
    LDD #0
    STD RESULT
AND_END_98:
    LDD RESULT
    LBEQ IF_NEXT_94
    ; VPy_LINE:204
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_PREV_BTN3
    STU TMPPTR
    STX ,U
    ; VPy_LINE:205
    LDD VAR_MSG_TIMER
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_103
    LDD #0
    STD RESULT
    BRA CE_104
CT_103:
    LDD #1
    STD RESULT
CE_104:
    LDD RESULT
    LBEQ IF_NEXT_102
    ; VPy_LINE:206
    LDD VAR_CURRENT_VERB
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_107
    LDD #0
    STD RESULT
    BRA CE_108
CT_107:
    LDD #1
    STD RESULT
CE_108:
    LDD RESULT
    LBEQ IF_NEXT_106
    ; VPy_LINE:207
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_CURRENT_VERB
    STU TMPPTR
    STX ,U
    LBRA IF_END_105
IF_NEXT_106:
    ; VPy_LINE:209
    LDD VAR_CURRENT_VERB
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
    LDU #VAR_CURRENT_VERB
    STU TMPPTR
    STX ,U
IF_END_105:
    LBRA IF_END_101
IF_NEXT_102:
IF_END_101:
    LBRA IF_END_93
IF_NEXT_94:
IF_END_93:
    ; VPy_LINE:210
    LDD VAR_BTN3
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_111
    LDD #0
    STD RESULT
    BRA CE_112
CT_111:
    LDD #1
    STD RESULT
CE_112:
    LDD RESULT
    LBEQ IF_NEXT_110
    ; VPy_LINE:211
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_PREV_BTN3
    STU TMPPTR
    STX ,U
    LBRA IF_END_109
IF_NEXT_110:
IF_END_109:
    ; VPy_LINE:214
; NATIVE_CALL: J1_BUTTON_1 at line 214
    JSR J1B1_BUILTIN
    STD RESULT
    LDX RESULT
    LDU #VAR_BTN1
    STU TMPPTR
    STX ,U
    ; VPy_LINE:215
    LDD VAR_BTN1
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_115
    LDD #0
    STD RESULT
    BRA CE_116
CT_115:
    LDD #1
    STD RESULT
CE_116:
    LDD RESULT
    BEQ AND_FALSE_117
    LDD VAR_PREV_BTN1
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_119
    LDD #0
    STD RESULT
    BRA CE_120
CT_119:
    LDD #1
    STD RESULT
CE_120:
    LDD RESULT
    BEQ AND_FALSE_117
    LDD #1
    STD RESULT
    BRA AND_END_118
AND_FALSE_117:
    LDD #0
    STD RESULT
AND_END_118:
    LDD RESULT
    LBEQ IF_NEXT_114
    ; VPy_LINE:216
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_PREV_BTN1
    STU TMPPTR
    STX ,U
    ; VPy_LINE:217
    LDD VAR_MSG_TIMER
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_123
    LDD #0
    STD RESULT
    BRA CE_124
CT_123:
    LDD #1
    STD RESULT
CE_124:
    LDD RESULT
    LBEQ IF_NEXT_122
    ; VPy_LINE:218
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_MSG_TIMER
    STU TMPPTR
    STX ,U
    LBRA IF_END_121
IF_NEXT_122:
    LDD VAR_NEAR_HS
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGE CT_125
    LDD #0
    STD RESULT
    BRA CE_126
CT_125:
    LDD #1
    STD RESULT
CE_126:
    LDD RESULT
    LBEQ IF_END_121
    ; VPy_LINE:220
    LDD VAR_CURRENT_ROOM
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_129
    LDD #0
    STD RESULT
    BRA CE_130
CT_129:
    LDD #1
    STD RESULT
CE_130:
    LDD RESULT
    LBEQ IF_NEXT_128
    ; VPy_LINE:221
    LDD VAR_NEAR_HS
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    JSR INTERACT_ENTRANCE
    LBRA IF_END_127
IF_NEXT_128:
IF_END_127:
    LBRA IF_END_121
IF_END_121:
    LBRA IF_END_113
IF_NEXT_114:
IF_END_113:
    ; VPy_LINE:222
    LDD VAR_BTN1
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_133
    LDD #0
    STD RESULT
    BRA CE_134
CT_133:
    LDD #1
    STD RESULT
CE_134:
    LDD RESULT
    LBEQ IF_NEXT_132
    ; VPy_LINE:223
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_PREV_BTN1
    STU TMPPTR
    STX ,U
    LBRA IF_END_131
IF_NEXT_132:
IF_END_131:
    RTS

    ; VPy_LINE:226
CHECK_ENTRANCE_HOTSPOTS: ; function
; --- function check_entrance_hotspots ---
    ; VPy_LINE:227
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_I
FOR_135: ; for loop
    LDD VAR_I
    LDD #2
    STD RESULT
    LDX RESULT
    CMPD RESULT
    LBCC FOR_END_136
    ; VPy_LINE:228
    LDD VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    ; ===== Const array indexing: ENT_HS_X =====
    LDD VAR_I
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDX #CONST_ARRAY_0
    LDD TMPPTR
    LEAX D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_DX
    STU TMPPTR
    STX ,U
    ; VPy_LINE:229
    LDD VAR_PLAYER_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    ; ===== Const array indexing: ENT_HS_Y =====
    LDD VAR_I
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDX #CONST_ARRAY_1
    LDD TMPPTR
    LEAX D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_DY
    STU TMPPTR
    STX ,U
    ; VPy_LINE:230
    LDD VAR_DX
    STD RESULT
    LDD RESULT
    TSTA
    BPL ABS_DONE_139
    COMA
    COMB
    ADDD #1
ABS_DONE_139:
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    ; ===== Const array indexing: ENT_HS_W =====
    LDD VAR_I
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDX #CONST_ARRAY_2
    LDD TMPPTR
    LEAX D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLE CT_140
    LDD #0
    STD RESULT
    BRA CE_141
CT_140:
    LDD #1
    STD RESULT
CE_141:
    LDD RESULT
    BEQ AND_FALSE_142
    LDD VAR_DY
    STD RESULT
    LDD RESULT
    TSTA
    BPL ABS_DONE_144
    COMA
    COMB
    ADDD #1
ABS_DONE_144:
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    ; ===== Const array indexing: ENT_HS_H =====
    LDD VAR_I
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDX #CONST_ARRAY_3
    LDD TMPPTR
    LEAX D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLE CT_145
    LDD #0
    STD RESULT
    BRA CE_146
CT_145:
    LDD #1
    STD RESULT
CE_146:
    LDD RESULT
    BEQ AND_FALSE_142
    LDD #1
    STD RESULT
    BRA AND_END_143
AND_FALSE_142:
    LDD #0
    STD RESULT
AND_END_143:
    LDD RESULT
    LBEQ IF_NEXT_138
    ; VPy_LINE:231
    LDD VAR_I
    STD RESULT
    LDX RESULT
    LDU #VAR_NEAR_HS
    STU TMPPTR
    STX ,U
    LBRA IF_END_137
IF_NEXT_138:
IF_END_137:
    LDX #1
    LDD VAR_I
    ADDD ,X
    STD VAR_I
    LBRA FOR_135
FOR_END_136: ; for end
    RTS

    ; VPy_LINE:234
INTERACT_ENTRANCE: ; function
; --- function interact_entrance ---
    LEAS -2,S ; allocate locals
    LDD VAR_ARG0
    STD 0,S ; param 0
    ; VPy_LINE:235
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_149
    LDD #0
    STD RESULT
    BRA CE_150
CT_149:
    LDD #1
    STD RESULT
CE_150:
    LDD RESULT
    LBEQ IF_NEXT_148
    ; VPy_LINE:236
    LDD VAR_CURRENT_VERB
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_153
    LDD #0
    STD RESULT
    BRA CE_154
CT_153:
    LDD #1
    STD RESULT
CE_154:
    LDD RESULT
    LBEQ IF_NEXT_152
    ; VPy_LINE:237
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_FLAG_DATE_KNOWN
    STU TMPPTR
    STX ,U
    ; VPy_LINE:238
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_MSG_ID
    STU TMPPTR
    STX ,U
    ; VPy_LINE:239
    LDD #160
    STD RESULT
    LDX RESULT
    LDU #VAR_MSG_TIMER
    STU TMPPTR
    STX ,U
    LBRA IF_END_151
IF_NEXT_152:
    LDD VAR_CURRENT_VERB
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_156
    LDD #0
    STD RESULT
    BRA CE_157
CT_156:
    LDD #1
    STD RESULT
CE_157:
    LDD RESULT
    LBEQ IF_NEXT_155
    ; VPy_LINE:241
    LDD #5
    STD RESULT
    LDX RESULT
    LDU #VAR_MSG_ID
    STU TMPPTR
    STX ,U
    ; VPy_LINE:242
    LDD #100
    STD RESULT
    LDX RESULT
    LDU #VAR_MSG_TIMER
    STU TMPPTR
    STX ,U
    LBRA IF_END_151
IF_NEXT_155:
    LDD VAR_CURRENT_VERB
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #2
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
    LBEQ IF_END_151
    ; VPy_LINE:244
    LDD #5
    STD RESULT
    LDX RESULT
    LDU #VAR_MSG_ID
    STU TMPPTR
    STX ,U
    ; VPy_LINE:245
    LDD #100
    STD RESULT
    LDX RESULT
    LDU #VAR_MSG_TIMER
    STU TMPPTR
    STX ,U
    LBRA IF_END_151
IF_END_151:
    LBRA IF_END_147
IF_NEXT_148:
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_160
    LDD #0
    STD RESULT
    BRA CE_161
CT_160:
    LDD #1
    STD RESULT
CE_161:
    LDD RESULT
    LBEQ IF_END_147
    ; VPy_LINE:248
    LDD VAR_CURRENT_VERB
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_164
    LDD #0
    STD RESULT
    BRA CE_165
CT_164:
    LDD #1
    STD RESULT
CE_165:
    LDD RESULT
    LBEQ IF_NEXT_163
    ; VPy_LINE:249
    LDD #2
    STD RESULT
    LDX RESULT
    LDU #VAR_MSG_ID
    STU TMPPTR
    STX ,U
    ; VPy_LINE:250
    LDD #120
    STD RESULT
    LDX RESULT
    LDU #VAR_MSG_TIMER
    STU TMPPTR
    STX ,U
    LBRA IF_END_162
IF_NEXT_163:
    LDD VAR_CURRENT_VERB
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_167
    LDD #0
    STD RESULT
    BRA CE_168
CT_167:
    LDD #1
    STD RESULT
CE_168:
    LDD RESULT
    LBEQ IF_NEXT_166
    ; VPy_LINE:252
    LDD VAR_FLAG_TALLER_OPEN
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_171
    LDD #0
    STD RESULT
    BRA CE_172
CT_171:
    LDD #1
    STD RESULT
CE_172:
    LDD RESULT
    LBEQ IF_NEXT_170
    ; VPy_LINE:253
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_ROOM_EXIT
    STU TMPPTR
    STX ,U
    ; VPy_LINE:254
    LDD #60
    STD RESULT
    LDX RESULT
    LDU #VAR_MSG_TIMER
    STU TMPPTR
    STX ,U
    LBRA IF_END_169
IF_NEXT_170:
    LDD VAR_FLAG_DATE_KNOWN
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_174
    LDD #0
    STD RESULT
    BRA CE_175
CT_174:
    LDD #1
    STD RESULT
CE_175:
    LDD RESULT
    LBEQ IF_NEXT_173
    ; VPy_LINE:256
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_FLAG_TALLER_OPEN
    STU TMPPTR
    STX ,U
    ; VPy_LINE:257
    LDD #4
    STD RESULT
    LDX RESULT
    LDU #VAR_MSG_ID
    STU TMPPTR
    STX ,U
    ; VPy_LINE:258
    LDD #200
    STD RESULT
    LDX RESULT
    LDU #VAR_MSG_TIMER
    STU TMPPTR
    STX ,U
    ; VPy_LINE:259
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_ROOM_EXIT
    STU TMPPTR
    STX ,U
    ; VPy_LINE:260
; PLAY_SFX("door_unlock") - play sound effect (one-shot)
    LDX #_DOOR_UNLOCK_SFX
    JSR PLAY_SFX_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_169
IF_NEXT_173:
    ; VPy_LINE:262
    LDD #3
    STD RESULT
    LDX RESULT
    LDU #VAR_MSG_ID
    STU TMPPTR
    STX ,U
    ; VPy_LINE:263
    LDD #120
    STD RESULT
    LDX RESULT
    LDU #VAR_MSG_TIMER
    STU TMPPTR
    STX ,U
    ; VPy_LINE:264
; PLAY_SFX("puzzle_fail") - play sound effect (one-shot)
    LDX #_PUZZLE_FAIL_SFX
    JSR PLAY_SFX_RUNTIME
    LDD #0
    STD RESULT
IF_END_169:
    LBRA IF_END_162
IF_NEXT_166:
    LDD VAR_CURRENT_VERB
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_176
    LDD #0
    STD RESULT
    BRA CE_177
CT_176:
    LDD #1
    STD RESULT
CE_177:
    LDD RESULT
    LBEQ IF_END_162
    ; VPy_LINE:266
    LDD #5
    STD RESULT
    LDX RESULT
    LDU #VAR_MSG_ID
    STU TMPPTR
    STX ,U
    ; VPy_LINE:267
    LDD #100
    STD RESULT
    LDX RESULT
    LDU #VAR_MSG_TIMER
    STU TMPPTR
    STX ,U
    LBRA IF_END_162
IF_END_162:
    LBRA IF_END_147
IF_END_147:
    LEAS 2,S ; free locals
    RTS

    ; VPy_LINE:272
DRAW_ROOM: ; function
; --- function draw_room ---
    ; VPy_LINE:274
    LDD #100
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 274
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:275
; NATIVE_CALL: UPDATE_LEVEL at line 275
    JSR UPDATE_LEVEL_RUNTIME
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:276
; SHOW_LEVEL() - draw all level objects
    JSR SHOW_LEVEL_RUNTIME
    LDD #0
    STD RESULT
    ; VPy_LINE:279
    LDD #110
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 279
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:280
; DRAW_VECTOR("player", x, y) - 7 path(s) at position
    LDD VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD VAR_PLAYER_Y
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
    LDX #_PLAYER_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_PLAYER_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_PLAYER_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_PLAYER_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_PLAYER_PATH4  ; Path 4
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_PLAYER_PATH5  ; Path 5
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_PLAYER_PATH6  ; Path 6
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    ; VPy_LINE:283
    JSR DRAW_HUD
    ; VPy_LINE:286
    LDD VAR_NEAR_HS
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGE CT_180
    LDD #0
    STD RESULT
    BRA CE_181
CT_180:
    LDD #1
    STD RESULT
CE_181:
    LDD RESULT
    BEQ AND_FALSE_182
    LDD VAR_MSG_TIMER
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_184
    LDD #0
    STD RESULT
    BRA CE_185
CT_184:
    LDD #1
    STD RESULT
CE_185:
    LDD RESULT
    BEQ AND_FALSE_182
    LDD #1
    STD RESULT
    BRA AND_END_183
AND_FALSE_182:
    LDD #0
    STD RESULT
AND_END_183:
    LDD RESULT
    LBEQ IF_NEXT_179
    ; VPy_LINE:287
    JSR DRAW_HOTSPOT_PROMPT
    LBRA IF_END_178
IF_NEXT_179:
IF_END_178:
    ; VPy_LINE:290
    LDD VAR_MSG_TIMER
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_188
    LDD #0
    STD RESULT
    BRA CE_189
CT_188:
    LDD #1
    STD RESULT
CE_189:
    LDD RESULT
    LBEQ IF_NEXT_187
    ; VPy_LINE:291
    JSR DRAW_MESSAGE
    LBRA IF_END_186
IF_NEXT_187:
IF_END_186:
    RTS

    ; VPy_LINE:294
DRAW_HUD: ; function
; --- function draw_hud ---
    ; VPy_LINE:295
    LDD #70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 295
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:296
    LDD VAR_CURRENT_VERB
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_192
    LDD #0
    STD RESULT
    BRA CE_193
CT_192:
    LDD #1
    STD RESULT
CE_193:
    LDD RESULT
    LBEQ IF_NEXT_191
    ; VPy_LINE:297
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-90
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #108
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_7
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 297
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_190
IF_NEXT_191:
    LDD VAR_CURRENT_VERB
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_195
    LDD #0
    STD RESULT
    BRA CE_196
CT_195:
    LDD #1
    STD RESULT
CE_196:
    LDD RESULT
    LBEQ IF_NEXT_194
    ; VPy_LINE:299
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-90
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #108
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_18
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 299
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_190
IF_NEXT_194:
    LDD VAR_CURRENT_VERB
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_197
    LDD #0
    STD RESULT
    BRA CE_198
CT_197:
    LDD #1
    STD RESULT
CE_198:
    LDD RESULT
    LBEQ IF_END_190
    ; VPy_LINE:301
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-90
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #108
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_29
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 301
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_190
IF_END_190:
    RTS

    ; VPy_LINE:304
DRAW_HOTSPOT_PROMPT: ; function
; --- function draw_hotspot_prompt ---
    ; VPy_LINE:305
    LDD #90
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 305
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:306
    LDD VAR_CURRENT_ROOM
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_201
    LDD #0
    STD RESULT
    BRA CE_202
CT_201:
    LDD #1
    STD RESULT
CE_202:
    LDD RESULT
    LBEQ IF_NEXT_200
    ; VPy_LINE:307
    LDD VAR_NEAR_HS
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_205
    LDD #0
    STD RESULT
    BRA CE_206
CT_205:
    LDD #1
    STD RESULT
CE_206:
    LDD RESULT
    LBEQ IF_NEXT_204
    ; VPy_LINE:308
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-49
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-108
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_8
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 308
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_203
IF_NEXT_204:
    LDD VAR_NEAR_HS
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_207
    LDD #0
    STD RESULT
    BRA CE_208
CT_207:
    LDD #1
    STD RESULT
CE_208:
    LDD RESULT
    LBEQ IF_END_203
    ; VPy_LINE:310
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-49
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-108
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_31
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 310
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_203
IF_END_203:
    LBRA IF_END_199
IF_NEXT_200:
IF_END_199:
    RTS

    ; VPy_LINE:318
DRAW_MESSAGE: ; function
; --- function draw_message ---
    ; VPy_LINE:319
    LDD #100
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 319
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:320
    LDD VAR_MSG_ID
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_211
    LDD #0
    STD RESULT
    BRA CE_212
CT_211:
    LDD #1
    STD RESULT
CE_212:
    LDD RESULT
    LBEQ IF_NEXT_210
    ; VPy_LINE:321
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-75
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_25
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 321
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:322
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-88
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_30
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 322
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:323
    LDD #80
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 323
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:324
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-101
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_2
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 324
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_209
IF_NEXT_210:
    LDD VAR_MSG_ID
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_214
    LDD #0
    STD RESULT
    BRA CE_215
CT_214:
    LDD #1
    STD RESULT
CE_215:
    LDD RESULT
    LBEQ IF_NEXT_213
    ; VPy_LINE:326
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-75
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_1
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 326
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:327
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-88
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_0
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 327
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_209
IF_NEXT_213:
    LDD VAR_MSG_ID
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_217
    LDD #0
    STD RESULT
    BRA CE_218
CT_217:
    LDD #1
    STD RESULT
CE_218:
    LDD RESULT
    LBEQ IF_NEXT_216
    ; VPy_LINE:329
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-75
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_35
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 329
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:330
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-88
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_20
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 330
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_209
IF_NEXT_216:
    LDD VAR_MSG_ID
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #4
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_220
    LDD #0
    STD RESULT
    BRA CE_221
CT_220:
    LDD #1
    STD RESULT
CE_221:
    LDD RESULT
    LBEQ IF_NEXT_219
    ; VPy_LINE:332
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-75
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_36
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 332
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:333
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-88
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_21
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 333
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_209
IF_NEXT_219:
    LDD VAR_MSG_ID
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #5
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_222
    LDD #0
    STD RESULT
    BRA CE_223
CT_222:
    LDD #1
    STD RESULT
CE_223:
    LDD RESULT
    LBEQ IF_END_209
    ; VPy_LINE:335
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-63
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-82
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_33
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 335
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    LBRA IF_END_209
IF_END_209:
    RTS

    ; VPy_LINE:343
DRAW_ENDING: ; function
; --- function draw_ending ---
    ; VPy_LINE:344
    LDD #100
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 344
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:345
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-42
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #10
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_27
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 345
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    RTS

;***************************************************************************
; DATA SECTION
;***************************************************************************

; ========================================
; ASSET DATA SECTION
; Embedded 9 of 12 assets (unused assets excluded)
; ========================================

; Vector asset: entrance_bg
; Generated from entrance_bg.vec (Malban Draw_Sync_List format)
; Total paths: 16, points: 36
; X bounds: min=-88, max=88, width=176
; Center: (0, 7)

_ENTRANCE_BG_WIDTH EQU 176
_ENTRANCE_BG_CENTER_X EQU 0
_ENTRANCE_BG_CENTER_Y EQU 7

_ENTRANCE_BG_VECTORS:  ; Main entry (header + 16 path(s))
    FCB 16               ; path_count (runtime metadata)
    FDB _ENTRANCE_BG_PATH0        ; pointer to path 0
    FDB _ENTRANCE_BG_PATH1        ; pointer to path 1
    FDB _ENTRANCE_BG_PATH2        ; pointer to path 2
    FDB _ENTRANCE_BG_PATH3        ; pointer to path 3
    FDB _ENTRANCE_BG_PATH4        ; pointer to path 4
    FDB _ENTRANCE_BG_PATH5        ; pointer to path 5
    FDB _ENTRANCE_BG_PATH6        ; pointer to path 6
    FDB _ENTRANCE_BG_PATH7        ; pointer to path 7
    FDB _ENTRANCE_BG_PATH8        ; pointer to path 8
    FDB _ENTRANCE_BG_PATH9        ; pointer to path 9
    FDB _ENTRANCE_BG_PATH10        ; pointer to path 10
    FDB _ENTRANCE_BG_PATH11        ; pointer to path 11
    FDB _ENTRANCE_BG_PATH12        ; pointer to path 12
    FDB _ENTRANCE_BG_PATH13        ; pointer to path 13
    FDB _ENTRANCE_BG_PATH14        ; pointer to path 14
    FDB _ENTRANCE_BG_PATH15        ; pointer to path 15

_ENTRANCE_BG_PATH0:    ; Path 0
    FCB 90              ; path0: intensity
    FCB $A4,$A8,0,0        ; path0: header (y=-92, x=-88, relative to center)
    FCB $FF,$00,$58          ; sub-seg 1/2 of line 0: dy=0, dx=88
    FCB $FF,$00,$58          ; sub-seg 2/2 of line 0: dy=0, dx=88
    FCB 2                ; End marker (path complete)

_ENTRANCE_BG_PATH1:    ; Path 1
    FCB 90              ; path1: intensity
    FCB $5D,$A8,0,0        ; path1: header (y=93, x=-88, relative to center)
    FCB $FF,$00,$58          ; sub-seg 1/2 of line 0: dy=0, dx=88
    FCB $FF,$00,$58          ; sub-seg 2/2 of line 0: dy=0, dx=88
    FCB 2                ; End marker (path complete)

_ENTRANCE_BG_PATH2:    ; Path 2
    FCB 80              ; path2: intensity
    FCB $A4,$A8,0,0        ; path2: header (y=-92, x=-88, relative to center)
    FCB $FF,$5C,$00          ; sub-seg 1/2 of line 0: dy=92, dx=0
    FCB $FF,$5D,$00          ; sub-seg 2/2 of line 0: dy=93, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_BG_PATH3:    ; Path 3
    FCB 80              ; path3: intensity
    FCB $A4,$58,0,0        ; path3: header (y=-92, x=88, relative to center)
    FCB $FF,$5C,$00          ; sub-seg 1/2 of line 0: dy=92, dx=0
    FCB $FF,$5D,$00          ; sub-seg 2/2 of line 0: dy=93, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_BG_PATH4:    ; Path 4
    FCB 100              ; path4: intensity
    FCB $17,$A8,0,0        ; path4: header (y=23, x=-88, relative to center)
    FCB $FF,$08,$07          ; flag=-1, dy=8, dx=7
    FCB $FF,$F8,$06          ; flag=-1, dy=-8, dx=6
    FCB $FF,$8D,$00          ; flag=-1, dy=-115, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_BG_PATH5:    ; Path 5
    FCB 80              ; path5: intensity
    FCB $21,$37,0,0        ; path5: header (y=33, x=55, relative to center)
    FCB $FF,$83,$00          ; flag=-1, dy=-125, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_BG_PATH6:    ; Path 6
    FCB 80              ; path6: intensity
    FCB $21,$4B,0,0        ; path6: header (y=33, x=75, relative to center)
    FCB $FF,$83,$00          ; flag=-1, dy=-125, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_BG_PATH7:    ; Path 7
    FCB 80              ; path7: intensity
    FCB $21,$37,0,0        ; path7: header (y=33, x=55, relative to center)
    FCB $FF,$00,$14          ; flag=-1, dy=0, dx=20
    FCB 2                ; End marker (path complete)

_ENTRANCE_BG_PATH8:    ; Path 8
    FCB 50              ; path8: intensity
    FCB $2B,$A8,0,0        ; path8: header (y=43, x=-88, relative to center)
    FCB $FF,$00,$58          ; sub-seg 1/2 of line 0: dy=0, dx=88
    FCB $FF,$00,$58          ; sub-seg 2/2 of line 0: dy=0, dx=88
    FCB 2                ; End marker (path complete)

_ENTRANCE_BG_PATH9:    ; Path 9
    FCB 50              ; path9: intensity
    FCB $03,$A8,0,0        ; path9: header (y=3, x=-88, relative to center)
    FCB $FF,$00,$58          ; sub-seg 1/2 of line 0: dy=0, dx=88
    FCB $FF,$00,$58          ; sub-seg 2/2 of line 0: dy=0, dx=88
    FCB 2                ; End marker (path complete)

_ENTRANCE_BG_PATH10:    ; Path 10
    FCB 50              ; path10: intensity
    FCB $DB,$A8,0,0        ; path10: header (y=-37, x=-88, relative to center)
    FCB $FF,$00,$58          ; sub-seg 1/2 of line 0: dy=0, dx=88
    FCB $FF,$00,$58          ; sub-seg 2/2 of line 0: dy=0, dx=88
    FCB 2                ; End marker (path complete)

_ENTRANCE_BG_PATH11:    ; Path 11
    FCB 40              ; path11: intensity
    FCB $53,$AE,0,0        ; path11: header (y=83, x=-82, relative to center)
    FCB $FF,$F8,$0A          ; flag=-1, dy=-8, dx=10
    FCB 2                ; End marker (path complete)

_ENTRANCE_BG_PATH12:    ; Path 12
    FCB 40              ; path12: intensity
    FCB $53,$AE,0,0        ; path12: header (y=83, x=-82, relative to center)
    FCB $FF,$F6,$FA          ; flag=-1, dy=-10, dx=-6
    FCB 2                ; End marker (path complete)

_ENTRANCE_BG_PATH13:    ; Path 13
    FCB 40              ; path13: intensity
    FCB $53,$AE,0,0        ; path13: header (y=83, x=-82, relative to center)
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB 2                ; End marker (path complete)

_ENTRANCE_BG_PATH14:    ; Path 14
    FCB 60              ; path14: intensity
    FCB $35,$A8,0,0        ; path14: header (y=53, x=-88, relative to center)
    FCB $FF,$05,$08          ; flag=-1, dy=5, dx=8
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_BG_PATH15:    ; Path 15
    FCB 60              ; path15: intensity
    FCB $35,$58,0,0        ; path15: header (y=53, x=88, relative to center)
    FCB $FF,$05,$F8          ; flag=-1, dy=5, dx=-8
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

; Vector asset: player
; Generated from player.vec (Malban Draw_Sync_List format)
; Total paths: 7, points: 27
; X bounds: min=-10, max=11, width=21
; Center: (0, -1)

_PLAYER_WIDTH EQU 21
_PLAYER_CENTER_X EQU 0
_PLAYER_CENTER_Y EQU -1

_PLAYER_VECTORS:  ; Main entry (header + 7 path(s))
    FCB 7               ; path_count (runtime metadata)
    FDB _PLAYER_PATH0        ; pointer to path 0
    FDB _PLAYER_PATH1        ; pointer to path 1
    FDB _PLAYER_PATH2        ; pointer to path 2
    FDB _PLAYER_PATH3        ; pointer to path 3
    FDB _PLAYER_PATH4        ; pointer to path 4
    FDB _PLAYER_PATH5        ; pointer to path 5
    FDB _PLAYER_PATH6        ; pointer to path 6

_PLAYER_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $0D,$FB,0,0        ; path0: header (y=13, x=-5, relative to center)
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$00,$10          ; flag=-1, dy=0, dx=16
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $06,$FB,0,0        ; path1: header (y=6, x=-5, relative to center)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $06,$FC,0,0        ; path2: header (y=6, x=-4, relative to center)
    FCB $FF,$F6,$FE          ; flag=-1, dy=-10, dx=-2
    FCB $FF,$F7,$FE          ; flag=-1, dy=-9, dx=-2
    FCB $FF,$00,$10          ; flag=-1, dy=0, dx=16
    FCB $FF,$09,$FE          ; flag=-1, dy=9, dx=-2
    FCB $FF,$0A,$FE          ; flag=-1, dy=10, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $F3,$FC,0,0        ; path3: header (y=-13, x=-4, relative to center)
    FCB $FF,$F8,$FF          ; flag=-1, dy=-8, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $F3,$04,0,0        ; path4: header (y=-13, x=4, relative to center)
    FCB $FF,$F8,$01          ; flag=-1, dy=-8, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_PATH5:    ; Path 5
    FCB 100              ; path5: intensity
    FCB $FF,$FA,0,0        ; path5: header (y=-1, x=-6, relative to center)
    FCB $FF,$FA,$FC          ; flag=-1, dy=-6, dx=-4
    FCB 2                ; End marker (path complete)

_PLAYER_PATH6:    ; Path 6
    FCB 100              ; path6: intensity
    FCB $FF,$06,0,0        ; path6: header (y=-1, x=6, relative to center)
    FCB $FF,$FB,$05          ; flag=-1, dy=-5, dx=5
    FCB 2                ; End marker (path complete)

; Vector asset: crypt_logo
; Generated from crypt_logo.vec (Malban Draw_Sync_List format)
; Total paths: 40, points: 169
; X bounds: min=-83, max=83, width=166
; Center: (0, 16)

_CRYPT_LOGO_WIDTH EQU 166
_CRYPT_LOGO_CENTER_X EQU 0
_CRYPT_LOGO_CENTER_Y EQU 16

_CRYPT_LOGO_VECTORS:  ; Main entry (header + 40 path(s))
    FCB 40               ; path_count (runtime metadata)
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
    FCB 90              ; path0: intensity
    FCB $52,$00,0,0        ; path0: header (y=82, x=0, relative to center)
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

_CRYPT_LOGO_PATH1:    ; Path 1
    FCB 90              ; path1: intensity
    FCB $3E,$00,0,0        ; path1: header (y=62, x=0, relative to center)
    FCB $FF,$12,$00          ; flag=-1, dy=18, dx=0
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH2:    ; Path 2
    FCB 90              ; path2: intensity
    FCB $3E,$00,0,0        ; path2: header (y=62, x=0, relative to center)
    FCB $FF,$0C,$F3          ; flag=-1, dy=12, dx=-13
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH3:    ; Path 3
    FCB 90              ; path3: intensity
    FCB $40,$00,0,0        ; path3: header (y=64, x=0, relative to center)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH4:    ; Path 4
    FCB 60              ; path4: intensity
    FCB $2A,$00,0,0        ; path4: header (y=42, x=0, relative to center)
    FCB $FF,$EE,$00          ; flag=-1, dy=-18, dx=0
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH5:    ; Path 5
    FCB 70              ; path5: intensity
    FCB $1D,$00,0,0        ; path5: header (y=29, x=0, relative to center)
    FCB $FF,$FB,$FC          ; flag=-1, dy=-5, dx=-4
    FCB $FF,$FB,$04          ; flag=-1, dy=-5, dx=4
    FCB $FF,$05,$04          ; flag=-1, dy=5, dx=4
    FCB $FF,$05,$FC          ; flag=-1, dy=5, dx=-4
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH6:    ; Path 6
    FCB 70              ; path6: intensity
    FCB $13,$B5,0,0        ; path6: header (y=19, x=-75, relative to center)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH7:    ; Path 7
    FCB 70              ; path7: intensity
    FCB $13,$B9,0,0        ; path7: header (y=19, x=-71, relative to center)
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH8:    ; Path 8
    FCB 70              ; path8: intensity
    FCB $09,$BF,0,0        ; path8: header (y=9, x=-65, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH9:    ; Path 9
    FCB 70              ; path9: intensity
    FCB $13,$C7,0,0        ; path9: header (y=19, x=-57, relative to center)
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

_CRYPT_LOGO_PATH10:    ; Path 10
    FCB 70              ; path10: intensity
    FCB $12,$D7,0,0        ; path10: header (y=18, x=-41, relative to center)
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH11:    ; Path 11
    FCB 70              ; path11: intensity
    FCB $13,$D9,0,0        ; path11: header (y=19, x=-39, relative to center)
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH12:    ; Path 12
    FCB 70              ; path12: intensity
    FCB $13,$E1,0,0        ; path12: header (y=19, x=-31, relative to center)
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH13:    ; Path 13
    FCB 70              ; path13: intensity
    FCB $12,$EF,0,0        ; path13: header (y=18, x=-17, relative to center)
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH14:    ; Path 14
    FCB 70              ; path14: intensity
    FCB $09,$F1,0,0        ; path14: header (y=9, x=-15, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH15:    ; Path 15
    FCB 70              ; path15: intensity
    FCB $0E,$F1,0,0        ; path15: header (y=14, x=-15, relative to center)
    FCB $FF,$05,$05          ; flag=-1, dy=5, dx=5
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH16:    ; Path 16
    FCB 70              ; path16: intensity
    FCB $0E,$F1,0,0        ; path16: header (y=14, x=-15, relative to center)
    FCB $FF,$FB,$05          ; flag=-1, dy=-5, dx=5
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH17:    ; Path 17
    FCB 70              ; path17: intensity
    FCB $09,$F9,0,0        ; path17: header (y=9, x=-7, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$FB,$03          ; flag=-1, dy=-5, dx=3
    FCB $FF,$05,$03          ; flag=-1, dy=5, dx=3
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH18:    ; Path 18
    FCB 70              ; path18: intensity
    FCB $09,$01,0,0        ; path18: header (y=9, x=1, relative to center)
    FCB $FF,$0A,$03          ; flag=-1, dy=10, dx=3
    FCB $FF,$F6,$03          ; flag=-1, dy=-10, dx=3
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH19:    ; Path 19
    FCB 70              ; path19: intensity
    FCB $0E,$02,0,0        ; path19: header (y=14, x=2, relative to center)
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH20:    ; Path 20
    FCB 70              ; path20: intensity
    FCB $09,$09,0,0        ; path20: header (y=9, x=9, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH21:    ; Path 21
    FCB 70              ; path21: intensity
    FCB $0E,$09,0,0        ; path21: header (y=14, x=9, relative to center)
    FCB $FF,$05,$05          ; flag=-1, dy=5, dx=5
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH22:    ; Path 22
    FCB 70              ; path22: intensity
    FCB $0E,$09,0,0        ; path22: header (y=14, x=9, relative to center)
    FCB $FF,$FB,$05          ; flag=-1, dy=-5, dx=5
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH23:    ; Path 23
    FCB 70              ; path23: intensity
    FCB $13,$11,0,0        ; path23: header (y=19, x=17, relative to center)
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

_CRYPT_LOGO_PATH24:    ; Path 24
    FCB 70              ; path24: intensity
    FCB $09,$19,0,0        ; path24: header (y=9, x=25, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH25:    ; Path 25
    FCB 70              ; path25: intensity
    FCB $12,$29,0,0        ; path25: header (y=18, x=41, relative to center)
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH26:    ; Path 26
    FCB 127              ; path26: intensity
    FCB $04,$CA,0,0        ; path26: header (y=4, x=-54, relative to center)
    FCB $FF,$00,$E4          ; flag=-1, dy=0, dx=-28
    FCB $FF,$D8,$00          ; flag=-1, dy=-40, dx=0
    FCB $FF,$00,$1C          ; flag=-1, dy=0, dx=28
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$E9          ; flag=-1, dy=0, dx=-23
    FCB $FF,$1C,$00          ; flag=-1, dy=28, dx=0
    FCB $FF,$00,$17          ; flag=-1, dy=0, dx=23
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH27:    ; Path 27
    FCB 127              ; path27: intensity
    FCB $DC,$D0,0,0        ; path27: header (y=-36, x=-48, relative to center)
    FCB $FF,$28,$00          ; flag=-1, dy=40, dx=0
    FCB $FF,$00,$14          ; flag=-1, dy=0, dx=20
    FCB $FF,$FA,$08          ; flag=-1, dy=-6, dx=8
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$FB,$F8          ; flag=-1, dy=-5, dx=-8
    FCB $FF,$00,$EC          ; flag=-1, dy=0, dx=-20
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH28:    ; Path 28
    FCB 127              ; path28: intensity
    FCB $EF,$E4,0,0        ; path28: header (y=-17, x=-28, relative to center)
    FCB $FF,$ED,$08          ; flag=-1, dy=-19, dx=8
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH29:    ; Path 29
    FCB 127              ; path29: intensity
    FCB $04,$F2,0,0        ; path29: header (y=4, x=-14, relative to center)
    FCB $FF,$EC,$0E          ; flag=-1, dy=-20, dx=14
    FCB $FF,$14,$0E          ; flag=-1, dy=20, dx=14
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH30:    ; Path 30
    FCB 127              ; path30: intensity
    FCB $F0,$00,0,0        ; path30: header (y=-16, x=0, relative to center)
    FCB $FF,$EC,$00          ; flag=-1, dy=-20, dx=0
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH31:    ; Path 31
    FCB 127              ; path31: intensity
    FCB $DC,$14,0,0        ; path31: header (y=-36, x=20, relative to center)
    FCB $FF,$28,$00          ; flag=-1, dy=40, dx=0
    FCB $FF,$00,$14          ; flag=-1, dy=0, dx=20
    FCB $FF,$FA,$08          ; flag=-1, dy=-6, dx=8
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$FB,$F8          ; flag=-1, dy=-5, dx=-8
    FCB $FF,$00,$EC          ; flag=-1, dy=0, dx=-20
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH32:    ; Path 32
    FCB 127              ; path32: intensity
    FCB $04,$36,0,0        ; path32: header (y=4, x=54, relative to center)
    FCB $FF,$00,$1C          ; flag=-1, dy=0, dx=28
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH33:    ; Path 33
    FCB 127              ; path33: intensity
    FCB $04,$44,0,0        ; path33: header (y=4, x=68, relative to center)
    FCB $FF,$D8,$00          ; flag=-1, dy=-40, dx=0
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH34:    ; Path 34
    FCB 100              ; path34: intensity
    FCB $D8,$AD,0,0        ; path34: header (y=-40, x=-83, relative to center)
    FCB $FF,$00,$53          ; sub-seg 1/2 of line 0: dy=0, dx=83
    FCB $FF,$00,$53          ; sub-seg 2/2 of line 0: dy=0, dx=83
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH35:    ; Path 35
    FCB 70              ; path35: intensity
    FCB $06,$AD,0,0        ; path35: header (y=6, x=-83, relative to center)
    FCB $FF,$00,$53          ; sub-seg 1/2 of line 0: dy=0, dx=83
    FCB $FF,$00,$53          ; sub-seg 2/2 of line 0: dy=0, dx=83
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH36:    ; Path 36
    FCB 80              ; path36: intensity
    FCB $C8,$00,0,0        ; path36: header (y=-56, x=0, relative to center)
    FCB $FF,$FD,$05          ; flag=-1, dy=-3, dx=5
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$FD,$FB          ; flag=-1, dy=-3, dx=-5
    FCB $FF,$03,$FB          ; flag=-1, dy=3, dx=-5
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$03,$05          ; flag=-1, dy=3, dx=5
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH37:    ; Path 37
    FCB 80              ; path37: intensity
    FCB $BD,$00,0,0        ; path37: header (y=-67, x=0, relative to center)
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH38:    ; Path 38
    FCB 80              ; path38: intensity
    FCB $B7,$00,0,0        ; path38: header (y=-73, x=0, relative to center)
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB 2                ; End marker (path complete)

_CRYPT_LOGO_PATH39:    ; Path 39
    FCB 80              ; path39: intensity
    FCB $B2,$00,0,0        ; path39: header (y=-78, x=0, relative to center)
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB 2                ; End marker (path complete)

; Vector asset: door_locked
; Generated from door_locked.vec (Malban Draw_Sync_List format)
; Total paths: 13, points: 59
; X bounds: min=-11, max=11, width=22
; Center: (0, 1)

_DOOR_LOCKED_WIDTH EQU 22
_DOOR_LOCKED_CENTER_X EQU 0
_DOOR_LOCKED_CENTER_Y EQU 1

_DOOR_LOCKED_VECTORS:  ; Main entry (header + 13 path(s))
    FCB 13               ; path_count (runtime metadata)
    FDB _DOOR_LOCKED_PATH0        ; pointer to path 0
    FDB _DOOR_LOCKED_PATH1        ; pointer to path 1
    FDB _DOOR_LOCKED_PATH2        ; pointer to path 2
    FDB _DOOR_LOCKED_PATH3        ; pointer to path 3
    FDB _DOOR_LOCKED_PATH4        ; pointer to path 4
    FDB _DOOR_LOCKED_PATH5        ; pointer to path 5
    FDB _DOOR_LOCKED_PATH6        ; pointer to path 6
    FDB _DOOR_LOCKED_PATH7        ; pointer to path 7
    FDB _DOOR_LOCKED_PATH8        ; pointer to path 8
    FDB _DOOR_LOCKED_PATH9        ; pointer to path 9
    FDB _DOOR_LOCKED_PATH10        ; pointer to path 10
    FDB _DOOR_LOCKED_PATH11        ; pointer to path 11
    FDB _DOOR_LOCKED_PATH12        ; pointer to path 12

_DOOR_LOCKED_PATH0:    ; Path 0
    FCB 110              ; path0: intensity
    FCB $E6,$F5,0,0        ; path0: header (y=-26, x=-11, relative to center)
    FCB $FF,$2D,$00          ; flag=-1, dy=45, dx=0
    FCB $FF,$08,$06          ; flag=-1, dy=8, dx=6
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$F8,$06          ; flag=-1, dy=-8, dx=6
    FCB $FF,$D3,$00          ; flag=-1, dy=-45, dx=0
    FCB $FF,$00,$EA          ; flag=-1, dy=0, dx=-22
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH1:    ; Path 1
    FCB 90              ; path1: intensity
    FCB $04,$F8,0,0        ; path1: header (y=4, x=-8, relative to center)
    FCB $FF,$0D,$00          ; flag=-1, dy=13, dx=0
    FCB $FF,$00,$10          ; flag=-1, dy=0, dx=16
    FCB $FF,$F3,$00          ; flag=-1, dy=-13, dx=0
    FCB $FF,$00,$F0          ; flag=-1, dy=0, dx=-16
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH2:    ; Path 2
    FCB 90              ; path2: intensity
    FCB $E9,$F8,0,0        ; path2: header (y=-23, x=-8, relative to center)
    FCB $FF,$14,$00          ; flag=-1, dy=20, dx=0
    FCB $FF,$00,$10          ; flag=-1, dy=0, dx=16
    FCB $FF,$EC,$00          ; flag=-1, dy=-20, dx=0
    FCB $FF,$00,$F0          ; flag=-1, dy=0, dx=-16
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH3:    ; Path 3
    FCB 70              ; path3: intensity
    FCB $E6,$00,0,0        ; path3: header (y=-26, x=0, relative to center)
    FCB $FF,$35,$00          ; flag=-1, dy=53, dx=0
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH4:    ; Path 4
    FCB 80              ; path4: intensity
    FCB $0E,$08,0,0        ; path4: header (y=14, x=8, relative to center)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH5:    ; Path 5
    FCB 80              ; path5: intensity
    FCB $F0,$08,0,0        ; path5: header (y=-16, x=8, relative to center)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH6:    ; Path 6
    FCB 120              ; path6: intensity
    FCB $FC,$F9,0,0        ; path6: header (y=-4, x=-7, relative to center)
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH7:    ; Path 7
    FCB 100              ; path7: intensity
    FCB $FA,$FB,0,0        ; path7: header (y=-6, x=-5, relative to center)
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH8:    ; Path 8
    FCB 100              ; path8: intensity
    FCB $FA,$FE,0,0        ; path8: header (y=-6, x=-2, relative to center)
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH9:    ; Path 9
    FCB 100              ; path9: intensity
    FCB $FA,$01,0,0        ; path9: header (y=-6, x=1, relative to center)
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH10:    ; Path 10
    FCB 100              ; path10: intensity
    FCB $FA,$04,0,0        ; path10: header (y=-6, x=4, relative to center)
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH11:    ; Path 11
    FCB 110              ; path11: intensity
    FCB $F1,$00,0,0        ; path11: header (y=-15, x=0, relative to center)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH12:    ; Path 12
    FCB 110              ; path12: intensity
    FCB $F1,$00,0,0        ; path12: header (y=-15, x=0, relative to center)
    FCB $FF,$FF,$01          ; flag=-1, dy=-1, dx=1
    FCB $FF,$FF,$FF          ; flag=-1, dy=-1, dx=-1
    FCB $FF,$01,$FF          ; flag=-1, dy=1, dx=-1
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB 2                ; End marker (path complete)

; Vector asset: painting
; Generated from painting.vec (Malban Draw_Sync_List format)
; Total paths: 10, points: 42
; X bounds: min=-16, max=16, width=32
; Center: (0, 0)

_PAINTING_WIDTH EQU 32
_PAINTING_CENTER_X EQU 0
_PAINTING_CENTER_Y EQU 0

_PAINTING_VECTORS:  ; Main entry (header + 10 path(s))
    FCB 10               ; path_count (runtime metadata)
    FDB _PAINTING_PATH0        ; pointer to path 0
    FDB _PAINTING_PATH1        ; pointer to path 1
    FDB _PAINTING_PATH2        ; pointer to path 2
    FDB _PAINTING_PATH3        ; pointer to path 3
    FDB _PAINTING_PATH4        ; pointer to path 4
    FDB _PAINTING_PATH5        ; pointer to path 5
    FDB _PAINTING_PATH6        ; pointer to path 6
    FDB _PAINTING_PATH7        ; pointer to path 7
    FDB _PAINTING_PATH8        ; pointer to path 8
    FDB _PAINTING_PATH9        ; pointer to path 9

_PAINTING_PATH0:    ; Path 0
    FCB 110              ; path0: intensity
    FCB $10,$F2,0,0        ; path0: header (y=16, x=-14, relative to center)
    FCB $FF,$00,$1C          ; flag=-1, dy=0, dx=28
    FCB $FF,$E0,$00          ; flag=-1, dy=-32, dx=0
    FCB $FF,$00,$E4          ; flag=-1, dy=0, dx=-28
    FCB $FF,$20,$00          ; flag=-1, dy=32, dx=0
    FCB 2                ; End marker (path complete)

_PAINTING_PATH1:    ; Path 1
    FCB 90              ; path1: intensity
    FCB $0D,$F5,0,0        ; path1: header (y=13, x=-11, relative to center)
    FCB $FF,$00,$16          ; flag=-1, dy=0, dx=22
    FCB $FF,$E6,$00          ; flag=-1, dy=-26, dx=0
    FCB $FF,$00,$EA          ; flag=-1, dy=0, dx=-22
    FCB $FF,$1A,$00          ; flag=-1, dy=26, dx=0
    FCB 2                ; End marker (path complete)

_PAINTING_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $10,$F2,0,0        ; path2: header (y=16, x=-14, relative to center)
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB 2                ; End marker (path complete)

_PAINTING_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $10,$0E,0,0        ; path3: header (y=16, x=14, relative to center)
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB 2                ; End marker (path complete)

_PAINTING_PATH4:    ; Path 4
    FCB 100              ; path4: intensity
    FCB $F0,$F2,0,0        ; path4: header (y=-16, x=-14, relative to center)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB 2                ; End marker (path complete)

_PAINTING_PATH5:    ; Path 5
    FCB 100              ; path5: intensity
    FCB $F0,$0E,0,0        ; path5: header (y=-16, x=14, relative to center)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB 2                ; End marker (path complete)

_PAINTING_PATH6:    ; Path 6
    FCB 70              ; path6: intensity
    FCB $0A,$FA,0,0        ; path6: header (y=10, x=-6, relative to center)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB $FF,$FA,$02          ; flag=-1, dy=-6, dx=2
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$FA,$FE          ; flag=-1, dy=-6, dx=-2
    FCB $FF,$00,$F4          ; flag=-1, dy=0, dx=-12
    FCB $FF,$06,$FE          ; flag=-1, dy=6, dx=-2
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$06,$02          ; flag=-1, dy=6, dx=2
    FCB 2                ; End marker (path complete)

_PAINTING_PATH7:    ; Path 7
    FCB 80              ; path7: intensity
    FCB $03,$FD,0,0        ; path7: header (y=3, x=-3, relative to center)
    FCB $FF,$00,$01          ; flag=-1, dy=0, dx=1
    FCB 2                ; End marker (path complete)

_PAINTING_PATH8:    ; Path 8
    FCB 80              ; path8: intensity
    FCB $03,$02,0,0        ; path8: header (y=3, x=2, relative to center)
    FCB $FF,$00,$01          ; flag=-1, dy=0, dx=1
    FCB 2                ; End marker (path complete)

_PAINTING_PATH9:    ; Path 9
    FCB 70              ; path9: intensity
    FCB $FE,$FC,0,0        ; path9: header (y=-2, x=-4, relative to center)
    FCB $FF,$FE,$04          ; flag=-1, dy=-2, dx=4
    FCB $FF,$02,$04          ; flag=-1, dy=2, dx=4
    FCB 2                ; End marker (path complete)

; Generated from exploration.vmus (internal name: The Clockmaker's Crypt - Exploration)
; Tempo: 60 BPM, Total events: 13 (PSG Direct format)
; Format: FCB count, FCB reg, val, ... (per frame), FCB 0 (end)

_EXPLORATION_MUSIC:
    ; Frame-based PSG register writes
    FCB     0              ; Delay 0 frames (maintain previous state)
    FCB     8              ; Frame 0 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $2C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $09             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $58             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $06             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FC             ; Reg 7 value
    FCB     37              ; Delay 37 frames (maintain previous state)
    FCB     6              ; Frame 37 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $2C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $09             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FE             ; Reg 7 value
    FCB     63              ; Delay 63 frames (maintain previous state)
    FCB     5              ; Frame 100 - 5 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0C             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $DF             ; Reg 7 value
    FCB     100              ; Delay 100 frames (maintain previous state)
    FCB     7              ; Frame 200 - 7 register writes
    FCB     0               ; Reg 0 number
    FCB     $C8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $08             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0C             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $DE             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     6              ; Frame 206 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $C8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $08             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FE             ; Reg 7 value
    FCB     94              ; Delay 94 frames (maintain previous state)
    FCB     5              ; Frame 300 - 5 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0C             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $DF             ; Reg 7 value
    FCB     100              ; Delay 100 frames (maintain previous state)
    FCB     9              ; Frame 400 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $09             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $06             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0C             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $DC             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     8              ; Frame 406 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $09             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $21             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $03             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $06             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FC             ; Reg 7 value
    FCB     31              ; Delay 31 frames (maintain previous state)
    FCB     6              ; Frame 437 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $FC             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $09             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FE             ; Reg 7 value
    FCB     62              ; Delay 62 frames (maintain previous state)
    FCB     5              ; Frame 499 - 5 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0C             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $DF             ; Reg 7 value
    FCB     101              ; Delay 101 frames (maintain previous state)
    FCB     7              ; Frame 600 - 7 register writes
    FCB     0               ; Reg 0 number
    FCB     $0B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $08             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0C             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $DE             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     6              ; Frame 606 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $0B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $08             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FE             ; Reg 7 value
    FCB     94              ; Delay 94 frames (maintain previous state)
    FCB     5              ; Frame 700 - 5 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0C             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $08             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $DF             ; Reg 7 value
    FCB     100              ; Delay 100 frames before loop
    FCB     $FF             ; Loop command ($FF never valid as count)
    FDB     _EXPLORATION_MUSIC       ; Jump to start (absolute address)


; ========================================
; SFX Asset: puzzle_fail (from /Users/daniel/projects/vectrex-pseudo-python/examples/clockmakers_crypt/assets/sfx/puzzle_fail.vsfx)
; ========================================
_PUZZLE_FAIL_SFX:
    ; SFX: puzzle_fail (hit)
    ; Duration: 150ms (7fr), Freq: 196Hz, Channel: 0
    FCB $6E         ; Frame 0 - flags (vol=14, noisevol=11, tone=Y, noise=Y)
    FCB $01, $3B  ; Tone period = 315 (big-endian)
    FCB $12         ; Noise period
    FCB $69         ; Frame 1 - flags (vol=9, noisevol=9, tone=Y, noise=Y)
    FCB $01, $51  ; Tone period = 337 (big-endian)
    FCB $12         ; Noise period
    FCB $67         ; Frame 2 - flags (vol=7, noisevol=7, tone=Y, noise=Y)
    FCB $01, $68  ; Tone period = 360 (big-endian)
    FCB $12         ; Noise period
    FCB $65         ; Frame 3 - flags (vol=5, noisevol=4, tone=Y, noise=Y)
    FCB $01, $7E  ; Tone period = 382 (big-endian)
    FCB $12         ; Noise period
    FCB $65         ; Frame 4 - flags (vol=5, noisevol=2, tone=Y, noise=Y)
    FCB $01, $95  ; Tone period = 405 (big-endian)
    FCB $12         ; Noise period
    FCB $A5         ; Frame 5 - flags (vol=5, noisevol=0, tone=Y, noise=N)
    FCB $01, $AB  ; Tone period = 427 (big-endian)
    FCB $A2         ; Frame 6 - flags (vol=2, noisevol=0, tone=Y, noise=N)
    FCB $01, $C2  ; Tone period = 450 (big-endian)
    FCB $D0, $20    ; End of effect marker


; ========================================
; SFX Asset: door_unlock (from /Users/daniel/projects/vectrex-pseudo-python/examples/clockmakers_crypt/assets/sfx/door_unlock.vsfx)
; ========================================
_DOOR_UNLOCK_SFX:
    ; SFX: door_unlock (custom)
    ; Duration: 400ms (20fr), Freq: 330Hz, Channel: 0
    FCB $6E         ; Frame 0 - flags (vol=14, noisevol=8, tone=Y, noise=Y)
    FCB $00, $6A  ; Tone period = 106 (big-endian)
    FCB $06         ; Noise period
    FCB $6A         ; Frame 1 - flags (vol=10, noisevol=7, tone=Y, noise=Y)
    FCB $00, $88  ; Tone period = 136 (big-endian)
    FCB $06         ; Noise period
    FCB $66         ; Frame 2 - flags (vol=6, noisevol=6, tone=Y, noise=Y)
    FCB $00, $A5  ; Tone period = 165 (big-endian)
    FCB $06         ; Noise period
    FCB $66         ; Frame 3 - flags (vol=6, noisevol=5, tone=Y, noise=Y)
    FCB $00, $C3  ; Tone period = 195 (big-endian)
    FCB $06         ; Noise period
    FCB $66         ; Frame 4 - flags (vol=6, noisevol=4, tone=Y, noise=Y)
    FCB $00, $E0  ; Tone period = 224 (big-endian)
    FCB $06         ; Noise period
    FCB $66         ; Frame 5 - flags (vol=6, noisevol=4, tone=Y, noise=Y)
    FCB $00, $FE  ; Tone period = 254 (big-endian)
    FCB $06         ; Noise period
    FCB $66         ; Frame 6 - flags (vol=6, noisevol=3, tone=Y, noise=Y)
    FCB $01, $1B  ; Tone period = 283 (big-endian)
    FCB $06         ; Noise period
    FCB $66         ; Frame 7 - flags (vol=6, noisevol=2, tone=Y, noise=Y)
    FCB $01, $39  ; Tone period = 313 (big-endian)
    FCB $06         ; Noise period
    FCB $66         ; Frame 8 - flags (vol=6, noisevol=1, tone=Y, noise=Y)
    FCB $01, $56  ; Tone period = 342 (big-endian)
    FCB $06         ; Noise period
    FCB $A6         ; Frame 9 - flags (vol=6, noisevol=0, tone=Y, noise=N)
    FCB $01, $74  ; Tone period = 372 (big-endian)
    FCB $A6         ; Frame 10 - flags (vol=6, noisevol=0, tone=Y, noise=N)
    FCB $01, $91  ; Tone period = 401 (big-endian)
    FCB $A6         ; Frame 11 - flags (vol=6, noisevol=0, tone=Y, noise=N)
    FCB $01, $AF  ; Tone period = 431 (big-endian)
    FCB $A6         ; Frame 12 - flags (vol=6, noisevol=0, tone=Y, noise=N)
    FCB $01, $CC  ; Tone period = 460 (big-endian)
    FCB $A6         ; Frame 13 - flags (vol=6, noisevol=0, tone=Y, noise=N)
    FCB $01, $EA  ; Tone period = 490 (big-endian)
    FCB $A6         ; Frame 14 - flags (vol=6, noisevol=0, tone=Y, noise=N)
    FCB $02, $07  ; Tone period = 519 (big-endian)
    FCB $A5         ; Frame 15 - flags (vol=5, noisevol=0, tone=Y, noise=N)
    FCB $02, $25  ; Tone period = 549 (big-endian)
    FCB $A3         ; Frame 16 - flags (vol=3, noisevol=0, tone=Y, noise=N)
    FCB $02, $42  ; Tone period = 578 (big-endian)
    FCB $A3         ; Frame 17 - flags (vol=3, noisevol=0, tone=Y, noise=N)
    FCB $02, $60  ; Tone period = 608 (big-endian)
    FCB $A1         ; Frame 18 - flags (vol=1, noisevol=0, tone=Y, noise=N)
    FCB $02, $7D  ; Tone period = 637 (big-endian)
    FCB $A1         ; Frame 19 - flags (vol=1, noisevol=0, tone=Y, noise=N)
    FCB $02, $9B  ; Tone period = 667 (big-endian)
    FCB $D0, $20    ; End of effect marker


; Level Asset: entrance (from /Users/daniel/projects/vectrex-pseudo-python/examples/clockmakers_crypt/assets/playground/entrance.vplay)
; ==== Level: ENTRANCE ====
; Author: 
; Difficulty: medium

_ENTRANCE_LEVEL:
    FDB -96  ; World bounds: xMin (16-bit signed)
    FDB 95  ; xMax (16-bit signed)
    FDB -128  ; yMin (16-bit signed)
    FDB 127  ; yMax (16-bit signed)
    FDB 0  ; Time limit (seconds)
    FDB 0  ; Target score
    FCB 1  ; Background object count
    FCB 2  ; Gameplay object count
    FCB 0  ; Foreground object count
    FDB _ENTRANCE_BG_OBJECTS
    FDB _ENTRANCE_GAMEPLAY_OBJECTS
    FDB _ENTRANCE_FG_OBJECTS

_ENTRANCE_BG_OBJECTS:
; Object: obj_bg_entrance (background)
    FCB 4  ; type
    FDB 0  ; x
    FDB 0  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _ENTRANCE_BG_VECTORS  ; vector_ptr
    FDB 0  ; properties_ptr (reserved)


_ENTRANCE_GAMEPLAY_OBJECTS:
; Object: obj_painting (background)
    FCB 4  ; type
    FDB 55  ; x
    FDB 15  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _PAINTING_VECTORS  ; vector_ptr
    FDB 0  ; properties_ptr (reserved)

; Object: obj_door_locked (obstacle)
    FCB 2  ; type
    FDB -65  ; x
    FDB -10  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _DOOR_LOCKED_VECTORS  ; vector_ptr
    FDB 0  ; properties_ptr (reserved)


_ENTRANCE_FG_OBJECTS:


; VPy_LINE:32
; Const array literal for 'ENT_HS_X' (2 elements)
CONST_ARRAY_0:
    FDB 55   ; Element 0
    FDB -65   ; Element 1

; VPy_LINE:33
; Const array literal for 'ENT_HS_Y' (2 elements)
CONST_ARRAY_1:
    FDB 15   ; Element 0
    FDB -10   ; Element 1

; VPy_LINE:34
; Const array literal for 'ENT_HS_W' (2 elements)
CONST_ARRAY_2:
    FDB 18   ; Element 0
    FDB 12   ; Element 1

; VPy_LINE:35
; Const array literal for 'ENT_HS_H' (2 elements)
CONST_ARRAY_3:
    FDB 22   ; Element 0
    FDB 35   ; Element 1

; String literals (classic FCC + $80 terminator)
STR_0:
    FCC "4 DIGIT WHEELS."
    FCB $80
STR_1:
    FCC "A COMBINATION LOCK."
    FCB $80
STR_2:
    FCC "A DATE... A CODE?"
    FCB $80
STR_3:
    FCC "BUTTON 1 : INTERACT"
    FCB $80
STR_4:
    FCC "BUTTON 2 : INVENTORY"
    FCB $80
STR_5:
    FCC "BUTTON 3 : CHANGE VERB"
    FCB $80
STR_6:
    FCC "ESCAPE THE CRYPT."
    FCB $80
STR_7:
    FCC "EXAMINE"
    FCB $80
STR_8:
    FCC "EXAMINE PAINTING"
    FCB $80
STR_9:
    FCC "FIND THE CLUES."
    FCB $80
STR_10:
    FCC "GEARS TURN BY THEMSELVES."
    FCB $80
STR_11:
    FCC "HAS A CLOCKWORK LOCK."
    FCB $80
STR_12:
    FCC "JOYSTICK : MOVE"
    FCB $80
STR_13:
    FCC "KONRAD VOSS IS DEAD."
    FCB $80
STR_14:
    FCC "PRESS BUTTON 1"
    FCB $80
STR_15:
    FCC "PUSH BUTTON 1 TO START"
    FCB $80
STR_16:
    FCC "SOLVE THE PUZZLES."
    FCB $80
STR_17:
    FCC "SWITZERLAND, 1887."
    FCB $80
STR_18:
    FCC "TAKE"
    FCB $80
STR_19:
    FCC "THE CLOCKMAKER'S CRYPT"
    FCB $80
STR_20:
    FCC "THE COMBINATION."
    FCB $80
STR_21:
    FCC "THE DOOR CLICKS OPEN."
    FCB $80
STR_22:
    FCC "THE DOOR CLOSES BEHIND"
    FCB $80
STR_23:
    FCC "THE ECCENTRIC CLOCKMAKER"
    FCB $80
STR_24:
    FCC "THE MUNICIPALITY SENDS"
    FCB $80
STR_25:
    FCC "THE PORTRAIT SHOWS"
    FCB $80
STR_26:
    FCC "THE SARCOPHAGUS BELOW"
    FCB $80
STR_27:
    FCC "TO BE CONTINUED..."
    FCB $80
STR_28:
    FCC "TO INVENTORY HIS ESTATE."
    FCB $80
STR_29:
    FCC "USE"
    FCB $80
STR_30:
    FCC "VOSS IN 1887."
    FCB $80
STR_31:
    FCC "WORKSHOP DOOR"
    FCB $80
STR_32:
    FCC "YOU AS ASSESSOR"
    FCB $80
STR_33:
    FCC "YOU CANNOT DO THAT."
    FCB $80
STR_34:
    FCC "YOU ENTER THE CRYPT."
    FCB $80
STR_35:
    FCC "YOU NEED TO FIND"
    FCB $80
STR_36:
    FCC "YOU TRY:  1 - 8 - 8 - 7"
    FCB $80
STR_37:
    FCC "YOU. ALONE."
    FCB $80
