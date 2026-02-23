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
    FCC "J1_BUTTONS"
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
TMPVAL               EQU $C880+$02   ; Temporary value storage (alias for RESULT) (2 bytes)
TMPPTR               EQU $C880+$04   ; Temporary pointer (2 bytes)
TMPPTR2              EQU $C880+$06   ; Temporary pointer 2 (2 bytes)
TEMP_YX              EQU $C880+$08   ; Temporary Y/X coordinate storage (2 bytes)
NUM_STR              EQU $C880+$0A   ; Buffer for PRINT_NUMBER hex output (2 bytes)
DRAW_CIRCLE_XC       EQU $C880+$0C   ; Circle center X (1 bytes)
DRAW_CIRCLE_YC       EQU $C880+$0D   ; Circle center Y (1 bytes)
DRAW_CIRCLE_DIAM     EQU $C880+$0E   ; Circle diameter (1 bytes)
DRAW_CIRCLE_INTENSITY EQU $C880+$0F   ; Circle intensity (1 bytes)
DRAW_CIRCLE_RADIUS   EQU $C880+$10   ; Circle radius (diam/2) - used in segment drawing (1 bytes)
DRAW_CIRCLE_TEMP     EQU $C880+$11   ; Circle temporary buffer (6 bytes)
DRAW_LINE_ARGS       EQU $C880+$17   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$21   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$23   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$25   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$26   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$27   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$29   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
VAR_BTN1             EQU $C880+$2B   ; User variable: btn1 (2 bytes)
VAR_BTN2             EQU $C880+$2D   ; User variable: btn2 (2 bytes)
VAR_BTN3             EQU $C880+$2F   ; User variable: btn3 (2 bytes)
VAR_BTN4             EQU $C880+$31   ; User variable: btn4 (2 bytes)
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
    ; TODO: Statement Pass { source_line: 9 }

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR Reset0Ref    ; Reset beam to center (0,0)
    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access
    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)
    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access
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
    STD VAR_BTN1
    LDA $C80F      ; Vec_Btn_State (updated by Read_Btns)
    ANDA #$02      ; Test bit 1
    LBEQ .J1B2_1_OFF
    LDD #1
    LBRA .J1B2_1_END
.J1B2_1_OFF:
    LDD #0
.J1B2_1_END:
    STD RESULT
    LDD RESULT
    STD VAR_BTN2
    LDA $C80F      ; Vec_Btn_State (updated by Read_Btns)
    ANDA #$04      ; Test bit 2
    LBEQ .J1B3_2_OFF
    LDD #1
    LBRA .J1B3_2_END
.J1B3_2_OFF:
    LDD #0
.J1B3_2_END:
    STD RESULT
    LDD RESULT
    STD VAR_BTN3
    LDA $C80F      ; Vec_Btn_State (updated by Read_Btns)
    ANDA #$08      ; Test bit 3
    LBEQ .J1B4_3_OFF
    LDD #1
    LBRA .J1B4_3_END
.J1B4_3_OFF:
    LDD #0
.J1B4_3_END:
    STD RESULT
    LDD RESULT
    STD VAR_BTN4
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #80
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_63531365      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #-20
    STD RESULT
    LDD RESULT
    STD VAR_ARG0    ; X position
    LDD #80
    STD RESULT
    LDD RESULT
    STD VAR_ARG1    ; Y position
    LDD >VAR_BTN1
    STD RESULT
    LDD RESULT
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #70
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_63531396      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #-20
    STD RESULT
    LDD RESULT
    STD VAR_ARG0    ; X position
    LDD #70
    STD RESULT
    LDD RESULT
    STD VAR_ARG1    ; Y position
    LDD >VAR_BTN2
    STD RESULT
    LDD RESULT
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #60
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_63531427      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #-20
    STD RESULT
    LDD RESULT
    STD VAR_ARG0    ; X position
    LDD #60
    STD RESULT
    LDD RESULT
    STD VAR_ARG1    ; Y position
    LDD >VAR_BTN3
    STD RESULT
    LDD RESULT
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #50
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_63531458      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #-20
    STD RESULT
    LDD RESULT
    STD VAR_ARG0    ; X position
    LDD #50
    STD RESULT
    LDD RESULT
    STD VAR_ARG1    ; Y position
    LDD >VAR_BTN4
    STD RESULT
    LDD RESULT
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN1
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
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD #-40
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_XC
    LDD #0
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_YC
    LDD #10
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_DIAM
    LDD #80
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN2
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
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD #0
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_XC
    LDD #0
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_YC
    LDD #10
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_DIAM
    LDD #80
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_2
IF_NEXT_3:
IF_END_2:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN3
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
    LBEQ IF_NEXT_5
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD #40
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_XC
    LDD #0
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_YC
    LDD #10
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_DIAM
    LDD #80
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_4
IF_NEXT_5:
IF_END_4:
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_BTN4
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
    LBEQ IF_NEXT_7
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD #0
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_XC
    LDD #-40
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_YC
    LDD #10
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_DIAM
    LDD #80
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
    LBRA IF_END_6
