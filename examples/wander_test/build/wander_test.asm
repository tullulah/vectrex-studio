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
    FCC "WANDER"
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
    CLR >ENEMY_COUNT        ; No enemies until SPAWN_ENEMIES runs
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
RAND_SEED            EQU $C880+$0E   ; Random seed for RAND() (2 bytes)
DRAW_VEC_INTENSITY   EQU $C880+$10   ; Vector intensity override (0=use vector data) (1 bytes)
DRAW_VEC_X_HI        EQU $C880+$11   ; Vector draw X high byte (16-bit screen_x) (1 bytes)
DRAW_VEC_X           EQU $C880+$12   ; Vector draw X offset (1 bytes)
DRAW_VEC_Y           EQU $C880+$13   ; Vector draw Y offset (1 bytes)
MIRROR_PAD           EQU $C880+$14   ; Safety padding to prevent MIRROR flag corruption (16 bytes)
MIRROR_X             EQU $C880+$24   ; X mirror flag (0=normal, 1=flip) (1 bytes)
MIRROR_Y             EQU $C880+$25   ; Y mirror flag (0=normal, 1=flip) (1 bytes)
DRAW_LINE_ARGS       EQU $C880+$26   ; DRAW_LINE argument buffer (x0,y0,x1,y1,intensity) (10 bytes)
VLINE_DX_16          EQU $C880+$30   ; DRAW_LINE dx (16-bit) (2 bytes)
VLINE_DY_16          EQU $C880+$32   ; DRAW_LINE dy (16-bit) (2 bytes)
VLINE_DX             EQU $C880+$34   ; DRAW_LINE dx clamped (8-bit) (1 bytes)
VLINE_DY             EQU $C880+$35   ; DRAW_LINE dy clamped (8-bit) (1 bytes)
VLINE_DY_REMAINING   EQU $C880+$36   ; DRAW_LINE remaining dy for segment 2 (16-bit) (2 bytes)
VLINE_DX_REMAINING   EQU $C880+$38   ; DRAW_LINE remaining dx for segment 2 (16-bit) (2 bytes)
LEVEL_PTR            EQU $C880+$3A   ; Pointer to currently loaded level header (2 bytes)
LEVEL_LOADED         EQU $C880+$3C   ; Level loaded flag (0=not loaded, 1=loaded) (1 bytes)
LEVEL_WIDTH          EQU $C880+$3D   ; Level width (legacy tile API) (1 bytes)
LEVEL_HEIGHT         EQU $C880+$3E   ; Level height (legacy tile API) (1 bytes)
LEVEL_TILE_SIZE      EQU $C880+$3F   ; Tile size (legacy tile API) (1 bytes)
LEVEL_Y_IDX          EQU $C880+$40   ; SHOW_LEVEL row counter (legacy) (1 bytes)
LEVEL_X_IDX          EQU $C880+$41   ; SHOW_LEVEL column counter (legacy) (1 bytes)
LEVEL_TEMP           EQU $C880+$42   ; SHOW_LEVEL temporary byte (legacy) (1 bytes)
LEVEL_BG_COUNT       EQU $C880+$43   ; BG object count (1 bytes)
LEVEL_GP_COUNT       EQU $C880+$44   ; GP object count (1 bytes)
LEVEL_FG_COUNT       EQU $C880+$45   ; FG object count (1 bytes)
CAMERA_X             EQU $C880+$46   ; Camera X scroll offset (16-bit signed world units) (2 bytes)
CAMERA_Y             EQU $C880+$48   ; Camera Y scroll offset (16-bit signed world units) (2 bytes)
SCROLL_LIMIT_LEFT    EQU $C880+$4A   ; Camera scroll limit: left world X (2 bytes)
SCROLL_LIMIT_RIGHT   EQU $C880+$4C   ; Camera scroll limit: right world X (2 bytes)
SCROLL_LIMIT_TOP     EQU $C880+$4E   ; Camera scroll limit: top world Y (2 bytes)
SCROLL_LIMIT_BOTTOM  EQU $C880+$50   ; Camera scroll limit: bottom world Y (2 bytes)
LEVEL_BG_ROM_PTR     EQU $C880+$52   ; BG layer ROM pointer (2 bytes)
LEVEL_GP_ROM_PTR     EQU $C880+$54   ; GP layer ROM pointer (2 bytes)
LEVEL_FG_ROM_PTR     EQU $C880+$56   ; FG layer ROM pointer (2 bytes)
LEVEL_GP_PTR         EQU $C880+$58   ; GP active pointer (RAM buffer after LOAD_LEVEL) (2 bytes)
LEVEL_BANK           EQU $C880+$5A   ; Bank ID for current level (for multibank) (1 bytes)
LEVEL_ENEMY_COUNT    EQU $C880+$5B   ; Enemy count from current level header (1 bytes)
LEVEL_ENEMY_INSTANCES_PTR EQU $C880+$5C   ; Ptr to enemy instances table in level bank (2 bytes)
LEVEL_SCREEN_COUNT   EQU $C880+$5E   ; Total Y screens partitioning the level (1 bytes)
LEVEL_BG_SCREENS_PTR EQU $C880+$5F   ; Per-screen BG index ptr (3 bytes per screen) (2 bytes)
LEVEL_GP_SCREENS_PTR EQU $C880+$61   ; Per-screen GP index ptr (2 bytes)
LEVEL_FG_SCREENS_PTR EQU $C880+$63   ; Per-screen FG index ptr (2 bytes)
SLR_CUR_X            EQU $C880+$65   ; SHOW_LEVEL: clamped (visible) beam X — actually written to integrator (1 bytes)
SLR_TRUE_X           EQU $C880+$66   ; SHOW_LEVEL: 16-bit unclamped abs_x for per-segment line clipping (2 bytes)
DRAW_T1_SCALED       EQU $C880+$68   ; SHOW_LEVEL: effective T1 for current object (DRAW_SCALE * object_scale) (1 bytes)
SDCP_ABS_Y           EQU $C880+$69   ; SHOW_LEVEL: abs_y temporary for SDCP (cannot share TMPVAL — would corrupt top_screen between layers) (1 bytes)
SLR_TOP_SCREEN       EQU $C880+$6A   ; SHOW_LEVEL: top Y screen idx (lives across all 3 layers — must not be in TMPVAL) (1 bytes)
SLR_BOT_SCREEN       EQU $C880+$6B   ; SHOW_LEVEL: bot Y screen idx (lives across all 3 layers) (1 bytes)
LCOL_PX              EQU $C880+$6C   ; LEVEL_COLLISION player world_x input (16-bit) (2 bytes)
LCOL_BEST_Y          EQU $C880+$6E   ; LEVEL_COLLISION_Y best floor y found (16-bit signed) (2 bytes)
LCOL_PY              EQU $C880+$70   ; LEVEL_COLLISION player_top (16-bit signed) (2 bytes)
LCOL_PHH             EQU $C880+$72   ; LEVEL_COLLISION player half_height (1 bytes)
LCOL_PHW             EQU $C880+$73   ; LEVEL_COLLISION_X player half_width (1 bytes)
LCOL_THW             EQU $C880+$74   ; LEVEL_COLLISION_X total half_width (player_hw + obj_hw scratch) (1 bytes)
LCOL_OBJ_Y           EQU $C880+$75   ; LEVEL_COLLISION_Y current object world_y (16-bit) (2 bytes)
LCOL_LOCAL_PX        EQU $C880+$77   ; LEVEL_COLLISION_Y player_x in object-local coords (16-bit) (2 bytes)
LCOL_OBJ_CNT         EQU $C880+$79   ; LEVEL_COLLISION_Y GP objects remaining (1 bytes)
LCOL_SEG_CNT         EQU $C880+$7A   ; LEVEL_COLLISION_Y mesh floor segments remaining (1 bytes)
ENEMY_POOL           EQU $C880+$7B   ; Enemy instances pool (Phase 2 wander: +18 sub_state, +19 cur_area_idx, +20 idle_timer, +21 trans_type, +22..23 target_x, +24..25 vy/from_x, +26 feet_offset × N) (224 bytes)
ENEMY_LOOP_IDX       EQU $C880+$15B   ; Enemy loop counter (1 bytes)
ENEMY_COUNT          EQU $C880+$15C   ; Active enemy count (1 bytes)
ENEMY_SCRATCH_PTR    EQU $C880+$15D   ; Scratch pointer for enemy iteration (2 bytes)
ENEMY_SCRATCH_X      EQU $C880+$15F   ; Enemy scratch X (2 bytes)
ENEMY_SCRATCH_Y      EQU $C880+$161   ; Enemy scratch Y (2 bytes)
DRAW_ANIM_MIRROR_X   EQU $C880+$163   ; DRAW_ANIM mirror X flag (0=normal, 1=flip) (1 bytes)
DRAW_ANIM_SCALE      EQU $C880+$164   ; DRAW_ANIM T1 scale ($7F=normal) (1 bytes)
DRAW_ANIM_SPEED_MUL  EQU $C880+$165   ; DRAW_ANIM tick multiplier (1=normal) (1 bytes)
DRAW_SCALE           EQU $C880+$166   ; Current T1 scale for Draw_Sync_List_At_With_Mirrors ($7F=normal) (1 bytes)
VAR_ARG0             EQU $C880+$167   ; Function argument 0 (16-bit) (2 bytes)
VAR_ARG1             EQU $C880+$169   ; Function argument 1 (16-bit) (2 bytes)
VAR_ARG2             EQU $C880+$16B   ; Function argument 2 (16-bit) (2 bytes)
VAR_ARG3             EQU $C880+$16D   ; Function argument 3 (16-bit) (2 bytes)
VAR_ARG4             EQU $C880+$16F   ; Function argument 4 (16-bit) (2 bytes)
VAR_ARG5             EQU $C880+$171   ; Function argument 5 (16-bit) (2 bytes)
VAR_ARG6             EQU $C880+$173   ; Function argument 6 (16-bit) (2 bytes)
VAR_ARG7             EQU $C880+$175   ; Function argument 7 (16-bit) (2 bytes)
CURRENT_ROM_BANK     EQU $C880+$177   ; Current ROM bank ID (multibank tracking) (1 bytes)

