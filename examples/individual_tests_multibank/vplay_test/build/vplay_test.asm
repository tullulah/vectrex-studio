; VPy M6809 Assembly (Vectrex)
; ROM: 65536 bytes
; Multibank cartridge: 4 banks (16KB each)
; Helpers bank: 3 (fixed bank at $4000-$7FFF)

; ================================================
; BANK #0 - Entry point and main code
; ================================================

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
    FCC "VPLAYTST"
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
    LDS #$CFFF       ; Stack -> top of Vectrex 2KB RAM (avoids user var collision)

    ; Initialize bank tracking vars to 0 (prevents spurious $DF00 writes)
    LDA #0
    STA >CURRENT_ROM_BANK   ; Bank 0 is always active at boot
    CLR >LEVEL_LOADED       ; No level loaded yet (flag, not a pointer)
; Bank 0 ($0000) is active; fixed bank 3 ($4000-$7FFF) always visible
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
DRAW_LINE_ARGS       EQU $C880+$24   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$2E   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$30   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$32   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$33   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$34   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$36   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
LEVEL_PTR            EQU $C880+$38   ; Pointer to currently loaded level header (2 bytes)
LEVEL_LOADED         EQU $C880+$3A   ; Level loaded flag (0=not loaded, 1=loaded) (1 bytes)
LEVEL_WIDTH          EQU $C880+$3B   ; Level width (legacy tile API) (1 bytes)
LEVEL_HEIGHT         EQU $C880+$3C   ; Level height (legacy tile API) (1 bytes)
LEVEL_TILE_SIZE      EQU $C880+$3D   ; Tile size (legacy tile API) (1 bytes)
LEVEL_Y_IDX          EQU $C880+$3E   ; SHOW_LEVEL row counter (legacy) (1 bytes)
LEVEL_X_IDX          EQU $C880+$3F   ; SHOW_LEVEL column counter (legacy) (1 bytes)
LEVEL_TEMP           EQU $C880+$40   ; SHOW_LEVEL temporary byte (legacy) (1 bytes)
LEVEL_BG_COUNT       EQU $C880+$41   ; BG object count (1 bytes)
LEVEL_GP_COUNT       EQU $C880+$42   ; GP object count (1 bytes)
LEVEL_FG_COUNT       EQU $C880+$43   ; FG object count (1 bytes)
CAMERA_X             EQU $C880+$44   ; Camera X scroll offset (16-bit signed world units) (2 bytes)
CAMERA_Y             EQU $C880+$46   ; Camera Y scroll offset (16-bit signed world units) (2 bytes)
SCROLL_LIMIT_LEFT    EQU $C880+$48   ; Camera scroll limit: left world X (2 bytes)
SCROLL_LIMIT_RIGHT   EQU $C880+$4A   ; Camera scroll limit: right world X (2 bytes)
SCROLL_LIMIT_TOP     EQU $C880+$4C   ; Camera scroll limit: top world Y (2 bytes)
SCROLL_LIMIT_BOTTOM  EQU $C880+$4E   ; Camera scroll limit: bottom world Y (2 bytes)
LEVEL_BG_ROM_PTR     EQU $C880+$50   ; BG layer ROM pointer (2 bytes)
LEVEL_GP_ROM_PTR     EQU $C880+$52   ; GP layer ROM pointer (2 bytes)
LEVEL_FG_ROM_PTR     EQU $C880+$54   ; FG layer ROM pointer (2 bytes)
LEVEL_GP_PTR         EQU $C880+$56   ; GP active pointer (RAM buffer after LOAD_LEVEL) (2 bytes)
LEVEL_BANK           EQU $C880+$58   ; Bank ID for current level (for multibank) (1 bytes)
LEVEL_ENEMY_COUNT    EQU $C880+$59   ; Enemy count from current level header (1 bytes)
LEVEL_ENEMY_INSTANCES_PTR EQU $C880+$5A   ; Ptr to enemy instances table in level bank (2 bytes)
LEVEL_SCREEN_COUNT   EQU $C880+$5C   ; Total Y screens partitioning the level (1 bytes)
LEVEL_BG_SCREENS_PTR EQU $C880+$5D   ; Per-screen BG index ptr (3 bytes per screen) (2 bytes)
LEVEL_GP_SCREENS_PTR EQU $C880+$5F   ; Per-screen GP index ptr (2 bytes)
LEVEL_FG_SCREENS_PTR EQU $C880+$61   ; Per-screen FG index ptr (2 bytes)
SLR_CUR_X            EQU $C880+$63   ; SHOW_LEVEL: clamped (visible) beam X — actually written to integrator (1 bytes)
SLR_TRUE_X           EQU $C880+$64   ; SHOW_LEVEL: 16-bit unclamped abs_x for per-segment line clipping (2 bytes)
DRAW_T1_SCALED       EQU $C880+$66   ; SHOW_LEVEL: effective T1 for current object (DRAW_SCALE * object_scale) (1 bytes)
SDCP_ABS_Y           EQU $C880+$67   ; SHOW_LEVEL: abs_y temporary for SDCP (cannot share TMPVAL — would corrupt top_screen between layers) (1 bytes)
SLR_TOP_SCREEN       EQU $C880+$68   ; SHOW_LEVEL: top Y screen idx (lives across all 3 layers — must not be in TMPVAL) (1 bytes)
SLR_BOT_SCREEN       EQU $C880+$69   ; SHOW_LEVEL: bot Y screen idx (lives across all 3 layers) (1 bytes)
LEVEL_GP_BUFFER      EQU $C880+$6A   ; GP objects RAM buffer (max 32 objects × 15 bytes) (480 bytes)
LCOL_PX              EQU $C880+$24A   ; LEVEL_COLLISION player world_x input (16-bit) (2 bytes)
LCOL_BEST_Y          EQU $C880+$24C   ; LEVEL_COLLISION_Y best floor y found (16-bit signed) (2 bytes)
LCOL_PY              EQU $C880+$24E   ; LEVEL_COLLISION player_top (16-bit signed) (2 bytes)
LCOL_PHH             EQU $C880+$250   ; LEVEL_COLLISION player half_height (1 bytes)
LCOL_PHW             EQU $C880+$251   ; LEVEL_COLLISION_X player half_width (1 bytes)
LCOL_THW             EQU $C880+$252   ; LEVEL_COLLISION_X total half_width (player_hw + obj_hw scratch) (1 bytes)
LCOL_OBJ_Y           EQU $C880+$253   ; LEVEL_COLLISION_Y current object world_y (16-bit) (2 bytes)
LCOL_LOCAL_PX        EQU $C880+$255   ; LEVEL_COLLISION_Y player_x in object-local coords (16-bit) (2 bytes)
LCOL_OBJ_CNT         EQU $C880+$257   ; LEVEL_COLLISION_Y GP objects remaining (1 bytes)
LCOL_SEG_CNT         EQU $C880+$258   ; LEVEL_COLLISION_Y mesh floor segments remaining (1 bytes)
UGPC_OUTER_IDX       EQU $C880+$259   ; GP-GP outer loop index (1 bytes)
UGPC_OUTER_MAX       EQU $C880+$25A   ; GP-GP outer loop max (count-1) (1 bytes)
UGPC_INNER_IDX       EQU $C880+$25B   ; GP-GP inner loop index (1 bytes)
UGPC_DX              EQU $C880+$25C   ; GP-GP |dx| (16-bit) (2 bytes)
UGPC_DIST            EQU $C880+$25E   ; GP-GP Manhattan distance (16-bit) (2 bytes)
UGFC_GP_IDX          EQU $C880+$260   ; GP-FG outer loop GP index (1 bytes)
UGFC_FG_COUNT        EQU $C880+$261   ; GP-FG inner loop FG count (1 bytes)
UGFC_DX              EQU $C880+$262   ; GP-FG |dx| (1 bytes)
UGFC_DY              EQU $C880+$263   ; GP-FG |dy| (1 bytes)
TEXT_SCALE_H         EQU $C880+$264   ; Character height for Print_Str_d (default $F8 = -8, normal) (1 bytes)
TEXT_SCALE_W         EQU $C880+$265   ; Character width for Print_Str_d (default $48 = 72, normal) (1 bytes)
DRAW_SCALE           EQU $C880+$266   ; Current T1 scale for Draw_Sync_List_At_With_Mirrors ($7F=normal) (1 bytes)
VAR_ARG0             EQU $C880+$267   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $C880+$269   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $C880+$26B   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $C880+$26D   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $C880+$26F   ; Function argument 4 (16-bit) (2 bytes)
VAR_ARG5             EQU $C880+$271   ; Function argument 5 (16-bit) (2 bytes)
VAR_ARG6             EQU $C880+$273   ; Function argument 6 (16-bit) (2 bytes)
VAR_ARG7             EQU $C880+$275   ; Function argument 7 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $C880+$277   ; Current ROM bank ID (multibank tracking) (1 bytes)

