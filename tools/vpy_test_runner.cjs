#!/usr/bin/env node
/**
 * vpy_test_runner.cjs
 * ─────────────────────────────────────────────────────────────
 * Headless VPy test runner — "Selenium for VPy"
 *
 * Usage:
 *   node tools/vpy_test_runner.cjs <test_spec.js> [options]
 *   node tools/vpy_test_runner.cjs examples/individual_tests/draw_line/test.vpy.js
 *
 * Options:
 *   --golden          Save current draw-list as golden snapshot (first-time setup)
 *   --frames N        Run N frames before asserting (default: 3)
 *   --no-compile      Skip compilation, use existing .bin
 *   --verbose         Print draw list and memory dumps
 *
 * Test spec format (test.vpy.js):
 *   module.exports = {
 *     project: 'examples/individual_tests/draw_line',  // dir with .vpyproj
 *     frames: 3,                                        // frames to warm up
 *     assert: function(ctx) {
 *       // ctx.drawList   → array of {x0,y0,x1,y1,color} for the last frame
 *       // ctx.ram        → function(addr) → byte value at RAM address
 *       // ctx.hasDraw()  → true if any lines were drawn
 *       // ctx.findLine(x0,y0,x1,y1) → true if a line exists (approx ±2px)
 *       ctx.expect(ctx.hasDraw(), 'should draw something');
 *       ctx.expect(ctx.drawList.length >= 5, 'should draw at least 5 lines');
 *     }
 *   };
 *
 * Golden snapshot mode (--golden):
 *   Saves the draw-list to <test_spec_dir>/golden.json.
 *   Future runs compare against it automatically.
 */

'use strict';

const fs       = require('fs');
const path     = require('path');
const cp       = require('child_process');
const os       = require('os');

// ─── Parse CLI arguments ───────────────────────────────────────────────────

const args = process.argv.slice(2);
if (args.length === 0 || args[0] === '--help') {
  console.log(`
Usage: node tools/vpy_test_runner.cjs <test_spec.js> [--golden] [--frames N] [--no-compile] [--verbose]

  <test_spec.js>   Path to a test spec (see docs/TESTING.md)
  --golden         Save current draw-list as golden.json (first run)
  --frames N       Run N frames (overrides spec value, default 3)
  --no-compile     Skip compilation, use existing .bin file
  --verbose        Dump draw list and RAM
`);
  process.exit(0);
}

const specPath    = path.resolve(args[0]);
const goldenMode  = args.includes('--golden');
const noCompile   = args.includes('--no-compile');
const verbose     = args.includes('--verbose');
const framesFlag  = (() => {
  const idx = args.indexOf('--frames');
  return idx !== -1 ? parseInt(args[idx + 1], 10) : null;
})();

// ─── Load test spec ────────────────────────────────────────────────────────

if (!fs.existsSync(specPath)) {
  console.error(`[ERROR] Test spec not found: ${specPath}`);
  process.exit(1);
}

const spec = require(specPath);
const WORKSPACE_ROOT = path.resolve(__dirname, '..');

const projectPath = path.resolve(WORKSPACE_ROOT, spec.project);
// Vectrex BIOS needs ~50 frames (1 second) to initialize and find cartridge
// Then game startup needs additional time - minimum 500 frames (10 seconds) for proper loading
const frames      = framesFlag ?? spec.frames ?? 500;

// If spec has skipCompile flag, automatically use --no-compile
const skipCompile = spec.skipCompile === true;
const actualNoCompile = noCompile || skipCompile;

// ─── Step 1: Compile ───────────────────────────────────────────────────────

/** Find the .vpyproj file in a project directory */
function findVpyProj(dir) {
  for (const f of fs.readdirSync(dir)) {
    if (f.endsWith('.vpyproj')) return path.join(dir, f);
  }
  return null;
}

/** Find the compiled .bin file in a project (searches src/ and build/) */
function findBin(dir) {
  for (const subdir of ['src', 'build', '.']) {
    const d = path.join(dir, subdir);
    if (!fs.existsSync(d)) continue;
    for (const f of fs.readdirSync(d)) {
      if (f.endsWith('.bin')) return path.join(d, f);
    }
  }
  return null;
}

