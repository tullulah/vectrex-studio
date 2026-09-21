/*
 * uvm2_svc.c — the UVM2 side of the VPy syscall ABI.
 *
 * `svc #N` is the contract every VPy/C/SBT program already speaks: the same
 * table is implemented by our own cartridge firmware (Rust) and by the IDE
 * emulator (Rp2350System.ts).  This is the third implementation, and the only
 * one that drives a real Vectrex through halt mode.  Because the ABI is shared,
 * the generated image for UVM2 is byte-identical to the RP2350 one apart from
 * the handler that lands here — no forked codegen, no duplicated builtins.
 *
 * Drawing syscalls only RECORD into the command stream; SYS_WAIT_RECAL is what
 * replays it, polls input and paces the frame.
 */

#include "uvm2_bus.h"
#include "uvm2_draw.h"
#include "uvm2_input.h"
#include "uvm2_led.h"
#include "uvm2_text.h"
#include "uvm2_audio.h"

/* ── Sonda de la capa de dibujo compartida (paso 1 de la unificacion) ────────
 * Volatiles y NO static: se leen por SWD, y un simbolo que solo se escribe se lo
 * lleva el enlazador — ya nos paso con sf_build_tag en speedfrk. */
volatile uint32_t uvm2_vx_probe;
volatile int32_t  uvm2_vx_probe_div;
#ifdef UVM2_VECTREX_DRAW
uint32_t vx_probe(void);
int32_t  vx_probe_div(int32_t num, int32_t den);
#endif
#include "uvm2_psram.h"

enum {
    SYS_RESET0REF     = 0,
    SYS_WAIT_RECAL    = 1,
    SYS_SET_INTENSITY = 2,
    SYS_MOVE          = 3,
    SYS_DRAW_DELTA    = 4,
    SYS_PSG_WRITE     = 5,
    SYS_PSG_SILENCE   = 6,
    SYS_READ_BUTTONS  = 7,
    SYS_BUS_WRITE     = 8,
    SYS_BUS_READ      = 11,
    SYS_PSG_READ      = 12,
    SYS_READ_AXES     = 13,
    SYS_READ_BTN_RAW  = 14,
    SYS_MOVE_ABS      = 15,
    SYS_PRINT_TEXT    = 16,
    SYS_PLAY_MUSIC    = 21,
    SYS_STOP_MUSIC    = 22,
    SYS_PLAY_SFX      = 23,
    /* Voice 0's cursor as a frame number at `fps`, matching the cartridge BIOS. A game
     * streaming into a ring buffer needs it to know how far the injector has got; asking
     * with fps = the sample's own rate gives the cursor in SAMPLES. It was missing here,
     * so on this target the call returned whatever was in r0 and the refill ran blind. */
    SYS_SAMPLE_POS    = 10,
    SYS_RASTER_TEXT   = 26,   /* (r0:x, r1:y, r2:str, r3:len) — see sdk_rp2350.c */
    SYS_DRAW_GAPPED   = 27,   /* (r0:dx, r1:dy, r2:gaps, r3:n) — one ramp, BLANK toggled inside */
    SYS_MOVE_Q4       = 28,   /* (r0:dx, r1:dy) en 1/16 de unidad: VPy en subunidades */
    SYS_DRAW_DELTA_Q4 = 29,   /* (r0:dx, r1:dy) en 1/16 de unidad, encendido */
};

/* Input is sampled once per frame in SYS_WAIT_RECAL and cached here: the read
 * sequences disturb Port B, so they may only run between frames. */
static uint8_t  s_buttons = 0xFFu;   /* released; active low, see uvm2_core1.c */
static uint32_t s_axes;
/* TIMER0 TIMELR en crudo: microsegundos, y sin arrastrar pico/time.h a un fichero que
 * vive en SRAM. Es el mismo reloj que usa mide_periodo() en uvm2_draw.c. */
static inline uint32_t uvm2_us(void)
{
#ifdef UVM2_HOST
    return 0;
#else
    return *(volatile uint32_t *)0x400B000Cu;
#endif
}
static uint32_t s_us_recal_prev;

/* Where the controls come from.  Single-core, this file reads them itself at the
 * frame boundary; dual-core, core 1 does and leaves them here.  Either way the
 * syscalls have always answered from a cache rather than from the wire, which is
 * why moving the read to the other core is invisible to every game. */