;***************************************************************************
; MAIN PROGRAM (Bank #0)
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
; VPy_LINE:11
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'test2'
    ; Level asset index: 0 (multibank)
    LDX #0
    JSR LOAD_LEVEL_BANKED

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
; VPy_LINE:14
; NATIVE_CALL: PRINT_TEXT at line 14
    ; PRINT_TEXT: Print text at position
    LDD #-55
    STD >VAR_ARG0
    LDD #120
    STD >VAR_ARG1
    LDX #PRINT_TEXT_STR_2344190015343208      ; Pointer to string in helpers bank
    STX >VAR_ARG2
    JSR VECTREX_PRINT_TEXT
    LDD #0
    STD RESULT
; VPy_LINE:15
    ; ===== UPDATE_LEVEL builtin =====
    JSR UPDATE_LEVEL_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:16
    ; ===== SHOW_LEVEL builtin =====
    JSR SHOW_LEVEL_RUNTIME
    LDD #0
    STD RESULT
    RTS


; ================================================
; BANK #1 - 0 function(s), 1 asset(s)
; ================================================
    ORG $0000  ; Sequential bank model

;***************************************************************************
; ASSETS IN BANK #1 (2 assets)
;***************************************************************************

; ==== Level: TEST2 ====
; Author: 
; Difficulty: medium

_TEST2_LEVEL:
    FDB -96  ; World bounds: xMin (16-bit signed)
    FDB 95  ; xMax (16-bit signed)
    FDB -128  ; yMin (16-bit signed)
    FDB 127  ; yMax (16-bit signed)
    FDB 0  ; Time limit (seconds)
    FDB 0  ; Target score
    FCB 2  ; Background object count
    FCB 0  ; Gameplay object count
    FCB 0  ; Foreground object count
    FDB _TEST2_BG_OBJECTS
    FDB _TEST2_GAMEPLAY_OBJECTS
    FDB _TEST2_FG_OBJECTS
    FDB -96  ; scrollLimit left (camera left cannot go below this)
    FDB 95  ; scrollLimit right (camera right cannot exceed this)
    FDB 127  ; scrollLimit top
    FDB -128  ; scrollLimit bottom
    FCB 0  ; enemy_count
    FDB 0  ; enemy_instances_ptr (0 if none)
    FDB 0  ; groundBottomOffset (floor surface offset from screen bottom)
    FCB 1    ; +34 screen_count
    FDB _TEST2_BG_SCREENS  ; +35 BG screens index
    FDB _TEST2_GP_SCREENS  ; +37 GP screens index
    FDB _TEST2_FG_SCREENS  ; +39 FG screens index

_TEST2_BG_OBJECTS:
_TEST2_BG_OBJECTS_S0:
; Object: obj_1773126779239 (enemy)
    FCB 1  ; type
    FDB -55  ; x
    FDB 59  ; y
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
    FDB _PLATFORM_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 2  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_1773126781390 (enemy)
    FCB 1  ; type
    FDB 50  ; x
    FDB -51  ; y
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
    FDB _PLATFORM_VECTORS  ; vector_ptr (ROM+17)
    FCB 30  ; half_width (1.00x, ROM+19)
    FCB 2  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)


