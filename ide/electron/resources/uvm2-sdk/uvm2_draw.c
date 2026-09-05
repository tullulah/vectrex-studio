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
#include "uvm2_config.h"
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
static int s_haz_encendido = 0;  /* estado del haz (SR), para keep-lit del idioma VecFever */
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
/* Con que valor se ceba el hold del BRILLO al montar la VIA. El VecFever usa 0x7F (fondo
 * de escala) en su preambulo de frame; los otros dos canales —referencia de cero y Y— van
 * a cero en los dos. Un juego lo cambia con -DUVM2_Z_CEBADO=N si mide otra cosa en SU
 * consola. */
#ifndef UVM2_Z_CEBADO
#define UVM2_Z_CEBADO 0x7F
#endif
#define UVM2_BLANK_OFF_DELAY 3u     /* ramp starts this early, before lighting */
#define UVM2_BLANK_ON_DELAY  16u    /* beam stays lit after the ramp stops     */
#define UVM2_ZERO_BASE       45u    /* centring cost, plus scale/4             */

/* Comandos perdidos en el frame en curso, por lista llena. Se vuelca a stats en
 * frame_end. Declarada aqui y no abajo porque emit() es quien la incrementa. */
/* Firma de lo que emit() manda escribir, contra lo que el chip devuelve al releerlo. */
uint32_t uvm2_firma_emitida = 2166136261u, uvm2_firma_releida, uvm2_firma_malas, uvm2_firma_vueltas;
uint32_t uvm2_firma_copia, uvm2_firma_copia_malas, uvm2_firma_copia_vueltas;

static uint32_t s_dropped;

/* EL CIERRE DEL FRAME TIENE SITIO RESERVADO. Si la lista se llena a mitad del juego, lo
 * que se tira es la COLA — y la cola es el cierre de frame_end: el apagado del haz, la
 * recalibracion y la pinza de cero. Pasaban tambien por emit() y se tiraban igual, asi
 * que un frame lleno dejaba el haz ENCENDIDO donde estuviera durante el hueco entre
 * frames y el preambulo del siguiente. En pantalla: trazos brillantisimos en el HUD
 * (que se dibuja el ultimo y es lo primero que se pierde) y el HUD a medias. Lo
 * describio Daniel el 2026-08-31 en 25m con barriles; ese mismo dia se leyo un frame de
 * 8192 comandos justos, o sea tocando el techo.
 *
 * El juego solo puede llenar hasta UVM2_CMD_RESERVA del final; frame_end levanta el
 * limite para su cierre. Un frame truncado sigue acabando apagado y pinzado. */
#define UVM2_CMD_RESERVA 64u
static uint32_t s_limite = UVM2_CMD_CAPACITY - UVM2_CMD_RESERVA;

/* LO QUE VA A COSTAR LA LISTA, en ciclos de E y mientras se construye.
 *
 * Hace falta para cerrar el frame donde lo cierra el: su frame mide 30023 ciclos CLAVADOS
 * y el sobrante lo gasta con comandos, no callado ([[preambulo-vecfever-es-el-ritmo]]).
 * Para saber cuanto sobra hay que saber cuanto llevamos, y eso nadie lo contaba: solo
 * habia `bus_cycles`, que se mide DESPUES de reproducir. */
static uint32_t s_ciclos;

uint32_t uvm2_ciclos_lista(void) { return s_ciclos; }

