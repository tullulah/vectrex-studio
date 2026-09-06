/*
 * uvm2_bus.h — Ultimate Vectrex Multicart 2: halt-mode Vectrex bus contract.
 *
 * The UVM2 has no HAL and no BIOS: the RP2350's GPIOs are wired straight to the
 * Vectrex cartridge bus, and a game either answers the 6809's ROM fetches or it
 * halts the 6809 and drives the VIA itself.  We always do the latter — the
 * generated code is native RP2350, so the 6809 has nothing to execute.
 *
 * Drawing therefore means "write the VIA registers the 6809 would have written",
 * phase-locked to the 1.5 MHz CLK that the 6809 keeps generating even while it
 * is halted.  Rather than writing them one at a time (which stalls the CPU on
 * every edge and leaves the beam idle during game logic), commands are RECORDED
 * into a buffer and replayed back-to-back by uvm2_exec().  This is the model
 * Ralf's own games use, and the command encoding below is deliberately
 * bit-identical to his so both executors are comparable.
 *
 * Command word layout:
 *      bits 31..20   delay: bus cycles to idle AFTER this write (0..4095)
 *      bits 19..16   VIA register select  → A0-A3 (GPIO8-11)
 *      bits 15..8    data byte            → D0-D7 (GPIO0-7)
 *      bits  7..0    unused
 * so (word >> 8) & 0xFFF lands directly on GPIO0-11 with no shifting in the
 * inner loop — one bus cycle per command, 667 ns.
 *
 * GPIO map (Ralf, 2026-04-16; GPIO8 = A0 confirmed against his reference game):
 *   0-7 D0-D7 | 8-21 A0-A13 | 22 PB6 | 23 /IRQ | 24 A14 | 25 A15
 *   26 R/W    | 27 /HALT     | 29 /NMI | 31 CLK        (28/30 are not ours)
 */
#ifndef UVM2_BUS_H
#define UVM2_BUS_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ── RP2350 SIO ──────────────────────────────────────────────────────────────
 * NOT the RP2040 offsets: RP2350 interleaves GPIO_HI_* (for GPIO32-47), so
 * every OUT/OE register moves.  (RP2350 datasheet §3.1.11.) */
#define UVM2_SIO_BASE       0xD0000000u
#define UVM2_MMIO(addr)     (*(volatile uint32_t *)(uintptr_t)(addr))
#define UVM2_REG(off)       UVM2_MMIO(UVM2_SIO_BASE + (off))
#define UVM2_CPUID          UVM2_REG(0x000)   /* 0 o 1: que core ejecuta */
#define UVM2_GPIO_IN        UVM2_REG(0x004)
#define UVM2_GPIO_OUT       UVM2_REG(0x010)
#define UVM2_GPIO_OUT_SET   UVM2_REG(0x018)
#define UVM2_GPIO_OUT_CLR   UVM2_REG(0x020)
#define UVM2_GPIO_OUT_XOR   UVM2_REG(0x028)
#define UVM2_GPIO_OE_SET    UVM2_REG(0x038)
#define UVM2_GPIO_OE_CLR    UVM2_REG(0x040)

/* ── Pin masks ─────────────────────────────────────────────────────────────── */
#define UVM2_DATA_MASK      0x000000FFu   /* D0-D7   GPIO0-7   */
#define UVM2_ADDR_LO_MASK   0x003FFF00u   /* A0-A13  GPIO8-21  */
#define UVM2_A14_MASK       0x01000000u
#define UVM2_A15_MASK       0x02000000u
#define UVM2_RW_MASK        0x04000000u   /* 1 = read, 0 = write */
#define UVM2_HALT_MASK      0x08000000u   /* drive LOW to own the bus */
#define UVM2_CLK_MASK       0x80000000u
#define UVM2_PB6_MASK       0x00400000u

