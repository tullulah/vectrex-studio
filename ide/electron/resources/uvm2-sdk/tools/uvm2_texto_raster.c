/* TEXTO POR TRAZOS CONTRA TEXTO POR BARRIDO, CON EL EMISOR DE VERDAD.
 *
 * La pregunta es de aae_esb y vale para cualquier puerto con mucho texto: su atraccion es
 * 80-95% glifos, y cada glifo cuesta 3,13 trazos y 2,65 saltos. Con el coste medido en
 * tools/uvm2_cuenta_lista -- un trazo 13,05 comandos, PLANO en la longitud, y un salto
 * +5,29 -- eso son ~55 comandos por caracter, y de ahi sale el frame entero.
 *
 * LA ALTERNATIVA ES LA DE LA BIOS DE VECTREX: no dibujar la letra, barrerla. Una rampa
 * larga por fila de pixeles y el BLANK conmutado por el camino, que es exactamente lo que
 * hace uvm2_draw_delta_patterned (una rampa, hasta 16 pares de huecos). El coste del trazo
 * no sube con la distancia, asi que el barrido se amortiza entre todos los caracteres de
 * la linea: cuanto mas largo el texto, mejor sale.
 *
 * LAS DOS DIBUJAN LA MISMA LETRA. El mapa de bits lo rasteriza gen_fuente_datos.py desde
 * la tinta del propio AVG, no de otra fuente; si no, el ráster ganaria por ser mas simple
 * y no por ser mas barato.
 *
 *   python3 <juego>/tools/gen_fuente_datos.py region0.bin > /tmp/esb_fuente_datos.h
 *   cc -O2 -DUVM2_HOST -DUVM2_BANCO_SIN_NUCLEO1 -DUVM2_SUBUNIDAD -DUVM2_CMD_CAPACITY=65536u \
 *      -I<sdk> -I/tmp -o /tmp/texto tools/uvm2_texto_raster.c <sdk>/uvm2_draw.c \
 *      <vectrex-draw>/cabi/target/release/libvectrex_draw_cabi.a
 *   /tmp/texto < lineas.txt
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "uvm2_bus.h"
#include "uvm2_draw.h"
#include "esb_fuente_datos.h"

uvm2_stats_t uvm2_stats;

static uint32_t g_cmds, g_ciclos, g_palabras;
static uint32_t g_reg_cmds[16];

static int g_dump;
static const char *reg_nom(uint32_t r){
    switch(r){case 1:return "ORA/DAC";case 0:return "ORB/mux";case 4:return "T1CL";
    case 5:return "T1CH";case 6:return "T1LL";case 0xC:return "PCR";case 0xA:return "SR";
    case 0xB:return "ACR";default:return "?";}
}
uint32_t uvm2_exec(const uint8_t *c, uint32_t n)
{
    g_cmds = n; g_ciclos = 0; g_palabras = 0;
    for (uint32_t i = 0; i < 16; i++) g_reg_cmds[i] = 0;
    for (uint32_t i = 0; i < n; i++) {
        uint32_t v = (uint32_t)c[i*3] | ((uint32_t)c[i*3+1] << 8) | ((uint32_t)c[i*3+2] << 16);
        uint32_t reg = (v >> 8) & 0xF, d = UVM2_CMD_RETARDO(v);
        g_ciclos += 1 + d; g_palabras += d ? 2u : 1u; g_reg_cmds[reg]++;
        if (g_dump) printf("  %4u  %-8s %02X  hueco %u\n", i, reg_nom(reg), v & 0xFFu, d);
    }
    return g_ciclos;
}
void     uvm2_bus_delay(uint32_t c) { (void)c; }
void     uvm2_via_write(uint32_t r, uint32_t d) { (void)r; (void)d; }
uint8_t  uvm2_via_read(uint32_t r) { (void)r; return 0; }
void uvm2_config_cargar(void) {}
volatile int uvm2_hay_calibracion = 0;
unsigned uvm2_smp_s_active = 0;
int  uvm2_smp_due(uint32_t c, uint8_t *v) { (void)c; (void)v; return 0; }
uint8_t uvm2_smp_mixer(void) { return 0; }
int  uvm2_smp_needs_latch(void) { return 0; }
void uvm2_smp_frame(uint32_t c) { (void)c; }
uint32_t uvm2_smp_injected = 0;
void rust_eh_personality(void) {}

#ifndef VPY_SCALE
#define VPY_SCALE 127
#endif
#define VS_Q4(v) ((int)(((v) < 0 ? (long)(v) * 16 - VPY_SCALE / 2 \
                                 : (long)(v) * 16 + VPY_SCALE / 2) / VPY_SCALE))

/* UNIDADES. Una unidad del AVG vale UNIT unidades de entrada; con UNIT=20 un trazo de
 * glifo (16 unidades) sale en 320, que es la mediana medida en el frame real de esb
 * (324). Asi los numeros de aqui se pueden poner al lado de los de uvm2_cuenta_lista. */
