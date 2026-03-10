# TEST: DRAW_VECTOR
# Tests vector graphics drawing (requires .vec assets)
# For now: tests with lines forming star pattern
# Expected: Vector/star pattern visible on screen

META TITLE = "DRAW_VECTOR"
META MUSIC = music1
META ROM_TOTAL_SIZE = 65536
META ROM_BANK_SIZE = 16384

def main():
    pass

def loop():
    # Draw a star pattern with lines
    DRAW_VECTOR("vec", 0, 0)
    PRINT_TEXT(0,0,"HOLA")
