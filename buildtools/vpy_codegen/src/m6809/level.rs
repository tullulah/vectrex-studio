// Level System Builtins for VPy
// vplay-aware level loading, rendering, and physics

use std::collections::HashSet;
use vpy_parser::Expr;
use super::builtins::is_multibank;
use crate::AssetInfo;

/// Emit LOAD_LEVEL(level_name) - Load level data from ROM
///
/// Reads the vplay ROM header format:
///   +0..+7:   FDB xMin, xMax, yMin, yMax   (world bounds)
///   +8..+11:  FDB timeLimit, targetScore
///   +12:      FCB bgCount
///   +13:      FCB gpCount
///   +14:      FCB fgCount
///   +15..+16: FDB bgObjectsPtr
///   +17..+18: FDB gpObjectsPtr
///   +19..+20: FDB fgObjectsPtr
///
/// GP objects (20 bytes each in ROM) are copied to LEVEL_GP_BUFFER (14 bytes each in RAM).
/// BG/FG objects stay in ROM and are read directly with stride 20.
pub fn emit_load_level(args: &[Expr], out: &mut String, assets: &[AssetInfo]) {
    out.push_str("    ; ===== LOAD_LEVEL builtin =====\n");

    if args.len() != 1 {
        out.push_str("    ; ERROR: LOAD_LEVEL requires 1 argument (level_name)\n");
        out.push_str("    LDD #0\n");
        out.push_str("    STD RESULT\n");
        return;
    }

    if let Expr::StringLit(level_name) = &args[0] {
        out.push_str(&format!("    ; Load level: '{}'\n", level_name));

        if is_multibank() {
            // Multibank mode: use LOAD_LEVEL_BANKED with index
            let level_assets: Vec<_> = assets.iter()
                .filter(|a| matches!(a.asset_type, crate::AssetType::Level))
                .collect();

            let level_index = level_assets.iter()
                .position(|a| a.name.eq_ignore_ascii_case(level_name));

            if let Some(idx) = level_index {
                out.push_str(&format!("    ; Level asset index: {} (multibank)\n", idx));
                out.push_str(&format!("    LDX #{}\n", idx));
                out.push_str("    JSR LOAD_LEVEL_BANKED\n");
            } else {
                out.push_str(&format!("    ; ERROR: Level '{}' not found in assets\n", level_name));
                out.push_str("    LDD #0\n");
                out.push_str("    STD RESULT\n");
            }
        } else {
            // Single-bank mode: call LOAD_LEVEL_RUNTIME with level ROM label
            let label = format!(
                "_{}_LEVEL",
                level_name.to_uppercase().replace('-', "_").replace(' ', "_")
            );
            out.push_str(&format!("    LDX #{}          ; Pointer to level data in ROM\n", label));
            out.push_str("    JSR LOAD_LEVEL_RUNTIME\n");
        }
    } else {
        out.push_str("    ; ERROR: LOAD_LEVEL requires string literal (level name)\n");
        out.push_str("    LDD #0\n");
        out.push_str("    STD RESULT\n");
    }
}

/// Emit SHOW_LEVEL() - Render current level using vplay layer system
pub fn emit_show_level(_args: &[Expr], out: &mut String) {
    out.push_str("    ; ===== SHOW_LEVEL builtin =====\n");
    out.push_str("    JSR SHOW_LEVEL_RUNTIME\n");
    out.push_str("    LDD #0\n");
    out.push_str("    STD RESULT\n");
}

/// Emit UPDATE_LEVEL() - Update level state (physics, velocity, bouncing)
pub fn emit_update_level(_args: &[Expr], out: &mut String) {
    out.push_str("    ; ===== UPDATE_LEVEL builtin =====\n");
    out.push_str("    JSR UPDATE_LEVEL_RUNTIME\n");
    out.push_str("    LDD #0\n");
    out.push_str("    STD RESULT\n");
}

/// Emit GET_LEVEL_WIDTH() - Return level width in tiles (legacy, returns 0 for vplay)
pub fn emit_get_level_width(_args: &[Expr], out: &mut String) {
    out.push_str("    ; ===== GET_LEVEL_WIDTH builtin =====\n");
    out.push_str("    CLR RESULT             ; Clear high byte\n");
    out.push_str("    LDA LEVEL_WIDTH        ; Load width (byte)\n");
    out.push_str("    STA RESULT+1           ; Store in low byte\n");
}

/// Emit GET_LEVEL_HEIGHT() - Return level height in tiles (legacy, returns 0 for vplay)
pub fn emit_get_level_height(_args: &[Expr], out: &mut String) {
    out.push_str("    ; ===== GET_LEVEL_HEIGHT builtin =====\n");
    out.push_str("    CLR RESULT             ; Clear high byte\n");
    out.push_str("    LDA LEVEL_HEIGHT       ; Load height (byte)\n");
    out.push_str("    STA RESULT+1           ; Store in low byte\n");
}

/// Emit GET_LEVEL_TILE(x, y) - Get tile at position (legacy tile-based API)
pub fn emit_get_level_tile(args: &[Expr], out: &mut String) {
    out.push_str("    ; ===== GET_LEVEL_TILE builtin =====\n");

    if args.len() != 2 {
        out.push_str("    ; ERROR: GET_LEVEL_TILE requires 2 arguments (x, y)\n");
        out.push_str("    LDD #0\n");
        out.push_str("    STD RESULT\n");
        return;
    }

    if let (Expr::Number(x), Expr::Number(y)) = (&args[0], &args[1]) {
        out.push_str(&format!("    ; Get tile at ({}, {})\n", x, y));
        out.push_str(&format!("    LDA #{}                 ; Y coordinate\n", y));
        out.push_str("    LDB LEVEL_WIDTH        ; Multiply by width\n");
        out.push_str("    MUL                    ; D = y * width\n");
        out.push_str(&format!("    ADDD #{}               ; Add X coordinate\n", x));
        out.push_str("    ADDD #2                ; Skip width/height header\n");
        out.push_str("    ADDD LEVEL_PTR         ; Add base pointer\n");
        out.push_str("    TFR D,X                ; X = tile address\n");
        out.push_str("    CLR RESULT             ; Clear high byte\n");
        out.push_str("    LDA ,X                 ; Load tile value\n");
        out.push_str("    STA RESULT+1           ; Store in low byte\n");
    } else {
        out.push_str("    ; ERROR: GET_LEVEL_TILE currently requires constant arguments\n");
        out.push_str("    LDD #0\n");
        out.push_str("    STD RESULT\n");
    }
}

