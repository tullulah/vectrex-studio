# TEST: RANDOM_NUMBERS
# Tests rand() and rand_range() functions
# Expected: Random dots scattered on screen, changing each frame

META TITLE = "RAND"
META MUSIC = music1
META ROM_TOTAL_SIZE = 65536
META ROM_BANK_SIZE = 16384

rx1 = 0
ry1 = 0
rx2 = 0
ry2 = 0
rx3 = 0
ry4 = 0

def main():
    rx1 = 0
    ry1 = 0
    rx2 = 0
    ry2 = 0
    rx3 = 0
    ry4 = 0

def loop():
    PRINT_TEXT(-50, 90, "RANDOM")
    
    # Generate random positions and draw dots
    rx1 = rand_range(-80, 80)
    ry1 = rand_range(-60, 60)
    DRAW_CIRCLE(rx1, ry1, 20, 100)

    rx2 = rand_range(-80, 80)
    ry2 = rand_range(-60, 60)
    DRAW_CIRCLE(rx2, ry2, 20, 80)

    rx3 = rand_range(-80, 80)
    ry3 = rand_range(-60, 60)
    DRAW_CIRCLE(rx3, ry3, 20, 60)
