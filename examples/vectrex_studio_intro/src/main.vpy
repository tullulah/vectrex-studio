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
        PRINT_TEXT(-42, 70, "GAMES")

        # NOTE: the game list (SNOW BROS / PANG / ...) is ~29 glyphs ≈ 26 ms on
        # single-core (~1 ms/glyph via the per-glyph Reset0Ref) → overruns the
        # 20 ms budget → flicker. The full text menu (list + nav + DRAW_RECORDING
        # previews) is a DUAL-CORE deliverable (retained-mode engine), same as the
        # STUDIO subtitle. Kept minimal here: title + preview box (~5.7 ms, stable).

        # preview box (right side)
        SET_INTENSITY(80)
        DRAW_VECTOR("frame", 55, 0)