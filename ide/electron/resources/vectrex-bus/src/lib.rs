//! El stream de bus por PIO+DMA, COMPARTIDO por los dos cartuchos.
//!
//! Que hay aqui y por que no puede estar en dos sitios: el `.pio`, los dos bits de
//! centinela, el park repetido con su `-1`, el anillo de lotes y su DMA. Todo eso salio de
//! medidas en el osciloscopio contra la consola —la fase del cambio de direccion dentro
//! del periodo de E, el `nop [14]`, el orden de las dos esperas— y una copia a mano de
//! esas constantes es una copia que se separa. Ver `bus_stream.pio`, que lleva la
//! derivacion entera.
//!
//! ## La costura entre placas
//!
//! No impone nada: nombra lo que las dos placas ya tienen. El llamante arma la palabra de
//! bus con SU mapa de pines (`board::bus_word`) —que es donde de verdad difieren, porque
//! en la UVM2 la direccion esta partida y A14/A15 saltan sobre PB6— y esta caja solo la
//! baja a la base del `out` y le pone el centinela. Asi el reparto de campos es del
//! tablero y el protocolo es de aqui.
//!
//! ## Lo que NO esta aqui
//!
//! La espera de rampa. Nosotros sondeamos el flag T1 de la VIA como la BIOS; el ejecutor
//! del UVM2 no puede leer a mitad de lista. Son dos algoritmos, no dos constantes, y se
//! quedan fuera a proposito para que no se escondan.
#![no_std]

use core::sync::atomic::{AtomicU32, Ordering};

// ── LOS REGISTROS, A PELO Y CON PROCEDENCIA ───────────────────────────────────
//
// POR QUE NO EL PAC, que seria lo correcto y es lo que pide la regla "escribe las
// posiciones de bit desde los campos tipados del PAC, nunca de memoria": `rp235x-pac`
// declara su dependencia de `cortex-m` SOLO para el objetivo de coma flotante hardware, y
// esta caja tiene que compilar tambien para `thumbv8m.main-none-eabi` — la imagen .um2 se
// enlaza `-mfloat-abi=softfp` y el enlazador compara `Tag_ABI_VFP_args` aunque no cruce
// ningun flotante.
//
// Asi que los numeros van a mano, PERO NO DE MEMORIA: cada uno esta leido de
// pico-sdk/src/rp2350/hardware_regs/include/hardware/regs/{dma,pio,dreq,addressmap}.h, y
// el firmware —que si tiene el PAC— los comprueba contra sus campos tipados con un
// `const assert`. Si divergen, rompe la compilacion en vez de la consola. Esto ya mordio
// una vez: el bit BUSY del DMA no estaba donde se supuso (es el 26, no el 24 del RP2040)
// y costo cuatro cuelgues del puerto de depuracion.
const DMA_BASE: usize = 0x5000_0000;      // addressmap.h
const DMA_CH_STRIDE: usize = 0x40;
const DMA_READ_ADDR: usize = 0x00;        // dma.h DMA_CH0_READ_ADDR_OFFSET
const DMA_WRITE_ADDR: usize = 0x04;       // dma.h DMA_CH0_WRITE_ADDR_OFFSET
const DMA_TRANS_COUNT: usize = 0x08;      // dma.h DMA_CH0_TRANS_COUNT_OFFSET
const DMA_CTRL_TRIG: usize = 0x0c;        // dma.h DMA_CH0_CTRL_TRIG_OFFSET

