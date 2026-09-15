/**
 * Uvm2System — simulates a VPy image running on the Ultimate Vectrex Multicart 2.
 *
 * This is deliberately NOT the RP2350 system with a different loader. That one
 * traps every `svc` in JavaScript and injects vectors straight into the beam,
 * which is right for our own cartridge — the syscalls really are implemented by
 * firmware there. On the UVM2 there is no firmware: the syscall handler, the
 * halt-mode bus protocol and the beam timing all live INSIDE the image, and
 * they are precisely the code that has never run on hardware.
 *
 * So this system emulates the wire instead:
 *   - SIO GPIO registers at 0xD0000000, with the Vectrex CLK on bit 31
 *   - a 1.5 MHz bus clock derived from CPU cycles
 *   - the address/data/R-W lines decoded on each falling edge into a real
 *     Via6522 write, exactly as the hardware latches them
 *   - Via6522 + Beam ticked once per bus cycle, so the analog integrators
 *     produce vectors from our own ramp timings
 *   - `svc` performing a real Cortex-M exception entry into the image's own
 *     handler, rather than being intercepted
 *
 * The payoff is that a wrong CLK phase, a mis-encoded command, a ramp that is
 * too short or a frame over budget all show up here the same way they would on
 * a real console.
 */

import type { Segment } from '../../emulatorCore.js';
import type { ISystem } from '../interfaces/ISystem.js';
import type { IBus } from '../interfaces/IBus.js';
import { Via6522 } from '../hardware/Via6522.js';
import { Beam }    from '../hardware/Beam.js';
import { Psg }     from '../hardware/Psg.js';
import { Canvas }  from '../hardware/Canvas.js';
import { Thumb2 }  from '../cpu/Thumb2.js';
import { extractElf32Symbols, loadElf32ByPaddr } from '../util/Elf32Symbols.js';

/** Beam vector list → the IDE's Segment shape (same mapping the other systems use). */
function vectorsToSegments(
  draw: readonly { x0: number; y0: number; x1: number; y1: number; color: number; ticks: number }[],
  drawCnt: number,
  frameCounter: number,
): Segment[] {
  const segments: Segment[] = [];
  for (let i = 0; i < drawCnt; i++) {
    const v = draw[i];
    segments.push({ x0: v.x0, y0: v.y0, x1: v.x1, y1: v.y1,
                    intensity: v.color, frame: frameCounter, ticks: v.ticks });
  }
  return segments;
}

// ── Memory map ──────────────────────────────────────────────────────────────
const SRAM_BASE = 0x20000000;

/** Profundidad de los historiales del informe de fallo. Potencias de dos. */
const PC_HIST = 32;
/** Historial de SALTOS (origen -> destino). Vale mucho mas que el de PCs seguidos:
 *  cuando el PC se va, los 32 PCs previos son la caida en linea recta y el salto
 *  culpable ya se ha ido del anillo. */
const SALTO_HIST = 24;
/** La tabla de vectores ocupa los primeros 64*4 bytes de la imagen. Son DATOS:
 *  ejecutar ahi es siempre un error, y detectarlo en el acto ahorra rastrear el
 *  choque que ocurre unas instrucciones despues. */
const VECTORES_FIN = SRAM_BASE + 64 * 4;

// ─── La ROM de arranque del RP2350 ────────────────────────────────────────────
//
// El runtime del pico-sdk llama a la bootrom durante la inicializacion estatica:
//
//     movs r3, #0
//     ldrh r3, [r3, #22]     @ el puntero a rom_table_lookup vive en 0x00000016
//     tt   r2, r2            @ seguro o no seguro -> elige la mascara
//     movs r1, #16 / #4      @ RT_FLAG_FUNC_ARM_NONSEC / _SEC
//     bx   r3
//
// Sin nada mapeado ahi, ese ldrh devuelve 0 y el `bx r3` salta a la direccion 0.
// El PC se pierde, recorre la tabla de vectores como si fuera codigo y acaba
// estrellandose contra el manejador por defecto — que en el log aparece como
// "Unimplemented 16-bit misc: 0xbe00" y no se parece en nada a la causa.
//
// En hardware la bootrom esta, asi que la imagen es correcta: esto es un agujero
// del emulador, no del juego.
//
// Se sintetiza lo minimo: el puntero de 0x16, un rom_table_lookup que se atiende
// de forma nativa, y una funcion que no hace nada y devuelve 0.
/** Escritura a un bloque y sus alias: 0 normal, 1 XOR, 2 SET, 3 CLR. */
function atomico(prev: number, alias: number, bits: number, mask: number): number {
  return (alias === 1 ? (prev ^ bits)
        : alias === 2 ? (prev | bits)
        : alias === 3 ? (prev & ~bits)
        : ((prev & ~mask) | bits)) >>> 0;
}

const BOOTROM_SIZE   = 0x4000;
const ROM_LOOKUP     = 0x00000100;   // rom_table_lookup sintetica (se intercepta)
const ROM_NOOP       = 0x00000110;   // funcion que no hace nada y devuelve 0
/** ROM_TABLE_CODE(c1,c2) = c1 | c2<<8. Los codigos que sabemos ignorar sin dañar. */
const ROM_IGNORABLES: Record<number, string> = {
  0x5253: "bootrom_state_reset('S','R')",
};

// ─── El arranque del pico-sdk ─────────────────────────────────────────────────
//
// Una imagen UVM2 construida por el camino del pico-sdk (build_uvm2.sh) NO salta
// directa a game_main: antes corre el runtime_init entero, que saca periféricos
// del reset, arranca el cristal, engancha los PLL y conmuta el árbol de relojes
// — y en cada paso ESPERA un bit de "listo". Un registro que lee 0 no da error:
// deja el juego girando para siempre, y en pantalla eso es "no hace nada".
//
// Lo que sigue es el mínimo para que esas esperas terminen. No pretende ser un
// modelo del reloj: aquí no hay frecuencias que respetar, sólo un protocolo que
// contestar. Cada dirección viene de desensamblar la imagen y verla girar.
const RESETS_BASE = 0x40020000;   // RESET(0) WDSEL(4) RESET_DONE(8) + alias atómicos
const XOSC_BASE   = 0x40048000;   // CTRL(0) STATUS(4): bit31 STABLE
const PLL_BASES    = [0x40050000, 0x40058000];   // PLL_SYS / PLL_USB, CS(0) bit31 LOCK
const CLOCKS_BASE = 0x40010000;   // CTRL/DIV/SELECTED por reloj + alias atómicos
const ATOM_SIZE   = 0x4000;       // el bloque y sus tres alias XOR/SET/CLR
// BOOTRAM: memoria normal, salvo los BOOT LOCKS de +0x800, que son cerrojos —
// leerlos INTENTA adquirir (devuelve != 0 si se logra, 0 si estaba tomado) y
// escribirlos suelta. El arranque del pico-sdk toma uno y espera:
//     ldr r3, [r2, #0x828] ; cmp r3, #0 ; beq . ; dmb sy
// Sin modelarlos, esa lectura da 0 para siempre. Como memoria normal TAMPOCO
// funciona: nadie escribe ese valor antes: lo pone el hardware al conceder.
const TIMER0_BASE = 0x400B0000;   // TIMEHR(8) TIMELR(C) TIMERAWH(24) TIMERAWL(28)
const BOOTRAM_BASE  = 0x400E0000;
const BOOTRAM_SIZE_ = 0x1000;
const BOOTLOCK_OFF  = 0x800;
const BOOTLOCK_N    = 16;
const SRAM_SIZE = 0x00082000;
/* LA PSRAM DEL UVM2, 8 MB por la ventana XIP de CS1 (0x11000000) y por su alias sin cache
 * (0x15000000). Sin ella, cualquier imagen que la use falla EN SILENCIO: dkong con el romset
 * en PSRAM arrancaba con dk_rom_error=1 y pintaba la X de "falta el romset", y una tarde de
 * medidas se hizo sobre esa X creyendo que era la partida. Medido en placa: 8 MB R/W en
 * 0x11000000 [[rp2350-psram-xip]]; el alias 0x15000000 es el que usa uvm2_romzip.c
 * (UVM2_ROMZIP_PSRAM_BASE = 0x15400000). Los registros del QMI que la configuran caen en la
 * zona "desconocida" del mapa y se ignoran, que es lo que ya hacia. */
const PSRAM_BASE  = 0x11000000;
const PSRAM_ALIAS = 0x15000000;
const PSRAM_SIZE  = 0x00800000;
function psramOff(addr: number): number {
  if (addr >= PSRAM_BASE  && addr < PSRAM_BASE  + PSRAM_SIZE) return addr - PSRAM_BASE;
  if (addr >= PSRAM_ALIAS && addr < PSRAM_ALIAS + PSRAM_SIZE) return addr - PSRAM_ALIAS;
  return -1;
}          // 520 KB, as on the real RP2350
const SIO_BASE  = 0xD0000000;

/* PSM — el "power state machine", que es por donde se resetea el nucleo 1.
 *
 * HIZO FALTA EL 2026-08-24. La imagen empezo a llamar a `multicore_reset_core1()` antes de
 * lanzar el nucleo 1 (hace falta para poder cargar por SWD encima de una imagen que ya
 * corre: si no, el nucleo 1 sigue en el bucle de la anterior y el saludo no llega nunca).
 * Y esa funcion no pasa por la FIFO —que aqui ya estaba falseada— sino que escribe el bit
 * de proc1 en FRCE_OFF y GIRA hasta leerlo de vuelta:
 *
 *     *power_off_set = PSM_FRCE_OFF_PROC1_BITS;
 *     while (!(*power_off & PSM_FRCE_OFF_PROC1_BITS)) tight_loop_contents();
 *
 * Sin modelarlo la lectura devolvia 0, el bucle no salia y el emulador se quedaba MUDO —
 * sin error, sin traza, sin dibujar. Indistinguible de "no arranca".
 *
 * Basta con que el registro RECUERDE lo que se le escribe, con sus alias atomicos. Aqui no
 * hay segundo nucleo que apagar, asi que apagarlo no tiene que hacer nada mas. */
const PSM_BASE = 0x40018000;
const PSM_FRCE_OFF = 0x004;
/* LA MASCARA CUBRE LOS CUATRO ALIAS y nada mas: 0x40018000..0x4001BFFF son el registro y
 * sus alias XOR/SET/CLR (+0x1000 cada uno).
 *
 * Primero puse 0xFFFF0000, que da 0x40010000 para cualquier direccion de esa pagina y por
 * tanto NUNCA coincidia con PSM_BASE: el manejador no se ejecutaba jamas y el sintoma era
 * identico a no haberlo escrito. Se ve con una resta, sin encender nada. */
const PSM_MASK = 0xFFFFC000;
/** El bit del nucleo 1 dentro de FRCE_OFF. */
const PSM_PROC1 = 0x01000000;

/* PIO0 — el flujo de bus por PIO+DMA (vectrex-bus). NO es una emulacion del PIO: es un
 * modelo de LO QUE EL PROGRAMA HACE, que para dibujar es lo unico que importa.
 *
 * `bus_stream.pio` es un bucle de una escritura por periodo de E, alimentado por el TX
 * FIFO. Cada palabra la arma `Layout::word(bus) = (bus >> out_base) << 1 | 1`, y el UVM2
 * instala out_base = 0 con 27 pines (GP0..GP26) — o sea EXACTAMENTE el mapa que este
 * emulador ya modela: datos 0-7, A0-A13 en 8-21, A14/A15 en 24/25, R/W en 26.
 *
 *     bit 0 = 1   escritura: los 27 bits siguientes van a los pines
 *     bit 0 = 0, bit 1 = 1   aparcar N periodos (N-1 en los bits 2..25)
 *     bit 0 = 0, bit 1 = 0   un periodo en silencio
 *
 * Sin esto el nucleo 1 se quedaba en `vectrex_bus::drain` para siempre: espera a que el
 * FIFO se vacie, y un FIFO que nadie consume no se vacia nunca. */
/* DMA canal 0 — QUIEN LLEVA DE VERDAD LAS PALABRAS AL PIO.
 *
 * La CPU no escribe el TX FIFO: `vbus_push` acumula en un lote en RAM y `batch_flush`
 * programa el canal 0 (origen = el lote, destino = PIO_TXF0, cuenta = n) y lo dispara
 * escribiendo CTRL_TRIG. Modelar solo TXF0 no veia NADA — medido: "palabras del stream: 0"
 * con el juego dibujando por ese camino.
 *
 * Aqui la transferencia es SINCRONA: al disparar se consumen las n palabras de golpe. Por
 * eso BUSY se lee siempre a cero, y `batch_flush` —que espera a que se libere— no gira. */
const DMA_BASE       = 0x50000000;
const DMA_CH_STRIDE  = 0x40;
const DMA_READ_ADDR  = 0x00;
const DMA_TRANS_COUNT = 0x08;
const DMA_CTRL_TRIG  = 0x0C;
const DMA_EN         = 1 << 0;