static int UNIT = 20;
#define ADV   (24 * UNIT)          /* avance entre caracteres */
#define LINEH (32 * UNIT)          /* alto de linea */

#define MAXL 64
static char  lineas[MAXL][128];
static int   n_lineas;
static long  n_glifos, n_trazos, n_rampas;

static int glyph_i(int c)
{
    if (c >= 'a' && c <= 'z') c -= 32;
    return (c < F_FIRST || c > F_LAST) ? 0 : c - F_FIRST;
}

/* ── por trazos: lo que hace el juego hoy ──────────────────────────────────── */
static void dibuja_vector(void)
{
    for (int L = 0; L < n_lineas; L++) {
        int y0 = -L * LINEH, x0 = 0;
        for (const char *p = lineas[L]; *p; p++, x0 += ADV) {
            int g = glyph_i((unsigned char)*p);
            int off = f_ink[g][0], cnt = f_ink[g][1];
            n_glifos++;
            for (int s = 0; s < cnt; s++) {
                int ax = x0 + f_pool[off+s][0] * UNIT, ay = y0 + f_pool[off+s][1] * UNIT;
                int bx = x0 + f_pool[off+s][2] * UNIT, by = y0 + f_pool[off+s][3] * UNIT;
                uvm2_draw_move_abs_q4(VS_Q4(ax), VS_Q4(ay));
                uvm2_draw_delta_q4(VS_Q4(bx) - VS_Q4(ax), VS_Q4(by) - VS_Q4(ay));
                n_trazos++;
            }
        }
    }
}

/* ── por barrido: una rampa por fila, el BLANK conmutado por el camino ─────── */
#define MAXH 16                     /* el tope de uvm2_draw_delta_patterned */

