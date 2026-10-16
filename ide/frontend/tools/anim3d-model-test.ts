/**
 * Tests for the 3D Animation editor's model (src/components/anim3d/animModel.ts).
 *
 *   node tools/anim3d-model-test.ts            (node >= 22.18 strips the types)
 *
 * Besides the cases worked out by hand, the forward kinematics is checked against the SDK's
 * own vpybone (vpy-c/vpybone.c, compiled on the host with cc): the same skeleton, the same
 * joint angles, every joint position within a few units (vpybone is Q14 fixed point). Set
 * VPY_C_SDK to an SDK's vpy-c folder; without it (or without cc) the cross-check is skipped.
 */
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, readdirSync, writeFileSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import path from 'node:path';
import * as A from '../src/components/anim3d/animModel.ts';

let passed = 0;
const test = (name: string, fn: () => void) => {
  try { fn(); passed++; console.log(`ok   ${name}`); }
  catch (e) { console.error(`FAIL ${name}\n${(e as Error).stack}`); process.exitCode = 1; }
};
const near = (a: number[], b: number[], tol: number, what = '') => {
  for (let k = 0; k < a.length; k++) assert.ok(Math.abs(a[k] - b[k]) <= tol, `${what} [${a.map((x) => x.toFixed(1))}] vs [${b.map((x) => x.toFixed(1))}]`);
};

// a little figure: hips, a torso turned by twist (y) and lean (x), an arm with a roll (z)
// and a pitch (x), a forearm, a head that turns back half the twist
const SKEL: A.VskelRaw = {
  version: 1, angle_unit: 4096,
  joints: [{ name: 'twist' }, { name: 'lean' }, { name: 'sh_pitch' }, { name: 'sh_roll' }, { name: 'elbow' }],
  bones: [
    { name: 'hips', parent: null, offset: [0, 950, 0], mesh: 'hips', rotate: [] },
    { name: 'torso', parent: 'hips', offset: [0, 0, 0], mesh: 'torso', rotate: [{ joint: 'twist', axis: 'y' }, { joint: 'lean', axis: 'x' }] },
    { name: 'head', parent: 'torso', offset: [0, 680, 0], mesh: 'head', rotate: [{ joint: 'twist', axis: 'y', mul: -1, div: 2 }] },
    { name: 'arm', parent: 'torso', offset: [420, 600, 0], mesh: 'limb', rotate: [{ joint: 'sh_roll', axis: 'z' }, { joint: 'sh_pitch', axis: 'x' }] },
    { name: 'fore', parent: 'arm', offset: [0, -450, 0], mesh: 'limb', rotate: [{ joint: 'elbow', axis: 'x', mul: 3, div: 4 }] },
    { name: 'hand', parent: 'fore', offset: [0, -450, 0], mesh: null, rotate: [] },
  ],
  sockets: [{ name: 'blade', bone: 'hand', from: [0, 0, 0], to: [0, -1200, 0] }],
  variants: {
    small: { scale: 128, meshes: { head: 'other' }, offsets: { head: [0, 640, 0] } },
    four: { bones: [{ name: 'arm2', parent: 'torso', offset: [380, 330, 0], mesh: 'limb', rotate: [{ axis: 'z', add: 284 }] }], rotate: { hand: [{ axis: 'x', add: 682 }] } },
  },
};
const MESHES = new Set(['hips', 'torso', 'head', 'limb', 'other']);
const meshExists = (n: string) => MESHES.has(n);
const Q = 1024;     // a quarter turn

test('the skeleton validates', () => {
  assert.deepEqual(A.validateVskel(SKEL, meshExists), []);
});

test('skeleton errors: parents, joints, meshes, variants', () => {
  const bad = structuredClone(SKEL) as A.VskelRaw;
  bad.bones[2].parent = 'arm';                                   // listed after
  bad.bones[3].rotate = [{ joint: 'nope', axis: 'x' }, { axis: 'w' as A.Axis, joint: 'lean' }, { axis: 'x', joint: 'lean', div: 0 }];
  bad.bones[4].mesh = 'missing';
  bad.variants!.small.meshes = { nobone: 'head' };
  bad.variants!.four.scale = 0;
  bad.sockets = [{ name: 'blade', bone: 'tail', from: [0, 0, 0], to: [0, 0, 1] }];
  const m = A.validateVskel(bad, meshExists).map((i) => i.message).join('\n');
  for (const s of ['parent "arm" must be a bone listed before', 'no joint "nope"', 'needs an axis', 'div cannot be 0',
    'no mesh "missing"', 'no bone "nobone"', 'scale must be a whole number above 0', 'socket "blade": no bone "tail"']) {
    assert.ok(m.includes(s), `missing: ${s}\n${m}`);
  }
});

