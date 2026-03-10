# THE CLOCKMAKER'S CRYPT
# Switzerland, 1887. Konrad Voss is dead. You are the assessor.

META TITLE = "CLOCKMAKER'S CRYPT"
META ROM_TOTAL_SIZE = 65536
META ROM_BANK_SIZE = 16384

# ─── Game states ───────────────────────────────────────────────────────────────
const STATE_TITLE     = 0
const STATE_INTRO     = 1
const STATE_ROOM      = 2
const STATE_ENDING    = 3
const STATE_TESTAMENT = 4

# ─── Rooms ─────────────────────────────────────────────────────────────────────
const ROOM_ENTRANCE       = 0
const ROOM_WORKSHOP       = 1
const ROOM_ANTEROOM       = 2
const ROOM_WEIGHTS        = 3
const ROOM_OPTICS         = 4
const ROOM_CONSERVATORY   = 5
const ROOM_VAULT_CORRIDOR = 6

# ─── Verbs ─────────────────────────────────────────────────────────────────────
const VERB_EXAMINE = 0
const VERB_TAKE    = 1
const VERB_USE     = 2
const VERB_GIVE    = 3

# ─── NPCs ──────────────────────────────────────────────────────────────────────
const NPC_CARETAKER  = 0
const NPC_HANS       = 1
const NPC_ELISA      = 2
const NPC_APPRENTICE = 3

# ─── Items ─────────────────────────────────────────────────────────────────────
const ITEM_LENS    = 0
const ITEM_GEAR    = 1
const ITEM_PRISM   = 2
const ITEM_BLANKET = 3
const ITEM_EYE     = 4
const ITEM_OIL     = 5
const ITEM_SHEET   = 6
const ITEM_KEY     = 7
const ITEM_COUNT   = 8

# Weight per item: LENS=1, GEAR=2, PRISM=1, BLANKET=0, EYE=1, OIL=1, SHEET=0, KEY=1
const ITEM_WEIGHT = [1, 2, 1, 0, 1, 1, 0, 1]

# ─── Music IDs ─────────────────────────────────────────────────────────────────
const MUSIC_NONE        = 0
const MUSIC_TITLE       = 1
const MUSIC_EXPLORATION = 2

# ─── Flag bit constants (flags_a / flags_b) ────────────────────────────────────
const FL_DATE_KNOWN      = 1    # flags_a bit 0
const FL_TALLER_OPEN     = 2    # flags_a bit 1
const FL_SARC_OPEN       = 4    # flags_a bit 2
const FL_CLOCK_READ      = 8    # flags_a bit 3
const FL_PANEL_ACTIVE    = 16   # flags_a bit 4
const FL_ITEMS_DEPOSITED = 32   # flags_a bit 5
const FL_OPTICS_SOLVED   = 64   # flags_a bit 6
const FL_OPTICS_OPEN     = 128  # flags_a bit 7

const FL_PLAT_DOWN       = 1    # flags_b bit 0
const FL_ELISA_HELPED    = 2    # flags_b bit 1
const FL_HANS_HELPED     = 4    # flags_b bit 2
const FL_CARETAKER_DONE  = 8    # flags_b bit 3
const FL_EXIT_TESTAMENT  = 16   # flags_b bit 4
const FL_EXIT_ENDING     = 32   # flags_b bit 5

# ─── Entrance hotspots (4): painting, workshop door, caretaker, conservatory door
const ENT_HS_PAINTING  = 0
const ENT_HS_DOOR      = 1
const ENT_HS_CARETAKER = 2
const ENT_HS_CONS_DOOR = 3

const ENT_HS_X = [260, 738, 100, 40]
const ENT_HS_Y = [-98, -88, -110, -95]
const ENT_HS_W = [25, 40, 22, 18]
const ENT_HS_H = [35, 45, 30, 28]

# ─── Workshop hotspots (6): sarc, clock, gear/panel, hans, oil, optics door
const CLOCK_HS_SARC   = 0
const CLOCK_HS_CLOCK  = 1
const CLOCK_HS_GEAR   = 2
const CLOCK_HS_HANS   = 3
const CLOCK_HS_OIL    = 4
const CLOCK_HS_OPTICS = 5

const CLOCK_HS_X = [190, 400, 520, 280, 460, 700]
const CLOCK_HS_Y = [-80, -70, -80, -110, -80, -90]
const CLOCK_HS_W = [40, 35, 35, 22, 20, 22]
const CLOCK_HS_H = [40, 40, 35, 30, 25, 32]

# ─── Anteroom hotspots (4): diary, exit, music shelf, cabinet
const ANT_HS_DIARY   = 0
const ANT_HS_EXIT    = 1
const ANT_HS_SHELF   = 2
const ANT_HS_CABINET = 3

const ANT_HS_X = [300, 735, 150, 550]
const ANT_HS_Y = [-95, -95, -95, -95]
const ANT_HS_W = [40, 30, 35, 35]
const ANT_HS_H = [35, 30, 35, 35]

# ─── Weights room hotspot indices ──────────────────────────────────────────────
const WGT_HS_PEDESTAL = 0
const WGT_HS_EXIT     = 1
const WGT_HS_X = [280, 570]
const WGT_HS_Y = [-95, -95]
const WGT_HS_W = [40, 30]
const WGT_HS_H = [35, 30]

# ─── Optics room hotspot indices ───────────────────────────────────────────────
const OPT_HS_PEDESTAL    = 0
const OPT_HS_COMPARTMENT = 1
const OPT_HS_X = [250, 420]
const OPT_HS_Y = [-95, -95]
const OPT_HS_W = [40, 30]
const OPT_HS_H = [35, 30]

# ─── Conservatory hotspot (1): Elisa the ghost
const CONS_HS_ELISA = 0
const CONS_HS_X = [0]
const CONS_HS_Y = [-100]
const CONS_HS_W = [40]
const CONS_HS_H = [40]

# ─── Vault corridor hotspots (2): crystal apprentice, final door
const VAULT_HS_APPR = 0
const VAULT_HS_DOOR = 1
const VAULT_HS_X = [-30, 70]
const VAULT_HS_Y = [-100, -90]
const VAULT_HS_W = [35, 22]
const VAULT_HS_H = [40, 32]

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

# Puzzle flags packed into 2 bytes (bit fields)
flags_a = 0    # FL_DATE_KNOWN | FL_TALLER_OPEN | FL_SARC_OPEN | FL_CLOCK_READ
               # FL_PANEL_ACTIVE | FL_ITEMS_DEPOSITED | FL_OPTICS_SOLVED | FL_OPTICS_OPEN
flags_b = 0    # FL_PLAT_DOWN | FL_ELISA_HELPED | FL_HANS_HELPED | FL_CARETAKER_DONE
               # FL_EXIT_TESTAMENT | FL_EXIT_ENDING

# NPC states (0=not met, 1=met, 2=helped)
npc_state = [0, 0, 0, 0]

# Room transition target
exit_room_target = 1

# Music state
current_music = MUSIC_TITLE

