# TEST: SET_TEXT_SIZE
# Tests text scaling at five different scale values (1-8, 8=normal)
# Expected: Five lines of text visible at decreasing sizes top to bottom

META TITLE = "TXTSIZE"

def main():
    SET_INTENSITY(100)

def draw_scales():
    SET_TEXT_SIZE(8)
    PRINT_TEXT(-80, 80, "SIZE 8 NORMAL")
    SET_TEXT_SIZE(6)
    PRINT_TEXT(-80, 40, "SIZE 6")
    SET_TEXT_SIZE(4)
    PRINT_TEXT(-80, 5, "SIZE 4")
    SET_TEXT_SIZE(2)
    PRINT_TEXT(-80, -30, "SIZE 2")
    SET_TEXT_SIZE(1)
    PRINT_TEXT(-80, -60, "SIZE 1 SMALL")
    SET_TEXT_SIZE(8)

def loop():
    draw_scales()
