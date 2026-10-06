# Vectrex Studio — Getting Started

**Vectrex Studio** is a complete development environment for the Vectrex console: a high-level language (VPy), a 9-phase compiler, a custom JSVecX emulator, and an IDE built on Electron + Monaco.

---

## First time in the project

1. **[SETUP.md](SETUP.md)** — Install all dependencies and build the project from scratch.
2. **[MANUAL.md](MANUAL.md)** — VPy language reference: syntax, types, builtins, examples.
3. **[COMPILER_STATUS.md](COMPILER_STATUS.md)** — Current compiler state (which phases are implemented, what's pending).

---

## I want to develop a game

→ Start with [MANUAL.md](MANUAL.md) and the `examples/` folder in the project root.

## I want to contribute to the compiler

→ Read [COMPILER_STATUS.md](COMPILER_STATUS.md) to see the status of each phase and next steps.
→ Source code lives in `buildtools/` (Rust, one crate per phase).

## I want to understand the emulator

→ [TIMING.md](TIMING.md) — Deterministic timing model (cycles, VIA, frame sync).
→ [VECTOR_MODEL.md](VECTOR_MODEL.md) — Analog integrator, segment merging, auto-drain.
→ [MEMORY_MAP.md](MEMORY_MAP.md) — Vectrex memory map.

## I want to work on the IDE

→ Source code lives in `ide/` (Electron shell + React/TypeScript frontend).
→ LSP server: `buildtools/vpy_lsp/` (binary: `vpy_lsp`, built with `cargo build --bin vpy_lsp`; shares the compiler's parser)
→ MCP server: `ide/mcp-server/` (Node.js)

---

## Full index

→ [INDEX.md](INDEX.md)
