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

/* El conmutador de modelo de haz se declara aqui porque `via_setup` elige ACR con el,
 * y esta antes del bloque que lo define. Ver "MODELO DE HAZ POR T1", mas abajo. */
extern volatile int uvm2_beam_model;

/* Comandos perdidos en el frame en curso, por lista llena. Se vuelca a stats en
 * frame_end. Declarada aqui y no abajo porque emit() es quien la incrementa. */
static uint32_t s_dropped;

static inline void emit(uint32_t reg, uint32_t data, uint32_t delay)
{
    if (s_count < UVM2_CMD_CAPACITY) s_cmds[s_buf][s_count++] = UVM2_CMD(reg, data, delay);
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

/* Con que modelo se programo el ACR por ultima vez. -1 = todavia con ninguno. */
static int s_acr_model = -1;

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
    /* ACR ES PARTE DEL MODELO DE HAZ, no un valor fijo:
     *   0x60 -> T1 en carrera libre con PB7 DESACTIVADO. /RAMP lo conmuta el
     *           software escribiendo PORTB bit 7 (el camino de Ralf).
     *   0x80 -> T1 en un disparo CON salida por PB7. Escribir T1CH baja /RAMP y el
     *           agotarse la cuenta lo sube: la rampa la termina el 6522. Es lo que
     *           programa la BIOS original y lo que hace nuestro firmware.
     * Con 0x80 los bits de PORTB que tocan PB7 dejan de llegar al pin, asi que
     * `set_ramp` no hace nada — por eso el camino T1 no lo llama. */
    s_acr_model = uvm2_beam_model;
    emit(UVM2_VIA_ACR,   uvm2_beam_model ? 0x80 : 0x60, 0);

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

/* ── MODELO DE HAZ POR T1, transcrito de nuestro firmware ───────────────────
 *
 * Los dos cartuchos NO dibujan igual, y hasta ahora eso estaba sin escribir:
 *
 *   Ralf (arriba):  /RAMP se conmuta A MANO por PORTB bit 7, y la longitud del
 *                   trazo la mide un retardo contado en la propia cadena de
 *                   comandos (`s_scale`). ACR = 0x60: T1 con PB7 DESACTIVADO.
 *
 *   Nuestro:        se calcula por vector la velocidad (vx, vy) y un contador t1,
 *                   se cargan en T1 de la VIA y **es el 6522 quien termina la
 *                   rampa**, por hardware, a traves de PB7. ACR = 0x80. Es como
 *                   lo hace la BIOS original.
 *
 * POR QUE PUEDE IMPORTAR AQUI. Con T1 la duracion de la rampa la marca el reloj
 * del 6522, no la exactitud con la que nuestro ejecutor de comandos cuente el
 * retardo. Todo jitter del lado del RP2350 deja de traducirse en longitud de
 * trazo. Dado que el UVM2 parpadea y que `uvm2-frame-budget` dice que la rampa se
 * lleva el 51% del presupuesto, es la hipotesis que merece medirse.
 *
 * PERO NO SE REEMPLAZA NADA. Los dos modelos conviven y se elige en caliente con
 * `uvm2_beam_model`, para poder ir cambiando poco a poco y, sobre todo, para poder
 * comparar A/B en la MISMA consola sin reflashear. Ver
 * `debug_cart/UVM2_UNIFICACION.md`.
 *
 *   uvm2_beam_model = 0  -> el de siempre (Ralf). POR DEFECTO: nada cambia.
 *                     1  -> el nuestro, por T1.
 *
 * SIN PROBAR EN ESTA CONSOLA. Compila; nadie lo ha encendido con model = 1.
 */
/* El valor de ARRANQUE tambien por compilacion, no solo por SWD. Si la sonda no
 * aparece —y hoy no aparece— se puede al menos cargar dos .um2 y comparar cambiando
 * de fichero en la SD. Es peor (hay un reset entre medidas, y una medida de fps entre
 * resets no vale), pero responde "¿dibuja siquiera?" sin depender del cable.
 *     ./build_uvm2.sh dkong dkt1_m1 -DUVM2_BEAM_MODEL_DEFAULT=1  */
#ifndef UVM2_BEAM_MODEL_DEFAULT
#define UVM2_BEAM_MODEL_DEFAULT 0
#endif
volatile int uvm2_beam_model = UVM2_BEAM_MODEL_DEFAULT;

/* Los knobs de `ramp_params`, con los valores que quedaron por defecto en el
 * cartucho propio el 2026-08-17 tras medirlos en pantalla. Variables y no defines
 * a proposito: se barren por SWD sin recompilar, que es la regla 3 de `hw-debug`.
 *
 * NO son constantes universales. `una-consola-no-es-evidencia`: VCAP se afino
 * contra una consola quemada y otra maquina quiere otro valor. Aqui llegan como
 * PUNTO DE PARTIDA, no como verdad. */
volatile int uvm2_t1_draw_scale = 0xA0;  /* DRAW_SCALE: gobierna longitud Y velocidad */
volatile int uvm2_t1_min        = 31;    /* MIN_T1                                    */
volatile int uvm2_t1_ceiling    = 0xA0;  /* T1_CEILING                                */
volatile int uvm2_t1_vcap       = 127;   /* VCAP                                      */
volatile int uvm2_t1_vcap_slow  = 30;    /* VCAP_SLOW: tope para el zigzag            */
volatile int uvm2_t1_vcap_dv    = 32;    /* VCAP_DV: longitud maxima que cuenta corta */
volatile int uvm2_t1_extra_q8   = 0;     /* T1_EXTRA_Q8: el 6522 cuenta t1 + 1,5      */

/* LOS DOS RETARDOS DEL HAZ, en nuestros valores y en ciclos de E.
 *
 * Conversion, sin inventarse el factor: el firmware los lleva en ciclos de CPU y
 * define CPU_PER_ECYCLE = 100 (un periodo de E, 666 ns a 1,5 MHz, son ~100 ciclos a
 * 150 MHz). Ademas tiene escrito BLANK_SETTLE_REFERENCE = 16 * CPU_PER_ECYCLE, que
 * es literalmente el c_BlankOnDelay de Ralf en nuestras unidades, asi que la
 * equivalencia esta comprobada en los dos sentidos.
 *
 *     BEAM_ON_DELAY_CYC  =  200 ciclos de CPU  ->  2 ciclos de E   (aqui habia 3)
 *     BLANK_SETTLE_CYC   = 1100 ciclos de CPU  -> 11 ciclos de E   (aqui habia 16)
 *
 * NO SON LA MISMA CANTIDAD, y por eso son dos knobs y no uno. MEDIDO por biseccion
 * en nuestra consola el 2026-08-07, en el menu (estatico, vectores cortos), mirando
 * cuando se abren las esquinas del recuadro: encender pide el codo entre 50 y 60
 * ciclos, apagar entre 125 y 150. Encender necesita 2,5 veces menos, y tiene sentido
 * fisico — arrancar el haz desde parado y frenarlo contra la inductancia del yugo no
 * son el mismo transitorio. Ralf apunta en la misma direccion con su 3 / 16, aunque
 * su razon sea 5:1.
 *
 * OJO CON EL 11: los valores enviados NO son el codo. Por debajo de ~200 ciclos de
 * CPU el dibujo TIEMBLA cada vez mas, mucho antes del codo, porque al encender antes
 * la parte iluminada incluye el arranque del haz y ahi la posicion depende de CUANDO
 * exactamente encendimos — jitter NUESTRO. En el UVM2 el retardo lo cuenta el
 * ejecutor de comandos, que es otro reloj y otro jitter: puede que aqui aguante
 * menos, o mas. Son el punto de partida para barrer, no un resultado importado.
 *
 * Se dejan como variables del MODELO T1 y no se tocan los #define de arriba: asi el
 * modelo 0 sigue siendo el de Ralf integro y la comparacion A/B sigue valiendo. */
volatile int uvm2_t1_beam_on      = 2;   /* BEAM_ON_DELAY_CYC 200 / 100 */
volatile int uvm2_t1_blank_settle = 11;  /* BLANK_SETTLE_CYC 1100 / 100 */
volatile uint32_t uvm2_t1_vcap_slow_hits;

/* vy del vector anterior, para el disparador del tope selectivo. Bit 8 = valido,
 * igual que `Y_HELD` en el firmware. */
static int s_y_held = 0;

static int t1_round_div(int num, long long den)
{
    long long n = (long long)num * 256;
    return (int)((n >= 0 ? (n + den / 2) / den : (n - den / 2) / den));
}

/* Transcripcion de `ramp_params` (vinterface.rs). Se mantiene la aritmetica ENTERA
 * exacta, incluido el redondeo al mas cercano: truncar hace que `vx * t1` deje de
 * ser proporcional a `dx * s` y las letras salgan escalonadas — medido en consola
 * el 2026-08-05, y el error no es monotono en el suelo, asi que ningun MIN_T1 lo
 * arregla. */
static void t1_ramp_params(int dx, int dy, int *out_vx, int *out_vy, unsigned *out_t1)
{
    int adx = dx < 0 ? -dx : dx;
    int ady = dy < 0 ? -dy : dy;
    int m    = adx > ady ? adx : ady;
    int vcap = uvm2_t1_vcap;

    /* TOPE SELECTIVO. El disparador es el CAMBIO DE SIGNO de dy respecto al vector
     * anterior Y que el vector sea corto — no la magnitud del salto.
     *
     * La primera version disparaba por "salto grande de vy" y MEDIDO en hardware
     * salto 218.591 veces en 2.767 frames: 79 vectores por frame, o sea casi todos.
     * No seleccionaba nada. La firma real del zigzag es que el signo de dy se
     * invierte en CADA trazo, cosa que el resto del dibujo no hace. */
    if (uvm2_t1_vcap_slow != 0 && dy != 0 && m <= uvm2_t1_vcap_dv && (s_y_held & 0x100)) {
        int prev = (signed char)(s_y_held & 0xFF);
        if (prev != 0 && ((prev < 0) != (dy < 0))) {
            vcap = uvm2_t1_vcap_slow;
            uvm2_t1_vcap_slow_hits++;
        }
    }

    if (m == 0) { *out_vx = 0; *out_vy = 0; *out_t1 = (unsigned)uvm2_t1_min; return; }

    int s = uvm2_t1_draw_scale;
    /* Suelo de permanencia, proporcional a la longitud. */
    int t1_floor = s * m / 127;
    if (t1_floor < uvm2_t1_min) t1_floor = uvm2_t1_min;
    if (t1_floor > s)           t1_floor = s;
    /* TOPE DE VELOCIDAD: si la velocidad dominante (m*s/t1) pasaria de VCAP, se sube
     * t1 hasta que caiga justo en VCAP. La DISTANCIA se conserva, porque es
     * velocidad x tiempo; lo que baja es el pico de corriente que inyectamos en el
     * integrador — que es de donde salen los espolones. */
    int t1_vcap = m * s / (vcap > 0 ? vcap : 1);
    if (t1_vcap < 1) t1_vcap = 1;

    int t1 = t1_floor > t1_vcap ? t1_floor : t1_vcap;
    if (t1 > uvm2_t1_ceiling) t1 = uvm2_t1_ceiling;

    /* El divisor es la duracion REAL de la rampa, no `t1` a secas: el 6522 cuenta
     * t1 + 1,5 en un disparo. Con uvm2_t1_extra_q8 = 0 esto es la aritmetica de
     * siempre. */
    long long den = (long long)t1 * 256 + uvm2_t1_extra_q8;
    int vx = t1_round_div(dx * s, den);
    int vy = t1_round_div(dy * s, den);
    if (vx >  127) vx =  127;
    if (vx < -128) vx = -128;
    if (vy >  127) vy =  127;
    if (vy < -128) vy = -128;

    *out_vx = vx; *out_vy = vy; *out_t1 = (unsigned)t1;
}

/* Carga T1 y arranca la rampa. Con ACR = 0x80 el 6522 baja PB7 (= /RAMP) al
 * escribir T1CH y lo vuelve a subir al agotar la cuenta: la rampa se termina SOLA.
 * Por eso aqui no hay ningun `set_ramp(0, ...)` — seria escribir un pin que en este
 * modo no controlamos nosotros. */
static void t1_start_ramp(unsigned t1, uint32_t delay)
{
    emit(UVM2_VIA_T1CL, t1 & 0xFFu, 0);
    emit(UVM2_VIA_T1CH, (t1 >> 8) & 0xFFu, delay);
}

static void uvm2_draw_move_t1(int dx, int dy)
{
    int vx, vy; unsigned t1;
    s_pos_x += dx;
    s_pos_y += dy;
    t1_ramp_params(dx, dy, &vx, &vy, &t1);

    set_y(vy, UVM2_HOLD_DELAY);
    s_y_held = 0x100 | (vy & 0xFF);
    set_x(vx, UVM2_HOLD_DELAY);
    /* El haz sigue apagado: un movimiento no enciende nada. La rampa corre t1
     * cuentas y para sola. */
    t1_start_ramp(t1, t1 + (uint32_t)uvm2_t1_blank_settle);

    uvm2_stats.moves++;
    uvm2_stats.ramp_cycles += t1;
}

static void uvm2_draw_delta_t1(int dx, int dy)
{
    int vx, vy; unsigned t1;
    uint8_t lit;

    s_pos_x += dx;
    s_pos_y += dy;
    t1_ramp_params(dx, dy, &vx, &vy, &t1);

    set_y(vy, UVM2_HOLD_DELAY);
    s_y_held = 0x100 | (vy & 0xFF);
    set_x(vx, UVM2_HOLD_DELAY);

    lit = (uint8_t)(s_pcr | UVM2_PCR_BLANK_OFF);

    /* EL ORDEN IMPORTA, y en su dia estaba al reves. Encender ANTES de arrancar la
     * rampa deja el punto quieto e iluminado durante una escritura entera: un punto
     * brillante en el vertice de SALIDA. Se arranca la rampa y se enciende cuando el
     * haz ya viaja — que es tambien lo que hace Ralf con su c_BlankOffDelay. */
    t1_start_ramp(t1, (uint32_t)uvm2_t1_beam_on);
    /* Iluminado el resto de la rampa, mas el tiempo que el haz tarda en LLEGAR
     * despues de que los integradores paren. Los dos retardos NO son la misma
     * cantidad: medido por biseccion en nuestra consola, encender pide 2,5 veces
     * menos que apagar. Aqui se reutilizan las constantes de ESTA placa, que estan
     * en sus unidades y medidas aqui; son el primer sitio donde barrer. */
    {
        uint32_t on = (uint32_t)uvm2_t1_beam_on;
        emit(UVM2_VIA_PCR, lit,
             (t1 > on ? t1 - on : 0) + (uint32_t)uvm2_t1_blank_settle);
    }
    emit(UVM2_VIA_PCR, s_pcr, 0);

    uvm2_stats.vectors++;
    uvm2_stats.ramp_cycles += t1;
}

void uvm2_draw_move(int dx, int dy)
{
    if (uvm2_beam_model) { uvm2_draw_move_t1(dx, dy); return; }
    dx += drift_fix(dx, &s_drift_ax, uvm2_drift_x);
    dy += drift_fix(dy, &s_drift_ay, uvm2_drift_y);
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
    if (uvm2_beam_model) { uvm2_draw_delta_t1(dx, dy); return; }
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
    s_y_held = 0x100 | (dy & 0xFF);
    set_x(dx, UVM2_HOLD_DELAY);
    if (uvm2_beam_model) {
        t1_start_ramp(255u, 255u + (uint32_t)uvm2_t1_blank_settle);
    } else {
        set_ramp(1, s_scale);
        set_ramp(0, UVM2_HOLD_DELAY);
    }
}

static void uvm2_recalibrate(void)
{
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
#else
    /* SIN via_setup POR FRAME, el ACR se queda como lo dejo el arranque. Y el ACR es
     * parte del modelo de haz (0x60 = /RAMP a mano, 0x80 = lo gobierna T1), asi que
     * conmutar `uvm2_beam_model` en caliente con este define puesto dejaria al camino
     * T1 escribiendo T1CH sin que PB7 haga nada: la rampa no arrancaria y el modelo
     * pareceria roto cuando lo que esta viejo es un registro.
     *
     * Un fallo asi no se ve, se DEDUCE mal — y la deduccion que invita es "el modelo
     * T1 no sirve". Cuesta una comparacion por frame evitarlo. */
    if (s_acr_model != uvm2_beam_model) {
        s_acr_model = uvm2_beam_model;
        emit(UVM2_VIA_ACR, uvm2_beam_model ? 0x80 : 0x60, 0);
    }
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
    s_len[s_buf]        = s_count;
    uvm2_stats.commands = s_count;
    uvm2_stats.dropped  = s_dropped;

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
    cycles = uvm2_exec(s_cmds[s_buf], s_count);

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