IF_NEXT_7:
IF_END_6:
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
    LDU >VAR_ARG2   ; string pointer (third parameter)
    LDA >VAR_ARG1+1 ; Y coordinate (second parameter, low byte)
    LDB >VAR_ARG0+1 ; X coordinate (first parameter, low byte)
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
    LDA >VAR_ARG1+1   ; Y position
    LDB >VAR_ARG0+1   ; X position
    JSR Moveto_d     ; Move to position
    
    ; Convert number to string (show low byte as hex)
    LDA >VAR_ARG2+1   ; Load number value
    
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
    STB >DRAW_CIRCLE_RADIUS  ; Save radius in RAM (not stack)
    
    ; Segment 1: NE to N (dx=-0.4r, dy=-0.9r) approx (-r/2, -r)
    CLR Vec_Misc_Count
    LDB >DRAW_CIRCLE_RADIUS  ; B = radius
    LSRB                ; B = r/2
    NEGB                ; B = -r/2 (dx)
    LDA >DRAW_CIRCLE_RADIUS  ; A = radius
    NEGA                ; A = -r (dy)
    JSR Draw_Line_d
    
    ; Segment 2: N to NW (dx=-0.9r, dy=-0.4r) approx (-r, -r/2)
    CLR Vec_Misc_Count
    LDA >DRAW_CIRCLE_RADIUS  ; radius
    LSRA                ; r/2
    NEGA                ; -r/2 (dy)
    LDB >DRAW_CIRCLE_RADIUS  ; radius
    NEGB                ; -r (dx)
    JSR Draw_Line_d
    
    ; Segment 3: NW to W (dx=-0.4r, dy=+0.9r) approx (-r/2, +r)
    CLR Vec_Misc_Count
    LDA >DRAW_CIRCLE_RADIUS  ; radius
    LDB >DRAW_CIRCLE_RADIUS
    LSRB                ; r/2
    NEGB                ; -r/2 (dx)
    JSR Draw_Line_d
    
    ; Segment 4: W to SW (dx=+0.4r, dy=+0.9r) approx (+r/2, +r)
    CLR Vec_Misc_Count
    LDA >DRAW_CIRCLE_RADIUS  ; radius (dy)
    LDB >DRAW_CIRCLE_RADIUS
    LSRB                ; r/2 (dx)
    JSR Draw_Line_d
    
    ; Segment 5: SW to S (dx=+0.9r, dy=+0.4r) approx (+r, +r/2)
    CLR Vec_Misc_Count
    LDA >DRAW_CIRCLE_RADIUS
    LSRA                ; r/2 (dy)
    LDB >DRAW_CIRCLE_RADIUS  ; r (dx)
    JSR Draw_Line_d
    
    ; Segment 6: S to SE (dx=+0.9r, dy=-0.4r) approx (+r, -r/2)
    CLR Vec_Misc_Count
    LDA >DRAW_CIRCLE_RADIUS
    LSRA                ; r/2
    NEGA                ; -r/2 (dy)
    LDB >DRAW_CIRCLE_RADIUS  ; r (dx)
    JSR Draw_Line_d
    
    ; Segment 7: SE to E (dx=+0.4r, dy=-0.9r) approx (+r/2, -r)
    CLR Vec_Misc_Count
    LDA >DRAW_CIRCLE_RADIUS  ; radius
    NEGA                ; -r (dy)
    LDB >DRAW_CIRCLE_RADIUS
    LSRB                ; r/2 (dx)
    JSR Draw_Line_d
    
    ; Segment 8: E to NE (close the loop) (dx=-0.4r, dy=-0.9r) approx (-r/2, -r)
    CLR Vec_Misc_Count
    LDA >DRAW_CIRCLE_RADIUS  ; radius
    NEGA                ; -r (dy)
    LDB >DRAW_CIRCLE_RADIUS
    LSRB                ; r/2
    NEGB                ; -r/2 (dx)
    JSR Draw_Line_d
    
    
    ; Restore DP to $C8
    LDA #$C8
    TFR A,DP
    RTS

;**** PRINT_TEXT String Data ****
PRINT_TEXT_STR_63531365:
    FCC "BTN1:"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_63531396:
    FCC "BTN2:"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_63531427:
    FCC "BTN3:"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_63531458:
    FCC "BTN4:"
    FCB $80          ; Vectrex string terminator

