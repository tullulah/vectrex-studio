# test_u8 - Test unsigned 8-bit
META MUSIC = music1

value :u8 = 0

def main():
    value = 50
    SET_INTENSITY(100)

def loop():
    value = value + 1
    # MOVE(0, 0)
    # DRAW_LINE(0, 0, value, 0, 100)
    PRINT_NUMBER(value, 100, value)

    PRINT_TEXT(value,0,"HOLA")
