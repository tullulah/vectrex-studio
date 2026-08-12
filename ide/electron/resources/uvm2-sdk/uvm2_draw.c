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

/* His buffer is 8K words per frame; a full screen of vectors is far below that
 * (a vector is ~8 commands, and a 50 Hz frame only affords ~220 vectors). */
#define UVM2_CMD_CAPACITY  8192u

/* One buffer single-core, two when core 1 replays: core 0 fills the buffer for
 * frame n while core 1 is still replaying frame n-1.  Single-core builds keep
 * exactly one, so nothing grows for a target that does not use it. */
#ifdef UVM2_DUAL_CORE
#  define UVM2_NBUF 2u
#else
#  define UVM2_NBUF 1u
#endif
static uint32_t s_cmds[UVM2_NBUF][UVM2_CMD_CAPACITY];
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

const uint32_t *uvm2_frame_buffer(uint32_t frame) { return s_cmds[frame & 1u]; }
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

static inline void emit(uint32_t reg, uint32_t data, uint32_t delay)
{
    if (s_count < UVM2_CMD_CAPACITY) s_cmds[s_buf][s_count++] = UVM2_CMD(reg, data, delay);
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

static void set_zero(int active, uint32_t delay)
{
    s_pcr = (uint8_t)((s_pcr & ~UVM2_PCR_ZERO_OFF) | (active ? 0u : UVM2_PCR_ZERO_OFF));
    emit(UVM2_VIA_PCR, s_pcr, delay);
}

static void set_ramp(int running, uint32_t delay)
{
    s_portb = (uint8_t)((s_portb & ~UVM2_PB_RAMP_OFF) | (running ? 0u : UVM2_PB_RAMP_OFF));
    emit(UVM2_VIA_PORTB, s_portb, delay);
}

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
    emit(UVM2_VIA_ACR,   0x60,    0);

    /* Prime each sample/hold channel from a DAC value of 0: zero reference,
     * then Y, then Z.  Without this the integrators start wherever the analog
     * section powered up. */
    set_porta(0x00, 0);
    mux_sample(UVM2_MUX_ZEROREF, UVM2_HOLD_DELAY);
    mux_sample(UVM2_MUX_Y,       UVM2_HOLD_DELAY);
    mux_sample(UVM2_MUX_Z,       UVM2_HOLD_DELAY);

    s_y = 0; s_z = 0; s_pos_x = 0; s_pos_y = 0;
}

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

void uvm2_draw_move(int dx, int dy)
{
    uint32_t s = s_scale;

    s_pos_x += dx;
    s_pos_y += dy;
    fixup(&dx, &dy, &s);

    set_y(dy, UVM2_HOLD_DELAY);
    set_x(dx, UVM2_HOLD_DELAY);

    set_ramp(1, s);                       /* integrators run for s cycles */
    set_ramp(0, UVM2_HOLD_DELAY);         /* and settle                   */

    uvm2_stats.moves++;
    uvm2_stats.ramp_cycles += s;
}

void uvm2_draw_delta(int dx, int dy)
{
    uint32_t s = s_scale;
    uint8_t  lit;

    s_pos_x += dx;
    s_pos_y += dy;
    fixup(&dx, &dy, &s);

    set_y(dy, UVM2_HOLD_DELAY);
    set_x(dx, UVM2_HOLD_DELAY);

    lit = (uint8_t)(s_pcr | UVM2_PCR_BLANK_OFF);

    /* Start the ramp, light the beam a few cycles later so the integrators are
     * already moving, ramp for the rest, then stop and blank.  The beam stays
     * lit briefly after the ramp stops — that trailing window is what makes the
     * segment end cleanly instead of fading early. */
    s_portb = (uint8_t)(s_portb & ~UVM2_PB_RAMP_OFF);
    emit(UVM2_VIA_PORTB, s_portb, UVM2_BLANK_OFF_DELAY);
    emit(UVM2_VIA_PCR,   lit,     s - UVM2_BLANK_OFF_DELAY);
    s_portb = (uint8_t)(s_portb | UVM2_PB_RAMP_OFF);
    emit(UVM2_VIA_PORTB, s_portb, UVM2_BLANK_ON_DELAY);
    emit(UVM2_VIA_PCR,   s_pcr,   0);

    uvm2_stats.vectors++;
    uvm2_stats.ramp_cycles += s;
}

void uvm2_draw_move_abs(int x, int y)
{
    int dx = x - s_pos_x;
    int dy = y - s_pos_y;
    if (dx == 0 && dy == 0) return;
    uvm2_draw_move(dx, dy);
}

/* ── Frame ────────────────────────────────────────────────────────────────── */

void uvm2_frame_begin(void)
{
    s_count = 0;
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
    s_len[s_buf]        = s_count;
    uvm2_stats.commands = s_count;

    uvm2_stats.vectors_last     = uvm2_stats.vectors;
    uvm2_stats.moves_last       = uvm2_stats.moves;
    uvm2_stats.ramp_cycles_last = uvm2_stats.ramp_cycles;

    s_count = 0;
    s_frames++;

    __asm volatile ("dmb" ::: "memory");   /* the buffer and its length, then the flag */
    uvm2_frame_request = s_frame_no;

    /* Next we fill the OTHER buffer, which core 1 last replayed for frame n-1.
     * Block until it has finished with it — this is the only place core 0 ever
     * waits, and it waits at most one frame. */
    while ((int32_t)(uvm2_frame_done - (s_frame_no - 1u)) < 0) { }

    s_frame_no++;
    s_buf = s_frame_no & 1u;
    (void)cycles;
    return;
#else
    cycles = uvm2_exec(s_cmds[s_buf], s_count);

    uvm2_stats.commands   = s_count;
    uvm2_stats.bus_cycles = cycles;
#endif

    /* Freeze this frame's per-frame counters where a debugger can still read them
     * once uvm2_frame_begin has cleared the live ones. */
    uvm2_stats.vectors_last     = uvm2_stats.vectors;
    uvm2_stats.moves_last       = uvm2_stats.moves;
    uvm2_stats.ramp_cycles_last = uvm2_stats.ramp_cycles;

    s_count = 0;
    s_frames++;

    /* Lock the frame to the Vectrex clock rather than to an RP2350 timer:
     * 1.5 MHz / 50 Hz = 30000 bus cycles exactly.  The clamp stays asserted
     * through the wait; uvm2_frame_begin() releases it. */
    if (cycles < UVM2_CYCLES_PER_FRAME) {
        uvm2_bus_delay(UVM2_CYCLES_PER_FRAME - cycles);
        s_frame_cycles = UVM2_CYCLES_PER_FRAME;
    } else {
        uvm2_stats.overrun++;
        s_frame_cycles = cycles;
    }
}

uint32_t uvm2_frame_bus_cycles(void) { return s_frame_cycles; }

uint32_t uvm2_frame_count(void) { return s_frames; }
