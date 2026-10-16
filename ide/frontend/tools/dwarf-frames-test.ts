/**
 * Tests for the ARM call stack: the ELF's call-frame information
 * (src/debug/dwarfFrames.ts) and the unwinder and names (src/debug/armCallStack.ts),
 * on a real uvm2 build (asm backend) of a two-module project.
 *
 *   node tools/dwarf-frames-test.ts            (node >= 22.18 strips the types)
 *
 * Needs the bundled vpy_cli and an installed SDK; skipped without them.
 */
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, mkdirSync, writeFileSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { frameTable } from '../src/debug/dwarfFrames.ts';
import { lineTable } from '../src/debug/dwarfLines.ts';
import { unwind, vpyName, prologueRow } from '../src/debug/armCallStack.ts';

let n = 0;
const t = (name: string, f: () => void) => { f(); n++; console.log(`  ok   ${name}`); };

t('a prologue without unwind data: push {r4, lr}; sub sp, #16 -> CFA sp+24, lr at CFA-4', () => {
  const code = new Map([[0x100, 0xb510], [0x102, 0xb084], [0x104, 0xf000], [0x106, 0xf800]]); // push {r4,lr}; sub sp,#16; bl
  const row = prologueRow(0x100, 0x108, (a) => code.get(a) ?? 0);
  assert.equal(row.cfaOffset, 24);
  assert.equal(row.saved.get(14), -4);
  assert.equal(row.saved.get(4), -8);
  // before the push: nothing saved, a leaf
  assert.equal(prologueRow(0x100, 0x100, (a) => code.get(a) ?? 0).cfaOffset, 0);
  // push.w {r4-r11, lr}
  const wide = new Map([[0x200, 0xe92d], [0x202, 0x4ff0]]);
  const w = prologueRow(0x200, 0x204, (a) => wide.get(a) ?? 0);
  assert.equal(w.cfaOffset, 36);
  assert.equal(w.saved.get(14), -4);
  assert.equal(w.saved.get(4), -36);
});

t('symbols become VPy names', () => {
  const mods = ['main', 'util', 'big_boss'];
  assert.equal(vpyName('UTIL_bump', mods), 'util.bump');
  assert.equal(vpyName('F_UTIL_BUMP', mods), 'util.bump');
  assert.equal(vpyName('F_BIG_BOSS_HIT_POINTS.isra.0', mods), 'big_boss.hit_points');
  assert.equal(vpyName('vpy_loop', mods), 'loop');
  assert.equal(vpyName('game_main_loop', mods), 'loop');
  assert.equal(vpyName('vpy_setup', mods), 'main');
  assert.equal(vpyName('uvm2_frame_end', mods), 'uvm2_frame_end');
  assert.equal(vpyName('F_HELPER', mods), 'helper');
  assert.equal(vpyName('_ZN12vectrex_draw4ramp15ramp_params_q_v17h29e0e37d5c0c9e7bE', mods), 'vectrex_draw::ramp::ramp_params_q_v');
});

const here = path.dirname(fileURLToPath(import.meta.url));
const vpyCli = process.env.VPY_CLI || path.resolve(here, '../../electron/resources/vpy_cli');
const sdkRoot = path.join(homedir(), 'VectrexStudio/sdk');
const sdk = existsSync(sdkRoot) ? readdirSync(sdkRoot).filter((v) => /^v\d/.test(v)).sort().pop() : undefined;
if (!existsSync(vpyCli) || !sdk) {
  console.log(`skip the build tests: needs ${vpyCli} and an SDK in ${sdkRoot}\n${n} passed`);
  process.exit(0);
}

const root = mkdtempSync(path.join(tmpdir(), 'dwarf-frames-'));
mkdirSync(path.join(root, 'src'));
writeFileSync(path.join(root, 'duo.vpyproj'), `[project]\nname = "duo"\nversion = "0.1.0"\nentry = "src/main.vpy"\n\n[build]\noutput = "build/duo.bin"\n\n[sdk]\nversion = "${sdk}"\n`);
writeFileSync(path.join(root, 'src/main.vpy'), 'import util\n\ncount = 0\n\ndef main():\n    SET_INTENSITY(80)\n\ndef loop():\n    count = util.bump(count)\n');
writeFileSync(path.join(root, 'src/util.vpy'), '# util\n\ndef bump(v):\n    w = v + 1\n    return w\n');
execFileSync(vpyCli, ['build', path.join(root, 'duo.vpyproj'), '--target', 'uvm2'], { stdio: 'pipe' });
const elf = new Uint8Array(readFileSync(path.join(root, 'build/duo.elf')));
rmSync(root, { recursive: true, force: true });
const frames = frameTable(elf);
const lines = lineTable(elf);
const bump = lines.functionAt([...lines.functionStarts].find((a) => lines.functionAt(a)?.name === 'UTIL_bump')!)!;
const util = [...lines.files].find((f) => f.endsWith('/util.vpy'))!;
const body = lines.starts.get(`${util}:4`)![0];

t('the asm backend\'s frame: CFA at sp on entry, then r7 + frame + 20 with lr at CFA-4', () => {
  assert.ok(frames.fdes > 10);
  const entry = frames.rowAt(bump.start)!;
  assert.equal(entry.cfaReg, 13);
  assert.equal(entry.cfaOffset, 0);
  const inBody = frames.rowAt(body)!;
  assert.equal(inBody.cfaReg, 7);
  assert.equal(inBody.saved.get(14), -4);
  assert.equal(inBody.saved.get(7), -8);
});

t('unwinding util.bump: back into loop (main.vpy:9) through the saved lr', () => {
  // A frame as the prologue leaves it: r7 = sp, CFA = r7 + frame + 20; lr saved at CFA-4
  const row = frames.rowAt(body)!;
  const r7 = 0x20081f00;
  const cfa = r7 + row.cfaOffset;
  const callSite = lines.starts.get(`${[...lines.files].find((f) => f.endsWith('/main.vpy'))}:9`)![0];
  const ret = (callSite + 8) | 1; // somewhere after the call in loop's line 9
  const mem = new Map<number, number>([[cfa - 4, ret], [cfa - 8, 0x20081f80]]);
  const regs = Array(16).fill(0);
  regs[7] = r7; regs[13] = r7; regs[15] = body;
  const stack = unwind(regs, frames, lines, (a) => mem.get(a) ?? 0, (pc) => lines.lineAt(pc));
  assert.deepEqual(stack.slice(0, 2).map((f) => [f.function, f.file, f.line, f.type]), [
    ['util.bump', 'util.vpy', 4, 'vpy'],
    ['loop', 'main.vpy', 9, 'vpy'],
  ]);
});

console.log(`${n} passed`);
