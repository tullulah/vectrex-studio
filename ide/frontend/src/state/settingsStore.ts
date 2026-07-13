import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export type CompilerBackend = 'buildtools' | 'core';
export type BuildTarget = 'm6809' | 'rp2350' | 'pitrex' | 'uvm2';
export type Rp2350FlashMethod = 'none' | 'swd' | 'usb';

const DEFAULT_RP2350_FIRMWARE_DIR =
  '/Users/daniel/projects/vectrex-arcade-private/hardware/debug_cart/firmware';

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
  rp2350FlashMethod: Rp2350FlashMethod;
  setRp2350FlashMethod: (method: Rp2350FlashMethod) => void;
  rp2350FirmwareDir: string;
  setRp2350FirmwareDir: (path: string) => void;
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
      rp2350FlashMethod: 'none',
      setRp2350FlashMethod: (rp2350FlashMethod) => set({ rp2350FlashMethod }),
      rp2350FirmwareDir: DEFAULT_RP2350_FIRMWARE_DIR,
      setRp2350FirmwareDir: (rp2350FirmwareDir) => set({ rp2350FirmwareDir }),
    }),
    {
      name: 'vpy-settings',
    }
  )
);
