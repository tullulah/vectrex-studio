# TEST: DRAW_VECTOR
# Tests vector graphics drawing (requires .vec assets)
# For now: tests with lines forming star pattern
# Expected: Vector/star pattern visible on screen

META TITLE = "DRAW_VECTOR"
META MUSIC = music1

def main():
    pass

def loop():
    # Draw a star pattern with lines
    DRAW_LINE(-40, 40, 40, -40, 80)
    DRAW_LINE(40, 40, -40, -40, 80)
    DRAW_LINE(-40, 0, 40, 0, 80)
    DRAW_LINE(0, 40, 0, -40, 80)