static void dibuja_raster(void)
{
    const int DOT = (F_CELL_W * UNIT) / F_COLS;     /* paso entre puntos */
    for (int L = 0; L < n_lineas; L++) {
        int len = (int)strlen(lineas[L]);
        for (int r = 0; r < F_ROWS; r++) {
            int y = -L * LINEH + ((F_ROWS - 1 - r) * F_CELL_H * UNIT) / F_ROWS;
            /* Se emite por TROZOS: el tope de huecos es 16, y ademas los huecos van en
             * fracciones 0..255 del vector — en una linea larga un octavo de caracter no
             * llega a una cuenta y el hueco se pierde al redondear. El trozo se cierra
             * cuando toca cualquiera de los dos limites. */
            int c = 0;
            while (c < len) {
                int h[MAXH * 2];   /* posiciones en unidades de entrada, no fracciones */
                int m = 0, c0 = c, dentro = -1;
                int cmax = c + (255 / F_COLS);      /* resolucion de las fracciones */
                while (c < len && c < cmax) {
                    unsigned char bits = f_bits[glyph_i((unsigned char)lineas[L][c])][r];
                    int col;
                    for (col = 0; col < F_COLS; col++) {
                        int on = (bits >> (F_COLS - 1 - col)) & 1;
                        int pos = (c - c0) * ADV + col * DOT;
                        if (!on && dentro < 0) dentro = pos;            /* empieza hueco */
                        else if (on && dentro >= 0) {
                            if (m >= MAXH) break;
                            h[m*2] = dentro; h[m*2+1] = pos;
                            m++; dentro = -1;
                        }
                    }
                    if (col < F_COLS || m >= MAXH) break;
                    /* el hueco entre caracteres (el avance menos el ancho de celda) */
                    if (dentro < 0) dentro = (c - c0) * ADV + F_COLS * DOT;
                    c++;
                }
                if (c == c0) c++;                                        /* siempre avanza */
                int largo = (c - c0) * ADV;
                if (dentro >= 0 && m < MAXH) {                           /* hueco final */
                    h[m*2] = dentro; h[m*2+1] = largo; m++;
                }
                /* posiciones -> fracciones 0..255 del vector */
                unsigned char frac[MAXH * 2];
                int mm = 0;
                for (int i = 0; i < m; i++) {
                    int a = (int)((long)h[i*2]   * 255 / (largo ? largo : 1));
                    int b = (int)((long)h[i*2+1] * 255 / (largo ? largo : 1));
                    if (a < 0) a = 0; if (b > 255) b = 255;
                    if (b <= a) continue;
                    frac[mm*2] = (unsigned char)a; frac[mm*2+1] = (unsigned char)b; mm++;
                }
                uvm2_draw_move_abs_q4(VS_Q4(c0 * ADV), VS_Q4(y));
                uvm2_draw_delta_patterned(VS_Q4(c0 * ADV + largo) - VS_Q4(c0 * ADV), 0,
                                          frac, mm);
                n_rampas++;
            }
        }
        n_glifos += len;
    }
}

/* ── por barrido con el registro de desplazamiento: el idioma de la BIOS ───────
 *
 * Un byte por caracter y por fila: la VIA saca los 8 puntos sola. La fila entera es UNA
 * rampa, sin trocear por huecos ni por resolucion de fracciones.
 *
 * El ancho de caracter NO se elige: los 8 desplazamientos duran 8 ciclos de Phi2, asi que
 * el caracter mide lo que la rampa recorra en `paso` cuentas de T1. Por eso el avance sale
 * de aqui (ADV_SR) y no de la metrica del AVG — y por eso la comprobacion de abajo cuenta
 * las escrituras al SR: si salen menos de las pedidas, la rampa se acabo antes y el texto
 * estaria cortado, que es la forma en que esto se rompe sin avisar. */
/* LA FUENTE DEL SDK POR uvm2_print_text, que es lo unico que el CARTUCHO alcanza con
 * nuestra letra y nuestro tamaño: su `draw_delta_patterned` vive en la BIOS flasheada y
 * alli el blanking del patron sigue escribiendo el PCR, que en el idioma de serie no
 * hace nada. Lo que hay que saber es si sale mas barata que la del juego, porque hace un
 * RE-CERO POR GLIFO. */
extern void uvm2_print_text(int x, int y, const char *str, int scale, int intensity);
static void dibuja_sdkfont(void)
{
    /* La caja del glifo es 4x6 en unidades de fuente y se escala con (v*escala)>>1, o
     * sea 2*escala de ancho. Para que ocupe lo mismo que la celda del juego (ADV en
     * unidades de entrada -> ADV/127 unidades de pantalla) la escala es esa /2. */
    const int esc = (ADV * 16 / VPY_SCALE) / 16 / 2;
    for (int L = 0; L < n_lineas; L++) {
        int y = (-L * LINEH) * 16 / VPY_SCALE / 16;
        uvm2_print_text(0, y, lineas[L], esc > 0 ? esc : 1, 127);
        n_glifos += (long)strlen(lineas[L]);
        n_rampas++;
    }
}

static int PASO = 8;
static int ADV_SR = 160;            /* unidades de entrada por caracter; ver arriba */
static long n_sr_pedidos;

