Launch the Vectrex Studio IDE.

Run `./run-ide.sh` from the project root (`run-ide.ps1` on Windows). It:
1. builds `vpy_cli` and `vpy_lsp` from `buildtools/` with cargo and copies them into `ide/electron/resources/` (`--fast` uses the quicker `dev-fast` cargo profile and skips `npm install` when `node_modules` exists),
2. always rebuilds the React frontend (`ide/frontend`, `npm run build`) and the Electron main process (`ide/electron`, `npm run build`),
3. starts Electron.

A UI change is not live until `ide/frontend/dist` has been rebuilt, which this script does.

If it fails, check:
- Node.js 22.12+ (`ide/frontend/package.json` engines) and npm on PATH
- cargo on PATH (without it the Rust binaries are not rebuilt and the existing copies in `resources/` are used)
- `ide/electron/src/main.ts` (main process) and `ide/frontend/src/main.tsx` (renderer)

At startup the IDE opens its MCP endpoint on `127.0.0.1:9123` (or the next free port up to 9133), authenticated with a token generated per run. `claude` started from the IDE's integrated terminal gets the `vectrex-studio` MCP server automatically (`ide/mcp-server/README.md`).
