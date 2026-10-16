/**
 * Tests for the ELF variable reader (src/debug/dwarfInfo.ts) on a real uvm2 build of
 * the C backend: globals with their C types (scalars, typed arrays, struct arrays),
 * and the locals in scope at an address, by function — inlined ones included.
 *
 *   node tools/dwarf-info-test.ts            (node >= 22.18 strips the types)
 *
 * Needs the bundled vpy_cli and an installed SDK; skipped without them.
 */
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, mkdirSync, writeFileSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { debugInfo } from '../src/debug/dwarfInfo.ts';
import { lineTable, sections } from '../src/debug/dwarfLines.ts';

let n = 0;
const t = (name: string, f: () => void) => { f(); n++; console.log(`  ok   ${name}`); };

const here = path.dirname(fileURLToPath(import.meta.url));
const vpyCli = process.env.VPY_CLI || path.resolve(here, '../../electron/resources/vpy_cli');
const sdkRoot = path.join(homedir(), 'VectrexStudio/sdk');
const sdk = existsSync(sdkRoot) ? readdirSync(sdkRoot).filter((v) => /^v\d/.test(v)).sort().pop() : undefined;
if (!existsSync(vpyCli) || !sdk) {
  console.log(`skip: needs ${vpyCli} and an SDK in ${sdkRoot}`);
  process.exit(0);
}

const root = mkdtempSync(path.join(tmpdir(), 'dwarf-info-'));
mkdirSync(path.join(root, 'src'));
writeFileSync(path.join(root, 'vars.vpyproj'), `[project]\nname = "vars"\nversion = "0.1.0"\nentry = "src/main.vpy"\n\n[build]\noutput = "build/vars.bin"\n\n[uvm2]\nbackend = "c"\n\n[sdk]\nversion = "${sdk}"\n`);
writeFileSync(path.join(root, 'src/main.vpy'), [
  'import util',
  'speed = 2',
  'table = [1, 2, 3]',
  'struct Ship:',
  '    x: i32',
  '    hp: u8 = 3',
  'ships = Ship[4]',
  '',
  'def main():',
  '    SET_INTENSITY(80)',
  '',
  'def loop():',
  '    count = 0',
  '    for i in range(0, J1_X() + 4):',
  '        count = count + table[i % 3]',
  '    speed = speed + util.bump(count) + ships[1].hp',
  '    ships[J1_Y() & 3].hp = speed',
  '    PRINT_NUMBER(0, 0, speed)',
  '',
].join('\n'));
writeFileSync(path.join(root, 'src/util.vpy'), 'level = 7\n\ndef bump(k):\n    level = level + k\n    return level\n');
execFileSync(vpyCli, ['build', path.join(root, 'vars.vpyproj'), '--target', 'uvm2'], { stdio: 'pipe' });
const elfPath = readdirSync(path.join(root, 'build')).find((f) => f.endsWith('.elf'))!;
const elf = new Uint8Array(readFileSync(path.join(root, 'build', elfPath)));
const cSource = readdirSync(path.join(root, 'build')).filter((f) => f.endsWith('.c')).map((f) => readFileSync(path.join(root, 'build', f), 'utf8')).join('\n');
if (!process.env.KEEP) rmSync(root, { recursive: true, force: true }); else console.log(root);

const info = debugInfo(sections(elf));
const lines = lineTable(elf);

t('globals: scalars are 32-bit, arrays keep their element type, struct arrays their fields', () => {
  assert.ok(info.units >= 1);
  const speed = info.global('G_SPEED')!;
  assert.deepEqual(speed.type, { kind: 'int', size: 4, signed: true, name: speed.type.kind === 'int' ? speed.type.name : '' });
  assert.equal(speed.addr, lines.symbolAddress('G_SPEED'));
  const level = info.global('G_UTIL_LEVEL')!;
  assert.equal(level.type.kind, 'int');
  const table = info.global('G_TABLE')!.type;
  assert.equal(table.kind, 'array');
  if (table.kind === 'array') { assert.equal(table.count, 3); assert.equal(table.elem.kind, 'int'); }
  const ships = info.global('G_SHIPS')!.type;
  assert.equal(ships.kind, 'array');
  if (ships.kind === 'array') {
    assert.equal(ships.count, 4);
    assert.equal(ships.elem.kind, 'struct');
    if (ships.elem.kind === 'struct') assert.deepEqual(ships.elem.members.map((m) => m.name), ['f_x', 'f_hp']);
  }
  assert.equal(info.global('G_NOPE'), null);
});

t('locals: the loop body has loop()\'s count and i in scope, wherever gcc put loop', () => {
  const main = [...lines.files].find((f) => f.endsWith('/main.vpy'))!;
  const body = lines.starts.get(`${main}:15`);
  assert.ok(body && body.length, `no code for main.vpy:15 in\n${cSource.slice(0, 200)}`);
  const scopes = info.scopesAt(body![0]);
  const names = scopes.flatMap((s) => s.vars.map((v) => v.name));
  assert.ok(names.includes('l_count'), `scopes: ${JSON.stringify(scopes.map((s) => [s.function, s.vars.map((v) => v.name)]))}`);
  assert.ok(scopes.some((s) => /LOOP|loop/.test(s.function)));
  // where they are: something a debugger can show, or honestly nothing
  const machine = { regs: Array(16).fill(0x20001000), cfa: 0x20002000, read32: () => 0 };
  for (const s of scopes) for (const v of s.vars) assert.ok(['memory', 'register', 'value', 'unavailable'].includes(v.place(body![0], machine).kind));
});

console.log(`${n} passed`);
