#!/usr/bin/env node
/**
 * vpy_test_runner_multi.cjs
 * ─────────────────────────────────────────────────────────────
 * Multi-backend VPy test runner — 6809, PiTrex, RP2350
 *
 * Usage:
 *   node tools/vpy_test_runner_multi.cjs <test_spec.js> [--all] [--backends 6809,pitrex,rp2350]
 *   node tools/vpy_test_runner_multi.cjs examples/individual_tests/draw_line/test.vpy.js --all
 *
 * Options:
 *   --all              Run all backends (default: 6809 only)
 *   --backends LIST    Comma-separated list: 6809,pitrex,rp2350
 *   --no-compile       Skip compilation, use existing .bin/.s/.elf files
 *   --golden           Save golden snapshots for all backends
 *   --verbose          Print detailed output
 *   --compare          Show differences between backends (implies --all)
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
Usage: node tools/vpy_test_runner_multi.cjs <test_spec.js> [options]

Options:
  --all              Run all backends (6809, pitrex, rp2350)
  --backends LIST    Run specific backends (e.g., --backends 6809,pitrex)
  --no-compile       Skip compilation, use existing outputs
  --golden           Save golden snapshots
  --verbose          Detailed output
  --compare          Compare all backends (implies --all)
`);
  process.exit(0);
}

const specPath    = path.resolve(args[0]);
const goldenMode  = args.includes('--golden');
const noCompile   = args.includes('--no-compile');
const verbose     = args.includes('--verbose');
const compareMode = args.includes('--compare');

let backends = ['6809'];  // default
if (args.includes('--all')) {
  backends = ['6809', 'pitrex', 'rp2350'];
} else if (args.includes('--compare')) {
  backends = ['6809', 'pitrex', 'rp2350'];
} else {
  const backendFlag = args.findIndex(a => a === '--backends');
  if (backendFlag !== -1) {
    backends = args[backendFlag + 1].split(',').map(b => b.trim());
  }
}

if (!fs.existsSync(specPath)) {
  console.error(`[ERROR] Test spec not found: ${specPath}`);
  process.exit(1);
}

const spec = require(specPath);
const WORKSPACE_ROOT = path.resolve(__dirname, '..');
const projectPath = path.resolve(WORKSPACE_ROOT, spec.project);
const frames = spec.frames ?? 3;

console.log(`[TEST] ${path.relative(WORKSPACE_ROOT, specPath)}`);
console.log(`[BACKENDS] ${backends.join(', ')}`);
console.log('');

// ─── Step 1: Compile to all requested backends ──────────────────────────

if (!noCompile) {
  console.log(`[COMPILE] Finding .vpy file...`);
  
  let mainVpy = null;
  const srcDir = path.join(projectPath, 'src');
  if (fs.existsSync(srcDir)) {
    for (const f of fs.readdirSync(srcDir)) {
      if (f.endsWith('.vpy')) { mainVpy = path.join(srcDir, f); break; }
    }
  }
  if (!mainVpy) {
    for (const f of fs.readdirSync(projectPath)) {
      if (f.endsWith('.vpy')) { mainVpy = path.join(projectPath, f); break; }
    }
  }
  
  if (!mainVpy) {
    console.error(`[ERROR] No .vpy file found in: ${projectPath}`);
    process.exit(1);
  }

  const compilerBin = path.join(WORKSPACE_ROOT, 'target', 'debug', 'vectrexc');
  if (!fs.existsSync(compilerBin)) {
    console.log('[COMPILE] Building vectrexc compiler...');
    cp.execSync('cargo build --bin vectrexc 2>&1', {
      cwd: WORKSPACE_ROOT,
      stdio: 'inherit',
    });
  }

  for (const backend of backends) {
    console.log(`[COMPILE] Compiling for ${backend}...`);
    const result = cp.spawnSync(compilerBin, ['build', mainVpy, '--target', backend, '--debug'], {
      cwd: projectPath,
      encoding: 'utf8',
    });

    if (result.status !== 0) {
      console.error(`[COMPILE] FAILED for ${backend}`);
      if (result.stdout) process.stdout.write(result.stdout);
      if (result.stderr) process.stderr.write(result.stderr);
      process.exit(1);
    }
    if (verbose && result.stdout) process.stdout.write(result.stdout);
  }
  console.log(`[COMPILE] OK for all backends\n`);
}

// ─── Step 2: Load and execute each backend ──────────────────────────────

const results = {};

// Load jsvecx for 6809
if (backends.includes('6809')) {
  console.log(`[6809] Initializing emulator...`);
  
  // Minimal browser stubs
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
  global.$ = () => ({ text: () => {} });

  const bundlePath = path.join(WORKSPACE_ROOT, 'ide', 'frontend', 'src', 'generated', 'jsvecx', 'vecx_full.js');
  let bundleCode = fs.readFileSync(bundlePath, 'utf8');
  bundleCode = bundleCode.replace(
    'const STEP2        = length;',
    'const STEP2        = 2;'
  );
  bundleCode = bundleCode.replace(
    'export { VecX, Globals };',
    'if (typeof module !== "undefined" && module.exports) { module.exports = { VecX, Globals }; }'
  );

  const tmpBundle = path.join(os.tmpdir(), `vecx_${process.pid}.cjs`);
  fs.writeFileSync(tmpBundle, bundleCode);
  const { VecX, Globals } = require(tmpBundle);
  try { fs.unlinkSync(tmpBundle); } catch (_) {}

  const biosPath = path.join(WORKSPACE_ROOT, 'ide', 'frontend', 'src', 'assets', 'bios.bin');
  const biosData = fs.readFileSync(biosPath);
  Globals.romdata = Buffer.from(biosData).toString('binary');

  const binPath = path.join(projectPath, 'src', 'main.bin');
  if (!fs.existsSync(binPath)) {
    console.error(`[ERROR] 6809 binary not found: ${binPath}`);
    process.exit(1);
  }
  const cartData = fs.readFileSync(binPath);
  Globals.cartdata = Buffer.from(cartData).toString('binary');

  const vecx = new VecX();
  vecx.e6809.init(vecx);
  vecx.osint.init(vecx);
  vecx.vecx_reset();

  const CYCLES_PER_FRAME = (Globals.VECTREX_MHZ / 50) | 0;
  console.log(`[6809] Running ${frames} frame(s)...`);
  
  for (let f = 0; f < frames; f++) {
    vecx.vecx_emu(CYCLES_PER_FRAME, 0);
  }

  const drawList = [];
  for (let i = 0; i < vecx.vector_draw_cnt; i++) {
    const v = vecx.vectors_draw[i];
    if (v) {
      drawList.push({ x0: v.x0, y0: v.y0, x1: v.x1, y1: v.y1, color: v.color });
    }
  }

  results['6809'] = {
    drawList,
    format: 'drawList',
    count: drawList.length,
  };
  console.log(`[6809] ✓ Captured ${drawList.length} vectors\n`);
}

// Load PiTrex for pitrex
if (backends.includes('pitrex')) {
  const pitrexBundlePath = path.join(__dirname, 'emulators', 'pitrex.cjs');
  
  if (!fs.existsSync(pitrexBundlePath)) {
    console.log(`[pitrex] Bundle not found. Building emulator bundles...`);
    const buildScript = path.join(__dirname, 'build_emulator_bundles.js');
    try {
      cp.execSync(`node "${buildScript}"`, { stdio: 'inherit' });
    } catch (e) {
      console.error(`[pitrex] Failed to build bundle. Skipping.`);
      results['pitrex'] = { error: 'build_failed' };
    }
  }
  
  if (fs.existsSync(pitrexBundlePath)) {
    try {
      console.log(`[pitrex] Initializing emulator...`);
      const { PitrexCore } = require(pitrexBundlePath);
      
      const sPath = path.join(projectPath, 'src', 'main.s');
      if (!fs.existsSync(sPath)) {
        console.error(`[pitrex] Assembly file not found: ${sPath}`);
        results['pitrex'] = { error: 'no_asm_file' };
      } else {
        const sFileText = fs.readFileSync(sPath, 'utf8');
        const core = new PitrexCore();
        core.loadAssembly(sFileText);
        
        console.log(`[pitrex] Running ${frames} frame(s)...`);
        
        let segments = [];
        for (let f = 0; f < frames; f++) {
          const frameResult = core.runFrame();
          segments = frameResult.segments;
        }
        
        results['pitrex'] = {
          segments,
          format: 'segments',
          count: segments.length,
        };
        console.log(`[pitrex] ✓ Captured ${segments.length} segments\n`);
      }
    } catch (e) {
      console.error(`[pitrex] Error: ${e.message}\n`);
      results['pitrex'] = { error: 'runtime_error', detail: e.message };
    }
  } else {
    results['pitrex'] = { error: 'bundle_not_found' };
  }
}

// Load RP2350 for rp2350
if (backends.includes('rp2350')) {
  const rp2350BundlePath = path.join(__dirname, 'emulators', 'rp2350.cjs');
  
  if (!fs.existsSync(rp2350BundlePath)) {
    console.log(`[rp2350] Bundle not found. Building emulator bundles...`);
    const buildScript = path.join(__dirname, 'build_emulator_bundles.js');
    try {
      cp.execSync(`node "${buildScript}"`, { stdio: 'inherit' });
    } catch (e) {
      console.error(`[rp2350] Failed to build bundle. Skipping.`);
      results['rp2350'] = { error: 'build_failed' };
    }
  }
  
  if (fs.existsSync(rp2350BundlePath)) {
    try {
      console.log(`[rp2350] Initializing emulator...`);
      const { Rp2350System } = require(rp2350BundlePath);
      
      const binPath = path.join(projectPath, 'src', 'main.bin');
      if (!fs.existsSync(binPath)) {
        console.error(`[rp2350] Binary file not found: ${binPath}`);
        results['rp2350'] = { error: 'no_bin_file' };
      } else {
        const binData = fs.readFileSync(binPath);
        const system = new Rp2350System();
        system.init(binData, null);  // bin, elf (optional)
        
        console.log(`[rp2350] Running ${frames} frame(s)...`);
        
        let segments = [];
        for (let f = 0; f < frames; f++) {
          const frameResult = system.runFrame();
          segments = frameResult.segments;
        }
        
        results['rp2350'] = {
          segments,
          format: 'segments',
          count: segments.length,
        };
        console.log(`[rp2350] ✓ Captured ${segments.length} segments\n`);
      }
    } catch (e) {
      console.error(`[rp2350] Error: ${e.message}\n`);
      results['rp2350'] = { error: 'runtime_error', detail: e.message };
    }
  } else {
    results['rp2350'] = { error: 'bundle_not_found' };
  }
}

// ─── Step 3: Compare results ────────────────────────────────────────────

if (compareMode && backends.length > 1) {
  console.log(`[COMPARE] Analyzing ${backends.length} backends...\n`);
  
  // Normalize all results to a common format (array of {x0, y0, x1, y1, color})
  const normalized = {};
  for (const backend of backends) {
    const result = results[backend];
    if (!result) continue;
    
    if (result.drawList) {
      normalized[backend] = result.drawList;
    } else if (result.segments) {
      normalized[backend] = result.segments;  // segments have same shape as drawList
    } else {
      normalized[backend] = [];
    }
  }
  
  const ref = normalized[backends[0]];
  let allMatch = true;
  
  for (let i = 1; i < backends.length; i++) {
    const backend = backends[i];
    const curr = normalized[backend];
    
    if (!ref || !curr) {
      console.log(`[COMPARE] ${backends[0]} vs ${backend}: skipped (missing data)\n`);
      continue;
    }
    
    if (ref.length !== curr.length) {
      console.log(`[COMPARE] ✗ ${backends[0]} vs ${backend}: count mismatch (${ref.length} vs ${curr.length})\n`);
      allMatch = false;
      continue;
    }
    
    const tolerance = 2;
    let mismatches = 0;
    for (let j = 0; j < ref.length; j++) {
      const r = ref[j];
      const c = curr[j];
      if (Math.abs(r.x0 - c.x0) > tolerance ||
          Math.abs(r.y0 - c.y0) > tolerance ||
          Math.abs(r.x1 - c.x1) > tolerance ||
          Math.abs(r.y1 - c.y1) > tolerance ||
          r.color !== c.color) {
        mismatches++;
      }
    }
    
    if (mismatches === 0) {
      console.log(`[COMPARE] ✓ ${backends[0]} vs ${backend}: all ${ref.length} lines match\n`);
    } else {
      console.log(`[COMPARE] ✗ ${backends[0]} vs ${backend}: ${mismatches}/${ref.length} lines differ\n`);
      allMatch = false;
    }
  }
  
  if (allMatch) {
    console.log('[COMPARE] ✓ All backends produce identical output\n');
  } else {
    console.log('[COMPARE] ✗ Backends differ\n');
  }
}

// ─── Step 4: Save golden or run assertions ──────────────────────────────

if (goldenMode) {
  for (const backend of backends) {
    const result = results[backend];
    if (!result.drawList) continue;
    
    const goldenPath = path.join(path.dirname(specPath), `golden_${backend}.json`);
    fs.writeFileSync(goldenPath, JSON.stringify(result.drawList, null, 2));
    console.log(`[GOLDEN] Saved ${result.drawList.length} vectors → ${path.relative(WORKSPACE_ROOT, goldenPath)}`);
  }
} else if (spec.assert) {
  console.log(`[ASSERT] Running spec.assert()...\n`);
  
  let passed = 0;
  let failed = 0;
  const failures = [];

  // Get drawList/segments from the first successful backend
  let drawList = [];
  for (const backend of backends) {
    const result = results[backend];
    if (result?.drawList) {
      drawList = result.drawList;
      break;
    } else if (result?.segments) {
      drawList = result.segments;
      break;
    }
  }

  const ctx = {
    drawList,
    ram: () => 0,
    hasDraw: function() { return this.drawList.length > 0; },
    findLine: function(x0, y0, x1, y1, tol = 4) {
      return this.drawList.some(v =>
        Math.abs(v.x0 - x0) <= tol && Math.abs(v.y0 - y0) <= tol &&
        Math.abs(v.x1 - x1) <= tol && Math.abs(v.y1 - y1) <= tol
      );
    },
    expect: function(condition, message) {
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

  const total = passed + failed;
  console.log(`Results: ${passed}/${total} passed`);
  if (failures.length > 0) {
    failures.forEach(f => console.error(`  ✗ ${f}`));
    console.log('\n[FAIL]');
    process.exit(1);
  } else {
    console.log('[PASS]');
    process.exit(0);
  }
}

console.log('[DONE]');
