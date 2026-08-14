/*
 * uvm2_psram.h — resultado de la sonda de PSRAM del UVM2. Ver uvm2_psram.c.
 *
 * La estructura es global y volatil a proposito: con SWD puesto se lee tal cual
 * y no hay que descifrar parpadeos de LED.
 */
#ifndef UVM2_PSRAM_H
#define UVM2_PSRAM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Centinela. Sin esto, leer la estructura de una imagen que NO esta cargada
 * devuelve el codigo de OTRO juego, y un `probed` distinto de cero se lee como
 * "la sonda corrio". Paso: dio un "ya esta mapeada" que era basura. Una palabra
 * improbable es la diferencia entre un dato y una casualidad. */
#define UVM2_PSRAM_MAGIC 0x50535231u   /* "PSR1" */

typedef struct {
    uint32_t magic;         /* UVM2_PSRAM_MAGIC si la sonda escribio esto   */
    uint32_t probed;        /* 1 = la sonda llego a ejecutarse            */
    uint32_t found;         /* 1 = el ID de fabricante es el esperado     */
    uint32_t mf_id;         /* byte 0 del READ_ID (0x0D = AP Memory)      */
    uint32_t kgd;           /* byte 1: known-good-die                     */
    uint32_t xip_before[4]; /* 0x11000000 ANTES de tocar nada             */
    /* Estado del QMI AL ENTRAR, antes de que la sonda toque nada. Sin esto no
     * se puede distinguir "el firmware la dejo montada" de "la montamos y luego
     * la rompimos": son dos lecturas distintas del mismo registro y hay que
     * capturar la primera. */
    uint32_t m1_timing_before;
    uint32_t m1_rfmt_before;
    uint32_t m1_rcmd_before;
    uint32_t direct_csr_before;
    /* Un rx() agotado y un chip que contesta cero devuelven LO MISMO: 0x00. Sin
     * contar los plantones, "no contesta" y "contesta cero" son la misma lectura,
     * y son diagnosticos opuestos. */
    uint32_t mf_id_spi;     /* READ_ID hablandole en UNA linea (SPI)        */
    uint32_t mf_id_after_qpi_exit; /* ...y despues de sacarlo de QPI          */
    /* Prueba electrica del UNICO cable exclusivo de U3: su chip select. El
     * resto del bus (SCK, SD0, SD1) lo comparte con la flash, y la flash
     * funciona —de ella arranca el firmware—, asi que esas lineas estan sanas.
     * Se conduce GPIO47 como salida normal y se lee lo que vuelve por el propio
     * pad: si no sigue a lo que conducimos, el problema es el cable, no el chip. */
    uint32_t cs_reads_when_high;
    uint32_t cs_reads_when_low;
    /* Indicio de CONTINUIDAD, no prueba. Se suelta la salida y se apagan los
     * pull INTERNOS, para que lo que se lea sea lo que hace la red de fuera. El
     * esquema pone un pull-up junto a U3: si la pista llega hasta el, un pin
     * conducido a cero y luego soltado vuelve solo a 1. Si esta cortada del lado
     * del chip, la red queda al aire y se queda en 0 por pura capacidad.
     * El discriminante es cs_float_tras_bajo. */
    uint32_t cs_float_tras_bajo;
    uint32_t cs_float_tras_alto;
    /* El mismo READ_ID a varias velocidades. Un chip bien cableado que calla
     * suele destaparse bajando el reloj. CLKDIV 6 = 25 MHz, 30 = 5 MHz,
     * 120 = 1,25 MHz. */
    uint32_t id_por_clkdiv[4];
    uint32_t clkdiv_probados[4];
    uint32_t rx_timeouts;
    uint32_t csr_after_cmd; /* DIRECT_CSR tras sacar el primer byte */
    uint32_t already_mapped;/* 1 = CS1 venia configurado: NO tocamos el chip  */
} uvm2_psram_result_t;

extern volatile uvm2_psram_result_t uvm2_psram_result;

/* Sondea. NO arma la ventana XIP ni escribe: primero saber que hay. */
int uvm2_psram_probe(void);

#ifdef __cplusplus
}
#endif

#endif /* UVM2_PSRAM_H */
