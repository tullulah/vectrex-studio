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
