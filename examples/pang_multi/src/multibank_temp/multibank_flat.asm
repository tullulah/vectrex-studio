; AUTO-GENERATED FLATTENED MULTIBANK ASM
; Banks: 32 | Bank size: 16384 bytes | Total: 524288 bytes

ORG $0000

;***************************************************************************
; DEFINE SECTION
;***************************************************************************
    INCLUDE "VECTREX.I"

; ===== BANK #00 (physical offset $00000) =====
; VPy M6809 Assembly (Vectrex)
; ROM: 524288 bytes
; Multibank cartridge: 32 banks (16KB each)
; Helpers bank: 31 (fixed bank at $4000-$7FFF)

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
    FCC "PANG"
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
    LDS #$CBFF       ; Initialize stack
    ; Initialize CURRENT_ROM_BANK to Bank 0 (current switchable window on boot)
    LDA #0
    STA >CURRENT_ROM_BANK   ; Initialize bank tracker (Bank 0 is visible at boot)
    ; Initialize SFX variables to prevent random noise on startup
    CLR >SFX_ACTIVE         ; Mark SFX as inactive (0=off)
    LDD #$0000
    STD >SFX_PTR            ; Clear SFX pointer
    CLR >PSG_MUSIC_BANK     ; Initialize to 0 (prevents garbage bank switches)
; Bank 0 ($0000) is active; fixed bank 31 ($4000-$7FFF) always visible
    JMP MAIN

;***************************************************************************
ARRAY_LOCATION_X_COORDS_DATA:
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

; Array literal for variable 'location_y_coords' (17 elements, 2 bytes each)
ARRAY_LOCATION_Y_COORDS_DATA:
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

; String array literal for variable 'location_names' (17 elements)
ARRAY_LOCATION_NAMES_DATA_STR_0:
    FCC "MOUNT FUJI (JP)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_1:
    FCC "MOUNT KEIRIN (CN)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_2:
    FCC "EMERALD BUDDHA TEMPLE (TH)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_3:
    FCC "ANGKOR WAT (KH)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_4:
    FCC "AYERS ROCK (AU)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_5:
    FCC "TAJ MAHAL (IN)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_6:
    FCC "LENINGRAD (RU)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_7:
    FCC "PARIS (FR)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_8:
    FCC "LONDON (UK)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_9:
    FCC "BARCELONA (ES)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_10:
    FCC "ATHENS (GR)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_11:
    FCC "PYRAMIDS (EG)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_12:
    FCC "MOUNT KILIMANJARO (TZ)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_13:
    FCC "NEW YORK (US)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_14:
    FCC "MAYAN RUINS (MX)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_15:
    FCC "ANTARCTICA (AQ)"
    FCB $80   ; String terminator (high bit)
ARRAY_LOCATION_NAMES_DATA_STR_16:
    FCC "EASTER ISLAND (CL)"
    FCB $80   ; String terminator (high bit)

ARRAY_LOCATION_NAMES_DATA:  ; Pointer table for location_names
    FDB ARRAY_LOCATION_NAMES_DATA_STR_0  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_1  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_2  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_3  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_4  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_5  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_6  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_7  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_8  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_9  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_10  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_11  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_12  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_13  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_14  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_15  ; Pointer to string
    FDB ARRAY_LOCATION_NAMES_DATA_STR_16  ; Pointer to string

; String array literal for variable 'level_backgrounds' (17 elements)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_0:
    FCC "FUJI_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_1:
    FCC "KEIRIN_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_2:
    FCC "BUDDHA_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_3:
    FCC "ANGKOR_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_4:
    FCC "AYERS_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_5:
    FCC "TAJ_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_6:
    FCC "LENINGRAD_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_7:
    FCC "PARIS_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_8:
    FCC "LONDON_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_9:
    FCC "BARCELONA_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_10:
    FCC "ATHENS_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_11:
    FCC "PYRAMIDS_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_12:
    FCC "KILIMANJARO_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_13:
    FCC "NEWYORK_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_14:
    FCC "MAYAN_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_15:
    FCC "ANTARCTICA_BG"
    FCB $80   ; String terminator (high bit)
ARRAY_LEVEL_BACKGROUNDS_DATA_STR_16:
    FCC "EASTER_BG"
    FCB $80   ; String terminator (high bit)

ARRAY_LEVEL_BACKGROUNDS_DATA:  ; Pointer table for level_backgrounds
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_0  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_1  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_2  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_3  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_4  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_5  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_6  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_7  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_8  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_9  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_10  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_11  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_12  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_13  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_14  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_15  ; Pointer to string
    FDB ARRAY_LEVEL_BACKGROUNDS_DATA_STR_16  ; Pointer to string

; Array literal for variable 'level_enemy_count' (17 elements, 2 bytes each)
ARRAY_LEVEL_ENEMY_COUNT_DATA:
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

; Array literal for variable 'level_enemy_speed' (17 elements, 2 bytes each)
ARRAY_LEVEL_ENEMY_SPEED_DATA:
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

; Array literal for variable 'joystick1_state' (6 elements, 2 bytes each)
ARRAY_JOYSTICK1_STATE_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5

; Array literal for variable 'enemy_active' (8 elements, 2 bytes each)
ARRAY_ENEMY_ACTIVE_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'enemy_x' (8 elements, 2 bytes each)
ARRAY_ENEMY_X_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'enemy_y' (8 elements, 2 bytes each)
ARRAY_ENEMY_Y_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'enemy_vx' (8 elements, 2 bytes each)
ARRAY_ENEMY_VX_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'enemy_vy' (8 elements, 2 bytes each)
ARRAY_ENEMY_VY_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7

; Array literal for variable 'enemy_size' (8 elements, 2 bytes each)
ARRAY_ENEMY_SIZE_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5
    FDB 0   ; Element 6
    FDB 0   ; Element 7


;***************************************************************************
; MAIN PROGRAM
;***************************************************************************

MAIN:
    ; Initialize global variables
    LDD #30
    STD VAR_TITLE_INTENSITY
    LDD #0
    STD VAR_TITLE_STATE
    LDD #-1
    STD VAR_CURRENT_MUSIC
    ; Copy array 'joystick1_state' from ROM to RAM (6 elements)
    LDX #ARRAY_JOYSTICK1_STATE_DATA       ; Source: ROM array data
    LDU #VAR_JOYSTICK1_STATE_DATA       ; Dest: RAM array space
    LDD #6        ; Number of elements
.COPY_LOOP_0:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_0 ; Loop until done (LBNE for long branch)
    LDX #VAR_JOYSTICK1_STATE_DATA    ; Array now in RAM
    STX VAR_JOYSTICK1_STATE
    LDD #0
    STD VAR_CURRENT_LOCATION
    LDD #60
    STD VAR_LOCATION_GLOW_INTENSITY
    LDD #0
    STD VAR_LOCATION_GLOW_DIRECTION
    LDD #0
    STD VAR_JOY_X
    LDD #0
    STD VAR_JOY_Y
    LDD #0
    STD VAR_PREV_JOY_X
    LDD #0
    STD VAR_PREV_JOY_Y
    LDD #0
    STD VAR_COUNTDOWN_TIMER
    LDD #0
    STD VAR_COUNTDOWN_ACTIVE
    LDD #0
    STD VAR_JOYSTICK_POLL_COUNTER
    LDD #0
    STD VAR_HOOK_ACTIVE
    LDD #0
    STD VAR_HOOK_X
    LDD #-70
    STD VAR_HOOK_Y
    LDD #0
    STD VAR_HOOK_GUN_X
    LDD #0
    STD VAR_HOOK_GUN_Y
    LDD #0
    STD VAR_HOOK_INIT_Y
    LDD #0
    STD VAR_PLAYER_X
    LDD #0
    STD VAR_MOVE_SPEED
    LDD #0
    STD VAR_ABS_JOY
    LDD #1
    STD VAR_PLAYER_ANIM_FRAME
    LDD #0
    STD VAR_PLAYER_ANIM_COUNTER
    LDD #1
    STD VAR_PLAYER_FACING
    ; Copy array 'enemy_active' from ROM to RAM (8 elements)
    LDX #ARRAY_ENEMY_ACTIVE_DATA       ; Source: ROM array data
    LDU #VAR_ENEMY_ACTIVE_DATA       ; Dest: RAM array space
    LDD #8        ; Number of elements
.COPY_LOOP_1:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_1 ; Loop until done (LBNE for long branch)
    LDX #VAR_ENEMY_ACTIVE_DATA    ; Array now in RAM
    STX VAR_ENEMY_ACTIVE
    ; Copy array 'enemy_x' from ROM to RAM (8 elements)
    LDX #ARRAY_ENEMY_X_DATA       ; Source: ROM array data
    LDU #VAR_ENEMY_X_DATA       ; Dest: RAM array space
    LDD #8        ; Number of elements
.COPY_LOOP_2:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_2 ; Loop until done (LBNE for long branch)
    LDX #VAR_ENEMY_X_DATA    ; Array now in RAM
    STX VAR_ENEMY_X
    ; Copy array 'enemy_y' from ROM to RAM (8 elements)
    LDX #ARRAY_ENEMY_Y_DATA       ; Source: ROM array data
    LDU #VAR_ENEMY_Y_DATA       ; Dest: RAM array space
    LDD #8        ; Number of elements
.COPY_LOOP_3:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_3 ; Loop until done (LBNE for long branch)
    LDX #VAR_ENEMY_Y_DATA    ; Array now in RAM
    STX VAR_ENEMY_Y
    ; Copy array 'enemy_vx' from ROM to RAM (8 elements)
    LDX #ARRAY_ENEMY_VX_DATA       ; Source: ROM array data
    LDU #VAR_ENEMY_VX_DATA       ; Dest: RAM array space
    LDD #8        ; Number of elements
.COPY_LOOP_4:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_4 ; Loop until done (LBNE for long branch)
    LDX #VAR_ENEMY_VX_DATA    ; Array now in RAM
    STX VAR_ENEMY_VX
    ; Copy array 'enemy_vy' from ROM to RAM (8 elements)
    LDX #ARRAY_ENEMY_VY_DATA       ; Source: ROM array data
    LDU #VAR_ENEMY_VY_DATA       ; Dest: RAM array space
    LDD #8        ; Number of elements
.COPY_LOOP_5:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_5 ; Loop until done (LBNE for long branch)
    LDX #VAR_ENEMY_VY_DATA    ; Array now in RAM
    STX VAR_ENEMY_VY
    ; Copy array 'enemy_size' from ROM to RAM (8 elements)
    LDX #ARRAY_ENEMY_SIZE_DATA       ; Source: ROM array data
    LDU #VAR_ENEMY_SIZE_DATA       ; Dest: RAM array space
    LDD #8        ; Number of elements
.COPY_LOOP_6:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_6 ; Loop until done (LBNE for long branch)
    LDX #VAR_ENEMY_SIZE_DATA    ; Array now in RAM
    STX VAR_ENEMY_SIZE
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
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_LOCATION
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_PREV_JOY_X
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_PREV_JOY_Y
    LDD #80
    STD RESULT
    LDD RESULT
    STD VAR_LOCATION_GLOW_INTENSITY
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_LOCATION_GLOW_DIRECTION
    LDD VAR_STATE_TITLE
    STD RESULT
    LDD RESULT
    STD VAR_SCREEN
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_COUNTDOWN_TIMER
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_COUNTDOWN_ACTIVE
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_ACTIVE
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_X
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_Y

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR Reset0Ref    ; Reset beam to center (0,0)
    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access
    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)
    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access
    JSR read_joystick1_state
    LDD VAR_STATE_TITLE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_SCREEN
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_1
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_MUSIC
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_3
    ; PLAY_MUSIC("pang_theme") - play music asset (index=1)
    LDX #1        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    JSR draw_title_screen
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #2
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_5_TRUE
    LDD #0
    LBRA .CMP_5_END
