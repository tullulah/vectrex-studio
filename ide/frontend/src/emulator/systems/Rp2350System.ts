/**
 * Rp2350System — ARM Cortex-M33 / RP2350 emulation system.
 *
 * Composes the Thumb2 CPU with the existing Vectrex hardware modules
 * (Via6522, Beam, Psg) to emulate a VPy debug cartridge based on the
 * RP2350 microcontroller.
 *
 * Memory map:
 *   0x10000000–0x13FFFFFF  Flash (4 MB).  Game binary is loaded at offset
 *                           0x200000 so that code addresses starting at
 *                           0x10200000 land in the correct flash locations.
 *   0x20000000–0x2007FFFF  SRAM (512 KB, zero-initialised).
 *   0x0000D000–0x0000D00F  VIA 6522 registers (Vectrex bus address space).
 *   Everything else        Returns 0xFF on reads, ignores writes.
 *
 * Bus-trap mechanism:
 *   The RP2350 firmware communicates with the Vectrex bus via two helper
 *   functions (bus_write / bus_read) implemented as GPIO bit-bang routines
 *   in helpers.rs.  In the emulator we intercept these by registering a
 *   "trap" at their symbol addresses.  When the Thumb2 CPU's PC reaches a
 *   trap address we call a TypeScript handler instead of executing the real
 *   GPIO code, then simulate a BX LR return.
 *
 *   bus_write(r0=addr, r1=data):  routes a byte write to Via6522.write().
 *   bus_read(r0=addr) → r0:       routes a byte read through Via6522.read().
 *
 * Frame synchronisation:
 *   The firmware calls WFI at the end of each display frame.  The Thumb2
 *   CPU sets its hitWfi flag on that instruction; the run-loop exits and
 *   Rp2350System swaps the Beam buffers, producing the Segment list for
 *   the IDE renderer.
 */

import type { Segment }   from '../../emulatorCore.js';
import type { ISystem }   from '../interfaces/ISystem.js';
import type { IBus }      from '../interfaces/IBus.js';
import { Via6522 }        from '../hardware/Via6522.js';
import { Beam }           from '../hardware/Beam.js';
import { Psg }            from '../hardware/Psg.js';
import { Canvas }         from '../hardware/Canvas.js';
import { Thumb2 }         from '../cpu/Thumb2.js';
import { extractElf32Symbols, readElf32Entry, loadElf32IntoFlash } from '../util/Elf32Symbols.js';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/** RP2350 flash base address. */
const FLASH_BASE  = 0x10000000;

// ARM beam-drawing constants (direct-inject path).
// The ARM VPy drawing engine uses T1 timer latch = 0x7F = 127 ticks per move.
// Scale factor maps i8 delta [-127, 127] to ALG units so that max delta covers
// half the display (ALG_MAX_X/2 = 16500, ALG_MAX_Y/2 = 20500).
const ARM_ALG_SCALE  = 127;
const ALG_MAX_X      = 33000;
const ALG_MAX_Y      = 41000;
const ALG_CENTER_X   = ALG_MAX_X >> 1;  // 16500
const ALG_CENTER_Y   = ALG_MAX_Y >> 1;  // 20500
/** Flash end (exclusive). */
const FLASH_END   = 0x14000000;
/** Flash array size: 4 MB. */
const FLASH_SIZE  = 4 * 1024 * 1024;

/** SRAM base address. */
const SRAM_BASE   = 0x20000000;
/** SRAM end (exclusive). */
const SRAM_END    = 0x20080000;
/** SRAM size: 512 KB. */
const SRAM_SIZE   = 512 * 1024;

/**
 * Offset within the flash array at which the game binary is loaded.
 * The linker script places game_main at 0x10200000, so that address maps
 * to flash[0x200000].
 */
const GAME_FLASH_OFFSET = 0x200000;

/**
 * Default entry-point address used when no ELF metadata is available.
 * Corresponds to the known address of game_main in generated binaries
 * (0x10201818 from the linker script).
 */
const DEFAULT_ENTRY_POINT = 0x10201818;

/** VIA address mask — matches the lower 4 bits of the VIA register select. */
const VIA_ADDR_MASK = 0x0000_D000;
const VIA_ADDR_PAGE = 0x0000_F000;

/**
 * Safety cycle limit per frame at RP2350 clock (150 MHz).
 * 150_000_000 / 50 = 3_000_000 cycles per 20 ms frame; use 15× headroom
 * so complex scenes (SnowBros level + enemies) never hit the budget.
 * Only catches genuine infinite loops (>300 ms of simulated work).
 */
const MAX_CYCLES_PER_FRAME = 45_000_000;

// ---------------------------------------------------------------------------
// ARM drawing helpers
// ---------------------------------------------------------------------------

/**
 * Interpret the low 8 bits of a 32-bit register value as a signed i8.
 * ARM ldrsb sign-extends to 32 bits, but high-level functions can also
 * pass 32-bit deltas that have been truncated to 8 bits by the bus_write
 * `& 0xFF`.  Either way, taking the low byte and re-signing is correct.
 */
function armI8(r: number): number {
  const b = r & 0xFF;
  return b > 127 ? b - 256 : b;
}

/**
 * Clamp a beam coordinate to the half-open interval [0, maxCoord).
 * Used only for dv_reset; beam tracking itself is unbounded.
 */
function clampAlg(v: number, maxCoord: number): number {
  return v < 0 ? 0 : v >= maxCoord ? maxCoord - 1 : v;
}

/**
 * Cohen-Sutherland line clipping against [0, ALG_MAX_X) × [0, ALG_MAX_Y).
 * Returns clipped [x0,y0,x1,y1] or null if the segment is entirely off-screen.
 * The beam position is tracked unbounded; only the drawable portion is returned.
 */
