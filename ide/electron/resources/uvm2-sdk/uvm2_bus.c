/*
 * uvm2_bus.c — halt-mode bus transport for the Ultimate Vectrex Multicart 2.
 *
 * Three jobs:
 *   1. uvm2_bus_init()  — take the machine over from the UVM2 firmware and halt
 *                         the 6809 once, for good.
 *   2. uvm2_exec()      — replay a recorded command stream, one VIA write per
 *                         Vectrex bus cycle.  This is the hot loop.
 *   3. single accesses  — one-off writes and the read cycle used for input.
 *
 * Bus phase (VectrexCart::WriteVia, proven on hardware):
 *      wait CLK HIGH → drive address+data+R/W → wait CLK LOW
 * i.e. the bus is updated just after the rising edge and held across the falling
 * edge, where the VIA latches.  Doing it the other way round — driving during
 * the low phase and releasing on the rising edge — changes the bus exactly at
 * the latch point and writes garbage.
 */

#include "uvm2_bus.h"
#ifdef UVM2_PIO_STREAM
#include "uvm2_bus_stream.h"
#endif

uvm2_stats_t uvm2_stats;

/* Linker-provided; C code needs its .bss cleared and nothing else does it. */
extern uint32_t _bss_start, _bss_end;

/* ── Edge waits ───────────────────────────────────────────────────────────────
 * Deliberately not a shared helper with a function call in the middle: the
 * executor has ~333 ns (about 50 CPU cycles at 150 MHz) between the rising edge
 * and the latch to get the new value onto the pins. */
#define UVM2_WAIT_CLK_HIGH()  while ((UVM2_GPIO_IN & UVM2_CLK_MASK) == 0) { }
#define UVM2_WAIT_CLK_LOW()   while ((UVM2_GPIO_IN & UVM2_CLK_MASK) != 0) { }

/* Glitch-free masked update: one store, no intermediate state.  A CLR+SET pair
 * would take the address through $0000 with R/W already low. */
static inline void uvm2_put_masked(uint32_t value, uint32_t mask)
{
    UVM2_GPIO_OUT_XOR = (UVM2_GPIO_OUT ^ value) & mask;
}

/* ── Init ─────────────────────────────────────────────────────────────────── */

#define SCB_VTOR        UVM2_MMIO(0xE000ED08u)
#define SYST_CSR        UVM2_MMIO(0xE000E010u)
#define NVIC_ICER(i)    UVM2_MMIO(0xE000E180u + 4u * (i))
#define NVIC_ICPR(i)    UVM2_MMIO(0xE000E280u + 4u * (i))
#define PADS_BANK0(n)   UVM2_MMIO(0x40038000u + 4u + 4u * (n))
#define IO_BANK0_CTRL(n) UVM2_MMIO(0x40028000u + 8u * (n) + 4u)

/* GPIO0-27, 29, 31 — 28 and 30 belong to the cartridge (30 = WS2812 LED). */
#define UVM2_CART_PINS      0xAFFFFFFFu
/* PB6, /IRQ, /HALT, /NMI, CLK get pull-ups, as the reference does. */
#define UVM2_PULLUP_PINS    0xA8C00000u
/* SCHMITT | DRIVE=8mA | IE.  OD and ISO clear — RP2350 pads power up isolated,
 * so writing the whole register is what actually connects the pad. */
#define UVM2_PAD_BASE       0x62u
#define UVM2_PAD_PUE        0x08u
#define UVM2_FUNC_SIO       5u

/* Step 1 — must run before ANY other C in the image: .bss still holds whatever
 * was in SRAM (the .um2 carries no zero-fill and the firmware copies the file
 * verbatim), so every static below is garbage until this returns. */
