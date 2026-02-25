; --- Motorola 6809 backend (Vectrex) title='PANG' origin=$0000 ---
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
    FCC "PANG"
    FCB $80
    FCB 0

;***************************************************************************
; CODE SECTION
;***************************************************************************

; === RAM VARIABLE DEFINITIONS (EQU) ===
; AUTO-GENERATED - All offsets calculated automatically
; Total RAM used: 303 bytes
RESULT               EQU $C880+$00   ; Main result temporary (2 bytes)
TMPLEFT              EQU $C880+$02   ; Left operand temp (2 bytes)
TMPLEFT2             EQU $C880+$04   ; Left operand temp 2 (for nested operations) (2 bytes)
TMPRIGHT             EQU $C880+$06   ; Right operand temp (2 bytes)
TMPRIGHT2            EQU $C880+$08   ; Right operand temp 2 (for nested operations) (2 bytes)
TMPPTR               EQU $C880+$0A   ; Pointer temp (used by DRAW_VECTOR, arrays, structs) (2 bytes)
TMPPTR2              EQU $C880+$0C   ; Pointer temp 2 (for nested array operations) (2 bytes)
MUL_A                EQU $C880+$0E   ; Multiplicand A (2 bytes)
MUL_B                EQU $C880+$10   ; Multiplicand B (2 bytes)
MUL_RES              EQU $C880+$12   ; Multiply result (2 bytes)
MUL_TMP              EQU $C880+$14   ; Multiply temporary (2 bytes)
MUL_CNT              EQU $C880+$16   ; Multiply counter (2 bytes)
DIV_A                EQU $C880+$18   ; Dividend (2 bytes)
DIV_B                EQU $C880+$1A   ; Divisor (2 bytes)
DIV_Q                EQU $C880+$1C   ; Quotient (2 bytes)
DIV_R                EQU $C880+$1E   ; Remainder (2 bytes)
TEMP_YX              EQU $C880+$20   ; Temporary y,x storage (2 bytes)
TEMP_X               EQU $C880+$22   ; Temporary x storage (1 bytes)
TEMP_Y               EQU $C880+$23   ; Temporary y storage (1 bytes)
PSG_MUSIC_PTR        EQU $C880+$24   ; Current music position pointer (2 bytes)
PSG_MUSIC_START      EQU $C880+$26   ; Music start pointer (for loops) (2 bytes)
PSG_IS_PLAYING       EQU $C880+$28   ; Playing flag ($00=stopped, $01=playing) (1 bytes)
PSG_MUSIC_ACTIVE     EQU $C880+$29   ; Set during UPDATE_MUSIC_PSG (1 bytes)
PSG_FRAME_COUNT      EQU $C880+$2A   ; Frame register write count (1 bytes)
PSG_DELAY_FRAMES     EQU $C880+$2B   ; Frames to wait before next read (1 bytes)
SFX_PTR              EQU $C880+$2C   ; Current SFX data pointer (2 bytes)
SFX_TICK             EQU $C880+$2E   ; Current frame counter (2 bytes)
SFX_ACTIVE           EQU $C880+$30   ; Playback state ($00=stopped, $01=playing) (1 bytes)
SFX_PHASE            EQU $C880+$31   ; Envelope phase (0=A,1=D,2=S,3=R) (1 bytes)
SFX_VOL              EQU $C880+$32   ; Current volume level (0-15) (1 bytes)
NUM_STR              EQU $C880+$33   ; String buffer for PRINT_NUMBER (2 bytes)
DRAW_VEC_X           EQU $C880+$35   ; X position offset for vector drawing (1 bytes)
DRAW_VEC_Y           EQU $C880+$36   ; Y position offset for vector drawing (1 bytes)
MIRROR_X             EQU $C880+$37   ; X-axis mirror flag (0=normal, 1=flip) (1 bytes)
MIRROR_Y             EQU $C880+$38   ; Y-axis mirror flag (0=normal, 1=flip) (1 bytes)
DRAW_VEC_INTENSITY   EQU $C880+$39   ; Intensity override (0=use vector's, >0=override) (1 bytes)
LEVEL_PTR            EQU $C880+$3A   ; Pointer to currently loaded level data (2 bytes)
LEVEL_BG_COUNT       EQU $C880+$3C   ; SHOW_LEVEL: background object count (1 bytes)
LEVEL_GP_COUNT       EQU $C880+$3D   ; SHOW_LEVEL: gameplay object count (1 bytes)
LEVEL_FG_COUNT       EQU $C880+$3E   ; SHOW_LEVEL: foreground object count (1 bytes)
LEVEL_BG_PTR         EQU $C880+$3F   ; SHOW_LEVEL: background objects pointer (RAM buffer) (2 bytes)
LEVEL_GP_PTR         EQU $C880+$41   ; SHOW_LEVEL: gameplay objects pointer (RAM buffer) (2 bytes)
LEVEL_FG_PTR         EQU $C880+$43   ; SHOW_LEVEL: foreground objects pointer (RAM buffer) (2 bytes)
LEVEL_BG_ROM_PTR     EQU $C880+$45   ; LOAD_LEVEL: background objects pointer (ROM) (2 bytes)
LEVEL_GP_ROM_PTR     EQU $C880+$47   ; LOAD_LEVEL: gameplay objects pointer (ROM) (2 bytes)
LEVEL_FG_ROM_PTR     EQU $C880+$49   ; LOAD_LEVEL: foreground objects pointer (ROM) (2 bytes)
LEVEL_GP_BUFFER      EQU $C880+$4B   ; Gameplay objects buffer (max 2 objects × 14 bytes, auto-sized) (28 bytes)
UGPC_OUTER_IDX       EQU $C880+$67   ; Outer loop index for collision detection (1 bytes)
UGPC_OUTER_MAX       EQU $C880+$68   ; Outer loop max value (count-1) (1 bytes)
UGPC_INNER_IDX       EQU $C880+$69   ; Inner loop index for collision detection (1 bytes)
UGPC_DX              EQU $C880+$6A   ; Distance X temporary (16-bit) (2 bytes)
UGPC_DIST            EQU $C880+$6C   ; Manhattan distance temporary (16-bit) (2 bytes)
VLINE_DX_16          EQU $C880+$6E   ; x1-x0 (16-bit) for line drawing (2 bytes)
VLINE_DY_16          EQU $C880+$70   ; y1-y0 (16-bit) for line drawing (2 bytes)
VLINE_DX             EQU $C880+$72   ; Clamped dx (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$73   ; Clamped dy (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$74   ; Remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$76   ; Remaining dx for segment 2 (16-bit) (2 bytes)
VLINE_STEPS          EQU $C880+$78   ; Line drawing step counter (1 bytes)
VLINE_LIST           EQU $C880+$79   ; 2-byte vector list (Y|endbit, X) (2 bytes)
VAR_SCREEN           EQU $C880+$7B   ; User variable (2 bytes)
VAR_TITLE_INTENSITY  EQU $C880+$7D   ; User variable (2 bytes)
VAR_TITLE_STATE      EQU $C880+$7F   ; User variable (2 bytes)
VAR_CURRENT_MUSIC    EQU $C880+$81   ; User variable (2 bytes)
VAR_JOYSTICK1_STATE_DATA EQU $C880+$83   ; Array data (6 elements) (12 bytes)
VAR_PREV_BTN1        EQU $C880+$8F   ; User variable (2 bytes)
VAR_PREV_BTN2        EQU $C880+$91   ; User variable (2 bytes)
VAR_PREV_BTN3        EQU $C880+$93   ; User variable (2 bytes)
VAR_PREV_BTN4        EQU $C880+$95   ; User variable (2 bytes)
VAR_CURRENT_LOCATION EQU $C880+$97   ; User variable (2 bytes)
VAR_LOCATION_GLOW_INTENSITY EQU $C880+$99   ; User variable (2 bytes)
VAR_LOCATION_GLOW_DIRECTION EQU $C880+$9B   ; User variable (2 bytes)
VAR_JOY_X            EQU $C880+$9D   ; User variable (2 bytes)
VAR_JOY_Y            EQU $C880+$9F   ; User variable (2 bytes)
VAR_PREV_JOY_X       EQU $C880+$A1   ; User variable (2 bytes)
VAR_PREV_JOY_Y       EQU $C880+$A3   ; User variable (2 bytes)
VAR_COUNTDOWN_TIMER  EQU $C880+$A5   ; User variable (2 bytes)
VAR_COUNTDOWN_ACTIVE EQU $C880+$A7   ; User variable (2 bytes)
VAR_JOYSTICK_POLL_COUNTER EQU $C880+$A9   ; User variable (2 bytes)
VAR_HOOK_ACTIVE      EQU $C880+$AB   ; User variable (2 bytes)
VAR_HOOK_X           EQU $C880+$AD   ; User variable (2 bytes)
VAR_HOOK_Y           EQU $C880+$AF   ; User variable (2 bytes)
VAR_HOOK_GUN_X       EQU $C880+$B1   ; User variable (2 bytes)
VAR_HOOK_GUN_Y       EQU $C880+$B3   ; User variable (2 bytes)
VAR_HOOK_INIT_Y      EQU $C880+$B5   ; User variable (2 bytes)
VAR_PLAYER_X         EQU $C880+$B7   ; User variable (2 bytes)
VAR_MOVE_SPEED       EQU $C880+$B9   ; User variable (2 bytes)
VAR_ABS_JOY          EQU $C880+$BB   ; User variable (2 bytes)
VAR_PLAYER_ANIM_FRAME EQU $C880+$BD   ; User variable (2 bytes)
VAR_PLAYER_ANIM_COUNTER EQU $C880+$BF   ; User variable (2 bytes)
VAR_PLAYER_FACING    EQU $C880+$C1   ; User variable (2 bytes)
VAR_ENEMY_ACTIVE_DATA EQU $C880+$C3   ; Array data (8 elements) (16 bytes)
VAR_ENEMY_X_DATA     EQU $C880+$D3   ; Array data (8 elements) (16 bytes)
VAR_ENEMY_Y_DATA     EQU $C880+$E3   ; Array data (8 elements) (16 bytes)
VAR_ENEMY_VX_DATA    EQU $C880+$F3   ; Array data (8 elements) (16 bytes)
VAR_ENEMY_VY_DATA    EQU $C880+$103   ; Array data (8 elements) (16 bytes)
VAR_ENEMY_SIZE_DATA  EQU $C880+$113   ; Array data (8 elements) (16 bytes)
VAR_ARG0             EQU $C880+$123   ; Function argument 0 (2 bytes)
VAR_ARG1             EQU $C880+$125   ; Function argument 1 (2 bytes)
VAR_ARG2             EQU $C880+$127   ; Function argument 2 (2 bytes)
VAR_ARG3             EQU $C880+$129   ; Function argument 3 (2 bytes)
VAR_ARG4             EQU $C880+$12B   ; Function argument 4 (2 bytes)
VAR_ARG5             EQU $C880+$12D   ; Function argument 5 (2 bytes)
PSG_MUSIC_PTR_DP   EQU $24  ; DP-relative
PSG_MUSIC_START_DP EQU $26  ; DP-relative
PSG_IS_PLAYING_DP  EQU $28  ; DP-relative
PSG_MUSIC_ACTIVE_DP EQU $29  ; DP-relative
PSG_FRAME_COUNT_DP EQU $2A  ; DP-relative
PSG_DELAY_FRAMES_DP EQU $2B  ; DP-relative
SFX_PTR_DP         EQU $2C  ; DP-relative
SFX_TICK_DP        EQU $2E  ; DP-relative
SFX_ACTIVE_DP      EQU $30  ; DP-relative
SFX_PHASE_DP       EQU $31  ; DP-relative
SFX_VOL_DP         EQU $32  ; DP-relative

    JMP START

;**** CONST DECLARATIONS (NUMBER-ONLY) ****
; VPy_LINE:8
; _CONST_DECL_0:  ; const STATE_TITLE
; VPy_LINE:9
; _CONST_DECL_1:  ; const STATE_MAP
; VPy_LINE:10
; _CONST_DECL_2:  ; const STATE_GAME
; VPy_LINE:34
; _CONST_DECL_3:  ; const num_locations
; VPy_LINE:52
; _CONST_DECL_4:  ; const hook_max_y
; VPy_LINE:58
; _CONST_DECL_5:  ; const player_y
; VPy_LINE:63
; _CONST_DECL_6:  ; const player_anim_speed
; VPy_LINE:67
; _CONST_DECL_7:  ; const MAX_ENEMIES
; VPy_LINE:76
; _CONST_DECL_8:  ; const GRAVITY
; VPy_LINE:77
; _CONST_DECL_9:  ; const BOUNCE_DAMPING
; VPy_LINE:78
; _CONST_DECL_10:  ; const MIN_BOUNCE_VY
; VPy_LINE:79
; _CONST_DECL_11:  ; const GROUND_Y

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

VECTREX_PRINT_TEXT:
    ; CRITICAL: Print_Str_d requires DP=$D0 and signature is (Y, X, string)
    ; VPy signature: PRINT_TEXT(x, y, string) -> args (ARG0=x, ARG1=y, ARG2=string)
    ; BIOS signature: Print_Str_d(A=Y, B=X, U=string)
    ; CRITICAL: Set VIA to DAC mode BEFORE calling BIOS (don't assume state)
    LDA #$98       ; VIA_cntl = $98 (DAC mode for text rendering)
    STA >$D00C     ; VIA_cntl
    LDA #$D0
    TFR A,DP       ; Set Direct Page to $D0 for BIOS
    LDU VAR_ARG2   ; string pointer (ARG2 = third param)
    LDA VAR_ARG1+1 ; Y (ARG1 = second param)
    LDB VAR_ARG0+1 ; X (ARG0 = first param)
    JSR Print_Str_d
    JSR $F1AF      ; DP_to_C8 (restore before return - CRITICAL for TMPPTR access)
    RTS
; DRAW_LINE unified wrapper - handles 16-bit signed coordinates
; Args: (x0,y0,x1,y1,intensity) as 16-bit words
; ALWAYS sets intensity. Does NOT reset origin (allows connected lines).
DRAW_LINE_WRAPPER:
    ; CRITICAL: Set VIA to DAC mode BEFORE calling BIOS (don't assume state)
    LDA #$98       ; VIA_cntl = $98 (DAC mode for vector drawing)
    STA >$D00C     ; VIA_cntl
    ; Set DP to hardware registers
    LDA #$D0
    TFR A,DP
    ; ALWAYS set intensity (no optimization)
    LDA RESULT+8+1  ; intensity (low byte of 16-bit value)
    JSR Intensity_a
    ; Move to start ONCE (y in A, x in B) - use low bytes (8-bit signed -127..+127)
    LDA RESULT+2+1  ; Y start (low byte of 16-bit value)
    LDB RESULT+0+1  ; X start (low byte of 16-bit value)
    JSR Moveto_d
    ; Compute deltas using 16-bit arithmetic
    ; dx = x1 - x0 (treating as signed 16-bit)
    LDD RESULT+4    ; x1 (RESULT+4, 16-bit)
    SUBD RESULT+0   ; subtract x0 (RESULT+0, 16-bit)
    STD VLINE_DX_16 ; Store full 16-bit dx
    ; dy = y1 - y0 (treating as signed 16-bit)
    LDD RESULT+6    ; y1 (RESULT+6, 16-bit)
    SUBD RESULT+2   ; subtract y0 (RESULT+2, 16-bit)
    STD VLINE_DY_16 ; Store full 16-bit dy
    ; SEGMENT 1: Clamp dy to ±127 and draw
    LDD VLINE_DY_16 ; Load full dy
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
    LDA VLINE_DY_16+1  ; Use original low byte (already in valid range)
DLW_SEG1_DY_READY:
    STA VLINE_DY    ; Save clamped dy for segment 1
    ; Clamp dx to ±127
    LDD VLINE_DX_16
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
    LDB VLINE_DX_16+1  ; Use original low byte (already in valid range)
DLW_SEG1_DX_READY:
    STB VLINE_DX    ; Save clamped dx for segment 1
    ; Draw segment 1
    CLR Vec_Misc_Count
    LDA VLINE_DY
    LDB VLINE_DX
    JSR Draw_Line_d ; Beam moves automatically
    ; Check if we need SEGMENT 2 (dy outside ±127 range)
    LDD VLINE_DY_16 ; Reload original dy
    CMPD #127
    BGT DLW_NEED_SEG2  ; dy > 127: needs segment 2
    CMPD #-128
    BLT DLW_NEED_SEG2  ; dy < -128: needs segment 2
    BRA DLW_DONE       ; dy in range ±127: no segment 2
DLW_NEED_SEG2:
    ; SEGMENT 2: Draw remaining dy and dx
    ; Calculate remaining dy
    LDD VLINE_DY_16 ; Load original full dy
    CMPD #127
    BGT DLW_SEG2_DY_POS  ; dy > 127
    ; dy < -128, so we drew -128 in segment 1
    ; remaining = dy - (-128) = dy + 128
    ADDD #128       ; Add back the -128 we already drew
    BRA DLW_SEG2_DY_DONE
DLW_SEG2_DY_POS:
    ; dy > 127, so we drew 127 in segment 1
    ; remaining = dy - 127
    SUBD #127       ; Subtract 127 we already drew
DLW_SEG2_DY_DONE:
    STD VLINE_DY_REMAINING  ; Store remaining dy (16-bit)
    ; Calculate remaining dx
    LDD VLINE_DX_16 ; Load original full dx
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
    STD VLINE_DX_REMAINING  ; Store remaining dx (16-bit) in VLINE_DX_REMAINING
    ; Setup for Draw_Line_d: A=dy, B=dx (CRITICAL: order matters!)
    ; Load remaining dy from VLINE_DY_REMAINING (already saved)
    LDA VLINE_DY_REMAINING+1  ; Low byte of remaining dy
    LDB VLINE_DX_REMAINING+1  ; Low byte of remaining dx
    CLR Vec_Misc_Count
    JSR Draw_Line_d ; Beam continues from segment 1 endpoint
DLW_DONE:
    LDA #$C8       ; CRITICAL: Restore DP to $C8 for our code
    TFR A,DP
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
LDA #$82
STA VIA_port_b
NOP
NOP
NOP
NOP
NOP
LDA #$83
STA VIA_port_b
; Move sequence
LDD TEMP_YX             ; Recuperar y,x
STB VIA_port_a          ; y to DAC
PSHS A                  ; Save x
LDA #$CE
STA VIA_cntl
CLR VIA_port_b
LDA #1
STA VIA_port_b
PULS A                  ; Restore x
STA VIA_port_a          ; x to DAC
; Timing setup
LDA #$7F
STA VIA_t1_cnt_lo
CLR VIA_t1_cnt_hi
LEAX 2,X                ; Skip next_y, next_x
; Wait for move to complete
DSL_W1:
LDA VIA_int_flags
ANDA #$40
BEQ DSL_W1
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
PSHS A                  ; Save dx
STB VIA_port_a          ; dy to DAC
CLR VIA_port_b
LDA #1
STA VIA_port_b
PULS A                  ; Restore dx
STA VIA_port_a          ; dx to DAC
CLR VIA_t1_cnt_hi
LDA #$FF
STA VIA_shift_reg
; Wait for line draw
DSL_W2:
LDA VIA_int_flags
ANDA #$40
BEQ DSL_W2
CLR VIA_shift_reg
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
LDA #$82
STA VIA_port_b
NOP
NOP
NOP
NOP
NOP
LDA #$83
STA VIA_port_b
; Move to new start position
LDD TEMP_YX
STB VIA_port_a          ; y to DAC
PSHS A
LDA #$CE
STA VIA_cntl
CLR VIA_port_b
LDA #1
STA VIA_port_b
PULS A
STA VIA_port_a          ; x to DAC
LDA #$7F
STA VIA_t1_cnt_lo
CLR VIA_t1_cnt_hi
LEAX 2,X                ; Skip next_y, next_x
; Wait for move
DSL_W3:
LDA VIA_int_flags
ANDA #$40
BEQ DSL_W3
CLR VIA_shift_reg       ; Clear before continuing
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
LDA #$82
STA VIA_port_b
NOP
NOP
NOP
NOP
NOP
LDA #$83
STA VIA_port_b
; Move sequence
LDD TEMP_YX             ; Recuperar y,x ajustado
STB VIA_port_a          ; y to DAC
PSHS A                  ; Save x
LDA #$CE
STA VIA_cntl
CLR VIA_port_b
LDA #1
STA VIA_port_b
PULS A                  ; Restore x
STA VIA_port_a          ; x to DAC
; Timing setup
LDA #$7F
STA VIA_t1_cnt_lo
CLR VIA_t1_cnt_hi
LEAX 2,X                ; Skip next_y, next_x
; Wait for move to complete
DSLA_W1:
LDA VIA_int_flags
ANDA #$40
BEQ DSLA_W1
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
PSHS A                  ; Save dx
STB VIA_port_a          ; dy to DAC
CLR VIA_port_b
LDA #1
STA VIA_port_b
PULS A                  ; Restore dx
STA VIA_port_a          ; dx to DAC
CLR VIA_t1_cnt_hi
LDA #$FF
STA VIA_shift_reg
; Wait for line draw
DSLA_W2:
LDA VIA_int_flags
ANDA #$40
BEQ DSLA_W2
CLR VIA_shift_reg
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
LDA #$82
STA VIA_port_b
NOP
NOP
NOP
NOP
NOP
LDA #$83
STA VIA_port_b
; Move to new start position (already offset-adjusted)
LDD TEMP_YX
STB VIA_port_a
PSHS A
LDA #$CE
STA VIA_cntl
CLR VIA_port_b
LDA #1
STA VIA_port_b
PULS A
STA VIA_port_a
LDA #$7F
STA VIA_t1_cnt_lo
CLR VIA_t1_cnt_hi
LEAX 2,X
; Wait for move
DSLA_W3:
LDA VIA_int_flags
ANDA #$40
BEQ DSLA_W3
CLR VIA_shift_reg
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
LDA #$82
STA VIA_port_b
NOP
NOP
NOP
NOP
NOP
LDA #$83
STA VIA_port_b
; Move sequence
LDD TEMP_YX
STB VIA_port_a          ; y to DAC
PSHS A                  ; Save x
LDA #$CE
STA VIA_cntl
CLR VIA_port_b
LDA #1
STA VIA_port_b
PULS A                  ; Restore x
STA VIA_port_a          ; x to DAC
; Timing setup
LDA #$7F
STA VIA_t1_cnt_lo
CLR VIA_t1_cnt_hi
LEAX 2,X                ; Skip next_y, next_x
; Wait for move to complete
DSWM_W1:
LDA VIA_int_flags
ANDA #$40
BEQ DSWM_W1
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
PSHS A                  ; Save final dx
STB VIA_port_a          ; dy (possibly negated) to DAC
CLR VIA_port_b
LDA #1
STA VIA_port_b
PULS A                  ; Restore final dx
STA VIA_port_a          ; dx (possibly negated) to DAC
CLR VIA_t1_cnt_hi
LDA #$FF
STA VIA_shift_reg
; Wait for line draw
DSWM_W2:
LDA VIA_int_flags
ANDA #$40
BEQ DSWM_W2
CLR VIA_shift_reg
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
LDA #$82
STA VIA_port_b
NOP
NOP
NOP
NOP
NOP
LDA #$83
STA VIA_port_b
; Move to new start position
LDD TEMP_YX
STB VIA_port_a
PSHS A
LDA #$CE
STA VIA_cntl
CLR VIA_port_b
LDA #1
STA VIA_port_b
PULS A
STA VIA_port_a
LDA #$7F
STA VIA_t1_cnt_lo
CLR VIA_t1_cnt_hi
LEAX 2,X
; Wait for move
DSWM_W3:
LDA VIA_int_flags
ANDA #$40
BEQ DSWM_W3
CLR VIA_shift_reg
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
    
    ; Physics enabled → Copy GP objects to RAM buffer
    LDA #$FF         ; Empty marker
    LDU #LEVEL_GP_BUFFER
    LDB #16          ; 16 objects
LLR_CLR_GP_LOOP:
    STA ,U           ; Write 0xFF to type byte
    LEAU 14,U
    DECB
    BNE LLR_CLR_GP_LOOP
    
    LDB >LEVEL_GP_COUNT   ; Reload count
    LDX >LEVEL_GP_ROM_PTR ; X = source (ROM)
    LDU #LEVEL_GP_BUFFER ; U = destination (RAM)
    PSHS U              ; Save buffer start BEFORE copy
    JSR LLR_COPY_OBJECTS ; Copy B objects from X to U
    PULS D              ; Restore buffer start
    STD >LEVEL_GP_PTR    ; Store RAM buffer pointer
    BRA LLR_GP_DONE
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
    ; VPy_LINE:82
    ; VPy_LINE:12
    LDD #0
    STD RESULT
    STD VAR_SCREEN
    ; VPy_LINE:13
    LDD #30
    STD VAR_TITLE_INTENSITY
    ; VPy_LINE:14
    LDD #0
    STD VAR_TITLE_STATE
    ; VPy_LINE:15
    LDD #-1
    STD VAR_CURRENT_MUSIC
    ; VPy_LINE:28
    ; Copy array 'joystick1_state' from ROM to RAM (6 elements)
    LDX #ARRAY_0       ; Source: ROM array data
    LDU #VAR_JOYSTICK1_STATE_DATA ; Dest: RAM array space
    LDD #6        ; Number of elements
COPY_LOOP_0:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    BNE COPY_LOOP_0 ; Loop until done
    ; VPy_LINE:29
    LDD #0
    STD VAR_PREV_BTN1
    ; VPy_LINE:30
    LDD #0
    STD VAR_PREV_BTN2
    ; VPy_LINE:31
    LDD #0
    STD VAR_PREV_BTN3
    ; VPy_LINE:32
    LDD #0
    STD VAR_PREV_BTN4
    ; VPy_LINE:35
    LDD #0
    STD VAR_CURRENT_LOCATION
    ; VPy_LINE:36
    LDD #60
    STD VAR_LOCATION_GLOW_INTENSITY
    ; VPy_LINE:37
    LDD #0
    STD VAR_LOCATION_GLOW_DIRECTION
    ; VPy_LINE:38
    LDD #0
    STD VAR_JOY_X
    ; VPy_LINE:39
    LDD #0
    STD VAR_JOY_Y
    ; VPy_LINE:40
    LDD #0
    STD VAR_PREV_JOY_X
    ; VPy_LINE:41
    LDD #0
    STD VAR_PREV_JOY_Y
    ; VPy_LINE:44
    LDD #0
    STD VAR_COUNTDOWN_TIMER
    ; VPy_LINE:45
    LDD #0
    STD VAR_COUNTDOWN_ACTIVE
    ; VPy_LINE:46
    LDD #0
    STD VAR_JOYSTICK_POLL_COUNTER
    ; VPy_LINE:49
    LDD #0
    STD VAR_HOOK_ACTIVE
    ; VPy_LINE:50
    LDD #0
    STD VAR_HOOK_X
    ; VPy_LINE:51
    LDD #-70
    STD VAR_HOOK_Y
    ; VPy_LINE:53
    LDD #0
    STD VAR_HOOK_GUN_X
    ; VPy_LINE:54
    LDD #0
    STD VAR_HOOK_GUN_Y
    ; VPy_LINE:55
    LDD #0
    STD VAR_HOOK_INIT_Y
    ; VPy_LINE:57
    LDD #0
    STD VAR_PLAYER_X
    ; VPy_LINE:59
    LDD #0
    STD VAR_MOVE_SPEED
    ; VPy_LINE:60
    LDD #0
    STD VAR_ABS_JOY
    ; VPy_LINE:61
    LDD #1
    STD VAR_PLAYER_ANIM_FRAME
    ; VPy_LINE:62
    LDD #0
    STD VAR_PLAYER_ANIM_COUNTER
    ; VPy_LINE:64
    LDD #1
    STD VAR_PLAYER_FACING
    ; VPy_LINE:68
    ; Copy array 'enemy_active' from ROM to RAM (8 elements)
    LDX #ARRAY_1       ; Source: ROM array data
    LDU #VAR_ENEMY_ACTIVE_DATA ; Dest: RAM array space
    LDD #8        ; Number of elements
COPY_LOOP_1:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    BNE COPY_LOOP_1 ; Loop until done
    ; VPy_LINE:69
    ; Copy array 'enemy_x' from ROM to RAM (8 elements)
    LDX #ARRAY_2       ; Source: ROM array data
    LDU #VAR_ENEMY_X_DATA ; Dest: RAM array space
    LDD #8        ; Number of elements
COPY_LOOP_2:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    BNE COPY_LOOP_2 ; Loop until done
    ; VPy_LINE:70
    ; Copy array 'enemy_y' from ROM to RAM (8 elements)
    LDX #ARRAY_3       ; Source: ROM array data
    LDU #VAR_ENEMY_Y_DATA ; Dest: RAM array space
    LDD #8        ; Number of elements
COPY_LOOP_3:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    BNE COPY_LOOP_3 ; Loop until done
    ; VPy_LINE:71
    ; Copy array 'enemy_vx' from ROM to RAM (8 elements)
    LDX #ARRAY_4       ; Source: ROM array data
    LDU #VAR_ENEMY_VX_DATA ; Dest: RAM array space
    LDD #8        ; Number of elements
COPY_LOOP_4:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    BNE COPY_LOOP_4 ; Loop until done
    ; VPy_LINE:72
    ; Copy array 'enemy_vy' from ROM to RAM (8 elements)
    LDX #ARRAY_5       ; Source: ROM array data
    LDU #VAR_ENEMY_VY_DATA ; Dest: RAM array space
    LDD #8        ; Number of elements
COPY_LOOP_5:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    BNE COPY_LOOP_5 ; Loop until done
    ; VPy_LINE:73
    ; Copy array 'enemy_size' from ROM to RAM (8 elements)
    LDX #ARRAY_6       ; Source: ROM array data
    LDU #VAR_ENEMY_SIZE_DATA ; Dest: RAM array space
    LDD #8        ; Number of elements
COPY_LOOP_6:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    BNE COPY_LOOP_6 ; Loop until done
    ; VPy_LINE:86
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_CURRENT_LOCATION
    STU TMPPTR
    STX ,U
    ; VPy_LINE:87
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_PREV_JOY_X
    STU TMPPTR
    STX ,U
    ; VPy_LINE:88
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_PREV_JOY_Y
    STU TMPPTR
    STX ,U
    ; VPy_LINE:89
    LDD #80
    STD RESULT
    LDX RESULT
    LDU #VAR_LOCATION_GLOW_INTENSITY
    STU TMPPTR
    STX ,U
    ; VPy_LINE:90
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_LOCATION_GLOW_DIRECTION
    STU TMPPTR
    STX ,U
    ; VPy_LINE:91
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_SCREEN
    STU TMPPTR
    STX ,U
    ; VPy_LINE:94
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_COUNTDOWN_TIMER
    STU TMPPTR
    STX ,U
    ; VPy_LINE:95
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_COUNTDOWN_ACTIVE
    STU TMPPTR
    STX ,U
    ; VPy_LINE:98
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_HOOK_ACTIVE
    STU TMPPTR
    STX ,U
    ; VPy_LINE:99
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_HOOK_X
    STU TMPPTR
    STX ,U
    ; VPy_LINE:100
    LDD #-70
    STD RESULT
    LDX RESULT
    LDU #VAR_HOOK_Y
    STU TMPPTR
    STX ,U
    ; VPy_LINE:103
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_JOYSTICK_POLL_COUNTER
    STU TMPPTR
    STX ,U
    ; VPy_LINE:104
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_PREV_BTN1
    STU TMPPTR
    STX ,U
    ; VPy_LINE:105
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_PREV_BTN2
    STU TMPPTR
    STX ,U
    ; VPy_LINE:106
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_PREV_BTN3
    STU TMPPTR
    STX ,U
    ; VPy_LINE:107
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_PREV_BTN4
    STU TMPPTR
    STX ,U

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

STATE_TITLE EQU 0
STATE_MAP EQU 1
STATE_GAME EQU 2
NUM_LOCATIONS EQU 17
HOOK_MAX_Y EQU 127
PLAYER_Y EQU 65466
PLAYER_ANIM_SPEED EQU 5
MAX_ENEMIES EQU 8
GRAVITY EQU 1
BOUNCE_DAMPING EQU 17
MIN_BOUNCE_VY EQU 10
GROUND_Y EQU 65466
    ; VPy_LINE:109
LOOP_BODY:
    JSR Wait_Recal  ; CRITICAL: Sync with CRT refresh (50Hz frame timing)
    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access
    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)
    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access
    ; DEBUG: Statement 0 - Discriminant(8)
    ; VPy_LINE:111
    JSR READ_JOYSTICK1_STATE
    ; DEBUG: Statement 1 - Discriminant(9)
    ; VPy_LINE:113
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
    ; VPy_LINE:114
    LDD VAR_CURRENT_MUSIC
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_6
    LDD #0
    STD RESULT
    BRA CE_7
CT_6:
    LDD #1
    STD RESULT
CE_7:
    LDD RESULT
    LBEQ IF_NEXT_5
    ; VPy_LINE:115
; PLAY_MUSIC("pang_theme") - play music asset
    LDX #_PANG_THEME_MUSIC
    JSR PLAY_MUSIC_RUNTIME
    LDD #0
    STD RESULT
    ; VPy_LINE:116
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_CURRENT_MUSIC
    STU TMPPTR
    STX ,U
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    ; VPy_LINE:118
    JSR DRAW_TITLE_SCREEN
    ; VPy_LINE:121
    LDD #VAR_JOYSTICK1_STATE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD #2
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
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
    BEQ AND_FALSE_12
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
    BEQ CT_14
    LDD #0
    STD RESULT
    BRA CE_15
CT_14:
    LDD #1
    STD RESULT
CE_15:
    LDD RESULT
    BEQ AND_FALSE_12
    LDD #1
    STD RESULT
    BRA AND_END_13
AND_FALSE_12:
    LDD #0
    STD RESULT
AND_END_13:
    LDD RESULT
    LBEQ IF_NEXT_9
    ; VPy_LINE:122
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_SCREEN
    STU TMPPTR
    STX ,U
    ; VPy_LINE:123
    LDD #-1
    STD RESULT
    LDX RESULT
    LDU #VAR_CURRENT_MUSIC
    STU TMPPTR
    STX ,U
    LBRA IF_END_8
IF_NEXT_9:
    LDD #VAR_JOYSTICK1_STATE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD #3
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_17
    LDD #0
    STD RESULT
    BRA CE_18
CT_17:
    LDD #1
    STD RESULT
CE_18:
    LDD RESULT
    BEQ AND_FALSE_19
    LDD VAR_PREV_BTN2
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_21
    LDD #0
    STD RESULT
    BRA CE_22
CT_21:
    LDD #1
    STD RESULT
CE_22:
    LDD RESULT
    BEQ AND_FALSE_19
    LDD #1
    STD RESULT
    BRA AND_END_20
AND_FALSE_19:
    LDD #0
    STD RESULT
AND_END_20:
    LDD RESULT
    LBEQ IF_NEXT_16
    ; VPy_LINE:126
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_SCREEN
    STU TMPPTR
    STX ,U
    ; VPy_LINE:127
    LDD #-1
    STD RESULT
    LDX RESULT
    LDU #VAR_CURRENT_MUSIC
    STU TMPPTR
    STX ,U
    LBRA IF_END_8
IF_NEXT_16:
    LDD #VAR_JOYSTICK1_STATE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD #4
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_24
    LDD #0
    STD RESULT
    BRA CE_25
CT_24:
    LDD #1
    STD RESULT
CE_25:
    LDD RESULT
    BEQ AND_FALSE_26
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
    BEQ CT_28
    LDD #0
    STD RESULT
    BRA CE_29
CT_28:
    LDD #1
    STD RESULT
CE_29:
    LDD RESULT
    BEQ AND_FALSE_26
    LDD #1
    STD RESULT
    BRA AND_END_27
AND_FALSE_26:
    LDD #0
    STD RESULT
AND_END_27:
    LDD RESULT
    LBEQ IF_NEXT_23
    ; VPy_LINE:130
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_SCREEN
    STU TMPPTR
    STX ,U
    ; VPy_LINE:131
    LDD #-1
    STD RESULT
    LDX RESULT
    LDU #VAR_CURRENT_MUSIC
    STU TMPPTR
    STX ,U
    LBRA IF_END_8
IF_NEXT_23:
    LDD #VAR_JOYSTICK1_STATE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD #5
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
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
    BEQ AND_FALSE_32
    LDD VAR_PREV_BTN4
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
    BEQ AND_FALSE_32
    LDD #1
    STD RESULT
    BRA AND_END_33
AND_FALSE_32:
    LDD #0
    STD RESULT
AND_END_33:
    LDD RESULT
    LBEQ IF_END_8
    ; VPy_LINE:134
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_SCREEN
    STU TMPPTR
    STX ,U
    ; VPy_LINE:135
    LDD #-1
    STD RESULT
    LDX RESULT
    LDU #VAR_CURRENT_MUSIC
    STU TMPPTR
    STX ,U
    LBRA IF_END_8
IF_END_8:
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
    BEQ CT_37
    LDD #0
    STD RESULT
    BRA CE_38
CT_37:
    LDD #1
    STD RESULT
CE_38:
    LDD RESULT
    LBEQ IF_NEXT_36
    ; VPy_LINE:139
    LDD VAR_CURRENT_MUSIC
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BNE CT_41
    LDD #0
    STD RESULT
    BRA CE_42
CT_41:
    LDD #1
    STD RESULT
CE_42:
    LDD RESULT
    LBEQ IF_NEXT_40
    ; VPy_LINE:140
; PLAY_MUSIC("map_theme") - play music asset
    LDX #_MAP_THEME_MUSIC
    JSR PLAY_MUSIC_RUNTIME
    LDD #0
    STD RESULT
    ; VPy_LINE:141
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_CURRENT_MUSIC
    STU TMPPTR
    STX ,U
    LBRA IF_END_39
IF_NEXT_40:
IF_END_39:
    ; VPy_LINE:144
    LDD VAR_JOYSTICK_POLL_COUNTER
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
    LDU #VAR_JOYSTICK_POLL_COUNTER
    STU TMPPTR
    STX ,U
    ; VPy_LINE:145
    LDD VAR_JOYSTICK_POLL_COUNTER
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #15
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGE CT_45
    LDD #0
    STD RESULT
    BRA CE_46
CT_45:
    LDD #1
    STD RESULT
CE_46:
    LDD RESULT
    LBEQ IF_NEXT_44
    ; VPy_LINE:146
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_JOYSTICK_POLL_COUNTER
    STU TMPPTR
    STX ,U
    ; VPy_LINE:147
    LDD #VAR_JOYSTICK1_STATE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD #0
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX RESULT
    LDU #VAR_JOY_X
    STU TMPPTR
    STX ,U
    ; VPy_LINE:148
    LDD #VAR_JOYSTICK1_STATE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD #1
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX RESULT
    LDU #VAR_JOY_Y
    STU TMPPTR
    STX ,U
    LBRA IF_END_43
IF_NEXT_44:
IF_END_43:
    ; VPy_LINE:152
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #40
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_49
    LDD #0
    STD RESULT
    BRA CE_50
CT_49:
    LDD #1
    STD RESULT
CE_50:
    LDD RESULT
    BEQ AND_FALSE_51
    LDD VAR_PREV_JOY_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #40
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLE CT_53
    LDD #0
    STD RESULT
    BRA CE_54
CT_53:
    LDD #1
    STD RESULT
CE_54:
    LDD RESULT
    BEQ AND_FALSE_51
    LDD #1
    STD RESULT
    BRA AND_END_52
AND_FALSE_51:
    LDD #0
    STD RESULT
AND_END_52:
    LDD RESULT
    LBEQ IF_NEXT_48
    ; VPy_LINE:153
    LDD VAR_CURRENT_LOCATION
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
    LDU #VAR_CURRENT_LOCATION
    STU TMPPTR
    STX ,U
    ; VPy_LINE:154
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #17
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGE CT_57
    LDD #0
    STD RESULT
    BRA CE_58
CT_57:
    LDD #1
    STD RESULT
CE_58:
    LDD RESULT
    LBEQ IF_NEXT_56
    ; VPy_LINE:155
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_CURRENT_LOCATION
    STU TMPPTR
    STX ,U
    ; VPy_LINE:156
; LOAD_LEVEL("fuji_level1_v2") - load level data
    LDX #_FUJI_LEVEL1_V2_LEVEL
    JSR LOAD_LEVEL_RUNTIME
    LDD RESULT  ; Returns level pointer
    LBRA IF_END_55
IF_NEXT_56:
IF_END_55:
    LBRA IF_END_47
IF_NEXT_48:
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-40
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_60
    LDD #0
    STD RESULT
    BRA CE_61
CT_60:
    LDD #1
    STD RESULT
CE_61:
    LDD RESULT
    BEQ AND_FALSE_62
    LDD VAR_PREV_JOY_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-40
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGE CT_64
    LDD #0
    STD RESULT
    BRA CE_65
CT_64:
    LDD #1
    STD RESULT
CE_65:
    LDD RESULT
    BEQ AND_FALSE_62
    LDD #1
    STD RESULT
    BRA AND_END_63
AND_FALSE_62:
    LDD #0
    STD RESULT
AND_END_63:
    LDD RESULT
    LBEQ IF_NEXT_59
    ; VPy_LINE:158
    LDD VAR_CURRENT_LOCATION
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
    LDU #VAR_CURRENT_LOCATION
    STU TMPPTR
    STX ,U
    ; VPy_LINE:159
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_68
    LDD #0
    STD RESULT
    BRA CE_69
CT_68:
    LDD #1
    STD RESULT
CE_69:
    LDD RESULT
    LBEQ IF_NEXT_67
    ; VPy_LINE:160
    LDD #17
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
    LDU #VAR_CURRENT_LOCATION
    STU TMPPTR
    STX ,U
    LBRA IF_END_66
IF_NEXT_67:
IF_END_66:
    LBRA IF_END_47
IF_NEXT_59:
    LDD VAR_JOY_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #40
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_71
    LDD #0
    STD RESULT
    BRA CE_72
CT_71:
    LDD #1
    STD RESULT
CE_72:
    LDD RESULT
    BEQ AND_FALSE_73
    LDD VAR_PREV_JOY_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #40
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLE CT_75
    LDD #0
    STD RESULT
    BRA CE_76
CT_75:
    LDD #1
    STD RESULT
CE_76:
    LDD RESULT
    BEQ AND_FALSE_73
    LDD #1
    STD RESULT
    BRA AND_END_74
AND_FALSE_73:
    LDD #0
    STD RESULT
AND_END_74:
    LDD RESULT
    LBEQ IF_NEXT_70
    ; VPy_LINE:162
    LDD VAR_CURRENT_LOCATION
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
    LDU #VAR_CURRENT_LOCATION
    STU TMPPTR
    STX ,U
    ; VPy_LINE:163
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #17
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGE CT_79
    LDD #0
    STD RESULT
    BRA CE_80
CT_79:
    LDD #1
    STD RESULT
CE_80:
    LDD RESULT
    LBEQ IF_NEXT_78
    ; VPy_LINE:164
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_CURRENT_LOCATION
    STU TMPPTR
    STX ,U
    LBRA IF_END_77
IF_NEXT_78:
IF_END_77:
    LBRA IF_END_47
IF_NEXT_70:
    LDD VAR_JOY_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-40
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_81
    LDD #0
    STD RESULT
    BRA CE_82
CT_81:
    LDD #1
    STD RESULT
CE_82:
    LDD RESULT
    BEQ AND_FALSE_83
    LDD VAR_PREV_JOY_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-40
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGE CT_85
    LDD #0
    STD RESULT
    BRA CE_86
CT_85:
    LDD #1
    STD RESULT
CE_86:
    LDD RESULT
    BEQ AND_FALSE_83
    LDD #1
    STD RESULT
    BRA AND_END_84
AND_FALSE_83:
    LDD #0
    STD RESULT
AND_END_84:
    LDD RESULT
    LBEQ IF_END_47
    ; VPy_LINE:166
    LDD VAR_CURRENT_LOCATION
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
    LDU #VAR_CURRENT_LOCATION
    STU TMPPTR
    STX ,U
    ; VPy_LINE:167
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_89
    LDD #0
    STD RESULT
    BRA CE_90
CT_89:
    LDD #1
    STD RESULT
CE_90:
    LDD RESULT
    LBEQ IF_NEXT_88
    ; VPy_LINE:168
    LDD #17
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
    LDU #VAR_CURRENT_LOCATION
    STU TMPPTR
    STX ,U
    LBRA IF_END_87
IF_NEXT_88:
IF_END_87:
    LBRA IF_END_47
IF_END_47:
    ; VPy_LINE:170
    LDD VAR_JOY_X
    STD RESULT
    LDX RESULT
    LDU #VAR_PREV_JOY_X
    STU TMPPTR
    STX ,U
    ; VPy_LINE:171
    LDD VAR_JOY_Y
    STD RESULT
    LDX RESULT
    LDU #VAR_PREV_JOY_Y
    STU TMPPTR
    STX ,U
    ; VPy_LINE:174
    LDD #VAR_JOYSTICK1_STATE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD #2
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_93
    LDD #0
    STD RESULT
    BRA CE_94
CT_93:
    LDD #1
    STD RESULT
CE_94:
    LDD RESULT
    BEQ AND_FALSE_95
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
    BEQ CT_97
    LDD #0
    STD RESULT
    BRA CE_98
CT_97:
    LDD #1
    STD RESULT
CE_98:
    LDD RESULT
    BEQ AND_FALSE_95
    LDD #1
    STD RESULT
    BRA AND_END_96
AND_FALSE_95:
    LDD #0
    STD RESULT
AND_END_96:
    LDD RESULT
    LBEQ IF_NEXT_92
    ; VPy_LINE:175
    LDD #2
    STD RESULT
    LDX RESULT
    LDU #VAR_SCREEN
    STU TMPPTR
    STX ,U
    ; VPy_LINE:176
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_COUNTDOWN_ACTIVE
    STU TMPPTR
    STX ,U
    ; VPy_LINE:177
    LDD #180
    STD RESULT
    LDX RESULT
    LDU #VAR_COUNTDOWN_TIMER
    STU TMPPTR
    STX ,U
    LBRA IF_END_91
IF_NEXT_92:
    LDD #VAR_JOYSTICK1_STATE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD #3
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_100
    LDD #0
    STD RESULT
    BRA CE_101
CT_100:
    LDD #1
    STD RESULT
CE_101:
    LDD RESULT
    BEQ AND_FALSE_102
    LDD VAR_PREV_BTN2
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_104
    LDD #0
    STD RESULT
    BRA CE_105
CT_104:
    LDD #1
    STD RESULT
CE_105:
    LDD RESULT
    BEQ AND_FALSE_102
    LDD #1
    STD RESULT
    BRA AND_END_103
AND_FALSE_102:
    LDD #0
    STD RESULT
AND_END_103:
    LDD RESULT
    LBEQ IF_NEXT_99
    ; VPy_LINE:180
    LDD #2
    STD RESULT
    LDX RESULT
    LDU #VAR_SCREEN
    STU TMPPTR
    STX ,U
    ; VPy_LINE:181
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_COUNTDOWN_ACTIVE
    STU TMPPTR
    STX ,U
    ; VPy_LINE:182
    LDD #180
    STD RESULT
    LDX RESULT
    LDU #VAR_COUNTDOWN_TIMER
    STU TMPPTR
    STX ,U
    LBRA IF_END_91
IF_NEXT_99:
    LDD #VAR_JOYSTICK1_STATE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD #4
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
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
    BEQ AND_FALSE_109
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
    BEQ CT_111
    LDD #0
    STD RESULT
    BRA CE_112
CT_111:
    LDD #1
    STD RESULT
CE_112:
    LDD RESULT
    BEQ AND_FALSE_109
    LDD #1
    STD RESULT
    BRA AND_END_110
AND_FALSE_109:
    LDD #0
    STD RESULT
AND_END_110:
    LDD RESULT
    LBEQ IF_NEXT_106
    ; VPy_LINE:185
    LDD #2
    STD RESULT
    LDX RESULT
    LDU #VAR_SCREEN
    STU TMPPTR
    STX ,U
    ; VPy_LINE:186
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_COUNTDOWN_ACTIVE
    STU TMPPTR
    STX ,U
    ; VPy_LINE:187
    LDD #180
    STD RESULT
    LDX RESULT
    LDU #VAR_COUNTDOWN_TIMER
    STU TMPPTR
    STX ,U
    LBRA IF_END_91
IF_NEXT_106:
    LDD #VAR_JOYSTICK1_STATE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD #5
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_113
    LDD #0
    STD RESULT
    BRA CE_114
CT_113:
    LDD #1
    STD RESULT
CE_114:
    LDD RESULT
    BEQ AND_FALSE_115
    LDD VAR_PREV_BTN4
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_117
    LDD #0
    STD RESULT
    BRA CE_118
CT_117:
    LDD #1
    STD RESULT
CE_118:
    LDD RESULT
    BEQ AND_FALSE_115
    LDD #1
    STD RESULT
    BRA AND_END_116
AND_FALSE_115:
    LDD #0
    STD RESULT
AND_END_116:
    LDD RESULT
    LBEQ IF_END_91
    ; VPy_LINE:190
    LDD #2
    STD RESULT
    LDX RESULT
    LDU #VAR_SCREEN
    STU TMPPTR
    STX ,U
    ; VPy_LINE:191
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_COUNTDOWN_ACTIVE
    STU TMPPTR
    STX ,U
    ; VPy_LINE:192
    LDD #180
    STD RESULT
    LDX RESULT
    LDU #VAR_COUNTDOWN_TIMER
    STU TMPPTR
    STX ,U
    LBRA IF_END_91
IF_END_91:
    ; VPy_LINE:195
    JSR DRAW_MAP_SCREEN
    LBRA IF_END_0
IF_NEXT_36:
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
    BEQ CT_119
    LDD #0
    STD RESULT
    BRA CE_120
CT_119:
    LDD #1
    STD RESULT
CE_120:
    LDD RESULT
    LBEQ IF_END_0
    ; VPy_LINE:199
    LDD VAR_COUNTDOWN_ACTIVE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_123
    LDD #0
    STD RESULT
    BRA CE_124
CT_123:
    LDD #1
    STD RESULT
CE_124:
    LDD RESULT
    LBEQ IF_NEXT_122
    ; VPy_LINE:201
    JSR DRAW_LEVEL_BACKGROUND
    ; VPy_LINE:203
    LDD #127
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 203
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:204
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-50
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_7
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 204
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:207
    LDD #100
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 207
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:208
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-85
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-20
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    ; ===== Const array indexing: location_names =====
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDX #CONST_ARRAY_2
    LDD TMPPTR
    LEAX D,X
    ; String array - load pointer from table
    LDD ,X
    STD RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 208
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:211
    LDD VAR_COUNTDOWN_TIMER
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
    LDU #VAR_COUNTDOWN_TIMER
    STU TMPPTR
    STX ,U
    ; VPy_LINE:214
    LDD VAR_COUNTDOWN_TIMER
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLE CT_127
    LDD #0
    STD RESULT
    BRA CE_128
CT_127:
    LDD #1
    STD RESULT
CE_128:
    LDD RESULT
    LBEQ IF_NEXT_126
    ; VPy_LINE:215
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_COUNTDOWN_ACTIVE
    STU TMPPTR
    STX ,U
    ; VPy_LINE:216
    JSR SPAWN_ENEMIES
    LBRA IF_END_125
IF_NEXT_126:
IF_END_125:
    LBRA IF_END_121
IF_NEXT_122:
    ; VPy_LINE:221
    LDD VAR_HOOK_ACTIVE
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
    LDD #VAR_JOYSTICK1_STATE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD #2
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_141
    LDD #0
    STD RESULT
    BRA CE_142
CT_141:
    LDD #1
    STD RESULT
CE_142:
    LDD RESULT
    BNE OR_TRUE_139
    LDD #VAR_JOYSTICK1_STATE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD #3
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
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
    BNE OR_TRUE_139
    LDD #0
    STD RESULT
    BRA OR_END_140
OR_TRUE_139:
    LDD #1
    STD RESULT
OR_END_140:
    LDD RESULT
    BNE OR_TRUE_137
    LDD #VAR_JOYSTICK1_STATE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD #4
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_145
    LDD #0
    STD RESULT
    BRA CE_146
CT_145:
    LDD #1
    STD RESULT
CE_146:
    LDD RESULT
    BNE OR_TRUE_137
    LDD #0
    STD RESULT
    BRA OR_END_138
OR_TRUE_137:
    LDD #1
    STD RESULT
OR_END_138:
    LDD RESULT
    BNE OR_TRUE_135
    LDD #VAR_JOYSTICK1_STATE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD #5
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_147
    LDD #0
    STD RESULT
    BRA CE_148
CT_147:
    LDD #1
    STD RESULT
CE_148:
    LDD RESULT
    BNE OR_TRUE_135
    LDD #0
    STD RESULT
    BRA OR_END_136
OR_TRUE_135:
    LDD #1
    STD RESULT
OR_END_136:
    LDD RESULT
    LBEQ IF_NEXT_134
    ; VPy_LINE:223
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_HOOK_ACTIVE
    STU TMPPTR
    STX ,U
    ; VPy_LINE:224
    LDD #-70
    STD RESULT
    LDX RESULT
    LDU #VAR_HOOK_Y
    STU TMPPTR
    STX ,U
    ; VPy_LINE:228
    LDD VAR_PLAYER_X
    STD RESULT
    LDX RESULT
    LDU #VAR_HOOK_GUN_X
    STU TMPPTR
    STX ,U
    ; VPy_LINE:229
    LDD VAR_PLAYER_FACING
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_151
    LDD #0
    STD RESULT
    BRA CE_152
CT_151:
    LDD #1
    STD RESULT
CE_152:
    LDD RESULT
    LBEQ IF_NEXT_150
    ; VPy_LINE:230
    LDD VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #11
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_HOOK_GUN_X
    STU TMPPTR
    STX ,U
    LBRA IF_END_149
IF_NEXT_150:
    ; VPy_LINE:232
    LDD VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #11
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_HOOK_GUN_X
    STU TMPPTR
    STX ,U
IF_END_149:
    ; VPy_LINE:233
    LDD #-70
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
    LDU #VAR_HOOK_GUN_Y
    STU TMPPTR
    STX ,U
    ; VPy_LINE:234
    LDD VAR_HOOK_GUN_Y
    STD RESULT
    LDX RESULT
    LDU #VAR_HOOK_INIT_Y
    STU TMPPTR
    STX ,U
    ; VPy_LINE:237
    LDD VAR_HOOK_GUN_X
    STD RESULT
    LDX RESULT
    LDU #VAR_HOOK_X
    STU TMPPTR
    STX ,U
    LBRA IF_END_133
IF_NEXT_134:
IF_END_133:
    LBRA IF_END_129
IF_NEXT_130:
IF_END_129:
    ; VPy_LINE:240
    LDD VAR_HOOK_ACTIVE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_155
    LDD #0
    STD RESULT
    BRA CE_156
CT_155:
    LDD #1
    STD RESULT
CE_156:
    LDD RESULT
    LBEQ IF_NEXT_154
    ; VPy_LINE:241
    LDD VAR_HOOK_Y
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
    LDU #VAR_HOOK_Y
    STU TMPPTR
    STX ,U
    ; VPy_LINE:244
    LDD VAR_HOOK_Y
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #127
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGE CT_159
    LDD #0
    STD RESULT
    BRA CE_160
CT_159:
    LDD #1
    STD RESULT
CE_160:
    LDD RESULT
    LBEQ IF_NEXT_158
    ; VPy_LINE:245
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_HOOK_ACTIVE
    STU TMPPTR
    STX ,U
    ; VPy_LINE:246
    LDD #-70
    STD RESULT
    LDX RESULT
    LDU #VAR_HOOK_Y
    STU TMPPTR
    STX ,U
    LBRA IF_END_157
IF_NEXT_158:
IF_END_157:
    LBRA IF_END_153
IF_NEXT_154:
IF_END_153:
    ; VPy_LINE:248
    JSR DRAW_GAME_LEVEL
IF_END_121:
    LBRA IF_END_0
IF_END_0:
    ; DEBUG: Statement 2 - Discriminant(0)
    ; VPy_LINE:251
    LDD #VAR_JOYSTICK1_STATE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD #2
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX RESULT
    LDU #VAR_PREV_BTN1
    STU TMPPTR
    STX ,U
    ; DEBUG: Statement 3 - Discriminant(0)
    ; VPy_LINE:252
    LDD #VAR_JOYSTICK1_STATE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD #3
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX RESULT
    LDU #VAR_PREV_BTN2
    STU TMPPTR
    STX ,U
    ; DEBUG: Statement 4 - Discriminant(0)
    ; VPy_LINE:253
    LDD #VAR_JOYSTICK1_STATE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD #4
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX RESULT
    LDU #VAR_PREV_BTN3
    STU TMPPTR
    STX ,U
    ; DEBUG: Statement 5 - Discriminant(0)
    ; VPy_LINE:254
    LDD #VAR_JOYSTICK1_STATE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD #5
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX RESULT
    LDU #VAR_PREV_BTN4
    STU TMPPTR
    STX ,U
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX (after all game logic)
    RTS

    ; VPy_LINE:256
DRAW_MAP_SCREEN: ; function
; --- function draw_map_screen ---
    LEAS -4,S ; allocate locals
    ; VPy_LINE:258
    LDD #80
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 258
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:259
; DRAW_VECTOR_EX("map", x, y, mirror) - 15 path(s), width=242, center_x=-6
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD #20
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD #0
    STD RESULT
    LDB RESULT+1  ; Mirror mode (0=normal, 1=X, 2=Y, 3=both)
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    BNE DSVEX_CHK_Y_161
    LDA #1
    STA MIRROR_X
DSVEX_CHK_Y_161:
    CMPB #2       ; Check if Y-mirror (mode 2)
    BNE DSVEX_CHK_XY_162
    LDA #1
    STA MIRROR_Y
DSVEX_CHK_XY_162:
    CMPB #3       ; Check if both-mirror (mode 3)
    BNE DSVEX_CALL_163
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
DSVEX_CALL_163:
    ; Set intensity override for drawing
    LDD #50
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
    STA DRAW_VEC_INTENSITY  ; Store intensity override (function will use this)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_MAP_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_MAP_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_MAP_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_MAP_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_MAP_PATH4  ; Path 4
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_MAP_PATH5  ; Path 5
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_MAP_PATH6  ; Path 6
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_MAP_PATH7  ; Path 7
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_MAP_PATH8  ; Path 8
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_MAP_PATH9  ; Path 9
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_MAP_PATH10  ; Path 10
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_MAP_PATH11  ; Path 11
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_MAP_PATH12  ; Path 12
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_MAP_PATH13  ; Path 13
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_MAP_PATH14  ; Path 14
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    ; VPy_LINE:262
    LDD VAR_LOCATION_GLOW_DIRECTION
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
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
    ; VPy_LINE:263
    LDD VAR_LOCATION_GLOW_INTENSITY
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
    LDU #VAR_LOCATION_GLOW_INTENSITY
    STU TMPPTR
    STX ,U
    ; VPy_LINE:264
    LDD VAR_LOCATION_GLOW_INTENSITY
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #127
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGE CT_170
    LDD #0
    STD RESULT
    BRA CE_171
CT_170:
    LDD #1
    STD RESULT
CE_171:
    LDD RESULT
    LBEQ IF_NEXT_169
    ; VPy_LINE:265
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_LOCATION_GLOW_DIRECTION
    STU TMPPTR
    STX ,U
    LBRA IF_END_168
IF_NEXT_169:
IF_END_168:
    LBRA IF_END_164
IF_NEXT_165:
    ; VPy_LINE:267
    LDD VAR_LOCATION_GLOW_INTENSITY
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
    LDU #VAR_LOCATION_GLOW_INTENSITY
    STU TMPPTR
    STX ,U
    ; VPy_LINE:268
    LDD VAR_LOCATION_GLOW_INTENSITY
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #80
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLE CT_174
    LDD #0
    STD RESULT
    BRA CE_175
CT_174:
    LDD #1
    STD RESULT
CE_175:
    LDD RESULT
    LBEQ IF_NEXT_173
    ; VPy_LINE:269
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_LOCATION_GLOW_DIRECTION
    STU TMPPTR
    STX ,U
    LBRA IF_END_172
IF_NEXT_173:
IF_END_172:
IF_END_164:
    ; VPy_LINE:271
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-80
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    ; ===== Const array indexing: location_names =====
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDX #CONST_ARRAY_2
    LDD TMPPTR
    LEAX D,X
    ; String array - load pointer from table
    LDD ,X
    STD RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 271
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:274
    ; ===== Const array indexing: location_x_coords =====
    LDD VAR_CURRENT_LOCATION
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
    LDX RESULT
    STX 0 ,S
    ; VPy_LINE:275
    ; ===== Const array indexing: location_y_coords =====
    LDD VAR_CURRENT_LOCATION
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
    LDX RESULT
    STX 2 ,S
    ; VPy_LINE:277
; DRAW_VECTOR_EX("location_marker", x, y, mirror) - 1 path(s), width=22, center_x=0
    LDD 2 ,S
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD 0 ,S
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD #0
    STD RESULT
    LDB RESULT+1  ; Mirror mode (0=normal, 1=X, 2=Y, 3=both)
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    BNE DSVEX_CHK_Y_176
    LDA #1
    STA MIRROR_X
DSVEX_CHK_Y_176:
    CMPB #2       ; Check if Y-mirror (mode 2)
    BNE DSVEX_CHK_XY_177
    LDA #1
    STA MIRROR_Y
DSVEX_CHK_XY_177:
    CMPB #3       ; Check if both-mirror (mode 3)
    BNE DSVEX_CALL_178
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
DSVEX_CALL_178:
    ; Set intensity override for drawing
    LDD VAR_LOCATION_GLOW_INTENSITY
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
    STA DRAW_VEC_INTENSITY  ; Store intensity override (function will use this)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_LOCATION_MARKER_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    LEAS 4,S ; free locals
    RTS

    ; VPy_LINE:280
DRAW_TITLE_SCREEN: ; function
; --- function draw_title_screen ---
    ; VPy_LINE:282
    LDD #80
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 282
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:283
; DRAW_VECTOR("logo", x, y) - 7 path(s) at position
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #70
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
    LDX #_LOGO_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_LOGO_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_LOGO_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_LOGO_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_LOGO_PATH4  ; Path 4
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_LOGO_PATH5  ; Path 5
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_LOGO_PATH6  ; Path 6
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    ; VPy_LINE:285
    LDD VAR_TITLE_INTENSITY
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 285
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:286
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-90
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_16
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 286
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:287
; PRINT_TEXT(x, y, text) - uses BIOS defaults
    LDD #-50
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-20
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #STR_19
    STX RESULT
    LDD RESULT
    STD VAR_ARG2
; NATIVE_CALL: VECTREX_PRINT_TEXT at line 287
    JSR VECTREX_PRINT_TEXT
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:289
    LDD VAR_TITLE_STATE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_181
    LDD #0
    STD RESULT
    BRA CE_182
CT_181:
    LDD #1
    STD RESULT
CE_182:
    LDD RESULT
    LBEQ IF_NEXT_180
    ; VPy_LINE:290
    LDD VAR_TITLE_INTENSITY
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
    LDU #VAR_TITLE_INTENSITY
    STU TMPPTR
    STX ,U
    LBRA IF_END_179
IF_NEXT_180:
IF_END_179:
    ; VPy_LINE:292
    LDD VAR_TITLE_STATE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_185
    LDD #0
    STD RESULT
    BRA CE_186
CT_185:
    LDD #1
    STD RESULT
CE_186:
    LDD RESULT
    LBEQ IF_NEXT_184
    ; VPy_LINE:293
    LDD VAR_TITLE_INTENSITY
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
    LDU #VAR_TITLE_INTENSITY
    STU TMPPTR
    STX ,U
    LBRA IF_END_183
IF_NEXT_184:
IF_END_183:
    ; VPy_LINE:295
    LDD VAR_TITLE_INTENSITY
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #80
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_189
    LDD #0
    STD RESULT
    BRA CE_190
CT_189:
    LDD #1
    STD RESULT
CE_190:
    LDD RESULT
    LBEQ IF_NEXT_188
    ; VPy_LINE:296
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_TITLE_STATE
    STU TMPPTR
    STX ,U
    LBRA IF_END_187
IF_NEXT_188:
IF_END_187:
    ; VPy_LINE:298
    LDD VAR_TITLE_INTENSITY
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #30
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_193
    LDD #0
    STD RESULT
    BRA CE_194
CT_193:
    LDD #1
    STD RESULT
CE_194:
    LDD RESULT
    LBEQ IF_NEXT_192
    ; VPy_LINE:299
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_TITLE_STATE
    STU TMPPTR
    STX ,U
    LBRA IF_END_191
IF_NEXT_192:
IF_END_191:
    RTS

    ; VPy_LINE:301
DRAW_LEVEL_BACKGROUND: ; function
; --- function draw_level_background ---
    ; VPy_LINE:303
    LDD #60
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 303
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:306
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
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
    LBEQ IF_NEXT_196
    ; VPy_LINE:307
; DRAW_VECTOR("fuji_bg", x, y) - 6 path(s) at position
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
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
    LDX #_FUJI_BG_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_FUJI_BG_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_FUJI_BG_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_FUJI_BG_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_FUJI_BG_PATH4  ; Path 4
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_FUJI_BG_PATH5  ; Path 5
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_195
IF_NEXT_196:
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_200
    LDD #0
    STD RESULT
    BRA CE_201
CT_200:
    LDD #1
    STD RESULT
CE_201:
    LDD RESULT
    LBEQ IF_NEXT_199
    ; VPy_LINE:309
; DRAW_VECTOR("keirin_bg", x, y) - 3 path(s) at position
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
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
    LDX #_KEIRIN_BG_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_KEIRIN_BG_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_KEIRIN_BG_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_195
IF_NEXT_199:
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_203
    LDD #0
    STD RESULT
    BRA CE_204
CT_203:
    LDD #1
    STD RESULT
CE_204:
    LDD RESULT
    LBEQ IF_NEXT_202
    ; VPy_LINE:311
; DRAW_VECTOR("buddha_bg", x, y) - 4 path(s) at position
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
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
    LDX #_BUDDHA_BG_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BUDDHA_BG_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BUDDHA_BG_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BUDDHA_BG_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_195
IF_NEXT_202:
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_206
    LDD #0
    STD RESULT
    BRA CE_207
CT_206:
    LDD #1
    STD RESULT
CE_207:
    LDD RESULT
    LBEQ IF_NEXT_205
    ; VPy_LINE:313
; DRAW_VECTOR("angkor_bg", x, y) - 192 path(s) at position
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
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
    LDX #_ANGKOR_BG_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH4  ; Path 4
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH5  ; Path 5
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH6  ; Path 6
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH7  ; Path 7
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH8  ; Path 8
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH9  ; Path 9
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH10  ; Path 10
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH11  ; Path 11
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH12  ; Path 12
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH13  ; Path 13
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH14  ; Path 14
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH15  ; Path 15
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH16  ; Path 16
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH17  ; Path 17
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH18  ; Path 18
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH19  ; Path 19
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH20  ; Path 20
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH21  ; Path 21
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH22  ; Path 22
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH23  ; Path 23
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH24  ; Path 24
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH25  ; Path 25
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH26  ; Path 26
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH27  ; Path 27
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH28  ; Path 28
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH29  ; Path 29
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH30  ; Path 30
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH31  ; Path 31
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH32  ; Path 32
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH33  ; Path 33
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH34  ; Path 34
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH35  ; Path 35
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH36  ; Path 36
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH37  ; Path 37
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH38  ; Path 38
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH39  ; Path 39
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH40  ; Path 40
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH41  ; Path 41
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH42  ; Path 42
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH43  ; Path 43
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH44  ; Path 44
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH45  ; Path 45
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH46  ; Path 46
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH47  ; Path 47
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH48  ; Path 48
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH49  ; Path 49
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH50  ; Path 50
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH51  ; Path 51
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH52  ; Path 52
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH53  ; Path 53
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH54  ; Path 54
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH55  ; Path 55
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH56  ; Path 56
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH57  ; Path 57
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH58  ; Path 58
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH59  ; Path 59
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH60  ; Path 60
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH61  ; Path 61
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH62  ; Path 62
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH63  ; Path 63
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH64  ; Path 64
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH65  ; Path 65
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH66  ; Path 66
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH67  ; Path 67
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH68  ; Path 68
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH69  ; Path 69
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH70  ; Path 70
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH71  ; Path 71
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH72  ; Path 72
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH73  ; Path 73
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH74  ; Path 74
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH75  ; Path 75
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH76  ; Path 76
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH77  ; Path 77
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH78  ; Path 78
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH79  ; Path 79
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH80  ; Path 80
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH81  ; Path 81
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH82  ; Path 82
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH83  ; Path 83
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH84  ; Path 84
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH85  ; Path 85
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH86  ; Path 86
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH87  ; Path 87
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH88  ; Path 88
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH89  ; Path 89
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH90  ; Path 90
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH91  ; Path 91
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH92  ; Path 92
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH93  ; Path 93
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH94  ; Path 94
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH95  ; Path 95
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH96  ; Path 96
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH97  ; Path 97
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH98  ; Path 98
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH99  ; Path 99
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH100  ; Path 100
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH101  ; Path 101
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH102  ; Path 102
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH103  ; Path 103
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH104  ; Path 104
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH105  ; Path 105
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH106  ; Path 106
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH107  ; Path 107
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH108  ; Path 108
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH109  ; Path 109
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH110  ; Path 110
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH111  ; Path 111
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH112  ; Path 112
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH113  ; Path 113
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH114  ; Path 114
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH115  ; Path 115
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH116  ; Path 116
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH117  ; Path 117
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH118  ; Path 118
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH119  ; Path 119
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH120  ; Path 120
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH121  ; Path 121
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH122  ; Path 122
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH123  ; Path 123
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH124  ; Path 124
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH125  ; Path 125
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH126  ; Path 126
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH127  ; Path 127
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH128  ; Path 128
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH129  ; Path 129
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH130  ; Path 130
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH131  ; Path 131
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH132  ; Path 132
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH133  ; Path 133
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH134  ; Path 134
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH135  ; Path 135
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH136  ; Path 136
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH137  ; Path 137
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH138  ; Path 138
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH139  ; Path 139
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH140  ; Path 140
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH141  ; Path 141
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH142  ; Path 142
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH143  ; Path 143
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH144  ; Path 144
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH145  ; Path 145
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH146  ; Path 146
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH147  ; Path 147
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH148  ; Path 148
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH149  ; Path 149
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH150  ; Path 150
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH151  ; Path 151
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH152  ; Path 152
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH153  ; Path 153
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH154  ; Path 154
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH155  ; Path 155
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH156  ; Path 156
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH157  ; Path 157
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH158  ; Path 158
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH159  ; Path 159
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH160  ; Path 160
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH161  ; Path 161
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH162  ; Path 162
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH163  ; Path 163
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH164  ; Path 164
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH165  ; Path 165
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH166  ; Path 166
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH167  ; Path 167
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH168  ; Path 168
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH169  ; Path 169
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH170  ; Path 170
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH171  ; Path 171
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH172  ; Path 172
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH173  ; Path 173
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH174  ; Path 174
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH175  ; Path 175
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH176  ; Path 176
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH177  ; Path 177
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH178  ; Path 178
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH179  ; Path 179
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH180  ; Path 180
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH181  ; Path 181
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH182  ; Path 182
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH183  ; Path 183
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH184  ; Path 184
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH185  ; Path 185
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH186  ; Path 186
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH187  ; Path 187
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH188  ; Path 188
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH189  ; Path 189
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH190  ; Path 190
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANGKOR_BG_PATH191  ; Path 191
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_195
IF_NEXT_205:
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #4
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_209
    LDD #0
    STD RESULT
    BRA CE_210
CT_209:
    LDD #1
    STD RESULT
CE_210:
    LDD RESULT
    LBEQ IF_NEXT_208
    ; VPy_LINE:315
; DRAW_VECTOR("ayers_bg", x, y) - 18 path(s) at position
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
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
    LDX #_AYERS_BG_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_AYERS_BG_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_AYERS_BG_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_AYERS_BG_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_AYERS_BG_PATH4  ; Path 4
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_AYERS_BG_PATH5  ; Path 5
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_AYERS_BG_PATH6  ; Path 6
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_AYERS_BG_PATH7  ; Path 7
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_AYERS_BG_PATH8  ; Path 8
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_AYERS_BG_PATH9  ; Path 9
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_AYERS_BG_PATH10  ; Path 10
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_AYERS_BG_PATH11  ; Path 11
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_AYERS_BG_PATH12  ; Path 12
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_AYERS_BG_PATH13  ; Path 13
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_AYERS_BG_PATH14  ; Path 14
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_AYERS_BG_PATH15  ; Path 15
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_AYERS_BG_PATH16  ; Path 16
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_AYERS_BG_PATH17  ; Path 17
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_195
IF_NEXT_208:
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #5
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_212
    LDD #0
    STD RESULT
    BRA CE_213
CT_212:
    LDD #1
    STD RESULT
CE_213:
    LDD RESULT
    LBEQ IF_NEXT_211
    ; VPy_LINE:317
; DRAW_VECTOR("taj_bg", x, y) - 4 path(s) at position
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
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
    LDX #_TAJ_BG_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_TAJ_BG_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_TAJ_BG_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_TAJ_BG_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_195
IF_NEXT_211:
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #6
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_215
    LDD #0
    STD RESULT
    BRA CE_216
CT_215:
    LDD #1
    STD RESULT
CE_216:
    LDD RESULT
    LBEQ IF_NEXT_214
    ; VPy_LINE:319
; DRAW_VECTOR("leningrad_bg", x, y) - 5 path(s) at position
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
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
    LDX #_LENINGRAD_BG_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_LENINGRAD_BG_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_LENINGRAD_BG_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_LENINGRAD_BG_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_LENINGRAD_BG_PATH4  ; Path 4
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_195
IF_NEXT_214:
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #7
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_218
    LDD #0
    STD RESULT
    BRA CE_219
CT_218:
    LDD #1
    STD RESULT
CE_219:
    LDD RESULT
    LBEQ IF_NEXT_217
    ; VPy_LINE:321
; DRAW_VECTOR("paris_bg", x, y) - 5 path(s) at position
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
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
    LDX #_PARIS_BG_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_PARIS_BG_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_PARIS_BG_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_PARIS_BG_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_PARIS_BG_PATH4  ; Path 4
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_195
IF_NEXT_217:
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #8
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_221
    LDD #0
    STD RESULT
    BRA CE_222
CT_221:
    LDD #1
    STD RESULT
CE_222:
    LDD RESULT
    LBEQ IF_NEXT_220
    ; VPy_LINE:323
; DRAW_VECTOR("london_bg", x, y) - 4 path(s) at position
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
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
    LDX #_LONDON_BG_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_LONDON_BG_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_LONDON_BG_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_LONDON_BG_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_195
IF_NEXT_220:
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #9
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_224
    LDD #0
    STD RESULT
    BRA CE_225
CT_224:
    LDD #1
    STD RESULT
CE_225:
    LDD RESULT
    LBEQ IF_NEXT_223
    ; VPy_LINE:325
; DRAW_VECTOR("barcelona_bg", x, y) - 60 path(s) at position
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
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
    LDX #_BARCELONA_BG_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH4  ; Path 4
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH5  ; Path 5
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH6  ; Path 6
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH7  ; Path 7
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH8  ; Path 8
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH9  ; Path 9
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH10  ; Path 10
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH11  ; Path 11
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH12  ; Path 12
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH13  ; Path 13
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH14  ; Path 14
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH15  ; Path 15
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH16  ; Path 16
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH17  ; Path 17
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH18  ; Path 18
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH19  ; Path 19
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH20  ; Path 20
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH21  ; Path 21
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH22  ; Path 22
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH23  ; Path 23
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH24  ; Path 24
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH25  ; Path 25
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH26  ; Path 26
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH27  ; Path 27
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH28  ; Path 28
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH29  ; Path 29
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH30  ; Path 30
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH31  ; Path 31
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH32  ; Path 32
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH33  ; Path 33
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH34  ; Path 34
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH35  ; Path 35
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH36  ; Path 36
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH37  ; Path 37
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH38  ; Path 38
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH39  ; Path 39
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH40  ; Path 40
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH41  ; Path 41
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH42  ; Path 42
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH43  ; Path 43
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH44  ; Path 44
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH45  ; Path 45
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH46  ; Path 46
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH47  ; Path 47
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH48  ; Path 48
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH49  ; Path 49
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH50  ; Path 50
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH51  ; Path 51
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH52  ; Path 52
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH53  ; Path 53
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH54  ; Path 54
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH55  ; Path 55
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH56  ; Path 56
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH57  ; Path 57
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH58  ; Path 58
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_BARCELONA_BG_PATH59  ; Path 59
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_195
IF_NEXT_223:
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #10
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_227
    LDD #0
    STD RESULT
    BRA CE_228
CT_227:
    LDD #1
    STD RESULT
CE_228:
    LDD RESULT
    LBEQ IF_NEXT_226
    ; VPy_LINE:327
; DRAW_VECTOR("athens_bg", x, y) - 41 path(s) at position
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
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
    LDX #_ATHENS_BG_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH4  ; Path 4
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH5  ; Path 5
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH6  ; Path 6
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH7  ; Path 7
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH8  ; Path 8
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH9  ; Path 9
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH10  ; Path 10
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH11  ; Path 11
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH12  ; Path 12
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH13  ; Path 13
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH14  ; Path 14
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH15  ; Path 15
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH16  ; Path 16
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH17  ; Path 17
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH18  ; Path 18
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH19  ; Path 19
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH20  ; Path 20
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH21  ; Path 21
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH22  ; Path 22
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH23  ; Path 23
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH24  ; Path 24
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH25  ; Path 25
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH26  ; Path 26
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH27  ; Path 27
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH28  ; Path 28
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH29  ; Path 29
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH30  ; Path 30
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH31  ; Path 31
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH32  ; Path 32
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH33  ; Path 33
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH34  ; Path 34
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH35  ; Path 35
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH36  ; Path 36
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH37  ; Path 37
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH38  ; Path 38
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH39  ; Path 39
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ATHENS_BG_PATH40  ; Path 40
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_195
IF_NEXT_226:
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #11
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_230
    LDD #0
    STD RESULT
    BRA CE_231
CT_230:
    LDD #1
    STD RESULT
CE_231:
    LDD RESULT
    LBEQ IF_NEXT_229
    ; VPy_LINE:329
; DRAW_VECTOR("pyramids_bg", x, y) - 4 path(s) at position
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
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
    LDX #_PYRAMIDS_BG_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_PYRAMIDS_BG_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_PYRAMIDS_BG_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_PYRAMIDS_BG_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_195
IF_NEXT_229:
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #12
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_233
    LDD #0
    STD RESULT
    BRA CE_234
CT_233:
    LDD #1
    STD RESULT
CE_234:
    LDD RESULT
    LBEQ IF_NEXT_232
    ; VPy_LINE:331
; DRAW_VECTOR("kilimanjaro_bg", x, y) - 4 path(s) at position
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
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
    LDX #_KILIMANJARO_BG_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_KILIMANJARO_BG_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_KILIMANJARO_BG_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_KILIMANJARO_BG_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_195
IF_NEXT_232:
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #13
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_236
    LDD #0
    STD RESULT
    BRA CE_237
CT_236:
    LDD #1
    STD RESULT
CE_237:
    LDD RESULT
    LBEQ IF_NEXT_235
    ; VPy_LINE:333
; DRAW_VECTOR("newyork_bg", x, y) - 5 path(s) at position
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
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
    LDX #_NEWYORK_BG_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_NEWYORK_BG_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_NEWYORK_BG_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_NEWYORK_BG_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_NEWYORK_BG_PATH4  ; Path 4
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_195
IF_NEXT_235:
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #14
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_239
    LDD #0
    STD RESULT
    BRA CE_240
CT_239:
    LDD #1
    STD RESULT
CE_240:
    LDD RESULT
    LBEQ IF_NEXT_238
    ; VPy_LINE:335
; DRAW_VECTOR("mayan_bg", x, y) - 5 path(s) at position
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
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
    LDX #_MAYAN_BG_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_MAYAN_BG_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_MAYAN_BG_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_MAYAN_BG_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_MAYAN_BG_PATH4  ; Path 4
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_195
IF_NEXT_238:
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #15
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_242
    LDD #0
    STD RESULT
    BRA CE_243
CT_242:
    LDD #1
    STD RESULT
CE_243:
    LDD RESULT
    LBEQ IF_NEXT_241
    ; VPy_LINE:337
; DRAW_VECTOR("antarctica_bg", x, y) - 20 path(s) at position
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
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
    LDX #_ANTARCTICA_BG_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANTARCTICA_BG_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANTARCTICA_BG_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANTARCTICA_BG_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANTARCTICA_BG_PATH4  ; Path 4
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANTARCTICA_BG_PATH5  ; Path 5
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANTARCTICA_BG_PATH6  ; Path 6
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANTARCTICA_BG_PATH7  ; Path 7
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANTARCTICA_BG_PATH8  ; Path 8
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANTARCTICA_BG_PATH9  ; Path 9
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANTARCTICA_BG_PATH10  ; Path 10
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANTARCTICA_BG_PATH11  ; Path 11
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANTARCTICA_BG_PATH12  ; Path 12
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANTARCTICA_BG_PATH13  ; Path 13
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANTARCTICA_BG_PATH14  ; Path 14
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANTARCTICA_BG_PATH15  ; Path 15
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANTARCTICA_BG_PATH16  ; Path 16
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANTARCTICA_BG_PATH17  ; Path 17
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANTARCTICA_BG_PATH18  ; Path 18
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_ANTARCTICA_BG_PATH19  ; Path 19
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_195
IF_NEXT_241:
    ; VPy_LINE:339
; DRAW_VECTOR("easter_bg", x, y) - 5 path(s) at position
    LDD #0
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #50
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
    LDX #_EASTER_BG_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_EASTER_BG_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_EASTER_BG_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_EASTER_BG_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    LDX #_EASTER_BG_PATH4  ; Path 4
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
IF_END_195:
    RTS

    ; VPy_LINE:341
DRAW_GAME_LEVEL: ; function
; --- function draw_game_level ---
    LEAS -4,S ; allocate locals
    ; VPy_LINE:343
    JSR DRAW_LEVEL_BACKGROUND
    ; VPy_LINE:346
    LDD #VAR_JOYSTICK1_STATE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD #0
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDX RESULT
    LDU #VAR_JOY_X
    STU TMPPTR
    STX ,U
    ; VPy_LINE:350
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-20
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_248
    LDD #0
    STD RESULT
    BRA CE_249
CT_248:
    LDD #1
    STD RESULT
CE_249:
    LDD RESULT
    BNE OR_TRUE_246
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #20
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_250
    LDD #0
    STD RESULT
    BRA CE_251
CT_250:
    LDD #1
    STD RESULT
CE_251:
    LDD RESULT
    BNE OR_TRUE_246
    LDD #0
    STD RESULT
    BRA OR_END_247
OR_TRUE_246:
    LDD #1
    STD RESULT
OR_END_247:
    LDD RESULT
    LBEQ IF_NEXT_245
    ; VPy_LINE:353
    LDD VAR_JOY_X
    STD RESULT
    LDX RESULT
    LDU #VAR_ABS_JOY
    STU TMPPTR
    STX ,U
    ; VPy_LINE:354
    LDD VAR_ABS_JOY
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_254
    LDD #0
    STD RESULT
    BRA CE_255
CT_254:
    LDD #1
    STD RESULT
CE_255:
    LDD RESULT
    LBEQ IF_NEXT_253
    ; VPy_LINE:355
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD VAR_ABS_JOY
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_ABS_JOY
    STU TMPPTR
    STX ,U
    LBRA IF_END_252
IF_NEXT_253:
IF_END_252:
    ; VPy_LINE:360
    LDD VAR_ABS_JOY
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #40
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_258
    LDD #0
    STD RESULT
    BRA CE_259
CT_258:
    LDD #1
    STD RESULT
CE_259:
    LDD RESULT
    LBEQ IF_NEXT_257
    ; VPy_LINE:361
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_MOVE_SPEED
    STU TMPPTR
    STX ,U
    LBRA IF_END_256
IF_NEXT_257:
    LDD VAR_ABS_JOY
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #70
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_261
    LDD #0
    STD RESULT
    BRA CE_262
CT_261:
    LDD #1
    STD RESULT
CE_262:
    LDD RESULT
    LBEQ IF_NEXT_260
    ; VPy_LINE:363
    LDD #2
    STD RESULT
    LDX RESULT
    LDU #VAR_MOVE_SPEED
    STU TMPPTR
    STX ,U
    LBRA IF_END_256
IF_NEXT_260:
    LDD VAR_ABS_JOY
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #100
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_264
    LDD #0
    STD RESULT
    BRA CE_265
CT_264:
    LDD #1
    STD RESULT
CE_265:
    LDD RESULT
    LBEQ IF_NEXT_263
    ; VPy_LINE:365
    LDD #3
    STD RESULT
    LDX RESULT
    LDU #VAR_MOVE_SPEED
    STU TMPPTR
    STX ,U
    LBRA IF_END_256
IF_NEXT_263:
    ; VPy_LINE:367
    LDD #4
    STD RESULT
    LDX RESULT
    LDU #VAR_MOVE_SPEED
    STU TMPPTR
    STX ,U
IF_END_256:
    ; VPy_LINE:370
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_268
    LDD #0
    STD RESULT
    BRA CE_269
CT_268:
    LDD #1
    STD RESULT
CE_269:
    LDD RESULT
    LBEQ IF_NEXT_267
    ; VPy_LINE:371
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD VAR_MOVE_SPEED
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX RESULT
    LDU #VAR_MOVE_SPEED
    STU TMPPTR
    STX ,U
    LBRA IF_END_266
IF_NEXT_267:
IF_END_266:
    ; VPy_LINE:373
    LDD VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD VAR_MOVE_SPEED
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
    ; VPy_LINE:376
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
    BLT CT_272
    LDD #0
    STD RESULT
    BRA CE_273
CT_272:
    LDD #1
    STD RESULT
CE_273:
    LDD RESULT
    LBEQ IF_NEXT_271
    ; VPy_LINE:377
    LDD #-110
    STD RESULT
    LDX RESULT
    LDU #VAR_PLAYER_X
    STU TMPPTR
    STX ,U
    LBRA IF_END_270
IF_NEXT_271:
IF_END_270:
    ; VPy_LINE:378
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
    BGT CT_276
    LDD #0
    STD RESULT
    BRA CE_277
CT_276:
    LDD #1
    STD RESULT
CE_277:
    LDD RESULT
    LBEQ IF_NEXT_275
    ; VPy_LINE:379
    LDD #110
    STD RESULT
    LDX RESULT
    LDU #VAR_PLAYER_X
    STU TMPPTR
    STX ,U
    LBRA IF_END_274
IF_NEXT_275:
IF_END_274:
    ; VPy_LINE:382
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_280
    LDD #0
    STD RESULT
    BRA CE_281
CT_280:
    LDD #1
    STD RESULT
CE_281:
    LDD RESULT
    LBEQ IF_NEXT_279
    ; VPy_LINE:383
    LDD #-1
    STD RESULT
    LDX RESULT
    LDU #VAR_PLAYER_FACING
    STU TMPPTR
    STX ,U
    LBRA IF_END_278
IF_NEXT_279:
    ; VPy_LINE:385
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_PLAYER_FACING
    STU TMPPTR
    STX ,U
IF_END_278:
    ; VPy_LINE:388
    LDD VAR_PLAYER_ANIM_COUNTER
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
    LDU #VAR_PLAYER_ANIM_COUNTER
    STU TMPPTR
    STX ,U
    ; VPy_LINE:390
    LDD #5
    STD RESULT
    LDX RESULT
    STX 0 ,S
    ; VPy_LINE:391
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-80
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_286
    LDD #0
    STD RESULT
    BRA CE_287
CT_286:
    LDD #1
    STD RESULT
CE_287:
    LDD RESULT
    BNE OR_TRUE_284
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #80
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_288
    LDD #0
    STD RESULT
    BRA CE_289
CT_288:
    LDD #1
    STD RESULT
CE_289:
    LDD RESULT
    BNE OR_TRUE_284
    LDD #0
    STD RESULT
    BRA OR_END_285
OR_TRUE_284:
    LDD #1
    STD RESULT
OR_END_285:
    LDD RESULT
    LBEQ IF_NEXT_283
    ; VPy_LINE:392
    LDD #5
    STD RESULT
    LDD RESULT
    LSRA
    RORB
    STD RESULT
    LDX RESULT
    STX 0 ,S
    LBRA IF_END_282
IF_NEXT_283:
IF_END_282:
    ; VPy_LINE:394
    LDD VAR_PLAYER_ANIM_COUNTER
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGE CT_292
    LDD #0
    STD RESULT
    BRA CE_293
CT_292:
    LDD #1
    STD RESULT
CE_293:
    LDD RESULT
    LBEQ IF_NEXT_291
    ; VPy_LINE:395
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_PLAYER_ANIM_COUNTER
    STU TMPPTR
    STX ,U
    ; VPy_LINE:396
    LDD VAR_PLAYER_ANIM_FRAME
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
    LDU #VAR_PLAYER_ANIM_FRAME
    STU TMPPTR
    STX ,U
    ; VPy_LINE:397
    LDD VAR_PLAYER_ANIM_FRAME
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #5
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_296
    LDD #0
    STD RESULT
    BRA CE_297
CT_296:
    LDD #1
    STD RESULT
CE_297:
    LDD RESULT
    LBEQ IF_NEXT_295
    ; VPy_LINE:398
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_PLAYER_ANIM_FRAME
    STU TMPPTR
    STX ,U
    LBRA IF_END_294
IF_NEXT_295:
IF_END_294:
    LBRA IF_END_290
IF_NEXT_291:
IF_END_290:
    LBRA IF_END_244
IF_NEXT_245:
    ; VPy_LINE:401
    LDD #1
    STD RESULT
    LDX RESULT
    LDU #VAR_PLAYER_ANIM_FRAME
    STU TMPPTR
    STX ,U
    ; VPy_LINE:402
    LDD #0
    STD RESULT
    LDX RESULT
    LDU #VAR_PLAYER_ANIM_COUNTER
    STU TMPPTR
    STX ,U
IF_END_244:
    ; VPy_LINE:405
    LDD #0
    STD RESULT
    LDX RESULT
    STX 2 ,S
    ; VPy_LINE:406
    LDD VAR_PLAYER_FACING
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_300
    LDD #0
    STD RESULT
    BRA CE_301
CT_300:
    LDD #1
    STD RESULT
CE_301:
    LDD RESULT
    LBEQ IF_NEXT_299
    ; VPy_LINE:407
    LDD #1
    STD RESULT
    LDX RESULT
    STX 2 ,S
    LBRA IF_END_298
IF_NEXT_299:
IF_END_298:
    ; VPy_LINE:410
    LDD VAR_PLAYER_ANIM_FRAME
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_304
    LDD #0
    STD RESULT
    BRA CE_305
CT_304:
    LDD #1
    STD RESULT
CE_305:
    LDD RESULT
    LBEQ IF_NEXT_303
    ; VPy_LINE:411
; DRAW_VECTOR_EX("player_walk_1", x, y, mirror) - 17 path(s), width=19, center_x=1
    LDD VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD #-70
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD 2 ,S
    STD RESULT
    LDB RESULT+1  ; Mirror mode (0=normal, 1=X, 2=Y, 3=both)
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    BNE DSVEX_CHK_Y_306
    LDA #1
    STA MIRROR_X
DSVEX_CHK_Y_306:
    CMPB #2       ; Check if Y-mirror (mode 2)
    BNE DSVEX_CHK_XY_307
    LDA #1
    STA MIRROR_Y
DSVEX_CHK_XY_307:
    CMPB #3       ; Check if both-mirror (mode 3)
    BNE DSVEX_CALL_308
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
DSVEX_CALL_308:
    ; Set intensity override for drawing
    LDD #80
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
    STA DRAW_VEC_INTENSITY  ; Store intensity override (function will use this)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_PLAYER_WALK_1_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_1_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_1_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_1_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_1_PATH4  ; Path 4
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_1_PATH5  ; Path 5
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_1_PATH6  ; Path 6
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_1_PATH7  ; Path 7
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_1_PATH8  ; Path 8
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_1_PATH9  ; Path 9
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_1_PATH10  ; Path 10
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_1_PATH11  ; Path 11
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_1_PATH12  ; Path 12
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_1_PATH13  ; Path 13
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_1_PATH14  ; Path 14
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_1_PATH15  ; Path 15
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_1_PATH16  ; Path 16
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    LBRA IF_END_302
IF_NEXT_303:
    LDD VAR_PLAYER_ANIM_FRAME
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_310
    LDD #0
    STD RESULT
    BRA CE_311
CT_310:
    LDD #1
    STD RESULT
CE_311:
    LDD RESULT
    LBEQ IF_NEXT_309
    ; VPy_LINE:413
; DRAW_VECTOR_EX("player_walk_2", x, y, mirror) - 17 path(s), width=21, center_x=0
    LDD VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD #-70
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD 2 ,S
    STD RESULT
    LDB RESULT+1  ; Mirror mode (0=normal, 1=X, 2=Y, 3=both)
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    BNE DSVEX_CHK_Y_312
    LDA #1
    STA MIRROR_X
DSVEX_CHK_Y_312:
    CMPB #2       ; Check if Y-mirror (mode 2)
    BNE DSVEX_CHK_XY_313
    LDA #1
    STA MIRROR_Y
DSVEX_CHK_XY_313:
    CMPB #3       ; Check if both-mirror (mode 3)
    BNE DSVEX_CALL_314
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
DSVEX_CALL_314:
    ; Set intensity override for drawing
    LDD #80
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
    STA DRAW_VEC_INTENSITY  ; Store intensity override (function will use this)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_PLAYER_WALK_2_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_2_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_2_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_2_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_2_PATH4  ; Path 4
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_2_PATH5  ; Path 5
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_2_PATH6  ; Path 6
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_2_PATH7  ; Path 7
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_2_PATH8  ; Path 8
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_2_PATH9  ; Path 9
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_2_PATH10  ; Path 10
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_2_PATH11  ; Path 11
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_2_PATH12  ; Path 12
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_2_PATH13  ; Path 13
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_2_PATH14  ; Path 14
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_2_PATH15  ; Path 15
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_2_PATH16  ; Path 16
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    LBRA IF_END_302
IF_NEXT_309:
    LDD VAR_PLAYER_ANIM_FRAME
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_316
    LDD #0
    STD RESULT
    BRA CE_317
CT_316:
    LDD #1
    STD RESULT
CE_317:
    LDD RESULT
    LBEQ IF_NEXT_315
    ; VPy_LINE:415
; DRAW_VECTOR_EX("player_walk_3", x, y, mirror) - 17 path(s), width=20, center_x=1
    LDD VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD #-70
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD 2 ,S
    STD RESULT
    LDB RESULT+1  ; Mirror mode (0=normal, 1=X, 2=Y, 3=both)
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    BNE DSVEX_CHK_Y_318
    LDA #1
    STA MIRROR_X
DSVEX_CHK_Y_318:
    CMPB #2       ; Check if Y-mirror (mode 2)
    BNE DSVEX_CHK_XY_319
    LDA #1
    STA MIRROR_Y
DSVEX_CHK_XY_319:
    CMPB #3       ; Check if both-mirror (mode 3)
    BNE DSVEX_CALL_320
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
DSVEX_CALL_320:
    ; Set intensity override for drawing
    LDD #80
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
    STA DRAW_VEC_INTENSITY  ; Store intensity override (function will use this)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_PLAYER_WALK_3_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_3_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_3_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_3_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_3_PATH4  ; Path 4
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_3_PATH5  ; Path 5
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_3_PATH6  ; Path 6
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_3_PATH7  ; Path 7
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_3_PATH8  ; Path 8
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_3_PATH9  ; Path 9
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_3_PATH10  ; Path 10
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_3_PATH11  ; Path 11
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_3_PATH12  ; Path 12
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_3_PATH13  ; Path 13
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_3_PATH14  ; Path 14
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_3_PATH15  ; Path 15
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_3_PATH16  ; Path 16
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    LBRA IF_END_302
IF_NEXT_315:
    LDD VAR_PLAYER_ANIM_FRAME
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #4
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_322
    LDD #0
    STD RESULT
    BRA CE_323
CT_322:
    LDD #1
    STD RESULT
CE_323:
    LDD RESULT
    LBEQ IF_NEXT_321
    ; VPy_LINE:417
; DRAW_VECTOR_EX("player_walk_4", x, y, mirror) - 17 path(s), width=19, center_x=1
    LDD VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD #-70
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD 2 ,S
    STD RESULT
    LDB RESULT+1  ; Mirror mode (0=normal, 1=X, 2=Y, 3=both)
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    BNE DSVEX_CHK_Y_324
    LDA #1
    STA MIRROR_X
DSVEX_CHK_Y_324:
    CMPB #2       ; Check if Y-mirror (mode 2)
    BNE DSVEX_CHK_XY_325
    LDA #1
    STA MIRROR_Y
DSVEX_CHK_XY_325:
    CMPB #3       ; Check if both-mirror (mode 3)
    BNE DSVEX_CALL_326
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
DSVEX_CALL_326:
    ; Set intensity override for drawing
    LDD #80
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
    STA DRAW_VEC_INTENSITY  ; Store intensity override (function will use this)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_PLAYER_WALK_4_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_4_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_4_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_4_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_4_PATH4  ; Path 4
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_4_PATH5  ; Path 5
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_4_PATH6  ; Path 6
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_4_PATH7  ; Path 7
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_4_PATH8  ; Path 8
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_4_PATH9  ; Path 9
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_4_PATH10  ; Path 10
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_4_PATH11  ; Path 11
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_4_PATH12  ; Path 12
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_4_PATH13  ; Path 13
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_4_PATH14  ; Path 14
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_4_PATH15  ; Path 15
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_4_PATH16  ; Path 16
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    LBRA IF_END_302
IF_NEXT_321:
    ; VPy_LINE:419
; DRAW_VECTOR_EX("player_walk_5", x, y, mirror) - 17 path(s), width=19, center_x=1
    LDD VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD #-70
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD 2 ,S
    STD RESULT
    LDB RESULT+1  ; Mirror mode (0=normal, 1=X, 2=Y, 3=both)
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    BNE DSVEX_CHK_Y_327
    LDA #1
    STA MIRROR_X
DSVEX_CHK_Y_327:
    CMPB #2       ; Check if Y-mirror (mode 2)
    BNE DSVEX_CHK_XY_328
    LDA #1
    STA MIRROR_Y
DSVEX_CHK_XY_328:
    CMPB #3       ; Check if both-mirror (mode 3)
    BNE DSVEX_CALL_329
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
DSVEX_CALL_329:
    ; Set intensity override for drawing
    LDD #80
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
    STA DRAW_VEC_INTENSITY  ; Store intensity override (function will use this)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_PLAYER_WALK_5_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_5_PATH1  ; Path 1
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_5_PATH2  ; Path 2
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_5_PATH3  ; Path 3
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_5_PATH4  ; Path 4
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_5_PATH5  ; Path 5
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_5_PATH6  ; Path 6
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_5_PATH7  ; Path 7
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_5_PATH8  ; Path 8
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_5_PATH9  ; Path 9
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_5_PATH10  ; Path 10
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_5_PATH11  ; Path 11
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_5_PATH12  ; Path 12
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_5_PATH13  ; Path 13
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_5_PATH14  ; Path 14
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_5_PATH15  ; Path 15
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    LDX #_PLAYER_WALK_5_PATH16  ; Path 16
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
IF_END_302:
    ; VPy_LINE:422
    JSR UPDATE_ENEMIES
    ; VPy_LINE:423
    JSR DRAW_ENEMIES
    ; VPy_LINE:426
    LDD VAR_HOOK_ACTIVE
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_332
    LDD #0
    STD RESULT
    BRA CE_333
CT_332:
    LDD #1
    STD RESULT
CE_333:
    LDD RESULT
    LBEQ IF_NEXT_331
    ; VPy_LINE:429
    LDD VAR_HOOK_GUN_X
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD VAR_HOOK_INIT_Y
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDD VAR_HOOK_X
    STD RESULT
    LDD RESULT
    STD VAR_ARG2
    LDD VAR_HOOK_Y
    STD RESULT
    LDD RESULT
    STD VAR_ARG3
    JSR DRAW_HOOK_ROPE
    ; VPy_LINE:431
    LDD #100
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 431
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:433
; DRAW_VECTOR_EX("hook", x, y, mirror) - 1 path(s), width=12, center_x=0
    LDD VAR_HOOK_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD VAR_HOOK_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD #0
    STD RESULT
    LDB RESULT+1  ; Mirror mode (0=normal, 1=X, 2=Y, 3=both)
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    BNE DSVEX_CHK_Y_334
    LDA #1
    STA MIRROR_X
DSVEX_CHK_Y_334:
    CMPB #2       ; Check if Y-mirror (mode 2)
    BNE DSVEX_CHK_XY_335
    LDA #1
    STA MIRROR_Y
DSVEX_CHK_XY_335:
    CMPB #3       ; Check if both-mirror (mode 3)
    BNE DSVEX_CALL_336
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
DSVEX_CALL_336:
    ; Set intensity override for drawing
    LDD #100
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
    STA DRAW_VEC_INTENSITY  ; Store intensity override (function will use this)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_HOOK_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses MIRROR_X, MIRROR_Y, and DRAW_VEC_INTENSITY
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    LBRA IF_END_330
IF_NEXT_331:
IF_END_330:
    LEAS 4,S ; free locals
    RTS

    ; VPy_LINE:445
SPAWN_ENEMIES: ; function
; --- function spawn_enemies ---
    LEAS -6,S ; allocate locals
    ; VPy_LINE:447
    ; ===== Const array indexing: level_enemy_count =====
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDX #CONST_ARRAY_4
    LDD TMPPTR
    LEAX D,X
    LDD ,X
    STD RESULT
    LDX RESULT
    STX 0 ,S
    ; VPy_LINE:448
    ; ===== Const array indexing: level_enemy_speed =====
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDX #CONST_ARRAY_5
    LDD TMPPTR
    LEAX D,X
    LDD ,X
    STD RESULT
    LDX RESULT
    STX 4 ,S
    ; VPy_LINE:451
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
    BLT CT_339
    LDD #0
    STD RESULT
    BRA CE_340
CT_339:
    LDD #1
    STD RESULT
CE_340:
    LDD RESULT
    LBEQ IF_NEXT_338
    ; VPy_LINE:452
    LDD #1
    STD RESULT
    LDX RESULT
    STX 0 ,S
    LBRA IF_END_337
IF_NEXT_338:
IF_END_337:
    ; VPy_LINE:453
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #8
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGT CT_343
    LDD #0
    STD RESULT
    BRA CE_344
CT_343:
    LDD #1
    STD RESULT
CE_344:
    LDD RESULT
    LBEQ IF_NEXT_342
    ; VPy_LINE:454
    LDD #8
    STD RESULT
    LDX RESULT
    STX 0 ,S
    LBRA IF_END_341
IF_NEXT_342:
IF_END_341:
    ; VPy_LINE:456
    LDD #0
    STD RESULT
    LDX RESULT
    STX 2 ,S
    ; VPy_LINE:457
WH_345: ; while start
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_347
    LDD #0
    STD RESULT
    BRA CE_348
CT_347:
    LDD #1
    STD RESULT
CE_348:
    LDD RESULT
    BEQ AND_FALSE_349
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #8
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_351
    LDD #0
    STD RESULT
    BRA CE_352
CT_351:
    LDD #1
    STD RESULT
CE_352:
    LDD RESULT
    BEQ AND_FALSE_349
    LDD #1
    STD RESULT
    BRA AND_END_350
AND_FALSE_349:
    LDD #0
    STD RESULT
AND_END_350:
    LDD RESULT
    LBEQ WH_END_346
    ; VPy_LINE:458
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_ENEMY_ACTIVE_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #1
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:459
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_ENEMY_SIZE_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #4
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:460
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_ENEMY_X_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #-80
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD 4 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #50
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    STD MUL_A
    LDD TMPRIGHT
    STD MUL_B
    JSR MUL16
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:461
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_ENEMY_Y_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #60
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:462
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_ENEMY_VX_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD 4 ,S
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:463
    LDD 2 ,S
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
    STD DIV_A
    LDD TMPRIGHT
    STD DIV_B
    JSR DIV16
    ; quotient in RESULT, need remainder: A - Q*B
    LDD DIV_A
    STD TMPLEFT
    LDD RESULT
    STD MUL_A
    LDD DIV_B
    STD MUL_B
    JSR MUL16
    ; product in RESULT, subtract from original A (TMPLEFT)
    LDD TMPLEFT
    SUBD RESULT
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_355
    LDD #0
    STD RESULT
    BRA CE_356
CT_355:
    LDD #1
    STD RESULT
CE_356:
    LDD RESULT
    LBEQ IF_NEXT_354
    ; VPy_LINE:464
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_ENEMY_VX_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD 6 ,S
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    LBRA IF_END_353
IF_NEXT_354:
IF_END_353:
    ; VPy_LINE:465
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_ENEMY_VY_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #0
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:466
    LDD 2 ,S
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
    STX 2 ,S
    LBRA WH_345
WH_END_346: ; while end
    LEAS 6,S ; free locals
    RTS

    ; VPy_LINE:468
UPDATE_ENEMIES: ; function
; --- function update_enemies ---
    LEAS -2,S ; allocate locals
    ; VPy_LINE:470
    LDD #0
    STD RESULT
    LDX RESULT
    STX 0 ,S
    ; VPy_LINE:471
WH_357: ; while start
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #8
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_359
    LDD #0
    STD RESULT
    BRA CE_360
CT_359:
    LDD #1
    STD RESULT
CE_360:
    LDD RESULT
    LBEQ WH_END_358
    ; VPy_LINE:472
    LDD #VAR_ENEMY_ACTIVE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_363
    LDD #0
    STD RESULT
    BRA CE_364
CT_363:
    LDD #1
    STD RESULT
CE_364:
    LDD RESULT
    LBEQ IF_NEXT_362
    ; VPy_LINE:474
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_ENEMY_VY_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #VAR_ENEMY_VY_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
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
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:477
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_ENEMY_X_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #VAR_ENEMY_X_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #VAR_ENEMY_VX_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:478
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_ENEMY_Y_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #VAR_ENEMY_Y_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #VAR_ENEMY_VY_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    ADDD TMPRIGHT
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:481
    LDD #VAR_ENEMY_Y_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-70
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLE CT_367
    LDD #0
    STD RESULT
    BRA CE_368
CT_367:
    LDD #1
    STD RESULT
CE_368:
    LDD RESULT
    LBEQ IF_NEXT_366
    ; VPy_LINE:482
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_ENEMY_Y_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #-70
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:483
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_ENEMY_VY_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #VAR_ENEMY_VY_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:484
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_ENEMY_VY_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #VAR_ENEMY_VY_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #17
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    STD MUL_A
    LDD TMPRIGHT
    STD MUL_B
    JSR MUL16
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #20
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    STD DIV_A
    LDD TMPRIGHT
    STD DIV_B
    JSR DIV16
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:486
    LDD #VAR_ENEMY_VY_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #10
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_371
    LDD #0
    STD RESULT
    BRA CE_372
CT_371:
    LDD #1
    STD RESULT
CE_372:
    LDD RESULT
    LBEQ IF_NEXT_370
    ; VPy_LINE:487
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_ENEMY_VY_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #10
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    LBRA IF_END_369
IF_NEXT_370:
IF_END_369:
    LBRA IF_END_365
IF_NEXT_366:
IF_END_365:
    ; VPy_LINE:490
    LDD #VAR_ENEMY_X_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #-85
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLE CT_375
    LDD #0
    STD RESULT
    BRA CE_376
CT_375:
    LDD #1
    STD RESULT
CE_376:
    LDD RESULT
    LBEQ IF_NEXT_374
    ; VPy_LINE:491
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_ENEMY_X_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #-85
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:492
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_ENEMY_VX_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #VAR_ENEMY_VX_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    LBRA IF_END_373
IF_NEXT_374:
IF_END_373:
    ; VPy_LINE:493
    LDD #VAR_ENEMY_X_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #85
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BGE CT_379
    LDD #0
    STD RESULT
    BRA CE_380
CT_379:
    LDD #1
    STD RESULT
CE_380:
    LDD RESULT
    LBEQ IF_NEXT_378
    ; VPy_LINE:494
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_ENEMY_X_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #85
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:495
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_ENEMY_VX_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    PSHS D
    LDD #VAR_ENEMY_VX_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 2 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    PULS D
    STD TMPLEFT
    LDD TMPLEFT
    SUBD TMPRIGHT
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    LBRA IF_END_377
IF_NEXT_378:
IF_END_377:
    LBRA IF_END_361
IF_NEXT_362:
IF_END_361:
    ; VPy_LINE:497
    LDD 0 ,S
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
    STX 0 ,S
    LBRA WH_357
WH_END_358: ; while end
    LEAS 2,S ; free locals
    RTS

    ; VPy_LINE:501
DRAW_ENEMIES: ; function
; --- function draw_enemies ---
    LEAS -2,S ; allocate locals
    ; VPy_LINE:503
    LDD #0
    STD RESULT
    LDX RESULT
    STX 0 ,S
    ; VPy_LINE:504
WH_381: ; while start
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #8
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BLT CT_383
    LDD #0
    STD RESULT
    BRA CE_384
CT_383:
    LDD #1
    STD RESULT
CE_384:
    LDD RESULT
    LBEQ WH_END_382
    ; VPy_LINE:505
    LDD #VAR_ENEMY_ACTIVE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_387
    LDD #0
    STD RESULT
    BRA CE_388
CT_387:
    LDD #1
    STD RESULT
CE_388:
    LDD RESULT
    LBEQ IF_NEXT_386
    ; VPy_LINE:506
    LDD #80
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
; NATIVE_CALL: VECTREX_SET_INTENSITY at line 506
    JSR VECTREX_SET_INTENSITY
    CLRA
    CLRB
    STD RESULT
    ; VPy_LINE:507
    LDD #VAR_ENEMY_SIZE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #4
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_391
    LDD #0
    STD RESULT
    BRA CE_392
CT_391:
    LDD #1
    STD RESULT
CE_392:
    LDD RESULT
    LBEQ IF_NEXT_390
    ; VPy_LINE:508
; DRAW_VECTOR("bubble_huge", x, y) - 1 path(s) at position
    LDD #VAR_ENEMY_X_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #VAR_ENEMY_Y_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
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
    LDX #_BUBBLE_HUGE_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_389
IF_NEXT_390:
    LDD #VAR_ENEMY_SIZE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_394
    LDD #0
    STD RESULT
    BRA CE_395
CT_394:
    LDD #1
    STD RESULT
CE_395:
    LDD RESULT
    LBEQ IF_NEXT_393
    ; VPy_LINE:510
; DRAW_VECTOR("bubble_large", x, y) - 1 path(s) at position
    LDD #VAR_ENEMY_X_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #VAR_ENEMY_Y_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
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
    LDX #_BUBBLE_LARGE_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_389
IF_NEXT_393:
    LDD #VAR_ENEMY_SIZE_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDD RESULT
    STD TMPLEFT
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPRIGHT
    LDD TMPLEFT
    SUBD TMPRIGHT
    BEQ CT_397
    LDD #0
    STD RESULT
    BRA CE_398
CT_397:
    LDD #1
    STD RESULT
CE_398:
    LDD RESULT
    LBEQ IF_NEXT_396
    ; VPy_LINE:512
; DRAW_VECTOR("bubble_medium", x, y) - 1 path(s) at position
    LDD #VAR_ENEMY_X_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #VAR_ENEMY_Y_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
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
    LDX #_BUBBLE_MEDIUM_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LBRA IF_END_389
IF_NEXT_396:
    ; VPy_LINE:514
; DRAW_VECTOR("bubble_small", x, y) - 1 path(s) at position
    LDD #VAR_ENEMY_X_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD #VAR_ENEMY_Y_DATA
    STD RESULT
    LDD RESULT
    STD TMPPTR
    LDD 0 ,S
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    ADDD TMPPTR
    TFR D,X
    LDD ,X
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
    LDX #_BUBBLE_SMALL_PATH0  ; Path 0
    JSR Draw_Sync_List_At_With_Mirrors  ; Uses unified mirror function
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
IF_END_389:
    LBRA IF_END_385
IF_NEXT_386:
IF_END_385:
    ; VPy_LINE:515
    LDD 0 ,S
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
    STX 0 ,S
    LBRA WH_381
WH_END_382: ; while end
    LEAS 2,S ; free locals
    RTS

    ; VPy_LINE:519
DRAW_HOOK_ROPE: ; function
; --- function draw_hook_rope ---
    LEAS -8,S ; allocate locals
    LDD VAR_ARG0
    STD 0,S ; param 0
    LDD VAR_ARG1
    STD 2,S ; param 1
    LDD VAR_ARG2
    STD 4,S ; param 2
    LDD VAR_ARG3
    STD 6,S ; param 3
    ; VPy_LINE:521
    LDD 0 ,S
    STD RESULT
    STD TMPPTR+0
    LDD 2 ,S
    STD RESULT
    STD TMPPTR+2
    LDD 4 ,S
    STD RESULT
    STD TMPPTR+4
    LDD 6 ,S
    STD RESULT
    STD TMPPTR+6
    LDD #127
    STD TMPPTR+8
    LDD TMPPTR+0
    STD RESULT+0
    LDD TMPPTR+2
    STD RESULT+2
    LDD TMPPTR+4
    STD RESULT+4
    LDD TMPPTR+6
    STD RESULT+6
    LDD TMPPTR+8
    STD RESULT+8
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    LEAS 8,S ; free locals
    RTS

    ; VPy_LINE:523
READ_JOYSTICK1_STATE: ; function
; --- function read_joystick1_state ---
    ; VPy_LINE:528
    LDD #0
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_JOYSTICK1_STATE_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
; NATIVE_CALL: J1_X at line 528
    JSR J1X_BUILTIN
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:529
    LDD #1
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_JOYSTICK1_STATE_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
; NATIVE_CALL: J1_Y at line 529
    JSR J1Y_BUILTIN
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:532
    LDD #2
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_JOYSTICK1_STATE_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
; NATIVE_CALL: J1_BUTTON_1 at line 532
    JSR J1B1_BUILTIN
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:533
    LDD #3
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_JOYSTICK1_STATE_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
; NATIVE_CALL: J1_BUTTON_2 at line 533
    JSR J1B2_BUILTIN
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:534
    LDD #4
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_JOYSTICK1_STATE_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
; NATIVE_CALL: J1_BUTTON_3 at line 534
    JSR J1B3_BUILTIN
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    ; VPy_LINE:535
    LDD #5
    STD RESULT
    LDD RESULT
    ASLB
    ROLA
    STD TMPPTR
    LDD #VAR_JOYSTICK1_STATE_DATA
    TFR D,X
    LDD TMPPTR
    LEAX D,X
    STX TMPPTR2
; NATIVE_CALL: J1_BUTTON_4 at line 535
    JSR J1B4_BUILTIN
    STD RESULT
    LDX TMPPTR2
    LDD RESULT
    STD ,X
    RTS

MUL16:
    LDD MUL_A
    STD MUL_RES
    LDD #0
    STD MUL_TMP
    LDD MUL_B
    STD MUL_CNT
MUL16_LOOP:
    LDD MUL_CNT
    BEQ MUL16_DONE
    LDD MUL_CNT
    ANDA #1
    BEQ MUL16_SKIP
    LDD MUL_RES
    ADDD MUL_TMP
    STD MUL_TMP
MUL16_SKIP:
    LDD MUL_RES
    ASLB
    ROLA
    STD MUL_RES
    LDD MUL_CNT
    LSRA
    RORB
    STD MUL_CNT
    BRA MUL16_LOOP
MUL16_DONE:
    LDD MUL_TMP
    STD RESULT
    RTS

DIV16:
    LDD #0
    STD DIV_Q
    LDD DIV_A
    STD DIV_R
    LDD DIV_B
    BEQ DIV16_DONE
DIV16_LOOP:
    LDD DIV_R
    SUBD DIV_B
    BLO DIV16_DONE
    STD DIV_R
    LDD DIV_Q
    ADDD #1
    STD DIV_Q
    BRA DIV16_LOOP
DIV16_DONE:
    LDD DIV_Q
    STD RESULT
    RTS

;***************************************************************************
; DATA SECTION
;***************************************************************************

; ========================================
; ASSET DATA SECTION
; Embedded 33 of 54 assets (unused assets excluded)
; ========================================

; Vector asset: player_walk_1
; Generated from player_walk_1.vec (Malban Draw_Sync_List format)
; Total paths: 17, points: 62
; X bounds: min=-8, max=11, width=19
; Center: (1, 0)

_PLAYER_WALK_1_WIDTH EQU 19
_PLAYER_WALK_1_CENTER_X EQU 1
_PLAYER_WALK_1_CENTER_Y EQU 0

_PLAYER_WALK_1_VECTORS:  ; Main entry (header + 17 path(s))
    FCB 17               ; path_count (runtime metadata)
    FDB _PLAYER_WALK_1_PATH0        ; pointer to path 0
    FDB _PLAYER_WALK_1_PATH1        ; pointer to path 1
    FDB _PLAYER_WALK_1_PATH2        ; pointer to path 2
    FDB _PLAYER_WALK_1_PATH3        ; pointer to path 3
    FDB _PLAYER_WALK_1_PATH4        ; pointer to path 4
    FDB _PLAYER_WALK_1_PATH5        ; pointer to path 5
    FDB _PLAYER_WALK_1_PATH6        ; pointer to path 6
    FDB _PLAYER_WALK_1_PATH7        ; pointer to path 7
    FDB _PLAYER_WALK_1_PATH8        ; pointer to path 8
    FDB _PLAYER_WALK_1_PATH9        ; pointer to path 9
    FDB _PLAYER_WALK_1_PATH10        ; pointer to path 10
    FDB _PLAYER_WALK_1_PATH11        ; pointer to path 11
    FDB _PLAYER_WALK_1_PATH12        ; pointer to path 12
    FDB _PLAYER_WALK_1_PATH13        ; pointer to path 13
    FDB _PLAYER_WALK_1_PATH14        ; pointer to path 14
    FDB _PLAYER_WALK_1_PATH15        ; pointer to path 15
    FDB _PLAYER_WALK_1_PATH16        ; pointer to path 16

_PLAYER_WALK_1_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $0C,$FB,0,0        ; path0: header (y=12, x=-5, relative to center)
    FCB $FF,$00,$08          ; line 0: flag=-1, dy=0, dx=8
    FCB $FF,$FC,$00          ; line 1: flag=-1, dy=-4, dx=0
    FCB $FF,$00,$F8          ; line 2: flag=-1, dy=0, dx=-8
    FCB $FF,$04,$00          ; closing line: flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $0C,$F9,0,0        ; path1: header (y=12, x=-7, relative to center)
    FCB $FF,$00,$0C          ; line 0: flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $0C,$FB,0,0        ; path2: header (y=12, x=-5, relative to center)
    FCB $FF,$00,$08          ; line 0: flag=-1, dy=0, dx=8
    FCB $FF,$02,$00          ; line 1: flag=-1, dy=2, dx=0
    FCB $FF,$00,$F8          ; line 2: flag=-1, dy=0, dx=-8
    FCB $FF,$FE,$00          ; closing line: flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $08,$FA,0,0        ; path3: header (y=8, x=-6, relative to center)
    FCB $FF,$00,$0A          ; line 0: flag=-1, dy=0, dx=10
    FCB $FF,$F6,$00          ; line 1: flag=-1, dy=-10, dx=0
    FCB $FF,$00,$F6          ; line 2: flag=-1, dy=0, dx=-10
    FCB $FF,$0A,$00          ; closing line: flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $07,$FA,0,0        ; path4: header (y=7, x=-6, relative to center)
    FCB $FF,$FF,$FF          ; line 0: flag=-1, dy=-1, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $06,$F9,0,0        ; path5: header (y=6, x=-7, relative to center)
    FCB $FF,$00,$FE          ; line 0: flag=-1, dy=0, dx=-2
    FCB $FF,$FA,$00          ; line 1: flag=-1, dy=-6, dx=0
    FCB $FF,$00,$02          ; line 2: flag=-1, dy=0, dx=2
    FCB $FF,$06,$00          ; closing line: flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $00,$F9,0,0        ; path6: header (y=0, x=-7, relative to center)
    FCB $FF,$00,$FE          ; line 0: flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$00          ; line 1: flag=-1, dy=-2, dx=0
    FCB $FF,$00,$02          ; line 2: flag=-1, dy=0, dx=2
    FCB $FF,$02,$00          ; closing line: flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $07,$04,0,0        ; path7: header (y=7, x=4, relative to center)
    FCB $FF,$FF,$02          ; line 0: flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $06,$06,0,0        ; path8: header (y=6, x=6, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$FC,$00          ; line 1: flag=-1, dy=-4, dx=0
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$04,$00          ; closing line: flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $04,$06,0,0        ; path9: header (y=4, x=6, relative to center)
    FCB $FF,$00,$04          ; line 0: flag=-1, dy=0, dx=4
    FCB $FF,$FF,$00          ; line 1: flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FC          ; line 2: flag=-1, dy=0, dx=-4
    FCB $FF,$01,$00          ; closing line: flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $03,$07,0,0        ; path10: header (y=3, x=7, relative to center)
    FCB $FF,$00,$01          ; line 0: flag=-1, dy=0, dx=1
    FCB $FF,$FE,$00          ; line 1: flag=-1, dy=-2, dx=0
    FCB $FF,$00,$FF          ; line 2: flag=-1, dy=0, dx=-1
    FCB $FF,$02,$00          ; closing line: flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $FE,$FB,0,0        ; path11: header (y=-2, x=-5, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; line 1: flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; closing line: flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $F8,$FB,0,0        ; path12: header (y=-8, x=-5, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; line 1: flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; closing line: flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $F2,$FB,0,0        ; path13: header (y=-14, x=-5, relative to center)
    FCB $FF,$00,$03          ; line 0: flag=-1, dy=0, dx=3
    FCB $FF,$FF,$00          ; line 1: flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FD          ; line 2: flag=-1, dy=0, dx=-3
    FCB $FF,$01,$00          ; closing line: flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $FE,$01,0,0        ; path14: header (y=-2, x=1, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; line 1: flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; closing line: flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $F8,$01,0,0        ; path15: header (y=-8, x=1, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; line 1: flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; closing line: flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $F2,$01,0,0        ; path16: header (y=-14, x=1, relative to center)
    FCB $FF,$00,$03          ; line 0: flag=-1, dy=0, dx=3
    FCB $FF,$FF,$00          ; line 1: flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FD          ; line 2: flag=-1, dy=0, dx=-3
    FCB $FF,$01,$00          ; closing line: flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

; Vector asset: player_walk_2
; Generated from player_walk_2.vec (Malban Draw_Sync_List format)
; Total paths: 17, points: 62
; X bounds: min=-10, max=11, width=21
; Center: (0, -1)

_PLAYER_WALK_2_WIDTH EQU 21
_PLAYER_WALK_2_CENTER_X EQU 0
_PLAYER_WALK_2_CENTER_Y EQU -1

_PLAYER_WALK_2_VECTORS:  ; Main entry (header + 17 path(s))
    FCB 17               ; path_count (runtime metadata)
    FDB _PLAYER_WALK_2_PATH0        ; pointer to path 0
    FDB _PLAYER_WALK_2_PATH1        ; pointer to path 1
    FDB _PLAYER_WALK_2_PATH2        ; pointer to path 2
    FDB _PLAYER_WALK_2_PATH3        ; pointer to path 3
    FDB _PLAYER_WALK_2_PATH4        ; pointer to path 4
    FDB _PLAYER_WALK_2_PATH5        ; pointer to path 5
    FDB _PLAYER_WALK_2_PATH6        ; pointer to path 6
    FDB _PLAYER_WALK_2_PATH7        ; pointer to path 7
    FDB _PLAYER_WALK_2_PATH8        ; pointer to path 8
    FDB _PLAYER_WALK_2_PATH9        ; pointer to path 9
    FDB _PLAYER_WALK_2_PATH10        ; pointer to path 10
    FDB _PLAYER_WALK_2_PATH11        ; pointer to path 11
    FDB _PLAYER_WALK_2_PATH12        ; pointer to path 12
    FDB _PLAYER_WALK_2_PATH13        ; pointer to path 13
    FDB _PLAYER_WALK_2_PATH14        ; pointer to path 14
    FDB _PLAYER_WALK_2_PATH15        ; pointer to path 15
    FDB _PLAYER_WALK_2_PATH16        ; pointer to path 16

_PLAYER_WALK_2_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $0D,$FC,0,0        ; path0: header (y=13, x=-4, relative to center)
    FCB $FF,$00,$08          ; line 0: flag=-1, dy=0, dx=8
    FCB $FF,$FC,$00          ; line 1: flag=-1, dy=-4, dx=0
    FCB $FF,$00,$F8          ; line 2: flag=-1, dy=0, dx=-8
    FCB $FF,$04,$00          ; closing line: flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $0D,$FA,0,0        ; path1: header (y=13, x=-6, relative to center)
    FCB $FF,$00,$0C          ; line 0: flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $0D,$FC,0,0        ; path2: header (y=13, x=-4, relative to center)
    FCB $FF,$00,$08          ; line 0: flag=-1, dy=0, dx=8
    FCB $FF,$02,$00          ; line 1: flag=-1, dy=2, dx=0
    FCB $FF,$00,$F8          ; line 2: flag=-1, dy=0, dx=-8
    FCB $FF,$FE,$00          ; closing line: flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $09,$FB,0,0        ; path3: header (y=9, x=-5, relative to center)
    FCB $FF,$00,$0A          ; line 0: flag=-1, dy=0, dx=10
    FCB $FF,$F6,$00          ; line 1: flag=-1, dy=-10, dx=0
    FCB $FF,$00,$F6          ; line 2: flag=-1, dy=0, dx=-10
    FCB $FF,$0A,$00          ; closing line: flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $08,$FB,0,0        ; path4: header (y=8, x=-5, relative to center)
    FCB $FF,$FF,$FE          ; line 0: flag=-1, dy=-1, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $07,$F9,0,0        ; path5: header (y=7, x=-7, relative to center)
    FCB $FF,$00,$FE          ; line 0: flag=-1, dy=0, dx=-2
    FCB $FF,$FC,$FF          ; line 1: flag=-1, dy=-4, dx=-1
    FCB $FF,$00,$02          ; line 2: flag=-1, dy=0, dx=2
    FCB $FF,$04,$01          ; closing line: flag=-1, dy=4, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $03,$F8,0,0        ; path6: header (y=3, x=-8, relative to center)
    FCB $FF,$00,$FE          ; line 0: flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$00          ; line 1: flag=-1, dy=-2, dx=0
    FCB $FF,$00,$02          ; line 2: flag=-1, dy=0, dx=2
    FCB $FF,$02,$00          ; closing line: flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $08,$05,0,0        ; path7: header (y=8, x=5, relative to center)
    FCB $FF,$FF,$02          ; line 0: flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $07,$07,0,0        ; path8: header (y=7, x=7, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$FC,$00          ; line 1: flag=-1, dy=-4, dx=0
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$04,$00          ; closing line: flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $05,$07,0,0        ; path9: header (y=5, x=7, relative to center)
    FCB $FF,$00,$04          ; line 0: flag=-1, dy=0, dx=4
    FCB $FF,$FF,$00          ; line 1: flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FC          ; line 2: flag=-1, dy=0, dx=-4
    FCB $FF,$01,$00          ; closing line: flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $04,$08,0,0        ; path10: header (y=4, x=8, relative to center)
    FCB $FF,$00,$01          ; line 0: flag=-1, dy=0, dx=1
    FCB $FF,$FE,$00          ; line 1: flag=-1, dy=-2, dx=0
    FCB $FF,$00,$FF          ; line 2: flag=-1, dy=0, dx=-1
    FCB $FF,$02,$00          ; closing line: flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $FF,$FB,0,0        ; path11: header (y=-1, x=-5, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$FA,$01          ; line 1: flag=-1, dy=-6, dx=1
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$06,$FF          ; closing line: flag=-1, dy=6, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $F9,$FE,0,0        ; path12: header (y=-7, x=-2, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; line 1: flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; closing line: flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $F3,$00,0,0        ; path13: header (y=-13, x=0, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$FF,$00          ; line 1: flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$01,$00          ; closing line: flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $FF,$02,0,0        ; path14: header (y=-1, x=2, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$F9,$01          ; line 1: flag=-1, dy=-7, dx=1
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$07,$FF          ; closing line: flag=-1, dy=7, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $F8,$03,0,0        ; path15: header (y=-8, x=3, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$F9,$01          ; line 1: flag=-1, dy=-7, dx=1
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$07,$FF          ; closing line: flag=-1, dy=7, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $F1,$04,0,0        ; path16: header (y=-15, x=4, relative to center)
    FCB $FF,$00,$03          ; line 0: flag=-1, dy=0, dx=3
    FCB $FF,$FF,$00          ; line 1: flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FD          ; line 2: flag=-1, dy=0, dx=-3
    FCB $FF,$01,$00          ; closing line: flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

; Vector asset: bubble_huge
; Generated from bubble_huge.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 8
; X bounds: min=-25, max=27, width=52
; Center: (1, 0)

_BUBBLE_HUGE_WIDTH EQU 52
_BUBBLE_HUGE_CENTER_X EQU 1
_BUBBLE_HUGE_CENTER_Y EQU 0

_BUBBLE_HUGE_VECTORS:  ; Main entry (header + 1 path(s))
    FCB 1               ; path_count (runtime metadata)
    FDB _BUBBLE_HUGE_PATH0        ; pointer to path 0

_BUBBLE_HUGE_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $00,$1A,0,0        ; path0: header (y=0, x=26, relative to center)
    FCB $FF,$12,$F8          ; line 0: flag=-1, dy=18, dx=-8
    FCB $FF,$08,$EE          ; line 1: flag=-1, dy=8, dx=-18
    FCB $FF,$F8,$EE          ; line 2: flag=-1, dy=-8, dx=-18
    FCB $FF,$EE,$F8          ; line 3: flag=-1, dy=-18, dx=-8
    FCB $FF,$EE,$08          ; line 4: flag=-1, dy=-18, dx=8
    FCB $FF,$F8,$12          ; line 5: flag=-1, dy=-8, dx=18
    FCB $FF,$08,$12          ; line 6: flag=-1, dy=8, dx=18
    FCB $FF,$12,$08          ; closing line: flag=-1, dy=18, dx=8
    FCB 2                ; End marker (path complete)

; Vector asset: player_walk_3
; Generated from player_walk_3.vec (Malban Draw_Sync_List format)
; Total paths: 17, points: 62
; X bounds: min=-9, max=11, width=20
; Center: (1, -1)

_PLAYER_WALK_3_WIDTH EQU 20
_PLAYER_WALK_3_CENTER_X EQU 1
_PLAYER_WALK_3_CENTER_Y EQU -1

_PLAYER_WALK_3_VECTORS:  ; Main entry (header + 17 path(s))
    FCB 17               ; path_count (runtime metadata)
    FDB _PLAYER_WALK_3_PATH0        ; pointer to path 0
    FDB _PLAYER_WALK_3_PATH1        ; pointer to path 1
    FDB _PLAYER_WALK_3_PATH2        ; pointer to path 2
    FDB _PLAYER_WALK_3_PATH3        ; pointer to path 3
    FDB _PLAYER_WALK_3_PATH4        ; pointer to path 4
    FDB _PLAYER_WALK_3_PATH5        ; pointer to path 5
    FDB _PLAYER_WALK_3_PATH6        ; pointer to path 6
    FDB _PLAYER_WALK_3_PATH7        ; pointer to path 7
    FDB _PLAYER_WALK_3_PATH8        ; pointer to path 8
    FDB _PLAYER_WALK_3_PATH9        ; pointer to path 9
    FDB _PLAYER_WALK_3_PATH10        ; pointer to path 10
    FDB _PLAYER_WALK_3_PATH11        ; pointer to path 11
    FDB _PLAYER_WALK_3_PATH12        ; pointer to path 12
    FDB _PLAYER_WALK_3_PATH13        ; pointer to path 13
    FDB _PLAYER_WALK_3_PATH14        ; pointer to path 14
    FDB _PLAYER_WALK_3_PATH15        ; pointer to path 15
    FDB _PLAYER_WALK_3_PATH16        ; pointer to path 16

_PLAYER_WALK_3_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $0D,$FB,0,0        ; path0: header (y=13, x=-5, relative to center)
    FCB $FF,$00,$08          ; line 0: flag=-1, dy=0, dx=8
    FCB $FF,$FC,$00          ; line 1: flag=-1, dy=-4, dx=0
    FCB $FF,$00,$F8          ; line 2: flag=-1, dy=0, dx=-8
    FCB $FF,$04,$00          ; closing line: flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $0D,$F9,0,0        ; path1: header (y=13, x=-7, relative to center)
    FCB $FF,$00,$0C          ; line 0: flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $0D,$FB,0,0        ; path2: header (y=13, x=-5, relative to center)
    FCB $FF,$00,$08          ; line 0: flag=-1, dy=0, dx=8
    FCB $FF,$02,$00          ; line 1: flag=-1, dy=2, dx=0
    FCB $FF,$00,$F8          ; line 2: flag=-1, dy=0, dx=-8
    FCB $FF,$FE,$00          ; closing line: flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $09,$FA,0,0        ; path3: header (y=9, x=-6, relative to center)
    FCB $FF,$00,$0A          ; line 0: flag=-1, dy=0, dx=10
    FCB $FF,$F6,$00          ; line 1: flag=-1, dy=-10, dx=0
    FCB $FF,$00,$F6          ; line 2: flag=-1, dy=0, dx=-10
    FCB $FF,$0A,$00          ; closing line: flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $08,$FA,0,0        ; path4: header (y=8, x=-6, relative to center)
    FCB $FF,$FF,$FF          ; line 0: flag=-1, dy=-1, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $07,$F9,0,0        ; path5: header (y=7, x=-7, relative to center)
    FCB $FF,$00,$FE          ; line 0: flag=-1, dy=0, dx=-2
    FCB $FF,$F9,$FF          ; line 1: flag=-1, dy=-7, dx=-1
    FCB $FF,$00,$02          ; line 2: flag=-1, dy=0, dx=2
    FCB $FF,$07,$01          ; closing line: flag=-1, dy=7, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $00,$F8,0,0        ; path6: header (y=0, x=-8, relative to center)
    FCB $FF,$00,$FE          ; line 0: flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$00          ; line 1: flag=-1, dy=-2, dx=0
    FCB $FF,$00,$02          ; line 2: flag=-1, dy=0, dx=2
    FCB $FF,$02,$00          ; closing line: flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $08,$04,0,0        ; path7: header (y=8, x=4, relative to center)
    FCB $FF,$FF,$02          ; line 0: flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $07,$06,0,0        ; path8: header (y=7, x=6, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$FC,$00          ; line 1: flag=-1, dy=-4, dx=0
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$04,$00          ; closing line: flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $05,$06,0,0        ; path9: header (y=5, x=6, relative to center)
    FCB $FF,$00,$04          ; line 0: flag=-1, dy=0, dx=4
    FCB $FF,$FF,$00          ; line 1: flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FC          ; line 2: flag=-1, dy=0, dx=-4
    FCB $FF,$01,$00          ; closing line: flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $04,$07,0,0        ; path10: header (y=4, x=7, relative to center)
    FCB $FF,$00,$01          ; line 0: flag=-1, dy=0, dx=1
    FCB $FF,$FE,$00          ; line 1: flag=-1, dy=-2, dx=0
    FCB $FF,$00,$FF          ; line 2: flag=-1, dy=0, dx=-1
    FCB $FF,$02,$00          ; closing line: flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $FF,$FA,0,0        ; path11: header (y=-1, x=-6, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$F9,$FF          ; line 1: flag=-1, dy=-7, dx=-1
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$07,$01          ; closing line: flag=-1, dy=7, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $F8,$FB,0,0        ; path12: header (y=-8, x=-5, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; line 1: flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; closing line: flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $F2,$FB,0,0        ; path13: header (y=-14, x=-5, relative to center)
    FCB $FF,$00,$03          ; line 0: flag=-1, dy=0, dx=3
    FCB $FF,$FF,$00          ; line 1: flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FD          ; line 2: flag=-1, dy=0, dx=-3
    FCB $FF,$01,$00          ; closing line: flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $FF,$02,0,0        ; path14: header (y=-1, x=2, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$F9,$01          ; line 1: flag=-1, dy=-7, dx=1
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$07,$FF          ; closing line: flag=-1, dy=7, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $F8,$03,0,0        ; path15: header (y=-8, x=3, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; line 1: flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; closing line: flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $F2,$03,0,0        ; path16: header (y=-14, x=3, relative to center)
    FCB $FF,$00,$03          ; line 0: flag=-1, dy=0, dx=3
    FCB $FF,$FF,$00          ; line 1: flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FD          ; line 2: flag=-1, dy=0, dx=-3
    FCB $FF,$01,$00          ; closing line: flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

; Vector asset: player_walk_4
; Generated from player_walk_4.vec (Malban Draw_Sync_List format)
; Total paths: 17, points: 62
; X bounds: min=-8, max=11, width=19
; Center: (1, -1)

_PLAYER_WALK_4_WIDTH EQU 19
_PLAYER_WALK_4_CENTER_X EQU 1
_PLAYER_WALK_4_CENTER_Y EQU -1

_PLAYER_WALK_4_VECTORS:  ; Main entry (header + 17 path(s))
    FCB 17               ; path_count (runtime metadata)
    FDB _PLAYER_WALK_4_PATH0        ; pointer to path 0
    FDB _PLAYER_WALK_4_PATH1        ; pointer to path 1
    FDB _PLAYER_WALK_4_PATH2        ; pointer to path 2
    FDB _PLAYER_WALK_4_PATH3        ; pointer to path 3
    FDB _PLAYER_WALK_4_PATH4        ; pointer to path 4
    FDB _PLAYER_WALK_4_PATH5        ; pointer to path 5
    FDB _PLAYER_WALK_4_PATH6        ; pointer to path 6
    FDB _PLAYER_WALK_4_PATH7        ; pointer to path 7
    FDB _PLAYER_WALK_4_PATH8        ; pointer to path 8
    FDB _PLAYER_WALK_4_PATH9        ; pointer to path 9
    FDB _PLAYER_WALK_4_PATH10        ; pointer to path 10
    FDB _PLAYER_WALK_4_PATH11        ; pointer to path 11
    FDB _PLAYER_WALK_4_PATH12        ; pointer to path 12
    FDB _PLAYER_WALK_4_PATH13        ; pointer to path 13
    FDB _PLAYER_WALK_4_PATH14        ; pointer to path 14
    FDB _PLAYER_WALK_4_PATH15        ; pointer to path 15
    FDB _PLAYER_WALK_4_PATH16        ; pointer to path 16

_PLAYER_WALK_4_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $0D,$FB,0,0        ; path0: header (y=13, x=-5, relative to center)
    FCB $FF,$00,$08          ; line 0: flag=-1, dy=0, dx=8
    FCB $FF,$FC,$00          ; line 1: flag=-1, dy=-4, dx=0
    FCB $FF,$00,$F8          ; line 2: flag=-1, dy=0, dx=-8
    FCB $FF,$04,$00          ; closing line: flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $0D,$F9,0,0        ; path1: header (y=13, x=-7, relative to center)
    FCB $FF,$00,$0C          ; line 0: flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $0D,$FB,0,0        ; path2: header (y=13, x=-5, relative to center)
    FCB $FF,$00,$08          ; line 0: flag=-1, dy=0, dx=8
    FCB $FF,$02,$00          ; line 1: flag=-1, dy=2, dx=0
    FCB $FF,$00,$F8          ; line 2: flag=-1, dy=0, dx=-8
    FCB $FF,$FE,$00          ; closing line: flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $09,$FA,0,0        ; path3: header (y=9, x=-6, relative to center)
    FCB $FF,$00,$0A          ; line 0: flag=-1, dy=0, dx=10
    FCB $FF,$F6,$00          ; line 1: flag=-1, dy=-10, dx=0
    FCB $FF,$00,$F6          ; line 2: flag=-1, dy=0, dx=-10
    FCB $FF,$0A,$00          ; closing line: flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $08,$FA,0,0        ; path4: header (y=8, x=-6, relative to center)
    FCB $FF,$FF,$FF          ; line 0: flag=-1, dy=-1, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $07,$F9,0,0        ; path5: header (y=7, x=-7, relative to center)
    FCB $FF,$00,$FE          ; line 0: flag=-1, dy=0, dx=-2
    FCB $FF,$FA,$00          ; line 1: flag=-1, dy=-6, dx=0
    FCB $FF,$00,$02          ; line 2: flag=-1, dy=0, dx=2
    FCB $FF,$06,$00          ; closing line: flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $01,$F9,0,0        ; path6: header (y=1, x=-7, relative to center)
    FCB $FF,$00,$FE          ; line 0: flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$00          ; line 1: flag=-1, dy=-2, dx=0
    FCB $FF,$00,$02          ; line 2: flag=-1, dy=0, dx=2
    FCB $FF,$02,$00          ; closing line: flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $08,$04,0,0        ; path7: header (y=8, x=4, relative to center)
    FCB $FF,$FF,$02          ; line 0: flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $07,$06,0,0        ; path8: header (y=7, x=6, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$FC,$00          ; line 1: flag=-1, dy=-4, dx=0
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$04,$00          ; closing line: flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $05,$06,0,0        ; path9: header (y=5, x=6, relative to center)
    FCB $FF,$00,$04          ; line 0: flag=-1, dy=0, dx=4
    FCB $FF,$FF,$00          ; line 1: flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FC          ; line 2: flag=-1, dy=0, dx=-4
    FCB $FF,$01,$00          ; closing line: flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $04,$07,0,0        ; path10: header (y=4, x=7, relative to center)
    FCB $FF,$00,$01          ; line 0: flag=-1, dy=0, dx=1
    FCB $FF,$FE,$00          ; line 1: flag=-1, dy=-2, dx=0
    FCB $FF,$00,$FF          ; line 2: flag=-1, dy=0, dx=-1
    FCB $FF,$02,$00          ; closing line: flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $FF,$FA,0,0        ; path11: header (y=-1, x=-6, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$F9,$01          ; line 1: flag=-1, dy=-7, dx=1
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$07,$FF          ; closing line: flag=-1, dy=7, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $F8,$FD,0,0        ; path12: header (y=-8, x=-3, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$F9,$00          ; line 1: flag=-1, dy=-7, dx=0
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$07,$00          ; closing line: flag=-1, dy=7, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $F1,$FF,0,0        ; path13: header (y=-15, x=-1, relative to center)
    FCB $FF,$00,$03          ; line 0: flag=-1, dy=0, dx=3
    FCB $FF,$FF,$00          ; line 1: flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FD          ; line 2: flag=-1, dy=0, dx=-3
    FCB $FF,$01,$00          ; closing line: flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $FF,$01,0,0        ; path14: header (y=-1, x=1, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; line 1: flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; closing line: flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $F9,$01,0,0        ; path15: header (y=-7, x=1, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$FA,$FF          ; line 1: flag=-1, dy=-6, dx=-1
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$06,$01          ; closing line: flag=-1, dy=6, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $F3,$00,0,0        ; path16: header (y=-13, x=0, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$FF,$00          ; line 1: flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$01,$00          ; closing line: flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

; Vector asset: player_walk_5
; Generated from player_walk_5.vec (Malban Draw_Sync_List format)
; Total paths: 17, points: 62
; X bounds: min=-8, max=11, width=19
; Center: (1, 0)

_PLAYER_WALK_5_WIDTH EQU 19
_PLAYER_WALK_5_CENTER_X EQU 1
_PLAYER_WALK_5_CENTER_Y EQU 0

_PLAYER_WALK_5_VECTORS:  ; Main entry (header + 17 path(s))
    FCB 17               ; path_count (runtime metadata)
    FDB _PLAYER_WALK_5_PATH0        ; pointer to path 0
    FDB _PLAYER_WALK_5_PATH1        ; pointer to path 1
    FDB _PLAYER_WALK_5_PATH2        ; pointer to path 2
    FDB _PLAYER_WALK_5_PATH3        ; pointer to path 3
    FDB _PLAYER_WALK_5_PATH4        ; pointer to path 4
    FDB _PLAYER_WALK_5_PATH5        ; pointer to path 5
    FDB _PLAYER_WALK_5_PATH6        ; pointer to path 6
    FDB _PLAYER_WALK_5_PATH7        ; pointer to path 7
    FDB _PLAYER_WALK_5_PATH8        ; pointer to path 8
    FDB _PLAYER_WALK_5_PATH9        ; pointer to path 9
    FDB _PLAYER_WALK_5_PATH10        ; pointer to path 10
    FDB _PLAYER_WALK_5_PATH11        ; pointer to path 11
    FDB _PLAYER_WALK_5_PATH12        ; pointer to path 12
    FDB _PLAYER_WALK_5_PATH13        ; pointer to path 13
    FDB _PLAYER_WALK_5_PATH14        ; pointer to path 14
    FDB _PLAYER_WALK_5_PATH15        ; pointer to path 15
    FDB _PLAYER_WALK_5_PATH16        ; pointer to path 16

_PLAYER_WALK_5_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $0C,$FB,0,0        ; path0: header (y=12, x=-5, relative to center)
    FCB $FF,$00,$08          ; line 0: flag=-1, dy=0, dx=8
    FCB $FF,$FC,$00          ; line 1: flag=-1, dy=-4, dx=0
    FCB $FF,$00,$F8          ; line 2: flag=-1, dy=0, dx=-8
    FCB $FF,$04,$00          ; closing line: flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $0C,$F9,0,0        ; path1: header (y=12, x=-7, relative to center)
    FCB $FF,$00,$0C          ; line 0: flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $0C,$FB,0,0        ; path2: header (y=12, x=-5, relative to center)
    FCB $FF,$00,$08          ; line 0: flag=-1, dy=0, dx=8
    FCB $FF,$02,$00          ; line 1: flag=-1, dy=2, dx=0
    FCB $FF,$00,$F8          ; line 2: flag=-1, dy=0, dx=-8
    FCB $FF,$FE,$00          ; closing line: flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $08,$FA,0,0        ; path3: header (y=8, x=-6, relative to center)
    FCB $FF,$00,$0A          ; line 0: flag=-1, dy=0, dx=10
    FCB $FF,$F6,$00          ; line 1: flag=-1, dy=-10, dx=0
    FCB $FF,$00,$F6          ; line 2: flag=-1, dy=0, dx=-10
    FCB $FF,$0A,$00          ; closing line: flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $07,$FA,0,0        ; path4: header (y=7, x=-6, relative to center)
    FCB $FF,$FF,$FF          ; line 0: flag=-1, dy=-1, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $06,$F9,0,0        ; path5: header (y=6, x=-7, relative to center)
    FCB $FF,$00,$FE          ; line 0: flag=-1, dy=0, dx=-2
    FCB $FF,$FB,$00          ; line 1: flag=-1, dy=-5, dx=0
    FCB $FF,$00,$02          ; line 2: flag=-1, dy=0, dx=2
    FCB $FF,$05,$00          ; closing line: flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $01,$F9,0,0        ; path6: header (y=1, x=-7, relative to center)
    FCB $FF,$00,$FE          ; line 0: flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$00          ; line 1: flag=-1, dy=-2, dx=0
    FCB $FF,$00,$02          ; line 2: flag=-1, dy=0, dx=2
    FCB $FF,$02,$00          ; closing line: flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $07,$04,0,0        ; path7: header (y=7, x=4, relative to center)
    FCB $FF,$FF,$02          ; line 0: flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $06,$06,0,0        ; path8: header (y=6, x=6, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$FC,$00          ; line 1: flag=-1, dy=-4, dx=0
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$04,$00          ; closing line: flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $04,$06,0,0        ; path9: header (y=4, x=6, relative to center)
    FCB $FF,$00,$04          ; line 0: flag=-1, dy=0, dx=4
    FCB $FF,$FF,$00          ; line 1: flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FC          ; line 2: flag=-1, dy=0, dx=-4
    FCB $FF,$01,$00          ; closing line: flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $03,$07,0,0        ; path10: header (y=3, x=7, relative to center)
    FCB $FF,$00,$01          ; line 0: flag=-1, dy=0, dx=1
    FCB $FF,$FE,$00          ; line 1: flag=-1, dy=-2, dx=0
    FCB $FF,$00,$FF          ; line 2: flag=-1, dy=0, dx=-1
    FCB $FF,$02,$00          ; closing line: flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $FE,$FB,0,0        ; path11: header (y=-2, x=-5, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; line 1: flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; closing line: flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $F8,$FB,0,0        ; path12: header (y=-8, x=-5, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; line 1: flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; closing line: flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $F2,$FB,0,0        ; path13: header (y=-14, x=-5, relative to center)
    FCB $FF,$00,$03          ; line 0: flag=-1, dy=0, dx=3
    FCB $FF,$FF,$00          ; line 1: flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FD          ; line 2: flag=-1, dy=0, dx=-3
    FCB $FF,$01,$00          ; closing line: flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $FE,$01,0,0        ; path14: header (y=-2, x=1, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; line 1: flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; closing line: flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $F8,$01,0,0        ; path15: header (y=-8, x=1, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; line 1: flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; line 2: flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; closing line: flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $F2,$01,0,0        ; path16: header (y=-14, x=1, relative to center)
    FCB $FF,$00,$03          ; line 0: flag=-1, dy=0, dx=3
    FCB $FF,$FF,$00          ; line 1: flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FD          ; line 2: flag=-1, dy=0, dx=-3
    FCB $FF,$01,$00          ; closing line: flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

; Vector asset: bubble_large
; Generated from bubble_large.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 24
; X bounds: min=-20, max=20, width=40
; Center: (0, 0)

_BUBBLE_LARGE_WIDTH EQU 40
_BUBBLE_LARGE_CENTER_X EQU 0
_BUBBLE_LARGE_CENTER_Y EQU 0

_BUBBLE_LARGE_VECTORS:  ; Main entry (header + 1 path(s))
    FCB 1               ; path_count (runtime metadata)
    FDB _BUBBLE_LARGE_PATH0        ; pointer to path 0

_BUBBLE_LARGE_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $00,$14,0,0        ; path0: header (y=0, x=20, relative to center)
    FCB $FF,$05,$FF          ; line 0: flag=-1, dy=5, dx=-1
    FCB $FF,$05,$FE          ; line 1: flag=-1, dy=5, dx=-2
    FCB $FF,$04,$FD          ; line 2: flag=-1, dy=4, dx=-3
    FCB $FF,$03,$FC          ; line 3: flag=-1, dy=3, dx=-4
    FCB $FF,$02,$FB          ; line 4: flag=-1, dy=2, dx=-5
    FCB $FF,$01,$FB          ; line 5: flag=-1, dy=1, dx=-5
    FCB $FF,$FF,$FB          ; line 6: flag=-1, dy=-1, dx=-5
    FCB $FF,$FE,$FB          ; line 7: flag=-1, dy=-2, dx=-5
    FCB $FF,$FD,$FC          ; line 8: flag=-1, dy=-3, dx=-4
    FCB $FF,$FC,$FD          ; line 9: flag=-1, dy=-4, dx=-3
    FCB $FF,$FB,$FE          ; line 10: flag=-1, dy=-5, dx=-2
    FCB $FF,$FB,$FF          ; line 11: flag=-1, dy=-5, dx=-1
    FCB $FF,$FB,$01          ; line 12: flag=-1, dy=-5, dx=1
    FCB $FF,$FB,$02          ; line 13: flag=-1, dy=-5, dx=2
    FCB $FF,$FC,$03          ; line 14: flag=-1, dy=-4, dx=3
    FCB $FF,$FD,$04          ; line 15: flag=-1, dy=-3, dx=4
    FCB $FF,$FE,$05          ; line 16: flag=-1, dy=-2, dx=5
    FCB $FF,$FF,$05          ; line 17: flag=-1, dy=-1, dx=5
    FCB $FF,$01,$05          ; line 18: flag=-1, dy=1, dx=5
    FCB $FF,$02,$05          ; line 19: flag=-1, dy=2, dx=5
    FCB $FF,$03,$04          ; line 20: flag=-1, dy=3, dx=4
    FCB $FF,$04,$03          ; line 21: flag=-1, dy=4, dx=3
    FCB $FF,$05,$02          ; line 22: flag=-1, dy=5, dx=2
    FCB $FF,$05,$01          ; closing line: flag=-1, dy=5, dx=1
    FCB 2                ; End marker (path complete)

; Vector asset: newyork_bg
; Generated from newyork_bg.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 22
; X bounds: min=-25, max=25, width=50
; Center: (0, 27)

_NEWYORK_BG_WIDTH EQU 50
_NEWYORK_BG_CENTER_X EQU 0
_NEWYORK_BG_CENTER_Y EQU 27

_NEWYORK_BG_VECTORS:  ; Main entry (header + 5 path(s))
    FCB 5               ; path_count (runtime metadata)
    FDB _NEWYORK_BG_PATH0        ; pointer to path 0
    FDB _NEWYORK_BG_PATH1        ; pointer to path 1
    FDB _NEWYORK_BG_PATH2        ; pointer to path 2
    FDB _NEWYORK_BG_PATH3        ; pointer to path 3
    FDB _NEWYORK_BG_PATH4        ; pointer to path 4

_NEWYORK_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $21,$FB,0,0        ; path0: header (y=33, x=-5, relative to center)
    FCB $FF,$05,$00          ; line 0: flag=-1, dy=5, dx=0
    FCB $FF,$00,$0A          ; line 1: flag=-1, dy=0, dx=10
    FCB $FF,$FB,$00          ; line 2: flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

_NEWYORK_BG_PATH1:    ; Path 1
    FCB 110              ; path1: intensity
    FCB $0D,$00,0,0        ; path1: header (y=13, x=0, relative to center)
    FCB $FF,$0F,$0A          ; line 0: flag=-1, dy=15, dx=10
    FCB $FF,$05,$F6          ; line 1: flag=-1, dy=5, dx=-10
    FCB 2                ; End marker (path complete)

_NEWYORK_BG_PATH2:    ; Path 2
    FCB 110              ; path2: intensity
    FCB $0D,$F1,0,0        ; path2: header (y=13, x=-15, relative to center)
    FCB $FF,$CE,$00          ; line 0: flag=-1, dy=-50, dx=0
    FCB $FF,$00,$1E          ; line 1: flag=-1, dy=0, dx=30
    FCB $FF,$32,$00          ; line 2: flag=-1, dy=50, dx=0
    FCB 2                ; End marker (path complete)

_NEWYORK_BG_PATH3:    ; Path 3
    FCB 120              ; path3: intensity
    FCB $0D,$EC,0,0        ; path3: header (y=13, x=-20, relative to center)
    FCB $FF,$0A,$05          ; line 0: flag=-1, dy=10, dx=5
    FCB $FF,$FB,$05          ; line 1: flag=-1, dy=-5, dx=5
    FCB $FF,$07,$05          ; line 2: flag=-1, dy=7, dx=5
    FCB $FF,$F9,$05          ; line 3: flag=-1, dy=-7, dx=5
    FCB $FF,$07,$05          ; line 4: flag=-1, dy=7, dx=5
    FCB $FF,$F9,$05          ; line 5: flag=-1, dy=-7, dx=5
    FCB $FF,$05,$05          ; line 6: flag=-1, dy=5, dx=5
    FCB $FF,$F6,$05          ; line 7: flag=-1, dy=-10, dx=5
    FCB 2                ; End marker (path complete)

_NEWYORK_BG_PATH4:    ; Path 4
    FCB 100              ; path4: intensity
    FCB $DB,$E7,0,0        ; path4: header (y=-37, x=-25, relative to center)
    FCB $FF,$00,$32          ; line 0: flag=-1, dy=0, dx=50
    FCB 2                ; End marker (path complete)

; Vector asset: pyramids_bg
; Generated from pyramids_bg.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 10
; X bounds: min=-90, max=90, width=180
; Center: (0, 0)

_PYRAMIDS_BG_WIDTH EQU 180
_PYRAMIDS_BG_CENTER_X EQU 0
_PYRAMIDS_BG_CENTER_Y EQU 0

_PYRAMIDS_BG_VECTORS:  ; Main entry (header + 4 path(s))
    FCB 4               ; path_count (runtime metadata)
    FDB _PYRAMIDS_BG_PATH0        ; pointer to path 0
    FDB _PYRAMIDS_BG_PATH1        ; pointer to path 1
    FDB _PYRAMIDS_BG_PATH2        ; pointer to path 2
    FDB _PYRAMIDS_BG_PATH3        ; pointer to path 3

_PYRAMIDS_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $D3,$A6,0,0        ; path0: header (y=-45, x=-90, relative to center)
    FCB $FF,$5A,$50          ; line 0: flag=-1, dy=90, dx=80
    FCB $FF,$A6,$50          ; line 1: flag=-1, dy=-90, dx=80
    FCB 2                ; End marker (path complete)

_PYRAMIDS_BG_PATH1:    ; Path 1
    FCB 100              ; path1: intensity
    FCB $D3,$A6,0,0        ; path1: header (y=-45, x=-90, relative to center)
    FCB $FF,$5A,$50          ; line 0: flag=-1, dy=90, dx=80
    FCB 2                ; End marker (path complete)

_PYRAMIDS_BG_PATH2:    ; Path 2
    FCB 80              ; path2: intensity
    FCB $2D,$F6,0,0        ; path2: header (y=45, x=-10, relative to center)
    FCB $FF,$A6,$50          ; line 0: flag=-1, dy=-90, dx=80
    FCB 2                ; End marker (path complete)

_PYRAMIDS_BG_PATH3:    ; Path 3
    FCB 90              ; path3: intensity
    FCB $D3,$1E,0,0        ; path3: header (y=-45, x=30, relative to center)
    FCB $FF,$2D,$1E          ; line 0: flag=-1, dy=45, dx=30
    FCB $FF,$D3,$1E          ; line 1: flag=-1, dy=-45, dx=30
    FCB 2                ; End marker (path complete)

; Vector asset: easter_bg
; Generated from easter_bg.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 19
; X bounds: min=-35, max=35, width=70
; Center: (0, 15)

_EASTER_BG_WIDTH EQU 70
_EASTER_BG_CENTER_X EQU 0
_EASTER_BG_CENTER_Y EQU 15

_EASTER_BG_VECTORS:  ; Main entry (header + 5 path(s))
    FCB 5               ; path_count (runtime metadata)
    FDB _EASTER_BG_PATH0        ; pointer to path 0
    FDB _EASTER_BG_PATH1        ; pointer to path 1
    FDB _EASTER_BG_PATH2        ; pointer to path 2
    FDB _EASTER_BG_PATH3        ; pointer to path 3
    FDB _EASTER_BG_PATH4        ; pointer to path 4

_EASTER_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $05,$E7,0,0        ; path0: header (y=5, x=-25, relative to center)
    FCB $FF,$1E,$00          ; line 0: flag=-1, dy=30, dx=0
    FCB $FF,$0A,$05          ; line 1: flag=-1, dy=10, dx=5
    FCB $FF,$00,$28          ; line 2: flag=-1, dy=0, dx=40
    FCB $FF,$F6,$05          ; line 3: flag=-1, dy=-10, dx=5
    FCB $FF,$E2,$00          ; line 4: flag=-1, dy=-30, dx=0
    FCB 2                ; End marker (path complete)

_EASTER_BG_PATH1:    ; Path 1
    FCB 110              ; path1: intensity
    FCB $19,$00,0,0        ; path1: header (y=25, x=0, relative to center)
    FCB $FF,$FB,$0A          ; line 0: flag=-1, dy=-5, dx=10
    FCB 2                ; End marker (path complete)

_EASTER_BG_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $1E,$F8,0,0        ; path2: header (y=30, x=-8, relative to center)
    FCB $FF,$05,$00          ; line 0: flag=-1, dy=5, dx=0
    FCB $FF,$00,$05          ; line 1: flag=-1, dy=0, dx=5
    FCB $FF,$FB,$00          ; line 2: flag=-1, dy=-5, dx=0
    FCB $FF,$00,$FB          ; line 3: flag=-1, dy=0, dx=-5
    FCB 2                ; End marker (path complete)

_EASTER_BG_PATH3:    ; Path 3
    FCB 110              ; path3: intensity
    FCB $05,$E2,0,0        ; path3: header (y=5, x=-30, relative to center)
    FCB $FF,$CE,$00          ; line 0: flag=-1, dy=-50, dx=0
    FCB $FF,$00,$3C          ; line 1: flag=-1, dy=0, dx=60
    FCB $FF,$32,$00          ; line 2: flag=-1, dy=50, dx=0
    FCB 2                ; End marker (path complete)

_EASTER_BG_PATH4:    ; Path 4
    FCB 90              ; path4: intensity
    FCB $D3,$DD,0,0        ; path4: header (y=-45, x=-35, relative to center)
    FCB $FF,$00,$46          ; line 0: flag=-1, dy=0, dx=70
    FCB 2                ; End marker (path complete)

; Vector asset: keirin_bg
; Generated from keirin_bg.vec (Malban Draw_Sync_List format)
; Total paths: 3, points: 11
; X bounds: min=-100, max=100, width=200
; Center: (0, 10)

_KEIRIN_BG_WIDTH EQU 200
_KEIRIN_BG_CENTER_X EQU 0
_KEIRIN_BG_CENTER_Y EQU 10

_KEIRIN_BG_VECTORS:  ; Main entry (header + 3 path(s))
    FCB 3               ; path_count (runtime metadata)
    FDB _KEIRIN_BG_PATH0        ; pointer to path 0
    FDB _KEIRIN_BG_PATH1        ; pointer to path 1
    FDB _KEIRIN_BG_PATH2        ; pointer to path 2

_KEIRIN_BG_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $D8,$9C,0,0        ; path0: header (y=-40, x=-100, relative to center)
    FCB $FF,$46,$32          ; line 0: flag=-1, dy=70, dx=50
    FCB $FF,$0A,$32          ; line 1: flag=-1, dy=10, dx=50
    FCB $FF,$F6,$32          ; line 2: flag=-1, dy=-10, dx=50
    FCB $FF,$BA,$32          ; line 3: flag=-1, dy=-70, dx=50
    FCB 2                ; End marker (path complete)

_KEIRIN_BG_PATH1:    ; Path 1
    FCB 80              ; path1: intensity
    FCB $EC,$BA,0,0        ; path1: header (y=-20, x=-70, relative to center)
    FCB $FF,$1E,$1E          ; line 0: flag=-1, dy=30, dx=30
    FCB $FF,$0A,$1E          ; line 1: flag=-1, dy=10, dx=30
    FCB 2                ; End marker (path complete)

_KEIRIN_BG_PATH2:    ; Path 2
    FCB 80              ; path2: intensity
    FCB $14,$0A,0,0        ; path2: header (y=20, x=10, relative to center)
    FCB $FF,$F6,$1E          ; line 0: flag=-1, dy=-10, dx=30
    FCB $FF,$E2,$1E          ; line 1: flag=-1, dy=-30, dx=30
    FCB 2                ; End marker (path complete)

; Vector asset: barcelona_bg
; Generated from barcelona_bg.vec (Malban Draw_Sync_List format)
; Total paths: 60, points: 193
; X bounds: min=-47, max=69, width=116
; Center: (11, 13)

_BARCELONA_BG_WIDTH EQU 116
_BARCELONA_BG_CENTER_X EQU 11
_BARCELONA_BG_CENTER_Y EQU 13

_BARCELONA_BG_VECTORS:  ; Main entry (header + 60 path(s))
    FCB 60               ; path_count (runtime metadata)
    FDB _BARCELONA_BG_PATH0        ; pointer to path 0
    FDB _BARCELONA_BG_PATH1        ; pointer to path 1
    FDB _BARCELONA_BG_PATH2        ; pointer to path 2
    FDB _BARCELONA_BG_PATH3        ; pointer to path 3
    FDB _BARCELONA_BG_PATH4        ; pointer to path 4
    FDB _BARCELONA_BG_PATH5        ; pointer to path 5
    FDB _BARCELONA_BG_PATH6        ; pointer to path 6
    FDB _BARCELONA_BG_PATH7        ; pointer to path 7
    FDB _BARCELONA_BG_PATH8        ; pointer to path 8
    FDB _BARCELONA_BG_PATH9        ; pointer to path 9
    FDB _BARCELONA_BG_PATH10        ; pointer to path 10
    FDB _BARCELONA_BG_PATH11        ; pointer to path 11
    FDB _BARCELONA_BG_PATH12        ; pointer to path 12
    FDB _BARCELONA_BG_PATH13        ; pointer to path 13
    FDB _BARCELONA_BG_PATH14        ; pointer to path 14
    FDB _BARCELONA_BG_PATH15        ; pointer to path 15
    FDB _BARCELONA_BG_PATH16        ; pointer to path 16
    FDB _BARCELONA_BG_PATH17        ; pointer to path 17
    FDB _BARCELONA_BG_PATH18        ; pointer to path 18
    FDB _BARCELONA_BG_PATH19        ; pointer to path 19
    FDB _BARCELONA_BG_PATH20        ; pointer to path 20
    FDB _BARCELONA_BG_PATH21        ; pointer to path 21
    FDB _BARCELONA_BG_PATH22        ; pointer to path 22
    FDB _BARCELONA_BG_PATH23        ; pointer to path 23
    FDB _BARCELONA_BG_PATH24        ; pointer to path 24
    FDB _BARCELONA_BG_PATH25        ; pointer to path 25
    FDB _BARCELONA_BG_PATH26        ; pointer to path 26
    FDB _BARCELONA_BG_PATH27        ; pointer to path 27
    FDB _BARCELONA_BG_PATH28        ; pointer to path 28
    FDB _BARCELONA_BG_PATH29        ; pointer to path 29
    FDB _BARCELONA_BG_PATH30        ; pointer to path 30
    FDB _BARCELONA_BG_PATH31        ; pointer to path 31
    FDB _BARCELONA_BG_PATH32        ; pointer to path 32
    FDB _BARCELONA_BG_PATH33        ; pointer to path 33
    FDB _BARCELONA_BG_PATH34        ; pointer to path 34
    FDB _BARCELONA_BG_PATH35        ; pointer to path 35
    FDB _BARCELONA_BG_PATH36        ; pointer to path 36
    FDB _BARCELONA_BG_PATH37        ; pointer to path 37
    FDB _BARCELONA_BG_PATH38        ; pointer to path 38
    FDB _BARCELONA_BG_PATH39        ; pointer to path 39
    FDB _BARCELONA_BG_PATH40        ; pointer to path 40
    FDB _BARCELONA_BG_PATH41        ; pointer to path 41
    FDB _BARCELONA_BG_PATH42        ; pointer to path 42
    FDB _BARCELONA_BG_PATH43        ; pointer to path 43
    FDB _BARCELONA_BG_PATH44        ; pointer to path 44
    FDB _BARCELONA_BG_PATH45        ; pointer to path 45
    FDB _BARCELONA_BG_PATH46        ; pointer to path 46
    FDB _BARCELONA_BG_PATH47        ; pointer to path 47
    FDB _BARCELONA_BG_PATH48        ; pointer to path 48
    FDB _BARCELONA_BG_PATH49        ; pointer to path 49
    FDB _BARCELONA_BG_PATH50        ; pointer to path 50
    FDB _BARCELONA_BG_PATH51        ; pointer to path 51
    FDB _BARCELONA_BG_PATH52        ; pointer to path 52
    FDB _BARCELONA_BG_PATH53        ; pointer to path 53
    FDB _BARCELONA_BG_PATH54        ; pointer to path 54
    FDB _BARCELONA_BG_PATH55        ; pointer to path 55
    FDB _BARCELONA_BG_PATH56        ; pointer to path 56
    FDB _BARCELONA_BG_PATH57        ; pointer to path 57
    FDB _BARCELONA_BG_PATH58        ; pointer to path 58
    FDB _BARCELONA_BG_PATH59        ; pointer to path 59

_BARCELONA_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $C0,$C6,0,0        ; path0: header (y=-64, x=-58, relative to center)
    FCB $FF,$0D,$05          ; line 0: flag=-1, dy=13, dx=5
    FCB $FF,$05,$00          ; line 1: flag=-1, dy=5, dx=0
    FCB $FF,$14,$2A          ; line 2: flag=-1, dy=20, dx=42
    FCB $FF,$EB,$2B          ; line 3: flag=-1, dy=-21, dx=43
    FCB $FF,$FD,$FD          ; line 4: flag=-1, dy=-3, dx=-3
    FCB $FF,$F3,$06          ; line 5: flag=-1, dy=-13, dx=6
    FCB $FF,$00,$00          ; line 6: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $C0,$CA,0,0        ; path1: header (y=-64, x=-54, relative to center)
    FCB $FF,$14,$07          ; line 0: flag=-1, dy=20, dx=7
    FCB $FF,$00,$06          ; line 1: flag=-1, dy=0, dx=6
    FCB $FF,$EC,$FA          ; line 2: flag=-1, dy=-20, dx=-6
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $C0,$D4,0,0        ; path2: header (y=-64, x=-44, relative to center)
    FCB $FF,$18,$08          ; line 0: flag=-1, dy=24, dx=8
    FCB $FF,$01,$09          ; line 1: flag=-1, dy=1, dx=9
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $C1,$05,0,0        ; path3: header (y=-63, x=5, relative to center)
    FCB $FF,$18,$F9          ; line 0: flag=-1, dy=24, dx=-7
    FCB $FF,$0A,$F7          ; line 1: flag=-1, dy=10, dx=-9
    FCB $FF,$F6,$F5          ; line 2: flag=-1, dy=-10, dx=-11
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $C0,$F0,0,0        ; path4: header (y=-64, x=-16, relative to center)
    FCB $FF,$0C,$01          ; line 0: flag=-1, dy=12, dx=1
    FCB $FF,$01,$04          ; line 1: flag=-1, dy=1, dx=4
    FCB $FF,$FF,$04          ; line 2: flag=-1, dy=-1, dx=4
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $CC,$F9,0,0        ; path5: header (y=-52, x=-7, relative to center)
    FCB $FF,$F5,$01          ; line 0: flag=-1, dy=-11, dx=1
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $D9,$EA,0,0        ; path6: header (y=-39, x=-22, relative to center)
    FCB $FF,$E7,$F9          ; line 0: flag=-1, dy=-25, dx=-7
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $D9,$E5,0,0        ; path7: header (y=-39, x=-27, relative to center)
    FCB $FF,$E7,$FC          ; line 0: flag=-1, dy=-25, dx=-4
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $C1,$3A,0,0        ; path8: header (y=-63, x=58, relative to center)
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $C1,$09,0,0        ; path9: header (y=-63, x=9, relative to center)
    FCB $FF,$11,$FC          ; line 0: flag=-1, dy=17, dx=-4
    FCB $FF,$08,$FF          ; line 1: flag=-1, dy=8, dx=-1
    FCB $FF,$FF,$09          ; line 2: flag=-1, dy=-1, dx=9
    FCB $FF,$E8,$07          ; line 3: flag=-1, dy=-24, dx=7
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $C1,$16,0,0        ; path10: header (y=-63, x=22, relative to center)
    FCB $FF,$13,$FD          ; line 0: flag=-1, dy=19, dx=-3
    FCB $FF,$00,$04          ; line 1: flag=-1, dy=0, dx=4
    FCB $FF,$ED,$0A          ; line 2: flag=-1, dy=-19, dx=10
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $D5,$CD,0,0        ; path11: header (y=-43, x=-51, relative to center)
    FCB $FF,$16,$28          ; line 0: flag=-1, dy=22, dx=40
    FCB $FF,$EA,$27          ; line 1: flag=-1, dy=-22, dx=39
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $EB,$F5,0,0        ; path12: header (y=-21, x=-11, relative to center)
    FCB $FF,$FB,$00          ; line 0: flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $D8,$CF,0,0        ; path13: header (y=-40, x=-49, relative to center)
    FCB $FF,$0B,$02          ; line 0: flag=-1, dy=11, dx=2
    FCB $FF,$12,$24          ; line 1: flag=-1, dy=18, dx=36
    FCB $FF,$EE,$24          ; line 2: flag=-1, dy=-18, dx=36
    FCB $FF,$F4,$01          ; line 3: flag=-1, dy=-12, dx=1
    FCB $FF,$00,$00          ; line 4: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $E4,$D3,0,0        ; path14: header (y=-28, x=-45, relative to center)
    FCB $FF,$3A,$08          ; line 0: flag=-1, dy=58, dx=8
    FCB $FF,$00,$FF          ; line 1: flag=-1, dy=0, dx=-1
    FCB $FF,$0F,$03          ; line 2: flag=-1, dy=15, dx=3
    FCB $FF,$00,$02          ; line 3: flag=-1, dy=0, dx=2
    FCB $FF,$F2,$02          ; line 4: flag=-1, dy=-14, dx=2
    FCB $FF,$00,$FF          ; line 5: flag=-1, dy=0, dx=-1
    FCB $FF,$CB,$00          ; line 6: flag=-1, dy=-53, dx=0
    FCB $FF,$00,$00          ; line 7: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $EA,$E0,0,0        ; path15: header (y=-22, x=-32, relative to center)
    FCB $FF,$00,$00          ; line 0: flag=-1, dy=0, dx=0
    FCB $FF,$40,$06          ; line 1: flag=-1, dy=64, dx=6
    FCB $FF,$01,$FF          ; line 2: flag=-1, dy=1, dx=-1
    FCB $FF,$0F,$03          ; line 3: flag=-1, dy=15, dx=3
    FCB $FF,$00,$02          ; line 4: flag=-1, dy=0, dx=2
    FCB $FF,$F3,$03          ; line 5: flag=-1, dy=-13, dx=3
    FCB $FF,$FF,$FF          ; line 6: flag=-1, dy=-1, dx=-1
    FCB $FF,$C5,$01          ; line 7: flag=-1, dy=-59, dx=1
    FCB $FF,$00,$00          ; line 8: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $F2,$FC,0,0        ; path16: header (y=-14, x=-4, relative to center)
    FCB $FF,$39,$01          ; line 0: flag=-1, dy=57, dx=1
    FCB $FF,$01,$FF          ; line 1: flag=-1, dy=1, dx=-1
    FCB $FF,$0D,$03          ; line 2: flag=-1, dy=13, dx=3
    FCB $FF,$00,$02          ; line 3: flag=-1, dy=0, dx=2
    FCB $FF,$F1,$02          ; line 4: flag=-1, dy=-15, dx=2
    FCB $FF,$00,$FF          ; line 5: flag=-1, dy=0, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $EA,$0B,0,0        ; path17: header (y=-22, x=11, relative to center)
    FCB $FF,$34,$FE          ; line 0: flag=-1, dy=52, dx=-2
    FCB $FF,$00,$FF          ; line 1: flag=-1, dy=0, dx=-1
    FCB $FF,$0E,$02          ; line 2: flag=-1, dy=14, dx=2
    FCB $FF,$00,$02          ; line 3: flag=-1, dy=0, dx=2
    FCB $FF,$F1,$04          ; line 4: flag=-1, dy=-15, dx=4
    FCB $FF,$00,$FF          ; line 5: flag=-1, dy=0, dx=-1
    FCB $FF,$C7,$08          ; line 6: flag=-1, dy=-57, dx=8
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH18:    ; Path 18
    FCB 127              ; path18: intensity
    FCB $12,$ED,0,0        ; path18: header (y=18, x=-19, relative to center)
    FCB $FF,$03,$07          ; line 0: flag=-1, dy=3, dx=7
    FCB $FF,$FE,$08          ; line 1: flag=-1, dy=-2, dx=8
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH19:    ; Path 19
    FCB 127              ; path19: intensity
    FCB $0B,$ED,0,0        ; path19: header (y=11, x=-19, relative to center)
    FCB $FF,$05,$07          ; line 0: flag=-1, dy=5, dx=7
    FCB $FF,$FC,$08          ; line 1: flag=-1, dy=-4, dx=8
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH20:    ; Path 20
    FCB 127              ; path20: intensity
    FCB $F3,$F1,0,0        ; path20: header (y=-13, x=-15, relative to center)
    FCB $FF,$0F,$00          ; line 0: flag=-1, dy=15, dx=0
    FCB $FF,$08,$03          ; line 1: flag=-1, dy=8, dx=3
    FCB $FF,$F7,$04          ; line 2: flag=-1, dy=-9, dx=4
    FCB $FF,$F2,$01          ; line 3: flag=-1, dy=-14, dx=1
    FCB $FF,$00,$00          ; line 4: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH21:    ; Path 21
    FCB 127              ; path21: intensity
    FCB $2A,$02,0,0        ; path21: header (y=42, x=2, relative to center)
    FCB $FF,$C0,$09          ; line 0: flag=-1, dy=-64, dx=9
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH22:    ; Path 22
    FCB 127              ; path22: intensity
    FCB $2A,$E6,0,0        ; path22: header (y=42, x=-26, relative to center)
    FCB $FF,$01,$06          ; line 0: flag=-1, dy=1, dx=6
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH23:    ; Path 23
    FCB 127              ; path23: intensity
    FCB $1D,$DB,0,0        ; path23: header (y=29, x=-37, relative to center)
    FCB $FF,$01,$05          ; line 0: flag=-1, dy=1, dx=5
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH24:    ; Path 24
    FCB 127              ; path24: intensity
    FCB $2A,$FD,0,0        ; path24: header (y=42, x=-3, relative to center)
    FCB $FF,$FF,$05          ; line 0: flag=-1, dy=-1, dx=5
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH25:    ; Path 25
    FCB 127              ; path25: intensity
    FCB $1D,$09,0,0        ; path25: header (y=29, x=9, relative to center)
    FCB $FF,$FF,$06          ; line 0: flag=-1, dy=-1, dx=6
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH26:    ; Path 26
    FCB 127              ; path26: intensity
    FCB $28,$FE,0,0        ; path26: header (y=40, x=-2, relative to center)
    FCB $FF,$E6,$00          ; line 0: flag=-1, dy=-26, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH27:    ; Path 27
    FCB 127              ; path27: intensity
    FCB $1A,$0B,0,0        ; path27: header (y=26, x=11, relative to center)
    FCB $FF,$E9,$01          ; line 0: flag=-1, dy=-23, dx=1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH28:    ; Path 28
    FCB 127              ; path28: intensity
    FCB $28,$E8,0,0        ; path28: header (y=40, x=-24, relative to center)
    FCB $FF,$E5,$FD          ; line 0: flag=-1, dy=-27, dx=-3
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH29:    ; Path 29
    FCB 127              ; path29: intensity
    FCB $28,$EB,0,0        ; path29: header (y=40, x=-21, relative to center)
    FCB $FF,$E6,$00          ; line 0: flag=-1, dy=-26, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH30:    ; Path 30
    FCB 127              ; path30: intensity
    FCB $0E,$E9,0,0        ; path30: header (y=14, x=-23, relative to center)
    FCB $FF,$00,$00          ; line 0: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH31:    ; Path 31
    FCB 127              ; path31: intensity
    FCB $28,$01,0,0        ; path31: header (y=40, x=1, relative to center)
    FCB $FF,$E5,$03          ; line 0: flag=-1, dy=-27, dx=3
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH32:    ; Path 32
    FCB 127              ; path32: intensity
    FCB $19,$0E,0,0        ; path32: header (y=25, x=14, relative to center)
    FCB $FF,$E9,$03          ; line 0: flag=-1, dy=-23, dx=3
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH33:    ; Path 33
    FCB 127              ; path33: intensity
    FCB $07,$E5,0,0        ; path33: header (y=7, x=-27, relative to center)
    FCB $FF,$F0,$FF          ; line 0: flag=-1, dy=-16, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH34:    ; Path 34
    FCB 127              ; path34: intensity
    FCB $07,$E8,0,0        ; path34: header (y=7, x=-24, relative to center)
    FCB $FF,$F2,$FF          ; line 0: flag=-1, dy=-14, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH35:    ; Path 35
    FCB 127              ; path35: intensity
    FCB $07,$EB,0,0        ; path35: header (y=7, x=-21, relative to center)
    FCB $FF,$F4,$FF          ; line 0: flag=-1, dy=-12, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH36:    ; Path 36
    FCB 127              ; path36: intensity
    FCB $F5,$00,0,0        ; path36: header (y=-11, x=0, relative to center)
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH37:    ; Path 37
    FCB 127              ; path37: intensity
    FCB $F3,$05,0,0        ; path37: header (y=-13, x=5, relative to center)
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH38:    ; Path 38
    FCB 127              ; path38: intensity
    FCB $F0,$08,0,0        ; path38: header (y=-16, x=8, relative to center)
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH39:    ; Path 39
    FCB 127              ; path39: intensity
    FCB $1B,$DC,0,0        ; path39: header (y=27, x=-36, relative to center)
    FCB $FF,$EB,$FE          ; line 0: flag=-1, dy=-21, dx=-2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH40:    ; Path 40
    FCB 127              ; path40: intensity
    FCB $1B,$DE,0,0        ; path40: header (y=27, x=-34, relative to center)
    FCB $FF,$EB,$00          ; line 0: flag=-1, dy=-21, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH41:    ; Path 41
    FCB 127              ; path41: intensity
    FCB $00,$D9,0,0        ; path41: header (y=0, x=-39, relative to center)
    FCB $FF,$F0,$FE          ; line 0: flag=-1, dy=-16, dx=-2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH42:    ; Path 42
    FCB 127              ; path42: intensity
    FCB $00,$DB,0,0        ; path42: header (y=0, x=-37, relative to center)
    FCB $FF,$F1,$FF          ; line 0: flag=-1, dy=-15, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH43:    ; Path 43
    FCB 127              ; path43: intensity
    FCB $00,$DE,0,0        ; path43: header (y=0, x=-34, relative to center)
    FCB $FF,$F3,$FF          ; line 0: flag=-1, dy=-13, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH44:    ; Path 44
    FCB 127              ; path44: intensity
    FCB $3D,$EC,0,0        ; path44: header (y=61, x=-20, relative to center)
    FCB $FF,$03,$FF          ; line 0: flag=-1, dy=3, dx=-1
    FCB $FF,$00,$FD          ; line 1: flag=-1, dy=0, dx=-3
    FCB $FF,$FD,$FF          ; line 2: flag=-1, dy=-3, dx=-1
    FCB $FF,$FD,$01          ; line 3: flag=-1, dy=-3, dx=1
    FCB $FF,$00,$02          ; line 4: flag=-1, dy=0, dx=2
    FCB $FF,$03,$02          ; closing line: flag=-1, dy=3, dx=2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH45:    ; Path 45
    FCB 127              ; path45: intensity
    FCB $30,$E1,0,0        ; path45: header (y=48, x=-31, relative to center)
    FCB $FF,$03,$FF          ; line 0: flag=-1, dy=3, dx=-1
    FCB $FF,$00,$FD          ; line 1: flag=-1, dy=0, dx=-3
    FCB $FF,$FD,$FE          ; line 2: flag=-1, dy=-3, dx=-2
    FCB $FF,$FD,$02          ; line 3: flag=-1, dy=-3, dx=2
    FCB $FF,$00,$02          ; line 4: flag=-1, dy=0, dx=2
    FCB $FF,$03,$02          ; closing line: flag=-1, dy=3, dx=2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH46:    ; Path 46
    FCB 127              ; path46: intensity
    FCB $3C,$03,0,0        ; path46: header (y=60, x=3, relative to center)
    FCB $FF,$03,$FF          ; line 0: flag=-1, dy=3, dx=-1
    FCB $FF,$00,$FC          ; line 1: flag=-1, dy=0, dx=-4
    FCB $FF,$FD,$FF          ; line 2: flag=-1, dy=-3, dx=-1
    FCB $FF,$FD,$02          ; line 3: flag=-1, dy=-3, dx=2
    FCB $FF,$00,$02          ; line 4: flag=-1, dy=0, dx=2
    FCB $FF,$03,$02          ; closing line: flag=-1, dy=3, dx=2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH47:    ; Path 47
    FCB 127              ; path47: intensity
    FCB $2E,$0E,0,0        ; path47: header (y=46, x=14, relative to center)
    FCB $FF,$03,$FF          ; line 0: flag=-1, dy=3, dx=-1
    FCB $FF,$00,$FC          ; line 1: flag=-1, dy=0, dx=-4
    FCB $FF,$FD,$FF          ; line 2: flag=-1, dy=-3, dx=-1
    FCB $FF,$FE,$02          ; line 3: flag=-1, dy=-2, dx=2
    FCB $FF,$00,$02          ; line 4: flag=-1, dy=0, dx=2
    FCB $FF,$02,$02          ; closing line: flag=-1, dy=2, dx=2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH48:    ; Path 48
    FCB 127              ; path48: intensity
    FCB $F2,$0D,0,0        ; path48: header (y=-14, x=13, relative to center)
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH49:    ; Path 49
    FCB 127              ; path49: intensity
    FCB $F0,$10,0,0        ; path49: header (y=-16, x=16, relative to center)
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH50:    ; Path 50
    FCB 127              ; path50: intensity
    FCB $EE,$13,0,0        ; path50: header (y=-18, x=19, relative to center)
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH51:    ; Path 51
    FCB 127              ; path51: intensity
    FCB $01,$EE,0,0        ; path51: header (y=1, x=-18, relative to center)
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH52:    ; Path 52
    FCB 127              ; path52: intensity
    FCB $03,$F1,0,0        ; path52: header (y=3, x=-15, relative to center)
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH53:    ; Path 53
    FCB 127              ; path53: intensity
    FCB $05,$F4,0,0        ; path53: header (y=5, x=-12, relative to center)
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH54:    ; Path 54
    FCB 127              ; path54: intensity
    FCB $07,$05,0,0        ; path54: header (y=7, x=5, relative to center)
    FCB $FF,$F0,$01          ; line 0: flag=-1, dy=-16, dx=1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH55:    ; Path 55
    FCB 127              ; path55: intensity
    FCB $07,$02,0,0        ; path55: header (y=7, x=2, relative to center)
    FCB $FF,$F2,$01          ; line 0: flag=-1, dy=-14, dx=1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH56:    ; Path 56
    FCB 127              ; path56: intensity
    FCB $07,$FF,0,0        ; path56: header (y=7, x=-1, relative to center)
    FCB $FF,$F4,$01          ; line 0: flag=-1, dy=-12, dx=1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH57:    ; Path 57
    FCB 127              ; path57: intensity
    FCB $00,$11,0,0        ; path57: header (y=0, x=17, relative to center)
    FCB $FF,$F0,$02          ; line 0: flag=-1, dy=-16, dx=2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH58:    ; Path 58
    FCB 127              ; path58: intensity
    FCB $00,$0F,0,0        ; path58: header (y=0, x=15, relative to center)
    FCB $FF,$F1,$01          ; line 0: flag=-1, dy=-15, dx=1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH59:    ; Path 59
    FCB 127              ; path59: intensity
    FCB $00,$0C,0,0        ; path59: header (y=0, x=12, relative to center)
    FCB $FF,$F3,$01          ; line 0: flag=-1, dy=-13, dx=1
    FCB 2                ; End marker (path complete)

; Vector asset: bubble_small
; Generated from bubble_small.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 24
; X bounds: min=-10, max=10, width=20
; Center: (0, 0)

_BUBBLE_SMALL_WIDTH EQU 20
_BUBBLE_SMALL_CENTER_X EQU 0
_BUBBLE_SMALL_CENTER_Y EQU 0

_BUBBLE_SMALL_VECTORS:  ; Main entry (header + 1 path(s))
    FCB 1               ; path_count (runtime metadata)
    FDB _BUBBLE_SMALL_PATH0        ; pointer to path 0

_BUBBLE_SMALL_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $00,$0A,0,0        ; path0: header (y=0, x=10, relative to center)
    FCB $FF,$03,$FF          ; line 0: flag=-1, dy=3, dx=-1
    FCB $FF,$02,$00          ; line 1: flag=-1, dy=2, dx=0
    FCB $FF,$02,$FE          ; line 2: flag=-1, dy=2, dx=-2
    FCB $FF,$02,$FE          ; line 3: flag=-1, dy=2, dx=-2
    FCB $FF,$00,$FE          ; line 4: flag=-1, dy=0, dx=-2
    FCB $FF,$01,$FD          ; line 5: flag=-1, dy=1, dx=-3
    FCB $FF,$FF,$FD          ; line 6: flag=-1, dy=-1, dx=-3
    FCB $FF,$00,$FE          ; line 7: flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$FE          ; line 8: flag=-1, dy=-2, dx=-2
    FCB $FF,$FE,$FE          ; line 9: flag=-1, dy=-2, dx=-2
    FCB $FF,$FE,$00          ; line 10: flag=-1, dy=-2, dx=0
    FCB $FF,$FD,$FF          ; line 11: flag=-1, dy=-3, dx=-1
    FCB $FF,$FD,$01          ; line 12: flag=-1, dy=-3, dx=1
    FCB $FF,$FE,$00          ; line 13: flag=-1, dy=-2, dx=0
    FCB $FF,$FE,$02          ; line 14: flag=-1, dy=-2, dx=2
    FCB $FF,$FE,$02          ; line 15: flag=-1, dy=-2, dx=2
    FCB $FF,$00,$02          ; line 16: flag=-1, dy=0, dx=2
    FCB $FF,$FF,$03          ; line 17: flag=-1, dy=-1, dx=3
    FCB $FF,$01,$03          ; line 18: flag=-1, dy=1, dx=3
    FCB $FF,$00,$02          ; line 19: flag=-1, dy=0, dx=2
    FCB $FF,$02,$02          ; line 20: flag=-1, dy=2, dx=2
    FCB $FF,$02,$02          ; line 21: flag=-1, dy=2, dx=2
    FCB $FF,$02,$00          ; line 22: flag=-1, dy=2, dx=0
    FCB $FF,$03,$01          ; closing line: flag=-1, dy=3, dx=1
    FCB 2                ; End marker (path complete)

; Vector asset: logo
; Generated from logo.vec (Malban Draw_Sync_List format)
; Total paths: 7, points: 65
; X bounds: min=-82, max=81, width=163
; Center: (0, 0)

_LOGO_WIDTH EQU 163
_LOGO_CENTER_X EQU 0
_LOGO_CENTER_Y EQU 0

_LOGO_VECTORS:  ; Main entry (header + 7 path(s))
    FCB 7               ; path_count (runtime metadata)
    FDB _LOGO_PATH0        ; pointer to path 0
    FDB _LOGO_PATH1        ; pointer to path 1
    FDB _LOGO_PATH2        ; pointer to path 2
    FDB _LOGO_PATH3        ; pointer to path 3
    FDB _LOGO_PATH4        ; pointer to path 4
    FDB _LOGO_PATH5        ; pointer to path 5
    FDB _LOGO_PATH6        ; pointer to path 6

_LOGO_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $13,$AE,0,0        ; path0: header (y=19, x=-82, relative to center)
    FCB $FF,$EF,$06          ; line 0: flag=-1, dy=-17, dx=6
    FCB $FF,$02,$07          ; line 1: flag=-1, dy=2, dx=7
    FCB $FF,$D6,$09          ; line 2: flag=-1, dy=-42, dx=9
    FCB $FF,$0B,$11          ; line 3: flag=-1, dy=11, dx=17
    FCB $FF,$0C,$FC          ; line 4: flag=-1, dy=12, dx=-4
    FCB $FF,$0D,$10          ; line 5: flag=-1, dy=13, dx=16
    FCB $FF,$0B,$09          ; line 6: flag=-1, dy=11, dx=9
    FCB $FF,$0C,$01          ; line 7: flag=-1, dy=12, dx=1
    FCB $FF,$08,$F8          ; line 8: flag=-1, dy=8, dx=-8
    FCB $FF,$02,$F0          ; line 9: flag=-1, dy=2, dx=-16
    FCB $FF,$FC,$F1          ; line 10: flag=-1, dy=-4, dx=-15
    FCB $FF,$F8,$EA          ; line 11: flag=-1, dy=-8, dx=-22
    FCB $FF,$00,$00          ; line 12: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_LOGO_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $FB,$E3,0,0        ; path1: header (y=-5, x=-29, relative to center)
    FCB $FF,$E7,$F8          ; line 0: flag=-1, dy=-25, dx=-8
    FCB $FF,$04,$10          ; line 1: flag=-1, dy=4, dx=16
    FCB $FF,$0C,$02          ; line 2: flag=-1, dy=12, dx=2
    FCB $FF,$03,$0B          ; line 3: flag=-1, dy=3, dx=11
    FCB $FF,$FA,$00          ; line 4: flag=-1, dy=-6, dx=0
    FCB $FF,$03,$0D          ; line 5: flag=-1, dy=3, dx=13
    FCB $FF,$22,$F7          ; line 6: flag=-1, dy=34, dx=-9
    FCB $FF,$FD,$F1          ; line 7: flag=-1, dy=-3, dx=-15
    FCB $FF,$F5,$FF          ; line 8: flag=-1, dy=-11, dx=-1
    FCB $FF,$F5,$F7          ; line 9: flag=-1, dy=-11, dx=-9
    FCB $FF,$00,$00          ; line 10: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_LOGO_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $07,$CE,0,0        ; path2: header (y=7, x=-50, relative to center)
    FCB $FF,$F8,$02          ; line 0: flag=-1, dy=-8, dx=2
    FCB $FF,$07,$08          ; line 1: flag=-1, dy=7, dx=8
    FCB $FF,$01,$F6          ; line 2: flag=-1, dy=1, dx=-10
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_LOGO_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $06,$F4,0,0        ; path3: header (y=6, x=-12, relative to center)
    FCB $FF,$F6,$FD          ; line 0: flag=-1, dy=-10, dx=-3
    FCB $FF,$02,$07          ; line 1: flag=-1, dy=2, dx=7
    FCB $FF,$08,$FC          ; line 2: flag=-1, dy=8, dx=-4
    FCB $FF,$FE,$01          ; line 3: flag=-1, dy=-2, dx=1
    FCB 2                ; End marker (path complete)

_LOGO_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $F3,$0A,0,0        ; path4: header (y=-13, x=10, relative to center)
    FCB $FF,$29,$02          ; line 0: flag=-1, dy=41, dx=2
    FCB $FF,$02,$0D          ; line 1: flag=-1, dy=2, dx=13
    FCB $FF,$EB,$0A          ; line 2: flag=-1, dy=-21, dx=10
    FCB $FF,$1A,$07          ; line 3: flag=-1, dy=26, dx=7
    FCB $FF,$03,$14          ; line 4: flag=-1, dy=3, dx=20
    FCB $FF,$D8,$EF          ; line 5: flag=-1, dy=-40, dx=-17
    FCB $FF,$FE,$F3          ; line 6: flag=-1, dy=-2, dx=-13
    FCB $FF,$0D,$F8          ; line 7: flag=-1, dy=13, dx=-8
    FCB $FF,$EE,$FC          ; line 8: flag=-1, dy=-18, dx=-4
    FCB $FF,$FC,$F6          ; line 9: flag=-1, dy=-4, dx=-10
    FCB $FF,$00,$00          ; line 10: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_LOGO_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $06,$45,0,0        ; path5: header (y=6, x=69, relative to center)
    FCB $FF,$08,$F5          ; line 0: flag=-1, dy=8, dx=-11
    FCB $FF,$F4,$F7          ; line 1: flag=-1, dy=-12, dx=-9
    FCB $FF,$F7,$01          ; line 2: flag=-1, dy=-9, dx=1
    FCB $FF,$FE,$0C          ; line 3: flag=-1, dy=-2, dx=12
    FCB $FF,$03,$FA          ; line 4: flag=-1, dy=3, dx=-6
    FCB $FF,$05,$01          ; line 5: flag=-1, dy=5, dx=1
    FCB $FF,$02,$17          ; line 6: flag=-1, dy=2, dx=23
    FCB $FF,$F3,$FD          ; line 7: flag=-1, dy=-13, dx=-3
    FCB $FF,$F9,$EE          ; line 8: flag=-1, dy=-7, dx=-18
    FCB $FF,$04,$F0          ; line 9: flag=-1, dy=4, dx=-16
    FCB $FF,$0B,$F8          ; line 10: flag=-1, dy=11, dx=-8
    FCB 2                ; End marker (path complete)

_LOGO_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $06,$45,0,0        ; path6: header (y=6, x=69, relative to center)
    FCB $FF,$00,$0C          ; line 0: flag=-1, dy=0, dx=12
    FCB $FF,$0C,$F8          ; line 1: flag=-1, dy=12, dx=-8
    FCB $FF,$03,$F0          ; line 2: flag=-1, dy=3, dx=-16
    FCB $FF,$FB,$FC          ; line 3: flag=-1, dy=-5, dx=-4
    FCB 2                ; End marker (path complete)

; Vector asset: angkor_bg
; Generated from angkor_bg.vec (Malban Draw_Sync_List format)
; Total paths: 192, points: 648
; X bounds: min=-96, max=96, width=192
; Center: (0, 8)

_ANGKOR_BG_WIDTH EQU 192
_ANGKOR_BG_CENTER_X EQU 0
_ANGKOR_BG_CENTER_Y EQU 8

_ANGKOR_BG_VECTORS:  ; Main entry (header + 192 path(s))
    FCB 192               ; path_count (runtime metadata)
    FDB _ANGKOR_BG_PATH0        ; pointer to path 0
    FDB _ANGKOR_BG_PATH1        ; pointer to path 1
    FDB _ANGKOR_BG_PATH2        ; pointer to path 2
    FDB _ANGKOR_BG_PATH3        ; pointer to path 3
    FDB _ANGKOR_BG_PATH4        ; pointer to path 4
    FDB _ANGKOR_BG_PATH5        ; pointer to path 5
    FDB _ANGKOR_BG_PATH6        ; pointer to path 6
    FDB _ANGKOR_BG_PATH7        ; pointer to path 7
    FDB _ANGKOR_BG_PATH8        ; pointer to path 8
    FDB _ANGKOR_BG_PATH9        ; pointer to path 9
    FDB _ANGKOR_BG_PATH10        ; pointer to path 10
    FDB _ANGKOR_BG_PATH11        ; pointer to path 11
    FDB _ANGKOR_BG_PATH12        ; pointer to path 12
    FDB _ANGKOR_BG_PATH13        ; pointer to path 13
    FDB _ANGKOR_BG_PATH14        ; pointer to path 14
    FDB _ANGKOR_BG_PATH15        ; pointer to path 15
    FDB _ANGKOR_BG_PATH16        ; pointer to path 16
    FDB _ANGKOR_BG_PATH17        ; pointer to path 17
    FDB _ANGKOR_BG_PATH18        ; pointer to path 18
    FDB _ANGKOR_BG_PATH19        ; pointer to path 19
    FDB _ANGKOR_BG_PATH20        ; pointer to path 20
    FDB _ANGKOR_BG_PATH21        ; pointer to path 21
    FDB _ANGKOR_BG_PATH22        ; pointer to path 22
    FDB _ANGKOR_BG_PATH23        ; pointer to path 23
    FDB _ANGKOR_BG_PATH24        ; pointer to path 24
    FDB _ANGKOR_BG_PATH25        ; pointer to path 25
    FDB _ANGKOR_BG_PATH26        ; pointer to path 26
    FDB _ANGKOR_BG_PATH27        ; pointer to path 27
    FDB _ANGKOR_BG_PATH28        ; pointer to path 28
    FDB _ANGKOR_BG_PATH29        ; pointer to path 29
    FDB _ANGKOR_BG_PATH30        ; pointer to path 30
    FDB _ANGKOR_BG_PATH31        ; pointer to path 31
    FDB _ANGKOR_BG_PATH32        ; pointer to path 32
    FDB _ANGKOR_BG_PATH33        ; pointer to path 33
    FDB _ANGKOR_BG_PATH34        ; pointer to path 34
    FDB _ANGKOR_BG_PATH35        ; pointer to path 35
    FDB _ANGKOR_BG_PATH36        ; pointer to path 36
    FDB _ANGKOR_BG_PATH37        ; pointer to path 37
    FDB _ANGKOR_BG_PATH38        ; pointer to path 38
    FDB _ANGKOR_BG_PATH39        ; pointer to path 39
    FDB _ANGKOR_BG_PATH40        ; pointer to path 40
    FDB _ANGKOR_BG_PATH41        ; pointer to path 41
    FDB _ANGKOR_BG_PATH42        ; pointer to path 42
    FDB _ANGKOR_BG_PATH43        ; pointer to path 43
    FDB _ANGKOR_BG_PATH44        ; pointer to path 44
    FDB _ANGKOR_BG_PATH45        ; pointer to path 45
    FDB _ANGKOR_BG_PATH46        ; pointer to path 46
    FDB _ANGKOR_BG_PATH47        ; pointer to path 47
    FDB _ANGKOR_BG_PATH48        ; pointer to path 48
    FDB _ANGKOR_BG_PATH49        ; pointer to path 49
    FDB _ANGKOR_BG_PATH50        ; pointer to path 50
    FDB _ANGKOR_BG_PATH51        ; pointer to path 51
    FDB _ANGKOR_BG_PATH52        ; pointer to path 52
    FDB _ANGKOR_BG_PATH53        ; pointer to path 53
    FDB _ANGKOR_BG_PATH54        ; pointer to path 54
    FDB _ANGKOR_BG_PATH55        ; pointer to path 55
    FDB _ANGKOR_BG_PATH56        ; pointer to path 56
    FDB _ANGKOR_BG_PATH57        ; pointer to path 57
    FDB _ANGKOR_BG_PATH58        ; pointer to path 58
    FDB _ANGKOR_BG_PATH59        ; pointer to path 59
    FDB _ANGKOR_BG_PATH60        ; pointer to path 60
    FDB _ANGKOR_BG_PATH61        ; pointer to path 61
    FDB _ANGKOR_BG_PATH62        ; pointer to path 62
    FDB _ANGKOR_BG_PATH63        ; pointer to path 63
    FDB _ANGKOR_BG_PATH64        ; pointer to path 64
    FDB _ANGKOR_BG_PATH65        ; pointer to path 65
    FDB _ANGKOR_BG_PATH66        ; pointer to path 66
    FDB _ANGKOR_BG_PATH67        ; pointer to path 67
    FDB _ANGKOR_BG_PATH68        ; pointer to path 68
    FDB _ANGKOR_BG_PATH69        ; pointer to path 69
    FDB _ANGKOR_BG_PATH70        ; pointer to path 70
    FDB _ANGKOR_BG_PATH71        ; pointer to path 71
    FDB _ANGKOR_BG_PATH72        ; pointer to path 72
    FDB _ANGKOR_BG_PATH73        ; pointer to path 73
    FDB _ANGKOR_BG_PATH74        ; pointer to path 74
    FDB _ANGKOR_BG_PATH75        ; pointer to path 75
    FDB _ANGKOR_BG_PATH76        ; pointer to path 76
    FDB _ANGKOR_BG_PATH77        ; pointer to path 77
    FDB _ANGKOR_BG_PATH78        ; pointer to path 78
    FDB _ANGKOR_BG_PATH79        ; pointer to path 79
    FDB _ANGKOR_BG_PATH80        ; pointer to path 80
    FDB _ANGKOR_BG_PATH81        ; pointer to path 81
    FDB _ANGKOR_BG_PATH82        ; pointer to path 82
    FDB _ANGKOR_BG_PATH83        ; pointer to path 83
    FDB _ANGKOR_BG_PATH84        ; pointer to path 84
    FDB _ANGKOR_BG_PATH85        ; pointer to path 85
    FDB _ANGKOR_BG_PATH86        ; pointer to path 86
    FDB _ANGKOR_BG_PATH87        ; pointer to path 87
    FDB _ANGKOR_BG_PATH88        ; pointer to path 88
    FDB _ANGKOR_BG_PATH89        ; pointer to path 89
    FDB _ANGKOR_BG_PATH90        ; pointer to path 90
    FDB _ANGKOR_BG_PATH91        ; pointer to path 91
    FDB _ANGKOR_BG_PATH92        ; pointer to path 92
    FDB _ANGKOR_BG_PATH93        ; pointer to path 93
    FDB _ANGKOR_BG_PATH94        ; pointer to path 94
    FDB _ANGKOR_BG_PATH95        ; pointer to path 95
    FDB _ANGKOR_BG_PATH96        ; pointer to path 96
    FDB _ANGKOR_BG_PATH97        ; pointer to path 97
    FDB _ANGKOR_BG_PATH98        ; pointer to path 98
    FDB _ANGKOR_BG_PATH99        ; pointer to path 99
    FDB _ANGKOR_BG_PATH100        ; pointer to path 100
    FDB _ANGKOR_BG_PATH101        ; pointer to path 101
    FDB _ANGKOR_BG_PATH102        ; pointer to path 102
    FDB _ANGKOR_BG_PATH103        ; pointer to path 103
    FDB _ANGKOR_BG_PATH104        ; pointer to path 104
    FDB _ANGKOR_BG_PATH105        ; pointer to path 105
    FDB _ANGKOR_BG_PATH106        ; pointer to path 106
    FDB _ANGKOR_BG_PATH107        ; pointer to path 107
    FDB _ANGKOR_BG_PATH108        ; pointer to path 108
    FDB _ANGKOR_BG_PATH109        ; pointer to path 109
    FDB _ANGKOR_BG_PATH110        ; pointer to path 110
    FDB _ANGKOR_BG_PATH111        ; pointer to path 111
    FDB _ANGKOR_BG_PATH112        ; pointer to path 112
    FDB _ANGKOR_BG_PATH113        ; pointer to path 113
    FDB _ANGKOR_BG_PATH114        ; pointer to path 114
    FDB _ANGKOR_BG_PATH115        ; pointer to path 115
    FDB _ANGKOR_BG_PATH116        ; pointer to path 116
    FDB _ANGKOR_BG_PATH117        ; pointer to path 117
    FDB _ANGKOR_BG_PATH118        ; pointer to path 118
    FDB _ANGKOR_BG_PATH119        ; pointer to path 119
    FDB _ANGKOR_BG_PATH120        ; pointer to path 120
    FDB _ANGKOR_BG_PATH121        ; pointer to path 121
    FDB _ANGKOR_BG_PATH122        ; pointer to path 122
    FDB _ANGKOR_BG_PATH123        ; pointer to path 123
    FDB _ANGKOR_BG_PATH124        ; pointer to path 124
    FDB _ANGKOR_BG_PATH125        ; pointer to path 125
    FDB _ANGKOR_BG_PATH126        ; pointer to path 126
    FDB _ANGKOR_BG_PATH127        ; pointer to path 127
    FDB _ANGKOR_BG_PATH128        ; pointer to path 128
    FDB _ANGKOR_BG_PATH129        ; pointer to path 129
    FDB _ANGKOR_BG_PATH130        ; pointer to path 130
    FDB _ANGKOR_BG_PATH131        ; pointer to path 131
    FDB _ANGKOR_BG_PATH132        ; pointer to path 132
    FDB _ANGKOR_BG_PATH133        ; pointer to path 133
    FDB _ANGKOR_BG_PATH134        ; pointer to path 134
    FDB _ANGKOR_BG_PATH135        ; pointer to path 135
    FDB _ANGKOR_BG_PATH136        ; pointer to path 136
    FDB _ANGKOR_BG_PATH137        ; pointer to path 137
    FDB _ANGKOR_BG_PATH138        ; pointer to path 138
    FDB _ANGKOR_BG_PATH139        ; pointer to path 139
    FDB _ANGKOR_BG_PATH140        ; pointer to path 140
    FDB _ANGKOR_BG_PATH141        ; pointer to path 141
    FDB _ANGKOR_BG_PATH142        ; pointer to path 142
    FDB _ANGKOR_BG_PATH143        ; pointer to path 143
    FDB _ANGKOR_BG_PATH144        ; pointer to path 144
    FDB _ANGKOR_BG_PATH145        ; pointer to path 145
    FDB _ANGKOR_BG_PATH146        ; pointer to path 146
    FDB _ANGKOR_BG_PATH147        ; pointer to path 147
    FDB _ANGKOR_BG_PATH148        ; pointer to path 148
    FDB _ANGKOR_BG_PATH149        ; pointer to path 149
    FDB _ANGKOR_BG_PATH150        ; pointer to path 150
    FDB _ANGKOR_BG_PATH151        ; pointer to path 151
    FDB _ANGKOR_BG_PATH152        ; pointer to path 152
    FDB _ANGKOR_BG_PATH153        ; pointer to path 153
    FDB _ANGKOR_BG_PATH154        ; pointer to path 154
    FDB _ANGKOR_BG_PATH155        ; pointer to path 155
    FDB _ANGKOR_BG_PATH156        ; pointer to path 156
    FDB _ANGKOR_BG_PATH157        ; pointer to path 157
    FDB _ANGKOR_BG_PATH158        ; pointer to path 158
    FDB _ANGKOR_BG_PATH159        ; pointer to path 159
    FDB _ANGKOR_BG_PATH160        ; pointer to path 160
    FDB _ANGKOR_BG_PATH161        ; pointer to path 161
    FDB _ANGKOR_BG_PATH162        ; pointer to path 162
    FDB _ANGKOR_BG_PATH163        ; pointer to path 163
    FDB _ANGKOR_BG_PATH164        ; pointer to path 164
    FDB _ANGKOR_BG_PATH165        ; pointer to path 165
    FDB _ANGKOR_BG_PATH166        ; pointer to path 166
    FDB _ANGKOR_BG_PATH167        ; pointer to path 167
    FDB _ANGKOR_BG_PATH168        ; pointer to path 168
    FDB _ANGKOR_BG_PATH169        ; pointer to path 169
    FDB _ANGKOR_BG_PATH170        ; pointer to path 170
    FDB _ANGKOR_BG_PATH171        ; pointer to path 171
    FDB _ANGKOR_BG_PATH172        ; pointer to path 172
    FDB _ANGKOR_BG_PATH173        ; pointer to path 173
    FDB _ANGKOR_BG_PATH174        ; pointer to path 174
    FDB _ANGKOR_BG_PATH175        ; pointer to path 175
    FDB _ANGKOR_BG_PATH176        ; pointer to path 176
    FDB _ANGKOR_BG_PATH177        ; pointer to path 177
    FDB _ANGKOR_BG_PATH178        ; pointer to path 178
    FDB _ANGKOR_BG_PATH179        ; pointer to path 179
    FDB _ANGKOR_BG_PATH180        ; pointer to path 180
    FDB _ANGKOR_BG_PATH181        ; pointer to path 181
    FDB _ANGKOR_BG_PATH182        ; pointer to path 182
    FDB _ANGKOR_BG_PATH183        ; pointer to path 183
    FDB _ANGKOR_BG_PATH184        ; pointer to path 184
    FDB _ANGKOR_BG_PATH185        ; pointer to path 185
    FDB _ANGKOR_BG_PATH186        ; pointer to path 186
    FDB _ANGKOR_BG_PATH187        ; pointer to path 187
    FDB _ANGKOR_BG_PATH188        ; pointer to path 188
    FDB _ANGKOR_BG_PATH189        ; pointer to path 189
    FDB _ANGKOR_BG_PATH190        ; pointer to path 190
    FDB _ANGKOR_BG_PATH191        ; pointer to path 191

_ANGKOR_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $CA,$A0,0,0        ; path0: header (y=-54, x=-96, relative to center)
    FCB $FF,$0D,$00          ; line 0: flag=-1, dy=13, dx=0
    FCB $FF,$00,$4C          ; line 1: flag=-1, dy=0, dx=76
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $D2,$A0,0,0        ; path1: header (y=-46, x=-96, relative to center)
    FCB $FF,$00,$4C          ; line 0: flag=-1, dy=0, dx=76
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $D8,$EC,0,0        ; path2: header (y=-40, x=-20, relative to center)
    FCB $FF,$F8,$00          ; line 0: flag=-1, dy=-8, dx=0
    FCB $FF,$00,$07          ; line 1: flag=-1, dy=0, dx=7
    FCB $FF,$FF,$02          ; line 2: flag=-1, dy=-1, dx=2
    FCB $FF,$09,$00          ; line 3: flag=-1, dy=9, dx=0
    FCB $FF,$00,$F7          ; line 4: flag=-1, dy=0, dx=-9
    FCB $FF,$00,$00          ; line 5: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $D8,$EE,0,0        ; path3: header (y=-40, x=-18, relative to center)
    FCB $FF,$0F,$00          ; line 0: flag=-1, dy=15, dx=0
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $E3,$EE,0,0        ; path4: header (y=-29, x=-18, relative to center)
    FCB $FF,$00,$B6          ; line 0: flag=-1, dy=0, dx=-74
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $E3,$A4,0,0        ; path5: header (y=-29, x=-92, relative to center)
    FCB $FF,$06,$00          ; line 0: flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $E9,$A4,0,0        ; path6: header (y=-23, x=-92, relative to center)
    FCB $FF,$00,$49          ; line 0: flag=-1, dy=0, dx=73
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $E7,$F5,0,0        ; path7: header (y=-25, x=-11, relative to center)
    FCB $FF,$00,$F8          ; line 0: flag=-1, dy=0, dx=-8
    FCB $FF,$04,$00          ; line 1: flag=-1, dy=4, dx=0
    FCB $FF,$01,$02          ; line 2: flag=-1, dy=1, dx=2
    FCB $FF,$01,$03          ; line 3: flag=-1, dy=1, dx=3
    FCB $FF,$02,$FF          ; line 4: flag=-1, dy=2, dx=-1
    FCB $FF,$02,$01          ; line 5: flag=-1, dy=2, dx=1
    FCB $FF,$00,$03          ; line 6: flag=-1, dy=0, dx=3
    FCB $FF,$00,$00          ; line 7: flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; line 8: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $FC,$00,0,0        ; path8: header (y=-4, x=0, relative to center)
    FCB $FF,$F5,$F5          ; line 0: flag=-1, dy=-11, dx=-11
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $E3,$A5,0,0        ; path9: header (y=-29, x=-91, relative to center)
    FCB $FF,$F4,$00          ; line 0: flag=-1, dy=-12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $E3,$B1,0,0        ; path10: header (y=-29, x=-79, relative to center)
    FCB $FF,$F4,$00          ; line 0: flag=-1, dy=-12, dx=0
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $E3,$BE,0,0        ; path11: header (y=-29, x=-66, relative to center)
    FCB $FF,$F4,$00          ; line 0: flag=-1, dy=-12, dx=0
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $E3,$CA,0,0        ; path12: header (y=-29, x=-54, relative to center)
    FCB $FF,$F4,$00          ; line 0: flag=-1, dy=-12, dx=0
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $E3,$D8,0,0        ; path13: header (y=-29, x=-40, relative to center)
    FCB $FF,$F4,$00          ; line 0: flag=-1, dy=-12, dx=0
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $E9,$A9,0,0        ; path14: header (y=-23, x=-87, relative to center)
    FCB $FF,$0E,$00          ; line 0: flag=-1, dy=14, dx=0
    FCB $FF,$00,$31          ; line 1: flag=-1, dy=0, dx=49
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $F7,$BB,0,0        ; path15: header (y=-9, x=-69, relative to center)
    FCB $FF,$F2,$00          ; line 0: flag=-1, dy=-14, dx=0
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $F0,$A9,0,0        ; path16: header (y=-16, x=-87, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $F0,$BB,0,0        ; path17: header (y=-16, x=-69, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH18:    ; Path 18
    FCB 127              ; path18: intensity
    FCB $FD,$DA,0,0        ; path18: header (y=-3, x=-38, relative to center)
    FCB $FF,$EC,$00          ; line 0: flag=-1, dy=-20, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH19:    ; Path 19
    FCB 127              ; path19: intensity
    FCB $F7,$B3,0,0        ; path19: header (y=-9, x=-77, relative to center)
    FCB $FF,$10,$00          ; line 0: flag=-1, dy=16, dx=0
    FCB $FF,$00,$1B          ; line 1: flag=-1, dy=0, dx=27
    FCB $FF,$F0,$00          ; line 2: flag=-1, dy=-16, dx=0
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH20:    ; Path 20
    FCB 127              ; path20: intensity
    FCB $07,$B4,0,0        ; path20: header (y=7, x=-76, relative to center)
    FCB $FF,$03,$00          ; line 0: flag=-1, dy=3, dx=0
    FCB $FF,$02,$FD          ; line 1: flag=-1, dy=2, dx=-3
    FCB $FF,$06,$00          ; line 2: flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH21:    ; Path 21
    FCB 127              ; path21: intensity
    FCB $07,$B8,0,0        ; path21: header (y=7, x=-72, relative to center)
    FCB $FF,$07,$00          ; line 0: flag=-1, dy=7, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH22:    ; Path 22
    FCB 127              ; path22: intensity
    FCB $07,$C7,0,0        ; path22: header (y=7, x=-57, relative to center)
    FCB $FF,$07,$00          ; line 0: flag=-1, dy=7, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH23:    ; Path 23
    FCB 127              ; path23: intensity
    FCB $07,$CB,0,0        ; path23: header (y=7, x=-53, relative to center)
    FCB $FF,$03,$00          ; line 0: flag=-1, dy=3, dx=0
    FCB $FF,$02,$03          ; line 1: flag=-1, dy=2, dx=3
    FCB $FF,$06,$00          ; line 2: flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH24:    ; Path 24
    FCB 127              ; path24: intensity
    FCB $0C,$B1,0,0        ; path24: header (y=12, x=-79, relative to center)
    FCB $FF,$02,$05          ; line 0: flag=-1, dy=2, dx=5
    FCB $FF,$00,$10          ; line 1: flag=-1, dy=0, dx=16
    FCB $FF,$00,$03          ; line 2: flag=-1, dy=0, dx=3
    FCB $FF,$FE,$05          ; line 3: flag=-1, dy=-2, dx=5
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH25:    ; Path 25
    FCB 127              ; path25: intensity
    FCB $0E,$B9,0,0        ; path25: header (y=14, x=-71, relative to center)
    FCB $FF,$08,$00          ; line 0: flag=-1, dy=8, dx=0
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB $FF,$00,$0E          ; line 2: flag=-1, dy=0, dx=14
    FCB $FF,$FE,$05          ; line 3: flag=-1, dy=-2, dx=5
    FCB $FF,$05,$00          ; line 4: flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH26:    ; Path 26
    FCB 127              ; path26: intensity
    FCB $16,$C6,0,0        ; path26: header (y=22, x=-58, relative to center)
    FCB $FF,$F8,$00          ; line 0: flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH27:    ; Path 27
    FCB 127              ; path27: intensity
    FCB $16,$B9,0,0        ; path27: header (y=22, x=-71, relative to center)
    FCB $FF,$00,$FF          ; line 0: flag=-1, dy=0, dx=-1
    FCB $FF,$FE,$FB          ; line 1: flag=-1, dy=-2, dx=-5
    FCB $FF,$05,$00          ; line 2: flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH28:    ; Path 28
    FCB 127              ; path28: intensity
    FCB $14,$CC,0,0        ; path28: header (y=20, x=-52, relative to center)
    FCB $FF,$FE,$FE          ; line 0: flag=-1, dy=-2, dx=-2
    FCB $FF,$FD,$00          ; line 1: flag=-1, dy=-3, dx=0
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH29:    ; Path 29
    FCB 127              ; path29: intensity
    FCB $14,$B3,0,0        ; path29: header (y=20, x=-77, relative to center)
    FCB $FF,$FE,$02          ; line 0: flag=-1, dy=-2, dx=2
    FCB $FF,$FD,$00          ; line 1: flag=-1, dy=-3, dx=0
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH30:    ; Path 30
    FCB 127              ; path30: intensity
    FCB $16,$BA,0,0        ; path30: header (y=22, x=-70, relative to center)
    FCB $FF,$08,$00          ; line 0: flag=-1, dy=8, dx=0
    FCB $FF,$00,$0B          ; line 1: flag=-1, dy=0, dx=11
    FCB $FF,$F8,$00          ; line 2: flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH31:    ; Path 31
    FCB 127              ; path31: intensity
    FCB $1E,$BA,0,0        ; path31: header (y=30, x=-70, relative to center)
    FCB $FF,$FE,$FA          ; line 0: flag=-1, dy=-2, dx=-6
    FCB $FF,$05,$00          ; line 1: flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH32:    ; Path 32
    FCB 127              ; path32: intensity
    FCB $1C,$B4,0,0        ; path32: header (y=28, x=-76, relative to center)
    FCB $FF,$FE,$02          ; line 0: flag=-1, dy=-2, dx=2
    FCB $FF,$FD,$00          ; line 1: flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH33:    ; Path 33
    FCB 127              ; path33: intensity
    FCB $1E,$C5,0,0        ; path33: header (y=30, x=-59, relative to center)
    FCB $FF,$FE,$06          ; line 0: flag=-1, dy=-2, dx=6
    FCB $FF,$04,$00          ; line 1: flag=-1, dy=4, dx=0
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH34:    ; Path 34
    FCB 127              ; path34: intensity
    FCB $1C,$CB,0,0        ; path34: header (y=28, x=-53, relative to center)
    FCB $FF,$FE,$FE          ; line 0: flag=-1, dy=-2, dx=-2
    FCB $FF,$FD,$00          ; line 1: flag=-1, dy=-3, dx=0
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH35:    ; Path 35
    FCB 127              ; path35: intensity
    FCB $1E,$B9,0,0        ; path35: header (y=30, x=-71, relative to center)
    FCB $FF,$03,$00          ; line 0: flag=-1, dy=3, dx=0
    FCB $FF,$01,$FE          ; line 1: flag=-1, dy=1, dx=-2
    FCB $FF,$05,$00          ; line 2: flag=-1, dy=5, dx=0
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH36:    ; Path 36
    FCB 127              ; path36: intensity
    FCB $23,$B7,0,0        ; path36: header (y=35, x=-73, relative to center)
    FCB $FF,$01,$04          ; line 0: flag=-1, dy=1, dx=4
    FCB $FF,$00,$09          ; line 1: flag=-1, dy=0, dx=9
    FCB $FF,$FF,$04          ; line 2: flag=-1, dy=-1, dx=4
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH37:    ; Path 37
    FCB 127              ; path37: intensity
    FCB $1E,$C6,0,0        ; path37: header (y=30, x=-58, relative to center)
    FCB $FF,$02,$00          ; line 0: flag=-1, dy=2, dx=0
    FCB $FF,$03,$02          ; line 1: flag=-1, dy=3, dx=2
    FCB $FF,$04,$00          ; line 2: flag=-1, dy=4, dx=0
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH38:    ; Path 38
    FCB 127              ; path38: intensity
    FCB $24,$BC,0,0        ; path38: header (y=36, x=-68, relative to center)
    FCB $FF,$FA,$00          ; line 0: flag=-1, dy=-6, dx=0
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH39:    ; Path 39
    FCB 127              ; path39: intensity
    FCB $1E,$C3,0,0        ; path39: header (y=30, x=-61, relative to center)
    FCB $FF,$06,$00          ; line 0: flag=-1, dy=6, dx=0
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH40:    ; Path 40
    FCB 127              ; path40: intensity
    FCB $24,$B9,0,0        ; path40: header (y=36, x=-71, relative to center)
    FCB $FF,$05,$00          ; line 0: flag=-1, dy=5, dx=0
    FCB $FF,$00,$0D          ; line 1: flag=-1, dy=0, dx=13
    FCB $FF,$FB,$00          ; line 2: flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH41:    ; Path 41
    FCB 127              ; path41: intensity
    FCB $29,$BA,0,0        ; path41: header (y=41, x=-70, relative to center)
    FCB $FF,$04,$00          ; line 0: flag=-1, dy=4, dx=0
    FCB $FF,$00,$0B          ; line 1: flag=-1, dy=0, dx=11
    FCB $FF,$FC,$00          ; line 2: flag=-1, dy=-4, dx=0
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH42:    ; Path 42
    FCB 127              ; path42: intensity
    FCB $2D,$BC,0,0        ; path42: header (y=45, x=-68, relative to center)
    FCB $FF,$03,$00          ; line 0: flag=-1, dy=3, dx=0
    FCB $FF,$00,$07          ; line 1: flag=-1, dy=0, dx=7
    FCB $FF,$FD,$00          ; line 2: flag=-1, dy=-3, dx=0
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH43:    ; Path 43
    FCB 127              ; path43: intensity
    FCB $30,$BD,0,0        ; path43: header (y=48, x=-67, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH44:    ; Path 44
    FCB 127              ; path44: intensity
    FCB $30,$C2,0,0        ; path44: header (y=48, x=-62, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH45:    ; Path 45
    FCB 127              ; path45: intensity
    FCB $33,$B7,0,0        ; path45: header (y=51, x=-73, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH46:    ; Path 46
    FCB 127              ; path46: intensity
    FCB $33,$C2,0,0        ; path46: header (y=51, x=-62, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH47:    ; Path 47
    FCB 127              ; path47: intensity
    FCB $30,$BD,0,0        ; path47: header (y=48, x=-67, relative to center)
    FCB $FF,$03,$00          ; line 0: flag=-1, dy=3, dx=0
    FCB $FF,$00,$05          ; line 1: flag=-1, dy=0, dx=5
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH48:    ; Path 48
    FCB 127              ; path48: intensity
    FCB $30,$C2,0,0        ; path48: header (y=48, x=-62, relative to center)
    FCB $FF,$03,$00          ; line 0: flag=-1, dy=3, dx=0
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH49:    ; Path 49
    FCB 127              ; path49: intensity
    FCB $07,$B9,0,0        ; path49: header (y=7, x=-71, relative to center)
    FCB $FF,$F0,$00          ; line 0: flag=-1, dy=-16, dx=0
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH50:    ; Path 50
    FCB 127              ; path50: intensity
    FCB $F7,$C6,0,0        ; path50: header (y=-9, x=-58, relative to center)
    FCB $FF,$10,$00          ; line 0: flag=-1, dy=16, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH51:    ; Path 51
    FCB 127              ; path51: intensity
    FCB $04,$BC,0,0        ; path51: header (y=4, x=-68, relative to center)
    FCB $FF,$00,$07          ; line 0: flag=-1, dy=0, dx=7
    FCB $FF,$F7,$00          ; line 1: flag=-1, dy=-9, dx=0
    FCB $FF,$00,$F9          ; line 2: flag=-1, dy=0, dx=-7
    FCB $FF,$09,$00          ; line 3: flag=-1, dy=9, dx=0
    FCB $FF,$00,$00          ; line 4: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH52:    ; Path 52
    FCB 127              ; path52: intensity
    FCB $07,$BC,0,0        ; path52: header (y=7, x=-68, relative to center)
    FCB $FF,$04,$00          ; line 0: flag=-1, dy=4, dx=0
    FCB $FF,$02,$03          ; line 1: flag=-1, dy=2, dx=3
    FCB $FF,$FE,$03          ; line 2: flag=-1, dy=-2, dx=3
    FCB $FF,$FC,$00          ; line 3: flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH53:    ; Path 53
    FCB 127              ; path53: intensity
    FCB $E3,$E5,0,0        ; path53: header (y=-29, x=-27, relative to center)
    FCB $FF,$F4,$00          ; line 0: flag=-1, dy=-12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH54:    ; Path 54
    FCB 127              ; path54: intensity
    FCB $EC,$F5,0,0        ; path54: header (y=-20, x=-11, relative to center)
    FCB $FF,$EE,$00          ; line 0: flag=-1, dy=-18, dx=0
    FCB $FF,$00,$FB          ; line 1: flag=-1, dy=0, dx=-5
    FCB $FF,$09,$00          ; line 2: flag=-1, dy=9, dx=0
    FCB $FF,$00,$05          ; line 3: flag=-1, dy=0, dx=5
    FCB $FF,$00,$00          ; line 4: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH55:    ; Path 55
    FCB 127              ; path55: intensity
    FCB $F3,$FC,0,0        ; path55: header (y=-13, x=-4, relative to center)
    FCB $FF,$FC,$FD          ; line 0: flag=-1, dy=-4, dx=-3
    FCB $FF,$E9,$00          ; line 1: flag=-1, dy=-23, dx=0
    FCB $FF,$00,$07          ; line 2: flag=-1, dy=0, dx=7
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH56:    ; Path 56
    FCB 127              ; path56: intensity
    FCB $F3,$FC,0,0        ; path56: header (y=-13, x=-4, relative to center)
    FCB $FF,$01,$04          ; line 0: flag=-1, dy=1, dx=4
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH57:    ; Path 57
    FCB 127              ; path57: intensity
    FCB $F2,$A9,0,0        ; path57: header (y=-14, x=-87, relative to center)
    FCB $FF,$00,$4A          ; line 0: flag=-1, dy=0, dx=74
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH58:    ; Path 58
    FCB 127              ; path58: intensity
    FCB $D0,$EC,0,0        ; path58: header (y=-48, x=-20, relative to center)
    FCB $FF,$00,$FA          ; line 0: flag=-1, dy=0, dx=-6
    FCB $FF,$F2,$00          ; line 1: flag=-1, dy=-14, dx=0
    FCB $FF,$00,$0B          ; line 2: flag=-1, dy=0, dx=11
    FCB $FF,$0E,$00          ; line 3: flag=-1, dy=14, dx=0
    FCB $FF,$00,$00          ; line 4: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH59:    ; Path 59
    FCB 127              ; path59: intensity
    FCB $D4,$F7,0,0        ; path59: header (y=-44, x=-9, relative to center)
    FCB $FF,$00,$09          ; line 0: flag=-1, dy=0, dx=9
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH60:    ; Path 60
    FCB 127              ; path60: intensity
    FCB $D1,$00,0,0        ; path60: header (y=-47, x=0, relative to center)
    FCB $FF,$00,$F6          ; line 0: flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH61:    ; Path 61
    FCB 127              ; path61: intensity
    FCB $CC,$F4,0,0        ; path61: header (y=-52, x=-12, relative to center)
    FCB $FF,$00,$0C          ; line 0: flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH62:    ; Path 62
    FCB 127              ; path62: intensity
    FCB $C7,$00,0,0        ; path62: header (y=-57, x=0, relative to center)
    FCB $FF,$00,$F3          ; line 0: flag=-1, dy=0, dx=-13
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH63:    ; Path 63
    FCB 127              ; path63: intensity
    FCB $C0,$F2,0,0        ; path63: header (y=-64, x=-14, relative to center)
    FCB $FF,$00,$0E          ; line 0: flag=-1, dy=0, dx=14
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH64:    ; Path 64
    FCB 127              ; path64: intensity
    FCB $FD,$F5,0,0        ; path64: header (y=-3, x=-11, relative to center)
    FCB $FF,$00,$E3          ; line 0: flag=-1, dy=0, dx=-29
    FCB $FF,$09,$00          ; line 1: flag=-1, dy=9, dx=0
    FCB $FF,$00,$1D          ; line 2: flag=-1, dy=0, dx=29
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH65:    ; Path 65
    FCB 127              ; path65: intensity
    FCB $FD,$F5,0,0        ; path65: header (y=-3, x=-11, relative to center)
    FCB $FF,$09,$00          ; line 0: flag=-1, dy=9, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH66:    ; Path 66
    FCB 127              ; path66: intensity
    FCB $07,$CE,0,0        ; path66: header (y=7, x=-50, relative to center)
    FCB $FF,$04,$00          ; line 0: flag=-1, dy=4, dx=0
    FCB $FF,$00,$2D          ; line 1: flag=-1, dy=0, dx=45
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH67:    ; Path 67
    FCB 127              ; path67: intensity
    FCB $F4,$00,0,0        ; path67: header (y=-12, x=0, relative to center)
    FCB $FF,$00,$00          ; line 0: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH68:    ; Path 68
    FCB 127              ; path68: intensity
    FCB $FC,$00,0,0        ; path68: header (y=-4, x=0, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH69:    ; Path 69
    FCB 127              ; path69: intensity
    FCB $D0,$0E,0,0        ; path69: header (y=-48, x=14, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH70:    ; Path 70
    FCB 127              ; path70: intensity
    FCB $C1,$0F,0,0        ; path70: header (y=-63, x=15, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH71:    ; Path 71
    FCB 127              ; path71: intensity
    FCB $01,$F5,0,0        ; path71: header (y=1, x=-11, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH72:    ; Path 72
    FCB 127              ; path72: intensity
    FCB $06,$F0,0,0        ; path72: header (y=6, x=-16, relative to center)
    FCB $FF,$0A,$00          ; line 0: flag=-1, dy=10, dx=0
    FCB $FF,$00,$0A          ; line 1: flag=-1, dy=0, dx=10
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH73:    ; Path 73
    FCB 127              ; path73: intensity
    FCB $0C,$FA,0,0        ; path73: header (y=12, x=-6, relative to center)
    FCB $FF,$00,$06          ; line 0: flag=-1, dy=0, dx=6
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH74:    ; Path 74
    FCB 127              ; path74: intensity
    FCB $12,$FA,0,0        ; path74: header (y=18, x=-6, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH75:    ; Path 75
    FCB 127              ; path75: intensity
    FCB $0C,$FA,0,0        ; path75: header (y=12, x=-6, relative to center)
    FCB $FF,$05,$00          ; line 0: flag=-1, dy=5, dx=0
    FCB $FF,$00,$02          ; line 1: flag=-1, dy=0, dx=2
    FCB $FF,$FF,$01          ; line 2: flag=-1, dy=-1, dx=1
    FCB $FF,$00,$03          ; line 3: flag=-1, dy=0, dx=3
    FCB $FF,$00,$00          ; line 4: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH76:    ; Path 76
    FCB 127              ; path76: intensity
    FCB $10,$F5,0,0        ; path76: header (y=16, x=-11, relative to center)
    FCB $FF,$05,$00          ; line 0: flag=-1, dy=5, dx=0
    FCB $FF,$03,$FD          ; line 1: flag=-1, dy=3, dx=-3
    FCB $FF,$06,$00          ; line 2: flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH77:    ; Path 77
    FCB 127              ; path77: intensity
    FCB $10,$F8,0,0        ; path77: header (y=16, x=-8, relative to center)
    FCB $FF,$0A,$00          ; line 0: flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH78:    ; Path 78
    FCB 127              ; path78: intensity
    FCB $18,$F2,0,0        ; path78: header (y=24, x=-14, relative to center)
    FCB $FF,$02,$05          ; line 0: flag=-1, dy=2, dx=5
    FCB $FF,$00,$09          ; line 1: flag=-1, dy=0, dx=9
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH79:    ; Path 79
    FCB 127              ; path79: intensity
    FCB $1A,$F9,0,0        ; path79: header (y=26, x=-7, relative to center)
    FCB $FF,$08,$00          ; line 0: flag=-1, dy=8, dx=0
    FCB $FF,$FF,$FA          ; line 1: flag=-1, dy=-1, dx=-6
    FCB $FF,$04,$00          ; line 2: flag=-1, dy=4, dx=0
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH80:    ; Path 80
    FCB 127              ; path80: intensity
    FCB $21,$F3,0,0        ; path80: header (y=33, x=-13, relative to center)
    FCB $FF,$FC,$03          ; line 0: flag=-1, dy=-4, dx=3
    FCB $FF,$FE,$00          ; line 1: flag=-1, dy=-2, dx=0
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH81:    ; Path 81
    FCB 127              ; path81: intensity
    FCB $22,$F9,0,0        ; path81: header (y=34, x=-7, relative to center)
    FCB $FF,$00,$07          ; line 0: flag=-1, dy=0, dx=7
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH82:    ; Path 82
    FCB 127              ; path82: intensity
    FCB $22,$FB,0,0        ; path82: header (y=34, x=-5, relative to center)
    FCB $FF,$08,$00          ; line 0: flag=-1, dy=8, dx=0
    FCB $FF,$00,$05          ; line 1: flag=-1, dy=0, dx=5
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH83:    ; Path 83
    FCB 127              ; path83: intensity
    FCB $2A,$FC,0,0        ; path83: header (y=42, x=-4, relative to center)
    FCB $FF,$07,$00          ; line 0: flag=-1, dy=7, dx=0
    FCB $FF,$00,$04          ; line 1: flag=-1, dy=0, dx=4
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH84:    ; Path 84
    FCB 127              ; path84: intensity
    FCB $31,$FC,0,0        ; path84: header (y=49, x=-4, relative to center)
    FCB $FF,$FF,$FC          ; line 0: flag=-1, dy=-1, dx=-4
    FCB $FF,$03,$00          ; line 1: flag=-1, dy=3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH85:    ; Path 85
    FCB 127              ; path85: intensity
    FCB $30,$F8,0,0        ; path85: header (y=48, x=-8, relative to center)
    FCB $FF,$FD,$02          ; line 0: flag=-1, dy=-3, dx=2
    FCB $FF,$FE,$00          ; line 1: flag=-1, dy=-2, dx=0
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH86:    ; Path 86
    FCB 127              ; path86: intensity
    FCB $2A,$FB,0,0        ; path86: header (y=42, x=-5, relative to center)
    FCB $FF,$00,$FE          ; line 0: flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$FC          ; line 1: flag=-1, dy=-2, dx=-4
    FCB $FF,$05,$00          ; line 2: flag=-1, dy=5, dx=0
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH87:    ; Path 87
    FCB 127              ; path87: intensity
    FCB $28,$F5,0,0        ; path87: header (y=40, x=-11, relative to center)
    FCB $FF,$FE,$02          ; line 0: flag=-1, dy=-2, dx=2
    FCB $FF,$FE,$00          ; line 1: flag=-1, dy=-2, dx=0
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH88:    ; Path 88
    FCB 127              ; path88: intensity
    FCB $31,$FA,0,0        ; path88: header (y=49, x=-6, relative to center)
    FCB $FF,$05,$00          ; line 0: flag=-1, dy=5, dx=0
    FCB $FF,$00,$06          ; line 1: flag=-1, dy=0, dx=6
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH89:    ; Path 89
    FCB 127              ; path89: intensity
    FCB $36,$FB,0,0        ; path89: header (y=54, x=-5, relative to center)
    FCB $FF,$04,$00          ; line 0: flag=-1, dy=4, dx=0
    FCB $FF,$00,$05          ; line 1: flag=-1, dy=0, dx=5
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH90:    ; Path 90
    FCB 127              ; path90: intensity
    FCB $3A,$FD,0,0        ; path90: header (y=58, x=-3, relative to center)
    FCB $FF,$03,$00          ; line 0: flag=-1, dy=3, dx=0
    FCB $FF,$00,$03          ; line 1: flag=-1, dy=0, dx=3
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH91:    ; Path 91
    FCB 127              ; path91: intensity
    FCB $3D,$FE,0,0        ; path91: header (y=61, x=-2, relative to center)
    FCB $FF,$04,$00          ; line 0: flag=-1, dy=4, dx=0
    FCB $FF,$00,$02          ; line 1: flag=-1, dy=0, dx=2
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH92:    ; Path 92
    FCB 127              ; path92: intensity
    FCB $11,$FD,0,0        ; path92: header (y=17, x=-3, relative to center)
    FCB $FF,$04,$00          ; line 0: flag=-1, dy=4, dx=0
    FCB $FF,$00,$03          ; line 1: flag=-1, dy=0, dx=3
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH93:    ; Path 93
    FCB 127              ; path93: intensity
    FCB $06,$F5,0,0        ; path93: header (y=6, x=-11, relative to center)
    FCB $FF,$01,$01          ; line 0: flag=-1, dy=1, dx=1
    FCB $FF,$00,$03          ; line 1: flag=-1, dy=0, dx=3
    FCB $FF,$02,$02          ; line 2: flag=-1, dy=2, dx=2
    FCB $FF,$03,$01          ; line 3: flag=-1, dy=3, dx=1
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH94:    ; Path 94
    FCB 127              ; path94: intensity
    FCB $01,$F5,0,0        ; path94: header (y=1, x=-11, relative to center)
    FCB $FF,$00,$0B          ; line 0: flag=-1, dy=0, dx=11
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH95:    ; Path 95
    FCB 127              ; path95: intensity
    FCB $F2,$F6,0,0        ; path95: header (y=-14, x=-10, relative to center)
    FCB $FF,$02,$FD          ; line 0: flag=-1, dy=2, dx=-3
    FCB $FF,$05,$00          ; line 1: flag=-1, dy=5, dx=0
    FCB $FF,$02,$02          ; line 2: flag=-1, dy=2, dx=2
    FCB $FF,$00,$02          ; line 3: flag=-1, dy=0, dx=2
    FCB $FF,$03,$01          ; line 4: flag=-1, dy=3, dx=1
    FCB $FF,$00,$04          ; line 5: flag=-1, dy=0, dx=4
    FCB $FF,$03,$04          ; line 6: flag=-1, dy=3, dx=4
    FCB $FF,$00,$00          ; line 7: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH96:    ; Path 96
    FCB 127              ; path96: intensity
    FCB $CA,$60,0,0        ; path96: header (y=-54, x=96, relative to center)
    FCB $FF,$0D,$00          ; line 0: flag=-1, dy=13, dx=0
    FCB $FF,$00,$B4          ; line 1: flag=-1, dy=0, dx=-76
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH97:    ; Path 97
    FCB 127              ; path97: intensity
    FCB $D2,$60,0,0        ; path97: header (y=-46, x=96, relative to center)
    FCB $FF,$00,$B4          ; line 0: flag=-1, dy=0, dx=-76
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH98:    ; Path 98
    FCB 127              ; path98: intensity
    FCB $D8,$14,0,0        ; path98: header (y=-40, x=20, relative to center)
    FCB $FF,$F8,$00          ; line 0: flag=-1, dy=-8, dx=0
    FCB $FF,$00,$F9          ; line 1: flag=-1, dy=0, dx=-7
    FCB $FF,$FF,$FE          ; line 2: flag=-1, dy=-1, dx=-2
    FCB $FF,$09,$00          ; line 3: flag=-1, dy=9, dx=0
    FCB $FF,$00,$09          ; line 4: flag=-1, dy=0, dx=9
    FCB $FF,$00,$00          ; line 5: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH99:    ; Path 99
    FCB 127              ; path99: intensity
    FCB $D8,$12,0,0        ; path99: header (y=-40, x=18, relative to center)
    FCB $FF,$0F,$00          ; line 0: flag=-1, dy=15, dx=0
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH100:    ; Path 100
    FCB 127              ; path100: intensity
    FCB $E3,$12,0,0        ; path100: header (y=-29, x=18, relative to center)
    FCB $FF,$00,$4A          ; line 0: flag=-1, dy=0, dx=74
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH101:    ; Path 101
    FCB 127              ; path101: intensity
    FCB $E3,$5C,0,0        ; path101: header (y=-29, x=92, relative to center)
    FCB $FF,$06,$00          ; line 0: flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH102:    ; Path 102
    FCB 127              ; path102: intensity
    FCB $E9,$5C,0,0        ; path102: header (y=-23, x=92, relative to center)
    FCB $FF,$00,$B7          ; line 0: flag=-1, dy=0, dx=-73
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH103:    ; Path 103
    FCB 127              ; path103: intensity
    FCB $E7,$0B,0,0        ; path103: header (y=-25, x=11, relative to center)
    FCB $FF,$00,$08          ; line 0: flag=-1, dy=0, dx=8
    FCB $FF,$04,$00          ; line 1: flag=-1, dy=4, dx=0
    FCB $FF,$01,$FE          ; line 2: flag=-1, dy=1, dx=-2
    FCB $FF,$01,$FD          ; line 3: flag=-1, dy=1, dx=-3
    FCB $FF,$02,$01          ; line 4: flag=-1, dy=2, dx=1
    FCB $FF,$02,$FF          ; line 5: flag=-1, dy=2, dx=-1
    FCB $FF,$00,$FD          ; line 6: flag=-1, dy=0, dx=-3
    FCB $FF,$00,$00          ; line 7: flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; line 8: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH104:    ; Path 104
    FCB 127              ; path104: intensity
    FCB $FC,$00,0,0        ; path104: header (y=-4, x=0, relative to center)
    FCB $FF,$F5,$0B          ; line 0: flag=-1, dy=-11, dx=11
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH105:    ; Path 105
    FCB 127              ; path105: intensity
    FCB $E3,$5B,0,0        ; path105: header (y=-29, x=91, relative to center)
    FCB $FF,$F4,$00          ; line 0: flag=-1, dy=-12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH106:    ; Path 106
    FCB 127              ; path106: intensity
    FCB $E3,$4F,0,0        ; path106: header (y=-29, x=79, relative to center)
    FCB $FF,$F4,$00          ; line 0: flag=-1, dy=-12, dx=0
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH107:    ; Path 107
    FCB 127              ; path107: intensity
    FCB $E3,$42,0,0        ; path107: header (y=-29, x=66, relative to center)
    FCB $FF,$F4,$00          ; line 0: flag=-1, dy=-12, dx=0
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH108:    ; Path 108
    FCB 127              ; path108: intensity
    FCB $E3,$36,0,0        ; path108: header (y=-29, x=54, relative to center)
    FCB $FF,$F4,$00          ; line 0: flag=-1, dy=-12, dx=0
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH109:    ; Path 109
    FCB 127              ; path109: intensity
    FCB $E3,$28,0,0        ; path109: header (y=-29, x=40, relative to center)
    FCB $FF,$F4,$00          ; line 0: flag=-1, dy=-12, dx=0
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH110:    ; Path 110
    FCB 127              ; path110: intensity
    FCB $E9,$57,0,0        ; path110: header (y=-23, x=87, relative to center)
    FCB $FF,$0E,$00          ; line 0: flag=-1, dy=14, dx=0
    FCB $FF,$00,$CF          ; line 1: flag=-1, dy=0, dx=-49
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH111:    ; Path 111
    FCB 127              ; path111: intensity
    FCB $F7,$45,0,0        ; path111: header (y=-9, x=69, relative to center)
    FCB $FF,$F2,$00          ; line 0: flag=-1, dy=-14, dx=0
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH112:    ; Path 112
    FCB 127              ; path112: intensity
    FCB $EC,$57,0,0        ; path112: header (y=-20, x=87, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH113:    ; Path 113
    FCB 127              ; path113: intensity
    FCB $F0,$26,0,0        ; path113: header (y=-16, x=38, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH114:    ; Path 114
    FCB 127              ; path114: intensity
    FCB $FD,$26,0,0        ; path114: header (y=-3, x=38, relative to center)
    FCB $FF,$EC,$00          ; line 0: flag=-1, dy=-20, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH115:    ; Path 115
    FCB 127              ; path115: intensity
    FCB $F7,$4D,0,0        ; path115: header (y=-9, x=77, relative to center)
    FCB $FF,$10,$00          ; line 0: flag=-1, dy=16, dx=0
    FCB $FF,$00,$E5          ; line 1: flag=-1, dy=0, dx=-27
    FCB $FF,$F0,$00          ; line 2: flag=-1, dy=-16, dx=0
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH116:    ; Path 116
    FCB 127              ; path116: intensity
    FCB $07,$4C,0,0        ; path116: header (y=7, x=76, relative to center)
    FCB $FF,$03,$00          ; line 0: flag=-1, dy=3, dx=0
    FCB $FF,$02,$03          ; line 1: flag=-1, dy=2, dx=3
    FCB $FF,$06,$00          ; line 2: flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH117:    ; Path 117
    FCB 127              ; path117: intensity
    FCB $07,$48,0,0        ; path117: header (y=7, x=72, relative to center)
    FCB $FF,$07,$00          ; line 0: flag=-1, dy=7, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH118:    ; Path 118
    FCB 127              ; path118: intensity
    FCB $07,$39,0,0        ; path118: header (y=7, x=57, relative to center)
    FCB $FF,$07,$00          ; line 0: flag=-1, dy=7, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH119:    ; Path 119
    FCB 127              ; path119: intensity
    FCB $07,$35,0,0        ; path119: header (y=7, x=53, relative to center)
    FCB $FF,$03,$00          ; line 0: flag=-1, dy=3, dx=0
    FCB $FF,$02,$FD          ; line 1: flag=-1, dy=2, dx=-3
    FCB $FF,$06,$00          ; line 2: flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH120:    ; Path 120
    FCB 127              ; path120: intensity
    FCB $0C,$4F,0,0        ; path120: header (y=12, x=79, relative to center)
    FCB $FF,$02,$FB          ; line 0: flag=-1, dy=2, dx=-5
    FCB $FF,$00,$F0          ; line 1: flag=-1, dy=0, dx=-16
    FCB $FF,$00,$FD          ; line 2: flag=-1, dy=0, dx=-3
    FCB $FF,$FE,$FB          ; line 3: flag=-1, dy=-2, dx=-5
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH121:    ; Path 121
    FCB 127              ; path121: intensity
    FCB $0E,$47,0,0        ; path121: header (y=14, x=71, relative to center)
    FCB $FF,$08,$00          ; line 0: flag=-1, dy=8, dx=0
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB $FF,$00,$F2          ; line 2: flag=-1, dy=0, dx=-14
    FCB $FF,$FE,$FB          ; line 3: flag=-1, dy=-2, dx=-5
    FCB $FF,$05,$00          ; line 4: flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH122:    ; Path 122
    FCB 127              ; path122: intensity
    FCB $16,$3A,0,0        ; path122: header (y=22, x=58, relative to center)
    FCB $FF,$F8,$00          ; line 0: flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH123:    ; Path 123
    FCB 127              ; path123: intensity
    FCB $16,$47,0,0        ; path123: header (y=22, x=71, relative to center)
    FCB $FF,$00,$01          ; line 0: flag=-1, dy=0, dx=1
    FCB $FF,$FE,$05          ; line 1: flag=-1, dy=-2, dx=5
    FCB $FF,$05,$00          ; line 2: flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH124:    ; Path 124
    FCB 127              ; path124: intensity
    FCB $14,$34,0,0        ; path124: header (y=20, x=52, relative to center)
    FCB $FF,$FE,$02          ; line 0: flag=-1, dy=-2, dx=2
    FCB $FF,$FD,$00          ; line 1: flag=-1, dy=-3, dx=0
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH125:    ; Path 125
    FCB 127              ; path125: intensity
    FCB $14,$4D,0,0        ; path125: header (y=20, x=77, relative to center)
    FCB $FF,$FE,$FE          ; line 0: flag=-1, dy=-2, dx=-2
    FCB $FF,$FD,$00          ; line 1: flag=-1, dy=-3, dx=0
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH126:    ; Path 126
    FCB 127              ; path126: intensity
    FCB $16,$46,0,0        ; path126: header (y=22, x=70, relative to center)
    FCB $FF,$08,$00          ; line 0: flag=-1, dy=8, dx=0
    FCB $FF,$00,$F5          ; line 1: flag=-1, dy=0, dx=-11
    FCB $FF,$F8,$00          ; line 2: flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH127:    ; Path 127
    FCB 127              ; path127: intensity
    FCB $1E,$46,0,0        ; path127: header (y=30, x=70, relative to center)
    FCB $FF,$FE,$06          ; line 0: flag=-1, dy=-2, dx=6
    FCB $FF,$05,$00          ; line 1: flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH128:    ; Path 128
    FCB 127              ; path128: intensity
    FCB $1C,$4C,0,0        ; path128: header (y=28, x=76, relative to center)
    FCB $FF,$FE,$FE          ; line 0: flag=-1, dy=-2, dx=-2
    FCB $FF,$FD,$00          ; line 1: flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH129:    ; Path 129
    FCB 127              ; path129: intensity
    FCB $1E,$3B,0,0        ; path129: header (y=30, x=59, relative to center)
    FCB $FF,$FE,$FA          ; line 0: flag=-1, dy=-2, dx=-6
    FCB $FF,$04,$00          ; line 1: flag=-1, dy=4, dx=0
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH130:    ; Path 130
    FCB 127              ; path130: intensity
    FCB $1C,$35,0,0        ; path130: header (y=28, x=53, relative to center)
    FCB $FF,$FE,$02          ; line 0: flag=-1, dy=-2, dx=2
    FCB $FF,$FD,$00          ; line 1: flag=-1, dy=-3, dx=0
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH131:    ; Path 131
    FCB 127              ; path131: intensity
    FCB $1E,$47,0,0        ; path131: header (y=30, x=71, relative to center)
    FCB $FF,$03,$00          ; line 0: flag=-1, dy=3, dx=0
    FCB $FF,$01,$02          ; line 1: flag=-1, dy=1, dx=2
    FCB $FF,$05,$00          ; line 2: flag=-1, dy=5, dx=0
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH132:    ; Path 132
    FCB 127              ; path132: intensity
    FCB $23,$49,0,0        ; path132: header (y=35, x=73, relative to center)
    FCB $FF,$01,$FC          ; line 0: flag=-1, dy=1, dx=-4
    FCB $FF,$00,$F7          ; line 1: flag=-1, dy=0, dx=-9
    FCB $FF,$FF,$FC          ; line 2: flag=-1, dy=-1, dx=-4
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH133:    ; Path 133
    FCB 127              ; path133: intensity
    FCB $1E,$3A,0,0        ; path133: header (y=30, x=58, relative to center)
    FCB $FF,$02,$00          ; line 0: flag=-1, dy=2, dx=0
    FCB $FF,$03,$FE          ; line 1: flag=-1, dy=3, dx=-2
    FCB $FF,$04,$00          ; line 2: flag=-1, dy=4, dx=0
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH134:    ; Path 134
    FCB 127              ; path134: intensity
    FCB $24,$44,0,0        ; path134: header (y=36, x=68, relative to center)
    FCB $FF,$FA,$00          ; line 0: flag=-1, dy=-6, dx=0
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH135:    ; Path 135
    FCB 127              ; path135: intensity
    FCB $1E,$3D,0,0        ; path135: header (y=30, x=61, relative to center)
    FCB $FF,$06,$00          ; line 0: flag=-1, dy=6, dx=0
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH136:    ; Path 136
    FCB 127              ; path136: intensity
    FCB $24,$47,0,0        ; path136: header (y=36, x=71, relative to center)
    FCB $FF,$05,$00          ; line 0: flag=-1, dy=5, dx=0
    FCB $FF,$00,$F3          ; line 1: flag=-1, dy=0, dx=-13
    FCB $FF,$FB,$00          ; line 2: flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH137:    ; Path 137
    FCB 127              ; path137: intensity
    FCB $29,$46,0,0        ; path137: header (y=41, x=70, relative to center)
    FCB $FF,$04,$00          ; line 0: flag=-1, dy=4, dx=0
    FCB $FF,$00,$F5          ; line 1: flag=-1, dy=0, dx=-11
    FCB $FF,$FC,$00          ; line 2: flag=-1, dy=-4, dx=0
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH138:    ; Path 138
    FCB 127              ; path138: intensity
    FCB $2D,$44,0,0        ; path138: header (y=45, x=68, relative to center)
    FCB $FF,$03,$00          ; line 0: flag=-1, dy=3, dx=0
    FCB $FF,$00,$F9          ; line 1: flag=-1, dy=0, dx=-7
    FCB $FF,$FD,$00          ; line 2: flag=-1, dy=-3, dx=0
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH139:    ; Path 139
    FCB 127              ; path139: intensity
    FCB $30,$43,0,0        ; path139: header (y=48, x=67, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH140:    ; Path 140
    FCB 127              ; path140: intensity
    FCB $30,$3E,0,0        ; path140: header (y=48, x=62, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH141:    ; Path 141
    FCB 127              ; path141: intensity
    FCB $33,$49,0,0        ; path141: header (y=51, x=73, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH142:    ; Path 142
    FCB 127              ; path142: intensity
    FCB $33,$3E,0,0        ; path142: header (y=51, x=62, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH143:    ; Path 143
    FCB 127              ; path143: intensity
    FCB $30,$43,0,0        ; path143: header (y=48, x=67, relative to center)
    FCB $FF,$03,$00          ; line 0: flag=-1, dy=3, dx=0
    FCB $FF,$00,$FB          ; line 1: flag=-1, dy=0, dx=-5
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH144:    ; Path 144
    FCB 127              ; path144: intensity
    FCB $30,$3E,0,0        ; path144: header (y=48, x=62, relative to center)
    FCB $FF,$03,$00          ; line 0: flag=-1, dy=3, dx=0
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH145:    ; Path 145
    FCB 127              ; path145: intensity
    FCB $07,$47,0,0        ; path145: header (y=7, x=71, relative to center)
    FCB $FF,$F0,$00          ; line 0: flag=-1, dy=-16, dx=0
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH146:    ; Path 146
    FCB 127              ; path146: intensity
    FCB $F7,$3A,0,0        ; path146: header (y=-9, x=58, relative to center)
    FCB $FF,$10,$00          ; line 0: flag=-1, dy=16, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH147:    ; Path 147
    FCB 127              ; path147: intensity
    FCB $04,$44,0,0        ; path147: header (y=4, x=68, relative to center)
    FCB $FF,$00,$F9          ; line 0: flag=-1, dy=0, dx=-7
    FCB $FF,$F7,$00          ; line 1: flag=-1, dy=-9, dx=0
    FCB $FF,$00,$07          ; line 2: flag=-1, dy=0, dx=7
    FCB $FF,$09,$00          ; line 3: flag=-1, dy=9, dx=0
    FCB $FF,$00,$00          ; line 4: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH148:    ; Path 148
    FCB 127              ; path148: intensity
    FCB $07,$44,0,0        ; path148: header (y=7, x=68, relative to center)
    FCB $FF,$04,$00          ; line 0: flag=-1, dy=4, dx=0
    FCB $FF,$02,$FD          ; line 1: flag=-1, dy=2, dx=-3
    FCB $FF,$FE,$FD          ; line 2: flag=-1, dy=-2, dx=-3
    FCB $FF,$FC,$00          ; line 3: flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH149:    ; Path 149
    FCB 127              ; path149: intensity
    FCB $E3,$1B,0,0        ; path149: header (y=-29, x=27, relative to center)
    FCB $FF,$F4,$00          ; line 0: flag=-1, dy=-12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH150:    ; Path 150
    FCB 127              ; path150: intensity
    FCB $EC,$0B,0,0        ; path150: header (y=-20, x=11, relative to center)
    FCB $FF,$EE,$00          ; line 0: flag=-1, dy=-18, dx=0
    FCB $FF,$00,$05          ; line 1: flag=-1, dy=0, dx=5
    FCB $FF,$09,$00          ; line 2: flag=-1, dy=9, dx=0
    FCB $FF,$00,$FB          ; line 3: flag=-1, dy=0, dx=-5
    FCB $FF,$00,$00          ; line 4: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH151:    ; Path 151
    FCB 127              ; path151: intensity
    FCB $F3,$04,0,0        ; path151: header (y=-13, x=4, relative to center)
    FCB $FF,$FC,$03          ; line 0: flag=-1, dy=-4, dx=3
    FCB $FF,$E9,$00          ; line 1: flag=-1, dy=-23, dx=0
    FCB $FF,$00,$F9          ; line 2: flag=-1, dy=0, dx=-7
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH152:    ; Path 152
    FCB 127              ; path152: intensity
    FCB $F3,$04,0,0        ; path152: header (y=-13, x=4, relative to center)
    FCB $FF,$01,$FC          ; line 0: flag=-1, dy=1, dx=-4
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH153:    ; Path 153
    FCB 127              ; path153: intensity
    FCB $F2,$57,0,0        ; path153: header (y=-14, x=87, relative to center)
    FCB $FF,$00,$B6          ; line 0: flag=-1, dy=0, dx=-74
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH154:    ; Path 154
    FCB 127              ; path154: intensity
    FCB $D0,$14,0,0        ; path154: header (y=-48, x=20, relative to center)
    FCB $FF,$00,$06          ; line 0: flag=-1, dy=0, dx=6
    FCB $FF,$F2,$00          ; line 1: flag=-1, dy=-14, dx=0
    FCB $FF,$00,$F5          ; line 2: flag=-1, dy=0, dx=-11
    FCB $FF,$0E,$00          ; line 3: flag=-1, dy=14, dx=0
    FCB $FF,$00,$00          ; line 4: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH155:    ; Path 155
    FCB 127              ; path155: intensity
    FCB $D4,$09,0,0        ; path155: header (y=-44, x=9, relative to center)
    FCB $FF,$00,$F7          ; line 0: flag=-1, dy=0, dx=-9
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH156:    ; Path 156
    FCB 127              ; path156: intensity
    FCB $D1,$00,0,0        ; path156: header (y=-47, x=0, relative to center)
    FCB $FF,$00,$0A          ; line 0: flag=-1, dy=0, dx=10
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH157:    ; Path 157
    FCB 127              ; path157: intensity
    FCB $CC,$0C,0,0        ; path157: header (y=-52, x=12, relative to center)
    FCB $FF,$00,$F4          ; line 0: flag=-1, dy=0, dx=-12
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH158:    ; Path 158
    FCB 127              ; path158: intensity
    FCB $C7,$00,0,0        ; path158: header (y=-57, x=0, relative to center)
    FCB $FF,$00,$0D          ; line 0: flag=-1, dy=0, dx=13
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH159:    ; Path 159
    FCB 127              ; path159: intensity
    FCB $C0,$0E,0,0        ; path159: header (y=-64, x=14, relative to center)
    FCB $FF,$00,$F2          ; line 0: flag=-1, dy=0, dx=-14
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH160:    ; Path 160
    FCB 127              ; path160: intensity
    FCB $FD,$0B,0,0        ; path160: header (y=-3, x=11, relative to center)
    FCB $FF,$00,$1D          ; line 0: flag=-1, dy=0, dx=29
    FCB $FF,$09,$00          ; line 1: flag=-1, dy=9, dx=0
    FCB $FF,$00,$E3          ; line 2: flag=-1, dy=0, dx=-29
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH161:    ; Path 161
    FCB 127              ; path161: intensity
    FCB $FD,$0B,0,0        ; path161: header (y=-3, x=11, relative to center)
    FCB $FF,$09,$00          ; line 0: flag=-1, dy=9, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH162:    ; Path 162
    FCB 127              ; path162: intensity
    FCB $07,$32,0,0        ; path162: header (y=7, x=50, relative to center)
    FCB $FF,$04,$00          ; line 0: flag=-1, dy=4, dx=0
    FCB $FF,$00,$D3          ; line 1: flag=-1, dy=0, dx=-45
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH163:    ; Path 163
    FCB 127              ; path163: intensity
    FCB $F4,$00,0,0        ; path163: header (y=-12, x=0, relative to center)
    FCB $FF,$00,$00          ; line 0: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH164:    ; Path 164
    FCB 127              ; path164: intensity
    FCB $FC,$00,0,0        ; path164: header (y=-4, x=0, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH165:    ; Path 165
    FCB 127              ; path165: intensity
    FCB $D0,$F2,0,0        ; path165: header (y=-48, x=-14, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH166:    ; Path 166
    FCB 127              ; path166: intensity
    FCB $C1,$F1,0,0        ; path166: header (y=-63, x=-15, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH167:    ; Path 167
    FCB 127              ; path167: intensity
    FCB $01,$0B,0,0        ; path167: header (y=1, x=11, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH168:    ; Path 168
    FCB 127              ; path168: intensity
    FCB $06,$10,0,0        ; path168: header (y=6, x=16, relative to center)
    FCB $FF,$0A,$00          ; line 0: flag=-1, dy=10, dx=0
    FCB $FF,$00,$F6          ; line 1: flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH169:    ; Path 169
    FCB 127              ; path169: intensity
    FCB $0C,$06,0,0        ; path169: header (y=12, x=6, relative to center)
    FCB $FF,$00,$FA          ; line 0: flag=-1, dy=0, dx=-6
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH170:    ; Path 170
    FCB 127              ; path170: intensity
    FCB $12,$06,0,0        ; path170: header (y=18, x=6, relative to center)
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH171:    ; Path 171
    FCB 127              ; path171: intensity
    FCB $0C,$06,0,0        ; path171: header (y=12, x=6, relative to center)
    FCB $FF,$05,$00          ; line 0: flag=-1, dy=5, dx=0
    FCB $FF,$00,$FE          ; line 1: flag=-1, dy=0, dx=-2
    FCB $FF,$FF,$FF          ; line 2: flag=-1, dy=-1, dx=-1
    FCB $FF,$00,$FD          ; line 3: flag=-1, dy=0, dx=-3
    FCB $FF,$00,$00          ; line 4: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH172:    ; Path 172
    FCB 127              ; path172: intensity
    FCB $10,$0B,0,0        ; path172: header (y=16, x=11, relative to center)
    FCB $FF,$05,$00          ; line 0: flag=-1, dy=5, dx=0
    FCB $FF,$03,$03          ; line 1: flag=-1, dy=3, dx=3
    FCB $FF,$06,$00          ; line 2: flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH173:    ; Path 173
    FCB 127              ; path173: intensity
    FCB $10,$08,0,0        ; path173: header (y=16, x=8, relative to center)
    FCB $FF,$0A,$00          ; line 0: flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH174:    ; Path 174
    FCB 127              ; path174: intensity
    FCB $18,$0E,0,0        ; path174: header (y=24, x=14, relative to center)
    FCB $FF,$02,$FB          ; line 0: flag=-1, dy=2, dx=-5
    FCB $FF,$00,$F7          ; line 1: flag=-1, dy=0, dx=-9
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH175:    ; Path 175
    FCB 127              ; path175: intensity
    FCB $1A,$07,0,0        ; path175: header (y=26, x=7, relative to center)
    FCB $FF,$08,$00          ; line 0: flag=-1, dy=8, dx=0
    FCB $FF,$FF,$06          ; line 1: flag=-1, dy=-1, dx=6
    FCB $FF,$04,$00          ; line 2: flag=-1, dy=4, dx=0
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH176:    ; Path 176
    FCB 127              ; path176: intensity
    FCB $21,$0D,0,0        ; path176: header (y=33, x=13, relative to center)
    FCB $FF,$FC,$FD          ; line 0: flag=-1, dy=-4, dx=-3
    FCB $FF,$FE,$00          ; line 1: flag=-1, dy=-2, dx=0
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH177:    ; Path 177
    FCB 127              ; path177: intensity
    FCB $22,$07,0,0        ; path177: header (y=34, x=7, relative to center)
    FCB $FF,$00,$F9          ; line 0: flag=-1, dy=0, dx=-7
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH178:    ; Path 178
    FCB 127              ; path178: intensity
    FCB $22,$05,0,0        ; path178: header (y=34, x=5, relative to center)
    FCB $FF,$08,$00          ; line 0: flag=-1, dy=8, dx=0
    FCB $FF,$00,$FB          ; line 1: flag=-1, dy=0, dx=-5
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH179:    ; Path 179
    FCB 127              ; path179: intensity
    FCB $2A,$04,0,0        ; path179: header (y=42, x=4, relative to center)
    FCB $FF,$07,$00          ; line 0: flag=-1, dy=7, dx=0
    FCB $FF,$00,$FC          ; line 1: flag=-1, dy=0, dx=-4
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH180:    ; Path 180
    FCB 127              ; path180: intensity
    FCB $31,$04,0,0        ; path180: header (y=49, x=4, relative to center)
    FCB $FF,$FF,$04          ; line 0: flag=-1, dy=-1, dx=4
    FCB $FF,$03,$00          ; line 1: flag=-1, dy=3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH181:    ; Path 181
    FCB 127              ; path181: intensity
    FCB $30,$08,0,0        ; path181: header (y=48, x=8, relative to center)
    FCB $FF,$FD,$FE          ; line 0: flag=-1, dy=-3, dx=-2
    FCB $FF,$FE,$00          ; line 1: flag=-1, dy=-2, dx=0
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH182:    ; Path 182
    FCB 127              ; path182: intensity
    FCB $2A,$05,0,0        ; path182: header (y=42, x=5, relative to center)
    FCB $FF,$00,$02          ; line 0: flag=-1, dy=0, dx=2
    FCB $FF,$FE,$04          ; line 1: flag=-1, dy=-2, dx=4
    FCB $FF,$05,$00          ; line 2: flag=-1, dy=5, dx=0
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH183:    ; Path 183
    FCB 127              ; path183: intensity
    FCB $28,$0B,0,0        ; path183: header (y=40, x=11, relative to center)
    FCB $FF,$FE,$FE          ; line 0: flag=-1, dy=-2, dx=-2
    FCB $FF,$FE,$00          ; line 1: flag=-1, dy=-2, dx=0
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH184:    ; Path 184
    FCB 127              ; path184: intensity
    FCB $31,$06,0,0        ; path184: header (y=49, x=6, relative to center)
    FCB $FF,$05,$00          ; line 0: flag=-1, dy=5, dx=0
    FCB $FF,$00,$FA          ; line 1: flag=-1, dy=0, dx=-6
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH185:    ; Path 185
    FCB 127              ; path185: intensity
    FCB $36,$05,0,0        ; path185: header (y=54, x=5, relative to center)
    FCB $FF,$04,$00          ; line 0: flag=-1, dy=4, dx=0
    FCB $FF,$00,$FB          ; line 1: flag=-1, dy=0, dx=-5
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH186:    ; Path 186
    FCB 127              ; path186: intensity
    FCB $3A,$03,0,0        ; path186: header (y=58, x=3, relative to center)
    FCB $FF,$03,$00          ; line 0: flag=-1, dy=3, dx=0
    FCB $FF,$00,$FD          ; line 1: flag=-1, dy=0, dx=-3
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH187:    ; Path 187
    FCB 127              ; path187: intensity
    FCB $3D,$02,0,0        ; path187: header (y=61, x=2, relative to center)
    FCB $FF,$04,$00          ; line 0: flag=-1, dy=4, dx=0
    FCB $FF,$00,$FE          ; line 1: flag=-1, dy=0, dx=-2
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH188:    ; Path 188
    FCB 127              ; path188: intensity
    FCB $11,$03,0,0        ; path188: header (y=17, x=3, relative to center)
    FCB $FF,$04,$00          ; line 0: flag=-1, dy=4, dx=0
    FCB $FF,$00,$FD          ; line 1: flag=-1, dy=0, dx=-3
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH189:    ; Path 189
    FCB 127              ; path189: intensity
    FCB $06,$0B,0,0        ; path189: header (y=6, x=11, relative to center)
    FCB $FF,$01,$FF          ; line 0: flag=-1, dy=1, dx=-1
    FCB $FF,$00,$FD          ; line 1: flag=-1, dy=0, dx=-3
    FCB $FF,$02,$FE          ; line 2: flag=-1, dy=2, dx=-2
    FCB $FF,$03,$FF          ; line 3: flag=-1, dy=3, dx=-1
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH190:    ; Path 190
    FCB 127              ; path190: intensity
    FCB $01,$0B,0,0        ; path190: header (y=1, x=11, relative to center)
    FCB $FF,$00,$F5          ; line 0: flag=-1, dy=0, dx=-11
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH191:    ; Path 191
    FCB 127              ; path191: intensity
    FCB $F2,$0A,0,0        ; path191: header (y=-14, x=10, relative to center)
    FCB $FF,$02,$03          ; line 0: flag=-1, dy=2, dx=3
    FCB $FF,$05,$00          ; line 1: flag=-1, dy=5, dx=0
    FCB $FF,$02,$FE          ; line 2: flag=-1, dy=2, dx=-2
    FCB $FF,$00,$FE          ; line 3: flag=-1, dy=0, dx=-2
    FCB $FF,$03,$FF          ; line 4: flag=-1, dy=3, dx=-1
    FCB $FF,$00,$FC          ; line 5: flag=-1, dy=0, dx=-4
    FCB $FF,$03,$FC          ; line 6: flag=-1, dy=3, dx=-4
    FCB $FF,$00,$00          ; line 7: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

; Vector asset: paris_bg
; Generated from paris_bg.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 15
; X bounds: min=-50, max=50, width=100
; Center: (0, 17)

_PARIS_BG_WIDTH EQU 100
_PARIS_BG_CENTER_X EQU 0
_PARIS_BG_CENTER_Y EQU 17

_PARIS_BG_VECTORS:  ; Main entry (header + 5 path(s))
    FCB 5               ; path_count (runtime metadata)
    FDB _PARIS_BG_PATH0        ; pointer to path 0
    FDB _PARIS_BG_PATH1        ; pointer to path 1
    FDB _PARIS_BG_PATH2        ; pointer to path 2
    FDB _PARIS_BG_PATH3        ; pointer to path 3
    FDB _PARIS_BG_PATH4        ; pointer to path 4

_PARIS_BG_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $D1,$CE,0,0        ; path0: header (y=-47, x=-50, relative to center)
    FCB $FF,$1E,$1E          ; line 0: flag=-1, dy=30, dx=30
    FCB $FF,$1E,$0A          ; line 1: flag=-1, dy=30, dx=10
    FCB 2                ; End marker (path complete)

_PARIS_BG_PATH1:    ; Path 1
    FCB 100              ; path1: intensity
    FCB $D1,$32,0,0        ; path1: header (y=-47, x=50, relative to center)
    FCB $FF,$1E,$E2          ; line 0: flag=-1, dy=30, dx=-30
    FCB $FF,$1E,$F6          ; line 1: flag=-1, dy=30, dx=-10
    FCB 2                ; End marker (path complete)

_PARIS_BG_PATH2:    ; Path 2
    FCB 110              ; path2: intensity
    FCB $0D,$F6,0,0        ; path2: header (y=13, x=-10, relative to center)
    FCB $FF,$14,$05          ; line 0: flag=-1, dy=20, dx=5
    FCB $FF,$00,$0A          ; line 1: flag=-1, dy=0, dx=10
    FCB $FF,$EC,$05          ; line 2: flag=-1, dy=-20, dx=5
    FCB 2                ; End marker (path complete)

_PARIS_BG_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $21,$FB,0,0        ; path3: header (y=33, x=-5, relative to center)
    FCB $FF,$0F,$05          ; line 0: flag=-1, dy=15, dx=5
    FCB $FF,$F1,$05          ; line 1: flag=-1, dy=-15, dx=5
    FCB 2                ; End marker (path complete)

_PARIS_BG_PATH4:    ; Path 4
    FCB 90              ; path4: intensity
    FCB $EF,$EC,0,0        ; path4: header (y=-17, x=-20, relative to center)
    FCB $FF,$00,$28          ; line 0: flag=-1, dy=0, dx=40
    FCB 2                ; End marker (path complete)

; Vector asset: buddha_bg
; Generated from buddha_bg.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 10
; X bounds: min=-80, max=80, width=160
; Center: (0, 20)

_BUDDHA_BG_WIDTH EQU 160
_BUDDHA_BG_CENTER_X EQU 0
_BUDDHA_BG_CENTER_Y EQU 20

_BUDDHA_BG_VECTORS:  ; Main entry (header + 4 path(s))
    FCB 4               ; path_count (runtime metadata)
    FDB _BUDDHA_BG_PATH0        ; pointer to path 0
    FDB _BUDDHA_BG_PATH1        ; pointer to path 1
    FDB _BUDDHA_BG_PATH2        ; pointer to path 2
    FDB _BUDDHA_BG_PATH3        ; pointer to path 3

_BUDDHA_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $14,$B0,0,0        ; path0: header (y=20, x=-80, relative to center)
    FCB $FF,$14,$14          ; line 0: flag=-1, dy=20, dx=20
    FCB $FF,$00,$78          ; line 1: flag=-1, dy=0, dx=120
    FCB $FF,$EC,$14          ; line 2: flag=-1, dy=-20, dx=20
    FCB 2                ; End marker (path complete)

_BUDDHA_BG_PATH1:    ; Path 1
    FCB 100              ; path1: intensity
    FCB $14,$CE,0,0        ; path1: header (y=20, x=-50, relative to center)
    FCB $FF,$C4,$00          ; line 0: flag=-1, dy=-60, dx=0
    FCB 2                ; End marker (path complete)

_BUDDHA_BG_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $14,$32,0,0        ; path2: header (y=20, x=50, relative to center)
    FCB $FF,$C4,$00          ; line 0: flag=-1, dy=-60, dx=0
    FCB 2                ; End marker (path complete)

_BUDDHA_BG_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $D8,$BA,0,0        ; path3: header (y=-40, x=-70, relative to center)
    FCB $FF,$00,$7F          ; line 0: flag=-1, dy=0, dx=127
    FCB 2                ; End marker (path complete)

; Vector asset: taj_bg
; Generated from taj_bg.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 13
; X bounds: min=-70, max=70, width=140
; Center: (0, 22)

_TAJ_BG_WIDTH EQU 140
_TAJ_BG_CENTER_X EQU 0
_TAJ_BG_CENTER_Y EQU 22

_TAJ_BG_VECTORS:  ; Main entry (header + 4 path(s))
    FCB 4               ; path_count (runtime metadata)
    FDB _TAJ_BG_PATH0        ; pointer to path 0
    FDB _TAJ_BG_PATH1        ; pointer to path 1
    FDB _TAJ_BG_PATH2        ; pointer to path 2
    FDB _TAJ_BG_PATH3        ; pointer to path 3

_TAJ_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $12,$E2,0,0        ; path0: header (y=18, x=-30, relative to center)
    FCB $FF,$14,$0A          ; line 0: flag=-1, dy=20, dx=10
    FCB $FF,$05,$14          ; line 1: flag=-1, dy=5, dx=20
    FCB $FF,$FB,$14          ; line 2: flag=-1, dy=-5, dx=20
    FCB $FF,$EC,$0A          ; line 3: flag=-1, dy=-20, dx=10
    FCB 2                ; End marker (path complete)

_TAJ_BG_PATH1:    ; Path 1
    FCB 110              ; path1: intensity
    FCB $12,$D8,0,0        ; path1: header (y=18, x=-40, relative to center)
    FCB $FF,$CE,$00          ; line 0: flag=-1, dy=-50, dx=0
    FCB $FF,$00,$50          ; line 1: flag=-1, dy=0, dx=80
    FCB $FF,$32,$00          ; line 2: flag=-1, dy=50, dx=0
    FCB 2                ; End marker (path complete)

_TAJ_BG_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $D6,$BA,0,0        ; path2: header (y=-42, x=-70, relative to center)
    FCB $FF,$46,$00          ; line 0: flag=-1, dy=70, dx=0
    FCB 2                ; End marker (path complete)

_TAJ_BG_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $D6,$46,0,0        ; path3: header (y=-42, x=70, relative to center)
    FCB $FF,$46,$00          ; line 0: flag=-1, dy=70, dx=0
    FCB 2                ; End marker (path complete)

; Vector asset: mayan_bg
; Generated from mayan_bg.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 20
; X bounds: min=-80, max=80, width=160
; Center: (0, 10)

_MAYAN_BG_WIDTH EQU 160
_MAYAN_BG_CENTER_X EQU 0
_MAYAN_BG_CENTER_Y EQU 10

_MAYAN_BG_VECTORS:  ; Main entry (header + 5 path(s))
    FCB 5               ; path_count (runtime metadata)
    FDB _MAYAN_BG_PATH0        ; pointer to path 0
    FDB _MAYAN_BG_PATH1        ; pointer to path 1
    FDB _MAYAN_BG_PATH2        ; pointer to path 2
    FDB _MAYAN_BG_PATH3        ; pointer to path 3
    FDB _MAYAN_BG_PATH4        ; pointer to path 4

_MAYAN_BG_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $D8,$B0,0,0        ; path0: header (y=-40, x=-80, relative to center)
    FCB $FF,$00,$7F          ; line 0: flag=-1, dy=0, dx=127
    FCB 2                ; End marker (path complete)

_MAYAN_BG_PATH1:    ; Path 1
    FCB 110              ; path1: intensity
    FCB $D8,$BA,0,0        ; path1: header (y=-40, x=-70, relative to center)
    FCB $FF,$0A,$00          ; line 0: flag=-1, dy=10, dx=0
    FCB $FF,$00,$7F          ; line 1: flag=-1, dy=0, dx=127
    FCB $FF,$F6,$00          ; line 2: flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_MAYAN_BG_PATH2:    ; Path 2
    FCB 110              ; path2: intensity
    FCB $E2,$C4,0,0        ; path2: header (y=-30, x=-60, relative to center)
    FCB $FF,$0A,$00          ; line 0: flag=-1, dy=10, dx=0
    FCB $FF,$00,$78          ; line 1: flag=-1, dy=0, dx=120
    FCB $FF,$F6,$00          ; line 2: flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_MAYAN_BG_PATH3:    ; Path 3
    FCB 120              ; path3: intensity
    FCB $EC,$CE,0,0        ; path3: header (y=-20, x=-50, relative to center)
    FCB $FF,$0A,$00          ; line 0: flag=-1, dy=10, dx=0
    FCB $FF,$00,$64          ; line 1: flag=-1, dy=0, dx=100
    FCB $FF,$F6,$00          ; line 2: flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_MAYAN_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $F6,$D8,0,0        ; path4: header (y=-10, x=-40, relative to center)
    FCB $FF,$28,$00          ; line 0: flag=-1, dy=40, dx=0
    FCB $FF,$0A,$0A          ; line 1: flag=-1, dy=10, dx=10
    FCB $FF,$00,$3C          ; line 2: flag=-1, dy=0, dx=60
    FCB $FF,$F6,$0A          ; line 3: flag=-1, dy=-10, dx=10
    FCB $FF,$D8,$00          ; line 4: flag=-1, dy=-40, dx=0
    FCB 2                ; End marker (path complete)

; Vector asset: hook
; Generated from hook.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 10
; X bounds: min=-6, max=6, width=12
; Center: (0, 0)

_HOOK_WIDTH EQU 12
_HOOK_CENTER_X EQU 0
_HOOK_CENTER_Y EQU 0

_HOOK_VECTORS:  ; Main entry (header + 1 path(s))
    FCB 1               ; path_count (runtime metadata)
    FDB _HOOK_PATH0        ; pointer to path 0

_HOOK_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FC,$FA,0,0        ; path0: header (y=-4, x=-6, relative to center)
    FCB $FF,$0B,$06          ; line 0: flag=-1, dy=11, dx=6
    FCB $FF,$F5,$06          ; line 1: flag=-1, dy=-11, dx=6
    FCB $FF,$00,$FF          ; line 2: flag=-1, dy=0, dx=-1
    FCB $FF,$04,$FC          ; line 3: flag=-1, dy=4, dx=-4
    FCB $FF,$F8,$00          ; line 4: flag=-1, dy=-8, dx=0
    FCB $FF,$00,$FE          ; line 5: flag=-1, dy=0, dx=-2
    FCB $FF,$08,$00          ; line 6: flag=-1, dy=8, dx=0
    FCB $FF,$FC,$FC          ; line 7: flag=-1, dy=-4, dx=-4
    FCB $FF,$00,$FF          ; line 8: flag=-1, dy=0, dx=-1
    FCB 2                ; End marker (path complete)

; Vector asset: map
; Generated from map.vec (Malban Draw_Sync_List format)
; Total paths: 15, points: 165
; X bounds: min=-127, max=115, width=242
; Center: (-6, -3)

_MAP_WIDTH EQU 242
_MAP_CENTER_X EQU -6
_MAP_CENTER_Y EQU -3

_MAP_VECTORS:  ; Main entry (header + 15 path(s))
    FCB 15               ; path_count (runtime metadata)
    FDB _MAP_PATH0        ; pointer to path 0
    FDB _MAP_PATH1        ; pointer to path 1
    FDB _MAP_PATH2        ; pointer to path 2
    FDB _MAP_PATH3        ; pointer to path 3
    FDB _MAP_PATH4        ; pointer to path 4
    FDB _MAP_PATH5        ; pointer to path 5
    FDB _MAP_PATH6        ; pointer to path 6
    FDB _MAP_PATH7        ; pointer to path 7
    FDB _MAP_PATH8        ; pointer to path 8
    FDB _MAP_PATH9        ; pointer to path 9
    FDB _MAP_PATH10        ; pointer to path 10
    FDB _MAP_PATH11        ; pointer to path 11
    FDB _MAP_PATH12        ; pointer to path 12
    FDB _MAP_PATH13        ; pointer to path 13
    FDB _MAP_PATH14        ; pointer to path 14

_MAP_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $22,$D7,0,0        ; path0: header (y=34, x=-41, relative to center)
    FCB $FF,$0E,$1A          ; line 0: flag=-1, dy=14, dx=26
    FCB $FF,$07,$0C          ; line 1: flag=-1, dy=7, dx=12
    FCB $FF,$06,$00          ; line 2: flag=-1, dy=6, dx=0
    FCB $FF,$09,$0C          ; line 3: flag=-1, dy=9, dx=12
    FCB $FF,$00,$0E          ; line 4: flag=-1, dy=0, dx=14
    FCB $FF,$08,$0A          ; line 5: flag=-1, dy=8, dx=10
    FCB $FF,$00,$21          ; line 6: flag=-1, dy=0, dx=33
    FCB $FF,$FC,$03          ; line 7: flag=-1, dy=-4, dx=3
    FCB $FF,$FF,$14          ; line 8: flag=-1, dy=-1, dx=20
    FCB $FF,$EE,$20          ; line 9: flag=-1, dy=-18, dx=32
    FCB $FF,$FB,$FC          ; line 10: flag=-1, dy=-5, dx=-4
    FCB $FF,$F9,$FE          ; line 11: flag=-1, dy=-7, dx=-2
    FCB $FF,$06,$FA          ; line 12: flag=-1, dy=6, dx=-6
    FCB $FF,$02,$F0          ; line 13: flag=-1, dy=2, dx=-16
    FCB $FF,$F4,$06          ; line 14: flag=-1, dy=-12, dx=6
    FCB $FF,$E2,$FE          ; line 15: flag=-1, dy=-30, dx=-2
    FCB $FF,$FB,$FB          ; line 16: flag=-1, dy=-5, dx=-5
    FCB $FF,$F8,$FE          ; line 17: flag=-1, dy=-8, dx=-2
    FCB $FF,$FF,$F6          ; line 18: flag=-1, dy=-1, dx=-10
    FCB $FF,$F7,$05          ; line 19: flag=-1, dy=-9, dx=5
    FCB $FF,$FC,$FD          ; line 20: flag=-1, dy=-4, dx=-3
    FCB $FF,$0E,$F6          ; line 21: flag=-1, dy=14, dx=-10
    FCB $FF,$05,$01          ; line 22: flag=-1, dy=5, dx=1
    FCB $FF,$06,$FD          ; line 23: flag=-1, dy=6, dx=-3
    FCB $FF,$EA,$F7          ; line 24: flag=-1, dy=-22, dx=-9
    FCB $FF,$20,$F0          ; line 25: flag=-1, dy=32, dx=-16
    FCB $FF,$05,$F9          ; line 26: flag=-1, dy=5, dx=-7
    FCB $FF,$F9,$03          ; line 27: flag=-1, dy=-7, dx=3
    FCB $FF,$F5,$F9          ; line 28: flag=-1, dy=-11, dx=-7
    FCB $FF,$0E,$F3          ; line 29: flag=-1, dy=14, dx=-13
    FCB $FF,$FD,$FD          ; line 30: flag=-1, dy=-3, dx=-3
    FCB $FF,$F2,$0C          ; line 31: flag=-1, dy=-14, dx=12
    FCB $FF,$00,$03          ; line 32: flag=-1, dy=0, dx=3
    FCB $FF,$F2,$F7          ; line 33: flag=-1, dy=-14, dx=-9
    FCB $FF,$F3,$FE          ; line 34: flag=-1, dy=-13, dx=-2
    FCB $FF,$EC,$ED          ; line 35: flag=-1, dy=-20, dx=-19
    FCB $FF,$0D,$F3          ; line 36: flag=-1, dy=13, dx=-13
    FCB $FF,$0E,$00          ; line 37: flag=-1, dy=14, dx=0
    FCB $FF,$09,$F8          ; line 38: flag=-1, dy=9, dx=-8
    FCB $FF,$00,$F0          ; line 39: flag=-1, dy=0, dx=-16
    FCB $FF,$08,$F8          ; line 40: flag=-1, dy=8, dx=-8
    FCB $FF,$0B,$00          ; line 41: flag=-1, dy=11, dx=0
    FCB $FF,$0B,$0A          ; line 42: flag=-1, dy=11, dx=10
    FCB $FF,$01,$22          ; line 43: flag=-1, dy=1, dx=34
    FCB $FF,$09,$F4          ; line 44: flag=-1, dy=9, dx=-12
    FCB $FF,$FA,$EE          ; line 45: flag=-1, dy=-6, dx=-18
    FCB $FF,$FF,$F3          ; line 46: flag=-1, dy=-1, dx=-13
    FCB $FF,$0A,$00          ; line 47: flag=-1, dy=10, dx=0
    FCB $FF,$00,$00          ; line 48: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $38,$DE,0,0        ; path1: header (y=56, x=-34, relative to center)
    FCB $FF,$04,$06          ; line 0: flag=-1, dy=4, dx=6
    FCB $FF,$FC,$01          ; line 1: flag=-1, dy=-4, dx=1
    FCB $FF,$FD,$FC          ; line 2: flag=-1, dy=-3, dx=-4
    FCB $FF,$00,$FD          ; line 3: flag=-1, dy=0, dx=-3
    FCB $FF,$03,$00          ; line 4: flag=-1, dy=3, dx=0
    FCB $FF,$00,$00          ; line 5: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $34,$E5,0,0        ; path2: header (y=52, x=-27, relative to center)
    FCB $FF,$06,$0A          ; line 0: flag=-1, dy=6, dx=10
    FCB $FF,$06,$FE          ; line 1: flag=-1, dy=6, dx=-2
    FCB $FF,$02,$05          ; line 2: flag=-1, dy=2, dx=5
    FCB $FF,$FB,$FE          ; line 3: flag=-1, dy=-5, dx=-2
    FCB $FF,$F6,$02          ; line 4: flag=-1, dy=-10, dx=2
    FCB $FF,$FF,$F4          ; line 5: flag=-1, dy=-1, dx=-12
    FCB $FF,$02,$FF          ; line 6: flag=-1, dy=2, dx=-1
    FCB $FF,$00,$00          ; line 7: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $BD,$70,0,0        ; path3: header (y=-67, x=112, relative to center)
    FCB $FF,$08,$05          ; line 0: flag=-1, dy=8, dx=5
    FCB $FF,$14,$00          ; line 1: flag=-1, dy=20, dx=0
    FCB $FF,$06,$FB          ; line 2: flag=-1, dy=6, dx=-5
    FCB $FF,$F8,$FE          ; line 3: flag=-1, dy=-8, dx=-2
    FCB $FF,$06,$EE          ; line 4: flag=-1, dy=6, dx=-18
    FCB $FF,$F3,$F1          ; line 5: flag=-1, dy=-13, dx=-15
    FCB $FF,$F5,$07          ; line 6: flag=-1, dy=-11, dx=7
    FCB $FF,$03,$0C          ; line 7: flag=-1, dy=3, dx=12
    FCB $FF,$F4,$10          ; line 8: flag=-1, dy=-12, dx=16
    FCB $FF,$00,$00          ; line 9: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $ED,$66,0,0        ; path4: header (y=-19, x=102, relative to center)
    FCB $FF,$F1,$00          ; line 0: flag=-1, dy=-15, dx=0
    FCB $FF,$04,$F8          ; line 1: flag=-1, dy=4, dx=-8
    FCB $FF,$05,$00          ; line 2: flag=-1, dy=5, dx=0
    FCB $FF,$06,$09          ; line 3: flag=-1, dy=6, dx=9
    FCB $FF,$00,$00          ; line 4: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $EE,$57,0,0        ; path5: header (y=-18, x=87, relative to center)
    FCB $FF,$F8,$05          ; line 0: flag=-1, dy=-8, dx=5
    FCB $FF,$F9,$FF          ; line 1: flag=-1, dy=-7, dx=-1
    FCB $FF,$05,$FA          ; line 2: flag=-1, dy=5, dx=-6
    FCB $FF,$0A,$02          ; line 3: flag=-1, dy=10, dx=2
    FCB $FF,$00,$00          ; line 4: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $E6,$72,0,0        ; path6: header (y=-26, x=114, relative to center)
    FCB $FF,$FD,$FB          ; line 0: flag=-1, dy=-3, dx=-5
    FCB $FF,$FB,$08          ; line 1: flag=-1, dy=-5, dx=8
    FCB $FF,$04,$00          ; line 2: flag=-1, dy=4, dx=0
    FCB $FF,$04,$FD          ; line 3: flag=-1, dy=4, dx=-3
    FCB $FF,$00,$00          ; line 4: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $DD,$1A,0,0        ; path7: header (y=-35, x=26, relative to center)
    FCB $FF,$09,$08          ; line 0: flag=-1, dy=9, dx=8
    FCB $FF,$01,$FA          ; line 1: flag=-1, dy=1, dx=-6
    FCB $FF,$F7,$FA          ; line 2: flag=-1, dy=-9, dx=-6
    FCB $FF,$FE,$05          ; line 3: flag=-1, dy=-2, dx=5
    FCB $FF,$00,$00          ; line 4: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $4C,$B0,0,0        ; path8: header (y=76, x=-80, relative to center)
    FCB $FF,$FC,$0D          ; line 0: flag=-1, dy=-4, dx=13
    FCB $FF,$FD,$00          ; line 1: flag=-1, dy=-3, dx=0
    FCB $FF,$FA,$08          ; line 2: flag=-1, dy=-6, dx=8
    FCB $FF,$09,$06          ; line 3: flag=-1, dy=9, dx=6
    FCB $FF,$09,$F2          ; line 4: flag=-1, dy=9, dx=-14
    FCB $FF,$FF,$F6          ; line 5: flag=-1, dy=-1, dx=-10
    FCB $FF,$FC,$FD          ; line 6: flag=-1, dy=-4, dx=-3
    FCB $FF,$00,$00          ; line 7: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $2D,$87,0,0        ; path9: header (y=45, x=-121, relative to center)
    FCB $FF,$F7,$08          ; line 0: flag=-1, dy=-9, dx=8
    FCB $FF,$F7,$F9          ; line 1: flag=-1, dy=-9, dx=-7
    FCB $FF,$E4,$17          ; line 2: flag=-1, dy=-28, dx=23
    FCB $FF,$FE,$16          ; line 3: flag=-1, dy=-2, dx=22
    FCB $FF,$09,$F6          ; line 4: flag=-1, dy=9, dx=-10
    FCB $FF,$00,$FA          ; line 5: flag=-1, dy=0, dx=-6
    FCB $FF,$0D,$FE          ; line 6: flag=-1, dy=13, dx=-2
    FCB $FF,$09,$0E          ; line 7: flag=-1, dy=9, dx=14
    FCB $FF,$F9,$06          ; line 8: flag=-1, dy=-7, dx=6
    FCB $FF,$18,$13          ; line 9: flag=-1, dy=24, dx=19
    FCB $FF,$10,$F5          ; line 10: flag=-1, dy=16, dx=-11
    FCB $FF,$F4,$FD          ; line 11: flag=-1, dy=-12, dx=-3
    FCB $FF,$04,$F5          ; line 12: flag=-1, dy=4, dx=-11
    FCB $FF,$08,$01          ; line 13: flag=-1, dy=8, dx=1
    FCB $FF,$0A,$EE          ; line 14: flag=-1, dy=10, dx=-18
    FCB $FF,$06,$E7          ; line 15: flag=-1, dy=6, dx=-25
    FCB $FF,$DF,$01          ; line 16: flag=-1, dy=-33, dx=1
    FCB $FF,$00,$00          ; line 17: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $04,$BE,0,0        ; path10: header (y=4, x=-66, relative to center)
    FCB $FF,$ED,$F8          ; line 0: flag=-1, dy=-19, dx=-8
    FCB $FF,$F9,$06          ; line 1: flag=-1, dy=-7, dx=6
    FCB $FF,$E0,$05          ; line 2: flag=-1, dy=-32, dx=5
    FCB $FF,$19,$14          ; line 3: flag=-1, dy=25, dx=20
    FCB $FF,$FF,$08          ; line 4: flag=-1, dy=-1, dx=8
    FCB $FF,$10,$00          ; line 5: flag=-1, dy=16, dx=0
    FCB $FF,$03,$F7          ; line 6: flag=-1, dy=3, dx=-9
    FCB $FF,$09,$F8          ; line 7: flag=-1, dy=9, dx=-8
    FCB $FF,$06,$F3          ; line 8: flag=-1, dy=6, dx=-13
    FCB $FF,$01,$00          ; line 9: flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $B0,$AE,0,0        ; path11: header (y=-80, x=-82, relative to center)
    FCB $FF,$0D,$0C          ; line 0: flag=-1, dy=13, dx=12
    FCB $FF,$FB,$0D          ; line 1: flag=-1, dy=-5, dx=13
    FCB $FF,$F9,$08          ; line 2: flag=-1, dy=-7, dx=8
    FCB $FF,$FE,$DF          ; line 3: flag=-1, dy=-2, dx=-33
    FCB $FF,$00,$00          ; line 4: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $0E,$69,0,0        ; path12: header (y=14, x=105, relative to center)
    FCB $FF,$08,$FC          ; line 0: flag=-1, dy=8, dx=-4
    FCB $FF,$01,$01          ; line 1: flag=-1, dy=1, dx=1
    FCB $FF,$02,$03          ; line 2: flag=-1, dy=2, dx=3
    FCB $FF,$F5,$00          ; line 3: flag=-1, dy=-11, dx=0
    FCB $FF,$00,$00          ; line 4: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $24,$69,0,0        ; path13: header (y=36, x=105, relative to center)
    FCB $FF,$04,$07          ; line 0: flag=-1, dy=4, dx=7
    FCB $FF,$04,$F9          ; line 1: flag=-1, dy=4, dx=-7
    FCB $FF,$F8,$00          ; line 2: flag=-1, dy=-8, dx=0
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $21,$6D,0,0        ; path14: header (y=33, x=109, relative to center)
    FCB $FF,$F9,$FD          ; line 0: flag=-1, dy=-7, dx=-3
    FCB $FF,$FB,$02          ; line 1: flag=-1, dy=-5, dx=2
    FCB $FF,$FF,$03          ; line 2: flag=-1, dy=-1, dx=3
    FCB $FF,$05,$04          ; line 3: flag=-1, dy=5, dx=4
    FCB $FF,$08,$FC          ; line 4: flag=-1, dy=8, dx=-4
    FCB $FF,$00,$FE          ; line 5: flag=-1, dy=0, dx=-2
    FCB $FF,$00,$00          ; line 6: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

; Vector asset: london_bg
; Generated from london_bg.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 16
; X bounds: min=-20, max=20, width=40
; Center: (0, 15)

_LONDON_BG_WIDTH EQU 40
_LONDON_BG_CENTER_X EQU 0
_LONDON_BG_CENTER_Y EQU 15

_LONDON_BG_VECTORS:  ; Main entry (header + 4 path(s))
    FCB 4               ; path_count (runtime metadata)
    FDB _LONDON_BG_PATH0        ; pointer to path 0
    FDB _LONDON_BG_PATH1        ; pointer to path 1
    FDB _LONDON_BG_PATH2        ; pointer to path 2
    FDB _LONDON_BG_PATH3        ; pointer to path 3

_LONDON_BG_PATH0:    ; Path 0
    FCB 110              ; path0: intensity
    FCB $D3,$EC,0,0        ; path0: header (y=-45, x=-20, relative to center)
    FCB $FF,$46,$00          ; line 0: flag=-1, dy=70, dx=0
    FCB $FF,$00,$28          ; line 1: flag=-1, dy=0, dx=40
    FCB $FF,$BA,$00          ; line 2: flag=-1, dy=-70, dx=0
    FCB 2                ; End marker (path complete)

_LONDON_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $23,$F1,0,0        ; path1: header (y=35, x=-15, relative to center)
    FCB $FF,$0A,$00          ; line 0: flag=-1, dy=10, dx=0
    FCB $FF,$00,$1E          ; line 1: flag=-1, dy=0, dx=30
    FCB $FF,$F6,$00          ; line 2: flag=-1, dy=-10, dx=0
    FCB $FF,$00,$E2          ; line 3: flag=-1, dy=0, dx=-30
    FCB 2                ; End marker (path complete)

_LONDON_BG_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $28,$00,0,0        ; path2: header (y=40, x=0, relative to center)
    FCB $FF,$05,$00          ; line 0: flag=-1, dy=5, dx=0
    FCB $FF,$FB,$08          ; line 1: flag=-1, dy=-5, dx=8
    FCB 2                ; End marker (path complete)

_LONDON_BG_PATH3:    ; Path 3
    FCB 120              ; path3: intensity
    FCB $19,$EC,0,0        ; path3: header (y=25, x=-20, relative to center)
    FCB $FF,$0A,$05          ; line 0: flag=-1, dy=10, dx=5
    FCB $FF,$00,$1E          ; line 1: flag=-1, dy=0, dx=30
    FCB $FF,$F6,$05          ; line 2: flag=-1, dy=-10, dx=5
    FCB 2                ; End marker (path complete)

; Vector asset: leningrad_bg
; Generated from leningrad_bg.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 21
; X bounds: min=-30, max=30, width=60
; Center: (0, 30)

_LENINGRAD_BG_WIDTH EQU 60
_LENINGRAD_BG_CENTER_X EQU 0
_LENINGRAD_BG_CENTER_Y EQU 30

_LENINGRAD_BG_VECTORS:  ; Main entry (header + 5 path(s))
    FCB 5               ; path_count (runtime metadata)
    FDB _LENINGRAD_BG_PATH0        ; pointer to path 0
    FDB _LENINGRAD_BG_PATH1        ; pointer to path 1
    FDB _LENINGRAD_BG_PATH2        ; pointer to path 2
    FDB _LENINGRAD_BG_PATH3        ; pointer to path 3
    FDB _LENINGRAD_BG_PATH4        ; pointer to path 4

_LENINGRAD_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $05,$E7,0,0        ; path0: header (y=5, x=-25, relative to center)
    FCB $FF,$14,$0A          ; line 0: flag=-1, dy=20, dx=10
    FCB $FF,$05,$0F          ; line 1: flag=-1, dy=5, dx=15
    FCB $FF,$FB,$0F          ; line 2: flag=-1, dy=-5, dx=15
    FCB $FF,$EC,$0A          ; line 3: flag=-1, dy=-20, dx=10
    FCB 2                ; End marker (path complete)

_LENINGRAD_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $1E,$00,0,0        ; path1: header (y=30, x=0, relative to center)
    FCB $FF,$0A,$00          ; line 0: flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_LENINGRAD_BG_PATH2:    ; Path 2
    FCB 110              ; path2: intensity
    FCB $05,$E2,0,0        ; path2: header (y=5, x=-30, relative to center)
    FCB $FF,$D3,$00          ; line 0: flag=-1, dy=-45, dx=0
    FCB $FF,$00,$3C          ; line 1: flag=-1, dy=0, dx=60
    FCB $FF,$2D,$00          ; line 2: flag=-1, dy=45, dx=0
    FCB 2                ; End marker (path complete)

_LENINGRAD_BG_PATH3:    ; Path 3
    FCB 90              ; path3: intensity
    FCB $EC,$EC,0,0        ; path3: header (y=-20, x=-20, relative to center)
    FCB $FF,$0F,$00          ; line 0: flag=-1, dy=15, dx=0
    FCB $FF,$00,$0A          ; line 1: flag=-1, dy=0, dx=10
    FCB $FF,$F1,$00          ; line 2: flag=-1, dy=-15, dx=0
    FCB $FF,$00,$F6          ; line 3: flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_LENINGRAD_BG_PATH4:    ; Path 4
    FCB 90              ; path4: intensity
    FCB $EC,$0A,0,0        ; path4: header (y=-20, x=10, relative to center)
    FCB $FF,$0F,$00          ; line 0: flag=-1, dy=15, dx=0
    FCB $FF,$00,$0A          ; line 1: flag=-1, dy=0, dx=10
    FCB $FF,$F1,$00          ; line 2: flag=-1, dy=-15, dx=0
    FCB $FF,$00,$F6          ; line 3: flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

; Vector asset: location_marker
; Generated from location_marker.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 10
; X bounds: min=-11, max=11, width=22
; Center: (0, 1)

_LOCATION_MARKER_WIDTH EQU 22
_LOCATION_MARKER_CENTER_X EQU 0
_LOCATION_MARKER_CENTER_Y EQU 1

_LOCATION_MARKER_VECTORS:  ; Main entry (header + 1 path(s))
    FCB 1               ; path_count (runtime metadata)
    FDB _LOCATION_MARKER_PATH0        ; pointer to path 0

_LOCATION_MARKER_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $0B,$00,0,0        ; path0: header (y=11, x=0, relative to center)
    FCB $FF,$F8,$04          ; line 0: flag=-1, dy=-8, dx=4
    FCB $FF,$00,$07          ; line 1: flag=-1, dy=0, dx=7
    FCB $FF,$F9,$FC          ; line 2: flag=-1, dy=-7, dx=-4
    FCB $FF,$F9,$00          ; line 3: flag=-1, dy=-7, dx=0
    FCB $FF,$05,$F9          ; line 4: flag=-1, dy=5, dx=-7
    FCB $FF,$FB,$F9          ; line 5: flag=-1, dy=-5, dx=-7
    FCB $FF,$07,$00          ; line 6: flag=-1, dy=7, dx=0
    FCB $FF,$07,$FC          ; line 7: flag=-1, dy=7, dx=-4
    FCB $FF,$00,$07          ; line 8: flag=-1, dy=0, dx=7
    FCB $FF,$08,$04          ; closing line: flag=-1, dy=8, dx=4
    FCB 2                ; End marker (path complete)

; Vector asset: ayers_bg
; Generated from ayers_bg.vec (Malban Draw_Sync_List format)
; Total paths: 18, points: 106
; X bounds: min=-96, max=102, width=198
; Center: (3, 10)

_AYERS_BG_WIDTH EQU 198
_AYERS_BG_CENTER_X EQU 3
_AYERS_BG_CENTER_Y EQU 10

_AYERS_BG_VECTORS:  ; Main entry (header + 18 path(s))
    FCB 18               ; path_count (runtime metadata)
    FDB _AYERS_BG_PATH0        ; pointer to path 0
    FDB _AYERS_BG_PATH1        ; pointer to path 1
    FDB _AYERS_BG_PATH2        ; pointer to path 2
    FDB _AYERS_BG_PATH3        ; pointer to path 3
    FDB _AYERS_BG_PATH4        ; pointer to path 4
    FDB _AYERS_BG_PATH5        ; pointer to path 5
    FDB _AYERS_BG_PATH6        ; pointer to path 6
    FDB _AYERS_BG_PATH7        ; pointer to path 7
    FDB _AYERS_BG_PATH8        ; pointer to path 8
    FDB _AYERS_BG_PATH9        ; pointer to path 9
    FDB _AYERS_BG_PATH10        ; pointer to path 10
    FDB _AYERS_BG_PATH11        ; pointer to path 11
    FDB _AYERS_BG_PATH12        ; pointer to path 12
    FDB _AYERS_BG_PATH13        ; pointer to path 13
    FDB _AYERS_BG_PATH14        ; pointer to path 14
    FDB _AYERS_BG_PATH15        ; pointer to path 15
    FDB _AYERS_BG_PATH16        ; pointer to path 16
    FDB _AYERS_BG_PATH17        ; pointer to path 17

_AYERS_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $E2,$9D,0,0        ; path0: header (y=-30, x=-99, relative to center)
    FCB $FF,$2A,$0C          ; line 0: flag=-1, dy=42, dx=12
    FCB $FF,$05,$0D          ; line 1: flag=-1, dy=5, dx=13
    FCB $FF,$04,$0F          ; line 2: flag=-1, dy=4, dx=15
    FCB $FF,$03,$0F          ; line 3: flag=-1, dy=3, dx=15
    FCB $FF,$05,$09          ; line 4: flag=-1, dy=5, dx=9
    FCB $FF,$FC,$0C          ; line 5: flag=-1, dy=-4, dx=12
    FCB $FF,$02,$0E          ; line 6: flag=-1, dy=2, dx=14
    FCB $FF,$05,$0C          ; line 7: flag=-1, dy=5, dx=12
    FCB $FF,$FF,$0C          ; line 8: flag=-1, dy=-1, dx=12
    FCB $FF,$FA,$0D          ; line 9: flag=-1, dy=-6, dx=13
    FCB $FF,$01,$10          ; line 10: flag=-1, dy=1, dx=16
    FCB $FF,$FB,$0E          ; line 11: flag=-1, dy=-5, dx=14
    FCB $FF,$F5,$10          ; line 12: flag=-1, dy=-11, dx=16
    FCB $FF,$F2,$0B          ; line 13: flag=-1, dy=-14, dx=11
    FCB $FF,$EE,$0B          ; line 14: flag=-1, dy=-18, dx=11
    FCB $FF,$F7,$03          ; line 15: flag=-1, dy=-9, dx=3
    FCB $FF,$01,$81          ; line 16: flag=-1, dy=1, dx=-127
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $11,$B6,0,0        ; path1: header (y=17, x=-74, relative to center)
    FCB $FF,$EA,$F9          ; line 0: flag=-1, dy=-22, dx=-7
    FCB $FF,$E7,$F8          ; line 1: flag=-1, dy=-25, dx=-8
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $E2,$BB,0,0        ; path2: header (y=-30, x=-69, relative to center)
    FCB $FF,$1C,$02          ; line 0: flag=-1, dy=28, dx=2
    FCB $FF,$08,$06          ; line 1: flag=-1, dy=8, dx=6
    FCB $FF,$F5,$FF          ; line 2: flag=-1, dy=-11, dx=-1
    FCB $FF,$E7,$FC          ; line 3: flag=-1, dy=-25, dx=-4
    FCB $FF,$00,$00          ; line 4: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $19,$E9,0,0        ; path3: header (y=25, x=-23, relative to center)
    FCB $FF,$EF,$FD          ; line 0: flag=-1, dy=-17, dx=-3
    FCB $FF,$F2,$03          ; line 1: flag=-1, dy=-14, dx=3
    FCB $FF,$F5,$00          ; line 2: flag=-1, dy=-11, dx=0
    FCB $FF,$09,$05          ; line 3: flag=-1, dy=9, dx=5
    FCB $FF,$0C,$06          ; line 4: flag=-1, dy=12, dx=6
    FCB $FF,$18,$06          ; line 5: flag=-1, dy=24, dx=6
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $1A,$F0,0,0        ; path4: header (y=26, x=-16, relative to center)
    FCB $FF,$EF,$FA          ; line 0: flag=-1, dy=-17, dx=-6
    FCB $FF,$F6,$03          ; line 1: flag=-1, dy=-10, dx=3
    FCB $FF,$09,$04          ; line 2: flag=-1, dy=9, dx=4
    FCB $FF,$13,$06          ; line 3: flag=-1, dy=19, dx=6
    FCB $FF,$00,$00          ; line 4: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $E2,$C4,0,0        ; path5: header (y=-30, x=-60, relative to center)
    FCB $FF,$16,$08          ; line 0: flag=-1, dy=22, dx=8
    FCB $FF,$20,$07          ; line 1: flag=-1, dy=32, dx=7
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $19,$D6,0,0        ; path6: header (y=25, x=-42, relative to center)
    FCB $FF,$E9,$FB          ; line 0: flag=-1, dy=-23, dx=-5
    FCB $FF,$EE,$FD          ; line 1: flag=-1, dy=-18, dx=-3
    FCB $FF,$F2,$01          ; line 2: flag=-1, dy=-14, dx=1
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $20,$07,0,0        ; path7: header (y=32, x=7, relative to center)
    FCB $FF,$F0,$02          ; line 0: flag=-1, dy=-16, dx=2
    FCB $FF,$F2,$FA          ; line 1: flag=-1, dy=-14, dx=-6
    FCB $FF,$EF,$01          ; line 2: flag=-1, dy=-17, dx=1
    FCB $FF,$0B,$03          ; line 3: flag=-1, dy=11, dx=3
    FCB $FF,$0E,$04          ; line 4: flag=-1, dy=14, dx=4
    FCB $FF,$13,$07          ; line 5: flag=-1, dy=19, dx=7
    FCB $FF,$00,$00          ; line 6: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $19,$1F,0,0        ; path8: header (y=25, x=31, relative to center)
    FCB $FF,$EB,$0A          ; line 0: flag=-1, dy=-21, dx=10
    FCB $FF,$E6,$01          ; line 1: flag=-1, dy=-26, dx=1
    FCB $FF,$F7,$FF          ; line 2: flag=-1, dy=-9, dx=-1
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $E1,$25,0,0        ; path9: header (y=-31, x=37, relative to center)
    FCB $FF,$08,$F9          ; line 0: flag=-1, dy=8, dx=-7
    FCB $FF,$1A,$FC          ; line 1: flag=-1, dy=26, dx=-4
    FCB $FF,$E6,$FE          ; line 2: flag=-1, dy=-26, dx=-2
    FCB $FF,$F9,$F9          ; line 3: flag=-1, dy=-7, dx=-7
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $E2,$0A,0,0        ; path10: header (y=-30, x=10, relative to center)
    FCB $FF,$12,$01          ; line 0: flag=-1, dy=18, dx=1
    FCB $FF,$13,$06          ; line 1: flag=-1, dy=19, dx=6
    FCB $FF,$F1,$FF          ; line 2: flag=-1, dy=-15, dx=-1
    FCB $FF,$EA,$00          ; line 3: flag=-1, dy=-22, dx=0
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $E1,$07,0,0        ; path11: header (y=-31, x=7, relative to center)
    FCB $FF,$06,$F8          ; line 0: flag=-1, dy=6, dx=-8
    FCB $FF,$01,$FD          ; line 1: flag=-1, dy=1, dx=-3
    FCB $FF,$13,$FC          ; line 2: flag=-1, dy=19, dx=-4
    FCB $FF,$F6,$FE          ; line 3: flag=-1, dy=-10, dx=-2
    FCB $FF,$F6,$01          ; line 4: flag=-1, dy=-10, dx=1
    FCB $FF,$00,$F3          ; line 5: flag=-1, dy=0, dx=-13
    FCB $FF,$03,$FD          ; line 6: flag=-1, dy=3, dx=-3
    FCB $FF,$FA,$FC          ; line 7: flag=-1, dy=-6, dx=-4
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $E4,$E3,0,0        ; path12: header (y=-28, x=-29, relative to center)
    FCB $FF,$04,$F5          ; line 0: flag=-1, dy=4, dx=-11
    FCB $FF,$20,$05          ; line 1: flag=-1, dy=32, dx=5
    FCB $FF,$F9,$FA          ; line 2: flag=-1, dy=-7, dx=-6
    FCB $FF,$EF,$FE          ; line 3: flag=-1, dy=-17, dx=-2
    FCB $FF,$F8,$00          ; line 4: flag=-1, dy=-8, dx=0
    FCB $FF,$FD,$FA          ; line 5: flag=-1, dy=-3, dx=-6
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $07,$2C,0,0        ; path13: header (y=7, x=44, relative to center)
    FCB $FF,$DB,$03          ; line 0: flag=-1, dy=-37, dx=3
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $E1,$3C,0,0        ; path14: header (y=-31, x=60, relative to center)
    FCB $FF,$1A,$FE          ; line 0: flag=-1, dy=26, dx=-2
    FCB $FF,$1B,$FE          ; line 1: flag=-1, dy=27, dx=-2
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $E1,$4C,0,0        ; path15: header (y=-31, x=76, relative to center)
    FCB $FF,$15,$FC          ; line 0: flag=-1, dy=21, dx=-4
    FCB $FF,$03,$FD          ; line 1: flag=-1, dy=3, dx=-3
    FCB $FF,$10,$FE          ; line 2: flag=-1, dy=16, dx=-2
    FCB $FF,$EE,$FE          ; line 3: flag=-1, dy=-18, dx=-2
    FCB $FF,$1F,$F7          ; line 4: flag=-1, dy=31, dx=-9
    FCB $FF,$00,$00          ; line 5: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $E1,$53,0,0        ; path16: header (y=-31, x=83, relative to center)
    FCB $FF,$23,$F7          ; line 0: flag=-1, dy=35, dx=-9
    FCB $FF,$E2,$0D          ; line 1: flag=-1, dy=-30, dx=13
    FCB $FF,$1A,$FB          ; line 2: flag=-1, dy=26, dx=-5
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $06,$2C,0,0        ; path17: header (y=6, x=44, relative to center)
    FCB $FF,$13,$F7          ; line 0: flag=-1, dy=19, dx=-9
    FCB 2                ; End marker (path complete)

; Vector asset: fuji_bg
; Generated from fuji_bg.vec (Malban Draw_Sync_List format)
; Total paths: 6, points: 65
; X bounds: min=-125, max=125, width=250
; Center: (0, 0)

_FUJI_BG_WIDTH EQU 250
_FUJI_BG_CENTER_X EQU 0
_FUJI_BG_CENTER_Y EQU 0

_FUJI_BG_VECTORS:  ; Main entry (header + 6 path(s))
    FCB 6               ; path_count (runtime metadata)
    FDB _FUJI_BG_PATH0        ; pointer to path 0
    FDB _FUJI_BG_PATH1        ; pointer to path 1
    FDB _FUJI_BG_PATH2        ; pointer to path 2
    FDB _FUJI_BG_PATH3        ; pointer to path 3
    FDB _FUJI_BG_PATH4        ; pointer to path 4
    FDB _FUJI_BG_PATH5        ; pointer to path 5

_FUJI_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $CF,$83,0,0        ; path0: header (y=-49, x=-125, relative to center)
    FCB 2                ; End marker (path complete)

_FUJI_BG_PATH1:    ; Path 1
    FCB 80              ; path1: intensity
    FCB $E8,$84,0,0        ; path1: header (y=-24, x=-124, relative to center)
    FCB $FF,$0A,$1E          ; line 0: flag=-1, dy=10, dx=30
    FCB $FF,$0E,$1E          ; line 1: flag=-1, dy=14, dx=30
    FCB $FF,$0F,$15          ; line 2: flag=-1, dy=15, dx=21
    FCB $FF,$11,$17          ; line 3: flag=-1, dy=17, dx=23
    FCB $FF,$0E,$0E          ; line 4: flag=-1, dy=14, dx=14
    FCB $FF,$FE,$03          ; line 5: flag=-1, dy=-2, dx=3
    FCB $FF,$03,$04          ; line 6: flag=-1, dy=3, dx=4
    FCB $FF,$FE,$04          ; line 7: flag=-1, dy=-2, dx=4
    FCB $FF,$01,$07          ; line 8: flag=-1, dy=1, dx=7
    FCB $FF,$02,$04          ; line 9: flag=-1, dy=2, dx=4
    FCB $FF,$FD,$06          ; line 10: flag=-1, dy=-3, dx=6
    FCB $FF,$03,$03          ; line 11: flag=-1, dy=3, dx=3
    FCB $FF,$EB,$11          ; line 12: flag=-1, dy=-21, dx=17
    FCB $FF,$F4,$11          ; line 13: flag=-1, dy=-12, dx=17
    FCB $FF,$F0,$16          ; line 14: flag=-1, dy=-16, dx=22
    FCB $FF,$F6,$14          ; line 15: flag=-1, dy=-10, dx=20
    FCB $FF,$F6,$18          ; line 16: flag=-1, dy=-10, dx=24
    FCB $FF,$00,$00          ; line 17: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_FUJI_BG_PATH2:    ; Path 2
    FCB 95              ; path2: intensity
    FCB $1A,$F1,0,0        ; path2: header (y=26, x=-15, relative to center)
    FCB $FF,$06,$03          ; line 0: flag=-1, dy=6, dx=3
    FCB $FF,$04,$03          ; line 1: flag=-1, dy=4, dx=3
    FCB $FF,$FD,$04          ; line 2: flag=-1, dy=-3, dx=4
    FCB $FF,$FC,$FC          ; line 3: flag=-1, dy=-4, dx=-4
    FCB $FF,$FD,$FA          ; line 4: flag=-1, dy=-3, dx=-6
    FCB $FF,$00,$00          ; line 5: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_FUJI_BG_PATH3:    ; Path 3
    FCB 95              ; path3: intensity
    FCB $1F,$07,0,0        ; path3: header (y=31, x=7, relative to center)
    FCB $FF,$F9,$FD          ; line 0: flag=-1, dy=-7, dx=-3
    FCB $FF,$FA,$02          ; line 1: flag=-1, dy=-6, dx=2
    FCB $FF,$F9,$FD          ; line 2: flag=-1, dy=-7, dx=-3
    FCB $FF,$FD,$04          ; line 3: flag=-1, dy=-3, dx=4
    FCB $FF,$08,$03          ; line 4: flag=-1, dy=8, dx=3
    FCB $FF,$07,$FE          ; line 5: flag=-1, dy=7, dx=-2
    FCB $FF,$06,$01          ; line 6: flag=-1, dy=6, dx=1
    FCB $FF,$02,$FE          ; line 7: flag=-1, dy=2, dx=-2
    FCB 2                ; End marker (path complete)

_FUJI_BG_PATH4:    ; Path 4
    FCB 95              ; path4: intensity
    FCB $21,$18,0,0        ; path4: header (y=33, x=24, relative to center)
    FCB $FF,$F7,$05          ; line 0: flag=-1, dy=-9, dx=5
    FCB $FF,$F7,$0C          ; line 1: flag=-1, dy=-9, dx=12
    FCB $FF,$0B,$FA          ; line 2: flag=-1, dy=11, dx=-6
    FCB $FF,$07,$F5          ; line 3: flag=-1, dy=7, dx=-11
    FCB 2                ; End marker (path complete)

_FUJI_BG_PATH5:    ; Path 5
    FCB 100              ; path5: intensity
    FCB $05,$C7,0,0        ; path5: header (y=5, x=-57, relative to center)
    FCB $FF,$09,$1A          ; line 0: flag=-1, dy=9, dx=26
    FCB $FF,$EF,$F2          ; line 1: flag=-1, dy=-17, dx=-14
    FCB $FF,$1B,$22          ; line 2: flag=-1, dy=27, dx=34
    FCB $FF,$F2,$FB          ; line 3: flag=-1, dy=-14, dx=-5
    FCB $FF,$00,$03          ; line 4: flag=-1, dy=0, dx=3
    FCB $FF,$F7,$FB          ; line 5: flag=-1, dy=-9, dx=-5
    FCB $FF,$FA,$01          ; line 6: flag=-1, dy=-6, dx=1
    FCB $FF,$0E,$0E          ; line 7: flag=-1, dy=14, dx=14
    FCB $FF,$F1,$00          ; line 8: flag=-1, dy=-15, dx=0
    FCB $FF,$0A,$05          ; line 9: flag=-1, dy=10, dx=5
    FCB $FF,$EA,$06          ; line 10: flag=-1, dy=-22, dx=6
    FCB $FF,$1C,$05          ; line 11: flag=-1, dy=28, dx=5
    FCB $FF,$EF,$06          ; line 12: flag=-1, dy=-17, dx=6
    FCB $FF,$03,$01          ; line 13: flag=-1, dy=3, dx=1
    FCB $FF,$FD,$04          ; line 14: flag=-1, dy=-3, dx=4
    FCB $FF,$0B,$03          ; line 15: flag=-1, dy=11, dx=3
    FCB $FF,$F5,$05          ; line 16: flag=-1, dy=-11, dx=5
    FCB $FF,$10,$FF          ; line 17: flag=-1, dy=16, dx=-1
    FCB $FF,$EE,$13          ; line 18: flag=-1, dy=-18, dx=19
    FCB $FF,$12,$F7          ; line 19: flag=-1, dy=18, dx=-9
    FCB $FF,$F9,$0E          ; line 20: flag=-1, dy=-7, dx=14
    FCB $FF,$04,$02          ; line 21: flag=-1, dy=4, dx=2
    FCB $FF,$FC,$14          ; line 22: flag=-1, dy=-4, dx=20
    FCB 2                ; End marker (path complete)

; Vector asset: kilimanjaro_bg
; Generated from kilimanjaro_bg.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 13
; X bounds: min=-100, max=100, width=200
; Center: (0, 12)

_KILIMANJARO_BG_WIDTH EQU 200
_KILIMANJARO_BG_CENTER_X EQU 0
_KILIMANJARO_BG_CENTER_Y EQU 12

_KILIMANJARO_BG_VECTORS:  ; Main entry (header + 4 path(s))
    FCB 4               ; path_count (runtime metadata)
    FDB _KILIMANJARO_BG_PATH0        ; pointer to path 0
    FDB _KILIMANJARO_BG_PATH1        ; pointer to path 1
    FDB _KILIMANJARO_BG_PATH2        ; pointer to path 2
    FDB _KILIMANJARO_BG_PATH3        ; pointer to path 3

_KILIMANJARO_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $D6,$9C,0,0        ; path0: header (y=-42, x=-100, relative to center)
    FCB $FF,$3C,$32          ; line 0: flag=-1, dy=60, dx=50
    FCB $FF,$19,$32          ; line 1: flag=-1, dy=25, dx=50
    FCB $FF,$E7,$32          ; line 2: flag=-1, dy=-25, dx=50
    FCB $FF,$C4,$32          ; line 3: flag=-1, dy=-60, dx=50
    FCB 2                ; End marker (path complete)

_KILIMANJARO_BG_PATH1:    ; Path 1
    FCB 110              ; path1: intensity
    FCB $1C,$E2,0,0        ; path1: header (y=28, x=-30, relative to center)
    FCB $FF,$0F,$1E          ; line 0: flag=-1, dy=15, dx=30
    FCB $FF,$F1,$00          ; line 1: flag=-1, dy=-15, dx=0
    FCB 2                ; End marker (path complete)

_KILIMANJARO_BG_PATH2:    ; Path 2
    FCB 110              ; path2: intensity
    FCB $1C,$00,0,0        ; path2: header (y=28, x=0, relative to center)
    FCB $FF,$0F,$00          ; line 0: flag=-1, dy=15, dx=0
    FCB $FF,$F1,$1E          ; line 1: flag=-1, dy=-15, dx=30
    FCB 2                ; End marker (path complete)

_KILIMANJARO_BG_PATH3:    ; Path 3
    FCB 90              ; path3: intensity
    FCB $F4,$BA,0,0        ; path3: header (y=-12, x=-70, relative to center)
    FCB $FF,$14,$1E          ; line 0: flag=-1, dy=20, dx=30
    FCB 2                ; End marker (path complete)

; Vector asset: athens_bg
; Generated from athens_bg.vec (Malban Draw_Sync_List format)
; Total paths: 41, points: 147
; X bounds: min=-80, max=80, width=160
; Center: (0, 0)

_ATHENS_BG_WIDTH EQU 160
_ATHENS_BG_CENTER_X EQU 0
_ATHENS_BG_CENTER_Y EQU 0

_ATHENS_BG_VECTORS:  ; Main entry (header + 41 path(s))
    FCB 41               ; path_count (runtime metadata)
    FDB _ATHENS_BG_PATH0        ; pointer to path 0
    FDB _ATHENS_BG_PATH1        ; pointer to path 1
    FDB _ATHENS_BG_PATH2        ; pointer to path 2
    FDB _ATHENS_BG_PATH3        ; pointer to path 3
    FDB _ATHENS_BG_PATH4        ; pointer to path 4
    FDB _ATHENS_BG_PATH5        ; pointer to path 5
    FDB _ATHENS_BG_PATH6        ; pointer to path 6
    FDB _ATHENS_BG_PATH7        ; pointer to path 7
    FDB _ATHENS_BG_PATH8        ; pointer to path 8
    FDB _ATHENS_BG_PATH9        ; pointer to path 9
    FDB _ATHENS_BG_PATH10        ; pointer to path 10
    FDB _ATHENS_BG_PATH11        ; pointer to path 11
    FDB _ATHENS_BG_PATH12        ; pointer to path 12
    FDB _ATHENS_BG_PATH13        ; pointer to path 13
    FDB _ATHENS_BG_PATH14        ; pointer to path 14
    FDB _ATHENS_BG_PATH15        ; pointer to path 15
    FDB _ATHENS_BG_PATH16        ; pointer to path 16
    FDB _ATHENS_BG_PATH17        ; pointer to path 17
    FDB _ATHENS_BG_PATH18        ; pointer to path 18
    FDB _ATHENS_BG_PATH19        ; pointer to path 19
    FDB _ATHENS_BG_PATH20        ; pointer to path 20
    FDB _ATHENS_BG_PATH21        ; pointer to path 21
    FDB _ATHENS_BG_PATH22        ; pointer to path 22
    FDB _ATHENS_BG_PATH23        ; pointer to path 23
    FDB _ATHENS_BG_PATH24        ; pointer to path 24
    FDB _ATHENS_BG_PATH25        ; pointer to path 25
    FDB _ATHENS_BG_PATH26        ; pointer to path 26
    FDB _ATHENS_BG_PATH27        ; pointer to path 27
    FDB _ATHENS_BG_PATH28        ; pointer to path 28
    FDB _ATHENS_BG_PATH29        ; pointer to path 29
    FDB _ATHENS_BG_PATH30        ; pointer to path 30
    FDB _ATHENS_BG_PATH31        ; pointer to path 31
    FDB _ATHENS_BG_PATH32        ; pointer to path 32
    FDB _ATHENS_BG_PATH33        ; pointer to path 33
    FDB _ATHENS_BG_PATH34        ; pointer to path 34
    FDB _ATHENS_BG_PATH35        ; pointer to path 35
    FDB _ATHENS_BG_PATH36        ; pointer to path 36
    FDB _ATHENS_BG_PATH37        ; pointer to path 37
    FDB _ATHENS_BG_PATH38        ; pointer to path 38
    FDB _ATHENS_BG_PATH39        ; pointer to path 39
    FDB _ATHENS_BG_PATH40        ; pointer to path 40

_ATHENS_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $26,$C1,0,0        ; path0: header (y=38, x=-63, relative to center)
    FCB $FF,$25,$3E          ; line 0: flag=-1, dy=37, dx=62
    FCB $FF,$DB,$3F          ; line 1: flag=-1, dy=-37, dx=63
    FCB $FF,$00,$83          ; line 2: flag=-1, dy=0, dx=-125
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $29,$D2,0,0        ; path1: header (y=41, x=-46, relative to center)
    FCB $FF,$1C,$2D          ; line 0: flag=-1, dy=28, dx=45
    FCB $FF,$E4,$2F          ; line 1: flag=-1, dy=-28, dx=47
    FCB $FF,$00,$A4          ; line 2: flag=-1, dy=0, dx=-92
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $26,$38,0,0        ; path2: header (y=38, x=56, relative to center)
    FCB $FF,$00,$00          ; line 0: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $26,$3B,0,0        ; path3: header (y=38, x=59, relative to center)
    FCB $FF,$F9,$00          ; line 0: flag=-1, dy=-7, dx=0
    FCB $FF,$00,$88          ; line 1: flag=-1, dy=0, dx=-120
    FCB $FF,$07,$00          ; line 2: flag=-1, dy=7, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $1F,$C6,0,0        ; path4: header (y=31, x=-58, relative to center)
    FCB $FF,$F5,$00          ; line 0: flag=-1, dy=-11, dx=0
    FCB $FF,$00,$72          ; line 1: flag=-1, dy=0, dx=114
    FCB $FF,$0B,$00          ; line 2: flag=-1, dy=11, dx=0
    FCB $FF,$00,$01          ; line 3: flag=-1, dy=0, dx=1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $14,$C6,0,0        ; path5: header (y=20, x=-58, relative to center)
    FCB $FF,$00,$FC          ; line 0: flag=-1, dy=0, dx=-4
    FCB $FF,$FB,$00          ; line 1: flag=-1, dy=-5, dx=0
    FCB $FF,$00,$7A          ; line 2: flag=-1, dy=0, dx=122
    FCB $FF,$05,$00          ; line 3: flag=-1, dy=5, dx=0
    FCB $FF,$00,$FC          ; line 4: flag=-1, dy=0, dx=-4
    FCB $FF,$00,$00          ; line 5: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $0F,$C8,0,0        ; path6: header (y=15, x=-56, relative to center)
    FCB $FF,$FD,$01          ; line 0: flag=-1, dy=-3, dx=1
    FCB $FF,$00,$0E          ; line 1: flag=-1, dy=0, dx=14
    FCB $FF,$03,$01          ; line 2: flag=-1, dy=3, dx=1
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $0C,$CA,0,0        ; path7: header (y=12, x=-54, relative to center)
    FCB $FF,$FE,$01          ; line 0: flag=-1, dy=-2, dx=1
    FCB $FF,$00,$0A          ; line 1: flag=-1, dy=0, dx=10
    FCB $FF,$02,$01          ; line 2: flag=-1, dy=2, dx=1
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $0A,$CB,0,0        ; path8: header (y=10, x=-53, relative to center)
    FCB $FF,$C5,$00          ; line 0: flag=-1, dy=-59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $0A,$D5,0,0        ; path9: header (y=10, x=-43, relative to center)
    FCB $FF,$C5,$00          ; line 0: flag=-1, dy=-59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $CA,$C8,0,0        ; path10: header (y=-54, x=-56, relative to center)
    FCB $FF,$03,$01          ; line 0: flag=-1, dy=3, dx=1
    FCB $FF,$00,$0E          ; line 1: flag=-1, dy=0, dx=14
    FCB $FF,$FD,$01          ; line 2: flag=-1, dy=-3, dx=1
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $CD,$CA,0,0        ; path11: header (y=-51, x=-54, relative to center)
    FCB $FF,$02,$01          ; line 0: flag=-1, dy=2, dx=1
    FCB $FF,$00,$0A          ; line 1: flag=-1, dy=0, dx=10
    FCB $FF,$FE,$01          ; line 2: flag=-1, dy=-2, dx=1
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $CF,$CB,0,0        ; path12: header (y=-49, x=-53, relative to center)
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $CF,$D5,0,0        ; path13: header (y=-49, x=-43, relative to center)
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $0F,$E0,0,0        ; path14: header (y=15, x=-32, relative to center)
    FCB $FF,$FD,$01          ; line 0: flag=-1, dy=-3, dx=1
    FCB $FF,$00,$0E          ; line 1: flag=-1, dy=0, dx=14
    FCB $FF,$03,$01          ; line 2: flag=-1, dy=3, dx=1
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $0C,$E2,0,0        ; path15: header (y=12, x=-30, relative to center)
    FCB $FF,$FE,$01          ; line 0: flag=-1, dy=-2, dx=1
    FCB $FF,$00,$0A          ; line 1: flag=-1, dy=0, dx=10
    FCB $FF,$02,$01          ; line 2: flag=-1, dy=2, dx=1
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $0A,$E3,0,0        ; path16: header (y=10, x=-29, relative to center)
    FCB $FF,$C5,$00          ; line 0: flag=-1, dy=-59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $0A,$ED,0,0        ; path17: header (y=10, x=-19, relative to center)
    FCB $FF,$C5,$00          ; line 0: flag=-1, dy=-59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH18:    ; Path 18
    FCB 127              ; path18: intensity
    FCB $CA,$E0,0,0        ; path18: header (y=-54, x=-32, relative to center)
    FCB $FF,$03,$01          ; line 0: flag=-1, dy=3, dx=1
    FCB $FF,$00,$0E          ; line 1: flag=-1, dy=0, dx=14
    FCB $FF,$FD,$01          ; line 2: flag=-1, dy=-3, dx=1
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH19:    ; Path 19
    FCB 127              ; path19: intensity
    FCB $CD,$E2,0,0        ; path19: header (y=-51, x=-30, relative to center)
    FCB $FF,$02,$01          ; line 0: flag=-1, dy=2, dx=1
    FCB $FF,$00,$0A          ; line 1: flag=-1, dy=0, dx=10
    FCB $FF,$FE,$01          ; line 2: flag=-1, dy=-2, dx=1
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH20:    ; Path 20
    FCB 127              ; path20: intensity
    FCB $CF,$E3,0,0        ; path20: header (y=-49, x=-29, relative to center)
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH21:    ; Path 21
    FCB 127              ; path21: intensity
    FCB $CF,$ED,0,0        ; path21: header (y=-49, x=-19, relative to center)
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH22:    ; Path 22
    FCB 127              ; path22: intensity
    FCB $0F,$12,0,0        ; path22: header (y=15, x=18, relative to center)
    FCB $FF,$FD,$01          ; line 0: flag=-1, dy=-3, dx=1
    FCB $FF,$00,$0E          ; line 1: flag=-1, dy=0, dx=14
    FCB $FF,$03,$01          ; line 2: flag=-1, dy=3, dx=1
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH23:    ; Path 23
    FCB 127              ; path23: intensity
    FCB $0C,$14,0,0        ; path23: header (y=12, x=20, relative to center)
    FCB $FF,$FE,$01          ; line 0: flag=-1, dy=-2, dx=1
    FCB $FF,$00,$0A          ; line 1: flag=-1, dy=0, dx=10
    FCB $FF,$02,$01          ; line 2: flag=-1, dy=2, dx=1
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH24:    ; Path 24
    FCB 127              ; path24: intensity
    FCB $0A,$15,0,0        ; path24: header (y=10, x=21, relative to center)
    FCB $FF,$C5,$00          ; line 0: flag=-1, dy=-59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH25:    ; Path 25
    FCB 127              ; path25: intensity
    FCB $0A,$1F,0,0        ; path25: header (y=10, x=31, relative to center)
    FCB $FF,$C5,$00          ; line 0: flag=-1, dy=-59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH26:    ; Path 26
    FCB 127              ; path26: intensity
    FCB $CA,$12,0,0        ; path26: header (y=-54, x=18, relative to center)
    FCB $FF,$03,$01          ; line 0: flag=-1, dy=3, dx=1
    FCB $FF,$00,$0E          ; line 1: flag=-1, dy=0, dx=14
    FCB $FF,$FD,$01          ; line 2: flag=-1, dy=-3, dx=1
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH27:    ; Path 27
    FCB 127              ; path27: intensity
    FCB $CD,$14,0,0        ; path27: header (y=-51, x=20, relative to center)
    FCB $FF,$02,$01          ; line 0: flag=-1, dy=2, dx=1
    FCB $FF,$00,$0A          ; line 1: flag=-1, dy=0, dx=10
    FCB $FF,$FE,$01          ; line 2: flag=-1, dy=-2, dx=1
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH28:    ; Path 28
    FCB 127              ; path28: intensity
    FCB $CF,$15,0,0        ; path28: header (y=-49, x=21, relative to center)
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH29:    ; Path 29
    FCB 127              ; path29: intensity
    FCB $CF,$1F,0,0        ; path29: header (y=-49, x=31, relative to center)
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH30:    ; Path 30
    FCB 127              ; path30: intensity
    FCB $0F,$26,0,0        ; path30: header (y=15, x=38, relative to center)
    FCB $FF,$FD,$01          ; line 0: flag=-1, dy=-3, dx=1
    FCB $FF,$00,$0E          ; line 1: flag=-1, dy=0, dx=14
    FCB $FF,$03,$01          ; line 2: flag=-1, dy=3, dx=1
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH31:    ; Path 31
    FCB 127              ; path31: intensity
    FCB $0C,$28,0,0        ; path31: header (y=12, x=40, relative to center)
    FCB $FF,$FE,$01          ; line 0: flag=-1, dy=-2, dx=1
    FCB $FF,$00,$0A          ; line 1: flag=-1, dy=0, dx=10
    FCB $FF,$02,$01          ; line 2: flag=-1, dy=2, dx=1
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH32:    ; Path 32
    FCB 127              ; path32: intensity
    FCB $0A,$29,0,0        ; path32: header (y=10, x=41, relative to center)
    FCB $FF,$C5,$00          ; line 0: flag=-1, dy=-59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH33:    ; Path 33
    FCB 127              ; path33: intensity
    FCB $0A,$33,0,0        ; path33: header (y=10, x=51, relative to center)
    FCB $FF,$C5,$00          ; line 0: flag=-1, dy=-59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH34:    ; Path 34
    FCB 127              ; path34: intensity
    FCB $CA,$26,0,0        ; path34: header (y=-54, x=38, relative to center)
    FCB $FF,$03,$01          ; line 0: flag=-1, dy=3, dx=1
    FCB $FF,$00,$0E          ; line 1: flag=-1, dy=0, dx=14
    FCB $FF,$FD,$01          ; line 2: flag=-1, dy=-3, dx=1
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH35:    ; Path 35
    FCB 127              ; path35: intensity
    FCB $CD,$28,0,0        ; path35: header (y=-51, x=40, relative to center)
    FCB $FF,$02,$01          ; line 0: flag=-1, dy=2, dx=1
    FCB $FF,$00,$0A          ; line 1: flag=-1, dy=0, dx=10
    FCB $FF,$FE,$01          ; line 2: flag=-1, dy=-2, dx=1
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH36:    ; Path 36
    FCB 127              ; path36: intensity
    FCB $CF,$29,0,0        ; path36: header (y=-49, x=41, relative to center)
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH37:    ; Path 37
    FCB 127              ; path37: intensity
    FCB $CF,$33,0,0        ; path37: header (y=-49, x=51, relative to center)
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH38:    ; Path 38
    FCB 127              ; path38: intensity
    FCB $B5,$B0,0,0        ; path38: header (y=-75, x=-80, relative to center)
    FCB $FF,$07,$00          ; line 0: flag=-1, dy=7, dx=0
    FCB $FF,$00,$7F          ; line 1: flag=-1, dy=0, dx=127
    FCB $FF,$F9,$00          ; line 2: flag=-1, dy=-7, dx=0
    FCB $FF,$00,$81          ; line 3: flag=-1, dy=0, dx=-127
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH39:    ; Path 39
    FCB 127              ; path39: intensity
    FCB $BC,$B7,0,0        ; path39: header (y=-68, x=-73, relative to center)
    FCB $FF,$08,$00          ; line 0: flag=-1, dy=8, dx=0
    FCB $FF,$00,$7F          ; line 1: flag=-1, dy=0, dx=127
    FCB $FF,$F8,$00          ; line 2: flag=-1, dy=-8, dx=0
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH40:    ; Path 40
    FCB 127              ; path40: intensity
    FCB $C4,$44,0,0        ; path40: header (y=-60, x=68, relative to center)
    FCB $FF,$06,$00          ; line 0: flag=-1, dy=6, dx=0
    FCB $FF,$00,$81          ; line 1: flag=-1, dy=0, dx=-127
    FCB $FF,$FA,$00          ; line 2: flag=-1, dy=-6, dx=0
    FCB $FF,$00,$00          ; line 3: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

; Vector asset: antarctica_bg
; Generated from antarctica_bg.vec (Malban Draw_Sync_List format)
; Total paths: 20, points: 91
; X bounds: min=-119, max=104, width=223
; Center: (-7, 46)

_ANTARCTICA_BG_WIDTH EQU 223
_ANTARCTICA_BG_CENTER_X EQU -7
_ANTARCTICA_BG_CENTER_Y EQU 46

_ANTARCTICA_BG_VECTORS:  ; Main entry (header + 20 path(s))
    FCB 20               ; path_count (runtime metadata)
    FDB _ANTARCTICA_BG_PATH0        ; pointer to path 0
    FDB _ANTARCTICA_BG_PATH1        ; pointer to path 1
    FDB _ANTARCTICA_BG_PATH2        ; pointer to path 2
    FDB _ANTARCTICA_BG_PATH3        ; pointer to path 3
    FDB _ANTARCTICA_BG_PATH4        ; pointer to path 4
    FDB _ANTARCTICA_BG_PATH5        ; pointer to path 5
    FDB _ANTARCTICA_BG_PATH6        ; pointer to path 6
    FDB _ANTARCTICA_BG_PATH7        ; pointer to path 7
    FDB _ANTARCTICA_BG_PATH8        ; pointer to path 8
    FDB _ANTARCTICA_BG_PATH9        ; pointer to path 9
    FDB _ANTARCTICA_BG_PATH10        ; pointer to path 10
    FDB _ANTARCTICA_BG_PATH11        ; pointer to path 11
    FDB _ANTARCTICA_BG_PATH12        ; pointer to path 12
    FDB _ANTARCTICA_BG_PATH13        ; pointer to path 13
    FDB _ANTARCTICA_BG_PATH14        ; pointer to path 14
    FDB _ANTARCTICA_BG_PATH15        ; pointer to path 15
    FDB _ANTARCTICA_BG_PATH16        ; pointer to path 16
    FDB _ANTARCTICA_BG_PATH17        ; pointer to path 17
    FDB _ANTARCTICA_BG_PATH18        ; pointer to path 18
    FDB _ANTARCTICA_BG_PATH19        ; pointer to path 19

_ANTARCTICA_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $D3,$90,0,0        ; path0: header (y=-45, x=-112, relative to center)
    FCB $FF,$00,$7F          ; line 0: flag=-1, dy=0, dx=127
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $D3,$29,0,0        ; path1: header (y=-45, x=41, relative to center)
    FCB $FF,$41,$D5          ; line 0: flag=-1, dy=65, dx=-43
    FCB $FF,$FA,$F9          ; line 1: flag=-1, dy=-6, dx=-7
    FCB $FF,$21,$E4          ; line 2: flag=-1, dy=33, dx=-28
    FCB $FF,$DF,$E7          ; line 3: flag=-1, dy=-33, dx=-25
    FCB $FF,$07,$F7          ; line 4: flag=-1, dy=7, dx=-9
    FCB $FF,$BE,$D7          ; line 5: flag=-1, dy=-66, dx=-41
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $E6,$9C,0,0        ; path2: header (y=-26, x=-100, relative to center)
    FCB $FF,$03,$21          ; line 0: flag=-1, dy=3, dx=33
    FCB $FF,$17,$22          ; line 1: flag=-1, dy=23, dx=34
    FCB $FF,$F6,$16          ; line 2: flag=-1, dy=-10, dx=22
    FCB $FF,$F9,$08          ; line 3: flag=-1, dy=-7, dx=8
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $D3,$D6,0,0        ; path3: header (y=-45, x=-42, relative to center)
    FCB $FF,$0F,$05          ; line 0: flag=-1, dy=15, dx=5
    FCB $FF,$10,$2A          ; line 1: flag=-1, dy=16, dx=42
    FCB $FF,$F7,$15          ; line 2: flag=-1, dy=-9, dx=21
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $F7,$F3,0,0        ; path4: header (y=-9, x=-13, relative to center)
    FCB $FF,$13,$FB          ; line 0: flag=-1, dy=19, dx=-5
    FCB $FF,$00,$F7          ; line 1: flag=-1, dy=0, dx=-9
    FCB $FF,$0F,$F8          ; line 2: flag=-1, dy=15, dx=-8
    FCB $FF,$02,$EF          ; line 3: flag=-1, dy=2, dx=-17
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $D9,$33,0,0        ; path5: header (y=-39, x=51, relative to center)
    FCB $FF,$09,$06          ; line 0: flag=-1, dy=9, dx=6
    FCB $FF,$02,$05          ; line 1: flag=-1, dy=2, dx=5
    FCB $FF,$FA,$06          ; line 2: flag=-1, dy=-6, dx=6
    FCB $FF,$F4,$01          ; line 3: flag=-1, dy=-12, dx=1
    FCB $FF,$02,$FD          ; line 4: flag=-1, dy=2, dx=-3
    FCB $FF,$06,$FF          ; line 5: flag=-1, dy=6, dx=-1
    FCB $FF,$06,$FD          ; line 6: flag=-1, dy=6, dx=-3
    FCB $FF,$FE,$FB          ; line 7: flag=-1, dy=-2, dx=-5
    FCB $FF,$FA,$FC          ; line 8: flag=-1, dy=-6, dx=-4
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $D9,$33,0,0        ; path6: header (y=-39, x=51, relative to center)
    FCB $FF,$F9,$12          ; line 0: flag=-1, dy=-7, dx=18
    FCB $FF,$04,$07          ; line 1: flag=-1, dy=4, dx=7
    FCB $FF,$00,$04          ; line 2: flag=-1, dy=0, dx=4
    FCB $FF,$00,$0D          ; line 3: flag=-1, dy=0, dx=13
    FCB $FF,$01,$0A          ; line 4: flag=-1, dy=1, dx=10
    FCB $FF,$03,$08          ; line 5: flag=-1, dy=3, dx=8
    FCB $FF,$00,$00          ; line 6: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $DA,$6F,0,0        ; path7: header (y=-38, x=111, relative to center)
    FCB $FF,$0A,$00          ; line 0: flag=-1, dy=10, dx=0
    FCB $FF,$0A,$FB          ; line 1: flag=-1, dy=10, dx=-5
    FCB $FF,$06,$FC          ; line 2: flag=-1, dy=6, dx=-4
    FCB $FF,$04,$F8          ; line 3: flag=-1, dy=4, dx=-8
    FCB $FF,$01,$F9          ; line 4: flag=-1, dy=1, dx=-7
    FCB $FF,$FF,$F5          ; line 5: flag=-1, dy=-1, dx=-11
    FCB $FF,$FB,$F9          ; line 6: flag=-1, dy=-5, dx=-7
    FCB $FF,$FB,$FB          ; line 7: flag=-1, dy=-5, dx=-5
    FCB $FF,$FA,$FC          ; line 8: flag=-1, dy=-6, dx=-4
    FCB $FF,$FA,$FD          ; line 9: flag=-1, dy=-6, dx=-3
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $D6,$4C,0,0        ; path8: header (y=-42, x=76, relative to center)
    FCB $FF,$07,$00          ; line 0: flag=-1, dy=7, dx=0
    FCB $FF,$06,$FE          ; line 1: flag=-1, dy=6, dx=-2
    FCB $FF,$03,$FD          ; line 2: flag=-1, dy=3, dx=-3
    FCB $FF,$FE,$F7          ; line 3: flag=-1, dy=-2, dx=-9
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $EC,$3F,0,0        ; path9: header (y=-20, x=63, relative to center)
    FCB $FF,$FF,$08          ; line 0: flag=-1, dy=-1, dx=8
    FCB $FF,$00,$0D          ; line 1: flag=-1, dy=0, dx=13
    FCB $FF,$02,$0B          ; line 2: flag=-1, dy=2, dx=11
    FCB $FF,$02,$0A          ; line 3: flag=-1, dy=2, dx=10
    FCB $FF,$00,$00          ; line 4: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $F6,$49,0,0        ; path10: header (y=-10, x=73, relative to center)
    FCB $FF,$FF,$09          ; line 0: flag=-1, dy=-1, dx=9
    FCB $FF,$01,$08          ; line 1: flag=-1, dy=1, dx=8
    FCB $FF,$01,$06          ; line 2: flag=-1, dy=1, dx=6
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $E0,$4B,0,0        ; path11: header (y=-32, x=75, relative to center)
    FCB $FF,$01,$0B          ; line 0: flag=-1, dy=1, dx=11
    FCB $FF,$02,$15          ; line 1: flag=-1, dy=2, dx=21
    FCB $FF,$01,$04          ; line 2: flag=-1, dy=1, dx=4
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $F5,$52,0,0        ; path12: header (y=-11, x=82, relative to center)
    FCB $FF,$F6,$FF          ; line 0: flag=-1, dy=-10, dx=-1
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $F6,$5B,0,0        ; path13: header (y=-10, x=91, relative to center)
    FCB $FF,$F8,$07          ; line 0: flag=-1, dy=-8, dx=7
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $EC,$59,0,0        ; path14: header (y=-20, x=89, relative to center)
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $E2,$60,0,0        ; path15: header (y=-30, x=96, relative to center)
    FCB $FF,$F5,$05          ; line 0: flag=-1, dy=-11, dx=5
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $E1,$53,0,0        ; path16: header (y=-31, x=83, relative to center)
    FCB $FF,$F5,$FE          ; line 0: flag=-1, dy=-11, dx=-2
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $EB,$49,0,0        ; path17: header (y=-21, x=73, relative to center)
    FCB $FF,$FB,$FE          ; line 0: flag=-1, dy=-5, dx=-2
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH18:    ; Path 18
    FCB 127              ; path18: intensity
    FCB $EE,$65,0,0        ; path18: header (y=-18, x=101, relative to center)
    FCB $FF,$F5,$06          ; line 0: flag=-1, dy=-11, dx=6
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH19:    ; Path 19
    FCB 127              ; path19: intensity
    FCB $E1,$58,0,0        ; path19: header (y=-31, x=88, relative to center)
    FCB $FF,$0B,$01          ; line 0: flag=-1, dy=11, dx=1
    FCB $FF,$00,$00          ; line 1: flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; line 2: flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

; Vector asset: bubble_medium
; Generated from bubble_medium.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 24
; X bounds: min=-15, max=15, width=30
; Center: (0, 0)

_BUBBLE_MEDIUM_WIDTH EQU 30
_BUBBLE_MEDIUM_CENTER_X EQU 0
_BUBBLE_MEDIUM_CENTER_Y EQU 0

_BUBBLE_MEDIUM_VECTORS:  ; Main entry (header + 1 path(s))
    FCB 1               ; path_count (runtime metadata)
    FDB _BUBBLE_MEDIUM_PATH0        ; pointer to path 0

_BUBBLE_MEDIUM_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $00,$0F,0,0        ; path0: header (y=0, x=15, relative to center)
    FCB $FF,$04,$FF          ; line 0: flag=-1, dy=4, dx=-1
    FCB $FF,$04,$FF          ; line 1: flag=-1, dy=4, dx=-1
    FCB $FF,$03,$FE          ; line 2: flag=-1, dy=3, dx=-2
    FCB $FF,$02,$FD          ; line 3: flag=-1, dy=2, dx=-3
    FCB $FF,$01,$FC          ; line 4: flag=-1, dy=1, dx=-4
    FCB $FF,$01,$FC          ; line 5: flag=-1, dy=1, dx=-4
    FCB $FF,$FF,$FC          ; line 6: flag=-1, dy=-1, dx=-4
    FCB $FF,$FF,$FC          ; line 7: flag=-1, dy=-1, dx=-4
    FCB $FF,$FE,$FD          ; line 8: flag=-1, dy=-2, dx=-3
    FCB $FF,$FD,$FE          ; line 9: flag=-1, dy=-3, dx=-2
    FCB $FF,$FC,$FF          ; line 10: flag=-1, dy=-4, dx=-1
    FCB $FF,$FC,$FF          ; line 11: flag=-1, dy=-4, dx=-1
    FCB $FF,$FC,$01          ; line 12: flag=-1, dy=-4, dx=1
    FCB $FF,$FC,$01          ; line 13: flag=-1, dy=-4, dx=1
    FCB $FF,$FD,$02          ; line 14: flag=-1, dy=-3, dx=2
    FCB $FF,$FE,$03          ; line 15: flag=-1, dy=-2, dx=3
    FCB $FF,$FF,$04          ; line 16: flag=-1, dy=-1, dx=4
    FCB $FF,$FF,$04          ; line 17: flag=-1, dy=-1, dx=4
    FCB $FF,$01,$04          ; line 18: flag=-1, dy=1, dx=4
    FCB $FF,$01,$04          ; line 19: flag=-1, dy=1, dx=4
    FCB $FF,$02,$03          ; line 20: flag=-1, dy=2, dx=3
    FCB $FF,$03,$02          ; line 21: flag=-1, dy=3, dx=2
    FCB $FF,$04,$01          ; line 22: flag=-1, dy=4, dx=1
    FCB $FF,$04,$01          ; closing line: flag=-1, dy=4, dx=1
    FCB 2                ; End marker (path complete)

; Generated from pang_theme.vmus (internal name: pang_theme)
; Tempo: 120 BPM, Total events: 34 (PSG Direct format)
; Format: FCB count, FCB reg, val, ... (per frame), FCB 0 (end)

_PANG_THEME_MUSIC:
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
    FCB     $F0             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
    FCB     25              ; Delay 25 frames (maintain previous state)
    FCB     11              ; Frame 50 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $77             ; Reg 0 value
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
    FCB     $F0             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 62 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $77             ; Reg 0 value
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
    FCB     $F8             ; Reg 7 value
    FCB     13              ; Delay 13 frames (maintain previous state)
    FCB     10              ; Frame 75 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $59             ; Reg 0 value
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
    FCB     $F8             ; Reg 7 value
    FCB     25              ; Delay 25 frames (maintain previous state)
    FCB     11              ; Frame 100 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $77             ; Reg 0 value
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
    FCB     $F0             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 112 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $77             ; Reg 0 value
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
    FCB     $F8             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
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
    FCB     $F0             ; Reg 7 value
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
    FCB     $F8             ; Reg 7 value
    FCB     38              ; Delay 38 frames (maintain previous state)
    FCB     11              ; Frame 200 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
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
    FCB     $FC             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $F0             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 212 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
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
    FCB     $FC             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $F8             ; Reg 7 value
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
    FCB     $FC             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $F8             ; Reg 7 value
    FCB     25              ; Delay 25 frames (maintain previous state)
    FCB     11              ; Frame 249 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
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
    FCB     $FC             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $F0             ; Reg 7 value
    FCB     13              ; Delay 13 frames (maintain previous state)
    FCB     10              ; Frame 262 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
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
    FCB     $FC             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $F8             ; Reg 7 value
    FCB     13              ; Delay 13 frames (maintain previous state)
    FCB     10              ; Frame 275 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $4F             ; Reg 0 value
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
    FCB     $FC             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $F8             ; Reg 7 value
    FCB     25              ; Delay 25 frames (maintain previous state)
    FCB     11              ; Frame 300 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $9F             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $FC             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $F0             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 312 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $6A             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $9F             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $FC             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $F8             ; Reg 7 value
    FCB     13              ; Delay 13 frames (maintain previous state)
    FCB     10              ; Frame 325 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $86             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $9F             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $FC             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $F8             ; Reg 7 value
    FCB     25              ; Delay 25 frames (maintain previous state)
    FCB     11              ; Frame 350 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
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
    FCB     $FC             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $F0             ; Reg 7 value
    FCB     12              ; Delay 12 frames (maintain previous state)
    FCB     10              ; Frame 362 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
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
    FCB     $FC             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $F8             ; Reg 7 value
    FCB     38              ; Delay 38 frames before loop
    FCB     $FF             ; Loop command ($FF never valid as count)
    FDB     _PANG_THEME_MUSIC       ; Jump to start (absolute address)


; Generated from map_theme.vmus (internal name: Space Groove)
; Tempo: 140 BPM, Total events: 36 (PSG Direct format)
; Format: FCB count, FCB reg, val, ... (per frame), FCB 0 (end)

_MAP_THEME_MUSIC:
    ; Frame-based PSG register writes
    FCB     0              ; Delay 0 frames (maintain previous state)
    FCB     11              ; Frame 0 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $B3             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $CC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $66             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $14             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $F0             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 5 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B3             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $CC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $66             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $F8             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     11              ; Frame 10 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $CC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $66             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $F0             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 13 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $CC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $66             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $F8             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     9              ; Frame 21 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $8E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $66             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $F2             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     8              ; Frame 24 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $8E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $66             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FA             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     9              ; Frame 32 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $66             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $F2             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 34 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $9F             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $66             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FA             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     11              ; Frame 42 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $B3             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $CC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $1C             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $14             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $F0             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     10              ; Frame 48 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B3             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $CC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $1C             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $F8             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     11              ; Frame 53 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $B3             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $CC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $1C             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $F0             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 56 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B3             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $CC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $1C             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $F8             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     9              ; Frame 64 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $D5             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $1C             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $F2             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 66 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $D5             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $1C             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FA             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     9              ; Frame 75 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $EF             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0B             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $1C             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $F2             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 77 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $EF             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0B             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $1C             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FA             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     11              ; Frame 85 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $B3             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $DE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $EF             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $14             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $F0             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     10              ; Frame 91 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $B3             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $DE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $EF             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $F8             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     11              ; Frame 96 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $8E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $DE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $EF             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $F0             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 99 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $8E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $DE             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $EF             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $F8             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     9              ; Frame 107 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $77             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0F             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $EF             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $F2             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 109 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $77             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0F             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $EF             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FA             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     9              ; Frame 117 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $77             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0F             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $EF             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $F2             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     8              ; Frame 120 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $77             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0F             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $EF             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FA             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     11              ; Frame 128 - 11 register writes
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
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $1C             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $14             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $F0             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 133 - 10 register writes
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
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $1C             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $F8             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     11              ; Frame 139 - 11 register writes
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
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $1C             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $F0             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 141 - 10 register writes
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
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $1C             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $F8             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     9              ; Frame 150 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $B3             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $1C             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $F2             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 152 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $B3             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $1C             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FA             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     9              ; Frame 160 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $B3             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $1C             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $F2             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     8              ; Frame 163 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $B3             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $1C             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FA             ; Reg 7 value
    FCB     8              ; Delay 8 frames before loop
    FCB     $FF             ; Loop command ($FF never valid as count)
    FDB     _MAP_THEME_MUSIC       ; Jump to start (absolute address)


; Level Asset: fuji_level1_v2 (from /Users/daniel/projects/vectrex-pseudo-python/examples/pang/assets/playground/fuji_level1_v2.vplay)
; ==== Level: FUJI_LEVEL1_V2 ====
; Author: 
; Difficulty: medium

_FUJI_LEVEL1_V2_LEVEL:
    FDB -96  ; World bounds: xMin (16-bit signed)
    FDB 95  ; xMax (16-bit signed)
    FDB -128  ; yMin (16-bit signed)
    FDB 127  ; yMax (16-bit signed)
    FDB 0  ; Time limit (seconds)
    FDB 0  ; Target score
    FCB 1  ; Background object count
    FCB 2  ; Gameplay object count
    FCB 0  ; Foreground object count
    FDB _FUJI_LEVEL1_V2_BG_OBJECTS
    FDB _FUJI_LEVEL1_V2_GAMEPLAY_OBJECTS
    FDB _FUJI_LEVEL1_V2_FG_OBJECTS

_FUJI_LEVEL1_V2_BG_OBJECTS:
; Object: obj_1767470884207 (enemy)
    FCB 1  ; type
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
    FDB _FUJI_BG_VECTORS  ; vector_ptr
    FDB 0  ; properties_ptr (reserved)


_FUJI_LEVEL1_V2_GAMEPLAY_OBJECTS:
; Object: enemy_1 (enemy)
    FCB 1  ; type
    FDB -40  ; x
    FDB 60  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 127  ; intensity (0=use vec, >0=override)
    FCB 255  ; velocity_x
    FCB 255  ; velocity_y
    FCB 3  ; physics_flags
    FCB 7  ; collision_flags
    FCB 20  ; collision_size
    FDB 0  ; spawn_delay
    FDB _BUBBLE_LARGE_VECTORS  ; vector_ptr
    FDB 0  ; properties_ptr (reserved)

; Object: enemy_2 (enemy)
    FCB 1  ; type
    FDB 40  ; x
    FDB 60  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 127  ; intensity (0=use vec, >0=override)
    FCB 1  ; velocity_x
    FCB 255  ; velocity_y
    FCB 3  ; physics_flags
    FCB 7  ; collision_flags
    FCB 20  ; collision_size
    FDB 60  ; spawn_delay
    FDB _BUBBLE_LARGE_VECTORS  ; vector_ptr
    FDB 0  ; properties_ptr (reserved)


_FUJI_LEVEL1_V2_FG_OBJECTS:


; Array literal for variable 'joystick1_state' (6 elements)
ARRAY_0:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5

; Array literal for variable 'enemy_active' (8 elements)
ARRAY_1:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'enemy_x' (8 elements)
ARRAY_2:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'enemy_y' (8 elements)
ARRAY_3:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'enemy_vx' (8 elements)
ARRAY_4:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'enemy_vy' (8 elements)
ARRAY_5:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'enemy_size' (8 elements)
ARRAY_6:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; VPy_LINE:18
; Const array literal for 'location_x_coords' (17 elements)
CONST_ARRAY_0:
    FDB 40   ; Element 0
    FDB 40   ; Element 1
    FDB -40   ; Element 2
    FDB -10   ; Element 3
    FDB 20   ; Element 4
    FDB 50   ; Element 5
    FDB 80   ; Element 6
    FDB -85   ; Element 7
    FDB -50   ; Element 8
    FDB -15   ; Element 9
    FDB 15   ; Element 10
    FDB 50   ; Element 11
    FDB 85   ; Element 12
    FDB -90   ; Element 13
    FDB -45   ; Element 14
    FDB 0   ; Element 15
    FDB 45   ; Element 16

; VPy_LINE:19
; Const array literal for 'location_y_coords' (17 elements)
CONST_ARRAY_1:
    FDB 110   ; Element 0
    FDB 79   ; Element 1
    FDB -20   ; Element 2
    FDB 10   ; Element 3
    FDB 40   ; Element 4
    FDB 70   ; Element 5
    FDB 100   ; Element 6
    FDB -40   ; Element 7
    FDB -10   ; Element 8
    FDB 30   ; Element 9
    FDB 60   ; Element 10
    FDB 90   ; Element 11
    FDB 20   ; Element 12
    FDB 50   ; Element 13
    FDB 0   ; Element 14
    FDB -60   ; Element 15
    FDB -30   ; Element 16

; VPy_LINE:20
; Const string array for 'location_names' (17 strings)
CONST_ARRAY_2_STR_0:
    FCC "MOUNT FUJI (JP)"
    FCB $80   ; String terminator
CONST_ARRAY_2_STR_1:
    FCC "MOUNT KEIRIN (CN)"
    FCB $80   ; String terminator
CONST_ARRAY_2_STR_2:
    FCC "EMERALD BUDDHA TEMPLE (TH)"
    FCB $80   ; String terminator
CONST_ARRAY_2_STR_3:
    FCC "ANGKOR WAT (KH)"
    FCB $80   ; String terminator
CONST_ARRAY_2_STR_4:
    FCC "AYERS ROCK (AU)"
    FCB $80   ; String terminator
CONST_ARRAY_2_STR_5:
    FCC "TAJ MAHAL (IN)"
    FCB $80   ; String terminator
CONST_ARRAY_2_STR_6:
    FCC "LENINGRAD (RU)"
    FCB $80   ; String terminator
CONST_ARRAY_2_STR_7:
    FCC "PARIS (FR)"
    FCB $80   ; String terminator
CONST_ARRAY_2_STR_8:
    FCC "LONDON (UK)"
    FCB $80   ; String terminator
CONST_ARRAY_2_STR_9:
    FCC "BARCELONA (ES)"
    FCB $80   ; String terminator
CONST_ARRAY_2_STR_10:
    FCC "ATHENS (GR)"
    FCB $80   ; String terminator
CONST_ARRAY_2_STR_11:
    FCC "PYRAMIDS (EG)"
    FCB $80   ; String terminator
CONST_ARRAY_2_STR_12:
    FCC "MOUNT KILIMANJARO (TZ)"
    FCB $80   ; String terminator
CONST_ARRAY_2_STR_13:
    FCC "NEW YORK (US)"
    FCB $80   ; String terminator
CONST_ARRAY_2_STR_14:
    FCC "MAYAN RUINS (MX)"
    FCB $80   ; String terminator
CONST_ARRAY_2_STR_15:
    FCC "ANTARCTICA (AQ)"
    FCB $80   ; String terminator
CONST_ARRAY_2_STR_16:
    FCC "EASTER ISLAND (CL)"
    FCB $80   ; String terminator
CONST_ARRAY_2:  ; Pointer table for location_names
    FDB CONST_ARRAY_2_STR_0  ; Pointer to string
    FDB CONST_ARRAY_2_STR_1  ; Pointer to string
    FDB CONST_ARRAY_2_STR_2  ; Pointer to string
    FDB CONST_ARRAY_2_STR_3  ; Pointer to string
    FDB CONST_ARRAY_2_STR_4  ; Pointer to string
    FDB CONST_ARRAY_2_STR_5  ; Pointer to string
    FDB CONST_ARRAY_2_STR_6  ; Pointer to string
    FDB CONST_ARRAY_2_STR_7  ; Pointer to string
    FDB CONST_ARRAY_2_STR_8  ; Pointer to string
    FDB CONST_ARRAY_2_STR_9  ; Pointer to string
    FDB CONST_ARRAY_2_STR_10  ; Pointer to string
    FDB CONST_ARRAY_2_STR_11  ; Pointer to string
    FDB CONST_ARRAY_2_STR_12  ; Pointer to string
    FDB CONST_ARRAY_2_STR_13  ; Pointer to string
    FDB CONST_ARRAY_2_STR_14  ; Pointer to string
    FDB CONST_ARRAY_2_STR_15  ; Pointer to string
    FDB CONST_ARRAY_2_STR_16  ; Pointer to string

; VPy_LINE:23
; Const string array for 'level_backgrounds' (17 strings)
CONST_ARRAY_3_STR_0:
    FCC "FUJI_BG"
    FCB $80   ; String terminator
CONST_ARRAY_3_STR_1:
    FCC "KEIRIN_BG"
    FCB $80   ; String terminator
CONST_ARRAY_3_STR_2:
    FCC "BUDDHA_BG"
    FCB $80   ; String terminator
CONST_ARRAY_3_STR_3:
    FCC "ANGKOR_BG"
    FCB $80   ; String terminator
CONST_ARRAY_3_STR_4:
    FCC "AYERS_BG"
    FCB $80   ; String terminator
CONST_ARRAY_3_STR_5:
    FCC "TAJ_BG"
    FCB $80   ; String terminator
CONST_ARRAY_3_STR_6:
    FCC "LENINGRAD_BG"
    FCB $80   ; String terminator
CONST_ARRAY_3_STR_7:
    FCC "PARIS_BG"
    FCB $80   ; String terminator
CONST_ARRAY_3_STR_8:
    FCC "LONDON_BG"
    FCB $80   ; String terminator
CONST_ARRAY_3_STR_9:
    FCC "BARCELONA_BG"
    FCB $80   ; String terminator
CONST_ARRAY_3_STR_10:
    FCC "ATHENS_BG"
    FCB $80   ; String terminator
CONST_ARRAY_3_STR_11:
    FCC "PYRAMIDS_BG"
    FCB $80   ; String terminator
CONST_ARRAY_3_STR_12:
    FCC "KILIMANJARO_BG"
    FCB $80   ; String terminator
CONST_ARRAY_3_STR_13:
    FCC "NEWYORK_BG"
    FCB $80   ; String terminator
CONST_ARRAY_3_STR_14:
    FCC "MAYAN_BG"
    FCB $80   ; String terminator
CONST_ARRAY_3_STR_15:
    FCC "ANTARCTICA_BG"
    FCB $80   ; String terminator
CONST_ARRAY_3_STR_16:
    FCC "EASTER_BG"
    FCB $80   ; String terminator
CONST_ARRAY_3:  ; Pointer table for level_backgrounds
    FDB CONST_ARRAY_3_STR_0  ; Pointer to string
    FDB CONST_ARRAY_3_STR_1  ; Pointer to string
    FDB CONST_ARRAY_3_STR_2  ; Pointer to string
    FDB CONST_ARRAY_3_STR_3  ; Pointer to string
    FDB CONST_ARRAY_3_STR_4  ; Pointer to string
    FDB CONST_ARRAY_3_STR_5  ; Pointer to string
    FDB CONST_ARRAY_3_STR_6  ; Pointer to string
    FDB CONST_ARRAY_3_STR_7  ; Pointer to string
    FDB CONST_ARRAY_3_STR_8  ; Pointer to string
    FDB CONST_ARRAY_3_STR_9  ; Pointer to string
    FDB CONST_ARRAY_3_STR_10  ; Pointer to string
    FDB CONST_ARRAY_3_STR_11  ; Pointer to string
    FDB CONST_ARRAY_3_STR_12  ; Pointer to string
    FDB CONST_ARRAY_3_STR_13  ; Pointer to string
    FDB CONST_ARRAY_3_STR_14  ; Pointer to string
    FDB CONST_ARRAY_3_STR_15  ; Pointer to string
    FDB CONST_ARRAY_3_STR_16  ; Pointer to string

; VPy_LINE:25
; Const array literal for 'level_enemy_count' (17 elements)
CONST_ARRAY_4:
    FDB 1   ; Element 0
    FDB 1   ; Element 1
    FDB 2   ; Element 2
    FDB 2   ; Element 3
    FDB 2   ; Element 4
    FDB 3   ; Element 5
    FDB 3   ; Element 6
    FDB 3   ; Element 7
    FDB 4   ; Element 8
    FDB 4   ; Element 9
    FDB 4   ; Element 10
    FDB 5   ; Element 11
    FDB 5   ; Element 12
    FDB 5   ; Element 13
    FDB 6   ; Element 14
    FDB 6   ; Element 15
    FDB 7   ; Element 16

; VPy_LINE:26
; Const array literal for 'level_enemy_speed' (17 elements)
CONST_ARRAY_5:
    FDB 1   ; Element 0
    FDB 1   ; Element 1
    FDB 1   ; Element 2
    FDB 2   ; Element 3
    FDB 2   ; Element 4
    FDB 2   ; Element 5
    FDB 2   ; Element 6
    FDB 3   ; Element 7
    FDB 3   ; Element 8
    FDB 3   ; Element 9
    FDB 3   ; Element 10
    FDB 4   ; Element 11
    FDB 4   ; Element 12
    FDB 4   ; Element 13
    FDB 4   ; Element 14
    FDB 5   ; Element 15
    FDB 5   ; Element 16

; String literals (classic FCC + $80 terminator)
STR_0:
    FCC "ANGKOR WAT (KH)"
    FCB $80
STR_1:
    FCC "ANTARCTICA (AQ)"
    FCB $80
STR_2:
    FCC "ATHENS (GR)"
    FCB $80
STR_3:
    FCC "AYERS ROCK (AU)"
    FCB $80
STR_4:
    FCC "BARCELONA (ES)"
    FCB $80
STR_5:
    FCC "EASTER ISLAND (CL)"
    FCB $80
STR_6:
    FCC "EMERALD BUDDHA TEMPLE (TH)"
    FCB $80
STR_7:
    FCC "GET READY"
    FCB $80
STR_8:
    FCC "LENINGRAD (RU)"
    FCB $80
STR_9:
    FCC "LONDON (UK)"
    FCB $80
STR_10:
    FCC "MAYAN RUINS (MX)"
    FCB $80
STR_11:
    FCC "MOUNT FUJI (JP)"
    FCB $80
STR_12:
    FCC "MOUNT KEIRIN (CN)"
    FCB $80
STR_13:
    FCC "MOUNT KILIMANJARO (TZ)"
    FCB $80
STR_14:
    FCC "NEW YORK (US)"
    FCB $80
STR_15:
    FCC "PARIS (FR)"
    FCB $80
STR_16:
    FCC "PRESS A BUTTON"
    FCB $80
STR_17:
    FCC "PYRAMIDS (EG)"
    FCB $80
STR_18:
    FCC "TAJ MAHAL (IN)"
    FCB $80
STR_19:
    FCC "TO START"
    FCB $80
