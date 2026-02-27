# TEST: TYPED_NUMBERS
# Tests i8, u8, i16, u16 scalar variables and typed arrays.
# JOY_UP/DOWN = select type row
# BTN1 = increment  BTN2 = decrement  BTN3 = reset all to defaults

META TITLE = "TYPED"
META MUSIC = music1

# ── Typed scalar variables ──────────────────────────────────────────────────
u8_val:  u8  = 200       # unsigned 8-bit   (0 .. 255,   wraps at 256)
i8_val:  i8  = -100      # signed 8-bit     (-128 .. 127, wraps both sides)
u16_val: u16 = 60000     # unsigned 16-bit  (0 .. 65535, wraps at 65536)
i16_val: i16 = -30000    # signed 16-bit    (-32768 .. 32767)

# ── Typed mutable arrays (RAM) ──────────────────────────────────────────────
u8_arr:  u8  = [10, 50, 150, 250]          # 4 × 1 byte  = 4 bytes RAM
i8_arr:  i8  = [-120, -40, 40, 120]        # 4 × 1 byte  = 4 bytes RAM
u16_arr: u16 = [0, 1000, 30000, 65535]     # 4 × 2 bytes = 8 bytes RAM
i16_arr: i16 = [-32000, -500, 500, 32000]  # 4 × 2 bytes = 8 bytes RAM

# ── Const arrays (ROM, read-only) ──────────────────────────────────────────
const ROW_Y = [100, 65, 30, -5]   # Y screen positions for the 4 type rows

# ── State variables ─────────────────────────────────────────────────────────
selected: u8  = 0    # which row is active: 0=u8  1=i8  2=u16  3=i16
cooldown: u8  = 0    # debounce counter
arr_idx:  u8  = 0    # cycles 0-3 to show array elements one by one
arr_tick: u8  = 0    # frame counter for auto-cycling
joy_y:    i16 = 0

def main():
    SET_INTENSITY(100)
    selected = 0
    cooldown = 0
    arr_idx  = 0
    arr_tick = 0

def loop():
    # ── Auto-cycle array index every ~30 frames ─────────────────────────────
    arr_tick = arr_tick + 1
    if arr_tick > 30:
        arr_tick = 0
        arr_idx  = arr_idx + 1
        if arr_idx > 3:
            arr_idx = 0

    # ── Read joystick & manage cooldown ─────────────────────────────────────
    joy_y = J1_Y()

    if cooldown > 0:
        cooldown = cooldown - 1

    if cooldown == 0:
        # Navigate rows with joystick
        if joy_y > 60:
            if selected > 0:
                selected = selected - 1
            cooldown = 15

        if joy_y < -60:
            if selected < 3:
                selected = selected + 1
            cooldown = 15

        # BTN1: increment the selected typed scalar
        if J1_BUTTON_1():
            if selected == 0:
                u8_val  = u8_val  + 1      # wraps 255 → 0
            if selected == 1:
                i8_val  = i8_val  + 1      # wraps 127 → -128
            if selected == 2:
                u16_val = u16_val + 100    # wraps 65535 → 0
            if selected == 3:
                i16_val = i16_val + 100    # wraps 32767 → -32768
            cooldown = 4

        # BTN2: decrement the selected typed scalar
        if J1_BUTTON_2():
            if selected == 0:
                u8_val  = u8_val  - 1      # wraps 0 → 255
            if selected == 1:
                i8_val  = i8_val  - 1      # wraps -128 → 127
            if selected == 2:
                u16_val = u16_val - 100
            if selected == 3:
                i16_val = i16_val - 100
            cooldown = 4

        # BTN3: reset everything to initial values
        if J1_BUTTON_3():
            u8_val  = 200
            i8_val  = -100
            u16_val = 60000
            i16_val = -30000
            u8_arr[0]  = 10
            u8_arr[1]  = 50
            u8_arr[2]  = 150
            u8_arr[3]  = 250
            i8_arr[0]  = -120
            i8_arr[1]  = -40
            i8_arr[2]  = 40
            i8_arr[3]  = 120
            u16_arr[0] = 0
            u16_arr[1] = 1000
            u16_arr[2] = 30000
            u16_arr[3] = 65535
            i16_arr[0] = -32000
            i16_arr[1] = -500
            i16_arr[2] = 500
            i16_arr[3] = 32000
            cooldown = 15

    # ── Display ─────────────────────────────────────────────────────────────
    # PRINT_TEXT(-45, 120, "TYPED NUMS")
    # PRINT_TEXT(-128, 100, "JY=ROW B1=+ B2=- B3=RST")

    # Row 0 — u8
    PRINT_TEXT(-120, ROW_Y[0], "U8")
    PRINT_NUMBER(-55,  ROW_Y[0], u8_val)
    PRINT_TEXT(5,  ROW_Y[0], "A+")
    PRINT_NUMBER( 30, ROW_Y[0], u8_arr[arr_idx])

    # Row 1 — i8
    PRINT_TEXT(-120, ROW_Y[1], "I8 ")
    PRINT_NUMBER(-55,  ROW_Y[1], i8_val)
    PRINT_TEXT(   5,  ROW_Y[1], "A+")
    PRINT_NUMBER( 30, ROW_Y[1], i8_arr[arr_idx])

    # Row 2 — u16
    PRINT_TEXT(-120, ROW_Y[2], "U16")
    PRINT_NUMBER(-55,  ROW_Y[2], u16_val)
    PRINT_TEXT(   5,  ROW_Y[2], "A+")
    PRINT_NUMBER( 30, ROW_Y[2], u16_arr[arr_idx])

    # Row 3 — i16
    PRINT_TEXT(-120, ROW_Y[3], "I16")
    PRINT_NUMBER(-55,  ROW_Y[3], i16_val)
    PRINT_TEXT(   5,  ROW_Y[3], "A+")
    PRINT_NUMBER( 30, ROW_Y[3], i16_arr[arr_idx])

    # Bottom: show current array index
    PRINT_TEXT(-40, -22, "IDX")
    PRINT_NUMBER(10, -22, arr_idx)

    # Selection cursor (circle on the left of the active row)
    DRAW_CIRCLE(-125, ROW_Y[selected], 10, 100)
