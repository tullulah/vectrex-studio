META TITLE = "WANDER"
cam = 0
def main():
    LOAD_LEVEL("wlevel")
    SPAWN_ENEMIES("wlevel")
def loop():
    UPDATE_ENEMIES()
    DRAW_ENEMIES()
    cam = cam + 1
    SET_CAMERA_X(cam)
