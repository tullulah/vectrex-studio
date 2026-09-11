#!/usr/bin/env python3
"""Compose Snow Bros sprites statically from the ROM — no gameplay needed.

Sprites are stored as runs of consecutive tiles in row-major order (learned
from the attract captures: a 32x32 frame is tiles t..t+3 as TL,TR,BL,BR; a
player 32x48 frame is t..t+5; the level-1 boss is 5x7 = 35 consecutive tiles).
So wrapping the whole gfx ROM at a given tile width reassembles every sprite of
that width — bosses and enemies the attract never showed included. Alignment
varies, so if a sprite looks shifted by one cell, re-run with --offset.

Colors: exact palette for tiles seen in the attract RAM dumps, else the
palette of the nearest seen tile (neighbours in ROM share palettes) — a guess,
good enough for tracing.

Modes:
  --strip W        whole ROM wrapped W tiles wide (paged into columns)
  --base N --width W --height H   one sprite/frame cut at tile N (hex ok)
  --pal P          force palette 0-15 (default: auto)

Examples:
  compose_rom.py --strip 2                    # players, enemies, balls
  compose_rom.py --strip 5                    # bosses
  compose_rom.py --base 0x800 --width 5 --height 7
"""

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw

from extract_sprites import decode_tile, load_palettes, load_tiles, GRAY


def build_pal_map(dump_dir: Path, n_tiles: int) -> list[int | None]:
    """tile -> palette: exact where seen in sprite RAM, else nearest seen."""
    from extract_sprites import used_tile_palettes
    used = used_tile_palettes(dump_dir)
    exact: dict[int, int] = {t: min(ps) for t, ps in used.items()}
    out: list[int | None] = [None] * n_tiles
    seen = sorted(exact)
    if not seen:
        return out
    for t in range(n_tiles):
        nearest = min(seen, key=lambda s: abs(s - t))
        out[t] = exact[nearest]
    return out


def render_grid(tiles, pals, pal_map, order, cols, scale, label_every, force_pal=None):
    """Render tile codes `order` wrapped at `cols`, labels in a left gutter."""
    gutter = 34
    rows = (len(order) + cols - 1) // cols
    img = Image.new("RGB", (gutter + cols * 16 * scale, rows * 16 * scale), (24, 24, 24))
    draw = ImageDraw.Draw(img)
    put = img.putpixel
    for i, t in enumerate(order):
        cx, cy = i % cols, i // cols
        x0, y0 = gutter + cx * 16 * scale, cy * 16 * scale
        pal = force_pal if force_pal is not None else pal_map[t]
        colors = GRAY if pal is None else pals[pal]
        px = decode_tile(tiles[t])
        for y in range(16):
            for x in range(16):
                c = colors[px[y * 16 + x]]
                for sy in range(scale):
                    for sx in range(scale):
                        put((x0 + x * scale + sx, y0 + y * scale + sy), c)
        if cx == 0 and cy % label_every == 0:
            draw.text((1, y0 + 1), f"{t:04x}", fill=(150, 150, 90))
    return img


def main():
    ap = argparse.ArgumentParser()
    here = Path(__file__).resolve().parent.parent
    ap.add_argument("--rom", type=Path, default=here / "rom" / "snowbros.zip")
    ap.add_argument("--dumps", type=Path, default=Path.home() / "projects/mame/snowdump")
    ap.add_argument("--out", type=Path, default=here / "rom_sheets")
    ap.add_argument("--strip", type=int, help="wrap the whole ROM this many tiles wide")
    ap.add_argument("--offset", type=int, default=0, help="skip N tiles first (fix alignment)")
    ap.add_argument("--base", type=lambda v: int(v, 0), help="first tile of one frame")
    ap.add_argument("--width", type=int, default=2, help="frame width in tiles")
    ap.add_argument("--height", type=int, default=2, help="frame height in tiles")
    ap.add_argument("--pal", type=int, help="force attract palette slot 0-15 (default auto)")
    ap.add_argument("--pal-rom", type=lambda v: int(v, 0),
                    help="force palette N from the ROM table at 0x10000 (112 entries, "
                         "see rom_sheets/rom_palettes.png) — covers ALL levels, not "
                         "just what the attract loaded")
    ap.add_argument("--scale", type=int, default=2)
    args = ap.parse_args()

    tiles = load_tiles(args.rom)
    pals = load_palettes(args.dumps) if args.dumps.is_dir() else [GRAY] * 16
    pal_map = build_pal_map(args.dumps, len(tiles)) if args.dumps.is_dir() else [None] * len(tiles)

    if args.pal_rom is not None:
        import struct
        import zipfile
        with zipfile.ZipFile(args.rom) as z:
            prog = bytes(b for pair in zip(z.read("sn6.bin"), z.read("sn5.bin")) for b in pair)
        words = struct.unpack(">16H", prog[0x10000 + args.pal_rom * 32:][:32])

        def xbgr_be(w):
            r = (w & 0x1F) << 3
            g = ((w >> 5) & 0x1F) << 3
            b = ((w >> 10) & 0x1F) << 3
            return (r | r >> 5, g | g >> 5, b | b >> 5)

        pals = [[xbgr_be(w) for w in words]] * 16
        pal_map = [0] * len(tiles)
        args.pal = 0
    args.out.mkdir(parents=True, exist_ok=True)

    if args.base is not None:
        n = args.width * args.height
        order = list(range(args.base, min(args.base + n, len(tiles))))
        img = render_grid(tiles, pals, pal_map, order, args.width, args.scale, 1, args.pal)
        name = f"frame_{args.base:04x}_{args.width}x{args.height}" \
               + (f"_p{args.pal}" if args.pal is not None else "") + ".png"
        img.save(args.out / name)
        print(args.out / name)
        return

    if not args.strip:
        sys.exit("pick --strip W or --base N")

    w = args.strip
    order = list(range(args.offset, len(tiles)))
    # page into side-by-side columns of ~128 tile-rows so the image stays usable
    rows_per_page = 128
    per_page = rows_per_page * w
    pages = [order[i:i + per_page] for i in range(0, len(order), per_page)]
    gap = 10
    imgs = [render_grid(tiles, pals, pal_map, p, w, args.scale, 4, args.pal) for p in pages]
    W = sum(im.width + gap for im in imgs)
    H = max(im.height for im in imgs)
    sheet = Image.new("RGB", (W, H), (40, 40, 40))
    x = 0
    for im in imgs:
        sheet.paste(im, (x, 0))
        x += im.width + gap
    name = f"strip_w{w}" + (f"_o{args.offset}" if args.offset else "") + ".png"
    sheet.save(args.out / name)
    print(args.out / name, sheet.size)


if __name__ == "__main__":
    main()