/// Emit runtime helpers for level system.
/// Only emits helpers that are actually used in the code (tree shaking).
pub fn emit_runtime_helpers(out: &mut String, needed: &HashSet<String>) {

    // =========================================================================
    // LOAD_LEVEL_RUNTIME
    // =========================================================================
    if needed.contains("LOAD_LEVEL_RUNTIME") {
        out.push_str("; === LOAD_LEVEL_RUNTIME ===\n");
        out.push_str("; Load level data from ROM and copy GP objects to RAM buffer\n");
        out.push_str("; Input:  X = pointer to level data in ROM\n");
        out.push_str("; Output: LEVEL_PTR = level header pointer\n");
        out.push_str(";         RESULT    = level header pointer (return value)\n");
        out.push_str("; BG and FG layers are static — read from ROM directly.\n");
        out.push_str("; GP layer is copied to LEVEL_GP_BUFFER (14 bytes/object).\n");
        out.push_str("LOAD_LEVEL_RUNTIME:\n");
        out.push_str("    PSHS D,X,Y,U     ; Preserve registers\n");
        out.push_str("    \n");
        out.push_str("    ; Store level pointer persistently\n");
        out.push_str("    STX >LEVEL_PTR\n");
        out.push_str("    \n");
        out.push_str("    ; Skip world bounds (8 bytes) + time/score (4 bytes)\n");
        out.push_str("    LEAX 12,X        ; X now points to object counts (+12)\n");
        out.push_str("    \n");
        out.push_str("    ; Read object counts (one byte each)\n");
        out.push_str("    LDB ,X+          ; B = bgCount\n");
        out.push_str("    STB >LEVEL_BG_COUNT\n");
        out.push_str("    LDB ,X+          ; B = gpCount\n");
        out.push_str("    STB >LEVEL_GP_COUNT\n");
        out.push_str("    LDB ,X+          ; B = fgCount\n");
        out.push_str("    STB >LEVEL_FG_COUNT\n");
        out.push_str("    \n");
        out.push_str("    ; Read layer ROM pointers (FDB, 2 bytes each)\n");
        out.push_str("    LDD ,X++         ; D = bgObjectsPtr\n");
        out.push_str("    STD >LEVEL_BG_ROM_PTR\n");
        out.push_str("    LDD ,X++         ; D = gpObjectsPtr\n");
        out.push_str("    STD >LEVEL_GP_ROM_PTR\n");
        out.push_str("    LDD ,X++         ; D = fgObjectsPtr\n");
        out.push_str("    STD >LEVEL_FG_ROM_PTR\n");
        out.push_str("    \n");
        out.push_str("    ; === Copy GP objects from ROM to RAM buffer ===\n");
        out.push_str("    LDB >LEVEL_GP_COUNT\n");
        out.push_str("    BEQ LLR_SKIP_GP  ; Skip if no GP objects\n");
        out.push_str("    \n");
        out.push_str("    ; Clear GP buffer with $FF marker (empty sentinel)\n");
        out.push_str("    LDA #$FF\n");
        out.push_str("    LDU #LEVEL_GP_BUFFER\n");
        out.push_str("    LDB #8           ; Max 8 objects\n");
        out.push_str("LLR_CLR_GP_LOOP:\n");
        out.push_str("    STA ,U           ; Write $FF to first byte of object slot\n");
        out.push_str("    LEAU 14,U        ; Advance by 14 bytes (RAM object stride)\n");
        out.push_str("    DECB\n");
        out.push_str("    BNE LLR_CLR_GP_LOOP\n");
        out.push_str("    \n");
        out.push_str("    ; Copy GP objects: ROM (20 bytes each) → RAM buffer (14 bytes each)\n");
        out.push_str("    LDB >LEVEL_GP_COUNT   ; Reload count after clear loop\n");
        out.push_str("    LDX >LEVEL_GP_ROM_PTR ; X = source (ROM)\n");
        out.push_str("    LDU #LEVEL_GP_BUFFER  ; U = destination (RAM)\n");
        out.push_str("    PSHS U               ; Save buffer start\n");
        out.push_str("    JSR LLR_COPY_OBJECTS  ; Copy B objects from X(ROM) to U(RAM)\n");
        out.push_str("    PULS D               ; Restore buffer start into D\n");
        out.push_str("    STD >LEVEL_GP_PTR    ; LEVEL_GP_PTR → RAM buffer\n");
        out.push_str("    BRA LLR_GP_DONE\n");
        out.push_str("    \n");
        out.push_str("LLR_GP_DONE:\n");
        out.push_str("LLR_SKIP_GP:\n");
        out.push_str("    \n");
        out.push_str("    ; Return level pointer in RESULT\n");
        out.push_str("    LDX >LEVEL_PTR\n");
        out.push_str("    STX RESULT\n");
        out.push_str("    \n");
        out.push_str("    PULS D,X,Y,U,PC  ; Restore and return\n");
        out.push_str("    \n");
        // ---- LLR_COPY_OBJECTS subroutine ----
        out.push_str("; === LLR_COPY_OBJECTS - Copy N ROM objects to RAM buffer ===\n");
        out.push_str("; Input:  B = count, X = source (ROM, 20 bytes/obj), U = dest (RAM, 14 bytes/obj)\n");
        out.push_str("; ROM object layout (20 bytes):\n");
        out.push_str(";   +0: type, +1-2: x(FDB), +3-4: y(FDB), +5-6: scale(FDB),\n");
        out.push_str(";   +7: rotation, +8: intensity, +9: velocity_x, +10: velocity_y,\n");
        out.push_str(";   +11: physics_flags, +12: collision_flags, +13: collision_size,\n");
        out.push_str(";   +14-15: spawn_delay(FDB), +16-17: vector_ptr(FDB), +18-19: properties_ptr(FDB)\n");
        out.push_str("; RAM object layout (14 bytes):\n");
        out.push_str(";   +0: x(low), +1: y(low), +2: scale(low), +3: rotation,\n");
        out.push_str(";   +4: velocity_x, +5: velocity_y, +6: physics_flags, +7: collision_flags,\n");
        out.push_str(";   +8: collision_size, +9: spawn_delay(low), +10-11: vector_ptr, +12-13: properties_ptr\n");
        out.push_str("; Clobbers: A, B, X, U\n");
        out.push_str("LLR_COPY_OBJECTS:\n");
        out.push_str("LLR_COPY_LOOP:\n");
        out.push_str("    TSTB\n");
        out.push_str("    BEQ LLR_COPY_DONE\n");
        out.push_str("    PSHS B           ; Save counter (LDD will clobber B)\n");
        out.push_str("    \n");
        out.push_str("    ; X points to ROM object start (+0 = type)\n");
        out.push_str("    LEAX 1,X         ; Skip type (+0), X now at +1 (x FDB high)\n");
        out.push_str("    \n");
        out.push_str("    ; RAM +0: x low byte (ROM +2, low byte of x FDB)\n");
        out.push_str("    LDA 1,X          ; ROM +2 = low byte of x FDB\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    ; RAM +1: y low byte (ROM +4, low byte of y FDB)\n");
        out.push_str("    LDA 3,X          ; ROM +4 = low byte of y FDB\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    ; RAM +2: scale low byte (ROM +6, low byte of scale FDB)\n");
        out.push_str("    LDA 5,X          ; ROM +6 = low byte of scale FDB\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    ; RAM +3: rotation (ROM +7)\n");
        out.push_str("    LDA 6,X          ; ROM +7 = rotation\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    ; Skip to ROM +9 (past intensity at ROM +8)\n");
        out.push_str("    LEAX 8,X         ; X now points to ROM +9 (velocity_x)\n");
        out.push_str("    ; RAM +4: velocity_x (ROM +9)\n");
        out.push_str("    LDA ,X+          ; ROM +9\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    ; RAM +5: velocity_y (ROM +10)\n");
        out.push_str("    LDA ,X+          ; ROM +10\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    ; RAM +6: physics_flags (ROM +11)\n");
        out.push_str("    LDA ,X+          ; ROM +11\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    ; RAM +7: collision_flags (ROM +12)\n");
        out.push_str("    LDA ,X+          ; ROM +12\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    ; RAM +8: collision_size (ROM +13)\n");
        out.push_str("    LDA ,X+          ; ROM +13\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    ; RAM +9: spawn_delay low byte (ROM +15, skip high at ROM +14)\n");
        out.push_str("    LDA 1,X          ; ROM +15 = low byte of spawn_delay FDB\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    LEAX 2,X         ; Skip spawn_delay FDB (2 bytes), X now at ROM +16\n");
        out.push_str("    ; RAM +10-11: vector_ptr FDB (ROM +16-17)\n");
        out.push_str("    LDD ,X++         ; ROM +16-17\n");
        out.push_str("    STD ,U++\n");
        out.push_str("    ; RAM +12-13: properties_ptr FDB (ROM +18-19)\n");
        out.push_str("    LDD ,X++         ; ROM +18-19\n");
        out.push_str("    STD ,U++\n");
        out.push_str("    ; X is now past end of this ROM object (ROM +1 + 8 + 5 + 2 + 2 + 2 = +20 total)\n");
        out.push_str("    ; NOTE: We started at ROM+1 (after LEAX 1,X), walked:\n");
        out.push_str("    ;   1,X and 3,X and 5,X and 6,X via indexed → X unchanged\n");
        out.push_str("    ;   then LEAX 8,X (X now at ROM+9)\n");
        out.push_str("    ;   then 5 post-increment ,X+ → X at ROM+14\n");
        out.push_str("    ;   then LEAX 2,X (X at ROM+16)\n");
        out.push_str("    ;   then 2x LDD ,X++ → X at ROM+20\n");
        out.push_str("    ;   ROM+20 from original ROM+0 = next object start\n");
        out.push_str("    \n");
        out.push_str("    PULS B           ; Restore counter\n");
        out.push_str("    DECB\n");
        out.push_str("    BRA LLR_COPY_LOOP\n");
        out.push_str("LLR_COPY_DONE:\n");
        out.push_str("    RTS\n");
        out.push_str("\n");
    }

    // =========================================================================
    // SHOW_LEVEL_RUNTIME
    // =========================================================================
    if needed.contains("SHOW_LEVEL_RUNTIME") {
        out.push_str("; === SHOW_LEVEL_RUNTIME ===\n");
        out.push_str("; Draw all level objects from all layers\n");
        out.push_str("; Input:  LEVEL_PTR = pointer to level header\n");
        out.push_str("; Layers: BG (ROM stride 20), GP (RAM stride 14), FG (ROM stride 20)\n");
        out.push_str("; Each object: load intensity, x, y, vector_ptr, call SLR_DRAW_OBJECTS\n");
        out.push_str("SHOW_LEVEL_RUNTIME:\n");
        out.push_str("    PSHS D,X,Y,U     ; Preserve registers\n");
        out.push_str("    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)\n");
        out.push_str("    \n");
        out.push_str("    ; Check if level is loaded\n");
        out.push_str("    LDX >LEVEL_PTR\n");
        out.push_str("    CMPX #0\n");
        out.push_str("    BEQ SLR_DONE     ; No level loaded, skip\n");
        out.push_str("    \n");
        out.push_str("    ; Re-read object counts from header\n");
        out.push_str("    LEAX 12,X        ; X points to counts (+12)\n");
        out.push_str("    LDB ,X+          ; B = bgCount\n");
        out.push_str("    STB >LEVEL_BG_COUNT\n");
        out.push_str("    LDB ,X+          ; B = gpCount\n");
        out.push_str("    STB >LEVEL_GP_COUNT\n");
        out.push_str("    LDB ,X+          ; B = fgCount\n");
        out.push_str("    STB >LEVEL_FG_COUNT\n");
        out.push_str("    \n");
        out.push_str("    ; === Draw Background Layer (ROM, stride=20) ===\n");
        out.push_str("SLR_BG_COUNT:\n");
        out.push_str("    CLRB\n");
        out.push_str("    LDB >LEVEL_BG_COUNT\n");
        out.push_str("    CMPB #0\n");
        out.push_str("    BEQ SLR_GAMEPLAY\n");
        out.push_str("    LDA #20          ; ROM object stride\n");
        out.push_str("    LDX >LEVEL_BG_ROM_PTR\n");
        out.push_str("    JSR SLR_DRAW_OBJECTS\n");
        out.push_str("    \n");
        out.push_str("    ; === Draw Gameplay Layer (RAM, stride=14) ===\n");
        out.push_str("SLR_GAMEPLAY:\n");
        out.push_str("SLR_GP_COUNT:\n");
        out.push_str("    CLRB\n");
        out.push_str("    LDB >LEVEL_GP_COUNT\n");
        out.push_str("    CMPB #0\n");
        out.push_str("    BEQ SLR_FOREGROUND\n");
        out.push_str("    LDA #14          ; RAM object stride (14 bytes)\n");
        out.push_str("    LDX >LEVEL_GP_PTR\n");
        out.push_str("    JSR SLR_DRAW_OBJECTS\n");
        out.push_str("    \n");
        out.push_str("    ; === Draw Foreground Layer (ROM, stride=20) ===\n");
        out.push_str("SLR_FOREGROUND:\n");
        out.push_str("SLR_FG_COUNT:\n");
        out.push_str("    CLRB\n");
        out.push_str("    LDB >LEVEL_FG_COUNT\n");
        out.push_str("    CMPB #0\n");
        out.push_str("    BEQ SLR_DONE\n");
        out.push_str("    LDA #20          ; ROM object stride\n");
        out.push_str("    LDX >LEVEL_FG_ROM_PTR\n");
        out.push_str("    JSR SLR_DRAW_OBJECTS\n");
        out.push_str("    \n");
        out.push_str("SLR_DONE:\n");
        out.push_str("    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)\n");
        out.push_str("    PULS D,X,Y,U,PC  ; Restore and return\n");
        out.push_str("    \n");
        // ---- SLR_DRAW_OBJECTS subroutine ----
        out.push_str("; === SLR_DRAW_OBJECTS - Draw N objects from a layer ===\n");
        out.push_str("; Input:  A = stride (14=RAM, 20=ROM), B = count, X = objects ptr\n");
        out.push_str("; For ROM objects (stride=20): intensity at +8, y FDB at +3, x FDB at +1, vector_ptr FDB at +16\n");
        out.push_str("; For RAM objects (stride=14): look up intensity from ROM via LEVEL_GP_ROM_PTR,\n");
        out.push_str(";   y at +1, x at +0, vector_ptr FDB at +10\n");
        out.push_str("SLR_DRAW_OBJECTS:\n");
        out.push_str("    PSHS A           ; Save stride on stack (A=stride)\n");
        out.push_str("SLR_OBJ_LOOP:\n");
        out.push_str("    TSTB\n");
        out.push_str("    LBEQ SLR_OBJ_DONE\n");
        out.push_str("    \n");
        out.push_str("    PSHS B           ; Save counter (LDD clobbers B)\n");
        out.push_str("    \n");
        out.push_str("    ; Determine ROM vs RAM offsets via stride\n");
        out.push_str("    LDA 1,S          ; Peek stride from stack (+1 because B is on top)\n");
        out.push_str("    CMPA #20\n");
        out.push_str("    BEQ SLR_ROM_OFFSETS\n");
        out.push_str("    \n");
        out.push_str("    ; === RAM object (stride=14) ===\n");
        out.push_str("    ; Need to look up intensity from ROM counterpart\n");
        out.push_str("    ; objIndex = LEVEL_GP_COUNT - currentCount\n");
        out.push_str("    PSHS X           ; Save RAM object pointer\n");
        out.push_str("    LDB >LEVEL_GP_COUNT\n");
        out.push_str("    SUBB 2,S         ; B = objIndex = totalCount - currentCounter\n");
        out.push_str("    LDX >LEVEL_GP_ROM_PTR  ; X = ROM base\n");
        out.push_str("SLR_ROM_ADDR_LOOP:\n");
        out.push_str("    BEQ SLR_INTENSITY_READ ; Done if index=0\n");
        out.push_str("    LEAX 20,X        ; Advance by ROM stride\n");
        out.push_str("    DECB\n");
        out.push_str("    BRA SLR_ROM_ADDR_LOOP\n");
        out.push_str("SLR_INTENSITY_READ:\n");
        out.push_str("    LDA 8,X          ; intensity at ROM +8\n");
        out.push_str("    STA DRAW_VEC_INTENSITY\n");
        out.push_str("    PULS X           ; Restore RAM object pointer\n");
        out.push_str("    \n");
        out.push_str("    CLR MIRROR_X\n");
        out.push_str("    CLR MIRROR_Y\n");
        out.push_str("    LDB 1,X          ; y at RAM +1\n");
        out.push_str("    STB DRAW_VEC_Y\n");
        out.push_str("    LDB 0,X          ; x at RAM +0\n");
        out.push_str("    STB DRAW_VEC_X\n");
        out.push_str("    LDU 10,X         ; vector_ptr at RAM +10\n");
        out.push_str("    BRA SLR_DRAW_VECTOR\n");
        out.push_str("    \n");
        out.push_str("SLR_ROM_OFFSETS:\n");
        out.push_str("    ; === ROM object (stride=20) ===\n");
        out.push_str("    CLR MIRROR_X\n");
        out.push_str("    CLR MIRROR_Y\n");
        out.push_str("    LDA 8,X          ; intensity at ROM +8\n");
        out.push_str("    STA DRAW_VEC_INTENSITY\n");
        out.push_str("    LDD 3,X          ; y FDB at ROM +3; low byte into B\n");
        out.push_str("    STB DRAW_VEC_Y\n");
        out.push_str("    LDD 1,X          ; x FDB at ROM +1; low byte into B\n");
        out.push_str("    STB DRAW_VEC_X\n");
        out.push_str("    LDU 16,X         ; vector_ptr FDB at ROM +16\n");
        out.push_str("    \n");
        out.push_str("SLR_DRAW_VECTOR:\n");
        out.push_str("    PSHS X           ; Save object pointer\n");
        out.push_str("    TFR U,X          ; X = vector data pointer (header)\n");
        out.push_str("    \n");
        out.push_str("    ; Read path_count from vector header byte 0\n");
        out.push_str("    LDB ,X+          ; B = path_count, X now at pointer table\n");
        out.push_str("    \n");
        out.push_str("    ; DP is already $D0 (set by SHOW_LEVEL_RUNTIME at entry)\n");
        out.push_str("SLR_PATH_LOOP:\n");
        out.push_str("    TSTB\n");
        out.push_str("    BEQ SLR_PATH_DONE\n");
        out.push_str("    DECB\n");
        out.push_str("    PSHS B           ; Save decremented count\n");
        out.push_str("    LDU ,X++         ; U = path pointer, X advances to next entry\n");
        out.push_str("    PSHS X           ; Save pointer table position\n");
        out.push_str("    TFR U,X          ; X = actual path data\n");
        out.push_str("    JSR Draw_Sync_List_At_With_Mirrors\n");
        out.push_str("    PULS X           ; Restore pointer table position\n");
        out.push_str("    PULS B           ; Restore count\n");
        out.push_str("    BRA SLR_PATH_LOOP\n");
        out.push_str("    \n");
        out.push_str("SLR_PATH_DONE:\n");
        out.push_str("    PULS X           ; Restore object pointer\n");
        out.push_str("    \n");
        out.push_str("    ; Advance to next object using stride\n");
        out.push_str("    LDA 1,S          ; Load stride from stack (+1 because B is on top)\n");
        out.push_str("    LEAX A,X         ; X += stride\n");
        out.push_str("    \n");
        out.push_str("    PULS B           ; Restore counter\n");
        out.push_str("    DECB\n");
        out.push_str("    LBRA SLR_OBJ_LOOP\n");
        out.push_str("    \n");
        out.push_str("SLR_OBJ_DONE:\n");
        out.push_str("    PULS A           ; Clean up stride from stack\n");
        out.push_str("    RTS\n");
        out.push_str("\n");
    }

    // =========================================================================
    // UPDATE_LEVEL_RUNTIME
    // =========================================================================
    if needed.contains("UPDATE_LEVEL_RUNTIME") {
        out.push_str("; === UPDATE_LEVEL_RUNTIME ===\n");
        out.push_str("; Update level physics: apply velocity, gravity, bounce walls\n");
        out.push_str("; GP-GP elastic collisions and GP-FG static collisions\n");
        out.push_str("; Only the GP layer (RAM buffer) is updated — BG/FG are static ROM.\n");
        out.push_str("UPDATE_LEVEL_RUNTIME:\n");
        out.push_str("    PSHS U,X,Y,D     ; Preserve all registers\n");
        out.push_str("    \n");
        out.push_str("    ; === Update Gameplay Objects ===\n");
        out.push_str("    LDB >LEVEL_GP_COUNT\n");
        out.push_str("    CMPB #0\n");
        out.push_str("    LBEQ ULR_EXIT    ; No objects\n");
        out.push_str("    LDU >LEVEL_GP_PTR  ; U = GP buffer (RAM)\n");
        out.push_str("    BSR ULR_UPDATE_LAYER\n");
        out.push_str("    \n");
        out.push_str("    ; === GP-to-GP Elastic Collisions ===\n");
        out.push_str("    JSR ULR_GAMEPLAY_COLLISIONS\n");
        out.push_str("    ; === GP vs FG Static Collisions ===\n");
        out.push_str("    JSR ULR_GP_FG_COLLISIONS\n");
        out.push_str("    \n");
        out.push_str("ULR_EXIT:\n");
        out.push_str("    PULS D,Y,X,U     ; Restore registers\n");
        out.push_str("    RTS\n");
        out.push_str("\n");

        // ---- ULR_UPDATE_LAYER ----
        out.push_str("; === ULR_UPDATE_LAYER - Apply physics to each object in GP buffer ===\n");
        out.push_str("; Input: B = object count, U = buffer base (14 bytes/object)\n");
        out.push_str("; RAM object layout:\n");
        out.push_str(";   +0: x(signed 8-bit)  +1: y(signed 8-bit)  +2: scale  +3: rotation\n");
        out.push_str(";   +4: velocity_x  +5: velocity_y  +6: physics_flags  +7: collision_flags\n");
        out.push_str(";   +8: collision_size  +9: spawn_delay_lo  +10-11: vector_ptr  +12-13: props_ptr\n");
        out.push_str("ULR_UPDATE_LAYER:\n");
        out.push_str("    LDX >LEVEL_PTR   ; Load level pointer for world bounds\n");
        out.push_str("    CMPX #0\n");
        out.push_str("    LBEQ ULR_LAYER_EXIT\n");
        out.push_str("    \n");
        out.push_str("ULR_LOOP:\n");
        out.push_str("    PSHS B           ; Save loop counter\n");
        out.push_str("    \n");
        out.push_str("    ; Check physics_flags (RAM +6)\n");
        out.push_str("    LDB 6,U\n");
        out.push_str("    CMPB #0\n");
        out.push_str("    LBEQ ULR_NEXT    ; No physics at all, skip\n");
        out.push_str("    \n");
        out.push_str("    ; Check dynamic bit (bit 0)\n");
        out.push_str("    BITB #$01\n");
        out.push_str("    LBEQ ULR_NEXT    ; Not dynamic, skip\n");
        out.push_str("    \n");
        out.push_str("    ; Check gravity bit (bit 1)\n");
        out.push_str("    BITB #$02\n");
        out.push_str("    LBEQ ULR_NO_GRAVITY\n");
        out.push_str("    \n");
        out.push_str("    ; Apply gravity: velocity_y -= 1, clamp to -15\n");
        out.push_str("    LDB 5,U          ; velocity_y (RAM +5)\n");
        out.push_str("    DECB\n");
        out.push_str("    CMPB #$F1        ; -15\n");
        out.push_str("    BGE ULR_VY_OK\n");
        out.push_str("    LDB #$F1\n");
        out.push_str("ULR_VY_OK:\n");
        out.push_str("    STB 5,U\n");
        out.push_str("    \n");
        out.push_str("ULR_NO_GRAVITY:\n");
        out.push_str("    ; Apply velocity: x += velocity_x (16-bit to avoid wraparound)\n");
        out.push_str("    LDB 0,U          ; x (8-bit signed)\n");
        out.push_str("    SEX              ; D = sign-extended x\n");
        out.push_str("    TFR D,Y          ; Y = x (16-bit)\n");
        out.push_str("    LDB 4,U          ; velocity_x (8-bit signed)\n");
        out.push_str("    SEX              ; D = sign-extended velocity_x\n");
        out.push_str("    LEAY D,Y         ; Y = x + velocity_x (16-bit addition)\n");
        out.push_str("    TFR Y,D          ; D = 16-bit result\n");
        out.push_str("    CMPD #127        ; Clamp to i8 max\n");
        out.push_str("    BLE ULR_X_NOT_MAX\n");
        out.push_str("    LDD #127\n");
        out.push_str("ULR_X_NOT_MAX:\n");
        out.push_str("    CMPD #-128       ; Clamp to i8 min\n");
        out.push_str("    BGE ULR_X_NOT_MIN\n");
        out.push_str("    LDD #-128\n");
        out.push_str("ULR_X_NOT_MIN:\n");
        out.push_str("    STB 0,U          ; Store clamped x\n");
        out.push_str("    \n");
        out.push_str("    ; Apply velocity: y += velocity_y (16-bit to avoid wraparound)\n");
        out.push_str("    LDB 1,U          ; y (8-bit signed)\n");
        out.push_str("    SEX              ; D = sign-extended y\n");
        out.push_str("    TFR D,Y          ; Y = y (16-bit)\n");
        out.push_str("    LDB 5,U          ; velocity_y (8-bit signed)\n");
        out.push_str("    SEX              ; D = sign-extended velocity_y\n");
        out.push_str("    LEAY D,Y         ; Y = y + velocity_y (16-bit addition)\n");
        out.push_str("    TFR Y,D          ; D = 16-bit result\n");
        out.push_str("    CMPD #127        ; Clamp to i8 max\n");
        out.push_str("    BLE ULR_Y_NOT_MAX\n");
        out.push_str("    LDD #127\n");
        out.push_str("ULR_Y_NOT_MAX:\n");
        out.push_str("    CMPD #-128       ; Clamp to i8 min\n");
        out.push_str("    BGE ULR_Y_NOT_MIN\n");
        out.push_str("    LDD #-128\n");
        out.push_str("ULR_Y_NOT_MIN:\n");
        out.push_str("    STB 1,U          ; Store clamped y\n");
        out.push_str("    \n");
        out.push_str("    ; === World Bounds / Wall Bounce ===\n");
        out.push_str("    LDB 7,U          ; collision_flags (RAM +7)\n");
        out.push_str("    BITB #$02        ; bounce_walls flag (bit 1)\n");
        out.push_str("    LBEQ ULR_NEXT    ; Skip if not bouncing\n");
        out.push_str("    \n");
        out.push_str("    ; LDX already loaded = LEVEL_PTR\n");
        out.push_str("    ; World bounds at LEVEL_PTR: +0=xMin(FDB), +2=xMax(FDB), +4=yMin(FDB), +6=yMax(FDB)\n");
        out.push_str("    \n");
        out.push_str("    ; --- Check X left wall (xMin) ---\n");
        out.push_str("    LDB 8,U          ; collision_size (RAM +8)\n");
        out.push_str("    SEX              ; D = sign-extended collision_size\n");
        out.push_str("    PSHS D           ; Save collision_size\n");
        out.push_str("    LDB 0,U          ; x (8-bit)\n");
        out.push_str("    SEX              ; sign-extend x to 16-bit\n");
        out.push_str("    SUBD ,S++        ; D = x - collision_size (left edge), pop\n");
        out.push_str("    CMPD 0,X         ; Compare with xMin\n");
        out.push_str("    LBGE ULR_X_MAX_CHECK\n");
        out.push_str("    ; Hit left wall — bounce only if moving left (velocity_x < 0)\n");
        out.push_str("    LDB 4,U\n");
        out.push_str("    CMPB #0\n");
        out.push_str("    LBGE ULR_X_MAX_CHECK\n");
        out.push_str("    LDB 8,U          ; collision_size\n");
        out.push_str("    SEX\n");
        out.push_str("    ADDD 0,X         ; D = xMin + collision_size\n");
        out.push_str("    STB 0,U          ; x = low byte\n");
        out.push_str("    LDB 4,U\n");
        out.push_str("    NEGB\n");
        out.push_str("    STB 4,U          ; velocity_x = -velocity_x\n");
        out.push_str("    \n");
        out.push_str("    ; --- Check X right wall (xMax) ---\n");
        out.push_str("ULR_X_MAX_CHECK:\n");
        out.push_str("    LDB 8,U\n");
        out.push_str("    SEX\n");
        out.push_str("    PSHS D\n");
        out.push_str("    LDB 0,U\n");
        out.push_str("    SEX\n");
        out.push_str("    ADDD ,S++        ; D = x + collision_size (right edge), pop\n");
        out.push_str("    CMPD 2,X         ; Compare with xMax\n");
        out.push_str("    LBLE ULR_Y_BOUNDS\n");
        out.push_str("    ; Hit right wall — bounce only if moving right (velocity_x > 0)\n");
        out.push_str("    LDB 4,U\n");
        out.push_str("    CMPB #0\n");
        out.push_str("    LBLE ULR_Y_BOUNDS\n");
        out.push_str("    LDB 8,U\n");
        out.push_str("    SEX\n");
        out.push_str("    TFR D,Y\n");
        out.push_str("    LDD 2,X          ; D = xMax\n");
        out.push_str("    PSHS Y\n");
        out.push_str("    SUBD ,S++        ; D = xMax - collision_size, pop\n");
        out.push_str("    STB 0,U\n");
        out.push_str("    LDB 4,U\n");
        out.push_str("    NEGB\n");
        out.push_str("    STB 4,U\n");
        out.push_str("    \n");
        out.push_str("    ; --- Check Y bottom wall (yMin) ---\n");
        out.push_str("ULR_Y_BOUNDS:\n");
        out.push_str("    LDB 8,U\n");
        out.push_str("    SEX\n");
        out.push_str("    PSHS D\n");
        out.push_str("    LDB 1,U\n");
        out.push_str("    SEX\n");
        out.push_str("    SUBD ,S++        ; D = y - collision_size, pop\n");
        out.push_str("    CMPD 4,X         ; Compare with yMin\n");
        out.push_str("    LBGE ULR_Y_MAX_CHECK\n");
        out.push_str("    LDB 5,U\n");
        out.push_str("    CMPB #0\n");
        out.push_str("    LBGE ULR_Y_MAX_CHECK\n");
        out.push_str("    LDB 8,U\n");
        out.push_str("    SEX\n");
        out.push_str("    ADDD 4,X         ; D = yMin + collision_size\n");
        out.push_str("    STB 1,U\n");
        out.push_str("    LDB 5,U\n");
        out.push_str("    NEGB\n");
        out.push_str("    STB 5,U\n");
        out.push_str("    \n");
        out.push_str("    ; --- Check Y top wall (yMax) ---\n");
        out.push_str("ULR_Y_MAX_CHECK:\n");
        out.push_str("    LDB 8,U\n");
        out.push_str("    SEX\n");
        out.push_str("    PSHS D\n");
        out.push_str("    LDB 1,U\n");
        out.push_str("    SEX\n");
        out.push_str("    ADDD ,S++        ; D = y + collision_size, pop\n");
        out.push_str("    CMPD 6,X         ; Compare with yMax\n");
        out.push_str("    LBLE ULR_NEXT\n");
        out.push_str("    LDB 5,U\n");
        out.push_str("    CMPB #0\n");
        out.push_str("    LBLE ULR_NEXT\n");
        out.push_str("    LDB 8,U\n");
        out.push_str("    SEX\n");
        out.push_str("    TFR D,Y\n");
        out.push_str("    LDD 6,X          ; D = yMax\n");
        out.push_str("    PSHS Y\n");
        out.push_str("    SUBD ,S++        ; D = yMax - collision_size, pop\n");
        out.push_str("    STB 1,U\n");
        out.push_str("    LDB 5,U\n");
        out.push_str("    NEGB\n");
        out.push_str("    STB 5,U\n");
        out.push_str("    \n");
        out.push_str("ULR_NEXT:\n");
        out.push_str("    PULS B           ; Restore loop counter\n");
        out.push_str("    LEAU 14,U        ; Next object (14 bytes)\n");
        out.push_str("    DECB\n");
        out.push_str("    LBNE ULR_LOOP\n");
        out.push_str("    \n");
        out.push_str("ULR_LAYER_EXIT:\n");
        out.push_str("    RTS\n");
        out.push_str("\n");

        // ---- ULR_GAMEPLAY_COLLISIONS ----
        out.push_str("; === ULR_GAMEPLAY_COLLISIONS - GP-to-GP elastic collisions ===\n");
        out.push_str("; Checks all pairs of GP objects; swaps velocities on collision.\n");
        out.push_str("; Uses Manhattan distance for speed. RAM indices via UGPC_ vars.\n");
        out.push_str("ULR_GAMEPLAY_COLLISIONS:\n");
        out.push_str("    LDA >LEVEL_GP_COUNT\n");
        out.push_str("    CMPA #2\n");
        out.push_str("    BHS UGPC_START\n");
        out.push_str("    RTS              ; Need at least 2 objects\n");
        out.push_str("UGPC_START:\n");
        out.push_str("    DECA\n");
        out.push_str("    STA UGPC_OUTER_MAX\n");
        out.push_str("    CLR UGPC_OUTER_IDX\n");
        out.push_str("    \n");
        out.push_str("UGPC_OUTER_LOOP:\n");
        out.push_str("    ; U = LEVEL_GP_BUFFER + (UGPC_OUTER_IDX * 14)\n");
        out.push_str("    LDU #LEVEL_GP_BUFFER\n");
        out.push_str("    LDB UGPC_OUTER_IDX\n");
        out.push_str("    BEQ UGPC_SKIP_OUTER_MUL\n");
        out.push_str("UGPC_OUTER_MUL:\n");
        out.push_str("    LEAU 14,U\n");
        out.push_str("    DECB\n");
        out.push_str("    BNE UGPC_OUTER_MUL\n");
        out.push_str("UGPC_SKIP_OUTER_MUL:\n");
        out.push_str("    ; Check if outer object is collidable (collision_flags bit 0 at RAM +7)\n");
        out.push_str("    LDB 7,U\n");
        out.push_str("    BITB #$01\n");
        out.push_str("    LBEQ UGPC_NEXT_OUTER\n");
        out.push_str("    \n");
        out.push_str("    LDA UGPC_OUTER_IDX\n");
        out.push_str("    INCA\n");
        out.push_str("    STA UGPC_INNER_IDX\n");
        out.push_str("    \n");
        out.push_str("UGPC_INNER_LOOP:\n");
        out.push_str("    LDA UGPC_INNER_IDX\n");
        out.push_str("    CMPA >LEVEL_GP_COUNT\n");
        out.push_str("    LBHS UGPC_INNER_DONE\n");
        out.push_str("    \n");
        out.push_str("    ; Y = LEVEL_GP_BUFFER + (UGPC_INNER_IDX * 14)\n");
        out.push_str("    LDY #LEVEL_GP_BUFFER\n");
        out.push_str("    LDB UGPC_INNER_IDX\n");
        out.push_str("    BEQ UGPC_SKIP_INNER_MUL\n");
        out.push_str("UGPC_INNER_MUL:\n");
        out.push_str("    LEAY 14,Y\n");
        out.push_str("    DECB\n");
        out.push_str("    BNE UGPC_INNER_MUL\n");
        out.push_str("UGPC_SKIP_INNER_MUL:\n");
        out.push_str("    ; Check inner collidable (RAM +7)\n");
        out.push_str("    LDB 7,Y\n");
        out.push_str("    BITB #$01\n");
        out.push_str("    LBEQ UGPC_NEXT_INNER\n");
        out.push_str("    \n");
        out.push_str("    ; Manhattan distance: |x1-x2| + |y1-y2|\n");
        out.push_str("    ; Compute |dx| = |x1 - x2|\n");
        out.push_str("    LDB 0,U          ; x1 (8-bit at RAM +0)\n");
        out.push_str("    SEX\n");
        out.push_str("    PSHS D           ; Save x1 (16-bit)\n");
        out.push_str("    LDB 0,Y          ; x2 (8-bit at RAM +0)\n");
        out.push_str("    SEX\n");
        out.push_str("    TFR D,X\n");
        out.push_str("    PULS D           ; D = x1\n");
        out.push_str("    PSHS X\n");
        out.push_str("    TFR X,D          ; D = x2\n");
        out.push_str("    PULS X\n");
        out.push_str("    PSHS D           ; Push x2\n");
        out.push_str("    LDB 0,U\n");
        out.push_str("    SEX\n");
        out.push_str("    SUBD ,S++        ; x1 - x2, pop\n");
        out.push_str("    BPL UGPC_DX_POS\n");
        out.push_str("    COMA\n");
        out.push_str("    COMB\n");
        out.push_str("    ADDD #1          ; negate\n");
        out.push_str("UGPC_DX_POS:\n");
        out.push_str("    STD UGPC_DX\n");
        out.push_str("    \n");
        out.push_str("    ; Compute |dy| = |y1 - y2|\n");
        out.push_str("    LDB 1,U          ; y1 (8-bit at RAM +1)\n");
        out.push_str("    SEX\n");
        out.push_str("    PSHS D\n");
        out.push_str("    LDB 1,Y          ; y2\n");
        out.push_str("    SEX\n");
        out.push_str("    TFR D,X\n");
        out.push_str("    PULS D\n");
        out.push_str("    PSHS X\n");
        out.push_str("    TFR X,D\n");
        out.push_str("    PULS X\n");
        out.push_str("    PSHS D           ; Push y2\n");
        out.push_str("    LDB 1,U\n");
        out.push_str("    SEX\n");
        out.push_str("    SUBD ,S++        ; y1 - y2, pop\n");
        out.push_str("    BPL UGPC_DY_POS\n");
        out.push_str("    COMA\n");
        out.push_str("    COMB\n");
        out.push_str("    ADDD #1\n");
        out.push_str("UGPC_DY_POS:\n");
        out.push_str("    ADDD UGPC_DX     ; D = |dx| + |dy|\n");
        out.push_str("    STD UGPC_DIST\n");
        out.push_str("    \n");
        out.push_str("    ; Sum of radii\n");
        out.push_str("    LDB 8,U          ; collision_size obj1 (RAM +8)\n");
        out.push_str("    ADDB 8,Y         ; + collision_size obj2\n");
        out.push_str("    SEX              ; D = sum_radius\n");
        out.push_str("    CMPD UGPC_DIST\n");
        out.push_str("    LBHI UGPC_COLLISION\n");
        out.push_str("    LBRA UGPC_NEXT_INNER\n");
        out.push_str("    \n");
        out.push_str("UGPC_COLLISION:\n");
        out.push_str("    ; Elastic collision: swap velocities\n");
        out.push_str("    LDA 4,U          ; vel_x obj1\n");
        out.push_str("    LDB 4,Y          ; vel_x obj2\n");
        out.push_str("    STB 4,U\n");
        out.push_str("    STA 4,Y\n");
        out.push_str("    LDA 5,U          ; vel_y obj1\n");
        out.push_str("    LDB 5,Y          ; vel_y obj2\n");
        out.push_str("    STB 5,U\n");
        out.push_str("    STA 5,Y\n");
        out.push_str("    \n");
        out.push_str("UGPC_NEXT_INNER:\n");
        out.push_str("    INC UGPC_INNER_IDX\n");
        out.push_str("    LBRA UGPC_INNER_LOOP\n");
        out.push_str("    \n");
        out.push_str("UGPC_INNER_DONE:\n");
        out.push_str("UGPC_NEXT_OUTER:\n");
        out.push_str("    INC UGPC_OUTER_IDX\n");
        out.push_str("    LDA UGPC_OUTER_IDX\n");
        out.push_str("    CMPA UGPC_OUTER_MAX\n");
        out.push_str("    LBHI UGPC_EXIT\n");
        out.push_str("    LBRA UGPC_OUTER_LOOP\n");
        out.push_str("    \n");
        out.push_str("UGPC_EXIT:\n");
        out.push_str("    RTS\n");
        out.push_str("    \n");

        // ---- ULR_GP_FG_COLLISIONS ----
        out.push_str("; === ULR_GP_FG_COLLISIONS - GP objects vs static FG ROM collidables ===\n");
        out.push_str("; For each GP object (RAM, collidable) check against each FG (ROM, collidable).\n");
        out.push_str("; Axis-split bounce: |dy|>|dx| → negate vy; else → negate vx.\n");
        out.push_str("; FG ROM offsets: +0=type, +1-2=x FDB, +3-4=y FDB, +12=collision_flags, +13=collision_size\n");
        out.push_str("ULR_GP_FG_COLLISIONS:\n");
        out.push_str("    LDA >LEVEL_FG_COUNT\n");
        out.push_str("    LBEQ UGFC_EXIT\n");
        out.push_str("    STA UGFC_FG_COUNT\n");
        out.push_str("    LDA >LEVEL_GP_COUNT\n");
        out.push_str("    LBEQ UGFC_EXIT\n");
        out.push_str("    CLR UGFC_GP_IDX\n");
        out.push_str("    \n");
        out.push_str("UGFC_GP_LOOP:\n");
        out.push_str("    ; U = LEVEL_GP_BUFFER + (UGFC_GP_IDX * 14)\n");
        out.push_str("    LDU #LEVEL_GP_BUFFER\n");
        out.push_str("    LDB UGFC_GP_IDX\n");
        out.push_str("    BEQ UGFC_GP_ADDR_DONE\n");
        out.push_str("UGFC_GP_MUL:\n");
        out.push_str("    LEAU 14,U\n");
        out.push_str("    DECB\n");
        out.push_str("    BNE UGFC_GP_MUL\n");
        out.push_str("UGFC_GP_ADDR_DONE:\n");
        out.push_str("    ; Check GP collidable (collision_flags bit 0 at RAM +7)\n");
        out.push_str("    LDB 7,U\n");
        out.push_str("    BITB #$01\n");
        out.push_str("    LBEQ UGFC_NEXT_GP\n");
        out.push_str("    \n");
        out.push_str("    ; Walk FG ROM objects\n");
        out.push_str("    LDX >LEVEL_FG_ROM_PTR\n");
        out.push_str("    LDB UGFC_FG_COUNT\n");
        out.push_str("    \n");
        out.push_str("UGFC_FG_LOOP:\n");
        out.push_str("    CMPB #0\n");
        out.push_str("    LBEQ UGFC_NEXT_GP\n");
        out.push_str("    ; Check FG collidable (ROM +12 = collision_flags)\n");
        out.push_str("    LDA 12,X\n");
        out.push_str("    BITA #$01\n");
        out.push_str("    BEQ UGFC_NEXT_FG\n");
        out.push_str("    \n");
        out.push_str("    ; |dx| = |GP.x - FG.x_lo|  (FG ROM +2 = low byte of x FDB)\n");
        out.push_str("    LDA 0,U          ; GP x (RAM +0)\n");
        out.push_str("    SUBA 2,X         ; A = GP.x - FG.x_lo\n");
        out.push_str("    BPL UGFC_DX_POS\n");
        out.push_str("    NEGA\n");
        out.push_str("UGFC_DX_POS:\n");
        out.push_str("    STA UGFC_DX\n");
        out.push_str("    \n");
        out.push_str("    ; |dy| = |GP.y - FG.y_lo|  (FG ROM +4 = low byte of y FDB)\n");
        out.push_str("    LDA 1,U          ; GP y (RAM +1)\n");
        out.push_str("    SUBA 4,X         ; A = GP.y - FG.y_lo\n");
        out.push_str("    BPL UGFC_DY_POS\n");
        out.push_str("    NEGA\n");
        out.push_str("UGFC_DY_POS:\n");
        out.push_str("    STA UGFC_DY\n");
        out.push_str("    \n");
        out.push_str("    ; sum_r = GP.collision_size + FG.collision_size\n");
        out.push_str("    LDA 8,U          ; GP collision_size (RAM +8)\n");
        out.push_str("    ADDA 13,X        ; + FG collision_size (ROM +13)\n");
        out.push_str("    \n");
        out.push_str("    ; Collision if |dx| + |dy| < sum_r\n");
        out.push_str("    PSHS A           ; Save sum_r\n");
        out.push_str("    LDA UGFC_DX\n");
        out.push_str("    ADDA UGFC_DY\n");
        out.push_str("    CMPA ,S+         ; Compare distance with sum_r (pop)\n");
        out.push_str("    BHS UGFC_NEXT_FG ; No collision\n");
        out.push_str("    \n");
        out.push_str("    ; COLLISION! Axis-split by velocity: |vy|>|vx| → vert bounce, else horiz bounce\n");
        out.push_str("    LDA 5,U          ; velocity_y\n");
        out.push_str("    BPL UGFC_VY_ABS\n");
        out.push_str("    NEGA\n");
        out.push_str("UGFC_VY_ABS:\n");
        out.push_str("    STA UGFC_DY      ; |vy|\n");
        out.push_str("    LDA 4,U          ; velocity_x\n");
        out.push_str("    BPL UGFC_VX_ABS\n");
        out.push_str("    NEGA\n");
        out.push_str("UGFC_VX_ABS:\n");
        out.push_str("    CMPA UGFC_DY     ; |vx| vs |vy|\n");
        out.push_str("    BLT UGFC_VERT_BOUNCE ; |vx| < |vy| → vert bounce\n");
        out.push_str("    \n");
        out.push_str("UGFC_HORIZ_BOUNCE:\n");
        out.push_str("    LDA 4,U          ; velocity_x (RAM +4)\n");
        out.push_str("    NEGA\n");
        out.push_str("    STA 4,U\n");
        out.push_str("    LDA 8,U\n");
        out.push_str("    ADDA 13,X\n");
        out.push_str("    PSHS A           ; Save separation\n");
        out.push_str("    LDA 0,U\n");
        out.push_str("    CMPA 2,X\n");
        out.push_str("    BLT UGFC_PUSH_LEFT\n");
        out.push_str("    LDA 2,X\n");
        out.push_str("    ADDA ,S+\n");
        out.push_str("    STA 0,U\n");
        out.push_str("    BRA UGFC_NEXT_FG\n");
        out.push_str("UGFC_PUSH_LEFT:\n");
        out.push_str("    LDA 2,X\n");
        out.push_str("    SUBA ,S+\n");
        out.push_str("    STA 0,U\n");
        out.push_str("    BRA UGFC_NEXT_FG\n");
        out.push_str("    \n");
        out.push_str("UGFC_VERT_BOUNCE:\n");
        out.push_str("    LDA 5,U          ; velocity_y (RAM +5)\n");
        out.push_str("    NEGA\n");
        out.push_str("    STA 5,U\n");
        out.push_str("    LDA 8,U\n");
        out.push_str("    ADDA 13,X\n");
        out.push_str("    PSHS A\n");
        out.push_str("    LDA 1,U\n");
        out.push_str("    CMPA 4,X\n");
        out.push_str("    BLT UGFC_PUSH_DOWN\n");
        out.push_str("    LDA 4,X\n");
        out.push_str("    ADDA ,S+\n");
        out.push_str("    STA 1,U\n");
        out.push_str("    BRA UGFC_NEXT_FG\n");
        out.push_str("UGFC_PUSH_DOWN:\n");
        out.push_str("    LDA 4,X\n");
        out.push_str("    SUBA ,S+\n");
        out.push_str("    STA 1,U\n");
        out.push_str("    \n");
        out.push_str("UGFC_NEXT_FG:\n");
        out.push_str("    LEAX 20,X        ; Next FG object (ROM stride 20)\n");
        out.push_str("    DECB\n");
        out.push_str("    LBRA UGFC_FG_LOOP\n");
        out.push_str("    \n");
        out.push_str("UGFC_NEXT_GP:\n");
        out.push_str("    INC UGFC_GP_IDX\n");
        out.push_str("    LDA UGFC_GP_IDX\n");
        out.push_str("    CMPA >LEVEL_GP_COUNT\n");
        out.push_str("    LBLO UGFC_GP_LOOP\n");
        out.push_str("    \n");
        out.push_str("UGFC_EXIT:\n");
        out.push_str("    RTS\n");
        out.push_str("\n");
    }
}
