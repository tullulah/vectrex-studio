//! ARM backend usage analysis for runtime tree-shaking.
//!
//! Mirrors the PiTrex model (`pitrex/analysis.rs`): walk the module's
//! statements and expressions collecting the *uppercase* names of every
//! VPy builtin actually called, then map those builtin names onto runtime
//! routine GROUPS and close the group set under static dependencies
//! (one group's emitted ASM contains `bl`/`ldr =` references into another).
//!
//! The emitters (`helpers.rs`, `drawing.rs`, `builtins.rs`, `functions.rs`)
//! consult the resulting [`Usage`] and only emit the routine groups that are
//! actually needed. A small "core" set is ALWAYS emitted regardless of usage
//! (tiny SVC stubs the IDE emulator traps by symbol):
//!   bus_write, bus_read, vpy_wait_recal, vpy_set_intensity,
//!   dv_reset, dv_move_to, dv_draw_delta
//!
//! Safety: any missed dependency shows up as an undefined-symbol error from
//! `arm-none-eabi-ld` (the rp2350/uvm2 build pipeline links every .s into a
//! fully-resolved ELF), so a gating mistake fails the build loudly instead of
//! producing a silently broken binary.

use std::collections::HashSet;
use vpy_parser::{Module, Stmt, Expr, Item};

/// Set of runtime routine groups the program needs.
#[derive(Debug, Clone)]
pub struct Usage {
    groups: HashSet<&'static str>,
}

impl Usage {
    /// True when the given routine group must be emitted.
    pub fn has(&self, group: &str) -> bool {
        self.groups.contains(group)
    }

    /// A Usage with every group enabled (emit the full runtime).
    pub fn full() -> Usage {
        Usage {
            groups: GROUPS.iter().map(|(g, _, _)| *g).collect(),
        }
    }
}