pub const DMA_EN: u32 = 1 << 0;           // dma.h ..._EN_LSB 0
pub const DMA_SIZE_WORD: u32 = 2 << 2;    // ..._DATA_SIZE_LSB 2, VALUE_SIZE_WORD 0x2
pub const DMA_INCR_READ: u32 = 1 << 4;    // ..._INCR_READ_LSB 4
pub const DMA_INCR_WRITE: u32 = 1 << 6;   // ..._INCR_WRITE_LSB 6
pub const DMA_CHAIN_LSB: u32 = 13;        // ..._CHAIN_TO_LSB 13
pub const DMA_TREQ_LSB: u32 = 17;         // ..._TREQ_SEL_LSB 17
pub const DMA_BUSY: u32 = 1 << 26;        // ..._BUSY_LSB 26  <-- 24 en el RP2040
pub const DREQ_PIO0_TX0: u32 = 0;         // dreq.h DREQ_PIO0_TX0

const PIO0_BASE: usize = 0x5020_0000;     // addressmap.h
const PIO_FSTAT: usize = 0x04;            // pio.h PIO_FSTAT_OFFSET
pub const PIO_TXF0: u32 = 0x5020_0010;    // pio.h PIO_TXF0_OFFSET 0x10
const PIO_FSTAT_TXEMPTY_LSB: u32 = 24;    // pio.h PIO_FSTAT_TXEMPTY_LSB

#[inline(always)]
unsafe fn r(a: usize) -> u32 { (a as *const u32).read_volatile() }
#[inline(always)]
unsafe fn w(a: usize, v: u32) { (a as *mut u32).write_volatile(v) }
#[inline(always)]
const fn ch(n: usize, off: usize) -> usize { DMA_BASE + n * DMA_CH_STRIDE + off }

/// El reparto de campos del `out pins` de UNA placa.
///
/// `out_base`/`out_count` tienen que casar con el `out pins, N` del `.pio` instalado: el
/// preambulo usa la misma base y cuenta para `out pindirs`, asi que no se pueden
/// desalinear por construccion — pero el ancho sigue siendo un numero en el programa.
#[derive(Clone, Copy)]
pub struct Layout {
    /// Primer GPIO del `out`. La palabra de bus se desplaza a esta base.
    pub out_base: u32,
    /// Cuantos pines conduce el `out`. 25 en el cartucho propio, 27 en la UVM2.
    pub out_count: u32,
    /// QUE pines de ese rango conducimos, ya alineado a `out_base`.
    ///
    /// No es siempre "todos". En la UVM2, PB6 (GP22) es una ENTRADA y GP23 no existe: si
    /// el preambulo los pone a salida, el `out pins` los conduce y peleamos con la placa.
    /// Con su bit a 0 aqui, el pad no conduce y el `out pins` sobre ellos es inocuo —
    /// mismo mecanismo que ya usa el preambulo, sin una sola rama en el camino caliente.
    pub out_dirs: u32,
    /// Patron de aparcado, ya alineado a `out_base` y SIN centinela.
    ///
    /// Es lo que la SM conduce cuando el FIFO se seca: `pull noblock` cae a X en vez de
    /// bloquearse, y X lleva esto. Tiene que decodificar a NADA — una direccion de VIA
    /// aparcada se re-engancha en CADA bajada de E, y eso es idempotente para un registro
    /// de puerto pero NO para T1_HI, que reinicia la rampa a 1,5 MHz.
    pub park: u32,
}

impl Layout {
    /// Una palabra de escritura: la palabra de bus de la placa, con centinela.
    ///
    /// `out` consume desde el bit BAJO, asi que el unico sitio donde la SM puede mirar
    /// antes de conducir es el 0. De ahi el desplazamiento: LOS DOS SE MUEVEN JUNTOS o se
    /// desalinean, y el sintoma seria un dibujo que no encadena trazos.
    ///
    ///     bit 0        1 = hay escritura, 0 = periodo en silencio
    ///     bits 1..=N   la palabra de la placa
    #[inline(always)]
    pub const fn word(&self, bus: u32) -> u32 {
        ((bus >> self.out_base) << 1) | 1
    }

    /// Un periodo en silencio: ni conduce el bus ni lo aparca.
    #[inline(always)]
    pub const fn silence(&self) -> u32 {
        0
    }

