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
    FCC "CLOCKCPT"
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
    ; Initialize audio system variables to prevent random noise on startup
    CLR >SFX_ACTIVE         ; Mark SFX as inactive (0=off)
    LDD #$0000
    STD >SFX_PTR            ; Clear SFX pointer
    STA >PSG_MUSIC_BANK     ; Bank 0 for music (prevents garbage bank switch in emulator)
    CLR >PSG_IS_PLAYING     ; No music playing at startup
    CLR >PSG_DELAY_FRAMES   ; Clear delay counter
    STD >PSG_MUSIC_PTR      ; Clear music pointer (D is already 0)
    STD >PSG_MUSIC_START    ; Clear loop pointer
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
DRAW_VEC_X_HI        EQU $C880+$0C   ; Vector draw X high byte (16-bit screen_x) (1 bytes)
DRAW_VEC_X           EQU $C880+$0D   ; Vector draw X offset (1 bytes)
DRAW_VEC_Y           EQU $C880+$0E   ; Vector draw Y offset (1 bytes)
DRAW_VEC_INTENSITY   EQU $C880+$0F   ; Vector intensity override (0=use vector data) (1 bytes)
MIRROR_PAD           EQU $C880+$10   ; Safety padding to prevent MIRROR flag corruption (16 bytes)
MIRROR_X             EQU $C880+$20   ; X mirror flag (0=normal, 1=flip) (1 bytes)
MIRROR_Y             EQU $C880+$21   ; Y mirror flag (0=normal, 1=flip) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$22   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$2C   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$2E   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$30   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$31   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$32   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$34   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
LEVEL_PTR            EQU $C880+$36   ; Pointer to currently loaded level header (2 bytes)
LEVEL_WIDTH          EQU $C880+$38   ; Level width (legacy tile API) (1 bytes)
LEVEL_HEIGHT         EQU $C880+$39   ; Level height (legacy tile API) (1 bytes)
LEVEL_TILE_SIZE      EQU $C880+$3A   ; Tile size (legacy tile API) (1 bytes)
LEVEL_Y_IDX          EQU $C880+$3B   ; SHOW_LEVEL row counter (legacy) (1 bytes)
LEVEL_X_IDX          EQU $C880+$3C   ; SHOW_LEVEL column counter (legacy) (1 bytes)
LEVEL_TEMP           EQU $C880+$3D   ; SHOW_LEVEL temporary byte (legacy) (1 bytes)
LEVEL_BG_COUNT       EQU $C880+$3E   ; BG object count (1 bytes)
LEVEL_GP_COUNT       EQU $C880+$3F   ; GP object count (1 bytes)
LEVEL_FG_COUNT       EQU $C880+$40   ; FG object count (1 bytes)
CAMERA_X             EQU $C880+$41   ; Camera X scroll offset (16-bit signed world units) (2 bytes)
LEVEL_BG_ROM_PTR     EQU $C880+$43   ; BG layer ROM pointer (2 bytes)
LEVEL_GP_ROM_PTR     EQU $C880+$45   ; GP layer ROM pointer (2 bytes)
LEVEL_FG_ROM_PTR     EQU $C880+$47   ; FG layer ROM pointer (2 bytes)
LEVEL_GP_PTR         EQU $C880+$49   ; GP active pointer (RAM buffer after LOAD_LEVEL) (2 bytes)
SLR_CUR_X            EQU $C880+$4B   ; SHOW_LEVEL: tracked beam X for per-segment clipping (1 bytes)
LEVEL_GP_BUFFER      EQU $C880+$4C   ; GP objects RAM buffer (max 8 objects × 15 bytes) (120 bytes)
UGPC_OUTER_IDX       EQU $C880+$C4   ; GP-GP outer loop index (1 bytes)
UGPC_OUTER_MAX       EQU $C880+$C5   ; GP-GP outer loop max (count-1) (1 bytes)
UGPC_INNER_IDX       EQU $C880+$C6   ; GP-GP inner loop index (1 bytes)
UGPC_DX              EQU $C880+$C7   ; GP-GP |dx| (16-bit) (2 bytes)
UGPC_DIST            EQU $C880+$C9   ; GP-GP Manhattan distance (16-bit) (2 bytes)
UGFC_GP_IDX          EQU $C880+$CB   ; GP-FG outer loop GP index (1 bytes)
UGFC_FG_COUNT        EQU $C880+$CC   ; GP-FG inner loop FG count (1 bytes)
UGFC_DX              EQU $C880+$CD   ; GP-FG |dx| (1 bytes)
UGFC_DY              EQU $C880+$CE   ; GP-FG |dy| (1 bytes)
TEXT_SCALE_H         EQU $C880+$CF   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$D0   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
VAR_STATE_TITLE      EQU $C880+$D1   ; User variable: STATE_TITLE (2 bytes)
VAR_STATE_INTRO      EQU $C880+$D3   ; User variable: STATE_INTRO (2 bytes)
VAR_STATE_ROOM       EQU $C880+$D5   ; User variable: STATE_ROOM (2 bytes)
VAR_STATE_ENDING     EQU $C880+$D7   ; User variable: STATE_ENDING (2 bytes)
VAR_ROOM_ENTRANCE    EQU $C880+$D9   ; User variable: ROOM_ENTRANCE (2 bytes)
VAR_ROOM_CLOCKROOM   EQU $C880+$DB   ; User variable: ROOM_CLOCKROOM (2 bytes)
VAR_VERB_EXAMINE     EQU $C880+$DD   ; User variable: VERB_EXAMINE (2 bytes)
VAR_VERB_TAKE        EQU $C880+$DF   ; User variable: VERB_TAKE (2 bytes)
VAR_VERB_USE         EQU $C880+$E1   ; User variable: VERB_USE (2 bytes)
VAR_MUSIC_NONE       EQU $C880+$E3   ; User variable: MUSIC_NONE (2 bytes)
VAR_MUSIC_TITLE      EQU $C880+$E5   ; User variable: MUSIC_TITLE (2 bytes)
VAR_MUSIC_EXPLORATION EQU $C880+$E7   ; User variable: MUSIC_EXPLORATION (2 bytes)
VAR_ENT_HS_COUNT     EQU $C880+$E9   ; User variable: ENT_HS_COUNT (2 bytes)
VAR_ENT_HS_PAINTING  EQU $C880+$EB   ; User variable: ENT_HS_PAINTING (2 bytes)
VAR_ENT_HS_DOOR      EQU $C880+$ED   ; User variable: ENT_HS_DOOR (2 bytes)
VAR_ENT_HS_X         EQU $C880+$EF   ; User variable: ENT_HS_X (2 bytes)
VAR_ENT_HS_Y         EQU $C880+$F1   ; User variable: ENT_HS_Y (2 bytes)
VAR_ENT_HS_W         EQU $C880+$F3   ; User variable: ENT_HS_W (2 bytes)
VAR_ENT_HS_H         EQU $C880+$F5   ; User variable: ENT_HS_H (2 bytes)
VAR_SCREEN           EQU $C880+$F7   ; User variable: SCREEN (2 bytes)
VAR_BLINK_TIMER      EQU $C880+$F9   ; User variable: BLINK_TIMER (2 bytes)
VAR_BLINK_ON         EQU $C880+$FB   ; User variable: BLINK_ON (2 bytes)
VAR_INTRO_PAGE       EQU $C880+$FD   ; User variable: INTRO_PAGE (2 bytes)
VAR_CURRENT_ROOM     EQU $C880+$FF   ; User variable: CURRENT_ROOM (2 bytes)
VAR_PLAYER_X         EQU $C880+$101   ; User variable: PLAYER_X (2 bytes)
VAR_PLAYER_Y         EQU $C880+$103   ; User variable: PLAYER_Y (2 bytes)
VAR_SCROLL_X         EQU $C880+$105   ; User variable: SCROLL_X (2 bytes)
VAR_PLAYER_SPEED     EQU $C880+$107   ; User variable: PLAYER_SPEED (2 bytes)
VAR_CURRENT_VERB     EQU $C880+$109   ; User variable: CURRENT_VERB (2 bytes)
VAR_NEAR_HS          EQU $C880+$10B   ; User variable: NEAR_HS (2 bytes)
VAR_MSG_ID           EQU $C880+$10D   ; User variable: MSG_ID (2 bytes)
VAR_MSG_TIMER        EQU $C880+$10F   ; User variable: MSG_TIMER (2 bytes)
VAR_ROOM_EXIT        EQU $C880+$111   ; User variable: ROOM_EXIT (2 bytes)
VAR_FLAG_DATE_KNOWN  EQU $C880+$113   ; User variable: FLAG_DATE_KNOWN (2 bytes)
VAR_FLAG_TALLER_OPEN EQU $C880+$115   ; User variable: FLAG_TALLER_OPEN (2 bytes)
VAR_CURRENT_MUSIC    EQU $C880+$117   ; User variable: CURRENT_MUSIC (2 bytes)
VAR_PREV_BTN1        EQU $C880+$119   ; User variable: PREV_BTN1 (2 bytes)
VAR_PREV_BTN3        EQU $C880+$11B   ; User variable: PREV_BTN3 (2 bytes)
VAR_BTN1_FIRED       EQU $C880+$11D   ; User variable: BTN1_FIRED (2 bytes)
VAR_BTN3_FIRED       EQU $C880+$11F   ; User variable: BTN3_FIRED (2 bytes)
VAR_B1               EQU $C880+$121   ; User variable: B1 (2 bytes)
VAR_B3               EQU $C880+$123   ; User variable: B3 (2 bytes)
VAR_ROOM_ID          EQU $C880+$127   ; User variable: room_id (2 bytes)
VAR_ROOM_ID          EQU $C880+$127   ; User variable: ROOM_ID (2 bytes)
VAR_JOY_X            EQU $C880+$129   ; User variable: JOY_X (2 bytes)
VAR_DX               EQU $C880+$12B   ; User variable: DX (2 bytes)
VAR_DY               EQU $C880+$12D   ; User variable: DY (2 bytes)
VAR_HS               EQU $C880+$131   ; User variable: hs (2 bytes)
VAR_HS               EQU $C880+$131   ; User variable: HS (2 bytes)
VAR_SCREEN_X         EQU $C880+$133   ; User variable: SCREEN_X (2 bytes)
VAR_ARG0             EQU $CB80   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $CB82   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $CB84   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $CB86   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $CB88   ; Function argument 4 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $CB8A   ; Current ROM bank ID (multibank tracking) (1 bytes)
PSG_MUSIC_PTR        EQU $CBEB   ; PSG music data pointer (2 bytes)
PSG_MUSIC_START      EQU $CBED   ; PSG music start pointer (for loops) (2 bytes)
PSG_MUSIC_ACTIVE     EQU $CBEF   ; PSG music active flag (1 bytes)
PSG_IS_PLAYING       EQU $CBF0   ; PSG playing flag (1 bytes)
PSG_DELAY_FRAMES     EQU $CBF1   ; PSG frame delay counter (1 bytes)
PSG_MUSIC_BANK       EQU $CBF2   ; PSG music bank ID (for multibank) (1 bytes)
SFX_PTR              EQU $CBF3   ; SFX data pointer (2 bytes)
SFX_ACTIVE           EQU $CBF5   ; SFX active flag (1 bytes)

;***************************************************************************
; ARRAY DATA (ROM literals)
;***************************************************************************
; Arrays are stored in ROM and accessed via pointers
; At startup, main() initializes VAR_{name} to point to ARRAY_{name}_DATA

; Array literal for variable 'ENT_HS_X' (2 elements, 2 bytes each)
ARRAY_ENT_HS_X_DATA:
    FDB 260   ; Element 0
    FDB 738   ; Element 1

; Array literal for variable 'ENT_HS_Y' (2 elements, 2 bytes each)
ARRAY_ENT_HS_Y_DATA:
    FDB -98   ; Element 0
    FDB -88   ; Element 1

; Array literal for variable 'ENT_HS_W' (2 elements, 2 bytes each)
ARRAY_ENT_HS_W_DATA:
    FDB 25   ; Element 0
    FDB 40   ; Element 1

; Array literal for variable 'ENT_HS_H' (2 elements, 2 bytes each)
ARRAY_ENT_HS_H_DATA:
    FDB 35   ; Element 0
    FDB 45   ; Element 1


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
    LDD #0  ; const STATE_TITLE
    STD RESULT
    STD VAR_SCREEN
    LDD #0
    STD RESULT
    STD VAR_BLINK_TIMER
    LDD #0
    STD RESULT
    STD VAR_BLINK_ON
    LDD #0
    STD RESULT
    STD VAR_INTRO_PAGE
    LDD #0  ; const ROOM_ENTRANCE
    STD RESULT
    STD VAR_CURRENT_ROOM
    LDD #0
    STD RESULT
    STD VAR_PLAYER_X
    LDD #-115
    STD RESULT
    STD VAR_PLAYER_Y
    LDD #0
    STD RESULT
    STD VAR_SCROLL_X
    LDD #5
    STD RESULT
    STD VAR_PLAYER_SPEED
    LDD #0  ; const VERB_EXAMINE
    STD RESULT
    STD VAR_CURRENT_VERB
    LDD #-1
    STD RESULT
    STD VAR_NEAR_HS
    LDD #0
    STD RESULT
    STD VAR_MSG_ID
    LDD #0
    STD RESULT
    STD VAR_MSG_TIMER
    LDD #0
    STD RESULT
    STD VAR_ROOM_EXIT
    LDD #0
    STD RESULT
    STD VAR_FLAG_DATE_KNOWN
    LDD #0
    STD RESULT
    STD VAR_FLAG_TALLER_OPEN
    LDD #1  ; const MUSIC_TITLE
    STD RESULT
    STD VAR_CURRENT_MUSIC
    LDD #1
    STD RESULT
    STD VAR_PREV_BTN1
    LDD #1
    STD RESULT
    STD VAR_PREV_BTN3
    LDD #0
    STD RESULT
    STD VAR_BTN1_FIRED
    LDD #0
    STD RESULT
    STD VAR_BTN3_FIRED
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
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'entrance'
    LDX #_ENTRANCE_LEVEL          ; Pointer to level data in ROM
    JSR LOAD_LEVEL_RUNTIME
    ; PLAY_MUSIC("intro") - play music asset (index=1)
    LDX #_INTRO_MUSIC  ; Load music data pointer
    JSR PLAY_MUSIC_RUNTIME
    LDD #0
    STD RESULT

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access
    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)
    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access
    LDA $C811      ; Vec_Button_1_1 (transition bits, rising edge = debounce)
    ANDA #$01      ; Test bit 0 (Button 1)
    LBEQ .J1B1_0_OFF
    LDD #1
    LBRA .J1B1_0_END
.J1B1_0_OFF:
    LDD #0
