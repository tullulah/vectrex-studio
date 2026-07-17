//! libvpy bridge (PROOF OF CONCEPT)
//!
//! De-risks the larger refactor that will replace the ~4600 lines of inline
//! ARM-emitting builtin bodies in `builtins.rs` with calls into `libvpy`
//! (`ide/electron/resources/vpy-c/vpy.c`) — the SAME builtins written in C on
//! the PiTrex SDK contract, which C programs already link against.
//!
//! Mechanism: for a builtin listed here, the codegen evaluates its arguments
//! into AAPCS registers (exactly as the generic call path already does) and
//! emits `bl vpy_<name>` instead of the inline `pitrex_<name>` body. The inline
//! body is then SUPPRESSED in `builtins.rs` so only the call remains.
//!
//! Both mechanisms coexist during the migration: only builtins whose name is
//! returned by [`libvpy_symbol`] are bridged; every other builtin is still
//! emitted inline.
//!
//! POC scope: exactly one builtin — `DRAW_CIRCLE` → `vpy_draw_circle`. The
//! inline `pitrex_draw_circle(r0=cx,r1=cy,r2=radius,r3=brightness)` already uses
//! AAPCS with the identical argument order/semantics as the C prototype
//! `void vpy_draw_circle(int cx,int cy,int r,int b)` (both scale VPy units by
//! 127 internally), so no argument marshalling shim is needed.
//!
//! BLOCK 1 scope: the STATELESS builtins whose inline ARM body is semantically
//! identical to their libvpy C function — the stateless draws
//! `DRAW_RECT`/`DRAW_FILLED_RECT`/`DRAW_ELLIPSE` (absolute, no MOVE offset) and
//! the pure-math helpers `abs/min/max/clamp/sin/cos/sqrt`.
//!
//! BLOCK 2 scope: the MOVE + DRAW_LINE state-pair — they share the beam origin
//! (libvpy `s_cur_x/y` vs the inline `PITREX_MOVE_X/Y`), so they are bridged
//! together or not at all. Verified bit-identical net output (see the
//! per-arm comment).
//!
//! BLOCK 3 scope: the previously-divergent builtins `atan2`, `rand`,
//! `rand_range` — libvpy's C has been rewritten to port the inline algorithm
//! BIT-EXACTLY (same atan LUT + octant/quadrant math; same LCG constants, output
//! width and zero seed), so their call sites are now remapped too. Their inline
//! `pitrex_*` bodies stay EMITTED (call-site remap only) because they share code
//! with other still-inline helpers (`atan2` shares the math-helpers emit block +
//! `pitrex_atan_lut`; `pitrex_random` is called by the inline enemy AI).
//!
//! BLOCK 4 scope: the TEXT builtins `PRINT_TEXT` / `PRINT_NUMBER` /
//! `SET_TEXT_SIZE` — the last previously-diverging group. libvpy now carries the
//! SDK vector-font glyph data (ported from `vectorFont.i`) and renders it via
//! `v_directDraw32`, reproducing the inline SDK-font text (same glyphs,
//! positions and size) instead of libvpy's old hand-built 4x6 table. The inline
//! `pitrex_print_text` stays EMITTED (call-site remap only) because the
//! always-emitted `pitrex_print_msg` (PRINT_MSG) forwards to it — the same
//! shared-symbol pattern as atan2/rand.
//!
//! Still inline: no C counterpart (`pow`, `tan`), a different arg shape
//! (`DRAW_POLYGON`), or a no-op inline stub (`beep`). See the per-arm comments in
//! [`libvpy_symbol`] for the exact reason each remains deferred.

