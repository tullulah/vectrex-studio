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

**File → New → Project...** creates a project from a template. The **Language** choice picks its kind:

| Language | Creates | Builds |
|----------|---------|--------|
| **VPy** | `<name>.vpyproj`, `src/main.vpy`, `assets/` folders | m6809, rp2350, uvm2, pitrex (vpy_cli) |
| **C (SDK)** | `<name>.cvproj`, `Makefile`, `src/main.c` on the SDK's libvpy runtime (`#include <vpy.h>`, `vpy_run(setup, loop)`) | WASM simulator (`make sim`, Shift+F5), rp2350 (`make rp2350`), uvm2 (`make uvm2`) |

Both are pinned to the latest SDK release (`[sdk] version`). The C project is self-contained: its Makefile only uses the SDK variables the IDE passes (`UVMC2_SDK`, `VPY_C_SDK`, `PITREX_SIM_SDK`, `RP2350_SDK`; see [SDK_VERSIONS.md](SDK_VERSIONS.md)) and the SDK's own rp2350/uvm2 recipes (`uvm2-sdk/uvm2.mk`). The same templates (`ide/electron/src/projectTemplates.ts`) back the MCP tool `project_create`.

New projects go to the default workspace, `~/VectrexStudio/projects` (created on first use), unless another location is chosen in the dialog — the MCP tool `project_create` uses the same default.

---

## 2. Editor

The editor is powered by Monaco with full VPy language support via the LSP server (`buildtools/vpy_lsp`, binary `vpy_lsp`). The LSP uses the compiler's own parser, so editor diagnostics match build errors.

### LSP Features

| Feature | How to trigger |
|---------|----------------|
| **Completions** | Type any identifier character — suggestions appear automatically |
| **Diagnostics** | Parse errors and semantic warnings appear as red/yellow squiggles in real-time |
| **Hover** | Hover over an identifier to see its type or documentation; while the program is paused, a variable's value (see [Debugging](#5-debugging)) |
| **Go to Definition** | Alt+click a name, or right-click → Go to Definition (Cmd/Ctrl+click adds a cursor) |
| **Rename** | Right-click → Rename Symbol — renames across all open files |
| **Quick Fixes** | Click the lightbulb or press Cmd+. on a squiggle (e.g. "Convert to const", "Remove unused variable") |
| **Semantic Tokens** | Built-in names, keywords, and user identifiers are colored differently |

Go to Definition resolves a name as the compiler does: in a function, a parameter (its `def` line), then a module-level name (global, `const`, enum member, function, struct), then a local (the first statement that assigns it). `module.name` goes to `name` in that module's file, the module of an `import` line to its file, a name a `from … import` brings in to its definition there, `value.field` / `ships[i].hp` to the struct's field, and a string naming an asset (`DRAW_VECTOR("ship")`) to the project's asset file, opened in its editor.

### Language support

The editor supports `.vpy` (VPy source), `.asm` (MC6809 assembly) and C sources. Asset files open in their own editors:

| Asset | Editor |
|---|---|
| `.vec` | Vector Editor (2D, and 3D with per-point `z`) |
| `.vmus` | Music Editor |
| `.vsfx` | SFX Editor |
| `.vanim` | Animation Editor |
| `.venemy` | Enemy Editor |
| `.vinstr` | Instrument Editor |
| `.vplay` | Playground (levels) |
| `.vmesh` | Mesh Editor — 3D wireframe with front/top/side/3D views (middle button pans, middle + Shift orbits), vertex and face editing, primitives (cube, pyramid, grid, cylinder), undo/redo and live validation against the compiler's rules. File → New → 3D Mesh creates `assets/meshes/<name>.vmesh` |
| `.vscene` | Scene Editor (below). File → New → 3D Scene creates `assets/scenes/<name>.vscene` with one piece, the first mesh in `assets/meshes` (so make a mesh first) |
| `.vskel`, `.vclip` | 3D Animation Editor (below): skeletons, poses, clips and sets. File → New → 3D Skeleton / 3D Animation |
| `.vmov` | Vector Movie Editor |
| `.vsmp` | Sample player |