.CMP_5_TRUE:
    LDD #1
.CMP_5_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_4_TRUE
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #3
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_6_TRUE
    LDD #0
    LBRA .CMP_6_END
.CMP_6_TRUE:
    LDD #1
.CMP_6_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_4_TRUE
    LDD #0
    LBRA .LOGIC_4_END
.LOGIC_4_TRUE:
    LDD #1
.LOGIC_4_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_3_TRUE
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #4
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_7_TRUE
    LDD #0
    LBRA .CMP_7_END
.CMP_7_TRUE:
    LDD #1
.CMP_7_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_3_TRUE
    LDD #0
    LBRA .LOGIC_3_END
.LOGIC_3_TRUE:
    LDD #1
.LOGIC_3_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_2_TRUE
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #5
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_8_TRUE
    LDD #0
    LBRA .CMP_8_END
.CMP_8_TRUE:
    LDD #1
.CMP_8_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_2_TRUE
    LDD #0
    LBRA .LOGIC_2_END
.LOGIC_2_TRUE:
    LDD #1
.LOGIC_2_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_5
    LDD VAR_STATE_MAP
    STD RESULT
    LDD RESULT
    STD VAR_SCREEN
    LDD #-1
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_MUSIC
    ; PLAY_SFX: Play sound effect
    JSR PLAY_SFX_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    LBRA IF_END_0
IF_NEXT_1:
    LDD VAR_STATE_MAP
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_SCREEN
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_9_TRUE
    LDD #0
    LBRA .CMP_9_END
.CMP_9_TRUE:
    LDD #1
.CMP_9_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_6
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_MUSIC
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBNE .CMP_10_TRUE
    LDD #0
    LBRA .CMP_10_END
.CMP_10_TRUE:
    LDD #1
.CMP_10_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_8
    ; PLAY_MUSIC("map_theme") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_7
IF_NEXT_8:
IF_END_7:
    LDD VAR_joystick_poll_counter
    STD TMPVAL          ; Save left operand
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + TMPVAL
    STD VAR_JOYSTICK_POLL_COUNTER
    LDD #15
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_JOYSTICK_POLL_COUNTER
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_11_TRUE
    LDD #0
    LBRA .CMP_11_END
.CMP_11_TRUE:
    LDD #1
.CMP_11_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_10
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_JOYSTICK_POLL_COUNTER
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #0
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_JOY_X
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #1
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_JOY_Y
    LBRA IF_END_9
IF_NEXT_10:
IF_END_9:
    LDD #40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_13_TRUE
    LDD #0
    LBRA .CMP_13_END
.CMP_13_TRUE:
    LDD #1
.CMP_13_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_12_FALSE
    LDD #40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PREV_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLE .CMP_14_TRUE
    LDD #0
    LBRA .CMP_14_END
.CMP_14_TRUE:
    LDD #1
.CMP_14_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_12_FALSE
    LDD #1
    LBRA .LOGIC_12_END
.LOGIC_12_FALSE:
    LDD #0
.LOGIC_12_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_12
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_LOCATION
    LDD VAR_NUM_LOCATIONS
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_15_TRUE
    LDD #0
    LBRA .CMP_15_END
.CMP_15_TRUE:
    LDD #1
.CMP_15_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_14
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_LOCATION
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'fuji_level1_v2'
    ; Level asset index: 0 (multibank)
    LDX #0
    JSR LOAD_LEVEL_BANKED  ; Switch bank, load level, return
    LBRA IF_END_13
IF_NEXT_14:
IF_END_13:
    LBRA IF_END_11
IF_NEXT_12:
    LDD #-40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_17_TRUE
    LDD #0
    LBRA .CMP_17_END
.CMP_17_TRUE:
    LDD #1
.CMP_17_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_16_FALSE
    LDD #-40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PREV_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_18_TRUE
    LDD #0
    LBRA .CMP_18_END
.CMP_18_TRUE:
    LDD #1
.CMP_18_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_16_FALSE
    LDD #1
    LBRA .LOGIC_16_END
.LOGIC_16_FALSE:
    LDD #0
.LOGIC_16_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_15
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_LOCATION
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_19_TRUE
    LDD #0
    LBRA .CMP_19_END
.CMP_19_TRUE:
    LDD #1
.CMP_19_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_17
    LDD VAR_NUM_LOCATIONS
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_LOCATION
    LBRA IF_END_16
IF_NEXT_17:
IF_END_16:
    LBRA IF_END_11
IF_NEXT_15:
    LDD #40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_JOY_Y
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_21_TRUE
    LDD #0
    LBRA .CMP_21_END
.CMP_21_TRUE:
    LDD #1
.CMP_21_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_20_FALSE
    LDD #40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PREV_JOY_Y
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLE .CMP_22_TRUE
    LDD #0
    LBRA .CMP_22_END
.CMP_22_TRUE:
    LDD #1
.CMP_22_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_20_FALSE
    LDD #1
    LBRA .LOGIC_20_END
.LOGIC_20_FALSE:
    LDD #0
.LOGIC_20_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_18
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_LOCATION
    LDD VAR_NUM_LOCATIONS
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_23_TRUE
    LDD #0
    LBRA .CMP_23_END
.CMP_23_TRUE:
    LDD #1
.CMP_23_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_20
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_LOCATION
    LBRA IF_END_19
IF_NEXT_20:
IF_END_19:
    LBRA IF_END_11
IF_NEXT_18:
    LDD #-40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_JOY_Y
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_25_TRUE
    LDD #0
    LBRA .CMP_25_END
.CMP_25_TRUE:
    LDD #1
.CMP_25_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_24_FALSE
    LDD #-40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PREV_JOY_Y
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_26_TRUE
    LDD #0
    LBRA .CMP_26_END
.CMP_26_TRUE:
    LDD #1
.CMP_26_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_24_FALSE
    LDD #1
    LBRA .LOGIC_24_END
.LOGIC_24_FALSE:
    LDD #0
.LOGIC_24_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_END_11
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_LOCATION
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_27_TRUE
    LDD #0
    LBRA .CMP_27_END
.CMP_27_TRUE:
    LDD #1
.CMP_27_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_22
    LDD VAR_NUM_LOCATIONS
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_LOCATION
    LBRA IF_END_21
IF_NEXT_22:
IF_END_21:
    LBRA IF_END_11
IF_END_11:
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    STD VAR_PREV_JOY_X
    LDD VAR_JOY_Y
    STD RESULT
    LDD RESULT
    STD VAR_PREV_JOY_Y
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #2
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_31_TRUE
    LDD #0
    LBRA .CMP_31_END
.CMP_31_TRUE:
    LDD #1
.CMP_31_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_30_TRUE
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #3
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_32_TRUE
    LDD #0
    LBRA .CMP_32_END
.CMP_32_TRUE:
    LDD #1
.CMP_32_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_30_TRUE
    LDD #0
    LBRA .LOGIC_30_END
.LOGIC_30_TRUE:
    LDD #1
.LOGIC_30_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_29_TRUE
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #4
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_33_TRUE
    LDD #0
    LBRA .CMP_33_END
.CMP_33_TRUE:
    LDD #1
.CMP_33_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_29_TRUE
    LDD #0
    LBRA .LOGIC_29_END
.LOGIC_29_TRUE:
    LDD #1
.LOGIC_29_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_28_TRUE
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #5
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_34_TRUE
    LDD #0
    LBRA .CMP_34_END
.CMP_34_TRUE:
    LDD #1
.CMP_34_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_28_TRUE
    LDD #0
    LBRA .LOGIC_28_END
.LOGIC_28_TRUE:
    LDD #1
.LOGIC_28_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_24
    ; PLAY_SFX: Play sound effect
    JSR PLAY_SFX_RUNTIME
    LDD #0
    STD RESULT
    LDD VAR_STATE_GAME
    STD RESULT
    LDD RESULT
    STD VAR_SCREEN
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_COUNTDOWN_ACTIVE
    LDD #180
    STD RESULT
    LDD RESULT
    STD VAR_COUNTDOWN_TIMER
    LBRA IF_END_23
IF_NEXT_24:
IF_END_23:
    JSR draw_map_screen
    LBRA IF_END_0
IF_NEXT_6:
    LDD VAR_STATE_GAME
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_SCREEN
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_35_TRUE
    LDD #0
    LBRA .CMP_35_END
.CMP_35_TRUE:
    LDD #1
.CMP_35_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_END_0
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_COUNTDOWN_ACTIVE
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_36_TRUE
    LDD #0
    LBRA .CMP_36_END
.CMP_36_TRUE:
    LDD #1
.CMP_36_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_26
    JSR draw_level_background
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-50
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_62529178322969      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-85
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-20
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #ARRAY_LOCATION_NAMES_DATA  ; Array base
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD VAR_COUNTDOWN_TIMER
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDD RESULT
    STD VAR_COUNTDOWN_TIMER
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_COUNTDOWN_TIMER
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLE .CMP_37_TRUE
    LDD #0
    LBRA .CMP_37_END
.CMP_37_TRUE:
    LDD #1
.CMP_37_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_28
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_COUNTDOWN_ACTIVE
    JSR spawn_enemies
    LBRA IF_END_27
IF_NEXT_28:
IF_END_27:
    LBRA IF_END_25
IF_NEXT_26:
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_HOOK_ACTIVE
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_38_TRUE
    LDD #0
    LBRA .CMP_38_END
.CMP_38_TRUE:
    LDD #1
.CMP_38_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_30
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #2
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_42_TRUE
    LDD #0
    LBRA .CMP_42_END
.CMP_42_TRUE:
    LDD #1
.CMP_42_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_41_TRUE
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #3
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_43_TRUE
    LDD #0
    LBRA .CMP_43_END
.CMP_43_TRUE:
    LDD #1
.CMP_43_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_41_TRUE
    LDD #0
    LBRA .LOGIC_41_END
.LOGIC_41_TRUE:
    LDD #1
.LOGIC_41_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_40_TRUE
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #4
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_44_TRUE
    LDD #0
    LBRA .CMP_44_END
.CMP_44_TRUE:
    LDD #1
.CMP_44_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_40_TRUE
    LDD #0
    LBRA .LOGIC_40_END
.LOGIC_40_TRUE:
    LDD #1
.LOGIC_40_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_39_TRUE
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #5
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_45_TRUE
    LDD #0
    LBRA .CMP_45_END
.CMP_45_TRUE:
    LDD #1
.CMP_45_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_39_TRUE
    LDD #0
    LBRA .LOGIC_39_END
.LOGIC_39_TRUE:
    LDD #1
.LOGIC_39_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_32
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_ACTIVE
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_Y
    ; PLAY_SFX: Play sound effect
    JSR PLAY_SFX_RUNTIME
    LDD #0
    STD RESULT
    LDD VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_GUN_X
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PLAYER_FACING
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_46_TRUE
    LDD #0
    LBRA .CMP_46_END
.CMP_46_TRUE:
    LDD #1
.CMP_46_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_34
    LDD VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #11
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_GUN_X
    LBRA IF_END_33
IF_NEXT_34:
    LDD VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #11
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_GUN_X
IF_END_33:
    LDD VAR_PLAYER_Y
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #3
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_GUN_Y
    LDD VAR_HOOK_GUN_Y
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_INIT_Y
    LDD VAR_HOOK_GUN_X
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_X
    LBRA IF_END_31
IF_NEXT_32:
IF_END_31:
    LBRA IF_END_29
IF_NEXT_30:
IF_END_29:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_HOOK_ACTIVE
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_47_TRUE
    LDD #0
    LBRA .CMP_47_END
