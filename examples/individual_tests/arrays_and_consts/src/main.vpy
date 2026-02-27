# TEST: ARRAYS_AND_CONSTS
# Demonstrates const scalars, const arrays, mutable arrays, and variables
# Expected: 4 score slots (A-D), joystick selects row
# BTN1=increment, BTN2=decrement, BTN3=reset all

META TITLE = "ARRAYS"
META MUSIC = music1

# Const scalar — stored in ROM, used as a literal at compile time
const NUM_ITEMS = 4

# Const array — data stored in ROM, read-only at runtime
const row_y = [70, 40, 10, -20]

# Mutable array — allocated in RAM, modified at runtime
item_score = [0, 0, 0, 0]

# Regular variables
selected = 0
cooldown = 0
joy_y = 0
cur_score = 0

def main():
    PLAY_MUSIC("music1")
    selected = 0
    cooldown = 0
    item_score[0] = 0
    item_score[1] = 0
    item_score[2] = 0
    item_score[3] = 0

def loop():
    PRINT_TEXT(-80, 120, "ARRAYS")
    PRINT_TEXT(-80, 106, "JOY=ROW")
    PRINT_TEXT(-80, 92, "B1=+ B2=-")

    # Read joystick
    joy_y = J1_Y()

    # Cooldown countdown
    if cooldown > 0:
        cooldown = cooldown - 1

    if cooldown == 0:
        # Navigate up with joystick
        if joy_y > 60:
            selected = selected - 1
            if selected < 0:
                selected = 0
            cooldown = 15

        # Navigate down with joystick
        if joy_y < -60:
            selected = selected + 1
            if selected > 3:
                selected = NUM_ITEMS - 1
            cooldown = 15

        # BTN1: increment selected score
        if J1_BUTTON_1():
            cur_score = item_score[selected] + 1
            if cur_score > 99:
                cur_score = 99
            item_score[selected] = cur_score
            cooldown = 8

        # BTN2: decrement selected score
        if J1_BUTTON_2():
            cur_score = item_score[selected] - 1
            if cur_score < 0:
                cur_score = 0
            item_score[selected] = cur_score
            cooldown = 8

        # BTN3: reset all scores to zero
        if J1_BUTTON_3():
            item_score[0] = 0
            item_score[1] = 0
            item_score[2] = 0
            item_score[3] = 0
            cooldown = 15

    # Draw all 4 rows — Y positions come from const array
    PRINT_TEXT(-55, row_y[0], "A ")
    PRINT_NUMBER(0, row_y[0], item_score[0])

    PRINT_TEXT(-55, row_y[1], "B ")
    PRINT_NUMBER(0, row_y[1], item_score[1])

    PRINT_TEXT(-55, row_y[2], "C ")
    PRINT_NUMBER(0, row_y[2], item_score[2])

    PRINT_TEXT(-55, row_y[3], "D ")
    PRINT_NUMBER(0, row_y[3], item_score[3])

    # Selection cursor — Y from const array indexed by variable
    DRAW_CIRCLE(-70, row_y[selected], 8, 100)
