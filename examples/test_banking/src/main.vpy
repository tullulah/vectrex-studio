META TITLE = "TEST BANKING"
META ROM_TOTAL_SIZE = 65536
META ROM_BANK_SIZE = 16384

state: i16 = 0

def main():
    SET_INTENSITY(127)

def loop():
    btn1 = J1_BUTTON_1()
    if btn1 == 1:
        state = 1

    if state == 0:
        PLAY_MUSIC("intro")
        DRAW_VECTOR("crypt_logo", 0, 10)
    if state == 1:
        PLAY_MUSIC("exploration")
        DRAW_VECTOR("crypt_logo", 0, 10)
