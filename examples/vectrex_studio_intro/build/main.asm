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
    FCC "VECTREX STUDIO"
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
DRAW_VEC_X_HI        EQU $C880+$0F   ; Vector draw X high byte (16-bit screen_x) (1 bytes)
DRAW_VEC_X           EQU $C880+$10   ; Vector draw X offset (1 bytes)
DRAW_VEC_Y           EQU $C880+$11   ; Vector draw Y offset (1 bytes)
MIRROR_PAD           EQU $C880+$12   ; Safety padding to prevent MIRROR flag corruption (16 bytes)
MIRROR_X             EQU $C880+$22   ; X mirror flag (0=normal, 1=flip) (1 bytes)
MIRROR_Y             EQU $C880+$23   ; Y mirror flag (0=normal, 1=flip) (1 bytes)
SLR_CUR_X            EQU $C880+$24   ; DRAW_VECTOR: clamped (visible) beam X for clipping (1 bytes)
SLR_TRUE_X           EQU $C880+$25   ; DRAW_VECTOR: 16-bit unclamped abs_x for line clipping (2 bytes)
DRAW_T1_SCALED       EQU $C880+$27   ; DRAW_VECTOR: T1 scale ($7F default for non-SHOW_LEVEL) (1 bytes)
SDCP_ABS_Y           EQU $C880+$28   ; DRAW_VECTOR: abs_y temporary for SDCP (cannot share TMPVAL — would corrupt SHOW_LEVEL's top_screen between layers) (1 bytes)
ROT3D_AX             EQU $C880+$29   ; 3D raw angle X (0-127) (1 bytes)
ROT3D_AY             EQU $C880+$2A   ; 3D raw angle Y (0-127) (1 bytes)
ROT3D_AZ             EQU $C880+$2B   ; 3D raw angle Z (0-127) (1 bytes)
ROT3D_COS_X          EQU $C880+$2C   ; 3D cos angle offset for X axis: (AX+32)&0x7F (1 bytes)
ROT3D_COS_Y          EQU $C880+$2D   ; 3D cos angle offset for Y axis: (AY+32)&0x7F (1 bytes)
ROT3D_COS_Z          EQU $C880+$2E   ; 3D cos angle offset for Z axis: (AZ+32)&0x7F (1 bytes)
ROT3D_OX             EQU $C880+$2F   ; 3D draw X offset (1 bytes)
ROT3D_OY             EQU $C880+$30   ; 3D draw Y offset (1 bytes)
ROT3D_PC             EQU $C880+$31   ; 3D path/vertex count remaining (1 bytes)
ROT3D_PT_REM         EQU $C880+$32   ; 3D remaining points in current path (1 bytes)
ROT3D_CLOSED         EQU $C880+$33   ; 3D path closed flag (1 bytes)
ROT3D_RX             EQU $C880+$34   ; 3D raw x (1 bytes)
ROT3D_RY             EQU $C880+$35   ; 3D raw y (1 bytes)
ROT3D_RZ             EQU $C880+$36   ; 3D raw z (1 bytes)
ROT3D_Y1             EQU $C880+$37   ; 3D intermediate y after X-axis rotation (1 bytes)
ROT3D_Z1             EQU $C880+$38   ; 3D intermediate z after X-axis rotation (1 bytes)
ROT3D_X2             EQU $C880+$39   ; 3D intermediate x after Y-axis rotation (1 bytes)
ROT3D_SCR_X          EQU $C880+$3A   ; 3D final screen x (1 bytes)
ROT3D_SCR_Y          EQU $C880+$3B   ; 3D final screen y (1 bytes)
ROT3D_PREV_X         EQU $C880+$3C   ; 3D previous screen x (1 bytes)
ROT3D_PREV_Y         EQU $C880+$3D   ; 3D previous screen y (1 bytes)
ROT3D_FIRST_X        EQU $C880+$3E   ; 3D first screen x (for closed path) (1 bytes)
ROT3D_FIRST_Y        EQU $C880+$3F   ; 3D first screen y (for closed path) (1 bytes)
ROT3D_TEMP           EQU $C880+$40   ; 3D rotation temp 1 (1 bytes)
ROT3D_TEMP2          EQU $C880+$41   ; 3D rotation temp 2 (1 bytes)
ROT3D_VBUF           EQU $C880+$42   ; 3D rotated vertex cache (127 verts × 2 bytes: x',y') (254 bytes)
DRAW_LINE_ARGS       EQU $C880+$140   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$14A   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$14C   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$14E   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$14F   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$150   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$152   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
TEXT_SCALE_H         EQU $C880+$154   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$155   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
DRAW_SCALE           EQU $C880+$156   ; Current T1 scale for Draw_Sync_List_At_With_Mirrors ($7F=normal) (1 bytes)
VAR_ARG0             EQU $C880+$157   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $C880+$159   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $C880+$15B   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $C880+$15D   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $C880+$15F   ; Function argument 4 (16-bit) (2 bytes)
VAR_ARG5             EQU $C880+$161   ; Function argument 5 (16-bit) (2 bytes)
VAR_ARG6             EQU $C880+$163   ; Function argument 6 (16-bit) (2 bytes)
VAR_ARG7             EQU $C880+$165   ; Function argument 7 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $C880+$167   ; Current ROM bank ID (multibank tracking) (1 bytes)
VAR_PHASE            EQU $C880+$168   ; User variable: phase (2 bytes)
VAR_T                EQU $C880+$16A   ; User variable: t (2 bytes)
VAR_LOGO_ROT         EQU $C880+$16C   ; User variable: logo_rot (2 bytes)
VAR_LOGO_I           EQU $C880+$16E   ; User variable: logo_i (2 bytes)
VAR_WORD_I           EQU $C880+$170   ; User variable: word_i (2 bytes)
VAR_SUB_I            EQU $C880+$172   ; User variable: sub_i (2 bytes)
VAR_MUSIC_ON         EQU $C880+$174   ; User variable: music_on (2 bytes)
VAR_LOGO_MAX         EQU $C880+$176   ; User variable: LOGO_MAX (2 bytes)
VAR_WORD_MAX         EQU $C880+$178   ; User variable: WORD_MAX (2 bytes)
VAR_SUB_MAX          EQU $C880+$17A   ; User variable: SUB_MAX (2 bytes)
PSG_MUSIC_PTR        EQU $C880+$17C   ; PSG music data pointer (2 bytes)
PSG_MUSIC_START      EQU $C880+$17E   ; PSG music start pointer (for loops) (2 bytes)
PSG_MUSIC_ACTIVE     EQU $C880+$180   ; PSG music active flag (1 bytes)
PSG_IS_PLAYING       EQU $C880+$181   ; PSG playing flag (1 bytes)
PSG_DELAY_FRAMES     EQU $C880+$182   ; PSG frame delay counter (1 bytes)
PSG_MUSIC_BANK       EQU $C880+$183   ; PSG music bank ID (for multibank) (1 bytes)
SFX_PTR              EQU $C880+$184   ; SFX data pointer (2 bytes)
SFX_ACTIVE           EQU $C880+$186   ; SFX active flag (1 bytes)
SFX_BANK             EQU $C880+$187   ; SFX bank ID (for multibank) (1 bytes)

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
    LDA #$7F
    STA DRAW_SCALE        ; Default T1 scale = $7F (127 = full BIOS scale)
    LDD #0
    STD VAR_PHASE
    LDD #0
    STD VAR_T
    LDD #64
    STD VAR_LOGO_ROT
    LDD #0
    STD VAR_LOGO_I
    LDD #0
    STD VAR_WORD_I
    LDD #0
    STD VAR_SUB_I
    LDD #0
    STD VAR_MUSIC_ON
    LDD #118
    STD VAR_LOGO_MAX
    LDD #100
    STD VAR_WORD_MAX
    LDD #80
    STD VAR_SUB_MAX
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
    ; Call main() for initialization
; VPy_LINE:30
    ; TODO: Statement Pass { source_line: 30 }
    CLR >$C811  ; Force-clear Vec_Buttons before first loop() frame

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
; VPy_LINE:34
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_T
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_T
; VPy_LINE:37
    LDD >VAR_MUSIC_ON
    CMPD #0
    LBNE IF_NEXT_1
; VPy_LINE:38
    LDD #1
    STD VAR_MUSIC_ON
; VPy_LINE:39
; NATIVE_CALL: PLAY_MUSIC at line 39
    ; PLAY_MUSIC("jingle") - play music asset (index=0)
    LDX #_JINGLE_MUSIC  ; Load music data pointer
    JSR PLAY_MUSIC_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
; VPy_LINE:42
    LDD >VAR_PHASE
    CMPD #0
    LBNE IF_NEXT_3
; VPy_LINE:44
    LDD #1
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_LOGO_ROT
    SUBD TMPVAL         ; D = LEFT - RIGHT
    STD VAR_LOGO_ROT
; VPy_LINE:45
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_LOGO_ROT
    CMPD TMPVAL
    LBLT .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    LBEQ IF_NEXT_5
; VPy_LINE:46
    LDD #0
    STD VAR_LOGO_ROT
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
; VPy_LINE:48
    LDD >VAR_LOGO_MAX
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_LOGO_I
    CMPD TMPVAL
    LBLT .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    LBEQ IF_NEXT_7
; VPy_LINE:49
    LDD #2
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_LOGO_I
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_LOGO_I
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
; VPy_LINE:51
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_LOGO_ROT
    CMPD TMPVAL
    LBLE .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    LBEQ IF_NEXT_9
; VPy_LINE:52
    LDD #1
    STD VAR_PHASE
    LBRA IF_END_8
IF_NEXT_9:
IF_END_8:
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
; VPy_LINE:55
    LDD >VAR_PHASE
    CMPD #1
    LBNE IF_NEXT_11
; VPy_LINE:57
    LDD #24
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_LOGO_MAX
    SUBD TMPVAL         ; D = LEFT - RIGHT
    PSHS D              ; save LEFT on stack (nested RIGHT)
    ; SIN: Sine lookup
    LDD >VAR_T
    ANDB #$7F      ; Mask to 0-127
    CLRA           ; Clear high byte
    ASLB
    ROLA
    LDX #SIN_TABLE
    ABX            ; Add offset to table base
    LDD ,X         ; Load 16-bit value
    STD RESULT
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD #5
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    TFR D,X             ; X = LEFT (dividend)
    LDD TMPVAL          ; D = RIGHT (divisor)
    JSR DIV16           ; D = X / D
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_LOGO_I
; VPy_LINE:59
    LDD >VAR_WORD_MAX
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_WORD_I
    CMPD TMPVAL
    LBLT .CMP_3_TRUE
    LDD #0
    LBRA .CMP_3_END
.CMP_3_TRUE:
    LDD #1
.CMP_3_END:
    LBEQ IF_NEXT_13
; VPy_LINE:60
    LDD #3
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_WORD_I
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_WORD_I
    LBRA IF_END_12
IF_NEXT_13:
IF_END_12:
; VPy_LINE:61
    LDD #40
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_WORD_I
    CMPD TMPVAL
    LBGT .CMP_4_TRUE
    LDD #0
    LBRA .CMP_4_END
.CMP_4_TRUE:
    LDD #1
.CMP_4_END:
    LBEQ IF_NEXT_15
; VPy_LINE:62
    LDD >VAR_SUB_MAX
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SUB_I
    CMPD TMPVAL
    LBLT .CMP_5_TRUE
    LDD #0
    LBRA .CMP_5_END
.CMP_5_TRUE:
    LDD #1
.CMP_5_END:
    LBEQ IF_NEXT_17
; VPy_LINE:63
    LDD #2
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_SUB_I
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_SUB_I
    LBRA IF_END_16
IF_NEXT_17:
IF_END_16:
    LBRA IF_END_14
IF_NEXT_15:
IF_END_14:
; VPy_LINE:64
    LDD >VAR_SUB_MAX
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SUB_I
    CMPD TMPVAL
    LBGE .CMP_6_TRUE
    LDD #0
    LBRA .CMP_6_END
.CMP_6_TRUE:
    LDD #1
.CMP_6_END:
    LBEQ IF_NEXT_19
; VPy_LINE:65
    LDD #2
    STD VAR_PHASE
    LBRA IF_END_18
IF_NEXT_19:
IF_END_18:
    LBRA IF_END_10
IF_NEXT_11:
IF_END_10:
; VPy_LINE:68
    LDD >VAR_PHASE
    CMPD #2
    LBNE IF_NEXT_21
; VPy_LINE:70
    LDD #24
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_LOGO_MAX
    SUBD TMPVAL         ; D = LEFT - RIGHT
    PSHS D              ; save LEFT on stack (nested RIGHT)
    ; SIN: Sine lookup
    LDD >VAR_T
    ANDB #$7F      ; Mask to 0-127
    CLRA           ; Clear high byte
    ASLB
    ROLA
    LDX #SIN_TABLE
    ABX            ; Add offset to table base
    LDD ,X         ; Load 16-bit value
    STD RESULT
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD #5
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    TFR D,X             ; X = LEFT (dividend)
    LDD TMPVAL          ; D = RIGHT (divisor)
    JSR DIV16           ; D = X / D
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_LOGO_I
; VPy_LINE:71
    LDD #20
    STD TMPVAL          ; RIGHT → TMPVAL (LEFT simple)
    LDD >VAR_WORD_MAX
    SUBD TMPVAL         ; D = LEFT - RIGHT
    PSHS D              ; save LEFT on stack (nested RIGHT)
    ; SIN: Sine lookup
    LDD >VAR_T
    ANDB #$7F      ; Mask to 0-127
    CLRA           ; Clear high byte
    ASLB
    ROLA
    LDX #SIN_TABLE
    ABX            ; Add offset to table base
    LDD ,X         ; Load 16-bit value
    STD RESULT
    PSHS D              ; save LEFT on stack (nested RIGHT)
    LDD #6
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    TFR D,X             ; X = LEFT (dividend)
    LDD TMPVAL          ; D = RIGHT (divisor)
    JSR DIV16           ; D = X / D
    STD TMPVAL          ; RIGHT → TMPVAL
    PULS D              ; restore LEFT into D
    ADDD TMPVAL         ; D = LEFT + RIGHT
    STD VAR_WORD_I
    LBRA IF_END_20
IF_NEXT_21:
IF_END_20:
; VPy_LINE:75
; NATIVE_CALL: SET_INTENSITY at line 75
    ; SET_INTENSITY: Set drawing intensity
    LDD >VAR_LOGO_I
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:76
; NATIVE_CALL: DRAW_VECTOR_3D at line 76
    ; DRAW_VECTOR_3D: Draw vector asset with 3D rotation
    ; Asset: logo (3D rotation)
    LDD #0
    STB >ROT3D_AX       ; angle X (0-127)
    LDD >VAR_LOGO_ROT
    STB >ROT3D_AY       ; angle Y (0-127)
    LDD #0
    STB >ROT3D_AZ       ; angle Z (0-127)
    LDD #0
    STB >ROT3D_OX       ; screen X offset
    LDD #34
    STB >ROT3D_OY       ; screen Y offset
    LDX #_LOGO_3D_DATA  ; pointer to 3D data table
    JSR DRAW_VECTOR_3D_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:79
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_WORD_I
    CMPD TMPVAL
    LBGT .CMP_7_TRUE
    LDD #0
    LBRA .CMP_7_END
.CMP_7_TRUE:
    LDD #1
.CMP_7_END:
    LBEQ IF_NEXT_23
; VPy_LINE:80
; NATIVE_CALL: SET_INTENSITY at line 80
    ; SET_INTENSITY: Set drawing intensity
    LDD >VAR_WORD_I
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:81
; NATIVE_CALL: DRAW_VECTOR at line 81
    ; DRAW_VECTOR: Draw vector asset at position
    ; Asset: text (index=1, 13 paths)
    LDD #0
    STA TMPPTR2      ; save high byte of 16-bit screen_x
    TFR B,A
    SEX              ; A = sign-extend of B (0x00 or 0xFF)
    CMPA TMPPTR2     ; vs actual high byte
    LBNE DRVEC_SKIP_0          ; out of 8-bit range — skip draw
    TFR B,A
    STA TMPPTR       ; save 8-bit x
    LDD #-40
    TFR B,A          ; Y position (8-bit signed in A)
    STA TMPPTR+1     ; Save Y to temporary storage
    LDA TMPPTR       ; X position (8-bit signed, was cull-checked)
    STA DRAW_VEC_X
    LDB #0
    TSTA
    BPL .sx_pos_0
    LDB #$FF
.sx_pos_0:
    STB DRAW_VEC_X_HI
    LDA TMPPTR+1     ; Y position
    STA DRAW_VEC_Y
    CLR MIRROR_X
    CLR MIRROR_Y
    CLR DRAW_VEC_INTENSITY  ; Reset: use .vec intensities (not SHOW_LEVEL leftovers)
    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)
    LDX #_TEXT_PATH0  ; Load path 0
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_TEXT_PATH1  ; Load path 1
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_TEXT_PATH2  ; Load path 2
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_TEXT_PATH3  ; Load path 3
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_TEXT_PATH4  ; Load path 4
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_TEXT_PATH5  ; Load path 5
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_TEXT_PATH6  ; Load path 6
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_TEXT_PATH7  ; Load path 7
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_TEXT_PATH8  ; Load path 8
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_TEXT_PATH9  ; Load path 9
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_TEXT_PATH10  ; Load path 10
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_TEXT_PATH11  ; Load path 11
    JSR Draw_Sync_List_At_With_Mirrors
    LDX #_TEXT_PATH12  ; Load path 12
    JSR Draw_Sync_List_At_With_Mirrors
    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)
DRVEC_SKIP_0:
    LDD #0
    STD RESULT
    LBRA IF_END_22
IF_NEXT_23:
IF_END_22:
; VPy_LINE:84
    LDD #0
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_SUB_I
    CMPD TMPVAL
    LBGT .CMP_8_TRUE
    LDD #0
    LBRA .CMP_8_END
.CMP_8_TRUE:
    LDD #1
.CMP_8_END:
    LBEQ IF_NEXT_25
; VPy_LINE:85
; NATIVE_CALL: SET_INTENSITY at line 85
    ; SET_INTENSITY: Set drawing intensity
    LDD >VAR_SUB_I
    TFR B,A         ; Intensity (8-bit) — B already holds low byte
    STA DRAW_VEC_INTENSITY  ; DSWM reads this for every path drawn
    LDD #0
    STD RESULT
