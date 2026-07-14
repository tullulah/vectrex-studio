# TEST: PRINT_TEXT
# Tests basic text display functionality
# Expected: Text appears on screen and stays visible each frame

META TITLE = "PRINT_TEXT"
#META MUSIC = music1

def main():
    SET_INTENSITY(110)

def loop():
    # DIAG: does a vector draw before text "enable" the text? (text-only = blank)
    DRAW_LINE(0 - 20, 0 - 80, 20, 0 - 80, 80)
    # Display text at different positions on screen
    SET_INTENSITY(110)
    SET_TEXT_SIZE(6)
    DRAW_VECTOR("test", 0, 100)
    PRINT_TEXT(-40, 20, "HELLO")
    PRINT_TEXT(-40, 0, "WORLD")
    PRINT_TEXT(-55, -20, "VPY TEST")