    /// Aparcar `n` periodos con UNA sola palabra.
    ///
    /// El `-1` es porque `jmp y--` salta MIENTRAS Y no es cero y decrementa despues, asi
    /// que con Y = n-1 el cuerpo corre n veces. Esto y el `.pio` SE MUEVEN JUNTOS.
    ///
    /// Existe porque la espera de rampa empujaba ~34 palabras de park por vector —unas
    /// 8400 por frame— para producir algo que la SM ya hace gratis.
    #[inline(always)]
    pub const fn repeat(n: u32) -> u32 {
        2 | ((n - 1) << 2)
    }
}

// ── El anillo de lotes ────────────────────────────────────────────────────────
//
// 64 palabras = 43 us de bus: bastante para amortizar el arranque del DMA, poco para que
// un lote a medio llenar retrase el dibujo. Dos lotes para que la CPU llene uno mientras
// el DMA vacia el otro.
pub const BATCH: usize = 64;

static mut BATCH_BUF: [[u32; BATCH]; 2] = [[0; BATCH]; 2];
static BATCH_IDX:  AtomicU32 = AtomicU32::new(0);
static BATCH_FILL: AtomicU32 = AtomicU32::new(0);

pub static BATCH_SENT:     AtomicU32 = AtomicU32::new(0);
pub static BATCH_WAITS:    AtomicU32 = AtomicU32::new(0);
pub static RING_FULL_SEEN: AtomicU32 = AtomicU32::new(0);
pub static RING_OVERRUNS:  AtomicU32 = AtomicU32::new(0);
pub static STREAM_PUSHES:  AtomicU32 = AtomicU32::new(0);
pub static STREAM_STALLS:  AtomicU32 = AtomicU32::new(0);

/// La mascara de pines que CONDUCEN, leida justo despues de ponerla desde la CPU y ANTES
/// de que el preambulo del .pio corra. Separa "mi bucle no hizo nada" de "el preambulo la
/// pisa despues": son dos averias opuestas con la misma pantalla negra.
pub static DIRS_TRAS_SET: AtomicU32 = AtomicU32::new(0);

/// Los pines que conducen ahora mismo, alineados a `out_base`. OETOPAD del IO_BANK0.
unsafe fn lee_oe(l: &Layout) -> u32 {
    let mut m = 0u32;
    let mut i = 0u32;
    while i < l.out_count {
        let st = r(0x4002_8000 + 8 * (l.out_base + i) as usize);
        if st & (1 << 13) != 0 { m |= 1 << i; }
        i += 1;
    }
    m
}


/// Dispara el lote acumulado. Espera a que el DMA anterior termine: el canal es uno solo.
#[inline(always)]
pub unsafe fn batch_flush() {
    let n = BATCH_FILL.load(Ordering::Relaxed);
    if n == 0 {
        return;
    }
    let idx = BATCH_IDX.load(Ordering::Relaxed) as usize & 1;

    let mut n_esperas = 0u32;
    while r(ch(0, DMA_CTRL_TRIG)) & DMA_BUSY != 0 {
        n_esperas += 1;
        if n_esperas > 1_000_000 {
            STREAM_STALLS.fetch_add(1, Ordering::Relaxed);
            break;
        }
    }
    if n_esperas != 0 {
        BATCH_WAITS.fetch_add(1, Ordering::Relaxed);
    }

    // La barrera ANTES de dar la direccion: el DMA tiene que ver las palabras escritas.
    dsb();

    let src = &raw const BATCH_BUF[idx] as *const u32 as u32;
    w(ch(0, DMA_READ_ADDR), src);
    w(ch(0, DMA_WRITE_ADDR), PIO_TXF0);
    w(ch(0, DMA_TRANS_COUNT), n);          // MODE en 31:28 = 0 = NORMAL
    w(ch(0, DMA_CTRL_TRIG),
        DMA_EN
      | DMA_SIZE_WORD
      | DMA_INCR_READ                       // recorre el lote
                                            // INCR_WRITE a 0: siempre el mismo FIFO
      | (0 << DMA_CHAIN_LSB)                // a si mismo = sin cadena
      | (DREQ_PIO0_TX0 << DMA_TREQ_LSB));   // al ritmo del hueco en la FIFO del PIO

    BATCH_IDX.store(BATCH_IDX.load(Ordering::Relaxed) + 1, Ordering::Relaxed);
    BATCH_FILL.store(0, Ordering::Relaxed);
    BATCH_SENT.fetch_add(1, Ordering::Relaxed);
}

