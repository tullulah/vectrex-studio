/*
 * uvm2_draw.c — Vectrex beam control as a recorded VIA command stream.
 *
 * Ported from Ralf's VectrexHaltCommandWriter, which is the only version of
 * these sequences proven on real hardware.  Where his writer is a C++ class
 * building into a caller-supplied buffer, this is a single module-level stream
 * because our callers are syscalls, not a frame-composing object.
 *
 * The beam is analog: Port A is a DAC feeding the X integrator directly, while
 * Y, Z (intensity) and the zero reference are sampled off that same DAC through
 * a mux + sample/hold on Port B.  Motion is therefore "set the DAC, release
 * /RAMP for N bus cycles" — the distance is the DAC value times the time, which
 * is why `scale` is the dominant per-vector cost and the main throughput lever.
 */

#include "uvm2_bus.h"
#include <limits.h>
#include "uvm2_draw.h"
#ifdef UVM2_CMDS_IN_PSRAM
#include "uvm2_psram.h"
#endif

/* CUANTOS COMANDOS CABEN EN UN FRAME. Perilla por juego, no una constante.
 *
 * El 8192 venia de Ralf y de una cuenta que ya no vale: "un vector son ~8 comandos y un
 * frame de 50 Hz solo da para ~220 vectores". Eso era cierto MIENTRAS EL PACER FRENABA a
 * 50 Hz. Sin limite (UVM2_HZ=0) el juego dibuja todo lo que le cabe, y asteroids llega a
 * 744 vectores: 8751 comandos, de los que 559 se caian por el borde — medido, stats.dropped.
 *
 * Y un tope que se pasa NO se ve como un error, se ve como un dibujo incompleto, que es el
 * sintoma de otras diez cosas. De ahi el aviso del contador: si dropped no es cero, nada de
 * lo que se ve en pantalla es concluyente.
 *
 * Cuesta 4 bytes por comando y por buffer (dos buffers en doble nucleo), asi que subirlo no
 * es gratis: 12288 son 48 KB por buffer. Se sube por juego, con el contador delante:
 *
 *     make uvm2 UVM2_CMD_CAPACITY=12288      # y comprobar que stats.dropped queda en 0
 */
#ifndef UVM2_CMD_CAPACITY
#define UVM2_CMD_CAPACITY  8192u
#endif

/* One buffer single-core, two when core 1 replays: core 0 fills the buffer for
 * frame n while core 1 is still replaying frame n-1.  Single-core builds keep
 * exactly one, so nothing grows for a target that does not use it. */
#ifdef UVM2_DUAL_CORE
#  define UVM2_NBUF 2u
#else
#  define UVM2_NBUF 1u
#endif
/* LA LISTA, EN SRAM O EN LA PSRAM EXTERNA.
 *
 * En SRAM la lista compite con el juego: dkong deja 3788 bytes libres de los 496 KB, asi
 * que subir el tope de 8192 no cabe (pedir 16384 desborda por 61748). La PSRAM del UVM2
 * son 8 MB y en una imagen de SRAM no la usa nadie, asi que ahi el tope deja de ser un
 * problema de memoria.
 *
 * POR QUE SE PUEDE PERMITIR LA LATENCIA. La lista se REPRODUCE al ritmo del bus del
 * Vectrex: un comando es un ciclo de bus, 667 ns. Una lectura secuencial por la cache del
 * XIP esta muy por debajo, asi que del lado de core 1 la latencia se esconde entera.
 * Donde puede doler es al ESCRIBIRLA —core 0, a toda velocidad y sin pacer— y eso no se
 * supone: se compara us_exec y el periodo de frame con la perilla y sin ella.
 *
 * No lleva script de enlazado: es un puntero a una direccion fija. La PSRAM esta vacia en
 * una imagen de SRAM, y asi esto no toca el memmap del pico-sdk.
 */
#if defined(UVM2_CMDS_IN_PSRAM) && defined(UVM2_PSRAM_IMAGE)
#  error "UVM2_CMDS_IN_PSRAM con la imagen YA en PSRAM: la lista pisaria el propio codigo"
#endif

#ifdef UVM2_CMDS_IN_PSRAM
/* POR EL ALIAS SIN CACHE (0x15000000), NO POR LA VENTANA NORMAL (0x11000000).
 *
 * MEDIDO, escribiendo 16 KB y comprobandolos por el alias: por la ventana con cache fallan
 * 2512 palabras de 4096; por el alias, CERO. La PSRAM esta sana — lo que corrompe el dato
 * es pasar por la cache del XIP al escribir, que rellena linea leyendo del chip lo que
 * todavia no se ha escrito, lo mezcla y devuelve esa mezcla.
 *
 * Y ES LA MISMA TRAMPA QUE YA ESTABA DOCUMENTADA: verificar por la cache no dice nada del
 * chip. Por eso el cargador de dos etapas "funcionaba" (payloads de 12 KB que caben en los
 * 16 KB de cache), asteroids desde PSRAM "arrancaba pero temblaba", y la lista de comandos
 * colapsaba el dibujo a una diagonal. Un solo fallo, no tres.
 *
 * Aqui ademas es lo correcto por diseño: la lista se escribe una vez y se lee una vez, asi
 * que la cache no puede aportar nada — solo estorbar. */
#  ifndef UVM2_PSRAM_CMDS_BASE
#    define UVM2_PSRAM_CMDS_BASE 0x15000000u
#  endif
typedef uint8_t uvm2_cmd_buf[UVM2_CMD_CAPACITY * 3u];
static uvm2_cmd_buf *const s_cmds = (uvm2_cmd_buf *)(uintptr_t)UVM2_PSRAM_CMDS_BASE;
#else
static uint8_t s_cmds[UVM2_NBUF][UVM2_CMD_CAPACITY * 3u];
#endif
static uint32_t s_count;
static uint32_t s_buf;                  /* buffer being filled; always 0 single-core */

#ifdef UVM2_DUAL_CORE
/* The handshake, and the only shared state between the cores besides the
 * buffers themselves.  Both only ever count up, so a 32-bit load can never tear
 * and no lock is needed — ordering comes from the barriers around them. */
volatile uint32_t uvm2_frame_request;   /* frames core 0 has finished building */
volatile uint32_t uvm2_frame_done;      /* frames core 1 has finished replaying */
static volatile uint32_t s_len[2];
static uint32_t s_frame_no = 1;

const uint8_t *uvm2_frame_buffer(uint32_t frame) { return s_cmds[frame & 1u]; }
uint32_t        uvm2_frame_length(uint32_t frame) { return s_len[frame & 1u]; }
#endif
static uint32_t s_frames;

/* Shadow of the VIA state, so a command is only emitted when something really
 * changes.  Data bytes, not the shifted command fields. */
static uint8_t  s_porta = 0x00;
/* Every 8-bit value is a legal DAC setting, so `stale` needs its own flag rather
 * than a sentinel that could collide with a real one. */
static int      s_porta_stale = 1;
static uint8_t  s_portb = UVM2_PB_IDLE;
static uint8_t  s_pcr   = UVM2_PCR_IDLE;
static int      s_y     = 0;        /* value currently held by the Y S/H  */
static int      s_z     = 0;        /* value currently held by the Z S/H  */
static int      s_pos_x = 0;        /* beam position since the last centre */
static int      s_pos_y = 0;

static uint32_t s_frame_cycles;     /* bus cycles the last frame really took */
/* Ciclos de rampa para un delta de fondo de escala. 160 lo pone del TAMAÑO DEL
 * CARTUCHO, comprobado en pantalla con dkong el 2026-08-12; con 128 el escenario
 * salia visiblemente pequeño. Y sale MAS BARATO que el 128 que habia: 154 ciclos
 * por vector contra 157. Llevabamos dibujando pequeño y pagando mas.
 *
 * El motivo no es que agrandar sea gratis —la distancia es velocidad por tiempo y
 * el DAC ya va lleno: de 992 escrituras medidas la mediana es 25, el p90 es 89 y
 * 11 saturan en 127, asi que subir la ganancia recortaria los trazos largos— sino
 * el suelo del fixup, que dobla el delta y parte la rampa mientras la escala
 * supere UVM2_RAMP_FLOOR:
 *
 *     desde 128:  128 -> 64 -> 32          se para.  Rampa final 32
 *     desde 160:  160 -> 80 -> 40 -> 20    una mas.  Rampa final 20
 *
 * O sea que esta perilla va A SALTOS, no de forma continua. Medido:
 *     128 -> 157 c/vector    144 -> 147    160 -> 154
 * El 144 es el mas barato y dibuja pequeño; el 160 acierta el tamaño. Si algun
 * dia hay que afinar de verdad, el sitio es RAMP_FLOOR, no este numero.
 *
 * SE PAGA EN BRILLO: los vectores cortos pasan de 32 ciclos de rampa a 20, o sea
 * menos rato encendidos. No se vio empeorar en dkong; es lo que hay que mirar si
 * un juego con detalle fino sale apagado. */
static uint32_t s_scale = 160;
static int      s_fixup = 0;

/* Timings, in bus cycles.  Named because they are exactly the knobs to turn
 * when the picture is right but the frame is too expensive. */
