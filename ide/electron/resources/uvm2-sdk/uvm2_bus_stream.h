/* uvm2_bus_stream.h — la cara en C de la caja compartida `vectrex-bus`.
 *
 * NO HAY IMPLEMENTACION AQUI, y es deliberado: el conductor del stream (el anillo de
 * lotes, el DMA, el programa de PIO y su calibracion de fase) vive UNA sola vez, en
 * resources/vectrex-bus, y lo enlazan el firmware del cartucho propio (como rlib) y esta
 * imagen (como staticlib). Cualquier decision que apareciera en este fichero seria una
 * segunda implementacion disfrazada de cabecera.
 */
#ifndef UVM2_BUS_STREAM_H
#define UVM2_BUS_STREAM_H

#include <stdint.h>

void     vbus_install(uint32_t out_base, uint32_t out_count, uint32_t out_dirs, uint32_t park);
uint32_t vbus_word(uint32_t bus_word);
uint32_t vbus_repeat(uint32_t n);
uint32_t vbus_silence(void);
void     vbus_push(uint32_t word);
void     vbus_flush(void);
void     vbus_drain(void);

/* Contadores por indice. EL ORDEN LO FIJA cabi/src/lib.rs y los dos se mueven juntos. */
#define VBUS_PUSHES     0u
#define VBUS_STALLS     1u
#define VBUS_BATCH_SENT 2u
#define VBUS_BATCH_WAIT 3u
#define VBUS_FULL_SEEN  4u
#define VBUS_OVERRUNS   5u
uint32_t vbus_stat(uint32_t idx);

void uvm2_stream_start(void);

/* Las direcciones de pin leidas JUSTO DESPUES de instalar. Comparar con la misma lectura
 * hecha mas tarde por SWD: si aqui sale bien y luego mal, el SM se ha reiniciado. */
extern uint32_t uvm2_stream_dirs_tras_install;

#endif
