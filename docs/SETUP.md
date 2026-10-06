# Vectrex Studio — Setup Guide

Complete guide to setting up the development environment from scratch.

---

## Prerequisites

### System requirements
- **macOS** 12+, **Linux** (Ubuntu 20.04+), or **Windows** 10/11
- **RAM**: 8 GB minimum (16 GB recommended for AI features)
- **Disk**: 5 GB free

### Required tools

**1. Rust (stable)**

```bash
# macOS / Linux:
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Then:
rustup default stable
rustup update
```

Verify: `rustc --version` (requires >= 1.70.0)

**2. Node.js 18+**

```bash
# macOS:
brew install node@18

# Ubuntu/Debian:
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

Verify: `node --version`

**3. Git**

```bash
brew install git        # macOS
sudo apt-get install git  # Ubuntu
```

---

## Clone the Repository

```bash
git clone https://github.com/tullulah/vectrex-studio.git
cd vectrex-studio
```

---

## Project Structure

```
vectrex-studio/
├── buildtools/        # VPy compiler — one Rust crate per phase
│   ├── vpy_loader/
│   ├── vpy_parser/
│   ├── vpy_assembler/
│   ├── ...
│   ├── vpy_cli/       # Compiler CLI (binary: vpy_cli)
│   └── vpy_lsp/       # Language server (binary: vpy_lsp)
├── ide/
│   ├── frontend/      # React + Vite UI
│   ├── electron/      # Electron shell
│   └── mcp-server/    # MCP server (Node.js)
├── examples/          # Example VPy projects
└── docs/              # Documentation
```

---

## Build

### 1. Build the compiler

```bash
cargo build --bin vpy_cli
```

Binary output: `target/debug/vpy_cli`

For release:
```bash
cargo build --bin vpy_cli --release
```

### 2. Build the LSP server

```bash
cargo build --bin vpy_lsp
```

Both binaries can be built from the repository root (workspace) or from `buildtools/`. The IDE runs the copies in `ide/electron/resources/`; `run-ide.sh` / `run-ide.ps1` build `vpy_cli` and `vpy_lsp` and copy them there, so you only need to build them by hand when working on the compiler or the LSP outside the IDE.

### 3. Install IDE dependencies

```bash
cd ide/frontend && npm install && cd ../..
cd ide/electron && npm install && cd ../..
cd ide/mcp-server && npm install && cd ../..
```

---

## Launch the IDE

Open two terminals:

**Terminal 1 — Frontend dev server:**
```bash
cd ide/frontend
npm run dev
# Wait for: "Local: http://localhost:5173/"
```

**Terminal 2 — Electron:**
```bash
cd ide/electron
npm start
```

The IDE window will open automatically.

### Convenience scripts

`run-ide.sh` (macOS / Linux) and `run-ide.ps1` (Windows) in the project root build `vpy_cli` + `vpy_lsp`, copy them into `ide/electron/resources/`, and launch both processes:
```bash
./run-ide.sh
```
```powershell
.\run-ide.ps1
```

If you launch the two processes manually, build the binaries first and copy `target/debug/vpy_cli` and `target/debug/vpy_lsp` into `ide/electron/resources/`.

---

## Vectrex BIOS

The emulator requires the Vectrex BIOS ROM file.

**Required location:**
```
ide/frontend/dist/bios.bin
```

The file is 8 KB (8192 bytes). Obtain it separately (it is freely available online).

```bash
mkdir -p ide/frontend/dist
cp /path/to/your/bios.bin ide/frontend/dist/bios.bin
```

Verify:
```bash
wc -c ide/frontend/dist/bios.bin   # should be 8192
```

---

## Verify the Setup

### Test the compiler

```bash
./target/debug/vpy_cli --help
```

Expected output includes: `Usage: vpy_cli <COMMAND>`

Compile an example project:
```bash
./target/debug/vpy_cli build examples/pong/pong.vpyproj -o /tmp/pong.bin
```

Options: `--target m6809|rp2350|pitrex|uvm2` (default `m6809`), `--debug` (also emit `.pdb` debug symbols). `vpy_cli asm <file.vpy|project.vpyproj>` prints the generated assembly.

The `uvm2` target (and the optional libvpy C runtime of `pitrex`) needs the uvmc2-sdk,
which is not part of this repository. `vpy_cli` uses the release pinned in the project's
`[sdk]` table once Vectrex Studio has downloaded it to `~/VectrexStudio/sdk/<version>/`, or
any SDK you point `UVMC2_SDK` at. `m6809` builds need nothing extra. See
[SDK_VERSIONS.md](SDK_VERSIONS.md).

### Test the IDE

1. Launch the IDE (see above)
2. Use **File → Open Project** to open an example from `examples/`
3. Click **Run** (▶)
4. The game should appear in the emulator panel

---

## Troubleshooting

### "cargo: command not found"
Restart your terminal after installing Rust, or run:
```bash
source $HOME/.cargo/env
```

### "vpy_cli not found"
```bash
cargo build --bin vpy_cli
ls target/debug/vpy_cli*
```

### "Cannot find BIOS" / emulator shows blank screen
Copy `bios.bin` to `ide/frontend/dist/bios.bin` (see BIOS section above).

### Port 5173 already in use
```bash
# macOS / Linux:
lsof -ti:5173 | xargs kill -9
```
Then restart the frontend dev server.

### Electron window doesn't open
```bash
cd ide/electron
npm install
npm start
```

---

## Run Tests

```bash
# All Rust tests:
cargo test --workspace

# Compiler tests (all phases):
cd buildtools && cargo test --all

# One phase:
cargo test -p vpy_codegen

# Specific test:
cargo test test_adda_immediate -- --nocapture
```

---

## Next Steps

- [MANUAL.md](MANUAL.md) — VPy language reference
- [IDE_GUIDE.md](IDE_GUIDE.md) — How to use the IDE
- [COMPILER_STATUS.md](COMPILER_STATUS.md) — Compiler backend status and known limitations
- `examples/` — Working example projects to study and run