const PIO0_TXF0  = 0x50200010;
const PIO0_FSTAT = 0x50200004;
const PIO0_BASE  = 0x50200000;
const PIO_TXEMPTY_SM0 = 1 << 24;   // pio.h: FSTAT TXEMPTY empieza en el bit 24

// ── Timing ──────────────────────────────────────────────────────────────────
/** RP2350 core cycles per Vectrex bus cycle (150 MHz / 1.5 MHz). */
const CPU_PER_BUS   = 100;
/** A 50 Hz Vectrex frame. Matches UVM2_CYCLES_PER_FRAME in the SDK. */
const BUS_PER_FRAME = 30000;
/** El refresco que la BIOS acostumbra, del que sale todo lo demas. */
const VECTREX_HZ = 50;
/** Microsegundos de CPU emulada por ciclo de CPU: 30000 x 50 x 100 = 150 MHz. */
const CPU_POR_US = (BUS_PER_FRAME * VECTREX_HZ * CPU_PER_BUS) / 1_000_000;
/** Escape hatch: an image that never advances the bus must not hang the IDE. */
const MAX_CPU_CYCLES_PER_FRAME = 40_000_000;

// ── GPIO bit assignments (must match uvm2_bus.h) ────────────────────────────
const DATA_MASK = 0x000000FF;
const ADDR_MASK = 0x003FFF00;          // A0-A13 on GPIO8-21
const A14_MASK  = 0x01000000;
const A15_MASK  = 0x02000000;
const RW_MASK   = 0x04000000;          // 1 = read, 0 = write
const HALT_MASK = 0x08000000;
const CLK_MASK  = 0x80000000;
const PULLUP_IN = 0x20C00000;

/* DOS PLACAS, UN EMULADOR. La imagen .um2 corre en la UVM2 de Ralf; la BIOS del cartucho de
 * Vectrex Studio (hardware/debug_cart/firmware) corre en la nuestra. Desde el 2026-09-15 las
 * dos construyen la lista de comandos con EL MISMO uvm2_draw.c y solo cambia el mapa de
 * pines (uvm2_bus.h: UVM2_PALABRA_VIA; board.rs), asi que aqui el mapa es un PERFIL y todo
 * lo demas —VIA, haz, PIO, DMA, PSM, PSRAM— es el mismo modelo. Es lo que permite comparar
 * las escrituras a la VIA de las dos placas con el mismo juego (VIADUMP). */
export interface Placa {
  nombre: string;
  /** El `out` del PIO: primer GPIO y cuantos. Layout::word(bus) = (bus >> out_base) << 1 | 1. */
  outBase: number; outCount: number;
  /** Datos y direccion, como campos de GPIO_OUT. */
  dataShift: number; dataMask: number;
  addrShift: number; addrMask: number;   // A0.. contiguos desde addrShift
  a14Mask: number; a15Mask: number;      // 0 si A14/A15 van dentro del campo contiguo
  rwMask: number;                        // 1 = lectura
  haltMask: number; haltAssertHigh: boolean;
  pullupIn: number;                      // lo que se lee alto sin conducir nada
  /** Palabra de aparcado del stream, ya como bits de GPIO. */
  park: number;
}
export const PLACA_UVM2: Placa = {
  nombre: 'uvm2', outBase: 0, outCount: 27,
  dataShift: 0, dataMask: DATA_MASK, addrShift: 8, addrMask: ADDR_MASK,
  a14Mask: A14_MASK, a15Mask: A15_MASK, rwMask: RW_MASK,
  haltMask: HALT_MASK, haltAssertHigh: false, pullupIn: PULLUP_IN,
  park: A15_MASK | RW_MASK,
};
/* board.rs (debug_cart): A0-A14 en GP4-18, /CE GP19 = A15, ABUS_DIR GP20, datos GP21-28,
 * DIR_CTRL GP29, R/W GP30, E GP31, /HALT GP1 y ASSERTA ALTO. vinterface.rs: out_base = 4,
 * 25 pines, park = (0xC000 << 4) | (0x5A << 21). */
export const PLACA_PROPIA: Placa = {
  nombre: 'debug_cart', outBase: 4, outCount: 25,
  dataShift: 21, dataMask: 0x1FE00000, addrShift: 4, addrMask: 0x000FFFF0,
  a14Mask: 0, a15Mask: 0, rwMask: 1 << 30,
  haltMask: 1 << 1, haltAssertHigh: true, pullupIn: 0,
  park: ((0xC000 << 4) | (0x5A << 21)) >>> 0,
};
/* La flash del RP2350 (XIP), 4 MB en 0x10000000: la BIOS arranca de ahi (vector table +
 * __pre_init, que copia el codigo a SRAM) y luego corre en RAM. La .um2 no la usa. */
const FLASH_BASE = 0x10000000;
const FLASH_SIZE = 0x00400000;
/* QMI en modo directo (0x400d0000): lo que usa psram::init (BIOS) y uvm2_psram.c (.um2)
 * para leer el ID de la PSRAM antes de abrir la ventana XIP. Sin esto el ID se lee a 0,
 * la BIOS da la PSRAM por muerta y SYS_LAUNCH se niega a cargar nada. Se modela lo justo:
 * un byte de respuesta por byte enviado, y al comando 0x9F (READ ID) contesta el
 * APS6404L: MF 0x0D, KGD 0x5D. Registros de hardware/regs/qmi.h. */
const QMI_BASE = 0x400D0000;
const QMI_DIRECT_CSR = 0x00, QMI_DIRECT_TX = 0x04, QMI_DIRECT_RX = 0x08;
const QMI_CSR_EN = 1 << 0, QMI_CSR_ASSERT_CS1N = 1 << 3, QMI_CSR_TXEMPTY = 1 << 11;
/** Pins the cartridge pulls up and never drives: PB6, /IRQ, /NMI. */

/** EXC_RETURN we hand the handler: thread mode, main stack, no FP context. */
const EXC_RETURN = 0xFFFFFFF9;

export class Uvm2System implements ISystem, IBus {
  readonly cpuName = 'Cortex-M33 (UVM2 halt mode)';

  private sram = new Uint8Array(SRAM_SIZE);
  private psram = new Uint8Array(PSRAM_SIZE);
  private cargaEnPsram = false;
  private cpu  = new Thumb2();
  /** EL SEGUNDO NUCLEO, DE VERDAD.
   *
   * Antes se falseaba el saludo del arranque para que core 0 siguiera, y lo que corriera en
   * core 1 simplemente no pasaba. Para un juego de doble nucleo eso no es "medio juego": en
   * el UVM2 core 1 es QUIEN DIBUJA (uvm2_core1.c llama a uvm2_exec), asi que la pantalla se
   * quedaba negra y core 0 acababa girando en la espera de uvm2_frame_end.
   *
   * Arranca cuando el pico-sdk termina su secuencia {0, 0, 1, vector_table, sp, entry}: las
   * dos ultimas palabras son la pila y el punto de entrada, y con eso ya se puede correr. */
  private cpu1: Thumb2 | null = null;
  private lanzamiento: number[] = [];
  private rastro1: number[] = [];
  private cpu1Perdido = false;
  private cpu1FetchEnSram = true;
  /** Media palabra del stream mientras llegan sus cuatro bytes. */
  viaHist = new Uint32Array(16);
  orbHist = new Uint32Array(256);
  oraHist = new Uint32Array(256);
  cambiosYsh = 0; private ultimoYsh = -1;
  traza: string[] = [];
  viaFull: number[] = [];   // volcado completo (ciclo,reg,dato) x N para comparar con la captura VecFever
  yshHist = new Uint32Array(256);
  trazaPio: string[] = [];
  private pioLatch = 0;
  /** Palabras de preambulo que quedan por tirar. Ver pioPalabra. */
  private pioPreambulo = 2;
  /** El patron de PARK, del preambulo. Ver pioPalabra. */
  /** El patron de APARCADO, del hardware y no del flujo.
   *
   * `uvm2_bus.h` lo define como A15 sin A14 mas R/W a uno: no decodifica a la VIA (que
   * esta en A15|A14) y ademas es un ciclo de lectura, asi que aparcar es no escribir. Se
   * pone aqui como constante en vez de deducirlo de las palabras del preambulo: lo intente
   * y las dos primeras palabras no cuadraban con la definicion, y una heuristica que se
   * equivoca en silencio es peor que un dato copiado de su cabecera. */
  private placa: Placa = PLACA_UVM2;
  private flash: Uint8Array | null = null;
  private sdImagen: Uint8Array | null = null;
  private sdHwInitAddr = 0;
  private sdHwReadBlockAddr = 0;
  private sdHwWriteBlockAddr = 0;
  private qmiCsr = 0;
  private qmiCs1 = false;
  private qmiCmd: number[] = [];
  private qmiRx: number[] = [];
  pioEsc = 0; pioPark_n = 0; pioSil = 0;
  private pioVistas = 0;
  txfDirectas = 0; dmaPalabras = 0;
  /** LA TARJETA SD, ATENDIDA POR TRAMPA DE SIMBOLO.
   *
   * El juego lee su romset con `uvm2_sd_leer(ruta, dst, max)`, que en el cartucho habla por
   * SPI con una SD de verdad. Emular el SPI seria emular el protocolo entero para acabar
   * copiando unos bytes; en su lugar se atrapa la FUNCION por su direccion del ELF y se
   * hace lo que hace: copiar el fichero al buffer y devolver cuantos bytes.
   *
   * Es el mismo criterio con el que ya se atrapa `rom_table_lookup` de la bootrom. Y hace
   * falta el ELF: sin simbolos no hay a que direccion atrapar, y el juego pinta su X de
   * "falta el romset" sin que nada explique por que. */
  private sdArchivos: Record<string, Uint8Array> = {};
  private sdLeerAddr = 0;
  private sdLeerDesdeAddr = 0;
  private sdErrorAddr = 0;
  /** Registros del canal 0 del DMA, por indice de palabra. */
  private dmaRegs = new Uint32Array(16);
  /** Cuantas palabras del stream se han consumido. Solo para diagnostico. */
  pioPalabras = 0;
  private via: Via6522;
  private beam = new Beam();
  private psg  = new Psg();
  private canvas: Canvas;

  // Halt-mode bus state
  private gpioOut  = 0;
  private gpioOe   = 0;
  private clkHigh  = false;
  private dataIn   = 0xFF;             // what the VIA drives back at us
  private busCycle = 0;
  /** Ciclos de CPU emulada desde el reset, sin truncar. La base del TIMER0. */
  /* PUBLICO: `tools/contadores.mjs` lo lee para comprobar la relacion entre el reloj del
   * bus y el TIMER del juego, que tiene que ser 1,5 ciclos por microsegundo. */
  cpuCiclos = 0;
  /** La parte alta que TIMELR dejo enganchada en su ultima lectura. */
  private timerAlta = 0;

  /* ── LO QUE COSTO EL ULTIMO FRAME COMPLETO ────────────────────────────────
   *
   * En ciclos de bus del Vectrex, que es lo unico de aqui que se puede comparar con la
   * consola: la lista de comandos se reproduce a un ciclo por comando igual en los dos
   * sitios. El tiempo de CPU NO vale — este emulador no modela esperas de memoria y sale
   * unas veinte veces optimista. */
  private frameBeginAddr = 0;
  private statsAddr = 0;
  /** Ciclos de bus del ultimo frame completo, o 0 si aun no se sabe. */
  ciclosDeBus = 0;
  /** Vectores iluminados de ese mismo frame. */
  vectoresDeBus = 0;
  /** Frames que el juego ha cerrado desde el reset. */
  framesDelJuego = 0;
  private cpuAcc   = 0;
  /* ── DOS NUCLEOS, UN RELOJ ───────────────────────────────────────────────────
   *
   * Cada nucleo lleva SU tiempo en ciclos de CPU y el bus avanza con el MENOR de los dos,
   * que es el instante que los dos han alcanzado ya. Antes se daba un paso de core 1 por
   * cada paso de core 0 y el bus se alimentaba SOLO de los ciclos de core 0 — o sea que
   * los dos nucleos corrian a la misma tasa de INSTRUCCIONES en vez de a la misma tasa de
   * CICLOS, y el reloj del bus lo marcaba el nucleo que no dibuja. En el UVM2 quien saca
   * el stream es core 1.
   *
   * Se ve en el frame del propio juego, medido entre sus escrituras de ACR=0x98:
   *     emulador, un paso cada uno   61490 ciclos de bus   (24 Hz)
   *     consola (su HUD de fps)      ~32600                (46 Hz)
   * casi el doble, y en la misma direccion que el sesgo del intercalado.
   *
   * Con dos relojes no hay bloqueo mutuo: avanzar CUALQUIERA de los dos mueve el minimo en
   * cuanto el otro le alcanza, asi que un nucleo girando a la espera del reloj de bus deja
   * correr al otro igual. */
  private relojCore0 = 0;
  private relojCore1 = 0;
  private relojBus   = 0;
  private cycleCount = 0;              // DWT_CYCCNT
  private lastPollPc = -1;             // spin detection, see maybeCollapseSpin
  /** PSM.FRCE_OFF: solo tiene que recordar. Ver la nota de PSM_BASE. */
  private psmFrceOff = 0;
  /** Frames seguidos sin un solo vector, y si ya se aviso. Ver runFrame. */
  private framesMudos = 0;
  private avisoMudo = false;
  private gpioInLatch = 0;             // 32-bit GPIO_IN snapshot, see read8