/* Asentamiento del sample-and-hold, EN FUNCION DEL SALTO.
 *
 * El condensador tarda segun cuanta tension tenga que recorrer, no segun lo que
 * dure el trazo que viene despues. Y el fixup dobla el delta de los vectores
 * cortos, asi que un peldaño acaba pidiendo un salto GRANDE — por eso sufrian
 * los cortos, que es lo contrario de lo que uno esperaria.
 *
 * MEDIDO en consola 2026-08-12 con dkong: con 8 fijo los peldaños caen en Y y el
 * dibujo encoge; con 14 fijo salen bien pero el refresco baja de 24,8 a 13,3 fps
 * (138 -> 167 ciclos por vector), porque se paga en CADA muestreo de mux. Con 10
 * salen bien "casi siempre", que es la firma de un umbral mal puesto: unos saltos
 * llegan y otros no.
 *
 * La fisica: Ron(4052) x 10 nF = 1,8 us = 2,7 ciclos de E por tau. 8 ciclos son
 * 3 tau (5% de error), 14 son 5,2 tau (0,6%). Un salto pequeño puede permitirse
 * el 5%; uno de fondo de escala, no.
 *
 * Lineal en el salto entre los dos extremos. La ley de verdad es logaritmica, asi
 * que esto PAGA DE MAS en los saltos medianos — y aun asi sale mucho mas barato
 * que el maximo fijo. Si hay que afinar, es aqui y con el corchete en pantalla. */
#define UVM2_HOLD_MIN        4u     /* saltos diminutos: no piden mas          */
#define UVM2_HOLD_MAX        15u    /* fondo de escala: 5,5 tau, 1 LSB de error */
#define UVM2_HOLD_DELAY      UVM2_HOLD_MAX   /* cuando no se sabe de donde venimos */
#define UVM2_BLANK_OFF_DELAY 3u     /* ramp starts this early, before lighting */
#define UVM2_BLANK_ON_DELAY  16u    /* beam stays lit after the ramp stops     */
#define UVM2_ZERO_BASE       45u    /* centring cost, plus scale/4             */

/* Comandos perdidos en el frame en curso, por lista llena. Se vuelca a stats en
 * frame_end. Declarada aqui y no abajo porque emit() es quien la incrementa. */
/* Firma de lo que emit() manda escribir, contra lo que el chip devuelve al releerlo. */
uint32_t uvm2_firma_emitida = 2166136261u, uvm2_firma_releida, uvm2_firma_malas, uvm2_firma_vueltas;
uint32_t uvm2_firma_copia, uvm2_firma_copia_malas, uvm2_firma_copia_vueltas;

static uint32_t s_dropped;

static inline void emit(uint32_t reg, uint32_t data, uint32_t delay)
{
    if (s_count < UVM2_CMD_CAPACITY) {
        const uint32_t w = UVM2_CMD(reg, data, delay);
        const uint32_t v = UVM2_CMD_EMPAQUETA(w);
        uint8_t *d = &s_cmds[s_buf][s_count * 3u];
        d[0] = (uint8_t)v; d[1] = (uint8_t)(v >> 8); d[2] = (uint8_t)(v >> 16);
        s_count++;
#ifdef UVM2_CMDS_IN_PSRAM
        /* LO QUE SE MANDA ESCRIBIR, firmado aqui — antes de que salga al bus.
         *
         * El test psramrw escribe por el alias sin cache y da CERO fallos en 4096 palabras,
         * pero lo hace con la maquina EN SILENCIO: sin stream, sin DMA y sin el bus del
         * cartucho moviendose. El juego no. Comparando esta firma con la de releer la lista
         * del chip se sabe si las escrituras aguantan BAJO CARGA, que es la unica diferencia
         * que queda entre el test que pasa y el juego que colapsa. */
        uvm2_firma_emitida ^= d[0]; uvm2_firma_emitida *= 16777619u;
        uvm2_firma_emitida ^= d[1]; uvm2_firma_emitida *= 16777619u;
        uvm2_firma_emitida ^= d[2]; uvm2_firma_emitida *= 16777619u;
#endif
    }
    else                             s_dropped++;   /* NUNCA en silencio: ver stats.dropped */
}

/* ── Primitive register writes ────────────────────────────────────────────── */

static void set_porta(uint8_t v, uint32_t delay)
{
    if (s_porta == v && !s_porta_stale) return;
    s_porta = v;
    s_porta_stale = 0;
    emit(UVM2_VIA_PORTA, v, delay);
}

/* Sample the current DAC value into one of the mux channels: disable the mux,
 * select the channel, enable it for `delay` cycles, then park Port B again. */
static void mux_sample(uint8_t channel, uint32_t delay)
{
    uint8_t keep = (uint8_t)(s_portb & 0xF8u);   /* preserve /RAMP + sound bits */
    emit(UVM2_VIA_PORTB, keep | channel | UVM2_PB_MUX_DISABLE, 0);
    emit(UVM2_VIA_PORTB, keep | channel | UVM2_PB_RAMP_OFF,    delay);
    emit(UVM2_VIA_PORTB, s_portb, 0);
}

/* Ciclos que necesita el hold para recorrer `from` -> `to`.
 *
 * LA LEY ES LOGARITMICA, no lineal: un RC llega a 1 LSB en t = tau * ln(salto),
 * con tau = Ron(4052) x 10 nF = 1,8 us = 2,7 ciclos de E. Doblar el salto cuesta
 * un tau mas, no el doble de tiempo.
 *
 * La primera version interpolaba linealmente y era mala en los DOS sentidos:
 * sobrepagaba los saltos pequeños —que son la mayoria— y se quedaba CORTA en los
 * medianos (un salto de 64 necesita 11,3 ciclos y le daba 9,5). Costaba 151
 * ciclos por vector contra 138 del minimo roto y 167 del maximo fijo.
 *
 * ln(d) = log2(d) * 0,693, y log2 entero es la posicion del bit mas alto, que el
 * micro da con una instruccion. tau * ln2 = 1,87 ciclos por bit. */
static uint32_t hold_for(int from, int to)
{
    uint32_t d = (uint32_t)(to > from ? to - from : from - to);
    if (d == 0) return UVM2_HOLD_MIN;
    uint32_t bits = 32u - (uint32_t)__builtin_clz(d);      /* ~log2(d) + 1 */
    uint32_t t    = (bits * 187u) / 100u;                  /* tau * ln2    */
    if (t < UVM2_HOLD_MIN) t = UVM2_HOLD_MIN;
    if (t > UVM2_HOLD_MAX) t = UVM2_HOLD_MAX;
    return t;
}

static void set_y(int y, uint32_t delay)
{
    if (s_y == y) return;                 /* the S/H still holds it */
    delay = hold_for(s_y, y);
    s_y = y;
    set_porta((uint8_t)y, 0);
    mux_sample(UVM2_MUX_Y, delay);
}

static void set_z(int z, uint32_t delay)
{
    if (s_z == z) return;
    delay = hold_for(s_z, z);
    s_z = z;
    set_porta((uint8_t)z, 0);
    mux_sample(UVM2_MUX_Z, delay);
}

/* X is the live DAC — no sample/hold, so it must be written last before a ramp. */
static void set_x(int x, uint32_t delay)
{
    set_porta((uint8_t)x, delay);
}

static int32_t s_drift_ax, s_drift_ay;   /* ver la compensacion de deriva, abajo */

static void set_zero(int active, uint32_t delay)
{
    /* CADA re-cero borra la deriva acumulada, porque devuelve el haz al centro.
     * Si el acumulador sobrevive, se sigue corrigiendo un error que ya no existe
     * — y como los re-ceros caen en sitios distintos segun la escena, ese sobrante
     * CAMBIA entre frames: tiembla. Un error determinista no puede temblar.
     *
     * Aqui y no en frame_begin: los re-ceros ocurren muchas veces dentro de un
     * frame (uno por objeto, mas los que mete el tope de trazos). */
    if (active) { s_drift_ax = 0; s_drift_ay = 0; }

    s_pcr = (uint8_t)((s_pcr & ~UVM2_PCR_ZERO_OFF) | (active ? 0u : UVM2_PCR_ZERO_OFF));
    emit(UVM2_VIA_PCR, s_pcr, delay);
}

/* `set_ramp` SE HA IDO. Conmutaba /RAMP escribiendo PB7 por PORTB, que es el modelo de
 * haz de Ralf; ahora la rampa la termina T1 (ACR = 0x80) y esos bits ni llegan al pin.
 * Dejarla habria sido peor que borrarla: una funcion que compila, se puede llamar y no
 * hace absolutamente nada. */
/* ── Public API ───────────────────────────────────────────────────────────── */

void uvm2_draw_set_scale(uint32_t cycles)
{
    if (cycles < 8u)  cycles = 8u;
    if (cycles > 255u) cycles = 255u;
    s_scale = cycles;
}

void uvm2_draw_set_fixup(int enable) { s_fixup = enable; }

/* The VIA bring-up and the sample-and-hold priming, as one unit.
 *
 * This is Ralf's VectrexHaltCommandWriter constructor, and he runs it at the top
 * of EVERY frame — he builds a fresh writer per frame, so all sixteen commands go
 * out again every 20 ms. We used to run it once, from uvm2_draw_init.
 *
 * Two reasons it belongs in the frame:
 *
 *  - the holds are capacitors. Primed once at boot, the zero reference, the Y
 *    hold and the Z hold droop, and the beam's idea of centre and scale drifts
 *    with them — which is the square that starts the right size and then shrinks
 *    and skews.
 *  - the PCR it writes is UVM2_PCR_IDLE, i.e. the zero clamp ASSERTED. Priming
 *    the holds against a clamped integrator gives a real reference; priming
 *    against a free-running one measures the drift instead. We released the
 *    clamp first and then primed, which is that mistake exactly.
 *
 * Sixteen commands is ~40 of the 30000 bus cycles in a frame: 0.13%. */
