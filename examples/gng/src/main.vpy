# gng - Main entry point
# VPy game for Vectrex

META TITLE = "gng"

def main():
    # Called once at startup
    SET_INTENSITY(127)

def loop():
    # Game loop - called every frame (the compiler adds Wait_Recal)

    # Draw something to show it works: a square around the centre
    DRAW_LINE(50, 50, -50, 50, 127)
    DRAW_LINE(-50, 50, -50, -50, 127)
    DRAW_LINE(-50, -50, 50, -50, 127)
    DRAW_LINE(50, -50, 50, 50, 127)
