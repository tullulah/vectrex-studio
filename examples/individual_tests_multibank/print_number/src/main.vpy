# TEST: PRINT_NUMBER
# Tests numeric display functionality
# Expected: Counter increments each frame from 0 to 32767

META TITLE = "PRINT_NUMBER"
META MUSIC = music1
META ROM_TOTAL_SIZE = 65536
META ROM_BANK_SIZE = 16384

counter = 0

def main():
    counter = 0

def loop():
    # Display counter and its value
    PRINT_TEXT(-80, 0, "COUNTER")
    PRINT_NUMBER(30, 0, counter)
    PRINT_TEXT(-80, -30, "FIXED VAL")
    PRINT_NUMBER(30, -30, 9999)
    # Increment counter each frame
    counter = counter + 1

