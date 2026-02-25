# TEST: DRAW_LINE
# Tests basic line drawing
# Expected: A regular pentagon centered on screen

META TITLE = "DRAW_LINE"
META MUSIC = music1

def main():
    pass

def loop():
    # Pentagon - radius 60, vertices starting at top (90deg), going clockwise
    # V0=(0,60)  V1=(-57,19)  V2=(-35,-49)  V3=(35,-49)  V4=(57,19)
    
    PRINT_TEXT( -60, 0, "TEST")
    PRINT_NUMBER(0, 0, 123)

    DRAW_LINE(0, 60, -57, 19, 80)
    DRAW_LINE(-57, 19, -35, -49, 80)
    DRAW_LINE(-35, -49, 35, -49, 80)
    DRAW_LINE(35, -49, 57, 19, 80)
    DRAW_LINE(57, 19, 0, 60, 80)

    #PRINT_TEXT( -60, 0, "TEST")    
    #PRINT_NUMBER(0, 0, 123) 
   

 
