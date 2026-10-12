#!/usr/bin/env python3
"""snd_conv.py — YM3812 register logs (from snd_rip) -> PSG event streams.

Input:  build/snd/cmd_XX.log, lines "us reg val" (every write the real sound
        program made, see tools/snd_rip.c).
Output: src/sb_snddata.h — one compiled stream per sound in EXACTLY the format
        the SDK sequencers play (uvm2_audio.c / libvpy / rp2350 core-1 player):

          MUSIC: [u32 num_events][u32 loop event byte offset][events at +8]
          SFX:   [u32 num_events][events at +4]
          event: [delay, num_writes, (reg,val)*num_writes]
                 num_writes 0xFF -> loop (music only), 0x00 -> end
                 delay = frames to wait AFTER this event (first fires at once)

The conversion is a per-frame (50 Hz) resample: the arcade driver rewrites the
whole chip state every timer tick, so each frame we read the YM state, reduce
it to the PSG's 3 tone voices + noise, and emit only the registers that
changed.  What survives is what the ROM says: the notes, their timing, their
relative volumes, the drum pattern.  What is lost is FM timbre — the PSG plays
square waves, like every AY port of an FM arcade ever did.

MUSIC and SFX are converted by DIFFERENT ROUTES, and the reason is worth
stating because it looks like an inconsistency:

  MUSIC is read from the REGISTERS, per channel. It is polyphonic, and only
  the per-channel view can keep three voices apart. Reading the frequency
  straight off fnum/block is correct HERE because of what the tracks actually
  do: every melodic channel runs its modulator at MULT x1 or x2 with the
  carrier a small integer multiple, so the FM sidebands land on multiples of
  the channel frequency and the perceived fundamental IS that frequency.
  (Checked across both tracks: modMULT/carMULT are 1/1, 1/3 and 2/3.)

  SFX are MEASURED from the rendered audio (tools/snd_ref.cpp drives the real
  ymfm YM3812). They are monophonic — one channel, every time — so measuring
  is possible; and it is necessary, because their operators are nothing like
  the music's. The shot runs a MULT x12 carrier against a MULT x6 modulator
  with feedback 4: the spectrum is dense and inharmonic, and neither fnum nor
  any MULT arithmetic predicts what you hear. Measured, the shot is a 2.8 kHz
  -> 540 Hz downward sweep; computed from fnum it came out a flat 3.7 kHz
  squeal, which is exactly what it sounded like.

Frequencies: music, YM fnum/block -> Hz; SFX, measured by autocorrelation.
             Either way PSG period = 93750/Hz (PSG at 1.5 MHz).
Volumes:     music, carrier Total Level (0-63 att.) -> 15 - TL/4;
             SFX, measured RMS at 2 dB per PSG volume step.
Melody:      up to 3 simultaneous YM channels -> voices A,B,C; a fixed
             most-used-first channel map per track, then steal-the-released.
Rhythm:      BD key rising edges -> 2-frame noise burst mixed into voice C
             (tone C keeps playing; the mixer enables noise alongside).
SFX:         voice C ONLY (regs 4,5,6,7-Cbits,10) so the SDK sequencer can
             merge them over music without killing voices A/B, exactly like
             the .vsfx contract in uvm2_audio.c. A frame whose measured
             tonality is too low to be a pitch becomes NOISE instead of a
             tone, with its period from the spectral centroid — that is what
             an FM zap is, and a square wave is not it.
"""
import sys
from pathlib import Path
from collections import defaultdict

FRAME_US = 20000                 # 50 Hz, the tick rate every SDK sequencer runs at
PSG_CLOCK_DIV = 93750.0          # 1.5 MHz / 16
YM_SAMPLE = 3000000.0 / 72.0     # 41666.67 Hz at the board's 3 MHz

# YM3812 slot offset of each channel's two operators (mod+car)
SLOT = {ch: (0x00, 0x03) for ch in range(3)}
SLOT.update({ch: (0x05 + ch, 0x08 + ch) for ch in range(3, 6)})   # 3,4,5 -> 08/0B..
SLOT = {0: (0x00, 0x03), 1: (0x01, 0x04), 2: (0x02, 0x05),
        3: (0x08, 0x0B), 4: (0x09, 0x0C), 5: (0x0A, 0x0D),
        6: (0x10, 0x13), 7: (0x11, 0x14), 8: (0x12, 0x15)}

# noise periods per drum, brightest wins when several hit together
DRUM_NOISE = [(0x10, 0x1C), (0x08, 0x0D), (0x04, 0x12), (0x02, 0x05), (0x01, 0x03)]
# (BD, SD, TOM, CYM, HH) mask -> noise period


