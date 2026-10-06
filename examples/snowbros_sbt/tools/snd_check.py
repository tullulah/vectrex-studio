#!/usr/bin/env python3
"""snd_check.py — play a compiled stream from src/sb_snddata.h the way the SDK
does, to verify the bytes before they ever reach a console.

This is a line-by-line port of uvm2_audio.c's music_tick/sfx_tick (the same
sequencer as libvpy and the rp2350 core-1 player), so anything it reports —
timing, notes, a stream that runs off its end — is what the hardware would do.

  snd_check.py                 list every stream with duration + note count
  snd_check.py LEVEL           notes of one stream, as frames/pitch/volume
  snd_check.py LEVEL --wav out.wav   render it to audio with a square-wave PSG
  snd_check.py SHOT --vs 1f   our pitch track next to the REAL chip's, frame
                              by frame (needs `make snd_ref`). The check to
                              run after touching the converter.
  snd_check.py --session snd.log --wav out.wav
                               mix a WHOLE GAMEPLAY SESSION: feed it the
                               `SB_TRACE_SND=1` log from the host harness and
                               it plays the streams the cartridge would play,
                               at the frames the game asked for them. This is
                               the end-to-end check of the chain 68000 ->
                               latch -> command -> PSG stream.
"""
import re
import sys
import math
import struct
import wave
from pathlib import Path

HDR = Path(__file__).resolve().parent.parent / 'src' / 'sb_snddata.h'
PSG_CLOCK = 1500000.0 / 16.0
NOTE = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']


def load():
    text = HDR.read_text()
    out = {}
    for m in re.finditer(r'SB_SND_(\w+)\[\d+\]\s*=\s*\{(.*?)\};', text, re.S):
        name, body = m.group(1), m.group(2)
        out[name] = bytes(int(b, 16) for b in re.findall(r'0x([0-9a-fA-F]{2})', body))
    music = set(re.findall(r'\{\s*0x[0-9a-f]{2},\s*1,\s*SB_SND_(\w+)\s*\}', text))
    return out, music


def load_table():
    """cmd -> (name, is_music), straight from the generated table."""
    text = HDR.read_text()
    return {int(c, 16): (n, bool(int(m)))
            for c, m, n in re.findall(
                r'\{\s*0x([0-9a-f]{2}),\s*(\d),\s*SB_SND_(\w+)\s*\}', text)}


class Seq:
    """uvm2_audio.c, in Python. regs[] is the PSG register file."""

    def __init__(self, data, is_music):
        self.d = data
        self.music = is_music
        self.base = 0
        self.ptr = 8 if is_music else 4
        self.delay = 0
        self.primed = not is_music      # music spends one priming frame
        self.playing = True
        self.regs = [0] * 14
        self.regs[7] = 0x3F

    def tick(self):
        if not self.playing:
            return
        if not self.primed:
            self.primed = True
            return
        if self.delay > 0:
            self.delay -= 1
            return
        p = self.ptr
        nw = self.d[p + 1]
        if nw == 0x00:
            self.playing = False
            for r in (8, 9, 10):
                self.regs[r] = 0
            self.regs[7] = 0x3F
            return
        if nw == 0xFF:
            if not self.music:
                raise AssertionError('loop marker in an SFX stream')
            self.ptr = struct.unpack_from('<I', self.d, 4)[0]
            if self.ptr >= len(self.d):
                raise AssertionError(f'loop offset {self.ptr} past end {len(self.d)}')
            self.delay = self.d[self.ptr]
            return
        w = p + 2
        for _ in range(nw):
            reg, val = self.d[w], self.d[w + 1]
            if reg > 13:
                raise AssertionError(f'register {reg} does not exist on the PSG')
            self.regs[reg] = val
            w += 2
        if w + 1 >= len(self.d):
            raise AssertionError(f'stream runs off its end at byte {w}')
        self.ptr = w
        self.delay = self.d[w]

    def voices(self):
        """(hz, vol) per tone voice that is actually audible this frame."""
        out = []
        for v in range(3):
            per = self.regs[2 * v] | ((self.regs[2 * v + 1] & 0x0F) << 8)
            vol = self.regs[8 + v] & 0x0F
            tone_on = not (self.regs[7] >> v) & 1
            out.append((PSG_CLOCK / per if per else 0.0,
                        vol if (tone_on and per) else 0))
        return out

    def noise(self):
        per = self.regs[6] & 0x1F
        on = [v for v in range(3) if not (self.regs[7] >> (3 + v)) & 1]
        vol = max((self.regs[8 + v] & 0x0F) for v in on) if on else 0
        return (PSG_CLOCK / (per * 2) if per else 0.0), vol


