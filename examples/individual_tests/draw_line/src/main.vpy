# TEST: DRAW_LINE
# Tests basic line drawing
# Expected: Horizontal, vertical, and diagonal lines visible on screen

META TITLE = "DRAW_LINE"
META MUSIC = music1

def main():
    pass

def loop():
    # Horizontal line (left to right)
    DRAW_LINE(-60, 80, 60, 80, 80)

    # Vertical line (top to bottom)
    DRAW_LINE(-80, 60, -80, -60, 80)

    # Diagonal line (top-left to bottom-right)
    DRAW_LINE(-50, 60, 50, -60, 80)

    # Another diagonal (top-right to bottom-left)
    DRAW_LINE(50, 60, -50, -60, 80)
