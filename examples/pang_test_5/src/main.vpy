# TEST 5: Add Music (PLAY_MUSIC)
# Tests: Builtin function generation, music playback
# Visual: Pulsing intensity to show music is playing

META TITLE = "PANG_TEST_5"
META MUSIC = music1

screen = 0
current_music = -1
pulse_intensity = 50
pulse_direction = 1

def main():
    screen = 0
    current_music = -1
    pulse_intensity = 50
    pulse_direction = 1

def loop():
    if current_music == -1:
        PLAY_MUSIC("pang_theme")
        current_music = 0

    # Visual feedback: pulsing circle shows music is playing
    pulse_intensity = pulse_intensity + pulse_direction
    if pulse_intensity >= 127:
        pulse_direction = -1
    if pulse_intensity <= 50:
        pulse_direction = 1

    DRAW_CIRCLE(0, 0, 40, pulse_intensity)