function clipSegment(
  x0: number, y0: number, x1: number, y1: number,
): [number, number, number, number] | null {
  const XMAX = ALG_MAX_X - 1, YMAX = ALG_MAX_Y - 1;
  const code = (x: number, y: number): number =>
    (x < 0 ? 1 : x > XMAX ? 2 : 0) | (y < 0 ? 4 : y > YMAX ? 8 : 0);
  let c0 = code(x0, y0), c1 = code(x1, y1);
  for (;;) {
    if (!(c0 | c1)) return [x0 | 0, y0 | 0, x1 | 0, y1 | 0]; // both inside
    if (c0 & c1)    return null;                                // trivially outside
    const cout = c0 !== 0 ? c0 : c1;
    let x = 0, y = 0;
    if (cout & 8)      { x = x0 + (x1 - x0) * (YMAX - y0) / (y1 - y0); y = YMAX; }
    else if (cout & 4) { x = x0 + (x1 - x0) * (0    - y0) / (y1 - y0); y = 0;    }
    else if (cout & 2) { y = y0 + (y1 - y0) * (XMAX - x0) / (x1 - x0); x = XMAX; }
    else               { y = y0 + (y1 - y0) * (0    - x0) / (x1 - x0); x = 0;    }
    if (cout === c0) { x0 = x; y0 = y; c0 = code(x0, y0); }
    else             { x1 = x; y1 = y; c1 = code(x1, y1); }
  }
}

// ---------------------------------------------------------------------------
// Segment conversion helper (mirrors VectrexSystem.ts)
// ---------------------------------------------------------------------------

function vectorsToSegments(
  draw: readonly { x0: number; y0: number; x1: number; y1: number; color: number }[],
  drawCnt: number,
  frameCounter: number,
): Segment[] {
  const segments: Segment[] = [];
  for (let i = 0; i < drawCnt; i++) {
    const v = draw[i];
    segments.push({
      x0:        v.x0,
      y0:        v.y0,
      x1:        v.x1,
      y1:        v.y1,
      intensity: v.color,
      frame:     frameCounter,
    });
  }
  return segments;
}

// ---------------------------------------------------------------------------
// Trap function type
// ---------------------------------------------------------------------------

/**
 * A trap handler is invoked instead of executing code at a given address.
 * It receives the CPU so it can read/write registers.
 * Returns the number of cycles that the simulated call consumed.
 */
type TrapFn = (cpu: Thumb2) => number;

// ---------------------------------------------------------------------------
// Rp2350System
// ---------------------------------------------------------------------------

/**
 * RP2350-based Vectrex cartridge emulation system.
 *
 * Implements ISystem so it can be used as a drop-in alongside VectrexSystem.
 * Also implements IBus so the Thumb2 CPU can call `this.read8` / `this.write8`
 * directly without an extra wrapper object.
 */
export class Rp2350System implements ISystem, IBus {
  readonly cpuName = 'ARM Cortex-M33 (RP2350)';

  // Hardware
  private readonly beam:   Beam;
  private readonly psg:    Psg;
  private readonly via:    Via6522;
  private readonly canvas: Canvas;
  private readonly cpu:    Thumb2;

  // Memory
  private readonly flash: Uint8Array = new Uint8Array(FLASH_SIZE);
  private readonly sram:  Uint8Array = new Uint8Array(SRAM_SIZE);

  // Trap table: PC value (Thumb bit already stripped) → handler
  private readonly traps: Map<number, TrapFn> = new Map();

  // Frame counter for Segment metadata
  private frameCounter: number = 0;

  // ---- ARM direct-drawing state ----
  // Tracks beam position for the direct-inject drawing path.
  // Updated by dv_reset / dv_move_to / dv_draw_delta traps so the ARM
  // drawing engine bypasses the VIA simulation entirely.
  private armBeamX: number    = ALG_CENTER_X;
  private armBeamY: number    = ALG_CENTER_Y;
  private armIntensity: number = 0;

  // ---- Joystick input state ----
  // Signed i8 axis values [-127, 127]. Default 0 (centred).
  private joyJ1X: number = 0;
  private joyJ1Y: number = 0;
  private joyJ2X: number = 0;
  private joyJ2Y: number = 0;
  // Button state for BTN_STATE_J1 (bits 4-7, active-low). Default 0xF0 = no buttons pressed.
  // Kept separate from this.via.joyButtons (which is reset to 0x00 for analog SAR correctness).
  private joyButtonState: number = 0xF0;
  // Player 2 button state mirrored into BTN_STATE_J2. Same active-low / bits 0-3
  // convention as the PSG reg 14 layout — the trap below writes it straight to SRAM.
  private joyButtonState2: number = 0xFF;

  // ---- Audio ----
  private audioCtx:  AudioContext | null           = null;
  private audioNode: ScriptProcessorNode | null    = null;
  static readonly AUDIO_SAMPLE_RATE = 44100;
  static readonly AUDIO_BUFFER_SIZE = 512;

  constructor() {
    this.beam   = new Beam();
    this.psg    = new Psg();
    this.canvas = new Canvas();

    this.via = new Via6522(
      // algUpdate callback: forward to Beam.update
      (via_ora, via_orb, via_acr, via_pcr, via_cb2h, via_cb2s) => {
        this.beam.update(via_ora, via_orb, via_acr, via_pcr, via_cb2h, via_cb2s);
      },
      // sndUpdate callback: forward to Psg.write
      (via_orb, via_ora) => {
        this.psg.write(via_orb, via_ora);
      },
    );

    this.cpu = new Thumb2();
  }

  // -------------------------------------------------------------------------
  // ISystem
  // -------------------------------------------------------------------------