;***************************************************************************
; MAIN PROGRAM
;***************************************************************************

MAIN:
    ; Initialize global variables
    CLR VPY_MOVE_X        ; MOVE offset defaults to 0
    CLR VPY_MOVE_Y        ; MOVE offset defaults to 0
    CLR DRAW_VEC_INTENSITY ; 0 = use recorded/vector intensity (no override)
    ; Init camera ONCE at boot (RAM not zero-init); LOAD_LEVEL must NOT reset it.
    LDD #0
    STD >CAMERA_X
    STD >CAMERA_Y
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

    ; Prime BIOS button state at startup
    JSR $F1BA    ; Read_Btns: reads PSG reg14 -> $C80F, $C811, $C80E
    ; Call main() for initialization
; VPy_LINE:9
    ; ===== LOAD_LEVEL builtin =====
    ; Load level: 'wlevel'
    LDX #_WLEVEL_LEVEL          ; Pointer to level data in ROM
    JSR LOAD_LEVEL_RUNTIME
; VPy_LINE:10
    ; SPAWN_ENEMIES("wlevel")
    LDB >LEVEL_ENEMY_COUNT        ; count stored by LOAD_LEVEL_RUNTIME
    LDX >LEVEL_ENEMY_INSTANCES_PTR ; instances ptr stored by LOAD_LEVEL_RUNTIME
    JSR SPAWN_ENEMIES_RUNTIME
; VPy_LINE:11
; NATIVE_CALL: SET_CAMERA_X at line 11
    ; ===== SET_CAMERA_X builtin =====
    LDD #0
    STD >CAMERA_X    ; Store 16-bit camera X scroll offset
    LDD #0
    STD RESULT
; VPy_LINE:12
; NATIVE_CALL: SET_CAMERA_Y at line 12
    ; ===== SET_CAMERA_Y builtin =====
    LDD #0
    STD >CAMERA_Y    ; Store 16-bit camera Y scroll offset
    LDD #0
    STD RESULT
    CLR >$C811  ; Force-clear Vec_Buttons before first loop() frame

.MAIN_LOOP:
    JSR LOOP_BODY
    LBRA .MAIN_LOOP   ; Use long branch for multibank support

LOOP_BODY:
    JSR Wait_Recal   ; Synchronize with screen refresh (mandatory)
    JSR $F1BA    ; Read_Btns: PSG reg14 -> $C80F (active-HIGH), edge -> $C811
; VPy_LINE:15
    ; ===== SHOW_LEVEL builtin =====
    JSR SHOW_LEVEL_RUNTIME
    LDD #0
    STD RESULT
; VPy_LINE:16
    ; UPDATE_ENEMIES: advance enemy AI and movement
    JSR UPDATE_ENEMIES_RUNTIME
; VPy_LINE:17
    ; DRAW_ENEMIES: render all active enemies
    JSR DRAW_ENEMIES_RUNTIME
    RTS

;***************************************************************************
; EMBEDDED ASSETS (vectors, music, levels, SFX)
;***************************************************************************

; Generated from enemy.vec (Malban Draw_Sync_List format)
; Total paths: 3, points: 7
; X bounds: min=-15, max=18, width=33
; Center: (1, 5)

_ENEMY_WIDTH EQU 33
_ENEMY_HALF_WIDTH EQU 16
_ENEMY_HEIGHT EQU 30
_ENEMY_HALF_HEIGHT EQU 15
_ENEMY_CENTER_X EQU 1
_ENEMY_CENTER_Y EQU 5

_ENEMY_VECTORS:  ; Main entry (header + 3 path(s))
    FDB 3               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _ENEMY_PATH0        ; pointer to path 0
    FDB _ENEMY_PATH1        ; pointer to path 1
    FDB _ENEMY_PATH2        ; pointer to path 2

_ENEMY_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $FE,$03,0,0        ; path0: header (y=-2, x=3)
    FCB $FF,$09,$09          ; flag=-1, dy=9, dx=9
    FCB 2                ; End marker (path complete)

_ENEMY_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $02,$11,0,0        ; path1: header (y=2, x=17)
    FCB $FF,$F5,$F5          ; flag=-1, dy=-11, dx=-11
    FCB 2                ; End marker (path complete)

_ENEMY_PATH2:    ; Path 2
    FCB 127              ; path2: intensity
    FCB $F1,$0E,0,0        ; path2: header (y=-15, x=14)
    FCB $FF,$00,$E2          ; flag=-1, dy=0, dx=-30
    FCB $FF,$1E,$0F          ; flag=-1, dy=30, dx=15
    FCB $FF,$E2,$0F          ; flag=-1, dy=-30, dx=15
    FCB 2                ; End marker (path complete)
; Generated from platform.vec (Malban Draw_Sync_List format)
; Total paths: 2, points: 7
; X bounds: min=-49, max=48, width=97
; Center: (0, 0)

_PLATFORM_WIDTH EQU 97
_PLATFORM_HALF_WIDTH EQU 48
_PLATFORM_HEIGHT EQU 10
_PLATFORM_HALF_HEIGHT EQU 5
_PLATFORM_CENTER_X EQU 0
_PLATFORM_CENTER_Y EQU 0

_PLATFORM_VECTORS:  ; Main entry (header + 2 path(s))
    FDB 2               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)
    FDB _PLATFORM_PATH0        ; pointer to path 0
    FDB _PLATFORM_PATH1        ; pointer to path 1

