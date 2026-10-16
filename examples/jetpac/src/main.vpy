META TITLE = "JETPAC MINIMAL"
META COPYRIGHT = "g 2025"
# META MUSIC = 1  # Comentado: Sin música por ahora

# ============================================
# JETPAC MINIMAL - Solo movimiento astronauta
# ============================================

# === STRUCT DEFINITIONS (COMENTADO) ===
# struct Vec2:
#     x: int
#     y: int
#     
#     def __init__(init_x, init_y):
#         # Constructor: initialize position
#         self.x = init_x
#         self.y = init_y

# struct Entity:
#     x: int
#     y: int
#     dx: int
#     dy: int
#     
#     def __init__(init_x, init_y, init_dx, init_dy):
#         # Constructor: initialize entity with position and velocity
#         self.x = init_x
#         self.y = init_y
#         self.dx = init_dx
#         self.dy = init_dy
#     
#     def update_position():
#         # ✅ NEW: Update position using self write
#         self.x = self.x + self.dx
#         self.y = self.y + self.dy
#     
#     def should_bounce_left(min_x):
#         # Check if should bounce off left edge
#         if self.x < min_x:
#             return 1
#         return 0
#     
#     def should_bounce_right(max_x):
#         # Check if should bounce off right edge
#         if self.x > max_x:
#             return 1
#         return 0
#     
#     def handle_bounce(min_x, max_x, speed):
#         # ✅ NEW: Handle bouncing and set new direction internally
#         if self.x < min_x:
#             self.dx = speed  # Bounce right
#         if self.x > max_x:
#             self.dx = -speed  # Bounce left

# struct ShipPart:
#     x: int
#     y: int
#     state: int  # 0=on platform, 1=carried, 2=assembled
#     
#     def __init__(init_x, init_y, init_state):
#         # Constructor: initialize ship part with position and state
#         self.x = init_x
#         self.y = init_y
#         self.state = init_state
#     
#     def is_on_platform():
#         # Check if part is on platform (not carried or assembled)
#         if self.state == 0:
#             return 1
#         return 0
#     
#     def is_assembled():
#         # Check if part is assembled
#         if self.state == 2:
#             return 1
#         return 0

# === GAME STATE ===
screen = 0        # 0=logo, 1=game
logo_timer = 0      # Frame counter for logo
logo_draw_counter = 0  # Dibuja logo cada 2 frames
fuel_level = 0
carried_part = 0    # Which part player carries (0=none)

# === ENTITY DATA ===
enemy_x = 100
enemy_y = 50
enemy_dx = -2
# enemy_dy = 0

part1_x = -80
part1_y = -40
part1_state = 0

part2_x = 0
part2_y = -15
part2_state = 0

part3_x = 80
part3_y = 15
part3_state = 0

ship_base_x = 0
ship_base_y = -85

# === PLATFORMS ===
plat1_y = -70       # Bottom
plat2_y = -20       # Middle
plat3_y = 30        # Top

# === PLAYER STATE (ESENCIAL) ===
player_x = 0
player_y = -80
player_dir = 0  # 0=right, 1=left (for sprite mirroring)

def main():
    # Inicialización
    PLAY_MUSIC("jetpac_theme")
    pass  # Placeholder

