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
    FCC "PRINT_NUMBER"
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
DRAW_LINE_ARGS       EQU $C880+$10   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$1A   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$1C   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$1E   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$1F   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$20   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$22   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
VAR_COUNTER          EQU $C880+$24   ; User variable: counter (2 bytes)
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
    STD VAR_COUNTER

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR Reset0Ref    ; Reset beam to center (0,0)
    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access
    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)
    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access
    ; PRINT_TEXT: Print text at position
    LDD #-80
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #80
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_61805355484      ; Pointer to string in helpers bank
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
    LDD >VAR_COUNTER
    STD RESULT
    LDD RESULT
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    ; PRINT_TEXT: Print text at position
    LDD #-80
    STD RESULT
    LDD RESULT
    STD VAR_ARG0
    LDD #-50
    STD RESULT
    LDD RESULT
    STD VAR_ARG1
    LDX #PRINT_TEXT_STR_84737      ; Pointer to string in helpers bank
    STX VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
    ; PRINT_NUMBER(x, y, num)
    LDD #-40
    STD RESULT
    LDD RESULT
    STD VAR_ARG0    ; X position
    LDD #-50
    STD RESULT
    LDD RESULT
    STD VAR_ARG1    ; Y position
    LDD #12345
    STD RESULT
    LDD RESULT
    STD VAR_ARG2    ; Number value
    JSR VECTREX_PRINT_NUMBER
    LDD #0
    STD RESULT
    LDD >VAR_COUNTER
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save left operand to TMPVAL (stack-safe temp)
    LDD #1
    STD RESULT
    LDD RESULT
    ADDD TMPVAL         ; D = D + LEFT (from TMPVAL)
    STD RESULT
    LDD RESULT
    STD VAR_COUNTER
    LDD #650
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD >VAR_COUNTER
    STD RESULT
    LDD RESULT
    CMPD TMPVAL
    LBGT .CMP_0_TRUE
    LDD #0
    LBRA .CMP_0_END
.CMP_0_TRUE:
    LDD #1
.CMP_0_END:
    STD RESULT
    LDD RESULT
    LBEQ IF_NEXT_1
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_COUNTER
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
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
    ; Uses NUM_STR buffer (6 bytes: 4 digits + terminator)
    
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
    JSR Print_Str_hwyx  ; Hardware print: Y in A, X in B, string in U
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

;**** PRINT_TEXT String Data ****
PRINT_TEXT_STR_84737:
    FCC "VAL"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_61805355484:
    FCC "COUNTER"
    FCB $80          ; Vectrex string terminator

