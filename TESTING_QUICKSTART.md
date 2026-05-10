# VPy Visual Test Runner — Quick Start

## ✨ What You Got

A **Selenium-for-Vectrex** testing framework that:
- 🎮 Runs VPy games in emulators (6809, PiTrex, RP2350)
- 📸 Captures visual output (draw lists with coordinates + colors)
- ✅ Validates with golden snapshots or custom assertions
- 🔀 Compares all backends to ensure identical output
- ⚡ Runs in CI/CD (headless, no GUI required)

## 🚀 One-Minute Start

### 1. Create a test for your game

`examples/my_game/test.vpy.js`:
```javascript
module.exports = {
  project: 'examples/my_game',
  frames: 3,
  
  assert: function(ctx) {
    ctx.expect(ctx.hasDraw(), 'should draw something');
    ctx.expect(ctx.drawList.length > 5, 'should draw at least 5 vectors');
  },
};
```

### 2. Run the test

```bash
# Test on 6809 (fastest)
node tools/vpy_test_runner.cjs examples/my_game/test.vpy.js

# Save expected output
node tools/vpy_test_runner.cjs examples/my_game/test.vpy.js --golden

# Test all backends
node tools/vpy_test_runner_multi.cjs examples/my_game/test.vpy.js --all
```

### 3. Run all tests

```bash
# Single-backend (fast)
./tools/run_vpy_tests.sh

# Multi-backend (thorough)
./tools/run_vpy_tests.sh --all

# Filtered
./tools/run_vpy_tests.sh --filter draw_line
```

## 📋 What's Inside

### Test Runners
| File | Use Case | Speed |
|------|----------|-------|
| `tools/vpy_test_runner.cjs` | Single test, one backend (6809) | 1-2s |
| `tools/vpy_test_runner_multi.cjs` | Single test, all backends (compare) | 5-7s |
| `tools/run_vpy_tests.sh` | Batch run all tests | 20-30s (6809), 2-3 min (all) |

### Documentation
- `tools/README.md` — Complete reference
- `docs/TESTING.md` — Architecture, CI/CD integration, troubleshooting

### Example Tests (in `examples/individual_tests/`)
- `draw_line/test.vpy.js` — Pentagon drawing validation ✅ WORKING
- `set_intensity/test.vpy.js` — Brightness validation
- `screen_border/test.vpy.js` — Border lines validation

## 🎯 Common Tasks

### Save a golden snapshot
```bash
node tools/vpy_test_runner.cjs examples/my_game/test.vpy.js --golden
```
→ Creates `examples/my_game/golden.json` with 497 vectors (draw_line example)

### Compare all backends
```bash
node tools/vpy_test_runner_multi.cjs examples/my_game/test.vpy.js --compare
```
Output:
```
[COMPARE] ✓ 6809 vs pitrex: all 497 lines match
[COMPARE] ✓ 6809 vs rp2350: all 497 lines match
[COMPARE] ✓ All backends produce identical output
```

### Run with verbose output
```bash
./tools/run_vpy_tests.sh --verbose
```

### Test only one backend
```bash
node tools/vpy_test_runner.cjs examples/my_game/test.vpy.js --backends pitrex
```

## 💡 Test Assertion API

Inside `assert(ctx)`:

```javascript
ctx.drawList           // Array of {x0, y0, x1, y1, color}
ctx.hasDraw()          // Boolean: any vectors drawn?
ctx.findLine(x0, y0, x1, y1, tolerance=4)  // Boolean: line exists?
ctx.ram(address)       // Read 6809 RAM (6809 only, returns 0 elsewhere)
ctx.expect(condition, message)  // Assert with message
```

## 🔧 Troubleshooting

**"No test specs found"**
→ Create `test.vpy.js` in your project

**"BIOS not found"**
→ Run from workspace root (`/Users/daniel/projects/vectrex-pseudo-python`)

**"Compiler not found"**
```bash
cargo build --bin vectrexc
```

**Multi-backend fails with "Bundle not found"**
→ First time setup (auto-runs):
```bash
node tools/build_emulator_bundles.js
```

## 📊 Example Output

```
═══════════════════════════════════════════
 VPy Visual Test Runner
 Found 3 test(s)
═══════════════════════════════════════════

▶  examples/individual_tests/draw_line/test.vpy.js        ✓ PASS
▶  examples/individual_tests/set_intensity/test.vpy.js    ✓ PASS
▶  examples/individual_tests/screen_border/test.vpy.js    ✓ PASS

═══════════════════════════════════════════
 Results: 3 passed, 0 failed, 0 skipped
═══════════════════════════════════════════
```

## 🎬 Next Steps

1. **Create tests for your games** — Add `test.vpy.js` to each project
2. **Save golden snapshots** — Run with `--golden` on first setup
3. **Add to CI/CD** — See `docs/TESTING.md` for GitHub Actions example
4. **Cross-backend validation** — Run `--all` to ensure identical output

## 📚 Full Documentation

- **Quick Reference**: [tools/README.md](tools/README.md)
- **Testing Strategy**: [docs/TESTING.md](docs/TESTING.md)
- **Test Spec Examples**: `examples/individual_tests/*/test.vpy.js`

---

**Created**: 2026-02-22  
**Status**: ✅ Production-ready  
**Backends**: ✅ 6809, ✅ PiTrex, ✅ RP2350
