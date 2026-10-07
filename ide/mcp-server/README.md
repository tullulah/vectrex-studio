# Vectrex Studio MCP server

`server.js` is a [Model Context Protocol](https://modelcontextprotocol.io) server that lets an AI
client (Claude Code, Claude Desktop, any MCP client) drive a running Vectrex Studio IDE: open and
create projects, edit files, build, run the ROM in the emulator, debug, and inspect memory.

```
MCP client ⇄ stdio (newline-delimited JSON-RPC) ⇄ server.js ⇄ TCP 127.0.0.1 ⇄ IDE main process
                                                                               ⇄ renderer (window.__mcpBridge__)
```

- `server.js` — the stdio server. No dependencies; runs under Node ≥ 18 or under the IDE's own
  Electron binary as Node (`ELECTRON_RUN_AS_NODE=1`).
- `ide/electron/src/mcp/` — the IDE side: `tcpServer.ts` (authenticated TCP endpoint),
  `server.ts` (tool registry and handlers), `auth.ts` (token, port, launch spec), `paths.ts`
  (path containment, project discovery, project tree), `assets.ts` (asset catalog),
  `apiReference.ts` (the language API: `api_reference` and the `api` block of `ide_get_context`).
- `ide/frontend/src/services/mcpBridge.ts` — the renderer hooks the handlers call
  (`window.__mcpBridge__.invoke(name, args)`); arguments always travel as JSON.

## How the IDE wires it

At startup the IDE:

1. generates a random token (32 bytes, hex) kept in memory only;
2. listens on `127.0.0.1:9123`, or on the next free port up to `9133`;
3. exposes `getMcpLaunchSpec()` from the Electron main process:

   ```ts
   { command: process.execPath,                    // the IDE's Electron binary
     args:    ['<resources>/mcp-server/server.js'], // ide/mcp-server/server.js in dev
     env:     { ELECTRON_RUN_AS_NODE: '1',
                VECTREX_STUDIO_MCP_PORT: '<port>',
                VECTREX_STUDIO_MCP_TOKEN: '<token>' } }
   ```

   This is what the IDE uses to register the server with Claude Code in its integrated terminal.
   No system Node install is needed. The packaged app ships this folder as
   `<resources>/mcp-server/` (electron-builder `extraResources`).

Because the token changes on every IDE start, an MCP client must be launched from (or
reconfigured by) the running IDE; a stale token gets a clear "rejected" tool error.

### Environment

| Variable | Meaning |
|----------|---------|
| `VECTREX_STUDIO_MCP_PORT` | IDE TCP port (default `9123`) |
| `VECTREX_STUDIO_MCP_TOKEN` | Auth token (required) |
| `MCP_VERBOSE=1` | Log to stderr |

## TCP protocol (IDE side)

Newline-delimited JSON-RPC 2.0. The first line a client sends must be

```json
{"jsonrpc":"2.0","id":0,"method":"auth","params":{"token":"<token>"}}
```

The IDE answers `{"result":{"ok":true,...}}`; a wrong or missing token gets an error reply and
the socket is closed — nothing else is processed on an unauthenticated socket (5 s to
authenticate). After that:

| Method | Result |
|--------|--------|
| `ide/list_tools` | `{tools:[{name, method, description, inputSchema}]}` — `name` is the MCP tool name (`project_open`), `method` the IDE method to call (`project/open`) |
| `<method>` (e.g. `project/open`) | the tool result, or a JSON-RPC error whose message explains the failure |
| `ide/ping` | `{ok, window}` |
| `ide/get_instructions` | `{instructions}` — the MCP server instructions (below) |

Unparseable lines get a `-32700` error carrying the request id when it can be recovered.

The in-process PyPilot assistant uses the same handlers through `ipcMain.handle('mcp:request')`
(no token: it never leaves the app).

## MCP behaviour (stdio side)

- Handles `initialize` (protocol versions `2025-06-18`, `2025-03-26`, `2024-11-05`; the
  client's version is echoed when supported), `notifications/initialized`, `ping`,
  `tools/list`, `tools/call`. Other methods answer `-32601`.
- **Instructions.** The `initialize` result carries `instructions`, which Claude Code puts in
  the model's context. They start with a numbered "BEFORE WRITING CODE" checklist: 1)
  `ide_get_context` (it lists the assets and the API), 2) reuse or create assets with
  `asset_create` for all art, sound, levels and animation, 3) `api_reference` instead of
  searching files (never grep the SDK or compiler sources), 4) `ide_run` to build and run.
  Then: it runs inside Vectrex Studio, works through the IDE's tools (no generated images,
  ad-hoc scripts or sleeps), what VPy / "the SDK" (uvmc2-sdk, so a C project) / the four
  targets mean, which `ide_run` mode is F7 / F5 / Shift+F5 / Shift+F7, the VPy writing rules,
  and to ask one short question when the language or target is ambiguous. The API itself is
  not in the instructions: it is generated per project (below). The text has ONE source, `ide/electron/src/mcp/instructions.ts`,
  fetched with `ide/get_instructions` at `initialize`; when the IDE is down `server.js` answers
  a short static fallback (`FALLBACK_INSTRUCTIONS`).