static inline void emit(uint32_t reg, uint32_t data, uint32_t delay)
{
    if (s_count < s_limite) {
        s_ciclos += delay + 1u;   /* la escritura ocupa su periodo de E, y el hueco va detras */
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

extern volatile uint32_t HAZ_POR_SR;   /* en vectrex-draw; ver via_setup */

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
    /* LA Y NO SE CACHEA. NUNCA.
     *
     * "El S/H todavia lo tiene" era una suposicion, y es la clase de suposicion que este
     * proyecto ya paga cara: el canal 0 del mux es C304, un condensador de 10 nF (netlist,
     * ver la skill logic-board), y un condensador SE DESCARGA. La X no tiene ese problema
     * porque es el DAC vivo, sin retencion — que es exactamente por que la deriva medida
     * era 7 veces mayor en Y que en X ([[beam-drift-jumps]]).
     *
     * Y no es teoria: en su frame 120 el VecFever abre el canal 0 en el 100,0% de las
     * rampas (647 de 647), pase lo que pase con el valor. Nosotros lo saltabamos en 12 y
     * nos quedabamos en el 98,2%. Z si la cachea (recarga C306 solo 4 veces por frame), asi
     * que la regla no es "no cachear nada": es no cachear la Y. */
    delay = hold_for(s_y, y);
    s_y = y;
    set_porta((uint8_t)y, 0);
    mux_sample(UVM2_MUX_Y, delay);
}

/* EL HUECO DESPUES DEL SR=00 LO FIJA LO QUE VIENE DETRAS, no el apagado. Medido en su
 * frame: 15 ciclos si le sigue ORA (el lote de brillo) y 12 si le sigue el PCR de la pinza.
 * El 8 de la fisica —los 8 desplazamientos del SR— cabe en los dos. Poniamos 12 en ambos. */
#define UVM2_SR_A_ORA  15u
#define UVM2_SR_A_PCR  12u
static void haz_apagar_y_esperar_h(uint32_t hueco);

static void set_z(int z, uint32_t delay)
{
    if (s_z == z) return;
    delay = hold_for(s_z, z);
    s_z = z;
    if (HAZ_POR_SR) {
        /* LOTE DE BRILLO DEL VECFEVER, verbatim de la captura (x1229/frame-clase:
         * ORA=z+4 ORB=84+9 ORB=81): DOS escrituras de ORB, sin el paso de "deshabilitar
         * primero" — el VecFever cambia seleccion y habilitacion en UNA escritura y
         * dibuja limpio, o sea que el paso extra era sobre-cautela nuestra. La ventana
         * del hold es fija (9 ciclos), la del VecFever. */
        /* APAGAR ANTES DE MOVER Z, QUE ES SU ORDEN.
         *
         * En la captura el SR=00 va PEGADO al lote de brillo y ANTES de el:
         *     4:08 5:00 | a:00 | 1:78 0:84 0:81
         * y nosotros lo teniamos despues:
         *     4:08 5:00 | 1:78 0:84 0:81 | a:00
         * O sea que cambiabamos la intensidad CON EL HAZ TODAVIA ENCENDIDO — y con el SR
         * en modo 110 el haz sigue vivo 8 ciclos mas, asi que el trazo que acaba de
         * terminar se lleva un tramo final con el brillo del SIGUIENTE. Ver
         * [[t2-el-reloj-del-blanking]] para por que SR=00 no apaga en el acto. */
        haz_apagar_y_esperar_h(UVM2_SR_A_ORA);   /* detras va el ORA del brillo */
        set_porta((uint8_t)z, 3u);
        emit(UVM2_VIA_PORTB, 0x84u, 8u);            /* mux ON canal 2, un solo paso */
        emit(UVM2_VIA_PORTB, UVM2_PB_IDLE, 12u);    /* y aparca en 81, como el VF */
        s_portb = UVM2_PB_IDLE;
        return;
    }
    set_porta((uint8_t)z, 0);
    mux_sample(UVM2_MUX_Z, delay);
}

/* X is the live DAC — no sample/hold, so it must be written last before a ramp. */
static void set_x(int x, uint32_t delay)
{
    set_porta((uint8_t)x, delay);
}

static int32_t s_drift_ax, s_drift_ay;   /* ver la compensacion de deriva, abajo */

/* La version CON DEUDA, para trazos encadenados, y el olvido de la deuda en cada salto.
 * Viven en vectrex-draw para que no haya tres copias de la misma regla. */
void vx_ramp_params_chain(int32_t dx, int32_t dy, int32_t *vx, int32_t *vy, uint32_t *t1);
void vx_chain_reset(void);
void vx_deuda_reset(void);
/* El SALTO usa su propio tope de velocidad (VCAP_SALTO): va a oscuras, asi que frenarlo
 * no ilumina nada. Ver el bloque de VCAP_SALTO en ramp.rs. */
void vx_ramp_params_salto(int32_t dx, int32_t dy, int32_t *vx, int32_t *vy, uint32_t *t1);
void vx_ramp_params_chain_q4(int32_t dx, int32_t dy, int32_t *vx, int32_t *vy, uint32_t *t1);
void vx_ramp_params_salto_q4(int32_t dx, int32_t dy, int32_t *vx, int32_t *vy, uint32_t *t1);
void vx_ramp_params_chain_qn(int32_t dx, int32_t dy, uint32_t q,
                             int32_t *vx, int32_t *vy, uint32_t *t1);
void vx_ramp_params_salto_qn(int32_t dx, int32_t dy, uint32_t q,
                             int32_t *vx, int32_t *vy, uint32_t *t1);
void vx_ramp_params_con_t1(int32_t dx, int32_t dy, int32_t f, uint32_t t1,
                           int32_t *vx, int32_t *vy);

extern volatile uint32_t HAZ_POR_SR;   /* en vectrex-draw; ver via_setup */

/* Apagar el haz por SR si esta encendido. Con keep-lit (idioma VecFever) el PCR NO apaga
 * nada: TODO camino que mueva el haz fuera de un trazo —re-cero, recalibrado, cierre de
 * frame— tiene que pasar por aqui ANTES de mover, o la travesia sale dibujada (la
 * ESTRELLA de rayos al centro vista en consola el 2026-09-03). */
/* CUANTO TARDA EL HAZ EN APAGARSE DE VERDAD TRAS PEDIRLO.
 *
 * Con ACR = 0x98 el registro de desplazamiento va en modo 110: saca 8 bits al ritmo de Phi2
 * y para, y CB2 (~BLANK) se queda con el ULTIMO. O sea que escribir SR = 0x00 no apaga:
 * apaga OCHO CICLOS DESPUES. Ver t2-el-reloj-del-blanking.
 *
 * El VecFever deja 12-13 ciclos entre su SR=00 y el PCR=CC que muerde la pinza de cero
 * (medido: 10 de sus 15 pinzas). Nosotros dejabamos CERO —`SR=00+0 PCR=cc`, en 6 de 10— asi
 * que la pinza empezaba a arrastrar el haz al centro CON EL HAZ TODAVIA ENCENDIDO y dibujaba
 * el camino: una linea larga cruzando la pantalla desde el objeto hasta el centro, que es
 * justo lo que se veia en consola en las dos fotos del 2026-09-04.
 *
 * El 8 es fisica (los 8 desplazamientos); el 12 es el suyo, con margen. */
#define UVM2_SR_APAGA_CICLOS  12

/* QUE LA ULTIMA RAMPA ILUMINADA TERMINE ANTES DE CERRAR EL HAZ.
 *
 * `moveto_seq` ya lo hace (H_T1CH_APAGA = 29 contra los 11 de "el microtramo sigue"), pero
 * ahi solo cubre los apagados que emite EL. Los que salen de este fichero —el de `set_z`,
 * el de la pinza de cero— dejaban el T1CH en 11, o sea 18 ciclos menos que el: 29 casos por
 * frame en su frame 120, y cada uno es una rampa cortada, o sea un trazo corto.
 *
 * El 29 es SUYO, medido: 21 casos con el SR justo detras del T1CH, contra 175 de hueco 16
 * en los que lo siguiente es siempre ORA. El hueco no lo fija el apagado, lo fija cuanto se
 * tarda en llegar a el. Ver los mismos numeros en emit.rs. */
#define UVM2_H_T1CH_SIGUE  11u
#define UVM2_H_T1CH_APAGA  29u

static void alarga_t1ch_del_trazo(void)
{
    if (s_count == 0u) return;
    uint8_t *p = &s_cmds[s_buf][(s_count - 1u) * 3u];
    uint32_t v = (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16);
    if (((v >> 8) & 0xFu) != (uint32_t)UVM2_VIA_T1CH) return;   /* no cerramos una rampa */
    uint32_t hueco = (v >> 12) + (UVM2_H_T1CH_APAGA - UVM2_H_T1CH_SIGUE);
    if (hueco > 4095u) hueco = 4095u;
    s_ciclos += hueco - (v >> 12);
    v = (v & 0xFFFu) | (hueco << 12);
    p[0] = (uint8_t)v; p[1] = (uint8_t)(v >> 8); p[2] = (uint8_t)(v >> 16);
}

static void haz_apagar(void)
{
    if (s_haz_encendido) {
        alarga_t1ch_del_trazo();
        emit(UVM2_VIA_SR, 0x00, 0);
        s_haz_encendido = 0;
    }
}

/* Como `haz_apagar`, pero dejando que el SR termine de desplazar antes de que el llamante
 * haga algo que MUEVA el haz (la pinza de cero, un salto). */
static void haz_apagar_y_esperar_h(uint32_t hueco)
{
    if (s_haz_encendido) {
        alarga_t1ch_del_trazo();
        emit(UVM2_VIA_SR, 0x00, hueco);
        s_haz_encendido = 0;
    }
}

static void haz_apagar_y_esperar(void) { haz_apagar_y_esperar_h(UVM2_SR_A_PCR); }

/* Rampas desde el ultimo re-cero. Declarado aqui arriba porque lo pone a cero ,
 * que va antes que el knob. Ver uvm2_cero_cada. */
static uint32_t s_rampas_desde_cero;

static void set_zero(int active, uint32_t delay)
{
    /* La pinza arrastra el haz al centro: si llega encendido, dibuja la travesia. Y no
     * basta con PEDIR el apagado: el SR tarda 8 ciclos en sacarlo. Ver haz_apagar_y_esperar. */
    if (active) haz_apagar_y_esperar();
    /* CADA re-cero borra la deriva acumulada, porque devuelve el haz al centro.
     * Si el acumulador sobrevive, se sigue corrigiendo un error que ya no existe
     * — y como los re-ceros caen en sitios distintos segun la escena, ese sobrante
     * CAMBIA entre frames: tiembla. Un error determinista no puede temblar.
     *
     * Aqui y no en frame_begin: los re-ceros ocurren muchas veces dentro de un
     * frame (uno por objeto, mas los que mete el tope de trazos). */
    if (active) { s_drift_ax = 0; s_drift_ay = 0; s_rampas_desde_cero = 0; }

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
    /* ACR SEGUN QUIEN ENCIENDA EL HAZ. Con el modelo nuestro (haz por PCR) la rampa la
     * termina T1 y basta 0x80. Con el de la BIOS (haz por el registro de desplazamiento)
     * hace falta 0x98, que ademas pone el SR bajo control de fase 2 — es lo que hace que
     * escribir $FF/$00 ahi encienda y apague CB2. Las dos formas van atadas a la MISMA
     * perilla para que no puedan quedar a medias. */
    /* T2 NO INTERVIENE EN EL BLANKING, Y AQUI LLEGUE A ESCRIBIRLO POR LEER MAL EL MODO.
     *
     * Puse T2 = 0x7530 copiandoselo al VecFever, creyendo que con ACR = 0x98 el registro de
     * desplazamiento iba en modo LIBRE a ritmo de T2. Es falso: los bits 4-2 de 0x98 son
     * **110 = shift out bajo control de Phi2**, que desplaza 8 bits y PARA; el free-running
     * a ritmo de T2 es el modo 100. En 110 CB2 se queda con el ultimo bit desplazado, asi
     * que 0x01 deja el haz encendido y 0x00 apagado — es un CIERRE, no un ciclo de trabajo,
     * y T2 no pinta nada. Escribirlo no rompia nada y tampoco arreglaba nada: los puntos de
     * los microtramos seguian igual en consola.
     *
     * El VecFever si lo escribe, pero por otro motivo: T2 es SU temporizador de frame (su
     * bucle espera a T2, y por eso T2CH sirve de marca de frame al analizar la captura).
     * Nosotros marcamos el frame de otra forma, asi que no nos hace falta.
     *
     * COMO SE APAGA EL HAZ DE VERDAD, leido del netlist y no de la memoria: CB2 (`~BLANK`,
     * IC207 pin 19) no es una puerta digital — tira del nodo Z por R315 (2,2k) contra el
     * diodo D302, cuyo catodo es la salida del amplificador de brillo (IC303C). CB2 bajo
     * hunde Z y apaga; CB2 alto deja Z al valor que sostiene el sample-and-hold. */
    emit(UVM2_VIA_ACR,   HAZ_POR_SR ? 0x98 : 0x80,    HAZ_POR_SR ? 23u : 0u);

    /* Prime each sample/hold channel from a DAC value of 0: zero reference,
     * then Y, then Z.  Without this the integrators start wherever the analog
     * section powered up. */
    if (HAZ_POR_SR) {
        /* SU PROLOGO DE FRAME, VERBATIM (frame 120, las 5 escrituras que van justo detras
         * del ACR=0x98):
         *
         *     PCR=CC  pinza ON
         *     ORB=03  mux cerrado, seleccion en 1
         *     ORA=00  DAC a cero
         *     ORB=E2  canal 1 (referencia de cero) abierto: se ceba a CERO
         *     ORB=E1  cerrado
         *
         * Y NADA MAS: no ceba Y ni Z aqui. Nosotros haciamos catorce escrituras -cebado de
         * Y, cebado de Z a 0x7F y un set_z de reposicion- antes de la Z que pide el juego,
         * o sea TRES cargas de C306 por frame donde el hace una. La Y y el centro los deja
         * en manos del bloque de cero, que viene justo despues de la Z y suelta la pinza el
         * mismo. Ver uvm2_frame_begin. */
        /* Los huecos son los SUYOS, medidos en la misma captura: el prologo no es solo
         * la lista de escrituras, tambien el ritmo al que salen. Los teniamos a cero. */
        emit(UVM2_VIA_PCR,   0xCC, 6);
        emit(UVM2_VIA_PORTB, 0x03, 0);
        emit(UVM2_VIA_PORTA, 0x00, 5);
        emit(UVM2_VIA_PORTB, 0xE2, 9);    /* ventana del canal 1 */
        emit(UVM2_VIA_PORTB, 0xE1, 58);   /* y su asentamiento antes de la Z */
        s_pcr = 0xCC; s_portb = 0xE1; s_porta = 0x00; s_porta_stale = 0;
        s_pos_x = 0; s_pos_y = 0;
        return;
    }
    set_porta(0x00, 0);
    mux_sample(UVM2_MUX_ZEROREF, UVM2_HOLD_DELAY);
    mux_sample(UVM2_MUX_Y,       UVM2_HOLD_DELAY);
    /* EL CANAL Z SE CEBA A FONDO DE ESCALA, COMO EL VECFEVER. Su preambulo de frame es
     * `ORA=7F, ORB=84 (canal 2), ORB=81` — ceba el hold del brillo con 0x7F, no con cero
     * como los otros dos. Nosotros lo cebabamos a 0 con los demas, o sea que entre el
     * cebado y el primer SET_INTENSITY del juego el haz corria con el brillo al MINIMO.
     * El de la referencia arranca al maximo, y bajar es barato: un `set_z` lo cambia en
     * cuanto el juego pide otra cosa. */
    set_porta(UVM2_Z_CEBADO, 0);
    mux_sample(UVM2_MUX_Z,       UVM2_HOLD_DELAY);

    s_y = 0; s_z = UVM2_Z_CEBADO; s_pos_x = 0; s_pos_y = 0;
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
 * esta encendido cuando no existe es peor que no tenerla.
 *
 * ── Y DESDE EL 2026-08-27 SI HAY UNA. Medida en consola, en el 25m de dkong ────────
 *
 * El modelo de rampa pasa a ser PROPORCIONAL —t1 = longitud * DRAW_SCALE / VCAP, sin
 * suelo— porque el suelo atrapaba al 96% de los trazos: la longitud MEDIANA de un trazo
 * del 25m son 3 unidades de dispositivo y el suelo valia 31. `VCAP` es, de hecho, los
 * ciclos de espera POR UNIDAD de longitud.
 *
 *     MIN_T1 = 1   MIN_T1_ARRANQUE = 1   VCAP = 24
 *     -> 87 ciclos por operacion con geometria correcta, contra 109 con los dos suelos
 *
 * Mesetas, y se coge el CENTRO, no el ultimo valor que sobrevive:
 *     VCAP: 20 y 26 bien, 32 flojea, 40 regular  -> 24
 *
 * POR QUE AQUI Y NO EN vectrex-draw: `MIN_T1` y `VCAP` son el mismo simbolo que usa el
 * firmware del cartucho propio, y alli la geometria se afino con 31/127 sin medir nada de
 * esto. Cambiar el valor compartido seria cambiarle el dibujo a la otra placa sin una sola
 * medida suya — la divergencia que este repositorio tiene un guardian para evitar.
 *
 * Y NO ES UNA CONSTANTE DEL REPOSITORIO, ES UNA CALIBRACION DE MAQUINA: si otra consola
 * pide otro numero, se cambia aqui y se anota con su medida, como esta. */
extern volatile uint32_t MIN_T1, MIN_T1_ARRANQUE, VCAP, VCAP_SALTO, DAC_CERO, DRAW_SCALE, T1_TRANSPORT;
extern volatile uint32_t T1_SALTO;
/* LOS HUECOS DEL MICROTRAMO, por globales como el resto de knobs de la capa de dibujo.
 * Estuvieron como campos de vx_timings y NO funcionaba: con los dos structs del mismo
 * tamaño y el valor correcto en C, Rust sacaba un hueco saturado a 4095 por vector y el
 * frame se iba 30x. Ver el bloque de MT_ORA_Y en emit.rs. */
extern volatile uint32_t MT_ORA_Y, MT_ORB_KEEP, MT_SR_ON, MT_ORA_X_ON;
extern volatile uint32_t TECHO_MANDA, DEUDA_ON, TRAZO_ENTERO;

/* DAC_CERO: poner PORT A a cero tras cada trazo, antes de apagar el haz. Es un comando y
 * un ciclo de E por trazo ENCENDIDO. Un juego lo fija con -DUVM2_DAC_CERO=0 tras medirlo
 * en SU consola; sin eso vale 1 y no cambia nada para nadie. */
#ifndef UVM2_DAC_CERO
#define UVM2_DAC_CERO 1
#endif

void uvm2_draw_init(void)
{
    /* LA CALIBRACION DE LA CONSOLA, ANTES DE NADA. Los knobs que toca —escala, termino fijo
     * de la rampa, referencia de cero y brillo— describen ESTE tubo, no este juego, asi que
     * se cargan aqui y los 44 puertos los heredan sin tocar 44 ficheros. Si no hay ninguna
     * guardada no cambia nada: `uvm2_config_cargar` devuelve 0 y el juego se queda con lo
     * que traiga compilado, que es lo de siempre.
     *
     * El ASISTENTE no se abre desde aqui a proposito: quien manda en el bucle de frame es el
     * juego, y arrancar una interfaz desde una funcion de init seria un efecto lateral
     * escondido. El juego hace `if (!uvm2_config_cargar()) uvm2_config_asistente();`. */
    uvm2_hay_calibracion = uvm2_config_cargar();

    /* LA SALIDA: el blanking por PCR sigue vivo para quien lo necesite. Desde 2026-09-04 el
     * idioma SR es el de serie (HAZ_POR_SR arranca en 1), asi que lo que hace falta es poder
     * APAGARLO, no encenderlo. */
#ifdef UVM2_HAZ_POR_PCR
    HAZ_POR_SR = 0u;
#endif
#ifdef UVM2_HAZ_POR_SR
    /* LA PERILLA DEL BUILD TIENE QUE ATERRIZAR EN EL SIMBOLO VIVO. build_uvm2.sh define
     * UVM2_HAZ_POR_SR desde el 2026-09-03, pero nadie lo consumia: HAZ_POR_SR quedaba en
     * su 0 por defecto, via_setup emitia ACR=0x80 y el idioma SR entero era un no-op —
     * CB2 se queda bajo por PCR (0xCC/0xCE) y no se enciende JAMAS. En el emulador:
     * pantalla negra con la lista entera correcta. [[defines-sin-arranque-vpy]]. */
    HAZ_POR_SR      = 1u;
#endif
    /* El VecFever no dibuja unidades de menos de 8 cuentas: su plotter fija t1 =
     * max(8, len*escala/127) y reparte en microtramos de 8 con un RESTO final (T1CL=4/6/7
     * en la captura). MIN_T1=8 + VCAP=127 reproduce exactamente ese modelo en el nuestro.
     * Por juego: -DUVM2_MIN_T1=N; sin define quedan los 1 de dkong. */
#ifdef UVM2_MIN_T1
    MIN_T1          = UVM2_MIN_T1;
    MIN_T1_ARRANQUE = UVM2_MIN_T1;
#else
    MIN_T1          = 1u;   /* sin suelo: la duracion sale de la longitud */
    MIN_T1_ARRANQUE = 1u;   /* idem para las rampas que arrancan paradas */
#endif
    /* VCAP era 24 A SECAS: la calibracion del 25m de dkong (2026-08-27) sangraba a
     * TODOS los juegos del UVM2 — el mismo overfitting contra el que avisa la nota de
     * arriba, pero al reves. Un juego lo fija con -DUVM2_VCAP=N; sin define, quedan
     * los 24 de dkong. asterock lleva 127: la captura del VecFever dibuja este juego
     * con tasas a fondo de escala, y vfplay ya reprodujo ese stream EN NUESTRA consola
     * (peldano b) — no es un numero a ojo. Con 24, cada trazo salia con t1 ~6x mas
     * largo y el frame a 90k ciclos (3x el presupuesto). */
    /* EL TOPE DE VELOCIDAD DE LOS SALTOS. 0 = el mismo que los trazos, o sea el
     * comportamiento de siempre para quien no lo fije. Un juego lo pone con
     * -DUVM2_VCAP_SALTO=N tras medirlo en SU consola. */
    /* SALTO A TIEMPO FIJO (el idioma del VecFever: t1 dado, tasa variable). Con esto
     * VCAP_SALTO deja de intervenir — son dos modelos alternativos del mismo salto, no
     * dos ajustes que se sumen. Medido en Major Havoc: t1=31 en el 99% de sus saltos.
     * Ver el bloque de T1_SALTO en ramp.rs. */
#ifdef UVM2_T1_SALTO
    T1_SALTO        = UVM2_T1_SALTO;
#endif
#ifdef UVM2_MT_ORA_Y
    MT_ORA_Y        = UVM2_MT_ORA_Y;
#endif
#ifdef UVM2_MT_ORB_KEEP
    MT_ORB_KEEP     = UVM2_MT_ORB_KEEP;
#endif
#ifdef UVM2_MT_SR_ON
    MT_SR_ON        = UVM2_MT_SR_ON;
#endif
#ifdef UVM2_MT_ORA_X_ON
    MT_ORA_X_ON     = UVM2_MT_ORA_X_ON;
#endif
#ifdef UVM2_VCAP_SALTO
    VCAP_SALTO      = UVM2_VCAP_SALTO;
#endif
    /* QUIEN MANDA EN LAS DIAGONALES TUMBADAS: el techo del eje menor (1, el de siempre) o
     * el tope de velocidad (0). Ver la nota de `ramp_params_q` en ramp.rs. Se compara en
     * consola con MHAVOCT antes de mover el por defecto. */
#ifdef UVM2_TECHO_CEDE
    TECHO_MANDA     = 0u;
#endif
    /* LA DEUDA SE APAGA SOLA CUANDO LA ENTRADA ES PRECISA.
     *
     * Existe para compensar el redondeo de la ENTRADA: con la geometria en 1/16 el residuo
     * se acumula y hay que cobrarlo. Con 1/64 o mas fino la entrada ya es casi exacta y la
     * correccion deja de quitar error y pasa a METERLO.
     *
     * MEDIDO contra su frame 120 de Major Havoc, misma geometria de entrada, comparando la
     * secuencia de trazos iluminados EN ORDEN:
     *
     *     con deuda   418 de 427 identicos a los suyos   (97,9%)
     *     sin deuda   426 de 427                          (99,8%)
     *
     * Los 8 que se van son todos +-1 en una tasa, y todos los mete la correccion. El umbral
     * es el mismo 6 con el que la entrada deja de perder tasas suyas: ver la nota de
     * UVM2_Q_BITS. -DUVM2_SIN_DEUDA / -DUVM2_CON_DEUDA fuerzan cualquiera de los dos. */
#if UVM2_Q_BITS >= 6
    DEUDA_ON        = 0u;
#endif
#ifdef UVM2_CON_DEUDA
    DEUDA_ON        = 1u;
#endif
#ifdef UVM2_SIN_DEUDA
    DEUDA_ON        = 0u;
#endif
    /* UN TRAZO = UNA RAMPA, como el VecFever, y es lo de serie: confirmado en consola el
     * 2026-09-04 (con microtramos, Major Havoc punteaba; con el trazo entero sale limpio).
     * Ver la nota de TRAZO_ENTERO en emit.rs. */
#ifdef UVM2_MICROTRAMOS
    TRAZO_ENTERO    = 0u;
#endif
#ifdef UVM2_VCAP
    VCAP            = UVM2_VCAP;
#else
    VCAP            = 24u;  /* 6,7 ciclos de espera por unidad de longitud */
#endif
    DAC_CERO        = UVM2_DAC_CERO;
    /* LA ESCALA, si el juego la fija (-DUVM2_DRAW_SCALE / -DUVM2_T1_TRANSPORT). Sin eso se
     * queda la de siempre. Existe porque la escala buena se encontro desde el panel y se
     * EVAPORO en el primer reboot: una perilla viva no es una decision hasta que se compila. */
#ifdef UVM2_DRAW_SCALE
    DRAW_SCALE      = UVM2_DRAW_SCALE;
#endif
#ifdef UVM2_T1_TRANSPORT
    T1_TRANSPORT    = UVM2_T1_TRANSPORT;
#endif

    s_count = 0;
    via_setup();
    /* EL CEBADO DE Z, UNA VEZ Y AL ARRANCAR. Vivia en via_setup, o sea una vez POR FRAME,
     * y ahora el prologo de frame es el suyo y no ceba Z. Aqui sigue haciendo falta por si
     * un juego dibuja antes de su primer SET_INTENSITY: sin esto el haz correria con lo que
     * tuviera C306 al encender. Fondo de escala, como el. */
    if (HAZ_POR_SR) set_z(UVM2_Z_CEBADO, UVM2_HOLD_DELAY);   /* s_z_last ya arranca ahi */

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
    set_porta(UVM2_Z_CEBADO, 0);          /* fondo de escala, como via_setup */
    mux_sample(UVM2_MUX_Z,       UVM2_HOLD_DELAY);
    s_y = 0;
    s_z = UVM2_Z_CEBADO;
}

/* Definidas abajo con las demas perillas; se usan aqui arriba. */
extern volatile int32_t uvm2_zero_settle_e;
extern volatile int32_t uvm2_cero_offset;
extern volatile int32_t uvm2_hueco_minimo;

void uvm2_draw_reset(void)
{
    /* APAGAR ANTES DE PINZAR EL CERO. Con keep-lit (idioma VecFever) el haz llega
     * ENCENDIDO al re-cero; el apagado vive en haz_apagar() y set_zero(1) tambien lo
     * llama, pero aqui ademas hay que apagar ANTES de re-cebar la referencia (mux). */
    haz_apagar_y_esperar();   /* el SR necesita sus 8 ciclos ANTES de que la pinza mueva el haz */

    if (HAZ_POR_SR) {
        /* EL BLOQUE DE CERO DEL VECFEVER, VERBATIM (x10.517 en la captura, 43 ciclos):
         *
         *     PCR=CC +7  pinza ON
         *     ORB=81 +1  mux aparcado
         *     ORA=00 +6  DAC a cero
         *     ORB=C0 +11 canal 0 (Y) abierto: la Y se re-ceba DENTRO de la pinza
         *     ORB=82 +1  canal 1 (referencia de cero) abierto
         *     ORA=of +7  el OFFSET calibrado por consola (la del VecFever: 0x07)
         *     ORA=FF +4  el toque final de $FF (su significado sigue ABIERTO; se
         *                reproduce tal cual — la consigna es copiar, no inventar)
         *     ORB=83 +6  mux cerrado
         *     PCR=CE +9  pinza suelta
         *
         * Cebar CONTRA la pinza es lo que este fichero ya defendia en via_setup; el
         * VecFever lo hace en CADA re-cero y en 43 ciclos, no en nuestros ~86. El
         * offset es calibracion DE MAQUINA ([[zero-reference-calibration]]): 0 deja
         * nuestra calibracion actual; se barre en consola. */
        if (s_pos_x == 0 && s_pos_y == 0 && (s_pcr & UVM2_PCR_ZERO_OFF) != 0)
            return;                     /* ya centrado y suelto: no repetir el bloque */
        s_drift_ax = 0; s_drift_ay = 0;   /* lo que set_zero(1) hacia */
        s_rampas_desde_cero = 0;
        /* Y LA DEUDA, QUE AQUI SI SE TIRA. El re-cero devuelve el haz al centro por
         * hardware: lo que creiamos y lo que hay vuelven a coincidir, asi que no queda
         * nada que deber. El SALTO no la tira (ver vx_chain_reset): ahi el haz sigue
         * donde estaba, solo que en otro sitio del que creemos. */
        vx_deuda_reset();
        emit(UVM2_VIA_PCR,   0xCC, 6);
        emit(UVM2_VIA_PORTB, 0x81, 0);
        emit(UVM2_VIA_PORTA, 0x00, 5);
        emit(UVM2_VIA_PORTB, 0xC0, 10);
        emit(UVM2_VIA_PORTB, 0x82, 0);
        emit(UVM2_VIA_PORTA, (uint8_t)uvm2_cero_offset, 6);
        /* EL `ORA=0xFF` VA ANTES DE CERRAR EL MUX, COMO EL. Y AQUI ME EQUIVOQUE.
         *
         * Lo tuve invertido a proposito, razonando que con el canal de referencia ABIERTO
         * ese 0xFF carga el condensador de la REFERENCIA DE CERO a 127 en vez de al offset
         * — y esa referencia es el ORIGEN del haz (dx = xsh - rsh, dy = rsh - ysh), asi que
         * descolocaria todos los vectores. Lo achaque a unos "vectores abiertos y temblor"
         * que aparecieron por esas fechas.
         *
         * LO REFUTA `vfcap`: reproduce SU stream byte a byte en nuestra placa, con este
         * mismo orden, y el dibujo sale limpio y sin vectores abiertos. Si en el suyo
         * funciona, el mecanismo que yo temia no ocurre, o algo mas lo compensa — y lo que
         * yo estaba arreglando estaba en otro sitio.
         *
         * Sigue sin saberse PARA QUE sirve ese 0xFF (anotado como abierto en
         * [[vecfever-como-dibuja]]). Pero no saber para que sirve no es razon para hacerlo
         * distinto: la referencia dice que asi va. */
        emit(UVM2_VIA_PORTA, 0xFF, 3);
        emit(UVM2_VIA_PORTB, 0x83, 5);
        emit(UVM2_VIA_PCR,   0xCE, 8);
        /* Las caches, con lo ULTIMO que se ha escrito de verdad: ahora el orden es
         * ORA=FF y luego ORB=83, asi que Port B queda en 0x83 y Port A en 0xFF igual,
         * pero el que cierra la secuencia es el ORB. */
        s_pcr = 0xCE; s_portb = 0x83;
        s_porta = 0xFF; s_porta_stale = 0;
        s_y = 0;                        /* el canal 0 quedo cebado a cero */
        s_pos_x = 0; s_pos_y = 0;
        return;
    }

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

    set_zero(1, uvm2_zero_settle_e >= 0 ? (uint32_t)uvm2_zero_settle_e
                                       : UVM2_ZERO_BASE + s_scale / 4u);
    set_zero(0, 0);
    s_pos_x = 0;
    s_pos_y = 0;
}

/* Ultima intensidad pedida, que SOBREVIVE al frame. via_setup() ceba Z a 0 cada
 * frame, asi que sin esto el hueco entre soltar la pinza y el primer SET_INTENSITY
 * del juego se recorre con Z desconocido. Ralf no tiene ese hueco: pone Z y
 * DESPUES suelta la pinza (SetZ(0x5F); SetZero(false);). */
static int s_z_last = UVM2_Z_CEBADO;   /* si no, frame_begin deshace el cebado de Z */

/** El brillo que se pidio por ultima vez. Lo necesita `uvm2_config_actual`, que tiene que
 *  poder LEER los knobs y no solo escribirlos. */
int uvm2_draw_intensity_actual(void) { return s_z_last; }

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

/* `fixup` SE HA IDO, y no por opinion: NADIE LA LLAMABA. Doblaba el delta y halvaba la
 * rampa mientras el DAC tuviera holgura, y su justificacion medida —"128 de los ~169
 * ciclos por vector eran la rampa FIJA"— describe un modelo de rampa que este SDK ya no
 * tiene: desde el 2026-08-27 la duracion sale de la longitud (t1 = len*DRAW_SCALE/VCAP),
 * asi que un trazo corto ya no paga una rampa de rango completo y no hay nada que
 * arreglar. Se quedo definida, sin una sola llamada, y `uvm2_draw_set_fixup(1)` en
 * uvm2_svc.c encendia un flag que nadie leia — una linea que dice que algo esta
 * encendido cuando no existe, que es peor que no tenerla (el mismo argumento con el que
 * se borro `set_ramp` unas lineas mas arriba). El VecFever tampoco hace nada parecido:
 * su plotter reparte la longitud en microtramos de 8, no en escala. */

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
    /* EL ORDEN Y EL NUMERO TIENEN QUE CUADRAR CON `CSink` de vectrex-draw/src/emit.rs.
     * Estas tres estaban declaradas aparte, en un `vx_sink_extra` que NO CONSUMIA NADIE:
     * el emisor las pregunta, pero el `CSink` de Rust no las tenia, asi que devolvian
     * siempre el valor por defecto del trait (falso) y el UVM2 pagaba el muestreo de Y y
     * el par apagar/encender en TODOS los vectores. El firmware del cartucho propio si
     * las implementa —usa la caja como rlib— y por eso sólo una de las dos placas tenia
     * las optimizaciones del emisor que comparten. */
    int  (*y_can_skip)(void *, int32_t);
    int  (*beam_is_lit)(void *);
    void (*beam_lit)(void *);
    int  (*x_can_skip)(void *, int32_t);
    /* AL FINAL, como los demas opcionales: quien no lo rellene se queda como antes. */
    void (*alargar_ultimo)(void *, uint32_t);
};
struct vx_timings { uint32_t e6809_q8, y_mux_q8, moveto_settle_q8, beam_on_q8;
                    int32_t blank_settle_q8; uint32_t keep_lit; uint32_t x_settle_q8;
                    /* Los huecos del microtramo, en ciclos de E. 0 = el valor de siempre
                     * (la cadencia medida de SU asterock). Se parametrizan porque el
                     * VecFever NO tiene una sola cadencia: le monta un plotter distinto a
                     * cada titulo. Ver el bloque en emit.rs. */
                    uint32_t mt_ora_y, mt_orb_keep, mt_sr_on, mt_ora_x_on; };
extern volatile uint32_t SIGUEN_UNIDADES;   /* en emit.rs */
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
/* ALARGAR EL HUECO DEL ULTIMO COMANDO YA EMITIDO.
 *
 * POR QUE HACE FALTA. MEDIDO en su frame 120 de Major Havoc: el hueco que el VecFever deja
 * tras `T1CH` vale 11 ciclos de E cuando el microtramo CONTINUA, y 16 cuando el siguiente
 * paso apaga el haz — la separacion es perfecta, 175 de 175. Es fisico: la ultima rampa de
 * un trazo iluminado tiene que TERMINAR antes de cerrar el haz; cortandola a 11 el trazo
 * sale corto, que es la firma de los puntos.
 *
 * Y va aqui, y no en `draw_line_seq`, porque quien apaga es la llamada SIGUIENTE
 * (`moveto_seq` o el re-cero): el emisor del trazo no puede saberlo cuando emite. */
static void vxs_alargar_ultimo(void *ctx, uint32_t extra_q8)
{
    (void)ctx;
    if (s_count == 0u) return;
    uint32_t d = extra_q8 / 256u;
    if (d == 0u) return;
    /* Los 24 bits ya empaquetados: dato en 0-7, registro en 8-11, hueco de 12 arriba.
     * Se toca SOLO el hueco; el dato y el registro se copian tal cual. */
    uint8_t *p = &s_cmds[s_buf][(s_count - 1u) * 3u];
    uint32_t v = (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16);
    uint32_t hueco = (v >> 12) + d;
    if (hueco > 4095u) hueco = 4095u;
    s_ciclos += hueco - (v >> 12);
    v = (v & 0xFFFu) | (hueco << 12);
    p[0] = (uint8_t)v; p[1] = (uint8_t)(v >> 8); p[2] = (uint8_t)(v >> 16);
}

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
    /* SI EL MODELO PIDE UN HUECO, QUE HAYA AL MENOS UN CICLO.
     *
     * El truncado es a proposito —lo hace el cartucho propio y dos implementaciones que
     * redondean distinto son dos modelos— pero AQUI e6809_q8 vale 64, no 256. Con esa
     * unidad la rejilla es de cuatro: e(1), e(2) y e(3) valen 0,25, 0,50 y 0,75 ciclos y
     * DESAPARECEN ENTEROS. En el cartucho propio, con 256, e(1) si vale un ciclo. O sea
     * que las dos placas NO estan igualadas: al UVM2 se le pierden huecos que la otra si
     * tiene.
     *
     * Consecuencia medida en la lista real: 593 escrituras seguidas a ORA/ORB con hueco
     * cero, el 9% de los comandos, y 438 de ellas ORB->ORA — inhibir el mux y escribir el
     * DAC de X en el periodo de E siguiente. Malban avisa por su cuenta de justo eso:
     * "it can sometimes be problematic to have ORB / ORA be set too fast without a delay",
     * y que depende de la consola.
     *
     * uvm2_hueco_minimo = 1 pone el suelo; 0 deja el truncado de siempre. */
    if (uvm2_hueco_minimo && delay_q8 && d == 0u) d = 1u;
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
#if defined(UVM2_PIO_STREAM) && !defined(UVM2_CMDS_IN_PSRAM)
    /* SIN PORTADOR: el retardo se PLIEGA en el comando anterior. El T1LL re-escrito era
     * el transporte del retardo para el ejecutor SIO, que sostiene la escritura durante
     * la espera y no puede colgar el retardo de T1CH ([[t1ch-no-es-idempotente]]). El
     * stream PIO aparca con el patron de PARK entre comandos — no re-escribe nada — asi
     * que ahi el retardo puede vivir en el campo del comando que ya esta en la lista.
     * El VecFever no escribe T1LL jamas (226 vs 0 por frame era el resto gordo de la
     * comparacion); esto lo deja en 0.
     * Solo en SRAM: parchear la lista a posteriori rompe la firma de PSRAM, y el camino
     * SIO conserva el portador porque para el si es necesario. */
    if (s_count > 0u && d > 0) {
        uint8_t *p = &s_cmds[s_buf][(s_count - 1u) * 3u];
        uint32_t v = (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16);
        uint32_t cur  = v >> 12;
        uint32_t room = UVM2_CMD_MAX_DELAY - cur;
        uint32_t take = (uint32_t)d < room ? (uint32_t)d : room;
        v = (v & 0x0FFFu) | ((cur + take) << 12);
        p[0] = (uint8_t)v; p[1] = (uint8_t)(v >> 8); p[2] = (uint8_t)(v >> 16);
        s_ciclos += take;          /* este camino no pasa por emit: se cuenta a mano */
        d -= (int32_t)take;
    }
    while (d > 0) {                /* resto rarisimo (>4095): portadores encadenados */
        uint32_t chunk = d > (int32_t)UVM2_CMD_MAX_DELAY ? UVM2_CMD_MAX_DELAY : (uint32_t)d;
        emit(UVM2_VIA_T1LL, t1 & 0xFFu, chunk);
        d -= (int32_t)chunk;
    }
#else
    if (d > 4095) d = 4095;        /* el campo son 12 bits */
    emit(UVM2_VIA_T1LL, t1 & 0xFFu, (uint32_t)d);
#endif
}

