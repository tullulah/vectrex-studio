import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export type CompilerBackend = 'buildtools' | 'core';
export type BuildTarget = 'm6809' | 'rp2350' | 'pitrex' | 'uvm2';

interface SettingsState {
  compiler: CompilerBackend;
  setCompiler: (compiler: CompilerBackend) => void;
  buildTarget: BuildTarget;
  setBuildTarget: (target: BuildTarget) => void;
  pitrexCopyToSD: boolean;
  setPitrexCopyToSD: (value: boolean) => void;
  pitrexSdPath: string;
  setPitrexSdPath: (path: string) => void;
  uvm2CopyToSD: boolean;
  setUvm2CopyToSD: (value: boolean) => void;
  uvm2SdPath: string;
  setUvm2SdPath: (path: string) => void;
}

export const useSettings = create<SettingsState>()(
  persist(
    (set) => ({
      compiler: 'buildtools',
      setCompiler: (compiler) => set({ compiler }),
      buildTarget: 'm6809',
      setBuildTarget: (buildTarget) => set({ buildTarget }),
      pitrexCopyToSD: false,
      setPitrexCopyToSD: (pitrexCopyToSD) => set({ pitrexCopyToSD }),
      pitrexSdPath: '',
      setPitrexSdPath: (pitrexSdPath) => set({ pitrexSdPath }),
      uvm2CopyToSD: false,
      setUvm2CopyToSD: (uvm2CopyToSD) => set({ uvm2CopyToSD }),
      uvm2SdPath: '',
      setUvm2SdPath: (uvm2SdPath) => set({ uvm2SdPath }),
    }),
    {
      name: 'vpy-settings',
    }
  )
);
