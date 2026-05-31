// Level System Builtins for VPy
// vplay-aware level loading, rendering, and physics

use std::collections::HashSet;
use std::sync::atomic::{AtomicUsize, Ordering};
use vpy_parser::{Expr, Module, Stmt};
use super::expressions;
use crate::AssetInfo;

static GLFY_COUNTER: AtomicUsize = AtomicUsize::new(0);

/// Returns true if the module uses any level system builtins
pub fn needs_level_runtime(module: &Module) -> bool {
    fn check_expr(expr: &Expr) -> bool {
        if let Expr::Call(c) = expr {
            // GET_LEVEL_FLOOR_Y must also pull in the runtime block — its multibank
            // path is a JSR to a helper emitted alongside the other LEVEL_*_RUNTIMEs.
            matches!(c.name.as_str(),
                "LOAD_LEVEL" | "SHOW_LEVEL" | "UPDATE_LEVEL" | "LEVEL_COLLISION_Y" | "LEVEL_COLLISION_X" | "GET_LEVEL_FLOOR_Y")
        } else { false }
    }
    fn check_stmt(stmt: &Stmt) -> bool {
        match stmt {
            Stmt::Expr(e, _) => check_expr(e),
            Stmt::If { cond, body, elifs, else_body, .. } =>
                check_expr(cond) || body.iter().any(check_stmt) ||
                elifs.iter().any(|(e,b)| check_expr(e) || b.iter().any(check_stmt)) ||
                else_body.as_ref().map_or(false, |b| b.iter().any(check_stmt)),
            Stmt::While { cond, body, .. } => check_expr(cond) || body.iter().any(check_stmt),
            Stmt::Assign { value, .. } => check_expr(value),
            _ => false,
        }
    }
    module.items.iter().any(|item| {
        if let vpy_parser::Item::Function(func) = item {
            func.body.iter().any(check_stmt)
        } else { false }
    })
}

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
///   +21..+28: FDB scrollLeft, scrollRight, scrollTop, scrollBottom
///
/// All layers (BG/GP/FG) are read from ROM directly with stride 21 (stride-21 format).
/// Stride-21 adds a vector_bank FCB at ROM+16 before the vector_ptr FDB at ROM+17.
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

        if crate::m6809::builtins::use_banked_assets() {
            // Multibank mode with distributed assets: use LOAD_LEVEL_BANKED with index
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

/// Emit SET_CAMERA_X(value) - Set 16-bit camera X scroll offset
///
/// Evaluates the expression and stores the result into CAMERA_X (16-bit).
/// SHOW_LEVEL_RUNTIME subtracts CAMERA_X from each object's world_x to get
/// the screen-relative x position.  Default value is 0 (no scroll).
pub fn emit_set_camera_x(args: &[Expr], out: &mut String, assets: &[crate::AssetInfo]) {
    out.push_str("    ; ===== SET_CAMERA_X builtin =====\n");
    if args.is_empty() {
        out.push_str("    ; ERROR: SET_CAMERA_X requires 1 argument\n");
        out.push_str("    LDD #0\n");
        out.push_str("    STD RESULT\n");
        return;
    }
    expressions::emit_simple_expr(&args[0], out, assets);
    out.push_str("    STD >CAMERA_X    ; Store 16-bit camera X scroll offset\n");
    out.push_str("    LDD #0\n");
    out.push_str("    STD RESULT\n");
}

/// Emit SET_CAMERA_Y(value) - Set 16-bit camera Y scroll offset
///
/// Evaluates the expression and stores the result into CAMERA_Y (16-bit).
/// SHOW_LEVEL_RUNTIME subtracts CAMERA_Y from each object's world_y to get
/// the screen-relative y position.  Default value is 0 (no scroll).
pub fn emit_set_camera_y(args: &[Expr], out: &mut String, assets: &[crate::AssetInfo]) {
    out.push_str("    ; ===== SET_CAMERA_Y builtin =====\n");
    if args.is_empty() {
        out.push_str("    ; ERROR: SET_CAMERA_Y requires 1 argument\n");
        out.push_str("    LDD #0\n");
        out.push_str("    STD RESULT\n");
        return;
    }
    expressions::emit_simple_expr(&args[0], out, assets);
    out.push_str("    STD >CAMERA_Y    ; Store 16-bit camera Y scroll offset\n");
    out.push_str("    LDD #0\n");
    out.push_str("    STD RESULT\n");
}

/// Emit GET_SCROLL_LIMIT_LEFT() → returns SCROLL_LIMIT_LEFT (16-bit signed)
pub fn emit_get_scroll_limit_left(_args: &[Expr], out: &mut String) {
    out.push_str("    ; ===== GET_SCROLL_LIMIT_LEFT builtin =====\n");
    out.push_str("    LDD >SCROLL_LIMIT_LEFT\n");
    out.push_str("    STD RESULT\n");
}

/// Emit GET_SCROLL_LIMIT_RIGHT() → returns SCROLL_LIMIT_RIGHT (16-bit signed)
pub fn emit_get_scroll_limit_right(_args: &[Expr], out: &mut String) {
    out.push_str("    ; ===== GET_SCROLL_LIMIT_RIGHT builtin =====\n");
    out.push_str("    LDD >SCROLL_LIMIT_RIGHT\n");
    out.push_str("    STD RESULT\n");
}

/// Emit GET_SCROLL_LIMIT_TOP() → returns SCROLL_LIMIT_TOP (16-bit signed)
pub fn emit_get_scroll_limit_top(_args: &[Expr], out: &mut String) {
    out.push_str("    ; ===== GET_SCROLL_LIMIT_TOP builtin =====\n");
    out.push_str("    LDD >SCROLL_LIMIT_TOP\n");
    out.push_str("    STD RESULT\n");
}

/// Emit GET_SCROLL_LIMIT_BOTTOM() → returns SCROLL_LIMIT_BOTTOM (16-bit signed)
pub fn emit_get_scroll_limit_bottom(_args: &[Expr], out: &mut String) {
    out.push_str("    ; ===== GET_SCROLL_LIMIT_BOTTOM builtin =====\n");
    out.push_str("    LDD >SCROLL_LIMIT_BOTTOM\n");
    out.push_str("    STD RESULT\n");
}

/// Emit GET_LEVEL_FLOOR_Y() → CAMERA_Y - 128 + groundBottomOffset (level header +32).
/// Mirrors pitrex_get_level_floor_y so cross-target code can share spawn math.
///
/// MULTIBANK: emits a JSR to GET_LEVEL_FLOOR_Y_RUNTIME (in the fixed helpers bank).
/// Inlining the bank-switch sequence at the call site is UNSAFE because the call
/// site lives in a switchable bank — `STA $DF00` flips the mapped bank
/// underneath PC's own code fetches and the very next instruction executes from
/// the wrong bank (level-data bytes interpreted as code → invalid opcode crash).
/// The runtime helper sits at $4000+ which is the fixed helpers bank, so bank
/// switching from there is safe (PC's code fetches never come from $0000-$3FFF).
pub fn emit_get_level_floor_y(_args: &[Expr], out: &mut String) {
    out.push_str("    ; ===== GET_LEVEL_FLOOR_Y builtin =====\n");
    if crate::m6809::builtins::use_banked_assets() {
        // Single instruction: helper does all the work in helpers bank.
        out.push_str("    JSR GET_LEVEL_FLOOR_Y_RUNTIME\n");
    } else {
        // Single-bank: safe to inline (no bank switching at all).
        let n = GLFY_COUNTER.fetch_add(1, Ordering::SeqCst);
        let skip = format!("GLFY_SKIP_{}", n);
        out.push_str("    LDX >LEVEL_PTR\n");
        out.push_str("    LDD #0              ; default offset = 0 if no level\n");
        out.push_str("    CMPX #0\n");
        out.push_str(&format!("    BEQ {}          ; no level loaded — keep offset 0\n", skip));
        out.push_str("    LDD 32,X            ; groundBottomOffset FDB at header +32\n");
        out.push_str(&format!("{}:\n", skip));
        out.push_str("    ADDD >CAMERA_Y      ; + camera_y\n");
        out.push_str("    SUBD #128           ; - 128 (half screen height)\n");
        out.push_str("    STD RESULT\n");
    }
}

/// Emit GET_FRAME_US() → stub. The Vectrex has no µs hardware timer accessible
/// at this level (VIA T2 is used by display), so return 0. Code paths that read
/// this for adaptive timing just see "no time elapsed" and skip slow-frame
/// branches, which is harmless on M6809 (single tempo target).
pub fn emit_get_frame_us(_args: &[Expr], out: &mut String) {
    out.push_str("    ; ===== GET_FRAME_US builtin (stub: returns 0) =====\n");
    out.push_str("    LDD #0\n");
    out.push_str("    STD RESULT\n");
}

/// Emit LEVEL_COLLISION_Y(player_x, player_y) → highest floor Y at player_x in the GP layer
///
/// Scans all collidable GP objects (collision_flags bit 0 set) and returns the top Y
/// Returns tile_top + player_half_height (the Y where player CENTER should be to stand on the surface).
/// Only considers surfaces whose top <= player_top (player_y + player_half_height).
/// Returns -128 + player_half_height if no surface found.
/// Caller usage:
///   floor_y = LEVEL_COLLISION_Y(player_x, player_y, player_half_height)
///   if player_y <= floor_y: player_y = floor_y; land()
pub fn emit_level_collision_y(args: &[Expr], out: &mut String, assets: &[crate::AssetInfo]) {
    out.push_str("    ; ===== LEVEL_COLLISION_Y builtin =====\n");
    if args.len() < 3 {
        out.push_str("    ; ERROR: LEVEL_COLLISION_Y requires 3 arguments (player_x, player_y, player_half_height)\n");
        out.push_str("    LDD #0\n");
        out.push_str("    STD RESULT\n");
        return;
    }
    // arg[0]: player_x → LCOL_PX
    expressions::emit_simple_expr(&args[0], out, assets);
    out.push_str("    STD >LCOL_PX         ; store player world_x (16-bit)\n");
    // arg[2]: player_half_height → LCOL_PHH (evaluate first so B is available for subtraction)
    expressions::emit_simple_expr(&args[2], out, assets);
    out.push_str("    STB >LCOL_PHH        ; store player half_height\n");
    // arg[1]: player_y (16-bit) - player_hh → LCOL_PY (player's feet, 16-bit)
    // Filter: skip surfaces whose top > player_feet (already below the feet — can't land on it from below)
    expressions::emit_simple_expr(&args[1], out, assets);
    out.push_str("    ; Compute player_feet = player_y - player_hh (16-bit)\n");
    out.push_str("    STD >TMPVAL          ; save player_y\n");
    out.push_str("    LDB >LCOL_PHH        ; B = player_hh\n");
    out.push_str("    CLRA\n");
    out.push_str("    STD >LCOL_PY         ; reuse as scratch (16-bit hh)\n");
    out.push_str("    LDD >TMPVAL          ; D = player_y\n");
    out.push_str("    SUBD >LCOL_PY        ; D = player_y - player_hh = player_feet\n");
    out.push_str("    STD >LCOL_PY         ; store player_feet Y (16-bit) for surface filter\n");
    out.push_str("    JSR LEVEL_COLLISION_Y_RUNTIME\n");
}

/// Emit LEVEL_COLLISION_X(player_x, player_y, player_half_width, player_half_height) → push-out dx
///
/// Scans all collidable GP objects and returns a signed 16-bit push-out dx.
/// Positive = push right, negative = push left, 0 = no horizontal overlap.
/// player_half_height is used for the Y-overlap test so that hitting the bottom of a block
/// from below does not trigger a lateral push (threshold = player_hh + obj_hh exactly excludes it).
pub fn emit_level_collision_x(args: &[Expr], out: &mut String, assets: &[crate::AssetInfo]) {
    out.push_str("    ; ===== LEVEL_COLLISION_X builtin =====\n");
    if args.len() < 4 {
        out.push_str("    ; ERROR: LEVEL_COLLISION_X requires 4 arguments (player_x, player_y, player_half_width, player_half_height)\n");
        out.push_str("    LDD #0\n");
        out.push_str("    STD RESULT\n");
        return;
    }
    // arg[0]: player_x → LCOL_PX (16-bit)
    expressions::emit_simple_expr(&args[0], out, assets);
    out.push_str("    STD >LCOL_PX         ; store player world_x (16-bit)\n");
    // arg[2]: player_half_width → LCOL_PHW
    expressions::emit_simple_expr(&args[2], out, assets);
    out.push_str("    STB >LCOL_PHW        ; store player half_width\n");
    // arg[3]: player_half_height → LCOL_PHH (used for Y-overlap; runtime stores total_hw in LCOL_THW, not here)
    expressions::emit_simple_expr(&args[3], out, assets);
    out.push_str("    STB >LCOL_PHH        ; store player half_height for Y-overlap check\n");
    // arg[1]: player_y (16-bit) → LCOL_PY
    expressions::emit_simple_expr(&args[1], out, assets);
    out.push_str("    STD >LCOL_PY         ; store player_y (16-bit)\n");
    out.push_str("    JSR LEVEL_COLLISION_X_RUNTIME\n");
}

/// Emit runtime helpers for level system.
/// Only emits helpers that are actually used in the code (tree shaking).
pub fn emit_runtime_helpers(out: &mut String, needed: &HashSet<String>) {

    // =========================================================================
    // GET_LEVEL_FLOOR_Y_RUNTIME — multibank only
    // =========================================================================
    // Read groundBottomOffset (FDB at level header +32) and compute the floor
    // screen-Y. Lives in helpers bank ($4000+, fixed) so STA $DF00 here never
    // affects PC's own code fetches. Callers in switchable banks `JSR` to this
    // helper instead of inlining the bank-switch sequence (which would flip the
    // bank under their own PC and execute level-data bytes as code).
    if needed.contains("GET_LEVEL_FLOOR_Y_RUNTIME") && crate::m6809::builtins::use_banked_assets() {
        out.push_str("; === GET_LEVEL_FLOOR_Y_RUNTIME (multibank) ===\n");
        out.push_str("GET_LEVEL_FLOOR_Y_RUNTIME:\n");
        out.push_str("    LDX >LEVEL_PTR\n");
        out.push_str("    LDD #0              ; default offset = 0 if no level\n");
        out.push_str("    CMPX #0\n");
        out.push_str("    BEQ GLFYR_NO_LEVEL  ; no level loaded — keep offset 0\n");
        out.push_str("    LDA >CURRENT_ROM_BANK\n");
        out.push_str("    PSHS A              ; save current bank\n");
        out.push_str("    LDA >LEVEL_BANK\n");
        out.push_str("    STA >CURRENT_ROM_BANK\n");
        out.push_str("    STA $DF00           ; switch — safe: we're in fixed helpers bank\n");
        out.push_str("    LDD 32,X            ; groundBottomOffset FDB at header +32\n");
        out.push_str("    STD >TMPVAL         ; save across bank restore (PULS clobbers D's hi)\n");
        out.push_str("    PULS A              ; restore original bank\n");
        out.push_str("    STA >CURRENT_ROM_BANK\n");
        out.push_str("    STA $DF00\n");
        out.push_str("    LDD >TMPVAL\n");
        out.push_str("GLFYR_NO_LEVEL:\n");
        out.push_str("    ADDD >CAMERA_Y      ; + camera_y\n");
        out.push_str("    SUBD #128           ; - 128 (half screen height)\n");
        out.push_str("    STD RESULT\n");
        out.push_str("    RTS\n");
        out.push_str("\n");
    }

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
        out.push_str("    ; Store level pointer and mark as loaded\n");
        out.push_str("    STX >LEVEL_PTR\n");
        out.push_str("    LDA #1\n");
        out.push_str("    STA >LEVEL_LOADED    ; Mark level as loaded\n");
        out.push_str("    \n");
        out.push_str("    ; Camera is NOT reset here (matches pitrex/rp2350). It is initialised once\n");
        out.push_str("    ; at boot in MAIN; the game sets it via SET_CAMERA_Y before LOAD_LEVEL, and\n");
        out.push_str("    ; GET_LEVEL_FLOOR_Y / the SPAWN_ENEMIES Y-filter read it after this call.\n");
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
        out.push_str("    ; Read scroll limits from ROM header (+21..+28)\n");
        out.push_str("    ; X is now at +21 (right after the 3 FDB layer pointers)\n");
        out.push_str("    LDD ,X++         ; D = scrollLimit left\n");
        out.push_str("    STD >SCROLL_LIMIT_LEFT\n");
        out.push_str("    LDD ,X++         ; D = scrollLimit right\n");
        out.push_str("    STD >SCROLL_LIMIT_RIGHT\n");
        out.push_str("    LDD ,X++         ; D = scrollLimit top\n");
        out.push_str("    STD >SCROLL_LIMIT_TOP\n");
        out.push_str("    LDD ,X++         ; D = scrollLimit bottom\n");
        out.push_str("    STD >SCROLL_LIMIT_BOTTOM\n");
        out.push_str("    \n");
        out.push_str("    ; Read enemy data from header (+29: count, +30,+31: instances_ptr)\n");
        out.push_str("    LDB ,X+         ; B = enemy_count\n");
        out.push_str("    STB >LEVEL_ENEMY_COUNT\n");
        out.push_str("    LDD ,X++        ; D = enemy_instances_ptr (advance past +30..+31)\n");
        out.push_str("    STD >LEVEL_ENEMY_INSTANCES_PTR\n");
        out.push_str("    LEAX 2,X        ; skip groundBottomOffset (+32..+33)\n");
        out.push_str("    \n");
        out.push_str("    ; Per-screen object index (+34..+40)\n");
        out.push_str("    LDB ,X+         ; B = screen_count\n");
        out.push_str("    STB >LEVEL_SCREEN_COUNT\n");
        out.push_str("    LDD ,X++        ; D = bg_screens_ptr\n");
        out.push_str("    STD >LEVEL_BG_SCREENS_PTR\n");
        out.push_str("    LDD ,X++        ; D = gp_screens_ptr\n");
        out.push_str("    STD >LEVEL_GP_SCREENS_PTR\n");
        out.push_str("    LDD ,X          ; D = fg_screens_ptr\n");
        out.push_str("    STD >LEVEL_FG_SCREENS_PTR\n");
        out.push_str("    \n");
        out.push_str("    ; === Setup GP pointer: point directly to ROM (matches core) ===\n");
        out.push_str("    ; GP objects are read from ROM with stride=21 (stride-21 format), same as BG/FG\n");
        out.push_str("    LDB >LEVEL_GP_COUNT\n");
        out.push_str("    BEQ LLR_SKIP_GP  ; Skip if no GP objects\n");
        out.push_str("    LDD >LEVEL_GP_ROM_PTR ; Just point to ROM\n");
        out.push_str("    STD >LEVEL_GP_PTR    ; Store ROM pointer\n");
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
        out.push_str("; === LLR_COPY_OBJECTS - LEGACY (not called; GP objects read from ROM directly)\n");
        out.push_str("; Input:  B = count, X = source (ROM, 21 bytes/obj stride-21), U = dest (RAM)\n");
        out.push_str("; ROM object layout (21 bytes, stride-21):\n");
        out.push_str(";   +0: type, +1-2: x(FDB), +3-4: y(FDB), +5-6: scale(FDB),\n");
        out.push_str(";   +7: rotation, +8: intensity, +9: velocity_x, +10: velocity_y,\n");
        out.push_str(";   +11: physics_flags, +12: collision_flags, +13: collision_size,\n");
        out.push_str(";   +14-15: spawn_delay(FDB), +16: vector_bank(FCB), +17-18: vector_ptr(FDB),\n");
        out.push_str(";   +19: half_width, +20: half_height\n");
        out.push_str("; RAM object layout (15 bytes):\n");
        out.push_str(";   +0-1: world_x(FDB i16), +2: y(i8), +3: scale(low), +4: rotation,\n");
        out.push_str(";   +5: velocity_x, +6: velocity_y, +7: physics_flags, +8: collision_flags,\n");
        out.push_str(";   +9: collision_size, +10: spawn_delay(low), +11-12: vector_ptr, +13: half_width, +14: half_height\n");
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
        out.push_str("    ; RAM +0-1: world_x FDB (16-bit, ROM +1-2)\n");
        out.push_str("    LDA ,X           ; ROM +1 = high byte of x FDB\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    LDA 1,X          ; ROM +2 = low byte of x FDB\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    ; RAM +2: y low byte (ROM +4, low byte of y FDB)\n");
        out.push_str("    LDA 3,X          ; ROM +4 = low byte of y FDB\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    ; RAM +3: scale low byte (ROM +6, low byte of scale FDB)\n");
        out.push_str("    LDA 5,X          ; ROM +6 = low byte of scale FDB\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    ; RAM +4: rotation (ROM +7)\n");
        out.push_str("    LDA 6,X          ; ROM +7 = rotation\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    ; Skip to ROM +9 (past intensity at ROM +8)\n");
        out.push_str("    LEAX 8,X         ; X now points to ROM +9 (velocity_x)\n");
        out.push_str("    ; RAM +5: velocity_x (ROM +9)\n");
        out.push_str("    LDA ,X+          ; ROM +9\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    ; RAM +6: velocity_y (ROM +10)\n");
        out.push_str("    LDA ,X+          ; ROM +10\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    ; RAM +7: physics_flags (ROM +11)\n");
        out.push_str("    LDA ,X+          ; ROM +11\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    ; RAM +8: collision_flags (ROM +12)\n");
        out.push_str("    LDA ,X+          ; ROM +12\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    ; RAM +9: collision_size (ROM +13)\n");
        out.push_str("    LDA ,X+          ; ROM +13\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    ; RAM +10: spawn_delay low byte (ROM +15, skip high at ROM +14)\n");
        out.push_str("    LDA 1,X          ; ROM +15 = low byte of spawn_delay FDB\n");
        out.push_str("    STA ,U+\n");
        out.push_str("    LEAX 3,X         ; Skip spawn_delay FDB (2 bytes) + vector_bank (1), X now at ROM+17\n");
        out.push_str("    ; RAM +11-12: vector_ptr FDB (ROM +17-18, stride-21)\n");
        out.push_str("    LDD ,X++         ; ROM +17-18 = vector_ptr FDB\n");
        out.push_str("    STD ,U++\n");
        out.push_str("    ; RAM +13-14: half_width + half_height (ROM +19-20, stride-21)\n");
        out.push_str("    LDD ,X++         ; ROM +19-20\n");
        out.push_str("    STD ,U++\n");
        out.push_str("    ; X is now past end of this ROM object (ROM+1 + 8 + 5 + 3 + 2 + 2 = +21 total)\n");
        out.push_str("    ; NOTE: We started at ROM+1 (after LEAX 1,X), walked:\n");
        out.push_str("    ;   ,X and 1,X and 3,X and 5,X and 6,X via indexed → X unchanged\n");
        out.push_str("    ;   then LEAX 8,X (X now at ROM+9)\n");
        out.push_str("    ;   then 5 post-increment ,X+ → X at ROM+14\n");
        out.push_str("    ;   then LEAX 3,X (X at ROM+17)\n");
        out.push_str("    ;   then 2x LDD ,X++ → X at ROM+21\n");
        out.push_str("    ;   ROM+21 from original ROM+0 = next object start (stride-21)\n");
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
        out.push_str("; Layers: BG (ROM stride 21), GP (ROM stride 21), FG (ROM stride 21)\n");
        out.push_str("; ROM object layout (21 bytes, stride-21):\n");
        out.push_str(";   +0: type, +1-2: x(FDB), +3-4: y(FDB), +5-6: scale(FDB),\n");
        out.push_str(";   +7: rotation, +8: intensity, +9: velocity_x, +10: velocity_y,\n");
        out.push_str(";   +11: physics_flags, +12: collision_flags, +13: collision_size,\n");
        out.push_str(";   +14-15: spawn_delay(FDB), +16: vector_bank(FCB, $FF=null),\n");
        out.push_str(";   +17-18: vector_ptr(FDB), +19: half_width(FCB), +20: half_height(FCB)\n");
        out.push_str("; Each object: load intensity, x, y, vector_bank, vector_ptr, call SLR_DRAW_OBJECTS\n");
        out.push_str("SHOW_LEVEL_RUNTIME:\n");
        out.push_str("    PSHS D,X,Y,U     ; Preserve registers\n");
        out.push_str("    JSR $F1AA        ; DP_to_D0 (set DP=$D0 for VIA access)\n");
        if crate::m6809::builtins::use_banked_assets() {
            out.push_str("    ; MULTIBANK: Switch to level bank so ROM pointers are valid\n");
            out.push_str("    LDA >CURRENT_ROM_BANK\n");
            out.push_str("    PSHS A              ; Save current bank\n");
            out.push_str("    LDA >LEVEL_BANK\n");
            out.push_str("    STA >CURRENT_ROM_BANK\n");
            out.push_str("    STA $DF00           ; Switch to level bank\n");
        }
        out.push_str("    \n");
        out.push_str("    ; Check if level is loaded\n");
        out.push_str("    TST >LEVEL_LOADED\n");
        out.push_str("    BEQ SLR_DONE     ; No level loaded, skip\n");
        out.push_str("    LDX >LEVEL_PTR\n");
        out.push_str("    \n");
        out.push_str("    ; Re-read object counts from header (legacy: kept for any caller that reads RAM vars)\n");
        out.push_str("    LEAX 12,X        ; X points to counts (+12)\n");
        out.push_str("    LDB ,X+          ; B = bgCount\n");
        out.push_str("    STB >LEVEL_BG_COUNT\n");
        out.push_str("    LDB ,X+          ; B = gpCount\n");
        out.push_str("    STB >LEVEL_GP_COUNT\n");
        out.push_str("    LDB ,X+          ; B = fgCount\n");
        out.push_str("    STB >LEVEL_FG_COUNT\n");
        out.push_str("    \n");
        out.push_str("    ; ── PER-SCREEN VISIBLE RANGE ─────────────────────────────────────\n");
        out.push_str("    ; Compute top_screen, bot_screen — only iterate objects whose screen\n");
        out.push_str("    ; band overlaps the camera's ±128 Y window. For SnowBros (1 screen\n");
        out.push_str("    ; visible) this is normally 1 screen, occasionally 2 during scroll.\n");
        out.push_str("    LDX >LEVEL_PTR\n");
        out.push_str("    LDD 6,X          ; D = yMax\n");
        out.push_str("    STD >TMPPTR      ; cache yMax\n");
        out.push_str("    LDD >CAMERA_Y\n");
        out.push_str("    ADDD #128        ; D = top_y (camera_y + 128, higher Y = top of screen)\n");
        out.push_str("    PSHS D\n");
        out.push_str("    LDD >TMPPTR      ; yMax\n");
        out.push_str("    SUBD ,S++        ; D = yMax - top_y\n");
        out.push_str("    TSTA             ; sign byte\n");
        out.push_str("    BPL SLR_TOP_OK   ; positive → A is the screen idx (D / 256)\n");
        out.push_str("    CLRA             ; negative → clamp top_screen to 0\n");
        out.push_str("SLR_TOP_OK:\n");
        out.push_str("    STA >TMPVAL      ; TMPVAL = top_screen\n");
        out.push_str("    LDD >CAMERA_Y\n");
        out.push_str("    SUBD #128        ; D = bot_y (camera_y - 128)\n");
        out.push_str("    PSHS D\n");
        out.push_str("    LDD >TMPPTR      ; yMax\n");
        out.push_str("    SUBD ,S++        ; D = yMax - bot_y\n");
        out.push_str("    TSTA\n");
        out.push_str("    BPL SLR_BOT_OK\n");
        out.push_str("    CLRA\n");
        out.push_str("SLR_BOT_OK:\n");
        out.push_str("    ; Clamp bot_screen to (LEVEL_SCREEN_COUNT - 1) max\n");
        out.push_str("    LDB >LEVEL_SCREEN_COUNT\n");
        out.push_str("    LBEQ SLR_DONE    ; no screens → nothing to draw\n");
        out.push_str("    DECB             ; B = max_idx = screen_count - 1\n");
        out.push_str("    STB >TMPVAL+1    ; stash max_idx for compare (no CBA in assembler)\n");
        out.push_str("    CMPA >TMPVAL+1   ; A (bot_screen) vs max_idx\n");
        out.push_str("    BLS SLR_BOT_NOCLAMP\n");
        out.push_str("    LDA >TMPVAL+1    ; clamp bot_screen = max_idx\n");
        out.push_str("SLR_BOT_NOCLAMP:\n");
        out.push_str("    STA >TMPVAL+1    ; TMPVAL+1 = bot_screen\n");
        out.push_str("    \n");
        out.push_str("    ; === Draw Background Layer ===\n");
        out.push_str("SLR_BG_LAYER:\n");
        out.push_str("    LDD >LEVEL_BG_SCREENS_PTR\n");
        out.push_str("    STD >TMPPTR      ; TMPPTR = table base for this layer\n");
        out.push_str("    JSR SLR_DRAW_SCREEN_RANGE\n");
        out.push_str("    \n");
        out.push_str("    ; === Draw Gameplay Layer ===\n");
        out.push_str("SLR_GAMEPLAY:\n");
        out.push_str("    LDD >LEVEL_GP_SCREENS_PTR\n");
        out.push_str("    STD >TMPPTR\n");
        out.push_str("    JSR SLR_DRAW_SCREEN_RANGE\n");
        out.push_str("    \n");
        out.push_str("    ; === Draw Foreground Layer ===\n");
        out.push_str("SLR_FOREGROUND:\n");
        out.push_str("    LDD >LEVEL_FG_SCREENS_PTR\n");
        out.push_str("    STD >TMPPTR\n");
        out.push_str("    JSR SLR_DRAW_SCREEN_RANGE\n");
        out.push_str("    \n");
        out.push_str("SLR_DONE:\n");
        if crate::m6809::builtins::use_banked_assets() {
            out.push_str("    ; MULTIBANK: Restore original bank\n");
            out.push_str("    PULS A              ; A = saved bank\n");
            out.push_str("    STA >CURRENT_ROM_BANK\n");
            out.push_str("    STA $DF00           ; Restore bank\n");
        }
        // CRITICAL: Match core compiler - JSR $F1AF BEFORE PULS to avoid corrupting D register
        // $F1AF restores DP=$C8 without touching D,X,Y,U (safe for PULS)
        out.push_str("    JSR $F1AF        ; DP_to_C8 (restore DP for RAM access)\n");
        out.push_str("    PULS D,X,Y,U,PC  ; Restore and return\n");
        out.push_str("    \n");
        // ---- SLR_DRAW_SCREEN_RANGE subroutine ----
        // Walks the per-screen index for one layer, calling SLR_DRAW_OBJECTS
        // for each screen in [top_screen, bot_screen]. Input: TMPPTR = screens_table_ptr.
        // top_screen at TMPVAL, bot_screen at TMPVAL+1.
        // Each screen entry is 3 bytes: FCB count, FDB ptr.
        out.push_str("; === SLR_DRAW_SCREEN_RANGE — iterate screens in visible camera range ===\n");
        out.push_str("SLR_DRAW_SCREEN_RANGE:\n");
        out.push_str("    LDA >TMPVAL          ; A = current screen idx (start at top)\n");
        out.push_str("SLR_SR_LOOP:\n");
        out.push_str("    CMPA >TMPVAL+1\n");
        out.push_str("    BHI SLR_SR_DONE      ; current > bot → finished\n");
        out.push_str("    CMPA >LEVEL_SCREEN_COUNT\n");
        out.push_str("    BHS SLR_SR_DONE      ; defensive: don't index past table\n");
        out.push_str("    ; Compute &table[s] = TMPPTR + s*3\n");
        out.push_str("    PSHS A               ; save loop var\n");
        out.push_str("    LDB #3\n");
        out.push_str("    MUL                  ; D = s*3 (A=0 since s < 256/3, B = offset)\n");
        out.push_str("    LDX >TMPPTR          ; X = screens table base\n");
        out.push_str("    LEAX D,X             ; X = &table[s]\n");
        out.push_str("    LDB ,X               ; B = count for this screen\n");
        out.push_str("    BEQ SLR_SR_NEXT      ; empty screen → skip\n");
        out.push_str("    LDX 1,X              ; X = ptr to first object in this screen\n");
        out.push_str("    LDA #23              ; ROM object stride\n");
        out.push_str("    JSR SLR_DRAW_OBJECTS\n");
        out.push_str("SLR_SR_NEXT:\n");
        out.push_str("    PULS A\n");
        out.push_str("    INCA\n");
        out.push_str("    BRA SLR_SR_LOOP\n");
        out.push_str("SLR_SR_DONE:\n");
        out.push_str("    RTS\n");
        out.push_str("    \n");
        // ---- SLR_DRAW_OBJECTS subroutine ----
        out.push_str("; === SLR_DRAW_OBJECTS - Draw N objects from a layer ===\n");
        out.push_str("; Input:  A = stride (21=ROM), B = count, X = objects ptr\n");
        out.push_str("; For ROM objects (stride=21, stride-21 format):\n");
        out.push_str(";   intensity at +8, y FDB at +3, x FDB at +1, half_width at +19\n");
        out.push_str(";   vector_bank at +16 ($FF=null), vector_ptr FDB at +17\n");
        out.push_str("; Camera: SUBD >CAMERA_X applied to world_x; objects outside i8 range are culled\n");
        out.push_str("SLR_DRAW_OBJECTS:\n");
        out.push_str("    PSHS A           ; Save stride on stack (A=stride)\n");
        out.push_str("SLR_OBJ_LOOP:\n");
        out.push_str("    TSTB\n");
        out.push_str("    LBEQ SLR_OBJ_DONE\n");
        out.push_str("    \n");
        out.push_str("    PSHS B           ; Save counter (LDD clobbers B)\n");
        out.push_str("    \n");
        out.push_str("    ; All layers use stride-21 ROM format — fall straight through\n");
        out.push_str("    \n");
        out.push_str("SLR_ROM_OFFSETS:\n");
        out.push_str("    ; === ROM object (stride=21, stride-21 format) ===\n");
        out.push_str("    ; Skip enemy spawn markers (type==1): drawn by DRAW_ENEMIES, not SHOW_LEVEL\n");
        out.push_str("    LDA ,X           ; type byte at ROM+0\n");
        out.push_str("    CMPA #1\n");
        out.push_str("    LBEQ SLR_OBJ_NEXT ; enemy marker: skip, handle via DRAW_ENEMIES\n");
        out.push_str("    CLR >MIRROR_X    ; DP=$D0, must use extended addressing\n");
        out.push_str("    CLR >MIRROR_Y\n");
        out.push_str("    LDA 8,X          ; intensity at ROM +8\n");
        out.push_str("    STA >DRAW_VEC_INTENSITY\n");
        out.push_str("    ; Apply CAMERA_Y: load world_y FDB at ROM +3, subtract CAMERA_Y, cull\n");
        out.push_str("    LDD 3,X          ; world_y FDB at ROM +3 (16-bit signed)\n");
        out.push_str("    SUBD >CAMERA_Y   ; screen_y = world_y - camera_y\n");
        out.push_str("    TSTA\n");
        out.push_str("    BEQ SLR_ROM_Y_ZERO\n");
        out.push_str("    INCA\n");
        out.push_str("    LBNE SLR_OBJ_NEXT    ; A not $FF: too far above\n");
        out.push_str("    ; A=$FF: visible if B >= 128 (i.e. >= -128 signed)\n");
        out.push_str("    CMPB #128\n");
        out.push_str("    BHS SLR_ROM_Y_VISIBLE\n");
        out.push_str("    LBRA SLR_OBJ_NEXT\n");
        out.push_str("SLR_ROM_Y_ZERO:\n");
        out.push_str("    ; A=0: visible if B <= 127\n");
        out.push_str("    CMPB #127\n");
        out.push_str("    BLS SLR_ROM_Y_VISIBLE\n");
        out.push_str("    LBRA SLR_OBJ_NEXT\n");
        out.push_str("SLR_ROM_Y_VISIBLE:\n");
        out.push_str("    STB >DRAW_VEC_Y  ; DP=$D0, must use extended addressing\n");
        out.push_str("    ; Load world_x (16-bit), subtract CAMERA_X, check visibility\n");
        out.push_str("    LDD 1,X          ; x FDB at ROM +1\n");
        out.push_str("    SUBD >CAMERA_X   ; screen_x = world_x - camera_x\n");
        out.push_str("    STD >TMPVAL\n");
        out.push_str("    ; STRICT cull at ±127: Draw_Sync_List_At_With_Mirrors uses only the\n");
        out.push_str("    ; LOW BYTE of screen_x (DRAW_VEC_X), so any object whose 16-bit screen_x\n");
        out.push_str("    ; is outside ±127 wraps to the opposite edge (ghost vectors). The previous\n");
        out.push_str("    ; cull widened by half_width to render partial edges but caused the wrap.\n");
        out.push_str("    LDD >TMPVAL\n");
        out.push_str("    TSTA\n");
        out.push_str("    BEQ SLR_ROM_A_ZERO\n");
        out.push_str("    INCA\n");
        out.push_str("    LBNE SLR_OBJ_NEXT  ; high byte ≠ $00/$FF → out of ±255 window, skip\n");
        out.push_str("    ; A was $FF (now 0): screen_x in [-256..-1]; visible if B >= 128 (i.e. -128..-1)\n");
        out.push_str("    CMPB #128\n");
        out.push_str("    BHS SLR_ROM_VISIBLE\n");
        out.push_str("    LBRA SLR_OBJ_NEXT\n");
        out.push_str("SLR_ROM_A_ZERO:\n");
        out.push_str("    ; A=0: screen_x in [0..255]; visible if B <= 127\n");
        out.push_str("    CMPB #127\n");
        out.push_str("    BLS SLR_ROM_VISIBLE\n");
        out.push_str("    LBRA SLR_OBJ_NEXT\n");
        out.push_str("SLR_ROM_VISIBLE:\n");
        out.push_str("    LDD >TMPVAL      ; reload full 16-bit screen_x (INCA corrupted A)\n");
        out.push_str("    STD >DRAW_VEC_X_HI ; store full 16-bit screen_x (A=hi, B=lo)\n");
        out.push_str("    ; Stride-21: vector_bank at ROM+16 ($FF=null), vector_ptr FDB at ROM+17\n");
        out.push_str("    ; CRITICAL: read ALL level-bank data BEFORE switching to vector bank.\n");
        out.push_str("    LDA 16,X         ; A = vector_bank (LEVEL BANK ACTIVE)\n");
        out.push_str("    CMPA #$FF        ; $FF = null (no visual for this object)\n");
        out.push_str("    LBEQ SLR_OBJ_NEXT ; null bank → skip draw\n");
        out.push_str("    LDU 17,X         ; vector_ptr FDB at ROM+17 (STILL IN LEVEL BANK)\n");
        out.push_str("    LDA 6,X          ; scale_t1 at ROM+6 (STILL IN LEVEL BANK)\n");
        out.push_str("    STA >DRAW_T1_SCALED\n");
        if crate::m6809::builtins::use_banked_assets() {
            out.push_str("    ; MULTIBANK: NOW switch to the vector's bank.\n");
            out.push_str("    ; U = vector address valid in that bank; level data fully read above.\n");
            out.push_str("    ; Level bank is restored in SLR_PATH_DONE after all paths are drawn.\n");
            out.push_str("    LDA 16,X         ; reload vector_bank (LDA 6,X clobbered A)\n");
            out.push_str("    STA >CURRENT_ROM_BANK\n");
            out.push_str("    STA $DF00        ; switch to vector bank\n");
        }
        out.push_str("    \n");
        out.push_str("SLR_DRAW_VECTOR:\n");
        out.push_str("    PSHS X           ; Save object pointer\n");
        out.push_str("    TFR U,X          ; X = vector data pointer (header)\n");
        out.push_str("    \n");
        out.push_str("    ; Read path_count from vector header (FDB = 2 bytes, high byte ignored)\n");
        out.push_str("    LDD ,X++         ; D = path_count FDB; B = low byte = actual count, X now at pointer table\n");
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
        // Use the same DSWM path that DRAW_VECTOR_BANKED uses. SLR_DRAW_CLIPPED_PATH
        // (custom direct-VIA implementation that aimed at 16-bit X clip) caused visible
        // beam flicker on stable scenes — manually replacing SHOW_LEVEL with DRAW_VECTOR
        // calls eliminated it. Draw_Sync_List_At_With_Mirrors reads DRAW_VEC_X (low byte
        // of DRAW_VEC_X_HI, which is the next RAM byte and already populated by the
        // 16-bit STD above) and DRAW_VEC_Y. The trade-off is the loss of per-path
        // 16-bit X clipping, but per-object visibility culling already keeps objects
        // whose centre is on-screen; paths that span >127 from the centre would ghost,
        // which is rare in well-authored .vec data and acceptable vs flicker.
        out.push_str("    JSR Draw_Sync_List_At_With_Mirrors  ; stable BIOS-style VIA drawing (no flicker)\n");
        out.push_str("    PULS X           ; Restore pointer table position\n");
        out.push_str("    PULS B           ; Restore count\n");
        out.push_str("    BRA SLR_PATH_LOOP\n");
        out.push_str("    \n");
        out.push_str("SLR_PATH_DONE:\n");
        out.push_str("    PULS X           ; Restore object pointer\n");
        if crate::m6809::builtins::use_banked_assets() {
            out.push_str("    ; MULTIBANK: Restore level bank now that all vector paths are drawn.\n");
            out.push_str("    ; SLR_OBJ_NEXT needs the level bank active to advance X through level objects.\n");
            out.push_str("    LDA >LEVEL_BANK\n");
            out.push_str("    STA >CURRENT_ROM_BANK\n");
            out.push_str("    STA $DF00        ; switch back to level bank\n");
        }
        out.push_str("    \n");
        out.push_str("SLR_OBJ_NEXT:\n");
        out.push_str("    ; Advance to next object using stride\n");
        out.push_str("    ; Reached here after draw (X restored by PULS X above) OR from\n");
        out.push_str("    ; visibility skip (X never pushed, still points to current object)\n");
        out.push_str("    ; Stack state in both cases: B on top, A=stride below\n");
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

        // ---- SLR_DRAW_CLIPPED_PATH ----
        // Per-segment X-clip draw loop mirroring DSWM VIA register patterns exactly.
        // Draw_Sync_List_At_With_Mirrors is NOT a BIOS call — it is our own custom
        // function in drawing.rs that writes VIA registers directly. BIOS calls like
        // JSR Intensity_a / Draw_Line_d / Moveto_d must NOT be used here: with DP=$D0,
        // Intensity_a would corrupt DDRB ($D032), and Draw_Line_d / Moveto_d are
        // undefined in the context of direct VIA drawing.
        //
        // Format: FCB intensity, y_start, x_start, 0, 0 (header, 5 bytes)
        //         FCB $FF, dy, dx  ...  FCB 2  (segments)
        // B = y, A = x throughout (matching DSWM convention).
        // SLR_CUR_X tracks the absolute beam X for clipping.
        out.push_str("; === SLR_DRAW_CLIPPED_PATH ===\n");
        out.push_str("; Per-segment X-axis clipping using direct VIA register writes.\n");
        out.push_str("; Mirrors the DSWM VIA pattern — no BIOS calls (Intensity_a corrupts\n");
        out.push_str("; DDRB with DP=$D0; Draw_Line_d / Moveto_d are BIOS-only).\n");
        out.push_str("; Segments whose new_x = cur_x+dx overflows a signed byte are moved\n");
        out.push_str("; with beam OFF, preventing screen-wrap at left/right edges.\n");
        out.push_str("SLR_DRAW_CLIPPED_PATH:\n");
        // --- Intensity (same as DSWM: STA >$C832, not JSR Intensity_a) ---
        out.push_str("    LDA >DRAW_VEC_INTENSITY ; check override\n");
        out.push_str("    BNE SDCP_USE_OVERRIDE\n");
        out.push_str("    LDA ,X+                 ; read intensity from path data\n");
        out.push_str("    BRA SDCP_SET_INTENS\n");
        out.push_str("SDCP_USE_OVERRIDE:\n");
        out.push_str("    LEAX 1,X                ; skip intensity byte\n");
        out.push_str("SDCP_SET_INTENS:\n");
        out.push_str("    STA >$C832              ; Vec_Misc_Count (DDRB-safe, no JSR)\n");
        // --- Read y_start (→ B) and x_start (→ A), then compute abs_x via
        //     16-bit sign-extended addition: abs_x_16 = screen_x_16 + SEX(x_start).
        //     If result is outside [-128, +127], skip this path entirely.
        out.push_str("    LDB ,X+                 ; B = y_start (relative to center)\n");
        out.push_str("    LDA ,X+                 ; A = x_start (relative to center)\n");
        out.push_str("    ADDB >DRAW_VEC_Y        ; B = abs_y\n");
        out.push_str("    STB >TMPVAL             ; save abs_y for moveto\n");
        // --- 16-bit abs_x computation: sign-extend x_start (in A) to D,
        //     then add DRAW_VEC_X_HI:DRAW_VEC_X (16-bit screen_x).
        //     Result D = abs_x_16. If high byte != sign extension of low byte,
        //     the abs_x is off-screen → skip this path.
        out.push_str("    TFR A,B                 ; B = x_start (SEX extends B, not A)\n");
        out.push_str("    SEX                      ; sign-extend B→D (A=sign, B=x_start)\n");
        out.push_str("    ADDD >DRAW_VEC_X_HI     ; D = abs_x_16 = SEX(x_start) + screen_x_16\n");
        out.push_str("    ; Range check: abs_x must fit in signed byte [-128, +127]\n");
        out.push_str("    ; If out of range, skip this path (can't position beam correctly).\n");
        out.push_str("    ; Progressive clipping works because paths starting on-screen are\n");
        out.push_str("    ; drawn normally, and their segments get clipped at the edge.\n");
        out.push_str("    TSTA\n");
        out.push_str("    BEQ SDCP_CHECK_POS       ; A=$00 → check positive range\n");
        out.push_str("    INCA                      ; was A=$FF?\n");
        out.push_str("    BNE SDCP_SKIP_PATH        ; A was not $00 or $FF → way off\n");
        out.push_str("    ; A was $FF: valid if B >= $80 (negative signed byte)\n");
        out.push_str("    CMPB #$80\n");
        out.push_str("    BHS SDCP_ABS_OK\n");
        out.push_str("    BRA SDCP_SKIP_PATH\n");
        out.push_str("SDCP_CHECK_POS:\n");
        out.push_str("    ; A=$00: valid if B <= $7F\n");
        out.push_str("    CMPB #$7F\n");
        out.push_str("    BLS SDCP_ABS_OK\n");
        out.push_str("SDCP_SKIP_PATH:\n");
        out.push_str("    RTS\n");
        out.push_str("SDCP_ABS_OK:\n");
        out.push_str("    ; B = abs_x (valid signed byte)\n");
        out.push_str("    TFR B,A                  ; A = abs_x for moveto\n");
        out.push_str("    STA >SLR_CUR_X          ; init beam-x tracker\n");
        // --- VIA Reset0Ref (inline, same as DSWM lines 964-976) ---
        out.push_str("    CLR VIA_shift_reg\n");
        out.push_str("    LDA #$CC\n");
        out.push_str("    STA VIA_cntl\n");
        out.push_str("    CLR VIA_port_a\n");
        out.push_str("    LDA #$03\n");
        out.push_str("    STA VIA_port_b\n");
        out.push_str("    LDA #$02\n");
        out.push_str("    STA VIA_port_b\n");
        out.push_str("    LDA #$02\n");
        out.push_str("    STA VIA_port_b\n");
        out.push_str("    LDA #$01\n");
        out.push_str("    STA VIA_port_b\n");
        // --- VIA Moveto abs position (B=abs_y, A=abs_x) ---
        out.push_str("    LDB >TMPVAL             ; B = abs_y\n");
        out.push_str("    STB VIA_port_a          ; DY → DAC (PB=1: hold)\n");
        out.push_str("    CLR VIA_port_b          ; PB=0: enable mux, beam tracks Y\n");
        out.push_str("    LDA >SLR_CUR_X          ; abs_x (load = settling for Y)\n");
        out.push_str("    PSHS A                  ; ~4 more settling cycles\n");
        out.push_str("    LDA #$CE\n");
        out.push_str("    STA VIA_cntl            ; PCR=$CE: /ZERO high\n");
        out.push_str("    CLR VIA_shift_reg       ; SR=0: beam off\n");
        out.push_str("    INC VIA_port_b          ; PB=1: lock Y direction\n");
        out.push_str("    PULS A                  ; restore abs_x\n");
        out.push_str("    STA VIA_port_a          ; DX → DAC\n");
        out.push_str("    LDA >DRAW_T1_SCALED     ; effective T1 for this object (scale * 127)\n");
        out.push_str("    STA VIA_t1_cnt_lo       ; load T1 latch\n");
        out.push_str("    LEAX 2,X                ; skip next_y, next_x (the 0,0)\n");
        out.push_str("    CLR VIA_t1_cnt_hi       ; start T1 → ramp\n");
        out.push_str("SDCP_MOVETO_W:\n");
        out.push_str("    LDA VIA_int_flags\n");
        out.push_str("    ANDA #$40\n");
        out.push_str("    BEQ SDCP_MOVETO_W\n");
        out.push_str("    ; PB=1 on exit — draw loop ready\n");
        // --- Segment loop ---
        out.push_str("SDCP_SEG_LOOP:\n");
        out.push_str("    LDA ,X+                 ; flags\n");
        out.push_str("    CMPA #2\n");
        out.push_str("    BEQ SDCP_DONE\n");
        out.push_str("    ; Read dy → B, dx → A (DSWM order)\n");
        out.push_str("    LDB ,X+                 ; B = dy\n");
        out.push_str("    LDA ,X+                 ; A = dx\n");
        out.push_str("    ; --- X-axis clip check: new_x = cur_x + dx ---\n");
        out.push_str("    STB >TMPPTR2            ; save dy\n");
        out.push_str("    PSHS A                  ; push dx\n");
        out.push_str("    LDA >SLR_CUR_X\n");
        out.push_str("    ADDA ,S                 ; A = cur_x + dx; V set on overflow\n");
        out.push_str("    BVS SDCP_CLIP           ; overflow → clip\n");
        out.push_str("    STA >SLR_CUR_X          ; update tracker\n");
        out.push_str("    PULS A                  ; restore dx\n");
        out.push_str("    LDB >TMPPTR2            ; restore dy\n");
        // --- Draw segment (beam ON) — same as DSWM_LOOP ---
        out.push_str("    STB VIA_port_a          ; DY → DAC (PB=1: hold)\n");
        out.push_str("    CLR VIA_port_b          ; PB=0: mux for DY\n");
        out.push_str("    NOP\n");
        out.push_str("    NOP\n");
        out.push_str("    NOP\n");
        out.push_str("    INC VIA_port_b          ; PB=1: lock DY\n");
        out.push_str("    STA VIA_port_a          ; DX → DAC\n");
        out.push_str("    LDA #$FF\n");
        out.push_str("    STA VIA_shift_reg       ; beam ON\n");
        out.push_str("    CLR VIA_t1_cnt_hi       ; start T1\n");
        out.push_str("SDCP_W_DRAW:\n");
        out.push_str("    LDA VIA_int_flags\n");
        out.push_str("    ANDA #$40\n");
        out.push_str("    BEQ SDCP_W_DRAW\n");
        out.push_str("    CLR VIA_shift_reg       ; beam OFF\n");
        out.push_str("    BRA SDCP_SEG_LOOP\n");
        // --- Clip: beam OFF move (same ramp, no beam) ---
        out.push_str("SDCP_CLIP:\n");
        out.push_str("    STA >SLR_CUR_X          ; store wrapped x (approx)\n");
        out.push_str("    PULS A                  ; restore dx\n");
        out.push_str("    LDB >TMPPTR2            ; restore dy\n");
        out.push_str("    STB VIA_port_a          ; DY → DAC\n");
        out.push_str("    CLR VIA_port_b\n");
        out.push_str("    NOP\n");
        out.push_str("    NOP\n");
        out.push_str("    NOP\n");
        out.push_str("    INC VIA_port_b\n");
        out.push_str("    STA VIA_port_a          ; DX → DAC\n");
        out.push_str("    ; beam stays OFF (no STA VIA_shift_reg)\n");
        out.push_str("    CLR VIA_t1_cnt_hi       ; start T1 (ramp, beam off)\n");
        out.push_str("SDCP_W_MOVE:\n");
        out.push_str("    LDA VIA_int_flags\n");
        out.push_str("    ANDA #$40\n");
        out.push_str("    BEQ SDCP_W_MOVE\n");
        out.push_str("    BRA SDCP_SEG_LOOP\n");
        out.push_str("SDCP_DONE:\n");
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
        if crate::m6809::builtins::use_banked_assets() {
            out.push_str("    ; MULTIBANK: Switch to level bank so FG ROM pointers are valid\n");
            out.push_str("    LDA >CURRENT_ROM_BANK\n");
            out.push_str("    PSHS A              ; Save current bank\n");
            out.push_str("    LDA >LEVEL_BANK\n");
            out.push_str("    STA >CURRENT_ROM_BANK\n");
            out.push_str("    STA $DF00           ; Switch to level bank\n");
        }
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
        if crate::m6809::builtins::use_banked_assets() {
            out.push_str("    ; MULTIBANK: Restore original bank\n");
            out.push_str("    PULS A              ; A = saved bank\n");
            out.push_str("    STA >CURRENT_ROM_BANK\n");
            out.push_str("    STA $DF00           ; Restore bank\n");
        }
        out.push_str("    PULS D,Y,X,U     ; Restore registers\n");
        out.push_str("    RTS\n");
        out.push_str("\n");

        // ---- ULR_UPDATE_LAYER ----
        out.push_str("; === ULR_UPDATE_LAYER - Apply physics to each object in GP buffer ===\n");
        out.push_str("; Input: B = object count, U = buffer base (15 bytes/object)\n");
        out.push_str("; RAM object layout:\n");
        out.push_str(";   +0-1: world_x(i16)  +2: y(i8)  +3: scale  +4: rotation\n");
        out.push_str(";   +5: velocity_x  +6: velocity_y  +7: physics_flags  +8: collision_flags\n");
        out.push_str(";   +9: collision_size  +10: spawn_delay_lo  +11-12: vector_ptr  +13-14: props_ptr\n");
        out.push_str("ULR_UPDATE_LAYER:\n");
        out.push_str("    TST >LEVEL_LOADED\n");
        out.push_str("    LBEQ ULR_LAYER_EXIT  ; No level loaded, skip\n");
        out.push_str("    LDX >LEVEL_PTR   ; Load level pointer for world bounds\n");
        out.push_str("    \n");
        out.push_str("ULR_LOOP:\n");
        out.push_str("    PSHS B           ; Save loop counter\n");
        out.push_str("    \n");
        out.push_str("    ; Check physics_flags (RAM +7)\n");
        out.push_str("    LDB 7,U\n");
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
        out.push_str("    LDB 6,U          ; velocity_y (RAM +6)\n");
        out.push_str("    DECB\n");
        out.push_str("    CMPB #$F1        ; -15\n");
        out.push_str("    BGE ULR_VY_OK\n");
        out.push_str("    LDB #$F1\n");
        out.push_str("ULR_VY_OK:\n");
        out.push_str("    STB 6,U\n");
        out.push_str("    \n");
        out.push_str("ULR_NO_GRAVITY:\n");
        out.push_str("    ; Apply velocity: world_x += velocity_x (16-bit)\n");
        out.push_str("    LDD 0,U          ; world_x (16-bit signed)\n");
        out.push_str("    TFR D,Y          ; Y = world_x\n");
        out.push_str("    LDB 5,U          ; velocity_x (8-bit signed)\n");
        out.push_str("    SEX              ; D = sign-extended velocity_x\n");
        out.push_str("    LEAY D,Y         ; Y = world_x + velocity_x (16-bit addition)\n");
        out.push_str("    TFR Y,D          ; D = new world_x\n");
        out.push_str("    STD 0,U          ; Store 16-bit world_x\n");
        out.push_str("    \n");
        out.push_str("    ; Apply velocity: y += velocity_y (16-bit to avoid wraparound)\n");
        out.push_str("    LDB 2,U          ; y (8-bit signed, RAM +2)\n");
        out.push_str("    SEX              ; D = sign-extended y\n");
        out.push_str("    TFR D,Y          ; Y = y (16-bit)\n");
        out.push_str("    LDB 6,U          ; velocity_y (8-bit signed, RAM +6)\n");
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
        out.push_str("    STB 2,U          ; Store clamped y (RAM +2)\n");
        out.push_str("    \n");
        out.push_str("    ; === World Bounds / Wall Bounce ===\n");
        out.push_str("    LDB 8,U          ; collision_flags (RAM +8)\n");
        out.push_str("    BITB #$02        ; bounce_walls flag (bit 1)\n");
        out.push_str("    LBEQ ULR_NEXT    ; Skip if not bouncing\n");
        out.push_str("    \n");
        out.push_str("    ; LDX already loaded = LEVEL_PTR\n");
        out.push_str("    ; World bounds at LEVEL_PTR: +0=xMin(FDB), +2=xMax(FDB), +4=yMin(FDB), +6=yMax(FDB)\n");
        out.push_str("    \n");
        out.push_str("    ; --- Check X left wall (xMin) ---\n");
        out.push_str("    LDB 9,U          ; collision_size (RAM +9)\n");
        out.push_str("    SEX              ; D = sign-extended collision_size\n");
        out.push_str("    PSHS D           ; Save collision_size\n");
        out.push_str("    LDD 0,U          ; world_x (16-bit)\n");
        out.push_str("    SUBD ,S++        ; D = world_x - collision_size (left edge), pop\n");
        out.push_str("    CMPD 0,X         ; Compare with xMin\n");
        out.push_str("    LBGE ULR_X_MAX_CHECK\n");
        out.push_str("    ; Hit left wall — bounce only if moving left (velocity_x < 0)\n");
        out.push_str("    LDB 5,U\n");
        out.push_str("    CMPB #0\n");
        out.push_str("    LBGE ULR_X_MAX_CHECK\n");
        out.push_str("    LDB 9,U          ; collision_size\n");
        out.push_str("    SEX\n");
        out.push_str("    ADDD 0,X         ; D = xMin + collision_size\n");
        out.push_str("    STD 0,U          ; world_x = corrected position (16-bit)\n");
        out.push_str("    LDB 5,U\n");
        out.push_str("    NEGB\n");
        out.push_str("    STB 5,U          ; velocity_x = -velocity_x\n");
        out.push_str("    \n");
        out.push_str("    ; --- Check X right wall (xMax) ---\n");
        out.push_str("ULR_X_MAX_CHECK:\n");
        out.push_str("    LDB 9,U\n");
        out.push_str("    SEX\n");
        out.push_str("    PSHS D\n");
        out.push_str("    LDD 0,U          ; world_x (16-bit)\n");
        out.push_str("    ADDD ,S++        ; D = world_x + collision_size (right edge), pop\n");
        out.push_str("    CMPD 2,X         ; Compare with xMax\n");
        out.push_str("    LBLE ULR_Y_BOUNDS\n");
        out.push_str("    ; Hit right wall — bounce only if moving right (velocity_x > 0)\n");
        out.push_str("    LDB 5,U\n");
        out.push_str("    CMPB #0\n");
        out.push_str("    LBLE ULR_Y_BOUNDS\n");
        out.push_str("    LDB 9,U\n");
        out.push_str("    SEX\n");
        out.push_str("    TFR D,Y\n");
        out.push_str("    LDD 2,X          ; D = xMax\n");
        out.push_str("    PSHS Y\n");
        out.push_str("    SUBD ,S++        ; D = xMax - collision_size, pop\n");
        out.push_str("    STD 0,U          ; world_x = corrected position (16-bit)\n");
        out.push_str("    LDB 5,U\n");
        out.push_str("    NEGB\n");
        out.push_str("    STB 5,U\n");
        out.push_str("    \n");
        out.push_str("    ; --- Check Y bottom wall (yMin) ---\n");
        out.push_str("ULR_Y_BOUNDS:\n");
        out.push_str("    LDB 9,U\n");
        out.push_str("    SEX\n");
        out.push_str("    PSHS D\n");
        out.push_str("    LDB 2,U          ; y (8-bit, RAM +2)\n");
        out.push_str("    SEX\n");
        out.push_str("    SUBD ,S++        ; D = y - collision_size, pop\n");
        out.push_str("    CMPD 4,X         ; Compare with yMin\n");
        out.push_str("    LBGE ULR_Y_MAX_CHECK\n");
        out.push_str("    LDB 6,U\n");
        out.push_str("    CMPB #0\n");
        out.push_str("    LBGE ULR_Y_MAX_CHECK\n");
        out.push_str("    LDB 9,U\n");
        out.push_str("    SEX\n");
        out.push_str("    ADDD 4,X         ; D = yMin + collision_size\n");
        out.push_str("    STB 2,U          ; y = low byte (RAM +2)\n");
        out.push_str("    LDB 6,U\n");
        out.push_str("    NEGB\n");
        out.push_str("    STB 6,U\n");
        out.push_str("    \n");
        out.push_str("    ; --- Check Y top wall (yMax) ---\n");
        out.push_str("ULR_Y_MAX_CHECK:\n");
        out.push_str("    LDB 9,U\n");
        out.push_str("    SEX\n");
        out.push_str("    PSHS D\n");
        out.push_str("    LDB 2,U          ; y (8-bit, RAM +2)\n");
        out.push_str("    SEX\n");
        out.push_str("    ADDD ,S++        ; D = y + collision_size, pop\n");
        out.push_str("    CMPD 6,X         ; Compare with yMax\n");
        out.push_str("    LBLE ULR_NEXT\n");
        out.push_str("    LDB 6,U\n");
        out.push_str("    CMPB #0\n");
        out.push_str("    LBLE ULR_NEXT\n");
        out.push_str("    LDB 9,U\n");
        out.push_str("    SEX\n");
        out.push_str("    TFR D,Y\n");
        out.push_str("    LDD 6,X          ; D = yMax\n");
        out.push_str("    PSHS Y\n");
        out.push_str("    SUBD ,S++        ; D = yMax - collision_size, pop\n");
        out.push_str("    STB 2,U          ; y = low byte (RAM +2)\n");
        out.push_str("    LDB 6,U\n");
        out.push_str("    NEGB\n");
        out.push_str("    STB 6,U\n");
        out.push_str("    \n");
        out.push_str("ULR_NEXT:\n");
        out.push_str("    PULS B           ; Restore loop counter\n");
        out.push_str("    LEAU 15,U        ; Next object (15 bytes)\n");
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
        out.push_str("    ; U = LEVEL_GP_BUFFER + (UGPC_OUTER_IDX * 15)\n");
        out.push_str("    LDU #LEVEL_GP_BUFFER\n");
        out.push_str("    LDB UGPC_OUTER_IDX\n");
        out.push_str("    BEQ UGPC_SKIP_OUTER_MUL\n");
        out.push_str("UGPC_OUTER_MUL:\n");
        out.push_str("    LEAU 15,U\n");
        out.push_str("    DECB\n");
        out.push_str("    BNE UGPC_OUTER_MUL\n");
        out.push_str("UGPC_SKIP_OUTER_MUL:\n");
        out.push_str("    ; Check if outer object is collidable (collision_flags bit 0 at RAM +8)\n");
        out.push_str("    LDB 8,U\n");
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
        out.push_str("    ; Y = LEVEL_GP_BUFFER + (UGPC_INNER_IDX * 15)\n");
        out.push_str("    LDY #LEVEL_GP_BUFFER\n");
        out.push_str("    LDB UGPC_INNER_IDX\n");
        out.push_str("    BEQ UGPC_SKIP_INNER_MUL\n");
        out.push_str("UGPC_INNER_MUL:\n");
        out.push_str("    LEAY 15,Y\n");
        out.push_str("    DECB\n");
        out.push_str("    BNE UGPC_INNER_MUL\n");
        out.push_str("UGPC_SKIP_INNER_MUL:\n");
        out.push_str("    ; Check inner collidable (RAM +8)\n");
        out.push_str("    LDB 8,Y\n");
        out.push_str("    BITB #$01\n");
        out.push_str("    LBEQ UGPC_NEXT_INNER\n");
        out.push_str("    \n");
        out.push_str("    ; Manhattan distance: |x1-x2| + |y1-y2|\n");
        out.push_str("    ; Use low byte of world_x (RAM +1) for approximate screen-relative collision\n");
        out.push_str("    ; Compute |dx| = |x1 - x2|\n");
        out.push_str("    LDB 1,U          ; x1 low byte (8-bit at RAM +1)\n");
        out.push_str("    SEX\n");
        out.push_str("    PSHS D           ; Save x1 (16-bit)\n");
        out.push_str("    LDB 1,Y          ; x2 low byte (8-bit at RAM +1)\n");
        out.push_str("    SEX\n");
        out.push_str("    TFR D,X\n");
        out.push_str("    PULS D           ; D = x1\n");
        out.push_str("    PSHS X\n");
        out.push_str("    TFR X,D          ; D = x2\n");
        out.push_str("    PULS X\n");
        out.push_str("    PSHS D           ; Push x2\n");
        out.push_str("    LDB 1,U\n");
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
        out.push_str("    LDB 2,U          ; y1 (8-bit at RAM +2)\n");
        out.push_str("    SEX\n");
        out.push_str("    PSHS D\n");
        out.push_str("    LDB 2,Y          ; y2 (8-bit at RAM +2)\n");
        out.push_str("    SEX\n");
        out.push_str("    TFR D,X\n");
        out.push_str("    PULS D\n");
        out.push_str("    PSHS X\n");
        out.push_str("    TFR X,D\n");
        out.push_str("    PULS X\n");
        out.push_str("    PSHS D           ; Push y2\n");
        out.push_str("    LDB 2,U\n");
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
        out.push_str("    LDB 9,U          ; collision_size obj1 (RAM +9)\n");
        out.push_str("    ADDB 9,Y         ; + collision_size obj2\n");
        out.push_str("    SEX              ; D = sum_radius\n");
        out.push_str("    CMPD UGPC_DIST\n");
        out.push_str("    LBHI UGPC_COLLISION\n");
        out.push_str("    LBRA UGPC_NEXT_INNER\n");
        out.push_str("    \n");
        out.push_str("UGPC_COLLISION:\n");
        out.push_str("    ; Elastic collision: swap velocities\n");
        out.push_str("    LDA 5,U          ; vel_x obj1 (RAM +5)\n");
        out.push_str("    LDB 5,Y          ; vel_x obj2 (RAM +5)\n");
        out.push_str("    STB 5,U\n");
        out.push_str("    STA 5,Y\n");
        out.push_str("    LDA 6,U          ; vel_y obj1 (RAM +6)\n");
        out.push_str("    LDB 6,Y          ; vel_y obj2 (RAM +6)\n");
        out.push_str("    STB 6,U\n");
        out.push_str("    STA 6,Y\n");
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
        out.push_str("    ; U = LEVEL_GP_BUFFER + (UGFC_GP_IDX * 15)\n");
        out.push_str("    LDU #LEVEL_GP_BUFFER\n");
        out.push_str("    LDB UGFC_GP_IDX\n");
        out.push_str("    BEQ UGFC_GP_ADDR_DONE\n");
        out.push_str("UGFC_GP_MUL:\n");
        out.push_str("    LEAU 15,U\n");
        out.push_str("    DECB\n");
        out.push_str("    BNE UGFC_GP_MUL\n");
        out.push_str("UGFC_GP_ADDR_DONE:\n");
        out.push_str("    ; Check GP collidable (collision_flags bit 0 at RAM +8)\n");
        out.push_str("    LDB 8,U\n");
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
        out.push_str("    ; |dx| = |GP.x_lo - FG.x_lo|  (GP RAM +1, FG ROM +2)\n");
        out.push_str("    LDA 1,U          ; GP x low byte (RAM +1, world_x low byte)\n");
        out.push_str("    SUBA 2,X         ; A = GP.x_lo - FG.x_lo\n");
        out.push_str("    BPL UGFC_DX_POS\n");
        out.push_str("    NEGA\n");
        out.push_str("UGFC_DX_POS:\n");
        out.push_str("    STA UGFC_DX\n");
        out.push_str("    \n");
        out.push_str("    ; |dy| = |GP.y - FG.y_lo|  (GP RAM +2, FG ROM +4)\n");
        out.push_str("    LDA 2,U          ; GP y (RAM +2)\n");
        out.push_str("    SUBA 4,X         ; A = GP.y - FG.y_lo\n");
        out.push_str("    BPL UGFC_DY_POS\n");
        out.push_str("    NEGA\n");
        out.push_str("UGFC_DY_POS:\n");
        out.push_str("    STA UGFC_DY\n");
        out.push_str("    \n");
        out.push_str("    ; sum_r = GP.collision_size + FG.collision_size\n");
        out.push_str("    LDA 9,U          ; GP collision_size (RAM +9)\n");
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
        out.push_str("    LDA 6,U          ; velocity_y (RAM +6)\n");
        out.push_str("    BPL UGFC_VY_ABS\n");
        out.push_str("    NEGA\n");
        out.push_str("UGFC_VY_ABS:\n");
        out.push_str("    STA UGFC_DY      ; |vy|\n");
        out.push_str("    LDA 5,U          ; velocity_x (RAM +5)\n");
        out.push_str("    BPL UGFC_VX_ABS\n");
        out.push_str("    NEGA\n");
        out.push_str("UGFC_VX_ABS:\n");
        out.push_str("    CMPA UGFC_DY     ; |vx| vs |vy|\n");
        out.push_str("    BLT UGFC_VERT_BOUNCE ; |vx| < |vy| → vert bounce\n");
        out.push_str("    \n");
        out.push_str("UGFC_HORIZ_BOUNCE:\n");
        out.push_str("    LDA 5,U          ; velocity_x (RAM +5)\n");
        out.push_str("    NEGA\n");
        out.push_str("    STA 5,U\n");
        out.push_str("    LDA 9,U          ; collision_size (RAM +9)\n");
        out.push_str("    ADDA 13,X\n");
        out.push_str("    PSHS A           ; Save separation\n");
        out.push_str("    LDA 1,U          ; x low byte (RAM +1)\n");
        out.push_str("    CMPA 2,X\n");
        out.push_str("    BLT UGFC_PUSH_LEFT\n");
        out.push_str("    LDA 2,X\n");
        out.push_str("    ADDA ,S+\n");
        out.push_str("    STA 1,U          ; store back x low byte (RAM +1)\n");
        out.push_str("    BRA UGFC_NEXT_FG\n");
        out.push_str("UGFC_PUSH_LEFT:\n");
        out.push_str("    LDA 2,X\n");
        out.push_str("    SUBA ,S+\n");
        out.push_str("    STA 1,U          ; store back x low byte (RAM +1)\n");
        out.push_str("    BRA UGFC_NEXT_FG\n");
        out.push_str("    \n");
        out.push_str("UGFC_VERT_BOUNCE:\n");
        out.push_str("    LDA 6,U          ; velocity_y (RAM +6)\n");
        out.push_str("    NEGA\n");
        out.push_str("    STA 6,U\n");
        out.push_str("    LDA 9,U          ; collision_size (RAM +9)\n");
        out.push_str("    ADDA 13,X\n");
        out.push_str("    PSHS A\n");
        out.push_str("    LDA 2,U          ; y (RAM +2)\n");
        out.push_str("    CMPA 4,X\n");
        out.push_str("    BLT UGFC_PUSH_DOWN\n");
        out.push_str("    LDA 4,X\n");
        out.push_str("    ADDA ,S+\n");
        out.push_str("    STA 2,U          ; store back y (RAM +2)\n");
        out.push_str("    BRA UGFC_NEXT_FG\n");
        out.push_str("UGFC_PUSH_DOWN:\n");
        out.push_str("    LDA 4,X\n");
        out.push_str("    SUBA ,S+\n");
        out.push_str("    STA 2,U          ; store back y (RAM +2)\n");
        out.push_str("    \n");
        out.push_str("UGFC_NEXT_FG:\n");
        out.push_str("    LEAX 23,X        ; Next FG object (ROM stride 23)\n");
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

    // =========================================================================
    // LEVEL_COLLISION_Y_RUNTIME
    // =========================================================================
    if needed.contains("LEVEL_COLLISION_Y_RUNTIME") {
        out.push_str("; === LEVEL_COLLISION_Y_RUNTIME ===\n");
        out.push_str("; Find the highest collidable floor Y at player_x in the GP layer.\n");
        out.push_str("; Input:  LCOL_PX (16-bit) = player world_x\n");
        out.push_str(";         LCOL_PY (16-bit) = player_feet (player_y - player_hh)\n");
        out.push_str("; Output: RESULT = highest floor landing Y (i16)\n");
        out.push_str(";         Returns $FF80 (-128) if no collidable surface found at that X.\n");
        out.push_str("; Algorithm: for each collidable GP object, check X AABB overlap,\n");
        out.push_str(";   compute surface_top = obj_y(16) + half_height, track max (16-bit).\n");
        out.push_str("; ROM object offsets (stride-21): +0=type, +1-2=x(FDB), +3-4=y(FDB), +12=collision_flags,\n");
        out.push_str(";   +16=vector_bank, +17-18=vector_ptr, +19=half_width, +20=half_height. Stride=21.\n");
        out.push_str("LEVEL_COLLISION_Y_RUNTIME:\n");
        out.push_str("    PSHS X,Y,U       ; Save regs (NOT D - result returns in D)\n");
        if crate::m6809::builtins::use_banked_assets() {
            out.push_str("    ; MULTIBANK: Switch to level bank so ROM GP pointer dereferences land in the right bank\n");
            out.push_str("    LDA >CURRENT_ROM_BANK\n");
            out.push_str("    PSHS A              ; Save current bank\n");
            out.push_str("    LDA >LEVEL_BANK\n");
            out.push_str("    STA >CURRENT_ROM_BANK\n");
            out.push_str("    STA $DF00           ; Switch to level bank\n");
        }
        out.push_str("    \n");
        out.push_str("    ; Initialize best_floor = -32768 ($8000, no floor found)\n");
        out.push_str("    LDD #$8000\n");
        out.push_str("    STD >LCOL_BEST_Y\n");
        out.push_str("    \n");
        out.push_str("    ; Check level loaded\n");
        out.push_str("    TST >LEVEL_LOADED\n");
        out.push_str("    LBEQ LCOL_Y_DONE\n");
        out.push_str("    \n");
        out.push_str("    LDB >LEVEL_GP_COUNT\n");
        out.push_str("    LBEQ LCOL_Y_DONE\n");
        out.push_str("    STB >LCOL_OBJ_CNT  ; GP objects remaining\n");
        out.push_str("    LDX >LEVEL_GP_PTR  ; X = ROM GP objects\n");
        out.push_str("    \n");
        out.push_str("LCOL_Y_LOOP:\n");
        out.push_str("    ; --- collision flag (bit 0 at ROM+12) ---\n");
        out.push_str("    LDA 12,X\n");
        out.push_str("    BITA #$01\n");
        out.push_str("    LBEQ LCOL_Y_NEXT  ; not collidable\n");
        out.push_str("    ; --- broadphase X: obj_x - hw <= player_x <= obj_x + hw ---\n");
        out.push_str("    LDD 1,X          ; obj_x FDB (ROM+1)\n");
        out.push_str("    SUBB 19,X        ; - half_width (ROM+19)\n");
        out.push_str("    SBCA #0\n");
        out.push_str("    STD >TMPVAL      ; left_edge\n");
        out.push_str("    LDD >LCOL_PX\n");
        out.push_str("    CMPD >TMPVAL\n");
        out.push_str("    LBLT LCOL_Y_NEXT ; player_x < left_edge\n");
        out.push_str("    LDD 1,X\n");
        out.push_str("    ADDB 19,X        ; + half_width\n");
        out.push_str("    ADCA #0\n");
        out.push_str("    STD >TMPVAL      ; right_edge\n");
        out.push_str("    LDD >LCOL_PX\n");
        out.push_str("    CMPD >TMPVAL\n");
        out.push_str("    LBGT LCOL_Y_NEXT ; player_x > right_edge\n");
        out.push_str("    \n");
        out.push_str("    ; --- X overlaps. Ray-cast mesh if coll_mesh_ptr(ROM+21) != 0, else AABB ---\n");
        out.push_str("    LDD 21,X         ; coll_mesh_ptr\n");
        out.push_str("    LBEQ LCOL_Y_AABB\n");
        out.push_str("    PSHS X           ; preserve object ptr across the segment walk\n");
        out.push_str("    LDD >LCOL_PX\n");
        out.push_str("    SUBD 1,X         ; local_px = player_x - obj_x\n");
        out.push_str("    STD >LCOL_LOCAL_PX\n");
        out.push_str("    LDD 3,X          ; obj world_y (ROM+3)\n");
        out.push_str("    STD >LCOL_OBJ_Y\n");
        out.push_str("    LDY 21,X         ; Y = mesh data ptr (level bank)\n");
        out.push_str("    LDB 1,Y          ; floor_count low byte (FDB at mesh+0)\n");
        out.push_str("    STB >LCOL_SEG_CNT\n");
        out.push_str("    LEAY 2,Y         ; Y -> first floor segment\n");
        out.push_str("LCOL_Y_SEG:\n");
        out.push_str("    LDB >LCOL_SEG_CNT\n");
        out.push_str("    BEQ LCOL_Y_SEG_DONE\n");
        out.push_str("    ; floor segment: x1=,Y y1=2,Y x2=4,Y (y2=6,Y unused; y1==y2)\n");
        out.push_str("    LDD >LCOL_LOCAL_PX\n");
        out.push_str("    CMPD ,Y          ; local_px vs x1\n");
        out.push_str("    BLT LCOL_Y_SEG_ADV ; local_px < x1 → off this segment\n");
        out.push_str("    LDD >LCOL_LOCAL_PX\n");
        out.push_str("    CMPD 4,Y         ; local_px vs x2\n");
        out.push_str("    BGT LCOL_Y_SEG_ADV ; local_px > x2 → off this segment\n");
        out.push_str("    LDD 2,Y          ; y1 (local)\n");
        out.push_str("    ADDD >LCOL_OBJ_Y ; world_seg_y = y1 + obj_world_y\n");
        out.push_str("    CMPD >LCOL_PY    ; vs player_feet\n");
        out.push_str("    BGT LCOL_Y_SEG_ADV ; above feet → skip\n");
        out.push_str("    CMPD >LCOL_BEST_Y\n");
        out.push_str("    BLE LCOL_Y_SEG_ADV ; not higher than best\n");
        out.push_str("    STD >LCOL_BEST_Y ; new best floor top\n");
        out.push_str("LCOL_Y_SEG_ADV:\n");
        out.push_str("    LEAY 8,Y         ; next floor segment (4 FDB)\n");
        out.push_str("    DEC >LCOL_SEG_CNT\n");
        out.push_str("    BRA LCOL_Y_SEG\n");
        out.push_str("LCOL_Y_SEG_DONE:\n");
        out.push_str("    PULS X           ; restore object ptr\n");
        out.push_str("    BRA LCOL_Y_NEXT\n");
        out.push_str("    \n");
        out.push_str("LCOL_Y_AABB:\n");
        out.push_str("    ; AABB fallback: surface_top = obj_y(ROM+3) + half_height(ROM+20)\n");
        out.push_str("    LDD 3,X\n");
        out.push_str("    ADDB 20,X\n");
        out.push_str("    ADCA #0\n");
        out.push_str("    CMPD >LCOL_PY    ; vs player_feet\n");
        out.push_str("    BGT LCOL_Y_NEXT  ; above feet → skip\n");
        out.push_str("    CMPD >LCOL_BEST_Y\n");
        out.push_str("    BLE LCOL_Y_NEXT  ; not higher\n");
        out.push_str("    STD >LCOL_BEST_Y\n");
        out.push_str("    \n");
        out.push_str("LCOL_Y_NEXT:\n");
        out.push_str("    LEAX 23,X        ; next ROM object (stride 23)\n");
        out.push_str("    DEC >LCOL_OBJ_CNT\n");
        out.push_str("    LBNE LCOL_Y_LOOP\n");
        out.push_str("    \n");
        out.push_str("LCOL_Y_DONE:\n");
        out.push_str("    ; best holds floor_top (16-bit). Landing Y = floor_top + player_hh.\n");
        out.push_str("    LDD >LCOL_BEST_Y\n");
        out.push_str("    CMPD #$8000\n");
        out.push_str("    BEQ LCOL_Y_NOFLOOR\n");
        out.push_str("    ADDB >LCOL_PHH   ; + player_hh\n");
        out.push_str("    ADCA #0\n");
        out.push_str("    BRA LCOL_Y_RET\n");
        out.push_str("LCOL_Y_NOFLOOR:\n");
        out.push_str("    LDD #$FF80       ; -128 (no floor found)\n");
        out.push_str("LCOL_Y_RET:\n");
        out.push_str("    STD RESULT\n");
        if crate::m6809::builtins::use_banked_assets() {
            out.push_str("    ; MULTIBANK: Restore original bank (result is in RESULT, will reload after)\n");
            out.push_str("    PULS A              ; A = saved bank\n");
            out.push_str("    STA >CURRENT_ROM_BANK\n");
            out.push_str("    STA $DF00           ; Restore bank\n");
            out.push_str("    LDD RESULT          ; Reload return value into D\n");
        }
        out.push_str("    \n");
        out.push_str("    PULS X,Y,U,PC    ; Restore (NOT D - result stays in D)\n");
        out.push_str("\n");
    }

    // =========================================================================
    // LEVEL_COLLISION_X_RUNTIME
    // =========================================================================
    if needed.contains("LEVEL_COLLISION_X_RUNTIME") {
        out.push_str("; === LEVEL_COLLISION_X_RUNTIME ===\n");
        out.push_str("; Find first collidable GP object overlapping player horizontally.\n");
        out.push_str("; Input:  LCOL_PX (16-bit) = player world_x\n");
        out.push_str(";         LCOL_PY (16-bit) = player world_y\n");
        out.push_str(";         LCOL_PHW (u8) = player half_width\n");
        out.push_str("; Output: RESULT = signed push-out dx (16-bit). Positive=right, negative=left.\n");
        out.push_str("; Returns 0 if no overlap found.\n");
        out.push_str("; Scratch: uses LCOL_THW for total_hw (preserves LCOL_PHH=player_hh across iterations).\n");
        out.push_str("; ROM object offsets (stride-21): +0=type, +1-2=x(FDB), +3-4=y(FDB), +12=collision_flags,\n");
        out.push_str(";   +16=vector_bank, +17-18=vector_ptr, +19=half_width, +20=half_height. Stride=21.\n");
        out.push_str("LEVEL_COLLISION_X_RUNTIME:\n");
        out.push_str("    PSHS X,Y,U\n");
        if crate::m6809::builtins::use_banked_assets() {
            out.push_str("    ; MULTIBANK: Switch to level bank so ROM GP pointer dereferences land in the right bank\n");
            out.push_str("    LDA >CURRENT_ROM_BANK\n");
            out.push_str("    PSHS A              ; Save current bank\n");
            out.push_str("    LDA >LEVEL_BANK\n");
            out.push_str("    STA >CURRENT_ROM_BANK\n");
            out.push_str("    STA $DF00           ; Switch to level bank\n");
        }
        out.push_str("    LDD #0\n");
        out.push_str("    STD RESULT\n");
        out.push_str("    TST >LEVEL_LOADED\n");
        out.push_str("    LBEQ LCOL_X_DONE\n");
        out.push_str("    LDB >LEVEL_GP_COUNT\n");
        out.push_str("    LBEQ LCOL_X_DONE\n");
        out.push_str("    STB >LCOL_OBJ_CNT  ; GP objects remaining\n");
        out.push_str("    LDX >LEVEL_GP_PTR\n");
        out.push_str("LCOL_X_LOOP:\n");
        out.push_str("    ; collision flag (bit 0 at ROM+12)\n");
        out.push_str("    LDA 12,X\n");
        out.push_str("    BITA #$01\n");
        out.push_str("    LBEQ LCOL_X_NEXT\n");
        out.push_str("    ; coll_mesh_ptr (ROM+21); 0 = floor-only, no walls → no horizontal push\n");
        out.push_str("    LDD 21,X\n");
        out.push_str("    LBEQ LCOL_X_NEXT\n");
        out.push_str("    ; cache obj_x / obj_y for local→world conversion (X stays = obj ptr)\n");
        out.push_str("    LDD 1,X\n");
        out.push_str("    STD >LCOL_LOCAL_PX  ; reuse scratch as obj_x\n");
        out.push_str("    LDD 3,X\n");
        out.push_str("    STD >LCOL_OBJ_Y     ; obj_y\n");
        out.push_str("    ; navigate mesh: skip floor section to reach wall_count\n");
        out.push_str("    LDD 21,X\n");
        out.push_str("    TFR D,Y             ; Y = mesh ptr\n");
        out.push_str("    LDD ,Y              ; floor_count (FDB)\n");
        out.push_str("    ASLB\n");
        out.push_str("    ROLA\n");
        out.push_str("    ASLB\n");
        out.push_str("    ROLA\n");
        out.push_str("    ASLB\n");
        out.push_str("    ROLA               ; D = floor_count * 8 (bytes per floor seg)\n");
        out.push_str("    ADDD #2            ; + the floor_count word itself\n");
        out.push_str("    LEAY D,Y           ; Y -> wall_count\n");
        out.push_str("    LDD ,Y             ; wall_count (FDB)\n");
        out.push_str("    STB >LCOL_SEG_CNT  ; low byte (walls are few)\n");
        out.push_str("    LBEQ LCOL_X_NEXT   ; no walls\n");
        out.push_str("    LEAY 2,Y           ; Y -> first wall segment\n");
        out.push_str("LCOL_X_WALL:\n");
        out.push_str("    LDB >LCOL_SEG_CNT\n");
        out.push_str("    LBEQ LCOL_X_NEXT\n");
        out.push_str("    ; wall segment: x=,Y ymin=2,Y ymax=6,Y (local coords)\n");
        out.push_str("    LDD ,Y\n");
        out.push_str("    ADDD >LCOL_LOCAL_PX ; world_wall_x = x + obj_x\n");
        out.push_str("    STD >TMPVAL         ; TMPVAL = world_wall_x\n");
        out.push_str("    ; Y-overlap lower bound: skip if py <= world_y_min - player_hh\n");
        out.push_str("    LDD 2,Y\n");
        out.push_str("    ADDD >LCOL_OBJ_Y    ; world_y_min\n");
        out.push_str("    SUBB >LCOL_PHH\n");
        out.push_str("    SBCA #0             ; world_y_min - player_hh\n");
        out.push_str("    STD >TMPPTR\n");
        out.push_str("    LDD >LCOL_PY\n");
        out.push_str("    CMPD >TMPPTR\n");
        out.push_str("    LBLE LCOL_X_WALL_ADV ; py below wall\n");
        out.push_str("    ; Y-overlap upper bound: skip if py >= world_y_max + player_hh\n");
        out.push_str("    LDD 6,Y\n");
        out.push_str("    ADDD >LCOL_OBJ_Y    ; world_y_max\n");
        out.push_str("    ADDB >LCOL_PHH\n");
        out.push_str("    ADCA #0             ; world_y_max + player_hh\n");
        out.push_str("    STD >TMPPTR\n");
        out.push_str("    LDD >LCOL_PY\n");
        out.push_str("    CMPD >TMPPTR\n");
        out.push_str("    LBGE LCOL_X_WALL_ADV ; py above wall\n");
        out.push_str("    ; X-overlap: dx_raw = px - world_wall_x\n");
        out.push_str("    LDD >LCOL_PX\n");
        out.push_str("    SUBD >TMPVAL\n");
        out.push_str("    STD >TMPPTR         ; dx_raw (signed 16-bit; hi byte = sign)\n");
        out.push_str("    BPL LCOL_X_DXP\n");
        out.push_str("    COMA\n");
        out.push_str("    COMB\n");
        out.push_str("    ADDD #1             ; D = |dx_raw|\n");
        out.push_str("LCOL_X_DXP:\n");
        out.push_str("    TSTA\n");
        out.push_str("    LBNE LCOL_X_WALL_ADV ; |dx| > 255 → no overlap\n");
        out.push_str("    CMPB >LCOL_PHW\n");
        out.push_str("    LBHS LCOL_X_WALL_ADV ; |dx| >= player_hw → no overlap\n");
        out.push_str("    ; push_mag = player_hw - |dx|  (B = |dx|)\n");
        out.push_str("    LDA >LCOL_PHW\n");
        out.push_str("    PSHS B\n");
        out.push_str("    SUBA ,S+            ; A = player_hw - |dx|\n");
        out.push_str("    LDB >TMPPTR         ; B = dx_raw hi byte (sign)\n");
        out.push_str("    BMI LCOL_X_PUSH_LEFT\n");
        out.push_str("    ; push right (dx_raw >= 0): RESULT = +push_mag\n");
        out.push_str("    TFR A,B\n");
        out.push_str("    SEX\n");
        out.push_str("    STD RESULT\n");
        out.push_str("    BRA LCOL_X_WALL_ADV\n");
        out.push_str("LCOL_X_PUSH_LEFT:\n");
        out.push_str("    ; push left (dx_raw < 0): RESULT = -push_mag\n");
        out.push_str("    NEGA\n");
        out.push_str("    TFR A,B\n");
        out.push_str("    SEX\n");
        out.push_str("    STD RESULT\n");
        out.push_str("LCOL_X_WALL_ADV:\n");
        out.push_str("    LEAY 8,Y           ; next wall segment (4 FDB)\n");
        out.push_str("    DEC >LCOL_SEG_CNT\n");
        out.push_str("    LBNE LCOL_X_WALL\n");
        out.push_str("LCOL_X_NEXT:\n");
        out.push_str("    LEAX 23,X          ; next ROM object (stride 23)\n");
        out.push_str("    DEC >LCOL_OBJ_CNT\n");
        out.push_str("    LBNE LCOL_X_LOOP\n");
        out.push_str("LCOL_X_DONE:\n");
        if crate::m6809::builtins::use_banked_assets() {
            out.push_str("    ; MULTIBANK: Restore original bank\n");
            out.push_str("    PULS A              ; A = saved bank\n");
            out.push_str("    STA >CURRENT_ROM_BANK\n");
            out.push_str("    STA $DF00           ; Restore bank\n");
        }
        out.push_str("    LDD RESULT\n");   // reload result into D (PULS B in loop corrupts B)
        out.push_str("    PULS X,Y,U,PC\n");
        out.push_str("\n");
    }
}