test('turns compute as C does (truncating toward zero)', () => {
  assert.equal(A.turnAngle({ axis: 'y', joint: 't', mul: -1, div: 2 }, { t: 7 }), -3);
  assert.equal(A.turnAngle({ axis: 'y', joint: 't', mul: -1, div: 2 }, { t: -7 }), 3);
  assert.equal(A.turnAngle({ axis: 'x', joint: 't', mul: 3, div: 4, add: -284 }, { t: -101 }), -75 - 284);
  assert.equal(A.turnAngle({ axis: 'x', add: 682 }, {}), 682);
});

test('a variant: scale, meshes, offsets, extra bones, rotations', () => {
  const r = A.resolve(SKEL, 'small');
  assert.deepEqual(r.bones[0].offset, [0, 475, 0]);
  assert.deepEqual(r.bones[2].offset, [0, 320, 0]);             // its own offset, scaled
  assert.equal(r.bones[2].mesh, 'other');
  assert.deepEqual(r.bones[3].offset, [210, 300, 0]);
  const f = A.resolve(SKEL, 'four');
  assert.equal(f.bones.length, 7);
  assert.equal(f.bones[6].parent, 1);
  assert.deepEqual(f.bones[5].rotate, [{ axis: 'x', add: 682 }]);
  const neg = A.resolve({ ...SKEL, variants: { v: { scale: 249 } } }, 'v');
  assert.deepEqual(neg.bones[4].offset, [0, -437, 0]);            // -450 * 249 / 256 = -437.7: toward zero
});

test('axes: +x swings a hanging limb forward, +y turns +z to +x, +z turns +x to +y', () => {
  const r = A.resolve(SKEL, null);
  const rest = A.pose(r, A.restPose(r.joints));
  near(rest.bones[5].pos, [420, 950 + 600 - 900, 0], 1e-6, 'hand at rest');
  const fwd = A.pose(r, { ...A.restPose(r.joints), sh_pitch: Q });   // arm straight out ahead
  near(fwd.bones[4].pos, [420, 1550, 450], 1e-6, 'elbow forward');
  const out = A.pose(r, { ...A.restPose(r.joints), sh_roll: Q });    // the arm's -y turned by +z: towards +x
  near(out.bones[4].pos, [420 + 450, 1550, 0], 1e-6, 'elbow out to +x');
  const tw = A.pose(r, { ...A.restPose(r.joints), twist: Q });       // the shoulder at +x turns to -z
  near(tw.bones[3].pos, [0, 1550, -420], 1e-6, 'shoulder after a twist');
});

test('turns compose in order, the first outermost', () => {
  const r = A.resolve(SKEL, null);
  // roll then pitch: the pitch swings the arm forward in the rolled frame
  const p = A.pose(r, { ...A.restPose(r.joints), sh_roll: Q, sh_pitch: Q });
  near(p.bones[4].pos, [420, 1550, 450], 1e-6, 'pitch first, then the roll turns the forward arm about z');
});

test('sockets and meshes scale with the character', () => {
  const r = A.resolve(SKEL, 'small');
  const p = A.pose(r, A.restPose(r.joints));
  const tip = A.boneToWorld(p, 5, [0, -1200, 0]);
  near(tip, [210, 475 + 300 - 225 - 225 - 600, 0], 1e-6, 'blade tip');
});

test('clips: validation', () => {
  const c: A.VclipRaw = {
    version: 1, skeleton: 'fig',
    poses: { a: { twist: 0, lean: 0, sh_pitch: 0, sh_roll: 0, elbow: 0 }, b: { twist: 100, lean: 0, sh_pitch: 0, sh_roll: 0 } },
    clips: { go: { keys: [{ frame: 0, pose: 'a' }, { frame: 0, pose: 'b' }, { frame: 4, pose: 'zz' }], marks: [{ frame: 9, name: 'hit' }], props: { d: 1.5 } } },
    sets: { s: { clips: { slash: 'gone' }, poses: { guard: 'a' } } },
  };
  const m = A.validateVclip(c, SKEL.joints.map((j) => j.name)).map((i) => i.message).join('\n');
  for (const s of ['pose "b" has no angle for "elbow"', 'must come after frame 0', 'no pose "zz"', 'mark "hit" must fall on the clip', 'd must be a whole number', 'no clip "gone"']) {
    assert.ok(m.includes(s), `missing: ${s}\n${m}`);
  }
});

const LIB: A.VclipRaw = {
  version: 1, skeleton: 'fig',
  poses: { g: { twist: 0, lean: 0 }, w: { twist: 400, lean: -100 }, s: { twist: -200, lean: 300 } },
  clips: { cut: { keys: [{ frame: 0, pose: 'g' }, { frame: 4, pose: 'w' }, { frame: 8, pose: 's' }, { frame: 12, pose: 'g' }], props: { damage: 1 }, marks: [{ frame: 4, name: 'strike' }] } },
  sets: { me: { poses: { guard: 'g' }, clips: { slash: 'cut' }, props: { combo: 30 } } },
};

