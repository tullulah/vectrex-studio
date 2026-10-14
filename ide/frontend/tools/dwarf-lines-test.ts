/**
 * Tests for the ELF line-table reader (src/debug/dwarfLines.ts) on a real uvm2 build of a
 * two-module project (main.vpy and util.vpy, line numbers overlapping), both backends.
 *
 *   node tools/dwarf-lines-test.ts            (node >= 22.18 strips the types)
 *
 * Needs the bundled vpy_cli and an installed SDK (~/VectrexStudio/sdk/<version>);
 * without them the test is skipped. Set VPY_CLI / VPY_SDK to point elsewhere.
 */
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, mkdirSync, writeFileSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { lineTable, parseLineRows } from '../src/debug/dwarfLines.ts';

const here = path.dirname(fileURLToPath(import.meta.url));
const vpyCli = process.env.VPY_CLI || path.resolve(here, '../../electron/resources/vpy_cli');
const sdkRoot = path.join(homedir(), 'VectrexStudio/sdk');
const sdk = process.env.VPY_SDK || (existsSync(sdkRoot) ? readdirSync(sdkRoot).filter((v) => /^v\d/.test(v)).sort().pop() : undefined);
if (!existsSync(vpyCli) || !sdk) {
  console.log(`skip: needs ${vpyCli} and an SDK in ${sdkRoot}`);
  process.exit(0);
}

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

function build(backend: 'asm' | 'c'): Uint8Array {
  const root = mkdtempSync(path.join(tmpdir(), `dwarf-lines-${backend}-`));
  mkdirSync(path.join(root, 'src'));
  writeFileSync(path.join(root, 'duo.vpyproj'), `[project]
name = "duo"
version = "0.1.0"
entry = "src/main.vpy"

[build]
output = "build/duo.bin"

[sdk]
version = "${sdk}"
${backend === 'c' ? '\n[uvm2]\nbackend = "c"\n' : ''}`);
  writeFileSync(path.join(root, 'src/main.vpy'), MAIN);
  writeFileSync(path.join(root, 'src/util.vpy'), UTIL);
  execFileSync(vpyCli, ['build', path.join(root, 'duo.vpyproj'), '--target', 'uvm2'], { stdio: 'pipe' });
  const elf = new Uint8Array(readFileSync(path.join(root, 'build/duo.elf')));
  rmSync(root, { recursive: true, force: true });
  return elf;
}

let n = 0;
const t = (name: string, f: () => void) => { f(); n++; console.log(`  ok   ${name}`); };

for (const backend of ['asm', 'c'] as const) {
  const elf = build(backend);
  const table = lineTable(elf);
  const util = [...table.files].find((f) => f.endsWith('/src/util.vpy'))!;
  const main = [...table.files].find((f) => f.endsWith('/src/main.vpy'))!;

  t(`${backend}: both .vpy files are in the table, by their absolute paths`, () => {
    assert.ok(util && main, [...table.files].filter((f) => f.endsWith('.vpy')).join(', '));
    assert.ok(path.isAbsolute(util) && path.isAbsolute(main));
  });

  t(`${backend}: util.vpy:5 and main.vpy:10 have statements, and the way back names them`, () => {
    for (const [file, line] of [[util, 5], [main, 10]] as const) {
      const starts = table.starts.get(`${file}:${line}`);
      assert.ok(starts?.length, `${file}:${line}`);
      // optimised C may put another row at the same address: one of them is this line
      const rows = parseLineRows(elf).filter((r) => r.address === starts![0] && r.line > 0);
      assert.ok(rows.some((r) => r.file === file && r.line === line));
    }
  });

  t(`${backend}: a comment has no statement; no row sits at a dropped function's address 0`, () => {
    assert.equal(table.starts.get(`${main}:9`), undefined);
    assert.ok(parseLineRows(elf).every((r) => r.address !== 0));
  });

  t(`${backend}: the functions' entry points come from the symbol table`, () => {
    assert.ok(table.functionStarts.size > 10);
    // the statement of `def bump` (asm: its def line) or of its body (C) is at/after an entry
    const first = Math.min(...(table.starts.get(`${util}:4`) ?? [Infinity]));
    assert.ok([...table.functionStarts].some((f) => f <= first && first - f < 64));
  });
}

console.log(`${n} passed`);
