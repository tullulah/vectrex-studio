# TEST: DRAW_RECT
# Tests rectangle drawing
# Expected: Rectangles visible on screen at different positions

META TITLE = "DRAW_RECT"
META MUSIC = music1

def main():
    pass

def loop():
    # Filled rectangle (center)
    DRAW_FILLED_RECT(-30, -30, 30, 30, 80)

    # Outlined rectangle (left side)
    DRAW_RECT(-80, -40, -50, 40, 80)

    # Outlined rectangle (right side)
    DRAW_RECT(50, -40, 80, 40, 80)

    # Small rectangle (top)
    DRAW_FILLED_RECT(-10, 60, 10, 80, 80)
