// ---------------------------------------------------------------------------
// `core/` is the legacy monolithic compiler — active development moved to
// `buildtools/`. The dead/unused-* warnings below are *expected* (lots of
// retired code paths still compiled because the LSP lives in this crate).
// Suppressing them at crate root keeps the warning budget at zero so the
// workspace can flip on `deny(warnings)` for the live crates without core
// dragging it down.
// ---------------------------------------------------------------------------
#![allow(dead_code)]
#![allow(unused_variables)]
#![allow(unused_assignments)]
#![allow(unused_mut)]
#![allow(unused_macros)]
#![allow(unreachable_patterns)]

pub mod lexer;
pub mod ast;
pub mod parser;
pub mod codegen;
pub mod target;
pub mod project;  // VPy project system (.vpyproj)
pub mod resolver; // Multi-file import resolution
pub mod unifier;  // AST unification for multi-file projects
pub mod library;  // VPy library system (.vpylib)
pub mod vecres;   // Vector resource format (.vec)
pub mod musres;   // Music resource format (.vmus)
pub mod sfxres;   // Sound effects resource format (.vsfx)
pub mod levelres; // Level resource format (.vplay)
pub mod vplay_analyzer; // Automatic .vplay analysis for dynamic buffer sizing
pub mod struct_layout; // Struct layout computation (Phase 2)
// pub mod linker;   // VPy linker (disabled - missing bincode dependency)
pub mod backend;
// Legacy emulator module removed; use vectrex_emulator crate instead.
// pub mod emulator; // intentionally disabled
#[cfg(not(target_arch = "wasm32"))]
pub mod lsp;
// Removed unused wasm feature gating after emulator extraction.

// Convenience re-exports
pub use lexer::*;
pub use parser::*;
pub use ast::*;
// wasm_api re-export removed (now provided via vectrex_emulator crate when compiling to WASM)
