#!/usr/bin/env python3
"""Compose each real level's full static background into one .vec.

Snow Bros levels don't scroll: every floor is one fixed 256x224 screen made of
level-bank tiles (0x600-0xcff). We FORCE each level number via build/host_levelcap
(SB_FORCE_LEVEL, intercepts the start-of-play RAM-clear at 0x1ba4) and grab its
scenery straight from the game — the real level, no enemies, correctly numbered,
without having to play to it.

For each level N:
  1. run the host forced to level N, capturing sprite RAM across a few frames;
  2. take the fullest scenery composition (all 0x600-0xcff tiles, big chained
     object only — small objects are enemies), rasterise to PNG (real palette);
  3. detect the snow-capped platform tops as horizontal runs;
  4. write assets/vectors/level_NN.vec with the PNG embedded (naturalCenter,
     1px=1 unit) so you draw the level by hand over the real scenery.

Coord contract: .vec centred on origin, y-up, 1 unit = 1 arcade px; screen
256x224 maps to x[-128..128], y[-112..112].
"""
import base64
import io
import json
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

here = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(here / 'tools'))
from compose_sprites import parse_objects
from extract_sprites import load_tiles, decode_tile, load_palettes

W, H = 256, 224
NUM_LEVELS = 50
HOST = here / 'build' / 'host_levelcap'


def sext9(v):
    v &= 0x1ff
    return v - 512 if v >= 256 else v


def scenery(raw):
    """Level backdrop tiles: the ONE big chained object (>24 tiles); small
    level-bank objects are floor-11+ enemies, kept out of the static bg."""
    out = []
    for o in parse_objects(raw):
        if len(o) <= 24:  # scenery = the big chained objects; small ones are enemies
            continue
        for t in o:
            if 0x600 <= t[2] <= 0xcff:
                out.append((sext9(t[0]), sext9(t[1]), t[2], t[3], t[4], t[5]))
    return out


def xbgr(w):
    r = (w & 0x1f) << 3
    g = ((w >> 5) & 0x1f) << 3
    b = ((w >> 10) & 0x1f) << 3
    return (r | r >> 5, g | g >> 5, b | b >> 5)


def load_pal_ram(raw):
    """256-colour palette from a pal_*.bin dump (0x200 bytes, big-endian words):
    16 palettes of 16 colours, xBGR555 — the level's OWN live palette."""
    return [xbgr((raw[i * 2] << 8) | raw[i * 2 + 1]) for i in range(256)]


