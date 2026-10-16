/**
 * gdb remote serial protocol framing: `$body#cs` packets, `+`/`-` acks, and the
 * Ctrl+C byte (0x03) gdb sends between packets to stop a running target.
 *
 * Pure (no sockets): feed() takes what arrived and returns what it held; encode()
 * builds a reply packet. Tested by ide/electron/test/gdb-rsp-test.ts.
 */

export type RspEvent =
  | { kind: 'packet'; body: string }
  | { kind: 'interrupt' }
  | { kind: 'bad' }; // checksum mismatch: answer '-' so gdb resends

const checksum = (s: string) => {
  let c = 0;
  for (let i = 0; i < s.length; i++) c = (c + s.charCodeAt(i)) & 0xff;
  return c;
};

/** `$`, `#`, `}` and `*` inside a body are sent as `}` + (byte ^ 0x20). */
export function encode(body: string): string {
  const esc = body.replace(/[$#}*]/g, (ch) => '}' + String.fromCharCode(ch.charCodeAt(0) ^ 0x20));
  return `$${esc}#${checksum(esc).toString(16).padStart(2, '0')}`;
}

function unescape(s: string): string {
  return s.replace(/\}([\s\S])/g, (_, ch: string) => String.fromCharCode(ch.charCodeAt(0) ^ 0x20));
}

export class RspParser {
  private buf = '';

  /** Bytes in (as latin1), events out. */
  feed(data: string): RspEvent[] {
    this.buf += data;
    const out: RspEvent[] = [];
    for (;;) {
      // Between packets: acks are dropped, Ctrl+C is an event, noise is skipped
      let i = 0;
      while (i < this.buf.length && this.buf[i] !== '$') {
        if (this.buf.charCodeAt(i) === 0x03) out.push({ kind: 'interrupt' });
        i++;
      }
      this.buf = this.buf.slice(i);
      if (!this.buf.length) return out;
      const hash = this.buf.indexOf('#'); // never escaped inside a body
      if (hash < 0 || hash + 3 > this.buf.length) return out; // incomplete
      const raw = this.buf.slice(1, hash);
      const sum = parseInt(this.buf.slice(hash + 1, hash + 3), 16);
      this.buf = this.buf.slice(hash + 3);
      out.push(sum === checksum(raw) ? { kind: 'packet', body: unescape(raw) } : { kind: 'bad' });
    }
  }
}
