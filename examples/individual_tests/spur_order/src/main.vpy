# TEST: SPUR_ORDER — separa ORDEN de EJE, que es lo que draw_vector no permitia
#
# draw_vector dibuja cuatro figuras distintas a la vez, asi que cuando una sale
# mal no se sabe si es por su GEOMETRIA, por su POSICION o por CUANDO se dibuja.
# Aqui cada fila cambia UNA sola cosa.
#
# FILA 1 (arriba)   seis copias IDENTICAS, misma forma, misma orientacion.
#                   Lo unico que cambia entre ellas es el orden de dibujo.
#                   -> si las primeras salen sucias y las ultimas limpias: es ORDEN.
#                   -> si salen todas iguales: NO es orden.
#
# FILA 2 (abajo)    la misma forma GIRADA 90 grados, otras seis copias.
#                   Mismo orden relativo, distinto eje dominante.
#                   -> si la fila 1 y la 2 difieren entre si: es EJE.
#
# CADA COPIA LLEVA SU PROPIA REGLA: una caja, y dentro una diagonal que va de
# esquina a esquina. La diagonal NO debe sobresalir de la caja. Un espolon se ve
# como el pico saliendose de una recta que esta justo al lado, y eso se juzga sin
# dudar — que es lo que faltaba con "parece que mejora".

META TITLE = "SPUR_ORDER"

def main():
    pass

def loop():
    # --- FILA 1: caja 20x20 con diagonal. Segmentos con |dy| >= |dx|. ---
    # x = -75, -45, -15, 15, 45, 75   (seis, separadas 30)
    DRAW_RECT(-85, 30, 20, 20, 60)
    DRAW_LINE(-85, 30, -65, 50, 90)
    DRAW_RECT(-55, 30, 20, 20, 60)
    DRAW_LINE(-55, 30, -35, 50, 90)
    DRAW_RECT(-25, 30, 20, 20, 60)
    DRAW_LINE(-25, 30, -5, 50, 90)
    DRAW_RECT(5, 30, 20, 20, 60)
    DRAW_LINE(5, 30, 25, 50, 90)
    DRAW_RECT(35, 30, 20, 20, 60)
    DRAW_LINE(35, 30, 55, 50, 90)
    DRAW_RECT(65, 30, 20, 20, 60)
    DRAW_LINE(65, 30, 85, 50, 90)

    # --- FILA 2: la misma caja, diagonal en el otro sentido. ---
    DRAW_RECT(-85, -50, 20, 20, 60)
    DRAW_LINE(-85, -30, -65, -50, 90)
    DRAW_RECT(-55, -50, 20, 20, 60)
    DRAW_LINE(-55, -30, -35, -50, 90)
    DRAW_RECT(-25, -50, 20, 20, 60)
    DRAW_LINE(-25, -30, -5, -50, 90)
    DRAW_RECT(5, -50, 20, 20, 60)
    DRAW_LINE(5, -30, 25, -50, 90)
    DRAW_RECT(35, -50, 20, 20, 60)
    DRAW_LINE(35, -30, 55, -50, 90)
    DRAW_RECT(65, -50, 20, 20, 60)
    DRAW_LINE(65, -30, 85, -50, 90)
