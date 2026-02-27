# TEST: DRAW_SHAPES
# Tests advanced shape builtins: POLYGON, FILLED_RECT, ELLIPSE, ARC
# Expected: Four shapes visible on screen

META TITLE = "SHAPES"
META MUSIC = music1

def main():
    pass

def loop():
    # Top-left: triangle via DRAW_POLYGON (3 vertices + intensity)
    DRAW_POLYGON(3, 80, -50, 50, -30, 50, -40, 70)

    # Top-right: filled rectangle
    DRAW_FILLED_RECT(30, 50, 30, 20, 80)

    # Bottom-left: ellipse (cx, cy, rx, ry, intensity)
    DRAW_ELLIPSE(-40, -30, 25, 15, 80)

    # Bottom-right: arc (segs, cx, cy, r, start_deg, sweep_deg, intensity)
    DRAW_ARC(12, 40, -30, 20, 0, 270, 80)

    # Labels
    PRINT_TEXT(-70, 95, "POLY")
    PRINT_TEXT(20, 95, "FILL")
    PRINT_TEXT(-70, 10, "ELLIP")
    PRINT_TEXT(20, 10, "ARC")
