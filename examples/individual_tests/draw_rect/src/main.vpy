# TEST: DRAW_RECT
# Tests rectangle drawing with DRAW_RECT(x, y, width, height, intensity)
# Expected: Two tall rectangles on left and right sides, one small in center

META TITLE = "DRAW_RECT"
META MUSIC = music1

def main():
    pass

def loop():
    # Left rectangle: starts at (-80,-40), 30 wide, 80 tall -> corners (-80,-40) to (-50,40)
    DRAW_RECT(-80, -40, 30, 80, 80)

    # Right rectangle: starts at (50,-40), 30 wide, 80 tall -> corners (50,-40) to (80,40)
    DRAW_RECT(50, -40, 30, 80, 80)

    # Center square: starts at (-15,-15), 30 wide, 30 tall -> corners (-15,-15) to (15,15)
    DRAW_RECT(-15, -15, 30, 30, 80)
