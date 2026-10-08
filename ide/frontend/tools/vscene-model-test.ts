/**
 * Tests for the Scene Editor's model (src/components/scene/vsceneModel.ts).
 *
 *   node tools/vscene-model-test.ts            (node >= 22.18 strips the types)
 *
 * Every validation case is also written to a temp project (scenes/ + meshes/)
 * and given to the compiler (`vpy_cli check-asset`): the test fails if the
 * editor's errors and the compiler disagree. Set VPY_CLI to point elsewhere;
 * without a vpy_cli that knows .vscene the cross-check is skipped. The
 * placement cases are worked out by hand from vpy3d_draw_scene (vpy3d.c).
 */
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, mkdirSync, readdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as S from '../src/components/scene/vsceneModel.ts';

const here = path.dirname(fileURLToPath(import.meta.url));
const vpyCli = process.env.VPY_CLI || path.resolve(here, '../../electron/resources/vpy_cli');
const work = mkdtempSync(path.join(tmpdir(), 'vscene-test-'));
mkdirSync(path.join(work, 'scenes'), { recursive: true });
mkdirSync(path.join(work, 'meshes'), { recursive: true });
const MESHES = ['a', 'b', 'c', 'rib'];
for (const m of MESHES) {
  writeFileSync(path.join(work, 'meshes', `${m}.vmesh`), JSON.stringify({ name: m, lines: [{ points: [{ x: 0, y: 0, z: 0 }, { x: 100, y: 0, z: 0 }] }] }));
}
const exists = (n: string) => MESHES.includes(n);

let passed = 0;
const test = (name: string, fn: () => void) => {
  try { fn(); passed++; console.log(`ok   ${name}`); }
  catch (e) { console.error(`FAIL ${name}\n${(e as Error).stack}`); process.exitCode = 1; }
};

/** Does the compiler accept the scene? */
function cliCheck(file: string): { ok: boolean; error: string } {
  try {
    const out = execFileSync(vpyCli, ['check-asset', file, '--json'], { stdio: 'pipe', encoding: 'utf-8' });
    const line = out.trim().split('\n').reverse().find((l) => l.startsWith('{'));
    const j = line ? JSON.parse(line) : { ok: true };
    return { ok: j.ok !== false, error: j.error || '' };
  } catch (e) {
    const err = e as { stdout?: string; stderr?: string };
    const line = (err.stdout || '').trim().split('\n').reverse().find((l) => l.startsWith('{'));
    return { ok: false, error: line ? JSON.parse(line).error : (err.stderr || String(e)) };
  }
}
const cliKnowsScenes = existsSync(vpyCli) && (() => {
  const f = path.join(work, 'scenes', 'probe.vscene');
  writeFileSync(f, JSON.stringify({ items: [{ mesh: 'a' }] }));
  return cliCheck(f).ok;
})();

let caseNo = 0;
/** The editor and the compiler must agree on whether a file is an error. */
function agree(name: string, raw: unknown): boolean {
  const errs = S.validateVscene(raw, exists);
  const editorOk = errs.length === 0;
  if (!cliKnowsScenes) return editorOk;
  const file = path.join(work, 'scenes', `case${caseNo++}.vscene`);
  writeFileSync(file, typeof raw === 'string' ? raw : JSON.stringify(raw, null, 2));
  const cli = cliCheck(file);
  assert.equal(editorOk, cli.ok, `${name}: editor says ${editorOk ? 'ok' : JSON.stringify(errs.map((e) => e.message))}, vpy_cli says ${cli.ok ? 'ok' : cli.error}`);
  return editorOk;
}

// ── validation, cross-checked ──────────────────────────────────────────────

