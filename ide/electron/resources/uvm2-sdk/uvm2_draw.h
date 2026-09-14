/*
 * uvm2_draw.h — Vectrex analog beam control, recorded as a VIA command stream.
 *
 * This is the port of Ralf's VectrexHaltCommandWriter: the sequences that a
 * 6809 would write to the VIA to move, light and blank the beam, emitted into a
 * buffer instead of onto the bus.  uvm2_frame_end() hands the whole buffer to
 * uvm2_exec(), so the beam draws with no gaps and the CPU never blocks on a
 * clock edge while composing a frame.
 *
 * Coordinates are VPy/Vectrex units, roughly -127..127 with +Y up, and deltas
 * are what the SYS_MOVE / SYS_DRAW_DELTA syscalls carry.  Intensity is 0..127.
 */
#ifndef UVM2_DRAW_H
#define UVM2_DRAW_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Configure the VIA and prime the integrators.  Call once, after uvm2_bus_init. */
void uvm2_draw_init(void);

/* SYS_RESET0REF — beam back to centre, blanked (zero the integrators). */
void uvm2_draw_reset(void);
/* Drop the cached DAC/mux state — see the note in uvm2_draw.c. */
void uvm2_draw_invalidate(void);
/* Re-charge the zero-reference / Y / Z holds after an analog read. */
void uvm2_draw_prime_holds(void);

/* SYS_SET_INTENSITY — Z-axis DAC, 0..127. */
void uvm2_draw_intensity(int brightness);

/* SYS_MOVE / SYS_DRAW_DELTA — relative, blanked and lit respectively. */
void uvm2_draw_move(int dx, int dy);
void uvm2_draw_delta(int dx, int dy);

/* LAS MISMAS EN 1/16 DE UNIDAD DE DISPOSITIVO. La rejilla entera es ~10 veces mas basta que
 * la del VecFever y eso deforma los glifos: 0,22 unidades de error por eje medidas en
 * mhavoc, con el 3,6% de los vectores enteramente sub-unidad. Requieren -DUVM2_SUBUNIDAD
 * para tener efecto; sin el redondean y se comportan como las enteras. */
void uvm2_draw_delta_q4(int dx_q4, int dy_q4);
void uvm2_draw_move_abs_q4(int x_q4, int y_q4);
/* La misma recta pero con tramos apagados, en UNA rampa. `huecos` son pares
 * (inicio, fin) en fracciones 0..255 de la recta. n = cuantos pares. */
void uvm2_draw_delta_patterned(int dx, int dy, const unsigned char *huecos, int n);

/* SYS_MOVE_ABS — absolute position, measured from centre. */
void uvm2_draw_move_abs(int x, int y);

/* Periodo del frame en CICLOS DE BUS. 0 = libre: se redibuja en cuanto la lista esta
 * hecha, como las recreativas. 30000 = enganchado a 50 Hz. Arranca en lo que diga UVM2_HZ.
 * Es variable y no #define para poder conmutarlo con el juego en marcha: la pregunta
 * "¿el temblor es un batido contra la red?" se contesta en segundos o no se contesta. */
extern volatile uint32_t uvm2_pacer_cycles;

/* ── EL REFRESCO, EN HERCIOS ─────────────────────────────────────────────────────────
 *
 * Y POR QUE ES UNA OPCION DEL JUEGO Y NO UNA CONSTANTE: el rizado de la red mueve el haz,
 * y solo queda ESTACIONARIO —o sea invisible— si el dibujo se repite a la MISMA frecuencia
 * que la toma de corriente. 50 Hz en Europa, 60 en America. Una consola de 60 Hz corriendo
 * un dibujo enganchado a 50 ve un batido de 10 Hz: una oscilacion lenta y bien visible.
 * Con el enganche puesto a SU frecuencia, el rizado cae en la misma fase cada frame y pasa
 * de moverse a ser un sesgo fijo.
 *
 * `hz` = 0 deja el frame libre: se presenta en cuanto la lista esta hecha, como la
 * recreativa. Va mas rapido y tiembla con la red; es lo que quiere un banco de medida.
 *
 * ENGANCHAR SOLO SIRVE SI EL DIBUJO CABE. Un frame que se pasa del periodo pierde el
 * enganche y dura el doble, y alternar 20 y 40 ms tiembla PEOR que no enganchar. Por eso
 * esta `uvm2_refresco_cabe()`: preguntarlo despues de un frame tipico dice si el juego se
 * puede permitir esa frecuencia. Tambien lo cuenta `uvm2_stats.overrun`.
 *
 * Es la primera entrada de la superficie de AJUSTES DEL JUEGO. Lo que venga detras (escala,
 * brillo, region) va aqui y con la misma forma: una funcion con nombre y unidades de
 * verdad, no una variable global en ciclos que cada juego interprete a su manera. */
