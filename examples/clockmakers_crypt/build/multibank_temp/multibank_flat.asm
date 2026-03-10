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
    FCC "CLOCKMAKER'S CRYPT"
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
MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    LDA #$F8
    STA TEXT_SCALE_H      ; Default height = -8 (normal size)
    LDA #$48
    STA TEXT_SCALE_W      ; Default width = 72 (normal size)
    LDD #0  ; const STATE_TITLE
    STD VAR_SCREEN
    LDD #0
    STD VAR_BLINK_TIMER
    LDD #0
    STD VAR_BLINK_ON
    LDD #0
    STD VAR_INTRO_PAGE
    LDD #0  ; const ROOM_ENTRANCE
    STD VAR_CURRENT_ROOM
    LDD #0
    STD VAR_PLAYER_X
    LDD #-115
    STD VAR_PLAYER_Y
    LDD #0
    STD VAR_SCROLL_X
    LDD #5
    STD VAR_PLAYER_SPEED
    LDD #0  ; const VERB_EXAMINE
    STD VAR_CURRENT_VERB
    LDD #-1
    STD VAR_NEAR_HS
    LDD #0
    STD VAR_MSG_ID
    LDD #0
    STD VAR_MSG_TIMER
    LDD #0
    STD VAR_ROOM_EXIT
    LDD #0
    STD VAR_FLAGS_A
    LDD #0
    STD VAR_FLAGS_B
    ; Copy array 'NPC_STATE' from ROM to RAM (4 elements)
    LDX #ARRAY_NPC_STATE_DATA       ; Source: ROM array data
    LDU #VAR_NPC_STATE_DATA       ; Dest: RAM array space
    LDD #4        ; Number of elements
.COPY_LOOP_0:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_0 ; Loop until done (LBNE for long branch)
    LDX #VAR_NPC_STATE_DATA    ; Array now in RAM
    STX VAR_NPC_STATE
    LDD #1
    STD VAR_EXIT_ROOM_TARGET
    LDD #1  ; const MUSIC_TITLE
    STD VAR_CURRENT_MUSIC
    LDD #0
    STD VAR_BTN1_FIRED
    LDD #0
    STD VAR_BTN2_FIRED
    LDD #0
    STD VAR_BTN3_FIRED
    LDD #0
    STD VAR_PREV_BTN1
    LDD #0
    STD VAR_PREV_BTN2
    LDD #0
    STD VAR_PREV_BTN3
    ; Copy array 'INV_ITEMS' from ROM to RAM (8 elements)
    LDX #ARRAY_INV_ITEMS_DATA       ; Source: ROM array data
    LDU #VAR_INV_ITEMS_DATA       ; Dest: RAM array space
    LDD #8        ; Number of elements
.COPY_LOOP_1:
    LDY ,X++        ; Load word from ROM, increment source
    STY ,U++        ; Store word to RAM, increment dest
    SUBD #1         ; Decrement counter
    LBNE .COPY_LOOP_1 ; Loop until done (LBNE for long branch)
    LDX #VAR_INV_ITEMS_DATA    ; Array now in RAM
    STX VAR_INV_ITEMS
    LDD #0
    STD VAR_INV_COUNT
    LDD #0
    STD VAR_INV_WEIGHT
    LDD #0
    STD VAR_SHOW_INVENTORY
    LDD #-1
    STD VAR_ACTIVE_ITEM
    LDD #0
    STD VAR_INV_CURSOR
    LDD #60
    STD VAR_HEARTBEAT_TEMPO
    LDD #0
    STD VAR_HEARTBEAT_TIMER
    LDD #-110
    STD VAR_TESTAMENT_Y
    LDD #0
    STD VAR_TESTAMENT_PAGE
    LDD #-110
    STD VAR_ENDING_Y
    LDD #0
    STD VAR_SKIPPEDFRAMES
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
    ; PLAY_MUSIC("intro") - play music asset (index=1)
    LDX #1        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    ; TODO: Statement Pass { source_line: 213 }

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
    LDD #10
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SKIPPEDFRAMES
    CMPD TMPVAL
    LBLT .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_1
    LDD >VAR_SKIPPEDFRAMES
    STD TMPVAL          ; Save left operand
    LDD #1
    ADDD TMPVAL         ; D = D + TMPVAL
    STD VAR_SKIPPEDFRAMES
    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed
    BITA #$01
    BNE .J1B1_0_ON
    LDD #0
    BRA .J1B1_0_END
.J1B1_0_ON:
    LDD #1
.J1B1_0_END:
    STD RESULT
    STD VAR_PREV_BTN1
    LDA >$C80F   ; Vec_Btns_1: bit1=1 means btn2 pressed
    BITA #$02
    BNE .J1B2_1_ON
    LDD #0
    BRA .J1B2_1_END
.J1B2_1_ON:
    LDD #1
.J1B2_1_END:
    STD RESULT
    STD VAR_PREV_BTN2
    LDA >$C80F   ; Vec_Btns_1: bit2=1 means btn3 pressed
    BITA #$04
    BNE .J1B3_2_ON
    LDD #0
    BRA .J1B3_2_END
.J1B3_2_ON:
    LDD #1
.J1B3_2_END:
    STD RESULT
    STD VAR_PREV_BTN3
    RTS
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    LDA >$C80F   ; Vec_Btns_1: bit0=1 means btn1 pressed
    BITA #$01
    BNE .J1B1_3_ON
    LDD #0
    BRA .J1B1_3_END
.J1B1_3_ON:
    LDD #1
.J1B1_3_END:
    STD RESULT
    STD VAR_RAW1
    LDA >$C80F   ; Vec_Btns_1: bit1=1 means btn2 pressed
    BITA #$02
    BNE .J1B2_4_ON
    LDD #0
    BRA .J1B2_4_END
.J1B2_4_ON:
    LDD #1
.J1B2_4_END:
    STD RESULT
    STD VAR_RAW2
    LDA >$C80F   ; Vec_Btns_1: bit2=1 means btn3 pressed
    BITA #$04
    BNE .J1B3_5_ON
    LDD #0
    BRA .J1B3_5_END
.J1B3_5_ON:
    LDD #1
.J1B3_5_END:
    STD RESULT
    STD VAR_RAW3
    LDD #0
    STD VAR_BTN1_FIRED
    LDD #0
    STD VAR_BTN2_FIRED
    LDD #0
    STD VAR_BTN3_FIRED
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_RAW1
    CMPD TMPVAL
    LBEQ .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    LBEQ .LOGIC_1_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_BTN1
    CMPD TMPVAL
    LBEQ .CMP_3_TRUE
    LDD #0
    LBRA .CMP_3_END
.CMP_3_TRUE:
    LDD #1
.CMP_3_END:
    LBEQ .LOGIC_1_FALSE
    LDD #1
    LBRA .LOGIC_1_END
.LOGIC_1_FALSE:
    LDD #0
.LOGIC_1_END:
    LBEQ IF_NEXT_3
    LDD #1
    STD VAR_BTN1_FIRED
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_RAW2
    CMPD TMPVAL
    LBEQ .CMP_5_TRUE
    LDD #0
    LBRA .CMP_5_END
.CMP_5_TRUE:
    LDD #1
.CMP_5_END:
    LBEQ .LOGIC_4_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_BTN2
    CMPD TMPVAL
    LBEQ .CMP_6_TRUE
    LDD #0
    LBRA .CMP_6_END
.CMP_6_TRUE:
    LDD #1
.CMP_6_END:
    LBEQ .LOGIC_4_FALSE
    LDD #1
    LBRA .LOGIC_4_END
.LOGIC_4_FALSE:
    LDD #0
.LOGIC_4_END:
    LBEQ IF_NEXT_5
    LDD #1
    STD VAR_BTN2_FIRED
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_RAW3
    CMPD TMPVAL
    LBEQ .CMP_8_TRUE
    LDD #0
    LBRA .CMP_8_END
.CMP_8_TRUE:
    LDD #1
.CMP_8_END:
    LBEQ .LOGIC_7_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_BTN3
    CMPD TMPVAL
    LBEQ .CMP_9_TRUE
    LDD #0
    LBRA .CMP_9_END
.CMP_9_TRUE:
    LDD #1
.CMP_9_END:
    LBEQ .LOGIC_7_FALSE
    LDD #1
    LBRA .LOGIC_7_END
.LOGIC_7_FALSE:
    LDD #0
.LOGIC_7_END:
    LBEQ IF_NEXT_7
    LDD #1
    STD VAR_BTN3_FIRED
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
    LDD >VAR_RAW1
    STD VAR_PREV_BTN1
    LDD >VAR_RAW2
    STD VAR_PREV_BTN2
    LDD >VAR_RAW3
    STD VAR_PREV_BTN3
    LDD #2  ; const STATE_ROOM
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SCREEN
    CMPD TMPVAL
    LBEQ .CMP_10_TRUE
    LDD #0
    LBRA .CMP_10_END
.CMP_10_TRUE:
    LDD #1
.CMP_10_END:
    LBEQ IF_NEXT_9
    LDD >VAR_HEARTBEAT_TIMER
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_HEARTBEAT_TIMER
    LDD >VAR_HEARTBEAT_TEMPO
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_HEARTBEAT_TIMER
    CMPD TMPVAL
    LBGE .CMP_11_TRUE
    LDD #0
    LBRA .CMP_11_END
.CMP_11_TRUE:
    LDD #1
.CMP_11_END:
    LBEQ IF_NEXT_11
    LDD #0
    STD VAR_HEARTBEAT_TIMER
    ; PLAY_SFX("heartbeat") - play SFX asset (index=1)
    LDX #1        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_10
IF_NEXT_11:
IF_END_10:
    LBRA IF_END_8
IF_NEXT_9:
IF_END_8:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN2_FIRED
    CMPD TMPVAL
    LBEQ .CMP_12_TRUE
    LDD #0
    LBRA .CMP_12_END
.CMP_12_TRUE:
    LDD #1
.CMP_12_END:
    LBEQ IF_NEXT_13
    LDD #2  ; const STATE_ROOM
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SCREEN
    CMPD TMPVAL
    LBEQ .CMP_13_TRUE
    LDD #0
    LBRA .CMP_13_END
.CMP_13_TRUE:
    LDD #1
.CMP_13_END:
    LBEQ IF_NEXT_15
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SHOW_INVENTORY
    CMPD TMPVAL
    LBEQ .CMP_14_TRUE
    LDD #0
    LBRA .CMP_14_END
.CMP_14_TRUE:
    LDD #1
.CMP_14_END:
    LBEQ IF_NEXT_17
    LDD #1
    STD VAR_SHOW_INVENTORY
    LBRA IF_END_16
IF_NEXT_17:
    LDD #0
    STD VAR_SHOW_INVENTORY
IF_END_16:
    LBRA IF_END_14
IF_NEXT_15:
IF_END_14:
    LBRA IF_END_12
IF_NEXT_13:
IF_END_12:
    LDD #0  ; const STATE_TITLE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SCREEN
    CMPD TMPVAL
    LBEQ .CMP_15_TRUE
    LDD #0
    LBRA .CMP_15_END
.CMP_15_TRUE:
    LDD #1
.CMP_15_END:
    LBEQ IF_NEXT_19
    JSR DRAW_TITLE
    LBRA IF_END_18
IF_NEXT_19:
    LDD #1  ; const STATE_INTRO
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SCREEN
    CMPD TMPVAL
    LBEQ .CMP_16_TRUE
    LDD #0
    LBRA .CMP_16_END
.CMP_16_TRUE:
    LDD #1
.CMP_16_END:
    LBEQ IF_NEXT_20
    JSR DRAW_INTRO
    LBRA IF_END_18
IF_NEXT_20:
    LDD #2  ; const STATE_ROOM
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SCREEN
    CMPD TMPVAL
    LBEQ .CMP_17_TRUE
    LDD #0
    LBRA .CMP_17_END
.CMP_17_TRUE:
    LDD #1