const VALID: [string, unknown][] = [
  ['one item', { items: [{ mesh: 'a' }] }],
  ['the doc example', {
    name: 'tunnel', fog: { full: 3000, gone: 17500 }, groups: ['alarm'],
    items: [
      { name: 'ribs', mesh: 'rib', at: { z: 600 }, follow: { z: -1 }, repeat: { axis: 'z', step: 2000, count: 9 }, fog: 'whole' },
      { name: 'panels', mesh: ['a', 'b'], at: { z: 600 }, follow: { x: 0.9167, z: -1 }, repeat: { step: 2000, count: 9 }, window: { max: 10999 }, br: 75 },
      { mesh: 'c', fog: false },
      { mesh: 'rib', group: '!alarm' },
    ],
  }],
  ['a one-name list without a repeat', { items: [{ mesh: ['a'] }] }],
  ['follow exactly 64 and -64', { items: [{ mesh: 'a', follow: { x: 64, y: -64, z: 0.00001 } }] }],
  ['at at the limit', { items: [{ mesh: 'a', at: { x: 1000000, y: -1000000, z: 0 } }] }],
  ['window with only a min, a null max', { items: [{ mesh: 'a', window: { min: 400, max: null } }] }],
  ['an empty window', { items: [{ mesh: 'a', window: {} }] }],
  ['br 1 and 100', { items: [{ mesh: 'a', br: 1 }, { mesh: 'b', br: 100 }] }],
  ['nulls where serde reads Option', { name: null, fog: null, items: [{ name: null, mesh: 'a', repeat: null, window: null, br: null, group: null }] }],
  ['repeat at its limits', { items: [{ mesh: ['a', 'b', 'c'], repeat: { axis: 'x', step: 1000000, count: 255 } }, { mesh: 'a', repeat: { axis: 'y', step: 1, count: 1 } }] }],
  ['unknown keys are ignored', { extra: 1, items: [{ mesh: 'a', note: 'x', at: { x: 1, w: 9 } }] }],
  ['fog full 0', { fog: { full: 0, gone: 1 }, items: [{ mesh: 'a' }] }],
  ['32 groups', { groups: Array.from({ length: 32 }, (_, i) => `g${i}`), items: [{ mesh: 'a', group: 'g31' }] }],
  ['16 meshes', { items: Array.from({ length: 16 }, (_, i) => ({ mesh: 'abc'[i % 3] })) }],
];
const INVALID: [string, unknown][] = [
  ['no items', { items: [] }],
  ['items missing', { name: 'x' }],
  ['items not a list', { items: { mesh: 'a' } }],
  ['an item that is not an object', { items: [3] }],
  ['mesh missing', { items: [{ at: { z: 1 } }] }],
  ['missing mesh file', { items: [{ mesh: 'missing' }] }],
  ['a path, not a name', { items: [{ mesh: '../a' }] }],
  ['with the extension', { items: [{ mesh: 'a.vmesh' }] }],
  ['empty mesh name', { items: [{ mesh: '' }] }],
  ['empty mesh list', { items: [{ mesh: [], repeat: { step: 10, count: 2 } }] }],
  ['a number in the mesh list', { items: [{ mesh: ['a', 1], repeat: { step: 10, count: 2 } }] }],
  ['turns without a repeat', { items: [{ mesh: ['a', 'b'] }] }],
  ['zero step', { items: [{ mesh: 'a', repeat: { step: 0, count: 3 } }] }],
  ['fractional step', { items: [{ mesh: 'a', repeat: { step: 1.5, count: 3 } }] }],
  ['step over the limit', { items: [{ mesh: 'a', repeat: { step: 1000001, count: 3 } }] }],
  ['count 0', { items: [{ mesh: 'a', repeat: { step: 10, count: 0 } }] }],
  ['count 256', { items: [{ mesh: 'a', repeat: { step: 10, count: 256 } }] }],
  ['count missing', { items: [{ mesh: 'a', repeat: { step: 10 } }] }],
  ['bad axis', { items: [{ mesh: 'a', repeat: { axis: 'w', step: 10, count: 3 } }] }],
  ['null axis', { items: [{ mesh: 'a', repeat: { axis: null, step: 10, count: 3 } }] }],
  ['unknown group', { items: [{ mesh: 'a', group: 'x' }] }],
  ['negated unknown group', { groups: ['x'], items: [{ mesh: 'a', group: '!y' }] }],
  ['a bare "!"', { groups: ['x'], items: [{ mesh: 'a', group: '!' }] }],
  ['br over 100', { items: [{ mesh: 'a', br: 101 }] }],
  ['br 0', { items: [{ mesh: 'a', br: 0 }] }],
  ['fractional br', { items: [{ mesh: 'a', br: 50.5 }] }],
  ['unknown fog mode', { items: [{ mesh: 'a', fog: 'thick' }] }],
  ['numeric fog', { items: [{ mesh: 'a', fog: 1 }] }],
  ['null fog', { items: [{ mesh: 'a', fog: null }] }],
  ['fog backwards', { fog: { full: 9, gone: 3 }, items: [{ mesh: 'a' }] }],
  ['fog full = gone', { fog: { full: 5, gone: 5 }, items: [{ mesh: 'a' }] }],
  ['negative fog', { fog: { full: -1, gone: 3 }, items: [{ mesh: 'a' }] }],
  ['fog without gone', { fog: { full: 1 }, items: [{ mesh: 'a' }] }],
  ['fog over i32', { fog: { full: 1, gone: 2147483648 }, items: [{ mesh: 'a' }] }],
  ['window backwards', { items: [{ mesh: 'a', window: { min: 5, max: 1 } }] }],
  ['fractional window', { items: [{ mesh: 'a', window: { min: 1.5 } }] }],
  ['fractional at', { items: [{ mesh: 'a', at: { x: 0.5 } }] }],
  ['too far', { items: [{ mesh: 'a', at: { z: 2000000 } }] }],
  ['null at', { items: [{ mesh: 'a', at: null }] }],
  ['null at.x', { items: [{ mesh: 'a', at: { x: null } }] }],
  ['follow over 64', { items: [{ mesh: 'a', follow: { z: 64.0001 } }] }],
  ['groups null', { groups: null, items: [{ mesh: 'a' }] }],
  ['a group starting with "!"', { groups: ['!a'], items: [{ mesh: 'a' }] }],
  ['an empty group name', { groups: [''], items: [{ mesh: 'a' }] }],
  ['a group twice', { groups: ['a', 'a'], items: [{ mesh: 'a' }] }],
  ['33 groups', { groups: Array.from({ length: 33 }, (_, i) => `g${i}`), items: [{ mesh: 'a' }] }],
  ['a numeric name', { name: 3, items: [{ mesh: 'a' }] }],
  ['17 meshes', { items: Array.from({ length: 17 }, (_, i) => ({ mesh: `m${i}` })) }],
];

