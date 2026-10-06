# snowbros_sbt - Snow Bros port traced from the arcade ROM
#
# Reference material (regenerate any of it with the tools/ scripts):
#   tiles/tilesheet_used.png        every tile the attract used, real palettes
#   sprites/frame_*.png             362 composed frames captured from attract
#   rom_sheets/seg_0eda/            dragon boss + golden bird + hatching eggs
#   rom_sheets/frame_0e00_7x4_*.png pink face boss (2 frames)
#   rom_sheets/strip_w*.png         whole gfx ROM wrapped at 2/4/5/7 tiles
#   rom_sheets/rom_palettes.png     the game's 112 palettes (ROM 0x10000)
#   assets/images/                  curated copies for editor tracing overlays
#
# Asset naming: semantic names, one .vec per frame
#   nick_walk_0.vec, ball_roll_1.vec, boss1_calm.vec, bird_fly_3.vec ...

META TITLE = "SNOW BROS"

# --- game states ---
STATE_TITLE = 0
STATE_GAME = 1

state: u8 = 0

# player
px: i16 = 0
py: i16 = -90
anim: u8 = 0

def main():
    pass

def loop():
    if state == STATE_TITLE:
        SET_INTENSITY(110)
        PRINT_TEXT(-60, 40, "SNOW BROS")
        PRINT_TEXT(-80, 0, "NICK AND TOM")
        PRINT_TEXT(-70, -40, "PRESS 1")
        if J1_BUTTON_1():
            state = STATE_GAME
    else:
        SET_INTENSITY(110)
        dx = clamp(J1_X() / 32, -3, 3)
        px = px + dx
        if px < -110:
            px = -110
        if px > 110:
            px = 110
        # walk cycle while moving, stand when idle
        if dx != 0:
            anim = anim + 1
            if anim >= 16:
                anim = 0
            if anim < 8:
                DRAW_VECTOR("nick_walk_0", px, py)
            else:
                DRAW_VECTOR("nick_walk_1", px, py)
        else:
            DRAW_VECTOR("nick_stand", px, py)
        # scene props to eyeball the traced assets
        DRAW_VECTOR("enemy_pink_0", 60, -90)
        DRAW_VECTOR("ball", -60, -90)