_PLATFORM_PATH0:    ; Path 0
    FCB 127              ; path0: intensity
    FCB $05,$30,0,0        ; path0: header (y=5, x=48)
    FCB $FF,$00,$9F          ; flag=-1, dy=0, dx=-97
    FCB 2                ; End marker (path complete)

_PLATFORM_PATH1:    ; Path 1
    FCB 127              ; path1: intensity
    FCB $05,$CF,0,0        ; path1: header (y=5, x=-49)
    FCB $FF,$F6,$00          ; flag=-1, dy=-10, dx=0
    FCB $FF,$00,$61          ; flag=-1, dy=0, dx=97
    FCB $FF,$0A,$00          ; flag=-1, dy=10, dx=0
    FCB $FF,$00,$00          ; flag=-1, dy=0, dx=0
    FCB 2                ; End marker (path complete)
; ==== Level: WLEVEL ====
; Author: 
; Difficulty: medium

_WLEVEL_LEVEL:
    FDB -96  ; World bounds: xMin (16-bit signed)
    FDB 95  ; xMax (16-bit signed)
    FDB -128  ; yMin (16-bit signed)
    FDB 127  ; yMax (16-bit signed)
    FDB 0  ; Time limit (seconds)
    FDB 0  ; Target score
    FCB 2  ; Background object count
    FCB 1  ; Gameplay object count
    FCB 0  ; Foreground object count
    FDB _WLEVEL_BG_OBJECTS
    FDB _WLEVEL_GAMEPLAY_OBJECTS
    FDB _WLEVEL_FG_OBJECTS
    FDB -96  ; scrollLimit left (camera left cannot go below this)
    FDB 95  ; scrollLimit right (camera right cannot exceed this)
    FDB 127  ; scrollLimit top
    FDB -128  ; scrollLimit bottom
    FCB 1  ; enemy_count
    FDB _WLEVEL_ENEMY_INSTANCES  ; enemy_instances_ptr (0 if none)
    FDB 42  ; groundBottomOffset (floor surface offset from screen bottom)
    FCB 1    ; +34 screen_count
    FDB _WLEVEL_BG_SCREENS  ; +35 BG screens index
    FDB _WLEVEL_GP_SCREENS  ; +37 GP screens index
    FDB _WLEVEL_FG_SCREENS  ; +39 FG screens index

_WLEVEL_BG_OBJECTS:
_WLEVEL_BG_OBJECTS_S0:
; Object: obj_1784399032266 (background)
    FCB 4  ; type
    FDB -42  ; x
    FDB -29  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _PLATFORM_VECTORS  ; vector_ptr (ROM+17)
    FCB 48  ; half_width (1.00x, ROM+19)
    FCB 5  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)

; Object: obj_1784399040656 (background)
    FCB 4  ; type
    FDB 45  ; x
    FDB 21  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 1  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB 0   ; vector_bank (ROM+16)
    FDB _PLATFORM_VECTORS  ; vector_ptr (ROM+17)
    FCB 48  ; half_width (1.00x, ROM+19)
    FCB 5  ; half_height (1.00x, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)


_WLEVEL_GAMEPLAY_OBJECTS:
_WLEVEL_GAMEPLAY_OBJECTS_S0:
; Object: e1 (enemy)
    FCB 1  ; type
    FDB -62  ; x
    FDB -4  ; y
    FDB 127  ; scale (T1 direct; 1.00x)
    FCB 0  ; rotation
    FCB 0  ; intensity (0=use vec, >0=override)
    FCB 0  ; velocity_x
    FCB 0  ; velocity_y
    FCB 0  ; physics_flags
    FCB 0  ; collision_flags
    FCB 10  ; collision_size
    FDB 0  ; spawn_delay
    FCB $FF  ; vector_bank = null (no visual, ROM+16)
    FDB 0    ; vector_ptr null (ROM+17)
    FCB 8    ; half_width (default, ROM+19)
    FCB 8    ; half_height (default, ROM+20)
    FDB 0  ; coll_mesh_ptr (AABB fallback, ROM+21)


_WLEVEL_FG_OBJECTS:
_WLEVEL_FG_OBJECTS_S0:

_WLEVEL_BG_SCREENS:
    FCB 2  ; screen 0 count
    FDB _WLEVEL_BG_OBJECTS_S0  ; screen 0 ptr

_WLEVEL_GP_SCREENS:
    FCB 1  ; screen 0 count
    FDB _WLEVEL_GAMEPLAY_OBJECTS_S0  ; screen 0 ptr

_WLEVEL_FG_SCREENS:
    FCB 0  ; screen 0 count
    FDB _WLEVEL_FG_OBJECTS_S0  ; screen 0 ptr

_WLEVEL_ENEMY_COUNT EQU 1

; ---- Enemy instances for level WLEVEL ----
; Instance stride = 14 bytes: type_ptr(2) x(2) y(2) ai(1) wave(1) respawn(1) wp_count(1) wp_ptr(2) feet_off(1) init_area_idx(1)
_WLEVEL_ENEMY_INSTANCES:
    ; instance 0
    FDB _ENEMY_ENEMY   ; enemy type ptr
    FDB -62                   ; spawn x
    FDB -4                   ; spawn y
    FCB 4                    ; ai_type: 0=static,1=patrol,2=chase,3=flee,4=wander
    FCB 0                    ; wave (0=always present)
    FCB 0                    ; respawn: 0=no, 1=yes
    FCB 2                    ; wp_count (or area_count for wander)
    FDB _WLEVEL_ENEMY0_AREAS   ; wp_ptr (or areas_header_ptr for wander; 0 if none)
    FCB 15                    ; feet_offset (sprite half-height for wander, 0 otherwise)
    FCB 0                    ; initial_area_idx (wander only)

; ---- Phase 2 wander: areas table _WLEVEL_ENEMY0_AREAS ----
_WLEVEL_ENEMY0_AREAS:
    FCB 2    ; area_count
    FCB 1    ; trans_count
; Areas (8 bytes each): FDB y, FDB x_min, FDB x_max, FCB 0, FCB 0
    FDB -20  ; area[0].y
    FDB -80  ; area[0].x_min
    FDB 0  ; area[0].x_max
    FCB 0,0      ; pad
    FDB 30  ; area[1].y
    FDB 10  ; area[1].x_min
    FDB 80  ; area[1].x_max
    FCB 0,0      ; pad
; Transitions (8 bytes each): FCB from, FCB to, FCB type, FCB vy0, FDB from_x, FDB to_x
; type: 1=jump_up, 2=drop, 3=jump_across; vy0 = signed initial velocity
    FCB 0,1,1,$0A  ; trans[0] from,to,type,vy0
    FDB -40     ; from_x
    FDB 45     ; to_x

; ---- Enemy type: ENEMY ----
_ENEMY_ACTION_IDLE EQU 0
_ENEMY_ACTION_WALK EQU 1

_ENEMY_ENEMY:
    FCB 3          ; [0] hp
    FCB 40          ; [1] speed (units/sec)
    FDB 180          ; [2-3] action_duration (frames, 16-bit)
    FCB 2          ; [4] action_count
    FDB 0           ; [5-6] no state machine

_ENEMY_ENEMY_ACTIONS:
    FDB _ENEMY_VECTORS    ; action 0 (idle) sprite ptr
    FCB 0                   ; sprite_type: 0=vec, 1=vanim
    FCB 1                   ; loop=true
    FDB _ENEMY_VECTORS    ; action 1 (walk) sprite ptr
    FCB 0                   ; sprite_type: 0=vec, 1=vanim
    FCB 1                   ; loop=true

;***************************************************************************
; RUNTIME HELPERS
;***************************************************************************

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

RAND_HELPER:
    ; LCG: seed = (seed * 1103515245 + 12345) & 0x7FFF
    ; Simplified for 6809: seed = (seed * 25 + 13) & 0x7FFF
    LDD RAND_SEED
    LDX #26
    ; Multiply by 25: loop runs 25 times (LCG a=25, Hull-Dobell ok)
    PSHS D
    LDD #0
