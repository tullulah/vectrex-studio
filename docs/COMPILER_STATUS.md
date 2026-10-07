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
- PDB debug symbol generation (Phase 9), single-bank and multibank. Each function's lines carry the `.vpy` file that defines it: `vpyLineMap` entries (`{file, line}`) and `functions[name].file` name the real file, `fileLineMap` holds per-file breakpoint addresses (`{"physics.vpy": {"7": "0x00B8"}}`), and `lineMap` (line numbers only, kept for older readers) holds the entry file's lines
- ORG directive and two-pass assembly in `vpy_assembler`
- Bank allocation with call graph analysis
- Variable-sized types (`u8`, `i8`, `u16`, `i16`) — saves ~20% RAM; use with caution

**Language:**
- Functions with positional parameters, `for`, `while`, `if/elif/else`, `switch/case`, `break`, `continue`, `return`
- Globals declared at module level as `name = expr` (optionally typed: `name: u8 = expr`); locals created by plain assignment inside a function (`x = expr`, no type annotation); `const` values and const arrays. There are no `let`/`var` keywords
- m6809 `const` values are folded at compile time (numbers, other consts in any order, `+ - * / // % & | ~`, `not`, comparisons) and emitted as immediates; a const that cannot be folded, or does not fit in 16 bits, is a compile error with its line
- Arrays: element size follows the declared type (`u8`/`i8` = 1 byte, untyped/`i16`/`u16` = 2) for `arr[i]`, `arr[i] = v` and `for v in arr`; `i8` elements are sign-extended. An array argument is passed as its base address, and on m6809 an indexed parameter takes its element type from the arrays passed at its call sites (forwarding through other functions included); arrays of different element types passed to one parameter are a compile error, and with no named array at any call site the elements are 2 bytes ([MANUAL.md](MANUAL.md#arrays-as-parameters)). Indexing a name that is neither a global array nor a parameter is a compile error
- Arithmetic (`+ - * / // %`), bitwise (`& | ~`), logical, comparison operators; chained comparisons (`a < b < c`)
- m6809 expression temporaries: `TMPVAL` (one RAM word) only holds an operand while the other operand is a plain name or literal; when both sides are expressions (a compare or binop with a binop, call or index on the side evaluated second), the first operand waits on the hardware stack (balanced `PSHS D`/`PULS D`). Arguments of a builtin that are expressions are computed before the builtin runs (into `VAR___HOIST<n>`, allocated only as far as the program needs); arguments of a user call go through the stack when a later argument is an expression or a parameter of the caller would be read after its slot was overwritten (`g(b, a)` inside `f(a, b)`). `min`/`max`/`clamp` methods, `switch` case values and `x op= v` follow the same rule. All `x op= v` operators work, and `xs[i] op= v` works with a simple index
- String literals (high-bit terminated for BIOS `Print_Str_d`)
- `META` directives (TITLE, COPYRIGHT, MUSIC, ROM_TOTAL_SIZE, ROM_BANK_SIZE)
- Modules: `import m [as a]`, `from m import f [as g]`; `m.f()`, `m.var`, `m.arr[i]`, `m.var = …` (resolved by `vpy_unifier`; module symbols are named `MODULE_symbol` via `vpy_parser::symbols`). Every target compiles all project modules; an unresolved import or `m.name` is a compile error with file:line

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
| Misc | `POKE`, `PEEK`, `WAIT`, `BEEP` |

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
- m6809: `wait`, `peek`, `poke`, `beep(period, frames)` and `atan2` need constant arguments (otherwise a compile error); `DRAW_SPRITE` is a compile error
- `len(arr)` is the compile-time length of a global or const array on every target; any other argument is a compile error with its line. `GET_TIME()` does not build on any target
- The parser has no `^`, `<<`, `>>` or unary `+` (parse error), and `&` / `|` bind like `*` (tighter than `+`/`-`), unlike Python
- m6809: `PLAY_SAMPLE` / `SAMPLE_POS` are a compile error ("not supported on m6809"). Digitised playback needs a PSG volume write every ~190 cycles at 8 kHz; the PSG is reached through VIA port A, which also feeds the beam DAC while a vector is drawn, and both VIA timers are taken (T1 times strokes, T2 the frame). Samples could only play with the screen stopped, which is not what `PLAY_SAMPLE` + `SAMPLE_POS` (a video synced to the audio) mean. The ARM targets stream samples from a second core ([ARCADE_SOUND_RIP.md](ARCADE_SOUND_RIP.md), [RP2350_BIOS.md](RP2350_BIOS.md))
- m6809: parameters live in the global `VAR_ARG0..7` slots, so a function that calls another function and then reads its own parameter reads the callee's argument. Copy a parameter to a local before calling out
- m6809: `xs[i + 1] += v` (compound assignment to an element with a computed index, or to a field) is a compile error with its line; write `xs[j] = xs[j] + v`
- Inline `asm("...")` is not implemented (the parser accepts it; the build fails on an undefined `ASM` symbol)
- `vectorlist` blocks are parsed but no backend emits them
- m6809: `SET_TEXT_SIZE` and `J2_DIGITAL_X/Y` fail to assemble (missing helper symbols); `DRAW_POLYGON`, `DRAW_CIRCLE_SEG`, `DRAW_ARC`, `DRAW_FILLED_RECT`, `DRAW_ELLIPSE` and the Bézier builtins only work with constant arguments
- Several builtins exist on one backend only (e.g. `tan`, `atan2`, `pow`, `GET_LEVEL_WIDTH` are m6809-only; `PLAY_SAMPLE`, `GET_CAMERA_X`, the SD launcher calls are ARM-only). [MANUAL.md](MANUAL.md) section 9 marks each one
- `vpy_cli build <file.vpy> --target rp2350|pitrex` (a bare `.vpy`, no `.vpyproj`) fails with "Unknown variable" as soon as a variable is read inside an expression; build through a `.vpyproj` for ARM targets
- Sloped walkable areas: the m6809 wander runtime interpolates the enemy's Y
  along a slope only during WALK-follow and landing. Unlike the libvpy (C) and
  ARM runtimes, it does **not** interpolate at spawn (it uses the authored
  instance Y) or at jump takeoff (it uses a compiler-precomputed `vy0`). The
  enemy still walks and lands the incline correctly; only the exact spawn height
  and the jump-arc peak can differ by ~1 frame. Candidate for the final
  fine-tuning pass — make m6809 spawn/takeoff read the interpolated surface too.

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
