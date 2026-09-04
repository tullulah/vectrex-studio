/* ¿Cuanto ahorra ORDENAR POR PENDIENTE? Replica un frame real a traves del uvm2_draw.c
 * REAL contra un bus simulado, en dos ordenes, y cuenta los comandos.
 *
 * y_can_skip() compara la VELOCIDAD Y de la rampa, no la posicion: cuando dos operaciones
 * consecutivas comparten vy se ahorran tres escrituras Y SUS TRES RETARDOS — 6 comandos de
 * 15. El escenario de dkong son vigas paralelas, peldaños horizontales y largueros
 * verticales, o sea unas pocas pendientes repetidas cientos de veces.
 *
 *   cc -O2 -DUVM2_HOST -I<sdk> -o orden tools/uvm2_orden.c uvm2_draw.c <cabi>.a eh.c
 *   ./orden volcado.txt
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "uvm2_bus.h"
#include "uvm2_draw.h"

uvm2_stats_t uvm2_stats;
static uint32_t g_cmd, g_cyc;
uint32_t uvm2_exec(const uint8_t *c, uint32_t n){ (void)c; g_cmd += n; g_cyc += n; return n; }
void     uvm2_bus_delay(uint32_t c){ g_cyc += c; }
void     uvm2_via_write(uint32_t r, uint32_t d){ (void)r; (void)d; g_cmd++; g_cyc++; }
uint8_t  uvm2_via_read(uint32_t r){ (void)r; return 0; }

#define MAXS 2048
static int sx0[MAXS], sy0[MAXS], sx1[MAXS], sy1[MAXS], sb[MAXS], sk[MAXS], n;

/* la clave: la pendiente en la escala del DAC, que es lo que y_can_skip compara */
static int clave(int i){
    int dx = sx1[i]-sx0[i], dy = sy1[i]-sy0[i];
    int m = (dx<0?-dx:dx) > (dy<0?-dy:dy) ? (dx<0?-dx:dx) : (dy<0?-dy:dy);
    return m ? (dy * 127) / m : 0;
}
static int cmp(const void *a, const void *b){
    int i = *(const int*)a, j = *(const int*)b;
    return sk[i] != sk[j] ? sk[i]-sk[j] : sx0[i]-sx0[j];
}

static void replay(const int *ord, const char *q){
    g_cmd = g_cyc = 0;
    uvm2_draw_init(); uvm2_frame_begin();
    int bx = 0, by = 0, bri = -1, nmov = 0, nvy = 0, vyprev = 0x7fffffff;
    for (int k = 0; k < n; k++){
        int i = ord[k];
        if (!sb[i]) continue;
        if (sb[i] != bri){ uvm2_draw_intensity(sb[i]); bri = sb[i]; }
        if (sx0[i] != bx || sy0[i] != by){ uvm2_draw_move(sx0[i]-bx, sy0[i]-by); nmov++; }
        { int dx=sx1[i]-sx0[i], dy=sy1[i]-sy0[i];
          int mm=(dx<0?-dx:dx)>(dy<0?-dy:dy)?(dx<0?-dx:dx):(dy<0?-dy:dy);
          int vy = mm ? (dy*127)/mm : 0;
          if (vy == vyprev) nvy++; vyprev = vy; }
        uvm2_draw_delta(sx1[i]-sx0[i], sy1[i]-sy0[i]);
        bx = sx1[i]; by = sy1[i];
    }
    uvm2_frame_end();
    printf("  %-24s %5u comandos  %4d saltos  %4d con la misma pendiente\n", q, uvm2_stats.commands, nmov, nvy);
}

/* vecino mas cercano: el que empieza mas cerca de donde acabo el haz, en cualquiera de
 * sus dos extremos. Es lo que hace flush_frame en el SDK del cartucho. */
static void vecino(int *o){
    char *usado = calloc(n,1);
    int bx = 0, by = 0, m = 0;
    for (int k = 0; k < n; k++){
        int mejor = -1; long bd = 0; int rev = 0;
        for (int i = 0; i < n; i++){
            if (usado[i] || !sb[i]) continue;
            long d0 = (long)(sx0[i]-bx)*(sx0[i]-bx) + (long)(sy0[i]-by)*(sy0[i]-by);
            long d1 = (long)(sx1[i]-bx)*(sx1[i]-bx) + (long)(sy1[i]-by)*(sy1[i]-by);
            if (mejor < 0 || d0 < bd){ bd = d0; mejor = i; rev = 0; }
            if (d1 < bd){ bd = d1; mejor = i; rev = 1; }
        }
        if (mejor < 0) break;
        usado[mejor] = 1;
        if (rev){ int t;
            t=sx0[mejor]; sx0[mejor]=sx1[mejor]; sx1[mejor]=t;
            t=sy0[mejor]; sy0[mejor]=sy1[mejor]; sy1[mejor]=t; }
        o[m++] = mejor; bx = sx1[mejor]; by = sy1[mejor];
    }
    while (m < n) o[m++] = 0;
    free(usado);
}

/* CODICIOSO CON PREFERENCIA DE PENDIENTE. El ahorro de 6 comandos lo dispara y_can_skip,
 * que compara la VELOCIDAD Y — o sea la pendiente —, no la posicion. Y un salto cuesta 15,
 * asi que no se puede perseguir la pendiente a costa de moverse. Prioridad:
 *   1. empieza donde acabo el haz Y con la misma pendiente   (9 comandos, sin salto)
 *   2. empieza donde acabo el haz                            (15, sin salto)
 *   3. la misma pendiente, lo mas cerca posible              (15 + salto corto)
 *   4. lo mas cercano                                        (15 + salto)
 */