RAND_MUL_LOOP:
    LEAX -1,X
    BEQ RAND_MUL_DONE
    ADDD ,S
    BRA RAND_MUL_LOOP
RAND_MUL_DONE:
    LEAS 2,S
    ADDD #13       ; Add constant c=13 (odd, Hull-Dobell ok)
    STD RAND_SEED  ; Store full 16-bit state BEFORE masking output
    ANDA #$7F      ; Mask output to positive 15-bit (state stays full)
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

; ============================================================================
; DRAW_ANIM_RUNTIME
; Input: X = animation ROM header (_ANIM_XXX)
;        U = 2-byte RAM state (byte0=frame_idx, byte1=ticks_left)
;
; Header layout:
;   byte 0: frame_count
;   byte 1: loop_flag (1=loop, 0=freeze)
;   byte 2: base_ref_count  (static cel layer — drawn before every frame)
;   byte 3: frame_table_offset (= 4 + base_ref_count*2)
;   bytes 4..: FDB ptrs to base_ref _VECNAME_VECTORS
;   at frame_table_offset: FDB ptrs to per-frame data
; ============================================================================
DRAW_ANIM_RUNTIME:
; NOTE: do NOT set ACR here. DRAW_VECTOR works without touching ACR;
; setting ACR=$18 (T1 no PB7) breaks T1 timing inside DSWM and hangs.
PSHS D,X,Y,U
; --- Refresh MIRROR_X from saved arg (re-assert before any BIOS call can corrupt A) ---
LDA >DRAW_ANIM_MIRROR_X
STA >MIRROR_X
; --- Apply scale: copy DRAW_ANIM_SCALE to DRAW_SCALE for DSWM ---
LDA >DRAW_ANIM_SCALE
STA >DRAW_SCALE
; --- Draw base_refs (static cel layer, drawn before every frame) ---
LDB 2,X             ; base_ref_count
BEQ DAR_TICK        ; none: skip to tick management
LEAY 4,X            ; Y = first base_ref FDB entry
DAR_BASE_LOOP:
PSHS B,X,Y
LDX ,Y              ; X = _VECNAME_VECTORS header
CLR >MIRROR_Y
JSR $F1AA           ; DP_to_D0
LDD ,X              ; D = path_count (FDB, 2 bytes)
BEQ DAR_BASE_SKIP
LEAY 2,X            ; Y = first path FDB in vec table (skip 2-byte count)
DAR_BASE_PATH_LOOP:
PSHS D,Y
LDX ,Y
JSR Draw_Sync_List_At_With_Mirrors
PULS D,Y
LEAY 2,Y
SUBD #1
BNE DAR_BASE_PATH_LOOP
DAR_BASE_SKIP:
JSR $F1AF           ; DP_to_C8
PULS B,X,Y
LEAY 2,Y            ; next base_ref FDB
DECB
LBNE DAR_BASE_LOOP
; --- Tick counter management ---
DAR_TICK:
LDU 6,S             ; reload U from stack — BIOS may corrupt live U
LDA 1,U             ; ticks_left
BEQ DAR_INIT        ; 0 = first call: initialize frame 0
DECA
BNE DAR_DRAW        ; still on this frame: skip frame advance
; ticks exhausted: advance frame index
LDB ,U              ; current frame_idx
INCB
CMPB ,X             ; frame_count (byte 0)
BLT DAR_NO_WRAP
LDA 1,X             ; loop flag (byte 1)
BEQ DAR_FREEZE      ; loop=0: freeze on last frame
CLRB                ; loop=1: back to frame 0
DAR_NO_WRAP:
STB ,U              ; save new frame_idx
; frame_ptr = X + frame_table_offset + frame_idx*2
LDB ,U              ; new frame_idx
CLRA
LSLB
ROLA                ; D = frame_idx*2
ADDB 3,X            ; D += frame_table_offset (byte 3)
ADCA #0
LEAY D,X            ; Y = &frame_table[frame_idx]
LDY ,Y              ; Y = frame data ptr
LDA ,Y              ; A = duration_ticks from vanim
LDB >DRAW_ANIM_SPEED_MUL
BEQ DAR_SPEED1      ; speed=0: use vanim's duration_ticks as-is
TFR B,A             ; speed>0: override with ticks_per_frame directly
DAR_SPEED1:
CMPA #1
BHS DAR_SPEED1_OK
LDA #1
DAR_SPEED1_OK:
STA 1,U             ; reset ticks_remaining
BRA DAR_EMIT
DAR_FREEZE:
LDA #1
STA 1,U
LDB ,U              ; last frame_idx
CLRA
LSLB
ROLA
ADDB 3,X
ADCA #0
LEAY D,X
LDY ,Y
BRA DAR_EMIT
DAR_INIT:
; First call: frame_idx=0, load frame 0 duration and draw it
CLRB                ; frame_idx = 0
STB ,U
CLRA                ; D = 0 (frame_idx*2 = 0)
ADDB 3,X            ; B = frame_table_offset (frame 0 offset from header)
ADCA #0
LEAY D,X            ; Y = frame_table[0] entry
LDY ,Y              ; Y = frame 0 data ptr
LDA ,Y              ; A = duration_ticks from vanim
LDB >DRAW_ANIM_SPEED_MUL
BEQ DAR_SPEED2      ; speed=0: use vanim's duration_ticks as-is
TFR B,A             ; speed>0: override with ticks_per_frame directly
DAR_SPEED2:
CMPA #1
BHS DAR_SPEED2_OK
LDA #1
DAR_SPEED2_OK:
STA 1,U             ; ticks_left = ticks_per_frame
BRA DAR_EMIT
DAR_DRAW:
STA 1,U             ; save decremented ticks
LDB ,U              ; frame_idx
CLRA
LSLB
ROLA
ADDB 3,X
ADCA #0
LEAY D,X
LDY ,Y              ; Y = frame data ptr
DAR_EMIT:
; frame data: byte 0=duration_ticks (skip), byte 1=vec_ref_count
LEAY 1,Y
LDB ,Y+             ; B = vec_ref_count, Y at first vec ptr
BEQ DAR_INLINE
DAR_VEC_LOOP:
PSHS B,Y
LDX ,Y
JSR $F1AA           ; DP_to_D0
LDD ,X              ; D = path_count (FDB, 2 bytes)
BEQ DAR_VEC_DONE
LEAY 2,X            ; Y = first path FDB (skip 2-byte count)
DAR_VEC_PATH_LOOP:
PSHS D,Y
LDX ,Y
JSR Draw_Sync_List_At_With_Mirrors
PULS D,Y
LEAY 2,Y
SUBD #1
BNE DAR_VEC_PATH_LOOP
DAR_VEC_DONE:
JSR $F1AF           ; DP_to_C8
PULS B,Y
LEAY 2,Y
DECB
BNE DAR_VEC_LOOP
DAR_INLINE:
LDB ,Y+             ; B = inline_path_count
BEQ DAR_DONE
DAR_PATH_LOOP:
PSHS B
TFR Y,X
JSR $F1AA           ; DP_to_D0
JSR Draw_Sync_List_At_With_Mirrors
JSR $F1AF           ; DP_to_C8
LEAY 5,Y            ; skip intensity + 4-byte header
DAR_SCAN:
LDA ,Y+
CMPA #2
BEQ DAR_PATH_DONE
CMPA #$FF
BNE DAR_SCAN
LEAY 2,Y
BRA DAR_SCAN
DAR_PATH_DONE:
PULS B
DECB
BNE DAR_PATH_LOOP
DAR_DONE:
; Restore DRAW_SCALE to default ($7F) after animation draw
LDA #$7F
STA >DRAW_SCALE
PULS D,X,Y,U
RTS

