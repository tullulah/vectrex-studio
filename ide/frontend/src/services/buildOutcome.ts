/**
 * What one Build / Run (F7, F5, Shift+F5, Shift+F7) did — returned by handleBuild in
 * main.tsx so callers that need the result (the MCP bridge's runBuild) do not have to
 * scrape the log. The keys themselves ignore it.
 */
export type BuildMode = 'build' | 'run' | 'simulate' | 'build_simulator';

export interface BuildOutcome {
  ok: boolean;
  /** The project kind that was built: VPy project, C/C++ .cvproj, or a loose .vpy file. */
  project: 'vpy' | 'c' | 'file' | null;
  /** Hardware target built, or 'sim' for the WASM simulator. */
  target: 'm6809' | 'rp2350' | 'pitrex' | 'uvm2' | 'sim' | null;
  /** Produced file: .bin/.um2/kernel image, or the simulator's .js loader. */
  artifact?: string | null;
  size?: number;
  /**
   * How the result reaches the Emulator panel:
   *   'emulator' — emu://compiledBin was sent (6809 JSVecX, RP2350, UVM2 or PiTrex interpreter)
   *   'sim'      — the WASM simulator module was handed to the panel
   *   'none'     — nothing to run (SD build, PiTrex kernel, failure)
   */
  launch: 'emulator' | 'sim' | 'none';
  /** Machine-readable failure code (compile_failed, build_failed, busy, ...). */
  error?: string;
  /** Human-readable detail for `error`. */
  detail?: string;
  /** Compiler stderr when the IPC returned it (VPy builds). */
  stderr?: string;
  /** Notes the IDE logged about what it chose (e.g. "no [simulate]: built rp2350 instead"). */
  notes?: string[];
}
