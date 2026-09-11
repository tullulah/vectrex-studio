#!/usr/bin/env python3
"""Auto-trace sprite tiles into .vec outlines — faithful, not hand-drawn.

For each sprite (a WxH block of ROM tiles, ROM-native orientation):
  1. silhouette: boundary-follow the nonzero-pixel mask (marching squares on
     pixel edges), one closed path per connected blob, simplified with
     Douglas-Peucker;
  2. features: dark-tone pixel regions that do NOT touch the silhouette edge
     (eyes, mouth, straps — the sprite art draws them as dark clusters) traced
     the same way at lower intensity.

Coordinates: pixel -> vec units 1:1, centred on the origin, y-up — the same
contract the renderer and the editor backgrounds use.

Existing .vec files are OVERWRITTEN in geometry only: name/canvas/background*
fields are kept so editor references survive. Run with --dry to preview counts.
"""
import argparse
import base64
import io
import json
import sys
from pathlib import Path

here = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(here / 'tools'))
from extract_sprites import load_tiles, decode_tile, load_palettes

# name -> (base tile, tiles wide, tiles high, attract palette for tones)
SPRITES = {
    'nick_stand':    (0x340, 2, 2, 8),
    'nick_walk_0':   (0x344, 2, 2, 8),
    'nick_walk_1':   (0x34c, 2, 2, 8),
    'nick_jump':     (0x370, 2, 2, 8),
    'enemy_pink_0':  (0x304, 2, 2, 10),
    'ball':          (0x100, 2, 2, 14),
    'enemy2_walk_0': (0x480, 2, 2, 10),
    'enemy2_walk_1': (0x484, 2, 2, 10),
    'enemy2_walk_2': (0x488, 2, 2, 10),
    'hud_1up':       (0x180, 1, 1, 6),
    'item_blue':     (0x402, 1, 1, 6),
}


def sprite_pixels(tiles, base, tw, th):
    W, H = tw * 16, th * 16
    px = [[0] * W for _ in range(H)]
    for gy in range(th):
        for gx in range(tw):
            t = decode_tile(tiles[base + gy * tw + gx])
            for y in range(16):
                for x in range(16):
                    px[gy * 16 + y][gx * 16 + x] = t[y * 16 + x]
    return px, W, H


def trace_mask(mask, W, H):
    """Closed contours of a binary mask, walking pixel edges (y down)."""
    # edge set: for each mask pixel, edges bordering non-mask
    edges = set()
    def at(x, y):
        return 0 <= x < W and 0 <= y < H and mask[y][x]
    for y in range(H):
        for x in range(W):
            if not mask[y][x]:
                continue
            if not at(x, y - 1): edges.add(((x, y), (x + 1, y)))
            if not at(x + 1, y): edges.add(((x + 1, y), (x + 1, y + 1)))
            if not at(x, y + 1): edges.add(((x + 1, y + 1), (x, y + 1)))
            if not at(x - 1, y): edges.add(((x, y + 1), (x, y)))
    # link into loops
    nxt = {}
    for a, b in edges:
        nxt.setdefault(a, []).append(b)
    loops = []
    used = set()
    for start in list(nxt):
        if start in used:
            continue
        loop = [start]
        cur = start
        prev = None
        while True:
            outs = [b for b in nxt.get(cur, []) if (cur, b) not in used]
            if not outs:
                break
            # prefer continuing straight to produce clean corners
            b = outs[0]
            if prev and len(outs) > 1:
                dx, dy = cur[0] - prev[0], cur[1] - prev[1]
                straight = (cur[0] + dx, cur[1] + dy)
                if straight in outs:
                    b = straight
            used.add((cur, b))
            used.add(cur)
            cur = b
            if cur == start:
                break
            loop.append(cur)
            prev = loop[-2]
        if len(loop) >= 4 and cur == start:
            loops.append(loop)
    return loops