.CMP_47_TRUE:
    LDD #1
.CMP_47_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_36
    LDD VAR_HOOK_Y
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #3
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_Y
    LDD VAR_HOOK_MAX_Y
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_HOOK_Y
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_48_TRUE
    LDD #0
    LBRA .CMP_48_END
.CMP_48_TRUE:
    LDD #1
.CMP_48_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_38
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_ACTIVE
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_HOOK_Y
    LBRA IF_END_37
IF_NEXT_38:
IF_END_37:
    LBRA IF_END_35
IF_NEXT_36:
IF_END_35:
    JSR draw_game_level
IF_END_25:
    LBRA IF_END_0
IF_END_0:
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX (after all game logic)
    RTS

; Function: draw_map_screen
draw_map_screen:
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: map (15 paths) with mirror + intensity
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
    LDD #50
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_MAP_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH7  ; Load path 7
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH8  ; Load path 8
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH9  ; Load path 9
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH10  ; Load path 10
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH11  ; Load path 11
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH12  ; Load path 12
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH13  ; Load path 13
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_MAP_PATH14  ; Load path 14
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_LOCATION_GLOW_DIRECTION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_49_TRUE
    LDD #0
    LBRA .CMP_49_END
.CMP_49_TRUE:
    LDD #1
.CMP_49_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_40
    LDD VAR_LOCATION_GLOW_INTENSITY
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #3
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_LOCATION_GLOW_INTENSITY
    LDD #127
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_LOCATION_GLOW_INTENSITY
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_50_TRUE
    LDD #0
    LBRA .CMP_50_END
.CMP_50_TRUE:
    LDD #1
.CMP_50_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_42
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_LOCATION_GLOW_DIRECTION
    LBRA IF_END_41
IF_NEXT_42:
IF_END_41:
    LBRA IF_END_39
IF_NEXT_40:
    LDD VAR_LOCATION_GLOW_INTENSITY
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDD RESULT
    STD VAR_LOCATION_GLOW_INTENSITY
    LDD #80
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_LOCATION_GLOW_INTENSITY
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLE .CMP_51_TRUE
    LDD #0
    LBRA .CMP_51_END
.CMP_51_TRUE:
    LDD #1
.CMP_51_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_44
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_LOCATION_GLOW_DIRECTION
    LBRA IF_END_43
IF_NEXT_44:
IF_END_43:
IF_END_39:
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-80
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #ARRAY_LOCATION_NAMES_DATA  ; Array base
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDX #ARRAY_LOCATION_X_COORDS_DATA  ; Array base
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_LOC_X
    LDX #ARRAY_LOCATION_Y_COORDS_DATA  ; Array base
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_LOC_Y
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: location_marker (1 paths) with mirror + intensity
    LDD VAR_LOC_Y
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD VAR_LOC_X
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
    LBNE .DSVEX_1_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_1_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_1_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_1_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_1_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_1_CALL:
    ; Set intensity override for drawing
    LDD VAR_LOCATION_GLOW_INTENSITY
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_LOCATION_MARKER_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    RTS

; Function: draw_title_screen
draw_title_screen:
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: logo (index=17, 7 paths)
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
    LDX #17        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD VAR_TITLE_INTENSITY
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-90
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_9120385685437879118      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-50
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-20
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2382167728733      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_TITLE_STATE
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_52_TRUE
    LDD #0
    LBRA .CMP_52_END
.CMP_52_TRUE:
    LDD #1
.CMP_52_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_46
    LDD VAR_title_intensity
    STD TMPVAL          ; Save left operand
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + TMPVAL
    STD VAR_TITLE_INTENSITY
    LBRA IF_END_45
IF_NEXT_46:
IF_END_45:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_TITLE_STATE
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_53_TRUE
    LDD #0
    LBRA .CMP_53_END
.CMP_53_TRUE:
    LDD #1
.CMP_53_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_48
    LDD VAR_title_intensity
    STD TMPVAL          ; Save left operand
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPPTR          ; Save right operand
    LDD TMPVAL          ; Get left operand
    SUBD TMPPTR         ; D = left - right
    STD VAR_TITLE_INTENSITY
    LBRA IF_END_47
IF_NEXT_48:
IF_END_47:
    LDD #80
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_TITLE_INTENSITY
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_54_TRUE
    LDD #0
    LBRA .CMP_54_END
.CMP_54_TRUE:
    LDD #1
.CMP_54_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_50
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_TITLE_STATE
    LBRA IF_END_49
IF_NEXT_50:
IF_END_49:
    LDD #30
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_TITLE_INTENSITY
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_55_TRUE
    LDD #0
    LBRA .CMP_55_END
.CMP_55_TRUE:
    LDD #1
.CMP_55_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_52
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_TITLE_STATE
    LBRA IF_END_51
IF_NEXT_52:
IF_END_51:
    RTS

; Function: draw_level_background
draw_level_background:
    ; SET_INTENSITY: Set drawing intensity
    LDD #60
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_56_TRUE
    LDD #0
    LBRA .CMP_56_END
.CMP_56_TRUE:
    LDD #1
.CMP_56_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_54
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: fuji_bg (index=11, 6 paths)
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
    LDX #11        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_54:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_57_TRUE
    LDD #0
    LBRA .CMP_57_END
.CMP_57_TRUE:
    LDD #1
.CMP_57_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_55
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: keirin_bg (index=13, 3 paths)
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
    LDX #13        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_55:
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_58_TRUE
    LDD #0
    LBRA .CMP_58_END
.CMP_58_TRUE:
    LDD #1
.CMP_58_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_56
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: buddha_bg (index=9, 4 paths)
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
    LDX #9        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_56:
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_59_TRUE
    LDD #0
    LBRA .CMP_59_END
.CMP_59_TRUE:
    LDD #1
.CMP_59_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_57
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: angkor_bg (index=0, 3 paths)
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
    LDX #0        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_57:
    LDD #4
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_60_TRUE
    LDD #0
    LBRA .CMP_60_END
.CMP_60_TRUE:
    LDD #1
.CMP_60_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_58
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: ayers_bg (index=3, 3 paths)
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
    LDX #3        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_58:
    LDD #5
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_61_TRUE
    LDD #0
    LBRA .CMP_61_END
.CMP_61_TRUE:
    LDD #1
.CMP_61_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_59
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: taj_bg (index=29, 4 paths)
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
    LDX #29        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_59:
    LDD #6
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_62_TRUE
    LDD #0
    LBRA .CMP_62_END
.CMP_62_TRUE:
    LDD #1
.CMP_62_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_60
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: leningrad_bg (index=15, 5 paths)
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
    LDX #15        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_60:
    LDD #7
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_63_TRUE
    LDD #0
    LBRA .CMP_63_END
.CMP_63_TRUE:
    LDD #1
.CMP_63_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_61
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: paris_bg (index=22, 5 paths)
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
    LDX #22        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_61:
    LDD #8
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_64_TRUE
    LDD #0
    LBRA .CMP_64_END
.CMP_64_TRUE:
    LDD #1
.CMP_64_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_62
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: london_bg (index=18, 4 paths)
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
    LDX #18        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_62:
    LDD #9
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_65_TRUE
    LDD #0
    LBRA .CMP_65_END
.CMP_65_TRUE:
    LDD #1
.CMP_65_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_63
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: barcelona_bg (index=4, 4 paths)
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
    LDX #4        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_63:
    LDD #10
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_66_TRUE
    LDD #0
    LBRA .CMP_66_END
.CMP_66_TRUE:
    LDD #1
.CMP_66_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_64
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: athens_bg (index=2, 7 paths)
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
    LDX #2        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_64:
    LDD #11
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_67_TRUE
    LDD #0
    LBRA .CMP_67_END
.CMP_67_TRUE:
    LDD #1
.CMP_67_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_65
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: pyramids_bg (index=28, 4 paths)
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
    LDX #28        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_65:
    LDD #12
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_68_TRUE
    LDD #0
    LBRA .CMP_68_END
.CMP_68_TRUE:
    LDD #1
.CMP_68_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_66
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: kilimanjaro_bg (index=14, 4 paths)
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
    LDX #14        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_66:
    LDD #13
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_69_TRUE
    LDD #0
    LBRA .CMP_69_END
.CMP_69_TRUE:
    LDD #1
.CMP_69_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_67
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: newyork_bg (index=21, 5 paths)
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
    LDX #21        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_67:
    LDD #14
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_70_TRUE
    LDD #0
    LBRA .CMP_70_END
.CMP_70_TRUE:
    LDD #1
.CMP_70_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_68
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: mayan_bg (index=20, 5 paths)
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
    LDX #20        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_68:
    LDD #15
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_71_TRUE
    LDD #0
    LBRA .CMP_71_END
.CMP_71_TRUE:
    LDD #1
.CMP_71_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_69
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: antarctica_bg (index=1, 4 paths)
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
    LDX #1        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_53
IF_NEXT_69:
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: easter_bg (index=10, 5 paths)
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
    LDX #10        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
IF_END_53:
    RTS

; Function: draw_game_level
draw_game_level:
    JSR draw_level_background
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #0
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_JOY_X
    LDD #-20
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_73_TRUE
    LDD #0
    LBRA .CMP_73_END
.CMP_73_TRUE:
    LDD #1
.CMP_73_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_72_TRUE
    LDD #20
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_74_TRUE
    LDD #0
    LBRA .CMP_74_END
.CMP_74_TRUE:
    LDD #1
.CMP_74_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_72_TRUE
    LDD #0
    LBRA .LOGIC_72_END
.LOGIC_72_TRUE:
    LDD #1
.LOGIC_72_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_71
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    STD VAR_ABS_JOY
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_ABS_JOY
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_75_TRUE
    LDD #0
    LBRA .CMP_75_END
.CMP_75_TRUE:
    LDD #1
.CMP_75_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_73
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD VAR_ABS_JOY
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD RESULT
    LDD RESULT
    STD VAR_ABS_JOY
    LBRA IF_END_72
IF_NEXT_73:
IF_END_72:
    LDD #40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_ABS_JOY
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_76_TRUE
    LDD #0
    LBRA .CMP_76_END
.CMP_76_TRUE:
    LDD #1
.CMP_76_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_75
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_MOVE_SPEED
    LBRA IF_END_74
IF_NEXT_75:
    LDD #70
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_ABS_JOY
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_77_TRUE
    LDD #0
    LBRA .CMP_77_END
.CMP_77_TRUE:
    LDD #1
.CMP_77_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_76
    LDD #2
    STD RESULT
    LDD RESULT
    STD VAR_MOVE_SPEED
    LBRA IF_END_74
IF_NEXT_76:
    LDD #100
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_ABS_JOY
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_78_TRUE
    LDD #0
    LBRA .CMP_78_END
.CMP_78_TRUE:
    LDD #1
.CMP_78_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_77
    LDD #3
    STD RESULT
    LDD RESULT
    STD VAR_MOVE_SPEED
    LBRA IF_END_74
IF_NEXT_77:
    LDD #4
    STD RESULT
    LDD RESULT
    STD VAR_MOVE_SPEED
IF_END_74:
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_79_TRUE
    LDD #0
    LBRA .CMP_79_END
.CMP_79_TRUE:
    LDD #1
.CMP_79_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_79
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD VAR_MOVE_SPEED
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD RESULT
    LDD RESULT
    STD VAR_MOVE_SPEED
    LBRA IF_END_78
IF_NEXT_79:
IF_END_78:
    LDD VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD VAR_MOVE_SPEED
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_X
    LDD #-110
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_80_TRUE
    LDD #0
    LBRA .CMP_80_END
.CMP_80_TRUE:
    LDD #1
