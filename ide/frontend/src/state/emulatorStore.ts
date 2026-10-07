import { create } from 'zustand';
import type { EmulatorState } from '../types/models.js';

/** Which machine the Emulator panel last loaded a program into. */
export type EmulatorBackend = 'm6809' | 'rp2350' | 'uvm2' | 'pitrex';

/** One program load in the Emulator panel (emu://compiledBin). `seq` grows by one per load. */
export interface EmulatorLoad {
  seq: number;
  backend: EmulatorBackend;
  binPath: string;
  ok: boolean;
  error?: string;
  at: number;
}

/** The WASM simulator (PitrexSimView) for the module of `nonce` (see setSimModule). */
export interface SimStatus {
  nonce: number;
  state: 'loading' | 'running' | 'error';
  error?: string;
}

interface EmulatorStore extends EmulatorState {
  setStatus: (s: EmulatorState['status']) => void;
  // Path to an external project's WASM simulator loader (.js). When set, the
  // emulator panel runs the module via PitrexSimView instead of a Vectrex
  // backend. null = no sim active. Kept target-agnostic (any module speaking
  // the PiTrex host SDK contract).
  simModulePath: string | null;
  // Bumped on every setSimModule call so the panel can force a fresh remount
  // even when the same module path is rebuilt (identical path, new bytes).
  simModuleNonce: number;
  simRomZip?: Uint8Array | null;
  setSimModule: (path: string | null, romZip?: Uint8Array | null) => void;

  // Observability for tools that start a run and must report what actually happened
  // (the MCP bridge's runBuild). Written by EmulatorPanel / PitrexSimView, read-only elsewhere.
  /** True while the Emulator panel is mounted (it is the only consumer of emu://compiledBin). */
  panelMounted: boolean;
  setPanelMounted: (mounted: boolean) => void;
  lastLoad: EmulatorLoad | null;
  noteLoad: (load: Omit<EmulatorLoad, 'seq' | 'at'>) => void;
  simStatus: SimStatus | null;
  setSimStatus: (s: SimStatus) => void;
}

const initial: EmulatorState = { status: 'stopped' };

export const useEmulatorStore = create<EmulatorStore>((set) => ({
  ...initial,
  simModulePath: null,
  simModuleNonce: 0,
  setStatus: (status) => set({ status }),
  simRomZip: null,
  setSimModule: (path, romZip = null) => set((s) => ({ simModulePath: path, simRomZip: romZip, simModuleNonce: s.simModuleNonce + 1 })),
  panelMounted: false,
  setPanelMounted: (panelMounted) => set({ panelMounted }),
  lastLoad: null,
  noteLoad: (load) => set((s) => ({ lastLoad: { ...load, seq: (s.lastLoad?.seq ?? 0) + 1, at: Date.now() } })),
  simStatus: null,
  setSimStatus: (simStatus) => set({ simStatus }),
}));
