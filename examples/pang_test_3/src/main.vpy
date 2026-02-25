# TEST 3: Add Button Debounce (State Machine)
# Tests: Conditional logic, variable tracking
# Visual: screen changes color when button pressed

META TITLE = "PANG_TEST_3"
META MUSIC = music1

screen = 0
joystick1_state = [0,0,0,0,0,0]
prev_btn1 = 0

def main():
    screen = 0
    prev_btn1 = 0

def loop():
    joystick1_state[2] = J1_BUTTON_1()

    if joystick1_state[2] == 1 and prev_btn1 == 0:
        # Button pressed (0→1 transition)
        screen = 1

    prev_btn1 = joystick1_state[2]

    # Visual feedback: draw circle that changes with screen state
    if screen == 0:
        DRAW_CIRCLE(0, 0, 30, 80)
    else:
        DRAW_CIRCLE(0, 0, 60, 127)