static void via_setup(void)
{
    s_porta = 0x00;
    s_portb = UVM2_PB_IDLE;
    s_pcr   = UVM2_PCR_IDLE;      /* zero clamp asserted, beam blanked */

    /* Port A all outputs (the DAC); Port B outputs except the comparator input
     * (bit 5) and PB6.  ACR: shift register under phase-2 control, T1 free-run
     * — the same values the Vectrex BIOS programs. */
    emit(UVM2_VIA_PORTA, s_porta, 0);
    emit(UVM2_VIA_DDRA,  0xFF,    0);
    emit(UVM2_VIA_PORTB, s_portb, 0);
    emit(UVM2_VIA_DDRB,  0x9F,    0);
    emit(UVM2_VIA_PCR,   s_pcr,   0);
    /* ACR ES PARTE DEL MODELO DE HAZ, no un valor suelto:
     *   0x60 -> T1 libre con PB7 DESACTIVADO; /RAMP lo conmuta el software por PORTB.
     *   0x80 -> T1 en un disparo CON salida por PB7: escribir T1CH baja /RAMP y el
     *           agotarse la cuenta lo sube. La rampa la termina el 6522, que es lo que
     *           programa la BIOS y lo que asume la capa compartida.
     * Con 0x80 los bits de PORTB que tocan PB7 dejan de llegar al pin, asi que
     * `set_ramp` no hace nada — por eso el camino compartido no lo llama. */
    emit(UVM2_VIA_ACR,   0x80,    0);

    /* Prime each sample/hold channel from a DAC value of 0: zero reference,
     * then Y, then Z.  Without this the integrators start wherever the analog
     * section powered up. */
    set_porta(0x00, 0);
    mux_sample(UVM2_MUX_ZEROREF, UVM2_HOLD_DELAY);
    mux_sample(UVM2_MUX_Y,       UVM2_HOLD_DELAY);
    mux_sample(UVM2_MUX_Z,       UVM2_HOLD_DELAY);

    s_y = 0; s_z = 0; s_pos_x = 0; s_pos_y = 0;
}


/* ── Calibracion por placa: DONDE iria, y por que ahora no hay ninguna ──────
 *
 * Los knobs del modelo son el MISMO simbolo que usa el firmware del cartucho propio, pero
 * su valor no tiene por que serlo: "VCAP no es una constante del repositorio, es una
 * calibracion de MAQUINA". Si esta placa necesita valores propios, se escriben aqui en el
 * arranque —son AtomicU32 Relaxed, o sea un uint32_t volatil desde C— en vez de forkear
 * el codigo.
 *
 * HOY NO HACE FALTA NINGUNA, y eso es un resultado, no un descuido. Estuvo VCAP = 96
 * porque cuatro de los cinco trazos del pentagono saturaban el DAC a +-128 y el modelo de
 * Ralf nunca satura. La hipotesis era que el amplificador de deflexion no seguia. MEDIDO
 * y FALSA: con 96 ya ibamos mas despacio que el (pico 97 contra 114) y el dibujo seguia
 * igual de mal. La causa real era otra —T1CH re-disparandose durante el retardo, ver
 * `vxs_wait_ramp`— y con eso arreglado, 127 es el valor compartido y va mejor: menos
 * tiempo de rampa por trazo.
 *
 * Se deja escrito y no se deja una funcion vacia llamandose: una linea que dice que algo
 * esta encendido cuando no existe es peor que no tenerla. */

void uvm2_draw_init(void)
{
    s_count = 0;
    via_setup();

    uvm2_stats.bus_cycles = uvm2_exec(s_cmds[s_buf], s_count);
    uvm2_stats.commands   = s_count;
    s_count = 0;
}

/* Forget what we believe the hardware holds.
 *
 * set_porta/set_y/set_z skip a write when their cached value already matches —
 * a real saving, since a vector that reuses the same Y costs four commands less.
 * The cache is only valid while NOTHING ELSE drives the DAC or the mux. The
 * joystick conversion does both: one CD4052 serves the pots and the beam on
 * shared select lines, so a SAR sweep on an axis lands in the Y sample-and-hold
 * as a side effect. The software then believes Y is still correct, skips the
 * write, and the frame's first vector is drawn at whatever Y the joystick left —
 * a stray bright segment that FOLLOWS THE STICK. (Seen on hardware 2026-08-04;
 * the cart does not show it because its read_axes re-zeros the beam and its SDK
 * resets its own tracking every frame.)
 *
 * Call this after anything that touches Port A/B outside the draw stream. */
void uvm2_draw_invalidate(void)
{
    s_porta_stale = 1;
    s_y = INT_MIN;
    s_z = INT_MIN;
}

/* Re-prime the beam's sample-and-holds from a DAC value of 0.
 *
 * The analog joystick read does not merely disturb the mux — it WRITES THROUGH
 * it. `read_axis_analog` drives Port B with PB0 low, which ENABLES the CD4052,
 * and the two halves share select lines, so while the SAR sweeps the DAC to find
 * an axis it is simultaneously charging a beam sample-and-hold:
 *
 *     mux channel 0  (joystick X)  ->  Y sample-and-hold
 *     mux channel 1  (joystick Y)  ->  the ZERO REFERENCE capacitor
 *
 * Y the draw path rewrites every frame once its cache is invalidated. The zero
 * reference it never rewrites — uvm2_draw_init primed it ONCE at start-up — so
 * after the first joystick read the beam's idea of centre is whatever the SAR
 * left behind. That is the bright streak through the middle of the screen which
 * tracks the stick, in every scene (hardware, 2026-08-04).
 *
 * Cheap: three mux samples, ~9 commands and ~24 bus cycles of a 30000 budget. */
void uvm2_draw_prime_holds(void)
{
    set_porta(0x00, 0);
    mux_sample(UVM2_MUX_ZEROREF, UVM2_HOLD_DELAY);
    mux_sample(UVM2_MUX_Y,       UVM2_HOLD_DELAY);
    mux_sample(UVM2_MUX_Z,       UVM2_HOLD_DELAY);
    s_y = 0;
    s_z = 0;
}

void uvm2_draw_reset(void)
{
    /* RE-CEBAR LA REFERENCIA DE CERO, COMO HACE LA BIOS.
     *
     * Reset0Ref ($F354) cae en Reset_Pen ($F35B), que en CADA re-cero pone el DAC
     * a cero y da el ciclo de mux del canal de referencia:
     *
     *     CLR <VIA_port_a      ; DAC a cero
     *     STA <VIA_port_b      ; mux=1, deshabilitado
     *     STB <VIA_port_b      ; mux=1, habilitado
     *     STB <VIA_port_b      ; otra vez
     *     LDB #$01 / STB       ; deshabilitar
     *
     * Nosotros lo haciamos UNA VEZ POR FRAME, en via_setup. Y ese condensador
     * derrama: si la referencia se ha ido, el "cero" al que vuelve el haz no es el
     * mismo al principio del frame que al final, y el error depende de cuantos
     * objetos se hayan dibujado antes — o sea que CAMBIA cuando aparece un barril.
     * Eso es un temblor, y encaja con lo observado en consola.
     *
     * Cuesta tres escrituras y su asentamiento por re-cero. Con fronteras de
     * objeto los re-ceros son pocos, asi que sale barato.
     * UVM2_NO_REPRIME_ON_RESET lo desactiva para comparar. */
#ifndef UVM2_NO_REPRIME_ON_RESET
    set_porta(0x00, 0);
    mux_sample(UVM2_MUX_ZEROREF, hold_for(0, 0));
#endif

    /* Already centred and already released? Nothing to do — re-zeroing is the
     * single most expensive thing a frame can repeat needlessly. */
    if (s_pos_x == 0 && s_pos_y == 0 && (s_pcr & UVM2_PCR_ZERO_OFF) != 0)
        return;

    set_zero(1, UVM2_ZERO_BASE + s_scale / 4u);
    set_zero(0, 0);
    s_pos_x = 0;
    s_pos_y = 0;
}

/* Ultima intensidad pedida, que SOBREVIVE al frame. via_setup() ceba Z a 0 cada
 * frame, asi que sin esto el hueco entre soltar la pinza y el primer SET_INTENSITY
 * del juego se recorre con Z desconocido. Ralf no tiene ese hueco: pone Z y
 * DESPUES suelta la pinza (SetZ(0x5F); SetZero(false);). */
static int s_z_last = 0;

void uvm2_draw_intensity(int brightness)
{
    if (brightness < 0)   brightness = 0;
    if (brightness > 127) brightness = 127;
    s_z_last = brightness;
    set_z(brightness, UVM2_HOLD_DELAY);
}

/* While both deltas are small, trade DAC range for ramp time: doubling the
 * delta and halving the scale draws the same length in half the cycles.  This
 * is Ralf's Fixup(), which he left in but disabled. */
/* Doubling dx,dy while halving the ramp draws the SAME vector in half the time:
 * the distance is the DAC value times the ramp duration, so the product is what
 * matters and only the time costs us anything.  Two limits stop the halving.
 *
 *  - The DAC.  Port A is a signed 8-bit converter, so a value can be doubled only
 *    while it is below half of full scale.  That bound is derived from the part,
 *    not chosen: UVM2_DAC_HALF.
 *
 *  - How short a ramp the analog section still integrates linearly.  That number
 *    is NOT known.  It belongs to the integrator's time constant and to the
 *    settling of the sample-and-holds feeding it, and nothing we have measured
 *    pins it down — so it is a build-time knob meant to be SWEPT on hardware with
 *    the geometry in view, not a constant to be tuned by eye.  32 is merely where
 *    it has sat since the fixup was written; it has never been measured, and it
 *    is currently the single biggest term in the frame (the ramp is ~90% of the
 *    time once beam travel is accounted for).
 *
 * Expect a plateau rather than a cliff when sweeping it: take the middle of the
 * range where the picture is still square, not the last value that survives. */
