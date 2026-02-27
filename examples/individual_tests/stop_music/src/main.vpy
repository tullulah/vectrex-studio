# TEST: STOP_MUSIC
# Tests PLAY_MUSIC, STOP_MUSIC, and beep
# Expected: BTN1=play, BTN2=stop, BTN3=beep

META TITLE = "STOPMUSIC"
META MUSIC = music1

playing = 0

def main():
    playing = 0

def loop():
    PRINT_TEXT(-60, 80, "MUSIC CTRL")
    PRINT_TEXT(-80, 50, "B1=PLAY")
    PRINT_TEXT(-80, 30, "B2=STOP")
    PRINT_TEXT(-80, 10, "B3=BEEP")

    if J1_BUTTON_1():
        PLAY_MUSIC("music1")
        playing = 1

    if J1_BUTTON_2():
        STOP_MUSIC()
        playing = 0

    if J1_BUTTON_3():
        beep()

    # Status indicator
    if playing == 1:
        DRAW_CIRCLE(5, -25, 8, 100)
    if playing == 0:
        DRAW_RECT(0, -30, 16, 16, 40)