.J1B1_0_END:
    STD RESULT
    LDD RESULT
    STD VAR_B1
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_BTN1_FIRED
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_B1
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
    LBEQ .LOGIC_0_FALSE
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_BTN1
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_0_FALSE
    LDD #1
    LBRA .LOGIC_0_END
.LOGIC_0_FALSE:
    LDD #0
.LOGIC_0_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_1
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_BTN1_FIRED
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_PREV_BTN1
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_B1
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_3_TRUE
    LDD #0
    LBRA .CMP_3_END
.CMP_3_TRUE:
    LDD #1
.CMP_3_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_3
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_PREV_BTN1
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LDA $C811      ; Vec_Button_1_1 (transition bits, rising edge = debounce)
    ANDA #$04      ; Test bit 2 (Button 3)
    LBEQ .J1B3_1_OFF
    LDD #1
    LBRA .J1B3_1_END
.J1B3_1_OFF:
    LDD #0
.J1B3_1_END:
    STD RESULT
    LDD RESULT
    STD VAR_B3
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_BTN3_FIRED
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_B3
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
    LBEQ .LOGIC_4_FALSE
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_PREV_BTN3
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
    LBEQ .LOGIC_4_FALSE
    LDD #1
    LBRA .LOGIC_4_END
.LOGIC_4_FALSE:
    LDD #0
.LOGIC_4_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_5
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_BTN3_FIRED
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_PREV_BTN3
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_B3
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
    LBEQ IF_NEXT_7
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_PREV_BTN3
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
    LDD #0  ; const STATE_TITLE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SCREEN
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
    LBEQ IF_NEXT_9
    JSR DRAW_TITLE
    LBRA IF_END_8
IF_NEXT_9:
    LDD #1  ; const STATE_INTRO
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SCREEN
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
    LBEQ IF_NEXT_10
    JSR DRAW_INTRO
    LBRA IF_END_8
IF_NEXT_10:
    LDD #2  ; const STATE_ROOM
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SCREEN
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_10_TRUE
    LDD #0
    LBRA .CMP_10_END
.CMP_10_TRUE:
    LDD #1
.CMP_10_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_11
    JSR UPDATE_ROOM
    JSR DRAW_ROOM
    LBRA IF_END_8
IF_NEXT_11:
    LDD #3  ; const STATE_ENDING
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SCREEN
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_11_TRUE
    LDD #0
    LBRA .CMP_11_END
.CMP_11_TRUE:
    LDD #1
.CMP_11_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_END_8
    JSR DRAW_ENDING
    LBRA IF_END_8
IF_END_8:
    ; META MUSIC_TIMER: catch up if game frame was slow
    LDA >$D00D              ; VIA_int_flags (extended addr, DP=$C8)
    BITA #$20               ; Bit 5 = T2 elapsed (>1 frame of user code)
    BEQ MUSIC_CATCHUP_SKIP  ; On time — skip extra tick
    JSR AUDIO_UPDATE        ; Catch-up tick: game was slow
MUSIC_CATCHUP_SKIP:
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX
    RTS

; Function: DRAW_TITLE
DRAW_TITLE:
    ; SET_INTENSITY: Set drawing intensity
    LDD #120
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: crypt_logo (index=1, 40 paths)
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
    LDX #_CRYPT_LOGO_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH7  ; Load path 7
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH8  ; Load path 8
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH9  ; Load path 9
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH10  ; Load path 10
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH11  ; Load path 11
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH12  ; Load path 12
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH13  ; Load path 13
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH14  ; Load path 14
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH15  ; Load path 15
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH16  ; Load path 16
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH17  ; Load path 17
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH18  ; Load path 18
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH19  ; Load path 19
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH20  ; Load path 20
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH21  ; Load path 21
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH22  ; Load path 22
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH23  ; Load path 23
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH24  ; Load path 24
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH25  ; Load path 25
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH26  ; Load path 26
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH27  ; Load path 27
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH28  ; Load path 28
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH29  ; Load path 29
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH30  ; Load path 30
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH31  ; Load path 31
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH32  ; Load path 32
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH33  ; Load path 33
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH34  ; Load path 34
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH35  ; Load path 35
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH36  ; Load path 36
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH37  ; Load path 37
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH38  ; Load path 38
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_CRYPT_LOGO_PATH39  ; Load path 39
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    LDD >VAR_BLINK_TIMER
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_BLINK_TIMER
    LDD #40
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BLINK_TIMER
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_12_TRUE
    LDD #0
    LBRA .CMP_12_END
.CMP_12_TRUE:
    LDD #1
.CMP_12_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_13
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_BLINK_TIMER
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BLINK_ON
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_13_TRUE
    LDD #0
    LBRA .CMP_13_END
.CMP_13_TRUE:
    LDD #1
.CMP_13_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_15
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_BLINK_ON
    LBRA IF_END_14
IF_NEXT_15:
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_BLINK_ON
IF_END_14:
    LBRA IF_END_12
IF_NEXT_13:
IF_END_12:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BLINK_ON
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_14_TRUE
    LDD #0
    LBRA .CMP_14_END
.CMP_14_TRUE:
    LDD #1
.CMP_14_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_17
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    LDD #7
    STD RESULT
    LDB RESULT+1    ; n = scale value (1-8)
    NEGB            ; B = -n -> TEXT_SCALE_H
    STB >TEXT_SCALE_H
    LDB RESULT+1    ; reload n
    ASLB            ; n*2
    ASLB            ; n*4
    ASLB            ; n*8
    ADDB RESULT+1   ; n*8 + n = n*9 -> TEXT_SCALE_W
    STB >TEXT_SCALE_W
    ; PRINT_TEXT: Print text at position
    LDD #-107
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-100
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2177760433760906132      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_16
IF_NEXT_17:
IF_END_16:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN1_FIRED
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_15_TRUE
    LDD #0
    LBRA .CMP_15_END
.CMP_15_TRUE:
    LDD #1
.CMP_15_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_19
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_INTRO_PAGE
    LDD #1  ; const STATE_INTRO
    STD RESULT
    LDD RESULT
    STD VAR_SCREEN
    LBRA IF_END_18
IF_NEXT_19:
IF_END_18:
    RTS

; Function: DRAW_INTRO
DRAW_INTRO:
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INTRO_PAGE
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_16_TRUE
    LDD #0
    LBRA .CMP_16_END
.CMP_16_TRUE:
    LDD #1
.CMP_16_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_21
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    LDD #7
    STD RESULT
    LDB RESULT+1    ; n = scale value (1-8)
    NEGB            ; B = -n -> TEXT_SCALE_H
    STB >TEXT_SCALE_H
    LDB RESULT+1    ; reload n
    ASLB            ; n*2
    ASLB            ; n*4
    ASLB            ; n*8
    ADDB RESULT+1   ; n*8 + n = n*9 -> TEXT_SCALE_W
    STB >TEXT_SCALE_W
    ; PRINT_TEXT: Print text at position
    LDD #-105
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #50
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_17850884399050856369      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #25
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_5426318097895719391      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #10
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_4088011977317884966      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-5
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_4406207116162196822      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-20
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_8774988741757873223      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-35
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_1723491705885603536      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #60
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-80
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_9120385760502433312      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_20
IF_NEXT_21:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INTRO_PAGE
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_17_TRUE
    LDD #0
    LBRA .CMP_17_END
.CMP_17_TRUE:
    LDD #1
.CMP_17_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_22
    LDD #7
    STD RESULT
    LDB RESULT+1    ; n = scale value (1-8)
    NEGB            ; B = -n -> TEXT_SCALE_H
    STB >TEXT_SCALE_H
    LDB RESULT+1    ; reload n
    ASLB            ; n*2
    ASLB            ; n*4
    ASLB            ; n*8
    ADDB RESULT+1   ; n*8 + n = n*9 -> TEXT_SCALE_W
    STB >TEXT_SCALE_W
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #50
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_3450013277136201656      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #25
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_6872332185365714620      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #10
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_75109439344046724      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-10
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_7315232135604509958      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-25
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_10933791426923319118      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-40
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_8014226008171103997      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #60
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-80
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_9120385760502433312      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_20
IF_NEXT_22:
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INTRO_PAGE
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_18_TRUE
    LDD #0
    LBRA .CMP_18_END
.CMP_18_TRUE:
    LDD #1
.CMP_18_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_END_20
    LDD #7
    STD RESULT
    LDB RESULT+1    ; n = scale value (1-8)
    NEGB            ; B = -n -> TEXT_SCALE_H
    STB >TEXT_SCALE_H
    LDB RESULT+1    ; reload n
    ASLB            ; n*2
    ASLB            ; n*4
    ASLB            ; n*8
    ADDB RESULT+1   ; n*8 + n = n*9 -> TEXT_SCALE_W
    STB >TEXT_SCALE_W
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #40
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_8026944039266549802      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #25
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_6139730876735760457      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #10
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_13107026394822308942      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #70
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-20
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_108981465518803784      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-35
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_16443595361531215430      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-50
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_12477029002870225325      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-65
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_663557968544316929      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #60
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-90
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_9120385760502433312      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_20
IF_END_20:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN1_FIRED
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_19_TRUE
    LDD #0
    LBRA .CMP_19_END
.CMP_19_TRUE:
    LDD #1
.CMP_19_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_24
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_INTRO_PAGE
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_20_TRUE
    LDD #0
    LBRA .CMP_20_END
.CMP_20_TRUE:
    LDD #1
.CMP_20_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_26
    LDD >VAR_INTRO_PAGE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_INTRO_PAGE
    LBRA IF_END_25
IF_NEXT_26:
    LDD #0  ; const ROOM_ENTRANCE
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    JSR ENTER_ROOM
    LDD #2  ; const STATE_ROOM
    STD RESULT
    LDD RESULT
    STD VAR_SCREEN
IF_END_25:
    LBRA IF_END_23
IF_NEXT_24:
IF_END_23:
    RTS

; Function: ENTER_ROOM
ENTER_ROOM:
    LDD >VAR_ARG0
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_ROOM
    LDD #-1
    STD RESULT
    LDD RESULT
    STD VAR_NEAR_HS
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_MSG_ID
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_MSG_TIMER
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_ROOM_EXIT
    LDD #0  ; const ROOM_ENTRANCE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_21_TRUE
    LDD #0
    LBRA .CMP_21_END
.CMP_21_TRUE:
    LDD #1
.CMP_21_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_28
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'entrance'
    LDX #_ENTRANCE_LEVEL          ; Pointer to level data in ROM
    JSR LOAD_LEVEL_RUNTIME
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_X
    LDD #-115
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_Y
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_SCROLL_X
    ; ===== SET_CAMERA_X builtin =====
    LDD #0
    STD RESULT
    LDD RESULT
    STD >CAMERA_X    ; Store 16-bit camera X scroll offset
    LDD #0
    STD RESULT
    LDD #2  ; const MUSIC_EXPLORATION
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_MUSIC
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBNE .CMP_22_TRUE
    LDD #0
    LBRA .CMP_22_END
.CMP_22_TRUE:
    LDD #1
.CMP_22_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_30
    ; PLAY_MUSIC("exploration") - play music asset (index=0)
    LDX #_EXPLORATION_MUSIC  ; Load music data pointer
    JSR PLAY_MUSIC_RUNTIME
    LDD #0
    STD RESULT
    LDD #2  ; const MUSIC_EXPLORATION
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_29
IF_NEXT_30:
IF_END_29:
    LBRA IF_END_27
IF_NEXT_28:
    LDD #1  ; const ROOM_CLOCKROOM
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_23_TRUE
    LDD #0
    LBRA .CMP_23_END
.CMP_23_TRUE:
    LDD #1
.CMP_23_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_END_27
    LDD #70
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_X
    LDD #-75
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_Y
    LDD #2  ; const MUSIC_EXPLORATION
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_MUSIC
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBNE .CMP_24_TRUE
    LDD #0
    LBRA .CMP_24_END
.CMP_24_TRUE:
    LDD #1
.CMP_24_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_32
    ; PLAY_MUSIC("exploration") - play music asset (index=0)
    LDX #_EXPLORATION_MUSIC  ; Load music data pointer
    JSR PLAY_MUSIC_RUNTIME
    LDD #0
    STD RESULT
    LDD #2  ; const MUSIC_EXPLORATION
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_MUSIC
    LBRA IF_END_31
IF_NEXT_32:
IF_END_31:
    LBRA IF_END_27
IF_END_27:
    RTS

; Function: UPDATE_ROOM
UPDATE_ROOM:
    LDD >VAR_NEAR_HS
    STD RESULT
    ; DEBUG_PRINT(NEAR_HS)
    LDD RESULT
    STA $C002
    STB $C000
    LDA #$FE
    STA $C001
    LDX #DEBUG_LABEL_NEAR_HS
    STX $C004
    BRA DEBUG_SKIP_0
DEBUG_LABEL_NEAR_HS:
    FCC "NEAR_HS"
    FCB $00
DEBUG_SKIP_0:
    LDD #0
    STD RESULT
    JSR J1X_BUILTIN
    STD RESULT
    LDD RESULT
    STD VAR_JOY_X
    LDD #30
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_25_TRUE
    LDD #0
    LBRA .CMP_25_END
.CMP_25_TRUE:
    LDD #1
.CMP_25_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_34
    LDD >VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_SPEED
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_X
    LBRA IF_END_33
IF_NEXT_34:
    LDD #-30
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLT .CMP_26_TRUE
    LDD #0
    LBRA .CMP_26_END
.CMP_26_TRUE:
    LDD #1
.CMP_26_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_END_33
    LDD >VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_PLAYER_SPEED
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDD RESULT
    STD VAR_PLAYER_X
    LBRA IF_END_33
IF_END_33:
    ; CLAMP: Clamp value to range [min, max]
    LDD >VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPPTR     ; Save value
    LDD #-90
    STD RESULT
    LDD RESULT
    STD TMPPTR+2   ; Save min
    LDD #780
    STD RESULT
    LDD RESULT
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
    LDD RESULT
    STD VAR_PLAYER_X
    ; CLAMP: Clamp value to range [min, max]
    LDD >VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPPTR     ; Save value
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPPTR+2   ; Save min
    LDD #670
    STD RESULT
    LDD RESULT
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
    LDD RESULT
    STD VAR_SCROLL_X
    ; ===== SET_CAMERA_X builtin =====
    LDD >VAR_SCROLL_X
    STD RESULT
    LDD RESULT
    STD >CAMERA_X    ; Store 16-bit camera X scroll offset
    LDD #0
    STD RESULT
    LDD #-1
    STD RESULT
    LDD RESULT
    STD VAR_NEAR_HS
    LDD >VAR_PLAYER_X
    STD RESULT
    ; DEBUG_PRINT(PLAYER_X)
    LDD RESULT
    STA $C002
    STB $C000
    LDA #$FE
    STA $C001
    LDX #DEBUG_LABEL_PLAYER_X
    STX $C004
    BRA DEBUG_SKIP_1