  /**
   * Initialise the system with a game binary (and optional ELF data for
   * accurate symbol resolution).
   *
   * @param rom      Raw game binary (.bin).  Loaded into flash at offset
   *                 GAME_FLASH_OFFSET (0x200000), mapping address 0x10200000.
   * @param elfData  Optional ELF32 image of the same binary.  When provided,
   *                 bus_write / bus_read traps are registered at the exact
   *                 symbol addresses extracted from the ELF.  When absent,
   *                 a heuristic scan of the flash image is used.
   */
  init(rom: Uint8Array, elfData?: Uint8Array): void {
    console.log(`[Rp2350System.init] START rom=${rom.length}b elf=${elfData?.length ?? 0}b`);

    // Load binary into flash.
    // Prefer ELF program-header segments when available: the ELF is always the
    // ARM binary, whereas the raw .bin may have been overwritten by an M6809
    // compilation (both targets share the same SnowBros.bin output path).
    this.flash.fill(0xFF);
    if (elfData && elfData.length >= 52) {
      const segsLoaded = loadElf32IntoFlash(elfData, this.flash, FLASH_BASE);
      console.log(`[Rp2350System.init] Flash loaded from ELF: ${segsLoaded} PT_LOAD segments`);
    } else {
      // Fallback: raw binary at fixed game offset
      const len = Math.min(rom.length, FLASH_SIZE - GAME_FLASH_OFFSET);
      this.flash.set(rom.subarray(0, len), GAME_FLASH_OFFSET);
      console.log(`[Rp2350System.init] Flash loaded from binary: ${len}b at offset 0x${GAME_FLASH_OFFSET.toString(16)}`);
    }

    // Spot-check: log first 8 bytes at game offset (should be ARM code)
    const fb = this.flash.subarray(GAME_FLASH_OFFSET, GAME_FLASH_OFFSET + 8);
    console.log(`[Rp2350System.init] Flash[0x${GAME_FLASH_OFFSET.toString(16)}..+8]:`,
      Array.from(fb).map(b => b.toString(16).padStart(2,'0')).join(' '));

    // Determine entry point and trap addresses
    let entryPoint = DEFAULT_ENTRY_POINT;

    this.traps.clear();

    if (elfData && elfData.length >= 52) {
      const entry = readElf32Entry(elfData);
      if (entry !== 0) entryPoint = entry;
      console.log(`[Rp2350System.init] ELF entry=0x${entryPoint.toString(16)}`);

      const symbols = extractElf32Symbols(elfData);
      console.log(`[Rp2350System.init] ELF symbols (${symbols.size}):`,
        Object.fromEntries([...symbols.entries()].map(([k,v]) => [k, '0x'+v.toString(16)])));
      this.registerTrapsFromSymbols(symbols);
    } else {
      // No ELF: parse the VPy2 game header to recover the real entry point.
      // Layout (16 bytes at offset 0): [magic u32 'VPy2'][game_main u32][rsv u32][rsv u32].
      // Without this, we'd fall back to DEFAULT_ENTRY_POINT (hardcoded), which only
      // matches the binary that DEFAULT_ENTRY_POINT was originally captured from.
      if (rom.length >= 8 &&
          rom[0] === 0x56 && rom[1] === 0x50 && rom[2] === 0x79 && rom[3] === 0x32) {
        const headerEntry = rom[4] | (rom[5] << 8) | (rom[6] << 16) | (rom[7] << 24);
        if (headerEntry !== 0) {
          entryPoint = headerEntry >>> 0;
          console.log(`[Rp2350System.init] VPy2 header entry=0x${entryPoint.toString(16)}`);
        }
      }
      console.log(`[Rp2350System.init] No ELF — prologue scan. elfData=${elfData?.length ?? 0}b, entry=0x${entryPoint.toString(16)}`);
      this.registerTrapsFromPrologue();
    }

    console.log(`[Rp2350System.init] DONE entry=0x${entryPoint.toString(16)} traps=${this.traps.size} trapAddrs=[${[...this.traps.keys()].map(a=>'0x'+a.toString(16)).join(',')}]`);

    this.reset(entryPoint);
    console.log(`[Rp2350System.init] CPU reset. PC=0x${this.cpu.pc.toString(16)} SP=0x${this.cpu.getReg(13).toString(16)}`);
  }

  reset(): void;
  reset(entryPoint?: number): void;
  reset(entryPoint: number = DEFAULT_ENTRY_POINT): void {
    this.sram.fill(0);
    this.frameCounter = 0;
    this.joyButtonState = 0xF0;  // default: no buttons pressed (active-low)

    // BTN_STATE_J1 / BTN_STATE_J2 must default to 0xF0 / 0xFF (active-low, no buttons pressed).
    // vpy_update_buttons caches VIA Port B into these before the first loop iteration, but until
    // then (and as a safety net) they must not read as "all pressed".
    this.sram[0x7F144] = 0xF0;  // BTN_STATE_J1: bits 4-7 high = J1 buttons released
    this.sram[0x7F148] = 0xFF;  // BTN_STATE_J2: all bits high = J2 buttons released

    this.armBeamX    = ALG_CENTER_X;
    this.armBeamY    = ALG_CENTER_Y;
    this.armIntensity = 0;

    this.via.reset();
    this.beam.reset();
    this.psg.reset();

    this.cpu.reset();

    // Set SP to top of SRAM (standard ARM convention)
    // The linker script places the stack at the top of the RAM region.
    // SRAM top = 0x20080000 → initial SP = 0x20040000 (safe default, 256 KB)
    this.cpu.setReg(13, 0x20040000);

    // Set PC to entry point (strip Thumb bit — PC register stores plain address)
    this.cpu.setReg(15, entryPoint & ~1);

    // Set LR to a sentinel that triggers halt if game_main ever returns
    this.cpu.setReg(14, 0xFFFFFFFE);
  }

