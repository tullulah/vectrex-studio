# Compiler Status

Vectrex Studio has a single compiler: **buildtools** (`buildtools/`, CLI binary `vpy_cli`), a modular 9-phase Rust pipeline with one crate per phase. It compiles VPy to MC6809 cartridge ROMs (single-bank and multibank) and to ARM targets (RP2350, PiTrex, UVM2), and emits `.pdb` debug symbols. The IDE invokes the bundled `vpy_cli`; the language server `vpy_lsp` is built from the same workspace and uses the compiler's parser.

---

## Buildtools

**Location:** `buildtools/` (one Rust crate per phase)
**CLI binary:** `vpy_cli`

### Command line

```bash
cargo build --bin vpy_cli            # from the repo root (or from buildtools/)
vpy_cli build <file.vpy|project.vpyproj> -o out.bin [--target m6809|rp2350|pitrex|uvm2] [--debug]
vpy_cli asm   <file.vpy|project.vpyproj> -o out.asm   # generated assembly only
```

`--debug` also generates `.pdb` debug symbols. Other subcommands (e.g. `parse`, `unify`, `codegen`, `allocate`, `assemble`, `link`) run individual phases for inspection.

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

**Language:**
- Functions with positional parameters, `for`, `while`, `if/elif/else`, `switch/case`, `break`, `continue`, `return`
- `let` locals, global `var`, `const` values and const arrays
- Arithmetic, bitwise, logical, comparison operators; chained comparisons (`a < b < c`)
- String literals (high-bit terminated for BIOS `Print_Str_d`)
- `META` directives (TITLE, COPYRIGHT, MUSIC, ROM_TOTAL_SIZE, ROM_BANK_SIZE)
- Module imports with dot notation (resolved by `vpy_unifier`)

**Built-in functions (m6809, selection — full reference in [MANUAL.md](MANUAL.md)):**

| Category | Functions |
|----------|-----------|
| Drawing | `DRAW_LINE`, `DRAW_VECTOR`, `DRAW_VECTOR_EX`, `DRAW_RECT`, `DRAW_CIRCLE`, `DRAW_CIRCLE_SEG`, `DRAW_ARC`, `DRAW_POLYGON` |
| Positioning | `MOVE`, `SET_INTENSITY` |
| Text | `PRINT_TEXT`, `PRINT_NUMBER` |
| Math | `abs`, `min`, `max`, `clamp` |
| Audio | `PLAY_MUSIC`, `PLAY_SFX`, `STOP_MUSIC` |
| Input | `J1_X`, `J1_Y`, `J1_BUTTON_1–4`, `J2_X`, `J2_Y`, `J2_BUTTON_1–4` |
| Level | `LOAD_LEVEL`, `SHOW_LEVEL`, `UPDATE_LEVEL` |
| SD launcher (rp2350) | `SD_FILE_COUNT`, `SD_FILE_NAME`, `DRAW_SD_PREVIEW`, `LAUNCH_GAME` |
| Misc | `ASM` (inline assembly), `POKE`, `PEEK`, `WAIT`, `BEEP` |

**RP2350 (debug cart) target:** `vpy_cli build --target rp2350` emits BIOS-linked
code (`svc #N` traps — see `docs/RP2350_BIOS.md`). Add `--ram` to link a game for
SRAM (0x20040000) so the cart's SD launcher can load it; the IDE's "Build for SD"
mode does this and copies the binary to the card. Audio (`PLAY_MUSIC`/`PLAY_SFX`)
runs on the BIOS's second core, so tempo is independent of the draw load.

**Asset pipeline:** `.vec` vector lists, `.vanim` animations, `.vmus` music (PSG AY-3-8912), `.vsfx` sound effects, `.vplay` levels.

### Known issues

- Cross-bank symbol resolution incomplete for configs larger than 4×16 KB
- Not all addressing modes fully tested in `vpy_assembler`
- `DRAW_TO(x,y)` not yet implemented in codegen
- `SET_SCALE()` not yet implemented
- PC-relative addressing (`label,PCR`) is not supported by `vpy_assembler`
- `MOVE` only supports constant arguments (variable x/y not yet implemented)
- `LEN()` and `GET_TIME()` are placeholders on m6809
- Sloped walkable areas: the m6809 wander runtime interpolates the enemy's Y
  along a slope only during WALK-follow and landing. Unlike the libvpy (C) and
  ARM runtimes, it does **not** interpolate at spawn (it uses the authored
  instance Y) or at jump takeoff (it uses a compiler-precomputed `vy0`). The
  enemy still walks and lands the incline correctly; only the exact spawn height
  and the jump-arc peak can differ by ~1 frame. Candidate for the final
  fine-tuning pass — make m6809 spawn/takeoff read the interpolated surface too.

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

## LSP Server

The LSP server lives in `buildtools/vpy_lsp` (binary `vpy_lsp`). It uses the compiler's own parser (`vpy_parser`), so editor diagnostics match what `vpy_cli` reports. It provides:
- Diagnostics (parse errors, semantic warnings)
- Completions (keywords, builtins, user-defined functions)
- Hover documentation
- Go-to-definition
- Semantic tokens
- Rename, signature help, code actions

Build with: `cargo build --bin vpy_lsp`. `run-ide.sh` builds `vpy_cli` and `vpy_lsp` and copies both into `ide/electron/resources/`.
