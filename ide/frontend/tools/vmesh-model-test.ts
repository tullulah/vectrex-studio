/**
 * Tests for the Mesh Editor's model (src/components/mesh/vmeshModel.ts).
 *
 *   node tools/vmesh-model-test.ts            (node >= 22.18 strips the types)
 *
 * Besides unit checks, every case is also written to a temp file and given to
 * the bundled compiler (`vpy_cli check-asset`), and the test fails if the
 * editor's errors and the compiler disagree. Set VPY_CLI to point elsewhere;
 * without a vpy_cli the cross-check is skipped.
 */
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as M from '../src/components/mesh/vmeshModel.ts';

const here = path.dirname(fileURLToPath(import.meta.url));
const vpyCli = process.env.VPY_CLI || path.resolve(here, '../../electron/resources/vpy_cli');
const haveCli = existsSync(vpyCli);
const work = mkdtempSync(path.join(tmpdir(), 'vmesh-test-'));

let passed = 0;
const test = (name: string, fn: () => void) => {
  try { fn(); passed++; console.log(`ok   ${name}`); }
  catch (e) { console.error(`FAIL ${name}\n${(e as Error).stack}`); process.exitCode = 1; }
};

const errors = (raw: unknown, r?: M.VecResolver) => M.validateVmesh(raw, r).filter((i) => i.level === 'error');
const warnings = (raw: unknown, r?: M.VecResolver) => M.validateVmesh(raw, r).filter((i) => i.level === 'warning');

/** Does the compiler accept it? */
function cliAccepts(name: string, raw: unknown, extraFiles: Record<string, string> = {}): boolean {
  const dir = path.join(work, name);
  mkdirSync(path.join(dir, 'meshes'), { recursive: true });
  for (const [rel, text] of Object.entries(extraFiles)) {
    mkdirSync(path.dirname(path.join(dir, rel)), { recursive: true });
    writeFileSync(path.join(dir, rel), text);
  }
  const file = path.join(dir, 'meshes', `${name}.vmesh`);
  writeFileSync(file, typeof raw === 'string' ? raw : JSON.stringify(raw, null, 2));
  try { execFileSync(vpyCli, ['check-asset', file], { stdio: 'pipe' }); return true; } catch { return false; }
}

/** The editor and the compiler must agree on whether a file is an error. */
function agree(name: string, raw: unknown, r?: M.VecResolver, extraFiles?: Record<string, string>) {
  const editorOk = errors(raw, r).length === 0;
  if (!haveCli) return editorOk;
  const cliOk = cliAccepts(name, raw, extraFiles);
  assert.equal(editorOk, cliOk, `${name}: editor says ${editorOk ? 'ok' : JSON.stringify(errors(raw, r))}, vpy_cli says ${cliOk ? 'ok' : 'error'}`);
  return editorOk;
}

const outward = (m: M.MeshData) => {
  const c = M.centroidOf(m.vertices);
  return m.faces.every((f) => {
    const n = M.newell(m.vertices, f);
    const g = M.centroidOf(m.vertices, f);
    return n[0] * (g[0] - c[0]) + n[1] * (g[1] - c[1]) + n[2] * (g[2] - c[2]) > 0;
  });
};

// ── primitives ───────────────────────────────────────────────────────────

for (const kind of ['cube', 'pyramid', 'cylinder'] as const) {
  test(`primitive ${kind}: outward, closed, compiles, no warnings`, () => {
    const m = M.makePrimitive(kind, 1000, 8);
    assert.ok(outward(m), 'every face wound outward');
    const raw = M.meshToRaw({ name: kind, hard: 45 }, m);
    assert.ok(agree(`prim_${kind}`, raw));
    assert.deepEqual(warnings(raw), []);
  });
}

test('primitive grid: a plate, compiles, faces up, warns only when not open', () => {
  const m = M.primitiveGrid(1000, 3);
  assert.equal(m.vertices.length, 16);
  assert.equal(m.faces.length, 9);
  for (const f of m.faces) assert.ok(M.newell(m.vertices, f)[1] > 0, 'faces +y');
  const raw = M.meshToRaw({ name: 'grid', hard: 45, open: true }, m);
  assert.ok(agree('prim_grid', raw));
  assert.deepEqual(warnings(raw), []);
  assert.ok(warnings({ ...raw, open: false }).some((w) => /closed/.test(w.message)));
});

// ── validation mirrors the compiler ─────────────────────────────────────