def read_frames(path):
    """Sample the YM register file at 50 Hz. Returns list of dict(reg->val)."""
    regs = {}
    frames = []
    t0 = None
    bd_edges = 0          # rhythm rising edges seen within the current frame
    bd_prev = 0
    cur = 0
    for line in open(path):
        us, r, v = line.split()
        us = int(us); r = int(r, 16); v = int(v, 16)
        if t0 is None:
            t0 = us
        f = (us - t0) // FRAME_US
        while f > cur:
            frames.append((dict(regs), bd_edges))
            bd_edges = 0
            cur += 1
        if r == 0xBD:
            bd_edges |= v & ~bd_prev & 0x1F
            bd_prev = v & 0x1F
        regs[r] = v
    frames.append((dict(regs), bd_edges))
    return frames


def ym_channel(regs, ch):
    """(keyed, psg_period, psg_vol) of one melodic YM channel this frame."""
    b = regs.get(0xB0 + ch, 0)
    keyed = bool(b & 0x20)
    fnum = regs.get(0xA0 + ch, 0) | ((b & 3) << 8)
    block = (b >> 2) & 7
    if fnum == 0:
        return (False, 0, 0)
    hz = fnum * YM_SAMPLE / (1 << (20 - block))
    if hz < 24:
        return (False, 0, 0)
    period = min(4095, max(1, round(PSG_CLOCK_DIV / hz)))
    mod, car = SLOT[ch]
    tl_car = regs.get(0x40 + car, 0x3F) & 0x3F
    if regs.get(0xC0 + ch, 0) & 1:            # additive: both ops sound
        tl_car = min(tl_car, regs.get(0x40 + mod, 0x3F) & 0x3F)
    vol = max(0, 15 - (tl_car >> 2))
    return (keyed, period, vol)


# ---- SFX: measure the real chip's output ----------------------------------

SND_REF = Path(__file__).resolve().parent.parent / 'build' / 'snd_ref'
TONALITY_MIN = 0.55        # below this an autocorrelation peak is not a pitch
PITCH_LO, PITCH_HI = 60, 4000
VOL_REF_RMS = 3000.0       # int16 RMS that maps to full PSG volume
VOL_DB_STEP = 2.0          # dB per PSG volume step


def render_reference(path):
    """Run the log through the real YM3812 and return (samples, rate)."""
    import subprocess
    import numpy as np
    if not SND_REF.exists():
        raise SystemExit(f'{SND_REF} missing — run `make snd_ref` first')
    out = subprocess.run([str(SND_REF), str(path), '-'],
                         capture_output=True, check=True).stdout
    rate = int.from_bytes(out[:4], 'little')
    return np.frombuffer(out[4:], dtype='<i2').astype(float), rate


def measure(path):
    """Per 20 ms frame of the real audio: (pitch_hz, tonality, rms, centroid)."""
    import numpy as np
    x, rate = render_reference(path)
    hop = int(rate * FRAME_US / 1e6)
    out = []
    for i in range(0, len(x) - hop, hop):
        fr = x[i:i + hop]
        rms = float(np.sqrt(np.mean(fr * fr)))
        if rms < 60:                            # silence
            out.append((0.0, 0.0, rms, 0.0))
            continue
        fr = fr - fr.mean()
        ac = np.correlate(fr, fr, 'full')[len(fr) - 1:]
        ac = ac / (ac[0] + 1e-9)
        lo, hi = int(rate / PITCH_HI), int(rate / PITCH_LO)
        k = lo + int(np.argmax(ac[lo:hi]))
        # spectral centroid, for picking a noise colour when there is no pitch
        sp = np.abs(np.fft.rfft(fr * np.hanning(len(fr))))
        fq = np.fft.rfftfreq(len(fr), 1.0 / rate)
        cen = float((sp * fq).sum() / (sp.sum() + 1e-9))
        out.append((rate / k, float(ac[k]), rms, cen))
    return out