#ifndef UVM2_BIOS   /* la BIOS tiene su propio arranque; y _bss_start no existe alli */
void uvm2_cpu_init(void)
{
#ifdef UVM2_PICO_RUNTIME
    /* Under the pico-sdk build the crt0 has already cleared .bss and pointed
     * VTOR at its own table (which carries our SVC handler, since isr_svcall is
     * weak). Doing either again here would be wrong twice over: `_bss_start`
     * and `_bss_end` are symbols from OUR linker script and do not exist, and
     * hardcoding VTOR = 0x20000000 assumes a vector table we no longer emit. */
#else
    for (uint32_t *p = &_bss_start; p < &_bss_end; p++) *p = 0;

    /* Our vector table, or SVC and faults still land in the firmware's. */
    SCB_VTOR = 0x20000000u;
    __asm__ volatile ("dsb \n isb" ::: "memory");
#endif

    /* Silence whatever the firmware left enabled; anything still armed would
     * vector into our stub handlers.  PRIMASK stays CLEAR on purpose — every
     * VPy builtin is an SVC, and masking it escalates SVC to a HardFault. */
    SYST_CSR = 0;
    for (int i = 0; i < 4; i++) { NVIC_ICER(i) = 0xFFFFFFFFu; NVIC_ICPR(i) = 0xFFFFFFFFu; }
}
#endif

/* Step 2 — pads and function select.  Separate from the halt because CLK has to
 * be readable before we commit to anything: everything downstream blocks on its
 * edges, so a console that is switched off must be detectable first. */
void uvm2_bus_pads(void)
{
    for (uint32_t n = 0; n < 32; n++) {
        uint32_t bit = 1u << n;
        if ((UVM2_CART_PINS & bit) == 0) continue;
        PADS_BANK0(n)    = UVM2_PAD_BASE | ((UVM2_PULLUP_PINS & bit) ? UVM2_PAD_PUE : 0u);
        IO_BANK0_CTRL(n) = UVM2_FUNC_SIO;
    }
}

/* Step 3 — take the bus and keep it.  /HALT stays asserted for the life of the
 * program: releasing it between accesses lets the 6809 resume BIOS execution
 * and fight us for the bus. */
#ifdef UVM2_PIO_STREAM
/* Arranca el stream con el reparto de campos de ESTA placa.
 *
 * out_dirs deja fuera GP22 (PB6, que es una ENTRADA aqui) y GP23 (que no existe). Van
 * dentro del rango del `out` porque la direccion esta partida —A14/A15 saltan sobre
 * ellos— pero con su bit de direccion a 0 el pad no conduce y el `out pins` es inocuo.
 * Es el mismo mecanismo del preambulo, sin una sola rama en el camino caliente.
 *
 * El park es $8000 con R/W ALTO: sin mapear en el Vectrex, asi que un periodo aparcado no
 * alcanza a ningun dispositivo. Aparcar en $D00x volveria a ejecutar la ultima escritura
 * a la VIA en CADA bajada de E. */
#define UVM2_STREAM_OUT_BASE   0u
#define UVM2_STREAM_OUT_COUNT  27u                       /* GP0..GP26: datos, A0-A15, R/W */
#define UVM2_STREAM_OUT_DIRS   (((1u << UVM2_STREAM_OUT_COUNT) - 1u) \
                                & ~(1u << 22) & ~(1u << 23))
/* Las direcciones de pin que el SM tiene puestas, leidas de IO_BANK0.
 *
 * POR QUE HACE FALTA: si estas salen mal, el SM corre, consume la FIFO y el pad no conduce
 * — pantalla negra sin un solo contador que se queje. Ya paso en el otro cartucho. Y hay
 * DOS causas opuestas que se ven igual desde fuera: que la mascara nunca llegara al
 * preambulo, o que el SM REINICIARA despues y volviera a correr el preambulo con la
 * primera palabra que hubiera en la FIFO (una palabra de dibujo).
 *
 * Se toma justo despues de instalar. Comparada con la misma lectura hecha mas tarde por
 * SWD, separa las dos: si aqui sale bien y luego mal, el SM se reinicia. */
uint32_t uvm2_stream_dirs_tras_install;

static uint32_t lee_dirs(void)
{
    uint32_t m = 0;
    for (uint32_t i = 0; i < UVM2_STREAM_OUT_COUNT; i++) {
        uint32_t st = *(volatile uint32_t *)(uintptr_t)(0x40028000u + 8u * i);
        if (st & (1u << 13)) m |= (1u << i);      /* OETOPAD: el pad conduce */
    }
    return m;
}

