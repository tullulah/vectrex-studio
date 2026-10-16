//! Symbol naming shared by every compiler phase.
//!
//! The unifier (Phase 3) renames every top-level symbol of an imported module
//! with [`mangle`]; the backends never build a cross-module name themselves, they
//! only read the names the unifier wrote into the AST. The m6809 backend turns a
//! unified name into an assembly label with [`m6809_label`], at the definition
//! AND at every call site, so the two can never disagree.
//!
//! Naming rule (`MODULE_symbol`):
//! - a symbol defined in an imported module `physics` is `PHYSICS_symbol`:
//!   upper-case module prefix, the symbol spelled as it is DEFINED;
//! - a symbol of the entry module has no prefix and is canonicalised to upper
//!   case (the long-standing behaviour builtins and the backends rely on).
//!
//! Identifiers are case-insensitive: `physics.CLAMP_X()` and `physics.clamp_x()`
//! both resolve to the definition `clamp_x`, so both become `PHYSICS_clamp_x`.

/// Upper-case prefix for a module name (`physics` → `PHYSICS`).
/// Characters that cannot appear in an assembler label become `_`.
pub fn module_prefix(module: &str) -> String {
    module
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() || c == '_' { c.to_ascii_uppercase() } else { '_' })
        .collect()
}

/// Unified name of `symbol` defined in the imported module `module`.
///
/// `symbol` must be spelled as at its definition (the unifier resolves case
/// variants to the definition before calling this).
pub fn mangle(module: &str, symbol: &str) -> String {
    format!("{}_{}", module_prefix(module), symbol)
}

/// Unified name of `symbol` defined in the entry module (no prefix).
pub fn entry_symbol(symbol: &str) -> String {
    symbol.to_uppercase()
}

/// Assembly label the m6809 backend uses for a unified function name.
/// Used for both the definition (`LABEL:`) and every `JSR LABEL`.
pub fn m6809_label(unified_name: &str) -> String {
    unified_name.to_uppercase()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mangle_keeps_symbol_case() {
        assert_eq!(mangle("physics", "clamp_x"), "PHYSICS_clamp_x");
        assert_eq!(mangle("physics", "Step"), "PHYSICS_Step");
        assert_eq!(mangle("my-mod", "x"), "MY_MOD_x");
    }

    #[test]
    fn entry_symbols_are_upper_case() {
        assert_eq!(entry_symbol("player_x"), "PLAYER_X");
    }

    #[test]
    fn m6809_label_is_case_insensitive_for_callers() {
        assert_eq!(m6809_label(&mangle("physics", "clamp_x")), "PHYSICS_CLAMP_X");
        assert_eq!(m6809_label("PHYSICS_CLAMP_X"), "PHYSICS_CLAMP_X");
    }
}
