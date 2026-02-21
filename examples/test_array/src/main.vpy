# test_array - Test arrays with different types
META MUSIC = music1
# u8 array (1 byte per element) - 8 elements = 8 bytes total
counters: u8 = [10, 20, 30, 40, 50, 60, 70, 80]

# i16 array (2 bytes per element) - 4 elements = 8 bytes total
positions: i16 = [0, 100, -100, 50]

index: u8 = 0

def main():
    index = 0
    SET_INTENSITY(100)

def loop():
    # Increment index through u8 array
    index = index + 1
    if index > 7:
        index = 0

    # Draw line at position from i16 array
    MOVE(positions[0], positions[1])
    DRAW_LINE(0, 0, counters[index], 0, 100)

    PRINT_TEXT(0, 0, "ARRAY")