# Button state (fired = 1 only on rising edge, 0 otherwise)
btn1_fired = 0
btn2_fired = 0
btn3_fired = 0

# Previous raw button state for VPy-level edge detection
prev_btn1 = 0
prev_btn2 = 0
prev_btn3 = 0

# ─── Inventory ──────────────────────────────────────────────────────────────────
inv_items  = [0, 0, 0, 0, 0, 0, 0, 0]
inv_count  = 0
inv_weight = 0
show_inventory = 0
active_item    = -1
inv_cursor     = 0

# ─── Heartbeat ─────────────────────────────────────────────────────────────────
heartbeat_tempo = 60
heartbeat_timer = 0

# ─── Testament scroll ──────────────────────────────────────────────────────────
testament_y    = -110
testament_page = 0

# ─── Ending scroll ─────────────────────────────────────────────────────────────
ending_y = -110

# ─── Test variables ────────────────────────────────────────────────────────────

skippedframes = 0

# hit1 : i16= 0
# hit2 : i16 = 0
# hit3 : i16 = 0


# ─── Entry point ───────────────────────────────────────────────────────────────
def main():
    # LOAD_LEVEL("entrance")
    PLAY_MUSIC("intro")
    pass

# ─── Main loop ─────────────────────────────────────────────────────────────────
def loop():
    # Skip first 10 frames to let hardware settle; prime prev_btn during skip
    if skippedframes < 10:
        skippedframes += 1
        prev_btn1 = J1_BUTTON_1()
        prev_btn2 = J1_BUTTON_2()
        prev_btn3 = J1_BUTTON_3()
        return

    # Edge detection: fire only on rising edge (0->1 transition)
    raw1 = J1_BUTTON_1()
    raw2 = J1_BUTTON_2()
    raw3 = J1_BUTTON_3()
    btn1_fired = 0
    btn2_fired = 0
    btn3_fired = 0
    if raw1 == 1 and prev_btn1 == 0:
        btn1_fired = 1
    if raw2 == 1 and prev_btn2 == 0:
        btn2_fired = 1
    if raw3 == 1 and prev_btn3 == 0:
        btn3_fired = 1
    prev_btn1 = raw1
    prev_btn2 = raw2
    prev_btn3 = raw3

    # hit1 += btn1_fired
    # hit2 += btn2_fired
    # hit3 += btn3_fired

    # Heartbeat tick
    if screen == STATE_ROOM:
        heartbeat_timer = heartbeat_timer + 1
        if heartbeat_timer >= heartbeat_tempo:
            heartbeat_timer = 0
            PLAY_SFX("heartbeat")

    # Toggle inventory overlay (only in STATE_ROOM)
    if btn2_fired == 1:
        if screen == STATE_ROOM:
            if show_inventory == 0:
                show_inventory = 1
            else:
                show_inventory = 0

    if screen == STATE_TITLE:
        draw_title()
    elif screen == STATE_INTRO:
        draw_intro()
    elif screen == STATE_ROOM:
        update_room()
        if show_inventory == 1:
            draw_inventory()
        else:
            draw_room()
    elif screen == STATE_TESTAMENT:
        draw_testament()
    elif screen == STATE_ENDING:
        draw_ending()

    # DEBUG: show button states on all screens
    # PRINT_TEXT(-120, 20, "BOTON")
    # PRINT_TEXT(-50, 20, "FIRED")
    # PRINT_TEXT(10, 20, "PREV")
    # PRINT_TEXT(60, 20, "SUM")

    # PRINT_TEXT(-100, 0, "B1")
    # PRINT_NUMBER(-50, 0, btn1_fired)
    # PRINT_NUMBER(10, 0, btn1_fired)
    # PRINT_NUMBER(60, 0, hit1)
    # PRINT_TEXT(-100, -20, "B2")
    # PRINT_NUMBER(-50, -20, btn2_fired)
    # PRINT_NUMBER(10, -20, btn1_fired)
    # PRINT_NUMBER(60, -20, hit2)
    # PRINT_TEXT(-100, -40, "B3")
    # PRINT_NUMBER(-50, -40, btn3_fired)
    # PRINT_NUMBER(10, -40, btn1_fired)
    # PRINT_NUMBER(60, -40, hit3)

# ═══════════════════════════════════════════════════════════════════════════════
# TITLE SCREEN
# ═══════════════════════════════════════════════════════════════════════════════
def draw_title():
    SET_INTENSITY(127)
    DRAW_VECTOR("crypt_logo", 0, 10)

    blink_timer = blink_timer + 1
    if blink_timer >= 40:
        blink_timer = 0
        if blink_on == 0:
            blink_on = 1
        else:
            blink_on = 0

    if blink_on == 1:
        SET_TEXT_SIZE(7)
        PRINT_TEXT(-77, -100, "PRESS B1 TO START")

    if btn1_fired == 1:
        intro_page = 0
        screen = STATE_INTRO

# ═══════════════════════════════════════════════════════════════════════════════
# INTRO — 3 story pages
# ═══════════════════════════════════════════════════════════════════════════════
def draw_intro():
    SET_TEXT_SIZE(7)
    if intro_page == 0:
        SET_INTENSITY(100)
        PRINT_TEXT(-91, 40, "SWITZERLAND, 1887.")
        SET_INTENSITY(80)
        PRINT_TEXT(-91, 20, "KONRAD VOSS IS DEAD.")
        PRINT_TEXT(-91, 0,  "YOU ARE THE ASSESSOR.")
        PRINT_TEXT(-91, -20, "THE CRYPT SEALED.")
        SET_INTENSITY(60)
        PRINT_TEXT(-70, -80, "PRESS BUTTON 1")
    elif intro_page == 1:
        SET_INTENSITY(100)
        PRINT_TEXT(-91, 40, "FIND CLUES. SOLVE")
        PRINT_TEXT(-91, 25, "PUZZLES. ESCAPE.")
        SET_INTENSITY(70)
        PRINT_TEXT(-91, -5,  "JOY:MOVE  B1:ACT")
        PRINT_TEXT(-91, -20, "B2:INV    B3:VERB")
        SET_INTENSITY(60)
        PRINT_TEXT(-70, -80, "PRESS BUTTON 1")

    if btn1_fired == 1:
        if intro_page < 1:
            intro_page = intro_page + 1
        else:
            enter_room(ROOM_ENTRANCE)
            screen = STATE_ROOM

