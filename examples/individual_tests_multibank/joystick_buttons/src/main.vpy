# TEST: JOYSTICK_BUTTONS
# Tests reading joystick 1 button states
# Expected: Press buttons, see values change (0=not pressed, 1=pressed)

META TITLE = "J1_BUTTONS"
META MUSIC = music1
META ROM_TOTAL_SIZE = 65536
META ROM_BANK_SIZE = 16384

def main():
    pass

def loop():
    # Read button states
    btn1 = J1_BUTTON_1()
    btn2 = J1_BUTTON_2()
    btn3 = J1_BUTTON_3()
    btn4 = J1_BUTTON_4()

    # Display button states
    PRINT_TEXT(-60, 80, "BTN1")
    PRINT_NUMBER(0, 80, btn1)

    PRINT_TEXT(-60, 60, "BTN2")
    PRINT_NUMBER(0, 60, btn2)

    PRINT_TEXT(-60, 40, "BTN3")
    PRINT_NUMBER(0, 40, btn3)

    PRINT_TEXT(-60, 20, "BTN4")
    PRINT_NUMBER(0, 20, btn4)

    # Draw different colors of circles based on buttons pressed
    if btn1 == 1:
        DRAW_CIRCLE(-40, 0, 10, 80)

    if btn2 == 1:
        DRAW_CIRCLE(0, 0, 10, 80)

    if btn3 == 1:
        DRAW_CIRCLE(40, 0, 10, 80)

    if btn4 == 1:
        DRAW_CIRCLE(0, -40, 10, 80)