_TEST2_GAMEPLAY_OBJECTS:
_TEST2_GAMEPLAY_OBJECTS_S0:

_TEST2_FG_OBJECTS:
_TEST2_FG_OBJECTS_S0:

_TEST2_BG_SCREENS:
    FCB 2  ; screen 0 count
    FDB _TEST2_BG_OBJECTS_S0  ; screen 0 ptr

_TEST2_GP_SCREENS:
    FCB 0  ; screen 0 count
    FDB _TEST2_GAMEPLAY_OBJECTS_S0  ; screen 0 ptr

_TEST2_FG_SCREENS:
    FCB 0  ; screen 0 count
    FDB _TEST2_FG_OBJECTS_S0  ; screen 0 ptr

_TEST2_ENEMY_COUNT EQU 0


; Generated from platform.vec (Malban Draw_Sync_List format)
; Total paths: 1, points: 4
; X bounds: min=-30, max=30, width=60
; Center: (0, 2)

_PLATFORM_WIDTH EQU 60
_PLATFORM_HALF_WIDTH EQU 30
_PLATFORM_HEIGHT EQU 5
_PLATFORM_HALF_HEIGHT EQU 2
_PLATFORM_CENTER_X EQU 0
_PLATFORM_CENTER_Y EQU 2

_PLATFORM_VECTORS:  ; Main entry (header + 1 path(s))
    FDB 1               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLATFORM_PATH0        ; pointer to path 0