  /**
   * Advance emulation by one display frame.
   *
   * Runs until the CPU executes a WFI instruction (frame-sync gate used by
   * the VPy firmware) or until the safety cycle budget is exhausted.
   *
   * Returns all vector segments drawn during the frame.
   */
  runFrame(): Segment[] {
    const fc     = this.frameCounter;
    const logAll = fc < 10 || fc % 60 === 0;

    if (logAll) {
      console.log(`[Rp2350System.runFrame] ENTER frame=${fc} pc=0x${this.cpu.pc.toString(16)} sp=0x${this.cpu.getReg(13).toString(16)} traps=${this.traps.size}`);
    }

    this.cpu.hitWfi = false;

    let spent   = 0;
    let lastPc  = this.cpu.pc;
    let steps   = 0;
    // Collect first few PC values executed this frame for diagnostics.
    const firstPcs: string[] = [];

    while (!this.cpu.hitWfi && spent < MAX_CYCLES_PER_FRAME) {
      lastPc = this.cpu.pc;

      if (logAll && firstPcs.length < 8) {
        firstPcs.push('0x' + lastPc.toString(16));
      }

      // Check for trap before executing
      const pc = this.cpu.pc & ~1; // strip Thumb bit for lookup
      const trap = this.traps.get(pc);
      if (trap) {
        // Execute trap handler instead of real code
        const trapCycles = trap(this.cpu);
        // Simulate "BX LR": PC ← LR with Thumb bit cleared
        this.cpu.setReg(15, this.cpu.getReg(14) & ~1);
        spent += trapCycles;
        steps++;
        continue;
      }

      // Execute one CPU instruction.
      // We do NOT tick VIA/Beam here: all drawing is handled by high-level traps
      // (dv_reset, dv_move_to, dv_draw_delta, bus_write/bus_read) that tick the
      // hardware themselves.  Ticking on every cycle costs ~600K JS calls/frame
      // for game logic that doesn't touch the beam, causing frame-time jitter.
      const c = this.cpu.step(this);

      spent += c;
      steps++;
    }

    if (logAll) {
      const reason = this.cpu.hitWfi
        ? `WFI after ${steps} steps`
        : `BUDGET_EXHAUSTED cycles=${spent} steps=${steps} lastPc=0x${lastPc.toString(16)}`;
      console.log(`[Rp2350System.runFrame] EXIT frame=${fc} reason=${reason}`);
      if (firstPcs.length > 0) {
        console.log(`[Rp2350System.runFrame] first PCs: ${firstPcs.join(' → ')}`);
      }
    }
    // Dump enemy pool state every frame for the first 90 frames, then every 60
    if (fc < 90 || fc % 60 === 0) {
      const ecOff = 0x7F308;
      const count = (this.sram[ecOff] | (this.sram[ecOff+1]<<8) | (this.sram[ecOff+2]<<16) | (this.sram[ecOff+3]<<24)) >>> 0;
      if (count > 0) {
        const b = 0x7F30C;
        const active = (this.sram[b] | (this.sram[b+1]<<8) | (this.sram[b+2]<<16) | (this.sram[b+3]<<24)) >>> 0;
        const wx = (this.sram[b+4]  | (this.sram[b+5]<<8)  | (this.sram[b+6]<<16)  | (this.sram[b+7]<<24))  | 0;
        const wy = (this.sram[b+8]  | (this.sram[b+9]<<8)  | (this.sram[b+10]<<16) | (this.sram[b+11]<<24)) | 0;
        const wpIdx = this.sram[b+20];
        console.log(`[Rp2350 ENEMY] frame=${fc} world=(${wx},${wy}) wp_idx=${wpIdx}`);
      }
    }

    // Swap beam buffers, render to canvas, and build segment list for this frame
    const { draw, drawCnt, erse, erseCnt } = this.beam.swapBuffers();
    this.canvas.renderFrame(draw, drawCnt, erse, erseCnt);
    const segments = vectorsToSegments(draw, drawCnt, this.frameCounter);
    this.frameCounter++;
    return segments;
  }

  // -------------------------------------------------------------------------
  // IBus
  // -------------------------------------------------------------------------

  read8(addr: number): number {
    addr = addr >>> 0;

    // Flash: 0x10000000–0x13FFFFFF
    if (addr >= FLASH_BASE && addr < FLASH_END) {
      return this.flash[(addr - FLASH_BASE) & (FLASH_SIZE - 1)] ?? 0xFF;
    }

    // SRAM: 0x20000000–0x2007FFFF
    if (addr >= SRAM_BASE && addr < SRAM_END) {
      return this.sram[addr - SRAM_BASE] ?? 0;
    }

    // VIA region: any address whose page bits equal 0xD000
    if ((addr & VIA_ADDR_PAGE) === VIA_ADDR_MASK) {
      return this.via.read(
        addr & 0xf,
        this.beam.alg_compare,
        this.psg.Regs,
        this.psg.selectedRegister,
      );
    }

    return 0xFF;
  }