void uvm2_stream_start(void)
{
    vbus_install(UVM2_STREAM_OUT_BASE, UVM2_STREAM_OUT_COUNT, UVM2_STREAM_OUT_DIRS,
                 UVM2_PARK_BITS | UVM2_RW_MASK);
    uvm2_stream_dirs_tras_install = lee_dirs();
}
#endif

void uvm2_bus_halt(void)
{
    /* Values go into GPIO_OUT *before* the drivers are enabled, so the pins
     * never glitch through a random state on their way up. */
    UVM2_GPIO_OUT_SET = UVM2_PARK_BITS;
    UVM2_GPIO_OUT_CLR = UVM2_OUT_MASK & ~UVM2_PARK_BITS;   /* includes /HALT low */
    UVM2_GPIO_OE_SET  = UVM2_OUT_MASK;

    /* Let the 6809 finish its instruction and tri-state.  The reference sleeps
     * 20 ms; counting bus cycles instead keeps this independent of whatever
     * core clock the firmware left configured — 30000 cycles is 20 ms exactly. */
    uvm2_bus_delay(UVM2_CYCLES_20MS);
}

/* CUANTOS CICLOS DE CPU DURA UN PERIODO E, medido contra el reloj del propio Vectrex.
 *
 * POR QUE ESTE NUMERO Y NO "cuantos MHz". La calibracion de fase del stream por PIO
 * (`nop [14]` en bus_stream.pio) esta expresada en ciclos de PIO, y el PIO va al reloj del
 * sistema. Lo que decide si esa calibracion se traslada de una placa a otra no es la
 * frecuencia nominal, es la RELACION entre el reloj del sistema y el periodo de E. En
 * nuestro cartucho son 100,0 ciclos por periodo (T1_CYCLES_Q8 = 25602).
 *
 * Y E es la mejor regla que hay: 1,5 MHz por definicion del Vectrex, independiente de que
 * cristal lleve la placa y de lo que dejara configurado la bootrom. Leer PLL_SYS da 150
 * MHz, pero SUPONIENDO un cristal de 12 MHz que nadie ha medido; esto no supone nada.
 *
 * Se toma sobre UVM2_E_MUESTRAS periodos para que el coste de detectar el flanco (unos
 * pocos ciclos) se reparta y no sesgue el resultado. En Q8 para no arrastrar coma
 * flotante: 100,0 ciclos se leen como 25600. */
#define UVM2_E_MUESTRAS 256u
uint32_t uvm2_ciclos_por_e_q8;

void uvm2_medir_e(void)
{
    uint32_t t0, t1, i;

    *(volatile uint32_t *)0xE000EDFC |= (1u << 24);   /* DEMCR.TRCENA        */
    *(volatile uint32_t *)0xE0001000 |= 1u;           /* DWT_CTRL.CYCCNTENA  */

    /* Empezar EN un flanco, no en medio de un periodo: si no, la primera muestra vale
     * una fraccion y el promedio sale corto. */
    UVM2_WAIT_CLK_LOW();
    UVM2_WAIT_CLK_HIGH();
    t0 = *(volatile uint32_t *)0xE0001004;
    for (i = 0; i < UVM2_E_MUESTRAS; i++) {
        UVM2_WAIT_CLK_LOW();
        UVM2_WAIT_CLK_HIGH();
    }
    t1 = *(volatile uint32_t *)0xE0001004;

    uvm2_ciclos_por_e_q8 = ((t1 - t0) << 8) / UVM2_E_MUESTRAS;
}

void uvm2_bus_init(void)
{
#ifndef UVM2_BIOS
    uvm2_cpu_init();
#endif

    uvm2_bus_pads();
    uvm2_bus_halt();
}

/* ── Command stream executor ──────────────────────────────────────────────────
 * Mirrors VectrexCart::ExecuteHaltCommands: R/W is dropped once for the whole
 * batch and the address' high bits stay at $D000 throughout, so each command is
 * a single 12-bit update landing on GPIO0-11.  One command = one bus cycle. */

#ifdef UVM2_PIO_STREAM
void uvm2_bus_devolver_al_stream(void);   /* definida con las primitivas sueltas, abajo */

