# gng - Main entry point
# VPy game for Vectrex

META TITLE = "gng"

def main():
    # Called once at startup
    Set_Intensity(127)

def loop():
    # Game loop - called every frame
    Wait_Recal()
    
    # Draw something to show it works
    Move(0, 0)
    Draw_To(50, 50)
    Draw_To(-50, 50)
    Draw_To(-50, -50)
    Draw_To(50, -50)
    Draw_To(50, 50)