const cube = M.primitiveCube(1000);
const cubeRaw = M.meshToRaw({ name: 'cube', hard: 45 }, cube);

test('loader cases from vmeshres.rs tests', () => {
  assert.ok(agree('explicit_quad', { name: 'c', hard: 45, vertices: [{ x: -1, y: -1, z: -1 }, { x: 1, y: -1, z: -1 }, { x: 1, y: 1, z: -1 }, { x: -1, y: 1, z: -1 }], faces: [[0, 3, 2, 1]] }));
  const tri = [{ x: 0, y: 10 }, { x: 9, y: -5 }, { x: -9, y: -5 }];
  assert.ok(agree('tube', { name: 't', caps: true, sections: [{ z: -10, points: tri }, { z: 10, points: tri }] }));
  assert.ok(!agree('mismatch', { sections: [{ z: 0, points: tri }, { z: 9, points: [...tri, { x: 1, y: 1 }] }] }));
  assert.ok(!agree('badidx', { vertices: [{ x: 0, y: 0, z: 0 }], faces: [[0, 1, 2]] }));
  assert.ok(!agree('both', { vertices: [{ x: 0, y: 0, z: 0 }], faces: [[0, 0, 0]], sections: [{ z: 0, points: tri }, { z: 1, points: tri }] }));
});

test('more error cases agree with the compiler', () => {
  assert.ok(!agree('empty', {}));
  assert.ok(!agree('no_faces', { vertices: cube.vertices, faces: [] }));
  assert.ok(!agree('two_vert_face', { ...cubeRaw, faces: [[0, 1]] }));
  assert.ok(!agree('out_of_i16', { ...cubeRaw, vertices: cube.vertices.map((v, i) => (i ? v : { ...v, x: 40000 })) }));
  assert.ok(!agree('float_coord', { ...cubeRaw, vertices: cube.vertices.map((v, i) => (i ? v : { ...v, y: 1.5 })) }));
  assert.ok(!agree('missing_x', { ...cubeRaw, vertices: cube.vertices.map((v, i) => (i ? v : { y: 0, z: 0 })) }));
  assert.ok(!agree('neg_index', { ...cubeRaw, faces: [[0, 1, -2]] }));
  assert.ok(!agree('hard_string', { ...cubeRaw, hard: '45' }));
  assert.ok(!agree('open_number', { ...cubeRaw, open: 1 }));
  assert.ok(!agree('one_section', { sections: [{ z: 0, points: [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: 0, y: 1 }] }] }));
  assert.ok(!agree('short_section', { sections: [{ z: 0, points: [{ x: 0, y: 0 }, { x: 1, y: 0 }] }, { z: 1, points: [{ x: 0, y: 0 }, { x: 1, y: 0 }] }] }));
  assert.ok(!agree('not_json_object', [1, 2, 3]));
});

test('accepted-but-warned cases compile', () => {
  // a missing z defaults to 0; unknown fields are ignored; unused vertex
  assert.ok(agree('no_z', { ...cubeRaw, vertices: [...cube.vertices, { x: 5, y: 5 }], comment: 'hi' }));
  assert.ok(warnings({ ...cubeRaw, vertices: [...cube.vertices, { x: 5, y: 5 }] }).some((w) => /no "z"/.test(w.message)));
  assert.ok(warnings({ ...cubeRaw, vertices: [...cube.vertices, { x: 5, y: 5, z: 0 }] }).some((w) => /in no face/.test(w.message)));
  // hard_cos overrides hard
  assert.equal(M.hardCosQ14({ hard: 45 }), 11585);
  assert.equal(M.hardCosQ14({ hard: 45, hard_cos: 99999 }), 16384);
  assert.equal(M.hardCosQ14({}), 11585);
  // too many vertices for vpy3d: a warning, not an error
  const big = M.primitiveGrid(1000, 15);
  const many = M.appendMesh(big, M.primitiveGrid(500, 15));
  const rawMany = M.meshToRaw({ name: 'many', open: true }, many);
  assert.ok(agree('many', rawMany));
  assert.ok(warnings(rawMany).some((w) => /VPY3D_MESH_MAXV/.test(w.message)));
});

