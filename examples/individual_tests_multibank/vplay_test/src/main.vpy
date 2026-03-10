# TEST: VPLAY_TEST
# Physics demo: balls bounce, coin falls with gravity.
# All objects + physics defined in assets/playground/demo_level.vplay — not in code.
META TITLE = "VPLAYTST"
META MUSIC = music1
META ROM_TOTAL_SIZE = 65536
META ROM_BANK_SIZE = 16384

def main():
    #LOAD_LEVEL("demo_level")
    LOAD_LEVEL("test2")

def loop():
    PRINT_TEXT(-55, 120, "VPLAY TEST")
    UPDATE_LEVEL()
    SHOW_LEVEL()
