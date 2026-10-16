/**
 * Tests for the gdb remote protocol answers (src/debug/gdbStub.ts) on a fake target.
 *
 *   node tools/gdb-stub-test.ts            (node >= 22.18 strips the types)
 */
import assert from 'node:assert/strict';
import { GdbStub, TARGET_XML, type GdbTarget, type StopReason } from '../src/debug/gdbStub.ts';

const regs = new Uint32Array(17);
const mem = new Uint8Array(0x100);
const bps = new Set<number>();
let stop: StopReason | null = null;
let running = false;
const target: GdbTarget = {
  readReg: (n) => regs[n],
  writeReg: (n, v) => { regs[n] = v; },
  readMem: (a, l) => (a >= 0x1000 && a + l <= 0x1100 ? mem.slice(a - 0x1000, a - 0x1000 + l) : null),
  writeMem: (a, b) => { if (a < 0x1000 || a + b.length > 0x1100) return false; mem.set(b, a - 0x1000); return true; },
  addBreakpoint: (a) => bps.add(a),
  removeBreakpoint: (a) => bps.delete(a),
  clearBreakpoints: () => bps.clear(),
  step: () => { regs[15] += 2; stop = 'step'; },
  cont: () => { running = true; },
  halt: () => { running = false; stop = 'halt'; },
  takeStop: () => { const r = stop; stop = null; return r; },
  detach: () => { bps.clear(); running = true; },
};
const g = new GdbStub(target);

let n = 0;
const t = (name: string, f: () => void) => { f(); n++; console.log(`  ok   ${name}`); };

t('qSupported offers the target description and no-ack mode', () => {
  const r = g.handle('qSupported:multiprocess+;swbreak+')!;
  assert.match(r, /qXfer:features:read\+/);
  assert.match(r, /QStartNoAckMode\+/);
});

t('target.xml comes in chunks, m then l', () => {
  const a = g.handle('qXfer:features:read:target.xml:0,40')!;
  assert.equal(a[0], 'm');
  const rest = g.handle(`qXfer:features:read:target.xml:40,${(TARGET_XML.length).toString(16)}`)!;
  assert.equal(rest[0], 'l');
  assert.equal(a.slice(1) + rest.slice(1), TARGET_XML);
  assert.match(TARGET_XML, /org\.gnu\.gdb\.arm\.m-profile/);
  assert.equal((TARGET_XML.match(/<reg /g) || []).length, 17);
});

t('g: 17 registers, little-endian; p and P one at a time', () => {
  regs[0] = 0x12345678; regs[15] = 0x20000100; regs[16] = 0x01000000;
  const all = g.handle('g')!;
  assert.equal(all.length, 17 * 8);
  assert.equal(all.slice(0, 8), '78563412');
  assert.equal(all.slice(15 * 8, 16 * 8), '00010020');
  assert.equal(g.handle('p10'), '00000001');
  assert.equal(g.handle('P1=efbeadde'), 'OK');
  assert.equal(regs[1], 0xdeadbeef);
  assert.equal(g.handle('p11'), 'E01');
});

t('m and M read and write memory; outside it, an error', () => {
  assert.equal(g.handle('M1004,3:aabbcc'), 'OK');
  assert.equal(g.handle('m1003,5'), '00aabbcc00');
  assert.equal(g.handle('m40000000,4'), 'E14');
  assert.equal(g.handle('M40000000,1:00'), 'E14');
});

t('Z0/Z1 set breakpoints (Thumb bit dropped), z0 clears; watchpoints unsupported', () => {
  assert.equal(g.handle('Z0,20000101,2'), 'OK');
  assert.equal(g.handle('Z1,20000200,2'), 'OK');
  assert.deepEqual([...bps], [0x20000100, 0x20000200]);
  assert.equal(g.handle('z0,20000100,2'), 'OK');
  assert.deepEqual([...bps], [0x20000200]);
  assert.equal(g.handle('Z2,20000000,4'), '');
});

t('s answers at once with a stop at the new pc', () => {
  regs[15] = 0x20000100;
  assert.equal(g.handle('s'), 'T050f:02010020;thread:1;');
});

t('c answers later: poll gives nothing while running, then the stop', () => {
  assert.equal(g.handle('c'), null);
  assert.ok(running);
  assert.equal(g.poll(), null);
  regs[15] = 0x20000200; stop = 'breakpoint';
  assert.equal(g.poll(), 'T050f:00020020;thread:1;');
});

t('Ctrl+C halts with SIGINT', () => {
  g.handle('c');
  assert.equal(g.interrupt().slice(0, 3), 'T02');
  assert.ok(!running);
});

t('unknown packets get the empty reply; D detaches', () => {
  assert.equal(g.handle('vMustReplyEmpty'), '');
  assert.equal(g.handle('X1000,0:'), '');
  assert.equal(g.handle('D'), 'OK');
  assert.equal(bps.size, 0);
});

console.log(`${n} passed`);
