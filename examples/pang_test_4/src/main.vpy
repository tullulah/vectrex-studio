# TEST 4: Add Global Arrays (Const Arrays)
# Tests: Const array initialization, array indexing
# Visual: Draw dots at array coordinates, cycle through locations

META TITLE = "PANG_TEST_4"
META MUSIC = music1

screen = 0
current_location = 0
button_pressed = 0

const location_x_coords = [40, -40, 20, 50, -85]
const location_y_coords = [110, -20, 40, 70, -40]
const num_locations = 5

def main():
    screen = 0
    current_location = 0
    button_pressed = 0

def loop():
    # Cycle through locations with button
    if J1_BUTTON_1() == 1 and button_pressed == 0:
        current_location = current_location + 1
        if current_location >= num_locations:
            current_location = 0
    button_pressed = J1_BUTTON_1()

    # Visual feedback: draw circle at current location
    loc_x = location_x_coords[current_location]
    loc_y = location_y_coords[current_location]

    DRAW_CIRCLE(loc_x, loc_y, 15, 100)
