# TEST: JOYSTICK_POSITION
# Tests reading joystick 1 X/Y position
# Expected: Move joystick, see position change in numbers
# Critical: Circle should NOT disappear when moving joystick (regression test for VIA corruption bug)

META TITLE = "JOYSTICK_POS"
META MUSIC = music1
META ROM_TOTAL_SIZE = 65536
META ROM_BANK_SIZE = 16384

x = 0
y = 0
circle_x = 0
circle_y = 0

def main():
    pass

def loop():
    # Get joystick position
    x = J1_X()
    y = J1_Y()

    # Display position values
    PRINT_TEXT(-60, 80, "POS X")
    PRINT_NUMBER(10, 80, x)

    PRINT_TEXT(-60, 60, "POS Y")
    PRINT_NUMBER(10, 60, y)

    # Draw a circle that follows joystick position (scaled down)
    # This is the critical test: circle must NOT disappear on input
    circle_x = x / 2
    circle_y = y / 2
    DRAW_CIRCLE(circle_x, circle_y, 15, 80)

     # Read button states
    btn1 = J1_BUTTON_1()
    btn2 = J1_BUTTON_2()
    btn3 = J1_BUTTON_3()
    btn4 = J1_BUTTON_4()

    # Display button states
    PRINT_TEXT(-60, 40, "BTN1")
    PRINT_NUMBER(0, 40, btn1)

    PRINT_TEXT(-60, 20, "BTN2")
    PRINT_NUMBER(0, 20, btn2)

    PRINT_TEXT(-60, 0, "BTN3")
    PRINT_NUMBER(0, 0, btn3)

    PRINT_TEXT(-60, -20, "BTN4")
    PRINT_NUMBER(0, -20, btn4)