def name_of(hz):
    """Note name from a frequency. A4 = 440 Hz is MIDI 69, and the octave is
    n//12 - 1 — with 57 instead of 69 every name came out an octave flat,
    which made correct conversions look wrong."""
    if hz < 20:
        return '---'
    n = round(12 * math.log2(hz / 440.0)) + 69
    return f'{NOTE[n % 12]}{n // 12 - 1}'


def run(data, is_music, frames):
    s = Seq(data, is_music)
    log = []
    for f in range(frames):
        s.tick()
        if not s.playing:
            break
        log.append((f, s.voices(), s.noise()))
    return s, log


class Mixer:
    """Music + SFX sharing one PSG, merged exactly as the SDK does: an effect
    owns channel C and contributes only the C bits of the mixer, so it plays
    OVER the music instead of cutting it (uvm2_audio.c sfx_tick)."""

    def __init__(self):
        self.mus = None
        self.sfx = None
        self.regs = [0] * 14
        self.regs[7] = 0x3F

    def play(self, data, is_music):
        if is_music:
            self.mus = Seq(data, True)
            self.mus.regs = self.regs        # share the register file
        else:
            self.sfx = Seq(data, False)
            self.sfx.regs = self.regs

    def stop_music(self):
        self.mus = None
        for r in (8, 9, 10):
            self.regs[r] = 0
        self.regs[7] = 0x3F

    def tick(self):
        # The merge runs BOTH ways, as the sequencers do: the effect keeps the
        # music's A/B bits, and the music keeps the effect's C bits. One-way
        # was the bug — a track with noise percussion writes the mixer on every
        # drum hit and took channel C back from the effect mid-flight.
        cbits = self.regs[7] & 0x24
        if self.mus:
            self.mus.tick()
            if self.sfx:
                self.regs[7] = (self.regs[7] & 0xDB) | cbits
            if not self.mus.playing:
                self.mus = None
        if self.sfx:
            keep = self.regs[7]
            self.sfx.tick()
            self.regs[7] = (keep & 0xDB) | (self.regs[7] & 0x24)
            if not self.sfx.playing:
                self.sfx = None
                self.regs[7] |= 0x24
        v = Seq.voices(self)
        return v, Seq.noise(self)

    playing = True


def render(path, frames, source):
    """source(frame) -> ((hz,vol)*3, (noise_hz,noise_vol)) or None to stop."""
    RATE = 22050
    spf = RATE // 50
    phase = [0.0, 0.0, 0.0]
    nz = 1
    samples = bytearray()
    for f in range(frames):
        got = source(f)
        if got is None:
            break
        vs, (nhz, nvol) = got
        for i in range(spf):
            acc = 0
            for v in range(3):
                hz, vol = vs[v]
                if vol and hz > 20:
                    phase[v] += hz / RATE
                    acc += (vol * 700) * (1 if (phase[v] % 1.0) < 0.5 else -1)
            if nvol and nhz > 20:
                nz = ((nz >> 1) ^ (0x14000 if nz & 1 else 0)) & 0x1FFFF
                acc += (nvol * 500) * (1 if nz & 1 else -1)
            acc = max(-32000, min(32000, acc))
            samples += struct.pack('<h', acc)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(samples))
    print(f'wrote {path}: {len(samples)//2/RATE:.1f} s')


def source_stream(data, is_music):
    s = Seq(data, is_music)

    def src(_f):
        s.tick()
        return None if not s.playing else (s.voices(), s.noise())
    return src


