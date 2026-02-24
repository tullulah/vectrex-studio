# TEST: JOYSTICK_POSITION
# Tests reading joystick 1 X/Y position
# Expected: Move joystick, see position change in numbers
# Critical: Circle should NOT disappear when moving joystick (regression test for VIA corruption bug)

META TITLE = "JOYSTICK_POS"
META MUSIC = music1

x = 0
y = 0

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
    # circle_x = x / 2
    # circle_y = y / 2
    # DRAW_CIRCLE(circle_x, circle_y, 15, 80)
