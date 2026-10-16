/**
 * Renderer half of the MCP bridge (ide/frontend/src/services/mcpBridge.ts), run in Node:
 * setBuildTarget through the settings store, and runBuild — the awaited F7/F5/Shift+F5 —
 * observing the emulator store the way EmulatorPanel / PitrexSimView feed it, and
 * capturing only its own build output. Bundled with the frontend's esbuild by run-tests.js.
 */
import { listeners } from './fake-window';
import { registerBuildRunner } from '../../../frontend/src/services/mcpBridge';
import { useEmulatorStore } from '../../../frontend/src/state/emulatorStore';
import { useSettings } from '../../../frontend/src/state/settingsStore';

const assert = (c: any, m: string) => { if (!c) { console.error('FAIL', m); process.exit(1); } else console.log('ok  ', m); };
const inv = (fn: string, args: any = {}) => (globalThis as any).__mcpBridge__.invoke(fn, args);

(async () => {
  listeners.out?.('old output from before\n');
  // Panel mounted, as EmulatorPanel does.
  useEmulatorStore.getState().setPanelMounted(true);

  // 1) setBuildTarget goes through the settings store
  let r = await inv('setBuildTarget', { target: 'rp2350' });
  assert(r.ok && r.value.buildTarget === 'rp2350' && useSettings.getState().buildTarget === 'rp2350', 'setBuildTarget writes the settings store');
  r = await inv('setBuildTarget', { target: 'nes' });
  assert(!r.ok && /Unknown build target/.test(r.error), 'setBuildTarget rejects unknown targets');

  // 2) runBuild without a registered runner
  r = await inv('runBuild', { mode: 'run' });
  assert(!r.ok && /not ready/.test(r.error), 'runBuild fails cleanly before main.tsx registers the runner');

  // 3) C rp2350 run: output captured, load observed
  const unregister = registerBuildRunner(async (mode) => {
    listeners.out?.('[C] $ make rp2350\n');
    listeners.err?.('ld: warning: RWX\n');
    listeners.status?.('Built hello_c');
    setTimeout(() => useEmulatorStore.getState().noteLoad({ backend: 'rp2350', binPath: '/p/build_rp2350/hello_c_sd.bin', ok: true }), 100);
    (globalThis as any).emuCore = { _activeTarget: 'rp2350' };
    const { useDebugStore } = await import('../../../frontend/src/state/debugStore');
    useDebugStore.getState().setState('running');
    return { ok: true, project: 'c', target: 'rp2350', artifact: '/p/build_rp2350/hello_c_sd.bin', launch: 'emulator', notes: [] };
  });
  r = await inv('runBuild', { mode: 'run' });
  assert(r.ok, 'runBuild run resolves: ' + (r.error || ''));
  const v = r.value;
  assert(v.ok && v.target === 'rp2350' && v.emulator.backend === 'rp2350' && v.emulator.running === true, 'reports the RP2350 emulator running');
  assert(v.emulatorWait && v.emulatorWait.timedOut === false, 'waited for the load and saw it');
  assert(v.output.includes('[C] $ make rp2350') && v.output.includes('ld: warning') && v.output.includes('[status] Built hello_c'), 'output of this build captured');
  assert(!v.output.includes('old output'), 'output from before the build is excluded');

  // 4) simulate: sim status published by PitrexSimView
  unregister();
  registerBuildRunner(async () => {
    useEmulatorStore.getState().setSimModule('/p/build_wasm/hello_c.js');
    const nonce = useEmulatorStore.getState().simModuleNonce;
    setTimeout(() => useEmulatorStore.getState().setSimStatus({ nonce, state: 'loading' }), 20);
    setTimeout(() => useEmulatorStore.getState().setSimStatus({ nonce, state: 'running' }), 150);
    return { ok: true, project: 'c', target: 'sim', artifact: '/p/build_wasm/hello_c.js', launch: 'sim', notes: [] };
  });
  r = await inv('runBuild', { mode: 'simulate' });
  assert(r.ok && r.value.emulator.backend === 'sim' && r.value.emulator.running && r.value.emulator.simulator.state === 'running', 'simulate reports the WASM simulator running');

  // 5) failure passes through
  registerBuildRunner(async () => ({ ok: false, project: 'vpy', target: 'm6809', launch: 'none', error: 'compile_failed', stderr: 'error 3:1 - boom' }));
  r = await inv('runBuild', { mode: 'build' });
  assert(r.ok && r.value.ok === false && r.value.error === 'compile_failed' && r.value.emulatorWait === null, 'failure outcome returned as data');

  // 6) panel closed + run: tries to open it, reports the note
  useEmulatorStore.getState().setPanelMounted(false);
  registerBuildRunner(async () => ({ ok: true, project: 'vpy', target: 'pitrex', launch: 'none', notes: [] }));
  r = await inv('runBuild', { mode: 'run' });
  assert(r.ok && r.value.notes.some((n: string) => /Emulator panel is not open/.test(n)), 'reports when the Emulator panel cannot be opened');

  r = await inv('runBuild', { mode: 'flash' });
  assert(!r.ok && /Unknown mode/.test(r.error), 'unknown mode rejected');
  console.log('ALL OK');
  process.exit(0);
})();
