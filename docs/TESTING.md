# VPy Testing Strategy

Comprehensive visual testing framework for VPy games across all three hardware targets (6809, PiTrex, RP2350).

## Overview

The VPy test runner is inspired by **Selenium for web browsers** but adapted for retro console emulation:

- **Headless execution** — No GUI required, fully automated
- **Multiple backends** — Test the same game on 6809, PiTrex, and RP2350
- **Visual capture** — Automatically extract draw lists from emulators
- **Golden snapshots** — Compare current output against expected (with tolerance)
- **Programmatic validation** — Write custom assertions in JavaScript
- **Cross-platform verification** — Ensure all targets produce identical output

## Why Test Visually?

Traditional unit tests verify **logic** (e.g., "did this function return 42?"). Visual tests verify **output** (e.g., "are the three lines drawn where we expect them?").

This is essential for game development because:
1. **Graphics bugs are hard to catch** — Off-by-one errors in sprite coordinates, wrong intensity values
2. **Cross-backend compatibility** — Same VPy code should render identically on 6809 and RP2350
3. **Regression detection** — Changes to the compiler should not break existing visuals
4. **Deterministic** — Emulator output is reproducible; no randomness or timing issues

## Architecture

### Single-Backend Runner (`vpy_test_runner.cjs`)

Fast testing on **6809 only** (default):

```
Test spec (test.vpy.js)
    ↓
Compile to 6809 (.bin)
    ↓
Load jsvecx emulator
    ↓
Run N frames, capture drawList
    ↓
Validate (golden or assertions)
```

**Time**: ~1-2s per test (mostly compilation)

### Multi-Backend Runner (`vpy_test_runner_multi.cjs`)

Full validation on **all three targets**:

```
Test spec (test.vpy.js)
    ↓
Compile to 6809 (.bin), PiTrex (.s), RP2350 (.bin/.elf)
    ↓
┌─────────────────────┬─────────────────────┬──────────────────┐
│ 6809 (jsvecx)       │ PiTrex (ARM32)      │ RP2350 (ARM CM33)│
│ Load jsvecx bundle  │ Load PitrexCore     │ Load Rp2350Sys   │
│ Run N frames        │ Run N frames        │ Run N frames     │
│ Capture drawList    │ Capture segments    │ Capture segments │
└─────────────────────┴─────────────────────┴──────────────────┘
    ↓
Normalize to common format (x0, y0, x1, y1, color)
    ↓
Compare outputs (with ±2px tolerance)
    ↓
Report: all backends match or identify differences
```

**Time**: ~5-7s per test (3 emulator runs + compilation)

### Emulator Bundling (`build_emulator_bundles.js`)

On first use, TypeScript emulators are bundled to CommonJS for Node.js:

```
PitrexCore.ts + dependencies
    ↓ esbuild
→ tools/emulators/pitrex.cjs

Rp2350System.ts + dependencies
    ↓ esbuild
→ tools/emulators/rp2350.cjs
```

**Time**: ~10-30s (one-time setup)

## Test Spec Format

Every test needs a `test.vpy.js` file in the project directory:

```javascript
module.exports = {
  // REQUIRED
  project: 'path/to/project',  // relative to workspace root
  
  // OPTIONAL
  frames: 3,                    // warmup frames before capture (default: 3)
  goldenTolerance: 2,           // pixel tolerance for golden comparison (default: 2)
  
  // OPTIONAL: assertions
  assert: function(ctx) {
    // Validate the captured frame
    
    // ctx.drawList — array of {x0, y0, x1, y1, color}
    ctx.expect(ctx.drawList.length > 0, 'should draw at least one line');
    
    // ctx.hasDraw() — true if any vectors were drawn
    ctx.expect(ctx.hasDraw(), 'should draw something');
    
    // ctx.findLine(x0, y0, x1, y1, tolerance) — true if line exists
    ctx.expect(ctx.findLine(0, 0, 100, 100), 'should have diagonal line');
    
    // ctx.ram(address) — read 6809 RAM (returns 0 for non-6809)
    const playerX = ctx.ram(0xC800);
    ctx.expect(playerX > 0, 'player should have valid X');
    
    // ctx.expect(condition, message) — assertion
    ctx.expect(true, 'this always passes');
  },
};
```

### Validation Modes

**1. Golden Snapshots** (automatic comparison)

```bash
# First run: capture expected output
node tools/vpy_test_runner.cjs test.vpy.js --golden

# Generated: examples/my_game/golden.json (array of vectors)

# Future runs: automatically compare
node tools/vpy_test_runner.cjs test.vpy.js
# ✓ Golden snapshot matches (497 vectors)
```