/* Everything we drive (data + full address + R/W + /HALT). */
#define UVM2_OUT_MASK       (UVM2_DATA_MASK | UVM2_ADDR_LO_MASK | \
                             UVM2_A14_MASK | UVM2_A15_MASK |      \
                             UVM2_RW_MASK  | UVM2_HALT_MASK)
/* Bus lines only — never touches /HALT, which stays asserted for good. */
#define UVM2_BUS_MASK       (UVM2_OUT_MASK & ~UVM2_HALT_MASK)

/* $D000 = A15|A14|A12; A12 is GPIO20 because GPIO8 = A0. */
#define UVM2_VIA_BASE_BITS  (UVM2_A15_MASK | UVM2_A14_MASK | (1u << 20))
/* Idle/park address: $8000 is unmapped on the Vectrex, so a parked write cycle
 * reaches no device.  Parking at $D00x instead would re-run the last VIA write
 * (or, with R/W high, keep clearing IFR flags) for as long as the bus idles. */
#define UVM2_PARK_BITS      UVM2_A15_MASK

/* The 12 bits of a command that map onto GPIO0-11. */
#define UVM2_CMD_GPIO_MASK  0x00000FFFu

/* ── VIA 6522 registers (index only — the base is implicit) ────────────────── */
enum {
    UVM2_VIA_PORTB = 0x0, UVM2_VIA_PORTA = 0x1,
    UVM2_VIA_DDRB  = 0x2, UVM2_VIA_DDRA  = 0x3,
    UVM2_VIA_T1CL  = 0x4, UVM2_VIA_T1CH  = 0x5,
    UVM2_VIA_T1LL  = 0x6, UVM2_VIA_T1LH  = 0x7,
    UVM2_VIA_T2CL  = 0x8, UVM2_VIA_T2CH  = 0x9,
    UVM2_VIA_SR    = 0xA, UVM2_VIA_ACR   = 0xB,
    UVM2_VIA_PCR   = 0xC, UVM2_VIA_IFR   = 0xD,
    UVM2_VIA_IER   = 0xE,
};

/* ── Port B bits (Vectrex wiring) ──────────────────────────────────────────── */
#define UVM2_PB_MUX_DISABLE 0x01u   /* 1 = sample/hold off (mux disabled)     */
#define UVM2_PB_MUX_SEL0    0x02u
#define UVM2_PB_MUX_SEL1    0x04u
#define UVM2_PB_RAMP_OFF    0x80u   /* /RAMP: 1 = integrators frozen          */
#define UVM2_PB_IDLE        (UVM2_PB_RAMP_OFF | UVM2_PB_MUX_DISABLE)
/* Mux channel select (with MUX_DISABLE clear the DAC value is sampled into it) */
#define UVM2_MUX_Y          0x00u
#define UVM2_MUX_ZEROREF    UVM2_PB_MUX_SEL0
#define UVM2_MUX_Z          UVM2_PB_MUX_SEL1

/* ── PCR (VIA_cntl) bits ───────────────────────────────────────────────────── */
#define UVM2_PCR_IDLE       0xCCu   /* CA2 (/ZERO) high, CB2 (/BLANK) low     */
#define UVM2_PCR_ZERO_OFF   0x02u   /* set  → /ZERO released                   */
#define UVM2_PCR_BLANK_OFF  0x20u   /* set  → beam lit                         */

/* ── Command encoding (Ralf-compatible) ────────────────────────────────────── */
#define UVM2_CMD(reg, data, delay)                     \
    (((uint32_t)(delay) << 20) | ((uint32_t)(reg) << 16) | \
     (((uint32_t)(data) & 0xFFu) << 8))
#define UVM2_CMD_MAX_DELAY  4095u

