#!/usr/bin/env python3
"""Bake the attract instruction rows as stroke-font .vec shapes.

The arcade renders these lines as pre-drawn graphics tiles (0xd22-0xd3f) with
decorative bullet digits — not ASCII — so the text path can't help. But the
CONTENT is fixed, so each row becomes a .vec of our own stroke font at reduced
scale: readable, cheap, and served by the same signature machinery.
"""
import json
import sys
from pathlib import Path

here = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(here / 'tools'))
from make_font import G
from autotrace import find_frame, captured_pixels, embed_background
from extract_sprites import load_tiles, load_palettes

# name -> (text, target width in arcade px = the captured object's bbox)
ROWS = {
    'instr_row_1': ('1 TURN ENEMY INTO A SNOW BALL', 128, 0x0df),
    'instr_row_2': ('2 PUSH SNOW BALL BY CONTROL LEVER', 176, 0x0e8),
    'instr_row_3': ('3 KICK OUT SNOW BALL BY PRESSING SHOOT BUTTON', 192, 0x0ee),
}


def main():
    tiles = load_tiles(here / 'rom' / 'snowbros.zip')
    pals = load_palettes(Path.home() / 'projects/mame/snowdump')
    for name, (text, width, base) in ROWS.items():
        adv = width / len(text)
        scale = adv / 8.0
        paths = []
        for i, ch in enumerate(text):
            if ch == ' ' or ch not in G:
                continue
            x0 = i * adv - width / 2
            for j, stroke in enumerate(G[ch]):
                pts = [{'x': round(x0 + gx * scale),
                        'y': round(4 - gy * scale)} for gx, gy in stroke]
                paths.append({'name': f'c{i}_{j}', 'intensity': 95,
                              'closed': False, 'points': pts})
        d = {'version': '1.0', 'name': name,
             'canvas': {'width': 256, 'height': 256, 'origin': 'center'},
             'layers': [{'name': 'default', 'visible': True, 'paths': paths}]}
        obj = find_frame(base)
        if obj is not None:
            px, W, H = captured_pixels(tiles, obj)
            embed_background(d, px, W, H, pals[5])
        (here / 'assets' / 'vectors' / f'{name}.vec').write_text(json.dumps(d, indent=1))
        npts = sum(len(p['points']) for p in paths)
        print(f'{name}: "{text}" -> {len(paths)} strokes, {npts} pts, {width}px wide')


if __name__ == '__main__':
    main()
