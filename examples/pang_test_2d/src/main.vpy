# TEST 2D: Vector with Joystick Control
# Tests: DRAW_VECTOR with J1_X/Y input

META TITLE = "PANG_TEST_2D"
META MUSIC = music1

screen = 0

def main():
    screen = 0

def loop():
    # Draw vector at joystick position
    DRAW_VECTOR("test_square", J1_X(), J1_Y())
