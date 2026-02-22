# Compiler Status

Vectrex Studio has two compiler backends. Both are selectable from the IDE Settings panel.

---

## Two-Backend Architecture

### Why two backends?

The **Core** compiler (`core/`) was the original implementation and worked reliably. When PDB debug symbol generation was added, it caused enough structural problems that a clean-room rewrite was started. The new **Buildtools** compiler (`buildtools/`) was designed from scratch with a modular, multi-crate pipeline to properly support PDB generation and multibank ROMs.

Both backends share the same VPy language input, but differ in architecture, capabilities, and stability.

---

## Backend 1: Core (Legacy)

**Location:** `core/src/codegen.rs`, `core/src/lexer.rs`, `core/src/parser.rs`
**CLI binary:** `vectrexc`
**Status:** ✅ Stable

### What it does

Single-pass pipeline: lexer → parser → AST → optimizer → codegen → MC6809 assembly → binary.

The assembler is built-in (no lwasm dependency). The LSP server (`core/src/lsp.rs`) also uses the same lexer and parser.

### Supported features

**Language:**
- Functions with up to 4 positional parameters
- `for`, `while`, `if/elif/else`, `switch/case`, `break`, `continue`, `return`
- `let` (stack locals) and global `var`
- Arithmetic, bitwise, logical, comparison operators (16-bit unsigned)
- Chained comparisons (`a < b < c`)
- String literals (high-bit terminated for BIOS `Print_Str_d`)
- `const` values
- `META` directives (TITLE, COPYRIGHT, MUSIC) for ROM header

**VectorList DSL** (embedded in `.vpy`):
- `MOVE`, `SET_INTENSITY`, `SET_ORIGIN`, `RECT`, `POLYGON`, `CIRCLE`, `ARC`, `SPIRAL`

**Optimizations:**
- Constant folding (arithmetic, bitwise, shifts)
- Dead code elimination
- Constant propagation
- Dead store elimination
- Peephole patterns (power-of-two mul/div → shifts)

**MC6809 assembler — implemented opcodes (selection):**
- Load/store: LDA, LDB, LDD, LDU, LDX, LDY, STA, STB, STD, STU, STX, STY
- Arithmetic 8-bit: ADDA, ADDB, SUBA, SUBB, ANDA, ANDB, ORA, ORB, EORA, EORB
- Arithmetic 16-bit: ADDD, SUBD, CMPD, ABX
- Shifts: ASLA, ASLB, LSRA, LSRB, ROLA, ROLB, RORA, RORB
- Branches: BRA, BEQ, BNE, BLT, BGT, BLE, BGE, BCS, BCC, BMI, BPL, BHI, BLO, BHS
- Long branches: LBRA, LBEQ, LBNE, LBLT, LBGT, LBLE, LBGE, LBCS, LBCC, LBMI, LBPL
- Control: JSR, RTS, BSR, LBSR, JMP, RTI, WAI, NOP
- Stack: PSHS, PULS, PSHU, PULU
- Misc: CLR, COM, NEG, INC, DEC, TST, CLRA, CLRB, COMA, COMB, NEGA, NEGB, INCA, INCB, DECA, DECB, TSTA, TSTB, MUL, EXG, TFR
- Addressing modes: immediate, direct, extended, indexed (basic: ,X ,Y ,U ,S)

**Asset pipeline:**
- `.vec` vector lists
- `.vmus` music (PSG AY-3-8912)
- `.vsfx` sound effects

### Known limitations

- **Single-bank only** — always outputs a 32KB ROM (padded to 32KB, fixed size)
- Indexed addressing with numeric offsets (e.g. `5,X`, `-2,Y`) is limited
- LEA instructions (LEAX, LEAY, LEAU, LEAS) not implemented
- PC-relative addressing (`label,PCR`) not implemented
- No debug symbol (PDB) generation — this was the motivation for buildtools

---

## Backend 2: Buildtools (New)

**Location:** `buildtools/` (one Rust crate per phase)
**CLI binary:** `vectrexc` (buildtools mode) via `vpy_cli`
**Status:** ⚠️ Partial — multibank works, some edge cases remain

### Pipeline

| Phase | Crate | Responsibility |
|-------|-------|----------------|
| 1 | `vpy_loader` | Load `.vpyproj` (TOML) project file |
| 2 | `vpy_parser` | Parse VPy source to AST |
| 3 | `vpy_unifier` | Merge multi-file ASTs, resolve imports |
| 4 | `vpy_bank_allocator` | Assign functions/data to ROM banks |
| 5 | `vpy_codegen` | AST → MC6809 assembly (with tree shaking) |
| 6 | `vpy_assembler` | MC6809 assembly → machine code (two-pass) |
| 7 | `vpy_linker` | Symbol resolution, inter-bank references |
| 8 | `vpy_binary_writer` | Emit final `.bin` ROM image |
| 9 | `vpy_debug_gen` | Generate `.pdb` debug symbol file |

Plus `vpy_disasm` (disassembler utility) and `vpy_cli` (orchestrator).

### What works

- Full 9-phase pipeline runs end-to-end
- Multibank ROM generation (up to 4MB via META directives)
- PDB debug symbol generation (Phase 9)
- ORG directive and two-pass assembly in `vpy_assembler`
- Bank allocation with call graph analysis
- ⚠️ **Experimental:** Variable-sized types (`u8`, `i8`, `u16`, `i16`) with type hints — saves ~20% RAM but not all edge cases tested (Phase 5 complete, use with caution)

### Known issues

- Some programs that compile correctly with Core don't compile with Buildtools
- Inter-bank symbol resolution has edge cases
- Not all addressing modes are fully tested in `vpy_assembler`

### Recently Fixed Issues

**Stack Validator False Positives (Phase 5, Fixed 2026-02-22)**
- **Issue:** Stack validator reported "stack imbalance" in functions like `UPDATE_ENEMIES` and `DRAW_ENEMIES` with claims of "+9 unmatched pushes"
- **Root cause:** The validator's `count_registers()` function was parsing comments as register names. For example, `PULS X      ; Array base` was counted as 3 registers (X, Array, base) instead of 1.
- **Result:** The generated code was always correct; only the validator gave false positives
- **Fix:** Modified `count_registers()` to stop parsing at semicolons (comments are now ignored), and improved function detection to skip internal control flow labels (IF_*, WH_*, CMP_*)
- **Verification:** UPDATE_ENEMIES and DRAW_ENEMIES now validate correctly; all codegen tests pass

### Project format

Buildtools requires a `.vpyproj` file (TOML):

```toml
[project]
name = "my_game"
version = "0.1.0"
entry = "main.vpy"

[build]
output = "my_game.bin"
optimization = 2
debug_symbols = true

[sources]
vpy = ["main.vpy", "player.vpy"]
```

---

## Selecting a Backend

In the IDE: open the **Settings** panel and choose **Buildtools (New)** or **Core (Legacy)**. The setting is saved in localStorage and takes effect on the next build.

**Which to use:**
- Use **Core** if your game fits in 32KB and you need reliability. Output is always a 32KB ROM.
- Use **Buildtools** if you need multibank support or are working on the compiler itself.

---

## LSP Server

The LSP server (`core/src/lsp.rs`, binary `vpy_lsp`) is shared between both backends. It uses the Core lexer and parser and provides:
- Diagnostics (parse errors, semantic warnings)
- Completions (keywords, builtins, user-defined functions)
- Hover documentation
- Go-to-definition
- Semantic tokens

Build with: `cargo build --bin vpy_lsp`
