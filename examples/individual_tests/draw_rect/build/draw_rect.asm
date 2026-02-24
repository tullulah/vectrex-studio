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
    FCC "DRAW_RECT"
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
    ; Initialize bank tracking vars to 0 (prevents spurious $DF00 writes)
    LDA #0
    STA >CURRENT_ROM_BANK   ; Bank 0 is always active at boot
    JMP MAIN

;***************************************************************************
; === RAM VARIABLE DEFINITIONS ===
;***************************************************************************
RESULT               EQU $C880+$00   ; Main result temporary (2 bytes)
TMPVAL               EQU $C880+$02   ; Temporary value storage (alias for RESULT) (2 bytes)
TMPPTR               EQU $C880+$04   ; Temporary pointer (2 bytes)
TMPPTR2              EQU $C880+$06   ; Temporary pointer 2 (2 bytes)
TEMP_YX              EQU $C880+$08   ; Temporary Y/X coordinate storage (2 bytes)
DRAW_RECT_X          EQU $C880+$0A   ; Rectangle X (1 bytes)
DRAW_RECT_Y          EQU $C880+$0B   ; Rectangle Y (1 bytes)
DRAW_RECT_WIDTH      EQU $C880+$0C   ; Rectangle width (1 bytes)
DRAW_RECT_HEIGHT     EQU $C880+$0D   ; Rectangle height (1 bytes)
DRAW_RECT_INTENSITY  EQU $C880+$0E   ; Rectangle intensity (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$0F   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$19   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$1B   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$1D   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$1E   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$1F   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$21   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
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
    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access
    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)
    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access
    LDA #$50
    JSR Intensity_a
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$D8
    LDB #$B0
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$50
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$E2
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$B0
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8
    LDD #0
    STD RESULT
    LDA #$50
    JSR Intensity_a
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$D8
    LDB #$32
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$50
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$E2
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$B0
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8
    LDD #0
    STD RESULT
    LDA #$50
    JSR Intensity_a
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    LDA #$F1
    LDB #$F1
    JSR Moveto_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$1E
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$1E
    LDB #$00
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$00
    LDB #$E2
    JSR Draw_Line_d
    CLR Vec_Misc_Count
    LDA #$E2
    LDB #$00
    JSR Draw_Line_d
    LDA #$C8
    TFR A,DP    ; Restore DP=$C8
    LDD #0
    STD RESULT
    RTS

;***************************************************************************
; RUNTIME HELPERS
;***************************************************************************

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

DRAW_RECT_RUNTIME:
    ; Input: DRAW_RECT_X, DRAW_RECT_Y, DRAW_RECT_WIDTH, DRAW_RECT_HEIGHT, DRAW_RECT_INTENSITY
    ; Draws 4 sides of rectangle
    
    ; Save parameters to stack before DP change
    LDB DRAW_RECT_INTENSITY
    PSHS B
    LDB DRAW_RECT_HEIGHT
    PSHS B
    LDB DRAW_RECT_WIDTH
    PSHS B
    LDB DRAW_RECT_Y
    PSHS B
    LDB DRAW_RECT_X
    PSHS B
    
    ; Setup BIOS
    LDA #$D0
    TFR A,DP
    JSR Reset0Ref
    
    ; Set intensity
    LDA 4,S             ; intensity
    JSR Intensity_a
    
    ; Move to starting position (x, y)
    LDA 1,S             ; y
    LDB ,S              ; x
    JSR Moveto_d_7F
    
    ; Draw right side
    CLR Vec_Misc_Count
    LDA #0
    LDB 2,S             ; width
    JSR Draw_Line_d
    
    ; Draw down side
    CLR Vec_Misc_Count
    LDA 3,S             ; height
    NEGA                ; -height
    LDB #0
    JSR Draw_Line_d
    
    ; Draw left side
    CLR Vec_Misc_Count
    LDA #0
    LDB 2,S             ; width
    NEGB                ; -width
    JSR Draw_Line_d
    
    ; Draw up side
    CLR Vec_Misc_Count
    LDA 2,S             ; height
    NEGA                ; -height
    LDB #0
    JSR Draw_Line_d
    
    LEAS 5,S            ; Clean stack
    RTS