/// Routine-group table: `(group, gating builtin names, dependency groups)`.
///
/// A group is enabled when the program calls any of its gating builtins;
/// enabled groups transitively enable their dependency groups. Dependencies
/// were derived by scanning the emitted ASM bodies for `bl <sym>` and
/// `ldr rN, =<sym>` references (see the per-group notes).
const GROUPS: &[(&str, &[&str], &[&str])] = &[
    // ── drawing ────────────────────────────────────────────────────────────
    // vpy_draw_vector: calls dv_reset/dv_move_to/dv_draw_delta/vpy_set_intensity (core).
    ("DRAW_VECTOR",     &["DRAW_VECTOR"],       &[]),
    // vpy_draw_vector_ex: core only. Also the target of the 4-arg
    // DRAW_VECTOR(name, ox, oy, mirror) form (handled in collect below) and a
    // dependency of LEVEL / ENEMIES / ANIM.
    ("DRAW_VECTOR_EX",  &["DRAW_VECTOR_EX"],    &[]),
    // vpy_draw_vector_3d: calls smul_lut (+ core).
    ("DRAW_VECTOR_3D",  &["DRAW_VECTOR_3D"],    &["SIN_TABLE"]),
    // vpy_draw_recording (.vrec attract/preview playback): core only —
    // dv_reset/dv_move_to/dv_draw_delta/vpy_set_intensity are always emitted.
    ("DRAW_RECORDING",  &["DRAW_RECORDING"],    &[]),
    // vpy_play_sample (.vsmp audio-sample playback): SVC stub only (svc #9 →
    // SYS_PLAY_SAMPLE). No dependencies — it just hands the ROM table to the
    // core1 audio streamer.
    ("PLAY_SAMPLE",     &["PLAY_SAMPLE"],       &[]),
    ("SAMPLE_POS",      &["SAMPLE_POS"],        &[]),
    // _SIN_TABLE data + smul_lut (smul_lut reads _SIN_TABLE).
    ("SIN_TABLE",       &[],                    &[]),
    // vpy_sin / vpy_cos: read _SIN_TABLE directly.
    ("TRIG",            &["SIN", "COS"],        &["SIN_TABLE"]),
    // vpy_move: bus_write only (core).
    ("MOVE",            &["MOVE"],              &[]),
    // vpy_draw_line: core + VPY_MOVE_X equate.
    ("DRAW_LINE",       &["DRAW_LINE"],         &[]),
    // ── shapes (each gates its own routine) ────────────────────────────────
    ("CIRCLE",          &["DRAW_CIRCLE"],       &["TRIG"]),   // calls vpy_sin/vpy_cos
    ("RECT",            &["DRAW_RECT"],         &[]),
    ("FILLED_RECT",     &["DRAW_FILLED_RECT"],  &["RECT"]),   // calls vpy_draw_rect
    ("POLYGON",         &["DRAW_POLYGON"],      &[]),
    ("ARC",             &["DRAW_ARC"],          &["TRIG"]),   // calls vpy_sin/vpy_cos
    ("ELLIPSE",         &["DRAW_ELLIPSE"],      &["TRIG"]),   // calls vpy_sin/vpy_cos
    ("BEZIER",          &["DRAW_BEZIER"],       &[]),
    ("BEZIER_QUAD",     &["DRAW_BEZIER_QUAD"],  &[]),
    // ── text ───────────────────────────────────────────────────────────────
    // Font tables + vpy_print_text (+ vpt_draw_glyph) + vpy_set_text_size/color.
    ("TEXT",            &["PRINT_TEXT", "SET_TEXT_SIZE", "SET_TEXT_COLOR"], &[]),
    ("PRINT_NUMBER",    &["PRINT_NUMBER"],      &["TEXT"]),   // calls vpy_print_text
    ("MSG",             &["MSG_DEF", "PRINT_MSG"], &["TEXT"]), // vpy_print_msg → vpy_print_text
    // ── input ──────────────────────────────────────────────────────────────
    // vpy_j1_* / vpy_j2_* readers + vpy_update_buttons (which calls psg_read).
    // Enabling this group also enables the auto-injected `bl vpy_update_buttons`
    // in game_main.
    ("JOYSTICK",        &[
        "J1_X", "J1_Y", "J1_BTN1", "J1_BTN2", "J1_BTN3", "J1_BTN4",
        "J1_BUTTON_1", "J1_BUTTON_2", "J1_BUTTON_3", "J1_BUTTON_4",
        "J2_X", "J2_Y", "J2_BTN1", "J2_BTN2", "J2_BTN3", "J2_BTN4",
        "J2_BUTTON_1", "J2_BUTTON_2", "J2_BUTTON_3", "J2_BUTTON_4",
        "UPDATE_BUTTONS",
    ], &["PSG"]),
    // ── audio ──────────────────────────────────────────────────────────────
    // psg_write / psg_read low-level PSG access (bus_write/bus_read = core).
    ("PSG",             &[],                    &[]),
    // vpy_play_music / vpy_stop_music / vpy_music_update (auto-injected call gated too).
    ("MUSIC",           &["PLAY_MUSIC", "STOP_MUSIC"], &["PSG"]),
    // vpy_play_sfx / vpy_audio_update (auto-injected call gated too).
    ("SFX",             &["PLAY_SFX"],          &["PSG"]),
    // NOTE_PERIOD_TABLE + vpy_play_note + vpy_note_update (auto-injected call gated too).
    ("NOTE",            &["PLAY_NOTE"],         &["PSG"]),
    // vpy_beep + vpy_beep_update (auto-injected call gated too).
    ("BEEP",            &["BEEP"],              &["PSG"]),
    // ── math ───────────────────────────────────────────────────────────────
    ("MATH_BASIC",      &["ABS", "MIN", "MAX", "CLAMP"], &[]),
    ("SQRT",            &["SQRT"],              &[]),
    // vpy_rand + vpy_rand_range. Also a dep of ENEMIES (wander AI calls vpy_rand).
    ("RAND",            &["RAND", "RAND_RANGE"], &[]),
    // ── utilities ──────────────────────────────────────────────────────────
    ("WAIT",            &["WAIT"],              &[]),  // calls vpy_wait_recal (core)
    ("PEEK_POKE",       &["PEEK", "POKE"],      &[]),  // bus_read/bus_write (core)
    ("LEN",             &["LEN"],               &[]),  // runtime fallback stub
    // ── sprites / enemies / levels ─────────────────────────────────────────
    // vpy_draw_anim: calls vpy_draw_vector_ex. Also a dep of ENEMIES.
    ("ANIM",            &["DRAW_ANIM"],         &["DRAW_VECTOR_EX"]),
    // Enemy pool + wander AI: vpy_update_enemies calls vpy_level_collision_x
    // and vpy_rand; vpy_draw_enemies calls vpy_draw_vector_ex and vpy_draw_anim.
    ("ENEMIES",         &[
        "SPAWN_ENEMIES", "UPDATE_ENEMIES", "DRAW_ENEMIES",
        "GET_ENEMY_ACTIVE", "GET_ENEMY_X", "GET_ENEMY_Y", "GET_ENEMY_STATE",
        "GET_ENEMY_AREA_IDX", "SET_ENEMY_X", "SET_ENEMY_Y", "SET_ENEMY_DIR",
        "SET_ENEMY_STATE", "KILL_ENEMY", "ENEMY_FIRE_EVENT",
    ], &["LEVEL_COLLISION", "RAND", "DRAW_VECTOR_EX", "ANIM"]),
    // vpy_load_level / vpy_show_level (+ vsl_draw_static) / vpy_update_level /
    // vpy_get_level_width/height/tile. show_level calls vpy_draw_vector_ex.
    ("LEVEL",           &[
        "LOAD_LEVEL", "SHOW_LEVEL", "UPDATE_LEVEL",
        "GET_LEVEL_WIDTH", "GET_LEVEL_HEIGHT", "GET_LEVEL_TILE",
    ], &["DRAW_VECTOR_EX"]),
    // vpy_level_collision_x / vpy_level_collision_y (leaf: RAM equates only).
    ("LEVEL_COLLISION", &["LEVEL_COLLISION_X", "LEVEL_COLLISION_Y"], &[]),
    // Camera / scroll-limit accessors + vpy_get_level_floor_y (all leaf stubs).
    ("CAMERA",          &[
        "SET_CAMERA_X", "SET_CAMERA_Y", "GET_CAMERA_X", "GET_CAMERA_Y",
        "GET_SCROLL_LIMIT_LEFT", "GET_SCROLL_LIMIT_RIGHT",
        "GET_SCROLL_LIMIT_TOP", "GET_SCROLL_LIMIT_BOTTOM",
        "GET_LEVEL_FLOOR_Y",
    ], &[]),
    ("FRAME_US",        &["GET_FRAME_US"],      &[]),
    ("DEBUG",           &["DEBUG_PRINT", "DEBUG_PRINT_LABELED", "DEBUG_PRINT_STR"], &[]),
];

