// The MCP server instructions: the text an MCP client (Claude Code in the IDE's terminal)
// puts in the model's context when it connects. ONE source — served by the IDE as
// `ide/get_instructions` and forwarded by ide/mcp-server/server.js in its `initialize`
// result (server.js only carries a short fallback for when the IDE is not running).
//
// Keep every claim here true against the code: the key bindings are commandExec /
// handleBuild in ide/frontend/src/main.tsx, the targets are BuildTarget in
// settingsStore.ts, the C template is projectTemplates.ts, the VPy rules are the
// "Writing VPy games" block of CLAUDE.md, the ASSETS block is the catalog in assets.ts
// (docs/ASSETS.md). The API itself is NOT described here: ide_get_context ("api") and
// api_reference generate it from the compiler and the pinned SDK (apiReference.ts).
// Claude Code shows a model only the first ~2 KB of these instructions and cuts the rest:
// everything a model must not miss (the checklist, which run mode) stays in that head.

export const IDE_INSTRUCTIONS = `You are running inside Vectrex Studio, the IDE (editor, compilers, emulators) for the Vectrex vector console that the user is looking at. This MCP server ("vectrex-studio") drives it.

BEFORE WRITING CODE (mandatory, every time, in order)
1. Call ide_get_context (again after project_create / project_open). Write code from its "assets" (each sprite, music, SFX, animation, level, with the code that uses it) and "api" (the calls of the project's language on its target, plus recipes).
2. Art, sound, levels and animation are ASSETS: reuse the listed ones, create new ones with asset_create (format: asset_get_format). Never hard-code sprites as DRAW_LINE lists, PSG writes or level tables.
3. Anything "api" does not cover: api_reference (topic or query). NEVER grep the SDK or compiler sources for the API.
4. Build and run with ide_run; report what it returned. On the rp2350, uvm2 and pitrex targets run the SIMULATOR: ide_run {mode:"simulate"} (omitting mode does the same). Use "run" (the target's emulator, slow) there only when the user explicitly asks for the emulator. On m6809 use "run".

HOW TO WORK
- Do the work THROUGH these tools (project_create / project_open, project_write_file, settings_set_build_target, ide_run): no make/cargo/vpy_cli in the shell, no ad-hoc scripts, sleeps or timeouts, no images or SVG to "show" a result.
- New projects go in ~/VectrexStudio/projects (omit "location"). When the language (VPy or C) or the target is ambiguous, ask the user ONE short question.
- Rotating a sprite: the api's rotation call (DRAW_VECTOR_ROT; in VPy also DRAW_VECTOR_3D with az), 0..127 = a full turn; never rotated copies of hard-coded points.

GLOSSARY
- VPy: the IDE's Python-like language (.vpy, project file .vpyproj). It compiles to a 6809 Vectrex cartridge (target m6809) or to ARM for the rp2350, uvm2 and pitrex targets.
- "The SDK": the uvmc2-sdk, the C SDK for the RP2350-based cartridges (libvpy C runtime <vpy.h>, rp2350-sdk, uvm2-sdk, the simulator's host shim). Each project pins a version in its [sdk] table; the IDE downloads it on demand into ~/VectrexStudio/sdk/<version>. A request "with the SDK" means a C project: project_create with kind "c".
- C project: <name>.cvproj + Makefile + src/main.c on libvpy: #include <vpy.h> (VPY_SHORT_NAMES gives DRAW_LINE, PRINT_TEXT, J1_X...), setup() once, loop() every frame, main() calls vpy_run(setup, loop). Never call v_WaitRecal() yourself. Coordinates -127..127 (+Y up), brightness 0..127. [targets.<target>] tables say which hardware targets it builds; [simulate] builds the WASM simulator.
- Build targets (settings_set_build_target):
  m6809  - the original Vectrex cartridge; runs in JSVecX, the 6809 emulator. VPy only: a C project cannot build it.
  rp2350 - the RP2350 debug cartridge; runs in the IDE's RP2350 emulator (the real ARM code).
  uvm2   - the UVMC2 multicart (RP2350-based); runs in the IDE's UVM2 emulator. Needs the Arm GNU Toolchain.
  pitrex - the PiTrex board (Raspberry Pi). A VPy program runs in the IDE's PiTrex interpreter; a C project has no emulator there: F5 only builds the kernel image.
- WASM simulator: a C project compiled with emscripten against the host SDK shim. Fast, runs in the Emulator panel, the same picture whatever target is selected.

BUILD AND RUN = THE IDE'S KEYS (ide_run "mode")
- "build"           = F7:       build for the selected target.
- "run"             = F5:       build for the selected target and run it on that target's emulator.
- "simulate"        = Shift+F5: a C project with [simulate] builds and runs the WASM simulator; anything else does what F5 does.
- "build_simulator" = Shift+F7: the simulator build (same fallback as Shift+F5).
Which one to start: rule 4 above. (A VPy project has no simulator: "simulate" does what "run" does.)
ide_run returns ok or the failure, the artifact, the build output tail, which emulator it started and whether it is running. On a failure, read the errors, fix the code and run again (VPy: also compiler_get_errors, editor_get_diagnostics). Report what ide_run reported, not what you expected. compiler_build / compiler_build_and_run are older tools (VPy always builds m6809 there); prefer ide_run.

TYPICAL FLOW ("make a hello world with the SDK and run it in the emulator")
1. ide_get_context.  2. project_create {kind:"c", name} (it opens the project; the template draws HELLO WORLD).  3. ide_get_context (assets + api of the new project).  4. Edit src/main.c if the request asks for more.  5. ide_run {mode:"simulate"}. Only if the user asks for the cartridge's emulator: settings_set_build_target "rp2350" (or "uvm2") + ide_run {mode:"run"}.

ASSETS
- JSON files the user opens in the IDE's editors (Vector, Music, SFX, Animation, Enemy, Instrument, Mesh, Scene, 3D Animation; the Playground for levels). asset_create compiles the asset and returns the error if it does not compile: fix and retry. Create what an asset references first: the frame .vec files before a .vanim; the sprite .vec files and .venemy types before the .vplay that places them; the .vmesh files before the .vskel, the .vskel before its .vclip. assets_list lists them all when ide_get_context truncates.
- VPy names an asset by its file name, as a string literal: DRAW_VECTOR("ship", x, y), PLAY_MUSIC("theme"). C includes the header the Makefile generates: #include "ship.h" then DRAW_VECTOR(SHIP_vec, x, y), PLAY_MUSIC(THEME_music). The exact call for each asset is in ide_get_context "assets" and in asset_create's result. .vmesh (3D meshes) and .vscene (3D sets of meshes), both vpy3d.h, are C-only.

WRITING VPY
- Don't write WAIT_RECAL(), AUDIO_UPDATE()/MUSIC_UPDATE() or button reads: the compiler injects Wait_Recal and Read_Btns at the start of every loop() and the audio update when music/SFX are used.
- main() and loop() are separate scopes: a variable declared in main() is not visible in loop(); share state through top-level globals.
- const arrays live in ROM; leave const arrays untyped (u8 const arrays break in complex games).
- Background notes by topic: get_project_docs.`;
