import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export type CompilerBackend = 'buildtools' | 'core';
export type BuildTarget = 'm6809' | 'rp2350' | 'pitrex' | 'uvm2';
export type Rp2350FlashMethod = 'none' | 'swd' | 'usb';
export type Rp2350BuildMode = 'flash' | 'sd';

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
  /* PERILLAS DE COMPILACION DEL UVM2, para poder hacer VARIAS builds y compararlas en la
   * CONSOLA. El emulador no basta: hay cosas que se ven bien ahi y mal en el tubo.
   *
   * Se pasan como variables de `make` al final de la orden de build, asi que valen para
   * cualquier proyecto uvm2 con Makefile (el juego, los bancos de prueba, los VPy).
   * El DEFECTO no cambia: doble nucleo + PIO + DMA sigue siendo la base de medida. */
  uvm2DualCore: boolean;
  setUvm2DualCore: (value: boolean) => void;
  uvm2PioStream: boolean;
  setUvm2PioStream: (value: boolean) => void;
  uvm2Hz: string;
  setUvm2Hz: (value: string) => void;
  uvm2ExtraFlags: string;
  setUvm2ExtraFlags: (value: string) => void;
  rp2350FlashMethod: Rp2350FlashMethod;
  setRp2350FlashMethod: (method: Rp2350FlashMethod) => void;
  rp2350FirmwareDir: string;
  setRp2350FirmwareDir: (path: string) => void;
  rp2350SdPath: string;
  setRp2350SdPath: (path: string) => void;
  rp2350BuildMode: Rp2350BuildMode;
  setRp2350BuildMode: (mode: Rp2350BuildMode) => void;
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
      uvm2DualCore: true,
      setUvm2DualCore: (uvm2DualCore) => set({ uvm2DualCore }),
      uvm2PioStream: true,
      setUvm2PioStream: (uvm2PioStream) => set({ uvm2PioStream }),
      uvm2Hz: '',
      setUvm2Hz: (uvm2Hz) => set({ uvm2Hz }),
      uvm2ExtraFlags: '',
      setUvm2ExtraFlags: (uvm2ExtraFlags) => set({ uvm2ExtraFlags }),
      rp2350FlashMethod: 'none',
      setRp2350FlashMethod: (rp2350FlashMethod) => set({ rp2350FlashMethod }),
      rp2350FirmwareDir: DEFAULT_RP2350_FIRMWARE_DIR,
      setRp2350FirmwareDir: (rp2350FirmwareDir) => set({ rp2350FirmwareDir }),
      rp2350SdPath: '',
      setRp2350SdPath: (rp2350SdPath) => set({ rp2350SdPath }),
      rp2350BuildMode: 'flash',
      setRp2350BuildMode: (rp2350BuildMode) => set({ rp2350BuildMode }),
    }),
    {
      name: 'vpy-settings',
    }
  )
);

/* LAS PERILLAS DEL UVM2, COMPUESTAS EN UN SOLO SITIO.
 *
 * La usan el panel (para enseñar lo que se va a ejecutar) y los DOS lanzadores. Si cada
 * uno la compusiera por su cuenta, el panel diria una cosa y la build haria otra.
 *
 * SE EMITEN SIEMPRE LAS DOS, con su 0 o su 1 explicito. Emitir "solo lo que se aparta del
 * defecto" parecia limpio y es una trampa doble: el caso vacio es indistinguible de "los
 * flags no llegaron", y ademas EL DEFECTO NO ES EL MISMO EN LOS DOS CAMINOS —
 *
 *   make uvm2   (proyectos con Makefile)  -> doble nucleo SI, PIO SI
 *   vpy_cli     (proyectos .vpyproj)      -> doble nucleo NO, PIO NO
 *
 * ...asi que la misma cadena significaba cosas opuestas segun quien compilara. Medido el
 * 2026-08-25: cuatro .um2 de VPy con nombres distintos y el MISMO md5.
 *
 * `make` acepta `NOMBRE=valor` en la linea de ordenes y `vpy_cli` las lee del ENTORNO, con
 * los mismos nombres; por eso una sola cadena sirve para los dos. */
export function uvm2MakeFlags(s: {
  uvm2DualCore: boolean; uvm2PioStream: boolean; uvm2Hz: string; uvm2ExtraFlags: string;
}): string {
  const v: string[] = [
    `UVM2_DUAL_CORE=${s.uvm2DualCore ? 1 : 0}`,
    `UVM2_PIO_STREAM=${s.uvm2PioStream ? 1 : 0}`,
  ];
  const hz = (s.uvm2Hz || '').trim();
  if (hz !== '' && /^\d+$/.test(hz)) v.push(`UVM2_HZ=${hz}`);
  const extra = (s.uvm2ExtraFlags || '').trim();
  if (extra) v.push(extra);
  return v.join(' ');
}