#ifdef UVM2_DUAL_CORE
extern volatile uint8_t  uvm2_cached_buttons;
extern volatile uint32_t uvm2_cached_axes;
void uvm2_psg_queue(uint32_t reg, uint32_t value);
#  define UVM2_BUTTONS  uvm2_cached_buttons
#  define UVM2_AXES     uvm2_cached_axes
#  define UVM2_PSG(r,v) uvm2_psg_queue((r), (v))
#else
#  define UVM2_BUTTONS  s_buttons
#  define UVM2_AXES     s_axes
#  define UVM2_PSG(r,v) uvm2_psg_write((r), (v))
#endif
/* Leftover Vectrex time not yet handed to the sequencer, in bus cycles. */
static uint32_t s_audio_acc;

/* Bring-up sequence, narrated on the status LED because there is no other
 * output channel until the beam itself works.  Each stage latches its colour,
 * so a board that stops early leaves the diagnosis visible on the cartridge:
 *   blue  → the image booted but never saw a Vectrex clock yet
 *   red   → no clock at all: console off, or the cart is not seated
 *   amber → clock found, bus taken, VIA being primed
 *   green → frames are going out
 */
#ifdef UVM2_STEP_OWNS_INIT
/* Declared here rather than pulled in: uvm2_stream_start lives in uvm2_bus_stream.h and
 * uvm2_core1_start has no header at all (uvm2_pico_main.c declares it the same way). */
void uvm2_stream_start(void);
void uvm2_core1_start(void);
#endif

