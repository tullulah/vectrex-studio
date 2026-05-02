#!/usr/bin/env python3
"""Convert VGZ (compressed VGM with YM3812) files to MIDI."""

import gzip
import struct
import math
import os
from pathlib import Path


def fnum_to_midi(fnum, block):
    if fnum == 0:
        return None
    # OPL2 frequency formula
    freq = fnum * 49716.0 / (1 << (20 - block))
    if freq <= 0:
        return None
    note = round(69 + 12 * math.log2(freq / 440.0))
    return note if 0 <= note <= 127 else None


def var_len(n):
    result = [n & 0x7F]
    n >>= 7
    while n:
        result.insert(0, (n & 0x7F) | 0x80)
        n >>= 7
    return bytes(result)


def build_track(events):
    data = b''
    for delta, ev in events:
        data += var_len(delta) + ev
    data += var_len(0) + b'\xFF\x2F\x00'
    return b'MTrk' + struct.pack('>I', len(data)) + data


def write_midi(path, tracks, ticks_per_beat=480, tempo=500000):
    num_tracks = 1 + len(tracks)
    header = b'MThd' + struct.pack('>I', 6) + struct.pack('>HHH', 1, num_tracks, ticks_per_beat)
    tempo_track = build_track([(0, b'\xFF\x51\x03' + struct.pack('>I', tempo)[1:])])
    with open(path, 'wb') as f:
        f.write(header + tempo_track)
        for events in tracks:
            f.write(build_track(events))


def parse_vgm(data):
    if data[:4] != b'Vgm ':
        raise ValueError("Not a VGM file")

    version = struct.unpack_from('<I', data, 8)[0]

    if version >= 0x150:
        rel = struct.unpack_from('<I', data, 0x34)[0]
        data_offset = (0x34 + rel) if rel else 0x40
    else:
        data_offset = 0x40

    SAMPLE_RATE = 44100
    TICKS_PER_BEAT = 480
    TEMPO = 500000
    ticks_per_sample = TICKS_PER_BEAT * 1_000_000 / (TEMPO * SAMPLE_RATE)

    fnums = [0] * 9
    blocks = [0] * 9
    key_on = [False] * 9
    current_note = [None] * 9
    # tracks 0-8: melody channels (MIDI ch 0-8)
    # track 9: percussion (MIDI ch 9, GM drums)
    tracks = [[] for _ in range(10)]
    last_tick = [0] * 10
    sample = 0

    # OPL2 rhythm mode: register $BD
    # bit5=rhythm_on, bit4=bass, bit3=snare, bit2=tom, bit1=cymbal, bit0=hihat
    rhythm_mode = False
    rhythm_key_on = 0
    # GM drum notes for OPL2 rhythm instruments
    DRUM_NOTES = {
        4: 36,   # bass drum  → kick
        3: 38,   # snare drum → snare
        2: 45,   # tom-tom    → low tom
        1: 49,   # cymbal     → crash cymbal
        0: 42,   # hi-hat     → closed hi-hat
    }
    DRUM_TRACK = 9

    pos = data_offset
    while pos < len(data):
        cmd = data[pos]

        if cmd == 0x66:
            break
        elif cmd == 0x5A:  # YM3812 write
            reg, val = data[pos + 1], data[pos + 2]
            pos += 3
            if reg == 0xBD:  # Rhythm control register
                new_rhythm = bool(val & 0x20)
                new_bits = val & 0x1F
                tick = int(sample * ticks_per_sample)
                for bit, drum_note in DRUM_NOTES.items():
                    was_on = bool(rhythm_key_on & (1 << bit))
                    is_on = bool(new_bits & (1 << bit))
                    if is_on and not was_on:
                        delta = tick - last_tick[DRUM_TRACK]
                        last_tick[DRUM_TRACK] = tick
                        tracks[DRUM_TRACK].append((delta, bytes([0x99, drum_note, 100])))
                    elif not is_on and was_on:
                        delta = tick - last_tick[DRUM_TRACK]
                        last_tick[DRUM_TRACK] = tick
                        tracks[DRUM_TRACK].append((delta, bytes([0x89, drum_note, 0])))
                rhythm_mode = new_rhythm
                rhythm_key_on = new_bits
            elif 0xA0 <= reg <= 0xA8:
                ch = reg - 0xA0
                fnums[ch] = (fnums[ch] & 0x300) | val
            elif 0xB0 <= reg <= 0xB8:
                ch = reg - 0xB0
                # In rhythm mode, channels 6-8 are percussion — skip melody tracking
                if rhythm_mode and ch >= 6:
                    pass
                else:
                    blocks[ch] = (val >> 2) & 0x7
                    fnums[ch] = ((val & 0x3) << 8) | (fnums[ch] & 0xFF)
                    new_key = bool(val & 0x20)
                    tick = int(sample * ticks_per_sample)

                    if new_key and not key_on[ch]:
                        note = fnum_to_midi(fnums[ch], blocks[ch])
                        if note is not None:
                            delta = tick - last_tick[ch]
                            last_tick[ch] = tick
                            tracks[ch].append((delta, bytes([0x90 | (ch % 9), note, 100])))
                            current_note[ch] = note
                    elif not new_key and key_on[ch] and current_note[ch] is not None:
                        delta = tick - last_tick[ch]
                        last_tick[ch] = tick
                        tracks[ch].append((delta, bytes([0x80 | (ch % 9), current_note[ch], 0])))
                        current_note[ch] = None

                    key_on[ch] = new_key
        elif cmd == 0x61:
            sample += struct.unpack_from('<H', data, pos + 1)[0]
            pos += 3
        elif cmd == 0x62:
            sample += 735
            pos += 1
        elif cmd == 0x63:
            sample += 882
            pos += 1
        elif 0x70 <= cmd <= 0x7F:
            sample += (cmd & 0x0F) + 1
            pos += 1
        elif cmd == 0x67:  # data block
            size = struct.unpack_from('<I', data, pos + 3)[0]
            pos += 7 + size
        elif cmd in (0x4F, 0x50):
            pos += 2
        elif 0x51 <= cmd <= 0x5F and cmd != 0x5A:
            pos += 3
        elif 0x30 <= cmd <= 0x4E:
            pos += 2
        elif 0x80 <= cmd <= 0x8F:
            sample += cmd & 0x0F
            pos += 1
        elif cmd == 0x90:
            pos += 5
        elif cmd == 0x91:
            pos += 5
        elif cmd == 0x92:
            pos += 6
        elif cmd == 0x93:
            pos += 11
        elif cmd == 0x94:
            pos += 4
        elif cmd == 0x95:
            pos += 5
        else:
            pos += 1

    return [t for t in tracks if t]


def convert(vgz_path, midi_path):
    with gzip.open(vgz_path, 'rb') as f:
        data = f.read()
    tracks = parse_vgm(data)
    if not tracks:
        print(f"  [!] No note events found in {os.path.basename(vgz_path)}")
        return
    write_midi(midi_path, tracks)
    total_notes = sum(len([e for e in t if e[1][0] & 0xF0 == 0x90]) for t in tracks)
    print(f"  {os.path.basename(vgz_path)} → {os.path.basename(midi_path)}  ({len(tracks)} channels, {total_notes} notes)")


if __name__ == '__main__':
    music_dir = Path(__file__).parent / 'assets' / 'music'
    for vgz in sorted(music_dir.glob('*.vgz')):
        convert(str(vgz), str(vgz.with_suffix('.mid')))
    print("Done.")