Formats and how each asset is used from VPy and C: [ASSETS.md](ASSETS.md).

### Scene Editor

A `.vscene` arranges `.vmesh` pieces into a 3D set for a C project (vpy3d,
`vpy3d_draw_scene`). The editor has three columns:

- **Left:** the items in draw order (add, duplicate, delete, move up/down). Order matters,
  because an item's occluders hide only the items after it, so list the near pieces first.
  Below the items are the groups (add, rename, delete) and the scene fog (on/off, `full`,
  `gone`). Renaming a group renames it in every item that uses it. Deleting a group makes
  those items draw always.
- **Right:** the selected item. It has a name, a mesh or a list of meshes that take turns
  along a repeat (picked from the project's `assets/meshes`), `at` and `follow` (x/y/z),
  repeat (axis, step, count), window (min/max, each optional), brightness %, fog
  (per segment / whole copy / none) and group (none, `name` or `!name`).
- **Middle:** a preview that places every copy with the runtime's own arithmetic for a
  preview `pos`. Set `pos` with the x/y/z sliders and fields. **▶** (or Space) advances
  `pos.z` at the set speed, so you can watch a repeat scroll and wrap. The group checkboxes
  in the left column form the groups mask.
  - Views: **Eye** is a perspective from an editable point, looking along +z. Front, top,
    side and an orbiting 3D view are also available.
  - Faces' edges are green (smooth edges faint), scenery lines are drawn at their
    brightness, and occluders show as a faint orange hull.
  - Click a piece to select its item. The selected item is drawn in orange.
  - The fog preview takes depth as z minus the eye's z, which approximates what the game's
    camera sees.

Errors show inline as you edit. They follow the compiler's rules, so the editor reports an
error exactly when `vpy_cli check-asset` would refuse the file. That includes a mesh missing
from `assets/meshes`, a list of meshes without a repeat, a group that is not declared, and
more than 16 distinct meshes. Every edit can be undone (Ctrl+Z / Ctrl+Y). Saving writes
2-space JSON and keeps any fields the editor does not know. **Reload meshes** reads the
`.vmesh` files again after you change them. A mesh lofted from `.vec` sections is not
previewed here: open it in the Mesh Editor.

### 3D Animation Editor

`.vskel` skeletons and `.vclip` libraries of poses and clips (formats in
[ASSETS.md](ASSETS.md#vskel-3d-skeleton)) open in one editor, in the spirit of Unreal's
Persona or Unity's Animation window. `.vanim` stays separate: it is a flipbook of 2D frames.
Create them with **File > New > 3D Skeleton** (into `assets/skeletons/`) and
**3D Animation** (into `assets/clips/`, posing the project's first skeleton).

The view in the middle draws the character the way the console draws it: hard edges facing
the camera, the outline of smooth surfaces, the bones in blue and the sockets (a blade, a
gun) in red. **Smooth edges** shows every edge, faint. **Character** picks one of the
skeleton's variants; the toolbar's checkboxes turn meshes, bones and sockets on and off.
**3D**, **Front**, **Side** and **Top** are views of a character facing +z. Dragging orbits,
Shift or middle drag pans, the wheel zooms, and clicking a joint selects its bone. The
skeleton and the meshes are read from `assets/skeletons` and `assets/meshes` (any folder);
**⟳** reads them again.

A `.vclip` has three tabs:

- **Poses:** the list of poses on the left, one slider per joint on the right, in degrees
  and in the file's own units. The editor warns when a pose is shared by several clips or
  sets, because changing it changes all of them. Clicking a joint's name finds its bone in
  the view, and the joints that turn the selected bone are highlighted.
- **Clips:** the keys (a pose at a frame) and the marks (a named instant, with an optional
  value), the clip's loop and its whole-number properties. The timeline under the view plays
  the clip at the game's 50 frames a second (Space, or **▶**; slower speeds too), scrubs
  with a click, and moves a key when you drag it. **+ Key at frame n** adds a key at the
  playhead, and **+ New pose here** turns what the view shows into a new pose keyed there.
  **Ghost** draws the last key passed, faintly. Selecting a key shows its pose's sliders.
  Between keys the preview moves in straight lines. How the game eases between them is its
  own business (Return of the Jedi chases each pose with springs).
- **Sets:** per character or style, the pose for each stance, the clip for each role
  (**▶** plays it) and the set's own numbers.

A `.vskel` has three tabs:

- **Bones:** the tree. A bone has its parent, its offset, its mesh and its turns (axis,
  joint, `mul`, `div`, `add`), plus the sockets fixed to it.
- **Joints:** names and optional limits, plus test sliders that pose the skeleton without
  saving anything.
- **Variants:** the scale, and a mesh and an offset per bone. A variant's extra bones,
  rotations and sockets are listed but edited as text.

Renaming a pose, a clip, a bone or a joint renames it wherever the same file uses it.
Deleting one that is still used is refused, and the message names the users. Renaming a
joint in a `.vskel` does not rename it in the `.vclip` files that pose it. Errors show on the
left as you edit. Every edit can be undone (Ctrl+Z / Ctrl+Y), and saving keeps the fields
the editor does not know. A game reads both files as constant tables built when it is
built: `import name` in VPy, `gen/name.h` in C ([ASSETS.md](ASSETS.md#vskel-3d-skeleton)),
so what is saved here is what the next build runs.

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

### Upload to the UVMC2 cartridge (USB)

**Build → Upload to Cartridge (UVMC2, USB)** (target UVM2; MCP tool `cartridge_upload`) builds the project with the USB debug monitor in it, puts the `.um2` on the cartridge's SD card over USB, with `MONITOR.BIN` beside it, and checks each file's CRC-32, then **starts the game**: the chip goes to its BOOTSEL mode and the game's ELF (the image the `.um2` is made from) is loaded into SRAM and run, the way the multicart would run it off the card. No card reader is needed; a whole upload takes about 5–7 seconds. The game also stays on the card, in the multicart's menu.

It works with the cartridge in either of two states, plugged into the computer by USB:

| Cartridge | How the IDE reaches the card |
|-----------|------------------------------|
| Running a game built with the monitor (`UVM2_USB_MONITOR=1`, which this command sets) | The monitor (`MONITOR.BIN`, loaded off the card into the PSRAM) answers on USB while the game runs. |
| In the multicart's menu | The menu's firmware is sent to the chip's BOOTSEL mode with `picotool`, and the SD bridge (a RAM-only program; the flash is not touched) is loaded and run. The console shows the upload's progress. |

It needs `picotool`: on macOS `brew install picotool`; on Linux the IDE builds one from the pico-sdk; on Windows it downloads Raspberry Pi's prebuilt one (the bootrom and the menu's reset interface are WinUSB devices, so no driver install). The port is the monitor's serial device: `/dev/cu.*` on macOS, `/dev/ttyACM*` on Linux, a COM port on Windows, held there by a Windows PowerShell child (`System.IO.Ports`) so the IDE never blocks on it (`hwdebug/serialLink.ts`). The Windows side is checked without a cartridge (picotool, the COM port search, opening a port); with one, it has not been run yet. Both programs come with the IDE (`ide/electron/resources/uvmc2/`); their sources are in uvmc2-sdk (`uvm2-sdk/monitor`, `uvm2-sdk/sdbridge`). A game built with the monitor costs about 2 KB of SRAM.

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

Click in the **gutter** (left margin) of any line in the editor to toggle a breakpoint (or F9). Breakpoints are:

- Persisted across sessions (stored in SQLite)
- Supported in `.vpy` source files — every file of the program, imported modules included — and in single-bank `.asm` files
- Mapped to ROM addresses through the `.pdb` the build writes (the IDE always builds with `--debug`), by file and line: `main.vpy:10` and `util.vpy:10` are different places
- Only the open project's: a breakpoint in another project's `main.vpy` is ignored

A breakpoint on a line with no code of its own (a comment, a `def`, an `else:`) stops at the next statement of the same function. When execution stops, the editor opens that statement's file and highlights the line.

The editor's breakpoints and the keys below work on **m6809** (JSVecX, through the `.pdb`) and on **rp2350 and uvm2** (the ARM emulator, through the line table in the build's ELF: see the next section). In a C project (`.cvproj`) they work in its own C files the same way. Step Into goes all the way down, into any code with line info (the SDK's C, libvpy); Step Over and Step Out from the project's own files stop only in them (a call into the SDK is stepped over), and once inside the SDK they go line by line there too, opening the SDK's file in the editor; the uvm2 build's ELF is read from `build_uvm2/pico/`. pitrex and the WASM simulator (Shift+F5) have no debugger.

On the ARM targets a C-backend build (`[uvm2] backend = "c"`) is optimised: gcc inlines and reorders, so a line may be skipped, a breakpoint on a call may show the first line of the function inlined there, and Step Over stays in the current file while the stack does not change (a call to another module that gcc inlined is stepped over). Step Out from `loop()` goes to whatever runs next in the frame.

### Debugging ARM programs with gdb (rp2350, uvm2)

The editor's breakpoints and steps cover the usual work; gdb adds instruction stepping, registers, memory and the full stack down to the firmware.

While the IDE runs, its ARM emulator accepts `arm-none-eabi-gdb` on localhost port **3333** (the next free port up to 3343 if 3333 is taken; the IDE's log says which). Build and run the program on the emulator (F5), then attach with the build's ELF (an IDE build for uvm2 writes `build/<name>_uvm2.elf`):

```bash
arm-none-eabi-gdb build/<name>_uvm2.elf -ex "target remote :3333"
```

Attaching pauses the emulator. Then, at the `.vpy` level:

| gdb | Does |
|-----|------|
| `break util.vpy:5`, `break UTIL_bump` | Breakpoint on a line or a function |
| `continue` (Ctrl+C to stop) | Run; the IDE's emulator runs with it |
| `next`, `step`, `finish` | Line steps over / into calls, run to the caller |
| `bt` | VPy calls, then the runtime and the firmware below them |
| `stepi`, `x/8i $pc`, `info registers` | Instruction level |
| `x/4wx 0x20010000` | Memory (RAM, flash, PSRAM; not peripherals) |
| `detach` | Remove gdb's breakpoints and let the program run |

The builds carry the line table for this: the asm backend writes a `.loc` per statement (and unwind data for `bt`, in a debug section: the image is the same with or without it); the C backend (`[uvm2] backend = "c"`) writes `#line`, so gdb shows the C runtime's own functions and parameters as well. With the C backend at `-O3`, `next` can land in an inlined runtime function. `step` into a VPy function stops on its `def` line first. The SDK's C (the uvm2 runtime, the firmware) has its own debug info.

Breakpoints are the emulator's (never written into the program). One gdb at a time; core 0 only on dual-core images; watchpoints are not supported. A uvm2 C project (`.cvproj`) is built by the same pico-sdk CMake, with debug info, and is debugged the same way with its ELF.

### Debugging on the cartridge (rp2350, over SWD)

**Debug → Debug on Cartridge (RP2350, SWD)** runs a VPy project on the RP2350 cartridge itself and debugs it there with the editor's breakpoints, the stepping keys (F10, F11, Shift+F11), Continue/Pause, the call stack and hover values — the same debugger as on the emulator. **Stop Debugging on Cartridge** (or Stop) ends the session and leaves the game running.

It needs a Raspberry Pi Debug Probe (or any CMSIS-DAP probe) on the cartridge's SWD header, `probe-rs` installed (`cargo install probe-rs-tools`), and the cartridge firmware with the SWD launch mailbox (`vectrex-arcade-private/hardware/debug_cart/firmware`, `bios.rs` `SWD_LAUNCH`), flashed once.

What it does:

1. Builds the project as **Build for SD** does: a RAM image with the `VPy2` header (`build/<name>_sd.bin`) and its ELF.
2. Resets the cartridge to its menu, attaches a `probe-rs dap-server` to **core 1 only** — the core that runs the program — and writes the image to the PSRAM where the firmware loads games from the card (`0x11000000`).
3. Writes the launch mailbox in SCRATCH_X (`0x20080004`: magic `0x53574C4E`, size, answer); the menu's next frame launches the game exactly as from the SD card (without a romset or samples, which are found by the card's game index).

Core 0 drives the Vectrex bus and keeps redrawing the last picture, so a paused game stays on screen and the beam never stops on one spot. Breakpoints are BKPT instructions written into the game's code (and the original put back): the core has a handful of hardware ones, and a step needs one at every statement of the function it is in. A step takes about a second (each stop reads the registers and the RAM the editor shows through the probe at 1 MHz SWD). Every BKPT is removed when the session ends, and the game keeps running.

The debugger reads the stack, the VPy runtime RAM (`0x2007F000`) and up to 64 KB of the program's data at each stop; a value outside them shows nothing. **Text from the game (RTT).** `vpy_log("x %d\n", x)` and `DEBUG_PRINT_LABELED` in a C game (and `DEBUG_PRINT…` in a VPy program built as C) write to an RTT ring the SDK puts in every cartridge image (`_SEGGER_RTT`, sdk_rp2350.c); the IDE reads it every 200 ms while the session lasts and shows each line in the build output as `[rtt] …`. Writing never waits: with no debugger reading, the text is dropped and the game runs the same.

**Change Value** works on globals and on locals in memory; a local the compiler keeps in a register can be changed on the emulators but not on the cartridge (probe-rs cannot set a core register). Not supported yet: games that need their romset or samples from the card, core 0.

### Debugging on the cartridge (UVMC2, over USB)

With the target **UVM2**, **Debug → Debug on Cartridge (UVMC2, USB)** (MCP: `cartridge_debug`, `cartridge_debug_stop`) debugs the game on Ralf's multicart with the same debugger: breakpoints, F10/F11/Shift+F11, Continue/Pause, the call stack, hover values and Change Value — registers included, which the RP2350 session cannot do. No probe: the game's own debug monitor answers over the cartridge's USB.

1. It builds the project with the USB debug monitor and `-Og`, and puts it on the card and starts it as **Upload to Cartridge** does (from the multicart menu, or over a game with the monitor already running).
2. It attaches to the monitor (`MONITOR.BIN`, in the PSRAM), which uses the Cortex-M33's **monitor-mode debug**: a breakpoint (a BKPT the monitor writes over the game's code, keeping the original), a step or a pause raises the DebugMonitor exception, and the core waits there while the USB interrupt goes on answering the IDE. Core 1 keeps redrawing the last picture, so a paused game stays on screen.
3. Steps run on the cartridge: the IDE marks where the step may stop, the game runs to the first of them.

While the game is held, the console shows its last picture with a pause sign in the top right corner, as on the RP2350 cartridge. `DEBUG_PRINT` / `vpy_log` text comes over the same USB port and shows in the build output as `[rtt] …`. **Stop Debugging on Cartridge** (or closing or reloading the IDE) takes every breakpoint out and leaves the game running.

**Without the IDE.** The SDK's `tools/uvmc2.py` does the same from a terminal (`deploy`, `upload`, `run`, `log`), and the monitor's second USB port speaks gdb's remote protocol: `arm-none-eabi-gdb game.elf -ex "target remote <port>"` (`uvmc2.py gdb` prints the port). See the uvmc2-sdk README. Use the IDE's debugger or gdb, one at a time.

Breakpoints work from the game's first frame on (the monitor starts at the end of it): a line that only runs before it — early in `main()` / `setup()` — does not stop. Only the game's core (core 0) is debugged.

### Debug controls

| Key | Action |
|-----|--------|
| **F5** | Build and run; while paused (at a breakpoint or after a step), Continue to the next breakpoint |
| **Shift+F5** | Build and run the simulator; while paused, end the debug session |
| **F12** | Continue |
| **F10** | Step Over: run to the next statement of this function or of the one it returns to, over calls (an `if` whose body is skipped is skipped; the end of `loop()` goes round to its top) |
| **F11** | Step Into: run to the next statement, inside a called function if the statement calls one, in whatever file it lives |
| **Shift+F11** | Step Out: run until back in the caller |

These controls are also available as buttons in the **Debug Toolbar** at the top.

### Values on hover

While the program is paused, hovering a variable in the editor shows its value — a scalar in decimal (and hex), an array's first 16 elements, a struct's fields; `ships[i].hp` shows `hp` of every element. The name resolves as in the compiler (parameter, then global, then local of the function the line is in), and `module.name` reads another module's global.

- **m6809**: every global, array and struct field, and the parameters and locals of the functions on the call stack (the `.pdb`'s variables; m6809 frames are overlaid by call graph, so a function that is not running has no value of its own). One-byte values show unsigned, two-byte ones signed: the `.pdb` does not record the declared type.
- **rp2350 / uvm2 with the C backend**: from the debug information gcc writes into the ELF — globals with their C types, and the parameters and locals of the function the program is paused in, or of one gcc inlined there (a local of a function further up the call stack shows nothing). At `-O3` a local often lives in a register, or nowhere at that point: the hover then says *optimised out here*. A global gcc kept in a register, or folded because nothing changes it, has no value to show either.
- **rp2350 / uvm2 with the asm backend**: scalar globals (`VAR_<NAME>`, 32-bit); arrays and locals are not shown (the asm backend writes no type or frame information).
- **C projects (`.cvproj`) on rp2350 / uvm2**: the same debug information, by the C names, next to clangd's own hover: a parameter or local of the function the hovered line is in (when that function is running, or inlined where the program is paused), else a global or file `static`; `s.field` and `arr[i].field` (the field of every element) too. A member read through a pointer (`p->field`) is not shown.

### Call Stack Panel

While the program is paused (m6809, rp2350, uvm2) it lists the calls that led there (View → Call Stack; the first stop of a session opens it): the innermost function first, each user function with its file and line (a click opens it), then its callers down to `main`. Runtime routines and BIOS routines appear by name (`Moveto_ix` ← `Wait_Recal` ← `loop` ← `main`). The stack is rebuilt from the return addresses on the 6809 stack, so a call through `JSR` indexed shows its callee by address, and in a multibank ROM a caller in another bank than the one mapped is missing. `main`'s frame under `loop` has no line: it is the compiler's own frame loop.

On rp2350 and uvm2 the stack is unwound with the call-frame information in the build's ELF (and, for code built without it, from the function's prologue), down through the C runtime and the firmware: `vpy3d_occl_add` ← `ties.draw` (ties.vpy:63) ← `loop` ← `vpy_run` ← `main` ← `_reset_handler`. A pause inside a system call (SVC) stops at its handler. A function gcc inlined has no frame of its own: with the C backend, `main()` and `loop()` themselves are inlined into the runtime's `vpy_setup` / `vpy_loop` and appear as `main` / `loop`, and a line of an inlined function shows in the frame of its caller.

### Debug Panel

Values printed via `DEBUG_PRINT` and variables tracked via `DEBUG_PRINT_STR` from the running program. Updates every 100ms.

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
levels = ["assets/playground/*.vplay"]

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

The MCP server (`ide/mcp-server/server.js`) exposes the IDE's capabilities to AI assistants (Claude Code, Claude Desktop, any MCP client) via the Model Context Protocol.

**Connection**: the AI client starts `server.js` and talks to it over stdio; `server.js` connects to the running IDE over TCP on `127.0.0.1` (port 9123, or the next free one up to 9133). Each connection must authenticate with a random token the IDE generates at startup, so only processes the IDE launches — with the port and token in `VECTREX_STUDIO_MCP_PORT` / `VECTREX_STUDIO_MCP_TOKEN` — can drive it. The server runs on the IDE's own Electron binary (`ELECTRON_RUN_AS_NODE=1`); no separate Node install is needed. The packaged app ships it in `<resources>/mcp-server/`.

If the IDE is not running, the MCP server still starts: tool calls return a "Vectrex Studio is not running / not reachable" error and it reconnects on its own once the IDE is up.

### Available tool groups

The tool list is served by the IDE itself, so it always matches what the IDE implements. Full list and behaviour: [ide/mcp-server/README.md](../ide/mcp-server/README.md).

**Claude Code in the integrated terminal.** `claude` typed in the IDE's terminal gets these tools, plus the server's *instructions* (`ide/electron/src/mcp/instructions.ts`): they open with a mandatory checklist: call `ide_get_context` first (it carries the project's assets and its language API), make all art, sound, levels and animation assets with `asset_create`, look the API up with `api_reference` instead of searching the SDK or compiler sources, and build and run with `ide_run`. They also say what VPy / "the SDK" / the targets mean, and which tool equals F7 / F5 / Shift+F5.

**Images in the terminal.** The terminal carries only text, so pasting a clipboard image (Cmd+V on macOS, Ctrl+Shift+V or Ctrl+V on Windows) saves it as a PNG in the system temp folder (`vectrex-studio-paste/`, cleared after a day) and pastes its path; Claude Code attaches a pasted image path. Files dragged onto the terminal are pasted as their paths the same way.

| Group | Tools |
|-------|-------|
| **IDE** | `ide_get_context` (open project, kind, SDK, selected target, buildable targets, what each key would do, emulator, Arm toolchain, IDE version; with a project open also its `assets` with the code that uses each one, and `api`: the language's calls on the selected target plus how-to recipes), `ide_run` (= F7 / F5 / Shift+F5 / Shift+F7, awaited, with the result), `settings_set_build_target`, `cartridge_upload` (= Build → Upload to Cartridge, UVMC2), `cartridge_debug` / `cartridge_debug_stop` (= Debug on Cartridge, UVMC2) |
| **Reference** | `api_reference` (the full API of the open project's language, generated from the real sources: VPy from the compiler's builtin catalog with per-target availability, C from the headers of the project's pinned SDK version) |
| **Editor** | List/read open documents, write files into the project, line-range edits, save, diagnostics |
| **Compiler** | Build the project (VPy: m6809; C: like F7), build and run, last build errors |
| **Emulator** | Load and run a ROM, stop, CPU state (PC, registers, cycles) |
| **Memory** | Dump RAM/ROM, list and read PDB variables, write RAM |
| **Debugger** | Start a debug session, breakpoints, continue/pause/step, registers, call stack |
| **Project** | Open/close/create projects (VPy or C), project tree, read/write files |
| **Assets** | `assets_list` (the project's assets + the code that uses each), `asset_get_format`, `asset_create` (every asset type, written to its folder and compile-checked); see [ASSETS.md](ASSETS.md) |

File access is confined to the open project's folder. Emulator, debugger and memory tools need the Emulator panel open. Every tool reports success only when it actually did the thing; failures come back as tool errors with the reason.