; VPy_LINE:86
; NATIVE_CALL: SET_TEXT_SIZE at line 86
    LDD #6
    STD TMPPTR2     ; Save n (TMPPTR2+1 = n)
    NEGB            ; B = -n -> TEXT_SCALE_H
    STB >TEXT_SCALE_H
    LDB TMPPTR2+1   ; Reload n (from TMPPTR2, not RESULT)
    ASLB            ; n*2
    ASLB            ; n*4
    ASLB            ; n*8
    ADDB TMPPTR2+1  ; n*8 + n = n*9 -> TEXT_SCALE_W
    STB >TEXT_SCALE_W
; VPy_LINE:87
; NATIVE_CALL: PRINT_TEXT at line 87
    ; PRINT_TEXT: Print text at position
    LDD #-14
    STD >VAR_ARG0
    LDD #-64
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2456395222      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    LBRA IF_END_24
IF_NEXT_25:
IF_END_24:
    JSR AUDIO_UPDATE  ; Auto-injected: update music + SFX
    RTS

;***************************************************************************
; EMBEDDED ASSETS (vectors, music, levels, SFX)
;***************************************************************************

; Generated from logo.vec (Malban Draw_Sync_List format)
; Total paths: 4, points: 36
; X bounds: min=-34, max=33, width=67
; Center: (0, 0)

_LOGO_WIDTH EQU 67
_LOGO_HALF_WIDTH EQU 33
_LOGO_HEIGHT EQU 99
_LOGO_HALF_HEIGHT EQU 49
_LOGO_CENTER_X EQU 0
_LOGO_CENTER_Y EQU 0

_LOGO_VECTORS:  ; Main entry (header + 4 path(s))
    FDB 4               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _LOGO_PATH0        ; pointer to path 0
    FDB _LOGO_PATH1        ; pointer to path 1
    FDB _LOGO_PATH2        ; pointer to path 2
    FDB _LOGO_PATH3        ; pointer to path 3

_LOGO_PATH0:    ; Path 0
    FCB 85              ; path0: intensity
    FCB $D6,$11,0,0        ; path0: header (y=-42, x=17)
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$00,$F8          ; flag=-1, dy=0, dx=-8
    FCB $FF,$F7,$00          ; flag=-1, dy=-9, dx=0
    FCB $FF,$00,$08          ; flag=-1, dy=0, dx=8
    FCB 2                ; End marker (path complete)

_LOGO_PATH1:    ; Path 1
    FCB 85              ; path1: intensity
    FCB $CE,$17,0,0        ; path1: header (y=-50, x=23)
    FCB $FF,$14,$00          ; flag=-1, dy=20, dx=0
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$24,$00          ; flag=-1, dy=36, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$E6          ; flag=-1, dy=0, dx=-26
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$DC,$00          ; flag=-1, dy=-36, dx=0
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$EC,$00          ; flag=-1, dy=-20, dx=0
    FCB $FF,$00,$1A          ; flag=-1, dy=0, dx=26
    FCB 2                ; End marker (path complete)

_LOGO_PATH2:    ; Path 2
    FCB 85              ; path2: intensity
    FCB $2B,$F0,0,0        ; path2: header (y=43, x=-16)
    FCB $FF,$F4,$00          ; flag=-1, dy=-12, dx=0
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$0C,$00          ; flag=-1, dy=12, dx=0
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB 2                ; End marker (path complete)

_LOGO_PATH3:    ; Path 3
    FCB 85              ; path3: intensity
    FCB $31,$E8,0,0        ; path3: header (y=49, x=-24)
    FCB $FF,$EE,$00          ; flag=-1, dy=-18, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$DB,$00          ; flag=-1, dy=-37, dx=0
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB $FF,$F5,$00          ; flag=-1, dy=-11, dx=0
    FCB $FF,$00,$18          ; flag=-1, dy=0, dx=24
    FCB $FF,$09,$00          ; flag=-1, dy=9, dx=0
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$27,$00          ; flag=-1, dy=39, dx=0
    FCB $FF,$00,$F6          ; flag=-1, dy=0, dx=-10
    FCB $FF,$12,$00          ; flag=-1, dy=18, dx=0
    FCB $FF,$00,$E6          ; flag=-1, dy=0, dx=-26
    FCB 2                ; End marker (path complete)
; Generated from text.vec (Malban Draw_Sync_List format)
; Total paths: 13, points: 98
; X bounds: min=-85, max=83, width=168
; Center: (-1, 0)

_TEXT_WIDTH EQU 168
_TEXT_HALF_WIDTH EQU 84
_TEXT_HEIGHT EQU 36
_TEXT_HALF_HEIGHT EQU 18
_TEXT_CENTER_X EQU -1
_TEXT_CENTER_Y EQU 0

_TEXT_VECTORS:  ; Main entry (header + 13 path(s))
    FDB 13               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _TEXT_PATH0        ; pointer to path 0
    FDB _TEXT_PATH1        ; pointer to path 1
    FDB _TEXT_PATH2        ; pointer to path 2
    FDB _TEXT_PATH3        ; pointer to path 3
    FDB _TEXT_PATH4        ; pointer to path 4
    FDB _TEXT_PATH5        ; pointer to path 5
    FDB _TEXT_PATH6        ; pointer to path 6
    FDB _TEXT_PATH7        ; pointer to path 7
    FDB _TEXT_PATH8        ; pointer to path 8
    FDB _TEXT_PATH9        ; pointer to path 9
    FDB _TEXT_PATH10        ; pointer to path 10
    FDB _TEXT_PATH11        ; pointer to path 11
    FDB _TEXT_PATH12        ; pointer to path 12

_TEXT_PATH0:    ; Path 0
    FCB 85              ; path0: intensity
    FCB $12,$FA,0,0        ; path0: header (y=18, x=-6)
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$EF,$00          ; flag=-1, dy=-17, dx=0
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$11,$00          ; flag=-1, dy=17, dx=0
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$04,$02          ; flag=-1, dy=4, dx=2
    FCB $FF,$00,$EE          ; flag=-1, dy=0, dx=-18
    FCB 2                ; End marker (path complete)

_TEXT_PATH1:    ; Path 1
    FCB 85              ; path1: intensity
    FCB $12,$F4,0,0        ; path1: header (y=18, x=-12)
    FCB $FF,$00,$F1          ; flag=-1, dy=0, dx=-15
    FCB $FF,$FC,$FD          ; flag=-1, dy=-4, dx=-3
    FCB $FF,$FA,$FD          ; flag=-1, dy=-6, dx=-3
    FCB $FF,$F8,$03          ; flag=-1, dy=-8, dx=3
    FCB $FF,$FD,$04          ; flag=-1, dy=-3, dx=4
    FCB $FF,$00,$0E          ; flag=-1, dy=0, dx=14
    FCB $FF,$03,$FD          ; flag=-1, dy=3, dx=-3
    FCB $FF,$00,$F7          ; flag=-1, dy=0, dx=-9
    FCB $FF,$02,$FD          ; flag=-1, dy=2, dx=-3
    FCB $FF,$06,$FE          ; flag=-1, dy=6, dx=-2
    FCB $FF,$04,$02          ; flag=-1, dy=4, dx=2
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$00,$0A          ; flag=-1, dy=0, dx=10
    FCB $FF,$04,$02          ; flag=-1, dy=4, dx=2
    FCB 2                ; End marker (path complete)

_TEXT_PATH2:    ; Path 2
    FCB 85              ; path2: intensity
    FCB $0E,$12,0,0        ; path2: header (y=14, x=18)
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$0F          ; flag=-1, dy=0, dx=15
    FCB $FF,$FD,$03          ; flag=-1, dy=-3, dx=3
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$FB,$FE          ; flag=-1, dy=-5, dx=-2
    FCB $FF,$FF,$FD          ; flag=-1, dy=-1, dx=-3
    FCB $FF,$F8,$05          ; flag=-1, dy=-8, dx=5
    FCB $FF,$00,$FB          ; flag=-1, dy=0, dx=-5
    FCB $FF,$08,$FC          ; flag=-1, dy=8, dx=-4
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$F8,$00          ; flag=-1, dy=-8, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$0C,$00          ; flag=-1, dy=12, dx=0
    FCB $FF,$00,$0C          ; flag=-1, dy=0, dx=12
    FCB $FF,$02,$03          ; flag=-1, dy=2, dx=3
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$00,$F4          ; flag=-1, dy=0, dx=-12
    FCB 2                ; End marker (path complete)

_TEXT_PATH3:    ; Path 3
    FCB 85              ; path3: intensity
    FCB $0B,$2A,0,0        ; path3: header (y=11, x=42)
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$10          ; flag=-1, dy=0, dx=16
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$F0          ; flag=-1, dy=0, dx=-16
    FCB 2                ; End marker (path complete)

_TEXT_PATH4:    ; Path 4
    FCB 85              ; path4: intensity
    FCB $12,$2A,0,0        ; path4: header (y=18, x=42)
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$10          ; flag=-1, dy=0, dx=16
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$F0          ; flag=-1, dy=0, dx=-16
    FCB 2                ; End marker (path complete)

_TEXT_PATH5:    ; Path 5
    FCB 85              ; path5: intensity
    FCB $00,$2A,0,0        ; path5: header (y=0, x=42)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$10          ; flag=-1, dy=0, dx=16
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$F0          ; flag=-1, dy=0, dx=-16
    FCB 2                ; End marker (path complete)

_TEXT_PATH6:    ; Path 6
    FCB 85              ; path6: intensity
    FCB $EE,$37,0,0        ; path6: header (y=-18, x=55)
    FCB $FF,$00,$12          ; flag=-1, dy=0, dx=18
    FCB 2                ; End marker (path complete)

_TEXT_PATH7:    ; Path 7
    FCB 85              ; path7: intensity
    FCB $12,$3D,0,0        ; path7: header (y=18, x=61)
    FCB $FF,$00,$07          ; flag=-1, dy=0, dx=7
    FCB $FF,$F8,$05          ; flag=-1, dy=-8, dx=5
    FCB $FF,$08,$05          ; flag=-1, dy=8, dx=5
    FCB $FF,$00,$06          ; flag=-1, dy=0, dx=6
    FCB $FF,$F5,$F7          ; flag=-1, dy=-11, dx=-9
    FCB $FF,$F6,$08          ; flag=-1, dy=-10, dx=8
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$07,$FC          ; flag=-1, dy=7, dx=-4
    FCB $FF,$F9,$FB          ; flag=-1, dy=-7, dx=-5
    FCB $FF,$00,$FA          ; flag=-1, dy=0, dx=-6
    FCB $FF,$0A,$09          ; flag=-1, dy=10, dx=9
    FCB $FF,$0B,$F6          ; flag=-1, dy=11, dx=-10
    FCB 2                ; End marker (path complete)

_TEXT_PATH8:    ; Path 8
    FCB 85              ; path8: intensity
    FCB $12,$C8,0,0        ; path8: header (y=18, x=-56)
    FCB $FF,$FC,$00          ; flag=-1, dy=-4, dx=0
    FCB $FF,$00,$11          ; flag=-1, dy=0, dx=17
    FCB $FF,$04,$00          ; flag=-1, dy=4, dx=0
    FCB $FF,$00,$EF          ; flag=-1, dy=0, dx=-17
    FCB 2                ; End marker (path complete)

_TEXT_PATH9:    ; Path 9
    FCB 85              ; path9: intensity
    FCB $0B,$C8,0,0        ; path9: header (y=11, x=-56)
    FCB $FF,$FA,$00          ; flag=-1, dy=-6, dx=0
    FCB $FF,$00,$11          ; flag=-1, dy=0, dx=17
    FCB $FF,$06,$00          ; flag=-1, dy=6, dx=0
    FCB $FF,$00,$EF          ; flag=-1, dy=0, dx=-17
    FCB 2                ; End marker (path complete)

_TEXT_PATH10:    ; Path 10
    FCB 85              ; path10: intensity
    FCB $00,$C8,0,0        ; path10: header (y=0, x=-56)
    FCB $FF,$FD,$00          ; flag=-1, dy=-3, dx=0
    FCB $FF,$00,$11          ; flag=-1, dy=0, dx=17
    FCB $FF,$03,$00          ; flag=-1, dy=3, dx=0
    FCB $FF,$00,$EF          ; flag=-1, dy=0, dx=-17
    FCB 2                ; End marker (path complete)

_TEXT_PATH11:    ; Path 11
    FCB 85              ; path11: intensity
    FCB $EE,$CB,0,0        ; path11: header (y=-18, x=-53)
    FCB $FF,$00,$EE          ; flag=-1, dy=0, dx=-18
    FCB 2                ; End marker (path complete)

_TEXT_PATH12:    ; Path 12
    FCB 85              ; path12: intensity
    FCB $12,$AC,0,0        ; path12: header (y=18, x=-84)
    FCB $FF,$00,$04          ; flag=-1, dy=0, dx=4
    FCB $FF,$F0,$08          ; flag=-1, dy=-16, dx=8
    FCB $FF,$10,$07          ; flag=-1, dy=16, dx=7
    FCB $FF,$00,$03          ; flag=-1, dy=0, dx=3
    FCB $FF,$EB,$F7          ; flag=-1, dy=-21, dx=-9
    FCB $FF,$00,$FD          ; flag=-1, dy=0, dx=-3
    FCB $FF,$15,$F6          ; flag=-1, dy=21, dx=-10
    FCB 2                ; End marker (path complete)
; Generated from jingle.vmus (internal name: Vectrex Studio - Boot Jingle)
; Tempo: 150 BPM, Total events: 17 (PSG Direct format)
; Format: FCB count, FCB reg, val, ... (per frame), FCB 0 (end)

_JINGLE_MUSIC:
    ; Frame-based PSG register writes
    FCB     0              ; Delay 0 frames (maintain previous state)
    FCB     8              ; Frame 0 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $2C             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $01             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0B             ; Reg 8 value
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
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     8              ; Frame 10 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $EE             ; Reg 0 value
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
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     8              ; Frame 20 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $C8             ; Reg 0 value
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
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     8              ; Frame 30 - 8 register writes
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
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     8              ; Frame 40 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $77             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0D             ; Reg 8 value
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
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     8              ; Frame 50 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $64             ; Reg 0 value
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
    FCB     10              ; Delay 10 frames (maintain previous state)
    FCB     8              ; Frame 60 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $77             ; Reg 0 value
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
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     8              ; Frame 65 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $64             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
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
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     8              ; Frame 70 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $59             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
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
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     8              ; Frame 75 - 8 register writes
    FCB     0               ; Reg 0 number
    FCB     $64             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0E             ; Reg 8 value
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
    FCB     5              ; Delay 5 frames (maintain previous state)
    FCB     10              ; Frame 80 - 10 register writes
    FCB     0               ; Reg 0 number
    FCB     $64             ; Reg 0 value
    FCB     1               ; Reg 1 number
    FCB     $00             ; Reg 1 value
    FCB     8               ; Reg 8 number
    FCB     $0F             ; Reg 8 value
    FCB     2               ; Reg 2 number
    FCB     $2C             ; Reg 2 value
    FCB     3               ; Reg 3 number
    FCB     $01             ; Reg 3 value
    FCB     9               ; Reg 9 number
    FCB     $0D             ; Reg 9 value
    FCB     4               ; Reg 4 number
    FCB     $77             ; Reg 4 value
    FCB     5               ; Reg 5 number
    FCB     $00             ; Reg 5 value
    FCB     10               ; Reg 10 number
    FCB     $0D             ; Reg 10 value
    FCB     7               ; Reg 7 number
    FCB     $38             ; Reg 7 value
    FCB     0               ; End of music (no loop)

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

