# TEST: MATH_FUNCTIONS
# Tests basic math functions: abs, min, max, clamp
# Expected: Values display correctly on screen

META TITLE = "MATH_FUNC"
META MUSIC = music1

def main():
    pass

def loop():
    # Test abs
    val1 = abs(-50)
    PRINT_TEXT(-60, 80, "ABS(-50):")
    PRINT_NUMBER(-20, 80, val1)

    # Test min
    val2 = min(30, 70)
    PRINT_TEXT(-60, 70, "MIN(30,70):")
    PRINT_NUMBER(-20, 70, val2)

    # Test max
    val3 = max(30, 70)
    PRINT_TEXT(-60, 60, "MAX(30,70):")
    PRINT_NUMBER(-20, 60, val3)

    # Test clamp
    val4 = clamp(150, 0, 100)
    PRINT_TEXT(-60, 50, "CLAMP(150):")
    PRINT_NUMBER(-20, 50, val4)