#[inline(always)]
fn dsb() {
    unsafe { core::arch::asm!("dsb", options(nostack, preserves_flags)) }
}

/// Encola una palabra. Dispara el lote al llenarse, o si el DMA esta parado.
pub unsafe fn push(word: u32) {
    let mut fill = BATCH_FILL.load(Ordering::Relaxed) as usize;
    if fill >= BATCH {
        RING_FULL_SEEN.fetch_add(1, Ordering::Relaxed);
        batch_flush();
        fill = BATCH_FILL.load(Ordering::Relaxed) as usize;
        if fill >= BATCH {
            fill = BATCH - 1;
            RING_OVERRUNS.fetch_add(1, Ordering::Relaxed);
        }
    }
    let idx = BATCH_IDX.load(Ordering::Relaxed) as usize & 1;
    (&raw mut BATCH_BUF[idx][fill]).write_volatile(word);
    BATCH_FILL.store(fill as u32 + 1, Ordering::Relaxed);
    STREAM_PUSHES.fetch_add(1, Ordering::Relaxed);

    if fill + 1 >= BATCH || r(ch(0, DMA_CTRL_TRIG)) & DMA_BUSY == 0 {
        batch_flush();
    }
}

/// Vacia el lote parcial.
///
/// NO QUITAR POR VELOCIDAD. Sin esto, una LECTURA puede adelantar a 63 escrituras
/// encoladas (~42 us). Leer un mando es *escribir la columna en PORT_B y luego leer
/// PORT_A*, y los botones son activos BAJOS: una lectura adelantada = "pulsado". El
/// sintoma fue botones 1 y 2 pulsados desde el arranque.
pub unsafe fn flush() {
    batch_flush();
}

/// Espera a que el bus se quede sin trabajo pendiente.
pub unsafe fn drain() {
    flush();
    let mut n = 0u32;
    while r(PIO0_BASE + PIO_FSTAT) & (1 << PIO_FSTAT_TXEMPTY_LSB) == 0 {
        n += 1;
        if n > 100_000 {
            STREAM_STALLS.fetch_add(1, Ordering::Relaxed);
            break;
        }
    }
}

// ── Instalacion: el programa, la SM y los pines ───────────────────────────────

const RESETS_BASE: usize = 0x4002_0000;    // addressmap.h
const RESETS_RESET: usize = 0x0000;
const RESETS_DONE: usize = 0x0008;
const RESET_PIO0: u32 = 1 << 11;           // resets.h RESETS_RESET_PIO0_LSB 11
const RESET_DMA: u32 = 1 << 2;             // resets.h RESETS_RESET_DMA_LSB 2
const ATOMIC_CLR: usize = 0x3000;          // los alias atomicos del bus del RP2350

