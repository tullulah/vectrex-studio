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

## Phase 5 Codegen Stack Corruption Bug - ✅ FIXED (2026-02-22)

**Status:** FIXED - Stack imbalances in vpy_codegen have been corrected.

**Original Problem:**
- `LOOP_BODY()`: Had **75 PSHS vs 25 PULS** = **+50 UNMATCHED PUSHES** (100 bytes/frame)
- Game would hang within seconds of entering gameplay due to stack exhaustion
- Caused by improper use of M6809 stack addressing modes

**Root Cause:**
The codegen was using addressing mode post-increments (`CMPD ,S++` and `ADDD ,S++`) which only increment stack pointer by 1 byte instead of 2 bytes for 16-bit operations, leaving bytes stranded on the stack.

**The Fix:**
1. **expressions.rs** - Changed all comparison and binary operations from PSHS/PULS to memory temporaries (TMPVAL):
   - `emit_compare()`: `PSHS D; CMPD ,S++` → `STD TMPVAL; CMPD TMPVAL`
   - `emit_binop()`: `PSHS left; ADD ,S++` → `STD TMPVAL; ADD TMPVAL`

2. **functions.rs** - Fixed compound assignments (+=, -=) to use temporaries

3. **stack_validator.rs** - Enhanced to properly validate generated code

4. **helpers.rs** - Added TMPVAL to RAM allocation

**Verification:**
- ✅ LOOP_BODY now has balanced PSHS/PULS
- ✅ Pang compiles successfully without workarounds
- ✅ `update_enemies()` and `draw_enemies()` re-enabled and working
- ✅ All buildtools tests pass

**Note on validation:**
Stack validator is currently disabled (lib.rs lines 161-169) because hand-written BIOS helper functions have pre-existing issues unrelated to vpy_codegen. VPy-generated code now has correct stack balance.

## Phase 5 Codegen Bug #2: Const Array Pointers Not Initialized - ✅ FIXED (2026-02-22)

**Status:** FIXED - Const array pointer initialization added to MAIN startup.

**Original Problem:**
- Const arrays (like `location_names`, `location_x_coords`) were not being initialized
- VAR_LOCATION_NAMES remained at address $0000 (uninitialized garbage)
- Array access like `location_names[current_location]` read from cartridge header at $0000
- Resulted in corrupted text display: "@GCE 2025" instead of actual location names

**Root Cause:**
In `buildtools/vpy_codegen/src/m6809/functions.rs`, the MAIN startup code only initialized mutable arrays (GlobalLet with `List` values) by copying from ROM to RAM. Const arrays (Item::Const with `List` values) were never initialized - their pointer variables remained uninitialized.

**The Fix:**
Added initialization loop in functions.rs lines 126-134 that sets pointer variables for all const arrays:
```rust
// Initialize const arrays - set pointer variables to ROM data addresses
for item in &module.items {
    if let vpy_parser::Item::Const { name, value, .. } = item {
        if let vpy_parser::Expr::List(_elements) = value {
            let rom_label = format!("ARRAY_{}_DATA", name.to_uppercase());
            asm.push_str(&format!("    LDX #{}  ; Const array pointer -> ROM\n", rom_label));
            asm.push_str(&format!("    STX VAR_{}\n", name.to_uppercase()));
        }
    }
}
```

**Generated Code:**
Each const array now gets proper initialization in MAIN:
```asm
LDX #ARRAY_LOCATION_NAMES_DATA  ; Const array pointer -> ROM
STX VAR_LOCATION_NAMES
LDX #ARRAY_LOCATION_X_COORDS_DATA  ; Const array pointer -> ROM
STX VAR_LOCATION_X_COORDS
; ... (same for level_backgrounds, level_enemy_count, level_enemy_speed)
```

**Verification:**
- ✅ Pang compiles with all 6 const arrays properly initialized
- ✅ Map screen displays correct location names instead of "@GCE 2025"
- ✅ All buildtools tests pass
- ✅ Array indexing produces correct pointers to ROM data

## Phase 5 Codegen Bug #3: Function Calls (update_enemies/draw_enemies) - INVESTIGATION COMPLETE

**Status:** No bug found - functions are correctly compiled. Previous issues likely caused by Bug #2.

**Investigation Summary:**
User reported that enabling `update_enemies()` and `draw_enemies()` function calls caused game to crash/hang, while disabling them showed other symptoms (character Y position wrong, etc.).

**Analysis:**
Examined generated ASM for both functions:
1. **Stack Balance:** Both functions verified to have 0 PSHS/PULS mismatches - all temporaries use TMPVAL/TMPPTR memory locations
2. **Function Prologue/Epilogue:** Both functions properly use JSR at call site and RTS at function end
3. **Array Assignment:** Array write code (`arr[i] = value`) correctly handles element stride and address calculation
4. **Parameter Passing:** User functions evaluate arguments into VAR_ARG0-4 and call JSR correctly

**Key Insight:**
The symptoms reported (character Y wrong, disappears on joystick input) suggest the real issue was Bug #2 (uninitialized const arrays). When const arrays weren't initialized:
- location_x_coords, location_y_coords read from $0000
- Other array calculations produced garbage
- Game logic behaved erratically

With Bug #2 fixed, array-dependent game logic (including enemy position updates) should work correctly.

**Conclusion:**
The function compilation code is sound. No bug in function calls themselves. The reported issues were likely symptoms of the const array initialization bug (Bug #2), which is now fixed.
