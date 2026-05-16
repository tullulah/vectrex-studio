//! PiTrex ARM32 expression compiler.
//!
//! Evaluates VPy expressions into Thumb2 assembly.
//! Result always ends up in r0.

use vpy_parser::{Expr, BinOp, CmpOp, LogicOp, CallInfo};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::collections::HashSet;
use std::cell::RefCell;

static COND_LABEL_CTR: AtomicUsize = AtomicUsize::new(0);

// Names of const arrays whose elements are string pointers (stride 4, ldr).
thread_local! {
    static STRING_ARRAYS: RefCell<HashSet<String>> = RefCell::new(HashSet::new());
}

/// Register which variable names hold string pointer arrays.
/// Called from emit_const_array_data before function emission.
pub fn register_string_arrays(names: HashSet<String>) {
    STRING_ARRAYS.with(|s| *s.borrow_mut() = names);
}

fn is_string_array(var_name: &str) -> bool {
    STRING_ARRAYS.with(|s| s.borrow().contains(&var_name.to_uppercase()))
}

/// Emit code that sets r0=1 if condition is true, r0=0 otherwise.
/// `branch_if_false` is the branch mnemonic taken when the condition is FALSE
/// (the complement), e.g. for LT use "bge".  Uses forward branches instead of
/// IT blocks so that 16-bit `movs` never runs inside an IT slot and cannot
/// corrupt the flags used by the ELSE evaluation.
fn bool_from_flags(branch_if_false: &str) -> String {
    let id = COND_LABEL_CTR.fetch_add(1, Ordering::Relaxed);
    format!(
        "    {branch_if_false}    .Lcf{id}\n\
         \x20   movs    r0, #1\n\
         \x20   b       .Lcf{id}e\n\
         .Lcf{id}:\n\
         \x20   movs    r0, #0\n\
         .Lcf{id}e:\n"
    )
}

