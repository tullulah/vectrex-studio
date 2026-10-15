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
- m6809 calling convention: every function has a static frame (one 16-bit slot per parameter and per local, `VAR_<FUNC>__<NAME>`, in `FRAME_POOL`). The caller stores the arguments in the callee's parameter slots and `JSR`s; the result comes back in D. Frames are overlaid by call graph (`m6809/frames.rs`): a frame starts after the highest frame end of every function that can call it, so functions that are never active together share RAM (SnowBros: 150 bytes of parameters/locals in a 28-byte pool). Recursion, a call with the wrong number of arguments and reading a name that is neither a parameter, a local nor a module-level name are compile errors with the line. A cross-bank call goes through a helpers-bank trampoline that keeps D and CC. The PDB lists frame slots as `function.name` (`type` `param` / `local`); overlaid slots share addresses. The build fails when RAM variables pass $CBFF and warns below 64 bytes of stack
- ARM calling convention (rp2350, uvm2, pitrex): every user function has a stack frame (`arm/frame.rs`, shared by the pitrex backend): `push {r4…r7, lr}`, `sub sp` for one 4-byte slot per parameter and local (padded so sp stays 8-byte aligned), r7 = frame pointer; arguments arrive in r0-r3 (5th and later on the caller's stack) and are stored in their slots, the result returns in r0, and every `return` leaves through one epilogue that restores sp from r7. `main()` and `loop()` locals are separate slots of `game_main`'s frame (pitrex: `main`) and persist across frames. Names resolve with the m6809 rules (`m6809::frames::function_scopes`): a parameter shadows a global or const, a module-level name is the global, any other assigned name is a local, and reading an undeclared name or calling with the wrong number of arguments is a compile error with the line. Recursion works (each activation has its own frame); globals stay at fixed addresses from `USER_RAM_START`
- m6809 `const` values are folded at compile time (numbers, other consts in any order, `+ - * / // % & | ~`, `not`, comparisons) and emitted as immediates; a const that cannot be folded, or does not fit in 16 bits, is a compile error with its line
- Arrays: element size follows the declared type on every target (`u8`/`i8` = 1 byte, untyped/`i16`/`u16` = 2, `u32`/`i32` = 4 on the ARM targets only) for `arr[i]`, `arr[i] = v`, `arr[i] op= v` and `for v in arr`; signed elements are sign-extended, unsigned ones zero-extended. A literal element or a constant store that does not fit the element is a compile error (`validate::check_array_types`). An array argument is passed as its base address, and an indexed parameter takes its element type from the arrays passed at its call sites (forwarding through other functions included); arrays of different element types passed to one parameter are a compile error, and with no named array at any call site the elements are 2 bytes ([MANUAL.md](MANUAL.md#arrays-as-parameters)). Indexing a name that is neither a global array nor a parameter is a compile error
- Structs, enums and array literals with repetition or nesting are lowered by the unifier (phase 3), so every backend compiles them: a struct variable becomes one global per field (`vpy_unifier/src/structs.rs`, an array per field for `Name[n]`), an N-dimensional array one flat array indexed `(i * d1 + j) * d2 + …` (`vpy_unifier/src/arrays.rs`), and `enum` members plain consts (the parser). Function references and calls through a variable are ARM-only (`blx`); m6809 rejects them in its frame analysis
- Arithmetic (`+ - * / // %`), bitwise (`& | ~`), logical, comparison operators; chained comparisons (`a < b < c`)
- m6809 expression temporaries: `TMPVAL` (one RAM word) only holds an operand while the other operand is a plain name or literal; when both sides are expressions (a compare or binop with a binop, call or index on the side evaluated second), the first operand waits on the hardware stack (balanced `PSHS D`/`PULS D`). Arguments of a builtin that are expressions are computed before the builtin runs (into `VAR___HOIST<n>`, allocated only as far as the program needs); arguments of a user call are stored straight into the callee's parameter slots when they are all plain names or literals, and otherwise are all computed first (waiting on the stack) and then stored. `min`/`max`/`clamp` methods, `switch` case values and `x op= v` follow the same rule. All `x op= v` operators work, and `xs[i] op= v` works with a simple index
- String literals (high-bit terminated for BIOS `Print_Str_d`)
- `META` directives (TITLE, COPYRIGHT, MUSIC, ROM_TOTAL_SIZE, ROM_BANK_SIZE)
- Modules: `import m [as a]`, `from m import f [as g]`; `m.f()`, `m.var`, `m.arr[i]`, `m.var = …` (resolved by `vpy_unifier`; module symbols are named `MODULE_symbol` via `vpy_parser::symbols`). Every target compiles all project modules; an unresolved import or `m.name` is a compile error with file:line. Function scopes: parameters, and assigned names the module neither defines nor `from`-imports, are locals; a local or parameter whose name equals another module's top-level variable or const (an imported module's `x` vs main's global `x`, a main local `physics_x` vs `PHYSICS_x`, or a parameter shadowing a global) is renamed `<name>__L` by the unifier, because every backend resolves names in one case-insensitive namespace. Reading another module's global by its bare name (a module reading main's `x`) is a compile error

**Built-in functions (m6809, selection — full reference in [MANUAL.md](MANUAL.md)):**

| Category | Functions |
|----------|-----------|
| Drawing | `DRAW_LINE`, `DRAW_VECTOR`, `DRAW_VECTOR_EX`, `DRAW_VECTOR_ROT`, `DRAW_RECT`, `DRAW_CIRCLE`, `DRAW_CIRCLE_SEG`, `DRAW_ARC`, `DRAW_POLYGON` |
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

### The C backend (uvm2)

`[uvm2] backend = "c"` in the `.vpyproj` compiles the program for the UVMC2 as C instead of ARM assembly (`vpy_codegen/src/cgen.rs`): gcc builds it at `-Os` against libvpy (the SDK's `vpy.c`, `vpy_run(setup, loop)`), the runtime C games use, and the 3D/effects/jukebox builtins go to the same C bridge as from the ARM backend. A `.um2` runs entirely from the cartridge's SRAM, code included, and the ARM backend's stack-machine code is about three times the size of the same game written in C; the Return of the Jedi port's Episode VI part is 224 KB of text this way against 323 KB. The semantics are the ARM backend's (32-bit wrapping integers, truncating `/`, `for` re-testing `< end`, typed arrays, strings and functions as addresses); the 2D builtins are libvpy's own, so text and vectors draw exactly as in a C game. Builtins libvpy has no counterpart for (levels, enemies, animations, samples, …) are a compile error with this backend for now. An untyped `const` array whose values all fit in a byte is stored as `int8_t` with this backend (other untyped arrays stay `int16_t`): every byte of a `.um2` is SRAM, and the Return of the Jedi port won about 1 KB this way. A `const` array may hold `MESH("name")`: the mesh's slot is a number fixed for the build (a `.vskel`'s `T_MESHES`); on a target without meshes the call itself is refused.

The same C program builds for the **rp2350 cartridge**: `[rp2350] backend = "c"` (or, with no `[rp2350]` key, the project's `[uvm2] backend`; `defs` and `sdk_opt` are read the same way) makes `vpy_cli build --target rp2350` compile it as the SDK's `rp2350-cart` recipe builds a C game — libvpy, `sdk_rp2350.c` reaching the BIOS's SDK through its function table (`VPY_DUAL_CORE`), `rp2350_start.s`'s `VPy2` header, linked into the PSRAM by `rp2350_game_ram.ld`. The result is always the SD card's RAM image (with or without `--ram`), which the IDE's rp2350 emulator and the cartridge's launcher run; it is never embedded in the firmware. This is how the 3D, effects, skeleton and cloth builtins reach rp2350. The cartridge has no audio jack: the jukebox builtins compile and stay silent (`JUKEBOX_LIVE()` is 0), so a program falls back to its PSG sounds.

**HardFaults leave a witness on the card.** The generated `main()` installs `vpy_fault.c` (shipped in vpy_cli) over the SDK's HardFault vector. On a fault it leaves the faulting stack for the jack's audio ring at the top of SRAM, then writes `VPYFAULT.TXT` (core, frame, r0–r12, sp, lr, pc, xPSR, CFSR/HFSR/MMFAR/BFAR/SFSR/SFAR) and `VPYRAM.BIN` (all of SRAM, 0x20000000–0x20082000) to the card root. The LED is blue while it writes, then red blinking (both files written) or solid red (the write failed). If core 1 faults, it waits ~0.5 s first, so core 0 is parked and not in a card transfer. `tools/uvm2_fault.py <game.elf> VPYFAULT.TXT VPYRAM.BIN [--vars]` names the function and line, decodes the fault bits, reads the call chain off the stack and, with `--vars`, prints the game's variables. It warns when the ELF is not the build that faulted. The handler costs ~1.6 KB of SRAM (mostly the card's write path).

### Known issues

- Cross-bank symbol resolution incomplete for configs larger than 4×16 KB
- Not all addressing modes fully tested in `vpy_assembler`
- `DRAW_TO(x,y)` not yet implemented in codegen
- `SET_SCALE()` not yet implemented
- PC-relative addressing (`label,PCR`) is not supported by `vpy_assembler`
- m6809: `wait`, `peek`, `poke`, `beep(period, frames)` and `atan2` need constant arguments (otherwise a compile error); `DRAW_SPRITE` is a compile error
- `len(arr)` is the compile-time length of a global or const array on every target; any other argument is a compile error with its line. `GET_TIME()` does not build on any target
- The parser has no unary `+` (parse error)
- pitrex: `for v in arr` is not implemented (the build fails with "Unsupported statement"); loop over `range(0, len(arr))` and index
- m6809: `PLAY_SAMPLE` / `SAMPLE_POS` are a compile error ("not supported on m6809"). Digitised playback needs a PSG volume write every ~190 cycles at 8 kHz; the PSG is reached through VIA port A, which also feeds the beam DAC while a vector is drawn, and both VIA timers are taken (T1 times strokes, T2 the frame). Samples could only play with the screen stopped, which is not what `PLAY_SAMPLE` + `SAMPLE_POS` (a video synced to the audio) mean. The ARM targets stream samples from a second core ([ARCADE_SOUND_RIP.md](ARCADE_SOUND_RIP.md), [RP2350_BIOS.md](RP2350_BIOS.md))
- m6809: a compound assignment to an element whose index calls a function (`xs[f(i)] += v`) is a compile error with its line (the index is evaluated twice); put the index in a variable first
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
- Diagnostics: parse errors; calls to a function this file neither defines nor imports by name, and UPPERCASE calls that are no builtin (an error); a builtin called with an argument count none of its documented forms takes (a warning); unused variables, and `const` hints for scalar globals nothing changes. A `module.function()` call, and whether a builtin exists on the selected target, are the compiler's to check: it sees every module. A global another module of the same folder reads (`common.speed`) counts as used there.
- Completions (keywords, builtins, user-defined functions)
- Hover documentation (a builtin's forms, its doc line from MANUAL.md section 9, its targets)
- Go-to-definition on the AST with the compiler's name rules (parameter, module-level name, local), across modules (`module.name`, `import` / `from … import` lines), to struct fields, and from an asset's name to its file (`vpy_lsp/src/navigate.rs`)
- Semantic tokens
- Rename, signature help, code actions

The builtins it knows are the compiler's: `vpy_lsp/src/builtins_catalog.json` is generated from the code generators and MANUAL.md (as `vpy_cli builtins`), and a `vpy_cli` test fails while it is out of date. After adding or changing a builtin: `VPY_UPDATE_LSP_CATALOG=1 cargo test -p vpy_cli lsp_catalog`.

Build with: `cargo build --bin vpy_lsp`. `run-ide.sh` builds `vpy_cli` and `vpy_lsp` and copies both into `ide/electron/resources/`.
