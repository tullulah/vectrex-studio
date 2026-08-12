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
MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    CLR DRAW_VEC_INTENSITY ; 0 = use recorded/vector intensity (no override)
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
    LDD #0  ; const MUSIC_NONE
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
; VPy_LINE:211
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'entrance'
    ; Level asset index: 3 (multibank)
    LDX #3
    JSR LOAD_LEVEL_BANKED
; VPy_LINE:213
    ; TODO: Statement Pass { source_line: 213 }

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
; VPy_LINE:218
    LDB >VAR_CURRENT_MUSIC
    SEX             ; Sign-extend B -> D
    CMPD #0
    LBNE IF_NEXT_1
; VPy_LINE:219
    LDD #1  ; const MUSIC_TITLE
    STB VAR_CURRENT_MUSIC
; VPy_LINE:220
; NATIVE_CALL: PLAY_MUSIC at line 220
    ; PLAY_MUSIC("intro") - play music asset (index=1)
    LDX #1        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
; VPy_LINE:224
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
    LBEQ IF_NEXT_3
; VPy_LINE:225
    LDD >VAR_SKIPPEDFRAMES
    STD TMPVAL          ; Save left operand
    LDD #1
    ADDD TMPVAL         ; D = D + TMPVAL
    STD VAR_SKIPPEDFRAMES
; VPy_LINE:226
; NATIVE_CALL: J1_BUTTON_1 at line 226
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
; VPy_LINE:227
; NATIVE_CALL: J1_BUTTON_2 at line 227
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
; VPy_LINE:228
; NATIVE_CALL: J1_BUTTON_3 at line 228
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
; VPy_LINE:229
    RTS
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
; VPy_LINE:232
; NATIVE_CALL: J1_BUTTON_1 at line 232
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
; VPy_LINE:233
; NATIVE_CALL: J1_BUTTON_2 at line 233
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
; VPy_LINE:234
; NATIVE_CALL: J1_BUTTON_3 at line 234
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
; VPy_LINE:235
    LDD #0
    STD VAR_BTN1_FIRED
; VPy_LINE:236
    LDD #0
    STD VAR_BTN2_FIRED
; VPy_LINE:237
    LDD #0
    STD VAR_BTN3_FIRED
; VPy_LINE:238
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
    LBEQ IF_NEXT_5
; VPy_LINE:239
    LDD #1
    STD VAR_BTN1_FIRED
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
; VPy_LINE:240
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
    LBEQ IF_NEXT_7
; VPy_LINE:241
    LDD #1
    STD VAR_BTN2_FIRED
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
; VPy_LINE:242
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
    LBEQ IF_NEXT_9
; VPy_LINE:243
    LDD #1
    STD VAR_BTN3_FIRED
    LBRA IF_END_8
IF_NEXT_9:
IF_END_8:
; VPy_LINE:244
    LDD >VAR_RAW1
    STD VAR_PREV_BTN1
; VPy_LINE:245
    LDD >VAR_RAW2
    STD VAR_PREV_BTN2
; VPy_LINE:246
    LDD >VAR_RAW3
    STD VAR_PREV_BTN3
; VPy_LINE:253
    LDD >VAR_SCREEN
    CMPD #2
    LBNE IF_NEXT_11
; VPy_LINE:254
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_HEARTBEAT_TIMER
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_HEARTBEAT_TIMER
; VPy_LINE:255
    LDD >VAR_HEARTBEAT_TEMPO
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_HEARTBEAT_TIMER
    CMPD TMPVAL
    LBGE .CMP_10_TRUE
    LDD #0
    LBRA .CMP_10_END
.CMP_10_TRUE:
    LDD #1
.CMP_10_END:
    LBEQ IF_NEXT_13
; VPy_LINE:256
    LDD #0
    STD VAR_HEARTBEAT_TIMER
    LBRA IF_END_12
IF_NEXT_13:
IF_END_12:
    LBRA IF_END_10
IF_NEXT_11:
IF_END_10:
; VPy_LINE:260
    LDD >VAR_BTN2_FIRED
    CMPD #1
    LBNE IF_NEXT_15
; VPy_LINE:261
    LDD >VAR_SCREEN
    CMPD #2
    LBNE IF_NEXT_17
; VPy_LINE:262
    LDD >VAR_SHOW_INVENTORY
    CMPD #0
    LBNE IF_NEXT_19
; VPy_LINE:263
    LDD #1
    STD VAR_SHOW_INVENTORY
    LBRA IF_END_18
IF_NEXT_19:
; VPy_LINE:265
    LDD #0
    STD VAR_SHOW_INVENTORY
IF_END_18:
    LBRA IF_END_16
IF_NEXT_17:
IF_END_16:
    LBRA IF_END_14
IF_NEXT_15:
IF_END_14:
; VPy_LINE:267
    LDD >VAR_SCREEN
    CMPD #0
    LBNE IF_NEXT_21
; VPy_LINE:268
    JSR DRAW_TITLE
    LBRA IF_END_20
IF_NEXT_21:
    LDD >VAR_SCREEN
    CMPD #1
    LBNE IF_NEXT_22
; VPy_LINE:270
    JSR DRAW_INTRO
    LBRA IF_END_20
IF_NEXT_22:
    LDD >VAR_SCREEN
    CMPD #2
    LBNE IF_NEXT_23
