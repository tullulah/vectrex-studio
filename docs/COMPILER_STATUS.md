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
**Status:** ⚠️ DEPRECATED — use Buildtools for all new projects

> **Deprecation notice (v0.2.0):** The Core compiler is in maintenance mode and will
> not receive new features. All active development targets the Buildtools pipeline.
> Migrate existing projects by adding a `.vpyproj` file and switching the IDE backend
> selector to **Buildtools (New)**.

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
- **Misc:** CLR, COM, NEG, INC, DEC, TST, CLRA, CLRB, COMA, COMB, NEGA, NEGB, INCA, INCB, DECA, DECB, TSTA, TSTB, MUL, EXG, TFR

**Built-in functions (core):**

| Category | Functions | Status |
|----------|-----------|--------|
| Drawing | `DRAW_LINE`, `DRAW_VECTOR`, `DRAW_VECTOR_EX`, `DRAW_RECT`, `DRAW_CIRCLE`, `DRAW_CIRCLE_SEG`, `DRAW_ARC`, `DRAW_SPIRAL`, `DRAW_POLYGON` | ✅ |
| Positioning | `MOVE` (sets DRAW_LINE origin offset), `SET_INTENSITY`, `SET_ORIGIN` | ✅ |
| Text | `PRINT_TEXT`, `PRINT_NUMBER` | ✅ |
| Math | `abs`, `min`, `max`, `clamp`, `MUL_A`, `DIV_A`, `MOD_A` | ✅ |
| Audio | `PLAY_MUSIC`, `PLAY_SFX`, `STOP_MUSIC` | ✅ |
| Input | `J1_X`, `J1_Y`, `J1_BUTTON_1–4`, `J2_X`, `J2_Y`, `J2_BUTTON_1–4` | ✅ |
| Level | `LOAD_LEVEL`, `SHOW_LEVEL`, `UPDATE_LEVEL` | ✅ |
| Misc | `ASM` (inline assembly), `LEN`, `POKE`, `PEEK` | ✅ |
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
- `MOVE` only supports constant arguments (variable x/y not yet implemented)

---

## Backend 2: Buildtools (Active)

**Location:** `buildtools/` (one Rust crate per phase)
**CLI binary:** `vpy_cli`
**Status:** ✅ Active — recommended for all new projects

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
- **4-bank multibank ROM** (4×16 KB = 64 KB) via `META ROM_TOTAL_SIZE`/`ROM_BANK_SIZE`
- All builtins in banked mode: `DRAW_VECTOR`, `SHOW_LEVEL`, `UPDATE_LEVEL`, `PLAY_SFX`
- PDB debug symbol generation (Phase 9)
- ORG directive and two-pass assembly in `vpy_assembler`
- Bank allocation with call graph analysis
- Variable-sized types (`u8`, `i8`, `u16`, `i16`) — saves ~20% RAM; use with caution

### Known issues

- Cross-bank symbol resolution incomplete for configs larger than 4×16 KB
- Not all addressing modes fully tested in `vpy_assembler`
- `DRAW_TO(x,y)` not yet implemented in codegen
- `SET_SCALE()` not yet implemented

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
- Use **Buildtools** for all new projects. It handles both single-bank (32 KB) and
  multibank (64 KB+) games and is actively maintained.
- Use **Core** only if you have an existing project that depends on its specific
  output and haven't had time to migrate yet. Core is deprecated and receives no
  new features.

---

## LSP Server

The LSP server (`core/src/lsp.rs`, binary `vpy_lsp`) is shared between both backends. It uses the Core lexer and parser and provides:
- Diagnostics (parse errors, semantic warnings)
- Completions (keywords, builtins, user-defined functions)
- Hover documentation
- Go-to-definition
- Semantic tokens

Build with: `cargo build --bin vpy_lsp`
