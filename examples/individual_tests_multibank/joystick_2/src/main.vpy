# TEST: JOYSTICK_2
# Tests Player 2 joystick: J2_X, J2_Y, J2_BUTTON_1-4
# Expected: Crosshair follows J2, buttons light up indicators

META TITLE = "JOY2"
META MUSIC = music1
META ROM_TOTAL_SIZE = 65536
META ROM_BANK_SIZE = 16384

jx = 0
jy = 0

def main():
    jx = 0
    jy = 0

def loop():
    PRINT_TEXT(-50, 90, "JOY P2")

    # Read joystick 2 position
    jx = J2_X() / 2
    jy = J2_Y() / 2

    # Draw crosshair at joystick position
    DRAW_LINE(jx - 8, jy, jx + 8, jy, 80)
    DRAW_LINE(jx, jy - 8, jx, jy + 8, 80)

    # Button indicators (bottom row)
    if J2_BUTTON_1():
        DRAW_CIRCLE(-45, -60, 6, 100)
    DRAW_CIRCLE(-45, -60, 6, 30)

    if J2_BUTTON_2():
        DRAW_CIRCLE(-15, -60, 6, 100)
    DRAW_CIRCLE(-15, -60, 6, 30)

    if J2_BUTTON_3():
        DRAW_CIRCLE(15, -60, 6, 100)
    DRAW_CIRCLE(15, -60, 6, 30)

    if J2_BUTTON_4():
        DRAW_CIRCLE(45, -60, 6, 100)
    DRAW_CIRCLE(45, -60, 6, 30)

    # Labels
    PRINT_TEXT(-52, -75, "1 2 3 4")