test('vec-referenced sections', () => {
  const vec = JSON.stringify({ version: '1.0', name: 'ring', canvas: { width: 256, height: 256, origin: 'center' }, layers: [
    { name: 'hidden', visible: false, paths: [{ name: 'h', closed: true, points: [{ x: 0, y: 0 }] }] },
    { name: 'default', visible: true, paths: [{ name: 'rib', closed: true, points: [{ x: 0, y: 10 }, { x: 9, y: -5 }, { x: -9, y: -5 }] }] },
  ] });
  const resolver: M.VecResolver = (_v, p) => M.ringFromVec(JSON.parse(vec), p, 'ring.vec');
  const raw = { name: 'hull', sections: [{ z: -10, vec: '../vectors/ring.vec', path: 'rib' }, { z: 10, vec: '../vectors/ring.vec' }] };
  assert.ok(agree('vec_sections', raw, resolver, { 'vectors/ring.vec': vec }));
  const l = M.loftRaw(raw, resolver);
  assert.equal(l.mesh?.vertices.length, 6);
  assert.equal(l.mesh?.faces.length, 5);
  assert.ok(!agree('vec_bad_path', { ...raw, sections: [{ z: 0, vec: '../vectors/ring.vec', path: 'nope' }, raw.sections[1]] }, resolver, { 'vectors/ring.vec': vec }));
  // not loaded yet: no error, a warning that checks are pending
  assert.deepEqual(errors(raw), []);
  assert.ok(warnings(raw).some((w) => /not loaded/.test(w.message)));
});

// ── loft and geometry ───────────────────────────────────────────────────

test('loft matches vmeshres.rs counts and caps winding', () => {
  const sq = [{ x: -1, y: -1 }, { x: 1, y: -1 }, { x: 1, y: 1 }, { x: -1, y: 1 }];
  const r = M.loftRaw({ sections: [{ z: -1, points: sq }, { z: 0, points: sq }, { z: 1, points: sq }] });
  assert.equal(r.mesh!.vertices.length, 12);
  assert.equal(r.mesh!.faces.length, 4 * 2 + 2);
  assert.deepEqual(r.mesh!.faces.at(-2), [3, 2, 1, 0]);
  assert.deepEqual(r.mesh!.faces.at(-1), [8, 9, 10, 11]);
  const nocaps = M.loftRaw({ caps: false, sections: [{ z: -1, points: sq }, { z: 1, points: sq }] });
  assert.equal(nocaps.mesh!.faces.length, 4);
});

test('geometry: cube has 12 hard edges; a 3-of-12 view of a cube shows 9', () => {
  const g = M.meshGeometry(cube, M.hardCosQ14({ hard: 45 }));
  assert.equal(g.edges.length, 12);
  assert.ok(g.edges.every((e) => e.hard && e.f1 >= 0));
  // looking along +z (front view): only the front face is turned to us → 4 edges
  assert.equal(g.edges.filter((e) => M.edgeVisible(g, e, [0, 0, 1], false)).length, 4);
  // looking down a body diagonal: three faces → 9 edges
  const d = 1 / Math.sqrt(3);
  assert.equal(g.edges.filter((e) => M.edgeVisible(g, e, [d, d, d], false)).length, 9);
  // a 16-sided cylinder at hard 45 has smooth sides: side seams are not creases
  const cyl = M.primitiveCylinder(500, 1000, 16);
  const gc = M.meshGeometry(cyl, M.hardCosQ14({ hard: 45 }));
  const seams = gc.edges.filter((e) => cyl.vertices[e.a].x === cyl.vertices[e.b].x && cyl.vertices[e.a].z === cyl.vertices[e.b].z);
  assert.equal(seams.length, 16);
  assert.ok(seams.every((e) => !e.hard));
});

// ── edit operations ─────────────────────────────────────────────────────

test('deleteVertices drops faces and re-indexes', () => {
  const m = M.deleteVertices(cube, [0]);
  assert.equal(m.vertices.length, 7);
  assert.equal(m.faces.length, 3);
  assert.ok(m.faces.every((f) => f.every((i) => i >= 0 && i < 7)));
  assert.deepEqual(m.vertices[0], cube.vertices[1]);
});