; ============================================================================
; SMUL_PROD - Product lookup table for SMUL_LUT
; SMUL_PROD[val][angle] = (val * sin(angle*2π/128)) >> 7  (i8)
; val=row (0-63, stride=128), angle=col (0-127) — 8KB total
; For cos: use angle=(ax+32)&0x7F — same table, shifted column
; Vertex coords must be ≤63 (clamped at data emit time)
SMUL_PROD:
    FCB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; val=0
    FCB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00  ; val=1
    FCB $00,$00,$00,$00,$00,$00,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00  ; val=2
    FCB $00,$00,$00,$00,$01,$01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$03,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$01,$01,$01,$01,$01,$01,$01,$00,$00,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00  ; val=3
    FCB $00,$00,$00,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$03,$03,$03,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$04,$03,$03,$03,$03,$03,$03,$03,$03,$02,$02,$02,$02,$02,$02,$01,$01,$01,$01,$01,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FE,$FE,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FD,$FE,$FE,$FE,$FE,$FE,$FE,$FF,$FF,$FF,$FF,$FF,$00,$00  ; val=4
    FCB $00,$00,$00,$01,$01,$01,$01,$02,$02,$02,$02,$03,$03,$03,$03,$03,$04,$04,$04,$04,$04,$04,$04,$04,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$04,$04,$04,$04,$04,$04,$04,$04,$03,$03,$03,$03,$03,$02,$02,$02,$02,$01,$01,$01,$01,$00,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FE,$FD,$FD,$FD,$FD,$FD,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FC,$FD,$FD,$FD,$FD,$FD,$FE,$FE,$FE,$FE,$FF,$FF,$FF,$FF,$00,$00  ; val=5
    FCB $00,$00,$01,$01,$01,$01,$02,$02,$02,$03,$03,$03,$03,$04,$04,$04,$04,$04,$05,$05,$05,$05,$05,$05,$05,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$06,$05,$05,$05,$05,$05,$05,$05,$04,$04,$04,$04,$04,$03,$03,$03,$03,$02,$02,$02,$01,$01,$01,$01,$00,$00,$00,$FF,$FF,$FF,$FF,$FE,$FE,$FE,$FD,$FD,$FD,$FD,$FC,$FC,$FC,$FC,$FC,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FA,$FA,$FA,$FA,$FA,$FA,$FA,$FA,$FA,$FA,$FA,$FA,$FA,$FA,$FA,$FB,$FB,$FB,$FB,$FB,$FB,$FB,$FC,$FC,$FC,$FC,$FC,$FD,$FD,$FD,$FD,$FE,$FE,$FE,$FF,$FF,$FF,$FF,$00  ; val=6
    FCB $00,$00,$01,$01,$01,$02,$02,$02,$03,$03,$03,$04,$04,$04,$04,$05,$05,$05,$05,$06,$06,$06,$06,$06,$06,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$07,$06,$06,$06,$06,$06,$06,$05,$05,$05,$05,$04,$04,$04,$04,$03,$03,$03,$02,$02,$02,$01,$01,$01,$00,$00,$00,$FF,$FF,$FF,$FE,$FE,$FE,$FD,$FD,$FD,$FC,$FC,$FC,$FC,$FB,$FB,$FB,$FB,$FA,$FA,$FA,$FA,$FA,$FA,$F9,$F9,$F9,$F9,$F9,$F9,$F9,$F9,$F9,$F9,$F9,$F9,$F9,$F9,$F9,$FA,$FA,$FA,$FA,$FA,$FA,$FB,$FB,$FB,$FB,$FC,$FC,$FC,$FC,$FD,$FD,$FD,$FE,$FE,$FE,$FF,$FF,$FF,$00  ; val=7
    FCB $00,$00,$01,$01,$02,$02,$02,$03,$03,$03,$04,$04,$04,$05,$05,$05,$06,$06,$06,$06,$07,$07,$07,$07,$07,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$08,$07,$07,$07,$07,$07,$06,$06,$06,$06,$05,$05,$05,$04,$04,$04,$03,$03,$03,$02,$02,$02,$01,$01,$00,$00,$00,$FF,$FF,$FE,$FE,$FE,$FD,$FD,$FD,$FC,$FC,$FC,$FB,$FB,$FB,$FA,$FA,$FA,$FA,$F9,$F9,$F9,$F9,$F9,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F8,$F9,$F9,$F9,$F9,$F9,$FA,$FA,$FA,$FA,$FB,$FB,$FB,$FC,$FC,$FC,$FD,$FD,$FD,$FE,$FE,$FE,$FF,$FF,$00  ; val=8
    FCB $00,$00,$01,$01,$02,$02,$03,$03,$03,$04,$04,$05,$05,$05,$06,$06,$06,$07,$07,$07,$07,$08,$08,$08,$08,$08,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$08,$08,$08,$08,$08,$07,$07,$07,$07,$06,$06,$06,$05,$05,$05,$04,$04,$03,$03,$03,$02,$02,$01,$01,$00,$00,$00,$FF,$FF,$FE,$FE,$FD,$FD,$FD,$FC,$FC,$FB,$FB,$FB,$FA,$FA,$FA,$F9,$F9,$F9,$F9,$F8,$F8,$F8,$F8,$F8,$F7,$F7,$F7,$F7,$F7,$F7,$F7,$F7,$F7,$F7,$F7,$F7,$F7,$F8,$F8,$F8,$F8,$F8,$F9,$F9,$F9,$F9,$FA,$FA,$FA,$FB,$FB,$FB,$FC,$FC,$FD,$FD,$FD,$FE,$FE,$FF,$FF,$00  ; val=9
    FCB $00,$00,$01,$01,$02,$02,$03,$03,$04,$04,$05,$05,$06,$06,$06,$07,$07,$07,$08,$08,$08,$09,$09,$09,$09,$09,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A,$09,$09,$09,$09,$09,$08,$08,$08,$07,$07,$07,$06,$06,$06,$05,$05,$04,$04,$03,$03,$02,$02,$01,$01,$00,$00,$00,$FF,$FF,$FE,$FE,$FD,$FD,$FC,$FC,$FB,$FB,$FA,$FA,$FA,$F9,$F9,$F9,$F8,$F8,$F8,$F7,$F7,$F7,$F7,$F7,$F6,$F6,$F6,$F6,$F6,$F6,$F6,$F6,$F6,$F6,$F6,$F6,$F6,$F7,$F7,$F7,$F7,$F7,$F8,$F8,$F8,$F9,$F9,$F9,$FA,$FA,$FA,$FB,$FB,$FC,$FC,$FD,$FD,$FE,$FE,$FF,$FF,$00  ; val=10
    FCB $00,$01,$01,$02,$02,$03,$03,$04,$04,$05,$05,$06,$06,$07,$07,$07,$08,$08,$08,$09,$09,$09,$0A,$0A,$0A,$0A,$0A,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B,$0A,$0A,$0A,$0A,$0A,$09,$09,$09,$08,$08,$08,$07,$07,$07,$06,$06,$05,$05,$04,$04,$03,$03,$02,$02,$01,$01,$00,$FF,$FF,$FE,$FE,$FD,$FD,$FC,$FC,$FB,$FB,$FA,$FA,$F9,$F9,$F9,$F8,$F8,$F8,$F7,$F7,$F7,$F6,$F6,$F6,$F6,$F6,$F5,$F5,$F5,$F5,$F5,$F5,$F5,$F5,$F5,$F5,$F5,$F6,$F6,$F6,$F6,$F6,$F7,$F7,$F7,$F8,$F8,$F8,$F9,$F9,$F9,$FA,$FA,$FB,$FB,$FC,$FC,$FD,$FD,$FE,$FE,$FF,$FF  ; val=11
    FCB $00,$01,$01,$02,$02,$03,$03,$04,$05,$05,$06,$06,$07,$07,$08,$08,$08,$09,$09,$0A,$0A,$0A,$0B,$0B,$0B,$0B,$0B,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0B,$0B,$0B,$0B,$0B,$0A,$0A,$0A,$09,$09,$08,$08,$08,$07,$07,$06,$06,$05,$05,$04,$03,$03,$02,$02,$01,$01,$00,$FF,$FF,$FE,$FE,$FD,$FD,$FC,$FB,$FB,$FA,$FA,$F9,$F9,$F8,$F8,$F8,$F7,$F7,$F6,$F6,$F6,$F5,$F5,$F5,$F5,$F5,$F4,$F4,$F4,$F4,$F4,$F4,$F4,$F4,$F4,$F4,$F4,$F5,$F5,$F5,$F5,$F5,$F6,$F6,$F6,$F7,$F7,$F8,$F8,$F8,$F9,$F9,$FA,$FA,$FB,$FB,$FC,$FD,$FD,$FE,$FE,$FF,$FF  ; val=12
    FCB $00,$01,$01,$02,$03,$03,$04,$04,$05,$05,$06,$07,$07,$08,$08,$09,$09,$0A,$0A,$0A,$0B,$0B,$0B,$0C,$0C,$0C,$0C,$0C,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0C,$0C,$0C,$0C,$0C,$0B,$0B,$0B,$0A,$0A,$0A,$09,$09,$08,$08,$07,$07,$06,$05,$05,$04,$04,$03,$03,$02,$01,$01,$00,$FF,$FF,$FE,$FD,$FD,$FC,$FC,$FB,$FB,$FA,$F9,$F9,$F8,$F8,$F7,$F7,$F6,$F6,$F6,$F5,$F5,$F5,$F4,$F4,$F4,$F4,$F4,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F3,$F4,$F4,$F4,$F4,$F4,$F5,$F5,$F5,$F6,$F6,$F6,$F7,$F7,$F8,$F8,$F9,$F9,$FA,$FB,$FB,$FC,$FC,$FD,$FD,$FE,$FF,$FF  ; val=13
    FCB $00,$01,$01,$02,$03,$03,$04,$05,$05,$06,$07,$07,$08,$08,$09,$09,$0A,$0A,$0B,$0B,$0C,$0C,$0C,$0D,$0D,$0D,$0D,$0D,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0D,$0D,$0D,$0D,$0D,$0C,$0C,$0C,$0B,$0B,$0A,$0A,$09,$09,$08,$08,$07,$07,$06,$05,$05,$04,$03,$03,$02,$01,$01,$00,$FF,$FF,$FE,$FD,$FD,$FC,$FB,$FB,$FA,$F9,$F9,$F8,$F8,$F7,$F7,$F6,$F6,$F5,$F5,$F4,$F4,$F4,$F3,$F3,$F3,$F3,$F3,$F2,$F2,$F2,$F2,$F2,$F2,$F2,$F2,$F2,$F3,$F3,$F3,$F3,$F3,$F4,$F4,$F4,$F5,$F5,$F6,$F6,$F7,$F7,$F8,$F8,$F9,$F9,$FA,$FB,$FB,$FC,$FD,$FD,$FE,$FF,$FF  ; val=14
    FCB $00,$01,$01,$02,$03,$04,$04,$05,$06,$06,$07,$08,$08,$09,$09,$0A,$0B,$0B,$0B,$0C,$0C,$0D,$0D,$0D,$0E,$0E,$0E,$0E,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0E,$0E,$0E,$0E,$0D,$0D,$0D,$0C,$0C,$0B,$0B,$0B,$0A,$09,$09,$08,$08,$07,$06,$06,$05,$04,$04,$03,$02,$01,$01,$00,$FF,$FF,$FE,$FD,$FC,$FC,$FB,$FA,$FA,$F9,$F8,$F8,$F7,$F7,$F6,$F5,$F5,$F5,$F4,$F4,$F3,$F3,$F3,$F2,$F2,$F2,$F2,$F1,$F1,$F1,$F1,$F1,$F1,$F1,$F1,$F1,$F2,$F2,$F2,$F2,$F3,$F3,$F3,$F4,$F4,$F5,$F5,$F5,$F6,$F7,$F7,$F8,$F8,$F9,$FA,$FA,$FB,$FC,$FC,$FD,$FE,$FF,$FF  ; val=15
    FCB $00,$01,$02,$02,$03,$04,$05,$05,$06,$07,$08,$08,$09,$0A,$0A,$0B,$0B,$0C,$0C,$0D,$0D,$0E,$0E,$0E,$0F,$0F,$0F,$0F,$10,$10,$10,$10,$10,$10,$10,$10,$10,$0F,$0F,$0F,$0F,$0E,$0E,$0E,$0D,$0D,$0C,$0C,$0B,$0B,$0A,$0A,$09,$08,$08,$07,$06,$05,$05,$04,$03,$02,$02,$01,$00,$FF,$FE,$FE,$FD,$FC,$FB,$FB,$FA,$F9,$F8,$F8,$F7,$F6,$F6,$F5,$F5,$F4,$F4,$F3,$F3,$F2,$F2,$F2,$F1,$F1,$F1,$F1,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F1,$F1,$F1,$F1,$F2,$F2,$F2,$F3,$F3,$F4,$F4,$F5,$F5,$F6,$F6,$F7,$F8,$F8,$F9,$FA,$FB,$FB,$FC,$FD,$FE,$FE,$FF  ; val=16
    FCB $00,$01,$02,$03,$03,$04,$05,$06,$07,$07,$08,$09,$09,$0A,$0B,$0B,$0C,$0C,$0D,$0E,$0E,$0E,$0F,$0F,$10,$10,$10,$10,$11,$11,$11,$11,$11,$11,$11,$11,$11,$10,$10,$10,$10,$0F,$0F,$0E,$0E,$0E,$0D,$0C,$0C,$0B,$0B,$0A,$09,$09,$08,$07,$07,$06,$05,$04,$03,$03,$02,$01,$00,$FF,$FE,$FD,$FD,$FC,$FB,$FA,$F9,$F9,$F8,$F7,$F7,$F6,$F5,$F5,$F4,$F4,$F3,$F2,$F2,$F2,$F1,$F1,$F0,$F0,$F0,$F0,$EF,$EF,$EF,$EF,$EF,$EF,$EF,$EF,$EF,$F0,$F0,$F0,$F0,$F1,$F1,$F2,$F2,$F2,$F3,$F4,$F4,$F5,$F5,$F6,$F7,$F7,$F8,$F9,$F9,$FA,$FB,$FC,$FD,$FD,$FE,$FF  ; val=17
    FCB $00,$01,$02,$03,$04,$04,$05,$06,$07,$08,$08,$09,$0A,$0B,$0B,$0C,$0D,$0D,$0E,$0E,$0F,$0F,$10,$10,$10,$11,$11,$11,$12,$12,$12,$12,$12,$12,$12,$12,$12,$11,$11,$11,$10,$10,$10,$0F,$0F,$0E,$0E,$0D,$0D,$0C,$0B,$0B,$0A,$09,$08,$08,$07,$06,$05,$04,$04,$03,$02,$01,$00,$FF,$FE,$FD,$FC,$FC,$FB,$FA,$F9,$F8,$F8,$F7,$F6,$F5,$F5,$F4,$F3,$F3,$F2,$F2,$F1,$F1,$F0,$F0,$F0,$EF,$EF,$EF,$EE,$EE,$EE,$EE,$EE,$EE,$EE,$EE,$EE,$EF,$EF,$EF,$F0,$F0,$F0,$F1,$F1,$F2,$F2,$F3,$F3,$F4,$F5,$F5,$F6,$F7,$F8,$F8,$F9,$FA,$FB,$FC,$FC,$FD,$FE,$FF  ; val=18
    FCB $00,$01,$02,$03,$04,$05,$05,$06,$07,$08,$09,$0A,$0B,$0B,$0C,$0D,$0D,$0E,$0F,$0F,$10,$10,$11,$11,$11,$12,$12,$12,$13,$13,$13,$13,$13,$13,$13,$13,$13,$12,$12,$12,$11,$11,$11,$10,$10,$0F,$0F,$0E,$0D,$0D,$0C,$0B,$0B,$0A,$09,$08,$07,$06,$05,$05,$04,$03,$02,$01,$00,$FF,$FE,$FD,$FC,$FB,$FB,$FA,$F9,$F8,$F7,$F6,$F5,$F5,$F4,$F3,$F3,$F2,$F1,$F1,$F0,$F0,$EF,$EF,$EF,$EE,$EE,$EE,$ED,$ED,$ED,$ED,$ED,$ED,$ED,$ED,$ED,$EE,$EE,$EE,$EF,$EF,$EF,$F0,$F0,$F1,$F1,$F2,$F3,$F3,$F4,$F5,$F5,$F6,$F7,$F8,$F9,$FA,$FB,$FB,$FC,$FD,$FE,$FF  ; val=19
    FCB $00,$01,$02,$03,$04,$05,$06,$07,$08,$08,$09,$0A,$0B,$0C,$0D,$0D,$0E,$0F,$0F,$10,$11,$11,$12,$12,$12,$13,$13,$13,$14,$14,$14,$14,$14,$14,$14,$14,$14,$13,$13,$13,$12,$12,$12,$11,$11,$10,$0F,$0F,$0E,$0D,$0D,$0C,$0B,$0A,$09,$08,$08,$07,$06,$05,$04,$03,$02,$01,$00,$FF,$FE,$FD,$FC,$FB,$FA,$F9,$F8,$F8,$F7,$F6,$F5,$F4,$F3,$F3,$F2,$F1,$F1,$F0,$EF,$EF,$EE,$EE,$EE,$ED,$ED,$ED,$EC,$EC,$EC,$EC,$EC,$EC,$EC,$EC,$EC,$ED,$ED,$ED,$EE,$EE,$EE,$EF,$EF,$F0,$F1,$F1,$F2,$F3,$F3,$F4,$F5,$F6,$F7,$F8,$F8,$F9,$FA,$FB,$FC,$FD,$FE,$FF  ; val=20
    FCB $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0C,$0D,$0E,$0F,$0F,$10,$11,$11,$12,$12,$13,$13,$14,$14,$14,$15,$15,$15,$15,$15,$15,$15,$15,$15,$14,$14,$14,$13,$13,$12,$12,$11,$11,$10,$0F,$0F,$0E,$0D,$0C,$0C,$0B,$0A,$09,$08,$07,$06,$05,$04,$03,$02,$01,$00,$FF,$FE,$FD,$FC,$FB,$FA,$F9,$F8,$F7,$F6,$F5,$F4,$F4,$F3,$F2,$F1,$F1,$F0,$EF,$EF,$EE,$EE,$ED,$ED,$EC,$EC,$EC,$EB,$EB,$EB,$EB,$EB,$EB,$EB,$EB,$EB,$EC,$EC,$EC,$ED,$ED,$EE,$EE,$EF,$EF,$F0,$F1,$F1,$F2,$F3,$F4,$F4,$F5,$F6,$F7,$F8,$F9,$FA,$FB,$FC,$FD,$FE,$FF  ; val=21
    FCB $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F,$0F,$10,$11,$12,$12,$13,$13,$14,$14,$15,$15,$15,$15,$16,$16,$16,$16,$16,$16,$16,$15,$15,$15,$15,$14,$14,$13,$13,$12,$12,$11,$10,$0F,$0F,$0E,$0D,$0C,$0B,$0A,$09,$08,$07,$06,$05,$04,$03,$02,$01,$00,$FF,$FE,$FD,$FC,$FB,$FA,$F9,$F8,$F7,$F6,$F5,$F4,$F3,$F2,$F1,$F1,$F0,$EF,$EE,$EE,$ED,$ED,$EC,$EC,$EB,$EB,$EB,$EB,$EA,$EA,$EA,$EA,$EA,$EA,$EA,$EB,$EB,$EB,$EB,$EC,$EC,$ED,$ED,$EE,$EE,$EF,$F0,$F1,$F1,$F2,$F3,$F4,$F5,$F6,$F7,$F8,$F9,$FA,$FB,$FC,$FD,$FE,$FF  ; val=22
    FCB $00,$01,$02,$03,$04,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F,$0F,$10,$11,$12,$12,$13,$14,$14,$15,$15,$16,$16,$16,$16,$17,$17,$17,$17,$17,$17,$17,$16,$16,$16,$16,$15,$15,$14,$14,$13,$12,$12,$11,$10,$0F,$0F,$0E,$0D,$0C,$0B,$0A,$09,$08,$07,$06,$04,$03,$02,$01,$00,$FF,$FE,$FD,$FC,$FA,$F9,$F8,$F7,$F6,$F5,$F4,$F3,$F2,$F1,$F1,$F0,$EF,$EE,$EE,$ED,$EC,$EC,$EB,$EB,$EA,$EA,$EA,$EA,$E9,$E9,$E9,$E9,$E9,$E9,$E9,$EA,$EA,$EA,$EA,$EB,$EB,$EC,$EC,$ED,$EE,$EE,$EF,$F0,$F1,$F1,$F2,$F3,$F4,$F5,$F6,$F7,$F8,$F9,$FA,$FC,$FD,$FE,$FF  ; val=23
    FCB $00,$01,$02,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F,$10,$11,$12,$12,$13,$14,$14,$15,$16,$16,$17,$17,$17,$17,$18,$18,$18,$18,$18,$18,$18,$17,$17,$17,$17,$16,$16,$15,$14,$14,$13,$12,$12,$11,$10,$0F,$0E,$0D,$0C,$0B,$0A,$09,$08,$07,$06,$05,$04,$02,$01,$00,$FF,$FE,$FC,$FB,$FA,$F9,$F8,$F7,$F6,$F5,$F4,$F3,$F2,$F1,$F0,$EF,$EE,$EE,$ED,$EC,$EC,$EB,$EA,$EA,$E9,$E9,$E9,$E9,$E8,$E8,$E8,$E8,$E8,$E8,$E8,$E9,$E9,$E9,$E9,$EA,$EA,$EB,$EC,$EC,$ED,$EE,$EE,$EF,$F0,$F1,$F2,$F3,$F4,$F5,$F6,$F7,$F8,$F9,$FA,$FB,$FC,$FE,$FF  ; val=24
    FCB $00,$01,$02,$04,$05,$06,$07,$08,$0A,$0B,$0C,$0D,$0E,$0F,$10,$11,$12,$12,$13,$14,$15,$15,$16,$16,$17,$17,$18,$18,$18,$19,$19,$19,$19,$19,$19,$19,$18,$18,$18,$17,$17,$16,$16,$15,$15,$14,$13,$12,$12,$11,$10,$0F,$0E,$0D,$0C,$0B,$0A,$08,$07,$06,$05,$04,$02,$01,$00,$FF,$FE,$FC,$FB,$FA,$F9,$F8,$F6,$F5,$F4,$F3,$F2,$F1,$F0,$EF,$EE,$EE,$ED,$EC,$EB,$EB,$EA,$EA,$E9,$E9,$E8,$E8,$E8,$E7,$E7,$E7,$E7,$E7,$E7,$E7,$E8,$E8,$E8,$E9,$E9,$EA,$EA,$EB,$EB,$EC,$ED,$EE,$EE,$EF,$F0,$F1,$F2,$F3,$F4,$F5,$F6,$F8,$F9,$FA,$FB,$FC,$FE,$FF  ; val=25
    FCB $00,$01,$02,$04,$05,$06,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F,$10,$11,$12,$13,$14,$15,$16,$16,$17,$17,$18,$18,$19,$19,$19,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$19,$19,$19,$18,$18,$17,$17,$16,$16,$15,$14,$13,$12,$11,$10,$0F,$0E,$0D,$0C,$0B,$0A,$09,$08,$06,$05,$04,$02,$01,$00,$FF,$FE,$FC,$FB,$FA,$F8,$F7,$F6,$F5,$F4,$F3,$F2,$F1,$F0,$EF,$EE,$ED,$EC,$EB,$EA,$EA,$E9,$E9,$E8,$E8,$E7,$E7,$E7,$E6,$E6,$E6,$E6,$E6,$E6,$E6,$E7,$E7,$E7,$E8,$E8,$E9,$E9,$EA,$EA,$EB,$EC,$ED,$EE,$EF,$F0,$F1,$F2,$F3,$F4,$F5,$F6,$F7,$F8,$FA,$FB,$FC,$FE,$FF  ; val=26
    FCB $00,$01,$03,$04,$05,$07,$08,$09,$0A,$0B,$0D,$0E,$0F,$10,$11,$12,$13,$14,$15,$16,$16,$17,$18,$18,$19,$19,$1A,$1A,$1A,$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1A,$1A,$1A,$19,$19,$18,$18,$17,$16,$16,$15,$14,$13,$12,$11,$10,$0F,$0E,$0D,$0B,$0A,$09,$08,$07,$05,$04,$03,$01,$00,$FF,$FD,$FC,$FB,$F9,$F8,$F7,$F6,$F5,$F3,$F2,$F1,$F0,$EF,$EE,$ED,$EC,$EB,$EA,$EA,$E9,$E8,$E8,$E7,$E7,$E6,$E6,$E6,$E5,$E5,$E5,$E5,$E5,$E5,$E5,$E6,$E6,$E6,$E7,$E7,$E8,$E8,$E9,$EA,$EA,$EB,$EC,$ED,$EE,$EF,$F0,$F1,$F2,$F3,$F5,$F6,$F7,$F8,$F9,$FB,$FC,$FD,$FF  ; val=27
    FCB $00,$01,$03,$04,$05,$07,$08,$09,$0B,$0C,$0D,$0E,$10,$11,$12,$13,$14,$15,$15,$16,$17,$18,$19,$19,$1A,$1A,$1B,$1B,$1B,$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1B,$1B,$1B,$1A,$1A,$19,$19,$18,$17,$16,$15,$15,$14,$13,$12,$11,$10,$0E,$0D,$0C,$0B,$09,$08,$07,$05,$04,$03,$01,$00,$FF,$FD,$FC,$FB,$F9,$F8,$F7,$F5,$F4,$F3,$F2,$F0,$EF,$EE,$ED,$EC,$EB,$EB,$EA,$E9,$E8,$E7,$E7,$E6,$E6,$E5,$E5,$E5,$E4,$E4,$E4,$E4,$E4,$E4,$E4,$E5,$E5,$E5,$E6,$E6,$E7,$E7,$E8,$E9,$EA,$EB,$EB,$EC,$ED,$EE,$EF,$F0,$F2,$F3,$F4,$F5,$F7,$F8,$F9,$FB,$FC,$FD,$FF  ; val=28
    FCB $00,$01,$03,$04,$06,$07,$08,$0A,$0B,$0C,$0E,$0F,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$19,$1A,$1B,$1B,$1C,$1C,$1C,$1D,$1D,$1D,$1D,$1D,$1D,$1D,$1C,$1C,$1C,$1B,$1B,$1A,$19,$19,$18,$17,$16,$15,$14,$13,$12,$11,$10,$0F,$0E,$0C,$0B,$0A,$08,$07,$06,$04,$03,$01,$00,$FF,$FD,$FC,$FA,$F9,$F8,$F6,$F5,$F4,$F2,$F1,$F0,$EF,$EE,$ED,$EC,$EB,$EA,$E9,$E8,$E7,$E7,$E6,$E5,$E5,$E4,$E4,$E4,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E4,$E4,$E4,$E5,$E5,$E6,$E7,$E7,$E8,$E9,$EA,$EB,$EC,$ED,$EE,$EF,$F0,$F1,$F2,$F4,$F5,$F6,$F8,$F9,$FA,$FC,$FD,$FF  ; val=29
    FCB $00,$01,$03,$04,$06,$07,$09,$0A,$0B,$0D,$0E,$0F,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1A,$1A,$1B,$1B,$1C,$1D,$1D,$1D,$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1D,$1D,$1D,$1C,$1B,$1B,$1A,$1A,$19,$18,$17,$16,$15,$14,$13,$12,$11,$0F,$0E,$0D,$0B,$0A,$09,$07,$06,$04,$03,$01,$00,$FF,$FD,$FC,$FA,$F9,$F7,$F6,$F5,$F3,$F2,$F1,$EF,$EE,$ED,$EC,$EB,$EA,$E9,$E8,$E7,$E6,$E6,$E5,$E5,$E4,$E3,$E3,$E3,$E2,$E2,$E2,$E2,$E2,$E2,$E2,$E3,$E3,$E3,$E4,$E5,$E5,$E6,$E6,$E7,$E8,$E9,$EA,$EB,$EC,$ED,$EE,$EF,$F1,$F2,$F3,$F5,$F6,$F7,$F9,$FA,$FC,$FD,$FF  ; val=30
    FCB $00,$01,$03,$05,$06,$08,$09,$0A,$0C,$0D,$0F,$10,$11,$12,$14,$15,$16,$17,$18,$19,$1A,$1A,$1B,$1C,$1C,$1D,$1E,$1E,$1E,$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1E,$1E,$1E,$1D,$1C,$1C,$1B,$1A,$1A,$19,$18,$17,$16,$15,$14,$12,$11,$10,$0F,$0D,$0C,$0A,$09,$08,$06,$05,$03,$01,$00,$FF,$FD,$FB,$FA,$F8,$F7,$F6,$F4,$F3,$F1,$F0,$EF,$EE,$EC,$EB,$EA,$E9,$E8,$E7,$E6,$E6,$E5,$E4,$E4,$E3,$E2,$E2,$E2,$E1,$E1,$E1,$E1,$E1,$E1,$E1,$E2,$E2,$E2,$E3,$E4,$E4,$E5,$E6,$E6,$E7,$E8,$E9,$EA,$EB,$EC,$EE,$EF,$F0,$F1,$F3,$F4,$F6,$F7,$F8,$FA,$FB,$FD,$FF  ; val=31
    FCB $00,$02,$03,$05,$06,$08,$09,$0B,$0C,$0E,$0F,$10,$12,$13,$14,$15,$17,$18,$19,$1A,$1B,$1B,$1C,$1D,$1D,$1E,$1F,$1F,$1F,$20,$20,$20,$20,$20,$20,$20,$1F,$1F,$1F,$1E,$1D,$1D,$1C,$1B,$1B,$1A,$19,$18,$17,$15,$14,$13,$12,$10,$0F,$0E,$0C,$0B,$09,$08,$06,$05,$03,$02,$00,$FE,$FD,$FB,$FA,$F8,$F7,$F5,$F4,$F2,$F1,$F0,$EE,$ED,$EC,$EB,$E9,$E8,$E7,$E6,$E5,$E5,$E4,$E3,$E3,$E2,$E1,$E1,$E1,$E0,$E0,$E0,$E0,$E0,$E0,$E0,$E1,$E1,$E1,$E2,$E3,$E3,$E4,$E5,$E5,$E6,$E7,$E8,$E9,$EB,$EC,$ED,$EE,$F0,$F1,$F2,$F4,$F5,$F7,$F8,$FA,$FB,$FD,$FE  ; val=32
    FCB $00,$02,$03,$05,$06,$08,$0A,$0B,$0D,$0E,$0F,$11,$12,$14,$15,$16,$17,$18,$19,$1A,$1B,$1C,$1D,$1E,$1E,$1F,$1F,$20,$20,$20,$20,$21,$21,$21,$20,$20,$20,$20,$1F,$1F,$1E,$1E,$1D,$1C,$1B,$1A,$19,$18,$17,$16,$15,$14,$12,$11,$0F,$0E,$0D,$0B,$0A,$08,$06,$05,$03,$02,$00,$FE,$FD,$FB,$FA,$F8,$F6,$F5,$F3,$F2,$F1,$EF,$EE,$EC,$EB,$EA,$E9,$E8,$E7,$E6,$E5,$E4,$E3,$E2,$E2,$E1,$E1,$E0,$E0,$E0,$E0,$DF,$DF,$DF,$E0,$E0,$E0,$E0,$E1,$E1,$E2,$E2,$E3,$E4,$E5,$E6,$E7,$E8,$E9,$EA,$EB,$EC,$EE,$EF,$F1,$F2,$F3,$F5,$F6,$F8,$FA,$FB,$FD,$FE  ; val=33
    FCB $00,$02,$03,$05,$07,$08,$0A,$0B,$0D,$0E,$10,$11,$13,$14,$16,$17,$18,$19,$1A,$1B,$1C,$1D,$1E,$1F,$1F,$20,$20,$21,$21,$21,$21,$22,$22,$22,$21,$21,$21,$21,$20,$20,$1F,$1F,$1E,$1D,$1C,$1B,$1A,$19,$18,$17,$16,$14,$13,$11,$10,$0E,$0D,$0B,$0A,$08,$07,$05,$03,$02,$00,$FE,$FD,$FB,$F9,$F8,$F6,$F5,$F3,$F2,$F0,$EF,$ED,$EC,$EA,$E9,$E8,$E7,$E6,$E5,$E4,$E3,$E2,$E1,$E1,$E0,$E0,$DF,$DF,$DF,$DF,$DE,$DE,$DE,$DF,$DF,$DF,$DF,$E0,$E0,$E1,$E1,$E2,$E3,$E4,$E5,$E6,$E7,$E8,$E9,$EA,$EC,$ED,$EF,$F0,$F2,$F3,$F5,$F6,$F8,$F9,$FB,$FD,$FE  ; val=34
    FCB $00,$02,$03,$05,$07,$08,$0A,$0C,$0D,$0F,$10,$12,$13,$15,$16,$17,$19,$1A,$1B,$1C,$1D,$1E,$1F,$1F,$20,$21,$21,$22,$22,$22,$22,$23,$23,$23,$22,$22,$22,$22,$21,$21,$20,$1F,$1F,$1E,$1D,$1C,$1B,$1A,$19,$17,$16,$15,$13,$12,$10,$0F,$0D,$0C,$0A,$08,$07,$05,$03,$02,$00,$FE,$FD,$FB,$F9,$F8,$F6,$F4,$F3,$F1,$F0,$EE,$ED,$EB,$EA,$E9,$E7,$E6,$E5,$E4,$E3,$E2,$E1,$E1,$E0,$DF,$DF,$DE,$DE,$DE,$DE,$DD,$DD,$DD,$DE,$DE,$DE,$DE,$DF,$DF,$E0,$E1,$E1,$E2,$E3,$E4,$E5,$E6,$E7,$E9,$EA,$EB,$ED,$EE,$F0,$F1,$F3,$F4,$F6,$F8,$F9,$FB,$FD,$FE  ; val=35
    FCB $00,$02,$03,$05,$07,$09,$0A,$0C,$0E,$0F,$11,$12,$14,$15,$17,$18,$19,$1A,$1C,$1D,$1E,$1F,$20,$20,$21,$22,$22,$23,$23,$23,$23,$24,$24,$24,$23,$23,$23,$23,$22,$22,$21,$20,$20,$1F,$1E,$1D,$1C,$1A,$19,$18,$17,$15,$14,$12,$11,$0F,$0E,$0C,$0A,$09,$07,$05,$03,$02,$00,$FE,$FD,$FB,$F9,$F7,$F6,$F4,$F2,$F1,$EF,$EE,$EC,$EB,$E9,$E8,$E7,$E6,$E4,$E3,$E2,$E1,$E0,$E0,$DF,$DE,$DE,$DD,$DD,$DD,$DD,$DC,$DC,$DC,$DD,$DD,$DD,$DD,$DE,$DE,$DF,$E0,$E0,$E1,$E2,$E3,$E4,$E6,$E7,$E8,$E9,$EB,$EC,$EE,$EF,$F1,$F2,$F4,$F6,$F7,$F9,$FB,$FD,$FE  ; val=36
    FCB $00,$02,$03,$05,$07,$09,$0B,$0C,$0E,$10,$11,$13,$15,$16,$17,$19,$1A,$1B,$1C,$1D,$1F,$20,$20,$21,$22,$23,$23,$24,$24,$24,$24,$25,$25,$25,$24,$24,$24,$24,$23,$23,$22,$21,$20,$20,$1F,$1D,$1C,$1B,$1A,$19,$17,$16,$15,$13,$11,$10,$0E,$0C,$0B,$09,$07,$05,$03,$02,$00,$FE,$FD,$FB,$F9,$F7,$F5,$F4,$F2,$F0,$EF,$ED,$EB,$EA,$E9,$E7,$E6,$E5,$E4,$E3,$E1,$E0,$E0,$DF,$DE,$DD,$DD,$DC,$DC,$DC,$DC,$DB,$DB,$DB,$DC,$DC,$DC,$DC,$DD,$DD,$DE,$DF,$E0,$E0,$E1,$E3,$E4,$E5,$E6,$E7,$E9,$EA,$EB,$ED,$EF,$F0,$F2,$F4,$F5,$F7,$F9,$FB,$FD,$FE  ; val=37
    FCB $00,$02,$04,$06,$07,$09,$0B,$0D,$0F,$10,$12,$13,$15,$17,$18,$19,$1B,$1C,$1D,$1E,$1F,$20,$21,$22,$23,$24,$24,$25,$25,$25,$25,$26,$26,$26,$25,$25,$25,$25,$24,$24,$23,$22,$21,$20,$1F,$1E,$1D,$1C,$1B,$19,$18,$17,$15,$13,$12,$10,$0F,$0D,$0B,$09,$07,$06,$04,$02,$00,$FE,$FC,$FA,$F9,$F7,$F5,$F3,$F1,$F0,$EE,$ED,$EB,$E9,$E8,$E7,$E5,$E4,$E3,$E2,$E1,$E0,$DF,$DE,$DD,$DC,$DC,$DB,$DB,$DB,$DB,$DA,$DA,$DA,$DB,$DB,$DB,$DB,$DC,$DC,$DD,$DE,$DF,$E0,$E1,$E2,$E3,$E4,$E5,$E7,$E8,$E9,$EB,$ED,$EE,$F0,$F1,$F3,$F5,$F7,$F9,$FA,$FC,$FE  ; val=38
    FCB $00,$02,$04,$06,$08,$09,$0B,$0D,$0F,$10,$12,$14,$16,$17,$19,$1A,$1B,$1D,$1E,$1F,$20,$21,$22,$23,$24,$25,$25,$25,$26,$26,$26,$27,$27,$27,$26,$26,$26,$25,$25,$25,$24,$23,$22,$21,$20,$1F,$1E,$1D,$1B,$1A,$19,$17,$16,$14,$12,$10,$0F,$0D,$0B,$09,$08,$06,$04,$02,$00,$FE,$FC,$FA,$F8,$F7,$F5,$F3,$F1,$F0,$EE,$EC,$EA,$E9,$E7,$E6,$E5,$E3,$E2,$E1,$E0,$DF,$DE,$DD,$DC,$DB,$DB,$DB,$DA,$DA,$DA,$D9,$D9,$D9,$DA,$DA,$DA,$DB,$DB,$DB,$DC,$DD,$DE,$DF,$E0,$E1,$E2,$E3,$E5,$E6,$E7,$E9,$EA,$EC,$EE,$F0,$F1,$F3,$F5,$F7,$F8,$FA,$FC,$FE  ; val=39
    FCB $00,$02,$04,$06,$08,$0A,$0C,$0D,$0F,$11,$13,$14,$16,$18,$19,$1B,$1C,$1D,$1F,$20,$21,$22,$23,$24,$25,$26,$26,$26,$27,$27,$27,$28,$28,$28,$27,$27,$27,$26,$26,$26,$25,$24,$23,$22,$21,$20,$1F,$1D,$1C,$1B,$19,$18,$16,$14,$13,$11,$0F,$0D,$0C,$0A,$08,$06,$04,$02,$00,$FE,$FC,$FA,$F8,$F6,$F4,$F3,$F1,$EF,$ED,$EC,$EA,$E8,$E7,$E5,$E4,$E3,$E1,$E0,$DF,$DE,$DD,$DC,$DB,$DA,$DA,$DA,$D9,$D9,$D9,$D8,$D8,$D8,$D9,$D9,$D9,$DA,$DA,$DA,$DB,$DC,$DD,$DE,$DF,$E0,$E1,$E3,$E4,$E5,$E7,$E8,$EA,$EC,$ED,$EF,$F1,$F3,$F4,$F6,$F8,$FA,$FC,$FE  ; val=40
    FCB $00,$02,$04,$06,$08,$0A,$0C,$0E,$10,$11,$13,$15,$17,$18,$1A,$1B,$1D,$1E,$1F,$21,$22,$23,$24,$25,$25,$26,$27,$27,$28,$28,$28,$29,$29,$29,$28,$28,$28,$27,$27,$26,$25,$25,$24,$23,$22,$21,$1F,$1E,$1D,$1B,$1A,$18,$17,$15,$13,$11,$10,$0E,$0C,$0A,$08,$06,$04,$02,$00,$FE,$FC,$FA,$F8,$F6,$F4,$F2,$F0,$EF,$ED,$EB,$E9,$E8,$E6,$E5,$E3,$E2,$E1,$DF,$DE,$DD,$DC,$DB,$DB,$DA,$D9,$D9,$D8,$D8,$D8,$D7,$D7,$D7,$D8,$D8,$D8,$D9,$D9,$DA,$DB,$DB,$DC,$DD,$DE,$DF,$E1,$E2,$E3,$E5,$E6,$E8,$E9,$EB,$ED,$EF,$F0,$F2,$F4,$F6,$F8,$FA,$FC,$FE  ; val=41
    FCB $00,$02,$04,$06,$08,$0A,$0C,$0E,$10,$12,$14,$15,$17,$19,$1B,$1C,$1E,$1F,$20,$21,$23,$24,$25,$26,$26,$27,$28,$28,$29,$29,$29,$2A,$2A,$2A,$29,$29,$29,$28,$28,$27,$26,$26,$25,$24,$23,$21,$20,$1F,$1E,$1C,$1B,$19,$17,$15,$14,$12,$10,$0E,$0C,$0A,$08,$06,$04,$02,$00,$FE,$FC,$FA,$F8,$F6,$F4,$F2,$F0,$EE,$EC,$EB,$E9,$E7,$E5,$E4,$E2,$E1,$E0,$DF,$DD,$DC,$DB,$DA,$DA,$D9,$D8,$D8,$D7,$D7,$D7,$D6,$D6,$D6,$D7,$D7,$D7,$D8,$D8,$D9,$DA,$DA,$DB,$DC,$DD,$DF,$E0,$E1,$E2,$E4,$E5,$E7,$E9,$EB,$EC,$EE,$F0,$F2,$F4,$F6,$F8,$FA,$FC,$FE  ; val=42
    FCB $00,$02,$04,$06,$08,$0A,$0C,$0E,$10,$12,$14,$16,$18,$1A,$1B,$1D,$1E,$20,$21,$22,$24,$25,$26,$27,$27,$28,$29,$29,$2A,$2A,$2A,$2B,$2B,$2B,$2A,$2A,$2A,$29,$29,$28,$27,$27,$26,$25,$24,$22,$21,$20,$1E,$1D,$1B,$1A,$18,$16,$14,$12,$10,$0E,$0C,$0A,$08,$06,$04,$02,$00,$FE,$FC,$FA,$F8,$F6,$F4,$F2,$F0,$EE,$EC,$EA,$E8,$E6,$E5,$E3,$E2,$E0,$DF,$DE,$DC,$DB,$DA,$D9,$D9,$D8,$D7,$D7,$D6,$D6,$D6,$D5,$D5,$D5,$D6,$D6,$D6,$D7,$D7,$D8,$D9,$D9,$DA,$DB,$DC,$DE,$DF,$E0,$E2,$E3,$E5,$E6,$E8,$EA,$EC,$EE,$F0,$F2,$F4,$F6,$F8,$FA,$FC,$FE  ; val=43
    FCB $00,$02,$04,$07,$09,$0B,$0D,$0F,$11,$13,$15,$16,$18,$1A,$1C,$1D,$1F,$20,$22,$23,$24,$25,$27,$28,$28,$29,$2A,$2A,$2B,$2B,$2B,$2C,$2C,$2C,$2B,$2B,$2B,$2A,$2A,$29,$28,$28,$27,$25,$24,$23,$22,$20,$1F,$1D,$1C,$1A,$18,$16,$15,$13,$11,$0F,$0D,$0B,$09,$07,$04,$02,$00,$FE,$FC,$F9,$F7,$F5,$F3,$F1,$EF,$ED,$EB,$EA,$E8,$E6,$E4,$E3,$E1,$E0,$DE,$DD,$DC,$DB,$D9,$D8,$D8,$D7,$D6,$D6,$D5,$D5,$D5,$D4,$D4,$D4,$D5,$D5,$D5,$D6,$D6,$D7,$D8,$D8,$D9,$DB,$DC,$DD,$DE,$E0,$E1,$E3,$E4,$E6,$E8,$EA,$EB,$ED,$EF,$F1,$F3,$F5,$F7,$F9,$FC,$FE  ; val=44
    FCB $00,$02,$04,$07,$09,$0B,$0D,$0F,$11,$13,$15,$17,$19,$1B,$1C,$1E,$20,$21,$22,$24,$25,$26,$27,$28,$29,$2A,$2B,$2B,$2C,$2C,$2C,$2D,$2D,$2D,$2C,$2C,$2C,$2B,$2B,$2A,$29,$28,$27,$26,$25,$24,$22,$21,$20,$1E,$1C,$1B,$19,$17,$15,$13,$11,$0F,$0D,$0B,$09,$07,$04,$02,$00,$FE,$FC,$F9,$F7,$F5,$F3,$F1,$EF,$ED,$EB,$E9,$E7,$E5,$E4,$E2,$E0,$DF,$DE,$DC,$DB,$DA,$D9,$D8,$D7,$D6,$D5,$D5,$D4,$D4,$D4,$D3,$D3,$D3,$D4,$D4,$D4,$D5,$D5,$D6,$D7,$D8,$D9,$DA,$DB,$DC,$DE,$DF,$E0,$E2,$E4,$E5,$E7,$E9,$EB,$ED,$EF,$F1,$F3,$F5,$F7,$F9,$FC,$FE  ; val=45
    FCB $00,$02,$04,$07,$09,$0B,$0D,$0F,$12,$13,$16,$17,$1A,$1B,$1D,$1F,$20,$22,$23,$25,$26,$27,$28,$29,$2A,$2B,$2C,$2C,$2D,$2D,$2D,$2E,$2E,$2E,$2D,$2D,$2D,$2C,$2C,$2B,$2A,$29,$28,$27,$26,$25,$23,$22,$20,$1F,$1D,$1B,$1A,$17,$16,$13,$12,$0F,$0D,$0B,$09,$07,$04,$02,$00,$FE,$FC,$F9,$F7,$F5,$F3,$F1,$EE,$ED,$EA,$E9,$E6,$E5,$E3,$E1,$E0,$DE,$DD,$DB,$DA,$D9,$D8,$D7,$D6,$D5,$D4,$D4,$D3,$D3,$D3,$D2,$D2,$D2,$D3,$D3,$D3,$D4,$D4,$D5,$D6,$D7,$D8,$D9,$DA,$DB,$DD,$DE,$E0,$E1,$E3,$E5,$E6,$E9,$EA,$ED,$EE,$F1,$F3,$F5,$F7,$F9,$FC,$FE  ; val=46
    FCB $00,$02,$04,$07,$09,$0B,$0E,$10,$12,$14,$16,$18,$1A,$1C,$1E,$1F,$21,$23,$24,$25,$27,$28,$29,$2A,$2B,$2C,$2D,$2D,$2E,$2E,$2E,$2F,$2F,$2F,$2E,$2E,$2E,$2D,$2D,$2C,$2B,$2A,$29,$28,$27,$25,$24,$23,$21,$1F,$1E,$1C,$1A,$18,$16,$14,$12,$10,$0E,$0B,$09,$07,$04,$02,$00,$FE,$FC,$F9,$F7,$F5,$F2,$F0,$EE,$EC,$EA,$E8,$E6,$E4,$E2,$E1,$DF,$DD,$DC,$DB,$D9,$D8,$D7,$D6,$D5,$D4,$D3,$D3,$D2,$D2,$D2,$D1,$D1,$D1,$D2,$D2,$D2,$D3,$D3,$D4,$D5,$D6,$D7,$D8,$D9,$DB,$DC,$DD,$DF,$E1,$E2,$E4,$E6,$E8,$EA,$EC,$EE,$F0,$F2,$F5,$F7,$F9,$FC,$FE  ; val=47
    FCB $00,$02,$05,$07,$09,$0C,$0E,$10,$12,$14,$17,$18,$1B,$1D,$1E,$20,$22,$23,$25,$26,$28,$29,$2A,$2B,$2C,$2D,$2E,$2E,$2F,$2F,$2F,$30,$30,$30,$2F,$2F,$2F,$2E,$2E,$2D,$2C,$2B,$2A,$29,$28,$26,$25,$23,$22,$20,$1E,$1D,$1B,$18,$17,$14,$12,$10,$0E,$0C,$09,$07,$05,$02,$00,$FE,$FB,$F9,$F7,$F4,$F2,$F0,$EE,$EC,$E9,$E8,$E5,$E3,$E2,$E0,$DE,$DD,$DB,$DA,$D8,$D7,$D6,$D5,$D4,$D3,$D2,$D2,$D1,$D1,$D1,$D0,$D0,$D0,$D1,$D1,$D1,$D2,$D2,$D3,$D4,$D5,$D6,$D7,$D8,$DA,$DB,$DD,$DE,$E0,$E2,$E3,$E5,$E8,$E9,$EC,$EE,$F0,$F2,$F4,$F7,$F9,$FB,$FE  ; val=48
    FCB $00,$02,$05,$07,$0A,$0C,$0E,$10,$13,$15,$17,$19,$1B,$1D,$1F,$21,$22,$24,$26,$27,$29,$2A,$2B,$2C,$2D,$2E,$2F,$2F,$30,$30,$30,$31,$31,$31,$30,$30,$30,$2F,$2F,$2E,$2D,$2C,$2B,$2A,$29,$27,$26,$24,$22,$21,$1F,$1D,$1B,$19,$17,$15,$13,$10,$0E,$0C,$0A,$07,$05,$02,$00,$FE,$FB,$F9,$F6,$F4,$F2,$F0,$ED,$EB,$E9,$E7,$E5,$E3,$E1,$DF,$DE,$DC,$DA,$D9,$D7,$D6,$D5,$D4,$D3,$D2,$D1,$D1,$D0,$D0,$D0,$CF,$CF,$CF,$D0,$D0,$D0,$D1,$D1,$D2,$D3,$D4,$D5,$D6,$D7,$D9,$DA,$DC,$DE,$DF,$E1,$E3,$E5,$E7,$E9,$EB,$ED,$F0,$F2,$F4,$F6,$F9,$FB,$FE  ; val=49
    FCB $00,$02,$05,$07,$0A,$0C,$0E,$11,$13,$15,$17,$19,$1C,$1E,$20,$21,$23,$25,$26,$28,$29,$2B,$2C,$2D,$2E,$2F,$30,$30,$31,$31,$31,$32,$32,$32,$31,$31,$31,$30,$30,$2F,$2E,$2D,$2C,$2B,$29,$28,$26,$25,$23,$21,$20,$1E,$1C,$19,$17,$15,$13,$11,$0E,$0C,$0A,$07,$05,$02,$00,$FE,$FB,$F9,$F6,$F4,$F2,$EF,$ED,$EB,$E9,$E7,$E4,$E2,$E0,$DF,$DD,$DB,$DA,$D8,$D7,$D5,$D4,$D3,$D2,$D1,$D0,$D0,$CF,$CF,$CF,$CE,$CE,$CE,$CF,$CF,$CF,$D0,$D0,$D1,$D2,$D3,$D4,$D5,$D7,$D8,$DA,$DB,$DD,$DF,$E0,$E2,$E4,$E7,$E9,$EB,$ED,$EF,$F2,$F4,$F6,$F9,$FB,$FE  ; val=50
    FCB $00,$02,$05,$08,$0A,$0C,$0F,$11,$14,$16,$18,$1A,$1C,$1E,$20,$22,$24,$25,$27,$29,$2A,$2B,$2D,$2E,$2F,$30,$31,$31,$32,$32,$32,$33,$33,$33,$32,$32,$32,$31,$31,$30,$2F,$2E,$2D,$2B,$2A,$29,$27,$25,$24,$22,$20,$1E,$1C,$1A,$18,$16,$14,$11,$0F,$0C,$0A,$08,$05,$02,$00,$FE,$FB,$F8,$F6,$F4,$F1,$EF,$EC,$EA,$E8,$E6,$E4,$E2,$E0,$DE,$DC,$DB,$D9,$D7,$D6,$D5,$D3,$D2,$D1,$D0,$CF,$CF,$CE,$CE,$CE,$CD,$CD,$CD,$CE,$CE,$CE,$CF,$CF,$D0,$D1,$D2,$D3,$D5,$D6,$D7,$D9,$DB,$DC,$DE,$E0,$E2,$E4,$E6,$E8,$EA,$EC,$EF,$F1,$F4,$F6,$F8,$FB,$FE  ; val=51
    FCB $00,$02,$05,$08,$0A,$0D,$0F,$11,$14,$16,$18,$1A,$1D,$1F,$21,$23,$25,$26,$28,$29,$2B,$2C,$2E,$2F,$30,$31,$32,$32,$33,$33,$33,$34,$34,$34,$33,$33,$33,$32,$32,$31,$30,$2F,$2E,$2C,$2B,$29,$28,$26,$25,$23,$21,$1F,$1D,$1A,$18,$16,$14,$11,$0F,$0D,$0A,$08,$05,$02,$00,$FE,$FB,$F8,$F6,$F3,$F1,$EF,$EC,$EA,$E8,$E6,$E3,$E1,$DF,$DD,$DB,$DA,$D8,$D7,$D5,$D4,$D2,$D1,$D0,$CF,$CE,$CE,$CD,$CD,$CD,$CC,$CC,$CC,$CD,$CD,$CD,$CE,$CE,$CF,$D0,$D1,$D2,$D4,$D5,$D7,$D8,$DA,$DB,$DD,$DF,$E1,$E3,$E6,$E8,$EA,$EC,$EF,$F1,$F3,$F6,$F8,$FB,$FE  ; val=52
    FCB $00,$02,$05,$08,$0A,$0D,$0F,$12,$14,$16,$19,$1B,$1D,$1F,$22,$23,$25,$27,$29,$2A,$2C,$2D,$2E,$30,$30,$32,$33,$33,$34,$34,$34,$35,$35,$35,$34,$34,$34,$33,$33,$32,$30,$30,$2E,$2D,$2C,$2A,$29,$27,$25,$23,$22,$1F,$1D,$1B,$19,$16,$14,$12,$0F,$0D,$0A,$08,$05,$02,$00,$FE,$FB,$F8,$F6,$F3,$F1,$EE,$EC,$EA,$E7,$E5,$E3,$E1,$DE,$DD,$DB,$D9,$D7,$D6,$D4,$D3,$D2,$D0,$D0,$CE,$CD,$CD,$CC,$CC,$CC,$CB,$CB,$CB,$CC,$CC,$CC,$CD,$CD,$CE,$D0,$D0,$D2,$D3,$D4,$D6,$D7,$D9,$DB,$DD,$DE,$E1,$E3,$E5,$E7,$EA,$EC,$EE,$F1,$F3,$F6,$F8,$FB,$FE  ; val=53
    FCB $00,$03,$05,$08,$0B,$0D,$10,$12,$15,$17,$19,$1B,$1E,$20,$22,$24,$26,$28,$29,$2B,$2D,$2E,$2F,$31,$31,$33,$33,$34,$35,$35,$35,$36,$36,$36,$35,$35,$35,$34,$33,$33,$31,$31,$2F,$2E,$2D,$2B,$29,$28,$26,$24,$22,$20,$1E,$1B,$19,$17,$15,$12,$10,$0D,$0B,$08,$05,$03,$00,$FD,$FB,$F8,$F5,$F3,$F0,$EE,$EB,$E9,$E7,$E5,$E2,$E0,$DE,$DC,$DA,$D8,$D7,$D5,$D3,$D2,$D1,$CF,$CF,$CD,$CD,$CC,$CB,$CB,$CB,$CA,$CA,$CA,$CB,$CB,$CB,$CC,$CD,$CD,$CF,$CF,$D1,$D2,$D3,$D5,$D7,$D8,$DA,$DC,$DE,$E0,$E2,$E5,$E7,$E9,$EB,$EE,$F0,$F3,$F5,$F8,$FB,$FD  ; val=54
    FCB $00,$03,$05,$08,$0B,$0D,$10,$12,$15,$17,$1A,$1C,$1F,$21,$23,$25,$27,$28,$2A,$2C,$2E,$2F,$30,$31,$32,$34,$34,$35,$36,$36,$36,$37,$37,$37,$36,$36,$36,$35,$34,$34,$32,$31,$30,$2F,$2E,$2C,$2A,$28,$27,$25,$23,$21,$1F,$1C,$1A,$17,$15,$12,$10,$0D,$0B,$08,$05,$03,$00,$FD,$FB,$F8,$F5,$F3,$F0,$EE,$EB,$E9,$E6,$E4,$E1,$DF,$DD,$DB,$D9,$D8,$D6,$D4,$D2,$D1,$D0,$CF,$CE,$CC,$CC,$CB,$CA,$CA,$CA,$C9,$C9,$C9,$CA,$CA,$CA,$CB,$CC,$CC,$CE,$CF,$D0,$D1,$D2,$D4,$D6,$D8,$D9,$DB,$DD,$DF,$E1,$E4,$E6,$E9,$EB,$EE,$F0,$F3,$F5,$F8,$FB,$FD  ; val=55
    FCB $00,$03,$05,$08,$0B,$0E,$10,$13,$15,$18,$1A,$1C,$1F,$21,$23,$25,$27,$29,$2B,$2D,$2E,$30,$31,$32,$33,$35,$35,$36,$37,$37,$37,$38,$38,$38,$37,$37,$37,$36,$35,$35,$33,$32,$31,$30,$2E,$2D,$2B,$29,$27,$25,$23,$21,$1F,$1C,$1A,$18,$15,$13,$10,$0E,$0B,$08,$05,$03,$00,$FD,$FB,$F8,$F5,$F2,$F0,$ED,$EB,$E8,$E6,$E4,$E1,$DF,$DD,$DB,$D9,$D7,$D5,$D3,$D2,$D0,$CF,$CE,$CD,$CB,$CB,$CA,$C9,$C9,$C9,$C8,$C8,$C8,$C9,$C9,$C9,$CA,$CB,$CB,$CD,$CE,$CF,$D0,$D2,$D3,$D5,$D7,$D9,$DB,$DD,$DF,$E1,$E4,$E6,$E8,$EB,$ED,$F0,$F2,$F5,$F8,$FB,$FD  ; val=56
    FCB $00,$03,$05,$08,$0B,$0E,$10,$13,$16,$18,$1B,$1D,$20,$22,$24,$26,$28,$2A,$2C,$2D,$2F,$31,$32,$33,$34,$35,$36,$37,$38,$38,$38,$39,$39,$39,$38,$38,$38,$37,$36,$35,$34,$33,$32,$31,$2F,$2D,$2C,$2A,$28,$26,$24,$22,$20,$1D,$1B,$18,$16,$13,$10,$0E,$0B,$08,$05,$03,$00,$FD,$FB,$F8,$F5,$F2,$F0,$ED,$EA,$E8,$E5,$E3,$E0,$DE,$DC,$DA,$D8,$D6,$D4,$D3,$D1,$CF,$CE,$CD,$CC,$CB,$CA,$C9,$C8,$C8,$C8,$C7,$C7,$C7,$C8,$C8,$C8,$C9,$CA,$CB,$CC,$CD,$CE,$CF,$D1,$D3,$D4,$D6,$D8,$DA,$DC,$DE,$E0,$E3,$E5,$E8,$EA,$ED,$F0,$F2,$F5,$F8,$FB,$FD  ; val=57
    FCB $00,$03,$05,$09,$0B,$0E,$11,$13,$16,$18,$1B,$1D,$20,$22,$25,$27,$29,$2B,$2C,$2E,$30,$31,$33,$34,$35,$36,$37,$38,$39,$39,$39,$3A,$3A,$3A,$39,$39,$39,$38,$37,$36,$35,$34,$33,$31,$30,$2E,$2C,$2B,$29,$27,$25,$22,$20,$1D,$1B,$18,$16,$13,$11,$0E,$0B,$09,$05,$03,$00,$FD,$FB,$F7,$F5,$F2,$EF,$ED,$EA,$E8,$E5,$E3,$E0,$DE,$DB,$D9,$D7,$D5,$D4,$D2,$D0,$CF,$CD,$CC,$CB,$CA,$C9,$C8,$C7,$C7,$C7,$C6,$C6,$C6,$C7,$C7,$C7,$C8,$C9,$CA,$CB,$CC,$CD,$CF,$D0,$D2,$D4,$D5,$D7,$D9,$DB,$DE,$E0,$E3,$E5,$E8,$EA,$ED,$EF,$F2,$F5,$F7,$FB,$FD  ; val=58
    FCB $00,$03,$06,$09,$0C,$0E,$11,$14,$17,$19,$1C,$1E,$21,$23,$25,$27,$29,$2B,$2D,$2F,$31,$32,$34,$35,$36,$37,$38,$39,$3A,$3A,$3A,$3B,$3B,$3B,$3A,$3A,$3A,$39,$38,$37,$36,$35,$34,$32,$31,$2F,$2D,$2B,$29,$27,$25,$23,$21,$1E,$1C,$19,$17,$14,$11,$0E,$0C,$09,$06,$03,$00,$FD,$FA,$F7,$F4,$F2,$EF,$EC,$E9,$E7,$E4,$E2,$DF,$DD,$DB,$D9,$D7,$D5,$D3,$D1,$CF,$CE,$CC,$CB,$CA,$C9,$C8,$C7,$C6,$C6,$C6,$C5,$C5,$C5,$C6,$C6,$C6,$C7,$C8,$C9,$CA,$CB,$CC,$CE,$CF,$D1,$D3,$D5,$D7,$D9,$DB,$DD,$DF,$E2,$E4,$E7,$E9,$EC,$EF,$F2,$F4,$F7,$FA,$FD  ; val=59
    FCB $00,$03,$06,$09,$0C,$0F,$11,$14,$17,$19,$1C,$1E,$21,$24,$26,$28,$2A,$2C,$2E,$30,$32,$33,$35,$36,$37,$38,$39,$3A,$3B,$3B,$3B,$3C,$3C,$3C,$3B,$3B,$3B,$3A,$39,$38,$37,$36,$35,$33,$32,$30,$2E,$2C,$2A,$28,$26,$24,$21,$1E,$1C,$19,$17,$14,$11,$0F,$0C,$09,$06,$03,$00,$FD,$FA,$F7,$F4,$F1,$EF,$EC,$E9,$E7,$E4,$E2,$DF,$DC,$DA,$D8,$D6,$D4,$D2,$D0,$CE,$CD,$CB,$CA,$C9,$C8,$C7,$C6,$C5,$C5,$C5,$C4,$C4,$C4,$C5,$C5,$C5,$C6,$C7,$C8,$C9,$CA,$CB,$CD,$CE,$D0,$D2,$D4,$D6,$D8,$DA,$DC,$DF,$E2,$E4,$E7,$E9,$EC,$EF,$F1,$F4,$F7,$FA,$FD  ; val=60
    FCB $00,$03,$06,$09,$0C,$0F,$12,$14,$17,$1A,$1D,$1F,$22,$24,$27,$29,$2B,$2D,$2F,$31,$33,$34,$35,$37,$38,$39,$3A,$3B,$3C,$3C,$3C,$3D,$3D,$3D,$3C,$3C,$3C,$3B,$3A,$39,$38,$37,$35,$34,$33,$31,$2F,$2D,$2B,$29,$27,$24,$22,$1F,$1D,$1A,$17,$14,$12,$0F,$0C,$09,$06,$03,$00,$FD,$FA,$F7,$F4,$F1,$EE,$EC,$E9,$E6,$E3,$E1,$DE,$DC,$D9,$D7,$D5,$D3,$D1,$CF,$CD,$CC,$CB,$C9,$C8,$C7,$C6,$C5,$C4,$C4,$C4,$C3,$C3,$C3,$C4,$C4,$C4,$C5,$C6,$C7,$C8,$C9,$CB,$CC,$CD,$CF,$D1,$D3,$D5,$D7,$D9,$DC,$DE,$E1,$E3,$E6,$E9,$EC,$EE,$F1,$F4,$F7,$FA,$FD  ; val=61
    FCB $00,$03,$06,$09,$0C,$0F,$12,$15,$18,$1A,$1D,$1F,$22,$25,$27,$29,$2C,$2E,$2F,$31,$33,$35,$36,$38,$39,$3A,$3B,$3C,$3D,$3D,$3D,$3E,$3E,$3E,$3D,$3D,$3D,$3C,$3B,$3A,$39,$38,$36,$35,$33,$31,$2F,$2E,$2C,$29,$27,$25,$22,$1F,$1D,$1A,$18,$15,$12,$0F,$0C,$09,$06,$03,$00,$FD,$FA,$F7,$F4,$F1,$EE,$EB,$E8,$E6,$E3,$E1,$DE,$DB,$D9,$D7,$D4,$D2,$D1,$CF,$CD,$CB,$CA,$C8,$C7,$C6,$C5,$C4,$C3,$C3,$C3,$C2,$C2,$C2,$C3,$C3,$C3,$C4,$C5,$C6,$C7,$C8,$CA,$CB,$CD,$CF,$D1,$D2,$D4,$D7,$D9,$DB,$DE,$E1,$E3,$E6,$E8,$EB,$EE,$F1,$F4,$F7,$FA,$FD  ; val=62
    FCB $00,$03,$06,$09,$0C,$0F,$12,$15,$18,$1B,$1E,$20,$23,$25,$28,$2A,$2C,$2E,$30,$32,$34,$36,$37,$39,$3A,$3B,$3C,$3D,$3E,$3E,$3E,$3F,$3F,$3F,$3E,$3E,$3E,$3D,$3C,$3B,$3A,$39,$37,$36,$34,$32,$30,$2E,$2C,$2A,$28,$25,$23,$20,$1E,$1B,$18,$15,$12,$0F,$0C,$09,$06,$03,$00,$FD,$FA,$F7,$F4,$F1,$EE,$EB,$E8,$E5,$E2,$E0,$DD,$DB,$D8,$D6,$D4,$D2,$D0,$CE,$CC,$CA,$C9,$C7,$C6,$C5,$C4,$C3,$C2,$C2,$C2,$C1,$C1,$C1,$C2,$C2,$C2,$C3,$C4,$C5,$C6,$C7,$C9,$CA,$CC,$CE,$D0,$D2,$D4,$D6,$D8,$DB,$DD,$E0,$E2,$E5,$E8,$EB,$EE,$F1,$F4,$F7,$FA,$FD  ; val=63