test('clips: sampling between keys, holding at the ends, looping', () => {
  const J = ['twist', 'lean'];
  assert.deepEqual(A.sampleClip(LIB, LIB.clips.cut, 2, J), { twist: 200, lean: -50 });
  assert.deepEqual(A.sampleClip(LIB, LIB.clips.cut, 6, J), { twist: 100, lean: 100 });
  assert.deepEqual(A.sampleClip(LIB, LIB.clips.cut, 99, J), { twist: 0, lean: 0 });
  const loop = { ...LIB.clips.cut, loop: true };
  assert.deepEqual(A.sampleClip(LIB, loop, 14, J), A.sampleClip(LIB, loop, 2, J));
});

test('renaming a pose renames it in the clips and the sets; deleting a used one is refused', () => {
  const r = A.renamePose(LIB, 'g', 'guard');
  assert.ok('raw' in r);
  if (!('raw' in r)) return;
  assert.deepEqual(Object.keys(r.raw.poses), ['guard', 'w', 's']);
  assert.equal(r.raw.clips.cut.keys[0].pose, 'guard');
  assert.equal(r.raw.clips.cut.keys[3].pose, 'guard');
  assert.equal(r.raw.sets.me.poses!.guard, 'guard');
  const d = A.deletePose(r.raw, 'w');
  assert.ok('error' in d && d.error.includes('clip cut'));
  assert.ok('error' in A.renamePose(LIB, 'g', 'w'));
  assert.ok('error' in A.renamePose(LIB, 'g', '9bad'));
});

test('renaming a clip renames it in the sets; deleting a used one is refused', () => {
  const r = A.renameClip(LIB, 'cut', 'slash_a');
  assert.ok('raw' in r && r.raw.sets.me.clips!.slash === 'slash_a');
  assert.ok('error' in A.deleteClip(LIB, 'cut'));
});

test('keys: move within neighbours, put, delete', () => {
  const c = LIB.clips.cut;
  const m = A.moveKey(c, 1, 6);
  assert.ok(!('error' in m) && m.keys[1].frame === 6);
  assert.ok('error' in A.moveKey(c, 1, 8));
  const p = A.putKey(c, 10, 'w');
  assert.deepEqual(p.keys.map((k) => k.frame), [0, 4, 8, 10, 12]);
  const end = A.moveKey(c, 3, 16);
  assert.ok(!('error' in end) && end.keys[3].frame === 16);
  const d = A.deleteKey(c, 3);
  assert.ok(!('error' in d) && A.clipLength(d) === 8);
  assert.ok('error' in A.deleteKey({ keys: [{ frame: 0, pose: 'g' }] }, 0));
});

test('skeleton edits: renaming a bone or a joint follows it everywhere; deleting a used one is refused', () => {
  const r = A.renameBone(SKEL, 'hand', 'grip');
  assert.ok('raw' in r);
  if (!('raw' in r)) return;
  assert.equal(r.raw.sockets![0].bone, 'grip');
  assert.ok('grip' in r.raw.variants!.four.rotate!);
  const a = A.renameBone(SKEL, 'arm', 'upper');
  assert.ok('raw' in a && a.raw.bones[4].parent === 'upper');
  assert.ok('error' in A.renameBone(SKEL, 'arm', 'torso'));
  assert.ok('error' in A.deleteBone(SKEL, 'arm'));                     // the forearm hangs from it
  assert.ok('error' in A.deleteBone(SKEL, 'hips'));                    // the root
  const j = A.renameJoint(SKEL, 'twist', 'yaw');
  assert.ok('raw' in j && j.raw.bones[2].rotate![0].joint === 'yaw' && j.raw.joints[0].name === 'yaw');
  assert.ok('error' in A.deleteJoint(SKEL, 'lean'));
  const k = A.deleteJoint({ ...SKEL, joints: [...SKEL.joints, { name: 'spare' }] }, 'spare');
  assert.ok('raw' in k && k.raw.joints.length === SKEL.joints.length);
  assert.equal(A.freshName('pose', ['pose', 'pose_2']), 'pose_3');
  assert.deepEqual(A.validateVskel((r as { raw: A.VskelRaw }).raw, meshExists), []);
});

