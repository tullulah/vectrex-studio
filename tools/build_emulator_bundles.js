#!/usr/bin/env node
/**
 * build_emulator_bundles.js
 * ─────────────────────────────────────────────────────────────
 * Bundles PitrexCore and Rp2350System as CommonJS modules for Node.js
 * 
 * Usage: node tools/build_emulator_bundles.js
 */

'use strict';

const fs = require('fs');
const path = require('path');
const cp = require('child_process');

const WORKSPACE = path.resolve(__dirname, '..');
const FRONTEND_SRC = path.join(WORKSPACE, 'ide', 'frontend', 'src');
const OUTPUT_DIR = path.join(__dirname, 'emulators');

// Ensure output directory exists
if (!fs.existsSync(OUTPUT_DIR)) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

console.log('[BUILD] Emulator bundles for Node.js\n');

// Check if esbuild is available
const esbuildPath = path.join(WORKSPACE, 'node_modules', '.bin', 'esbuild');
if (!fs.existsSync(esbuildPath)) {
  console.error('[ERROR] esbuild not found. Install dependencies first:');
  console.error('  npm install');
  process.exit(1);
}

// Build 1: PitrexCore bundle
console.log('[BUILD] pitrex.cjs...');
const pitrexEntry = path.join(FRONTEND_SRC, 'pitrex', 'PitrexCore.ts');
const pitrexOut = path.join(OUTPUT_DIR, 'pitrex.cjs');

const pitrexCmd = [
  esbuildPath,
  pitrexEntry,
  '--bundle',
  '--platform=node',
  '--format=cjs',
  '--outfile=' + pitrexOut,
  '--external:ws',  // WebSocket not needed in Node.js
  '--external:audio-worklet',
];

try {
  cp.execSync(pitrexCmd.join(' '), { 
    stdio: 'inherit',
    cwd: WORKSPACE 
  });
  console.log(`[OK] ${path.relative(WORKSPACE, pitrexOut)}\n`);
} catch (e) {
  console.error(`[ERROR] Failed to bundle pitrex: ${e.message}\n`);
  process.exit(1);
}

// Build 2: Rp2350System bundle
console.log('[BUILD] rp2350.cjs...');
const rp2350Entry = path.join(FRONTEND_SRC, 'emulator', 'systems', 'Rp2350System.ts');
const rp2350Out = path.join(OUTPUT_DIR, 'rp2350.cjs');

const rp2350Cmd = [
  esbuildPath,
  rp2350Entry,
  '--bundle',
  '--platform=node',
  '--format=cjs',
  '--outfile=' + rp2350Out,
  '--external:ws',
];

try {
  cp.execSync(rp2350Cmd.join(' '), { 
    stdio: 'inherit',
    cwd: WORKSPACE 
  });
  console.log(`[OK] ${path.relative(WORKSPACE, rp2350Out)}\n`);
} catch (e) {
  console.error(`[ERROR] Failed to bundle rp2350: ${e.message}\n`);
  process.exit(1);
}

console.log('[DONE] Emulator bundles ready for Node.js');
console.log(`      ${path.relative(WORKSPACE, pitrexOut)}`);
console.log(`      ${path.relative(WORKSPACE, rp2350Out)}`);
