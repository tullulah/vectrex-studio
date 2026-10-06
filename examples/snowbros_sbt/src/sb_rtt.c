/* sb_rtt.c — los fps de snowbros por RTT, SIN PARAR EL NUCLEO.
 *
 * POR QUE NO UNA LECTURA POR SWD. En este cartucho el nucleo conduce el bus del
 * Vectrex con la fase de E pegada al reloj. Cualquier sonda que lo DETENGA —GDB o
 * `probe-rs read`— es una violacion de fase, y reanudar despues no devuelve la
 * fase perdida: la consola se queda a oscuras. Pasa a veces, no siempre, que es
 * lo peor que puede hacer un instrumento. Probado el 2026-09-16: dos lecturas con
 * `sonda.sh` (que reanuda explicitamente) y la consola colgada a la tercera.
 *
 * RTT no para nada. El objetivo escribe en un anillo en RAM y el host lo lee por
 * el AHB-AP con el juego corriendo:
 *
 *     probe-rs attach --chip RP235x build_rp2350/snowbros_sbt.elf
 *
 * Copiado del rtt.c de dkong, que lleva meses funcionando. Lo que se ha quitado:
 * el canal de bajada con sus knobs en vivo (dkong barre constantes del haz; aqui
 * solo se quiere un numero) y `uvm2_stats`, que es del objetivo .um2.
 *
 * EL BLOQUE DE CONTROL VA EN SRAM INTERNA A PROPOSITO. El host LOCALIZA el anillo
 * escaneando la RAM en busca de la firma "SEGGER RTT", y el mapa de RAM que
 * conoce para el RP235x es la SRAM interna (0x20000000+). Este juego se enlaza en
 * la PSRAM (0x11000000, ver rp2350_game_ram.ld): un anillo en su .bss no lo
 * encontraria nadie, y el sintoma seria "probe-rs no ve el RTT", que no se
 * distingue de "el juego no arranco". `.sram_rapida` es el hueco que el propio
 * script de enlazado reserva en la SRAM interna para esto (NOLOAD: no viaja en la
 * imagen ni se pone a cero, y no hace falta — rtt_init() escribe cada campo).
 */
#include <stdint.h>

#define SUBIDA 1024

/* Solo el cartucho propio enlaza contra rp2350_game_ram.ld. La .um2 se enlaza por
 * el pico-sdk, que no tiene esa seccion — y alli la imagen entera ya esta en SRAM,
 * asi que el anillo cae donde el host lo busca sin ayuda. */
#ifdef VPY_DUAL_CORE
#define EN_SRAM __attribute__((section(".sram_rapida")))
#else
#define EN_SRAM
#endif

typedef struct {
    const char *nombre; char *buf; unsigned tam;
    volatile unsigned wr;   /* lo escribe el objetivo */
    volatile unsigned rd;   /* lo escribe el HOST     */
    unsigned flags;
} RttCanal;

typedef struct {
    char firma[16];
    int  n_subida, n_bajada;
    RttCanal subida[1], bajada[1];
} RttBloque;

static char buf_sub[SUBIDA] EN_SRAM __attribute__((aligned(4)));
static char buf_baj[4]      EN_SRAM __attribute__((aligned(4)));
RttBloque _SEGGER_RTT       EN_SRAM __attribute__((aligned(4), used));

static void rtt_init(void)
{
    static const char nom[] = "Terminal";
    _SEGGER_RTT.n_subida = 1; _SEGGER_RTT.n_bajada = 1;
    _SEGGER_RTT.subida[0].nombre = nom;  _SEGGER_RTT.subida[0].buf = buf_sub;
    _SEGGER_RTT.subida[0].tam = SUBIDA;  _SEGGER_RTT.subida[0].wr = 0;
    _SEGGER_RTT.subida[0].rd = 0;        _SEGGER_RTT.subida[0].flags = 0; /* 0 = si no cabe, se tira */
    _SEGGER_RTT.bajada[0].nombre = nom;  _SEGGER_RTT.bajada[0].buf = buf_baj;
    _SEGGER_RTT.bajada[0].tam = sizeof buf_baj; _SEGGER_RTT.bajada[0].wr = 0;
    _SEGGER_RTT.bajada[0].rd = 0;        _SEGGER_RTT.bajada[0].flags = 0;
    /* LA FIRMA, LA ULTIMA: el host da por bueno el resto del bloque en cuanto la ve,
     * asi que escribirla primero es ofrecerle punteros a medias. Y se escribe en
     * ARRANQUE, no como literal, para que no aparezca tambien en la imagen en disco
     * y el host no enganche con una copia muerta. */
    __asm__ volatile("" ::: "memory");
    static const char f[] = "SEGGER RTT";
    for (int i = 0; i < 16; i++) _SEGGER_RTT.firma[i] = i < 10 ? f[i] : 0;
}

