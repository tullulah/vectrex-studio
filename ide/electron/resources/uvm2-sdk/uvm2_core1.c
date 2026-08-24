/* uvm2_core1.c — the second core, replaying frames while the game thinks.
 *
 * This is Ralf's split, which his CrazyStones has used from the start:
 *
 *     core 0   builds a command list into one of two buffers, publishes it
 *     core 1   replays it over the bus, reads the controls, ticks the audio
 *
 * WHAT IT BUYS, AND WHAT IT DOES NOT
 *
 * It does NOT make drawing faster. The replay is paced by the Vectrex's own
 * 1.5 MHz clock — 30000 bus cycles is a 50 Hz frame by definition — and no
 * amount of CPU makes a bus cycle shorter. dkong's stream measured 69718 cycles
 * (46.5 ms), and that number is untouched by this file.
 *
 * What it buys is the overlap. Single-core, a frame is
 *
 *     [ emulate the Z80 ][ build the list ][ replay 46.5 ms ][ pace ]
 *
 * strictly in series, so the game's own time is added on top of the beam's.
 * Split, the emulation for frame n+1 runs while the beam is still drawing frame
 * n, and the frame costs max(logic, replay) instead of their sum.
 *
 * WHO OWNS THE BUS
 *
 * Core 1, exclusively, from the moment it starts. That is the whole discipline
 * here and it is not negotiable: two cores driving the same GPIO would put two
 * writers on the VIA with no arbitration, which is the same fault we shipped on
 * the cartridge when 40 games claimed dual-core while compiled single.
 *
 * It works out cleanly because every bus contact on this target was already
 * funnelled into SYS_WAIT_RECAL: the replay, the button/axis reads and the audio
 * tick. Those move here wholesale. The game keeps reading buttons and axes
 * through the syscalls, which have always answered from a cache rather than from
 * the wire, so nothing on the game side changes.
 *
 * The two exceptions are the syscalls that write the bus at an arbitrary moment:
 * SYS_PSG_WRITE goes through a small queue drained here at the frame boundary,
 * and the raw SYS_BUS_READ/WRITE pair is refused (see uvm2_svc.c) because it has
 * no meaning while another core owns the pins.
 */

#include "uvm2_bus.h"

extern uint32_t uvm2_firma_escrita[2], uvm2_firma_n[2];

/* Desacuerdos entre lo que core 0 escribio y lo que core 1 lee del MISMO buffer. Si esto
 * no sube, la coherencia entre nucleos queda descartada y el fallo es de tiempo. */
uint32_t uvm2_firma_fallos, uvm2_firma_comparadas, uvm2_firma_leida, uvm2_firma_ultima_ok;
#include "uvm2_draw.h"
#include "uvm2_input.h"
#include "uvm2_audio.h"

#ifdef UVM2_DUAL_CORE

#include "pico/multicore.h"
#include "pico/time.h"

/* Published by uvm2_draw.c. `request` counts frames core 0 has finished
 * building, `done` frames core 1 has finished replaying; the buffer for frame n
 * is n & 1. Both are plain counters that only ever increase, so a torn read is
 * impossible on a 32-bit load and no lock is needed — the ordering is carried by
 * the barrier core 0 issues before publishing. */
extern volatile uint32_t uvm2_frame_request;
extern volatile uint32_t uvm2_frame_done;
extern const uint8_t    *uvm2_frame_buffer(uint32_t frame);
extern uint32_t          uvm2_frame_length(uint32_t frame);

/* PSG writes the game issued mid-frame, drained between frames.
 *
 * A ring rather than a flag per register: a game that writes the same register
 * twice in a frame means both writes, and .vmus playback does exactly that on
 * the volume registers. Single producer (core 0), single consumer (core 1), so
 * head and tail need no lock. Overflow drops the OLDEST rather than the newest,
 * because for a PSG the newest write is the current state and the one that must
 * survive. */
#define PSG_QUEUE_LEN 64u
static volatile uint32_t s_psg_reg[PSG_QUEUE_LEN];
static volatile uint32_t s_psg_val[PSG_QUEUE_LEN];
static volatile uint32_t s_psg_head;      /* written by core 0 */
static volatile uint32_t s_psg_tail;      /* written by core 1 */