/* LA LISTA SE GUARDA EN 3 BYTES POR COMANDO, no en 4.
 *
 * UVM2_CMD deja los bits 0-7 SIN USAR: la informacion son 24 bits justos (retardo 12,
 * registro 4, dato 8). Guardar cuatro bytes por comando es tirar uno de cada cuatro, y en
 * el UVM2 eso se paga en SRAM — la imagen vive en 496 KB y la lista de dkong son 64 KB con
 * el juego a 3788 bytes del techo.
 *
 * Con 3 bytes, los mismos 64 KB dan 21845 comandos en vez de 16384, o los 8192 de ahora
 * ocupan 24 KB en vez de 32. Y no se pierde nada: es el mismo valor desplazado.
 *
 * El coste es leerlo byte a byte en el ejecutor, y ahi sobra tiempo: cada comando es un
 * ciclo de bus del Vectrex, 667 ns, contra unos pocos ciclos de CPU a 150 MHz. */
#define UVM2_CMD_EMPAQUETA(w)  ((w) >> 8)          /* 32 bits -> los 24 que valen */
#define UVM2_CMD_REG_DATO(v)   ((v) & UVM2_CMD_GPIO_MASK)
#define UVM2_CMD_RETARDO(v)    ((v) >> 12)

/* ── Lifecycle ─────────────────────────────────────────────────────────────── */

/* Bring-up, in three steps because their order is load-bearing:
 *   uvm2_cpu_init()  .bss, vector table, firmware interrupts off.  MUST be the
 *                    first C executed — every static is garbage until it runs.
 *   uvm2_bus_pads()  pads/function select.  CLK becomes readable here, which is
 *                    what lets a switched-off console be detected rather than
 *                    hanging on the first edge wait.
 *   uvm2_bus_halt()  park the bus, enable the drivers, assert /HALT for good.
 * uvm2_bus_init() runs all three for callers that need no diagnostics between. */
void uvm2_cpu_init(void);
void uvm2_bus_pads(void);
void uvm2_bus_halt(void);
void uvm2_bus_init(void);

/* ── Command stream ────────────────────────────────────────────────────────── */

/* EN SRAM SIEMPRE. Ver el comentario de .time_critical en memmap_psram.ld: ejecutando
 * desde PSRAM, un fallo de cache dentro de la ventana de E manda la escritura al periodo
 * siguiente y el dibujo tiembla. En las imagenes normales (SRAM) no cambia nada. */
/* UVM2_HOST builds this file into a host harness (tools/), where the section name is not
 * a valid mach-o specifier and there is no SRAM to pin anything to. */
#ifdef UVM2_HOST
#define UVM2_RAMFUNC
#else
#define UVM2_RAMFUNC __attribute__((section(".time_critical.uvm2"), noinline))
#endif

/* Replay `count` commands back-to-back, one bus cycle each plus their delays.
 * R/W is held low for the whole batch (as in the reference executor) and the
 * bus is parked at $8000 on exit.  Returns the bus cycles consumed. */
UVM2_RAMFUNC uint32_t uvm2_exec(const uint8_t *cmds, uint32_t count);

/* Ciclos de CPU por periodo de E, en Q8 (100,0 ciclos = 25600). Lo llena uvm2_medir_e(),
 * que hay que llamar con el bus ya tomado. Es la relacion que decide si la calibracion de
 * fase del stream por PIO se traslada entre placas — ver uvm2_bus.c. */
extern uint32_t uvm2_ciclos_por_e_q8;
void uvm2_medir_e(void);

/* Idle for `cycles` Vectrex bus cycles (667 ns each) — clock-independent, which
 * is what beam/integrator timing needs. */
UVM2_RAMFUNC void uvm2_bus_delay(uint32_t cycles);

/* ── Single accesses (outside the command stream) ───────────────────────────
 * Reads cannot be recorded — they need the data bus turned around mid-cycle —
 * so input polling runs directly, exactly as the reference does after replaying
 * its frame.  uvm2_via_write is the one-off equivalent of a single command. */
UVM2_RAMFUNC void    uvm2_via_write(uint32_t reg, uint32_t data);
UVM2_RAMFUNC uint8_t uvm2_via_read(uint32_t reg);

