# TEST: DRAW_VECTOR_3D
# Tests 3D rotation of a vector asset on all axes simultaneously
# Expected: 3D object rotating continuously

META TITLE = "3D ROTATE"
META MUSIC = music1
# META ROM_TOTAL_SIZE = 65536
# META ROM_BANK_SIZE = 16384

angle_x = 0
angle_y = 0
angle_z = 0
    
def main():
    angle_x = 0
    angle_y = 0
    angle_z = 0

def loop():
    #angle_x = angle_x + 1
    angle_y = angle_y + 2
    #angle_z = angle_z + 1

    DRAW_VECTOR_3D("dtest", angle_x, angle_y, angle_z, 0, 0)

    DRAW_VECTOR_3D("dtest", angle_x, angle_y, angle_z, -40, -40)

    DRAW_VECTOR_3D("dtest", angle_x, angle_y, angle_z, 40, 40)

    DRAW_VECTOR_3D("dtest", angle_x, angle_y, angle_z, -40, 40)


