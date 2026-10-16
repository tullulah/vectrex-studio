META TITLE = "WANDER"

# Fixed camera. wander_test has no player, so there is nothing for the camera to
# follow — it stays put and the whole level (both platforms + the wander enemy)
# fits on screen. The enemy wanders within its area and jumps to the other one.
# (In a real scrolling game the camera would track the PLAYER, not an enemy.)

def main():
    LOAD_LEVEL("wlevel")
    SPAWN_ENEMIES("wlevel")
    SET_CAMERA_X(0)
    SET_CAMERA_Y(0)

def loop():
    SHOW_LEVEL()
    UPDATE_ENEMIES()
    DRAW_ENEMIES()
