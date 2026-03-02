# THE CLOCKMAKER'S CRYPT
# Switzerland, 1887. Konrad Voss is dead. You are the assessor.

META TITLE = "CLOCKCPT"

# ─── Game states ───────────────────────────────────────────────────────────────
const STATE_TITLE  = 0
const STATE_INTRO  = 1
const STATE_ROOM   = 2
const STATE_ENDING = 3

# ─── Rooms ─────────────────────────────────────────────────────────────────────
const ROOM_ENTRANCE  = 0
const ROOM_CLOCKROOM = 1

# ─── Verbs ─────────────────────────────────────────────────────────────────────
const VERB_EXAMINE = 0
const VERB_TAKE    = 1
const VERB_USE     = 2

# ─── Music IDs ─────────────────────────────────────────────────────────────────
const MUSIC_NONE        = 0
const MUSIC_TITLE       = 1
const MUSIC_EXPLORATION = 2

# ─── Puzzle flags ──────────────────────────────────────────────────────────────
# flag_date_known  : player examined the portrait → knows 1887 is the code
# flag_taller_open : workshop door unlocked

# ─── Entrance room hotspot indices ─────────────────────────────────────────────
const ENT_HS_COUNT = 2
const ENT_HS_PAINTING = 0
const ENT_HS_DOOR     = 1

# Hotspot bounding boxes — must match entrance.vplay positions exactly
# Hotspot 0 = canvas/painting (x=260, y=-98)
# Hotspot 1 = locked_door      (x=738, y=-88)
const ENT_HS_X = [260, 738]
const ENT_HS_Y = [-98, -88]
const ENT_HS_W = [25, 40]
const ENT_HS_H = [35, 45]

# ─── Global variables ──────────────────────────────────────────────────────────
screen        = STATE_TITLE
blink_timer   = 0
blink_on      = 0
intro_page    = 0

# Room state
current_room    = ROOM_ENTRANCE
player_x        = 0
player_y        = -115
scroll_x        = 0
player_speed    = 5
current_verb    = VERB_EXAMINE
near_hs         = -1
msg_id          = 0
msg_timer       = 0
room_exit       = 0

# Puzzle flags (0 = not yet, 1 = done)
flag_date_known  = 0
flag_taller_open = 0

# Music state (prevents restarting the same track on room transitions)
current_music = MUSIC_TITLE

# Button edge detection — init to 1 so a release is required before the first
# press is counted. Prevents false triggers at startup on real hardware.
prev_btn1 = 1
prev_btn3 = 1
btn1_fired = 0
btn3_fired = 0

# ─── Entry point ───────────────────────────────────────────────────────────────
def main():
    SET_INTENSITY(100)
    LOAD_LEVEL("entrance")
    PLAY_MUSIC("intro")

# ─── Main loop ─────────────────────────────────────────────────────────────────
def loop():
    # Debounce btn1 — done here in loop() so globals update correctly
    b1 = J1_BUTTON_1()
    btn1_fired = 0
    if b1 == 1 and prev_btn1 == 0:
        btn1_fired = 1
        prev_btn1 = 1
    if b1 == 0:
        prev_btn1 = 0
    # Debounce btn3
    b3 = J1_BUTTON_3()
    btn3_fired = 0
    if b3 == 1 and prev_btn3 == 0:
        btn3_fired = 1
        prev_btn3 = 1
    if b3 == 0:
        prev_btn3 = 0

    if screen == STATE_TITLE:
        draw_title()
    elif screen == STATE_INTRO:
        draw_intro()
    elif screen == STATE_ROOM:
        update_room()
        draw_room()
    elif screen == STATE_ENDING:
        draw_ending()
    
# ═══════════════════════════════════════════════════════════════════════════════
# TITLE SCREEN
# ═══════════════════════════════════════════════════════════════════════════════
def draw_title():
    SET_INTENSITY(120)
    DRAW_VECTOR("crypt_logo", 0, 10)

    blink_timer = blink_timer + 1
    if blink_timer >= 40:
        blink_timer = 0
        if blink_on == 0:
            blink_on = 1
        else:
            blink_on = 0

    if blink_on == 1:
        SET_INTENSITY(100)
        SET_TEXT_SIZE(7)
        PRINT_TEXT(-107, -100, "PUSH BUTTON 1 TO START")

    if btn1_fired == 1:
        intro_page = 0
        screen = STATE_INTRO

