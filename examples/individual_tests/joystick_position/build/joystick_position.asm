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
    FCC "JOYSTICK_POS"
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
NUM_STR              EQU $C880+$0A   ; Buffer for PRINT_NUMBER decimal output (5 digits + terminator) (6 bytes)
DRAW_CIRCLE_XC       EQU $C880+$10   ; Circle center X (1 bytes)
DRAW_CIRCLE_YC       EQU $C880+$11   ; Circle center Y (1 bytes)
DRAW_CIRCLE_DIAM     EQU $C880+$12   ; Circle diameter (1 bytes)
DRAW_CIRCLE_INTENSITY EQU $C880+$13   ; Circle intensity (1 bytes)
DRAW_CIRCLE_RADIUS   EQU $C880+$14   ; Circle radius (diam/2) - used in segment drawing (1 bytes)
DRAW_CIRCLE_TEMP     EQU $C880+$15   ; Circle temporary buffer (6 bytes)
DRAW_LINE_ARGS       EQU $C880+$1B   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$25   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$27   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$29   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$2A   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$2B   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$2D   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
VAR_X                EQU $C880+$2F   ; User variable: x (2 bytes)
VAR_Y                EQU $C880+$31   ; User variable: y (2 bytes)
VAR_CIRCLE_X         EQU $C880+$33   ; User variable: circle_x (2 bytes)
VAR_CIRCLE_Y         EQU $C880+$35   ; User variable: circle_y (2 bytes)
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
    ; TODO: Statement Pass { source_line: 10 }

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
    STD VAR_X
    JSR J1Y_BUILTIN
    STD RESULT
    LDD RESULT
    STD VAR_Y
    ; PRINT_TEXT: Print text at position
    LDD #-60
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #80
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_2786      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #-40
    STD RESULT
    LDD RESULT
    STD VAR_ARG0    ; X position
    LDD #80
    STD RESULT
    LDD RESULT
    STD VAR_ARG1    ; Y position
    LDD >VAR_X
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
    LDX #PRINT_TEXT_STR_2817      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #-40
    STD RESULT
    LDD RESULT
    STD VAR_ARG0    ; X position
    LDD #70
    STD RESULT
    LDD RESULT
    STD VAR_ARG1    ; Y position
    LDD >VAR_Y
    STD RESULT
    LDD RESULT
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    LDD >VAR_X
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
    STD VAR_CIRCLE_X
    LDD >VAR_Y
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
    STD VAR_CIRCLE_Y
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD >VAR_CIRCLE_X
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_XC
    LDD >VAR_CIRCLE_Y
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_YC
    LDD #15
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
    ; Print 16-bit decimal number (0-9999)
    ; ARG0=x, ARG1=y, ARG2=value
    ; CRITICAL: Set VIA to DAC mode BEFORE calling BIOS
    LDA #$98
    STA >$D00C     ; VIA_cntl = $98
    JSR $F1AA      ; DP_to_D0
    
    ; Convert 16-bit number to decimal
    LDD >VAR_ARG2  ; Load 16-bit number
    LDX #NUM_STR   ; String buffer
    
    ; Check for 0
    CMPD #0
    BNE .PN_DIV1000
    LDA #'0'
    ORA #$80
    STA ,X
    BRA .PN_AFTER_CONVERT
    
.PN_DIV1000:
    CLRA
.PN_L1000:
    CMPD #1000
    BLT .PN_D1000_DONE
    SUBD #1000
    INCA
    BRA .PN_L1000
.PN_D1000_DONE:
    ADDA #'0'
    STA ,X+
    
    CLRA
.PN_L100:
    CMPD #100
    BLT .PN_D100_DONE
    SUBD #100
    INCA
    BRA .PN_L100
.PN_D100_DONE:
    ADDA #'0'
    STA ,X+
    
    CLRA
.PN_L10:
    CMPD #10
    BLT .PN_D10_DONE
    SUBD #10
    INCA
    BRA .PN_L10
.PN_D10_DONE:
    ADDA #'0'
    STA ,X+
    
    ; Last digit (remainder in D)
    ADDB #'0'
    ORB #$80       ; Terminator
    STB ,X
    
.PN_AFTER_CONVERT:
    ; Move to position
    LDA >VAR_ARG1+1
    LDB >VAR_ARG0+1
    JSR Moveto_d
    
    ; Print string
    LDU #NUM_STR
    JSR Print_Str_d  ; Print using BIOS
    JSR Reset_Pen    ; Reset pen parameters after Print_Str_d
    JSR $F1AF      ; Restore DP
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
PRINT_TEXT_STR_2786:
    FCC "X:"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2817:
    FCC "Y:"
    FCB $80          ; Vectrex string terminator