  write8(addr: number, data: number): void {
    addr = addr >>> 0;
    data &= 0xFF;

    // SRAM: 0x20000000–0x2007FFFF
    if (addr >= SRAM_BASE && addr < SRAM_END) {
      this.sram[addr - SRAM_BASE] = data;
      // ── Ball-variable write trace (debug bounce bug) ──────────────────
      // Detect when the HIGH byte (last byte, +3) of ball vel vars is written,
      // then log the full signed 32-bit value so we can see direction changes.
      if (addr === 0x2007F29B) {  // BALL_VY high byte
        const vy = this.sram[0x7F298] | (this.sram[0x7F299] << 8)
                 | (this.sram[0x7F29A] << 16) | (this.sram[0x7F29B] << 24);
        console.log(`[bounce-trace] BALL_VY written: ${vy | 0}  frame=${this.frameCounter}`);
      }
      if (addr === 0x2007F297) {  // BALL_VX high byte
        const vx = this.sram[0x7F294] | (this.sram[0x7F295] << 8)
                 | (this.sram[0x7F296] << 16) | (this.sram[0x7F297] << 24);
        console.log(`[bounce-trace] BALL_VX written: ${vx | 0}  frame=${this.frameCounter}`);
      }
      return;
    }

    // VIA region
    if ((addr & VIA_ADDR_PAGE) === VIA_ADDR_MASK) {
      this.via.write(addr & 0xf, data, (xsh) => {
        this.beam.alg_xsh = xsh;
      });
    }

    // Flash and other regions are read-only / unmapped — ignore writes
  }

  // -------------------------------------------------------------------------
  // Trap registration
  // -------------------------------------------------------------------------

  /**
   * Register bus_write and bus_read traps from parsed ELF symbol table.
   *
   * bus_write(r0=vectrex_addr, r1=data_byte):
   *   - Extracts VIA register from address bits [3:0]
   *   - Calls via.write(reg, data, xsh_callback)
   *
   * bus_read(r0=vectrex_addr) → r0:
   *   - Extracts VIA register from address bits [3:0]
   *   - Calls via.read(...) and places result in r0
   */
  private registerTrapsFromSymbols(symbols: Map<string, number>): void {
    const busWriteAddr    = symbols.get('bus_write');
    const busReadAddr     = symbols.get('bus_read');
    const waitRecalAddr   = symbols.get('vpy_wait_recal');
    const dvResetAddr     = symbols.get('dv_reset');
    const setIntAddr      = symbols.get('vpy_set_intensity');
    const dvMoveToAddr    = symbols.get('dv_move_to');
    const dvDrawDeltaAddr = symbols.get('dv_draw_delta');
    const j1xAddr         = symbols.get('vpy_j1_x');
    const j1yAddr         = symbols.get('vpy_j1_y');
    const j2xAddr         = symbols.get('vpy_j2_x');
    const j2yAddr         = symbols.get('vpy_j2_y');

    if (busWriteAddr !== undefined) {
      this.traps.set(busWriteAddr & ~1, this.makeBusWriteTrap());
    }
    if (busReadAddr !== undefined) {
      this.traps.set(busReadAddr & ~1, this.makeBusReadTrap());
    }

    // vpy_wait_recal: frame-sync gate (polls VIA T1 on real hardware).
    // We intercept it as the WFI frame boundary.
    if (waitRecalAddr !== undefined) {
      this.traps.set(waitRecalAddr & ~1, this.makeWaitRecalTrap());
      console.log(`[Rp2350System] vpy_wait_recal trap @ 0x${(waitRecalAddr & ~1).toString(16)}`);
    }

    // High-level drawing function traps — bypass VIA simulation entirely.
    // The ARM drawing sequence (dv_reset / vpy_set_intensity / dv_move_to /
    // dv_draw_delta) uses RSH=0 which makes signed i8 deltas wrap when cast to
    // u8 PORT_A values, producing wrong movements in the VIA model.  We
    // intercept at the function level and implement the semantics directly.
    if (dvResetAddr !== undefined) {
      this.traps.set(dvResetAddr & ~1, this.makeDvResetTrap());
      console.log(`[Rp2350System] dv_reset trap @ 0x${(dvResetAddr & ~1).toString(16)}`);
    }
    if (setIntAddr !== undefined) {
      this.traps.set(setIntAddr & ~1, this.makeSetIntensityTrap());
      console.log(`[Rp2350System] vpy_set_intensity trap @ 0x${(setIntAddr & ~1).toString(16)}`);
    }
    if (dvMoveToAddr !== undefined) {
      this.traps.set(dvMoveToAddr & ~1, this.makeDvMoveTrap());
      console.log(`[Rp2350System] dv_move_to trap @ 0x${(dvMoveToAddr & ~1).toString(16)}`);
    }
    if (dvDrawDeltaAddr !== undefined) {
      this.traps.set(dvDrawDeltaAddr & ~1, this.makeDvDrawDeltaTrap());
      console.log(`[Rp2350System] dv_draw_delta trap @ 0x${(dvDrawDeltaAddr & ~1).toString(16)}`);
    }

    // Joystick axis traps: vpy_j1_x / vpy_j1_y read Port A after a PSG write
    // which leaves stale PSG data in via_ora.  Trap them to return clean state.
    // The real vpy_j1_x/y functions end with "sxtb r0, r0" to sign-extend the
    // unsigned byte to a signed 32-bit integer.  We must replicate that here so
    // that callers (e.g. vpy_print_number) receive the correct signed value.
    // sxtb equivalent in JS: (b << 24) >> 24  (arithmetic right shift)
    if (j1xAddr !== undefined) {
      this.traps.set(j1xAddr & ~1, (cpu: Thumb2) => {
        cpu.setReg(0, (this.joyJ1X << 24) >> 24);  // sxtb: sign extend i8→i32
        return 10;
      });
    }
    if (j1yAddr !== undefined) {
      this.traps.set(j1yAddr & ~1, (cpu: Thumb2) => {
        cpu.setReg(0, (this.joyJ1Y << 24) >> 24);  // sxtb: sign extend i8→i32
        return 10;
      });
    }
    if (j2xAddr !== undefined) {
      this.traps.set(j2xAddr & ~1, (cpu: Thumb2) => {
        cpu.setReg(0, (this.joyJ2X << 24) >> 24);
        return 10;
      });
    }
    if (j2yAddr !== undefined) {
      this.traps.set(j2yAddr & ~1, (cpu: Thumb2) => {
        cpu.setReg(0, (this.joyJ2Y << 24) >> 24);
        return 10;
      });
    }

    // vpy_msg_def: compile-time declaration, pure no-op at runtime.
    // Trap it to avoid going through cpu.step() + via.tick() + beam.tick().
    const msgDefAddr = symbols.get('vpy_msg_def');
    if (msgDefAddr !== undefined) {
      this.traps.set(msgDefAddr & ~1, (_cpu: Thumb2): number => 0);
    }

    // vpy_update_buttons: bypass Via6522 Port B read entirely.
    // Reading Port B goes through alg_compare (bit 5) and via_t1pb7 (bit 7),
    // both of which can mask button 2 and button 4 inputs.  Write joyButtons
    // (bits 4-7, active-low) directly to BTN_STATE_J1 and BTN_STATE_J2 in SRAM.
    const updateButtonsAddr = symbols.get('vpy_update_buttons');
    const btnJ1Addr = symbols.get('BTN_STATE_J1');
    const btnJ2Addr = symbols.get('BTN_STATE_J2');
    // Fallback SRAM offsets (used in reset() as well; must match linker script).
    const BTN_J1_OFF = 0x7F144;
    const BTN_J2_OFF = 0x7F148;
    if (updateButtonsAddr !== undefined) {
      this.traps.set(updateButtonsAddr & ~1, (_cpu: Thumb2): number => {
        const j1Off = btnJ1Addr !== undefined
          ? btnJ1Addr - 0x20000000
          : BTN_J1_OFF;
        const j2Off = btnJ2Addr !== undefined
          ? btnJ2Addr - 0x20000000
          : BTN_J2_OFF;
        // joyButtons: bits 4-7 active-low.  Use joyButtonState (not via.joyButtons, which
        // is reset to 0x00 for analog SAR correctness and would read as all-pressed).
        this.sram[j1Off] = this.joyButtonState & 0xF0;
        // J2 buttons mirror joyButtonState2 (active-low). Default 0xFF = released.
        this.sram[j2Off] = this.joyButtonState2 & 0xFF;
        return 10;
      });
      console.log(`[Rp2350System] vpy_update_buttons trap @ 0x${(updateButtonsAddr & ~1).toString(16)}`);
    }
  }

