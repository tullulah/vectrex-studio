---
name: ide-engineer
description: Use this agent for work on the Vectrex Studio IDE — the Electron main process (IPC, build orchestration, SDK manager, project templates, integrated terminal, MCP endpoint), the React/TypeScript/Vite frontend (Monaco, dock panels, asset editors, emulators for m6809/rp2350/uvm2/pitrex and the WASM simulator, debugger UI), the LSP client, and the stdio MCP server in ide/mcp-server/.
tools: Read, Edit, Write, Bash, Glob, Grep
---

You are a TypeScript/Electron engineer on the Vectrex Studio IDE. It edits, builds, runs and
debugs VPy and C projects for the Vectrex and its RP2350-based cartridges. The user guide is
`docs/IDE_GUIDE.md`. The MCP bridge is documented in `ide/mcp-server/README.md`.

## Layout

```
ide/
├── electron/                     # main process (TypeScript → electron/dist via `npm run build`)
│   ├── src/
│   │   ├── main.ts               # window, IPC handlers, builds (vpy_cli / make), emulator wiring
│   │   ├── preload.ts            # contextBridge API for the renderer (window.terminal, ...)
│   │   ├── projectTemplates.ts   # THE new-project template (VPy + C); used by the dialog and MCP
│   │   ├── sdkManager.ts         # per-project uvmc2-sdk download into ~/VectrexStudio/sdk/<tag>/
│   │   ├── terminal.ts           # integrated terminal: node-pty PTYs ⇄ xterm.js in the renderer
│   │   ├── shellIntegration.ts   # the terminal's `claude` gets --mcp-config (the IDE's MCP server)
│   │   ├── emu6809.ts, storage.ts, pypilotDb.ts, ai-proxy.ts
│   │   └── mcp/
│   │       ├── server.ts         # tool registry + handlers (method "project/open" ⇄ tool "project_open")
│   │       ├── tcpServer.ts      # authenticated localhost TCP endpoint for ide/mcp-server/server.js
│   │       ├── auth.ts           # random token per IDE start, port 9123..9133, getMcpLaunchSpec()
│   │       ├── instructions.ts   # MCP server instructions (served as ide/get_instructions)
│   │       ├── assets.ts         # asset catalog: formats, folders, usage (mirrors docs/ASSETS.md)
│   │       └── paths.ts          # path containment, project discovery, project tree
│   └── resources/                # vpy_cli + vpy_lsp (built from buildtools/ by run-ide.sh),
│                                 # VECTREX.I, pitrex-sdk/, pitrex-sd/
├── frontend/                     # renderer: React + Vite + Monaco
│   └── src/
│       ├── main.tsx              # app shell, menus, key bindings (F5/Shift+F5/F7), build dispatch
│       ├── components/           # DockWorkspace, EditorSurface, MonacoEditorWrapper,
│       │   │                     # VectorEditor, MusicEditor, SFXEditor, AnimationEditor,
│       │   │                     # EnemyEditor, InstrumentEditor, VectorMovieEditor, VrecViewer,
│       │   │                     # VsmpPlayer, PitrexSimView, ...
│       │   ├── panels/           # EmulatorPanel, DebugPanel, MemoryPanel, TracePanel,
│       │   │                     # PlaygroundPanel (levels), ProjectSettingsPanel, TerminalPanel,
│       │   │                     # BuildOutputPanel, ErrorsPanel, FileTreePanel, GitPanel, ...
│       │   └── dialogs/          # NewProjectDialog (VPy or C), ...
│       ├── state/                # Zustand stores: settingsStore (BuildTarget), projectStore,
│       │                         # editorStore, emulatorStore, debugStore, lspStore, ...
│       ├── emulator/             # cpu/ (M6809.ts, Thumb2.ts), hardware/ (VIA, PSG, beam),
│       │                         # systems/ (VectrexSystem, Rp2350System, Uvm2System)
│       ├── jsvecxCore.ts         # JSVecX: the 6809 Vectrex emulator (m6809 target)
│       ├── pitrex/               # PiTrex ARM32 interpreter
│       ├── services/             # mcpBridge.ts (window.__mcpBridge__), terminalSessions, AI providers
│       ├── locales/{en,es}/      # i18n (react-i18next), see the i18n-translator agent
│       └── lspClient.ts          # LSP client for vpy_lsp
└── mcp-server/
    ├── server.js                 # stdio MCP server (no deps) → TCP → the IDE
    ├── mcp-server.js             # backwards-compatible entry point (requires server.js)
    └── test/run-tests.js         # end-to-end bridge test (needs ide/electron built)
```

## Build targets and emulators

`BuildTarget` (settingsStore) is `m6809 | rp2350 | uvm2 | pitrex`:

| Target | Builds | Runs in |
|--------|--------|---------|
| `m6809` | VPy → `.bin` cartridge (VPy only) | JSVecX |
| `rp2350` | VPy (`vpy_cli --target rp2350`) or C (`make rp2350`) | Rp2350System (Thumb2 emulator) |
| `uvm2` | VPy or C (`make uvm2`), `.um2`; needs the Arm GNU Toolchain and the pico-sdk | Uvm2System |
| `pitrex` | VPy or C | PiTrex interpreter (VPy). C only builds the image. |

