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
    FCC "VPY GAME"
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
    JMP MAIN

;***************************************************************************
; === RAM VARIABLE DEFINITIONS ===
;***************************************************************************
RESULT               EQU $C880+$00   ; Main result temporary (2 bytes)
TMPPTR               EQU $C880+$02   ; Temporary pointer (2 bytes)
TMPPTR2              EQU $C880+$04   ; Temporary pointer 2 (2 bytes)
TEMP_YX              EQU $C880+$06   ; Temporary Y/X coordinate storage (2 bytes)
NUM_STR              EQU $C880+$08   ; Buffer for PRINT_NUMBER hex output (2 bytes)
DRAW_CIRCLE_XC       EQU $C880+$0A   ; Circle center X (1 bytes)
DRAW_CIRCLE_YC       EQU $C880+$0B   ; Circle center Y (1 bytes)
DRAW_CIRCLE_DIAM     EQU $C880+$0C   ; Circle diameter (1 bytes)
DRAW_CIRCLE_INTENSITY EQU $C880+$0D   ; Circle intensity (1 bytes)
DRAW_CIRCLE_TEMP     EQU $C880+$0E   ; Circle temporary buffer (6 bytes)
DRAW_LINE_ARGS       EQU $C880+$14   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$1E   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$20   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$22   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$23   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$24   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$26   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
VAR_COUNTER          EQU $C880+$28   ; User variable: COUNTER (1 bytes)
VAR_STATE            EQU $C880+$29   ; User variable: STATE (1 bytes)
VAR_SHAPE_TYPE       EQU $C880+$2A   ; User variable: SHAPE_TYPE (1 bytes)
VAR_DIRECTION_X      EQU $C880+$2B   ; User variable: DIRECTION_X (1 bytes)
VAR_DIRECTION_Y      EQU $C880+$2C   ; User variable: DIRECTION_Y (1 bytes)
VAR_POS_X            EQU $C880+$2D   ; User variable: POS_X (2 bytes)
VAR_POS_Y            EQU $C880+$2F   ; User variable: POS_Y (2 bytes)
VAR_JOY_X            EQU $C880+$31   ; User variable: JOY_X (2 bytes)
VAR_BASE_INTENSITY   EQU $C880+$33   ; User variable: BASE_INTENSITY (2 bytes)
VAR_MAX_X            EQU $C880+$35   ; User variable: MAX_X (2 bytes)
VAR_MIN_X            EQU $C880+$37   ; User variable: MIN_X (2 bytes)
VAR_ARG0             EQU $CFE0   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $CFE2   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $CFE4   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $CFE6   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $CFE8   ; Function argument 4 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $CFEA   ; Current ROM bank ID (multibank tracking) (1 bytes)


;***************************************************************************
; MAIN PROGRAM
;***************************************************************************

MAIN:
    ; Initialize global variables
    LDD #0
    STD VAR_COUNTER
    LDD #0
    STD VAR_STATE
    LDD #0
    STD VAR_SHAPE_TYPE
    LDD #0
    STD VAR_DIRECTION_X
    LDD #0
    STD VAR_DIRECTION_Y
    LDD #0
    STD VAR_POS_X
    LDD #0
    STD VAR_POS_Y
    LDD #0
    STD VAR_JOY_X
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
    LDB RESULT+1    ; Load low byte
    STB VAR_COUNTER
    LDD #0
    STD RESULT
    LDB RESULT+1    ; Load low byte
    STB VAR_STATE
    LDD #0
    STD RESULT
    LDB RESULT+1    ; Load low byte
    STB VAR_SHAPE_TYPE
    LDD #0
    STD RESULT
    LDB RESULT+1    ; Load low byte
    STB VAR_DIRECTION_X
    LDD #0
    STD RESULT
    LDB RESULT+1    ; Load low byte
    STB VAR_DIRECTION_Y
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_POS_X
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_POS_Y
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_JOY_X
    ; SET_INTENSITY: Set drawing intensity
    LDD VAR_BASE_INTENSITY
    STD RESULT
    LDA RESULT+1    ; Load intensity (8-bit)
    JSR Intensity_a
    LDD #0
    STD RESULT

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR Reset0Ref    ; Reset beam to center (0,0)
    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access
    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)
    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access
    JSR J1X_BUILTIN
    STD RESULT
    LDD RESULT
    STD VAR_JOY_X
    LDD #0
    STD RESULT
    LDD RESULT
    PSHS D
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD ,S++
    LBLT .CMP_0_TRUE
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
    LDB RESULT+1    ; Load low byte
    STB VAR_DIRECTION_X
    LBRA IF_END_0
IF_NEXT_1:
    LDD #0
    STD RESULT
    LDD RESULT
    PSHS D
    LDD VAR_JOY_X
    STD RESULT
    LDD RESULT
    CMPD ,S++
    LBGT .CMP_1_TRUE
    LDD #0
    LBRA .CMP_1_END
