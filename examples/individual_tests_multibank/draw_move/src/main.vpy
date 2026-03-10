# TEST: DRAW_MOVE
# Tests MOVE (set draw position) with DRAW_LINE
# Expected: Lines drawn relative to MOVE position

META TITLE = "DRAW_MOVE"
META MUSIC = music1
META ROM_TOTAL_SIZE = 65536
META ROM_BANK_SIZE = 16384

def main():
    pass

def loop():
    # Move to left position and draw
    MOVE(-60, 60)
    DRAW_LINE(0, 0, 40, -40, 80)

    # Move to right position and draw
    MOVE(60, 60)
    DRAW_LINE(0, 0, -40, -40, 80)

    # Move to center and draw
    MOVE(0, 0)
    DRAW_LINE(-30, 0, 30, 0, 80)