  /**
   * Fallback trap registration by scanning the flash image for known
   * bus_write / bus_read function prologues.
   *
   * bus_write prologue (from helpers.rs):
   *   push {r4, r5, lr}   → Thumb16 encoding: 2D E9 30 40
   *   ldr  r4, =0xD0000000 (follows shortly after)
   *
   * bus_read prologue:
   *   push {r4, lr}        → Thumb16 encoding: 2D E9 10 40
   *
   * We scan for the 4-byte PUSH encoding and check the surrounding context
   * (the LDR of 0xD0000000 SIO_BASE) to distinguish the two functions.
   */
  private registerTrapsFromPrologue(): void {
    // Thumb2 PUSH {r4,r5,lr}: encoding T2 (32-bit)
    //   11101 00 1 0010 1101 = E92D, register list with r4(bit4)=1 r5(bit5)=1 lr(bit14)=1 → 0x4030
    const PUSH_R4_R5_LR_HI = 0xE92D;
    const PUSH_R4_R5_LR_LO = 0x4030;

    // Thumb2 PUSH {r4,lr}: E92D 4010
    const PUSH_R4_LR_HI = 0xE92D;
    const PUSH_R4_LR_LO = 0x4010;

    const base = GAME_FLASH_OFFSET;
    const end  = Math.min(this.flash.length - 4, base + 0x100000); // search first 1 MB

    let foundWrite = false;
    let foundRead  = false;

    for (let off = base; off < end && !(foundWrite && foundRead); off += 2) {
      const hi = this.flash[off] | (this.flash[off + 1] << 8);
      const lo = this.flash[off + 2] | (this.flash[off + 3] << 8);

      if (!foundWrite && hi === PUSH_R4_R5_LR_HI && lo === PUSH_R4_R5_LR_LO) {
        // Candidate for bus_write — verify a LDR literal to 0xD0000000 within 32 bytes
        if (this.hasLdrSioBase(off + 4, 32)) {
          const flashAddr = FLASH_BASE + off;
          this.traps.set(flashAddr & ~1, this.makeBusWriteTrap());
          foundWrite = true;
        }
      }

      if (!foundRead && hi === PUSH_R4_LR_HI && lo === PUSH_R4_LR_LO) {
        // Candidate for bus_read — verify a LDR literal to 0xD0000000 within 32 bytes
        if (this.hasLdrSioBase(off + 4, 32)) {
          const flashAddr = FLASH_BASE + off;
          this.traps.set(flashAddr & ~1, this.makeBusReadTrap());
          foundRead = true;
        }
      }
    }
  }

  /**
   * Check whether a literal pool within `windowBytes` bytes of `startOff` in
   * the flash array contains the SIO_BASE constant 0xD0000000.
   */
  private hasLdrSioBase(startOff: number, windowBytes: number): boolean {
    // Scan the literal pool area after the instruction sequence
    const poolStart = startOff + windowBytes;
    const poolEnd   = Math.min(poolStart + 64, this.flash.length - 4);
    for (let p = poolStart; p < poolEnd; p += 4) {
      const word = (this.flash[p] | (this.flash[p + 1] << 8) | (this.flash[p + 2] << 16) | (this.flash[p + 3] << 24)) >>> 0;
      if (word === 0xD0000000) return true;
    }
    return false;
  }

  // -------------------------------------------------------------------------
  // Trap factory methods
  // -------------------------------------------------------------------------