/* ── Instrumentation ───────────────────────────────────────────────────────
 * A 50 Hz frame is 30000 bus cycles.  These let a game (or the IDE) report how
 * much of that budget the last frame actually spent, which is the only fair way
 * to compare this command-stream model against the syscall-per-write one. */
typedef struct {
    uint32_t commands;      /* commands replayed last frame                   */
    uint32_t bus_cycles;    /* bus cycles they consumed (writes + delays)     */
    uint32_t vectors;       /* lit segments drawn last frame                  */
    uint32_t overrun;       /* frames whose stream exceeded the 50 Hz budget  */
    uint32_t moves;         /* blanked repositions last frame (beam travel)   */
    uint32_t ramp_cycles;   /* cycles spent with the integrators running      */
    /* Comandos TIRADOS por lista llena, del ultimo frame. Un tope silencioso se lee
     * como "el dibujo esta roto" y manda a depurar el sitio equivocado: paso el
     * 2026-08-18 con el modelo T1, que llegaba justo a las 8192 y perdia el resto del
     * frame. Si esto no es cero, NADA de lo que se ve en pantalla es concluyente. */
    uint32_t dropped;
    /* Cuantas veces se ha recalibrado, ACUMULADO. Si esto no sube, Recalibrate NO SE
     * ESTA LLAMANDO — y "no funciona" y "no se ejecuta" son dos investigaciones
     * distintas. El firmware del cartucho propio lleva el mismo contador (RECALS) por
     * esta misma razon. */
    uint32_t recals;
    /* Ciclos de bus del ultimo frame, contados por el ejecutor. Repetido aparte de
     * bus_cycles porque ese lo pisa el camino de un solo nucleo. */
    uint32_t exec_cycles;

    /* Snapshots of the three above, taken in uvm2_frame_end and never cleared.
     *
     * The live counters are reset in uvm2_frame_begin and fill up as the frame is
     * built, so a debugger sampling at an arbitrary moment mostly catches them at
     * zero — a game that spends 40 ms emulating a CPU and 2 ms drawing is in the
     * "reset, not yet drawn" window almost always. Read these instead; they hold
     * the last COMPLETE frame for as long as it takes to look. */
    uint32_t vectors_last;
    uint32_t moves_last;
    uint32_t ramp_cycles_last;
    uint32_t wait_spins;    /* vueltas que core 0 espero al buffer */
    uint32_t us_exec;       /* core 1: microsegundos ejecutando la lista   */
    uint32_t us_input;      /* core 1: leyendo mandos y ejes               */
    uint32_t us_rest;       /* core 1: todo lo demas del bucle             */
    uint32_t us_wait;       /* core 1: esperando a que core 0 publique     */

    /* ── TIEMPO REAL POR FRAME ───────────────────────────────────────────────
     *
     * PARA QUE. El relleno de uvm2_frame_end se calcula con los CICLOS DE BUS DEL DIBUJO,
     * asi que lo que tarda la emulacion del juego NO entra en la cuenta: el periodo del
     * frame acaba siendo `emulacion + 20 ms` en vez de `maximo(20 ms, todo)`. Lo que cuesta
     * la CPU emulada se SUMA al frame en lugar de absorberse.
     *
     * Consecuencia: el refresco real baja de 50 Hz y ademas VARIA con la escena — pocas
     * rocas, frame corto; muchas rocas, frame largo. Eso son tirones, y ningun contador de
     * los que hay lo ve: `overrun` mide solo el flujo de bus (13 de 3677 con la pantalla
     * temblando), y `bus_cycles` tampoco, porque la emulacion ocurre ENTRE frames.
     *
     * us_frame_* es el periodo COMPLETO, medido de un frame_end al siguiente. Si el modelo
     * es correcto: min ~20000 en escenas vacias, max muy por encima con muchos vectores, y
     * vectores_en_max alto. Si sale todo clavado a 20000, el modelo es falso y hay que
     * buscar en otro sitio. */
    uint32_t us_frame_last;
    uint32_t us_frame_min;
    uint32_t us_frame_max;
    uint32_t vectores_en_max;   /* vectores del frame mas lento: liga tiempo con escena */
    uint32_t frames_lentos;     /* periodos por encima de 20,5 ms */
    uint32_t frames_medidos;

    /* ── EL LATIDO ───────────────────────────────────────────────────────────
     *
     * `frames_lentos` dice CUANTOS y `us_frame_max` dice CUANTO, pero lo que se ve en
     * pantalla es un ritmo: "parpadea una vez por segundo, a veces dos". Un contador no
     * distingue 50 frames flojos seguidos de uno flojo cada 50, y son defectos distintos.
     *
     * `hueco_lento_*` mide los FRAMES ENTRE dos lentos consecutivos: si sale ~50, el latido
     * es de 1 Hz y hay que buscar algo con periodo de un segundo; si sale 5, es otra cosa.
     * `hist_frame` da la forma entera de la distribucion, que es lo que separa "todos un
     * poco largos" de "casi todos clavados y uno larguisimo".
     *
     * Y `en_max_*` es la foto del frame MAS LENTO: dice si se fue en reproducir la lista
     * (us_exec), en leer los mandos (us_input), esperando a core 0 (us_wait) o en el resto
     * del bucle. Sin eso solo se sabe QUE hubo un tiron, no DE QUIEN. */
    uint32_t hist_frame[8];     /* <20,5 <21 <22 <24 <28 <36 <52 y el resto, en ms */
    uint32_t hueco_lento_ult;   /* frames desde el lento anterior */
    uint32_t hueco_lento_min;
    uint32_t hueco_lento_max;
    uint32_t en_max_us_exec;
    uint32_t en_max_us_input;
    uint32_t en_max_us_rest;
    uint32_t en_max_us_wait;
    uint32_t en_max_dropped;
    uint32_t en_max_commands;

    /* LA RAZON ENTRE LO QUE LA LISTA PIDE Y LO QUE TARDA, en centesimas: 100 = el bus va a
     * su ritmo nominal de 1,5 MHz, 50 = a la mitad. Separa "la lista es demasiado grande"
     * de "algo esta frenando al ejecutor", que son defectos opuestos y hasta ahora no se
     * distinguian. Ver uvm2_core1.c. */
    uint32_t exec_razon_ult, exec_razon_min, exec_razon_max;
    uint32_t hist_razon[8];     /* <50 <70 <85 <95 <105 <130 <200 y el resto */

    /* LA CAJA DEL FRAME y su salto respecto al anterior, en centesimas (100 = igual). Un
     * frame dibujado con otra ESCALA salta aqui y no lo ve ninguna metrica de conteo. */
    uint32_t caja_w, caja_h;
    uint32_t caja_razon_ult, caja_razon_min, caja_razon_max, caja_saltos;
    /* Los 6 ultimos saltos, con las 3 razones que vienen DETRAS de cada uno: distingue un
     * fallo (sube y vuelve) de una animacion (sube y se queda). */
    uint32_t caja_pico[6][4];
    /* Disparos de avg_mgo (generacion de la lista del AVG) en el frame en curso, y el
     * reparto: >1 significa que la geometria se acumula DOS VECES en la misma lista. */
    uint32_t mgo_por_frame;
    uint32_t mgo_hist[4];       /* 0, 1, 2, 3 o mas disparos por frame */

    /* EL TIEMPO DE CORE 0, PARTIDO EN DOS. Son ataques distintos: `us_emul` es el 6502 y
     * el AVG (codigo del puerto) y `us_lista` es construir la lista de comandos (nuestro
     * SDK). Sin separarlos, optimizar es a ciegas. Acumulados en microsegundos y con su
     * contador, para poder sacar la media sin sondear. */
    uint32_t us_emul_acum, us_emul_n;     /* 6502 + AVG, sin la lista */
    uint32_t us_lista_acum, us_lista_n;   /* CONSTRUIR la lista */
    uint32_t us_pub_acum,   us_pub_n;     /* publicarla — INCLUYE esperar a core 1 */
    /* EL TIEMPO DE CORE 1, con UN SOLO ESCRITOR. `us_exec` lo escriben core 1 Y
     * uvm2_svc.c, asi que leerlo no dice de quien es — y sobre ese numero montamos un
     * diagnostico entero. Estos son de core 1 y de nadie mas. */
    uint32_t us_c1_exec_acum, us_c1_exec_n;
    uint32_t us_c1_wait_acum;             /* lo que core 1 espera a core 0 */
} uvm2_stats_t;

