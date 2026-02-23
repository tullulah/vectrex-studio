# TEST: PRINT_NUMBER
# Tests numeric display functionality
# Expected: Counter increments each frame from 0 to 32767

META TITLE = "PRINT_NUMBER"
META MUSIC = music1

counter = 0

def main():
    counter = 0

def loop():
    # Display counter and its value
    PRINT_TEXT(-40, 80, "COUNTER")
    PRINT_NUMBER(-40, 70, counter)

    # Display test values
    PRINT_TEXT(-40, 50, "VAL")
    PRINT_NUMBER(-40, 40, 12345)

    # Increment counter each frame
    counter = counter + 1