def loop():
    # === MÁQUINA DE ESTADOS ===
    if screen == 0:
        # Dibuja logo cada frame
        draw_logo_screen()
        logo_timer = logo_timer + 1

        if logo_timer > 300:
            screen = 1
            logo_timer = 0
    
    if screen == 1:
        
        
        # === INPUT HANDLING (ESENCIAL) ===
        joy_x = J1_X()  # -1 (izq), 0 (centro), +1 (der)
        joy_y = J1_Y()  # -1 (abajo), 0 (centro), +1 (arriba)
        
        # === PLAYER MOVEMENT (ESENCIAL) ===
        # Movimiento horizontal
        if joy_x == -1:
            player_x = player_x - 3
            player_dir = 1  # facing left
        if joy_x == 1:
            player_x = player_x + 3
            player_dir = 0  # facing right
        
        # Movimiento vertical
        if joy_y == -1:
            player_y = player_y - 3
        if joy_y == 1:
            player_y = player_y + 3
        
        # Boundaries (limites)
        if player_x < -110:
            player_x = -110
        if player_x > 110:
            player_x = 110
        if player_y < -90:
            player_y = -90
        if player_y > 90:
            player_y = 90
        
        # === PICKUP LOGIC ===
        # Auto-pickup if close to part (distance < 20)
        if carried_part == 0:
            # Check part 1
            # if part1_state == 0:
            #     dist_x = player_x - part1_x
            #     dist_y = player_y - part1_y
            #     if dist_x < 20 and dist_x > -20 and dist_y < 20 and dist_y > -20:
            #         carried_part = 1
            #         part1_state = 1
            # Check part 2
            if part2_state == 0:
                dist_x = player_x - part2_x
                dist_y = player_y - part2_y
                if dist_x < 20 and dist_x > -20 and dist_y < 20 and dist_y > -20:
                    carried_part = 2
                    part2_state = 1
            # Check part 3
            if part3_state == 0 and part2_state == 1:
                dist_x = player_x - part3_x
                dist_y = player_y - part3_y
                if dist_x < 20 and dist_x > -20 and dist_y < 20 and dist_y > -20:
                    carried_part = 3
                    part3_state = 1
        
        # === DROP-OFF LOGIC ===
        # If at base, drop part
        if carried_part > 0:
            dist_x = player_x - ship_base_x
            dist_y = player_y - ship_base_y
            if dist_x < 25 and dist_x > -25 and dist_y < 25 and dist_y > -25:
                # Drop the part
                if carried_part == 1:
                    part1_state = 2
                if carried_part == 2:
                    part2_state = 2
                if carried_part == 3:
                    part3_state = 2
                carried_part = 0
        
        # === DEBUG: Mostrar valores ===
        DEBUG_PRINT(player_dir)  # Marker
        
        
        # === DRAW PLATFORMS (ACTIVO) ===
        SET_INTENSITY(80)
        DRAW_VECTOR("platform", -80, plat1_y)
        DRAW_VECTOR("platform", 0, plat2_y)
        DRAW_VECTOR("platform", 80, plat3_y)
        #
        # === DRAW SHIP PARTS (on ground) ===
        SET_INTENSITY(127)
        # if part1_state == 0:
        #     DRAW_VECTOR("rocket_base", part1_x, part1_y)
        if part2_state == 0:
            DRAW_VECTOR("rocket_middle", part2_x, part2_y)
        if part3_state == 0:
            DRAW_VECTOR("rocket_top", part3_x, part3_y)
        
        # === DRAW SHIP BASE ===
        SET_INTENSITY(100)
        DRAW_VECTOR("rocket_base", ship_base_x, ship_base_y)
        
        # === DRAW ASSEMBLED PARTS AT BASE ===
        if part1_state == 2:
            SET_INTENSITY(127)
            DRAW_VECTOR("rocket_base", ship_base_x, ship_base_y + 1)
        if part2_state == 2:
            SET_INTENSITY(127)
            DRAW_VECTOR("rocket_middle", ship_base_x, ship_base_y + 1)
        if part3_state == 2:
            SET_INTENSITY(127)
            DRAW_VECTOR("rocket_top", ship_base_x, ship_base_y + 1)
        
        # === DRAW ENEMY ===
        SET_INTENSITY(127)
        DRAW_VECTOR("enemy_alien", enemy_x, enemy_y)
        
        # === UPDATE ENEMY MOVEMENT ===
        enemy_x = enemy_x + enemy_dx
        
        # Bounce logic
        if enemy_x < -100:
            enemy_dx = 2
        if enemy_x > 100:
            enemy_dx = -2
        
        # === DRAW ASTRONAUT (ESENCIAL) ===
        SET_INTENSITY(127)
        DRAW_VECTOR_EX("astronaut_armed", player_x, player_y, player_dir, 100)
        #DRAW_VECTOR("astronaut_armed", player_x, player_y)
        
        # === DRAW CARRIED PART (if any) ===
        if carried_part == 1:
            SET_INTENSITY(100)
            DRAW_VECTOR("rocket_base", player_x, player_y + 12)
        if carried_part == 2:
            SET_INTENSITY(100)
            DRAW_VECTOR("rocket_middle", player_x, player_y + 12)
        if carried_part == 3:
            SET_INTENSITY(100)
            DRAW_VECTOR("rocket_top", player_x, player_y + 12)
    
    # Update music at end of loop (after all drawing)
    # MUSIC_UPDATE()

def draw_logo_screen():
    # Draw logo usando jetpac_logo.vec
    SET_INTENSITY(127)
    DRAW_VECTOR("jetpac_logo", 0, 20)