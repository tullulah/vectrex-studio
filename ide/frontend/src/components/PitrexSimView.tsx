import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useJoystickStore } from '../state/joystickStore';

/*
 * PitrexSimView — runs an external project's WASM "simulator" module in the
 * emulator panel. The module speaks the PiTrex host SDK contract (see
 * ide/electron/resources/pitrex-sim/): it calls back into `Module.pitrex.*`
 * for drawing, input, time and sound, and yields once per frame at
 * v_WaitRecal() via Asyncify (emscripten_sleep). NOTHING here is
 * game-specific — the view only knows a module path + the SDK contract.
 *
 * The module is a MODULARIZE emscripten build (default EXPORT_NAME
 * `createDoomModule`, but the real name is read from the emitted JS). It is
 * loaded WITHOUT any file:// fetch: we read the .js as text and the sibling
 * .wasm / .data by path (Electron IPC), then hand the bytes to the factory via
 * `wasmBinary` + `getPreloadedPackage`.
 */

// ── PiTrex vector space → canvas mapping ────────────────────────────────────
// v_directDraw32 emits coordinates roughly in x:[-18000,18000], y:[-24000,24000]
// with +Y pointing UP (Vectrex convention). Canvas has +Y pointing DOWN, so Y
// is flipped. Aspect 36000:48000 == 3:4 (portrait), matching the Vectrex tube.
const PITREX_X_RANGE = 18000; // half-width
const PITREX_Y_RANGE = 24000; // half-height
const INTERNAL_W = 330;
const INTERNAL_H = 440;
const DEBUG_INPUT = false;    // draw a live controller-state readout (diagnostic)

interface Segment { x0: number; y0: number; x1: number; y1: number; b: number; }

// Vectrex controller state fed back to the WASM via Module.pitrex hooks.
interface ControllerState {
  buttons: number; // bit0..bit3 = button 1..4 (active-high)
  joyX: number;    // -127..127
  joyY: number;    // -127..127  (+ = up/forward)
}

function base64ToArrayBuffer(b64: string): ArrayBuffer {
  const bin = atob(b64);
  const len = bin.length;
  const bytes = new Uint8Array(len);
  for (let i = 0; i < len; i++) bytes[i] = bin.charCodeAt(i);
  return bytes.buffer;
}

export interface PitrexSimViewProps {
  /** Absolute path to the emitted MODULARIZE loader (.js). Siblings .wasm/.data
   *  are derived by replacing the extension. */
  modulePath: string;
  /** CSS display size (px). */
  width: number;
  height: number;
  /** Optional stdout/stderr sink (build/runtime log lines). */
  onLog?: (line: string) => void;
}