.CMP_1_TRUE:
    LDD #1
.CMP_1_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_2
    LDD #1
    STD RESULT
    LDB RESULT+1    ; Load low byte
    STB VAR_DIRECTION_X
    LBRA IF_END_0
IF_NEXT_2:
    LDD #0
    STD RESULT
    LDB RESULT+1    ; Load low byte
    STB VAR_DIRECTION_X
IF_END_0:
    LDD VAR_POS_X
    STD RESULT
    LDD RESULT
    PSHS D
    LDB VAR_DIRECTION_X
    SEX             ; Sign-extend B -> D
    STD RESULT
    LDD RESULT
    ADDD ,S++
    STD RESULT
    LDD RESULT
    STD VAR_POS_X
    LDD VAR_MAX_X
    STD RESULT
    LDD RESULT
    PSHS D
    LDD VAR_POS_X
    STD RESULT
    LDD RESULT
    CMPD ,S++
    LBGT .CMP_2_TRUE
    LDD #0
    LBRA .CMP_2_END
.CMP_2_TRUE:
    LDD #1
.CMP_2_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_4
    LDD VAR_MAX_X
    STD RESULT
    LDD RESULT
    STD VAR_POS_X
    LBRA IF_END_3
IF_NEXT_4:
IF_END_3:
    LDD VAR_MIN_X
    STD RESULT
    LDD RESULT
    PSHS D
    LDD VAR_POS_X
    STD RESULT
    LDD RESULT
    CMPD ,S++
    LBLT .CMP_3_TRUE
    LDD #0
    LBRA .CMP_3_END
.CMP_3_TRUE:
    LDD #1
.CMP_3_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_6
    LDD VAR_MIN_X
    STD RESULT
    LDD RESULT
    STD VAR_POS_X
    LBRA IF_END_5
IF_NEXT_6:
IF_END_5:
    LDD #32
    STD RESULT
    LDD RESULT
    PSHS D
    LDB VAR_COUNTER
    CLRA            ; Zero-extend: A=0, B=value
    STD RESULT
    LDD RESULT
    CMPD ,S++
    LBLT .CMP_4_TRUE
    LDD #0
    LBRA .CMP_4_END
.CMP_4_TRUE:
    LDD #1
.CMP_4_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_8
    LDB VAR_COUNTER
    CLRA            ; Zero-extend: A=0, B=value
    STD RESULT
    LDD RESULT
    STD VAR_POS_Y
    LBRA IF_END_7
IF_NEXT_8:
    LDD #64
    STD RESULT
    LDD RESULT
    PSHS D
    LDB VAR_COUNTER
    CLRA            ; Zero-extend: A=0, B=value
    STD RESULT
    LDD RESULT
    CMPD ,S++
    LBLT .CMP_5_TRUE
    LDD #0
    LBRA .CMP_5_END
.CMP_5_TRUE:
    LDD #1
.CMP_5_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_9
    LDD #64
    STD RESULT
    LDD RESULT
    PSHS D
    LDB VAR_COUNTER
    CLRA            ; Zero-extend: A=0, B=value
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand
    PULS D          ; Get left operand
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDD RESULT
    STD VAR_POS_Y
    LBRA IF_END_7
IF_NEXT_9:
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_POS_Y
IF_END_7:
    LDB VAR_COUNTER
    CLRA            ; Zero-extend: A=0, B=value
    STD RESULT
    LDD RESULT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD ,S++
    STD RESULT
    LDB RESULT+1    ; Load low byte
    STB VAR_COUNTER
    LDD #1
    STD RESULT
    LDD RESULT
    PSHS D
    LDA $C80F      ; Vec_Btn_State (updated by Read_Btns)
    ANDA #$01      ; Test bit 0
    LBEQ .J1B1_0_OFF
    LDD #1
    LBRA .J1B1_0_END
.J1B1_0_OFF:
    LDD #0
.J1B1_0_END:
    STD RESULT
    LDD RESULT
    CMPD ,S++
    LBEQ .CMP_6_TRUE
    LDD #0
    LBRA .CMP_6_END
.CMP_6_TRUE:
    LDD #1
.CMP_6_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_11
    LDB VAR_SHAPE_TYPE
    CLRA            ; Zero-extend: A=0, B=value
    STD RESULT
    LDD RESULT
    PSHS D
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD ,S++
    STD RESULT
    LDB RESULT+1    ; Load low byte
    STB VAR_SHAPE_TYPE
    LDD #2
    STD RESULT
    LDD RESULT
    PSHS D
    LDB VAR_SHAPE_TYPE
    CLRA            ; Zero-extend: A=0, B=value
    STD RESULT
    LDD RESULT
    CMPD ,S++
    LBGT .CMP_7_TRUE
    LDD #0
    LBRA .CMP_7_END
