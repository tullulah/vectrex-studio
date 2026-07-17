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

/// Map a VPy builtin name to its libvpy C symbol, if that builtin has been
/// migrated to the C runtime. Returns `None` for builtins still emitted inline.
///
/// The caller (`expressions.rs`) uses the returned symbol as the `bl` target in
/// place of the inline `pitrex_*` helper name; argument evaluation is unchanged.
pub fn libvpy_symbol(vpy_name: &str) -> Option<&'static str> {
    match vpy_name {
        "DRAW_CIRCLE" => Some("vpy_draw_circle"),
        _ => None,
    }
}

/// True if the inline `pitrex_*` body for this builtin must be SUPPRESSED
/// because it has been bridged to libvpy. `builtins.rs` gates the corresponding
/// `emit_pitrex_*()` call on `!is_bridged(..)`.
pub fn is_bridged(vpy_name: &str) -> bool {
    libvpy_symbol(vpy_name).is_some()
}
