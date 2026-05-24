# TEST: ALL JOYSTICKS — read J1 + J2 axes and buttons, visualise everything.
#
# Layout:
#   left half  — Player 1 panel: crosshair, B1..B4 indicators, "P1" label
#   right half — Player 2 panel: crosshair, B1..B4 indicators, "P2" label
#
# When a button is held its circle fills bright; otherwise it shows a dim
# outline so you can always see where the indicators are.
#
# Controls (jsvecx default):
#   P1 joystick : WASD / arrows
#   P1 buttons  : 1 2 3 4 (or whatever the gamepad mapping uses)
#   P2 buttons  : J K L M   (added in IDE specifically for this test)

META TITLE = "JOY12"

def main():
    pass

def draw_panel(cx, jx, jy, b1, b2, b3, b4):
    # Crosshair at joystick position (scaled to fit half-screen panel)
    sx = cx + jx / 4
    sy = jy / 2
    DRAW_LINE(sx - 6, sy, sx + 6, sy, 90)
    DRAW_LINE(sx, sy - 6, sx, sy + 6, 90)
    # Bounding box of the joystick panel
    DRAW_RECT(cx - 32, 32, 64, 64, 25)
    # Four button indicators in a row at the bottom of the panel
    b_y = 0 - 50
    b_x0 = cx - 24
    if b1 == 1:
        DRAW_CIRCLE(b_x0, b_y, 5, 110)
    DRAW_CIRCLE(b_x0, b_y, 5, 30)
    if b2 == 1:
        DRAW_CIRCLE(b_x0 + 16, b_y, 5, 110)
    DRAW_CIRCLE(b_x0 + 16, b_y, 5, 30)
    if b3 == 1:
        DRAW_CIRCLE(b_x0 + 32, b_y, 5, 110)
    DRAW_CIRCLE(b_x0 + 32, b_y, 5, 30)
    if b4 == 1:
        DRAW_CIRCLE(b_x0 + 48, b_y, 5, 110)
    DRAW_CIRCLE(b_x0 + 48, b_y, 5, 30)

def loop():
    PRINT_TEXT(0 - 32, 110, "JOY 1+2")

    # Player 1 panel (left half)
    PRINT_TEXT(0 - 54, 50, "P1")
    draw_panel(0 - 48, J1_X(), J1_Y(), J1_BUTTON_1(), J1_BUTTON_2(), J1_BUTTON_3(), J1_BUTTON_4())
    PRINT_TEXT(0 - 76, 0 - 62, "1 2 3 4")

    # Player 2 panel (right half)
    PRINT_TEXT(42, 50, "P2")
    draw_panel(48, J2_X(), J2_Y(), J2_BUTTON_1(), J2_BUTTON_2(), J2_BUTTON_3(), J2_BUTTON_4())
    PRINT_TEXT(20, 0 - 62, "1 2 3 4")

    PRINT_TEXT(0 - 78, 0 - 95, "P2 KEYS J K L M")
