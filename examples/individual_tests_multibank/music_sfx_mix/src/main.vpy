# TEST: MUSIC_SFX_MIX
# Tests simultaneous music + SFX playback
# Expected: pang_theme plays; BTN1=laser, BTN2=boom, BTN3=jump, BTN4=coin

META TITLE = "MUSICSFX"
META MUSIC = music1
META ROM_TOTAL_SIZE = 65536
META ROM_BANK_SIZE = 16384

sfx_timer = 0
last_sfx = 0
radius = 0

def main():
    PLAY_MUSIC("music1")
    sfx_timer = 0
    last_sfx = 0

def loop():
    PRINT_TEXT(-60, 80, "MUSIC+SFX")
    PRINT_TEXT(-60, 55, "B1=LASER")
    PRINT_TEXT(-60, 38, "B2=BOOM")
    PRINT_TEXT(-60, 21, "B3=JUMP")
    PRINT_TEXT(-60, 4, "B4=COIN")

    if J1_BUTTON_1():
        PLAY_SFX("laser")
        sfx_timer = 20
        last_sfx = 1

    if J1_BUTTON_2():
        PLAY_SFX("explosion1")
        sfx_timer = 20
        last_sfx = 2

    if J1_BUTTON_3():
        PLAY_SFX("jump")
        sfx_timer = 20
        last_sfx = 3

    if J1_BUTTON_4():
        PLAY_SFX("coin")
        sfx_timer = 20
        last_sfx = 4

    # Decay timer
    if sfx_timer > 0:
        sfx_timer = sfx_timer - 1

    # Visual: show which SFX fired as expanding ring
    radius = 20 - sfx_timer
    if sfx_timer > 0:
        DRAW_CIRCLE(0, -30, radius, 100)
        if last_sfx == 1:
            DRAW_LINE(-10, -30, 10, -30, 100)
        if last_sfx == 2:
            DRAW_CIRCLE(0, -30, radius + 8, 80)
        if last_sfx == 3:
            DRAW_LINE(0, -20, 0, -40, 100)
        if last_sfx == 4:
            DRAW_CIRCLE(0, -30, 4, 127)