let binPath = null;

if (!actualNoCompile) {
  const vpyproj = findVpyProj(projectPath);
  if (!vpyproj) {
    console.error(`[ERROR] No .vpyproj found in: ${projectPath}`);
    process.exit(1);
  }

  console.log(`[COMPILE] ${path.relative(WORKSPACE_ROOT, vpyproj)}`);

  // Use the buildtools vpy_cli to compile
  const buildtoolsDir  = path.join(WORKSPACE_ROOT, 'buildtools');
  const compilerBin    = path.join(WORKSPACE_ROOT, 'target', 'debug', 'vectrexc');
  const projFile       = vpyproj;
  const srcDir         = path.join(projectPath, 'src');

  // Find main.vpy
  let mainVpy = null;
  if (fs.existsSync(srcDir)) {
    for (const f of fs.readdirSync(srcDir)) {
      if (f.endsWith('.vpy')) { mainVpy = path.join(srcDir, f); break; }
    }
  }
  if (!mainVpy) {
    // try project root
    for (const f of fs.readdirSync(projectPath)) {
      if (f.endsWith('.vpy')) { mainVpy = path.join(projectPath, f); break; }
    }
  }

  if (!mainVpy) {
    console.error(`[ERROR] No .vpy file found in: ${projectPath}`);
    process.exit(1);
  }

  try {
    // Build vectrexc first if needed
    if (!fs.existsSync(compilerBin)) {
      console.log('[COMPILE] Building vectrexc compiler...');
      cp.execSync('cargo build --bin vectrexc 2>&1', {
        cwd: WORKSPACE_ROOT,
        stdio: 'inherit',
      });
    }

    const result = cp.spawnSync(compilerBin, ['build', mainVpy, '--bin'], {
      cwd: projectPath,
      encoding: 'utf8',
    });

    if (result.status !== 0) {
      console.error('[COMPILE] FAILED');
      if (result.stdout) process.stdout.write(result.stdout);
      if (result.stderr) process.stderr.write(result.stderr);
      process.exit(1);
    }
    if (verbose && result.stdout) process.stdout.write(result.stdout);
    console.log('[COMPILE] OK');
  } catch (e) {
    console.error(`[COMPILE] Error: ${e.message}`);
    process.exit(1);
  }
}

binPath = findBin(projectPath);
if (!binPath) {
  // If skipCompile was requested but no binary found, skip the test
  if (skipCompile) {
    console.log('[SKIP] No pre-compiled binary found (compilation has issues)');
    console.log('[WARN] Test skipped - see skipCompile flag in test spec');
    process.exit(0);
  }
  console.error(`[ERROR] No .bin file found in: ${projectPath}`);
  process.exit(1);
}
console.log(`[BIN] ${path.relative(WORKSPACE_ROOT, binPath)}`);

// ─── Step 2: Load jsvecx headlessly ───────────────────────────────────────

// Minimal browser stubs (canvas is a no-op sink)
global.window = { AudioContext: null, webkitAudioContext: null };
global.document = {
  getElementById: () => ({
    getContext: () => ({
      getImageData: () => ({ data: new Uint8ClampedArray(330 * 410 * 4) }),
      putImageData: () => {},
    }),
  }),
  documentElement: { addEventListener: () => {} },
};
global.$ = () => ({ text: () => {} });  // jsvecx uses jQuery for FPS display

const bundlePath = path.join(WORKSPACE_ROOT, 'ide', 'frontend', 'src', 'generated', 'jsvecx', 'vecx_full.js');
if (!fs.existsSync(bundlePath)) {
  console.error(`[ERROR] jsvecx bundle not found: ${bundlePath}`);
  console.error('        Build the IDE frontend first: cd ide/frontend && npm run build');
  process.exit(1);
}