.CMP_7_TRUE:
    LDD #1
.CMP_7_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_13
    LDD #0
    STD RESULT
    LDB RESULT+1    ; Load low byte
    STB VAR_SHAPE_TYPE
    LBRA IF_END_12
IF_NEXT_13:
IF_END_12:
    LBRA IF_END_10
IF_NEXT_11:
IF_END_10:
    ; ===== MOVE builtin =====
    ; TODO: Support variable x, y (requires expressions)
    LDD #0
    STD RESULT
    LDD #0
    STD RESULT
    LDD RESULT
    PSHS D
    LDB VAR_SHAPE_TYPE
    CLRA            ; Zero-extend: A=0, B=value
    STD RESULT
    LDD RESULT
    CMPD ,S++
    LBEQ .CMP_8_TRUE
    LDD #0
    LBRA .CMP_8_END
.CMP_8_TRUE:
    LDD #1
.CMP_8_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_15
    ; DRAW_LINE: Draw line from (x0,y0) to (x1,y1)
    LDD VAR_POS_X
    STD RESULT
    LDD RESULT
    PSHS D
    LDD #10
    STD RESULT
    LDD RESULT
    STD TMPPTR      ; Save right operand
    PULS D          ; Get left operand
    SUBD TMPPTR     ; Left - Right
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+0    ; x0
    LDD VAR_POS_Y
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+2    ; y0
    LDD VAR_POS_X
    STD RESULT
    LDD RESULT
    PSHS D
    LDD #10
    STD RESULT
    LDD RESULT
    ADDD ,S++
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+4    ; x1
    LDD VAR_POS_Y
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+6    ; y1
    LDD VAR_BASE_INTENSITY
    STD RESULT
    LDD RESULT
    STD DRAW_LINE_ARGS+8    ; intensity
    JSR DRAW_LINE_WRAPPER
    LDD #0
    STD RESULT
    LBRA IF_END_14
IF_NEXT_15:
    LDD #1
    STD RESULT
    LDD RESULT
    PSHS D
    LDB VAR_SHAPE_TYPE
    CLRA            ; Zero-extend: A=0, B=value
    STD RESULT
    LDD RESULT
    CMPD ,S++
    LBEQ .CMP_9_TRUE
    LDD #0
    LBRA .CMP_9_END
.CMP_9_TRUE:
    LDD #1
.CMP_9_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_16
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD VAR_POS_X
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_XC
    LDD VAR_POS_Y
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_YC
    LDD #10
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_DIAM
    LDD VAR_BASE_INTENSITY
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_14
IF_NEXT_16:
    ; ERROR: DRAW_POLYGON with variables not yet implemented
    LDD #0
    STD RESULT
IF_END_14:
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
    LDD #110
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2327302452187161      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #-120
    STD RESULT
    LDD RESULT
    STD VAR_ARG0    ; X position
    LDD #100
    STD RESULT
    LDD RESULT
    STD VAR_ARG1    ; Y position
    LDB VAR_COUNTER
    CLRA            ; Zero-extend: A=0, B=value
    STD RESULT
    LDD RESULT
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
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