/// Emit Thumb2 code to evaluate `expr`, leaving result in r0.
pub fn emit_expr(
    expr: &Expr,
    var_addrs: &std::collections::HashMap<String, u32>,
) -> Result<String, String> {
    match expr {
        Expr::Number(n) => {
            // ARM32 mov immediate: only 8-bit values rotated by even amounts are encodable.
            // Safe rule: use mov for 0..=255 and a few common negatives (-1, -2, ..),
            // use ldr literal pool for everything else.
            if *n >= 0 && *n <= 255 {
                Ok(format!("    mov     r0, #{n}\n"))
            } else {
                Ok(format!("    ldr     r0, ={n}\n"))
            }
        }

        Expr::Ident(info) => {
            let name_up = info.name.to_uppercase();
            if let Some(&addr) = var_addrs.get(&name_up) {
                Ok(format!(
                    "    ldr     r1, =0x{addr:08X}    @ {}\n    ldr     r0, [r1]\n",
                    info.name
                ))
            } else {
                Err(format!("Unknown variable: {}", info.name))
            }
        }

        Expr::Binary { op, left, right } => {
            let mut s = String::new();
            s.push_str(&emit_expr(left, var_addrs)?);
            s.push_str("    push    {r0}\n");
            s.push_str(&emit_expr(right, var_addrs)?);
            s.push_str("    mov     r1, r0\n");
            s.push_str("    pop     {r0}\n");
            match op {
                BinOp::Add     => s.push_str("    add     r0, r0, r1\n"),
                BinOp::Sub     => s.push_str("    sub     r0, r0, r1\n"),
                BinOp::Mul     => s.push_str("    mul     r0, r0, r1\n"),
                BinOp::Div |
                BinOp::FloorDiv=> s.push_str("    push    {lr}
    bl      __aeabi_idiv  @ r0=dividend r1=divisor → r0
    pop     {lr}\n"),
                BinOp::Mod     => {
                    s.push_str("    push    {r0, r1, lr}
    bl      __aeabi_idiv
    mov     r2, r0
    pop     {r0, r1, lr}\n");
                    s.push_str("    mul     r2, r2, r1\n");
                    s.push_str("    sub     r0, r0, r2\n");
                }
                BinOp::Shl    => s.push_str("    lsl     r0, r0, r1\n"),
                BinOp::Shr    => s.push_str("    asr     r0, r0, r1\n"),
                BinOp::BitAnd => s.push_str("    and     r0, r0, r1\n"),
                BinOp::BitOr  => s.push_str("    orr     r0, r0, r1\n"),
                BinOp::BitXor => s.push_str("    eor     r0, r0, r1\n"),
            }
            Ok(s)
        }

        Expr::Compare { op, left, right } => {
            let mut s = String::new();
            s.push_str(&emit_expr(left, var_addrs)?);
            s.push_str("    push    {r0}\n");
            s.push_str(&emit_expr(right, var_addrs)?);
            s.push_str("    mov     r1, r0\n");
            s.push_str("    pop     {r0}\n");
            s.push_str("    cmp     r0, r1\n");
            // Use conditional branch pattern — IT blocks are avoided because
            // 16-bit `movs` inside them sets N/Z, corrupting ELSE slot evaluation.
            match op {
                CmpOp::Eq => s.push_str(&bool_from_flags("bne")),
                CmpOp::Ne => s.push_str(&bool_from_flags("beq")),
                CmpOp::Lt => s.push_str(&bool_from_flags("bge")),
                CmpOp::Le => s.push_str(&bool_from_flags("bgt")),
                CmpOp::Gt => s.push_str(&bool_from_flags("ble")),
                CmpOp::Ge => s.push_str(&bool_from_flags("blt")),
            }
            Ok(s)
        }

        Expr::Logic { op, left, right } => {
            let mut s = String::new();
            match op {
                LogicOp::And => {
                    // Short-circuit: if left is 0, result is 0
                    s.push_str(&emit_expr(left, var_addrs)?);
                    s.push_str("    cmp     r0, #0\n");
                    s.push_str("    beq     1f\n");
                    s.push_str(&emit_expr(right, var_addrs)?);
                    s.push_str("    cmp     r0, #0\n");
                    s.push_str(&bool_from_flags("beq"));
                    s.push_str("    b       2f\n");
                    s.push_str("1:  mov     r0, #0\n");
                    s.push_str("2:\n");
                }
                LogicOp::Or => {
                    s.push_str(&emit_expr(left, var_addrs)?);
                    s.push_str("    cmp     r0, #0\n");
                    s.push_str("    bne     1f\n");
                    s.push_str(&emit_expr(right, var_addrs)?);
                    s.push_str("    b       2f\n");
                    s.push_str("1:  mov     r0, #1\n");
                    s.push_str("2:\n");
                }
            }
            Ok(s)
        }

        Expr::Not(operand) => {
            let mut s = emit_expr(operand, var_addrs)?;
            s.push_str("    cmp     r0, #0\n");
            s.push_str(&bool_from_flags("bne"));
            Ok(s)
        }

        Expr::BitNot(operand) => {
            let mut s = emit_expr(operand, var_addrs)?;
            s.push_str("    mvn     r0, r0\n");
            Ok(s)
        }

        Expr::Call(info) => emit_call(info, var_addrs),

        Expr::Index { target, index } => {
            let is_str = matches!(target.as_ref(), Expr::Ident(info) if is_string_array(&info.name));
            let mut s = String::new();
            s.push_str(&emit_expr(target, var_addrs)?);
            s.push_str("    push    {r0}\n");
            s.push_str(&emit_expr(index, var_addrs)?);
            s.push_str("    mov     r1, r0\n");
            s.push_str("    pop     {r0}           @ base ptr\n");
            if is_str {
                s.push_str("    lsl     r1, r1, #2     @ index * 4 (ptr stride)\n");
                s.push_str("    add     r0, r0, r1\n");
                s.push_str("    ldr     r0, [r0]       @ load 32-bit string pointer\n");
            } else {
                s.push_str("    lsl     r1, r1, #1     @ index * 2 (i16 stride)\n");
                s.push_str("    add     r0, r0, r1\n");
                s.push_str("    ldrsh   r0, [r0]       @ sign-extend 16-bit load\n");
            }
            Ok(s)
        }

        Expr::StringLit(s) => {
            // String literals used as asset names — not a runtime value
            Err(format!("String literal '{}' not supported as expression in ARM backend", s))
        }

        Expr::MethodCall(info) => {
            match info.method_name.as_str() {
                "abs" => {
                    let mut s = emit_expr(&info.target, var_addrs)?;
                    s.push_str("    cmp     r0, #0\n");
                    s.push_str("    it      mi\n    negmi   r0, r0    @ abs\n");
                    Ok(s)
                }
                "clamp" => {
                    let lo = info.args.get(0).ok_or_else(|| "clamp: missing lo".to_string())?;
                    let hi = info.args.get(1).ok_or_else(|| "clamp: missing hi".to_string())?;
                    let mut s = emit_expr(&info.target, var_addrs)?;
                    // clamp lo: val = max(val, lo)
                    s.push_str("    push    {r0}           @ val\n");
                    s.push_str(&emit_expr(lo, var_addrs)?);
                    s.push_str("    mov     r1, r0\n    pop     {r0}\n");
                    s.push_str("    cmp     r0, r1\n    it      lt\n    movlt   r0, r1    @ max(val, lo)\n");
                    // clamp hi: val = min(val, hi)
                    s.push_str("    push    {r0}           @ val (after lo clamp)\n");
                    s.push_str(&emit_expr(hi, var_addrs)?);
                    s.push_str("    mov     r1, r0\n    pop     {r0}\n");
                    s.push_str("    cmp     r0, r1\n    it      gt\n    movgt   r0, r1    @ min(val, hi)\n");
                    Ok(s)
                }
                "min" => {
                    let arg = info.args.get(0).ok_or_else(|| "min: missing arg".to_string())?;
                    let mut s = emit_expr(&info.target, var_addrs)?;
                    s.push_str("    push    {r0}\n");
                    s.push_str(&emit_expr(arg, var_addrs)?);
                    s.push_str("    mov     r1, r0\n    pop     {r0}\n");
                    s.push_str("    cmp     r0, r1\n    it      gt\n    movgt   r0, r1    @ min(a, b)\n");
                    Ok(s)
                }
                "max" => {
                    let arg = info.args.get(0).ok_or_else(|| "max: missing arg".to_string())?;
                    let mut s = emit_expr(&info.target, var_addrs)?;
                    s.push_str("    push    {r0}\n");
                    s.push_str(&emit_expr(arg, var_addrs)?);
                    s.push_str("    mov     r1, r0\n    pop     {r0}\n");
                    s.push_str("    cmp     r0, r1\n    it      lt\n    movlt   r0, r1    @ max(a, b)\n");
                    Ok(s)
                }
                other => Err(format!("Unsupported method call: .{other}()")),
            }
        }

        other => Err(format!("Unsupported expression in ARM backend: {:?}", other)),
    }
}

/// Builtins whose first argument is an asset name (string literal → ROM symbol address).
const ASSET_BUILTINS: &[&str] = &[
    "DRAW_VECTOR", "DRAW_VECTOR_EX", "DRAW_VECTOR_3D", "PLAY_MUSIC", "PLAY_SFX",
    "LOAD_LEVEL", "SHOW_LEVEL", "PLAY_NOTE",
];

/// Builtins that contain string literals in any position — handled by stripping them
/// and emitting a `.asciz` reference instead (position tracked separately).
const TEXT_BUILTINS: &[&str] = &["PRINT_TEXT"];

/// Emit a function call, placing args in r0–r3 (ARM EABI).
pub fn emit_call(
    info: &CallInfo,
    var_addrs: &std::collections::HashMap<String, u32>,
) -> Result<String, String> {
    // Special case: len(arr) — resolved at compile time via ARRAY_NAME_LEN equate.
    // Only works for simple variable-name arguments (the common case).
    if (info.name == "len" || info.name == "LEN") && info.args.len() == 1 {
        if let Some(vpy_parser::Expr::Ident(id)) = info.args.first() {
            let varname = id.name.to_uppercase();
            // Emit the compile-time constant directly — the assembler resolves it.
            return Ok(format!("    ldr     r0, =ARRAY_{varname}_LEN\n"));
        }
        // Fallthrough for non-Var args → returns 0 via vpy_len
    }

    // Enemy system
    if info.name.to_uppercase() == "SPAWN_ENEMIES" {
        if let Some(Expr::StringLit(level_name)) = info.args.first() {
            let sym = level_name.to_uppercase().replace('-', "_").replace(' ', "_");
            return Ok(format!(
                "    @ SPAWN_ENEMIES(\"{level_name}\")\n\
                 \x20   ldr     r0, =_{sym}_PITREX_ENEMIES\n\
                 \x20   ldr     r1, =_{sym}_PITREX_ENEMY_COUNT\n\
                 \x20   ldr     r1, [r1]\n\
                 \x20   bl      pitrex_spawn_enemies\n"
            ));
        }
        return Ok(format!("    @ SPAWN_ENEMIES — missing level name arg\n"));
    }
    if info.name.to_uppercase() == "UPDATE_ENEMIES" {
        return Ok("    @ UPDATE_ENEMIES\n    bl      pitrex_update_enemies\n".to_string());
    }
    if info.name.to_uppercase() == "DRAW_ENEMIES" {
        return Ok("    @ DRAW_ENEMIES\n    bl      pitrex_draw_enemies\n".to_string());
    }

    // ── Enemy query/command builtins — ARM32 pool access ───────────────────
    // Pool layout: stride=32, active@+12, x@+4(i16), y@+6(i16), sm_state@+18
    if info.name.to_uppercase() == "GET_ENEMY_ACTIVE" {
        let idx_s = emit_expr(info.args.first().ok_or("GET_ENEMY_ACTIVE: missing arg")?, var_addrs)?;
        return Ok(format!(
            "    @ GET_ENEMY_ACTIVE(idx)\n\
             {idx_s}\
             \x20   mov     r1, #32\n\
             \x20   mul     r0, r0, r1\n\
             \x20   ldr     r1, =PITREX_ENEMY_POOL\n\
             \x20   add     r1, r1, r0\n\
             \x20   ldrb    r0, [r1, #12]   @ active\n"
        ));
    }
    if info.name.to_uppercase() == "GET_ENEMY_X" {
        let idx_s = emit_expr(info.args.first().ok_or("GET_ENEMY_X: missing arg")?, var_addrs)?;
        return Ok(format!(
            "    @ GET_ENEMY_X(idx)\n\
             {idx_s}\
             \x20   mov     r1, #32\n\
             \x20   mul     r0, r0, r1\n\
             \x20   ldr     r1, =PITREX_ENEMY_POOL\n\
             \x20   add     r1, r1, r0\n\
             \x20   ldrsh   r0, [r1, #4]    @ x (i16)\n"
        ));
    }
    if info.name.to_uppercase() == "GET_ENEMY_Y" {
        let idx_s = emit_expr(info.args.first().ok_or("GET_ENEMY_Y: missing arg")?, var_addrs)?;
        return Ok(format!(
            "    @ GET_ENEMY_Y(idx)\n\
             {idx_s}\
             \x20   mov     r1, #32\n\
             \x20   mul     r0, r0, r1\n\
             \x20   ldr     r1, =PITREX_ENEMY_POOL\n\
             \x20   add     r1, r1, r0\n\
             \x20   ldrsh   r0, [r1, #6]    @ y (i16)\n"
        ));
    }
    if info.name.to_uppercase() == "SET_ENEMY_X" {
        let idx_s = emit_expr(info.args.first().ok_or("SET_ENEMY_X: missing idx arg")?, var_addrs)?;
        let val_s = emit_expr(info.args.get(1).ok_or("SET_ENEMY_X: missing x arg")?, var_addrs)?;
        return Ok(format!(
            "    @ SET_ENEMY_X(idx, x)\n\
             {idx_s}\
             \x20   mov     r1, #32\n\
             \x20   mul     r0, r0, r1\n\
             \x20   ldr     r1, =PITREX_ENEMY_POOL\n\
             \x20   add     r1, r1, r0\n\
             \x20   push    {{r1}}              @ save pool entry ptr\n\
             {val_s}\
             \x20   pop     {{r1}}\n\
             \x20   strh    r0, [r1, #4]    @ pool.x = r0\n"
        ));
    }
    if info.name.to_uppercase() == "SET_ENEMY_Y" {
        let idx_s = emit_expr(info.args.first().ok_or("SET_ENEMY_Y: missing idx arg")?, var_addrs)?;
        let val_s = emit_expr(info.args.get(1).ok_or("SET_ENEMY_Y: missing y arg")?, var_addrs)?;
        return Ok(format!(
            "    @ SET_ENEMY_Y(idx, y)\n\
             {idx_s}\
             \x20   mov     r1, #32\n\
             \x20   mul     r0, r0, r1\n\
             \x20   ldr     r1, =PITREX_ENEMY_POOL\n\
             \x20   add     r1, r1, r0\n\
             \x20   push    {{r1}}              @ save pool entry ptr\n\
             {val_s}\
             \x20   pop     {{r1}}\n\
             \x20   strh    r0, [r1, #6]    @ pool.y = r0\n"
        ));
    }
    if info.name.to_uppercase() == "GET_ENEMY_STATE" {
        let idx_s = emit_expr(info.args.first().ok_or("GET_ENEMY_STATE: missing arg")?, var_addrs)?;
        return Ok(format!(
            "    @ GET_ENEMY_STATE(idx)\n\
             {idx_s}\
             \x20   mov     r1, #32\n\
             \x20   mul     r0, r0, r1\n\
             \x20   ldr     r1, =PITREX_ENEMY_POOL\n\
             \x20   add     r1, r1, r0\n\
             \x20   ldrb    r0, [r1, #18]   @ sm_state\n"
        ));
    }
    if info.name.to_uppercase() == "SET_ENEMY_STATE" {
        let idx_s = emit_expr(info.args.first().ok_or("SET_ENEMY_STATE: missing idx arg")?, var_addrs)?;
        let val_s = emit_expr(info.args.get(1).ok_or("SET_ENEMY_STATE: missing state arg")?, var_addrs)?;
        return Ok(format!(
            "    @ SET_ENEMY_STATE(idx, state)\n\
             {idx_s}\
             \x20   mov     r1, #32\n\
             \x20   mul     r0, r0, r1\n\
             \x20   ldr     r1, =PITREX_ENEMY_POOL\n\
             \x20   add     r1, r1, r0\n\
             \x20   push    {{r1}}              @ save pool entry ptr\n\
             {val_s}\
             \x20   pop     {{r1}}\n\
             \x20   strb    r0, [r1, #18]   @ pool.sm_state\n"
        ));
    }
    if info.name.to_uppercase() == "KILL_ENEMY" {
        let idx_s = emit_expr(info.args.first().ok_or("KILL_ENEMY: missing arg")?, var_addrs)?;
        return Ok(format!(
            "    @ KILL_ENEMY(idx)\n\
             {idx_s}\
             \x20   bl      pitrex_kill_enemy\n"
        ));
    }
    if info.name.to_uppercase() == "ENEMY_FIRE_EVENT" {
        let idx_s = emit_expr(info.args.first().ok_or("ENEMY_FIRE_EVENT: missing idx arg")?, var_addrs)?;
        // Second arg must be a string literal — compute FNV-1a hash at compile time
        let hash: u8 = if let Some(Expr::StringLit(ev)) = info.args.get(1) {
            // FNV-1a hash (same as M6809 builtins.rs fnv1a_u8)
            let mut h: u32 = 2166136261;
            for b in ev.bytes() { h = h.wrapping_mul(16777619) ^ (b as u32); }
            (h & 0xFF) as u8
        } else { 0 };
        return Ok(format!(
            "    @ ENEMY_FIRE_EVENT(idx, hash=0x{hash:02X})\n\
             {idx_s}\
             \x20   mov     r1, #{hash}\n\
             \x20   bl      pitrex_enemy_fire_event\n"
        ));
    }

    let fn_name = match info.name.as_str() {
        "WAIT_RECAL"      => "pitrex_wait_recal",
        "SET_INTENSITY"   => "pitrex_set_intensity",
        "DRAW_LINE"       => "pitrex_draw_line",
        "DRAW_CIRCLE"     => "pitrex_draw_circle",
        "DRAW_RECT"       => "pitrex_draw_rect",
        "DRAW_FILLED_RECT" => "pitrex_draw_filled_rect",
        "DRAW_POLYGON"    => "pitrex_draw_polygon",
        "DRAW_ARC"        => "pitrex_draw_arc",
        "DRAW_ELLIPSE"    => "pitrex_draw_ellipse",
        "DRAW_BEZIER"     => "v_drawBezierCubic",
        "DRAW_BEZIER_QUAD"=> "v_drawBezierQuad",
        "MOVE"            => "pitrex_move",
        "DRAW_VECTOR"     => "pitrex_draw_vector",
        "DRAW_VECTOR_EX"  => "pitrex_draw_vector_ex",
        "DRAW_VECTOR_3D"  => "pitrex_draw_vector_3d",
        "PRINT_TEXT"      => "pitrex_print_text",
        "PRINT_NUMBER"    => "pitrex_print_number",
        "PLAY_MUSIC"      => "pitrex_play_music",
        "STOP_MUSIC"      => "pitrex_stop_music",
        "PLAY_SFX"        => "pitrex_play_sfx",
        "PLAY_NOTE"       => "pitrex_play_note",
        "LOAD_LEVEL"      => "pitrex_load_level",
        "SHOW_LEVEL"      => "pitrex_show_level",
        "J1_X"            => "pitrex_j1_x",
        "J1_Y"            => "pitrex_j1_y",
        "J1_BTN1" | "J1_BUTTON_1" => "pitrex_j1_btn1",
        "J1_BTN2" | "J1_BUTTON_2" => "pitrex_j1_btn2",
        "J1_BTN3" | "J1_BUTTON_3" => "pitrex_j1_btn3",
        "J1_BTN4" | "J1_BUTTON_4" => "pitrex_j1_btn4",
        "J2_X"            => "pitrex_j2_x",
        "J2_Y"            => "pitrex_j2_y",
        "J2_BTN1" | "J2_BUTTON_1" => "pitrex_j2_btn1",
        "J2_BTN2" | "J2_BUTTON_2" => "pitrex_j2_btn2",
        "J2_BTN3" | "J2_BUTTON_3" => "pitrex_j2_btn3",
        "J2_BTN4" | "J2_BUTTON_4" => "pitrex_j2_btn4",
        "UPDATE_BUTTONS"  => "pitrex_update_buttons",
        // Math builtins (both cases)
        "abs" | "ABS"     => "pitrex_abs",
        "min" | "MIN"     => "pitrex_min",
        "max" | "MAX"     => "pitrex_max",
        "clamp" | "CLAMP" => "pitrex_clamp",
        "sin" | "SIN"     => "pitrex_sin",
        "cos" | "COS"     => "pitrex_cos",
        "tan" | "TAN"     => "pitrex_tan_impl",
        "atan2" | "ATAN2" => "pitrex_atan2",
        "pow" | "POW"     => "pitrex_pow",
        "sqrt" | "SQRT"   => "pitrex_sqrt",
        "rand" | "RAND"   => "pitrex_rand",
        "rand_range" | "RAND_RANGE" => "pitrex_rand_range",
        // Debug builtins
        "debug_print" | "DEBUG_PRINT" => "pitrex_debug_print",
        "debug_print_labeled" | "DEBUG_PRINT_LABELED" => "pitrex_debug_print_labeled",
        "DEBUG_PRINT_STR"   => "pitrex_debug_print_str",
        // Level system
        "LEVEL_COLLISION_Y" => "pitrex_level_collision_y",
        "LEVEL_COLLISION_X" => "pitrex_level_collision_x",
        "SET_CAMERA_X"      => "pitrex_set_camera_x",
        "SET_CAMERA_Y"      => "pitrex_set_camera_y",
        "GET_CAMERA_X"           => "pitrex_get_camera_x",
        "GET_CAMERA_Y"           => "pitrex_get_camera_y",
        "GET_SCROLL_LIMIT_LEFT"  => "pitrex_get_scroll_limit_left",
        "GET_SCROLL_LIMIT_RIGHT" => "pitrex_get_scroll_limit_right",
        "GET_SCROLL_LIMIT_TOP"   => "pitrex_get_scroll_limit_top",
        "GET_SCROLL_LIMIT_BOTTOM"=> "pitrex_get_scroll_limit_bottom",
        // Message system
        "MSG_DEF"         => "pitrex_msg_def",
        "PRINT_MSG"       => "pitrex_print_msg",
        // Text/display extras
        "SET_TEXT_SIZE"   => "pitrex_set_text_size",
        "SET_TEXT_COLOR"  => "pitrex_set_text_color",
        "UPDATE_LEVEL"    => "pitrex_update_level",
        // Misc
        "beep" | "BEEP"   => "pitrex_beep",
        "wait" | "WAIT"   => "pitrex_wait",
        "peek" | "PEEK"   => "pitrex_peek",
        "poke" | "POKE"   => "pitrex_poke",
        "len" | "LEN"     => "pitrex_len",
        // Animation
        "DRAW_ANIM"       => "pitrex_draw_anim",
        other             => other,
    };

    let mut s = String::new();
    let args = &info.args;

    // Special handling for PRINT_TEXT(x, y, "string") — string is 3rd arg
    if TEXT_BUILTINS.contains(&info.name.as_str()) {
        // Find string literal and emit as .asciz in place
        let mut processed: Vec<String> = Vec::new();
        for (i, arg) in args.iter().enumerate() {
            if let Expr::StringLit(text) = arg {
                // Generate unique label for this string
                static STR_CTR: std::sync::atomic::AtomicU32 = std::sync::atomic::AtomicU32::new(0);
                let id = STR_CTR.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                let label = format!("_str_{id}");
                // Emit string in rodata section, then return to text
                processed.push(format!(
                    "    b       {label}_end\n{label}:\n    .asciz  \"{text}\\x80\"\n    .align  2\n{label}_end:\n    ldr     r{i}, ={label}\n"
                ));
            } else {
                let expr_s = emit_expr(arg, var_addrs)?;
                processed.push(format!("{expr_s}    push    {{r0}}\n"));
            }
        }
        // Simple approach: eval all, put results in r0..rN
        for (i, p) in processed.iter().enumerate() {
            if !p.contains("ldr     r") {
                s.push_str(p);
                if i < args.len() - 1 {
                    s.push_str(&format!("    mov     r{i}, r0\n"));
                }
            }
        }
        // Re-emit cleanly: push each arg then pop
        s.clear();
        for arg in args.iter() {
            match arg {
                Expr::StringLit(text) => {
                    static STR_CTR2: std::sync::atomic::AtomicU32 = std::sync::atomic::AtomicU32::new(0);
                    let id = STR_CTR2.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                    let label = format!("_str_{id}");
                    s.push_str(&format!("    ldr     r0, ={label}\n"));
                    s.push_str("    push    {r0}\n");
                    // Emit the string data after the call via a literal pool reference
                    s.push_str(&format!("@ string data for label {label} emitted in rodata\n"));
                    // Store for later emission — for now inline with b/label trick
                    s = format!(
                        "{s_prev}    b       {label}_after\n{label}:\n    .asciz  \"{text}\"\n    .align  2\n{label}_after:\n    ldr     r0, ={label}\n    push    {{r0}}\n",
                        s_prev = {
                            // Remove the last two lines we just added
                            let mut tmp = s.clone();
                            // strip the ldr + push we added above
                            let pos = tmp.rfind(&format!("    ldr     r0, ={label}\n")).unwrap_or(tmp.len());
                            tmp.truncate(pos);
                            tmp
                        }
                    );
                }
                other => {
                    s.push_str(&emit_expr(other, var_addrs)?);
                    s.push_str("    push    {r0}\n");
                }
            }
        }
        let nreg = args.len().min(4);
        for i in (0..nreg).rev() {
            s.push_str(&format!("    pop     {{r{i}}}\n"));
        }
        s.push_str(&format!("    bl      {fn_name}\n"));
        let nextra = args.len().saturating_sub(4);
        if nextra > 0 {
            s.push_str(&format!("    add     sp, sp, #{}\n", nextra * 4));
        }
        return Ok(s);
    }

    // Special case: DRAW_POLYGON — supports both
    //   Form A: (n, x0, y0, x1, y1, ...)            — no intensity
    //   Form B: (n, intensity, x0, y0, x1, y1, ...) — intensity as 2nd arg
    // pitrex_draw_polygon expects Form B; normalise Form A by inserting a
    // default intensity (0x5F) at position 1 before pushing.
    if info.name == "DRAW_POLYGON" {
        if let Some(Expr::Number(nv)) = args.first() {
            let n = *nv as usize;
            let form_a_len = 1 + 2 * n;
            let form_b_len = 2 + 2 * n;
            let normalized: Vec<Expr> = if args.len() == form_a_len {
                let mut v: Vec<Expr> = Vec::with_capacity(form_b_len);
                v.push(args[0].clone());
                v.push(Expr::Number(0x5F));
                v.extend(args[1..].iter().cloned());
                v
            } else if args.len() == form_b_len {
                args.to_vec()
            } else {
                args.to_vec()
            };

            // Inline the generic emit path but with the normalised arg list.
            let total_reg_args = normalized.len();
            let n_extra = total_reg_args.saturating_sub(4);
            let n_skip = 4usize.min(total_reg_args);

            for arg in normalized.iter().skip(n_skip).rev() {
                s.push_str(&emit_arg(arg, var_addrs)?);
                s.push_str("    push    {r0}\n");
            }
            for arg in normalized.iter().take(n_skip) {
                s.push_str(&emit_arg(arg, var_addrs)?);
                s.push_str("    push    {r0}\n");
            }
            let nreg = total_reg_args.min(4);
            for i in (0..nreg).rev() {
                s.push_str(&format!("    pop     {{r{i}}}\n"));
            }
            s.push_str("    bl      pitrex_draw_polygon\n");
            if n_extra > 0 {
                s.push_str(&format!("    add     sp, sp, #{}\n", n_extra * 4));
            }
            return Ok(s);
        }
    }

    // Special case: DRAW_VECTOR("name", ox, oy[, mirror]) — 3-arg form uses simple draw,
    // 4-arg form (with mirror) routes to pitrex_draw_vector_ex with intensity=127.
    if info.name == "DRAW_VECTOR" {
        if let Some(Expr::StringLit(asset_name)) = args.first() {
            let sym_base = asset_name.to_uppercase().replace('-', "_").replace(' ', "_");
            let symbol   = format!("_{sym_base}_VECTORS");
            let runtime: Vec<&Expr> = args.iter().skip(1).collect();
            if runtime.len() >= 3 {
                // Has mirror arg → pitrex_draw_vector_ex(r0=asset, r1=ox, r2=oy, r3=mirror, [sp]=intensity)
                // Push intensity first so it sits at [sp] when callee reads [sp+28]
                s.push_str("    mov     r0, #127\n");
                s.push_str("    push    {r0}\n");
                s.push_str(&format!("    ldr     r0, ={symbol}    @ asset '{asset_name}'\n"));
                s.push_str("    push    {r0}\n");
                if let Some(ox) = runtime.first() {
                    s.push_str(&emit_arg(ox, var_addrs)?);
                } else {
                    s.push_str("    mov     r0, #0\n");
                }
                s.push_str("    push    {r0}\n");
                if let Some(oy) = runtime.get(1) {
                    s.push_str(&emit_arg(oy, var_addrs)?);
                } else {
                    s.push_str("    mov     r0, #0\n");
                }
                s.push_str("    push    {r0}\n");
                s.push_str(&emit_arg(runtime.get(2).unwrap(), var_addrs)?);
                s.push_str("    push    {r0}\n");
                s.push_str("    pop     {r3}\n    pop     {r2}\n    pop     {r1}\n    pop     {r0}\n");
                s.push_str("    bl      pitrex_draw_vector_ex\n");
                s.push_str("    add     sp, sp, #4\n"); // discard intensity
            } else {
                // No mirror → simple pitrex_draw_vector(r0=asset, r1=ox, r2=oy)
                s.push_str(&format!("    ldr     r0, ={symbol}    @ asset '{asset_name}'\n"));
                s.push_str("    push    {r0}\n");
                if let Some(ox) = runtime.first() {
                    s.push_str(&emit_arg(ox, var_addrs)?);
                } else {
                    s.push_str("    mov     r0, #0\n");
                }
                s.push_str("    push    {r0}\n");
                if let Some(oy) = runtime.get(1) {
                    s.push_str(&emit_arg(oy, var_addrs)?);
                } else {
                    s.push_str("    mov     r0, #0\n");
                }
                s.push_str("    push    {r0}\n");
                s.push_str("    pop     {r2}\n    pop     {r1}\n    pop     {r0}\n");
                s.push_str("    bl      pitrex_draw_vector\n");
            }
            return Ok(s);
        }
    }

    // Special case: DRAW_VECTOR_EX(asset, ox, oy, mirror, intensity)
    // ABI: r0=asset_ptr, r1=ox, r2=oy, r3=mirror, [sp+0]=intensity
    // intensity MUST be on the stack BEFORE the call (and cleaned up after).
    if info.name == "DRAW_VECTOR_EX" {
        if let Some(Expr::StringLit(asset_name)) = args.first() {
            let sym_base = asset_name.to_uppercase().replace('-', "_").replace(' ', "_");
            let symbol = format!("_{sym_base}_VECTORS");
            let runtime: Vec<&Expr> = args.iter().skip(1).collect();
            // Push intensity first so it sits at [sp] when the function reads [sp+32]
            // (after the function pushes 8 regs = 32 bytes).
            if let Some(intensity) = runtime.get(3) {
                s.push_str(&emit_arg(intensity, var_addrs)?);
            } else {
                s.push_str("    mov     r0, #127\n");
            }
            s.push_str("    push    {r0}\n");
            // r0 = asset_ptr
            s.push_str(&format!("    ldr     r0, ={symbol}    @ asset '{asset_name}'\n"));
            s.push_str("    push    {r0}\n");
            // r1 = ox
            if let Some(ox) = runtime.first() {
                s.push_str(&emit_arg(ox, var_addrs)?);
            } else {
                s.push_str("    mov     r0, #0\n");
            }
            s.push_str("    push    {r0}\n");
            // r2 = oy
            if let Some(oy) = runtime.get(1) {
                s.push_str(&emit_arg(oy, var_addrs)?);
            } else {
                s.push_str("    mov     r0, #0\n");
            }
            s.push_str("    push    {r0}\n");
            // r3 = mirror
            if let Some(mirror) = runtime.get(2) {
                s.push_str(&emit_arg(mirror, var_addrs)?);
            } else {
                s.push_str("    mov     r0, #0\n");
            }
            s.push_str("    push    {r0}\n");
            // pop r3=mirror, r2=oy, r1=ox, r0=asset_ptr; intensity stays at [sp]
            s.push_str("    pop     {r3}\n    pop     {r2}\n    pop     {r1}\n    pop     {r0}\n");
            s.push_str("    bl      pitrex_draw_vector_ex\n");
            s.push_str("    add     sp, sp, #4\n"); // discard intensity from stack
            return Ok(s);
        }
    }

    // Special case: DRAW_ANIM("name", ox, oy[, mirror[, scale[, speed_mul]]])
    // ABI: r0=anim_ptr, r1=ox, r2=oy, r3=mirror, [sp]=speed_mul
    // scale is ignored on PiTrex (no T1 timer equivalent).
    // Callee pushes 9 regs (36 bytes), so speed_mul is at [sp+36] on entry.
    if info.name == "DRAW_ANIM" {
        if let Some(Expr::StringLit(anim_name)) = args.first() {
            let sym = anim_name.to_uppercase().replace('-', "_").replace(' ', "_");
            let symbol = format!("_ANIM_{sym}");
            // Push speed_mul first — callee reads [sp+36] after pushing 9 regs
            if args.len() >= 6 {
                s.push_str(&emit_arg(&args[5], var_addrs)?);
            } else {
                s.push_str("    mov     r0, #1\n");
            }
            s.push_str("    push    {r0}\n");
            // anim ptr → r0
            s.push_str(&format!("    ldr     r0, ={symbol}    @ animation '{anim_name}'\n"));
            s.push_str("    push    {r0}\n");
            // ox → r1
            if args.len() >= 2 {
                s.push_str(&emit_arg(&args[1], var_addrs)?);
            } else {
                s.push_str("    mov     r0, #0\n");
            }
            s.push_str("    push    {r0}\n");
            // oy → r2
            if args.len() >= 3 {
                s.push_str(&emit_arg(&args[2], var_addrs)?);
            } else {
                s.push_str("    mov     r0, #0\n");
            }
            s.push_str("    push    {r0}\n");
            // mirror → r3
            if args.len() >= 4 {
                s.push_str(&emit_arg(&args[3], var_addrs)?);
            } else {
                s.push_str("    mov     r0, #0\n");
            }
            s.push_str("    push    {r0}\n");
            // pop r3=mirror, r2=oy, r1=ox, r0=anim_ptr; speed_mul stays at [sp]
            s.push_str("    pop     {r3}\n    pop     {r2}\n    pop     {r1}\n    pop     {r0}\n");
            s.push_str("    bl      pitrex_draw_anim\n");
            s.push_str("    add     sp, sp, #4\n"); // discard speed_mul
            return Ok(s);
        }
    }

    // Special case: DRAW_VECTOR_3D("name", rot_x, rot_y, rot_z, pos_x, pos_y)
    // Stub: For now, just draw 2D version at offset, ignore rotation
    // TODO: Implement full 3D rotation with matrix + perspective
    if info.name == "DRAW_VECTOR_3D" {
        if let Some(Expr::StringLit(asset_name)) = args.first() {
            let sym_base = asset_name.to_uppercase().replace('-', "_").replace(' ', "_");
            let symbol = format!("_{sym_base}_VECTORS");  // TODO: Use _3D_DATA when 3D rotation is complete

            // pitrex_draw_vector_3d(r0=asset_ptr, r1=rot_x, r2=rot_y, r3=rot_z, [sp]=ox, [sp+4]=oy)
            // r0 = asset_ptr
            s.push_str(&format!("    ldr     r0, ={symbol}    @ asset '{asset_name}'\n"));

            // r1 = rot_x
            if args.len() >= 2 {
                s.push_str(&emit_arg(&args[1], var_addrs)?);
                s.push_str("    mov     r1, r0\n");
            } else {
                s.push_str("    mov     r1, #0\n");
            }

            // r2 = rot_y
            if args.len() >= 3 {
                s.push_str(&emit_arg(&args[2], var_addrs)?);
                s.push_str("    mov     r2, r0\n");
            } else {
                s.push_str("    mov     r2, #0\n");
            }

            // r3 = rot_z
            if args.len() >= 4 {
                s.push_str(&emit_arg(&args[3], var_addrs)?);
                s.push_str("    mov     r3, r0\n");
            } else {
                s.push_str("    mov     r3, #0\n");
            }

            // Push ox, oy (overflow arguments for pitrex_draw_vector_3d)
            // ox = pos_x
            if args.len() >= 5 {
                s.push_str(&emit_arg(&args[4], var_addrs)?);
            } else {
                s.push_str("    mov     r0, #0\n");
            }
            s.push_str("    push    {r0}\n");

            // oy = pos_y
            if args.len() >= 6 {
                s.push_str(&emit_arg(&args[5], var_addrs)?);
            } else {
                s.push_str("    mov     r0, #0\n");
            }
            s.push_str("    push    {r0}\n");

            s.push_str("    bl      pitrex_draw_vector_3d\n");
            s.push_str("    add     sp, sp, #8          @ pop ox, oy\n");
            return Ok(s);
        }
    }

    // Special case: PLAY_NOTE("name", channel, note)
    // r0=_NAME_INSTR address, r1=channel(0-2), r2=note(MIDI 24-107)
    if info.name == "PLAY_NOTE" {
        if let Some(Expr::StringLit(instr_name)) = args.first() {
            let sym_base = instr_name.to_uppercase().replace('-', "_").replace(' ', "_");
            let symbol = format!("_{sym_base}_INSTR");
            // r0 = instrument ROM block address
            s.push_str(&format!("    ldr     r0, ={symbol}    @ instrument '{instr_name}'\n"));
            s.push_str("    push    {r0}\n");
            // r1 = channel
            if let Some(ch_expr) = args.get(1) {
                s.push_str(&emit_arg(ch_expr, var_addrs)?);
            } else {
                s.push_str("    mov     r0, #0\n");
            }
            s.push_str("    push    {r0}\n");
            // r2 = note
            if let Some(note_expr) = args.get(2) {
                s.push_str(&emit_arg(note_expr, var_addrs)?);
            } else {
                s.push_str("    mov     r0, #60\n");
            }
            s.push_str("    push    {r0}\n");
            s.push_str("    pop     {r2}\n    pop     {r1}\n    pop     {r0}\n");
            s.push_str("    bl      pitrex_play_note\n");
            return Ok(s);
        }
    }

    // For asset builtins, the first arg is a string literal → ROM symbol address.
    // Only treat as asset builtin if first arg is actually a string literal.
    let is_asset_builtin = ASSET_BUILTINS.contains(&info.name.as_str())
        && matches!(args.first(), Some(Expr::StringLit(_)));
    let runtime_args: Vec<(usize, &Expr)> = args.iter().enumerate()
        .filter(|(i, arg)| {
            !(is_asset_builtin && *i == 0 && matches!(arg, Expr::StringLit(_)))
        })
        .collect();

    // Emit asset name as first register (r0 = address of asset data in ROM)
    if is_asset_builtin {
        if let Some(Expr::StringLit(asset_name)) = args.first() {
            let sym_base = asset_name.to_uppercase().replace('-', "_").replace(' ', "_");
            // Choose symbol suffix based on builtin type
            let suffix = match info.name.as_str() {
                "PLAY_MUSIC"               => "MUSIC",
                "PLAY_SFX"                 => "SFX",
                "PLAY_NOTE"                => "INSTR",
                "LOAD_LEVEL" | "SHOW_LEVEL" => "LEVEL",
                _                          => "VECTORS",
            };
            let symbol = format!("_{sym_base}_{suffix}");
            s.push_str(&format!("    ldr     r0, ={symbol}    @ asset '{asset_name}'\n"));
            s.push_str("    push    {r0}\n");
        }
    }

    let n_asset = if is_asset_builtin { 1 } else { 0 };
    let total_reg_args = runtime_args.len() + n_asset;
    let n_extra = total_reg_args.saturating_sub(4);
    let n_skip = (4usize).saturating_sub(n_asset);

    // Extra args right-to-left
    for (_, arg) in runtime_args.iter().skip(n_skip).rev() {
        s.push_str(&emit_arg(arg, var_addrs)?);
        s.push_str("    push    {r0}\n");
    }
    // First register args
    for (_, arg) in runtime_args.iter().take(n_skip) {
        s.push_str(&emit_arg(arg, var_addrs)?);
        s.push_str("    push    {r0}\n");
    }

    let nreg = total_reg_args.min(4);
    for i in (0..nreg).rev() {
        s.push_str(&format!("    pop     {{r{i}}}\n"));
    }

    s.push_str(&format!("    bl      {fn_name}\n"));

    let nextra = n_extra;
    if nextra > 0 {
        s.push_str(&format!("    add     sp, sp, #{}\n", nextra * 4));
    }

    Ok(s)
}

/// Emit one function argument into r0.
/// Handles string literals as inline PC-relative data (branch-over trick).
fn emit_arg(
    expr: &Expr,
    var_addrs: &std::collections::HashMap<String, u32>,
) -> Result<String, String> {
    if let Expr::StringLit(text) = expr {
        static STR_CTR: std::sync::atomic::AtomicU32 = std::sync::atomic::AtomicU32::new(0);
        let id = STR_CTR.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
        let label = format!("_arg_str_{id}");
        // Branch over the string data, load its address into r0
        let s = format!(
            "    b       {label}_end\n\
             {label}:\n\
             .asciz  \"{text}\"\n\
             .align  2\n\
             {label}_end:\n\
             .ltorg\n\
             ldr     r0, ={label}\n"
        );
        Ok(s)
    } else {
        emit_expr(expr, var_addrs)
    }
}