# ═══════════════════════════════════════════════════════════════════════════════
# INTRO — 3 story pages
# ═══════════════════════════════════════════════════════════════════════════════
def draw_intro():
    if intro_page == 0:
        SET_INTENSITY(100)
        SET_TEXT_SIZE(7)
        PRINT_TEXT(-105, 50,  "SWITZERLAND, 1887.")
        SET_INTENSITY(80)
        PRINT_TEXT(-120, 25,  "THE ECCENTRIC CLOCKMAKER")
        PRINT_TEXT(-120, 10,  "KONRAD VOSS IS DEAD.")
        PRINT_TEXT(-120, -5,  "THE MUNICIPALITY SENDS")
        PRINT_TEXT(-120, -20, "YOU AS ASSESSOR TO")
        PRINT_TEXT(-120, -35, "INVENTORY HIS ESTATE.")
        SET_INTENSITY(60)
        PRINT_TEXT(-70, -80, "PRESS BUTTON 1")
    elif intro_page == 1:
        SET_TEXT_SIZE(7)
        SET_INTENSITY(100)
        PRINT_TEXT(-120, 50,  "YOU ENTER THE CRYPT.")
        SET_INTENSITY(80)
        PRINT_TEXT(-120, 25,  "THE DOOR CLOSES BEHIND")
        PRINT_TEXT(-120, 10,  "YOU. ALONE.")
        PRINT_TEXT(-120, -10, "GEARS TURN BY THEMSELVES.")
        PRINT_TEXT(-120, -25, "THE SARCOPHAGUS BELOW")
        PRINT_TEXT(-120, -40, "HAS A CLOCKWORK LOCK.")
        SET_INTENSITY(60)
        PRINT_TEXT(-70, -80, "PRESS BUTTON 1")
    elif intro_page == 2:
        SET_TEXT_SIZE(7)
        SET_INTENSITY(100)
        PRINT_TEXT(-120, 40, "FIND THE CLUES.")
        PRINT_TEXT(-120, 25, "SOLVE THE PUZZLES.")
        PRINT_TEXT(-120, 10, "ESCAPE THE CRYPT.")
        SET_INTENSITY(70)
        PRINT_TEXT(-120, -20, "JOYSTICK - MOVE")
        PRINT_TEXT(-120, -35, "BUTTON 1 - INTERACT")
        PRINT_TEXT(-120, -50, "BUTTON 2 - INVENTORY")
        PRINT_TEXT(-120, -65, "BUTTON 3 - CHANGE VERB")
        SET_INTENSITY(60)
        PRINT_TEXT(-70, -90, "PRESS BUTTON 1")

    if btn1_fired == 1:
        if intro_page < 2:
            intro_page = intro_page + 1
        else:
            enter_room(ROOM_ENTRANCE)
            screen = STATE_ROOM

# ═══════════════════════════════════════════════════════════════════════════════
# ROOM — Load & transition
# ═══════════════════════════════════════════════════════════════════════════════
def enter_room(room_id):
    current_room = room_id
    near_hs      = -1
    msg_id       = 0
    msg_timer    = 0
    room_exit    = 0
    if room_id == ROOM_ENTRANCE:
        LOAD_LEVEL("entrance")
        player_x = 0
        player_y = -115
        scroll_x = 0
        SET_CAMERA_X(0)
        if current_music != MUSIC_EXPLORATION:
            PLAY_MUSIC("exploration")
            current_music = MUSIC_EXPLORATION
    elif room_id == ROOM_CLOCKROOM:
        player_x = 70
        player_y = -75
        if current_music != MUSIC_EXPLORATION:
            PLAY_MUSIC("exploration")
            current_music = MUSIC_EXPLORATION