  private vtor = SRAM_BASE;

  /**
   * Diagnóstico de "corre pero no dibuja".
   *
   * Una CPU que no falla y una pantalla en negro no dan ninguna pista: puede ser
   * un bucle de espera, puede ser que el juego no toque el bus, o puede que lo
   * toque y el haz no se mueva. Estas tres cuentas separan los tres casos, y el
   * perfil dice DÓNDE está si es lo primero.
   *
   * El perfil se muestrea uno de cada 64 pasos: para localizar un bucle sobra, y
   * no cuesta nada medible.
   */
  private readonly perfil = new Map<number, number>();
  private muestra = 0;
  private escriturasVia = 0;
  private framesSinDibujo = 0;
  private avisadoSinDibujo = false;

  private informeSinDibujo(): void {
    const top = [...this.perfil.entries()].sort((a, b) => b[1] - a[1]).slice(0, 10);
    const tot = [...this.perfil.values()].reduce((a, b) => a + b, 0) || 1;
    console.warn(
      `[Uvm2System] ${this.framesSinDibujo} frames sin un solo vector. ` +
      `Escrituras a la VIA en todo ese rato: ${this.escriturasVia}. ` +
      (this.escriturasVia === 0
        ? 'CERO: el juego no esta tocando el bus, asi que el problema es ANTERIOR al dibujo.'
        : 'El juego SI escribe la VIA, asi que mira el haz, no la CPU.'));
    console.warn('[Uvm2System] Donde pasa el tiempo:\n' + top
      .map(([pc, c]) => `  0x${pc.toString(16)}  ${(100 * c / tot).toFixed(1)}%`).join('\n'));
    console.warn('[Uvm2System] Ultimos saltos:', this.historialSaltos().join(' '));
  }

  /** BOOTRAM y sus cerrojos. */
  private readonly bootram = new Uint8Array(BOOTRAM_SIZE_);
  private bootlocks = 0;
  private ultimoCerrojo = 0;

  /** Máscara de periféricos en reset. RESET_DONE es su complemento. */
  private resets = 0;
  /** Fichero de registros de CLOCKS, en palabras. */
  private readonly clocks = new Uint32Array(0x40);
  /**
   * SELECTED es el one-hot de la fuente elegida en CTRL, y el runtime lo compara
   * por IGUALDAD, no por máscara — devolver "todos los bits" no vale. clk_ref usa
   * dos bits de SRC y clk_sys uno; los demás muxes no son glitchless y leen 1.
   */
  private leerClocks(off: number): number {
    if (off === 0x38) return (1 << (this.clocks[0x30 >> 2] & 3)) >>> 0;  // CLK_REF_SELECTED
    if (off === 0x44) return (1 << (this.clocks[0x3C >> 2] & 1)) >>> 0;  // CLK_SYS_SELECTED
    if (off >= 0x30 && ((off - 0x38) % 12) === 0) return 1;
    return this.clocks[off >> 2];
  }

  /** ROM de arranque sintetica (ver arriba). */
  private readonly bootrom = new Uint8Array(BOOTROM_SIZE);
  /* QMI modo directo, ver la constante QMI_BASE. */
  private qmiLeer(off: number): number {
    if (off === QMI_DIRECT_CSR) {
      /* BUSY siempre a 0, TXEMPTY siempre a 1, RXEMPTY a 1 solo si no hay nada que leer. */
      const rxempty = this.qmiRx.length === 0 ? (1 << 16) : 0;
      return ((this.qmiCsr & (QMI_CSR_EN | QMI_CSR_ASSERT_CS1N)) | QMI_CSR_TXEMPTY | rxempty) >>> 0;
    }
    if (off === QMI_DIRECT_RX) return this.qmiRx.length ? this.qmiRx.shift()! : 0xFF;
    return 0;
  }
  private qmiEscribir(off: number, byte: number, data: number): void {
    if (off === QMI_DIRECT_CSR) {
      if (byte === 0) {
        const antes = this.qmiCs1;
        this.qmiCsr = (this.qmiCsr & ~0xFF) | data;
        this.qmiCs1 = (data & QMI_CSR_ASSERT_CS1N) !== 0;
        if (this.qmiCs1 && !antes) this.qmiCmd = [];   // nueva transaccion
      }
      return;
    }
    if (off === QMI_DIRECT_TX && byte === 0) {
      /* SPI: un byte de respuesta por byte enviado. Tras 0x9F (READ ID) y 3 bytes de
       * direccion, el chip contesta MF=0x0D, KGD=0x5D, y luego el EID. */
      this.qmiCmd.push(data);
      const k = this.qmiCmd.length;
      let r = 0xFF;
      if (this.qmiCmd[0] === 0x9F) r = k <= 4 ? 0xFF : k === 5 ? 0x0D : k === 6 ? 0x5D : 0x00;
      if (this.qmiCmd[0] === 0x9F && k === 6 && !this.qmiIdVisto) { this.qmiIdVisto = true; console.log('[Uvm2System] PSRAM: READ ID contestado (0x0D 0x5D)'); }
      this.qmiRx.push(r);
    }
  }
  /* La costura de la SD del firmware (sd.rs: sd_hw_init / sd_hw_read_block). */
  private atiendeSdHwInit(cpu: Thumb2): void {
    cpu.setReg(0, this.sdImagen ? (1 | 2 | 4) : 0);   // presente, inicializada, SDHC (lba)
    cpu.setReg(15, cpu.getReg(14) & ~1);
  }
  /* sd_hw_write_block(lba, sdhc, buf): escribe en la imagen en memoria (no en el disco). */
  private atiendeSdHwWriteBlock(cpu: Thumb2): void {
    const lba = cpu.getReg(0) >>> 0, buf = cpu.getReg(2) >>> 0;
    let ok = 0;
    if (this.sdImagen && (lba + 1) * 512 <= this.sdImagen.length) {
      for (let i = 0; i < 512; i++) this.sdImagen[lba * 512 + i] = this.read8((buf + i) >>> 0);
      ok = 1;
      console.log(`[Uvm2System] SD ESCRITO bloque ${lba} (en la imagen en memoria)`);
    }
    cpu.setReg(0, ok);
    cpu.setReg(15, cpu.getReg(14) & ~1);
  }
  private atiendeSdHwReadBlock(cpu: Thumb2): void {
    const lba = cpu.getReg(0) >>> 0, buf = cpu.getReg(2) >>> 0;
    let ok = 0;
    if (this.sdImagen && (lba + 1) * 512 <= this.sdImagen.length) {
      for (let i = 0; i < 512; i++) this.write8((buf + i) >>> 0, this.sdImagen[lba * 512 + i]);
      ok = 1;
    }
    if (this.sdBloquesVistos < 12 || this.frameCounter > 370) { this.sdBloquesVistos++; console.log(`[Uvm2System] SD bloque ${lba} -> 0x${buf.toString(16)} ${ok ? 'ok' : 'FUERA DE LA IMAGEN'}  desde lr=0x${(cpu.getReg(14) >>> 0).toString(16)} core=${cpu === this.cpu ? 0 : 1}`); }
    cpu.setReg(0, ok);
    cpu.setReg(15, cpu.getReg(14) & ~1);
  }
  private sdBloquesVistos = 0;
  private enStream = false;
  private execAddr = 0;
  private execVuelta = [0, 0];   // LR guardado por nucleo mientras esta dentro de uvm2_exec
  private enLista = 0;
  private volcarEn = Number((globalThis as any).__VOLCAR ?? 0) >>> 0;
  private volcados = 0;
  private qmiIdVisto = false;
  private leidoEnCiclo = -1;
  trazaLecturas: string[] = [];
  lecturasIfr = 0;
  private montarBootrom(): void {
    this.bootrom.fill(0);
    // 0x16: puntero de 16 bits a rom_table_lookup, con el bit Thumb.
    const lk = ROM_LOOKUP | 1;
    this.bootrom[0x16] = lk & 0xff;
    this.bootrom[0x17] = (lk >>> 8) & 0xff;
    // Las dos rutinas llevan `bx lr` de verdad por si alguna vez se ejecutan;
    // rom_table_lookup se intercepta antes, y la no-op se ejecuta tal cual.
    const bxlr = [0x70, 0x47];                       // bx lr
    const movs0 = [0x00, 0x20];                      // movs r0, #0
    this.bootrom.set(bxlr, ROM_LOOKUP);
    this.bootrom.set(movs0, ROM_NOOP);
    this.bootrom.set(bxlr, ROM_NOOP + 2);
  }

  /**
   * rom_table_lookup(r0 = codigo, r1 = mascara) -> r0 = puntero a la funcion.
   *
   * Se atiende aqui y no con codigo ARM sintetico porque la tabla real de la
   * bootrom no existe: lo unico que se puede hacer es decidir, por codigo, si la
   * llamada se puede ignorar. Las que no conocemos se NOMBRAN en el log con sus
   * dos letras ASCII, que es como las llama el pico-sdk, para que la siguiente
   * laguna se identifique de un vistazo en vez de volver a rastrear un PC perdido.
   */
  /* PARAMETRIZADA POR NUCLEO. Estaba atada a `this.cpu`, asi que la trampa de la bootrom
   * solo funcionaba para el nucleo 0. El nucleo 1 pasa por el MISMO camino al arrancar
   * —core1_wrapper -> runtime_init -> rom_func_lookup— y sin interceptarla saltaba a
   * 0x100, que en el emulador no es codigo: se perdia en la primera decena de pasos. */
  private romTableLookup(cpu: Thumb2 = this.cpu): void {
    const code = cpu.getReg(0) & 0xffff;
    const c1 = String.fromCharCode(code & 0xff), c2 = String.fromCharCode(code >>> 8);
    if (!(code in ROM_IGNORABLES)) {
      console.warn(
        `[Uvm2System] rom_table_lookup('${c1}','${c2}') (0x${code.toString(16)}) no esta ` +
        `modelada; se devuelve una funcion que no hace nada. Si el juego se comporta ` +
        `raro a partir de aqui, esta es la razon.`);
    }
    cpu.setReg(0, ROM_NOOP | 1);
    cpu.setReg(15, cpu.getReg(14) & ~1);
  }

  /** Anillo de los ultimos PCs ejecutados; se vuelca si la CPU falla. */
  private readonly pcHist = new Uint32Array(PC_HIST);
  private pcHistN = 0;
  private readonly saltoDe = new Uint32Array(SALTO_HIST);
  private readonly saltoA  = new Uint32Array(SALTO_HIST);
  private saltoN = 0;
  private historialSaltos(): string[] {
    const n = Math.min(this.saltoN, SALTO_HIST);
    const out: string[] = [];
    for (let i = n; i > 0; i--) {
      const k = (this.saltoN - i) & (SALTO_HIST - 1);
      out.push(`0x${this.saltoDe[k].toString(16)}->0x${this.saltoA[k].toString(16)}`);
    }
    return out;
  }
  /**
   * Que vectores apuntan a esta direccion. Las imagenes de UVM2 llenan la tabla
   * con un manejador por defecto —un muro de bkpt, uno por vector— asi que caer
   * en el se lee en el log como "instruccion no implementada: 0xbe00" y parece
   * un fallo del emulador cuando es el juego rindiendose.
   */
  private vectoresQueApuntanA(pc: number): string[] {
    const NOMBRE: Record<number, string> = {
      2: 'NMI', 3: 'HardFault', 4: 'MemManage', 5: 'BusFault', 6: 'UsageFault',
      7: 'SecureFault', 11: 'SVCall', 12: 'DebugMon', 14: 'PendSV', 15: 'SysTick',
    };
    const out: string[] = [];
    for (let i = 2; i < 64; i++) {
      if (((this.read32(this.vtor + i * 4) & ~1) >>> 0) === (pc >>> 0)) {
        out.push(NOMBRE[i] ?? (i >= 16 ? `IRQ ${i - 16}` : `vector ${i}`));
      }
    }
    return out;
  }

  private historialPC(): number[] {
    const n = Math.min(this.pcHistN, PC_HIST);
    const out: number[] = [];
    for (let i = n; i > 0; i--) out.push(this.pcHist[(this.pcHistN - i) & (PC_HIST - 1)]);
    return out;
  }
  private frameCounter = 0;
  private halted = false;

  /** Bus cycles the last frame actually consumed — the SDK's own budget. */
  public lastFrameBusCycles = 0;

  private audioCtx: AudioContext | null = null;
  private audioNode: ScriptProcessorNode | null = null;

  constructor(canvasElement?: HTMLCanvasElement) {
    this.via = new Via6522(
      (ora, orb, acr, pcr, cb2h, cb2s) => this.beam.update(ora, orb, acr, pcr, cb2h, cb2s),
      (orb, ora) => this.psg.write(orb, ora),
    );
    this.canvas = new Canvas(canvasElement);
  }

  // ─── Loading ──────────────────────────────────────────────────────────────

