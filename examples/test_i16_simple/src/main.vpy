# test_i16 - Test signed 16-bit (-32768 to +32767)

value: i16 = 0

def main():
    value = -1000
    SET_INTENSITY(100)

def loop():
    value = value + 50
    MOVE(0, 0)
    DRAW_LINE(0, 0, 50, 50, 100)
    PRINT_TEXT(0, 0, "I16TEST")
