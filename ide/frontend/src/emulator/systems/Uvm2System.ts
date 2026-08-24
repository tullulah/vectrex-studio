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

/** Beam vector list → the IDE's Segment shape (same mapping the other systems use). */
function vectorsToSegments(
  draw: readonly { x0: number; y0: number; x1: number; y1: number; color: number }[],
  drawCnt: number,
  frameCounter: number,
): Segment[] {
  const segments: Segment[] = [];
  for (let i = 0; i < drawCnt; i++) {
    const v = draw[i];
    segments.push({ x0: v.x0, y0: v.y0, x1: v.x1, y1: v.y1,
                    intensity: v.color, frame: frameCounter });
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
const BOOTRAM_BASE  = 0x400E0000;
const BOOTRAM_SIZE_ = 0x1000;
const BOOTLOCK_OFF  = 0x800;
const BOOTLOCK_N    = 16;
const SRAM_SIZE = 0x00082000;          // 520 KB, as on the real RP2350
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

// ── Timing ──────────────────────────────────────────────────────────────────
/** RP2350 core cycles per Vectrex bus cycle (150 MHz / 1.5 MHz). */
const CPU_PER_BUS   = 100;
/** A 50 Hz Vectrex frame. Matches UVM2_CYCLES_PER_FRAME in the SDK. */
const BUS_PER_FRAME = 30000;
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
/** Pins the cartridge pulls up and never drives: PB6, /IRQ, /NMI. */
const PULLUP_IN = 0x20C00000;

/** EXC_RETURN we hand the handler: thread mode, main stack, no FP context. */
const EXC_RETURN = 0xFFFFFFF9;

export class Uvm2System implements ISystem, IBus {
  readonly cpuName = 'Cortex-M33 (UVM2 halt mode)';

  private sram = new Uint8Array(SRAM_SIZE);
  private cpu  = new Thumb2();
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
  private cpuAcc   = 0;
  private cycleCount = 0;              // DWT_CYCCNT
  private lastPollPc = -1;             // spin detection, see maybeCollapseSpin
  /** PSM.FRCE_OFF: solo tiene que recordar. Ver la nota de PSM_BASE. */
  private psmFrceOff = 0;
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
  private romTableLookup(): void {
    const code = this.cpu.getReg(0) & 0xffff;
    const c1 = String.fromCharCode(code & 0xff), c2 = String.fromCharCode(code >>> 8);
    if (!(code in ROM_IGNORABLES)) {
      console.warn(
        `[Uvm2System] rom_table_lookup('${c1}','${c2}') (0x${code.toString(16)}) no esta ` +
        `modelada; se devuelve una funcion que no hace nada. Si el juego se comporta ` +
        `raro a partir de aqui, esta es la razon.`);
    }
    this.cpu.setReg(0, ROM_NOOP | 1);
    this.cpu.setReg(15, this.cpu.getReg(14) & ~1);
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
  init(um2: Uint8Array): void {
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
    this.sram.set(payload, (loadAddr - SRAM_BASE) >>> 0);
    this.montarBootrom();
    this.reset();
  }

  reset(): void {
    this.frameCounter = 0;
    this.busCycle = 0;
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
    this.cpu.setFetchRegion(this.sram, SRAM_BASE);

    // The firmware loads MSP and the entry point from the image's own vector
    // table — word 0 and word 1 — exactly as a Cortex-M reset would.
    this.cpu.setReg(13, this.read32(SRAM_BASE));
    this.cpu.setReg(15, this.read32(SRAM_BASE + 4) & ~1);
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
  private advanceBus(cpuCycles: number): void {
    this.cycleCount = (this.cycleCount + cpuCycles) >>> 0;
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

  /** Address currently on the bus, assembled from the GPIO pins. */
  private busAddress(): number {
    return (((this.gpioOut & ADDR_MASK) >>> 8)
         | ((this.gpioOut & A14_MASK) ? 0x4000 : 0)
         | ((this.gpioOut & A15_MASK) ? 0x8000 : 0)) >>> 0;
  }

  private addressesVia(): boolean {
    return (this.busAddress() & 0xF000) === 0xD000;
  }

  /** The VIA latches a write here — the same edge the hardware uses. */
  private onFallingEdge(): void {
    if (this.gpioOut & HALT_MASK) return;      // 6809 still owns the bus
    if (this.gpioOut & RW_MASK)   return;      // read cycle
    if (!this.addressesVia())     return;      // parked, or not the VIA

    this.escriturasVia++;
    this.via.write(this.busAddress() & 0xF, this.gpioOut & DATA_MASK,
                   (xsh) => { this.beam.alg_xsh = xsh; });
  }

  /**
   * A read cycle presents its data while the clock is high. Latching it once
   * per rising edge (rather than on every GPIO_IN poll) matters: VIA reads have
   * side effects, and the image polls that register in a tight loop.
   */
  private onRisingEdge(): void {
    if (this.gpioOut & HALT_MASK) return;
    if (!(this.gpioOut & RW_MASK)) return;
    if (this.gpioOe & DATA_MASK)  return;      // we are still driving the bus
    if (!this.addressesVia())     return;

    this.dataIn = this.via.read(
      this.busAddress() & 0xF, this.beam.alg_compare,
      this.psg.Regs, this.psg.selectedRegister,
    ) & 0xFF;
  }

  /** GPIO_IN as the image sees it: driven pins read back, plus the real inputs. */
  private gpioIn(): number {
    let v = (this.gpioOut & this.gpioOe) | PULLUP_IN;
    if (this.clkHigh) v |= CLK_MASK;
    if (!(this.gpioOe & DATA_MASK)) {
      v = (v & ~DATA_MASK) | (this.dataIn & DATA_MASK);
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

    if (addr < BOOTROM_SIZE) return this.bootrom[addr];

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

    // PSM: solo FRCE_OFF, y solo para que multicore_reset_core1() pueda leer de vuelta
    // el bit que acaba de escribir. Ver la nota de PSM_BASE.
    if (((addr & 0xFFFF0000) >>> 0) === PSM_BASE) {
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
      // FIFO_ST at +0x50. THERE IS NO SECOND CORE HERE, and without an answer the image
      // never gets past multicore_launch_core1_raw: pico-sdk pushes the entry point to
      // core 1 and spins on RDY, which stayed 0 for ever. Measured: a dual-core .um2 sat
      // in a three-instruction loop at multicore.h:186 and drew nothing, with no error —
      // "the emulator does nothing". Answering RDY|VLD lets core 0 carry on; whatever the
      // game delegated to core 1 simply does not happen, which is a visible half-game
      // rather than a black screen. Build with UVM2_DUAL_CORE=0 to emulate the whole game.
      //
      // Answering RDY alone only moves the hang twenty instructions on: the launch is a
      // six-word HANDSHAKE and core 0 pops each word back and compares. So FIFO_RD echoes
      // whatever was last written to FIFO_WR, the comparison passes, and the launch
      // returns instead of restarting for ever.
      else if (off === 0x050) {
        if (!this.avisoMulticore) {
          this.avisoMulticore = true;
          console.warn('[Uvm2System] la imagen arranca el nucleo 1 y aqui no hay segundo ' +
                       'nucleo: se responde al FIFO para que no se cuelgue, pero lo que ' +
                       'corra en el core 1 no se ejecuta. Compila con UVM2_DUAL_CORE=0.');
        }
        word = 0x3;   // RDY | VLD
      }
      else if (off === 0x058) word = this.fifoEco;   // FIFO_RD: echo, see above
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
      // PSM: FRCE_OFF con sus alias atomicos. Aqui no hay segundo nucleo que apagar; lo
      // unico que hace falta es que el registro RECUERDE, porque multicore_reset_core1()
      // gira leyendolo. Ver la nota de PSM_BASE.
      if (((addr & 0xFFFF0000) >>> 0) === PSM_BASE) {
        const off = addr & 0xFFC, shift = (addr & 3) * 8;
        if (off === PSM_FRCE_OFF) {
          const bits = (data << shift) >>> 0;
          const alias = (addr >>> 12) & 3;    // 0 normal, 1 XOR, 2 SET, 3 CLR
          if (alias === 1)      this.psmFrceOff = (this.psmFrceOff ^ bits) >>> 0;
          else if (alias === 2) this.psmFrceOff = (this.psmFrceOff | bits) >>> 0;
          else if (alias === 3) this.psmFrceOff = (this.psmFrceOff & ~bits) >>> 0;
          else this.psmFrceOff = ((this.psmFrceOff & ~(0xFF << shift)) | bits) >>> 0;
        }
        return;
      }
      // XOSC y PLL sólo se leen; lo que se les escribe no cambia nada aquí.
      if (addr >= XOSC_BASE && addr < XOSC_BASE + ATOM_SIZE) return;
      for (const p of PLL_BASES) if (addr >= p && addr < p + ATOM_SIZE) return;
    }

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
        case 0x054: this.fifoEco = ((this.fifoEco & keep) | bits) >>> 0; break;
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
  onSvc(_imm: number, cpu: { getReg(i: number): number; setReg(i: number, v: number): void;
                            setException?(n: number): void }): void {
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

  runFrame(): Segment[] {
    const until = this.busCycle + BUS_PER_FRAME;
    let spent = 0;

    while (!this.halted && this.busCycle < until && spent < MAX_CPU_CYCLES_PER_FRAME) {
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

      // Ejecutar la tabla de vectores es siempre un PC perdido. Se corta aqui, con
      // el salto que llevo hasta ahi todavia en el anillo, en vez de dejar que
      // avance por los datos y choque contra el manejador por defecto — que en el
      // log se lee como "instruccion no implementada 0xbe00" y despista.
      if (pc >= SRAM_BASE && pc < VECTORES_FIN) {
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
      this.advanceBus(c);
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