/* ── EL MISMO EJECUTOR, PERO ENCOLANDO ────────────────────────────────────────
 *
 * La lista y su formato NO CAMBIAN: se decodifica igual (reg+dato ya desplazados en los
 * bits 8..19, retardo en 20..31). Lo que cambia es quien pone los bits en el bus y quien
 * cuenta los periodos: aqui la maquina de estados del PIO, que sincroniza contra ~E por
 * hardware. Esa es la diferencia que importa — una palabra que llega tarde le cuesta un
 * periodo, no una escritura en la fase equivocada.
 *
 * Y por eso esto tolera que la lista viva en la PSRAM: un fallo de cache retrasa al DMA,
 * que reponde llenando el FIFO un poco despues; la SM mientras tanto APARCA. Con el
 * ejecutor en CPU el mismo fallo caia dentro de la ventana de una escritura y rompia la
 * fase, que es lo que dibujaba garabatos.
 *
 * EL RETARDO SE ENCOLA, NO SE ESPERA. `vbus_repeat(n)` es UNA palabra que hace aparcar n
 * periodos; empujar n palabras de park costaba ~8400 escrituras al FIFO por frame para
 * producir exactamente lo mismo.
 */
UVM2_RAMFUNC uint32_t uvm2_exec(const uint8_t *cmds, uint32_t count)
{
    uint32_t cycles = 0;

    /* Reclamar el bus si un acceso suelto se lo llevo a SIO entre frames. */
    uvm2_bus_devolver_al_stream();

    while (count--) {
        uint32_t v     = (uint32_t)cmds[0] | ((uint32_t)cmds[1] << 8) | ((uint32_t)cmds[2] << 16);
        uint32_t out   = UVM2_CMD_REG_DATO(v);
        uint32_t delay = UVM2_CMD_RETARDO(v);
        cmds += 3;

        /* R/W queda BAJO por omision en la palabra: es una escritura. */
        vbus_push(vbus_word(UVM2_PALABRA_VIA(out)));
        cycles++;

        if (delay) {
            vbus_push(vbus_repeat(delay));
            cycles += delay;
        }
    }

    /* VACIAR ANTES DE QUE NADIE LEA. El resto del SDK lee la VIA entre frames (mandos,
     * PSG), y una lectura que adelante al lote pendiente ve el bus de antes. Es la misma
     * avaria que dejo los botones 1 y 2 pulsados desde el arranque en el otro cartucho. */
    vbus_flush();
    return cycles;
}
#else
UVM2_RAMFUNC uint32_t uvm2_exec(const uint8_t *cmds, uint32_t count)
{
    uint32_t cycles = 0;

#ifdef UVM2_STREAM_SOLO_INSTALA
    /* BISECCION: el stream se INSTALA pero no se usa; se dibuja por SIO.
     *
     * Separa dos cosas que hasta ahora iban juntas: lo que `install()` deja hecho al
     * arrancar —pads, FUNCSEL, PIO y DMA fuera del reset, direcciones de pin— y como el
     * stream deja la VIA al cerrar cada frame. Con el mando dando 0x89 en vez de 0xFF con
     * los pines cedidos, la SM parada y el bus drenado, el sospechoso ya solo puede ser
     * uno de esos dos.
     *
     * Hay que tomar el bus porque install se llevo los pines al PIO. Es pegajoso: se queda
     * en SIO y nadie lo reclama, que es justo lo que se quiere medir. */
    bus_tomar();
#endif

    /* Select $D000 on a clean edge, with R/W HIGH — a READ, not a write.
     *
     * This used to leave R/W low, and UVM2_BUS_MASK covers R/W as well as the
     * address and data lines, so the pre-select WAS a write: register 0 (Port B)
     * = 0x00. That clears PB0 (mux ENABLED, channel 0 = the Y sample-and-hold)
     * and PB7 (/RAMP RUNNING), so every frame began by releasing the integrators
     * with the DAC wired to the Y hold. It is the stray bright vector that
     * survived removing the drawing, the input, the audio and the zero-clamp
     * release — because it happened before any of them, even with an empty
     * command stream (s_count = 0, verified over SWD 2026-08-04).
     *
     * Ralf's executor does `... | c_ReadWriteMask` here for exactly this reason,
     * which is why his game never showed it.
     *
     * PERO SOLO SE COPIO LA MITAD. El suyo es:
     *
     *     gpio_put_masked (c_HaltModeOutputs, c_VIABase | 0xC00 | c_ReadWriteMask);
     *                                                     ^^^^^ registro 0xC = PCR
     *
     * El R/W alto y el registro son DOS defensas, no una. El R/W alto dice "esto
     * es una lectura"; el registro elige QUE se rompe si esa lectura no se
     * respeta. Con el registro a 0 lo que se escribe es PORT B = 0x00: mux
     * habilitado y /RAMP CORRIENDO, o sea un trazo. Con el registro a 0xC lo que
     * se escribe es PCR = 0x00, que deja CB2 bajo —haz apagado— y no mueve nada.
     *
     * El fantasma sobrevivio a quitar el dibujo, la entrada y el audio, y la
     * lista de comandos impresa en el host sale limpia (los dos movimientos con
     * el haz apagado, solo los dos trazos encendidos). Lo unico que queda fuera
     * de la lista es este preambulo.
     *
     * Y LA FASE TAMPOCO ERA LA SUYA. El suyo, con Start = CLK bajo y End = CLK alto:
     *
     *     Start(); End(); gpio_put_masked(preambulo); Start();
     *
     * o sea: pone con CLK ALTO y lo mantiene hasta que CLK baja — la misma fase
     * que usan sus comandos, y que los nuestros. El nuestro hacia lo contrario
     * (HIGH, LOW, poner), asi que cambiaba direccion y R/W con CLK BAJO. El pin
     * es ~E, luego CLK bajo es E ALTA: cambiabamos el bus en mitad de E alta,
     * que es precisamente lo que este proyecto tiene escrito que no se hace, y
     * el flanco siguiente lo engancha igual. Los comandos estaban bien; el
     * preambulo, que es lo unico que queda fuera de la lista, no. */
    UVM2_WAIT_CLK_LOW();
    UVM2_WAIT_CLK_HIGH();
    uvm2_put_masked(UVM2_VIA_BASE_BITS | UVM2_RW_MASK | (UVM2_VIA_PCR << 8),
                    UVM2_BUS_MASK);
    UVM2_WAIT_CLK_LOW();

    while (count--) {
        uint32_t v     = (uint32_t)cmds[0] | ((uint32_t)cmds[1] << 8) | ((uint32_t)cmds[2] << 16);
        uint32_t out   = UVM2_CMD_REG_DATO(v);
        uint32_t delay = UVM2_CMD_RETARDO(v);
        cmds += 3;

        UVM2_WAIT_CLK_HIGH();
        uvm2_put_masked(out, UVM2_CMD_GPIO_MASK);
        UVM2_GPIO_OUT_CLR = UVM2_RW_MASK;   /* assert WRITE */
        UVM2_WAIT_CLK_LOW();
        cycles++;

        /* R/W STAYS LOW through the delay cycles.
         *
         * It used to go high here, "so the idle cycles do not re-execute the same
         * write". They do not need protecting from that: every register we write
         * (PORTA, PORTB, PCR, ACR, DDRx) takes the same value idempotently, which
         * is why Ralf's executor holds R/W low for the whole command and only
         * raises it once, after the last one.
         *
         * Raising it costs us something real. In halt mode the data bus is an
         * OUTPUT (UVM2_OUT_MASK), and the address still selects $D000 — so R/W
         * high is a READ of the VIA, and the VIA drives the data lines straight
         * back into our drivers. Contention, on every delay cycle, which is most
         * of them: a vector spends 125 + 16 + 3 cycles in delays and 4 driving.
         *
         * Diffing the two command streams on the host (2026-08-04) showed ours is
         * IDENTICAL to his, command for command, data for data, delay for delay —
         * 45 words each for the same square. So the stray vector was never in what
         * we send; it is in how we hold the bus while sending it. */
        while (delay--) {
            UVM2_WAIT_CLK_HIGH();
            UVM2_WAIT_CLK_LOW();
            cycles++;
        }
    }

    /* Park at $0000, R/W high — his `gpio_put_masked(c_HaltModeOutputs,
     * c_ReadWriteMask)`, which drives every halt-mode output low except R/W.
     * We parked at $8000; both are unmapped and neither drives the data bus
     * back at us, but there is no reason to differ from the reference here. */
    UVM2_WAIT_CLK_HIGH();
    UVM2_GPIO_OUT_SET = UVM2_RW_MASK;
    uvm2_put_masked(UVM2_RW_MASK, UVM2_BUS_MASK);
    return cycles;
}
#endif /* UVM2_PIO_STREAM */