# ═══════════════════════════════════════════════════════════════════════════════
# ROOM — Load & transition
# ═══════════════════════════════════════════════════════════════════════════════
def enter_room(room_id):
    current_room   = room_id
    near_hs        = -1
    msg_id         = 0
    msg_timer      = 0
    room_exit      = 0
    show_inventory = 0
    if room_id == ROOM_ENTRANCE:
        LOAD_LEVEL("entrance")
        player_x = 0
        player_y = -115
        scroll_x = 0
        SET_CAMERA_X(0)
        if current_music != MUSIC_EXPLORATION:
            PLAY_MUSIC("exploration")
            current_music = MUSIC_EXPLORATION
    elif room_id == ROOM_WORKSHOP:
        LOAD_LEVEL("clockroom")
        player_x = 70
        player_y = -75
        scroll_x = 0
        SET_CAMERA_X(0)
        if current_music != MUSIC_EXPLORATION:
            PLAY_MUSIC("exploration")
            current_music = MUSIC_EXPLORATION
    elif room_id == ROOM_ANTEROOM:
        LOAD_LEVEL("anteroom")
        player_x = 50
        player_y = -115
        scroll_x = 0
        SET_CAMERA_X(0)
        if current_music != MUSIC_EXPLORATION:
            PLAY_MUSIC("exploration")
            current_music = MUSIC_EXPLORATION
    elif room_id == ROOM_WEIGHTS:
        LOAD_LEVEL("weights_room")
        player_x = 50
        player_y = -115
        scroll_x = 0
        SET_CAMERA_X(0)
        if current_music != MUSIC_EXPLORATION:
            PLAY_MUSIC("exploration")
            current_music = MUSIC_EXPLORATION
    elif room_id == ROOM_OPTICS:
        LOAD_LEVEL("optics_lab")
        player_x = 50
        player_y = -115
        scroll_x = 0
        SET_CAMERA_X(0)
        if current_music != MUSIC_EXPLORATION:
            PLAY_MUSIC("exploration")
            current_music = MUSIC_EXPLORATION
    elif room_id == ROOM_CONSERVATORY:
        LOAD_LEVEL("conservatory")
        player_x = -60
        player_y = -115
        scroll_x = 0
        SET_CAMERA_X(0)
        if current_music != MUSIC_EXPLORATION:
            PLAY_MUSIC("exploration")
            current_music = MUSIC_EXPLORATION
    elif room_id == ROOM_VAULT_CORRIDOR:
        LOAD_LEVEL("vault_corridor")
        player_x = -60
        player_y = -115
        scroll_x = 0
        SET_CAMERA_X(0)
        if current_music != MUSIC_EXPLORATION:
            PLAY_MUSIC("exploration")
            current_music = MUSIC_EXPLORATION

# ═══════════════════════════════════════════════════════════════════════════════
# ROOM — Update (input + logic)
# ═══════════════════════════════════════════════════════════════════════════════
def update_room():
    joy_x = J1_X()
    if joy_x > 30:
        player_x = player_x + player_speed
    elif joy_x < -30:
        player_x = player_x - player_speed

    player_x = clamp(player_x, -90, 780)

    scroll_x = clamp(player_x, 0, 670)
    SET_CAMERA_X(scroll_x)

    near_hs = -1
    if current_room == ROOM_ENTRANCE:
        check_entrance_hotspots()
        if player_x <= -85 and (flags_a & FL_TALLER_OPEN) != 0 and msg_timer == 0:
            enter_room(ROOM_CONSERVATORY)
    elif current_room == ROOM_WORKSHOP:
        check_workshop_hotspots()
        if player_x >= 770 and (flags_a & FL_PANEL_ACTIVE) != 0 and msg_timer == 0:
            enter_room(ROOM_VAULT_CORRIDOR)
        if player_x >= 690 and (flags_a & FL_OPTICS_OPEN) != 0 and player_x < 770 and msg_timer == 0:
            enter_room(ROOM_OPTICS)
    elif current_room == ROOM_ANTEROOM:
        check_anteroom_hotspots()
        if player_x <= -85 and msg_timer == 0:
            enter_room(ROOM_ENTRANCE)
    elif current_room == ROOM_WEIGHTS:
        check_weights_hotspots()
        if player_x <= -85 and msg_timer == 0:
            enter_room(ROOM_ANTEROOM)
    elif current_room == ROOM_OPTICS:
        check_optics_hotspots()
        if player_x <= -85 and msg_timer == 0:
            enter_room(ROOM_WORKSHOP)
    elif current_room == ROOM_CONSERVATORY:
        check_conservatory_hotspots()
        if player_x >= 60 and msg_timer == 0:
            enter_room(ROOM_ENTRANCE)
    elif current_room == ROOM_VAULT_CORRIDOR:
        check_vault_hotspots()
        if player_x <= -85 and msg_timer == 0:
            enter_room(ROOM_WORKSHOP)

    # Message timer
    if msg_timer > 0:
        msg_timer = msg_timer - 1
        if msg_timer == 0 and room_exit == 1:
            room_exit = 0
            if (flags_b & FL_EXIT_TESTAMENT) != 0:
                flags_b = flags_b & 239
                testament_y     = -110
                testament_page  = 0
                screen = STATE_TESTAMENT
            elif (flags_b & FL_EXIT_ENDING) != 0:
                flags_b  = flags_b & 223
                ending_y = -110
                screen   = STATE_ENDING
            else:
                enter_room(exit_room_target)

    # Button 3 — cycle verb (when not in inventory) or cycle inv_cursor (when in inventory)
    if btn3_fired == 1:
        if show_inventory == 1:
            inv_cursor = inv_cursor + 1
            if inv_cursor >= ITEM_COUNT:
                inv_cursor = 0
        elif msg_timer == 0:
            if current_verb == VERB_GIVE:
                current_verb = VERB_EXAMINE
            else:
                current_verb = current_verb + 1

    # Button 1 — interact, dismiss message, or select item in inventory
    if btn1_fired == 1:
        if show_inventory == 1:
            # Select active item from inventory
            if inv_items[inv_cursor] == 1:
                active_item = inv_cursor
            show_inventory = 0
        elif msg_timer > 0:
            msg_timer = 0
            if room_exit == 1:
                room_exit = 0
                if (flags_b & FL_EXIT_TESTAMENT) != 0:
                    flags_b = flags_b & 239
                    testament_y    = -110
                    testament_page = 0
                    screen = STATE_TESTAMENT
                elif (flags_b & FL_EXIT_ENDING) != 0:
                    flags_b = flags_b & 223
                    screen = STATE_ENDING
                else:
                    enter_room(exit_room_target)
        elif near_hs >= 0:
            if current_room == ROOM_ENTRANCE:
                interact_entrance(near_hs)
            elif current_room == ROOM_WORKSHOP:
                interact_workshop(near_hs)
            elif current_room == ROOM_ANTEROOM:
                interact_anteroom(near_hs)
            elif current_room == ROOM_WEIGHTS:
                interact_weights(near_hs)
            elif current_room == ROOM_OPTICS:
                interact_optics(near_hs)
            elif current_room == ROOM_CONSERVATORY:
                interact_conservatory(near_hs)
            elif current_room == ROOM_VAULT_CORRIDOR:
                interact_vault(near_hs)