.CMP_80_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_81
    LDD #-110
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_X
    LBRA IF_END_80
IF_NEXT_81:
IF_END_80:
    LDD #110
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_81_TRUE
    LDD #0
    LBRA .CMP_81_END
.CMP_81_TRUE:
    LDD #1
.CMP_81_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_83
    LDD #110
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_X
    LBRA IF_END_82
IF_NEXT_83:
IF_END_82:
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_82_TRUE
    LDD #0
    LBRA .CMP_82_END
.CMP_82_TRUE:
    LDD #1
.CMP_82_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_85
    LDD #-1
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_FACING
    LBRA IF_END_84
IF_NEXT_85:
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_FACING
IF_END_84:
    LDD VAR_PLAYER_ANIM_COUNTER
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_ANIM_COUNTER
    LDD VAR_PLAYER_ANIM_SPEED
    STD RESULT
    LDD RESULT
    STD VAR_ANIM_THRESHOLD
    LDD #-80
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_84_TRUE
    LDD #0
    LBRA .CMP_84_END
.CMP_84_TRUE:
    LDD #1
.CMP_84_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_83_TRUE
    LDD #80
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_85_TRUE
    LDD #0
    LBRA .CMP_85_END
.CMP_85_TRUE:
    LDD #1
.CMP_85_END:
    STD RESULT
    LDD RESULT
    LBNE .LOGIC_83_TRUE
    LDD #0
    LBRA .LOGIC_83_END
.LOGIC_83_TRUE:
    LDD #1
.LOGIC_83_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_87
    LDD VAR_PLAYER_ANIM_SPEED
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #2
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR DIV16       ; D = X / D
    STD RESULT
    LDD RESULT
    STD VAR_ANIM_THRESHOLD
    LBRA IF_END_86
IF_NEXT_87:
IF_END_86:
    LDD VAR_ANIM_THRESHOLD
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PLAYER_ANIM_COUNTER
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_86_TRUE
    LDD #0
    LBRA .CMP_86_END
.CMP_86_TRUE:
    LDD #1
.CMP_86_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_89
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_ANIM_COUNTER
    LDD VAR_PLAYER_ANIM_FRAME
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_ANIM_FRAME
    LDD #5
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PLAYER_ANIM_FRAME
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_87_TRUE
    LDD #0
    LBRA .CMP_87_END
.CMP_87_TRUE:
    LDD #1
.CMP_87_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_91
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_ANIM_FRAME
    LBRA IF_END_90
IF_NEXT_91:
IF_END_90:
    LBRA IF_END_88
IF_NEXT_89:
IF_END_88:
    LBRA IF_END_70
IF_NEXT_71:
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_ANIM_FRAME
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_ANIM_COUNTER
IF_END_70:
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_MIRROR_MODE
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PLAYER_FACING
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_88_TRUE
    LDD #0
    LBRA .CMP_88_END
.CMP_88_TRUE:
    LDD #1
.CMP_88_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_93
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_MIRROR_MODE
    LBRA IF_END_92
IF_NEXT_93:
IF_END_92:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PLAYER_ANIM_FRAME
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_89_TRUE
    LDD #0
    LBRA .CMP_89_END
.CMP_89_TRUE:
    LDD #1
.CMP_89_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_95
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_1 (17 paths) with mirror + intensity
    LDD VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD VAR_PLAYER_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD VAR_MIRROR_MODE
    STD RESULT
    LDB RESULT+1  ; Mirror mode (0=normal, 1=X, 2=Y, 3=both)
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_2_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_2_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_2_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_2_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_2_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_2_CALL:
    ; Set intensity override for drawing
    LDD #80
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_PLAYER_WALK_1_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH7  ; Load path 7
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH8  ; Load path 8
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH9  ; Load path 9
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH10  ; Load path 10
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH11  ; Load path 11
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH12  ; Load path 12
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH13  ; Load path 13
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH14  ; Load path 14
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH15  ; Load path 15
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_1_PATH16  ; Load path 16
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    LBRA IF_END_94
IF_NEXT_95:
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PLAYER_ANIM_FRAME
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_90_TRUE
    LDD #0
    LBRA .CMP_90_END
.CMP_90_TRUE:
    LDD #1
.CMP_90_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_96
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_2 (17 paths) with mirror + intensity
    LDD VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD VAR_PLAYER_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD VAR_MIRROR_MODE
    STD RESULT
    LDB RESULT+1  ; Mirror mode (0=normal, 1=X, 2=Y, 3=both)
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_3_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_3_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_3_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_3_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_3_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_3_CALL:
    ; Set intensity override for drawing
    LDD #80
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_PLAYER_WALK_2_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH7  ; Load path 7
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH8  ; Load path 8
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH9  ; Load path 9
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH10  ; Load path 10
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH11  ; Load path 11
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH12  ; Load path 12
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH13  ; Load path 13
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH14  ; Load path 14
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH15  ; Load path 15
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_2_PATH16  ; Load path 16
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    LBRA IF_END_94
IF_NEXT_96:
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PLAYER_ANIM_FRAME
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_91_TRUE
    LDD #0
    LBRA .CMP_91_END
.CMP_91_TRUE:
    LDD #1
.CMP_91_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_97
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_3 (17 paths) with mirror + intensity
    LDD VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD VAR_PLAYER_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD VAR_MIRROR_MODE
    STD RESULT
    LDB RESULT+1  ; Mirror mode (0=normal, 1=X, 2=Y, 3=both)
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_4_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_4_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_4_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_4_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_4_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_4_CALL:
    ; Set intensity override for drawing
    LDD #80
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_PLAYER_WALK_3_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH7  ; Load path 7
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH8  ; Load path 8
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH9  ; Load path 9
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH10  ; Load path 10
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH11  ; Load path 11
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH12  ; Load path 12
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH13  ; Load path 13
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH14  ; Load path 14
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH15  ; Load path 15
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_3_PATH16  ; Load path 16
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    LBRA IF_END_94
IF_NEXT_97:
    LDD #4
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_PLAYER_ANIM_FRAME
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_92_TRUE
    LDD #0
    LBRA .CMP_92_END
.CMP_92_TRUE:
    LDD #1
.CMP_92_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_98
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_4 (17 paths) with mirror + intensity
    LDD VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD VAR_PLAYER_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD VAR_MIRROR_MODE
    STD RESULT
    LDB RESULT+1  ; Mirror mode (0=normal, 1=X, 2=Y, 3=both)
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_5_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_5_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_5_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_5_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_5_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_5_CALL:
    ; Set intensity override for drawing
    LDD #80
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_PLAYER_WALK_4_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH7  ; Load path 7
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH8  ; Load path 8
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH9  ; Load path 9
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH10  ; Load path 10
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH11  ; Load path 11
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH12  ; Load path 12
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH13  ; Load path 13
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH14  ; Load path 14
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH15  ; Load path 15
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_4_PATH16  ; Load path 16
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    LBRA IF_END_94
IF_NEXT_98:
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_5 (17 paths) with mirror + intensity
    LDD VAR_PLAYER_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA DRAW_VEC_X
    LDD VAR_PLAYER_Y
    STD RESULT
    LDA RESULT+1  ; Y position (low byte)
    STA DRAW_VEC_Y
    LDD VAR_MIRROR_MODE
    STD RESULT
    LDB RESULT+1  ; Mirror mode (0=normal, 1=X, 2=Y, 3=both)
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_6_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_6_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_6_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_6_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_6_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_6_CALL:
    ; Set intensity override for drawing
    LDD #80
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_PLAYER_WALK_5_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH7  ; Load path 7
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH8  ; Load path 8
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH9  ; Load path 9
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH10  ; Load path 10
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH11  ; Load path 11
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH12  ; Load path 12
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH13  ; Load path 13
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH14  ; Load path 14
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH15  ; Load path 15
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_WALK_5_PATH16  ; Load path 16
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
IF_END_94:
    JSR update_enemies
    JSR draw_enemies
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_HOOK_ACTIVE
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_93_TRUE
    LDD #0
    LBRA .CMP_93_END
.CMP_93_TRUE:
    LDD #1
.CMP_93_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_100
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
    JSR draw_hook_rope
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: hook (1 paths) with mirror + intensity
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
    LBNE .DSVEX_7_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_7_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_7_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_7_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_7_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_7_CALL:
    ; Set intensity override for drawing
    LDD #100
    STD RESULT
    LDA RESULT+1  ; Intensity (0-127)
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_HOOK_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    LBRA IF_END_99
IF_NEXT_100:
IF_END_99:
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_ACTIVE_COUNT
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_I
WH_101: ; while start
    LDD VAR_MAX_ENEMIES
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_I
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_94_TRUE
    LDD #0
    LBRA .CMP_94_END
.CMP_94_TRUE:
    LDD #1
.CMP_94_END:
    STD RESULT
    LDD RESULT
    LBEQ WH_END_102
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_ACTIVE_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_95_TRUE
    LDD #0
    LBRA .CMP_95_END
.CMP_95_TRUE:
    LDD #1
.CMP_95_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_104
    LDD VAR_ACTIVE_COUNT
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_ACTIVE_COUNT
    LBRA IF_END_103
IF_NEXT_104:
IF_END_103:
    LDD VAR_I
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_I
    LBRA WH_101
WH_END_102: ; while end
    RTS

; Function: spawn_enemies
spawn_enemies:
    LDX #ARRAY_LEVEL_ENEMY_COUNT_DATA  ; Array base
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_COUNT
    LDX #ARRAY_LEVEL_ENEMY_SPEED_DATA  ; Array base
    LDD VAR_CURRENT_LOCATION
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD VAR_SPEED
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_I
WH_105: ; while start
    LDD VAR_COUNT
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_I
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_96_TRUE
    LDD #0
    LBRA .CMP_96_END
.CMP_96_TRUE:
    LDD #1
.CMP_96_END:
    STD RESULT
    LDD RESULT
    LBEQ WH_END_106
    LDD VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_ACTIVE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #1
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_SIZE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #4
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_X_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #-80
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD VAR_I
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #50
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_Y_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #60
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VX_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD VAR_SPEED
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_I
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #2
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MOD16       ; D = X % D
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_97_TRUE
    LDD #0
    LBRA .CMP_97_END
.CMP_97_TRUE:
    LDD #1
.CMP_97_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_108
    LDD VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VX_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD VAR_SPEED
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LBRA IF_END_107
IF_NEXT_108:
IF_END_107:
    LDD VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VY_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD VAR_I
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_I
    LBRA WH_105
WH_END_106: ; while end
    RTS

; Function: update_enemies
update_enemies:
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_I
WH_109: ; while start
    LDD VAR_MAX_ENEMIES
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_I
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_98_TRUE
    LDD #0
    LBRA .CMP_98_END
.CMP_98_TRUE:
    LDD #1
.CMP_98_END:
    STD RESULT
    LDD RESULT
    LBEQ WH_END_110
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_ACTIVE_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_99_TRUE
    LDD #0
    LBRA .CMP_99_END
.CMP_99_TRUE:
    LDD #1
.CMP_99_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_112
    LDD VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VY_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_ENEMY_VY_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD VAR_GRAVITY
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_X_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_VX_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_Y_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_VY_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD VAR_GROUND_Y
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLE .CMP_100_TRUE
    LDD #0
    LBRA .CMP_100_END
.CMP_100_TRUE:
    LDD #1
.CMP_100_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_114
    LDD VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_Y_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD VAR_GROUND_Y
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VY_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_VY_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VY_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_ENEMY_VY_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD VAR_BOUNCE_DAMPING
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #20
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR DIV16       ; D = X / D
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD VAR_MIN_BOUNCE_VY
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_VY_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_101_TRUE
    LDD #0
    LBRA .CMP_101_END