  /**
   * Build the bus_write trap handler.
   *
   * Called when the RP2350 firmware invokes bus_write(addr, data):
   *   r0 = Vectrex bus address (e.g. 0xD001 for VIA ORA)
   *   r1 = data byte to write
   *
   * The hardware function uses ~620 cycles (300-cycle hold + overhead).
   * We model it as 620 cycles so VIA timer and beam ticks stay roughly
   * in sync with wall-clock time.
   */
  private makeBusWriteTrap(): TrapFn {
    return (cpu: Thumb2): number => {
      const busAddr = cpu.getReg(0);
      const data    = cpu.getReg(1) & 0xFF;

      // Only handle VIA region (address 0xD000-0xD00F in Vectrex space)
      const reg = busAddr & 0xf;
      this.via.write(reg, data, (xsh) => {
        this.beam.alg_xsh = xsh;
      });

      // Tick hardware for beam integration (20 ticks — enough for SR/CB2
      // timing without blowing the per-frame cycle budget on complex scenes).
      for (let i = 0; i < 20; i++) {
        this.via.tick();
        this.beam.tick(
          this.via.via_acr,
          this.via.via_pcr,
          this.via.via_ca2,
          this.via.via_cb2h,
          this.via.via_cb2s,
          this.via.via_t1pb7,
          this.via.via_orb,
        );
      }

      return 20;
    };
  }

  /**
   * Build the bus_read trap handler.
   *
   * Called when the RP2350 firmware invokes bus_read(addr):
   *   r0 = Vectrex bus address
   * Returns:
   *   r0 = data byte read
   *
   * Modelled as 620 cycles (symmetric with bus_write).
   */
  private makeBusReadTrap(): TrapFn {
    return (cpu: Thumb2): number => {
      const busAddr = cpu.getReg(0);

      const reg   = busAddr & 0xf;
      const value = this.via.read(
        reg,
        this.beam.alg_compare,
        this.psg.Regs,
        this.psg.selectedRegister,
      );

      cpu.setReg(0, value & 0xFF);

      // Tick hardware for bus cycle time (symmetric with bus_write)
      for (let i = 0; i < 20; i++) {
        this.via.tick();
        this.beam.tick(
          this.via.via_acr,
          this.via.via_pcr,
          this.via.via_ca2,
          this.via.via_cb2h,
          this.via.via_cb2s,
          this.via.via_t1pb7,
          this.via.via_orb,
        );
      }

      return 20;
    };
  }

  /**
   * Build the vpy_wait_recal trap handler.
   *
   * In hardware this polls the VIA T1 timer until it fires (~1/60 s).
   * In the emulator we intercept and use it as the frame-sync gate: signal
   * hitWfi so the run-loop exits and swaps Beam buffers.
   *
   * No VIA ticking needed here — the drawing functions are trapped at the
   * high level (dv_reset / dv_move_to / dv_draw_delta), so the VIA state
   * is effectively idle during drawing.
   */
  private makeWaitRecalTrap(): TrapFn {
    return (cpu: Thumb2): number => {
      cpu.hitWfi = true;
      return 128;
    };
  }

  // -------------------------------------------------------------------------
  // High-level ARM drawing trap factories
  // -------------------------------------------------------------------------
  //
  // These bypass the VIA simulation for the core drawing primitives.
  // The ARM VPy codegen uses RSH=0 after dv_reset, which means signed i8
  // deltas (stored as u8 in PORT_A) wrap for negative values — making the
  // VIA S&H model produce wrong movements for the negative direction.
  // By trapping at the function boundary we implement the INTENDED
  // signed-delta semantics directly.
  //
  // Coordinate mapping:
  //   ARM i8 delta [-127, 127] → ALG units via ARM_ALG_SCALE = 127
  //   (T1 latch 0x7F = 127 ticks → max movement ≈ ALG_MAX_X/2 = 16500)
  //   Y is inverted: Vectrex +Y = up, ALG +y = down (larger y = lower on canvas)

  /** dv_reset() — reset integrators and beam position to display centre. */
  private makeDvResetTrap(): TrapFn {
    return (_cpu: Thumb2): number => {
      this.armBeamX    = ALG_CENTER_X;
      this.armBeamY    = ALG_CENTER_Y;
      this.armIntensity = 0;
      // Neutralise ongoing beam integration so VIA ticking (if any) is benign.
      this.beam.alg_dx        = 0;
      this.beam.alg_dy        = 0;
      this.beam.alg_vectoring = 0;
      this.beam.alg_zsh       = 0;
      return 100;
    };
  }

  /**
   * vpy_set_intensity(r0=intensity) — set draw brightness.
   *
   * On real hardware writes PORT_A=intensity but never latches alg_zsh
   * (would need ORB=0x04 first).  We set it directly.
   */
  private makeSetIntensityTrap(): TrapFn {
    return (cpu: Thumb2): number => {
      const intensity   = cpu.getReg(0) & 0x7F;
      this.armIntensity = intensity;
      this.beam.alg_zsh = intensity;
      return 10;
    };
  }

  /**
   * dv_move_to(r0=x, r1=y) — reposition beam without drawing.
   *
   * The beam is tracked in UNBOUNDED virtual ALG coordinates so that objects
   * partially off-screen don't have their paths clamped to the screen edge.
   * dv_draw_delta uses Cohen-Sutherland clipping to only render the visible
   * portion of each segment.
   */
  private makeDvMoveTrap(): TrapFn {
    return (cpu: Thumb2): number => {
      const dx = cpu.getReg(0) | 0;  // signed 32-bit screen coord
      const dy = cpu.getReg(1) | 0;
      this.armBeamX += dx * ARM_ALG_SCALE;   // unbounded — no clamp
      this.armBeamY -= dy * ARM_ALG_SCALE;   // Y inverted, still unbounded
      return 200;
    };
  }