int      uvm2_draw_intensity_actual(void);
/** Levantar el lapiz sin moverse: se llama ANTES de un `uvm2_draw_move_abs` y solo tiene
 *  efecto si ese salto mide cero. Ver la nota de `s_penup_pendiente`. */
void     uvm2_draw_penup(void);

void     uvm2_refresco(unsigned hz);
unsigned uvm2_refresco_actual(void);
/** 1 si el ultimo frame cupo en el periodo (o si el refresco es libre). */
int      uvm2_refresco_cabe(void);

/* Frame boundary.  uvm2_frame_end() blanks, re-centres, replays the stream and
 * then pads the frame out to exactly 30000 bus cycles (50 Hz), locked to the
 * Vectrex clock rather than to any RP2350 timer. */
void uvm2_frame_begin(void);
/* Un comando crudo en la lista. Solo para bancos de medida — ver uvm2_draw.c. */
void uvm2_emit_raw(uint32_t reg, uint32_t data, uint32_t hueco);
uint32_t uvm2_ciclos_lista(void);
void uvm2_frame_end(void);

/* Frames completed since boot — the only clock a halted Vectrex gives us. */
uint32_t uvm2_frame_count(void);

/* Bus cycles the last frame actually consumed, padding included. Equals
 * UVM2_CYCLES_PER_FRAME for a frame that fit, and more for one that did not —
 * which is how audio keeps its tempo when drawing runs over. */
uint32_t uvm2_frame_bus_cycles(void);

/* ── Throughput levers (the point of the command-stream model) ──────────────
 * scale is the ramp duration in bus cycles for a full-range delta; it is the
 * dominant per-vector cost.  With scale = 128 a vector costs ~136 cycles, so a
 * 50 Hz frame fits ~220 of them.
 *
 * "fixup" is the lever Ralf left in his writer but commented out: while a delta
 * is small, double it and halve the scale.  A short vector then ramps for far
 * fewer cycles at the same length on screen.  Off by default so measurements
 * are directly comparable to his; turn it on to see the difference. */
void uvm2_draw_set_scale(uint32_t cycles);

#ifdef __cplusplus
}
#endif

/* TIEMPO DE MUESTREO DE CADA RETENCION, en ciclos de E, POR CANAL.
 *
 * Por el mux pasan tres retenciones —Y, Z y la referencia de cero— con su propio
 * condensador cada una, y un solo par de numeros no le vale a las tres. PiTrex tiene cuatro
 * tiempos separados (YSH_A/B, XSH_A/B) por exactamente esa razon.
 *
 * El minimo es lo que se le da a un salto diminuto y el maximo el tope para uno de fondo de
 * escala; entre medias la ley sigue siendo logaritmica (tau*ln2 por bit). Defecto 4 y 15,
 * los de siempre, asi que no tocarlas no cambia nada.
 *
 * PARA QUE SIRVE LA DE Y: con el trio de `caminos` en consola, un trazo que solo pide X sale
 * INCLINADO — la Y se mueve donde la lista pide vy = 0 exacto. Si no se muestrea el tiempo
 * suficiente, el valor retenido se queda a medio camino. */
extern volatile int32_t uvm2_hold_y_min, uvm2_hold_y_max;
extern volatile int32_t uvm2_hold_z_min, uvm2_hold_z_max;

#endif /* UVM2_DRAW_H */