static void rtt_puts(const char *s)
{
    RttCanal *c = &_SEGGER_RTT.subida[0];
    unsigned w = c->wr;
    while (*s) {
        unsigned n = w + 1; if (n >= c->tam) n = 0;
        if (n == c->rd) break;            /* lleno: se tira, NUNCA se bloquea el dibujo */
        c->buf[w] = *s++; w = n;
    }
    c->wr = w;
}

static void num(unsigned v)
{
    char d[12]; int i = 0;
    if (!v) { rtt_puts("0"); return; }
    while (v && i < 11) { d[i++] = (char)('0' + v % 10); v /= 10; }
    char o[12]; int j = 0;
    while (i) o[j++] = d[--i];
    o[j] = 0; rtt_puts(o);
}
static void campo(const char *n, unsigned v) { rtt_puts(n); num(v); rtt_puts(" "); }

/* TIMELR del TIMER0: microsegundos, y es el mismo reloj con el que mide dkong. Se
 * lee solo la mitad baja: da la vuelta cada 71 minutos y aqui solo se restan
 * diferencias de un frame. */
#define AHORA_US (*(volatile unsigned *)0x400B000Cu)

unsigned sb_vec_last;    /* segmentos encendidos del ultimo frame; lo pone sb_render */

/* EL FRAME PARTIDO EN DOS, que es la pregunta que esto viene a contestar.
 *
 * El juego va a ~60% de su velocidad real porque avanza UN frame de maquina por
 * frame DIBUJADO, y dibujamos a 30-35 en vez de a 57,5. Lo obvio seria ejecutar
 * los frames de maquina que falten, pero eso solo cabe si emular es barato:
 * hacen falta `57,5·emul + fps·lista <= 1000 ms`. Sin separar los dos terminos, un
 * frame de 21 ms no distingue "Musashi es lento" de "construir la lista es lenta",
 * y son arreglos completamente distintos (mover el interprete a la SRAM contra
 * tocar el renderer).
 *
 * gmain llama tres veces por frame:
 *   sb_marca(0)  antes de sb_hw_frame   (emular)
 *   sb_marca(1)  despues, antes de sb_render   (construir la lista)
 *   sb_marca(2)  despues: cierra el frame y, cada VENTANA, emite la linea
 *
 * LOS VECTORES VAN AL LADO DE LOS FPS Y NO ES ADORNO: los fps de estos puertos
 * dependen de cuantos vectores lleva el frame, asi que un fps sin su cuenta de
 * vectores no es comparable con otro. Comparar dos escenas distintas ya produjo
 * una vez un 1,66x que era falso. */
#define VENTANA 25u    /* frames por linea: ~dos lineas por segundo */

void sb_marca(int fase)
{
    static int arrancado;
    static unsigned t_fase, t_prev, acc, n, vec_acc, peor, emul_acc, lista_acc;

    if (!arrancado) { rtt_init(); arrancado = 1; }

    unsigned ahora = AHORA_US;

    if (fase == 0) { t_fase = ahora; return; }
    if (fase == 1) { emul_acc += ahora - t_fase; t_fase = ahora; return; }

    lista_acc += ahora - t_fase;

    if (t_prev) {
        unsigned dt = ahora - t_prev;
        acc += dt; n++;
        if (dt > peor) peor = dt;
        vec_acc += sb_vec_last;
    }
    t_prev = ahora;

    if (n < VENTANA) return;

    /* Todo en DECIMAS: es donde se ve la diferencia entre 49,8 y 50,0 fps, o entre
     * 8,4 y 9,1 ms de emulacion — que es justo el margen que decide si cabe. */
    campo("fps=",   acc ? (n * 10000000u) / acc : 0);
    campo("vec=",   vec_acc / n);
    campo("emul=",  emul_acc / n / 100u);
    campo("lista=", lista_acc / n / 100u);
    campo("pico=",  peor / 100u);
    /* Saltos de espera por frame (src/sb_hw.c). Va al lado de `emul` porque es lo
     * que lo explica: si sale 0, el idle skip no esta disparando en consola y
     * cualquier lectura de `emul` seria sobre el camino viejo. Un mecanismo que no
     * se ve funcionar se lee igual que uno que no hace falta. */
    { extern unsigned sb_idle_cortes; static unsigned prev;
      campo("salt=", (sb_idle_cortes - prev) * 10u / n); prev = sb_idle_cortes; }
    /* FRAMES DE MAQUINA POR FRAME DIBUJADO, que es la medida DIRECTA de la
     * velocidad del juego: `maq` x `fps` tiene que dar 575 (57,5 Hz). Con el
     * catch-up apagado sale siempre 10 y el juego va a fps/57,5 de su velocidad. */
    { extern unsigned sb_maq_frames; static unsigned prev;
      campo("maq=", (sb_maq_frames - prev) * 10u / n); prev = sb_maq_frames; }
    rtt_puts("(decimas: fps, ms, salt y maq por frame)\n");
    acc = n = vec_acc = peor = emul_acc = lista_acc = 0;
}