def dp_simplify(pts, eps):
    """Douglas-Peucker on a closed loop (open-run applied around anchor)."""
    def simplify(seg):
        if len(seg) < 3:
            return seg
        ax, ay = seg[0]
        bx, by = seg[-1]
        dx, dy = bx - ax, by - ay
        norm = (dx * dx + dy * dy) ** 0.5 or 1.0
        best, bi = 0.0, 0
        for i in range(1, len(seg) - 1):
            px, py = seg[i]
            d = abs((px - ax) * dy - (py - ay) * dx) / norm
            if d > best:
                best, bi = d, i
        if best <= eps:
            return [seg[0], seg[-1]]
        left = simplify(seg[:bi + 1])
        return left[:-1] + simplify(seg[bi:])
    # split closed loop at two far-apart anchors
    n = len(pts)
    a, b = 0, n // 2
    part1 = simplify(pts[a:b + 1])
    part2 = simplify(pts[b:] + [pts[0]])
    return part1[:-1] + part2[:-1]


def luminance(rgb):
    return 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]


def embed_background(d, px, W, H, colors):
    """Render the reference pixels to PNG and embed as the editor background
    (1:1, centred on the origin — same contract as the traced geometry)."""
    from PIL import Image
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    for y in range(H):
        for x in range(W):
            v = px[y][x]
            if v:
                img.putpixel((x, y), tuple(colors[v]) + (255,))
    buf = io.BytesIO()
    img.save(buf, format='PNG')
    d['backgroundImage'] = 'data:image/png;base64,' + base64.b64encode(buf.getvalue()).decode()
    d['backgroundFit'] = 'naturalCenter'
    d['backgroundOffset'] = {'x': 0, 'y': 0}