.CMP_101_TRUE:
    LDD #1
.CMP_101_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_116
    LDD VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VY_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD VAR_MIN_BOUNCE_VY
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LBRA IF_END_115
IF_NEXT_116:
IF_END_115:
    LBRA IF_END_113
IF_NEXT_114:
IF_END_113:
    LDD #-85
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLE .CMP_102_TRUE
    LDD #0
    LBRA .CMP_102_END
.CMP_102_TRUE:
    LDD #1
.CMP_102_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_118
    LDD VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_X_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #-85
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VX_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_VX_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LBRA IF_END_117
IF_NEXT_118:
IF_END_117:
    LDD #85
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_103_TRUE
    LDD #0
    LBRA .CMP_103_END
.CMP_103_TRUE:
    LDD #1
.CMP_103_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_120
    LDD VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_X_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #85
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD VAR_I
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VX_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #-1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_VX_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    LDX TMPVAL      ; Get left into X from TMPVAL
    JSR MUL16       ; D = X * D
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LBRA IF_END_119
IF_NEXT_120:
IF_END_119:
    LBRA IF_END_111
IF_NEXT_112:
IF_END_111:
    LDD VAR_I
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_I
    LBRA WH_109
WH_END_110: ; while end
    RTS

; Function: draw_enemies
draw_enemies:
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_I
WH_121: ; while start
    LDD VAR_MAX_ENEMIES
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_I
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_104_TRUE
    LDD #0
    LBRA .CMP_104_END
.CMP_104_TRUE:
    LDD #1
.CMP_104_END:
    STD RESULT
    LDD RESULT
    LBEQ WH_END_122
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_ACTIVE_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_105_TRUE
    LDD #0
    LBRA .CMP_105_END
.CMP_105_TRUE:
    LDD #1
.CMP_105_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_124
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    LDD #4
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_SIZE_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_106_TRUE
    LDD #0
    LBRA .CMP_106_END
.CMP_106_TRUE:
    LDD #1
.CMP_106_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_126
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bubble_huge (index=5, 1 paths)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
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
    LDX #5        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_125
IF_NEXT_126:
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_SIZE_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_107_TRUE
    LDD #0
    LBRA .CMP_107_END
.CMP_107_TRUE:
    LDD #1
.CMP_107_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_127
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bubble_large (index=6, 1 paths)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
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
    LDX #6        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_125
IF_NEXT_127:
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_SIZE_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_108_TRUE
    LDD #0
    LBRA .CMP_108_END
.CMP_108_TRUE:
    LDD #1
.CMP_108_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_128
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bubble_medium (index=7, 1 paths)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
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
    LDX #7        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_125
IF_NEXT_128:
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bubble_small (index=8, 1 paths)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD VAR_I
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPVAL  ; Save index to TMPVAL temporarily
    LDD TMPVAL  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
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
    LDX #8        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    LDD #0
    STD RESULT
IF_END_125:
    LBRA IF_END_123
IF_NEXT_124:
IF_END_123:
    LDD VAR_I
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_I
    LBRA WH_121
WH_END_122: ; while end
    RTS

; Function: draw_hook_rope
draw_hook_rope:
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD VAR_START_X
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+0    ; x0
    LDD VAR_START_Y
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+2    ; y0
    LDD VAR_END_X
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+4    ; x1
    LDD VAR_END_Y
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #127
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    RTS

; Function: read_joystick1_state
read_joystick1_state:
    LDD #0
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_JOYSTICK1_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    JSR J1X_BUILTIN
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD #1
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_JOYSTICK1_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    JSR J1Y_BUILTIN
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD #2
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_JOYSTICK1_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDA $C80F      ; Vec_Btn_State (updated by Read_Btns)
    ANDA #$01      ; Test bit 0
    LBEQ .J1B1_8_OFF
    LDD #1
    LBRA .J1B1_8_END
.J1B1_8_OFF:
    LDD #0
.J1B1_8_END:
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD #3
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_JOYSTICK1_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDA $C80F      ; Vec_Btn_State (updated by Read_Btns)
    ANDA #$02      ; Test bit 1
    LBEQ .J1B2_9_OFF
    LDD #1
    LBRA .J1B2_9_END
.J1B2_9_OFF:
    LDD #0
.J1B2_9_END:
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD #4
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_JOYSTICK1_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDA $C80F      ; Vec_Btn_State (updated by Read_Btns)
    ANDA #$04      ; Test bit 2
    LBEQ .J1B3_10_OFF
    LDD #1
    LBRA .J1B3_10_END
.J1B3_10_OFF:
    LDD #0
.J1B3_10_END:
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD #5
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_JOYSTICK1_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDA $C80F      ; Vec_Btn_State (updated by Read_Btns)
    ANDA #$08      ; Test bit 3
    LBEQ .J1B4_11_OFF
    LDD #1
    LBRA .J1B4_11_END
.J1B4_11_OFF:
    LDD #0
.J1B4_11_END:
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    RTS


; ================================================


; ===== BANK #01 (physical offset $04000) =====

    ORG $0000  ; Sequential bank model

;***************************************************************************
; ASSETS IN BANK #1 (35 assets)
;***************************************************************************

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

_LASER_SFX:
    ; SFX: laser (laser)
    ; Duration: 500ms (25fr), Freq: 880Hz, Channel: 0
    FCB $A0         ; Frame 0 - flags (vol=0, tone=Y, noise=N)
    FCB $00, $34  ; Tone period = 52 (big-endian)
    FCB $AF         ; Frame 1 - flags (vol=15, tone=Y, noise=N)
    FCB $00, $3A  ; Tone period = 58 (big-endian)
    FCB $AC         ; Frame 2 - flags (vol=12, tone=Y, noise=N)
    FCB $00, $42  ; Tone period = 66 (big-endian)
    FCB $AC         ; Frame 3 - flags (vol=12, tone=Y, noise=N)
    FCB $00, $48  ; Tone period = 72 (big-endian)
    FCB $AC         ; Frame 4 - flags (vol=12, tone=Y, noise=N)
    FCB $00, $4E  ; Tone period = 78 (big-endian)
    FCB $AC         ; Frame 5 - flags (vol=12, tone=Y, noise=N)
    FCB $00, $56  ; Tone period = 86 (big-endian)
    FCB $AC         ; Frame 6 - flags (vol=12, tone=Y, noise=N)
    FCB $00, $5C  ; Tone period = 92 (big-endian)
    FCB $AC         ; Frame 7 - flags (vol=12, tone=Y, noise=N)
    FCB $00, $62  ; Tone period = 98 (big-endian)
    FCB $AC         ; Frame 8 - flags (vol=12, tone=Y, noise=N)
    FCB $00, $6A  ; Tone period = 106 (big-endian)
    FCB $AC         ; Frame 9 - flags (vol=12, tone=Y, noise=N)
    FCB $00, $70  ; Tone period = 112 (big-endian)
    FCB $AC         ; Frame 10 - flags (vol=12, tone=Y, noise=N)
    FCB $00, $76  ; Tone period = 118 (big-endian)
    FCB $AC         ; Frame 11 - flags (vol=12, tone=Y, noise=N)
    FCB $00, $7C  ; Tone period = 124 (big-endian)
    FCB $AC         ; Frame 12 - flags (vol=12, tone=Y, noise=N)
    FCB $00, $84  ; Tone period = 132 (big-endian)
    FCB $AC         ; Frame 13 - flags (vol=12, tone=Y, noise=N)
    FCB $00, $8A  ; Tone period = 138 (big-endian)
    FCB $AC         ; Frame 14 - flags (vol=12, tone=Y, noise=N)
    FCB $00, $90  ; Tone period = 144 (big-endian)
    FCB $AC         ; Frame 15 - flags (vol=12, tone=Y, noise=N)
    FCB $00, $98  ; Tone period = 152 (big-endian)
    FCB $AC         ; Frame 16 - flags (vol=12, tone=Y, noise=N)
    FCB $00, $9E  ; Tone period = 158 (big-endian)
    FCB $AC         ; Frame 17 - flags (vol=12, tone=Y, noise=N)
    FCB $00, $A4  ; Tone period = 164 (big-endian)
    FCB $AC         ; Frame 18 - flags (vol=12, tone=Y, noise=N)
    FCB $00, $AC  ; Tone period = 172 (big-endian)
    FCB $AC         ; Frame 19 - flags (vol=12, tone=Y, noise=N)
    FCB $00, $B2  ; Tone period = 178 (big-endian)
    FCB $AC         ; Frame 20 - flags (vol=12, tone=Y, noise=N)
    FCB $00, $B8  ; Tone period = 184 (big-endian)
    FCB $A9         ; Frame 21 - flags (vol=9, tone=Y, noise=N)
    FCB $00, $C0  ; Tone period = 192 (big-endian)
    FCB $A7         ; Frame 22 - flags (vol=7, tone=Y, noise=N)
    FCB $00, $C6  ; Tone period = 198 (big-endian)
    FCB $A4         ; Frame 23 - flags (vol=4, tone=Y, noise=N)
    FCB $00, $CC  ; Tone period = 204 (big-endian)
    FCB $A2         ; Frame 24 - flags (vol=2, tone=Y, noise=N)
    FCB $00, $D4  ; Tone period = 212 (big-endian)
    FCB $D0, $20    ; End of effect marker


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

_HIT_SFX:
    ; SFX: hit (hit)
    ; Duration: 300ms (15fr), Freq: 200Hz, Channel: 0
    FCB $60         ; Frame 0 - flags (vol=0, tone=Y, noise=Y)
    FCB $00, $8C  ; Tone period = 140 (big-endian)
    FCB $08         ; Noise period
    FCB $6F         ; Frame 1 - flags (vol=15, tone=Y, noise=Y)
    FCB $00, $AA  ; Tone period = 170 (big-endian)
    FCB $08         ; Noise period
    FCB $6F         ; Frame 2 - flags (vol=15, tone=Y, noise=Y)
    FCB $00, $C8  ; Tone period = 200 (big-endian)
    FCB $08         ; Noise period
    FCB $6E         ; Frame 3 - flags (vol=14, tone=Y, noise=Y)
    FCB $00, $E6  ; Tone period = 230 (big-endian)
    FCB $08         ; Noise period
    FCB $6D         ; Frame 4 - flags (vol=13, tone=Y, noise=Y)
    FCB $01, $04  ; Tone period = 260 (big-endian)
    FCB $08         ; Noise period
    FCB $6C         ; Frame 5 - flags (vol=12, tone=Y, noise=Y)
    FCB $01, $22  ; Tone period = 290 (big-endian)
    FCB $08         ; Noise period
    FCB $6C         ; Frame 6 - flags (vol=12, tone=Y, noise=Y)
    FCB $01, $40  ; Tone period = 320 (big-endian)
    FCB $08         ; Noise period
    FCB $6C         ; Frame 7 - flags (vol=12, tone=Y, noise=Y)
    FCB $01, $5E  ; Tone period = 350 (big-endian)
    FCB $08         ; Noise period
    FCB $6C         ; Frame 8 - flags (vol=12, tone=Y, noise=Y)
    FCB $01, $7C  ; Tone period = 380 (big-endian)
    FCB $08         ; Noise period
    FCB $6C         ; Frame 9 - flags (vol=12, tone=Y, noise=Y)
    FCB $01, $9A  ; Tone period = 410 (big-endian)
    FCB $08         ; Noise period
    FCB $6C         ; Frame 10 - flags (vol=12, tone=Y, noise=Y)
    FCB $01, $B8  ; Tone period = 440 (big-endian)
    FCB $08         ; Noise period
    FCB $6C         ; Frame 11 - flags (vol=12, tone=Y, noise=Y)
    FCB $01, $D6  ; Tone period = 470 (big-endian)
    FCB $08         ; Noise period
    FCB $69         ; Frame 12 - flags (vol=9, tone=Y, noise=Y)
    FCB $01, $F4  ; Tone period = 500 (big-endian)
    FCB $08         ; Noise period
    FCB $66         ; Frame 13 - flags (vol=6, tone=Y, noise=Y)
    FCB $02, $12  ; Tone period = 530 (big-endian)
    FCB $08         ; Noise period
    FCB $63         ; Frame 14 - flags (vol=3, tone=Y, noise=Y)
    FCB $02, $30  ; Tone period = 560 (big-endian)
    FCB $08         ; Noise period
    FCB $D0, $20    ; End of effect marker


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

