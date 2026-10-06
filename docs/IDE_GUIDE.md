# Vectrex Studio — IDE Guide

Vectrex Studio is an Electron-based IDE built around Monaco editor, a custom JSVecX emulator, and a full Language Server Protocol (LSP) integration. This guide covers everything you need to write, compile, and debug VPy games.

---

## Table of Contents

1. [Opening a Project](#1-opening-a-project)
2. [Editor](#2-editor)
3. [Building and Running](#3-building-and-running)
4. [Emulator Panel](#4-emulator-panel)
5. [Debugging](#5-debugging)
6. [PyPilot — AI Assistant](#6-pypilot--ai-assistant)
7. [Panels Reference](#7-panels-reference)
8. [Settings](#8-settings)
9. [Project File Format (.vpyproj)](#9-project-file-format-vpyproj)
10. [MCP Server](#10-mcp-server)

---

## 1. Opening a Project

Use **File → Open Project** to open a `.vpyproj` file. The IDE loads the project structure and sets the entry point for compilation.

If you open a single `.vpy` file without a project, the IDE compiles that file directly (no `.vpyproj` needed for quick tests).

---

## 2. Editor

The editor is powered by Monaco with full VPy language support via the LSP server (`buildtools/vpy_lsp`, binary `vpy_lsp`). The LSP uses the compiler's own parser, so editor diagnostics match build errors.

### LSP Features

| Feature | How to trigger |
|---------|----------------|
| **Completions** | Type any identifier character — suggestions appear automatically |
| **Diagnostics** | Parse errors and semantic warnings appear as red/yellow squiggles in real-time |
| **Hover** | Hover over an identifier to see its type or documentation |
| **Go to Definition** | Click a symbol while holding Cmd/Ctrl |
| **Rename** | Right-click → Rename Symbol — renames across all open files |
| **Quick Fixes** | Click the lightbulb or press Cmd+. on a squiggle (e.g. "Convert to const", "Remove unused variable") |
| **Semantic Tokens** | Built-in names, keywords, and user identifiers are colored differently |

### Language support

The editor supports `.vpy` (VPy source), `.asm` (MC6809 assembly), and asset files (`.vec`, `.vmus`, `.vsfx`).

---

## 3. Building and Running

### Run button

Click **Run** (or press **F5** when stopped) to:

1. Save any unsaved changes
2. Invoke the compiler (`vpy_cli`) for the build target selected in Settings
3. Stream output to the **Build Output** panel
4. On success: load the ROM into the emulator and start it automatically

### Compilation output panels

| Panel | Content |
|-------|---------|
| **Build Output** | Smart-classified output: phase headers, ✅ success, ❌ errors, ⚠ warnings |
| **Compiler Output** | Raw stdout/stderr stream from the compiler process |
| **Errors** | Diagnostics list — click any entry to jump to the source location |

### Compiler

The IDE compiles with `vpy_cli`, the buildtools compiler bundled in `ide/electron/resources/`. It handles single-bank and multibank ROMs and generates `.pdb` debug symbols for source-level debugging. The hardware target is chosen in [Settings](#8-settings). See [COMPILER_STATUS.md](COMPILER_STATUS.md) for the command-line interface.

---

## 4. Emulator Panel

The emulator panel embeds a custom JSVecX emulator that runs the compiled ROM. It displays:

- **CPU registers**: PC, A, B, X, Y, U, S, DP, CC flags
- **Performance metrics**: cycles per frame, instruction count, frame count, FPS
- **Cycle utilization chart** with danger zone indicator (frame budget exceeded)

### Controls

| Button | Action |
|--------|--------|
| **Play** | Start or resume emulation |
| **Pause** | Pause emulation |
| **Reset** | Reset the emulator to startup state |

The emulator starts automatically after a successful build.

---

## 5. Debugging

### Breakpoints

Click in the **gutter** (left margin) of any line in the editor to toggle a breakpoint. Breakpoints are:

- Persisted across sessions (stored in SQLite)
- Supported in both `.vpy` source files and `.asm` assembly files
- Mapped to ROM addresses via the `.pdb` debug symbol file (requires `debug_symbols = true` in the project file)

> **Note:** Breakpoints in `.vpy` files require a PDB file to map VPy lines → MC6809 addresses. Enable `debug_symbols` in the `.vpyproj` (or pass `--debug` to `vpy_cli`).

### Debug controls

| Key | Action |
|-----|--------|
| **F5** | Continue (resume from breakpoint) |
| **F10** | Step Over |
| **F11** | Step Into |
| **Shift+F11** | Step Out |

These controls are also available as buttons in the **Debug Toolbar** at the top.

### Debug Panel

Shows values printed via `DEBUG_PRINT` and variables tracked via `DEBUG_PRINT_STR` from the running program. Updates every 100ms.

### Trace Panel

Shows an instruction-level execution trace (when tracing is enabled). Useful for understanding exactly what the CPU is doing.

### Memory Panel

Inspect RAM contents directly. Supports both raw bytes and grid view.

### BIOS Calls Panel

Monitor which Vectrex BIOS routines are being called and how often. Useful for diagnosing drawing performance issues.

### PSG Log Panel

Logs activity on the AY-3-8910 sound chip (PSG) — register writes, tone/noise values.

---

## 6. PyPilot — AI Assistant

PyPilot is the built-in AI assistant. It understands VPy and the Vectrex hardware, can write or edit code, create vector assets, and control the IDE directly via MCP.

### AI Providers

PyPilot supports multiple AI backends. Select and configure one in the **⚙️ Config** settings panel inside the AI Assistant:

| Provider | Type | Notes |
|----------|------|-------|
| **Ollama** | Local (private) | Runs on your machine. No API key, no cost. Recommended for privacy. |
| **Anthropic Claude** | Cloud | Requires API key. Best reasoning quality. |
| **OpenAI** | Cloud | Requires API key. `gpt-4o` / `gpt-4o-mini`. |
| **Google Gemini** | Cloud | Requires API key. |
| **DeepSeek** | Cloud | Requires API key. Free tier available. |
| **GitHub Models** | Cloud | Requires GitHub Personal Access Token. |
| **Groq** | Cloud | Requires API key. Fast inference, free tier available. |

Configuration (API keys, model selection, endpoint) is saved per-provider in localStorage.

### Ollama (local AI)

For 100% private AI with no API costs, use Ollama. See [OLLAMA_SETUP.md](OLLAMA_SETUP.md) for installation and recommended models.

Quick start:
```bash
brew install ollama
brew services start ollama
ollama pull qwen2.5:7b    # recommended model
```

Then select **Ollama (Local)** in PyPilot's config panel. The IDE includes an **Ollama Manager** (🏠 button) to download, switch, and delete models directly from the UI.

### What PyPilot can do

**Chat and code assistance:**
- Generate VPy code from a description
- Explain selected code
- Suggest fixes for compiler errors
- Optimize code for performance or clarity
- Answer questions about VPy syntax and Vectrex hardware

**IDE control (via MCP):**

When the MCP server is running, PyPilot can take actions directly in the IDE:

- Read and write `.vpy` source files
- Create new vector assets (`.vec`), music assets (`.vmus`)
- Trigger compilation and inspect build errors
- Add breakpoints, inspect the emulator state

### Slash commands

| Command | Action |
|---------|--------|
| `/help` | Show all available commands |
| `/clear` | Clear current session history |
| `/settings` | Open provider configuration |
| `/generate [description]` | Generate VPy code from a description |
| `/explain` | Explain the current or selected code |
| `/fix` | Suggest fixes for current compiler errors |
| `/optimize` | Optimize selected code |
| `/vectrex [command]` | Get syntax and examples for a Vectrex built-in |
| `/examples` | Show VPy code examples |
| `/assets` | Guide to using `.vec` and `.vmus` assets |

### Context

PyPilot automatically attaches the current open file as context with every message. You can also attach additional context manually via the **📎 Adjuntar** button.

### Session management

Each project has independent conversation history. Use the **Session Manager** dropdown in the header to create, rename, switch, or delete sessions. Sessions are persisted in SQLite.

### Concise mode

Toggle **⚡ Conciso** to get shorter, more direct responses — useful when you just want code, not explanations.

---

## 7. Panels Reference

| Panel | Purpose |
|-------|---------|
| **Editor** | VPy/ASM code editor with full LSP |
| **File Tree** | Project file browser — expand, open, right-click for context menu |
| **Emulator** | JSVecX emulator with CPU state and metrics |
| **Build Output** | Smart-classified compiler output |
| **Compiler Output** | Raw compiler stdout/stderr |
| **Errors** | Compile-time diagnostics (click to jump to source) |
| **Debug** | `DEBUG_PRINT` output and watched variables |
| **Trace** | Instruction-level execution trace |
| **Memory** | RAM inspector (raw and grid views) |
| **BIOS Calls** | BIOS routine call monitor |
| **PSG Log** | Sound chip activity log |
| **Git** | Git status, staging, commits, history, stashes, remotes, tags |
| **PyPilot (AI Assistant)** | AI chat, code generation, asset creation, IDE control via MCP |
| **Settings** | Build target selection (M6809, RP2350, PiTrex, UVM2) |
| **Project Settings** | Only with a project open. The project's pinned uvmc2-sdk version: installed and GitHub releases, change the pin, download with progress. See [SDK_VERSIONS.md](SDK_VERSIONS.md) |

---

## 8. Settings

Open the **Settings** panel to choose the **Build Target** — the hardware `vpy_cli` compiles for.

| Target | Description |
|--------|-------------|
| **M6809 (Vectrex)** | Original Vectrex hardware. Produces a `.bin` ROM cartridge image (single-bank or multibank). |
| **RP2350 (Debug Cartridge)** | ARM Thumb2 target for the RP2350 debug cartridge. Requires the `arm-none-eabi` toolchain on PATH. Options: build mode (flash to cart via XIP, or SD card / RAM-linked for the launcher), flash on Build & Run, and an SD card folder for auto-copy. |
| **PiTrex (Pi Zero / ARMv6)** | ARM32 native target for the PiTrex cartridge. Produces a `.img` file. Requires `arm-none-eabi` and `PITREX_SDK`. |
| **UVM2 (Ultimate Vectrex Multicart)** | ARM Thumb2 target for the Ultimate Vectrex Multicart 2. Produces a `.um2` raw binary for the SD card. |

Changes take effect on the next build.

The UVM2 target (and, optionally, PiTrex for the libvpy C runtime) builds against the
uvmc2-sdk release pinned by the project. The IDE downloads it on the first build that needs
it; M6809 builds never do. The pinned version is managed in the **Project Settings** panel —
see [SDK_VERSIONS.md](SDK_VERSIONS.md).

---

## 9. Project File Format (.vpyproj)

Projects are defined by a TOML file at the project root:

```toml
[project]
name = "mygame"
version = "0.1.0"
entry = "src/main.vpy"
description = "My Vectrex game"
author = "Your Name"

[build]
output = "build/mygame.bin"
target = "vectrex"
optimization = 2
debug_symbols = true        # required for source-level debugging

[sources]
vpy = ["src/**/*.vpy"]

[resources]
vectors = ["assets/vectors/*.vec"]
music = ["assets/music/*.vmus"]
sfx = ["assets/sfx/*.vsfx"]
levels = ["assets/levels/*.vplay"]

[sdk]
version = "v1.3.2"          # uvmc2-sdk release (UVM2 / PiTrex / C builds)
```

### Key fields

| Field | Required | Description |
|-------|----------|-------------|
| `project.name` | Yes | Display name |
| `project.entry` | Yes | Main `.vpy` file (relative to project root) |
| `build.output` | Yes | Output `.bin` path (relative to project root) |
| `build.debug_symbols` | No | Set to `true` to enable PDB generation |
| `build.optimization` | No | Optimization level 0–2 (default: 2) |
| `sdk.version` | No | uvmc2-sdk release tag. If missing, the IDE pins the latest tag the first time a build needs the SDK. `.cvproj` files use the same table. See [SDK_VERSIONS.md](SDK_VERSIONS.md) |

---

## 10. MCP Server

The MCP server (`ide/mcp-server/server.js`) exposes the IDE's capabilities to AI assistants (Claude, Copilot, etc.) via the Model Context Protocol.

**Connection**: The IDE connects on TCP port 9123; AI clients connect via stdio.

### Available tool groups

| Group | Tools |
|-------|-------|
| **Editor** | Read/write/edit documents, get diagnostics |
| **Compiler** | Trigger builds, get errors |
| **Emulator** | Start/stop, get CPU state |
| **Debugger** | Add breakpoints, get call stack |
| **Project** | Open/close projects, read/write files, create vector/music assets |

This allows AI tools to read your code, trigger builds, inspect the running emulator, and create or edit assets — all without leaving the IDE.