extern uvm2_stats_t uvm2_stats;

/* Bus cycles consumed by single accesses (input, PSG) — see uvm2_bus.c.  The
 * frame pacing must subtract these or it overshoots by whatever they cost. */
extern uint32_t uvm2_single_cycles;

/* EL REFRESCO NO ES UNA LEY, ES UNA COSTUMBRE.
 *
 * El Vectrex no tiene vsync: es un monitor VECTORIAL y se redibuja cuando se le manda. Los
 * 50 Hz salen de que la BIOS hace eso, no de la electronica. Y las recreativas vectoriales
 * no tenian refresco fijo — Asteroids redibujaba en cuanto terminaba su lista, asi que se
 * apagaba un poco cuando la pantalla se llenaba de rocas.
 *
 * Aqui se puede cambiar: 25000 = 60 Hz, 30000 = 50 Hz. Con el dibujo de asteroids en 11745
 * ciclos, a 60 sigue sobrando sitio. Y es la prueba directa de si el problema es que
 * FRENAMOS: si a 60 va mejor, lo era.
 *
 * OJO al cambiarlo: refrescar mas a menudo tambien ILUMINA MAS (mas pasadas por segundo
 * sobre el mismo fosforo), asi que la intensidad puede necesitar ajuste, y ese ajuste no
 * debe confundirse con el resultado de la prueba. */