#define UVM2_DAC_FULL_SCALE 128
#define UVM2_DAC_HALF       (UVM2_DAC_FULL_SCALE / 2)

#ifndef UVM2_RAMP_FLOOR
#define UVM2_RAMP_FLOOR 32u
#endif

static void fixup(int *x, int *y, uint32_t *scale)
{
    if (!s_fixup) return;
    int ax = *x < 0 ? -*x : *x;
    int ay = *y < 0 ? -*y : *y;
    while (ax < UVM2_DAC_HALF && ay < UVM2_DAC_HALF && *scale > UVM2_RAMP_FLOOR) {
        *x *= 2; *y *= 2; ax *= 2; ay *= 2; *scale /= 2u;
    }
}

/* ── Compensacion de deriva ────────────────────────────────────────────────
 *
 * MEDIDO EN CONSOLA el 2026-08-12 con hardware/uvm2/drift, que dibuja una rejilla
 * rectangular de saltos y deja ajustar la correccion desde el mando hasta que sale
 * recta. Sin compensar, la rejilla sale como una cascada en diagonal: el haz NO
 * acaba donde se le manda, y el error se acumula salto a salto.
 *
 *     X  -16/256  = -0,06 unidades por salto
 *     Y -112/256  = -0,44 unidades por salto
 *
 * SIETE VECES MAS EN Y, y eso tiene explicacion fisica: X va directo al DAC, Y pasa
 * por el mux y el sample-and-hold. El condensador es quien lo mete. Por eso TODOS
 * los sintomas de ese dia eran verticales — peldaños caidos en Y, el Kong partido
 * por la mitad, el escenario encogido.
 *
 * El signo dice que el haz SE PASA, no que se quede corto: la hipotesis del retardo
 * de deflexion era la contraria. Encaja con que el integrador siga un instante
 * despues de congelar la rampa.
 *
 * EL ACUMULADOR ES LO QUE LO HACE FUNCIONAR. El error es una FRACCION de unidad, y
 * sumar una unidad entera por salto pasa de "corta" a "pasada" sin punto medio
 * (comprobado: con 1 unidad las columnas se iban al otro lado). Se lleva en 1/256 y
 * solo se traslada al delta al completar una unidad; el resto se guarda. Es
 * Bresenham: la correccion media es exacta aunque cada paso sea entero.
 *
 * Se pone a cero en frame_begin: el re-cero del frame borra la deriva real, asi que
 * arrastrar el acumulador seria corregir un error que ya no existe.
 *
 * COSTE: CERO ciclos de bus. Es aritmetica sobre un delta que ya se iba a escribir.
 * Para desactivarla, UVM2_DRIFT_X/Y = 0.  */
/* AJUSTABLES EN CALIENTE, no defines: el banco los mueve desde el mando y por
 * SWD sin recompilar. Por defecto CERO = desactivada, para no cambiar el
 * comportamiento de ningun juego hasta que este medida de verdad.
 *
 *   uvm2_drift_mode 0 -> la correccion sigue el SIGNO del salto
 *                   1 -> direccion FIJA, siempre al mismo lado
 * Esas dos hipotesis son indistinguibles si todos los saltos van igual, que es
 * el fallo que tenia el primer banco. Con texto se separan. */
/* CERO = DESACTIVADA, y asi se queda hasta que este bien medida. Lo que hay
 * medido es que el error EXISTE y es sistematico; el MODELO no esta cerrado:
 * el primer banco no podia distinguir si la correccion debe seguir el signo del
 * salto o ir siempre al mismo lado, porque todos sus saltos iban igual. Aplicarla
 * con el modelo equivocado empeora dkong (se probo: plataformas desplazadas hacia
 * arriba y temblor al aparecer los barriles). Ver hardware/uvm2/DERIVA.md. */
volatile int32_t uvm2_drift_x    = 0;
volatile int32_t uvm2_drift_y    = 0;
volatile int32_t uvm2_drift_mode = 0;


void uvm2_draw_drift_reset(void) { s_drift_ax = s_drift_ay = 0; }

static int drift_fix(int d, int32_t *acc, int32_t cte)
{
    if (cte == 0) return 0;
    if (uvm2_drift_mode == 0 && d == 0) return 0;   /* con signo: sin salto no hay error */
    *acc += cte;
    int32_t entero = *acc / 256;
    *acc -= entero * 256;
    if (uvm2_drift_mode) return (int)entero;        /* direccion fija */
    return (d > 0) ? (int)entero : -(int)entero;    /* con el signo del salto */
}


/* ── Sumidero hacia la capa de dibujo COMPARTIDA ─────────────────────────────
 *
 * El modelo de haz ya no vive aqui: vive en `vectrex-draw`, la misma caja que enlaza
 * el firmware del cartucho propio. Lo que queda de este lado es apilar los comandos
 * que el modelo emite — que es lo unico que de verdad cambia entre las dos placas.
 *
 * Ya no hay segundo camino: la capa vive en `../vectrex-draw`, en este mismo arbol, y
 * CMake la construye. El modelo de haz es UNO. */

struct vx_sink {
    void *ctx;
    void (*emit)(void *, uint32_t, uint32_t, uint32_t);
    void (*wait_ramp)(void *, uint32_t, int32_t);
    void (*beam_blanked)(void *);
    void (*y_held)(void *, int32_t);
};
struct vx_sink_extra { int (*y_can_skip)(void *, int32_t); int (*beam_is_lit)(void *);
                       void (*beam_lit)(void *); };
struct vx_timings { uint32_t e6809_q8, y_mux_q8, moveto_settle_q8, beam_on_q8;
                    int32_t blank_settle_q8; uint32_t keep_lit; uint32_t x_settle_q8; };
void vx_moveto_seq(struct vx_sink *, int32_t vx, int32_t vy, uint32_t t1,
                   const struct vx_timings *);
void vx_draw_line_patterned_seq(struct vx_sink *, int32_t vx, int32_t vy, uint32_t t1,
                                const struct vx_timings *, const uint16_t *huecos, uint32_t n);
void vx_draw_line_seq(struct vx_sink *, int32_t vx, int32_t vy, uint32_t t1,
                      const struct vx_timings *);
void vx_ramp_params(int32_t dx, int32_t dy, int32_t *vx, int32_t *vy, uint32_t *t1);

/* El retardo llega en Q8 de ciclo de E; el campo de comando es entero, asi que hay que
 * bajar de resolucion. SE TRUNCA, no se redondea.
 *
 * Redondear al mas cercano parece lo correcto —truncar sesga los huecos hacia abajo— y
 * por eso lo puse asi. Pero NUESTRO CARTUCHO TRUNCA: `e6809_raw` hace `cycles / 256` y
 * `stream_park(n - 1)`, asi que con E6809_SCALE_Q8 = 64 un hueco `e(2)` vale 128 Q8 y
 * alli espera CERO. Redondeando, aqui esperaba UNO. Son ~6 huecos por vector: con 300
 * vectores, unos 1.800 ciclos de E por frame de mas — un 6% del presupuesto de 30.000,
 * y en una placa que ya no llegaba.
 *
 * Entre "lo correcto en abstracto" y "lo que hace la otra placa", manda lo segundo: dos
 * implementaciones del mismo modelo que redondean distinto son dos modelos. */
static void vxs_emit(void *ctx, uint32_t reg, uint32_t data, uint32_t delay_q8)
{
    (void)ctx;
    /* La cache de Port A la lleva set_porta, y el modelo escribe PORTA por su cuenta.
     * Sin esto la cache creeria un valor que ya no esta en el DAC y se saltaria la
     * siguiente escritura — un fallo que solo aparece de vez en cuando, que es el peor
     * tipo. */
    if (reg == UVM2_VIA_PORTA) { s_porta = (uint8_t)data; s_porta_stale = 0; }
    /* ACOTAR ANTES DE EMPAQUETAR. El comando mete el retardo en `delay << 20`, asi que un
     * valor de mas de 12 bits se derrama en los campos de registro y dato: comandos
     * corruptos y pantalla negra, sin un solo aviso. Lo destapo un beam_on negativo que
     * daba la vuelta en un uint32_t. Es la misma familia que el tope de 8192 que tiraba
     * comandos en silencio — un limite callado no es un limite. */
    uint32_t d = delay_q8 / 256u;
    if (d > 4095u) d = 4095u;
    emit(reg, data, d);
}

/* AQUI NO SE SONDEA. En el cartucho propio esto pregunta al flag T1 de la VIA, como la
 * BIOS; aqui la lista la reproduce un ejecutor que no lee, y leer la VIA a mitad de lista
 * mientras conducimos el bus de datos es lo que causaba los vectores fantasma. Se cuenta
 * la rampa y punto — y esa diferencia esta ESCRITA en el trait, no escondida.
 *
 * ── Y AQUI ESTA EL FALLO QUE COSTO LA TARDE DEL 2026-08-18 ──────────────────
 *
 * El retardo NO puede colgarse del comando anterior cuando ese comando es T1CH.
 *
 * El ejecutor de esta placa mantiene R/W BAJO durante todos los ciclos de retardo, con
 * la direccion y el dato puestos. Su propio comentario dice por que se permite:
 *
 *     "every register we write (PORTA, PORTB, PCR, ACR, DDRx) takes the same value
 *      IDEMPOTENTLY, which is why Ralf's executor holds R/W low for the whole command"
 *
 * Esa lista es la SUYA. Su modelo nunca escribe T1: conmuta /RAMP por PORTB. El nuestro
 * escribe T1CH — y escribir T1C-H **rearranca el temporizador**. No es idempotente.
 *
 * Colgando el retardo de esa escritura, la VIA re-dispara T1 en CADA ciclo de E: PB7 se
 * queda abajo, el integrador no para donde debe, y el ultimo re-disparo arranca una
 * cuenta entera que sigue mas alla del retardo. De ahi los trazos que se pasan, el dibujo
 * mas grande de lo que toca y los vertices que no se encuentran — con la aritmetica
 * saliendo perfecta, que es lo que despisto seis hipotesis seguidas.
 *
 * SOLUCION: el retardo lo lleva un comando INOCUO detras. Se reescribe T1LL (el cerrojo
 * de la parte baja) con el mismo valor: escribirlo no toca la cuenta en curso ni recarga
 * nada en modo un disparo, asi que repetirlo 95 veces no hace absolutamente nada. Cuesta
 * un comando por vector. */