def capture_level(n, outdir):
    """Force level n; return (fullest scenery, that frame's live palette)."""
    subprocess.run(
        [str(HOST)],
        env={'SB_FORCE_LEVEL': str(n), 'AUTOCOIN': '250', 'CHEATS': '1',
             'SPRFARM': str(outdir), 'SPREVERY': '120', 'FRAMES': '1400',
             'PATH': '/usr/bin:/bin'},
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    best, bestn, bestpal = [], 0, None
    for f in sorted(Path(outdir).glob('sprites_*.bin')):
        sc = scenery(f.read_bytes())
        if len(sc) > bestn:
            bestn, best = len(sc), sc
            pf = f.with_name(f.name.replace('sprites_', 'pal_'))
            bestpal = load_pal_ram(pf.read_bytes()) if pf.exists() else None
    for f in Path(outdir).glob('*.bin'):
        f.unlink()
    return best, bestpal


def rasterize(tiles, pal256, sc):
    """pal256 = the level's 256 live colours (16 palettes x 16)."""
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    put = img.putpixel
    for x, y, tile, pal, fx, fy in sc:
        px = decode_tile(tiles[tile])
        cols = [pal256[pal * 16 + c] for c in range(16)]
        for ty in range(16):
            for tx in range(16):
                c = px[ty * 16 + tx]
                if not c:
                    continue
                sx = 15 - tx if fx else tx
                sy = 15 - ty if fy else ty
                X, Y = x + sx, y + sy - 16
                if 0 <= X < W and 0 <= Y < H:
                    put((X, Y), cols[c] + (255,))
    return img


def platforms(img):
    px = img.convert('RGB').load()
    runs = []
    for y in range(16, H):
        x = 0
        while x < W:
            r, g, b = px[x, y]
            if r > 185 and g > 185 and b > 185:
                x0 = x
                while x < W:
                    r, g, b = px[x, y]
                    if not (r > 160 and g > 160 and b > 160):
                        break
                    x += 1
                if x - x0 >= 14:
                    runs.append((y, x0, x))
            else:
                x += 1
    plats = []
    for y, x0, x1 in sorted(runs):
        for p in plats:
            if abs(p[0] - y) <= 6 and not (x1 < p[1] - 20 or x0 > p[2] + 20):
                p[0] = min(p[0], y); p[1] = min(p[1], x0); p[2] = max(p[2], x1)
                break
        else:
            plats.append([y, x0, x1])
    return [p for p in plats if p[2] - p[1] >= 14]


# Tilted-console geometry: the Vectrex laid on its side gives a 256x192 screen,
# and Snow Bros (256x224) fits it UNIFORMLY SCALED (no squash) at 192/224, so
# the 224-tall arcade screen becomes the 192-tall short axis. That leaves the
# game 256*S wide inside a 256-wide screen -> side gutters for the overlay.
# Everything (bg + platforms) is emitted pre-scaled so the .vec IS the final
# on-screen geometry; the SDK's 90-degree rotation presents it tilted.
GAME_SCALE = 192.0 / 224.0     # ~0.857, uniform


def vscale(px, py):
    """arcade pixel (0..256, 0..224) -> vec unit (origin centre, y-up), scaled."""
    return (px - 128) * GAME_SCALE, (112 - py) * GAME_SCALE


def make_vec(name, img, plats):
    paths, segs = [], []
    thick = 12 * GAME_SCALE
    for y, x0, x1 in plats:
        (vx0, vy), (vx1, _) = vscale(x0, y), vscale(x1, y)
        paths.append({'name': f'plat_{y}_{x0}', 'intensity': 110, 'closed': True,
                      'points': [{'x': round(vx0), 'y': round(vy)}, {'x': round(vx1), 'y': round(vy)},
                                 {'x': round(vx1), 'y': round(vy - thick)}, {'x': round(vx0), 'y': round(vy - thick)}]})
        segs.append({'x1': round(vx0), 'y1': round(vy), 'x2': round(vx1), 'y2': round(vy)})
    # embed the background pre-scaled to the game rect (219x192), so 1px = 1 unit
    # centred lands it exactly under the scaled platforms, gutters transparent
    gw, gh = round(256 * GAME_SCALE), round(224 * GAME_SCALE)
    scaled = img.resize((gw, gh), Image.LANCZOS)
    buf = io.BytesIO()
    scaled.save(buf, format='PNG')
    d = {'version': '1.0', 'name': name,
         'canvas': {'width': 256, 'height': 256, 'origin': 'center'},
         'layers': [{'name': 'platforms', 'visible': True, 'paths': paths}],
         'collisionMesh': {'segments': segs},
         'backgroundImage': 'data:image/png;base64,' + base64.b64encode(buf.getvalue()).decode(),
         'backgroundFit': 'naturalCenter', 'backgroundOffset': {'x': 0, 'y': 0}}
    (here / 'assets' / 'vectors' / f'{name}.vec').write_text(json.dumps(d, indent=1))


def main():
    if not HOST.exists():
        sys.exit("build/host_levelcap missing — run: make host-levelcap CHEATS=1")
    tiles = load_tiles(here / 'rom' / 'snowbros.zip')
    (here / 'assets' / 'backgrounds').mkdir(exist_ok=True)
    # clear the old similarity-grouped level_bg_* set
    for old in (here / 'assets' / 'vectors').glob('level_bg_*.vec'):
        old.unlink()
    for old in (here / 'assets' / 'backgrounds').glob('level_bg_*.png'):
        old.unlink()
    with tempfile.TemporaryDirectory() as tmp:
        for n in range(NUM_LEVELS):
            sc, pal256 = capture_level(n, tmp)
            if len(sc) < 100 or pal256 is None:
                print(f'level {n:02d}: only {len(sc)} tiles — skipped (load failed)')
                continue
            img = rasterize(tiles, pal256, sc)
            plats = platforms(img)
            name = f'level_{n:02d}'
            make_vec(name, img, plats)
            img.convert('RGB').save(here / 'assets' / 'backgrounds' / f'{name}.png')
            print(f'level {n:02d}: {len(sc)} tiles, {len(plats)} platforms')


if __name__ == '__main__':
    main()