# ═══════════════════════════════════════════════════════════════════════════════
# ROOM — Update (input + logic)
# ═══════════════════════════════════════════════════════════════════════════════
def update_room():
    # ─── Side-scroll camera ────────────────────────────────────────────
    # player_x is in WORLD coordinates (0 .. 640+95)
    # scroll_x is the camera offset (0 .. 640)
    # screen_x = player_x - scroll_x  (what we draw on screen)
    #
    # Behaviour:
    #   - Player at screen center (x==0) → scroll starts
    #   - scroll_x 0..640 → player stays centered, world scrolls
    #   - scroll_x == 0   → player can walk left to screen edge (-90)
    #   - scroll_x == 640  → player can walk right to screen edge (+90)
    # ───────────────────────────────────────────────────────────────────
    debug_print(near_hs)
    joy_x = J1_X()
    if joy_x > 30:
        player_x = player_x + player_speed
    elif joy_x < -30:
        player_x = player_x - player_speed

    # Clamp player_x to world bounds: left edge = -90, right edge = 640 + 90
    player_x = clamp(player_x, -90, 780)

    # Derive ideal camera so player stays at screen center
    # ideal_scroll = player_x  (so screen_x = player_x - scroll_x = 0)
    # Then clamp scroll to valid range [0..670]
    scroll_x = clamp(player_x, 0, 670)

    SET_CAMERA_X(scroll_x)

    # Hotspot proximity check
    near_hs = -1
    debug_print(player_x)
    debug_print(current_room)
    if current_room == ROOM_ENTRANCE:
        check_entrance_hotspots()

    # Message timer (auto-dismiss)
    if msg_timer > 0:
        msg_timer = msg_timer - 1
        if msg_timer == 0 and room_exit == 1:
            room_exit = 0
            enter_room(ROOM_CLOCKROOM)

    # Button 3 — cycle verb (only when no message showing)
    if btn3_fired == 1:
        if msg_timer == 0:
            if current_verb == VERB_USE:
                current_verb = VERB_EXAMINE
            else:
                current_verb = current_verb + 1

    # Button 1 — interact or dismiss message
    if btn1_fired == 1:
        if msg_timer > 0:
            msg_timer = 0
        elif near_hs >= 0:
            if current_room == ROOM_ENTRANCE:
                interact_entrance(near_hs)

# ─── Hotspot detection (unrolled — codegen TODO: for-in-function) ──────────────
def check_entrance_hotspots():
    # Hotspot 0: painting/canvas
    dx = player_x - ENT_HS_X[0]
    dy = player_y - ENT_HS_Y[0]
    debug_print(dx)
    debug_print(dy)
    if abs(dx) <= ENT_HS_W[0] and abs(dy) <= ENT_HS_H[0]:
        near_hs = 0
    # Hotspot 1: locked door
    dx = player_x - ENT_HS_X[1]
    dy = player_y - ENT_HS_Y[1]
    if abs(dx) <= ENT_HS_W[1] and abs(dy) <= ENT_HS_H[1]:
        near_hs = 1

# ─── Interactions ──────────────────────────────────────────────────────────────
def interact_entrance(hs):
    if hs == ENT_HS_PAINTING:
        if current_verb == VERB_EXAMINE:
            flag_date_known = 1
            msg_id    = 1
            msg_timer = 160
        elif current_verb == VERB_TAKE:
            msg_id    = 5
            msg_timer = 100
        elif current_verb == VERB_USE:
            msg_id    = 5
            msg_timer = 100

    elif hs == ENT_HS_DOOR:
        if current_verb == VERB_EXAMINE:
            msg_id    = 2
            msg_timer = 120
        elif current_verb == VERB_USE:
            if flag_taller_open == 1:
                room_exit = 1
                msg_timer = 60
            elif flag_date_known == 1:
                flag_taller_open = 1
                msg_id    = 4
                msg_timer = 200
                room_exit = 1
                PLAY_SFX("door_unlock")
            else:
                msg_id    = 3
                msg_timer = 120
                PLAY_SFX("puzzle_fail")
        elif current_verb == VERB_TAKE:
            msg_id    = 5
            msg_timer = 100