const PIO_CTRL: usize = 0x00;              // pio.h PIO_CTRL_OFFSET
const PIO_INSTR_MEM0: usize = 0x48;        // pio.h PIO_INSTR_MEM0_OFFSET
const PIO_SM0_CLKDIV: usize = 0xc8;
const PIO_SM0_EXECCTRL: usize = 0xcc;
const PIO_SM0_SHIFTCTRL: usize = 0xd0;
const PIO_SM0_INSTR: usize = 0xd8;
const PIO_SM0_PINCTRL: usize = 0xdc;
const EXECCTRL_WRAP_BOTTOM_LSB: u32 = 7;   // pio.h ..._WRAP_BOTTOM_LSB 7
const EXECCTRL_WRAP_TOP_LSB: u32 = 12;     // pio.h ..._WRAP_TOP_LSB 12
const SHIFTCTRL_OUT_SHIFTDIR: u32 = 1 << 19;
const PINCTRL_OUT_COUNT_LSB: u32 = 20;     // pio.h ..._OUT_COUNT_LSB 20
const PINCTRL_SET_BASE_LSB: u32 = 5;       // pio.h ..._SET_BASE_LSB 5
const PINCTRL_SET_COUNT_LSB: u32 = 26;     // pio.h ..._SET_COUNT_LSB 26

const IO_BANK0_BASE: usize = 0x4002_8000;
const PADS_BANK0_BASE: usize = 0x4003_8000;
const FUNCSEL_PIO0: u32 = 6;               // io_bank0.h ..._FUNCSEL_VALUE_PIO0_n

/// EL ANCHO DEL `out` VIVE EN LA INSTRUCCION, y por eso hay UN solo `.pio`.
///
/// `out` codifica la cuenta de bits en los bits 0..4 (0 significa 32). Nuestro cartucho
/// conduce 25 pines y la UVM2 27, y esa es la UNICA diferencia entre los dos programas —
/// el resto (la fase, el orden de las dos esperas, el `nop [14]`, los dos centinelas, el
/// park repetido) es identico y esta calibrado contra la consola.
///
/// Duplicar el fichero para cambiar un numero seria garantizar que las calibraciones se
/// separen. Se ensambla una vez y se parchea al instalar: `out pindirs, N` y `out pins, N`
/// son las unicas instrucciones con la cuenta, y se reconocen por su opcode.
///
///     15..13 = 0b011  -> OUT
///      7..5          -> destino (0 = PINS, 4 = PINDIRS)
///      4..0          -> cuenta de bits
fn parchea_ancho(instr: u16, ancho: u32) -> u16 {
    const OUT: u16 = 0b011 << 13;
    if (instr & (0b111 << 13)) != OUT {
        return instr;
    }
    let destino = (instr >> 5) & 0b111;
    if destino != 0 && destino != 4 {
        return instr;   // out y,1 / out null,N: no conducen pines, no se tocan
    }
    (instr & !0x1F) | ((ancho & 0x1F) as u16)
}