export const PitrexSimView: React.FC<PitrexSimViewProps> = ({ modulePath, width, height, onLog }) => {
  const { t } = useTranslation();
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const [state, setState] = useState<'loading' | 'running' | 'error'>('loading');
  const [errorMsg, setErrorMsg] = useState<string>('');

  // Live refs read by the JS hooks each frame.
  const controllerRef = useRef<ControllerState>({ buttons: 0, joyX: 0, joyY: 0 });
  const keysRef = useRef<Record<string, boolean>>({});      // live keyboard state
  const keyDbgRef = useRef({ n: 0, last: '-' }); // DEBUG: raw keydown counter

  // Merge keyboard + physical gamepad (HTML5 Gamepad API, honouring the IDE's
  // joystick config) into the controller state the game reads. Called on every
  // key event and once per frame (so a plugged-in gamepad is polled live).
  const pollInput = useCallback(() => {
    const keys = keysRef.current;
    let x = 0, y = 0, buttons = 0;
    if (keys['ArrowLeft'] || keys['KeyA']) x -= 127;
    if (keys['ArrowRight'] || keys['KeyD']) x += 127;
    if (keys['ArrowUp'] || keys['KeyW']) y += 127;   // +Y = up
    if (keys['ArrowDown'] || keys['KeyS']) y -= 127;
    if (keys['KeyZ']) buttons |= 0x01;
    if (keys['KeyX']) buttons |= 0x02;
    if (keys['KeyC']) buttons |= 0x04;
    if (keys['KeyV']) buttons |= 0x08;

    try {
      const cfg = useJoystickStore.getState();
      const pads = navigator.getGamepads ? navigator.getGamepads() : [];
      // Use the configured pad, or fall back to the first connected one so a
      // plugged-in controller works without prior setup.
      let gp = (cfg.gamepadIndex != null ? pads[cfg.gamepadIndex] : null) || null;
      if (!gp) { for (const p of pads) { if (p && p.connected) { gp = p; break; } } }
      if (gp && gp.connected) {
        const dz = cfg.deadzone ?? 0.15;
        const dead = (v: number) => (Math.abs(v) < dz ? 0 : v);
        const gx = dead(gp.axes[cfg.axisXIndex ?? 0] || 0) * (cfg.axisXInverted ? -1 : 1);
        const gy = dead(gp.axes[cfg.axisYIndex ?? 1] || 0) * (cfg.axisYInverted ? -1 : 1);
        const dL = gp.buttons[cfg.dpadLeftButton]?.pressed;
        const dR = gp.buttons[cfg.dpadRightButton]?.pressed;
        const dU = gp.buttons[cfg.dpadUpButton]?.pressed;
        const dD = gp.buttons[cfg.dpadDownButton]?.pressed;
        if (dL) x = -127; else if (dR) x = 127; else if (gx) x = Math.round(gx * 127);
        // Match the 6809 emulator's convention: axis * 127 with the user's
        // axisYInverted config (no extra negation), so both cores behave the
        // same for a given joystick setup.
        if (dU) y = 127; else if (dD) y = -127; else if (gy) y = Math.round(gy * 127);
        const maps = cfg.buttonMappings && cfg.buttonMappings.length
          ? cfg.buttonMappings
          : [{ vectrexButton: 1, gamepadButton: 0 }, { vectrexButton: 2, gamepadButton: 1 },
             { vectrexButton: 3, gamepadButton: 2 }, { vectrexButton: 4, gamepadButton: 3 }];
        maps.forEach((m) => { if (gp!.buttons[m.gamepadButton]?.pressed) buttons |= (1 << (m.vectrexButton - 1)); });
      }
    } catch { /* no gamepad */ }

    controllerRef.current = { joyX: x, joyY: y, buttons };
  }, []);
  const segmentsRef = useRef<Segment[]>([]);
  const disposedRef = useRef<boolean>(false);
  const startMsRef = useRef<number>(Date.now());
  const moduleRef = useRef<any>(null);
  // AY-3-8910 audio on an AudioWorklet (audio thread — a synth stall can't
  // freeze the UI). Holds { ctx, node, resume } once set up.
  const audioRef = useRef<any>(null);
  // Digitised-sample audio (e.g. AAE Sega-G80). `samplesRef` holds one decoded
  // AudioBuffer per bank index (from samples/samples.json, order = the game's
  // sample index); `voiceNodesRef` maps a mixing voice → its live source node.
  const samplesRef = useRef<(AudioBuffer | null)[]>([]);
  const voiceNodesRef = useRef<Map<number, AudioBufferSourceNode>>(new Map());
  const log = useRef(onLog);
  log.current = onLog;

  // ── Keyboard → Vectrex controller ─────────────────────────────────────────
  // Mirrors the IDE's existing digital mapping (inputManager): arrows / WASD
  // for the stick, Z X C V for the 4 face buttons (bit0..3). +Y is up/forward.
  // Listeners attach on `document` with capture:true so IDE / Monaco shortcuts
  // don't swallow the keys first. This is a generic Vectrex-controller mapping,
  // not tied to any particular game.
  useEffect(() => {
    const isGameKey = (code: string) =>
      code === 'ArrowLeft' || code === 'ArrowRight' || code === 'ArrowUp' || code === 'ArrowDown' ||
      code === 'KeyA' || code === 'KeyD' || code === 'KeyW' || code === 'KeyS' ||
      code === 'KeyZ' || code === 'KeyX' || code === 'KeyC' || code === 'KeyV';
    const down = (e: KeyboardEvent) => {
      keyDbgRef.current.n++;              // DEBUG: count every keydown reaching us
      keyDbgRef.current.last = e.code;
      if (!isGameKey(e.code)) return;
      keysRef.current[e.code] = true;
      e.preventDefault();
      pollInput();
    };
    const up = (e: KeyboardEvent) => {
      if (!isGameKey(e.code)) return;
      keysRef.current[e.code] = false;
      pollInput();
    };
    window.addEventListener('keydown', down, { capture: true });
    window.addEventListener('keyup', up, { capture: true });
    return () => {
      window.removeEventListener('keydown', down, { capture: true } as any);
      window.removeEventListener('keyup', up, { capture: true } as any);
    };
  }, [pollInput]);

  // ── Load + instantiate the WASM module ────────────────────────────────────
  useEffect(() => {
    disposedRef.current = false;
    segmentsRef.current = [];
    startMsRef.current = Date.now();
    setState('loading');
    setErrorMsg('');

    let cancelled = false;

    const draw = (segs: Segment[]) => {
      const canvas = canvasRef.current;
      if (!canvas) return;
      const ctx = canvas.getContext('2d');
      if (!ctx) return;
      const W = canvas.width, H = canvas.height;
      ctx.fillStyle = '#000';
      ctx.fillRect(0, 0, W, H);
      ctx.lineWidth = 1;
      ctx.lineCap = 'round';
      const sx = (x: number) => (x + PITREX_X_RANGE) / (2 * PITREX_X_RANGE) * W;
      const sy = (y: number) => (PITREX_Y_RANGE - y) / (2 * PITREX_Y_RANGE) * H; // Y flipped
      for (const s of segs) {
        const alpha = Math.max(0, Math.min(1, s.b / 127));
        if (alpha <= 0) continue;
        // Phosphor-green vector stroke, intensity scaled by brightness.
        ctx.strokeStyle = `rgba(255,255,255,${alpha})`;
        ctx.beginPath();
        ctx.moveTo(sx(s.x0), sy(s.y0));
        ctx.lineTo(sx(s.x1), sy(s.y1));
        ctx.stroke();
      }
      // DEBUG: live controller state the game reads (flip DEBUG_INPUT off later).
      if (DEBUG_INPUT) {
        const c = controllerRef.current;
        const k = keyDbgRef.current;
        ctx.fillStyle = '#3f6';
        ctx.font = '11px monospace';
        ctx.fillText(`J ${c.joyX},${c.joyY} B ${c.buttons.toString(2).padStart(4, '0')} k:${k.n} ${k.last}`, 4, 12);
      }
    };

    // The Module.pitrex contract implemented by sdk_host.c. Every hook is a
    // no-op once disposed; `present` additionally throws a sentinel so the
    // Asyncify main loop unwinds and stops (swallowed in the callMain catch).
    const pitrex = {
      drawLine: (x0: number, y0: number, x1: number, y1: number, b: number) => {
        if (disposedRef.current) return;
        segmentsRef.current.push({ x0, y0, x1, y1, b });
      },
      present: () => {
        if (disposedRef.current) throw 'pitrex-sim-disposed';
        pollInput();   // poll the physical gamepad once per frame (live)
        const segs = segmentsRef.current;
        segmentsRef.current = [];
        draw(segs);
      },
      readButtons: () => controllerRef.current.buttons,
      joyX: () => controllerRef.current.joyX,
      joyY: () => controllerRef.current.joyY,
      millis: () => (Date.now() - startMsRef.current) | 0,
      // Audio: forward AY-3-8910 register writes to the AudioWorklet synth.
      soundAY: (reg: number, val: number) => {
        if (disposedRef.current) return;
        const a = audioRef.current;
        if (a) a.node.port.postMessage({ type: 'reg', reg: reg & 0x0f, val: val & 0xff });
      },
      // Digitised-sample audio: play bank[idx] on mixing voice `voice` (Web Audio
      // mixes voices for us). Retriggering a voice stops its previous node.
      playSample: (idx: number, voice: number, loop: number) => {
        if (disposedRef.current) return;
        const a = audioRef.current;
        const buf = samplesRef.current[idx];
        if (!a || !buf) return;
        const prev = voiceNodesRef.current.get(voice);
        if (prev) { try { prev.stop(); } catch { /* already stopped */ } }
        const src = a.ctx.createBufferSource();
        src.buffer = buf;
        src.loop = !!loop;
        src.connect(a.ctx.destination);
        src.onended = () => { if (voiceNodesRef.current.get(voice) === src) voiceNodesRef.current.delete(voice); };
        try { src.start(); } catch { /* ctx not running yet */ }
        voiceNodesRef.current.set(voice, src);
      },
      stopSample: (voice: number) => {
        const n = voiceNodesRef.current.get(voice);
        if (n) { try { n.stop(); } catch { /* already stopped */ } voiceNodesRef.current.delete(voice); }
      },
      samplePlaying: (voice: number) => (voiceNodesRef.current.has(voice) ? 1 : 0),
    };

    (async () => {
      try {
        // Set up AY-3-8910 audio on an AudioWorklet (audio thread). Best-effort:
        // failure here must never block the game from loading.
        try {
          const AC = (window as any).AudioContext || (window as any).webkitAudioContext;
          if (AC) {
            const ctx = new AC({ sampleRate: 44100 });
            const workletUrl = new URL('ay8910-worklet.js', document.baseURI).href;
            await ctx.audioWorklet.addModule(workletUrl);
            if (!cancelled && !disposedRef.current) {
              const node = new AudioWorkletNode(ctx, 'ay8910', {
                numberOfInputs: 0, numberOfOutputs: 1, outputChannelCount: [1],
              });
              node.connect(ctx.destination);
              // Browsers gate audio until a real mouse/keyboard/touch gesture —
              // GAMEPAD input does NOT qualify, so a pad-only player hears nothing
              // until they click/key once. Listen on ALL gesture types (capture,
              // on window) so any interaction unlocks it.
              const resume = () => { if (ctx.state !== 'running') ctx.resume().catch(() => {}); };
              const evts = ['keydown', 'pointerdown', 'mousedown', 'click', 'touchstart'];
              evts.forEach((e) => window.addEventListener(e, resume, { capture: true }));
              audioRef.current = { ctx, node, resume, evts };
            } else {
              ctx.close?.();
            }
          }
        } catch (e: any) {
          log.current?.(`[PiTrex simulator] audio unavailable: ${e?.message || e}`);
        }

        const files = (window as any).files;
        if (!files?.readFile || !files?.readFileBin) {
          throw new Error('file IPC unavailable');
        }

        // Optional digitised samples: <project>/samples/samples.json lists the
        // .wav files in the game's bank-index order. Decode them (best-effort —
        // a game with no samples just runs silent). The module lives in
        // <project>/build_wasm/, so the samples dir is a sibling two levels up.
        try {
          const a = audioRef.current;
          const samplesDir = modulePath.replace(/\/build_wasm\/[^/]+$/, '/samples');
          if (a && samplesDir !== modulePath) {
            const manifest = await files.readFile(`${samplesDir}/samples.json`).catch(() => null);
            if (manifest && !manifest.error && typeof manifest.content === 'string') {
              const names: string[] = JSON.parse(manifest.content);
              const bufs = await Promise.all(names.map(async (n) => {
                const r = await files.readFileBin(`${samplesDir}/${n}`).catch(() => null);
                if (!r || r.error || !r.base64) return null;
                const bytes = Uint8Array.from(atob(r.base64), (c) => c.charCodeAt(0));
                return await a.ctx.decodeAudioData(bytes.buffer).catch(() => null);
              }));
              if (!cancelled && !disposedRef.current) {
                samplesRef.current = bufs;
                log.current?.(`[PiTrex simulator] loaded ${bufs.filter(Boolean).length}/${names.length} samples`);
              }
            }
          }
        } catch (e: any) {
          log.current?.(`[PiTrex simulator] samples unavailable: ${e?.message || e}`);
        }

        const base = modulePath.replace(/\.js$/i, '');
        const wasmPath = `${base}.wasm`;
        const dataPath = `${base}.data`;

        const jsRes = await files.readFile(modulePath);
        if (!jsRes || jsRes.error || typeof jsRes.content !== 'string') {
          throw new Error(`cannot read loader ${modulePath}: ${jsRes?.error || 'no content'}`);
        }
        const wasmRes = await files.readFileBin(wasmPath);
        if (!wasmRes || wasmRes.error || !wasmRes.base64) {
          throw new Error(`cannot read wasm ${wasmPath}: ${wasmRes?.error || 'no bytes'}`);
        }
        const wasmBinary = base64ToArrayBuffer(wasmRes.base64);

        // .data is only present when the module was built with --preload-file.
        // Absent is fine (no getPreloadedPackage call will happen).
        let dataBuffer: ArrayBuffer | null = null;
        const dataRes = await files.readFileBin(dataPath).catch(() => null);
        if (dataRes && !dataRes.error && dataRes.base64) {
          dataBuffer = base64ToArrayBuffer(dataRes.base64);
        }

        if (cancelled) return;

        // Turn the MODULARIZE text into the factory. The emitted JS ends with
        //   var <NAME>=(()=>{ ... })();
        // followed by a CommonJS/AMD export tail that is inert inside a
        // `new Function` scope (typeof exports/module/define are "undefined").
        // We read <NAME> from the source rather than hardcoding it, then return
        // it from the wrapper.
        const jsText: string = jsRes.content;
        const m = jsText.match(/var\s+([A-Za-z_$][\w$]*)\s*=\s*\(\s*\(\s*\)\s*=>/);
        const exportName = m ? m[1] : 'createDoomModule';
        // eslint-disable-next-line no-new-func
        const factory = new Function(`${jsText}\n;return ${exportName};`)();
        if (typeof factory !== 'function') {
          throw new Error(`module factory "${exportName}" not found in ${modulePath}`);
        }

        const moduleArg: any = {
          pitrex,
          // Instantiate the wasm from our own bytes. This is the definitive hook
          // (doom.js: `if (Module.instantiateWasm) …`) and short-circuits emscripten's
          // fetch/streaming path — which, under the Vite/Electron origin, would
          // otherwise resolve the .wasm URL to index.html and fail with a bad
          // magic word. `wasmBinary` alone is not honoured here.
          instantiateWasm: (imports: any, done: (inst: any) => void) => {
            WebAssembly.instantiate(wasmBinary, imports)
              .then((output: any) => done(output.instance))
              .catch((err: any) => {
                if (!disposedRef.current) log.current?.(`[PiTrex simulator] wasm instantiate failed: ${err?.message || err}`);
              });
            return {}; // signal async instantiation
          },
          locateFile: (p: string) => p,
          print: (line: string) => log.current?.(line),
          printErr: (line: string) => log.current?.(line),
          // Supply the --preload-file package bytes so it isn't fetched either.
          getPreloadedPackage: (_name: string, _size: number) => dataBuffer,
          // Built with -sINVOKE_RUN=0: we drive main() ourselves below.
          noInitialRun: true,
        };

        const instance = await factory(moduleArg);
        if (cancelled || disposedRef.current) return;
        moduleRef.current = instance;
        setState('running');
        log.current?.('[PiTrex simulator] module ready — starting main()');

        // main() loops forever, yielding each frame at v_WaitRecal (Asyncify).
        // The returned promise never resolves under normal play; it only
        // settles when we dispose (present() throws the sentinel) or the
        // program aborts. Swallow the sentinel; surface real errors.
        Promise.resolve(instance.callMain([])).catch((e: any) => {
          if (e === 'pitrex-sim-disposed') return;
          if (!disposedRef.current) {
            const msg = e?.message || String(e);
            log.current?.(`[PiTrex simulator] stopped: ${msg}`);
          }
        });
      } catch (e: any) {
        if (cancelled) return;
        const msg = e?.message || String(e);
        setErrorMsg(msg);
        setState('error');
        log.current?.(`[PiTrex simulator] load failed: ${msg}`);
      }
    })();

    return () => {
      cancelled = true;
      // Signal the hooks to no-op and unwind the Asyncify loop on the next
      // present(). The module instance is then dropped for GC.
      disposedRef.current = true;
      moduleRef.current = null;
      // Tear down the AY worklet + its AudioContext so repeated Build & Run
      // doesn't leak audio nodes.
      try {
        voiceNodesRef.current.forEach((n) => { try { n.stop(); } catch { /* ignore */ } });
        voiceNodesRef.current.clear();
        samplesRef.current = [];
        const a = audioRef.current;
        if (a) {
          (a.evts || []).forEach((e: string) => window.removeEventListener(e, a.resume, { capture: true } as any));
          a.node?.disconnect?.();
          a.ctx?.close?.();
        }
      } catch { /* ignore */ }
      audioRef.current = null;
    };
  }, [modulePath, pollInput]);

  return (
    <div style={{ position: 'relative', display: 'inline-block' }}>
      <canvas
        ref={canvasRef}
        width={INTERNAL_W}
        height={INTERNAL_H}
        style={{
          border: '1px solid #333',
          background: '#000',
          width,
          height,
          display: 'block',
        }}
      />
      {state !== 'running' && (
        <div style={{
          position: 'absolute', top: 0, left: 0, width, height,
          display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
          gap: '8px', background: 'rgba(10,10,10,0.85)', pointerEvents: 'none',
          fontFamily: 'monospace',
        }}>
          {state === 'loading' && (
            <>
              <span style={{ fontSize: '22px' }}>🕹️</span>
              <span style={{ color: '#ccc', fontSize: '12px' }}>
                {t('pitrexSim.loading', 'Loading PiTrex simulator…')}
              </span>
            </>
          )}
          {state === 'error' && (
            <>
              <span style={{ fontSize: '22px' }}>⚠️</span>
              <span style={{ color: '#f88', fontSize: '12px' }}>
                {t('pitrexSim.error', 'Simulator failed to load')}
              </span>
              <span style={{ color: '#888', fontSize: '10px', maxWidth: '90%', textAlign: 'center' }}>
                {errorMsg}
              </span>
            </>
          )}
        </div>
      )}
    </div>
  );
};

export default PitrexSimView;