/// Analyze the module and return the set of runtime routine groups to emit.
pub fn analyze(module: &Module) -> Usage {
    let called = collect_called_builtins(module);

    let mut groups: HashSet<&'static str> = HashSet::new();
    for (group, builtins, _) in GROUPS {
        if builtins.iter().any(|b| called.contains(*b)) {
            groups.insert(group);
        }
    }

    // Transitive closure over dependency groups.
    loop {
        let before = groups.len();
        for (group, _, deps) in GROUPS {
            if groups.contains(group) {
                for d in *deps {
                    groups.insert(d);
                }
            }
        }
        if groups.len() == before {
            break;
        }
    }

    Usage { groups }
}

/// Walk every function body / global initializer collecting uppercase call
/// names. Also inserts the pseudo-builtin "DRAW_VECTOR_EX" for the 4-arg
/// DRAW_VECTOR(name, ox, oy, mirror) form, which routes through
/// vpy_draw_vector_ex at codegen time (see expressions.rs).
fn collect_called_builtins(module: &Module) -> HashSet<String> {
    let mut out = HashSet::new();
    for item in &module.items {
        match item {
            Item::Function(f) => {
                for s in &f.body {
                    walk_stmt(s, &mut out);
                }
            }
            Item::Const { value, .. } | Item::GlobalLet { value, .. } => {
                walk_expr(value, &mut out);
            }
            Item::ExprStatement(e) => walk_expr(e, &mut out),
            _ => {}
        }
    }
    out
}