# ─── Hotspot detection ────────────────────────────────────────────────────────
def check_entrance_hotspots():
    dx = player_x - ENT_HS_X[0]
    dy = player_y - ENT_HS_Y[0]
    if abs(dx) <= ENT_HS_W[0] and abs(dy) <= ENT_HS_H[0]:
        near_hs = 0
    dx = player_x - ENT_HS_X[1]
    dy = player_y - ENT_HS_Y[1]
    if abs(dx) <= ENT_HS_W[1] and abs(dy) <= ENT_HS_H[1]:
        near_hs = 1
    dx = player_x - ENT_HS_X[2]
    dy = player_y - ENT_HS_Y[2]
    if abs(dx) <= ENT_HS_W[2] and abs(dy) <= ENT_HS_H[2]:
        near_hs = 2
    if (flags_a & FL_TALLER_OPEN) != 0:
        dx = player_x - ENT_HS_X[3]
        dy = player_y - ENT_HS_Y[3]
        if abs(dx) <= ENT_HS_W[3] and abs(dy) <= ENT_HS_H[3]:
            near_hs = 3

def check_workshop_hotspots():
    dx = player_x - CLOCK_HS_X[0]
    dy = player_y - CLOCK_HS_Y[0]
    if abs(dx) <= CLOCK_HS_W[0] and abs(dy) <= CLOCK_HS_H[0]:
        near_hs = 0
    dx = player_x - CLOCK_HS_X[1]
    dy = player_y - CLOCK_HS_Y[1]
    if abs(dx) <= CLOCK_HS_W[1] and abs(dy) <= CLOCK_HS_H[1]:
        near_hs = 1
    if inv_items[ITEM_GEAR] == 0:
        dx = player_x - CLOCK_HS_X[2]
        dy = player_y - CLOCK_HS_Y[2]
        if abs(dx) <= CLOCK_HS_W[2] and abs(dy) <= CLOCK_HS_H[2]:
            near_hs = 2
    elif (flags_a & FL_PANEL_ACTIVE) == 0 and inv_items[ITEM_GEAR] == 1:
        dx = player_x - CLOCK_HS_X[2]
        dy = player_y - CLOCK_HS_Y[2]
        if abs(dx) <= CLOCK_HS_W[2] and abs(dy) <= CLOCK_HS_H[2]:
            near_hs = 2
    dx = player_x - CLOCK_HS_X[3]
    dy = player_y - CLOCK_HS_Y[3]
    if abs(dx) <= CLOCK_HS_W[3] and abs(dy) <= CLOCK_HS_H[3]:
        near_hs = 3
    if inv_items[ITEM_OIL] == 0:
        dx = player_x - CLOCK_HS_X[4]
        dy = player_y - CLOCK_HS_Y[4]
        if abs(dx) <= CLOCK_HS_W[4] and abs(dy) <= CLOCK_HS_H[4]:
            near_hs = 4
    dx = player_x - CLOCK_HS_X[5]
    dy = player_y - CLOCK_HS_Y[5]
    if abs(dx) <= CLOCK_HS_W[5] and abs(dy) <= CLOCK_HS_H[5]:
        near_hs = 5

def check_anteroom_hotspots():
    dx = player_x - ANT_HS_X[0]
    dy = player_y - ANT_HS_Y[0]
    if abs(dx) <= ANT_HS_W[0] and abs(dy) <= ANT_HS_H[0]:
        near_hs = 0
    dx = player_x - ANT_HS_X[1]
    dy = player_y - ANT_HS_Y[1]
    if abs(dx) <= ANT_HS_W[1] and abs(dy) <= ANT_HS_H[1]:
        near_hs = 1
    dx = player_x - ANT_HS_X[2]
    dy = player_y - ANT_HS_Y[2]
    if abs(dx) <= ANT_HS_W[2] and abs(dy) <= ANT_HS_H[2]:
        near_hs = 2
    dx = player_x - ANT_HS_X[3]
    dy = player_y - ANT_HS_Y[3]
    if abs(dx) <= ANT_HS_W[3] and abs(dy) <= ANT_HS_H[3]:
        near_hs = 3

def check_weights_hotspots():
    dx = player_x - WGT_HS_X[0]
    dy = player_y - WGT_HS_Y[0]
    if abs(dx) <= WGT_HS_W[0] and abs(dy) <= WGT_HS_H[0]:
        near_hs = 0
    dx = player_x - WGT_HS_X[1]
    dy = player_y - WGT_HS_Y[1]
    if abs(dx) <= WGT_HS_W[1] and abs(dy) <= WGT_HS_H[1]:
        near_hs = 1

def check_optics_hotspots():
    dx = player_x - OPT_HS_X[0]
    dy = player_y - OPT_HS_Y[0]
    if abs(dx) <= OPT_HS_W[0] and abs(dy) <= OPT_HS_H[0]:
        near_hs = 0
    if (flags_a & FL_OPTICS_SOLVED) != 0:
        dx = player_x - OPT_HS_X[1]
        dy = player_y - OPT_HS_Y[1]
        if abs(dx) <= OPT_HS_W[1] and abs(dy) <= OPT_HS_H[1]:
            near_hs = 1

def check_conservatory_hotspots():
    dx = player_x - CONS_HS_X[0]
    dy = player_y - CONS_HS_Y[0]
    if abs(dx) <= CONS_HS_W[0] and abs(dy) <= CONS_HS_H[0]:
        near_hs = 0

def check_vault_hotspots():
    dx = player_x - VAULT_HS_X[0]
    dy = player_y - VAULT_HS_Y[0]
    if abs(dx) <= VAULT_HS_W[0] and abs(dy) <= VAULT_HS_H[0]:
        near_hs = 0
    dx = player_x - VAULT_HS_X[1]
    dy = player_y - VAULT_HS_Y[1]
    if abs(dx) <= VAULT_HS_W[1] and abs(dy) <= VAULT_HS_H[1]:
        near_hs = 1

# ─── Interactions ──────────────────────────────────────────────────────────────
def interact_entrance(hs):
    if hs == ENT_HS_PAINTING:
        if current_verb == VERB_EXAMINE:
            flags_a = flags_a | FL_DATE_KNOWN
            msg_id    = 1
            msg_timer = 160
        elif current_verb == VERB_TAKE:
            msg_id    = 5
            msg_timer = 100
        elif current_verb == VERB_USE:
            if inv_items[ITEM_EYE] == 1:
                msg_id    = 43
                msg_timer = 120
            else:
                msg_id    = 5
                msg_timer = 100
        elif current_verb == VERB_GIVE:
            msg_id    = 5
            msg_timer = 100

    elif hs == ENT_HS_DOOR:
        if current_verb == VERB_EXAMINE:
            msg_id    = 2
            msg_timer = 120
        elif current_verb == VERB_USE:
            if (flags_a & FL_TALLER_OPEN) != 0:
                exit_room_target = ROOM_ANTEROOM
                room_exit = 1
                msg_timer = 60
            elif (flags_a & FL_DATE_KNOWN) != 0:
                flags_a = flags_a | FL_TALLER_OPEN
                exit_room_target = ROOM_ANTEROOM
                msg_id    = 4
                msg_timer = 200
                room_exit = 1
                PLAY_SFX("door_unlock")
                accelerate_heartbeat()
            else:
                msg_id    = 3
                msg_timer = 120
                PLAY_SFX("puzzle_fail")
        elif current_verb == VERB_TAKE:
            msg_id    = 5
            msg_timer = 100

    elif hs == ENT_HS_CARETAKER:
        if current_verb == VERB_EXAMINE:
            npc_state[NPC_CARETAKER] = 1
            msg_id    = 24
            msg_timer = 160
        elif current_verb == VERB_USE:
            msg_id    = 36
            msg_timer = 120
        elif current_verb == VERB_GIVE:
            if active_item == ITEM_BLANKET:
                if (flags_b & FL_CARETAKER_DONE) == 0:
                    flags_b = flags_b | FL_CARETAKER_DONE
                    flags_a = flags_a | FL_OPTICS_OPEN
                    drop_item(ITEM_BLANKET)
                    active_item = -1
                    npc_state[NPC_CARETAKER] = 2
                    msg_id    = 26
                    msg_timer = 200
                    accelerate_heartbeat()
                else:
                    msg_id    = 5
                    msg_timer = 100
            else:
                msg_id    = 36
                msg_timer = 120
        elif current_verb == VERB_TAKE:
            msg_id    = 5
            msg_timer = 100

    elif hs == ENT_HS_CONS_DOOR:
        if current_verb == VERB_EXAMINE:
            msg_id    = 43
            msg_timer = 120
        elif current_verb == VERB_USE:
            exit_room_target = ROOM_CONSERVATORY
            room_exit  = 1
            msg_timer  = 60
        elif current_verb == VERB_TAKE:
            msg_id    = 5
            msg_timer = 100

