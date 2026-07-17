import { create } from 'zustand';
import type { EmulatorState } from '../types/models.js';

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
  setSimModule: (path: string | null) => void;
}

const initial: EmulatorState = { status: 'stopped' };

export const useEmulatorStore = create<EmulatorStore>((set) => ({
  ...initial,
  simModulePath: null,
  simModuleNonce: 0,
  setStatus: (status) => set({ status }),
  setSimModule: (path) => set((s) => ({ simModulePath: path, simModuleNonce: s.simModuleNonce + 1 })),
}));
