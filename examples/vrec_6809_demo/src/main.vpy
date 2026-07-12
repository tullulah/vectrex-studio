META TITLE = "VREC DEMO"

# ============================================================
#  Vector-movie playback on a STOCK Vectrex (m6809) — video only.
#
#  A hand-made .vrec (a square rotating in place, 12 frames) plays via
#  DRAW_RECORDING. No special hardware — runs on any Vectrex cartridge.
#
#  `frame` is a plain counter (there is no audio clock on the 6809); a small
#  tick divider steps it every 3 loops so the 12-frame clip plays at ~16 fps
#  instead of 50. DRAW_RECORDING wraps frame % frame_count internally.
#
#  Keep .vrec clips SIMPLE per frame (few segments) — the Vectrex flicker
#  budget is ~100-150 vectors/frame. This one is 4.
# ============================================================

frame: i16 = 0
tick: i16 = 0


def main():
    pass


def loop():
    tick = tick + 1
    if tick >= 3:
        tick = 0
        frame = frame + 1
    # Full-size, centred; scale 128 = 100%.
    DRAW_RECORDING("spin", 0, 0, 128, frame)
