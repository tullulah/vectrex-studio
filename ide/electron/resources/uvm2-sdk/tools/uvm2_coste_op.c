/* Host harness: WHAT ONE OPERATION COSTS, broken down. Links the REAL uvm2_draw.c against
 * a mocked bus and counts, per primitive, how many commands go out and how many bus cycles
 * they consume — the anatomy of the ~39 cycles of overhead that ride on every vector.
 *
 *   cc -O2 -DUVM2_HOST -I<sdk> -o costeop tools/uvm2_coste_op.c uvm2_draw.c \
 *      <vectrex-draw>/cabi/target/release/libvectrex_draw_cabi.a eh.c
 */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include "uvm2_bus.h"
#include "uvm2_draw.h"
const uint8_t *uvm2_frame_buffer(uint32_t);

uvm2_stats_t uvm2_stats;
static uint32_t g_cyc, g_cmd, g_delay;

uint32_t uvm2_exec(const uint8_t *c, uint32_t n) { (void)c; g_cmd += n; g_cyc += n; return n; }
void     uvm2_bus_delay(uint32_t c)              { g_cyc += c; g_delay += c; }
void     uvm2_via_write(uint32_t r, uint32_t d)  { (void)r; (void)d; g_cmd++; g_cyc++; }
uint8_t  uvm2_via_read(uint32_t r)               { (void)r; return 0; }

static void cero(void) { g_cyc = g_cmd = g_delay = 0; }
static void di(const char *q) {
    printf("  %-34s %4u comandos  %5u ciclos  (%u de retardo)\n", q, g_cmd, g_cyc, g_delay);
}

static uint32_t base_cmd, base_cyc;

/* Cada primitiva ENCOLA; la lista se ejecuta al cerrar el frame. Asi que se mide
 * (frame_begin + primitiva + frame_end) y se le resta (frame_begin + frame_end). */
static void medir(const char *q, void (*f)(void))
{
    cero(); uvm2_frame_begin(); if (f) f(); uvm2_frame_end();
    if (!f) { base_cmd = g_cmd; base_cyc = g_cyc; printf("  %-30s %4u comandos  %5u ciclos   <- linea base\n", q, g_cmd, g_cyc); return; }
    printf("  %-30s %4d comandos  %5d ciclos\n", q, (int)g_cmd-(int)base_cmd, (int)g_cyc-(int)base_cyc);
}
static void p_reset(void){ uvm2_draw_reset(); }
static void p_int(void)  { uvm2_draw_intensity(0x5F); }
static void p_mov(void)  { uvm2_draw_move(40,30); }
static void p_h(void)    { uvm2_draw_delta(60,0); }
static void p_v(void)    { uvm2_draw_delta(0,60); }
static void p_d(void)    { uvm2_draw_delta(60,45); }
static void p_c(void)    { uvm2_draw_delta(4,3); }
static void p_2(void)    { uvm2_draw_delta(60,45); uvm2_draw_delta(60,45); }
static void p_mov2(void) { uvm2_draw_move(40,30); uvm2_draw_move(40,30); }

static const char *REG[16] = {"ORB","ORA","DDRB","DDRA","T1CL","T1CH","T1LL","T1LH",
                              "T2CL","T2CH","SR","ACR","PCR","IFR","IER","ORAnh"};
/* Volcar la lista tal cual: registro, dato y retardo de cada comando. */
static void volcar(const char *q, void (*f)(void))
{
    cero(); uvm2_frame_begin();
    const uint8_t *b = uvm2_frame_buffer(0);
    uint32_t antes = uvm2_stats.commands;
    f(); uvm2_frame_end();
    uint32_t n = uvm2_stats.commands;
    printf("\n== %s : %u comandos ==\n", q, n);
    for (uint32_t i = 0; i < n && i < 60; i++){
        uint32_t v = (uint32_t)b[i*3] | ((uint32_t)b[i*3+1] << 8) | ((uint32_t)b[i*3+2] << 16);
        printf("   %2u  %-5s dato %3u  retardo %4u\n",
               i, REG[(v >> 8) & 0xF], (v >> 0) & 0xFF, v >> 12);
    }
    (void)antes;
}
static void nada(void){}

int main(void)
{
    uvm2_draw_init();
    medir("nada", 0);
    medir("reset0ref (re-cero)", p_reset);
    medir("intensidad", p_int);
    medir("move 40,30", p_mov);
    medir("move 40,30 x2", p_mov2);
    medir("draw 60,0  horizontal", p_h);
    medir("draw 0,60  vertical", p_v);
    medir("draw 60,45 diagonal", p_d);
    medir("draw 4,3   corto", p_c);
    medir("draw 60,45 x2 encadenado", p_2);
    volcar("un frame con UN solo draw", p_d);
    volcar("frame vacio", nada);
    return 0;
}
