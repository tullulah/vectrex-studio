/* LA ANATOMIA DE UNA OPERACION, decodificando la lista de comandos DE VERDAD.
 *
 * El arnes que habia (uvm2_coste_op.c) contaba `g_cyc += n`: UN ciclo por comando, y
 * tiraba el campo de retardo. Pero el retardo es exactamente donde esta el tiempo — el
 * ejecutor gasta 1 + delay por comando. Medido asi, los 85 ciclos por operacion que se
 * ven en consola no se pueden explicar, y una anatomia que no suma el total que mide el
 * hardware no describe nada.
 *
 * Aqui se emite una cadena de vectores con el emisor REAL y los tiempos REALES, se
 * decodifica la lista empaquetada (3 bytes: retardo 12, registro 4, dato 8) y se atribuye
 * cada ciclo a la etapa que lo gasta.
 *
 *   cc -O2 -DUVM2_HOST -I. -o /tmp/anat tools/uvm2_anatomia.c uvm2_draw.c \
 *      <vectrex-draw>/cabi/target/release/libvectrex_draw_cabi.a
 */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include "uvm2_bus.h"
#include "uvm2_draw.h"

uvm2_stats_t uvm2_stats;
const uint8_t *uvm2_frame_buffer(uint32_t);
uint32_t uvm2_exec(const uint8_t *c, uint32_t n);
void     uvm2_bus_delay(uint32_t c) { (void)c; }
void     uvm2_via_write(uint32_t r, uint32_t d) { (void)r; (void)d; }

/* la lista que el emisor acaba de construir, tal cual la leeria el ejecutor */
static const uint8_t *g_lista; static uint32_t g_n;
uint32_t uvm2_exec(const uint8_t *c, uint32_t n){ g_lista = c; g_n = n; return 0; }

static const char *nombre(uint32_t reg)
{
    switch (reg){
    case UVM2_VIA_PORTA: return "PORT_A  (DAC: velocidad X o Y)";
    case UVM2_VIA_PORTB: return "PORT_B  (mux: muestreo de Y)";
    case UVM2_VIA_T1CL:  return "T1CL    (escala de la rampa)";
    case UVM2_VIA_T1CH:  return "T1CH    (ARRANCA la rampa)";
    case UVM2_VIA_T1LL:  return "T1LL    (ESPERA a que acabe)";
    case UVM2_VIA_PCR:   return "CNTL    (enciende/apaga el haz)";
    default:             return "otro";
    }
}

int main(void)
{
    uvm2_draw_init();
    uvm2_frame_begin();
    /* una cadena tipica de dkong: trazos cortos encadenados, como una escalera o el
     * escenario. La longitud importa: t1 crece con ella y la rampa es el termino que
     * ESCALA, todo lo demas es fijo. */
    const int N = 32, L = 8;
    uvm2_draw_move(0, 0);
    for (int i = 0; i < N; i++) uvm2_draw_delta(L, (i & 1) ? L : -L);
    uvm2_frame_end();

    uint32_t esc[16] = {0}, ret[16] = {0}, cnt[16] = {0};
    uint32_t total = 0;
    for (uint32_t i = 0; i < g_n; i++){
        uint32_t v = (uint32_t)g_lista[i*3] | ((uint32_t)g_lista[i*3+1] << 8)
                   | ((uint32_t)g_lista[i*3+2] << 16);
        uint32_t reg = (v >> 8) & 0xF, d = UVM2_CMD_RETARDO(v);
        esc[reg] += 1; ret[reg] += d; cnt[reg]++;
        total += 1 + d;
    }
    printf("  cadena de %d vectores de %d unidades, %u comandos, %u ciclos de bus\n",
           N, L, g_n, total);
    printf("  -> %.1f ciclos por operacion\n\n", (double)total / N);
    printf("  %-34s  cmds  escritura  espera   total   %%\n", "etapa");
    for (int r = 0; r < 16; r++){
        if (!cnt[r]) continue;
        uint32_t t = esc[r] + ret[r];
        printf("  %-34s %5u %10u %7u %7u  %4.1f%%\n",
               nombre((uint32_t)r), cnt[r], esc[r], ret[r], t, 100.0*t/total);
    }
    uint32_t we = 0, wr = 0;
    for (int r = 0; r < 16; r++){ we += esc[r]; wr += ret[r]; }
    /* LA SECUENCIA, comando a comando. Una tabla de totales dice CUANTO; esto dice QUE,
     * y es lo unico que permite ver un retardo colgado del registro equivocado. */
    printf("\n  comandos 40..61: dos vectores encadenados en mitad de la cadena\n");
    for (uint32_t i = 40; i < g_n && i < 62; i++){
        uint32_t v = (uint32_t)g_lista[i*3] | ((uint32_t)g_lista[i*3+1] << 8)
                   | ((uint32_t)g_lista[i*3+2] << 16);
        printf("    %2u  %-34s dato %3u   espera %u\n",
               i, nombre((v >> 8) & 0xF), v & 0xFF, UVM2_CMD_RETARDO(v));
    }
    printf("\n  ESCRITURAS %u ciclos (%.1f%%)   ESPERAS %u ciclos (%.1f%%)\n",
           we, 100.0*we/total, wr, 100.0*wr/total);
    return 0;
}