_PLATFORM_PATH0:    ; Path 0
    FCB 100              ; path0: intensity
    FCB $FE,$E2,0,0        ; path0: header (y=-2, x=-30)
    FCB $FF,$00,$3C          ; flag=-1, dy=0, dx=60
    FCB $FF,$05,$00          ; flag=-1, dy=5, dx=0
    FCB $FF,$00,$C4          ; flag=-1, dy=0, dx=-60
    FCB $FF,$FB,$00          ; flag=-1, dy=-5, dx=0
    FCB 2                ; End marker (path complete)


; ================================================
; BANK #2 - 0 function(s) [EMPTY]
; ================================================
    ORG $0000  ; Sequential bank model
    ; Reserved for future code overflow


; ================================================
; BANK #3 - 0 function(s) [HELPERS ONLY]
; ================================================
    ORG $4000  ; Fixed bank (always visible at $4000-$7FFF)
    ; Runtime helpers (accessible from all banks)

;***************************************************************************
; ASSET LOOKUP TABLES (for banked asset access)
; Total: 1 vectors, 0 music, 0 sfx, 1 levels, 0 animations, 0 instruments, 0 enemies
;***************************************************************************

; Vector Asset Index Mapping:
;   0 = platform (Bank #1)

VECTOR_BANK_TABLE:
    FCB 1              ; Bank ID

VECTOR_ADDR_TABLE:
    FDB _PLATFORM_VECTORS    ; platform

; Level Asset Index Mapping:
;   0 = test2 (Bank #1)

LEVEL_BANK_TABLE:
    FCB 1              ; Bank ID

LEVEL_ADDR_TABLE:
    FDB _TEST2_LEVEL    ; test2

; Legacy unified tables (all assets)
ASSET_BANK_TABLE:
    FCB 1              ; Bank ID
    FCB 1              ; Bank ID

ASSET_ADDR_TABLE:
    FDB _TEST2_LEVEL    ; test2
    FDB _PLATFORM_VECTORS    ; platform

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

;**** PRINT_TEXT String Data ****
PRINT_TEXT_STR_110251488:
    FCC "test2"
    FCB $80          ; Vectrex string terminator

PRINT_TEXT_STR_2344190015343208:
    FCC "VPLAY TEST"
    FCB $80          ; Vectrex string terminator