fn walk_stmt(stmt: &Stmt, out: &mut HashSet<String>) {
    match stmt {
        Stmt::Assign { target, value, .. } => {
            walk_assign_target(target, out);
            walk_expr(value, out);
        }
        Stmt::CompoundAssign { target, value, .. } => {
            walk_assign_target(target, out);
            walk_expr(value, out);
        }
        Stmt::Let { value, .. } => walk_expr(value, out),
        Stmt::Return(Some(e), _) => walk_expr(e, out),
        Stmt::Expr(e, _) => walk_expr(e, out),
        Stmt::If { cond, body, elifs, else_body, .. } => {
            walk_expr(cond, out);
            for s in body { walk_stmt(s, out); }
            for (c, b) in elifs {
                walk_expr(c, out);
                for s in b { walk_stmt(s, out); }
            }
            if let Some(b) = else_body {
                for s in b { walk_stmt(s, out); }
            }
        }
        Stmt::While { cond, body, .. } => {
            walk_expr(cond, out);
            for s in body { walk_stmt(s, out); }
        }
        Stmt::For { start, end, step, body, .. } => {
            walk_expr(start, out);
            walk_expr(end, out);
            if let Some(s) = step { walk_expr(s, out); }
            for s in body { walk_stmt(s, out); }
        }
        Stmt::ForIn { iterable, body, .. } => {
            walk_expr(iterable, out);
            for s in body { walk_stmt(s, out); }
        }
        Stmt::Switch { expr, cases, default, .. } => {
            walk_expr(expr, out);
            for (c, b) in cases {
                walk_expr(c, out);
                for s in b { walk_stmt(s, out); }
            }
            if let Some(b) = default {
                for s in b { walk_stmt(s, out); }
            }
        }
        _ => {}
    }
}

fn walk_assign_target(target: &vpy_parser::AssignTarget, out: &mut HashSet<String>) {
    if let vpy_parser::AssignTarget::Index { target, index, .. } = target {
        walk_expr(target, out);
        walk_expr(index, out);
    }
}

fn walk_expr(expr: &Expr, out: &mut HashSet<String>) {
    match expr {
        Expr::Call(info) => {
            let name = info.name.to_uppercase();
            // 4-arg DRAW_VECTOR routes through vpy_draw_vector_ex (mirror form).
            if name == "DRAW_VECTOR" && info.args.len() >= 4 {
                out.insert("DRAW_VECTOR_EX".to_string());
            }
            out.insert(name);
            for a in &info.args { walk_expr(a, out); }
        }
        Expr::MethodCall(info) => {
            walk_expr(&info.target, out);
            for a in &info.args { walk_expr(a, out); }
        }
        Expr::Binary { left, right, .. }
        | Expr::Compare { left, right, .. }
        | Expr::Logic { left, right, .. } => {
            walk_expr(left, out);
            walk_expr(right, out);
        }
        Expr::Not(e) | Expr::BitNot(e) => walk_expr(e, out),
        Expr::Index { target, index } => {
            walk_expr(target, out);
            walk_expr(index, out);
        }
        Expr::FieldAccess { target, .. } => walk_expr(target, out),
        Expr::List(items) => for it in items { walk_expr(it, out); },
        _ => {}
    }
}