def source_session(log, streams, table, machine_hz=57.5):
    """Replay a SB_TRACE_SND log: at the frame the game sent each command, play
    what the cartridge would. The log counts MACHINE frames (57.5 Hz, the
    board's refresh) while the sequencer ticks per DRAWN frame (50 Hz), so the
    frame numbers are rescaled — otherwise the session would run 15% fast."""
    cues = {}
    for line in open(log):
        m = re.match(r'SND f(\d+) cmd ([0-9a-f]{2})', line.strip())
        if not m:
            continue
        f = round(int(m.group(1)) * 50.0 / machine_hz)
        cues.setdefault(f, []).append(int(m.group(2), 16))
    mix = Mixer()
    print(f'session: {sum(len(v) for v in cues.values())} commands '
          f'over {max(cues, default=0)/50:.1f} s')

    def src(f):
        for cmd in cues.get(f, ()):
            if cmd == 0xfe:
                mix.stop_music()
            elif cmd in table:
                name, is_music = table[cmd]
                mix.play(streams[name], is_music)
        return mix.tick()
    return src


def compare(name, cmd, streams, music_names):
    """Does our PSG version follow the real chip? Prints both pitch tracks.

    The arcade's own output is rendered by tools/snd_ref (ymfm YM3812) and
    measured the same way the converter measures it; ours is played through the
    sequencer above. Timbre cannot match — three square waves are not nine FM
    operators — but the PITCH and the ENVELOPE must, and when they do not it is
    a converter bug, not a limit of the hardware."""
    import subprocess
    import numpy as np
    ref_bin = HDR.parent.parent / 'build' / 'snd_ref'
    log = HDR.parent.parent / 'build' / 'snd' / f'cmd_{cmd:02x}.log'
    if not ref_bin.exists() or not log.exists():
        print(f'need {ref_bin} and {log} — run `make snd_ref` and the ripper')
        return
    raw = subprocess.run([str(ref_bin), str(log), '-'],
                         capture_output=True, check=True).stdout
    rate = int.from_bytes(raw[:4], 'little')
    x = np.frombuffer(raw[4:], dtype='<i2').astype(float)
    hop = int(rate * 0.02)

    s = Seq(streams[name], name in music_names)
    print(f'{"frame":>5} {"ARCADE (ymfm YM3812)":>28} {"OURS (PSG)":>26}')
    for f in range(40):
        fr = x[f * hop:(f + 1) * hop]
        if len(fr) < hop:
            break
        rms = float(np.sqrt(np.mean(fr * fr)))
        if rms < 60:
            ref = f'{"silent":>18}'
        else:
            d = fr - fr.mean()
            ac = np.correlate(d, d, 'full')[len(d) - 1:]
            ac = ac / (ac[0] + 1e-9)
            lo, hi = int(rate / 4000), int(rate / 60)
            k = lo + int(np.argmax(ac[lo:hi]))
            ref = f'{name_of(rate/k):>4s} {rate/k:7.1f}Hz t{ac[k]:.2f}'
        s.tick()
        if not s.playing:
            ours = f'{"ended":>18}'
        else:
            vs = s.voices()
            nhz, nvol = s.noise()
            hz, vol = max(vs, key=lambda v: v[1])
            if vol:
                ours = f'{name_of(hz):>4s} {hz:7.1f}Hz v{vol:2d}'
            elif nvol:
                ours = f'{"noise":>4s} {nhz:7.1f}Hz v{nvol:2d}'
            else:
                ours = f'{"silent":>18}'
        print(f'{f:5d} {ref:>28} {ours:>26}')


def writes_of(data, is_music):
    """Every (reg, val) a stream performs, following its events."""
    p = 8 if is_music else 4
    out = []
    while p + 1 < len(data):
        nw = data[p + 1]
        if nw in (0x00, 0xFF):
            break
        for i in range(nw):
            out.append((data[p + 2 + 2 * i], data[p + 3 + 2 * i]))
        p += 2 + 2 * nw
    return out