; ============================================================================
; ENEMY SYSTEM RUNTIME  (max 8 enemies, stride 28 bytes)
; ============================================================================
ENEMY_POOL_STRIDE EQU 28
ENEMY_POOL_MAX    EQU 8

; Pool record offsets
POOL_ACTIVE  EQU 0
POOL_X_HI    EQU 1
POOL_X_LO    EQU 2
POOL_Y_HI    EQU 3
POOL_Y_LO    EQU 4
POOL_TYPE_HI EQU 5
POOL_TYPE_LO EQU 6
POOL_ACTION  EQU 7
POOL_AI      EQU 8
POOL_HP      EQU 9
POOL_WPIDX   EQU 10
POOL_WPPTR   EQU 11
POOL_SM_STATE EQU 13
POOL_SM_TMR_HI EQU 14
POOL_SM_TMR_LO EQU 15
POOL_WPCOUNT   EQU 16
POOL_DIR        EQU 17
POOL_SUB_STATE  EQU 18
POOL_AREA_IDX   EQU 19
POOL_IDLE_TIMER EQU 20
POOL_TRANS_TYPE EQU 21
POOL_TARGET_X_HI EQU 22
POOL_TARGET_X_LO EQU 23
POOL_FROMX_OR_VY_HI EQU 24
POOL_FROMX_OR_VY_LO EQU 25
POOL_FEET_OFFSET EQU 26
POOL_VY0_STASH EQU 27
;   POOL_FROMX_OR_VY (2) — WALK_TO_TAKEOFF: from_x (i16). AIRBORNE: vy (i16, low byte = i8 vy).
;   POOL_FEET_OFFSET (1) — set at SPAWN to enemy's sprite half-height. Used to snap
;     world_y = area.y + feet_offset on spawn and on land.
;   POOL_VY0_STASH (1) — initial vy of the in-progress transition (set at commit,
;     applied at takeoff). Comes from trans entry's vy0 byte (per-transition tuned).
;   POOL_DIR (1) — 0=facing right, 1=facing left. Written by UPDATE_ENEMIES when
;   patrol moves the enemy on X (LBGT path = right, LBLT/SUB path = left). Read by
;   DRAW_ENEMIES into MIRROR_X so the sprite reflects the current direction.
;   POOL_SUB_STATE (1) — wander only. 0=WALK, 1=IDLE, 2=AIRBORNE, 3=WALK_TO_TAKEOFF
;   POOL_AREA_IDX (1) — wander only. Current area index into level's AREAS table.
;   POOL_IDLE_TIMER (1) — wander only. Frames remaining in idle. Decremented each
;   frame while sub_state=1; on expire either commits a transition or returns to WALK.
;   POOL_TRANS_TYPE (1) — wander only. Type of in-progress transition: 1=jump_up, 2=drop, 3=jump_across.
;   POOL_TARGET_X (2) — wander only. Target X stashed at transition commit (i16).
;   POOL_VY (2) — wander only. AIRBORNE: signed vertical velocity (i16, only low byte typically used).
;     WALK_TO_TAKEOFF: stores from_x in same slot since vy isn't used yet.
; For wander enemies, wp_ptr (pool +11..12) is reused as areas_ptr (points to
;   _LVL_AREAS_HEADER), and wp_count (pool +16) holds area_count.
; SM state record layout (SM_STATE_STRIDE = 13 bytes, max 4 events)
SM_STATE_STRIDE EQU 13
SM_HDR_INIT   EQU 1
SM_HDR_STATES EQU 2
SM_ST_ACTION  EQU 0
SM_ST_DCY_HI  EQU 1
SM_ST_DCY_LO  EQU 2
SM_ST_DCYTO   EQU 3
SM_ST_NEVT    EQU 4
SM_ST_EVT0H   EQU 5
SM_ST_EVT0T   EQU 6
SM_ST_EVT1H   EQU 7
SM_ST_EVT1T   EQU 8
SM_ST_EVT2H   EQU 9
SM_ST_EVT2T   EQU 10
SM_ST_EVT3H   EQU 11
SM_ST_EVT3T   EQU 12

; SPAWN_ENEMIES_RUNTIME
; Entry: B = instance count, X = ptr to _LEVEL_ENEMY_INSTANCES table
; Initialises ENEMY_POOL from the ROM instance table.
SPAWN_ENEMIES_RUNTIME:
; Entry: B = total ROM instance count, X = ptr to instances table.
; Per-screen reuse (mirrors pitrex): only spawn enemies whose world Y is
; within +/-150 of CAMERA_Y, capped at the pool size (8).
LBEQ SPAWN_ENE_DONE
STB >ENEMY_LOOP_IDX        ; scan counter = total ROM entries to examine
; Zero-clear ALL pool slots so stale enemies from the previous screen vanish
LDY #ENEMY_POOL
LDB #8
CLRA
SPAWN_CLR_LOOP:
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+
STA ,Y+                    ; +17 dir (clears to 0=right)
STA ,Y+                    ; +18 sub_state (clears to 0=WALK)
STA ,Y+                    ; +19 cur_area_idx (clears to 0)
STA ,Y+                    ; +20 idle_timer (clears to 0)
STA ,Y+                    ; +21 trans_type (clears to 0)
STA ,Y+                    ; +22 target_x hi
STA ,Y+                    ; +23 target_x lo
STA ,Y+                    ; +24 from_x/vy hi
STA ,Y+                    ; +25 from_x/vy lo
STA ,Y+                    ; +26 feet_offset (set by SPAWN_FILL for wander)
STA ,Y+                    ; +27 pad
DECB
BNE SPAWN_CLR_LOOP
CLR >ENEMY_COUNT           ; spawned (in-range) count = 0
LDX >LEVEL_ENEMY_INSTANCES_PTR
STX >ENEMY_SCRATCH_PTR
LDY #ENEMY_POOL
SPAWN_SCAN_LOOP:
LDX >ENEMY_SCRATCH_PTR
LDD 4,X                    ; D = instance world Y (offset +4,+5)
SUBD >CAMERA_Y             ; D = spawn_y - camera_y
CMPD #150
LBGT SPAWN_SKIP            ; off-screen below (signed)
CMPD #$FF6A                ; -150: off-screen above (signed)
LBLT SPAWN_SKIP
LDA #1
STA ,Y              ; +0 active=1
LDA 2,X
STA 1,Y             ; +1 x hi
LDA 3,X
STA 2,Y             ; +2 x lo
LDA 4,X
STA 3,Y             ; +3 y hi
LDA 5,X
STA 4,Y             ; +4 y lo
LDA ,X
STA 5,Y             ; +5 type_ptr hi
LDA 1,X
STA 6,Y             ; +6 type_ptr lo
CLR 7,Y             ; +7 action=0 (idle)
LDA 6,X
STA 8,Y             ; +8 ai_type
; hp = first byte of enemy type block
LDX >ENEMY_SCRATCH_PTR  ; reload instance ptr (X still valid here)
PSHS B,X,Y
LDA 5,Y
LDB 6,Y
TFR D,X             ; X = type_ptr = _NAME_ENEMY header
LDA ,X              ; hp byte
PULS B,X,Y
STA 9,Y             ; +9 hp
CLR 10,Y            ; +10 wp_idx=0
LDA 9,X
STA 16,Y            ; +16 wp_count
LDA 10,X
STA 11,Y            ; +11 wp_ptr hi
LDA 11,X
STA 12,Y            ; +12 wp_ptr lo
; Init SM state (+13) from type header [5-6] = SM ptr
PSHS B              ; save loop counter (B clobbered by LDB below)
LDA 5,Y             ; type_ptr hi (pool)
LDB 6,Y             ; type_ptr lo (pool)
TFR D,X             ; X = _NAME_ENEMY header
LDA 5,X             ; SM ptr hi (header[5])
LDB 6,X             ; SM ptr lo (header[6])
CMPD #0
BEQ SPAWN_SM_NOSM   ; no state machine
TFR D,X             ; X = SM table header
PSHS X              ; save SM header ptr
LDA 1,X             ; initial_state_idx
STA 13,Y            ; pool.sm_state = initial
; Look up initial state action
TFR A,B             ; B = initial_state_idx
PULS X              ; X = SM header
LEAX 2,X            ; X = &states[0]
LDA #13             ; stride = 13 bytes per state record
MUL                 ; D = initial_state_idx * 13
LEAX D,X            ; X = &states[initial]
LDA ,X              ; action_idx from state[0]
STA 7,Y             ; pool.action = initial action
BRA SPAWN_SM_DONE
SPAWN_SM_NOSM:
LDA #$FF
STA 13,Y            ; pool.sm_state = $FF (no SM)
SPAWN_SM_DONE:
PULS B              ; restore loop counter
CLR 14,Y            ; pool.sm_decay_timer hi = 0
CLR 15,Y            ; pool.sm_decay_timer lo = 0
; Wander (ai_type=4) starts in walk action and copies feet_offset+area_idx.
; CRITICAL: X is currently type_ptr or SM_state record (clobbered by SM init).
; Must reload X = ENEMY_SCRATCH_PTR (instance ptr) before reading instance bytes.
LDA 8,Y             ; ai_type
CMPA #4
BNE SPAWN_ACT_DONE
LDA #1
STA 7,Y             ; action=1 (walk)
LDX >ENEMY_SCRATCH_PTR  ; X = instance ptr (was clobbered by SM init)
LDA 12,X            ; instance.feet_offset (instance +12)
STA 26,Y            ; pool.feet_offset
LDA 13,X            ; instance.initial_area_idx (instance +13)
STA 19,Y            ; pool.cur_area_idx
SPAWN_ACT_DONE:
; filled a slot: advance pool ptr, bump spawned count, stop if pool full
LEAY 28,Y
INC >ENEMY_COUNT
LDA >ENEMY_COUNT
CMPA #8
BHS SPAWN_ENE_DONE         ; pool full -> stop scanning
SPAWN_SKIP:
; advance to next ROM instance (stride 14) and keep scanning
LDX >ENEMY_SCRATCH_PTR
LEAX 14,X
STX >ENEMY_SCRATCH_PTR
DEC >ENEMY_LOOP_IDX
LBNE SPAWN_SCAN_LOOP
SPAWN_ENE_DONE:
RTS

