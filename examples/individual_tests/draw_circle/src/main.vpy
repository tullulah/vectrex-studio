# TEST: DRAW_CIRCLE
# Tests circle drawing with constant and variable radius
# Expected: Circles visible on screen, should remain stable (not disappear on input)

META TITLE = "DRAW_CIRCLE"
META MUSIC = music1

radius = 20

def main():
    radius = 20

def loop():
    # Center circle with constant radius
    DRAW_CIRCLE(0, 0, 30, 80)

    # Left circle with constant radius
    DRAW_CIRCLE(-60, 0, 20, 80)

    # Right circle with variable radius (increments slowly)
    DRAW_CIRCLE(60, 0, radius, 80)

    # Top circle
    DRAW_CIRCLE(0, 60, 15, 80)

    # Slowly vary radius
    radius = radius + 1
    if radius > 35:
        radius = 15