static void vxs_y_held(void *ctx, int32_t vy) { (void)ctx; s_y = (int)vy; }

/* ¿El S&H de Y ya sostiene este valor? El dato ya se llevaba —`set_y` hace el mismo
 * `if (s_y == y) return;`— pero el emisor no podia consultarlo y volvia a emitir las tres
 * escrituras del muestreo y su ventana de carga. MEDIDO en dkong: la Y cambia en el 91% de
 * los vectores, asi que esto se dispara en el 9% restante; no es la palanca grande, pero
 * es exacta y no cuesta nada. */
static int vxs_y_can_skip(void *ctx, int32_t vy)
{
    (void)ctx;
#ifdef UVM2_SIN_ATAJO_Y
    /* PERILLA DE DIAGNOSTICO: nunca saltar el muestreo de Y. Existe porque este atajo es
     * la UNICA asimetria entre los dos ejes (X lee el DAC vivo, que se invalida solo; Y
     * cree recordar lo que sostiene un condensador), y el sintoma medido tambien es
     * asimetrico: en un frame, nuestra lista integra X 168 / Y 173 y el haz dibuja
     * X 207 / Y 45. Encenderla y volver a medir separa "el S&H no sostiene lo que
     * creemos" de cualquier otra causa, con una sola variable. */
    (void)vy; return 0;
#else
#ifdef VPY_MIDE_REDONDEO
    { extern volatile int sonda_a, sonda_b, sonda_c;
      sonda_a++; if (s_y == (int)vy) sonda_b++; sonda_c = s_y; }
#endif
    return s_y == (int)vy;
#endif
}

