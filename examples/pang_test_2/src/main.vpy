# TEST 2: Add Input Handling (J1_X, J1_Y)
# Tests: Joystick reading, array access
# Visual: Draw a dot that moves with joystick

META TITLE = "PANG_TEST_2"
META MUSIC = music1

screen = 0
joystick1_state = [0,0,0,0,0,0]

def main():
    screen = 0

def loop():
    joystick1_state[0] = J1_X()
    joystick1_state[1] = J1_Y()

    # Visual feedback: draw a dot at joystick position
    DRAW_CIRCLE(joystick1_state[0], joystick1_state[1], 10, 127)
