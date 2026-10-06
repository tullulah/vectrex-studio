#!/usr/bin/env python3
"""Recompose full Snow Bros sprites (players, enemies, bosses) from RAM dumps.

The Pandora chains multi-tile sprites through relative positioning: an entry
with byte3 bit2 clear places itself at (dx, dy) absolute; entries with bit2 set
add their (dx, dy) to the running position. One absolute entry plus the
relative entries that follow it is one on-screen object — that run is the
recomposition unit. dx/dy are 9-bit (byte3 bits 0/1 are the high bits),
sign-extended. Byte7: bit7 flip-X, bit6 flip-Y, bits 0-5 tile high; byte6 tile
low; byte3 high nibble palette.

Reads the sprites_*.bin / palette_*.bin dumps written by snowbros_dump.lua,
dedupes identical compositions across all dumps, and writes:

  sprites/frame_NNN.png        each unique composed frame, 1x, black background
  sprites_composed.png         labeled contact sheet of all frames, 3x

Usage: compose_sprites.py [--rom ...] [--dumps ...] [--out sprites/]
"""

import argparse
import sys
from pathlib import Path

# PIL is only needed for the rendering helpers below; parse_objects/normalize
# (imported by vec_to_sprites.py at build time) must work without it, so the
# import is lazy — the IDE's python3 has no Pillow and the build must not need it.
try:
    from PIL import Image, ImageDraw
except ImportError:
    Image = ImageDraw = None

from extract_sprites import decode_tile, load_palettes, load_tiles


def sext9(v: int) -> int:
    return v - 0x200 if v & 0x100 else v


def parse_objects(raw: bytes) -> list[list[tuple]]:
    """One dump -> list of objects; each object = [(relx, rely, tile, pal, fx, fy)]."""
    objects: list[list[tuple]] = []
    cur: list[tuple] = []
    bbox = [0, 0, 0, 0]  # minx, miny, maxx, maxy of cur's placed tiles

    def flush():
        nonlocal cur
        if cur:
            objects.append(cur)
        cur = []

    x = y = 0
    for off in range(0, len(raw) - 7, 8):
        entry = raw[off:off + 8]
        b3, dx, dy, b6, b7 = entry[3], entry[4], entry[5], entry[6], entry[7]
        if b3 & 1:
            dx |= 0x100
        if b3 & 2:
            dy |= 0x100
        if b3 & 4:
            x += sext9(dx)
            y += sext9(dy)
            # Games also chain SEPARATE objects relative to each other. A tile
            # of the same sprite lands touching the part already drawn (a
            # row-return step is large but lands right below) AND on the
            # object's own 16px tile grid; a moving neighbour chained in sits
            # at an arbitrary offset, so off-grid or detached = new object.
            if cur and ((x - cur[0][0]) % 16 or (y - cur[0][1]) % 16
                        or not (bbox[0] - 16 <= x <= bbox[2] + 16
                                and bbox[1] - 16 <= y <= bbox[3] + 16)):
                flush()
        else:
            flush()
            x, y = sext9(dx), sext9(dy)
        if entry == b"\x00" * 8:
            continue  # empty slot (still resets the running position)
        tile = (((b7 & 0x3F) << 8) | b6) % 4096
        if not cur:
            bbox = [x, y, x, y]
        else:
            bbox = [min(bbox[0], x), min(bbox[1], y), max(bbox[2], x), max(bbox[3], y)]
        cur.append((x, y, tile, b3 >> 4, bool(b7 & 0x80), bool(b7 & 0x40)))  # flipx=bit7, flipy=bit6
    flush()
    return objects


def normalize(obj: list[tuple]) -> tuple:
    """Shift tile positions to the top-left corner -> hashable dedupe key."""
    minx = min(t[0] for t in obj)
    miny = min(t[1] for t in obj)
    return tuple(sorted((x - minx, y - miny, *rest) for x, y, *rest in obj))


def render_object(obj: tuple, tiles, pals, scale: int) -> "Image.Image":
    w = max(t[0] for t in obj) + 16
    h = max(t[1] for t in obj) + 16
    img = Image.new("RGB", (w * scale, h * scale), (0, 0, 0))
    put = img.putpixel
    for ox, oy, tile, pal, fx, fy in obj:
        px = decode_tile(tiles[tile])
        colors = pals[pal]
        for y in range(16):
            for x in range(16):
                c = px[y * 16 + x]
                if c == 0:
                    continue  # transparent
                dx = 15 - x if fx else x
                dy = 15 - y if fy else y
                col = colors[c]
                for sy in range(scale):
                    for sx in range(scale):
                        put(((ox + dx) * scale + sx, (oy + dy) * scale + sy), col)
    return img


def main():
    ap = argparse.ArgumentParser()
    here = Path(__file__).resolve().parent.parent
    ap.add_argument("--rom", type=Path, default=here / "rom" / "snowbros.zip")
    ap.add_argument("--dumps", type=Path, default=Path.home() / "projects/mame/snowdump")
    ap.add_argument("--out", type=Path, default=here / "sprites")
    ap.add_argument("--max-tiles", type=int, default=64,
                    help="skip objects bigger than this many tiles")
    args = ap.parse_args()

    tiles = load_tiles(args.rom)
    pals = load_palettes(args.dumps)
    dumps = sorted(args.dumps.glob("sprites_*.bin"))
    if not dumps:
        sys.exit(f"no sprites_*.bin in {args.dumps}")

    blank = {i for i, t in enumerate(tiles) if not any(b & 0x0F or b & 0xF0 for b in t)}
    seen: dict[tuple, None] = {}
    for f in dumps:
        for obj in parse_objects(f.read_bytes()):
            obj = [t for t in obj if t[2] not in blank]
            if 1 <= len(obj) <= args.max_tiles:
                seen.setdefault(normalize(obj), None)
    frames = list(seen)
    print(f"{len(frames)} unique composed frames from {len(dumps)} dumps")

    args.out.mkdir(parents=True, exist_ok=True)
    # multi-tile frames first (the interesting ones), then by first tile code
    frames.sort(key=lambda o: (-len(o), o[0][2]))
    for i, obj in enumerate(frames):
        render_object(obj, tiles, pals, 1).save(args.out / f"frame_{i:03d}.png")

    # Contact sheet, 3x, labeled with frame number + first tile code.
    # Cell is capped at 64px of content; the rare bigger frame (text banners)
    # is scaled down to fit — the full-size version is its frame_*.png.
    scale, cols, pad, label_h, cap = 3, 12, 4, 10, 64
    cw, ch = cap * scale + pad, cap * scale + label_h + pad
    rows = (len(frames) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cw, rows * ch), (24, 24, 24))
    draw = ImageDraw.Draw(sheet)
    for i, obj in enumerate(frames):
        img = render_object(obj, tiles, pals, scale)
        if img.width > cap * scale or img.height > cap * scale:
            img.thumbnail((cap * scale, cap * scale), Image.NEAREST)
        x0, y0 = (i % cols) * cw + pad // 2, (i // cols) * ch + pad // 2
        sheet.paste(img, (x0, y0))
        draw.text((x0, y0 + cap * scale), f"{i:03d} t{obj[0][2]:04x}", fill=(180, 180, 180))
    sheet.save(args.out.parent / "sprites_composed.png")
    print(f"sprites_composed.png + {len(frames)} frame_*.png in {args.out}/")


if __name__ == "__main__":
    main()