void uvm2_psg_queue(uint32_t reg, uint32_t value)
{
    uint32_t h = s_psg_head;
    s_psg_reg[h % PSG_QUEUE_LEN] = reg;
    s_psg_val[h % PSG_QUEUE_LEN] = value;
    __asm volatile ("dmb" ::: "memory");  /* the data before the index */
    s_psg_head = h + 1;
}

static void psg_drain(void)
{
    uint32_t h = s_psg_head;
    uint32_t t = s_psg_tail;

    /* If the producer ran away, skip forward and keep only the newest entries
     * the ring still holds — the older ones have already been overwritten. */
    if (h - t > PSG_QUEUE_LEN) t = h - PSG_QUEUE_LEN;

    __asm volatile ("dmb" ::: "memory");
    while (t != h) {
        uvm2_psg_write(s_psg_reg[t % PSG_QUEUE_LEN], s_psg_val[t % PSG_QUEUE_LEN]);
        t++;
    }
    s_psg_tail = t;
}

/* Cached controls, served to the game by SYS_READ_BUTTONS / SYS_READ_AXES.
 * Defined here in dual-core builds because this is the core that fills them. */
volatile uint8_t  uvm2_cached_buttons;
volatile uint32_t uvm2_cached_axes;

/* Tiempo Vectrex no entregado aun al secuenciador, en ciclos de bus. */
static uint32_t s_audio_acc;