/// Map a VPy builtin name to its libvpy C symbol, if that builtin has been
/// migrated to the C runtime. Returns `None` for builtins still emitted inline.
///
/// The caller (`expressions.rs`) uses the returned symbol as the `bl` target in
/// place of the inline `pitrex_*` helper name; argument evaluation is unchanged.
pub fn libvpy_symbol(vpy_name: &str) -> Option<&'static str> {
    match vpy_name {
        // ── POC: first bridged builtin ──────────────────────────────────────
        "DRAW_CIRCLE" => Some("vpy_draw_circle"),

        // ── BLOCK 1: stateless builtins ─────────────────────────────────────
        // Stateless draws — verified ABSOLUTE (no MOVE offset), same arg
        // order/ABI, same VPy×127 scaling as their inline `pitrex_*` bodies.
        //   DRAW_RECT / DRAW_FILLED_RECT: coordinates are bit-exact vs inline.
        //   DRAW_ELLIPSE: identical 16-gon algorithm; vertices differ from the
        //   inline table by <1 VPy unit (libvpy rounds each vertex to integer
        //   VPy units before the ×127 scale) — the SAME quantization already
        //   accepted for the bridged DRAW_CIRCLE (they share the geometry).
        "DRAW_RECT"        => Some("vpy_draw_rect"),
        "DRAW_FILLED_RECT" => Some("vpy_draw_filled_rect"),
        "DRAW_ELLIPSE"     => Some("vpy_draw_ellipse"),

        // Pure math — no state, no draw. abs/min/max/clamp are bit-identical to
        // the inline helpers; sin/cos use a byte-identical LUT; sqrt matches the
        // inline VFP path for every input a VPy game can produce (verified
        // identical over 0..1e6). Accepted in both lower- and upper-case because
        // `libvpy_symbol` is keyed on the raw VPy call name.
        "abs" | "ABS"     => Some("vpy_abs"),
        "min" | "MIN"     => Some("vpy_min"),
        "max" | "MAX"     => Some("vpy_max"),
        "clamp" | "CLAMP" => Some("vpy_clamp"),
        "sin" | "SIN"     => Some("vpy_sin"),
        "cos" | "COS"     => Some("vpy_cos"),
        "sqrt" | "SQRT"   => Some("vpy_sqrt"),

        // ── BLOCK 2: the MOVE + DRAW_LINE state-pair ────────────────────────
        // These share the beam-origin state so they MUST be bridged together:
        // MOVE stores the origin, DRAW_LINE reads it. The inline pair stores the
        // origin PRE-SCALED (PITREX_MOVE_X/Y = arg*127) and adds it to the
        // ×127-scaled endpoints; libvpy stores it in VPy units (s_cur_x/y) and
        // scales in raw_line. The NET result is bit-identical — worked example
        // MOVE(-60,60); DRAW_LINE(0,0,40,-40,80) yields
        // v_directDraw32(-7620, 7620, -2540, 2540, 80) on BOTH paths (segment
        // (-60,60)->(-20,20) in VPy units, ×127). Arg order and the 5th-arg
        // brightness match. The inline MOVE additionally issues a redundant
        // v_directMove32 (beam physically moved) that no absolute-coordinate
        // draw consumes, so dropping it changes no output. No OTHER inline
        // builtin reads PITREX_MOVE_X/Y (only the inline DRAW_LINE did), and
        // DRAW_VECTOR/DRAW_POLYGON seed PITREX_CUR_X/Y themselves rather than
        // relying on a prior MOVE — so the pair is self-consistent once bridged.
        //   Note: there is no VPy-level DRAW_LINE_REL/DRAW_TO builtin —
        //   pitrex_draw_line_rel is an INTERNAL helper of DRAW_VECTOR/POLYGON
        //   (each seeds PITREX_CUR itself), not reachable from a VPy call, so it
        //   is not part of this group.
        "MOVE"      => Some("vpy_move"),
        "DRAW_LINE" => Some("vpy_draw_line"),

        // ── BLOCK 3: reconciled divergent-implementation builtins ───────────
        // These previously DIFFERED from the inline body; libvpy's C has been
        // rewritten to port the inline algorithm bit-exactly, so the call site
        // can now be remapped. Unlike the draw/state builtins above, their inline
        // `pitrex_*` bodies are NOT suppressed (only the call site is remapped) —
        // exactly like the already-bridged pure-math helpers (sqrt/abs/…). The
        // reason each inline body stays emitted:
        //   atan2 — the inline `pitrex_atan2` shares one emit block
        //     (`emit_pitrex_math_helpers`) with sqrt/pow AND the shared
        //     `pitrex_atan_lut` + `.ltorg`; it can't be split out without
        //     breaking those symbols, so it stays emitted as dead code.
        //   rand/rand_range — `pitrex_random` is called DIRECTLY by the inline
        //     enemy-AI (`pitrex_update_enemies`/wander) ARM helpers, so it must
        //     stay emitted. VPy-level rand()/rand_range() are remapped to
        //     vpy_rand/vpy_rand_range (own `s_rng`, seeded 0, same LCG => same
        //     sequence). CAVEAT: a program that calls BOTH VPy rand() AND the
        //     pitrex enemy-AI builtins now draws from two INDEPENDENT streams
        //     (each deterministic from seed 0) instead of one shared RAND_SEED
        //     counter — a subtle change only for that combination.
        "atan2" | "ATAN2"           => Some("vpy_atan2"),
        "rand" | "RAND"             => Some("vpy_rand"),
        "rand_range" | "RAND_RANGE" => Some("vpy_rand_range"),

        // ── BLOCK 4: the TEXT builtins ──────────────────────────────────────
        // Previously the last DIVERGING group: the inline `pitrex_print_text`
        // draws with the PiTrex SDK vector font via `v_printString`, while
        // libvpy's `vpy_print_text` used its OWN hand-built 4x6 glyph table
        // (different glyphs). Reconciled by porting the SDK vector-font glyph
        // data (the ACTIVE BLOW_UP=15 table from vectorFont.i) into libvpy and
        // reimplementing `vpy_print_text` to walk it and draw each stroke via
        // `v_directDraw32` — reproducing v_printString's glyph shapes, advance
        // and scale plus the inline sequence's -8 baseline, 127/128 pre-scale
        // and default textSize=8. Same font, positions and size as the inline
        // SDK text; glyph GEOMETRY is beam-identical (same v_directDraw32
        // segment count/coords). NOT beam-identical in brightness only: the
        // inline hard-codes 0x50 and v_printString applies the SDK's
        // intensityMul, whereas libvpy honors SET_INTENSITY (s_intensity) —
        // exactly like every other bridged libvpy draw. `v_printString` is NOT
        // added to the minimal SDK contract (one font copy, drawn via
        // v_directDraw32 on all three runtimes).
        //
        // SHARED-SYMBOL CAVEAT (why the inline bodies stay EMITTED, call-site
        // remap only — the atan2/rand pattern): `emit_pitrex_msg_system` is
        // emitted UNCONDITIONALLY (builtins.rs) and its `pitrex_print_msg`
        // forwards to `pitrex_print_text`, so suppressing the inline
        // `pitrex_print_text` would leave PRINT_MSG's `bl pitrex_print_text`
        // unresolved. PRINT_MSG keeps using the inline SDK-font path (same
        // ported glyphs, so it looks identical). The `PITREX_TEXT_SIZE` RAM
        // slot is a `.equ` alias always defined in functions.rs regardless of
        // bridging, so no data symbol is lost either. `pitrex_print_number` /
        // `pitrex_set_text_size` are not shared, but stay emitted too for
        // consistency (harmless dead code once their call sites are remapped).
        "PRINT_TEXT"                => Some("vpy_print_text"),
        "PRINT_NUMBER"              => Some("vpy_print_number"),
        "SET_TEXT_SIZE"             => Some("vpy_set_text_size"),

        // ── BLOCK 5: INPUT builtins (J1 only) ───────────────────────────────
        // The inline `pitrex_j1_x/y` do `ldrsb` of the SDK globals
        // currentJoy1X/currentJoy1Y (int8_t, -128..127); libvpy's vpy_j1_x/y
        // now read the SAME globals directly (was a stale s_jx/s_jy snapshot
        // only refreshed by vpy_frame_begin, which the VPy game loop never
        // calls). Range/sign are byte-identical.
        //
        // Buttons: the inline `pitrex_j1_btnN` returns
        // `(currentButtonState >> (N-1)) & 1` (btn1->bit0 … btn4->bit3);
        // vpy_j1_button(n) returns the identical `(currentButtonState>>(n-1))&1`.
        // The VPy builtins J1_BUTTON_1..4 / J1_BTN1..4 are NAME-BAKED (no
        // runtime arg), so the codegen (expressions.rs) intercepts the
        // vpy_j1_button symbol and emits `mov r0,#N; bl vpy_j1_button` — the
        // constant N is passed in r0 exactly as the C prototype expects.
        //
        // UPDATE_BUTTONS: inline `pitrex_update_buttons` = `bl v_readButtons` +
        // `bl v_readJoystick1Analog`; vpy_update_buttons does the identical two
        // SDK calls. (The VPy game loop already calls these each frame; this is
        // the explicit mid-frame re-read.)
        //
        // NOT bridged: J2_* — the sim SDK contract (pitrex-sim) exposes ONLY J1
        // (currentJoy1X/Y, currentButtonState; no currentJoy2X/Y, no
        // v_readJoystick2Analog). Adding vpy_j2_* would fail to link against the
        // integer-only C runtime's minimal contract and require extending the
        // simulator host (sdk_host.c + JS hooks) — deferred. The inline J2 path
        // (bits 4-7, currentJoy2X/Y) still serves HW/rp2350.
        "J1_X" => Some("vpy_j1_x"),
        "J1_Y" => Some("vpy_j1_y"),
        "J1_BTN1" | "J1_BUTTON_1"
        | "J1_BTN2" | "J1_BUTTON_2"
        | "J1_BTN3" | "J1_BUTTON_3"
        | "J1_BTN4" | "J1_BUTTON_4" => Some("vpy_j1_button"),
        "UPDATE_BUTTONS" => Some("vpy_update_buttons"),

        // Deferred (NOT bridged yet):
        //   beep       — the inline `pitrex_beep` is a NO-OP stub (silent; the
        //                allocated BEEP_FRAMES_LEFT slot is never used on pitrex,
        //                unlike the m6809 frame-decay model). libvpy's vpy_beep
        //                emits an actual tone, so bridging would turn silence into
        //                sound — a behavior change, not a reconciliation. There is
        //                no inline algorithm to make bit-identical, so it stays
        //                deferred (see report).
        //   pow/tan    — no vpy_pow/vpy_tan in libvpy.
        //   DRAW_POLYGON — arg-shape mismatch: VPy passes a flat count-first
        //                vertex list; vpy_draw_polygon takes (const int* xy,n,b).
        _ => None,
    }
}

/// True if the inline `pitrex_*` body for this builtin must be SUPPRESSED
/// because it has been bridged to libvpy. `builtins.rs` gates the corresponding
/// `emit_pitrex_*()` call on `!is_bridged(..)`.
pub fn is_bridged(vpy_name: &str) -> bool {
    libvpy_symbol(vpy_name).is_some()
}
