/**
 * Tests for the debugger's source <-> address lookups (src/debug/pdbSource.ts),
 * on PDBs the bundled compiler writes for a two-module m6809 project whose line
 * numbers overlap (main.vpy and util.vpy both have code on line 10).
 *
 *   node tools/pdb-source-test.ts            (node >= 22.18 strips the types)
 *
 * Set VPY_CLI to point elsewhere; without a vpy_cli the test is skipped.
 */
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync, readdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as P from '../src/debug/pdbSource.ts';

const here = path.dirname(fileURLToPath(import.meta.url));
const vpyCli = process.env.VPY_CLI || path.resolve(here, '../../electron/resources/vpy_cli');
if (!existsSync(vpyCli)) {
  console.log(`skip: no vpy_cli at ${vpyCli}`);
  process.exit(0);
}

const root = mkdtempSync(path.join(tmpdir(), 'pdb-source-'));
mkdirSync(path.join(root, 'src'));
writeFileSync(path.join(root, 'duo.vpyproj'), `[project]
name = "duo"
version = "0.1.0"
entry = "src/main.vpy"

[build]
output = "build/duo.bin"
debug_symbols = true
`);
const MAIN = `import util

count = 0

def main():
    SET_INTENSITY(80)

def loop():
    # count up, then show it
    count = util.bump(count)
    util.show(count)
`;
const UTIL = `# a second module: its line numbers overlap main.vpy's

def bump(v):
    w = v + 1
    if w > 100:
        w = 0
    return w

def show(v):
    PRINT_NUMBER(0, 0, v)
`;
writeFileSync(path.join(root, 'src/main.vpy'), MAIN);
writeFileSync(path.join(root, 'src/util.vpy'), UTIL);
execFileSync(vpyCli, ['build', path.join(root, 'duo.vpyproj'), '--target', 'm6809', '--debug'], { stdio: 'pipe' });
const find = (dir: string): string | null => {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) { const f = find(p); if (f) return f; } else if (e.name.endsWith('.pdb')) return p;
  }
  return null;
};
const pdbPath = find(root);
assert.ok(pdbPath, 'the build wrote a .pdb');
const pdb: P.PdbLines = JSON.parse(readFileSync(pdbPath!, 'utf-8'));
const bin = readFileSync(pdbPath!.replace(/\.pdb$/, '.bin'));

let n = 0;
const t = (name: string, f: () => void) => { f(); n++; console.log(`  ok   ${name}`); };

t('each file has its own lines; line 10 is two different places', () => {
  const m = P.fileLines(pdb, 'main.vpy'), u = P.fileLines(pdb, 'util.vpy');
  assert.ok(m.has(10) && u.has(10));
  assert.notEqual(m.get(10), u.get(10));
  assert.equal(P.breakpointAddress(pdb, 'file:///x/src/util.vpy', 10), u.get(10));
  assert.equal(P.breakpointAddress(pdb, 'file:///x/src/main.vpy', 10), m.get(10));
});

t('util.vpy:10 is PRINT_NUMBER (its code loads 0, 0, v)', () => {
  const a = P.breakpointAddress(pdb, 'util.vpy', 10)!;
  assert.ok(a > 0 && a < bin.length);
  assert.deepEqual(P.sourceAt(pdb, a), { file: 'util.vpy', line: 10 });
});

t('the way back: every statement address names its own file and line', () => {
  for (const file of ['main.vpy', 'util.vpy']) {
    for (const [line, addr] of P.fileLines(pdb, file)) assert.deepEqual(P.sourceAt(pdb, addr), { file, line }, `${file}:${line}`);
  }
  assert.equal(P.sourceAt(pdb, 0xF000), null);
});

t('a comment or def line stops at the next statement of its function', () => {
  // main.vpy:9 is a comment inside loop(): the first statement after it is line 10
  assert.equal(P.breakpointAddress(pdb, 'main.vpy', 9), P.fileLines(pdb, 'main.vpy').get(10));
  // util.vpy:3 is `def bump(v):`, its first statement line 4
  assert.equal(P.breakpointAddress(pdb, 'util.vpy', 3), P.fileLines(pdb, 'util.vpy').get(4));
});

t('breakpoints across files all reach the emulator, unknown files are ignored', () => {
  const all = P.breakpointAddresses(pdb, {
    'file:///p/src/main.vpy': new Set([10]),
    'file:///p/src/util.vpy': new Set([5, 10]),
    'file:///p/assets/vectors/ship.vec': new Set([3]),
  });
  assert.equal(all.size, 3);
  assert.ok(all.has(P.fileLines(pdb, 'util.vpy').get(5)!));
});

t('an older PDB with only lineMap still serves the entry file', () => {
  const old: P.PdbLines = { source: 'main.vpy', lineMap: pdb.lineMap };
  assert.equal(P.breakpointAddress(old, 'main.vpy', 10), P.fileLines(pdb, 'main.vpy').get(10));
  assert.equal(P.breakpointAddress(old, 'util.vpy', 5), null);
});

rmSync(root, { recursive: true, force: true });
console.log(`${n} passed`);
