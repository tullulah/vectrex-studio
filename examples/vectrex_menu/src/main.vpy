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
scroll: i16 = 0         # index of the top visible entry (pagination)
music_on: i16 = 0       # PLAY_MUSIC latch (start once)
t: i16 = 0              # frame counter (drives the preview animation)
last_jy: i16 = 0        # joystick edge detection (NOT 'prev_y' — VPy names
                        # are case-insensitive and it would collide with PREV_Y!)
flash: i16 = 0          # launch feedback flash counter

GAME_COUNT: i16 = 6
PAGE_SIZE: i16 = 4      # entries visible at once (rest scroll)
PREVIEW_DIV: i16 = 3    # menu_fps (~50) / recording_fps (15) — slows preview to real speed

# layout
LIST_X: i16 = -110      # game list left edge
LIST_Y0: i16 = 30       # first entry y
LIST_DY: i16 = -24      # entry spacing (downwards)
PREV_X: i16 = 55        # preview box centre
PREV_Y: i16 = 0
PREV_HW: i16 = 45       # preview box half-WIDTH
PREV_HH: i16 = 58       # preview box half-HEIGHT (taller than wide)


def main():
    pass


def loop():
    t = t + 1

    # start the background music once (MUSIC_UPDATE is auto-injected each frame)
    if music_on == 0:
        music_on = 1
        PLAY_MUSIC("menu_theme")

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
    PRINT_TEXT(-60, 115, "VECTREX STUDIO")

    # ---------- pagination: scroll so `selected` stays in the visible window ----------
    if selected < scroll:
        scroll = selected
    if selected >= scroll + PAGE_SIZE:
        scroll = selected - PAGE_SIZE + 1

    # ---------- game list (paginated window of PAGE_SIZE entries) ----------
    SET_TEXT_SIZE(6)
    slot = 0
    while slot < PAGE_SIZE:
        gidx = scroll + slot
        if gidx < GAME_COUNT:
            y = LIST_Y0 + slot * LIST_DY
            if gidx == selected:
                SET_INTENSITY(120)  # highlighted: bright
                # selector chevron
                DRAW_LINE(LIST_X - 14, y - 8, LIST_X - 6, y - 4, 120)
                DRAW_LINE(LIST_X - 6, y - 4, LIST_X - 14, y, 120)
            else:
                SET_INTENSITY(55)   # rest: dim
            if gidx == 0:
                PRINT_TEXT(LIST_X, y, "SNOW BROS")
            elif gidx == 1:
                PRINT_TEXT(LIST_X, y, "PANG")
            elif gidx == 2:
                PRINT_TEXT(LIST_X, y, "CLOCK. CRYPT")
            elif gidx == 3:
                PRINT_TEXT(LIST_X, y, "STAR HOP")
            elif gidx == 4:
                PRINT_TEXT(LIST_X, y, "MARIO")
            elif gidx == 5:
                PRINT_TEXT(LIST_X, y, "SOLITAIRE")
        slot = slot + 1

    # ---------- scroll indicators (triangles) ----------
    # up triangle if entries exist above the window
    if scroll > 0:
        DRAW_LINE(LIST_X + 30, LIST_Y0 + 16, LIST_X + 38, LIST_Y0 + 24, 90)
        DRAW_LINE(LIST_X + 38, LIST_Y0 + 24, LIST_X + 46, LIST_Y0 + 16, 90)
    # down triangle if entries exist below the window
    if scroll + PAGE_SIZE < GAME_COUNT:
        by = LIST_Y0 + PAGE_SIZE * LIST_DY + 12
        DRAW_LINE(LIST_X + 30, by, LIST_X + 38, by - 8, 90)
        DRAW_LINE(LIST_X + 38, by - 8, LIST_X + 46, by, 90)

    # ---------- preview box (right side) ----------
    box = 70
    if flash > 0:
        box = 127  # launch feedback: box flashes bright
    DRAW_LINE(PREV_X - PREV_HW, PREV_Y - PREV_HH, PREV_X + PREV_HW, PREV_Y - PREV_HH, box)
    DRAW_LINE(PREV_X + PREV_HW, PREV_Y - PREV_HH, PREV_X + PREV_HW, PREV_Y + PREV_HH, box)
    DRAW_LINE(PREV_X + PREV_HW, PREV_Y + PREV_HH, PREV_X - PREV_HW, PREV_Y + PREV_HH, box)
    DRAW_LINE(PREV_X - PREV_HW, PREV_Y + PREV_HH, PREV_X - PREV_HW, PREV_Y - PREV_HH, box)

    # ---------- animated preview of the highlighted game ----------
    # Each entry plays its .vrec recording scaled into the preview box.
    # scale 48/128 = 37% → a ~127-wide frame fits the 90-wide box.
    # (Recordings are captured with the IDE emulator's record button.)
    # The menu runs at ~50 fps but the recording was captured at 15 fps, so
    # advance the preview frame only every ~3 menu frames (t / PREVIEW_DIV) or
    # it plays ~3x too fast. PREVIEW_DIV = round(menu_fps / recording_fps).
    preview_frame = t / PREVIEW_DIV
    if selected == 0:
        DRAW_RECORDING("snowbros_preview", PREV_X, PREV_Y, 48, preview_frame)
    elif selected == 1:
        DRAW_RECORDING("pang_preview", PREV_X, PREV_Y, 48, preview_frame)
    elif selected == 2:
        DRAW_RECORDING("clockmakers_preview", PREV_X, PREV_Y, 48, preview_frame)
    elif selected == 3:
        DRAW_RECORDING("star_hop_preview", PREV_X, PREV_Y, 48, preview_frame)
    elif selected == 4:
        DRAW_RECORDING("mario_preview", PREV_X, PREV_Y, 48, preview_frame)
    elif selected == 5:
        DRAW_RECORDING("solitaire_preview", PREV_X, PREV_Y, 48, preview_frame)