DEBUG_LABEL_PLAYER_X:
    FCC "PLAYER_X"
    FCB $00
DEBUG_SKIP_1:
    LDD #0
    STD RESULT
    LDD >VAR_CURRENT_ROOM
    STD RESULT
    ; DEBUG_PRINT(CURRENT_ROOM)
    LDD RESULT
    STA $C002
    STB $C000
    LDA #$FE
    STA $C001
    LDX #DEBUG_LABEL_CURRENT_ROOM
    STX $C004
    BRA DEBUG_SKIP_2
DEBUG_LABEL_CURRENT_ROOM:
    FCC "CURRENT_ROOM"
    FCB $00
DEBUG_SKIP_2:
    LDD #0
    STD RESULT
    LDD #0  ; const ROOM_ENTRANCE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_ROOM
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_27_TRUE
    LDD #0
    LBRA .CMP_27_END
.CMP_27_TRUE:
    LDD #1
.CMP_27_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_36
    JSR CHECK_ENTRANCE_HOTSPOTS
    LBRA IF_END_35
IF_NEXT_36:
IF_END_35:
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_28_TRUE
    LDD #0
    LBRA .CMP_28_END
.CMP_28_TRUE:
    LDD #1
.CMP_28_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_38
    LDD >VAR_MSG_TIMER
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
    STD VAR_MSG_TIMER
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_30_TRUE
    LDD #0
    LBRA .CMP_30_END
.CMP_30_TRUE:
    LDD #1
.CMP_30_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_29_FALSE
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ROOM_EXIT
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
    LBEQ .LOGIC_29_FALSE
    LDD #1
    LBRA .LOGIC_29_END
.LOGIC_29_FALSE:
    LDD #0
.LOGIC_29_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_40
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_ROOM_EXIT
    LDD #1  ; const ROOM_CLOCKROOM
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    JSR ENTER_ROOM
    LBRA IF_END_39
IF_NEXT_40:
IF_END_39:
    LBRA IF_END_37
IF_NEXT_38:
IF_END_37:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN3_FIRED
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
    LBEQ IF_NEXT_42
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
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
    LBEQ IF_NEXT_44
    LDD #2  ; const VERB_USE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
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
    LBEQ IF_NEXT_46
    LDD #0  ; const VERB_EXAMINE
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_VERB
    LBRA IF_END_45
IF_NEXT_46:
    LDD >VAR_CURRENT_VERB
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_CURRENT_VERB
IF_END_45:
    LBRA IF_END_43
IF_NEXT_44:
IF_END_43:
    LBRA IF_END_41
IF_NEXT_42:
IF_END_41:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN1_FIRED
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
    LBEQ IF_NEXT_48
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_36_TRUE
    LDD #0
    LBRA .CMP_36_END
.CMP_36_TRUE:
    LDD #1
.CMP_36_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_50
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_MSG_TIMER
    LBRA IF_END_49
IF_NEXT_50:
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_NEAR_HS
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_37_TRUE
    LDD #0
    LBRA .CMP_37_END
.CMP_37_TRUE:
    LDD #1
.CMP_37_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_END_49
    LDD #0  ; const ROOM_ENTRANCE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_ROOM
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
    LBEQ IF_NEXT_52
    LDD >VAR_NEAR_HS
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    JSR INTERACT_ENTRANCE
    LBRA IF_END_51
IF_NEXT_52:
IF_END_51:
    LBRA IF_END_49
IF_END_49:
    LBRA IF_END_47
IF_NEXT_48:
IF_END_47:
    RTS

; Function: CHECK_ENTRANCE_HOTSPOTS
CHECK_ENTRANCE_HOTSPOTS:
    LDD >VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_ENT_HS_X_DATA  ; Array base
    LDD #0
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDD RESULT
    STD VAR_DX
    LDD >VAR_PLAYER_Y
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_ENT_HS_Y_DATA  ; Array base
    LDD #0
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDD RESULT
    STD VAR_DY
    LDD >VAR_DX
    STD RESULT
    ; DEBUG_PRINT(DX)
    LDD RESULT
    STA $C002
    STB $C000
    LDA #$FE
    STA $C001
    LDX #DEBUG_LABEL_DX
    STX $C004
    BRA DEBUG_SKIP_3
DEBUG_LABEL_DX:
    FCC "DX"
    FCB $00
DEBUG_SKIP_3:
    LDD #0
    STD RESULT
    LDD >VAR_DY
    STD RESULT
    ; DEBUG_PRINT(DY)
    LDD RESULT
    STA $C002
    STB $C000
    LDA #$FE
    STA $C001
    LDX #DEBUG_LABEL_DY
    STX $C004
    BRA DEBUG_SKIP_4
DEBUG_LABEL_DY:
    FCC "DY"
    FCB $00
DEBUG_SKIP_4:
    LDD #0
    STD RESULT
    LDX #ARRAY_ENT_HS_W_DATA  ; Array base
    LDD #0
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DX
    STD RESULT
    LDD RESULT
    TSTA           ; Test sign bit
    BPL .ABS_2_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_2_POS:
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLE .CMP_40_TRUE
    LDD #0
    LBRA .CMP_40_END
.CMP_40_TRUE:
    LDD #1
.CMP_40_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_39_FALSE
    LDX #ARRAY_ENT_HS_H_DATA  ; Array base
    LDD #0
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DY
    STD RESULT
    LDD RESULT
    TSTA           ; Test sign bit
    BPL .ABS_3_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_3_POS:
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLE .CMP_41_TRUE
    LDD #0
    LBRA .CMP_41_END
.CMP_41_TRUE:
    LDD #1
.CMP_41_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_39_FALSE
    LDD #1
    LBRA .LOGIC_39_END
.LOGIC_39_FALSE:
    LDD #0
.LOGIC_39_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_54
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_NEAR_HS
    LBRA IF_END_53
IF_NEXT_54:
IF_END_53:
    LDD >VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_ENT_HS_X_DATA  ; Array base
    LDD #1
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDD RESULT
    STD VAR_DX
    LDD >VAR_PLAYER_Y
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDX #ARRAY_ENT_HS_Y_DATA  ; Array base
    LDD #1
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDD RESULT
    STD VAR_DY
    LDX #ARRAY_ENT_HS_W_DATA  ; Array base
    LDD #1
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DX
    STD RESULT
    LDD RESULT
    TSTA           ; Test sign bit
    BPL .ABS_4_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_4_POS:
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLE .CMP_43_TRUE
    LDD #0
    LBRA .CMP_43_END
.CMP_43_TRUE:
    LDD #1
.CMP_43_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_42_FALSE
    LDX #ARRAY_ENT_HS_H_DATA  ; Array base
    LDD #1
    STD RESULT
    LDD RESULT  ; Index value
    STD TMPPTR  ; Save index to TMPPTR (safe from TMPVAL overwrites)
    LDD TMPPTR  ; Load index
    ASLB        ; Multiply by 2 (16-bit elements)
    ROLA
    LEAX D,X    ; X = base + (index * element_size)
    LDD ,X      ; Load 16-bit value
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    ; ABS: Absolute value
    LDD >VAR_DY
    STD RESULT
    LDD RESULT
    TSTA           ; Test sign bit
    BPL .ABS_5_POS   ; Branch if positive
    COMA           ; Complement A
    COMB           ; Complement B
    ADDD #1        ; Add 1 for two's complement
.ABS_5_POS:
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBLE .CMP_44_TRUE
    LDD #0
    LBRA .CMP_44_END
.CMP_44_TRUE:
    LDD #1
.CMP_44_END:
    STD RESULT
    LDD RESULT
    LBEQ .LOGIC_42_FALSE
    LDD #1
    LBRA .LOGIC_42_END
.LOGIC_42_FALSE:
    LDD #0
.LOGIC_42_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_56
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_NEAR_HS
    LBRA IF_END_55
IF_NEXT_56:
IF_END_55:
    RTS

; Function: INTERACT_ENTRANCE
INTERACT_ENTRANCE:
    LDD #0  ; const ENT_HS_PAINTING
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
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
    LBEQ IF_NEXT_58
    LDD #0  ; const VERB_EXAMINE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
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
    LBEQ IF_NEXT_60
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_FLAG_DATE_KNOWN
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_MSG_ID
    LDD #160
    STD RESULT
    LDD RESULT
    STD VAR_MSG_TIMER
    LBRA IF_END_59
IF_NEXT_60:
    LDD #1  ; const VERB_TAKE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
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
    LBEQ IF_NEXT_61
    LDD #5
    STD RESULT
    LDD RESULT
    STD VAR_MSG_ID
    LDD #100
    STD RESULT
    LDD RESULT
    STD VAR_MSG_TIMER
    LBRA IF_END_59
IF_NEXT_61:
    LDD #2  ; const VERB_USE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_48_TRUE
    LDD #0
    LBRA .CMP_48_END
.CMP_48_TRUE:
    LDD #1
.CMP_48_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_END_59
    LDD #5
    STD RESULT
    LDD RESULT
    STD VAR_MSG_ID
    LDD #100
    STD RESULT
    LDD RESULT
    STD VAR_MSG_TIMER
    LBRA IF_END_59
IF_END_59:
    LBRA IF_END_57
IF_NEXT_58:
    LDD #1  ; const ENT_HS_DOOR
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_ARG0
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
    LBEQ IF_END_57
    LDD #0  ; const VERB_EXAMINE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_50_TRUE
    LDD #0
    LBRA .CMP_50_END
.CMP_50_TRUE:
    LDD #1
.CMP_50_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_63
    LDD #2
    STD RESULT
    LDD RESULT
    STD VAR_MSG_ID
    LDD #120
    STD RESULT
    LDD RESULT
    STD VAR_MSG_TIMER
    LBRA IF_END_62
IF_NEXT_63:
    LDD #2  ; const VERB_USE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_51_TRUE
    LDD #0
    LBRA .CMP_51_END
.CMP_51_TRUE:
    LDD #1
.CMP_51_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_64
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAG_TALLER_OPEN
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
    LBEQ IF_NEXT_66
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_ROOM_EXIT
    LDD #60
    STD RESULT
    LDD RESULT
    STD VAR_MSG_TIMER
    LBRA IF_END_65
IF_NEXT_66:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_FLAG_DATE_KNOWN
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
    LBEQ IF_NEXT_67
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_FLAG_TALLER_OPEN
    LDD #4
    STD RESULT
    LDD RESULT
    STD VAR_MSG_ID
    LDD #200
    STD RESULT
    LDD RESULT
    STD VAR_MSG_TIMER
    LDD #1
    STD RESULT
    LDD RESULT
    STD VAR_ROOM_EXIT
    ; PLAY_SFX("door_unlock") - play SFX asset (index=0)
    LDX #_DOOR_UNLOCK_SFX  ; Load SFX data pointer
    JSR PLAY_SFX_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_65
IF_NEXT_67:
    LDD #3
    STD RESULT
    LDD RESULT
    STD VAR_MSG_ID
    LDD #120
    STD RESULT
    LDD RESULT
    STD VAR_MSG_TIMER
    ; PLAY_SFX("puzzle_fail") - play SFX asset (index=1)
    LDX #_PUZZLE_FAIL_SFX  ; Load SFX data pointer
    JSR PLAY_SFX_RUNTIME
    LDD #0
    STD RESULT
IF_END_65:
    LBRA IF_END_62
IF_NEXT_64:
    LDD #1  ; const VERB_TAKE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
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
    LBEQ IF_END_62
    LDD #5
    STD RESULT
    LDD RESULT
    STD VAR_MSG_ID
    LDD #100
    STD RESULT
    LDD RESULT
    STD VAR_MSG_TIMER
    LBRA IF_END_62
IF_END_62:
    LBRA IF_END_57
IF_END_57:
    RTS

; Function: DRAW_ROOM
DRAW_ROOM:
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
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
    LDD >VAR_PLAYER_X
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD >VAR_SCROLL_X
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand to TMPPTR
    LDD TMPVAL      ; Get left operand from TMPVAL
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDD RESULT
    STD VAR_SCREEN_X
    ; SET_INTENSITY: Set drawing intensity
    LDD #110
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: player (index=6, 7 paths)
    LDD >VAR_SCREEN_X
    STD RESULT
    LDA RESULT+1  ; X position (low byte)
    STA TMPPTR    ; Save X to temporary storage
    LDD >VAR_PLAYER_Y
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
    LDX #_PLAYER_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_PLAYER_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
    LDD #0
    STD RESULT
    JSR DRAW_BOTTOM_HUD
    RTS

; Function: DRAW_BOTTOM_HUD
DRAW_BOTTOM_HUD:
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_NEAR_HS
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGE .CMP_55_TRUE
    LDD #0
    LBRA .CMP_55_END
.CMP_55_TRUE:
    LDD #1
.CMP_55_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_69
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    LDD #0  ; const ROOM_ENTRANCE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_ROOM
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
    LBEQ IF_NEXT_71
    JSR DRAW_ENTRANCE_ACTION_LINE
    LBRA IF_END_70
IF_NEXT_71:
IF_END_70:
    LBRA IF_END_68
IF_NEXT_69:
    ; SET_INTENSITY: Set drawing intensity
    LDD #70
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    JSR DRAW_VERB_INDICATOR
IF_END_68:
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_TIMER
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_57_TRUE
    LDD #0
    LBRA .CMP_57_END
.CMP_57_TRUE:
    LDD #1
.CMP_57_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_73
    JSR DRAW_MESSAGE
    LBRA IF_END_72
IF_NEXT_73:
IF_END_72:
    RTS

; Function: DRAW_ENTRANCE_ACTION_LINE
DRAW_ENTRANCE_ACTION_LINE:
    LDD #0  ; const ENT_HS_PAINTING
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_NEAR_HS
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
    LBEQ IF_NEXT_75
    LDD #0  ; const VERB_EXAMINE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
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
    LBEQ IF_NEXT_77
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #127
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_3280973746071781571      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_76
IF_NEXT_77:
    LDD #1  ; const VERB_TAKE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
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
    LBEQ IF_NEXT_78
    ; PRINT_TEXT: Print text at position
    LDD #-56
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #127
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_12538318624203089469      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_76
IF_NEXT_78:
    LDD #2  ; const VERB_USE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
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
    LBEQ IF_END_76
    ; PRINT_TEXT: Print text at position
    LDD #-49
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #127
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2229603571317507421      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_76
IF_END_76:
    LBRA IF_END_74