#ifndef UVM2_HZ
#define UVM2_HZ 50
#endif

/* EL RELOJ DEL BUS, con nombre. Estaba escrito a mano como 1500000 en los cuatro sitios de
 * abajo; con nombre se ve que las cuatro derivan del MISMO reloj y no son cuatro numeros. */
#define UVM2_BUS_HZ  1500000u

/* UVM2_HZ = 0 significa SIN LIMITE: se presenta en cuanto la lista esta hecha, como la
 * recreativa. Entonces no hay periodo fijo que definir, y el 1 es solo para que la division
 * no reviente en tiempo de compilacion; nadie lo usa, porque el relleno se compila fuera. */
#if UVM2_HZ == 0
#define UVM2_CYCLES_PER_FRAME  (UVM2_BUS_HZ / 1u)
#else
#define UVM2_CYCLES_PER_FRAME  (UVM2_BUS_HZ / (unsigned)UVM2_HZ)
#endif

/* DOS COSAS QUE NO SON EL PERIODO DE FRAME, y que lo usaban porque a 50 Hz coinciden.
 *
 * A 50 Hz UVM2_CYCLES_PER_FRAME vale 30000 y todo el mundo escribio 30000 donde queria
 * decir "20 ms" o "un tick de musica". Al mover UVM2_HZ, esas dos se movieron con el:
 * a 60 Hz la musica se acelera un 20%, y con UVM2_HZ=0 el asentamiento de /HALT pasa de
 * 20 ms a UN SEGUNDO. Coincidir no es ser lo mismo. */
#define UVM2_CYCLES_20MS   (UVM2_BUS_HZ / 50u)   /* asentamiento tras asertar /HALT */
#define UVM2_AUDIO_CYCLES  (UVM2_BUS_HZ / 50u)   /* el tempo de .vmus es 50 Hz, no el refresco */

#ifdef __cplusplus
}
#endif

#endif /* UVM2_BUS_H */