def interact_workshop(hs):
    if hs == CLOCK_HS_SARC:
        if current_verb == VERB_EXAMINE:
            msg_id    = 6
            msg_timer = 120
        elif current_verb == VERB_USE:
            if (flags_a & FL_SARC_OPEN) != 0:
                msg_id    = 5
                msg_timer = 100
            elif (flags_a & FL_CLOCK_READ) != 0:
                flags_a = flags_a | FL_SARC_OPEN
                pickup_item(ITEM_BLANKET)
                pickup_item(ITEM_KEY)
                msg_id    = 7
                msg_timer = 200
                PLAY_SFX("puzzle_success")
                accelerate_heartbeat()
            else:
                msg_id    = 23
                msg_timer = 120
        elif current_verb == VERB_TAKE:
            msg_id    = 5
            msg_timer = 100

    elif hs == CLOCK_HS_CLOCK:
        if current_verb == VERB_EXAMINE:
            msg_id    = 8
            msg_timer = 120
        elif current_verb == VERB_USE:
            if inv_items[ITEM_LENS] == 1:
                flags_a = flags_a | FL_CLOCK_READ
                msg_id    = 8
                msg_timer = 160
            else:
                msg_id    = 22
                msg_timer = 120
        elif current_verb == VERB_TAKE:
            msg_id    = 5
            msg_timer = 100

    elif hs == CLOCK_HS_GEAR:
        if inv_items[ITEM_GEAR] == 0:
            pickup_item(ITEM_GEAR)
            msg_id    = 25
            msg_timer = 140
        elif current_verb == VERB_USE:
            if inv_items[ITEM_GEAR] == 1:
                flags_a = flags_a | FL_PANEL_ACTIVE
                drop_item(ITEM_GEAR)
                msg_id    = 44
                msg_timer = 160
                PLAY_SFX("puzzle_success")
                accelerate_heartbeat()
            else:
                msg_id    = 5
                msg_timer = 100
        else:
            msg_id    = 5
            msg_timer = 100

    elif hs == CLOCK_HS_HANS:
        if current_verb == VERB_EXAMINE:
            npc_state[NPC_HANS] = 1
            msg_id    = 27
            msg_timer = 160
        elif current_verb == VERB_USE:
            msg_id    = 37
            msg_timer = 120
        elif current_verb == VERB_GIVE:
            if active_item == ITEM_OIL:
                if (flags_b & FL_HANS_HELPED) == 0:
                    flags_b = flags_b | FL_HANS_HELPED
                    drop_item(ITEM_OIL)
                    active_item = -1
                    npc_state[NPC_HANS] = 2
                    msg_id    = 28
                    msg_timer = 200
                    accelerate_heartbeat()
                else:
                    msg_id    = 5
                    msg_timer = 100
            else:
                msg_id    = 37
                msg_timer = 120
        elif current_verb == VERB_TAKE:
            msg_id    = 5
            msg_timer = 100

    elif hs == CLOCK_HS_OIL:
        if inv_items[ITEM_OIL] == 0:
            pickup_item(ITEM_OIL)
            msg_id    = 34
            msg_timer = 140
        else:
            msg_id    = 5
            msg_timer = 100

    elif hs == CLOCK_HS_OPTICS:
        if current_verb == VERB_EXAMINE:
            msg_id    = 40
            msg_timer = 120
        elif current_verb == VERB_USE:
            if (flags_a & FL_OPTICS_OPEN) != 0:
                exit_room_target = ROOM_OPTICS
                room_exit  = 1
                msg_timer  = 60
            else:
                msg_id    = 40
                msg_timer = 120
        elif current_verb == VERB_TAKE:
            msg_id    = 5
            msg_timer = 100

def interact_anteroom(hs):
    if hs == ANT_HS_DIARY:
        if current_verb == VERB_EXAMINE:
            msg_id    = 9
            msg_timer = 140
        elif current_verb == VERB_TAKE:
            msg_id    = 5
            msg_timer = 100
        elif current_verb == VERB_USE:
            if inv_items[ITEM_LENS] == 0:
                pickup_item(ITEM_LENS)
                msg_id    = 10
                msg_timer = 160
            else:
                msg_id    = 11
                msg_timer = 100
    elif hs == ANT_HS_EXIT:
        if current_verb == VERB_EXAMINE:
            msg_id    = 12
            msg_timer = 100
        elif current_verb == VERB_USE:
            exit_room_target = ROOM_WEIGHTS
            room_exit  = 1
            msg_timer  = 60
        elif current_verb == VERB_TAKE:
            msg_id    = 5
            msg_timer = 100
    elif hs == ANT_HS_SHELF:
        if current_verb == VERB_EXAMINE:
            msg_id    = 33
            msg_timer = 120
        elif current_verb == VERB_TAKE:
            if inv_items[ITEM_SHEET] == 0:
                pickup_item(ITEM_SHEET)
                msg_id    = 33
                msg_timer = 140
            else:
                msg_id    = 5
                msg_timer = 100
        elif current_verb == VERB_USE:
            msg_id    = 5
            msg_timer = 100
    elif hs == ANT_HS_CABINET:
        if current_verb == VERB_EXAMINE:
            msg_id    = 35
            msg_timer = 120
        elif current_verb == VERB_USE:
            if inv_items[ITEM_PRISM] == 0 and inv_items[ITEM_LENS] == 1:
                pickup_item(ITEM_PRISM)
                msg_id    = 35
                msg_timer = 160
            elif inv_items[ITEM_PRISM] == 1:
                msg_id    = 5
                msg_timer = 100
            else:
                msg_id    = 22
                msg_timer = 120
        elif current_verb == VERB_TAKE:
            msg_id    = 5
            msg_timer = 100

