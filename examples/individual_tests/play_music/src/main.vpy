# TEST: PLAY_MUSIC
# Tests music playback (requires .vmus file)
# Expected: Music plays in emulator background

META TITLE = "PLAY_MUSIC"
META MUSIC = music1

music_playing = 0

def main():
    music_playing = 1
    PLAY_MUSIC(music1)

def loop():
    PRINT_TEXT(-60, 80, "MUSIC:")
    PRINT_TEXT(-40, 80, "PLAYING")

    # Display status
    if music_playing == 1:
        DRAW_CIRCLE(0, 0, 20, 80)