// the 17-mesh case needs its meshes to exist to reach the table check
if (cliKnowsScenes) {
  for (let i = 0; i < 17; i++) writeFileSync(path.join(work, 'meshes', `m${i}.vmesh`), readFileSync(path.join(work, 'meshes', 'a.vmesh')));
}
const existsAll = (n: string) => exists(n) || /^m\d+$/.test(n);

for (const [name, raw] of VALID) test(`valid: ${name}`, () => assert.ok(agree(name, raw), JSON.stringify(S.validateVscene(raw, exists))));
for (const [name, raw] of INVALID) {
  test(`invalid: ${name}`, () => {
    const errs = S.validateVscene(raw, existsAll);
    assert.ok(errs.length > 0, 'the editor accepts it');
    if (cliKnowsScenes) {
      const file = path.join(work, 'scenes', `case${caseNo++}.vscene`);
      writeFileSync(file, JSON.stringify(raw));
      const cli = cliCheck(file);
      assert.ok(!cli.ok, `vpy_cli accepts it (editor: ${errs[0].message})`);
    }
  });
}

test('errors point at their item and group', () => {
  const errs = S.validateVscene({ groups: ['a', 'a'], items: [{ mesh: 'a' }, { mesh: 'a', br: 0 }] }, exists);
  assert.ok(errs.some((e) => e.item === 1 && /br/.test(e.message)));
  assert.ok(errs.some((e) => e.group === 1 && /twice/.test(e.message)));
});
test('an unknown mesh listing says nothing about missing meshes', () => {
  assert.deepEqual(S.validateVscene({ items: [{ mesh: 'whatever' }] }, () => undefined), []);
  assert.deepEqual(S.validateVscene({ items: [{ mesh: 'whatever' }] }), []);
});

// The real scenes of a game, when it is on this machine.
const ROTJ = path.join(process.env.HOME || '', 'VectrexStudio/projects/return_of_the_jedi/assets');
if (existsSync(path.join(ROTJ, 'scenes'))) {
  const have = (n: string) => existsSync(path.join(ROTJ, 'meshes', `${n}.vmesh`));
  for (const f of readdirSync(path.join(ROTJ, 'scenes')).filter((x) => x.endsWith('.vscene'))) {
    test(`real scene ${f}: no errors, and the compiler agrees`, () => {
      const file = path.join(ROTJ, 'scenes', f);
      const raw = JSON.parse(readFileSync(file, 'utf-8'));
      assert.deepEqual(S.validateVscene(raw, have), []);
      if (cliKnowsScenes) assert.ok(cliCheck(file).ok);
      assert.ok(S.placeScene(raw, [0, 0, 0], 0).copies.length > 0);
    });
  }
}