IF_NEXT_75:
    LDD #1  ; const ENT_HS_DOOR
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_NEAR_HS
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
    LBEQ IF_END_74
    LDD #0  ; const VERB_EXAMINE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
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
    LBEQ IF_NEXT_80
    ; PRINT_TEXT: Print text at position
    LDD #-91
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #127
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_13773863620621678600      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_79
IF_NEXT_80:
    LDD #1  ; const VERB_TAKE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
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
    LBEQ IF_NEXT_81
    ; PRINT_TEXT: Print text at position
    LDD #-77
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #127
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_13572010117618904782      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_79
IF_NEXT_81:
    LDD #2  ; const VERB_USE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
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
    LBEQ IF_END_79
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #127
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_7290160099101033390      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_79
IF_END_79:
    LBRA IF_END_74
IF_END_74:
    RTS

; Function: DRAW_VERB_INDICATOR
DRAW_VERB_INDICATOR:
    LDD #0  ; const VERB_EXAMINE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
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
    LBEQ IF_NEXT_83
    ; PRINT_TEXT: Print text at position
    LDD #-42
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #127
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_63819514689      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_82
IF_NEXT_83:
    LDD #1  ; const VERB_TAKE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
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
    LBEQ IF_NEXT_84
    ; PRINT_TEXT: Print text at position
    LDD #-28
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #127
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2567303      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_82
IF_NEXT_84:
    LDD #2  ; const VERB_USE
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_CURRENT_VERB
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
    LBEQ IF_END_82
    ; PRINT_TEXT: Print text at position
    LDD #-21
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #127
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_84327      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_82
IF_END_82:
    RTS

; Function: DRAW_MESSAGE
DRAW_MESSAGE:
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_ID
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
    LBEQ IF_NEXT_86
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #114
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2861907936048358368      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #101
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_14476289867083772980      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; SET_INTENSITY: Set drawing intensity
    LDD #80
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #88
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_7298484243732525396      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_85
IF_NEXT_86:
    LDD #2
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_ID
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
    LBEQ IF_NEXT_87
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #114
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_5259861110007390611      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #101
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2466860800980120503      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_85
IF_NEXT_87:
    LDD #3
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_ID
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
    LBEQ IF_NEXT_88
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #114
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_9561915646494768437      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #101
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_15028810657913953998      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_85
IF_NEXT_88:
    LDD #4
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_ID
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_72_TRUE
    LDD #0
    LBRA .CMP_72_END
.CMP_72_TRUE:
    LDD #1
.CMP_72_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_89
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #114
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_9156937352888375391      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #101
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_14502866266724095954      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_85
IF_NEXT_89:
    LDD #5
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_MSG_ID
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBEQ .CMP_73_TRUE
    LDD #0
    LBRA .CMP_73_END
.CMP_73_TRUE:
    LDD #1
.CMP_73_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_END_85
    ; PRINT_TEXT: Print text at position
    LDD #-70
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #114
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_17897140833419752430      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_85
IF_END_85:
    RTS

; Function: DRAW_ENDING
DRAW_ENDING:
    ; SET_INTENSITY: Set drawing intensity
    LDD #100
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-42
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #10
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_9511871676577024489      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    RTS

;***************************************************************************
; EMBEDDED ASSETS (vectors, music, levels, SFX)
;***************************************************************************

; Generated from canvas.vec (Malban Draw_Sync_List format)
; Total paths: 32, points: 125
; X bounds: min=-23, max=23, width=46
; Center: (0, 0)

_CANVAS_WIDTH EQU 46
_CANVAS_HALF_WIDTH EQU 23
_CANVAS_CENTER_X EQU 0
_CANVAS_CENTER_Y EQU 0

_CANVAS_VECTORS:  ; Main entry (header + 32 path(s))
    FCB 32               ; path_count (runtime metadata)
    FDB _CANVAS_PATH0        ; pointer to path 0
    FDB _CANVAS_PATH1        ; pointer to path 1
    FDB _CANVAS_PATH2        ; pointer to path 2
    FDB _CANVAS_PATH3        ; pointer to path 3
    FDB _CANVAS_PATH4        ; pointer to path 4
    FDB _CANVAS_PATH5        ; pointer to path 5
    FDB _CANVAS_PATH6        ; pointer to path 6
    FDB _CANVAS_PATH7        ; pointer to path 7
    FDB _CANVAS_PATH8        ; pointer to path 8
    FDB _CANVAS_PATH9        ; pointer to path 9
    FDB _CANVAS_PATH10        ; pointer to path 10
    FDB _CANVAS_PATH11        ; pointer to path 11
    FDB _CANVAS_PATH12        ; pointer to path 12
    FDB _CANVAS_PATH13        ; pointer to path 13
    FDB _CANVAS_PATH14        ; pointer to path 14
    FDB _CANVAS_PATH15        ; pointer to path 15
    FDB _CANVAS_PATH16        ; pointer to path 16
    FDB _CANVAS_PATH17        ; pointer to path 17
    FDB _CANVAS_PATH18        ; pointer to path 18
    FDB _CANVAS_PATH19        ; pointer to path 19
    FDB _CANVAS_PATH20        ; pointer to path 20
    FDB _CANVAS_PATH21        ; pointer to path 21
    FDB _CANVAS_PATH22        ; pointer to path 22
    FDB _CANVAS_PATH23        ; pointer to path 23
    FDB _CANVAS_PATH24        ; pointer to path 24
    FDB _CANVAS_PATH25        ; pointer to path 25
    FDB _CANVAS_PATH26        ; pointer to path 26
    FDB _CANVAS_PATH27        ; pointer to path 27
    FDB _CANVAS_PATH28        ; pointer to path 28
    FDB _CANVAS_PATH29        ; pointer to path 29
    FDB _CANVAS_PATH30        ; pointer to path 30
    FDB _CANVAS_PATH31        ; pointer to path 31

_CANVAS_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $14,$E9,0,0        ; path0: header (y=20, x=-23, relative to center)
    FCB $FF,$00,$2E          ; flag=-1, dy=0, dx=46
    FCB $FF,$D8,$00          ; flag=-1, dy=-40, dx=0
    FCB $FF,$00,$D2          ; flag=-1, dy=0, dx=-46
    FCB $FF,$28,$00          ; flag=-1, dy=40, dx=0
    FCB 2                ; End marker (path complete)

_CANVAS_PATH1:    ; Path 1
    FCB 69              ; path1: intensity
    FCB $12,$EC,0,0        ; path1: header (y=18, x=-20, relative to center)
    FCB $FF,$00,$2A          ; flag=-1, dy=0, dx=42
    FCB $FF,$DC,$00          ; flag=-1, dy=-36, dx=0
    FCB $FF,$00,$D6          ; flag=-1, dy=0, dx=-42
    FCB $FF,$24,$00          ; flag=-1, dy=36, dx=0
    FCB 2                ; End marker (path complete)

_CANVAS_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $F4,$EE,0,0        ; path2: header (y=-12, x=-18, relative to center)
    FCB $FF,$01,$04          ; flag=-1, dy=1, dx=4
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$02,$04          ; flag=-1, dy=2, dx=4
    FCB 2                ; End marker (path complete)

_CANVAS_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $F8,$F8,0,0        ; path3: header (y=-8, x=-8, relative to center)
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$04,$01          ; flag=-1, dy=4, dx=1
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB 2                ; End marker (path complete)

_CANVAS_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $EE,$F9,0,0        ; path4: header (y=-18, x=-7, relative to center)
    FCB $FF,$05,$FD          ; flag=-1, dy=5, dx=-3
    FCB $FF,$04,$02          ; flag=-1, dy=4, dx=2
    FCB 2                ; End marker (path complete)

_CANVAS_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $F9,$F7,0,0        ; path5: header (y=-7, x=-9, relative to center)
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB $FF,$FF,$01          ; flag=-1, dy=-1, dx=1
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$01,$04          ; flag=-1, dy=1, dx=4
    FCB $FF,$FF,$01          ; flag=-1, dy=-1, dx=1
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB 2                ; End marker (path complete)

_CANVAS_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $FD,$02,0,0        ; path6: header (y=-3, x=2, relative to center)
    FCB $FF,$FD,$03          ; flag=-1, dy=-3, dx=3
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB 2                ; End marker (path complete)

_CANVAS_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $F6,$FC,0,0        ; path7: header (y=-10, x=-4, relative to center)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB $FF,$04,$01          ; flag=-1, dy=4, dx=1
    FCB 2                ; End marker (path complete)

_CANVAS_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $F5,$FF,0,0        ; path8: header (y=-11, x=-1, relative to center)
    FCB $FF,$01,$04          ; flag=-1, dy=1, dx=4
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_CANVAS_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $F6,$03,0,0        ; path9: header (y=-10, x=3, relative to center)
    FCB $FF,$FF,$01          ; flag=-1, dy=-1, dx=1
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB 2                ; End marker (path complete)

_CANVAS_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $F9,$09,0,0        ; path10: header (y=-7, x=9, relative to center)
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_CANVAS_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $FD,$FC,0,0        ; path11: header (y=-3, x=-4, relative to center)
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB 2                ; End marker (path complete)

_CANVAS_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $05,$FD,0,0        ; path12: header (y=5, x=-3, relative to center)
    FCB $FF,$FB,$FF          ; flag=-1, dy=-5, dx=-1
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$01,$00          ; flag=-1, dy=1, dx=0
    FCB 2                ; End marker (path complete)

_CANVAS_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $FB,$F8,0,0        ; path13: header (y=-5, x=-8, relative to center)
    FCB $FF,$01,$FF          ; flag=-1, dy=1, dx=-1
    FCB $FF,$03,$01          ; flag=-1, dy=3, dx=1
    FCB $FF,$04,$FE          ; flag=-1, dy=4, dx=-2
    FCB $FF,$02,$00          ; flag=-1, dy=2, dx=0
    FCB $FF,$FF,$01          ; flag=-1, dy=-1, dx=1
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_CANVAS_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $04,$F7,0,0        ; path14: header (y=4, x=-9, relative to center)
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$05,$06          ; flag=-1, dy=5, dx=6
    FCB $FF,$FF,$0B          ; flag=-1, dy=-1, dx=11
    FCB $FF,$FE,$05          ; flag=-1, dy=-2, dx=5
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_CANVAS_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $05,$F7,0,0        ; path15: header (y=5, x=-9, relative to center)
    FCB $FF,$04,$FF          ; flag=-1, dy=4, dx=-1
    FCB $FF,$05,$07          ; flag=-1, dy=5, dx=7
    FCB 2                ; End marker (path complete)

