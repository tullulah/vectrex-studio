# TEST: PRINT_TEXT
# Tests basic text display functionality
# Expected: Text appears on screen and stays visible each frame

META TITLE = "PRINT_TEXT"
META MUSIC = music1
META ROM_TOTAL_SIZE = 65536
META ROM_BANK_SIZE = 16384
def main():
    pass

def loop():
    # Display text at different positions on screen
    PRINT_TEXT(-40, 20, "HELLO")
    PRINT_TEXT(-40, 0, "WORLD")
    PRINT_TEXT(-55, -20, "VPY TEST")
