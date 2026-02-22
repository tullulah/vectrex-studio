# VPy — Vectrex Pseudo Python

A complete development environment for the Vectrex retro gaming console: Python-like language, 9-phase Rust compiler, JavaScript emulator, and Electron IDE.

## Project Layout

```
buildtools/   — 9-phase modular Rust compiler (ACTIVE)
core/         — Legacy monolithic compiler (being retired)
ide/          — Electron IDE with React+Monaco frontend
  electron/   — Main process, IPC, bundled binaries
  frontend/   — React + Vite UI
  mcp-server/ — MCP bridge for AI tools (port 9123)
examples/     — VPy game examples (pang, animations, etc.)
docs/         — 187 docs; see docs/INDEX.md
```

## Compiler Pipeline (buildtools/)

```
Phase 1: vpy_loader         → ProjectInfo
Phase 2: vpy_parser         → Vec<Module> (AST)
Phase 3: vpy_unifier        → UnifiedModule
Phase 4: vpy_bank_allocator → BankLayout
Phase 5: vpy_codegen        → GeneratedIR (ASM)
Phase 6: vpy_assembler      → Vec<ObjectFile>
Phase 7: vpy_linker         → LinkedBinary + SymbolTable  ← ADDRESS SOURCE OF TRUTH
Phase 8: vpy_binary_writer  → .bin file
Phase 9: vpy_debug_gen      → .pdb file
```

Status: Phases 1–6 complete, Phase 7 in progress, Phases 8–9 planned.

## Build & Test

```bash
cd buildtools && cargo build --all    # Build all phases
cd buildtools && cargo test --all     # Run all phase tests
cd buildtools && cargo test -p <crate>  # Test one phase
```

## Key Rules

- **Only the linker (Phase 7) computes final addresses.** Never derive addresses elsewhere.
- **No interrupt vectors in cartridge ROM.** They live in BIOS ($E000-$FFFF).
- **Symbol naming**: `MODULE_symbol` (uppercase module prefix, original-case symbol).
- **Multibank**: Every bank uses `ORG $0000`. Helpers bank = `(total / bank_size) - 1`.
- **Tests required per phase**: single-bank case, multibank case, error case.

## VPy Language

Python-like syntax, compiles to MC6809 assembly. Key builtins: `WAIT_RECAL()`, `SET_INTENSITY()`, `DRAW_LINE()`, `J1_X/Y()`, `PLAY_MUSIC()`. See `docs/COMPILER_STATUS.md` for full reference.

## IDE

- Electron + React + Monaco. State managed with Zustand.
- LSP server: `ide/electron/resources/vpy_lsp` (Rust binary).
- Emulator: JSVecX running in renderer process.
- MCP server on port 9123 (IDE must be running first).

## Important Docs

- `docs/INDEX.md` — navigation guide
- `docs/COMPILER_STATUS.md` — opcodes, backlog, known issues
- `docs/SUPER_SUMMARY.md` — emulator architecture (32 sections)
- `docs/TIMING.md` — deterministic cycle model
- `buildtools/README.md` — phase-by-phase status

## Debugging Runtime Issues

**When a compiled VPy game hangs, crashes, or behaves incorrectly:**

1. **ALWAYS examine the generated ASM**, not just the VPy code. Use the `asm-expert` agent to:
   - Generate ASM: `cargo run --manifest-path buildtools/Cargo.toml --bin vpy_cli -- asm src/main.vpy > /tmp/main.asm`
   - Review the generated assembly for infinite loops, stack corruption, incorrect addressing
   - Look for patterns that match the reported bug (e.g., if game hangs after STATE_GAME transition, find STATE_GAME handler in ASM)

2. **Compiler bugs often manifest as:**
   - Infinite loops in generated code (check for missing increment counters)
   - Incorrect array indexing (off-by-one, wrong stride calculations)
   - Register corruption (values not preserved across function calls)
   - Stack issues (incorrect push/pop sequences, stack pointer mismanagement)

3. **Common VPy → ASM translation issues:**
   - Array access: stride calculations (1 byte for u8/i8, 2 bytes for u16/i16)
   - Variable updates at end-of-frame: check if writes are actually happening
   - State transitions: verify condition branches and flag preservation

## CRITICAL: Phase 5 Codegen Stack Corruption Bug - CONFIRMED REAL

**Bug Status:** CONFIRMED - Real stack imbalances found in actual generated code.

**Evidence:** When compiling `examples/pang/src/main.vpy`:
- `update_enemies()`: **29 PSHS vs 20 PULS** = **+9 unmatched pushes** (18 bytes left on stack!)
- `draw_enemies()`: **18 PSHS vs 12 PULS** = **+6 unmatched pushes** (12 bytes left on stack!)
- These imbalances cause RTS (function return) to jump to corrupted/invalid addresses, resulting in game hang

**Root cause analysis:**
The bug occurs in loops with IF statements that access arrays. Specifically in `vpy_codegen/src/m6809/` when generating:
1. Condition evaluation: `PSHS` pushes temporary values for comparison
2. Array indexing: `PSHS` for array base address
3. Branching logic: Conditional branches that skip certain PULS instructions on specific code paths

Result: Some branches exit the loop iteration with unpaired PSHS on the stack, which accumulate across iterations until stack corruption causes crashes.

**Pattern that breaks:**
```python
while i < MAX_ENEMIES:
    if enemy_active[i] == 1:  # Array access in IF condition
        # Loop continues with corrupted stack
```

**Fix requirement:** ALWAYS fix this at the compiler level in vpy_codegen. NEVER work around by:
- Commenting out problematic functions (this was a temporary workaround, not a solution)
- Restructuring code to avoid the pattern
- Using alternative syntax

**Compiler must be fixed:** Ensure Phase 5 codegen generates balanced PSHS/PULS pairs on **all code paths** (both taken and not-taken branches). Every function must return with stack depth = 0.

**Validation now in place:** Stack balance validator (`stack_validator.rs`) automatically checks all generated functions. Currently disabled to identify root cause, will be re-enabled once codegen is fixed.

**Next steps:**
1. Analyze vpy_codegen/src/m6809/expressions.rs and functions.rs
2. Identify which PSHS are not paired with corresponding PULS on all control flow paths
3. Refactor to ensure balanced stacks across all branches
4. Re-enable validator and verify all functions pass
5. Re-enable `update_enemies()` and `draw_enemies()` in examples/pang
