/* CUANTOS COMANDOS PIDE UN FRAME DE VERDAD, Y EN QUE SE VAN.
 *
 * UVM2_CMD_CAPACITY se venia eligiendo por analogia ("a Star Wars le valio 12288"), y un
 * tope que se pasa NO se ve como un error: se ve como un dibujo incompleto. Esto lo
 * contesta antes de construir nada — enlaza el emisor REAL (uvm2_draw.c) contra un bus
 * simulado y le pasa la geometria que el arnes del juego volco de un frame concreto.
 *
 * Y contesta las tres mitades:
 *   - cuantos COMANDOS (el tope, UVM2_CMD_CAPACITY),
 *   - cuantas PALABRAS de bus (LISTA_MAX del stream: una por comando, DOS si lleva
 *     retardo — ver uvm2_exec en uvm2_bus.c),
 *   - cuantos CICLOS de bus (el tiempo del frame, que fija los fps y no depende de
 *     ningun ajuste: 667 ns por ciclo).
 *
 * EL DESGLOSE ES LO QUE EXPLICA LAS DIFERENCIAS ENTRE JUEGOS. "Comandos por segmento" no
 * es una constante del SDK: sale de la GEOMETRIA. Un trazo largo se trocea en mas peldaños
 * de rampa, un trazo que no empieza donde acabo el anterior paga un salto entero, y un
 * cambio de brillo paga su escritura. Por eso conviene mirar el reparto por registro de la
 * VIA y las estadisticas de geometria juntos, no el promedio solo.
 *
 *   cd <juego> && make host && ./build_wasm/<juego>_host 60 2>/tmp/frame.txt
 *   (cd <vectrex-draw>/cabi && cargo build --release)      # la .a para el host
 *   cc -O2 -DUVM2_HOST -DUVM2_BANCO_SIN_NUCLEO1 -DUVM2_SUBUNIDAD -DUVM2_CMD_CAPACITY=65536u \
 *      -I<sdk> -o /tmp/cuenta tools/uvm2_cuenta_lista.c <sdk>/uvm2_draw.c \
 *      <vectrex-draw>/cabi/target/release/libvectrex_draw_cabi.a
 *   /tmp/cuenta /tmp/frame.txt
 *
 * El tope se pone GRANDE al compilar esto (65536): lo que se quiere saber es cuanto pide
 * el frame, no si cabe en el tope que ya teniamos.
 *
 * La entrada son lineas "x0 y0 x1 y1 z" en las unidades que el juego le pasa a
 * v_directDraw32 (el arnes de host de cada puerto ya las vuelca en ese formato).
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include "uvm2_bus.h"
#include "uvm2_draw.h"

uvm2_stats_t uvm2_stats;

static uint32_t g_cmds, g_ciclos, g_palabras;
static uint32_t g_reg_cmds[16], g_reg_ciclos[16];
static uint32_t g_sr_total, g_sr_cero, g_sr_repe, g_sr_prev;

/* Un comando son 3 bytes: retardo 12, registro 4, dato 8 (ver tools/uvm2_anatomia.c), y
 * el ejecutor gasta 1 + retardo ciclos de bus en cada uno. */
uint32_t uvm2_exec(const uint8_t *c, uint32_t n)
{
    g_cmds = n; g_ciclos = 0; g_palabras = 0;
    for (uint32_t i = 0; i < 16; i++) { g_reg_cmds[i] = 0; g_reg_ciclos[i] = 0; }
    for (uint32_t i = 0; i < n; i++) {
        uint32_t v = (uint32_t)c[i*3] | ((uint32_t)c[i*3+1] << 8) | ((uint32_t)c[i*3+2] << 16);
        uint32_t reg = (v >> 8) & 0xF, d = UVM2_CMD_RETARDO(v);
        g_ciclos    += 1 + d;
        g_palabras  += d ? 2u : 1u;
        g_reg_cmds[reg]++;
        g_reg_ciclos[reg] += 1 + d;
        /* EL SR NO ES "CAMBIO DE BRILLO". Un juego que nunca cambia la intensidad escribe
         * el SR cientos de veces por frame, y conviene saber QUE escribe: si alterna entre
         * cero y un valor, son apagados y encendidos del haz alrededor de cada salto, no
         * brillo — y entonces "no escribir si no cambia" no aplica. */
        if (reg == UVM2_VIA_SR) {
            uint32_t dato = v & 0xFFu;
            g_sr_total++;
            if (dato == 0) g_sr_cero++;
            if (g_sr_total > 1 && dato == g_sr_prev) g_sr_repe++;
            g_sr_prev = dato;
        }
    }
    return g_ciclos;
}
void     uvm2_bus_delay(uint32_t c) { (void)c; }
void     uvm2_via_write(uint32_t r, uint32_t d) { (void)r; (void)d; }
uint8_t  uvm2_via_read(uint32_t r) { (void)r; return 0; }