  /**
   * Load a `.um2` file: a 20-byte header followed by a flat RAM image whose
   * first two words are the initial SP and the entry point. The length field
   * is a WORD count, not a byte count.
   */
  /** ARRANCADO: si esta traza sale, el emulador del UVM2 tiene la imagen y ha empezado. */
  /** Los simbolos de la imagen, para poder atrapar por nombre. Opcional: sin ELF todo
   *  sigue funcionando, solo que la SD no se atiende y el juego lo dira a su manera. */
  setElf(elf: Uint8Array): void {
    const sim = extractElf32Symbols(elf);
    this.sdLeerAddr  = (sim.get('uvm2_sd_leer')  ?? 0) & ~1;
    this.sdLeerDesdeAddr = (sim.get('uvm2_sd_leer_desde') ?? 0) & ~1;
    this.sdErrorAddr = (sim.get('uvm2_sd_error') ?? 0) >>> 0;
    /* EL PRINCIPIO DEL FRAME ES DONDE SE MIRAN LAS CUENTAS DEL ANTERIOR. Los contadores
     * vivos los pone a cero `uvm2_frame_begin`, asi que leerlos en cualquier otro momento
     * los pilla a medio llenar — un juego que emula 40 ms y dibuja 2 esta casi siempre en
     * la ventana "reciennacido". Justo al ENTRAR ahi todavia valen los del frame que
     * acaba de terminar. */
    this.frameBeginAddr = (sim.get('uvm2_frame_begin') ?? 0) & ~1;
    this.statsAddr      = (sim.get('uvm2_stats') ?? 0) >>> 0;
    /* La BIOS del cartucho propio: su SD se atrapa en sd_hw_init / sd_hw_read_block
     * (sd.rs, la costura) y se sirve de una imagen FAT (setSdImagen). */
    this.sdHwInitAddr      = (sim.get('sd_hw_init') ?? 0) & ~1;
    /* LA LISTA, Y SOLO LA LISTA: mientras un nucleo esta dentro de uvm2_exec (el que
     * reproduce la lista de comandos por el stream) las escrituras a la VIA se marcan
     * 'lista'. Lo demas (mandos, recalibraciones a mano) tambien pasa por el stream en la
     * BIOS, asi que el origen PIO/SIO no separaba el dibujo. */
    this.execAddr = (sim.get('uvm2_exec') ?? 0) & ~1;
    this.sdHwReadBlockAddr = (sim.get('sd_hw_read_block') ?? 0) & ~1;
    this.sdHwWriteBlockAddr = (sim.get('sd_hw_write_block') ?? 0) & ~1;
    console.log(`[Uvm2System] simbolos: uvm2_sd_leer=0x${this.sdLeerAddr.toString(16)} ` +
                `uvm2_sd_error=0x${this.sdErrorAddr.toString(16)}`);
  }

  /** Los ficheros de la SD simulada, por ruta relativa en minusculas. */
  setSdFiles(files: Record<string, Uint8Array>): void {
    this.sdArchivos = files;
    console.log(`[Uvm2System] SD simulada: ${Object.keys(files).length} ficheros`);
  }

  /** `uvm2_sd_leer(ruta, dst, max)`: copiar el fichero y devolver los bytes. */
  private atiendeSdLeer(cpu: Thumb2): void {
    let ruta = '';
    for (let a = cpu.getReg(0) >>> 0, i = 0; i < 128; i++) {
      const c = this.read8(a + i);
      if (!c) break;
      ruta += String.fromCharCode(c);
    }
    const dst = cpu.getReg(1) >>> 0, max = cpu.getReg(2) >>> 0;
    const f = this.sdArchivos[ruta.toLowerCase()];
    let n = 0;
    if (f) {
      n = Math.min(f.length, max);
      for (let i = 0; i < n; i++) this.write8((dst + i) >>> 0, f[i]);
    } else {
      console.warn(`[Uvm2System] la SD simulada no tiene "${ruta}". Ponlo en ` +
                   `~/VectrexStudio/sd/${ruta} y vuelve a compilar.`);
    }
    /* uvm2_sd_error: 0 = bien. Se escribe aqui porque el juego lo mira despues, y dejarlo
     * con lo que hubiera haria que una lectura buena pareciera fallida. */
    if (this.sdErrorAddr) {
      const e = f ? 0 : 1;
      for (let i = 0; i < 4; i++) this.write8(this.sdErrorAddr + i, (e >>> (i * 8)) & 0xFF);
    }
    cpu.setReg(0, n >>> 0);
    cpu.setReg(15, cpu.getReg(14) & ~1);
    console.log(`[Uvm2System] SD: "${ruta}" -> ${n} bytes`);
  }

  /** `uvm2_sd_leer_desde(ruta, dst, max, desde)`: un TROZO del fichero.
   *
   * Hacia falta porque el emulador atrapa la SD POR SIMBOLO, y una funcion nueva que el no
   * conozca se ejecuta de verdad: el codigo FAT contra un lector que aqui no existe, y el
   * juego ve un fallo que en la consola no ocurre. `vfcap` se quedaba en su error 1 por
   * esto, no por el fichero.
   *
   * Sin traza por llamada A PROPOSITO: esto se llama una vez por frame y a 50 Hz llenaria
   * la consola de lineas iguales. */
  private atiendeSdLeerDesde(cpu: Thumb2): void {
    let ruta = '';
    for (let a = cpu.getReg(0) >>> 0, i = 0; i < 128; i++) {
      const c = this.read8(a + i);
      if (!c) break;
      ruta += String.fromCharCode(c);
    }
    const dst   = cpu.getReg(1) >>> 0;
    const max   = cpu.getReg(2) >>> 0;
    const desde = cpu.getReg(3) >>> 0;
    const f = this.sdArchivos[ruta.toLowerCase()];
    let n = 0;
    if (f && desde < f.length) {
      n = Math.min(f.length - desde, max);
      for (let i = 0; i < n; i++) this.write8((dst + i) >>> 0, f[desde + i]);
    }
    if (this.sdErrorAddr) {
      const e = f ? 0 : 1;
      for (let i = 0; i < 4; i++) this.write8(this.sdErrorAddr + i, (e >>> (i * 8)) & 0xFF);
    }
    cpu.setReg(0, n >>> 0);
    cpu.setReg(15, cpu.getReg(14) & ~1);
  }

  /** Una imagen FAT (superfloppy o con MBR) que la BIOS lee por bloques: es la tarjeta. */
  setSdImagen(img: Uint8Array): void {
    this.sdImagen = img;
    console.log(`[Uvm2System] SD por bloques: ${img.length} bytes (${(img.length / 512) | 0} sectores)`);
  }
  /**
   * ARRANCAR LA BIOS DEL CARTUCHO DE VECTREX STUDIO (el ELF del firmware, no una .um2).
   * Arranca como el chip: MSP y reset desde la tabla de vectores en flash (0x10000000);
   * __pre_init copia el codigo a SRAM y de ahi en adelante todo corre en RAM. Llama antes
   * a setElf (mismo ELF: da los simbolos de la costura de la SD) y a setSdImagen.
   */
  initFirmware(elf: Uint8Array): void {
    console.log('[Uvm2System] ARRANCANDO la BIOS del cartucho propio, ELF de', elf.length, 'bytes');
    this.placa = PLACA_PROPIA;
    /* La BIOS EXPORTA uvm2_sd_leer_desde (su costura Rust sobre sd.rs, mismo nombre que la
     * funcion C de la .um2), y setElf la habia registrado como trampa de la .um2: el
     * emulador la servia desde la carpeta SDDIR y config/uvm2.cfg salia "no existe". Aqui
     * la SD se sirve por bloques (sd_hw_*), asi que esas dos trampas no se aplican. */
    this.sdLeerAddr = 0;
    this.sdLeerDesdeAddr = 0;
    this.resets = 0;
    this.clocks.fill(0);
    this.bootram.fill(0);
    this.bootlocks = 0;
    this.flash = new Uint8Array(FLASH_SIZE).fill(0xFF);
    const segs = loadElf32ByPaddr(elf, this.flash, FLASH_BASE);
    console.log(`[Uvm2System] flash: ${segs} segmentos PT_LOAD del ELF`);
    this.sram.fill(0);
    this.psram.fill(0);
    this.cargaEnPsram = false;
    this.montarBootrom();
    this.reset();
    /* La tabla de vectores es la de la flash, no la de SRAM: el reset de arriba puso
     * MSP/PC leyendo la base de SRAM (a ceros); se pisan con los de la flash. */
    this.vtor = FLASH_BASE;
    this.cpu.setReg(13, this.read32(FLASH_BASE));
    this.cpu.setReg(15, this.read32(FLASH_BASE + 4) & ~1);
    console.log(`[Uvm2System] reset: msp=0x${this.read32(FLASH_BASE).toString(16)} pc=0x${(this.read32(FLASH_BASE + 4) & ~1).toString(16)}`);
  }
  init(um2: Uint8Array): void {
    console.log('[Uvm2System] ARRANCANDO con una imagen de', um2.length, 'bytes');
    this.placa = PLACA_UVM2;
    this.flash = null;
    this.resets = 0;
    this.clocks.fill(0);
    this.bootram.fill(0);
    this.bootlocks = 0;
    const rd32 = (o: number) =>
      (um2[o] | (um2[o + 1] << 8) | (um2[o + 2] << 16) | (um2[o + 3] << 24)) >>> 0;

    let payload = um2, loadAddr = SRAM_BASE;
    const magic = String.fromCharCode(um2[0], um2[1], um2[2], um2[3]);
    if (magic === '2CMU') {
      loadAddr = rd32(12);
      const words = rd32(16);
      payload = um2.subarray(20, 20 + words * 4);
    }

    this.sram.fill(0);
    this.psram.fill(0);
    if (psramOff(loadAddr) >= 0) this.psram.set(payload, psramOff(loadAddr));
    else                         this.sram.set(payload, (loadAddr - SRAM_BASE) >>> 0);
    this.cargaEnPsram = psramOff(loadAddr) >= 0;
    this.montarBootrom();
    this.reset();
  }

  reset(): void {
    this.frameCounter = 0;
    this.busCycle = 0;
    this.cpuCiclos = 0;
    this.relojCore0 = this.relojCore1 = this.relojBus = 0;
    this.framesDelJuego = 0;
    this.ciclosDeBus = 0;
    this.vectoresDeBus = 0;
    this.timerAlta = 0;
    this.cpuAcc = 0;
    this.cycleCount = 0;
    this.clkHigh = false;
    this.gpioOut = 0;
    this.gpioOe = 0;
    this.halted = false;
    this.vtor = SRAM_BASE;
    this.lastPollPc = -1;

    this.via.reset();
    this.beam.reset();
    this.psg.reset();
    // Port B bit 5 is the comparator input; joyButtons ORs bits 4-7 into an ORB
    // read and would hold it high. Buttons reach the image via the PSG instead.
    this.via.joyButtons = 0x00;
    this.cpu.reset();
    if (this.cargaEnPsram) this.cpu.setFetchRegion(this.psram, PSRAM_BASE);
    else                   this.cpu.setFetchRegion(this.sram, SRAM_BASE);

    // The firmware loads MSP and the entry point from the image's own vector
    // table — word 0 and word 1 — exactly as a Cortex-M reset would.
    { const base = this.cargaEnPsram ? PSRAM_BASE : SRAM_BASE;
      this.cpu.setReg(13, this.read32(base));
      this.cpu.setReg(15, this.read32(base + 4) & ~1); }
    this.cpu.setReg(14, 0xFFFFFFFE);   // sentinel: game_main must never return
  }

  // ─── Bus clock ────────────────────────────────────────────────────────────

  /**
   * Advance the Vectrex bus by however many bus cycles `cpuCycles` covers.
   *
   * Everything that makes the beam move happens here: the VIA latches a write
   * on each falling edge, presents read data on each rising edge, and the
   * integrators are ticked once per bus cycle so a ramp of N cycles moves the
   * beam the distance N cycles of ramp actually would.
   */

