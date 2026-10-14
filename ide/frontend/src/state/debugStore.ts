import { create } from 'zustand';
import type { DebugState as LegacyDebugState } from '../types/models.js';
import { useEditorStore } from './editorStore.js';
import { ensureComponent } from './dockBus';
import { syncEmulatorBreakpoints } from '../debug/breakpointSync';

export type ExecutionState = 'stopped' | 'running' | 'paused';

export interface PdbData {
  version: string;
  source: string;
  asm?: string;  // Path to generated ASM file
  binary: string;
  entry_point: string;
  symbols: Record<string, string>;
  lineMap: Record<string, string>;
  functions?: Record<string, {
    startLine: number;
    endLine: number;
    address: string;
    type: 'vpy' | 'native';
  }>;
  nativeCalls?: Record<string, string>;
  asmFunctions?: Record<string, {
    name: string;
    file: string;
    startLine: number;
    endLine: number;
    type: 'vpy' | 'native' | 'bios';
  }>;
  asmAddressMap?: Record<string, string>; // ASM line number -> binary address
  asmLineMap?: Record<string, {
    file: string;
    address: string;
    line: number;
    bankId?: string | number;
  }>;
  vpyLineMap?: Record<string, { file: string; line: number; column: number }>; // Multibank format
  romConfig?: { isMultibank?: boolean; [key: string]: unknown };
  variables?: Record<string, { name: string; address: string; size: number; type?: string; declLine?: number | null }>;
}

export interface CallFrame {
  function: string;
  file?: string | null;
  line: number | null;
  address: string;
  type: 'vpy' | 'native' | 'bios';
}

interface DebugStore extends LegacyDebugState {
  // Legacy setters (keep for compatibility)
  setRegisters: (r: Record<string,string>) => void;
  setVariables: (vars: Array<{name:string;value:string}>) => void;
  setConstants: (c: Array<{name:string;value:string}>) => void;
  setPC: (pc: number) => void;
  setCycles: (cycles: number) => void;
  reset: () => void;
  
  // New debug state
  state: ExecutionState;
  currentVpyLine: number | null;
  currentVpyFile: string | null;
  currentAsmAddress: string | null;
  pdbData: PdbData | null;
  callStack: CallFrame[];
  currentFps: number;
  /* EL REFRESCO QUE PERMITE EL DIBUJO, aparte del que consigue el emulador.
   *
   * Son dos cosas distintas y confundirlas manda a optimizar el sitio equivocado:
   * `currentFps` es lo que el navegador logra emular por segundo de reloj de pared, y
   * `drawFps` es a cuanto podria refrescar el juego EN LA CONSOLA si el dibujo fuese el
   * unico coste — 1,5 MHz de bus entre los ciclos que costo el frame. El segundo es fiel
   * porque la lista de comandos se reproduce igual aqui que alli; el primero solo dice si
   * el emulador va comodo. Un fps absoluto de consola NO se puede dar: el modelo de CPU no
   * tiene esperas de memoria y sale unas veinte veces optimista. */
  drawFps: number;
  loadingForDebug: boolean; // Flag to indicate loading binary for debug session (don't auto-start)
  
  // New actions
  setState: (state: ExecutionState) => void;
  setCurrentVpyLine: (line: number | null) => void;
  setCurrentVpyLineWithFile: (line: number, file: string) => void;
  setCurrentAsmAddress: (address: string | null) => void;
  loadPdbData: (pdb: PdbData) => void;
  clearPdbData: () => void;
  updateCallStack: (stack: CallFrame[]) => void;
  updateStats: (cycles: number, fps: number, drawFps?: number) => void;
  setLoadingForDebug: (loading: boolean) => void;
  
  // Debug controls
  run: () => void;
  pause: () => void;
  stop: () => void;
  stepOver: () => void;
  stepInto: () => void;
  stepOut: () => void;
  
  // Breakpoint synchronization
  onBreakpointAdded: (uri: string, line: number) => void;
  onBreakpointRemoved: (uri: string, line: number) => void;
  syncBreakpointsToWasm: (pdb: PdbData, breakpoints: Record<string, number[]>) => void;
}

const initial: LegacyDebugState = {
  registers: {},
  pc: 0,
  cycles: 0,
  variables: [],
  constants: [],
};

/** Has the Call Stack panel been opened for a stop this session? */
let callStackShown = false;