UVM2_RAMFUNC void uvm2_bus_delay(uint32_t cycles)
{
    while (cycles--) {
        UVM2_WAIT_CLK_HIGH();
        UVM2_WAIT_CLK_LOW();
    }
}

/* ── Single accesses ──────────────────────────────────────────────────────── */

/* Bus cycles spent in single accesses (input reads, PSG writes) since it was
 * last cleared.  uvm2_exec returns its own count, but these do not go through
 * it, so without this the frame pacing has no idea they happened and overshoots
 * 50 Hz by however long the controls and the sound took.  Counted rather than
 * assumed: an input read's cost depends on how many SAR steps an axis needs. */
uint32_t uvm2_single_cycles;

#ifdef UVM2_PIO_STREAM
/* ── ACCESOS SUELTOS MIENTRAS EL STREAM TIENE EL BUS ──────────────────────────
 *
 * Con el stream, GP0..GP26 son del PIO. uvm2_via_write y uvm2_via_read siguen hablando por
 * SIO —es su forma correcta y unica de leer, porque el ejecutor no puede leer a mitad de
 * lista— asi que escriben en registros que YA NO CONDUCEN esos pines.
 *
 * EL SINTOMA NO SE PARECE A UN FALLO DE BUS. Leer un mando es *escribir la columna en
 * Port B y luego leer Port A*, y los botones son activos BAJOS: si la columna no sale, se
 * lee "pulsado" en todo. En asteroids eso es la nave girando, disparando y saltando al
 * hiperespacio a la vez y al azar. En el otro cartucho la misma familia de fallo dejo los
 * botones 1 y 2 pulsados desde el arranque, y tampoco parecio un problema del bus.
 *
 * Dos cosas, y las dos hacen falta:
 *   1. VACIAR el stream. Una lectura puede adelantar a hasta 63 escrituras encoladas
 *      (~42 us), y entonces lee el bus de antes.
 *   2. Devolver los pines a SIO durante el acceso, y al PIO al salir.
 *
 * Cuesta 27 escrituras de FUNCSEL por acceso, y se puede permitir: esto ocurre ENTRE
 * frames (mandos, ejes, PSG), nunca dentro del bucle de dibujo. La SM se queda aparcando
 * mientras tanto, que es su estado de reposo por diseño.
 *
 * El valor y la direccion de SIO no se pierden al ceder los pines: GPIO_OUT y GPIO_OE son
 * del SIO y siguen ahi; solo cambia quien conduce el pad. */