  /* UN PASO DE CORE 1, con sus mismas trampas, devolviendo lo que ha costado.
   *
   * Estaba metido dentro del `try` de core 0 y se daba UNO por cada paso de core 0,
   * tirando su coste. Ahora lo llama el planificador de `runFrame` cuando el reloj de
   * core 1 va por detras, que es lo que pone a los dos nucleos a la misma tasa de
   * ciclos. El cuerpo no cambia. */
  private pasoCore1(): number {
    if (!this.cpu1) return 0;
    const pc1 = this.cpu1.getReg(15) >>> 0;
    if (((pc1 & 0xFFFFFFF0) >>> 0) === 0xFFFFFFF0) { this.cpu1 = null; return 0; }  // volvio: se acabo
    /* SU PROPIO RASTRO. Los primeros pasos del nucleo 1 son los que deciden si llega a su
     * bucle o se pierde, y sin guardarlos un PC absurdo no dice de donde vino. */
    if (this.rastro1.length < 64) this.rastro1.push(pc1);
    if (this.sdLeerAddr && pc1 === this.sdLeerAddr) { this.atiendeSdLeer(this.cpu1); return 1; }
    if (this.sdLeerDesdeAddr && pc1 === this.sdLeerDesdeAddr) { this.atiendeSdLeerDesde(this.cpu1); return 1; }
    if (this.execAddr && pc1 === this.execAddr) { this.execVuelta[1] = this.cpu1.getReg(14) & ~1; this.enLista++; }
    else if (this.execVuelta[1] && pc1 === this.execVuelta[1]) { this.execVuelta[1] = 0; this.enLista--; }
    if (this.sdHwInitAddr && pc1 === this.sdHwInitAddr) { this.atiendeSdHwInit(this.cpu1); return 1; }
    if (this.sdHwReadBlockAddr && pc1 === this.sdHwReadBlockAddr) { this.atiendeSdHwReadBlock(this.cpu1); return 1; }
    if (this.sdHwWriteBlockAddr && pc1 === this.sdHwWriteBlockAddr) { this.atiendeSdHwWriteBlock(this.cpu1); return 1; }
    /* En la BIOS, core 1 salta al JUEGO, que vive en PSRAM: que lo busque alli deprisa. */
    if (psramOff(pc1) >= 0 && this.cpu1FetchEnSram) {
      this.cpu1.setFetchRegion(this.psram, PSRAM_BASE); this.cpu1FetchEnSram = false;
      console.log(`[Uvm2System] NUCLEO 1 EN EL JUEGO: pc=0x${pc1.toString(16)} (PSRAM), frame ${this.frameCounter}`);
    }
    if (pc1 === ROM_LOOKUP) { this.romTableLookup(this.cpu1); return 1; }
    if (((pc1 & 0xFFFFFFF0) >>> 0) === ROM_NOOP) {
      this.cpu1.setReg(15, this.cpu1.getReg(14) & ~1);   // la funcion vacia: volver
      return 1;
    }
    if ((pc1 < SRAM_BASE || pc1 > 0x20090000) && psramOff(pc1) < 0) {
      if (!this.cpu1Perdido) {
        this.cpu1Perdido = true;
        console.error(`[Uvm2System] NUCLEO 1 PERDIDO en 0x${pc1.toString(16)}. ` +
          `Camino: ${this.rastro1.map(x => '0x' + x.toString(16)).join(' ')}`);
      }
      this.cpu1 = null;
      return 0;
    }
    return this.cpu1.step(this);
  }

  /* El bus, hasta el instante que LOS DOS nucleos han alcanzado ya. */
  private sincronizaBus(): void {
    const ahora = this.cpu1 ? Math.min(this.relojCore0, this.relojCore1) : this.relojCore0;
    const d = ahora - this.relojBus;
    if (d > 0) { this.relojBus = ahora; this.advanceBus(d); }
  }

  private advanceBus(cpuCycles: number): void {
    this.cycleCount = (this.cycleCount + cpuCycles) >>> 0;
    /* APARTE DE cycleCount, que se trunca a 32 bits. El TIMER cuenta microsegundos y a
     * 150 MHz los 32 bits de ciclos se dan la vuelta cada 28 s: bastante menos que una
     * partida, y un reloj que retrocede da restas negativas enormes. */
    this.cpuCiclos += cpuCycles;
    this.cpuAcc += cpuCycles;

    while (this.cpuAcc >= CPU_PER_BUS / 2) {
      this.cpuAcc -= CPU_PER_BUS / 2;
      this.halfStep();
    }
  }

  /** One clock phase: the edge, and — on the falling one — a bus cycle of beam. */
  private halfStep(): void {
    if (this.clkHigh) {
      this.clkHigh = false;
      this.onFallingEdge();
      this.busCycle++;
      // Integrate one bus cycle's worth of beam movement.
      this.via.tick();
      this.beam.tick(
        this.via.via_acr, this.via.via_pcr, this.via.via_ca2,
        this.via.via_cb2h, this.via.via_cb2s, this.via.via_t1pb7,
        this.via.via_orb,
      );
    } else {
      this.clkHigh = true;
      this.onRisingEdge();
    }
  }

  /**
   * Collapse a clock-edge spin.
   *
   * At 100 CPU cycles per bus cycle an honest emulation spends ~99% of its
   * instructions inside `while ((GPIO_IN & CLK) ...)`: a frame that draws a
   * single dot still costs 2.3M steps, and the simulator falls behind 50 Hz —
   * which shows up as music playing slow, because the sequencer is ticked once
   * per frame.
   *
   * Waiting is not work. When the SAME instruction reads the clock byte twice
   * in a row, it is a spin by definition, so the phase is advanced immediately
   * instead of after another 50 emulated cycles. Bus cycles are still counted
   * one for one, so every SDK delay keeps its exact duration; only the idle
   * polling gets cheaper. Real game logic never hits this path and keeps its
   * honest 100:1 ratio against the bus.
   */
  private maybeCollapseSpin(): void {
    const pc = this.cpu.getReg(15) >>> 0;
    if (pc === this.lastPollPc) {
      this.lastPollPc = -1;      // one collapse per pair of polls
      this.halfStep();
      // The collapse REPLACES the cycles the spin would have burned; leaving
      // them in the accumulator counts the same phase twice, which stretches
      // every ramp and blows up the geometry.
      this.cpuAcc = 0;
    } else {
      this.lastPollPc = pc;
    }
  }

  /** ¿Ha terminado el pico-sdk su secuencia de arranque del nucleo 1? Entonces se arranca.
   *
   * La secuencia es {0, 0, 1, vector_table, sp, entry} (multicore.c:189), empujada palabra a
   * palabra y con cada una devuelta por eco — que es lo que este emulador ya hacia. Aqui solo
   * se mira la ventana de las ultimas seis: si empieza por 0,0,1 y acaba en una direccion de
   * SRAM, las dos ultimas son la pila y el punto de entrada.
   *
   * Se comprueba la FORMA, no un contador de posicion: si el saludo se reinicia a mitad
   * —el propio sdk lo hace cuando una respuesta no coincide— un contador se quedaria
   * desfasado y la ventana no. */
  private quizaLanzarCore1(palabra: number): void {
    this.lanzamiento.push(palabra);
    if (this.lanzamiento.length > 6) this.lanzamiento.shift();
    if (this.cpu1 || this.lanzamiento.length < 6) return;
    const [a, b, c, , sp, entry] = this.lanzamiento;
    if (a !== 0 || b !== 0 || c !== 1) return;
    if ((entry >>> 0) < SRAM_BASE || (sp >>> 0) < SRAM_BASE) return;

    this.cpu1 = new Thumb2();
    /* EN HORA. Su reloj arranca donde va el de core 0: dejarlo en 0 congela el minimo
     * —y con el, el bus— hasta que core 1 recupere los millones de ciclos del arranque. */
    this.relojCore1 = this.relojCore0;
    this.cpu1.reset();
    this.cpu1.setFetchRegion(this.sram, SRAM_BASE);
    this.cpu1FetchEnSram = true;
    this.cpu1.setReg(13, sp >>> 0);
    this.cpu1.setReg(15, (entry >>> 0) & ~1);
    this.cpu1.setReg(14, 0xFFFFFFFE);
    /* core1_trampoline es `pop {r0, r1, pc}`: las tres palabras de la cima de la pila son
     * la funcion de entrada, la base de la pila y core1_wrapper. Se imprimen porque si
     * alguna es basura, el nucleo salta a ninguna parte y el sintoma —un PC absurdo— no
     * dice de donde vino. */
    const w = [this.read32(sp >>> 0), this.read32((sp >>> 0) + 4), this.read32((sp >>> 0) + 8)];
    console.log(`[Uvm2System] NUCLEO 1 ARRANCADO: pc=0x${(entry >>> 0).toString(16)} ` +
                `sp=0x${(sp >>> 0).toString(16)}  pila=[${w.map(x => '0x' + (x >>> 0).toString(16)).join(', ')}]`);
  }

  /** La transferencia del canal 0: n palabras del lote al TX FIFO, de golpe. */
  private dmaTransferencia(): void {
    const src = this.dmaRegs[DMA_READ_ADDR >>> 2] >>> 0;
    const n   = this.dmaRegs[DMA_TRANS_COUNT >>> 2] & 0x0FFFFFFF;   // 31:28 = MODE
    for (let i = 0; i < n && i < 65536; i++) {
      this.dmaPalabras++;
      this.pioPalabra(this.read32((src + i * 4) >>> 0) >>> 0);
    }
    this.dmaRegs[DMA_TRANS_COUNT >>> 2] = 0;
  }

  /** Una palabra del stream: se presenta en los pines y se corre su periodo de E.
   *
   * LAS DOS PRIMERAS SE TIRAN. El preambulo del .pio hace dos `pull block`: la primera
   * palabra son 27 unos para `out pindirs` y la segunda el patron de PARK que va a X. Las
   * dos tienen el bit 0 a uno, asi que sin saltarlas se leerian como escrituras y
   * mandarian basura a la VIA en el primer frame. */
  private pioPalabra(w: number): void {
    const PINES = (((1 << this.placa.outCount) - 1) << this.placa.outBase) >>> 0;
    if (this.pioVistas < 6) {
      console.log(`[Uvm2System] palabra ${this.pioVistas} = 0x${(w >>> 0).toString(16)} ` +
                  `(bit0=${w & 1} bit1=${(w >>> 1) & 1})`);
      this.pioVistas++;
    }
    if (this.pioPreambulo > 0) {
      /* La SEGUNDA palabra del preambulo es el patron de PARK: el .pio la mete en X y la
       * saca a los pines en cada periodo aparcado. Guardarla es lo que hace que aparcar
       * signifique algo. */
      this.pioPreambulo--;
      return;
    }
    this.pioPalabras++;
    /* La palabra CRUDA junto al registro y dato que produce. Si el flujo lleva vy y aqui
     * sale 0, el fallo esta en la decodificacion, no en el juego. */
    if (this.trazaPio.length < 24 && this.busCycle > 200000 && (w & 1)) {
      const g = (((w >>> 1) & ((1 << this.placa.outCount) - 1)) << this.placa.outBase) >>> 0;
      const dir = this.direccionDe(g);
      this.trazaPio.push(`w=0x${(w >>> 0).toString(16)} dir=0x${dir.toString(16)} reg=${dir & 0xF} dato=0x${this.datoDe(g).toString(16)}`);
    }
    if (w & 1) this.pioEsc++; else if (w & 2) this.pioPark_n++; else this.pioSil++;

    if (w & 1) {
      this.gpioOut = ((this.gpioOut & ~PINES) | ((((w >>> 1) & ((1 << this.placa.outCount) - 1)) << this.placa.outBase) & PINES)) >>> 0;
      this.enStream = true;
      this.correPeriodoE();
      this.enStream = false;
      /* Y SE APARCA EN CUANTO SE ENGANCHA. En el hardware la SM del PIO ocupa cada periodo
       * de E; aqui el reloj avanza TAMBIEN con la CPU, asi que unos pines que se quedan
       * puestos los vuelve a enganchar la VIA en el siguiente flanco. Medido en la traza:
       * cada escritura aparecia DOS O TRES veces seguidas —"ORB=0x81 ORB=0x81",
       * "DDRB=0x9f" tres veces— y una repeticion es inocua para un puerto pero NO para
       * T1CH, que reinicia la rampa. */
      this.gpioOut = ((this.gpioOut & ~PINES) | this.placa.park) >>> 0;
    } else if (w & 2) {
      /* APARCAR ES PRESENTAR EL PATRON DE PARK, no dejar los pines como estaban.
       *
       * El `parkeo` del .pio hace `mov osr, x` + `out pins` en CADA vuelta. Dejandolos
       * quietos, la ultima direccion sigue seleccionada y la VIA la RE-ENGANCHA en cada
       * flanco — que es justo contra lo que avisa el comentario del .pio: idempotente para
       * un registro de puerto, NO para T1CH, que reinicia la rampa.
       *
       * Medido: 1.235.936 escrituras a T1LL en 60 frames, y el haz solo se movia en X
       * (todos los segmentos con la misma Y). El patron de PARK lleva A15 sin A14, que no
       * decodifica a la VIA: aparcar es no escribir. */
      this.gpioOut = ((this.gpioOut & ~PINES) | this.placa.park) >>> 0;
      const n = ((w >>> 2) & 0xFFFFFF) + 1;      // la cuenta va como N-1, ver el .pio
      for (let i = 0; i < n && i < 4096; i++) this.correPeriodoE();
    } else {
      this.correPeriodoE();                       // silencio: los pines se quedan como esten
    }
  }

  /** Un periodo de E completo, que es donde la VIA engancha (en el flanco de bajada). */
  private correPeriodoE(): void {
    if (!this.clkHigh) this.halfStep();   // subir
    this.halfStep();                      // bajar: aqui se latchea
  }