  /**
   * dv_draw_delta(r0=dx_i8, r1=dy_i8) — draw one vector segment.
   *
   * Tracks the beam in unbounded virtual space; clips the segment with
   * Cohen-Sutherland before injecting into the Beam draw list so that
   * objects scrolling off-screen don't pile up on the screen edge.
   */
  private makeDvDrawDeltaTrap(): TrapFn {
    return (cpu: Thumb2): number => {
      const dx   = armI8(cpu.getReg(0));
      const dy   = armI8(cpu.getReg(1));
      const newX = this.armBeamX + dx * ARM_ALG_SCALE;   // unbounded
      const newY = this.armBeamY - dy * ARM_ALG_SCALE;   // unbounded, Y inverted
      const clipped = clipSegment(this.armBeamX, this.armBeamY, newX, newY);
      if (clipped !== null) {
        this.beam.addSegmentDirect(clipped[0], clipped[1], clipped[2], clipped[3], this.armIntensity);
      }
      this.armBeamX = newX;
      this.armBeamY = newY;
      return 200;
    };
  }

  // -------------------------------------------------------------------------
  // Public utilities
  // -------------------------------------------------------------------------

  /**
   * Wire the DOM canvas element so renderFrame() draws to the screen.
   * Call this after loadArm() with the same <canvas> element JSVecX uses.
   */
  setCanvas(el: HTMLCanvasElement): void {
    this.canvas.setCanvas(el);
  }

  /**
   * Set J1 joystick button state for Port B bits 4-7 (active-low).
   *
   * Pass a bitmask where each bit corresponds to a button:
   *   bit 4 = J1 Button 1,  bit 5 = J1 Button 2
   *   bit 6 = J1 Button 3,  bit 7 = J1 Button 4
   *
   * Active-low convention: 0 = pressed, 1 = released.
   * Default (no buttons held): 0xF0.
   *
   * Example — Button 1 pressed: setJoyButtons(0xE0)
   */
  setJoyButtons(portBMask: number): void {
    this.joyButtonState = portBMask & 0xF0;
    this.via.joyButtons = portBMask & 0xF0;
  }

  /**
   * Set J1 joystick axis values.
   *
   * @param x  Horizontal axis, signed [-127, 127]. 0 = centred.
   * @param y  Vertical axis,   signed [-127, 127]. 0 = centred.
   */
  setJoyAxis(x: number, y: number): void {
    this.joyJ1X = (x | 0) & 0xFF;
    this.joyJ1Y = (y | 0) & 0xFF;
  }

  /** Same as setJoyAxis but for Player 2 (drives vpy_j2_x / vpy_j2_y). */
  setJoyAxis2(x: number, y: number): void {
    this.joyJ2X = (x | 0) & 0xFF;
    this.joyJ2Y = (y | 0) & 0xFF;
  }

  /**
   * Set Player-2 button state mirrored to BTN_STATE_J2 (PSG reg 14, active-low).
   * mask bit 0 = J2 Button 1, bit 1 = J2 Button 2, etc. Default (released): 0xFF.
   */
  setJoyButtons2(mask: number): void {
    this.joyButtonState2 = mask & 0xFF;
  }

  // -------------------------------------------------------------------------
  // Audio
  // -------------------------------------------------------------------------

  /**
   * Start PSG audio synthesis via a ScriptProcessor node.
   * Must be called after a user gesture so the AudioContext can start.
   * Idempotent — safe to call multiple times.
   */
  startAudio(): void {
    if (this.audioCtx) return;
    try {
      const ctx = new AudioContext({ sampleRate: Rp2350System.AUDIO_SAMPLE_RATE });
      // eslint-disable-next-line @typescript-eslint/no-deprecated
      const node = ctx.createScriptProcessor(Rp2350System.AUDIO_BUFFER_SIZE, 0, 1);
      node.onaudioprocess = (ev) => {
        this.psg.fillBuffer(
          ev.outputBuffer.getChannelData(0),
          Rp2350System.AUDIO_BUFFER_SIZE,
        );
      };
      node.connect(ctx.destination);
      this.audioCtx  = ctx;
      this.audioNode = node;
      // Resume if browser suspended it
      if (ctx.state !== 'running') ctx.resume().catch(() => {});
    } catch (e) {
      console.warn('[Rp2350System] Audio init failed:', e);
    }
  }

  /** Stop and destroy the audio context. */
  stopAudio(): void {
    try {
      this.audioNode?.disconnect();
      this.audioCtx?.close().catch(() => {});
    } catch {}
    this.audioNode = null;
    this.audioCtx  = null;
  }

  /**
   * Manually register a trap at a given code address.
   *
   * Useful for testing or for adding traps for functions other than
   * bus_write / bus_read (e.g. a hypothetical debug_print stub).
   *
   * The Thumb bit in `addr` is stripped automatically.
   */
  registerTrap(addr: number, fn: TrapFn): void {
    this.traps.set(addr & ~1, fn);
  }

  /** Read a byte from SRAM by absolute address (for debugger/memory inspector). */
  peekSram(addr: number): number {
    addr = addr >>> 0;
    if (addr >= SRAM_BASE && addr < SRAM_END) {
      return this.sram[addr - SRAM_BASE] & 0xFF;
    }
    return 0xFF;
  }

  /** Read a byte from flash by absolute address (for debugger). */
  peekFlash(addr: number): number {
    addr = addr >>> 0;
    if (addr >= FLASH_BASE && addr < FLASH_END) {
      return this.flash[(addr - FLASH_BASE) & (FLASH_SIZE - 1)] & 0xFF;
    }
    return 0xFF;
  }
}
