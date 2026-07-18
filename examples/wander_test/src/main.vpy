META TITLE = "WANDER"

# Bounded camera demo: the camera pans back and forth within the level instead of
# scrolling off to infinity, so the wander enemy stays on screen. cam ping-pongs
# between -CAM_LIMIT and +CAM_LIMIT (well inside worldBounds x:[-96,95]).
cam = 0
cam_dir = 1
CAM_LIMIT = 40

def main():
    LOAD_LEVEL("wlevel")
    SPAWN_ENEMIES("wlevel")

def loop():
    UPDATE_ENEMIES()
    DRAW_ENEMIES()
    cam = cam + cam_dir
    if cam > CAM_LIMIT:
        cam_dir = -1
    if cam < 0 - CAM_LIMIT:
        cam_dir = 1
    SET_CAMERA_X(cam)
