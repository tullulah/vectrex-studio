# audio2vsmp — Vectrex voice / sampled audio

Converts an audio track into a `.vsmp` file: low-rate **4-bit PCM** ready to
stream to the Vectrex PSG's volume register.

## Why 4-bit PCM

The Vectrex AY-3-8912 PSG has no audio DAC — only square-wave tone/noise. Voice
(as in the game *Spike*) is done by **abusing the 4-bit per-channel VOLUME
register as a crude DAC**: mute the tone/noise, then write volume values (0-15)
at the sample rate. Rough — "suena mal pero suena" — but recognizable.

So `.vsmp` is just packed 4-bit / low-rate PCM. Quality is intentionally crude;
the format matches what the hardware can actually stream.

## The `.vsmp` format

```json
{
  "version": "1.0",
  "name": "…",
  "sampleRate": 8000,
  "bits": 4,
  "numSamples": N,
  "data": "<base64 of packed 4-bit samples, 2 per byte, low nibble = even sample>"
}
```

## Use

```bash
python3 audio2vsmp.py IN.(mp3|mov|wav|…) OUT.vsmp [options]
```

| Option | Meaning |
|--------|---------|
| `--rate HZ` | sample rate (default 8000; lower = smaller + easier to stream, rougher) |
| `--normalize` | scale to peak amplitude (louder, better use of the 4 bits) |
| `--preview OUT.wav` | **also write a .wav of the 4-bit result — open it to HEAR the quality on your computer before touching hardware** |
| `--name` | sample name (default: from output filename) |

### Example (Bad Apple audio)

```bash
python3 audio2vsmp.py badapple.mov badapple.vsmp \
  --rate 8000 --normalize --preview badapple_4bit.wav
open badapple_4bit.wav   # listen: this is what the Vectrex will sound like
```

Rate/size tradeoff (full 3.6 min song): 6 kHz ≈ 640 KB (rougher), 8 kHz ≈ 856 KB,
11025 ≈ 1.2 MB (cleaner but a faster stream). All fit the cart's 8 MB flash.

## Status & what's next

- ✅ **Format + converter + offline preview** (this tool).
- ⏳ **Player** — a BIOS routine that streams the samples to PSG volume at the
  sample rate. On the RP2350 this can run on core 1 (owns the bus) and slot
  sample writes into the ramp dead-time between vectors, so voice + vectors can
  play concurrently — the hard scheduling problem, done alongside the
  retained-mode render engine (see docs/RP2350_BIOS.md). Needs hardware.
- Quality refinements (later): the PSG volume steps are **logarithmic**, so a
  linear→log amplitude map would reduce distortion; and the compiler needs a
  `.vsmp` asset type + a `PLAY_SAMPLE` builtin.
