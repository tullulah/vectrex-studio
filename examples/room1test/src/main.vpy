# room1test - Main entry point
# VPy game for Vectrex

META TITLE = "ROOMTEST1"
#META INTERLEAVED_FRAMES = 2

camera = 0

def main():
    # Called once at startup
    Set_Intensity(40)
    LOAD_LEVEL("test_scene")

def loop():
    # Game loop - called every frame
    SET_INTENSITY(80)
    SHOW_LEVEL()

    x = J1_X()

    if(x >0 and camera < 670):
        camera +=5
    if(x < 0 and camera > 0):
        camera -=5


    SET_CAMERA_X(camera)

    DEBUG_PRINT(camera)