- **The tool list comes from the IDE** (`ide/list_tools`), so it always matches the handlers.
  When the IDE is not reachable, `tools/list` returns only `get_project_docs` (served locally);
  once the IDE comes up the server sends `notifications/tools/list_changed`.
- It starts even if the IDE is not running. Tool calls then return
  `{content:[{type:'text', text:'Vectrex Studio is not running / not reachable ...'}], isError:true}`;
  each call retries the connection, and a background reconnect runs with backoff (1 s → 30 s).
- Every tool failure — IDE down, bad arguments, compile errors — is an `isError` tool result,
  not a JSON-RPC error. A tool reports success only when it actually did the thing.

## Tools

Generated from the IDE's registry (`ide/electron/src/mcp/server.ts`); the live list with full
input schemas is what `tools/list` returns.

| Group | Tools |
|-------|-------|
| IDE | `ide_get_context`, `ide_run`, `settings_set_build_target` |
| Reference | `api_reference` |
| Editor | `editor_list_documents`, `editor_read_document`, `editor_write_document`, `editor_save_document`, `editor_get_diagnostics`, `editor_replace_range`, `editor_insert_at`, `editor_delete_range` |
| Compiler | `compiler_build`, `compiler_build_and_run`, `compiler_get_errors` |
| Emulator | `emulator_run`, `emulator_get_state`, `emulator_stop` |
| Memory | `memory_dump`, `memory_list_variables`, `memory_read_variable`, `memory_write` |
| Debugger | `debugger_start`, `debugger_continue`, `debugger_pause`, `debugger_step_into`, `debugger_step_over`, `debugger_step_out`, `debugger_add_breakpoint`, `debugger_remove_breakpoint`, `debugger_list_breakpoints`, `debugger_clear_breakpoints`, `debugger_get_callstack`, `debugger_get_registers` |
| Project | `project_open`, `project_close`, `project_create`, `project_get_structure`, `project_read_file`, `project_write_file`, `project_create_vector`, `project_create_music`, `project_create_sfx` |
| Assets | `assets_list`, `asset_get_format`, `asset_create` |
| Local | `get_project_docs` (works without the IDE) |

Notes on behaviour:

- **Files are confined to the open project.** `project_read_file`, `project_write_file`,
  `editor_write_document`, `editor_save_document` and the `create_*` tools resolve paths against
  the project root and refuse anything outside it (`..`, absolute paths, symlinks that escape).
  `editor_write_document` only accepts `file://` URIs inside the project (or project-relative
  paths / bare file names).