def interact_weights(hs):
    if hs == WGT_HS_PEDESTAL:
        if current_verb == VERB_EXAMINE:
            msg_id    = 13
            msg_timer = 120
        elif current_verb == VERB_USE:
            if inv_weight > 0:
                flags_a = flags_a | FL_ITEMS_DEPOSITED
                inv_weight = 0
                msg_id    = 14
                msg_timer = 140
            else:
                msg_id    = 5
                msg_timer = 100
        elif current_verb == VERB_TAKE:
            msg_id    = 5
            msg_timer = 100
    elif hs == WGT_HS_EXIT:
        if current_verb == VERB_EXAMINE:
            msg_id    = 15
            msg_timer = 100
        elif current_verb == VERB_USE:
            if inv_weight > 3:
                msg_id    = 16
                msg_timer = 140
                PLAY_SFX("puzzle_fail")
            else:
                exit_room_target = ROOM_WORKSHOP
                room_exit  = 1
                msg_timer  = 60
        elif current_verb == VERB_TAKE:
            msg_id    = 5
            msg_timer = 100

def interact_optics(hs):
    if hs == OPT_HS_PEDESTAL:
        if current_verb == VERB_EXAMINE:
            msg_id    = 17
            msg_timer = 120
        elif current_verb == VERB_USE:
            if (flags_a & FL_OPTICS_SOLVED) != 0:
                msg_id    = 5
                msg_timer = 100
            elif inv_items[ITEM_PRISM] == 1:
                flags_a = flags_a | FL_OPTICS_SOLVED
                drop_item(ITEM_PRISM)
                msg_id    = 19
                msg_timer = 200
                PLAY_SFX("puzzle_success")
                accelerate_heartbeat()
            else:
                msg_id    = 18
                msg_timer = 120
        elif current_verb == VERB_TAKE:
            msg_id    = 5
            msg_timer = 100
    elif hs == OPT_HS_COMPARTMENT:
        if current_verb == VERB_EXAMINE:
            msg_id    = 20
            msg_timer = 120
        elif current_verb == VERB_TAKE:
            if inv_items[ITEM_EYE] == 0:
                pickup_item(ITEM_EYE)
                msg_id    = 21
                msg_timer = 140
            else:
                msg_id    = 5
                msg_timer = 100
        elif current_verb == VERB_USE:
            msg_id    = 5
            msg_timer = 100

def interact_conservatory(hs):
    if hs == CONS_HS_ELISA:
        if current_verb == VERB_EXAMINE:
            npc_state[NPC_ELISA] = 1
            msg_id    = 29
            msg_timer = 160
        elif current_verb == VERB_USE:
            msg_id    = 38
            msg_timer = 120
        elif current_verb == VERB_GIVE:
            if active_item == ITEM_SHEET:
                if (flags_b & FL_ELISA_HELPED) == 0:
                    flags_b = flags_b | FL_ELISA_HELPED
                    drop_item(ITEM_SHEET)
                    active_item = -1
                    npc_state[NPC_ELISA] = 2
                    msg_id    = 30
                    msg_timer = 200
                    PLAY_SFX("puzzle_success")
                    accelerate_heartbeat()
                else:
                    msg_id    = 5
                    msg_timer = 100
            else:
                msg_id    = 38
                msg_timer = 120
        elif current_verb == VERB_TAKE:
            msg_id    = 5
            msg_timer = 100

def interact_vault(hs):
    if hs == VAULT_HS_APPR:
        if current_verb == VERB_EXAMINE:
            npc_state[NPC_APPRENTICE] = 1
            msg_id    = 31
            msg_timer = 200
        elif current_verb == VERB_USE:
            msg_id    = 39
            msg_timer = 120
        elif current_verb == VERB_GIVE:
            if active_item == ITEM_GEAR:
                npc_state[NPC_APPRENTICE] = 2
                active_item = -1
                msg_id    = 32
                msg_timer = 200
            else:
                msg_id    = 39
                msg_timer = 120
        elif current_verb == VERB_TAKE:
            msg_id    = 5
            msg_timer = 100
    elif hs == VAULT_HS_DOOR:
        if current_verb == VERB_EXAMINE:
            msg_id    = 42
            msg_timer = 120
        elif current_verb == VERB_USE:
            if inv_items[ITEM_KEY] == 1:
                drop_item(ITEM_KEY)
                active_item = -1
                room_exit = 1
                flags_b = flags_b | FL_EXIT_TESTAMENT
                msg_timer = 80
            else:
                msg_id    = 42
                msg_timer = 120
        elif current_verb == VERB_TAKE:
            msg_id    = 5
            msg_timer = 100

# ═══════════════════════════════════════════════════════════════════════════════
def draw_room():
    SET_INTENSITY(100)
    UPDATE_LEVEL()
    SHOW_LEVEL()

    # Draw NPCs in rooms
    if current_room == ROOM_ENTRANCE:
        caretaker_sx = ENT_HS_X[ENT_HS_CARETAKER] - scroll_x
        if caretaker_sx > -120 and caretaker_sx < 120:
            if npc_state[NPC_CARETAKER] < 2:
                SET_INTENSITY(90)
            else:
                SET_INTENSITY(50)
            DRAW_VECTOR("caretaker", caretaker_sx, -118)

    if current_room == ROOM_WORKSHOP:
        hans_sx = CLOCK_HS_X[CLOCK_HS_HANS] - scroll_x
        if hans_sx > -120 and hans_sx < 120:
            if npc_state[NPC_HANS] < 2:
                SET_INTENSITY(90)
            else:
                SET_INTENSITY(50)
            DRAW_VECTOR("hans_automata", hans_sx, -118)

    # Dynamic objects
    if current_room == ROOM_WEIGHTS:
        if inv_weight > 3:
            flags_b = flags_b | FL_PLAT_DOWN
        else:
            flags_b = flags_b & 254
        plat_sx = 280 - scroll_x
        if plat_sx > -120 and plat_sx < 120:
            SET_INTENSITY(100)
            if (flags_b & FL_PLAT_DOWN) == 0:
                DRAW_VECTOR("platform_up", plat_sx, -85)
            else:
                DRAW_VECTOR("platform_down", plat_sx, -85)

    if current_room == ROOM_OPTICS:
        if (flags_a & FL_OPTICS_SOLVED) != 0:
            comp_sx = 420 - scroll_x
            if comp_sx > -120 and comp_sx < 120:
                SET_INTENSITY(110)
                DRAW_VECTOR("wall_compartment", comp_sx, -88)

    if current_room == ROOM_CONSERVATORY:
        if npc_state[NPC_ELISA] < 2:
            SET_INTENSITY(80)
        else:
            SET_INTENSITY(30)
        DRAW_VECTOR("elisa_ghost", 0, -104)

    if current_room == ROOM_VAULT_CORRIDOR:
        SET_INTENSITY(85)
        DRAW_VECTOR("crystal_apprentice", -30, -104)

    # Player
    screen_x = player_x - scroll_x
    SET_INTENSITY(110)
    DRAW_VECTOR("player", screen_x, player_y)

    draw_bottom_hud()

