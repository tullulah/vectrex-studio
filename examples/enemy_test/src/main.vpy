# enemy_test - Main entry point
# VPy game for Vectrex

META TITLE = "ENEMY TEST"
#META ROM_TOTAL_SIZE = 65536
#META ROM_BANK_SIZE = 16384

def main():
    # Called once at startup
    LOAD_LEVEL("level1")
    SPAWN_ENEMIES("level1")
    pass

def loop():
    # Game loop - called every frame
    UPDATE_ENEMIES()
    DRAW_ENEMIES()
    show_level()
    
