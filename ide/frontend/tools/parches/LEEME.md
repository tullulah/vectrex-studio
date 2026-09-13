# pio-al-reloj-de-bus.patch — EMPEZADO, NO TERMINADO

Corrige el defecto de fidelidad mas gordo que tiene el emulador del UVM2 hoy, y **no se
aplica porque regresiona**. Se guarda entero para no volver a derivarlo.

## El defecto

`dmaTransferencia()` recorre la transferencia ENTERA —hasta 65536 palabras— corriendo un
periodo de E por cada una, y todo eso en **cero ciclos de CPU**. O sea que el reloj del bus
lo mueven DOS cosas a la vez: el tiempo de CPU (por `advanceBus`) y el consumo de palabras
del PIO. En la placa hay UN solo reloj de bus y el PIO va enganchado a el.

Se mide con `tools/contadores.mjs`, que lee el TIMER del propio juego (microsegundos)
contra el contador de ciclos de bus del emulador. Por cada microsegundo tienen que pasar
1,5 ciclos (bus a 1,5 MHz):

    hoy                         2.742    <- un 83% de ciclos de bus REGALADOS
    con el parche               1.619
    lo que tiene que salir      1.500

## Lo que hace el parche

Invierte el mando: el lote del DMA se APUNTA (`dmaSrc`, `dmaRestan`) y lo consume `sirvePio`
a razon de UNA palabra por periodo de E, llamado desde el flanco de bajada de `halfStep`.
Una palabra de park arma `pioEspera` en vez de correr N periodos gratis. Asi, que el juego
no llene el lote deja de ser invisible: el PIO aparca, que es lo que hace la placa.

De propina arregla un contador del juego que se desbordaba (`us_rest` salia 4294967199) y
sube los vectores del menu de 103 a 124.

## Por que no se aplica

**El juego no pasa del menu**: la pulsacion no llega. Probado con `40:1`, `40:1,200:1`,
`80:4` y `40:3` — en las cuatro `us_lista_n` se queda en 0, o sea que el bucle de partida no
corre. El dibujo del menu si sale.

La sospecha es el reparto de `gpioOut`, que es el MISMO sitio por el que el nucleo conduce
el bus a mano para leer los mandos. Media correccion ya esta en el parche (no aparcar
cuando el PIO no tiene lote), y con ella el menu dibuja mejor, pero el boton sigue sin
llegar. Lo que falta es entender por donde lee la entrada el nucleo 1 antes de seguir
tocando el PIO — medirlo, no suponerlo.