# ─── Bottom HUD ────────────────────────────────────────────────────────────────
def draw_bottom_hud():
    SET_TEXT_SIZE(7)
    SET_INTENSITY(70)
    draw_verb_indicator()
    if msg_timer > 0:
        draw_message()

def draw_verb_indicator():
    if current_verb == VERB_EXAMINE:
        PRINT_TEXT(-42, 127, "EXAMINE")
    elif current_verb == VERB_TAKE:
        PRINT_TEXT(-28, 127, "TAKE")
    elif current_verb == VERB_USE:
        PRINT_TEXT(-21, 127, "USE")
    elif current_verb == VERB_GIVE:
        if active_item == -1:
            PRINT_TEXT(-28, 127, "GIVE")
        elif active_item == ITEM_LENS:
            PRINT_TEXT(-49, 127, "GIVE:LENS")
        elif active_item == ITEM_GEAR:
            PRINT_TEXT(-49, 127, "GIVE:GEAR")
        elif active_item == ITEM_PRISM:
            PRINT_TEXT(-56, 127, "GIVE:PRISM")
        elif active_item == ITEM_BLANKET:
            PRINT_TEXT(-63, 127, "GIVE:BLNKT")
        elif active_item == ITEM_EYE:
            PRINT_TEXT(-42, 127, "GIVE:EYE")
        elif active_item == ITEM_OIL:
            PRINT_TEXT(-42, 127, "GIVE:OIL")
        elif active_item == ITEM_SHEET:
            PRINT_TEXT(-56, 127, "GIVE:SHEET")
        elif active_item == ITEM_KEY:
            PRINT_TEXT(-42, 127, "GIVE:KEY")

# ─── Message display ───────────────────────────────────────────────────────────
def draw_message():
    MSG_DEF(1,  -70, 114, "VOSS 1887. NO EYE.")
    MSG_DEF(2,  -63, 114, "4-DIGIT LOCK.")
    MSG_DEF(3,  -63, 114, "NEED A CLUE.")
    MSG_DEF(4,  -70, 114, "1-8-8-7. OPENS!")
    MSG_DEF(5,  -70, 114, "CANNOT DO THAT.")
    MSG_DEF(6,  -63, 114, "SARC. HOUR LOCK.")
    MSG_DEF(7,  -77, 114, "11:07. BLNKT+KEY!")
    MSG_DEF(8,  -70, 114, "CLOCK: 11:07.")
    MSG_DEF(9,  -63, 114, "DIARY: LENS INSIDE.")
    MSG_DEF(10, -63, 114, "LENS TAKEN.")
    MSG_DEF(11, -63, 114, "ALREADY TOOK IT.")
    MSG_DEF(12, -63, 114, "WEIGHTS ROOM.")
    MSG_DEF(13, -70, 114, "DEPOSIT ITEMS.")
    MSG_DEF(14, -63, 114, "BALANCE SHIFTS.")
    MSG_DEF(15, -63, 114, "WORKSHOP BEYOND.")
    MSG_DEF(16, -56, 114, "TOO HEAVY.")
    MSG_DEF(17, -70, 114, "PRISM MOUNT. EMPTY.")
    MSG_DEF(18, -63, 114, "NEED A PRISM.")
    MSG_DEF(19, -63, 114, "PANEL SLIDES OPEN!")
    MSG_DEF(20, -70, 114, "HIDDEN COMPARTMENT.")
    MSG_DEF(21, -63, 114, "THE CRYSTAL EYE!")
    MSG_DEF(22, -63, 114, "NEED LENS FIRST.")
    MSG_DEF(23, -56, 114, "FIND CLUE FIRST.")
    MSG_DEF(24, -70, 114, "BARELY ALIVE.")
    MSG_DEF(25, -63, 114, "GEARS TAKEN.")
    MSG_DEF(26, -63, 114, "WARM. OPTICS OPEN.")
    MSG_DEF(27, -63, 114, "TICK... NEED OIL...")
    MSG_DEF(28, -70, 114, "CLOCK LIES.")
    MSG_DEF(29, -70, 114, "TRIES TO SING.")
    MSG_DEF(30, -63, 114, "SHE SMILES. C-E-G.")
    MSG_DEF(31, -70, 114, "HIS WINDING CLOCK.")
    MSG_DEF(32, -56, 114, "VAULT AWAITS.")
    MSG_DEF(33, -63, 114, "OLD SHEET MUSIC.")
    MSG_DEF(34, -56, 114, "WHALE OIL CAN.")
    MSG_DEF(35, -56, 114, "A GLASS PRISM.")
    MSG_DEF(36, -56, 114, "NEEDS WARMTH.")
    MSG_DEF(37, -56, 114, "HANS NEEDS OIL.")
    MSG_DEF(38, -49, 114, "NEEDS MUSIC.")
    MSG_DEF(39, -70, 114, "WANTS THE GEARS.")
    MSG_DEF(40, -63, 114, "OPTICS LAB LOCKED.")
    MSG_DEF(41, -63, 114, "NO ITEM SELECTED.")
    MSG_DEF(42, -63, 114, "NEEDS VOSS KEY.")
    MSG_DEF(43, -63, 114, "SMALL SIDE DOOR.")
    MSG_DEF(44, -63, 114, "VAULT UNSEALED!")
    SET_TEXT_SIZE(7)
    SET_INTENSITY(100)
    PRINT_MSG(msg_id)

# ═══════════════════════════════════════════════════════════════════════════════
# INVENTORY
# ═══════════════════════════════════════════════════════════════════════════════
def pickup_item(item_id):
    if inv_items[item_id] == 0:
        inv_items[item_id] = 1
        inv_count  = inv_count  + 1
        inv_weight = inv_weight + ITEM_WEIGHT[item_id]
        PLAY_SFX("item_pickup")

def drop_item(item_id):
    if inv_items[item_id] == 1:
        inv_items[item_id] = 0
        inv_count  = inv_count  - 1
        inv_weight = inv_weight - ITEM_WEIGHT[item_id]