static void codicioso(int *o){
    char *usado = calloc(n,1);
    int bx = 0, by = 0, bk = 0x7fffffff, m = 0;
    for (int k = 0; k < n; k++){
        int mejor = -1, rev = 0, mejor_rango = 9; long bd = 0;
        for (int i = 0; i < n; i++){
            if (usado[i] || !sb[i]) continue;
            for (int r = 0; r < 2; r++){
                int px = r ? sx1[i] : sx0[i], py = r ? sy1[i] : sy0[i];
                int ky = r ? -sk[i] : sk[i];
                int pegado = (px == bx && py == by);
                int rango = pegado ? (ky == bk ? 0 : 1) : (ky == bk ? 2 : 3);
                long d = (long)(px-bx)*(px-bx) + (long)(py-by)*(py-by);
                if (rango < mejor_rango || (rango == mejor_rango && d < bd)){
                    mejor_rango = rango; bd = d; mejor = i; rev = r;
                }
            }
        }
        if (mejor < 0) break;
        usado[mejor] = 1;
        if (rev){ int t;
            t=sx0[mejor]; sx0[mejor]=sx1[mejor]; sx1[mejor]=t;
            t=sy0[mejor]; sy0[mejor]=sy1[mejor]; sy1[mejor]=t; sk[mejor] = -sk[mejor]; }
        o[m++] = mejor; bx = sx1[mejor]; by = sy1[mejor]; bk = sk[mejor];
    }
    while (m < n) o[m++] = 0;
    free(usado);
}

/* ORDENAR OBJETOS, NO SEGMENTOS. Reordenar segmentos sueltos rompe las cadenas y ANADE
 * saltos (medido: 5307 -> 5838). Lo que hace flush_frame en el SDK es ordenar TRAZOS
 * —cadenas de segmentos contiguos— dejando intacto su interior. Aqui se agrupa primero y
 * se ordena despues, que es la unica forma en que la reordenacion puede ganar. */
static void por_trazos(int *o){
    /* 1. agrupar: un trazo es una cadena de segmentos donde el fin de uno es el principio
     *    del siguiente, en el orden en que el juego los emite. */
    int ini[MAXS], fin[MAXS], nt = 0;
    for (int i = 0; i < n; ){
        if (!sb[i]) { i++; continue; }
        int j = i;
        while (j+1 < n && sb[j+1] && sx1[j] == sx0[j+1] && sy1[j] == sy0[j+1]) j++;
        ini[nt] = i; fin[nt] = j; nt++;
        i = j + 1;
    }
    /* 2. ordenar los trazos por cercania, cada uno en el sentido que empiece mas cerca */
    char *usado = calloc(nt,1);
    int bx = 0, by = 0, m = 0;
    for (int k = 0; k < nt; k++){
        int mejor = -1, rev = 0; long bd = 0;
        for (int t = 0; t < nt; t++){
            if (usado[t]) continue;
            long d0 = (long)(sx0[ini[t]]-bx)*(sx0[ini[t]]-bx) + (long)(sy0[ini[t]]-by)*(sy0[ini[t]]-by);
            long d1 = (long)(sx1[fin[t]]-bx)*(sx1[fin[t]]-bx) + (long)(sy1[fin[t]]-by)*(sy1[fin[t]]-by);
            if (mejor < 0 || d0 < bd){ bd = d0; mejor = t; rev = 0; }
            if (d1 < bd){ bd = d1; mejor = t; rev = 1; }
        }
        if (mejor < 0) break;
        usado[mejor] = 1;
        if (!rev){ for (int i = ini[mejor]; i <= fin[mejor]; i++) o[m++] = i;
                   bx = sx1[fin[mejor]]; by = sy1[fin[mejor]]; }
        else {     for (int i = fin[mejor]; i >= ini[mejor]; i--){
                       int t2;
                       t2=sx0[i]; sx0[i]=sx1[i]; sx1[i]=t2;
                       t2=sy0[i]; sy0[i]=sy1[i]; sy1[i]=t2;
                       o[m++] = i; }
                   bx = sx1[fin[mejor]]; by = sy1[fin[mejor]]; }
    }
    printf("  (%d trazos de %d segmentos)\n", nt, n);
    while (m < n) o[m++] = 0;
    free(usado);
}

int main(int argc, char **argv){
    FILE *f = fopen(argv[1], "r"); if (!f) return 2;
    char l[256];
    while (fgets(l, sizeof l, f) && n < MAXS){
        int a,b,c,d,e;
        if (sscanf(l, "%d %d %d %d %d", &a,&b,&c,&d,&e) == 5){
            sx0[n]=a/127; sy0[n]=b/127; sx1[n]=c/127; sy1[n]=d/127; sb[n]=e; n++;
        }
    }
    fclose(f);
    int *o1 = malloc(n*sizeof(int)), *o2 = malloc(n*sizeof(int));
    for (int i = 0; i < n; i++){ o1[i]=i; sk[i]=clave(i); }
    memcpy(o2, o1, n*sizeof(int));
    qsort(o2, n, sizeof(int), cmp);
    printf("%d segmentos\n", n);
    replay(o1, "orden actual");
    replay(o2, "ordenado por pendiente");
    int *o3 = malloc(n*sizeof(int)); vecino(o3);
    replay(o3, "vecino mas cercano");
    int *o4 = malloc(n*sizeof(int));
    for (int i = 0; i < n; i++) sk[i] = clave(i);
    codicioso(o4);
    replay(o4, "codicioso + pendiente");
    int *o5 = malloc(n*sizeof(int));
    por_trazos(o5);
    replay(o5, "por TRAZOS (objetos)");
    return 0;
}