VECTREX_PRINT_NUMBER:
    ; VPy signature: PRINT_NUMBER(x, y, num)
    ; Convert number to hex string and print
    ; CRITICAL: Set VIA to DAC mode BEFORE calling BIOS (don't assume state)
    LDA #$98       ; VIA_cntl = $98 (DAC mode for text rendering)
    STA >$D00C     ; VIA_cntl
    JSR $F1AA      ; DP_to_D0 - set Direct Page for BIOS/VIA access
    LDA VAR_ARG1+1   ; Y position
    LDB VAR_ARG0+1   ; X position
    JSR Moveto_d     ; Move to position
    
    ; Convert number to string (show low byte as hex)
    LDA VAR_ARG2+1   ; Load number value
    
    ; Convert high nibble to ASCII
    LSRA
    LSRA
    LSRA
    LSRA
    ANDA #$0F
    CMPA #10
    BLO PN_DIGIT1
    ADDA #7          ; A-F
PN_DIGIT1:
    ADDA #'0'
    STA NUM_STR      ; Store first digit
    
    ; Convert low nibble to ASCII  
    LDA VAR_ARG2+1
    ANDA #$0F
    CMPA #10
    BLO PN_DIGIT2
    ADDA #7          ; A-F
PN_DIGIT2:
    ADDA #'0'
    ORA #$80         ; Set high bit for string termination
    STA NUM_STR+1    ; Store second digit with high bit
    
    ; Print the string
    LDU #NUM_STR     ; Point to our number string
    JSR Print_Str_d  ; Print using BIOS
    ; CRITICAL: Reset ALL pen parameters after Print_Str_d (scale, position, etc.)
    JSR Reset_Pen  ; BIOS $F35B - resets scale, intensity, and beam state
    JSR $F1AF      ; DP_to_C8 - restore DP before return
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

DRAW_CIRCLE_RUNTIME:
    ; Input: DRAW_CIRCLE_XC, DRAW_CIRCLE_YC, DRAW_CIRCLE_DIAM, DRAW_CIRCLE_INTENSITY
    ; Draw 8-sided polygon (octagon) approximation
    
    ; Set DP to $D0 for BIOS calls
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    
    ; Set intensity
    LDA >DRAW_CIRCLE_INTENSITY
    JSR Intensity_a
    
    ; Calculate radius = diam / 2 (use B for 8-bit)
    LDB >DRAW_CIRCLE_DIAM
    LSRB                ; radius = diam / 2
    STB >DRAW_CIRCLE_TEMP  ; Save radius
    
    ; Move to start point: (xc + radius, yc)
    ; For octagon, start at rightmost point
    LDB >DRAW_CIRCLE_XC
    ADDB >DRAW_CIRCLE_TEMP  ; B = xc + radius
    LDA >DRAW_CIRCLE_YC     ; A = yc
    JSR Moveto_d            ; Move to (yc, xc+r)
    
    ; Draw 8 segments of octagon
    ; Each segment: approximate circle direction with fixed ratios
    ; For radius r, segment deltas are approximately:
    ; Seg 0: dx=-r*0.41, dy=-r*0.41 (upper right to top)
    ; Seg 1: dx=-r*0.41, dy=-r*0.41 (continue)
    ; ... etc around the circle
    
    ; We use simplified ratios: 0.7*r and 0.7*r for diagonal moves
    ; And r for straight moves
    
    LDB >DRAW_CIRCLE_TEMP  ; B = radius
    
    ; Segment 1: NE to N (dx=-0.4r, dy=-0.9r) approx (-r/2, -r)
    CLR Vec_Misc_Count
    PSHS B              ; Save radius
    LSRB                ; B = r/2
    NEGB                ; B = -r/2 (dx)
    LDA ,S              ; A = radius
    NEGA                ; A = -r (dy)
    JSR Draw_Line_d
    
    ; Segment 2: N to NW (dx=-0.9r, dy=-0.4r) approx (-r, -r/2)
    CLR Vec_Misc_Count
    LDA ,S              ; radius
    LSRA                ; r/2
    NEGA                ; -r/2 (dy)
    LDB ,S              ; radius
    NEGB                ; -r (dx)
    JSR Draw_Line_d
    
    ; Segment 3: NW to W (dx=-0.4r, dy=+0.9r) approx (-r/2, +r)
    CLR Vec_Misc_Count
    LDA ,S              ; radius
    LDB ,S
    LSRB                ; r/2
    NEGB                ; -r/2 (dx)
    JSR Draw_Line_d
    
    ; Segment 4: W to SW (dx=+0.4r, dy=+0.9r) approx (+r/2, +r)
    CLR Vec_Misc_Count
    LDA ,S              ; radius (dy)
    LDB ,S
    LSRB                ; r/2 (dx)
    JSR Draw_Line_d
    
    ; Segment 5: SW to S (dx=+0.9r, dy=+0.4r) approx (+r, +r/2)
    CLR Vec_Misc_Count
    LDA ,S
    LSRA                ; r/2 (dy)
    LDB ,S              ; r (dx)
    JSR Draw_Line_d
    
    ; Segment 6: S to SE (dx=+0.9r, dy=-0.4r) approx (+r, -r/2)
    CLR Vec_Misc_Count
    LDA ,S
    LSRA                ; r/2
    NEGA                ; -r/2 (dy)
    LDB ,S              ; r (dx)
    JSR Draw_Line_d
    
    ; Segment 7: SE to E (dx=+0.4r, dy=-0.9r) approx (+r/2, -r)
    CLR Vec_Misc_Count
    LDA ,S              ; radius
    NEGA                ; -r (dy)
    LDB ,S
    LSRB                ; r/2 (dx)
    JSR Draw_Line_d
    
    ; Segment 8: E to NE (close the loop) (dx=-0.4r, dy=-0.9r) approx (-r/2, -r)
    CLR Vec_Misc_Count
    LDA ,S              ; radius
    NEGA                ; -r (dy)
    LDB ,S
    LSRB                ; r/2
    NEGB                ; -r/2 (dx)
    JSR Draw_Line_d
    
    LEAS 1,S            ; Clean up stack (remove saved radius)
    
    ; Restore DP to $C8
    LDA #$C8
    TFR A,DP
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

;**** PRINT_TEXT String Data ****
PRINT_TEXT_STR_2327302452187161:
    FCC "Types Test"
    FCB $80          ; Vectrex string terminator

