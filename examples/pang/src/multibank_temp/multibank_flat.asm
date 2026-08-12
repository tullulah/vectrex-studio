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
    LDX #Vec_Default_Stk ; Same stack as BIOS default ($CBEA)
    TFR X,S
    JSR $F533        ; Init_Music_Buf: init BIOS sound work buffer at Vec_Default_Stk
    LDS #$CFFF       ; Stack -> top of Vectrex 2KB RAM (avoids user var collision)

    ; Initialize bank tracking vars to 0 (prevents spurious $DF00 writes)
    LDA #0
    STA >CURRENT_ROM_BANK   ; Bank 0 is always active at boot
    CLR >LEVEL_LOADED       ; No level loaded yet (flag, not a pointer)
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
MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    ; Init camera ONCE at boot (RAM not zero-init). LOAD_LEVEL must NOT
    ; reset it (matches pitrex): the game sets it via SET_CAMERA_Y before
    ; LOAD_LEVEL/SPAWN, and GET_LEVEL_FLOOR_Y / the spawn Y-filter read it.
    LDD #0
    STD >CAMERA_X
    STD >CAMERA_Y
    LDA #$F8
    STA TEXT_SCALE_H      ; Default height = -8 (normal size)
    LDA #$48
    STA TEXT_SCALE_W      ; Default width = 72 (normal size)
    LDA #$7F
    STA DRAW_SCALE        ; Default T1 scale = $7F (127 = full BIOS scale)
    LDD #0  ; const STATE_TITLE
    STD VAR_SCREEN
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
    STD VAR_PREV_BTN1
    LDD #0
    STD VAR_PREV_BTN2
    LDD #0
    STD VAR_PREV_BTN3
    LDD #0
    STD VAR_PREV_BTN4
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
; VPy_LINE:88
    LDD #0
    STD VAR_CURRENT_LOCATION
; VPy_LINE:89
    LDD #0
    STD VAR_PREV_JOY_X
; VPy_LINE:90
    LDD #0
    STD VAR_PREV_JOY_Y
; VPy_LINE:91
    LDD #80
    STD VAR_LOCATION_GLOW_INTENSITY
; VPy_LINE:92
    LDD #0
    STD VAR_LOCATION_GLOW_DIRECTION
; VPy_LINE:93
    LDD #0  ; const STATE_TITLE
    STD VAR_SCREEN
; VPy_LINE:96
    LDD #0
    STD VAR_COUNTDOWN_TIMER
; VPy_LINE:97
    LDD #0
    STD VAR_COUNTDOWN_ACTIVE
; VPy_LINE:100
    LDD #0
    STD VAR_HOOK_ACTIVE
; VPy_LINE:101
    LDD #0
    STD VAR_HOOK_X
; VPy_LINE:102
    LDD #-70
    STD VAR_HOOK_Y
; VPy_LINE:105
    LDD #0
    STD VAR_JOYSTICK_POLL_COUNTER
; VPy_LINE:106
    LDD #0
    STD VAR_PREV_BTN1
; VPy_LINE:107
    LDD #0
    STD VAR_PREV_BTN2
; VPy_LINE:108
    LDD #0
    STD VAR_PREV_BTN3
; VPy_LINE:109
    LDD #0
    STD VAR_PREV_BTN4

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
; VPy_LINE:113
    JSR read_joystick1_state
; VPy_LINE:115
    LDD >VAR_SCREEN
    CMPD #0
    LBNE IF_NEXT_1
; VPy_LINE:116
    LDD >VAR_CURRENT_MUSIC
    CMPD #-1
    LBNE IF_NEXT_3
; VPy_LINE:117
; NATIVE_CALL: PLAY_MUSIC at line 117
    ; PLAY_MUSIC("pang_theme") - play music asset (index=1)
    LDX #1        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
; VPy_LINE:118
    LDD #0
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
; VPy_LINE:120
    JSR draw_title_screen
; VPy_LINE:123
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    LBEQ .LOGIC_0_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_BTN1
    CMPD TMPVAL
    LBEQ .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    LBEQ .LOGIC_0_FALSE
    LDD #1
    LBRA .LOGIC_0_END
.LOGIC_0_FALSE:
    LDD #0
.LOGIC_0_END:
    LBEQ IF_NEXT_5
; VPy_LINE:124
    LDD #1  ; const STATE_MAP
    STD VAR_SCREEN
; VPy_LINE:125
    LDD #-1
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_4
IF_NEXT_5:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_4_TRUE
    LDD #0
    LBRA .CMP_4_END
.CMP_4_TRUE:
    LDD #1
.CMP_4_END:
    LBEQ .LOGIC_3_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_BTN2
    CMPD TMPVAL
    LBEQ .CMP_5_TRUE
    LDD #0
    LBRA .CMP_5_END
.CMP_5_TRUE:
    LDD #1
.CMP_5_END:
    LBEQ .LOGIC_3_FALSE
    LDD #1
    LBRA .LOGIC_3_END
.LOGIC_3_FALSE:
    LDD #0
.LOGIC_3_END:
    LBEQ IF_NEXT_6
; VPy_LINE:128
    LDD #1  ; const STATE_MAP
    STD VAR_SCREEN
; VPy_LINE:129
    LDD #-1
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_4
IF_NEXT_6:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #4
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_7_TRUE
    LDD #0
    LBRA .CMP_7_END
.CMP_7_TRUE:
    LDD #1
.CMP_7_END:
    LBEQ .LOGIC_6_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_BTN3
    CMPD TMPVAL
    LBEQ .CMP_8_TRUE
    LDD #0
    LBRA .CMP_8_END
.CMP_8_TRUE:
    LDD #1
.CMP_8_END:
    LBEQ .LOGIC_6_FALSE
    LDD #1
    LBRA .LOGIC_6_END
.LOGIC_6_FALSE:
    LDD #0
.LOGIC_6_END:
    LBEQ IF_NEXT_7
; VPy_LINE:132
    LDD #1  ; const STATE_MAP
    STD VAR_SCREEN
; VPy_LINE:133
    LDD #-1
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_4
IF_NEXT_7:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #5
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_10_TRUE
    LDD #0
    LBRA .CMP_10_END
.CMP_10_TRUE:
    LDD #1
.CMP_10_END:
    LBEQ .LOGIC_9_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_BTN4
    CMPD TMPVAL
    LBEQ .CMP_11_TRUE
    LDD #0
    LBRA .CMP_11_END
.CMP_11_TRUE:
    LDD #1
.CMP_11_END:
    LBEQ .LOGIC_9_FALSE
    LDD #1
    LBRA .LOGIC_9_END
.LOGIC_9_FALSE:
    LDD #0
.LOGIC_9_END:
    LBEQ IF_END_4
; VPy_LINE:136
    LDD #1  ; const STATE_MAP
    STD VAR_SCREEN
; VPy_LINE:137
    LDD #-1
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_4
IF_END_4:
    LBRA IF_END_0
IF_NEXT_1:
    LDD >VAR_SCREEN
    CMPD #1
    LBNE IF_NEXT_8
; VPy_LINE:141
    LDD >VAR_CURRENT_MUSIC
    CMPD #1
    LBEQ IF_NEXT_10
; VPy_LINE:142
; NATIVE_CALL: PLAY_MUSIC at line 142
    ; PLAY_MUSIC("map_theme") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
; VPy_LINE:143
    LDD #1
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_9
IF_NEXT_10:
IF_END_9:
; VPy_LINE:146
    LDD >VAR_JOYSTICK_POLL_COUNTER
    STD TMPVAL          ; Save left operand
    LDD #1
    ADDD TMPVAL         ; D = D + TMPVAL
    STD VAR_JOYSTICK_POLL_COUNTER
; VPy_LINE:147
    LDD #15
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOYSTICK_POLL_COUNTER
    CMPD TMPVAL
    LBGE .CMP_12_TRUE
    LDD #0
    LBRA .CMP_12_END
.CMP_12_TRUE:
    LDD #1
.CMP_12_END:
    LBEQ IF_NEXT_12
; VPy_LINE:148
    LDD #0
    STD VAR_JOYSTICK_POLL_COUNTER
; VPy_LINE:149
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_JOY_X
; VPy_LINE:150
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_JOY_Y
    LBRA IF_END_11
IF_NEXT_12:
IF_END_11:
; VPy_LINE:154
    LDD #40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBGT .CMP_14_TRUE
    LDD #0
    LBRA .CMP_14_END
.CMP_14_TRUE:
    LDD #1
.CMP_14_END:
    LBEQ .LOGIC_13_FALSE
    LDD #40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_JOY_X
    CMPD TMPVAL
    LBLE .CMP_15_TRUE
    LDD #0
    LBRA .CMP_15_END
.CMP_15_TRUE:
    LDD #1
.CMP_15_END:
    LBEQ .LOGIC_13_FALSE
    LDD #1
    LBRA .LOGIC_13_END
.LOGIC_13_FALSE:
    LDD #0
.LOGIC_13_END:
    LBEQ IF_NEXT_14
; VPy_LINE:155
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_CURRENT_LOCATION
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_CURRENT_LOCATION
; VPy_LINE:156
    LDD #17  ; const num_locations
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LOCATION
    CMPD TMPVAL
    LBGE .CMP_16_TRUE
    LDD #0
    LBRA .CMP_16_END
.CMP_16_TRUE:
    LDD #1
.CMP_16_END:
    LBEQ IF_NEXT_16
; VPy_LINE:157
    LDD #0
    STD VAR_CURRENT_LOCATION
; VPy_LINE:158
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'fuji_level1_v2'
    ; Level asset index: 0 (multibank)
    LDX #0
    JSR LOAD_LEVEL_BANKED
    LBRA IF_END_15
IF_NEXT_16:
IF_END_15:
    LBRA IF_END_13
IF_NEXT_14:
    LDD #-40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBLT .CMP_18_TRUE
    LDD #0
    LBRA .CMP_18_END
.CMP_18_TRUE:
    LDD #1
.CMP_18_END:
    LBEQ .LOGIC_17_FALSE
    LDD #-40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_JOY_X
    CMPD TMPVAL
    LBGE .CMP_19_TRUE
    LDD #0
    LBRA .CMP_19_END
.CMP_19_TRUE:
    LDD #1
.CMP_19_END:
    LBEQ .LOGIC_17_FALSE
    LDD #1
    LBRA .LOGIC_17_END
.LOGIC_17_FALSE:
    LDD #0
.LOGIC_17_END:
    LBEQ IF_NEXT_17
; VPy_LINE:160
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_CURRENT_LOCATION
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_CURRENT_LOCATION
; VPy_LINE:161
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LOCATION
    CMPD TMPVAL
    LBLT .CMP_20_TRUE
    LDD #0
    LBRA .CMP_20_END
.CMP_20_TRUE:
    LDD #1
.CMP_20_END:
    LBEQ IF_NEXT_19
; VPy_LINE:162
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #17  ; const num_locations
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_CURRENT_LOCATION
    LBRA IF_END_18
IF_NEXT_19:
IF_END_18:
    LBRA IF_END_13
IF_NEXT_17:
    LDD #40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_Y
    CMPD TMPVAL
    LBGT .CMP_22_TRUE
    LDD #0
    LBRA .CMP_22_END
.CMP_22_TRUE:
    LDD #1
.CMP_22_END:
    LBEQ .LOGIC_21_FALSE
    LDD #40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_JOY_Y
    CMPD TMPVAL
    LBLE .CMP_23_TRUE
    LDD #0
    LBRA .CMP_23_END
.CMP_23_TRUE:
    LDD #1
.CMP_23_END:
    LBEQ .LOGIC_21_FALSE
    LDD #1
    LBRA .LOGIC_21_END
.LOGIC_21_FALSE:
    LDD #0
.LOGIC_21_END:
    LBEQ IF_NEXT_20
; VPy_LINE:164
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_CURRENT_LOCATION
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_CURRENT_LOCATION
; VPy_LINE:165
    LDD #17  ; const num_locations
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LOCATION
    CMPD TMPVAL
    LBGE .CMP_24_TRUE
    LDD #0
    LBRA .CMP_24_END
.CMP_24_TRUE:
    LDD #1
.CMP_24_END:
    LBEQ IF_NEXT_22
; VPy_LINE:166
    LDD #0
    STD VAR_CURRENT_LOCATION
    LBRA IF_END_21
IF_NEXT_22:
IF_END_21:
    LBRA IF_END_13
IF_NEXT_20:
    LDD #-40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_Y
    CMPD TMPVAL
    LBLT .CMP_26_TRUE
    LDD #0
    LBRA .CMP_26_END
.CMP_26_TRUE:
    LDD #1
.CMP_26_END:
    LBEQ .LOGIC_25_FALSE
    LDD #-40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_JOY_Y
    CMPD TMPVAL
    LBGE .CMP_27_TRUE
    LDD #0
    LBRA .CMP_27_END
.CMP_27_TRUE:
    LDD #1
.CMP_27_END:
    LBEQ .LOGIC_25_FALSE
    LDD #1
    LBRA .LOGIC_25_END
.LOGIC_25_FALSE:
    LDD #0
.LOGIC_25_END:
    LBEQ IF_END_13
; VPy_LINE:168
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_CURRENT_LOCATION
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_CURRENT_LOCATION
; VPy_LINE:169
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_LOCATION
    CMPD TMPVAL
    LBLT .CMP_28_TRUE
    LDD #0
    LBRA .CMP_28_END
.CMP_28_TRUE:
    LDD #1
.CMP_28_END:
    LBEQ IF_NEXT_24
; VPy_LINE:170
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #17  ; const num_locations
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_CURRENT_LOCATION
    LBRA IF_END_23
IF_NEXT_24:
IF_END_23:
    LBRA IF_END_13
IF_END_13:
; VPy_LINE:172
    LDD >VAR_JOY_X
    STD VAR_PREV_JOY_X
; VPy_LINE:173
    LDD >VAR_JOY_Y
    STD VAR_PREV_JOY_Y
; VPy_LINE:176
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_30_TRUE
    LDD #0
    LBRA .CMP_30_END
.CMP_30_TRUE:
    LDD #1
.CMP_30_END:
    LBEQ .LOGIC_29_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_BTN1
    CMPD TMPVAL
    LBEQ .CMP_31_TRUE
    LDD #0
    LBRA .CMP_31_END
.CMP_31_TRUE:
    LDD #1
.CMP_31_END:
    LBEQ .LOGIC_29_FALSE
    LDD #1
    LBRA .LOGIC_29_END
.LOGIC_29_FALSE:
    LDD #0
.LOGIC_29_END:
    LBEQ IF_NEXT_26
; VPy_LINE:177
    LDD #2  ; const STATE_GAME
    STD VAR_SCREEN
; VPy_LINE:178
    LDD #1
    STD VAR_COUNTDOWN_ACTIVE
; VPy_LINE:179
    LDD #180
    STD VAR_COUNTDOWN_TIMER
    LBRA IF_END_25
IF_NEXT_26:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_33_TRUE
    LDD #0
    LBRA .CMP_33_END
.CMP_33_TRUE:
    LDD #1
.CMP_33_END:
    LBEQ .LOGIC_32_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_BTN2
    CMPD TMPVAL
    LBEQ .CMP_34_TRUE
    LDD #0
    LBRA .CMP_34_END
.CMP_34_TRUE:
    LDD #1
.CMP_34_END:
    LBEQ .LOGIC_32_FALSE
    LDD #1
    LBRA .LOGIC_32_END
.LOGIC_32_FALSE:
    LDD #0
.LOGIC_32_END:
    LBEQ IF_NEXT_27
; VPy_LINE:182
    LDD #2  ; const STATE_GAME
    STD VAR_SCREEN
; VPy_LINE:183
    LDD #1
    STD VAR_COUNTDOWN_ACTIVE
; VPy_LINE:184
    LDD #180
    STD VAR_COUNTDOWN_TIMER
    LBRA IF_END_25
IF_NEXT_27:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #4
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_36_TRUE
    LDD #0
    LBRA .CMP_36_END
.CMP_36_TRUE:
    LDD #1
.CMP_36_END:
    LBEQ .LOGIC_35_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_BTN3
    CMPD TMPVAL
    LBEQ .CMP_37_TRUE
    LDD #0
    LBRA .CMP_37_END
.CMP_37_TRUE:
    LDD #1
.CMP_37_END:
    LBEQ .LOGIC_35_FALSE
    LDD #1
    LBRA .LOGIC_35_END
.LOGIC_35_FALSE:
    LDD #0
.LOGIC_35_END:
    LBEQ IF_NEXT_28
; VPy_LINE:187
    LDD #2  ; const STATE_GAME
    STD VAR_SCREEN
; VPy_LINE:188
    LDD #1
    STD VAR_COUNTDOWN_ACTIVE
; VPy_LINE:189
    LDD #180
    STD VAR_COUNTDOWN_TIMER
    LBRA IF_END_25
IF_NEXT_28:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #5
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_39_TRUE
    LDD #0
    LBRA .CMP_39_END
.CMP_39_TRUE:
    LDD #1
.CMP_39_END:
    LBEQ .LOGIC_38_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_BTN4
    CMPD TMPVAL
    LBEQ .CMP_40_TRUE
    LDD #0
    LBRA .CMP_40_END
.CMP_40_TRUE:
    LDD #1
.CMP_40_END:
    LBEQ .LOGIC_38_FALSE
    LDD #1
    LBRA .LOGIC_38_END
.LOGIC_38_FALSE:
    LDD #0
.LOGIC_38_END:
    LBEQ IF_END_25
; VPy_LINE:192
    LDD #2  ; const STATE_GAME
    STD VAR_SCREEN
; VPy_LINE:193
    LDD #1
    STD VAR_COUNTDOWN_ACTIVE
; VPy_LINE:194
    LDD #180
    STD VAR_COUNTDOWN_TIMER
    LBRA IF_END_25
IF_END_25:
; VPy_LINE:197
    JSR draw_map_screen
    LBRA IF_END_0
IF_NEXT_8:
    LDD >VAR_SCREEN
    CMPD #2
    LBNE IF_END_0
; VPy_LINE:201
    LDD >VAR_COUNTDOWN_ACTIVE
    CMPD #1
    LBNE IF_NEXT_30
; VPy_LINE:203
    JSR draw_level_background
; VPy_LINE:205
; NATIVE_CALL: SET_INTENSITY at line 205
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:206
; NATIVE_CALL: PRINT_TEXT at line 206
    ; PRINT_TEXT: Print text at position
    LDD #-50
    STD >VAR_ARG0
    LDD #0
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_62529178322969      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:209
; NATIVE_CALL: SET_INTENSITY at line 209
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:210
; NATIVE_CALL: PRINT_TEXT at line 210
    ; PRINT_TEXT: Print text at position
    LDD #-85
    STD >VAR_ARG0
    LDD #-20
    STD >VAR_ARG1
    LDX #ARRAY_LOCATION_NAMES_DATA  ; Array base
    LDD >VAR_CURRENT_LOCATION
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:213
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_COUNTDOWN_TIMER
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_COUNTDOWN_TIMER
; VPy_LINE:216
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_COUNTDOWN_TIMER
    CMPD TMPVAL
    LBLE .CMP_41_TRUE
    LDD #0
    LBRA .CMP_41_END
.CMP_41_TRUE:
    LDD #1
.CMP_41_END:
    LBEQ IF_NEXT_32
; VPy_LINE:217
    LDD #0
    STD VAR_COUNTDOWN_ACTIVE
; VPy_LINE:218
    JSR init_bubbles
    LBRA IF_END_31
IF_NEXT_32:
IF_END_31:
    LBRA IF_END_29
IF_NEXT_30:
; VPy_LINE:223
    LDD >VAR_HOOK_ACTIVE
    CMPD #0
    LBNE IF_NEXT_34
; VPy_LINE:224
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_45_TRUE
    LDD #0
    LBRA .CMP_45_END
.CMP_45_TRUE:
    LDD #1
.CMP_45_END:
    LBNE .LOGIC_44_TRUE
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_46_TRUE
    LDD #0
    LBRA .CMP_46_END
.CMP_46_TRUE:
    LDD #1
.CMP_46_END:
    LBNE .LOGIC_44_TRUE
    LDD #0
    LBRA .LOGIC_44_END
.LOGIC_44_TRUE:
    LDD #1
.LOGIC_44_END:
    LBNE .LOGIC_43_TRUE
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #4
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_47_TRUE
    LDD #0
    LBRA .CMP_47_END
.CMP_47_TRUE:
    LDD #1
.CMP_47_END:
    LBNE .LOGIC_43_TRUE
    LDD #0
    LBRA .LOGIC_43_END
.LOGIC_43_TRUE:
    LDD #1
.LOGIC_43_END:
    LBNE .LOGIC_42_TRUE
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #5
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_48_TRUE
    LDD #0
    LBRA .CMP_48_END
.CMP_48_TRUE:
    LDD #1
.CMP_48_END:
    LBNE .LOGIC_42_TRUE
    LDD #0
    LBRA .LOGIC_42_END
.LOGIC_42_TRUE:
    LDD #1
.LOGIC_42_END:
    LBEQ IF_NEXT_36
; VPy_LINE:225
    LDD #1
    STD VAR_HOOK_ACTIVE
; VPy_LINE:226
    LDD #-70
    STD VAR_HOOK_Y
; VPy_LINE:230
    LDD >VAR_PLAYER_X
    STD VAR_HOOK_GUN_X
; VPy_LINE:231
    LDD >VAR_PLAYER_FACING
    CMPD #1
    LBNE IF_NEXT_38
; VPy_LINE:232
    LDD #11
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_HOOK_GUN_X
    LBRA IF_END_37
IF_NEXT_38:
; VPy_LINE:234
    LDD #11
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_HOOK_GUN_X
IF_END_37:
; VPy_LINE:235
    LDD #3
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-70  ; const player_y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_HOOK_GUN_Y
; VPy_LINE:236
    LDD >VAR_HOOK_GUN_Y
    STD VAR_HOOK_INIT_Y
; VPy_LINE:239
    LDD >VAR_HOOK_GUN_X
    STD VAR_HOOK_X
    LBRA IF_END_35
IF_NEXT_36:
IF_END_35:
    LBRA IF_END_33
IF_NEXT_34:
IF_END_33:
; VPy_LINE:242
    LDD >VAR_HOOK_ACTIVE
    CMPD #1
    LBNE IF_NEXT_40
; VPy_LINE:243
    LDD #3
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_HOOK_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_HOOK_Y
; VPy_LINE:246
    LDD #127  ; const hook_max_y
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_HOOK_Y
    CMPD TMPVAL
    LBGE .CMP_49_TRUE
    LDD #0
    LBRA .CMP_49_END
.CMP_49_TRUE:
    LDD #1
.CMP_49_END:
    LBEQ IF_NEXT_42
; VPy_LINE:247
    LDD #0
    STD VAR_HOOK_ACTIVE
; VPy_LINE:248
    LDD #-70
    STD VAR_HOOK_Y
    LBRA IF_END_41
IF_NEXT_42:
IF_END_41:
    LBRA IF_END_39
IF_NEXT_40:
IF_END_39:
; VPy_LINE:250
    JSR draw_game_level
IF_END_29:
    LBRA IF_END_0
IF_END_0:
; VPy_LINE:253
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_PREV_BTN1
; VPy_LINE:254
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_PREV_BTN2
; VPy_LINE:255
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #4
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_PREV_BTN3
; VPy_LINE:256
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #5
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_PREV_BTN4
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX (after all game logic)
    RTS