// ── the cross-check: vpybone, the SDK's own forward kinematics ─────────────────
function sdkDir(): string | null {
  if (process.env.VPY_C_SDK) return existsSync(path.join(process.env.VPY_C_SDK, 'vpybone.c')) ? process.env.VPY_C_SDK : null;
  const root = path.join(homedir(), 'VectrexStudio', 'sdk');
  if (!existsSync(root)) return null;
  const v = readdirSync(root).filter((d) => existsSync(path.join(root, d, 'vpy-c', 'vpybone.c'))).sort().pop();
  return v ? path.join(root, v, 'vpy-c') : null;
}

test('forward kinematics agrees with vpybone', () => {
  const sdk = sdkDir();
  if (!sdk) { console.log('     (skipped: no SDK with vpy-c/vpybone.c; set VPY_C_SDK)'); return; }
  const work = mkdtempSync(path.join(tmpdir(), 'anim3d-test-'));
  const cases: { variant: string | null; angles: A.Pose }[] = [];
  let seed = 7;
  const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return (seed % 4001) - 2000; };
  for (const variant of [null, 'small', 'four']) for (let k = 0; k < 4; k++) {
    cases.push({ variant, angles: Object.fromEntries(SKEL.joints.map((j) => [j.name, rnd()])) });
  }
  // the C side: each case's skeleton through vpyb_add, its rotations from vpyb_quat_axis
  // (x negated: vpybone turns +y towards +z, the format a hanging -y towards +z)
  const lines: string[] = [];
  cases.forEach((c, ci) => {
    const r = A.resolve(SKEL, c.variant);
    lines.push(`  vpyb_init(&S);`);
    r.bones.forEach((b) => lines.push(`  vpyb_add(&S, ${b.parent}, ${b.offset.join(', ')}, 0);`));
    r.bones.forEach((b, i) => {
      let q = 'vpyb_quat_identity()';
      for (const t of b.rotate) {
        const a = A.turnAngle(t, c.angles);
        const ax = t.axis === 'x' ? `1000, 0, 0, ${-a}` : t.axis === 'y' ? `0, 1000, 0, ${a}` : `0, 0, 1000, ${a}`;
        q = `mul(${q}, vpyb_quat_axis(${ax}))`;
      }
      lines.push(`  S.rot[${i}] = ${q};`);
    });
    lines.push(`  vpyb_pose(&S, O, vpyb_quat_identity());`);
    lines.push(`  for (int i = 0; i < S.n; i++) printf("${ci} %d %d %d %d\\n", i, (int)S.pos[i][0], (int)S.pos[i][1], (int)S.pos[i][2]);`);
  });
  const prog = `#include <stdio.h>
#include "vpybone.h"
unsigned char currentButtonState; signed char currentJoy1X, currentJoy1Y, currentJoy2X, currentJoy2Y;
void v_WaitRecal(void){} void v_directDraw32(int a,int b,int c,int d,int e){} void v_init(void){}
void v_readButtons(void){} void v_readJoystick1Analog(void){} void v_setRefresh(int r){} void v_writePSG(int a,int b){}
int vectrexinit(int a){return 0;}
static vpyb_quat mul(vpyb_quat a, vpyb_quat b) {
  vpyb_quat r;
  r.w = (a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z) >> 14;
  r.x = (a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y) >> 14;
  r.y = (a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x) >> 14;
  r.z = (a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w) >> 14;
  return r;
}
int main(void) {
  static vpyb_skeleton S; int32_t O[3] = { 0, 0, 0 };
${lines.join('\n')}
  return 0;
}
`;
  const src = path.join(work, 'fk.c'), exe = path.join(work, 'fk');
  writeFileSync(src, prog);
  try {
    execFileSync('cc', ['-w', '-I', path.join(sdk, 'include'), '-I', sdk, '-I', path.join(sdk, '..', 'pitrex-sim', 'include'), src,
      ...['vpybone.c', 'vpyik.c', 'vpy3d.c', 'vpy.c'].map((f) => path.join(sdk, f)), '-o', exe], { stdio: 'pipe' });
  } catch (e) {
    console.log(`     (skipped: the SDK does not build on the host: ${String((e as { stderr?: Buffer }).stderr ?? e).slice(0, 200)})`);
    return;
  }
  const out = execFileSync(exe, { encoding: 'utf-8' }).trim().split('\n').map((l) => l.split(' ').map(Number));
  let worst = 0;
  for (const [ci, i, x, y, z] of out) {
    const c = cases[ci];
    const mine = A.pose(A.resolve(SKEL, c.variant), c.angles).bones[i].pos;
    worst = Math.max(worst, Math.abs(mine[0] - x), Math.abs(mine[1] - y), Math.abs(mine[2] - z));
    near(mine, [x, y, z], 8, `case ${ci} bone ${i}`);
  }
  console.log(`     (${out.length} joints, worst difference ${worst.toFixed(2)} units: vpybone is Q14)`);
});

console.log(`\n${passed} passed${process.exitCode ? ', some FAILED' : ''}`);
