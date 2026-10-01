META TITLE = "VECTREX STUDIO"

# ============================================================
#  VECTREX STUDIO — boot intro + game menu
#
#  state 0 INTRO : 3D "VS" logo rotating reveal + fade-in +
#                  VECTREX wordmark + jingle.
#  state 1 MENU  : game launcher. Being built up from MINIMAL
#                  on HW (frame budget + broken VIA reads) —
#                  music / joystick / DRAW_RECORDING previews
#                  are commented out for now, added back one at
#                  a time (see NOTE blocks).
#  Transition: ~5 s in (after the jingle envelope + a couple s).
# ============================================================

state: i16 = 0          # 0 = intro, 1 = menu
music_on: i16 = 0       # jingle-started latch (play once)
fade: i16 = 0           # brightness fade-in level, eases 0 -> FADE_MAX
logo_rot: i16 = 0       # logo Y-rotation angle (0..127 = full turn)
t: i16 = 0              # frame counter
sel: i16 = 0            # menu: selected game index
nav_latch: i16 = 0      # menu: joystick edge latch (one move per push)
jy: i16 = 0             # menu: stick Y this frame, centred on its rest
btn_latch: i16 = 1      # menu: buttons 3/4 act on a press, not while held (1 = wait for release)
not_saved: i16 = 0      # menu: frames left showing "NOT SAVED" after a calibration

FADE_MAX: i16 = 80     # peak brightness
SPIN_FRAMES: i16 = 128  # spin for 2 full turns (~2.56 s), covers the jingle
MENU_START: i16 = 250   # frame to switch to the menu (~5 s @ 50 fps)


def main():
    pass


def loop():
    t = t + 1

    # kick off the jingle on the first frame (latched so it plays once)
    if music_on == 0:
        music_on = 1
        PLAY_MUSIC("jingle")

    # ============ STATE 0 : INTRO ============
    if state == 0:
        # fade in from black over ~1 s, then hold
        if fade < FADE_MAX:
            fade = fade + 2

        # reveal spin: 2 Y-turns while the jingle plays, settle facing front
        if t < SPIN_FRAMES:
            logo_rot = logo_rot + 2
            if logo_rot >= 128:
                logo_rot = logo_rot - 128
        else:
            logo_rot = 0

        SET_INTENSITY(fade)
        PRINT_TEXT(-25,-50, "STUDIO")

        # "VS" 3D logo (upper centre)
        SET_INTENSITY(fade)
        DRAW_VECTOR_3D("logo", 0, logo_rot, 0, 0, 34)

        # VECTREX wordmark (lower centre)
        SET_INTENSITY(fade)
        DRAW_VECTOR("text", 0, -40)

        

        # after the jingle (+ a couple seconds), go to the menu
        if t >= MENU_START:
            state = 1

    # ============ STATE 1 : MENU (minimal) ============
    # elif (not a 2nd if): on the transition frame only the intro block runs and
    # sets state=1; the menu starts NEXT frame → no double-draw overrun.
    elif state == 1:
        # NOTE: deferred until the pieces work on HW —
        #   PLAY_MUSIC("menu_theme")          # audio (jingle already covers it)
        #   DRAW_RECORDING(...) previews       # expensive + big ROM
        # Start MINIMAL: a title + the preview box, to prove the transition and
        # measure the budget. Build the list up from here.

        SET_INTENSITY(80)
        SET_TEXT_SIZE(4)
        PRINT_TEXT(-10, 100, "GAMES")

        # Game list from the SD card (SD_FILE_COUNT / SD_FILE_NAME). VPy owns the
        # navigation + drawing. Up/down moves a highlighted selection; at most 5
        # rows are shown at once, scrolling to keep the selection visible.
        n = SD_FILE_COUNT()
        if n == 0:
            # No card (or a card with no .BIN): same text size as the game rows.
            # At size 4 a cell is ~7.5 units (measured on the tube), so the message
            # has to be short to stay clear of the preview frame, which starts at x ~ +11.
            SET_INTENSITY(80)
            SET_TEXT_SIZE(4)
            PRINT_TEXT(-70, 0, "NO SD")
        else:
            # --- navigation: the stick only, one step per push, round the ends ---
            # The BIOS reads the axes between frames anyway (once, with Joy_Analog's
            # algorithm) and J1_Y() returns that cached value centred on the stick's
            # own rest, which is not 0 (measured 2026-10-02: Y rests at 31..48). Past
            # half the travel counts as a push, so a resting stick never moves it.
            # Up from the first game goes to the last, down from the last to the first.
            jy = J1_Y()
            if jy > 64:
                if nav_latch == 0:
                    sel = sel - 1
                    if sel < 0:
                        sel = n - 1
                    nav_latch = 1
            elif jy < -64:
                if nav_latch == 0:
                    sel = sel + 1
                    if sel >= n:
                        sel = 0
                    nav_latch = 1
            else:
                nav_latch = 0
            if sel >= n:
                sel = n - 1

            # --- scroll window: up to 5 rows, keeping the selection visible ---
            top = 0
            if n > 5:
                top = sel - 2
                if top < 0:
                    top = 0
                if top > n - 5:
                    top = n - 5

            # --- draw the visible rows; selected one is bright ---
            SET_TEXT_SIZE(4)
            row = 0
            i = top
            while i < n and row < 5:
                y = 55 - row * 26
                bright = 40
                if i == sel:
                    bright = 80
                SET_INTENSITY(bright)
                PRINT_TEXT(-85, y, SD_FILE_NAME(i))
                i = i + 1
                row = row + 1

        # preview box (right side)
        SET_INTENSITY(80)
        DRAW_VECTOR("frame", 55, 20)

        # play the selected game's video preview inside the frame (SD .vrec).
        # Emulator-only for now; on real HW this is a no-op until precompiled
        # binary previews exist.
        if n > 0:
            DRAW_SD_PREVIEW(sel, 52, 20, 40)

        # --- buttons, on a PRESS: 3 calibrates, 4 starts the selected game ---
        # Not while held: the calibration screen also closes with button 4, and
        # that same press must not launch a game the moment the menu comes back.
        # LAUNCH_GAME loads <NAME>.BIN and does not return (exit: hold all 4 ~1 s).
        b3 = J1_BUTTON_3()
        b4 = J1_BUTTON_4()
        if b3 == 1 and btn_latch == 0:
            btn_latch = 1
            if CALIBRATE() == 0:
                not_saved = 150
        elif b4 == 1 and btn_latch == 0:
            btn_latch = 1
            if n > 0:
                LAUNCH_GAME(sel)
        elif b3 == 0 and b4 == 0:
            btn_latch = 0

        # --- what the buttons do, at the bottom, centred ---
        # The same size as the game list. Measured on the tube (2026-10-02): a
        # cell at size 4 is ~7.5 units — "AAE OMEGRACE" runs from -85 to +5 — so
        # 22 cells are ~165 and the full sentence fits.
        SET_INTENSITY(60)
        SET_TEXT_SIZE(4)
        PRINT_TEXT(-82, -84, "BUTTON 3 - CALIBRATION")
        PRINT_TEXT(-60, -104, "BUTTON 4 - START")
        if not_saved > 0:
            not_saved = not_saved - 1
            SET_INTENSITY(80)
            PRINT_TEXT(-34, -122, "NOT SAVED")