; ============================================================================
; SMUL8 - Signed 8x8 multiply, result = (A * B) / 128  (i8)  [kept for compat]
; ============================================================================
; Input:  A = op1 (i8), B = op2 (i8)
; Output: A = result (i8)
; Destroys: B  (no RAM touched — sign tracked with branches)
SMUL8:
TSTA
BPL SMUL8_AP        ; A >= 0?
NEGA
TSTB
BPL SMUL8_NEGNEG    ; A<0, B: check sign
NEGB                ; A<0, B<0 -> result positive
MUL
ASLB
ROLA
RTS
SMUL8_NEGNEG:           ; A<0, B>=0 -> result negative
MUL
ASLB
ROLA
NEGA
RTS
SMUL8_AP:               ; A >= 0
TSTB
BPL SMUL8_POSPOS    ; A>=0, B>=0 -> result positive
NEGB                ; A>=0, B<0 -> result negative
MUL
ASLB
ROLA
NEGA
RTS
SMUL8_POSPOS:
MUL
ASLB
ROLA
RTS

; ============================================================================
; SMUL_LUT - LUT-based signed 8×8 multiply, result = (A * sin(B*2π/128)) / 128
; ============================================================================
; Input:  A = val (i8, |val|≤63), B = angle index (0-127)
;         Y = SMUL_PROD base address (caller pre-loads: LDY #SMUL_PROD)
; Output: A = result (i8)
; Strategy: LSRA trick — D = (|val|/2)*256 + (angle | (bit0*128)) → table offset
;           LDA D,Y — 7 cycles vs LDX+LEAX+LDA = 12 cycles. Saves 5c per call.
; Destroys: B  (Y preserved)
SMUL_LUT:
TSTA
BPL SMUL_LUT_P      ; A >= 0 ?
; --- negative val ---
NEGA                ; A = |val|
LSRA                ; A = |val|/2,  C = |val| bit0
BCC SMUL_LUT_N1
ORB #$80
SMUL_LUT_N1:
LDA D,Y             ; table[|val|/2][angle]
NEGA
RTS
SMUL_LUT_P:
LSRA                ; A = val/2,  C = val bit0
BCC SMUL_LUT_P1
ORB #$80
SMUL_LUT_P1:
LDA D,Y
RTS

; ============================================================================
; DV3D_ROTATE - Apply X/Y/Z Euler rotation to a single point (inlined LUT)
; ============================================================================
; Input:  ROT3D_RX, ROT3D_RY, ROT3D_RZ (i8 world coords, |val|≤63)
;         ROT3D_AX/AY/AZ = raw sin angle indices (0-127)
;         ROT3D_COS_X/Y/Z = cos angle offsets: (angle+32)&0x7F
;         ROT3D_OX, ROT3D_OY (i8 screen offsets)
; Output: ROT3D_SCR_X, ROT3D_SCR_Y
; Destroys: A, B, X, Y, ROT3D_TEMP, ROT3D_TEMP2, ROT3D_Y1, ROT3D_Z1, ROT3D_X2
DV3D_ROTATE:
LDY #SMUL_PROD      ; Y = table base — shared by all inlined SMUL_LUT calls
; -- X-axis rotation: y1 = y*cX - z*sX,  z1 = y*sX + z*cX --
LDA >ROT3D_RY
LDB >ROT3D_COS_X
    TSTA
BPL SL_P_0
NEGA
LSRA
BCC SL_N1_0
ORB #$80
SL_N1_0:
LDA D,Y
NEGA
BRA SL_END_0
SL_P_0:
LSRA
BCC SL_P1_0
ORB #$80
SL_P1_0:
LDA D,Y
SL_END_0:
    STA >ROT3D_TEMP
LDA >ROT3D_RZ
LDB >ROT3D_AX
    TSTA
BPL SL_P_1
NEGA
LSRA
BCC SL_N1_1
ORB #$80
SL_N1_1:
LDA D,Y
NEGA
BRA SL_END_1
SL_P_1:
LSRA
BCC SL_P1_1
ORB #$80
SL_P1_1:
LDA D,Y
SL_END_1:
    STA >ROT3D_TEMP2
LDA >ROT3D_TEMP
SUBA >ROT3D_TEMP2
STA >ROT3D_Y1

LDA >ROT3D_RY
LDB >ROT3D_AX
    TSTA
BPL SL_P_2
NEGA
LSRA
BCC SL_N1_2
ORB #$80
SL_N1_2:
LDA D,Y
NEGA
BRA SL_END_2
SL_P_2:
LSRA
BCC SL_P1_2
ORB #$80
SL_P1_2:
LDA D,Y
SL_END_2:
    STA >ROT3D_TEMP
LDA >ROT3D_RZ
LDB >ROT3D_COS_X
    TSTA
BPL SL_P_3
NEGA
LSRA
BCC SL_N1_3
ORB #$80
SL_N1_3:
LDA D,Y
NEGA
BRA SL_END_3
SL_P_3:
LSRA
BCC SL_P1_3
ORB #$80
SL_P1_3:
LDA D,Y
SL_END_3:
    ADDA >ROT3D_TEMP
STA >ROT3D_Z1

; -- Y-axis rotation: x2 = x*cY + z1*sY --
LDA >ROT3D_RX
LDB >ROT3D_COS_Y
    TSTA
BPL SL_P_4
NEGA
LSRA
BCC SL_N1_4
ORB #$80
SL_N1_4:
LDA D,Y
NEGA
BRA SL_END_4
SL_P_4:
LSRA
BCC SL_P1_4
ORB #$80
SL_P1_4:
LDA D,Y
SL_END_4:
    STA >ROT3D_TEMP
LDA >ROT3D_Z1
LDB >ROT3D_AY
    TSTA
BPL SL_P_5
NEGA
LSRA
BCC SL_N1_5
ORB #$80
SL_N1_5:
LDA D,Y
NEGA
BRA SL_END_5
SL_P_5:
LSRA
BCC SL_P1_5
ORB #$80
SL_P1_5:
LDA D,Y
SL_END_5:
    ADDA >ROT3D_TEMP
STA >ROT3D_X2

; -- Z-axis rotation: sx = x2*cZ - y1*sZ + OX,  sy = x2*sZ + y1*cZ + OY --
LDA >ROT3D_X2
LDB >ROT3D_COS_Z
    TSTA
BPL SL_P_6
NEGA
LSRA
BCC SL_N1_6
ORB #$80
SL_N1_6:
LDA D,Y
NEGA
BRA SL_END_6
SL_P_6:
LSRA
BCC SL_P1_6
ORB #$80
SL_P1_6:
LDA D,Y
SL_END_6:
    STA >ROT3D_TEMP
LDA >ROT3D_Y1
LDB >ROT3D_AZ
    TSTA
BPL SL_P_7
NEGA
LSRA
BCC SL_N1_7
ORB #$80
SL_N1_7:
LDA D,Y
NEGA
BRA SL_END_7
SL_P_7:
LSRA
BCC SL_P1_7
ORB #$80
SL_P1_7:
LDA D,Y
SL_END_7:
    STA >ROT3D_TEMP2
LDA >ROT3D_TEMP
SUBA >ROT3D_TEMP2
ADDA >ROT3D_OX
STA >ROT3D_SCR_X

LDA >ROT3D_X2
LDB >ROT3D_AZ
    TSTA
BPL SL_P_8
NEGA
LSRA
BCC SL_N1_8
ORB #$80
SL_N1_8:
LDA D,Y
NEGA
BRA SL_END_8
SL_P_8:
LSRA
BCC SL_P1_8
ORB #$80
SL_P1_8:
LDA D,Y
SL_END_8:
    STA >ROT3D_TEMP
LDA >ROT3D_Y1
LDB >ROT3D_COS_Z
    TSTA
BPL SL_P_9
NEGA
LSRA
BCC SL_N1_9
ORB #$80
SL_N1_9:
LDA D,Y
NEGA
BRA SL_END_9
SL_P_9:
LSRA
BCC SL_P1_9
ORB #$80
SL_P1_9:
LDA D,Y
SL_END_9:
    ADDA >ROT3D_TEMP
ADDA >ROT3D_OY
STA >ROT3D_SCR_Y
RTS

; ============================================================================
; DV3D_MOVETO - Move beam to absolute (X,Y) using direct VIA (same as DSWM)
; ============================================================================
; Input:  ROT3D_TEMP=dy, ROT3D_TEMP2=dx (delta from current beam pos)
;         DP must be $D0 on entry
; Destroys: A
; On exit: PB=1 (ready for draw loop)
DV3D_MOVETO:
LDA >ROT3D_TEMP     ; dy
STA VIA_port_a      ; Y to DAC
CLR VIA_port_b      ; PB=0: enable mux, beam tracks Y
NOP                 ; settling
LDA #$CE
STA VIA_cntl        ; PCR=$CE: /ZERO high, integrators active
CLR VIA_shift_reg   ; SR=0: beam off during move
INC VIA_port_b      ; PB=1: lock direction
LDA >ROT3D_TEMP2    ; dx
STA VIA_port_a      ; X to DAC
LDA #$7F
STA VIA_t1_cnt_lo   ; T1=$7F — same scale as DSWM
CLR VIA_t1_cnt_hi   ; start timer (ramp)
DV3D_MOVETO_WAIT:
LDA VIA_int_flags
ANDA #$40
BEQ DV3D_MOVETO_WAIT
RTS

; ============================================================================
; DV3D_DRAWLINE - Draw line with delta (dy,dx) using direct VIA (same as DSWM)
; ============================================================================
; Input:  ROT3D_TEMP=dy, ROT3D_TEMP2=dx
;         PB=1 on entry (left by previous moveto or drawline)
;         DP must be $D0 on entry
; Destroys: A
; On exit: PB=1
DV3D_DRAWLINE:
LDA >ROT3D_TEMP     ; dy
STA VIA_port_a      ; DY to DAC (PB=1: integrators hold)
CLR VIA_port_b      ; PB=0: enable mux, set direction
NOP
NOP
NOP                 ; settling (~same as DSWM)
INC VIA_port_b      ; PB=1: lock direction
LDA >ROT3D_TEMP2    ; dx
STA VIA_port_a      ; DX to DAC
LDA #$FF
STA VIA_shift_reg   ; SR=$FF: beam ON
CLR VIA_t1_cnt_hi   ; start T1 ramp (lo already $7F from moveto — reuse)
DV3D_DRAWLINE_WAIT:
LDA VIA_int_flags
ANDA #$40
BEQ DV3D_DRAWLINE_WAIT
CLR VIA_shift_reg   ; beam OFF
RTS

; ============================================================================
; DRAW_VECTOR_3D_RUNTIME - Draw 3D-rotated vector (vertex-dedup + LUT version)
; ============================================================================
; Input:  X = pointer to _NAME_3D_DATA (vertex-indexed format)
;         ROT3D_AX, ROT3D_AY, ROT3D_AZ = raw angles (0-127)
;         ROT3D_OX, ROT3D_OY = screen offsets
; Data format:
;   FDB vertex_count         ; unique vertex count (high byte skipped)
;   FCB x,y,z × count        ; vertex table (coords ±63)
;   FDB path_count           ; path count (high byte skipped)
;   per path: FCB pt_count, closed, idx0, idx1, ...
; Uses direct VIA access (DP=$D0 required) — same scale as DRAW_VECTOR/DSWM.
; Destroys: A, B, X, U, all ROT3D_* vars
DRAW_VECTOR_3D_RUNTIME:
TFR X,U             ; U = ROM data pointer

; --- Compute cos angle offsets: ROT3D_COS_X = (AX+32)&0x7F, etc. ---
LDA >ROT3D_AX
ADDA #32
ANDA #$7F
STA >ROT3D_COS_X
LDA >ROT3D_AY
ADDA #32
ANDA #$7F
STA >ROT3D_COS_Y
LDA >ROT3D_AZ
ADDA #32
ANDA #$7F
STA >ROT3D_COS_Z

; --- Phase 1: rotate unique vertices → ROT3D_VBUF ---
LDA ,U+             ; skip high byte of FDB vertex_count
LDB ,U+             ; B = vertex count
STB >ROT3D_PC
LDX #ROT3D_VBUF     ; X = write ptr into RAM cache

DV3D_VERT_LOOP:
TST >ROT3D_PC
BEQ DV3D_VERTS_DONE
DEC >ROT3D_PC
LDA ,U+
STA >ROT3D_RX
LDA ,U+
STA >ROT3D_RY
LDA ,U+
STA >ROT3D_RZ
PSHS X,U            ; save VBUF write ptr and ROM data ptr (DV3D_ROTATE uses X,Y)
JSR DV3D_ROTATE     ; -> ROT3D_SCR_X, ROT3D_SCR_Y
PULS X,U            ; Y was clobbered but not needed outside DV3D_ROTATE
LDA >ROT3D_SCR_X
STA ,X+
LDA >ROT3D_SCR_Y
STA ,X+
BRA DV3D_VERT_LOOP

DV3D_VERTS_DONE:
; U now points to FDB path_count in ROM
; Switch to DP=$D0 for direct VIA access (same as DSWM)
LDA #$D0
TFR A,DP

; --- Reset integrators (DSWM-style: PB sequence + PCR) ---
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

; Set intensity ($7F) via Port A + Z-axis strobe (DSWM-style)
LDA #$7F
STA VIA_port_a
LDA #$04
STA VIA_port_b
LDA #$01
STA VIA_port_b

; Beam at (0,0) after reset — PREV tracks beam position
CLR >ROT3D_PREV_X
CLR >ROT3D_PREV_Y
; T1 lo pre-loaded — reused by DV3D_DRAWLINE
LDA #$7F
STA VIA_t1_cnt_lo

; --- Phase 2: draw paths using VBUF lookup ---
LDA ,U+             ; skip high byte of FDB path_count
LDB ,U+             ; B = path count
STB >ROT3D_PC

DV3D_PATH_LOOP:
TST >ROT3D_PC
LBEQ DV3D_ALL_DONE
DEC >ROT3D_PC

LDB ,U+             ; B = point count for this path
STB >ROT3D_PT_REM
LDA ,U+             ; A = closed flag
STA >ROT3D_CLOSED

; Look up first vertex from VBUF
LDB ,U+             ; B = vertex index
ASLB                ; B = index*2 (VBUF stride = 2 bytes: x', y')
LDX #ROT3D_VBUF
ABX                 ; X = &VBUF[idx*2]
LDA ,X
STA >ROT3D_FIRST_X
LDA 1,X
STA >ROT3D_FIRST_Y

; Moveto: delta from current beam position (PREV)
LDA >ROT3D_FIRST_Y
SUBA >ROT3D_PREV_Y
STA >ROT3D_TEMP     ; dy
LDA >ROT3D_FIRST_X
SUBA >ROT3D_PREV_X
STA >ROT3D_TEMP2    ; dx
JSR DV3D_MOVETO     ; direct VIA move (T1=$7F, same scale as DSWM)

LDA >ROT3D_FIRST_X
STA >ROT3D_PREV_X
LDA >ROT3D_FIRST_Y
STA >ROT3D_PREV_Y
DEC >ROT3D_PT_REM

DV3D_SEG_LOOP:
TST >ROT3D_PT_REM
BEQ DV3D_CLOSE_CHECK
DEC >ROT3D_PT_REM

LDB ,U+             ; B = vertex index
ASLB
LDX #ROT3D_VBUF
ABX                 ; X = &VBUF[idx*2]
; Compute dx, update PREV_X: new_X - PREV_X = dx; new_X = dx + PREV_X
LDA ,X              ; new_X
SUBA >ROT3D_PREV_X  ; A = dx
STA >ROT3D_TEMP2    ; save dx
ADDA >ROT3D_PREV_X  ; A = new_X again
STA >ROT3D_PREV_X
; Compute dy, update PREV_Y
LDA 1,X             ; new_Y
SUBA >ROT3D_PREV_Y  ; A = dy
STA >ROT3D_TEMP     ; save dy
ADDA >ROT3D_PREV_Y  ; A = new_Y again
STA >ROT3D_PREV_Y
JSR DV3D_DRAWLINE
BRA DV3D_SEG_LOOP

DV3D_CLOSE_CHECK:
TST >ROT3D_CLOSED
BEQ DV3D_NEXT_PATH

LDA >ROT3D_FIRST_Y
SUBA >ROT3D_PREV_Y
STA >ROT3D_TEMP
LDA >ROT3D_FIRST_X
SUBA >ROT3D_PREV_X
STA >ROT3D_TEMP2
JSR DV3D_DRAWLINE
LDA >ROT3D_FIRST_X
STA >ROT3D_PREV_X
LDA >ROT3D_FIRST_Y
STA >ROT3D_PREV_Y

DV3D_NEXT_PATH:
LBRA DV3D_PATH_LOOP

DV3D_ALL_DONE:
; Restore DP=$C8 for normal RAM access
JSR $F1AF
RTS

;***************************************************************************
; TRIGONOMETRY LOOKUP TABLES (128 entries each)
;***************************************************************************
SIN_TABLE:
    FDB 0    ; angle 0
    FDB 6    ; angle 1
    FDB 12    ; angle 2
    FDB 19    ; angle 3
    FDB 25    ; angle 4
    FDB 31    ; angle 5
    FDB 37    ; angle 6
    FDB 43    ; angle 7
    FDB 49    ; angle 8
    FDB 54    ; angle 9
    FDB 60    ; angle 10
    FDB 65    ; angle 11
    FDB 71    ; angle 12
    FDB 76    ; angle 13
    FDB 81    ; angle 14
    FDB 85    ; angle 15
    FDB 90    ; angle 16
    FDB 94    ; angle 17
    FDB 98    ; angle 18
    FDB 102    ; angle 19
    FDB 106    ; angle 20
    FDB 109    ; angle 21
    FDB 112    ; angle 22
    FDB 115    ; angle 23
    FDB 117    ; angle 24
    FDB 120    ; angle 25
    FDB 122    ; angle 26
    FDB 123    ; angle 27
    FDB 125    ; angle 28
    FDB 126    ; angle 29
    FDB 126    ; angle 30
    FDB 127    ; angle 31
    FDB 127    ; angle 32
    FDB 127    ; angle 33
    FDB 126    ; angle 34
    FDB 126    ; angle 35
    FDB 125    ; angle 36
    FDB 123    ; angle 37
    FDB 122    ; angle 38
    FDB 120    ; angle 39
    FDB 117    ; angle 40
    FDB 115    ; angle 41
    FDB 112    ; angle 42
    FDB 109    ; angle 43
    FDB 106    ; angle 44
    FDB 102    ; angle 45
    FDB 98    ; angle 46
    FDB 94    ; angle 47
    FDB 90    ; angle 48
    FDB 85    ; angle 49
    FDB 81    ; angle 50
    FDB 76    ; angle 51
    FDB 71    ; angle 52
    FDB 65    ; angle 53
    FDB 60    ; angle 54
    FDB 54    ; angle 55
    FDB 49    ; angle 56
    FDB 43    ; angle 57
    FDB 37    ; angle 58
    FDB 31    ; angle 59
    FDB 25    ; angle 60
    FDB 19    ; angle 61
    FDB 12    ; angle 62
    FDB 6    ; angle 63
    FDB 0    ; angle 64
    FDB -6    ; angle 65
    FDB -12    ; angle 66
    FDB -19    ; angle 67
    FDB -25    ; angle 68
    FDB -31    ; angle 69
    FDB -37    ; angle 70
    FDB -43    ; angle 71
    FDB -49    ; angle 72
    FDB -54    ; angle 73
    FDB -60    ; angle 74
    FDB -65    ; angle 75
    FDB -71    ; angle 76
    FDB -76    ; angle 77
    FDB -81    ; angle 78
    FDB -85    ; angle 79
    FDB -90    ; angle 80
    FDB -94    ; angle 81
    FDB -98    ; angle 82
    FDB -102    ; angle 83
    FDB -106    ; angle 84
    FDB -109    ; angle 85
    FDB -112    ; angle 86
    FDB -115    ; angle 87
    FDB -117    ; angle 88
    FDB -120    ; angle 89
    FDB -122    ; angle 90
    FDB -123    ; angle 91
    FDB -125    ; angle 92
    FDB -126    ; angle 93
    FDB -126    ; angle 94
    FDB -127    ; angle 95
    FDB -127    ; angle 96
    FDB -127    ; angle 97
    FDB -126    ; angle 98
    FDB -126    ; angle 99
    FDB -125    ; angle 100
    FDB -123    ; angle 101
    FDB -122    ; angle 102
    FDB -120    ; angle 103
    FDB -117    ; angle 104
    FDB -115    ; angle 105
    FDB -112    ; angle 106
    FDB -109    ; angle 107
    FDB -106    ; angle 108
    FDB -102    ; angle 109
    FDB -98    ; angle 110
    FDB -94    ; angle 111
    FDB -90    ; angle 112
    FDB -85    ; angle 113
    FDB -81    ; angle 114
    FDB -76    ; angle 115
    FDB -71    ; angle 116
    FDB -65    ; angle 117
    FDB -60    ; angle 118
    FDB -54    ; angle 119
    FDB -49    ; angle 120
    FDB -43    ; angle 121
    FDB -37    ; angle 122
    FDB -31    ; angle 123
    FDB -25    ; angle 124
    FDB -19    ; angle 125
    FDB -12    ; angle 126
    FDB -6    ; angle 127

COS_TABLE:
    FDB 127    ; angle 0
    FDB 127    ; angle 1
    FDB 126    ; angle 2
    FDB 126    ; angle 3
    FDB 125    ; angle 4
    FDB 123    ; angle 5
    FDB 122    ; angle 6
    FDB 120    ; angle 7
    FDB 117    ; angle 8
    FDB 115    ; angle 9
    FDB 112    ; angle 10
    FDB 109    ; angle 11
    FDB 106    ; angle 12
    FDB 102    ; angle 13
    FDB 98    ; angle 14
    FDB 94    ; angle 15
    FDB 90    ; angle 16
    FDB 85    ; angle 17
    FDB 81    ; angle 18
    FDB 76    ; angle 19
    FDB 71    ; angle 20
    FDB 65    ; angle 21
    FDB 60    ; angle 22
    FDB 54    ; angle 23
    FDB 49    ; angle 24
    FDB 43    ; angle 25
    FDB 37    ; angle 26
    FDB 31    ; angle 27
    FDB 25    ; angle 28
    FDB 19    ; angle 29
    FDB 12    ; angle 30
    FDB 6    ; angle 31
    FDB 0    ; angle 32
    FDB -6    ; angle 33
    FDB -12    ; angle 34
    FDB -19    ; angle 35
    FDB -25    ; angle 36
    FDB -31    ; angle 37
    FDB -37    ; angle 38
    FDB -43    ; angle 39
    FDB -49    ; angle 40
    FDB -54    ; angle 41
    FDB -60    ; angle 42
    FDB -65    ; angle 43
    FDB -71    ; angle 44
    FDB -76    ; angle 45
    FDB -81    ; angle 46
    FDB -85    ; angle 47
    FDB -90    ; angle 48
    FDB -94    ; angle 49
    FDB -98    ; angle 50
    FDB -102    ; angle 51
    FDB -106    ; angle 52
    FDB -109    ; angle 53
    FDB -112    ; angle 54
    FDB -115    ; angle 55
    FDB -117    ; angle 56
    FDB -120    ; angle 57
    FDB -122    ; angle 58
    FDB -123    ; angle 59
    FDB -125    ; angle 60
    FDB -126    ; angle 61
    FDB -126    ; angle 62
    FDB -127    ; angle 63
    FDB -127    ; angle 64
    FDB -127    ; angle 65
    FDB -126    ; angle 66
    FDB -126    ; angle 67
    FDB -125    ; angle 68
    FDB -123    ; angle 69
    FDB -122    ; angle 70
    FDB -120    ; angle 71
    FDB -117    ; angle 72
    FDB -115    ; angle 73
    FDB -112    ; angle 74
    FDB -109    ; angle 75
    FDB -106    ; angle 76
    FDB -102    ; angle 77
    FDB -98    ; angle 78
    FDB -94    ; angle 79
    FDB -90    ; angle 80
    FDB -85    ; angle 81
    FDB -81    ; angle 82
    FDB -76    ; angle 83
    FDB -71    ; angle 84
    FDB -65    ; angle 85
    FDB -60    ; angle 86
    FDB -54    ; angle 87
    FDB -49    ; angle 88
    FDB -43    ; angle 89
    FDB -37    ; angle 90
    FDB -31    ; angle 91
    FDB -25    ; angle 92
    FDB -19    ; angle 93
    FDB -12    ; angle 94
    FDB -6    ; angle 95
    FDB 0    ; angle 96
    FDB 6    ; angle 97
    FDB 12    ; angle 98
    FDB 19    ; angle 99
    FDB 25    ; angle 100
    FDB 31    ; angle 101
    FDB 37    ; angle 102
    FDB 43    ; angle 103
    FDB 49    ; angle 104
    FDB 54    ; angle 105
    FDB 60    ; angle 106
    FDB 65    ; angle 107
    FDB 71    ; angle 108
    FDB 76    ; angle 109
    FDB 81    ; angle 110
    FDB 85    ; angle 111
    FDB 90    ; angle 112
    FDB 94    ; angle 113
    FDB 98    ; angle 114
    FDB 102    ; angle 115
    FDB 106    ; angle 116
    FDB 109    ; angle 117
    FDB 112    ; angle 118
    FDB 115    ; angle 119
    FDB 117    ; angle 120
    FDB 120    ; angle 121
    FDB 122    ; angle 122
    FDB 123    ; angle 123
    FDB 125    ; angle 124
    FDB 126    ; angle 125
    FDB 126    ; angle 126
    FDB 127    ; angle 127

TAN_TABLE:
    FDB 0    ; angle 0
    FDB 1    ; angle 1
    FDB 2    ; angle 2
    FDB 3    ; angle 3
    FDB 4    ; angle 4
    FDB 5    ; angle 5
    FDB 6    ; angle 6
    FDB 7    ; angle 7
    FDB 8    ; angle 8
    FDB 9    ; angle 9
    FDB 11    ; angle 10
    FDB 12    ; angle 11
    FDB 13    ; angle 12
    FDB 15    ; angle 13
    FDB 16    ; angle 14
    FDB 18    ; angle 15
    FDB 20    ; angle 16
    FDB 22    ; angle 17
    FDB 24    ; angle 18
    FDB 27    ; angle 19
    FDB 30    ; angle 20
    FDB 33    ; angle 21
    FDB 37    ; angle 22
    FDB 42    ; angle 23
    FDB 48    ; angle 24
    FDB 56    ; angle 25
    FDB 66    ; angle 26
    FDB 80    ; angle 27
    FDB 101    ; angle 28
    FDB 120    ; angle 29
    FDB 120    ; angle 30
    FDB 120    ; angle 31
    FDB -120    ; angle 32
    FDB -120    ; angle 33
    FDB -120    ; angle 34
    FDB -120    ; angle 35
    FDB -101    ; angle 36
    FDB -80    ; angle 37
    FDB -66    ; angle 38
    FDB -56    ; angle 39
    FDB -48    ; angle 40
    FDB -42    ; angle 41
    FDB -37    ; angle 42
    FDB -33    ; angle 43
    FDB -30    ; angle 44
    FDB -27    ; angle 45
    FDB -24    ; angle 46
    FDB -22    ; angle 47
    FDB -20    ; angle 48
    FDB -18    ; angle 49
    FDB -16    ; angle 50
    FDB -15    ; angle 51
    FDB -13    ; angle 52
    FDB -12    ; angle 53
    FDB -11    ; angle 54
    FDB -9    ; angle 55
    FDB -8    ; angle 56
    FDB -7    ; angle 57
    FDB -6    ; angle 58
    FDB -5    ; angle 59
    FDB -4    ; angle 60
    FDB -3    ; angle 61
    FDB -2    ; angle 62
    FDB -1    ; angle 63
    FDB 0    ; angle 64
    FDB 1    ; angle 65
    FDB 2    ; angle 66
    FDB 3    ; angle 67
    FDB 4    ; angle 68
    FDB 5    ; angle 69
    FDB 6    ; angle 70
    FDB 7    ; angle 71
    FDB 8    ; angle 72
    FDB 9    ; angle 73
    FDB 11    ; angle 74
    FDB 12    ; angle 75
    FDB 13    ; angle 76
    FDB 15    ; angle 77
    FDB 16    ; angle 78
    FDB 18    ; angle 79
    FDB 20    ; angle 80
    FDB 22    ; angle 81
    FDB 24    ; angle 82
    FDB 27    ; angle 83
    FDB 30    ; angle 84
    FDB 33    ; angle 85
    FDB 37    ; angle 86
    FDB 42    ; angle 87
    FDB 48    ; angle 88
    FDB 56    ; angle 89
    FDB 66    ; angle 90
    FDB 80    ; angle 91
    FDB 101    ; angle 92
    FDB 120    ; angle 93
    FDB 120    ; angle 94
    FDB 120    ; angle 95
    FDB -120    ; angle 96
    FDB -120    ; angle 97
    FDB -120    ; angle 98
    FDB -120    ; angle 99
    FDB -101    ; angle 100
    FDB -80    ; angle 101
    FDB -66    ; angle 102
    FDB -56    ; angle 103
    FDB -48    ; angle 104
    FDB -42    ; angle 105
    FDB -37    ; angle 106
    FDB -33    ; angle 107
    FDB -30    ; angle 108
    FDB -27    ; angle 109
    FDB -24    ; angle 110
    FDB -22    ; angle 111
    FDB -20    ; angle 112
    FDB -18    ; angle 113
    FDB -16    ; angle 114
    FDB -15    ; angle 115
    FDB -13    ; angle 116
    FDB -12    ; angle 117
    FDB -11    ; angle 118
    FDB -9    ; angle 119
    FDB -8    ; angle 120
    FDB -7    ; angle 121
    FDB -6    ; angle 122
    FDB -5    ; angle 123
    FDB -4    ; angle 124
    FDB -3    ; angle 125
    FDB -2    ; angle 126
    FDB -1    ; angle 127

;**** PRINT_TEXT String Data ****
PRINT_TEXT_STR_3327403:
    FCC "logo"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3556653:
    FCC "text"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2456395222:
    FCC "STUDIO"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_3135039153:
    FCC "jingle"
    FCB $80          ; Vectrex string terminator

;***************************************************************************
; 3D COMPACT DATA TABLES (for DRAW_VECTOR_3D)
;***************************************************************************


; 3D vertex-indexed data for DRAW_VECTOR_3D (32 unique verts, 4 paths, 36 total point refs)
_LOGO_3D_DATA:
    FDB 32               ; vertex count (unique)
    FCB $E8,$31,$00          ; vert 0: x=-24,y=49,z=0
    FCB $E8,$1F,$00          ; vert 1: x=-24,y=31,z=0
    FCB $DE,$1F,$00          ; vert 2: x=-34,y=31,z=0
    FCB $DE,$FA,$00          ; vert 3: x=-34,y=-6,z=0
    FCB $EA,$FA,$00          ; vert 4: x=-22,y=-6,z=0
    FCB $EA,$EF,$00          ; vert 5: x=-22,y=-17,z=0
    FCB $02,$EF,$00          ; vert 6: x=2,y=-17,z=0
    FCB $02,$F8,$00          ; vert 7: x=2,y=-8,z=0
    FCB $0C,$F8,$00          ; vert 8: x=12,y=-8,z=0
    FCB $0C,$1F,$00          ; vert 9: x=12,y=31,z=0
    FCB $02,$1F,$00          ; vert 10: x=2,y=31,z=0
    FCB $02,$31,$00          ; vert 11: x=2,y=49,z=0
    FCB $F0,$2B,$00          ; vert 12: x=-16,y=43,z=0
    FCB $F0,$1F,$00          ; vert 13: x=-16,y=31,z=0
    FCB $F6,$1F,$00          ; vert 14: x=-10,y=31,z=0
    FCB $F6,$2B,$00          ; vert 15: x=-10,y=43,z=0
    FCB $17,$CE,$00          ; vert 16: x=23,y=-50,z=0
    FCB $17,$E2,$00          ; vert 17: x=23,y=-30,z=0
    FCB $21,$E2,$00          ; vert 18: x=33,y=-30,z=0
    FCB $21,$06,$00          ; vert 19: x=33,y=6,z=0
    FCB $17,$06,$00          ; vert 20: x=23,y=6,z=0
    FCB $17,$10,$00          ; vert 21: x=23,y=16,z=0
    FCB $FD,$10,$00          ; vert 22: x=-3,y=16,z=0
    FCB $FD,$06,$00          ; vert 23: x=-3,y=6,z=0
    FCB $F3,$06,$00          ; vert 24: x=-13,y=6,z=0
    FCB $F3,$E2,$00          ; vert 25: x=-13,y=-30,z=0
    FCB $FD,$E2,$00          ; vert 26: x=-3,y=-30,z=0
    FCB $FD,$CE,$00          ; vert 27: x=-3,y=-50,z=0
    FCB $11,$D6,$00          ; vert 28: x=17,y=-42,z=0
    FCB $11,$DF,$00          ; vert 29: x=17,y=-33,z=0
    FCB $09,$DF,$00          ; vert 30: x=9,y=-33,z=0
    FCB $09,$D6,$00          ; vert 31: x=9,y=-42,z=0
    FDB 4               ; path count
    FCB 13               ; path 0: point count
    FCB 0               ; path 0: closed flag
    FCB 0               ; vertex index
    FCB 1               ; vertex index
    FCB 2               ; vertex index
    FCB 3               ; vertex index
    FCB 4               ; vertex index
    FCB 5               ; vertex index
    FCB 6               ; vertex index
    FCB 7               ; vertex index
    FCB 8               ; vertex index
    FCB 9               ; vertex index
    FCB 10               ; vertex index
    FCB 11               ; vertex index
    FCB 0               ; vertex index
    FCB 5               ; path 1: point count
    FCB 0               ; path 1: closed flag
    FCB 12               ; vertex index
    FCB 13               ; vertex index
    FCB 14               ; vertex index
    FCB 15               ; vertex index
    FCB 12               ; vertex index
    FCB 13               ; path 2: point count
    FCB 0               ; path 2: closed flag
    FCB 16               ; vertex index
    FCB 17               ; vertex index
    FCB 18               ; vertex index
    FCB 19               ; vertex index
    FCB 20               ; vertex index
    FCB 21               ; vertex index
    FCB 22               ; vertex index
    FCB 23               ; vertex index
    FCB 24               ; vertex index
    FCB 25               ; vertex index
    FCB 26               ; vertex index
    FCB 27               ; vertex index
    FCB 16               ; vertex index
    FCB 5               ; path 3: point count
    FCB 0               ; path 3: closed flag
    FCB 28               ; vertex index
    FCB 29               ; vertex index
    FCB 30               ; vertex index
    FCB 31               ; vertex index
    FCB 28               ; vertex index


; 3D vertex-indexed data for DRAW_VECTOR_3D (78 unique verts, 13 paths, 98 total point refs)
_TEXT_3D_DATA:
    FDB 78               ; vertex count (unique)
    FCB $C1,$12,$00          ; vert 0: x=-63,y=18,z=0
    FCB $C1,$02,$00          ; vert 1: x=-63,y=2,z=0
    FCB $C1,$FD,$00          ; vert 2: x=-63,y=-3,z=0
    FCB $C7,$12,$00          ; vert 3: x=-57,y=18,z=0
    FCB $C7,$0E,$00          ; vert 4: x=-57,y=14,z=0
    FCB $D8,$0E,$00          ; vert 5: x=-40,y=14,z=0
    FCB $D8,$12,$00          ; vert 6: x=-40,y=18,z=0
    FCB $C7,$0B,$00          ; vert 7: x=-57,y=11,z=0
    FCB $C7,$05,$00          ; vert 8: x=-57,y=5,z=0
    FCB $D8,$05,$00          ; vert 9: x=-40,y=5,z=0
    FCB $D8,$0B,$00          ; vert 10: x=-40,y=11,z=0
    FCB $C7,$00,$00          ; vert 11: x=-57,y=0,z=0
    FCB $C7,$FD,$00          ; vert 12: x=-57,y=-3,z=0
    FCB $D8,$FD,$00          ; vert 13: x=-40,y=-3,z=0
    FCB $D8,$00,$00          ; vert 14: x=-40,y=0,z=0
    FCB $F3,$12,$00          ; vert 15: x=-13,y=18,z=0
    FCB $E4,$12,$00          ; vert 16: x=-28,y=18,z=0
    FCB $E1,$0E,$00          ; vert 17: x=-31,y=14,z=0
    FCB $DE,$08,$00          ; vert 18: x=-34,y=8,z=0
    FCB $E1,$00,$00          ; vert 19: x=-31,y=0,z=0
    FCB $E5,$FD,$00          ; vert 20: x=-27,y=-3,z=0
    FCB $F3,$FD,$00          ; vert 21: x=-13,y=-3,z=0
    FCB $F0,$00,$00          ; vert 22: x=-16,y=0,z=0
    FCB $E7,$00,$00          ; vert 23: x=-25,y=0,z=0
    FCB $E4,$02,$00          ; vert 24: x=-28,y=2,z=0
    FCB $E2,$08,$00          ; vert 25: x=-30,y=8,z=0
    FCB $E4,$0C,$00          ; vert 26: x=-28,y=12,z=0
    FCB $E7,$0E,$00          ; vert 27: x=-25,y=14,z=0
    FCB $F1,$0E,$00          ; vert 28: x=-15,y=14,z=0
    FCB $F9,$12,$00          ; vert 29: x=-7,y=18,z=0
    FCB $F9,$0E,$00          ; vert 30: x=-7,y=14,z=0
    FCB $FF,$0E,$00          ; vert 31: x=-1,y=14,z=0
    FCB $FF,$FD,$00          ; vert 32: x=-1,y=-3,z=0
    FCB $02,$FD,$00          ; vert 33: x=2,y=-3,z=0
    FCB $02,$0E,$00          ; vert 34: x=2,y=14,z=0
    FCB $09,$0E,$00          ; vert 35: x=9,y=14,z=0
    FCB $0B,$12,$00          ; vert 36: x=11,y=18,z=0
    FCB $11,$0E,$00          ; vert 37: x=17,y=14,z=0
    FCB $11,$12,$00          ; vert 38: x=17,y=18,z=0
    FCB $20,$12,$00          ; vert 39: x=32,y=18,z=0
    FCB $23,$0F,$00          ; vert 40: x=35,y=15,z=0
    FCB $23,$0B,$00          ; vert 41: x=35,y=11,z=0
    FCB $21,$06,$00          ; vert 42: x=33,y=6,z=0
    FCB $1E,$05,$00          ; vert 43: x=30,y=5,z=0
    FCB $23,$FD,$00          ; vert 44: x=35,y=-3,z=0
    FCB $1E,$FD,$00          ; vert 45: x=30,y=-3,z=0
    FCB $1A,$05,$00          ; vert 46: x=26,y=5,z=0
    FCB $14,$05,$00          ; vert 47: x=20,y=5,z=0
    FCB $14,$FD,$00          ; vert 48: x=20,y=-3,z=0
    FCB $11,$FD,$00          ; vert 49: x=17,y=-3,z=0
    FCB $11,$09,$00          ; vert 50: x=17,y=9,z=0
    FCB $1D,$09,$00          ; vert 51: x=29,y=9,z=0
    FCB $20,$0B,$00          ; vert 52: x=32,y=11,z=0
    FCB $20,$0E,$00          ; vert 53: x=32,y=14,z=0
    FCB $1D,$0E,$00          ; vert 54: x=29,y=14,z=0
    FCB $29,$12,$00          ; vert 55: x=41,y=18,z=0
    FCB $29,$0E,$00          ; vert 56: x=41,y=14,z=0
    FCB $39,$0E,$00          ; vert 57: x=57,y=14,z=0
    FCB $39,$12,$00          ; vert 58: x=57,y=18,z=0
    FCB $29,$0B,$00          ; vert 59: x=41,y=11,z=0
    FCB $29,$05,$00          ; vert 60: x=41,y=5,z=0
    FCB $39,$05,$00          ; vert 61: x=57,y=5,z=0
    FCB $39,$0B,$00          ; vert 62: x=57,y=11,z=0
    FCB $29,$00,$00          ; vert 63: x=41,y=0,z=0
    FCB $29,$FD,$00          ; vert 64: x=41,y=-3,z=0
    FCB $39,$FD,$00          ; vert 65: x=57,y=-3,z=0
    FCB $39,$00,$00          ; vert 66: x=57,y=0,z=0
    FCB $C1,$EE,$00          ; vert 67: x=-63,y=-18,z=0
    FCB $CA,$EE,$00          ; vert 68: x=-54,y=-18,z=0
    FCB $36,$EE,$00          ; vert 69: x=54,y=-18,z=0
    FCB $3F,$EE,$00          ; vert 70: x=63,y=-18,z=0
    FCB $3C,$12,$00          ; vert 71: x=60,y=18,z=0
    FCB $3F,$12,$00          ; vert 72: x=63,y=18,z=0
    FCB $3F,$0A,$00          ; vert 73: x=63,y=10,z=0
    FCB $3F,$07,$00          ; vert 74: x=63,y=7,z=0
    FCB $3F,$FD,$00          ; vert 75: x=63,y=-3,z=0
    FCB $3F,$04,$00          ; vert 76: x=63,y=4,z=0
    FCB $3D,$FD,$00          ; vert 77: x=61,y=-3,z=0
    FDB 13               ; path count
    FCB 8               ; path 0: point count
    FCB 0               ; path 0: closed flag
    FCB 0               ; vertex index
    FCB 0               ; vertex index
    FCB 1               ; vertex index
    FCB 0               ; vertex index
    FCB 0               ; vertex index
    FCB 2               ; vertex index
    FCB 2               ; vertex index
    FCB 0               ; vertex index
    FCB 5               ; path 1: point count
    FCB 0               ; path 1: closed flag
    FCB 3               ; vertex index
    FCB 4               ; vertex index
    FCB 5               ; vertex index
    FCB 6               ; vertex index
    FCB 3               ; vertex index
    FCB 5               ; path 2: point count
    FCB 0               ; path 2: closed flag
    FCB 7               ; vertex index
    FCB 8               ; vertex index
    FCB 9               ; vertex index
    FCB 10               ; vertex index
    FCB 7               ; vertex index
    FCB 5               ; path 3: point count
    FCB 0               ; path 3: closed flag
    FCB 11               ; vertex index
    FCB 12               ; vertex index
    FCB 13               ; vertex index
    FCB 14               ; vertex index
    FCB 11               ; vertex index
    FCB 15               ; path 4: point count
    FCB 0               ; path 4: closed flag
    FCB 15               ; vertex index
    FCB 16               ; vertex index
    FCB 17               ; vertex index
    FCB 18               ; vertex index
    FCB 19               ; vertex index
    FCB 20               ; vertex index
    FCB 21               ; vertex index
    FCB 22               ; vertex index
    FCB 23               ; vertex index
    FCB 24               ; vertex index
    FCB 25               ; vertex index
    FCB 26               ; vertex index
    FCB 27               ; vertex index
    FCB 28               ; vertex index
    FCB 15               ; vertex index
    FCB 9               ; path 5: point count
    FCB 0               ; path 5: closed flag
    FCB 29               ; vertex index
    FCB 30               ; vertex index
    FCB 31               ; vertex index
    FCB 32               ; vertex index
    FCB 33               ; vertex index
    FCB 34               ; vertex index
    FCB 35               ; vertex index
    FCB 36               ; vertex index
    FCB 29               ; vertex index
    FCB 19               ; path 6: point count
    FCB 0               ; path 6: closed flag
    FCB 37               ; vertex index
    FCB 38               ; vertex index
    FCB 39               ; vertex index
    FCB 40               ; vertex index
    FCB 41               ; vertex index
    FCB 42               ; vertex index
    FCB 43               ; vertex index
    FCB 44               ; vertex index
    FCB 45               ; vertex index
    FCB 46               ; vertex index
    FCB 47               ; vertex index
    FCB 48               ; vertex index
    FCB 49               ; vertex index
    FCB 50               ; vertex index
    FCB 51               ; vertex index
    FCB 52               ; vertex index
    FCB 53               ; vertex index
    FCB 54               ; vertex index
    FCB 37               ; vertex index
    FCB 5               ; path 7: point count
    FCB 0               ; path 7: closed flag
    FCB 55               ; vertex index
    FCB 56               ; vertex index
    FCB 57               ; vertex index
    FCB 58               ; vertex index
    FCB 55               ; vertex index
    FCB 5               ; path 8: point count
    FCB 0               ; path 8: closed flag
    FCB 59               ; vertex index
    FCB 60               ; vertex index
    FCB 61               ; vertex index
    FCB 62               ; vertex index
    FCB 59               ; vertex index
    FCB 5               ; path 9: point count
    FCB 0               ; path 9: closed flag
    FCB 63               ; vertex index
    FCB 64               ; vertex index
    FCB 65               ; vertex index
    FCB 66               ; vertex index
    FCB 63               ; vertex index
    FCB 2               ; path 10: point count
    FCB 0               ; path 10: closed flag
    FCB 67               ; vertex index
    FCB 68               ; vertex index
    FCB 2               ; path 11: point count
    FCB 0               ; path 11: closed flag
    FCB 69               ; vertex index
    FCB 70               ; vertex index
    FCB 13               ; path 12: point count
    FCB 0               ; path 12: closed flag
    FCB 71               ; vertex index
    FCB 72               ; vertex index
    FCB 73               ; vertex index
    FCB 72               ; vertex index
    FCB 72               ; vertex index
    FCB 74               ; vertex index
    FCB 75               ; vertex index
    FCB 75               ; vertex index
    FCB 76               ; vertex index
    FCB 75               ; vertex index
    FCB 77               ; vertex index
    FCB 74               ; vertex index
    FCB 71               ; vertex index