void uvm2_runtime_init(void)
{
    /* First, before anything with state: .bss is still whatever was in SRAM. */
    uvm2_cpu_init();

    /* Then the pads, so CLK can be read, and only then the LED — it needs a
     * calibrated cycle counter, and the Vectrex clock is what calibrates it. */
    uvm2_bus_pads();
    uvm2_led_init();
    uvm2_led_status(UVM2_STATUS_BOOT);

    /* Is the 6809 even clocking?  Everything below blocks on CLK edges, so
     * without this check a switched-off console is indistinguishable from a bug
     * in our own code: black screen, frozen cart, no clue which. */
    if (uvm2_clock_calibrate() == 0) {
        uvm2_led_status(UVM2_STATUS_NO_CLOCK);
        for (;;) { }
    }

    uvm2_led_status(UVM2_STATUS_HALTING);
    uvm2_bus_halt();
    uvm2_draw_init();
    /* `uvm2_draw_set_fixup(1)` ESTABA AQUI y encendia un flag que nadie leia: la
     * funcion existia sin una sola llamada. Retirada con su nota en uvm2_draw.c. */
    /* Analog stick. It was implemented all along (read_axis_analog is the BIOS
     * SAR) but s_analog defaulted to 0 and nobody turned it on, so every game got
     * a -1/0/1 verdict. Asteroids and the rest are analog games on real hardware
     * and the cart reads them that way. */
    uvm2_input_set_analog(1);
    /* Poner el PSG en un estado conocido. NADIE lo hacia: uvm2_stop_music() es
     * la unica funcion que escribe el registro 7, y solo se llama al parar la
     * musica, asi que al arrancar ese registro se quedaba como lo hubiera dejado
     * el 6809 antes de que lo halteramos. El bit 6 del registro 7 es la DIRECCION
     * del puerto A del PSG, y ahi es donde viven los botones: si quedo como
     * salida, leer el registro 14 devuelve el latch en vez de los mandos, y los
     * botones salen pulsados solos. De paso deja los tres volumenes a cero, que
     * es el estado sano para arrancar. */
    uvm2_stop_music();
    /* Sonda de PSRAM, solo si se pide (-DUVM2_PSRAM_PROBE). Va bajo interruptor
     * porque toca el bus QSPI, que es el mismo por el que cuelga la flash del
     * multicart: en un arranque normal no hay ninguna razon para meterse ahi.
     * Resultado en uvm2_psram_result, legible por SWD. */
#ifdef UVM2_PSRAM_PROBE
    /* En este orden, y el orden es la medida. uvm2_psram_probe() lo primero
     * porque lo unico que solo puede leer ELLA es el QMI virgen: en cuanto la
     * otra sonda llama al bootrom, los M1 y DIRECT_CSR ya no dicen "como me
     * encontre" sino "como me dejaron". Y la del bootrom despues porque manda
     * la secuencia de salida de XIP a CS1, que puede sacar al chip de QPI: si
     * fuera al reves, la sonda de siempre encontraria un chip ya despierto y no
     * sabriamos cual de las dos lo consiguio. */
    uvm2_psram_probe();
    /* MEDIDO 2026-08-17: rom_flash_exit_xip() no vuelve en este cartucho, y ya
     * en la llamada de CS0 — antes de tocar CS1. Lo dijo la miga paso_bootrom =
     * 103. Asi que este camino queda detras de su propio interruptor: una sonda
     * que cuelga cuesta un viaje de tarjeta entero y devuelve un solo bit, y lo
     * de abajo no llegaba a correr. */
#ifdef UVM2_PSRAM_BOOTROM
    uvm2_psram_probe_bootrom();
#endif
    uvm2_psram_probe_qpi();
#endif
    /* SONDA DEL PASO 1: ¿enlaza y CORRE una staticlib de Rust dentro de esta imagen?
     * Es la incognita que puede matar el plan de unificar el SDK, asi que se responde
     * antes de mover una sola linea de dibujo. Legible por SWD en uvm2_vx_probe:
     *   0x56580001 = la libreria esta y se ejecuta
     *   0          = la libreria no se enlazo (sin UVM2_VECTREX_DRAW)
     * La division va aparte porque los intrinsecos son justo lo que falta en enlaces
     * bare-metal: hoy mismo `__aeabi_ldivmod` tumbo el camino VPy. */
#ifdef UVM2_VECTREX_DRAW
    uvm2_vx_probe     = vx_probe();
    uvm2_vx_probe_div = vx_probe_div(1000, 7);   /* 142 */
#endif

    uvm2_frame_begin();
    uvm2_led_status(UVM2_STATUS_RUNNING);

#ifdef UVM2_STEP_OWNS_INIT
    /* THE REST OF THE BRING-UP, FOR THE VPy PATH ONLY.
     *
     * On the C-port path main() calls runtime_init and then, in this order, medir_e,
     * stream_start and core1_start. The VPy path never reaches that main(): the codegen
     * injects ONE call — `bl uvm2_runtime_init` as the first instruction of game_main —
     * and uvm2_pico_main.c skips the whole block under UVM2_STEP_OWNS_INIT. So the two
     * switches that matter were defines with no startup behind them:
     *
     *   UVM2_PIO_STREAM  changed the emit path but nobody started the state machine.
     *   UVM2_DUAL_CORE   made uvm2_frame_end hand the list to core 1 and return — and
     *                    core 1 was never launched, so NOTHING replayed the list.
     *
     * The symptom of the second one is the nastiest kind: the game runs, the frame
     * counter climbs, the host reports fps, and the screen stays black. Found on
     * SnowBros 2026-08-25, whose ELF had -DUVM2_DUAL_CORE and not one core-1 symbol —
     * the launch was unreferenced and the linker collected it.
     *
     * Same order as main(), so both paths bring the machine up identically. */
    uvm2_medir_e();
#  ifdef UVM2_PIO_STREAM
    /* After measuring E and with the bus already taken: the SM syncs against ~E. */
    uvm2_stream_start();
#  endif
#  ifdef UVM2_DUAL_CORE
    /* Last, never before: core 1 owns the bus from here on, and must not start
     * until the VIA has been programmed and the 6809 is halted. */
    uvm2_core1_start();
#  endif
#endif
}

/* r0-r3 of the interrupted code sit at frame[0..3]; frame[6] is the stacked PC,
 * which points just past the `svc` instruction, so the immediate is at [-2].
 * A result must be written back to frame[0] — exception return reloads r0. */