def sfx_images(path):
    """PSG register images for one effect, measured from the real chip.

    Voice C only, so the SDK sequencer can merge the effect over the music."""
    import math
    imgs = []
    for pitch, tonality, rms, centroid in measure(path):
        img = [0] * 11
        img[7] = 0x3F                                   # everything off
        if rms >= 60:
            vol = 15 + int(round(20 * math.log10(rms / VOL_REF_RMS) / VOL_DB_STEP))
            vol = max(0, min(15, vol))
            if vol:
                img[10] = vol
                if tonality >= TONALITY_MIN and PITCH_LO <= pitch <= PITCH_HI:
                    per = max(1, min(4095, round(PSG_CLOCK_DIV / pitch)))
                    img[4] = per & 0xFF
                    img[5] = per >> 8
                    img[7] &= ~0x04                     # tone C on
                else:
                    # not a pitch: an FM zap is noise. The PSG noise divider is
                    # 5 bits; its frequency is 93750/period, so the centroid
                    # picks the colour (a bright hiss vs a low rumble).
                    npr = max(1, min(31, round(PSG_CLOCK_DIV / max(centroid, 3000))))
                    img[6] = npr
                    img[7] &= ~0x20                     # noise C on
        imgs.append(img)
    while imgs and imgs[-1][10] == 0:
        imgs.pop()
    # Closing silence. The mixer must be 0x3F — ALL DISABLED — not 0: a zero
    # mixer byte means every channel ENABLED, so an all-zeroes "silence" frame
    # actually hands the effect both C's tone and the noise on its way out.
    tail = [0] * 11
    tail[7] = 0x3F
    imgs.append(tail)
    return imgs


def convert(path, is_music):
    if not is_music:
        return encode(sfx_images(path), None, False)
    frames = read_frames(path)

    # channel usage census -> stable voice preference (most keyed first)
    use = defaultdict(int)
    for regs, _ in frames:
        for ch in range(6):
            if regs.get(0xB0 + ch, 0) & 0x20:
                use[ch] += 1
    pref = sorted(use, key=lambda c: -use[c])

    # per frame: PSG register image (0-10)
    #
    # MUSIC GETS VOICES A AND B ONLY. Voice C belongs to sound effects, and that
    # is not a style choice — it is the runtime contract every sequencer
    # implements: an SFX merges only the channel-C bits of the mixer
    # ((mixer & 0xDB) | (val & 0x24)) and MUTES register 10 when it ends. A
    # track that puts a voice on C therefore loses it to the next gunshot and
    # does not get it back until the track happens to rewrite that register.
    # Two voices plus noise is what the PSG really offers a game with sound.
    voice_of = {}                              # ym ch -> psg voice
    images = []
    noise_left = 0
    noise_vol = 0
    noise_per = 0x0D
    for regs, bd_edges in frames:
        state = [ym_channel(regs, ch) for ch in range(6)]
        active = [ch for ch in range(6) if state[ch][0] and state[ch][2] > 0]
        # keep existing assignments while their channel stays keyed
        voice_of = {ch: v for ch, v in voice_of.items() if ch in active}
        free = [v for v in range(2) if v not in voice_of.values()]
        for ch in sorted(active, key=lambda c: pref.index(c) if c in pref else 9):
            if ch in voice_of:
                continue
            if free:
                voice_of[ch] = free.pop(0)
        img = [0] * 11
        mixer = 0x3F
        for ch, v in voice_of.items():
            _, period, vol = state[ch]
            img[2 * v] = period & 0xFF
            img[2 * v + 1] = period >> 8
            img[8 + v] = vol
            mixer &= ~(1 << v)                 # tone on
        # rhythm -> noise burst on voice C
        if bd_edges:
            for mask, nper in DRUM_NOISE:
                if bd_edges & mask:
                    noise_left = 2
                    noise_vol = 12
                    noise_per = nper
                    break
        # The noise PERIOD is sticky: it is left at whatever the last drum set,
        # rather than reset between hits. The mixer bit is what makes noise
        # audible, so a silent voice's period is unobservable — and rewriting it
        # on every hit and release was, measured, 626 of 5947 writes in the
        # level theme for no audible difference.
        img[6] = noise_per
        if noise_left > 0:
            # Drums BORROW VOICE B, never C: noise routed to a channel shares
            # that channel's volume register, so putting it on C would collide
            # with effects exactly as a tone there would. B carries its note and
            # the drum together for the hit, which is how AY ports have always
            # done percussion.
            mixer &= ~0x10                     # noise on B
            img[9] = max(img[9], noise_vol)
            noise_vol = max(0, noise_vol - 6)
            noise_left -= 1
        img[7] = mixer
        images.append(img)

    loop_frame, images = find_loop(images)
    return encode(images, loop_frame, True)


