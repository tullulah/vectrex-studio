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
├── core/              # Core (legacy) compiler — Rust crate
│   └── src/
│       ├── lexer.rs
│       ├── parser.rs
│       ├── codegen.rs
│       └── lsp.rs     # LSP server (shared by both backends)
├── buildtools/        # Buildtools (new) compiler — 9 Rust crates
│   ├── vpy_loader/
│   ├── vpy_parser/
│   ├── vpy_assembler/
│   └── ...
├── ide/
│   ├── frontend/      # React + Vite UI
│   ├── electron/      # Electron shell
│   └── mcp-server/    # MCP server (Node.js)
├── examples/          # Example VPy projects
└── docs/              # Documentation
```

---

## Build

### 1. Build the Core compiler

```bash
cargo build --bin vectrexc
```

Binary output: `target/debug/vectrexc`

For release:
```bash
cargo build --bin vectrexc --release
```

### 2. Build the LSP server

```bash
cargo build --bin vpy_lsp
```

The IDE launches this automatically — you only need to build it manually if you're working on the LSP.

### 3. Build the Buildtools compiler (optional)

```bash
cargo build --bin vpy_cli
```

Only needed if you're working on the new compiler pipeline or need multibank/PDB support.

### 4. Install IDE dependencies

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

### Windows convenience script

On Windows, `run-ide.ps1` in the project root launches both processes:
```powershell
.\run-ide.ps1
```

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

### Test the Core compiler

```bash
./target/debug/vectrexc --help
```

Expected output includes: `Usage: vectrexc <COMMAND>`

Compile a test file:
```bash
./target/debug/vectrexc build examples/hello/src/main.vpy
```

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

### "vectrexc not found"
```bash
cargo build --bin vectrexc
ls target/debug/vectrexc*
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

# Compiler tests only:
cargo test --package vectrex_lang

# Specific test:
cargo test test_adda_immediate -- --nocapture
```

---

## Next Steps

- [MANUAL.md](MANUAL.md) — VPy language reference
- [IDE_GUIDE.md](IDE_GUIDE.md) — How to use the IDE
- [COMPILER_STATUS.md](COMPILER_STATUS.md) — Compiler backend status and known limitations
- `examples/` — Working example projects to study and run