#define UVM2_FUNC_SIO 5u
#define UVM2_FUNC_PIO 6u

static void pines_a(uint32_t funcsel)
{
    for (uint32_t i = 0; i < UVM2_STREAM_OUT_COUNT; i++)
        if (UVM2_STREAM_OUT_DIRS & (1u << i))
            *(volatile uint32_t *)(uintptr_t)
                (0x40028000u + 8u * (UVM2_STREAM_OUT_BASE + i) + 4u) = funcsel;
}

/* SE TOMA UNA VEZ Y SE SUELTA AL VOLVER A DIBUJAR, no por acceso.
 *
 * Tomarlo y soltarlo en cada uvm2_via_write era el arreglo obvio y esta MAL: leer los
 * botones son OCHO accesos seguidos (DDRA, el numero de registro, el latch, inactivo,
 * DDRA a entrada, leer, inactivo) y esa secuencia son ESTROBOS del PSG, con orden y
 * tiempos. Rebotando los pines PIO->SIO->PIO entre cada uno se mete un hueco largo en
 * mitad de la secuencia, y el resultado no es ruido: es un valor ESTABLE Y EQUIVOCADO.
 * Medido con el test `mandos`: 0x76 en vez de 0xFF con nada pulsado, congelado en tres
 * lecturas. Un valor que baila y un valor fijo pero falso son averias distintas.
 *
 * Asi que el bus se queda en SIO desde el primer acceso suelto hasta que el dibujo lo
 * reclama. uvm2_exec lo pide al empezar; entre frames no lo pide nadie, que es justo
 * cuando se leen mandos, ejes y PSG. */
