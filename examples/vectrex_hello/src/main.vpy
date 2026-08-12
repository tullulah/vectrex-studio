# Vectrex "Hello World" — text draw test for the RP2350 debug cart
# The 6809 runs this ROM; the BIOS Print_Str routine draws the text.

def main():
    SET_INTENSITY(100)

def loop():
    SET_INTENSITY(100)
    PRINT_TEXT(-60, 20, "HELLO WORLD")
    PRINT_TEXT(-70, -10, "DEBUG CART OK")
