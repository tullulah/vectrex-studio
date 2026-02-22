# TEST 2E: Vector with Inverted Joystick
# Tests: DRAW_VECTOR with negated J1_X/Y (to fix inversion)

META TITLE = "PANG_TEST_2E"
META MUSIC = music1

screen = 0
x_pos = 0
y_pos = 0

def main():
    screen = 0

def loop():
    # Negate joystick values to test if inversion is the issue
    x_pos = 0 - J1_X()
    y_pos = 0 - J1_Y()

    # Draw vector at negated joystick position
    DRAW_VECTOR("test_square", x_pos, y_pos)