static void vxs_wait_ramp(void *ctx, uint32_t t1, int32_t extra_q8)
{
    (void)ctx;
    /* CON SIGNO: negativo = apagar ANTES de que la rampa termine. Hace falta de verdad —
     * medido en consola, subir el retardo ENSANCHA el hueco de los vertices, o sea que el
     * codo esta por debajo de cero. */
    int32_t d = (int32_t)t1 + extra_q8 / 256;
    if (d < 0) d = 0;
    if (d > 4095) d = 4095;        /* el campo son 12 bits */
    emit(UVM2_VIA_T1LL, t1 & 0xFFu, (uint32_t)d);
}

static void vxs_y_held(void *ctx, int32_t vy) { (void)ctx; s_y = (int)vy; }

static struct vx_sink vx_cart_sink(void)
{
    struct vx_sink s = { 0 };
    s.emit = vxs_emit;
    s.wait_ramp = vxs_wait_ramp;
    s.y_held = vxs_y_held;
    return s;
}

/* Los huecos, con los MISMOS valores que el cartucho propio.
 *
 * Antes estaban puestos a los de Ralf (e6809 sin descuento, 3 y 16 ciclos de E) con el
 * razonamiento de que importar los nuestros seria afinar a ciegas. El resultado fue peor
 * que cualquiera de las dos opciones: NUESTRO modelo de velocidad con SUS tiempos, una
 * combinacion que no habia probado nadie. Si se unifica, se unifica entero — y si luego
 * hay que separar algo, se separa con una medida delante.
 *
 * Equivalencias, del firmware:
 *   E6809_SCALE_Q8    = 64        -> tal cual, ya es Q8
 *   Y_MUX_ECYC        = 14 E
 *   BEAM_ON_DELAY_CYC = 200 CPU   -> 2 ciclos de E   (CPU_PER_ECYCLE = 100)
 *   BLANK_SETTLE_CYC  = 1100 CPU  -> 11 ciclos de E
 *   BEAM_KEEP_LIT     = 0
 *
 * SIGUEN SIENDO DE OTRA CONSOLA. `una-consola-no-es-evidencia`: se midieron en la
 * nuestra, contra nuestro camino de bus. Son el punto de partida del barrido, no el
 * final — pero al menos ahora es UNA configuracion coherente. */
/* AJUSTABLES EN CALIENTE, no defines. En esta placa no se pueden tocar por SWD —una
 * escritura para el nucleo y no vuelve, y resetear te devuelve al menu— asi que el camino
 * es el MANDO, igual que hizo `hardware/uvm2/drift` con la deriva. Ver hardware/uvm2/
 * beamtune. Volatiles y no static: tienen que sobrevivir al enlazador y ser visibles. */
/* MEDIDOS EN ESTA CONSOLA el 2026-08-18 con hardware/uvm2/beamtune, ajustando desde el
 * mando y mirando los vertices del pentagono. Con 16 y 2 las esquinas se abrian; con
 * 12 y 0 cierran. Queda un espolon pequeño en el vertice de arriba.
 *
 * Y NO son los del cartucho propio (11 y 2), lo cual es el punto: esto es calibracion de
 * MAQUINA. Los 11/2 salieron de una biseccion en NUESTRA consola, con otro camino de bus
 * y otro amplificador de deflexion. Aqui manda lo que se ve aqui.
 *
 * `beam_on = 0` merece una nota: encender el haz A LA VEZ que arranca la rampa. En
 * nuestra consola eso deja un punto brillante en el vertice de salida y por eso hay 2;
 * aqui el transporte ya mete su propio periodo de E entre las dos escrituras, asi que el
 * retardo explicito sobra. La misma cantidad fisica, pagada por otro. */
volatile int32_t uvm2_beam_on_e = 0;        /* ciclos de E entre arrancar y encender */
/* KNOBS EN TIEMPO DE EJECUCION, no constantes. En esta placa no se puede leer por SWD —el
 * nucleo conduce el bus con la fase de E pegada al reloj y pararlo es una violacion de
 * fase— asi que barrer una constante costaba un flasheo por valor. Estas se ajustan desde
 * el menu de servicio con el mando, viendo los fps al lado.
 *
 * y_mux: la ventana del mux de Y. Estaba en 2 y alguien la subio a 14 (ver emit.rs:154).
 * Son 12 ciclos de E en CADA operacion que cambia Y: ~5400 por frame, 3,6 ms.
 * keep_lit: mantener el haz encendido entre segmentos encadenados, que se ahorra el par
 * de escrituras de BLANK y sus asentamientos. Aqui nunca se ha probado. */
volatile int32_t uvm2_y_mux_e   = 14;
volatile int32_t uvm2_keep_lit  = 0;
volatile int32_t uvm2_blank_settle_e = 12;  /* ciclos de E que sigue encendido al parar */
/* ASENTAMIENTO DEL DAC EN X, antes de arrancar la rampa. Ver x_settle_q8 en emit.rs: la Y
 * llega muestreada y retenida tras `y_mux` ciclos de ventana, y la X va directa al DAC con
 * la rampa arrancando tres comandos despues. 0 = como siempre. */
volatile int32_t uvm2_x_settle_e = 0;
/* Periodo del frame en CICLOS DE BUS, 0 = libre. Arranca en lo que diga UVM2_HZ para no
 * cambiarle el comportamiento a nadie; el panel lo mueve en caliente. 30000 = 50 Hz. */
/* `used`: sin esto --gc-sections se lo lleva y el panel no lo encuentra. Le paso a este
 * y no a los otros knobs porque a aquellos los referencia vx_cart_timings; a este solo lo
 * mira uvm2_frame_end, y el enlazador decidio que sobraba. Un knob que no esta en el ELF
 * no se puede tocar en caliente, que es todo el punto. */
__attribute__((used)) volatile uint32_t uvm2_pacer_cycles =
#if UVM2_HZ == 0
    0u;
#else
    UVM2_CYCLES_PER_FRAME;
#endif

static struct vx_timings vx_cart_timings(void)
{
    struct vx_timings k;
    k.e6809_q8 = 64u;
    k.y_mux_q8 = (uint32_t)(uvm2_y_mux_e > 0 ? uvm2_y_mux_e : 0) * 256u;
    k.moveto_settle_q8 = 0u;
    /* Sin signo: un beam_on negativo no significa nada (no se puede encender el haz
     * antes de arrancar la rampa), y dejarlo pasar daba la vuelta a ~4.000 millones. */
    k.beam_on_q8 = uvm2_beam_on_e > 0 ? (uint32_t)uvm2_beam_on_e * 256u : 0u;
    /* 16, NO los 11 del cartucho propio. AQUI SI hay calibracion por placa, y esta vez
     * con una medida detras: con 11 las esquinas del pentagono salen un poco abiertas —
     * el haz se apaga ANTES de terminar de llegar. 16 es el valor que Ralf midio para
     * ESTA placa (c_BlankOnDelay), y los 11 nuestros salieron de una biseccion en NUESTRA
     * consola, con otro camino de bus y otro amplificador.
     *
     * Es el termino que convierte los puntos brillantes en los vertices y las esquinas
     * abiertas en los dos extremos de un mismo knob. Se sube el grande primero y de uno
     * en uno; `beam_on` sigue en 2 (el suyo es 3) hasta que haga falta. */
    k.blank_settle_q8 = uvm2_blank_settle_e * 256;
    k.keep_lit = (uint32_t)(uvm2_keep_lit ? 1 : 0);
    k.x_settle_q8 = (uint32_t)(uvm2_x_settle_e > 0 ? uvm2_x_settle_e : 0) * 256u;
    return k;
}

/* TROCEAR LO QUE NO CABE EN UNA RAMPA — y esto faltaba entero.
 *
 * Una rampa expresa como mucho +-127 (vx_ramp_params hace clamp(-128,127)), pero
 * uvm2_draw_move/delta pasaban el delta CRUDO y ademas actualizaban s_pos con el valor
 * ENTERO. Resultado: todo movimiento o trazo de mas de 127 unidades se recortaba EN
 * SILENCIO y el modelo creia al haz en un sitio donde no estaba, para siempre.
 *
 * MEDIDO en el host el 2026-08-24 con hardware/uvm2/rejilla: una cuadricula escrita para
 * ocupar [-100..100] generaba un flujo de comandos que llevaba el haz a [-100..444] —
 * cuatro veces fuera de pantalla. En consola eso se ve como "dibuja la mitad, y pegado al
 * borde", que es lo que era.
 *
 * El SDK del RP2350 SI lo hacia ("splits >127 i8 chunks" en beam_draw_to). Este no: otra
 * divergencia entre los dos cartuchos que ningun numero delataba.
 *
 * EL REPARTO ES EXACTO. Los trozos suman el delta original al ultimo bit: se acumula la
 * posicion ideal y cada trozo es la diferencia contra lo ya emitido, asi que el error de
 * division no se acumula — que es justo lo que estabamos persiguiendo en el juego. */
