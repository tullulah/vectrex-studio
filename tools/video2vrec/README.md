# video2vrec — vectorize a video for the Vectrex

Converts a raster video (mp4/gif/…) into a Vectrex `.vrec` vector recording that
plays back on hardware / in the Vectrex Studio emulator via the
`DRAW_RECORDING(name, x, y, scale, frame)` VPy builtin.

Because a vector display draws **lines**, not pixels, the tool traces the
**contours** of each frame and simplifies them to fit the Vectrex per-frame
vector budget. This works best on high-contrast, clean-outline content:

- **Bad Apple** and other shadow-art / binary clips → `--mode silhouette`
- **Flash cartoons** (e.g. *The Demented Cartoon Movie*) with black outlines →
  `--mode edges` (Flash art is vector-native, so its ink outlines vectorize
  cleanly)

## Setup (one-time)

```bash
cd tools/video2vrec
python3 -m venv .venv
.venv/bin/pip install numpy opencv-python-headless
# ffmpeg must be on PATH (brew install ffmpeg)
```

## Use

```bash
.venv/bin/python video2vrec.py INPUT.mp4 OUT.vrec [options]
```

Key options:

| Option | Meaning |
|--------|---------|
| `--mode silhouette\|edges` | silhouette = filled shapes (Bad Apple); edges = dark line-art (Flash) |
| `--fps N` | playback/capture rate (default 15; the Vectrex won't do 30 with many vectors) |
| `--threshold 0-255` | black/white cutoff (tune per source) |
| `--invert` | flip which side is "ink" |
| `--epsilon PX` | RDP simplify strength — **the main quality/budget knob** (higher = fewer vertices) |
| `--budget N` | max segments per frame (Vectrex vector budget, default 200) |
| `--min-area PX²` | drop contours smaller than this (kills noise) |
| `--intensity 0-127` | beam brightness |
| `--max-frames N` | limit frames (for quick tests) |

### Bad Apple

```bash
.venv/bin/python video2vrec.py bad_apple.mp4 bad_apple.vrec \
  --mode silhouette --fps 15 --threshold 128 --epsilon 2.5 --budget 200
```

### The Demented Cartoon Movie (or any Flash cartoon)

```bash
.venv/bin/python video2vrec.py tdcm.mp4 tdcm.vrec \
  --mode edges --fps 12 --threshold 60 --epsilon 2 --budget 250
```

Watch the printed `segs/frame`: if `max` hits the budget, raise `--epsilon`
(simplify harder) or `--budget` (if the Vectrex can draw more). Aim for an
average the hardware can sustain (start ~150–250; the variable-T1 draw model
raises what's possible — see docs/RP2350_BIOS.md).

## Play it

1. Copy the `.vrec` to a project's `assets/recordings/` (e.g.
   `examples/vrec_player/assets/recordings/clip.vrec`).
2. Build for the **rp2350** target and run — `examples/vrec_player` plays a
   full-screen `clip.vrec` on a loop.

## Limitations / future

- `edges` traces the OUTLINE of the ink strokes (both sides of each black line),
  which doubles thin lines. A centerline/skeleton pass would trace each stroke
  once — a worthwhile refinement for line-art.
- No temporal coherence yet (each frame traced independently → some vertex
  "swim"). Frame-to-frame contour matching would steady it.
- No beam-path sorting yet (segments are drawn largest-contour-first). The
  retained-mode engine's chaining/sort will make playback more efficient.
