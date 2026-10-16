# VPy — Vectrex Pseudo Python

A complete development environment for the Vectrex retro gaming console: Python-like language, 9-phase Rust compiler, JavaScript emulator, and Electron IDE.

## Project Layout

```
buildtools/   — 9-phase modular Rust compiler (the only compiler; binary `vpy_cli`)
  vpy_lsp/    — Language server (binary `vpy_lsp`), shares the compiler's parser
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

### M6809 codegen gotchas
- **Stack balance**: `PSHS`/`PULS` must balance; use `TMPVAL`/`TMPPTR` or a balanced `PSHS D`/`PULS D` for temporaries (see "m6809 Codegen" below).
- **DP register**: load RAM values before switching DP; with DP=$D0 read RAM with `>` (extended addressing).
- **Array stride**: 1 byte for u8/i8, 2 bytes for u16/i16.

### ARM backends (rp2350 / uvm2 / pitrex)
- **Runtime RAM is fixed `.equ` addresses**, not `.bss`: the VPy runtime area starts at `0x2007_F000` and user globals at `USER_RAM_START`. The layout and `RamAllocator` live in `buildtools/vpy_codegen/src/arm/ram_layout.rs` — read the values there, never hard-code them.
- **AAPCS**: SP must be 8-byte aligned at every `bl`.
- **Calls / frames**: parameters and locals live in a per-call stack frame addressed from r7 (`arm/frame.rs`, also used by pitrex): the prologue pushes `{r4…r7, lr}`, reserves the slots (keeping sp 8-byte aligned) and sets r7; every `return` branches to the one epilogue (`mov sp, r7`). Never give a parameter or local a global RAM slot, and any runtime routine that writes r7 must save it. Name rules are m6809's (`frames::function_scopes`); recursion is allowed on ARM.
- **Literal pools**: a function using `ldr rN, =SYMBOL` ends with `.ltorg` — never at a branch-landing site (pending literals would execute as instructions).
- **VIA port B is shared** by the joystick 4052 mux and the PSG BDIR/BC1: `bus_write($D000, …)` only inside `vpy_wait_recal` / `vpy_update_buttons` (frame start). Joystick axes are read from the SRAM cache.

## VPy Language

Python-like syntax, compiles to MC6809 assembly (and ARM for the cartridge targets). Key builtins: `SET_INTENSITY()`, `DRAW_LINE()`, `DRAW_VECTOR()`, `J1_X/Y()`, `PLAY_MUSIC()`. See `docs/COMPILER_STATUS.md` and `docs/MANUAL.md` for the full reference.

Writing VPy games:
- **Don't write `WAIT_RECAL()`, `AUDIO_UPDATE()`/`MUSIC_UPDATE()` or button reads**: the compiler injects `Wait_Recal` and `Read_Btns` at the start of every `loop()` and the audio update when music/SFX are used.
- **`main()` and `loop()` are separate scopes**: a variable declared in `main()` is not visible in `loop()`.
- **Assets are JSON** (`.vec`, `.vmus`, `.vsfx`, `.vanim`): never invent a text format, and check an asset exists before `DRAW_VECTOR("name")` / `PLAY_MUSIC("name")`.
- **`const` arrays live in ROM**; leave const arrays untyped (u8 const arrays break in complex games).

## IDE

- Electron + React + Monaco. State managed with Zustand.
- LSP server: `buildtools/vpy_lsp` (binary `vpy_lsp`, built with `cargo build --bin vpy_lsp`); `run-ide.sh` builds `vpy_cli` + `vpy_lsp` and copies them to `ide/electron/resources/`.
- Emulator: JSVecX running in renderer process.
- Integrated terminal (xterm.js + node-pty, `ide/electron/src/terminal.ts`). `claude` typed there gets the IDE's MCP tools via `--mcp-config` (shell integration in `ide/electron/src/shellIntegration.ts`).
- MCP: `ide/mcp-server/server.js` (stdio) → authenticated localhost TCP (port 9123+, per-run token) → `ide/electron/src/mcp/`. The IDE must be running. See `ide/mcp-server/README.md`.

## Important Docs

- `docs/INDEX.md` — navigation guide
- `docs/COMPILER_STATUS.md` — compiler CLI, phases, known issues, LSP
- `docs/MANUAL.md` — VPy language reference and builtins
- `docs/IDE_GUIDE.md` — IDE panels, emulator, debugger, MCP server
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

## m6809 Codegen: Temporaries, Arrays, Calls

- **Temporaries**: `TMPVAL` holds an operand only while the operand evaluated second is a plain name or literal. When it is an expression, the first operand waits on the hardware stack with a balanced `PSHS D` / `PULS D`; builtin arguments that are expressions are computed first into `VAR___HOIST<n>` slots. Never let a nested evaluation reuse a temporary that is still holding a value (a single shared `TMPVAL` made `if a + 0 > b:` compare against 0 — reported by Raúl García, fixed 2026-10-07).
- **`,S++` pops 2 bytes** (postbyte `$E1`), `,S+` pops 1 (`$E0`); the assembler encodes both correctly and tests pin it.
- **Arrays**: a global or const array name evaluates to its fixed data address (`#VAR_X_DATA` / `#ARRAY_X_DATA`); there is no pointer variable. Arrays are passed to functions as their base address; an indexed parameter's element size comes from the arrays passed at its call sites (`m6809/array_params.rs`). Element stride follows the declared type (u8/i8 = 1 byte, sign-extended for i8).
- **Usage scans** ("does the program use X?") all go through one exhaustive AST visitor, `m6809/ast_walk.rs`: a new AST node must be handled there.
- **Constants** fold at compile time (`m6809/consts.rs`); an unfoldable const is a compile error.
- **Errors** are collected during generation (`m6809/diagnostics.rs`) and fail the build; unknown calls, modules or members are compile errors with file:line on every target.
- **Codegen state is per thread** (`thread_local!` in `m6809/context.rs` and the multibank flags in `m6809/builtins.rs`): never add a process-global mode flag.
- **Calls / frames**: each function's parameters and locals are slots of a static frame (`VAR_<FUNC>__<NAME>` inside `FRAME_POOL`), overlaid by call graph in `m6809/frames.rs` (a frame starts after every caller's frame ends). The caller stores arguments straight into the callee's parameter slots (all computed first, on the stack, when any is not a plain name/literal) and the result returns in D. Recursion, wrong argument counts and undeclared names are compile errors. `VAR_ARG0-2` belong to the runtime helpers only; never pass user arguments through a global slot. Truth tests (`if f():`) must not trust the flags a value leaves: `expressions::emit_truth_value` adds `CMPD #0` when the code does not end in a load/ADDD/SUBD.