#define UVM2_MAX_PASO 127

/* Lo que se le debe al dibujo, en MILESIMAS de unidad. Ver delta_una(). */
static int32_t s_res_x, s_res_y;

/* LO QUE LA RAMPA VA A RECORRER DE VERDAD, en milesimas: vx * t1 / DRAW_SCALE. Ni `dx` ni
 * `vx*t1/160` redondeado — el valor exacto con su fraccion, que es lo unico que permite
 * saber cuanto se debe. */
static int32_t recorrido_mil(int32_t v, uint32_t t1)
{
    return (int32_t)(((int64_t)v * (int64_t)t1 * 1000) / 160);
}


static void trocear(int dx, int dy, void (*emite)(int, int))
{
    int m = (dx < 0 ? -dx : dx);
    int my = (dy < 0 ? -dy : dy);
    if (my > m) m = my;
    if (m <= UVM2_MAX_PASO){ emite(dx, dy); return; }

    int n = (m + UVM2_MAX_PASO - 1) / UVM2_MAX_PASO;
    int hx = 0, hy = 0;                       /* lo ya emitido */
    for (int i = 1; i <= n; i++){
        int ox = (int)(((long long)dx * i) / n);   /* posicion ideal tras i trozos */
        int oy = (int)(((long long)dy * i) / n);
        emite(ox - hx, oy - hy);
        hx = ox; hy = oy;
    }
}

static void move_una(int dx, int dy)
{
    /* LA DEUDA MUERE AQUI. Un salto reestablece la posicion por su cuenta, asi que
     * arrastrarle el residuo de la cadena anterior seria corregir un error que ya no
     * existe — el mismo fallo que el acumulador de deriva que sobrevivia a un re-cero. */
    s_res_x = 0; s_res_y = 0;

    {
        int32_t vx, vy; uint32_t t1;
        s_pos_x += dx;
        s_pos_y += dy;
        vx_ramp_params(dx, dy, &vx, &vy, &t1);
        struct vx_sink sink = vx_cart_sink();
        struct vx_timings k = vx_cart_timings();
        vx_moveto_seq(&sink, vx, vy, t1, &k);
        uvm2_stats.moves++;
        uvm2_stats.ramp_cycles += t1;
    }
}

void uvm2_draw_move(int dx, int dy){ trocear(dx, dy, move_una); }


/* DIFUNDIR EL RESIDUO AL VECTOR SIGUIENTE, que es lo que hace exacta una CADENA aunque
 * cada trazo suelto no pueda serlo.
 *
 * `ramp_params` reparte un delta entre velocidad y tiempo, y las dos son ENTERAS: la
 * distancia real casi nunca es la pedida. El error de un trazo es despreciable, pero tiene
 * SIGNO CONSTANTE, asi que en una cadena se suma. MEDIDO en el host el 2026-08-24, 84
 * trazos encadenados de 33 unidades:
 *
 *     VCAP=127  +6,30 u de deriva (+2,5% de pantalla)     VCAP=32   0,00
 *     VCAP= 64 +16,80 u          (+6,6%)                  VCAP=21   0,00
 *
 * Y ESO EXPLICA LO QUE SE VEIA. A VCAP bajo `t1` topa en T1_TRANSPORT y vx*t1/160 sale
 * clavado; a VCAP alto no, y la cadena deriva. O sea que "a VCAP alto dibuja mal y rapido,
 * a VCAP bajo dibuja bien y lento" NO era el amplificador sin poder seguir al haz: era
 * nuestro redondeo, y bajar VCAP lo tapaba pagando 3,8 veces mas ciclos de rampa.
 *
 * Llevando la cuenta de lo que se debe y sumandoselo al siguiente, la cadena queda exacta
 * a cualquier VCAP y no cuesta un solo ciclo. Se pide `dx + debido`, se mira lo que la
 * rampa dara, y la diferencia queda anotada. */
static void delta_una(int dx, int dy)
{
    int32_t vx, vy; uint32_t t1;
    s_pos_x += dx;
    s_pos_y += dy;

    /* Se pide el delta MAS lo que se debia del anterior. El redondeo a entero es a la
     * proxima, no truncando: truncar reintroduce el sesgo que esto viene a quitar. */
    int px = dx + ((s_res_x >= 0 ? s_res_x + 500 : s_res_x - 500) / 1000);
    int py = dy + ((s_res_y >= 0 ? s_res_y + 500 : s_res_y - 500) / 1000);
    if (px > 127) px = 127; else if (px < -128) px = -128;
    if (py > 127) py = 127; else if (py < -128) py = -128;

    vx_ramp_params(px, py, &vx, &vy, &t1);

    /* Lo que se debe = lo que se queria menos lo que la rampa dara. Se acumula en
     * milesimas, y se acota: si un trazo se recorta (px saturado) la deuda no puede
     * crecer sin freno o el siguiente saldria disparado. */
    s_res_x += (int32_t)dx * 1000 - recorrido_mil(vx, t1);
    s_res_y += (int32_t)dy * 1000 - recorrido_mil(vy, t1);
    if (s_res_x >  4000) s_res_x =  4000; else if (s_res_x < -4000) s_res_x = -4000;
    if (s_res_y >  4000) s_res_y =  4000; else if (s_res_y < -4000) s_res_y = -4000;

    struct vx_sink sink = vx_cart_sink();
    struct vx_timings k = vx_cart_timings();
    vx_draw_line_seq(&sink, vx, vy, t1, &k);
    uvm2_stats.vectors++;
    uvm2_stats.ramp_cycles += t1;
}

void uvm2_draw_delta(int dx, int dy){ trocear(dx, dy, delta_una); }

/* UNA RECTA CON HUECOS, EN UNA SOLA RAMPA.
 *
 * `huecos` son pares (inicio, fin) en FRACCIONES 0..255 del vector, no en cuentas de T1:
 * quien llama sabe donde empieza y acaba un tramo tapado a lo largo de la recta, y no
 * tiene por que saber nada de T1. La conversion es de aqui.
 *
 * Partir la recta en trozos cuesta una rampa por trozo —dos DAC, la cuenta de T1, abrir y
 * cerrar—; esto la programa UNA vez y solo conmuta el BLANK por el camino.
 */
void uvm2_draw_delta_patterned(int dx, int dy, const unsigned char *huecos, int n)
{
    int32_t vx, vy; uint32_t t1;
    s_pos_x += dx;
    s_pos_y += dy;
    vx_ramp_params(dx, dy, &vx, &vy, &t1);
    struct vx_sink sink = vx_cart_sink();
    struct vx_timings k = vx_cart_timings();

    /* fracciones -> cuentas de T1. Un hueco que al redondear se queda en cero no se emite:
     * costaria dos escrituras de bus y no apagaria nada. */
    enum { MAX = 16 };
    uint16_t cuentas[MAX * 2];
    int m = 0;
    for (int i = 0; i < n && m < MAX; i++){
        uint32_t a = ((uint32_t)huecos[i*2]     * t1) >> 8;
        uint32_t b = ((uint32_t)huecos[i*2 + 1] * t1) >> 8;
        if (b > t1) b = t1;
        if (b <= a) continue;
        cuentas[m*2] = (uint16_t)a; cuentas[m*2 + 1] = (uint16_t)b; m++;
    }
    if (m == 0) vx_draw_line_seq(&sink, vx, vy, t1, &k);
    else        vx_draw_line_patterned_seq(&sink, vx, vy, t1, &k, cuentas, (uint32_t)m);
    uvm2_stats.vectors++;
    uvm2_stats.ramp_cycles += t1;
}

void uvm2_draw_move_abs(int x, int y)
{
    int dx = x - s_pos_x;
    int dy = y - s_pos_y;
    if (dx == 0 && dy == 0) return;
    uvm2_draw_move(dx, dy);
}

/* ── Frame ────────────────────────────────────────────────────────────────── */

/* ---- Recalibrate ($F2E6) — LA RUTINA QUE ESTE SDK TAMPOCO TENIA -------------
 *
 * La BIOS original la llama CADA FRAME desde `Wait_Recal` ($F192), y no es un cero
 * pasivo:
 *
 *     Recalibrate:  LDX #Recal_Points   ; $7F7F,$8080
 *                   BSR Moveto_ix_FF    ; escala $FF, mover a (+127,+127)
 *                   JSR Reset0Int       ; integradores a cero
 *                   BSR Moveto_ix       ; mover a (-128,-128), MISMA escala $FF
 *                   BRA Reset0Ref
 *
 * Barre los integradores a los DOS railes y los anula en medio. Este SDK solo hacia
 * el equivalente de `Reset0Ref` (`uvm2_draw_reset`), que pone a cero la REFERENCIA
 * pero no drena nada: si queda carga residual, ahi se queda.
 *
 * POR QUE SE TRANSCRIBE AQUI. En el cartucho propio esto mismo, el 2026-08-17, era
 * la causa de que TODO se fuera acumulando: el dibujo colapsaba hacia Y = 0 y
 * perdia intensidad, y los 33 tests VPy eran inservibles. Con la consola una hora
 * apagada el primer arranque salia limpio y los siguientes no — una hora sin
 * corriente era el unico drenaje que teniamos. Con `Recalibrate` puesta, resuelto.
 *
 * Este SDK no tenia ni una referencia a $7F7F ni a Recalibrate, asi que arrastra el
 * mismo agujero. Y encaja con el parpadeo del UVM2 que sigue sin explicarse.
 *
 * ESCALA MAXIMA A PROPOSITO. La BIOS pide $FF y no vale usar la escala en curso:
 * una rampa mas corta no lleva el integrador hasta el rail, que es justo el punto
 * del ejercicio. Por eso se guarda `s_scale`, se fuerza 255 y se restaura.
 *
 * Cuesta dos movimientos a escala maxima por frame. Si hiciera falta medirlo,
 * -DUVM2_NO_RECALIBRATE lo quita.
 */
