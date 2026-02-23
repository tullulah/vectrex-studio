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
    FCC "PANG_TEST_3"
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
DRAW_CIRCLE_XC       EQU $C880+$0A   ; Circle center X (1 bytes)
DRAW_CIRCLE_YC       EQU $C880+$0B   ; Circle center Y (1 bytes)
DRAW_CIRCLE_DIAM     EQU $C880+$0C   ; Circle diameter (1 bytes)
DRAW_CIRCLE_INTENSITY EQU $C880+$0D   ; Circle intensity (1 bytes)
DRAW_CIRCLE_RADIUS   EQU $C880+$0E   ; Circle radius (diam/2) - used in segment drawing (1 bytes)
DRAW_CIRCLE_TEMP     EQU $C880+$0F   ; Circle temporary buffer (6 bytes)
DRAW_LINE_ARGS       EQU $C880+$15   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$1F   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$21   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$23   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$24   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$25   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$27   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
VAR_SCREEN           EQU $C880+$29   ; User variable: SCREEN (2 bytes)
VAR_PREV_BTN1        EQU $C880+$2B   ; User variable: PREV_BTN1 (2 bytes)
VAR_JOYSTICK1_STATE  EQU $C880+$2D   ; User variable: JOYSTICK1_STATE (2 bytes)
VAR_JOYSTICK1_STATE_DATA EQU $C880+$2F   ; Mutable array 'JOYSTICK1_STATE' data (6 elements x 2 bytes) (12 bytes)
VAR_ARG0             EQU $CFE0   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $CFE2   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $CFE4   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $CFE6   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $CFE8   ; Function argument 4 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $CFEA   ; Current ROM bank ID (multibank tracking) (1 bytes)

;***************************************************************************
; ARRAY DATA (ROM literals)
;***************************************************************************
; Arrays are stored in ROM and accessed via pointers
; At startup, main() initializes VAR_{name} to point to ARRAY_{name}_DATA

; Array literal for variable 'JOYSTICK1_STATE' (6 elements, 2 bytes each)
ARRAY_JOYSTICK1_STATE_DATA:
    FDB 0   ; Element 0
    FDB 0   ; Element 1
    FDB 0   ; Element 2
    FDB 0   ; Element 3
    FDB 0   ; Element 4
    FDB 0   ; Element 5


;***************************************************************************
; MAIN PROGRAM
;***************************************************************************

MAIN:
    ; Initialize global variables
    LDD #0
    STD VAR_SCREEN
    ; Copy array 'JOYSTICK1_STATE' from ROM to RAM (6 elements)
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
    STD VAR_SCREEN
    LDD #0
    STD RESULT
    LDD RESULT
    STD VAR_PREV_BTN1

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR Reset0Ref    ; Reset beam to center (0,0)
    JSR $F1AA  ; DP_to_D0: set direct page to $D0 for PSG access
    JSR $F1BA  ; Read_Btns: read PSG register 14, update $C80F (Vec_Btn_State)
    JSR $F1AF  ; DP_to_C8: restore direct page to $C8 for normal RAM access
    LDD #2
    STD RESULT
    LDD RESULT
    ASLB            ; Multiply index by 2 (16-bit elements)
    ROLA
    STD TMPPTR      ; Save offset temporarily
    LDD #VAR_JOYSTICK1_STATE_DATA  ; Array data address
    TFR D,X         ; X = array base pointer
    LDD TMPPTR      ; D = offset
    LEAX D,X        ; X = base + offset
    STX TMPPTR2     ; Save computed address
    LDA $C80F      ; Vec_Btn_State (updated by Read_Btns)
    ANDA #$01      ; Test bit 0
    LBEQ .J1B1_0_OFF
    LDD #1
    LBRA .J1B1_0_END
.J1B1_0_OFF:
    LDD #0
.J1B1_0_END:
    STD RESULT
    LDX TMPPTR2     ; Load computed address
    LDD RESULT      ; Load value
    STD ,X          ; Store 16-bit value
    LDD #1
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #2
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
    LDD VAR_PREV_BTN1
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
    STD VAR_SCREEN
    LBRA IF_END_0
IF_NEXT_1:
IF_END_0:
    LDX #VAR_JOYSTICK1_STATE_DATA  ; Array base
    LDD #2
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
    STD VAR_PREV_BTN1
    LDD #0
    STD RESULT
    LDD RESULT
    STD TMPVAL          ; Save right operand to TMPVAL (stack-safe temp)
    LDD VAR_SCREEN
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
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD #0
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_XC
    LDD #0
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_YC
    LDD #30
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
    ; DRAW_CIRCLE: Draw circle at (xc, yc) with diameter
    LDD #0
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_XC
    LDD #0
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_YC
    LDD #60
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_DIAM
    LDD #127
    STD RESULT
    LDA RESULT+1
    STA DRAW_CIRCLE_INTENSITY
    JSR DRAW_CIRCLE_RUNTIME
    LDD #0
    STD RESULT
IF_END_2:
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