def find_loop(images):
    """Detect the musical loop: smallest period with a long TOLERANT repeat.

    Tolerant, not verbatim: the driver's timer tick is not a multiple of our
    20 ms sampling frame, so on each pass a few notes land one frame earlier
    or later. Musically identical, byte-different — an exact match never
    fires (that is how the first version shipped 120 s of unrolled tune).
    93% frame-equality over a 4 s window is far above chance and far below
    the jitter."""
    sig = [tuple(i) for i in images]
    n = len(sig)
    W = 200                                    # 4 s window
    for start in (0, 50, 100, 250):
        if start + 2 * W >= n:
            break
        win = sig[start:start + W]
        for p in range(W, n - start - W):
            eq = sum(1 for i in range(W) if win[i] == sig[start + p + i])
            if eq >= W * 0.93:
                return start, images[:start + p]
    return 0, images                           # no loop found: loop everything


# EL CODIFICADOR VIVE EN LA SDK, no aqui. Estaba escrito en este fichero hasta que
# kuroishi necesito lo mismo desde una entrada distinta (notas propias en vez de
# registros del YM3812): lo que comparten no es la musica, es el formato. Ver la
# cabecera de psg_stream.py, que se llevo los comentarios porque se llevo el
# conocimiento.
_SDK = Path(__file__).resolve().parents[3] / 'ide/electron/resources/uvmc2-sdk/uvm2-sdk/tools'
sys.path.insert(0, str(_SDK))
from psg_stream import MUSIC_REGS, SFX_REGS, encode        # noqa: E402

def main():
    here = Path(__file__).resolve().parent.parent
    snd = here / 'build' / 'snd'
    # (cmd, name, music?). EVERY effect the ripper found is here — together
    # they are 2.6 KB, so there is no reason to guess which ones the game uses
    # and a command we left out is a silent moment nobody would think to look
    # for. Names are the command number where the moment is not yet known;
    # rename as they get identified in play.
    #
    # MUSIC IS NOT: a 58-second track is ~13 KB, and the ROM holds twelve of
    # them (254 KB, more than the whole 68000 program). Only the tracks the
    # port actually reaches are compiled in — the rest stay one converter run
    # away, in build/snd. Which is also why LEVEL is a per-track entry rather
    # than a loop over 0x22-0x2d.
    sounds = [
        (0x01, 'COIN',   False), (0x02, 'ATTRACT', False),
        (0x03, 'SFX03',  False), (0x04, 'SFX04',  False), (0x05, 'SFX05', False),
        (0x07, 'SFX07',  False), (0x08, 'SFX08',  False), (0x09, 'HIT09', False),
        (0x0a, 'SFX0A',  False), (0x0b, 'SFX0B',  False), (0x0c, 'HIT0C', False),
        (0x0d, 'HIT0D',  False), (0x10, 'SFX10',  False), (0x11, 'SFX11', False),
        (0x12, 'SFX12',  False), (0x13, 'SFX13',  False), (0x1b, 'SFX1B', False),
        (0x1c, 'JUMP',   False), (0x1d, 'SFX1D',  False), (0x1f, 'SHOT',  False),
        (0x20, 'START',  False), (0x21, 'CLEAR',  False), (0x2e, 'DEATH', False),
        (0x22, 'MUS22',  True),  (0x23, 'LEVEL',  True),
    ]
    hdr = []
    hdr.append('/* generated by tools/snd_conv.py — do not edit.')
    hdr.append(' * PSG event streams ripped from the arcade sound ROM (see snd_rip.c). */')
    table = []
    for cmd, name, is_music in sounds:
        log = snd / f'cmd_{cmd:02x}.log'
        if not log.exists():
            print(f'  [snd] missing {log}, skipped', file=sys.stderr)
            continue
        data = convert(log, is_music)
        rows = [', '.join(f'0x{b:02x}' for b in data[i:i+16]) for i in range(0, len(data), 16)]
        hdr.append(f'static const unsigned char SB_SND_{name}[{len(data)}] = {{')
        hdr.extend('    ' + r + ',' for r in rows)
        hdr[-1] = hdr[-1].rstrip(',')
        hdr.append('};')
        table.append((cmd, name, is_music))
        print(f'  [snd] cmd {cmd:02x} {name:6s} {"music" if is_music else "sfx  "} {len(data)} bytes')
    hdr.append('')
    hdr.append('static const struct { unsigned char cmd, is_music; const unsigned char *data; }')
    hdr.append('sb_snd_table[] = {')
    for cmd, name, is_music in table:
        hdr.append(f'    {{ 0x{cmd:02x}, {1 if is_music else 0}, SB_SND_{name} }},')
    hdr.append('};')
    hdr.append('')
    out = here / 'src' / 'sb_snddata.h'
    out.write_text('\n'.join(hdr) + '\n')
    print(f'  [snd] wrote {out}')


if __name__ == '__main__':
    main()