  /** Address currently on the bus, assembled from the GPIO pins. */
  private direccionDe(g: number): number {
    const p = this.placa;
    return (((g & p.addrMask) >>> p.addrShift)
         | ((p.a14Mask && (g & p.a14Mask)) ? 0x4000 : 0)
         | ((p.a15Mask && (g & p.a15Mask)) ? 0x8000 : 0)) >>> 0;
  }
  private datoDe(g: number): number { return ((g & this.placa.dataMask) >>> this.placa.dataShift) & 0xFF; }
  /** El 6809 esta parado y el bus es nuestro: /HALT asertado, con la polaridad de la placa. */
  private busNuestro(): boolean {
    const h = (this.gpioOut & this.placa.haltMask) !== 0;
    return this.placa.haltAssertHigh ? h : !h;
  }
  private busAddress(): number { return this.direccionDe(this.gpioOut); }

  private addressesVia(): boolean {
    return (this.busAddress() & 0xF000) === 0xD000;
  }

  /** The VIA latches a write here — the same edge the hardware uses. */
  private onFallingEdge(): void {
    if (!this.busNuestro()) return;            // 6809 still owns the bus
    if (this.gpioOut & this.placa.rwMask) return;   // read cycle
    if (!this.addressesVia())     return;      // parked, or not the VIA

    this.escriturasVia++;
    /* Histograma de registros, solo diagnostico: "no dibuja" no distingue "no llegan
     * escrituras" de "llegan pero a los registros equivocados". */
    this.viaHist[this.busAddress() & 0xF]++;
    if ((this.busAddress() & 0xF) === 0) this.orbHist[this.datoDe(this.gpioOut)]++;   // ORB
    if ((this.busAddress() & 0xF) === 1) this.oraHist[this.datoDe(this.gpioOut)]++;   // ORA
    /* LA SECUENCIA TAL CUAL LLEGA. Los histogramas dicen CUANTAS y de QUE, nunca EN QUE
     * ORDEN — y el enganche del S&H de Y depende de que ORA lleve la velocidad cuando se
     * escribe ORB. Eso solo se ve en la traza. */
    if (this.traza.length < 40 && this.busCycle > 200000)
      this.traza.push(`${['ORB','ORA','DDRB','DDRA','T1CL','T1CH','T1LL','T1LH','T2CL','T2CH','SR','ACR','PCR','IFR','IER','ORAnh'][this.busAddress() & 0xF]}=0x${this.datoDe(this.gpioOut).toString(16)}`);
    /* CON SU ORIGEN: 1 = palabra del stream PIO (la LISTA de comandos), 0 = escritura por SIO
     * (lectura de mandos, recalibraciones a mano). Separa el dibujo de lo demas en las dos
     * placas con el mismo criterio, que es lo que hace comparable un frame con otro. */
    if ((globalThis as any).__VIADUMP) this.viaFull.push(this.busCycle, this.busAddress() & 0xF, this.datoDe(this.gpioOut), this.enLista > 0 ? 1 : 0);
    this.via.write(this.busAddress() & 0xF, this.datoDe(this.gpioOut),
                   (xsh) => { this.beam.alg_xsh = xsh; });
    /* ¿Se mueve el sample-and-hold de Y? Si ORB=0 llega y esto no cambia, el enganche no
     * ocurre; si cambia y el haz no se mueve, el problema esta en el integrador. Son dos
     * sitios opuestos y sin este dato no se distinguen. */
    if (this.beam.alg_ysh !== this.ultimoYsh) { this.ultimoYsh = this.beam.alg_ysh; this.cambiosYsh++; }
    /* SOLO LOS ENGANCHES, no el valor retenido. Contar en cada escritura medía cuanto
     * tiempo pasa la Y en cada valor, que esta dominado por el reposo — y me hizo leer
     * "siempre 0x80" cuando la pregunta era otra. */
    if ((this.busAddress() & 0xF) === 0 && (this.gpioOut & 0x07) === 0x00)
      this.yshHist[this.via.via_ora & 0xFF]++;
  }

  /**
   * A read cycle presents its data while the clock is high. Latching it once
   * per rising edge (rather than on every GPIO_IN poll) matters: VIA reads have
   * side effects, and the image polls that register in a tight loop.
   */
  private onRisingEdge(): void {
    if (!this.busNuestro()) return;
    if (!(this.gpioOut & this.placa.rwMask)) return;
    if (this.gpioOe & this.placa.dataMask) return;   // we are still driving the bus
    if (!this.addressesVia())     return;

    this.dataIn = this.via.read(
      this.busAddress() & 0xF, this.beam.alg_compare,
      this.psg.Regs, this.psg.selectedRegister,
    ) & 0xFF;
  }

  /** GPIO_IN as the image sees it: driven pins read back, plus the real inputs. */
  private gpioIn(): number {
    let v = (this.gpioOut & this.gpioOe) | this.placa.pullupIn;
    if (this.clkHigh) v |= CLK_MASK;
    /* LECTURA CON LA DIRECCION PUESTA DESPUES DEL FLANCO. La BIOS del cartucho propio lee
     * asi (vinterface::bus_read): espera la subida de E, ENTONCES pone A15 (SELECT), deja
     * pasar el acceso y muestrea GPIO_IN con E aun alto. En el flanco de subida la
     * direccion todavia no era la VIA, asi que onRisingEdge no presento nada y la lectura
     * devolvia el dato viejo (0xFF): botones nunca pulsados. Aqui se presenta el dato en el
     * momento de muestrear, una vez por periodo de E, que es lo que hace el chip. */
    if (this.clkHigh && this.busNuestro() && (this.gpioOut & this.placa.rwMask) &&
        !(this.gpioOe & this.placa.dataMask) && this.addressesVia() && this.leidoEnCiclo !== this.busCycle) {
      this.leidoEnCiclo = this.busCycle;
      this.dataIn = this.via.read(this.busAddress() & 0xF, this.beam.alg_compare,
                                  this.psg.Regs, this.psg.selectedRegister) & 0xFF;
      const r = this.busAddress() & 0xF;
      if (r === 13) this.lecturasIfr++;
      else if (this.trazaLecturas.length < 24) this.trazaLecturas.push(`f${this.frameCounter} ${r}:${this.dataIn.toString(16)}`);
    }
    if (!(this.gpioOe & this.placa.dataMask)) {
      v = (v & ~this.placa.dataMask) | ((this.dataIn << this.placa.dataShift) & this.placa.dataMask);
    }
    return v >>> 0;
  }

  // ─── IBus ─────────────────────────────────────────────────────────────────

  private read32(addr: number): number {
    return (this.read8(addr) | (this.read8(addr + 1) << 8)
         | (this.read8(addr + 2) << 16) | (this.read8(addr + 3) << 24)) >>> 0;
  }

  read8(addr: number): number {
    addr = addr >>> 0;

    if (addr >= SRAM_BASE && addr < SRAM_BASE + SRAM_SIZE) {
      return this.sram[addr - SRAM_BASE];
    }
    { const po = psramOff(addr); if (po >= 0) return this.psram[po]; }

    if (addr < BOOTROM_SIZE) return this.bootrom[addr];
    if (this.flash && addr >= FLASH_BASE && addr < FLASH_BASE + FLASH_SIZE) return this.flash[addr - FLASH_BASE];
    if (addr >= QMI_BASE && addr < QMI_BASE + 0x10) return (this.qmiLeer(addr & 0xC) >>> ((addr & 3) * 8)) & 0xFF;

    // SCB->VTOR, TAMBIÉN EN LECTURA.
    //
    // Sólo estaba la escritura, y el pico-sdk lo LEE para localizar la tabla de
    // vectores: irq_set_exclusive_handler() comprueba que la ranura siga con el
    // manejador por defecto antes de instalar el suyo. Devolviendo 0, buscaba la
    // tabla en la dirección 0, leía ceros y disparaba `hard_assert` -> panic ->
    // bkpt, a un mundo de distancia de la causa.
    if (addr >= 0xE000ED08 && addr <= 0xE000ED0B)
      return (this.vtor >>> ((addr & 3) * 8)) & 0xFF;

    {
      const sh = (addr & 3) * 8;
      // RESETS: un periférico está "hecho" justo cuando no está en reset.
      if (addr >= RESETS_BASE && addr < RESETS_BASE + 0x10) {
        const off = addr & 0xC;
        const w = off === 0x0 ? this.resets : off === 0x8 ? (~this.resets >>> 0) : 0;
        return (w >>> sh) & 0xFF;
      }
      // XOSC: el cristal se declara estable desde el primer instante.
      if (addr >= XOSC_BASE && addr < XOSC_BASE + 0x20)
        return ((((addr & 0x1C) === 0x4 ? 0x80000000 : 0) >>> sh) & 0xFF);
      // PLL: enganchado desde el primer instante.
      for (const p of PLL_BASES)
        if (addr >= p && addr < p + 0x20)
          return ((((addr & 0x1C) === 0x0 ? 0x80000000 : 0) >>> sh) & 0xFF);
      /* TIMER0. SIN ESTO `time_us_32()` DEVUELVE SIEMPRE LO MISMO, y todo lo que el juego
       * mide en microsegundos —us_exec, us_input, us_wait y el periodo del frame— sale
       * CERO dentro del emulador. Un contador a cero se lee igual que "no hace falta".
       *
       * La base de tiempo es la del propio emulador: sus ciclos de CPU a 150 MHz. Fiel a
       * lo que el emulador cree que cuesta cada instruccion, que no es lo mismo que lo que
       * cuesta en silicio; sirve para comparar escenas entre si, no para dar un fps
       * absoluto de consola. */
      if (addr >= TIMER0_BASE && addr < TIMER0_BASE + 0x30) {
        const off = addr & 0xFC;
        const us  = Math.floor(this.cpuCiclos / CPU_POR_US);
        const alta = Math.floor(us / 4294967296);
        let w = 0;
        // Leer TIMELR ENGANCHA la parte alta; las RAW no enganchan nada.
        if      (off === 0x0C) { this.timerAlta = alta; w = us >>> 0; }
        else if (off === 0x08) { w = this.timerAlta; }
        else if (off === 0x28) { w = us >>> 0; }
        else if (off === 0x24) { w = alta; }
        return (w >>> sh) & 0xFF;
      }
      if (addr >= CLOCKS_BASE && addr < CLOCKS_BASE + 0x100)
        return ((this.leerClocks(addr & 0xFC) >>> sh) & 0xFF);
      if (addr >= BOOTRAM_BASE && addr < BOOTRAM_BASE + BOOTRAM_SIZE_) {
        const off = addr - BOOTRAM_BASE;
        if (off >= BOOTLOCK_OFF && off < BOOTLOCK_OFF + BOOTLOCK_N * 4) {
          const n = (off - BOOTLOCK_OFF) >> 2;
          // El intento se resuelve al leer el primer byte; los otros tres sirven
          // el mismo resultado, o una carga de 32 bits adquiriria cuatro veces.
          if ((addr & 3) === 0) {
            this.ultimoCerrojo = (this.bootlocks >>> n) & 1
              ? 0 : ((this.bootlocks |= 1 << n), (1 << n) >>> 0);
          }
          return (this.ultimoCerrojo >>> sh) & 0xFF;
        }
        return this.bootram[off];
      }
    }

    /* DMA: se lee lo ultimo escrito, y CTRL_TRIG SIN el bit BUSY — la transferencia ya
     * ocurrio en el disparo, asi que nunca esta ocupado. */
    if (((addr & 0xFFFFF000) >>> 0) === DMA_BASE) {
      const off = addr & 0xFFC, shift = (addr & 3) * 8;
      const word = this.dmaRegs[off >>> 2] ?? 0;
      return (word >>> shift) & 0xFF;
    }

    /* PIO0.FSTAT: el TX FIFO SIEMPRE esta vacio porque cada palabra se consume en el acto,
     * en la propia escritura. `drain` gira hasta ver TXEMPTY, asi que sin esto no sale. */
    if (((addr & 0xFFFFF000) >>> 0) === PIO0_BASE) {
      const off = addr & 0xFFC, shift = (addr & 3) * 8;
      const word = off === (PIO0_FSTAT & 0xFFF) ? (PIO_TXEMPTY_SM0 | 0x0F) : 0;
      return (word >>> shift) & 0xFF;
    }

    // PSM: solo FRCE_OFF, y solo para que multicore_reset_core1() pueda leer de vuelta
    // el bit que acaba de escribir. Ver la nota de PSM_BASE.
    if (((addr & PSM_MASK) >>> 0) === PSM_BASE) {
      const off = addr & 0xFFC, shift = (addr & 3) * 8;
      const word = off === PSM_FRCE_OFF ? this.psmFrceOff : 0;
      return (word >>> shift) & 0xFF;
    }

    // SIO. Only GPIO_IN and GPIO_OUT are readable; the SET/CLR/XOR aliases are
    // write-only on real silicon too.
    // The `>>> 0` is load-bearing: JS bitwise ops yield a SIGNED 32-bit result,
    // so `addr & 0xFFFFF000` compares as negative and never matches 0xD0000000.
    if (((addr & 0xFFFFF000) >>> 0) === SIO_BASE) {
      const off = addr & 0xFFC, shift = (addr & 3) * 8;
      let word = 0;
      if (off === 0x004) {
        // The image reads GPIO_IN with a 32-bit load and treats CLK (bit 31)
        // and the data bus (bits 0-7) as one consistent sample. Since the bus
        // decomposes that into four byte reads, snapshot the whole word on the
        // first byte and serve the rest from it — otherwise a phase advance
        // between bytes hands the caller a fresh clock alongside stale data,
        // which is exactly how the joystick reads went wrong.
        if ((addr & 3) === 0) {
          this.maybeCollapseSpin();
          this.gpioInLatch = this.gpioIn();
        }
        word = this.gpioInLatch;
      }
      else if (off === 0x010) word = this.gpioOut;
      else if (off === 0x030) word = this.gpioOe;
      /* SPINLOCK0..31 (0x100..0x17C): leer es reclamar y devuelve el bit del cerrojo si se
       * consigue. Aqui siempre se consigue: no hay contienda que modelar entre nucleos a
       * este nivel, y sin esto la critical_section de rp235x-hal (BIOS) gira para siempre
       * en cpsid/cpsie esperando un cerrojo que se lee a cero. */
      else if (off >= 0x100 && off < 0x180) word = (1 << ((off - 0x100) >> 2)) >>> 0;
      // FIFO_ST at +0x50. THERE IS NO SECOND CORE HERE, and without an answer the image
      // never gets past multicore_launch_core1_raw: pico-sdk pushes the entry point to
      // core 1 and spins on RDY, which stayed 0 for ever. Measured: a dual-core .um2 sat
      // in a three-instruction loop at multicore.h:186 and drew nothing, with no error —
      // "the emulator does nothing". Answering RDY|VLD lets core 0 carry on.
      //
      // HISTORY, AND WHY THIS COMMENT IS WORTH READING TO THE END: back then whatever the
      // game delegated to core 1 did not happen, and the advice was to build with
      // UVM2_DUAL_CORE=0. THAT IS NO LONGER TRUE — `arrancaCore1` builds a real second
      // Thumb2 and `cpu1.step(this)` runs it interleaved with core 0. The handshake below
      // is only what gets the launch through; the delegated work does run. A stale warning
      // here once cost a whole round of wrong conclusions about a dual-core image.
      //
      // Answering RDY alone only moves the hang twenty instructions on: the launch is a
      // six-word HANDSHAKE and core 0 pops each word back and compares. So FIFO_RD echoes
      // whatever was last written to FIFO_WR, the comparison passes, and the launch
      // returns instead of restarting for ever.
      else if (off === 0x050) {
        if (!this.avisoMulticore) {
          this.avisoMulticore = true;
          console.log('[Uvm2System] dual-core image: answering the launch handshake; core 1 ' +
                      'runs for real (see arrancaCore1 / cpu1.step).');
        }
        // VLD SOLO SI HAY DATO PENDIENTE, y esto NO es un detalle.
        //
        // Estaba fijo en RDY|VLD, o sea "siempre hay algo que leer". `multicore_fifo_drain`
        // vacia la FIFO leyendo MIENTRAS VLD siga puesto:
        //
        //     ldr r2,[r3,#0x58]   ; FIFO_RD
        //     ldr r2,[r3,#0x50]   ; FIFO_ST
        //     lsls r2, r2, #31    ; probar VLD
        //     bmi  <atras>        ; repetir mientras haya dato
        //
        // Con VLD clavado ese bucle no termina JAMAS. Aparecio el 2026-08-24 al anadir
        // `multicore_reset_core1()` a la imagen —que llama a drain antes del saludo— y el
        // sintoma fue el de siempre: la imagen corre, no dibuja, y no hay error. El perfil
        // de PCs lo canto: 99,7% del tiempo en 0x200329a2, multicore.h:260.
        //
        // Modelarlo bien es una linea: el dato lo pone FIFO_WR y lo quita FIFO_RD.
        word = 0x2 | (this.fifoPendiente ? 0x1 : 0);   // RDY siempre, VLD si hay dato
      }
      else if (off === 0x058) {
        word = this.fifoEco;                          // FIFO_RD: eco, ver arriba
        // Se consume en el ULTIMO byte: la lectura de 32 bits se descompone en cuatro, y
        // limpiar en el primero le daria a los otros tres una FIFO ya vacia.
        if ((addr & 3) === 3) this.fifoPendiente = false;
      }
      return (word >>> shift) & 0xFF;
    }

    // DWT cycle counter — the status LED bit-bangs WS2812 timing off it.
    if (addr >= 0xE0001004 && addr <= 0xE0001007) {
      return (this.cycleCount >>> ((addr & 3) * 8)) & 0xFF;
    }

    return 0;
  }