; VPy_LINE:272
    JSR TRAMP_UPDATE_ROOM  ; cross-bank trampoline (bank #0 -> bank #1)
; VPy_LINE:273
    LDD >VAR_SHOW_INVENTORY
    CMPD #1
    LBNE IF_NEXT_25
; VPy_LINE:274
    JSR DRAW_INVENTORY
    LBRA IF_END_24
IF_NEXT_25:
; VPy_LINE:276
    JSR DRAW_ROOM
IF_END_24:
    LBRA IF_END_20
IF_NEXT_23:
    LDD >VAR_SCREEN
    CMPD #4
    LBNE IF_NEXT_26
; VPy_LINE:278
    JSR DRAW_TESTAMENT
    LBRA IF_END_20
IF_NEXT_26:
    LDD >VAR_SCREEN
    CMPD #3
    LBNE IF_END_20
; VPy_LINE:280
    JSR DRAW_ENDING
    LBRA IF_END_20
IF_END_20:
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX (after all game logic)
    RTS

; Function: DRAW_TITLE (Bank #0)
DRAW_TITLE:
; VPy_LINE:306
; NATIVE_CALL: DRAW_VECTOR_EX at line 306
    ; DRAW_VECTOR_EX: Draw vector asset with transformations
    ; Asset: crypt_logo (index=3, 40 paths) with mirror + intensity
    LDD #0
    TFR B,A       ; X position (low byte) — B already holds it
    STA DRAW_VEC_X
    LDD #10
    TFR B,A       ; Y position (low byte) — B already holds it
    STA DRAW_VEC_Y
    LDD #0
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
    LDD #0
    TFR B,A       ; Intensity (0-127) — B already holds it
    STA DRAW_VEC_INTENSITY  ; Store intensity override
    LDX #3        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
    CLR DRAW_VEC_INTENSITY  ; Clear intensity override for next draw
    LDD #0
    STD RESULT
; VPy_LINE:308
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_BLINK_TIMER
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_BLINK_TIMER
; VPy_LINE:309
    LDD #40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BLINK_TIMER
    CMPD TMPVAL
    LBGE .CMP_11_TRUE
    LDD #0
    LBRA .CMP_11_END
.CMP_11_TRUE:
    LDD #1
.CMP_11_END:
    LBEQ IF_NEXT_28
; VPy_LINE:310
    LDD #0
    STD VAR_BLINK_TIMER
; VPy_LINE:311
    LDD >VAR_BLINK_ON
    CMPD #0
    LBNE IF_NEXT_30
; VPy_LINE:312
    LDD #1
    STD VAR_BLINK_ON
    LBRA IF_END_29
IF_NEXT_30:
; VPy_LINE:314
    LDD #0
    STD VAR_BLINK_ON
IF_END_29:
    LBRA IF_END_27
IF_NEXT_28:
IF_END_27:
; VPy_LINE:316
    LDD >VAR_BLINK_ON
    CMPD #1
    LBNE IF_NEXT_32
; VPy_LINE:317
; NATIVE_CALL: SET_TEXT_SIZE at line 317
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
    LBRA IF_END_31
IF_NEXT_32:
IF_END_31:
; VPy_LINE:320
    LDD >VAR_BTN1_FIRED
    CMPD #1
    LBNE IF_NEXT_34
; VPy_LINE:321
    LDD #0
    STD VAR_INTRO_PAGE
; VPy_LINE:322
    LDD #1  ; const STATE_INTRO
    STD VAR_SCREEN
    LBRA IF_END_33
IF_NEXT_34:
IF_END_33:
    RTS

; Function: DRAW_INTRO (Bank #0)
DRAW_INTRO:
; VPy_LINE:328
; NATIVE_CALL: SET_TEXT_SIZE at line 328
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
; VPy_LINE:329
    LDD >VAR_INTRO_PAGE
    CMPD #0
    LBNE IF_NEXT_36
; VPy_LINE:330
; NATIVE_CALL: SET_INTENSITY at line 330
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:331
; NATIVE_CALL: PRINT_TEXT at line 331
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD >VAR_ARG0
    LDD #40
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_17850884399050856369      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:332
; NATIVE_CALL: SET_INTENSITY at line 332
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:333
; NATIVE_CALL: PRINT_TEXT at line 333
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD >VAR_ARG0
    LDD #20
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_4088011977317884966      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:334
; NATIVE_CALL: PRINT_TEXT at line 334
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD >VAR_ARG0
    LDD #0
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_17028423667663067371      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:335
; NATIVE_CALL: PRINT_TEXT at line 335
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD >VAR_ARG0
    LDD #-20
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_4810967809196323313      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:336
; NATIVE_CALL: SET_INTENSITY at line 336
    ; SET_INTENSITY: Set drawing intensity
    LDD #60
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:337
; NATIVE_CALL: PRINT_TEXT at line 337
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD >VAR_ARG0
    LDD #-80
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_9120385760502433312      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_35
IF_NEXT_36:
    LDD >VAR_INTRO_PAGE
    CMPD #1
    LBNE IF_END_35
; VPy_LINE:339
; NATIVE_CALL: SET_INTENSITY at line 339
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:340
; NATIVE_CALL: PRINT_TEXT at line 340
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD >VAR_ARG0
    LDD #40
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2725988333465993402      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:341
; NATIVE_CALL: PRINT_TEXT at line 341
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD >VAR_ARG0
    LDD #25
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_5995724771220415910      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:342
; NATIVE_CALL: SET_INTENSITY at line 342
    ; SET_INTENSITY: Set drawing intensity
    LDD #70
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:343
; NATIVE_CALL: PRINT_TEXT at line 343
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD >VAR_ARG0
    LDD #-5
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_1961155566409942910      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:344
; NATIVE_CALL: PRINT_TEXT at line 344
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD >VAR_ARG0
    LDD #-20
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_1423984413427534561      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:345
; NATIVE_CALL: SET_INTENSITY at line 345
    ; SET_INTENSITY: Set drawing intensity
    LDD #60
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:346
; NATIVE_CALL: PRINT_TEXT at line 346
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD >VAR_ARG0
    LDD #-80
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_9120385760502433312      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_35
IF_END_35:
; VPy_LINE:348
    LDD >VAR_BTN1_FIRED
    CMPD #1
    LBNE IF_NEXT_38
; VPy_LINE:349
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INTRO_PAGE
    CMPD TMPVAL
    LBLT .CMP_12_TRUE
    LDD #0
    LBRA .CMP_12_END
.CMP_12_TRUE:
    LDD #1
.CMP_12_END:
    LBEQ IF_NEXT_40
; VPy_LINE:350
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_INTRO_PAGE
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_INTRO_PAGE
    LBRA IF_END_39
IF_NEXT_40:
; VPy_LINE:352
    LDD #0  ; const ROOM_ENTRANCE
    STD VAR_ARG0
    JSR ENTER_ROOM
; VPy_LINE:353
    LDD #2  ; const STATE_ROOM
    STD VAR_SCREEN
IF_END_39:
    LBRA IF_END_37
IF_NEXT_38:
IF_END_37:
    RTS

; Function: ENTER_ROOM (Bank #0)
ENTER_ROOM:
; VPy_LINE:359
    LDD >VAR_ARG0
    STD VAR_CURRENT_ROOM
; VPy_LINE:360
    LDD #-1
    STD VAR_NEAR_HS
; VPy_LINE:361
    LDD #0
    STD VAR_MSG_ID
; VPy_LINE:362
    LDD #0
    STD VAR_MSG_TIMER
; VPy_LINE:363
    LDD #0
    STD VAR_ROOM_EXIT
; VPy_LINE:364
    LDD #0
    STD VAR_SHOW_INVENTORY
; VPy_LINE:365
    LDD >VAR_ARG0
    CMPD #0
    LBNE IF_NEXT_42
; VPy_LINE:366
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'entrance'
    ; Level asset index: 3 (multibank)
    LDX #3
    JSR LOAD_LEVEL_BANKED
; VPy_LINE:367
    LDD #0
    STD VAR_PLAYER_X
; VPy_LINE:368
    LDD #-115
    STD VAR_PLAYER_Y
; VPy_LINE:369
    LDD #0
    STD VAR_SCROLL_X
; VPy_LINE:370
; NATIVE_CALL: SET_CAMERA_X at line 370
    ; ===== SET_CAMERA_X builtin =====
    LDD #0
    STD >CAMERA_X    ; Store 16-bit camera X scroll offset
    LDD #0
    STD RESULT
; VPy_LINE:371
    LDB >VAR_CURRENT_MUSIC
    SEX             ; Sign-extend B -> D
    CMPD #2
    LBEQ IF_NEXT_44
; VPy_LINE:372
; NATIVE_CALL: PLAY_MUSIC at line 372
    ; PLAY_MUSIC("exploration") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
; VPy_LINE:373
    LDD #2  ; const MUSIC_EXPLORATION
    STB VAR_CURRENT_MUSIC
    LBRA IF_END_43
IF_NEXT_44:
IF_END_43:
    LBRA IF_END_41
IF_NEXT_42:
    LDD >VAR_ARG0
    CMPD #1
    LBNE IF_NEXT_45
; VPy_LINE:375
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'clockroom'
    ; Level asset index: 1 (multibank)
    LDX #1
    JSR LOAD_LEVEL_BANKED
; VPy_LINE:376
    LDD #70
    STD VAR_PLAYER_X
; VPy_LINE:377
    LDD #-75
    STD VAR_PLAYER_Y
; VPy_LINE:378
    LDD #0
    STD VAR_SCROLL_X
; VPy_LINE:379
; NATIVE_CALL: SET_CAMERA_X at line 379
    ; ===== SET_CAMERA_X builtin =====
    LDD #0
    STD >CAMERA_X    ; Store 16-bit camera X scroll offset
    LDD #0
    STD RESULT
; VPy_LINE:380
    LDB >VAR_CURRENT_MUSIC
    SEX             ; Sign-extend B -> D
    CMPD #2
    LBEQ IF_NEXT_47
; VPy_LINE:381
; NATIVE_CALL: PLAY_MUSIC at line 381
    ; PLAY_MUSIC("exploration") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
; VPy_LINE:382
    LDD #2  ; const MUSIC_EXPLORATION
    STB VAR_CURRENT_MUSIC
    LBRA IF_END_46
IF_NEXT_47:
IF_END_46:
    LBRA IF_END_41
IF_NEXT_45:
    LDD >VAR_ARG0
    CMPD #2
    LBNE IF_NEXT_48
; VPy_LINE:384
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'anteroom'
    ; Level asset index: 0 (multibank)
    LDX #0
    JSR LOAD_LEVEL_BANKED
; VPy_LINE:385
    LDD #50
    STD VAR_PLAYER_X
; VPy_LINE:386
    LDD #-115
    STD VAR_PLAYER_Y
; VPy_LINE:387
    LDD #0
    STD VAR_SCROLL_X
; VPy_LINE:388
; NATIVE_CALL: SET_CAMERA_X at line 388
    ; ===== SET_CAMERA_X builtin =====
    LDD #0
    STD >CAMERA_X    ; Store 16-bit camera X scroll offset
    LDD #0
    STD RESULT
; VPy_LINE:389
    LDB >VAR_CURRENT_MUSIC
    SEX             ; Sign-extend B -> D
    CMPD #2
    LBEQ IF_NEXT_50
; VPy_LINE:390
; NATIVE_CALL: PLAY_MUSIC at line 390
    ; PLAY_MUSIC("exploration") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
; VPy_LINE:391
    LDD #2  ; const MUSIC_EXPLORATION
    STB VAR_CURRENT_MUSIC
    LBRA IF_END_49
IF_NEXT_50:
IF_END_49:
    LBRA IF_END_41
IF_NEXT_48:
    LDD >VAR_ARG0
    CMPD #3
    LBNE IF_NEXT_51
; VPy_LINE:393
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'weights_room'
    ; Level asset index: 6 (multibank)
    LDX #6
    JSR LOAD_LEVEL_BANKED
; VPy_LINE:394
    LDD #50
    STD VAR_PLAYER_X
; VPy_LINE:395
    LDD #-115
    STD VAR_PLAYER_Y
; VPy_LINE:396
    LDD #0
    STD VAR_SCROLL_X
; VPy_LINE:397
; NATIVE_CALL: SET_CAMERA_X at line 397
    ; ===== SET_CAMERA_X builtin =====
    LDD #0
    STD >CAMERA_X    ; Store 16-bit camera X scroll offset
    LDD #0
    STD RESULT
; VPy_LINE:398
    LDB >VAR_CURRENT_MUSIC
    SEX             ; Sign-extend B -> D
    CMPD #2
    LBEQ IF_NEXT_53
; VPy_LINE:399
; NATIVE_CALL: PLAY_MUSIC at line 399
    ; PLAY_MUSIC("exploration") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
; VPy_LINE:400
    LDD #2  ; const MUSIC_EXPLORATION
    STB VAR_CURRENT_MUSIC
    LBRA IF_END_52
IF_NEXT_53:
IF_END_52:
    LBRA IF_END_41
IF_NEXT_51:
    LDD >VAR_ARG0
    CMPD #4
    LBNE IF_NEXT_54
; VPy_LINE:402
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'optics_lab'
    ; Level asset index: 4 (multibank)
    LDX #4
    JSR LOAD_LEVEL_BANKED
; VPy_LINE:403
    LDD #50
    STD VAR_PLAYER_X
; VPy_LINE:404
    LDD #-115
    STD VAR_PLAYER_Y
; VPy_LINE:405
    LDD #0
    STD VAR_SCROLL_X
; VPy_LINE:406
; NATIVE_CALL: SET_CAMERA_X at line 406
    ; ===== SET_CAMERA_X builtin =====
    LDD #0
    STD >CAMERA_X    ; Store 16-bit camera X scroll offset
    LDD #0
    STD RESULT
; VPy_LINE:407
    LDB >VAR_CURRENT_MUSIC
    SEX             ; Sign-extend B -> D
    CMPD #2
    LBEQ IF_NEXT_56
; VPy_LINE:408
; NATIVE_CALL: PLAY_MUSIC at line 408
    ; PLAY_MUSIC("exploration") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
; VPy_LINE:409
    LDD #2  ; const MUSIC_EXPLORATION
    STB VAR_CURRENT_MUSIC
    LBRA IF_END_55
IF_NEXT_56:
IF_END_55:
    LBRA IF_END_41
IF_NEXT_54:
    LDD >VAR_ARG0
    CMPD #5
    LBNE IF_NEXT_57
; VPy_LINE:411
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'conservatory'
    ; Level asset index: 2 (multibank)
    LDX #2
    JSR LOAD_LEVEL_BANKED
; VPy_LINE:412
    LDD #-60
    STD VAR_PLAYER_X
; VPy_LINE:413
    LDD #-115
    STD VAR_PLAYER_Y
; VPy_LINE:414
    LDD #0
    STD VAR_SCROLL_X
; VPy_LINE:415
; NATIVE_CALL: SET_CAMERA_X at line 415
    ; ===== SET_CAMERA_X builtin =====
    LDD #0
    STD >CAMERA_X    ; Store 16-bit camera X scroll offset
    LDD #0
    STD RESULT
; VPy_LINE:416
    LDB >VAR_CURRENT_MUSIC
    SEX             ; Sign-extend B -> D
    CMPD #2
    LBEQ IF_NEXT_59
; VPy_LINE:417
; NATIVE_CALL: PLAY_MUSIC at line 417
    ; PLAY_MUSIC("exploration") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
; VPy_LINE:418
    LDD #2  ; const MUSIC_EXPLORATION
    STB VAR_CURRENT_MUSIC
    LBRA IF_END_58
IF_NEXT_59:
IF_END_58:
    LBRA IF_END_41
IF_NEXT_57:
    LDD >VAR_ARG0
    CMPD #6
    LBNE IF_END_41
; VPy_LINE:420
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'vault_corridor'
    ; Level asset index: 5 (multibank)
    LDX #5
    JSR LOAD_LEVEL_BANKED
; VPy_LINE:421
    LDD #-60
    STD VAR_PLAYER_X
; VPy_LINE:422
    LDD #-115
    STD VAR_PLAYER_Y
; VPy_LINE:423
    LDD #0
    STD VAR_SCROLL_X
; VPy_LINE:424
; NATIVE_CALL: SET_CAMERA_X at line 424
    ; ===== SET_CAMERA_X builtin =====
    LDD #0
    STD >CAMERA_X    ; Store 16-bit camera X scroll offset
    LDD #0
    STD RESULT
; VPy_LINE:425
    LDB >VAR_CURRENT_MUSIC
    SEX             ; Sign-extend B -> D
    CMPD #2
    LBEQ IF_NEXT_61
; VPy_LINE:426
; NATIVE_CALL: PLAY_MUSIC at line 426
    ; PLAY_MUSIC("exploration") - play music asset (index=0)
    LDX #0        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
; VPy_LINE:427
    LDD #2  ; const MUSIC_EXPLORATION
    STB VAR_CURRENT_MUSIC
    LBRA IF_END_60
IF_NEXT_61:
IF_END_60:
    LBRA IF_END_41
IF_END_41:
    RTS

; Function: CHECK_ENTRANCE_HOTSPOTS (Bank #0)
CHECK_ENTRANCE_HOTSPOTS:
; VPy_LINE:544
    LDX #ARRAY_ENT_HS_X_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:545
    LDX #ARRAY_ENT_HS_Y_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:546
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
    LBLE .CMP_55_TRUE
    LDD #0
    LBRA .CMP_55_END
.CMP_55_TRUE:
    LDD #1
.CMP_55_END:
    LBEQ .LOGIC_54_FALSE
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
    LBLE .CMP_56_TRUE
    LDD #0
    LBRA .CMP_56_END
.CMP_56_TRUE:
    LDD #1
.CMP_56_END:
    LBEQ .LOGIC_54_FALSE
    LDD #1
    LBRA .LOGIC_54_END
.LOGIC_54_FALSE:
    LDD #0
.LOGIC_54_END:
    LBEQ IF_NEXT_122
; VPy_LINE:547
    LDD #0
    STD VAR_NEAR_HS
    LBRA IF_END_121
IF_NEXT_122:
IF_END_121:
; VPy_LINE:548
    LDX #ARRAY_ENT_HS_X_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:549
    LDX #ARRAY_ENT_HS_Y_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:550
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
    LBLE .CMP_58_TRUE
    LDD #0
    LBRA .CMP_58_END
.CMP_58_TRUE:
    LDD #1
.CMP_58_END:
    LBEQ .LOGIC_57_FALSE
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
    LBLE .CMP_59_TRUE
    LDD #0
    LBRA .CMP_59_END
.CMP_59_TRUE:
    LDD #1
.CMP_59_END:
    LBEQ .LOGIC_57_FALSE
    LDD #1
    LBRA .LOGIC_57_END
.LOGIC_57_FALSE:
    LDD #0
.LOGIC_57_END:
    LBEQ IF_NEXT_124
; VPy_LINE:551
    LDD #1
    STD VAR_NEAR_HS
    LBRA IF_END_123
IF_NEXT_124:
IF_END_123:
; VPy_LINE:552
    LDX #ARRAY_ENT_HS_X_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:553
    LDX #ARRAY_ENT_HS_Y_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:554
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
    LBLE .CMP_61_TRUE
    LDD #0
    LBRA .CMP_61_END
.CMP_61_TRUE:
    LDD #1
.CMP_61_END:
    LBEQ .LOGIC_60_FALSE
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
    LBLE .CMP_62_TRUE
    LDD #0
    LBRA .CMP_62_END
.CMP_62_TRUE:
    LDD #1
.CMP_62_END:
    LBEQ .LOGIC_60_FALSE
    LDD #1
    LBRA .LOGIC_60_END
.LOGIC_60_FALSE:
    LDD #0
.LOGIC_60_END:
    LBEQ IF_NEXT_126
; VPy_LINE:555
    LDD #2
    STD VAR_NEAR_HS
    LBRA IF_END_125
IF_NEXT_126:
IF_END_125:
; VPy_LINE:556
    LDD #2  ; const FL_TALLER_OPEN
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_A
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    CMPD #0
    LBEQ IF_NEXT_128
; VPy_LINE:557
    LDX #ARRAY_ENT_HS_X_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:558
    LDX #ARRAY_ENT_HS_Y_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:559
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
    LBLE .CMP_64_TRUE
    LDD #0
    LBRA .CMP_64_END
.CMP_64_TRUE:
    LDD #1
.CMP_64_END:
    LBEQ .LOGIC_63_FALSE
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
    LBLE .CMP_65_TRUE
    LDD #0
    LBRA .CMP_65_END
.CMP_65_TRUE:
    LDD #1
.CMP_65_END:
    LBEQ .LOGIC_63_FALSE
    LDD #1
    LBRA .LOGIC_63_END
.LOGIC_63_FALSE:
    LDD #0
.LOGIC_63_END:
    LBEQ IF_NEXT_130
; VPy_LINE:560
    LDD #3
    STD VAR_NEAR_HS
    LBRA IF_END_129
IF_NEXT_130:
IF_END_129:
    LBRA IF_END_127
IF_NEXT_128:
IF_END_127:
    RTS

; Function: CHECK_WORKSHOP_HOTSPOTS (Bank #0)
CHECK_WORKSHOP_HOTSPOTS:
; VPy_LINE:563
    LDX #ARRAY_CLOCK_HS_X_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:564
    LDX #ARRAY_CLOCK_HS_Y_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:565
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
    LBLE .CMP_67_TRUE
    LDD #0
    LBRA .CMP_67_END
.CMP_67_TRUE:
    LDD #1
.CMP_67_END:
    LBEQ .LOGIC_66_FALSE
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
    LBLE .CMP_68_TRUE
    LDD #0
    LBRA .CMP_68_END
.CMP_68_TRUE:
    LDD #1
.CMP_68_END:
    LBEQ .LOGIC_66_FALSE
    LDD #1
    LBRA .LOGIC_66_END
.LOGIC_66_FALSE:
    LDD #0
.LOGIC_66_END:
    LBEQ IF_NEXT_132
; VPy_LINE:566
    LDD #0
    STD VAR_NEAR_HS
    LBRA IF_END_131
IF_NEXT_132:
IF_END_131:
; VPy_LINE:567
    LDX #ARRAY_CLOCK_HS_X_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:568
    LDX #ARRAY_CLOCK_HS_Y_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:569
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
    LBLE .CMP_70_TRUE
    LDD #0
    LBRA .CMP_70_END
.CMP_70_TRUE:
    LDD #1
.CMP_70_END:
    LBEQ .LOGIC_69_FALSE
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
    LBLE .CMP_71_TRUE
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
    LBEQ IF_NEXT_134
; VPy_LINE:570
    LDD #1
    STD VAR_NEAR_HS
    LBRA IF_END_133
IF_NEXT_134:
IF_END_133:
; VPy_LINE:571
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #1  ; const ITEM_GEAR
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #0
    LBNE IF_NEXT_136
; VPy_LINE:572
    LDX #ARRAY_CLOCK_HS_X_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:573
    LDX #ARRAY_CLOCK_HS_Y_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:574
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
    LBLE .CMP_73_TRUE
    LDD #0
    LBRA .CMP_73_END
.CMP_73_TRUE:
    LDD #1
.CMP_73_END:
    LBEQ .LOGIC_72_FALSE
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
    LBLE .CMP_74_TRUE
    LDD #0
    LBRA .CMP_74_END
.CMP_74_TRUE:
    LDD #1
.CMP_74_END:
    LBEQ .LOGIC_72_FALSE
    LDD #1
    LBRA .LOGIC_72_END
.LOGIC_72_FALSE:
    LDD #0
.LOGIC_72_END:
    LBEQ IF_NEXT_138
; VPy_LINE:575
    LDD #2
    STD VAR_NEAR_HS
    LBRA IF_END_137
IF_NEXT_138:
IF_END_137:
    LBRA IF_END_135
IF_NEXT_136:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD #16  ; const FL_PANEL_ACTIVE
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_A
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    CMPD TMPVAL
    LBEQ .CMP_76_TRUE
    LDD #0
    LBRA .CMP_76_END
.CMP_76_TRUE:
    LDD #1
.CMP_76_END:
    LBEQ .LOGIC_75_FALSE
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
    LBEQ .CMP_77_TRUE
    LDD #0
    LBRA .CMP_77_END
.CMP_77_TRUE:
    LDD #1
.CMP_77_END:
    LBEQ .LOGIC_75_FALSE
    LDD #1
    LBRA .LOGIC_75_END
.LOGIC_75_FALSE:
    LDD #0
.LOGIC_75_END:
    LBEQ IF_END_135
; VPy_LINE:577
    LDX #ARRAY_CLOCK_HS_X_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:578
    LDX #ARRAY_CLOCK_HS_Y_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:579
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
    LBLE .CMP_79_TRUE
    LDD #0
    LBRA .CMP_79_END
.CMP_79_TRUE:
    LDD #1
.CMP_79_END:
    LBEQ .LOGIC_78_FALSE
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
    LBLE .CMP_80_TRUE
    LDD #0
    LBRA .CMP_80_END
.CMP_80_TRUE:
    LDD #1
.CMP_80_END:
    LBEQ .LOGIC_78_FALSE
    LDD #1
    LBRA .LOGIC_78_END
.LOGIC_78_FALSE:
    LDD #0
.LOGIC_78_END:
    LBEQ IF_NEXT_140
; VPy_LINE:580
    LDD #2
    STD VAR_NEAR_HS
    LBRA IF_END_139
IF_NEXT_140:
IF_END_139:
    LBRA IF_END_135
IF_END_135:
; VPy_LINE:581
    LDX #ARRAY_CLOCK_HS_X_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:582
    LDX #ARRAY_CLOCK_HS_Y_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:583
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
    LBLE .CMP_82_TRUE
    LDD #0
    LBRA .CMP_82_END
.CMP_82_TRUE:
    LDD #1
.CMP_82_END:
    LBEQ .LOGIC_81_FALSE
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
    LBLE .CMP_83_TRUE
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
    LBEQ IF_NEXT_142
; VPy_LINE:584
    LDD #3
    STD VAR_NEAR_HS
    LBRA IF_END_141
IF_NEXT_142:
IF_END_141:
; VPy_LINE:585
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #5  ; const ITEM_OIL
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #0
    LBNE IF_NEXT_144
; VPy_LINE:586
    LDX #ARRAY_CLOCK_HS_X_DATA  ; Array base
    LDD #4
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:587
    LDX #ARRAY_CLOCK_HS_Y_DATA  ; Array base
    LDD #4
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:588
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
    LBLE .CMP_85_TRUE
    LDD #0
    LBRA .CMP_85_END
.CMP_85_TRUE:
    LDD #1
.CMP_85_END:
    LBEQ .LOGIC_84_FALSE
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
    LBLE .CMP_86_TRUE
    LDD #0
    LBRA .CMP_86_END
.CMP_86_TRUE:
    LDD #1
.CMP_86_END:
    LBEQ .LOGIC_84_FALSE
    LDD #1
    LBRA .LOGIC_84_END
.LOGIC_84_FALSE:
    LDD #0
.LOGIC_84_END:
    LBEQ IF_NEXT_146
; VPy_LINE:589
    LDD #4
    STD VAR_NEAR_HS
    LBRA IF_END_145
IF_NEXT_146:
IF_END_145:
    LBRA IF_END_143
IF_NEXT_144:
IF_END_143:
; VPy_LINE:590
    LDX #ARRAY_CLOCK_HS_X_DATA  ; Array base
    LDD #5
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:591
    LDX #ARRAY_CLOCK_HS_Y_DATA  ; Array base
    LDD #5
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:592
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
    LBLE .CMP_88_TRUE
    LDD #0
    LBRA .CMP_88_END
.CMP_88_TRUE:
    LDD #1
.CMP_88_END:
    LBEQ .LOGIC_87_FALSE
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
    LBLE .CMP_89_TRUE
    LDD #0
    LBRA .CMP_89_END
.CMP_89_TRUE:
    LDD #1
.CMP_89_END:
    LBEQ .LOGIC_87_FALSE
    LDD #1
    LBRA .LOGIC_87_END
.LOGIC_87_FALSE:
    LDD #0
.LOGIC_87_END:
    LBEQ IF_NEXT_148
; VPy_LINE:593
    LDD #5
    STD VAR_NEAR_HS
    LBRA IF_END_147
IF_NEXT_148:
IF_END_147:
    RTS

; Function: CHECK_ANTEROOM_HOTSPOTS (Bank #0)
CHECK_ANTEROOM_HOTSPOTS:
; VPy_LINE:596
    LDX #ARRAY_ANT_HS_X_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:597
    LDX #ARRAY_ANT_HS_Y_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:598
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
    LBLE .CMP_91_TRUE
    LDD #0
    LBRA .CMP_91_END
.CMP_91_TRUE:
    LDD #1
.CMP_91_END:
    LBEQ .LOGIC_90_FALSE
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
    LBLE .CMP_92_TRUE
    LDD #0
    LBRA .CMP_92_END
.CMP_92_TRUE:
    LDD #1
.CMP_92_END:
    LBEQ .LOGIC_90_FALSE
    LDD #1
    LBRA .LOGIC_90_END
.LOGIC_90_FALSE:
    LDD #0
.LOGIC_90_END:
    LBEQ IF_NEXT_150
; VPy_LINE:599
    LDD #0
    STD VAR_NEAR_HS
    LBRA IF_END_149
IF_NEXT_150:
IF_END_149:
; VPy_LINE:600
    LDX #ARRAY_ANT_HS_X_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:601
    LDX #ARRAY_ANT_HS_Y_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:602
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
    LBLE .CMP_94_TRUE
    LDD #0
    LBRA .CMP_94_END
.CMP_94_TRUE:
    LDD #1
.CMP_94_END:
    LBEQ .LOGIC_93_FALSE
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
    LBLE .CMP_95_TRUE
    LDD #0
    LBRA .CMP_95_END
.CMP_95_TRUE:
    LDD #1
.CMP_95_END:
    LBEQ .LOGIC_93_FALSE
    LDD #1
    LBRA .LOGIC_93_END
.LOGIC_93_FALSE:
    LDD #0
.LOGIC_93_END:
    LBEQ IF_NEXT_152
; VPy_LINE:603
    LDD #1
    STD VAR_NEAR_HS
    LBRA IF_END_151
IF_NEXT_152:
IF_END_151:
; VPy_LINE:604
    LDX #ARRAY_ANT_HS_X_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:605
    LDX #ARRAY_ANT_HS_Y_DATA  ; Array base
    LDD #2
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:606
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
    LBLE .CMP_97_TRUE
    LDD #0
    LBRA .CMP_97_END
.CMP_97_TRUE:
    LDD #1
.CMP_97_END:
    LBEQ .LOGIC_96_FALSE
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
    LBLE .CMP_98_TRUE
    LDD #0
    LBRA .CMP_98_END
.CMP_98_TRUE:
    LDD #1
.CMP_98_END:
    LBEQ .LOGIC_96_FALSE
    LDD #1
    LBRA .LOGIC_96_END
.LOGIC_96_FALSE:
    LDD #0
.LOGIC_96_END:
    LBEQ IF_NEXT_154
; VPy_LINE:607
    LDD #2
    STD VAR_NEAR_HS
    LBRA IF_END_153
IF_NEXT_154:
IF_END_153:
; VPy_LINE:608
    LDX #ARRAY_ANT_HS_X_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:609
    LDX #ARRAY_ANT_HS_Y_DATA  ; Array base
    LDD #3
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:610
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
    LBLE .CMP_100_TRUE
    LDD #0
    LBRA .CMP_100_END
.CMP_100_TRUE:
    LDD #1
.CMP_100_END:
    LBEQ .LOGIC_99_FALSE
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
    LBLE .CMP_101_TRUE
    LDD #0
    LBRA .CMP_101_END
.CMP_101_TRUE:
    LDD #1
.CMP_101_END:
    LBEQ .LOGIC_99_FALSE
    LDD #1
    LBRA .LOGIC_99_END
.LOGIC_99_FALSE:
    LDD #0
.LOGIC_99_END:
    LBEQ IF_NEXT_156
; VPy_LINE:611
    LDD #3
    STD VAR_NEAR_HS
    LBRA IF_END_155
IF_NEXT_156:
IF_END_155:
    RTS

; Function: CHECK_WEIGHTS_HOTSPOTS (Bank #0)
CHECK_WEIGHTS_HOTSPOTS:
; VPy_LINE:614
    LDX #ARRAY_WGT_HS_X_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:615
    LDX #ARRAY_WGT_HS_Y_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:616
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
    LBLE .CMP_103_TRUE
    LDD #0
    LBRA .CMP_103_END
.CMP_103_TRUE:
    LDD #1
.CMP_103_END:
    LBEQ .LOGIC_102_FALSE
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
    LBLE .CMP_104_TRUE
    LDD #0
    LBRA .CMP_104_END
.CMP_104_TRUE:
    LDD #1
.CMP_104_END:
    LBEQ .LOGIC_102_FALSE
    LDD #1
    LBRA .LOGIC_102_END
.LOGIC_102_FALSE:
    LDD #0
.LOGIC_102_END:
    LBEQ IF_NEXT_158
; VPy_LINE:617
    LDD #0
    STD VAR_NEAR_HS
    LBRA IF_END_157
IF_NEXT_158:
IF_END_157:
; VPy_LINE:618
    LDX #ARRAY_WGT_HS_X_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:619
    LDX #ARRAY_WGT_HS_Y_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:620
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
    LBLE .CMP_106_TRUE
    LDD #0
    LBRA .CMP_106_END
.CMP_106_TRUE:
    LDD #1
.CMP_106_END:
    LBEQ .LOGIC_105_FALSE
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
    LBLE .CMP_107_TRUE
    LDD #0
    LBRA .CMP_107_END
.CMP_107_TRUE:
    LDD #1
.CMP_107_END:
    LBEQ .LOGIC_105_FALSE
    LDD #1
    LBRA .LOGIC_105_END
.LOGIC_105_FALSE:
    LDD #0
.LOGIC_105_END:
    LBEQ IF_NEXT_160
; VPy_LINE:621
    LDD #1
    STD VAR_NEAR_HS
    LBRA IF_END_159
IF_NEXT_160:
IF_END_159:
    RTS

; Function: CHECK_OPTICS_HOTSPOTS (Bank #0)
CHECK_OPTICS_HOTSPOTS:
; VPy_LINE:624
    LDX #ARRAY_OPT_HS_X_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:625
    LDX #ARRAY_OPT_HS_Y_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:626
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
    LBLE .CMP_109_TRUE
    LDD #0
    LBRA .CMP_109_END
.CMP_109_TRUE:
    LDD #1
.CMP_109_END:
    LBEQ .LOGIC_108_FALSE
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
    LBLE .CMP_110_TRUE
    LDD #0
    LBRA .CMP_110_END
.CMP_110_TRUE:
    LDD #1
.CMP_110_END:
    LBEQ .LOGIC_108_FALSE
    LDD #1
    LBRA .LOGIC_108_END
.LOGIC_108_FALSE:
    LDD #0
.LOGIC_108_END:
    LBEQ IF_NEXT_162
; VPy_LINE:627
    LDD #0
    STD VAR_NEAR_HS
    LBRA IF_END_161
IF_NEXT_162:
IF_END_161:
; VPy_LINE:628
    LDD #64  ; const FL_OPTICS_SOLVED
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_A
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    CMPD #0
    LBEQ IF_NEXT_164
; VPy_LINE:629
    LDX #ARRAY_OPT_HS_X_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:630
    LDX #ARRAY_OPT_HS_Y_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:631
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
    LBLE .CMP_112_TRUE
    LDD #0
    LBRA .CMP_112_END
.CMP_112_TRUE:
    LDD #1
.CMP_112_END:
    LBEQ .LOGIC_111_FALSE
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
    LBLE .CMP_113_TRUE
    LDD #0
    LBRA .CMP_113_END
.CMP_113_TRUE:
    LDD #1
.CMP_113_END:
    LBEQ .LOGIC_111_FALSE
    LDD #1
    LBRA .LOGIC_111_END
.LOGIC_111_FALSE:
    LDD #0
.LOGIC_111_END:
    LBEQ IF_NEXT_166
; VPy_LINE:632
    LDD #1
    STD VAR_NEAR_HS
    LBRA IF_END_165
IF_NEXT_166:
IF_END_165:
    LBRA IF_END_163
IF_NEXT_164:
IF_END_163:
    RTS

; Function: CHECK_CONSERVATORY_HOTSPOTS (Bank #0)
CHECK_CONSERVATORY_HOTSPOTS:
; VPy_LINE:635
    LDX #ARRAY_CONS_HS_X_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:636
    LDX #ARRAY_CONS_HS_Y_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:637
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
    LBLE .CMP_115_TRUE
    LDD #0
    LBRA .CMP_115_END
.CMP_115_TRUE:
    LDD #1
.CMP_115_END:
    LBEQ .LOGIC_114_FALSE
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
    LBLE .CMP_116_TRUE
    LDD #0
    LBRA .CMP_116_END
.CMP_116_TRUE:
    LDD #1
.CMP_116_END:
    LBEQ .LOGIC_114_FALSE
    LDD #1
    LBRA .LOGIC_114_END
.LOGIC_114_FALSE:
    LDD #0
.LOGIC_114_END:
    LBEQ IF_NEXT_168
; VPy_LINE:638
    LDD #0
    STD VAR_NEAR_HS
    LBRA IF_END_167
IF_NEXT_168:
IF_END_167:
    RTS

; Function: CHECK_VAULT_HOTSPOTS (Bank #0)
CHECK_VAULT_HOTSPOTS:
; VPy_LINE:641
    LDX #ARRAY_VAULT_HS_X_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:642
    LDX #ARRAY_VAULT_HS_Y_DATA  ; Array base
    LDD #0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:643
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
    LBLE .CMP_118_TRUE
    LDD #0
    LBRA .CMP_118_END
.CMP_118_TRUE:
    LDD #1
.CMP_118_END:
    LBEQ .LOGIC_117_FALSE
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
    LBLE .CMP_119_TRUE
    LDD #0
    LBRA .CMP_119_END
.CMP_119_TRUE:
    LDD #1
.CMP_119_END:
    LBEQ .LOGIC_117_FALSE
    LDD #1
    LBRA .LOGIC_117_END
.LOGIC_117_FALSE:
    LDD #0
.LOGIC_117_END:
    LBEQ IF_NEXT_170
; VPy_LINE:644
    LDD #0
    STD VAR_NEAR_HS
    LBRA IF_END_169
IF_NEXT_170:
IF_END_169:
; VPy_LINE:645
    LDX #ARRAY_VAULT_HS_X_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DX
; VPy_LINE:646
    LDX #ARRAY_VAULT_HS_Y_DATA  ; Array base
    LDD #1
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_DY
; VPy_LINE:647
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
    LBLE .CMP_121_TRUE
    LDD #0
    LBRA .CMP_121_END
.CMP_121_TRUE:
    LDD #1
.CMP_121_END:
    LBEQ .LOGIC_120_FALSE
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
    LBEQ IF_NEXT_172
; VPy_LINE:648
    LDD #1
    STD VAR_NEAR_HS
    LBRA IF_END_171
IF_NEXT_172:
IF_END_171:
    RTS

; Function: INTERACT_CONSERVATORY (Bank #0)
INTERACT_CONSERVATORY:
; VPy_LINE:984
    LDD >VAR_ARG0
    CMPD #0
    LBNE IF_NEXT_286
; VPy_LINE:985
    LDD >VAR_CURRENT_VERB
    CMPD #0
    LBNE IF_NEXT_288
; VPy_LINE:986
    LDD #2  ; const NPC_ELISA
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_NPC_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #1
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:987
    LDD #29
    STD VAR_MSG_ID
; VPy_LINE:988
    LDD #160
    STD VAR_MSG_TIMER
    LBRA IF_END_287
IF_NEXT_288:
    LDD >VAR_CURRENT_VERB
    CMPD #2
    LBNE IF_NEXT_289
; VPy_LINE:990
    LDD #38
    STD VAR_MSG_ID
; VPy_LINE:991
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_287
IF_NEXT_289:
    LDD >VAR_CURRENT_VERB
    CMPD #3
    LBNE IF_NEXT_290
; VPy_LINE:993
    LDD >VAR_ACTIVE_ITEM
    CMPD #6
    LBNE IF_NEXT_292
; VPy_LINE:994
    LDD #2  ; const FL_ELISA_HELPED
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_B
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    CMPD #0
    LBNE IF_NEXT_294
; VPy_LINE:995
    LDD #2  ; const FL_ELISA_HELPED
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_B
    ORA TMPVAL          ; A OR TMPVAL+0
    ORB TMPVAL+1        ; B OR TMPVAL+1
    STD VAR_FLAGS_B
; VPy_LINE:996
    LDD #6  ; const ITEM_SHEET
    STD VAR_ARG0
    JSR DROP_ITEM
; VPy_LINE:997
    LDD #-1
    STD VAR_ACTIVE_ITEM
; VPy_LINE:998
    LDD #2  ; const NPC_ELISA
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_NPC_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #2
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:999
    LDD #30
    STD VAR_MSG_ID
; VPy_LINE:1000
    LDD #200
    STD VAR_MSG_TIMER
; VPy_LINE:1001
; NATIVE_CALL: PLAY_SFX at line 1001
    ; PLAY_SFX("puzzle_success") - play SFX asset (index=3)
    LDX #3        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
; VPy_LINE:1002
    JSR ACCELERATE_HEARTBEAT
    LBRA IF_END_293
IF_NEXT_294:
; VPy_LINE:1004
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:1005
    LDD #100
    STD VAR_MSG_TIMER
IF_END_293:
    LBRA IF_END_291
IF_NEXT_292:
; VPy_LINE:1007
    LDD #38
    STD VAR_MSG_ID
; VPy_LINE:1008
    LDD #120
    STD VAR_MSG_TIMER
IF_END_291:
    LBRA IF_END_287
IF_NEXT_290:
    LDD >VAR_CURRENT_VERB
    CMPD #1
    LBNE IF_END_287
; VPy_LINE:1010
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:1011
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_287
IF_END_287:
    LBRA IF_END_285
IF_NEXT_286:
IF_END_285:
    RTS

; Function: DRAW_ROOM (Bank #0)
DRAW_ROOM:
; VPy_LINE:1054
; NATIVE_CALL: SET_INTENSITY at line 1054
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1055
    ; ===== UPDATE_LEVEL builtin =====
    JSR UPDATE_LEVEL_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:1056
    ; ===== SHOW_LEVEL builtin =====
    JSR SHOW_LEVEL_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:1059
    LDD >VAR_CURRENT_ROOM
    CMPD #0
    LBNE IF_NEXT_309
; VPy_LINE:1060
    LDX #ARRAY_ENT_HS_X_DATA  ; Array base
    LDD #2  ; const ENT_HS_CARETAKER
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD >VAR_SCROLL_X
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_CARETAKER_SX
; VPy_LINE:1061
    LDD #-120
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CARETAKER_SX
    CMPD TMPVAL
    LBGT .CMP_129_TRUE
    LDD #0
    LBRA .CMP_129_END
.CMP_129_TRUE:
    LDD #1
.CMP_129_END:
    LBEQ .LOGIC_128_FALSE
    LDD #120
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CARETAKER_SX
    CMPD TMPVAL
    LBLT .CMP_130_TRUE
    LDD #0
    LBRA .CMP_130_END
.CMP_130_TRUE:
    LDD #1
.CMP_130_END:
    LBEQ .LOGIC_128_FALSE
    LDD #1
    LBRA .LOGIC_128_END
.LOGIC_128_FALSE:
    LDD #0
.LOGIC_128_END:
    LBEQ IF_NEXT_311
; VPy_LINE:1062
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
    LBLT .CMP_131_TRUE
    LDD #0
    LBRA .CMP_131_END
.CMP_131_TRUE:
    LDD #1
.CMP_131_END:
    LBEQ IF_NEXT_313
; VPy_LINE:1063
; NATIVE_CALL: SET_INTENSITY at line 1063
    ; SET_INTENSITY: Set drawing intensity
    LDD #90
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
    LBRA IF_END_312
IF_NEXT_313:
; VPy_LINE:1065
; NATIVE_CALL: SET_INTENSITY at line 1065
    ; SET_INTENSITY: Set drawing intensity
    LDD #50
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
IF_END_312:
; VPy_LINE:1066
; NATIVE_CALL: DRAW_VECTOR at line 1066
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: caretaker (index=1, 7 paths)
    LDD >VAR_CARETAKER_SX
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_7          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #-118
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_7
    LDB #$FF
.sx_pos_7:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #1        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_7:
    LDD #0
    STD RESULT
    LBRA IF_END_310
IF_NEXT_311:
IF_END_310:
    LBRA IF_END_308
IF_NEXT_309:
IF_END_308:
; VPy_LINE:1068
    LDD >VAR_CURRENT_ROOM
    CMPD #1
    LBNE IF_NEXT_315
; VPy_LINE:1069
    LDX #ARRAY_CLOCK_HS_X_DATA  ; Array base
    LDD #3  ; const CLOCK_HS_HANS
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD >VAR_SCROLL_X
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_HANS_SX
; VPy_LINE:1070
    LDD #-120
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_HANS_SX
    CMPD TMPVAL
    LBGT .CMP_133_TRUE
    LDD #0
    LBRA .CMP_133_END
.CMP_133_TRUE:
    LDD #1
.CMP_133_END:
    LBEQ .LOGIC_132_FALSE
    LDD #120
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_HANS_SX
    CMPD TMPVAL
    LBLT .CMP_134_TRUE
    LDD #0
    LBRA .CMP_134_END
.CMP_134_TRUE:
    LDD #1
.CMP_134_END:
    LBEQ .LOGIC_132_FALSE
    LDD #1
    LBRA .LOGIC_132_END
.LOGIC_132_FALSE:
    LDD #0
.LOGIC_132_END:
    LBEQ IF_NEXT_317
; VPy_LINE:1071
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
    LBLT .CMP_135_TRUE
    LDD #0
    LBRA .CMP_135_END
.CMP_135_TRUE:
    LDD #1
.CMP_135_END:
    LBEQ IF_NEXT_319
; VPy_LINE:1072
; NATIVE_CALL: SET_INTENSITY at line 1072
    ; SET_INTENSITY: Set drawing intensity
    LDD #90
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
    LBRA IF_END_318
IF_NEXT_319:
; VPy_LINE:1074
; NATIVE_CALL: SET_INTENSITY at line 1074
    ; SET_INTENSITY: Set drawing intensity
    LDD #50
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
IF_END_318:
; VPy_LINE:1075
; NATIVE_CALL: DRAW_VECTOR at line 1075
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: hans_automata (index=10, 8 paths)
    LDD >VAR_HANS_SX
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_8          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #-118
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_8
    LDB #$FF
.sx_pos_8:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #10        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_8:
    LDD #0
    STD RESULT
    LBRA IF_END_316
IF_NEXT_317:
IF_END_316:
    LBRA IF_END_314
IF_NEXT_315:
IF_END_314:
; VPy_LINE:1078
    LDD >VAR_CURRENT_ROOM
    CMPD #3
    LBNE IF_NEXT_321
; VPy_LINE:1079
    LDD #3
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INV_WEIGHT
    CMPD TMPVAL
    LBGT .CMP_136_TRUE
    LDD #0
    LBRA .CMP_136_END
.CMP_136_TRUE:
    LDD #1
.CMP_136_END:
    LBEQ IF_NEXT_323
; VPy_LINE:1080
    LDD #1  ; const FL_PLAT_DOWN
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_B
    ORA TMPVAL          ; A OR TMPVAL+0
    ORB TMPVAL+1        ; B OR TMPVAL+1
    STD VAR_FLAGS_B
    LBRA IF_END_322
IF_NEXT_323:
; VPy_LINE:1082
    LDD #254
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_B
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    STD VAR_FLAGS_B
IF_END_322:
; VPy_LINE:1083
    LDD >VAR_SCROLL_X
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #280
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_PLAT_SX
; VPy_LINE:1084
    LDD #-120
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAT_SX
    CMPD TMPVAL
    LBGT .CMP_138_TRUE
    LDD #0
    LBRA .CMP_138_END
.CMP_138_TRUE:
    LDD #1
.CMP_138_END:
    LBEQ .LOGIC_137_FALSE
    LDD #120
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAT_SX
    CMPD TMPVAL
    LBLT .CMP_139_TRUE
    LDD #0
    LBRA .CMP_139_END
.CMP_139_TRUE:
    LDD #1
.CMP_139_END:
    LBEQ .LOGIC_137_FALSE
    LDD #1
    LBRA .LOGIC_137_END
.LOGIC_137_FALSE:
    LDD #0
.LOGIC_137_END:
    LBEQ IF_NEXT_325
; VPy_LINE:1085
; NATIVE_CALL: SET_INTENSITY at line 1085
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1086
    LDD #1  ; const FL_PLAT_DOWN
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_B
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    CMPD #0
    LBNE IF_NEXT_327
; VPy_LINE:1087
; NATIVE_CALL: DRAW_VECTOR at line 1087
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: platform_up (index=16, 5 paths)
    LDD >VAR_PLAT_SX
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_9          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #-85
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_9
    LDB #$FF
.sx_pos_9:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #16        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_9:
    LDD #0
    STD RESULT
    LBRA IF_END_326
IF_NEXT_327:
; VPy_LINE:1089
; NATIVE_CALL: DRAW_VECTOR at line 1089
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: platform_down (index=15, 7 paths)
    LDD >VAR_PLAT_SX
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_10          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #-85
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_10
    LDB #$FF
.sx_pos_10:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #15        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_10:
    LDD #0
    STD RESULT
IF_END_326:
    LBRA IF_END_324
IF_NEXT_325:
IF_END_324:
    LBRA IF_END_320
IF_NEXT_321:
IF_END_320:
; VPy_LINE:1091
    LDD >VAR_CURRENT_ROOM
    CMPD #4
    LBNE IF_NEXT_329
; VPy_LINE:1092
    LDD #64  ; const FL_OPTICS_SOLVED
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_A
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    CMPD #0
    LBEQ IF_NEXT_331
; VPy_LINE:1093
    LDD >VAR_SCROLL_X
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD #420
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_COMP_SX
; VPy_LINE:1094
    LDD #-120
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_COMP_SX
    CMPD TMPVAL
    LBGT .CMP_141_TRUE
    LDD #0
    LBRA .CMP_141_END
.CMP_141_TRUE:
    LDD #1
.CMP_141_END:
    LBEQ .LOGIC_140_FALSE
    LDD #120
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_COMP_SX
    CMPD TMPVAL
    LBLT .CMP_142_TRUE
    LDD #0
    LBRA .CMP_142_END
.CMP_142_TRUE:
    LDD #1
.CMP_142_END:
    LBEQ .LOGIC_140_FALSE
    LDD #1
    LBRA .LOGIC_140_END
.LOGIC_140_FALSE:
    LDD #0
.LOGIC_140_END:
    LBEQ IF_NEXT_333
; VPy_LINE:1095
; NATIVE_CALL: SET_INTENSITY at line 1095
    ; SET_INTENSITY: Set drawing intensity
    LDD #110
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1096
; NATIVE_CALL: DRAW_VECTOR at line 1096
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: wall_compartment (index=19, 4 paths)
    LDD >VAR_COMP_SX
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_11          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #-88
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_11
    LDB #$FF
.sx_pos_11:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #19        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_11:
    LDD #0
    STD RESULT
    LBRA IF_END_332
IF_NEXT_333:
IF_END_332:
    LBRA IF_END_330
IF_NEXT_331:
IF_END_330:
    LBRA IF_END_328
IF_NEXT_329:
IF_END_328:
; VPy_LINE:1098
    LDD >VAR_CURRENT_ROOM
    CMPD #5
    LBNE IF_NEXT_335
; VPy_LINE:1099
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
    LBLT .CMP_143_TRUE
    LDD #0
    LBRA .CMP_143_END
.CMP_143_TRUE:
    LDD #1
.CMP_143_END:
    LBEQ IF_NEXT_337
; VPy_LINE:1100
; NATIVE_CALL: SET_INTENSITY at line 1100
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
    LBRA IF_END_336
IF_NEXT_337:
; VPy_LINE:1102
; NATIVE_CALL: SET_INTENSITY at line 1102
    ; SET_INTENSITY: Set drawing intensity
    LDD #30
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
IF_END_336:
; VPy_LINE:1103
; NATIVE_CALL: DRAW_VECTOR at line 1103
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: elisa_ghost (index=7, 3 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_12          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #-104
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_12
    LDB #$FF
.sx_pos_12:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #7        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_12:
    LDD #0
    STD RESULT
    LBRA IF_END_334
IF_NEXT_335:
IF_END_334:
; VPy_LINE:1105
    LDD >VAR_CURRENT_ROOM
    CMPD #6
    LBNE IF_NEXT_339
; VPy_LINE:1106
; NATIVE_CALL: SET_INTENSITY at line 1106
    ; SET_INTENSITY: Set drawing intensity
    LDD #85
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1107
; NATIVE_CALL: DRAW_VECTOR at line 1107
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: crystal_apprentice (index=4, 7 paths)
    LDD #-30
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_13          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #-104
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_13
    LDB #$FF
.sx_pos_13:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #4        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_13:
    LDD #0
    STD RESULT
    LBRA IF_END_338
IF_NEXT_339:
IF_END_338:
; VPy_LINE:1110
    LDD >VAR_SCROLL_X
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_SCREEN_X
; VPy_LINE:1111
; NATIVE_CALL: SET_INTENSITY at line 1111
    ; SET_INTENSITY: Set drawing intensity
    LDD #110
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1112
; NATIVE_CALL: DRAW_VECTOR at line 1112
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: player (index=17, 7 paths)
    LDD >VAR_SCREEN_X
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_14          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD >VAR_PLAYER_Y
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_14
    LDB #$FF
.sx_pos_14:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities
    LDX #17        ; Asset index for lookup
    JSR DRAW_VECTOR_BANKED  ; Draw with automatic bank switching
DRVEC_SKIP_14:
    LDD #0
    STD RESULT
; VPy_LINE:1114
    JSR DRAW_BOTTOM_HUD
    RTS

; Function: DRAW_BOTTOM_HUD (Bank #0)
DRAW_BOTTOM_HUD:
; VPy_LINE:1118
; NATIVE_CALL: SET_TEXT_SIZE at line 1118
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
; VPy_LINE:1119
; NATIVE_CALL: SET_INTENSITY at line 1119
    ; SET_INTENSITY: Set drawing intensity
    LDD #70
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1120
    JSR DRAW_VERB_INDICATOR
; VPy_LINE:1121
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    CMPD TMPVAL
    LBGT .CMP_144_TRUE
    LDD #0
    LBRA .CMP_144_END
.CMP_144_TRUE:
    LDD #1
.CMP_144_END:
    LBEQ IF_NEXT_341
; VPy_LINE:1122
    JSR DRAW_MESSAGE
    LBRA IF_END_340
IF_NEXT_341:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_NEAR_HS
    CMPD TMPVAL
    LBGE .CMP_145_TRUE
    LDD #0
    LBRA .CMP_145_END
.CMP_145_TRUE:
    LDD #1
.CMP_145_END:
    LBEQ IF_END_340
; VPy_LINE:1124
    JSR DRAW_HOTSPOT_NAME
    LBRA IF_END_340
IF_END_340:
    RTS

; Function: DRAW_HOTSPOT_NAME (Bank #0)
DRAW_HOTSPOT_NAME:
; VPy_LINE:1127
; NATIVE_CALL: SET_TEXT_SIZE at line 1127
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
; VPy_LINE:1128
; NATIVE_CALL: SET_INTENSITY at line 1128
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1129
    LDD >VAR_CURRENT_ROOM
    CMPD #0
    LBNE IF_NEXT_343
; VPy_LINE:1130
    LDD >VAR_NEAR_HS
    CMPD #0
    LBNE IF_NEXT_345
; VPy_LINE:1131
; NATIVE_CALL: PRINT_TEXT at line 1131
    ; PRINT_TEXT: Print text at position
    LDD #-35
    STD >VAR_ARG0
    LDD #114
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2260861405892      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_344
IF_NEXT_345:
    LDD >VAR_NEAR_HS
    CMPD #1
    LBNE IF_NEXT_346
; VPy_LINE:1133
; NATIVE_CALL: PRINT_TEXT at line 1133
    ; PRINT_TEXT: Print text at position
    LDD #-56
    STD >VAR_ARG0
    LDD #114
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_15262964977784735399      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_344
IF_NEXT_346:
    LDD >VAR_NEAR_HS
    CMPD #2
    LBNE IF_NEXT_347
; VPy_LINE:1135
; NATIVE_CALL: PRINT_TEXT at line 1135
    ; PRINT_TEXT: Print text at position
    LDD #-42
    STD >VAR_ARG0
    LDD #114
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_59006849725498      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_344
IF_NEXT_347:
    LDD >VAR_NEAR_HS
    CMPD #3
    LBNE IF_END_344
; VPy_LINE:1137
; NATIVE_CALL: PRINT_TEXT at line 1137
    ; PRINT_TEXT: Print text at position
    LDD #-56
    STD >VAR_ARG0
    LDD #114
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_17953374719443405528      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_344
IF_END_344:
    LBRA IF_END_342
IF_NEXT_343:
    LDD >VAR_CURRENT_ROOM
    CMPD #1
    LBNE IF_NEXT_348
; VPy_LINE:1139
    LDD >VAR_NEAR_HS
    CMPD #0
    LBNE IF_NEXT_350
; VPy_LINE:1140
; NATIVE_CALL: PRINT_TEXT at line 1140
    ; PRINT_TEXT: Print text at position
    LDD #-49
    STD >VAR_ARG0
    LDD #114
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_69819576141689452      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_349
IF_NEXT_350:
    LDD >VAR_NEAR_HS
    CMPD #1
    LBNE IF_NEXT_351
; VPy_LINE:1142
; NATIVE_CALL: PRINT_TEXT at line 1142
    ; PRINT_TEXT: Print text at position
    LDD #-21
    STD >VAR_ARG0
    LDD #114
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_64218094      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_349
IF_NEXT_351:
    LDD >VAR_NEAR_HS
    CMPD #2
    LBNE IF_NEXT_352
; VPy_LINE:1144
; NATIVE_CALL: PRINT_TEXT at line 1144
    ; PRINT_TEXT: Print text at position
    LDD #-42
    STD >VAR_ARG0
    LDD #114
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_1937924742238227      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_349
IF_NEXT_352:
    LDD >VAR_NEAR_HS
    CMPD #3
    LBNE IF_NEXT_353
; VPy_LINE:1146
; NATIVE_CALL: PRINT_TEXT at line 1146
    ; PRINT_TEXT: Print text at position
    LDD #-21
    STD >VAR_ARG0
    LDD #114
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2209918      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_349
IF_NEXT_353:
    LDD >VAR_NEAR_HS
    CMPD #4
    LBNE IF_NEXT_354
; VPy_LINE:1148
; NATIVE_CALL: PRINT_TEXT at line 1148
    ; PRINT_TEXT: Print text at position
    LDD #-35
    STD >VAR_ARG0
    LDD #114
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_72273926210      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_349
IF_NEXT_354:
    LDD >VAR_NEAR_HS
    CMPD #5
    LBNE IF_END_349
; VPy_LINE:1150
; NATIVE_CALL: PRINT_TEXT at line 1150
    ; PRINT_TEXT: Print text at position
    LDD #-49
    STD >VAR_ARG0
    LDD #114
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_66939517582935176      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_349
IF_END_349:
    LBRA IF_END_342
IF_NEXT_348:
    LDD >VAR_CURRENT_ROOM
    CMPD #2
    LBNE IF_NEXT_355
; VPy_LINE:1152
    LDD >VAR_NEAR_HS
    CMPD #0
    LBNE IF_NEXT_357
; VPy_LINE:1153
; NATIVE_CALL: PRINT_TEXT at line 1153
    ; PRINT_TEXT: Print text at position
    LDD #-21
    STD >VAR_ARG0
    LDD #114
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_65039267      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_356
IF_NEXT_357:
    LDD >VAR_NEAR_HS
    CMPD #1
    LBNE IF_NEXT_358
; VPy_LINE:1155
; NATIVE_CALL: PRINT_TEXT at line 1155
    ; PRINT_TEXT: Print text at position
    LDD #-42
    STD >VAR_ARG0
    LDD #114
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_61337815899504      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_356
IF_NEXT_358:
    LDD >VAR_NEAR_HS
    CMPD #2
    LBNE IF_NEXT_359
; VPy_LINE:1157
; NATIVE_CALL: PRINT_TEXT at line 1157
    ; PRINT_TEXT: Print text at position
    LDD #-49
    STD >VAR_ARG0
    LDD #114
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_65431604815861807      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_356
IF_NEXT_359:
    LDD >VAR_NEAR_HS
    CMPD #3
    LBNE IF_END_356
; VPy_LINE:1159
; NATIVE_CALL: PRINT_TEXT at line 1159
    ; PRINT_TEXT: Print text at position
    LDD #-35
    STD >VAR_ARG0
    LDD #114
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_61386845752      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_356
IF_END_356:
    LBRA IF_END_342
IF_NEXT_355:
    LDD >VAR_CURRENT_ROOM
    CMPD #3
    LBNE IF_NEXT_360
; VPy_LINE:1161
    LDD >VAR_NEAR_HS
    CMPD #0
    LBNE IF_NEXT_362
; VPy_LINE:1162
; NATIVE_CALL: PRINT_TEXT at line 1162
    ; PRINT_TEXT: Print text at position
    LDD #-35
    STD >VAR_ARG0
    LDD #114
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2264259943554      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_361
IF_NEXT_362:
    LDD >VAR_NEAR_HS
    CMPD #1
    LBNE IF_END_361
; VPy_LINE:1164
; NATIVE_CALL: PRINT_TEXT at line 1164
    ; PRINT_TEXT: Print text at position
    LDD #-42
    STD >VAR_ARG0
    LDD #114
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_61337815899504      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_361
IF_END_361:
    LBRA IF_END_342
IF_NEXT_360:
    LDD >VAR_CURRENT_ROOM
    CMPD #4
    LBNE IF_NEXT_363
; VPy_LINE:1166
    LDD >VAR_NEAR_HS
    CMPD #0
    LBNE IF_NEXT_365
; VPy_LINE:1167
; NATIVE_CALL: PRINT_TEXT at line 1167
    ; PRINT_TEXT: Print text at position
    LDD #-49
    STD >VAR_ARG0
    LDD #114
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_67802925895808570      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_364
IF_NEXT_365:
    LDD >VAR_NEAR_HS
    CMPD #1
    LBNE IF_END_364
; VPy_LINE:1169
; NATIVE_CALL: PRINT_TEXT at line 1169
    ; PRINT_TEXT: Print text at position
    LDD #-49
    STD >VAR_ARG0
    LDD #114
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_57071759112686642      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_364
IF_END_364:
    LBRA IF_END_342
IF_NEXT_363:
    LDD >VAR_CURRENT_ROOM
    CMPD #5
    LBNE IF_NEXT_366
; VPy_LINE:1171
    LDD >VAR_NEAR_HS
    CMPD #0
    LBNE IF_NEXT_368
; VPy_LINE:1172
; NATIVE_CALL: PRINT_TEXT at line 1172
    ; PRINT_TEXT: Print text at position
    LDD #-21
    STD >VAR_ARG0
    LDD #114
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_66059856      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_367
IF_NEXT_368:
IF_END_367:
    LBRA IF_END_342
IF_NEXT_366:
    LDD >VAR_CURRENT_ROOM
    CMPD #6
    LBNE IF_END_342
; VPy_LINE:1174
    LDD >VAR_NEAR_HS
    CMPD #0
    LBNE IF_NEXT_370
; VPy_LINE:1175
; NATIVE_CALL: PRINT_TEXT at line 1175
    ; PRINT_TEXT: Print text at position
    LDD #-42
    STD >VAR_ARG0
    LDD #114
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_1789082557890417      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_369
IF_NEXT_370:
    LDD >VAR_NEAR_HS
    CMPD #1
    LBNE IF_END_369
; VPy_LINE:1177
; NATIVE_CALL: PRINT_TEXT at line 1177
    ; PRINT_TEXT: Print text at position
    LDD #-42
    STD >VAR_ARG0
    LDD #114
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2331653882236156      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_369
IF_END_369:
    LBRA IF_END_342
IF_END_342:
    RTS

; Function: DRAW_VERB_INDICATOR (Bank #0)
DRAW_VERB_INDICATOR:
; VPy_LINE:1180
    LDD >VAR_CURRENT_VERB
    CMPD #0
    LBNE IF_NEXT_372
; VPy_LINE:1181
; NATIVE_CALL: PRINT_TEXT at line 1181
    ; PRINT_TEXT: Print text at position
    LDD #-42
    STD >VAR_ARG0
    LDD #127
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_63819514689      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_371
IF_NEXT_372:
    LDD >VAR_CURRENT_VERB
    CMPD #1
    LBNE IF_NEXT_373
; VPy_LINE:1183
; NATIVE_CALL: PRINT_TEXT at line 1183
    ; PRINT_TEXT: Print text at position
    LDD #-28
    STD >VAR_ARG0
    LDD #127
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2567303      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_371
IF_NEXT_373:
    LDD >VAR_CURRENT_VERB
    CMPD #2
    LBNE IF_NEXT_374
; VPy_LINE:1185
; NATIVE_CALL: PRINT_TEXT at line 1185
    ; PRINT_TEXT: Print text at position
    LDD #-21
    STD >VAR_ARG0
    LDD #127
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_84327      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_371
IF_NEXT_374:
    LDD >VAR_CURRENT_VERB
    CMPD #3
    LBNE IF_END_371
; VPy_LINE:1187
    LDD >VAR_ACTIVE_ITEM
    CMPD #-1
    LBNE IF_NEXT_376
; VPy_LINE:1188
; NATIVE_CALL: PRINT_TEXT at line 1188
    ; PRINT_TEXT: Print text at position
    LDD #-28
    STD >VAR_ARG0
    LDD #127
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2188049      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_375
IF_NEXT_376:
    LDD >VAR_ACTIVE_ITEM
    CMPD #0
    LBNE IF_NEXT_377
; VPy_LINE:1190
; NATIVE_CALL: PRINT_TEXT at line 1190
    ; PRINT_TEXT: Print text at position
    LDD #-49
    STD >VAR_ARG0
    LDD #127
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_62642041113543      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_375
IF_NEXT_377:
    LDD >VAR_ACTIVE_ITEM
    CMPD #1
    LBNE IF_NEXT_378
; VPy_LINE:1192
; NATIVE_CALL: PRINT_TEXT at line 1192
    ; PRINT_TEXT: Print text at position
    LDD #-49
    STD >VAR_ARG0
    LDD #127
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_62642040964184      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_375
IF_NEXT_378:
    LDD >VAR_ACTIVE_ITEM
    CMPD #2
    LBNE IF_NEXT_379
; VPy_LINE:1194
; NATIVE_CALL: PRINT_TEXT at line 1194
    ; PRINT_TEXT: Print text at position
    LDD #-56
    STD >VAR_ARG0
    LDD #127
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_1941903278596472      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_375
IF_NEXT_379:
    LDD >VAR_ACTIVE_ITEM
    CMPD #3
    LBNE IF_NEXT_380
; VPy_LINE:1196
; NATIVE_CALL: PRINT_TEXT at line 1196
    ; PRINT_TEXT: Print text at position
    LDD #-63
    STD >VAR_ARG0
    LDD #127
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_1941903265492996      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_375
IF_NEXT_380:
    LDD >VAR_ACTIVE_ITEM
    CMPD #4
    LBNE IF_NEXT_381
; VPy_LINE:1198
; NATIVE_CALL: PRINT_TEXT at line 1198
    ; PRINT_TEXT: Print text at position
    LDD #-42
    STD >VAR_ARG0
    LDD #127
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2020710997544      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_375
IF_NEXT_381:
    LDD >VAR_ACTIVE_ITEM
    CMPD #5
    LBNE IF_NEXT_382
; VPy_LINE:1200
; NATIVE_CALL: PRINT_TEXT at line 1200
    ; PRINT_TEXT: Print text at position
    LDD #-42
    STD >VAR_ARG0
    LDD #127
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2020711006665      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_375
IF_NEXT_382:
    LDD >VAR_ACTIVE_ITEM
    CMPD #6
    LBNE IF_NEXT_383
; VPy_LINE:1202
; NATIVE_CALL: PRINT_TEXT at line 1202
    ; PRINT_TEXT: Print text at position
    LDD #-56
    STD >VAR_ARG0
    LDD #127
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_1941903281064854      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_375
IF_NEXT_383:
    LDD >VAR_ACTIVE_ITEM
    CMPD #7
    LBNE IF_END_375
; VPy_LINE:1204
; NATIVE_CALL: PRINT_TEXT at line 1204
    ; PRINT_TEXT: Print text at position
    LDD #-42
    STD >VAR_ARG0
    LDD #127
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2020711002710      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_375
IF_END_375:
    LBRA IF_END_371
IF_END_371:
    RTS

; Function: DRAW_MESSAGE (Bank #0)
DRAW_MESSAGE:
; VPy_LINE:1208
; NATIVE_CALL: MSG_DEF at line 1208
; VPy_LINE:1209
; NATIVE_CALL: MSG_DEF at line 1209
; VPy_LINE:1210
; NATIVE_CALL: MSG_DEF at line 1210
; VPy_LINE:1211
; NATIVE_CALL: MSG_DEF at line 1211
; VPy_LINE:1212
; NATIVE_CALL: MSG_DEF at line 1212
; VPy_LINE:1213
; NATIVE_CALL: MSG_DEF at line 1213
; VPy_LINE:1214
; NATIVE_CALL: MSG_DEF at line 1214
; VPy_LINE:1215
; NATIVE_CALL: MSG_DEF at line 1215
; VPy_LINE:1216
; NATIVE_CALL: MSG_DEF at line 1216
; VPy_LINE:1217
; NATIVE_CALL: MSG_DEF at line 1217
; VPy_LINE:1218
; NATIVE_CALL: MSG_DEF at line 1218
; VPy_LINE:1219
; NATIVE_CALL: MSG_DEF at line 1219
; VPy_LINE:1220
; NATIVE_CALL: MSG_DEF at line 1220
; VPy_LINE:1221
; NATIVE_CALL: MSG_DEF at line 1221
; VPy_LINE:1222
; NATIVE_CALL: MSG_DEF at line 1222
; VPy_LINE:1223
; NATIVE_CALL: MSG_DEF at line 1223
; VPy_LINE:1224
; NATIVE_CALL: MSG_DEF at line 1224
; VPy_LINE:1225
; NATIVE_CALL: MSG_DEF at line 1225
; VPy_LINE:1226
; NATIVE_CALL: MSG_DEF at line 1226
; VPy_LINE:1227
; NATIVE_CALL: MSG_DEF at line 1227
; VPy_LINE:1228
; NATIVE_CALL: MSG_DEF at line 1228
; VPy_LINE:1229
; NATIVE_CALL: MSG_DEF at line 1229
; VPy_LINE:1230
; NATIVE_CALL: MSG_DEF at line 1230
; VPy_LINE:1231
; NATIVE_CALL: MSG_DEF at line 1231
; VPy_LINE:1232
; NATIVE_CALL: MSG_DEF at line 1232
; VPy_LINE:1233
; NATIVE_CALL: MSG_DEF at line 1233
; VPy_LINE:1234
; NATIVE_CALL: MSG_DEF at line 1234
; VPy_LINE:1235
; NATIVE_CALL: MSG_DEF at line 1235
; VPy_LINE:1236
; NATIVE_CALL: MSG_DEF at line 1236
; VPy_LINE:1237
; NATIVE_CALL: MSG_DEF at line 1237
; VPy_LINE:1238
; NATIVE_CALL: MSG_DEF at line 1238
; VPy_LINE:1239
; NATIVE_CALL: MSG_DEF at line 1239
; VPy_LINE:1240
; NATIVE_CALL: MSG_DEF at line 1240
; VPy_LINE:1241
; NATIVE_CALL: MSG_DEF at line 1241
; VPy_LINE:1242
; NATIVE_CALL: MSG_DEF at line 1242
; VPy_LINE:1243
; NATIVE_CALL: MSG_DEF at line 1243
; VPy_LINE:1244
; NATIVE_CALL: MSG_DEF at line 1244
; VPy_LINE:1245
; NATIVE_CALL: MSG_DEF at line 1245
; VPy_LINE:1246
; NATIVE_CALL: MSG_DEF at line 1246
; VPy_LINE:1247
; NATIVE_CALL: MSG_DEF at line 1247
; VPy_LINE:1248
; NATIVE_CALL: MSG_DEF at line 1248
; VPy_LINE:1249
; NATIVE_CALL: MSG_DEF at line 1249
; VPy_LINE:1250
; NATIVE_CALL: MSG_DEF at line 1250
; VPy_LINE:1251
; NATIVE_CALL: MSG_DEF at line 1251
; VPy_LINE:1252
; NATIVE_CALL: SET_TEXT_SIZE at line 1252
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
; VPy_LINE:1253
; NATIVE_CALL: SET_INTENSITY at line 1253
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1254
; NATIVE_CALL: PRINT_MSG at line 1254
    ; PRINT_MSG: Dispatch via ROM message table
    LDD >VAR_MSG_ID
    STD >VAR_ARG0
    JSR PRINT_MSG_DISPATCH
    LDD #0
    STD RESULT
    RTS

; Function: PICKUP_ITEM (Bank #0)
PICKUP_ITEM:
; VPy_LINE:1260
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD >VAR_ARG0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #0
    LBNE IF_NEXT_385
; VPy_LINE:1261
    LDD >VAR_ARG0
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_INV_ITEMS_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #1
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:1262
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_INV_COUNT
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_INV_COUNT
; VPy_LINE:1263
    LDX #ARRAY_ITEM_WEIGHT_DATA  ; Array base
    LDD >VAR_ARG0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_INV_WEIGHT
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_INV_WEIGHT
; VPy_LINE:1264
; NATIVE_CALL: PLAY_SFX at line 1264
    ; PLAY_SFX("item_pickup") - play SFX asset (index=1)
    LDX #1        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_384
IF_NEXT_385:
IF_END_384:
    RTS

; Function: DROP_ITEM (Bank #0)
DROP_ITEM:
; VPy_LINE:1267
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD >VAR_ARG0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #1
    LBNE IF_NEXT_387
; VPy_LINE:1268
    LDD >VAR_ARG0
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_INV_ITEMS_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #0
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:1269
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_INV_COUNT
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_INV_COUNT
; VPy_LINE:1270
    LDX #ARRAY_ITEM_WEIGHT_DATA  ; Array base
    LDD >VAR_ARG0
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_INV_WEIGHT
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_INV_WEIGHT
    LBRA IF_END_386
IF_NEXT_387:
IF_END_386:
    RTS

; Function: DRAW_INVENTORY (Bank #0)
DRAW_INVENTORY:
; VPy_LINE:1274
; NATIVE_CALL: SET_TEXT_SIZE at line 1274
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
; VPy_LINE:1275
; NATIVE_CALL: SET_INTENSITY at line 1275
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1276
; NATIVE_CALL: PRINT_TEXT at line 1276
    ; PRINT_TEXT: Print text at position
    LDD #-42
    STD >VAR_ARG0
    LDD #115
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_64485404977468      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1278
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #0  ; const ITEM_LENS
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #1
    LBNE IF_NEXT_389
; VPy_LINE:1279
    LDD >VAR_INV_CURSOR
    CMPD #0
    LBNE IF_NEXT_391
; VPy_LINE:1280
; NATIVE_CALL: SET_INTENSITY at line 1280
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
    LBRA IF_END_390
IF_NEXT_391:
; VPy_LINE:1282
; NATIVE_CALL: SET_INTENSITY at line 1282
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
IF_END_390:
    LBRA IF_END_388
IF_NEXT_389:
; VPy_LINE:1284
; NATIVE_CALL: SET_INTENSITY at line 1284
    ; SET_INTENSITY: Set drawing intensity
    LDD #35
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
IF_END_388:
; VPy_LINE:1285
; NATIVE_CALL: PRINT_TEXT at line 1285
    ; PRINT_TEXT: Print text at position
    LDD #-105
    STD >VAR_ARG0
    LDD #90
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_64184922134308892      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1287
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #1  ; const ITEM_GEAR
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #1
    LBNE IF_NEXT_393
; VPy_LINE:1288
    LDD >VAR_INV_CURSOR
    CMPD #1
    LBNE IF_NEXT_395
; VPy_LINE:1289
; NATIVE_CALL: SET_INTENSITY at line 1289
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
    LBRA IF_END_394
IF_NEXT_395:
; VPy_LINE:1291
; NATIVE_CALL: SET_INTENSITY at line 1291
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
IF_END_394:
    LBRA IF_END_392
IF_NEXT_393:
; VPy_LINE:1293
; NATIVE_CALL: SET_INTENSITY at line 1293
    ; SET_INTENSITY: Set drawing intensity
    LDD #35
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
IF_END_392:
; VPy_LINE:1294
; NATIVE_CALL: PRINT_TEXT at line 1294
    ; PRINT_TEXT: Print text at position
    LDD #-105
    STD >VAR_ARG0
    LDD #73
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_60075665603304044      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1296
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #2  ; const ITEM_PRISM
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #1
    LBNE IF_NEXT_397
; VPy_LINE:1297
    LDD >VAR_INV_CURSOR
    CMPD #2
    LBNE IF_NEXT_399
; VPy_LINE:1298
; NATIVE_CALL: SET_INTENSITY at line 1298
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
    LBRA IF_END_398
IF_NEXT_399:
; VPy_LINE:1300
; NATIVE_CALL: SET_INTENSITY at line 1300
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
IF_END_398:
    LBRA IF_END_396
IF_NEXT_397:
; VPy_LINE:1302
; NATIVE_CALL: SET_INTENSITY at line 1302
    ; SET_INTENSITY: Set drawing intensity
    LDD #35
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
IF_END_396:
; VPy_LINE:1303
; NATIVE_CALL: PRINT_TEXT at line 1303
    ; PRINT_TEXT: Print text at position
    LDD #-105
    STD >VAR_ARG0
    LDD #56
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_67802925852799259      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1305
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #3  ; const ITEM_BLANKET
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #1
    LBNE IF_NEXT_401
; VPy_LINE:1306
    LDD >VAR_INV_CURSOR
    CMPD #3
    LBNE IF_NEXT_403
; VPy_LINE:1307
; NATIVE_CALL: SET_INTENSITY at line 1307
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
    LBRA IF_END_402
IF_NEXT_403:
; VPy_LINE:1309
; NATIVE_CALL: SET_INTENSITY at line 1309
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
IF_END_402:
    LBRA IF_END_400
IF_NEXT_401:
; VPy_LINE:1311
; NATIVE_CALL: SET_INTENSITY at line 1311
    ; SET_INTENSITY: Set drawing intensity
    LDD #35
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
IF_END_400:
; VPy_LINE:1312
; NATIVE_CALL: PRINT_TEXT at line 1312
    ; PRINT_TEXT: Print text at position
    LDD #-105
    STD >VAR_ARG0
    LDD #39
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_56162530743028252      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1314
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #4  ; const ITEM_EYE
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #1
    LBNE IF_NEXT_405
; VPy_LINE:1315
    LDD >VAR_INV_CURSOR
    CMPD #4
    LBNE IF_NEXT_407
; VPy_LINE:1316
; NATIVE_CALL: SET_INTENSITY at line 1316
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
    LBRA IF_END_406
IF_NEXT_407:
; VPy_LINE:1318
; NATIVE_CALL: SET_INTENSITY at line 1318
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
IF_END_406:
    LBRA IF_END_404
IF_NEXT_405:
; VPy_LINE:1320
; NATIVE_CALL: SET_INTENSITY at line 1320
    ; SET_INTENSITY: Set drawing intensity
    LDD #35
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
IF_END_404:
; VPy_LINE:1321
; NATIVE_CALL: PRINT_TEXT at line 1321
    ; PRINT_TEXT: Print text at position
    LDD #-105
    STD >VAR_ARG0
    LDD #22
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_58967237406000075      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1323
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #5  ; const ITEM_OIL
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #1
    LBNE IF_NEXT_409
; VPy_LINE:1324
    LDD >VAR_INV_CURSOR
    CMPD #5
    LBNE IF_NEXT_411
; VPy_LINE:1325
; NATIVE_CALL: SET_INTENSITY at line 1325
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
    LBRA IF_END_410
IF_NEXT_411:
; VPy_LINE:1327
; NATIVE_CALL: SET_INTENSITY at line 1327
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
IF_END_410:
    LBRA IF_END_408
IF_NEXT_409:
; VPy_LINE:1329
; NATIVE_CALL: SET_INTENSITY at line 1329
    ; SET_INTENSITY: Set drawing intensity
    LDD #35
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
IF_END_408:
; VPy_LINE:1330
; NATIVE_CALL: PRINT_TEXT at line 1330
    ; PRINT_TEXT: Print text at position
    LDD #-105
    STD >VAR_ARG0
    LDD #5
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_66746456558499436      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1332
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #6  ; const ITEM_SHEET
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #1
    LBNE IF_NEXT_413
; VPy_LINE:1333
    LDD >VAR_INV_CURSOR
    CMPD #6
    LBNE IF_NEXT_415
; VPy_LINE:1334
; NATIVE_CALL: SET_INTENSITY at line 1334
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
    LBRA IF_END_414
IF_NEXT_415:
; VPy_LINE:1336
; NATIVE_CALL: SET_INTENSITY at line 1336
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
IF_END_414:
    LBRA IF_END_412
IF_NEXT_413:
; VPy_LINE:1338
; NATIVE_CALL: SET_INTENSITY at line 1338
    ; SET_INTENSITY: Set drawing intensity
    LDD #35
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
IF_END_412:
; VPy_LINE:1339
; NATIVE_CALL: PRINT_TEXT at line 1339
    ; PRINT_TEXT: Print text at position
    LDD #-105
    STD >VAR_ARG0
    LDD #-12
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_69993623963913400      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1341
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #7  ; const ITEM_KEY
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #1
    LBNE IF_NEXT_417
; VPy_LINE:1342
    LDD >VAR_INV_CURSOR
    CMPD #7
    LBNE IF_NEXT_419
; VPy_LINE:1343
; NATIVE_CALL: SET_INTENSITY at line 1343
    ; SET_INTENSITY: Set drawing intensity
    LDD #127
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
    LBRA IF_END_418
IF_NEXT_419:
; VPy_LINE:1345
; NATIVE_CALL: SET_INTENSITY at line 1345
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
IF_END_418:
    LBRA IF_END_416
IF_NEXT_417:
; VPy_LINE:1347
; NATIVE_CALL: SET_INTENSITY at line 1347
    ; SET_INTENSITY: Set drawing intensity
    LDD #35
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
IF_END_416:
; VPy_LINE:1348
; NATIVE_CALL: PRINT_TEXT at line 1348
    ; PRINT_TEXT: Print text at position
    LDD #-105
    STD >VAR_ARG0
    LDD #-29
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_72649866947832674      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1350
    LDD #3
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INV_WEIGHT
    CMPD TMPVAL
    LBGT .CMP_146_TRUE
    LDD #0
    LBRA .CMP_146_END
.CMP_146_TRUE:
    LDD #1
.CMP_146_END:
    LBEQ IF_NEXT_421
; VPy_LINE:1351
; NATIVE_CALL: SET_INTENSITY at line 1351
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1352
; NATIVE_CALL: PRINT_TEXT at line 1352
    ; PRINT_TEXT: Print text at position
    LDD #-105
    STD >VAR_ARG0
    LDD #-60
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_1357395807964332428      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_420
IF_NEXT_421:
; VPy_LINE:1354
; NATIVE_CALL: SET_INTENSITY at line 1354
    ; SET_INTENSITY: Set drawing intensity
    LDD #70
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1355
; NATIVE_CALL: PRINT_TEXT at line 1355
    ; PRINT_TEXT: Print text at position
    LDD #-42
    STD >VAR_ARG0
    LDD #-60
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_76166780098692      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
IF_END_420:
; VPy_LINE:1356
; NATIVE_CALL: SET_INTENSITY at line 1356
    ; SET_INTENSITY: Set drawing intensity
    LDD #60
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1357
; NATIVE_CALL: PRINT_TEXT at line 1357
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD >VAR_ARG0
    LDD #-80
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_6391486935903418068      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    RTS

; Function: DRAW_TESTAMENT (Bank #0)
DRAW_TESTAMENT:
; VPy_LINE:1363
; NATIVE_CALL: SET_TEXT_SIZE at line 1363
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
; VPy_LINE:1364
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_TESTAMENT_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_TESTAMENT_Y
; VPy_LINE:1366
    LDD >VAR_TESTAMENT_PAGE
    CMPD #0
    LBNE IF_NEXT_423
; VPy_LINE:1367
; NATIVE_CALL: SET_INTENSITY at line 1367
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1368
; NATIVE_CALL: PRINT_TEXT at line 1368
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD >VAR_ARG0
    LDD #15
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_TESTAMENT_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_12694600541101677361      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1369
; NATIVE_CALL: SET_INTENSITY at line 1369
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1370
; NATIVE_CALL: PRINT_TEXT at line 1370
    ; PRINT_TEXT: Print text at position
    LDD #-84
    STD >VAR_ARG0
    LDD #15
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_TESTAMENT_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_3054387366258387060      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_422
IF_NEXT_423:
    LDD >VAR_TESTAMENT_PAGE
    CMPD #1
    LBNE IF_END_422
; VPy_LINE:1372
; NATIVE_CALL: SET_INTENSITY at line 1372
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1373
; NATIVE_CALL: PRINT_TEXT at line 1373
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD >VAR_ARG0
    LDD #15
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_TESTAMENT_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_14476289871539234619      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1374
; NATIVE_CALL: SET_INTENSITY at line 1374
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1375
; NATIVE_CALL: PRINT_TEXT at line 1375
    ; PRINT_TEXT: Print text at position
    LDD #-84
    STD >VAR_ARG0
    LDD #15
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_TESTAMENT_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_15647433387823626580      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_422
IF_END_422:
; VPy_LINE:1377
    LDD #110
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_TESTAMENT_Y
    CMPD TMPVAL
    LBGT .CMP_147_TRUE
    LDD #0
    LBRA .CMP_147_END
.CMP_147_TRUE:
    LDD #1
.CMP_147_END:
    LBEQ IF_NEXT_425
; VPy_LINE:1378
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_TESTAMENT_PAGE
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_TESTAMENT_PAGE
; VPy_LINE:1379
    LDD #-110
    STD VAR_TESTAMENT_Y
; VPy_LINE:1380
    LDD #2
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_TESTAMENT_PAGE
    CMPD TMPVAL
    LBGE .CMP_148_TRUE
    LDD #0
    LBRA .CMP_148_END
.CMP_148_TRUE:
    LDD #1
.CMP_148_END:
    LBEQ IF_NEXT_427
; VPy_LINE:1381
    LDD #3  ; const STATE_ENDING
    STD VAR_SCREEN
    LBRA IF_END_426
IF_NEXT_427:
IF_END_426:
    LBRA IF_END_424
IF_NEXT_425:
IF_END_424:
    RTS

; Function: DRAW_ENDING (Bank #0)
DRAW_ENDING:
; VPy_LINE:1387
; NATIVE_CALL: SET_TEXT_SIZE at line 1387
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
; VPy_LINE:1388
    LDD #50
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ENDING_Y
    CMPD TMPVAL
    LBLT .CMP_149_TRUE
    LDD #0
    LBRA .CMP_149_END
.CMP_149_TRUE:
    LDD #1
.CMP_149_END:
    LBEQ IF_NEXT_429
; VPy_LINE:1389
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENDING_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_ENDING_Y
    LBRA IF_END_428
IF_NEXT_429:
IF_END_428:
; VPy_LINE:1391
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD #2  ; const FL_ELISA_HELPED
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_B
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    CMPD TMPVAL
    LBNE .CMP_151_TRUE
    LDD #0
    LBRA .CMP_151_END
.CMP_151_TRUE:
    LDD #1
.CMP_151_END:
    LBEQ .LOGIC_150_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD #4  ; const FL_HANS_HELPED
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_B
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    CMPD TMPVAL
    LBNE .CMP_152_TRUE
    LDD #0
    LBRA .CMP_152_END
.CMP_152_TRUE:
    LDD #1
.CMP_152_END:
    LBEQ .LOGIC_150_FALSE
    LDD #1
    LBRA .LOGIC_150_END
.LOGIC_150_FALSE:
    LDD #0
.LOGIC_150_END:
    LBEQ IF_NEXT_431
; VPy_LINE:1393
; NATIVE_CALL: SET_INTENSITY at line 1393
    ; SET_INTENSITY: Set drawing intensity
    LDD #110
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1394
; NATIVE_CALL: PRINT_TEXT at line 1394
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD >VAR_ARG0
    LDD #70
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENDING_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_3688976395448209650      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1395
; NATIVE_CALL: SET_INTENSITY at line 1395
    ; SET_INTENSITY: Set drawing intensity
    LDD #90
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1396
; NATIVE_CALL: PRINT_TEXT at line 1396
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD >VAR_ARG0
    LDD #50
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENDING_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_4750152274843692088      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1397
; NATIVE_CALL: PRINT_TEXT at line 1397
    ; PRINT_TEXT: Print text at position
    LDD #-84
    STD >VAR_ARG0
    LDD #30
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENDING_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_17345789615299082788      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1398
; NATIVE_CALL: SET_INTENSITY at line 1398
    ; SET_INTENSITY: Set drawing intensity
    LDD #70
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1399
; NATIVE_CALL: PRINT_TEXT at line 1399
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD >VAR_ARG0
    LDD #5
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENDING_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2502506564742786359      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1400
; NATIVE_CALL: PRINT_TEXT at line 1400
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD >VAR_ARG0
    LDD #15
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENDING_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_11654038037461762538      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1401
; NATIVE_CALL: PRINT_TEXT at line 1401
    ; PRINT_TEXT: Print text at position
    LDD #-63
    STD >VAR_ARG0
    LDD #35
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENDING_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_1863858565675      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1402
; NATIVE_CALL: SET_INTENSITY at line 1402
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1403
; NATIVE_CALL: PRINT_TEXT at line 1403
    ; PRINT_TEXT: Print text at position
    LDD #-63
    STD >VAR_ARG0
    LDD #65
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENDING_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_71091249681780729      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_430
IF_NEXT_431:
    LDD #2  ; const FL_ELISA_HELPED
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_B
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    CMPD #0
    LBEQ IF_NEXT_432
; VPy_LINE:1406
; NATIVE_CALL: SET_INTENSITY at line 1406
    ; SET_INTENSITY: Set drawing intensity
    LDD #110
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1407
; NATIVE_CALL: PRINT_TEXT at line 1407
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD >VAR_ARG0
    LDD #70
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENDING_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_1694552686414567337      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1408
; NATIVE_CALL: SET_INTENSITY at line 1408
    ; SET_INTENSITY: Set drawing intensity
    LDD #90
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1409
; NATIVE_CALL: PRINT_TEXT at line 1409
    ; PRINT_TEXT: Print text at position
    LDD #-84
    STD >VAR_ARG0
    LDD #50
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENDING_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_894489252191113018      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1410
; NATIVE_CALL: PRINT_TEXT at line 1410
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD >VAR_ARG0
    LDD #30
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENDING_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_18135904787860682873      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1411
; NATIVE_CALL: PRINT_TEXT at line 1411
    ; PRINT_TEXT: Print text at position
    LDD #-56
    STD >VAR_ARG0
    LDD #10
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENDING_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_70966799469806525      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1412
; NATIVE_CALL: SET_INTENSITY at line 1412
    ; SET_INTENSITY: Set drawing intensity
    LDD #60
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1413
; NATIVE_CALL: PRINT_TEXT at line 1413
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD >VAR_ARG0
    LDD #15
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENDING_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_17643359177242884552      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1414
; NATIVE_CALL: PRINT_TEXT at line 1414
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD >VAR_ARG0
    LDD #35
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENDING_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_679393960477689362      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1415
; NATIVE_CALL: PRINT_TEXT at line 1415
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD >VAR_ARG0
    LDD #55
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENDING_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_6586363433779781634      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1416
; NATIVE_CALL: SET_INTENSITY at line 1416
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1417
; NATIVE_CALL: PRINT_TEXT at line 1417
    ; PRINT_TEXT: Print text at position
    LDD #-56
    STD >VAR_ARG0
    LDD #80
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENDING_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_69586596903166      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_430
IF_NEXT_432:
; VPy_LINE:1420
; NATIVE_CALL: SET_INTENSITY at line 1420
    ; SET_INTENSITY: Set drawing intensity
    LDD #110
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1421
; NATIVE_CALL: PRINT_TEXT at line 1421
    ; PRINT_TEXT: Print text at position
    LDD #-77
    STD >VAR_ARG0
    LDD #70
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENDING_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_15031599020925928582      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1422
; NATIVE_CALL: SET_INTENSITY at line 1422
    ; SET_INTENSITY: Set drawing intensity
    LDD #90
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1423
; NATIVE_CALL: PRINT_TEXT at line 1423
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD >VAR_ARG0
    LDD #50
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENDING_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_8058628335699392711      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1424
; NATIVE_CALL: PRINT_TEXT at line 1424
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD >VAR_ARG0
    LDD #30
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENDING_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_3134159664534957280      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1425
; NATIVE_CALL: PRINT_TEXT at line 1425
    ; PRINT_TEXT: Print text at position
    LDD #-84
    STD >VAR_ARG0
    LDD #10
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENDING_Y
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_16762347117432342118      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1426
; NATIVE_CALL: SET_INTENSITY at line 1426
    ; SET_INTENSITY: Set drawing intensity
    LDD #60
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1427
; NATIVE_CALL: PRINT_TEXT at line 1427
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD >VAR_ARG0
    LDD #15
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENDING_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_17954386693183881976      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1428
; NATIVE_CALL: PRINT_TEXT at line 1428
    ; PRINT_TEXT: Print text at position
    LDD #-84
    STD >VAR_ARG0
    LDD #35
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENDING_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_6894498445181154440      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1429
; NATIVE_CALL: SET_INTENSITY at line 1429
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1430
; NATIVE_CALL: PRINT_TEXT at line 1430
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD >VAR_ARG0
    LDD #65
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENDING_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_3443128850001289426      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
IF_END_430:
; VPy_LINE:1432
; NATIVE_CALL: SET_INTENSITY at line 1432
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1433
; NATIVE_CALL: PRINT_TEXT at line 1433
    ; PRINT_TEXT: Print text at position
    LDD #-49
    STD >VAR_ARG0
    LDD #95
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_ENDING_Y
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2376966947138      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1435
    LDD #50
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ENDING_Y
    CMPD TMPVAL
    LBGE .CMP_153_TRUE
    LDD #0
    LBRA .CMP_153_END
.CMP_153_TRUE:
    LDD #1
.CMP_153_END:
    LBEQ IF_NEXT_434
; VPy_LINE:1436
; NATIVE_CALL: SET_INTENSITY at line 1436
    ; SET_INTENSITY: Set drawing intensity
    LDD #50
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:1437
; NATIVE_CALL: PRINT_TEXT at line 1437
    ; PRINT_TEXT: Print text at position
    LDD #-84
    STD >VAR_ARG0
    LDD #-90
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_15373067420087200981      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:1438
    LDD >VAR_BTN1_FIRED
    CMPD #1
    LBNE IF_NEXT_436
; VPy_LINE:1439
    LDD #-110
    STD VAR_ENDING_Y
; VPy_LINE:1440
    LDD #0  ; const STATE_TITLE
    STD VAR_SCREEN
; VPy_LINE:1441
    LDD #1  ; const MUSIC_TITLE
    STB VAR_CURRENT_MUSIC
; VPy_LINE:1442
; NATIVE_CALL: PLAY_MUSIC at line 1442
    ; PLAY_MUSIC("intro") - play music asset (index=1)
    LDX #1        ; Music asset index for lookup
    JSR PLAY_MUSIC_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_435
IF_NEXT_436:
IF_END_435:
    LBRA IF_END_433
IF_NEXT_434:
IF_END_433:
    RTS

; Function: ACCELERATE_HEARTBEAT (Bank #0)
ACCELERATE_HEARTBEAT:
; VPy_LINE:1448
    LDD #8
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_HEARTBEAT_TEMPO
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_HEARTBEAT_TEMPO
; VPy_LINE:1449
    LDD #20
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_HEARTBEAT_TEMPO
    CMPD TMPVAL
    LBLT .CMP_154_TRUE
    LDD #0
    LBRA .CMP_154_END
.CMP_154_TRUE:
    LDD #1
.CMP_154_END:
    LBEQ IF_NEXT_438
; VPy_LINE:1450
    LDD #20
    STD VAR_HEARTBEAT_TEMPO
    LBRA IF_END_437
IF_NEXT_438:
IF_END_437:
    RTS


; ================================================


; ===== BANK #01 (physical offset $04000) =====

    ORG $0000  ; Sequential bank model

; Function: UPDATE_ROOM (Bank #1)
UPDATE_ROOM:
; VPy_LINE:433
; NATIVE_CALL: J1_X at line 433
    JSR J1X_BUILTIN
    STD RESULT
    STD VAR_JOY_X
; VPy_LINE:434
    LDD #30
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBGT .CMP_13_TRUE
    LDD #0
    LBRA .CMP_13_END
.CMP_13_TRUE:
    LDD #1
.CMP_13_END:
    LBEQ IF_NEXT_63
; VPy_LINE:435
    LDD >VAR_PLAYER_SPEED
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_PLAYER_X
    LBRA IF_END_62
IF_NEXT_63:
    LDD #-30
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    CMPD TMPVAL
    LBLT .CMP_14_TRUE
    LDD #0
    LBRA .CMP_14_END
.CMP_14_TRUE:
    LDD #1
.CMP_14_END:
    LBEQ IF_END_62
; VPy_LINE:437
    LDD >VAR_PLAYER_SPEED
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_PLAYER_X
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_PLAYER_X
    LBRA IF_END_62
IF_END_62:
; VPy_LINE:439
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
; VPy_LINE:441
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
; VPy_LINE:442
; NATIVE_CALL: SET_CAMERA_X at line 442
    ; ===== SET_CAMERA_X builtin =====
    LDD >VAR_SCROLL_X
    STD >CAMERA_X    ; Store 16-bit camera X scroll offset
    LDD #0
    STD RESULT
; VPy_LINE:444
    LDD #-1
    STD VAR_NEAR_HS
; VPy_LINE:445
    LDD >VAR_CURRENT_ROOM
    CMPD #0
    LBNE IF_NEXT_65
; VPy_LINE:446
    JSR TRAMP_CHECK_ENTRANCE_HOTSPOTS  ; cross-bank trampoline (bank #1 -> bank #0)
; VPy_LINE:447
    LDD #-85
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    CMPD TMPVAL
    LBLE .CMP_17_TRUE
    LDD #0
    LBRA .CMP_17_END
.CMP_17_TRUE:
    LDD #1
.CMP_17_END:
    LBEQ .LOGIC_16_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD #2  ; const FL_TALLER_OPEN
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_A
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    CMPD TMPVAL
    LBNE .CMP_18_TRUE
    LDD #0
    LBRA .CMP_18_END
.CMP_18_TRUE:
    LDD #1
.CMP_18_END:
    LBEQ .LOGIC_16_FALSE
    LDD #1
    LBRA .LOGIC_16_END
.LOGIC_16_FALSE:
    LDD #0
.LOGIC_16_END:
    LBEQ .LOGIC_15_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    CMPD TMPVAL
    LBEQ .CMP_19_TRUE
    LDD #0
    LBRA .CMP_19_END
.CMP_19_TRUE:
    LDD #1
.CMP_19_END:
    LBEQ .LOGIC_15_FALSE
    LDD #1
    LBRA .LOGIC_15_END
.LOGIC_15_FALSE:
    LDD #0
.LOGIC_15_END:
    LBEQ IF_NEXT_67
; VPy_LINE:448
    LDD #5  ; const ROOM_CONSERVATORY
    STD VAR_ARG0
    JSR TRAMP_ENTER_ROOM  ; cross-bank trampoline (bank #1 -> bank #0)
    LBRA IF_END_66
IF_NEXT_67:
IF_END_66:
    LBRA IF_END_64
IF_NEXT_65:
    LDD >VAR_CURRENT_ROOM
    CMPD #1
    LBNE IF_NEXT_68
; VPy_LINE:450
    JSR TRAMP_CHECK_WORKSHOP_HOTSPOTS  ; cross-bank trampoline (bank #1 -> bank #0)
; VPy_LINE:451
    LDD #770
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    CMPD TMPVAL
    LBGE .CMP_22_TRUE
    LDD #0
    LBRA .CMP_22_END
.CMP_22_TRUE:
    LDD #1
.CMP_22_END:
    LBEQ .LOGIC_21_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD #16  ; const FL_PANEL_ACTIVE
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_A
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    CMPD TMPVAL
    LBNE .CMP_23_TRUE
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
    LBEQ .LOGIC_20_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    CMPD TMPVAL
    LBEQ .CMP_24_TRUE
    LDD #0
    LBRA .CMP_24_END
.CMP_24_TRUE:
    LDD #1
.CMP_24_END:
    LBEQ .LOGIC_20_FALSE
    LDD #1
    LBRA .LOGIC_20_END
.LOGIC_20_FALSE:
    LDD #0
.LOGIC_20_END:
    LBEQ IF_NEXT_70
; VPy_LINE:452
    LDD #6  ; const ROOM_VAULT_CORRIDOR
    STD VAR_ARG0
    JSR TRAMP_ENTER_ROOM  ; cross-bank trampoline (bank #1 -> bank #0)
    LBRA IF_END_69
IF_NEXT_70:
IF_END_69:
; VPy_LINE:453
    LDD #690
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    CMPD TMPVAL
    LBGE .CMP_28_TRUE
    LDD #0
    LBRA .CMP_28_END
.CMP_28_TRUE:
    LDD #1
.CMP_28_END:
    LBEQ .LOGIC_27_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD #128  ; const FL_OPTICS_OPEN
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_A
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    CMPD TMPVAL
    LBNE .CMP_29_TRUE
    LDD #0
    LBRA .CMP_29_END
.CMP_29_TRUE:
    LDD #1
.CMP_29_END:
    LBEQ .LOGIC_27_FALSE
    LDD #1
    LBRA .LOGIC_27_END
.LOGIC_27_FALSE:
    LDD #0
.LOGIC_27_END:
    LBEQ .LOGIC_26_FALSE
    LDD #770
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    CMPD TMPVAL
    LBLT .CMP_30_TRUE
    LDD #0
    LBRA .CMP_30_END
.CMP_30_TRUE:
    LDD #1
.CMP_30_END:
    LBEQ .LOGIC_26_FALSE
    LDD #1
    LBRA .LOGIC_26_END
.LOGIC_26_FALSE:
    LDD #0
.LOGIC_26_END:
    LBEQ .LOGIC_25_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    CMPD TMPVAL
    LBEQ .CMP_31_TRUE
    LDD #0
    LBRA .CMP_31_END
.CMP_31_TRUE:
    LDD #1
.CMP_31_END:
    LBEQ .LOGIC_25_FALSE
    LDD #1
    LBRA .LOGIC_25_END
.LOGIC_25_FALSE:
    LDD #0
.LOGIC_25_END:
    LBEQ IF_NEXT_72
; VPy_LINE:454
    LDD #4  ; const ROOM_OPTICS
    STD VAR_ARG0
    JSR TRAMP_ENTER_ROOM  ; cross-bank trampoline (bank #1 -> bank #0)
    LBRA IF_END_71
IF_NEXT_72:
IF_END_71:
    LBRA IF_END_64
IF_NEXT_68:
    LDD >VAR_CURRENT_ROOM
    CMPD #2
    LBNE IF_NEXT_73
; VPy_LINE:456
    JSR TRAMP_CHECK_ANTEROOM_HOTSPOTS  ; cross-bank trampoline (bank #1 -> bank #0)
; VPy_LINE:457
    LDD #-85
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    CMPD TMPVAL
    LBLE .CMP_33_TRUE
    LDD #0
    LBRA .CMP_33_END
.CMP_33_TRUE:
    LDD #1
.CMP_33_END:
    LBEQ .LOGIC_32_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
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
    LBEQ IF_NEXT_75
; VPy_LINE:458
    LDD #0  ; const ROOM_ENTRANCE
    STD VAR_ARG0
    JSR TRAMP_ENTER_ROOM  ; cross-bank trampoline (bank #1 -> bank #0)
    LBRA IF_END_74
IF_NEXT_75:
IF_END_74:
    LBRA IF_END_64
IF_NEXT_73:
    LDD >VAR_CURRENT_ROOM
    CMPD #3
    LBNE IF_NEXT_76
; VPy_LINE:460
    JSR TRAMP_CHECK_WEIGHTS_HOTSPOTS  ; cross-bank trampoline (bank #1 -> bank #0)
; VPy_LINE:461
    LDD #-85
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    CMPD TMPVAL
    LBLE .CMP_36_TRUE
    LDD #0
    LBRA .CMP_36_END
.CMP_36_TRUE:
    LDD #1
.CMP_36_END:
    LBEQ .LOGIC_35_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
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
    LBEQ IF_NEXT_78
; VPy_LINE:462
    LDD #2  ; const ROOM_ANTEROOM
    STD VAR_ARG0
    JSR TRAMP_ENTER_ROOM  ; cross-bank trampoline (bank #1 -> bank #0)
    LBRA IF_END_77
IF_NEXT_78:
IF_END_77:
    LBRA IF_END_64
IF_NEXT_76:
    LDD >VAR_CURRENT_ROOM
    CMPD #4
    LBNE IF_NEXT_79
; VPy_LINE:464
    JSR TRAMP_CHECK_OPTICS_HOTSPOTS  ; cross-bank trampoline (bank #1 -> bank #0)
; VPy_LINE:465
    LDD #-85
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    CMPD TMPVAL
    LBLE .CMP_39_TRUE
    LDD #0
    LBRA .CMP_39_END
.CMP_39_TRUE:
    LDD #1
.CMP_39_END:
    LBEQ .LOGIC_38_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
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
    LBEQ IF_NEXT_81
; VPy_LINE:466
    LDD #1  ; const ROOM_WORKSHOP
    STD VAR_ARG0
    JSR TRAMP_ENTER_ROOM  ; cross-bank trampoline (bank #1 -> bank #0)
    LBRA IF_END_80
IF_NEXT_81:
IF_END_80:
    LBRA IF_END_64
IF_NEXT_79:
    LDD >VAR_CURRENT_ROOM
    CMPD #5
    LBNE IF_NEXT_82
; VPy_LINE:468
    JSR TRAMP_CHECK_CONSERVATORY_HOTSPOTS  ; cross-bank trampoline (bank #1 -> bank #0)
; VPy_LINE:469
    LDD #60
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    CMPD TMPVAL
    LBGE .CMP_42_TRUE
    LDD #0
    LBRA .CMP_42_END
.CMP_42_TRUE:
    LDD #1
.CMP_42_END:
    LBEQ .LOGIC_41_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    CMPD TMPVAL
    LBEQ .CMP_43_TRUE
    LDD #0
    LBRA .CMP_43_END
.CMP_43_TRUE:
    LDD #1
.CMP_43_END:
    LBEQ .LOGIC_41_FALSE
    LDD #1
    LBRA .LOGIC_41_END
.LOGIC_41_FALSE:
    LDD #0
.LOGIC_41_END:
    LBEQ IF_NEXT_84
; VPy_LINE:470
    LDD #0  ; const ROOM_ENTRANCE
    STD VAR_ARG0
    JSR TRAMP_ENTER_ROOM  ; cross-bank trampoline (bank #1 -> bank #0)
    LBRA IF_END_83
IF_NEXT_84:
IF_END_83:
    LBRA IF_END_64
IF_NEXT_82:
    LDD >VAR_CURRENT_ROOM
    CMPD #6
    LBNE IF_END_64
; VPy_LINE:472
    JSR TRAMP_CHECK_VAULT_HOTSPOTS  ; cross-bank trampoline (bank #1 -> bank #0)
; VPy_LINE:473
    LDD #-85
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_X
    CMPD TMPVAL
    LBLE .CMP_45_TRUE
    LDD #0
    LBRA .CMP_45_END
.CMP_45_TRUE:
    LDD #1
.CMP_45_END:
    LBEQ .LOGIC_44_FALSE
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    CMPD TMPVAL
    LBEQ .CMP_46_TRUE
    LDD #0
    LBRA .CMP_46_END
.CMP_46_TRUE:
    LDD #1
.CMP_46_END:
    LBEQ .LOGIC_44_FALSE
    LDD #1
    LBRA .LOGIC_44_END
.LOGIC_44_FALSE:
    LDD #0
.LOGIC_44_END:
    LBEQ IF_NEXT_86
; VPy_LINE:474
    LDD #1  ; const ROOM_WORKSHOP
    STD VAR_ARG0
    JSR TRAMP_ENTER_ROOM  ; cross-bank trampoline (bank #1 -> bank #0)
    LBRA IF_END_85
IF_NEXT_86:
IF_END_85:
    LBRA IF_END_64
IF_END_64:
; VPy_LINE:477
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    CMPD TMPVAL
    LBGT .CMP_47_TRUE
    LDD #0
    LBRA .CMP_47_END
.CMP_47_TRUE:
    LDD #1
.CMP_47_END:
    LBEQ IF_NEXT_88
; VPy_LINE:478
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_MSG_TIMER
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_MSG_TIMER
; VPy_LINE:479
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    CMPD TMPVAL
    LBEQ .CMP_49_TRUE
    LDD #0
    LBRA .CMP_49_END
.CMP_49_TRUE:
    LDD #1
.CMP_49_END:
    LBEQ .LOGIC_48_FALSE
    LDD #1
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ROOM_EXIT
    CMPD TMPVAL
    LBEQ .CMP_50_TRUE
    LDD #0
    LBRA .CMP_50_END
.CMP_50_TRUE:
    LDD #1
.CMP_50_END:
    LBEQ .LOGIC_48_FALSE
    LDD #1
    LBRA .LOGIC_48_END
.LOGIC_48_FALSE:
    LDD #0
.LOGIC_48_END:
    LBEQ IF_NEXT_90
; VPy_LINE:480
    LDD #0
    STD VAR_ROOM_EXIT
; VPy_LINE:481
    LDD #16  ; const FL_EXIT_TESTAMENT
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_B
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    CMPD #0
    LBEQ IF_NEXT_92
; VPy_LINE:482
    LDD #239
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_B
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    STD VAR_FLAGS_B
; VPy_LINE:483
    LDD #-110
    STD VAR_TESTAMENT_Y
; VPy_LINE:484
    LDD #0
    STD VAR_TESTAMENT_PAGE
; VPy_LINE:485
    LDD #4  ; const STATE_TESTAMENT
    STD VAR_SCREEN
    LBRA IF_END_91
IF_NEXT_92:
    LDD #32  ; const FL_EXIT_ENDING
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_B
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    CMPD #0
    LBEQ IF_NEXT_93
; VPy_LINE:487
    LDD #223
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_B
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    STD VAR_FLAGS_B
; VPy_LINE:488
    LDD #-110
    STD VAR_ENDING_Y
; VPy_LINE:489
    LDD #3  ; const STATE_ENDING
    STD VAR_SCREEN
    LBRA IF_END_91
IF_NEXT_93:
; VPy_LINE:491
    LDD >VAR_EXIT_ROOM_TARGET
    STD VAR_ARG0
    JSR TRAMP_ENTER_ROOM  ; cross-bank trampoline (bank #1 -> bank #0)
IF_END_91:
    LBRA IF_END_89
IF_NEXT_90:
IF_END_89:
    LBRA IF_END_87
IF_NEXT_88:
IF_END_87:
; VPy_LINE:494
    LDD >VAR_BTN3_FIRED
    CMPD #1
    LBNE IF_NEXT_95
; VPy_LINE:495
    LDD >VAR_SHOW_INVENTORY
    CMPD #1
    LBNE IF_NEXT_97
; VPy_LINE:496
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_INV_CURSOR
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_INV_CURSOR
; VPy_LINE:497
    LDD #8  ; const ITEM_COUNT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INV_CURSOR
    CMPD TMPVAL
    LBGE .CMP_51_TRUE
    LDD #0
    LBRA .CMP_51_END
.CMP_51_TRUE:
    LDD #1
.CMP_51_END:
    LBEQ IF_NEXT_99
; VPy_LINE:498
    LDD #0
    STD VAR_INV_CURSOR
    LBRA IF_END_98
IF_NEXT_99:
IF_END_98:
    LBRA IF_END_96
IF_NEXT_97:
    LDD >VAR_MSG_TIMER
    CMPD #0
    LBNE IF_END_96
; VPy_LINE:500
    LDD >VAR_CURRENT_VERB
    CMPD #3
    LBNE IF_NEXT_101
; VPy_LINE:501
    LDD #0  ; const VERB_EXAMINE
    STD VAR_CURRENT_VERB
    LBRA IF_END_100
IF_NEXT_101:
; VPy_LINE:503
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_CURRENT_VERB
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_CURRENT_VERB
IF_END_100:
    LBRA IF_END_96
IF_END_96:
    LBRA IF_END_94
IF_NEXT_95:
IF_END_94:
; VPy_LINE:506
    LDD >VAR_BTN1_FIRED
    CMPD #1
    LBNE IF_NEXT_103
; VPy_LINE:507
    LDD >VAR_SHOW_INVENTORY
    CMPD #1
    LBNE IF_NEXT_105
; VPy_LINE:509
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD >VAR_INV_CURSOR
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #1
    LBNE IF_NEXT_107
; VPy_LINE:510
    LDD >VAR_INV_CURSOR
    STD VAR_ACTIVE_ITEM
    LBRA IF_END_106
IF_NEXT_107:
IF_END_106:
; VPy_LINE:511
    LDD #0
    STD VAR_SHOW_INVENTORY
    LBRA IF_END_104
IF_NEXT_105:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    CMPD TMPVAL
    LBGT .CMP_52_TRUE
    LDD #0
    LBRA .CMP_52_END
.CMP_52_TRUE:
    LDD #1
.CMP_52_END:
    LBEQ IF_NEXT_108
; VPy_LINE:513
    LDD #0
    STD VAR_MSG_TIMER
; VPy_LINE:514
    LDD >VAR_ROOM_EXIT
    CMPD #1
    LBNE IF_NEXT_110
; VPy_LINE:515
    LDD #0
    STD VAR_ROOM_EXIT
; VPy_LINE:516
    LDD #16  ; const FL_EXIT_TESTAMENT
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_B
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    CMPD #0
    LBEQ IF_NEXT_112
; VPy_LINE:517
    LDD #239
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_B
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    STD VAR_FLAGS_B
; VPy_LINE:518
    LDD #-110
    STD VAR_TESTAMENT_Y
; VPy_LINE:519
    LDD #0
    STD VAR_TESTAMENT_PAGE
; VPy_LINE:520
    LDD #4  ; const STATE_TESTAMENT
    STD VAR_SCREEN
    LBRA IF_END_111
IF_NEXT_112:
    LDD #32  ; const FL_EXIT_ENDING
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_B
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    CMPD #0
    LBEQ IF_NEXT_113
; VPy_LINE:522
    LDD #223
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_B
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    STD VAR_FLAGS_B
; VPy_LINE:523
    LDD #3  ; const STATE_ENDING
    STD VAR_SCREEN
    LBRA IF_END_111
IF_NEXT_113:
; VPy_LINE:525
    LDD >VAR_EXIT_ROOM_TARGET
    STD VAR_ARG0
    JSR TRAMP_ENTER_ROOM  ; cross-bank trampoline (bank #1 -> bank #0)
IF_END_111:
    LBRA IF_END_109
IF_NEXT_110:
IF_END_109:
    LBRA IF_END_104
IF_NEXT_108:
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_NEAR_HS
    CMPD TMPVAL
    LBGE .CMP_53_TRUE
    LDD #0
    LBRA .CMP_53_END
.CMP_53_TRUE:
    LDD #1
.CMP_53_END:
    LBEQ IF_END_104
; VPy_LINE:527
    LDD >VAR_CURRENT_ROOM
    CMPD #0
    LBNE IF_NEXT_115
; VPy_LINE:528
    LDD >VAR_NEAR_HS
    STD VAR_ARG0
    JSR INTERACT_ENTRANCE
    LBRA IF_END_114
IF_NEXT_115:
    LDD >VAR_CURRENT_ROOM
    CMPD #1
    LBNE IF_NEXT_116
; VPy_LINE:530
    LDD >VAR_NEAR_HS
    STD VAR_ARG0
    JSR INTERACT_WORKSHOP
    LBRA IF_END_114
IF_NEXT_116:
    LDD >VAR_CURRENT_ROOM
    CMPD #2
    LBNE IF_NEXT_117
; VPy_LINE:532
    LDD >VAR_NEAR_HS
    STD VAR_ARG0
    JSR INTERACT_ANTEROOM
    LBRA IF_END_114
IF_NEXT_117:
    LDD >VAR_CURRENT_ROOM
    CMPD #3
    LBNE IF_NEXT_118
; VPy_LINE:534
    LDD >VAR_NEAR_HS
    STD VAR_ARG0
    JSR INTERACT_WEIGHTS
    LBRA IF_END_114
IF_NEXT_118:
    LDD >VAR_CURRENT_ROOM
    CMPD #4
    LBNE IF_NEXT_119
; VPy_LINE:536
    LDD >VAR_NEAR_HS
    STD VAR_ARG0
    JSR INTERACT_OPTICS
    LBRA IF_END_114
IF_NEXT_119:
    LDD >VAR_CURRENT_ROOM
    CMPD #5
    LBNE IF_NEXT_120
; VPy_LINE:538
    LDD >VAR_NEAR_HS
    STD VAR_ARG0
    JSR TRAMP_INTERACT_CONSERVATORY  ; cross-bank trampoline (bank #1 -> bank #0)
    LBRA IF_END_114
IF_NEXT_120:
    LDD >VAR_CURRENT_ROOM
    CMPD #6
    LBNE IF_END_114
; VPy_LINE:540
    LDD >VAR_NEAR_HS
    STD VAR_ARG0
    JSR INTERACT_VAULT
    LBRA IF_END_114
IF_END_114:
    LBRA IF_END_104
IF_END_104:
    LBRA IF_END_102
IF_NEXT_103:
IF_END_102:
    RTS

; Function: INTERACT_ENTRANCE (Bank #1)
INTERACT_ENTRANCE:
; VPy_LINE:652
    LDD >VAR_ARG0
    CMPD #0
    LBNE IF_NEXT_174
; VPy_LINE:653
    LDD >VAR_CURRENT_VERB
    CMPD #0
    LBNE IF_NEXT_176
; VPy_LINE:654
    LDD #1  ; const FL_DATE_KNOWN
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_A
    ORA TMPVAL          ; A OR TMPVAL+0
    ORB TMPVAL+1        ; B OR TMPVAL+1
    STD VAR_FLAGS_A
; VPy_LINE:655
    LDD #1
    STD VAR_MSG_ID
; VPy_LINE:656
    LDD #160
    STD VAR_MSG_TIMER
    LBRA IF_END_175
IF_NEXT_176:
    LDD >VAR_CURRENT_VERB
    CMPD #1
    LBNE IF_NEXT_177
; VPy_LINE:658
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:659
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_175
IF_NEXT_177:
    LDD >VAR_CURRENT_VERB
    CMPD #2
    LBNE IF_NEXT_178
; VPy_LINE:661
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #4  ; const ITEM_EYE
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #1
    LBNE IF_NEXT_180
; VPy_LINE:662
    LDD #43
    STD VAR_MSG_ID
; VPy_LINE:663
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_179
IF_NEXT_180:
; VPy_LINE:665
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:666
    LDD #100
    STD VAR_MSG_TIMER
IF_END_179:
    LBRA IF_END_175
IF_NEXT_178:
    LDD >VAR_CURRENT_VERB
    CMPD #3
    LBNE IF_END_175
; VPy_LINE:668
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:669
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_175
IF_END_175:
    LBRA IF_END_173
IF_NEXT_174:
    LDD >VAR_ARG0
    CMPD #1
    LBNE IF_NEXT_181
; VPy_LINE:672
    LDD >VAR_CURRENT_VERB
    CMPD #0
    LBNE IF_NEXT_183
; VPy_LINE:673
    LDD #2
    STD VAR_MSG_ID
; VPy_LINE:674
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_182
IF_NEXT_183:
    LDD >VAR_CURRENT_VERB
    CMPD #2
    LBNE IF_NEXT_184
; VPy_LINE:676
    LDD #2  ; const FL_TALLER_OPEN
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_A
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    CMPD #0
    LBEQ IF_NEXT_186
; VPy_LINE:677
    LDD #2  ; const ROOM_ANTEROOM
    STD VAR_EXIT_ROOM_TARGET
; VPy_LINE:678
    LDD #1
    STD VAR_ROOM_EXIT
; VPy_LINE:679
    LDD #60
    STD VAR_MSG_TIMER
    LBRA IF_END_185
IF_NEXT_186:
    LDD #1  ; const FL_DATE_KNOWN
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_A
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    CMPD #0
    LBEQ IF_NEXT_187
; VPy_LINE:681
    LDD #2  ; const FL_TALLER_OPEN
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_A
    ORA TMPVAL          ; A OR TMPVAL+0
    ORB TMPVAL+1        ; B OR TMPVAL+1
    STD VAR_FLAGS_A
; VPy_LINE:682
    LDD #2  ; const ROOM_ANTEROOM
    STD VAR_EXIT_ROOM_TARGET
; VPy_LINE:683
    LDD #4
    STD VAR_MSG_ID
; VPy_LINE:684
    LDD #200
    STD VAR_MSG_TIMER
; VPy_LINE:685
    LDD #1
    STD VAR_ROOM_EXIT
; VPy_LINE:686
; NATIVE_CALL: PLAY_SFX at line 686
    ; PLAY_SFX("door_unlock") - play SFX asset (index=0)
    LDX #0        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
; VPy_LINE:687
    JSR TRAMP_ACCELERATE_HEARTBEAT  ; cross-bank trampoline (bank #1 -> bank #0)
    LBRA IF_END_185
IF_NEXT_187:
; VPy_LINE:689
    LDD #3
    STD VAR_MSG_ID
; VPy_LINE:690
    LDD #120
    STD VAR_MSG_TIMER
; VPy_LINE:691
; NATIVE_CALL: PLAY_SFX at line 691
    ; PLAY_SFX("puzzle_fail") - play SFX asset (index=2)
    LDX #2        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
IF_END_185:
    LBRA IF_END_182
IF_NEXT_184:
    LDD >VAR_CURRENT_VERB
    CMPD #1
    LBNE IF_END_182
; VPy_LINE:693
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:694
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_182
IF_END_182:
    LBRA IF_END_173
IF_NEXT_181:
    LDD >VAR_ARG0
    CMPD #2
    LBNE IF_NEXT_188
; VPy_LINE:697
    LDD >VAR_CURRENT_VERB
    CMPD #0
    LBNE IF_NEXT_190
; VPy_LINE:698
    LDD #0  ; const NPC_CARETAKER
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_NPC_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #1
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:699
    LDD #24
    STD VAR_MSG_ID
; VPy_LINE:700
    LDD #160
    STD VAR_MSG_TIMER
    LBRA IF_END_189
IF_NEXT_190:
    LDD >VAR_CURRENT_VERB
    CMPD #2
    LBNE IF_NEXT_191
; VPy_LINE:702
    LDD #36
    STD VAR_MSG_ID
; VPy_LINE:703
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_189
IF_NEXT_191:
    LDD >VAR_CURRENT_VERB
    CMPD #3
    LBNE IF_NEXT_192
; VPy_LINE:705
    LDD >VAR_ACTIVE_ITEM
    CMPD #3
    LBNE IF_NEXT_194
; VPy_LINE:706
    LDD #8  ; const FL_CARETAKER_DONE
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_B
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    CMPD #0
    LBNE IF_NEXT_196
; VPy_LINE:707
    LDD #8  ; const FL_CARETAKER_DONE
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_B
    ORA TMPVAL          ; A OR TMPVAL+0
    ORB TMPVAL+1        ; B OR TMPVAL+1
    STD VAR_FLAGS_B
; VPy_LINE:708
    LDD #128  ; const FL_OPTICS_OPEN
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_A
    ORA TMPVAL          ; A OR TMPVAL+0
    ORB TMPVAL+1        ; B OR TMPVAL+1
    STD VAR_FLAGS_A
; VPy_LINE:709
    LDD #3  ; const ITEM_BLANKET
    STD VAR_ARG0
    JSR TRAMP_DROP_ITEM  ; cross-bank trampoline (bank #1 -> bank #0)
; VPy_LINE:710
    LDD #-1
    STD VAR_ACTIVE_ITEM
; VPy_LINE:711
    LDD #0  ; const NPC_CARETAKER
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_NPC_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #2
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:712
    LDD #26
    STD VAR_MSG_ID
; VPy_LINE:713
    LDD #200
    STD VAR_MSG_TIMER
; VPy_LINE:714
    JSR TRAMP_ACCELERATE_HEARTBEAT  ; cross-bank trampoline (bank #1 -> bank #0)
    LBRA IF_END_195
IF_NEXT_196:
; VPy_LINE:716
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:717
    LDD #100
    STD VAR_MSG_TIMER
IF_END_195:
    LBRA IF_END_193
IF_NEXT_194:
; VPy_LINE:719
    LDD #36
    STD VAR_MSG_ID
; VPy_LINE:720
    LDD #120
    STD VAR_MSG_TIMER
IF_END_193:
    LBRA IF_END_189
IF_NEXT_192:
    LDD >VAR_CURRENT_VERB
    CMPD #1
    LBNE IF_END_189
; VPy_LINE:722
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:723
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_189
IF_END_189:
    LBRA IF_END_173
IF_NEXT_188:
    LDD >VAR_ARG0
    CMPD #3
    LBNE IF_END_173
; VPy_LINE:726
    LDD >VAR_CURRENT_VERB
    CMPD #0
    LBNE IF_NEXT_198
; VPy_LINE:727
    LDD #43
    STD VAR_MSG_ID
; VPy_LINE:728
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_197
IF_NEXT_198:
    LDD >VAR_CURRENT_VERB
    CMPD #2
    LBNE IF_NEXT_199
; VPy_LINE:730
    LDD #5  ; const ROOM_CONSERVATORY
    STD VAR_EXIT_ROOM_TARGET
; VPy_LINE:731
    LDD #1
    STD VAR_ROOM_EXIT
; VPy_LINE:732
    LDD #60
    STD VAR_MSG_TIMER
    LBRA IF_END_197
IF_NEXT_199:
    LDD >VAR_CURRENT_VERB
    CMPD #1
    LBNE IF_END_197
; VPy_LINE:734
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:735
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_197
IF_END_197:
    LBRA IF_END_173
IF_END_173:
    RTS

; Function: INTERACT_WORKSHOP (Bank #1)
INTERACT_WORKSHOP:
; VPy_LINE:738
    LDD >VAR_ARG0
    CMPD #0
    LBNE IF_NEXT_201
; VPy_LINE:739
    LDD >VAR_CURRENT_VERB
    CMPD #0
    LBNE IF_NEXT_203
; VPy_LINE:740
    LDD #6
    STD VAR_MSG_ID
; VPy_LINE:741
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_202
IF_NEXT_203:
    LDD >VAR_CURRENT_VERB
    CMPD #2
    LBNE IF_NEXT_204
; VPy_LINE:743
    LDD #4  ; const FL_SARC_OPEN
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_A
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    CMPD #0
    LBEQ IF_NEXT_206
; VPy_LINE:744
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:745
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_205
IF_NEXT_206:
    LDD #8  ; const FL_CLOCK_READ
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_A
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    CMPD #0
    LBEQ IF_NEXT_207
; VPy_LINE:747
    LDD #4  ; const FL_SARC_OPEN
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_A
    ORA TMPVAL          ; A OR TMPVAL+0
    ORB TMPVAL+1        ; B OR TMPVAL+1
    STD VAR_FLAGS_A
; VPy_LINE:748
    LDD #3  ; const ITEM_BLANKET
    STD VAR_ARG0
    JSR TRAMP_PICKUP_ITEM  ; cross-bank trampoline (bank #1 -> bank #0)
; VPy_LINE:749
    LDD #7  ; const ITEM_KEY
    STD VAR_ARG0
    JSR TRAMP_PICKUP_ITEM  ; cross-bank trampoline (bank #1 -> bank #0)
; VPy_LINE:750
    LDD #7
    STD VAR_MSG_ID
; VPy_LINE:751
    LDD #200
    STD VAR_MSG_TIMER
; VPy_LINE:752
; NATIVE_CALL: PLAY_SFX at line 752
    ; PLAY_SFX("puzzle_success") - play SFX asset (index=3)
    LDX #3        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
; VPy_LINE:753
    JSR TRAMP_ACCELERATE_HEARTBEAT  ; cross-bank trampoline (bank #1 -> bank #0)
    LBRA IF_END_205
IF_NEXT_207:
; VPy_LINE:755
    LDD #23
    STD VAR_MSG_ID
; VPy_LINE:756
    LDD #120
    STD VAR_MSG_TIMER
IF_END_205:
    LBRA IF_END_202
IF_NEXT_204:
    LDD >VAR_CURRENT_VERB
    CMPD #1
    LBNE IF_END_202
; VPy_LINE:758
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:759
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_202
IF_END_202:
    LBRA IF_END_200
IF_NEXT_201:
    LDD >VAR_ARG0
    CMPD #1
    LBNE IF_NEXT_208
; VPy_LINE:762
    LDD >VAR_CURRENT_VERB
    CMPD #0
    LBNE IF_NEXT_210
; VPy_LINE:763
    LDD #8
    STD VAR_MSG_ID
; VPy_LINE:764
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_209
IF_NEXT_210:
    LDD >VAR_CURRENT_VERB
    CMPD #2
    LBNE IF_NEXT_211
; VPy_LINE:766
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #0  ; const ITEM_LENS
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #1
    LBNE IF_NEXT_213
; VPy_LINE:767
    LDD #8  ; const FL_CLOCK_READ
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_A
    ORA TMPVAL          ; A OR TMPVAL+0
    ORB TMPVAL+1        ; B OR TMPVAL+1
    STD VAR_FLAGS_A
; VPy_LINE:768
    LDD #8
    STD VAR_MSG_ID
; VPy_LINE:769
    LDD #160
    STD VAR_MSG_TIMER
    LBRA IF_END_212
IF_NEXT_213:
; VPy_LINE:771
    LDD #22
    STD VAR_MSG_ID
; VPy_LINE:772
    LDD #120
    STD VAR_MSG_TIMER
IF_END_212:
    LBRA IF_END_209
IF_NEXT_211:
    LDD >VAR_CURRENT_VERB
    CMPD #1
    LBNE IF_END_209
; VPy_LINE:774
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:775
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_209
IF_END_209:
    LBRA IF_END_200
IF_NEXT_208:
    LDD >VAR_ARG0
    CMPD #2
    LBNE IF_NEXT_214
; VPy_LINE:778
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #1  ; const ITEM_GEAR
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #0
    LBNE IF_NEXT_216
; VPy_LINE:779
    LDD #1  ; const ITEM_GEAR
    STD VAR_ARG0
    JSR TRAMP_PICKUP_ITEM  ; cross-bank trampoline (bank #1 -> bank #0)
; VPy_LINE:780
    LDD #25
    STD VAR_MSG_ID
; VPy_LINE:781
    LDD #140
    STD VAR_MSG_TIMER
    LBRA IF_END_215
IF_NEXT_216:
    LDD >VAR_CURRENT_VERB
    CMPD #2
    LBNE IF_NEXT_217
; VPy_LINE:783
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #1  ; const ITEM_GEAR
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #1
    LBNE IF_NEXT_219
; VPy_LINE:784
    LDD #16  ; const FL_PANEL_ACTIVE
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_A
    ORA TMPVAL          ; A OR TMPVAL+0
    ORB TMPVAL+1        ; B OR TMPVAL+1
    STD VAR_FLAGS_A
; VPy_LINE:785
    LDD #1  ; const ITEM_GEAR
    STD VAR_ARG0
    JSR TRAMP_DROP_ITEM  ; cross-bank trampoline (bank #1 -> bank #0)
; VPy_LINE:786
    LDD #44
    STD VAR_MSG_ID
; VPy_LINE:787
    LDD #160
    STD VAR_MSG_TIMER
; VPy_LINE:788
; NATIVE_CALL: PLAY_SFX at line 788
    ; PLAY_SFX("puzzle_success") - play SFX asset (index=3)
    LDX #3        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
; VPy_LINE:789
    JSR TRAMP_ACCELERATE_HEARTBEAT  ; cross-bank trampoline (bank #1 -> bank #0)
    LBRA IF_END_218
IF_NEXT_219:
; VPy_LINE:791
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:792
    LDD #100
    STD VAR_MSG_TIMER
IF_END_218:
    LBRA IF_END_215
IF_NEXT_217:
; VPy_LINE:794
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:795
    LDD #100
    STD VAR_MSG_TIMER
IF_END_215:
    LBRA IF_END_200
IF_NEXT_214:
    LDD >VAR_ARG0
    CMPD #3
    LBNE IF_NEXT_220
; VPy_LINE:798
    LDD >VAR_CURRENT_VERB
    CMPD #0
    LBNE IF_NEXT_222
; VPy_LINE:799
    LDD #1  ; const NPC_HANS
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_NPC_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #1
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:800
    LDD #27
    STD VAR_MSG_ID
; VPy_LINE:801
    LDD #160
    STD VAR_MSG_TIMER
    LBRA IF_END_221
IF_NEXT_222:
    LDD >VAR_CURRENT_VERB
    CMPD #2
    LBNE IF_NEXT_223
; VPy_LINE:803
    LDD #37
    STD VAR_MSG_ID
; VPy_LINE:804
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_221
IF_NEXT_223:
    LDD >VAR_CURRENT_VERB
    CMPD #3
    LBNE IF_NEXT_224
; VPy_LINE:806
    LDD >VAR_ACTIVE_ITEM
    CMPD #5
    LBNE IF_NEXT_226
; VPy_LINE:807
    LDD #4  ; const FL_HANS_HELPED
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_B
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    CMPD #0
    LBNE IF_NEXT_228
; VPy_LINE:808
    LDD #4  ; const FL_HANS_HELPED
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_B
    ORA TMPVAL          ; A OR TMPVAL+0
    ORB TMPVAL+1        ; B OR TMPVAL+1
    STD VAR_FLAGS_B
; VPy_LINE:809
    LDD #5  ; const ITEM_OIL
    STD VAR_ARG0
    JSR TRAMP_DROP_ITEM  ; cross-bank trampoline (bank #1 -> bank #0)
; VPy_LINE:810
    LDD #-1
    STD VAR_ACTIVE_ITEM
; VPy_LINE:811
    LDD #1  ; const NPC_HANS
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_NPC_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #2
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:812
    LDD #28
    STD VAR_MSG_ID
; VPy_LINE:813
    LDD #200
    STD VAR_MSG_TIMER
; VPy_LINE:814
    JSR TRAMP_ACCELERATE_HEARTBEAT  ; cross-bank trampoline (bank #1 -> bank #0)
    LBRA IF_END_227
IF_NEXT_228:
; VPy_LINE:816
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:817
    LDD #100
    STD VAR_MSG_TIMER
IF_END_227:
    LBRA IF_END_225
IF_NEXT_226:
; VPy_LINE:819
    LDD #37
    STD VAR_MSG_ID
; VPy_LINE:820
    LDD #120
    STD VAR_MSG_TIMER
IF_END_225:
    LBRA IF_END_221
IF_NEXT_224:
    LDD >VAR_CURRENT_VERB
    CMPD #1
    LBNE IF_END_221
; VPy_LINE:822
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:823
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_221
IF_END_221:
    LBRA IF_END_200
IF_NEXT_220:
    LDD >VAR_ARG0
    CMPD #4
    LBNE IF_NEXT_229
; VPy_LINE:826
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #5  ; const ITEM_OIL
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #0
    LBNE IF_NEXT_231
; VPy_LINE:827
    LDD #5  ; const ITEM_OIL
    STD VAR_ARG0
    JSR TRAMP_PICKUP_ITEM  ; cross-bank trampoline (bank #1 -> bank #0)
; VPy_LINE:828
    LDD #34
    STD VAR_MSG_ID
; VPy_LINE:829
    LDD #140
    STD VAR_MSG_TIMER
    LBRA IF_END_230
IF_NEXT_231:
; VPy_LINE:831
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:832
    LDD #100
    STD VAR_MSG_TIMER
IF_END_230:
    LBRA IF_END_200
IF_NEXT_229:
    LDD >VAR_ARG0
    CMPD #5
    LBNE IF_END_200
; VPy_LINE:835
    LDD >VAR_CURRENT_VERB
    CMPD #0
    LBNE IF_NEXT_233
; VPy_LINE:836
    LDD #40
    STD VAR_MSG_ID
; VPy_LINE:837
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_232
IF_NEXT_233:
    LDD >VAR_CURRENT_VERB
    CMPD #2
    LBNE IF_NEXT_234
; VPy_LINE:839
    LDD #128  ; const FL_OPTICS_OPEN
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_A
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    CMPD #0
    LBEQ IF_NEXT_236
; VPy_LINE:840
    LDD #4  ; const ROOM_OPTICS
    STD VAR_EXIT_ROOM_TARGET
; VPy_LINE:841
    LDD #1
    STD VAR_ROOM_EXIT
; VPy_LINE:842
    LDD #60
    STD VAR_MSG_TIMER
    LBRA IF_END_235
IF_NEXT_236:
; VPy_LINE:844
    LDD #40
    STD VAR_MSG_ID
; VPy_LINE:845
    LDD #120
    STD VAR_MSG_TIMER
IF_END_235:
    LBRA IF_END_232
IF_NEXT_234:
    LDD >VAR_CURRENT_VERB
    CMPD #1
    LBNE IF_END_232
; VPy_LINE:847
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:848
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_232
IF_END_232:
    LBRA IF_END_200
IF_END_200:
    RTS

; Function: INTERACT_ANTEROOM (Bank #1)
INTERACT_ANTEROOM:
; VPy_LINE:851
    LDD >VAR_ARG0
    CMPD #0
    LBNE IF_NEXT_238
; VPy_LINE:852
    LDD >VAR_CURRENT_VERB
    CMPD #0
    LBNE IF_NEXT_240
; VPy_LINE:853
    LDD #9
    STD VAR_MSG_ID
; VPy_LINE:854
    LDD #140
    STD VAR_MSG_TIMER
    LBRA IF_END_239
IF_NEXT_240:
    LDD >VAR_CURRENT_VERB
    CMPD #1
    LBNE IF_NEXT_241
; VPy_LINE:856
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:857
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_239
IF_NEXT_241:
    LDD >VAR_CURRENT_VERB
    CMPD #2
    LBNE IF_END_239
; VPy_LINE:859
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #0  ; const ITEM_LENS
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #0
    LBNE IF_NEXT_243
; VPy_LINE:860
    LDD #0  ; const ITEM_LENS
    STD VAR_ARG0
    JSR TRAMP_PICKUP_ITEM  ; cross-bank trampoline (bank #1 -> bank #0)
; VPy_LINE:861
    LDD #10
    STD VAR_MSG_ID
; VPy_LINE:862
    LDD #160
    STD VAR_MSG_TIMER
    LBRA IF_END_242
IF_NEXT_243:
; VPy_LINE:864
    LDD #11
    STD VAR_MSG_ID
; VPy_LINE:865
    LDD #100
    STD VAR_MSG_TIMER
IF_END_242:
    LBRA IF_END_239
IF_END_239:
    LBRA IF_END_237
IF_NEXT_238:
    LDD >VAR_ARG0
    CMPD #1
    LBNE IF_NEXT_244
; VPy_LINE:867
    LDD >VAR_CURRENT_VERB
    CMPD #0
    LBNE IF_NEXT_246
; VPy_LINE:868
    LDD #12
    STD VAR_MSG_ID
; VPy_LINE:869
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_245
IF_NEXT_246:
    LDD >VAR_CURRENT_VERB
    CMPD #2
    LBNE IF_NEXT_247
; VPy_LINE:871
    LDD #3  ; const ROOM_WEIGHTS
    STD VAR_EXIT_ROOM_TARGET
; VPy_LINE:872
    LDD #1
    STD VAR_ROOM_EXIT
; VPy_LINE:873
    LDD #60
    STD VAR_MSG_TIMER
    LBRA IF_END_245
IF_NEXT_247:
    LDD >VAR_CURRENT_VERB
    CMPD #1
    LBNE IF_END_245
; VPy_LINE:875
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:876
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_245
IF_END_245:
    LBRA IF_END_237
IF_NEXT_244:
    LDD >VAR_ARG0
    CMPD #2
    LBNE IF_NEXT_248
; VPy_LINE:878
    LDD >VAR_CURRENT_VERB
    CMPD #0
    LBNE IF_NEXT_250
; VPy_LINE:879
    LDD #33
    STD VAR_MSG_ID
; VPy_LINE:880
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_249
IF_NEXT_250:
    LDD >VAR_CURRENT_VERB
    CMPD #1
    LBNE IF_NEXT_251
; VPy_LINE:882
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #6  ; const ITEM_SHEET
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #0
    LBNE IF_NEXT_253
; VPy_LINE:883
    LDD #6  ; const ITEM_SHEET
    STD VAR_ARG0
    JSR TRAMP_PICKUP_ITEM  ; cross-bank trampoline (bank #1 -> bank #0)
; VPy_LINE:884
    LDD #33
    STD VAR_MSG_ID
; VPy_LINE:885
    LDD #140
    STD VAR_MSG_TIMER
    LBRA IF_END_252
IF_NEXT_253:
; VPy_LINE:887
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:888
    LDD #100
    STD VAR_MSG_TIMER
IF_END_252:
    LBRA IF_END_249
IF_NEXT_251:
    LDD >VAR_CURRENT_VERB
    CMPD #2
    LBNE IF_END_249
; VPy_LINE:890
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:891
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_249
IF_END_249:
    LBRA IF_END_237
IF_NEXT_248:
    LDD >VAR_ARG0
    CMPD #3
    LBNE IF_END_237
; VPy_LINE:893
    LDD >VAR_CURRENT_VERB
    CMPD #0
    LBNE IF_NEXT_255
; VPy_LINE:894
    LDD #35
    STD VAR_MSG_ID
; VPy_LINE:895
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_254
IF_NEXT_255:
    LDD >VAR_CURRENT_VERB
    CMPD #2
    LBNE IF_NEXT_256
; VPy_LINE:897
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
    LBEQ .CMP_124_TRUE
    LDD #0
    LBRA .CMP_124_END
.CMP_124_TRUE:
    LDD #1
.CMP_124_END:
    LBEQ .LOGIC_123_FALSE
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
    LBEQ .CMP_125_TRUE
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
    LBEQ IF_NEXT_258
; VPy_LINE:898
    LDD #2  ; const ITEM_PRISM
    STD VAR_ARG0
    JSR TRAMP_PICKUP_ITEM  ; cross-bank trampoline (bank #1 -> bank #0)
; VPy_LINE:899
    LDD #35
    STD VAR_MSG_ID
; VPy_LINE:900
    LDD #160
    STD VAR_MSG_TIMER
    LBRA IF_END_257
IF_NEXT_258:
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #2  ; const ITEM_PRISM
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #1
    LBNE IF_NEXT_259
; VPy_LINE:902
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:903
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_257
IF_NEXT_259:
; VPy_LINE:905
    LDD #22
    STD VAR_MSG_ID
; VPy_LINE:906
    LDD #120
    STD VAR_MSG_TIMER
IF_END_257:
    LBRA IF_END_254
IF_NEXT_256:
    LDD >VAR_CURRENT_VERB
    CMPD #1
    LBNE IF_END_254
; VPy_LINE:908
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:909
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_254
IF_END_254:
    LBRA IF_END_237
IF_END_237:
    RTS

; Function: INTERACT_WEIGHTS (Bank #1)
INTERACT_WEIGHTS:
; VPy_LINE:912
    LDD >VAR_ARG0
    CMPD #0
    LBNE IF_NEXT_261
; VPy_LINE:913
    LDD >VAR_CURRENT_VERB
    CMPD #0
    LBNE IF_NEXT_263
; VPy_LINE:914
    LDD #13
    STD VAR_MSG_ID
; VPy_LINE:915
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_262
IF_NEXT_263:
    LDD >VAR_CURRENT_VERB
    CMPD #2
    LBNE IF_NEXT_264
; VPy_LINE:917
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INV_WEIGHT
    CMPD TMPVAL
    LBGT .CMP_126_TRUE
    LDD #0
    LBRA .CMP_126_END
.CMP_126_TRUE:
    LDD #1
.CMP_126_END:
    LBEQ IF_NEXT_266
; VPy_LINE:918
    LDD #32  ; const FL_ITEMS_DEPOSITED
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_A
    ORA TMPVAL          ; A OR TMPVAL+0
    ORB TMPVAL+1        ; B OR TMPVAL+1
    STD VAR_FLAGS_A
; VPy_LINE:919
    LDD #0
    STD VAR_INV_WEIGHT
; VPy_LINE:920
    LDD #14
    STD VAR_MSG_ID
; VPy_LINE:921
    LDD #140
    STD VAR_MSG_TIMER
    LBRA IF_END_265
IF_NEXT_266:
; VPy_LINE:923
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:924
    LDD #100
    STD VAR_MSG_TIMER
IF_END_265:
    LBRA IF_END_262
IF_NEXT_264:
    LDD >VAR_CURRENT_VERB
    CMPD #1
    LBNE IF_END_262
; VPy_LINE:926
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:927
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_262
IF_END_262:
    LBRA IF_END_260
IF_NEXT_261:
    LDD >VAR_ARG0
    CMPD #1
    LBNE IF_END_260
; VPy_LINE:929
    LDD >VAR_CURRENT_VERB
    CMPD #0
    LBNE IF_NEXT_268
; VPy_LINE:930
    LDD #15
    STD VAR_MSG_ID
; VPy_LINE:931
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_267
IF_NEXT_268:
    LDD >VAR_CURRENT_VERB
    CMPD #2
    LBNE IF_NEXT_269
; VPy_LINE:933
    LDD #3
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INV_WEIGHT
    CMPD TMPVAL
    LBGT .CMP_127_TRUE
    LDD #0
    LBRA .CMP_127_END
.CMP_127_TRUE:
    LDD #1
.CMP_127_END:
    LBEQ IF_NEXT_271
; VPy_LINE:934
    LDD #16
    STD VAR_MSG_ID
; VPy_LINE:935
    LDD #140
    STD VAR_MSG_TIMER
; VPy_LINE:936
; NATIVE_CALL: PLAY_SFX at line 936
    ; PLAY_SFX("puzzle_fail") - play SFX asset (index=2)
    LDX #2        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
    LBRA IF_END_270
IF_NEXT_271:
; VPy_LINE:938
    LDD #1  ; const ROOM_WORKSHOP
    STD VAR_EXIT_ROOM_TARGET
; VPy_LINE:939
    LDD #1
    STD VAR_ROOM_EXIT
; VPy_LINE:940
    LDD #60
    STD VAR_MSG_TIMER
IF_END_270:
    LBRA IF_END_267
IF_NEXT_269:
    LDD >VAR_CURRENT_VERB
    CMPD #1
    LBNE IF_END_267
; VPy_LINE:942
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:943
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_267
IF_END_267:
    LBRA IF_END_260
IF_END_260:
    RTS

; Function: INTERACT_OPTICS (Bank #1)
INTERACT_OPTICS:
; VPy_LINE:946
    LDD >VAR_ARG0
    CMPD #0
    LBNE IF_NEXT_273
; VPy_LINE:947
    LDD >VAR_CURRENT_VERB
    CMPD #0
    LBNE IF_NEXT_275
; VPy_LINE:948
    LDD #17
    STD VAR_MSG_ID
; VPy_LINE:949
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_274
IF_NEXT_275:
    LDD >VAR_CURRENT_VERB
    CMPD #2
    LBNE IF_NEXT_276
; VPy_LINE:951
    LDD #64  ; const FL_OPTICS_SOLVED
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_A
    ANDA TMPVAL         ; A AND TMPVAL+0 (high byte)
    ANDB TMPVAL+1       ; B AND TMPVAL+1 (low byte)
    CMPD #0
    LBEQ IF_NEXT_278
; VPy_LINE:952
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:953
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_277
IF_NEXT_278:
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #2  ; const ITEM_PRISM
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #1
    LBNE IF_NEXT_279
; VPy_LINE:955
    LDD #64  ; const FL_OPTICS_SOLVED
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_A
    ORA TMPVAL          ; A OR TMPVAL+0
    ORB TMPVAL+1        ; B OR TMPVAL+1
    STD VAR_FLAGS_A
; VPy_LINE:956
    LDD #2  ; const ITEM_PRISM
    STD VAR_ARG0
    JSR TRAMP_DROP_ITEM  ; cross-bank trampoline (bank #1 -> bank #0)
; VPy_LINE:957
    LDD #19
    STD VAR_MSG_ID
; VPy_LINE:958
    LDD #200
    STD VAR_MSG_TIMER
; VPy_LINE:959
; NATIVE_CALL: PLAY_SFX at line 959
    ; PLAY_SFX("puzzle_success") - play SFX asset (index=3)
    LDX #3        ; SFX asset index for lookup
    JSR PLAY_SFX_BANKED  ; Play with automatic bank switching
    LDD #0
    STD RESULT
; VPy_LINE:960
    JSR TRAMP_ACCELERATE_HEARTBEAT  ; cross-bank trampoline (bank #1 -> bank #0)
    LBRA IF_END_277
IF_NEXT_279:
; VPy_LINE:962
    LDD #18
    STD VAR_MSG_ID
; VPy_LINE:963
    LDD #120
    STD VAR_MSG_TIMER
IF_END_277:
    LBRA IF_END_274
IF_NEXT_276:
    LDD >VAR_CURRENT_VERB
    CMPD #1
    LBNE IF_END_274
; VPy_LINE:965
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:966
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_274
IF_END_274:
    LBRA IF_END_272
IF_NEXT_273:
    LDD >VAR_ARG0
    CMPD #1
    LBNE IF_END_272
; VPy_LINE:968
    LDD >VAR_CURRENT_VERB
    CMPD #0
    LBNE IF_NEXT_281
; VPy_LINE:969
    LDD #20
    STD VAR_MSG_ID
; VPy_LINE:970
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_280
IF_NEXT_281:
    LDD >VAR_CURRENT_VERB
    CMPD #1
    LBNE IF_NEXT_282
; VPy_LINE:972
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #4  ; const ITEM_EYE
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #0
    LBNE IF_NEXT_284
; VPy_LINE:973
    LDD #4  ; const ITEM_EYE
    STD VAR_ARG0
    JSR TRAMP_PICKUP_ITEM  ; cross-bank trampoline (bank #1 -> bank #0)
; VPy_LINE:974
    LDD #21
    STD VAR_MSG_ID
; VPy_LINE:975
    LDD #140
    STD VAR_MSG_TIMER
    LBRA IF_END_283
IF_NEXT_284:
; VPy_LINE:977
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:978
    LDD #100
    STD VAR_MSG_TIMER
IF_END_283:
    LBRA IF_END_280
IF_NEXT_282:
    LDD >VAR_CURRENT_VERB
    CMPD #2
    LBNE IF_END_280
; VPy_LINE:980
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:981
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_280
IF_END_280:
    LBRA IF_END_272
IF_END_272:
    RTS

; Function: INTERACT_VAULT (Bank #1)
INTERACT_VAULT:
; VPy_LINE:1014
    LDD >VAR_ARG0
    CMPD #0
    LBNE IF_NEXT_296
; VPy_LINE:1015
    LDD >VAR_CURRENT_VERB
    CMPD #0
    LBNE IF_NEXT_298
; VPy_LINE:1016
    LDD #3  ; const NPC_APPRENTICE
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_NPC_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #1
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:1017
    LDD #31
    STD VAR_MSG_ID
; VPy_LINE:1018
    LDD #200
    STD VAR_MSG_TIMER
    LBRA IF_END_297
IF_NEXT_298:
    LDD >VAR_CURRENT_VERB
    CMPD #2
    LBNE IF_NEXT_299
; VPy_LINE:1020
    LDD #39
    STD VAR_MSG_ID
; VPy_LINE:1021
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_297
IF_NEXT_299:
    LDD >VAR_CURRENT_VERB
    CMPD #3
    LBNE IF_NEXT_300
; VPy_LINE:1023
    LDD >VAR_ACTIVE_ITEM
    CMPD #1
    LBNE IF_NEXT_302
; VPy_LINE:1024
    LDD #3  ; const NPC_APPRENTICE
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_NPC_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    PSHS X          ; Save computed address (stack-safe across function calls)
    LDD #2
    PULS X          ; Restore computed address
    STD ,X          ; Store 16-bit value
; VPy_LINE:1025
    LDD #-1
    STD VAR_ACTIVE_ITEM
; VPy_LINE:1026
    LDD #32
    STD VAR_MSG_ID
; VPy_LINE:1027
    LDD #200
    STD VAR_MSG_TIMER
    LBRA IF_END_301
IF_NEXT_302:
; VPy_LINE:1029
    LDD #39
    STD VAR_MSG_ID
; VPy_LINE:1030
    LDD #120
    STD VAR_MSG_TIMER
IF_END_301:
    LBRA IF_END_297
IF_NEXT_300:
    LDD >VAR_CURRENT_VERB
    CMPD #1
    LBNE IF_END_297
; VPy_LINE:1032
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:1033
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_297
IF_END_297:
    LBRA IF_END_295
IF_NEXT_296:
    LDD >VAR_ARG0
    CMPD #1
    LBNE IF_END_295
; VPy_LINE:1035
    LDD >VAR_CURRENT_VERB
    CMPD #0
    LBNE IF_NEXT_304
; VPy_LINE:1036
    LDD #42
    STD VAR_MSG_ID
; VPy_LINE:1037
    LDD #120
    STD VAR_MSG_TIMER
    LBRA IF_END_303
IF_NEXT_304:
    LDD >VAR_CURRENT_VERB
    CMPD #2
    LBNE IF_NEXT_305
; VPy_LINE:1039
    LDX #VAR_INV_ITEMS_DATA  ; Array base
    LDD #7  ; const ITEM_KEY
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    CMPD #1
    LBNE IF_NEXT_307
; VPy_LINE:1040
    LDD #7  ; const ITEM_KEY
    STD VAR_ARG0
    JSR TRAMP_DROP_ITEM  ; cross-bank trampoline (bank #1 -> bank #0)
; VPy_LINE:1041
    LDD #-1
    STD VAR_ACTIVE_ITEM
; VPy_LINE:1042
    LDD #1
    STD VAR_ROOM_EXIT
; VPy_LINE:1043
    LDD #16  ; const FL_EXIT_TESTAMENT
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_FLAGS_B
    ORA TMPVAL          ; A OR TMPVAL+0
    ORB TMPVAL+1        ; B OR TMPVAL+1
    STD VAR_FLAGS_B
; VPy_LINE:1044
    LDD #80
    STD VAR_MSG_TIMER
    LBRA IF_END_306
IF_NEXT_307:
; VPy_LINE:1046
    LDD #42
    STD VAR_MSG_ID
; VPy_LINE:1047
    LDD #120
    STD VAR_MSG_TIMER
IF_END_306:
    LBRA IF_END_303
IF_NEXT_305:
    LDD >VAR_CURRENT_VERB
    CMPD #1
    LBNE IF_END_303
; VPy_LINE:1049
    LDD #5
    STD VAR_MSG_ID
; VPy_LINE:1050
    LDD #100
    STD VAR_MSG_TIMER
    LBRA IF_END_303
IF_END_303:
    LBRA IF_END_295
IF_END_295:
    RTS

;***************************************************************************
; ASSETS IN BANK #1 (24 assets)
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
    FCB     24              ; Delay 24 frames before loop
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
    FCB     16              ; Delay 16 frames before loop
    FCB     $FF             ; Loop command ($FF never valid as count)
    FDB     _INTRO_MUSIC       ; Jump to start (absolute address)


; Generated from door_locked.vec (Malban Draw_Sync_List format)
; Total paths: 13, points: 59
; X bounds: min=-11, max=11, width=22
; Center: (0, 0)

_DOOR_LOCKED_WIDTH EQU 22
_DOOR_LOCKED_HALF_WIDTH EQU 11
_DOOR_LOCKED_HEIGHT EQU 53
_DOOR_LOCKED_HALF_HEIGHT EQU 26
_DOOR_LOCKED_CENTER_X EQU 0
_DOOR_LOCKED_CENTER_Y EQU 0

_DOOR_LOCKED_VECTORS:  ; Main entry (header + 13 path(s))
    FDB 13               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
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
    FCB 100              ; path0: intensity
    FCB $FB,$00,0,0        ; path0: header (y=-5, x=0)
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH1:    ; Path 1
    FCB 100              ; path1: intensity
    FCB $FB,$03,0,0        ; path1: header (y=-5, x=3)
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH2:    ; Path 2
    FCB 100              ; path2: intensity
    FCB $F9,$FE,0,0        ; path2: header (y=-7, x=-2)
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $F9,$FB,0,0        ; path3: header (y=-7, x=-5)
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH4:    ; Path 4
    FCB 120              ; path4: intensity
    FCB $FB,$F9,0,0        ; path4: header (y=-5, x=-7)
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH5:    ; Path 5
    FCB 90              ; path5: intensity
    FCB $03,$F8,0,0        ; path5: header (y=3, x=-8)
    FCB $FF,$0D,$00          ; flag=-1, dy=13, dx=0
    FCB $FF,$00,$10          ; flag=-1, dy=0, dx=16
    FCB $FF,$F3,$00          ; flag=-1, dy=-13, dx=0
    FCB $FF,$00,$F0          ; flag=-1, dy=0, dx=-16
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH6:    ; Path 6
    FCB 80              ; path6: intensity
    FCB $0A,$08,0,0        ; path6: header (y=10, x=8)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH7:    ; Path 7
    FCB 70              ; path7: intensity
    FCB $1A,$00,0,0        ; path7: header (y=26, x=0)
    FCB $FF,$CB,$00          ; flag=-1, dy=-53, dx=0
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH8:    ; Path 8
    FCB 90              ; path8: intensity
    FCB $E8,$F8,0,0        ; path8: header (y=-24, x=-8)
    FCB $FF,$14,$00          ; flag=-1, dy=20, dx=0
    FCB $FF,$00,$10          ; flag=-1, dy=0, dx=16
    FCB $FF,$EC,$00          ; flag=-1, dy=-20, dx=0
    FCB $FF,$00,$F0          ; flag=-1, dy=0, dx=-16
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH9:    ; Path 9
    FCB 110              ; path9: intensity
    FCB $E5,$F5,0,0        ; path9: header (y=-27, x=-11)
    FCB $FF,$2D,$00          ; flag=-1, dy=45, dx=0
    FCB $FF,$08,$06          ; flag=-1, dy=8, dx=6
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$F8,$06          ; flag=-1, dy=-8, dx=6
    FCB $FF,$D3,$00          ; flag=-1, dy=-45, dx=0
    FCB $FF,$00,$EA          ; flag=-1, dy=0, dx=-22
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH10:    ; Path 10
    FCB 110              ; path10: intensity
    FCB $F0,$00,0,0        ; path10: header (y=-16, x=0)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$FE,$00          ; flag=-1, dy=-2, dx=0
    FCB $FF,$00,$FE          ; flag=-1, dy=0, dx=-2
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH11:    ; Path 11
    FCB 110              ; path11: intensity
    FCB $F0,$00,0,0        ; path11: header (y=-16, x=0)
    FCB $FF,$FF,$01          ; flag=-1, dy=-1, dx=1
    FCB $FF,$FF,$FF          ; flag=-1, dy=-1, dx=-1
    FCB $FF,$01,$FF          ; flag=-1, dy=1, dx=-1
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB 2                ; End marker (path complete)

_DOOR_LOCKED_PATH12:    ; Path 12
    FCB 80              ; path12: intensity
    FCB $EF,$08,0,0        ; path12: header (y=-17, x=8)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB 2                ; End marker (path complete)

; Generated from painting.vec (Malban Draw_Sync_List format)
; Total paths: 10, points: 42
; X bounds: min=-16, max=16, width=32
; Center: (0, 0)

_PAINTING_WIDTH EQU 32
_PAINTING_HALF_WIDTH EQU 16
_PAINTING_HEIGHT EQU 36
_PAINTING_HALF_HEIGHT EQU 18
_PAINTING_CENTER_X EQU 0
_PAINTING_CENTER_Y EQU 0

_PAINTING_VECTORS:  ; Main entry (header + 10 path(s))
    FDB 10               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
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
    FCB 80              ; path0: intensity
    FCB $03,$FE,0,0        ; path0: header (y=3, x=-2)
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB 2                ; End marker (path complete)

_PAINTING_PATH1:    ; Path 1
    FCB 80              ; path1: intensity
    FCB $03,$02,0,0        ; path1: header (y=3, x=2)
    FCB $FF,$00,$01          ; flag=-1, dy=0, dx=1
    FCB 2                ; End marker (path complete)

_PAINTING_PATH2:    ; Path 2
    FCB 70              ; path2: intensity
    FCB $FE,$04,0,0        ; path2: header (y=-2, x=4)
    FCB $FF,$FE,$FC          ; flag=-1, dy=-2, dx=-4
    FCB $FF,$02,$FC          ; flag=-1, dy=2, dx=-4
    FCB 2                ; End marker (path complete)

_PAINTING_PATH3:    ; Path 3
    FCB 70              ; path3: intensity
    FCB $0A,$FA,0,0        ; path3: header (y=10, x=-6)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB $FF,$FA,$02          ; flag=-1, dy=-6, dx=2
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$FA,$FE          ; flag=-1, dy=-6, dx=-2
    FCB $FF,$00,$F4          ; flag=-1, dy=0, dx=-12
    FCB $FF,$06,$FE          ; flag=-1, dy=6, dx=-2
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$06,$02          ; flag=-1, dy=6, dx=2
    FCB 2                ; End marker (path complete)

_PAINTING_PATH4:    ; Path 4
    FCB 90              ; path4: intensity
    FCB $0D,$F5,0,0        ; path4: header (y=13, x=-11)
    FCB $FF,$00,$16          ; flag=-1, dy=0, dx=22
    FCB $FF,$E6,$00          ; flag=-1, dy=-26, dx=0
    FCB $FF,$00,$EA          ; flag=-1, dy=0, dx=-22
    FCB $FF,$1A,$00          ; flag=-1, dy=26, dx=0
    FCB 2                ; End marker (path complete)

_PAINTING_PATH5:    ; Path 5
    FCB 110              ; path5: intensity
    FCB $10,$F2,0,0        ; path5: header (y=16, x=-14)
    FCB $FF,$00,$1C          ; flag=-1, dy=0, dx=28
    FCB $FF,$E0,$00          ; flag=-1, dy=-32, dx=0
    FCB $FF,$00,$E4          ; flag=-1, dy=0, dx=-28
    FCB $FF,$20,$00          ; flag=-1, dy=32, dx=0
    FCB 2                ; End marker (path complete)

_PAINTING_PATH6:    ; Path 6
    FCB 100              ; path6: intensity
    FCB $10,$F2,0,0        ; path6: header (y=16, x=-14)
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB 2                ; End marker (path complete)

_PAINTING_PATH7:    ; Path 7
    FCB 100              ; path7: intensity
    FCB $10,$0E,0,0        ; path7: header (y=16, x=14)
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB 2                ; End marker (path complete)

_PAINTING_PATH8:    ; Path 8
    FCB 100              ; path8: intensity
    FCB $F0,$0E,0,0        ; path8: header (y=-16, x=14)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB 2                ; End marker (path complete)

_PAINTING_PATH9:    ; Path 9
    FCB 100              ; path9: intensity
    FCB $F0,$F2,0,0        ; path9: header (y=-16, x=-14)
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
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
    FDB -96  ; scrollLimit left (camera left cannot go below this)
    FDB 95  ; scrollLimit right (camera right cannot exceed this)
    FDB 127  ; scrollLimit top
    FDB -128  ; scrollLimit bottom
    FCB 0  ; enemy_count
    FDB 0  ; enemy_instances_ptr (0 if none)
    FDB 0  ; groundBottomOffset (floor surface offset from screen bottom)
    FCB 1    ; +34 screen_count
    FDB _CONSERVATORY_BG_SCREENS  ; +35 BG screens index
    FDB _CONSERVATORY_GP_SCREENS  ; +37 GP screens index
    FDB _CONSERVATORY_FG_SCREENS  ; +39 FG screens index

_CONSERVATORY_BG_OBJECTS:
_CONSERVATORY_BG_OBJECTS_S0:

_CONSERVATORY_GAMEPLAY_OBJECTS:
_CONSERVATORY_GAMEPLAY_OBJECTS_S0:
; Object: obj_con_arch_left (enemy)
    FCB 1  ; type
    FDB -90  ; x
    FDB -83  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 1   ; vector_bank (ROM+16)
    FDB _ENTRANCE_ARC_VECTORS  ; vector_ptr (ROM+17)
    FCB 60  ; half_width (1.00x, ROM+19)
    FCB 94  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_con_arch_right (enemy)
    FCB 1  ; type
    FDB 85  ; x
    FDB -83  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 1   ; vector_bank (ROM+16)
    FDB _ENTRANCE_ARC_VECTORS  ; vector_ptr (ROM+17)
    FCB 60  ; half_width (1.00x, ROM+19)
    FCB 94  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_con_lamp_left (enemy)
    FCB 1  ; type
    FDB -55  ; x
    FDB -5  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 1   ; vector_bank (ROM+16)
    FDB _LAMP_VECTORS  ; vector_ptr (ROM+17)
    FCB 22  ; half_width (1.00x, ROM+19)
    FCB 6  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_con_lamp_right (enemy)
    FCB 1  ; type
    FDB 55  ; x
    FDB -5  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 1   ; vector_bank (ROM+16)
    FDB _LAMP_VECTORS  ; vector_ptr (ROM+17)
    FCB 22  ; half_width (1.00x, ROM+19)
    FCB 6  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_con_harpsichord (enemy)
    FCB 1  ; type
    FDB 0  ; x
    FDB -90  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 1   ; vector_bank (ROM+16)
    FDB _DESK_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 23  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_con_portrait (enemy)
    FCB 1  ; type
    FDB -15  ; x
    FDB 25  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 1   ; vector_bank (ROM+16)
    FDB _PAINTING_VECTORS  ; vector_ptr (ROM+17)
    FCB 16  ; half_width (1.00x, ROM+19)
    FCB 18  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_con_floor (enemy)
    FCB 1  ; type
    FDB 0  ; x
    FDB -115  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 2   ; vector_bank (ROM+16)
    FDB _FLOOR_VECTORS  ; vector_ptr (ROM+17)
    FCB 120  ; half_width (1.00x, ROM+19)
    FCB 1  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)


_CONSERVATORY_FG_OBJECTS:
_CONSERVATORY_FG_OBJECTS_S0:

_CONSERVATORY_BG_SCREENS:
    FCB 0  ; screen 0 count
    FDB _CONSERVATORY_BG_OBJECTS_S0  ; screen 0 ptr

_CONSERVATORY_GP_SCREENS:
    FCB 7  ; screen 0 count
    FDB _CONSERVATORY_GAMEPLAY_OBJECTS_S0  ; screen 0 ptr

_CONSERVATORY_FG_SCREENS:
    FCB 0  ; screen 0 count
    FDB _CONSERVATORY_FG_OBJECTS_S0  ; screen 0 ptr

_CONSERVATORY_ENEMY_COUNT EQU 0


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
    FDB -128  ; scrollLimit left (camera left cannot go below this)
    FDB 127  ; scrollLimit right (camera right cannot exceed this)
    FDB 127  ; scrollLimit top
    FDB -128  ; scrollLimit bottom
    FCB 0  ; enemy_count
    FDB 0  ; enemy_instances_ptr (0 if none)
    FDB 0  ; groundBottomOffset (floor surface offset from screen bottom)
    FCB 1    ; +34 screen_count
    FDB _VAULT_CORRIDOR_BG_SCREENS  ; +35 BG screens index
    FDB _VAULT_CORRIDOR_GP_SCREENS  ; +37 GP screens index
    FDB _VAULT_CORRIDOR_FG_SCREENS  ; +39 FG screens index

_VAULT_CORRIDOR_BG_OBJECTS:
_VAULT_CORRIDOR_BG_OBJECTS_S0:

_VAULT_CORRIDOR_GAMEPLAY_OBJECTS:
_VAULT_CORRIDOR_GAMEPLAY_OBJECTS_S0:
; Object: obj_vc_lamp_left (enemy)
    FCB 1  ; type
    FDB -90  ; x
    FDB -5  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 1   ; vector_bank (ROM+16)
    FDB _LAMP_VECTORS  ; vector_ptr (ROM+17)
    FCB 22  ; half_width (1.00x, ROM+19)
    FCB 6  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_vc_lamp_right (enemy)
    FCB 1  ; type
    FDB 90  ; x
    FDB -5  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 1   ; vector_bank (ROM+16)
    FDB _LAMP_VECTORS  ; vector_ptr (ROM+17)
    FCB 22  ; half_width (1.00x, ROM+19)
    FCB 6  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_vc_wall_panel_left (enemy)
    FCB 1  ; type
    FDB -65  ; x
    FDB -45  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 2   ; vector_bank (ROM+16)
    FDB _WALL_COMPARTMENT_VECTORS  ; vector_ptr (ROM+17)
    FCB 20  ; half_width (1.00x, ROM+19)
    FCB 21  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_vc_wall_panel_right (enemy)
    FCB 1  ; type
    FDB 40  ; x
    FDB -45  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 2   ; vector_bank (ROM+16)
    FDB _WALL_COMPARTMENT_VECTORS  ; vector_ptr (ROM+17)
    FCB 20  ; half_width (1.00x, ROM+19)
    FCB 21  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_vc_pedestal_npc (enemy)
    FCB 1  ; type
    FDB -30  ; x
    FDB -95  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 2   ; vector_bank (ROM+16)
    FDB _OPTICS_PEDESTAL_VECTORS  ; vector_ptr (ROM+17)
    FCB 16  ; half_width (1.00x, ROM+19)
    FCB 34  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_vc_vault_door (enemy)
    FCB 1  ; type
    FDB 70  ; x
    FDB -90  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 2   ; vector_bank (ROM+16)
    FDB _LOCKED_DOOR_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 55  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_vc_floor (enemy)
    FCB 1  ; type
    FDB 0  ; x
    FDB -115  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 2   ; vector_bank (ROM+16)
    FDB _FLOOR_VECTORS  ; vector_ptr (ROM+17)
    FCB 120  ; half_width (1.00x, ROM+19)
    FCB 1  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)


_VAULT_CORRIDOR_FG_OBJECTS:
_VAULT_CORRIDOR_FG_OBJECTS_S0:

_VAULT_CORRIDOR_BG_SCREENS:
    FCB 0  ; screen 0 count
    FDB _VAULT_CORRIDOR_BG_OBJECTS_S0  ; screen 0 ptr

_VAULT_CORRIDOR_GP_SCREENS:
    FCB 7  ; screen 0 count
    FDB _VAULT_CORRIDOR_GAMEPLAY_OBJECTS_S0  ; screen 0 ptr

_VAULT_CORRIDOR_FG_SCREENS:
    FCB 0  ; screen 0 count
    FDB _VAULT_CORRIDOR_FG_OBJECTS_S0  ; screen 0 ptr

_VAULT_CORRIDOR_ENEMY_COUNT EQU 0


; Generated from vault_corridor.vec (Malban Draw_Sync_List format)
; Total paths: 12, points: 35
; X bounds: min=-90, max=90, width=180
; Center: (0, 10)

_VAULT_CORRIDOR_WIDTH EQU 180
_VAULT_CORRIDOR_HALF_WIDTH EQU 90
_VAULT_CORRIDOR_HEIGHT EQU 150
_VAULT_CORRIDOR_HALF_HEIGHT EQU 75
_VAULT_CORRIDOR_CENTER_X EQU 0
_VAULT_CORRIDOR_CENTER_Y EQU 10

_VAULT_CORRIDOR_VECTORS:  ; Main entry (header + 12 path(s))
    FDB 12               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
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
    FCB 110              ; path0: intensity
    FCB $F6,$42,0,0        ; path0: header (y=-10, x=66)
    FCB $FF,$F8,$FC          ; flag=-1, dy=-8, dx=-4
    FCB $FF,$F8,$04          ; flag=-1, dy=-8, dx=4
    FCB $FF,$FC,$08          ; flag=-1, dy=-4, dx=8
    FCB $FF,$04,$08          ; flag=-1, dy=4, dx=8
    FCB $FF,$08,$04          ; flag=-1, dy=8, dx=4
    FCB $FF,$08,$FC          ; flag=-1, dy=8, dx=-4
    FCB $FF,$04,$F8          ; flag=-1, dy=4, dx=-8
    FCB $FF,$FC,$F8          ; flag=-1, dy=-4, dx=-8
    FCB 2                ; End marker (path complete)

_VAULT_CORRIDOR_PATH1:    ; Path 1
    FCB 60              ; path1: intensity
    FCB $EE,$4E,0,0        ; path1: header (y=-18, x=78)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_VAULT_CORRIDOR_PATH2:    ; Path 2
    FCB 60              ; path2: intensity
    FCB $D2,$5A,0,0        ; path2: header (y=-46, x=90)
    FCB $FF,$00,$F4          ; flag=-1, dy=0, dx=-12
    FCB 2                ; End marker (path complete)

_VAULT_CORRIDOR_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $B5,$5A,0,0        ; path3: header (y=-75, x=90)
    FCB $FF,$4B,$00          ; sub-seg 1/2 of line 0: dy=75, dx=0
    FCB $FF,$4B,$00          ; sub-seg 2/2 of line 0: dy=75, dx=0
    FCB 2                ; End marker (path complete)

_VAULT_CORRIDOR_PATH4:    ; Path 4
    FCB 80              ; path4: intensity
    FCB $4B,$5A,0,0        ; path4: header (y=75, x=90)
    FCB $FF,$00,$A6          ; sub-seg 1/2 of line 0: dy=0, dx=-90
    FCB $FF,$00,$A6          ; sub-seg 2/2 of line 0: dy=0, dx=-90
    FCB 2                ; End marker (path complete)

_VAULT_CORRIDOR_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $4B,$A6,0,0        ; path5: header (y=75, x=-90)
    FCB $FF,$B5,$00          ; sub-seg 1/2 of line 0: dy=-75, dx=0
    FCB $FF,$B5,$00          ; sub-seg 2/2 of line 0: dy=-75, dx=0
    FCB 2                ; End marker (path complete)

_VAULT_CORRIDOR_PATH6:    ; Path 6
    FCB 100              ; path6: intensity
    FCB $B5,$A6,0,0        ; path6: header (y=-75, x=-90)
    FCB $FF,$00,$5A          ; sub-seg 1/2 of line 0: dy=0, dx=90
    FCB $FF,$00,$5A          ; sub-seg 2/2 of line 0: dy=0, dx=90
    FCB 2                ; End marker (path complete)

_VAULT_CORRIDOR_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $B5,$5A,0,0        ; path7: header (y=-75, x=90)
    FCB $FF,$2F,$00          ; flag=-1, dy=47, dx=0
    FCB $FF,$15,$FC          ; flag=-1, dy=21, dx=-4
    FCB $FF,$11,$F4          ; flag=-1, dy=17, dx=-12
    FCB $FF,$EF,$F4          ; flag=-1, dy=-17, dx=-12
    FCB $FF,$EB,$FC          ; flag=-1, dy=-21, dx=-4
    FCB $FF,$D1,$00          ; flag=-1, dy=-47, dx=0
    FCB 2                ; End marker (path complete)

_VAULT_CORRIDOR_PATH8:    ; Path 8
    FCB 60              ; path8: intensity
    FCB $0C,$4E,0,0        ; path8: header (y=12, x=78)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_VAULT_CORRIDOR_PATH9:    ; Path 9
    FCB 60              ; path9: intensity
    FCB $0C,$B2,0,0        ; path9: header (y=12, x=-78)
    FCB $FF,$00,$F4          ; flag=-1, dy=0, dx=-12
    FCB 2                ; End marker (path complete)

_VAULT_CORRIDOR_PATH10:    ; Path 10
    FCB 60              ; path10: intensity
    FCB $EE,$A6,0,0        ; path10: header (y=-18, x=-90)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_VAULT_CORRIDOR_PATH11:    ; Path 11
    FCB 60              ; path11: intensity
    FCB $D2,$B2,0,0        ; path11: header (y=-46, x=-78)
    FCB $FF,$00,$F4          ; flag=-1, dy=0, dx=-12
    FCB 2                ; End marker (path complete)

; Generated from conservatory.vec (Malban Draw_Sync_List format)
; Total paths: 10, points: 33
; X bounds: min=-120, max=120, width=240
; Center: (0, -2)

_CONSERVATORY_WIDTH EQU 240
_CONSERVATORY_HALF_WIDTH EQU 120
_CONSERVATORY_HEIGHT EQU 115
_CONSERVATORY_HALF_HEIGHT EQU 57
_CONSERVATORY_CENTER_X EQU 0
_CONSERVATORY_CENTER_Y EQU -2

_CONSERVATORY_VECTORS:  ; Main entry (header + 10 path(s))
    FDB 10               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
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
    FCB 90              ; path0: intensity
    FCB $DF,$18,0,0        ; path0: header (y=-33, x=24)
    FCB $FF,$11,$F0          ; flag=-1, dy=17, dx=-16
    FCB $FF,$FE,$E0          ; flag=-1, dy=-2, dx=-32
    FCB $FF,$F1,$F8          ; flag=-1, dy=-15, dx=-8
    FCB 2                ; End marker (path complete)

_CONSERVATORY_PATH1:    ; Path 1
    FCB 110              ; path1: intensity
    FCB $DF,$E0,0,0        ; path1: header (y=-33, x=-32)
    FCB $FF,$00,$38          ; flag=-1, dy=0, dx=56
    FCB $FF,$F7,$0E          ; flag=-1, dy=-9, dx=14
    FCB $FF,$F5,$FA          ; flag=-1, dy=-11, dx=-6
    FCB $FF,$00,$C0          ; flag=-1, dy=0, dx=-64
    FCB $FF,$14,$00          ; flag=-1, dy=20, dx=0
    FCB 2                ; End marker (path complete)

_CONSERVATORY_PATH2:    ; Path 2
    FCB 90              ; path2: intensity
    FCB $CB,$E4,0,0        ; path2: header (y=-53, x=-28)
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

_CONSERVATORY_PATH3:    ; Path 3
    FCB 64              ; path3: intensity
    FCB $D4,$E4,0,0        ; path3: header (y=-44, x=-28)
    FCB $FF,$00,$38          ; flag=-1, dy=0, dx=56
    FCB 2                ; End marker (path complete)

_CONSERVATORY_PATH4:    ; Path 4
    FCB 90              ; path4: intensity
    FCB $CB,$1C,0,0        ; path4: header (y=-53, x=28)
    FCB $FF,$FB,$03          ; flag=-1, dy=-5, dx=3
    FCB 2                ; End marker (path complete)

_CONSERVATORY_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $C6,$32,0,0        ; path5: header (y=-58, x=50)
    FCB $FF,$4B,$00          ; flag=-1, dy=75, dx=0
    FCB $FF,$28,$14          ; flag=-1, dy=40, dx=20
    FCB $FF,$D8,$14          ; flag=-1, dy=-40, dx=20
    FCB $FF,$B5,$00          ; flag=-1, dy=-75, dx=0
    FCB 2                ; End marker (path complete)

_CONSERVATORY_PATH6:    ; Path 6
    FCB 100              ; path6: intensity
    FCB $C6,$78,0,0        ; path6: header (y=-58, x=120)
    FCB $FF,$00,$88          ; sub-seg 1/2 of line 0: dy=0, dx=-120
    FCB $FF,$00,$88          ; sub-seg 2/2 of line 0: dy=0, dx=-120
    FCB 2                ; End marker (path complete)

_CONSERVATORY_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $C6,$A6,0,0        ; path7: header (y=-58, x=-90)
    FCB $FF,$4B,$00          ; flag=-1, dy=75, dx=0
    FCB $FF,$28,$14          ; flag=-1, dy=40, dx=20
    FCB $FF,$D8,$14          ; flag=-1, dy=-40, dx=20
    FCB $FF,$B5,$00          ; flag=-1, dy=-75, dx=0
    FCB 2                ; End marker (path complete)

_CONSERVATORY_PATH8:    ; Path 8
    FCB 80              ; path8: intensity
    FCB $11,$C8,0,0        ; path8: header (y=17, x=-56)
    FCB $FF,$1F,$F2          ; flag=-1, dy=31, dx=-14
    FCB $FF,$E1,$F2          ; flag=-1, dy=-31, dx=-14
    FCB 2                ; End marker (path complete)

_CONSERVATORY_PATH9:    ; Path 9
    FCB 80              ; path9: intensity
    FCB $11,$38,0,0        ; path9: header (y=17, x=56)
    FCB $FF,$1F,$0E          ; flag=-1, dy=31, dx=14
    FCB $FF,$E1,$0E          ; flag=-1, dy=-31, dx=14
    FCB 2                ; End marker (path complete)

; Generated from crystal_apprentice.vec (Malban Draw_Sync_List format)
; Total paths: 7, points: 28
; X bounds: min=-14, max=14, width=28
; Center: (0, -1)

_CRYSTAL_APPRENTICE_WIDTH EQU 28
_CRYSTAL_APPRENTICE_HALF_WIDTH EQU 14
_CRYSTAL_APPRENTICE_HEIGHT EQU 34
_CRYSTAL_APPRENTICE_HALF_HEIGHT EQU 17
_CRYSTAL_APPRENTICE_CENTER_X EQU 0
_CRYSTAL_APPRENTICE_CENTER_Y EQU -1

_CRYSTAL_APPRENTICE_VECTORS:  ; Main entry (header + 7 path(s))
    FDB 7               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _CRYSTAL_APPRENTICE_PATH0        ; pointer to path 0
    FDB _CRYSTAL_APPRENTICE_PATH1        ; pointer to path 1
    FDB _CRYSTAL_APPRENTICE_PATH2        ; pointer to path 2
    FDB _CRYSTAL_APPRENTICE_PATH3        ; pointer to path 3
    FDB _CRYSTAL_APPRENTICE_PATH4        ; pointer to path 4
    FDB _CRYSTAL_APPRENTICE_PATH5        ; pointer to path 5
    FDB _CRYSTAL_APPRENTICE_PATH6        ; pointer to path 6

_CRYSTAL_APPRENTICE_PATH0:    ; Path 0
    FCB 90              ; path0: intensity
    FCB $05,$FD,0,0        ; path0: header (y=5, x=-3)
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB 2                ; End marker (path complete)

_CRYSTAL_APPRENTICE_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $0B,$04,0,0        ; path1: header (y=11, x=4)
    FCB $FF,$01,$02          ; flag=-1, dy=1, dx=2
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_CRYSTAL_APPRENTICE_PATH2:    ; Path 2
    FCB 110              ; path2: intensity
    FCB $11,$00,0,0        ; path2: header (y=17, x=0)
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB $FF,$FC,$01          ; flag=-1, dy=-4, dx=1
    FCB $FF,$FC,$FF          ; flag=-1, dy=-4, dx=-1
    FCB $FF,$FE,$FB          ; flag=-1, dy=-2, dx=-5
    FCB $FF,$02,$FB          ; flag=-1, dy=2, dx=-5
    FCB $FF,$04,$FF          ; flag=-1, dy=4, dx=-1
    FCB $FF,$04,$01          ; flag=-1, dy=4, dx=1
    FCB $FF,$02,$05          ; flag=-1, dy=2, dx=5
    FCB 2                ; End marker (path complete)

_CRYSTAL_APPRENTICE_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $0C,$FA,0,0        ; path3: header (y=12, x=-6)
    FCB $FF,$01,$02          ; flag=-1, dy=1, dx=2
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB 2                ; End marker (path complete)

_CRYSTAL_APPRENTICE_PATH4:    ; Path 4
    FCB 110              ; path4: intensity
    FCB $05,$F7,0,0        ; path4: header (y=5, x=-9)
    FCB $FF,$00,$12          ; flag=-1, dy=0, dx=18
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB $FF,$00,$EE          ; flag=-1, dy=0, dx=-18
    FCB $FF,$0E,$00          ; flag=-1, dy=14, dx=0
    FCB 2                ; End marker (path complete)

_CRYSTAL_APPRENTICE_PATH5:    ; Path 5
    FCB 100              ; path5: intensity
    FCB $F7,$F2,0,0        ; path5: header (y=-9, x=-14)
    FCB $FF,$00,$1C          ; flag=-1, dy=0, dx=28
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$E4          ; flag=-1, dy=0, dx=-28
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB 2                ; End marker (path complete)

_CRYSTAL_APPRENTICE_PATH6:    ; Path 6
    FCB 80              ; path6: intensity
    FCB $FF,$F8,0,0        ; path6: header (y=-1, x=-8)
    FCB $FF,$00,$10          ; flag=-1, dy=0, dx=16
    FCB 2                ; End marker (path complete)

; Generated from hans_automata.vec (Malban Draw_Sync_List format)
; Total paths: 8, points: 24
; X bounds: min=-11, max=11, width=22
; Center: (0, 0)

_HANS_AUTOMATA_WIDTH EQU 22
_HANS_AUTOMATA_HALF_WIDTH EQU 11
_HANS_AUTOMATA_HEIGHT EQU 23
_HANS_AUTOMATA_HALF_HEIGHT EQU 11
_HANS_AUTOMATA_CENTER_X EQU 0
_HANS_AUTOMATA_CENTER_Y EQU 0

_HANS_AUTOMATA_VECTORS:  ; Main entry (header + 8 path(s))
    FDB 8               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _HANS_AUTOMATA_PATH0        ; pointer to path 0
    FDB _HANS_AUTOMATA_PATH1        ; pointer to path 1
    FDB _HANS_AUTOMATA_PATH2        ; pointer to path 2
    FDB _HANS_AUTOMATA_PATH3        ; pointer to path 3
    FDB _HANS_AUTOMATA_PATH4        ; pointer to path 4
    FDB _HANS_AUTOMATA_PATH5        ; pointer to path 5
    FDB _HANS_AUTOMATA_PATH6        ; pointer to path 6
    FDB _HANS_AUTOMATA_PATH7        ; pointer to path 7

_HANS_AUTOMATA_PATH0:    ; Path 0
    FCB 85              ; path0: intensity
    FCB $01,$FA,0,0        ; path0: header (y=1, x=-6)
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB 2                ; End marker (path complete)

_HANS_AUTOMATA_PATH1:    ; Path 1
    FCB 100              ; path1: intensity
    FCB $03,$07,0,0        ; path1: header (y=3, x=7)
    FCB $FF,$FC,$04          ; flag=-1, dy=-4, dx=4
    FCB 2                ; End marker (path complete)

_HANS_AUTOMATA_PATH2:    ; Path 2
    FCB 85              ; path2: intensity
    FCB $FD,$06,0,0        ; path2: header (y=-3, x=6)
    FCB $FF,$00,$F4          ; flag=-1, dy=0, dx=-12
    FCB 2                ; End marker (path complete)

_HANS_AUTOMATA_PATH3:    ; Path 3
    FCB 110              ; path3: intensity
    FCB $FA,$F9,0,0        ; path3: header (y=-6, x=-7)
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB $FF,$0C,$00          ; flag=-1, dy=12, dx=0
    FCB $FF,$00,$F2          ; flag=-1, dy=0, dx=-14
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB 2                ; End marker (path complete)

_HANS_AUTOMATA_PATH4:    ; Path 4
    FCB 110              ; path4: intensity
    FCB $06,$FC,0,0        ; path4: header (y=6, x=-4)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_HANS_AUTOMATA_PATH5:    ; Path 5
    FCB 100              ; path5: intensity
    FCB $03,$F9,0,0        ; path5: header (y=3, x=-7)
    FCB $FF,$FC,$FC          ; flag=-1, dy=-4, dx=-4
    FCB 2                ; End marker (path complete)

_HANS_AUTOMATA_PATH6:    ; Path 6
    FCB 90              ; path6: intensity
    FCB $F8,$FA,0,0        ; path6: header (y=-8, x=-6)
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB 2                ; End marker (path complete)

_HANS_AUTOMATA_PATH7:    ; Path 7
    FCB 90              ; path7: intensity
    FCB $F8,$02,0,0        ; path7: header (y=-8, x=2)
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB 2                ; End marker (path complete)

; Generated from desk.vec (Malban Draw_Sync_List format)
; Total paths: 10, points: 25
; X bounds: min=-30, max=30, width=60
; Center: (0, 7)

_DESK_WIDTH EQU 60
_DESK_HALF_WIDTH EQU 30
_DESK_HEIGHT EQU 46
_DESK_HALF_HEIGHT EQU 23
_DESK_CENTER_X EQU 0
_DESK_CENTER_Y EQU 7

_DESK_VECTORS:  ; Main entry (header + 10 path(s))
    FDB 10               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
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
    FCB 80              ; path0: intensity
    FCB $F7,$00,0,0        ; path0: header (y=-9, x=0)
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB 2                ; End marker (path complete)

_DESK_PATH1:    ; Path 1
    FCB 55              ; path1: intensity
    FCB $EF,$FE,0,0        ; path1: header (y=-17, x=-2)
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB 2                ; End marker (path complete)

_DESK_PATH2:    ; Path 2
    FCB 55              ; path2: intensity
    FCB $F3,$F5,0,0        ; path2: header (y=-13, x=-11)
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB 2                ; End marker (path complete)

_DESK_PATH3:    ; Path 3
    FCB 55              ; path3: intensity
    FCB $F3,$02,0,0        ; path3: header (y=-13, x=2)
    FCB $FF,$00,$09          ; flag=-1, dy=0, dx=9
    FCB 2                ; End marker (path complete)

_DESK_PATH4:    ; Path 4
    FCB 55              ; path4: intensity
    FCB $EF,$0B,0,0        ; path4: header (y=-17, x=11)
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB 2                ; End marker (path complete)

_DESK_PATH5:    ; Path 5
    FCB 110              ; path5: intensity
    FCB $F7,$0E,0,0        ; path5: header (y=-9, x=14)
    FCB $FF,$F2,$00          ; flag=-1, dy=-14, dx=0
    FCB $FF,$00,$E4          ; flag=-1, dy=0, dx=-28
    FCB $FF,$0E,$00          ; flag=-1, dy=14, dx=0
    FCB 2                ; End marker (path complete)

_DESK_PATH6:    ; Path 6
    FCB 90              ; path6: intensity
    FCB $FE,$E6,0,0        ; path6: header (y=-2, x=-26)
    FCB $FF,$19,$00          ; flag=-1, dy=25, dx=0
    FCB 2                ; End marker (path complete)

_DESK_PATH7:    ; Path 7
    FCB 75              ; path7: intensity
    FCB $0B,$E6,0,0        ; path7: header (y=11, x=-26)
    FCB $FF,$00,$34          ; flag=-1, dy=0, dx=52
    FCB 2                ; End marker (path complete)

_DESK_PATH8:    ; Path 8
    FCB 90              ; path8: intensity
    FCB $17,$1A,0,0        ; path8: header (y=23, x=26)
    FCB $FF,$E7,$00          ; flag=-1, dy=-25, dx=0
    FCB 2                ; End marker (path complete)

_DESK_PATH9:    ; Path 9
    FCB 100              ; path9: intensity
    FCB $F7,$E2,0,0        ; path9: header (y=-9, x=-30)
    FCB $FF,$00,$3C          ; flag=-1, dy=0, dx=60
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB $FF,$00,$C4          ; flag=-1, dy=0, dx=-60
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
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
    FDB -96  ; scrollLimit left (camera left cannot go below this)
    FDB 863  ; scrollLimit right (camera right cannot exceed this)
    FDB 127  ; scrollLimit top
    FDB -128  ; scrollLimit bottom
    FCB 0  ; enemy_count
    FDB 0  ; enemy_instances_ptr (0 if none)
    FDB 0  ; groundBottomOffset (floor surface offset from screen bottom)
    FCB 1    ; +34 screen_count
    FDB _ANTEROOM_BG_SCREENS  ; +35 BG screens index
    FDB _ANTEROOM_GP_SCREENS  ; +37 GP screens index
    FDB _ANTEROOM_FG_SCREENS  ; +39 FG screens index

_ANTEROOM_BG_OBJECTS:
_ANTEROOM_BG_OBJECTS_S0:

_ANTEROOM_GAMEPLAY_OBJECTS:
_ANTEROOM_GAMEPLAY_OBJECTS_S0:
; Object: obj_ant_lamp_left (enemy)
    FCB 1  ; type
    FDB 80  ; x
    FDB -5  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 1   ; vector_bank (ROM+16)
    FDB _LAMP_VECTORS  ; vector_ptr (ROM+17)
    FCB 22  ; half_width (1.00x, ROM+19)
    FCB 6  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_ant_desk (enemy)
    FCB 1  ; type
    FDB 300  ; x
    FDB -72  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 1   ; vector_bank (ROM+16)
    FDB _DESK_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 23  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_ant_lamp_right (enemy)
    FCB 1  ; type
    FDB 530  ; x
    FDB -5  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 1   ; vector_bank (ROM+16)
    FDB _LAMP_VECTORS  ; vector_ptr (ROM+17)
    FCB 22  ; half_width (1.00x, ROM+19)
    FCB 6  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_ant_exit_arch (enemy)
    FCB 1  ; type
    FDB 734  ; x
    FDB -33  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 1   ; vector_bank (ROM+16)
    FDB _ENTRANCE_ARC_VECTORS  ; vector_ptr (ROM+17)
    FCB 60  ; half_width (1.00x, ROM+19)
    FCB 94  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)


_ANTEROOM_FG_OBJECTS:
_ANTEROOM_FG_OBJECTS_S0:

_ANTEROOM_BG_SCREENS:
    FCB 0  ; screen 0 count
    FDB _ANTEROOM_BG_OBJECTS_S0  ; screen 0 ptr

_ANTEROOM_GP_SCREENS:
    FCB 4  ; screen 0 count
    FDB _ANTEROOM_GAMEPLAY_OBJECTS_S0  ; screen 0 ptr

_ANTEROOM_FG_SCREENS:
    FCB 0  ; screen 0 count
    FDB _ANTEROOM_FG_OBJECTS_S0  ; screen 0 ptr

_ANTEROOM_ENEMY_COUNT EQU 0


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
    FDB -96  ; scrollLimit left (camera left cannot go below this)
    FDB 671  ; scrollLimit right (camera right cannot exceed this)
    FDB 127  ; scrollLimit top
    FDB -128  ; scrollLimit bottom
    FCB 0  ; enemy_count
    FDB 0  ; enemy_instances_ptr (0 if none)
    FDB 0  ; groundBottomOffset (floor surface offset from screen bottom)
    FCB 1    ; +34 screen_count
    FDB _CLOCKROOM_BG_SCREENS  ; +35 BG screens index
    FDB _CLOCKROOM_GP_SCREENS  ; +37 GP screens index
    FDB _CLOCKROOM_FG_SCREENS  ; +39 FG screens index

_CLOCKROOM_BG_OBJECTS:
_CLOCKROOM_BG_OBJECTS_S0:

_CLOCKROOM_GAMEPLAY_OBJECTS:
_CLOCKROOM_GAMEPLAY_OBJECTS_S0:
; Object: obj_lamp_left (enemy)
    FCB 1  ; type
    FDB 70  ; x
    FDB -5  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 1   ; vector_bank (ROM+16)
    FDB _LAMP_VECTORS  ; vector_ptr (ROM+17)
    FCB 22  ; half_width (1.00x, ROM+19)
    FCB 6  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_sarcophagus (enemy)
    FCB 1  ; type
    FDB 190  ; x
    FDB -72  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 1   ; vector_bank (ROM+16)
    FDB _DOOR_LOCKED_VECTORS  ; vector_ptr (ROM+17)
    FCB 11  ; half_width (1.00x, ROM+19)
    FCB 26  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_pendulum_clock (enemy)
    FCB 1  ; type
    FDB 400  ; x
    FDB -60  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 1   ; vector_bank (ROM+16)
    FDB _PAINTING_VECTORS  ; vector_ptr (ROM+17)
    FCB 16  ; half_width (1.00x, ROM+19)
    FCB 18  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_lamp_right (enemy)
    FCB 1  ; type
    FDB 480  ; x
    FDB -5  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 1   ; vector_bank (ROM+16)
    FDB _LAMP_VECTORS  ; vector_ptr (ROM+17)
    FCB 22  ; half_width (1.00x, ROM+19)
    FCB 6  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)


_CLOCKROOM_FG_OBJECTS:
_CLOCKROOM_FG_OBJECTS_S0:

_CLOCKROOM_BG_SCREENS:
    FCB 0  ; screen 0 count
    FDB _CLOCKROOM_BG_OBJECTS_S0  ; screen 0 ptr

_CLOCKROOM_GP_SCREENS:
    FCB 4  ; screen 0 count
    FDB _CLOCKROOM_GAMEPLAY_OBJECTS_S0  ; screen 0 ptr

_CLOCKROOM_FG_SCREENS:
    FCB 0  ; screen 0 count
    FDB _CLOCKROOM_FG_OBJECTS_S0  ; screen 0 ptr

_CLOCKROOM_ENEMY_COUNT EQU 0


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
    FDB -96  ; scrollLimit left (camera left cannot go below this)
    FDB 863  ; scrollLimit right (camera right cannot exceed this)
    FDB 127  ; scrollLimit top
    FDB -128  ; scrollLimit bottom
    FCB 0  ; enemy_count
    FDB 0  ; enemy_instances_ptr (0 if none)
    FDB 0  ; groundBottomOffset (floor surface offset from screen bottom)
    FCB 1    ; +34 screen_count
    FDB _ENTRANCE_BG_SCREENS  ; +35 BG screens index
    FDB _ENTRANCE_GP_SCREENS  ; +37 GP screens index
    FDB _ENTRANCE_FG_SCREENS  ; +39 FG screens index

_ENTRANCE_BG_OBJECTS:
_ENTRANCE_BG_OBJECTS_S0:
; Object: obj_1772461603432 (enemy)
    FCB 1  ; type
    FDB -30  ; x
    FDB -33  ; y
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
    FDB _ENTRANCE_ARC_VECTORS  ; vector_ptr (ROM+17)
    FCB 60  ; half_width (1.00x, ROM+19)
    FCB 94  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)


_ENTRANCE_GAMEPLAY_OBJECTS:
_ENTRANCE_GAMEPLAY_OBJECTS_S0:
; Object: obj_1772392174432 (enemy)
    FCB 1  ; type
    FDB 458  ; x
    FDB -2  ; y
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
    FDB _LAMP_VECTORS  ; vector_ptr (ROM+17)
    FCB 22  ; half_width (1.00x, ROM+19)
    FCB 6  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_1772392204950 (enemy)
    FCB 1  ; type
    FDB 259  ; x
    FDB -49  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 2   ; vector_bank (ROM+16)
    FDB _CANVAS_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 22  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_1772392228716 (enemy)
    FCB 1  ; type
    FDB 738  ; x
    FDB -47  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 2   ; vector_bank (ROM+16)
    FDB _LOCKED_DOOR_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 55  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)


_ENTRANCE_FG_OBJECTS:
_ENTRANCE_FG_OBJECTS_S0:

_ENTRANCE_BG_SCREENS:
    FCB 1  ; screen 0 count
    FDB _ENTRANCE_BG_OBJECTS_S0  ; screen 0 ptr

_ENTRANCE_GP_SCREENS:
    FCB 3  ; screen 0 count
    FDB _ENTRANCE_GAMEPLAY_OBJECTS_S0  ; screen 0 ptr

_ENTRANCE_FG_SCREENS:
    FCB 0  ; screen 0 count
    FDB _ENTRANCE_FG_OBJECTS_S0  ; screen 0 ptr

_ENTRANCE_ENEMY_COUNT EQU 0


; Generated from player.vec (Malban Draw_Sync_List format)
; Total paths: 7, points: 25
; X bounds: min=-11, max=10, width=21
; Center: (0, 0)

_PLAYER_WIDTH EQU 21
_PLAYER_HALF_WIDTH EQU 10
_PLAYER_HEIGHT EQU 42
_PLAYER_HALF_HEIGHT EQU 21
_PLAYER_CENTER_X EQU 0
_PLAYER_CENTER_Y EQU 0

_PLAYER_VECTORS:  ; Main entry (header + 7 path(s))
    FDB 7               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLAYER_PATH0        ; pointer to path 0
    FDB _PLAYER_PATH1        ; pointer to path 1
    FDB _PLAYER_PATH2        ; pointer to path 2
    FDB _PLAYER_PATH3        ; pointer to path 3
    FDB _PLAYER_PATH4        ; pointer to path 4
    FDB _PLAYER_PATH5        ; pointer to path 5
    FDB _PLAYER_PATH6        ; pointer to path 6

_PLAYER_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $FF,$05,0,0        ; path0: header (y=-1, x=5)
    FCB $FF,$FB,$05          ; flag=-1, dy=-5, dx=5
    FCB 2                ; End marker (path complete)

_PLAYER_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $F3,$03,0,0        ; path1: header (y=-13, x=3)
    FCB $FF,$F8,$01          ; flag=-1, dy=-8, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $EB,$FA,0,0        ; path2: header (y=-21, x=-6)
    FCB $FF,$08,$01          ; flag=-1, dy=8, dx=1
    FCB 2                ; End marker (path complete)

_PLAYER_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $F9,$F5,0,0        ; path3: header (y=-7, x=-11)
    FCB $FF,$06,$04          ; flag=-1, dy=6, dx=4
    FCB 2                ; End marker (path complete)

_PLAYER_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $06,$FA,0,0        ; path4: header (y=6, x=-6)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $0D,$FA,0,0        ; path5: header (y=13, x=-6)
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$FF,$00          ; flag=-1, dy=-1, dx=0
    FCB $FF,$00,$10          ; flag=-1, dy=0, dx=16
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_PLAYER_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $06,$FB,0,0        ; path6: header (y=6, x=-5)
    FCB $FF,$ED,$FC          ; flag=-1, dy=-19, dx=-4
    FCB $FF,$00,$10          ; flag=-1, dy=0, dx=16
    FCB $FF,$13,$FC          ; flag=-1, dy=19, dx=-4
    FCB 2                ; End marker (path complete)

_PUZZLE_SUCCESS_SFX:
    ; SFX: puzzle_success (powerup)
    ; Duration: 500ms (25fr), Freq: 440Hz, Channel: 0
    FCB $A0         ; Frame 0 - flags (vol=0, noisevol=0, tone=Y, noise=N)
    FCB $00, $C8  ; Tone period = 200 (big-endian)
    FCB $AF         ; Frame 1 - flags (vol=15, noisevol=0, tone=Y, noise=N)
    FCB $00, $C8  ; Tone period = 200 (big-endian)
    FCB $AD         ; Frame 2 - flags (vol=13, noisevol=0, tone=Y, noise=N)
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
    FCB $A9         ; Frame 11 - flags (vol=9, noisevol=0, tone=Y, noise=N)
    FCB $00, $86  ; Tone period = 134 (big-endian)
    FCB $A8         ; Frame 12 - flags (vol=8, noisevol=0, tone=Y, noise=N)
    FCB $00, $59  ; Tone period = 89 (big-endian)
    FCB $A8         ; Frame 13 - flags (vol=8, noisevol=0, tone=Y, noise=N)
    FCB $00, $59  ; Tone period = 89 (big-endian)
    FCB $A7         ; Frame 14 - flags (vol=7, noisevol=0, tone=Y, noise=N)
    FCB $00, $59  ; Tone period = 89 (big-endian)
    FCB $A6         ; Frame 15 - flags (vol=6, noisevol=0, tone=Y, noise=N)
    FCB $00, $59  ; Tone period = 89 (big-endian)
    FCB $A6         ; Frame 16 - flags (vol=6, noisevol=0, tone=Y, noise=N)
    FCB $00, $59  ; Tone period = 89 (big-endian)
    FCB $A5         ; Frame 17 - flags (vol=5, noisevol=0, tone=Y, noise=N)
    FCB $00, $59  ; Tone period = 89 (big-endian)
    FCB $A4         ; Frame 18 - flags (vol=4, noisevol=0, tone=Y, noise=N)
    FCB $00, $C8  ; Tone period = 200 (big-endian)
    FCB $A3         ; Frame 19 - flags (vol=3, noisevol=0, tone=Y, noise=N)
    FCB $00, $C8  ; Tone period = 200 (big-endian)
    FCB $A3         ; Frame 20 - flags (vol=3, noisevol=0, tone=Y, noise=N)
    FCB $00, $C8  ; Tone period = 200 (big-endian)
    FCB $A2         ; Frame 21 - flags (vol=2, noisevol=0, tone=Y, noise=N)
    FCB $00, $C8  ; Tone period = 200 (big-endian)
    FCB $A1         ; Frame 22 - flags (vol=1, noisevol=0, tone=Y, noise=N)
    FCB $00, $C8  ; Tone period = 200 (big-endian)
    FCB $A1         ; Frame 23 - flags (vol=1, noisevol=0, tone=Y, noise=N)
    FCB $00, $C8  ; Tone period = 200 (big-endian)
    FCB $A0         ; Frame 24 - flags (vol=0, noisevol=0, tone=Y, noise=N)
    FCB $00, $86  ; Tone period = 134 (big-endian)
    FCB $D0, $20    ; End of effect marker


; Generated from entrance_arc.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 17
; X bounds: min=-60, max=60, width=120
; Center: (0, 0)

_ENTRANCE_ARC_WIDTH EQU 120
_ENTRANCE_ARC_HALF_WIDTH EQU 60
_ENTRANCE_ARC_HEIGHT EQU 188
_ENTRANCE_ARC_HALF_HEIGHT EQU 94
_ENTRANCE_ARC_CENTER_X EQU 0
_ENTRANCE_ARC_CENTER_Y EQU 0

_ENTRANCE_ARC_VECTORS:  ; Main entry (header + 4 path(s))
    FDB 4               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _ENTRANCE_ARC_PATH0        ; pointer to path 0
    FDB _ENTRANCE_ARC_PATH1        ; pointer to path 1
    FDB _ENTRANCE_ARC_PATH2        ; pointer to path 2
    FDB _ENTRANCE_ARC_PATH3        ; pointer to path 3

_ENTRANCE_ARC_PATH0:    ; Path 0
    FCB 60              ; path0: intensity
    FCB $2E,$DD,0,0        ; path0: header (y=46, x=-35)
    FCB $FF,$00,$46          ; flag=-1, dy=0, dx=70
    FCB $FF,$BA,$00          ; sub-seg 1/2 of line 1: dy=-70, dx=0
    FCB $FF,$BA,$00          ; sub-seg 2/2 of line 1: dy=-70, dx=0
    FCB $FF,$00,$BA          ; flag=-1, dy=0, dx=-70
    FCB $FF,$46,$00          ; sub-seg 1/2 of closing line: dy=70, dx=0
    FCB $FF,$46,$00          ; sub-seg 2/2 of closing line: dy=70, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $A2,$C4,0,0        ; path1: header (y=-94, x=-60)
    FCB $FF,$00,$14          ; flag=-1, dy=0, dx=20
    FCB $FF,$46,$00          ; sub-seg 1/2 of line 1: dy=70, dx=0
    FCB $FF,$46,$00          ; sub-seg 2/2 of line 1: dy=70, dx=0
    FCB $FF,$00,$EC          ; flag=-1, dy=0, dx=-20
    FCB $FF,$BA,$00          ; sub-seg 1/2 of closing line: dy=-70, dx=0
    FCB $FF,$BA,$00          ; sub-seg 2/2 of closing line: dy=-70, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $2E,$D8,0,0        ; path2: header (y=46, x=-40)
    FCB $FF,$19,$02          ; flag=-1, dy=25, dx=2
    FCB $FF,$17,$26          ; flag=-1, dy=23, dx=38
    FCB $FF,$E9,$26          ; flag=-1, dy=-23, dx=38
    FCB $FF,$E7,$02          ; flag=-1, dy=-25, dx=2
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $2E,$28,0,0        ; path3: header (y=46, x=40)
    FCB $FF,$00,$14          ; flag=-1, dy=0, dx=20
    FCB $FF,$BA,$00          ; sub-seg 1/2 of line 1: dy=-70, dx=0
    FCB $FF,$BA,$00          ; sub-seg 2/2 of line 1: dy=-70, dx=0
    FCB $FF,$00,$EC          ; flag=-1, dy=0, dx=-20
    FCB $FF,$46,$00          ; sub-seg 1/2 of closing line: dy=70, dx=0
    FCB $FF,$46,$00          ; sub-seg 2/2 of closing line: dy=70, dx=0
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
    FDB -96  ; scrollLimit left (camera left cannot go below this)
    FDB 671  ; scrollLimit right (camera right cannot exceed this)
    FDB 127  ; scrollLimit top
    FDB -128  ; scrollLimit bottom
    FCB 0  ; enemy_count
    FDB 0  ; enemy_instances_ptr (0 if none)
    FDB 0  ; groundBottomOffset (floor surface offset from screen bottom)
    FCB 1    ; +34 screen_count
    FDB _WEIGHTS_ROOM_BG_SCREENS  ; +35 BG screens index
    FDB _WEIGHTS_ROOM_GP_SCREENS  ; +37 GP screens index
    FDB _WEIGHTS_ROOM_FG_SCREENS  ; +39 FG screens index

_WEIGHTS_ROOM_BG_OBJECTS:
_WEIGHTS_ROOM_BG_OBJECTS_S0:

_WEIGHTS_ROOM_GAMEPLAY_OBJECTS:
_WEIGHTS_ROOM_GAMEPLAY_OBJECTS_S0:
; Object: obj_wgt_lamp (enemy)
    FCB 1  ; type
    FDB 80  ; x
    FDB -5  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 1   ; vector_bank (ROM+16)
    FDB _LAMP_VECTORS  ; vector_ptr (ROM+17)
    FCB 22  ; half_width (1.00x, ROM+19)
    FCB 6  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_wgt_pedestal_base (enemy)
    FCB 1  ; type
    FDB 280  ; x
    FDB -68  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 2   ; vector_bank (ROM+16)
    FDB _CANVAS_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 22  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_wgt_exit_arch (enemy)
    FCB 1  ; type
    FDB 570  ; x
    FDB -34  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 1   ; vector_bank (ROM+16)
    FDB _ENTRANCE_ARC_VECTORS  ; vector_ptr (ROM+17)
    FCB 60  ; half_width (1.00x, ROM+19)
    FCB 94  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)


_WEIGHTS_ROOM_FG_OBJECTS:
_WEIGHTS_ROOM_FG_OBJECTS_S0:

_WEIGHTS_ROOM_BG_SCREENS:
    FCB 0  ; screen 0 count
    FDB _WEIGHTS_ROOM_BG_OBJECTS_S0  ; screen 0 ptr

_WEIGHTS_ROOM_GP_SCREENS:
    FCB 3  ; screen 0 count
    FDB _WEIGHTS_ROOM_GAMEPLAY_OBJECTS_S0  ; screen 0 ptr

_WEIGHTS_ROOM_FG_SCREENS:
    FCB 0  ; screen 0 count
    FDB _WEIGHTS_ROOM_FG_OBJECTS_S0  ; screen 0 ptr

_WEIGHTS_ROOM_ENEMY_COUNT EQU 0


_DOOR_UNLOCK_SFX:
    ; SFX: door_unlock (custom)
    ; Duration: 400ms (20fr), Freq: 330Hz, Channel: 0
    FCB $6E         ; Frame 0 - flags (vol=14, noisevol=8, tone=Y, noise=Y)
    FCB $00, $6B  ; Tone period = 107 (big-endian)
    FCB $06         ; Noise period
    FCB $6A         ; Frame 1 - flags (vol=10, noisevol=7, tone=Y, noise=Y)
    FCB $00, $70  ; Tone period = 112 (big-endian)
    FCB $06         ; Noise period
    FCB $66         ; Frame 2 - flags (vol=6, noisevol=6, tone=Y, noise=Y)
    FCB $00, $75  ; Tone period = 117 (big-endian)
    FCB $06         ; Noise period
    FCB $66         ; Frame 3 - flags (vol=6, noisevol=5, tone=Y, noise=Y)
    FCB $00, $7B  ; Tone period = 123 (big-endian)
    FCB $06         ; Noise period
    FCB $66         ; Frame 4 - flags (vol=6, noisevol=4, tone=Y, noise=Y)
    FCB $00, $82  ; Tone period = 130 (big-endian)
    FCB $06         ; Noise period
    FCB $66         ; Frame 5 - flags (vol=6, noisevol=4, tone=Y, noise=Y)
    FCB $00, $89  ; Tone period = 137 (big-endian)
    FCB $06         ; Noise period
    FCB $66         ; Frame 6 - flags (vol=6, noisevol=3, tone=Y, noise=Y)
    FCB $00, $92  ; Tone period = 146 (big-endian)
    FCB $06         ; Noise period
    FCB $66         ; Frame 7 - flags (vol=6, noisevol=2, tone=Y, noise=Y)
    FCB $00, $9B  ; Tone period = 155 (big-endian)
    FCB $06         ; Noise period
    FCB $65         ; Frame 8 - flags (vol=5, noisevol=1, tone=Y, noise=Y)
    FCB $00, $A5  ; Tone period = 165 (big-endian)
    FCB $06         ; Noise period
    FCB $A5         ; Frame 9 - flags (vol=5, noisevol=0, tone=Y, noise=N)
    FCB $00, $B2  ; Tone period = 178 (big-endian)
    FCB $A4         ; Frame 10 - flags (vol=4, noisevol=0, tone=Y, noise=N)
    FCB $00, $C0  ; Tone period = 192 (big-endian)
    FCB $A4         ; Frame 11 - flags (vol=4, noisevol=0, tone=Y, noise=N)
    FCB $00, $D0  ; Tone period = 208 (big-endian)
    FCB $A3         ; Frame 12 - flags (vol=3, noisevol=0, tone=Y, noise=N)
    FCB $00, $E4  ; Tone period = 228 (big-endian)
    FCB $A3         ; Frame 13 - flags (vol=3, noisevol=0, tone=Y, noise=N)
    FCB $00, $FB  ; Tone period = 251 (big-endian)
    FCB $A2         ; Frame 14 - flags (vol=2, noisevol=0, tone=Y, noise=N)
    FCB $01, $19  ; Tone period = 281 (big-endian)
    FCB $A2         ; Frame 15 - flags (vol=2, noisevol=0, tone=Y, noise=N)
    FCB $01, $3D  ; Tone period = 317 (big-endian)
    FCB $A1         ; Frame 16 - flags (vol=1, noisevol=0, tone=Y, noise=N)
    FCB $01, $6D  ; Tone period = 365 (big-endian)
    FCB $A1         ; Frame 17 - flags (vol=1, noisevol=0, tone=Y, noise=N)
    FCB $01, $AE  ; Tone period = 430 (big-endian)
    FCB $A0         ; Frame 18 - flags (vol=0, noisevol=0, tone=Y, noise=N)
    FCB $02, $0C  ; Tone period = 524 (big-endian)
    FCB $A0         ; Frame 19 - flags (vol=0, noisevol=0, tone=Y, noise=N)
    FCB $02, $9C  ; Tone period = 668 (big-endian)
    FCB $D0, $20    ; End of effect marker


; Generated from lamp.vec (Malban Draw_Sync_List format)
; Total paths: 7, points: 19
; X bounds: min=-22, max=22, width=44
; Center: (0, 0)

_LAMP_WIDTH EQU 44
_LAMP_HALF_WIDTH EQU 22
_LAMP_HEIGHT EQU 13
_LAMP_HALF_HEIGHT EQU 6
_LAMP_CENTER_X EQU 0
_LAMP_CENTER_Y EQU 0

_LAMP_VECTORS:  ; Main entry (header + 7 path(s))
    FDB 7               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _LAMP_PATH0        ; pointer to path 0
    FDB _LAMP_PATH1        ; pointer to path 1
    FDB _LAMP_PATH2        ; pointer to path 2
    FDB _LAMP_PATH3        ; pointer to path 3
    FDB _LAMP_PATH4        ; pointer to path 4
    FDB _LAMP_PATH5        ; pointer to path 5
    FDB _LAMP_PATH6        ; pointer to path 6

_LAMP_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FF,$00,0,0        ; path0: header (y=-1, x=0)
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB 2                ; End marker (path complete)

_LAMP_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $FF,$FB,0,0        ; path1: header (y=-1, x=-5)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$FA,$FE          ; flag=-1, dy=-6, dx=-2
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$06,$FE          ; flag=-1, dy=6, dx=-2
    FCB 2                ; End marker (path complete)

_LAMP_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $00,$F0,0,0        ; path2: header (y=0, x=-16)
    FCB $FF,$FD,$FE          ; flag=-1, dy=-3, dx=-2
    FCB $FF,$03,$FE          ; flag=-1, dy=3, dx=-2
    FCB 2                ; End marker (path complete)

_LAMP_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $00,$EE,0,0        ; path3: header (y=0, x=-18)
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB 2                ; End marker (path complete)

_LAMP_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $06,$EA,0,0        ; path4: header (y=6, x=-22)
    FCB $FF,$00,$2C          ; flag=-1, dy=0, dx=44
    FCB 2                ; End marker (path complete)

_LAMP_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $06,$12,0,0        ; path5: header (y=6, x=18)
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_LAMP_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $00,$10,0,0        ; path6: header (y=0, x=16)
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB 2                ; End marker (path complete)

; Generated from platform_down.vec (Malban Draw_Sync_List format)
; Total paths: 7, points: 19
; X bounds: min=-38, max=38, width=76
; Center: (0, 20)

_PLATFORM_DOWN_WIDTH EQU 76
_PLATFORM_DOWN_HALF_WIDTH EQU 38
_PLATFORM_DOWN_HEIGHT EQU 36
_PLATFORM_DOWN_HALF_HEIGHT EQU 18
_PLATFORM_DOWN_CENTER_X EQU 0
_PLATFORM_DOWN_CENTER_Y EQU 20

_PLATFORM_DOWN_VECTORS:  ; Main entry (header + 7 path(s))
    FDB 7               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLATFORM_DOWN_PATH0        ; pointer to path 0
    FDB _PLATFORM_DOWN_PATH1        ; pointer to path 1
    FDB _PLATFORM_DOWN_PATH2        ; pointer to path 2
    FDB _PLATFORM_DOWN_PATH3        ; pointer to path 3
    FDB _PLATFORM_DOWN_PATH4        ; pointer to path 4
    FDB _PLATFORM_DOWN_PATH5        ; pointer to path 5
    FDB _PLATFORM_DOWN_PATH6        ; pointer to path 6

_PLATFORM_DOWN_PATH0:    ; Path 0
    FCB 50              ; path0: intensity
    FCB $EE,$F9,0,0        ; path0: header (y=-18, x=-7)
    FCB $FF,$08,$FE          ; flag=-1, dy=8, dx=-2
    FCB $FF,$08,$03          ; flag=-1, dy=8, dx=3
    FCB 2                ; End marker (path complete)

_PLATFORM_DOWN_PATH1:    ; Path 1
    FCB 80              ; path1: intensity
    FCB $08,$F9,0,0        ; path1: header (y=8, x=-7)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB 2                ; End marker (path complete)

_PLATFORM_DOWN_PATH2:    ; Path 2
    FCB 90              ; path2: intensity
    FCB $12,$F4,0,0        ; path2: header (y=18, x=-12)
    FCB $FF,$00,$18          ; flag=-1, dy=0, dx=24
    FCB 2                ; End marker (path complete)

_PLATFORM_DOWN_PATH3:    ; Path 3
    FCB 80              ; path3: intensity
    FCB $12,$07,0,0        ; path3: header (y=18, x=7)
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

_PLATFORM_DOWN_PATH4:    ; Path 4
    FCB 50              ; path4: intensity
    FCB $FE,$06,0,0        ; path4: header (y=-2, x=6)
    FCB $FF,$F8,$03          ; flag=-1, dy=-8, dx=3
    FCB $FF,$F8,$FE          ; flag=-1, dy=-8, dx=-2
    FCB 2                ; End marker (path complete)

_PLATFORM_DOWN_PATH5:    ; Path 5
    FCB 75              ; path5: intensity
    FCB $01,$23,0,0        ; path5: header (y=1, x=35)
    FCB $FF,$00,$BA          ; flag=-1, dy=0, dx=-70
    FCB 2                ; End marker (path complete)

_PLATFORM_DOWN_PATH6:    ; Path 6
    FCB 100              ; path6: intensity
    FCB $FE,$DA,0,0        ; path6: header (y=-2, x=-38)
    FCB $FF,$00,$4C          ; flag=-1, dy=0, dx=76
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$B4          ; flag=-1, dy=0, dx=-76
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

; Generated from caretaker.vec (Malban Draw_Sync_List format)
; Total paths: 7, points: 17
; X bounds: min=-7, max=10, width=17
; Center: (1, 2)

_CARETAKER_WIDTH EQU 17
_CARETAKER_HALF_WIDTH EQU 8
_CARETAKER_HEIGHT EQU 33
_CARETAKER_HALF_HEIGHT EQU 16
_CARETAKER_CENTER_X EQU 1
_CARETAKER_CENTER_Y EQU 2

_CARETAKER_VECTORS:  ; Main entry (header + 7 path(s))
    FDB 7               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _CARETAKER_PATH0        ; pointer to path 0
    FDB _CARETAKER_PATH1        ; pointer to path 1
    FDB _CARETAKER_PATH2        ; pointer to path 2
    FDB _CARETAKER_PATH3        ; pointer to path 3
    FDB _CARETAKER_PATH4        ; pointer to path 4
    FDB _CARETAKER_PATH5        ; pointer to path 5
    FDB _CARETAKER_PATH6        ; pointer to path 6

_CARETAKER_PATH0:    ; Path 0
    FCB 80              ; path0: intensity
    FCB $FA,$00,0,0        ; path0: header (y=-6, x=0)
    FCB $FF,$F6,$FE          ; flag=-1, dy=-10, dx=-2
    FCB 2                ; End marker (path complete)

_CARETAKER_PATH1:    ; Path 1
    FCB 80              ; path1: intensity
    FCB $F0,$04,0,0        ; path1: header (y=-16, x=4)
    FCB $FF,$0A,$FE          ; flag=-1, dy=10, dx=-2
    FCB 2                ; End marker (path complete)

_CARETAKER_PATH2:    ; Path 2
    FCB 80              ; path2: intensity
    FCB $FA,$02,0,0        ; path2: header (y=-6, x=2)
    FCB $FF,$0A,$FF          ; flag=-1, dy=10, dx=-1
    FCB $FF,$08,$FD          ; flag=-1, dy=8, dx=-3
    FCB 2                ; End marker (path complete)

_CARETAKER_PATH3:    ; Path 3
    FCB 80              ; path3: intensity
    FCB $0C,$FA,0,0        ; path3: header (y=12, x=-6)
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$F9          ; flag=-1, dy=0, dx=-7
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)

_CARETAKER_PATH4:    ; Path 4
    FCB 75              ; path4: intensity
    FCB $08,$00,0,0        ; path4: header (y=8, x=0)
    FCB $FF,$FA,$F8          ; flag=-1, dy=-6, dx=-8
    FCB 2                ; End marker (path complete)

_CARETAKER_PATH5:    ; Path 5
    FCB 75              ; path5: intensity
    FCB $06,$01,0,0        ; path5: header (y=6, x=1)
    FCB $FF,$F9,$03          ; flag=-1, dy=-7, dx=3
    FCB 2                ; End marker (path complete)

_CARETAKER_PATH6:    ; Path 6
    FCB 70              ; path6: intensity
    FCB $FF,$04,0,0        ; path6: header (y=-1, x=4)
    FCB $FF,$F2,$05          ; flag=-1, dy=-14, dx=5
    FCB 2                ; End marker (path complete)

_PUZZLE_FAIL_SFX:
    ; SFX: puzzle_fail (hit)
    ; Duration: 150ms (7fr), Freq: 196Hz, Channel: 0
    FCB $6E         ; Frame 0 - flags (vol=14, noisevol=11, tone=Y, noise=Y)
    FCB $01, $C2  ; Tone period = 450 (big-endian)
    FCB $12         ; Noise period
    FCB $69         ; Frame 1 - flags (vol=9, noisevol=9, tone=Y, noise=Y)
    FCB $01, $DA  ; Tone period = 474 (big-endian)
    FCB $12         ; Noise period
    FCB $67         ; Frame 2 - flags (vol=7, noisevol=7, tone=Y, noise=Y)
    FCB $01, $F4  ; Tone period = 500 (big-endian)
    FCB $12         ; Noise period
    FCB $65         ; Frame 3 - flags (vol=5, noisevol=4, tone=Y, noise=Y)
    FCB $02, $11  ; Tone period = 529 (big-endian)
    FCB $12         ; Noise period
    FCB $63         ; Frame 4 - flags (vol=3, noisevol=2, tone=Y, noise=Y)
    FCB $02, $33  ; Tone period = 563 (big-endian)
    FCB $12         ; Noise period
    FCB $A2         ; Frame 5 - flags (vol=2, noisevol=0, tone=Y, noise=N)
    FCB $02, $58  ; Tone period = 600 (big-endian)
    FCB $A1         ; Frame 6 - flags (vol=1, noisevol=0, tone=Y, noise=N)
    FCB $02, $83  ; Tone period = 643 (big-endian)
    FCB $D0, $20    ; End of effect marker



; ================================================


; ===== BANK #02 (physical offset $08000) =====

    ORG $0000  ; Sequential bank model

;***************************************************************************
; ASSETS IN BANK #2 (9 assets)
;***************************************************************************

; Generated from locked_door.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 15
; X bounds: min=-30, max=30, width=60
; Center: (0, 0)

_LOCKED_DOOR_WIDTH EQU 60
_LOCKED_DOOR_HALF_WIDTH EQU 30
_LOCKED_DOOR_HEIGHT EQU 110
_LOCKED_DOOR_HALF_HEIGHT EQU 55
_LOCKED_DOOR_CENTER_X EQU 0
_LOCKED_DOOR_CENTER_Y EQU 0

_LOCKED_DOOR_VECTORS:  ; Main entry (header + 4 path(s))
    FDB 4               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _LOCKED_DOOR_PATH0        ; pointer to path 0
    FDB _LOCKED_DOOR_PATH1        ; pointer to path 1
    FDB _LOCKED_DOOR_PATH2        ; pointer to path 2
    FDB _LOCKED_DOOR_PATH3        ; pointer to path 3

_LOCKED_DOOR_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $F9,$FC,0,0        ; path0: header (y=-7, x=-4)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $F9,$FC,0,0        ; path1: header (y=-7, x=-4)
    FCB $FF,$06,$04          ; flag=-1, dy=6, dx=4
    FCB $FF,$FA,$04          ; flag=-1, dy=-6, dx=4
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH2:    ; Path 2
    FCB 90              ; path2: intensity
    FCB $15,$EA,0,0        ; path2: header (y=21, x=-22)
    FCB $FF,$00,$2C          ; flag=-1, dy=0, dx=44
    FCB $FF,$BC,$00          ; flag=-1, dy=-68, dx=0
    FCB $FF,$00,$D4          ; flag=-1, dy=0, dx=-44
    FCB $FF,$44,$00          ; flag=-1, dy=68, dx=0
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $C9,$E2,0,0        ; path3: header (y=-55, x=-30)
    FCB $FF,$00,$3C          ; flag=-1, dy=0, dx=60
    FCB $FF,$6E,$00          ; flag=-1, dy=110, dx=0
    FCB $FF,$00,$C4          ; flag=-1, dy=0, dx=-60
    FCB $FF,$92,$00          ; flag=-1, dy=-110, dx=0
    FCB 2                ; End marker (path complete)

; Generated from optics_pedestal.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 18
; X bounds: min=-16, max=16, width=32
; Center: (0, -6)

_OPTICS_PEDESTAL_WIDTH EQU 32
_OPTICS_PEDESTAL_HALF_WIDTH EQU 16
_OPTICS_PEDESTAL_HEIGHT EQU 68
_OPTICS_PEDESTAL_HALF_HEIGHT EQU 34
_OPTICS_PEDESTAL_CENTER_X EQU 0
_OPTICS_PEDESTAL_CENTER_Y EQU -6

_OPTICS_PEDESTAL_VECTORS:  ; Main entry (header + 4 path(s))
    FDB 4               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _OPTICS_PEDESTAL_PATH0        ; pointer to path 0
    FDB _OPTICS_PEDESTAL_PATH1        ; pointer to path 1
    FDB _OPTICS_PEDESTAL_PATH2        ; pointer to path 2
    FDB _OPTICS_PEDESTAL_PATH3        ; pointer to path 3

_OPTICS_PEDESTAL_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $1A,$F0,0,0        ; path0: header (y=26, x=-16)
    FCB $FF,$00,$20          ; flag=-1, dy=0, dx=32
    FCB $FF,$08,$00          ; flag=-1, dy=8, dx=0
    FCB $FF,$00,$E0          ; flag=-1, dy=0, dx=-32
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_OPTICS_PEDESTAL_PATH1:    ; Path 1
    FCB 90              ; path1: intensity
    FCB $EE,$F7,0,0        ; path1: header (y=-18, x=-9)
    FCB $FF,$2C,$00          ; flag=-1, dy=44, dx=0
    FCB $FF,$00,$12          ; flag=-1, dy=0, dx=18
    FCB $FF,$D4,$00          ; flag=-1, dy=-44, dx=0
    FCB 2                ; End marker (path complete)

_OPTICS_PEDESTAL_PATH2:    ; Path 2
    FCB 110              ; path2: intensity
    FCB $DE,$00,0,0        ; path2: header (y=-34, x=0)
    FCB $FF,$0A,$F6          ; flag=-1, dy=10, dx=-10
    FCB $FF,$00,$14          ; flag=-1, dy=0, dx=20
    FCB $FF,$F6,$F6          ; flag=-1, dy=-10, dx=-10
    FCB 2                ; End marker (path complete)

_OPTICS_PEDESTAL_PATH3:    ; Path 3
    FCB 100              ; path3: intensity
    FCB $E8,$F2,0,0        ; path3: header (y=-24, x=-14)
    FCB $FF,$00,$1C          ; flag=-1, dy=0, dx=28
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$E4          ; flag=-1, dy=0, dx=-28
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

; Generated from wall_compartment.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 16
; X bounds: min=-20, max=20, width=40
; Center: (0, -16)

_WALL_COMPARTMENT_WIDTH EQU 40
_WALL_COMPARTMENT_HALF_WIDTH EQU 20
_WALL_COMPARTMENT_HEIGHT EQU 43
_WALL_COMPARTMENT_HALF_HEIGHT EQU 21
_WALL_COMPARTMENT_CENTER_X EQU 0
_WALL_COMPARTMENT_CENTER_Y EQU -16

_WALL_COMPARTMENT_VECTORS:  ; Main entry (header + 4 path(s))
    FDB 4               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _WALL_COMPARTMENT_PATH0        ; pointer to path 0
    FDB _WALL_COMPARTMENT_PATH1        ; pointer to path 1
    FDB _WALL_COMPARTMENT_PATH2        ; pointer to path 2
    FDB _WALL_COMPARTMENT_PATH3        ; pointer to path 3

_WALL_COMPARTMENT_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $01,$04,0,0        ; path0: header (y=1, x=4)
    FCB $FF,$03,$FC          ; flag=-1, dy=3, dx=-4
    FCB $FF,$FD,$FC          ; flag=-1, dy=-3, dx=-4
    FCB $FF,$FD,$04          ; flag=-1, dy=-3, dx=4
    FCB $FF,$03,$04          ; flag=-1, dy=3, dx=4
    FCB 2                ; End marker (path complete)

_WALL_COMPARTMENT_PATH1:    ; Path 1
    FCB 120              ; path1: intensity
    FCB $FA,$00,0,0        ; path1: header (y=-6, x=0)
    FCB $FF,$07,$F6          ; flag=-1, dy=7, dx=-10
    FCB $FF,$07,$0A          ; flag=-1, dy=7, dx=10
    FCB $FF,$F9,$0A          ; flag=-1, dy=-7, dx=10
    FCB $FF,$F9,$F6          ; flag=-1, dy=-7, dx=-10
    FCB 2                ; End marker (path complete)

_WALL_COMPARTMENT_PATH2:    ; Path 2
    FCB 80              ; path2: intensity
    FCB $EA,$14,0,0        ; path2: header (y=-22, x=20)
    FCB $FF,$00,$D8          ; flag=-1, dy=0, dx=-40
    FCB $FF,$0D,$00          ; flag=-1, dy=13, dx=0
    FCB 2                ; End marker (path complete)

_WALL_COMPARTMENT_PATH3:    ; Path 3
    FCB 90              ; path3: intensity
    FCB $F7,$EC,0,0        ; path3: header (y=-9, x=-20)
    FCB $FF,$00,$28          ; flag=-1, dy=0, dx=40
    FCB $FF,$1E,$00          ; flag=-1, dy=30, dx=0
    FCB $FF,$00,$D8          ; flag=-1, dy=0, dx=-40
    FCB $FF,$E2,$00          ; flag=-1, dy=-30, dx=0
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
    FDB -96  ; scrollLimit left (camera left cannot go below this)
    FDB 575  ; scrollLimit right (camera right cannot exceed this)
    FDB 127  ; scrollLimit top
    FDB -128  ; scrollLimit bottom
    FCB 0  ; enemy_count
    FDB 0  ; enemy_instances_ptr (0 if none)
    FDB 0  ; groundBottomOffset (floor surface offset from screen bottom)
    FCB 1    ; +34 screen_count
    FDB _OPTICS_LAB_BG_SCREENS  ; +35 BG screens index
    FDB _OPTICS_LAB_GP_SCREENS  ; +37 GP screens index
    FDB _OPTICS_LAB_FG_SCREENS  ; +39 FG screens index

_OPTICS_LAB_BG_OBJECTS:
_OPTICS_LAB_BG_OBJECTS_S0:

_OPTICS_LAB_GAMEPLAY_OBJECTS:
_OPTICS_LAB_GAMEPLAY_OBJECTS_S0:
; Object: obj_opt_lamp (enemy)
    FCB 1  ; type
    FDB 80  ; x
    FDB -5  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 1   ; vector_bank (ROM+16)
    FDB _LAMP_VECTORS  ; vector_ptr (ROM+17)
    FCB 22  ; half_width (1.00x, ROM+19)
    FCB 6  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_opt_pedestal (enemy)
    FCB 1  ; type
    FDB 250  ; x
    FDB -62  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 2   ; vector_bank (ROM+16)
    FDB _OPTICS_PEDESTAL_VECTORS  ; vector_ptr (ROM+17)
    FCB 16  ; half_width (1.00x, ROM+19)
    FCB 34  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)


_OPTICS_LAB_FG_OBJECTS:
_OPTICS_LAB_FG_OBJECTS_S0:

_OPTICS_LAB_BG_SCREENS:
    FCB 0  ; screen 0 count
    FDB _OPTICS_LAB_BG_OBJECTS_S0  ; screen 0 ptr

_OPTICS_LAB_GP_SCREENS:
    FCB 2  ; screen 0 count
    FDB _OPTICS_LAB_GAMEPLAY_OBJECTS_S0  ; screen 0 ptr

_OPTICS_LAB_FG_SCREENS:
    FCB 0  ; screen 0 count
    FDB _OPTICS_LAB_FG_OBJECTS_S0  ; screen 0 ptr

_OPTICS_LAB_ENEMY_COUNT EQU 0


; Generated from canvas.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 12
; X bounds: min=-30, max=30, width=60
; Center: (0, 0)

_CANVAS_WIDTH EQU 60
_CANVAS_HALF_WIDTH EQU 30
_CANVAS_HEIGHT EQU 44
_CANVAS_HALF_HEIGHT EQU 22
_CANVAS_CENTER_X EQU 0
_CANVAS_CENTER_Y EQU 0

_CANVAS_VECTORS:  ; Main entry (header + 4 path(s))
    FDB 4               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _CANVAS_PATH0        ; pointer to path 0
    FDB _CANVAS_PATH1        ; pointer to path 1
    FDB _CANVAS_PATH2        ; pointer to path 2
    FDB _CANVAS_PATH3        ; pointer to path 3

_CANVAS_PATH0:    ; Path 0
    FCB 90              ; path0: intensity
    FCB $F0,$E8,0,0        ; path0: header (y=-16, x=-24)
    FCB $FF,$00,$30          ; flag=-1, dy=0, dx=48
    FCB $FF,$20,$00          ; flag=-1, dy=32, dx=0
    FCB $FF,$00,$D0          ; flag=-1, dy=0, dx=-48
    FCB $FF,$E0,$00          ; flag=-1, dy=-32, dx=0
    FCB 2                ; End marker (path complete)

_CANVAS_PATH1:    ; Path 1
    FCB 60              ; path1: intensity
    FCB $10,$E8,0,0        ; path1: header (y=16, x=-24)
    FCB $FF,$E0,$30          ; flag=-1, dy=-32, dx=48
    FCB 2                ; End marker (path complete)

_CANVAS_PATH2:    ; Path 2
    FCB 60              ; path2: intensity
    FCB $10,$18,0,0        ; path2: header (y=16, x=24)
    FCB $FF,$E0,$D0          ; flag=-1, dy=-32, dx=-48
    FCB 2                ; End marker (path complete)

_CANVAS_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $EA,$E2,0,0        ; path3: header (y=-22, x=-30)
    FCB $FF,$00,$3C          ; flag=-1, dy=0, dx=60
    FCB $FF,$2C,$00          ; flag=-1, dy=44, dx=0
    FCB $FF,$00,$C4          ; flag=-1, dy=0, dx=-60
    FCB $FF,$D4,$00          ; flag=-1, dy=-44, dx=0
    FCB 2                ; End marker (path complete)

; Generated from platform_up.vec (Malban Draw_Sync_List format)
; Total paths: 5, points: 13
; X bounds: min=-38, max=38, width=76
; Center: (0, 15)

_PLATFORM_UP_WIDTH EQU 76
_PLATFORM_UP_HALF_WIDTH EQU 38
_PLATFORM_UP_HEIGHT EQU 46
_PLATFORM_UP_HALF_HEIGHT EQU 23
_PLATFORM_UP_CENTER_X EQU 0
_PLATFORM_UP_CENTER_Y EQU 15

_PLATFORM_UP_VECTORS:  ; Main entry (header + 5 path(s))
    FDB 5               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLATFORM_UP_PATH0        ; pointer to path 0
    FDB _PLATFORM_UP_PATH1        ; pointer to path 1
    FDB _PLATFORM_UP_PATH2        ; pointer to path 2
    FDB _PLATFORM_UP_PATH3        ; pointer to path 3
    FDB _PLATFORM_UP_PATH4        ; pointer to path 4

_PLATFORM_UP_PATH0:    ; Path 0
    FCB 85              ; path0: intensity
    FCB $F3,$F9,0,0        ; path0: header (y=-13, x=-7)
    FCB $FF,$24,$00          ; flag=-1, dy=36, dx=0
    FCB 2                ; End marker (path complete)

_PLATFORM_UP_PATH1:    ; Path 1
    FCB 90              ; path1: intensity
    FCB $17,$F4,0,0        ; path1: header (y=23, x=-12)
    FCB $FF,$00,$18          ; flag=-1, dy=0, dx=24
    FCB 2                ; End marker (path complete)

_PLATFORM_UP_PATH2:    ; Path 2
    FCB 85              ; path2: intensity
    FCB $17,$07,0,0        ; path2: header (y=23, x=7)
    FCB $FF,$DC,$00          ; flag=-1, dy=-36, dx=0
    FCB 2                ; End marker (path complete)

_PLATFORM_UP_PATH3:    ; Path 3
    FCB 75              ; path3: intensity
    FCB $EC,$23,0,0        ; path3: header (y=-20, x=35)
    FCB $FF,$00,$BA          ; flag=-1, dy=0, dx=-70
    FCB 2                ; End marker (path complete)

_PLATFORM_UP_PATH4:    ; Path 4
    FCB 100              ; path4: intensity
    FCB $E9,$DA,0,0        ; path4: header (y=-23, x=-38)
    FCB $FF,$00,$4C          ; flag=-1, dy=0, dx=76
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$B4          ; flag=-1, dy=0, dx=-76
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB 2                ; End marker (path complete)

; Generated from elisa_ghost.vec (Malban Draw_Sync_List format)
; Total paths: 3, points: 11
; X bounds: min=-10, max=10, width=20
; Center: (0, -2)

_ELISA_GHOST_WIDTH EQU 20
_ELISA_GHOST_HALF_WIDTH EQU 10
_ELISA_GHOST_HEIGHT EQU 34
_ELISA_GHOST_HALF_HEIGHT EQU 17
_ELISA_GHOST_CENTER_X EQU 0
_ELISA_GHOST_CENTER_Y EQU -2

_ELISA_GHOST_VECTORS:  ; Main entry (header + 3 path(s))
    FDB 3               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _ELISA_GHOST_PATH0        ; pointer to path 0
    FDB _ELISA_GHOST_PATH1        ; pointer to path 1
    FDB _ELISA_GHOST_PATH2        ; pointer to path 2

_ELISA_GHOST_PATH0:    ; Path 0
    FCB 90              ; path0: intensity
    FCB $02,$F6,0,0        ; path0: header (y=2, x=-10)
    FCB $FF,$F3,$04          ; flag=-1, dy=-13, dx=4
    FCB $FF,$03,$0A          ; flag=-1, dy=3, dx=10
    FCB $FF,$0C,$06          ; flag=-1, dy=12, dx=6
    FCB $FF,$0A,$FD          ; flag=-1, dy=10, dx=-3
    FCB $FF,$03,$F9          ; flag=-1, dy=3, dx=-7
    FCB $FF,$FD,$F9          ; flag=-1, dy=-3, dx=-7
    FCB $FF,$F4,$FD          ; flag=-1, dy=-12, dx=-3
    FCB 2                ; End marker (path complete)

_ELISA_GHOST_PATH1:    ; Path 1
    FCB 65              ; path1: intensity
    FCB $F8,$04,0,0        ; path1: header (y=-8, x=4)
    FCB $FF,$F9,$03          ; flag=-1, dy=-7, dx=3
    FCB 2                ; End marker (path complete)

_ELISA_GHOST_PATH2:    ; Path 2
    FCB 65              ; path2: intensity
    FCB $EF,$FC,0,0        ; path2: header (y=-17, x=-4)
    FCB $FF,$06,$FE          ; flag=-1, dy=6, dx=-2
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
    FCB $A9         ; Frame 5 - flags (vol=9, noisevol=0, tone=Y, noise=N)
    FCB $00, $32  ; Tone period = 50 (big-endian)
    FCB $A7         ; Frame 6 - flags (vol=7, noisevol=0, tone=Y, noise=N)
    FCB $00, $32  ; Tone period = 50 (big-endian)
    FCB $A5         ; Frame 7 - flags (vol=5, noisevol=0, tone=Y, noise=N)
    FCB $00, $32  ; Tone period = 50 (big-endian)
    FCB $A3         ; Frame 8 - flags (vol=3, noisevol=0, tone=Y, noise=N)
    FCB $00, $64  ; Tone period = 100 (big-endian)
    FCB $A1         ; Frame 9 - flags (vol=1, noisevol=0, tone=Y, noise=N)
    FCB $00, $64  ; Tone period = 100 (big-endian)
    FCB $D0, $20    ; End of effect marker


; Generated from floor.vec (Malban Draw_Sync_List format)
; Total paths: 12, points: 15
; X bounds: min=-122, max=118, width=240
; Center: (-2, -6)

_FLOOR_WIDTH EQU 240
_FLOOR_HALF_WIDTH EQU 120
_FLOOR_HEIGHT EQU 2
_FLOOR_HALF_HEIGHT EQU 1
_FLOOR_CENTER_X EQU -2
_FLOOR_CENTER_Y EQU -6

_FLOOR_VECTORS:  ; Main entry (header + 3 path(s))
    FDB 3               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _FLOOR_PATH0        ; pointer to path 0
    FDB _FLOOR_PATH1        ; pointer to path 1
    FDB _FLOOR_PATH2        ; pointer to path 2

_FLOOR_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FF,$CE,0,0        ; path0: header (y=-1, x=-50)
    FCB $FF,$01,$4D          ; flag=-1, dy=1, dx=77
    FCB 2                ; End marker (path complete)

_FLOOR_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $00,$20,0,0        ; path1: header (y=0, x=32)
    FCB $FF,$00,$58          ; flag=-1, dy=0, dx=88
    FCB 2                ; End marker (path complete)

_FLOOR_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $FF,$CB,0,0        ; path2: header (y=-1, x=-53)
    FCB $FF,$00,$BD          ; flag=-1, dy=0, dx=-67
    FCB 2                ; End marker (path complete)


; ================================================


; ===== BANK #03 (physical offset $0C000) =====
    ORG $4000  ; Fixed bank window (runtime helpers + interrupt vectors)


VECTOR_BANK_TABLE:
    FCB 2              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 2              ; Bank ID
    FCB 1              ; Bank ID
    FCB 2              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 2              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 2              ; Bank ID

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
;   1 = item_pickup (Bank #2)
;   2 = puzzle_fail (Bank #1)
;   3 = puzzle_success (Bank #1)

SFX_BANK_TABLE:
    FCB 1              ; Bank ID
    FCB 2              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID

SFX_ADDR_TABLE:
    FDB _DOOR_UNLOCK_SFX    ; door_unlock
    FDB _ITEM_PICKUP_SFX    ; item_pickup
    FDB _PUZZLE_FAIL_SFX    ; puzzle_fail
    FDB _PUZZLE_SUCCESS_SFX    ; puzzle_success

; Level Asset Index Mapping:
;   0 = anteroom (Bank #1)
;   1 = clockroom (Bank #1)
;   2 = conservatory (Bank #1)
;   3 = entrance (Bank #1)
;   4 = optics_lab (Bank #2)
;   5 = vault_corridor (Bank #1)
;   6 = weights_room (Bank #1)

LEVEL_BANK_TABLE:
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID
    FCB 2              ; Bank ID
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
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
    FCB 2              ; Bank ID
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
    FDB _LOCKED_DOOR_VECTORS    ; locked_door
    FDB _OPTICS_PEDESTAL_VECTORS    ; optics_pedestal
    FDB _WALL_COMPARTMENT_VECTORS    ; wall_compartment
    FDB _OPTICS_LAB_LEVEL    ; optics_lab
    FDB _CANVAS_VECTORS    ; canvas
    FDB _PLATFORM_UP_VECTORS    ; platform_up
    FDB _ELISA_GHOST_VECTORS    ; elisa_ghost
    FDB _ITEM_PICKUP_SFX    ; item_pickup
    FDB _FLOOR_VECTORS    ; floor
    FDB _CRYPT_LOGO_VECTORS    ; crypt_logo
    FDB _EXPLORATION_MUSIC    ; exploration
    FDB _INTRO_MUSIC    ; intro
    FDB _DOOR_LOCKED_VECTORS    ; door_locked
    FDB _PAINTING_VECTORS    ; painting
    FDB _CONSERVATORY_LEVEL    ; conservatory
    FDB _VAULT_CORRIDOR_LEVEL    ; vault_corridor
    FDB _VAULT_CORRIDOR_VECTORS    ; vault_corridor
    FDB _CONSERVATORY_VECTORS    ; conservatory
    FDB _CRYSTAL_APPRENTICE_VECTORS    ; crystal_apprentice
    FDB _HANS_AUTOMATA_VECTORS    ; hans_automata
    FDB _DESK_VECTORS    ; desk
    FDB _ANTEROOM_LEVEL    ; anteroom
    FDB _CLOCKROOM_LEVEL    ; clockroom
    FDB _ENTRANCE_LEVEL    ; entrance
    FDB _PLAYER_VECTORS    ; player
    FDB _PUZZLE_SUCCESS_SFX    ; puzzle_success
    FDB _ENTRANCE_ARC_VECTORS    ; entrance_arc
    FDB _WEIGHTS_ROOM_LEVEL    ; weights_room
    FDB _DOOR_UNLOCK_SFX    ; door_unlock
    FDB _LAMP_VECTORS    ; lamp
    FDB _PLATFORM_DOWN_VECTORS    ; platform_down
    FDB _CARETAKER_VECTORS    ; caretaker
    FDB _PUZZLE_FAIL_SFX    ; puzzle_fail

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

; === SHOW_LEVEL_RUNTIME ===
; Draw all level objects from all layers
; Input:  LEVEL_PTR = pointer to level header
; Layers: BG (ROM stride 21), GP (ROM stride 21), FG (ROM stride 21)
; ROM object layout (21 bytes, stride-21):
;   +0: type, +1-2: x(FDB), +3-4: y(FDB), +5-6: scale(FDB),
;   +7: rotation, +8: intensity, +9: velocity_x, +10: velocity_y,
;   +11: physics_flags, +12: collision_flags, +13: collision_size,
;   +14-15: spawn_delay(FDB), +16: vector_bank(FCB, $FF=null),
;   +17-18: vector_ptr(FDB), +19: half_width(FCB), +20: half_height(FCB)
; Each object: load intensity, x, y, vector_bank, vector_ptr, call SLR_DRAW_OBJECTS
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
    
    ; Re-read object counts from header (legacy: kept for any caller that reads RAM vars)
    LEAX 12,X        ; X points to counts (+12)
    LDB ,X+          ; B = bgCount
    STB >LEVEL_BG_COUNT
    LDB ,X+          ; B = gpCount
    STB >LEVEL_GP_COUNT
    LDB ,X+          ; B = fgCount
    STB >LEVEL_FG_COUNT
    
    ; ── PER-SCREEN VISIBLE RANGE ─────────────────────────────────────
    ; Compute top_screen, bot_screen — only iterate objects whose screen
    ; band overlaps the camera's ±128 Y window. For SnowBros (1 screen
    ; visible) this is normally 1 screen, occasionally 2 during scroll.
    LDX >LEVEL_PTR
    LDD 6,X          ; D = yMax
    STD >TMPPTR      ; cache yMax
    LDD >CAMERA_Y
    ADDD #128        ; D = top_y (camera_y + 128, higher Y = top of screen)
    PSHS D
    LDD >TMPPTR      ; yMax
    SUBD ,S++        ; D = yMax - top_y
    TSTA             ; sign byte
    BPL SLR_TOP_OK   ; positive → A is the screen idx (D / 256)
    CLRA             ; negative → clamp top_screen to 0
SLR_TOP_OK:
    STA >SLR_TOP_SCREEN  ; top_screen (separate from TMPVAL — survives per-object cull)
    LDD >CAMERA_Y
    SUBD #128        ; D = bot_y (camera_y - 128)
    PSHS D
    LDD >TMPPTR      ; yMax
    SUBD ,S++        ; D = yMax - bot_y
    TSTA
    BPL SLR_BOT_OK
    CLRA
SLR_BOT_OK:
    ; Clamp bot_screen to (LEVEL_SCREEN_COUNT - 1) max
    LDB >LEVEL_SCREEN_COUNT
    LBEQ SLR_DONE    ; no screens → nothing to draw
    DECB             ; B = max_idx = screen_count - 1
    STB >SLR_BOT_SCREEN  ; stash max_idx for compare
    CMPA >SLR_BOT_SCREEN ; A (bot_screen) vs max_idx
    BLS SLR_BOT_NOCLAMP
    LDA >SLR_BOT_SCREEN  ; clamp bot_screen = max_idx
SLR_BOT_NOCLAMP:
    STA >SLR_BOT_SCREEN  ; bot_screen
    
    ; === Draw Background Layer ===
SLR_BG_LAYER:
    LDD >LEVEL_BG_SCREENS_PTR
    STD >TMPPTR      ; TMPPTR = table base for this layer
    JSR SLR_DRAW_SCREEN_RANGE
    
    ; === Draw Gameplay Layer ===
SLR_GAMEPLAY:
    LDD >LEVEL_GP_SCREENS_PTR
    STD >TMPPTR
    JSR SLR_DRAW_SCREEN_RANGE
    
    ; === Draw Foreground Layer ===
SLR_FOREGROUND:
    LDD >LEVEL_FG_SCREENS_PTR
    STD >TMPPTR
    JSR SLR_DRAW_SCREEN_RANGE
    
SLR_DONE:
    ; MULTIBANK: Restore original bank
    PULS A              ; A = saved bank
    STA >CURRENT_ROM_BANK
    STA $DF00           ; Restore bank
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    PULS D,X,Y,U,PC  ; Restore and return
    
; === SLR_DRAW_SCREEN_RANGE — iterate screens in visible camera range ===
SLR_DRAW_SCREEN_RANGE:
    LDA >SLR_TOP_SCREEN  ; A = current screen idx (start at top)
SLR_SR_LOOP:
    CMPA >SLR_BOT_SCREEN
    BHI SLR_SR_DONE      ; current > bot → finished
    CMPA >LEVEL_SCREEN_COUNT
    BHS SLR_SR_DONE      ; defensive: don't index past table
    ; Compute &table[s] = TMPPTR + s*3
    PSHS A               ; save loop var
    LDB #3
    MUL                  ; D = s*3 (A=0 since s < 256/3, B = offset)
    LDX >TMPPTR          ; X = screens table base
    LEAX D,X             ; X = &table[s]
    LDB ,X               ; B = count for this screen
    BEQ SLR_SR_NEXT      ; empty screen → skip
    LDX 1,X              ; X = ptr to first object in this screen
    LDA #23              ; ROM object stride
    JSR SLR_DRAW_OBJECTS
SLR_SR_NEXT:
    PULS A
    INCA
    BRA SLR_SR_LOOP
SLR_SR_DONE:
    RTS
    
; === SLR_DRAW_OBJECTS - Draw N objects from a layer ===
; Input:  A = stride (21=ROM), B = count, X = objects ptr
; For ROM objects (stride=21, stride-21 format):
;   intensity at +8, y FDB at +3, x FDB at +1, half_width at +19
;   vector_bank at +16 ($FF=null), vector_ptr FDB at +17
; Camera: SUBD >CAMERA_X applied to world_x; objects outside i8 range are culled
SLR_DRAW_OBJECTS:
    PSHS A           ; Save stride on stack (A=stride)
SLR_OBJ_LOOP:
    TSTB
    LBEQ SLR_OBJ_DONE
    
    PSHS B           ; Save counter (LDD clobbers B)
    
    ; All layers use stride-21 ROM format — fall straight through
    
SLR_ROM_OFFSETS:
    ; === ROM object (stride=21, stride-21 format) ===
    ; Skip enemy spawn markers (type==1): drawn by DRAW_ENEMIES, not SHOW_LEVEL
    LDA ,X           ; type byte at ROM+0
    CMPA #1
    LBEQ SLR_OBJ_NEXT ; enemy marker: skip, handle via DRAW_ENEMIES
    CLR >MIRROR_X    ; DP=$D0, must use extended addressing
    CLR >MIRROR_Y
    LDA 8,X          ; intensity at ROM +8
    STA >DRAW_VEC_INTENSITY
    ; Apply CAMERA_Y: load world_y FDB at ROM +3, subtract CAMERA_Y, cull
    LDD 3,X          ; world_y FDB at ROM +3 (16-bit signed)
    SUBD >CAMERA_Y   ; screen_y = world_y - camera_y
    TSTA
    BEQ SLR_ROM_Y_ZERO
    INCA
    LBNE SLR_OBJ_NEXT    ; A not $FF: too far above
    ; A=$FF: visible if B >= 128 (i.e. >= -128 signed)
    CMPB #128
    BHS SLR_ROM_Y_VISIBLE
    LBRA SLR_OBJ_NEXT
SLR_ROM_Y_ZERO:
    ; A=0: visible if B <= 127
    CMPB #127
    BLS SLR_ROM_Y_VISIBLE
    LBRA SLR_OBJ_NEXT
SLR_ROM_Y_VISIBLE:
    STB >DRAW_VEC_Y  ; DP=$D0, must use extended addressing
    ; Load world_x (16-bit), subtract CAMERA_X, check visibility
    LDD 1,X          ; x FDB at ROM +1
    SUBD >CAMERA_X   ; screen_x = world_x - camera_x
    STD >TMPVAL
    ; Wide cull at ±(127+hw): partial-edge objects still render via SDCP.
    LDB 19,X         ; B = half_width (ROM+19)
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
    ; Stride-21: vector_bank at ROM+16 ($FF=null), vector_ptr FDB at ROM+17
    ; CRITICAL: read ALL level-bank data BEFORE switching to vector bank.
    LDA 16,X         ; A = vector_bank (LEVEL BANK ACTIVE)
    CMPA #$FF        ; $FF = null (no visual for this object)
    LBEQ SLR_OBJ_NEXT ; null bank → skip draw
    LDU 17,X         ; vector_ptr FDB at ROM+17 (STILL IN LEVEL BANK)
    LDA 6,X          ; scale_t1 at ROM+6 (STILL IN LEVEL BANK)
    STA >DRAW_T1_SCALED
    ; MULTIBANK: NOW switch to the vector's bank.
    ; U = vector address valid in that bank; level data fully read above.
    ; Level bank is restored in SLR_PATH_DONE after all paths are drawn.
    LDA 16,X         ; reload vector_bank (LDA 6,X clobbered A)
    STA >CURRENT_ROM_BANK
    STA $DF00        ; switch to vector bank
    
SLR_DRAW_VECTOR:
    PSHS X           ; Save object pointer
    TFR U,X          ; X = vector data pointer (header)
    
    ; Read path_count from vector header (FDB = 2 bytes, high byte ignored)
    LDD ,X++         ; D = path_count FDB; B = low byte = actual count, X now at pointer table
    
    ; DP is already $D0 (set by SHOW_LEVEL_RUNTIME at entry)
SLR_PATH_LOOP:
    TSTB
    BEQ SLR_PATH_DONE
    DECB
    PSHS B           ; Save decremented count
    LDU ,X++         ; U = path pointer, X advances to next entry
    PSHS X           ; Save pointer table position
    TFR U,X          ; X = actual path data
    LDA >DRAW_VEC_X_HI
    BEQ SLR_PATH_CHECK_POS
    INCA
    BNE SLR_PATH_USE_SDCP
    LDA >DRAW_VEC_X
    CMPA #$B0
    BHS SLR_PATH_USE_DSWM
    BRA SLR_PATH_USE_SDCP
SLR_PATH_CHECK_POS:
    LDA >DRAW_VEC_X
    CMPA #80
    BLS SLR_PATH_USE_DSWM
SLR_PATH_USE_SDCP:
    JSR SLR_DRAW_CLIPPED_PATH
    BRA SLR_PATH_AFTER
SLR_PATH_USE_DSWM:
    JSR Draw_Sync_List_At_With_Mirrors
SLR_PATH_AFTER:
    PULS X           ; Restore pointer table position
    PULS B           ; Restore count
    BRA SLR_PATH_LOOP
    
SLR_PATH_DONE:
    PULS X           ; Restore object pointer
    ; MULTIBANK: Restore level bank now that all vector paths are drawn.
    ; SLR_OBJ_NEXT needs the level bank active to advance X through level objects.
    LDA >LEVEL_BANK
    STA >CURRENT_ROM_BANK
    STA $DF00        ; switch back to level bank
    
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
    LEAX 23,X        ; Next FG object (ROM stride 23)
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
PRINT_TEXT_STR_84327:
    FCC "USE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2188049:
    FCC "GIVE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2209918:
    FCC "HANS"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2567303:
    FCC "TAKE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_64218094:
    FCC "CLOCK"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_65039267:
    FCC "DIARY"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_66059856:
    FCC "ELISA"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_100361836:
    FCC "intro"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3309214433:
    FCC "player"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_61386845752:
    FCC "CABINET"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_63819514689:
    FCC "EXAMINE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_72273926210:
    FCC "OIL CAN"
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

PRINT_TEXT_STR_2260861405892:
    FCC "PAINTING"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2264259943554:
    FCC "PEDESTAL"
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

PRINT_TEXT_STR_59006849725498:
    FCC "CARETAKER"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_61337815899504:
    FCC "EXIT DOOR"
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

PRINT_TEXT_STR_1789082557890417:
    FCC "APPRENTICE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1937924742238227:
    FCC "GEAR PANEL"
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

PRINT_TEXT_STR_2331653882236156:
    FCC "VAULT DOOR"
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

PRINT_TEXT_STR_57071759112686642:
    FCC "COMPARTMENT"
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

PRINT_TEXT_STR_65431604815861807:
    FCC "MUSIC SHELF"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_66746456558499436:
    FCC "OIL      W1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_66939517582935176:
    FCC "OPTICS DOOR"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_67802925852799259:
    FCC "PRISM    W1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_67802925895808570:
    FCC "PRISM MOUNT"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_69819576141689452:
    FCC "SARCOPHAGUS"
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

PRINT_TEXT_STR_15262964977784735399:
    FCC "WORKSHOP DOOR"
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

PRINT_TEXT_STR_17953374719443405528:
    FCC "CONSERV. DOOR"
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
    LDB >VAR_ARG0+1      ; B = msg_id (low byte)
    BEQ PRINT_MSG_SKIP  ; id=0 → nothing to print
    DECB                ; 0-based index (id starts at 1)
    LSLB               ; B = index * 2
    LSLB               ; B = index * 4
    LDX #PRINT_MSG_TABLE
    ABX                ; X = &table[index * 4]
    LDB ,X+            ; B = x (signed byte)
    SEX                ; D = sign-extended x
    STD >VAR_ARG0
    LDB ,X+            ; B = y (signed byte)
    SEX                ; D = sign-extended y
    STD >VAR_ARG1
    LDX ,X             ; X = string pointer
    STX >VAR_ARG2
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
TRAMP_CHECK_ENTRANCE_HOTSPOTS:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR CHECK_ENTRANCE_HOTSPOTS
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_ENTER_ROOM:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR ENTER_ROOM
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
TRAMP_CHECK_ANTEROOM_HOTSPOTS:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR CHECK_ANTEROOM_HOTSPOTS
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
TRAMP_CHECK_OPTICS_HOTSPOTS:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR CHECK_OPTICS_HOTSPOTS
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
TRAMP_CHECK_CONSERVATORY_HOTSPOTS:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR CHECK_CONSERVATORY_HOTSPOTS
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
TRAMP_PICKUP_ITEM:
    LDA CURRENT_ROM_BANK  ; save caller's bank
    PSHS A
    LDA #$00  ; switch to bank #0
    STA CURRENT_ROM_BANK
    STA $DF00
    JSR PICKUP_ITEM
    PULS A
    STA CURRENT_ROM_BANK  ; restore caller's bank
    STA $DF00
    RTS
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
