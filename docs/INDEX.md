# Vectrex Studio — Documentation Index

This is the map of `docs/`, the single home of the project's documentation. Every file in `docs/` is listed below, grouped by area. The only `.md` files outside `docs/` are short `README.md` files that describe their folder and link back here (the root `README.md`, `buildtools/README.md`, `ide/mcp-server/README.md`, `ide/electron/README.md`, `tools/**/README.md`, `vscode-extension/README.md`).

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
| [COMPILER_STATUS.md](COMPILER_STATUS.md) | The buildtools compiler (`vpy_cli`): CLI, phase table, builtins, known issues, LSP |
| [STACK_VALIDATOR.md](STACK_VALIDATOR.md) | Stack balance validation — catches PSHS/PULS imbalances at compile time |
| [TESTING.md](TESTING.md) | Visual test runner for VPy games across the 6809, PiTrex and RP2350 targets |
| [TODO.md](TODO.md) | Variable-sized types implementation roadmap |

---

## Language Reference

| File | Description |
|------|-------------|
| [MANUAL.md](MANUAL.md) | Full VPy language manual (syntax, types, builtins per target, gotchas) |
| [VPY_RESERVED_WORDS.md](VPY_RESERVED_WORDS.md) | Reserved keywords and built-in names that cannot be used as variable names |
| [PYTHON_VS_VPY.md](PYTHON_VS_VPY.md) | Key differences between Python and VPy |

---

## IDE

| File | Description |
|------|-------------|
| [IDE_GUIDE.md](IDE_GUIDE.md) | IDE panels, build/run workflow, emulator, debugger (breakpoints via `.pdb` debug symbols), PyPilot, MCP server, project format |
| [OLLAMA_SETUP.md](OLLAMA_SETUP.md) | Setting up Ollama for local AI (PyPilot) — models, installation, troubleshooting |

---

## Asset Formats

| File | Description |
|------|-------------|
| [ASSETS.md](ASSETS.md) | **The asset reference.** Every asset type (`.vec` `.vmus` `.vsfx` `.vanim` `.vplay` `.venemy` `.vinstr` `.vrec` `.vsmp` `.vmesh`): format, folder, IDE editor, VPy and C usage, targets |
| [GUIDE_SFX_README.md](GUIDE_SFX_README.md) | Overview of the `.vsfx` sound effect format |
| [GUIDE_SFX_CREATION.md](GUIDE_SFX_CREATION.md) | How to create sound effects |
| [GUIDE_SFX_EXAMPLES.md](GUIDE_SFX_EXAMPLES.md) | Example `.vsfx` files with commentary |

---

## Targets and Hardware

| File | Description |
|------|-------------|
| [SDK_VERSIONS.md](SDK_VERSIONS.md) | uvmc2-sdk releases: the per-project `[sdk] version` pin, on-demand download to `~/VectrexStudio/sdk/<tag>/`, which targets need it, `UVMC2_SDK` and the other env vars, building outside the IDE |
| [UVM2_TARGET.md](UVM2_TARGET.md) | Ultimate Vectrex Multicart 2 target: halt-mode bus, `.um2` format, frame budget, bring-up ladder |
| [RP2350_BIOS.md](RP2350_BIOS.md) | RP2350 cartridge BIOS: syscall ABI (`svc #N`), SD launcher, memory map, dual-core audio |
| [AUTOMATIC_BANK_SWITCHING.md](AUTOMATIC_BANK_SWITCHING.md) | Multibank ROM banking architecture and switching mechanism (includes the cartridge ROM layout) |
| [AAE_RP2350_PORT.md](AAE_RP2350_PORT.md) | Porting the AAE vector-arcade emulator to the RP2350 cartridge (Asteroids first) |
| [ARCADE_SOUND_RIP.md](ARCADE_SOUND_RIP.md) | Sound for an arcade port, both routes: ripping music out of its own sound ROM down to PSG streams (`v_playMusic`/`v_playSFX`), and — for boards with no sound chip to record, like Tac/Scan's analogue USB — digitised `.vsmp` samples injected into the draw list (`v_playSample`) |

---

## Third-Party Vectrex Reference

Original Vectrex programming material, kept verbatim in [vec_prog_docs/](vec_prog_docs/). Useful entry points:

| File | Description |
|------|-------------|
| [vec_prog_docs/other/TOOLS/6809/TEXT/6809.TXT](vec_prog_docs/other/TOOLS/6809/TEXT/6809.TXT) | MC6809 instruction set: opcodes, addressing modes, cycle counts |
| [vec_prog_docs/html/memorymap.htm](vec_prog_docs/html/memorymap.htm) | Vectrex memory map (RAM, cartridge ROM, BIOS, VIA registers) |
| [vec_prog_docs/html/bios.htm](vec_prog_docs/html/bios.htm) | BIOS routine reference |
| [vec_prog_docs/html/linedrawing.htm](vec_prog_docs/html/linedrawing.htm) | How the BIOS draws lines (integrators, scale, beam positioning) |
| [vec_prog_docs/html/vectordisplay.htm](vec_prog_docs/html/vectordisplay.htm) | How the vector display works |

---

## Documentation Rules

- All docs must be written in **English**.
- All documentation files go in `docs/`. Outside it, only the folder `README.md` files listed above.
- No session notes, bug fix reports, or completion reports. Document what *is*, not what *was done*.
- When a feature is implemented, update the relevant reference doc — don't create a new `_COMPLETE.md` file.
- Add a new topic as a new file here (UPPER_SNAKE_CASE.md) and list it in this index.