/// Deja el bus listo para el stream: pines al PIO, programa dentro, SM corriendo.
///
/// `programa` es el `.pio` ya ensamblado; `wrap`/`wrap_target` son sus indices relativos.
/// El llamante los saca de `pio_proc::pio_file!("src/bus_stream.pio")`, que se queda del
/// lado de quien tiene el proc-macro para no arrastrarlo a la imagen.
pub unsafe fn install(l: &Layout, programa: &[u16], wrap_target: u8, wrap: u8) {
    // PIO0 y DMA FUERA DEL RESET, explicitamente.
    //
    // Nada de darlo por hecho: `split(&mut RESETS)` hace esto para el PIO y NADIE lo hacia
    // para el DMA. Dos diseños de DMA completamente distintos fallaron igual, que era la
    // pista, y costo cuatro cuelgues del puerto de depuracion encontrarlo.
    w(RESETS_BASE + ATOMIC_CLR + RESETS_RESET, RESET_PIO0 | RESET_DMA);
    while r(RESETS_BASE + RESETS_DONE) & (RESET_PIO0 | RESET_DMA) != (RESET_PIO0 | RESET_DMA) {}

    // SM parada mientras se toca su configuracion.
    w(PIO0_BASE + PIO_CTRL, 0);

    // El programa, en el origen 0 y con el ancho de esta placa.
    let mut i = 0usize;
    while i < programa.len() && i < 32 {
        w(PIO0_BASE + PIO_INSTR_MEM0 + 4 * i, parchea_ancho(programa[i], l.out_count) as u32);
        i += 1;
    }

    // 1 ciclo de PIO = 1 ciclo de sistema. Aqui NADA esta contado en ciclos salvo el
    // `nop [14]` de la calibracion de fase, asi que el divisor solo cambiaria eso — y esa
    // calibracion esta medida a este divisor.
    w(PIO0_BASE + PIO_SM0_CLKDIV, 1 << 16);

    w(PIO0_BASE + PIO_SM0_EXECCTRL,
        ((wrap_target as u32) << EXECCTRL_WRAP_BOTTOM_LSB)
      | ((wrap as u32) << EXECCTRL_WRAP_TOP_LSB));

    // AUTOPULL APAGADO: el `pull noblock` explicito ES el mecanismo de aparcado. Con
    // autopull, un FIFO vacio bloquea la SM con los pines conduciendo la ULTIMA palabra —
    // una direccion de VIA que se re-engancha en cada bajada de E, a 1,5 MHz.
    w(PIO0_BASE + PIO_SM0_SHIFTCTRL, SHIFTCTRL_OUT_SHIFTDIR);

    w(PIO0_BASE + PIO_SM0_PINCTRL,
        l.out_base | ((l.out_count & 0x1F) << PINCTRL_OUT_COUNT_LSB));

    // LOS PADS, ANTES DE LA FUNCION Y SIN OLVIDAR EL AISLAMIENTO.
    //
    // En el RP2350 el pad arranca en 0x0116: ISO=1, IE=0. Un pad aislado NO CONDUCE NADA
    // por correcto que sea el FUNCSEL, y no da error, ni contador, ni sintoma propio —
    // solo pantalla negra, que es tambien el sintoma de otras seis cosas. Ya costo el
    // arranque del stream una vez, por GP19 (A15).
    let mut p = 0u32;
    while p < l.out_count {
        let gpio = (l.out_base + p) as usize;
        if l.out_dirs & (1 << p) != 0 {
            let pad = PADS_BANK0_BASE + 4 + 4 * gpio;
            let v = r(pad);
            w(pad, (v & !((1 << 8) | (1 << 7))) | (1 << 6));   // ISO=0, OD=0, IE=1
            w(IO_BANK0_BASE + 8 * gpio + 4, FUNCSEL_PIO0);
        }
        p += 1;
    }

    // Arrancar. Se queda bloqueada en su primer `pull block`, que es inofensivo — y es
    // ESTANDO HABILITADA cuando SM_INSTR ejecuta lo que se le escribe. Con la maquina
    // parada, las 27 escrituras de `set pindirs` no hicieron nada: medido en la consola,
    // salio EXACTAMENTE el mismo 0x06200201 que sin ellas, por dos caminos distintos.
    w(PIO0_BASE + PIO_SM0_INSTR, 0);        // jmp 0
    w(PIO0_BASE + PIO_CTRL, 1);             // SM_ENABLE bit 0

    // LAS DIRECCIONES DE PIN, DESDE LA CPU Y CON LA MAQUINA YA HABILITADA.
    //
    // El preambulo del .pio las pone con `out pindirs` leyendo una palabra de la FIFO, y
    // eso es lo que hace el firmware del otro cartucho. Aqui NO FUNCIONO: medido en la
    // consola, tras instalar solo conducian 5 de los 27 pines (0x06200201 en vez de
    // 0x073FFFFF), y ya en el momento de instalar — o sea que no era que la maquina se
    // reiniciara mas tarde, es que la mascara no llegaba a aplicarse entera.
    //
    // Esta forma es la del propio pico-sdk (`pio_sm_set_pindirs_with_mask`): pin a pin,
    // moviendo el grupo SET y ejecutando `set pindirs, 0/1` por SM_INSTR. No pasa por
    // ninguna FIFO, no depende de que el programa haya llegado a su segunda instruccion, y
    // se puede COMPROBAR leyendo IO_BANK0 justo despues — que es lo que hace
    // uvm2_stream_dirs_tras_install.
    //
    // El preambulo se queda igual y consume su palabra: aplica la misma mascara otra vez,
    // asi que es idempotente. No se toca el .pio, que lo comparte la placa que funciona.
    {
        let guardado = r(PIO0_BASE + PIO_SM0_PINCTRL);
        let mut i = 0u32;
        while i < l.out_count {
            let gpio = l.out_base + i;
            let dir = (l.out_dirs >> i) & 1;
            w(PIO0_BASE + PIO_SM0_PINCTRL,
                (1u32 << PINCTRL_SET_COUNT_LSB) | (gpio << PINCTRL_SET_BASE_LSB));
            // SET: opcode 111, destino PINDIRS = 4, dato en los bits 0..4.
            w(PIO0_BASE + PIO_SM0_INSTR, 0xE000 | (4u32 << 5) | dir);
            i += 1;
        }
        w(PIO0_BASE + PIO_SM0_PINCTRL, guardado);
    }

    DIRS_TRAS_SET.store(lee_oe(l), Ordering::Relaxed);



    // 1a palabra: las DIRECCIONES de pin. Las pone la propia SM con `out pindirs`, usando
    // por construccion la misma base y cuenta que el `out pins` de abajo — asi no pueden
    // desalinearse. Confiarselas al HAL dejo los 25 pines como ENTRADAS: la SM corria,
    // consumia el FIFO y ejecutaba `out pins`, y el pad no conducia nada.
    empuja_crudo(l.out_dirs);
    // 2a palabra: el patron de PARK, que va a X. CON SU CENTINELA: la rama de aparcado
    // hace `mov osr, x` y luego `out null, 1` para tirarlo antes de conducir, igual que
    // hace `pull noblock` cuando cae a X por su cuenta. Sin el centinela, ese `out null`
    // se come el bit bajo de la direccion y el bus aparca en otro sitio.
    empuja_crudo(l.word(l.park));
}