static int s_bus_en_sio;

static void bus_tomar(void)
{
    if (s_bus_en_sio) return;
    vbus_drain();
    vbus_sm_parar();               /* viva pero sin pines sigue opinando sobre el ciclo */
    pines_a(UVM2_FUNC_SIO);
    s_bus_en_sio = 1;
}

void uvm2_bus_devolver_al_stream(void)
{
    if (!s_bus_en_sio) return;
    pines_a(UVM2_FUNC_PIO);
    vbus_sm_arrancar();
    s_bus_en_sio = 0;
}

#define UVM2_BUS_TOMAR()  bus_tomar()
#define UVM2_BUS_SOLTAR() do { } while (0)
#else
#define UVM2_BUS_TOMAR()  do { } while (0)
#define UVM2_BUS_SOLTAR() do { } while (0)
#define uvm2_bus_devolver_al_stream() do { } while (0)
#endif

uint32_t uvm2_escritura_out, uvm2_escritura_in, uvm2_escritura_oe;

UVM2_RAMFUNC void uvm2_via_write(uint32_t reg, uint32_t data)
{
    uint32_t out = UVM2_VIA_BASE_BITS
                 | ((reg & 0x0Fu) << 8)          /* register → A0-A3 */
                 | (data & 0xFFu);               /* data     → D0-D7 */

    UVM2_BUS_TOMAR();

    /* ESPERAR UN FLANCO COMPLETO, no "a que este alto".
     *
     * Con solo UVM2_WAIT_CLK_HIGH(), si el reloj YA estaba alto al entrar no se espera
     * nada y se presenta al FINAL de esa mitad — a un pelo del cambio. Eso es una
     * violacion de fase, y en este bus una violacion de fase no degrada: falla en seco.
     *
     * MEDIDO, comparando los mismos testigos en la imagen que funciona y en la del stream,
     * en el instante de presentar la escritura de Port A: la direccion, el dato, R/W,
     * /HALT y la OE son IDENTICOS, y solo difiere el bit 31 — el reloj. Alto en SIO, bajo
     * con el stream. De ahi que las lecturas funcionaran y las escrituras no, y que el
     * mando leyera siempre el mismo valor equivocado.
     *
     * En SIO colaba por el ritmo con el que se encadenan las llamadas; en cuanto
     * bus_tomar() las deja en otra fase, se caen fuera. uvm2_exec ya lo hace bien —
     * WAIT_CLK_LOW y luego WAIT_CLK_HIGH— y estas dos no. */
    UVM2_WAIT_CLK_LOW();
    UVM2_WAIT_CLK_HIGH();
    uvm2_put_masked(out, UVM2_BUS_MASK);          /* R/W low = write */

    /* QUE LLEGA DE VERDAD A LOS PADS AL PRESENTAR.
     *
     * Las lecturas funcionan —medido: la VIA queda seleccionada en $D001, R/W alto, /HALT
     * bajo y contesta— y aun asi el PSG esta en el estado equivocado, o sea que lo que no
     * llega son las ESCRITURAS. Esto captura los tres testigos en el instante de presentar,
     * para poder comparar la imagen con stream contra la que funciona:
     *
     *   _out  lo que QUERIAMOS poner
     *   _in   lo que los pads muestran de verdad (nos leemos a nosotros mismos: si no
     *         coincide con _out en la mascara del bus, la escritura no sale al pad)
     *   _oe   quien conduce
     *
     * Se toma solo en la escritura de PORT A (reg 1), que es donde va el numero de registro
     * del PSG: la que decide que se lee despues, y por tanto la que explica un valor
     * equivocado y repetible. Capturar todas dejaria la ultima, que no es comparable. */
    if ((reg & 0x0Fu) == 1u) {
        uvm2_escritura_out = out;
        uvm2_escritura_in  = UVM2_GPIO_IN;
        uvm2_escritura_oe  = *(volatile uint32_t *)(uintptr_t)(0xD0000000u + 0x030u);
    }

    UVM2_WAIT_CLK_LOW();

    /* El aparcado va con CLK ALTO, no aqui. Estaba justo detras del WAIT_CLK_LOW,
     * o sea que cambiaba la direccion y el R/W con E ALTA — el mismo error de
     * fase que tenia el preambulo del ejecutor, y en el camino que mas se usa:
     * cada escritura del PSG y cada paso de la lectura de mandos pasa por aqui.
     * Ralf ni siquiera aparca por escritura: su WriteVia termina en el flanco y
     * el aparcado ocurre una sola vez, en EndDirectViaMode, con un
     * WaitForBusCycleEnd() delante. */
    UVM2_WAIT_CLK_HIGH();
    uvm2_put_masked(UVM2_PARK_BITS, UVM2_BUS_MASK & ~UVM2_DATA_MASK);
    uvm2_single_cycles += 2;

    UVM2_BUS_SOLTAR();
}

