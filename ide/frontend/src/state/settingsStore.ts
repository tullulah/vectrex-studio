import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export type CompilerBackend = 'buildtools' | 'core';
export type BuildTarget = 'm6809' | 'rp2350';

interface SettingsState {
  compiler: CompilerBackend;
  setCompiler: (compiler: CompilerBackend) => void;
  buildTarget: BuildTarget;
  setBuildTarget: (target: BuildTarget) => void;
}

export const useSettings = create<SettingsState>()(
  persist(
    (set) => ({
      compiler: 'buildtools', // Default to new buildtools compiler
      setCompiler: (compiler) => set({ compiler }),
      buildTarget: 'm6809', // Default target
      setBuildTarget: (buildTarget) => set({ buildTarget }),
    }),
    {
      name: 'vpy-settings', // localStorage key
    }
  )
);