.CMP_17_END:
    LBEQ IF_NEXT_21
    JSR TRAMP_UPDATE_ROOM  ; cross-bank trampoline (bank #0 -> bank #1)
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SHOW_INVENTORY
    CMPD TMPVAL
    LBEQ .CMP_18_TRUE
    LDD #0
    LBRA .CMP_18_END
.CMP_18_TRUE:
    LDD #1
.CMP_18_END:
    LBEQ IF_NEXT_23
    JSR DRAW_INVENTORY
    LBRA IF_END_22
IF_NEXT_23:
    JSR DRAW_ROOM
IF_END_22:
    LBRA IF_END_18
IF_NEXT_21:
    LDD #4  ; const STATE_TESTAMENT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SCREEN
    CMPD TMPVAL
    LBEQ .CMP_19_TRUE
    LDD #0
    LBRA .CMP_19_END
.CMP_19_TRUE:
    LDD #1
.CMP_19_END:
    LBEQ IF_NEXT_24
    JSR TRAMP_DRAW_TESTAMENT  ; cross-bank trampoline (bank #0 -> bank #1)
    LBRA IF_END_18
IF_NEXT_24:
    LDD #3  ; const STATE_ENDING
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SCREEN
    CMPD TMPVAL
    LBEQ .CMP_20_TRUE
    LDD #0
    LBRA .CMP_20_END
.CMP_20_TRUE:
    LDD #1
.CMP_20_END:
    LBEQ IF_END_18
    JSR TRAMP_DRAW_ENDING  ; cross-bank trampoline (bank #0 -> bank #1)
    LBRA IF_END_18
IF_END_18:
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX (after all game logic)
    RTS

; Function: DRAW_TITLE (Bank #0)
DRAW_TITLE:
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: crypt_logo (index=3, 40 paths)
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
    LDX #3        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    CLR DRAW_VEC_INTENSITY  ; Reset: next DRAW_VECTOR uses .vec intensities
    LDD #0
    STD RESULT
    LDD >VAR_BLINK_TIMER
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_BLINK_TIMER
    LDD #40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BLINK_TIMER
    CMPD TMPVAL
    LBGE .CMP_21_TRUE
    LDD #0
    LBRA .CMP_21_END
.CMP_21_TRUE:
    LDD #1
.CMP_21_END:
    LBEQ IF_NEXT_26
    LDD #0
    STD VAR_BLINK_TIMER
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BLINK_ON
    CMPD TMPVAL
    LBEQ .CMP_22_TRUE
    LDD #0
    LBRA .CMP_22_END
.CMP_22_TRUE:
    LDD #1
.CMP_22_END:
    LBEQ IF_NEXT_28
    LDD #1
    STD VAR_BLINK_ON
    LBRA IF_END_27
IF_NEXT_28:
    LDD #0
    STD VAR_BLINK_ON
IF_END_27:
    LBRA IF_END_25
IF_NEXT_26:
IF_END_25:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BLINK_ON
    CMPD TMPVAL
    LBEQ .CMP_23_TRUE
    LDD #0
    LBRA .CMP_23_END
.CMP_23_TRUE:
    LDD #1
.CMP_23_END:
    LBEQ IF_NEXT_30
    LDD #7
    STD TMPPTR2     ; Save n (TMPPTR2+1 = n)
    NEGB            ; B = -n -> TEXT_SCALE_H
    STB >TEXT_SCALE_H
    LDB TMPPTR2+1   ; Reload n (from TMPPTR2, not RESULT)
    ASLB            ; n*2
    ASLB            ; n*4
    ASLB            ; n*8
    ADDB TMPPTR2+1  ; n*8 + n = n*9 -> TEXT_SCALE_W
    STB >TEXT_SCALE_W
    ; PRINT_TEXT: Print text at position
    LDD #-77
    STD VAR_ARG0
    LDD #-100
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_3317733282004581041      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_29
IF_NEXT_30:
IF_END_29:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN1_FIRED
    CMPD TMPVAL
    LBEQ .CMP_24_TRUE
    LDD #0
    LBRA .CMP_24_END
.CMP_24_TRUE:
    LDD #1
.CMP_24_END:
    LBEQ IF_NEXT_32
    LDD #0
    STD VAR_INTRO_PAGE
    LDD #1  ; const STATE_INTRO
    STD VAR_SCREEN
    LBRA IF_END_31
IF_NEXT_32:
IF_END_31:
    RTS

; Function: DRAW_INTRO (Bank #0)
DRAW_INTRO:
    LDD #7
    STD TMPPTR2     ; Save n (TMPPTR2+1 = n)
    NEGB            ; B = -n -> TEXT_SCALE_H
    STB >TEXT_SCALE_H
    LDB TMPPTR2+1   ; Reload n (from TMPPTR2, not RESULT)
    ASLB            ; n*2
    ASLB            ; n*4
    ASLB            ; n*8
    ADDB TMPPTR2+1  ; n*8 + n = n*9 -> TEXT_SCALE_W
    STB >TEXT_SCALE_W
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INTRO_PAGE
    CMPD TMPVAL
    LBEQ .CMP_25_TRUE
    LDD #0
    LBRA .CMP_25_END
.CMP_25_TRUE:
    LDD #1
.CMP_25_END:
    LBEQ IF_NEXT_34
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD VAR_ARG0
    LDD #40
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_17850884399050856369      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD VAR_ARG0
    LDD #20
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_4088011977317884966      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD VAR_ARG0
    LDD #0
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_17028423667663067371      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD VAR_ARG0
    LDD #-20
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_4810967809196323313      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #60
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD VAR_ARG0
    LDD #-80
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_9120385760502433312      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_33
IF_NEXT_34:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INTRO_PAGE
    CMPD TMPVAL
    LBEQ .CMP_26_TRUE
    LDD #0
    LBRA .CMP_26_END
.CMP_26_TRUE:
    LDD #1
.CMP_26_END:
    LBEQ IF_END_33
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD VAR_ARG0
    LDD #40
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2725988333465993402      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD VAR_ARG0
    LDD #25
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_5995724771220415910      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #70
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD VAR_ARG0
    LDD #-5
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_1961155566409942910      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD VAR_ARG0
    LDD #-20
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_1423984413427534561      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #60
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD VAR_ARG0
    LDD #-80
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_9120385760502433312      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_33
IF_END_33:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN1_FIRED
    CMPD TMPVAL
    LBEQ .CMP_27_TRUE
    LDD #0
    LBRA .CMP_27_END
.CMP_27_TRUE:
    LDD #1
.CMP_27_END:
    LBEQ IF_NEXT_36
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INTRO_PAGE
    CMPD TMPVAL
    LBLT .CMP_28_TRUE
    LDD #0
    LBRA .CMP_28_END
.CMP_28_TRUE:
    LDD #1
.CMP_28_END:
    LBEQ IF_NEXT_38
    LDD >VAR_INTRO_PAGE
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_INTRO_PAGE
    LBRA IF_END_37
IF_NEXT_38:
    LDD #0  ; const ROOM_ENTRANCE
    STD VAR_ARG0
    JSR TRAMP_ENTER_ROOM  ; cross-bank trampoline (bank #0 -> bank #1)
    LDD #2  ; const STATE_ROOM
    STD VAR_SCREEN
IF_END_37:
    LBRA IF_END_35
IF_NEXT_36:
IF_END_35:
    RTS

; Function: CHECK_WORKSHOP_HOTSPOTS (Bank #0)
CHECK_WORKSHOP_HOTSPOTS:
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_CLOCK_HS_X_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DX
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_CLOCK_HS_Y_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DY
    LDX #ARRAY_CLOCK_HS_W_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DX
    TSTA           ; Test sign bit
    BPL .ABS_10_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_10_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_124_TRUE
    LDD #0
    LBRA .CMP_124_END
.CMP_124_TRUE:
    LDD #1
.CMP_124_END:
    LBEQ .LOGIC_123_FALSE
    LDX #ARRAY_CLOCK_HS_H_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DY
    TSTA           ; Test sign bit
    BPL .ABS_11_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_11_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_125_TRUE
    LDD #0
    LBRA .CMP_125_END
.CMP_125_TRUE:
    LDD #1
.CMP_125_END:
    LBEQ .LOGIC_123_FALSE
    LDD #1
    LBRA .LOGIC_123_END
.LOGIC_123_FALSE:
    LDD #0
.LOGIC_123_END:
    LBEQ IF_NEXT_130
    LDD #0
    STD VAR_NEAR_HS
    LBRA IF_END_129
IF_NEXT_130:
IF_END_129:
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_CLOCK_HS_X_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DX
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_CLOCK_HS_Y_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DY
    LDX #ARRAY_CLOCK_HS_W_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DX
    TSTA           ; Test sign bit
    BPL .ABS_12_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_12_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_127_TRUE
    LDD #0
    LBRA .CMP_127_END
.CMP_127_TRUE:
    LDD #1
.CMP_127_END:
    LBEQ .LOGIC_126_FALSE
    LDX #ARRAY_CLOCK_HS_H_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DY
    TSTA           ; Test sign bit
    BPL .ABS_13_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_13_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_128_TRUE
    LDD #0
    LBRA .CMP_128_END
.CMP_128_TRUE:
    LDD #1
.CMP_128_END:
    LBEQ .LOGIC_126_FALSE
    LDD #1
    LBRA .LOGIC_126_END
.LOGIC_126_FALSE:
    LDD #0
.LOGIC_126_END:
    LBEQ IF_NEXT_132
    LDD #1
    STD VAR_NEAR_HS
    LBRA IF_END_131
IF_NEXT_132:
IF_END_131:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #1  ; const ITEM_GEAR
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_129_TRUE
    LDD #0
    LBRA .CMP_129_END
.CMP_129_TRUE:
    LDD #1
.CMP_129_END:
    LBEQ IF_NEXT_134
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_CLOCK_HS_X_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DX
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_CLOCK_HS_Y_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DY
    LDX #ARRAY_CLOCK_HS_W_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DX
    TSTA           ; Test sign bit
    BPL .ABS_14_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_14_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_131_TRUE
    LDD #0
    LBRA .CMP_131_END
.CMP_131_TRUE:
    LDD #1
.CMP_131_END:
    LBEQ .LOGIC_130_FALSE
    LDX #ARRAY_CLOCK_HS_H_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DY
    TSTA           ; Test sign bit
    BPL .ABS_15_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_15_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_132_TRUE
    LDD #0
    LBRA .CMP_132_END
.CMP_132_TRUE:
    LDD #1
.CMP_132_END:
    LBEQ .LOGIC_130_FALSE
    LDD #1
    LBRA .LOGIC_130_END
.LOGIC_130_FALSE:
    LDD #0
.LOGIC_130_END:
    LBEQ IF_NEXT_136
    LDD #2
    STD VAR_NEAR_HS
    LBRA IF_END_135
IF_NEXT_136:
IF_END_135:
    LBRA IF_END_133
IF_NEXT_134:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAGS_A
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #16  ; const FL_PANEL_ACTIVE
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    CMPD TMPVAL
    LBEQ .CMP_134_TRUE
    LDD #0
    LBRA .CMP_134_END
.CMP_134_TRUE:
    LDD #1
.CMP_134_END:
    LBEQ .LOGIC_133_FALSE
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #1  ; const ITEM_GEAR
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_135_TRUE
    LDD #0
    LBRA .CMP_135_END
.CMP_135_TRUE:
    LDD #1
.CMP_135_END:
    LBEQ .LOGIC_133_FALSE
    LDD #1
    LBRA .LOGIC_133_END
.LOGIC_133_FALSE:
    LDD #0
.LOGIC_133_END:
    LBEQ IF_END_133
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_CLOCK_HS_X_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DX
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_CLOCK_HS_Y_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DY
    LDX #ARRAY_CLOCK_HS_W_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DX
    TSTA           ; Test sign bit
    BPL .ABS_16_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_16_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_137_TRUE
    LDD #0
    LBRA .CMP_137_END
.CMP_137_TRUE:
    LDD #1
.CMP_137_END:
    LBEQ .LOGIC_136_FALSE
    LDX #ARRAY_CLOCK_HS_H_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DY
    TSTA           ; Test sign bit
    BPL .ABS_17_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_17_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_138_TRUE
    LDD #0
    LBRA .CMP_138_END
.CMP_138_TRUE:
    LDD #1
.CMP_138_END:
    LBEQ .LOGIC_136_FALSE
    LDD #1
    LBRA .LOGIC_136_END
.LOGIC_136_FALSE:
    LDD #0
.LOGIC_136_END:
    LBEQ IF_NEXT_138
    LDD #2
    STD VAR_NEAR_HS
    LBRA IF_END_137
IF_NEXT_138:
IF_END_137:
    LBRA IF_END_133
IF_END_133:
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_CLOCK_HS_X_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DX
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_CLOCK_HS_Y_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DY
    LDX #ARRAY_CLOCK_HS_W_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DX
    TSTA           ; Test sign bit
    BPL .ABS_18_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_18_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_140_TRUE
    LDD #0
    LBRA .CMP_140_END
.CMP_140_TRUE:
    LDD #1
.CMP_140_END:
    LBEQ .LOGIC_139_FALSE
    LDX #ARRAY_CLOCK_HS_H_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DY
    TSTA           ; Test sign bit
    BPL .ABS_19_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_19_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_141_TRUE
    LDD #0
    LBRA .CMP_141_END
.CMP_141_TRUE:
    LDD #1
.CMP_141_END:
    LBEQ .LOGIC_139_FALSE
    LDD #1
    LBRA .LOGIC_139_END
.LOGIC_139_FALSE:
    LDD #0
.LOGIC_139_END:
    LBEQ IF_NEXT_140
    LDD #3
    STD VAR_NEAR_HS
    LBRA IF_END_139
IF_NEXT_140:
IF_END_139:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #5  ; const ITEM_OIL
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_142_TRUE
    LDD #0
    LBRA .CMP_142_END
.CMP_142_TRUE:
    LDD #1
.CMP_142_END:
    LBEQ IF_NEXT_142
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_CLOCK_HS_X_DATA  ; Array base
    LDD #4
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DX
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_CLOCK_HS_Y_DATA  ; Array base
    LDD #4
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DY
    LDX #ARRAY_CLOCK_HS_W_DATA  ; Array base
    LDD #4
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DX
    TSTA           ; Test sign bit
    BPL .ABS_20_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_20_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_144_TRUE
    LDD #0
    LBRA .CMP_144_END
.CMP_144_TRUE:
    LDD #1
.CMP_144_END:
    LBEQ .LOGIC_143_FALSE
    LDX #ARRAY_CLOCK_HS_H_DATA  ; Array base
    LDD #4
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DY
    TSTA           ; Test sign bit
    BPL .ABS_21_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_21_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_145_TRUE
    LDD #0
    LBRA .CMP_145_END
.CMP_145_TRUE:
    LDD #1
.CMP_145_END:
    LBEQ .LOGIC_143_FALSE
    LDD #1
    LBRA .LOGIC_143_END
.LOGIC_143_FALSE:
    LDD #0
.LOGIC_143_END:
    LBEQ IF_NEXT_144
    LDD #4
    STD VAR_NEAR_HS
    LBRA IF_END_143
IF_NEXT_144:
IF_END_143:
    LBRA IF_END_141
IF_NEXT_142:
IF_END_141:
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_CLOCK_HS_X_DATA  ; Array base
    LDD #5
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DX
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_CLOCK_HS_Y_DATA  ; Array base
    LDD #5
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DY
    LDX #ARRAY_CLOCK_HS_W_DATA  ; Array base
    LDD #5
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DX
    TSTA           ; Test sign bit
    BPL .ABS_22_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_22_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_147_TRUE
    LDD #0
    LBRA .CMP_147_END
.CMP_147_TRUE:
    LDD #1
.CMP_147_END:
    LBEQ .LOGIC_146_FALSE
    LDX #ARRAY_CLOCK_HS_H_DATA  ; Array base
    LDD #5
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DY
    TSTA           ; Test sign bit
    BPL .ABS_23_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_23_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_148_TRUE
    LDD #0
    LBRA .CMP_148_END
.CMP_148_TRUE:
    LDD #1
.CMP_148_END:
    LBEQ .LOGIC_146_FALSE
    LDD #1
    LBRA .LOGIC_146_END
.LOGIC_146_FALSE:
    LDD #0
.LOGIC_146_END:
    LBEQ IF_NEXT_146
    LDD #5
    STD VAR_NEAR_HS
    LBRA IF_END_145
IF_NEXT_146:
IF_END_145:
    RTS

; Function: CHECK_WEIGHTS_HOTSPOTS (Bank #0)
CHECK_WEIGHTS_HOTSPOTS:
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_WGT_HS_X_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DX
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_WGT_HS_Y_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DY
    LDX #ARRAY_WGT_HS_W_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DX
    TSTA           ; Test sign bit
    BPL .ABS_32_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_32_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_162_TRUE
    LDD #0
    LBRA .CMP_162_END
.CMP_162_TRUE:
    LDD #1
.CMP_162_END:
    LBEQ .LOGIC_161_FALSE
    LDX #ARRAY_WGT_HS_H_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DY
    TSTA           ; Test sign bit
    BPL .ABS_33_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_33_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_163_TRUE
    LDD #0
    LBRA .CMP_163_END
.CMP_163_TRUE:
    LDD #1
.CMP_163_END:
    LBEQ .LOGIC_161_FALSE
    LDD #1
    LBRA .LOGIC_161_END
.LOGIC_161_FALSE:
    LDD #0
.LOGIC_161_END:
    LBEQ IF_NEXT_156
    LDD #0
    STD VAR_NEAR_HS
    LBRA IF_END_155
IF_NEXT_156:
IF_END_155:
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_WGT_HS_X_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DX
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_WGT_HS_Y_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DY
    LDX #ARRAY_WGT_HS_W_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DX
    TSTA           ; Test sign bit
    BPL .ABS_34_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_34_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_165_TRUE
    LDD #0
    LBRA .CMP_165_END
.CMP_165_TRUE:
    LDD #1
.CMP_165_END:
    LBEQ .LOGIC_164_FALSE
    LDX #ARRAY_WGT_HS_H_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DY
    TSTA           ; Test sign bit
    BPL .ABS_35_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_35_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_166_TRUE
    LDD #0
    LBRA .CMP_166_END
.CMP_166_TRUE:
    LDD #1
.CMP_166_END:
    LBEQ .LOGIC_164_FALSE
    LDD #1
    LBRA .LOGIC_164_END
.LOGIC_164_FALSE:
    LDD #0
.LOGIC_164_END:
    LBEQ IF_NEXT_158
    LDD #1
    STD VAR_NEAR_HS
    LBRA IF_END_157
IF_NEXT_158:
IF_END_157:
    RTS

; Function: CHECK_VAULT_HOTSPOTS (Bank #0)
CHECK_VAULT_HOTSPOTS:
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_VAULT_HS_X_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DX
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_VAULT_HS_Y_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DY
    LDX #ARRAY_VAULT_HS_W_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DX
    TSTA           ; Test sign bit
    BPL .ABS_42_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_42_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_178_TRUE
    LDD #0
    LBRA .CMP_178_END
.CMP_178_TRUE:
    LDD #1
.CMP_178_END:
    LBEQ .LOGIC_177_FALSE
    LDX #ARRAY_VAULT_HS_H_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DY
    TSTA           ; Test sign bit
    BPL .ABS_43_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_43_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_179_TRUE
    LDD #0
    LBRA .CMP_179_END
.CMP_179_TRUE:
    LDD #1
.CMP_179_END:
    LBEQ .LOGIC_177_FALSE
    LDD #1
    LBRA .LOGIC_177_END
.LOGIC_177_FALSE:
    LDD #0
.LOGIC_177_END:
    LBEQ IF_NEXT_168
    LDD #0
    STD VAR_NEAR_HS
    LBRA IF_END_167
IF_NEXT_168:
IF_END_167:
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_VAULT_HS_X_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DX
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_VAULT_HS_Y_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DY
    LDX #ARRAY_VAULT_HS_W_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DX
    TSTA           ; Test sign bit
    BPL .ABS_44_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_44_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_181_TRUE
    LDD #0
    LBRA .CMP_181_END
.CMP_181_TRUE:
    LDD #1
.CMP_181_END:
    LBEQ .LOGIC_180_FALSE
    LDX #ARRAY_VAULT_HS_H_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DY
    TSTA           ; Test sign bit
    BPL .ABS_45_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_45_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_182_TRUE
    LDD #0
    LBRA .CMP_182_END
.CMP_182_TRUE:
    LDD #1
.CMP_182_END:
    LBEQ .LOGIC_180_FALSE
    LDD #1
    LBRA .LOGIC_180_END
.LOGIC_180_FALSE:
    LDD #0
.LOGIC_180_END:
    LBEQ IF_NEXT_170
    LDD #1
    STD VAR_NEAR_HS
    LBRA IF_END_169
IF_NEXT_170:
IF_END_169:
    RTS

; Function: INTERACT_ENTRANCE (Bank #0)
INTERACT_ENTRANCE:
    LDD #0  ; const ENT_HS_PAINTING
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_183_TRUE
    LDD #0
    LBRA .CMP_183_END
.CMP_183_TRUE:
    LDD #1
.CMP_183_END:
    LBEQ IF_NEXT_172
    LDD #0  ; const VERB_EXAMINE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_184_TRUE
    LDD #0
    LBRA .CMP_184_END
.CMP_184_TRUE:
    LDD #1
.CMP_184_END:
    LBEQ IF_NEXT_174
    LDD >VAR_FLAGS_A
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1  ; const FL_DATE_KNOWN
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ORA TMPPTR2     ; A OR TMPPTR2+0 (high byte)
    ORB TMPPTR2+1   ; B OR TMPPTR2+1 (low byte)
    STD VAR_FLAGS_A
    LDD #1
    STD VAR_MSG_ID
    LDD #160
    STD VAR_MSG_TIMER
    LBRA IF_END_173
IF_NEXT_174:
    LDD #1  ; const VERB_TAKE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_185_TRUE
    LDD #0
    LBRA .CMP_185_END
.CMP_185_TRUE:
    LDD #1
.CMP_185_END:
    LBEQ IF_NEXT_175
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_173
IF_NEXT_175:
    LDD #2  ; const VERB_USE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_186_TRUE
    LDD #0
    LBRA .CMP_186_END
.CMP_186_TRUE:
    LDD #1
.CMP_186_END:
    LBEQ IF_NEXT_176
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #4  ; const ITEM_EYE
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_187_TRUE
    LDD #0
    LBRA .CMP_187_END
.CMP_187_TRUE:
    LDD #1
.CMP_187_END:
    LBEQ IF_NEXT_178
    LDD #43
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_177
IF_NEXT_178:
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
IF_END_177:
    LBRA IF_END_173
IF_NEXT_176:
    LDD #3  ; const VERB_GIVE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_188_TRUE
    LDD #0
    LBRA .CMP_188_END
.CMP_188_TRUE:
    LDD #1
.CMP_188_END:
    LBEQ IF_END_173
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_173
IF_END_173:
    LBRA IF_END_171
IF_NEXT_172:
    LDD #1  ; const ENT_HS_DOOR
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_189_TRUE
    LDD #0
    LBRA .CMP_189_END
.CMP_189_TRUE:
    LDD #1
.CMP_189_END:
    LBEQ IF_NEXT_179
    LDD #0  ; const VERB_EXAMINE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_190_TRUE
    LDD #0
    LBRA .CMP_190_END
.CMP_190_TRUE:
    LDD #1
.CMP_190_END:
    LBEQ IF_NEXT_181
    LDD #2
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_180
IF_NEXT_181:
    LDD #2  ; const VERB_USE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_191_TRUE
    LDD #0
    LBRA .CMP_191_END
.CMP_191_TRUE:
    LDD #1
.CMP_191_END:
    LBEQ IF_NEXT_182
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAGS_A
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #2  ; const FL_TALLER_OPEN
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    CMPD TMPVAL
    LBNE .CMP_192_TRUE
    LDD #0
    LBRA .CMP_192_END
.CMP_192_TRUE:
    LDD #1
.CMP_192_END:
    LBEQ IF_NEXT_184
    LDD #2  ; const ROOM_ANTEROOM
    STD VAR_EXIT_ROOM_TARGET
    LDD #1
    STD VAR_ROOM_EXIT
    LDD #60
    STD VAR_MSG_TIMER
    LBRA IF_END_183
IF_NEXT_184:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAGS_A
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1  ; const FL_DATE_KNOWN
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    CMPD TMPVAL
    LBNE .CMP_193_TRUE
    LDD #0
    LBRA .CMP_193_END
.CMP_193_TRUE:
    LDD #1
.CMP_193_END:
    LBEQ IF_NEXT_185
    LDD >VAR_FLAGS_A
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #2  ; const FL_TALLER_OPEN
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ORA TMPPTR2     ; A OR TMPPTR2+0 (high byte)
    ORB TMPPTR2+1   ; B OR TMPPTR2+1 (low byte)
    STD VAR_FLAGS_A
    LDD #2  ; const ROOM_ANTEROOM
    STD VAR_EXIT_ROOM_TARGET
    LDD #4
    STD VAR_MSG_ID
    LDD #200
    STD VAR_MSG_TIMER
    LDD #1
    STD VAR_ROOM_EXIT
    ; PLAY_SFX("door_unlock") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    JSR ACCELERATE_HEARTBEAT
    LBRA IF_END_183
IF_NEXT_185:
    LDD #3
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
    ; PLAY_SFX("puzzle_fail") - play SFX asset (index=3)
    LDX #3        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
IF_END_183:
    LBRA IF_END_180
IF_NEXT_182:
    LDD #1  ; const VERB_TAKE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_194_TRUE
    LDD #0
    LBRA .CMP_194_END
.CMP_194_TRUE:
    LDD #1
.CMP_194_END:
    LBEQ IF_END_180
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_180
IF_END_180:
    LBRA IF_END_171
IF_NEXT_179:
    LDD #2  ; const ENT_HS_CARETAKER
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_195_TRUE
    LDD #0
    LBRA .CMP_195_END
.CMP_195_TRUE:
    LDD #1
.CMP_195_END:
    LBEQ IF_NEXT_186
    LDD #0  ; const VERB_EXAMINE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_196_TRUE
    LDD #0
    LBRA .CMP_196_END
.CMP_196_TRUE:
    LDD #1
.CMP_196_END:
    LBEQ IF_NEXT_188
    LDD #0  ; const NPC_CARETAKER
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_NPC_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #1
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #24
    STD VAR_MSG_ID
    LDD #160
    STD VAR_MSG_TIMER
    LBRA IF_END_187
IF_NEXT_188:
    LDD #2  ; const VERB_USE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_197_TRUE
    LDD #0
    LBRA .CMP_197_END
.CMP_197_TRUE:
    LDD #1
.CMP_197_END:
    LBEQ IF_NEXT_189
    LDD #36
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_187
IF_NEXT_189:
    LDD #3  ; const VERB_GIVE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_198_TRUE
    LDD #0
    LBRA .CMP_198_END
.CMP_198_TRUE:
    LDD #1
.CMP_198_END:
    LBEQ IF_NEXT_190
    LDD #3  ; const ITEM_BLANKET
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ACTIVE_ITEM
    CMPD TMPVAL
    LBEQ .CMP_199_TRUE
    LDD #0
    LBRA .CMP_199_END
.CMP_199_TRUE:
    LDD #1
.CMP_199_END:
    LBEQ IF_NEXT_192
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAGS_B
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #8  ; const FL_CARETAKER_DONE
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    CMPD TMPVAL
    LBEQ .CMP_200_TRUE
    LDD #0
    LBRA .CMP_200_END
.CMP_200_TRUE:
    LDD #1
.CMP_200_END:
    LBEQ IF_NEXT_194
    LDD >VAR_FLAGS_B
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #8  ; const FL_CARETAKER_DONE
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ORA TMPPTR2     ; A OR TMPPTR2+0 (high byte)
    ORB TMPPTR2+1   ; B OR TMPPTR2+1 (low byte)
    STD VAR_FLAGS_B
    LDD >VAR_FLAGS_A
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #128  ; const FL_OPTICS_OPEN
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ORA TMPPTR2     ; A OR TMPPTR2+0 (high byte)
    ORB TMPPTR2+1   ; B OR TMPPTR2+1 (low byte)
    STD VAR_FLAGS_A
    LDD #3  ; const ITEM_BLANKET
    STD VAR_ARG0
    JSR DROP_ITEM
    LDD #-1
    STD VAR_ACTIVE_ITEM
    LDD #0  ; const NPC_CARETAKER
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_NPC_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #2
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #26
    STD VAR_MSG_ID
    LDD #200
    STD VAR_MSG_TIMER
    JSR ACCELERATE_HEARTBEAT
    LBRA IF_END_193
IF_NEXT_194:
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
IF_END_193:
    LBRA IF_END_191
IF_NEXT_192:
    LDD #36
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
IF_END_191:
    LBRA IF_END_187
IF_NEXT_190:
    LDD #1  ; const VERB_TAKE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_201_TRUE
    LDD #0
    LBRA .CMP_201_END
.CMP_201_TRUE:
    LDD #1
.CMP_201_END:
    LBEQ IF_END_187
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_187
IF_END_187:
    LBRA IF_END_171
IF_NEXT_186:
    LDD #3  ; const ENT_HS_CONS_DOOR
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_202_TRUE
    LDD #0
    LBRA .CMP_202_END
.CMP_202_TRUE:
    LDD #1
.CMP_202_END:
    LBEQ IF_END_171
    LDD #0  ; const VERB_EXAMINE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_203_TRUE
    LDD #0
    LBRA .CMP_203_END
.CMP_203_TRUE:
    LDD #1
.CMP_203_END:
    LBEQ IF_NEXT_196
    LDD #43
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_195
IF_NEXT_196:
    LDD #2  ; const VERB_USE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_204_TRUE
    LDD #0
    LBRA .CMP_204_END
.CMP_204_TRUE:
    LDD #1
.CMP_204_END:
    LBEQ IF_NEXT_197
    LDD #5  ; const ROOM_CONSERVATORY
    STD VAR_EXIT_ROOM_TARGET
    LDD #1
    STD VAR_ROOM_EXIT
    LDD #60
    STD VAR_MSG_TIMER
    LBRA IF_END_195
IF_NEXT_197:
    LDD #1  ; const VERB_TAKE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_205_TRUE
    LDD #0
    LBRA .CMP_205_END
.CMP_205_TRUE:
    LDD #1
.CMP_205_END:
    LBEQ IF_END_195
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_195
IF_END_195:
    LBRA IF_END_171
IF_END_171:
    RTS

; Function: INTERACT_WORKSHOP (Bank #0)
INTERACT_WORKSHOP:
    LDD #0  ; const CLOCK_HS_SARC
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_206_TRUE
    LDD #0
    LBRA .CMP_206_END
.CMP_206_TRUE:
    LDD #1
.CMP_206_END:
    LBEQ IF_NEXT_199
    LDD #0  ; const VERB_EXAMINE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_207_TRUE
    LDD #0
    LBRA .CMP_207_END
.CMP_207_TRUE:
    LDD #1
.CMP_207_END:
    LBEQ IF_NEXT_201
    LDD #6
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_200
IF_NEXT_201:
    LDD #2  ; const VERB_USE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_208_TRUE
    LDD #0
    LBRA .CMP_208_END
.CMP_208_TRUE:
    LDD #1
.CMP_208_END:
    LBEQ IF_NEXT_202
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAGS_A
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #4  ; const FL_SARC_OPEN
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    CMPD TMPVAL
    LBNE .CMP_209_TRUE
    LDD #0
    LBRA .CMP_209_END
.CMP_209_TRUE:
    LDD #1
.CMP_209_END:
    LBEQ IF_NEXT_204
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_203
IF_NEXT_204:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAGS_A
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #8  ; const FL_CLOCK_READ
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    CMPD TMPVAL
    LBNE .CMP_210_TRUE
    LDD #0
    LBRA .CMP_210_END
.CMP_210_TRUE:
    LDD #1
.CMP_210_END:
    LBEQ IF_NEXT_205
    LDD >VAR_FLAGS_A
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #4  ; const FL_SARC_OPEN
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ORA TMPPTR2     ; A OR TMPPTR2+0 (high byte)
    ORB TMPPTR2+1   ; B OR TMPPTR2+1 (low byte)
    STD VAR_FLAGS_A
    LDD #3  ; const ITEM_BLANKET
    STD VAR_ARG0
    JSR TRAMP_PICKUP_ITEM  ; cross-bank trampoline (bank #0 -> bank #1)
    LDD #7  ; const ITEM_KEY
    STD VAR_ARG0
    JSR TRAMP_PICKUP_ITEM  ; cross-bank trampoline (bank #0 -> bank #1)
    LDD #7
    STD VAR_MSG_ID
    LDD #200
    STD VAR_MSG_TIMER
    ; PLAY_SFX("puzzle_success") - play SFX asset (index=4)
    LDX #4        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    JSR ACCELERATE_HEARTBEAT
    LBRA IF_END_203
IF_NEXT_205:
    LDD #23
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
IF_END_203:
    LBRA IF_END_200
IF_NEXT_202:
    LDD #1  ; const VERB_TAKE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_211_TRUE
    LDD #0
    LBRA .CMP_211_END
.CMP_211_TRUE:
    LDD #1
.CMP_211_END:
    LBEQ IF_END_200
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_200
IF_END_200:
    LBRA IF_END_198
IF_NEXT_199:
    LDD #1  ; const CLOCK_HS_CLOCK
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_212_TRUE
    LDD #0
    LBRA .CMP_212_END
.CMP_212_TRUE:
    LDD #1
.CMP_212_END:
    LBEQ IF_NEXT_206
    LDD #0  ; const VERB_EXAMINE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_213_TRUE
    LDD #0
    LBRA .CMP_213_END
.CMP_213_TRUE:
    LDD #1
.CMP_213_END:
    LBEQ IF_NEXT_208
    LDD #8
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_207
IF_NEXT_208:
    LDD #2  ; const VERB_USE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_214_TRUE
    LDD #0
    LBRA .CMP_214_END
.CMP_214_TRUE:
    LDD #1
.CMP_214_END:
    LBEQ IF_NEXT_209
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #0  ; const ITEM_LENS
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_215_TRUE
    LDD #0
    LBRA .CMP_215_END
.CMP_215_TRUE:
    LDD #1
.CMP_215_END:
    LBEQ IF_NEXT_211
    LDD >VAR_FLAGS_A
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #8  ; const FL_CLOCK_READ
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ORA TMPPTR2     ; A OR TMPPTR2+0 (high byte)
    ORB TMPPTR2+1   ; B OR TMPPTR2+1 (low byte)
    STD VAR_FLAGS_A
    LDD #8
    STD VAR_MSG_ID
    LDD #160
    STD VAR_MSG_TIMER
    LBRA IF_END_210
IF_NEXT_211:
    LDD #22
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
IF_END_210:
    LBRA IF_END_207
IF_NEXT_209:
    LDD #1  ; const VERB_TAKE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_216_TRUE
    LDD #0
    LBRA .CMP_216_END
.CMP_216_TRUE:
    LDD #1
.CMP_216_END:
    LBEQ IF_END_207
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_207
IF_END_207:
    LBRA IF_END_198
IF_NEXT_206:
    LDD #2  ; const CLOCK_HS_GEAR
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_217_TRUE
    LDD #0
    LBRA .CMP_217_END
.CMP_217_TRUE:
    LDD #1
.CMP_217_END:
    LBEQ IF_NEXT_212
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #1  ; const ITEM_GEAR
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_218_TRUE
    LDD #0
    LBRA .CMP_218_END
.CMP_218_TRUE:
    LDD #1
.CMP_218_END:
    LBEQ IF_NEXT_214
    LDD #1  ; const ITEM_GEAR
    STD VAR_ARG0
    JSR TRAMP_PICKUP_ITEM  ; cross-bank trampoline (bank #0 -> bank #1)
    LDD #25
    STD VAR_MSG_ID
    LDD #140
    STD VAR_MSG_TIMER
    LBRA IF_END_213
IF_NEXT_214:
    LDD #2  ; const VERB_USE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_219_TRUE
    LDD #0
    LBRA .CMP_219_END
.CMP_219_TRUE:
    LDD #1
.CMP_219_END:
    LBEQ IF_NEXT_215
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #1  ; const ITEM_GEAR
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_220_TRUE
    LDD #0
    LBRA .CMP_220_END
.CMP_220_TRUE:
    LDD #1
.CMP_220_END:
    LBEQ IF_NEXT_217
    LDD >VAR_FLAGS_A
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #16  ; const FL_PANEL_ACTIVE
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ORA TMPPTR2     ; A OR TMPPTR2+0 (high byte)
    ORB TMPPTR2+1   ; B OR TMPPTR2+1 (low byte)
    STD VAR_FLAGS_A
    LDD #1  ; const ITEM_GEAR
    STD VAR_ARG0
    JSR DROP_ITEM
    LDD #44
    STD VAR_MSG_ID
    LDD #160
    STD VAR_MSG_TIMER
    ; PLAY_SFX("puzzle_success") - play SFX asset (index=4)
    LDX #4        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    JSR ACCELERATE_HEARTBEAT
    LBRA IF_END_216
IF_NEXT_217:
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
IF_END_216:
    LBRA IF_END_213
IF_NEXT_215:
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
IF_END_213:
    LBRA IF_END_198
IF_NEXT_212:
    LDD #3  ; const CLOCK_HS_HANS
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_221_TRUE
    LDD #0
    LBRA .CMP_221_END
.CMP_221_TRUE:
    LDD #1
.CMP_221_END:
    LBEQ IF_NEXT_218
    LDD #0  ; const VERB_EXAMINE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_222_TRUE
    LDD #0
    LBRA .CMP_222_END
.CMP_222_TRUE:
    LDD #1
.CMP_222_END:
    LBEQ IF_NEXT_220
    LDD #1  ; const NPC_HANS
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_NPC_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #1
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #27
    STD VAR_MSG_ID
    LDD #160
    STD VAR_MSG_TIMER
    LBRA IF_END_219
IF_NEXT_220:
    LDD #2  ; const VERB_USE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_223_TRUE
    LDD #0
    LBRA .CMP_223_END
.CMP_223_TRUE:
    LDD #1
.CMP_223_END:
    LBEQ IF_NEXT_221
    LDD #37
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_219
IF_NEXT_221:
    LDD #3  ; const VERB_GIVE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_224_TRUE
    LDD #0
    LBRA .CMP_224_END
.CMP_224_TRUE:
    LDD #1
.CMP_224_END:
    LBEQ IF_NEXT_222
    LDD #5  ; const ITEM_OIL
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ACTIVE_ITEM
    CMPD TMPVAL
    LBEQ .CMP_225_TRUE
    LDD #0
    LBRA .CMP_225_END
.CMP_225_TRUE:
    LDD #1
.CMP_225_END:
    LBEQ IF_NEXT_224
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAGS_B
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #4  ; const FL_HANS_HELPED
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    CMPD TMPVAL
    LBEQ .CMP_226_TRUE
    LDD #0
    LBRA .CMP_226_END
.CMP_226_TRUE:
    LDD #1
.CMP_226_END:
    LBEQ IF_NEXT_226
    LDD >VAR_FLAGS_B
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #4  ; const FL_HANS_HELPED
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ORA TMPPTR2     ; A OR TMPPTR2+0 (high byte)
    ORB TMPPTR2+1   ; B OR TMPPTR2+1 (low byte)
    STD VAR_FLAGS_B
    LDD #5  ; const ITEM_OIL
    STD VAR_ARG0
    JSR DROP_ITEM
    LDD #-1
    STD VAR_ACTIVE_ITEM
    LDD #1  ; const NPC_HANS
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_NPC_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #2
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #28
    STD VAR_MSG_ID
    LDD #200
    STD VAR_MSG_TIMER
    JSR ACCELERATE_HEARTBEAT
    LBRA IF_END_225
IF_NEXT_226:
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
IF_END_225:
    LBRA IF_END_223
IF_NEXT_224:
    LDD #37
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
IF_END_223:
    LBRA IF_END_219
IF_NEXT_222:
    LDD #1  ; const VERB_TAKE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_227_TRUE
    LDD #0
    LBRA .CMP_227_END
.CMP_227_TRUE:
    LDD #1
.CMP_227_END:
    LBEQ IF_END_219
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_219
IF_END_219:
    LBRA IF_END_198
IF_NEXT_218:
    LDD #4  ; const CLOCK_HS_OIL
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_228_TRUE
    LDD #0
    LBRA .CMP_228_END
.CMP_228_TRUE:
    LDD #1
.CMP_228_END:
    LBEQ IF_NEXT_227
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #5  ; const ITEM_OIL
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_229_TRUE
    LDD #0
    LBRA .CMP_229_END
.CMP_229_TRUE:
    LDD #1
.CMP_229_END:
    LBEQ IF_NEXT_229
    LDD #5  ; const ITEM_OIL
    STD VAR_ARG0
    JSR TRAMP_PICKUP_ITEM  ; cross-bank trampoline (bank #0 -> bank #1)
    LDD #34
    STD VAR_MSG_ID
    LDD #140
    STD VAR_MSG_TIMER
    LBRA IF_END_228
IF_NEXT_229:
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
IF_END_228:
    LBRA IF_END_198
IF_NEXT_227:
    LDD #5  ; const CLOCK_HS_OPTICS
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_230_TRUE
    LDD #0
    LBRA .CMP_230_END
.CMP_230_TRUE:
    LDD #1
.CMP_230_END:
    LBEQ IF_END_198
    LDD #0  ; const VERB_EXAMINE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_231_TRUE
    LDD #0
    LBRA .CMP_231_END
.CMP_231_TRUE:
    LDD #1
.CMP_231_END:
    LBEQ IF_NEXT_231
    LDD #40
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_230
IF_NEXT_231:
    LDD #2  ; const VERB_USE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_232_TRUE
    LDD #0
    LBRA .CMP_232_END
.CMP_232_TRUE:
    LDD #1
.CMP_232_END:
    LBEQ IF_NEXT_232
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAGS_A
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #128  ; const FL_OPTICS_OPEN
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    CMPD TMPVAL
    LBNE .CMP_233_TRUE
    LDD #0
    LBRA .CMP_233_END
.CMP_233_TRUE:
    LDD #1
.CMP_233_END:
    LBEQ IF_NEXT_234
    LDD #4  ; const ROOM_OPTICS
    STD VAR_EXIT_ROOM_TARGET
    LDD #1
    STD VAR_ROOM_EXIT
    LDD #60
    STD VAR_MSG_TIMER
    LBRA IF_END_233
IF_NEXT_234:
    LDD #40
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
IF_END_233:
    LBRA IF_END_230
IF_NEXT_232:
    LDD #1  ; const VERB_TAKE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_234_TRUE
    LDD #0
    LBRA .CMP_234_END
.CMP_234_TRUE:
    LDD #1
.CMP_234_END:
    LBEQ IF_END_230
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_230
IF_END_230:
    LBRA IF_END_198
IF_END_198:
    RTS

; Function: INTERACT_ANTEROOM (Bank #0)
INTERACT_ANTEROOM:
    LDD #0  ; const ANT_HS_DIARY
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_235_TRUE
    LDD #0
    LBRA .CMP_235_END
.CMP_235_TRUE:
    LDD #1
.CMP_235_END:
    LBEQ IF_NEXT_236
    LDD #0  ; const VERB_EXAMINE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_236_TRUE
    LDD #0
    LBRA .CMP_236_END
.CMP_236_TRUE:
    LDD #1
.CMP_236_END:
    LBEQ IF_NEXT_238
    LDD #9
    STD VAR_MSG_ID
    LDD #140
    STD VAR_MSG_TIMER
    LBRA IF_END_237
IF_NEXT_238:
    LDD #1  ; const VERB_TAKE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_237_TRUE
    LDD #0
    LBRA .CMP_237_END
.CMP_237_TRUE:
    LDD #1
.CMP_237_END:
    LBEQ IF_NEXT_239
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_237
IF_NEXT_239:
    LDD #2  ; const VERB_USE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_238_TRUE
    LDD #0
    LBRA .CMP_238_END
.CMP_238_TRUE:
    LDD #1
.CMP_238_END:
    LBEQ IF_END_237
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #0  ; const ITEM_LENS
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_239_TRUE
    LDD #0
    LBRA .CMP_239_END
.CMP_239_TRUE:
    LDD #1
.CMP_239_END:
    LBEQ IF_NEXT_241
    LDD #0  ; const ITEM_LENS
    STD VAR_ARG0
    JSR TRAMP_PICKUP_ITEM  ; cross-bank trampoline (bank #0 -> bank #1)
    LDD #10
    STD VAR_MSG_ID
    LDD #160
    STD VAR_MSG_TIMER
    LBRA IF_END_240
IF_NEXT_241:
    LDD #11
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
IF_END_240:
    LBRA IF_END_237
IF_END_237:
    LBRA IF_END_235
IF_NEXT_236:
    LDD #1  ; const ANT_HS_EXIT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_240_TRUE
    LDD #0
    LBRA .CMP_240_END
.CMP_240_TRUE:
    LDD #1
.CMP_240_END:
    LBEQ IF_NEXT_242
    LDD #0  ; const VERB_EXAMINE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_241_TRUE
    LDD #0
    LBRA .CMP_241_END
.CMP_241_TRUE:
    LDD #1
.CMP_241_END:
    LBEQ IF_NEXT_244
    LDD #12
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_243
IF_NEXT_244:
    LDD #2  ; const VERB_USE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_242_TRUE
    LDD #0
    LBRA .CMP_242_END
.CMP_242_TRUE:
    LDD #1
.CMP_242_END:
    LBEQ IF_NEXT_245
    LDD #3  ; const ROOM_WEIGHTS
    STD VAR_EXIT_ROOM_TARGET
    LDD #1
    STD VAR_ROOM_EXIT
    LDD #60
    STD VAR_MSG_TIMER
    LBRA IF_END_243
IF_NEXT_245:
    LDD #1  ; const VERB_TAKE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_243_TRUE
    LDD #0
    LBRA .CMP_243_END
.CMP_243_TRUE:
    LDD #1
.CMP_243_END:
    LBEQ IF_END_243
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_243
IF_END_243:
    LBRA IF_END_235
IF_NEXT_242:
    LDD #2  ; const ANT_HS_SHELF
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_244_TRUE
    LDD #0
    LBRA .CMP_244_END
.CMP_244_TRUE:
    LDD #1
.CMP_244_END:
    LBEQ IF_NEXT_246
    LDD #0  ; const VERB_EXAMINE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_245_TRUE
    LDD #0
    LBRA .CMP_245_END
.CMP_245_TRUE:
    LDD #1
.CMP_245_END:
    LBEQ IF_NEXT_248
    LDD #33
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_247
IF_NEXT_248:
    LDD #1  ; const VERB_TAKE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_246_TRUE
    LDD #0
    LBRA .CMP_246_END
.CMP_246_TRUE:
    LDD #1
.CMP_246_END:
    LBEQ IF_NEXT_249
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #6  ; const ITEM_SHEET
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_247_TRUE
    LDD #0
    LBRA .CMP_247_END
.CMP_247_TRUE:
    LDD #1
.CMP_247_END:
    LBEQ IF_NEXT_251
    LDD #6  ; const ITEM_SHEET
    STD VAR_ARG0
    JSR TRAMP_PICKUP_ITEM  ; cross-bank trampoline (bank #0 -> bank #1)
    LDD #33
    STD VAR_MSG_ID
    LDD #140
    STD VAR_MSG_TIMER
    LBRA IF_END_250
IF_NEXT_251:
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
IF_END_250:
    LBRA IF_END_247
IF_NEXT_249:
    LDD #2  ; const VERB_USE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_248_TRUE
    LDD #0
    LBRA .CMP_248_END
.CMP_248_TRUE:
    LDD #1
.CMP_248_END:
    LBEQ IF_END_247
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_247
IF_END_247:
    LBRA IF_END_235
IF_NEXT_246:
    LDD #3  ; const ANT_HS_CABINET
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_249_TRUE
    LDD #0
    LBRA .CMP_249_END
.CMP_249_TRUE:
    LDD #1
.CMP_249_END:
    LBEQ IF_END_235
    LDD #0  ; const VERB_EXAMINE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_250_TRUE
    LDD #0
    LBRA .CMP_250_END
.CMP_250_TRUE:
    LDD #1
.CMP_250_END:
    LBEQ IF_NEXT_253
    LDD #35
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_252
IF_NEXT_253:
    LDD #2  ; const VERB_USE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_251_TRUE
    LDD #0
    LBRA .CMP_251_END
.CMP_251_TRUE:
    LDD #1
.CMP_251_END:
    LBEQ IF_NEXT_254
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #2  ; const ITEM_PRISM
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_253_TRUE
    LDD #0
    LBRA .CMP_253_END
.CMP_253_TRUE:
    LDD #1
.CMP_253_END:
    LBEQ .LOGIC_252_FALSE
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #0  ; const ITEM_LENS
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_254_TRUE
    LDD #0
    LBRA .CMP_254_END
.CMP_254_TRUE:
    LDD #1
.CMP_254_END:
    LBEQ .LOGIC_252_FALSE
    LDD #1
    LBRA .LOGIC_252_END
.LOGIC_252_FALSE:
    LDD #0
.LOGIC_252_END:
    LBEQ IF_NEXT_256
    LDD #2  ; const ITEM_PRISM
    STD VAR_ARG0
    JSR TRAMP_PICKUP_ITEM  ; cross-bank trampoline (bank #0 -> bank #1)
    LDD #35
    STD VAR_MSG_ID
    LDD #160
    STD VAR_MSG_TIMER
    LBRA IF_END_255
IF_NEXT_256:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #2  ; const ITEM_PRISM
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_255_TRUE
    LDD #0
    LBRA .CMP_255_END
.CMP_255_TRUE:
    LDD #1
.CMP_255_END:
    LBEQ IF_NEXT_257
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_255
IF_NEXT_257:
    LDD #22
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
IF_END_255:
    LBRA IF_END_252
IF_NEXT_254:
    LDD #1  ; const VERB_TAKE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_256_TRUE
    LDD #0
    LBRA .CMP_256_END
.CMP_256_TRUE:
    LDD #1
.CMP_256_END:
    LBEQ IF_END_252
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_252
IF_END_252:
    LBRA IF_END_235
IF_END_235:
    RTS

; Function: INTERACT_WEIGHTS (Bank #0)
INTERACT_WEIGHTS:
    LDD #0  ; const WGT_HS_PEDESTAL
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_257_TRUE
    LDD #0
    LBRA .CMP_257_END
.CMP_257_TRUE:
    LDD #1
.CMP_257_END:
    LBEQ IF_NEXT_259
    LDD #0  ; const VERB_EXAMINE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_258_TRUE
    LDD #0
    LBRA .CMP_258_END
.CMP_258_TRUE:
    LDD #1
.CMP_258_END:
    LBEQ IF_NEXT_261
    LDD #13
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_260
IF_NEXT_261:
    LDD #2  ; const VERB_USE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_259_TRUE
    LDD #0
    LBRA .CMP_259_END
.CMP_259_TRUE:
    LDD #1
.CMP_259_END:
    LBEQ IF_NEXT_262
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INV_WEIGHT
    CMPD TMPVAL
    LBGT .CMP_260_TRUE
    LDD #0
    LBRA .CMP_260_END
.CMP_260_TRUE:
    LDD #1
.CMP_260_END:
    LBEQ IF_NEXT_264
    LDD >VAR_FLAGS_A
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #32  ; const FL_ITEMS_DEPOSITED
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ORA TMPPTR2     ; A OR TMPPTR2+0 (high byte)
    ORB TMPPTR2+1   ; B OR TMPPTR2+1 (low byte)
    STD VAR_FLAGS_A
    LDD #0
    STD VAR_INV_WEIGHT
    LDD #14
    STD VAR_MSG_ID
    LDD #140
    STD VAR_MSG_TIMER
    LBRA IF_END_263
IF_NEXT_264:
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
IF_END_263:
    LBRA IF_END_260
IF_NEXT_262:
    LDD #1  ; const VERB_TAKE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_261_TRUE
    LDD #0
    LBRA .CMP_261_END
.CMP_261_TRUE:
    LDD #1
.CMP_261_END:
    LBEQ IF_END_260
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_260
IF_END_260:
    LBRA IF_END_258
IF_NEXT_259:
    LDD #1  ; const WGT_HS_EXIT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_262_TRUE
    LDD #0
    LBRA .CMP_262_END
.CMP_262_TRUE:
    LDD #1
.CMP_262_END:
    LBEQ IF_END_258
    LDD #0  ; const VERB_EXAMINE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_263_TRUE
    LDD #0
    LBRA .CMP_263_END
.CMP_263_TRUE:
    LDD #1
.CMP_263_END:
    LBEQ IF_NEXT_266
    LDD #15
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_265
IF_NEXT_266:
    LDD #2  ; const VERB_USE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_264_TRUE
    LDD #0
    LBRA .CMP_264_END
.CMP_264_TRUE:
    LDD #1
.CMP_264_END:
    LBEQ IF_NEXT_267
    LDD #3
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INV_WEIGHT
    CMPD TMPVAL
    LBGT .CMP_265_TRUE
    LDD #0
    LBRA .CMP_265_END
.CMP_265_TRUE:
    LDD #1
.CMP_265_END:
    LBEQ IF_NEXT_269
    LDD #16
    STD VAR_MSG_ID
    LDD #140
    STD VAR_MSG_TIMER
    ; PLAY_SFX("puzzle_fail") - play SFX asset (index=3)
    LDX #3        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_268
IF_NEXT_269:
    LDD #1  ; const ROOM_WORKSHOP
    STD VAR_EXIT_ROOM_TARGET
    LDD #1
    STD VAR_ROOM_EXIT
    LDD #60
    STD VAR_MSG_TIMER
IF_END_268:
    LBRA IF_END_265
IF_NEXT_267:
    LDD #1  ; const VERB_TAKE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_266_TRUE
    LDD #0
    LBRA .CMP_266_END
.CMP_266_TRUE:
    LDD #1
.CMP_266_END:
    LBEQ IF_END_265
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_265
IF_END_265:
    LBRA IF_END_258
IF_END_258:
    RTS

; Function: INTERACT_CONSERVATORY (Bank #0)
INTERACT_CONSERVATORY:
    LDD #0  ; const CONS_HS_ELISA
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_278_TRUE
    LDD #0
    LBRA .CMP_278_END
.CMP_278_TRUE:
    LDD #1
.CMP_278_END:
    LBEQ IF_NEXT_284
    LDD #0  ; const VERB_EXAMINE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_279_TRUE
    LDD #0
    LBRA .CMP_279_END
.CMP_279_TRUE:
    LDD #1
.CMP_279_END:
    LBEQ IF_NEXT_286
    LDD #2  ; const NPC_ELISA
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_NPC_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #1
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #29
    STD VAR_MSG_ID
    LDD #160
    STD VAR_MSG_TIMER
    LBRA IF_END_285
IF_NEXT_286:
    LDD #2  ; const VERB_USE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_280_TRUE
    LDD #0
    LBRA .CMP_280_END
.CMP_280_TRUE:
    LDD #1
.CMP_280_END:
    LBEQ IF_NEXT_287
    LDD #38
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_285
IF_NEXT_287:
    LDD #3  ; const VERB_GIVE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_281_TRUE
    LDD #0
    LBRA .CMP_281_END
.CMP_281_TRUE:
    LDD #1
.CMP_281_END:
    LBEQ IF_NEXT_288
    LDD #6  ; const ITEM_SHEET
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ACTIVE_ITEM
    CMPD TMPVAL
    LBEQ .CMP_282_TRUE
    LDD #0
    LBRA .CMP_282_END
.CMP_282_TRUE:
    LDD #1
.CMP_282_END:
    LBEQ IF_NEXT_290
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAGS_B
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #2  ; const FL_ELISA_HELPED
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    CMPD TMPVAL
    LBEQ .CMP_283_TRUE
    LDD #0
    LBRA .CMP_283_END
.CMP_283_TRUE:
    LDD #1
.CMP_283_END:
    LBEQ IF_NEXT_292
    LDD >VAR_FLAGS_B
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #2  ; const FL_ELISA_HELPED
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ORA TMPPTR2     ; A OR TMPPTR2+0 (high byte)
    ORB TMPPTR2+1   ; B OR TMPPTR2+1 (low byte)
    STD VAR_FLAGS_B
    LDD #6  ; const ITEM_SHEET
    STD VAR_ARG0
    JSR DROP_ITEM
    LDD #-1
    STD VAR_ACTIVE_ITEM
    LDD #2  ; const NPC_ELISA
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_NPC_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #2
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #30
    STD VAR_MSG_ID
    LDD #200
    STD VAR_MSG_TIMER
    ; PLAY_SFX("puzzle_success") - play SFX asset (index=4)
    LDX #4        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    JSR ACCELERATE_HEARTBEAT
    LBRA IF_END_291
IF_NEXT_292:
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
IF_END_291:
    LBRA IF_END_289
IF_NEXT_290:
    LDD #38
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
IF_END_289:
    LBRA IF_END_285
IF_NEXT_288:
    LDD #1  ; const VERB_TAKE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_284_TRUE
    LDD #0
    LBRA .CMP_284_END
.CMP_284_TRUE:
    LDD #1
.CMP_284_END:
    LBEQ IF_END_285
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_285
IF_END_285:
    LBRA IF_END_283
IF_NEXT_284:
IF_END_283:
    RTS

; Function: INTERACT_VAULT (Bank #0)
INTERACT_VAULT:
    LDD #0  ; const VAULT_HS_APPR
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_285_TRUE
    LDD #0
    LBRA .CMP_285_END
.CMP_285_TRUE:
    LDD #1
.CMP_285_END:
    LBEQ IF_NEXT_294
    LDD #0  ; const VERB_EXAMINE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_286_TRUE
    LDD #0
    LBRA .CMP_286_END
.CMP_286_TRUE:
    LDD #1
.CMP_286_END:
    LBEQ IF_NEXT_296
    LDD #3  ; const NPC_APPRENTICE
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_NPC_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #1
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #31
    STD VAR_MSG_ID
    LDD #200
    STD VAR_MSG_TIMER
    LBRA IF_END_295
IF_NEXT_296:
    LDD #2  ; const VERB_USE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_287_TRUE
    LDD #0
    LBRA .CMP_287_END
.CMP_287_TRUE:
    LDD #1
.CMP_287_END:
    LBEQ IF_NEXT_297
    LDD #39
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_295
IF_NEXT_297:
    LDD #3  ; const VERB_GIVE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_288_TRUE
    LDD #0
    LBRA .CMP_288_END
.CMP_288_TRUE:
    LDD #1
.CMP_288_END:
    LBEQ IF_NEXT_298
    LDD #1  ; const ITEM_GEAR
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ACTIVE_ITEM
    CMPD TMPVAL
    LBEQ .CMP_289_TRUE
    LDD #0
    LBRA .CMP_289_END
.CMP_289_TRUE:
    LDD #1
.CMP_289_END:
    LBEQ IF_NEXT_300
    LDD #3  ; const NPC_APPRENTICE
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_NPC_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #2
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD #-1
    STD VAR_ACTIVE_ITEM
    LDD #32
    STD VAR_MSG_ID
    LDD #200
    STD VAR_MSG_TIMER
    LBRA IF_END_299
IF_NEXT_300:
    LDD #39
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
IF_END_299:
    LBRA IF_END_295
IF_NEXT_298:
    LDD #1  ; const VERB_TAKE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_290_TRUE
    LDD #0
    LBRA .CMP_290_END
.CMP_290_TRUE:
    LDD #1
.CMP_290_END:
    LBEQ IF_END_295
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_295
IF_END_295:
    LBRA IF_END_293
IF_NEXT_294:
    LDD #1  ; const VAULT_HS_DOOR
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_291_TRUE
    LDD #0
    LBRA .CMP_291_END
.CMP_291_TRUE:
    LDD #1
.CMP_291_END:
    LBEQ IF_END_293
    LDD #0  ; const VERB_EXAMINE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_292_TRUE
    LDD #0
    LBRA .CMP_292_END
.CMP_292_TRUE:
    LDD #1
.CMP_292_END:
    LBEQ IF_NEXT_302
    LDD #42
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_301
IF_NEXT_302:
    LDD #2  ; const VERB_USE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_293_TRUE
    LDD #0
    LBRA .CMP_293_END
.CMP_293_TRUE:
    LDD #1
.CMP_293_END:
    LBEQ IF_NEXT_303
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #7  ; const ITEM_KEY
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_294_TRUE
    LDD #0
    LBRA .CMP_294_END
.CMP_294_TRUE:
    LDD #1
.CMP_294_END:
    LBEQ IF_NEXT_305
    LDD #7  ; const ITEM_KEY
    STD VAR_ARG0
    JSR DROP_ITEM
    LDD #-1
    STD VAR_ACTIVE_ITEM
    LDD #1
    STD VAR_ROOM_EXIT
    LDD >VAR_FLAGS_B
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #16  ; const FL_EXIT_TESTAMENT
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ORA TMPPTR2     ; A OR TMPPTR2+0 (high byte)
    ORB TMPPTR2+1   ; B OR TMPPTR2+1 (low byte)
    STD VAR_FLAGS_B
    LDD #80
    STD VAR_MSG_TIMER
    LBRA IF_END_304
IF_NEXT_305:
    LDD #42
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
IF_END_304:
    LBRA IF_END_301
IF_NEXT_303:
    LDD #1  ; const VERB_TAKE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_295_TRUE
    LDD #0
    LBRA .CMP_295_END
.CMP_295_TRUE:
    LDD #1
.CMP_295_END:
    LBEQ IF_END_301
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_301
IF_END_301:
    LBRA IF_END_293
IF_END_293:
    RTS

; Function: DRAW_ROOM (Bank #0)
DRAW_ROOM:
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; ===== UPDATE_LEVEL builtin =====
    JSR UPDATE_LEVEL_RUNTIME
    LDD #0
    STD RESULT
    ; ===== SHOW_LEVEL builtin =====
    JSR SHOW_LEVEL_RUNTIME
    LDD #0
    STD RESULT
    LDD #0  ; const ROOM_ENTRANCE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_ROOM
    CMPD TMPVAL
    LBEQ .CMP_296_TRUE
    LDD #0
    LBRA .CMP_296_END
.CMP_296_TRUE:
    LDD #1
.CMP_296_END:
    LBEQ IF_NEXT_307
    LDX #ARRAY_ENT_HS_X_DATA  ; Array base
    LDD #2  ; const ENT_HS_CARETAKER
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_SCROLL_X
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_CARETAKER_SX
    LDD #-120
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CARETAKER_SX
    CMPD TMPVAL
    LBGT .CMP_298_TRUE
    LDD #0
    LBRA .CMP_298_END
.CMP_298_TRUE:
    LDD #1
.CMP_298_END:
    LBEQ .LOGIC_297_FALSE
    LDD #120
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CARETAKER_SX
    CMPD TMPVAL
    LBLT .CMP_299_TRUE
    LDD #0
    LBRA .CMP_299_END
.CMP_299_TRUE:
    LDD #1
.CMP_299_END:
    LBEQ .LOGIC_297_FALSE
    LDD #1
    LBRA .LOGIC_297_END
.LOGIC_297_FALSE:
    LDD #0
.LOGIC_297_END:
    LBEQ IF_NEXT_309
    LDD #2
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_NPC_STATE_DATA  ; Array base
    LDD #0  ; const NPC_CARETAKER
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBLT .CMP_300_TRUE
    LDD #0
    LBRA .CMP_300_END
.CMP_300_TRUE:
    LDD #1
.CMP_300_END:
    LBEQ IF_NEXT_311
    ; SET_INTENSITY: Set drawing intensity
    LDD #90
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    LBRA IF_END_310
IF_NEXT_311:
    ; SET_INTENSITY: Set drawing intensity
    LDD #50
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
IF_END_310:
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: caretaker (index=1, 7 paths)
    LDD >VAR_CARETAKER_SX
    TFR B,A       ; X position (low byte) — B already holds it
    STA TMPPTR    ; Save X to temporary storage
    LDD #-118
    TFR B,A       ; Y position (low byte) — B already holds it
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    LDX #1        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    CLR DRAW_VEC_INTENSITY  ; Reset: next DRAW_VECTOR uses .vec intensities
    LDD #0
    STD RESULT
    LBRA IF_END_308
IF_NEXT_309:
IF_END_308:
    LBRA IF_END_306
IF_NEXT_307:
IF_END_306:
    LDD #1  ; const ROOM_WORKSHOP
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_ROOM
    CMPD TMPVAL
    LBEQ .CMP_301_TRUE
    LDD #0
    LBRA .CMP_301_END
.CMP_301_TRUE:
    LDD #1
.CMP_301_END:
    LBEQ IF_NEXT_313
    LDX #ARRAY_CLOCK_HS_X_DATA  ; Array base
    LDD #3  ; const CLOCK_HS_HANS
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_SCROLL_X
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_HANS_SX
    LDD #-120
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_HANS_SX
    CMPD TMPVAL
    LBGT .CMP_303_TRUE
    LDD #0
    LBRA .CMP_303_END
.CMP_303_TRUE:
    LDD #1
.CMP_303_END:
    LBEQ .LOGIC_302_FALSE
    LDD #120
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_HANS_SX
    CMPD TMPVAL
    LBLT .CMP_304_TRUE
    LDD #0
    LBRA .CMP_304_END
.CMP_304_TRUE:
    LDD #1
.CMP_304_END:
    LBEQ .LOGIC_302_FALSE
    LDD #1
    LBRA .LOGIC_302_END
.LOGIC_302_FALSE:
    LDD #0
.LOGIC_302_END:
    LBEQ IF_NEXT_315
    LDD #2
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_NPC_STATE_DATA  ; Array base
    LDD #1  ; const NPC_HANS
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBLT .CMP_305_TRUE
    LDD #0
    LBRA .CMP_305_END
.CMP_305_TRUE:
    LDD #1
.CMP_305_END:
    LBEQ IF_NEXT_317
    ; SET_INTENSITY: Set drawing intensity
    LDD #90
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    LBRA IF_END_316
IF_NEXT_317:
    ; SET_INTENSITY: Set drawing intensity
    LDD #50
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
IF_END_316:
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: hans_automata (index=10, 8 paths)
    LDD >VAR_HANS_SX
    TFR B,A       ; X position (low byte) — B already holds it
    STA TMPPTR    ; Save X to temporary storage
    LDD #-118
    TFR B,A       ; Y position (low byte) — B already holds it
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    LDX #10        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    CLR DRAW_VEC_INTENSITY  ; Reset: next DRAW_VECTOR uses .vec intensities
    LDD #0
    STD RESULT
    LBRA IF_END_314
IF_NEXT_315:
IF_END_314:
    LBRA IF_END_312
IF_NEXT_313:
IF_END_312:
    LDD #3  ; const ROOM_WEIGHTS
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_ROOM
    CMPD TMPVAL
    LBEQ .CMP_306_TRUE
    LDD #0
    LBRA .CMP_306_END
.CMP_306_TRUE:
    LDD #1
.CMP_306_END:
    LBEQ IF_NEXT_319
    LDD #3
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INV_WEIGHT
    CMPD TMPVAL
    LBGT .CMP_307_TRUE
    LDD #0
    LBRA .CMP_307_END
.CMP_307_TRUE:
    LDD #1
.CMP_307_END:
    LBEQ IF_NEXT_321
    LDD >VAR_FLAGS_B
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1  ; const FL_PLAT_DOWN
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ORA TMPPTR2     ; A OR TMPPTR2+0 (high byte)
    ORB TMPPTR2+1   ; B OR TMPPTR2+1 (low byte)
    STD VAR_FLAGS_B
    LBRA IF_END_320
IF_NEXT_321:
    LDD >VAR_FLAGS_B
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #254
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    STD VAR_FLAGS_B
IF_END_320:
    LDD #280
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_SCROLL_X
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_PLAT_SX
    LDD #-120
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAT_SX
    CMPD TMPVAL
    LBGT .CMP_309_TRUE
    LDD #0
    LBRA .CMP_309_END
.CMP_309_TRUE:
    LDD #1
.CMP_309_END:
    LBEQ .LOGIC_308_FALSE
    LDD #120
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAT_SX
    CMPD TMPVAL
    LBLT .CMP_310_TRUE
    LDD #0
    LBRA .CMP_310_END
.CMP_310_TRUE:
    LDD #1
.CMP_310_END:
    LBEQ .LOGIC_308_FALSE
    LDD #1
    LBRA .LOGIC_308_END
.LOGIC_308_FALSE:
    LDD #0
.LOGIC_308_END:
    LBEQ IF_NEXT_323
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAGS_B
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1  ; const FL_PLAT_DOWN
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    CMPD TMPVAL
    LBEQ .CMP_311_TRUE
    LDD #0
    LBRA .CMP_311_END
.CMP_311_TRUE:
    LDD #1
.CMP_311_END:
    LBEQ IF_NEXT_325
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: platform_up (index=16, 5 paths)
    LDD >VAR_PLAT_SX
    TFR B,A       ; X position (low byte) — B already holds it
    STA TMPPTR    ; Save X to temporary storage
    LDD #-85
    TFR B,A       ; Y position (low byte) — B already holds it
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    LDX #16        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    CLR DRAW_VEC_INTENSITY  ; Reset: next DRAW_VECTOR uses .vec intensities
    LDD #0
    STD RESULT
    LBRA IF_END_324
IF_NEXT_325:
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: platform_down (index=15, 7 paths)
    LDD >VAR_PLAT_SX
    TFR B,A       ; X position (low byte) — B already holds it
    STA TMPPTR    ; Save X to temporary storage
    LDD #-85
    TFR B,A       ; Y position (low byte) — B already holds it
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    LDX #15        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    CLR DRAW_VEC_INTENSITY  ; Reset: next DRAW_VECTOR uses .vec intensities
    LDD #0
    STD RESULT
IF_END_324:
    LBRA IF_END_322
IF_NEXT_323:
IF_END_322:
    LBRA IF_END_318
IF_NEXT_319:
IF_END_318:
    LDD #4  ; const ROOM_OPTICS
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_ROOM
    CMPD TMPVAL
    LBEQ .CMP_312_TRUE
    LDD #0
    LBRA .CMP_312_END
.CMP_312_TRUE:
    LDD #1
.CMP_312_END:
    LBEQ IF_NEXT_327
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAGS_A
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #64  ; const FL_OPTICS_SOLVED
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    CMPD TMPVAL
    LBNE .CMP_313_TRUE
    LDD #0
    LBRA .CMP_313_END
.CMP_313_TRUE:
    LDD #1
.CMP_313_END:
    LBEQ IF_NEXT_329
    LDD #420
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_SCROLL_X
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_COMP_SX
    LDD #-120
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_COMP_SX
    CMPD TMPVAL
    LBGT .CMP_315_TRUE
    LDD #0
    LBRA .CMP_315_END
.CMP_315_TRUE:
    LDD #1
.CMP_315_END:
    LBEQ .LOGIC_314_FALSE
    LDD #120
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_COMP_SX
    CMPD TMPVAL
    LBLT .CMP_316_TRUE
    LDD #0
    LBRA .CMP_316_END
.CMP_316_TRUE:
    LDD #1
.CMP_316_END:
    LBEQ .LOGIC_314_FALSE
    LDD #1
    LBRA .LOGIC_314_END
.LOGIC_314_FALSE:
    LDD #0
.LOGIC_314_END:
    LBEQ IF_NEXT_331
    ; SET_INTENSITY: Set drawing intensity
    LDD #110
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: wall_compartment (index=19, 4 paths)
    LDD >VAR_COMP_SX
    TFR B,A       ; X position (low byte) — B already holds it
    STA TMPPTR    ; Save X to temporary storage
    LDD #-88
    TFR B,A       ; Y position (low byte) — B already holds it
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    LDX #19        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    CLR DRAW_VEC_INTENSITY  ; Reset: next DRAW_VECTOR uses .vec intensities
    LDD #0
    STD RESULT
    LBRA IF_END_330
IF_NEXT_331:
IF_END_330:
    LBRA IF_END_328
IF_NEXT_329:
IF_END_328:
    LBRA IF_END_326
IF_NEXT_327:
IF_END_326:
    LDD #5  ; const ROOM_CONSERVATORY
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_ROOM
    CMPD TMPVAL
    LBEQ .CMP_317_TRUE
    LDD #0
    LBRA .CMP_317_END
.CMP_317_TRUE:
    LDD #1
.CMP_317_END:
    LBEQ IF_NEXT_333
    LDD #2
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_NPC_STATE_DATA  ; Array base
    LDD #2  ; const NPC_ELISA
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBLT .CMP_318_TRUE
    LDD #0
    LBRA .CMP_318_END
.CMP_318_TRUE:
    LDD #1
.CMP_318_END:
    LBEQ IF_NEXT_335
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    LBRA IF_END_334
IF_NEXT_335:
    ; SET_INTENSITY: Set drawing intensity
    LDD #30
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
IF_END_334:
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: elisa_ghost (index=7, 3 paths)
    LDD #0
    TFR B,A       ; X position (low byte) — B already holds it
    STA TMPPTR    ; Save X to temporary storage
    LDD #-104
    TFR B,A       ; Y position (low byte) — B already holds it
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    LDX #7        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    CLR DRAW_VEC_INTENSITY  ; Reset: next DRAW_VECTOR uses .vec intensities
    LDD #0
    STD RESULT
    LBRA IF_END_332
IF_NEXT_333:
IF_END_332:
    LDD #6  ; const ROOM_VAULT_CORRIDOR
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_ROOM
    CMPD TMPVAL
    LBEQ .CMP_319_TRUE
    LDD #0
    LBRA .CMP_319_END
.CMP_319_TRUE:
    LDD #1
.CMP_319_END:
    LBEQ IF_NEXT_337
    ; SET_INTENSITY: Set drawing intensity
    LDD #85
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: crystal_apprentice (index=4, 7 paths)
    LDD #-30
    TFR B,A       ; X position (low byte) — B already holds it
    STA TMPPTR    ; Save X to temporary storage
    LDD #-104
    TFR B,A       ; Y position (low byte) — B already holds it
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    LDX #4        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    CLR DRAW_VEC_INTENSITY  ; Reset: next DRAW_VECTOR uses .vec intensities
    LDD #0
    STD RESULT
    LBRA IF_END_336
IF_NEXT_337:
IF_END_336:
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_SCROLL_X
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_SCREEN_X
    ; SET_INTENSITY: Set drawing intensity
    LDD #110
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: player (index=17, 7 paths)
    LDD >VAR_SCREEN_X
    TFR B,A       ; X position (low byte) — B already holds it
    STA TMPPTR    ; Save X to temporary storage
    LDD >VAR_PLAYER_Y
    TFR B,A       ; Y position (low byte) — B already holds it
    STA TMPPTR+1  ; Save Y to temporary storage
    LDA TMPPTR    ; X position
    STA DRAW_VEC_X
    LDA TMPPTR+1  ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    LDX #17        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    CLR DRAW_VEC_INTENSITY  ; Reset: next DRAW_VECTOR uses .vec intensities
    LDD #0
    STD RESULT
    JSR DRAW_BOTTOM_HUD
    RTS

; Function: DRAW_BOTTOM_HUD (Bank #0)
DRAW_BOTTOM_HUD:
    LDD #7
    STD TMPPTR2     ; Save n (TMPPTR2+1 = n)
    NEGB            ; B = -n -> TEXT_SCALE_H
    STB >TEXT_SCALE_H
    LDB TMPPTR2+1   ; Reload n (from TMPPTR2, not RESULT)
    ASLB            ; n*2
    ASLB            ; n*4
    ASLB            ; n*8
    ADDB TMPPTR2+1  ; n*8 + n = n*9 -> TEXT_SCALE_W
    STB >TEXT_SCALE_W
    ; SET_INTENSITY: Set drawing intensity
    LDD #70
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    JSR TRAMP_DRAW_VERB_INDICATOR  ; cross-bank trampoline (bank #0 -> bank #1)
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    CMPD TMPVAL
    LBGT .CMP_320_TRUE
    LDD #0
    LBRA .CMP_320_END
.CMP_320_TRUE:
    LDD #1
.CMP_320_END:
    LBEQ IF_NEXT_339
    JSR DRAW_MESSAGE
    LBRA IF_END_338
IF_NEXT_339:
IF_END_338:
    RTS

; Function: DRAW_MESSAGE (Bank #0)
DRAW_MESSAGE:
    LDD #7
    STD TMPPTR2     ; Save n (TMPPTR2+1 = n)
    NEGB            ; B = -n -> TEXT_SCALE_H
    STB >TEXT_SCALE_H
    LDB TMPPTR2+1   ; Reload n (from TMPPTR2, not RESULT)
    ASLB            ; n*2
    ASLB            ; n*4
    ASLB            ; n*8
    ADDB TMPPTR2+1  ; n*8 + n = n*9 -> TEXT_SCALE_W
    STB >TEXT_SCALE_W
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_MSG: Dispatch via ROM message table
    LDD >VAR_MSG_ID
    STD VAR_ARG0
    JSR PRINT_MSG_DISPATCH
    LDD #0
    STD RESULT
    RTS

; Function: DROP_ITEM (Bank #0)
DROP_ITEM:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD >VAR_ARG0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_335_TRUE
    LDD #0
    LBRA .CMP_335_END
.CMP_335_TRUE:
    LDD #1
.CMP_335_END:
    LBEQ IF_NEXT_356
    LDD >VAR_ARG0
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_INV_ITEMS_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #0
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD >VAR_INV_COUNT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_INV_COUNT
    LDD >VAR_INV_WEIGHT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_ITEM_WEIGHT_DATA  ; Array base
    LDD >VAR_ARG0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_INV_WEIGHT
    LBRA IF_END_355
IF_NEXT_356:
IF_END_355:
    RTS

; Function: DRAW_INVENTORY (Bank #0)
DRAW_INVENTORY:
    LDD #7
    STD TMPPTR2     ; Save n (TMPPTR2+1 = n)
    NEGB            ; B = -n -> TEXT_SCALE_H
    STB >TEXT_SCALE_H
    LDB TMPPTR2+1   ; Reload n (from TMPPTR2, not RESULT)
    ASLB            ; n*2
    ASLB            ; n*4
    ASLB            ; n*8
    ADDB TMPPTR2+1  ; n*8 + n = n*9 -> TEXT_SCALE_W
    STB >TEXT_SCALE_W
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-42
    STD VAR_ARG0
    LDD #115
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_64485404977468      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #0  ; const ITEM_LENS
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_336_TRUE
    LDD #0
    LBRA .CMP_336_END
.CMP_336_TRUE:
    LDD #1
.CMP_336_END:
    LBEQ IF_NEXT_358
    LDD #0  ; const ITEM_LENS
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INV_CURSOR
    CMPD TMPVAL
    LBEQ .CMP_337_TRUE
    LDD #0
    LBRA .CMP_337_END
.CMP_337_TRUE:
    LDD #1
.CMP_337_END:
    LBEQ IF_NEXT_360
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    LBRA IF_END_359
IF_NEXT_360:
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
IF_END_359:
    LBRA IF_END_357
IF_NEXT_358:
    ; SET_INTENSITY: Set drawing intensity
    LDD #35
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
IF_END_357:
    ; PRINT_TEXT: Print text at position
    LDD #-105
    STD VAR_ARG0
    LDD #90
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_64184922134308892      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #1  ; const ITEM_GEAR
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_338_TRUE
    LDD #0
    LBRA .CMP_338_END
.CMP_338_TRUE:
    LDD #1
.CMP_338_END:
    LBEQ IF_NEXT_362
    LDD #1  ; const ITEM_GEAR
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INV_CURSOR
    CMPD TMPVAL
    LBEQ .CMP_339_TRUE
    LDD #0
    LBRA .CMP_339_END
.CMP_339_TRUE:
    LDD #1
.CMP_339_END:
    LBEQ IF_NEXT_364
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    LBRA IF_END_363
IF_NEXT_364:
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
IF_END_363:
    LBRA IF_END_361
IF_NEXT_362:
    ; SET_INTENSITY: Set drawing intensity
    LDD #35
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
IF_END_361:
    ; PRINT_TEXT: Print text at position
    LDD #-105
    STD VAR_ARG0
    LDD #73
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_60075665603304044      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #2  ; const ITEM_PRISM
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_340_TRUE
    LDD #0
    LBRA .CMP_340_END
.CMP_340_TRUE:
    LDD #1
.CMP_340_END:
    LBEQ IF_NEXT_366
    LDD #2  ; const ITEM_PRISM
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INV_CURSOR
    CMPD TMPVAL
    LBEQ .CMP_341_TRUE
    LDD #0
    LBRA .CMP_341_END
.CMP_341_TRUE:
    LDD #1
.CMP_341_END:
    LBEQ IF_NEXT_368
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    LBRA IF_END_367
IF_NEXT_368:
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
IF_END_367:
    LBRA IF_END_365
IF_NEXT_366:
    ; SET_INTENSITY: Set drawing intensity
    LDD #35
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
IF_END_365:
    ; PRINT_TEXT: Print text at position
    LDD #-105
    STD VAR_ARG0
    LDD #56
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_67802925852799259      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #3  ; const ITEM_BLANKET
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_342_TRUE
    LDD #0
    LBRA .CMP_342_END
.CMP_342_TRUE:
    LDD #1
.CMP_342_END:
    LBEQ IF_NEXT_370
    LDD #3  ; const ITEM_BLANKET
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INV_CURSOR
    CMPD TMPVAL
    LBEQ .CMP_343_TRUE
    LDD #0
    LBRA .CMP_343_END
.CMP_343_TRUE:
    LDD #1
.CMP_343_END:
    LBEQ IF_NEXT_372
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    LBRA IF_END_371
IF_NEXT_372:
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
IF_END_371:
    LBRA IF_END_369
IF_NEXT_370:
    ; SET_INTENSITY: Set drawing intensity
    LDD #35
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
IF_END_369:
    ; PRINT_TEXT: Print text at position
    LDD #-105
    STD VAR_ARG0
    LDD #39
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_56162530743028252      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #4  ; const ITEM_EYE
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_344_TRUE
    LDD #0
    LBRA .CMP_344_END
.CMP_344_TRUE:
    LDD #1
.CMP_344_END:
    LBEQ IF_NEXT_374
    LDD #4  ; const ITEM_EYE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INV_CURSOR
    CMPD TMPVAL
    LBEQ .CMP_345_TRUE
    LDD #0
    LBRA .CMP_345_END
.CMP_345_TRUE:
    LDD #1
.CMP_345_END:
    LBEQ IF_NEXT_376
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    LBRA IF_END_375
IF_NEXT_376:
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
IF_END_375:
    LBRA IF_END_373
IF_NEXT_374:
    ; SET_INTENSITY: Set drawing intensity
    LDD #35
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
IF_END_373:
    ; PRINT_TEXT: Print text at position
    LDD #-105
    STD VAR_ARG0
    LDD #22
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_58967237406000075      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #5  ; const ITEM_OIL
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_346_TRUE
    LDD #0
    LBRA .CMP_346_END
.CMP_346_TRUE:
    LDD #1
.CMP_346_END:
    LBEQ IF_NEXT_378
    LDD #5  ; const ITEM_OIL
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INV_CURSOR
    CMPD TMPVAL
    LBEQ .CMP_347_TRUE
    LDD #0
    LBRA .CMP_347_END
.CMP_347_TRUE:
    LDD #1
.CMP_347_END:
    LBEQ IF_NEXT_380
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    LBRA IF_END_379
IF_NEXT_380:
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
IF_END_379:
    LBRA IF_END_377
IF_NEXT_378:
    ; SET_INTENSITY: Set drawing intensity
    LDD #35
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
IF_END_377:
    ; PRINT_TEXT: Print text at position
    LDD #-105
    STD VAR_ARG0
    LDD #5
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_66746456558499436      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #6  ; const ITEM_SHEET
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_348_TRUE
    LDD #0
    LBRA .CMP_348_END
.CMP_348_TRUE:
    LDD #1
.CMP_348_END:
    LBEQ IF_NEXT_382
    LDD #6  ; const ITEM_SHEET
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INV_CURSOR
    CMPD TMPVAL
    LBEQ .CMP_349_TRUE
    LDD #0
    LBRA .CMP_349_END
.CMP_349_TRUE:
    LDD #1
.CMP_349_END:
    LBEQ IF_NEXT_384
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    LBRA IF_END_383
IF_NEXT_384:
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
IF_END_383:
    LBRA IF_END_381
IF_NEXT_382:
    ; SET_INTENSITY: Set drawing intensity
    LDD #35
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
IF_END_381:
    ; PRINT_TEXT: Print text at position
    LDD #-105
    STD VAR_ARG0
    LDD #-12
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_69993623963913400      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #7  ; const ITEM_KEY
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_350_TRUE
    LDD #0
    LBRA .CMP_350_END
.CMP_350_TRUE:
    LDD #1
.CMP_350_END:
    LBEQ IF_NEXT_386
    LDD #7  ; const ITEM_KEY
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INV_CURSOR
    CMPD TMPVAL
    LBEQ .CMP_351_TRUE
    LDD #0
    LBRA .CMP_351_END
.CMP_351_TRUE:
    LDD #1
.CMP_351_END:
    LBEQ IF_NEXT_388
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    LBRA IF_END_387
IF_NEXT_388:
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
IF_END_387:
    LBRA IF_END_385
IF_NEXT_386:
    ; SET_INTENSITY: Set drawing intensity
    LDD #35
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
IF_END_385:
    ; PRINT_TEXT: Print text at position
    LDD #-105
    STD VAR_ARG0
    LDD #-29
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_72649866947832674      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD #3
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INV_WEIGHT
    CMPD TMPVAL
    LBGT .CMP_352_TRUE
    LDD #0
    LBRA .CMP_352_END
.CMP_352_TRUE:
    LDD #1
.CMP_352_END:
    LBEQ IF_NEXT_390
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-105
    STD VAR_ARG0
    LDD #-60
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_1357395807964332428      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_389
IF_NEXT_390:
    ; SET_INTENSITY: Set drawing intensity
    LDD #70
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-42
    STD VAR_ARG0
    LDD #-60
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_76166780098692      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
IF_END_389:
    ; SET_INTENSITY: Set drawing intensity
    LDD #60
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD VAR_ARG0
    LDD #-80
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_6391486935903418068      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    RTS

; Function: ACCELERATE_HEARTBEAT (Bank #0)
ACCELERATE_HEARTBEAT:
    LDD >VAR_HEARTBEAT_TEMPO
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #8
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_HEARTBEAT_TEMPO
    LDD #20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_HEARTBEAT_TEMPO
    CMPD TMPVAL
    LBLT .CMP_364_TRUE
    LDD #0
    LBRA .CMP_364_END
.CMP_364_TRUE:
    LDD #1
.CMP_364_END:
    LBEQ IF_NEXT_407
    LDD #20
    STD VAR_HEARTBEAT_TEMPO
    LBRA IF_END_406
IF_NEXT_407:
IF_END_406:
    RTS


; ================================================


; ===== BANK #01 (physical offset $04000) =====

    ORG $0000  ; Sequential bank model

; Function: ENTER_ROOM (Bank #1)
ENTER_ROOM:
    LDD >VAR_ARG0
    STD VAR_CURRENT_ROOM
    LDD #-1
    STD VAR_NEAR_HS
    LDD #0
    STD VAR_MSG_ID
    LDD #0
    STD VAR_MSG_TIMER
    LDD #0
    STD VAR_ROOM_EXIT
    LDD #0
    STD VAR_SHOW_INVENTORY
    LDD #0  ; const ROOM_ENTRANCE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_29_TRUE
    LDD #0
    LBRA .CMP_29_END
.CMP_29_TRUE:
    LDD #1
.CMP_29_END:
    LBEQ IF_NEXT_40
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'entrance'
    ; Level asset index: 3 (multibank)
    LDX #3
    JSR LOAD_LEVEL_BANKED
    LDD #0
    STD VAR_PLAYER_X
    LDD #-115
    STD VAR_PLAYER_Y
    LDD #0
    STD VAR_SCROLL_X
    ; ===== SET_CAMERA_X builtin =====
    LDD #0
    STD >CAMERA_X    ; Store 16-bit camera X scroll offset
    LDD #0
    STD RESULT
    LDD #2  ; const MUSIC_EXPLORATION
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_MUSIC
    CMPD TMPVAL
    LBNE .CMP_30_TRUE
    LDD #0
    LBRA .CMP_30_END
.CMP_30_TRUE:
    LDD #1
.CMP_30_END:
    LBEQ IF_NEXT_42
    ; PLAY_MUSIC("exploration") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LDD #2  ; const MUSIC_EXPLORATION
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_41
IF_NEXT_42:
IF_END_41:
    LBRA IF_END_39
IF_NEXT_40:
    LDD #1  ; const ROOM_WORKSHOP
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_31_TRUE
    LDD #0
    LBRA .CMP_31_END
.CMP_31_TRUE:
    LDD #1
.CMP_31_END:
    LBEQ IF_NEXT_43
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'clockroom'
    ; Level asset index: 1 (multibank)
    LDX #1
    JSR LOAD_LEVEL_BANKED
    LDD #70
    STD VAR_PLAYER_X
    LDD #-75
    STD VAR_PLAYER_Y
    LDD #0
    STD VAR_SCROLL_X
    ; ===== SET_CAMERA_X builtin =====
    LDD #0
    STD >CAMERA_X    ; Store 16-bit camera X scroll offset
    LDD #0
    STD RESULT
    LDD #2  ; const MUSIC_EXPLORATION
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_MUSIC
    CMPD TMPVAL
    LBNE .CMP_32_TRUE
    LDD #0
    LBRA .CMP_32_END
.CMP_32_TRUE:
    LDD #1
.CMP_32_END:
    LBEQ IF_NEXT_45
    ; PLAY_MUSIC("exploration") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LDD #2  ; const MUSIC_EXPLORATION
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_44
IF_NEXT_45:
IF_END_44:
    LBRA IF_END_39
IF_NEXT_43:
    LDD #2  ; const ROOM_ANTEROOM
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_33_TRUE
    LDD #0
    LBRA .CMP_33_END
.CMP_33_TRUE:
    LDD #1
.CMP_33_END:
    LBEQ IF_NEXT_46
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'anteroom'
    ; Level asset index: 0 (multibank)
    LDX #0
    JSR LOAD_LEVEL_BANKED
    LDD #50
    STD VAR_PLAYER_X
    LDD #-115
    STD VAR_PLAYER_Y
    LDD #0
    STD VAR_SCROLL_X
    ; ===== SET_CAMERA_X builtin =====
    LDD #0
    STD >CAMERA_X    ; Store 16-bit camera X scroll offset
    LDD #0
    STD RESULT
    LDD #2  ; const MUSIC_EXPLORATION
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_MUSIC
    CMPD TMPVAL
    LBNE .CMP_34_TRUE
    LDD #0
    LBRA .CMP_34_END
.CMP_34_TRUE:
    LDD #1
.CMP_34_END:
    LBEQ IF_NEXT_48
    ; PLAY_MUSIC("exploration") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LDD #2  ; const MUSIC_EXPLORATION
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_47
IF_NEXT_48:
IF_END_47:
    LBRA IF_END_39
IF_NEXT_46:
    LDD #3  ; const ROOM_WEIGHTS
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_35_TRUE
    LDD #0
    LBRA .CMP_35_END
.CMP_35_TRUE:
    LDD #1
.CMP_35_END:
    LBEQ IF_NEXT_49
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'weights_room'
    ; Level asset index: 6 (multibank)
    LDX #6
    JSR LOAD_LEVEL_BANKED
    LDD #50
    STD VAR_PLAYER_X
    LDD #-115
    STD VAR_PLAYER_Y
    LDD #0
    STD VAR_SCROLL_X
    ; ===== SET_CAMERA_X builtin =====
    LDD #0
    STD >CAMERA_X    ; Store 16-bit camera X scroll offset
    LDD #0
    STD RESULT
    LDD #2  ; const MUSIC_EXPLORATION
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_MUSIC
    CMPD TMPVAL
    LBNE .CMP_36_TRUE
    LDD #0
    LBRA .CMP_36_END
.CMP_36_TRUE:
    LDD #1
.CMP_36_END:
    LBEQ IF_NEXT_51
    ; PLAY_MUSIC("exploration") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LDD #2  ; const MUSIC_EXPLORATION
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_50
IF_NEXT_51:
IF_END_50:
    LBRA IF_END_39
IF_NEXT_49:
    LDD #4  ; const ROOM_OPTICS
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_37_TRUE
    LDD #0
    LBRA .CMP_37_END
.CMP_37_TRUE:
    LDD #1
.CMP_37_END:
    LBEQ IF_NEXT_52
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'optics_lab'
    ; Level asset index: 4 (multibank)
    LDX #4
    JSR LOAD_LEVEL_BANKED
    LDD #50
    STD VAR_PLAYER_X
    LDD #-115
    STD VAR_PLAYER_Y
    LDD #0
    STD VAR_SCROLL_X
    ; ===== SET_CAMERA_X builtin =====
    LDD #0
    STD >CAMERA_X    ; Store 16-bit camera X scroll offset
    LDD #0
    STD RESULT
    LDD #2  ; const MUSIC_EXPLORATION
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_MUSIC
    CMPD TMPVAL
    LBNE .CMP_38_TRUE
    LDD #0
    LBRA .CMP_38_END
.CMP_38_TRUE:
    LDD #1
.CMP_38_END:
    LBEQ IF_NEXT_54
    ; PLAY_MUSIC("exploration") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LDD #2  ; const MUSIC_EXPLORATION
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_53
IF_NEXT_54:
IF_END_53:
    LBRA IF_END_39
IF_NEXT_52:
    LDD #5  ; const ROOM_CONSERVATORY
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_39_TRUE
    LDD #0
    LBRA .CMP_39_END
.CMP_39_TRUE:
    LDD #1
.CMP_39_END:
    LBEQ IF_NEXT_55
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'conservatory'
    ; Level asset index: 2 (multibank)
    LDX #2
    JSR LOAD_LEVEL_BANKED
    LDD #-60
    STD VAR_PLAYER_X
    LDD #-115
    STD VAR_PLAYER_Y
    LDD #0
    STD VAR_SCROLL_X
    ; ===== SET_CAMERA_X builtin =====
    LDD #0
    STD >CAMERA_X    ; Store 16-bit camera X scroll offset
    LDD #0
    STD RESULT
    LDD #2  ; const MUSIC_EXPLORATION
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_MUSIC
    CMPD TMPVAL
    LBNE .CMP_40_TRUE
    LDD #0
    LBRA .CMP_40_END
.CMP_40_TRUE:
    LDD #1
.CMP_40_END:
    LBEQ IF_NEXT_57
    ; PLAY_MUSIC("exploration") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LDD #2  ; const MUSIC_EXPLORATION
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_56
IF_NEXT_57:
IF_END_56:
    LBRA IF_END_39
IF_NEXT_55:
    LDD #6  ; const ROOM_VAULT_CORRIDOR
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_41_TRUE
    LDD #0
    LBRA .CMP_41_END
.CMP_41_TRUE:
    LDD #1
.CMP_41_END:
    LBEQ IF_END_39
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'vault_corridor'
    ; Level asset index: 5 (multibank)
    LDX #5
    JSR LOAD_LEVEL_BANKED
    LDD #-60
    STD VAR_PLAYER_X
    LDD #-115
    STD VAR_PLAYER_Y
    LDD #0
    STD VAR_SCROLL_X
    ; ===== SET_CAMERA_X builtin =====
    LDD #0
    STD >CAMERA_X    ; Store 16-bit camera X scroll offset
    LDD #0
    STD RESULT
    LDD #2  ; const MUSIC_EXPLORATION
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_MUSIC
    CMPD TMPVAL
    LBNE .CMP_42_TRUE
    LDD #0
    LBRA .CMP_42_END
.CMP_42_TRUE:
    LDD #1
.CMP_42_END:
    LBEQ IF_NEXT_59
    ; PLAY_MUSIC("exploration") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LDD #2  ; const MUSIC_EXPLORATION
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_58
IF_NEXT_59:
IF_END_58:
    LBRA IF_END_39
IF_END_39:
    RTS

; Function: UPDATE_ROOM (Bank #1)
UPDATE_ROOM:
    JSR J1X_BUILTIN
    STD RESULT
    STD VAR_JOY_X
    LDD #30
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBGT .CMP_43_TRUE
    LDD #0
    LBRA .CMP_43_END
.CMP_43_TRUE:
    LDD #1
.CMP_43_END:
    LBEQ IF_NEXT_61
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_SPEED
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_PLAYER_X
    LBRA IF_END_60
IF_NEXT_61:
    LDD #-30
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBLT .CMP_44_TRUE
    LDD #0
    LBRA .CMP_44_END
.CMP_44_TRUE:
    LDD #1
.CMP_44_END:
    LBEQ IF_END_60
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_SPEED
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_PLAYER_X
    LBRA IF_END_60
IF_END_60:
    ; CLAMP: Clamp value to range [min, max]
    LDD >VAR_PLAYER_X
    STD TMPPTR     ; Save value
    LDD #-90
    STD TMPPTR+2   ; Save min
    LDD #780
    STD TMPPTR+4   ; Save max
    LDD TMPPTR     ; Load value
    CMPD TMPPTR+2  ; Compare with min
    BGE .CLAMP_0_CHK_MAX ; Branch if value >= min
    LDD TMPPTR+2
    STD RESULT
    BRA .CLAMP_0_END
.CLAMP_0_CHK_MAX:
    LDD TMPPTR     ; Load value again
    CMPD TMPPTR+4  ; Compare with max
    BLE .CLAMP_0_OK  ; Branch if value <= max
    LDD TMPPTR+4
    STD RESULT
    BRA .CLAMP_0_END
.CLAMP_0_OK:
    LDD TMPPTR
    STD RESULT
.CLAMP_0_END:
    STD VAR_PLAYER_X
    ; CLAMP: Clamp value to range [min, max]
    LDD >VAR_PLAYER_X
    STD TMPPTR     ; Save value
    LDD #0
    STD TMPPTR+2   ; Save min
    LDD #670
    STD TMPPTR+4   ; Save max
    LDD TMPPTR     ; Load value
    CMPD TMPPTR+2  ; Compare with min
    BGE .CLAMP_1_CHK_MAX ; Branch if value >= min
    LDD TMPPTR+2
    STD RESULT
    BRA .CLAMP_1_END
.CLAMP_1_CHK_MAX:
    LDD TMPPTR     ; Load value again
    CMPD TMPPTR+4  ; Compare with max
    BLE .CLAMP_1_OK  ; Branch if value <= max
    LDD TMPPTR+4
    STD RESULT
    BRA .CLAMP_1_END
.CLAMP_1_OK:
    LDD TMPPTR
    STD RESULT
.CLAMP_1_END:
    STD VAR_SCROLL_X
    ; ===== SET_CAMERA_X builtin =====
    LDD >VAR_SCROLL_X
    STD >CAMERA_X    ; Store 16-bit camera X scroll offset
    LDD #0
    STD RESULT
    LDD #-1
    STD VAR_NEAR_HS
    LDD #0  ; const ROOM_ENTRANCE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_ROOM
    CMPD TMPVAL
    LBEQ .CMP_45_TRUE
    LDD #0
    LBRA .CMP_45_END
.CMP_45_TRUE:
    LDD #1
.CMP_45_END:
    LBEQ IF_NEXT_63
    JSR CHECK_ENTRANCE_HOTSPOTS
    LDD #-85
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    CMPD TMPVAL
    LBLE .CMP_48_TRUE
    LDD #0
    LBRA .CMP_48_END
.CMP_48_TRUE:
    LDD #1
.CMP_48_END:
    LBEQ .LOGIC_47_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAGS_A
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #2  ; const FL_TALLER_OPEN
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    CMPD TMPVAL
    LBNE .CMP_49_TRUE
    LDD #0
    LBRA .CMP_49_END
.CMP_49_TRUE:
    LDD #1
.CMP_49_END:
    LBEQ .LOGIC_47_FALSE
    LDD #1
    LBRA .LOGIC_47_END
.LOGIC_47_FALSE:
    LDD #0
.LOGIC_47_END:
    LBEQ .LOGIC_46_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    CMPD TMPVAL
    LBEQ .CMP_50_TRUE
    LDD #0
    LBRA .CMP_50_END
.CMP_50_TRUE:
    LDD #1
.CMP_50_END:
    LBEQ .LOGIC_46_FALSE
    LDD #1
    LBRA .LOGIC_46_END
.LOGIC_46_FALSE:
    LDD #0
.LOGIC_46_END:
    LBEQ IF_NEXT_65
    LDD #5  ; const ROOM_CONSERVATORY
    STD VAR_ARG0
    JSR ENTER_ROOM
    LBRA IF_END_64
IF_NEXT_65:
IF_END_64:
    LBRA IF_END_62
IF_NEXT_63:
    LDD #1  ; const ROOM_WORKSHOP
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_ROOM
    CMPD TMPVAL
    LBEQ .CMP_51_TRUE
    LDD #0
    LBRA .CMP_51_END
.CMP_51_TRUE:
    LDD #1
.CMP_51_END:
    LBEQ IF_NEXT_66
    JSR TRAMP_CHECK_WORKSHOP_HOTSPOTS  ; cross-bank trampoline (bank #1 -> bank #0)
    LDD #770
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    CMPD TMPVAL
    LBGE .CMP_54_TRUE
    LDD #0
    LBRA .CMP_54_END
.CMP_54_TRUE:
    LDD #1
.CMP_54_END:
    LBEQ .LOGIC_53_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAGS_A
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #16  ; const FL_PANEL_ACTIVE
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    CMPD TMPVAL
    LBNE .CMP_55_TRUE
    LDD #0
    LBRA .CMP_55_END
.CMP_55_TRUE:
    LDD #1
.CMP_55_END:
    LBEQ .LOGIC_53_FALSE
    LDD #1
    LBRA .LOGIC_53_END
.LOGIC_53_FALSE:
    LDD #0
.LOGIC_53_END:
    LBEQ .LOGIC_52_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    CMPD TMPVAL
    LBEQ .CMP_56_TRUE
    LDD #0
    LBRA .CMP_56_END
.CMP_56_TRUE:
    LDD #1
.CMP_56_END:
    LBEQ .LOGIC_52_FALSE
    LDD #1
    LBRA .LOGIC_52_END
.LOGIC_52_FALSE:
    LDD #0
.LOGIC_52_END:
    LBEQ IF_NEXT_68
    LDD #6  ; const ROOM_VAULT_CORRIDOR
    STD VAR_ARG0
    JSR ENTER_ROOM
    LBRA IF_END_67
IF_NEXT_68:
IF_END_67:
    LDD #690
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    CMPD TMPVAL
    LBGE .CMP_60_TRUE
    LDD #0
    LBRA .CMP_60_END
.CMP_60_TRUE:
    LDD #1
.CMP_60_END:
    LBEQ .LOGIC_59_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAGS_A
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #128  ; const FL_OPTICS_OPEN
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    CMPD TMPVAL
    LBNE .CMP_61_TRUE
    LDD #0
    LBRA .CMP_61_END
.CMP_61_TRUE:
    LDD #1
.CMP_61_END:
    LBEQ .LOGIC_59_FALSE
    LDD #1
    LBRA .LOGIC_59_END
.LOGIC_59_FALSE:
    LDD #0
.LOGIC_59_END:
    LBEQ .LOGIC_58_FALSE
    LDD #770
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    CMPD TMPVAL
    LBLT .CMP_62_TRUE
    LDD #0
    LBRA .CMP_62_END
.CMP_62_TRUE:
    LDD #1
.CMP_62_END:
    LBEQ .LOGIC_58_FALSE
    LDD #1
    LBRA .LOGIC_58_END
.LOGIC_58_FALSE:
    LDD #0
.LOGIC_58_END:
    LBEQ .LOGIC_57_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    CMPD TMPVAL
    LBEQ .CMP_63_TRUE
    LDD #0
    LBRA .CMP_63_END
.CMP_63_TRUE:
    LDD #1
.CMP_63_END:
    LBEQ .LOGIC_57_FALSE
    LDD #1
    LBRA .LOGIC_57_END
.LOGIC_57_FALSE:
    LDD #0
.LOGIC_57_END:
    LBEQ IF_NEXT_70
    LDD #4  ; const ROOM_OPTICS
    STD VAR_ARG0
    JSR ENTER_ROOM
    LBRA IF_END_69
IF_NEXT_70:
IF_END_69:
    LBRA IF_END_62
IF_NEXT_66:
    LDD #2  ; const ROOM_ANTEROOM
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_ROOM
    CMPD TMPVAL
    LBEQ .CMP_64_TRUE
    LDD #0
    LBRA .CMP_64_END
.CMP_64_TRUE:
    LDD #1
.CMP_64_END:
    LBEQ IF_NEXT_71
    JSR CHECK_ANTEROOM_HOTSPOTS
    LDD #-85
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    CMPD TMPVAL
    LBLE .CMP_66_TRUE
    LDD #0
    LBRA .CMP_66_END
.CMP_66_TRUE:
    LDD #1
.CMP_66_END:
    LBEQ .LOGIC_65_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    CMPD TMPVAL
    LBEQ .CMP_67_TRUE
    LDD #0
    LBRA .CMP_67_END
.CMP_67_TRUE:
    LDD #1
.CMP_67_END:
    LBEQ .LOGIC_65_FALSE
    LDD #1
    LBRA .LOGIC_65_END
.LOGIC_65_FALSE:
    LDD #0
.LOGIC_65_END:
    LBEQ IF_NEXT_73
    LDD #0  ; const ROOM_ENTRANCE
    STD VAR_ARG0
    JSR ENTER_ROOM
    LBRA IF_END_72
IF_NEXT_73:
IF_END_72:
    LBRA IF_END_62
IF_NEXT_71:
    LDD #3  ; const ROOM_WEIGHTS
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_ROOM
    CMPD TMPVAL
    LBEQ .CMP_68_TRUE
    LDD #0
    LBRA .CMP_68_END
.CMP_68_TRUE:
    LDD #1
.CMP_68_END:
    LBEQ IF_NEXT_74
    JSR TRAMP_CHECK_WEIGHTS_HOTSPOTS  ; cross-bank trampoline (bank #1 -> bank #0)
    LDD #-85
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    CMPD TMPVAL
    LBLE .CMP_70_TRUE
    LDD #0
    LBRA .CMP_70_END
.CMP_70_TRUE:
    LDD #1
.CMP_70_END:
    LBEQ .LOGIC_69_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    CMPD TMPVAL
    LBEQ .CMP_71_TRUE
    LDD #0
    LBRA .CMP_71_END
.CMP_71_TRUE:
    LDD #1
.CMP_71_END:
    LBEQ .LOGIC_69_FALSE
    LDD #1
    LBRA .LOGIC_69_END
.LOGIC_69_FALSE:
    LDD #0
.LOGIC_69_END:
    LBEQ IF_NEXT_76
    LDD #2  ; const ROOM_ANTEROOM
    STD VAR_ARG0
    JSR ENTER_ROOM
    LBRA IF_END_75
IF_NEXT_76:
IF_END_75:
    LBRA IF_END_62
IF_NEXT_74:
    LDD #4  ; const ROOM_OPTICS
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_ROOM
    CMPD TMPVAL
    LBEQ .CMP_72_TRUE
    LDD #0
    LBRA .CMP_72_END
.CMP_72_TRUE:
    LDD #1
.CMP_72_END:
    LBEQ IF_NEXT_77
    JSR CHECK_OPTICS_HOTSPOTS
    LDD #-85
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    CMPD TMPVAL
    LBLE .CMP_74_TRUE
    LDD #0
    LBRA .CMP_74_END
.CMP_74_TRUE:
    LDD #1
.CMP_74_END:
    LBEQ .LOGIC_73_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    CMPD TMPVAL
    LBEQ .CMP_75_TRUE
    LDD #0
    LBRA .CMP_75_END
.CMP_75_TRUE:
    LDD #1
.CMP_75_END:
    LBEQ .LOGIC_73_FALSE
    LDD #1
    LBRA .LOGIC_73_END
.LOGIC_73_FALSE:
    LDD #0
.LOGIC_73_END:
    LBEQ IF_NEXT_79
    LDD #1  ; const ROOM_WORKSHOP
    STD VAR_ARG0
    JSR ENTER_ROOM
    LBRA IF_END_78
IF_NEXT_79:
IF_END_78:
    LBRA IF_END_62
IF_NEXT_77:
    LDD #5  ; const ROOM_CONSERVATORY
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_ROOM
    CMPD TMPVAL
    LBEQ .CMP_76_TRUE
    LDD #0
    LBRA .CMP_76_END
.CMP_76_TRUE:
    LDD #1
.CMP_76_END:
    LBEQ IF_NEXT_80
    JSR CHECK_CONSERVATORY_HOTSPOTS
    LDD #60
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    CMPD TMPVAL
    LBGE .CMP_78_TRUE
    LDD #0
    LBRA .CMP_78_END
.CMP_78_TRUE:
    LDD #1
.CMP_78_END:
    LBEQ .LOGIC_77_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    CMPD TMPVAL
    LBEQ .CMP_79_TRUE
    LDD #0
    LBRA .CMP_79_END
.CMP_79_TRUE:
    LDD #1
.CMP_79_END:
    LBEQ .LOGIC_77_FALSE
    LDD #1
    LBRA .LOGIC_77_END
.LOGIC_77_FALSE:
    LDD #0
.LOGIC_77_END:
    LBEQ IF_NEXT_82
    LDD #0  ; const ROOM_ENTRANCE
    STD VAR_ARG0
    JSR ENTER_ROOM
    LBRA IF_END_81
IF_NEXT_82:
IF_END_81:
    LBRA IF_END_62
IF_NEXT_80:
    LDD #6  ; const ROOM_VAULT_CORRIDOR
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_ROOM
    CMPD TMPVAL
    LBEQ .CMP_80_TRUE
    LDD #0
    LBRA .CMP_80_END
.CMP_80_TRUE:
    LDD #1
.CMP_80_END:
    LBEQ IF_END_62
    JSR TRAMP_CHECK_VAULT_HOTSPOTS  ; cross-bank trampoline (bank #1 -> bank #0)
    LDD #-85
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    CMPD TMPVAL
    LBLE .CMP_82_TRUE
    LDD #0
    LBRA .CMP_82_END
.CMP_82_TRUE:
    LDD #1
.CMP_82_END:
    LBEQ .LOGIC_81_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    CMPD TMPVAL
    LBEQ .CMP_83_TRUE
    LDD #0
    LBRA .CMP_83_END
.CMP_83_TRUE:
    LDD #1
.CMP_83_END:
    LBEQ .LOGIC_81_FALSE
    LDD #1
    LBRA .LOGIC_81_END
.LOGIC_81_FALSE:
    LDD #0
.LOGIC_81_END:
    LBEQ IF_NEXT_84
    LDD #1  ; const ROOM_WORKSHOP
    STD VAR_ARG0
    JSR ENTER_ROOM
    LBRA IF_END_83
IF_NEXT_84:
IF_END_83:
    LBRA IF_END_62
IF_END_62:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    CMPD TMPVAL
    LBGT .CMP_84_TRUE
    LDD #0
    LBRA .CMP_84_END
.CMP_84_TRUE:
    LDD #1
.CMP_84_END:
    LBEQ IF_NEXT_86
    LDD >VAR_MSG_TIMER
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_MSG_TIMER
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    CMPD TMPVAL
    LBEQ .CMP_86_TRUE
    LDD #0
    LBRA .CMP_86_END
.CMP_86_TRUE:
    LDD #1
.CMP_86_END:
    LBEQ .LOGIC_85_FALSE
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ROOM_EXIT
    CMPD TMPVAL
    LBEQ .CMP_87_TRUE
    LDD #0
    LBRA .CMP_87_END
.CMP_87_TRUE:
    LDD #1
.CMP_87_END:
    LBEQ .LOGIC_85_FALSE
    LDD #1
    LBRA .LOGIC_85_END
.LOGIC_85_FALSE:
    LDD #0
.LOGIC_85_END:
    LBEQ IF_NEXT_88
    LDD #0
    STD VAR_ROOM_EXIT
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAGS_B
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #16  ; const FL_EXIT_TESTAMENT
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    CMPD TMPVAL
    LBNE .CMP_88_TRUE
    LDD #0
    LBRA .CMP_88_END
.CMP_88_TRUE:
    LDD #1
.CMP_88_END:
    LBEQ IF_NEXT_90
    LDD >VAR_FLAGS_B
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #239
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    STD VAR_FLAGS_B
    LDD #-110
    STD VAR_TESTAMENT_Y
    LDD #0
    STD VAR_TESTAMENT_PAGE
    LDD #4  ; const STATE_TESTAMENT
    STD VAR_SCREEN
    LBRA IF_END_89
IF_NEXT_90:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAGS_B
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #32  ; const FL_EXIT_ENDING
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    CMPD TMPVAL
    LBNE .CMP_89_TRUE
    LDD #0
    LBRA .CMP_89_END
.CMP_89_TRUE:
    LDD #1
.CMP_89_END:
    LBEQ IF_NEXT_91
    LDD >VAR_FLAGS_B
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #223
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    STD VAR_FLAGS_B
    LDD #-110
    STD VAR_ENDING_Y
    LDD #3  ; const STATE_ENDING
    STD VAR_SCREEN
    LBRA IF_END_89
IF_NEXT_91:
    LDD >VAR_EXIT_ROOM_TARGET
    STD VAR_ARG0
    JSR ENTER_ROOM
IF_END_89:
    LBRA IF_END_87
IF_NEXT_88:
IF_END_87:
    LBRA IF_END_85
IF_NEXT_86:
IF_END_85:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN3_FIRED
    CMPD TMPVAL
    LBEQ .CMP_90_TRUE
    LDD #0
    LBRA .CMP_90_END
.CMP_90_TRUE:
    LDD #1
.CMP_90_END:
    LBEQ IF_NEXT_93
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SHOW_INVENTORY
    CMPD TMPVAL
    LBEQ .CMP_91_TRUE
    LDD #0
    LBRA .CMP_91_END
.CMP_91_TRUE:
    LDD #1
.CMP_91_END:
    LBEQ IF_NEXT_95
    LDD >VAR_INV_CURSOR
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_INV_CURSOR
    LDD #8  ; const ITEM_COUNT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INV_CURSOR
    CMPD TMPVAL
    LBGE .CMP_92_TRUE
    LDD #0
    LBRA .CMP_92_END
.CMP_92_TRUE:
    LDD #1
.CMP_92_END:
    LBEQ IF_NEXT_97
    LDD #0
    STD VAR_INV_CURSOR
    LBRA IF_END_96
IF_NEXT_97:
IF_END_96:
    LBRA IF_END_94
IF_NEXT_95:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    CMPD TMPVAL
    LBEQ .CMP_93_TRUE
    LDD #0
    LBRA .CMP_93_END
.CMP_93_TRUE:
    LDD #1
.CMP_93_END:
    LBEQ IF_END_94
    LDD #3  ; const VERB_GIVE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_94_TRUE
    LDD #0
    LBRA .CMP_94_END
.CMP_94_TRUE:
    LDD #1
.CMP_94_END:
    LBEQ IF_NEXT_99
    LDD #0  ; const VERB_EXAMINE
    STD VAR_CURRENT_VERB
    LBRA IF_END_98
IF_NEXT_99:
    LDD >VAR_CURRENT_VERB
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_CURRENT_VERB
IF_END_98:
    LBRA IF_END_94
IF_END_94:
    LBRA IF_END_92
IF_NEXT_93:
IF_END_92:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN1_FIRED
    CMPD TMPVAL
    LBEQ .CMP_95_TRUE
    LDD #0
    LBRA .CMP_95_END
.CMP_95_TRUE:
    LDD #1
.CMP_95_END:
    LBEQ IF_NEXT_101
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SHOW_INVENTORY
    CMPD TMPVAL
    LBEQ .CMP_96_TRUE
    LDD #0
    LBRA .CMP_96_END
.CMP_96_TRUE:
    LDD #1
.CMP_96_END:
    LBEQ IF_NEXT_103
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD >VAR_INV_CURSOR
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_97_TRUE
    LDD #0
    LBRA .CMP_97_END
.CMP_97_TRUE:
    LDD #1
.CMP_97_END:
    LBEQ IF_NEXT_105
    LDD >VAR_INV_CURSOR
    STD VAR_ACTIVE_ITEM
    LBRA IF_END_104
IF_NEXT_105:
IF_END_104:
    LDD #0
    STD VAR_SHOW_INVENTORY
    LBRA IF_END_102
IF_NEXT_103:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    CMPD TMPVAL
    LBGT .CMP_98_TRUE
    LDD #0
    LBRA .CMP_98_END
.CMP_98_TRUE:
    LDD #1
.CMP_98_END:
    LBEQ IF_NEXT_106
    LDD #0
    STD VAR_MSG_TIMER
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ROOM_EXIT
    CMPD TMPVAL
    LBEQ .CMP_99_TRUE
    LDD #0
    LBRA .CMP_99_END
.CMP_99_TRUE:
    LDD #1
.CMP_99_END:
    LBEQ IF_NEXT_108
    LDD #0
    STD VAR_ROOM_EXIT
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAGS_B
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #16  ; const FL_EXIT_TESTAMENT
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    CMPD TMPVAL
    LBNE .CMP_100_TRUE
    LDD #0
    LBRA .CMP_100_END
.CMP_100_TRUE:
    LDD #1
.CMP_100_END:
    LBEQ IF_NEXT_110
    LDD >VAR_FLAGS_B
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #239
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    STD VAR_FLAGS_B
    LDD #-110
    STD VAR_TESTAMENT_Y
    LDD #0
    STD VAR_TESTAMENT_PAGE
    LDD #4  ; const STATE_TESTAMENT
    STD VAR_SCREEN
    LBRA IF_END_109
IF_NEXT_110:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAGS_B
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #32  ; const FL_EXIT_ENDING
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    CMPD TMPVAL
    LBNE .CMP_101_TRUE
    LDD #0
    LBRA .CMP_101_END
.CMP_101_TRUE:
    LDD #1
.CMP_101_END:
    LBEQ IF_NEXT_111
    LDD >VAR_FLAGS_B
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #223
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    STD VAR_FLAGS_B
    LDD #3  ; const STATE_ENDING
    STD VAR_SCREEN
    LBRA IF_END_109
IF_NEXT_111:
    LDD >VAR_EXIT_ROOM_TARGET
    STD VAR_ARG0
    JSR ENTER_ROOM
IF_END_109:
    LBRA IF_END_107
IF_NEXT_108:
IF_END_107:
    LBRA IF_END_102
IF_NEXT_106:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_NEAR_HS
    CMPD TMPVAL
    LBGE .CMP_102_TRUE
    LDD #0
    LBRA .CMP_102_END
.CMP_102_TRUE:
    LDD #1
.CMP_102_END:
    LBEQ IF_END_102
    LDD #0  ; const ROOM_ENTRANCE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_ROOM
    CMPD TMPVAL
    LBEQ .CMP_103_TRUE
    LDD #0
    LBRA .CMP_103_END
.CMP_103_TRUE:
    LDD #1
.CMP_103_END:
    LBEQ IF_NEXT_113
    LDD >VAR_NEAR_HS
    STD VAR_ARG0
    JSR TRAMP_INTERACT_ENTRANCE  ; cross-bank trampoline (bank #1 -> bank #0)
    LBRA IF_END_112
IF_NEXT_113:
    LDD #1  ; const ROOM_WORKSHOP
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_ROOM
    CMPD TMPVAL
    LBEQ .CMP_104_TRUE
    LDD #0
    LBRA .CMP_104_END
.CMP_104_TRUE:
    LDD #1
.CMP_104_END:
    LBEQ IF_NEXT_114
    LDD >VAR_NEAR_HS
    STD VAR_ARG0
    JSR TRAMP_INTERACT_WORKSHOP  ; cross-bank trampoline (bank #1 -> bank #0)
    LBRA IF_END_112
IF_NEXT_114:
    LDD #2  ; const ROOM_ANTEROOM
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_ROOM
    CMPD TMPVAL
    LBEQ .CMP_105_TRUE
    LDD #0
    LBRA .CMP_105_END
.CMP_105_TRUE:
    LDD #1
.CMP_105_END:
    LBEQ IF_NEXT_115
    LDD >VAR_NEAR_HS
    STD VAR_ARG0
    JSR TRAMP_INTERACT_ANTEROOM  ; cross-bank trampoline (bank #1 -> bank #0)
    LBRA IF_END_112
IF_NEXT_115:
    LDD #3  ; const ROOM_WEIGHTS
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_ROOM
    CMPD TMPVAL
    LBEQ .CMP_106_TRUE
    LDD #0
    LBRA .CMP_106_END
.CMP_106_TRUE:
    LDD #1
.CMP_106_END:
    LBEQ IF_NEXT_116
    LDD >VAR_NEAR_HS
    STD VAR_ARG0
    JSR TRAMP_INTERACT_WEIGHTS  ; cross-bank trampoline (bank #1 -> bank #0)
    LBRA IF_END_112
IF_NEXT_116:
    LDD #4  ; const ROOM_OPTICS
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_ROOM
    CMPD TMPVAL
    LBEQ .CMP_107_TRUE
    LDD #0
    LBRA .CMP_107_END
.CMP_107_TRUE:
    LDD #1
.CMP_107_END:
    LBEQ IF_NEXT_117
    LDD >VAR_NEAR_HS
    STD VAR_ARG0
    JSR INTERACT_OPTICS
    LBRA IF_END_112
IF_NEXT_117:
    LDD #5  ; const ROOM_CONSERVATORY
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_ROOM
    CMPD TMPVAL
    LBEQ .CMP_108_TRUE
    LDD #0
    LBRA .CMP_108_END
.CMP_108_TRUE:
    LDD #1
.CMP_108_END:
    LBEQ IF_NEXT_118
    LDD >VAR_NEAR_HS
    STD VAR_ARG0
    JSR TRAMP_INTERACT_CONSERVATORY  ; cross-bank trampoline (bank #1 -> bank #0)
    LBRA IF_END_112
IF_NEXT_118:
    LDD #6  ; const ROOM_VAULT_CORRIDOR
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_ROOM
    CMPD TMPVAL
    LBEQ .CMP_109_TRUE
    LDD #0
    LBRA .CMP_109_END
.CMP_109_TRUE:
    LDD #1
.CMP_109_END:
    LBEQ IF_END_112
    LDD >VAR_NEAR_HS
    STD VAR_ARG0
    JSR TRAMP_INTERACT_VAULT  ; cross-bank trampoline (bank #1 -> bank #0)
    LBRA IF_END_112
IF_END_112:
    LBRA IF_END_102
IF_END_102:
    LBRA IF_END_100
IF_NEXT_101:
IF_END_100:
    RTS

; Function: CHECK_ENTRANCE_HOTSPOTS (Bank #1)
CHECK_ENTRANCE_HOTSPOTS:
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_ENT_HS_X_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DX
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_ENT_HS_Y_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DY
    LDX #ARRAY_ENT_HS_W_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DX
    TSTA           ; Test sign bit
    BPL .ABS_2_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_2_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_111_TRUE
    LDD #0
    LBRA .CMP_111_END
.CMP_111_TRUE:
    LDD #1
.CMP_111_END:
    LBEQ .LOGIC_110_FALSE
    LDX #ARRAY_ENT_HS_H_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DY
    TSTA           ; Test sign bit
    BPL .ABS_3_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_3_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_112_TRUE
    LDD #0
    LBRA .CMP_112_END
.CMP_112_TRUE:
    LDD #1
.CMP_112_END:
    LBEQ .LOGIC_110_FALSE
    LDD #1
    LBRA .LOGIC_110_END
.LOGIC_110_FALSE:
    LDD #0
.LOGIC_110_END:
    LBEQ IF_NEXT_120
    LDD #0
    STD VAR_NEAR_HS
    LBRA IF_END_119
IF_NEXT_120:
IF_END_119:
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_ENT_HS_X_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DX
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_ENT_HS_Y_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DY
    LDX #ARRAY_ENT_HS_W_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DX
    TSTA           ; Test sign bit
    BPL .ABS_4_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_4_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_114_TRUE
    LDD #0
    LBRA .CMP_114_END
.CMP_114_TRUE:
    LDD #1
.CMP_114_END:
    LBEQ .LOGIC_113_FALSE
    LDX #ARRAY_ENT_HS_H_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DY
    TSTA           ; Test sign bit
    BPL .ABS_5_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_5_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_115_TRUE
    LDD #0
    LBRA .CMP_115_END
.CMP_115_TRUE:
    LDD #1
.CMP_115_END:
    LBEQ .LOGIC_113_FALSE
    LDD #1
    LBRA .LOGIC_113_END
.LOGIC_113_FALSE:
    LDD #0
.LOGIC_113_END:
    LBEQ IF_NEXT_122
    LDD #1
    STD VAR_NEAR_HS
    LBRA IF_END_121
IF_NEXT_122:
IF_END_121:
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_ENT_HS_X_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DX
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_ENT_HS_Y_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DY
    LDX #ARRAY_ENT_HS_W_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DX
    TSTA           ; Test sign bit
    BPL .ABS_6_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_6_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_117_TRUE
    LDD #0
    LBRA .CMP_117_END
.CMP_117_TRUE:
    LDD #1
.CMP_117_END:
    LBEQ .LOGIC_116_FALSE
    LDX #ARRAY_ENT_HS_H_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DY
    TSTA           ; Test sign bit
    BPL .ABS_7_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_7_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_118_TRUE
    LDD #0
    LBRA .CMP_118_END
.CMP_118_TRUE:
    LDD #1
.CMP_118_END:
    LBEQ .LOGIC_116_FALSE
    LDD #1
    LBRA .LOGIC_116_END
.LOGIC_116_FALSE:
    LDD #0
.LOGIC_116_END:
    LBEQ IF_NEXT_124
    LDD #2
    STD VAR_NEAR_HS
    LBRA IF_END_123
IF_NEXT_124:
IF_END_123:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAGS_A
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #2  ; const FL_TALLER_OPEN
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    CMPD TMPVAL
    LBNE .CMP_119_TRUE
    LDD #0
    LBRA .CMP_119_END
.CMP_119_TRUE:
    LDD #1
.CMP_119_END:
    LBEQ IF_NEXT_126
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_ENT_HS_X_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DX
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_ENT_HS_Y_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DY
    LDX #ARRAY_ENT_HS_W_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DX
    TSTA           ; Test sign bit
    BPL .ABS_8_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_8_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_121_TRUE
    LDD #0
    LBRA .CMP_121_END
.CMP_121_TRUE:
    LDD #1
.CMP_121_END:
    LBEQ .LOGIC_120_FALSE
    LDX #ARRAY_ENT_HS_H_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DY
    TSTA           ; Test sign bit
    BPL .ABS_9_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_9_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_122_TRUE
    LDD #0
    LBRA .CMP_122_END
.CMP_122_TRUE:
    LDD #1
.CMP_122_END:
    LBEQ .LOGIC_120_FALSE
    LDD #1
    LBRA .LOGIC_120_END
.LOGIC_120_FALSE:
    LDD #0
.LOGIC_120_END:
    LBEQ IF_NEXT_128
    LDD #3
    STD VAR_NEAR_HS
    LBRA IF_END_127
IF_NEXT_128:
IF_END_127:
    LBRA IF_END_125
IF_NEXT_126:
IF_END_125:
    RTS

; Function: CHECK_ANTEROOM_HOTSPOTS (Bank #1)
CHECK_ANTEROOM_HOTSPOTS:
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_ANT_HS_X_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DX
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_ANT_HS_Y_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DY
    LDX #ARRAY_ANT_HS_W_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DX
    TSTA           ; Test sign bit
    BPL .ABS_24_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_24_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_150_TRUE
    LDD #0
    LBRA .CMP_150_END
.CMP_150_TRUE:
    LDD #1
.CMP_150_END:
    LBEQ .LOGIC_149_FALSE
    LDX #ARRAY_ANT_HS_H_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DY
    TSTA           ; Test sign bit
    BPL .ABS_25_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_25_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_151_TRUE
    LDD #0
    LBRA .CMP_151_END
.CMP_151_TRUE:
    LDD #1
.CMP_151_END:
    LBEQ .LOGIC_149_FALSE
    LDD #1
    LBRA .LOGIC_149_END
.LOGIC_149_FALSE:
    LDD #0
.LOGIC_149_END:
    LBEQ IF_NEXT_148
    LDD #0
    STD VAR_NEAR_HS
    LBRA IF_END_147
IF_NEXT_148:
IF_END_147:
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_ANT_HS_X_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DX
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_ANT_HS_Y_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DY
    LDX #ARRAY_ANT_HS_W_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DX
    TSTA           ; Test sign bit
    BPL .ABS_26_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_26_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_153_TRUE
    LDD #0
    LBRA .CMP_153_END
.CMP_153_TRUE:
    LDD #1
.CMP_153_END:
    LBEQ .LOGIC_152_FALSE
    LDX #ARRAY_ANT_HS_H_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DY
    TSTA           ; Test sign bit
    BPL .ABS_27_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_27_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_154_TRUE
    LDD #0
    LBRA .CMP_154_END
.CMP_154_TRUE:
    LDD #1
.CMP_154_END:
    LBEQ .LOGIC_152_FALSE
    LDD #1
    LBRA .LOGIC_152_END
.LOGIC_152_FALSE:
    LDD #0
.LOGIC_152_END:
    LBEQ IF_NEXT_150
    LDD #1
    STD VAR_NEAR_HS
    LBRA IF_END_149
IF_NEXT_150:
IF_END_149:
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_ANT_HS_X_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DX
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_ANT_HS_Y_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DY
    LDX #ARRAY_ANT_HS_W_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DX
    TSTA           ; Test sign bit
    BPL .ABS_28_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_28_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_156_TRUE
    LDD #0
    LBRA .CMP_156_END
.CMP_156_TRUE:
    LDD #1
.CMP_156_END:
    LBEQ .LOGIC_155_FALSE
    LDX #ARRAY_ANT_HS_H_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DY
    TSTA           ; Test sign bit
    BPL .ABS_29_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_29_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_157_TRUE
    LDD #0
    LBRA .CMP_157_END
.CMP_157_TRUE:
    LDD #1
.CMP_157_END:
    LBEQ .LOGIC_155_FALSE
    LDD #1
    LBRA .LOGIC_155_END
.LOGIC_155_FALSE:
    LDD #0
.LOGIC_155_END:
    LBEQ IF_NEXT_152
    LDD #2
    STD VAR_NEAR_HS
    LBRA IF_END_151
IF_NEXT_152:
IF_END_151:
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_ANT_HS_X_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DX
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_ANT_HS_Y_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DY
    LDX #ARRAY_ANT_HS_W_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DX
    TSTA           ; Test sign bit
    BPL .ABS_30_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_30_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_159_TRUE
    LDD #0
    LBRA .CMP_159_END
.CMP_159_TRUE:
    LDD #1
.CMP_159_END:
    LBEQ .LOGIC_158_FALSE
    LDX #ARRAY_ANT_HS_H_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DY
    TSTA           ; Test sign bit
    BPL .ABS_31_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_31_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_160_TRUE
    LDD #0
    LBRA .CMP_160_END
.CMP_160_TRUE:
    LDD #1
.CMP_160_END:
    LBEQ .LOGIC_158_FALSE
    LDD #1
    LBRA .LOGIC_158_END
.LOGIC_158_FALSE:
    LDD #0
.LOGIC_158_END:
    LBEQ IF_NEXT_154
    LDD #3
    STD VAR_NEAR_HS
    LBRA IF_END_153
IF_NEXT_154:
IF_END_153:
    RTS

; Function: CHECK_OPTICS_HOTSPOTS (Bank #1)
CHECK_OPTICS_HOTSPOTS:
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_OPT_HS_X_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DX
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_OPT_HS_Y_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DY
    LDX #ARRAY_OPT_HS_W_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DX
    TSTA           ; Test sign bit
    BPL .ABS_36_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_36_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_168_TRUE
    LDD #0
    LBRA .CMP_168_END
.CMP_168_TRUE:
    LDD #1
.CMP_168_END:
    LBEQ .LOGIC_167_FALSE
    LDX #ARRAY_OPT_HS_H_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DY
    TSTA           ; Test sign bit
    BPL .ABS_37_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_37_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_169_TRUE
    LDD #0
    LBRA .CMP_169_END
.CMP_169_TRUE:
    LDD #1
.CMP_169_END:
    LBEQ .LOGIC_167_FALSE
    LDD #1
    LBRA .LOGIC_167_END
.LOGIC_167_FALSE:
    LDD #0
.LOGIC_167_END:
    LBEQ IF_NEXT_160
    LDD #0
    STD VAR_NEAR_HS
    LBRA IF_END_159
IF_NEXT_160:
IF_END_159:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAGS_A
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #64  ; const FL_OPTICS_SOLVED
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    CMPD TMPVAL
    LBNE .CMP_170_TRUE
    LDD #0
    LBRA .CMP_170_END
.CMP_170_TRUE:
    LDD #1
.CMP_170_END:
    LBEQ IF_NEXT_162
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_OPT_HS_X_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DX
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_OPT_HS_Y_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DY
    LDX #ARRAY_OPT_HS_W_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DX
    TSTA           ; Test sign bit
    BPL .ABS_38_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_38_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_172_TRUE
    LDD #0
    LBRA .CMP_172_END
.CMP_172_TRUE:
    LDD #1
.CMP_172_END:
    LBEQ .LOGIC_171_FALSE
    LDX #ARRAY_OPT_HS_H_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DY
    TSTA           ; Test sign bit
    BPL .ABS_39_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_39_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_173_TRUE
    LDD #0
    LBRA .CMP_173_END
.CMP_173_TRUE:
    LDD #1
.CMP_173_END:
    LBEQ .LOGIC_171_FALSE
    LDD #1
    LBRA .LOGIC_171_END
.LOGIC_171_FALSE:
    LDD #0
.LOGIC_171_END:
    LBEQ IF_NEXT_164
    LDD #1
    STD VAR_NEAR_HS
    LBRA IF_END_163
IF_NEXT_164:
IF_END_163:
    LBRA IF_END_161
IF_NEXT_162:
IF_END_161:
    RTS

; Function: CHECK_CONSERVATORY_HOTSPOTS (Bank #1)
CHECK_CONSERVATORY_HOTSPOTS:
    LDD >VAR_PLAYER_X
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_CONS_HS_X_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DX
    LDD >VAR_PLAYER_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_CONS_HS_Y_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_DY
    LDX #ARRAY_CONS_HS_W_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DX
    TSTA           ; Test sign bit
    BPL .ABS_40_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_40_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_175_TRUE
    LDD #0
    LBRA .CMP_175_END
.CMP_175_TRUE:
    LDD #1
.CMP_175_END:
    LBEQ .LOGIC_174_FALSE
    LDX #ARRAY_CONS_HS_H_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DY
    TSTA           ; Test sign bit
    BPL .ABS_41_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_41_POS:
    STD RESULT
    CMPD TMPVAL
    LBLE .CMP_176_TRUE
    LDD #0
    LBRA .CMP_176_END
.CMP_176_TRUE:
    LDD #1
.CMP_176_END:
    LBEQ .LOGIC_174_FALSE
    LDD #1
    LBRA .LOGIC_174_END
.LOGIC_174_FALSE:
    LDD #0
.LOGIC_174_END:
    LBEQ IF_NEXT_166
    LDD #0
    STD VAR_NEAR_HS
    LBRA IF_END_165
IF_NEXT_166:
IF_END_165:
    RTS

; Function: INTERACT_OPTICS (Bank #1)
INTERACT_OPTICS:
    LDD #0  ; const OPT_HS_PEDESTAL
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_267_TRUE
    LDD #0
    LBRA .CMP_267_END
.CMP_267_TRUE:
    LDD #1
.CMP_267_END:
    LBEQ IF_NEXT_271
    LDD #0  ; const VERB_EXAMINE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_268_TRUE
    LDD #0
    LBRA .CMP_268_END
.CMP_268_TRUE:
    LDD #1
.CMP_268_END:
    LBEQ IF_NEXT_273
    LDD #17
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_272
IF_NEXT_273:
    LDD #2  ; const VERB_USE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_269_TRUE
    LDD #0
    LBRA .CMP_269_END
.CMP_269_TRUE:
    LDD #1
.CMP_269_END:
    LBEQ IF_NEXT_274
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAGS_A
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #64  ; const FL_OPTICS_SOLVED
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    CMPD TMPVAL
    LBNE .CMP_270_TRUE
    LDD #0
    LBRA .CMP_270_END
.CMP_270_TRUE:
    LDD #1
.CMP_270_END:
    LBEQ IF_NEXT_276
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_275
IF_NEXT_276:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #2  ; const ITEM_PRISM
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_271_TRUE
    LDD #0
    LBRA .CMP_271_END
.CMP_271_TRUE:
    LDD #1
.CMP_271_END:
    LBEQ IF_NEXT_277
    LDD >VAR_FLAGS_A
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #64  ; const FL_OPTICS_SOLVED
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ORA TMPPTR2     ; A OR TMPPTR2+0 (high byte)
    ORB TMPPTR2+1   ; B OR TMPPTR2+1 (low byte)
    STD VAR_FLAGS_A
    LDD #2  ; const ITEM_PRISM
    STD VAR_ARG0
    JSR TRAMP_DROP_ITEM  ; cross-bank trampoline (bank #1 -> bank #0)
    LDD #19
    STD VAR_MSG_ID
    LDD #200
    STD VAR_MSG_TIMER
    ; PLAY_SFX("puzzle_success") - play SFX asset (index=4)
    LDX #4        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    JSR TRAMP_ACCELERATE_HEARTBEAT  ; cross-bank trampoline (bank #1 -> bank #0)
    LBRA IF_END_275
IF_NEXT_277:
    LDD #18
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
IF_END_275:
    LBRA IF_END_272
IF_NEXT_274:
    LDD #1  ; const VERB_TAKE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_272_TRUE
    LDD #0
    LBRA .CMP_272_END
.CMP_272_TRUE:
    LDD #1
.CMP_272_END:
    LBEQ IF_END_272
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_272
IF_END_272:
    LBRA IF_END_270
IF_NEXT_271:
    LDD #1  ; const OPT_HS_COMPARTMENT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    CMPD TMPVAL
    LBEQ .CMP_273_TRUE
    LDD #0
    LBRA .CMP_273_END
.CMP_273_TRUE:
    LDD #1
.CMP_273_END:
    LBEQ IF_END_270
    LDD #0  ; const VERB_EXAMINE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_274_TRUE
    LDD #0
    LBRA .CMP_274_END
.CMP_274_TRUE:
    LDD #1
.CMP_274_END:
    LBEQ IF_NEXT_279
    LDD #20
    STD VAR_MSG_ID
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_278
IF_NEXT_279:
    LDD #1  ; const VERB_TAKE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_275_TRUE
    LDD #0
    LBRA .CMP_275_END
.CMP_275_TRUE:
    LDD #1
.CMP_275_END:
    LBEQ IF_NEXT_280
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #4  ; const ITEM_EYE
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_276_TRUE
    LDD #0
    LBRA .CMP_276_END
.CMP_276_TRUE:
    LDD #1
.CMP_276_END:
    LBEQ IF_NEXT_282
    LDD #4  ; const ITEM_EYE
    STD VAR_ARG0
    JSR PICKUP_ITEM
    LDD #21
    STD VAR_MSG_ID
    LDD #140
    STD VAR_MSG_TIMER
    LBRA IF_END_281
IF_NEXT_282:
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
IF_END_281:
    LBRA IF_END_278
IF_NEXT_280:
    LDD #2  ; const VERB_USE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_277_TRUE
    LDD #0
    LBRA .CMP_277_END
.CMP_277_TRUE:
    LDD #1
.CMP_277_END:
    LBEQ IF_END_278
    LDD #5
    STD VAR_MSG_ID
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_278
IF_END_278:
    LBRA IF_END_270
IF_END_270:
    RTS

; Function: DRAW_VERB_INDICATOR (Bank #1)
DRAW_VERB_INDICATOR:
    LDD #0  ; const VERB_EXAMINE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_321_TRUE
    LDD #0
    LBRA .CMP_321_END
.CMP_321_TRUE:
    LDD #1
.CMP_321_END:
    LBEQ IF_NEXT_341
    ; PRINT_TEXT: Print text at position
    LDD #-42
    STD VAR_ARG0
    LDD #127
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_63819514689      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_340
IF_NEXT_341:
    LDD #1  ; const VERB_TAKE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_322_TRUE
    LDD #0
    LBRA .CMP_322_END
.CMP_322_TRUE:
    LDD #1
.CMP_322_END:
    LBEQ IF_NEXT_342
    ; PRINT_TEXT: Print text at position
    LDD #-28
    STD VAR_ARG0
    LDD #127
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2567303      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_340
IF_NEXT_342:
    LDD #2  ; const VERB_USE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_323_TRUE
    LDD #0
    LBRA .CMP_323_END
.CMP_323_TRUE:
    LDD #1
.CMP_323_END:
    LBEQ IF_NEXT_343
    ; PRINT_TEXT: Print text at position
    LDD #-21
    STD VAR_ARG0
    LDD #127
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_84327      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_340
IF_NEXT_343:
    LDD #3  ; const VERB_GIVE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    CMPD TMPVAL
    LBEQ .CMP_324_TRUE
    LDD #0
    LBRA .CMP_324_END
.CMP_324_TRUE:
    LDD #1
.CMP_324_END:
    LBEQ IF_END_340
    LDD #-1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ACTIVE_ITEM
    CMPD TMPVAL
    LBEQ .CMP_325_TRUE
    LDD #0
    LBRA .CMP_325_END
.CMP_325_TRUE:
    LDD #1
.CMP_325_END:
    LBEQ IF_NEXT_345
    ; PRINT_TEXT: Print text at position
    LDD #-28
    STD VAR_ARG0
    LDD #127
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2188049      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_344
IF_NEXT_345:
    LDD #0  ; const ITEM_LENS
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ACTIVE_ITEM
    CMPD TMPVAL
    LBEQ .CMP_326_TRUE
    LDD #0
    LBRA .CMP_326_END
.CMP_326_TRUE:
    LDD #1
.CMP_326_END:
    LBEQ IF_NEXT_346
    ; PRINT_TEXT: Print text at position
    LDD #-49
    STD VAR_ARG0
    LDD #127
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_62642041113543      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_344
IF_NEXT_346:
    LDD #1  ; const ITEM_GEAR
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ACTIVE_ITEM
    CMPD TMPVAL
    LBEQ .CMP_327_TRUE
    LDD #0
    LBRA .CMP_327_END
.CMP_327_TRUE:
    LDD #1
.CMP_327_END:
    LBEQ IF_NEXT_347
    ; PRINT_TEXT: Print text at position
    LDD #-49
    STD VAR_ARG0
    LDD #127
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_62642040964184      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_344
IF_NEXT_347:
    LDD #2  ; const ITEM_PRISM
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ACTIVE_ITEM
    CMPD TMPVAL
    LBEQ .CMP_328_TRUE
    LDD #0
    LBRA .CMP_328_END
.CMP_328_TRUE:
    LDD #1
.CMP_328_END:
    LBEQ IF_NEXT_348
    ; PRINT_TEXT: Print text at position
    LDD #-56
    STD VAR_ARG0
    LDD #127
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_1941903278596472      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_344
IF_NEXT_348:
    LDD #3  ; const ITEM_BLANKET
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ACTIVE_ITEM
    CMPD TMPVAL
    LBEQ .CMP_329_TRUE
    LDD #0
    LBRA .CMP_329_END
.CMP_329_TRUE:
    LDD #1
.CMP_329_END:
    LBEQ IF_NEXT_349
    ; PRINT_TEXT: Print text at position
    LDD #-63
    STD VAR_ARG0
    LDD #127
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_1941903265492996      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_344
IF_NEXT_349:
    LDD #4  ; const ITEM_EYE
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ACTIVE_ITEM
    CMPD TMPVAL
    LBEQ .CMP_330_TRUE
    LDD #0
    LBRA .CMP_330_END
.CMP_330_TRUE:
    LDD #1
.CMP_330_END:
    LBEQ IF_NEXT_350
    ; PRINT_TEXT: Print text at position
    LDD #-42
    STD VAR_ARG0
    LDD #127
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2020710997544      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_344
IF_NEXT_350:
    LDD #5  ; const ITEM_OIL
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ACTIVE_ITEM
    CMPD TMPVAL
    LBEQ .CMP_331_TRUE
    LDD #0
    LBRA .CMP_331_END
.CMP_331_TRUE:
    LDD #1
.CMP_331_END:
    LBEQ IF_NEXT_351
    ; PRINT_TEXT: Print text at position
    LDD #-42
    STD VAR_ARG0
    LDD #127
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2020711006665      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_344
IF_NEXT_351:
    LDD #6  ; const ITEM_SHEET
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ACTIVE_ITEM
    CMPD TMPVAL
    LBEQ .CMP_332_TRUE
    LDD #0
    LBRA .CMP_332_END
.CMP_332_TRUE:
    LDD #1
.CMP_332_END:
    LBEQ IF_NEXT_352
    ; PRINT_TEXT: Print text at position
    LDD #-56
    STD VAR_ARG0
    LDD #127
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_1941903281064854      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_344
IF_NEXT_352:
    LDD #7  ; const ITEM_KEY
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ACTIVE_ITEM
    CMPD TMPVAL
    LBEQ .CMP_333_TRUE
    LDD #0
    LBRA .CMP_333_END
.CMP_333_TRUE:
    LDD #1
.CMP_333_END:
    LBEQ IF_END_344
    ; PRINT_TEXT: Print text at position
    LDD #-42
    STD VAR_ARG0
    LDD #127
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2020711002710      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_344
IF_END_344:
    LBRA IF_END_340
IF_END_340:
    RTS

; Function: PICKUP_ITEM (Bank #1)
PICKUP_ITEM:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD >VAR_ARG0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD TMPVAL
    LBEQ .CMP_334_TRUE
    LDD #0
    LBRA .CMP_334_END
.CMP_334_TRUE:
    LDD #1
.CMP_334_END:
    LBEQ IF_NEXT_354
    LDD >VAR_ARG0
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_INV_ITEMS_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDD #1
    LDX TMPPTR2     ; Load computed address
    STD ,X          ; Store 16-bit value
    LDD >VAR_INV_COUNT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_INV_COUNT
    LDD >VAR_INV_WEIGHT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_ITEM_WEIGHT_DATA  ; Array base
    LDD >VAR_ARG0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_INV_WEIGHT
    ; PLAY_SFX("item_pickup") - play SFX asset (index=2)
    LDX #2        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_353
IF_NEXT_354:
IF_END_353:
    RTS

; Function: DRAW_TESTAMENT (Bank #1)
DRAW_TESTAMENT:
    LDD #7
    STD TMPPTR2     ; Save n (TMPPTR2+1 = n)
    NEGB            ; B = -n -> TEXT_SCALE_H
    STB >TEXT_SCALE_H
    LDB TMPPTR2+1   ; Reload n (from TMPPTR2, not RESULT)
    ASLB            ; n*2
    ASLB            ; n*4
    ASLB            ; n*8
    ADDB TMPPTR2+1  ; n*8 + n = n*9 -> TEXT_SCALE_W
    STB >TEXT_SCALE_W
    LDD >VAR_TESTAMENT_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_TESTAMENT_Y
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_TESTAMENT_PAGE
    CMPD TMPVAL
    LBEQ .CMP_353_TRUE
    LDD #0
    LBRA .CMP_353_END
.CMP_353_TRUE:
    LDD #1
.CMP_353_END:
    LBEQ IF_NEXT_392
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD VAR_ARG0
    LDD >VAR_TESTAMENT_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #15
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_12694600541101677361      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-84
    STD VAR_ARG0
    LDD >VAR_TESTAMENT_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #15
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_3054387366258387060      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_391
IF_NEXT_392:
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_TESTAMENT_PAGE
    CMPD TMPVAL
    LBEQ .CMP_354_TRUE
    LDD #0
    LBRA .CMP_354_END
.CMP_354_TRUE:
    LDD #1
.CMP_354_END:
    LBEQ IF_END_391
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD VAR_ARG0
    LDD >VAR_TESTAMENT_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #15
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_14476289871539234619      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-84
    STD VAR_ARG0
    LDD >VAR_TESTAMENT_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #15
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_15647433387823626580      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_391
IF_END_391:
    LDD #110
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_TESTAMENT_Y
    CMPD TMPVAL
    LBGT .CMP_355_TRUE
    LDD #0
    LBRA .CMP_355_END
.CMP_355_TRUE:
    LDD #1
.CMP_355_END:
    LBEQ IF_NEXT_394
    LDD >VAR_TESTAMENT_PAGE
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_TESTAMENT_PAGE
    LDD #-110
    STD VAR_TESTAMENT_Y
    LDD #2
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_TESTAMENT_PAGE
    CMPD TMPVAL
    LBGE .CMP_356_TRUE
    LDD #0
    LBRA .CMP_356_END
.CMP_356_TRUE:
    LDD #1
.CMP_356_END:
    LBEQ IF_NEXT_396
    LDD #3  ; const STATE_ENDING
    STD VAR_SCREEN
    LBRA IF_END_395
IF_NEXT_396:
IF_END_395:
    LBRA IF_END_393
IF_NEXT_394:
IF_END_393:
    RTS

; Function: DRAW_ENDING (Bank #1)
DRAW_ENDING:
    LDD #7
    STD TMPPTR2     ; Save n (TMPPTR2+1 = n)
    NEGB            ; B = -n -> TEXT_SCALE_H
    STB >TEXT_SCALE_H
    LDB TMPPTR2+1   ; Reload n (from TMPPTR2, not RESULT)
    ASLB            ; n*2
    ASLB            ; n*4
    ASLB            ; n*8
    ADDB TMPPTR2+1  ; n*8 + n = n*9 -> TEXT_SCALE_W
    STB >TEXT_SCALE_W
    LDD #50
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ENDING_Y
    CMPD TMPVAL
    LBLT .CMP_357_TRUE
    LDD #0
    LBRA .CMP_357_END
.CMP_357_TRUE:
    LDD #1
.CMP_357_END:
    LBEQ IF_NEXT_398
    LDD >VAR_ENDING_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ENDING_Y
    LBRA IF_END_397
IF_NEXT_398:
IF_END_397:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAGS_B
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #2  ; const FL_ELISA_HELPED
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    CMPD TMPVAL
    LBNE .CMP_359_TRUE
    LDD #0
    LBRA .CMP_359_END
.CMP_359_TRUE:
    LDD #1
.CMP_359_END:
    LBEQ .LOGIC_358_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAGS_B
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #4  ; const FL_HANS_HELPED
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    CMPD TMPVAL
    LBNE .CMP_360_TRUE
    LDD #0
    LBRA .CMP_360_END
.CMP_360_TRUE:
    LDD #1
.CMP_360_END:
    LBEQ .LOGIC_358_FALSE
    LDD #1
    LBRA .LOGIC_358_END
.LOGIC_358_FALSE:
    LDD #0
.LOGIC_358_END:
    LBEQ IF_NEXT_400
    ; SET_INTENSITY: Set drawing intensity
    LDD #110
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD VAR_ARG0
    LDD >VAR_ENDING_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #70
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_3688976395448209650      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #90
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD VAR_ARG0
    LDD >VAR_ENDING_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #50
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_4750152274843692088      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-84
    STD VAR_ARG0
    LDD >VAR_ENDING_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #30
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_17345789615299082788      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #70
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD VAR_ARG0
    LDD >VAR_ENDING_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #5
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2502506564742786359      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD VAR_ARG0
    LDD >VAR_ENDING_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #15
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_11654038037461762538      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-63
    STD VAR_ARG0
    LDD >VAR_ENDING_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #35
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_1863858565675      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-63
    STD VAR_ARG0
    LDD >VAR_ENDING_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #65
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_71091249681780729      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_399
IF_NEXT_400:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAGS_B
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #2  ; const FL_ELISA_HELPED
    STD TMPPTR2     ; Save right operand to TMPPTR2
    LDD TMPVAL      ; Get left from TMPVAL
    ANDA TMPPTR2    ; A AND TMPPTR2+0 (high byte)
    ANDB TMPPTR2+1  ; B AND TMPPTR2+1 (low byte)
    CMPD TMPVAL
    LBNE .CMP_361_TRUE
    LDD #0
    LBRA .CMP_361_END
.CMP_361_TRUE:
    LDD #1
.CMP_361_END:
    LBEQ IF_NEXT_401
    ; SET_INTENSITY: Set drawing intensity
    LDD #110
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD VAR_ARG0
    LDD >VAR_ENDING_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #70
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_1694552686414567337      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #90
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-84
    STD VAR_ARG0
    LDD >VAR_ENDING_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #50
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_894489252191113018      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD VAR_ARG0
    LDD >VAR_ENDING_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #30
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_18135904787860682873      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-56
    STD VAR_ARG0
    LDD >VAR_ENDING_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #10
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_70966799469806525      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #60
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD VAR_ARG0
    LDD >VAR_ENDING_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #15
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_17643359177242884552      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD VAR_ARG0
    LDD >VAR_ENDING_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #35
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_679393960477689362      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD VAR_ARG0
    LDD >VAR_ENDING_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #55
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_6586363433779781634      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-56
    STD VAR_ARG0
    LDD >VAR_ENDING_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #80
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_69586596903166      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_399
IF_NEXT_401:
    ; SET_INTENSITY: Set drawing intensity
    LDD #110
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-77
    STD VAR_ARG0
    LDD >VAR_ENDING_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #70
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_15031599020925928582      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #90
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD VAR_ARG0
    LDD >VAR_ENDING_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #50
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_8058628335699392711      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD VAR_ARG0
    LDD >VAR_ENDING_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #30
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_3134159664534957280      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-84
    STD VAR_ARG0
    LDD >VAR_ENDING_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #10
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_16762347117432342118      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #60
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD VAR_ARG0
    LDD >VAR_ENDING_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #15
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_17954386693183881976      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-84
    STD VAR_ARG0
    LDD >VAR_ENDING_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #35
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_6894498445181154440      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD VAR_ARG0
    LDD >VAR_ENDING_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #65
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_3443128850001289426      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
IF_END_399:
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-49
    STD VAR_ARG0
    LDD >VAR_ENDING_Y
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #95
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2376966947138      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD #50
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ENDING_Y
    CMPD TMPVAL
    LBGE .CMP_362_TRUE
    LDD #0
    LBRA .CMP_362_END
.CMP_362_TRUE:
    LDD #1
.CMP_362_END:
    LBEQ IF_NEXT_403
    ; SET_INTENSITY: Set drawing intensity
    LDD #50
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; Save for DRAW_VECTOR (BIOS Intensity_a will NOT touch this)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-84
    STD VAR_ARG0
    LDD #-90
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_15373067420087200981      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN1_FIRED
    CMPD TMPVAL
    LBEQ .CMP_363_TRUE
    LDD #0
    LBRA .CMP_363_END
.CMP_363_TRUE:
    LDD #1
.CMP_363_END:
    LBEQ IF_NEXT_405
    LDD #-110
    STD VAR_ENDING_Y
    LDD #0  ; const STATE_TITLE
    STD VAR_SCREEN
    LDD #1  ; const MUSIC_TITLE
    STD VAR_CURRENT_MUSIC
    ; PLAY_MUSIC("intro") - play music asset (index=1)
    LDX #1        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_404
IF_NEXT_405:
IF_END_404:
    LBRA IF_END_402
IF_NEXT_403:
IF_END_402:
    RTS

;***************************************************************************
; ASSETS IN BANK #1 (34 assets)
;***************************************************************************

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


; Generated from crypt_logo.vec (Malban Draw_Sync_List format)
; Total paths: 40, points: 169
; X bounds: min=-83, max=83, width=166
; Center: (0, 16)

_CRYPT_LOGO_WIDTH EQU 166
_CRYPT_LOGO_HALF_WIDTH EQU 83
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
    FCB 28              ; path0: intensity
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

; Generated from door_locked.vec (Malban Draw_Sync_List format)
; Total paths: 13, points: 59
; X bounds: min=-11, max=11, width=22
; Center: (0, 0)

_DOOR_LOCKED_WIDTH EQU 22
_DOOR_LOCKED_HALF_WIDTH EQU 11
_DOOR_LOCKED_CENTER_X EQU 0
_DOOR_LOCKED_CENTER_Y EQU 0

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
    FCB $E5,$F5,0,0        ; path0: header (y=-27, x=-11, relative to center)
    FCB $FF,$2D,$00          ; flag=-1, dy=45, dx=0
    FCB $FF,$08,$06          ; flag=-1, dy=8, dx=6
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$F8,$06          ; flag=-1, dy=-8, dx=6
    FCB $FF,$D3,$00          ; flag=-1, dy=-45, dx=0
    FCB $FF,$00,$EA          ; flag=-1, dy=0, dx=-22
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH1:    ; Path 1
    FCB 90              ; path1: intensity
    FCB $03,$F8,0,0        ; path1: header (y=3, x=-8, relative to center)
    FCB $FF,$0D,$00          ; flag=-1, dy=13, dx=0
    FCB $FF,$00,$10          ; flag=-1, dy=0, dx=16
    FCB $FF,$F3,$00          ; flag=-1, dy=-13, dx=0
    FCB $FF,$00,$F0          ; flag=-1, dy=0, dx=-16
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH2:    ; Path 2
    FCB 90              ; path2: intensity
    FCB $E8,$F8,0,0        ; path2: header (y=-24, x=-8, relative to center)
    FCB $FF,$14,$00          ; flag=-1, dy=20, dx=0
    FCB $FF,$00,$10          ; flag=-1, dy=0, dx=16
    FCB $FF,$EC,$00          ; flag=-1, dy=-20, dx=0
    FCB $FF,$00,$F0          ; flag=-1, dy=0, dx=-16
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH3:    ; Path 3
    FCB 70              ; path3: intensity
    FCB $E5,$00,0,0        ; path3: header (y=-27, x=0, relative to center)
    FCB $FF,$35,$00          ; flag=-1, dy=53, dx=0
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH4:    ; Path 4
    FCB 80              ; path4: intensity
    FCB $0D,$08,0,0        ; path4: header (y=13, x=8, relative to center)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH5:    ; Path 5
    FCB 80              ; path5: intensity
    FCB $EF,$08,0,0        ; path5: header (y=-17, x=8, relative to center)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH6:    ; Path 6
    FCB 120              ; path6: intensity
    FCB $FB,$F9,0,0        ; path6: header (y=-5, x=-7, relative to center)
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH7:    ; Path 7
    FCB 100              ; path7: intensity
    FCB $F9,$FB,0,0        ; path7: header (y=-7, x=-5, relative to center)
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH8:    ; Path 8
    FCB 100              ; path8: intensity
    FCB $F9,$FE,0,0        ; path8: header (y=-7, x=-2, relative to center)
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH9:    ; Path 9
    FCB 100              ; path9: intensity
    FCB $F9,$01,0,0        ; path9: header (y=-7, x=1, relative to center)
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH10:    ; Path 10
    FCB 100              ; path10: intensity
    FCB $F9,$04,0,0        ; path10: header (y=-7, x=4, relative to center)
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH11:    ; Path 11
    FCB 110              ; path11: intensity
    FCB $F0,$00,0,0        ; path11: header (y=-16, x=0, relative to center)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH12:    ; Path 12
    FCB 110              ; path12: intensity
    FCB $F0,$00,0,0        ; path12: header (y=-16, x=0, relative to center)
    FCB $FF,$FF,$01          ; flag=-1, dy=-1, dx=1
    FCB $FF,$FF,$FF          ; flag=-1, dy=-1, dx=-1
    FCB $FF,$01,$FF          ; flag=-1, dy=1, dx=-1
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB 2                ; End marker (path complete)

; Generated from painting.vec (Malban Draw_Sync_List format)
; Total paths: 10, points: 42
; X bounds: min=-16, max=16, width=32
; Center: (0, 0)

_PAINTING_WIDTH EQU 32
_PAINTING_HALF_WIDTH EQU 16
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

; ==== Level: CONSERVATORY ====
; Author: 
; Difficulty: medium

_CONSERVATORY_LEVEL:
    FDB -96  ; World bounds: xMin (16-bit signed)
    FDB 95  ; xMax (16-bit signed)
    FDB -128  ; yMin (16-bit signed)
    FDB 127  ; yMax (16-bit signed)
    FDB 0  ; Time limit (seconds)
    FDB 0  ; Target score
    FCB 0  ; Background object count
    FCB 7  ; Gameplay object count
    FCB 0  ; Foreground object count
    FDB _CONSERVATORY_BG_OBJECTS
    FDB _CONSERVATORY_GAMEPLAY_OBJECTS
    FDB _CONSERVATORY_FG_OBJECTS

_CONSERVATORY_BG_OBJECTS:

_CONSERVATORY_GAMEPLAY_OBJECTS:
; Object: obj_con_arch_left (enemy)
    FCB 1  ; type
    FDB -90  ; x
    FDB -83  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _ENTRANCE_ARC_VECTORS  ; vector_ptr
    FCB _ENTRANCE_ARC_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)

; Object: obj_con_arch_right (enemy)
    FCB 1  ; type
    FDB 85  ; x
    FDB -83  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _ENTRANCE_ARC_VECTORS  ; vector_ptr
    FCB _ENTRANCE_ARC_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)

; Object: obj_con_lamp_left (enemy)
    FCB 1  ; type
    FDB -55  ; x
    FDB -5  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _LAMP_VECTORS  ; vector_ptr
    FCB _LAMP_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)

; Object: obj_con_lamp_right (enemy)
    FCB 1  ; type
    FDB 55  ; x
    FDB -5  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _LAMP_VECTORS  ; vector_ptr
    FCB _LAMP_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)

; Object: obj_con_harpsichord (enemy)
    FCB 1  ; type
    FDB 0  ; x
    FDB -90  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _DESK_VECTORS  ; vector_ptr
    FCB _DESK_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)

; Object: obj_con_portrait (enemy)
    FCB 1  ; type
    FDB -15  ; x
    FDB 25  ; y
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
    FCB _PAINTING_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)

; Object: obj_con_floor (enemy)
    FCB 1  ; type
    FDB 0  ; x
    FDB -115  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _FLOOR_VECTORS  ; vector_ptr
    FCB _FLOOR_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)


_CONSERVATORY_FG_OBJECTS:


; ==== Level: VAULT_CORRIDOR ====
; Author: 
; Difficulty: medium

_VAULT_CORRIDOR_LEVEL:
    FDB -128  ; World bounds: xMin (16-bit signed)
    FDB 127  ; xMax (16-bit signed)
    FDB -128  ; yMin (16-bit signed)
    FDB 127  ; yMax (16-bit signed)
    FDB 0  ; Time limit (seconds)
    FDB 0  ; Target score
    FCB 0  ; Background object count
    FCB 7  ; Gameplay object count
    FCB 0  ; Foreground object count
    FDB _VAULT_CORRIDOR_BG_OBJECTS
    FDB _VAULT_CORRIDOR_GAMEPLAY_OBJECTS
    FDB _VAULT_CORRIDOR_FG_OBJECTS

_VAULT_CORRIDOR_BG_OBJECTS:

_VAULT_CORRIDOR_GAMEPLAY_OBJECTS:
; Object: obj_vc_lamp_left (enemy)
    FCB 1  ; type
    FDB -90  ; x
    FDB -5  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _LAMP_VECTORS  ; vector_ptr
    FCB _LAMP_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)

; Object: obj_vc_lamp_right (enemy)
    FCB 1  ; type
    FDB 90  ; x
    FDB -5  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _LAMP_VECTORS  ; vector_ptr
    FCB _LAMP_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)

; Object: obj_vc_wall_panel_left (enemy)
    FCB 1  ; type
    FDB -65  ; x
    FDB -45  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _WALL_COMPARTMENT_VECTORS  ; vector_ptr
    FCB _WALL_COMPARTMENT_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)

; Object: obj_vc_wall_panel_right (enemy)
    FCB 1  ; type
    FDB 40  ; x
    FDB -45  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _WALL_COMPARTMENT_VECTORS  ; vector_ptr
    FCB _WALL_COMPARTMENT_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)

; Object: obj_vc_pedestal_npc (enemy)
    FCB 1  ; type
    FDB -30  ; x
    FDB -95  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _OPTICS_PEDESTAL_VECTORS  ; vector_ptr
    FCB _OPTICS_PEDESTAL_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)

; Object: obj_vc_vault_door (enemy)
    FCB 1  ; type
    FDB 70  ; x
    FDB -90  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _LOCKED_DOOR_VECTORS  ; vector_ptr
    FCB _LOCKED_DOOR_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)

; Object: obj_vc_floor (enemy)
    FCB 1  ; type
    FDB 0  ; x
    FDB -115  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _FLOOR_VECTORS  ; vector_ptr
    FCB _FLOOR_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)


_VAULT_CORRIDOR_FG_OBJECTS:


; Generated from vault_corridor.vec (Malban Draw_Sync_List format)
; Total paths: 12, points: 35
; X bounds: min=-90, max=90, width=180
; Center: (0, 10)

_VAULT_CORRIDOR_WIDTH EQU 180
_VAULT_CORRIDOR_HALF_WIDTH EQU 90
_VAULT_CORRIDOR_CENTER_X EQU 0
_VAULT_CORRIDOR_CENTER_Y EQU 10

_VAULT_CORRIDOR_VECTORS:  ; Main entry (header + 12 path(s))
    FCB 12               ; path_count (runtime metadata)
    FDB _VAULT_CORRIDOR_PATH0        ; pointer to path 0
    FDB _VAULT_CORRIDOR_PATH1        ; pointer to path 1
    FDB _VAULT_CORRIDOR_PATH2        ; pointer to path 2
    FDB _VAULT_CORRIDOR_PATH3        ; pointer to path 3
    FDB _VAULT_CORRIDOR_PATH4        ; pointer to path 4
    FDB _VAULT_CORRIDOR_PATH5        ; pointer to path 5
    FDB _VAULT_CORRIDOR_PATH6        ; pointer to path 6
    FDB _VAULT_CORRIDOR_PATH7        ; pointer to path 7
    FDB _VAULT_CORRIDOR_PATH8        ; pointer to path 8
    FDB _VAULT_CORRIDOR_PATH9        ; pointer to path 9
    FDB _VAULT_CORRIDOR_PATH10        ; pointer to path 10
    FDB _VAULT_CORRIDOR_PATH11        ; pointer to path 11

_VAULT_CORRIDOR_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $B5,$A6,0,0        ; path0: header (y=-75, x=-90, relative to center)
    FCB $FF,$4B,$00          ; sub-seg 1/2 of line 0: dy=75, dx=0
    FCB $FF,$4B,$00          ; sub-seg 2/2 of line 0: dy=75, dx=0
    FCB 2                ; End marker (path complete)

_VAULT_CORRIDOR_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $B5,$5A,0,0        ; path1: header (y=-75, x=90, relative to center)
    FCB $FF,$4B,$00          ; sub-seg 1/2 of line 0: dy=75, dx=0
    FCB $FF,$4B,$00          ; sub-seg 2/2 of line 0: dy=75, dx=0
    FCB 2                ; End marker (path complete)

_VAULT_CORRIDOR_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $B5,$A6,0,0        ; path2: header (y=-75, x=-90, relative to center)
    FCB $FF,$00,$5A          ; sub-seg 1/2 of line 0: dy=0, dx=90
    FCB $FF,$00,$5A          ; sub-seg 2/2 of line 0: dy=0, dx=90
    FCB 2                ; End marker (path complete)

_VAULT_CORRIDOR_PATH3:    ; Path 3
    FCB 80              ; path3: intensity
    FCB $4B,$A6,0,0        ; path3: header (y=75, x=-90, relative to center)
    FCB $FF,$00,$5A          ; sub-seg 1/2 of line 0: dy=0, dx=90
    FCB $FF,$00,$5A          ; sub-seg 2/2 of line 0: dy=0, dx=90
    FCB 2                ; End marker (path complete)

_VAULT_CORRIDOR_PATH4:    ; Path 4
    FCB 60              ; path4: intensity
    FCB $0C,$A6,0,0        ; path4: header (y=12, x=-90, relative to center)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_VAULT_CORRIDOR_PATH5:    ; Path 5
    FCB 60              ; path5: intensity
    FCB $EE,$A6,0,0        ; path5: header (y=-18, x=-90, relative to center)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_VAULT_CORRIDOR_PATH6:    ; Path 6
    FCB 60              ; path6: intensity
    FCB $D2,$A6,0,0        ; path6: header (y=-46, x=-90, relative to center)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_VAULT_CORRIDOR_PATH7:    ; Path 7
    FCB 60              ; path7: intensity
    FCB $0C,$4E,0,0        ; path7: header (y=12, x=78, relative to center)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_VAULT_CORRIDOR_PATH8:    ; Path 8
    FCB 60              ; path8: intensity
    FCB $EE,$4E,0,0        ; path8: header (y=-18, x=78, relative to center)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_VAULT_CORRIDOR_PATH9:    ; Path 9
    FCB 60              ; path9: intensity
    FCB $D2,$4E,0,0        ; path9: header (y=-46, x=78, relative to center)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_VAULT_CORRIDOR_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $B5,$3A,0,0        ; path10: header (y=-75, x=58, relative to center)
    FCB $FF,$2F,$00          ; flag=-1, dy=47, dx=0
    FCB $FF,$15,$04          ; flag=-1, dy=21, dx=4
    FCB $FF,$11,$0C          ; flag=-1, dy=17, dx=12
    FCB $FF,$EF,$0C          ; flag=-1, dy=-17, dx=12
    FCB $FF,$EB,$04          ; flag=-1, dy=-21, dx=4
    FCB $FF,$D1,$00          ; flag=-1, dy=-47, dx=0
    FCB 2                ; End marker (path complete)

_VAULT_CORRIDOR_PATH11:    ; Path 11
    FCB 110              ; path11: intensity
    FCB $FA,$4A,0,0        ; path11: header (y=-6, x=74, relative to center)
    FCB $FF,$FC,$08          ; flag=-1, dy=-4, dx=8
    FCB $FF,$F8,$04          ; flag=-1, dy=-8, dx=4
    FCB $FF,$F8,$FC          ; flag=-1, dy=-8, dx=-4
    FCB $FF,$FC,$F8          ; flag=-1, dy=-4, dx=-8
    FCB $FF,$04,$F8          ; flag=-1, dy=4, dx=-8
    FCB $FF,$08,$FC          ; flag=-1, dy=8, dx=-4
    FCB $FF,$08,$04          ; flag=-1, dy=8, dx=4
    FCB $FF,$04,$08          ; flag=-1, dy=4, dx=8
    FCB 2                ; End marker (path complete)

; Generated from conservatory.vec (Malban Draw_Sync_List format)
; Total paths: 10, points: 33
; X bounds: min=-120, max=120, width=240
; Center: (0, -2)

_CONSERVATORY_WIDTH EQU 240
_CONSERVATORY_HALF_WIDTH EQU 120
_CONSERVATORY_CENTER_X EQU 0
_CONSERVATORY_CENTER_Y EQU -2

_CONSERVATORY_VECTORS:  ; Main entry (header + 10 path(s))
    FCB 10               ; path_count (runtime metadata)
    FDB _CONSERVATORY_PATH0        ; pointer to path 0
    FDB _CONSERVATORY_PATH1        ; pointer to path 1
    FDB _CONSERVATORY_PATH2        ; pointer to path 2
    FDB _CONSERVATORY_PATH3        ; pointer to path 3
    FDB _CONSERVATORY_PATH4        ; pointer to path 4
    FDB _CONSERVATORY_PATH5        ; pointer to path 5
    FDB _CONSERVATORY_PATH6        ; pointer to path 6
    FDB _CONSERVATORY_PATH7        ; pointer to path 7
    FDB _CONSERVATORY_PATH8        ; pointer to path 8
    FDB _CONSERVATORY_PATH9        ; pointer to path 9

_CONSERVATORY_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $C6,$88,0,0        ; path0: header (y=-58, x=-120, relative to center)
    FCB $FF,$00,$78          ; sub-seg 1/2 of line 0: dy=0, dx=120
    FCB $FF,$00,$78          ; sub-seg 2/2 of line 0: dy=0, dx=120
    FCB 2                ; End marker (path complete)

_CONSERVATORY_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $C6,$A6,0,0        ; path1: header (y=-58, x=-90, relative to center)
    FCB $FF,$4B,$00          ; flag=-1, dy=75, dx=0
    FCB $FF,$28,$14          ; flag=-1, dy=40, dx=20
    FCB $FF,$D8,$14          ; flag=-1, dy=-40, dx=20
    FCB $FF,$B5,$00          ; flag=-1, dy=-75, dx=0
    FCB 2                ; End marker (path complete)

_CONSERVATORY_PATH2:    ; Path 2
    FCB 80              ; path2: intensity
    FCB $11,$AC,0,0        ; path2: header (y=17, x=-84, relative to center)
    FCB $FF,$1F,$0E          ; flag=-1, dy=31, dx=14
    FCB $FF,$E1,$0E          ; flag=-1, dy=-31, dx=14
    FCB 2                ; End marker (path complete)

_CONSERVATORY_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $C6,$32,0,0        ; path3: header (y=-58, x=50, relative to center)
    FCB $FF,$4B,$00          ; flag=-1, dy=75, dx=0
    FCB $FF,$28,$14          ; flag=-1, dy=40, dx=20
    FCB $FF,$D8,$14          ; flag=-1, dy=-40, dx=20
    FCB $FF,$B5,$00          ; flag=-1, dy=-75, dx=0
    FCB 2                ; End marker (path complete)

_CONSERVATORY_PATH4:    ; Path 4
    FCB 80              ; path4: intensity
    FCB $11,$38,0,0        ; path4: header (y=17, x=56, relative to center)
    FCB $FF,$1F,$0E          ; flag=-1, dy=31, dx=14
    FCB $FF,$E1,$0E          ; flag=-1, dy=-31, dx=14
    FCB 2                ; End marker (path complete)

_CONSERVATORY_PATH5:    ; Path 5
    FCB 110              ; path5: intensity
    FCB $DF,$E0,0,0        ; path5: header (y=-33, x=-32, relative to center)
    FCB $FF,$00,$38          ; flag=-1, dy=0, dx=56
    FCB $FF,$F7,$0E          ; flag=-1, dy=-9, dx=14
    FCB $FF,$F5,$FA          ; flag=-1, dy=-11, dx=-6
    FCB $FF,$00,$C0          ; flag=-1, dy=0, dx=-64
    FCB $FF,$14,$00          ; flag=-1, dy=20, dx=0
    FCB 2                ; End marker (path complete)

_CONSERVATORY_PATH6:    ; Path 6
    FCB 90              ; path6: intensity
    FCB $DF,$E0,0,0        ; path6: header (y=-33, x=-32, relative to center)
    FCB $FF,$0F,$08          ; flag=-1, dy=15, dx=8
    FCB $FF,$02,$20          ; flag=-1, dy=2, dx=32
    FCB $FF,$EF,$10          ; flag=-1, dy=-17, dx=16
    FCB 2                ; End marker (path complete)

_CONSERVATORY_PATH7:    ; Path 7
    FCB 64              ; path7: intensity
    FCB $D4,$E4,0,0        ; path7: header (y=-44, x=-28, relative to center)
    FCB $FF,$00,$38          ; flag=-1, dy=0, dx=56
    FCB 2                ; End marker (path complete)

_CONSERVATORY_PATH8:    ; Path 8
    FCB 90              ; path8: intensity
    FCB $CB,$E4,0,0        ; path8: header (y=-53, x=-28, relative to center)
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

_CONSERVATORY_PATH9:    ; Path 9
    FCB 90              ; path9: intensity
    FCB $CB,$1C,0,0        ; path9: header (y=-53, x=28, relative to center)
    FCB $FF,$FB,$03          ; flag=-1, dy=-5, dx=3
    FCB 2                ; End marker (path complete)

_PUZZLE_SUCCESS_SFX:
    ; SFX: puzzle_success (powerup)
    ; Duration: 500ms (25fr), Freq: 440Hz, Channel: 0
    FCB $A0         ; Frame 0 - flags (vol=0, noisevol=0, tone=Y, noise=N)
    FCB $00, $C8  ; Tone period = 200 (big-endian)
    FCB $AF         ; Frame 1 - flags (vol=15, noisevol=0, tone=Y, noise=N)
    FCB $00, $C8  ; Tone period = 200 (big-endian)
    FCB $AA         ; Frame 2 - flags (vol=10, noisevol=0, tone=Y, noise=N)
    FCB $00, $C8  ; Tone period = 200 (big-endian)
    FCB $AA         ; Frame 3 - flags (vol=10, noisevol=0, tone=Y, noise=N)
    FCB $00, $C8  ; Tone period = 200 (big-endian)
    FCB $AA         ; Frame 4 - flags (vol=10, noisevol=0, tone=Y, noise=N)
    FCB $00, $C8  ; Tone period = 200 (big-endian)
    FCB $AA         ; Frame 5 - flags (vol=10, noisevol=0, tone=Y, noise=N)
    FCB $00, $C8  ; Tone period = 200 (big-endian)
    FCB $AA         ; Frame 6 - flags (vol=10, noisevol=0, tone=Y, noise=N)
    FCB $00, $86  ; Tone period = 134 (big-endian)
    FCB $AA         ; Frame 7 - flags (vol=10, noisevol=0, tone=Y, noise=N)
    FCB $00, $86  ; Tone period = 134 (big-endian)
    FCB $AA         ; Frame 8 - flags (vol=10, noisevol=0, tone=Y, noise=N)
    FCB $00, $86  ; Tone period = 134 (big-endian)
    FCB $AA         ; Frame 9 - flags (vol=10, noisevol=0, tone=Y, noise=N)
    FCB $00, $86  ; Tone period = 134 (big-endian)
    FCB $AA         ; Frame 10 - flags (vol=10, noisevol=0, tone=Y, noise=N)
    FCB $00, $86  ; Tone period = 134 (big-endian)
    FCB $AA         ; Frame 11 - flags (vol=10, noisevol=0, tone=Y, noise=N)
    FCB $00, $86  ; Tone period = 134 (big-endian)
    FCB $AA         ; Frame 12 - flags (vol=10, noisevol=0, tone=Y, noise=N)
    FCB $00, $59  ; Tone period = 89 (big-endian)
    FCB $AA         ; Frame 13 - flags (vol=10, noisevol=0, tone=Y, noise=N)
    FCB $00, $59  ; Tone period = 89 (big-endian)
    FCB $AA         ; Frame 14 - flags (vol=10, noisevol=0, tone=Y, noise=N)
    FCB $00, $59  ; Tone period = 89 (big-endian)
    FCB $AA         ; Frame 15 - flags (vol=10, noisevol=0, tone=Y, noise=N)
    FCB $00, $59  ; Tone period = 89 (big-endian)
    FCB $AA         ; Frame 16 - flags (vol=10, noisevol=0, tone=Y, noise=N)
    FCB $00, $59  ; Tone period = 89 (big-endian)
    FCB $AA         ; Frame 17 - flags (vol=10, noisevol=0, tone=Y, noise=N)
    FCB $00, $59  ; Tone period = 89 (big-endian)
    FCB $AA         ; Frame 18 - flags (vol=10, noisevol=0, tone=Y, noise=N)
    FCB $00, $C8  ; Tone period = 200 (big-endian)
    FCB $A8         ; Frame 19 - flags (vol=8, noisevol=0, tone=Y, noise=N)
    FCB $00, $C8  ; Tone period = 200 (big-endian)
    FCB $A7         ; Frame 20 - flags (vol=7, noisevol=0, tone=Y, noise=N)
    FCB $00, $C8  ; Tone period = 200 (big-endian)
    FCB $A5         ; Frame 21 - flags (vol=5, noisevol=0, tone=Y, noise=N)
    FCB $00, $C8  ; Tone period = 200 (big-endian)
    FCB $A4         ; Frame 22 - flags (vol=4, noisevol=0, tone=Y, noise=N)
    FCB $00, $C8  ; Tone period = 200 (big-endian)
    FCB $A2         ; Frame 23 - flags (vol=2, noisevol=0, tone=Y, noise=N)
    FCB $00, $C8  ; Tone period = 200 (big-endian)
    FCB $A1         ; Frame 24 - flags (vol=1, noisevol=0, tone=Y, noise=N)
    FCB $00, $86  ; Tone period = 134 (big-endian)
    FCB $D0, $20    ; End of effect marker


; Generated from crystal_apprentice.vec (Malban Draw_Sync_List format)
; Total paths: 7, points: 28
; X bounds: min=-14, max=14, width=28
; Center: (0, -1)

_CRYSTAL_APPRENTICE_WIDTH EQU 28
_CRYSTAL_APPRENTICE_HALF_WIDTH EQU 14
_CRYSTAL_APPRENTICE_CENTER_X EQU 0
_CRYSTAL_APPRENTICE_CENTER_Y EQU -1

_CRYSTAL_APPRENTICE_VECTORS:  ; Main entry (header + 7 path(s))
    FCB 7               ; path_count (runtime metadata)
    FDB _CRYSTAL_APPRENTICE_PATH0        ; pointer to path 0
    FDB _CRYSTAL_APPRENTICE_PATH1        ; pointer to path 1
    FDB _CRYSTAL_APPRENTICE_PATH2        ; pointer to path 2
    FDB _CRYSTAL_APPRENTICE_PATH3        ; pointer to path 3
    FDB _CRYSTAL_APPRENTICE_PATH4        ; pointer to path 4
    FDB _CRYSTAL_APPRENTICE_PATH5        ; pointer to path 5
    FDB _CRYSTAL_APPRENTICE_PATH6        ; pointer to path 6

_CRYSTAL_APPRENTICE_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $EF,$F2,0,0        ; path0: header (y=-17, x=-14, relative to center)
    FCB $FF,$00,$1C          ; flag=-1, dy=0, dx=28
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$E4          ; flag=-1, dy=0, dx=-28
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_CRYSTAL_APPRENTICE_PATH1:    ; Path 1
    FCB 110              ; path1: intensity
    FCB $F7,$F7,0,0        ; path1: header (y=-9, x=-9, relative to center)
    FCB $FF,$00,$12          ; flag=-1, dy=0, dx=18
    FCB $FF,$0E,$00          ; flag=-1, dy=14, dx=0
    FCB $FF,$00,$EE          ; flag=-1, dy=0, dx=-18
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB 2                ; End marker (path complete)

_CRYSTAL_APPRENTICE_PATH2:    ; Path 2
    FCB 80              ; path2: intensity
    FCB $FF,$F8,0,0        ; path2: header (y=-1, x=-8, relative to center)
    FCB $FF,$00,$10          ; flag=-1, dy=0, dx=16
    FCB 2                ; End marker (path complete)

_CRYSTAL_APPRENTICE_PATH3:    ; Path 3
    FCB 90              ; path3: intensity
    FCB $05,$FD,0,0        ; path3: header (y=5, x=-3, relative to center)
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB 2                ; End marker (path complete)

_CRYSTAL_APPRENTICE_PATH4:    ; Path 4
    FCB 110              ; path4: intensity
    FCB $11,$00,0,0        ; path4: header (y=17, x=0, relative to center)
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB $FF,$FC,$01          ; flag=-1, dy=-4, dx=1
    FCB $FF,$FC,$FF          ; flag=-1, dy=-4, dx=-1
    FCB $FF,$FE,$FB          ; flag=-1, dy=-2, dx=-5
    FCB $FF,$02,$FB          ; flag=-1, dy=2, dx=-5
    FCB $FF,$04,$FF          ; flag=-1, dy=4, dx=-1
    FCB $FF,$04,$01          ; flag=-1, dy=4, dx=1
    FCB $FF,$02,$05          ; flag=-1, dy=2, dx=5
    FCB 2                ; End marker (path complete)

_CRYSTAL_APPRENTICE_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $0B,$FC,0,0        ; path5: header (y=11, x=-4, relative to center)
    FCB $FF,$01,$02          ; flag=-1, dy=1, dx=2
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_CRYSTAL_APPRENTICE_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $0B,$04,0,0        ; path6: header (y=11, x=4, relative to center)
    FCB $FF,$01,$02          ; flag=-1, dy=1, dx=2
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

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


; Generated from desk.vec (Malban Draw_Sync_List format)
; Total paths: 10, points: 25
; X bounds: min=-30, max=30, width=60
; Center: (0, 7)

_DESK_WIDTH EQU 60
_DESK_HALF_WIDTH EQU 30
_DESK_CENTER_X EQU 0
_DESK_CENTER_Y EQU 7

_DESK_VECTORS:  ; Main entry (header + 10 path(s))
    FCB 10               ; path_count (runtime metadata)
    FDB _DESK_PATH0        ; pointer to path 0
    FDB _DESK_PATH1        ; pointer to path 1
    FDB _DESK_PATH2        ; pointer to path 2
    FDB _DESK_PATH3        ; pointer to path 3
    FDB _DESK_PATH4        ; pointer to path 4
    FDB _DESK_PATH5        ; pointer to path 5
    FDB _DESK_PATH6        ; pointer to path 6
    FDB _DESK_PATH7        ; pointer to path 7
    FDB _DESK_PATH8        ; pointer to path 8
    FDB _DESK_PATH9        ; pointer to path 9

_DESK_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $F7,$E2,0,0        ; path0: header (y=-9, x=-30, relative to center)
    FCB $FF,$00,$3C          ; flag=-1, dy=0, dx=60
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB $FF,$00,$C4          ; flag=-1, dy=0, dx=-60
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB 2                ; End marker (path complete)

_DESK_PATH1:    ; Path 1
    FCB 90              ; path1: intensity
    FCB $FE,$E6,0,0        ; path1: header (y=-2, x=-26, relative to center)
    FCB $FF,$19,$00          ; flag=-1, dy=25, dx=0
    FCB 2                ; End marker (path complete)

_DESK_PATH2:    ; Path 2
    FCB 90              ; path2: intensity
    FCB $FE,$1A,0,0        ; path2: header (y=-2, x=26, relative to center)
    FCB $FF,$19,$00          ; flag=-1, dy=25, dx=0
    FCB 2                ; End marker (path complete)

_DESK_PATH3:    ; Path 3
    FCB 75              ; path3: intensity
    FCB $0B,$E6,0,0        ; path3: header (y=11, x=-26, relative to center)
    FCB $FF,$00,$34          ; flag=-1, dy=0, dx=52
    FCB 2                ; End marker (path complete)

_DESK_PATH4:    ; Path 4
    FCB 110              ; path4: intensity
    FCB $F7,$F2,0,0        ; path4: header (y=-9, x=-14, relative to center)
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB $FF,$00,$1C          ; flag=-1, dy=0, dx=28
    FCB $FF,$0E,$00          ; flag=-1, dy=14, dx=0
    FCB 2                ; End marker (path complete)

_DESK_PATH5:    ; Path 5
    FCB 80              ; path5: intensity
    FCB $F7,$00,0,0        ; path5: header (y=-9, x=0, relative to center)
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB 2                ; End marker (path complete)

_DESK_PATH6:    ; Path 6
    FCB 55              ; path6: intensity
    FCB $F3,$F5,0,0        ; path6: header (y=-13, x=-11, relative to center)
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB 2                ; End marker (path complete)

_DESK_PATH7:    ; Path 7
    FCB 55              ; path7: intensity
    FCB $F3,$02,0,0        ; path7: header (y=-13, x=2, relative to center)
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB 2                ; End marker (path complete)

_DESK_PATH8:    ; Path 8
    FCB 55              ; path8: intensity
    FCB $EF,$F5,0,0        ; path8: header (y=-17, x=-11, relative to center)
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB 2                ; End marker (path complete)

_DESK_PATH9:    ; Path 9
    FCB 55              ; path9: intensity
    FCB $EF,$02,0,0        ; path9: header (y=-17, x=2, relative to center)
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB 2                ; End marker (path complete)

; Generated from hans_automata.vec (Malban Draw_Sync_List format)
; Total paths: 8, points: 24
; X bounds: min=-11, max=11, width=22
; Center: (0, 0)

_HANS_AUTOMATA_WIDTH EQU 22
_HANS_AUTOMATA_HALF_WIDTH EQU 11
_HANS_AUTOMATA_CENTER_X EQU 0
_HANS_AUTOMATA_CENTER_Y EQU 0

_HANS_AUTOMATA_VECTORS:  ; Main entry (header + 8 path(s))
    FCB 8               ; path_count (runtime metadata)
    FDB _HANS_AUTOMATA_PATH0        ; pointer to path 0
    FDB _HANS_AUTOMATA_PATH1        ; pointer to path 1
    FDB _HANS_AUTOMATA_PATH2        ; pointer to path 2
    FDB _HANS_AUTOMATA_PATH3        ; pointer to path 3
    FDB _HANS_AUTOMATA_PATH4        ; pointer to path 4
    FDB _HANS_AUTOMATA_PATH5        ; pointer to path 5
    FDB _HANS_AUTOMATA_PATH6        ; pointer to path 6
    FDB _HANS_AUTOMATA_PATH7        ; pointer to path 7

_HANS_AUTOMATA_PATH0:    ; Path 0
    FCB 110              ; path0: intensity
    FCB $FA,$F9,0,0        ; path0: header (y=-6, x=-7, relative to center)
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB $FF,$0C,$00          ; flag=-1, dy=12, dx=0
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB 2                ; End marker (path complete)

_HANS_AUTOMATA_PATH1:    ; Path 1
    FCB 110              ; path1: intensity
    FCB $06,$FC,0,0        ; path1: header (y=6, x=-4, relative to center)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_HANS_AUTOMATA_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $03,$F9,0,0        ; path2: header (y=3, x=-7, relative to center)
    FCB $FF,$FC,$FC          ; flag=-1, dy=-4, dx=-4
    FCB 2                ; End marker (path complete)

_HANS_AUTOMATA_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $03,$07,0,0        ; path3: header (y=3, x=7, relative to center)
    FCB $FF,$FC,$04          ; flag=-1, dy=-4, dx=4
    FCB 2                ; End marker (path complete)

_HANS_AUTOMATA_PATH4:    ; Path 4
    FCB 90              ; path4: intensity
    FCB $F8,$FA,0,0        ; path4: header (y=-8, x=-6, relative to center)
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB 2                ; End marker (path complete)

_HANS_AUTOMATA_PATH5:    ; Path 5
    FCB 90              ; path5: intensity
    FCB $F8,$02,0,0        ; path5: header (y=-8, x=2, relative to center)
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB 2                ; End marker (path complete)

_HANS_AUTOMATA_PATH6:    ; Path 6
    FCB 85              ; path6: intensity
    FCB $01,$FA,0,0        ; path6: header (y=1, x=-6, relative to center)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_HANS_AUTOMATA_PATH7:    ; Path 7
    FCB 85              ; path7: intensity
    FCB $FD,$FA,0,0        ; path7: header (y=-3, x=-6, relative to center)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

; Generated from player.vec (Malban Draw_Sync_List format)
; Total paths: 7, points: 25
; X bounds: min=-11, max=10, width=21
; Center: (0, 0)

_PLAYER_WIDTH EQU 21
_PLAYER_HALF_WIDTH EQU 10
_PLAYER_CENTER_X EQU 0
_PLAYER_CENTER_Y EQU 0

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
    FCB $0D,$FA,0,0        ; path0: header (y=13, x=-6, relative to center)
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
    FCB $06,$FA,0,0        ; path1: header (y=6, x=-6, relative to center)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $06,$FB,0,0        ; path2: header (y=6, x=-5, relative to center)
    FCB $FF,$ED,$FC          ; flag=-1, dy=-19, dx=-4
    FCB $FF,$00,$10          ; flag=-1, dy=0, dx=16
    FCB $FF,$13,$FC          ; flag=-1, dy=19, dx=-4
    FCB 2                ; End marker (path complete)

_PLAYER_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $F3,$FB,0,0        ; path3: header (y=-13, x=-5, relative to center)
    FCB $FF,$F8,$FF          ; flag=-1, dy=-8, dx=-1
    FCB 2                ; End marker (path complete)

_PLAYER_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $F3,$03,0,0        ; path4: header (y=-13, x=3, relative to center)
    FCB $FF,$F8,$01          ; flag=-1, dy=-8, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_PATH5:    ; Path 5
    FCB 100              ; path5: intensity
    FCB $FF,$F9,0,0        ; path5: header (y=-1, x=-7, relative to center)
    FCB $FF,$FA,$FC          ; flag=-1, dy=-6, dx=-4
    FCB 2                ; End marker (path complete)

_PLAYER_PATH6:    ; Path 6
    FCB 100              ; path6: intensity
    FCB $FF,$05,0,0        ; path6: header (y=-1, x=5, relative to center)
    FCB $FF,$FB,$05          ; flag=-1, dy=-5, dx=5
    FCB 2                ; End marker (path complete)

; ==== Level: ANTEROOM ====
; Author: 
; Difficulty: medium

_ANTEROOM_LEVEL:
    FDB -96  ; World bounds: xMin (16-bit signed)
    FDB 863  ; xMax (16-bit signed)
    FDB -128  ; yMin (16-bit signed)
    FDB 127  ; yMax (16-bit signed)
    FDB 0  ; Time limit (seconds)
    FDB 0  ; Target score
    FCB 0  ; Background object count
    FCB 4  ; Gameplay object count
    FCB 0  ; Foreground object count
    FDB _ANTEROOM_BG_OBJECTS
    FDB _ANTEROOM_GAMEPLAY_OBJECTS
    FDB _ANTEROOM_FG_OBJECTS

_ANTEROOM_BG_OBJECTS:

_ANTEROOM_GAMEPLAY_OBJECTS:
; Object: obj_ant_lamp_left (enemy)
    FCB 1  ; type
    FDB 80  ; x
    FDB -5  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _LAMP_VECTORS  ; vector_ptr
    FCB _LAMP_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)

; Object: obj_ant_desk (enemy)
    FCB 1  ; type
    FDB 300  ; x
    FDB -72  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _DESK_VECTORS  ; vector_ptr
    FCB _DESK_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)

; Object: obj_ant_lamp_right (enemy)
    FCB 1  ; type
    FDB 530  ; x
    FDB -5  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _LAMP_VECTORS  ; vector_ptr
    FCB _LAMP_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)

; Object: obj_ant_exit_arch (enemy)
    FCB 1  ; type
    FDB 734  ; x
    FDB -33  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _ENTRANCE_ARC_VECTORS  ; vector_ptr
    FCB _ENTRANCE_ARC_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)


_ANTEROOM_FG_OBJECTS:


; ==== Level: CLOCKROOM ====
; Author: 
; Difficulty: medium

_CLOCKROOM_LEVEL:
    FDB -96  ; World bounds: xMin (16-bit signed)
    FDB 671  ; xMax (16-bit signed)
    FDB -128  ; yMin (16-bit signed)
    FDB 127  ; yMax (16-bit signed)
    FDB 0  ; Time limit (seconds)
    FDB 0  ; Target score
    FCB 0  ; Background object count
    FCB 4  ; Gameplay object count
    FCB 0  ; Foreground object count
    FDB _CLOCKROOM_BG_OBJECTS
    FDB _CLOCKROOM_GAMEPLAY_OBJECTS
    FDB _CLOCKROOM_FG_OBJECTS

_CLOCKROOM_BG_OBJECTS:

_CLOCKROOM_GAMEPLAY_OBJECTS:
; Object: obj_lamp_left (enemy)
    FCB 1  ; type
    FDB 70  ; x
    FDB -5  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _LAMP_VECTORS  ; vector_ptr
    FCB _LAMP_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)

; Object: obj_sarcophagus (enemy)
    FCB 1  ; type
    FDB 190  ; x
    FDB -72  ; y
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
    FCB _DOOR_LOCKED_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)

; Object: obj_pendulum_clock (enemy)
    FCB 1  ; type
    FDB 400  ; x
    FDB -60  ; y
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
    FCB _PAINTING_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)

; Object: obj_lamp_right (enemy)
    FCB 1  ; type
    FDB 480  ; x
    FDB -5  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _LAMP_VECTORS  ; vector_ptr
    FCB _LAMP_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)


_CLOCKROOM_FG_OBJECTS:


; ==== Level: ENTRANCE ====
; Author: 
; Difficulty: medium

_ENTRANCE_LEVEL:
    FDB -96  ; World bounds: xMin (16-bit signed)
    FDB 863  ; xMax (16-bit signed)
    FDB -128  ; yMin (16-bit signed)
    FDB 127  ; yMax (16-bit signed)
    FDB 0  ; Time limit (seconds)
    FDB 0  ; Target score
    FCB 1  ; Background object count
    FCB 3  ; Gameplay object count
    FCB 0  ; Foreground object count
    FDB _ENTRANCE_BG_OBJECTS
    FDB _ENTRANCE_GAMEPLAY_OBJECTS
    FDB _ENTRANCE_FG_OBJECTS

_ENTRANCE_BG_OBJECTS:
; Object: obj_1772461603432 (enemy)
    FCB 1  ; type
    FDB -30  ; x
    FDB -33  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _ENTRANCE_ARC_VECTORS  ; vector_ptr
    FCB _ENTRANCE_ARC_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)


_ENTRANCE_GAMEPLAY_OBJECTS:
; Object: obj_1772392174432 (enemy)
    FCB 1  ; type
    FDB 458  ; x
    FDB -2  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _LAMP_VECTORS  ; vector_ptr
    FCB _LAMP_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)

; Object: obj_1772392204950 (enemy)
    FCB 1  ; type
    FDB 259  ; x
    FDB -49  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _CANVAS_VECTORS  ; vector_ptr
    FCB _CANVAS_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)

; Object: obj_1772392228716 (enemy)
    FCB 1  ; type
    FDB 738  ; x
    FDB -47  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _LOCKED_DOOR_VECTORS  ; vector_ptr
    FCB _LOCKED_DOOR_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)


_ENTRANCE_FG_OBJECTS:


; Generated from floor.vec (Malban Draw_Sync_List format)
; Total paths: 12, points: 15
; X bounds: min=-122, max=118, width=240
; Center: (-2, -6)

_FLOOR_WIDTH EQU 240
_FLOOR_HALF_WIDTH EQU 120
_FLOOR_CENTER_X EQU -2
_FLOOR_CENTER_Y EQU -6

_FLOOR_VECTORS:  ; Main entry (header + 12 path(s))
    FCB 12               ; path_count (runtime metadata)
    FDB _FLOOR_PATH0        ; pointer to path 0
    FDB _FLOOR_PATH1        ; pointer to path 1
    FDB _FLOOR_PATH2        ; pointer to path 2
    FDB _FLOOR_PATH3        ; pointer to path 3
    FDB _FLOOR_PATH4        ; pointer to path 4
    FDB _FLOOR_PATH5        ; pointer to path 5
    FDB _FLOOR_PATH6        ; pointer to path 6
    FDB _FLOOR_PATH7        ; pointer to path 7
    FDB _FLOOR_PATH8        ; pointer to path 8
    FDB _FLOOR_PATH9        ; pointer to path 9
    FDB _FLOOR_PATH10        ; pointer to path 10
    FDB _FLOOR_PATH11        ; pointer to path 11

_FLOOR_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FF,$88,0,0        ; path0: header (y=-1, x=-120, relative to center)
    FCB $FF,$00,$43          ; flag=-1, dy=0, dx=67
    FCB 2                ; End marker (path complete)

_FLOOR_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $00,$8D,0,0        ; path1: header (y=0, x=-115, relative to center)
    FCB 2                ; End marker (path complete)

_FLOOR_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $FF,$A3,0,0        ; path2: header (y=-1, x=-93, relative to center)
    FCB 2                ; End marker (path complete)

_FLOOR_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $00,$FC,0,0        ; path3: header (y=0, x=-4, relative to center)
    FCB 2                ; End marker (path complete)

_FLOOR_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $FF,$CE,0,0        ; path4: header (y=-1, x=-50, relative to center)
    FCB $FF,$01,$4D          ; flag=-1, dy=1, dx=77
    FCB 2                ; End marker (path complete)

_FLOOR_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $FF,$E8,0,0        ; path5: header (y=-1, x=-24, relative to center)
    FCB 2                ; End marker (path complete)

_FLOOR_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $01,$FD,0,0        ; path6: header (y=1, x=-3, relative to center)
    FCB 2                ; End marker (path complete)

_FLOOR_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $01,$1D,0,0        ; path7: header (y=1, x=29, relative to center)
    FCB 2                ; End marker (path complete)

_FLOOR_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $00,$20,0,0        ; path8: header (y=0, x=32, relative to center)
    FCB $FF,$00,$58          ; flag=-1, dy=0, dx=88
    FCB 2                ; End marker (path complete)

_FLOOR_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $00,$78,0,0        ; path9: header (y=0, x=120, relative to center)
    FCB 2                ; End marker (path complete)

_FLOOR_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $00,$3E,0,0        ; path10: header (y=0, x=62, relative to center)
    FCB 2                ; End marker (path complete)

_FLOOR_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $00,$60,0,0        ; path11: header (y=0, x=96, relative to center)
    FCB 2                ; End marker (path complete)

; Generated from lamp.vec (Malban Draw_Sync_List format)
; Total paths: 7, points: 19
; X bounds: min=-22, max=22, width=44
; Center: (0, 0)

_LAMP_WIDTH EQU 44
_LAMP_HALF_WIDTH EQU 22
_LAMP_CENTER_X EQU 0
_LAMP_CENTER_Y EQU 0

_LAMP_VECTORS:  ; Main entry (header + 7 path(s))
    FCB 7               ; path_count (runtime metadata)
    FDB _LAMP_PATH0        ; pointer to path 0
    FDB _LAMP_PATH1        ; pointer to path 1
    FDB _LAMP_PATH2        ; pointer to path 2
    FDB _LAMP_PATH3        ; pointer to path 3
    FDB _LAMP_PATH4        ; pointer to path 4
    FDB _LAMP_PATH5        ; pointer to path 5
    FDB _LAMP_PATH6        ; pointer to path 6

_LAMP_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $06,$EA,0,0        ; path0: header (y=6, x=-22, relative to center)
    FCB $FF,$00,$2C          ; flag=-1, dy=0, dx=44
    FCB 2                ; End marker (path complete)

_LAMP_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $06,$00,0,0        ; path1: header (y=6, x=0, relative to center)
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB 2                ; End marker (path complete)

_LAMP_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $FF,$FB,0,0        ; path2: header (y=-1, x=-5, relative to center)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$FA,$FE          ; flag=-1, dy=-6, dx=-2
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$06,$FE          ; flag=-1, dy=6, dx=-2
    FCB 2                ; End marker (path complete)

_LAMP_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $06,$EE,0,0        ; path3: header (y=6, x=-18, relative to center)
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_LAMP_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $00,$EC,0,0        ; path4: header (y=0, x=-20, relative to center)
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB 2                ; End marker (path complete)

_LAMP_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $06,$12,0,0        ; path5: header (y=6, x=18, relative to center)
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_LAMP_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $00,$10,0,0        ; path6: header (y=0, x=16, relative to center)
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB 2                ; End marker (path complete)

; Generated from platform_down.vec (Malban Draw_Sync_List format)
; Total paths: 7, points: 19
; X bounds: min=-38, max=38, width=76
; Center: (0, 20)

_PLATFORM_DOWN_WIDTH EQU 76
_PLATFORM_DOWN_HALF_WIDTH EQU 38
_PLATFORM_DOWN_CENTER_X EQU 0
_PLATFORM_DOWN_CENTER_Y EQU 20

_PLATFORM_DOWN_VECTORS:  ; Main entry (header + 7 path(s))
    FCB 7               ; path_count (runtime metadata)
    FDB _PLATFORM_DOWN_PATH0        ; pointer to path 0
    FDB _PLATFORM_DOWN_PATH1        ; pointer to path 1
    FDB _PLATFORM_DOWN_PATH2        ; pointer to path 2
    FDB _PLATFORM_DOWN_PATH3        ; pointer to path 3
    FDB _PLATFORM_DOWN_PATH4        ; pointer to path 4
    FDB _PLATFORM_DOWN_PATH5        ; pointer to path 5
    FDB _PLATFORM_DOWN_PATH6        ; pointer to path 6

_PLATFORM_DOWN_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $FE,$DA,0,0        ; path0: header (y=-2, x=-38, relative to center)
    FCB $FF,$00,$4C          ; flag=-1, dy=0, dx=76
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$B4          ; flag=-1, dy=0, dx=-76
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_PLATFORM_DOWN_PATH1:    ; Path 1
    FCB 75              ; path1: intensity
    FCB $01,$DD,0,0        ; path1: header (y=1, x=-35, relative to center)
    FCB $FF,$00,$46          ; flag=-1, dy=0, dx=70
    FCB 2                ; End marker (path complete)

_PLATFORM_DOWN_PATH2:    ; Path 2
    FCB 80              ; path2: intensity
    FCB $08,$F9,0,0        ; path2: header (y=8, x=-7, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_PLATFORM_DOWN_PATH3:    ; Path 3
    FCB 80              ; path3: intensity
    FCB $08,$07,0,0        ; path3: header (y=8, x=7, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_PLATFORM_DOWN_PATH4:    ; Path 4
    FCB 90              ; path4: intensity
    FCB $12,$F4,0,0        ; path4: header (y=18, x=-12, relative to center)
    FCB $FF,$00,$18          ; flag=-1, dy=0, dx=24
    FCB 2                ; End marker (path complete)

_PLATFORM_DOWN_PATH5:    ; Path 5
    FCB 50              ; path5: intensity
    FCB $EE,$F9,0,0        ; path5: header (y=-18, x=-7, relative to center)
    FCB $FF,$08,$FE          ; flag=-1, dy=8, dx=-2
    FCB $FF,$08,$03          ; flag=-1, dy=8, dx=3
    FCB 2                ; End marker (path complete)

_PLATFORM_DOWN_PATH6:    ; Path 6
    FCB 50              ; path6: intensity
    FCB $EE,$07,0,0        ; path6: header (y=-18, x=7, relative to center)
    FCB $FF,$08,$02          ; flag=-1, dy=8, dx=2
    FCB $FF,$08,$FD          ; flag=-1, dy=8, dx=-3
    FCB 2                ; End marker (path complete)

; Generated from caretaker.vec (Malban Draw_Sync_List format)
; Total paths: 7, points: 17
; X bounds: min=-7, max=10, width=17
; Center: (1, 2)

_CARETAKER_WIDTH EQU 17
_CARETAKER_HALF_WIDTH EQU 8
_CARETAKER_CENTER_X EQU 1
_CARETAKER_CENTER_Y EQU 2

_CARETAKER_VECTORS:  ; Main entry (header + 7 path(s))
    FCB 7               ; path_count (runtime metadata)
    FDB _CARETAKER_PATH0        ; pointer to path 0
    FDB _CARETAKER_PATH1        ; pointer to path 1
    FDB _CARETAKER_PATH2        ; pointer to path 2
    FDB _CARETAKER_PATH3        ; pointer to path 3
    FDB _CARETAKER_PATH4        ; pointer to path 4
    FDB _CARETAKER_PATH5        ; pointer to path 5
    FDB _CARETAKER_PATH6        ; pointer to path 6

_CARETAKER_PATH0:    ; Path 0
    FCB 80              ; path0: intensity
    FCB $0C,$FA,0,0        ; path0: header (y=12, x=-6, relative to center)
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$F9          ; flag=-1, dy=0, dx=-7
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

_CARETAKER_PATH1:    ; Path 1
    FCB 80              ; path1: intensity
    FCB $0C,$FE,0,0        ; path1: header (y=12, x=-2, relative to center)
    FCB $FF,$F8,$03          ; flag=-1, dy=-8, dx=3
    FCB $FF,$F6,$01          ; flag=-1, dy=-10, dx=1
    FCB 2                ; End marker (path complete)

_CARETAKER_PATH2:    ; Path 2
    FCB 75              ; path2: intensity
    FCB $08,$00,0,0        ; path2: header (y=8, x=0, relative to center)
    FCB $FF,$FA,$F8          ; flag=-1, dy=-6, dx=-8
    FCB 2                ; End marker (path complete)

_CARETAKER_PATH3:    ; Path 3
    FCB 75              ; path3: intensity
    FCB $06,$01,0,0        ; path3: header (y=6, x=1, relative to center)
    FCB $FF,$F9,$03          ; flag=-1, dy=-7, dx=3
    FCB 2                ; End marker (path complete)

_CARETAKER_PATH4:    ; Path 4
    FCB 70              ; path4: intensity
    FCB $FF,$04,0,0        ; path4: header (y=-1, x=4, relative to center)
    FCB $FF,$F2,$05          ; flag=-1, dy=-14, dx=5
    FCB 2                ; End marker (path complete)

_CARETAKER_PATH5:    ; Path 5
    FCB 80              ; path5: intensity
    FCB $FA,$00,0,0        ; path5: header (y=-6, x=0, relative to center)
    FCB $FF,$F6,$FE          ; flag=-1, dy=-10, dx=-2
    FCB 2                ; End marker (path complete)

_CARETAKER_PATH6:    ; Path 6
    FCB 80              ; path6: intensity
    FCB $FA,$02,0,0        ; path6: header (y=-6, x=2, relative to center)
    FCB $FF,$F6,$02          ; flag=-1, dy=-10, dx=2
    FCB 2                ; End marker (path complete)

; ==== Level: WEIGHTS_ROOM ====
; Author: 
; Difficulty: medium

_WEIGHTS_ROOM_LEVEL:
    FDB -96  ; World bounds: xMin (16-bit signed)
    FDB 671  ; xMax (16-bit signed)
    FDB -128  ; yMin (16-bit signed)
    FDB 127  ; yMax (16-bit signed)
    FDB 0  ; Time limit (seconds)
    FDB 0  ; Target score
    FCB 0  ; Background object count
    FCB 3  ; Gameplay object count
    FCB 0  ; Foreground object count
    FDB _WEIGHTS_ROOM_BG_OBJECTS
    FDB _WEIGHTS_ROOM_GAMEPLAY_OBJECTS
    FDB _WEIGHTS_ROOM_FG_OBJECTS

_WEIGHTS_ROOM_BG_OBJECTS:

_WEIGHTS_ROOM_GAMEPLAY_OBJECTS:
; Object: obj_wgt_lamp (enemy)
    FCB 1  ; type
    FDB 80  ; x
    FDB -5  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _LAMP_VECTORS  ; vector_ptr
    FCB _LAMP_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)

; Object: obj_wgt_pedestal_base (enemy)
    FCB 1  ; type
    FDB 280  ; x
    FDB -68  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _CANVAS_VECTORS  ; vector_ptr
    FCB _CANVAS_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)

; Object: obj_wgt_exit_arch (enemy)
    FCB 1  ; type
    FDB 570  ; x
    FDB -34  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _ENTRANCE_ARC_VECTORS  ; vector_ptr
    FCB _ENTRANCE_ARC_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)


_WEIGHTS_ROOM_FG_OBJECTS:


_HEARTBEAT_SFX:
    ; SFX: heartbeat (custom)
    ; Duration: 280ms (14fr), Freq: 110Hz, Channel: 0
    FCB $AF         ; Frame 0 - flags (vol=15, noisevol=0, tone=Y, noise=N)
    FCB $03, $22  ; Tone period = 802 (big-endian)
    FCB $AD         ; Frame 1 - flags (vol=13, noisevol=0, tone=Y, noise=N)
    FCB $03, $22  ; Tone period = 802 (big-endian)
    FCB $AB         ; Frame 2 - flags (vol=11, noisevol=0, tone=Y, noise=N)
    FCB $03, $22  ; Tone period = 802 (big-endian)
    FCB $A9         ; Frame 3 - flags (vol=9, noisevol=0, tone=Y, noise=N)
    FCB $03, $22  ; Tone period = 802 (big-endian)
    FCB $A7         ; Frame 4 - flags (vol=7, noisevol=0, tone=Y, noise=N)
    FCB $03, $22  ; Tone period = 802 (big-endian)
    FCB $A7         ; Frame 5 - flags (vol=7, noisevol=0, tone=Y, noise=N)
    FCB $02, $59  ; Tone period = 601 (big-endian)
    FCB $A7         ; Frame 6 - flags (vol=7, noisevol=0, tone=Y, noise=N)
    FCB $02, $59  ; Tone period = 601 (big-endian)
    FCB $A7         ; Frame 7 - flags (vol=7, noisevol=0, tone=Y, noise=N)
    FCB $02, $59  ; Tone period = 601 (big-endian)
    FCB $A7         ; Frame 8 - flags (vol=7, noisevol=0, tone=Y, noise=N)
    FCB $02, $59  ; Tone period = 601 (big-endian)
    FCB $A7         ; Frame 9 - flags (vol=7, noisevol=0, tone=Y, noise=N)
    FCB $02, $59  ; Tone period = 601 (big-endian)
    FCB $A7         ; Frame 10 - flags (vol=7, noisevol=0, tone=Y, noise=N)
    FCB $03, $22  ; Tone period = 802 (big-endian)
    FCB $A5         ; Frame 11 - flags (vol=5, noisevol=0, tone=Y, noise=N)
    FCB $03, $22  ; Tone period = 802 (big-endian)
    FCB $A3         ; Frame 12 - flags (vol=3, noisevol=0, tone=Y, noise=N)
    FCB $03, $22  ; Tone period = 802 (big-endian)
    FCB $A1         ; Frame 13 - flags (vol=1, noisevol=0, tone=Y, noise=N)
    FCB $03, $22  ; Tone period = 802 (big-endian)
    FCB $D0, $20    ; End of effect marker


; Generated from entrance_arc.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 17
; X bounds: min=-60, max=60, width=120
; Center: (0, 0)

_ENTRANCE_ARC_WIDTH EQU 120
_ENTRANCE_ARC_HALF_WIDTH EQU 60
_ENTRANCE_ARC_CENTER_X EQU 0
_ENTRANCE_ARC_CENTER_Y EQU 0

_ENTRANCE_ARC_VECTORS:  ; Main entry (header + 4 path(s))
    FCB 4               ; path_count (runtime metadata)
    FDB _ENTRANCE_ARC_PATH0        ; pointer to path 0
    FDB _ENTRANCE_ARC_PATH1        ; pointer to path 1
    FDB _ENTRANCE_ARC_PATH2        ; pointer to path 2
    FDB _ENTRANCE_ARC_PATH3        ; pointer to path 3

_ENTRANCE_ARC_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $A2,$C4,0,0        ; path0: header (y=-94, x=-60, relative to center)
    FCB $FF,$00,$14          ; flag=-1, dy=0, dx=20
    FCB $FF,$46,$00          ; sub-seg 1/2 of line 1: dy=70, dx=0
    FCB $FF,$46,$00          ; sub-seg 2/2 of line 1: dy=70, dx=0
    FCB $FF,$00,$EC          ; flag=-1, dy=0, dx=-20
    FCB $FF,$BA,$00          ; sub-seg 1/2 of closing line: dy=-70, dx=0
    FCB $FF,$BA,$00          ; sub-seg 2/2 of closing line: dy=-70, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $A2,$28,0,0        ; path1: header (y=-94, x=40, relative to center)
    FCB $FF,$00,$14          ; flag=-1, dy=0, dx=20
    FCB $FF,$46,$00          ; sub-seg 1/2 of line 1: dy=70, dx=0
    FCB $FF,$46,$00          ; sub-seg 2/2 of line 1: dy=70, dx=0
    FCB $FF,$00,$EC          ; flag=-1, dy=0, dx=-20
    FCB $FF,$BA,$00          ; sub-seg 1/2 of closing line: dy=-70, dx=0
    FCB $FF,$BA,$00          ; sub-seg 2/2 of closing line: dy=-70, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $2E,$D8,0,0        ; path2: header (y=46, x=-40, relative to center)
    FCB $FF,$19,$02          ; flag=-1, dy=25, dx=2
    FCB $FF,$17,$26          ; flag=-1, dy=23, dx=38
    FCB $FF,$E9,$26          ; flag=-1, dy=-23, dx=38
    FCB $FF,$E7,$02          ; flag=-1, dy=-25, dx=2
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH3:    ; Path 3
    FCB 60              ; path3: intensity
    FCB $A2,$DD,0,0        ; path3: header (y=-94, x=-35, relative to center)
    FCB $FF,$00,$46          ; flag=-1, dy=0, dx=70
    FCB $FF,$46,$00          ; sub-seg 1/2 of line 1: dy=70, dx=0
    FCB $FF,$46,$00          ; sub-seg 2/2 of line 1: dy=70, dx=0
    FCB $FF,$00,$BA          ; flag=-1, dy=0, dx=-70
    FCB $FF,$BA,$00          ; sub-seg 1/2 of closing line: dy=-70, dx=0
    FCB $FF,$BA,$00          ; sub-seg 2/2 of closing line: dy=-70, dx=0
    FCB 2                ; End marker (path complete)

; Generated from locked_door.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 15
; X bounds: min=-30, max=30, width=60
; Center: (0, 0)

_LOCKED_DOOR_WIDTH EQU 60
_LOCKED_DOOR_HALF_WIDTH EQU 30
_LOCKED_DOOR_CENTER_X EQU 0
_LOCKED_DOOR_CENTER_Y EQU 0

_LOCKED_DOOR_VECTORS:  ; Main entry (header + 4 path(s))
    FCB 4               ; path_count (runtime metadata)
    FDB _LOCKED_DOOR_PATH0        ; pointer to path 0
    FDB _LOCKED_DOOR_PATH1        ; pointer to path 1
    FDB _LOCKED_DOOR_PATH2        ; pointer to path 2
    FDB _LOCKED_DOOR_PATH3        ; pointer to path 3

_LOCKED_DOOR_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $C9,$E2,0,0        ; path0: header (y=-55, x=-30, relative to center)
    FCB $FF,$00,$3C          ; flag=-1, dy=0, dx=60
    FCB $FF,$6E,$00          ; flag=-1, dy=110, dx=0
    FCB $FF,$00,$C4          ; flag=-1, dy=0, dx=-60
    FCB $FF,$92,$00          ; flag=-1, dy=-110, dx=0
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH1:    ; Path 1
    FCB 90              ; path1: intensity
    FCB $D1,$EA,0,0        ; path1: header (y=-47, x=-22, relative to center)
    FCB $FF,$00,$2C          ; flag=-1, dy=0, dx=44
    FCB $FF,$44,$00          ; flag=-1, dy=68, dx=0
    FCB $FF,$00,$D4          ; flag=-1, dy=0, dx=-44
    FCB $FF,$BC,$00          ; flag=-1, dy=-68, dx=0
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $F9,$FC,0,0        ; path2: header (y=-7, x=-4, relative to center)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $F9,$FC,0,0        ; path3: header (y=-7, x=-4, relative to center)
    FCB $FF,$06,$04          ; flag=-1, dy=6, dx=4
    FCB $FF,$FA,$04          ; flag=-1, dy=-6, dx=4
    FCB 2                ; End marker (path complete)

; Generated from optics_pedestal.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 18
; X bounds: min=-16, max=16, width=32
; Center: (0, -6)

_OPTICS_PEDESTAL_WIDTH EQU 32
_OPTICS_PEDESTAL_HALF_WIDTH EQU 16
_OPTICS_PEDESTAL_CENTER_X EQU 0
_OPTICS_PEDESTAL_CENTER_Y EQU -6

_OPTICS_PEDESTAL_VECTORS:  ; Main entry (header + 4 path(s))
    FCB 4               ; path_count (runtime metadata)
    FDB _OPTICS_PEDESTAL_PATH0        ; pointer to path 0
    FDB _OPTICS_PEDESTAL_PATH1        ; pointer to path 1
    FDB _OPTICS_PEDESTAL_PATH2        ; pointer to path 2
    FDB _OPTICS_PEDESTAL_PATH3        ; pointer to path 3

_OPTICS_PEDESTAL_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $E8,$F2,0,0        ; path0: header (y=-24, x=-14, relative to center)
    FCB $FF,$00,$1C          ; flag=-1, dy=0, dx=28
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$E4          ; flag=-1, dy=0, dx=-28
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_OPTICS_PEDESTAL_PATH1:    ; Path 1
    FCB 90              ; path1: intensity
    FCB $EE,$F7,0,0        ; path1: header (y=-18, x=-9, relative to center)
    FCB $FF,$2C,$00          ; flag=-1, dy=44, dx=0
    FCB $FF,$00,$12          ; flag=-1, dy=0, dx=18
    FCB $FF,$D4,$00          ; flag=-1, dy=-44, dx=0
    FCB 2                ; End marker (path complete)

_OPTICS_PEDESTAL_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $1A,$F0,0,0        ; path2: header (y=26, x=-16, relative to center)
    FCB $FF,$00,$20          ; flag=-1, dy=0, dx=32
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$E0          ; flag=-1, dy=0, dx=-32
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_OPTICS_PEDESTAL_PATH3:    ; Path 3
    FCB 110              ; path3: intensity
    FCB $DE,$00,0,0        ; path3: header (y=-34, x=0, relative to center)
    FCB $FF,$0A,$F6          ; flag=-1, dy=10, dx=-10
    FCB $FF,$00,$14          ; flag=-1, dy=0, dx=20
    FCB $FF,$F6,$F6          ; flag=-1, dy=-10, dx=-10
    FCB 2                ; End marker (path complete)

; Generated from wall_compartment.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 16
; X bounds: min=-20, max=20, width=40
; Center: (0, -16)

_WALL_COMPARTMENT_WIDTH EQU 40
_WALL_COMPARTMENT_HALF_WIDTH EQU 20
_WALL_COMPARTMENT_CENTER_X EQU 0
_WALL_COMPARTMENT_CENTER_Y EQU -16

_WALL_COMPARTMENT_VECTORS:  ; Main entry (header + 4 path(s))
    FCB 4               ; path_count (runtime metadata)
    FDB _WALL_COMPARTMENT_PATH0        ; pointer to path 0
    FDB _WALL_COMPARTMENT_PATH1        ; pointer to path 1
    FDB _WALL_COMPARTMENT_PATH2        ; pointer to path 2
    FDB _WALL_COMPARTMENT_PATH3        ; pointer to path 3

_WALL_COMPARTMENT_PATH0:    ; Path 0
    FCB 90              ; path0: intensity
    FCB $F7,$EC,0,0        ; path0: header (y=-9, x=-20, relative to center)
    FCB $FF,$00,$28          ; flag=-1, dy=0, dx=40
    FCB $FF,$1E,$00          ; flag=-1, dy=30, dx=0
    FCB $FF,$00,$D8          ; flag=-1, dy=0, dx=-40
    FCB $FF,$E2,$00          ; flag=-1, dy=-30, dx=0
    FCB 2                ; End marker (path complete)

_WALL_COMPARTMENT_PATH1:    ; Path 1
    FCB 80              ; path1: intensity
    FCB $F7,$EC,0,0        ; path1: header (y=-9, x=-20, relative to center)
    FCB $FF,$F3,$00          ; flag=-1, dy=-13, dx=0
    FCB $FF,$00,$28          ; flag=-1, dy=0, dx=40
    FCB 2                ; End marker (path complete)

_WALL_COMPARTMENT_PATH2:    ; Path 2
    FCB 120              ; path2: intensity
    FCB $FA,$00,0,0        ; path2: header (y=-6, x=0, relative to center)
    FCB $FF,$07,$F6          ; flag=-1, dy=7, dx=-10
    FCB $FF,$07,$0A          ; flag=-1, dy=7, dx=10
    FCB $FF,$F9,$0A          ; flag=-1, dy=-7, dx=10
    FCB $FF,$F9,$F6          ; flag=-1, dy=-7, dx=-10
    FCB 2                ; End marker (path complete)

_WALL_COMPARTMENT_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $FE,$00,0,0        ; path3: header (y=-2, x=0, relative to center)
    FCB $FF,$03,$FC          ; flag=-1, dy=3, dx=-4
    FCB $FF,$03,$04          ; flag=-1, dy=3, dx=4
    FCB $FF,$FD,$04          ; flag=-1, dy=-3, dx=4
    FCB $FF,$FD,$FC          ; flag=-1, dy=-3, dx=-4
    FCB 2                ; End marker (path complete)

; Generated from platform_up.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 13
; X bounds: min=-38, max=38, width=76
; Center: (0, 15)

_PLATFORM_UP_WIDTH EQU 76
_PLATFORM_UP_HALF_WIDTH EQU 38
_PLATFORM_UP_CENTER_X EQU 0
_PLATFORM_UP_CENTER_Y EQU 15

_PLATFORM_UP_VECTORS:  ; Main entry (header + 5 path(s))
    FCB 5               ; path_count (runtime metadata)
    FDB _PLATFORM_UP_PATH0        ; pointer to path 0
    FDB _PLATFORM_UP_PATH1        ; pointer to path 1
    FDB _PLATFORM_UP_PATH2        ; pointer to path 2
    FDB _PLATFORM_UP_PATH3        ; pointer to path 3
    FDB _PLATFORM_UP_PATH4        ; pointer to path 4

_PLATFORM_UP_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $E9,$DA,0,0        ; path0: header (y=-23, x=-38, relative to center)
    FCB $FF,$00,$4C          ; flag=-1, dy=0, dx=76
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$B4          ; flag=-1, dy=0, dx=-76
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_PLATFORM_UP_PATH1:    ; Path 1
    FCB 75              ; path1: intensity
    FCB $EC,$DD,0,0        ; path1: header (y=-20, x=-35, relative to center)
    FCB $FF,$00,$46          ; flag=-1, dy=0, dx=70
    FCB 2                ; End marker (path complete)

_PLATFORM_UP_PATH2:    ; Path 2
    FCB 85              ; path2: intensity
    FCB $F3,$F9,0,0        ; path2: header (y=-13, x=-7, relative to center)
    FCB $FF,$24,$00          ; flag=-1, dy=36, dx=0
    FCB 2                ; End marker (path complete)

_PLATFORM_UP_PATH3:    ; Path 3
    FCB 85              ; path3: intensity
    FCB $F3,$07,0,0        ; path3: header (y=-13, x=7, relative to center)
    FCB $FF,$24,$00          ; flag=-1, dy=36, dx=0
    FCB 2                ; End marker (path complete)

_PLATFORM_UP_PATH4:    ; Path 4
    FCB 90              ; path4: intensity
    FCB $17,$F4,0,0        ; path4: header (y=23, x=-12, relative to center)
    FCB $FF,$00,$18          ; flag=-1, dy=0, dx=24
    FCB 2                ; End marker (path complete)

; ==== Level: OPTICS_LAB ====
; Author: 
; Difficulty: hard

_OPTICS_LAB_LEVEL:
    FDB -96  ; World bounds: xMin (16-bit signed)
    FDB 575  ; xMax (16-bit signed)
    FDB -128  ; yMin (16-bit signed)
    FDB 127  ; yMax (16-bit signed)
    FDB 0  ; Time limit (seconds)
    FDB 0  ; Target score
    FCB 0  ; Background object count
    FCB 2  ; Gameplay object count
    FCB 0  ; Foreground object count
    FDB _OPTICS_LAB_BG_OBJECTS
    FDB _OPTICS_LAB_GAMEPLAY_OBJECTS
    FDB _OPTICS_LAB_FG_OBJECTS

_OPTICS_LAB_BG_OBJECTS:

_OPTICS_LAB_GAMEPLAY_OBJECTS:
; Object: obj_opt_lamp (enemy)
    FCB 1  ; type
    FDB 80  ; x
    FDB -5  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _LAMP_VECTORS  ; vector_ptr
    FCB _LAMP_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)

; Object: obj_opt_pedestal (enemy)
    FCB 1  ; type
    FDB 250  ; x
    FDB -62  ; y
    FDB 256  ; scale (8.8 fixed)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FDB _OPTICS_PEDESTAL_VECTORS  ; vector_ptr
    FCB _OPTICS_PEDESTAL_HALF_WIDTH  ; half_width (visual cull margin, ROM+18)
    FCB 0  ; reserved (ROM+19)


_OPTICS_LAB_FG_OBJECTS:


; Generated from canvas.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 12
; X bounds: min=-30, max=30, width=60
; Center: (0, 0)

_CANVAS_WIDTH EQU 60
_CANVAS_HALF_WIDTH EQU 30
_CANVAS_CENTER_X EQU 0
_CANVAS_CENTER_Y EQU 0

_CANVAS_VECTORS:  ; Main entry (header + 4 path(s))
    FCB 4               ; path_count (runtime metadata)
    FDB _CANVAS_PATH0        ; pointer to path 0
    FDB _CANVAS_PATH1        ; pointer to path 1
    FDB _CANVAS_PATH2        ; pointer to path 2
    FDB _CANVAS_PATH3        ; pointer to path 3

_CANVAS_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $EA,$E2,0,0        ; path0: header (y=-22, x=-30, relative to center)
    FCB $FF,$00,$3C          ; flag=-1, dy=0, dx=60
    FCB $FF,$2C,$00          ; flag=-1, dy=44, dx=0
    FCB $FF,$00,$C4          ; flag=-1, dy=0, dx=-60
    FCB $FF,$D4,$00          ; flag=-1, dy=-44, dx=0
    FCB 2                ; End marker (path complete)

_CANVAS_PATH1:    ; Path 1
    FCB 90              ; path1: intensity
    FCB $F0,$E8,0,0        ; path1: header (y=-16, x=-24, relative to center)
    FCB $FF,$00,$30          ; flag=-1, dy=0, dx=48
    FCB $FF,$20,$00          ; flag=-1, dy=32, dx=0
    FCB $FF,$00,$D0          ; flag=-1, dy=0, dx=-48
    FCB $FF,$E0,$00          ; flag=-1, dy=-32, dx=0
    FCB 2                ; End marker (path complete)

_CANVAS_PATH2:    ; Path 2
    FCB 60              ; path2: intensity
    FCB $F0,$E8,0,0        ; path2: header (y=-16, x=-24, relative to center)
    FCB $FF,$20,$30          ; flag=-1, dy=32, dx=48
    FCB 2                ; End marker (path complete)

_CANVAS_PATH3:    ; Path 3
    FCB 60              ; path3: intensity
    FCB $10,$E8,0,0        ; path3: header (y=16, x=-24, relative to center)
    FCB $FF,$E0,$30          ; flag=-1, dy=-32, dx=48
    FCB 2                ; End marker (path complete)

_ITEM_PICKUP_SFX:
    ; SFX: item_pickup (coin)
    ; Duration: 200ms (10fr), Freq: 880Hz, Channel: 0
    FCB $AF         ; Frame 0 - flags (vol=15, noisevol=0, tone=Y, noise=N)
    FCB $00, $64  ; Tone period = 100 (big-endian)
    FCB $AB         ; Frame 1 - flags (vol=11, noisevol=0, tone=Y, noise=N)
    FCB $00, $64  ; Tone period = 100 (big-endian)
    FCB $AB         ; Frame 2 - flags (vol=11, noisevol=0, tone=Y, noise=N)
    FCB $00, $64  ; Tone period = 100 (big-endian)
    FCB $AB         ; Frame 3 - flags (vol=11, noisevol=0, tone=Y, noise=N)
    FCB $00, $64  ; Tone period = 100 (big-endian)
    FCB $AB         ; Frame 4 - flags (vol=11, noisevol=0, tone=Y, noise=N)
    FCB $00, $32  ; Tone period = 50 (big-endian)
    FCB $AB         ; Frame 5 - flags (vol=11, noisevol=0, tone=Y, noise=N)
    FCB $00, $32  ; Tone period = 50 (big-endian)
    FCB $AB         ; Frame 6 - flags (vol=11, noisevol=0, tone=Y, noise=N)
    FCB $00, $32  ; Tone period = 50 (big-endian)
    FCB $AB         ; Frame 7 - flags (vol=11, noisevol=0, tone=Y, noise=N)
    FCB $00, $32  ; Tone period = 50 (big-endian)
    FCB $A7         ; Frame 8 - flags (vol=7, noisevol=0, tone=Y, noise=N)
    FCB $00, $64  ; Tone period = 100 (big-endian)
    FCB $A3         ; Frame 9 - flags (vol=3, noisevol=0, tone=Y, noise=N)
    FCB $00, $64  ; Tone period = 100 (big-endian)
    FCB $D0, $20    ; End of effect marker


; Generated from elisa_ghost.vec (Malban Draw_Sync_List format)
; Total paths: 3, points: 11
; X bounds: min=-10, max=10, width=20
; Center: (0, -2)

_ELISA_GHOST_WIDTH EQU 20
_ELISA_GHOST_HALF_WIDTH EQU 10
_ELISA_GHOST_CENTER_X EQU 0
_ELISA_GHOST_CENTER_Y EQU -2

_ELISA_GHOST_VECTORS:  ; Main entry (header + 3 path(s))
    FCB 3               ; path_count (runtime metadata)
    FDB _ELISA_GHOST_PATH0        ; pointer to path 0
    FDB _ELISA_GHOST_PATH1        ; pointer to path 1
    FDB _ELISA_GHOST_PATH2        ; pointer to path 2

_ELISA_GHOST_PATH0:    ; Path 0
    FCB 90              ; path0: intensity
    FCB $0E,$F9,0,0        ; path0: header (y=14, x=-7, relative to center)
    FCB $FF,$03,$07          ; flag=-1, dy=3, dx=7
    FCB $FF,$FD,$07          ; flag=-1, dy=-3, dx=7
    FCB $FF,$F6,$03          ; flag=-1, dy=-10, dx=3
    FCB $FF,$F4,$FA          ; flag=-1, dy=-12, dx=-6
    FCB $FF,$FD,$F6          ; flag=-1, dy=-3, dx=-10
    FCB $FF,$0D,$FC          ; flag=-1, dy=13, dx=-4
    FCB $FF,$0C,$03          ; flag=-1, dy=12, dx=3
    FCB 2                ; End marker (path complete)

_ELISA_GHOST_PATH1:    ; Path 1
    FCB 65              ; path1: intensity
    FCB $F8,$04,0,0        ; path1: header (y=-8, x=4, relative to center)
    FCB $FF,$F9,$03          ; flag=-1, dy=-7, dx=3
    FCB 2                ; End marker (path complete)

_ELISA_GHOST_PATH2:    ; Path 2
    FCB 65              ; path2: intensity
    FCB $F5,$FA,0,0        ; path2: header (y=-11, x=-6, relative to center)
    FCB $FF,$FA,$02          ; flag=-1, dy=-6, dx=2
    FCB 2                ; End marker (path complete)

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

VECTOR_ADDR_TABLE:
    FDB _CANVAS_VECTORS    ; canvas
    FDB _CARETAKER_VECTORS    ; caretaker
    FDB _CONSERVATORY_VECTORS    ; conservatory
    FDB _CRYPT_LOGO_VECTORS    ; crypt_logo
    FDB _CRYSTAL_APPRENTICE_VECTORS    ; crystal_apprentice
    FDB _DESK_VECTORS    ; desk
    FDB _DOOR_LOCKED_VECTORS    ; door_locked
    FDB _ELISA_GHOST_VECTORS    ; elisa_ghost
    FDB _ENTRANCE_ARC_VECTORS    ; entrance_arc
    FDB _FLOOR_VECTORS    ; floor
    FDB _HANS_AUTOMATA_VECTORS    ; hans_automata
    FDB _LAMP_VECTORS    ; lamp
    FDB _LOCKED_DOOR_VECTORS    ; locked_door
    FDB _OPTICS_PEDESTAL_VECTORS    ; optics_pedestal
    FDB _PAINTING_VECTORS    ; painting
    FDB _PLATFORM_DOWN_VECTORS    ; platform_down
    FDB _PLATFORM_UP_VECTORS    ; platform_up
    FDB _PLAYER_VECTORS    ; player
    FDB _VAULT_CORRIDOR_VECTORS    ; vault_corridor
    FDB _WALL_COMPARTMENT_VECTORS    ; wall_compartment

; Music Asset Index Mapping:
;   0 = exploration (Bank #1)
;   1 = intro (Bank #1)

MUSIC_BANK_TABLE:
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID

MUSIC_ADDR_TABLE:
    FDB _EXPLORATION_MUSIC    ; exploration
    FDB _INTRO_MUSIC    ; intro

; SFX Asset Index Mapping:
;   0 = door_unlock (Bank #1)
;   1 = heartbeat (Bank #1)
;   2 = item_pickup (Bank #1)
;   3 = puzzle_fail (Bank #1)
;   4 = puzzle_success (Bank #1)

SFX_BANK_TABLE:
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID

SFX_ADDR_TABLE:
    FDB _DOOR_UNLOCK_SFX    ; door_unlock
    FDB _HEARTBEAT_SFX    ; heartbeat
    FDB _ITEM_PICKUP_SFX    ; item_pickup
    FDB _PUZZLE_FAIL_SFX    ; puzzle_fail
    FDB _PUZZLE_SUCCESS_SFX    ; puzzle_success

; Level Asset Index Mapping:
;   0 = anteroom (Bank #1)
;   1 = clockroom (Bank #1)
;   2 = conservatory (Bank #1)
;   3 = entrance (Bank #1)
;   4 = optics_lab (Bank #1)
;   5 = vault_corridor (Bank #1)
;   6 = weights_room (Bank #1)

LEVEL_BANK_TABLE:
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID

LEVEL_ADDR_TABLE:
    FDB _ANTEROOM_LEVEL    ; anteroom
    FDB _CLOCKROOM_LEVEL    ; clockroom
    FDB _CONSERVATORY_LEVEL    ; conservatory
    FDB _ENTRANCE_LEVEL    ; entrance
    FDB _OPTICS_LAB_LEVEL    ; optics_lab
    FDB _VAULT_CORRIDOR_LEVEL    ; vault_corridor
    FDB _WEIGHTS_ROOM_LEVEL    ; weights_room

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

ASSET_ADDR_TABLE:
    FDB _EXPLORATION_MUSIC    ; exploration
    FDB _INTRO_MUSIC    ; intro
    FDB _CRYPT_LOGO_VECTORS    ; crypt_logo
    FDB _DOOR_LOCKED_VECTORS    ; door_locked
    FDB _PAINTING_VECTORS    ; painting
    FDB _CONSERVATORY_LEVEL    ; conservatory
    FDB _VAULT_CORRIDOR_LEVEL    ; vault_corridor
    FDB _VAULT_CORRIDOR_VECTORS    ; vault_corridor
    FDB _CONSERVATORY_VECTORS    ; conservatory
    FDB _PUZZLE_SUCCESS_SFX    ; puzzle_success
    FDB _CRYSTAL_APPRENTICE_VECTORS    ; crystal_apprentice
    FDB _DOOR_UNLOCK_SFX    ; door_unlock
    FDB _DESK_VECTORS    ; desk
    FDB _HANS_AUTOMATA_VECTORS    ; hans_automata
    FDB _PLAYER_VECTORS    ; player
    FDB _ANTEROOM_LEVEL    ; anteroom
    FDB _CLOCKROOM_LEVEL    ; clockroom
    FDB _ENTRANCE_LEVEL    ; entrance
    FDB _FLOOR_VECTORS    ; floor
    FDB _LAMP_VECTORS    ; lamp
    FDB _PLATFORM_DOWN_VECTORS    ; platform_down
    FDB _CARETAKER_VECTORS    ; caretaker
    FDB _WEIGHTS_ROOM_LEVEL    ; weights_room
    FDB _HEARTBEAT_SFX    ; heartbeat
    FDB _ENTRANCE_ARC_VECTORS    ; entrance_arc
    FDB _LOCKED_DOOR_VECTORS    ; locked_door
    FDB _OPTICS_PEDESTAL_VECTORS    ; optics_pedestal
    FDB _WALL_COMPARTMENT_VECTORS    ; wall_compartment
    FDB _PLATFORM_UP_VECTORS    ; platform_up
    FDB _OPTICS_LAB_LEVEL    ; optics_lab
    FDB _CANVAS_VECTORS    ; canvas
    FDB _ITEM_PICKUP_SFX    ; item_pickup
    FDB _ELISA_GHOST_VECTORS    ; elisa_ghost
    FDB _PUZZLE_FAIL_SFX    ; puzzle_fail

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

    ; Loop over all paths (header byte 0 = path_count, +1.. = FDB table)
    LDB ,X               ; B = path_count
    LBEQ DVB_DONE        ; No paths
    LEAY 1,X             ; Y = pointer to first FDB entry
DVB_PATH_LOOP:
    PSHS B               ; Save remaining path count
    LDX ,Y               ; X = path data address (FDB entry)
    JSR Draw_Sync_List_At_With_Mirrors
    LEAY 2,Y             ; Advance to next FDB entry
    PULS B               ; Restore count
    DECB
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
    
    ; Reset camera to world origin — JSVecX RAM is NOT zero-initialized
    LDD #0
    STD >CAMERA_X
    
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
    
    ; === Copy GP objects from ROM to RAM buffer ===
    LDB >LEVEL_GP_COUNT
    BEQ LLR_SKIP_GP  ; Skip if no GP objects
    
    ; Clear GP buffer with $FF marker (empty sentinel)
    LDA #$FF
    LDU #LEVEL_GP_BUFFER
    LDB #8           ; Max 8 objects
LLR_CLR_GP_LOOP:
    STA ,U           ; Write $FF to first byte of object slot
    LEAU 15,U        ; Advance by 15 bytes (RAM object stride)
    DECB
    BNE LLR_CLR_GP_LOOP
    
    ; Copy GP objects: ROM (20 bytes each) → RAM buffer (14 bytes each)
    LDB >LEVEL_GP_COUNT   ; Reload count after clear loop
    LDX >LEVEL_GP_ROM_PTR ; X = source (ROM)
    LDU #LEVEL_GP_BUFFER  ; U = destination (RAM)
    PSHS U               ; Save buffer start
    JSR LLR_COPY_OBJECTS  ; Copy B objects from X(ROM) to U(RAM)
    PULS D               ; Restore buffer start into D
    STD >LEVEL_GP_PTR    ; LEVEL_GP_PTR → RAM buffer
    BRA LLR_GP_DONE
    
LLR_GP_DONE:
LLR_SKIP_GP:
    
    ; Return level pointer in RESULT
    LDX >LEVEL_PTR
    STX RESULT
    
    PULS D,X,Y,U,PC  ; Restore and return
    
; === LLR_COPY_OBJECTS - Copy N ROM objects to RAM buffer ===
; Input:  B = count, X = source (ROM, 20 bytes/obj), U = dest (RAM, 15 bytes/obj)
; ROM object layout (20 bytes):
;   +0: type, +1-2: x(FDB), +3-4: y(FDB), +5-6: scale(FDB),
;   +7: rotation, +8: intensity, +9: velocity_x, +10: velocity_y,
;   +11: physics_flags, +12: collision_flags, +13: collision_size,
;   +14-15: spawn_delay(FDB), +16-17: vector_ptr(FDB), +18: half_width, +19: reserved
; RAM object layout (15 bytes):
;   +0-1: world_x(FDB i16), +2: y(i8), +3: scale(low), +4: rotation,
;   +5: velocity_x, +6: velocity_y, +7: physics_flags, +8: collision_flags,
;   +9: collision_size, +10: spawn_delay(low), +11-12: vector_ptr, +13: half_width, +14: reserved
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
    LEAX 2,X         ; Skip spawn_delay FDB (2 bytes), X now at ROM +16
    ; RAM +11-12: vector_ptr FDB (ROM +16-17)
    LDD ,X++         ; ROM +16-17
    STD ,U++
    ; RAM +13-14: properties_ptr FDB (ROM +18-19)
    LDD ,X++         ; ROM +18-19
    STD ,U++
    ; X is now past end of this ROM object (ROM +1 + 8 + 5 + 2 + 2 + 2 = +20 total)
    ; NOTE: We started at ROM+1 (after LEAX 1,X), walked:
    ;   ,X and 1,X and 3,X and 5,X and 6,X via indexed → X unchanged
    ;   then LEAX 8,X (X now at ROM+9)
    ;   then 5 post-increment ,X+ → X at ROM+14
    ;   then LEAX 2,X (X at ROM+16)
    ;   then 2x LDD ,X++ → X at ROM+20
    ;   ROM+20 from original ROM+0 = next object start
    
    PULS B           ; Restore counter
    DECB
    BRA LLR_COPY_LOOP
LLR_COPY_DONE:
    RTS

; === SHOW_LEVEL_RUNTIME ===
; Draw all level objects from all layers
; Input:  LEVEL_PTR = pointer to level header
; Layers: BG (ROM stride 20), GP (RAM stride 15), FG (ROM stride 20)
; Each object: load intensity, x, y, vector_ptr, call SLR_DRAW_OBJECTS
SHOW_LEVEL_RUNTIME:
    PSHS D,X,Y,U     ; Preserve registers
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    ; MULTIBANK: Switch to level bank so ROM pointers are valid
    LDA >CURRENT_ROM_BANK
    PSHS A              ; Save current bank
    LDA >LEVEL_BANK
    STA >CURRENT_ROM_BANK
    STA $DF00           ; Switch to level bank
    
    ; Check if level is loaded
    TST >LEVEL_LOADED
    BEQ SLR_DONE     ; No level loaded, skip
    LDX >LEVEL_PTR
    
    ; Re-read object counts from header
    LEAX 12,X        ; X points to counts (+12)
    LDB ,X+          ; B = bgCount
    STB >LEVEL_BG_COUNT
    LDB ,X+          ; B = gpCount
    STB >LEVEL_GP_COUNT
    LDB ,X+          ; B = fgCount
    STB >LEVEL_FG_COUNT
    
    ; === Draw Background Layer (ROM, stride=20) ===
SLR_BG_COUNT:
    CLRB
    LDB >LEVEL_BG_COUNT
    CMPB #0
    BEQ SLR_GAMEPLAY
    LDA #20          ; ROM object stride
    LDX >LEVEL_BG_ROM_PTR
    JSR SLR_DRAW_OBJECTS
    
    ; === Draw Gameplay Layer (RAM, stride=15) ===
SLR_GAMEPLAY:
SLR_GP_COUNT:
    CLRB
    LDB >LEVEL_GP_COUNT
    CMPB #0
    BEQ SLR_FOREGROUND
    LDA #15          ; RAM object stride (15 bytes)
    LDX >LEVEL_GP_PTR
    JSR SLR_DRAW_OBJECTS
    
    ; === Draw Foreground Layer (ROM, stride=20) ===
SLR_FOREGROUND:
SLR_FG_COUNT:
    CLRB
    LDB >LEVEL_FG_COUNT
    CMPB #0
    BEQ SLR_DONE
    LDA #20          ; ROM object stride
    LDX >LEVEL_FG_ROM_PTR
    JSR SLR_DRAW_OBJECTS
    
SLR_DONE:
    ; MULTIBANK: Restore original bank
    PULS A              ; A = saved bank
    STA >CURRENT_ROM_BANK
    STA $DF00           ; Restore bank
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    PULS D,X,Y,U,PC  ; Restore and return
    
; === SLR_DRAW_OBJECTS - Draw N objects from a layer ===
; Input:  A = stride (15=RAM, 20=ROM), B = count, X = objects ptr
; For ROM objects (stride=20): intensity at +8, y FDB at +3, x FDB at +1, vector_ptr FDB at +16
; For RAM objects (stride=15): look up intensity from ROM via LEVEL_GP_ROM_PTR,
;   world_x at +0-1 (16-bit), y at +2, vector_ptr FDB at +11
; Camera: SUBD >CAMERA_X applied to world_x; objects outside i8 range are culled
SLR_DRAW_OBJECTS:
    PSHS A           ; Save stride on stack (A=stride)
SLR_OBJ_LOOP:
    TSTB
    LBEQ SLR_OBJ_DONE
    
    PSHS B           ; Save counter (LDD clobbers B)
    
    ; Determine ROM vs RAM offsets via stride
    LDA 1,S          ; Peek stride from stack (+1 because B is on top)
    CMPA #20
    BEQ SLR_ROM_OFFSETS
    
    ; === RAM object (stride=15) ===
    ; Need to look up intensity from ROM counterpart
    ; objIndex = LEVEL_GP_COUNT - currentCount
    PSHS X           ; Save RAM object pointer
    LDB >LEVEL_GP_COUNT
    SUBB 2,S         ; B = objIndex = totalCount - currentCounter
    LDX >LEVEL_GP_ROM_PTR  ; X = ROM base
SLR_ROM_ADDR_LOOP:
    BEQ SLR_INTENSITY_READ ; Done if index=0
    LEAX 20,X        ; Advance by ROM stride
    DECB
    BRA SLR_ROM_ADDR_LOOP
SLR_INTENSITY_READ:
    LDA 8,X          ; intensity at ROM +8
    STA >DRAW_VEC_INTENSITY  ; DP=$D0, must use extended addressing
    PULS X           ; Restore RAM object pointer
    
    CLR >MIRROR_X    ; DP=$D0, must use extended addressing
    CLR >MIRROR_Y
    ; Load world_x (16-bit), subtract CAMERA_X, check visibility
    LDD 0,X          ; RAM +0-1 = world_x (16-bit)
    SUBD >CAMERA_X   ; screen_x = world_x - camera_x
    STD >TMPVAL      ; save screen_x (overwritten by CMPB below)
    ; Per-object cull using half_width from RAM+13
    ; Wider culling: object stays until fully off-screen
    ; Visible range: [-(128+hw), 127+hw]
    ; right_limit = 127 + hw  (A=$00, B <= right_limit)
    ; left_limit  = 128 - hw  (A=$FF, B >= left_limit)
    LDB 13,X         ; B = half_width (RAM+13)
    STB >TMPPTR2     ; save hw
    LDA #127
    ADDA >TMPPTR2    ; A = 127 + hw (right boundary)
    STA >TMPPTR
    LDA #128
    SUBA >TMPPTR2    ; A = 128 - hw (left boundary, unsigned)
    STA >TMPPTR+1
    LDD >TMPVAL      ; restore screen_x into D
    TSTA
    BEQ SLR_RAM_A_ZERO
    INCA
    LBNE SLR_OBJ_NEXT        ; A not $FF: too far
    ; A=$FF: visible if B >= left_limit (128-hw)
    CMPB >TMPPTR+1
    BHS SLR_RAM_VISIBLE       ; unsigned >=
    LBRA SLR_OBJ_NEXT
SLR_RAM_A_ZERO:
    ; A=0: visible if B <= right_limit (127+hw)
    CMPB >TMPPTR
    BLS SLR_RAM_VISIBLE       ; unsigned <=
    LBRA SLR_OBJ_NEXT
SLR_RAM_VISIBLE:
    LDD >TMPVAL      ; reload full 16-bit screen_x (INCA corrupted A)
    STD >DRAW_VEC_X_HI ; store full 16-bit screen_x (A=hi, B=lo)
    LDB 2,X          ; y at RAM +2
    STB >DRAW_VEC_Y
    LDU 11,X         ; vector_ptr at RAM +11
    BRA SLR_DRAW_VECTOR
    
SLR_ROM_OFFSETS:
    ; === ROM object (stride=20) ===
    CLR >MIRROR_X    ; DP=$D0, must use extended addressing
    CLR >MIRROR_Y
    LDA 8,X          ; intensity at ROM +8
    STA >DRAW_VEC_INTENSITY
    LDD 3,X          ; y FDB at ROM +3; low byte into B
    STB >DRAW_VEC_Y  ; DP=$D0, must use extended addressing
    ; Load world_x (16-bit), subtract CAMERA_X, check visibility
    LDD 1,X          ; x FDB at ROM +1
    SUBD >CAMERA_X   ; screen_x = world_x - camera_x
    STD >TMPVAL
    ; Per-object cull: half_width at ROM+18
    ; Wider culling: object stays until fully off-screen
    LDB 18,X         ; B = half_width (ROM+18)
    STB >TMPPTR2     ; save hw
    LDA #127
    ADDA >TMPPTR2    ; A = 127 + hw (right boundary)
    STA >TMPPTR
    LDA #128
    SUBA >TMPPTR2    ; A = 128 - hw (left boundary)
    STA >TMPPTR+1
    LDD >TMPVAL
    TSTA
    BEQ SLR_ROM_A_ZERO
    INCA
    LBNE SLR_OBJ_NEXT
    CMPB >TMPPTR+1
    BHS SLR_ROM_VISIBLE
    LBRA SLR_OBJ_NEXT
SLR_ROM_A_ZERO:
    CMPB >TMPPTR
    BLS SLR_ROM_VISIBLE
    LBRA SLR_OBJ_NEXT
SLR_ROM_VISIBLE:
    LDD >TMPVAL      ; reload full 16-bit screen_x (INCA corrupted A)
    STD >DRAW_VEC_X_HI ; store full 16-bit screen_x (A=hi, B=lo)
    LDU 16,X         ; vector_ptr FDB at ROM +16
    
SLR_DRAW_VECTOR:
    PSHS X           ; Save object pointer
    TFR U,X          ; X = vector data pointer (header)
    
    ; Read path_count from vector header byte 0
    LDB ,X+          ; B = path_count, X now at pointer table
    
    ; DP is already $D0 (set by SHOW_LEVEL_RUNTIME at entry)
SLR_PATH_LOOP:
    TSTB
    BEQ SLR_PATH_DONE
    DECB
    PSHS B           ; Save decremented count
    LDU ,X++         ; U = path pointer, X advances to next entry
    PSHS X           ; Save pointer table position
    TFR U,X          ; X = actual path data
    JSR SLR_DRAW_CLIPPED_PATH
    PULS X           ; Restore pointer table position
    PULS B           ; Restore count
    BRA SLR_PATH_LOOP
    
SLR_PATH_DONE:
    PULS X           ; Restore object pointer
    
SLR_OBJ_NEXT:
    ; Advance to next object using stride
    ; Reached here after draw (X restored by PULS X above) OR from
    ; visibility skip (X never pushed, still points to current object)
    ; Stack state in both cases: B on top, A=stride below
    LDA 1,S          ; Load stride from stack (+1 because B is on top)
    LEAX A,X         ; X += stride
    
    PULS B           ; Restore counter
    DECB
    LBRA SLR_OBJ_LOOP
    
SLR_OBJ_DONE:
    PULS A           ; Clean up stride from stack
    RTS

; === SLR_DRAW_CLIPPED_PATH ===
; Per-segment X-axis clipping using direct VIA register writes.
; Mirrors the DSWM VIA pattern — no BIOS calls (Intensity_a corrupts
; DDRB with DP=$D0; Draw_Line_d / Moveto_d are BIOS-only).
; Segments whose new_x = cur_x+dx overflows a signed byte are moved
; with beam OFF, preventing screen-wrap at left/right edges.
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
    STB >TMPVAL             ; save abs_y for moveto
    TFR A,B                 ; B = x_start (SEX extends B, not A)
    SEX                      ; sign-extend B→D (A=sign, B=x_start)
    ADDD >DRAW_VEC_X_HI     ; D = abs_x_16 = SEX(x_start) + screen_x_16
    ; Range check: abs_x must fit in signed byte [-128, +127]
    ; If out of range, skip this path (can't position beam correctly).
    ; Progressive clipping works because paths starting on-screen are
    ; drawn normally, and their segments get clipped at the edge.
    TSTA
    BEQ SDCP_CHECK_POS       ; A=$00 → check positive range
    INCA                      ; was A=$FF?
    BNE SDCP_SKIP_PATH        ; A was not $00 or $FF → way off
    ; A was $FF: valid if B >= $80 (negative signed byte)
    CMPB #$80
    BHS SDCP_ABS_OK
    BRA SDCP_SKIP_PATH
SDCP_CHECK_POS:
    ; A=$00: valid if B <= $7F
    CMPB #$7F
    BLS SDCP_ABS_OK
SDCP_SKIP_PATH:
    RTS
SDCP_ABS_OK:
    ; B = abs_x (valid signed byte)
    TFR B,A                  ; A = abs_x for moveto
    STA >SLR_CUR_X          ; init beam-x tracker
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
    LDB >TMPVAL             ; B = abs_y
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
    LDA #$7F
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
    BEQ SDCP_DONE
    ; Read dy → B, dx → A (DSWM order)
    LDB ,X+                 ; B = dy
    LDA ,X+                 ; A = dx
    ; --- X-axis clip check: new_x = cur_x + dx ---
    STB >TMPPTR2            ; save dy
    PSHS A                  ; push dx
    LDA >SLR_CUR_X
    ADDA ,S                 ; A = cur_x + dx; V set on overflow
    BVS SDCP_CLIP           ; overflow → clip
    STA >SLR_CUR_X          ; update tracker
    PULS A                  ; restore dx
    LDB >TMPPTR2            ; restore dy
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
    BRA SDCP_SEG_LOOP
SDCP_CLIP:
    STA >SLR_CUR_X          ; store wrapped x (approx)
    PULS A                  ; restore dx
    LDB >TMPPTR2            ; restore dy
    STB VIA_port_a          ; DY → DAC
    CLR VIA_port_b
    NOP
    NOP
    NOP
    INC VIA_port_b
    STA VIA_port_a          ; DX → DAC
    ; beam stays OFF (no STA VIA_shift_reg)
    CLR VIA_t1_cnt_hi       ; start T1 (ramp, beam off)
SDCP_W_MOVE:
    LDA VIA_int_flags
    ANDA #$40
    BEQ SDCP_W_MOVE
    BRA SDCP_SEG_LOOP
SDCP_DONE:
    RTS

; === UPDATE_LEVEL_RUNTIME ===
; Update level physics: apply velocity, gravity, bounce walls
; GP-GP elastic collisions and GP-FG static collisions
; Only the GP layer (RAM buffer) is updated — BG/FG are static ROM.
UPDATE_LEVEL_RUNTIME:
    PSHS U,X,Y,D     ; Preserve all registers
    ; MULTIBANK: Switch to level bank so FG ROM pointers are valid
    LDA >CURRENT_ROM_BANK
    PSHS A              ; Save current bank
    LDA >LEVEL_BANK
    STA >CURRENT_ROM_BANK
    STA $DF00           ; Switch to level bank
    
    ; === Update Gameplay Objects ===
    LDB >LEVEL_GP_COUNT
    CMPB #0
    LBEQ ULR_EXIT    ; No objects
    LDU >LEVEL_GP_PTR  ; U = GP buffer (RAM)
    BSR ULR_UPDATE_LAYER
    
    ; === GP-to-GP Elastic Collisions ===
    JSR ULR_GAMEPLAY_COLLISIONS
    ; === GP vs FG Static Collisions ===
    JSR ULR_GP_FG_COLLISIONS
    
ULR_EXIT:
    ; MULTIBANK: Restore original bank
    PULS A              ; A = saved bank
    STA >CURRENT_ROM_BANK
    STA $DF00           ; Restore bank
    PULS D,Y,X,U     ; Restore registers
    RTS

; === ULR_UPDATE_LAYER - Apply physics to each object in GP buffer ===
; Input: B = object count, U = buffer base (15 bytes/object)
; RAM object layout:
;   +0-1: world_x(i16)  +2: y(i8)  +3: scale  +4: rotation
;   +5: velocity_x  +6: velocity_y  +7: physics_flags  +8: collision_flags
;   +9: collision_size  +10: spawn_delay_lo  +11-12: vector_ptr  +13-14: props_ptr
ULR_UPDATE_LAYER:
    TST >LEVEL_LOADED
    LBEQ ULR_LAYER_EXIT  ; No level loaded, skip
    LDX >LEVEL_PTR   ; Load level pointer for world bounds
    
ULR_LOOP:
    PSHS B           ; Save loop counter
    
    ; Check physics_flags (RAM +7)
    LDB 7,U
    CMPB #0
    LBEQ ULR_NEXT    ; No physics at all, skip
    
    ; Check dynamic bit (bit 0)
    BITB #$01
    LBEQ ULR_NEXT    ; Not dynamic, skip
    
    ; Check gravity bit (bit 1)
    BITB #$02
    LBEQ ULR_NO_GRAVITY
    
    ; Apply gravity: velocity_y -= 1, clamp to -15
    LDB 6,U          ; velocity_y (RAM +6)
    DECB
    CMPB #$F1        ; -15
    BGE ULR_VY_OK
    LDB #$F1
ULR_VY_OK:
    STB 6,U
    
ULR_NO_GRAVITY:
    ; Apply velocity: world_x += velocity_x (16-bit)
    LDD 0,U          ; world_x (16-bit signed)
    TFR D,Y          ; Y = world_x
    LDB 5,U          ; velocity_x (8-bit signed)
    SEX              ; D = sign-extended velocity_x
    LEAY D,Y         ; Y = world_x + velocity_x (16-bit addition)
    TFR Y,D          ; D = new world_x
    STD 0,U          ; Store 16-bit world_x
    
    ; Apply velocity: y += velocity_y (16-bit to avoid wraparound)
    LDB 2,U          ; y (8-bit signed, RAM +2)
    SEX              ; D = sign-extended y
    TFR D,Y          ; Y = y (16-bit)
    LDB 6,U          ; velocity_y (8-bit signed, RAM +6)
    SEX              ; D = sign-extended velocity_y
    LEAY D,Y         ; Y = y + velocity_y (16-bit addition)
    TFR Y,D          ; D = 16-bit result
    CMPD #127        ; Clamp to i8 max
    BLE ULR_Y_NOT_MAX
    LDD #127
ULR_Y_NOT_MAX:
    CMPD #-128       ; Clamp to i8 min
    BGE ULR_Y_NOT_MIN
    LDD #-128
ULR_Y_NOT_MIN:
    STB 2,U          ; Store clamped y (RAM +2)
    
    ; === World Bounds / Wall Bounce ===
    LDB 8,U          ; collision_flags (RAM +8)
    BITB #$02        ; bounce_walls flag (bit 1)
    LBEQ ULR_NEXT    ; Skip if not bouncing
    
    ; LDX already loaded = LEVEL_PTR
    ; World bounds at LEVEL_PTR: +0=xMin(FDB), +2=xMax(FDB), +4=yMin(FDB), +6=yMax(FDB)
    
    ; --- Check X left wall (xMin) ---
    LDB 9,U          ; collision_size (RAM +9)
    SEX              ; D = sign-extended collision_size
    PSHS D           ; Save collision_size
    LDD 0,U          ; world_x (16-bit)
    SUBD ,S++        ; D = world_x - collision_size (left edge), pop
    CMPD 0,X         ; Compare with xMin
    LBGE ULR_X_MAX_CHECK
    ; Hit left wall — bounce only if moving left (velocity_x < 0)
    LDB 5,U
    CMPB #0
    LBGE ULR_X_MAX_CHECK
    LDB 9,U          ; collision_size
    SEX
    ADDD 0,X         ; D = xMin + collision_size
    STD 0,U          ; world_x = corrected position (16-bit)
    LDB 5,U
    NEGB
    STB 5,U          ; velocity_x = -velocity_x
    
    ; --- Check X right wall (xMax) ---
ULR_X_MAX_CHECK:
    LDB 9,U
    SEX
    PSHS D
    LDD 0,U          ; world_x (16-bit)
    ADDD ,S++        ; D = world_x + collision_size (right edge), pop
    CMPD 2,X         ; Compare with xMax
    LBLE ULR_Y_BOUNDS
    ; Hit right wall — bounce only if moving right (velocity_x > 0)
    LDB 5,U
    CMPB #0
    LBLE ULR_Y_BOUNDS
    LDB 9,U
    SEX
    TFR D,Y
    LDD 2,X          ; D = xMax
    PSHS Y
    SUBD ,S++        ; D = xMax - collision_size, pop
    STD 0,U          ; world_x = corrected position (16-bit)
    LDB 5,U
    NEGB
    STB 5,U
    
    ; --- Check Y bottom wall (yMin) ---
ULR_Y_BOUNDS:
    LDB 9,U
    SEX
    PSHS D
    LDB 2,U          ; y (8-bit, RAM +2)
    SEX
    SUBD ,S++        ; D = y - collision_size, pop
    CMPD 4,X         ; Compare with yMin
    LBGE ULR_Y_MAX_CHECK
    LDB 6,U
    CMPB #0
    LBGE ULR_Y_MAX_CHECK
    LDB 9,U
    SEX
    ADDD 4,X         ; D = yMin + collision_size
    STB 2,U          ; y = low byte (RAM +2)
    LDB 6,U
    NEGB
    STB 6,U
    
    ; --- Check Y top wall (yMax) ---
ULR_Y_MAX_CHECK:
    LDB 9,U
    SEX
    PSHS D
    LDB 2,U          ; y (8-bit, RAM +2)
    SEX
    ADDD ,S++        ; D = y + collision_size, pop
    CMPD 6,X         ; Compare with yMax
    LBLE ULR_NEXT
    LDB 6,U
    CMPB #0
    LBLE ULR_NEXT
    LDB 9,U
    SEX
    TFR D,Y
    LDD 6,X          ; D = yMax
    PSHS Y
    SUBD ,S++        ; D = yMax - collision_size, pop
    STB 2,U          ; y = low byte (RAM +2)
    LDB 6,U
    NEGB
    STB 6,U
    
ULR_NEXT:
    PULS B           ; Restore loop counter
    LEAU 15,U        ; Next object (15 bytes)
    DECB
    LBNE ULR_LOOP
    
ULR_LAYER_EXIT:
    RTS

; === ULR_GAMEPLAY_COLLISIONS - GP-to-GP elastic collisions ===
; Checks all pairs of GP objects; swaps velocities on collision.
; Uses Manhattan distance for speed. RAM indices via UGPC_ vars.
ULR_GAMEPLAY_COLLISIONS:
    LDA >LEVEL_GP_COUNT
    CMPA #2
    BHS UGPC_START
    RTS              ; Need at least 2 objects
UGPC_START:
    DECA
    STA UGPC_OUTER_MAX
    CLR UGPC_OUTER_IDX
    
UGPC_OUTER_LOOP:
    ; U = LEVEL_GP_BUFFER + (UGPC_OUTER_IDX * 15)
    LDU #LEVEL_GP_BUFFER
    LDB UGPC_OUTER_IDX
    BEQ UGPC_SKIP_OUTER_MUL
UGPC_OUTER_MUL:
    LEAU 15,U
    DECB
    BNE UGPC_OUTER_MUL
UGPC_SKIP_OUTER_MUL:
    ; Check if outer object is collidable (collision_flags bit 0 at RAM +8)
    LDB 8,U
    BITB #$01
    LBEQ UGPC_NEXT_OUTER
    
    LDA UGPC_OUTER_IDX
    INCA
    STA UGPC_INNER_IDX
    
UGPC_INNER_LOOP:
    LDA UGPC_INNER_IDX
    CMPA >LEVEL_GP_COUNT
    LBHS UGPC_INNER_DONE
    
    ; Y = LEVEL_GP_BUFFER + (UGPC_INNER_IDX * 15)
    LDY #LEVEL_GP_BUFFER
    LDB UGPC_INNER_IDX
    BEQ UGPC_SKIP_INNER_MUL
UGPC_INNER_MUL:
    LEAY 15,Y
    DECB
    BNE UGPC_INNER_MUL
UGPC_SKIP_INNER_MUL:
    ; Check inner collidable (RAM +8)
    LDB 8,Y
    BITB #$01
    LBEQ UGPC_NEXT_INNER
    
    ; Manhattan distance: |x1-x2| + |y1-y2|
    ; Use low byte of world_x (RAM +1) for approximate screen-relative collision
    ; Compute |dx| = |x1 - x2|
    LDB 1,U          ; x1 low byte (8-bit at RAM +1)
    SEX
    PSHS D           ; Save x1 (16-bit)
    LDB 1,Y          ; x2 low byte (8-bit at RAM +1)
    SEX
    TFR D,X
    PULS D           ; D = x1
    PSHS X
    TFR X,D          ; D = x2
    PULS X
    PSHS D           ; Push x2
    LDB 1,U
    SEX
    SUBD ,S++        ; x1 - x2, pop
    BPL UGPC_DX_POS
    COMA
    COMB
    ADDD #1          ; negate
UGPC_DX_POS:
    STD UGPC_DX
    
    ; Compute |dy| = |y1 - y2|
    LDB 2,U          ; y1 (8-bit at RAM +2)
    SEX
    PSHS D
    LDB 2,Y          ; y2 (8-bit at RAM +2)
    SEX
    TFR D,X
    PULS D
    PSHS X
    TFR X,D
    PULS X
    PSHS D           ; Push y2
    LDB 2,U
    SEX
    SUBD ,S++        ; y1 - y2, pop
    BPL UGPC_DY_POS
    COMA
    COMB
    ADDD #1
UGPC_DY_POS:
    ADDD UGPC_DX     ; D = |dx| + |dy|
    STD UGPC_DIST
    
    ; Sum of radii
    LDB 9,U          ; collision_size obj1 (RAM +9)
    ADDB 9,Y         ; + collision_size obj2
    SEX              ; D = sum_radius
    CMPD UGPC_DIST
    LBHI UGPC_COLLISION
    LBRA UGPC_NEXT_INNER
    
UGPC_COLLISION:
    ; Elastic collision: swap velocities
    LDA 5,U          ; vel_x obj1 (RAM +5)
    LDB 5,Y          ; vel_x obj2 (RAM +5)
    STB 5,U
    STA 5,Y
    LDA 6,U          ; vel_y obj1 (RAM +6)
    LDB 6,Y          ; vel_y obj2 (RAM +6)
    STB 6,U
    STA 6,Y
    
UGPC_NEXT_INNER:
    INC UGPC_INNER_IDX
    LBRA UGPC_INNER_LOOP
    
UGPC_INNER_DONE:
UGPC_NEXT_OUTER:
    INC UGPC_OUTER_IDX
    LDA UGPC_OUTER_IDX
    CMPA UGPC_OUTER_MAX
    LBHI UGPC_EXIT
    LBRA UGPC_OUTER_LOOP
    
UGPC_EXIT:
    RTS
    
; === ULR_GP_FG_COLLISIONS - GP objects vs static FG ROM collidables ===
; For each GP object (RAM, collidable) check against each FG (ROM, collidable).
; Axis-split bounce: |dy|>|dx| → negate vy; else → negate vx.
; FG ROM offsets: +0=type, +1-2=x FDB, +3-4=y FDB, +12=collision_flags, +13=collision_size
ULR_GP_FG_COLLISIONS:
    LDA >LEVEL_FG_COUNT
    LBEQ UGFC_EXIT
    STA UGFC_FG_COUNT
    LDA >LEVEL_GP_COUNT
    LBEQ UGFC_EXIT
    CLR UGFC_GP_IDX
    
UGFC_GP_LOOP:
    ; U = LEVEL_GP_BUFFER + (UGFC_GP_IDX * 15)
    LDU #LEVEL_GP_BUFFER
    LDB UGFC_GP_IDX
    BEQ UGFC_GP_ADDR_DONE
UGFC_GP_MUL:
    LEAU 15,U
    DECB
    BNE UGFC_GP_MUL
UGFC_GP_ADDR_DONE:
    ; Check GP collidable (collision_flags bit 0 at RAM +8)
    LDB 8,U
    BITB #$01
    LBEQ UGFC_NEXT_GP
    
    ; Walk FG ROM objects
    LDX >LEVEL_FG_ROM_PTR
    LDB UGFC_FG_COUNT
    
UGFC_FG_LOOP:
    CMPB #0
    LBEQ UGFC_NEXT_GP
    ; Check FG collidable (ROM +12 = collision_flags)
    LDA 12,X
    BITA #$01
    BEQ UGFC_NEXT_FG
    
    ; |dx| = |GP.x_lo - FG.x_lo|  (GP RAM +1, FG ROM +2)
    LDA 1,U          ; GP x low byte (RAM +1, world_x low byte)
    SUBA 2,X         ; A = GP.x_lo - FG.x_lo
    BPL UGFC_DX_POS
    NEGA
UGFC_DX_POS:
    STA UGFC_DX
    
    ; |dy| = |GP.y - FG.y_lo|  (GP RAM +2, FG ROM +4)
    LDA 2,U          ; GP y (RAM +2)
    SUBA 4,X         ; A = GP.y - FG.y_lo
    BPL UGFC_DY_POS
    NEGA
UGFC_DY_POS:
    STA UGFC_DY
    
    ; sum_r = GP.collision_size + FG.collision_size
    LDA 9,U          ; GP collision_size (RAM +9)
    ADDA 13,X        ; + FG collision_size (ROM +13)
    
    ; Collision if |dx| + |dy| < sum_r
    PSHS A           ; Save sum_r
    LDA UGFC_DX
    ADDA UGFC_DY
    CMPA ,S+         ; Compare distance with sum_r (pop)
    BHS UGFC_NEXT_FG ; No collision
    
    ; COLLISION! Axis-split by velocity: |vy|>|vx| → vert bounce, else horiz bounce
    LDA 6,U          ; velocity_y (RAM +6)
    BPL UGFC_VY_ABS
    NEGA
UGFC_VY_ABS:
    STA UGFC_DY      ; |vy|
    LDA 5,U          ; velocity_x (RAM +5)
    BPL UGFC_VX_ABS
    NEGA
UGFC_VX_ABS:
    CMPA UGFC_DY     ; |vx| vs |vy|
    BLT UGFC_VERT_BOUNCE ; |vx| < |vy| → vert bounce
    
UGFC_HORIZ_BOUNCE:
    LDA 5,U          ; velocity_x (RAM +5)
    NEGA
    STA 5,U
    LDA 9,U          ; collision_size (RAM +9)
    ADDA 13,X
    PSHS A           ; Save separation
    LDA 1,U          ; x low byte (RAM +1)
    CMPA 2,X
    BLT UGFC_PUSH_LEFT
    LDA 2,X
    ADDA ,S+
    STA 1,U          ; store back x low byte (RAM +1)
    BRA UGFC_NEXT_FG
UGFC_PUSH_LEFT:
    LDA 2,X
    SUBA ,S+
    STA 1,U          ; store back x low byte (RAM +1)
    BRA UGFC_NEXT_FG
    
UGFC_VERT_BOUNCE:
    LDA 6,U          ; velocity_y (RAM +6)
    NEGA
    STA 6,U
    LDA 9,U          ; collision_size (RAM +9)
    ADDA 13,X
    PSHS A
    LDA 2,U          ; y (RAM +2)
    CMPA 4,X
    BLT UGFC_PUSH_DOWN
    LDA 4,X
    ADDA ,S+
    STA 2,U          ; store back y (RAM +2)
    BRA UGFC_NEXT_FG
UGFC_PUSH_DOWN:
    LDA 4,X
    SUBA ,S+
    STA 2,U          ; store back y (RAM +2)
    
UGFC_NEXT_FG:
    LEAX 20,X        ; Next FG object (ROM stride 20)
    DECB
    LBRA UGFC_FG_LOOP
    
UGFC_NEXT_GP:
    INC UGFC_GP_IDX
    LDA UGFC_GP_IDX
    CMPA >LEVEL_GP_COUNT
    LBLO UGFC_GP_LOOP
    
UGFC_EXIT:
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
PRINT_TEXT_STR_84327:
    FCC "USE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2188049:
    FCC "GIVE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2567303:
    FCC "TAKE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_100361836:
    FCC "intro"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3309214433:
    FCC "player"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_63819514689:
    FCC "EXAMINE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1863858565675:
    FCC "AT LAST."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2020710997544:
    FCC "GIVE:EYE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2020711002710:
    FCC "GIVE:KEY"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2020711006665:
    FCC "GIVE:OIL"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2376966947138:
    FCC "THE END."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2769766737209:
    FCC "anteroom"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2879828691638:
    FCC "entrance"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_62642040964184:
    FCC "GIVE:GEAR"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_62642041113543:
    FCC "GIVE:LENS"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_64485404977468:
    FCC "INVENTORY"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_69586596903166:
    FCC "ONE FREED"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_76166780098692:
    FCC "WEIGHT OK"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_87209113363546:
    FCC "caretaker"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_87509024548329:
    FCC "clockroom"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_91568903647484:
    FCC "heartbeat"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1941903265492996:
    FCC "GIVE:BLNKT"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1941903278596472:
    FCC "GIVE:PRISM"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1941903281064854:
    FCC "GIVE:SHEET"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2290510677130451:
    FCC "TOO HEAVY."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2718184010937820:
    FCC "crypt_logo"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3033609450579156:
    FCC "optics_lab"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_56162530743028252:
    FCC "BLANKET  W0"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_56993795800368113:
    FCC "CLOCK LIES."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_58967237406000075:
    FCC "EYE      W1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_60075665603304044:
    FCC "GEAR     W2"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_64184922134308892:
    FCC "LENS     W1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_64184923654817225:
    FCC "LENS TAKEN."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_66746456558499436:
    FCC "OIL      W1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_67802925852799259:
    FCC "PRISM    W1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_69993623963913400:
    FCC "SHEET    W0"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_70966799469806525:
    FCC "TO FREEDOM."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_71091249681780729:
    FCC "TRUE ENDING"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_72649866947832674:
    FCC "VOSS KEY W1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_84995521868454133:
    FCC "door_unlock"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_85730742593925120:
    FCC "elisa_ghost"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_86053808672632355:
    FCC "exploration"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_89217194792681768:
    FCC "item_pickup"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_94739863040905703:
    FCC "platform_up"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_94999312012949119:
    FCC "puzzle_fail"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_561378197138974931:
    FCC "NEEDS VOSS KEY."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_679393960477689362:
    FCC "SOME THINGS CANNOT"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_894489252191113018:
    FCC "THE VAULTED DARK."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1294369330382807152:
    FCC "DEPOSIT ITEMS."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1357395807964332428:
    FCC "* OVERWEIGHT *"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1423984413427534561:
    FCC "B2:INV    B3:VERB"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1694552686414567337:
    FCC "ELISA'S SONG FILLS"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1862347038366201699:
    FCC "GEARS TAKEN."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1961155566409942910:
    FCC "JOY:MOVE  B1:ACT"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2040298819312631916:
    FCC "NEED A CLUE."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2040300194473462220:
    FCC "NEEDS MUSIC."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2502506564742786359:
    FCC "DAWN WAITS OUTSIDE."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2609427276926758987:
    FCC "conservatory"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2725988333465993402:
    FCC "FIND CLUES. SOLVE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2980434551938874269:
    FCC "VOSS 1887. NO EYE."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3054387366258387060:
    FCC "IT IS A SPRING TO WIND."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3109258183406850463:
    FCC "weights_room"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3134159664534957280:
    FCC "YOUR MIND STAYS IN,"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3317733282004581041:
    FCC "PRESS B1 TO START"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3443128850001289426:
    FCC "HOLLOW ESCAPE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3569223757657551064:
    FCC "SARC. HOUR LOCK."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3688976395448209650:
    FCC "THE MECHANISM HALTS."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_4088011977317884966:
    FCC "KONRAD VOSS IS DEAD."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_4134672786914975283:
    FCC "11:07. BLNKT+KEY!"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_4475750633065476197:
    FCC "NO ITEM SELECTED."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_4588030343759193236:
    FCC "HIS WINDING CLOCK."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_4750152274843692088:
    FCC "ELISA'S CURSE LIFTS."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_4810967809196323313:
    FCC "THE CRYPT SEALED."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_5194980316262412902:
    FCC "WORKSHOP BEYOND."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_5266085525079663479:
    FCC "4-DIGIT LOCK."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_5393684617976031258:
    FCC "crystal_apprentice"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_5995724771220415910:
    FCC "PUZZLES. ESCAPE."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_6038144227778049379:
    FCC "WHALE OIL CAN."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_6391486935903418068:
    FCC "B3:SEL B1:EQUIP"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_6491622880375508119:
    FCC "OPTICS LAB LOCKED."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_6586363433779781634:
    FCC "BE WOUND DOWN."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_6894498445181154440:
    FCC "A NEW HOME IN YOU."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_6950660334503696963:
    FCC "OLD SHEET MUSIC."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_7582700907259536897:
    FCC "WARM. OPTICS OPEN."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_7616489895533870322:
    FCC "HIDDEN COMPARTMENT."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_7772660912310229250:
    FCC "puzzle_success"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_7909031177940311606:
    FCC "NEED A PRISM."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_7909073815850340594:
    FCC "NEEDS WARMTH."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_8058628335699392711:
    FCC "YOUR BODY WALKS OUT."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_8802356165028628829:
    FCC "wall_compartment"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_9013778969627065598:
    FCC "FIND CLUE FIRST."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_9120385760502433312:
    FCC "PRESS BUTTON 1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_9259163830802518359:
    FCC "vault_corridor"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_9347069291597612016:
    FCC "A GLASS PRISM."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_9679949307385682704:
    FCC "SMALL SIDE DOOR."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_10687858946875495377:
    FCC "hans_automata"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_11231926301297463383:
    FCC "TICK... NEED OIL..."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_11476744573813328057:
    FCC "BALANCE SHIFTS."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_11654038037461762538:
    FCC "THE CRYPT IS SILENT"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_11740726934691799833:
    FCC "DIARY: LENS INSIDE."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_12512026909897550613:
    FCC "PANEL SLIDES OPEN!"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_12688323002745966939:
    FCC "1-8-8-7. OPENS!"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_12694600541101677361:
    FCC "TIME IS NOT A RIVER."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_12942139072472107330:
    FCC "ALREADY TOOK IT."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_12951030068845256446:
    FCC "VAULT UNSEALED!"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_13801705626177845190:
    FCC "SHE SMILES. C-E-G."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_14011047070412848655:
    FCC "CANNOT DO THAT."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_14122068582122076643:
    FCC "VAULT AWAITS."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_14476289871539234619:
    FCC "VOSS IS DEAD."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_14647010181714948705:
    FCC "TRIES TO SING."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_15001388746321493806:
    FCC "WEIGHTS ROOM."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_15031599020925928582:
    FCC "THE CRYPT OPENS."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_15031601608756456041:
    FCC "THE CRYSTAL EYE!"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_15373067420087200981:
    FCC "BTN1 TO RESTART"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_15647433387823626580:
    FCC "LONG LIVE THE MECHANISM."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_16142505063574718582:
    FCC "NEED LENS FIRST."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_16477571072303887030:
    FCC "WANTS THE GEARS."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_16517487495056338189:
    FCC "PRISM MOUNT. EMPTY."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_16762347117432342118:
    FCC "WOUND LIKE A SPRING."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_16812907733027968162:
    FCC "BARELY ALIVE."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17028423667663067371:
    FCC "YOU ARE THE ASSESSOR."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17236580857328069985:
    FCC "HANS NEEDS OIL."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17258032087471670510:
    FCC "platform_down"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17345789615299082788:
    FCC "HANS FINDS HIS REST."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17643359177242884552:
    FCC "HANS TICKS ON ALONE."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17850884399050856369:
    FCC "SWITZERLAND, 1887."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17877550292306147137:
    FCC "CLOCK: 11:07."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17954386693183881976:
    FCC "THE TICKING FOUND"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_18135904787860682873:
    FCC "YOU FOLLOW HER VOICE"
    FCB $80          ; Vectrex string terminator

;**** PRINT_MSG Dispatch ****
PRINT_MSG_DISPATCH:
    ; VAR_ARG0 = msg_id (set by PRINT_MSG caller)
    LDB VAR_ARG0+1      ; B = msg_id (low byte)
    BEQ PRINT_MSG_SKIP  ; id=0 → nothing to print
    DECB                ; 0-based index (id starts at 1)
    LSLB               ; B = index * 2
    LSLB               ; B = index * 4
    LDX #PRINT_MSG_TABLE
    ABX                ; X = &table[index * 4]
    LDB ,X+            ; B = x (signed byte)
    SEX                ; D = sign-extended x
    STD VAR_ARG0
    LDB ,X+            ; B = y (signed byte)
    SEX                ; D = sign-extended y
    STD VAR_ARG1
    LDX ,X             ; X = string pointer
    STX VAR_ARG2
    JMP VECTREX_PRINT_TEXT  ; tail call (no RTS needed)
PRINT_MSG_SKIP:
    RTS

PRINT_MSG_TABLE:
    ; 4 bytes/entry: x(signed), y(signed), string_ptr(2)
    FCB -70  ; msg 1 x
    FCB 114  ; msg 1 y
    FDB PRINT_TEXT_STR_2980434551938874269  ; msg 1 "VOSS 1887. NO EYE."
    FCB -63  ; msg 2 x
    FCB 114  ; msg 2 y
    FDB PRINT_TEXT_STR_5266085525079663479  ; msg 2 "4-DIGIT LOCK."
    FCB -63  ; msg 3 x
    FCB 114  ; msg 3 y
    FDB PRINT_TEXT_STR_2040298819312631916  ; msg 3 "NEED A CLUE."
    FCB -70  ; msg 4 x
    FCB 114  ; msg 4 y
    FDB PRINT_TEXT_STR_12688323002745966939  ; msg 4 "1-8-8-7. OPENS!"
    FCB -70  ; msg 5 x
    FCB 114  ; msg 5 y
    FDB PRINT_TEXT_STR_14011047070412848655  ; msg 5 "CANNOT DO THAT."
    FCB -63  ; msg 6 x
    FCB 114  ; msg 6 y
    FDB PRINT_TEXT_STR_3569223757657551064  ; msg 6 "SARC. HOUR LOCK."
    FCB -77  ; msg 7 x
    FCB 114  ; msg 7 y
    FDB PRINT_TEXT_STR_4134672786914975283  ; msg 7 "11:07. BLNKT+KEY!"
    FCB -70  ; msg 8 x
    FCB 114  ; msg 8 y
    FDB PRINT_TEXT_STR_17877550292306147137  ; msg 8 "CLOCK: 11:07."
    FCB -63  ; msg 9 x
    FCB 114  ; msg 9 y
    FDB PRINT_TEXT_STR_11740726934691799833  ; msg 9 "DIARY: LENS INSIDE."
    FCB -63  ; msg 10 x
    FCB 114  ; msg 10 y
    FDB PRINT_TEXT_STR_64184923654817225  ; msg 10 "LENS TAKEN."
    FCB -63  ; msg 11 x
    FCB 114  ; msg 11 y
    FDB PRINT_TEXT_STR_12942139072472107330  ; msg 11 "ALREADY TOOK IT."
    FCB -63  ; msg 12 x
    FCB 114  ; msg 12 y
    FDB PRINT_TEXT_STR_15001388746321493806  ; msg 12 "WEIGHTS ROOM."
    FCB -70  ; msg 13 x
    FCB 114  ; msg 13 y
    FDB PRINT_TEXT_STR_1294369330382807152  ; msg 13 "DEPOSIT ITEMS."
    FCB -63  ; msg 14 x
    FCB 114  ; msg 14 y
    FDB PRINT_TEXT_STR_11476744573813328057  ; msg 14 "BALANCE SHIFTS."
    FCB -63  ; msg 15 x
    FCB 114  ; msg 15 y
    FDB PRINT_TEXT_STR_5194980316262412902  ; msg 15 "WORKSHOP BEYOND."
    FCB -56  ; msg 16 x
    FCB 114  ; msg 16 y
    FDB PRINT_TEXT_STR_2290510677130451  ; msg 16 "TOO HEAVY."
    FCB -70  ; msg 17 x
    FCB 114  ; msg 17 y
    FDB PRINT_TEXT_STR_16517487495056338189  ; msg 17 "PRISM MOUNT. EMPTY."
    FCB -63  ; msg 18 x
    FCB 114  ; msg 18 y
    FDB PRINT_TEXT_STR_7909031177940311606  ; msg 18 "NEED A PRISM."
    FCB -63  ; msg 19 x
    FCB 114  ; msg 19 y
    FDB PRINT_TEXT_STR_12512026909897550613  ; msg 19 "PANEL SLIDES OPEN!"
    FCB -70  ; msg 20 x
    FCB 114  ; msg 20 y
    FDB PRINT_TEXT_STR_7616489895533870322  ; msg 20 "HIDDEN COMPARTMENT."
    FCB -63  ; msg 21 x
    FCB 114  ; msg 21 y
    FDB PRINT_TEXT_STR_15031601608756456041  ; msg 21 "THE CRYSTAL EYE!"
    FCB -63  ; msg 22 x
    FCB 114  ; msg 22 y
    FDB PRINT_TEXT_STR_16142505063574718582  ; msg 22 "NEED LENS FIRST."
    FCB -56  ; msg 23 x
    FCB 114  ; msg 23 y
    FDB PRINT_TEXT_STR_9013778969627065598  ; msg 23 "FIND CLUE FIRST."
    FCB -70  ; msg 24 x
    FCB 114  ; msg 24 y
    FDB PRINT_TEXT_STR_16812907733027968162  ; msg 24 "BARELY ALIVE."
    FCB -63  ; msg 25 x
    FCB 114  ; msg 25 y
    FDB PRINT_TEXT_STR_1862347038366201699  ; msg 25 "GEARS TAKEN."
    FCB -63  ; msg 26 x
    FCB 114  ; msg 26 y
    FDB PRINT_TEXT_STR_7582700907259536897  ; msg 26 "WARM. OPTICS OPEN."
    FCB -63  ; msg 27 x
    FCB 114  ; msg 27 y
    FDB PRINT_TEXT_STR_11231926301297463383  ; msg 27 "TICK... NEED OIL..."
    FCB -70  ; msg 28 x
    FCB 114  ; msg 28 y
    FDB PRINT_TEXT_STR_56993795800368113  ; msg 28 "CLOCK LIES."
    FCB -70  ; msg 29 x
    FCB 114  ; msg 29 y
    FDB PRINT_TEXT_STR_14647010181714948705  ; msg 29 "TRIES TO SING."
    FCB -63  ; msg 30 x
    FCB 114  ; msg 30 y
    FDB PRINT_TEXT_STR_13801705626177845190  ; msg 30 "SHE SMILES. C-E-G."
    FCB -70  ; msg 31 x
    FCB 114  ; msg 31 y
    FDB PRINT_TEXT_STR_4588030343759193236  ; msg 31 "HIS WINDING CLOCK."
    FCB -56  ; msg 32 x
    FCB 114  ; msg 32 y
    FDB PRINT_TEXT_STR_14122068582122076643  ; msg 32 "VAULT AWAITS."
    FCB -63  ; msg 33 x
    FCB 114  ; msg 33 y
    FDB PRINT_TEXT_STR_6950660334503696963  ; msg 33 "OLD SHEET MUSIC."
    FCB -56  ; msg 34 x
    FCB 114  ; msg 34 y
    FDB PRINT_TEXT_STR_6038144227778049379  ; msg 34 "WHALE OIL CAN."
    FCB -56  ; msg 35 x
    FCB 114  ; msg 35 y
    FDB PRINT_TEXT_STR_9347069291597612016  ; msg 35 "A GLASS PRISM."
    FCB -56  ; msg 36 x
    FCB 114  ; msg 36 y
    FDB PRINT_TEXT_STR_7909073815850340594  ; msg 36 "NEEDS WARMTH."
    FCB -56  ; msg 37 x
    FCB 114  ; msg 37 y
    FDB PRINT_TEXT_STR_17236580857328069985  ; msg 37 "HANS NEEDS OIL."
    FCB -49  ; msg 38 x
    FCB 114  ; msg 38 y
    FDB PRINT_TEXT_STR_2040300194473462220  ; msg 38 "NEEDS MUSIC."
    FCB -70  ; msg 39 x
    FCB 114  ; msg 39 y
    FDB PRINT_TEXT_STR_16477571072303887030  ; msg 39 "WANTS THE GEARS."
    FCB -63  ; msg 40 x
    FCB 114  ; msg 40 y
    FDB PRINT_TEXT_STR_6491622880375508119  ; msg 40 "OPTICS LAB LOCKED."
    FCB -63  ; msg 41 x
    FCB 114  ; msg 41 y
    FDB PRINT_TEXT_STR_4475750633065476197  ; msg 41 "NO ITEM SELECTED."
    FCB -63  ; msg 42 x
    FCB 114  ; msg 42 y
    FDB PRINT_TEXT_STR_561378197138974931  ; msg 42 "NEEDS VOSS KEY."
    FCB -63  ; msg 43 x
    FCB 114  ; msg 43 y
    FDB PRINT_TEXT_STR_9679949307385682704  ; msg 43 "SMALL SIDE DOOR."
    FCB -63  ; msg 44 x
    FCB 114  ; msg 44 y
    FDB PRINT_TEXT_STR_12951030068845256446  ; msg 44 "VAULT UNSEALED!"

; === CROSS-BANK USER FUNCTION TRAMPOLINES ===
TRAMP_UPDATE_ROOM:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$01  ; switch to bank #1
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR UPDATE_ROOM
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_DRAW_TESTAMENT:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$01  ; switch to bank #1
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR DRAW_TESTAMENT
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_DRAW_ENDING:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$01  ; switch to bank #1
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR DRAW_ENDING
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_ENTER_ROOM:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$01  ; switch to bank #1
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR ENTER_ROOM
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_PICKUP_ITEM:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$01  ; switch to bank #1
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR PICKUP_ITEM
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_DRAW_VERB_INDICATOR:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$01  ; switch to bank #1
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR DRAW_VERB_INDICATOR
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_CHECK_WORKSHOP_HOTSPOTS:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR CHECK_WORKSHOP_HOTSPOTS
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_CHECK_WEIGHTS_HOTSPOTS:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR CHECK_WEIGHTS_HOTSPOTS
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_CHECK_VAULT_HOTSPOTS:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR CHECK_VAULT_HOTSPOTS
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_INTERACT_ENTRANCE:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR INTERACT_ENTRANCE
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_INTERACT_WORKSHOP:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR INTERACT_WORKSHOP
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_INTERACT_ANTEROOM:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR INTERACT_ANTEROOM
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_INTERACT_WEIGHTS:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR INTERACT_WEIGHTS
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_INTERACT_CONSERVATORY:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR INTERACT_CONSERVATORY
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_INTERACT_VAULT:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR INTERACT_VAULT
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_DROP_ITEM:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR DROP_ITEM
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_ACCELERATE_HEARTBEAT:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR ACCELERATE_HEARTBEAT
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS

; === CONST ARRAY DATA (relocated to fixed bank - accessible from any bank) ===
ARRAY_ITEM_WEIGHT_DATA:
    FDB 1   ; Element 0
    FDB 2   ; Element 1
    FDB 1   ; Element 2
    FDB 0   ; Element 3
    FDB 1   ; Element 4
    FDB 1   ; Element 5
    FDB 0   ; Element 6
    FDB 1   ; Element 7

; Array literal for variable 'ENT_HS_X' (4 elements, 2 bytes each)
ARRAY_ENT_HS_X_DATA:
    FDB 260   ; Element 0
    FDB 738   ; Element 1
    FDB 100   ; Element 2
    FDB 40   ; Element 3

; Array literal for variable 'ENT_HS_Y' (4 elements, 2 bytes each)
ARRAY_ENT_HS_Y_DATA:
    FDB -98   ; Element 0
    FDB -88   ; Element 1
    FDB -110   ; Element 2
    FDB -95   ; Element 3

; Array literal for variable 'ENT_HS_W' (4 elements, 2 bytes each)
ARRAY_ENT_HS_W_DATA:
    FDB 25   ; Element 0
    FDB 40   ; Element 1
    FDB 22   ; Element 2
    FDB 18   ; Element 3

; Array literal for variable 'ENT_HS_H' (4 elements, 2 bytes each)
ARRAY_ENT_HS_H_DATA:
    FDB 35   ; Element 0
    FDB 45   ; Element 1
    FDB 30   ; Element 2
    FDB 28   ; Element 3

; Array literal for variable 'CLOCK_HS_X' (6 elements, 2 bytes each)
ARRAY_CLOCK_HS_X_DATA:
    FDB 190   ; Element 0
    FDB 400   ; Element 1
    FDB 520   ; Element 2
    FDB 280   ; Element 3
    FDB 460   ; Element 4
    FDB 700   ; Element 5

; Array literal for variable 'CLOCK_HS_Y' (6 elements, 2 bytes each)
ARRAY_CLOCK_HS_Y_DATA:
    FDB -80   ; Element 0
    FDB -70   ; Element 1
    FDB -80   ; Element 2
    FDB -110   ; Element 3
    FDB -80   ; Element 4
    FDB -90   ; Element 5

; Array literal for variable 'CLOCK_HS_W' (6 elements, 2 bytes each)
ARRAY_CLOCK_HS_W_DATA:
    FDB 40   ; Element 0
    FDB 35   ; Element 1
    FDB 35   ; Element 2
    FDB 22   ; Element 3
    FDB 20   ; Element 4
    FDB 22   ; Element 5

; Array literal for variable 'CLOCK_HS_H' (6 elements, 2 bytes each)
ARRAY_CLOCK_HS_H_DATA:
    FDB 40   ; Element 0
    FDB 40   ; Element 1
    FDB 35   ; Element 2
    FDB 30   ; Element 3
    FDB 25   ; Element 4
    FDB 32   ; Element 5

; Array literal for variable 'ANT_HS_X' (4 elements, 2 bytes each)
ARRAY_ANT_HS_X_DATA:
    FDB 300   ; Element 0
    FDB 735   ; Element 1
    FDB 150   ; Element 2
    FDB 550   ; Element 3

; Array literal for variable 'ANT_HS_Y' (4 elements, 2 bytes each)
ARRAY_ANT_HS_Y_DATA:
    FDB -95   ; Element 0
    FDB -95   ; Element 1
    FDB -95   ; Element 2
    FDB -95   ; Element 3

; Array literal for variable 'ANT_HS_W' (4 elements, 2 bytes each)
ARRAY_ANT_HS_W_DATA:
    FDB 40   ; Element 0
    FDB 30   ; Element 1
    FDB 35   ; Element 2
    FDB 35   ; Element 3

; Array literal for variable 'ANT_HS_H' (4 elements, 2 bytes each)
ARRAY_ANT_HS_H_DATA:
    FDB 35   ; Element 0
    FDB 30   ; Element 1
    FDB 35   ; Element 2
    FDB 35   ; Element 3

; Array literal for variable 'WGT_HS_X' (2 elements, 2 bytes each)
ARRAY_WGT_HS_X_DATA:
    FDB 280   ; Element 0
    FDB 570   ; Element 1

; Array literal for variable 'WGT_HS_Y' (2 elements, 2 bytes each)
ARRAY_WGT_HS_Y_DATA:
    FDB -95   ; Element 0
    FDB -95   ; Element 1

; Array literal for variable 'WGT_HS_W' (2 elements, 2 bytes each)
ARRAY_WGT_HS_W_DATA:
    FDB 40   ; Element 0
    FDB 30   ; Element 1

; Array literal for variable 'WGT_HS_H' (2 elements, 2 bytes each)
ARRAY_WGT_HS_H_DATA:
    FDB 35   ; Element 0
    FDB 30   ; Element 1

; Array literal for variable 'OPT_HS_X' (2 elements, 2 bytes each)
ARRAY_OPT_HS_X_DATA:
    FDB 250   ; Element 0
    FDB 420   ; Element 1

; Array literal for variable 'OPT_HS_Y' (2 elements, 2 bytes each)
ARRAY_OPT_HS_Y_DATA:
    FDB -95   ; Element 0
    FDB -95   ; Element 1

; Array literal for variable 'OPT_HS_W' (2 elements, 2 bytes each)
ARRAY_OPT_HS_W_DATA:
    FDB 40   ; Element 0
    FDB 30   ; Element 1

; Array literal for variable 'OPT_HS_H' (2 elements, 2 bytes each)
ARRAY_OPT_HS_H_DATA:
    FDB 35   ; Element 0
    FDB 30   ; Element 1

; Array literal for variable 'CONS_HS_X' (1 elements, 2 bytes each)
ARRAY_CONS_HS_X_DATA:
    FDB 0   ; Element 0

; Array literal for variable 'CONS_HS_Y' (1 elements, 2 bytes each)
ARRAY_CONS_HS_Y_DATA:
    FDB -100   ; Element 0

; Array literal for variable 'CONS_HS_W' (1 elements, 2 bytes each)
ARRAY_CONS_HS_W_DATA:
    FDB 40   ; Element 0

; Array literal for variable 'CONS_HS_H' (1 elements, 2 bytes each)
ARRAY_CONS_HS_H_DATA:
    FDB 40   ; Element 0

; Array literal for variable 'VAULT_HS_X' (2 elements, 2 bytes each)
ARRAY_VAULT_HS_X_DATA:
    FDB -30   ; Element 0
    FDB 70   ; Element 1

; Array literal for variable 'VAULT_HS_Y' (2 elements, 2 bytes each)
ARRAY_VAULT_HS_Y_DATA:
    FDB -100   ; Element 0
    FDB -90   ; Element 1

; Array literal for variable 'VAULT_HS_W' (2 elements, 2 bytes each)
ARRAY_VAULT_HS_W_DATA:
    FDB 35   ; Element 0
    FDB 22   ; Element 1

; Array literal for variable 'VAULT_HS_H' (2 elements, 2 bytes each)
ARRAY_VAULT_HS_H_DATA:
    FDB 40   ; Element 0
    FDB 32   ; Element 1

; Array literal for variable 'NPC_STATE' (4 elements, 2 bytes each)
ARRAY_NPC_STATE_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3

; Array literal for variable 'INV_ITEMS' (8 elements, 2 bytes each)
ARRAY_INV_ITEMS_DATA:
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