/// Escribe directo al FIFO, sin lote. Solo para el preambulo: el DMA aun no corre.
unsafe fn empuja_crudo(word: u32) {
    let mut n = 0u32;
    while r(PIO0_BASE + PIO_FSTAT) & (1 << 16) != 0 {   // TXFULL de la SM0
        n += 1;
        if n > 100_000 { STREAM_STALLS.fetch_add(1, Ordering::Relaxed); return; }
    }
    w(PIO_TXF0 as usize, word);
}

/// El programa ensamblado, sus indices de `wrap`, y su longitud.
///
/// Se ensambla AQUI y no en cada consumidor: si cada placa corriera el ensamblador por su
/// cuenta bastaria que una quedase apuntando a una copia vieja del `.pio` para que las dos
/// calibraciones se separaran en silencio. El proc-macro corre en el anfitrion; no entra
/// nada de el en la imagen.
pub fn programa() -> (&'static [u16], u8, u8) {
    static mut CODIGO: [u16; 32] = [0; 32];
    static mut LARGO: usize = 0;
    static mut WT: u8 = 0;
    static mut WR: u8 = 0;
    unsafe {
        if LARGO == 0 {
            let p = pio_proc::pio_file!("src/bus_stream.pio");
            let c = p.program.code;
            LARGO = c.len();
            let mut i = 0;
            while i < c.len() { CODIGO[i] = c[i]; i += 1; }
            WT = p.program.wrap.target;
            WR = p.program.wrap.source;
        }
        (&CODIGO[..LARGO], WT, WR)
    }
}

/// Deja el anillo como recien arrancado. La llama quien acaba de sacar el DMA del reset:
/// el canal no conserva nada, pero el indice y el relleno del lote si.
pub fn reset() {
    BATCH_IDX.store(0, Ordering::Relaxed);
    BATCH_FILL.store(0, Ordering::Relaxed);
}
