#!/usr/bin/env python3
"""Extract Snow Bros sprite tiles from the ROM, colored with real in-game palettes.

The gfx ROM (sbros-1.41) holds 4096 16x16 4bpp tiles in MAME's
gfx_8x8x4_row_2x2_group_packed_msb layout: each 128-byte tile is four 8x8
sub-blocks (TL, TR, BL, BR) of 32 bytes; each byte is two pixels, high nibble
left. Palettes (16 palettes x 16 colors, xBGR_555) and the tile/palette pairs
actually used by sprites come from RAM dumps taken during attract mode by
snowbros_dump.lua (Pandora sprite RAM: 8 bytes/sprite, tile =
(b7 & 0x3f) << 8 | b6, palette = b3 >> 4).

Usage: extract_sprites.py [--rom snowbros.zip] [--dumps snowdump/] [--out tiles/]

Outputs:
  tilesheet_gray.png            all 4096 tiles, grayscale, 64x64 grid
  tilesheet_used.png            tiles seen in sprite RAM, real palette, labeled
  used_tiles.txt                tile code -> palette(s) list
"""

import argparse
import io
import struct
import sys
import zipfile
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit("needs Pillow: pip3 install Pillow")

TILE_BYTES = 128
TILE_W = 16


def decode_tile(data: bytes) -> list[int]:
    """128 bytes -> 256 pixel values (0-15), row-major 16x16."""
    px = [0] * 256
    for block in range(4):  # TL, TR, BL, BR
        bx = (block & 1) * 8
        by = (block >> 1) * 8
        base = block * 32
        for row in range(8):
            for bcol in range(4):
                b = data[base + row * 4 + bcol]
                x = bx + bcol * 2
                y = by + row
                px[y * 16 + x] = b >> 4
                px[y * 16 + x + 1] = b & 0x0F
    return px


def load_tiles(rom_zip: Path) -> list[bytes]:
    with zipfile.ZipFile(rom_zip) as z:
        gfx = z.read("sbros-1.41")
    return [gfx[i:i + TILE_BYTES] for i in range(0, len(gfx), TILE_BYTES)]


def xbgr555(word: int) -> tuple[int, int, int]:
    r = (word & 0x1F) << 3
    g = ((word >> 5) & 0x1F) << 3
    b = ((word >> 10) & 0x1F) << 3
    return (r | r >> 5, g | g >> 5, b | b >> 5)


def load_palettes(dump_dir: Path) -> list[list[tuple[int, int, int]]]:
    """Merge palette dumps: last non-black version of each 16-color palette wins."""
    pals = [[(0, 0, 0)] * 16 for _ in range(16)]
    for f in sorted(dump_dir.glob("palette_*.bin")):
        raw = f.read_bytes()
        words = struct.unpack("<256H", raw)
        for p in range(16):
            colors = [xbgr555(words[p * 16 + c]) for c in range(16)]
            if any(c != (0, 0, 0) for c in colors[1:]):
                pals[p] = colors
    return pals


def used_tile_palettes(dump_dir: Path) -> dict[int, set[int]]:
    """tile code -> set of palettes it was drawn with during the attract dumps."""
    used: dict[int, set[int]] = {}
    for f in sorted(dump_dir.glob("sprites_*.bin")):
        raw = f.read_bytes()
        for off in range(0, len(raw) - 7, 8):
            b3, b6, b7 = raw[off + 3], raw[off + 6], raw[off + 7]
            tile = (((b7 & 0x3F) << 8) | b6) % 4096  # gfx system wraps by ROM tile count
            if tile == 0:
                continue
            used.setdefault(tile, set()).add(b3 >> 4)
    return used


GRAY = [(i * 17, i * 17, i * 17) for i in range(16)]


def render_tile(img: Image.Image, px: list[int], colors, x0: int, y0: int, scale: int):
    put = img.putpixel
    for y in range(16):
        for x in range(16):
            c = colors[px[y * 16 + x]]
            for sy in range(scale):
                for sx in range(scale):
                    put((x0 + x * scale + sx, y0 + y * scale + sy), c)


def main():
    ap = argparse.ArgumentParser()
    here = Path(__file__).resolve().parent.parent
    ap.add_argument("--rom", type=Path, default=here / "rom" / "snowbros.zip")
    ap.add_argument("--dumps", type=Path, default=Path.home() / "projects/mame/snowdump")
    ap.add_argument("--out", type=Path, default=here / "tiles")
    args = ap.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    tiles = load_tiles(args.rom)
    print(f"{len(tiles)} tiles from {args.rom.name}")

    # Full grayscale sheet, 64 tiles per row
    cols = 64
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * 16, rows * 16), (0, 0, 0))
    for i, t in enumerate(tiles):
        render_tile(sheet, decode_tile(t), GRAY, (i % cols) * 16, (i // cols) * 16, 1)
    sheet.save(args.out / "tilesheet_gray.png")
    print(f"tilesheet_gray.png ({cols}x{rows} tiles; tile code = row*{cols}+col)")

    if not args.dumps.is_dir() or not any(args.dumps.glob("sprites_*.bin")):
        print("no RAM dumps found — run snowbros_dump.lua first for colored output")
        return

    pals = load_palettes(args.dumps)
    used = used_tile_palettes(args.dumps)
    print(f"{len(used)} distinct tiles seen in sprite RAM during attract")

    # Contact sheet of used tiles with their real palette, 3x scale, labeled
    entries = sorted((t, p) for t, ps in used.items() for p in ps)
    with open(args.out / "used_tiles.txt", "w") as f:
        for t, ps in sorted(used.items()):
            f.write(f"{t:04x}: palettes {sorted(ps)}\n")

    scale, label_h, ucols = 3, 10, 16
    cell_w, cell_h = 16 * scale + 4, 16 * scale + label_h + 4
    urows = (len(entries) + ucols - 1) // ucols
    csheet = Image.new("RGB", (ucols * cell_w, urows * cell_h), (24, 24, 24))
    draw = ImageDraw.Draw(csheet)
    for i, (t, p) in enumerate(entries):
        x0 = (i % ucols) * cell_w + 2
        y0 = (i // ucols) * cell_h + 2
        render_tile(csheet, decode_tile(tiles[t]), pals[p], x0, y0, scale)
        draw.text((x0, y0 + 16 * scale), f"{t:04x}/{p:x}", fill=(180, 180, 180))
    csheet.save(args.out / "tilesheet_used.png")
    print(f"tilesheet_used.png ({len(entries)} tile/palette pairs) + used_tiles.txt")


if __name__ == "__main__":
    main()