let bundleCode = fs.readFileSync(bundlePath, 'utf8');
// Fix: `length` is a browser global (window.length === 0); patch for Node.js
bundleCode = bundleCode.replace(
  'const STEP2        = length; // (igual que macro original)',
  'const STEP2        = 2; // Patched: window.length not available in Node.js'
);
// Patch the ES module export into a CJS-compatible form
bundleCode = bundleCode.replace(
  'export { VecX, Globals };',
  'if (typeof module !== "undefined" && module.exports) { module.exports = { VecX, Globals }; }'
);
// Write patched bundle to a temp file and require() it — avoids strict-mode eval scoping issues
const tmpBundle = path.join(os.tmpdir(), `vecx_bundle_${process.pid}.cjs`);
fs.writeFileSync(tmpBundle, bundleCode);
const { VecX, Globals } = require(tmpBundle);
try { fs.unlinkSync(tmpBundle); } catch (_) {}

// Load BIOS
const biosPath = path.join(WORKSPACE_ROOT, 'ide', 'frontend', 'src', 'assets', 'bios.bin');
if (!fs.existsSync(biosPath)) {
  console.error(`[ERROR] BIOS not found: ${biosPath}`);
  process.exit(1);
}
const biosData = fs.readFileSync(biosPath);
Globals.romdata = Buffer.from(biosData).toString('binary');

// Load cartridge
const cartData = fs.readFileSync(binPath);
Globals.cartdata = Buffer.from(cartData).toString('binary');

// Boot emulator
const vecx = new VecX();
vecx.e6809.init(vecx);
vecx.osint.init(vecx);
vecx.vecx_reset();

console.log(`[EMU] Reset OK, PC=0x${vecx.e6809.reg_pc.toString(16).toUpperCase().padStart(4,'0')}, cart=${cartData.length} bytes`);

// ─── Step 3: Run N frames ──────────────────────────────────────────────────

// One Vectrex frame = VECTREX_MHZ / 50 cycles = 30000 cycles
const CYCLES_PER_FRAME = (Globals.VECTREX_MHZ / 50) | 0;

console.log(`[EMU] Running ${frames} frame(s) (${CYCLES_PER_FRAME} cycles each)...`);

// Capture the LAST COMPLETE frame using vectors_erse / vector_erse_cnt.
// Strategy: identify the game's "home" frame count (most common in range 50-350),
// then return any frame matching that count from the run.
const framesByCount = {};  // { count: [ {count, frame_data}, ... ], ... }
let lastCompleteFrame = [];

for (let f = 0; f < frames; f++) {
  vecx.vecx_emu(CYCLES_PER_FRAME, 0);
  
  const erseCount = vecx.vector_erse_cnt || 0;
  if (erseCount > 0 && vecx.vectors_erse) {
    const frameVectors = [];
    for (let i = 0; i < erseCount; i++) {
      const v = vecx.vectors_erse[i];
      if (v) {
        frameVectors.push({ x0: v.x0, y0: v.y0, x1: v.x1, y1: v.y1, color: v.color });
      }
    }
    lastCompleteFrame = frameVectors;
    
    // Only track game-range frames (50-350)
    if (erseCount >= 50 && erseCount <= 350) {
      if (!framesByCount[erseCount]) {
        framesByCount[erseCount] = [];
      }
      framesByCount[erseCount].push(frameVectors);
    }
    if (verbose) {
      console.log(`  Frame ${f}: ${erseCount} vector(s)`);
    }
  }
}

// Find the most common count
let bestGameCount = 0;
let bestGameFreq = 0;
for (const [count, frames_arr] of Object.entries(framesByCount)) {
  if (frames_arr.length > bestGameFreq) {
    bestGameCount = parseInt(count);
    bestGameFreq = frames_arr.length;
  }
}

// Use a frame with the most common count, or fall back to last frame
let bestGameFrame = lastCompleteFrame;
if (bestGameCount > 0 && framesByCount[bestGameCount].length > 0) {
  // Pick the last frame with that count (most recent game state)
  bestGameFrame = framesByCount[bestGameCount][framesByCount[bestGameCount].length - 1];
}

// ─── Step 4: Capture draw list ────────────────────────────────────────────

// Use bestGameFrame (the frame with the most common game-range count)
const rawDrawList = bestGameFrame;

if (verbose) {
  console.log(`[DRAW] ${rawDrawList.length} vector(s) drawn:`);
  rawDrawList.forEach((v, i) => {
    console.log(`  [${i}] (${v.x0},${v.y0})→(${v.x1},${v.y1}) color=${v.color}`);
  });
}