; Generated from athens_bg.vec (Malban Draw_Sync_List format)
; Total paths: 7, points: 15
; X bounds: min=-80, max=80, width=160
; Center: (0, 22)

_ATHENS_BG_WIDTH EQU 160
_ATHENS_BG_CENTER_X EQU 0
_ATHENS_BG_CENTER_Y EQU 22

_ATHENS_BG_VECTORS:  ; Main entry (header + 7 path(s))
    FCB 7               ; path_count (runtime metadata)
    FDB _ATHENS_BG_PATH0        ; pointer to path 0
    FDB _ATHENS_BG_PATH1        ; pointer to path 1
    FDB _ATHENS_BG_PATH2        ; pointer to path 2
    FDB _ATHENS_BG_PATH3        ; pointer to path 3
    FDB _ATHENS_BG_PATH4        ; pointer to path 4
    FDB _ATHENS_BG_PATH5        ; pointer to path 5
    FDB _ATHENS_BG_PATH6        ; pointer to path 6

_ATHENS_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $12,$B0,0,0        ; path0: header (y=18, x=-80, relative to center)
    FCB $FF,$0F,$50          ; line 0: flag=-1, dy=15, dx=80
    FCB $FF,$F1,$50          ; line 1: flag=-1, dy=-15, dx=80
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH1:    ; Path 1
    FCB 110              ; path1: intensity
    FCB $12,$BA,0,0        ; path1: header (y=18, x=-70, relative to center)
    FCB $FF,$CE,$00          ; line 0: flag=-1, dy=-50, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH2:    ; Path 2
    FCB 110              ; path2: intensity
    FCB $12,$D8,0,0        ; path2: header (y=18, x=-40, relative to center)
    FCB $FF,$CE,$00          ; line 0: flag=-1, dy=-50, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH3:    ; Path 3
    FCB 110              ; path3: intensity
    FCB $12,$F6,0,0        ; path3: header (y=18, x=-10, relative to center)
    FCB $FF,$CE,$00          ; line 0: flag=-1, dy=-50, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH4:    ; Path 4
    FCB 110              ; path4: intensity
    FCB $12,$14,0,0        ; path4: header (y=18, x=20, relative to center)
    FCB $FF,$CE,$00          ; line 0: flag=-1, dy=-50, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH5:    ; Path 5
    FCB 110              ; path5: intensity
    FCB $12,$32,0,0        ; path5: header (y=18, x=50, relative to center)
    FCB $FF,$CE,$00          ; line 0: flag=-1, dy=-50, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH6:    ; Path 6
    FCB 100              ; path6: intensity
    FCB $E0,$B0,0,0        ; path6: header (y=-32, x=-80, relative to center)
    FCB $FF,$00,$7F          ; line 0: flag=-1, dy=0, dx=127
    FCB 2                ; End marker (path complete)

; Generated from barcelona_bg.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 20
; X bounds: min=-50, max=50, width=100
; Center: (0, 22)

_BARCELONA_BG_WIDTH EQU 100
_BARCELONA_BG_CENTER_X EQU 0
_BARCELONA_BG_CENTER_Y EQU 22

_BARCELONA_BG_VECTORS:  ; Main entry (header + 4 path(s))
    FCB 4               ; path_count (runtime metadata)
    FDB _BARCELONA_BG_PATH0        ; pointer to path 0
    FDB _BARCELONA_BG_PATH1        ; pointer to path 1
    FDB _BARCELONA_BG_PATH2        ; pointer to path 2
    FDB _BARCELONA_BG_PATH3        ; pointer to path 3

_BARCELONA_BG_PATH0:    ; Path 0
    FCB 120              ; path0: intensity
    FCB $D6,$CE,0,0        ; path0: header (y=-42, x=-50, relative to center)
    FCB $FF,$46,$00          ; line 0: flag=-1, dy=70, dx=0
    FCB $FF,$0A,$05          ; line 1: flag=-1, dy=10, dx=5
    FCB $FF,$F6,$05          ; line 2: flag=-1, dy=-10, dx=5
    FCB $FF,$BA,$00          ; line 3: flag=-1, dy=-70, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $D6,$EC,0,0        ; path1: header (y=-42, x=-20, relative to center)
    FCB $FF,$4B,$00          ; line 0: flag=-1, dy=75, dx=0
    FCB $FF,$0A,$05          ; line 1: flag=-1, dy=10, dx=5
    FCB $FF,$F6,$05          ; line 2: flag=-1, dy=-10, dx=5
    FCB $FF,$B5,$00          ; line 3: flag=-1, dy=-75, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $D6,$0A,0,0        ; path2: header (y=-42, x=10, relative to center)
    FCB $FF,$4B,$00          ; line 0: flag=-1, dy=75, dx=0
    FCB $FF,$0A,$05          ; line 1: flag=-1, dy=10, dx=5
    FCB $FF,$F6,$05          ; line 2: flag=-1, dy=-10, dx=5
    FCB $FF,$B5,$00          ; line 3: flag=-1, dy=-75, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH3:    ; Path 3
    FCB 120              ; path3: intensity
    FCB $D6,$28,0,0        ; path3: header (y=-42, x=40, relative to center)
    FCB $FF,$46,$00          ; line 0: flag=-1, dy=70, dx=0
    FCB $FF,$0A,$05          ; line 1: flag=-1, dy=10, dx=5
    FCB $FF,$F6,$05          ; line 2: flag=-1, dy=-10, dx=5
    FCB $FF,$BA,$00          ; line 3: flag=-1, dy=-70, dx=0
    FCB 2                ; End marker (path complete)

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

; Generated from angkor_bg.vec (Malban Draw_Sync_List format)
; Total paths: 3, points: 16
; X bounds: min=-60, max=60, width=120
; Center: (0, 12)

_ANGKOR_BG_WIDTH EQU 120
_ANGKOR_BG_CENTER_X EQU 0
_ANGKOR_BG_CENTER_Y EQU 12

_ANGKOR_BG_VECTORS:  ; Main entry (header + 3 path(s))
    FCB 3               ; path_count (runtime metadata)
    FDB _ANGKOR_BG_PATH0        ; pointer to path 0
    FDB _ANGKOR_BG_PATH1        ; pointer to path 1
    FDB _ANGKOR_BG_PATH2        ; pointer to path 2

_ANGKOR_BG_PATH0:    ; Path 0
    FCB 120              ; path0: intensity
    FCB $D6,$EC,0,0        ; path0: header (y=-42, x=-20, relative to center)
    FCB $FF,$46,$00          ; line 0: flag=-1, dy=70, dx=0
    FCB $FF,$0F,$0A          ; line 1: flag=-1, dy=15, dx=10
    FCB $FF,$00,$14          ; line 2: flag=-1, dy=0, dx=20
    FCB $FF,$F1,$0A          ; line 3: flag=-1, dy=-15, dx=10
    FCB $FF,$BA,$00          ; line 4: flag=-1, dy=-70, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH1:    ; Path 1
    FCB 100              ; path1: intensity
    FCB $E0,$C4,0,0        ; path1: header (y=-32, x=-60, relative to center)
    FCB $FF,$32,$00          ; line 0: flag=-1, dy=50, dx=0
    FCB $FF,$0A,$0A          ; line 1: flag=-1, dy=10, dx=10
    FCB $FF,$F6,$0A          ; line 2: flag=-1, dy=-10, dx=10
    FCB $FF,$CE,$00          ; line 3: flag=-1, dy=-50, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $E0,$28,0,0        ; path2: header (y=-32, x=40, relative to center)
    FCB $FF,$32,$00          ; line 0: flag=-1, dy=50, dx=0
    FCB $FF,$0A,$0A          ; line 1: flag=-1, dy=10, dx=10
    FCB $FF,$F6,$0A          ; line 2: flag=-1, dy=-10, dx=10
    FCB $FF,$CE,$00          ; line 3: flag=-1, dy=-50, dx=0
    FCB 2                ; End marker (path complete)

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

; Generated from antarctica_bg.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 12
; X bounds: min=-120, max=120, width=240
; Center: (0, 15)

_ANTARCTICA_BG_WIDTH EQU 240
_ANTARCTICA_BG_CENTER_X EQU 0
_ANTARCTICA_BG_CENTER_Y EQU 15

_ANTARCTICA_BG_VECTORS:  ; Main entry (header + 4 path(s))
    FCB 4               ; path_count (runtime metadata)
    FDB _ANTARCTICA_BG_PATH0        ; pointer to path 0
    FDB _ANTARCTICA_BG_PATH1        ; pointer to path 1
    FDB _ANTARCTICA_BG_PATH2        ; pointer to path 2
    FDB _ANTARCTICA_BG_PATH3        ; pointer to path 3

_ANTARCTICA_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $DD,$B0,0,0        ; path0: header (y=-35, x=-80, relative to center)
    FCB $FF,$3C,$14          ; line 0: flag=-1, dy=60, dx=20
    FCB $FF,$C4,$14          ; line 1: flag=-1, dy=-60, dx=20
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH1:    ; Path 1
    FCB 110              ; path1: intensity
    FCB $DD,$E2,0,0        ; path1: header (y=-35, x=-30, relative to center)
    FCB $FF,$46,$14          ; line 0: flag=-1, dy=70, dx=20
    FCB $FF,$00,$14          ; line 1: flag=-1, dy=0, dx=20
    FCB $FF,$BA,$14          ; line 2: flag=-1, dy=-70, dx=20
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $DD,$28,0,0        ; path2: header (y=-35, x=40, relative to center)
    FCB $FF,$37,$14          ; line 0: flag=-1, dy=55, dx=20
    FCB $FF,$C9,$14          ; line 1: flag=-1, dy=-55, dx=20
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH3:    ; Path 3
    FCB 80              ; path3: intensity
    FCB $DD,$88,0,0        ; path3: header (y=-35, x=-120, relative to center)
    FCB $FF,$00,$7F          ; line 0: flag=-1, dy=0, dx=127
    FCB 2                ; End marker (path complete)

; Generated from ayers_bg.vec (Malban Draw_Sync_List format)
; Total paths: 3, points: 13
; X bounds: min=-90, max=90, width=180
; Center: (0, 10)

_AYERS_BG_WIDTH EQU 180
_AYERS_BG_CENTER_X EQU 0
_AYERS_BG_CENTER_Y EQU 10

_AYERS_BG_VECTORS:  ; Main entry (header + 3 path(s))
    FCB 3               ; path_count (runtime metadata)
    FDB _AYERS_BG_PATH0        ; pointer to path 0
    FDB _AYERS_BG_PATH1        ; pointer to path 1
    FDB _AYERS_BG_PATH2        ; pointer to path 2

