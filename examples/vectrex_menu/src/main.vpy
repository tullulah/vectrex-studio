META TITLE = "VS MENU"

# ============================================================
#  VECTREX STUDIO — cartridge game menu
#
#  Left: game list, joystick up/down selects, button 1 launches.
#  Right: animated vector preview of the highlighted game
#  (recorded from the emulator as a .vrec asset).
# ============================================================

# --- state ---------------------------------------------------
selected: i16 = 0       # highlighted entry
t: i16 = 0              # frame counter (drives the preview animation)
last_jy: i16 = 0        # joystick edge detection (NOT 'prev_y' — VPy names
                        # are case-insensitive and it would collide with PREV_Y!)
flash: i16 = 0          # launch feedback flash counter

GAME_COUNT: i16 = 3

# layout
LIST_X: i16 = -110      # game list left edge
LIST_Y0: i16 = 30       # first entry y
LIST_DY: i16 = -24      # entry spacing (downwards)
PREV_X: i16 = 55        # preview box centre
PREV_Y: i16 = 0
PREV_HALF: i16 = 45     # preview box half-size


def main():
    pass


def loop():
    t = t + 1

    # ---------- input: joystick up/down with edge detection ----------
    jy = J1_Y()
    if jy < -40:
        if last_jy >= -40:
            selected = selected + 1
            if selected >= GAME_COUNT:
                selected = 0
    if jy > 40:
        if last_jy <= 40:
            selected = selected - 1
            if selected < 0:
                selected = GAME_COUNT - 1
    last_jy = jy

    # button 1 = launch (flash feedback until the loader exists)
    if J1_BUTTON_1():
        flash = 12
    if flash > 0:
        flash = flash - 1

    # ---------- title ----------
    SET_INTENSITY(110)
    SET_TEXT_SIZE(7)
    PRINT_TEXT(-60, 85, "VECTREX STUDIO")

    # ---------- game list ----------
    SET_TEXT_SIZE(6)
    i = 0
    while i < GAME_COUNT:
        y = LIST_Y0 + i * LIST_DY
        if i == selected:
            SET_INTENSITY(120)  # highlighted: bright
            # selector chevron
            DRAW_LINE(LIST_X - 14, y - 8, LIST_X - 6, y - 4, 120)
            DRAW_LINE(LIST_X - 6, y - 4, LIST_X - 14, y, 120)
        else:
            SET_INTENSITY(55)   # rest: dim
        if i == 0:
            PRINT_TEXT(LIST_X, y, "SNOW BROS")
        if i == 1:
            PRINT_TEXT(LIST_X, y, "PANG")
        if i == 2:
            PRINT_TEXT(LIST_X, y, "INTRO")
        i = i + 1

    # ---------- preview box (right side) ----------
    box = 70
    if flash > 0:
        box = 127  # launch feedback: box flashes bright
    DRAW_LINE(PREV_X - PREV_HALF, PREV_Y - PREV_HALF, PREV_X + PREV_HALF, PREV_Y - PREV_HALF, box)
    DRAW_LINE(PREV_X + PREV_HALF, PREV_Y - PREV_HALF, PREV_X + PREV_HALF, PREV_Y + PREV_HALF, box)
    DRAW_LINE(PREV_X + PREV_HALF, PREV_Y + PREV_HALF, PREV_X - PREV_HALF, PREV_Y + PREV_HALF, box)
    DRAW_LINE(PREV_X - PREV_HALF, PREV_Y + PREV_HALF, PREV_X - PREV_HALF, PREV_Y - PREV_HALF, box)

    # ---------- animated preview of the highlighted game ----------
    # Each entry plays its .vrec recording scaled into the preview box.
    # scale 48/128 = 37% → a ~127-wide frame fits the 90-wide box.
    # (Recordings are captured with the IDE emulator's record button.)
    if selected == 0:
        DRAW_RECORDING("snowbros_preview", PREV_X, PREV_Y, 48, t)