; Function: draw_map_screen (Bank #0)
draw_map_screen:
; VPy_LINE:260
; NATIVE_CALL: SET_INTENSITY at line 260
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:261
; NATIVE_CALL: DRAW_VECTOR_EX at line 261
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: map (index=19, 15 paths) with mirror + intensity
    LDD #0
    TFR B,A       ; X position (low byte) — B already holds it
    STA DRAW_VEC_X
    LDD #20
    TFR B,A       ; Y position (low byte) — B already holds it
    STA DRAW_VEC_Y
    LDD #0
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
    TFR B,A       ; Intensity (0-127) — B already holds it
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    LDX #19        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
; VPy_LINE:264
    LDD >VAR_LOCATION_GLOW_DIRECTION
    CMPD #0
    LBNE IF_NEXT_44
; VPy_LINE:265
    LDD #3
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_LOCATION_GLOW_INTENSITY
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_LOCATION_GLOW_INTENSITY
; VPy_LINE:266
    LDD #127
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_LOCATION_GLOW_INTENSITY
    CMPD TMPVAL
    LBGE .CMP_50_TRUE
    LDD #0
    LBRA .CMP_50_END
.CMP_50_TRUE:
    LDD #1
.CMP_50_END:
    LBEQ IF_NEXT_46
; VPy_LINE:267
    LDD #1
    STD VAR_LOCATION_GLOW_DIRECTION
    LBRA IF_END_45
IF_NEXT_46:
IF_END_45:
    LBRA IF_END_43
IF_NEXT_44:
; VPy_LINE:269
    LDD #3
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_LOCATION_GLOW_INTENSITY
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_LOCATION_GLOW_INTENSITY
; VPy_LINE:270
    LDD #80
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_LOCATION_GLOW_INTENSITY
    CMPD TMPVAL
    LBLE .CMP_51_TRUE
    LDD #0
    LBRA .CMP_51_END
.CMP_51_TRUE:
    LDD #1
.CMP_51_END:
    LBEQ IF_NEXT_48
; VPy_LINE:271
    LDD #0
    STD VAR_LOCATION_GLOW_DIRECTION
    LBRA IF_END_47
IF_NEXT_48:
IF_END_47:
IF_END_43:
; VPy_LINE:273
; NATIVE_CALL: PRINT_TEXT at line 273
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD >VAR_ARG0
    LDD #-80
    STD >VAR_ARG1
    LDX #ARRAY_LOCATION_NAMES_DATA  ; Array base
    LDD >VAR_CURRENT_LOCATION
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:276
    LDX #ARRAY_LOCATION_X_COORDS_DATA  ; Array base
    LDD >VAR_CURRENT_LOCATION
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_LOC_X
; VPy_LINE:277
    LDX #ARRAY_LOCATION_Y_COORDS_DATA  ; Array base
    LDD >VAR_CURRENT_LOCATION
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_LOC_Y
; VPy_LINE:279
; NATIVE_CALL: DRAW_VECTOR_EX at line 279
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: location_marker (index=16, 1 paths) with mirror + intensity
    LDD >VAR_LOC_Y
    TFR B,A       ; X position (low byte) — B already holds it
    STA DRAW_VEC_X
    LDD >VAR_LOC_X
    TFR B,A       ; Y position (low byte) — B already holds it
    STA DRAW_VEC_Y
    LDD #0
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
    LDD >VAR_LOCATION_GLOW_INTENSITY
    TFR B,A       ; Intensity (0-127) — B already holds it
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    LDX #16        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    RTS

; Function: draw_title_screen (Bank #0)
draw_title_screen:
; VPy_LINE:284
; NATIVE_CALL: SET_INTENSITY at line 284
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:285
; NATIVE_CALL: DRAW_VECTOR at line 285
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: logo (index=17, 7 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_2          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #70
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #17        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_2:
    LDD #0
    STD RESULT
; VPy_LINE:287
; NATIVE_CALL: SET_INTENSITY at line 287
    ; SET_INTENSITY: Set drawing intensity
    LDD >VAR_TITLE_INTENSITY
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:288
; NATIVE_CALL: PRINT_TEXT at line 288
    ; PRINT_TEXT: Print text at position
    LDD #-90
    STD >VAR_ARG0
    LDD #0
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_9120385685437879118      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:289
; NATIVE_CALL: PRINT_TEXT at line 289
    ; PRINT_TEXT: Print text at position
    LDD #-50
    STD >VAR_ARG0
    LDD #-20
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2382167728733      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:291
    LDD >VAR_TITLE_STATE
    CMPD #0
    LBNE IF_NEXT_50
; VPy_LINE:292
    LDD >VAR_TITLE_INTENSITY
    STD TMPVAL          ; Save left operand
    LDD #1
    ADDD TMPVAL         ; D = D + TMPVAL
    STD VAR_TITLE_INTENSITY
    LBRA IF_END_49
IF_NEXT_50:
IF_END_49:
; VPy_LINE:294
    LDD >VAR_TITLE_STATE
    CMPD #1
    LBNE IF_NEXT_52
; VPy_LINE:295
    LDD >VAR_TITLE_INTENSITY
    STD TMPVAL          ; Save left operand
    LDD #1
    STD TMPPTR          ; Save right operand
    LDD TMPVAL          ; Get left operand
    SUBD TMPPTR         ; D = left - right
    STD VAR_TITLE_INTENSITY
    LBRA IF_END_51
IF_NEXT_52:
IF_END_51:
; VPy_LINE:297
    LDD >VAR_TITLE_INTENSITY
    CMPD #80
    LBNE IF_NEXT_54
; VPy_LINE:298
    LDD #1
    STD VAR_TITLE_STATE
    LBRA IF_END_53
IF_NEXT_54:
IF_END_53:
; VPy_LINE:300
    LDD >VAR_TITLE_INTENSITY
    CMPD #30
    LBNE IF_NEXT_56
; VPy_LINE:301
    LDD #0
    STD VAR_TITLE_STATE
    LBRA IF_END_55
IF_NEXT_56:
IF_END_55:
    RTS

; Function: draw_level_background (Bank #0)
draw_level_background:
; VPy_LINE:305
; NATIVE_CALL: SET_INTENSITY at line 305
    ; SET_INTENSITY: Set drawing intensity
    LDD #60
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:308
    LDD >VAR_CURRENT_LOCATION
    CMPD #0
    LBNE IF_NEXT_58
; VPy_LINE:309
; NATIVE_CALL: DRAW_VECTOR at line 309
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: fuji_bg (index=11, 5 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_3          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #11        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_3:
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_58:
    LDD >VAR_CURRENT_LOCATION
    CMPD #1
    LBNE IF_NEXT_59
; VPy_LINE:311
; NATIVE_CALL: DRAW_VECTOR at line 311
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: keirin_bg (index=13, 3 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_4          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #13        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_4:
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_59:
    LDD >VAR_CURRENT_LOCATION
    CMPD #2
    LBNE IF_NEXT_60
; VPy_LINE:313
; NATIVE_CALL: DRAW_VECTOR at line 313
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: buddha_bg (index=9, 4 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_5          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #9        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_5:
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_60:
    LDD >VAR_CURRENT_LOCATION
    CMPD #3
    LBNE IF_NEXT_61
; VPy_LINE:315
; NATIVE_CALL: DRAW_VECTOR at line 315
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: angkor_bg (index=0, 170 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_6          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #0        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_6:
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_61:
    LDD >VAR_CURRENT_LOCATION
    CMPD #4
    LBNE IF_NEXT_62
; VPy_LINE:317
; NATIVE_CALL: DRAW_VECTOR at line 317
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: ayers_bg (index=3, 18 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_7          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #3        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_7:
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_62:
    LDD >VAR_CURRENT_LOCATION
    CMPD #5
    LBNE IF_NEXT_63
; VPy_LINE:319
; NATIVE_CALL: DRAW_VECTOR at line 319
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: taj_bg (index=29, 4 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_8          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #29        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_8:
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_63:
    LDD >VAR_CURRENT_LOCATION
    CMPD #6
    LBNE IF_NEXT_64
; VPy_LINE:321
; NATIVE_CALL: DRAW_VECTOR at line 321
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: leningrad_bg (index=15, 5 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_9          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #15        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_9:
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_64:
    LDD >VAR_CURRENT_LOCATION
    CMPD #7
    LBNE IF_NEXT_65
; VPy_LINE:323
; NATIVE_CALL: DRAW_VECTOR at line 323
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: paris_bg (index=22, 5 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_10          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #22        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_10:
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_65:
    LDD >VAR_CURRENT_LOCATION
    CMPD #8
    LBNE IF_NEXT_66
; VPy_LINE:325
; NATIVE_CALL: DRAW_VECTOR at line 325
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: london_bg (index=18, 4 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_11          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #18        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_11:
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_66:
    LDD >VAR_CURRENT_LOCATION
    CMPD #9
    LBNE IF_NEXT_67
; VPy_LINE:327
; NATIVE_CALL: DRAW_VECTOR at line 327
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: barcelona_bg (index=4, 50 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_12          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #4        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_12:
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_67:
    LDD >VAR_CURRENT_LOCATION
    CMPD #10
    LBNE IF_NEXT_68
; VPy_LINE:329
; NATIVE_CALL: DRAW_VECTOR at line 329
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: athens_bg (index=2, 33 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_13          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #2        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_13:
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_68:
    LDD >VAR_CURRENT_LOCATION
    CMPD #11
    LBNE IF_NEXT_69
; VPy_LINE:331
; NATIVE_CALL: DRAW_VECTOR at line 331
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: pyramids_bg (index=28, 4 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_14          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #28        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_14:
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_69:
    LDD >VAR_CURRENT_LOCATION
    CMPD #12
    LBNE IF_NEXT_70
; VPy_LINE:333
; NATIVE_CALL: DRAW_VECTOR at line 333
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: kilimanjaro_bg (index=14, 4 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_15          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #14        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_15:
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_70:
    LDD >VAR_CURRENT_LOCATION
    CMPD #13
    LBNE IF_NEXT_71
; VPy_LINE:335
; NATIVE_CALL: DRAW_VECTOR at line 335
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: newyork_bg (index=21, 5 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_16          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #21        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_16:
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_71:
    LDD >VAR_CURRENT_LOCATION
    CMPD #14
    LBNE IF_NEXT_72
; VPy_LINE:337
; NATIVE_CALL: DRAW_VECTOR at line 337
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: mayan_bg (index=20, 5 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_17          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #20        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_17:
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_72:
    LDD >VAR_CURRENT_LOCATION
    CMPD #15
    LBNE IF_NEXT_73
; VPy_LINE:339
; NATIVE_CALL: DRAW_VECTOR at line 339
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: antarctica_bg (index=1, 19 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_18          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #1        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_18:
    LDD #0
    STD RESULT
    LBRA IF_END_57
IF_NEXT_73:
; VPy_LINE:341
; NATIVE_CALL: DRAW_VECTOR at line 341
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: easter_bg (index=10, 5 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_19          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #50
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #10        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_19:
    LDD #0
    STD RESULT
IF_END_57:
    RTS

; Function: draw_game_level (Bank #0)
draw_game_level:
; VPy_LINE:345
    JSR draw_level_background
; VPy_LINE:348
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_JOY_X
; VPy_LINE:352
    LDD #-20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBLT .CMP_53_TRUE
    LDD #0
    LBRA .CMP_53_END
.CMP_53_TRUE:
    LDD #1
.CMP_53_END:
    LBNE .LOGIC_52_TRUE
    LDD #20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBGT .CMP_54_TRUE
    LDD #0
    LBRA .CMP_54_END
.CMP_54_TRUE:
    LDD #1
.CMP_54_END:
    LBNE .LOGIC_52_TRUE
    LDD #0
    LBRA .LOGIC_52_END
.LOGIC_52_TRUE:
    LDD #1
.LOGIC_52_END:
    LBEQ IF_NEXT_75
; VPy_LINE:355
    LDD >VAR_JOY_X
    STD VAR_ABS_JOY
; VPy_LINE:356
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ABS_JOY
    CMPD TMPVAL
    LBLT .CMP_55_TRUE
    LDD #0
    LBRA .CMP_55_END
.CMP_55_TRUE:
    LDD #1
.CMP_55_END:
    LBEQ IF_NEXT_77
; VPy_LINE:357
    LDD >VAR_ABS_JOY
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD VAR_ABS_JOY
    LBRA IF_END_76
IF_NEXT_77:
IF_END_76:
; VPy_LINE:362
    LDD #40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ABS_JOY
    CMPD TMPVAL
    LBLT .CMP_56_TRUE
    LDD #0
    LBRA .CMP_56_END
.CMP_56_TRUE:
    LDD #1
.CMP_56_END:
    LBEQ IF_NEXT_79
; VPy_LINE:363
    LDD #1
    STD VAR_MOVE_SPEED
    LBRA IF_END_78
IF_NEXT_79:
    LDD #70
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ABS_JOY
    CMPD TMPVAL
    LBLT .CMP_57_TRUE
    LDD #0
    LBRA .CMP_57_END
.CMP_57_TRUE:
    LDD #1
.CMP_57_END:
    LBEQ IF_NEXT_80
; VPy_LINE:365
    LDD #2
    STD VAR_MOVE_SPEED
    LBRA IF_END_78
IF_NEXT_80:
    LDD #100
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ABS_JOY
    CMPD TMPVAL
    LBLT .CMP_58_TRUE
    LDD #0
    LBRA .CMP_58_END
.CMP_58_TRUE:
    LDD #1
.CMP_58_END:
    LBEQ IF_NEXT_81
; VPy_LINE:367
    LDD #3
    STD VAR_MOVE_SPEED
    LBRA IF_END_78
IF_NEXT_81:
; VPy_LINE:369
    LDD #4
    STD VAR_MOVE_SPEED
IF_END_78:
; VPy_LINE:372
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBLT .CMP_59_TRUE
    LDD #0
    LBRA .CMP_59_END
.CMP_59_TRUE:
    LDD #1
.CMP_59_END:
    LBEQ IF_NEXT_83
; VPy_LINE:373
    LDD >VAR_MOVE_SPEED
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD VAR_MOVE_SPEED
    LBRA IF_END_82
IF_NEXT_83:
IF_END_82:
; VPy_LINE:375
    LDD >VAR_MOVE_SPEED
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_PLAYER_X
; VPy_LINE:378
    LDD #-110
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    CMPD TMPVAL
    LBLT .CMP_60_TRUE
    LDD #0
    LBRA .CMP_60_END
.CMP_60_TRUE:
    LDD #1
.CMP_60_END:
    LBEQ IF_NEXT_85
; VPy_LINE:379
    LDD #-110
    STD VAR_PLAYER_X
    LBRA IF_END_84
IF_NEXT_85:
IF_END_84:
; VPy_LINE:380
    LDD #110
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    CMPD TMPVAL
    LBGT .CMP_61_TRUE
    LDD #0
    LBRA .CMP_61_END
.CMP_61_TRUE:
    LDD #1
.CMP_61_END:
    LBEQ IF_NEXT_87
; VPy_LINE:381
    LDD #110
    STD VAR_PLAYER_X
    LBRA IF_END_86
IF_NEXT_87:
IF_END_86:
; VPy_LINE:384
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBLT .CMP_62_TRUE
    LDD #0
    LBRA .CMP_62_END
.CMP_62_TRUE:
    LDD #1
.CMP_62_END:
    LBEQ IF_NEXT_89
; VPy_LINE:385
    LDD #-1
    STD VAR_PLAYER_FACING
    LBRA IF_END_88
IF_NEXT_89:
; VPy_LINE:387
    LDD #1
    STD VAR_PLAYER_FACING
IF_END_88:
; VPy_LINE:390
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_ANIM_COUNTER
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_PLAYER_ANIM_COUNTER
; VPy_LINE:392
    LDD #5  ; const player_anim_speed
    STD VAR_ANIM_THRESHOLD
; VPy_LINE:393
    LDD #-80
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBLT .CMP_64_TRUE
    LDD #0
    LBRA .CMP_64_END
.CMP_64_TRUE:
    LDD #1
.CMP_64_END:
    LBNE .LOGIC_63_TRUE
    LDD #80
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBGT .CMP_65_TRUE
    LDD #0
    LBRA .CMP_65_END
.CMP_65_TRUE:
    LDD #1
.CMP_65_END:
    LBNE .LOGIC_63_TRUE
    LDD #0
    LBRA .LOGIC_63_END
.LOGIC_63_TRUE:
    LDD #1
.LOGIC_63_END:
    LBEQ IF_NEXT_91
; VPy_LINE:394
    LDD #2
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #5  ; const player_anim_speed
    TFR D,X             ; X = LEFT (dividend)
    LDD TMPVAL          ; D = RIGHT (divisor)
    JSR DIV16           ; D = X / D
    STD VAR_ANIM_THRESHOLD
    LBRA IF_END_90
IF_NEXT_91:
IF_END_90:
; VPy_LINE:396
    LDD >VAR_ANIM_THRESHOLD
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_ANIM_COUNTER
    CMPD TMPVAL
    LBGE .CMP_66_TRUE
    LDD #0
    LBRA .CMP_66_END
.CMP_66_TRUE:
    LDD #1
.CMP_66_END:
    LBEQ IF_NEXT_93
; VPy_LINE:397
    LDD #0
    STD VAR_PLAYER_ANIM_COUNTER
; VPy_LINE:398
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_ANIM_FRAME
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_PLAYER_ANIM_FRAME
; VPy_LINE:399
    LDD #5
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_ANIM_FRAME
    CMPD TMPVAL
    LBGT .CMP_67_TRUE
    LDD #0
    LBRA .CMP_67_END
.CMP_67_TRUE:
    LDD #1
.CMP_67_END:
    LBEQ IF_NEXT_95
; VPy_LINE:400
    LDD #1
    STD VAR_PLAYER_ANIM_FRAME
    LBRA IF_END_94
IF_NEXT_95:
IF_END_94:
    LBRA IF_END_92
IF_NEXT_93:
IF_END_92:
    LBRA IF_END_74
IF_NEXT_75:
; VPy_LINE:403
    LDD #1
    STD VAR_PLAYER_ANIM_FRAME
; VPy_LINE:404
    LDD #0
    STD VAR_PLAYER_ANIM_COUNTER
IF_END_74:
; VPy_LINE:407
    LDD #0
    STD VAR_MIRROR_MODE
; VPy_LINE:408
    LDD >VAR_PLAYER_FACING
    CMPD #-1
    LBNE IF_NEXT_97
; VPy_LINE:409
    LDD #1
    STD VAR_MIRROR_MODE
    LBRA IF_END_96
IF_NEXT_97:
IF_END_96:
; VPy_LINE:412
    LDD >VAR_PLAYER_ANIM_FRAME
    CMPD #1
    LBNE IF_NEXT_99
; VPy_LINE:413
; NATIVE_CALL: DRAW_VECTOR_EX at line 413
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_1 (index=23, 17 paths) with mirror + intensity
    LDD >VAR_PLAYER_X
    TFR B,A       ; X position (low byte) — B already holds it
    STA DRAW_VEC_X
    LDD #-70  ; const player_y
    TFR B,A       ; Y position (low byte) — B already holds it
    STA DRAW_VEC_Y
    LDD >VAR_MIRROR_MODE
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_20_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_20_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_20_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_20_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_20_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_20_CALL:
    ; Set intensity override for drawing
    LDD #80
    TFR B,A       ; Intensity (0-127) — B already holds it
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    LDX #23        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    LBRA IF_END_98
IF_NEXT_99:
    LDD >VAR_PLAYER_ANIM_FRAME
    CMPD #2
    LBNE IF_NEXT_100
; VPy_LINE:415
; NATIVE_CALL: DRAW_VECTOR_EX at line 415
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_2 (index=24, 17 paths) with mirror + intensity
    LDD >VAR_PLAYER_X
    TFR B,A       ; X position (low byte) — B already holds it
    STA DRAW_VEC_X
    LDD #-70  ; const player_y
    TFR B,A       ; Y position (low byte) — B already holds it
    STA DRAW_VEC_Y
    LDD >VAR_MIRROR_MODE
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_21_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_21_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_21_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_21_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_21_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_21_CALL:
    ; Set intensity override for drawing
    LDD #80
    TFR B,A       ; Intensity (0-127) — B already holds it
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    LDX #24        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    LBRA IF_END_98
IF_NEXT_100:
    LDD >VAR_PLAYER_ANIM_FRAME
    CMPD #3
    LBNE IF_NEXT_101
; VPy_LINE:417
; NATIVE_CALL: DRAW_VECTOR_EX at line 417
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_3 (index=25, 17 paths) with mirror + intensity
    LDD >VAR_PLAYER_X
    TFR B,A       ; X position (low byte) — B already holds it
    STA DRAW_VEC_X
    LDD #-70  ; const player_y
    TFR B,A       ; Y position (low byte) — B already holds it
    STA DRAW_VEC_Y
    LDD >VAR_MIRROR_MODE
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_22_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_22_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_22_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_22_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_22_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_22_CALL:
    ; Set intensity override for drawing
    LDD #80
    TFR B,A       ; Intensity (0-127) — B already holds it
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    LDX #25        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    LBRA IF_END_98
IF_NEXT_101:
    LDD >VAR_PLAYER_ANIM_FRAME
    CMPD #4
    LBNE IF_NEXT_102
; VPy_LINE:419
; NATIVE_CALL: DRAW_VECTOR_EX at line 419
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_4 (index=26, 17 paths) with mirror + intensity
    LDD >VAR_PLAYER_X
    TFR B,A       ; X position (low byte) — B already holds it
    STA DRAW_VEC_X
    LDD #-70  ; const player_y
    TFR B,A       ; Y position (low byte) — B already holds it
    STA DRAW_VEC_Y
    LDD >VAR_MIRROR_MODE
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_23_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_23_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_23_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_23_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_23_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_23_CALL:
    ; Set intensity override for drawing
    LDD #80
    TFR B,A       ; Intensity (0-127) — B already holds it
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    LDX #26        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    LBRA IF_END_98
IF_NEXT_102:
; VPy_LINE:421
; NATIVE_CALL: DRAW_VECTOR_EX at line 421
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: player_walk_5 (index=27, 17 paths) with mirror + intensity
    LDD >VAR_PLAYER_X
    TFR B,A       ; X position (low byte) — B already holds it
    STA DRAW_VEC_X
    LDD #-70  ; const player_y
    TFR B,A       ; Y position (low byte) — B already holds it
    STA DRAW_VEC_Y
    LDD >VAR_MIRROR_MODE
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_24_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_24_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_24_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_24_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_24_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_24_CALL:
    ; Set intensity override for drawing
    LDD #80
    TFR B,A       ; Intensity (0-127) — B already holds it
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    LDX #27        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
IF_END_98:
; VPy_LINE:424
    JSR update_bubbles
; VPy_LINE:425
    JSR draw_bubbles
; VPy_LINE:428
    LDD >VAR_HOOK_ACTIVE
    CMPD #1
    LBNE IF_NEXT_104
; VPy_LINE:431
    LDD >VAR_HOOK_GUN_X
    STD VAR_ARG0
    LDD >VAR_HOOK_INIT_Y
    STD VAR_ARG1
    LDD >VAR_HOOK_X
    STD VAR_ARG2
    LDD >VAR_HOOK_Y
    STD VAR_ARG3
    JSR draw_hook_rope
; VPy_LINE:433
; NATIVE_CALL: SET_INTENSITY at line 433
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:435
; NATIVE_CALL: DRAW_VECTOR_EX at line 435
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: hook (index=12, 1 paths) with mirror + intensity
    LDD >VAR_HOOK_X
    TFR B,A       ; X position (low byte) — B already holds it
    STA DRAW_VEC_X
    LDD >VAR_HOOK_Y
    TFR B,A       ; Y position (low byte) — B already holds it
    STA DRAW_VEC_Y
    LDD #0
    ; Decode mirror mode into separate flags:
    CLR MIRROR_X  ; Clear X flag
    CLR MIRROR_Y  ; Clear Y flag
    CMPB #1       ; Check if X-mirror (mode 1)
    LBNE .DSVEX_25_CHK_Y
    LDA #1
    STA MIRROR_X
.DSVEX_25_CHK_Y:
    CMPB #2       ; Check if Y-mirror (mode 2)
    LBNE .DSVEX_25_CHK_XY
    LDA #1
    STA MIRROR_Y
.DSVEX_25_CHK_XY:
    CMPB #3       ; Check if both-mirror (mode 3)
    LBNE .DSVEX_25_CALL
    LDA #1
    STA MIRROR_X
    STA MIRROR_Y
.DSVEX_25_CALL:
    ; Set intensity override for drawing
    LDD #100
    TFR B,A       ; Intensity (0-127) — B already holds it
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    LDX #12        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
    LBRA IF_END_103
IF_NEXT_104:
IF_END_103:
    RTS

; Function: init_bubbles (Bank #0)
init_bubbles:
; VPy_LINE:449
    LDX #ARRAY_LEVEL_ENEMY_COUNT_DATA  ; Array base
    LDD >VAR_CURRENT_LOCATION
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_COUNT
; VPy_LINE:450
    LDX #ARRAY_LEVEL_ENEMY_SPEED_DATA  ; Array base
    LDD >VAR_CURRENT_LOCATION
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD VAR_SPEED
; VPy_LINE:453
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_COUNT
    CMPD TMPVAL
    LBLT .CMP_68_TRUE
    LDD #0
    LBRA .CMP_68_END
.CMP_68_TRUE:
    LDD #1
.CMP_68_END:
    LBEQ IF_NEXT_106
; VPy_LINE:454
    LDD #1
    STD VAR_COUNT
    LBRA IF_END_105
IF_NEXT_106:
IF_END_105:
; VPy_LINE:455
    LDD #8  ; const MAX_ENEMIES
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_COUNT
    CMPD TMPVAL
    LBGT .CMP_69_TRUE
    LDD #0
    LBRA .CMP_69_END
.CMP_69_TRUE:
    LDD #1
.CMP_69_END:
    LBEQ IF_NEXT_108
; VPy_LINE:456
    LDD #8  ; const MAX_ENEMIES
    STD VAR_COUNT
    LBRA IF_END_107
IF_NEXT_108:
IF_END_107:
; VPy_LINE:458
    LDD #0
    STD VAR_I
; VPy_LINE:459
WH_109: ; while start
    LDD >VAR_COUNT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    CMPD TMPVAL
    LBLT .CMP_71_TRUE
    LDD #0
    LBRA .CMP_71_END
.CMP_71_TRUE:
    LDD #1
.CMP_71_END:
    LBEQ .LOGIC_70_FALSE
    LDD #8  ; const MAX_ENEMIES
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    CMPD TMPVAL
    LBLT .CMP_72_TRUE
    LDD #0
    LBRA .CMP_72_END
.CMP_72_TRUE:
    LDD #1
.CMP_72_END:
    LBEQ .LOGIC_70_FALSE
    LDD #1
    LBRA .LOGIC_70_END
.LOGIC_70_FALSE:
    LDD #0
.LOGIC_70_END:
    LBEQ WH_END_110
; VPy_LINE:460
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_ACTIVE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #1
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:461
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_SIZE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #4
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:462
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_X_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #50
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-80
    ADDD TMPVAL         ; D = LEFT + RIGHT
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:463
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_Y_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #60
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:464
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VX_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD >VAR_SPEED
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:465
    LDD #2
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MOD16           ; D = X % D
    CMPD #1
    LBNE IF_NEXT_112
; VPy_LINE:466
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VX_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD >VAR_SPEED
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LBRA IF_END_111
IF_NEXT_112:
IF_END_111:
; VPy_LINE:467
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VY_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:468
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_I
    LBRA WH_109
WH_END_110: ; while end
    RTS

; Function: update_bubbles (Bank #0)
update_bubbles:
; VPy_LINE:472
    LDD #0
    STD VAR_I
; VPy_LINE:473
WH_113: ; while start
    LDD #8  ; const MAX_ENEMIES
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    CMPD TMPVAL
    LBLT .CMP_73_TRUE
    LDD #0
    LBRA .CMP_73_END
.CMP_73_TRUE:
    LDD #1
.CMP_73_END:
    LBEQ WH_END_114
; VPy_LINE:474
    LDX #VAR_ENEMY_ACTIVE_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #1
    LBNE IF_NEXT_116
; VPy_LINE:476
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VY_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_ENEMY_VY_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD #1  ; const GRAVITY
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    SUBD TMPVAL         ; D = LEFT - RIGHT
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:479
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_X_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDX #VAR_ENEMY_VX_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    ADDD TMPVAL         ; D = LEFT + RIGHT
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:480
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_Y_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDX #VAR_ENEMY_VY_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    ADDD TMPVAL         ; D = LEFT + RIGHT
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:483
    LDD #-70  ; const GROUND_Y
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBLE .CMP_74_TRUE
    LDD #0
    LBRA .CMP_74_END
.CMP_74_TRUE:
    LDD #1
.CMP_74_END:
    LBEQ IF_NEXT_118
; VPy_LINE:484
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_Y_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #-70  ; const GROUND_Y
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:485
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VY_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_ENEMY_VY_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:486
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VY_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_ENEMY_VY_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; LEFT → TMPVAL (RIGHT simple, commutative)
    LDD #17  ; const BOUNCE_DAMPING
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD #20
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    TFR D,X             ; X = LEFT (dividend)
    LDD TMPVAL          ; D = RIGHT (divisor)
    JSR DIV16           ; D = X / D
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:488
    LDD #10  ; const MIN_BOUNCE_VY
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_VY_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBLT .CMP_75_TRUE
    LDD #0
    LBRA .CMP_75_END
.CMP_75_TRUE:
    LDD #1
.CMP_75_END:
    LBEQ IF_NEXT_120
; VPy_LINE:489
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VY_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #10  ; const MIN_BOUNCE_VY
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LBRA IF_END_119
IF_NEXT_120:
IF_END_119:
    LBRA IF_END_117
IF_NEXT_118:
IF_END_117:
; VPy_LINE:492
    LDD #-85
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBLE .CMP_76_TRUE
    LDD #0
    LBRA .CMP_76_END
.CMP_76_TRUE:
    LDD #1
.CMP_76_END:
    LBEQ IF_NEXT_122
; VPy_LINE:493
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_X_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #-85
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:494
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VX_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_ENEMY_VX_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LBRA IF_END_121
IF_NEXT_122:
IF_END_121:
; VPy_LINE:495
    LDD #85
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBGE .CMP_77_TRUE
    LDD #0
    LBRA .CMP_77_END
.CMP_77_TRUE:
    LDD #1
.CMP_77_END:
    LBEQ IF_NEXT_124
; VPy_LINE:496
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_X_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #85
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:497
    LDD >VAR_I
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_ENEMY_VX_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDX #VAR_ENEMY_VX_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #-1
    TFR D,X             ; X = LEFT
    LDD TMPVAL          ; D = RIGHT
    JSR MUL16           ; D = X * D
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LBRA IF_END_123
IF_NEXT_124:
IF_END_123:
    LBRA IF_END_115
IF_NEXT_116:
IF_END_115:
; VPy_LINE:499
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_I
    LBRA WH_113
WH_END_114: ; while end
    RTS

; Function: draw_bubbles (Bank #0)
draw_bubbles:
; VPy_LINE:505
    LDD #0
    STD VAR_I
; VPy_LINE:506
WH_125: ; while start
    LDD #8  ; const MAX_ENEMIES
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_I
    CMPD TMPVAL
    LBLT .CMP_78_TRUE
    LDD #0
    LBRA .CMP_78_END
.CMP_78_TRUE:
    LDD #1
.CMP_78_END:
    LBEQ WH_END_126
; VPy_LINE:507
    LDX #VAR_ENEMY_ACTIVE_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #1
    LBNE IF_NEXT_128
; VPy_LINE:508
; NATIVE_CALL: SET_INTENSITY at line 508
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:509
    LDX #VAR_ENEMY_SIZE_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #4
    LBNE IF_NEXT_130
; VPy_LINE:510
; NATIVE_CALL: DRAW_VECTOR at line 510
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bubble_huge (index=5, 1 paths)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_26          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #5        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_26:
    LDD #0
    STD RESULT
    LBRA IF_END_129
IF_NEXT_130:
    LDX #VAR_ENEMY_SIZE_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #3
    LBNE IF_NEXT_131
; VPy_LINE:512
; NATIVE_CALL: DRAW_VECTOR at line 512
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bubble_large (index=6, 1 paths)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_27          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #6        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_27:
    LDD #0
    STD RESULT
    LBRA IF_END_129
IF_NEXT_131:
    LDX #VAR_ENEMY_SIZE_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #2
    LBNE IF_NEXT_132
; VPy_LINE:514
; NATIVE_CALL: DRAW_VECTOR at line 514
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bubble_medium (index=7, 1 paths)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_28          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #7        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_28:
    LDD #0
    STD RESULT
    LBRA IF_END_129
IF_NEXT_132:
; VPy_LINE:516
; NATIVE_CALL: DRAW_VECTOR at line 516
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: bubble_small (index=8, 1 paths)
    LDX #VAR_ENEMY_X_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_29          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDX #VAR_ENEMY_Y_DATA  ; Array base
    LDD >VAR_I
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #8        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_29:
    LDD #0
    STD RESULT
IF_END_129:
    LBRA IF_END_127
IF_NEXT_128:
IF_END_127:
; VPy_LINE:517
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_I
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_I
    LBRA WH_125
WH_END_126: ; while end
    RTS

; Function: draw_hook_rope (Bank #0)
draw_hook_rope:
; VPy_LINE:523
; NATIVE_CALL: DRAW_LINE at line 523
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD >VAR_ARG0
    STD DRAW_LINE_ARGS+0    ; x0
    LDD >VAR_ARG1
    STD DRAW_LINE_ARGS+2    ; y0
    LDD >VAR_ARG2
    STD DRAW_LINE_ARGS+4    ; x1
    LDD >VAR_ARG3
    STD DRAW_LINE_ARGS+6    ; y1
    LDD #127
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    RTS

; Function: read_joystick1_state (Bank #0)
read_joystick1_state:
; VPy_LINE:530
; NATIVE_CALL: J1_X at line 530
    LDD #0
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
    STD ,X          ; Store 16-bit value
; VPy_LINE:531
; NATIVE_CALL: J1_Y at line 531
    LDD #1
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
    STD ,X          ; Store 16-bit value
; VPy_LINE:534
; NATIVE_CALL: J1_BUTTON_1 at line 534
    LDD #2
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_JOYSTICK1_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed
    BITA #$01
    BNE .J1B1_30_ON
    LDD #0
    BRA .J1B1_30_END
.J1B1_30_ON:
    LDD #1
.J1B1_30_END:
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:535
; NATIVE_CALL: J1_BUTTON_2 at line 535
    LDD #3
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_JOYSTICK1_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDA >$C80F   ; Vec_Btns_1: bit1=1 means btn2 pressed
    BITA #$02
    BNE .J1B2_31_ON
    LDD #0
    BRA .J1B2_31_END
.J1B2_31_ON:
    LDD #1
.J1B2_31_END:
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:536
; NATIVE_CALL: J1_BUTTON_3 at line 536
    LDD #4
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_JOYSTICK1_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDA >$C80F   ; Vec_Btns_1: bit2=1 means btn3 pressed
    BITA #$04
    BNE .J1B3_32_ON
    LDD #0
    BRA .J1B3_32_END
.J1B3_32_ON:
    LDD #1
.J1B3_32_END:
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:537
; NATIVE_CALL: J1_BUTTON_4 at line 537
    LDD #5
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_JOYSTICK1_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDA >$C80F   ; Vec_Btns_1: bit3=1 means btn4 pressed
    BITA #$08
    BNE .J1B4_33_ON
    LDD #0
    BRA .J1B4_33_END
.J1B4_33_ON:
    LDD #1
.J1B4_33_END:
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    RTS


; ================================================


; ===== BANK #01 (physical offset $04000) =====

    ORG $0000  ; Sequential bank model

;***************************************************************************
; ASSETS IN BANK #1 (33 assets)
;***************************************************************************

; Generated from angkor_bg.vec (Malban Draw_Sync_List format)
; Total paths: 192, points: 648
; X bounds: min=-96, max=96, width=192
; Center: (0, 8)

_ANGKOR_BG_WIDTH EQU 192
_ANGKOR_BG_HALF_WIDTH EQU 96
_ANGKOR_BG_HEIGHT EQU 129
_ANGKOR_BG_HALF_HEIGHT EQU 64
_ANGKOR_BG_CENTER_X EQU 0
_ANGKOR_BG_CENTER_Y EQU 8

_ANGKOR_BG_VECTORS:  ; Main entry (header + 170 path(s))
    FDB 170               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
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

_ANGKOR_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FC,$00,0,0        ; path0: header (y=-4, x=0)
    FCB $FF,$F5,$F5          ; flag=-1, dy=-11, dx=-11
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $F1,$F5,0,0        ; path1: header (y=-15, x=-11)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$FF,$FD          ; flag=-1, dy=-1, dx=-3
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $E3,$F5,0,0        ; path2: header (y=-29, x=-11)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB $FF,$12,$00          ; flag=-1, dy=18, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $F2,$F6,0,0        ; path3: header (y=-14, x=-10)
    FCB $FF,$02,$FD          ; flag=-1, dy=2, dx=-3
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$03,$04          ; flag=-1, dy=3, dx=4
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $01,$00,0,0        ; path4: header (y=1, x=0)
    FCB $FF,$00,$F5          ; flag=-1, dy=0, dx=-11
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $FD,$F5,0,0        ; path5: header (y=-3, x=-11)
    FCB $FF,$00,$E3          ; flag=-1, dy=0, dx=-29
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$00,$1D          ; flag=-1, dy=0, dx=29
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $06,$F5,0,0        ; path6: header (y=6, x=-11)
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $06,$F5,0,0        ; path7: header (y=6, x=-11)
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $0B,$FB,0,0        ; path8: header (y=11, x=-5)
    FCB $FF,$00,$D3          ; flag=-1, dy=0, dx=-45
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $07,$CB,0,0        ; path9: header (y=7, x=-53)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $14,$CC,0,0        ; path10: header (y=20, x=-52)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $0E,$C7,0,0        ; path11: header (y=14, x=-57)
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $07,$C6,0,0        ; path12: header (y=7, x=-58)
    FCB $FF,$F0,$00          ; flag=-1, dy=-16, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $F7,$CE,0,0        ; path13: header (y=-9, x=-50)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$10,$00          ; flag=-1, dy=16, dx=0
    FCB $FF,$00,$E5          ; flag=-1, dy=0, dx=-27
    FCB $FF,$F0,$00          ; flag=-1, dy=-16, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $F7,$B9,0,0        ; path14: header (y=-9, x=-71)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$10,$00          ; flag=-1, dy=16, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $07,$B8,0,0        ; path15: header (y=7, x=-72)
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $0E,$B9,0,0        ; path16: header (y=14, x=-71)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $1C,$CB,0,0        ; path17: header (y=28, x=-53)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH18:    ; Path 18
    FCB 127              ; path18: intensity
    FCB $16,$C6,0,0        ; path18: header (y=22, x=-58)
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH19:    ; Path 19
    FCB 127              ; path19: intensity
    FCB $16,$C5,0,0        ; path19: header (y=22, x=-59)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$F5          ; flag=-1, dy=0, dx=-11
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH20:    ; Path 20
    FCB 127              ; path20: intensity
    FCB $16,$B9,0,0        ; path20: header (y=22, x=-71)
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$FE,$FB          ; flag=-1, dy=-2, dx=-5
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH21:    ; Path 21
    FCB 127              ; path21: intensity
    FCB $1C,$B4,0,0        ; path21: header (y=28, x=-76)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH22:    ; Path 22
    FCB 127              ; path22: intensity
    FCB $14,$B3,0,0        ; path22: header (y=20, x=-77)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH23:    ; Path 23
    FCB 127              ; path23: intensity
    FCB $12,$B1,0,0        ; path23: header (y=18, x=-79)
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$FE,$03          ; flag=-1, dy=-2, dx=3
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH24:    ; Path 24
    FCB 127              ; path24: intensity
    FCB $0C,$B1,0,0        ; path24: header (y=12, x=-79)
    FCB $FF,$02,$05          ; flag=-1, dy=2, dx=5
    FCB $FF,$00,$10          ; flag=-1, dy=0, dx=16
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH25:    ; Path 25
    FCB 127              ; path25: intensity
    FCB $07,$C2,0,0        ; path25: header (y=7, x=-62)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$02,$FD          ; flag=-1, dy=2, dx=-3
    FCB $FF,$FE,$FD          ; flag=-1, dy=-2, dx=-3
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH26:    ; Path 26
    FCB 127              ; path26: intensity
    FCB $04,$BC,0,0        ; path26: header (y=4, x=-68)
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB $FF,$00,$F9          ; flag=-1, dy=0, dx=-7
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH27:    ; Path 27
    FCB 127              ; path27: intensity
    FCB $F7,$BB,0,0        ; path27: header (y=-9, x=-69)
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH28:    ; Path 28
    FCB 127              ; path28: intensity
    FCB $E3,$BE,0,0        ; path28: header (y=-29, x=-66)
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH29:    ; Path 29
    FCB 127              ; path29: intensity
    FCB $D7,$CA,0,0        ; path29: header (y=-41, x=-54)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$0C,$00          ; flag=-1, dy=12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH30:    ; Path 30
    FCB 127              ; path30: intensity
    FCB $E3,$D8,0,0        ; path30: header (y=-29, x=-40)
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH31:    ; Path 31
    FCB 127              ; path31: intensity
    FCB $D7,$E5,0,0        ; path31: header (y=-41, x=-27)
    FCB $FF,$0C,$00          ; flag=-1, dy=12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH32:    ; Path 32
    FCB 127              ; path32: intensity
    FCB $E3,$EE,0,0        ; path32: header (y=-29, x=-18)
    FCB $FF,$00,$B6          ; flag=-1, dy=0, dx=-74
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH33:    ; Path 33
    FCB 127              ; path33: intensity
    FCB $E3,$A4,0,0        ; path33: header (y=-29, x=-92)
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH34:    ; Path 34
    FCB 127              ; path34: intensity
    FCB $E9,$A4,0,0        ; path34: header (y=-23, x=-92)
    FCB $FF,$00,$49          ; flag=-1, dy=0, dx=73
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH35:    ; Path 35
    FCB 127              ; path35: intensity
    FCB $E7,$EE,0,0        ; path35: header (y=-25, x=-18)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$F1,$00          ; flag=-1, dy=-15, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH36:    ; Path 36
    FCB 127              ; path36: intensity
    FCB $D8,$EC,0,0        ; path36: header (y=-40, x=-20)
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH37:    ; Path 37
    FCB 127              ; path37: intensity
    FCB $D7,$EC,0,0        ; path37: header (y=-41, x=-20)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$B4          ; flag=-1, dy=0, dx=-76
    FCB $FF,$F3,$00          ; flag=-1, dy=-13, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH38:    ; Path 38
    FCB 127              ; path38: intensity
    FCB $D2,$A0,0,0        ; path38: header (y=-46, x=-96)
    FCB $FF,$00,$4C          ; flag=-1, dy=0, dx=76
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH39:    ; Path 39
    FCB 127              ; path39: intensity
    FCB $D0,$EC,0,0        ; path39: header (y=-48, x=-20)
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB $FF,$00,$0B          ; flag=-1, dy=0, dx=11
    FCB $FF,$0E,$00          ; flag=-1, dy=14, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH40:    ; Path 40
    FCB 127              ; path40: intensity
    FCB $D1,$F6,0,0        ; path40: header (y=-47, x=-10)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH41:    ; Path 41
    FCB 127              ; path41: intensity
    FCB $D1,$00,0,0        ; path41: header (y=-47, x=0)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH42:    ; Path 42
    FCB 127              ; path42: intensity
    FCB $D4,$09,0,0        ; path42: header (y=-44, x=9)
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH43:    ; Path 43
    FCB 127              ; path43: intensity
    FCB $D4,$00,0,0        ; path43: header (y=-44, x=0)
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH44:    ; Path 44
    FCB 127              ; path44: intensity
    FCB $CC,$F4,0,0        ; path44: header (y=-52, x=-12)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH45:    ; Path 45
    FCB 127              ; path45: intensity
    FCB $CC,$00,0,0        ; path45: header (y=-52, x=0)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH46:    ; Path 46
    FCB 127              ; path46: intensity
    FCB $D0,$0F,0,0        ; path46: header (y=-48, x=15)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB $FF,$00,$0B          ; flag=-1, dy=0, dx=11
    FCB $FF,$0E,$00          ; flag=-1, dy=14, dx=0
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH47:    ; Path 47
    FCB 127              ; path47: intensity
    FCB $D2,$14,0,0        ; path47: header (y=-46, x=20)
    FCB $FF,$00,$4C          ; flag=-1, dy=0, dx=76
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH48:    ; Path 48
    FCB 127              ; path48: intensity
    FCB $D7,$5B,0,0        ; path48: header (y=-41, x=91)
    FCB $FF,$0C,$00          ; flag=-1, dy=12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH49:    ; Path 49
    FCB 127              ; path49: intensity
    FCB $E3,$5C,0,0        ; path49: header (y=-29, x=92)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$B6          ; flag=-1, dy=0, dx=-74
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH50:    ; Path 50
    FCB 127              ; path50: intensity
    FCB $E7,$12,0,0        ; path50: header (y=-25, x=18)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$F1,$00          ; flag=-1, dy=-15, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH51:    ; Path 51
    FCB 127              ; path51: intensity
    FCB $D8,$14,0,0        ; path51: header (y=-40, x=20)
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$F9          ; flag=-1, dy=0, dx=-7
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH52:    ; Path 52
    FCB 127              ; path52: intensity
    FCB $D7,$14,0,0        ; path52: header (y=-41, x=20)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$4C          ; flag=-1, dy=0, dx=76
    FCB $FF,$F3,$00          ; flag=-1, dy=-13, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH53:    ; Path 53
    FCB 127              ; path53: intensity
    FCB $D7,$4F,0,0        ; path53: header (y=-41, x=79)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$0C,$00          ; flag=-1, dy=12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH54:    ; Path 54
    FCB 127              ; path54: intensity
    FCB $E9,$57,0,0        ; path54: header (y=-23, x=87)
    FCB $FF,$0E,$00          ; flag=-1, dy=14, dx=0
    FCB $FF,$00,$CF          ; flag=-1, dy=0, dx=-49
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH55:    ; Path 55
    FCB 127              ; path55: intensity
    FCB $FD,$26,0,0        ; path55: header (y=-3, x=38)
    FCB $FF,$EC,$00          ; flag=-1, dy=-20, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH56:    ; Path 56
    FCB 127              ; path56: intensity
    FCB $E3,$28,0,0        ; path56: header (y=-29, x=40)
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH57:    ; Path 57
    FCB 127              ; path57: intensity
    FCB $D7,$1B,0,0        ; path57: header (y=-41, x=27)
    FCB $FF,$0C,$00          ; flag=-1, dy=12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH58:    ; Path 58
    FCB 127              ; path58: intensity
    FCB $E9,$13,0,0        ; path58: header (y=-23, x=19)
    FCB $FF,$00,$49          ; flag=-1, dy=0, dx=73
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH59:    ; Path 59
    FCB 127              ; path59: intensity
    FCB $E9,$5C,0,0        ; path59: header (y=-23, x=92)
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH60:    ; Path 60
    FCB 127              ; path60: intensity
    FCB $F2,$57,0,0        ; path60: header (y=-14, x=87)
    FCB $FF,$00,$B6          ; flag=-1, dy=0, dx=-74
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH61:    ; Path 61
    FCB 127              ; path61: intensity
    FCB $F1,$0B,0,0        ; path61: header (y=-15, x=11)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FF,$03          ; flag=-1, dy=-1, dx=3
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH62:    ; Path 62
    FCB 127              ; path62: intensity
    FCB $E3,$0B,0,0        ; path62: header (y=-29, x=11)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB $FF,$12,$00          ; flag=-1, dy=18, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH63:    ; Path 63
    FCB 127              ; path63: intensity
    FCB $F1,$0B,0,0        ; path63: header (y=-15, x=11)
    FCB $FF,$0B,$F5          ; flag=-1, dy=11, dx=-11
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH64:    ; Path 64
    FCB 127              ; path64: intensity
    FCB $01,$00,0,0        ; path64: header (y=1, x=0)
    FCB $FF,$00,$0B          ; flag=-1, dy=0, dx=11
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH65:    ; Path 65
    FCB 127              ; path65: intensity
    FCB $FD,$0B,0,0        ; path65: header (y=-3, x=11)
    FCB $FF,$00,$1D          ; flag=-1, dy=0, dx=29
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$00,$E3          ; flag=-1, dy=0, dx=-29
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH66:    ; Path 66
    FCB 127              ; path66: intensity
    FCB $06,$0B,0,0        ; path66: header (y=6, x=11)
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH67:    ; Path 67
    FCB 127              ; path67: intensity
    FCB $06,$0B,0,0        ; path67: header (y=6, x=11)
    FCB $FF,$01,$FF          ; flag=-1, dy=1, dx=-1
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH68:    ; Path 68
    FCB 127              ; path68: intensity
    FCB $0B,$05,0,0        ; path68: header (y=11, x=5)
    FCB $FF,$00,$2D          ; flag=-1, dy=0, dx=45
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH69:    ; Path 69
    FCB 127              ; path69: intensity
    FCB $07,$35,0,0        ; path69: header (y=7, x=53)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$02,$FD          ; flag=-1, dy=2, dx=-3
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH70:    ; Path 70
    FCB 127              ; path70: intensity
    FCB $14,$34,0,0        ; path70: header (y=20, x=52)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH71:    ; Path 71
    FCB 127              ; path71: intensity
    FCB $0E,$39,0,0        ; path71: header (y=14, x=57)
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH72:    ; Path 72
    FCB 127              ; path72: intensity
    FCB $07,$3A,0,0        ; path72: header (y=7, x=58)
    FCB $FF,$F0,$00          ; flag=-1, dy=-16, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH73:    ; Path 73
    FCB 127              ; path73: intensity
    FCB $F7,$32,0,0        ; path73: header (y=-9, x=50)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$10,$00          ; flag=-1, dy=16, dx=0
    FCB $FF,$00,$1B          ; flag=-1, dy=0, dx=27
    FCB $FF,$F0,$00          ; flag=-1, dy=-16, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH74:    ; Path 74
    FCB 127              ; path74: intensity
    FCB $F7,$47,0,0        ; path74: header (y=-9, x=71)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$10,$00          ; flag=-1, dy=16, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH75:    ; Path 75
    FCB 127              ; path75: intensity
    FCB $07,$48,0,0        ; path75: header (y=7, x=72)
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH76:    ; Path 76
    FCB 127              ; path76: intensity
    FCB $0E,$47,0,0        ; path76: header (y=14, x=71)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$FE,$FB          ; flag=-1, dy=-2, dx=-5
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH77:    ; Path 77
    FCB 127              ; path77: intensity
    FCB $1C,$35,0,0        ; path77: header (y=28, x=53)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH78:    ; Path 78
    FCB 127              ; path78: intensity
    FCB $16,$3A,0,0        ; path78: header (y=22, x=58)
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH79:    ; Path 79
    FCB 127              ; path79: intensity
    FCB $16,$3B,0,0        ; path79: header (y=22, x=59)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$0B          ; flag=-1, dy=0, dx=11
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH80:    ; Path 80
    FCB 127              ; path80: intensity
    FCB $16,$47,0,0        ; path80: header (y=22, x=71)
    FCB $FF,$00,$01          ; flag=-1, dy=0, dx=1
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH81:    ; Path 81
    FCB 127              ; path81: intensity
    FCB $1C,$4C,0,0        ; path81: header (y=28, x=76)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH82:    ; Path 82
    FCB 127              ; path82: intensity
    FCB $14,$4D,0,0        ; path82: header (y=20, x=77)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH83:    ; Path 83
    FCB 127              ; path83: intensity
    FCB $12,$4F,0,0        ; path83: header (y=18, x=79)
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$FE,$FD          ; flag=-1, dy=-2, dx=-3
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH84:    ; Path 84
    FCB 127              ; path84: intensity
    FCB $0C,$4F,0,0        ; path84: header (y=12, x=79)
    FCB $FF,$02,$FB          ; flag=-1, dy=2, dx=-5
    FCB $FF,$00,$F0          ; flag=-1, dy=0, dx=-16
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$FE,$FB          ; flag=-1, dy=-2, dx=-5
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH85:    ; Path 85
    FCB 127              ; path85: intensity
    FCB $07,$3E,0,0        ; path85: header (y=7, x=62)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$FE,$03          ; flag=-1, dy=-2, dx=3
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH86:    ; Path 86
    FCB 127              ; path86: intensity
    FCB $04,$44,0,0        ; path86: header (y=4, x=68)
    FCB $FF,$00,$F9          ; flag=-1, dy=0, dx=-7
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH87:    ; Path 87
    FCB 127              ; path87: intensity
    FCB $F7,$45,0,0        ; path87: header (y=-9, x=69)
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH88:    ; Path 88
    FCB 127              ; path88: intensity
    FCB $E3,$42,0,0        ; path88: header (y=-29, x=66)
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH89:    ; Path 89
    FCB 127              ; path89: intensity
    FCB $D7,$36,0,0        ; path89: header (y=-41, x=54)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$0C,$00          ; flag=-1, dy=12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH90:    ; Path 90
    FCB 127              ; path90: intensity
    FCB $F2,$0A,0,0        ; path90: header (y=-14, x=10)
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$03,$FC          ; flag=-1, dy=3, dx=-4
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH91:    ; Path 91
    FCB 127              ; path91: intensity
    FCB $0C,$00,0,0        ; path91: header (y=12, x=0)
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH92:    ; Path 92
    FCB 127              ; path92: intensity
    FCB $0C,$FA,0,0        ; path92: header (y=12, x=-6)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FF,$01          ; flag=-1, dy=-1, dx=1
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH93:    ; Path 93
    FCB 127              ; path93: intensity
    FCB $10,$00,0,0        ; path93: header (y=16, x=0)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH94:    ; Path 94
    FCB 127              ; path94: intensity
    FCB $0C,$06,0,0        ; path94: header (y=12, x=6)
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH95:    ; Path 95
    FCB 127              ; path95: intensity
    FCB $11,$FD,0,0        ; path95: header (y=17, x=-3)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH96:    ; Path 96
    FCB 127              ; path96: intensity
    FCB $15,$00,0,0        ; path96: header (y=21, x=0)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH97:    ; Path 97
    FCB 127              ; path97: intensity
    FCB $10,$06,0,0        ; path97: header (y=16, x=6)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH98:    ; Path 98
    FCB 127              ; path98: intensity
    FCB $10,$0B,0,0        ; path98: header (y=16, x=11)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$03,$03          ; flag=-1, dy=3, dx=3
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH99:    ; Path 99
    FCB 127              ; path99: intensity
    FCB $21,$0D,0,0        ; path99: header (y=33, x=13)
    FCB $FF,$FC,$FD          ; flag=-1, dy=-4, dx=-3
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH100:    ; Path 100
    FCB 127              ; path100: intensity
    FCB $1A,$08,0,0        ; path100: header (y=26, x=8)
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH101:    ; Path 101
    FCB 127              ; path101: intensity
    FCB $1A,$07,0,0        ; path101: header (y=26, x=7)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$FF,$06          ; flag=-1, dy=-1, dx=6
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH102:    ; Path 102
    FCB 127              ; path102: intensity
    FCB $28,$0B,0,0        ; path102: header (y=40, x=11)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH103:    ; Path 103
    FCB 127              ; path103: intensity
    FCB $22,$07,0,0        ; path103: header (y=34, x=7)
    FCB $FF,$00,$F9          ; flag=-1, dy=0, dx=-7
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH104:    ; Path 104
    FCB 127              ; path104: intensity
    FCB $22,$00,0,0        ; path104: header (y=34, x=0)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$F9          ; flag=-1, dy=0, dx=-7
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH105:    ; Path 105
    FCB 127              ; path105: intensity
    FCB $22,$FB,0,0        ; path105: header (y=34, x=-5)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH106:    ; Path 106
    FCB 127              ; path106: intensity
    FCB $2A,$00,0,0        ; path106: header (y=42, x=0)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH107:    ; Path 107
    FCB 127              ; path107: intensity
    FCB $2A,$05,0,0        ; path107: header (y=42, x=5)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FE,$04          ; flag=-1, dy=-2, dx=4
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH108:    ; Path 108
    FCB 127              ; path108: intensity
    FCB $30,$08,0,0        ; path108: header (y=48, x=8)
    FCB $FF,$FD,$FE          ; flag=-1, dy=-3, dx=-2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH109:    ; Path 109
    FCB 127              ; path109: intensity
    FCB $2A,$04,0,0        ; path109: header (y=42, x=4)
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH110:    ; Path 110
    FCB 127              ; path110: intensity
    FCB $31,$00,0,0        ; path110: header (y=49, x=0)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH111:    ; Path 111
    FCB 127              ; path111: intensity
    FCB $2A,$FB,0,0        ; path111: header (y=42, x=-5)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$FC          ; flag=-1, dy=-2, dx=-4
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH112:    ; Path 112
    FCB 127              ; path112: intensity
    FCB $30,$F8,0,0        ; path112: header (y=48, x=-8)
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH113:    ; Path 113
    FCB 127              ; path113: intensity
    FCB $28,$F5,0,0        ; path113: header (y=40, x=-11)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH114:    ; Path 114
    FCB 127              ; path114: intensity
    FCB $25,$F3,0,0        ; path114: header (y=37, x=-13)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$01,$06          ; flag=-1, dy=1, dx=6
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH115:    ; Path 115
    FCB 127              ; path115: intensity
    FCB $1A,$F8,0,0        ; path115: header (y=26, x=-8)
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH116:    ; Path 116
    FCB 127              ; path116: intensity
    FCB $10,$FA,0,0        ; path116: header (y=16, x=-6)
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH117:    ; Path 117
    FCB 127              ; path117: intensity
    FCB $10,$F5,0,0        ; path117: header (y=16, x=-11)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$03,$FD          ; flag=-1, dy=3, dx=-3
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH118:    ; Path 118
    FCB 127              ; path118: intensity
    FCB $21,$F3,0,0        ; path118: header (y=33, x=-13)
    FCB $FF,$FC,$03          ; flag=-1, dy=-4, dx=3
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH119:    ; Path 119
    FCB 127              ; path119: intensity
    FCB $18,$F2,0,0        ; path119: header (y=24, x=-14)
    FCB $FF,$02,$05          ; flag=-1, dy=2, dx=5
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH120:    ; Path 120
    FCB 127              ; path120: intensity
    FCB $1A,$00,0,0        ; path120: header (y=26, x=0)
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH121:    ; Path 121
    FCB 127              ; path121: intensity
    FCB $F4,$00,0,0        ; path121: header (y=-12, x=0)
    FCB $FF,$FF,$FC          ; flag=-1, dy=-1, dx=-4
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH122:    ; Path 122
    FCB 127              ; path122: intensity
    FCB $F3,$FC,0,0        ; path122: header (y=-13, x=-4)
    FCB $FF,$FC,$FD          ; flag=-1, dy=-4, dx=-3
    FCB $FF,$E9,$00          ; flag=-1, dy=-23, dx=0
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH123:    ; Path 123
    FCB 127              ; path123: intensity
    FCB $D8,$00,0,0        ; path123: header (y=-40, x=0)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$17,$00          ; flag=-1, dy=23, dx=0
    FCB $FF,$04,$FD          ; flag=-1, dy=4, dx=-3
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH124:    ; Path 124
    FCB 127              ; path124: intensity
    FCB $F3,$04,0,0        ; path124: header (y=-13, x=4)
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH125:    ; Path 125
    FCB 127              ; path125: intensity
    FCB $F4,$00,0,0        ; path125: header (y=-12, x=0)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH126:    ; Path 126
    FCB 127              ; path126: intensity
    FCB $F4,$00,0,0        ; path126: header (y=-12, x=0)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH127:    ; Path 127
    FCB 127              ; path127: intensity
    FCB $F2,$F3,0,0        ; path127: header (y=-14, x=-13)
    FCB $FF,$00,$B6          ; flag=-1, dy=0, dx=-74
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH128:    ; Path 128
    FCB 127              ; path128: intensity
    FCB $E9,$A9,0,0        ; path128: header (y=-23, x=-87)
    FCB $FF,$0E,$00          ; flag=-1, dy=14, dx=0
    FCB $FF,$00,$31          ; flag=-1, dy=0, dx=49
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH129:    ; Path 129
    FCB 127              ; path129: intensity
    FCB $FD,$DA,0,0        ; path129: header (y=-3, x=-38)
    FCB $FF,$EC,$00          ; flag=-1, dy=-20, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH130:    ; Path 130
    FCB 127              ; path130: intensity
    FCB $E3,$B1,0,0        ; path130: header (y=-29, x=-79)
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH131:    ; Path 131
    FCB 127              ; path131: intensity
    FCB $D7,$A5,0,0        ; path131: header (y=-41, x=-91)
    FCB $FF,$0C,$00          ; flag=-1, dy=12, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH132:    ; Path 132
    FCB 127              ; path132: intensity
    FCB $1E,$B9,0,0        ; path132: header (y=30, x=-71)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH133:    ; Path 133
    FCB 127              ; path133: intensity
    FCB $24,$B9,0,0        ; path133: header (y=36, x=-71)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$0D          ; flag=-1, dy=0, dx=13
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH134:    ; Path 134
    FCB 127              ; path134: intensity
    FCB $23,$C8,0,0        ; path134: header (y=35, x=-56)
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB $FF,$FF,$FC          ; flag=-1, dy=-1, dx=-4
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH135:    ; Path 135
    FCB 127              ; path135: intensity
    FCB $21,$B4,0,0        ; path135: header (y=33, x=-76)
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$02,$06          ; flag=-1, dy=2, dx=6
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH136:    ; Path 136
    FCB 127              ; path136: intensity
    FCB $1E,$BC,0,0        ; path136: header (y=30, x=-68)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH137:    ; Path 137
    FCB 127              ; path137: intensity
    FCB $29,$BA,0,0        ; path137: header (y=41, x=-70)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$0B          ; flag=-1, dy=0, dx=11
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH138:    ; Path 138
    FCB 127              ; path138: intensity
    FCB $27,$C8,0,0        ; path138: header (y=39, x=-56)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$FD,$FE          ; flag=-1, dy=-3, dx=-2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH139:    ; Path 139
    FCB 127              ; path139: intensity
    FCB $1E,$C5,0,0        ; path139: header (y=30, x=-59)
    FCB $FF,$FE,$06          ; flag=-1, dy=-2, dx=6
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH140:    ; Path 140
    FCB 127              ; path140: intensity
    FCB $1E,$C3,0,0        ; path140: header (y=30, x=-61)
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH141:    ; Path 141
    FCB 127              ; path141: intensity
    FCB $2D,$C3,0,0        ; path141: header (y=45, x=-61)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$F9          ; flag=-1, dy=0, dx=-7
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH142:    ; Path 142
    FCB 127              ; path142: intensity
    FCB $30,$BD,0,0        ; path142: header (y=48, x=-67)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH143:    ; Path 143
    FCB 127              ; path143: intensity
    FCB $33,$C2,0,0        ; path143: header (y=51, x=-62)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH144:    ; Path 144
    FCB 127              ; path144: intensity
    FCB $33,$F8,0,0        ; path144: header (y=51, x=-8)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$01,$04          ; flag=-1, dy=1, dx=4
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH145:    ; Path 145
    FCB 127              ; path145: intensity
    FCB $31,$FA,0,0        ; path145: header (y=49, x=-6)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH146:    ; Path 146
    FCB 127              ; path146: intensity
    FCB $36,$00,0,0        ; path146: header (y=54, x=0)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH147:    ; Path 147
    FCB 127              ; path147: intensity
    FCB $31,$04,0,0        ; path147: header (y=49, x=4)
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH148:    ; Path 148
    FCB 127              ; path148: intensity
    FCB $36,$05,0,0        ; path148: header (y=54, x=5)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH149:    ; Path 149
    FCB 127              ; path149: intensity
    FCB $3A,$00,0,0        ; path149: header (y=58, x=0)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH150:    ; Path 150
    FCB 127              ; path150: intensity
    FCB $3A,$FD,0,0        ; path150: header (y=58, x=-3)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH151:    ; Path 151
    FCB 127              ; path151: intensity
    FCB $3D,$00,0,0        ; path151: header (y=61, x=0)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH152:    ; Path 152
    FCB 127              ; path152: intensity
    FCB $3D,$02,0,0        ; path152: header (y=61, x=2)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH153:    ; Path 153
    FCB 127              ; path153: intensity
    FCB $41,$00,0,0        ; path153: header (y=65, x=0)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH154:    ; Path 154
    FCB 127              ; path154: intensity
    FCB $27,$38,0,0        ; path154: header (y=39, x=56)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH155:    ; Path 155
    FCB 127              ; path155: intensity
    FCB $1E,$3B,0,0        ; path155: header (y=30, x=59)
    FCB $FF,$FE,$FA          ; flag=-1, dy=-2, dx=-6
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH156:    ; Path 156
    FCB 127              ; path156: intensity
    FCB $23,$38,0,0        ; path156: header (y=35, x=56)
    FCB $FF,$01,$04          ; flag=-1, dy=1, dx=4
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH157:    ; Path 157
    FCB 127              ; path157: intensity
    FCB $24,$47,0,0        ; path157: header (y=36, x=71)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$F3          ; flag=-1, dy=0, dx=-13
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH158:    ; Path 158
    FCB 127              ; path158: intensity
    FCB $24,$3D,0,0        ; path158: header (y=36, x=61)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH159:    ; Path 159
    FCB 127              ; path159: intensity
    FCB $1E,$44,0,0        ; path159: header (y=30, x=68)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH160:    ; Path 160
    FCB 127              ; path160: intensity
    FCB $29,$46,0,0        ; path160: header (y=41, x=70)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$F5          ; flag=-1, dy=0, dx=-11
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH161:    ; Path 161
    FCB 127              ; path161: intensity
    FCB $2D,$3D,0,0        ; path161: header (y=45, x=61)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH162:    ; Path 162
    FCB 127              ; path162: intensity
    FCB $30,$43,0,0        ; path162: header (y=48, x=67)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH163:    ; Path 163
    FCB 127              ; path163: intensity
    FCB $33,$3E,0,0        ; path163: header (y=51, x=62)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH164:    ; Path 164
    FCB 127              ; path164: intensity
    FCB $27,$49,0,0        ; path164: header (y=39, x=73)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH165:    ; Path 165
    FCB 127              ; path165: intensity
    FCB $1E,$46,0,0        ; path165: header (y=30, x=70)
    FCB $FF,$FE,$06          ; flag=-1, dy=-2, dx=6
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH166:    ; Path 166
    FCB 127              ; path166: intensity
    FCB $C7,$0D,0,0        ; path166: header (y=-57, x=13)
    FCB $FF,$00,$F3          ; flag=-1, dy=0, dx=-13
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH167:    ; Path 167
    FCB 127              ; path167: intensity
    FCB $C7,$00,0,0        ; path167: header (y=-57, x=0)
    FCB $FF,$00,$F3          ; flag=-1, dy=0, dx=-13
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH168:    ; Path 168
    FCB 127              ; path168: intensity
    FCB $C0,$F2,0,0        ; path168: header (y=-64, x=-14)
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB 2                ; End marker (path complete)

_ANGKOR_BG_PATH169:    ; Path 169
    FCB 127              ; path169: intensity
    FCB $C0,$00,0,0        ; path169: header (y=-64, x=0)
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB 2                ; End marker (path complete)

; Generated from barcelona_bg.vec (Malban Draw_Sync_List format)
; Total paths: 60, points: 193
; X bounds: min=-47, max=69, width=116
; Center: (11, 13)

_BARCELONA_BG_WIDTH EQU 116
_BARCELONA_BG_HALF_WIDTH EQU 58
_BARCELONA_BG_HEIGHT EQU 128
_BARCELONA_BG_HALF_HEIGHT EQU 64
_BARCELONA_BG_CENTER_X EQU 11
_BARCELONA_BG_CENTER_Y EQU 13

_BARCELONA_BG_VECTORS:  ; Main entry (header + 50 path(s))
    FDB 50               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
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

_BARCELONA_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $F3,$F1,0,0        ; path0: header (y=-13, x=-15)
    FCB $FF,$0F,$00          ; flag=-1, dy=15, dx=0
    FCB $FF,$08,$03          ; flag=-1, dy=8, dx=3
    FCB $FF,$F7,$04          ; flag=-1, dy=-9, dx=4
    FCB $FF,$F2,$01          ; flag=-1, dy=-14, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $F2,$FC,0,0        ; path1: header (y=-14, x=-4)
    FCB $FF,$39,$01          ; flag=-1, dy=57, dx=1
    FCB $FF,$01,$FF          ; flag=-1, dy=1, dx=-1
    FCB $FF,$0D,$03          ; flag=-1, dy=13, dx=3
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$F1,$02          ; flag=-1, dy=-15, dx=2
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $2A,$02,0,0        ; path2: header (y=42, x=2)
    FCB $FF,$C0,$09          ; flag=-1, dy=-64, dx=9
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $EA,$0B,0,0        ; path3: header (y=-22, x=11)
    FCB $FF,$34,$FE          ; flag=-1, dy=52, dx=-2
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$0E,$02          ; flag=-1, dy=14, dx=2
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$F1,$04          ; flag=-1, dy=-15, dx=4
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$C7,$08          ; flag=-1, dy=-57, dx=8
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $F0,$13,0,0        ; path4: header (y=-16, x=19)
    FCB $FF,$10,$FE          ; flag=-1, dy=16, dx=-2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $02,$11,0,0        ; path5: header (y=2, x=17)
    FCB $FF,$17,$FD          ; flag=-1, dy=23, dx=-3
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $1C,$0F,0,0        ; path6: header (y=28, x=15)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$01,$FA          ; flag=-1, dy=1, dx=-6
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $1A,$0B,0,0        ; path7: header (y=26, x=11)
    FCB $FF,$E9,$01          ; flag=-1, dy=-23, dx=1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $00,$0C,0,0        ; path8: header (y=0, x=12)
    FCB $FF,$F3,$01          ; flag=-1, dy=-13, dx=1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $F1,$10,0,0        ; path9: header (y=-15, x=16)
    FCB $FF,$0F,$FF          ; flag=-1, dy=15, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $07,$05,0,0        ; path10: header (y=7, x=5)
    FCB $FF,$F0,$01          ; flag=-1, dy=-16, dx=1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $F9,$03,0,0        ; path11: header (y=-7, x=3)
    FCB $FF,$0E,$FF          ; flag=-1, dy=14, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $07,$FF,0,0        ; path12: header (y=7, x=-1)
    FCB $FF,$F4,$01          ; flag=-1, dy=-12, dx=1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $D7,$1A,0,0        ; path13: header (y=-41, x=26)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$0C,$FF          ; flag=-1, dy=12, dx=-1
    FCB $FF,$12,$DC          ; flag=-1, dy=18, dx=-36
    FCB $FF,$EE,$DC          ; flag=-1, dy=-18, dx=-36
    FCB $FF,$F5,$FE          ; flag=-1, dy=-11, dx=-2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $D5,$CD,0,0        ; path14: header (y=-43, x=-51)
    FCB $FF,$16,$28          ; flag=-1, dy=22, dx=40
    FCB $FF,$EA,$27          ; flag=-1, dy=-22, dx=39
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $C1,$21,0,0        ; path15: header (y=-63, x=33)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$13,$F6          ; flag=-1, dy=19, dx=-10
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$ED,$03          ; flag=-1, dy=-19, dx=3
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $C1,$14,0,0        ; path16: header (y=-63, x=20)
    FCB $FF,$18,$F9          ; flag=-1, dy=24, dx=-7
    FCB $FF,$01,$F7          ; flag=-1, dy=1, dx=-9
    FCB $FF,$F8,$01          ; flag=-1, dy=-8, dx=1
    FCB $FF,$EF,$04          ; flag=-1, dy=-17, dx=4
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $C1,$05,0,0        ; path17: header (y=-63, x=5)
    FCB $FF,$18,$F9          ; flag=-1, dy=24, dx=-7
    FCB $FF,$0A,$F7          ; flag=-1, dy=10, dx=-9
    FCB $FF,$F6,$F5          ; flag=-1, dy=-10, dx=-11
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH18:    ; Path 18
    FCB 127              ; path18: intensity
    FCB $D9,$EA,0,0        ; path18: header (y=-39, x=-22)
    FCB $FF,$E7,$F9          ; flag=-1, dy=-25, dx=-7
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH19:    ; Path 19
    FCB 127              ; path19: intensity
    FCB $C0,$E1,0,0        ; path19: header (y=-64, x=-31)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$19,$04          ; flag=-1, dy=25, dx=4
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH20:    ; Path 20
    FCB 127              ; path20: intensity
    FCB $D9,$E5,0,0        ; path20: header (y=-39, x=-27)
    FCB $FF,$FF,$F7          ; flag=-1, dy=-1, dx=-9
    FCB $FF,$E8,$F8          ; flag=-1, dy=-24, dx=-8
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH21:    ; Path 21
    FCB 127              ; path21: intensity
    FCB $C0,$D1,0,0        ; path21: header (y=-64, x=-47)
    FCB $FF,$14,$06          ; flag=-1, dy=20, dx=6
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$EC,$F9          ; flag=-1, dy=-20, dx=-7
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH22:    ; Path 22
    FCB 127              ; path22: intensity
    FCB $C0,$C6,0,0        ; path22: header (y=-64, x=-58)
    FCB $FF,$0D,$05          ; flag=-1, dy=13, dx=5
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$14,$2A          ; flag=-1, dy=20, dx=42
    FCB $FF,$EB,$2B          ; flag=-1, dy=-21, dx=43
    FCB $FF,$FD,$FD          ; flag=-1, dy=-3, dx=-3
    FCB $FF,$F3,$06          ; flag=-1, dy=-13, dx=6
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH23:    ; Path 23
    FCB 127              ; path23: intensity
    FCB $C1,$FA,0,0        ; path23: header (y=-63, x=-6)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$0B,$FF          ; flag=-1, dy=11, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH24:    ; Path 24
    FCB 127              ; path24: intensity
    FCB $CC,$F9,0,0        ; path24: header (y=-52, x=-7)
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB $FF,$FF,$FC          ; flag=-1, dy=-1, dx=-4
    FCB $FF,$F4,$FF          ; flag=-1, dy=-12, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH25:    ; Path 25
    FCB 127              ; path25: intensity
    FCB $E6,$F5,0,0        ; path25: header (y=-26, x=-11)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH26:    ; Path 26
    FCB 127              ; path26: intensity
    FCB $F1,$ED,0,0        ; path26: header (y=-15, x=-19)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$3B,$FF          ; flag=-1, dy=59, dx=-1
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB $FF,$0D,$FD          ; flag=-1, dy=13, dx=-3
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$F1,$FD          ; flag=-1, dy=-15, dx=-3
    FCB $FF,$FF,$01          ; flag=-1, dy=-1, dx=1
    FCB $FF,$C0,$FA          ; flag=-1, dy=-64, dx=-6
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH27:    ; Path 27
    FCB 127              ; path27: intensity
    FCB $EA,$E0,0,0        ; path27: header (y=-22, x=-32)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$35,$00          ; flag=-1, dy=53, dx=0
    FCB $FF,$00,$01          ; flag=-1, dy=0, dx=1
    FCB $FF,$0E,$FE          ; flag=-1, dy=14, dx=-2
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$F1,$FD          ; flag=-1, dy=-15, dx=-3
    FCB $FF,$00,$01          ; flag=-1, dy=0, dx=1
    FCB $FF,$C6,$F8          ; flag=-1, dy=-58, dx=-8
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH28:    ; Path 28
    FCB 127              ; path28: intensity
    FCB $F0,$D7,0,0        ; path28: header (y=-16, x=-41)
    FCB $FF,$10,$02          ; flag=-1, dy=16, dx=2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH29:    ; Path 29
    FCB 127              ; path29: intensity
    FCB $00,$DB,0,0        ; path29: header (y=0, x=-37)
    FCB $FF,$F1,$FF          ; flag=-1, dy=-15, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH30:    ; Path 30
    FCB 127              ; path30: intensity
    FCB $F3,$DD,0,0        ; path30: header (y=-13, x=-35)
    FCB $FF,$0D,$01          ; flag=-1, dy=13, dx=1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH31:    ; Path 31
    FCB 127              ; path31: intensity
    FCB $06,$DE,0,0        ; path31: header (y=6, x=-34)
    FCB $FF,$15,$00          ; flag=-1, dy=21, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH32:    ; Path 32
    FCB 127              ; path32: intensity
    FCB $1B,$DC,0,0        ; path32: header (y=27, x=-36)
    FCB $FF,$EB,$FE          ; flag=-1, dy=-21, dx=-2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH33:    ; Path 33
    FCB 127              ; path33: intensity
    FCB $07,$E5,0,0        ; path33: header (y=7, x=-27)
    FCB $FF,$F0,$FF          ; flag=-1, dy=-16, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH34:    ; Path 34
    FCB 127              ; path34: intensity
    FCB $F9,$E7,0,0        ; path34: header (y=-7, x=-25)
    FCB $FF,$0E,$01          ; flag=-1, dy=14, dx=1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH35:    ; Path 35
    FCB 127              ; path35: intensity
    FCB $07,$EB,0,0        ; path35: header (y=7, x=-21)
    FCB $FF,$F4,$FF          ; flag=-1, dy=-12, dx=-1
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH36:    ; Path 36
    FCB 127              ; path36: intensity
    FCB $0B,$ED,0,0        ; path36: header (y=11, x=-19)
    FCB $FF,$05,$07          ; flag=-1, dy=5, dx=7
    FCB $FF,$FC,$08          ; flag=-1, dy=-4, dx=8
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH37:    ; Path 37
    FCB 127              ; path37: intensity
    FCB $0E,$FE,0,0        ; path37: header (y=14, x=-2)
    FCB $FF,$1A,$00          ; flag=-1, dy=26, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH38:    ; Path 38
    FCB 127              ; path38: intensity
    FCB $2A,$FD,0,0        ; path38: header (y=42, x=-3)
    FCB $FF,$FF,$05          ; flag=-1, dy=-1, dx=5
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH39:    ; Path 39
    FCB 127              ; path39: intensity
    FCB $28,$01,0,0        ; path39: header (y=40, x=1)
    FCB $FF,$E5,$03          ; flag=-1, dy=-27, dx=3
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH40:    ; Path 40
    FCB 127              ; path40: intensity
    FCB $13,$FC,0,0        ; path40: header (y=19, x=-4)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$02,$F8          ; flag=-1, dy=2, dx=-8
    FCB $FF,$FD,$F9          ; flag=-1, dy=-3, dx=-7
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH41:    ; Path 41
    FCB 127              ; path41: intensity
    FCB $0E,$EB,0,0        ; path41: header (y=14, x=-21)
    FCB $FF,$1A,$00          ; flag=-1, dy=26, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH42:    ; Path 42
    FCB 127              ; path42: intensity
    FCB $28,$E8,0,0        ; path42: header (y=40, x=-24)
    FCB $FF,$E5,$FD          ; flag=-1, dy=-27, dx=-3
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH43:    ; Path 43
    FCB 127              ; path43: intensity
    FCB $0E,$E9,0,0        ; path43: header (y=14, x=-23)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH44:    ; Path 44
    FCB 127              ; path44: intensity
    FCB $1E,$E0,0,0        ; path44: header (y=30, x=-32)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$FF,$FB          ; flag=-1, dy=-1, dx=-5
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH45:    ; Path 45
    FCB 127              ; path45: intensity
    FCB $2D,$DF,0,0        ; path45: header (y=45, x=-33)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$03,$FE          ; flag=-1, dy=3, dx=-2
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$FD,$FE          ; flag=-1, dy=-3, dx=-2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH46:    ; Path 46
    FCB 127              ; path46: intensity
    FCB $2A,$E6,0,0        ; path46: header (y=42, x=-26)
    FCB $FF,$01,$06          ; flag=-1, dy=1, dx=6
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH47:    ; Path 47
    FCB 127              ; path47: intensity
    FCB $3A,$EA,0,0        ; path47: header (y=58, x=-22)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$FD,$FE          ; flag=-1, dy=-3, dx=-2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH48:    ; Path 48
    FCB 127              ; path48: intensity
    FCB $39,$01,0,0        ; path48: header (y=57, x=1)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$03,$FE          ; flag=-1, dy=3, dx=-2
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$FD,$FE          ; flag=-1, dy=-3, dx=-2
    FCB 2                ; End marker (path complete)

_BARCELONA_BG_PATH49:    ; Path 49
    FCB 127              ; path49: intensity
    FCB $2E,$0E,0,0        ; path49: header (y=46, x=14)
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB 2                ; End marker (path complete)

; Generated from map.vec (Malban Draw_Sync_List format)
; Total paths: 15, points: 165
; X bounds: min=-127, max=115, width=242
; Center: (-6, -3)

_MAP_WIDTH EQU 242
_MAP_HALF_WIDTH EQU 121
_MAP_HEIGHT EQU 162
_MAP_HALF_HEIGHT EQU 81
_MAP_CENTER_X EQU -6
_MAP_CENTER_Y EQU -3

_MAP_VECTORS:  ; Main entry (header + 15 path(s))
    FDB 15               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
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
    FCB $DD,$1A,0,0        ; path0: header (y=-35, x=26)
    FCB $FF,$09,$08          ; flag=-1, dy=9, dx=8
    FCB $FF,$01,$FA          ; flag=-1, dy=1, dx=-6
    FCB $FF,$F7,$FA          ; flag=-1, dy=-9, dx=-6
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $EE,$57,0,0        ; path1: header (y=-18, x=87)
    FCB $FF,$F8,$05          ; flag=-1, dy=-8, dx=5
    FCB $FF,$F9,$FF          ; flag=-1, dy=-7, dx=-1
    FCB $FF,$05,$FA          ; flag=-1, dy=5, dx=-6
    FCB $FF,$0A,$02          ; flag=-1, dy=10, dx=2
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $ED,$66,0,0        ; path2: header (y=-19, x=102)
    FCB $FF,$F1,$00          ; flag=-1, dy=-15, dx=0
    FCB $FF,$04,$F8          ; flag=-1, dy=4, dx=-8
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$06,$09          ; flag=-1, dy=6, dx=9
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $E6,$72,0,0        ; path3: header (y=-26, x=114)
    FCB $FF,$FD,$FB          ; flag=-1, dy=-3, dx=-5
    FCB $FF,$FB,$08          ; flag=-1, dy=-5, dx=8
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$04,$FD          ; flag=-1, dy=4, dx=-3
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $0E,$69,0,0        ; path4: header (y=14, x=105)
    FCB $FF,$08,$FC          ; flag=-1, dy=8, dx=-4
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$F5,$00          ; flag=-1, dy=-11, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $21,$6D,0,0        ; path5: header (y=33, x=109)
    FCB $FF,$F9,$FD          ; flag=-1, dy=-7, dx=-3
    FCB $FF,$FB,$02          ; flag=-1, dy=-5, dx=2
    FCB $FF,$FF,$03          ; flag=-1, dy=-1, dx=3
    FCB $FF,$05,$04          ; flag=-1, dy=5, dx=4
    FCB $FF,$08,$FC          ; flag=-1, dy=8, dx=-4
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $24,$69,0,0        ; path6: header (y=36, x=105)
    FCB $FF,$04,$07          ; flag=-1, dy=4, dx=7
    FCB $FF,$04,$F9          ; flag=-1, dy=4, dx=-7
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $BD,$70,0,0        ; path7: header (y=-67, x=112)
    FCB $FF,$08,$05          ; flag=-1, dy=8, dx=5
    FCB $FF,$14,$00          ; flag=-1, dy=20, dx=0
    FCB $FF,$06,$FB          ; flag=-1, dy=6, dx=-5
    FCB $FF,$F8,$FE          ; flag=-1, dy=-8, dx=-2
    FCB $FF,$06,$EE          ; flag=-1, dy=6, dx=-18
    FCB $FF,$F3,$F1          ; flag=-1, dy=-13, dx=-15
    FCB $FF,$F5,$07          ; flag=-1, dy=-11, dx=7
    FCB $FF,$03,$0C          ; flag=-1, dy=3, dx=12
    FCB $FF,$F4,$10          ; flag=-1, dy=-12, dx=16
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $21,$D7,0,0        ; path8: header (y=33, x=-41)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$01,$0D          ; flag=-1, dy=1, dx=13
    FCB $FF,$06,$12          ; flag=-1, dy=6, dx=18
    FCB $FF,$F7,$0C          ; flag=-1, dy=-9, dx=12
    FCB $FF,$FF,$DE          ; flag=-1, dy=-1, dx=-34
    FCB $FF,$F5,$F6          ; flag=-1, dy=-11, dx=-10
    FCB $FF,$F5,$00          ; flag=-1, dy=-11, dx=0
    FCB $FF,$F8,$08          ; flag=-1, dy=-8, dx=8
    FCB $FF,$00,$10          ; flag=-1, dy=0, dx=16
    FCB $FF,$F7,$08          ; flag=-1, dy=-9, dx=8
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB $FF,$F3,$0D          ; flag=-1, dy=-13, dx=13
    FCB $FF,$14,$13          ; flag=-1, dy=20, dx=19
    FCB $FF,$0D,$02          ; flag=-1, dy=13, dx=2
    FCB $FF,$0E,$09          ; flag=-1, dy=14, dx=9
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$0E,$F4          ; flag=-1, dy=14, dx=-12
    FCB $FF,$03,$03          ; flag=-1, dy=3, dx=3
    FCB $FF,$F2,$0D          ; flag=-1, dy=-14, dx=13
    FCB $FF,$0B,$07          ; flag=-1, dy=11, dx=7
    FCB $FF,$07,$FD          ; flag=-1, dy=7, dx=-3
    FCB $FF,$FB,$07          ; flag=-1, dy=-5, dx=7
    FCB $FF,$E0,$10          ; flag=-1, dy=-32, dx=16
    FCB $FF,$16,$09          ; flag=-1, dy=22, dx=9
    FCB $FF,$FA,$03          ; flag=-1, dy=-6, dx=3
    FCB $FF,$FB,$FF          ; flag=-1, dy=-5, dx=-1
    FCB $FF,$F2,$0A          ; flag=-1, dy=-14, dx=10
    FCB $FF,$04,$03          ; flag=-1, dy=4, dx=3
    FCB $FF,$09,$FB          ; flag=-1, dy=9, dx=-5
    FCB $FF,$01,$0A          ; flag=-1, dy=1, dx=10
    FCB $FF,$08,$02          ; flag=-1, dy=8, dx=2
    FCB $FF,$05,$05          ; flag=-1, dy=5, dx=5
    FCB $FF,$1E,$02          ; flag=-1, dy=30, dx=2
    FCB $FF,$0C,$FA          ; flag=-1, dy=12, dx=-6
    FCB $FF,$FE,$10          ; flag=-1, dy=-2, dx=16
    FCB $FF,$FA,$06          ; flag=-1, dy=-6, dx=6
    FCB $FF,$07,$02          ; flag=-1, dy=7, dx=2
    FCB $FF,$05,$04          ; flag=-1, dy=5, dx=4
    FCB $FF,$12,$E0          ; flag=-1, dy=18, dx=-32
    FCB $FF,$01,$EC          ; flag=-1, dy=1, dx=-20
    FCB $FF,$04,$FD          ; flag=-1, dy=4, dx=-3
    FCB $FF,$00,$DF          ; flag=-1, dy=0, dx=-33
    FCB $FF,$F8,$F6          ; flag=-1, dy=-8, dx=-10
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$F7,$F4          ; flag=-1, dy=-9, dx=-12
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$F9,$F4          ; flag=-1, dy=-7, dx=-12
    FCB $FF,$F2,$E6          ; flag=-1, dy=-14, dx=-26
    FCB 2                ; End marker (path complete)

_MAP_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $34,$E5,0,0        ; path9: header (y=52, x=-27)
    FCB $FF,$06,$0A          ; flag=-1, dy=6, dx=10
    FCB $FF,$06,$FE          ; flag=-1, dy=6, dx=-2
    FCB $FF,$02,$05          ; flag=-1, dy=2, dx=5
    FCB $FF,$FB,$FE          ; flag=-1, dy=-5, dx=-2
    FCB $FF,$F6,$02          ; flag=-1, dy=-10, dx=2
    FCB $FF,$FF,$F4          ; flag=-1, dy=-1, dx=-12
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $38,$DE,0,0        ; path10: header (y=56, x=-34)
    FCB $FF,$04,$06          ; flag=-1, dy=4, dx=6
    FCB $FF,$FC,$01          ; flag=-1, dy=-4, dx=1
    FCB $FF,$FD,$FC          ; flag=-1, dy=-3, dx=-4
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $4C,$B0,0,0        ; path11: header (y=76, x=-80)
    FCB $FF,$FC,$0D          ; flag=-1, dy=-4, dx=13
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$FA,$08          ; flag=-1, dy=-6, dx=8
    FCB $FF,$09,$06          ; flag=-1, dy=9, dx=6
    FCB $FF,$09,$F2          ; flag=-1, dy=9, dx=-14
    FCB $FF,$FF,$F6          ; flag=-1, dy=-1, dx=-10
    FCB $FF,$FC,$FD          ; flag=-1, dy=-4, dx=-3
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $2C,$88,0,0        ; path12: header (y=44, x=-120)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$21,$FF          ; flag=-1, dy=33, dx=-1
    FCB $FF,$FA,$19          ; flag=-1, dy=-6, dx=25
    FCB $FF,$F6,$12          ; flag=-1, dy=-10, dx=18
    FCB $FF,$F8,$FF          ; flag=-1, dy=-8, dx=-1
    FCB $FF,$FC,$0B          ; flag=-1, dy=-4, dx=11
    FCB $FF,$0C,$03          ; flag=-1, dy=12, dx=3
    FCB $FF,$F0,$0B          ; flag=-1, dy=-16, dx=11
    FCB $FF,$E8,$ED          ; flag=-1, dy=-24, dx=-19
    FCB $FF,$07,$FA          ; flag=-1, dy=7, dx=-6
    FCB $FF,$F7,$F2          ; flag=-1, dy=-9, dx=-14
    FCB $FF,$F3,$02          ; flag=-1, dy=-13, dx=2
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$F7,$0A          ; flag=-1, dy=-9, dx=10
    FCB $FF,$02,$EA          ; flag=-1, dy=2, dx=-22
    FCB $FF,$1C,$E9          ; flag=-1, dy=28, dx=-23
    FCB $FF,$09,$07          ; flag=-1, dy=9, dx=7
    FCB $FF,$09,$F8          ; flag=-1, dy=9, dx=-8
    FCB 2                ; End marker (path complete)

_MAP_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $04,$BE,0,0        ; path13: header (y=4, x=-66)
    FCB $FF,$ED,$F8          ; flag=-1, dy=-19, dx=-8
    FCB $FF,$F9,$06          ; flag=-1, dy=-7, dx=6
    FCB $FF,$E0,$05          ; flag=-1, dy=-32, dx=5
    FCB $FF,$19,$14          ; flag=-1, dy=25, dx=20
    FCB $FF,$FF,$08          ; flag=-1, dy=-1, dx=8
    FCB $FF,$10,$00          ; flag=-1, dy=16, dx=0
    FCB $FF,$03,$F7          ; flag=-1, dy=3, dx=-9
    FCB $FF,$09,$F8          ; flag=-1, dy=9, dx=-8
    FCB $FF,$06,$F3          ; flag=-1, dy=6, dx=-13
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_MAP_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $B0,$AE,0,0        ; path14: header (y=-80, x=-82)
    FCB $FF,$0D,$0C          ; flag=-1, dy=13, dx=12
    FCB $FF,$FB,$0D          ; flag=-1, dy=-5, dx=13
    FCB $FF,$F9,$08          ; flag=-1, dy=-7, dx=8
    FCB $FF,$FE,$DF          ; flag=-1, dy=-2, dx=-33
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

; Generated from athens_bg.vec (Malban Draw_Sync_List format)
; Total paths: 41, points: 147
; X bounds: min=-80, max=80, width=160
; Center: (0, 0)

_ATHENS_BG_WIDTH EQU 160
_ATHENS_BG_HALF_WIDTH EQU 80
_ATHENS_BG_HEIGHT EQU 150
_ATHENS_BG_HALF_HEIGHT EQU 75
_ATHENS_BG_CENTER_X EQU 0
_ATHENS_BG_CENTER_Y EQU 0

_ATHENS_BG_VECTORS:  ; Main entry (header + 33 path(s))
    FDB 33               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
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

_ATHENS_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $0A,$ED,0,0        ; path0: header (y=10, x=-19)
    FCB $FF,$C5,$00          ; flag=-1, dy=-59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $CD,$EE,0,0        ; path1: header (y=-51, x=-18)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $CF,$E3,0,0        ; path2: header (y=-49, x=-29)
    FCB $FF,$3B,$00          ; flag=-1, dy=59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $0C,$E2,0,0        ; path3: header (y=12, x=-30)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $0F,$F0,0,0        ; path4: header (y=15, x=-16)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $0F,$D8,0,0        ; path5: header (y=15, x=-40)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $0C,$CA,0,0        ; path6: header (y=12, x=-54)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $0A,$D5,0,0        ; path7: header (y=10, x=-43)
    FCB $FF,$C5,$00          ; flag=-1, dy=-59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $CD,$D6,0,0        ; path8: header (y=-51, x=-42)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $CF,$CB,0,0        ; path9: header (y=-49, x=-53)
    FCB $FF,$3B,$00          ; flag=-1, dy=59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $14,$C6,0,0        ; path10: header (y=20, x=-58)
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$00,$7A          ; flag=-1, dy=0, dx=122
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $0F,$36,0,0        ; path11: header (y=15, x=54)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $0C,$28,0,0        ; path12: header (y=12, x=40)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $0A,$33,0,0        ; path13: header (y=10, x=51)
    FCB $FF,$C5,$00          ; flag=-1, dy=-59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $CD,$34,0,0        ; path14: header (y=-51, x=52)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $CF,$29,0,0        ; path15: header (y=-49, x=41)
    FCB $FF,$3B,$00          ; flag=-1, dy=59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $0F,$22,0,0        ; path16: header (y=15, x=34)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $0C,$14,0,0        ; path17: header (y=12, x=20)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH18:    ; Path 18
    FCB 127              ; path18: intensity
    FCB $0A,$1F,0,0        ; path18: header (y=10, x=31)
    FCB $FF,$C5,$00          ; flag=-1, dy=-59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH19:    ; Path 19
    FCB 127              ; path19: intensity
    FCB $CD,$20,0,0        ; path19: header (y=-51, x=32)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH20:    ; Path 20
    FCB 127              ; path20: intensity
    FCB $CF,$15,0,0        ; path20: header (y=-49, x=21)
    FCB $FF,$3B,$00          ; flag=-1, dy=59, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH21:    ; Path 21
    FCB 127              ; path21: intensity
    FCB $1F,$39,0,0        ; path21: header (y=31, x=57)
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$F5,$00          ; flag=-1, dy=-11, dx=0
    FCB $FF,$00,$8E          ; flag=-1, dy=0, dx=-114
    FCB $FF,$0B,$00          ; flag=-1, dy=11, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH22:    ; Path 22
    FCB 127              ; path22: intensity
    FCB $26,$C3,0,0        ; path22: header (y=38, x=-61)
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB $FF,$00,$78          ; flag=-1, dy=0, dx=120
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH23:    ; Path 23
    FCB 127              ; path23: intensity
    FCB $26,$38,0,0        ; path23: header (y=38, x=56)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH24:    ; Path 24
    FCB 127              ; path24: intensity
    FCB $CA,$26,0,0        ; path24: header (y=-54, x=38)
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH25:    ; Path 25
    FCB 127              ; path25: intensity
    FCB $C4,$44,0,0        ; path25: header (y=-60, x=68)
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$BD          ; sub-seg 1/2 of line 1: dy=0, dx=-67
    FCB $FF,$00,$BC          ; sub-seg 2/2 of line 1: dy=0, dx=-68
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH26:    ; Path 26
    FCB 127              ; path26: intensity
    FCB $BC,$B7,0,0        ; path26: header (y=-68, x=-73)
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$49          ; sub-seg 1/2 of line 1: dy=0, dx=73
    FCB $FF,$00,$49          ; sub-seg 2/2 of line 1: dy=0, dx=73
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH27:    ; Path 27
    FCB 127              ; path27: intensity
    FCB $CA,$22,0,0        ; path27: header (y=-54, x=34)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH28:    ; Path 28
    FCB 127              ; path28: intensity
    FCB $CA,$F0,0,0        ; path28: header (y=-54, x=-16)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH29:    ; Path 29
    FCB 127              ; path29: intensity
    FCB $CA,$D8,0,0        ; path29: header (y=-54, x=-40)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH30:    ; Path 30
    FCB 127              ; path30: intensity
    FCB $B5,$B0,0,0        ; path30: header (y=-75, x=-80)
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB $FF,$00,$50          ; sub-seg 1/2 of line 1: dy=0, dx=80
    FCB $FF,$00,$50          ; sub-seg 2/2 of line 1: dy=0, dx=80
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB $FF,$00,$B0          ; sub-seg 1/2 of line 3: dy=0, dx=-80
    FCB $FF,$00,$B0          ; sub-seg 2/2 of line 3: dy=0, dx=-80
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH31:    ; Path 31
    FCB 127              ; path31: intensity
    FCB $26,$C1,0,0        ; path31: header (y=38, x=-63)
    FCB $FF,$25,$3E          ; flag=-1, dy=37, dx=62
    FCB $FF,$DB,$3F          ; flag=-1, dy=-37, dx=63
    FCB $FF,$00,$83          ; flag=-1, dy=0, dx=-125
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ATHENS_BG_PATH32:    ; Path 32
    FCB 127              ; path32: intensity
    FCB $29,$D2,0,0        ; path32: header (y=41, x=-46)
    FCB $FF,$1C,$2D          ; flag=-1, dy=28, dx=45
    FCB $FF,$E4,$2F          ; flag=-1, dy=-28, dx=47
    FCB $FF,$00,$A4          ; flag=-1, dy=0, dx=-92
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

; Generated from map_theme.vmus (internal name: Space Groove)
; Tempo: 140 BPM, Total events: 36 (PSG Direct format)
; Format: FCB count, FCB reg, val, ... (per frame), FCB 0 (end)

_MAP_THEME_MUSIC:
    ; Frame-based PSG register writes
    FCB     0              ; Delay 0 frames (maintain previous state)
    FCB     11              ; Frame 0 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $14             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 5 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     11              ; Frame 10 - 11 register writes
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
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 13 - 10 register writes
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
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     9              ; Frame 21 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $32             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     8              ; Frame 24 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3A             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     9              ; Frame 32 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $32             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 34 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $51             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3A             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     11              ; Frame 42 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $14             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     10              ; Frame 48 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     11              ; Frame 53 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 56 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     9              ; Frame 64 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $C8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $32             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 66 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $C8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3A             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     9              ; Frame 75 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0B             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $32             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 77 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0B             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3A             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     11              ; Frame 85 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $E1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $14             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     10              ; Frame 91 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $E1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     11              ; Frame 96 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $E1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     10              ; Frame 99 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $E1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     9              ; Frame 107 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $70             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0F             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $E1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $32             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 109 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $70             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0F             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $E1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3A             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     9              ; Frame 117 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $70             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0F             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $E1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $32             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     8              ; Frame 120 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $70             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0F             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $E1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3A             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     11              ; Frame 128 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $14             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 133 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     11              ; Frame 139 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     10              ; Frame 141 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0B             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     9              ; Frame 150 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $32             ; Reg 7 value
    FCB     2              ; Delay 2 frames (maintain previous state)
    FCB     8              ; Frame 152 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3A             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     9              ; Frame 160 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $03             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $32             ; Reg 7 value
    FCB     3              ; Delay 3 frames (maintain previous state)
    FCB     8              ; Frame 163 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $0B             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $01             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $09             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $3A             ; Reg 7 value
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
    FCB     4              ; Delay 4 frames before loop
    FCB     $FF             ; Loop command ($FF never valid as count)
    FDB     _MAP_THEME_MUSIC       ; Jump to start (absolute address)


; Generated from ayers_bg.vec (Malban Draw_Sync_List format)
; Total paths: 18, points: 106
; X bounds: min=-96, max=102, width=198
; Center: (3, 10)

_AYERS_BG_WIDTH EQU 198
_AYERS_BG_HALF_WIDTH EQU 99
_AYERS_BG_HEIGHT EQU 63
_AYERS_BG_HALF_HEIGHT EQU 31
_AYERS_BG_CENTER_X EQU 3
_AYERS_BG_CENTER_Y EQU 10

_AYERS_BG_VECTORS:  ; Main entry (header + 18 path(s))
    FDB 18               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
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
    FCB $E1,$07,0,0        ; path0: header (y=-31, x=7)
    FCB $FF,$06,$F8          ; flag=-1, dy=6, dx=-8
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB $FF,$13,$FC          ; flag=-1, dy=19, dx=-4
    FCB $FF,$F6,$FE          ; flag=-1, dy=-10, dx=-2
    FCB $FF,$F6,$01          ; flag=-1, dy=-10, dx=1
    FCB $FF,$00,$F3          ; flag=-1, dy=0, dx=-13
    FCB $FF,$03,$FD          ; flag=-1, dy=3, dx=-3
    FCB $FF,$FA,$FC          ; flag=-1, dy=-6, dx=-4
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $E4,$E3,0,0        ; path1: header (y=-28, x=-29)
    FCB $FF,$04,$F5          ; flag=-1, dy=4, dx=-11
    FCB $FF,$20,$05          ; flag=-1, dy=32, dx=5
    FCB $FF,$F9,$FA          ; flag=-1, dy=-7, dx=-6
    FCB $FF,$EF,$FE          ; flag=-1, dy=-17, dx=-2
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$FD,$FA          ; flag=-1, dy=-3, dx=-6
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $E2,$CF,0,0        ; path2: header (y=-30, x=-49)
    FCB $FF,$0E,$FF          ; flag=-1, dy=14, dx=-1
    FCB $FF,$12,$03          ; flag=-1, dy=18, dx=3
    FCB $FF,$17,$05          ; flag=-1, dy=23, dx=5
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $18,$D3,0,0        ; path3: header (y=24, x=-45)
    FCB $FF,$E0,$F9          ; flag=-1, dy=-32, dx=-7
    FCB $FF,$EA,$F8          ; flag=-1, dy=-22, dx=-8
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $E2,$BE,0,0        ; path4: header (y=-30, x=-66)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$19,$04          ; flag=-1, dy=25, dx=4
    FCB $FF,$0B,$01          ; flag=-1, dy=11, dx=1
    FCB $FF,$F8,$FA          ; flag=-1, dy=-8, dx=-6
    FCB $FF,$E4,$FE          ; flag=-1, dy=-28, dx=-2
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $E2,$A7,0,0        ; path5: header (y=-30, x=-89)
    FCB $FF,$19,$08          ; flag=-1, dy=25, dx=8
    FCB $FF,$16,$07          ; flag=-1, dy=22, dx=7
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $19,$E9,0,0        ; path6: header (y=25, x=-23)
    FCB $FF,$EF,$FD          ; flag=-1, dy=-17, dx=-3
    FCB $FF,$F2,$03          ; flag=-1, dy=-14, dx=3
    FCB $FF,$F5,$00          ; flag=-1, dy=-11, dx=0
    FCB $FF,$09,$05          ; flag=-1, dy=9, dx=5
    FCB $FF,$0C,$06          ; flag=-1, dy=12, dx=6
    FCB $FF,$18,$06          ; flag=-1, dy=24, dx=6
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $1B,$F7,0,0        ; path7: header (y=27, x=-9)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$ED,$FA          ; flag=-1, dy=-19, dx=-6
    FCB $FF,$F7,$FC          ; flag=-1, dy=-9, dx=-4
    FCB $FF,$0A,$FD          ; flag=-1, dy=10, dx=-3
    FCB $FF,$11,$06          ; flag=-1, dy=17, dx=6
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $20,$07,0,0        ; path8: header (y=32, x=7)
    FCB $FF,$F0,$02          ; flag=-1, dy=-16, dx=2
    FCB $FF,$F2,$FA          ; flag=-1, dy=-14, dx=-6
    FCB $FF,$EF,$01          ; flag=-1, dy=-17, dx=1
    FCB $FF,$0B,$03          ; flag=-1, dy=11, dx=3
    FCB $FF,$0E,$04          ; flag=-1, dy=14, dx=4
    FCB $FF,$13,$07          ; flag=-1, dy=19, dx=7
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $19,$1F,0,0        ; path9: header (y=25, x=31)
    FCB $FF,$EB,$0A          ; flag=-1, dy=-21, dx=10
    FCB $FF,$E6,$01          ; flag=-1, dy=-26, dx=1
    FCB $FF,$F7,$FF          ; flag=-1, dy=-9, dx=-1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $E1,$25,0,0        ; path10: header (y=-31, x=37)
    FCB $FF,$08,$F9          ; flag=-1, dy=8, dx=-7
    FCB $FF,$1A,$FC          ; flag=-1, dy=26, dx=-4
    FCB $FF,$E6,$FE          ; flag=-1, dy=-26, dx=-2
    FCB $FF,$F9,$F9          ; flag=-1, dy=-7, dx=-7
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $E2,$10,0,0        ; path11: header (y=-30, x=16)
    FCB $FF,$16,$00          ; flag=-1, dy=22, dx=0
    FCB $FF,$0F,$01          ; flag=-1, dy=15, dx=1
    FCB $FF,$ED,$FA          ; flag=-1, dy=-19, dx=-6
    FCB $FF,$EE,$FF          ; flag=-1, dy=-18, dx=-1
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $E2,$2F,0,0        ; path12: header (y=-30, x=47)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$25,$FD          ; flag=-1, dy=37, dx=-3
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $06,$2C,0,0        ; path13: header (y=6, x=44)
    FCB $FF,$13,$F7          ; flag=-1, dy=19, dx=-9
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $16,$38,0,0        ; path14: header (y=22, x=56)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$E5,$02          ; flag=-1, dy=-27, dx=2
    FCB $FF,$E6,$02          ; flag=-1, dy=-26, dx=2
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $E1,$4C,0,0        ; path15: header (y=-31, x=76)
    FCB $FF,$15,$FC          ; flag=-1, dy=21, dx=-4
    FCB $FF,$03,$FD          ; flag=-1, dy=3, dx=-3
    FCB $FF,$10,$FE          ; flag=-1, dy=16, dx=-2
    FCB $FF,$EE,$FE          ; flag=-1, dy=-18, dx=-2
    FCB $FF,$1F,$F7          ; flag=-1, dy=31, dx=-9
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $00,$52,0,0        ; path16: header (y=0, x=82)
    FCB $FF,$E6,$05          ; flag=-1, dy=-26, dx=5
    FCB $FF,$1E,$F3          ; flag=-1, dy=30, dx=-13
    FCB $FF,$DD,$09          ; flag=-1, dy=-35, dx=9
    FCB 2                ; End marker (path complete)

_AYERS_BG_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $E2,$9D,0,0        ; path17: header (y=-30, x=-99)
    FCB $FF,$2A,$0C          ; flag=-1, dy=42, dx=12
    FCB $FF,$05,$0D          ; flag=-1, dy=5, dx=13
    FCB $FF,$04,$0F          ; flag=-1, dy=4, dx=15
    FCB $FF,$03,$0F          ; flag=-1, dy=3, dx=15
    FCB $FF,$05,$09          ; flag=-1, dy=5, dx=9
    FCB $FF,$FC,$0C          ; flag=-1, dy=-4, dx=12
    FCB $FF,$02,$0E          ; flag=-1, dy=2, dx=14
    FCB $FF,$05,$0C          ; flag=-1, dy=5, dx=12
    FCB $FF,$FF,$0C          ; flag=-1, dy=-1, dx=12
    FCB $FF,$FA,$0D          ; flag=-1, dy=-6, dx=13
    FCB $FF,$01,$10          ; flag=-1, dy=1, dx=16
    FCB $FF,$FB,$0E          ; flag=-1, dy=-5, dx=14
    FCB $FF,$F5,$10          ; flag=-1, dy=-11, dx=16
    FCB $FF,$F2,$0B          ; flag=-1, dy=-14, dx=11
    FCB $FF,$EE,$0B          ; flag=-1, dy=-18, dx=11
    FCB $FF,$F7,$03          ; flag=-1, dy=-9, dx=3
    FCB $FF,$00,$9D          ; sub-seg 1/2 of line 16: dy=0, dx=-99
    FCB $FF,$01,$9D          ; sub-seg 2/2 of line 16: dy=1, dx=-99
    FCB 2                ; End marker (path complete)

; Generated from antarctica_bg.vec (Malban Draw_Sync_List format)
; Total paths: 20, points: 91
; X bounds: min=-119, max=104, width=223
; Center: (-7, 46)

_ANTARCTICA_BG_WIDTH EQU 223
_ANTARCTICA_BG_HALF_WIDTH EQU 111
_ANTARCTICA_BG_HEIGHT EQU 93
_ANTARCTICA_BG_HALF_HEIGHT EQU 46
_ANTARCTICA_BG_CENTER_X EQU -7
_ANTARCTICA_BG_CENTER_Y EQU 46

_ANTARCTICA_BG_VECTORS:  ; Main entry (header + 19 path(s))
    FDB 19               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
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

_ANTARCTICA_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $E9,$1A,0,0        ; path0: header (y=-23, x=26)
    FCB $FF,$09,$EB          ; flag=-1, dy=9, dx=-21
    FCB $FF,$F0,$D6          ; flag=-1, dy=-16, dx=-42
    FCB $FF,$F1,$FB          ; flag=-1, dy=-15, dx=-5
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $F7,$F3,0,0        ; path1: header (y=-9, x=-13)
    FCB $FF,$13,$FB          ; flag=-1, dy=19, dx=-5
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB $FF,$0F,$F8          ; flag=-1, dy=15, dx=-8
    FCB $FF,$02,$EF          ; flag=-1, dy=2, dx=-17
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $EF,$FD,0,0        ; path2: header (y=-17, x=-3)
    FCB $FF,$07,$F8          ; flag=-1, dy=7, dx=-8
    FCB $FF,$0A,$EA          ; flag=-1, dy=10, dx=-22
    FCB $FF,$E9,$DE          ; flag=-1, dy=-23, dx=-34
    FCB $FF,$FD,$DF          ; flag=-1, dy=-3, dx=-33
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $D3,$90,0,0        ; path3: header (y=-45, x=-112)
    FCB $FF,$00,$4C          ; sub-seg 1/2 of line 0: dy=0, dx=76
    FCB $FF,$00,$4D          ; sub-seg 2/2 of line 0: dy=0, dx=77
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $D3,$29,0,0        ; path4: header (y=-45, x=41)
    FCB $FF,$41,$D5          ; flag=-1, dy=65, dx=-43
    FCB $FF,$FA,$F9          ; flag=-1, dy=-6, dx=-7
    FCB $FF,$21,$E4          ; flag=-1, dy=33, dx=-28
    FCB $FF,$DF,$E7          ; flag=-1, dy=-33, dx=-25
    FCB $FF,$07,$F7          ; flag=-1, dy=7, dx=-9
    FCB $FF,$BE,$D7          ; flag=-1, dy=-66, dx=-41
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $D9,$33,0,0        ; path5: header (y=-39, x=51)
    FCB $FF,$09,$06          ; flag=-1, dy=9, dx=6
    FCB $FF,$02,$05          ; flag=-1, dy=2, dx=5
    FCB $FF,$FA,$06          ; flag=-1, dy=-6, dx=6
    FCB $FF,$F4,$01          ; flag=-1, dy=-12, dx=1
    FCB $FF,$02,$FD          ; flag=-1, dy=2, dx=-3
    FCB $FF,$06,$FF          ; flag=-1, dy=6, dx=-1
    FCB $FF,$06,$FD          ; flag=-1, dy=6, dx=-3
    FCB $FF,$FE,$FB          ; flag=-1, dy=-2, dx=-5
    FCB $FF,$FA,$FC          ; flag=-1, dy=-6, dx=-4
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $D9,$33,0,0        ; path6: header (y=-39, x=51)
    FCB $FF,$F9,$12          ; flag=-1, dy=-7, dx=18
    FCB $FF,$04,$07          ; flag=-1, dy=4, dx=7
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$00,$0D          ; flag=-1, dy=0, dx=13
    FCB $FF,$01,$0A          ; flag=-1, dy=1, dx=10
    FCB $FF,$03,$08          ; flag=-1, dy=3, dx=8
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $DA,$6F,0,0        ; path7: header (y=-38, x=111)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$0A,$FB          ; flag=-1, dy=10, dx=-5
    FCB $FF,$06,$FC          ; flag=-1, dy=6, dx=-4
    FCB $FF,$04,$F8          ; flag=-1, dy=4, dx=-8
    FCB $FF,$01,$F9          ; flag=-1, dy=1, dx=-7
    FCB $FF,$FF,$F5          ; flag=-1, dy=-1, dx=-11
    FCB $FF,$FB,$F9          ; flag=-1, dy=-5, dx=-7
    FCB $FF,$FB,$FB          ; flag=-1, dy=-5, dx=-5
    FCB $FF,$FA,$FC          ; flag=-1, dy=-6, dx=-4
    FCB $FF,$FA,$FD          ; flag=-1, dy=-6, dx=-3
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $E4,$3E,0,0        ; path8: header (y=-28, x=62)
    FCB $FF,$02,$09          ; flag=-1, dy=2, dx=9
    FCB $FF,$FD,$03          ; flag=-1, dy=-3, dx=3
    FCB $FF,$FA,$02          ; flag=-1, dy=-6, dx=2
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $D6,$51,0,0        ; path9: header (y=-42, x=81)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$0B,$02          ; flag=-1, dy=11, dx=2
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $E1,$58,0,0        ; path10: header (y=-31, x=88)
    FCB $FF,$0B,$01          ; flag=-1, dy=11, dx=1
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $EB,$51,0,0        ; path11: header (y=-21, x=81)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$0A,$01          ; flag=-1, dy=10, dx=1
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $F6,$49,0,0        ; path12: header (y=-10, x=73)
    FCB $FF,$FF,$09          ; flag=-1, dy=-1, dx=9
    FCB $FF,$01,$08          ; flag=-1, dy=1, dx=8
    FCB $FF,$01,$06          ; flag=-1, dy=1, dx=6
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $F6,$5B,0,0        ; path13: header (y=-10, x=91)
    FCB $FF,$F8,$07          ; flag=-1, dy=-8, dx=7
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $EE,$65,0,0        ; path14: header (y=-18, x=101)
    FCB $FF,$F5,$06          ; flag=-1, dy=-11, dx=6
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $E4,$6F,0,0        ; path15: header (y=-28, x=111)
    FCB $FF,$FF,$FC          ; flag=-1, dy=-1, dx=-4
    FCB $FF,$FE,$EB          ; flag=-1, dy=-2, dx=-21
    FCB $FF,$FF,$F5          ; flag=-1, dy=-1, dx=-11
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $E6,$47,0,0        ; path16: header (y=-26, x=71)
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB $FF,$05,$02          ; flag=-1, dy=5, dx=2
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $EC,$3F,0,0        ; path17: header (y=-20, x=63)
    FCB $FF,$FF,$08          ; flag=-1, dy=-1, dx=8
    FCB $FF,$00,$0D          ; flag=-1, dy=0, dx=13
    FCB $FF,$02,$0B          ; flag=-1, dy=2, dx=11
    FCB $FF,$02,$0A          ; flag=-1, dy=2, dx=10
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_ANTARCTICA_BG_PATH18:    ; Path 18
    FCB 127              ; path18: intensity
    FCB $E2,$60,0,0        ; path18: header (y=-30, x=96)
    FCB $FF,$F5,$05          ; flag=-1, dy=-11, dx=5
    FCB 2                ; End marker (path complete)

; Generated from pang_theme.vmus (internal name: pang_theme)
; Tempo: 150 BPM, Total events: 34 (PSG Direct format)
; Format: FCB count, FCB reg, val, ... (per frame), FCB 0 (end)

_PANG_THEME_MUSIC:
    ; Frame-based PSG register writes
    FCB     0              ; Delay 0 frames (maintain previous state)
    FCB     11              ; Frame 0 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $0B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     10              ; Frame 10 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $0B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     10              ; Frame 20 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $0B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     20              ; Delay 20 frames (maintain previous state)
    FCB     11              ; Frame 40 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $70             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $E1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     10              ; Frame 50 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $70             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $E1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     10              ; Frame 60 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $54             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $E1             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     20              ; Delay 20 frames (maintain previous state)
    FCB     11              ; Frame 80 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $70             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     10              ; Frame 90 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $70             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     10              ; Frame 100 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $85             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     20              ; Delay 20 frames (maintain previous state)
    FCB     11              ; Frame 120 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $0B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     10              ; Frame 130 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $0B             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $44             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $05             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     30              ; Delay 30 frames (maintain previous state)
    FCB     11              ; Frame 160 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $FC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     10              ; Frame 170 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $FC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     10              ; Frame 180 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $FC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     20              ; Delay 20 frames (maintain previous state)
    FCB     11              ; Frame 200 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $64             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     10              ; Frame 210 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $64             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     10              ; Frame 220 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $4B             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C8             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     20              ; Delay 20 frames (maintain previous state)
    FCB     11              ; Frame 240 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $64             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $96             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     10              ; Frame 250 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $64             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $96             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     10              ; Frame 260 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $7E             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $96             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     20              ; Delay 20 frames (maintain previous state)
    FCB     11              ; Frame 280 - 11 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $FC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $04             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $08             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0F             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $30             ; Reg 7 value
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     10              ; Frame 290 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $FC             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $00             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $B1             ; Reg 4 value
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
    FCB     26              ; Delay 26 frames before loop
    FCB     $FF             ; Loop command ($FF never valid as count)
    FDB     _PANG_THEME_MUSIC       ; Jump to start (absolute address)


; Generated from player_walk_1.vec (Malban Draw_Sync_List format)
; Total paths: 17, points: 62
; X bounds: min=-8, max=11, width=19
; Center: (1, 0)

_PLAYER_WALK_1_WIDTH EQU 19
_PLAYER_WALK_1_HALF_WIDTH EQU 9
_PLAYER_WALK_1_HEIGHT EQU 29
_PLAYER_WALK_1_HALF_HEIGHT EQU 14
_PLAYER_WALK_1_CENTER_X EQU 1
_PLAYER_WALK_1_CENTER_Y EQU 0

_PLAYER_WALK_1_VECTORS:  ; Main entry (header + 17 path(s))
    FDB 17               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
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
    FCB $FE,$01,0,0        ; path0: header (y=-2, x=1)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $F8,$01,0,0        ; path1: header (y=-8, x=1)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $F2,$01,0,0        ; path2: header (y=-14, x=1)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $F1,$FB,0,0        ; path3: header (y=-15, x=-5)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $F2,$FB,0,0        ; path4: header (y=-14, x=-5)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $F8,$FB,0,0        ; path5: header (y=-8, x=-5)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $FE,$FA,0,0        ; path6: header (y=-2, x=-6)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $08,$FB,0,0        ; path7: header (y=8, x=-5)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $0C,$FB,0,0        ; path8: header (y=12, x=-5)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $0C,$F9,0,0        ; path9: header (y=12, x=-7)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $07,$04,0,0        ; path10: header (y=7, x=4)
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $06,$06,0,0        ; path11: header (y=6, x=6)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $03,$06,0,0        ; path12: header (y=3, x=6)
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $03,$07,0,0        ; path13: header (y=3, x=7)
    FCB $FF,$00,$01          ; flag=-1, dy=0, dx=1
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $00,$F9,0,0        ; path14: header (y=0, x=-7)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $06,$F9,0,0        ; path15: header (y=6, x=-7)
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_1_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $00,$F9,0,0        ; path16: header (y=0, x=-7)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

; Generated from player_walk_2.vec (Malban Draw_Sync_List format)
; Total paths: 17, points: 62
; X bounds: min=-10, max=11, width=21
; Center: (0, -1)

_PLAYER_WALK_2_WIDTH EQU 21
_PLAYER_WALK_2_HALF_WIDTH EQU 10
_PLAYER_WALK_2_HEIGHT EQU 31
_PLAYER_WALK_2_HALF_HEIGHT EQU 15
_PLAYER_WALK_2_CENTER_X EQU 0
_PLAYER_WALK_2_CENTER_Y EQU -1

_PLAYER_WALK_2_VECTORS:  ; Main entry (header + 17 path(s))
    FDB 17               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
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
    FCB $FF,$02,0,0        ; path0: header (y=-1, x=2)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$F9,$01          ; flag=-1, dy=-7, dx=1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$07,$FF          ; flag=-1, dy=7, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $F8,$03,0,0        ; path1: header (y=-8, x=3)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$F9,$01          ; flag=-1, dy=-7, dx=1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$07,$FF          ; flag=-1, dy=7, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $F1,$04,0,0        ; path2: header (y=-15, x=4)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $F2,$00,0,0        ; path3: header (y=-14, x=0)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $F3,$FE,0,0        ; path4: header (y=-13, x=-2)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $F9,$FC,0,0        ; path5: header (y=-7, x=-4)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$06,$FF          ; flag=-1, dy=6, dx=-1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FA,$01          ; flag=-1, dy=-6, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $FF,$FB,0,0        ; path6: header (y=-1, x=-5)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $09,$FC,0,0        ; path7: header (y=9, x=-4)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $0D,$FC,0,0        ; path8: header (y=13, x=-4)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $0D,$FA,0,0        ; path9: header (y=13, x=-6)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $08,$05,0,0        ; path10: header (y=8, x=5)
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $07,$07,0,0        ; path11: header (y=7, x=7)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $04,$07,0,0        ; path12: header (y=4, x=7)
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $04,$08,0,0        ; path13: header (y=4, x=8)
    FCB $FF,$00,$01          ; flag=-1, dy=0, dx=1
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $08,$FB,0,0        ; path14: header (y=8, x=-5)
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $07,$F9,0,0        ; path15: header (y=7, x=-7)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FC,$FF          ; flag=-1, dy=-4, dx=-1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$04,$01          ; flag=-1, dy=4, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_2_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $03,$F8,0,0        ; path16: header (y=3, x=-8)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

; Generated from player_walk_3.vec (Malban Draw_Sync_List format)
; Total paths: 17, points: 62
; X bounds: min=-9, max=11, width=20
; Center: (1, -1)

_PLAYER_WALK_3_WIDTH EQU 20
_PLAYER_WALK_3_HALF_WIDTH EQU 10
_PLAYER_WALK_3_HEIGHT EQU 30
_PLAYER_WALK_3_HALF_HEIGHT EQU 15
_PLAYER_WALK_3_CENTER_X EQU 1
_PLAYER_WALK_3_CENTER_Y EQU -1

_PLAYER_WALK_3_VECTORS:  ; Main entry (header + 17 path(s))
    FDB 17               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
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
    FCB $FF,$02,0,0        ; path0: header (y=-1, x=2)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$F9,$01          ; flag=-1, dy=-7, dx=1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$07,$FF          ; flag=-1, dy=7, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $F8,$03,0,0        ; path1: header (y=-8, x=3)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $F2,$03,0,0        ; path2: header (y=-14, x=3)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $F1,$FB,0,0        ; path3: header (y=-15, x=-5)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $F2,$FB,0,0        ; path4: header (y=-14, x=-5)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $F8,$F9,0,0        ; path5: header (y=-8, x=-7)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$07,$01          ; flag=-1, dy=7, dx=1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$F9,$FF          ; flag=-1, dy=-7, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $FF,$FA,0,0        ; path6: header (y=-1, x=-6)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $09,$FB,0,0        ; path7: header (y=9, x=-5)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $0D,$FB,0,0        ; path8: header (y=13, x=-5)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $0D,$F9,0,0        ; path9: header (y=13, x=-7)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $08,$04,0,0        ; path10: header (y=8, x=4)
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $07,$06,0,0        ; path11: header (y=7, x=6)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $04,$06,0,0        ; path12: header (y=4, x=6)
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $04,$07,0,0        ; path13: header (y=4, x=7)
    FCB $FF,$00,$01          ; flag=-1, dy=0, dx=1
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $08,$FA,0,0        ; path14: header (y=8, x=-6)
    FCB $FF,$FF,$FF          ; flag=-1, dy=-1, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $07,$F9,0,0        ; path15: header (y=7, x=-7)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$F9,$FF          ; flag=-1, dy=-7, dx=-1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$07,$01          ; flag=-1, dy=7, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_3_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $00,$F8,0,0        ; path16: header (y=0, x=-8)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

; Generated from player_walk_4.vec (Malban Draw_Sync_List format)
; Total paths: 17, points: 62
; X bounds: min=-8, max=11, width=19
; Center: (1, -1)

_PLAYER_WALK_4_WIDTH EQU 19
_PLAYER_WALK_4_HALF_WIDTH EQU 9
_PLAYER_WALK_4_HEIGHT EQU 31
_PLAYER_WALK_4_HALF_HEIGHT EQU 15
_PLAYER_WALK_4_CENTER_X EQU 1
_PLAYER_WALK_4_CENTER_Y EQU -1

_PLAYER_WALK_4_VECTORS:  ; Main entry (header + 17 path(s))
    FDB 17               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
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
    FCB $FF,$01,0,0        ; path0: header (y=-1, x=1)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $F9,$01,0,0        ; path1: header (y=-7, x=1)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$FF          ; flag=-1, dy=-6, dx=-1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$01          ; flag=-1, dy=6, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $F3,$00,0,0        ; path2: header (y=-13, x=0)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $F1,$FF,0,0        ; path3: header (y=-15, x=-1)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $F1,$FD,0,0        ; path4: header (y=-15, x=-3)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $F8,$FB,0,0        ; path5: header (y=-8, x=-5)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$07,$FF          ; flag=-1, dy=7, dx=-1
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$F9,$01          ; flag=-1, dy=-7, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $FF,$FA,0,0        ; path6: header (y=-1, x=-6)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $09,$FB,0,0        ; path7: header (y=9, x=-5)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $0D,$FB,0,0        ; path8: header (y=13, x=-5)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $0D,$F9,0,0        ; path9: header (y=13, x=-7)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $08,$04,0,0        ; path10: header (y=8, x=4)
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $07,$06,0,0        ; path11: header (y=7, x=6)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $04,$06,0,0        ; path12: header (y=4, x=6)
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $04,$07,0,0        ; path13: header (y=4, x=7)
    FCB $FF,$00,$01          ; flag=-1, dy=0, dx=1
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $01,$F9,0,0        ; path14: header (y=1, x=-7)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $07,$F9,0,0        ; path15: header (y=7, x=-7)
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_4_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $01,$F9,0,0        ; path16: header (y=1, x=-7)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

; Generated from player_walk_5.vec (Malban Draw_Sync_List format)
; Total paths: 17, points: 62
; X bounds: min=-8, max=11, width=19
; Center: (1, 0)

_PLAYER_WALK_5_WIDTH EQU 19
_PLAYER_WALK_5_HALF_WIDTH EQU 9
_PLAYER_WALK_5_HEIGHT EQU 29
_PLAYER_WALK_5_HALF_HEIGHT EQU 14
_PLAYER_WALK_5_CENTER_X EQU 1
_PLAYER_WALK_5_CENTER_Y EQU 0

_PLAYER_WALK_5_VECTORS:  ; Main entry (header + 17 path(s))
    FDB 17               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
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
    FCB $FE,$01,0,0        ; path0: header (y=-2, x=1)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $F8,$01,0,0        ; path1: header (y=-8, x=1)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $F2,$01,0,0        ; path2: header (y=-14, x=1)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $F1,$FB,0,0        ; path3: header (y=-15, x=-5)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $F2,$FB,0,0        ; path4: header (y=-14, x=-5)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $F8,$FB,0,0        ; path5: header (y=-8, x=-5)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $FE,$FA,0,0        ; path6: header (y=-2, x=-6)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $08,$FB,0,0        ; path7: header (y=8, x=-5)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $0C,$FB,0,0        ; path8: header (y=12, x=-5)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $0C,$F9,0,0        ; path9: header (y=12, x=-7)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $07,$04,0,0        ; path10: header (y=7, x=4)
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $06,$06,0,0        ; path11: header (y=6, x=6)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $03,$06,0,0        ; path12: header (y=3, x=6)
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $03,$07,0,0        ; path13: header (y=3, x=7)
    FCB $FF,$00,$01          ; flag=-1, dy=0, dx=1
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $01,$F9,0,0        ; path14: header (y=1, x=-7)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $06,$F9,0,0        ; path15: header (y=6, x=-7)
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_WALK_5_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $01,$F9,0,0        ; path16: header (y=1, x=-7)
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

; Generated from logo.vec (Malban Draw_Sync_List format)
; Total paths: 7, points: 65
; X bounds: min=-82, max=81, width=163
; Center: (0, 0)

_LOGO_WIDTH EQU 163
_LOGO_HALF_WIDTH EQU 81
_LOGO_HEIGHT EQU 76
_LOGO_HALF_HEIGHT EQU 38
_LOGO_CENTER_X EQU 0
_LOGO_CENTER_Y EQU 0

_LOGO_VECTORS:  ; Main entry (header + 7 path(s))
    FDB 7               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _LOGO_PATH0        ; pointer to path 0
    FDB _LOGO_PATH1        ; pointer to path 1
    FDB _LOGO_PATH2        ; pointer to path 2
    FDB _LOGO_PATH3        ; pointer to path 3
    FDB _LOGO_PATH4        ; pointer to path 4
    FDB _LOGO_PATH5        ; pointer to path 5
    FDB _LOGO_PATH6        ; pointer to path 6

_LOGO_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $04,$F5,0,0        ; path0: header (y=4, x=-11)
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$F8,$04          ; flag=-1, dy=-8, dx=4
    FCB $FF,$FE,$F9          ; flag=-1, dy=-2, dx=-7
    FCB $FF,$0A,$03          ; flag=-1, dy=10, dx=3
    FCB 2                ; End marker (path complete)

_LOGO_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $FB,$E3,0,0        ; path1: header (y=-5, x=-29)
    FCB $FF,$E7,$F8          ; flag=-1, dy=-25, dx=-8
    FCB $FF,$04,$10          ; flag=-1, dy=4, dx=16
    FCB $FF,$0C,$02          ; flag=-1, dy=12, dx=2
    FCB $FF,$03,$0B          ; flag=-1, dy=3, dx=11
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$03,$0D          ; flag=-1, dy=3, dx=13
    FCB $FF,$22,$F7          ; flag=-1, dy=34, dx=-9
    FCB $FF,$FD,$F1          ; flag=-1, dy=-3, dx=-15
    FCB $FF,$F5,$FF          ; flag=-1, dy=-11, dx=-1
    FCB $FF,$F5,$F7          ; flag=-1, dy=-11, dx=-9
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_LOGO_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $07,$CE,0,0        ; path2: header (y=7, x=-50)
    FCB $FF,$F8,$02          ; flag=-1, dy=-8, dx=2
    FCB $FF,$07,$08          ; flag=-1, dy=7, dx=8
    FCB $FF,$01,$F6          ; flag=-1, dy=1, dx=-10
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_LOGO_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $13,$AE,0,0        ; path3: header (y=19, x=-82)
    FCB $FF,$EF,$06          ; flag=-1, dy=-17, dx=6
    FCB $FF,$02,$07          ; flag=-1, dy=2, dx=7
    FCB $FF,$D6,$09          ; flag=-1, dy=-42, dx=9
    FCB $FF,$0B,$11          ; flag=-1, dy=11, dx=17
    FCB $FF,$0C,$FC          ; flag=-1, dy=12, dx=-4
    FCB $FF,$0D,$10          ; flag=-1, dy=13, dx=16
    FCB $FF,$0B,$09          ; flag=-1, dy=11, dx=9
    FCB $FF,$0C,$01          ; flag=-1, dy=12, dx=1
    FCB $FF,$08,$F8          ; flag=-1, dy=8, dx=-8
    FCB $FF,$02,$F0          ; flag=-1, dy=2, dx=-16
    FCB $FF,$FC,$F1          ; flag=-1, dy=-4, dx=-15
    FCB $FF,$F8,$EA          ; flag=-1, dy=-8, dx=-22
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_LOGO_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $F3,$0A,0,0        ; path4: header (y=-13, x=10)
    FCB $FF,$29,$02          ; flag=-1, dy=41, dx=2
    FCB $FF,$02,$0D          ; flag=-1, dy=2, dx=13
    FCB $FF,$EB,$0A          ; flag=-1, dy=-21, dx=10
    FCB $FF,$1A,$07          ; flag=-1, dy=26, dx=7
    FCB $FF,$03,$14          ; flag=-1, dy=3, dx=20
    FCB $FF,$D8,$EF          ; flag=-1, dy=-40, dx=-17
    FCB $FF,$FE,$F3          ; flag=-1, dy=-2, dx=-13
    FCB $FF,$0D,$F8          ; flag=-1, dy=13, dx=-8
    FCB $FF,$EE,$FC          ; flag=-1, dy=-18, dx=-4
    FCB $FF,$FC,$F6          ; flag=-1, dy=-4, dx=-10
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_LOGO_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $FC,$23,0,0        ; path5: header (y=-4, x=35)
    FCB $FF,$F5,$08          ; flag=-1, dy=-11, dx=8
    FCB $FF,$FC,$10          ; flag=-1, dy=-4, dx=16
    FCB $FF,$07,$12          ; flag=-1, dy=7, dx=18
    FCB $FF,$0D,$03          ; flag=-1, dy=13, dx=3
    FCB $FF,$FE,$E9          ; flag=-1, dy=-2, dx=-23
    FCB $FF,$FB,$FF          ; flag=-1, dy=-5, dx=-1
    FCB $FF,$FD,$06          ; flag=-1, dy=-3, dx=6
    FCB $FF,$02,$F4          ; flag=-1, dy=2, dx=-12
    FCB $FF,$09,$FF          ; flag=-1, dy=9, dx=-1
    FCB $FF,$0C,$09          ; flag=-1, dy=12, dx=9
    FCB $FF,$F8,$0B          ; flag=-1, dy=-8, dx=11
    FCB 2                ; End marker (path complete)

_LOGO_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $06,$45,0,0        ; path6: header (y=6, x=69)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB $FF,$0C,$F8          ; flag=-1, dy=12, dx=-8
    FCB $FF,$03,$F0          ; flag=-1, dy=3, dx=-16
    FCB $FF,$FB,$FC          ; flag=-1, dy=-5, dx=-4
    FCB 2                ; End marker (path complete)

; Generated from fuji_bg.vec (Malban Draw_Sync_List format)
; Total paths: 6, points: 65
; X bounds: min=-125, max=125, width=250
; Center: (0, 0)

_FUJI_BG_WIDTH EQU 250
_FUJI_BG_HALF_WIDTH EQU 125
_FUJI_BG_HEIGHT EQU 97
_FUJI_BG_HALF_HEIGHT EQU 48
_FUJI_BG_CENTER_X EQU 0
_FUJI_BG_CENTER_Y EQU 0

_FUJI_BG_VECTORS:  ; Main entry (header + 5 path(s))
    FDB 5               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _FUJI_BG_PATH0        ; pointer to path 0
    FDB _FUJI_BG_PATH1        ; pointer to path 1
    FDB _FUJI_BG_PATH2        ; pointer to path 2
    FDB _FUJI_BG_PATH3        ; pointer to path 3
    FDB _FUJI_BG_PATH4        ; pointer to path 4

_FUJI_BG_PATH0:    ; Path 0
    FCB 95              ; path0: intensity
    FCB $1A,$F1,0,0        ; path0: header (y=26, x=-15)
    FCB $FF,$06,$03          ; flag=-1, dy=6, dx=3
    FCB $FF,$04,$03          ; flag=-1, dy=4, dx=3
    FCB $FF,$FD,$04          ; flag=-1, dy=-3, dx=4
    FCB $FF,$FC,$FC          ; flag=-1, dy=-4, dx=-4
    FCB $FF,$FD,$FA          ; flag=-1, dy=-3, dx=-6
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_FUJI_BG_PATH1:    ; Path 1
    FCB 95              ; path1: intensity
    FCB $1F,$07,0,0        ; path1: header (y=31, x=7)
    FCB $FF,$F9,$FD          ; flag=-1, dy=-7, dx=-3
    FCB $FF,$FA,$02          ; flag=-1, dy=-6, dx=2
    FCB $FF,$F9,$FD          ; flag=-1, dy=-7, dx=-3
    FCB $FF,$FD,$04          ; flag=-1, dy=-3, dx=4
    FCB $FF,$08,$03          ; flag=-1, dy=8, dx=3
    FCB $FF,$07,$FE          ; flag=-1, dy=7, dx=-2
    FCB $FF,$06,$01          ; flag=-1, dy=6, dx=1
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB 2                ; End marker (path complete)

_FUJI_BG_PATH2:    ; Path 2
    FCB 95              ; path2: intensity
    FCB $21,$18,0,0        ; path2: header (y=33, x=24)
    FCB $FF,$F7,$05          ; flag=-1, dy=-9, dx=5
    FCB $FF,$F7,$0C          ; flag=-1, dy=-9, dx=12
    FCB $FF,$0B,$FA          ; flag=-1, dy=11, dx=-6
    FCB $FF,$07,$F5          ; flag=-1, dy=7, dx=-11
    FCB 2                ; End marker (path complete)

_FUJI_BG_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $02,$4D,0,0        ; path3: header (y=2, x=77)
    FCB $FF,$04,$EC          ; flag=-1, dy=4, dx=-20
    FCB $FF,$FC,$FE          ; flag=-1, dy=-4, dx=-2
    FCB $FF,$07,$F2          ; flag=-1, dy=7, dx=-14
    FCB $FF,$EE,$09          ; flag=-1, dy=-18, dx=9
    FCB $FF,$12,$ED          ; flag=-1, dy=18, dx=-19
    FCB $FF,$F0,$01          ; flag=-1, dy=-16, dx=1
    FCB $FF,$0B,$FB          ; flag=-1, dy=11, dx=-5
    FCB $FF,$F5,$FD          ; flag=-1, dy=-11, dx=-3
    FCB $FF,$03,$FC          ; flag=-1, dy=3, dx=-4
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$11,$FA          ; flag=-1, dy=17, dx=-6
    FCB $FF,$E4,$FB          ; flag=-1, dy=-28, dx=-5
    FCB $FF,$16,$FA          ; flag=-1, dy=22, dx=-6
    FCB $FF,$F6,$FB          ; flag=-1, dy=-10, dx=-5
    FCB $FF,$0F,$00          ; flag=-1, dy=15, dx=0
    FCB $FF,$F2,$F2          ; flag=-1, dy=-14, dx=-14
    FCB $FF,$06,$FF          ; flag=-1, dy=6, dx=-1
    FCB $FF,$09,$05          ; flag=-1, dy=9, dx=5
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$0E,$05          ; flag=-1, dy=14, dx=5
    FCB $FF,$E5,$DE          ; flag=-1, dy=-27, dx=-34
    FCB $FF,$11,$0E          ; flag=-1, dy=17, dx=14
    FCB $FF,$F7,$E6          ; flag=-1, dy=-9, dx=-26
    FCB 2                ; End marker (path complete)

_FUJI_BG_PATH4:    ; Path 4
    FCB 80              ; path4: intensity
    FCB $E8,$84,0,0        ; path4: header (y=-24, x=-124)
    FCB $FF,$0A,$1E          ; flag=-1, dy=10, dx=30
    FCB $FF,$0E,$1E          ; flag=-1, dy=14, dx=30
    FCB $FF,$0F,$15          ; flag=-1, dy=15, dx=21
    FCB $FF,$11,$17          ; flag=-1, dy=17, dx=23
    FCB $FF,$0E,$0E          ; flag=-1, dy=14, dx=14
    FCB $FF,$FE,$03          ; flag=-1, dy=-2, dx=3
    FCB $FF,$03,$04          ; flag=-1, dy=3, dx=4
    FCB $FF,$FE,$04          ; flag=-1, dy=-2, dx=4
    FCB $FF,$01,$07          ; flag=-1, dy=1, dx=7
    FCB $FF,$02,$04          ; flag=-1, dy=2, dx=4
    FCB $FF,$FD,$06          ; flag=-1, dy=-3, dx=6
    FCB $FF,$03,$03          ; flag=-1, dy=3, dx=3
    FCB $FF,$EB,$11          ; flag=-1, dy=-21, dx=17
    FCB $FF,$F4,$11          ; flag=-1, dy=-12, dx=17
    FCB $FF,$F0,$16          ; flag=-1, dy=-16, dx=22
    FCB $FF,$F6,$14          ; flag=-1, dy=-10, dx=20
    FCB $FF,$F6,$18          ; flag=-1, dy=-10, dx=24
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
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
    FDB -96  ; scrollLimit left (camera left cannot go below this)
    FDB 95  ; scrollLimit right (camera right cannot exceed this)
    FDB 127  ; scrollLimit top
    FDB -128  ; scrollLimit bottom
    FCB 0  ; enemy_count
    FDB 0  ; enemy_instances_ptr (0 if none)
    FDB 0  ; groundBottomOffset (floor surface offset from screen bottom)
    FCB 1    ; +34 screen_count
    FDB _FUJI_LEVEL1_V2_BG_SCREENS  ; +35 BG screens index
    FDB _FUJI_LEVEL1_V2_GP_SCREENS  ; +37 GP screens index
    FDB _FUJI_LEVEL1_V2_FG_SCREENS  ; +39 FG screens index

_FUJI_LEVEL1_V2_BG_OBJECTS:
_FUJI_LEVEL1_V2_BG_OBJECTS_S0:
; Object: obj_1767470884207 (enemy)
    FCB 1  ; type
    FDB 0  ; x
    FDB 0  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 1   ; vector_bank (ROM+16)
    FDB _FUJI_BG_VECTORS  ; vector_ptr (ROM+17)
    FCB 125  ; half_width (1.00x, ROM+19)
    FCB 48  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)


_FUJI_LEVEL1_V2_GAMEPLAY_OBJECTS:
_FUJI_LEVEL1_V2_GAMEPLAY_OBJECTS_S0:
; Object: enemy_1 (enemy)
    FCB 1  ; type
    FDB -40  ; x
    FDB 60  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 127  ; intensity (0=use vec, >0=override)
    FCB 255  ; velocity_x
    FCB 255  ; velocity_y
    FCB 3  ; physics_flags
    FCB 7  ; collision_flags
    FCB 20  ; collision_size
    FDB 0  ; spawn_delay
    FCB 1   ; vector_bank (ROM+16)
    FDB _BUBBLE_LARGE_VECTORS  ; vector_ptr (ROM+17)
    FCB 20  ; half_width (1.00x, ROM+19)
    FCB 20  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: enemy_2 (enemy)
    FCB 1  ; type
    FDB 40  ; x
    FDB 60  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 127  ; intensity (0=use vec, >0=override)
    FCB 1  ; velocity_x
    FCB 255  ; velocity_y
    FCB 3  ; physics_flags
    FCB 7  ; collision_flags
    FCB 20  ; collision_size
    FDB 60  ; spawn_delay
    FCB 1   ; vector_bank (ROM+16)
    FDB _BUBBLE_LARGE_VECTORS  ; vector_ptr (ROM+17)
    FCB 20  ; half_width (1.00x, ROM+19)
    FCB 20  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)


_FUJI_LEVEL1_V2_FG_OBJECTS:
_FUJI_LEVEL1_V2_FG_OBJECTS_S0:

_FUJI_LEVEL1_V2_BG_SCREENS:
    FCB 1  ; screen 0 count
    FDB _FUJI_LEVEL1_V2_BG_OBJECTS_S0  ; screen 0 ptr

_FUJI_LEVEL1_V2_GP_SCREENS:
    FCB 2  ; screen 0 count
    FDB _FUJI_LEVEL1_V2_GAMEPLAY_OBJECTS_S0  ; screen 0 ptr

_FUJI_LEVEL1_V2_FG_SCREENS:
    FCB 0  ; screen 0 count
    FDB _FUJI_LEVEL1_V2_FG_OBJECTS_S0  ; screen 0 ptr

_FUJI_LEVEL1_V2_ENEMY_COUNT EQU 0


; Generated from newyork_bg.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 22
; X bounds: min=-25, max=25, width=50
; Center: (0, 27)

_NEWYORK_BG_WIDTH EQU 50
_NEWYORK_BG_HALF_WIDTH EQU 25
_NEWYORK_BG_HEIGHT EQU 75
_NEWYORK_BG_HALF_HEIGHT EQU 37
_NEWYORK_BG_CENTER_X EQU 0
_NEWYORK_BG_CENTER_Y EQU 27

_NEWYORK_BG_VECTORS:  ; Main entry (header + 5 path(s))
    FDB 5               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _NEWYORK_BG_PATH0        ; pointer to path 0
    FDB _NEWYORK_BG_PATH1        ; pointer to path 1
    FDB _NEWYORK_BG_PATH2        ; pointer to path 2
    FDB _NEWYORK_BG_PATH3        ; pointer to path 3
    FDB _NEWYORK_BG_PATH4        ; pointer to path 4

_NEWYORK_BG_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $DB,$E7,0,0        ; path0: header (y=-37, x=-25)
    FCB $FF,$00,$32          ; flag=-1, dy=0, dx=50
    FCB 2                ; End marker (path complete)

_NEWYORK_BG_PATH1:    ; Path 1
    FCB 120              ; path1: intensity
    FCB $0D,$14,0,0        ; path1: header (y=13, x=20)
    FCB $FF,$0A,$FB          ; flag=-1, dy=10, dx=-5
    FCB $FF,$FB,$FB          ; flag=-1, dy=-5, dx=-5
    FCB $FF,$07,$FB          ; flag=-1, dy=7, dx=-5
    FCB $FF,$F9,$FB          ; flag=-1, dy=-7, dx=-5
    FCB $FF,$07,$FB          ; flag=-1, dy=7, dx=-5
    FCB $FF,$F9,$FB          ; flag=-1, dy=-7, dx=-5
    FCB $FF,$05,$FB          ; flag=-1, dy=5, dx=-5
    FCB $FF,$F6,$FB          ; flag=-1, dy=-10, dx=-5
    FCB 2                ; End marker (path complete)

_NEWYORK_BG_PATH2:    ; Path 2
    FCB 110              ; path2: intensity
    FCB $0D,$F1,0,0        ; path2: header (y=13, x=-15)
    FCB $FF,$CE,$00          ; flag=-1, dy=-50, dx=0
    FCB $FF,$00,$1E          ; flag=-1, dy=0, dx=30
    FCB $FF,$32,$00          ; flag=-1, dy=50, dx=0
    FCB 2                ; End marker (path complete)

_NEWYORK_BG_PATH3:    ; Path 3
    FCB 110              ; path3: intensity
    FCB $0D,$00,0,0        ; path3: header (y=13, x=0)
    FCB $FF,$0F,$0A          ; flag=-1, dy=15, dx=10
    FCB $FF,$05,$F6          ; flag=-1, dy=5, dx=-10
    FCB 2                ; End marker (path complete)

_NEWYORK_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $21,$FB,0,0        ; path4: header (y=33, x=-5)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

; Generated from bubble_large.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 24
; X bounds: min=-20, max=20, width=40
; Center: (0, 0)

_BUBBLE_LARGE_WIDTH EQU 40
_BUBBLE_LARGE_HALF_WIDTH EQU 20
_BUBBLE_LARGE_HEIGHT EQU 40
_BUBBLE_LARGE_HALF_HEIGHT EQU 20
_BUBBLE_LARGE_CENTER_X EQU 0
_BUBBLE_LARGE_CENTER_Y EQU 0

_BUBBLE_LARGE_VECTORS:  ; Main entry (header + 1 path(s))
    FDB 1               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _BUBBLE_LARGE_PATH0        ; pointer to path 0

_BUBBLE_LARGE_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $00,$14,0,0        ; path0: header (y=0, x=20)
    FCB $FF,$05,$FF          ; flag=-1, dy=5, dx=-1
    FCB $FF,$05,$FE          ; flag=-1, dy=5, dx=-2
    FCB $FF,$04,$FD          ; flag=-1, dy=4, dx=-3
    FCB $FF,$03,$FC          ; flag=-1, dy=3, dx=-4
    FCB $FF,$02,$FB          ; flag=-1, dy=2, dx=-5
    FCB $FF,$01,$FB          ; flag=-1, dy=1, dx=-5
    FCB $FF,$FF,$FB          ; flag=-1, dy=-1, dx=-5
    FCB $FF,$FE,$FB          ; flag=-1, dy=-2, dx=-5
    FCB $FF,$FD,$FC          ; flag=-1, dy=-3, dx=-4
    FCB $FF,$FC,$FD          ; flag=-1, dy=-4, dx=-3
    FCB $FF,$FB,$FE          ; flag=-1, dy=-5, dx=-2
    FCB $FF,$FB,$FF          ; flag=-1, dy=-5, dx=-1
    FCB $FF,$FB,$01          ; flag=-1, dy=-5, dx=1
    FCB $FF,$FB,$02          ; flag=-1, dy=-5, dx=2
    FCB $FF,$FC,$03          ; flag=-1, dy=-4, dx=3
    FCB $FF,$FD,$04          ; flag=-1, dy=-3, dx=4
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB $FF,$FF,$05          ; flag=-1, dy=-1, dx=5
    FCB $FF,$01,$05          ; flag=-1, dy=1, dx=5
    FCB $FF,$02,$05          ; flag=-1, dy=2, dx=5
    FCB $FF,$03,$04          ; flag=-1, dy=3, dx=4
    FCB $FF,$04,$03          ; flag=-1, dy=4, dx=3
    FCB $FF,$05,$02          ; flag=-1, dy=5, dx=2
    FCB $FF,$05,$01          ; flag=-1, dy=5, dx=1
    FCB 2                ; End marker (path complete)

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
    FCB $FF,$04,$FF          ; flag=-1, dy=4, dx=-1
    FCB $FF,$04,$FF          ; flag=-1, dy=4, dx=-1
    FCB $FF,$03,$FE          ; flag=-1, dy=3, dx=-2
    FCB $FF,$02,$FD          ; flag=-1, dy=2, dx=-3
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB $FF,$01,$FC          ; flag=-1, dy=1, dx=-4
    FCB $FF,$FF,$FC          ; flag=-1, dy=-1, dx=-4
    FCB $FF,$FF,$FC          ; flag=-1, dy=-1, dx=-4
    FCB $FF,$FE,$FD          ; flag=-1, dy=-2, dx=-3
    FCB $FF,$FD,$FE          ; flag=-1, dy=-3, dx=-2
    FCB $FF,$FC,$FF          ; flag=-1, dy=-4, dx=-1
    FCB $FF,$FC,$FF          ; flag=-1, dy=-4, dx=-1
    FCB $FF,$FC,$01          ; flag=-1, dy=-4, dx=1
    FCB $FF,$FC,$01          ; flag=-1, dy=-4, dx=1
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$FE,$03          ; flag=-1, dy=-2, dx=3
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB $FF,$01,$04          ; flag=-1, dy=1, dx=4
    FCB $FF,$01,$04          ; flag=-1, dy=1, dx=4
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB $FF,$04,$01          ; flag=-1, dy=4, dx=1
    FCB $FF,$04,$01          ; flag=-1, dy=4, dx=1
    FCB 2                ; End marker (path complete)

; Generated from bubble_small.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 24
; X bounds: min=-10, max=10, width=20
; Center: (0, 0)

_BUBBLE_SMALL_WIDTH EQU 20
_BUBBLE_SMALL_HALF_WIDTH EQU 10
_BUBBLE_SMALL_HEIGHT EQU 20
_BUBBLE_SMALL_HALF_HEIGHT EQU 10
_BUBBLE_SMALL_CENTER_X EQU 0
_BUBBLE_SMALL_CENTER_Y EQU 0

_BUBBLE_SMALL_VECTORS:  ; Main entry (header + 1 path(s))
    FDB 1               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _BUBBLE_SMALL_PATH0        ; pointer to path 0

_BUBBLE_SMALL_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $00,$0A,0,0        ; path0: header (y=0, x=10)
    FCB $FF,$03,$FF          ; flag=-1, dy=3, dx=-1
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB $FF,$FF,$FD          ; flag=-1, dy=-1, dx=-3
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FF,$03          ; flag=-1, dy=-1, dx=3
    FCB $FF,$01,$03          ; flag=-1, dy=1, dx=3
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB 2                ; End marker (path complete)

; Generated from mayan_bg.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 20
; X bounds: min=-80, max=80, width=160
; Center: (0, 10)

_MAYAN_BG_WIDTH EQU 160
_MAYAN_BG_HALF_WIDTH EQU 80
_MAYAN_BG_HEIGHT EQU 80
_MAYAN_BG_HALF_HEIGHT EQU 40
_MAYAN_BG_CENTER_X EQU 0
_MAYAN_BG_CENTER_Y EQU 10

_MAYAN_BG_VECTORS:  ; Main entry (header + 5 path(s))
    FDB 5               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _MAYAN_BG_PATH0        ; pointer to path 0
    FDB _MAYAN_BG_PATH1        ; pointer to path 1
    FDB _MAYAN_BG_PATH2        ; pointer to path 2
    FDB _MAYAN_BG_PATH3        ; pointer to path 3
    FDB _MAYAN_BG_PATH4        ; pointer to path 4

_MAYAN_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $F6,$D8,0,0        ; path0: header (y=-10, x=-40)
    FCB $FF,$28,$00          ; flag=-1, dy=40, dx=0
    FCB $FF,$0A,$0A          ; flag=-1, dy=10, dx=10
    FCB $FF,$00,$3C          ; flag=-1, dy=0, dx=60
    FCB $FF,$F6,$0A          ; flag=-1, dy=-10, dx=10
    FCB $FF,$D8,$00          ; flag=-1, dy=-40, dx=0
    FCB 2                ; End marker (path complete)

_MAYAN_BG_PATH1:    ; Path 1
    FCB 120              ; path1: intensity
    FCB $EC,$32,0,0        ; path1: header (y=-20, x=50)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$9C          ; flag=-1, dy=0, dx=-100
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_MAYAN_BG_PATH2:    ; Path 2
    FCB 110              ; path2: intensity
    FCB $E2,$C4,0,0        ; path2: header (y=-30, x=-60)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$78          ; flag=-1, dy=0, dx=120
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_MAYAN_BG_PATH3:    ; Path 3
    FCB 110              ; path3: intensity
    FCB $D8,$46,0,0        ; path3: header (y=-40, x=70)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$BA          ; sub-seg 1/2 of line 1: dy=0, dx=-70
    FCB $FF,$00,$BA          ; sub-seg 2/2 of line 1: dy=0, dx=-70
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_MAYAN_BG_PATH4:    ; Path 4
    FCB 100              ; path4: intensity
    FCB $D8,$B0,0,0        ; path4: header (y=-40, x=-80)
    FCB $FF,$00,$50          ; sub-seg 1/2 of line 0: dy=0, dx=80
    FCB $FF,$00,$50          ; sub-seg 2/2 of line 0: dy=0, dx=80
    FCB 2                ; End marker (path complete)

; Generated from leningrad_bg.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 21
; X bounds: min=-30, max=30, width=60
; Center: (0, 30)

_LENINGRAD_BG_WIDTH EQU 60
_LENINGRAD_BG_HALF_WIDTH EQU 30
_LENINGRAD_BG_HEIGHT EQU 80
_LENINGRAD_BG_HALF_HEIGHT EQU 40
_LENINGRAD_BG_CENTER_X EQU 0
_LENINGRAD_BG_CENTER_Y EQU 30

_LENINGRAD_BG_VECTORS:  ; Main entry (header + 5 path(s))
    FDB 5               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _LENINGRAD_BG_PATH0        ; pointer to path 0
    FDB _LENINGRAD_BG_PATH1        ; pointer to path 1
    FDB _LENINGRAD_BG_PATH2        ; pointer to path 2
    FDB _LENINGRAD_BG_PATH3        ; pointer to path 3
    FDB _LENINGRAD_BG_PATH4        ; pointer to path 4

_LENINGRAD_BG_PATH0:    ; Path 0
    FCB 90              ; path0: intensity
    FCB $EC,$0A,0,0        ; path0: header (y=-20, x=10)
    FCB $FF,$0F,$00          ; flag=-1, dy=15, dx=0
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$F1,$00          ; flag=-1, dy=-15, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

_LENINGRAD_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $05,$19,0,0        ; path1: header (y=5, x=25)
    FCB $FF,$14,$F6          ; flag=-1, dy=20, dx=-10
    FCB $FF,$05,$F1          ; flag=-1, dy=5, dx=-15
    FCB $FF,$FB,$F1          ; flag=-1, dy=-5, dx=-15
    FCB $FF,$EC,$F6          ; flag=-1, dy=-20, dx=-10
    FCB 2                ; End marker (path complete)

_LENINGRAD_BG_PATH2:    ; Path 2
    FCB 110              ; path2: intensity
    FCB $05,$E2,0,0        ; path2: header (y=5, x=-30)
    FCB $FF,$D3,$00          ; flag=-1, dy=-45, dx=0
    FCB $FF,$00,$3C          ; flag=-1, dy=0, dx=60
    FCB $FF,$2D,$00          ; flag=-1, dy=45, dx=0
    FCB 2                ; End marker (path complete)

_LENINGRAD_BG_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $1E,$00,0,0        ; path3: header (y=30, x=0)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_LENINGRAD_BG_PATH4:    ; Path 4
    FCB 90              ; path4: intensity
    FCB $EC,$EC,0,0        ; path4: header (y=-20, x=-20)
    FCB $FF,$0F,$00          ; flag=-1, dy=15, dx=0
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$F1,$00          ; flag=-1, dy=-15, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB 2                ; End marker (path complete)

; Generated from easter_bg.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 19
; X bounds: min=-35, max=35, width=70
; Center: (0, 15)

_EASTER_BG_WIDTH EQU 70
_EASTER_BG_HALF_WIDTH EQU 35
_EASTER_BG_HEIGHT EQU 90
_EASTER_BG_HALF_HEIGHT EQU 45
_EASTER_BG_CENTER_X EQU 0
_EASTER_BG_CENTER_Y EQU 15

_EASTER_BG_VECTORS:  ; Main entry (header + 5 path(s))
    FDB 5               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _EASTER_BG_PATH0        ; pointer to path 0
    FDB _EASTER_BG_PATH1        ; pointer to path 1
    FDB _EASTER_BG_PATH2        ; pointer to path 2
    FDB _EASTER_BG_PATH3        ; pointer to path 3
    FDB _EASTER_BG_PATH4        ; pointer to path 4

_EASTER_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $05,$E7,0,0        ; path0: header (y=5, x=-25)
    FCB $FF,$1E,$00          ; flag=-1, dy=30, dx=0
    FCB $FF,$0A,$05          ; flag=-1, dy=10, dx=5
    FCB $FF,$00,$28          ; flag=-1, dy=0, dx=40
    FCB $FF,$F6,$05          ; flag=-1, dy=-10, dx=5
    FCB $FF,$E2,$00          ; flag=-1, dy=-30, dx=0
    FCB 2                ; End marker (path complete)

_EASTER_BG_PATH1:    ; Path 1
    FCB 110              ; path1: intensity
    FCB $05,$1E,0,0        ; path1: header (y=5, x=30)
    FCB $FF,$CE,$00          ; flag=-1, dy=-50, dx=0
    FCB $FF,$00,$C4          ; flag=-1, dy=0, dx=-60
    FCB $FF,$32,$00          ; flag=-1, dy=50, dx=0
    FCB 2                ; End marker (path complete)

_EASTER_BG_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $1E,$F8,0,0        ; path2: header (y=30, x=-8)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB 2                ; End marker (path complete)

_EASTER_BG_PATH3:    ; Path 3
    FCB 110              ; path3: intensity
    FCB $19,$00,0,0        ; path3: header (y=25, x=0)
    FCB $FF,$FB,$0A          ; flag=-1, dy=-5, dx=10
    FCB 2                ; End marker (path complete)

_EASTER_BG_PATH4:    ; Path 4
    FCB 90              ; path4: intensity
    FCB $D3,$23,0,0        ; path4: header (y=-45, x=35)
    FCB $FF,$00,$BA          ; flag=-1, dy=0, dx=-70
    FCB 2                ; End marker (path complete)

; Generated from london_bg.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 16
; X bounds: min=-20, max=20, width=40
; Center: (0, 15)

_LONDON_BG_WIDTH EQU 40
_LONDON_BG_HALF_WIDTH EQU 20
_LONDON_BG_HEIGHT EQU 90
_LONDON_BG_HALF_HEIGHT EQU 45
_LONDON_BG_CENTER_X EQU 0
_LONDON_BG_CENTER_Y EQU 15

_LONDON_BG_VECTORS:  ; Main entry (header + 4 path(s))
    FDB 4               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _LONDON_BG_PATH0        ; pointer to path 0
    FDB _LONDON_BG_PATH1        ; pointer to path 1
    FDB _LONDON_BG_PATH2        ; pointer to path 2
    FDB _LONDON_BG_PATH3        ; pointer to path 3

_LONDON_BG_PATH0:    ; Path 0
    FCB 110              ; path0: intensity
    FCB $D3,$EC,0,0        ; path0: header (y=-45, x=-20)
    FCB $FF,$46,$00          ; flag=-1, dy=70, dx=0
    FCB $FF,$00,$28          ; flag=-1, dy=0, dx=40
    FCB $FF,$BA,$00          ; flag=-1, dy=-70, dx=0
    FCB 2                ; End marker (path complete)

_LONDON_BG_PATH1:    ; Path 1
    FCB 120              ; path1: intensity
    FCB $19,$14,0,0        ; path1: header (y=25, x=20)
    FCB $FF,$0A,$FB          ; flag=-1, dy=10, dx=-5
    FCB $FF,$00,$E2          ; flag=-1, dy=0, dx=-30
    FCB $FF,$F6,$FB          ; flag=-1, dy=-10, dx=-5
    FCB 2                ; End marker (path complete)

_LONDON_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $23,$F1,0,0        ; path2: header (y=35, x=-15)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$1E          ; flag=-1, dy=0, dx=30
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$00,$E2          ; flag=-1, dy=0, dx=-30
    FCB 2                ; End marker (path complete)

_LONDON_BG_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $28,$00,0,0        ; path3: header (y=40, x=0)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$FB,$08          ; flag=-1, dy=-5, dx=8
    FCB 2                ; End marker (path complete)

; Generated from paris_bg.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 15
; X bounds: min=-50, max=50, width=100
; Center: (0, 17)

_PARIS_BG_WIDTH EQU 100
_PARIS_BG_HALF_WIDTH EQU 50
_PARIS_BG_HEIGHT EQU 95
_PARIS_BG_HALF_HEIGHT EQU 47
_PARIS_BG_CENTER_X EQU 0
_PARIS_BG_CENTER_Y EQU 17

_PARIS_BG_VECTORS:  ; Main entry (header + 5 path(s))
    FDB 5               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PARIS_BG_PATH0        ; pointer to path 0
    FDB _PARIS_BG_PATH1        ; pointer to path 1
    FDB _PARIS_BG_PATH2        ; pointer to path 2
    FDB _PARIS_BG_PATH3        ; pointer to path 3
    FDB _PARIS_BG_PATH4        ; pointer to path 4

_PARIS_BG_PATH0:    ; Path 0
    FCB 90              ; path0: intensity
    FCB $EF,$EC,0,0        ; path0: header (y=-17, x=-20)
    FCB $FF,$00,$28          ; flag=-1, dy=0, dx=40
    FCB 2                ; End marker (path complete)

_PARIS_BG_PATH1:    ; Path 1
    FCB 100              ; path1: intensity
    FCB $0D,$0A,0,0        ; path1: header (y=13, x=10)
    FCB $FF,$E2,$0A          ; flag=-1, dy=-30, dx=10
    FCB $FF,$E2,$1E          ; flag=-1, dy=-30, dx=30
    FCB 2                ; End marker (path complete)

_PARIS_BG_PATH2:    ; Path 2
    FCB 110              ; path2: intensity
    FCB $0D,$0A,0,0        ; path2: header (y=13, x=10)
    FCB $FF,$14,$FB          ; flag=-1, dy=20, dx=-5
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$EC,$FB          ; flag=-1, dy=-20, dx=-5
    FCB 2                ; End marker (path complete)

_PARIS_BG_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $0D,$F6,0,0        ; path3: header (y=13, x=-10)
    FCB $FF,$E2,$F6          ; flag=-1, dy=-30, dx=-10
    FCB $FF,$E2,$E2          ; flag=-1, dy=-30, dx=-30
    FCB 2                ; End marker (path complete)

_PARIS_BG_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $21,$FB,0,0        ; path4: header (y=33, x=-5)
    FCB $FF,$0F,$05          ; flag=-1, dy=15, dx=5
    FCB $FF,$F1,$05          ; flag=-1, dy=-15, dx=5
    FCB 2                ; End marker (path complete)

; Generated from kilimanjaro_bg.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 13
; X bounds: min=-100, max=100, width=200
; Center: (0, 12)

_KILIMANJARO_BG_WIDTH EQU 200
_KILIMANJARO_BG_HALF_WIDTH EQU 100
_KILIMANJARO_BG_HEIGHT EQU 85
_KILIMANJARO_BG_HALF_HEIGHT EQU 42
_KILIMANJARO_BG_CENTER_X EQU 0
_KILIMANJARO_BG_CENTER_Y EQU 12

_KILIMANJARO_BG_VECTORS:  ; Main entry (header + 4 path(s))
    FDB 4               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _KILIMANJARO_BG_PATH0        ; pointer to path 0
    FDB _KILIMANJARO_BG_PATH1        ; pointer to path 1
    FDB _KILIMANJARO_BG_PATH2        ; pointer to path 2
    FDB _KILIMANJARO_BG_PATH3        ; pointer to path 3

_KILIMANJARO_BG_PATH0:    ; Path 0
    FCB 110              ; path0: intensity
    FCB $1C,$00,0,0        ; path0: header (y=28, x=0)
    FCB $FF,$0F,$00          ; flag=-1, dy=15, dx=0
    FCB $FF,$F1,$E2          ; flag=-1, dy=-15, dx=-30
    FCB 2                ; End marker (path complete)

_KILIMANJARO_BG_PATH1:    ; Path 1
    FCB 90              ; path1: intensity
    FCB $08,$D8,0,0        ; path1: header (y=8, x=-40)
    FCB $FF,$EC,$E2          ; flag=-1, dy=-20, dx=-30
    FCB 2                ; End marker (path complete)

_KILIMANJARO_BG_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $D6,$9C,0,0        ; path2: header (y=-42, x=-100)
    FCB $FF,$3C,$32          ; flag=-1, dy=60, dx=50
    FCB $FF,$19,$32          ; flag=-1, dy=25, dx=50
    FCB $FF,$E7,$32          ; flag=-1, dy=-25, dx=50
    FCB $FF,$C4,$32          ; flag=-1, dy=-60, dx=50
    FCB 2                ; End marker (path complete)

_KILIMANJARO_BG_PATH3:    ; Path 3
    FCB 110              ; path3: intensity
    FCB $1C,$1E,0,0        ; path3: header (y=28, x=30)
    FCB $FF,$0F,$E2          ; flag=-1, dy=15, dx=-30
    FCB $FF,$F1,$00          ; flag=-1, dy=-15, dx=0
    FCB 2                ; End marker (path complete)

; Generated from taj_bg.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 13
; X bounds: min=-70, max=70, width=140
; Center: (0, 22)

_TAJ_BG_WIDTH EQU 140
_TAJ_BG_HALF_WIDTH EQU 70
_TAJ_BG_HEIGHT EQU 85
_TAJ_BG_HALF_HEIGHT EQU 42
_TAJ_BG_CENTER_X EQU 0
_TAJ_BG_CENTER_Y EQU 22

_TAJ_BG_VECTORS:  ; Main entry (header + 4 path(s))
    FDB 4               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _TAJ_BG_PATH0        ; pointer to path 0
    FDB _TAJ_BG_PATH1        ; pointer to path 1
    FDB _TAJ_BG_PATH2        ; pointer to path 2
    FDB _TAJ_BG_PATH3        ; pointer to path 3

_TAJ_BG_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $12,$E2,0,0        ; path0: header (y=18, x=-30)
    FCB $FF,$14,$0A          ; flag=-1, dy=20, dx=10
    FCB $FF,$05,$14          ; flag=-1, dy=5, dx=20
    FCB $FF,$FB,$14          ; flag=-1, dy=-5, dx=20
    FCB $FF,$EC,$0A          ; flag=-1, dy=-20, dx=10
    FCB 2                ; End marker (path complete)

_TAJ_BG_PATH1:    ; Path 1
    FCB 110              ; path1: intensity
    FCB $12,$28,0,0        ; path1: header (y=18, x=40)
    FCB $FF,$CE,$00          ; flag=-1, dy=-50, dx=0
    FCB $FF,$00,$B0          ; flag=-1, dy=0, dx=-80
    FCB $FF,$32,$00          ; flag=-1, dy=50, dx=0
    FCB 2                ; End marker (path complete)

_TAJ_BG_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $1C,$BA,0,0        ; path2: header (y=28, x=-70)
    FCB $FF,$BA,$00          ; flag=-1, dy=-70, dx=0
    FCB 2                ; End marker (path complete)

_TAJ_BG_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $D6,$46,0,0        ; path3: header (y=-42, x=70)
    FCB $FF,$46,$00          ; flag=-1, dy=70, dx=0
    FCB 2                ; End marker (path complete)

; Generated from buddha_bg.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 10
; X bounds: min=-80, max=80, width=160
; Center: (0, 20)

_BUDDHA_BG_WIDTH EQU 160
_BUDDHA_BG_HALF_WIDTH EQU 80
_BUDDHA_BG_HEIGHT EQU 80
_BUDDHA_BG_HALF_HEIGHT EQU 40
_BUDDHA_BG_CENTER_X EQU 0
_BUDDHA_BG_CENTER_Y EQU 20

_BUDDHA_BG_VECTORS:  ; Main entry (header + 4 path(s))
    FDB 4               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _BUDDHA_BG_PATH0        ; pointer to path 0
    FDB _BUDDHA_BG_PATH1        ; pointer to path 1
    FDB _BUDDHA_BG_PATH2        ; pointer to path 2
    FDB _BUDDHA_BG_PATH3        ; pointer to path 3

_BUDDHA_BG_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $D8,$CE,0,0        ; path0: header (y=-40, x=-50)
    FCB $FF,$3C,$00          ; flag=-1, dy=60, dx=0
    FCB 2                ; End marker (path complete)

_BUDDHA_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $14,$B0,0,0        ; path1: header (y=20, x=-80)
    FCB $FF,$14,$14          ; flag=-1, dy=20, dx=20
    FCB $FF,$00,$78          ; flag=-1, dy=0, dx=120
    FCB $FF,$EC,$14          ; flag=-1, dy=-20, dx=20
    FCB 2                ; End marker (path complete)

_BUDDHA_BG_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $14,$32,0,0        ; path2: header (y=20, x=50)
    FCB $FF,$C4,$00          ; flag=-1, dy=-60, dx=0
    FCB 2                ; End marker (path complete)

_BUDDHA_BG_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $D8,$46,0,0        ; path3: header (y=-40, x=70)
    FCB $FF,$00,$BA          ; sub-seg 1/2 of line 0: dy=0, dx=-70
    FCB $FF,$00,$BA          ; sub-seg 2/2 of line 0: dy=0, dx=-70
    FCB 2                ; End marker (path complete)

; Generated from keirin_bg.vec (Malban Draw_Sync_List format)
; Total paths: 3, points: 11
; X bounds: min=-100, max=100, width=200
; Center: (0, 10)

_KEIRIN_BG_WIDTH EQU 200
_KEIRIN_BG_HALF_WIDTH EQU 100
_KEIRIN_BG_HEIGHT EQU 80
_KEIRIN_BG_HALF_HEIGHT EQU 40
_KEIRIN_BG_CENTER_X EQU 0
_KEIRIN_BG_CENTER_Y EQU 10

_KEIRIN_BG_VECTORS:  ; Main entry (header + 3 path(s))
    FDB 3               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _KEIRIN_BG_PATH0        ; pointer to path 0
    FDB _KEIRIN_BG_PATH1        ; pointer to path 1
    FDB _KEIRIN_BG_PATH2        ; pointer to path 2

_KEIRIN_BG_PATH0:    ; Path 0
    FCB 80              ; path0: intensity
    FCB $14,$F6,0,0        ; path0: header (y=20, x=-10)
    FCB $FF,$F6,$E2          ; flag=-1, dy=-10, dx=-30
    FCB $FF,$E2,$E2          ; flag=-1, dy=-30, dx=-30
    FCB 2                ; End marker (path complete)

_KEIRIN_BG_PATH1:    ; Path 1
    FCB 100              ; path1: intensity
    FCB $D8,$9C,0,0        ; path1: header (y=-40, x=-100)
    FCB $FF,$46,$32          ; flag=-1, dy=70, dx=50
    FCB $FF,$0A,$32          ; flag=-1, dy=10, dx=50
    FCB $FF,$F6,$32          ; flag=-1, dy=-10, dx=50
    FCB $FF,$BA,$32          ; flag=-1, dy=-70, dx=50
    FCB 2                ; End marker (path complete)

_KEIRIN_BG_PATH2:    ; Path 2
    FCB 80              ; path2: intensity
    FCB $EC,$46,0,0        ; path2: header (y=-20, x=70)
    FCB $FF,$1E,$E2          ; flag=-1, dy=30, dx=-30
    FCB $FF,$0A,$E2          ; flag=-1, dy=10, dx=-30
    FCB 2                ; End marker (path complete)

; Generated from pyramids_bg.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 10
; X bounds: min=-90, max=90, width=180
; Center: (0, 0)

_PYRAMIDS_BG_WIDTH EQU 180
_PYRAMIDS_BG_HALF_WIDTH EQU 90
_PYRAMIDS_BG_HEIGHT EQU 90
_PYRAMIDS_BG_HALF_HEIGHT EQU 45
_PYRAMIDS_BG_CENTER_X EQU 0
_PYRAMIDS_BG_CENTER_Y EQU 0

_PYRAMIDS_BG_VECTORS:  ; Main entry (header + 4 path(s))
    FDB 4               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PYRAMIDS_BG_PATH0        ; pointer to path 0
    FDB _PYRAMIDS_BG_PATH1        ; pointer to path 1
    FDB _PYRAMIDS_BG_PATH2        ; pointer to path 2
    FDB _PYRAMIDS_BG_PATH3        ; pointer to path 3

_PYRAMIDS_BG_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $2D,$F6,0,0        ; path0: header (y=45, x=-10)
    FCB $FF,$A6,$B0          ; flag=-1, dy=-90, dx=-80
    FCB 2                ; End marker (path complete)

_PYRAMIDS_BG_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $D3,$A6,0,0        ; path1: header (y=-45, x=-90)
    FCB $FF,$5A,$50          ; flag=-1, dy=90, dx=80
    FCB $FF,$A6,$50          ; flag=-1, dy=-90, dx=80
    FCB 2                ; End marker (path complete)

_PYRAMIDS_BG_PATH2:    ; Path 2
    FCB 80              ; path2: intensity
    FCB $D3,$46,0,0        ; path2: header (y=-45, x=70)
    FCB $FF,$5A,$B0          ; flag=-1, dy=90, dx=-80
    FCB 2                ; End marker (path complete)

_PYRAMIDS_BG_PATH3:    ; Path 3
    FCB 90              ; path3: intensity
    FCB $D3,$1E,0,0        ; path3: header (y=-45, x=30)
    FCB $FF,$2D,$1E          ; flag=-1, dy=45, dx=30
    FCB $FF,$D3,$1E          ; flag=-1, dy=-45, dx=30
    FCB 2                ; End marker (path complete)

; Generated from location_marker.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 10
; X bounds: min=-11, max=11, width=22
; Center: (0, 1)

_LOCATION_MARKER_WIDTH EQU 22
_LOCATION_MARKER_HALF_WIDTH EQU 11
_LOCATION_MARKER_HEIGHT EQU 22
_LOCATION_MARKER_HALF_HEIGHT EQU 11
_LOCATION_MARKER_CENTER_X EQU 0
_LOCATION_MARKER_CENTER_Y EQU 1

_LOCATION_MARKER_VECTORS:  ; Main entry (header + 1 path(s))
    FDB 1               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _LOCATION_MARKER_PATH0        ; pointer to path 0

_LOCATION_MARKER_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $0B,$00,0,0        ; path0: header (y=11, x=0)
    FCB $FF,$F8,$04          ; flag=-1, dy=-8, dx=4
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$F9,$FC          ; flag=-1, dy=-7, dx=-4
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB $FF,$05,$F9          ; flag=-1, dy=5, dx=-7
    FCB $FF,$FB,$F9          ; flag=-1, dy=-5, dx=-7
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB $FF,$07,$FC          ; flag=-1, dy=7, dx=-4
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$08,$04          ; flag=-1, dy=8, dx=4
    FCB 2                ; End marker (path complete)

; Generated from hook.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 10
; X bounds: min=-6, max=6, width=12
; Center: (0, 0)

_HOOK_WIDTH EQU 12
_HOOK_HALF_WIDTH EQU 6
_HOOK_HEIGHT EQU 15
_HOOK_HALF_HEIGHT EQU 7
_HOOK_CENTER_X EQU 0
_HOOK_CENTER_Y EQU 0

_HOOK_VECTORS:  ; Main entry (header + 1 path(s))
    FDB 1               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _HOOK_PATH0        ; pointer to path 0

_HOOK_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FC,$FA,0,0        ; path0: header (y=-4, x=-6)
    FCB $FF,$0B,$06          ; flag=-1, dy=11, dx=6
    FCB $FF,$F5,$06          ; flag=-1, dy=-11, dx=6
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$04,$FC          ; flag=-1, dy=4, dx=-4
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$FC,$FC          ; flag=-1, dy=-4, dx=-4
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB 2                ; End marker (path complete)

; Generated from bubble_huge.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 8
; X bounds: min=-25, max=27, width=52
; Center: (1, 0)

_BUBBLE_HUGE_WIDTH EQU 52
_BUBBLE_HUGE_HALF_WIDTH EQU 26
_BUBBLE_HUGE_HEIGHT EQU 52
_BUBBLE_HUGE_HALF_HEIGHT EQU 26
_BUBBLE_HUGE_CENTER_X EQU 1
_BUBBLE_HUGE_CENTER_Y EQU 0

_BUBBLE_HUGE_VECTORS:  ; Main entry (header + 1 path(s))
    FDB 1               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _BUBBLE_HUGE_PATH0        ; pointer to path 0

_BUBBLE_HUGE_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $00,$1A,0,0        ; path0: header (y=0, x=26)
    FCB $FF,$12,$F8          ; flag=-1, dy=18, dx=-8
    FCB $FF,$08,$EE          ; flag=-1, dy=8, dx=-18
    FCB $FF,$F8,$EE          ; flag=-1, dy=-8, dx=-18
    FCB $FF,$EE,$F8          ; flag=-1, dy=-18, dx=-8
    FCB $FF,$EE,$08          ; flag=-1, dy=-18, dx=8
    FCB $FF,$F8,$12          ; flag=-1, dy=-8, dx=18
    FCB $FF,$08,$12          ; flag=-1, dy=8, dx=18
    FCB $FF,$12,$08          ; flag=-1, dy=18, dx=8
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

ASSET_ADDR_TABLE:
    FDB _ANGKOR_BG_VECTORS    ; angkor_bg
    FDB _BARCELONA_BG_VECTORS    ; barcelona_bg
    FDB _MAP_VECTORS    ; map
    FDB _ATHENS_BG_VECTORS    ; athens_bg
    FDB _MAP_THEME_MUSIC    ; map_theme
    FDB _AYERS_BG_VECTORS    ; ayers_bg
    FDB _ANTARCTICA_BG_VECTORS    ; antarctica_bg
    FDB _PANG_THEME_MUSIC    ; pang_theme
    FDB _PLAYER_WALK_1_VECTORS    ; player_walk_1
    FDB _PLAYER_WALK_2_VECTORS    ; player_walk_2
    FDB _PLAYER_WALK_3_VECTORS    ; player_walk_3
    FDB _PLAYER_WALK_4_VECTORS    ; player_walk_4
    FDB _PLAYER_WALK_5_VECTORS    ; player_walk_5
    FDB _LOGO_VECTORS    ; logo
    FDB _FUJI_BG_VECTORS    ; fuji_bg
    FDB _FUJI_LEVEL1_V2_LEVEL    ; fuji_level1_v2
    FDB _NEWYORK_BG_VECTORS    ; newyork_bg
    FDB _BUBBLE_LARGE_VECTORS    ; bubble_large
    FDB _BUBBLE_MEDIUM_VECTORS    ; bubble_medium
    FDB _BUBBLE_SMALL_VECTORS    ; bubble_small
    FDB _MAYAN_BG_VECTORS    ; mayan_bg
    FDB _LENINGRAD_BG_VECTORS    ; leningrad_bg
    FDB _EASTER_BG_VECTORS    ; easter_bg
    FDB _LONDON_BG_VECTORS    ; london_bg
    FDB _PARIS_BG_VECTORS    ; paris_bg
    FDB _KILIMANJARO_BG_VECTORS    ; kilimanjaro_bg
    FDB _TAJ_BG_VECTORS    ; taj_bg
    FDB _BUDDHA_BG_VECTORS    ; buddha_bg
    FDB _KEIRIN_BG_VECTORS    ; keirin_bg
    FDB _PYRAMIDS_BG_VECTORS    ; pyramids_bg
    FDB _LOCATION_MARKER_VECTORS    ; location_marker
    FDB _HOOK_VECTORS    ; hook
    FDB _BUBBLE_HUGE_VECTORS    ; bubble_huge

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
    STA >LEVEL_BANK      ; Save level bank for SHOW/UPDATE_LEVEL_RUNTIME
    STA $DF00            ; Switch bank hardware register

    ; Get level's address from lookup table (2 bytes per entry)
    TFR U,D              ; Reload level index from U
    ASLB                 ; *2 for FDB entries
    ROLA
    LDX #LEVEL_ADDR_TABLE
    LEAX D,X             ; X points to address entry
    LDX ,X               ; X = actual level address in banked ROM

    ; Full level init: call LOAD_LEVEL_RUNTIME with X = level address
    ; (level bank is active, LOAD_LEVEL_RUNTIME code is in fixed helpers bank)
    JSR LOAD_LEVEL_RUNTIME

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

; === CUSTOM VECTOR FONT (M6809) ===
; _FONT_PTRS: 96 FDB entries for ASCII 32..127 → glyph_ptr or 0.
; Each glyph block: stream of (cmd, gx, gy) triples, terminated by FCB 0.
_FONT_PTRS:
    FDB 0       ; ' ' ($20) no glyph
    FDB _FONT_G_21    ; '!' ($21)
    FDB _FONT_G_22    ; '"' ($22)
    FDB 0       ; '#' ($23) no glyph
    FDB 0       ; '$' ($24) no glyph
    FDB 0       ; '%' ($25) no glyph
    FDB 0       ; '&' ($26) no glyph
    FDB 0       ; ''' ($27) no glyph
    FDB 0       ; '(' ($28) no glyph
    FDB 0       ; ')' ($29) no glyph
    FDB 0       ; '*' ($2A) no glyph
    FDB _FONT_G_2B    ; '+' ($2B)
    FDB _FONT_G_2C    ; ',' ($2C)
    FDB _FONT_G_2D    ; '-' ($2D)
    FDB _FONT_G_2E    ; '.' ($2E)
    FDB _FONT_G_2F    ; '/' ($2F)
    FDB _FONT_G_30    ; '0' ($30)
    FDB _FONT_G_31    ; '1' ($31)
    FDB _FONT_G_32    ; '2' ($32)
    FDB _FONT_G_33    ; '3' ($33)
    FDB _FONT_G_34    ; '4' ($34)
    FDB _FONT_G_35    ; '5' ($35)
    FDB _FONT_G_36    ; '6' ($36)
    FDB _FONT_G_37    ; '7' ($37)
    FDB _FONT_G_38    ; '8' ($38)
    FDB _FONT_G_39    ; '9' ($39)
    FDB _FONT_G_3A    ; ':' ($3A)
    FDB _FONT_G_3B    ; ';' ($3B)
    FDB _FONT_G_3C    ; '<' ($3C)
    FDB _FONT_G_3D    ; '=' ($3D)
    FDB _FONT_G_3E    ; '>' ($3E)
    FDB _FONT_G_3F    ; '?' ($3F)
    FDB 0       ; '@' ($40) no glyph
    FDB _FONT_G_41    ; 'A' ($41)
    FDB _FONT_G_42    ; 'B' ($42)
    FDB _FONT_G_43    ; 'C' ($43)
    FDB _FONT_G_44    ; 'D' ($44)
    FDB _FONT_G_45    ; 'E' ($45)
    FDB _FONT_G_46    ; 'F' ($46)
    FDB _FONT_G_47    ; 'G' ($47)
    FDB _FONT_G_48    ; 'H' ($48)
    FDB _FONT_G_49    ; 'I' ($49)
    FDB _FONT_G_4A    ; 'J' ($4A)
    FDB _FONT_G_4B    ; 'K' ($4B)
    FDB _FONT_G_4C    ; 'L' ($4C)
    FDB _FONT_G_4D    ; 'M' ($4D)
    FDB _FONT_G_4E    ; 'N' ($4E)
    FDB _FONT_G_4F    ; 'O' ($4F)
    FDB _FONT_G_50    ; 'P' ($50)
    FDB _FONT_G_51    ; 'Q' ($51)
    FDB _FONT_G_52    ; 'R' ($52)
    FDB _FONT_G_53    ; 'S' ($53)
    FDB _FONT_G_54    ; 'T' ($54)
    FDB _FONT_G_55    ; 'U' ($55)
    FDB _FONT_G_56    ; 'V' ($56)
    FDB _FONT_G_57    ; 'W' ($57)
    FDB _FONT_G_58    ; 'X' ($58)
    FDB _FONT_G_59    ; 'Y' ($59)
    FDB _FONT_G_5A    ; 'Z' ($5A)
    FDB 0       ; '[' ($5B) no glyph
    FDB 0       ; '\' ($5C) no glyph
    FDB 0       ; ']' ($5D) no glyph
    FDB 0       ; '^' ($5E) no glyph
    FDB 0       ; '_' ($5F) no glyph
    FDB 0       ; '`' ($60) no glyph
    FDB _FONT_G_61    ; 'a' ($61)
    FDB _FONT_G_62    ; 'b' ($62)
    FDB _FONT_G_63    ; 'c' ($63)
    FDB _FONT_G_64    ; 'd' ($64)
    FDB _FONT_G_65    ; 'e' ($65)
    FDB _FONT_G_66    ; 'f' ($66)
    FDB _FONT_G_67    ; 'g' ($67)
    FDB _FONT_G_68    ; 'h' ($68)
    FDB _FONT_G_69    ; 'i' ($69)
    FDB _FONT_G_6A    ; 'j' ($6A)
    FDB _FONT_G_6B    ; 'k' ($6B)
    FDB _FONT_G_6C    ; 'l' ($6C)
    FDB _FONT_G_6D    ; 'm' ($6D)
    FDB _FONT_G_6E    ; 'n' ($6E)
    FDB _FONT_G_6F    ; 'o' ($6F)
    FDB _FONT_G_70    ; 'p' ($70)
    FDB _FONT_G_71    ; 'q' ($71)
    FDB _FONT_G_72    ; 'r' ($72)
    FDB _FONT_G_73    ; 's' ($73)
    FDB _FONT_G_74    ; 't' ($74)
    FDB _FONT_G_75    ; 'u' ($75)
    FDB _FONT_G_76    ; 'v' ($76)
    FDB _FONT_G_77    ; 'w' ($77)
    FDB _FONT_G_78    ; 'x' ($78)
    FDB _FONT_G_79    ; 'y' ($79)
    FDB _FONT_G_7A    ; 'z' ($7A)
    FDB 0       ; '{' ($7B) no glyph
    FDB 0       ; '|' ($7C) no glyph
    FDB 0       ; '}' ($7D) no glyph
    FDB 0       ; '~' ($7E) no glyph
    FDB 0       ; '?' ($7F) no glyph

; --- Glyph stroke data ---
_FONT_G_21:
    FCB 1,2,6
    FCB 2,2,2
    FCB 1,2,0
    FCB 2,2,1
    FCB 0    ; end of glyph
_FONT_G_22:
    FCB 1,1,5
    FCB 2,1,6
    FCB 1,3,5
    FCB 2,3,6
    FCB 0    ; end of glyph
_FONT_G_2B:
    FCB 1,2,1
    FCB 2,2,5
    FCB 1,0,3
    FCB 2,4,3
    FCB 0    ; end of glyph
_FONT_G_2C:
    FCB 1,2,1
    FCB 2,1,0
    FCB 0    ; end of glyph
_FONT_G_2D:
    FCB 1,0,3
    FCB 2,4,3
    FCB 0    ; end of glyph
_FONT_G_2E:
    FCB 1,1,0
    FCB 2,2,0
    FCB 0    ; end of glyph
_FONT_G_2F:
    FCB 1,0,0
    FCB 2,4,6
    FCB 0    ; end of glyph
_FONT_G_30:
    FCB 1,0,0
    FCB 2,4,0
    FCB 2,4,6
    FCB 2,0,6
    FCB 2,0,0
    FCB 0    ; end of glyph
_FONT_G_31:
    FCB 1,2,0
    FCB 2,2,6
    FCB 0    ; end of glyph
_FONT_G_32:
    FCB 1,0,6
    FCB 2,4,6
    FCB 2,4,3
    FCB 2,0,3
    FCB 2,0,0
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_33:
    FCB 1,0,6
    FCB 2,4,6
    FCB 2,4,0
    FCB 2,0,0
    FCB 1,4,3
    FCB 2,1,3
    FCB 0    ; end of glyph
_FONT_G_34:
    FCB 1,0,6
    FCB 2,0,3
    FCB 2,4,3
    FCB 1,4,6
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_35:
    FCB 1,4,6
    FCB 2,0,6
    FCB 2,0,3
    FCB 2,4,3
    FCB 2,4,0
    FCB 2,0,0
    FCB 0    ; end of glyph
_FONT_G_36:
    FCB 1,4,6
    FCB 2,0,6
    FCB 2,0,0
    FCB 2,4,0
    FCB 2,4,3
    FCB 2,0,3
    FCB 0    ; end of glyph
_FONT_G_37:
    FCB 1,0,6
    FCB 2,4,6
    FCB 2,2,0
    FCB 0    ; end of glyph
_FONT_G_38:
    FCB 1,0,0
    FCB 2,4,0
    FCB 2,4,6
    FCB 2,0,6
    FCB 2,0,0
    FCB 1,0,3
    FCB 2,4,3
    FCB 0    ; end of glyph
_FONT_G_39:
    FCB 1,4,0
    FCB 2,4,6
    FCB 2,0,6
    FCB 2,0,3
    FCB 2,4,3
    FCB 0    ; end of glyph
_FONT_G_3A:
    FCB 1,2,1
    FCB 2,2,2
    FCB 1,2,4
    FCB 2,2,5
    FCB 0    ; end of glyph
_FONT_G_3B:
    FCB 1,2,4
    FCB 2,2,5
    FCB 1,2,1
    FCB 2,1,0
    FCB 0    ; end of glyph
_FONT_G_3C:
    FCB 1,3,6
    FCB 2,0,3
    FCB 2,3,0
    FCB 0    ; end of glyph
_FONT_G_3D:
    FCB 1,0,4
    FCB 2,4,4
    FCB 1,0,2
    FCB 2,4,2
    FCB 0    ; end of glyph
_FONT_G_3E:
    FCB 1,1,6
    FCB 2,4,3
    FCB 2,1,0
    FCB 0    ; end of glyph
_FONT_G_3F:
    FCB 1,0,6
    FCB 2,4,6
    FCB 2,4,4
    FCB 2,2,3
    FCB 1,2,1
    FCB 2,2,2
    FCB 0    ; end of glyph
_FONT_G_41:
    FCB 1,0,0
    FCB 2,2,6
    FCB 2,4,0
    FCB 1,0,3
    FCB 2,4,3
    FCB 0    ; end of glyph
_FONT_G_42:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,3,6
    FCB 2,3,3
    FCB 2,0,3
    FCB 2,3,3
    FCB 2,3,0
    FCB 2,0,0
    FCB 0    ; end of glyph
_FONT_G_43:
    FCB 1,4,6
    FCB 2,0,6
    FCB 2,0,0
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_44:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,3,6
    FCB 2,4,5
    FCB 2,4,1
    FCB 2,3,0
    FCB 2,0,0
    FCB 0    ; end of glyph
_FONT_G_45:
    FCB 1,4,0
    FCB 2,0,0
    FCB 2,0,6
    FCB 2,4,6
    FCB 1,0,3
    FCB 2,3,3
    FCB 0    ; end of glyph
_FONT_G_46:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,4,6
    FCB 1,0,3
    FCB 2,3,3
    FCB 0    ; end of glyph
_FONT_G_47:
    FCB 1,4,6
    FCB 2,0,6
    FCB 2,0,0
    FCB 2,4,0
    FCB 2,4,3
    FCB 2,2,3
    FCB 0    ; end of glyph
_FONT_G_48:
    FCB 1,0,0
    FCB 2,0,6
    FCB 1,4,0
    FCB 2,4,6
    FCB 1,0,3
    FCB 2,4,3
    FCB 0    ; end of glyph
_FONT_G_49:
    FCB 1,1,0
    FCB 2,3,0
    FCB 1,2,0
    FCB 2,2,6
    FCB 1,1,6
    FCB 2,3,6
    FCB 0    ; end of glyph
_FONT_G_4A:
    FCB 1,0,1
    FCB 2,1,0
    FCB 2,4,0
    FCB 2,4,6
    FCB 1,1,6
    FCB 2,3,6
    FCB 0    ; end of glyph
_FONT_G_4B:
    FCB 1,0,0
    FCB 2,0,6
    FCB 1,0,3
    FCB 2,4,6
    FCB 1,0,3
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_4C:
    FCB 1,0,6
    FCB 2,0,0
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_4D:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,2,3
    FCB 2,4,6
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_4E:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,4,0
    FCB 2,4,6
    FCB 0    ; end of glyph
_FONT_G_4F:
    FCB 1,0,0
    FCB 2,4,0
    FCB 2,4,6
    FCB 2,0,6
    FCB 2,0,0
    FCB 0    ; end of glyph
_FONT_G_50:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,3,6
    FCB 2,4,5
    FCB 2,4,4
    FCB 2,3,3
    FCB 2,0,3
    FCB 0    ; end of glyph
_FONT_G_51:
    FCB 1,0,0
    FCB 2,4,0
    FCB 2,4,6
    FCB 2,0,6
    FCB 2,0,0
    FCB 1,3,1
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_52:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,3,6
    FCB 2,4,5
    FCB 2,4,4
    FCB 2,3,3
    FCB 2,0,3
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_53:
    FCB 1,4,6
    FCB 2,0,6
    FCB 2,0,3
    FCB 2,4,3
    FCB 2,4,0
    FCB 2,0,0
    FCB 0    ; end of glyph
_FONT_G_54:
    FCB 1,0,6
    FCB 2,4,6
    FCB 1,2,6
    FCB 2,2,0
    FCB 0    ; end of glyph
_FONT_G_55:
    FCB 1,0,6
    FCB 2,0,0
    FCB 2,4,0
    FCB 2,4,6
    FCB 0    ; end of glyph
_FONT_G_56:
    FCB 1,0,6
    FCB 2,2,0
    FCB 2,4,6
    FCB 0    ; end of glyph
_FONT_G_57:
    FCB 1,0,6
    FCB 2,1,0
    FCB 2,2,3
    FCB 2,3,0
    FCB 2,4,6
    FCB 0    ; end of glyph
_FONT_G_58:
    FCB 1,0,0
    FCB 2,4,6
    FCB 1,0,6
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_59:
    FCB 1,0,6
    FCB 2,2,3
    FCB 2,4,6
    FCB 1,2,3
    FCB 2,2,0
    FCB 0    ; end of glyph
_FONT_G_5A:
    FCB 1,0,6
    FCB 2,4,6
    FCB 2,0,0
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_61:
    FCB 1,0,0
    FCB 2,2,6
    FCB 2,4,0
    FCB 1,0,3
    FCB 2,4,3
    FCB 0    ; end of glyph
_FONT_G_62:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,3,6
    FCB 2,3,3
    FCB 2,0,3
    FCB 2,3,3
    FCB 2,3,0
    FCB 2,0,0
    FCB 0    ; end of glyph
_FONT_G_63:
    FCB 1,4,6
    FCB 2,0,6
    FCB 2,0,0
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_64:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,3,6
    FCB 2,4,5
    FCB 2,4,1
    FCB 2,3,0
    FCB 2,0,0
    FCB 0    ; end of glyph
_FONT_G_65:
    FCB 1,4,0
    FCB 2,0,0
    FCB 2,0,6
    FCB 2,4,6
    FCB 1,0,3
    FCB 2,3,3
    FCB 0    ; end of glyph
_FONT_G_66:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,4,6
    FCB 1,0,3
    FCB 2,3,3
    FCB 0    ; end of glyph
_FONT_G_67:
    FCB 1,4,6
    FCB 2,0,6
    FCB 2,0,0
    FCB 2,4,0
    FCB 2,4,3
    FCB 2,2,3
    FCB 0    ; end of glyph
_FONT_G_68:
    FCB 1,0,0
    FCB 2,0,6
    FCB 1,4,0
    FCB 2,4,6
    FCB 1,0,3
    FCB 2,4,3
    FCB 0    ; end of glyph
_FONT_G_69:
    FCB 1,1,0
    FCB 2,3,0
    FCB 1,2,0
    FCB 2,2,6
    FCB 1,1,6
    FCB 2,3,6
    FCB 0    ; end of glyph
_FONT_G_6A:
    FCB 1,0,1
    FCB 2,1,0
    FCB 2,4,0
    FCB 2,4,6
    FCB 1,1,6
    FCB 2,3,6
    FCB 0    ; end of glyph
_FONT_G_6B:
    FCB 1,0,0
    FCB 2,0,6
    FCB 1,0,3
    FCB 2,4,6
    FCB 1,0,3
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_6C:
    FCB 1,0,6
    FCB 2,0,0
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_6D:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,2,3
    FCB 2,4,6
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_6E:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,4,0
    FCB 2,4,6
    FCB 0    ; end of glyph
_FONT_G_6F:
    FCB 1,0,0
    FCB 2,4,0
    FCB 2,4,6
    FCB 2,0,6
    FCB 2,0,0
    FCB 0    ; end of glyph
_FONT_G_70:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,3,6
    FCB 2,4,5
    FCB 2,4,4
    FCB 2,3,3
    FCB 2,0,3
    FCB 0    ; end of glyph
_FONT_G_71:
    FCB 1,0,0
    FCB 2,4,0
    FCB 2,4,6
    FCB 2,0,6
    FCB 2,0,0
    FCB 1,3,1
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_72:
    FCB 1,0,0
    FCB 2,0,6
    FCB 2,3,6
    FCB 2,4,5
    FCB 2,4,4
    FCB 2,3,3
    FCB 2,0,3
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_73:
    FCB 1,4,6
    FCB 2,0,6
    FCB 2,0,3
    FCB 2,4,3
    FCB 2,4,0
    FCB 2,0,0
    FCB 0    ; end of glyph
_FONT_G_74:
    FCB 1,0,6
    FCB 2,4,6
    FCB 1,2,6
    FCB 2,2,0
    FCB 0    ; end of glyph
_FONT_G_75:
    FCB 1,0,6
    FCB 2,0,0
    FCB 2,4,0
    FCB 2,4,6
    FCB 0    ; end of glyph
_FONT_G_76:
    FCB 1,0,6
    FCB 2,2,0
    FCB 2,4,6
    FCB 0    ; end of glyph
_FONT_G_77:
    FCB 1,0,6
    FCB 2,1,0
    FCB 2,2,3
    FCB 2,3,0
    FCB 2,4,6
    FCB 0    ; end of glyph
_FONT_G_78:
    FCB 1,0,0
    FCB 2,4,6
    FCB 1,0,6
    FCB 2,4,0
    FCB 0    ; end of glyph
_FONT_G_79:
    FCB 1,0,6
    FCB 2,2,3
    FCB 2,4,6
    FCB 1,2,3
    FCB 2,2,0
    FCB 0    ; end of glyph
_FONT_G_7A:
    FCB 1,0,6
    FCB 2,4,6
    FCB 2,0,0
    FCB 2,4,0
    FCB 0    ; end of glyph

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

MUL16:
    ; Signed 16x16->16 multiply: D = X * D (lower 16 bits, sign-correct)
    ; Uses 6809 MUL (8x8->16) for constant-time execution.
    ; Stack after PSHS X,B,A: [SP+0]=A=D_hi=b_hi, [SP+1]=B=D_lo=b_lo,
    ;                         [SP+2]=X_hi=a_hi,  [SP+3]=X_lo=a_lo
    ; Result = a_lo*b_lo + (a_hi*b_lo + a_lo*b_hi)*256  (mod 65536)
    PSHS X,B,A
    ; Step 1: a_lo * b_lo -> 16-bit partial product
    LDA 3,S         ; A = a_lo (X low byte)
    LDB 1,S         ; B = b_lo (D low byte)
    MUL             ; D = a_lo * b_lo (unsigned 16-bit)
    STA TMPPTR      ; TMPPTR   = P0_hi (carry into result bits [15:8])
    STB TMPPTR+1    ; TMPPTR+1 = P0_lo (result bits [7:0])
    ; Step 2: a_hi * b_lo -> only low byte adds to result[15:8]
    LDA 2,S         ; A = a_hi (X high byte)
    LDB 1,S         ; B = b_lo (D low byte)
    MUL             ; D = a_hi * b_lo
    ADDB TMPPTR     ; B += P0_hi (ignore carry = mod 256)
    STB TMPPTR      ; TMPPTR = accumulated result[15:8]
    ; Step 3: a_lo * b_hi -> only low byte adds to result[15:8]
    LDA 3,S         ; A = a_lo (X low byte)
    LDB 0,S         ; B = b_hi (D high byte)
    MUL             ; D = a_lo * b_hi
    ADDB TMPPTR     ; B += accumulated result[15:8] (mod 256)
    TFR B,A         ; A = result_hi
    LDB TMPPTR+1    ; B = result_lo
    LEAS 4,S        ; restore stack
    RTS

DIV16:
    ; Signed 16-bit division: D = X / D
    ; X = dividend (i16), D = divisor (i16) -> D = quotient
    STD TMPPTR          ; Save divisor
    TFR X,D             ; D = dividend (TFR does NOT set flags!)
    CMPD #0             ; Set flags from FULL D BEFORE any LDA corrupts high byte
    BPL .D16_DPOS       ; if dividend >= 0, skip negation
    COMA
    COMB
    ADDD #1             ; D = |dividend|
    STD TMPVAL          ; store |dividend| BEFORE LDA corrupts A (high byte of D)
    LDA #1
    STA TMPPTR2         ; sign_flag = 1 (dividend was negative)
    BRA .D16_RCHECK
.D16_DPOS:
    STD TMPVAL          ; dividend is positive, store as-is
    LDA #0
    STA TMPPTR2         ; sign_flag = 0 (positive result)
.D16_RCHECK:
    LDD TMPPTR          ; D = divisor
    BPL .D16_RPOS       ; if divisor >= 0, skip negation
    COMA
    COMB
    ADDD #1             ; D = |divisor|
    STD TMPPTR          ; TMPPTR = |divisor|
    LDA TMPPTR2
    EORA #1
    STA TMPPTR2         ; toggle sign flag (XOR with 1)
.D16_RPOS:
    LDD #0
    STD RESULT          ; quotient = 0
.D16_LOOP:
    LDD TMPVAL
    SUBD TMPPTR         ; |dividend| - |divisor|
    BLO .D16_END        ; if |dividend| < |divisor|, done
    STD TMPVAL          ; update remainder
    LDD RESULT
    ADDD #1
    STD RESULT          ; quotient++
    BRA .D16_LOOP
.D16_END:
    LDD RESULT          ; D = unsigned quotient
    LDA TMPPTR2
    BEQ .D16_DONE       ; zero = positive result
    COMA
    COMB
    ADDD #1             ; negate for negative result
.D16_DONE:
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

; J1_Y() - Read Joystick 1 Y axis from cached BIOS value at $C81C
J1Y_BUILTIN:
    LDB >$C81C   ; Vec_Joy_1_Y
    SEX
    ADDD #2
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
; === LOAD_LEVEL_RUNTIME ===
; Load level data from ROM and copy GP objects to RAM buffer
; Input:  X = pointer to level data in ROM
; Output: LEVEL_PTR = level header pointer
;         RESULT    = level header pointer (return value)
; BG and FG layers are static — read from ROM directly.
; GP layer is copied to LEVEL_GP_BUFFER (14 bytes/object).
LOAD_LEVEL_RUNTIME:
    PSHS D,X,Y,U     ; Preserve registers
    
    ; Store level pointer and mark as loaded
    STX >LEVEL_PTR
    LDA #1
    STA >LEVEL_LOADED    ; Mark level as loaded
    
    ; Camera is NOT reset here (matches pitrex/rp2350). It is initialised once
    ; at boot in MAIN; the game sets it via SET_CAMERA_Y before LOAD_LEVEL, and
    ; GET_LEVEL_FLOOR_Y / the SPAWN_ENEMIES Y-filter read it after this call.
    
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
    
    ; Read scroll limits from ROM header (+21..+28)
    ; X is now at +21 (right after the 3 FDB layer pointers)
    LDD ,X++         ; D = scrollLimit left
    STD >SCROLL_LIMIT_LEFT
    LDD ,X++         ; D = scrollLimit right
    STD >SCROLL_LIMIT_RIGHT
    LDD ,X++         ; D = scrollLimit top
    STD >SCROLL_LIMIT_TOP
    LDD ,X++         ; D = scrollLimit bottom
    STD >SCROLL_LIMIT_BOTTOM
    
    ; Read enemy data from header (+29: count, +30,+31: instances_ptr)
    LDB ,X+         ; B = enemy_count
    STB >LEVEL_ENEMY_COUNT
    LDD ,X++        ; D = enemy_instances_ptr (advance past +30..+31)
    STD >LEVEL_ENEMY_INSTANCES_PTR
    LEAX 2,X        ; skip groundBottomOffset (+32..+33)
    
    ; Per-screen object index (+34..+40)
    LDB ,X+         ; B = screen_count
    STB >LEVEL_SCREEN_COUNT
    LDD ,X++        ; D = bg_screens_ptr
    STD >LEVEL_BG_SCREENS_PTR
    LDD ,X++        ; D = gp_screens_ptr
    STD >LEVEL_GP_SCREENS_PTR
    LDD ,X          ; D = fg_screens_ptr
    STD >LEVEL_FG_SCREENS_PTR
    
    ; === Setup GP pointer: point directly to ROM (matches core) ===
    ; GP objects are read from ROM with stride=21 (stride-21 format), same as BG/FG
    LDB >LEVEL_GP_COUNT
    BEQ LLR_SKIP_GP  ; Skip if no GP objects
    LDD >LEVEL_GP_ROM_PTR ; Just point to ROM
    STD >LEVEL_GP_PTR    ; Store ROM pointer
    
LLR_GP_DONE:
LLR_SKIP_GP:
    
    ; Return level pointer in RESULT
    LDX >LEVEL_PTR
    STX RESULT
    
    PULS D,X,Y,U,PC  ; Restore and return
    
; === LLR_COPY_OBJECTS - LEGACY (not called; GP objects read from ROM directly)
; Input:  B = count, X = source (ROM, 21 bytes/obj stride-21), U = dest (RAM)
; ROM object layout (21 bytes, stride-21):
;   +0: type, +1-2: x(FDB), +3-4: y(FDB), +5-6: scale(FDB),
;   +7: rotation, +8: intensity, +9: velocity_x, +10: velocity_y,
;   +11: physics_flags, +12: collision_flags, +13: collision_size,
;   +14-15: spawn_delay(FDB), +16: vector_bank(FCB), +17-18: vector_ptr(FDB),
;   +19: half_width, +20: half_height
; RAM object layout (15 bytes):
;   +0-1: world_x(FDB i16), +2: y(i8), +3: scale(low), +4: rotation,
;   +5: velocity_x, +6: velocity_y, +7: physics_flags, +8: collision_flags,
;   +9: collision_size, +10: spawn_delay(low), +11-12: vector_ptr, +13: half_width, +14: half_height
; Clobbers: A, B, X, U
LLR_COPY_OBJECTS:
LLR_COPY_LOOP:
    TSTB
    BEQ LLR_COPY_DONE
    PSHS B           ; Save counter (LDD will clobber B)
    
    ; X points to ROM object start (+0 = type)
    LEAX 1,X         ; Skip type (+0), X now at +1 (x FDB high)
    
    ; RAM +0-1: world_x FDB (16-bit, ROM +1-2)
    LDA ,X           ; ROM +1 = high byte of x FDB
    STA ,U+
    LDA 1,X          ; ROM +2 = low byte of x FDB
    STA ,U+
    ; RAM +2: y low byte (ROM +4, low byte of y FDB)
    LDA 3,X          ; ROM +4 = low byte of y FDB
    STA ,U+
    ; RAM +3: scale low byte (ROM +6, low byte of scale FDB)
    LDA 5,X          ; ROM +6 = low byte of scale FDB
    STA ,U+
    ; RAM +4: rotation (ROM +7)
    LDA 6,X          ; ROM +7 = rotation
    STA ,U+
    ; Skip to ROM +9 (past intensity at ROM +8)
    LEAX 8,X         ; X now points to ROM +9 (velocity_x)
    ; RAM +5: velocity_x (ROM +9)
    LDA ,X+          ; ROM +9
    STA ,U+
    ; RAM +6: velocity_y (ROM +10)
    LDA ,X+          ; ROM +10
    STA ,U+
    ; RAM +7: physics_flags (ROM +11)
    LDA ,X+          ; ROM +11
    STA ,U+
    ; RAM +8: collision_flags (ROM +12)
    LDA ,X+          ; ROM +12
    STA ,U+
    ; RAM +9: collision_size (ROM +13)
    LDA ,X+          ; ROM +13
    STA ,U+
    ; RAM +10: spawn_delay low byte (ROM +15, skip high at ROM +14)
    LDA 1,X          ; ROM +15 = low byte of spawn_delay FDB
    STA ,U+
    LEAX 3,X         ; Skip spawn_delay FDB (2 bytes) + vector_bank (1), X now at ROM+17
    ; RAM +11-12: vector_ptr FDB (ROM +17-18, stride-21)
    LDD ,X++         ; ROM +17-18 = vector_ptr FDB
    STD ,U++
    ; RAM +13-14: half_width + half_height (ROM +19-20, stride-21)
    LDD ,X++         ; ROM +19-20
    STD ,U++
    ; X is now past end of this ROM object (ROM+1 + 8 + 5 + 3 + 2 + 2 = +21 total)
    ; NOTE: We started at ROM+1 (after LEAX 1,X), walked:
    ;   ,X and 1,X and 3,X and 5,X and 6,X via indexed → X unchanged
    ;   then LEAX 8,X (X now at ROM+9)
    ;   then 5 post-increment ,X+ → X at ROM+14
    ;   then LEAX 3,X (X at ROM+17)
    ;   then 2x LDD ,X++ → X at ROM+21
    ;   ROM+21 from original ROM+0 = next object start (stride-21)
    
    PULS B           ; Restore counter
    DECB
    BRA LLR_COPY_LOOP
LLR_COPY_DONE:
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
PRINT_TEXT_STR_107868:
    FCC "map"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3208483:
    FCC "hook"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3327403:
    FCC "logo"
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

; === CONST ARRAY DATA (relocated to fixed bank - accessible from any bank) ===
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
; MAIN PROGRAM (Bank #0)
;***************************************************************************




;***************************************************************************
; INTERRUPT VECTORS (Bank #31 Fixed Window)
;***************************************************************************
ORG $FFFE
FDB CUSTOM_RESET