  write8(addr: number, data: number): void {
    addr = addr >>> 0;
    data &= 0xFF;

    if (addr >= SRAM_BASE && addr < SRAM_BASE + SRAM_SIZE) {
      this.sram[addr - SRAM_BASE] = data;
      return;
    }
    { const po = psramOff(addr); if (po >= 0) { this.psram[po] = data; return; } }

    {
      const sh = (addr & 3) * 8, bits = data << sh, mask = 0xFF << sh;
      if (addr >= RESETS_BASE && addr < RESETS_BASE + ATOM_SIZE) {
        if ((addr & 0xC) === 0)
          this.resets = atomico(this.resets, (addr - RESETS_BASE) >>> 12, bits, mask);
        return;
      }
      if (addr >= CLOCKS_BASE && addr < CLOCKS_BASE + ATOM_SIZE) {
        const i = (addr & 0xFC) >> 2;
        this.clocks[i] = atomico(this.clocks[i], (addr - CLOCKS_BASE) >>> 12, bits, mask);
        return;
      }
      if (addr >= BOOTRAM_BASE && addr < BOOTRAM_BASE + BOOTRAM_SIZE_) {
        const off = addr - BOOTRAM_BASE;
        if (off >= BOOTLOCK_OFF && off < BOOTLOCK_OFF + BOOTLOCK_N * 4) {
          this.bootlocks &= ~(1 << ((off - BOOTLOCK_OFF) >> 2));   // soltar
        } else {
          this.bootram[off] = data;
        }
        return;
      }
      if (((addr & 0xFFFFF000) >>> 0) === DMA_BASE) {
        const off = addr & 0xFFC, shift = (addr & 3) * 8;
        const i = off >>> 2;
        this.dmaRegs[i] = (((this.dmaRegs[i] ?? 0) & ~(0xFF << shift)) | (data << shift)) >>> 0;
        // Solo el canal 0, que es el unico que usa el stream.
        if (off === DMA_CTRL_TRIG && (addr & 3) === 3 &&
            (this.dmaRegs[i] & DMA_EN) && off < DMA_CH_STRIDE) {
          this.dmaTransferencia();
        }
        return;
      }

      /* PIO0.TXF0: la palabra del stream. Se consume EN EL ACTO — un periodo de E por
       * escritura, que es lo que hace el programa del PIO. */
      if (((addr & 0xFFFFF000) >>> 0) === PIO0_BASE) {
        if ((addr & 0xFFC) === (PIO0_TXF0 & 0xFFF)) {
          const shift = (addr & 3) * 8;
          this.pioLatch = ((this.pioLatch & ~(0xFF << shift)) | (data << shift)) >>> 0;
          if ((addr & 3) === 3) { this.txfDirectas++; this.pioPalabra(this.pioLatch); }
        }
        return;
      }

      // PSM: FRCE_OFF con sus alias atomicos. Aqui no hay segundo nucleo que apagar; lo
      // unico que hace falta es que el registro RECUERDE, porque multicore_reset_core1()
      // gira leyendolo. Ver la nota de PSM_BASE.
      if (((addr & PSM_MASK) >>> 0) === PSM_BASE) {
        const off = addr & 0xFFC, shift = (addr & 3) * 8;
        if (off === PSM_FRCE_OFF) {
          const bits = (data << shift) >>> 0;
          const alias = (addr >>> 12) & 3;    // 0 normal, 1 XOR, 2 SET, 3 CLR
          const antes = this.psmFrceOff;
          if (alias === 1)      this.psmFrceOff = (this.psmFrceOff ^ bits) >>> 0;
          else if (alias === 2) this.psmFrceOff = (this.psmFrceOff | bits) >>> 0;
          else if (alias === 3) this.psmFrceOff = (this.psmFrceOff & ~bits) >>> 0;
          else this.psmFrceOff = ((this.psmFrceOff & ~(0xFF << shift)) | bits) >>> 0;

          /* SOLTAR EL RESET DEL NUCLEO 1 -> EL NUCLEO 1 CONTESTA. Lo dice el pico-sdk al
           * lado de la linea: "Bring core 1 back out of reset. It will drain its own
           * mailbox FIFO, then push a 0 to our mailbox to tell us it has done this", y
           * acto seguido hace un pop BLOQUEANTE esperando ese 0.
           *
           * Aqui no hay nucleo 1, asi que si nadie empuja ese 0 el reset no vuelve nunca.
           * Es el otro extremo del mismo saludo: con VLD clavado a 1 se colgaba el DRENAJE
           * (que lee mientras haya dato) y con VLD honesto se colgaba esta ESPERA. Las dos
           * se resuelven modelando quien pone y quien quita el dato, no forzando el bit. */
          if ((antes & PSM_PROC1) && !(this.psmFrceOff & PSM_PROC1)) {
            this.fifoEco = 0;
            this.fifoPendiente = true;
          }
        }
        return;
      }
      // XOSC y PLL sólo se leen; lo que se les escribe no cambia nada aquí.
      if (addr >= XOSC_BASE && addr < XOSC_BASE + ATOM_SIZE) return;
      for (const p of PLL_BASES) if (addr >= p && addr < p + ATOM_SIZE) return;
    }

    if (addr >= QMI_BASE && addr < QMI_BASE + 0x10) { this.qmiEscribir(addr & 0xC, addr & 3, data); return; }
    if (((addr & 0xFFFFF000) >>> 0) === SIO_BASE) {
      const off = addr & 0xFFC, shift = (addr & 3) * 8;
      const bits = data << shift;
      this.lastPollPc = -1;
      const keep = ~(0xFF << shift);
      switch (off) {
        case 0x010: this.gpioOut = ((this.gpioOut & keep) | bits) >>> 0; break;
        case 0x018: this.gpioOut = (this.gpioOut |  bits) >>> 0; break;
        case 0x020: this.gpioOut = (this.gpioOut & ~bits) >>> 0; break;
        case 0x028: this.gpioOut = (this.gpioOut ^  bits) >>> 0; break;
        case 0x030: this.gpioOe  = ((this.gpioOe & keep) | bits) >>> 0; break;
        case 0x038: this.gpioOe  = (this.gpioOe  |  bits) >>> 0; break;
        case 0x040: this.gpioOe  = (this.gpioOe  & ~bits) >>> 0; break;
        /* FIFO_WR: keep it so FIFO_RD can echo it back — see the note at FIFO_ST. */
        case 0x054:
          this.fifoEco = ((this.fifoEco & keep) | bits) >>> 0;
          if ((addr & 3) === 3) {
            this.fifoPendiente = true;                      // dato listo tras el ultimo byte
            this.quizaLanzarCore1(this.fifoEco >>> 0);
          }
          break;
        default: break;
      }
      return;
    }

    if (addr >= 0xE000ED08 && addr <= 0xE000ED0B) {          // SCB->VTOR
      const shift = (addr & 3) * 8;
      this.vtor = (((this.vtor & ~(0xFF << shift)) | (data << shift))) >>> 0;
      return;
    }

    // Pad/function-select, NVIC, SysTick, DWT control: accepted and ignored.
  }

  /**
   * `svc` performs a real exception entry rather than being intercepted: the
   * handler we vector to is the image's own, which is the whole point of
   * simulating this target at all.
   */
  /** Cuantas veces se ha pedido cada svc: dice en que estado esta el programa sin verlo. */
  svcHist = new Uint32Array(256);
  onSvc(_imm: number, cpu: { getReg(i: number): number; setReg(i: number, v: number): void;
                            setException?(n: number): void }): void {
    this.svcHist[_imm & 0xFF]++;
    const sp = (cpu.getReg(13) - 32) >>> 0;
    const put = (i: number, v: number) => {
      const a = sp + i * 4;
      this.write8(a, v & 0xFF); this.write8(a + 1, (v >>> 8) & 0xFF);
      this.write8(a + 2, (v >>> 16) & 0xFF); this.write8(a + 3, (v >>> 24) & 0xFF);
    };
    // r0-r3, r12, lr, return address, xpsr — the standard Cortex-M frame. The
    // return address is already past the svc, which is what lets the handler
    // find its immediate at pc[-2].
    put(0, cpu.getReg(0)); put(1, cpu.getReg(1));
    put(2, cpu.getReg(2)); put(3, cpu.getReg(3));
    put(4, cpu.getReg(12)); put(5, cpu.getReg(14));
    put(6, cpu.getReg(15)); put(7, 0x01000000);

    cpu.setReg(13, sp);
    cpu.setReg(14, EXC_RETURN);
    cpu.setReg(15, this.read32(this.vtor + 11 * 4) & ~1);   // SVCall vector
    // Y hay que ANUNCIAR la excepcion, no solo saltar a su vector: el manejador
    // pregunta `mrs r0, ipsr` para saber en cual esta. Sin esto se le contesta 0
    // ("modo hilo") y se va por la rama de error — un bkpt, en el SDK de UVM2.
    cpu.setException?.(11);   // SVCall
  }