test('connect splits a face, disconnect merges it back', () => {
  const c = M.connectVertices(cube, 0, 2);
  assert.ok('mesh' in c);
  const m = (c as { mesh: M.MeshData }).mesh;
  assert.equal(m.faces.length, 7);
  assert.ok(errors(M.meshToRaw({}, m)).length === 0);
  assert.ok(outward(m));
  assert.ok(warnings(M.meshToRaw({}, m)).every((w) => !/inconsistent/.test(w.message)));
  const d = M.disconnectVertices(m, 0, 2);
  assert.ok('mesh' in d);
  const back = (d as { mesh: M.MeshData }).mesh;
  assert.equal(back.faces.length, 6);
  assert.ok(outward(back));
  // the merged face has the same corners as the original
  assert.deepEqual([...back.faces[0]].sort(), [0, 1, 2, 3]);
  assert.ok('error' in M.connectVertices(cube, 0, 1), 'already an edge');
  assert.ok('error' in M.connectVertices(cube, 0, 6), 'not on one face');
  assert.ok('error' in M.disconnectVertices(cube, 0, 2), 'no such edge');
});

test('disconnect on a cube edge merges two sides into a hexagon', () => {
  const d = M.disconnectVertices(cube, 0, 1);
  assert.ok('mesh' in d);
  const m = (d as { mesh: M.MeshData }).mesh;
  assert.equal(m.faces.length, 5);
  assert.ok(m.faces.some((f) => f.length === 6));
  assert.ok(warnings(M.meshToRaw({}, m)).every((w) => !/inconsistent/.test(w.message)));
});

test('makeFace winds outward, refuses duplicates and short selections', () => {
  const noTop = M.deleteFaces(cube, [3]); // [2,3,7,6] = the +y face
  const r = M.makeFace(noTop, [2, 6, 7, 3]); // given inward
  assert.ok('mesh' in r);
  assert.ok(outward((r as { mesh: M.MeshData }).mesh));
  assert.ok('error' in M.makeFace(cube, [0, 1, 2, 3]));
  assert.ok('error' in M.makeFace(cube, [0, 1]));
});

test('flip + windOutward', () => {
  const flipped = M.flipFaces(cube, [0, 2]);
  assert.ok(!outward(flipped));
  assert.ok(warnings(M.meshToRaw({}, flipped)).some((w) => /inconsistent/.test(w.message)));
  assert.ok(outward(M.windOutward(flipped)));
});

test('moves clamp to i16; setVertex rounds', () => {
  const m = M.moveVertices(cube, [0], { x: -1e6, y: 0, z: 0 });
  assert.equal(m.vertices[0].x, M.I16_MIN);
  assert.equal(M.setVertex(cube, 1, { y: 12.6 }).vertices[1].y, 13);
  assert.equal(cube.vertices[0].x, -500, 'operations do not mutate their input');
});

// ── serialization keeps what it does not know ───────────────────────────

test('round-trip keeps unknown fields and key order', () => {
  const raw = { name: 'thing', author: 'me', hard: 30, vertices: cube.vertices.map((v, i) => (i === 0 ? { ...v, tag: 'tip' } : v)), faces: cube.faces, extra: { a: 1 } };
  const m = M.setVertex(M.meshFromRaw(raw), 1, { x: 7 });
  const out = M.meshToRaw(raw, m);
  assert.deepEqual(Object.keys(out), Object.keys(raw));
  assert.equal(out.author, 'me');
  assert.deepEqual(out.extra, { a: 1 });
  assert.equal((out.vertices as M.MeshVertex[])[0].tag, 'tip');
  assert.equal((out.vertices as M.MeshVertex[])[1].x, 7);
  // converting a lofted file drops sections/caps
  const lofted = { name: 'l', caps: true, sections: [{ z: 0, points: [] }] };
  const conv = M.meshToRaw(lofted, cube);
  assert.ok(!('sections' in conv) && !('caps' in conv));
  assert.ok(agree('roundtrip', out));
});

// ── scenery: lines and occluders ────────────────────────────────────────

/**
 * Does the bundled compiler know "lines"/"occluders"? An older one ignores the
 * keys (serde) and refuses a scenery-only file; then the scenery cases are
 * unit checks only.
 */
const cliKnowsScenery = haveCli && cliAccepts('probe_scenery', { name: 'p', lines: [{ points: [{ x: 0, y: 0, z: 0 }, { x: 1, y: 0, z: 0 }] }] });
const agreeScene = (name: string, raw: unknown) => (cliKnowsScenery ? agree(name, raw) : errors(raw).length === 0);

const wall = { points: [{ x: -40000, y: 0, z: 5000 }, { x: 40000, y: 0, z: 5000 }, { x: 40000, y: 3000, z: 5000 }, { x: -40000, y: 3000, z: 5000 }] };