// ── placement (vpy3d_draw_scene), worked out by hand ───────────────────────

const zs = (p: S.Placement, item = 0) => p.copies.filter((c) => c.item === item).map((c) => c.at[2]);
const ns = (p: S.Placement, item = 0) => p.copies.filter((c) => c.item === item).map((c) => c.n);
const RIBS = { items: [{ mesh: 'rib', at: { z: 600 }, follow: { z: -1 }, repeat: { axis: 'z', step: 2000, count: 9 } }] };

test('repeat at pos 0: copies from at, numbered 0..', () => {
  const p = S.placeScene(RIBS, [0, 0, 0], 0);
  assert.deepEqual(zs(p), [600, 2600, 4600, 6600, 8600, 10600, 12600, 14600, 16600]);
  assert.deepEqual(ns(p), [0, 1, 2, 3, 4, 5, 6, 7, 8]);
});
test('repeat wraps: pos.z 4500 -> p.z -3900, n0 2, first copy at 100', () => {
  const p = S.placeScene(RIBS, [0, 0, 4500], 0);
  assert.deepEqual(zs(p), [100, 2100, 4100, 6100, 8100, 10100, 12100, 14100, 16100]);
  assert.deepEqual(ns(p), [2, 3, 4, 5, 6, 7, 8, 9, 10]);
});
test('repeat wraps on an exact step: pos.z 2000 -> back at 600, n0 1', () => {
  const p = S.placeScene(RIBS, [0, 0, 2000], 0);
  assert.equal(zs(p)[0], 600);
  assert.equal(ns(p)[0], 1);
});
test('repeat with a negative pos: pos.z -2500 -> p.z 3100, n0 -2, first copy at -900', () => {
  const p = S.placeScene(RIBS, [0, 0, -2500], 0);
  assert.deepEqual(zs(p).slice(0, 3), [-900, 1100, 3100]);
  assert.deepEqual(ns(p).slice(0, 3), [-2, -1, 0]);
});
test('the first copy is always in (at - step, at]', () => {
  for (let z = -10000; z <= 10000; z += 137) {
    const first = zs(S.placeScene(RIBS, [0, 0, z], 0))[0];
    assert.ok(first > 600 - 2000 && first <= 600, `pos.z ${z}: first copy at ${first}`);
  }
});
test('meshes take turns by copy number, also below zero', () => {
  const two = { items: [{ mesh: ['a', 'b'], at: { z: 600 }, follow: { z: -1 }, repeat: { step: 2000, count: 4 } }] };
  assert.deepEqual(S.placeScene(two, [0, 0, 4500], 0).copies.map((c) => c.mesh), ['a', 'b', 'a', 'b']);       // n 2..5
  assert.deepEqual(S.placeScene(two, [0, 0, 6500], 0).copies.map((c) => c.mesh), ['b', 'a', 'b', 'a']);       // n 3..6
  assert.deepEqual(S.placeScene(two, [0, 0, -2500], 0).copies.map((c) => c.mesh), ['a', 'b', 'a', 'b']);      // n -2..1
  const three = { items: [{ mesh: ['a', 'b', 'c'], at: { z: 0 }, follow: { z: -1 }, repeat: { step: 100, count: 4 } }] };
  const p = S.placeScene(three, [0, 0, -150], 0);                                                              // p.z 150, n0 -2
  assert.deepEqual(ns(p), [-2, -1, 0, 1]);
  assert.deepEqual(p.copies.map((c) => c.mesh), ['b', 'c', 'a', 'b']);
});
test('window: a copy is drawn only while its world z is within min..max', () => {
  const w = { items: [{ ...RIBS.items[0], window: { min: 400, max: 10999 } }] };
  const p = S.placeScene(w, [0, 0, 4500], 0);
  assert.deepEqual(zs(p), [2100, 4100, 6100, 8100, 10100]);
  assert.equal(p.windowed[0], 4);
  const onlyMax = S.placeScene({ items: [{ ...RIBS.items[0], window: { max: 10999 } }] }, [0, 0, 4500], 0);
  assert.deepEqual(zs(onlyMax), [100, 2100, 4100, 6100, 8100, 10100]);
  // a window on a piece that does not repeat
  const still = { items: [{ mesh: 'a', at: { z: 600 }, follow: { z: -1 }, window: { min: 0 } }] };
  assert.equal(S.placeScene(still, [0, 0, 500], 0).copies.length, 1);
  assert.equal(S.placeScene(still, [0, 0, 700], 0).copies.length, 0);
});
test('follow fractions: Q16, then >> 16 floors (negative pos too)', () => {
  assert.equal(S.followQ16(0.9167), 60077);                   // 60076.85 rounds up
  assert.equal(S.followQ16(-0.5 / 65536), -1);          // f64::round, half away from zero
  const f = { items: [{ mesh: 'a', at: { x: 10 }, follow: { x: 0.9167, y: 0.5 } }] };
  assert.deepEqual(S.placeScene(f, [1000, 3, 0], 0).copies[0].at, [10 + 916, 1, 0]);      // 60077000/65536 = 916.70 -> 916; 1.5 -> 1
  assert.deepEqual(S.placeScene(f, [-1000, -3, 0], 0).copies[0].at, [10 - 917, -2, 0]);   // -916.70 -> -917; -1.5 -> -2
});
test('a repeat along x follows the same rules', () => {
  const x = { items: [{ mesh: 'a', at: { x: -500, z: 3000 }, follow: { x: -1 }, repeat: { axis: 'x', step: 300, count: 3 } }] };
  const p = S.placeScene(x, [700, 0, 0], 0);                                                  // p.x -1200, n0 2, -600
  assert.deepEqual(p.copies.map((c) => c.at), [[-600, 0, 3000], [-300, 0, 3000], [0, 0, 3000]]);
});
test('groups: bit n = the n-th group, "!name" inverts', () => {
  const g = { groups: ['alarm', 'night'], items: [{ mesh: 'a', group: 'alarm' }, { mesh: 'b', group: '!night' }, { mesh: 'c' }] };
  const drawn = (mask: number) => S.placeScene(g, [0, 0, 0], mask).copies.map((c) => c.mesh);
  assert.deepEqual(drawn(0), ['b', 'c']);
  assert.deepEqual(drawn(1), ['a', 'b', 'c']);
  assert.deepEqual(drawn(2), ['c']);
  assert.deepEqual(drawn(3), ['a', 'c']);
  assert.deepEqual(S.placeScene(g, [0, 0, 0], 2).groupedOut, [true, true, false]);
});
test('fog: vpy3d_fog by depth', () => {
  assert.equal(S.fogBrightness(127, 1000, 3000, 17500), 127);
  assert.equal(S.fogBrightness(127, 17500, 3000, 17500), 0);
  assert.equal(S.fogBrightness(100, 10250, 3000, 17500), 50);
  assert.deepEqual(S.sceneFog({ fog: { full: 0, gone: 0 } }), null);
});