- `ide_get_context` returns the open project (path, name, kind `vpy`|`c`, entry, `[sdk] version`
  and whether it is installed; for a `.cvproj` its `[build]`, `[targets.*]`, `[simulate]` and the
  targets it can build), the selected build target and related settings, what F7 / F5 /
  Shift+F5 / Shift+F7 would do right now, the emulator state, the Arm GNU Toolchain status
  (`detectArmToolchain`) and the IDE version. With a project open it also returns, so that the
  call every client makes first already carries them (about 8 KB for a typical project):
  - `assets`: `byType` — every asset as `"<name>: <code that uses it>"` in the project's language
    (12 per type, 40 in all; the rest via `assets_list`), and `canCreate` — the types
    `asset_create` can make for this language, in one line;
  - `api`: `functions` — category → one line per call (`SIGNATURE — purpose`) available in the
    project's language on the selected target (VPy: what game code calls; injected, broken and
    alias names are left to `api_reference`. C: the `vpy.h` calls, with their `VPY_SHORT_NAMES`
    alias); `howTo` — recipes for rotating a sprite, many objects, music/SFX, joystick and
    buttons, text/score, random numbers, collisions, levels (a recipe is shown only when every
    call it uses exists there, so a new call such as `DRAW_VECTOR_ROT` appears by itself);
    `source`; `modules` (C: `vpy3d.h` and the other `vpy*.h` headers); `more`.
  A C project whose pinned SDK is not installed waits up to 20 s for its download.
- `api_reference {topic?, query?, target?}` is the full reference, generated, never written by
  hand (`apiReference.ts`, cached per compiler build / SDK version):
  - VPy: `vpy_cli builtins --json` (`buildtools/vpy_cli/src/builtins_catalog.rs`). Candidate
    names are every UPPER_SNAKE string literal of the codegen and parser sources (`build.rs`);
    each is compiled as a call for every target, and what a backend accepts is a builtin there
    (`targets`, and `onTarget` for the selected target). Signature and doc line come from
    `docs/MANUAL.md` section 9; a builtin without one fails `cargo test -p vpy_cli`.
  - C: the headers of the project's pinned SDK (`~/VectrexStudio/sdk/<version>/vpy-c/include`):
    `vpy.h` and `vpy3d.h` by default (prototypes, the comment on their line or right above,
    `---- section ----` banners as categories, `VPY_*` constants, `VPY_SHORT_NAMES` aliases);
    `topic: "vpyphys"` (any `vpy*.h`) parses that module.
  - `topic` = a category (substring), a C header, or `howto`; `query` = substring/regex over
    names, signatures and docs. No arguments = everything, plus `howTo` and `topics`.
- `settings_set_build_target {target: m6809|rp2350|pitrex|uvm2}` sets the same zustand setting
  as the Settings panel's selector, and warns when the open C project has no recipe for it.
- `ide_run {mode}` is the general build/run tool: `build` = F7, `run` = F5, `simulate` = Shift+F5,
  `build_simulator` = Shift+F7. With no `mode` it picks `simulate` on rp2350 / pitrex / uvm2
  (their faithful emulators are slow) and `run` on m6809, and Claude's instructions, the tool
  description and `ide_get_context.runWith` all say to start the simulator there. Claude Code only
  passes the first ~2 KB of server instructions to the model, so that rule sits in the checklist at
  the top (a test keeps it under 1800 bytes). It calls the renderer's own `handleBuild` (registered on the
  bridge by `main.tsx`, so the keys and the tool cannot diverge), opens the Emulator panel for
  `run`/`simulate`, waits for the build, then for the panel to load what it produced (6809
  JSVecX, RP2350, UVM2, PiTrex or the WASM simulator), and returns `ok`, the artifact, the
  emulator (`backend`, `running`), notes about fall-backs, and the tail of this build's output.
  A failed build is an `isError` result with the compiler errors and the output tail; so is a
  `run`/`simulate` whose program did not start.