def check_channels(streams, music_names):
    """Music owns voices A and B, effects own voice C. Verify it on the bytes.

    This is the contract the sequencers implement — an effect merges only the
    channel-C bits of the mixer and mutes register 10 when it ends — so a track
    that touches C loses that voice to the next gunshot and does not get it
    back. Enforced on the WRITES, not just the mixer: a music stream setting C's
    volume to zero silences an effect just as effectively as claiming it."""
    bad = 0
    for name, data in sorted(streams.items()):
        is_music = name in music_names
        ws = writes_of(data, is_music)
        if is_music:
            stray = sorted({r for r, _ in ws} & {4, 5, 10})
            mixers = [v for r, v in ws if r == 7]
            claims = [v for v in mixers if not (v & 0x04) or not (v & 0x20)]
        else:
            stray = sorted({r for r, _ in ws} & {0, 1, 2, 3, 8, 9})
            mixers = [v for r, v in ws if r == 7]
            claims = [v for v in mixers if not (v & 0x03) or not (v & 0x18)]
        if stray or claims:
            bad += 1
            who = "music" if is_music else "sfx"
            print(f'  {name:8s} ({who}) VIOLATES: '
                  + (f'writes {stray} ' if stray else '')
                  + (f'mixer claims {[f"{v:02x}" for v in claims]}' if claims else ''))
    print(f'channel split: {len(streams) - bad}/{len(streams)} streams clean'
          + ('' if bad else '  — music on A+B+noise, effects on C'))
    return bad


def opt(flag):
    """Value after --flag on the command line, or None."""
    return sys.argv[sys.argv.index(flag) + 1] if flag in sys.argv else None


def main():
    streams, music_names = load()
    argv = sys.argv[1:]
    args = []
    skip = False
    for i, a in enumerate(argv):
        if skip:
            skip = False
        elif a.startswith('--'):
            skip = a in ('--wav', '--session')
        else:
            args.append(a)

    cmp_to = opt('--vs')
    if cmp_to:
        name = args[0].upper() if args else 'SHOT'
        if name not in streams:
            print(f'no stream {name}; have: {", ".join(streams)}')
            return 1
        compare(name, int(cmp_to, 16), streams, music_names)
        return

    session = opt('--session')
    if session:
        wav = opt('--wav') or 'session.wav'
        frames = int(args[0]) if args else 6000
        render(wav, frames, source_session(session, streams, load_table()))
        return

    if not args:
        print(f'{"name":8s} {"kind":6s} {"bytes":>6s} {"frames":>7s} {"notes":>6s}')
        for name, data in streams.items():
            is_music = name in music_names
            s, log = run(data, is_music, 4000)
            notes = 0
            prev = [0, 0, 0]
            for _, vs, _ in log:
                for v in range(3):
                    hz = round(vs[v][0])
                    if hz != prev[v] and vs[v][1]:
                        notes += 1
                    prev[v] = hz
            print(f'{name:8s} {"music" if is_music else "sfx":6s} '
                  f'{len(data):6d} {len(log):7d} {notes:6d}')
        print()
        return 1 if check_channels(streams, music_names) else 0

    name = args[0].upper()
    if name not in streams:
        print(f'no stream {name}; have: {", ".join(streams)}')
        return 1
    data, is_music = streams[name], name in music_names
    frames = int(args[1]) if len(args) > 1 else (3000 if is_music else 200)

    wav = opt('--wav')
    if wav:
        render(wav, frames, source_stream(data, is_music))
        return

    s, log = run(data, is_music, frames)
    prev = None
    for f, vs, (nhz, nvol) in log:
        row = tuple((name_of(h) if vol else '---', vol) for h, vol in vs)
        if row != prev:
            cells = '  '.join(f'{n:>4s}:{v:2d}' for n, v in row)
            print(f'{f:5d} ({f/50:6.2f}s)  {cells}   noise {nvol:2d}')
            prev = row
    print(f'-- {len(log)} frames ({len(log)/50:.1f} s), '
          f'{"looped" if s.playing else "ended"}')


if __name__ == '__main__':
    sys.exit(main() or 0)