// ── edits ──────────────────────────────────────────────────────────────────

test('edits keep unknown keys and compile', () => {
  let r: S.VsceneRaw = { name: 's', custom: { keep: true }, items: [{ mesh: 'a', note: 'mine', at: { z: 5 } }] };
  r = S.setItemAxis(r, 0, 'at', 'z', 0);
  assert.equal((r.items as any)[0].at, undefined, 'an all-zero "at" is dropped');
  r = S.setItemAxis(r, 0, 'follow', 'z', -1);
  r = S.setItemSub(r, 0, 'repeat', 'step', 100);
  r = S.setItemSub(r, 0, 'repeat', 'count', 3);
  r = S.setItemMeshes(r, 0, ['a', 'b']);
  r = S.duplicateItem(r, 0).raw;
  r = S.moveItem(r, 1, -1).raw;
  r = S.addGroup(r, 'alarm');
  r = S.setItemField(r, 1, 'group', '!alarm');
  r = S.renameGroup(r, 0, 'siren');
  assert.equal((r.items as any)[1].group, '!siren');
  assert.equal((r.items as any)[0].note, 'mine');
  assert.deepEqual(r.custom, { keep: true });
  assert.ok(agree('edited', r));
  r = S.deleteGroup(r, 0);
  assert.equal((r.items as any)[1].group, undefined);
  assert.equal(r.groups, undefined);
  r = S.deleteItem(r, 0);
  assert.equal(S.items(r).length, 1);
  assert.ok(agree('edited again', r));
  assert.ok(agree('a new scene', S.newScene('n', 'a')));
});

rmSync(work, { recursive: true, force: true });
console.log(`\n${passed} passed${cliKnowsScenes ? '' : ' (no vpy_cli that knows .vscene: compiler cross-check skipped; set VPY_CLI)'}`);
