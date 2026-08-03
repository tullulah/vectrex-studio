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
        #   J1_Y() / J1_BUTTON_1() navigation # VIA read path broken on the cart
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
            # At size 4 a cell is 14 px wide, so the message has to be short to
            # stay clear of the preview frame, which starts at x ~ +11.
            SET_INTENSITY(80)
            SET_TEXT_SIZE(4)
            PRINT_TEXT(-70, 0, "NO SD")
        else:
            # --- navigation: J1 buttons 1 (up) / 2 (down), edge-latched ---
            # Digital buttons, NOT the analog stick: reading the analog axes runs
            # a SAR against the DAC/comparator that perturbs the PSG → speaker
            # noise + stretched vectors every frame. Buttons are clean.
            if J1_BUTTON_1() == 1:
                if nav_latch == 0:
                    sel = sel - 1
                    nav_latch = 1
            elif J1_BUTTON_2() == 1:
                if nav_latch == 0:
                    sel = sel + 1
                    nav_latch = 1
            else:
                nav_latch = 0
            if sel < 0:
                sel = 0
            if sel >= n:
                sel = n - 1

            # --- launch the selected game with button 4 ---
            # LAUNCH_GAME loads <NAME>.BIN from the SD into RAM and jumps to it;
            # it does not return. Exit back here = hold all 4 buttons ~1 s.
            if J1_BUTTON_4() == 1:
                LAUNCH_GAME(sel)

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