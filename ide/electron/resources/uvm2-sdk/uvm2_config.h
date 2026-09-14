/* uvm2_config.h — LA CALIBRACION DEL HAZ, que es de la CONSOLA y no del juego.
 *
 * El mismo tubo, la misma deriva y el mismo desajuste de escala los sufren los 44 puertos,
 * asi que la calibracion es UNA y compartida. Lo que si es del juego —VCAP, MIN_T1, la
 * escala de su geometria— se queda donde esta, en su Makefile.
 *
 * FLUJO, como lo pidio Daniel: cada juego llama a `uvm2_config_cargar()` al arrancar. Si hay
 * calibracion, la aplica y sigue. Si no, el juego abre el asistente y al terminar guarda.
 *
 * DE DONDE SALE Y DONDE SE GUARDA, y no es el mismo sitio a proposito:
 *
 *   - LEE de `config/uvm2.cfg` en la SD si existe. Es texto, asi que se puede mirar y editar
 *     desde el PC — que mientras estemos afinando esto vale mas que la comodidad.
 *   - Si no hay fichero, lee de la FLASH del RP2350.
 *   - GUARDA siempre en la FLASH. El lector FAT de `uvm2_sd.c` es de SOLO LECTURA: crear un
 *     fichero pide asignar clusters y reescribir las dos copias de la FAT, y equivocarse ahi
 *     corrompe la tarjeta del usuario. La flash ademas sobrevive a cambiar de tarjeta, que
 *     es lo correcto para algo que describe la CONSOLA.
 *
 * QUE HAY DENTRO, y por que estos cuatro y no los dieciocho knobs del dibujo. El error entre
 * lo que se pide y lo que recorre el haz tiene DOS terminos:
 *
 *     proporcional a la longitud  -> la escala
 *     fijo por trazo              -> el arranque de la rampa
 *
 * Los vectores largos los domina el primero; el texto, que son muchos trazos cortos, el
 * segundo. Por eso el VecFever tiene una pantalla para cada uno (lo confirma Technobly), y
 * por eso un poligono cerrado que se ABRE acusa al termino FIJO: un error de escala lo haria
 * mas pequeño pero seguiria cerrado. Los otros dos son el cero y el brillo, que no corrigen
 * geometria pero cambian lo que se ve al ajustarla. */
#ifndef UVM2_CONFIG_H
#define UVM2_CONFIG_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

struct uvm2_config {
    int32_t escala;      /* DRAW_SCALE: el divisor. MAS grande = trazos MAS cortos. */
    int32_t fijo_q8;     /* T1_EXTRA_Q8: la duracion REAL de la rampa, en 1/256 de cuenta.
                          * El 6522 cuenta t1 + 1,5 en un disparo, asi que el valor honesto
                          * no es 0; se mide cerrando un poligono de trazos cortos. */
    int32_t cero;        /* uvm2_cero_offset: el valor que se ceba en la referencia de cero. */
    int32_t brillo;      /* Z por defecto, 0..127. */
    /* MUESTREO DE LA RETENCION DE Y, en ciclos de E: el minimo para un salto diminuto y el
     * tope para uno de fondo de escala. Es de la CONSOLA —el condensador es C304 y su Ron
     * es el del 4052 que lleve dentro— y es el unico de los tres canales que cambia
     * GEOMETRIA: si la Y no se muestrea bastante, un trazo que solo pide X sale inclinado.
     * PiTrex calibra cuatro tiempos de retencion por lo mismo. Defecto 4 y 15. */
    int32_t hold_y_min;
    int32_t hold_y_max;
    /* AJUSTE FINO DE LAS TASAS NEGATIVAS, por eje, en 1/256. El DAC no se desvia igual en
     * +k que en -k, asi que una diagonal donde los dos ejes piden numeros OPUESTOS no sale
     * a 45 grados y la ida y la vuelta se separan. Ni el cero (mueve los dos ejes a la vez)
     * ni la escala (simetrica) lo alcanzan. Ver TASA_NEG_X/Y en vectrex-draw. Defecto 0. */
    int32_t tasa_neg_x;
    int32_t tasa_neg_y;
    /* DERIVA POR SALTO, por eje, en 1/256. El haz no acaba donde se le manda y el error se
     * acumula salto a salto: sin compensar, una columna de lineas pedidas en la MISMA x sale
     * en cascada hacia un lado. Medido en consola el 2026-08-12 con hardware/uvm2/drift:
     * X -16/256 y Y -112/256, siete veces mas en Y porque Y pasa por el sample-and-hold y X
     * va directa al DAC. Defecto 0 = sin compensar. */
    int32_t deriva_x;
    int32_t deriva_y;
};

/** Rellena `c` con lo que valen los knobs AHORA. */
void uvm2_config_actual(struct uvm2_config *c);

/** Aplica `c` a los knobs vivos. */
void uvm2_config_aplicar(const struct uvm2_config *c);

/** Lo que devolvio `uvm2_config_cargar()` en `uvm2_draw_init`, para que el juego no tenga
 *  que volver a leer la tarjeta solo para saber si abrir el asistente. */
extern volatile int uvm2_hay_calibracion;

/** 1 si habia calibracion guardada (y queda aplicada); 0 si no hay ninguna. */
int  uvm2_config_cargar(void);

/** LA PANTALLA DE CALIBRACION. Corre su propio bucle de frame hasta que el usuario pulsa
 *  el boton 4; devuelve 1 si la calibracion quedo guardada.
 *
 *  El juego la abre asi:   if (!uvm2_hay_calibracion) uvm2_config_asistente();
 *
 *  Dibuja DOS cuadrados del mismo tamaño, uno con 4 trazos largos y otro con 40 cortos: el
 *  que se abra dice cual de los dos terminos del error hay que mover. Ver uvm2_asistente.c. */
int  uvm2_config_asistente(void);

/** La misma pantalla, pero dibujando LA FIGURA DEL JUEGO en vez del patron del SDK.
 *
 *  Calibrar contra el dibujo que molesta vale mas que contra una figura de laboratorio: el
 *  juego pasa su propia figura, ya centrada y a su escala, y el asistente no sabe nada de
 *  ella. Con `figura` a cero es exactamente `uvm2_config_asistente()`. */
int  uvm2_config_asistente_con(void (*figura)(void));

/** Guarda la calibracion actual. 1 si se pudo.
 *
 *  Escribe `config/uvm2.cfg` EN SITIO, que no toca ni la FAT ni el directorio. Si el fichero
 *  no existe devuelve 0 y no lo crea: crearlo asigna clusters y reescribe las dos copias de
 *  la FAT, y eso colgo a dkong en consola el 2026-09-14 con una tarjeta sin `config/`. Para
 *  permitirlo hay que pedirlo con `uvm2_config_permitir_crear(1)`. */
int  uvm2_config_guardar(void);

/** Deja (o no) que `uvm2_config_guardar` CREE el fichero si no existe. Apagado de serie: ver
 *  la nota de arriba. Crear toca la FAT, y una escritura a medias es la tarjeta del usuario. */
void uvm2_config_permitir_crear(int si);

#ifdef __cplusplus
}
#endif
#endif /* UVM2_CONFIG_H */