; UPDATE_ENEMIES_RUNTIME (single-bank)
; Same as multibank version without bank switching.
UPDATE_ENEMIES_RUNTIME:
LDB >ENEMY_COUNT
LBEQ UPD_ENE_DONE
LDY #ENEMY_POOL
UPD_ENE_LOOP:
PSHS B
LDA ,Y
LBEQ UPD_ENE_NEXT_POP
JSR UPD_DECAY_CHECK   ; SM auto-decay (matches per-state decay_frames)
; Frozen-action guard: action >= 2 = SM-frozen (snow1/snow2/ball) → skip movement
LDA 7,Y
CMPA #2
LBHS UPD_ENE_NEXT_POP
LDA 8,Y
CMPA #1
LBEQ UPD_PATROL
CMPA #4
LBEQ UPD_WANDER
LBRA UPD_ENE_NEXT_POP

UPD_PATROL:
LDA 11,Y
LDB 12,Y
CMPD #0
LBEQ UPD_ENE_NEXT_POP
TFR D,X
LDA 10,Y
ASLA
ASLA
LEAX A,X
LDD ,X
CMPD 1,Y
LBEQ UPD_P_MOVE_Y
LBGT UPD_P_INC_X
LDD 1,Y
SUBD #1
STD 1,Y
LDA #1
STA 17,Y
LBRA UPD_P_MOVE_Y
UPD_P_INC_X:
LDD 1,Y
ADDD #1
STD 1,Y
CLR 17,Y
UPD_P_MOVE_Y:
LDD 2,X
CMPD 3,Y
LBEQ UPD_P_CHECK_WP
LBGT UPD_P_INC_Y
LDD 3,Y
SUBD #1
STD 3,Y
LBRA UPD_ENE_NEXT_POP
UPD_P_INC_Y:
LDD 3,Y
ADDD #1
STD 3,Y
LBRA UPD_ENE_NEXT_POP
UPD_P_CHECK_WP:
LDD ,X
CMPD 1,Y
LBNE UPD_ENE_NEXT_POP
INC 10,Y
LDA 10,Y
CMPA 16,Y
LBLO UPD_ENE_NEXT_POP
CLR 10,Y
LBRA UPD_ENE_NEXT_POP

UPD_WANDER:
LDA 18,Y
LBEQ UPD_W_WALK
CMPA #1
LBEQ UPD_W_IDLE
CMPA #2
LBEQ UPD_W_AIR
CMPA #3
LBEQ UPD_W_TT
LBRA UPD_ENE_NEXT_POP

UPD_W_WALK:
LDA 11,Y
LDB 12,Y
CMPD #0
LBEQ UPD_ENE_NEXT_POP
TFR D,X
LDB 19,Y
LDA #8
MUL
ADDD #2
LEAX D,X
LDA 17,Y
LBNE UPD_W_WALK_L
LDD 1,Y
ADDD #1
PSHS D
LDD 4,X
CMPD ,S
LBLT UPD_W_EDGE_R
PULS D
STD 1,Y
LBRA UPD_ENE_NEXT_POP
UPD_W_EDGE_R:
LEAS 2,S
LDD 4,X
STD 1,Y
LBRA UPD_W_EDGE
UPD_W_WALK_L:
LDD 1,Y
SUBD #1
PSHS D
LDD 2,X
CMPD ,S
LBGT UPD_W_EDGE_L
PULS D
STD 1,Y
LBRA UPD_ENE_NEXT_POP
UPD_W_EDGE_L:
LEAS 2,S
LDD 2,X
STD 1,Y
UPD_W_EDGE:
LDA 17,Y
EORA #1
STA 17,Y
LDA #1
STA 18,Y
CLR 7,Y
JSR RAND_HELPER
ANDB #$3F
ADDB #90
STB 20,Y
LBRA UPD_ENE_NEXT_POP

UPD_W_IDLE:
DEC 20,Y
LBNE UPD_ENE_NEXT_POP
LDA 11,Y
LDB 12,Y
TFR D,X
LDB 1,X
LBEQ UPD_W_TO_WALK
PSHS B
LDA ,X
LDB #8
MUL
ADDD #2
LEAX D,X
PULS B
UPD_W_TRY_LOOP:
LDA 19,Y
CMPA ,X
BNE UPD_W_NEXT_TRY
PSHS B,X
JSR RAND_HELPER
CMPA #32            ; ~25% commit. Use the high byte (A, 0..127): the LCG's
PULS B,X            ; low 2 bits flip +1/call, and with 2 rolls/idle cycle a
BHS UPD_W_NEXT_TRY  ; low-bit coin locks to {1,3} for odd seeds -> never fires.
LDA 1,X
STA 19,Y
LDA 2,X
STA 21,Y
LDA 3,X
STA 27,Y            ; vy0_stash from trans entry
LDD 4,X
STD 24,Y
LDD 6,X
STD 22,Y
LDA #3
STA 18,Y
LDA #1
STA 7,Y
LBRA UPD_ENE_NEXT_POP
UPD_W_NEXT_TRY:
LEAX 8,X
DECB
BNE UPD_W_TRY_LOOP
UPD_W_TO_WALK:
CLR 18,Y
LDA #1
STA 7,Y
LBRA UPD_ENE_NEXT_POP