/* EL HAZ, PARA `keep_lit`. Sin estas dos el emisor cree SIEMPRE que el haz esta apagado:
 * con `uvm2_keep_lit = 1` tomaria la rama de "encender" en cada vector y no apagaria
 * nunca, o sea que el haz se quedaria encendido mientras se preparan los DAC del vector
 * siguiente y emborronaria la pantalla. Por eso van con el knob, no antes. */
static int  vxs_beam_is_lit(void *ctx)  { (void)ctx; return s_haz_encendido; }
static void vxs_beam_lit(void *ctx)     { (void)ctx; s_haz_encendido = 1; }
static void vxs_beam_blanked(void *ctx) { (void)ctx; s_haz_encendido = 0; }

/* X no tiene sample-and-hold: el DAC sostiene lo ULTIMO que se escribio en PORT_A, y de eso
 * ya lleva cuenta `s_porta` (lo actualiza `vxs_emit` en cada escritura, incluidas las del
 * muestreo de Y y el CLR a cero). Asi que no hace falta cache nueva: preguntarle a el es
 * exactamente la pregunta correcta, y se invalida solo. */
static int vxs_x_can_skip(void *ctx, int32_t vx)
{
    (void)ctx;
    return !s_porta_stale && s_porta == (uint8_t)(int8_t)vx;
}