test('scenery-only meshes are valid; vertices/faces still go together', () => {
  assert.ok(agreeScene('lines_only', { name: 'room', hard: 45, lines: [{ points: wall.points, br: 70, closed: true }] }));
  assert.ok(agreeScene('occ_only', { name: 'room', occluders: [wall] }));
  assert.ok(agreeScene('cube_and_lines', { ...cubeRaw, lines: [{ points: wall.points.slice(0, 2) }], occluders: [wall] }));
  const tri = [{ x: 0, y: 10 }, { x: 9, y: -5 }, { x: -9, y: -5 }];
  assert.ok(agreeScene('loft_and_lines', { name: 't', sections: [{ z: -10, points: tri }, { z: 10, points: tri }], lines: [{ points: wall.points.slice(0, 2) }] }));
  assert.ok(!agree('empty_scenery', { name: 'x', lines: [], occluders: [] }));
  assert.equal(errors({ vertices: cube.vertices, faces: [], lines: [{ points: wall.points }] }).length, 1, 'vertices without faces is still an error');
});

test('scenery errors', () => {
  const base = { name: 'x' };
  const bad: [string, unknown][] = [
    ['one point', { ...base, lines: [{ points: [{ x: 0, y: 0, z: 0 }] }] }],
    ['br 0', { ...base, lines: [{ points: wall.points, br: 0 }] }],
    ['br 101', { ...base, lines: [{ points: wall.points, br: 101 }] }],
    ['br float', { ...base, lines: [{ points: wall.points, br: 50.5 }] }],
    ['closed number', { ...base, lines: [{ points: wall.points, closed: 1 }] }],
    ['fog string', { ...base, lines: [{ points: wall.points, fog: 'no' }] }],
    ['points not array', { ...base, lines: [{ points: 3 }] }],
    ['lines not array', { ...base, lines: {} }],
    ['line beyond 1e6', { ...base, lines: [{ points: [{ x: 1_000_001, y: 0, z: 0 }, { x: 0, y: 0, z: 0 }] }] }],
    ['float point', { ...base, lines: [{ points: [{ x: 0.5, y: 0, z: 0 }, { x: 0, y: 0, z: 0 }] }] }],
    ['occluder 2 points', { ...base, occluders: [{ points: wall.points.slice(0, 2) }] }],
    ['occluder 9 points', { ...base, occluders: [{ points: Array.from({ length: 9 }, (_, i) => ({ x: i, y: i * i, z: 0 })) }] }],
  ];
  for (const [what, raw] of bad) {
    const e = errors(raw);
    assert.ok(e.length > 0, `${what}: expected an error`);
    assert.ok(e.every((x) => x.line !== undefined || x.occluder !== undefined || /must be an array/.test(x.message)), `${what}: errors point at the item`);
    if (cliKnowsScenery) assert.ok(!agree(`scene_${what.replace(/\W+/g, '_')}`, raw));
  }
  // within range, and a vertex at 40000 is still an error
  assert.equal(errors({ ...base, lines: [{ points: [{ x: 1_000_000, y: -1_000_000, z: 0 }, { x: 0, y: 0, z: 0 }] }] }).length, 0);
  assert.ok(errors({ ...cubeRaw, vertices: cube.vertices.map((v, i) => (i ? v : { ...v, x: 40000 })), lines: [{ points: wall.points }] }).length > 0);
  // warnings: a line with no length, an occluder with no area
  assert.ok(warnings({ ...base, lines: [{ points: [{ x: 1, y: 1, z: 1 }, { x: 1, y: 1, z: 1 }] }] }).some((w) => w.line === 0));
  assert.ok(warnings({ ...base, occluders: [{ points: [{ x: 0, y: 0, z: 0 }, { x: 1, y: 1, z: 1 }, { x: 2, y: 2, z: 2 }] }] }).some((w) => w.occluder === 0));
});