- `compiler_build` builds a VPy project for m6809 whatever target is selected: it saves dirty
  project sources first, returns the `.bin` path, or fails with the compiler errors. On a
  C/C++ (`.cvproj`) project it does what F7 does (`ide_run` mode `build`);
  `compiler_build_and_run` on one does what F5 does.
- `project_create {name, location?, kind}`: created in `location`, or in the default workspace `~/VectrexStudio/projects` when it is omitted. `kind: "vpy"` (default) or `"c"` — a C project on the
  SDK's libvpy runtime (`.cvproj` with `[targets.rp2350]`, `[targets.uvm2]`, `[simulate]`,
  `Makefile`, `src/main.c`). Templates: `ide/electron/src/projectTemplates.ts`, shared with the
  New Project dialog.
- `emulator_run`, `compiler_build_and_run`, `debugger_*` and `memory_*` need the **Emulator
  panel** open — the emulator lives there.
- `memory_dump` reads cartridge ROM, RAM and BIOS only; the VIA (`$D000`) is excluded because
  reading it has side effects.
- **Assets** (catalog: `ide/electron/src/mcp/assets.ts`, reference: `docs/ASSETS.md`).
  `assets_list {type?, maxPerType?}` lists the project's assets by type with a one-line summary
  and the exact code that uses each one in the project's language (VPy builtin call, or C
  `#include "<name>.h"` + call), the usable types it has none of, the types its language cannot
  use, other asset files (`.vmov`, `.vrb`, `.vgz`), and for a C project whether its Makefile
  compiles assets. `asset_get_format {type}` returns the format, a minimal valid example, the
  folder, the editor, the targets and the usage. `asset_create {type, name, content, overwrite?,
  open?}` writes `<folder>/<name>.<ext>`, sets the asset's own name to the file name, checks
  that the assets it references exist, and compiles it with `vpy_cli check-asset` (and, in a C
  project, `vpy_cli compile-asset --format c`, the Makefile's step). On a compile error the file
  is removed, or restored when it replaced one, and the compiler's message is returned.
  `project_create_vector` / `_music` / `_sfx` are shortcuts for it, with templates when the
  content is empty.
- `asset_create` and `project_create_*` refuse to overwrite an existing asset unless `overwrite: true`.
- `project_close` refuses while documents are unsaved unless `force: true`.

## Testing

```bash
cd ide/electron && npm run build      # compiles ide/electron/src/mcp → dist/mcp
node ide/mcp-server/test/run-tests.js
```

The test runs `server.js` over stdio against the IDE's real TCP server and tool registry (with a
fake window in a `vm` sandbox): auth accepted/rejected, IDE down → `isError`, background
reconnect + `tools/list_changed`, restart of the IDE, MCP framing, argument injection, path
containment, running under `ELECTRON_RUN_AS_NODE=1`, the instructions (from the IDE, the
fallback when it is down, every tool they name exists, the checklist comes first, the size
does not grow), `ide_get_context` (also its `assets` and `api` for a VPy and a C project, and
its size), `api_reference` (VPy: equal to the compiler's catalog and covering the m6809 arity
registry; C: equal to an independent scan of the pinned SDK's `vpy.h`, with a synthetic SDK
version that adds a rotation call),
`settings_set_build_target`, `ide_run` outcomes, `compiler_build` on a `.cvproj`, and
`project_create` with `kind: "c"`. When `ide/frontend/node_modules` has esbuild it also bundles
`test/renderer/bridge.test.ts` and runs the renderer half (`mcpBridge.ts`: `setBuildTarget`,
`runBuild` waiting on the emulator store, per-build output capture) in Node.

## Manual use

```bash
VECTREX_STUDIO_MCP_PORT=9123 VECTREX_STUDIO_MCP_TOKEN=<token> node ide/mcp-server/server.js
```

The token is only available from the running IDE (`getMcpLaunchSpec()`), so in practice the
IDE launches the server for you.