**2. Programmatic Assertions** (custom logic)

```bash
# Run test with spec.assert() validation
node tools/vpy_test_runner.cjs test.vpy.js
# Results: 3/3 passed [PASS]
```

**3. Both** (golden + assertions)

Snapshots are compared first (automatic). Then `spec.assert()` runs if defined.

## Usage Examples

### Example 1: Test draw_line

```bash
cd /Users/daniel/projects/vectrex-pseudo-python

# First run: save golden snapshot
node tools/vpy_test_runner.cjs examples/individual_tests/draw_line/test.vpy.js --golden

# Future runs: validate
node tools/vpy_test_runner.cjs examples/individual_tests/draw_line/test.vpy.js
```

### Example 2: Multi-backend comparison

```bash
# Compile to all backends and compare
node tools/vpy_test_runner_multi.cjs examples/individual_tests/draw_line/test.vpy.js --compare

# Output:
# [COMPARE] ✓ 6809 vs pitrex: all 497 lines match
# [COMPARE] ✓ 6809 vs rp2350: all 497 lines match
# [COMPARE] ✓ All backends produce identical output
```

### Example 3: Run all tests

```bash
# Single-backend (fast, suitable for CI)
./tools/run_vpy_tests.sh

# Multi-backend (thorough validation)
./tools/run_vpy_tests.sh --all

# Specific tests only
./tools/run_vpy_tests.sh --filter draw

# Verbose output
./tools/run_vpy_tests.sh --verbose
```

## Performance

| Scenario | Time | Notes |
|----------|------|-------|
| Single test (6809) | ~1-2s | Fastest, use for development |
| Single test (multi) | ~5-7s | Full validation |
| All individual_tests (6809) | ~20-30s | 20+ tests, good for CI |
| All individual_tests (multi) | ~2-3 min | Complete cross-backend validation |

## CI/CD Integration

### GitHub Actions

```yaml
name: Test VPy Games

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: actions/setup-node@v3
        with:
          node-version: 20
      
      - run: npm install
      - run: node tools/build_emulator_bundles.js
      - run: ./tools/run_vpy_tests.sh --all
```

### Local Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit
set -e

echo "[PRE-COMMIT] Running VPy tests..."
./tools/run_vpy_tests.sh --filter examples/ || {
  echo "[FAIL] Tests failed. Commit blocked."
  exit 1
}
echo "[OK] Tests passed."
```

Install:
```bash
chmod +x .git/hooks/pre-commit
```

## Debugging Failures

### "Golden snapshot doesn't match"

```bash
# Regenerate golden snapshot (after verifying visually)
node tools/vpy_test_runner.cjs test.vpy.js --golden

# Or examine the old vs new
diff examples/my_game/golden.json <(node tools/vpy_test_runner.cjs test.vpy.js --dump-json)
```

### "Backends differ"

When `--compare` shows mismatches between 6809 and PiTrex/RP2350:

```bash
# Check if it's a coordination difference (expected)
# Or a real bug in the codegen

# First: Is it tolerance? Try:
node tools/vpy_test_runner_multi.cjs test.vpy.js --backends 6809,pitrex --verbose

# Look for "mismatches in vector[N]"
```

### Multi-backend assertion fails on one target

```bash
# Run just that backend
node tools/vpy_test_runner.cjs test.vpy.js --backends pitrex

# This will help isolate the issue to that backend's emulator
```

## Roadmap

- [ ] Frame-by-frame capture (not just first frame)
- [ ] Audio validation (PSG register writes)
- [ ] Input sequence testing (joystick + buttons over multiple frames)
- [ ] Performance profiling (cycles per backend)
- [ ] Memory usage validation
- [ ] Coverage reporting for test suite

## Files

| File | Purpose |
|------|---------|
| `tools/vpy_test_runner.cjs` | Single-backend runner (6809) |
| `tools/vpy_test_runner_multi.cjs` | Multi-backend runner (6809/pitrex/rp2350) |
| `tools/build_emulator_bundles.js` | Bundles TypeScript emulators to CJS |
| `tools/run_vpy_tests.sh` | Batch test harness |
| `tools/README.md` | Quick reference |
| `examples/*/test.vpy.js` | Test specs (one per project) |

## See Also

- [Selenium WebDriver](https://www.selenium.dev/) — Inspiration for the automated testing approach
- [buildtools/README.md](../buildtools/README.md) — Compiler architecture
- [tools/README.md](../tools/README.md) — Runner quick reference