#ifndef UVM2_NO_RECALIBRATE
/* Un movimiento a escala FIJA, al margen del modelo de haz: los dos necesitan lo
 * mismo aqui —barrer el integrador hasta el rail— y ninguno debe elegir la duracion.
 * Con T1 activo la rampa la termina el 6522; sin el, PB7 a mano como el resto de ese
 * camino. */
static void recal_move(int dx, int dy)
{
    set_y(dy, UVM2_HOLD_DELAY);
    set_x(dx, UVM2_HOLD_DELAY);
    /* La rampa la termina T1, no PORTB: con ACR = 0x80 los bits de PORTB que tocan PB7
     * ya no llegan al pin, asi que un `set_ramp` aqui seria un no-op silencioso y el
     * barrido a los railes —que es TODO el ejercicio de Recalibrate— no ocurriria. */
    emit(UVM2_VIA_T1CL, 255u, 0);
    emit(UVM2_VIA_T1CH, 0u, 255u + UVM2_BLANK_ON_DELAY);
}

static void uvm2_recalibrate(void)
{
    /* INVALIDAR LAS CACHES ANTES DE BARRER, y esto no es precaucion: es un fallo medido.
     *
     * `set_y` y `set_porta` se saltan la escritura si creen que el DAC ya tiene ese
     * valor. Con el modelo compartido lo que se escribe al DAC es una VELOCIDAD, y esa
     * se satura en +-127 continuamente —todo vector con |delta| >= 32 da vx = 127—, asi
     * que la cache cree muy a menudo que ya vale 127 y SE SALTA el movimiento al rail.
     *
     * Y el movimiento al rail es TODO el ejercicio de Recalibrate. Sin el, la referencia
     * de cero no se restablece y el error se acumula frame a frame: el dibujo se va
     * descolocando, que es exactamente el sintoma que llevamos toda la tarde viendo.
     *
     * La cache es de la placa; la saturacion es del modelo. Ninguna de las dos esta mal
     * sola — juntas se comen la recalibracion. */
    uvm2_draw_invalidate();
    uvm2_stats.recals++;

    const uint32_t escala = s_scale;
    /* $FF EXPLICITO, y por eso NO puede pasar por `uvm2_draw_move`: con el modelo T1
     * activo ese camino calcularia su propia t1 a partir de la longitud, y una rampa
     * mas corta no lleva el integrador hasta el rail — que es justo el punto del
     * ejercicio. Misma razon por la que el firmware tiene `recal_moveto` aparte de
     * `moveto`. */
    s_scale = 255u;                       /* Moveto_ix_FF: LDB #$FF / STB t1_cnt_lo */

    /* Los dos puntos son ABSOLUTOS en la BIOS ($7F7F y $8080), y aqui los
     * movimientos son relativos: se va al rail y se cruza al contrario, que es el
     * mismo recorrido — la ida completa y la vuelta completa. */
    recal_move(127, 127);                 /* -> (+127, +127) */

    /* Reset0Int ($F36C): LDD #$00CC / STB cntl / STA shift. Aqui es la pinza de
     * cero, que es lo que ese 0xCC enciende. */
    set_zero(1, UVM2_HOLD_DELAY);
    set_zero(0, UVM2_HOLD_DELAY);

    recal_move(-128, -128);               /* -> (-128, -128), misma escala */

    s_scale = escala;
    uvm2_draw_reset();                    /* Reset0Ref */
}
#endif

/* RETARDO ARTIFICIAL ENTRE FRAMES, para separar el TIEMPO de la PSRAM.
 *
 * Con la lista en la PSRAM el dibujo colapsa a x=y, y ya esta descartado todo lo demas: el
 * dato es identico byte a byte (firmado en los dos extremos), el tiempo por vector es el
 * mismo, la fase es correcta, los dos nucleos son inocentes y durante el dibujo no hay ni
 * un acceso al chip. Lo UNICO que cambia es que escribir la lista alli cuesta ~6,9 ms por
 * frame — medido: periodo 20097 us contra 13200 de bus.
 *
 * Asi que se reproduce ese hueco SIN PSRAM. Si colapsa igual, la PSRAM es inocente y la
 * causa es el hueco entre frames; si dibuja, el hueco es inocente y hay que volver al chip.
 * Una imagen, una lectura, y una rama entera cerrada.
 *
 *     make uvm2 UVM2_RETARDO_US=6900
 */
#ifdef UVM2_RETARDO_US
static void retardo_artificial(void)
{
    const uint32_t t0 = *(volatile uint32_t *)0x400B000Cu;   /* TIMER0 TIMELR */
    while ((*(volatile uint32_t *)0x400B000Cu - t0) < (uint32_t)UVM2_RETARDO_US) { }
}
#endif

void uvm2_frame_begin(void)
{
    s_count = 0;
    s_dropped              = 0;
    uvm2_stats.vectors     = 0;
    uvm2_stats.moves       = 0;
    uvm2_stats.ramp_cycles = 0;

    /* Re-programme the VIA and re-prime the holds, with the zero clamp still
     * asserted — see via_setup().  UVM2_NO_FRAME_SETUP goes back to priming
     * once at boot, for A/B testing. */
#ifndef UVM2_NO_FRAME_SETUP
    via_setup();
#endif

    /* Reponer la intensidad ANTES de soltar la pinza, como el escritor de Ralf:
     *
     *     commandWriter.SetZ(0x5F);
     *     commandWriter.SetZero(false);
     *
     * via_setup() acaba de cebar Z a 0, y el juego no pondra la suya hasta su
     * primer SET_INTENSITY. Entre esas dos cosas hay comandos que corren con la
     * pinza ya suelta y con Z en un valor que no eligio nadie. */
    set_z(s_z_last, UVM2_HOLD_DELAY);

    /* Only now release the clamp that has held the beam at centre since the
     * last frame ended.  The clamp covers the whole inter-frame gap and the
     * priming above, so no drift reaches the screen and the holds are charged
     * against a beam that is actually at zero. */
#ifndef UVM2_HOLD_ZERO
    set_zero(0, 0);
#endif
}

/* Por BUFFER, no una sola: con doble buffer core 0 firma el frame que acaba de
 * construir y core 1 reproduce el ANTERIOR. Comparar las dos sin indexar es
 * comparar frames distintos, que nunca coinciden y no dice nada. */
uint32_t uvm2_firma_escrita[2], uvm2_firma_n[2];

