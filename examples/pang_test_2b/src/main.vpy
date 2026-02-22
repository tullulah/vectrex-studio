# TEST 2B: Joystick Input (Direct - No Array)
# Tests: J1_X/Y direct call vs array version
# Visual: Circle that moves with joystick

META TITLE = "PANG_TEST_2B"
META MUSIC = music1

screen = 0

def main():
    screen = 0

def loop():
    # Direct call to J1_X/Y without storing in array
    DRAW_CIRCLE(J1_X(), J1_Y(), 10, 127)