/* Los vecinos del SDK que uvm2_draw.c llama y que aqui no pintan nada. */
void uvm2_config_cargar(void) {}
volatile int uvm2_hay_calibracion = 0;
unsigned uvm2_smp_s_active = 0;   /* uvm2_smp_active() es inline en uvm2_smp.h */
int  uvm2_smp_due(uint32_t c, uint8_t *v) { (void)c; (void)v; return 0; }
uint8_t uvm2_smp_mixer(void) { return 0; }
int  uvm2_smp_needs_latch(void) { return 0; }
void uvm2_smp_frame(uint32_t c) { (void)c; }
uint32_t uvm2_smp_injected = 0;
void rust_eh_personality(void) {}

/* La misma aritmetica que sdk_rp2350.c. OJO: 127, no 100 — son las unidades logicas de
 * VPy (pantalla +-127). Con 100 las rampas salen 1,27x mas largas y todo lo que se cuente
 * aqui es de otro juego. */
#ifndef VPY_SCALE
#define VPY_SCALE 127
#endif
#define VS_Q4(v) ((int)(((v) < 0 ? (long)(v) * 16 - VPY_SCALE / 2 \
                                 : (long)(v) * 16 + VPY_SCALE / 2) / VPY_SCALE))

static const char *nombre(uint32_t reg)
{
    switch (reg) {
    case UVM2_VIA_PORTA: return "PORT_A  DAC: velocidad X o Y";
    case UVM2_VIA_PORTB: return "PORT_B  mux / muestreo de Y";
    case UVM2_VIA_T1CL:  return "T1CL    escala de la rampa";
    case UVM2_VIA_T1CH:  return "T1CH    ARRANCA la rampa";
    case UVM2_VIA_T1LL:  return "T1LL    ESPERA a que acabe";
    case UVM2_VIA_PCR:   return "CNTL    enciende/apaga el haz";
    case UVM2_VIA_SR:    return "SR      brillo (shift register)";
    case UVM2_VIA_ACR:   return "ACR";
    case UVM2_VIA_DDRA:  return "DDRA";
    case UVM2_VIA_DDRB:  return "DDRB";
    default:             return "otro";
    }
}

#define MAXSEG 200000
static int sx0[MAXSEG], sy0[MAXSEG], sx1[MAXSEG], sy1[MAXSEG], sz[MAXSEG];

static int cmp_d(const void *a, const void *b)
{ double x = *(const double *)a, y = *(const double *)b; return x < y ? -1 : x > y; }

