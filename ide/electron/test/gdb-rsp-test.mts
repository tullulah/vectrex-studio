/**
 * Tests for the gdb packet framing (src/gdb/rsp.ts).
 *
 *   node test/gdb-rsp-test.mts           (node >= 22.18 strips the types)
 */
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';

// This package is CommonJS: rsp.ts is loaded as the ES module it is written as
const src = readFileSync(new URL('../src/gdb/rsp.ts', import.meta.url), 'utf8');
const { RspParser, encode } = await import('data:text/javascript,' + encodeURIComponent(stripTypeScriptTypes(src)));

let n = 0;
const t = (name: string, f: () => void) => { f(); n++; console.log(`  ok   ${name}`); };

t('encode: body, #, two-digit checksum', () => {
  assert.equal(encode('OK'), '$OK#9a');
  assert.equal(encode(''), '$#00');
});

t('encode escapes $ # } *', () => {
  assert.equal(encode('a#b'), '$a}\x03b#' + ((0x61 + 0x7d + 0x03 + 0x62) & 0xff).toString(16));
});

t('a packet split across reads, acks dropped', () => {
  const p = new RspParser();
  assert.deepEqual(p.feed('+$qSupp'), []);
  assert.deepEqual(p.feed('orted#37+'), [{ kind: 'packet', body: 'qSupported' }]);
});

t('several packets in one read; a bad checksum is reported', () => {
  const p = new RspParser();
  assert.deepEqual(p.feed('$g#67$m0,4#00'), [{ kind: 'packet', body: 'g' }, { kind: 'bad' }]);
});

t('Ctrl+C between packets is an interrupt; an escaped 0x03 inside one is data', () => {
  const p = new RspParser();
  assert.deepEqual(p.feed('\x03'), [{ kind: 'interrupt' }]);
  const body = 'X0,1:}\x03';
  const sum = [...body].reduce((c, ch) => (c + ch.charCodeAt(0)) & 0xff, 0).toString(16).padStart(2, '0');
  assert.deepEqual(p.feed(`$${body}#${sum}`), [{ kind: 'packet', body: 'X0,1:#' }]);
});

t('what encode writes, the parser reads back', () => {
  const p = new RspParser();
  const body = 'lthe $ and # and } and * survive';
  assert.deepEqual(p.feed(encode(body)), [{ kind: 'packet', body }]);
});

console.log(`${n} passed`);