  /** Undo the above when the handler returns to EXC_RETURN. */
  private exceptionReturn(): void {
    const sp = this.cpu.getReg(13) >>> 0;
    const get = (i: number) => this.read32(sp + i * 4);
    this.cpu.setReg(0, get(0)); this.cpu.setReg(1, get(1));
    this.cpu.setReg(2, get(2)); this.cpu.setReg(3, get(3));
    this.cpu.setReg(12, get(4)); this.cpu.setReg(14, get(5));
    this.cpu.setReg(15, get(6) & ~1);
    this.cpu.setReg(13, (sp + 32) >>> 0);
    this.cpu.setException(0);   // de vuelta a modo hilo
  }

  // ─── Frame ────────────────────────────────────────────────────────────────

  /**
   * Run until the image has consumed one Vectrex frame's worth of bus cycles.
   *
   * There is no WFI to wait for here: the image paces itself against the bus
   * clock, exactly as it will on hardware, so the frame boundary is simply
   * 30000 bus cycles of elapsed Vectrex time.
   */
  private avisoMulticore = false;
  private fifoEco = 0;   /* last word written to FIFO_WR, echoed back on FIFO_RD */
  /** ¿Hay una palabra sin leer? Es el bit VLD de FIFO_ST. Ver la nota alli. */
  private fifoPendiente = false;

  runFrame(): Segment[] {
    const until = this.busCycle + BUS_PER_FRAME;
    let spent = 0;

    while (!this.halted && this.busCycle < until && spent < MAX_CPU_CYCLES_PER_FRAME) {
      /* ANDA EL QUE VA POR DETRAS. Es lo unico que hace falta para que los dos nucleos
       * corran a la misma tasa de CICLOS en vez de a la misma de instrucciones: se mira
       * que reloj esta mas atrasado y se le da un paso. El bus va detras del minimo. */
      if (this.cpu1 && this.relojCore1 < this.relojCore0) {
        const c1 = this.pasoCore1();
        this.relojCore1 += c1 > 0 ? c1 : 1;
        spent += c1;
        this.sincronizaBus();
        continue;
      }
      const pc = this.cpu.getReg(15) >>> 0;
      // `>>> 0` again: without it the masked value is negative and never
      // matches, so the handler "returns" by executing address 0xFFFFFFF9.
      if (((pc & 0xFFFFFFF0) >>> 0) === 0xFFFFFFF0) {
        if (pc === 0xFFFFFFFE) { this.halted = true; break; }   // game_main returned
        this.exceptionReturn();
        continue;
      }

      // Historial de PCs, solo para el informe de fallo. Un fallo en este nucleo
      // dice DONDE se paro pero no COMO se llego, y sin el "como" no se puede
      // distinguir "instruccion no implementada" de "el juego ha saltado a su
      // manejador de excepciones por defecto" — que se parecen mucho en el log y
      // se arreglan en sitios opuestos.
      this.pcHist[this.pcHistN++ & (PC_HIST - 1)] = pc;
      if ((this.muestra++ & 63) === 0) this.perfil.set(pc, (this.perfil.get(pc) ?? 0) + 1);

      if (pc === ROM_LOOKUP) { this.romTableLookup(); continue; }
      if (this.sdLeerAddr && pc === this.sdLeerAddr) { this.atiendeSdLeer(this.cpu); continue; }
      if (this.sdLeerDesdeAddr && pc === this.sdLeerDesdeAddr) { this.atiendeSdLeerDesde(this.cpu); continue; }
      /* VOLCADO DE REGISTROS EN UN PC (depuracion): VOLCAR=0x2000362c imprime r0-r12, lr y
       * 40 bytes en [r8] las primeras 4 veces que core 0 pasa por ahi. Sin esto, saber que
       * calculo se tuerce dentro del emulador es adivinar sobre el desensamblado. */
      if (this.volcarEn && pc === this.volcarEn && this.volcados < 4) {
        this.volcados++;
        const r = []; for (let i = 0; i <= 12; i++) r.push(`r${i}=0x${(this.cpu.getReg(i) >>> 0).toString(16)}`);
        r.push(`lr=0x${(this.cpu.getReg(14) >>> 0).toString(16)}`);
        const b = []; const base = this.cpu.getReg(8) >>> 0;
        for (let i = 0; i < 40; i += 4) b.push('0x' + this.read32(base + i).toString(16));
        let txt = ''; for (let i = 0; i < 24; i++) { const c = this.read8((this.cpu.getReg(0) >>> 0) + i); if (c < 32 || c > 126) break; txt += String.fromCharCode(c); }
        console.log(`[Uvm2System] VOLCAR pc=0x${pc.toString(16)} ${r.join(' ')}\n   [r8..]: ${b.join(' ')}   [r0] como texto: "${txt}"`);
      }
      if (this.execAddr && pc === this.execAddr) { this.execVuelta[0] = this.cpu.getReg(14) & ~1; this.enLista++; }
      else if (this.execVuelta[0] && pc === this.execVuelta[0]) { this.execVuelta[0] = 0; this.enLista--; }
      if (this.sdHwInitAddr && pc === this.sdHwInitAddr) { this.atiendeSdHwInit(this.cpu); continue; }
      if (this.sdHwReadBlockAddr && pc === this.sdHwReadBlockAddr) { this.atiendeSdHwReadBlock(this.cpu); continue; }
      if (this.sdHwWriteBlockAddr && pc === this.sdHwWriteBlockAddr) { this.atiendeSdHwWriteBlock(this.cpu); continue; }
      /* Mirar y dejar pasar: no se atrapa la llamada, solo se le hace la foto. */
      if (this.frameBeginAddr && pc === this.frameBeginAddr && this.statsAddr) {
        this.ciclosDeBus    = this.read32(this.statsAddr + 4);   // bus_cycles
        this.vectoresDeBus  = this.read32(this.statsAddr + 8);   // vectors
        this.framesDelJuego++;
      }

      // Ejecutar la tabla de vectores es siempre un PC perdido. Se corta aqui, con
      // el salto que llevo hasta ahi todavia en el anillo, en vez de dejar que
      // avance por los datos y choque contra el manejador por defecto — que en el
      // log se lee como "instruccion no implementada 0xbe00" y despista.
      /* Solo en la .um2: alli la base de SRAM es la tabla de vectores. En la BIOS del
       * cartucho propio la base de SRAM es __sramcode, CODIGO, y saltar ahi es lo normal. */
      if (!this.flash && pc >= SRAM_BASE && pc < VECTORES_FIN) {
        console.error(
          `[Uvm2System] PC PERDIDO: 0x${pc.toString(16)} esta DENTRO de la tabla de ` +
          `vectores (0x${SRAM_BASE.toString(16)}-0x${(VECTORES_FIN - 1).toString(16)}), ` +
          `que son datos, no codigo. Ultimos saltos: ${this.historialSaltos().join(' ')}`);
        this.halted = true;
        break;
      }

      let c: number;
      try {
        c = this.cpu.step(this);
      } catch (e) {
        console.error(`[Uvm2System] CPU fault at 0x${pc.toString(16)}:`, e);
        console.error('[Uvm2System] PCs anteriores (del mas antiguo al fallo):',
          this.historialPC().map(v => '0x' + v.toString(16)).join(' -> '));
        console.error('[Uvm2System] Ultimos saltos (origen->destino):',
          this.historialSaltos().join(' '));
        const vec = this.vectoresQueApuntanA(pc);
        if (vec.length) {
          console.error(
            `[Uvm2System] 0x${pc.toString(16)} ES el manejador de: ${vec.join(', ')}. ` +
            `O sea que el juego ha VECTORIZADO ahi; el fallo no es la instruccion, ` +
            `es lo que provoco la excepcion.`);
        }
        this.halted = true;
        break;
      }
      // Un PC que no continua al siguiente opcode es un salto: se apunta el par.
      const sig = this.cpu.getReg(15) >>> 0;
      if (sig !== ((pc + 2) >>> 0) && sig !== ((pc + 4) >>> 0)) {
        const k = this.saltoN++ & (SALTO_HIST - 1);
        this.saltoDe[k] = pc; this.saltoA[k] = sig;
      }

      spent += c;
      this.relojCore0 += c;
      this.sincronizaBus();
    }

    this.lastFrameBusCycles = BUS_PER_FRAME;
    const { draw, drawCnt, erse, erseCnt } = this.beam.swapBuffers();

    if (drawCnt === 0) {
      // 120 frames son ~2,4 s: bastante para no gritar en una pantalla de carga.
      if (++this.framesSinDibujo === 120 && !this.avisadoSinDibujo) {
        this.avisadoSinDibujo = true;
        this.informeSinDibujo();
      }
    } else {
      this.framesSinDibujo = 0;
    }
    this.canvas.renderFrame(draw, drawCnt, erse, erseCnt);
    /* SI NO DIBUJA, DECIR DONDE SE QUEDO. Un emulador mudo no distingue "la imagen esta
     * colgada" de "el emulador no arranca" ni de "no se llamo al emulador", y hoy me ha
     * costado tres intentos en el fichero equivocado por no tener esto.
     *
     * Se informa UNA vez, tras varios frames seguidos sin un solo vector, con el PC mas
     * visitado del perfil de muestreo — que es donde esta girando— y los ultimos saltos.
     * Con eso, `addr2line` sobre el .elf da la funcion exacta. */
    if (drawCnt === 0) {
      if (++this.framesMudos === 30 && !this.avisoMudo) {
        this.avisoMudo = true;
        let peorPc = 0, peorN = 0;
        for (const [pc, n] of this.perfil) if (n > peorN) { peorN = n; peorPc = pc; }
        console.error(
          `[Uvm2System] 30 frames SIN UN SOLO VECTOR. La imagen corre pero no dibuja.\n` +
          `  gira sobre todo en pc=0x${peorPc.toString(16)} (${peorN} muestras de ` +
          `${this.muestra >> 6})\n` +
          `  ultimos saltos: ${this.historialSaltos().join(' ')}\n` +
          `  para saber que funcion es:  arm-none-eabi-addr2line -f -e <juego>.elf ` +
          `0x${peorPc.toString(16)}`);
      }
    } else {
      this.framesMudos = 0;
    }

    const segments = vectorsToSegments(draw, drawCnt, this.frameCounter);
    this.frameCounter++;
    return segments;
  }

  // ─── Host wiring (canvas, input, audio) ───────────────────────────────────

  setCanvas(el: HTMLCanvasElement): void { this.canvas.setCanvas(el); }

  /**
   * Joystick axes. The image reads these the hard way — it drives the DAC and
   * compares against the pot through the VIA's comparator bit — so the values
   * go where the analog hardware expects them, not into a shortcut register.
   */
  setJoyAxis(x: number, y: number): void {
    this.beam.alg_jch0 = Math.max(0, Math.min(255, Math.round((x / 127 + 1) * 127.5)));
    this.beam.alg_jch1 = Math.max(0, Math.min(255, Math.round((y / 127 + 1) * 127.5)));
  }

  /**
   * Buttons. On a real Vectrex these are NOT on VIA Port B — they hang off the
   * PSG's register 14, and the image reads them through the AY handshake. Port
   * B bit 5 is the joystick COMPARATOR, so routing buttons through
   * `via.joyButtons` (whose read ORs bits 4-7 into ORB) pins the comparator
   * high and every axis reads as full deflection. VectrexSystem forces
   * joyButtons to 0 for the same reason.
   *
   * `portBMask` is the host's convention: bits 4-7, active-low, bit 4 = button 1.
   * PSG register 14 wants J1 in bits 0-3 and J2 in bits 4-7, also active-low.
   */
  setJoyButtons(portBMask: number): void {
    this.psg.Regs[14] = 0xF0 | ((portBMask >> 4) & 0x0F);
  }

  /** PSG audio out. Call after a user gesture, as the browser requires. */
  startAudio(): void {
    if (this.audioCtx) return;
    try {
      const ctx = new AudioContext({ sampleRate: 44100 });
      // eslint-disable-next-line @typescript-eslint/no-deprecated
      const node = ctx.createScriptProcessor(2048, 0, 1);
      node.onaudioprocess = (ev) => {
        this.psg.fillBuffer(ev.outputBuffer.getChannelData(0), 2048);
      };
      node.connect(ctx.destination);
      this.audioCtx = ctx;
      this.audioNode = node;
      if (ctx.state !== 'running') ctx.resume().catch(() => {});
    } catch (e) {
      console.warn('[Uvm2System] Audio init failed:', e);
    }
  }

  stopAudio(): void {
    try { this.audioNode?.disconnect(); this.audioCtx?.close().catch(() => {}); } catch {}
    this.audioNode = null;
    this.audioCtx = null;
  }

  getAudioContextAndOutputNode(): { ctx: AudioContext; outputNode: AudioNode } | null {
    return this.audioCtx && this.audioNode
      ? { ctx: this.audioCtx, outputNode: this.audioNode }
      : null;
  }
}