int main(int argc, char **argv)
{
    FILE *f = argc > 1 ? fopen(argv[1], "r") : stdin;
    if (!f) { fprintf(stderr, "no puedo abrir %s\n", argv[1]); return 1; }

    /* EN QUE UNIDADES VIENE EL VOLCADO, QUE NO ES LA MISMA EN TODOS LOS ARNESES.
     *
     * Los puertos AAE pasan por `aae-src/vector.h`, y alli el arnes de host se compila con
     * -DNO_PI, que pone AAE_SCREEN_MUL = 1: el volcado sale en las unidades DEL JUEGO,
     * mientras que en el destino real la misma funcion multiplica por 36 y desplaza el
     * centro medido a cero. Darle al emisor las unidades del juego es medir rampas 36
     * veces mas cortas — y el numero que sale de ahi no es de este juego ni de ninguno.
     * Un juego que no pasa por vector.h (dkong) ya vuelca en unidades de destino.
     *
     *   MUL=36 OX=-13356 OY=-13968 ./cuenta frame.txt      # puertos AAE
     *   ./cuenta frame.txt                                 # identidad (dkong, VPy)
     */
    const long mul = getenv("MUL") ? atol(getenv("MUL")) : 1;
    const long ox  = getenv("OX")  ? atol(getenv("OX"))  : 0;
    const long oy  = getenv("OY")  ? atol(getenv("OY"))  : 0;

    long n = 0;
    while (n < MAXSEG &&
           fscanf(f, "%d %d %d %d %d", &sx0[n], &sy0[n], &sx1[n], &sy1[n], &sz[n]) == 5) {
        if (!sz[n]) continue;
        sx0[n] = (int)(sx0[n] * mul + ox); sy0[n] = (int)(sy0[n] * mul + oy);
        sx1[n] = (int)(sx1[n] * mul + ox); sy1[n] = (int)(sy1[n] * mul + oy);
        n++;
    }
    if (!n) { fprintf(stderr, "sin segmentos en la entrada\n"); return 1; }

    /* ── REORDENAR PARA ENCADENAR (REORDENA=1) ────────────────────────────────────
     *
     * NO cambia el dibujo: cada trazo lleva sus dos extremos absolutos, asi que
     * reordenarlos pinta exactamente los mismos segmentos. Lo que cambia es cuantos
     * SALTOS hacen falta entre ellos, y un salto es una rampa entera — ~6 comandos en el
     * bus MAS una resolucion de rampa completa en el constructor. En esb son 709 saltos
     * para 1136 trazos (62%); dkong, que dibuja cadenas de .vec, salta el 30%.
     *
     * Esto es una MEDIDA, no una propuesta de implementacion: dice cuanto habria que
     * ganar antes de decidir si merece la pena resucitar un reordenado en el SDK (se
     * retiro con los demas knobs enteros, aunque el reordenado es el unico de esa familia
     * que no puede mover geometria). Vecino mas cercano voraz, que es el suelo de lo que
     * daria uno bueno. */
    if (getenv("REORDENA")) {
        /* PRIMERO ENCADENAR, LUEGO ORDENAR LAS CADENAS. El vecino mas cercano a secas
         * EMPEORA (medido en esb: 709 -> 882 saltos) porque se come segmentos que eran la
         * continuacion de otra cadena. Asi que se arman primero las polilineas siguiendo
         * las coincidencias exactas de extremo, y solo despues se ordenan ESAS.
         *
         * Y de aqui sale el resultado que importa: el NUMERO de saltos no lo decide el
         * orden, lo decide cuantas polilineas disjuntas dibuja el juego. Reordenar solo
         * puede ACORTARLOS. */
        char *usado = calloc((size_t)n, 1);
        long *sig = malloc(sizeof(long) * (size_t)n);
        for (long i = 0; i < n; i++) sig[i] = -1;
        /* enlazar: para cada trazo, uno cuyo inicio == su final y que no tenga ya padre */
        char *tiene_padre = calloc((size_t)n, 1);
        for (long i = 0; i < n; i++) {
            if (sig[i] >= 0) continue;
            for (long j = 0; j < n; j++) {
                if (j == i || tiene_padre[j]) continue;
                if (sx0[j] == sx1[i] && sy0[j] == sy1[i]) { sig[i] = j; tiene_padre[j] = 1; break; }
            }
        }
        long *ord = malloc(sizeof(long) * (size_t)n); long k = 0;
        int px = 0, py = 0;
        long cadenas = 0;
        for (;;) {
            long mejor = -1; long long mejord = -1;
            for (long i = 0; i < n; i++) {
                if (usado[i] || tiene_padre[i]) continue;      /* solo cabezas de cadena */
                long long dx = sx0[i] - px, dy = sy0[i] - py;
                long long d = dx*dx + dy*dy;
                if (mejor < 0 || d < mejord) { mejor = i; mejord = d; }
            }
            if (mejor < 0) break;
            cadenas++;
            for (long i = mejor; i >= 0 && !usado[i]; i = sig[i]) {
                usado[i] = 1; ord[k++] = i; px = sx1[i]; py = sy1[i];
            }
        }
        for (long i = 0; i < n; i++) if (!usado[i]) ord[k++] = i;   /* por si acaso */
        int *a=malloc(sizeof(int)*(size_t)n),*b=malloc(sizeof(int)*(size_t)n),
            *c=malloc(sizeof(int)*(size_t)n),*d=malloc(sizeof(int)*(size_t)n),
            *e=malloc(sizeof(int)*(size_t)n);
        for (long q=0;q<n;q++){ long i=ord[q]; a[q]=sx0[i]; b[q]=sy0[i]; c[q]=sx1[i]; d[q]=sy1[i]; e[q]=sz[i]; }
        for (long q=0;q<n;q++){ sx0[q]=a[q]; sy0[q]=b[q]; sx1[q]=c[q]; sy1[q]=d[q]; sz[q]=e[q]; }
        free(usado); free(sig); free(tiene_padre); free(ord);
        free(a); free(b); free(c); free(d); free(e);
        printf("  [REORDENADO: %ld polilineas encadenadas, ordenadas por vecino mas cercano]\n", cadenas);
    }

    uvm2_draw_init();
    /* CERO_CADA=N: la red de seguridad por CUENTA de rampas, que viene apagada. Se pone
     * DESPUES de uvm2_draw_init porque ese la reinicia a su valor de compilacion. */
    { const char *e = getenv("CERO_CADA");
      if (e) { extern volatile int32_t uvm2_cero_cada; uvm2_cero_cada = atoi(e); } }
    uvm2_frame_begin();
    for (long i = 0; i < n; i++) {
        uvm2_draw_intensity(sz[i]);
        uvm2_draw_move_abs_q4(VS_Q4(sx0[i]), VS_Q4(sy0[i]));
        uvm2_draw_delta_q4(VS_Q4(sx1[i]) - VS_Q4(sx0[i]), VS_Q4(sy1[i]) - VS_Q4(sy0[i]));
    }
    uvm2_frame_end();

    printf("%s   (MUL=%ld OX=%ld OY=%ld, VPY_SCALE=%d)\n",
           argc > 1 ? argv[1] : "(stdin)", mul, ox, oy, VPY_SCALE);
    printf("  segmentos            %ld\n", n);
    printf("  COMANDOS             %u      -> UVM2_CMD_CAPACITY\n", g_cmds);
    printf("  palabras de bus      %u      -> LISTA_MAX (solo un nucleo)\n", g_palabras);
    printf("  ciclos de bus        %u      -> %.1f ms  (%.1f fps)\n",
           g_ciclos, g_ciclos * 667.0 / 1e6, g_ciclos ? 1e9 / (g_ciclos * 667.0) : 0.0);
    printf("  descartados          %u\n", uvm2_stats.dropped);
    printf("  COMANDOS POR SEGMENTO %.2f\n", (double)g_cmds / (double)n);

    printf("\n  en que se van los comandos (por registro de la VIA):\n");
    printf("    %-32s %8s %8s %8s\n", "registro", "cmds", "%", "ciclos");
    for (int r = 0; r < 16; r++) {
        if (!g_reg_cmds[r]) continue;
        printf("    %-32s %8u %7.1f%% %8u\n", nombre((uint32_t)r), g_reg_cmds[r],
               100.0 * g_reg_cmds[r] / g_cmds, g_reg_ciclos[r]);
    }

    /* ── LA GEOMETRIA, que es lo que de verdad explica el numero ───────────────
     *
     * "Comandos por segmento" no lo fija el SDK: lo fija lo que el juego dibuja.
     *   encadenados  un trazo que empieza donde acabo el anterior NO paga salto.
     *   largo        una rampa larga se trocea en mas peldaños (la escalera de t1).
     *   brillo       un cambio de intensidad es una escritura mas por trazo. */
    long encadenados = 0, cambia_z = 0;
    double *largos = malloc(sizeof(double) * (size_t)n);
    double *saltos = malloc(sizeof(double) * (size_t)n);
    long nsaltos = 0;
    double suma_l = 0;
    for (long i = 0; i < n; i++) {
        double dx = sx1[i] - sx0[i], dy = sy1[i] - sy0[i];
        largos[i] = sqrt(dx * dx + dy * dy);
        suma_l += largos[i];
        if (i) {
            if (sx0[i] == sx1[i-1] && sy0[i] == sy1[i-1]) encadenados++;
            else {
                double jx = sx0[i] - sx1[i-1], jy = sy0[i] - sy1[i-1];
                saltos[nsaltos++] = sqrt(jx * jx + jy * jy);
            }
            if (sz[i] != sz[i-1]) cambia_z++;
        }
    }
    qsort(largos, (size_t)n, sizeof(double), cmp_d);
    if (nsaltos) qsort(saltos, (size_t)nsaltos, sizeof(double), cmp_d);

    if (g_sr_total)
        printf("\n  el SR (brillo): %u escrituras — %u a CERO (%.0f%% apagados del haz),"
               " %u repetidas del mismo valor\n",
               g_sr_total, g_sr_cero, 100.0*g_sr_cero/g_sr_total, g_sr_repe);
    printf("\n  la geometria, que es lo que explica el numero:\n");
    printf("    largo del trazo      mediana %.1f   p90 %.1f   max %.1f   medio %.1f\n",
           largos[n/2], largos[(n*9)/10], largos[n-1], suma_l / (double)n);
    printf("    encadenados          %ld de %ld (%.1f%%)  <- no pagan salto\n",
           encadenados, n, 100.0 * encadenados / (double)n);
    printf("    saltos               %ld", nsaltos);
    if (nsaltos) printf("   mediana %.1f   p90 %.1f   max %.1f",
                        saltos[nsaltos/2], saltos[(nsaltos*9)/10], saltos[nsaltos-1]);
    printf("\n");
    /* ── CADA CUANTO SE RE-CENTRA EL HAZ ────────────────────────────────────────────
     *
     * `uvm2_cero_salto` (24 unidades de dispositivo por defecto) fuerza un re-cero cuando
     * el transporte es largo, y `uvm2_cero_cada` —la red por CUENTA— viene APAGADA. En una
     * escena de trazos cortos encadenados eso deja tiradas enormes sin re-centrar, y la
     * deriva se ve como vectores que saltan. Aqui se cuenta.
     *
     * El umbral esta en unidades de dispositivo; la entrada, en las del juego. La
     * conversion es la del SDK: dispositivo = juego * MUL * 16 / VPY_SCALE / 16. */
    {
        /* Las coordenadas de estos arrays YA llevan el MUL aplicado. VS_Q4 divide por
         * VPY_SCALE y multiplica por 16, y la unidad de dispositivo es q4>>4 — o sea que
         * una unidad de dispositivo son VPY_SCALE de estas. El umbral son 24. */
        const long umbral_juego = 24L * VPY_SCALE;
        long fuerzan = 0, racha = 0, peor = 0;
        for (long i = 0; i < n; i++) {
            long j = 0;
            if (i) { double jx = sx0[i]-sx1[i-1], jy = sy0[i]-sy1[i-1];
                     j = (long)(fabs(jx) > fabs(jy) ? fabs(jx) : fabs(jy)); }
            if (j >= umbral_juego) { fuerzan++; if (racha > peor) peor = racha; racha = 0; }
            else racha++;
        }
        if (racha > peor) peor = racha;
        printf("\n  el re-cero del haz (uvm2_cero_salto = 24 unidades de dispositivo):\n");
        printf("    saltos que lo fuerzan  %ld de %ld  (%.1f%%)\n", fuerzan, n, 100.0*fuerzan/n);
        printf("    PEOR TIRADA sin re-centrar  %ld segmentos seguidos\n", peor);
        printf("    (umbral, en las unidades de la entrada: %ld)\n", umbral_juego);
    }
    printf("    cambios de brillo    %ld de %ld (%.1f%%)\n",
           cambia_z, n, 100.0 * cambia_z / (double)n);
    free(largos); free(saltos);
    return 0;
}
