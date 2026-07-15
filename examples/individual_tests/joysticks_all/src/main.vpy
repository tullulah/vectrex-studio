# TEST: ALL JOYSTICKS — read J1 + J2 axes and buttons, visualise everything.
#
# Layout:
#   left half  — Player 1 panel: crosshair, B1..B4 indicators, "P1" label
#   right half — Player 2 panel: crosshair, B1..B4 indicators, "P2" label
#
# Buttons use if/else so the held circle is BIG and BRIGHT, the released one
# is SMALL and dim. Easy to tell apart even with phosphor persistence.
#
# Controls (jsvecx default):
#   P1 joystick : WASD / arrows
#   P1 buttons  : Z X C V    (inputManager keymap)
#   P2 joystick : second gamepad axes  (configure in Joystick dialog)
#   P2 buttons  : J K L M    (frontend P2 keymap) or second gamepad face btns

META TITLE = "JOY12"

def main():
    SET_INTENSITY(80)

def draw_btn(x, y, pressed):
    if pressed == 1:
        DRAW_CIRCLE(x, y, 7, 127)
    else:
        DRAW_CIRCLE(x, y, 3, 25)

def draw_panel(cx, jx, jy, b1, b2, b3, b4):
    sx = cx + jx / 4
    sy = jy / 2
    DRAW_LINE(sx - 6, sy, sx + 6, sy, 90)
    DRAW_LINE(sx, sy - 6, sx, sy + 6, 90)
    DRAW_RECT(cx - 32, 32, 64, 64, 25)
    b_y = 0 - 50
    b_x0 = cx - 24
    draw_btn(b_x0, b_y, b1)
    draw_btn(b_x0 + 16, b_y, b2)
    draw_btn(b_x0 + 32, b_y, b3)
    draw_btn(b_x0 + 48, b_y, b4)

def loop():
    SET_INTENSITY(80)
    PRINT_TEXT(0 - 32, 110, "JOY 1+2")

    # Player 1 panel (left half)
    PRINT_TEXT(0 - 54, 50, "P1")
    draw_panel(0 - 48, J1_X(), J1_Y(), J1_BUTTON_1(), J1_BUTTON_2(), J1_BUTTON_3(), J1_BUTTON_4())

    # Player 2 panel (right half)
    PRINT_TEXT(42, 50, "P2")
    draw_panel(48, J2_X(), J2_Y(), J2_BUTTON_1(), J2_BUTTON_2(), J2_BUTTON_3(), J2_BUTTON_4())

    # DEBUG: raw axis values, offset +128 so centre reads 128 (PRINT_NUMBER is 0-9999)
    PRINT_NUMBER(0 - 78, 90, J1_X() + 128)
    PRINT_NUMBER(0 - 78, 78, J1_Y() + 128)
    PRINT_NUMBER(30, 90, J2_X() + 128)
    PRINT_NUMBER(30, 78, J2_Y() + 128)