UPD_W_TT:
LDD 24,Y
CMPD 1,Y
LBEQ UPD_W_TT_REACHED
LBGT UPD_W_TT_RIGHT
LDD 1,Y
SUBD #1
STD 1,Y
LDA #1
STA 17,Y
LBRA UPD_ENE_NEXT_POP
UPD_W_TT_RIGHT:
LDD 1,Y
ADDD #1
STD 1,Y
CLR 17,Y
LBRA UPD_ENE_NEXT_POP
UPD_W_TT_REACHED:
LDA 27,Y            ; vy0_stash from commit
STA 25,Y
LDA #120
STA 24,Y
LDD 22,Y
CMPD 1,Y
LBGT UPD_W_TT_FACE_R
LDA #1
STA 17,Y
LBRA UPD_W_TT_AIR
UPD_W_TT_FACE_R:
CLR 17,Y
UPD_W_TT_AIR:
LDA #2
STA 18,Y
LBRA UPD_ENE_NEXT_POP

UPD_W_AIR:
DEC 24,Y
LBEQ UPD_W_AIR_LAND
LDD 22,Y
CMPD 1,Y
LBEQ UPD_W_AIR_Y
LBGT UPD_W_AIR_X_R
LDD 1,Y
SUBD #2
CMPD 22,Y
LBGT UPD_W_AIR_X_OKL
LDD 22,Y
UPD_W_AIR_X_OKL:
STD 1,Y
LBRA UPD_W_AIR_Y
UPD_W_AIR_X_R:
LDD 1,Y
ADDD #2
CMPD 22,Y
LBLT UPD_W_AIR_X_OKR
LDD 22,Y
UPD_W_AIR_X_OKR:
STD 1,Y
UPD_W_AIR_Y:
LDB 25,Y
SEX
ADDD 3,Y
STD 3,Y
LDB 25,Y
DECB
CMPB #$FC
BGE UPD_W_AIR_VYOK
LDB #$FC
UPD_W_AIR_VYOK:
STB 25,Y
LDA 11,Y
LDB 12,Y
TFR D,X
LDB 19,Y
LDA #8
MUL
ADDD #2
LEAX D,X            ; X = &area[cur_area]
LDB 26,Y            ; B = feet_offset
CLRA
ADDD ,X             ; D = feet_offset + area.y
PSHS D              ; stash target_y
LDA 21,Y
CMPA #2
BEQ UPD_W_AIR_CHK_DOWN
LDB 25,Y
TSTB
BPL UPD_W_AIR_NOLAND
UPD_W_AIR_CHK_DOWN:
LDD ,S
CMPD 3,Y
LBLT UPD_W_AIR_NOLAND
PULS D
STD 3,Y
CLR 18,Y
LDA #1
STA 7,Y
LBRA UPD_ENE_NEXT_POP
UPD_W_AIR_NOLAND:
LEAS 2,S
LBRA UPD_ENE_NEXT_POP
UPD_W_AIR_LAND:
LDA 11,Y
LDB 12,Y
TFR D,X
LDB 19,Y
LDA #8
MUL
ADDD #2
LEAX D,X
LDB 26,Y
CLRA
ADDD ,X             ; D = feet_offset + area.y
STD 3,Y
CLR 18,Y
LDA #1
STA 7,Y
LBRA UPD_ENE_NEXT_POP

UPD_ENE_NEXT_POP:
PULS B
LEAY 28,Y
DECB
LBNE UPD_ENE_LOOP
UPD_ENE_DONE:
RTS

; DRAW_ENEMIES_RUNTIME
; For each active enemy, draws its current-action sprite.
; Enemy type header layout: FCB hp, FCB speed, FDB action_dur, FCB action_count
;   followed by _NAME_ENEMY_ACTIONS table.
; Multibank action entry (6 bytes):
;   [0] FCB sprite_idx   — 0-based index into VECTOR_ADDR_TABLE (vec) or ANIM_ADDR_TABLE (vanim); $FF=none
;   [1] FCB sprite_type  — 0=vec, 1=vanim
;   [2] FCB loop         — 0=one-shot, 1=loop
;   [3] FCB pad
;   [4-5] FDB anim_state — 16-bit RAM address of 2-byte animation state; 0 for vec actions
; Enemy type data resides in the helpers bank (always accessible).
DRAW_ENEMIES_RUNTIME:
LDB >ENEMY_COUNT
LBEQ DRW_ENE_DONE
LDY #ENEMY_POOL
DRW_ENE_LOOP:
PSHS B              ; save outer loop counter
LDA ,Y              ; active?
LBEQ DRW_ENE_NEXT_POP
; Resolve type header and action table entry
LDA 5,Y             ; type_ptr hi
LDB 6,Y             ; type_ptr lo
TFR D,X             ; X = _NAME_ENEMY header
LEAX 7,X            ; skip 7-byte header → action table
LDA 7,Y             ; action index
    LDB #4              ; 4 bytes per action entry (FDB sprite_ptr+FCB type+FCB loop)
MUL                 ; D = action_idx * 4
LEAX D,X            ; X = &actions[action]
LDD ,X              ; sprite_ptr = FDB at action[0,1] (_NAME_VECTORS address)
CMPD #0             ; 0 = no sprite assigned
LBEQ DRW_ENE_NEXT_POP
TFR D,X             ; X = _NAME_VECTORS header address
; screen_x = world_x(16-bit) - camera_x(16-bit), y unchanged
LDA 1,Y             ; world_x hi (POOL_X_HI)
LDB 2,Y             ; world_x lo (POOL_X_LO)
SUBD CAMERA_X       ; D = world_x - camera_x (16-bit, DP=$C8 relative)
STA TMPPTR2         ; save high byte for range check
TFR B,A
SEX                 ; A = sign-extend of B (0x00 or 0xFF)
CMPA TMPPTR2        ; compare with actual high byte
LBNE DRW_ENE_NEXT_POP  ; out of 8-bit range — skip draw
STB DRAW_VEC_X      ; screen_x lo byte
STA DRAW_VEC_X_HI   ; A holds sign-extension of B (set by SEX above)
LDB 4,Y             ; world_y lo (POOL_Y_LO)
STB DRAW_VEC_Y
CLR DRAW_VEC_INTENSITY  ; use vector's own intensity
; Mirror from POOL_DIR (set by UPDATE_ENEMIES patrol move): 0=right, 1=left.
; Set both MIRROR_X (path loop) and DRAW_ANIM_MIRROR_X (DAR re-applies it
; per frame because DRAW_ANIM_BANKED clears MIRROR_X at entry).
LDA 17,Y
STA MIRROR_X
STA DRAW_ANIM_MIRROR_X
CLR MIRROR_Y
; Draw paths — mirrors DRAW_VECTOR_BANKED path loop (no bank switch)
JSR $F1AA           ; DP_to_D0 (required before DSWM / VIA access)
LDD ,X              ; D = path_count (FDB at vector header start)
CMPD #0
LBEQ DRW_ENE_SB_DONE
PSHS Y              ; save pool ptr (Y used as path table ptr below)
LEAY 2,X            ; Y = first path FDB entry (skip 2-byte path_count)
DRW_ENE_SB_PATH:
PSHS D              ; save remaining path count
LDX ,Y              ; X = path data address (FDB entry)
JSR Draw_Sync_List_At_With_Mirrors
LEAY 2,Y            ; advance to next FDB entry
PULS D              ; restore count
SUBD #1
BNE DRW_ENE_SB_PATH
PULS Y              ; restore pool ptr
DRW_ENE_SB_DONE:
JSR $F1AF           ; DP_to_C8 (restore DP for RAM access)
DRW_ENE_NEXT_POP:
PULS B              ; restore outer loop counter
LEAY 28,Y           ; next pool record
DECB
LBNE DRW_ENE_LOOP
DRW_ENE_DONE:
RTS


; KILL_ENEMY_RUNTIME
; Entry: A = enemy index (0-based)
; Effect: pool[A].active=0, ENEMY_COUNT--
; Return: RESULT = new ENEMY_COUNT (D)
KILL_ENEMY_RUNTIME:
LDB #28             ; ENEMY_POOL_STRIDE
MUL
LDX #ENEMY_POOL
LEAX D,X
CLR ,X              ; active = 0
DEC >ENEMY_COUNT
CLRA
LDB >ENEMY_COUNT
STD RESULT
RTS