export const useDebugStore = create<DebugStore>((set, get) => ({
  ...initial,
  
  // Legacy setters (keep for compatibility)
  setRegisters: (r) => set({ registers: r }),
  setVariables: (variables) => set({ variables }),
  setConstants: (constants) => set({ constants }),
  setPC: (pc) => set({ pc }),
  setCycles: (cycles) => set({ cycles }),
  reset: () => set(initial),
  
  // New state
  state: 'stopped',
  currentVpyLine: null,
  currentVpyFile: null,
  currentAsmAddress: null,
  pdbData: null,
  callStack: [],
  currentFps: 0,
  drawFps: 0,
  loadingForDebug: false,
  
  // New actions
  // The call stack is the paused program's: running or stopped, it is stale
  setState: (state) => set(state === 'paused' ? { state } : { state, callStack: [] }),
  setCurrentVpyLine: (line) => set({ currentVpyLine: line }),
  setCurrentVpyLineWithFile: (line, file) => set({ currentVpyLine: line, currentVpyFile: file }),
  setCurrentAsmAddress: (address) => set({ currentAsmAddress: address }),
  setLoadingForDebug: (loading) => set({ loadingForDebug: loading }),
  clearPdbData: () => set({ pdbData: null, currentVpyLine: null, currentVpyFile: null, currentAsmAddress: null, callStack: [] }),
  
  loadPdbData: (pdb) => {
    console.log('[DebugStore] 📋 Loaded .pdb:', pdb);
    set({ pdbData: pdb }); // the breakpoint sync (debug/breakpointSync.ts) follows the store
  },

  // Breakpoints reach the emulator through ONE path, debug/breakpointSync.ts, which
  // maps every file's lines with the .pdb's per-file maps (debug/pdbSource.ts).
  syncBreakpointsToWasm: (_pdb: PdbData, _breakpoints: Record<string, number[]>) => {
    syncEmulatorBreakpoints();
  },
  
  updateCallStack: (stack) => {
    // The first stop with a stack opens the Call Stack panel (once a session: closed
    // again, it stays closed)
    if (stack.length && !callStackShown) {
      callStackShown = true;
      try { ensureComponent('callstack'); } catch { /* no dock (tests) */ }
    }
    set({ callStack: stack });
  },
  updateStats: (cycles, fps, drawFps) => set({ cycles, currentFps: fps, ...(drawFps === undefined ? {} : { drawFps }) }),
  
  // Debug controls
  run: () => {
    console.log('[DebugStore] Run');
    set({ state: 'running' });
    window.postMessage({ type: 'debug-continue' }, '*');
  },
  
  pause: () => {
    console.log('[DebugStore] Pause');
    set({ state: 'paused' });
    window.postMessage({ type: 'debug-pause' }, '*');
  },
  
  stop: () => {
    console.log('[DebugStore] Stop');
    set({
      state: 'stopped',
      currentVpyLine: null,
      currentVpyFile: null,
      currentAsmAddress: null,
      callStack: [],
      cycles: 0
    });
    window.postMessage({ type: 'debug-stop' }, '*');
  },
  
  stepOver: () => {
    console.log('[DebugStore] Step Over');
    const { pdbData, currentVpyLine } = get();
    
    if (!pdbData || currentVpyLine === null) return;
    
    const nextLine = currentVpyLine + 1;
    const nextAddress = pdbData.lineMap[nextLine.toString()];
    
    if (nextAddress) {
      window.postMessage({ 
        type: 'debug-step-over',
        targetAddress: nextAddress
      }, '*');
    }
  },
  
  stepInto: () => {
    console.log('[DebugStore] Step Into');
    const { pdbData, currentVpyLine } = get();
    
    if (!pdbData || currentVpyLine === null) return;
    
    const nativeCall = pdbData.nativeCalls?.[currentVpyLine.toString()];
    
    window.postMessage({ 
      type: 'debug-step-into',
      isNativeCall: !!nativeCall,
      functionName: nativeCall
    }, '*');
  },
  
  stepOut: () => {
    console.log('[DebugStore] Step Out');
    window.postMessage({ type: 'debug-step-out' }, '*');
  },
  
  // Breakpoint synchronization (the editor store changes first; this is a nudge)
  onBreakpointAdded: (_uri, _line) => {
    syncEmulatorBreakpoints();
  },

  onBreakpointRemoved: (_uri, _line) => {
    syncEmulatorBreakpoints();
  }
}));
