/**
 * Keeps the 6809 emulator's breakpoints equal to the editor's, for EVERY file of the
 * program at once (a breakpoint in an imported module counts while another tab is
 * active). Runs whenever the breakpoints, the loaded .pdb or the emulator change.
 */
import { useEditorStore } from '../state/editorStore';
import { useDebugStore } from '../state/debugStore';
import { useProjectStore } from '../state/projectStore';
import { breakpointAddresses } from './pdbSource';

export function syncEmulatorBreakpoints(): void {
  const emu = (window as any).emulatorDebug;
  const pdb = useDebugStore.getState().pdbData;
  if (!emu || !pdb) return;
  // Only this project's files: another project's main.vpy is not this program's
  const root = useProjectStore.getState().vpyProject?.rootDir?.replace(/\\/g, '/');
  const all = useEditorStore.getState().breakpoints || {};
  const mine = root
    ? Object.fromEntries(Object.entries(all).filter(([uri]) => uri.replace(/^file:\/\//, '').startsWith(root + '/')))
    : all;
  const want = breakpointAddresses(pdb as any, mine);
  const have = new Set<number>(emu.getBreakpoints() as number[]);
  for (const a of have) if (!want.has(a)) emu.removeBreakpoint(a);
  for (const a of want) if (!have.has(a)) emu.addBreakpoint(a);
  // A debug session (Ctrl+F5) loads the program and waits here for its breakpoints.
  // Only that wait is started: a pause AT a breakpoint stays paused while the user
  // edits breakpoints.
  const vecx = (window as any).vecx;
  if (vecx?.waitingForBreakpoints) {
    vecx.waitingForBreakpoints = false;
    emu.start?.();
    useDebugStore.getState().setState('running');
  }
}

let installed = false;

export function installBreakpointSync(): void {
  if (installed) return;
  installed = true;
  useEditorStore.subscribe((s, prev) => { if (s.breakpoints !== prev.breakpoints) syncEmulatorBreakpoints(); });
  useDebugStore.subscribe((s, prev) => { if (s.pdbData !== prev.pdbData) syncEmulatorBreakpoints(); });
  useProjectStore.subscribe((s, prev) => { if (s.vpyProject !== prev.vpyProject) syncEmulatorBreakpoints(); });
}
