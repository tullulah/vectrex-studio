# test_i8 - Test signed 8-bit (-128 to +127)
META MUSIC  = music1
value: u16 = 0

def main():
    value = 10
    SET_INTENSITY(100)

def loop():
    value = value - 1

    PRINT_TEXT(value, 0, "I8TEST")
