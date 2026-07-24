// Headless runner for the RP2350 Thumb2 emulator — runs a real RAM-linked
// `_sd.bin` (VPy or AAE C game) in node, no DOM. Used to debug HW-vs-sim
// divergences on the actual ARM binary (the WASM/emscripten sim is a different
// build and diverges; this runs the exact bytes that ship to hardware).
//
// Build the bundle first (re-run whenever the emulator TS changes):
//   cd ide/frontend
//   ./node_modules/.bin/esbuild src/emulator/systems/Rp2350System.ts \
//       --bundle --format=esm --platform=node --outfile=tools/.rp2350emu-built.mjs
//
// Then:
//   node tools/emu-harness.mjs <game_sd.bin> [frames] [mode]
//     mode = run (default) | svc | pc | jumps
//
// KEY: use initRamGame(bin) (RAM-linked svc games), NOT init() (flash/XIP).
//
// Known fidelity gap (2026-07): 6502 games (asteroids) run faithfully, but the
// ccpu Cinematronics games (starcas/ripoff/solarq) don't draw / freeze in the
// emulator even though they work on HW → a Thumb2 miscompute in the ccpu path.

import { Rp2350System } from './.rp2350emu-built.mjs';
import fs from 'node:fs';

const path = process.argv[2];
const frames = parseInt(process.argv[3] || '200', 10);
const mode = process.argv[4] || 'run';
if (!path) { console.error('usage: node emu-harness.mjs <game_sd.bin> [frames] [run|svc|pc|jumps]'); process.exit(2); }

const bin = new Uint8Array(fs.readFileSync(path));
const sys = new Rp2350System();
const _log = console.log; console.log = () => {};      // silence init chatter
sys.initRamGame(bin);
console.log = _log;

if (mode === 'svc') {
  const counts = {}; const orig = sys.onSvc.bind(sys);
  sys.onSvc = (imm, cpu) => { counts[imm] = (counts[imm] || 0) + 1; return orig(imm, cpu); };
  let err = null;
  try { for (let f = 0; f < frames; f++) sys.runFrame(); } catch (e) { err = e; }
  console.log('svc counts:', JSON.stringify(counts) + (err ? `  ERR ${err.message}` : ''));
} else if (mode === 'pc' || mode === 'jumps') {
  const cpu = sys.cpu; let prev = -1, steps = 0; const jumps = [], ring = [];
  const orig = cpu.step.bind(cpu);
  cpu.step = (bus) => {
    const pc = cpu.pc >>> 0;
    if (prev >= 0 && Math.abs(pc - prev) > 4) jumps.push([prev, pc]);
    ring.push(pc); if (ring.length > 64) ring.shift();
    prev = pc; steps++;
    return orig(bus);
  };
  let err = null;
  try { for (let f = 0; f < frames; f++) sys.runFrame(); } catch (e) { err = e; }
  console.log(`steps=${steps}`);
  if (mode === 'pc') console.log('last PCs:', ring.map(p => '0x' + p.toString(16)).join(' '));
  else console.log('last jumps:', jumps.slice(-24).map(([a, b]) => `0x${a.toString(16)}->0x${b.toString(16)}`).join('  '));
  if (err) console.log('CRASH:', err.message);
} else {
  let total = 0, withDraw = 0, err = null; const seen = new Set();
  try {
    for (let f = 0; f < frames; f++) {
      const segs = sys.runFrame();
      total += segs.length; if (segs.length) withDraw++;
      seen.add(segs.map(s => `${s.x0|0},${s.y0|0},${s.x1|0},${s.y1|0}`).join(';'));
    }
  } catch (e) { err = e; }
  console.log(`frames=${frames} totalSegs=${total} avg=${(total/Math.max(1,frames)).toFixed(0)}/f `
    + `framesWithDraw=${withDraw} distinctFrames=${seen.size}` + (err ? `  ERROR: ${err.message}` : ''));
}