_AYERS_BG_PATH0:    ; Path 0
    FCB 110              ; path0: intensity
    FCB $D8,$A6,0,0        ; path0: header (y=-40, x=-90, relative to center)
    FCB $FF,$32,$14          ; line 0: flag=-1, dy=50, dx=20
    FCB $FF,$19,$1E          ; line 1: flag=-1, dy=25, dx=30
    FCB $FF,$05,$28          ; line 2: flag=-1, dy=5, dx=40
    FCB $FF,$FB,$28          ; line 3: flag=-1, dy=-5, dx=40
    FCB $FF,$E7,$1E          ; line 4: flag=-1, dy=-25, dx=30
    FCB $FF,$CE,$14          ; line 5: flag=-1, dy=-50, dx=20
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH1:    ; Path 1
    FCB 80              ; path1: intensity
    FCB $00,$CE,0,0        ; path1: header (y=0, x=-50, relative to center)
    FCB $FF,$0F,$14          ; line 0: flag=-1, dy=15, dx=20
    FCB $FF,$05,$1E          ; line 1: flag=-1, dy=5, dx=30
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH2:    ; Path 2
    FCB 80              ; path2: intensity
    FCB $14,$00,0,0        ; path2: header (y=20, x=0, relative to center)
    FCB $FF,$FB,$1E          ; line 0: flag=-1, dy=-5, dx=30
    FCB $FF,$F1,$14          ; line 1: flag=-1, dy=-15, dx=20
    FCB 2                ; End marker (path complete)

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


; ================================================


; ===== BANK #02 (physical offset $08000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #03 (physical offset $0C000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #04 (physical offset $10000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #05 (physical offset $14000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #06 (physical offset $18000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #07 (physical offset $1C000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #08 (physical offset $20000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #09 (physical offset $24000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #10 (physical offset $28000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #11 (physical offset $2C000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #12 (physical offset $30000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #13 (physical offset $34000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #14 (physical offset $38000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #15 (physical offset $3C000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #16 (physical offset $40000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #17 (physical offset $44000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #18 (physical offset $48000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #19 (physical offset $4C000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #20 (physical offset $50000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #21 (physical offset $54000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #22 (physical offset $58000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #23 (physical offset $5C000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #24 (physical offset $60000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #25 (physical offset $64000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #26 (physical offset $68000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #27 (physical offset $6C000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #28 (physical offset $70000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #29 (physical offset $74000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #30 (physical offset $78000) =====

    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================


; ===== BANK #31 (physical offset $7C000) =====
    ORG $4000  ; Fixed bank window (runtime helpers + interrupt vectors)


VECTOR_BANK_TABLE:
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID

VECTOR_ADDR_TABLE:
    FDB _ANGKOR_BG_VECTORS    ; angkor_bg
    FDB _ANTARCTICA_BG_VECTORS    ; antarctica_bg
    FDB _ATHENS_BG_VECTORS    ; athens_bg
    FDB _AYERS_BG_VECTORS    ; ayers_bg
    FDB _BARCELONA_BG_VECTORS    ; barcelona_bg
    FDB _BUBBLE_HUGE_VECTORS    ; bubble_huge
    FDB _BUBBLE_LARGE_VECTORS    ; bubble_large
    FDB _BUBBLE_MEDIUM_VECTORS    ; bubble_medium
    FDB _BUBBLE_SMALL_VECTORS    ; bubble_small
    FDB _BUDDHA_BG_VECTORS    ; buddha_bg
    FDB _EASTER_BG_VECTORS    ; easter_bg
    FDB _FUJI_BG_VECTORS    ; fuji_bg
    FDB _HOOK_VECTORS    ; hook
    FDB _KEIRIN_BG_VECTORS    ; keirin_bg
    FDB _KILIMANJARO_BG_VECTORS    ; kilimanjaro_bg
    FDB _LENINGRAD_BG_VECTORS    ; leningrad_bg
    FDB _LOCATION_MARKER_VECTORS    ; location_marker
    FDB _LOGO_VECTORS    ; logo
    FDB _LONDON_BG_VECTORS    ; london_bg
    FDB _MAP_VECTORS    ; map
    FDB _MAYAN_BG_VECTORS    ; mayan_bg
    FDB _NEWYORK_BG_VECTORS    ; newyork_bg
    FDB _PARIS_BG_VECTORS    ; paris_bg
    FDB _PLAYER_WALK_1_VECTORS    ; player_walk_1
    FDB _PLAYER_WALK_2_VECTORS    ; player_walk_2
    FDB _PLAYER_WALK_3_VECTORS    ; player_walk_3
    FDB _PLAYER_WALK_4_VECTORS    ; player_walk_4
    FDB _PLAYER_WALK_5_VECTORS    ; player_walk_5
    FDB _PYRAMIDS_BG_VECTORS    ; pyramids_bg
    FDB _TAJ_BG_VECTORS    ; taj_bg