; ENEMY_FIRE_EVENT_RUNTIME
; Entry: A = enemy index, B = event hash (FNV-1a u8)
; Looks up the current SM state, scans on_event table, applies transition.
; Uses ENEMY_SCRATCH_PTR (2 bytes) and ENEMY_SCRATCH_X (1 byte) as temporals.
ENEMY_FIRE_EVENT_RUNTIME:
STB >ENEMY_SCRATCH_X    ; save event hash (1 byte)
LDB #28                 ; ENEMY_POOL_STRIDE — was hard-coded 17 which is WRONG (real stride=28); idx>0 wrote to wrong pool entry
MUL                     ; D = A * stride
LDX #ENEMY_POOL
LEAX D,X                ; X = &pool[A]
STX >ENEMY_SCRATCH_PTR  ; save pool ptr
LDA 13,X     ; sm_state
CMPA #$FF
BEQ FIRE_EVT_RTS        ; no SM
LDA 5,X
LDB 6,X
TFR D,X                 ; X = type header
LDA 5,X                 ; SM hi
LDB 6,X                 ; SM lo
CMPD #0
BEQ FIRE_EVT_RTS
TFR D,X                 ; X = SM header
LEAX 2,X    ; X = &states[0]
PSHS X                  ; save states[0] ptr on stack
LDX >ENEMY_SCRATCH_PTR  ; X = pool entry
LDA 13,X     ; current state
PULS X                  ; X = states[0] again
LDB #13
MUL
LEAX D,X                ; X = &states[current]
LDB 4,X        ; event count
BEQ FIRE_EVT_RTS
LEAX 5,X      ; X = first event pair
LDA >ENEMY_SCRATCH_X    ; event hash
FIRE_EVT_SCAN:
CMPA ,X
BEQ FIRE_EVT_MATCH
LEAX 2,X
DECB
BNE FIRE_EVT_SCAN
BRA FIRE_EVT_RTS
FIRE_EVT_MATCH:
LDB 1,X                 ; to_state_idx
STB >ENEMY_SCRATCH_X    ; save to_state_idx
LDX >ENEMY_SCRATCH_PTR  ; X = pool entry
STB 13,X     ; apply new state
; Look up new state record for action/decay
LDA 5,X
LDB 6,X
TFR D,X                 ; X = type header
LDA 5,X
LDB 6,X
TFR D,X                 ; X = SM header
LEAX 2,X    ; X = &states[0]
LDA >ENEMY_SCRATCH_X    ; to_state_idx
LDB #13
MUL
LEAX D,X                ; X = &states[to]
; Store action/decay into pool without LDY (VASM LDY extended mode bug workaround)
LDA 1,X
LDB 2,X
STD >ENEMY_SCRATCH_Y    ; save decay hi+lo in 2-byte scratch
LDA 0,X      ; action_idx
PSHS A                  ; save action on stack
LDX >ENEMY_SCRATCH_PTR  ; X = pool entry
PULS A
STA 7,X       ; update pool action
LDA >ENEMY_SCRATCH_Y
STA 14,X
LDA >ENEMY_SCRATCH_Y+1
STA 15,X
FIRE_EVT_RTS:
RTS

; SET_ENEMY_STATE_RUNTIME
; Entry: A = enemy idx, B = target state_idx
; Thin wrapper: compute pool ptr from idx, then dispatch to SES_APPLY which
; does the actual state-record lookup and field writes. SES_APPLY is also
; called from UPD_DECAY_CHECK (auto-decay) using Y-derived pool ptr.
SET_ENEMY_STATE_RUNTIME:
STB >ENEMY_SCRATCH_X    ; save target state_idx
LDB #28                 ; ENEMY_POOL_STRIDE
MUL
LDX #ENEMY_POOL
LEAX D,X                ; X = &pool[idx]
STX >ENEMY_SCRATCH_PTR
JMP SES_APPLY

; SES_APPLY: apply a state transition to a pool entry.
; Entry: ENEMY_SCRATCH_PTR = pool entry ptr, ENEMY_SCRATCH_X = target_state_idx
; Updates pool.sm_state (+13), pool.action (+7) [unless action_idx=$FF=keep],
; and pool.sm_decay_timer (+14..15) from the type's SM state record.
; Falls back to plain STB 13,X if no SM exists. Preserves Y.
SES_APPLY:
LDX >ENEMY_SCRATCH_PTR
LDA 13,X                ; current sm_state
CMPA #$FF
BEQ SES_PLAIN           ; no SM → just store the byte
LDA 5,X                 ; type_ptr hi
LDB 6,X                 ; type_ptr lo
TFR D,X                 ; X = type header
LDA 5,X                 ; SM ptr hi
LDB 6,X                 ; SM ptr lo
CMPD #0
BEQ SES_PLAIN
TFR D,X                 ; X = SM header
LEAX 2,X                ; X = &states[0]
LDA >ENEMY_SCRATCH_X    ; target state_idx
LDB #13
MUL                     ; D = target * 13
LEAX D,X                ; X = &states[target]
LDA 1,X
LDB 2,X
STD >ENEMY_SCRATCH_Y    ; stash decay hi+lo
LDA ,X                  ; action_idx ($FF = keep)
PSHS A
LDX >ENEMY_SCRATCH_PTR  ; X = pool entry
LDB >ENEMY_SCRATCH_X    ; target state_idx
STB 13,X                ; pool.sm_state = target
PULS A
CMPA #$FF
BEQ SES_SKIP_ACTION
STA 7,X                 ; pool.action = state.action
SES_SKIP_ACTION:
LDA >ENEMY_SCRATCH_Y
STA 14,X                ; sm_decay_timer hi
LDA >ENEMY_SCRATCH_Y+1
STA 15,X                ; sm_decay_timer lo
RTS
SES_PLAIN:
LDX >ENEMY_SCRATCH_PTR
LDB >ENEMY_SCRATCH_X
STB 13,X
RTS

; UPD_DECAY_CHECK: auto-decay tick for one pool entry.
; Entry: Y = &pool[i] (preserved on exit)
; If pool.sm_decay_timer > 0: decrement. On reaching 0, look up the current
; state's decay_to_idx (state record offset +3) and apply that transition
; via SES_APPLY. If decay_to is $FF (none) the state stays put.
; Honours the per-state decay_frames declared in the .venemy SM, so SnowBros
; thaw walks ball→snow2→snow1→normal automatically with their own timings.
UPD_DECAY_CHECK:
LDD 14,Y                ; sm_decay_timer
LBEQ UDC_DONE           ; not decaying
SUBD #1
STD 14,Y
LBNE UDC_DONE           ; still counting
; Timer hit 0 → resolve current state's decay_to
LDA 5,Y
LDB 6,Y
TFR D,X                 ; X = type header
LDA 5,X
LDB 6,X
CMPD #0
BEQ UDC_DONE            ; no SM (defensive)
TFR D,X                 ; X = SM header
LEAX 2,X                ; X = &states[0]
LDA 13,Y                ; current sm_state
LDB #13
MUL
LEAX D,X                ; X = &states[current]
LDA 3,X                 ; decay_to_idx
CMPA #$FF
BEQ UDC_DONE            ; no decay target
; Apply transition via SES_APPLY (preserves Y)
STA >ENEMY_SCRATCH_X    ; target = decay_to_idx
STY >ENEMY_SCRATCH_PTR  ; pool ptr = current Y
JSR SES_APPLY
UDC_DONE:
RTS

;**** PRINT_TEXT String Data ****
PRINT_TEXT_STR_3509734765:
    FCC "wlevel"
    FCB $80          ; Vectrex string terminator

