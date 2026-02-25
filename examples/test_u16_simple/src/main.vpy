# test_u16 - Test unsigned 16-bit (0-65535)

value: u16 = 0

def main():
    value = 1000
    SET_INTENSITY(100)

def loop():
    value = value + 100
    MOVE(0, 0)
    DRAW_LINE(0, 0, 50, 50, 100)
    PRINT_TEXT(0, 0, "U16TEST")