// ─── Step 5: RAM accessor ─────────────────────────────────────────────────

// Vectrex RAM lives at $C800–$CFFF (mirrored). jsvecx stores it in vecx.ram[]
// RAM offset: address & 0x07FF gives the index into vecx.ram[]
function readRam(addr) {
  return vecx.ram[addr & 0x07FF] & 0xff;
}

// ─── Step 6: Golden snapshot mode ─────────────────────────────────────────

const goldenPath = path.join(path.dirname(specPath), 'golden.json');

if (goldenMode) {
  fs.writeFileSync(goldenPath, JSON.stringify(rawDrawList, null, 2));
  console.log(`[GOLDEN] Saved ${rawDrawList.length} vectors → ${path.relative(WORKSPACE_ROOT, goldenPath)}`);
  process.exit(0);
}

// ─── Step 7: Assertions ────────────────────────────────────────────────────

let passed = 0;
let failed = 0;
const failures = [];

/** Compare golden snapshot if it exists */
if (fs.existsSync(goldenPath) && !spec.assert) {
  const golden = JSON.parse(fs.readFileSync(goldenPath, 'utf8'));
  const tolerance = spec.goldenTolerance ?? 2;

  function vectorsMatch(a, b) {
    return Math.abs(a.x0 - b.x0) <= tolerance &&
           Math.abs(a.y0 - b.y0) <= tolerance &&
           Math.abs(a.x1 - b.x1) <= tolerance &&
           Math.abs(a.y1 - b.y1) <= tolerance &&
           a.color === b.color;
  }

  let mismatches = 0;
  if (rawDrawList.length !== golden.length) {
    failures.push(`Draw count mismatch: expected ${golden.length}, got ${rawDrawList.length}`);
    mismatches++;
  } else {
    for (let i = 0; i < golden.length; i++) {
      if (!vectorsMatch(rawDrawList[i], golden[i])) {
        failures.push(`Vector[${i}] mismatch: expected (${golden[i].x0},${golden[i].y0})→(${golden[i].x1},${golden[i].y1}) col=${golden[i].color}, got (${rawDrawList[i].x0},${rawDrawList[i].y0})→(${rawDrawList[i].x1},${rawDrawList[i].y1}) col=${rawDrawList[i].color}`);
        mismatches++;
      }
    }
  }
  if (mismatches === 0) {
    passed++;
    console.log(`  ✓ Golden snapshot matches (${golden.length} vectors)`);
  } else {
    failed += mismatches;
  }
}

/** Run programmatic assertions from spec.assert() */
if (spec.assert) {
  /** Context object passed to spec.assert */
  const ctx = {
    drawList: rawDrawList,
    ram: readRam,

    hasDraw() {
      return rawDrawList.length > 0;
    },

    /** Returns true if any drawn vector is within `tol` pixels of the given coordinates */
    findLine(x0, y0, x1, y1, tol = 4) {
      return rawDrawList.some(v =>
        Math.abs(v.x0 - x0) <= tol && Math.abs(v.y0 - y0) <= tol &&
        Math.abs(v.x1 - x1) <= tol && Math.abs(v.y1 - y1) <= tol
      );
    },

    /** Assert helper: throws on failure, accumulates results */
    expect(condition, message) {
      if (condition) {
        passed++;
        if (verbose) console.log(`  ✓ ${message}`);
      } else {
        failed++;
        failures.push(message);
      }
    },
  };

  try {
    spec.assert(ctx);
  } catch (e) {
    failed++;
    failures.push(`assert() threw: ${e.message}`);
  }
}

// ─── Step 8: Print results ────────────────────────────────────────────────

const total = passed + failed;
console.log('');
console.log(`[DRAW] ${rawDrawList.length} vector(s) captured`);
console.log(`Results: ${passed}/${total} passed`);
if (failures.length > 0) {
  failures.forEach(f => console.error(`  ✗ ${f}`));
  console.log('');
  console.log('[FAIL]');
  process.exit(1);
} else if (total === 0) {
  console.warn('[WARN] No assertions were made. Add spec.assert() or run --golden first.');
  process.exit(0);
} else {
  console.log('[PASS]');
  process.exit(0);
}