# draw_inventory: BTN2 closes, BTN3 cycles cursor, BTN1 selects active_item
def draw_inventory():
    SET_TEXT_SIZE(7)
    SET_INTENSITY(100)
    PRINT_TEXT(-42, 115, "INVENTORY")

    if inv_items[ITEM_LENS] == 1:
        if inv_cursor == ITEM_LENS:
            SET_INTENSITY(127)
        else:
            SET_INTENSITY(100)
    else:
        SET_INTENSITY(35)
    PRINT_TEXT(-105, 90, "LENS     W1")

    if inv_items[ITEM_GEAR] == 1:
        if inv_cursor == ITEM_GEAR:
            SET_INTENSITY(127)
        else:
            SET_INTENSITY(100)
    else:
        SET_INTENSITY(35)
    PRINT_TEXT(-105, 73, "GEAR     W2")

    if inv_items[ITEM_PRISM] == 1:
        if inv_cursor == ITEM_PRISM:
            SET_INTENSITY(127)
        else:
            SET_INTENSITY(100)
    else:
        SET_INTENSITY(35)
    PRINT_TEXT(-105, 56, "PRISM    W1")

    if inv_items[ITEM_BLANKET] == 1:
        if inv_cursor == ITEM_BLANKET:
            SET_INTENSITY(127)
        else:
            SET_INTENSITY(100)
    else:
        SET_INTENSITY(35)
    PRINT_TEXT(-105, 39, "BLANKET  W0")

    if inv_items[ITEM_EYE] == 1:
        if inv_cursor == ITEM_EYE:
            SET_INTENSITY(127)
        else:
            SET_INTENSITY(100)
    else:
        SET_INTENSITY(35)
    PRINT_TEXT(-105, 22, "EYE      W1")

    if inv_items[ITEM_OIL] == 1:
        if inv_cursor == ITEM_OIL:
            SET_INTENSITY(127)
        else:
            SET_INTENSITY(100)
    else:
        SET_INTENSITY(35)
    PRINT_TEXT(-105,  5, "OIL      W1")

    if inv_items[ITEM_SHEET] == 1:
        if inv_cursor == ITEM_SHEET:
            SET_INTENSITY(127)
        else:
            SET_INTENSITY(100)
    else:
        SET_INTENSITY(35)
    PRINT_TEXT(-105, -12, "SHEET    W0")

    if inv_items[ITEM_KEY] == 1:
        if inv_cursor == ITEM_KEY:
            SET_INTENSITY(127)
        else:
            SET_INTENSITY(100)
    else:
        SET_INTENSITY(35)
    PRINT_TEXT(-105, -29, "VOSS KEY W1")

    if inv_weight > 3:
        SET_INTENSITY(100)
        PRINT_TEXT(-105, -60, "* OVERWEIGHT *")
    else:
        SET_INTENSITY(70)
        PRINT_TEXT(-42, -60, "WEIGHT OK")
    SET_INTENSITY(60)
    PRINT_TEXT(-70, -80, "B3:SEL B1:EQUIP")

# ═══════════════════════════════════════════════════════════════════════════════
# TESTAMENT OF VOSS — vertical scroll
# ═══════════════════════════════════════════════════════════════════════════════
def draw_testament():
    SET_TEXT_SIZE(7)
    testament_y = testament_y + 1

    if testament_page == 0:
        SET_INTENSITY(100)
        PRINT_TEXT(-91, testament_y + 15, "TIME IS NOT A RIVER.")
        SET_INTENSITY(80)
        PRINT_TEXT(-84, testament_y - 15, "IT IS A SPRING TO WIND.")
    elif testament_page == 1:
        SET_INTENSITY(100)
        PRINT_TEXT(-70, testament_y + 15, "VOSS IS DEAD.")
        SET_INTENSITY(80)
        PRINT_TEXT(-84, testament_y - 15, "LONG LIVE THE MECHANISM.")

    if testament_y > 110:
        testament_page = testament_page + 1
        testament_y    = -110
        if testament_page >= 2:
            screen = STATE_ENDING

# ═══════════════════════════════════════════════════════════════════════════════
# ENDING — 3 branches
# ═══════════════════════════════════════════════════════════════════════════════
def draw_ending():
    SET_TEXT_SIZE(7)
    if ending_y < 50:
        ending_y = ending_y + 1

    if (flags_b & FL_ELISA_HELPED) != 0 and (flags_b & FL_HANS_HELPED) != 0:
        # ── True ending: both souls freed ───────────────────────────────────
        SET_INTENSITY(110)
        PRINT_TEXT(-91, ending_y + 70, "THE MECHANISM HALTS.")
        SET_INTENSITY(90)
        PRINT_TEXT(-91, ending_y + 50, "ELISA'S CURSE LIFTS.")
        PRINT_TEXT(-84, ending_y + 30, "HANS FINDS HIS REST.")
        SET_INTENSITY(70)
        PRINT_TEXT(-91, ending_y + 5,  "DAWN WAITS OUTSIDE.")
        PRINT_TEXT(-91, ending_y - 15, "THE CRYPT IS SILENT")
        PRINT_TEXT(-63, ending_y - 35, "AT LAST.")
        SET_INTENSITY(100)
        PRINT_TEXT(-63, ending_y - 65, "TRUE ENDING")
    elif (flags_b & FL_ELISA_HELPED) != 0:
        # ── Elisa ending: one soul freed ────────────────────────────────────
        SET_INTENSITY(110)
        PRINT_TEXT(-91, ending_y + 70, "ELISA'S SONG FILLS")
        SET_INTENSITY(90)
        PRINT_TEXT(-84, ending_y + 50, "THE VAULTED DARK.")
        PRINT_TEXT(-91, ending_y + 30, "YOU FOLLOW HER VOICE")
        PRINT_TEXT(-56, ending_y + 10, "TO FREEDOM.")
        SET_INTENSITY(60)
        PRINT_TEXT(-91, ending_y - 15, "HANS TICKS ON ALONE.")
        PRINT_TEXT(-91, ending_y - 35, "SOME THINGS CANNOT")
        PRINT_TEXT(-70, ending_y - 55, "BE WOUND DOWN.")
        SET_INTENSITY(100)
        PRINT_TEXT(-56, ending_y - 80, "ONE FREED")
    else:
        # ── Bad ending: hollow escape ────────────────────────────────────────
        SET_INTENSITY(110)
        PRINT_TEXT(-77, ending_y + 70, "THE CRYPT OPENS.")
        SET_INTENSITY(90)
        PRINT_TEXT(-91, ending_y + 50, "YOUR BODY WALKS OUT.")
        PRINT_TEXT(-91, ending_y + 30, "YOUR MIND STAYS IN,")
        PRINT_TEXT(-84, ending_y + 10, "WOUND LIKE A SPRING.")
        SET_INTENSITY(60)
        PRINT_TEXT(-91, ending_y - 15, "THE TICKING FOUND")
        PRINT_TEXT(-84, ending_y - 35, "A NEW HOME IN YOU.")
        SET_INTENSITY(100)
        PRINT_TEXT(-70, ending_y - 65, "HOLLOW ESCAPE")

    SET_INTENSITY(100)
    PRINT_TEXT(-49, ending_y - 95, "THE END.")

    if ending_y >= 50:
        SET_INTENSITY(50)
        PRINT_TEXT(-84, -90, "BTN1 TO RESTART")
        if btn1_fired == 1:
            ending_y      = -110
            screen        = STATE_TITLE
            current_music = MUSIC_TITLE
            PLAY_MUSIC("intro")

# ═══════════════════════════════════════════════════════════════════════════════
# HEARTBEAT — accelerate per puzzle
# ═══════════════════════════════════════════════════════════════════════════════
def accelerate_heartbeat():
    heartbeat_tempo = heartbeat_tempo - 8
    if heartbeat_tempo < 20:
        heartbeat_tempo = 20