uint32_t uvm2_lectura_oe;       /* SIO GPIO_OE en el muestreo: bits 0-7 = conducimos */
uint32_t uvm2_lectura_estado;   /* GPIO_IN entero en el muestreo */

UVM2_RAMFUNC uint8_t uvm2_via_read(uint32_t reg)
{
    uint32_t out = UVM2_VIA_BASE_BITS | UVM2_RW_MASK | ((reg & 0x0Fu) << 8);
    uint32_t addr_mask = UVM2_BUS_MASK & ~UVM2_DATA_MASK;
    uint32_t state;

    UVM2_BUS_TOMAR();

    UVM2_GPIO_OE_CLR = UVM2_DATA_MASK;            /* let the VIA drive D0-D7 */

    /* El mismo flanco completo que en uvm2_via_write, y por la misma razon. */
    UVM2_WAIT_CLK_LOW();
    UVM2_WAIT_CLK_HIGH();
    uvm2_put_masked(out, addr_mask);
    UVM2_WAIT_CLK_LOW();

    /* Sample on the next rising edge — the address has had a whole cycle by
     * then.  Edge-for-edge the same as VectrexCart::ReadVia. */
    do { state = UVM2_GPIO_IN; } while ((state & UVM2_CLK_MASK) == 0);

    /* EL ESTADO EN EL INSTANTE DEL MUESTREO, que es lo unico que no se puede deducir desde
     * fuera. Las tres lecturas del PSG devuelven el MISMO valor (0x89) den igual el
     * registro que se pida, asi que no se esta leyendo el chip: se esta leyendo el bus. Y
     * un valor constante lo da o quien lo conduce o una resistencia.
     *
     * uvm2_lectura_oe guarda la habilitacion de salida de SIO justo aqui. Si sus bits 0-7
     * estan puestos, estamos CONDUCIENDO D0-D7 mientras intentamos leerlos — o sea que
     * leemos nuestro propio dibujo, y ese es el fallo entero. Si estan a cero, nadie los
     * conduce y 0x89 es la resistencia de los pads, lo que acusa a la seleccion de la VIA
     * (la direccion) y no al dato. */
    uvm2_lectura_oe    = *(volatile uint32_t *)(uintptr_t)(0xD0000000u + 0x030u);
    uvm2_lectura_estado = state;

    uvm2_put_masked(UVM2_PARK_BITS, addr_mask);
    UVM2_GPIO_OE_SET = UVM2_DATA_MASK;

    /* Leave the clock LOW before returning.  Sampling happens on a rising edge,
     * so without this the caller's next access finds its "wait for CLK high"
     * already satisfied and drives the bus in the dying part of that same high
     * phase — too late for the falling edge that latches it, and the write is
     * simply lost.  Costs half a bus cycle and makes every access start from
     * the same known phase. */
    UVM2_WAIT_CLK_LOW();
    uvm2_single_cycles += 2u;      /* one to address, one to sample */

    UVM2_BUS_SOLTAR();
    return (uint8_t)(state & 0xFFu);
}