def trace_sprite(tiles, pals, base, tw, th, pal):
    px, W, H = sprite_pixels(tiles, base, tw, th)
    mask = [[1 if px[y][x] else 0 for x in range(W)] for y in range(H)]
    silhouettes = [dp_simplify(l, 1.25) for l in trace_mask(mask, W, H)]
    silhouettes = [s for s in silhouettes if len(s) >= 4]

    # dark features: darkest-tone pixels not touching the silhouette border
    colors = pals[pal]
    lum = {i: luminance(colors[i]) for i in range(1, 16)}
    present = sorted({px[y][x] for y in range(H) for x in range(W) if px[y][x]},
                     key=lambda i: lum[i])
    # only tones clearly darker than the sprite's median read as drawn
    # features (eyes, mouth); mid shading tones produce scribble noise
    med = lum[present[len(present) // 2]]
    dark = {t for t in present if lum[t] < 0.55 * med} or {present[0]}
    border = set()
    for y in range(H):
        for x in range(W):
            if not mask[y][x]:
                continue
            if (x == 0 or y == 0 or x == W - 1 or y == H - 1
                    or not mask[y][x - 1] or not mask[y][x + 1]
                    or not mask[y - 1][x] or not mask[y + 1][x]):
                border.add((x, y))
    fmask = [[0] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            if px[y][x] in dark and (x, y) not in border:
                fmask[y][x] = 1
    raw = [dp_simplify(l, 0.9) for l in trace_mask(fmask, W, H)]
    raw = [f for f in raw if 3 <= len(f) <= 12]
    # keep only the biggest few features — eyes/mouth, not pixel noise
    def area(loop):
        a = 0
        for i in range(len(loop)):
            x0, y0 = loop[i]; x1, y1 = loop[(i + 1) % len(loop)]
            a += x0 * y1 - x1 * y0
        return abs(a) / 2
    raw.sort(key=area, reverse=True)
    features = [f for f in raw if area(f) >= 3.0][:4]

    def to_vec(loop):
        return [{'x': round(x - W / 2), 'y': round(H / 2 - y)} for x, y in loop]

    paths = []
    for i, s in enumerate(silhouettes):
        paths.append({'name': f'sil{i}', 'intensity': 115, 'closed': True,
                      'points': to_vec(s)})
    for i, f in enumerate(features):
        paths.append({'name': f'det{i}', 'intensity': 80, 'closed': True,
                      'points': to_vec(f)})
    return paths


# captured multi-tile compositions (logo, title lettering, attract rows):
# name -> (min tile code of the captured object, attract palette)
# name -> (min tile code, palette, max interior features, min feature area)
CAPTURED = {
    'logo_medallion': (0xd8f, 1, 10, 2.0, True),
    # (name -> base, palette, max features, min area, colour-region mode)
    'title_snow':     (0xddc, 1, 0, 3.0, False),
    'title_bros':     (0xdee, 1, 0, 3.0, False),
    'nick_push':      (0x3b0, 8, 4, 3.0, False),
}


def find_frame(base):
    from vec_to_sprites import rebuild_frames
    if not hasattr(find_frame, 'frames'):
        find_frame.frames = rebuild_frames()
    best = None
    for obj in find_frame.frames:
        if min(t[2] for t in obj) == base:
            if best is None or len(obj) > len(best):
                best = obj
    return best


def captured_pixels(tiles, obj):
    minx = min(t[0] for t in obj); miny = min(t[1] for t in obj)
    W = max(t[0] for t in obj) - minx + 16
    H = max(t[1] for t in obj) - miny + 16
    px = [[0] * W for _ in range(H)]
    for x0, y0, tile, pal, fx, fy in obj:
        t = decode_tile(tiles[tile])
        for y in range(16):
            for x in range(16):
                sx = 15 - x if fx else x
                sy = 15 - y if fy else y
                v = t[sy * 16 + sx]
                if v:
                    px[y0 - miny + y][x0 - minx + x] = v
    return px, W, H


def color_region_features(px, W, H, colors, min_area, max_features):
    """Interior contours of distinct COLOUR groups (mouth, cap, eyes) —
    features that a dark-tone pass misses because they are bright.
    Regions touching the silhouette edge are shading, not features."""
    mask = [[1 if px[y][x] else 0 for x in range(W)] for y in range(H)]
    border = set()
    for y in range(H):
        for x in range(W):
            if not mask[y][x]:
                continue
            if (x == 0 or y == 0 or x == W - 1 or y == H - 1
                    or not mask[y][x - 1] or not mask[y][x + 1]
                    or not mask[y - 1][x] or not mask[y + 1][x]):
                border.add((x, y))
    # cluster palette indices by RGB proximity
    present = {}
    for y in range(H):
        for x in range(W):
            v = px[y][x]
            if v: present[v] = present.get(v, 0) + 1
    groups = []
    for idx in sorted(present, key=present.get, reverse=True):
        for g in groups:
            r0, g0, b0 = colors[g[0]]
            r1, g1, b1 = colors[idx]
            if abs(r0 - r1) + abs(g0 - g1) + abs(b0 - b1) < 95:
                g.append(idx); break
        else:
            groups.append([idx])
    if len(groups) < 2:
        return []
    # dominant group = the body; every other group's regions are features
    body = max(groups, key=lambda g: sum(present[i] for i in g))
    feats = []
    for g in groups:
        if g is body: continue
        gm = [[1 if px[y][x] in g and (x, y) not in border else 0
               for x in range(W)] for y in range(H)]
        for loop in trace_mask(gm, W, H):
            sl = dp_simplify(loop, 1.0)
            if 3 <= len(sl) <= 14:
                a = 0
                for i in range(len(sl)):
                    x0, y0 = sl[i]; x1, y1 = sl[(i + 1) % len(sl)]
                    a += x0 * y1 - x1 * y0
                if abs(a) / 2 >= min_area:
                    feats.append((abs(a) / 2, sl))
    feats.sort(reverse=True, key=lambda t: t[0])
    return [f for _, f in feats[:max_features]]


def trace_pixels(px, W, H, colors, max_features=4, min_area=3.0, regions=False):
    """Shared pipeline: silhouettes + isolated dark features."""
    mask = [[1 if px[y][x] else 0 for x in range(W)] for y in range(H)]
    silhouettes = [dp_simplify(l, 1.25) for l in trace_mask(mask, W, H)]
    silhouettes = [s for s in silhouettes if len(s) >= 4]

    lum = {i: luminance(colors[i]) for i in range(1, 16)}
    present = sorted({px[y][x] for y in range(H) for x in range(W) if px[y][x]},
                     key=lambda i: lum[i])
    features = []
    if present:
        med = lum[present[len(present) // 2]]
        dark = {t for t in present if lum[t] < 0.55 * med} or {present[0]}
        border = set()
        for y in range(H):
            for x in range(W):
                if not mask[y][x]:
                    continue
                if (x == 0 or y == 0 or x == W - 1 or y == H - 1
                        or not mask[y][x - 1] or not mask[y][x + 1]
                        or not mask[y - 1][x] or not mask[y + 1][x]):
                    border.add((x, y))
        fmask = [[0] * W for _ in range(H)]
        for y in range(H):
            for x in range(W):
                if px[y][x] in dark and (x, y) not in border:
                    fmask[y][x] = 1
        raw = [dp_simplify(l, 0.9) for l in trace_mask(fmask, W, H)]
        raw = [f for f in raw if 3 <= len(f) <= 12]
        def area(loop):
            a = 0
            for i in range(len(loop)):
                x0, y0 = loop[i]; x1, y1 = loop[(i + 1) % len(loop)]
                a += x0 * y1 - x1 * y0
            return abs(a) / 2
        raw.sort(key=area, reverse=True)
        features = [f for f in raw if area(f) >= min_area][:max_features]
    if regions:
        features = color_region_features(px, W, H, colors, min_area, max_features)

    def to_vec(loop):
        return [{'x': round(x - W / 2), 'y': round(H / 2 - y)} for x, y in loop]
    paths = [{'name': f'sil{i}', 'intensity': 115, 'closed': True,
              'points': to_vec(s)} for i, s in enumerate(silhouettes)]
    paths += [{'name': f'det{i}', 'intensity': 80, 'closed': True,
               'points': to_vec(f)} for i, f in enumerate(features)]
    return paths


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dry', action='store_true')
    ap.add_argument('--only', nargs='*')
    ap.add_argument('--catalog', action='store_true')
    args = ap.parse_args()

    if args.catalog:
        catalog(dry=args.dry)
        return

    tiles = load_tiles(here / 'rom' / 'snowbros.zip')
    pals = load_palettes(Path.home() / 'projects/mame/snowdump')

    for name, (base, pal, maxfeat, minarea, regions) in CAPTURED.items():
        if args.only and name not in args.only:
            continue
        obj = find_frame(base)
        if obj is None:
            print(f'{name:14s} NOT FOUND in dumps (base {base:04x})')
            continue
        px, W, H = captured_pixels(tiles, obj)
        paths = trace_pixels(px, W, H, pals[pal], max_features=maxfeat, min_area=minarea, regions=regions)
        npts = sum(len(p['points']) for p in paths)
        print(f'{name:14s} {W}x{H}  {len(paths)} paths, {npts} pts')
        if not args.dry:
            p = here / 'assets' / 'vectors' / f'{name}.vec'
            d = json.loads(p.read_text()) if p.exists() else {
                'version': '1.0', 'name': name,
                'canvas': {'width': 256, 'height': 256, 'origin': 'center'}}
            d['layers'] = [{'name': 'default', 'visible': True, 'paths': paths}]
            embed_background(d, px, W, H, pals[pal])
            p.write_text(json.dumps(d, indent=1))

    for name, (base, tw, th, pal) in SPRITES.items():
        if args.only and name not in args.only:
            continue
        paths = trace_sprite(tiles, pals, base, tw, th, pal)
        npts = sum(len(p['points']) for p in paths)
        print(f'{name:14s} {len(paths)} paths, {npts} pts')
        if args.dry:
            continue
        p = here / 'assets' / 'vectors' / f'{name}.vec'
        d = json.loads(p.read_text()) if p.exists() else {
            'version': '1.0', 'name': name,
            'canvas': {'width': 256, 'height': 256, 'origin': 'center'}}
        d['layers'] = [{'name': 'default', 'visible': True, 'paths': paths}]
        spx, sW, sH = sprite_pixels(tiles, base, tw, th)
        embed_background(d, spx, sW, sH, pals[pal])
        p.write_text(json.dumps(d, indent=1))




# ---- bulk catalogue: every captured frame in the character/boss families ----
# (base range lo, hi, family label, palette fallback)
FAMILIES = [
    (0x0fa, 0x0fa, 'misc'),    # (c) mark of the copyright line
    (0x11c, 0x17d, 'fx'),      # effects, power-up banners, sparkles
    (0x200, 0x27f, 'ghost'),   # hurry-up pumpkin ghost: flames, ghost, totems
    (0x280, 0x33f, 'enemy1'),  # includes the 0x280 block: floor-2+ states
    (0x340, 0x3ef, 'nick'),    # includes the back-view / bonus poses past 0x3df
    (0x3f0, 0x47f, 'item'),    # pickups: potions, sushi, bonus drops
    (0x480, 0x52f, 'enemy2'),
    (0x530, 0x5be, 'enemy3'),
    (0xe00, 0xed9, 'boss1'),
    (0xff3, 0xffb, 'misc'),    # TOAPLAN banner + continue-screen blocks
]


def catalog(dry=False):
    import json as _json
    tiles = load_tiles(here / 'rom' / 'snowbros.zip')
    pals = load_palettes(Path.home() / 'projects/mame/snowdump')
    from vec_to_sprites import rebuild_frames
    frames = rebuild_frames()
    # one entry per (base, bbox): frame VARIANTS share a base with different
    # boxes (the ghost materialising is 32x32/3 tiles, the full ghost bigger)
    best = {}
    for obj in frames:
        base = min(t[2] for t in obj)
        fam = next((f for f in FAMILIES if f[0] <= base <= f[1]), None)
        if fam is None or not (1 <= len(obj) <= 48):
            continue
        w = max(t[0] for t in obj) - min(t[0] for t in obj) + 16
        h = max(t[1] for t in obj) - min(t[1] for t in obj) + 16
        if w > 128 or h > 128:
            continue
        flip = sum(1 for t in obj if t[4]) * 2 > len(obj)
        key = (base, w, h)
        cur = best.get(key)
        if cur is None or (cur[1] and not flip) or \
           (cur[1] == flip and len(obj) > len(cur[0])):
            best[key] = (obj, flip, fam[2])
    manifest = []
    seen_names = {}
    for (base, bw, bh), (obj, flip, fam) in sorted(best.items()):
        px, W, H = captured_pixels(tiles, obj)
        pal = obj[0][3]
        paths = trace_pixels(px, W, H, pals[pal], max_features=4)
        npts = sum(len(p['points']) for p in paths)
        name = f'auto_{fam}_{base:04x}'
        n = seen_names.get(base, 0)
        seen_names[base] = n + 1
        if n:
            name += f'_v{n + 1}'
        manifest.append({'name': name, 'base': base, 'w': W, 'h': H,
                         'ntiles': len(obj), 'refflip': 1 if flip else 0})
        if not dry:
            d = {'version': '1.0', 'name': name,
                 'canvas': {'width': 256, 'height': 256, 'origin': 'center'},
                 'layers': [{'name': 'default', 'visible': True, 'paths': paths}]}
            embed_background(d, px, W, H, pals[pal])
            (here / 'assets' / 'vectors' / f'{name}.vec').write_text(_json.dumps(d, indent=1))
    if not dry:
        (here / 'assets' / 'vectors' / 'auto_manifest.json').write_text(
            _json.dumps(manifest, indent=1))
    from collections import Counter
    fams = Counter(m['name'].split('_')[1] for m in manifest)
    print(f'catalog: {len(manifest)} frames  {dict(fams)}')


if __name__ == '__main__':
    main()
