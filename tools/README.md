# VPy Visual Test Runner

Automated testing framework for VPy games with support for multiple hardware backends (6809, PiTrex, RP2350).

## Features

✅ **Multi-backend support** — Test on 6809 (Vectrex), PiTrex (ARM), RP2350 (ARM Cortex-M33)  
✅ **Golden snapshots** — Capture and compare frame output automatically  
✅ **Programmatic assertions** — Write custom validation logic  
✅ **Cross-backend comparison** — Verify all targets produce identical output  
✅ **Headless execution** — No GUI required, runs in CI/CD pipelines  

## Quick Start

### 1. Create a test spec

Create `examples/my_game/test.vpy.js`:

```javascript
module.exports = {
  project: 'examples/my_game',
  frames: 3,

  assert: function(ctx) {
    ctx.expect(ctx.hasDraw(), 'should draw something');
    ctx.expect(ctx.drawList.length > 0, 'should have lines');
  },
};
```

### 2. Run single-backend test

```bash
# Test on 6809 (default, fastest)
node tools/vpy_test_runner.cjs examples/my_game/test.vpy.js

# Save golden snapshot
node tools/vpy_test_runner.cjs examples/my_game/test.vpy.js --golden
```

### 3. Run multi-backend test

```bash
# Test on all backends (6809, pitrex, rp2350)
node tools/vpy_test_runner_multi.cjs examples/my_game/test.vpy.js --all

# Compare outputs from all backends
node tools/vpy_test_runner_multi.cjs examples/my_game/test.vpy.js --compare
```

### 4. Run all tests

```bash
# Single-backend (fast)
./tools/run_vpy_tests.sh

# Multi-backend
./tools/run_vpy_tests.sh --all

# Filter by name pattern
./tools/run_vpy_tests.sh --filter draw_line

# Show detailed output
./tools/run_vpy_tests.sh --verbose
```

## Test Spec Format

```javascript
module.exports = {
  // Required
  project: 'path/to/project',        // relative to workspace root
  
  // Optional
  frames: 3,                          // frames to warm up before capture
  goldenTolerance: 2,                 // pixel tolerance for golden comparison
  
  // Optional: assertions
  assert: function(ctx) {
    // ctx.drawList      — array of {x0, y0, x1, y1, color} vectors
    // ctx.hasDraw()     — true if any lines were drawn
    // ctx.findLine(x0, y0, x1, y1, tolerance)  — find a line
    // ctx.ram(address)  — read RAM at address (6809 only)
    // ctx.expect(condition, message)  — assertion
    
    ctx.expect(ctx.hasDraw(), 'should draw at least one line');
    ctx.expect(
      ctx.drawList.filter(v => v.color > 100).length > 0,
      'should have bright lines'
    );
    ctx.expect(
      ctx.findLine(0, 0, 10, 10),
      'should draw line from (0,0) to (10,10)'
    );
  },
};
```

## Backends

### 6809 (Vectrex - jsvecx)
- **Speed**: ~1s per test
- **Format**: `vectors_draw` array
- **Files**: `.bin` binary
- **Status**: ✅ Fully implemented

### PiTrex (ARM32)
- **Speed**: ~2-3s per test (includes TypeScript bundling on first run)
- **Format**: `segments` array
- **Files**: `.s` (ARM32 assembly)
- **Status**: ✅ Implemented (builds on demand)

### RP2350 (ARM Cortex-M33)
- **Speed**: ~2-3s per test (includes TypeScript bundling on first run)
- **Format**: `segments` array
- **Files**: `.bin` (binary) + optional `.elf` (symbols)
- **Status**: ✅ Implemented (builds on demand)

## Golden Snapshots

Capture the expected output of your test:

```bash
# Save golden snapshot for 6809
node tools/vpy_test_runner.cjs test.vpy.js --golden

# Generates: examples/my_game/golden.json (497 vectors)
```

Future runs automatically compare against the golden snapshot with ±2px tolerance.

## Examples

### Test draw_line

```bash
cd examples/individual_tests/draw_line
node ../../tools/vpy_test_runner.cjs test.vpy.js
```

**Output:**
```
[BIN] examples/individual_tests/draw_line/src/main.bin
[EMU] Reset OK, PC=0xF000, cart=32768 bytes
[EMU] Running 3 frame(s) (30000 cycles each)...
[DRAW] 497 vector(s) drawn:
  [0] (5790,4180)→(5790,4180) color=127
  [1] (6994,4180)→(7252,4180) color=127
  ...

Results: 3/3 passed
[PASS]
```

## Troubleshooting

### "No test specs found"
Create `test.vpy.js` in your project directory.

### "BIOS not found"
Run from workspace root. BIOS is at `ide/frontend/src/assets/bios.bin`.

### "Compiler not found"
Run:
```bash
cargo build --bin vectrexc
```

### Multi-backend fails with "Bundle not found"
On first use, the runner auto-builds TypeScript emulators:
```bash
node tools/build_emulator_bundles.js
```

Or manually:
```bash
npm install  # ensure esbuild is installed
node tools/build_emulator_bundles.js
```

## Architecture

```
vpy_test_runner.cjs (single-backend)
    └─ 6809: jsvecx (JavaScript emulator)
       └─ captures drawList

vpy_test_runner_multi.cjs (multi-backend)
    ├─ 6809: jsvecx
    │  └─ drawList
    ├─ pitrex: PitrexCore (TypeScript→CJS)
    │  └─ segments
    └─ rp2350: Rp2350System (TypeScript→CJS)
       └─ segments

build_emulator_bundles.js
    ├─ esbuild PitrexCore.ts → tools/emulators/pitrex.cjs
    └─ esbuild Rp2350System.ts → tools/emulators/rp2350.cjs
```

## CI/CD Integration

### GitHub Actions

```yaml
- name: Test VPy Games
  run: |
    npm install
    node tools/build_emulator_bundles.js
    ./tools/run_vpy_tests.sh --all
```

### Local Pre-commit

```bash
#!/bin/bash
# .git/hooks/pre-commit
./tools/run_vpy_tests.sh --filter examples/ || exit 1
```

## Performance

| Backend | Time/test | Compile | Notes |
|---------|-----------|---------|-------|
| 6809    | ~1s       | ~500ms  | Fastest, use for CI |
| PiTrex  | ~2-3s     | ~1s     | Builds ASM interpreter on first run |
| RP2350  | ~2-3s     | ~1s     | Builds ARM interpreter on first run |
| All 3   | ~5-7s     | ~2s     | Full cross-validation |

## See Also

- [docs/TESTING.md](../docs/TESTING.md) — Testing strategy and best practices
- [buildtools/README.md](../buildtools/README.md) — Compiler architecture
- `test.vpy.js` files in `examples/individual_tests/` — Example specs