void uvm2_svc_dispatch(uint32_t *frame)
{
    const uint8_t *pc  = (const uint8_t *)(uintptr_t)frame[6];
    uint32_t       num = pc[-2];
    uint32_t       r0  = frame[0];
    uint32_t       r1  = frame[1];

    switch (num) {
    case SYS_RESET0REF:
        uvm2_draw_reset();
        break;

    case SYS_WAIT_RECAL:
    {
        /* DONDE SE VA EL FRAME, EN EL CAMINO DE UN SOLO NUCLEO.
         *
         * us_exec/us_input/us_rest/us_wait existian pero SOLO se escriben en
         * uvm2_core1.c, o sea en doble nucleo: en un juego single-core —asterock,
         * asteroids, todos los AAE— se leian CERO por SWD y no decian nada. Medido en
         * consola el 2026-09-03: el frame duraba 24.204 us y el dibujo (8.768 ciclos de
         * bus a 1,5 MHz) solo 5.845, o sea el 24%. El 76% restante no tenia desglose, y
         * sin el, "optimizar el dibujo" es apostar. Cuatro lecturas de TIMER0 por frame.
         *
         * us_exec  = reproducir la lista al haz (el dibujo de verdad)
         * us_input = botones + ejes (el SAR analogico son 8 sondeos por eje)
         * us_rest  = audio y el cierre del frame
         * us_wait  = lo que tardo EL JUEGO desde el WAIT_RECAL anterior: su logica, que
         *            en un puerto SBT es el 6502 traducido. Es el numero que dice si el
         *            techo de refresco es nuestro o suyo.
         */
        const uint32_t t_e0 = uvm2_us();
        uvm2_stats.us_wait = t_e0 - s_us_recal_prev;
        uvm2_frame_end();
        const uint32_t t_e1 = uvm2_us();
        /* UN SOLO ESCRITOR POR CAMPO. En doble nucleo el dibujo lo hace core 1 y `us_exec`
         * es SUYO; aqui lo que se mide es el cierre de frame en core 0, que es otra cosa.
         * Escribiendo los dos en el mismo sitio, el lector veia el que pasara ultimo — y
         * por SWD salia 0,00 ms para el dibujo entero. */
#ifdef UVM2_DUAL_CORE
        uvm2_stats.us_fin_frame = t_e1 - t_e0;
#else
        uvm2_stats.us_exec = t_e1 - t_e0;
#endif
#ifdef UVM2_DUAL_CORE
        /* Core 1 owns the bus now: the replay, the control reads, the PSG queue,
         * the audio tick and the 50 Hz pacing all happen there (uvm2_core1.c).
         * Touching Port A or Port B from here would put two writers on the VIA
         * with no arbitration — the exact fault the cartridge shipped when 40
         * games claimed dual-core while compiled single-core.
         *
         * uvm2_frame_end has already blocked until core 1 released the buffer we
         * are about to fill, so this returns at the same rate as before; what it
         * no longer does is wait out the beam. */
#else
        /* Between frames, with the beam clamped at centre — the only window in
         * which input reads and PSG writes may drive Port B.  Audio is ticked
         * here rather than on a second core, so the .vmus tempo follows the
         * frame rate; a frame over budget stretches the music with it. */
#ifndef UVM2_NO_INPUT
        s_buttons = uvm2_read_buttons();
        s_axes    = uvm2_read_axes();
#endif
        uvm2_stats.us_input = uvm2_us() - t_e1;
        /* Both of those drove Port A/B for the PSG and the analog mux, which the
         * draw path's cached DAC/S-H state does not know about. Drop the cache so
         * the next frame re-establishes Y, Z and the DAC instead of trusting a
         * hold the SAR just overwrote. */
        uvm2_draw_invalidate();

        /* Advance the sequencer by ELAPSED VECTREX TIME, not once per frame.
         * A frame heavy enough to blow the 50 Hz budget takes two frames' worth
         * of bus cycles, and ticking once would play the track at half speed —
         * which is exactly what a draw-heavy game did. Our own cartridge gets
         * this for free by sequencing on core 1; here we count the cycles. */
#ifndef UVM2_NO_AUDIO
        s_audio_acc += uvm2_frame_bus_cycles();
        while (s_audio_acc >= UVM2_AUDIO_CYCLES) {
            s_audio_acc -= UVM2_AUDIO_CYCLES;
            uvm2_audio_tick();
        }
#endif
#endif /* UVM2_DUAL_CORE */

        uvm2_frame_begin();
        {   /* lo que queda del bloque, y la marca desde la que se mide EL JUEGO */
            const uint32_t t_fin = uvm2_us();
            /* us_rest NO ES DE FIAR EN DOBLE NUCLEO: lo escribe TAMBIEN uvm2_core1.c
             * (`us_rest = time_us_32() - t2`), asi que los dos nucleos se pisan el mismo
             * contador y esta resta cruza dos relojes distintos. Medido en consola con
             * mhavoc: us_rest = 4294966253, o sea -1043. Los us_frame_* si valen (los mide
             * mide_periodo() con reloj de pared y un solo escritor). Arreglarlo es darle un
             * contador a cada nucleo, no tocar la formula. */
            uvm2_stats.us_rest = t_fin - t_e1 - uvm2_stats.us_input;
            s_us_recal_prev = t_fin;
        }
        /* AQUI HABIA UN uvm2_draw_prime_holds(), y era un SEGUNDO cebado hecho
         * al lado equivocado de la pinza de cero.
         *
         * frame_begin() termina soltando la pinza, asi que esta llamada cebaba
         * los tres sample-and-hold —incluida la referencia de cero— contra unos
         * integradores YA LIBRES. Es exactamente la divergencia que ya
         * diagnosticamos contra el escritor de Ralf en 2026-08-04: "priming
         * against a free-running integrator measures the drift instead of a
         * reference — this is the square that starts the right size and then
         * shrinks and skews". Observado en consola hoy: "primero sale grande y
         * luego se reduce la escala".
         *
         * Su intencion (el comentario decia "must come after frame_begin so they
         * are part of the new stream") ya la cumple via_setup(), que ceba los
         * mismos tres canales al principio de frame_begin con la pinza PUESTA.
         * Asi que esto no solo estaba mal colocado: sobraba. De paso ponia
         * s_z = 0, tirando la intensidad que frame_begin acababa de reponer. */
        break;
    }

#ifdef UVM2_NO_DRAW
    /* Bisection build: swallow every drawing syscall so the stream carries only
     * what frame_end/frame_begin put in it. Anything still visible on screen is
     * produced by the frame boundary, not by the game's geometry. */
    case SYS_SET_INTENSITY:
    case SYS_MOVE:
    case SYS_DRAW_DELTA:
    case SYS_MOVE_ABS:
        break;
#else
    case SYS_SET_INTENSITY:
        uvm2_draw_intensity((int)r0);
        break;

    case SYS_MOVE:
        uvm2_draw_move((int)(int32_t)r0, (int)(int32_t)r1);
        break;

    case SYS_DRAW_DELTA:
        uvm2_draw_delta((int)(int32_t)r0, (int)(int32_t)r1);
        break;

    case SYS_MOVE_ABS:
        uvm2_draw_move_abs((int)(int32_t)r0, (int)(int32_t)r1);
        break;

    /* VPY EN SUBUNIDADES (2026-09-16): el compilador ARM emite el salto y el trazo en 1/16
     * de unidad, las mismas funciones que v_directDraw32 en los puertos en C. */
    case SYS_MOVE_Q4:
        uvm2_draw_move_q4((int)(int32_t)r0, (int)(int32_t)r1);
        break;

    case SYS_DRAW_DELTA_Q4:
        uvm2_draw_delta_q4((int)(int32_t)r0, (int)(int32_t)r1);
        break;

    /* ONE RAMP FOR A WHOLE COLLINEAR RUN. The emitter (sdk_rp2350.c flush_frame) has
     * already merged the run and expressed the dark stretches as 0..255 fractions of it;
     * uvm2_draw_delta_patterned turns those into T1 counts and drops the ones that round
     * to nothing. r2/r3 are not unpacked at the top of this function, so they come
     * straight out of the stacked exception frame, same as SYS_RASTER_TEXT. */
    case SYS_DRAW_GAPPED:
        uvm2_draw_delta_patterned((int)(int32_t)r0, (int)(int32_t)r1,
                                  (const unsigned char *)(uintptr_t)frame[2],
                                  (int)frame[3]);
        break;

    /* r0=x, r1=y (both i8), r2=string, r3 = scale | (intensity << 8).
     * The VPy stub has already resolved TEXT_SIZE and the brightness override
     * into r3, so both defaults are applied before we ever see the call. */
    case SYS_PRINT_TEXT:
        uvm2_print_text((int)(int8_t)r0, (int)(int8_t)r1,
                        (const char *)(uintptr_t)frame[2],
                        (int)(frame[3] & 0xFFu), (int)((frame[3] >> 8) & 0xFFu));
        break;

    case SYS_PLAY_MUSIC:
        uvm2_play_music((const uint8_t *)(uintptr_t)r0);
        break;

    case SYS_STOP_MUSIC:
        uvm2_stop_music();
        break;

    case SYS_PLAY_SFX:
        uvm2_play_sfx((const uint8_t *)(uintptr_t)r0);
        break;

    /* Raster text. The cart BIOS draws this with the VIA shift register; here we
     * render it with the vector font, which is what this SDK has. Same call, same
     * arguments — the game cannot tell, and it beats dropping the text. */
    case SYS_RASTER_TEXT: {
        /* r2/r3 are not unpacked at the top of this function — only r0/r1 are —
         * so take the string straight out of the stacked exception frame. */
        const char *str = (const char *)(uintptr_t)frame[2];
        if (str) uvm2_print_text((int)(int8_t)r0, (int)(int8_t)r1, str, 1, 0x5F);
        break;
    }

#endif /* UVM2_NO_DRAW */

    case SYS_SAMPLE_POS: {
        extern unsigned uvm2_smp_pos(unsigned voice, unsigned fps);
        frame[0] = uvm2_smp_pos(0u, r0);
        break;
    }

    case SYS_PSG_WRITE:
        /* Register 7 is the mixer. The sample injector composes its own channel over
         * what it believes the mixer to be, so a game driving the PSG directly has to
         * say -- see uvm2_audio_note_mixer. */
        if (r0 == 7u) { extern void uvm2_smp_note_mixer(uint8_t);
                        uvm2_smp_note_mixer((uint8_t)r1); }
        UVM2_PSG(r0, r1);
        break;

    /* A PSG read has to happen on the bus, now, and cannot be queued.  Dual-core
     * that means core 1 owns the pins and we must not — return silence, which is
     * what the register would read while nothing is playing. */
    case SYS_PSG_READ:
#ifdef UVM2_DUAL_CORE
        frame[0] = 0;
#else
        frame[0] = uvm2_psg_read(r0);
#endif
        break;

    case SYS_PSG_SILENCE:
        UVM2_PSG(8, 0);
        UVM2_PSG(9, 0);
        UVM2_PSG(10, 0);
        break;

    /* Two different shapes of the same byte, and they are not interchangeable.
     *   #7  wants "1 = pressed", J1 in bits 0-3 and J2 in bits 4-7.
     *   #14 wants the raw per-port bytes packed as (J1 << 8) | J2, still
     *       active-low, and the generated getters read J1 at bits 4-7 (the VIA
     *       Port B position) and J2 at bits 0-3.
     * Returning one where the other is expected leaves every button reading as
     * held down, which is exactly how this went wrong the first time. */
    case SYS_READ_BUTTONS:
        frame[0] = (uint32_t)(uint8_t)~UVM2_BUTTONS;
        break;

    case SYS_READ_BTN_RAW: {
        uint8_t  b  = UVM2_BUTTONS;
        uint32_t j1 = (uint32_t)(((b & 0x0Fu) << 4) | 0x0Fu);
        uint32_t j2 = (uint32_t)(((b >> 4) & 0x0Fu) | 0xF0u);
        frame[0] = (j1 << 8) | j2;
        break;
    }

    case SYS_READ_AXES:
        frame[0] = UVM2_AXES;
        break;

    /* Raw bus access. The address is a full Vectrex address; only the VIA is
     * reachable while the 6809 is halted, and the register is its low nibble. */
    /* Refused under UVM2_DUAL_CORE: core 1 owns the pins, and a raw access from
     * here would collide with a replay in progress.  Silently doing nothing is
     * the safe answer — these are diagnostic calls, and a game that depends on
     * them has a bigger problem than this target. */
    case SYS_BUS_WRITE:
#ifndef UVM2_DUAL_CORE
        uvm2_via_write(r0 & 0x0Fu, r1);
#endif
        break;

    case SYS_BUS_READ:
#ifdef UVM2_DUAL_CORE
        frame[0] = 0;
#else
        frame[0] = uvm2_via_read(r0 & 0x0Fu);
#endif
        break;

    /* Digitised samples and SD browsing are not implemented on UVM2.  They are
     * no-ops in the IDE emulator too, so a game that calls them behaves the
     * same in both places rather than hanging. */
    default:
        frame[0] = 0;
        break;
    }
}
