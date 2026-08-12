// Abstracción de núcleo de emulador para permitir alternar implementaciones (Rust WASM vs jsvecx u otras).
// Política: interfaz mínima estable consumida por paneles; métodos extra opcionales deben ser verificados con guards.

export interface RegistersSnapshot { a:number;b:number;dp:number;x:number;y:number;u:number;s:number;pc:number;cycles:number;frame_count:number;cycle_frame?:number;bios_frame?:number;last_intensity:number;draw_vl_count?:number; }
export interface MetricsSnapshot { total:number;unimplemented:number;frames:number;cycle_frame?:number;bios_frame?:number;draw_vl:number;last_intensity:number;unique_unimplemented:number[];cycles:number;avg_cycles_per_frame?:number;top_opcodes:[number,number][];first_unimpl?:number;via_t1?:number;via_irq_count?:number;via_irq_line?:boolean;via_ifr?:number;via_ier?:number; }
export interface Segment { x0:number;y0:number;x1:number;y1:number;intensity:number;frame:number; }

export interface IEmulatorCore {
  init(wasmUrl?: string): Promise<void> | void;
  ensureBios?(opts?: { bytes?: Uint8Array; urlCandidates?: string[] }): Promise<boolean>;
  loadBios(bytes: Uint8Array): void;
  isBiosLoaded(): boolean;
  reset(coldReset?: boolean): void;
  resetStats?(): void;
  loadProgram(bytes: Uint8Array, base?: number): void;
  runFrame(maxInstr?: number): void;
  metrics(): MetricsSnapshot | null;
  registers(): RegistersSnapshot | null;
  biosCalls?(): string[];
  clearBiosCalls?(): void;
  enableTraceCapture?(on:boolean, limit?:number): void;
  clearTrace?(): void;
  traceLog?(): any[];
  loopWatch?(): any[];
  getSegmentsShared(): Segment[];
  drainSegmentsJson?(): Segment[];
  peekSegmentsJson?(): Segment[];
  demoTriangle?(): Segment[];
  snapshotMemory?(): Uint8Array;
  invalidateMemoryView?(): void;
  setInput?(x:number,y:number,buttons:number): void;
  // Audio (opcional): devuelve delta de muestras i16 (copiadas) y sample rate fijo.
  audioPrepareDelta?(): Int16Array; // retorna nuevas muestras (puede longitud 0)
  audioSampleRate?(): number;       // Hz (ej. 44100)
  audioHasOverflow?(): boolean;     // true si último delta fue snapshot completo por overflow

  /** Devuelve true si el envelope PSG acaba de finalizar (evento one-shot, se limpia tras leer). */
  psgEnvJustFinished?(): boolean;
  
  // Debug output system (optional methods)
  getDebugMessages?(): string[];
  clearDebugMessages?(): void;
  getLastDebugOutput?(): string;

  /** Load an ARM binary (rp2350 target). Switches the active backend to Rp2350System. */
  loadArm?(bin: Uint8Array, elf?: Uint8Array, canvas?: HTMLCanvasElement, simSdFiles?: string[], simSdPreviews?: Record<string, string>): void;

  /** Load a `.um2` image (uvm2 target). Switches the active backend to Uvm2System. */
  loadUvm2?(um2: Uint8Array, canvas?: HTMLCanvasElement): void;

  /** Set joystick J1 axis values for RP2350 backend (-128..127, 0=center). */
  setJoyAxis?(x: number, y: number): void;
  /** Set joystick J1 button state for RP2350 backend (Port B mask, bits 4-7 active-low). */
  setJoyButtons?(portBMask: number): void;
  /** Set joystick J2 axis values (only consumed by RP2350 backend so far). */
  setJoyAxis2?(x: number, y: number): void;
  /** Set joystick J2 button state (active-low, bits 0-3 = btn 1-4). */
  setJoyButtons2?(mask: number): void;

  // Live AudioContext + output node of the active target, for the parallel
  // MediaStream tap used by the gameplay video recorder. Null when no audio.
  getAudioContextAndOutputNode?(): { ctx: AudioContext; outputNode: AudioNode } | null;
}

// Tipo del identificador de backend.
export type EmulatorBackend = 'jsvecx';
