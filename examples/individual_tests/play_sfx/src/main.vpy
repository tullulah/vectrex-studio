# TEST: PLAY_SFX
# Tests sound effect playback (requires .vsfx files)
# Expected: Press BTN1 → jump SFX, BTN2 → explosion SFX

META TITLE = "PLAY_SFX"
META MUSIC = music1

def main():
    pass

def loop():
    PRINT_TEXT(-60, 80, "SFX TEST")
    PRINT_TEXT(-80, 50, "BTN1=JUMP")
    PRINT_TEXT(-80, 30, "BTN2=BOOM")

    if J1_BUTTON_1():
        PLAY_SFX("jump")
        DRAW_CIRCLE(0, -20, 15, 100)

    if J1_BUTTON_2():
        PLAY_SFX("explosion")
        DRAW_CIRCLE(0, -20, 30, 100)

    # Visual indicator always visible
    DRAW_CIRCLE(0, -20, 5, 40)