test('scenery round-trip keeps unknown fields and key order; mesh edits keep the scenery', () => {
  const raw = {
    name: 'throne', note: 'keep', hard: 45, vertices: cube.vertices, faces: cube.faces,
    lines: [{ tag: 'rail', points: [{ x: 0, y: 0, z: 0, id: 'a' }, { x: 100, y: 0, z: 0 }], br: 70, closed: false, fog: false }],
    occluders: [{ points: wall.points, who: 'wall' }],
    tail: 1,
  };
  const sc = M.sceneryFromRaw(raw);
  assert.equal(sc.lines.length, 1);
  assert.equal(M.lineBr(sc.lines[0]), 70);
  assert.equal(M.lineClosed(sc.lines[0]), false);
  const out = M.sceneryToRaw(raw, sc);
  assert.deepEqual(JSON.parse(JSON.stringify(out)), JSON.parse(JSON.stringify(raw)), 'untouched scenery round-trips exactly');
  assert.deepEqual(Object.keys(out), Object.keys(raw));
  const moved = M.moveScenePoints(sc, [{ kind: 'line', item: 0, point: 1 }], { x: 5, y: 0, z: 0 });
  const out2 = M.sceneryToRaw(raw, moved) as typeof raw;
  assert.deepEqual(Object.keys(out2.lines[0]), ['tag', 'points', 'br', 'closed', 'fog']);
  assert.equal(out2.lines[0].points[1].x, 105);
  assert.equal(out2.lines[0].points[0].id, 'a');
  assert.equal(out2.occluders[0].who, 'wall');
  // a mesh edit keeps lines/occluders verbatim
  const meshEdit = M.meshToRaw(raw, M.setVertex(M.meshFromRaw(raw), 0, { x: 1 }));
  assert.deepEqual(meshEdit.lines, raw.lines);
  assert.deepEqual(meshEdit.occluders, raw.occluders);
  assert.deepEqual(Object.keys(meshEdit), Object.keys(raw));
  // a scenery-only file gets no empty vertices/faces from a mesh write
  const only = { name: 'r', lines: raw.lines };
  assert.ok(!('vertices' in M.meshToRaw(only, { vertices: [], faces: [] })));
  // removing every line drops the key
  assert.ok(!('lines' in M.sceneryToRaw(raw, { ...sc, lines: [] })));
});

test('scenery edits', () => {
  const empty: M.Scenery = { lines: [], occluders: [] };
  const r = M.addLine(empty, [{ x: 0, y: 0, z: 0 }, { x: 0, y: 0, z: 0 }, { x: 2_000_000, y: 0, z: 0 }], true);
  assert.ok('scenery' in r);
  const sc = (r as { scenery: M.Scenery }).scenery;
  assert.equal(sc.lines[0].points.length, 2, 'repeated point dropped');
  assert.equal(sc.lines[0].points[1].x, M.SCENE_MAX, 'clamped to the scenery range');
  assert.equal(sc.lines[0].closed, true);
  assert.ok('error' in M.addLine(empty, [{ x: 1, y: 1, z: 1 }, { x: 1, y: 1, z: 1 }]));
  // br: default omitted, null removes
  const b = M.setLineProps(sc, 0, { br: 40 });
  assert.equal(b.lines[0].br, 40);
  assert.ok(!('br' in M.setLineProps(b, 0, { br: null }).lines[0]));
  assert.ok(!('closed' in M.setLineProps({ lines: [{ points: sc.lines[0].points }], occluders: [] }, 0, { closed: false }).lines[0]));
  assert.equal(M.setLineProps(sc, 0, { closed: false }).lines[0].closed, false, 'a spelled-out key stays');
  // fog: default true, false is written, back to true removes the key
  assert.equal(M.lineFog(sc.lines[0]), true);
  const nf = M.setLineProps(sc, 0, { fog: false });
  assert.equal(nf.lines[0].fog, false);
  assert.equal(M.lineFog(nf.lines[0]), false);
  assert.ok(!('fog' in M.setLineProps(sc, 0, { fog: true }).lines[0]));
  assert.equal(M.setLineProps(nf, 0, { fog: true }).lines[0].fog, true, 'a spelled-out key stays');
  assert.deepEqual(errors({ name: 'f', lines: [{ points: nf.lines[0].points, fog: false }] }), []);
  // box occluders: full box = 8 corners, flat = 4 in order, a segment = none
  assert.equal(M.boxOccluder([0, 0, 0], [10, 20, 30])!.points.length, 8);
  const flat = M.boxOccluder([0, 0, 5], [10, 20, 5])!;
  assert.deepEqual(flat.points.map((p) => [p.x, p.y]), [[0, 0], [0, 20], [10, 20], [10, 0]]);
  assert.equal(M.boxOccluder([0, 0, 0], [10, 0, 0]), null);
  // deleting points: a line under 2 points and an occluder under 3 go
  const withOcc = M.addOccluder(sc, flat);
  const del = M.deleteScenePoints(withOcc, [{ kind: 'line', item: 0, point: 0 }, { kind: 'occ', item: 0, point: 0 }]);
  assert.equal(del.lines.length, 0);
  assert.equal(del.occluders[0].points.length, 3);
  const del2 = M.deleteScenePoints(withOcc, M.itemRefs(withOcc, 'occ', 0));
  assert.equal(del2.occluders.length, 0);
  assert.equal(del2.lines.length, 1);
  // bounds include scenery
  const bb = M.boundsOf(cube, withOcc)!;
  assert.equal(bb.hi[0], M.SCENE_MAX);
  assert.equal(M.boundsOf({ vertices: [], faces: [] }, empty), null);
  // the result validates
  const raw = M.sceneryToRaw({ name: 's' }, withOcc);
  assert.deepEqual(errors(raw), []);
  assert.equal(sc.lines[0].points.length, 2, 'operations do not mutate their input');
});

