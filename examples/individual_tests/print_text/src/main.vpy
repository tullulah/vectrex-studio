# TEST: PRINT_TEXT
# Tests basic text display functionality
# Expected: Text appears on screen and stays visible each frame

META TITLE = "PRINT_TEXT"
META MUSIC = music1
def main():
    pass

def loop():
    # Display text at different positions on screen
    # SET_INTENSITY(110)
    # SET_TEXT_SIZE(6)    
    PRINT_TEXT(-40, 20, "HELLO")
    PRINT_TEXT(-40, 0, "WORLD")
    PRINT_TEXT(-55, -20, "VPY TEST")