static struct vx_sink vx_cart_sink(void)
{
    struct vx_sink s = { 0 };
    s.emit = vxs_emit;
    s.wait_ramp = vxs_wait_ramp;
    s.y_held = vxs_y_held;
    s.y_can_skip = vxs_y_can_skip;
    s.beam_is_lit = vxs_beam_is_lit;
    s.beam_lit = vxs_beam_lit;
    s.beam_blanked = vxs_beam_blanked;
    s.x_can_skip = vxs_x_can_skip;
    s.alargar_ultimo = vxs_alargar_ultimo;
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
/* 4, MEDIDO EN ESTA CONSOLA el 2026-08-27 y no heredado. Meseta: 11 (que es lo que venia
 * del cartucho propio), 8, 6, 4 y 2 dibujan bien JUGANDO —con saltos grandes de Y, que es
 * cuando el sample-and-hold lo pasa peor— y 0 ROMPE. Centro de la meseta: 4. Vale 5 de los
 * 93 ciclos por operacion. Era el hueco 12 del 6809 menos el ciclo de la escritura. */
/* LA PINZA DE CERO, que hasta hoy era una constante de peor caso.
 *
 * `UVM2_ZERO_BASE + s_scale/4` da 85 ciclos de E y se pagan ENTEROS en cada re-cero,
 * este el haz donde este. MEDIDO el 2026-08-27 leyendo por SWD la lista de comandos que
 * el cartucho estaba reproduciendo: 73 re-ceros por frame a 85 = 6205 ciclos, el 9,5%
 * del frame y el segundo gasto despues de la rampa.
 *
 * Y el 45 no sale de ningun sitio: su comentario dice "centring cost" y nada mas. La
 * BIOS no ayuda, porque NO ESPERA — `Reset0Ref` ($F354) pone /ZERO baja, hace el ciclo
 * de mux de Reset_Pen y RTS. En el Vectrex el cero se queda puesto mientras el 6809 se
 * va a hacer otra cosa, asi que alli la duracion la fija el programa, no la rutina, y no
 * hay un numero que copiar.
 *
 * Como no hay de donde derivarlo, se barre en consola con el dibujo delante, igual que
 * se hizo con y_mux. Cada ciclo que se le quite vale 73 ciclos de frame. Con 0 tiene que
 * ROMPER: es la prueba de que la perilla llega al dibujo.
 *
 * SOLO EL RE-CERO POR OBJETO. La pinza de fin de frame (uvm2_frame_end) se queda con la
 * constante: ocurre una vez, no pesa, y acortarla solo arriesga quemar un punto. */
/* El juego puede fijarlo en su Makefile (-DUVM2_ZERO_SETTLE_E=N) tras medirlo en su
 * consola; sin eso vale -1 y no cambia nada para nadie. */
#ifndef UVM2_ZERO_SETTLE_E
#define UVM2_ZERO_SETTLE_E (-1)
#endif
volatile int32_t uvm2_hueco_minimo = 0;   /* ver la nota de vxs_emit */
volatile int32_t uvm2_zero_settle_e = UVM2_ZERO_SETTLE_E;   /* <0 = ZERO_BASE + scale/4 */
/* El OFFSET del canal de referencia en el bloque de cero (idioma SR). Calibracion DE
 * MAQUINA, no constante del repo: la consola de la captura VecFever llevaba 0x07; 0
 * deja nuestra calibracion de siempre. Se barre en consola con el panel. */
/* LA REFERENCIA DE CERO. El bloque de cero carga este valor en el canal de referencia, y
 * ese canal es el ORIGEN del haz (dx = xsh - rsh, dy = rsh - ysh): si no es el que la
 * maquina espera, TODO el frame sale desplazado.
 *
 * 7, MEDIDO EN SU BLOQUE DE CERO. Comparando el nuestro con el suyo en el mismo frame de
 * Major Havoc, las nueve escrituras coinciden registro a registro y hueco a hueco salvo
 * esta: el escribe ORA=07 donde nosotros poniamos ORA=00. Encaja con lo que ya estaba
 * anotado — Vectorblade y PiTrex tambien escriben un valor NO CERO ahi, y la BIOS pone 0.
 *
 * Se puede sobreescribir por juego con -DUVM2_CERO_OFFSET si alguna consola pide otro:
 * esto es calibracion de maquina, no una constante universal. */
/* CADA CUANTAS RAMPAS SE VUELVE A PINZAR EL CERO.
 *
 * MEDIDO en su frame 120 de Major Havoc: el VecFever mete 12 bloques de cero en el CUERPO
 * del frame, separados 72, 66, 55, 73, 67, 57, 52, 55, 52, 61 y 59 rampas — mediana 59, y
 * mucho mas apretado por numero de rampas (12% de dispersion) que por tiempo (20%).
 *
 * NOSOTROS PINZABAMOS UNA VEZ POR FRAME, y el error de posicion se acumulaba durante las
 * 616 rampas sin que nada lo borrara: en consola, cada fila de la lista de records salia
 * mas a la derecha y mas abajo que la anterior, en escalera. La lista es correcta —
 * integrada como haz termina a 1,4 unidades de lo pedido— asi que lo que derivaba era el
 * INTEGRADOR, y contra eso lo unico que vale es volver al cero.
 *
 * ESTO ESTABA, PERO EN LA CAPA DE ARRIBA: `VPY_MAX_CONSECUTIVE_DRAWS` vive en
 * sdk_rp2350.c, o sea que solo lo tienen los puertos SBT. Un banco (o un juego) que llame
 * al SDK directamente no re-centraba NUNCA. Acotar la deriva no es una optimizacion de una
 * capa opcional: va aqui, y actua de SUELO — el contador lo pone a cero cualquier re-cero,
 * venga de donde venga, asi que si la capa de arriba ya pincha mas a menudo, este no salta.
 *
 * 0 lo apaga. */
#ifndef UVM2_CERO_CADA
#define UVM2_CERO_CADA 0   /* la red por CUENTA: apagada, la manda la distancia (UVM2_CERO_SALTO) */
#endif
volatile int32_t uvm2_cero_cada = UVM2_CERO_CADA;

/* RE-CENTRAR CUANDO EL SALTO ES LARGO — SU CRITERIO, MEDIDO.
 *
 * Emparejando cada transporte en blanco de sus capturas con si lleva bloque de cero
 * delante, sobre 2020 transportes de 8 frames:
 *
 *     los 66 que re-centra:  minimo 20,1  mediana 42,0  maximo 82,0 unidades
 *     los 1954 que no:       p90 3,5   p99 20,2   maximo 37,1
 *
 * O sea: **re-centra cuando el haz va a viajar lejos**, no cada N rampas. Con el umbral en
 * 20 aciertan los 66 de 66 y solo 22 de 1954 (1,1%) serian de mas. Y tiene sentido fisico:
 * un salto largo es donde mas pesa el error acumulado y donde el re-cero sale gratis,
 * porque el haz va a cruzar la pantalla de todas formas.
 *
 * NOSOTROS re-centrabamos por CUENTA DE RAMPAS, y eso deja pasar los saltos largos: medido
 * en mhavoc, transportes de hasta 102 unidades sin re-centrar. En consola se veia como
 * objetos que se descolocan de un frame a otro — "latidos".
 *
 * 0 lo apaga; `uvm2_cero_cada` sigue de red de seguridad por si una escena no tiene saltos
 * largos. */
#ifndef UVM2_CERO_SALTO
#define UVM2_CERO_SALTO 20
#endif
volatile int32_t uvm2_cero_salto = UVM2_CERO_SALTO;

/* Emitir el pen-up cuando el salto pedido mide CERO. Ver move_abs_interno. */
#ifndef UVM2_PENUP_CERO
/* 0 POR DEFECTO, Y NO POR PRUDENCIA: con la geometria del banco no se puede saber cuando
 * toca. Sus 12 pen-ups llevan SR=00/SR=01 alrededor, pero `vf_geom_mh.h` solo guarda los
 * segmentos ILUMINADOS — donde el levanto el lapiz no esta en el fichero. Encendido dispara
 * en los 240 encadenados (contra sus 12) y hunde el parecido del transporte del 91,6% al
 * 41,7%. Se queda para cuando la entrada traiga esa informacion. */
#define UVM2_PENUP_CERO 0
#endif
volatile int32_t uvm2_penup_cero = UVM2_PENUP_CERO;

/* La escalera de duraciones del salto y su tope de tasa. Ver move_una. 0 la apaga. */
#ifndef UVM2_ESCALERA_SALTO
#define UVM2_ESCALERA_SALTO 1
#endif
volatile int32_t uvm2_escalera_salto = UVM2_ESCALERA_SALTO;
volatile int32_t uvm2_escalera_tope  = 120;

/* EL JUEGO AVISA DE QUE VA A LEVANTAR EL LAPIZ. Lo pone antes de un `move_abs`, y solo se
 * consume si ese salto resulta medir CERO — si mueve, el propio salto ya apaga. Hace falta
 * porque "apago y volvi a encender" y "segui encendido" dan la MISMA geometria: sin este
 * aviso, dos trazos contiguos se unen con una esquina que el no dibuja. */
static int s_penup_pendiente;
void uvm2_draw_penup(void) { s_penup_pendiente = 1; }

/* Cuantos "pasos de arranque" tiene que medir un salto para merecer el arranque suave.
 * Su umbral medido esta en tasa >= 100, o sea unas 20 veces el paso. 0 lo apaga. */
#ifndef UVM2_ARRANQUE_SUAVE
#define UVM2_ARRANQUE_SUAVE 124
#endif
/* La TASA a partir de la cual el salto lleva unidad diminuta delante. 124 es su minimo
 * medido; por debajo de 124 el no ceba NUNCA (0 de 179). 0 lo apaga. */
volatile int32_t uvm2_arranque_suave = 124;

/* EL CIERRE DE FRAME DEL VECFEVER: ni recalibracion a los railes ni silencio al final.
 *
 * Va con el idioma del SR porque es su metodo, no una perilla suelta. A 0 vuelve el cierre
 * de la BIOS que teniamos —dos barridos a los railes por frame y `uvm2_bus_delay` para el
 * resto—, que es a lo que hay que volver si apareciera deriva frame a frame. */
#ifndef UVM2_CIERRE_VECFEVER
#define UVM2_CIERRE_VECFEVER 1
#endif
volatile int32_t uvm2_cierre_vecfever = UVM2_CIERRE_VECFEVER;
#define CIERRE_VECFEVER (HAZ_POR_SR && uvm2_cierre_vecfever)

/* EL RELLENO VA APARTE DEL CIERRE, porque las dos mitades no cuestan lo mismo.
 *
 * Medido en el emulador con mhavoc, 199 frames: quitar la recalibracion sale GRATIS (117
 * frames dibujados contra 114 con ella), pero anadir el relleno baja a 86 — un 26%. El bus
 * tarda lo mismo en los dos casos (los dos cierran el frame en 30000 ciclos; lo que cambia
 * es que uno los gasta con 220 comandos y el otro callado), asi que el coste no esta en el
 * bus sino en construir y reproducir esos comandos.
 *
 * Y ahi el emulador puede estar cobrando de mas: reproduce el bucle de core 1 instruccion a
 * instruccion, mientras que en la placa son 220 comandos mas en la MISMA lista y el MISMO
 * DMA. No se ha podido comprobar en consola. Se deja encendido —es su metodo y hace que el
 * frame cadencie como el suyo— con el knob a mano para el A/B. */
#ifndef UVM2_RITMO_VECFEVER
#define UVM2_RITMO_VECFEVER 1
#endif
volatile int32_t uvm2_ritmo_vecfever = UVM2_RITMO_VECFEVER;
#define RITMO_VECFEVER (HAZ_POR_SR && uvm2_ritmo_vecfever)

#ifndef UVM2_CERO_OFFSET
/* EL VALOR QUE SE CEBA EN LA REFERENCIA DE CERO. 0x23 (35) es el de fabrica de Vectorblade
 * para su texto (`calibrationValue16`); para trazos largos el usa 0x56 (86). Estaba en 7, o
 * sea practicamente en el 0 de la BIOS, que es lo que [[zero-reference-calibration]] ya
 * decia que estaba mal. Se calibra por consola, que para eso esta el asistente. */
#define UVM2_CERO_OFFSET 0x23
#endif
volatile int32_t uvm2_cero_offset = UVM2_CERO_OFFSET;
volatile int32_t uvm2_y_mux_e = 4;
volatile int32_t uvm2_keep_lit  = 0;
/* El juego puede fijarlo (-DUVM2_BLANK_SETTLE_E=N) tras barrerlo en su consola. */
#ifndef UVM2_BLANK_SETTLE_E
#define UVM2_BLANK_SETTLE_E 12
#endif
volatile int32_t uvm2_blank_settle_e = UVM2_BLANK_SETTLE_E;  /* ciclos de E encendido tras parar */
/* ASENTAMIENTO DEL DAC EN X, antes de arrancar la rampa. Ver x_settle_q8 en emit.rs: la Y
 * llega muestreada y retenida tras `y_mux` ciclos de ventana, y la X va directa al DAC con
 * la rampa arrancando tres comandos despues. 0 = como siempre. */
volatile int32_t uvm2_x_settle_e = 0;

/* EL ASENTAMIENTO DEL SALTO. Era `k.moveto_settle_q8 = 0u` a fuego, el UNICO de los seis
 * terminos de vx_timings que no salia de una perilla — y sin una medida detras.
 *
 * Lo que hace: un salto apagado termina su rampa y el amplificador todavia esta llegando.
 * Con 0 no se compensa nada, asi que el haz aterriza CORTO y todo lo que se dibuje despues
 * arranca del sitio equivocado. En un dibujo cuyo contorno es una polilinea continua (sin
 * saltos) y cuyo detalle interior son trazos sueltos (con salto delante), el sintoma es
 * exactamente el que se ve en consola: contorno perfecto, interior desplazado.
 *
 * Se deja en 0 —el valor que habia— para no cambiar nada al introducirlo: lo que cambia es
 * que ahora SE PUEDE MEDIR, con el banco `unvec` y el panel, en vez de discutirlo. */
volatile int32_t uvm2_moveto_settle_e = 0;
/* Periodo del frame en CICLOS DE BUS, 0 = libre. Arranca en lo que diga UVM2_HZ para no
 * cambiarle el comportamiento a nadie; el panel lo mueve en caliente. 30000 = 50 Hz. */
/* `used`: sin esto --gc-sections se lo lleva y el panel no lo encuentra. Le paso a este
 * y no a los otros knobs porque a aquellos los referencia vx_cart_timings; a este solo lo
 * mira uvm2_frame_end, y el enlazador decidio que sobraba. Un knob que no esta en el ELF
 * no se puede tocar en caliente, que es todo el punto. */
/* Lo que tardo en dibujarse el ultimo frame, SIN el relleno del enganche. Separado de
 * `s_frame_cycles` a proposito: aquel vale el periodo cuando el frame cupo, asi que no
 * sirve para saber si cabe. */
static uint32_t s_dibujo_cycles;

/* EL REFRESCO EN HERCIOS. Ver la nota de uvm2_draw.h: es una opcion del JUEGO porque tiene
 * que coincidir con la frecuencia de la TOMA DE CORRIENTE, no con ninguna preferencia
 * nuestra. La division se hace aqui una vez y no en cada juego. */
void uvm2_refresco(unsigned hz)
{
    uvm2_pacer_cycles = hz ? (UVM2_BUS_HZ / hz) : 0u;
}

unsigned uvm2_refresco_actual(void)
{
    return uvm2_pacer_cycles ? (UVM2_BUS_HZ / uvm2_pacer_cycles) : 0u;
}

int uvm2_refresco_cabe(void)
{
    return uvm2_pacer_cycles == 0u || s_dibujo_cycles <= uvm2_pacer_cycles;
}

__attribute__((used)) volatile uint32_t uvm2_pacer_cycles =
#if UVM2_HZ == 0
    0u;
#else
    UVM2_CYCLES_PER_FRAME;
#endif

static struct vx_timings vx_cart_timings(void)
{
    /* A CERO DE ENTRADA. Se llenaba campo a campo y un campo nuevo que se olvidara sale
     * con basura de pila — y un hueco basura satura el campo de 12 bits del comando y
     * dispara el frame (paso: 788.661 ciclos con un ORA+4096). */
    struct vx_timings k = (struct vx_timings){0};
    k.e6809_q8 = 64u;
    k.y_mux_q8 = (uint32_t)(uvm2_y_mux_e > 0 ? uvm2_y_mux_e : 0) * 256u;
    k.moveto_settle_q8 = (uint32_t)(uvm2_moveto_settle_e > 0 ? uvm2_moveto_settle_e : 0) * 256u;
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
/* LA UNIDAD INTERNA DEL DIBUJANTE. Con -DUVM2_SUBUNIDAD las posiciones y los deltas van
 * en 1/16 de unidad de dispositivo en TODO el camino; sin el, en enteros, exactamente como
 * antes (y `ramp_params_q` con valores enteros exactos da lo mismo bit a bit que el camino
 * viejo — hay un test que lo comprueba).
 *
 * POR QUE. `VS_RND` en sdk_rp2350.c divide las coordenadas del juego por 127 y REDONDEA A
 * ENTERO antes de que nadie las vea. MEDIDO en mhavoc sobre 81.552 vectores: 0,22 unidades
 * de error por eje, el 3,6% de los vectores enteramente sub-unidad y el 0,26%
 * desapareciendo porque sus dos extremos caen en el mismo punto. La rejilla del VecFever es
 * ~1/20 de unidad (la granularidad de la tasa a t1=8): eramos diez veces mas bastos.
 *
 * La deuda de la cadena NO tapaba esto: corrige el residuo de la RAMPA, y recibia i8, o sea
 * ya redondeado. Son dos perdidas distintas. */
/* CUANTOS BITS DE FRACCION lleva la entrada. 4 (1/16) es lo que usan los puertos; el banco
 * de comparacion con el VecFever pide 8 porque a 1/16 el 10,5% de sus tasas no se pueden
 * reproducir — su vector de tasa 32 con t1 = 8 mide 1,6 unidades exactas y 1/16 solo sabe
 * decir 1,5625 o 1,625. Con 1/64 o mas fino salen las 210 del frame EXACTAS. */
#ifdef UVM2_SUBUNIDAD
#ifndef UVM2_Q_BITS
#define UVM2_Q_BITS 4
#endif
#define UVM2_Q (1 << UVM2_Q_BITS)
#else
#define UVM2_Q_BITS 0
#define UVM2_Q 1
#endif

#define UVM2_MAX_PASO (127 * UVM2_Q)



static void move_abs_interno(int x, int y);

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

/* CUANTO CORRE UNA RAMPA DE ARRANQUE, en unidades internas: tasa 1 durante 8 cuentas de
 * T1. No es un numero elegido — sale de las mismas constantes que el resto del dibujo. */
static int paso_arranque(void)
{
    int q = (8 * (1 << UVM2_Q_BITS)) / (int)DRAW_SCALE;
    return q > 0 ? q : 1;
}

static void move_una(int dx, int dy)
{
    /* EL SALTO NO LLEVA DEUDA — Y ESO DEJA UNA DERIVA CONOCIDA, SIN CERRAR.
     *
     * Medido sobre los deltas reales de dkong (60 frames, 1416 saltos): la posicion se va
     * -47,2 unidades en X y -88,7 en Y, porque el salto tambien es una rampa que redondea
     * y aqui su error se TIRA. Los trazos, que si van encadenados, se quedan en +0,4.
     *
     * Se probo lo evidente —encadenar tambien los saltos— y SALE PEOR: la deuda que el
     * salto no consigue absorber la acaba pagando el siguiente trazo ILUMINADO, que se
     * dobla. En la rejilla las filas pasaron de planas (desvio 0, exactas) a empezar 378
     * unidades mas arriba y caer 189 a lo largo. Una linea recta torcida se ve mucho mas
     * que un origen desplazado.
     *
     * Lo que hace falta es que el salto ABSORBA la deuda entero durante el tramo apagado
     * —donde corregir no se ve— y no que la reparta. Eso no esta hecho. */
    vx_chain_reset();

    /* EL ARRANQUE SUAVE DE LOS SALTOS RAPIDOS.
     *
     * MEDIDO en su frame 120 de Major Havoc: 20 de sus 26 saltos de tasa >= 100 (77%) van
     * precedidos de una unidad DIMINUTA — t1 = 8 en las 20, tasa |v| <= 4 (casi siempre
     * +-1) y en el MISMO SENTIDO que el salto (X: 20 de 20, Y: 17 de 20). Y 10 de sus 12
     * salidas de re-cero empiezan asi. Nosotros no lo haciamos NUNCA, ni una vez.
     *
     * Fisicamente es lo que parece: tras la pinza de cero los integradores estan parados, y
     * una rampa que arranca del reposo a tasa 124 recorre de menos. La unidad previa los
     * pone en movimiento. El sintoma en consola era el banco con las filas APELOTONADAS
     * hacia el centro —cada objeto caia corto— con la lista geometricamente CORRECTA:
     * error de posicion por trazo, mediana 0,01 en X y 0,06 en Y, peor caso 0,42.
     *
     * Su recorrido se DESCUENTA del salto, asi que la posicion final no cambia. */
    int forzada = 0;
    int32_t px_ = 0, py_ = 0; uint32_t pt1_ = 0;   /* la rampa larga, para emitirla tal cual */
    if (uvm2_arranque_suave > 0) {
        /* SU CRITERIO ES LA TASA DEL SALTO, NO SU DISTANCIA. Medido sobre sus 198
         * transportes que mueven algo: los 19 que llevan unidad diminuta delante tienen
         * tasa 124..126, y de los 179 que no la llevan **ninguno** llega a 124. Separacion
         * perfecta, sin solape.
         *
         * Antes esto disparaba por distancia y lo hacia en 41 de 43 saltos, contra sus 19 de
         * 198 — por eso en consola salio peor. El error era el umbral, no la idea. */
#if UVM2_Q_BITS > 0
        vx_ramp_params_salto_qn(dx, dy, UVM2_Q_BITS, &px_, &py_, &pt1_);
#else
        vx_ramp_params_salto(dx, dy, &px_, &py_, &pt1_);
#endif
        const int tasa = (px_ < 0 ? -px_ : px_) > (py_ < 0 ? -py_ : py_)
                       ? (px_ < 0 ? -px_ : px_) : (py_ < 0 ? -py_ : py_);
        if (tasa >= uvm2_arranque_suave) {
            /* LA UNIDAD DIMINUTA LLEVA EL RESIDUO, no un paso fijo.
             *
             * Comprobado en su aritmetica: en su transporte #45 el salto pide -20,25
             * unidades en X; su rampa principal (-124, t1=26) recorre -20,15; el residuo es
             * -0,10, que a t1 = 8 son -2 — y -2 es exactamente lo que emite. En Y, igual.
             * O sea que primero elige la rampa larga y lo que le sobra lo mete delante.
             *
             * Poniendo +-1 fijo aciertan 5 de 22; con el residuo, la unidad diminuta sale
             * con SU valor. */
            const int t1p = 8;
            /* EL SALTO PRINCIPAL SE TRUNCA, NO SE REDONDEA, cuando lleva cebado delante.
             *
             * `vx_ramp_params_salto` redondea al mas cercano, asi que la rampa larga puede
             * PASARSE y dejar un residuo del signo contrario — y entonces la unidad diminuta
             * empuja hacia atras. El VecFever se queda corto y el residuo va en el mismo
             * sentido que el salto.
             *
             * MEDIDO en su #45: pide -20,25 unidades; a t1 = 26 la tasa exacta es -124,6.
             * Redondeando sale -125 (lo nuestro), truncando -124 (lo suyo), y con -124 el
             * residuo es -0,10, que a t1 = 8 son los -2 que el emite. */
            {
                const long rec = ((long)px_ * (long)pt1_ * (1L << UVM2_Q_BITS)) / (long)DRAW_SCALE;
                if ((dx > 0 && rec > dx) || (dx < 0 && rec < dx)) px_ += (px_ > 0 ? -1 : 1);
                const long rey = ((long)py_ * (long)pt1_ * (1L << UVM2_Q_BITS)) / (long)DRAW_SCALE;
                if ((dy > 0 && rey > dy) || (dy < 0 && rey < dy)) py_ += (py_ > 0 ? -1 : 1);
            }
            /* Lo que recorre la rampa principal, en unidades internas (mismo redondeo que
             * `recorrido_mil` del modelo: v * t1 / DRAW_SCALE). */
            const int rec_x = (int)(((long)px_ * (long)pt1_ * (1L << UVM2_Q_BITS)) / (long)DRAW_SCALE);
            const int rec_y = (int)(((long)py_ * (long)pt1_ * (1L << UVM2_Q_BITS)) / (long)DRAW_SCALE);
            const int res_x = dx - rec_x, res_y = dy - rec_y;
            if (res_x || res_y) {
                int32_t ax, ay; uint32_t at1;
#if UVM2_Q_BITS > 0
                vx_ramp_params_salto_qn(res_x, res_y, UVM2_Q_BITS, &ax, &ay, &at1);
#else
                vx_ramp_params_salto(res_x, res_y, &ax, &ay, &at1);
#endif
                if (at1 > (uint32_t)t1p) at1 = (uint32_t)t1p;   /* el suyo es SIEMPRE t1 = 8 */
                struct vx_sink s0 = vx_cart_sink();
                struct vx_timings k0 = vx_cart_timings();
                /* DETRAS DE ESTA VIENE LA RAMPA LARGA, asi que el haz se apaga ANTES de
                 * esta unidad y no dentro de su ventana de mux. Ver SIGUEN_UNIDADES. */
                SIGUEN_UNIDADES = 1;
                vx_moveto_seq(&s0, ax, ay, at1, &k0);
                SIGUEN_UNIDADES = 0;
                s_pos_x += res_x; s_pos_y += res_y;
                dx -= res_x; dy -= res_y;
                s_rampas_desde_cero++;
                uvm2_stats.moves++;
                uvm2_stats.ramp_cycles += at1;
                vx_chain_reset();
                /* Y LA RAMPA LARGA SE EMITE TAL COMO SE CALCULO, no recalculada sobre el
                 * delta ya reducido: quitarle el residuo la acorta un t1 y la tasa se va a
                 * 127-128. Medido en su #45 —el emite (-124, t1=26) y a nosotros nos salia
                 * (-128, t1=25)— y en su #393. El VecFever elige la rampa PRIMERO y lo que
                 * le sobra lo mete delante; no al reves. */
                forzada = 1;
            }
        }
    }

    {
        int32_t vx, vy; uint32_t t1;
        s_pos_x += dx;
        s_pos_y += dy;
        /* SIN DEUDA, Y AHORA CON EL NUMERO DE POR QUE. Se probo darle a los saltos su
         * PROPIA deuda (separada de la de los trazos, para no contaminarlos, que es lo
         * que esta nota pedia) y MEDIDO sobre los 255 saltos reales de un frame de
         * asterock: el error acumulado sube de 86,8 a 99,8 unidades en X y de 91,6 a
         * 100,6 en Y. EMPEORA, y por una razon que ahora se ve: el error del salto NO
         * es un residuo fraccionario que otro pueda absorber —es un SESGO POR SIGNO del
         * modelo de rampa (delta X negativo se queda 1,3 unidades corto, delta Y
         * positivo se pasa 3,9; las otras dos direcciones son exactas)— y pedir
         * "delta + deuda" solo lo mueve a otro delta con otro sesgo. Arreglar el sesgo
         * es lo que hay que hacer; repartirlo, no. */
        /* CON EL TOPE DE VELOCIDAD DE LOS SALTOS, no el de los trazos. El haz va apagado:
         * frenarlo no da brillo, solo gasta frame. Medido en la captura del VecFever: el
         * salta a 1,8x la velocidad a la que dibuja (tasa mediana 64 contra 35), y a
         * nosotros un salto nos costaba ~267 ciclos contra sus ~32. */
if (forzada) { vx = px_; vy = py_; t1 = pt1_; } else {
#if UVM2_Q_BITS > 0
        vx_ramp_params_salto_qn(dx, dy, UVM2_Q_BITS, &vx, &vy, &t1);
#else
        vx_ramp_params_salto(dx, dy, &vx, &vy, &t1);
#endif
        /* LA ESCALERA DE DURACIONES DEL SALTO.
         *
         * El VecFever no CALCULA el t1 de un salto: lo ELIGE de {8, 18, 31}, el primer
         * peldaño cuya tasa no pase de 120. Medido en sus 1041 saltos que siguen a un trazo,
         * esa regla explica 1008 (97%), y en su frame 120 los explica TODOS — incluidos los
         * tres que se resistian, donde el pone 18 y a nosotros nos salia 9, 13 y 15.
         *
         * Solo actua si algun peldaño CABE: en los saltos largos manda el calculo de antes. */
        if (uvm2_escalera_salto) {
            static const uint32_t PELDANOS[3] = { 8u, 18u, 31u };
            /* LA DISTANCIA SALE DEL DELTA, NO DE LA RAMPA.
             *
             * Sacarla de (tasa x t1) parece equivalente y no lo es: si esa rampa SATURO en
             * +-127, no cubre el delta entero y la distancia sale corta — con lo que la
             * escalera elegia un peldaño que no cabe y las tasas volvian a saturar. El
             * sintoma era (127,127) en un salto de X puro, con vy = 127 donde dy = 0. */
            const int adx = dx < 0 ? -dx : dx, ady = dy < 0 ? -dy : dy;
            const long m_q = adx > ady ? adx : ady;          /* en unidades internas */
            for (unsigned e = 0; e < 3u; e++) {
                /* cabe si  m_q * escala / (Q * peldaño)  <=  tope */
                if (m_q * (long)DRAW_SCALE
                    <= (long)uvm2_escalera_tope * (long)UVM2_Q * (long)PELDANOS[e]) {
                    if (PELDANOS[e] != t1) {
                        t1 = PELDANOS[e];
                        vx_ramp_params_con_t1(dx, dy, UVM2_Q, t1, &vx, &vy);
                    }
                    break;
                }
            }
        }
        }
        struct vx_sink sink = vx_cart_sink();
        struct vx_timings k = vx_cart_timings();
        vx_moveto_seq(&sink, vx, vy, t1, &k);
        s_rampas_desde_cero++;
        uvm2_stats.moves++;
        uvm2_stats.ramp_cycles += t1;
    }
}

void uvm2_draw_move(int dx, int dy){ trocear(dx, dy, move_una); }


/* LA DIFUSION VIVE EN LA CAJA COMPARTIDA. Estuvo aqui unas horas, y en el emulador habia
 * otra copia, y el firmware del cartucho propio no la tenia — tres decisiones distintas
 * sobre la misma regla, que es la forma de divergencia que llevamos el dia entero pagando.
 * Ahora es `vx_ramp_params_chain` en vectrex-draw, y los tres la usan. */
static void delta_una(int dx, int dy)
{
    int32_t vx, vy; uint32_t t1;
#ifdef VPY_MIDE_REDONDEO
    /* SONDA: el delta que de verdad le llega a la rampa, y lo que devuelve. Por el lado C
     * porque un static de Rust se lo lleva --gc-sections aunque sea #[no_mangle]. */
    { extern volatile unsigned vpy_red_n, vpy_red_err_c, vpy_red_subunidad, vpy_red_cero;
       }
#endif
    s_pos_x += dx;
    s_pos_y += dy;

#if UVM2_Q_BITS > 0
    vx_ramp_params_chain_qn(dx, dy, UVM2_Q_BITS, &vx, &vy, &t1);
#else
    vx_ramp_params_chain(dx, dy, &vx, &vy, &t1);
#endif

    struct vx_sink sink = vx_cart_sink();
    struct vx_timings k = vx_cart_timings();
    vx_draw_line_seq(&sink, vx, vy, t1, &k);
    s_rampas_desde_cero++;
    uvm2_stats.vectors++;
    uvm2_stats.ramp_cycles += t1;
}

void uvm2_draw_delta(int dx, int dy){ trocear(dx * UVM2_Q, dy * UVM2_Q, delta_una); }

/* LA MISMA EN 1/16 DE UNIDAD. Es la que deja pedir lo que el entero no puede — un trazo de
 * 2,5 unidades, o uno de media, que en enteros DESAPARECE. Sin -DUVM2_SUBUNIDAD redondea a
 * entero y se comporta como la de arriba, para que un juego pueda llamarla siempre. */
void uvm2_draw_delta_q4(int dx_q4, int dy_q4)
{
#if UVM2_Q_BITS > 0   /* la unidad de la API es la INTERNA; ver UVM2_Q_BITS */
    trocear(dx_q4, dy_q4, delta_una);
#else
    trocear((dx_q4 + (dx_q4 < 0 ? -8 : 8)) / 16, (dy_q4 + (dy_q4 < 0 ? -8 : 8)) / 16, delta_una);
#endif
}

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
    /* Con cadena como cualquier otro trazo: que lleve huecos no cambia que es una rampa
     * que redondea. Quedaba con la plana porque dkong no pasa por aqui y nadie lo miro. */
#if UVM2_Q_BITS > 0   /* la unidad de la API es la INTERNA; ver UVM2_Q_BITS */
    vx_ramp_params_chain_q4(dx, dy, &vx, &vy, &t1);
#else
    vx_ramp_params_chain(dx, dy, &vx, &vy, &t1);
#endif
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

/* ── AQUI HUBO UNA "CAPA DE TASAS" (uvm2_draw_rate / uvm2_draw_raw), Y ERA UN ERROR ───
 *
 * La escribi para que un banco de pruebas pudiera reproducir el stream del VecFever sin
 * redondear posiciones: le pasabas (vy, vx, t1, sr, hueco) y emitia el microtramo. Daniel
 * lo corto en cuanto lo vio, y con razon: **eso convierte al SDK en un tubo**. Si el banco
 * le da las tasas, los tiempos y los huecos ya hechos, lo que se comprueba es que el tubo
 * transporta lo que se le mete — no que NUESTRO modelo genere las llamadas correctas. Para
 * reproducir un stream ajeno tal cual ya existe `vfplay`, que usa `uvm2_exec` y no finge
 * ser otra cosa.
 *
 * Lo que se compara tiene que entrar por la puerta de un juego: `uvm2_draw_intensity`,
 * `_move_abs`, `_delta`. Que el SDK elija tasa, tiempo, troceado y re-ceros es
 * PRECISAMENTE lo que esta a prueba.
 *
 * El motivo tecnico por el que la escribi sigue siendo cierto y queda anotado: las
 * posiciones que alcanza el haz son fraccionarias (v*t1/DRAW_SCALE: 127*8/160 = 6,35) y la
 * API toma enteros, asi que la distancia de un salto puede diferir menos de una unidad y
 * mover su t1 en 1-2 cuentas. Eso es un limite de dar coordenadas, y un juego da
 * coordenadas: es el comportamiento correcto, no un defecto que tapar. */

/* LAS DOS PUBLICAS CONVIERTEN A LA UNIDAD INTERNA; EL CUERPO VIVE ABAJO.
 *
 * Aqui metí la pata la primera vez encadenandolas —la entera llamaba a la de 1/16 tras
 * multiplicar por UVM2_Q— y sin el define eso multiplicaba por 1 y dividia por 16: el
 * dibujo se encogia y los saltos pasaban de 180 a 406 por frame. La conversion tiene que
 * estar en CADA entrada, no en cadena. */
void uvm2_draw_move_abs(int x, int y) { move_abs_interno(x * UVM2_Q, y * UVM2_Q); }

void uvm2_draw_move_abs_q4(int x_q4, int y_q4)
{
#if UVM2_Q_BITS > 0   /* la unidad de la API es la INTERNA; ver UVM2_Q_BITS */
    move_abs_interno(x_q4, y_q4);
#else
    move_abs_interno((x_q4 + (x_q4 < 0 ? -8 : 8)) / 16,
                     (y_q4 + (y_q4 < 0 ? -8 : 8)) / 16);
#endif
}

/* El cuerpo, en la unidad interna: `s_pos_*` va en esa misma unidad, asi que la resta es
 * directa y no hay ninguna conversion escondida aqui dentro. */
static void move_abs_interno(int x, int y)
{
    /* EL SUELO DE DERIVA. Va en el salto y no en el trazo a proposito: pinzar el cero
     * arrastra el haz al centro, asi que solo puede hacerse donde el dibujo ya iba a
     * saltar. `uvm2_draw_reset` deja `s_pos` en (0,0), de modo que el salto de abajo se
     * recalcula solo desde el origen. Ver uvm2_cero_cada. */
    {
        /* La distancia del transporte, en unidades de dispositivo. Se mide ANTES de saltar
         * porque el re-cero deja `s_pos` en el origen y despues ya no se sabe. */
        const int dx = x - s_pos_x, dy = y - s_pos_y;
        const int ax = dx < 0 ? -dx : dx, ay = dy < 0 ? -dy : dy;
        const int m = (ax > ay ? ax : ay) >> UVM2_Q_BITS;
        /* EL SENTIDO, NO SOLO LA DISTANCIA.
         *
         * Medido en su frame 120: las distancias de los transportes donde re-centra y donde
         * no SE SOLAPAN (20,3 contra 20,2), asi que el umbral solo no separa. Lo que separa
         * es el signo de X: en los 10 que re-centra va NEGATIVO (-20,2 ... -25,4) y en los 9
         * que no, POSITIVO (+20,2 ... +24,6). Es el retorno de carro —el salto que vuelve al
         * principio de la fila siguiente— frente al que avanza dentro de la fila.
         *
         * Sin esto disparabamos 20 veces contra sus 11, y los 9 de mas dejaban el haz en
         * otro sitio: sus saltos siguientes iban +X y los nuestros -Y, con el t1 creciendo
         * fila a fila (14, 21, 29, ... 67).
         *
         * LA REGLA ESTA INCOMPLETA Y SE SABE: sobre sus 11 frames acierta 56 de 87 re-ceros
         * con solo 4 falsos positivos. O sea que nunca sobra, pero le falta un segundo
         * criterio que en otras pantallas si dispara — probablemente "uno por objeto", que
         * la geometria no trae. */
        const int largo = uvm2_cero_salto > 0 && m >= uvm2_cero_salto && dx < 0;
        const int muchas = uvm2_cero_cada > 0 && s_rampas_desde_cero >= (uint32_t)uvm2_cero_cada;
        if (largo || muchas) uvm2_draw_reset();
    }
    int dx = x - s_pos_x;
    int dy = y - s_pos_y;
    if (dx != 0 || dy != 0) s_penup_pendiente = 0;   /* el salto ya apaga por su cuenta */
    if (dx == 0 && dy == 0) {
        /* LEVANTAR EL LAPIZ AUNQUE NO HAYA QUE MOVERSE.
         *
         * El juego pide un salto de distancia CERO: el trazo siguiente empieza donde acabo
         * el anterior. Aqui se volvia sin emitir nada, y con keep-lit eso deja el haz
         * ENCENDIDO entre los dos — o sea que dibujamos la esquina que los une. El juego
         * pidio un salto: queria separarlos.
         *
         * MEDIDO en su frame 120: el emite 12 unidades `(0, 0, t1=8)` —rampa de 8 ciclos
         * sin mover, con el haz apagado— y las DOCE llevan `SR=00` y `SR=01` alrededor. Los
         * 228 encadenados de verdad no tienen ninguna escritura al SR. O sea que esa unidad
         * ES el pen-up de distancia cero, y nosotros emitiamos cero de 12. */
        const int avisado = s_penup_pendiente;
        s_penup_pendiente = 0;
        if ((uvm2_penup_cero || avisado) && s_haz_encendido) {
            int32_t vx, vy; uint32_t t1;
#if UVM2_Q_BITS > 0
            vx_ramp_params_salto_qn(0, 0, UVM2_Q_BITS, &vx, &vy, &t1);
#else
            vx_ramp_params_salto(0, 0, &vx, &vy, &t1);
#endif
            struct vx_sink sink = vx_cart_sink();
            struct vx_timings k = vx_cart_timings();
            vx_moveto_seq(&sink, 0, 0, t1, &k);   /* tasas a cero: no mueve, solo separa */
            s_rampas_desde_cero++;
            uvm2_stats.moves++;
            vx_chain_reset();
        }
        return;
    }
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

    /* El barrido a los railes es el movimiento mas largo del frame: encendido, es la
     * diagonal mas brillante de la pantalla. Apagar aqui y no confiar en que el frame
     * llego apagado. */
    haz_apagar();

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
    s_ciclos = 0;
    s_limite = UVM2_CMD_CAPACITY - UVM2_CMD_RESERVA;
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
    /* LA Z DE REPOSICION SOBRA EN EL CAMINO DEL VECFEVER. Estaba para que el haz no
     * corriera con una Z indefinida entre soltar la pinza y el primer SET_INTENSITY del
     * juego; ahora la pinza la suelta el bloque de cero, que va DESPUES de esa Z, asi que
     * el hueco que tapaba ya no existe. En su frame no hay ninguna: escribiendola cargabamos
     * C306 dos veces por frame — la nuestra y la del juego — para el mismo valor. */
    if (!HAZ_POR_SR) set_z(s_z_last, UVM2_HOLD_DELAY);

    /* Only now release the clamp that has held the beam at centre since the
     * last frame ended.  The clamp covers the whole inter-frame gap and the
     * priming above, so no drift reaches the screen and the holds are charged
     * against a beam that is actually at zero. */
#ifndef UVM2_HOLD_ZERO
    /* LA PINZA LA SUELTA EL BLOQUE DE CERO, COMO EL. En su frame la secuencia es
     * prologo -> Z del juego -> bloque de cero (que acaba en PCR=CE), y no hay ningun
     * PCR=CE suelto antes. Soltarla aqui tenia ademas un efecto que no se buscaba: dejaba
     * `s_pcr` con el bit de suelta puesto, y con eso el primer `uvm2_draw_reset` del frame
     * se creia "ya centrado y suelto" y se SALTABA el bloque entero - o sea que el frame
     * empezaba sin re-cero, confiando en que el centro seguia donde lo dejo el frame
     * anterior. Con la pinza puesta, ese mismo `if` deja pasar el bloque. */
    if (!HAZ_POR_SR) set_zero(0, 0);
#endif
}

/* Por BUFFER, no una sola: con doble buffer core 0 firma el frame que acaba de
 * construir y core 1 reproduce el ANTERIOR. Comparar las dos sin indexar es
 * comparar frames distintos, que nunca coinciden y no dice nada. */
uint32_t uvm2_firma_escrita[2], uvm2_firma_n[2];

/* EL PERIODO DEL FRAME SE MIDE EN LOS DOS CAMINOS.
 *
 * Estaba al final de uvm2_frame_end, y el camino de DOBLE NUCLEO vuelve mucho antes:
 * asi que en todo build de doble nucleo —o sea, en el que corre de verdad— us_frame_last,
 * us_frame_min/max y frames_lentos se quedaban a cero PARA SIEMPRE. Y un contador a cero
 * se lee igual que "no hace falta". Se saco aqui para que lo llamen los dos. */
static void mide_periodo(void)
{
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
}

/* SU RELLENO DE FRAME, VERBATIM.
 *
 * El frame del VecFever mide 30023 ciclos CLAVADOS, y lo que le sobra tras dibujar lo
 * quema con comandos: ORA a +-64 alternando con la rampa ABIERTA (ORB=0x00 -> PB0=0 mux en
 * el canal 0, PB7=0 rampa activa) y ACR=0x18, que quita PB7 de las manos de T1. Medido en
 * los 1061 frames de la captura: 246 alternancias cuando dibuja 1621 escrituras y 70 cuando
 * dibuja 3348 — mas dibujo, menos relleno, y el total siempre 30023
 * ([[preambulo-vecfever-es-el-ritmo]]).
 *
 * Como alterna en tramos iguales el desplazamiento neto es cero, y el haz va apagado (el SR
 * quedo en 0 y con ACR = 0x18 los bits de modo siguen en 110, asi que CB2 conserva el
 * ultimo bit). O sea: aparca el haz y mantiene los integradores y los condensadores vivos
 * durante el hueco entre frames, donde nosotros nos quedabamos en silencio con
 * `uvm2_bus_delay`. Un silencio no refresca un condensador.
 *
 * Los ciclos son suyos: cabecera 3/6/3/6/0/212 y cada alternancia 6/0/41. */
static void ritmo_vecfever(void)
{
    const uint32_t objetivo = uvm2_pacer_cycles;
    if (objetivo == 0u) return;                 /* sin ritmo fijado, no hay sobrante */
    const uint32_t CAB = 3u+1u + 6u+1u + 3u+1u + 6u+1u + 0u+1u + 212u+1u;   /* 236 */
    const uint32_t ALT = 6u+1u + 0u+1u + 41u+1u;                            /*  50 */
    if (s_ciclos + CAB + ALT > objetivo) return;   /* no cabe ni una: se deja el silencio */

    emit(UVM2_VIA_PORTA, 0x40, 3);
    emit(UVM2_VIA_PORTB, 0x00, 6);    /* canal 0, rampa abierta */
    emit(UVM2_VIA_PCR,   0xCE, 3);
    emit(UVM2_VIA_ACR,   0x18, 6);    /* PB7 fuera de T1: la rampa la manda PORTB */
    emit(UVM2_VIA_T1CL,  0xBF, 0);
    emit(UVM2_VIA_T1CH,  0x00, 212);
    unsigned n = (objetivo - s_ciclos) / ALT;
    for (unsigned i = 0; i < n; i++) {
        emit(UVM2_VIA_PORTA, (i & 1u) ? 0x40 : 0xC0, 6);
        emit(UVM2_VIA_T1CL,  0x1F, 0);
        emit(UVM2_VIA_T1CH,  0x00, 41);
    }
    /* Las caches, con lo ultimo que salio de verdad. El ACR y el PCR los repone
     * via_setup en el frame siguiente. */
    s_porta = (uint8_t)((n & 1u) ? 0x40 : 0xC0); s_porta_stale = 0;
    s_portb = 0x00; s_pcr = 0xCE;
    uvm2_draw_invalidate();
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
    s_limite = UVM2_CMD_CAPACITY;   /* el cierre entra SIEMPRE, ver UVM2_CMD_RESERVA */
    /* EL APAGADO VA ANTES DEL PCR, COMO EL. Su cierre de frame es `T1CH+29 SR=00+14`, y
     * nosotros poniamos el PCR en medio: con el PCR delante, el ultimo comando emitido ya
     * no es el T1CH del trazo y `alarga_t1ch_del_trazo` no podia cerrarlo, asi que el
     * ultimo trazo de CADA frame salia cortado 18 ciclos. */
    haz_apagar_y_esperar_h(14u);
    emit(UVM2_VIA_PCR, s_pcr, 0);

    /* RECALIBRAR, con el haz ya apagado y antes de pinzar. Es donde la BIOS la
     * tiene: `Recalibrate` es lo ultimo de `Wait_Recal`, o sea trabajo del CIERRE
     * del frame. Ver el bloque de uvm2_recalibrate.
     *
     * EL VECFEVER NO LO HACE. Su cierre de frame entero es `T1CH+29 SR=00+14` — una
     * escritura — y no barre a los railes ni una vez. Puede permitirselo porque su bloque
     * de cero corre 12 veces POR FRAME re-cebando C305 con el offset calibrado, que es la
     * referencia que el barrido venia a restablecer; y desde hoy nosotros emitimos ese
     * mismo bloque, con sus mismos ciclos.
     *
     * Se apaga con el resto del cierre suyo (UVM2_CIERRE_VECFEVER=0 devuelve los dos), y
     * el sintoma a vigilar si hiciera falta volver es el de siempre: el dibujo
     * descolocandose frame a frame. */
#ifndef UVM2_NO_RECALIBRATE
    if (!CIERRE_VECFEVER) uvm2_recalibrate();
#endif

    /* Y ahora si, pinzar el haz en el centro: un integrador parado deriva, y un
     * haz que deriva es un punto brillante quemado en mitad de la pantalla. */
    set_zero(1, UVM2_ZERO_BASE + s_scale / 4u);
    s_pos_x = 0;
    s_pos_y = 0;

    /* Y EL SOBRANTE DEL FRAME SE GASTA COMO EL: con comandos, no callado. */
    if (RITMO_VECFEVER) ritmo_vecfever();

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
    mide_periodo();
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
    s_dibujo_cycles = cycles;              /* lo que tardo en DIBUJARSE, sin el relleno */
    if (uvm2_pacer_cycles == 0) {
        s_frame_cycles = cycles;
    } else if (cycles < uvm2_pacer_cycles) {
        uvm2_bus_delay(uvm2_pacer_cycles - cycles);
        s_frame_cycles = uvm2_pacer_cycles;
    } else {
        uvm2_stats.overrun++;
        s_frame_cycles = cycles;
    }

    mide_periodo();

#ifdef UVM2_RETARDO_US
    retardo_artificial();
#endif
}

#ifdef UVM2_RETARDO_US
/* Al final del cierre de frame, que es donde cae el coste de escribir en la PSRAM. */
#endif

uint32_t uvm2_frame_bus_cycles(void) { return s_frame_cycles; }

uint32_t uvm2_frame_count(void) { return s_frames; }
