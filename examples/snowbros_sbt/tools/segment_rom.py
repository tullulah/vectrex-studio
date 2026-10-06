#!/usr/bin/env python3
"""Auto-segment a ROM tile region into sprite frames by edge continuity.

Sprites are consecutive-tile runs laid out row-major, but frame sizes vary
(2x2 bats, 6x4 dragons, 7x4 boss faces...). For a candidate frame (base, w, h)
every internal edge is scored by how well adjacent tile borders continue into
each other (opaque meets opaque, transparent meets transparent); dynamic
programming then picks the segmentation of the whole region that maximizes
total score. Frames are rendered with the same palette logic as compose_rom.

Usage: segment_rom.py --start 0xeda --end 0xff2 [--pal 10] [--out seg/]
"""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

from extract_sprites import decode_tile, load_palettes, load_tiles, GRAY
from compose_rom import build_pal_map, render_grid

CANDIDATES = [(w, h) for w in range(2, 8) for h in range(2, 8) if w * h <= 42]


def edge_score_h(a, b):
    """a's right column vs b's left column, 0..1."""
    s = 0.0
    for r in range(16):
        av, bv = a[r * 16 + 15], b[r * 16]
        if (av > 0) == (bv > 0):
            s += 1.0 if av > 0 else 0.6
    return s / 16


def edge_score_v(a, b):
    """a's bottom row vs b's top row, 0..1."""
    s = 0.0
    for c in range(16):
        av, bv = a[15 * 16 + c], b[c]
        if (av > 0) == (bv > 0):
            s += 1.0 if av > 0 else 0.6
    return s / 16


def main():
    ap = argparse.ArgumentParser()
    here = Path(__file__).resolve().parent.parent
    ap.add_argument("--rom", type=Path, default=here / "rom" / "snowbros.zip")
    ap.add_argument("--dumps", type=Path, default=Path.home() / "projects/mame/snowdump")
    ap.add_argument("--start", type=lambda v: int(v, 0), required=True)
    ap.add_argument("--end", type=lambda v: int(v, 0), required=True)
    ap.add_argument("--pal", type=int, help="force attract palette slot")
    ap.add_argument("--min-score", type=float, default=0.62,
                    help="mean edge score below this can't justify a frame")
    ap.add_argument("--out", type=Path, default=here / "rom_sheets")
    args = ap.parse_args()

    tiles = load_tiles(args.rom)
    px = {t: decode_tile(tiles[t]) for t in range(args.start, min(args.end + 1, len(tiles)))}
    pals = load_palettes(args.dumps) if args.dumps.is_dir() else [GRAY] * 16
    pal_map = build_pal_map(args.dumps, len(tiles)) if args.dumps.is_dir() else [None] * len(tiles)

    blank = {t for t, p in px.items() if not any(p)}
    N = args.end + 1 - args.start

    def frame_score(base, w, h):
        n = w * h
        if base + n > args.end + 1:
            return None
        codes = [base + i for i in range(n)]
        if all(c in blank for c in codes):
            return None
        # corner-blank tiles are fine (round sprites); an all-blank edge
        # column/row means the frame is too wide/tall — reject it so a
        # tighter fit wins
        if all(base + gy * w + (w - 1) in blank for gy in range(h)):
            return None
        if all(base + (h - 1) * w + gx in blank for gx in range(w)):
            return None
        total, edges = 0.0, 0
        for gy in range(h):
            for gx in range(w):
                t = px[base + gy * w + gx]
                if gx + 1 < w:
                    total += edge_score_h(t, px[base + gy * w + gx + 1]); edges += 1
                if gy + 1 < h:
                    total += edge_score_v(t, px[base + (gy + 1) * w + gx]); edges += 1
        return total / edges if edges else 0.0

    # dp[i] = (best value, chosen (w,h) or None) for region tail starting at tile i
    INF = float("-inf")
    dp = [(0.0, None)] * (N + 1)
    for i in range(N - 1, -1, -1):
        base = args.start + i
        best, choice = dp[i + 1][0] - 0.05, None  # skip one tile, tiny penalty
        for w, h in CANDIDATES:
            n = w * h
            if i + n > N:
                continue
            sc = frame_score(base, w, h)
            if sc is None or sc < args.min_score:
                continue
            val = (sc - args.min_score) * n + dp[i + n][0]
            if val > best:
                best, choice = val, (w, h)
        dp[i] = (best, choice)

    frames = []
    i = 0
    while i < N:
        choice = dp[i][1]
        if choice is None:
            i += 1
            continue
        w, h = choice
        frames.append((args.start + i, w, h))
        i += w * h
    print(f"{len(frames)} frames segmented in {args.start:04x}-{args.end:04x}")

    args.out.mkdir(parents=True, exist_ok=True)
    frames_dir = args.out / f"seg_{args.start:04x}"
    frames_dir.mkdir(exist_ok=True)
    scale, gap, label_h = 2, 8, 12
    imgs = []
    for base, w, h in frames:
        order = list(range(base, base + w * h))
        img = render_grid(tiles, pals, pal_map, order, w, scale, 999, args.pal)
        img.save(frames_dir / f"{base:04x}_{w}x{h}.png")
        imgs.append((f"{base:04x} {w}x{h}", img))
    cols = 8
    cw = max(im.width for _, im in imgs) + gap
    ch = max(im.height for _, im in imgs) + label_h + gap
    rows = (len(imgs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cw, rows * ch), (40, 40, 40))
    d = ImageDraw.Draw(sheet)
    for i, (label, im) in enumerate(imgs):
        x, y = (i % cols) * cw, (i // cols) * ch
        sheet.paste(im, (x, y + label_h))
        d.text((x, y + 1), label, fill=(255, 255, 0))
    name = f"segmented_{args.start:04x}_{args.end:04x}.png"
    sheet.save(args.out / name)
    print(args.out / name, sheet.size)


if __name__ == "__main__":
    main()