// ─── Tests ────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    fn parse(src: &str) -> Module {
        let tokens = vpy_parser::lex(src).expect("lex");
        vpy_parser::parser::parse(tokens, "test").expect("parse")
    }

    #[test]
    fn test_minimal_program_uses_nothing() {
        let m = parse("def main():\n    pass\n\ndef loop():\n    x = 1\n");
        let u = analyze(&m);
        for g in ["ENEMIES", "LEVEL", "MUSIC", "SFX", "TEXT", "JOYSTICK",
                  "CIRCLE", "RECT", "BEZIER", "DRAW_VECTOR", "DRAW_VECTOR_3D"] {
            assert!(!u.has(g), "{g} should NOT be used by a minimal program");
        }
    }

    #[test]
    fn test_intro_style_program() {
        // DRAW_VECTOR_3D + DRAW_VECTOR + PRINT_TEXT + SET_TEXT_SIZE +
        // SET_INTENSITY + PLAY_MUSIC — like examples/vectrex_studio_intro.
        let m = parse(concat!(
            "def main():\n",
            "    PLAY_MUSIC(\"jingle\")\n",
            "    SET_TEXT_SIZE(8)\n",
            "\n",
            "def loop():\n",
            "    SET_INTENSITY(sin(3))\n",
            "    DRAW_VECTOR_3D(\"logo\", 0, 1, 2, 0, 0)\n",
            "    DRAW_VECTOR(\"text\", 0, -40)\n",
            "    PRINT_TEXT(-50, -80, \"HELLO\")\n",
        ));
        let u = analyze(&m);
        for g in ["DRAW_VECTOR", "DRAW_VECTOR_3D", "SIN_TABLE", "TRIG",
                  "TEXT", "MUSIC", "PSG"] {
            assert!(u.has(g), "{g} SHOULD be used by intro-style program");
        }
        for g in ["ENEMIES", "LEVEL", "LEVEL_COLLISION", "JOYSTICK", "SFX",
                  "CIRCLE", "RECT", "FILLED_RECT", "POLYGON", "ARC", "ELLIPSE",
                  "BEZIER", "BEZIER_QUAD", "DRAW_LINE", "ANIM", "MOVE"] {
            assert!(!u.has(g), "{g} should NOT be used by intro-style program");
        }
    }

    #[test]
    fn test_enemies_pull_transitive_deps() {
        let m = parse(concat!(
            "def main():\n",
            "    LOAD_LEVEL(\"lvl1\")\n",
            "\n",
            "def loop():\n",
            "    UPDATE_ENEMIES()\n",
            "    DRAW_ENEMIES()\n",
        ));
        let u = analyze(&m);
        // ENEMIES pulls LEVEL_COLLISION (vpy_level_collision_x), RAND
        // (wander AI), DRAW_VECTOR_EX and ANIM (vpy_draw_enemies).
        for g in ["ENEMIES", "LEVEL", "LEVEL_COLLISION", "RAND",
                  "DRAW_VECTOR_EX", "ANIM"] {
            assert!(u.has(g), "{g} SHOULD be enabled via enemies/level usage");
        }
        assert!(!u.has("MUSIC"), "MUSIC should stay off");
        assert!(!u.has("TEXT"), "TEXT should stay off");
    }

    #[test]
    fn test_calls_inside_expressions_are_found() {
        // Builtins referenced only inside conditions / nested expressions.
        let m = parse(concat!(
            "def loop():\n",
            "    if J1_BTN1() == 1:\n",
            "        x = GET_ENEMY_X(0) + rand()\n",
        ));
        let u = analyze(&m);
        assert!(u.has("JOYSTICK"));
        assert!(u.has("PSG"), "JOYSTICK requires PSG (psg_read)");
        assert!(u.has("ENEMIES"));
        assert!(u.has("RAND"));
    }

    #[test]
    fn test_draw_vector_mirror_form_pulls_ex() {
        let m = parse("def loop():\n    DRAW_VECTOR(\"s\", 0, 0, 1)\n");
        let u = analyze(&m);
        assert!(u.has("DRAW_VECTOR"));
        assert!(u.has("DRAW_VECTOR_EX"), "4-arg DRAW_VECTOR routes through vpy_draw_vector_ex");
        let m3 = parse("def loop():\n    DRAW_VECTOR(\"s\", 0, 0)\n");
        let u3 = analyze(&m3);
        assert!(!u3.has("DRAW_VECTOR_EX"), "3-arg DRAW_VECTOR does not need _ex");
    }

    #[test]
    fn test_draw_recording_gates_group() {
        let m = parse("def loop():\n    t = t + 1\n    DRAW_RECORDING(\"preview\", 0, 0, 45, t)\n");
        let u = analyze(&m);
        assert!(u.has("DRAW_RECORDING"), "DRAW_RECORDING call must enable its group");
        let m2 = parse("def loop():\n    DRAW_LINE(0, 0, 10)\n");
        let u2 = analyze(&m2);
        assert!(!u2.has("DRAW_RECORDING"), "no DRAW_RECORDING call → group off");
    }

    #[test]
    fn test_play_sample_gates_group() {
        let m = parse("def loop():\n    PLAY_SAMPLE(\"beep\")\n");
        let u = analyze(&m);
        assert!(u.has("PLAY_SAMPLE"), "PLAY_SAMPLE call must enable its group");
        let m2 = parse("def loop():\n    DRAW_LINE(0, 0, 10)\n");
        let u2 = analyze(&m2);
        assert!(!u2.has("PLAY_SAMPLE"), "no PLAY_SAMPLE call → group off");
    }

    #[test]
    fn test_full_has_everything() {
        let u = Usage::full();
        for (g, _, _) in GROUPS {
            assert!(u.has(g));
        }
    }
}