static void dibuja_sr(void)
{
    for (int L = 0; L < n_lineas; L++) {
        int len = (int)strlen(lineas[L]);
        for (int r = 0; r < F_ROWS; r++) {
            int y = -L * LINEH + ((F_ROWS - 1 - r) * F_CELL_H * UNIT) / F_ROWS;
            /* Troceado por el tope de t1 (255 cuentas): con paso=8 caben 31 caracteres
             * por rampa. Una linea mas larga se parte, y cada trozo sigue siendo UNA
             * rampa — que es todo el punto. */
            int porRampa = 255 / PASO;
            for (int c0 = 0; c0 < len; c0 += porRampa) {
                unsigned char patron[64];
                int n = 0;
                for (int c = c0; c < len && n < porRampa; c++)
                    patron[n++] = f_bits[glyph_i((unsigned char)lineas[L][c])][r];
                uvm2_draw_move_abs_q4(VS_Q4(c0 * ADV_SR), VS_Q4(y));
                uvm2_draw_barrido_sr(VS_Q4((c0 + n) * ADV_SR) - VS_Q4(c0 * ADV_SR), 0,
                                     patron, n, PASO);
                n_sr_pedidos += n;
                n_rampas++;
            }
        }
        n_glifos += len;
    }
}

int main(int argc, char **argv)
{
    int raster = 0, sr = 0;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--raster")) raster = 1;
        else if (!strcmp(argv[i], "--sdkfont")) sr = 2;
        else if (!strcmp(argv[i], "--dump")) g_dump = 1;
        else if (!strcmp(argv[i], "--sr")) sr = 1;
        else if (!strncmp(argv[i], "--unit=", 7)) UNIT = atoi(argv[i] + 7);
        else if (!strncmp(argv[i], "--paso=", 7)) PASO = atoi(argv[i] + 7);
        else if (!strncmp(argv[i], "--adv=", 6)) ADV_SR = atoi(argv[i] + 6);
    }
    while (n_lineas < MAXL && fgets(lineas[n_lineas], sizeof lineas[0], stdin)) {
        char *p = strchr(lineas[n_lineas], '\n');
        if (p) *p = 0;
        if (lineas[n_lineas][0]) n_lineas++;
    }
    uvm2_draw_init();
    uvm2_frame_begin();
    uvm2_draw_intensity(127);
    if (sr == 2) dibuja_sdkfont(); else if (sr) dibuja_sr();
    else if (raster) dibuja_raster(); else dibuja_vector();
    uvm2_frame_end();

    printf("%-8s  %d lineas, %ld caracteres, UNIT=%d\n",
           sr == 2 ? "SDKFONT" : sr ? "SR" : raster ? "RASTER" : "TRAZOS",
           n_lineas, n_glifos, UNIT);
    printf("  COMANDOS            %u\n", g_cmds);
    printf("  palabras de bus     %u\n", g_palabras);
    printf("  ciclos de bus       %u   (%.2f ms)\n", g_ciclos, g_ciclos * 667.0 / 1e6);
    printf("  descartados         %u\n", uvm2_stats.dropped);
    if (sr) {
        printf("  rampas de barrido   %ld  (%.2f por caracter)\n",
               n_rampas, (double)n_rampas / (double)n_glifos);
        printf("  escrituras al SR    %u de %ld pedidas%s\n", g_reg_cmds[0xA],
               n_sr_pedidos + n_rampas,
               g_reg_cmds[0xA] >= (uint32_t)(n_sr_pedidos + n_rampas)
                   ? "" : "   <-- TRUNCADO: la rampa acaba antes, el texto saldria cortado");
    }
    else if (raster) printf("  rampas de barrido   %ld  (%.2f por caracter)\n",
                       n_rampas, (double)n_rampas / (double)n_glifos);
    else        printf("  trazos              %ld  (%.2f por caracter)\n",
                       n_trazos, (double)n_trazos / (double)n_glifos);
    printf("  COMANDOS POR CARACTER %.2f\n", (double)g_cmds / (double)n_glifos);
    printf("  reparto: ");
    for (int r = 0; r < 16; r++) if (g_reg_cmds[r])
        printf("%s=%u ", reg_nom((uint32_t)r), g_reg_cmds[r]);
    printf("\n");
    return 0;
}