void uvm2_frame_end(void)
{
    uint32_t cycles = 0;

    /* APAGAR EXPLICITAMENTE, no darlo por hecho. Aqui decia "blanked already
     * (every lit segment restores the PCR)", que es una SUPOSICION: solo se
     * cumple si el frame termino en un segmento iluminado. Un frame sin dibujo,
     * o que acabe en un movimiento, o en texto, sale de aqui con el haz como
     * estuviera. Ralf no lo supone: emite SetBlank(true) al cerrar cada frame.
     * Cuesta un comando. */
    s_pcr = (uint8_t)(s_pcr & ~UVM2_PCR_BLANK_OFF);
    emit(UVM2_VIA_PCR, s_pcr, 0);

    /* RECALIBRAR, con el haz ya apagado y antes de pinzar. Es donde la BIOS la
     * tiene: `Recalibrate` es lo ultimo de `Wait_Recal`, o sea trabajo del CIERRE
     * del frame. Ver el bloque de uvm2_recalibrate. */
#ifndef UVM2_NO_RECALIBRATE
    uvm2_recalibrate();
#endif

    /* Y ahora si, pinzar el haz en el centro: un integrador parado deriva, y un
     * haz que deriva es un punto brillante quemado en mitad de la pantalla. */
    set_zero(1, UVM2_ZERO_BASE + s_scale / 4u);
    s_pos_x = 0;
    s_pos_y = 0;

#ifdef UVM2_DUAL_CORE
    /* Hand the finished list to core 1 and go straight back to the game.  The
     * replay, the input, the audio and the 50 Hz pacing all happen over there
     * now (uvm2_core1.c), so the game's next frame of logic overlaps the beam
     * still drawing this one. */
    /* SUMA DE COMPROBACION EN LOS DOS EXTREMOS, para no tener que adivinar.
     *
     * Con la lista en la PSRAM el dibujo colapsa a una diagonal x=y, y la lista es correcta
     * en contenido y en tiempos (7,6 ciclos de bus por comando, la misma proporcion que la
     * version que dibuja bien). Quedan dos causas opuestas: que lo que LEE core 1 no sea lo
     * que ESCRIBIO core 0 —coherencia— o que el dato sea bueno y el problema sea cuando
     * llega. Aqui se firma lo escrito; en uvm2_core1.c se firma lo leido justo antes de
     * reproducirlo. Si las firmas coinciden, la coherencia queda descartada de una vez. */
    {
        /* POR EL ALIAS SIN CACHE. Firmar por la ventana normal lee la cache del XIP, que
         * acaba de escribirse: la firma sale bien SIEMPRE y no dice nada del chip. Son 16
         * KB de cache contra una lista de 64-128 KB, asi que lo que se reproduce despues
         * viene en su mayoria de la PSRAM y puede ser otra cosa. Esa confusion ya invalido
         * una prueba entera aqui, y antes la del cargador. */
        /* Sin traducir: la lista ya vive en el alias sin cache. */
        const volatile uint8_t *lista = (const volatile uint8_t *)&s_cmds[s_buf][0];
        uint32_t h = 2166136261u;
        for (uint32_t i = 0; i < s_count * 3u; i++) { h ^= lista[i]; h *= 16777619u; }
        uvm2_firma_escrita[s_buf & 1u] = h;
        uvm2_firma_n[s_buf & 1u]       = s_count;
#ifdef UVM2_CMDS_IN_PSRAM
        /* LA MISMA CUENTA, LOS DOS LADOS. `h` es lo que el CHIP devuelve al releer la lista
         * por el alias sin cache; uvm2_firma_emitida es lo que emit() mando escribir. Si no
         * coinciden, las escrituras no aguantan con el stream, el DMA y el bus en marcha —
         * que es la unica diferencia entre el test psramrw (CERO fallos, maquina en
         * silencio) y el juego (que colapsa). */
        uvm2_firma_releida = h;
        uvm2_firma_vueltas++;
        if (h != uvm2_firma_emitida) uvm2_firma_malas++;
#endif
    }

    s_len[s_buf]        = s_count;
    uvm2_stats.commands = s_count;
    uvm2_stats.dropped  = s_dropped;

    uvm2_stats.vectors_last     = uvm2_stats.vectors;
    uvm2_stats.moves_last       = uvm2_stats.moves;
    uvm2_stats.ramp_cycles_last = uvm2_stats.ramp_cycles;

    s_count = 0;
#ifdef UVM2_CMDS_IN_PSRAM
    uvm2_firma_emitida = 2166136261u;
#endif
    s_frames++;
#ifdef UVM2_CMDS_IN_PSRAM
    uvm2_firma_emitida = 2166136261u;
#endif

    __asm volatile ("dmb" ::: "memory");   /* the buffer and its length, then the flag */
    uvm2_frame_request = s_frame_no;

    /* Next we fill the OTHER buffer, which core 1 last replayed for frame n-1.
     * Block until it has finished with it — this is the only place core 0 ever
     * waits, and it waits at most one frame. */
    /* ¿QUIEN MANDA, EL HAZ O LA LOGICA? Esta es la unica espera de core 0, y su
     * duracion lo dice sin ambiguedad: si espera mucho, core 1 va justo y manda el
     * haz; si no espera nada, core 1 esta ocioso y manda la logica del juego.
     * Se cuentan vueltas, no tiempo: solo hace falta comparar. */
    {
        uint32_t giros = 0;
        while ((int32_t)(uvm2_frame_done - (s_frame_no - 1u)) < 0) { giros++; }
        uvm2_stats.wait_spins = giros;
    }

    s_frame_no++;
    s_buf = s_frame_no & 1u;
    (void)cycles;
    return;
#else
#ifdef UVM2_CMDS_STAGE_SRAM
    /* CONTROL, tambien en un solo nucleo. La copia estaba SOLO en uvm2_core1.c, que no se
     * compila sin doble nucleo — asi que la perilla no hacia nada y una prueba entera se
     * fue en comparar una imagen consigo misma. Aqui la lista vive en la PSRAM pero se
     * reproduce desde SRAM, sin un solo acceso al chip externo durante el dibujo y sin otro
     * nucleo escribiendo por detras. */
    {
        static uint8_t s_stage[UVM2_CMD_CAPACITY * 3u];
        for (uint32_t i = 0; i < s_count * 3u && i < UVM2_CMD_CAPACITY * 3u; i++)
            s_stage[i] = s_cmds[s_buf][i];
#ifdef UVM2_CMDS_IN_PSRAM
        /* EL ULTIMO ESLABON SIN COMPROBAR. Ya sabemos que emit() -> PSRAM llega bien (4890
         * de 4891 frames). Falta PSRAM -> copia, que es lo que de verdad alimenta al
         * ejecutor en esta imagen. Si la copia no coincide con lo emitido, la lectura del
         * chip se estropea aunque la escritura sea buena — y eso es otra averia distinta. */
        {
            uint32_t h = 2166136261u;
            for (uint32_t i = 0; i < s_count * 3u; i++) { h ^= s_stage[i]; h *= 16777619u; }
            uvm2_firma_copia = h;
            uvm2_firma_copia_vueltas++;
            if (h != uvm2_firma_emitida) uvm2_firma_copia_malas++;
        }
#endif
        cycles = uvm2_exec(s_stage, s_count);
    }
#else
    cycles = uvm2_exec(s_cmds[s_buf], s_count);
#endif

    uvm2_stats.commands   = s_count;
    uvm2_stats.bus_cycles = cycles;
    uvm2_stats.dropped    = s_dropped;
#endif

    /* Freeze this frame's per-frame counters where a debugger can still read them
     * once uvm2_frame_begin has cleared the live ones. */
    uvm2_stats.vectors_last     = uvm2_stats.vectors;
    uvm2_stats.moves_last       = uvm2_stats.moves;
    uvm2_stats.ramp_cycles_last = uvm2_stats.ramp_cycles;

    s_count = 0;
#ifdef UVM2_CMDS_IN_PSRAM
    uvm2_firma_emitida = 2166136261u;
#endif
    s_frames++;
#ifdef UVM2_CMDS_IN_PSRAM
    uvm2_firma_emitida = 2166136261u;
#endif

    /* Lock the frame to the Vectrex clock rather than to an RP2350 timer:
     * 1.5 MHz / 50 Hz = 30000 bus cycles exactly.  The clamp stays asserted
     * through the wait; uvm2_frame_begin() releases it. */
    /* EL ENGANCHE, EN TIEMPO DE EJECUCION. Era `#if UVM2_HZ`, o sea un flasheo por valor
     * para responder a una pregunta de segundos.
     *
     * Y LA PREGUNTA IMPORTA. Observado en consola el 2026-08-24 sobre la rejilla, con la
     * geometria QUIETA: subiendo X_SETTLE —que solo cambia TIEMPOS— el temblor se hace mas
     * RAPIDO. Eso no es temblor, es un BATIDO: la imagen se redibuja a F y algo periodico
     * pasa a G fija, y lo que se ve moverse es |F - G|. El sospechoso de G son los 50 Hz de
     * la red sobre la fuente y el amplificador de deflexion — encaja ademas con que sea
     * casi todo horizontal, porque el rizado no acopla igual en los dos ejes.
     *
     * Si es eso, ENGANCHAR el dibujo a 50 Hz deja el rizado en la misma fase cada frame y
     * el desplazamiento pasa de moverse a ser un sesgo fijo, o sea invisible. Con el
     * enganche puesto hay que asegurarse ademas de que el dibujo CABE: un frame que se pasa
     * pierde el enganche y dura 40 ms, y alternar 20 y 40 ms tiembla por otro camino.
     *
     * 0 = libre (Asteroids). != 0 = enganchado a ese periodo en ciclos de bus. */
    if (uvm2_pacer_cycles == 0) {
        s_frame_cycles = cycles;
    } else if (cycles < uvm2_pacer_cycles) {
        uvm2_bus_delay(uvm2_pacer_cycles - cycles);
        s_frame_cycles = uvm2_pacer_cycles;
    } else {
        uvm2_stats.overrun++;
        s_frame_cycles = cycles;
    }

    /* EL PERIODO REAL DEL FRAME, en microsegundos de reloj de pared.
     *
     * Se toma al FINAL, de un frame_end al siguiente, para que incluya lo unico que no mide
     * nadie: el tiempo que el juego pasa emulando entre frames. Ver el comentario de
     * us_frame_* en uvm2_bus.h.
     *
     * TIMELR del TIMER0 en crudo (0x400B000C): 32 bits de microsegundos, de sobra para una
     * diferencia entre frames, y sin arrastrar pico/time.h a un fichero que vive en SRAM.
     *
     * Los 60 primeros frames NO cuentan: al arrancar hay carga de ROM, pantallas de
     * atencion y el propio cargador, y esa basura se queda en el minimo y el maximo para
     * siempre. Ya paso una vez con las estadisticas sembradas desde el arranque. */
    {
        static uint32_t s_us_prev;
        static uint32_t s_calentando = 60;
#ifdef UVM2_HOST
        const uint32_t ahora = 0;   /* no TIMER0 in a host harness — see tools/ */
#else
        const uint32_t ahora = *(volatile uint32_t *)0x400B000Cu;
#endif

        if (s_calentando) {
            s_calentando--;
            uvm2_stats.us_frame_min = 0xFFFFFFFFu;
        } else {
            const uint32_t d = ahora - s_us_prev;
            uvm2_stats.us_frame_last = d;
            uvm2_stats.frames_medidos++;
            if (d < uvm2_stats.us_frame_min) uvm2_stats.us_frame_min = d;
            if (d > uvm2_stats.us_frame_max) {
                uvm2_stats.us_frame_max     = d;
                uvm2_stats.vectores_en_max  = uvm2_stats.vectors_last;
            }
            if (d > 20500u) uvm2_stats.frames_lentos++;
        }
        s_us_prev = ahora;
    }

#ifdef UVM2_RETARDO_US
    retardo_artificial();
#endif
}

#ifdef UVM2_RETARDO_US
/* Al final del cierre de frame, que es donde cae el coste de escribir en la PSRAM. */
#endif

uint32_t uvm2_frame_bus_cycles(void) { return s_frame_cycles; }

uint32_t uvm2_frame_count(void) { return s_frames; }