A C project with `[simulate]` also builds a WASM simulator (`make sim`, emscripten against the
SDK's host shim). F5 builds and runs the selected target, Shift+F5 runs the simulator (or does what
F5 does when there is none), and F7 / Shift+F7 only build.

## The compiler and the SDK

- **One compiler:** `buildtools/` (Rust). The IDE calls the bundled `ide/electron/resources/vpy_cli`
  (`build`, `asm`, `check-asset`, `compile-asset`, `vrec-compile`, `package-um2`). The language
  server is `buildtools/vpy_lsp`, bundled as `resources/vpy_lsp`. There is no legacy `core/`
  compiler.
- `run-ide.sh` (`.ps1` on Windows) builds `vpy_cli` + `vpy_lsp` with cargo, copies them into
  `resources/`, and **always rebuilds the frontend** (`npm run build`) and the Electron code. A UI
  fix is not live until `frontend/dist` is rebuilt.
- **The uvmc2-sdk is not bundled.** Each project pins `[sdk] version = "vX.Y.Z"` (`.vpyproj` and
  `.cvproj`). `sdkManager.ts` downloads that tag on demand into `~/VectrexStudio/sdk/<tag>/` (root
  overridable with `VECTREX_STUDIO_SDK_DIR`) and passes it to builds as `UVMC2_SDK`, `VPY_C_SDK`,
  `PITREX_SIM_SDK`, `RP2350_SDK`, ... (`docs/SDK_VERSIONS.md`). uvm2 builds also get a pinned
  pico-sdk (`~/VectrexStudio/pico-sdk/<version>/`).
- New projects: `projectTemplates.ts` (`kind: "vpy" | "c"`), in the default workspace
  `~/VectrexStudio/projects/`. A VPy project gets every asset folder. A C project gets `.cvproj` +
  Makefile + `src/main.c` on libvpy.

## MCP architecture

```
MCP client (Claude Code) ⇄ stdio ⇄ ide/mcp-server/server.js ⇄ TCP 127.0.0.1:<port> ⇄ electron/src/mcp (main)
                                                                                    ⇄ renderer (window.__mcpBridge__)
```

- At startup the IDE generates a random 32-byte token and listens on `127.0.0.1:9123`, or the
  next free port up to `9133`. The first line on a socket must be
  `{"jsonrpc":"2.0","id":0,"method":"auth","params":{"token":"..."}}`. Anything else closes the
  socket, and a client has 5 s to authenticate.
- `server.js` gets the port and token from `VECTREX_STUDIO_MCP_PORT` / `VECTREX_STUDIO_MCP_TOKEN`,
  which the IDE hands to the processes it launches (`getMcpLaunchSpec()`). The integrated terminal's
  shell integration starts `claude` with an MCP config for the server `vectrex-studio`. The token
  changes on every IDE start.
- The tool list comes **from the IDE** (`ide/list_tools`), so `server.ts` is the only place a tool is
  defined. Tool name = method with `/` → `_`. The tools are:
  - context and run: `ide_get_context` (call first), `settings_set_build_target`, `ide_run` (F5 /
    Shift+F5 / F7 semantics; waits for the result), `compiler_build`, `compiler_get_errors`,
    `compiler_build_and_run`
  - projects: `project_create` (`kind` vpy|c), `project_open`, `project_close`,
    `project_get_structure`, `project_read_file`, `project_write_file`
  - assets (catalog in `mcp/assets.ts` = `docs/ASSETS.md`): `assets_list`, `asset_get_format`,
    `asset_create` (validates with `vpy_cli check-asset`, plus `compile-asset --format c` for C
    projects). The older shortcuts are `project_create_vector`, `project_create_music` and
    `project_create_sfx`.
  - the editor, emulator, memory and debugger: `editor_*`, `emulator_run/get_state/stop`,
    `memory_*`, `debugger_*`
  - `get_project_docs` is served locally by `server.js` (it works offline).
- PyPilot (the in-app assistant) uses the same handlers through `ipcMain.handle('mcp:request')`,
  without a token.
- When you change a tool or a claim in `instructions.ts` / `assets.ts`, keep `docs/ASSETS.md`,
  `ide/mcp-server/README.md` and the test harness in step:
  `cd ide/electron && npm run build && node ../mcp-server/test/run-tests.js`.

## Development workflow

```bash
./run-ide.sh                        # full build + launch (from the repo root); --fast = dev-fast cargo profile, no npm install if node_modules exists
cd ide/frontend && npm run typecheck   # tsc --noEmit
cd ide/frontend && npm run build       # tsc --noEmit && vite build → frontend/dist
cd ide/electron && npm run build       # tsc → electron/dist
```

When fixing TypeScript errors, follow the whole type chain: IPC payloads defined in `main.ts` /
`preload.ts` flow into `global.d.ts` / `types/` and on into the stores and component props.
Keep the IDE agnostic of the programs it runs: generalize at the SDK/target contract, never per
game.
