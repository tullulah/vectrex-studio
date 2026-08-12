# donkey - Main entry point
# VPy game for Vectrex

META TITLE = "donkey"

def main():
    # Called once at startup
    Set_Intensity(85)

    load_level("floor1")

def loop():
    # Game loop - called every frame
    show_level()

