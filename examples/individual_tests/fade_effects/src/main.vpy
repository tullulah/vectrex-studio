# TEST: FADE_EFFECTS
# Demonstrates brightness control via variable intensity.
# On a vector display, "fading" means redrawing at lower intensity each frame —
# there is no framebuffer, so the screen is only lit while vectors are being drawn.
# B1=dim, B2=brighten (hold button for smooth fade)
# Expected: box dims/brightens continuously as buttons are held

META TITLE = "FADE"
META MUSIC = music1

brightness = 100

def main():
    brightness = 100

def loop():
    PRINT_TEXT(-60, 90, "BRIGHTNESS")
    PRINT_TEXT(-80, 70, "B1=DIM B2=BRIGHT")

    if J1_BUTTON_1():
        if brightness > 5:
            brightness = brightness - 5

    if J1_BUTTON_2():
        if brightness < 120:
            brightness = brightness + 5

    DRAW_LINE(-40, -40, 40, -40, brightness)
    DRAW_LINE(40, -40, 40, 40, brightness)
    DRAW_LINE(40, 40, -40, 40, brightness)
    DRAW_LINE(-40, 40, -40, -40, brightness)
    DRAW_LINE(-40, -40, 40, 40, brightness)
    DRAW_LINE(40, -40, -40, 40, brightness)