; Music Asset Index Mapping:
;   0 = map_theme (Bank #1)
;   1 = pang_theme (Bank #1)

MUSIC_BANK_TABLE:
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID

MUSIC_ADDR_TABLE:
    FDB _MAP_THEME_MUSIC    ; map_theme
    FDB _PANG_THEME_MUSIC    ; pang_theme

; SFX Asset Index Mapping:
;   0 = hit (Bank #1)
;   1 = laser (Bank #1)

SFX_BANK_TABLE:
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID

SFX_ADDR_TABLE:
    FDB _HIT_SFX    ; hit
    FDB _LASER_SFX    ; laser

; Level Asset Index Mapping:
;   0 = fuji_level1_v2 (Bank #1)

LEVEL_BANK_TABLE:
    FCB 1              ; Bank ID

LEVEL_ADDR_TABLE:
    FDB _FUJI_LEVEL1_V2_LEVEL    ; fuji_level1_v2

; Legacy unified tables (all assets)
ASSET_BANK_TABLE:
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID

ASSET_ADDR_TABLE:
    FDB _MAP_THEME_MUSIC    ; map_theme
    FDB _MAP_VECTORS    ; map
    FDB _PANG_THEME_MUSIC    ; pang_theme
    FDB _PLAYER_WALK_1_VECTORS    ; player_walk_1
    FDB _PLAYER_WALK_2_VECTORS    ; player_walk_2
    FDB _PLAYER_WALK_3_VECTORS    ; player_walk_3
    FDB _PLAYER_WALK_4_VECTORS    ; player_walk_4
    FDB _PLAYER_WALK_5_VECTORS    ; player_walk_5
    FDB _LOGO_VECTORS    ; logo
    FDB _FUJI_BG_VECTORS    ; fuji_bg
    FDB _LASER_SFX    ; laser
    FDB _NEWYORK_BG_VECTORS    ; newyork_bg
    FDB _HIT_SFX    ; hit
    FDB _LENINGRAD_BG_VECTORS    ; leningrad_bg
    FDB _MAYAN_BG_VECTORS    ; mayan_bg
    FDB _FUJI_LEVEL1_V2_LEVEL    ; fuji_level1_v2
    FDB _EASTER_BG_VECTORS    ; easter_bg
    FDB _ATHENS_BG_VECTORS    ; athens_bg
    FDB _BARCELONA_BG_VECTORS    ; barcelona_bg
    FDB _BUBBLE_LARGE_VECTORS    ; bubble_large
    FDB _BUBBLE_MEDIUM_VECTORS    ; bubble_medium
    FDB _BUBBLE_SMALL_VECTORS    ; bubble_small
    FDB _PARIS_BG_VECTORS    ; paris_bg
    FDB _LONDON_BG_VECTORS    ; london_bg
    FDB _ANGKOR_BG_VECTORS    ; angkor_bg
    FDB _KILIMANJARO_BG_VECTORS    ; kilimanjaro_bg
    FDB _TAJ_BG_VECTORS    ; taj_bg
    FDB _ANTARCTICA_BG_VECTORS    ; antarctica_bg
    FDB _AYERS_BG_VECTORS    ; ayers_bg
    FDB _BUDDHA_BG_VECTORS    ; buddha_bg
    FDB _PYRAMIDS_BG_VECTORS    ; pyramids_bg
    FDB _KEIRIN_BG_VECTORS    ; keirin_bg
    FDB _LOCATION_MARKER_VECTORS    ; location_marker
    FDB _HOOK_VECTORS    ; hook
    FDB _BUBBLE_HUGE_VECTORS    ; bubble_huge

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
    LDD 1,S              ; Reload asset index from stack (offset 1, skip saved bank)
    ASLB                 ; *2 for FDB entries
    ROLA
    LDX #VECTOR_ADDR_TABLE
    LEAX D,X             ; X points to address entry
    LDX ,X               ; X = actual vector address in banked ROM

    ; Set up for drawing
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY
    JSR $F1AA            ; DP_to_D0

    ; Draw the vector (X already has address)
    JSR Draw_Sync_List_At_With_Mirrors

    JSR $F1AF            ; DP_to_C8

    ; Restore original bank from stack
    PULS X,A             ; A = original bank, X = level index (discarded but preserves balance)
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
; LOAD_LEVEL_BANKED - Load level asset with automatic bank switching
; Input: X = Level asset index (0-based)
; Output: LEVEL_PTR, LEVEL_WIDTH, LEVEL_HEIGHT set
; Uses: A, B, X, Y
;***************************************************************************
LOAD_LEVEL_BANKED:
    ; Save level index to U register, save context to stack
    TFR X,U              ; U = level index
    LDA CURRENT_ROM_BANK
    PSHS A               ; Stack: [A] - Only save original bank

    ; Get level's bank from lookup table
    TFR U,D              ; D = level index (from U)
    LDX #LEVEL_BANK_TABLE
    LDA D,X              ; A = bank ID for this level
    STA CURRENT_ROM_BANK ; Update RAM tracker
    STA $DF00            ; Switch bank hardware register

    ; Get level's address from lookup table (2 bytes per entry)
    TFR U,D              ; Reload level index from U
    ASLB                 ; *2 for FDB entries
    ROLA
    LDX #LEVEL_ADDR_TABLE
    LEAX D,X             ; X points to address entry
    LDX ,X               ; X = actual level address in banked ROM

    ; Load level data into RAM variables
    STX LEVEL_PTR        ; Store level data pointer
    LDA ,X+              ; Load width (byte)
    STA LEVEL_WIDTH
    LDA ,X+              ; Load height (byte)
    STA LEVEL_HEIGHT

    ; Restore original bank from stack
    PULS A               ; A = original bank
    STA CURRENT_ROM_BANK
    STA $DF00            ; Restore bank

    LDD #1               ; Return success
    STD RESULT

    RTS

;***************************************************************************
; RUNTIME HELPERS
;***************************************************************************

VECTREX_PRINT_TEXT:
    ; VPy signature: PRINT_TEXT(x, y, string)
    ; BIOS signature: Print_Str_d(A=Y, B=X, U=string)
    ; CRITICAL: Set VIA to DAC mode BEFORE calling BIOS (don't assume state)
    LDA #$98       ; VIA_cntl = $98 (DAC mode for text rendering)
    STA >$D00C     ; VIA_cntl
    JSR $F1AA      ; DP_to_D0 - set Direct Page for BIOS/VIA access
    LDU VAR_ARG2   ; string pointer (third parameter)
    LDA VAR_ARG1+1 ; Y coordinate (second parameter, low byte)
    LDB VAR_ARG0+1 ; X coordinate (first parameter, low byte)
    JSR Print_Str_d ; Print string from U register
    ; CRITICAL: Reset ALL pen parameters after Print_Str_d (scale, position, etc.)
    JSR Reset_Pen  ; BIOS $F35B - resets scale, intensity, and beam state
    JSR $F1AF      ; DP_to_C8 - restore DP before return
    RTS

MUL16:
    ; Multiply 16-bit X * D -> D
    ; Simple implementation (can be optimized)
    PSHS X,B,A
    LDD #0         ; Result accumulator
    LDX 2,S        ; Multiplier
.MUL16_LOOP:
    BEQ .MUL16_END
    ADDD ,S        ; Add multiplicand
    LEAX -1,X
    BRA .MUL16_LOOP
.MUL16_END:
    LEAS 4,S
    RTS

DIV16:
    ; Divide 16-bit X / D -> D
    ; Simple implementation
    PSHS X,D
    LDD #0         ; Quotient
.DIV16_LOOP:
    PSHS D         ; Save quotient
    LDD 4,S        ; Load dividend (after PSHS D)
    CMPD 2,S       ; Compare with divisor (after PSHS D)
    PULS D         ; Restore quotient
    BLT .DIV16_END
    ADDD #1        ; Increment quotient
    LDX 2,S
    PSHS D
    LDD 2,S        ; Divisor
    LEAX D,X       ; Subtract divisor
    STX 4,S
    PULS D
    BRA .DIV16_LOOP
.DIV16_END:
    LEAS 4,S
    RTS

MOD16:
    ; Modulo 16-bit X % D -> D
    PSHS X,D
.MOD16_LOOP:
    PSHS D         ; Save D
    LDD 4,S        ; Load dividend (after PSHS D)
    CMPD 2,S       ; Compare with divisor (after PSHS D)
    PULS D         ; Restore D
    BLT .MOD16_END
    LDX 2,S
    LDD ,S
    LEAX D,X
    STX 2,S
    BRA .MOD16_LOOP
.MOD16_END:
    LDD 2,S        ; Remainder
    LEAS 4,S
    RTS

; === JOYSTICK BUILTIN SUBROUTINES ===
; J1_X() - Read Joystick 1 X axis (INCREMENTAL - with state preservation)
; Returns: D = raw value from $C81B after Joy_Analog call
J1X_BUILTIN:
    PSHS X       ; Save X (Joy_Analog uses it)
    JSR $F1AA    ; DP_to_D0 (required for Joy_Analog BIOS call)
    JSR $F1F5    ; Joy_Analog (updates $C81B from hardware)
    LDA #$98     ; VIA_cntl = $98 (restore DAC mode for drawing)
    STA $0C      ; Direct page $D00C (VIA_cntl)
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
    LDA #$98     ; VIA_cntl = $98 (restore DAC mode for drawing)
    STA $0C      ; Direct page $D00C (VIA_cntl)
    JSR $F1AF    ; DP_to_C8 (required to read RAM $C81C)
    LDB $C81C    ; Vec_Joy_1_Y (BIOS writes ~$FE at center)
    SEX          ; Sign-extend B to D
    ADDD #2      ; Calibrate center offset
    PULS X       ; Restore X
    RTS

; DRAW_LINE unified wrapper - handles 16-bit signed coordinates
; Args: DRAW_LINE_ARGS+0=x0, +2=y0, +4=x1, +6=y1, +8=intensity
; ALWAYS sets intensity. Does NOT reset origin (allows connected lines).
DRAW_LINE_WRAPPER:
    ; CRITICAL: Set VIA to DAC mode BEFORE calling BIOS (don't assume state)
    LDA #$98       ; VIA_cntl = $98 (DAC mode for vector drawing)
    STA >$D00C     ; VIA_cntl
    ; Set DP to hardware registers
    LDA #$D0
    TFR A,DP
    ; ALWAYS set intensity (no optimization)
    LDA >DRAW_LINE_ARGS+8+1  ; intensity (low byte) - EXTENDED addressing
    JSR Intensity_a
    ; Move to start ONCE (y in A, x in B) - use low bytes (8-bit signed -127..+127)
    LDA >DRAW_LINE_ARGS+2+1  ; Y start (low byte) - EXTENDED addressing
    LDB >DRAW_LINE_ARGS+0+1  ; X start (low byte) - EXTENDED addressing
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
    ; Check if we need SEGMENT 2 (dy outside ±127 range)
    LDD >VLINE_DY_16 ; Reload original dy - EXTENDED
    CMPD #127
    BGT DLW_NEED_SEG2  ; dy > 127: needs segment 2
    CMPD #-128
    BLT DLW_NEED_SEG2  ; dy < -128: needs segment 2
    BRA DLW_DONE       ; dy in range ±127: no segment 2
DLW_NEED_SEG2:
    ; SEGMENT 2: Draw remaining dy and dx
    ; Calculate remaining dy
    LDD >VLINE_DY_16 ; Load original full dy - EXTENDED
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
STX >PSG_MUSIC_PTR      ; Store current music pointer (force extended)
STX >PSG_MUSIC_START    ; Store start pointer for loops (force extended)
CLR >PSG_DELAY_FRAMES   ; Clear delay counter
LDA #$01
STA >PSG_IS_PLAYING     ; Mark as playing (extended - var at 0xC8A0)
PMr_done:
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
STA >PSG_MUSIC_ACTIVE   ; Mark music system active (for PSG logging)
LDA >PSG_IS_PLAYING     ; Check if playing (extended - var at 0xC8A0)
BEQ PSG_update_done     ; Not playing, exit

LDX >PSG_MUSIC_PTR      ; Load pointer (force extended - LDX has no DP mode)
BEQ PSG_update_done     ; No music loaded

; Read frame count byte (number of register writes)
LDB ,X+
BEQ PSG_music_ended     ; Count=0 means end (no loop)
CMPB #$FF               ; Check for loop command
BEQ PSG_music_loop      ; $FF means loop (never valid as count)

; Process frame - push counter to stack
PSHS B                  ; Save count on stack

; Write register/value pairs to PSG
PSG_write_loop:
LDA ,X+                 ; Load register number
LDB ,X+                 ; Load register value
PSHS X                  ; Save pointer (after reads)

; WRITE_PSG sequence
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
DECB                    ; Decrement
BEQ PSG_frame_done      ; Done with this frame
PSHS B                  ; Save counter back
BRA PSG_write_loop

PSG_frame_done:

; Frame complete - update pointer and done
STX >PSG_MUSIC_PTR      ; Update pointer (force extended)
BRA PSG_update_done

PSG_music_ended:
CLR >PSG_IS_PLAYING     ; Stop playback (extended - var at 0xC8A0)
; NOTE: Do NOT write PSG registers here - corrupts VIA for vector drawing
; Music will fade naturally as frame data stops updating
BRA PSG_update_done

PSG_music_loop:
; Loop command: $FF followed by 2-byte address (FDB)
; X points past $FF, read the target address
LDD ,X                  ; Load 2-byte loop target address
STD >PSG_MUSIC_PTR      ; Update pointer to loop start
; Exit - next frame will start from loop target
BRA PSG_update_done

PSG_update_done:
CLR >PSG_MUSIC_ACTIVE   ; Clear flag (music system done)
RTS

; ============================================================================
; STOP_MUSIC_RUNTIME - Stop music playback
; ============================================================================
STOP_MUSIC_RUNTIME:
CLR >PSG_IS_PLAYING     ; Clear playing flag (extended - var at 0xC8A0)
CLR >PSG_MUSIC_PTR      ; Clear pointer high byte (force extended)
CLR >PSG_MUSIC_PTR+1    ; Clear pointer low byte (force extended)
; NOTE: Do NOT write PSG registers here - corrupts VIA for vector drawing
RTS

; ============================================================================
; AUDIO_UPDATE - Unified music + SFX update (auto-injected after WAIT_RECAL)
; ============================================================================
; Processes both music (channel B) and SFX (channel C) in one pass
; Uses Sound_Byte (BIOS) for PSG writes - compatible with both systems
; Sets DP=$D0 once at entry, restores at exit
; RAM variables: PSG_MUSIC_PTR, PSG_IS_PLAYING, PSG_DELAY_FRAMES
;                PSG_MUSIC_BANK (for multibank: bank ID where music data lives)
;                SFX_PTR, SFX_ACTIVE (defined in SYSTEM RAM VARIABLES)

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

sfx_checktonedisable:
LDB ,U                 ; Reload flag byte
BITB #$10              ; Bit 4: disable tone?
BEQ sfx_enabletone
sfx_disabletone:
LDB $C807              ; Read mixer shadow (MUST be B register)
ORB #$04               ; Set bit 2 (disable tone C)
LDA #$07               ; Register 7 (mixer)
JSR Sound_Byte         ; Write to PSG
BRA sfx_checknoisedisable  ; Continue to noise check

sfx_enabletone:
LDB $C807              ; Read mixer shadow (MUST be B register)
ANDB #$FB              ; Clear bit 2 (enable tone C)
LDA #$07               ; Register 7 (mixer)
JSR Sound_Byte         ; Write to PSG

sfx_checknoisedisable:
LDB ,U                 ; Reload flag byte
BITB #$80              ; Bit 7: disable noise?
BEQ sfx_enablenoise
sfx_disablenoise:
LDB $C807              ; Read mixer shadow (MUST be B register)
ORB #$20               ; Set bit 5 (disable noise C)
LDA #$07               ; Register 7 (mixer)
JSR Sound_Byte         ; Write to PSG
BRA sfx_nextframe      ; Done, update pointer

sfx_enablenoise:
LDB $C807              ; Read mixer shadow (MUST be B register)
ANDB #$DF              ; Clear bit 5 (enable noise C)
LDA #$07               ; Register 7 (mixer)
JSR Sound_Byte         ; Write to PSG

sfx_nextframe:
STY >SFX_PTR            ; Update pointer for next frame
RTS

sfx_endofeffect:
; Stop SFX - set volume to 0
CLR >SFX_ACTIVE         ; Mark as inactive
LDA #$0A                ; Register 10 (volume C)
LDB #$00                ; Volume = 0
JSR Sound_Byte
LDD #$0000
STD >SFX_PTR            ; Clear pointer
RTS

;**** PRINT_TEXT String Data ****
PRINT_TEXT_STR_103315:
    FCC "hit"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_107868:
    FCC "map"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3208483:
    FCC "hook"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3327403:
    FCC "logo"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_102743755:
    FCC "laser"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3413815335:
    FCC "taj_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_93976101846:
    FCC "fuji_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2382167728733:
    FCC "TO START"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2779111860214:
    FCC "ayers_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3088519875410:
    FCC "mayan_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3170864850809:
    FCC "paris_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_62529178322969:
    FCC "GET READY"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_85851400383728:
    FCC "angkor_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_86017190903439:
    FCC "athens_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_86894009833752:
    FCC "buddha_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_88916199021370:
    FCC "easter_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_94134666982268:
    FCC "keirin_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_95266726412236:
    FCC "london_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_95736077158694:
    FCC "map_theme"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2997885107879189:
    FCC "newyork_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3047088743154868:
    FCC "pang_theme"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_83503386307659390:
    FCC "bubble_huge"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_95097560564962529:
    FCC "pyramids_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2572636110730664281:
    FCC "barcelona_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2588604975540550088:
    FCC "bubble_large"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2588604975547356052:
    FCC "bubble_small"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2829898994950197404:
    FCC "leningrad_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2984064007298942493:
    FCC "fuji_level1_v2"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_4990555610362249649:
    FCC "kilimanjaro_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_5508987775272975622:
    FCC "antarctica_bg"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_6459777946950754952:
    FCC "bubble_medium"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_9120385685437879118:
    FCC "PRESS A BUTTON"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17258163498655081049:
    FCC "player_walk_1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17258163498655081050:
    FCC "player_walk_2"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17258163498655081051:
    FCC "player_walk_3"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17258163498655081052:
    FCC "player_walk_4"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17258163498655081053:
    FCC "player_walk_5"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17852485805690375172:
    FCC "location_marker"
    FCB $80          ; Vectrex string terminator



;***************************************************************************
; INTERRUPT VECTORS (Bank #31 Fixed Window)
;***************************************************************************
ORG $FFFE
FDB CUSTOM_RESET
