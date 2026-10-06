# Copilot Project Instructions

> **For technical details on any system, call `get_project_docs(topic)`.**
> Available topics: `assets`, `joystick`, `buttons`, `const_arrays`, `modules`, `banking`, `draw_line`, `music`, `compiler`, `bios`, `tests`, `meta`, `all`

---

## CRITICAL RULES — NEVER BREAK

### Git
- Main branch: `master` (NOT `main`)
- macOS: use `&&`. On Windows PowerShell v5.1: use `;` (NOT `&&`)

### WAIT_RECAL and AUDIO_UPDATE — AUTO-INJECTED
- ❌ NEVER write `WAIT_RECAL()` in VPy code — the compiler injects it automatically at the start of `loop()`
- ❌ NEVER write `MUSIC_UPDATE()` or `AUDIO_UPDATE()` — injected automatically at the END of `loop()`
- ❌ NEVER write `UPDATE_BUTTONS()` — `Read_Btns` is injected automatically at the start of `loop()`

### Variable Scopes
- Variables declared in `main()` are NOT accessible in `loop()` — separate scopes
- Declare variables inside the function where they are used

### BIOS
- NEVER use a synthetic BIOS. Valid paths:
  - `ide/frontend/src/assets/bios.bin`
  - `ide/frontend/dist/bios.bin`
- NEVER use absolute paths outside the workspace

### Assets (.vec / .vmus)
- Format is ALWAYS JSON — never invent text-based formats
- NEVER invent asset names — verify with `project/get_structure` before using `DRAW_VECTOR("name")`
- Use `project/create_vector` and `project/create_music` (they validate JSON automatically)

### Code — No Synthetic Implementations
- All implementations must be real, not heuristic or simulated
- Do not fabricate side effects or invent APIs without verifying source code

### 1:1 Verification (emulator_v2)
- Before creating any API: read the corresponding .cpp/.h file in `vectrexy/libs/emulator/`
- Each function must include a `// C++ Original:` comment with the real source code

---

## VPy Language — Quick Reference

```python
# CORRECT
def main():
    SET_INTENSITY(127)

def loop():
    # WAIT_RECAL() ← DO NOT write, injected automatically
    player_x = 0       # declare here, not in main()

    joy_x = J1_X()     # -1, 0, +1
    btn1 = J1_BUTTON_1()  # 0=released, 1=pressed

    const coords = [10, 20, 30]   # ROM-only, no RAM
    val = coords[1]               # indexing works

    DRAW_VECTOR("ship")           # asset must exist
    PLAY_MUSIC("theme")           # auto-updated at end of loop
```

```python
# META for multibank
META ROM_TOTAL_SIZE = 524288
META ROM_BANK_SIZE = 16384
```

---

## Compiler Architecture — Summary

The only compiler is **buildtools** (`buildtools/`, binary `vpy_cli`), one Rust crate per phase:

| Phase | Crate | Description |
|-------|-------|-------------|
| 1 | vpy_loader | Load `.vpyproj`, discover assets (assets/vectors/*.vec, assets/music/*.vmus) |
| 2 | vpy_parser | Parse VPy source to AST |
| 3 | vpy_unifier | Merge modules, resolve imports (dot notation → PREFIX_NAME) |
| 4 | vpy_bank_allocator | Assign functions/assets to banks if ROM_TOTAL_SIZE is defined |
| 5 | vpy_codegen | AST → MC6809 ASM (assets embedded as FCB/FDB) |
| 6 | vpy_assembler | ASM → object code |
| 7 | vpy_linker | Symbol resolution, final addresses (source of truth) |
| 8 | vpy_binary_writer | `.bin` ROM image |
| 9 | vpy_debug_gen | `.pdb` debug symbols |

- Build: `cargo run --bin vpy_cli -- build program.vpy -o program.bin [--target m6809|rp2350|pitrex|uvm2] [--debug]`
- ASM only: `cargo run --bin vpy_cli -- asm program.vpy -o program.asm`
- Compiler tests: `cd buildtools && cargo test --all`
- Language server: `buildtools/vpy_lsp` (binary `vpy_lsp`), same parser as the compiler
- Tests: `cargo test -p vectrex_emulator`

---

## Available MCP Tools (ide/mcp-server/server.js)

| Category | Tools |
|----------|-------|
| Editor | editor_list_documents, editor_read_document, editor_write_document, editor_replace_range, editor_insert_at, editor_delete_range, editor_get_diagnostics |
| Compiler | compiler_build, compiler_get_errors |
| Emulator | emulator_run, emulator_get_state, emulator_stop |
| Memory | memory_dump, memory_list_variables, memory_read_variable, memory_write |
| Debugger | debugger_start, debugger_add_breakpoint, debugger_remove_breakpoint, debugger_get_callstack, debugger_get_registers |
| Project | project_get_structure, project_read_file, project_write_file, project_create, project_open, project_close, project_create_vector, project_create_music |
| **Docs** | **get_project_docs(topic)** ← call for technical details |

### Tool usage rules
- `editor/write_document`: creates OR updates (always works)
- `editor/read_document`: only if the file is already open
- `editor/replace_range`: requires startLine/endLine (NOT character offsets)
- `project/read_file`: paths RELATIVE to project root (e.g. `src/main.vpy`)
- DO NOT invent tool names — only use those listed above