_CANVAS_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $07,$FA,0,0        ; path16: header (y=7, x=-6, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB 2                ; End marker (path complete)

_CANVAS_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $08,$FF,0,0        ; path17: header (y=8, x=-1, relative to center)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_CANVAS_PATH18:    ; Path 18
    FCB 127              ; path18: intensity
    FCB $08,$09,0,0        ; path18: header (y=8, x=9, relative to center)
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB 2                ; End marker (path complete)

_CANVAS_PATH19:    ; Path 19
    FCB 127              ; path19: intensity
    FCB $03,$0C,0,0        ; path19: header (y=3, x=12, relative to center)
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FF,$FD          ; flag=-1, dy=-1, dx=-3
    FCB $FF,$FD,$FF          ; flag=-1, dy=-3, dx=-1
    FCB 2                ; End marker (path complete)

_CANVAS_PATH20:    ; Path 20
    FCB 127              ; path20: intensity
    FCB $00,$02,0,0        ; path20: header (y=0, x=2, relative to center)
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_CANVAS_PATH21:    ; Path 21
    FCB 127              ; path21: intensity
    FCB $05,$0D,0,0        ; path21: header (y=5, x=13, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FF,$FD          ; flag=-1, dy=-1, dx=-3
    FCB 2                ; End marker (path complete)

_CANVAS_PATH22:    ; Path 22
    FCB 127              ; path22: intensity
    FCB $01,$0E,0,0        ; path22: header (y=1, x=14, relative to center)
    FCB $FF,$FD,$01          ; flag=-1, dy=-3, dx=1
    FCB $FF,$FF,$FF          ; flag=-1, dy=-1, dx=-1
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB 2                ; End marker (path complete)

_CANVAS_PATH23:    ; Path 23
    FCB 127              ; path23: intensity
    FCB $F3,$08,0,0        ; path23: header (y=-13, x=8, relative to center)
    FCB $FF,$04,$03          ; flag=-1, dy=4, dx=3
    FCB $FF,$04,$03          ; flag=-1, dy=4, dx=3
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB 2                ; End marker (path complete)

_CANVAS_PATH24:    ; Path 24
    FCB 127              ; path24: intensity
    FCB $EF,$03,0,0        ; path24: header (y=-17, x=3, relative to center)
    FCB $FF,$03,$04          ; flag=-1, dy=3, dx=4
    FCB $FF,$FD,$08          ; flag=-1, dy=-3, dx=8
    FCB 2                ; End marker (path complete)

_CANVAS_PATH25:    ; Path 25
    FCB 127              ; path25: intensity
    FCB $F0,$10,0,0        ; path25: header (y=-16, x=16, relative to center)
    FCB $FF,$07,$02          ; flag=-1, dy=7, dx=2
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$02,$FC          ; flag=-1, dy=2, dx=-4
    FCB 2                ; End marker (path complete)

_CANVAS_PATH26:    ; Path 26
    FCB 127              ; path26: intensity
    FCB $FA,$12,0,0        ; path26: header (y=-6, x=18, relative to center)
    FCB $FF,$FF,$04          ; flag=-1, dy=-1, dx=4
    FCB 2                ; End marker (path complete)

_CANVAS_PATH27:    ; Path 27
    FCB 127              ; path27: intensity
    FCB $05,$F8,0,0        ; path27: header (y=5, x=-8, relative to center)
    FCB $FF,$00,$05          ; flag=-1, dy=0, dx=5
    FCB 2                ; End marker (path complete)

_CANVAS_PATH28:    ; Path 28
    FCB 127              ; path28: intensity
    FCB $05,$01,0,0        ; path28: header (y=5, x=1, relative to center)
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_CANVAS_PATH29:    ; Path 29
    FCB 127              ; path29: intensity
    FCB $03,$F9,0,0        ; path29: header (y=3, x=-7, relative to center)
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$01,$02          ; flag=-1, dy=1, dx=2
    FCB 2                ; End marker (path complete)

_CANVAS_PATH30:    ; Path 30
    FCB 127              ; path30: intensity
    FCB $04,$F8,0,0        ; path30: header (y=4, x=-8, relative to center)
    FCB $FF,$01,$02          ; flag=-1, dy=1, dx=2
    FCB $FF,$FF,$03          ; flag=-1, dy=-1, dx=3
    FCB 2                ; End marker (path complete)

_CANVAS_PATH31:    ; Path 31
    FCB 127              ; path31: intensity
    FCB $04,$01,0,0        ; path31: header (y=4, x=1, relative to center)
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB $FF,$01,$03          ; flag=-1, dy=1, dx=3
    FCB 2                ; End marker (path complete)
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
; Generated from entrance.vec (Malban Draw_Sync_List format)
; Total paths: 49, points: 125
; X bounds: min=-51, max=51, width=102
; Center: (0, 0)

_ENTRANCE_WIDTH EQU 102
_ENTRANCE_HALF_WIDTH EQU 51
_ENTRANCE_CENTER_X EQU 0
_ENTRANCE_CENTER_Y EQU 0

_ENTRANCE_VECTORS:  ; Main entry (header + 49 path(s))
    FCB 49               ; path_count (runtime metadata)
    FDB _ENTRANCE_PATH0        ; pointer to path 0
    FDB _ENTRANCE_PATH1        ; pointer to path 1
    FDB _ENTRANCE_PATH2        ; pointer to path 2
    FDB _ENTRANCE_PATH3        ; pointer to path 3
    FDB _ENTRANCE_PATH4        ; pointer to path 4
    FDB _ENTRANCE_PATH5        ; pointer to path 5
    FDB _ENTRANCE_PATH6        ; pointer to path 6
    FDB _ENTRANCE_PATH7        ; pointer to path 7
    FDB _ENTRANCE_PATH8        ; pointer to path 8
    FDB _ENTRANCE_PATH9        ; pointer to path 9
    FDB _ENTRANCE_PATH10        ; pointer to path 10
    FDB _ENTRANCE_PATH11        ; pointer to path 11
    FDB _ENTRANCE_PATH12        ; pointer to path 12
    FDB _ENTRANCE_PATH13        ; pointer to path 13
    FDB _ENTRANCE_PATH14        ; pointer to path 14
    FDB _ENTRANCE_PATH15        ; pointer to path 15
    FDB _ENTRANCE_PATH16        ; pointer to path 16
    FDB _ENTRANCE_PATH17        ; pointer to path 17
    FDB _ENTRANCE_PATH18        ; pointer to path 18
    FDB _ENTRANCE_PATH19        ; pointer to path 19
    FDB _ENTRANCE_PATH20        ; pointer to path 20
    FDB _ENTRANCE_PATH21        ; pointer to path 21
    FDB _ENTRANCE_PATH22        ; pointer to path 22
    FDB _ENTRANCE_PATH23        ; pointer to path 23
    FDB _ENTRANCE_PATH24        ; pointer to path 24
    FDB _ENTRANCE_PATH25        ; pointer to path 25
    FDB _ENTRANCE_PATH26        ; pointer to path 26
    FDB _ENTRANCE_PATH27        ; pointer to path 27
    FDB _ENTRANCE_PATH28        ; pointer to path 28
    FDB _ENTRANCE_PATH29        ; pointer to path 29
    FDB _ENTRANCE_PATH30        ; pointer to path 30
    FDB _ENTRANCE_PATH31        ; pointer to path 31
    FDB _ENTRANCE_PATH32        ; pointer to path 32
    FDB _ENTRANCE_PATH33        ; pointer to path 33
    FDB _ENTRANCE_PATH34        ; pointer to path 34
    FDB _ENTRANCE_PATH35        ; pointer to path 35
    FDB _ENTRANCE_PATH36        ; pointer to path 36
    FDB _ENTRANCE_PATH37        ; pointer to path 37
    FDB _ENTRANCE_PATH38        ; pointer to path 38
    FDB _ENTRANCE_PATH39        ; pointer to path 39
    FDB _ENTRANCE_PATH40        ; pointer to path 40
    FDB _ENTRANCE_PATH41        ; pointer to path 41
    FDB _ENTRANCE_PATH42        ; pointer to path 42
    FDB _ENTRANCE_PATH43        ; pointer to path 43
    FDB _ENTRANCE_PATH44        ; pointer to path 44
    FDB _ENTRANCE_PATH45        ; pointer to path 45
    FDB _ENTRANCE_PATH46        ; pointer to path 46
    FDB _ENTRANCE_PATH47        ; pointer to path 47
    FDB _ENTRANCE_PATH48        ; pointer to path 48

_ENTRANCE_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $D5,$CD,0,0        ; path0: header (y=-43, x=-51, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$12          ; flag=-1, dy=0, dx=18
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$00,$EE          ; flag=-1, dy=0, dx=-18
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $DF,$DF,0,0        ; path1: header (y=-33, x=-33, relative to center)
    FCB $FF,$02,$04          ; flag=-1, dy=2, dx=4
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$FE,$FD          ; flag=-1, dy=-2, dx=-3
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $DF,$CD,0,0        ; path2: header (y=-33, x=-51, relative to center)
    FCB $FF,$02,$04          ; flag=-1, dy=2, dx=4
    FCB $FF,$00,$0D          ; flag=-1, dy=0, dx=13
    FCB $FF,$01,$03          ; flag=-1, dy=1, dx=3
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $E1,$D1,0,0        ; path3: header (y=-31, x=-47, relative to center)
    FCB $FF,$28,$00          ; flag=-1, dy=40, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $E0,$DE,0,0        ; path4: header (y=-32, x=-34, relative to center)
    FCB $FF,$29,$00          ; flag=-1, dy=41, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $E2,$E1,0,0        ; path5: header (y=-30, x=-31, relative to center)
    FCB $FF,$26,$00          ; flag=-1, dy=38, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $EB,$D1,0,0        ; path6: header (y=-21, x=-47, relative to center)
    FCB $FF,$00,$0D          ; flag=-1, dy=0, dx=13
    FCB $FF,$01,$03          ; flag=-1, dy=1, dx=3
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $FD,$D1,0,0        ; path7: header (y=-3, x=-47, relative to center)
    FCB $FF,$00,$0D          ; flag=-1, dy=0, dx=13
    FCB $FF,$01,$03          ; flag=-1, dy=1, dx=3
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $FD,$E1,0,0        ; path8: header (y=-3, x=-31, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $07,$E1,0,0        ; path9: header (y=7, x=-31, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $09,$CE,0,0        ; path10: header (y=9, x=-50, relative to center)
    FCB $FF,$00,$11          ; flag=-1, dy=0, dx=17
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$00,$EF          ; flag=-1, dy=0, dx=-17
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $0D,$DF,0,0        ; path11: header (y=13, x=-33, relative to center)
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $0D,$D1,0,0        ; path12: header (y=13, x=-47, relative to center)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$0B,$0A          ; flag=-1, dy=11, dx=10
    FCB $FF,$0B,$18          ; flag=-1, dy=11, dx=24
    FCB $FF,$03,$0D          ; flag=-1, dy=3, dx=13
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $20,$00,0,0        ; path13: header (y=32, x=0, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $0D,$DD,0,0        ; path14: header (y=13, x=-35, relative to center)
    FCB $FF,$0A,$07          ; flag=-1, dy=10, dx=7
    FCB $FF,$05,$09          ; flag=-1, dy=5, dx=9
    FCB $FF,$04,$0A          ; flag=-1, dy=4, dx=10
    FCB $FF,$02,$09          ; flag=-1, dy=2, dx=9
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $0D,$E0,0,0        ; path15: header (y=13, x=-32, relative to center)
    FCB $FF,$09,$07          ; flag=-1, dy=9, dx=7
    FCB $FF,$05,$09          ; flag=-1, dy=5, dx=9
    FCB $FF,$05,$10          ; flag=-1, dy=5, dx=16
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $20,$01,0,0        ; path16: header (y=32, x=1, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $27,$F3,0,0        ; path17: header (y=39, x=-13, relative to center)
    FCB $FF,$F9,$04          ; flag=-1, dy=-7, dx=4
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH18:    ; Path 18
    FCB 127              ; path18: intensity
    FCB $1B,$F0,0,0        ; path18: header (y=27, x=-16, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH19:    ; Path 19
    FCB 127              ; path19: intensity
    FCB $1C,$DC,0,0        ; path19: header (y=28, x=-36, relative to center)
    FCB $FF,$FB,$09          ; flag=-1, dy=-5, dx=9
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH20:    ; Path 20
    FCB 127              ; path20: intensity
    FCB $11,$E2,0,0        ; path20: header (y=17, x=-30, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH21:    ; Path 21
    FCB 127              ; path21: intensity
    FCB $21,$FD,0,0        ; path21: header (y=33, x=-3, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH22:    ; Path 22
    FCB 127              ; path22: intensity
    FCB $28,$07,0,0        ; path22: header (y=40, x=7, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH23:    ; Path 23
    FCB 127              ; path23: intensity
    FCB $D7,$E4,0,0        ; path23: header (y=-41, x=-28, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH24:    ; Path 24
    FCB 127              ; path24: intensity
    FCB $22,$00,0,0        ; path24: header (y=34, x=0, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH25:    ; Path 25
    FCB 127              ; path25: intensity
    FCB $D5,$33,0,0        ; path25: header (y=-43, x=51, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$EE          ; flag=-1, dy=0, dx=-18
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$00,$12          ; flag=-1, dy=0, dx=18
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH26:    ; Path 26
    FCB 127              ; path26: intensity
    FCB $DF,$21,0,0        ; path26: header (y=-33, x=33, relative to center)
    FCB $FF,$02,$FC          ; flag=-1, dy=2, dx=-4
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$FE,$03          ; flag=-1, dy=-2, dx=3
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH27:    ; Path 27
    FCB 127              ; path27: intensity
    FCB $DF,$33,0,0        ; path27: header (y=-33, x=51, relative to center)
    FCB $FF,$02,$FC          ; flag=-1, dy=2, dx=-4
    FCB $FF,$00,$F3          ; flag=-1, dy=0, dx=-13
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH28:    ; Path 28
    FCB 127              ; path28: intensity
    FCB $E1,$2F,0,0        ; path28: header (y=-31, x=47, relative to center)
    FCB $FF,$28,$00          ; flag=-1, dy=40, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH29:    ; Path 29
    FCB 127              ; path29: intensity
    FCB $E0,$22,0,0        ; path29: header (y=-32, x=34, relative to center)
    FCB $FF,$29,$00          ; flag=-1, dy=41, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH30:    ; Path 30
    FCB 127              ; path30: intensity
    FCB $E2,$1F,0,0        ; path30: header (y=-30, x=31, relative to center)
    FCB $FF,$26,$00          ; flag=-1, dy=38, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH31:    ; Path 31
    FCB 127              ; path31: intensity
    FCB $EB,$2F,0,0        ; path31: header (y=-21, x=47, relative to center)
    FCB $FF,$00,$F3          ; flag=-1, dy=0, dx=-13
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH32:    ; Path 32
    FCB 127              ; path32: intensity
    FCB $FD,$2F,0,0        ; path32: header (y=-3, x=47, relative to center)
    FCB $FF,$00,$F3          ; flag=-1, dy=0, dx=-13
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH33:    ; Path 33
    FCB 127              ; path33: intensity
    FCB $FD,$1F,0,0        ; path33: header (y=-3, x=31, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH34:    ; Path 34
    FCB 127              ; path34: intensity
    FCB $07,$1F,0,0        ; path34: header (y=7, x=31, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH35:    ; Path 35
    FCB 127              ; path35: intensity
    FCB $09,$32,0,0        ; path35: header (y=9, x=50, relative to center)
    FCB $FF,$00,$EF          ; flag=-1, dy=0, dx=-17
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$00,$11          ; flag=-1, dy=0, dx=17
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH36:    ; Path 36
    FCB 127              ; path36: intensity
    FCB $0D,$21,0,0        ; path36: header (y=13, x=33, relative to center)
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH37:    ; Path 37
    FCB 127              ; path37: intensity
    FCB $0D,$2F,0,0        ; path37: header (y=13, x=47, relative to center)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$0B,$F6          ; flag=-1, dy=11, dx=-10
    FCB $FF,$0B,$E8          ; flag=-1, dy=11, dx=-24
    FCB $FF,$03,$F3          ; flag=-1, dy=3, dx=-13
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH38:    ; Path 38
    FCB 127              ; path38: intensity
    FCB $20,$00,0,0        ; path38: header (y=32, x=0, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH39:    ; Path 39
    FCB 127              ; path39: intensity
    FCB $0D,$23,0,0        ; path39: header (y=13, x=35, relative to center)
    FCB $FF,$0A,$F9          ; flag=-1, dy=10, dx=-7
    FCB $FF,$05,$F7          ; flag=-1, dy=5, dx=-9
    FCB $FF,$04,$F6          ; flag=-1, dy=4, dx=-10
    FCB $FF,$02,$F7          ; flag=-1, dy=2, dx=-9
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH40:    ; Path 40
    FCB 127              ; path40: intensity
    FCB $0D,$20,0,0        ; path40: header (y=13, x=32, relative to center)
    FCB $FF,$09,$F9          ; flag=-1, dy=9, dx=-7
    FCB $FF,$05,$F7          ; flag=-1, dy=5, dx=-9
    FCB $FF,$05,$F0          ; flag=-1, dy=5, dx=-16
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH41:    ; Path 41
    FCB 127              ; path41: intensity
    FCB $20,$FF,0,0        ; path41: header (y=32, x=-1, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH42:    ; Path 42
    FCB 127              ; path42: intensity
    FCB $27,$0D,0,0        ; path42: header (y=39, x=13, relative to center)
    FCB $FF,$F9,$FC          ; flag=-1, dy=-7, dx=-4
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH43:    ; Path 43
    FCB 127              ; path43: intensity
    FCB $1B,$10,0,0        ; path43: header (y=27, x=16, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH44:    ; Path 44
    FCB 127              ; path44: intensity
    FCB $1C,$24,0,0        ; path44: header (y=28, x=36, relative to center)
    FCB $FF,$FB,$F7          ; flag=-1, dy=-5, dx=-9
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH45:    ; Path 45
    FCB 127              ; path45: intensity
    FCB $11,$1E,0,0        ; path45: header (y=17, x=30, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH46:    ; Path 46
    FCB 127              ; path46: intensity
    FCB $21,$03,0,0        ; path46: header (y=33, x=3, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH47:    ; Path 47
    FCB 127              ; path47: intensity
    FCB $D7,$1C,0,0        ; path47: header (y=-41, x=28, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_PATH48:    ; Path 48
    FCB 127              ; path48: intensity
    FCB $22,$00,0,0        ; path48: header (y=34, x=0, relative to center)
    FCB 2                ; End marker (path complete)
; Generated from entrance_arc.vec (Malban Draw_Sync_List format)
; Total paths: 49, points: 125
; X bounds: min=-51, max=51, width=102
; Center: (0, 0)

_ENTRANCE_ARC_WIDTH EQU 102
_ENTRANCE_ARC_HALF_WIDTH EQU 51
_ENTRANCE_ARC_CENTER_X EQU 0
_ENTRANCE_ARC_CENTER_Y EQU 0

_ENTRANCE_ARC_VECTORS:  ; Main entry (header + 49 path(s))
    FCB 49               ; path_count (runtime metadata)
    FDB _ENTRANCE_ARC_PATH0        ; pointer to path 0
    FDB _ENTRANCE_ARC_PATH1        ; pointer to path 1
    FDB _ENTRANCE_ARC_PATH2        ; pointer to path 2
    FDB _ENTRANCE_ARC_PATH3        ; pointer to path 3
    FDB _ENTRANCE_ARC_PATH4        ; pointer to path 4
    FDB _ENTRANCE_ARC_PATH5        ; pointer to path 5
    FDB _ENTRANCE_ARC_PATH6        ; pointer to path 6
    FDB _ENTRANCE_ARC_PATH7        ; pointer to path 7
    FDB _ENTRANCE_ARC_PATH8        ; pointer to path 8
    FDB _ENTRANCE_ARC_PATH9        ; pointer to path 9
    FDB _ENTRANCE_ARC_PATH10        ; pointer to path 10
    FDB _ENTRANCE_ARC_PATH11        ; pointer to path 11
    FDB _ENTRANCE_ARC_PATH12        ; pointer to path 12
    FDB _ENTRANCE_ARC_PATH13        ; pointer to path 13
    FDB _ENTRANCE_ARC_PATH14        ; pointer to path 14
    FDB _ENTRANCE_ARC_PATH15        ; pointer to path 15
    FDB _ENTRANCE_ARC_PATH16        ; pointer to path 16
    FDB _ENTRANCE_ARC_PATH17        ; pointer to path 17
    FDB _ENTRANCE_ARC_PATH18        ; pointer to path 18
    FDB _ENTRANCE_ARC_PATH19        ; pointer to path 19
    FDB _ENTRANCE_ARC_PATH20        ; pointer to path 20
    FDB _ENTRANCE_ARC_PATH21        ; pointer to path 21
    FDB _ENTRANCE_ARC_PATH22        ; pointer to path 22
    FDB _ENTRANCE_ARC_PATH23        ; pointer to path 23
    FDB _ENTRANCE_ARC_PATH24        ; pointer to path 24
    FDB _ENTRANCE_ARC_PATH25        ; pointer to path 25
    FDB _ENTRANCE_ARC_PATH26        ; pointer to path 26
    FDB _ENTRANCE_ARC_PATH27        ; pointer to path 27
    FDB _ENTRANCE_ARC_PATH28        ; pointer to path 28
    FDB _ENTRANCE_ARC_PATH29        ; pointer to path 29
    FDB _ENTRANCE_ARC_PATH30        ; pointer to path 30
    FDB _ENTRANCE_ARC_PATH31        ; pointer to path 31
    FDB _ENTRANCE_ARC_PATH32        ; pointer to path 32
    FDB _ENTRANCE_ARC_PATH33        ; pointer to path 33
    FDB _ENTRANCE_ARC_PATH34        ; pointer to path 34
    FDB _ENTRANCE_ARC_PATH35        ; pointer to path 35
    FDB _ENTRANCE_ARC_PATH36        ; pointer to path 36
    FDB _ENTRANCE_ARC_PATH37        ; pointer to path 37
    FDB _ENTRANCE_ARC_PATH38        ; pointer to path 38
    FDB _ENTRANCE_ARC_PATH39        ; pointer to path 39
    FDB _ENTRANCE_ARC_PATH40        ; pointer to path 40
    FDB _ENTRANCE_ARC_PATH41        ; pointer to path 41
    FDB _ENTRANCE_ARC_PATH42        ; pointer to path 42
    FDB _ENTRANCE_ARC_PATH43        ; pointer to path 43
    FDB _ENTRANCE_ARC_PATH44        ; pointer to path 44
    FDB _ENTRANCE_ARC_PATH45        ; pointer to path 45
    FDB _ENTRANCE_ARC_PATH46        ; pointer to path 46
    FDB _ENTRANCE_ARC_PATH47        ; pointer to path 47
    FDB _ENTRANCE_ARC_PATH48        ; pointer to path 48

_ENTRANCE_ARC_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $D5,$CD,0,0        ; path0: header (y=-43, x=-51, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$12          ; flag=-1, dy=0, dx=18
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$00,$EE          ; flag=-1, dy=0, dx=-18
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $DF,$DF,0,0        ; path1: header (y=-33, x=-33, relative to center)
    FCB $FF,$02,$04          ; flag=-1, dy=2, dx=4
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$FE,$FD          ; flag=-1, dy=-2, dx=-3
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $DF,$CD,0,0        ; path2: header (y=-33, x=-51, relative to center)
    FCB $FF,$02,$04          ; flag=-1, dy=2, dx=4
    FCB $FF,$00,$0D          ; flag=-1, dy=0, dx=13
    FCB $FF,$01,$03          ; flag=-1, dy=1, dx=3
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $E1,$D1,0,0        ; path3: header (y=-31, x=-47, relative to center)
    FCB $FF,$28,$00          ; flag=-1, dy=40, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $E0,$DE,0,0        ; path4: header (y=-32, x=-34, relative to center)
    FCB $FF,$29,$00          ; flag=-1, dy=41, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $E2,$E1,0,0        ; path5: header (y=-30, x=-31, relative to center)
    FCB $FF,$26,$00          ; flag=-1, dy=38, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $EB,$D1,0,0        ; path6: header (y=-21, x=-47, relative to center)
    FCB $FF,$00,$0D          ; flag=-1, dy=0, dx=13
    FCB $FF,$01,$03          ; flag=-1, dy=1, dx=3
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $FD,$D1,0,0        ; path7: header (y=-3, x=-47, relative to center)
    FCB $FF,$00,$0D          ; flag=-1, dy=0, dx=13
    FCB $FF,$01,$03          ; flag=-1, dy=1, dx=3
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $FD,$E1,0,0        ; path8: header (y=-3, x=-31, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $07,$E1,0,0        ; path9: header (y=7, x=-31, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $09,$CE,0,0        ; path10: header (y=9, x=-50, relative to center)
    FCB $FF,$00,$11          ; flag=-1, dy=0, dx=17
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$00,$EF          ; flag=-1, dy=0, dx=-17
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $0D,$DF,0,0        ; path11: header (y=13, x=-33, relative to center)
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $0D,$D1,0,0        ; path12: header (y=13, x=-47, relative to center)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$0B,$0A          ; flag=-1, dy=11, dx=10
    FCB $FF,$0B,$18          ; flag=-1, dy=11, dx=24
    FCB $FF,$03,$0D          ; flag=-1, dy=3, dx=13
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $20,$00,0,0        ; path13: header (y=32, x=0, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $0D,$DD,0,0        ; path14: header (y=13, x=-35, relative to center)
    FCB $FF,$0A,$07          ; flag=-1, dy=10, dx=7
    FCB $FF,$05,$09          ; flag=-1, dy=5, dx=9
    FCB $FF,$04,$0A          ; flag=-1, dy=4, dx=10
    FCB $FF,$02,$09          ; flag=-1, dy=2, dx=9
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $0D,$E0,0,0        ; path15: header (y=13, x=-32, relative to center)
    FCB $FF,$09,$07          ; flag=-1, dy=9, dx=7
    FCB $FF,$05,$09          ; flag=-1, dy=5, dx=9
    FCB $FF,$05,$10          ; flag=-1, dy=5, dx=16
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $20,$01,0,0        ; path16: header (y=32, x=1, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $27,$F3,0,0        ; path17: header (y=39, x=-13, relative to center)
    FCB $FF,$F9,$04          ; flag=-1, dy=-7, dx=4
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH18:    ; Path 18
    FCB 127              ; path18: intensity
    FCB $1B,$F0,0,0        ; path18: header (y=27, x=-16, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH19:    ; Path 19
    FCB 127              ; path19: intensity
    FCB $1C,$DC,0,0        ; path19: header (y=28, x=-36, relative to center)
    FCB $FF,$FB,$09          ; flag=-1, dy=-5, dx=9
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH20:    ; Path 20
    FCB 127              ; path20: intensity
    FCB $11,$E2,0,0        ; path20: header (y=17, x=-30, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH21:    ; Path 21
    FCB 127              ; path21: intensity
    FCB $21,$FD,0,0        ; path21: header (y=33, x=-3, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH22:    ; Path 22
    FCB 127              ; path22: intensity
    FCB $28,$07,0,0        ; path22: header (y=40, x=7, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH23:    ; Path 23
    FCB 127              ; path23: intensity
    FCB $D7,$E4,0,0        ; path23: header (y=-41, x=-28, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH24:    ; Path 24
    FCB 127              ; path24: intensity
    FCB $22,$00,0,0        ; path24: header (y=34, x=0, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH25:    ; Path 25
    FCB 127              ; path25: intensity
    FCB $D5,$33,0,0        ; path25: header (y=-43, x=51, relative to center)
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$EE          ; flag=-1, dy=0, dx=-18
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$00,$12          ; flag=-1, dy=0, dx=18
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH26:    ; Path 26
    FCB 127              ; path26: intensity
    FCB $DF,$21,0,0        ; path26: header (y=-33, x=33, relative to center)
    FCB $FF,$02,$FC          ; flag=-1, dy=2, dx=-4
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$FE,$03          ; flag=-1, dy=-2, dx=3
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH27:    ; Path 27
    FCB 127              ; path27: intensity
    FCB $DF,$33,0,0        ; path27: header (y=-33, x=51, relative to center)
    FCB $FF,$02,$FC          ; flag=-1, dy=2, dx=-4
    FCB $FF,$00,$F3          ; flag=-1, dy=0, dx=-13
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH28:    ; Path 28
    FCB 127              ; path28: intensity
    FCB $E1,$2F,0,0        ; path28: header (y=-31, x=47, relative to center)
    FCB $FF,$28,$00          ; flag=-1, dy=40, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH29:    ; Path 29
    FCB 127              ; path29: intensity
    FCB $E0,$22,0,0        ; path29: header (y=-32, x=34, relative to center)
    FCB $FF,$29,$00          ; flag=-1, dy=41, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH30:    ; Path 30
    FCB 127              ; path30: intensity
    FCB $E2,$1F,0,0        ; path30: header (y=-30, x=31, relative to center)
    FCB $FF,$26,$00          ; flag=-1, dy=38, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH31:    ; Path 31
    FCB 127              ; path31: intensity
    FCB $EB,$2F,0,0        ; path31: header (y=-21, x=47, relative to center)
    FCB $FF,$00,$F3          ; flag=-1, dy=0, dx=-13
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH32:    ; Path 32
    FCB 127              ; path32: intensity
    FCB $FD,$2F,0,0        ; path32: header (y=-3, x=47, relative to center)
    FCB $FF,$00,$F3          ; flag=-1, dy=0, dx=-13
    FCB $FF,$01,$FD          ; flag=-1, dy=1, dx=-3
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH33:    ; Path 33
    FCB 127              ; path33: intensity
    FCB $FD,$1F,0,0        ; path33: header (y=-3, x=31, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH34:    ; Path 34
    FCB 127              ; path34: intensity
    FCB $07,$1F,0,0        ; path34: header (y=7, x=31, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH35:    ; Path 35
    FCB 127              ; path35: intensity
    FCB $09,$32,0,0        ; path35: header (y=9, x=50, relative to center)
    FCB $FF,$00,$EF          ; flag=-1, dy=0, dx=-17
    FCB $FF,$00,$FC          ; flag=-1, dy=0, dx=-4
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$00,$11          ; flag=-1, dy=0, dx=17
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH36:    ; Path 36
    FCB 127              ; path36: intensity
    FCB $0D,$21,0,0        ; path36: header (y=13, x=33, relative to center)
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH37:    ; Path 37
    FCB 127              ; path37: intensity
    FCB $0D,$2F,0,0        ; path37: header (y=13, x=47, relative to center)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$0B,$F6          ; flag=-1, dy=11, dx=-10
    FCB $FF,$0B,$E8          ; flag=-1, dy=11, dx=-24
    FCB $FF,$03,$F3          ; flag=-1, dy=3, dx=-13
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH38:    ; Path 38
    FCB 127              ; path38: intensity
    FCB $20,$00,0,0        ; path38: header (y=32, x=0, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH39:    ; Path 39
    FCB 127              ; path39: intensity
    FCB $0D,$23,0,0        ; path39: header (y=13, x=35, relative to center)
    FCB $FF,$0A,$F9          ; flag=-1, dy=10, dx=-7
    FCB $FF,$05,$F7          ; flag=-1, dy=5, dx=-9
    FCB $FF,$04,$F6          ; flag=-1, dy=4, dx=-10
    FCB $FF,$02,$F7          ; flag=-1, dy=2, dx=-9
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH40:    ; Path 40
    FCB 127              ; path40: intensity
    FCB $0D,$20,0,0        ; path40: header (y=13, x=32, relative to center)
    FCB $FF,$09,$F9          ; flag=-1, dy=9, dx=-7
    FCB $FF,$05,$F7          ; flag=-1, dy=5, dx=-9
    FCB $FF,$05,$F0          ; flag=-1, dy=5, dx=-16
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH41:    ; Path 41
    FCB 127              ; path41: intensity
    FCB $20,$FF,0,0        ; path41: header (y=32, x=-1, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH42:    ; Path 42
    FCB 127              ; path42: intensity
    FCB $27,$0D,0,0        ; path42: header (y=39, x=13, relative to center)
    FCB $FF,$F9,$FC          ; flag=-1, dy=-7, dx=-4
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH43:    ; Path 43
    FCB 127              ; path43: intensity
    FCB $1B,$10,0,0        ; path43: header (y=27, x=16, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH44:    ; Path 44
    FCB 127              ; path44: intensity
    FCB $1C,$24,0,0        ; path44: header (y=28, x=36, relative to center)
    FCB $FF,$FB,$F7          ; flag=-1, dy=-5, dx=-9
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH45:    ; Path 45
    FCB 127              ; path45: intensity
    FCB $11,$1E,0,0        ; path45: header (y=17, x=30, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH46:    ; Path 46
    FCB 127              ; path46: intensity
    FCB $21,$03,0,0        ; path46: header (y=33, x=3, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH47:    ; Path 47
    FCB 127              ; path47: intensity
    FCB $D7,$1C,0,0        ; path47: header (y=-41, x=28, relative to center)
    FCB 2                ; End marker (path complete)

_ENTRANCE_ARC_PATH48:    ; Path 48
    FCB 127              ; path48: intensity
    FCB $22,$00,0,0        ; path48: header (y=34, x=0, relative to center)
    FCB 2                ; End marker (path complete)
; Generated from lamp.vec (Malban Draw_Sync_List format)
; Total paths: 29, points: 92
; X bounds: min=-22, max=23, width=45
; Center: (0, 0)

_LAMP_WIDTH EQU 45
_LAMP_HALF_WIDTH EQU 22
_LAMP_CENTER_X EQU 0
_LAMP_CENTER_Y EQU 0

_LAMP_VECTORS:  ; Main entry (header + 29 path(s))
    FCB 29               ; path_count (runtime metadata)
    FDB _LAMP_PATH0        ; pointer to path 0
    FDB _LAMP_PATH1        ; pointer to path 1
    FDB _LAMP_PATH2        ; pointer to path 2
    FDB _LAMP_PATH3        ; pointer to path 3
    FDB _LAMP_PATH4        ; pointer to path 4
    FDB _LAMP_PATH5        ; pointer to path 5
    FDB _LAMP_PATH6        ; pointer to path 6
    FDB _LAMP_PATH7        ; pointer to path 7
    FDB _LAMP_PATH8        ; pointer to path 8
    FDB _LAMP_PATH9        ; pointer to path 9
    FDB _LAMP_PATH10        ; pointer to path 10
    FDB _LAMP_PATH11        ; pointer to path 11
    FDB _LAMP_PATH12        ; pointer to path 12
    FDB _LAMP_PATH13        ; pointer to path 13
    FDB _LAMP_PATH14        ; pointer to path 14
    FDB _LAMP_PATH15        ; pointer to path 15
    FDB _LAMP_PATH16        ; pointer to path 16
    FDB _LAMP_PATH17        ; pointer to path 17
    FDB _LAMP_PATH18        ; pointer to path 18
    FDB _LAMP_PATH19        ; pointer to path 19
    FDB _LAMP_PATH20        ; pointer to path 20
    FDB _LAMP_PATH21        ; pointer to path 21
    FDB _LAMP_PATH22        ; pointer to path 22
    FDB _LAMP_PATH23        ; pointer to path 23
    FDB _LAMP_PATH24        ; pointer to path 24
    FDB _LAMP_PATH25        ; pointer to path 25
    FDB _LAMP_PATH26        ; pointer to path 26
    FDB _LAMP_PATH27        ; pointer to path 27
    FDB _LAMP_PATH28        ; pointer to path 28

_LAMP_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $DC,$F6,0,0        ; path0: header (y=-36, x=-10, relative to center)
    FCB 2                ; End marker (path complete)

_LAMP_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $23,$00,0,0        ; path1: header (y=35, x=0, relative to center)
    FCB 2                ; End marker (path complete)

_LAMP_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $23,$01,0,0        ; path2: header (y=35, x=1, relative to center)
    FCB 2                ; End marker (path complete)

_LAMP_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $07,$F4,0,0        ; path3: header (y=7, x=-12, relative to center)
    FCB 2                ; End marker (path complete)

_LAMP_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $07,$0B,0,0        ; path4: header (y=7, x=11, relative to center)
    FCB 2                ; End marker (path complete)

_LAMP_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $06,$F2,0,0        ; path5: header (y=6, x=-14, relative to center)
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$FF          ; flag=-1, dy=0, dx=-1
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB 2                ; End marker (path complete)

_LAMP_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $09,$EB,0,0        ; path6: header (y=9, x=-21, relative to center)
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB 2                ; End marker (path complete)

_LAMP_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $06,$EC,0,0        ; path7: header (y=6, x=-20, relative to center)
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_LAMP_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $06,$F2,0,0        ; path8: header (y=6, x=-14, relative to center)
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB 2                ; End marker (path complete)

_LAMP_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $02,$FC,0,0        ; path9: header (y=2, x=-4, relative to center)
    FCB 2                ; End marker (path complete)

_LAMP_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $0D,$FD,0,0        ; path10: header (y=13, x=-3, relative to center)
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB 2                ; End marker (path complete)

_LAMP_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $0A,$FD,0,0        ; path11: header (y=10, x=-3, relative to center)
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB 2                ; End marker (path complete)

_LAMP_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $07,$FC,0,0        ; path12: header (y=7, x=-4, relative to center)
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB 2                ; End marker (path complete)

_LAMP_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $06,$04,0,0        ; path13: header (y=6, x=4, relative to center)
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$F5          ; flag=-1, dy=0, dx=-11
    FCB 2                ; End marker (path complete)

_LAMP_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $06,$10,0,0        ; path14: header (y=6, x=16, relative to center)
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB 2                ; End marker (path complete)

_LAMP_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $02,$10,0,0        ; path15: header (y=2, x=16, relative to center)
    FCB 2                ; End marker (path complete)

_LAMP_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $00,$FE,0,0        ; path16: header (y=0, x=-2, relative to center)
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$FF,$01          ; flag=-1, dy=-1, dx=1
    FCB $FF,$01,$01          ; flag=-1, dy=1, dx=1
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB 2                ; End marker (path complete)

_LAMP_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $01,$EC,0,0        ; path17: header (y=1, x=-20, relative to center)
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB 2                ; End marker (path complete)

_LAMP_PATH18:    ; Path 18
    FCB 127              ; path18: intensity
    FCB $01,$10,0,0        ; path18: header (y=1, x=16, relative to center)
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB 2                ; End marker (path complete)

_LAMP_PATH19:    ; Path 19
    FCB 127              ; path19: intensity
    FCB $06,$FA,0,0        ; path19: header (y=6, x=-6, relative to center)
    FCB 2                ; End marker (path complete)

_LAMP_PATH20:    ; Path 20
    FCB 127              ; path20: intensity
    FCB $06,$06,0,0        ; path20: header (y=6, x=6, relative to center)
    FCB 2                ; End marker (path complete)

_LAMP_PATH21:    ; Path 21
    FCB 127              ; path21: intensity
    FCB $0E,$ED,0,0        ; path21: header (y=14, x=-19, relative to center)
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB 2                ; End marker (path complete)

_LAMP_PATH22:    ; Path 22
    FCB 127              ; path22: intensity
    FCB $0E,$11,0,0        ; path22: header (y=14, x=17, relative to center)
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$03,$02          ; flag=-1, dy=3, dx=2
    FCB $FF,$FD,$02          ; flag=-1, dy=-3, dx=2
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB 2                ; End marker (path complete)

_LAMP_PATH23:    ; Path 23
    FCB 127              ; path23: intensity
    FCB $12,$00,0,0        ; path23: header (y=18, x=0, relative to center)
    FCB 2                ; End marker (path complete)

_LAMP_PATH24:    ; Path 24
    FCB 127              ; path24: intensity
    FCB $23,$00,0,0        ; path24: header (y=35, x=0, relative to center)
    FCB 2                ; End marker (path complete)

_LAMP_PATH25:    ; Path 25
    FCB 127              ; path25: intensity
    FCB $1A,$00,0,0        ; path25: header (y=26, x=0, relative to center)
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_LAMP_PATH26:    ; Path 26
    FCB 127              ; path26: intensity
    FCB $12,$00,0,0        ; path26: header (y=18, x=0, relative to center)
    FCB $FF,$02,$02          ; flag=-1, dy=2, dx=2
    FCB $FF,$02,$FE          ; flag=-1, dy=2, dx=-2
    FCB $FF,$FE,$FE          ; flag=-1, dy=-2, dx=-2
    FCB $FF,$FE,$02          ; flag=-1, dy=-2, dx=2
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_LAMP_PATH27:    ; Path 27
    FCB 127              ; path27: intensity
    FCB $12,$00,0,0        ; path27: header (y=18, x=0, relative to center)
    FCB $FF,$F4,$F2          ; flag=-1, dy=-12, dx=-14
    FCB 2                ; End marker (path complete)

_LAMP_PATH28:    ; Path 28
    FCB 127              ; path28: intensity
    FCB $12,$00,0,0        ; path28: header (y=18, x=0, relative to center)
    FCB $FF,$F4,$0C          ; flag=-1, dy=-12, dx=12
    FCB 2                ; End marker (path complete)
; Generated from locked_door.vec (Malban Draw_Sync_List format)
; Total paths: 35, points: 103
; X bounds: min=-36, max=36, width=72
; Center: (0, 0)

_LOCKED_DOOR_WIDTH EQU 72
_LOCKED_DOOR_HALF_WIDTH EQU 36
_LOCKED_DOOR_CENTER_X EQU 0
_LOCKED_DOOR_CENTER_Y EQU 0

_LOCKED_DOOR_VECTORS:  ; Main entry (header + 35 path(s))
    FCB 35               ; path_count (runtime metadata)
    FDB _LOCKED_DOOR_PATH0        ; pointer to path 0
    FDB _LOCKED_DOOR_PATH1        ; pointer to path 1
    FDB _LOCKED_DOOR_PATH2        ; pointer to path 2
    FDB _LOCKED_DOOR_PATH3        ; pointer to path 3
    FDB _LOCKED_DOOR_PATH4        ; pointer to path 4
    FDB _LOCKED_DOOR_PATH5        ; pointer to path 5
    FDB _LOCKED_DOOR_PATH6        ; pointer to path 6
    FDB _LOCKED_DOOR_PATH7        ; pointer to path 7
    FDB _LOCKED_DOOR_PATH8        ; pointer to path 8
    FDB _LOCKED_DOOR_PATH9        ; pointer to path 9
    FDB _LOCKED_DOOR_PATH10        ; pointer to path 10
    FDB _LOCKED_DOOR_PATH11        ; pointer to path 11
    FDB _LOCKED_DOOR_PATH12        ; pointer to path 12
    FDB _LOCKED_DOOR_PATH13        ; pointer to path 13
    FDB _LOCKED_DOOR_PATH14        ; pointer to path 14
    FDB _LOCKED_DOOR_PATH15        ; pointer to path 15
    FDB _LOCKED_DOOR_PATH16        ; pointer to path 16
    FDB _LOCKED_DOOR_PATH17        ; pointer to path 17
    FDB _LOCKED_DOOR_PATH18        ; pointer to path 18
    FDB _LOCKED_DOOR_PATH19        ; pointer to path 19
    FDB _LOCKED_DOOR_PATH20        ; pointer to path 20
    FDB _LOCKED_DOOR_PATH21        ; pointer to path 21
    FDB _LOCKED_DOOR_PATH22        ; pointer to path 22
    FDB _LOCKED_DOOR_PATH23        ; pointer to path 23
    FDB _LOCKED_DOOR_PATH24        ; pointer to path 24
    FDB _LOCKED_DOOR_PATH25        ; pointer to path 25
    FDB _LOCKED_DOOR_PATH26        ; pointer to path 26
    FDB _LOCKED_DOOR_PATH27        ; pointer to path 27
    FDB _LOCKED_DOOR_PATH28        ; pointer to path 28
    FDB _LOCKED_DOOR_PATH29        ; pointer to path 29
    FDB _LOCKED_DOOR_PATH30        ; pointer to path 30
    FDB _LOCKED_DOOR_PATH31        ; pointer to path 31
    FDB _LOCKED_DOOR_PATH32        ; pointer to path 32
    FDB _LOCKED_DOOR_PATH33        ; pointer to path 33
    FDB _LOCKED_DOOR_PATH34        ; pointer to path 34

_LOCKED_DOOR_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $1D,$E0,0,0        ; path0: header (y=29, x=-32, relative to center)
    FCB $FF,$BE,$00          ; flag=-1, dy=-66, dx=0
    FCB $FF,$00,$42          ; flag=-1, dy=0, dx=66
    FCB $FF,$42,$00          ; flag=-1, dy=66, dx=0
    FCB $FF,$00,$02          ; flag=-1, dy=0, dx=2
    FCB $FF,$07,$00          ; flag=-1, dy=7, dx=0
    FCB $FF,$00,$B8          ; flag=-1, dy=0, dx=-72
    FCB $FF,$F9,$00          ; flag=-1, dy=-7, dx=0
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $1D,$E0,0,0        ; path1: header (y=29, x=-32, relative to center)
    FCB $FF,$00,$42          ; flag=-1, dy=0, dx=66
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $1D,$1A,0,0        ; path2: header (y=29, x=26, relative to center)
    FCB $FF,$E5,$FF          ; flag=-1, dy=-27, dx=-1
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH3:    ; Path 3
    FCB 127              ; path3: intensity
    FCB $02,$11,0,0        ; path3: header (y=2, x=17, relative to center)
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH4:    ; Path 4
    FCB 127              ; path4: intensity
    FCB $1D,$0A,0,0        ; path4: header (y=29, x=10, relative to center)
    FCB $FF,$F3,$00          ; flag=-1, dy=-13, dx=0
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH5:    ; Path 5
    FCB 127              ; path5: intensity
    FCB $0B,$0A,0,0        ; path5: header (y=11, x=10, relative to center)
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH6:    ; Path 6
    FCB 127              ; path6: intensity
    FCB $11,$02,0,0        ; path6: header (y=17, x=2, relative to center)
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH7:    ; Path 7
    FCB 127              ; path7: intensity
    FCB $03,$02,0,0        ; path7: header (y=3, x=2, relative to center)
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH8:    ; Path 8
    FCB 127              ; path8: intensity
    FCB $EC,$E9,0,0        ; path8: header (y=-20, x=-23, relative to center)
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH9:    ; Path 9
    FCB 127              ; path9: intensity
    FCB $DB,$E9,0,0        ; path9: header (y=-37, x=-23, relative to center)
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH10:    ; Path 10
    FCB 127              ; path10: intensity
    FCB $1B,$EB,0,0        ; path10: header (y=27, x=-21, relative to center)
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH11:    ; Path 11
    FCB 127              ; path11: intensity
    FCB $1D,$EF,0,0        ; path11: header (y=29, x=-17, relative to center)
    FCB $FF,$F5,$00          ; flag=-1, dy=-11, dx=0
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH12:    ; Path 12
    FCB 127              ; path12: intensity
    FCB $0A,$EF,0,0        ; path12: header (y=10, x=-17, relative to center)
    FCB $FF,$E3,$00          ; flag=-1, dy=-29, dx=0
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH13:    ; Path 13
    FCB 127              ; path13: intensity
    FCB $E5,$EF,0,0        ; path13: header (y=-27, x=-17, relative to center)
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH14:    ; Path 14
    FCB 127              ; path14: intensity
    FCB $10,$F5,0,0        ; path14: header (y=16, x=-11, relative to center)
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH15:    ; Path 15
    FCB 127              ; path15: intensity
    FCB $DC,$F5,0,0        ; path15: header (y=-36, x=-11, relative to center)
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH16:    ; Path 16
    FCB 127              ; path16: intensity
    FCB $1D,$FC,0,0        ; path16: header (y=29, x=-4, relative to center)
    FCB $FF,$F5,$00          ; flag=-1, dy=-11, dx=0
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH17:    ; Path 17
    FCB 127              ; path17: intensity
    FCB $0A,$FC,0,0        ; path17: header (y=10, x=-4, relative to center)
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH18:    ; Path 18
    FCB 127              ; path18: intensity
    FCB $F5,$FC,0,0        ; path18: header (y=-11, x=-4, relative to center)
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH19:    ; Path 19
    FCB 127              ; path19: intensity
    FCB $E5,$FC,0,0        ; path19: header (y=-27, x=-4, relative to center)
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH20:    ; Path 20
    FCB 127              ; path20: intensity
    FCB $EC,$03,0,0        ; path20: header (y=-20, x=3, relative to center)
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH21:    ; Path 21
    FCB 127              ; path21: intensity
    FCB $DC,$03,0,0        ; path21: header (y=-36, x=3, relative to center)
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH22:    ; Path 22
    FCB 127              ; path22: intensity
    FCB $F5,$0A,0,0        ; path22: header (y=-11, x=10, relative to center)
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH23:    ; Path 23
    FCB 127              ; path23: intensity
    FCB $E7,$0A,0,0        ; path23: header (y=-25, x=10, relative to center)
    FCB $FF,$F5,$00          ; flag=-1, dy=-11, dx=0
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH24:    ; Path 24
    FCB 127              ; path24: intensity
    FCB $DB,$11,0,0        ; path24: header (y=-37, x=17, relative to center)
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH25:    ; Path 25
    FCB 127              ; path25: intensity
    FCB $F5,$19,0,0        ; path25: header (y=-11, x=25, relative to center)
    FCB $FF,$E7,$00          ; flag=-1, dy=-25, dx=0
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH26:    ; Path 26
    FCB 127              ; path26: intensity
    FCB $0B,$E3,0,0        ; path26: header (y=11, x=-29, relative to center)
    FCB $FF,$00,$1F          ; flag=-1, dy=0, dx=31
    FCB $FF,$03,$0C          ; flag=-1, dy=3, dx=12
    FCB $FF,$03,$F4          ; flag=-1, dy=3, dx=-12
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH27:    ; Path 27
    FCB 127              ; path27: intensity
    FCB $11,$02,0,0        ; path27: header (y=17, x=2, relative to center)
    FCB $FF,$00,$E1          ; flag=-1, dy=0, dx=-31
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH28:    ; Path 28
    FCB 127              ; path28: intensity
    FCB $1D,$E9,0,0        ; path28: header (y=29, x=-23, relative to center)
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH29:    ; Path 29
    FCB 127              ; path29: intensity
    FCB $EC,$E3,0,0        ; path29: header (y=-20, x=-29, relative to center)
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$20          ; flag=-1, dy=0, dx=32
    FCB $FF,$03,$0B          ; flag=-1, dy=3, dx=11
    FCB $FF,$03,$F5          ; flag=-1, dy=3, dx=-11
    FCB $FF,$00,$E0          ; flag=-1, dy=0, dx=-32
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH30:    ; Path 30
    FCB 127              ; path30: intensity
    FCB $01,$FA,0,0        ; path30: header (y=1, x=-6, relative to center)
    FCB $FF,$F5,$00          ; flag=-1, dy=-11, dx=0
    FCB $FF,$00,$20          ; flag=-1, dy=0, dx=32
    FCB $FF,$0B,$00          ; flag=-1, dy=11, dx=0
    FCB $FF,$00,$E0          ; flag=-1, dy=0, dx=-32
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH31:    ; Path 31
    FCB 127              ; path31: intensity
    FCB $F8,$FE,0,0        ; path31: header (y=-8, x=-2, relative to center)
    FCB $FF,$01,$02          ; flag=-1, dy=1, dx=2
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH32:    ; Path 32
    FCB 127              ; path32: intensity
    FCB $F8,$06,0,0        ; path32: header (y=-8, x=6, relative to center)
    FCB $FF,$01,$02          ; flag=-1, dy=1, dx=2
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH33:    ; Path 33
    FCB 127              ; path33: intensity
    FCB $F8,$0E,0,0        ; path33: header (y=-8, x=14, relative to center)
    FCB $FF,$01,$02          ; flag=-1, dy=1, dx=2
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)

_LOCKED_DOOR_PATH34:    ; Path 34
    FCB 127              ; path34: intensity
    FCB $F8,$16,0,0        ; path34: header (y=-8, x=22, relative to center)
    FCB $FF,$01,$02          ; flag=-1, dy=1, dx=2
    FCB $FF,$02,$01          ; flag=-1, dy=2, dx=1
    FCB $FF,$02,$FF          ; flag=-1, dy=2, dx=-1
    FCB $FF,$01,$FE          ; flag=-1, dy=1, dx=-2
    FCB $FF,$FF,$FE          ; flag=-1, dy=-1, dx=-2
    FCB $FF,$FE,$FF          ; flag=-1, dy=-2, dx=-1
    FCB $FF,$FE,$01          ; flag=-1, dy=-2, dx=1
    FCB $FF,$FF,$02          ; flag=-1, dy=-1, dx=2
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)
; Generated from player.vec (Malban Draw_Sync_List format)
; Total paths: 7, points: 25
; X bounds: min=-10, max=11, width=21
; Center: (0, -1)

_PLAYER_WIDTH EQU 21
_PLAYER_HALF_WIDTH EQU 10
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
    FCB $FF,$ED,$FC          ; flag=-1, dy=-19, dx=-4
    FCB $FF,$00,$10          ; flag=-1, dy=0, dx=16
    FCB $FF,$13,$FC          ; flag=-1, dy=19, dx=-4
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
    FCB     38              ; Delay 38 frames (maintain previous state)
    FCB     4              ; Frame 75 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FF             ; Reg 7 value
    FCB     25              ; Delay 25 frames (maintain previous state)
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
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     4              ; Frame 106 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FF             ; Reg 7 value
    FCB     94              ; Delay 94 frames (maintain previous state)
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
    FCB     43              ; Delay 43 frames (maintain previous state)
    FCB     4              ; Frame 249 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FF             ; Reg 7 value
    FCB     51              ; Delay 51 frames (maintain previous state)
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
    FCB     6              ; Delay 6 frames (maintain previous state)
    FCB     4              ; Frame 306 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FF             ; Reg 7 value
    FCB     94              ; Delay 94 frames (maintain previous state)
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
    FCB     37              ; Delay 37 frames (maintain previous state)
    FCB     4              ; Frame 474 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FF             ; Reg 7 value
    FCB     25              ; Delay 25 frames (maintain previous state)
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
    FCB     7              ; Delay 7 frames (maintain previous state)
    FCB     4              ; Frame 506 - 4 register writes
    FCB     8               ; Reg 8 number
    FCB     $00             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FF             ; Reg 7 value
    FCB     94              ; Delay 94 frames (maintain previous state)
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

; Generated from intro.vmus (internal name: The Clockmaker's Crypt - Title Theme)
; Tempo: 84 BPM, Total events: 18 (PSG Direct format)
; Format: FCB count, FCB reg, val, ... (per frame), FCB 0 (end)

_INTRO_MUSIC:
    ; Frame-based PSG register writes
    FCB     0              ; Delay 0 frames (maintain previous state)
    FCB     9              ; Frame 0 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0C             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0E             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $DC             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     8              ; Frame 8 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $A2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $02             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FC             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     6              ; Frame 17 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
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
    FCB     18              ; Delay 18 frames (maintain previous state)
    FCB     6              ; Frame 35 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
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
    FCB     36              ; Delay 36 frames (maintain previous state)
    FCB     6              ; Frame 71 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FE             ; Reg 7 value
    FCB     36              ; Delay 36 frames (maintain previous state)
    FCB     9              ; Frame 107 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0C             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0E             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $DC             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     8              ; Frame 116 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $08             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FC             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     6              ; Frame 125 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $96             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FE             ; Reg 7 value
    FCB     17              ; Delay 17 frames (maintain previous state)
    FCB     6              ; Frame 142 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $BD             ; Reg 0 value
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
    FCB     36              ; Delay 36 frames (maintain previous state)
    FCB     6              ; Frame 178 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0B             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FE             ; Reg 7 value
    FCB     72              ; Delay 72 frames (maintain previous state)
    FCB     9              ; Frame 250 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
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
    FCB     $0C             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0E             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $DC             ; Reg 7 value
    FCB     8              ; Delay 8 frames (maintain previous state)
    FCB     8              ; Frame 258 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
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
    FCB     $FC             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     6              ; Frame 267 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $D4             ; Reg 0 value
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
    FCB     18              ; Delay 18 frames (maintain previous state)
    FCB     6              ; Frame 285 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $A8             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
    FCB     9               ; Reg 9 number
    FCB     $00             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FE             ; Reg 7 value
    FCB     36              ; Delay 36 frames (maintain previous state)
    FCB     6              ; Frame 321 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $8D             ; Reg 0 value
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
    FCB     36              ; Delay 36 frames (maintain previous state)
    FCB     9              ; Frame 357 - 9 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $0C             ; Reg 10 value
    FCB     6               ; Reg 6 number
    FCB     $0E             ; Reg 6 value
    FCB     7               ; Reg 7 number
    FCB     $DC             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     8              ; Frame 366 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0C             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $C2             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0A             ; Reg 9 value
    FCB     10               ; Reg 10 number
    FCB     $00             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $FC             ; Reg 7 value
    FCB     9              ; Delay 9 frames (maintain previous state)
    FCB     6              ; Frame 375 - 6 register writes
    FCB     0               ; Reg 0 number
    FCB     $E1             ; Reg 0 value
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
    FCB     53              ; Delay 53 frames before loop
    FCB     $FF             ; Loop command ($FF never valid as count)
    FDB     _INTRO_MUSIC       ; Jump to start (absolute address)

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
    FCB 0  ; Background object count
    FCB 4  ; Gameplay object count
    FCB 0  ; Foreground object count
    FDB _ENTRANCE_BG_OBJECTS
    FDB _ENTRANCE_GAMEPLAY_OBJECTS
    FDB _ENTRANCE_FG_OBJECTS

_ENTRANCE_BG_OBJECTS:

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
    FDB -80  ; y
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

; Object: obj_1772461603432 (enemy)
    FCB 1  ; type
    FDB -42  ; x
    FDB -83  ; y
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


_ENTRANCE_FG_OBJECTS:

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
; CRITICAL: Do NOT call JSR $F2AB (Intensity_a) here! With DP=$D0,
; Intensity_a does STA <$32 which hits $D032 = VIA DDRB (reg $02),
; setting PB0 as input and breaking the X/Y integrator mux entirely.
; Fix: write Vec_Misc_Count ($C832) directly via extended addressing.
LDA >DRAW_VEC_INTENSITY ; Check if intensity override is set
BNE DSWM_USE_OVERRIDE   ; If non-zero, use override
LDA ,X+                 ; Otherwise, read intensity from vector data
BRA DSWM_SET_INTENSITY
DSWM_USE_OVERRIDE:
LEAX 1,X                ; Skip intensity byte in vector data
DSWM_SET_INTENSITY:
STA >$C832              ; Set Vec_Misc_Count directly (DP-safe, no DDRB corruption)
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
STA >$C832              ; Set Vec_Misc_Count directly (DP-safe, no DDRB corruption)
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
    
    ; Store level pointer persistently
    STX >LEVEL_PTR
    
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
    
    ; Check if level is loaded
    LDX >LEVEL_PTR
    CMPX #0
    BEQ SLR_DONE     ; No level loaded, skip
    
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
    PULS D,Y,X,U     ; Restore registers
    RTS

; === ULR_UPDATE_LAYER - Apply physics to each object in GP buffer ===
; Input: B = object count, U = buffer base (15 bytes/object)
; RAM object layout:
;   +0-1: world_x(i16)  +2: y(i8)  +3: scale  +4: rotation
;   +5: velocity_x  +6: velocity_y  +7: physics_flags  +8: collision_flags
;   +9: collision_size  +10: spawn_delay_lo  +11-12: vector_ptr  +13-14: props_ptr
ULR_UPDATE_LAYER:
    LDX >LEVEL_PTR   ; Load level pointer for world bounds
    CMPX #0
    LBEQ ULR_LAYER_EXIT
    
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
LDB #$FF                ; All channels disabled
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

PRINT_TEXT_STR_2879828691638:
    FCC "entrance"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2718184010937820:
    FCC "crypt_logo"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_75109439344046724:
    FCC "YOU. ALONE."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_84995521868454133:
    FCC "door_unlock"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_86053808672632355:
    FCC "exploration"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_94999312012949119:
    FCC "puzzle_fail"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_108981465518803784:
    FCC "JOYSTICK - MOVE"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_663557968544316929:
    FCC "BUTTON 3 - CHANGE VERB"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_1723491705885603536:
    FCC "INVENTORY HIS ESTATE."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2177760433760906132:
    FCC "PUSH BUTTON 1 TO START"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2229603571317507421:
    FCC "USE PAINTING"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2466860800980120503:
    FCC "4 DIGIT WHEELS."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2861907936048358368:
    FCC "THE PORTRAIT SHOWS"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3280973746071781571:
    FCC "EXAMINE PAINTING"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3450013277136201656:
    FCC "YOU ENTER THE CRYPT."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_4088011977317884966:
    FCC "KONRAD VOSS IS DEAD."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_4406207116162196822:
    FCC "THE MUNICIPALITY SENDS"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_5259861110007390611:
    FCC "A COMBINATION LOCK."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_5426318097895719391:
    FCC "THE ECCENTRIC CLOCKMAKER"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_6139730876735760457:
    FCC "SOLVE THE PUZZLES."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_6872332185365714620:
    FCC "THE DOOR CLOSES BEHIND"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_7290160099101033390:
    FCC "USE WORKSHOP DOOR"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_7298484243732525396:
    FCC "A DATE... A CODE?"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_7315232135604509958:
    FCC "GEARS TURN BY THEMSELVES."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_8014226008171103997:
    FCC "HAS A CLOCKWORK LOCK."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_8026944039266549802:
    FCC "FIND THE CLUES."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_8774988741757873223:
    FCC "YOU AS ASSESSOR TO"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_9120385760502433312:
    FCC "PRESS BUTTON 1"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_9156937352888375391:
    FCC "YOU TRY:  1 - 8 - 8 - 7"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_9511871676577024489:
    FCC "TO BE CONTINUED..."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_9561915646494768437:
    FCC "YOU NEED TO FIND"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_10933791426923319118:
    FCC "THE SARCOPHAGUS BELOW"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_12477029002870225325:
    FCC "BUTTON 2 - INVENTORY"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_12538318624203089469:
    FCC "TAKE PAINTING"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_13107026394822308942:
    FCC "ESCAPE THE CRYPT."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_13572010117618904782:
    FCC "TAKE WORKSHOP DOOR"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_13773863620621678600:
    FCC "EXAMINE WORKSHOP DOOR"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_14476289867083772980:
    FCC "VOSS IN 1887."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_14502866266724095954:
    FCC "THE DOOR CLICKS OPEN."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_15028810657913953998:
    FCC "THE COMBINATION."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_16443595361531215430:
    FCC "BUTTON 1 - INTERACT"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17850884399050856369:
    FCC "SWITZERLAND, 1887."
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_17897140833419752430:
    FCC "YOU CANNOT DO THAT."
    FCB $80          ; Vectrex string terminator