test('face_colors follow their faces through every edit', () => {
  const raw = { name: 'c', vertices: M.primitiveCube(1000).vertices, faces: M.primitiveCube(1000).faces,
    face_colors: ['#100000', '#200000', '#300000', '#400000', '#500000', '#600000'] };
  const m = M.meshFromRaw(raw);
  assert.equal(m.faceColors?.length, 6);
  // a split face: both halves keep the colour
  const f0 = m.faces[0];
  const split = M.connectVertices(m, f0[0], f0[2]);
  assert.ok('mesh' in split);
  const s1 = (split as { mesh: M.MeshData }).mesh;
  assert.equal(s1.faces.length, 7);
  assert.deepEqual(s1.faceColors!.slice(0, 2), ['#100000', '#100000']);
  // merged back: one face, the first one's colour, the rest untouched
  const merged = M.disconnectVertices(s1, f0[0], f0[2]);
  assert.ok('mesh' in merged);
  const s2 = (merged as { mesh: M.MeshData }).mesh;
  assert.deepEqual(s2.faceColors, m.faceColors);
  // deleting faces and vertices drops their colours
  const d = M.deleteFaces(m, [1, 3]);
  assert.deepEqual(d.faceColors, ['#100000', '#300000', '#500000', '#600000']);
  const dv = M.deleteVertices(m, [0]);
  assert.equal(dv.faceColors!.length, dv.faces.length);
  // a new face has none; written back, the array keeps its length, and a mesh
  // without colours writes none (a stale array never survives)
  const nf = M.makeFace(dv, [1, 2, 3]);
  assert.ok('mesh' in nf);
  const s3 = (nf as { mesh: M.MeshData }).mesh;
  assert.equal(s3.faceColors![s3.faceColors!.length - 1], null);
  const back = M.meshToRaw(raw, s3);
  assert.equal((back.face_colors as unknown[]).length, s3.faces.length);
  assert.equal('face_colors' in M.meshToRaw(raw, M.primitiveCube(1000)), false);
  assert.deepEqual(errors(back), []);
});

test('dissolveEdges merges a strip of faces into one, colours kept', () => {
  // a 1 x 4 strip of quads: vertices 0..9 in two columns (x 0 and 1000, y 0..4000)
  const vertices = [] as M.MeshVertex[];
  for (let r = 0; r <= 4; r++) { vertices.push({ x: 0, y: r * 1000, z: 0 }, { x: 1000, y: r * 1000, z: 0 }); }
  const faces = [0, 1, 2, 3].map((r) => [2 * r, 2 * r + 1, 2 * r + 3, 2 * r + 2]);
  const m: M.MeshData = { vertices, faces, faceColors: ['#a00000', '#b00000', '#c00000', '#d00000'] };
  const r = M.dissolveEdges(m, [[2, 3], [4, 5], [6, 7]]);
  assert.equal(r.merged, 3);
  assert.equal(r.skipped, 0);
  assert.equal(r.mesh.faces.length, 1);
  assert.equal(r.mesh.faces[0].length, 10);
  assert.deepEqual(r.mesh.faceColors, ['#a00000']);
  // a rim cannot be dissolved
  assert.equal(M.dissolveEdges(m, [[0, 1]]).skipped, 1);
});

rmSync(work, { recursive: true, force: true });
console.log(`\n${passed} passed${haveCli ? '' : ' (vpy_cli not found: compiler cross-check skipped)'}${haveCli && !cliKnowsScenery ? ' (vpy_cli predates lines/occluders: scenery cases not cross-checked)' : ''}`);