static void core1_main(void)
{
    uint32_t served = 0;

    for (;;) {
        /* CRONOMETRADO DE VERDAD, en microsegundos. Se llego aqui tras dos rondas
         * adivinando de donde salian ~17 ms por frame que no eran el haz: se
         * culpo al audio y se midio que no. Un reloj cuesta menos que una
         * hipotesis. */
        uint32_t t_w0 = time_us_32();
        while (uvm2_frame_request == served) { }   /* nothing published yet */
        uint32_t t0 = time_us_32();
        uvm2_stats.us_wait = t0 - t_w0;
        served++;
        __asm volatile ("dmb" ::: "memory");       /* the buffer before the count */

#ifdef UVM2_CMDS_STAGE_SRAM
        /* CONTROL: la lista vive en la PSRAM pero se REPRODUCE desde SRAM.
         *
         * La hipotesis que prueba: un fallo de la cache del XIP (16 KB) contra la PSRAM
         * tarda mas que un periodo E, asi que la escritura pierde su fase — y la regla del
         * bus 6800 es de FASE, no de tiempo de establecimiento: no degrada, falla. De ahi
         * garabatos mezclados con vectores buenos en vez de un dibujo borroso.
         *
         * Copiar entero antes de empezar quita TODOS los fallos de la ventana con el haz
         * encendido. Si con esto se limpia, la causa es la busqueda y el arreglo de verdad
         * es traerla por DMA a un anillo pequeño mientras se dibuja. Si NO se limpia, el
         * dato esta mal y la busqueda no tenia nada que ver.
         *
         * Es un CONTROL, no la solucion: gasta en SRAM lo mismo que se queria ahorrar. */
        static uint8_t s_stage[UVM2_CMD_CAPACITY * 3u];
        const uint8_t  *origen = uvm2_frame_buffer(served);
        const uint32_t  n      = uvm2_frame_length(served);
        for (uint32_t i = 0; i < n * 3u && i < UVM2_CMD_CAPACITY * 3u; i++) s_stage[i] = origen[i];
        uint32_t cycles = uvm2_exec(s_stage, n);
#else
        {   /* La otra mitad de la firma: lo que core 1 va a reproducir DE VERDAD. */
            const uint8_t *b = uvm2_frame_buffer(served);
            uint32_t n = uvm2_frame_length(served), h = 2166136261u;
            for (uint32_t i = 0; i < n * 3u; i++) { h ^= b[i]; h *= 16777619u; }
            uvm2_firma_leida = h;
            if (n == uvm2_firma_n[served & 1u]) {
                uvm2_firma_comparadas++;
                if (h != uvm2_firma_escrita[served & 1u]) uvm2_firma_fallos++;
                else                                     uvm2_firma_ultima_ok = h;
            }
        }
        uint32_t cycles = uvm2_exec(uvm2_frame_buffer(served),
                                    uvm2_frame_length(served));
#endif
        uint32_t t1 = time_us_32();
        uvm2_stats.us_exec = t1 - t0;

        /* Between frames, with the beam clamped at centre by the last command of
         * the stream — the only window in which anything else may drive Port A
         * or Port B. Same window the single-core path used, same order. */
        uvm2_single_cycles = 0;
#ifndef UVM2_NO_INPUT
        uvm2_cached_buttons = uvm2_read_buttons();
        uvm2_cached_axes    = uvm2_read_axes();
#endif
        uint32_t t2 = time_us_32();
        uvm2_stats.us_input = t2 - t1;
        psg_drain();
#ifndef UVM2_NO_AUDIO
        /* Avanzar el secuenciador por TIEMPO VECTREX TRANSCURRIDO, no una vez por
         * frame. Es lo que hace el camino monocore, y por una razon medida: un
         * frame que revienta el presupuesto de 50 Hz vale dos frames de musica, y
         * dkong gasta 59.000 ciclos sobre 30.000. Un tick por frame toca la pista
         * a media velocidad.
         *
         * Esto NO es un diagnostico de "la musica no suena en dual core", que
         * sigue abierto: es que los dos caminos tenian semanticas distintas para
         * lo mismo, y eso hay que igualarlo antes de comparar nada. */
        s_audio_acc += cycles;
        while (s_audio_acc >= UVM2_AUDIO_CYCLES) {
            s_audio_acc -= UVM2_AUDIO_CYCLES;
            uvm2_audio_tick();
        }
#endif
        /* Counted, not assumed: an axis conversion costs as many bus cycles as
         * its SAR needed, and the PSG queue's depth varies with the music. */
        cycles += uvm2_single_cycles;
        /* Redraw state that the input read and the PSG writes just clobbered:
         * one CD4052 serves the pots and the beam on shared select lines, so a
         * joystick conversion lands in the beam's own sample-and-holds. */
        uvm2_draw_invalidate();

        /* EL ENGANCHE, EN TIEMPO DE EJECUCION. AQUI ES DONDE MANDA de verdad: con doble
         * nucleo, uvm2_frame_end retorna antes de llegar a su propio pacer, asi que el que
         * cuenta es este. (Lo descubri porque el simbolo del knob ni siquiera llegaba al
         * ELF: nadie referenciaba el otro.)
         *
         * `cycles` SIEMPRE en bus_cycles, pase lo que pase. Antes, en la rama con enganche,
         * se hacia `bus_cycles = UVM2_CYCLES_PER_FRAME`: el contador se PISABA con el
         * presupuesto y marcaba 30000 aunque el dibujo costara la mitad o el doble. Por eso
         * no se movia al barrer VCAP, y por eso publique un "CABE" que era falso.
         *
         * 0 = libre (Asteroids redibujaba en cuanto acababa su lista). != 0 = periodo fijo
         * en ciclos de bus; 30000 = 50 Hz. */
        uvm2_stats.bus_cycles = cycles;
        if (uvm2_pacer_cycles != 0) {
            if (cycles < uvm2_pacer_cycles) uvm2_bus_delay(uvm2_pacer_cycles - cycles);
            else                            uvm2_stats.overrun++;
        }

        uvm2_stats.us_rest = time_us_32() - t2;
        __asm volatile ("dmb" ::: "memory");       /* the work before the flag */
        uvm2_frame_done = served;
    }
}

void uvm2_core1_start(void)
{
    /* RESETEAR ANTES DE LANZAR, y esto es lo que hace posible cargar por SWD.
     *
     * `multicore_launch_core1` da por hecho que el nucleo 1 esta parado. En un arranque
     * frio lo esta; cargando una imagen nueva por SWD encima de otra que ya corre, NO — el
     * nucleo 1 sigue en el bucle de la imagen ANTERIOR, el saludo por la FIFO no llega
     * nunca y la imagen nueva se queda colgada ahi. Localizado el 2026-08-24 con
     * tools/sonda.sh: pc en multicore_fifo_rvalid, lr en multicore_launch_core1_raw. El
     * sintoma es "no dibuja", o sea indistinguible de un fallo del programa.
     *
     * Intente resolverlo desde fuera apagando el nucleo por el PSM y colgue la consola
     * entera. Desde dentro es una linea, la pone el propio pico-sdk y en arranque frio no
     * hace nada. Con esto, tools/cargar.sh sirve tambien para imagenes de doble nucleo y el
     * ciclo de prueba pasa de un minuto (sacar la SD, copiar, menu) a unos segundos. */
    multicore_reset_core1();
    multicore_launch_core1(core1_main);
}

#endif /* UVM2_DUAL_CORE */