# ═══════════════════════════════════════════════════════════════════════════════
# ROOM — Draw
# ═══════════════════════════════════════════════════════════════════════════════
def draw_room():
    # Level background + objects
    SET_INTENSITY(100)
    UPDATE_LEVEL()
    SHOW_LEVEL()

    # Player character (draw at screen position = world_x - camera)
    screen_x = player_x - scroll_x
    SET_INTENSITY(110)
    DRAW_VECTOR("player", screen_x, player_y)

    # Bottom HUD: verb + hotspot name + interaction text
    draw_bottom_hud()

# ─── Bottom HUD ────────────────────────────────────────────────────────────────
def draw_bottom_hud():
    # Show verb + hotspot name fused in one line
    if near_hs >= 0:
        SET_INTENSITY(100)
        if current_room == ROOM_ENTRANCE:
            draw_entrance_action_line()
    else:
        # No hotspot nearby — just show the verb alone
        SET_INTENSITY(70)
        draw_verb_indicator()

    # Show interaction message below the action line
    if msg_timer > 0:
        draw_message()

# ─── Verb + hotspot fused lines (one line each combo) ─────────────────────────
def draw_entrance_action_line():
    if near_hs == ENT_HS_PAINTING:
        if current_verb == VERB_EXAMINE:
            PRINT_TEXT(-70, 127, "EXAMINE PAINTING")
        elif current_verb == VERB_TAKE:
            PRINT_TEXT(-56, 127, "TAKE PAINTING")
        elif current_verb == VERB_USE:
            PRINT_TEXT(-49, 127, "USE PAINTING")
    elif near_hs == ENT_HS_DOOR:
        if current_verb == VERB_EXAMINE:
            PRINT_TEXT(-91, 127, "EXAMINE WORKSHOP DOOR")
        elif current_verb == VERB_TAKE:
            PRINT_TEXT(-77, 127, "TAKE WORKSHOP DOOR")
        elif current_verb == VERB_USE:
            PRINT_TEXT(-70, 127, "USE WORKSHOP DOOR")

# ─── Verb indicator (no hotspot nearby) ────────────────────────────────────────
def draw_verb_indicator():
    if current_verb == VERB_EXAMINE:
        PRINT_TEXT(-42, 127, "EXAMINE")
    elif current_verb == VERB_TAKE:
        PRINT_TEXT(-28, 127, "TAKE")
    elif current_verb == VERB_USE:
        PRINT_TEXT(-21, 127, "USE")

# ─── Message display ───────────────────────────────────────────────────────────
# msg_id 1 : examined portrait
# msg_id 2 : examined workshop door
# msg_id 3 : tried door without clue
# msg_id 4 : door opens (1-8-8-7)
# msg_id 5 : cannot do that
def draw_message():
    SET_INTENSITY(100)
    if msg_id == 1:
        PRINT_TEXT(-70, 114,  "THE PORTRAIT SHOWS")
        PRINT_TEXT(-70, 101, "VOSS IN 1887.")
        SET_INTENSITY(80)
        PRINT_TEXT(-70, 88, "A DATE... A CODE?")
    elif msg_id == 2:
        PRINT_TEXT(-70, 114, "A COMBINATION LOCK.")
        PRINT_TEXT(-70, 101, "4 DIGIT WHEELS.")
    elif msg_id == 3:
        PRINT_TEXT(-70, 114, "YOU NEED TO FIND")
        PRINT_TEXT(-70, 101, "THE COMBINATION.")
    elif msg_id == 4:
        PRINT_TEXT(-70, 114, "YOU TRY:  1 - 8 - 8 - 7")
        PRINT_TEXT(-70, 101, "THE DOOR CLICKS OPEN.")
    elif msg_id == 5:
        PRINT_TEXT(-70, 114, "YOU CANNOT DO THAT.")

# ─── Clock room stub ───────────────────────────────────────────────────────────
# (placeholder until assets are ready)

# ═══════════════════════════════════════════════════════════════════════════════
# ENDING
# ═══════════════════════════════════════════════════════════════════════════════
def draw_ending():
    SET_INTENSITY(100)
    PRINT_TEXT(-42, 10, "TO BE CONTINUED...")
