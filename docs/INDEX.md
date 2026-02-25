# Vectrex Studio — Documentation Index

All documentation lives in `docs/`. The only exception is `README.md` at the project root (quick overview and quick start).

---

## Release Notes

| File | Description |
|------|-------------|
| [CHANGELOG.md](CHANGELOG.md) | Full version history |
| [blog/2026-02-25-v0.1.1.md](blog/2026-02-25-v0.1.1.md) | v0.1.1 — Math builtins, MOVE, 16-seg circles, snippets |

---

## Getting Started

| File | Description |
|------|-------------|
| [START_HERE.md](START_HERE.md) | Entry point — where to go depending on your goal |
| [SETUP.md](SETUP.md) | Full installation and build guide |

---

## Compiler & Planning

| File | Description |
|------|-------------|
| [COMPILER_STATUS.md](COMPILER_STATUS.md) | Both backends (Core and Buildtools), phase table, known issues |
| [TODO.md](TODO.md) | Variable-sized types implementation roadmap (9-phase breakdown with effort estimates) |
| [STACK_VALIDATOR.md](STACK_VALIDATOR.md) | Stack balance validation — catches PSHS/PULS imbalances at compile time |

---

## Language Reference

| File | Description |
|------|-------------|
| [MANUAL.md](MANUAL.md) | Full VPy language manual (syntax, types, builtins, gotchas) |
| [VPY_RESERVED_WORDS.md](VPY_RESERVED_WORDS.md) | Reserved keywords and built-in names that cannot be used as variable names |
| [PYTHON_VS_VPY.md](PYTHON_VS_VPY.md) | Key differences between Python and VPy |

---

## IDE

| File | Description |
|------|-------------|
| [IDE_GUIDE.md](IDE_GUIDE.md) | IDE panels, build/run workflow, debugger, PyPilot, MCP server, project format |
| [OLLAMA_SETUP.md](OLLAMA_SETUP.md) | Setting up Ollama for local AI (PyPilot) — models, installation, troubleshooting |
| [DEBUG_SYMBOLS_IMPLEMENTATION.md](DEBUG_SYMBOLS_IMPLEMENTATION.md) | PDB debug symbol format and how the debugger uses it |

---

## Asset Formats

| File | Description |
|------|-------------|
| [GUIDE_SFX_README.md](GUIDE_SFX_README.md) | Overview of the `.vsfx` sound effect format |
| [GUIDE_SFX_CREATION.md](GUIDE_SFX_CREATION.md) | How to create sound effects |
| [GUIDE_SFX_EXAMPLES.md](GUIDE_SFX_EXAMPLES.md) | Example `.vsfx` files with commentary |

**Supported asset formats:** `.vec` (vectors), `.vmus` (music), `.vsfx` (sound effects). `.vanim` (animation) is not yet implemented.

---

## Hardware Reference

| File | Description |
|------|-------------|
| [6809_opcodes.md](6809_opcodes.md) | Complete MC6809 opcode table with addressing modes and cycle counts |
| [MEMORY_MAP.md](MEMORY_MAP.md) | Vectrex memory map (RAM, ROM, BIOS, hardware registers) |
| [AUTOMATIC_BANK_SWITCHING.md](AUTOMATIC_BANK_SWITCHING.md) | Multibank ROM banking architecture and switching mechanism |
| [VECTOR_DRAWING_EXACT_SEQUENCE.md](VECTOR_DRAWING_EXACT_SEQUENCE.md) | Exact draw sequence for vector rendering |
| [VECTOR_MULTIPATH_LIMITATION.md](VECTOR_MULTIPATH_LIMITATION.md) | Known limitation: multipath vector drawing |

---

## Legacy / Future Reference

These files describe the Rust/WASM emulator that was explored but not adopted. The current emulator is JSVecX. Kept for potential future use.

| File | Description |
|------|-------------|
| [TIMING.md](TIMING.md) | Rust emulator timing model: cycle_frame, VIA timers, frame sync |
| [VECTOR_MODEL.md](VECTOR_MODEL.md) | Rust emulator analog integrator: BeamSegment, auto-drain |
| [ARCH_COMPARISON.md](ARCH_COMPARISON.md) | Comparison between the abandoned Rust emulator and vectrexy |

---

## Documentation Rules

- All docs must be written in **English**.
- All documentation files go in `docs/`. No `.md` files in the project root (except `README.md`).
- No session notes, bug fix reports, or completion reports. Document what *is*, not what *was done*.
- When a feature is implemented, update the relevant reference doc — don't create a new `_COMPLETE.md` file.
