import React, { useEffect, useRef, useState, useCallback } from 'react';
import { useEmulatorStore, type ActiveEngine } from '../../state/emulatorStore';
import { useEditorStore } from '../../state/editorStore';
import { useEmulatorSettings } from '../../state/emulatorSettings';
import { useDebugStore } from '../../state/debugStore';
import type { PdbData } from '../../state/debugStore';
import { useJoystickStore } from '../../state/joystickStore';
import { useProjectStore } from '../../state/projectStore';
import { useSettings } from '../../state/settingsStore';
import { JoystickConfigDialog } from '../dialogs/JoystickConfigDialog';
import { psgAudio } from '../../psgAudio';
import { inputManager } from '../../inputManager';
import { asmAddressToVpyLine, formatAddress } from '../../utils/debugHelpers';
import { emuCore } from '../../emulatorCoreSingleton';
import { VectorRecorder, serializeVrec, defaultRecordingName, MAX_RECORD_SECONDS, type RawSegment } from '../../emulator/recorder/VectorRecorder';
import { VideoRecorder, defaultVideoName } from '../../emulator/recorder/VideoRecorder';
import { getAllLiveContextOutputs, getOutputsForContext } from '../../emulator/recorder/audioGraphTracker';
import { PitrexSimView, PITREX_RANGE, type Segment as PitrexSegment } from '../PitrexSimView';
import { installBreakpointSync, syncEmulatorBreakpoints } from '../../debug/breakpointSync';
import { baseName, sourceAt, statementAddresses } from '../../debug/pdbSource';

// Helper: Get line->address map for both single-bank and multibank formats
function getLineAddressMap(pdb: PdbData | null): Record<number, number> {
  const result: Record<number, number> = {};
  if (!pdb) return result;
  
  if (pdb.vpyLineMap) {
    // Multibank: hex address string → {file, line, column}
    // NOTE: Keys are stored as decimal strings (e.g., "155" not "0x9B")
    for (const [addr, info] of Object.entries(pdb.vpyLineMap)) {
      // Try parsing as decimal first (current format bug)
      // If it starts with "0x", parse as hex
      const address = addr.startsWith('0x') 
        ? parseInt(addr, 16)
        : parseInt(addr, 10);
      result[info.line] = address;
    }
  } else if (pdb.lineMap) {
    // Single-bank: line → address hex string
    for (const [line, addrHex] of Object.entries(pdb.lineMap)) {
      result[parseInt(line, 10)] = parseInt(addrHex, 16);
    }
  }
  
  return result;
}

/**
 * Show `fileName` (a .vpy base name from the .pdb) at `line` (1-based): this project's
 * open tab of that name — not another project's main.vpy — or the file read from the
 * project's src/.
 */
function showProjectSource(fileName: string, line: number): void {
  const root = useProjectStore.getState().vpyProject?.rootDir?.replace(/\\/g, '/');
  const editorStore = useEditorStore.getState();
  const fsOf = (uri: string) => uri.replace(/^file:\/\//, '');
  const doc = editorStore.documents.find(d =>
    baseName(d.uri) === fileName && (!root || fsOf(d.uri).startsWith(root + '/')));
  if (doc) {
    if (editorStore.active !== doc.uri) editorStore.setActive(doc.uri);
    editorStore.gotoLocation(doc.uri, line - 1, 0);
    return;
  }
  if (!root) { console.warn(`[EmulatorPanel] ⚠️ No project open: cannot show ${fileName}`); return; }
  const fsPath = `${root}/src/${fileName}`;
  const uri = `file://${fsPath}`;
  (window as any).files?.readFile?.(fsPath).then((res: { content?: string; error?: string }) => {
    if (!res || res.error || res.content === undefined) {
      console.warn(`[EmulatorPanel] ⚠️ Could not open ${fsPath}: ${res?.error}`);
      return;
    }
    useEditorStore.getState().openDocument({ uri, content: res.content, language: 'vpy', dirty: false, mtime: Date.now(), diagnostics: [] });
    useEditorStore.getState().gotoLocation(uri, line - 1, 0);
  });
}

// Tipos para JSVecX
interface VecxMetrics {
  totalCycles: number;
  instructionCount: number;
  frameCount: number;
  running: boolean;
}
  
interface VecxRegs {
  PC: number;
  A: number; B: number;
  X: number; Y: number; U: number; S: number;
  DP: number; CC: number;
  BANK?: number;
}

// Componente simple para gráficas de barras
const MiniChart: React.FC<{ 
  label: string; 
  value: number; 
  max: number; 
  color: string; 
  dangerZone?: number;
  unit?: string;
}> = ({ label, value, max, color, dangerZone, unit = '' }) => {
  const percentage = Math.min((value / max) * 100, 100);
  const isDanger = dangerZone && value >= dangerZone;
  const dangerPercentage = dangerZone ? (dangerZone / max) * 100 : 0;
  
  return (
    <div style={{ marginBottom: '8px', position: 'relative' }}>
      <div style={{
        display: 'flex',
        justifyContent: 'space-between',
        fontSize: '9px',
        marginBottom: '2px',
        color: isDanger ? '#ff6666' : '#aaa'
      }}>
        <span style={{ fontWeight: isDanger ? 'bold' : 'normal' }}>
          {label} {isDanger ? '⚠️' : ''}
        </span>
        <span>{value.toLocaleString()}{unit}</span>
      </div>
      <div style={{
        width: '100%',
        height: '14px',
        background: '#2a2a2a',
        borderRadius: '7px',
        overflow: 'hidden',
        border: '1px solid #444',
        position: 'relative'
      }}>
        {/* Zona de peligro de fondo */}
        {dangerZone && (
          <div style={{
            position: 'absolute',
            left: `${dangerPercentage}%`,
            width: `${100 - dangerPercentage}%`,
            height: '100%',
            background: 'rgba(255, 68, 68, 0.15)',
            zIndex: 1
          }} />
        )}
        
        {/* Barra de progreso principal */}
        <div style={{
          width: `${percentage}%`,
          height: '100%',
          background: isDanger ? 
            'linear-gradient(90deg, #ff4444, #ff6666)' :
            `linear-gradient(90deg, ${color}, ${color}99)`,
          transition: 'width 0.5s ease-out',
          borderRadius: '7px',
          zIndex: 2,
          position: 'relative',
          boxShadow: isDanger ? '0 0 8px rgba(255, 68, 68, 0.5)' : `0 0 4px ${color}33`
        }} />
        
        {/* Línea marcadora de zona peligro */}
        {dangerZone && (
          <div style={{
            position: 'absolute',
            left: `${dangerPercentage}%`,
            width: '2px',
            height: '100%',
            background: '#ff4444',
            zIndex: 3,
            boxShadow: '0 0 3px #ff4444'
          }} />
        )}
      </div>
    </div>
  );
};

// Helper: Get current VPy line number for a given PC address
const getCurrentVpyLineForPC = (pc: number, pdbData: any): number | null => {
  if (!pdbData) return null;
  
  const pcStr = formatAddress(pc);
  
  // Try vpyLineMap first (multibank)
  if (pdbData.vpyLineMap) {
    const pcDec = parseInt(pcStr, 16);
    if (pdbData.vpyLineMap[pcDec]) {
      return pdbData.vpyLineMap[pcDec].line;
    }
  }
  
  // Try lineMap (single-bank)
  if (pdbData.lineMap) {
    for (const [lineStr, addr] of Object.entries(pdbData.lineMap)) {
      if ((addr as string).toLowerCase() === pcStr.toLowerCase()) {
        return parseInt(lineStr, 10);
      }
    }
  }
  
  return null;
};

// Componente para mostrar información técnica del emulador (métricas reales)
/* `backend` = which emulator is running RIGHT NOW. Without it this panel always read
  * `window.vecx` — the 6809 — so with UVM2 running it showed zeroed registers and a red
  * "JSVecx: STOPPED / MISMATCH": a panel that looks broken when in fact it is reading the
  * wrong machine. */
const EmulatorOutputInfo: React.FC<{ backend: 'rp2350' | 'uvm2' | null }> = ({ backend }) => {
  const [metrics, setMetrics] = useState<VecxMetrics | null>(null);
  const [regs, setRegs] = useState<VecxRegs | null>(null);
  const [vecxRunning, setVecxRunning] = useState<boolean>(false);
  const [statsArm, setStatsArm] = useState<{ ciclos: number; vectores: number; frames: number } | null>(null);

  // Get debug state from debugStore
  const debugState = useDebugStore(s => s.state);
  const emuFps = useDebugStore(s => s.currentFps);
  const emuDrawFps = useDebugStore(s => s.drawFps);

  const fetchStats = () => {
    try { setStatsArm((emuCore as any).uvm2FrameStats ?? null); } catch { setStatsArm(null); }
    try {
      const vecx = (window as any).vecx;
      if (!vecx) {
        setMetrics(null);
        setRegs(null);
        setVecxRunning(false);
        return;
      }
      
      const fetchedMetrics = vecx.getMetrics && vecx.getMetrics();
      const fetchedRegs = vecx.getRegisters && vecx.getRegisters();
      
      setMetrics(fetchedMetrics || null);
      setRegs(fetchedRegs || null);
      setVecxRunning(vecx.running || false);
    } catch (e) {
      setMetrics(null);
      setRegs(null);
      setVecxRunning(false);
    }
  };

  useEffect(() => {
    fetchStats();
    const interval = setInterval(fetchStats, 1000);
    return () => clearInterval(interval);
  }, []);

  const hex8 = (v: any) => typeof v === 'number' ? `0x${(v & 0xFF).toString(16).padStart(2, '0')}` : '--';
  const hex16 = (v: any) => typeof v === 'number' ? `0x${(v & 0xFFFF).toString(16).padStart(4, '0')}` : '--';
  
  const avgCyclesPerFrame = (metrics && metrics.frameCount > 0) ? 
    Math.round(metrics.totalCycles / metrics.frameCount) : 0;

  return (
    <div style={{
      background: '#1a1a1a',
      border: '1px solid #333',
      borderRadius: 4,
      padding: '6px 10px',
      marginBottom: 12,
      fontSize: '11px',
      color: '#ccc',
      fontFamily: 'monospace'
    }}>
      <div style={{ 
        fontWeight: 'bold', 
        color: '#0f0',
        marginBottom: '4px',
        fontSize: '10px',
        textTransform: 'uppercase',
        letterSpacing: '0.5px',
        fontFamily: 'system-ui'
      }}>
        Emulator Output{backend ? ` — ${backend.toUpperCase()}` : ''}
      </div>

      {/* With UVM2 (or the ARM core) running, the 6809 registers MEAN NOTHING: the 6809 is
          stopped, everything reads zero, and the red MISMATCH is not a fault. Show the
          counters of the backend that is actually running. */}
      {backend ? (
        <>
          <div style={{ marginBottom: '2px' }}>
            State: <span style={{
              color: debugState === 'running' ? '#0f0' : debugState === 'paused' ? '#ff0' : '#f00',
              fontWeight: 'bold'
            }}>{debugState.toUpperCase()}</span>
          </div>
          <div style={{ marginBottom: '2px' }}>
            Host FPS: {emuFps > 0 ? emuFps.toFixed(1) : '--'}
          </div>
          <div style={{ marginBottom: '2px' }}>
            {/* What the frame's bus cycles would allow on the real console: this is the
                number that matters, and it is NOT the one above (that one depends on this
                machine). */}
            Console refresh: {emuDrawFps > 0 ? `${emuDrawFps.toFixed(1)} Hz` : '--'}
          </div>
          <div style={{ marginBottom: '2px' }}>
            Bus cycles/frame: {statsArm?.ciclos ? statsArm.ciclos : '--'}
          </div>
          <div style={{ marginBottom: '2px' }}>
            Vectors/frame: {statsArm?.vectores ? statsArm.vectores : '--'}
          </div>
          <div>
            Frames: {statsArm?.frames ?? 0}
          </div>
        </>
      ) : (
      <>
      <div style={{ marginBottom: '2px' }}>
        PC: {hex16(regs?.PC)}
        {' | '}BANK: {typeof regs?.BANK === 'number' ? regs.BANK.toString(16).toUpperCase() : '--'}
      </div>
      
      <div style={{ marginBottom: '2px' }}>
        Debug State: <span style={{ 
          color: debugState === 'running' ? '#0f0' : debugState === 'paused' ? '#ff0' : '#f00',
          fontWeight: 'bold'
        }}>{debugState.toUpperCase()}</span>
        {' | '}
        JSVecx: <span style={{ 
          color: vecxRunning ? '#0f0' : '#f00',
          fontWeight: 'bold'
        }}>{vecxRunning ? 'RUNNING' : 'STOPPED'}</span>
        {debugState !== (vecxRunning ? 'running' : 'stopped') && (
          <span style={{ color: '#f00', marginLeft: '8px' }}>⚠️ MISMATCH</span>
        )}
      </div>
      
      <div style={{ marginBottom: '2px' }}>
        A: {hex8(regs?.A)} B: {hex8(regs?.B)} X: {hex16(regs?.X)} Y: {hex16(regs?.Y)} U: {hex16(regs?.U)} S: {hex16(regs?.S)} DP: {hex8(regs?.DP)} CC: {hex8(regs?.CC)}
      </div>
      
      <div style={{ marginBottom: '2px' }}>
        Total Cycles: {metrics?.totalCycles ?? 0}
      </div>
      
      <div style={{ marginBottom: '2px' }}>
        Instructions: {metrics?.instructionCount ?? 0}
      </div>
      
      <div style={{ marginBottom: '2px' }}>
        Frames: {metrics?.frameCount ?? 0}
      </div>
      
      <div>
        Avg Cycles/frame: {avgCyclesPerFrame > 0 ? avgCyclesPerFrame : '--'}
      </div>
      </>
      )}
    </div>
  );
};

// Romset for the simulated card. The ports read `roms/<STEM>.ZIP` off the SD at
// boot instead of embedding the ROM (MAME model), so the emulator has to hand the
// same bytes over — otherwise the game boots, finds no romset and says so, which is
// correct behaviour but looks like a bug.
//
// Returns undefined when there is no romset: that is not an error here. A port that
// still embeds its ROM ignores this entirely.
async function loadSimRomZip(binPath?: string | null): Promise<Uint8Array | undefined> {
  if (!binPath) return undefined;
  const stem = binPath.split(/[/\\]/).pop()?.replace(/\.bin$/i, '');
  if (!stem) return undefined;
  // Se le pasa el .bin: el nombre del romset lo declara EL JUEGO (bloque RSET),
  // no se deduce del nombre del fichero.
  const res = await (window as any).electronAPI?.sdRomZip?.(stem, binPath).catch(() => null);
  if (!res?.ok || !res.base64) {
    console.log(`[EmulatorPanel] No romset for "${stem}" (${res?.error ?? 'no ipc'})` +
      (res?.have?.length ? ` — roms/ has: ${res.have.join(', ')}` : '') +
      ` — the game will report it if it needs one.`);
    return undefined;
  }
  console.log(`[EmulatorPanel] \u2713 Romset ${res.name} (${res.size}b) from ${res.dir}`);
  return Uint8Array.from(atob(res.base64), c => c.charCodeAt(0));
}

export const EmulatorPanel: React.FC = () => {
  const status = useEmulatorStore(s => s.status);
  const setStatus = useEmulatorStore(s => s.setStatus);
  // External-project WASM simulator (PiTrex host SDK). When set, PitrexSimView
  // runs the module in the canvas area instead of a Vectrex backend.
  const simModulePath = useEmulatorStore(s => s.simModulePath);
  const simModuleNonce = useEmulatorStore(s => s.simModuleNonce);
  const setSimModule = useEmulatorStore(s => s.setSimModule);
  // The simulator Stop took down, so Play can start it again from the beginning.
  const stoppedSimRef = useRef<{ path: string; romZip: Uint8Array | null } | null>(null);
  // The engine that owns the panel (see stopAllEngines). In the store, not in a ref,
  // so it survives the panel remounting when the dock layout changes.
  const activeEngine = useEmulatorStore(s => s.activeEngine);
  const setActiveEngine = useEmulatorStore(s => s.setActiveEngine);

  // Tell tools that start runs (MCP ide_run) whether anyone is here to load the program.
  useEffect(() => {
    useEmulatorStore.getState().setPanelMounted(true);
    return () => useEmulatorStore.getState().setPanelMounted(false);
  }, []);
  // Which run backend is active, shown as a badge so it's never ambiguous whether
  // you're SIMULATING (fast WASM, F5) or EMULATING the RP2350 ARM binary (slow
  // HW-accurate, Shift+F5).  'rp2350' is set when an ARM binary is loaded below.
  const [runMode, setRunMode] = useState<'rp2350' | 'uvm2' | null>(null);
  const { setConfigOpen, loadConfig } = useJoystickStore();
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  
  // Persistent emulator settings
  const { 
    audioEnabled, 
    overlayEnabled, 
    lastRomPath, 
    lastRomName,
    // emulatorWasRunning is persisted but deliberately not read: a mount never starts an engine.
    lastCompiledBinary,
    lastCompiledProject,
    setAudioEnabled, 
    setOverlayEnabled, 
    setLastRom,
    setEmulatorRunning,
    setLastCompiledBinary
  } = useEmulatorSettings();
  
  // Estados básicos necesarios
  const [audioStats, setAudioStats] = useState<{ 
    sampleRate:number; pushed:number; consumed:number; 
    bufferedSamples:number; bufferedMs:number; overflowCount:number 
  }|null>(null);
  const [loadedROM, setLoadedROM] = useState<string | null>(null);
  const [availableROMs, setAvailableROMs] = useState<string[]>([]);
  const [selectedROM, setSelectedROM] = useState<string>(lastRomName || '');
  const [currentOverlay, setCurrentOverlay] = useState<string | null>(null);
  const [showPitrexOverlay, setShowPitrexOverlay] = useState<boolean>(false);
  const [pitrexImgPath, setPitrexImgPath] = useState<string>('');
  // Both `pitrex` and `uvm2` are hardware-only targets that share the same
  // "no in-browser emulation" overlay; this discriminator keeps the text
  // accurate (PiTrex Pi Zero vs UVM2 Cortex-M33).
  const [hardwareOverlayKind, setHardwareOverlayKind] = useState<'pitrex' | 'uvm2'>('pitrex');
  // PiTrex-specific audio enabled state (separate from JSVecX's AY chip state)
  const [pitrexAudioEnabled, setPitrexAudioEnabled] = useState<boolean>(true);
  const overlayCanvasRef = useRef<HTMLCanvasElement | null>(null);
  const containerRef = useRef<HTMLDivElement | null>(null);
  const [canvasSize, setCanvasSize] = useState({ width: 300, height: 400 });
  const defaultOverlayLoaded = useRef<boolean>(false); // Flag para evitar recargar overlay por defecto
  const jsVecxInitialized = useRef<boolean>(false); // Track if JSVecx already initialized (avoid reset on resize)
  
  // Phase 3: Breakpoint system
  const [breakpoints, setBreakpoints] = useState<Set<number>>(new Set());
  const debugState = useDebugStore(s => s.state);
  const pdbData = useDebugStore(s => s.pdbData);
  /* FRAME COUNTER. The emulator loop already wrote this to the store, but the only
   * component that rendered it (DebugToolbar) is not mounted anywhere, so the number was
   * computed and thrown away. Shown here, next to the backend badge. */
  const emuFps = useDebugStore(s => s.currentFps);
  const emuDrawFps = useDebugStore(s => s.drawFps);
  const emuCiclos = useDebugStore(s => s.cycles);
  const breakpointCheckIntervalRef = useRef<number | null>(null);

  // rp2350 requestAnimationFrame loop handle
  const rp2350LoopRef = useRef<number | null>(null);

  // Vector recorder (.vrec capture for game-preview / attract-mode playback)
  const recorderRef = useRef<VectorRecorder | null>(null);
  const [isRecording, setIsRecording] = useState<boolean>(false);
  const [recordElapsed, setRecordElapsed] = useState<number>(0);

  // Gameplay video recorder (real pixels + audio → WebM → MP4 via ffmpeg).
  // Separate from the .vrec vector recorder above.
  const videoRecorderRef = useRef<VideoRecorder | null>(null);
  /* Cuantos contextos pincho el tap la ultima vez, para no imprimir el
   * diagnostico diez veces por segundo: solo cuando cambia. */
  const ultimoTapRef = useRef<number>(-1);
  /* El canvas de PitrexSimView, que se superpone al del emulador cuando corre un
   * simulador WASM de proyecto externo. Grabar el de abajo daba "Nothing captured"
   * sin un solo error: no fallaba nada, es que ese canvas ya no lo pinta nadie. */
  const simCanvasRef = useRef<HTMLCanvasElement | null>(null);
  /* Lector del ultimo frame del simulador externo, para el .vrec (mismo punto ciego
   * que el video: emuCore y window.vecx estan parados mientras corre). */
  const simSegmentsRef = useRef<(() => PitrexSegment[] | null) | null>(null);
  /* Estables a proposito: una funcion en linea cambia de identidad en cada render y
   * React la vuelve a invocar con null antes de reasignarla. */
  const onSimCanvasReady = useCallback((el: HTMLCanvasElement | null) => { simCanvasRef.current = el; }, []);
  const onSimCaptureReady = useCallback((leer: (() => PitrexSegment[] | null) | null) => { simSegmentsRef.current = leer; }, []);
  const [isVideoRecording, setIsVideoRecording] = useState<boolean>(false);
  const [videoElapsed, setVideoElapsed] = useState<number>(0);
  // idle | recording | transcoding | saved | error
  const [videoStatus, setVideoStatus] = useState<'idle' | 'recording' | 'transcoding' | 'saved' | 'error'>('idle');
  const [videoMessage, setVideoMessage] = useState<string>('');

  // PiTrex ARM32 interpreter loop handle and core instance
  const pitrexLoopRef = useRef<number | null>(null);
  const pitrexCoreRef = useRef<import('../../pitrex/PitrexCore.js').PitrexCore | null>(null);
  // Last assembly text loaded into PitrexCore — needed for reset (re-parse + restart loop)
  const pitrexSFileRef = useRef<string | null>(null);
  const pitrexLibvpyRef = useRef<string | null>(null);
  
  // Reloads the last rp2350 / uvm2 image into its system (set by the load paths), so
  // Reset, and Play after Stop, restart THAT program instead of falling through to
  // the 6809 and booting the BIOS.
  const armReloadRef = useRef<(() => void) | null>(null);
  // The panel's Play / Pause / Stop, for the debugger message handler (a long-lived
  // closure): assigned on every render once the handlers exist.
  const runControlRef = useRef<{ play: () => void; pause: () => void; stop: () => void }>(
    { play: () => {}, pause: () => {}, stop: () => {} });
  // Mute state for handlers that live in long-lived closures (onCompiledBin).
  const audioEnabledRef = useRef(audioEnabled);
  audioEnabledRef.current = audioEnabled;

  /* ── ONE ENGINE AT A TIME ────────────────────────────────────────────────
   *
   * Stops EVERY engine the panel can run and silences every audio path they own:
   * JSVecX (CPU loop, its pending auto-start, its PSG callback), the psgAudio
   * streamer, VectrexSystem's audio, the PiTrex interpreter, the rp2350 and uvm2
   * systems (rAF loop + AudioContext) and, unless `keepSim`, the WASM simulator
   * (unmounting PitrexSimView closes its contexts). Called at the single entry of
   * every program load/start; the engine being started then starts itself (and its
   * own audio) as before. Stopping only the CPU is not enough: a ScriptProcessor
   * keeps rendering the last PSG registers, which is the stuck note.
   *
   * It does not change `activeEngine`: the caller that starts something sets it. */
  const stopAllEngines = useCallback((reason: string, opts: { keepSim?: boolean } = {}) => {
    // 1. JSVecX (m6809). stop() also cancels the start that vecx.reset() schedules
    //    200 ms later, and silences the PSG even if the debugger had halted the loop.
    const vecx = (window as any).vecx;
    if (vecx) {
      try { vecx.stop(); } catch {}
      try { vecx.e8910?.stop?.(); } catch {}
      // A 6809 debug session ends here: a stale 'paused' would make the breakpoint
      // poller pause whatever engine runs next.
      try { vecx.debugState = 'stopped'; vecx.stepMode = null; vecx.stepTargetAddress = null; } catch {}
    }
    // 2. The psgAudio streamer and VectrexSystem's own PSG output (the 6809 path).
    try { psgAudio.stop(); } catch {}
    try { (emuCore as any)._vectrexSystem?.stopAudio?.(); } catch {}
    // 3. PiTrex interpreter: rAF loop + audio. The core is dropped; a reload makes a new one.
    if (pitrexLoopRef.current !== null) {
      cancelAnimationFrame(pitrexLoopRef.current);
      pitrexLoopRef.current = null;
    }
    if (pitrexCoreRef.current) {
      try { pitrexCoreRef.current.stopAudio?.(); } catch {}
      pitrexCoreRef.current = null;
    }
    // 4. rp2350 and uvm2: one rAF loop drives either; each system owns an AudioContext.
    if (rp2350LoopRef.current !== null) {
      cancelAnimationFrame(rp2350LoopRef.current);
      rp2350LoopRef.current = null;
    }
    try { (emuCore as any)._rp2350System?.stopAudio?.(); } catch {}
    try { (emuCore as any)._uvm2System?.stopAudio?.(); } catch {}
    // 5. The WASM simulator: unmounting PitrexSimView ends the program and closes its audio.
    if (!opts.keepSim) {
      stoppedSimRef.current = null;
      if (useEmulatorStore.getState().simModulePath) setSimModule(null);
    }
    console.log(`[EmulatorPanel] stopAllEngines (${reason})${opts.keepSim ? ' — simulator kept' : ''}`);
  }, [setSimModule]);

  // Tools outside the panel (main.tsx before a build, the MCP bridge, DevTools) reach
  // the same function and can see who owns the panel.
  useEffect(() => {
    (window as any).emulatorEngines = {
      stopAll: (reason = 'external') => stopAllEngines(reason),
      active: () => useEmulatorStore.getState().activeEngine,
      // Who is running and which AudioContexts are live (for DevTools and tests).
      state: () => {
        const vecx = (window as any).vecx;
        const ec = emuCore as any;
        return {
          active: useEmulatorStore.getState().activeEngine,
          status: useEmulatorStore.getState().status,
          sim: useEmulatorStore.getState().simModulePath,
          m6809: { running: !!vecx?.running, pendingStart: vecx?.pendingStart != null,
                   psgReady: !!vecx?.e8910?.psg?.ready, ctx: vecx?.e8910?.ctx?.state ?? null },
          psgAudio: !!(psgAudio as any).running,
          armLoop: rp2350LoopRef.current !== null,
          rp2350Audio: ec._rp2350System?.audioCtx?.state ?? null,
          uvm2Audio: ec._uvm2System?.audioCtx?.state ?? null,
          pitrex: { loop: pitrexLoopRef.current !== null, core: !!pitrexCoreRef.current },
          contexts: getAllLiveContextOutputs().map(t => `${t.ctx.state}/${t.outputs.length}`),
        };
      },
    };
    return () => { delete (window as any).emulatorEngines; };
  }, [stopAllEngines]);

  // rp2350 / uvm2 audio follows Pause and Mute by suspending the system's context
  // (Stop closes it; the next load opens a new one).
  const setArmAudioSuspended = useCallback((suspended: boolean) => {
    const a = (emuCore as any)?.getAudioContextAndOutputNode?.();
    const ctx: AudioContext | undefined = a?.ctx;
    if (!ctx || ctx.state === 'closed') return;
    (suspended ? ctx.suspend() : ctx.resume()).catch(() => {});
  }, []);

  // Hook editor store para documentos activos
  const editorActive = useEditorStore(s => s.active);
  const editorDocuments = useEditorStore(s => s.documents);

  // Cargar lista de ROMs disponibles (lista hardcodeada ya que Vite no soporta directory listing)
  // Log component mount/remount
  useEffect(() => {
    console.log('🔄 [EmulatorPanel] COMPONENT MOUNTED/REMOUNTED');
    // console.log('📍 [EmulatorPanel] Mount stack trace:', new Error().stack); // Debug only
    return () => {
      console.log('💀 [EmulatorPanel] COMPONENT UNMOUNTING');
      // The rAF loops and the PiTrex core live in this instance's refs: once it is
      // gone nothing can stop them, so they stop here, sound included (cancelling
      // only the loop left the last note sustaining). JSVecX is global and the
      // remounted panel re-binds it, so it is left alone.
      if (rp2350LoopRef.current !== null) {
        cancelAnimationFrame(rp2350LoopRef.current);
        rp2350LoopRef.current = null;
        try { (emuCore as any)._rp2350System?.stopAudio?.(); } catch {}
        try { (emuCore as any)._uvm2System?.stopAudio?.(); } catch {}
      }
      if (pitrexLoopRef.current !== null) {
        cancelAnimationFrame(pitrexLoopRef.current);
        pitrexLoopRef.current = null;
      }
      if (pitrexCoreRef.current) {
        try { pitrexCoreRef.current.stopAudio?.(); } catch {}
        pitrexCoreRef.current = null;
      }
      // Discard any in-progress vector recording
      recorderRef.current?.discard();
      // Discard any in-progress gameplay video recording
      videoRecorderRef.current?.discard();
    };
  }, []);

  // The WASM simulator's entry: every activation (main.tsx Shift+F5, MCP, Play/Reset
  // here) goes through the store's setSimModule, so this effect is the one place that
  // hands the panel to it. Keyed on the nonce too: a rebuild of the same module path
  // is a new program load. PitrexSimView owns its own canvas + lifecycle.
  useEffect(() => {
    if (!simModulePath) return;
    stopAllEngines('WASM simulator', { keepSim: true });
    setActiveEngine('sim');
    setRunMode(null);
    setShowPitrexOverlay(false);
  }, [simModulePath, simModuleNonce, stopAllEngines, setActiveEngine]);

  // ── Vector recorder (.vrec) ─────────────────────────────────────────────
  // Samples the most recent completed frame's draw list from whichever
  // emulator backend is active.  All backends produce segments in the same
  // ALG integrator space (x 0..33000, y 0..41000, Y down); conversion to
  // Vectrex space (-127..127, Y up) happens inside VectorRecorder.
  const captureCurrentSegments = useCallback((): RawSegment[] | null => {
    // Simulador WASM de proyecto externo: tiene su propio bucle y su propio espacio
    // de coordenadas, y mientras corre los otros backends estan parados. Se convierte
    // de espacio PiTrex (x +-18000, y +-24000, Y arriba) al espacio ALG que espera el
    // grabador (centro 16500/20500, 127 unidades por coordenada Vectrex, Y abajo), de
    // forma que los extremos caigan justo en +-127.
    const leerSim = simSegmentsRef.current;
    if (simModulePath && leerSim) {
      const segs = leerSim();
      if (!segs) return null;
      const kx = (127 * 127) / PITREX_RANGE.x;
      const ky = (127 * 127) / PITREX_RANGE.y;
      return segs.map(v => ({
        x0: 16500 + v.x0 * kx, y0: 20500 - v.y0 * ky,
        x1: 16500 + v.x1 * kx, y1: 20500 - v.y1 * ky,
        intensity: v.b,
      }));
    }
    // rp2350 path (Rp2350System): emuCore.runFrame() stores each completed
    // frame in lastFrameSegments, exposed via getSegmentsShared().
    if ((emuCore as any)?._activeTarget === 'rp2350') {
      return emuCore.getSegmentsShared() ?? null;
    }
    // Legacy M6809 JSVecX: after the frame-boundary swap in vecx_emu(), the
    // just-completed frame's draw list lives in vectors_erse[0..vector_erse_cnt).
    // Pure read-only tap — entries carry intensity in `color`.
    const vecx = (window as any).vecx;
    if (vecx && Array.isArray(vecx.vectors_erse)) {
      const cnt = Math.min(vecx.vector_erse_cnt | 0, vecx.vectors_erse.length);
      const out: RawSegment[] = [];
      for (let i = 0; i < cnt; i++) {
        const v = vecx.vectors_erse[i];
        if (v) out.push({ x0: v.x0, y0: v.y0, x1: v.x1, y1: v.y1, intensity: v.color });
      }
      return out;
    }
    // Fallback: VectrexSystem path (useVectrexSystem flag) also updates
    // lastFrameSegments through emuCore.runFrame().
    return emuCore.getSegmentsShared() ?? null;
  }, [simModulePath]);

  const finishRecording = useCallback(async () => {
    const rec = recorderRef.current;
    if (!rec) return;
    setIsRecording(false);

    const fallbackName = defaultRecordingName();
    let name: string = fallbackName;
    try {
      const answer = window.prompt('Recording name (saved to assets/recordings/):', fallbackName);
      if (answer === null) {
        // User cancelled → discard the capture
        rec.discard();
        console.log('[EmulatorPanel] Vector recording discarded (cancelled)');
        return;
      }
      name = answer.trim() || fallbackName;
    } catch {
      name = fallbackName; // window.prompt unsupported — derive the name
    }
    name = name.replace(/\.vrec$/i, '').replace(/[^\w.-]+/g, '_');

    const vrec = rec.stop(name);
    if (vrec.frames.length === 0) {
      // Que no se pierda en la consola: una grabacion vacia es un fallo, y el motivo
      // casi siempre es que se estaba leyendo un backend que no era el que corria.
      const motivo = simModulePath
        ? 'el simulador externo no entrego ningun frame'
        : 'el emulador no entrego ningun frame';
      console.warn(`[EmulatorPanel] Vector recording empty — ${motivo}`);
      setVideoStatus('error');
      setVideoMessage(`Vector recording empty — ${motivo}`);
      setTimeout(() => setVideoStatus('idle'), 6000);
      return;
    }

    const rootDir = useProjectStore.getState().vpyProject?.rootDir?.replace(/\\/g, '/');
    const api = (window as any).files;
    if (!rootDir || !api?.saveFile) {
      console.error('[EmulatorPanel] Cannot save .vrec — no open project or saveFile API unavailable');
      return;
    }
    const path = `${rootDir}/assets/recordings/${name}.vrec`;
    try {
      const res = await api.saveFile({ path, content: serializeVrec(vrec) });
      if (res?.error) {
        console.error('[EmulatorPanel] Failed to save recording:', res.error);
      } else {
        console.log(`[EmulatorPanel] ✓ Vector recording saved: ${path} (${vrec.frames.length} frames @ ${vrec.fps} fps)`);
        // Also emit the hardware-compatible precompiled .vrb sibling.
        try {
          const vrb = await (window as any).electronAPI?.vrecCompile?.(path);
          if (vrb?.ok) console.log(`[EmulatorPanel] ✓ Precompiled preview: ${vrb.vrbPath}`);
        } catch { /* non-fatal */ }
      }
    } catch (e) {
      console.error('[EmulatorPanel] Failed to save recording:', e);
    }
  }, [simModulePath]);

  const onToggleRecording = useCallback(() => {
    let rec = recorderRef.current;
    if (!rec) {
      rec = new VectorRecorder();
      recorderRef.current = rec;
    }
    if (rec.isRecording) {
      void finishRecording();
      return;
    }
    rec.onTick = (elapsed) => setRecordElapsed(elapsed);
    rec.onAutoStop = () => { void finishRecording(); }; // 10 s cap reached
    setRecordElapsed(0);
    setIsRecording(true);
    rec.start(captureCurrentSegments);
    console.log(`[EmulatorPanel] Vector recording started (max ${MAX_RECORD_SECONDS} s)`);
  }, [captureCurrentSegments, finishRecording]);

  // ── Gameplay video recorder (MP4) ───────────────────────────────────────
  // Captures the live display canvas + the active target's audio to a WebM
  // MediaStream, then hands the bytes to the Electron main process which
  // transcodes to MP4 with the bundled ffmpeg. Independent of the .vrec path.

  // Resolve the active target's live { ctx, outputNode } for the audio tap.
  // PiTrex has its own core (not part of emuCore); everything else routes
  // through emuCore's active system (m6809 → VectrexSystem, rp2350 → Rp2350System).
  const getActiveAudio = useCallback((): Array<{ ctx: AudioContext; outputs: AudioNode[] }> => {
    try {
      // ── EVERY LIVE CONTEXT, AND THE ACTIVE TARGET'S FIRST ─────────────────
      //
      // THIS USED TO CHOOSE ONE, and choosing is what kept going wrong. First it
      // preferred getRunningContextOutputs(), which returns the first tracked
      // context that is 'running' with outputs — after switching targets that is
      // often a STALE context: still running, still with an output node, and
      // completely silent. So it was changed to pin the ACTIVE target's context,
      // which fixed that and introduced the opposite failure: only a component
      // this panel knows about can BE the active target, and the WASM simulator
      // (PitrexSimView) is a React child that owns its own audio and is not one
      // of them. Its recordings came out silent from end to end — video fine, no
      // sound at all — and the recorder reported success both times. Measured,
      // not guessed: ffmpeg volumedetect reads -91 dB on both of today's files
      // and -21.7 dB on one from August.
      //
      // Tapping ALL of them cannot fail that way. A stale context contributes
      // silence to a mix, which costs nothing; whatever is actually sounding is
      // in there by construction. The active target still goes first so the
      // diagnostic log names something meaningful.
      const pit = (pitrexCoreRef.current as any)?.getAudioContextAndOutputNode?.();
      const core = (emuCore as any)?.getAudioContextAndOutputNode?.();
      const legacy = psgAudio.getAudioContextAndOutputNode?.();
      const vx = (window as any).vecx;
      const vecxAudio = (vx?.ctx && vx?.node) ? { ctx: vx.ctx as AudioContext, outputNode: vx.node as AudioNode } : null;
      const activo = [pit, core, legacy, vecxAudio]
        .find((c): c is { ctx: AudioContext; outputNode: AudioNode } =>
          !!c?.ctx && !!c?.outputNode && c.ctx.state !== 'closed');

      const todos = getAllLiveContextOutputs();
      const lista = activo
        ? [{ ctx: activo.ctx, outputs: getOutputsForContext(activo.ctx).length
                                       ? getOutputsForContext(activo.ctx)
                                       : [activo.outputNode] },
           ...todos.filter(t => t.ctx !== activo.ctx)]
        : todos;

      if (lista.length !== ultimoTapRef.current) {
        ultimoTapRef.current = lista.length;
        const cual = activo === pit ? 'pitrex' : activo === core ? 'emuCore'
                   : activo === legacy ? 'psgAudio' : activo === vecxAudio ? 'window.vecx'
                   : 'ninguno declarado';
        console.log(`[EmulatorPanel] audio tap → ${lista.length} contexto(s), activo: ${cual}`,
                    lista.map(t => `${t.ctx.state}/${t.outputs.length}n`).join(' '));
      }
      return lista;
    } catch {
      return [];
    }
  }, []);

  const finishVideoRecording = useCallback(async () => {
    const rec = videoRecorderRef.current;
    if (!rec) return;
    setIsVideoRecording(false);

    const blob = await rec.stop();
    if (!blob || blob.size === 0) {
      setVideoStatus('error');
      const porque = rec.lastDiagnostic;
      setVideoMessage(porque ? `Nothing captured — ${porque}` : 'Nothing captured');
      console.error('[EmulatorPanel] grabacion vacia:', porque || '(sin diagnostico)');
      setTimeout(() => setVideoStatus('idle'), 4000);
      return;
    }

    const api = (window as any).videoExport;
    if (!api?.saveMp4) {
      setVideoStatus('error');
      setVideoMessage('Video export API unavailable');
      setTimeout(() => setVideoStatus('idle'), 4000);
      return;
    }

    setVideoStatus('transcoding');
    setVideoMessage('Transcoding to MP4…');
    try {
      const webmBytes = await blob.arrayBuffer();
      const res = await api.saveMp4({ webmBytes, name: defaultVideoName() });
      if (res?.path) {
        setVideoStatus('saved');
        // A recording that came out MUTE used to be saved with a plain "Saved
        // to ..." and no hint that anything was wrong. `hasAudio` is what the
        // tap managed to connect; `inputHadAudio` is what ffmpeg actually found
        // in the WebM — if they disagree the problem is the encoder, not the tap.
        const mudo = !rec.hasAudio || res.inputHadAudio === false;
        setVideoMessage(mudo ? `Saved (NO AUDIO) to ${res.path}` : `Saved to ${res.path}`);
        console.log(`[EmulatorPanel] ✓ Gameplay MP4 saved: ${res.path}`,
                    `| tap hasAudio=${rec.hasAudio} inputHadAudio=${res.inputHadAudio}`,
                    res.streams ?? '');
        setTimeout(() => setVideoStatus('idle'), 6000);
      } else if (res?.canceled) {
        setVideoStatus('idle');
        setVideoMessage('');
      } else {
        setVideoStatus('error');
        setVideoMessage(res?.error || 'Transcode failed');
        console.error('[EmulatorPanel] Video export failed:', res?.error);
        setTimeout(() => setVideoStatus('idle'), 8000);
      }
    } catch (e: any) {
      setVideoStatus('error');
      setVideoMessage(e?.message || 'Video export failed');
      console.error('[EmulatorPanel] Video export threw:', e);
      setTimeout(() => setVideoStatus('idle'), 8000);
    }
  }, []);

  const onToggleVideoRecording = useCallback(() => {
    let rec = videoRecorderRef.current;
    if (!rec) {
      rec = new VideoRecorder();
      videoRecorderRef.current = rec;
    }
    if (rec.isRecording) {
      void finishVideoRecording();
      return;
    }
    // el que se VE: si hay simulador externo, el suyo; si no, el del emulador
    const canvas = (simModulePath && simCanvasRef.current) || canvasRef.current;
    if (!canvas) {
      setVideoStatus('error');
      setVideoMessage('No display canvas');
      setTimeout(() => setVideoStatus('idle'), 4000);
      return;
    }
    rec.onTick = (elapsed) => setVideoElapsed(elapsed);
    setVideoElapsed(0);
    setIsVideoRecording(true);
    setVideoStatus('recording');
    // Pass getActiveAudio as a CALLBACK: the recorder holds its own audio track
    // from frame 0 and bridges the emulator's audio in once it appears — so you
    // can hit Record before the game boots (e.g. the intro) and still get sound.
    // Vectrex/6809 render at ~50 Hz; capture at 60 so no frame is dropped.
    rec.start(canvas, 60, getActiveAudio);
    console.log(`[EmulatorPanel] Gameplay video recording started — canvas ${canvas.width}x${canvas.height}`
      + `${simModulePath ? ' (simulador externo)' : ''} (audio bridges when it appears)`);
  }, [finishVideoRecording, getActiveAudio, simModulePath]);

  useEffect(() => {
    // Lista basada en las ROMs que vimos en la carpeta public/roms/
    const knownROMs = [
      'ARMOR.BIN', 'BEDLAM.BIN', 'BERZERK.BIN', 'BerzerkDebugged.vec', 'BirdsofPrey(1999).vec', 
      'BLITZ.BIN', 'CASTLE.BIN', 'CHASM.BIN', 'DKTOWER.BIN', 'FROGGER.BIN',
      'HEADSUP.BIN', 'HYPER.BIN', 'MailPlane.BIN', 'MINE3.BIN', 'MineStorm.bin', 'MSTORM2.BIN', 
      'NARZOD.BIN', 'NEBULA.BIN', 'PATRIOT.BIN', 'PatriotsIII.vec', 'POLAR.BIN', 'POLE.BIN', 
      'RIPOFF.BIN', 'ROCKS.BIN', 'SCRAMBLE.BIN', 'SFPD.BIN', 'SOLAR.BIN', 'SPACE.BIN', 
      'SPIKE.BIN', 'SPINBALL.BIN', 'STARHAWK.BIN', 'starship.vec', 'STARTREK.BIN', 
      'SWEEP.BIN', 'THRUST.BIN', 'Vectrexians-1999-PD.vec', 'WEBWARS.BIN', 'WOTR.BIN'
    ];
    setAvailableROMs(knownROMs);
    console.log('[EmulatorPanel] Loaded ROM list:', knownROMs.length, 'ROMs');
  }, []); // Sin auto-carga de ROM

  // Inicialización JSVecX con dimensiones responsive
  useEffect(() => {
    let cancelled = false;
    let initAttempts = 0;
    const MAX_INIT_ATTEMPTS = 5;
    
    const initJSVecX = () => {
      const canvas = canvasRef.current;
      if (!canvas) {
        console.warn('[EmulatorPanel] Canvas ref not ready yet');
        // Retry initialization if canvas isn't ready yet
        if (initAttempts < MAX_INIT_ATTEMPTS) {
          initAttempts++;
          setTimeout(initJSVecX, 200);
        }
        return;
      }
      
      // Check if canvas is visible (has dimensions)
      const rect = canvas.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0) {
        console.warn('[EmulatorPanel] Canvas not visible yet, retrying...');
        if (initAttempts < MAX_INIT_ATTEMPTS) {
          initAttempts++;
          setTimeout(initJSVecX, 200);
        }
        return;
      }
      
      // Configurar canvas con dimensiones responsive
      canvas.id = 'screen';
      canvas.width = 330;  // Resolución interna fija para JSVecX
      canvas.height = 410;
      canvas.style.width = `${canvasSize.width}px`;
      canvas.style.height = `${canvasSize.height}px`;
      canvas.style.border = '1px solid #333';
      canvas.style.background = '#000';
      
      // Optimización para múltiples lecturas de canvas (elimina warning Canvas2D)
      // JSVecX hace muchas operaciones getImageData, necesitamos willReadFrequently
      try {
        const ctx = canvas.getContext('2d', { willReadFrequently: true });
        if (ctx) {
          console.log('[EmulatorPanel] Canvas context configured with willReadFrequently optimization');
          // Asegurar que JSVecX use este contexto optimizado
          (canvas as any)._optimizedContext = ctx;
        }
      } catch (e) {
        console.warn('[EmulatorPanel] Could not configure willReadFrequently, using default context');
      }
      
      let vecx = (window as any).vecx;
      if (!vecx) {
        console.error('[EmulatorPanel] Global vecx instance not found');
        return;
      }
      
      // CRITICAL: Don't re-initialize if already initialized (avoid reset on resize)
      if (jsVecxInitialized.current) {
        console.log('[EmulatorPanel] 🛑 Skipping re-initialization - JSVecx already initialized');
        return;
      }

      const wasRunning = !!vecx.running;

      console.log(`[EmulatorPanel] Initializing JSVecX with canvas size: ${canvasSize.width}x${canvasSize.height} (visible: ${rect.width}x${rect.height}) wasRunning=${wasRunning}`);
      
      try {
      // Always re-bind osint to the current canvas element.
      // On tab switch React unmounts the panel (destroys canvas) and remounts it.
      // vecx.osint.ctx still points to the old detached canvas — re-init is required.
      // osint.init() is safe to call while running: it only refreshes canvas/ctx refs.
      console.log('[EmulatorPanel] Binding osint display to current canvas...');
      vecx.osint.init(vecx);
      console.log('[EmulatorPanel] ✓ osint.init() successful');

      if (!vecx.e6809?.vecx) {
        console.log('[EmulatorPanel] Initializing e6809 CPU...');
        vecx.e6809.init(vecx);
        console.log('[EmulatorPanel] ✓ e6809.init() successful');
      }

      if (!wasRunning) {
        // Fresh start: reset CPU+display state
        console.log('🔄 [EmulatorPanel] CALLING vecx_reset() - fresh initialization');
        vecx.vecx_reset();
        vecx.osint.osint_clearscreen();
        console.log('[EmulatorPanel] ✓ vecx reset successful');
      } else {
        // Was already running: canvas is now re-bound, emulator continues painting
        console.log('[EmulatorPanel] ✓ canvas re-bound, emulator continues running');
      }
        
      console.log('[EmulatorPanel] ✓ JSVecx initialized (stopped, ready for manual start)');
        
        jsVecxInitialized.current = true; // Mark as initialized
        
        // Only when nothing owns the panel: on a remount the status belongs to the
        // engine that is running (the simulator, a 6809 game that kept running, ...).
        if (!cancelled && useEmulatorStore.getState().activeEngine === null) {
          setStatus('stopped');
        }
      } catch (e) {
        console.error('[EmulatorPanel] JSVecX initialization failed:', e);
        if (!cancelled) {
          setStatus('stopped');
        }
      }
    };
    
    // Esperar un poco para que el canvas esté listo
    setTimeout(initJSVecX, 100);
    
    return () => {
      cancelled = true;
    };
  }, [setStatus, canvasSize.width, canvasSize.height]); // Use individual values instead of object reference

  // LOG: Detectar cambios en canvasSize (debug only - commented to reduce console noise)
  // useEffect(() => {
  //   console.log(`[EmulatorPanel] 🔍 canvasSize changed to:`, canvasSize);
  //   console.log(`[EmulatorPanel] 🔍 Stack trace:`, new Error().stack);
  // }, [canvasSize]);

  // Actualizar dimensiones del canvas sin re-inicializar JSVecX
  useEffect(() => {
    const canvas = canvasRef.current;
    if (canvas) {
      canvas.style.width = `${canvasSize.width}px`;
      canvas.style.height = `${canvasSize.height}px`;
      console.log(`[EmulatorPanel] Canvas resized to: ${canvasSize.width}x${canvasSize.height}`);
    }
  }, [canvasSize]);

  // Función para cargar overlay basado en nombre de ROM (definida antes de ser usada)
  const loadOverlay = useCallback(async (romName: string) => {
    const baseName = romName.replace(/\.(bin|BIN|vec)$/, '').toLowerCase();
    
    console.log(`[EmulatorPanel] 🖼️  loadOverlay called for ROM: "${romName}" (base: "${baseName}")`);
    
    try {
      // Obtener la ruta del proyecto actual
      const projectState = (window as any).__projectStore__?.getState?.();
      const projectRoot = projectState?.vpyProject?.rootDir;
      console.log(`[EmulatorPanel] 📁 Project root: ${projectRoot || '(no project loaded)'}`);
      
      if (!projectRoot) {
        setCurrentOverlay(null);
        console.log(`[EmulatorPanel] ⚠️  No project loaded - cannot load overlay`);
        return;
      }
      
      // Intentar cargar overlay genérico del proyecto usando IPC
      const overlayFsPath = `${projectRoot}/assets/overlay/overlay.png`;
      console.log(`[EmulatorPanel] 🔍 Checking project overlay: ${overlayFsPath}`);
      
      const result = await (window as any).files.readFileBin(overlayFsPath);
      
      if (result.error) {
        console.log(`[EmulatorPanel] ℹ️  No overlay found at: ${overlayFsPath}`);
        console.log(`[EmulatorPanel] Error: ${result.error}`);
        setCurrentOverlay(null);
        return;
      }
      
      // Convertir base64 a data URL
      const dataUrl = `data:image/png;base64,${result.base64}`;
      setCurrentOverlay(dataUrl);
      console.log(`[EmulatorPanel] ✅ Project overlay loaded: ${overlayFsPath} (${result.size} bytes)`);
      
    } catch (e) {
      // Error al buscar overlay - quitarlo
      setCurrentOverlay(null);
      console.log(`[EmulatorPanel] ❌ Error loading overlay:`, e);
    }
  }, []); // sin dependencias (lee projectState dinámicamente)

  // Phase 3: Breakpoint management functions
  const addBreakpoint = useCallback((address: number) => {
    console.log(`[EmulatorPanel] addBreakpoint called with:`, address, `type: ${typeof address}`);
    console.log(`[EmulatorPanel] 📊 Current canvasSize before add:`, canvasSize);
    setBreakpoints(prev => {
      const next = new Set(prev);
      next.add(address);
      console.log(`[EmulatorPanel] ✓ Breakpoint added at ${formatAddress(address)}`);
      console.log(`[EmulatorPanel] 📍 Total breakpoints: ${next.size}, addresses: [${Array.from(next).map(formatAddress).join(', ')}]`);
      console.log(`[EmulatorPanel] 📍 Raw Set contents:`, Array.from(next));
      return next;
    });
    console.log(`[EmulatorPanel] 📊 Current canvasSize after add:`, canvasSize);
  }, [canvasSize]);

  const removeBreakpoint = useCallback((address: number) => {
    setBreakpoints(prev => {
      const next = new Set(prev);
      next.delete(address);
      console.log(`[EmulatorPanel] ✓ Breakpoint removed from ${formatAddress(address)}`);
      console.log(`[EmulatorPanel] 📍 Total breakpoints: ${next.size}, addresses: [${Array.from(next).map(formatAddress).join(', ')}]`);
      return next;
    });
  }, []);

  const toggleBreakpoint = useCallback((address: number) => {
    setBreakpoints(prev => {
      const next = new Set(prev);
      if (next.has(address)) {
        next.delete(address);
        console.log(`[EmulatorPanel] ✓ Breakpoint removed from ${formatAddress(address)}`);
      } else {
        next.add(address);
        console.log(`[EmulatorPanel] ✓ Breakpoint added at ${formatAddress(address)}`);
      }
      return next;
    });
  }, []);

  const clearAllBreakpoints = useCallback(() => {
    setBreakpoints(new Set());
    console.log('[EmulatorPanel] ✓ All breakpoints cleared');
  }, []);

  // Expose breakpoint functions globally for debugStore integration
  useEffect(() => {
    // The 6809's own breakpoint set (vecx.breakpoints) is what stops it; the panel's
    // copy only mirrors it. debug/breakpointSync.ts drives these.
    const vx = () => (window as any).vecx;
    (window as any).emulatorDebug = {
      addBreakpoint: (a: number) => { vx()?.addBreakpoint?.(a); addBreakpoint(a); },
      removeBreakpoint: (a: number) => { vx()?.removeBreakpoint?.(a); removeBreakpoint(a); },
      toggleBreakpoint,
      clearAllBreakpoints: () => { vx()?.clearBreakpoints?.(); clearAllBreakpoints(); },
      getBreakpoints: () => Array.from((vx()?.breakpoints as Set<number> | undefined) ?? breakpoints),
      start: () => {
        const vecx = (window as any).vecx;
        // Breakpoint sync calls this whenever the debugger reads 'paused'; that state
        // is shared by every engine, so it must not start the 6809 under another one.
        if (useEmulatorStore.getState().activeEngine !== 'm6809') return;
        if (vecx && vecx.debugState === 'paused') {
          console.log('[EmulatorPanel] 🚀 emulatorDebug.start() called - starting emulator');
          vecx.debugState = 'running';
          vecx.start();
        }
      }
    };
    installBreakpointSync();
    syncEmulatorBreakpoints();
    
    return () => {
      delete (window as any).emulatorDebug;
    };
  }, [addBreakpoint, removeBreakpoint, toggleBreakpoint, clearAllBreakpoints, breakpoints]);

  // Gamepad Manager: Poll HTML5 Gamepad API and inject into JSVecX memory
  useEffect(() => {
    // Load joystick configuration on mount
    loadConfig();

    // Persistent state for button debouncing (outside setInterval to persist between frames)
    let lastButtonState = 0;

    // Player-2 buttons over keyboard: J/K/L/M → P2 btn 1/2/3/4. The frontend
    // has no second-controller keyboard config, so this is the quick path
    // to drive J2_BUTTON_*() without a second physical gamepad. The bits
    // land in the high nibble of the PSG reg-14 value injected below.
    // Listener attached on `document` with capture:true so Monaco / IDE
    // shortcut handlers don't swallow the keys before us.
    let p2ButtonState = 0;
    const p2KeyMap: Record<string, number> = {
      'KeyJ': 0, 'KeyK': 1, 'KeyL': 2, 'KeyM': 3,
    };
    const p2KeyDown = (e: KeyboardEvent) => {
      const bit = p2KeyMap[e.code];
      if (bit !== undefined) p2ButtonState |= (1 << bit);
    };
    const p2KeyUp = (e: KeyboardEvent) => {
      const bit = p2KeyMap[e.code];
      if (bit !== undefined) p2ButtonState &= ~(1 << bit);
    };
    document.addEventListener('keydown', p2KeyDown, { capture: true });
    document.addEventListener('keyup',   p2KeyUp,   { capture: true });

    const gamepadPollInterval = setInterval(() => {
      const vecx = (window as any).vecx;
      // vecx may be null in pitrex mode — do NOT early-return here.
      // All input processing runs regardless; JSVecX writes are guarded below.

      const gamepads = navigator.getGamepads();
      if (!gamepads) return;

      // Get joystick configuration from store
      const joystickConfig = useJoystickStore.getState();
      const { gamepadIndex, gamepadIndex2, axisXIndex, axisYIndex, axisXInverted, axisYInverted, deadzone, buttonMappings, dpadUpButton, dpadDownButton, dpadLeftButton, dpadRightButton } = joystickConfig;

      // ── Player 2 gamepad poll ──────────────────────────────────────────
      // Reuses the same axis indices / button mappings as P1 (same model
      // assumed). Feeds J2_X / J2_Y axes (jsvecx alg_jch2/jch3) and the
      // high nibble of psgReg14 for J2_BUTTON_1..4.
      let p2GpButtonState = 0;
      let p2GpAxisX = 0;
      let p2GpAxisY = 0;
      if (gamepadIndex2 !== null && gamepadIndex2 !== gamepadIndex) {
        const gp2 = gamepads[gamepadIndex2];
        if (gp2 && gp2.connected) {
          const raw2X = gp2.axes[axisXIndex] || 0;
          const raw2Y = gp2.axes[axisYIndex] || 0;
          const apply = (v: number) => (Math.abs(v) < deadzone ? 0 : v);
          const x2 = apply(raw2X) * (axisXInverted ? -1 : 1);
          const y2 = apply(raw2Y) * (axisYInverted ? -1 : 1);
          // D-pad override for axes (same buttons mapped on P1)
          const d2L = gp2.buttons[dpadLeftButton]?.pressed || false;
          const d2R = gp2.buttons[dpadRightButton]?.pressed || false;
          const d2U = gp2.buttons[dpadUpButton]?.pressed || false;
          const d2D = gp2.buttons[dpadDownButton]?.pressed || false;
          const ax2 = d2L ? -127 : d2R ? 127 : Math.round(x2 * 127);
          const ay2 = d2D ? -127 : d2U ? 127 : Math.round(y2 * 127);
          p2GpAxisX = ax2;
          p2GpAxisY = ay2;
          buttonMappings.forEach((m) => {
            const b = gp2.buttons[m.gamepadButton];
            if (b && b.pressed) p2GpButtonState |= (1 << (m.vectrexButton - 1));
          });
        }
      }
      // OR with keyboard JKLM fallback so both routes light up the same
      // bits when nothing's wired to P2 gamepad.
      const p2DownTotal = (p2ButtonState | p2GpButtonState) & 0x0F;

      if (gamepadIndex === null) {
        // No gamepad configured — use keyboard input (ArrowLeft/Right/Up/Down or WASD)
        const kb = inputManager.update();
        const kbX = kb.x / 127; // normalize -127..127 → -1..1
        const kbY = kb.y / 127;
        // rp2350 / pitrex keyboard axis and buttons. P2 axes have no
        // keyboard fallback yet (JKLM only drives the buttons), so we
        // pass 0/0 for the P2 stick. P2 buttons come from the JKLM mask.
        emuCore.setJoyAxis?.(kb.x, kb.y);
        emuCore.setJoyButtons2?.(0xFF & ~(p2ButtonState & 0x0F));
        pitrexCoreRef.current?.setInput(
          kb.x, kb.y, kb.buttons & 0xF,
          0, 0, p2ButtonState & 0xF,
        );
        if (vecx) {
          try {
            // Always use analog mode so the gamepad's continuous values reach Joy_Analog.
            // inputManager already polls the Gamepad API — kb.x/y are analog when a
            // gamepad is connected, digital (±127/0) when only keyboard is used.
            // Map kb.x/y (−127..127) → alg_jch0/1 (0..255): +128 shifts center to 0x80.
            // The emuloop must NOT override these (useAnalogJoy=true).
            vecx.useAnalogJoy = true;
            vecx.alg_jch0 = (kb.x + 128) & 0xFF;  // X: left→1, center→128, right→255
            vecx.alg_jch1 = (kb.y + 128) & 0xFF;  // Y: down→1, center→128, up→255
            // Keep leftHeld/rightHeld/etc. for compatibility with any other JSVecX code.
            vecx.leftHeld  = kbX < -0.3;
            vecx.rightHeld = kbX > 0.3;
            vecx.downHeld  = kbY < -0.3;
            vecx.upHeld    = kbY > 0.3;
            vecx.alg_jch0 = Math.round((kbX + 1) * 127.5); // 0=left, 128=center, 255=right
            vecx.alg_jch1 = Math.round((kbY + 1) * 127.5); // 0=down,  128=center, 255=up
            // Same PSG reg 14 injection as the gamepad path so J1_BUTTON_*
            // and J2_BUTTON_*() work in keyboard-only mode. kb.buttons has
            // P1 in bits 0-3; the JKLM keyboard fallback (p2ButtonState)
            // goes into bits 4-7.
            const combinedDown = (kb.buttons & 0x0F) | ((p2ButtonState & 0x0F) << 4);
            const psgReg14 = ~combinedDown & 0xFF;
            (window as any).injectedButtonStatePSG = psgReg14;
            if (vecx.e8910 && vecx.e8910.e8910_write) {
              vecx.e8910.e8910_write(14, psgReg14);
            }
          } catch {}
        }
        return;
      }

      const gamepad = gamepads[gamepadIndex];
      if (!gamepad || !gamepad.connected) return;

      // Read analog axes and apply configuration
      const rawX = gamepad.axes[axisXIndex] || 0;
      const rawY = gamepad.axes[axisYIndex] || 0;

      // Apply deadzone
      const applyDeadzone = (value: number) => {
        return Math.abs(value) < deadzone ? 0 : value;
      };

      const x = applyDeadzone(rawX) * (axisXInverted ? -1 : 1);
      const y = applyDeadzone(rawY) * (axisYInverted ? -1 : 1);

      // Read D-Pad button states (digital input)
      const dpadLeft = gamepad.buttons[dpadLeftButton]?.pressed || false;
      const dpadRight = gamepad.buttons[dpadRightButton]?.pressed || false;
      const dpadUp = gamepad.buttons[dpadUpButton]?.pressed || false;
      const dpadDown = gamepad.buttons[dpadDownButton]?.pressed || false;

      // Build button state from configured button mappings
      let buttonState = 0x00;
      buttonMappings.forEach(mapping => {
        const button = gamepad.buttons[mapping.gamepadButton];
        if (button && button.pressed) {
          buttonState |= (1 << (mapping.vectrexButton - 1));
        }
      });

      // Compute final axis values with D-pad override
      const rp2350X = Math.round(x * 127);
      const rp2350Y = Math.round(y * 127);
      const dp2350X = dpadLeft ? -127 : dpadRight ? 127 : rp2350X;
      const dp2350Y = dpadDown ? -127 : dpadUp   ? 127 : rp2350Y;

      // rp2350: forward axis and buttons (P1 always, P2 only when wired)
      emuCore.setJoyAxis?.(dp2350X, dp2350Y);
      emuCore.setJoyButtons?.(0xF0 & ~((buttonState & 0x0F) << 4));
      if (gamepadIndex2 !== null) {
        emuCore.setJoyAxis2?.(p2GpAxisX, p2GpAxisY);
        // BTN_STATE_J2 is active-low; bits 0-3 = btn 1-4.
        emuCore.setJoyButtons2?.(0xFF & ~(p2DownTotal & 0x0F));
      } else if (p2ButtonState !== 0) {
        // P2-keyboard-only: still feed the buttons to rp2350.
        emuCore.setJoyButtons2?.(0xFF & ~(p2ButtonState & 0x0F));
      }

      // pitrex: forward axis and buttons for BOTH players. PitrexCore.setInput
      // already takes the P2 triplet as its last three params.
      pitrexCoreRef.current?.setInput(
        dp2350X, dp2350Y, buttonState & 0xF,
        p2GpAxisX, p2GpAxisY, p2DownTotal & 0xF,
      );

      // JSVecX-specific: directional booleans, analog channels, PSG buttons
      if (vecx) {
        try {
          // Enable analog joystick mode: alg_jch0/1 are set directly from gamepad
          // axes below, and vecx_emuloop will NOT override them with digital values.
          vecx.useAnalogJoy = true;
          vecx.alg_jch0 = (dp2350X + 128) & 0xFF;  // X: −127→1, 0→128, 127→255
          vecx.alg_jch1 = (dp2350Y + 128) & 0xFF;  // Y: −127→1, 0→128, 127→255
          vecx.leftHeld  = (x < -0.3) || dpadLeft;
          vecx.rightHeld = (x > 0.3)  || dpadRight;
          vecx.downHeld  = (y < -0.3) || dpadDown;
          vecx.upHeld    = (y > 0.3)  || dpadUp;

          vecx.alg_jch0 = Math.round((x + 1) * 127.5);
          vecx.alg_jch1 = Math.round((y + 1) * 127.5);

          // Track transitions for debug logging
          const prevState = lastButtonState;
          const transitions = buttonState & ~prevState & 0xFF;
          lastButtonState = buttonState;

          if (transitions !== 0) {
            console.log('[GamepadManager] TRANSITION DETECTED:', {
              buttonState: buttonState.toString(2).padStart(4, '0'),
              transitions: transitions.toString(2).padStart(4, '0'),
            });
          }

          // PSG reg 14 injection for Read_Btns workaround. Bits 0-3 = P1
          // (from the configured gamepad), bits 4-7 = P2 (from the P2
          // gamepad if configured, OR'd with the JKLM keyboard fallback).
          // PSG reg 14 is active-LOW, so we invert the combined press mask
          // before writing.
          const combinedDown = (buttonState & 0x0F) | ((p2DownTotal & 0x0F) << 4);
          const psgReg14 = ~combinedDown & 0xFF;
          (window as any).injectedButtonStatePSG = psgReg14;
          if (vecx.e8910 && vecx.e8910.e8910_write) {
            vecx.e8910.e8910_write(14, psgReg14);
          }
          // J2 analog axes. jsvecx's Joy_Analog read path uses jch2/jch3 via
          // the VIA mux, but in practice the BIOS-cached $C81D/$C81E
          // (Vec_Joy_2_X/Y) didn't always reflect them — writing both covers
          // the BIOS-read and the direct-RAM-read code paths.
          if (gamepadIndex2 !== null) {
            vecx.alg_jch2 = (p2GpAxisX + 128) & 0xFF;
            vecx.alg_jch3 = (p2GpAxisY + 128) & 0xFF;
            if (vecx.write8) {
              vecx.write8(0xC81D, p2GpAxisX & 0xFF);
              vecx.write8(0xC81E, p2GpAxisY & 0xFF);
            }
          }

          if ((transitions !== 0 || buttonState !== 0) && (window as any).BUTTON_DEBUG) {
            setTimeout(() => {
              const c811 = vecx.read8(0xC811);
              const c80f = vecx.read8(0xC80F);
              const c80e = vecx.read8(0xC80E);
              console.log('[Button] Frame state:', {
                'btn': buttonState.toString(2).padStart(4, '0'),
                'trans': transitions.toString(2).padStart(4, '0'),
                'C811': c811.toString(2).padStart(4, '0'),
                'C80F': c80f.toString(2).padStart(4, '0'),
                'C80E': c80e.toString(2).padStart(4, '0'),
              });
            }, 5);
          }
        } catch (error) {
          console.error('[GamepadManager] Error setting JSVecX input state:', error);
        }
      }
    }, 16); // ~60Hz polling

    return () => {
      clearInterval(gamepadPollInterval);
      document.removeEventListener('keydown', p2KeyDown, { capture: true } as any);
      document.removeEventListener('keyup',   p2KeyUp,   { capture: true } as any);
    };
  }, [status, loadConfig]); // Re-create interval if status changes

  // Helper function to apply audio state to vecx
  const applyAudioState = useCallback((enabled?: boolean) => {
    const vecx = (window as any).vecx;
    if (!vecx || !vecx.e8910) {
      console.warn('[EmulatorPanel] Cannot apply audio state - vecx or e8910 not available');
      return;
    }
    
    const audioState = enabled !== undefined ? enabled : audioEnabled;
    
    try {
      // Verificar estado actual del audio en e8910
      const currentAudioEnabled = vecx.e8910.enabled;
      console.log('[EmulatorPanel] Applying audio state:', audioState ? 'enabled' : 'muted', {
        currentAudioEnabled,
        targetAudioState: audioState,
        needsToggle: currentAudioEnabled !== audioState
      });
      
      // Solo hacer toggle si el estado actual es diferente al deseado
      if (currentAudioEnabled !== audioState) {
        if (vecx.toggleSoundEnabled) {
          const newState = vecx.toggleSoundEnabled();
          console.log(`[EmulatorPanel] ✓ Toggled audio: ${currentAudioEnabled} → ${newState}`);
        } else {
          console.warn('[EmulatorPanel] toggleSoundEnabled not available');
        }
      } else {
        console.log(`[EmulatorPanel] ✓ Audio already in desired state: ${audioState}`);
      }
      
      // Verificar estado final
      const finalState = vecx.e8910.enabled;
      console.log('[EmulatorPanel] ✓ Audio state application complete. Final state:', finalState);
      
    } catch (error) {
      console.error('[EmulatorPanel] Error applying audio state:', error);
    }
  }, [audioEnabled]);

  // Helper function to get current audio state from vecx
  const getCurrentAudioState = useCallback(() => {
    const vecx = (window as any).vecx;
    if (vecx && vecx.e8910) {
      return vecx.e8910.enabled;
    }
    return audioEnabled; // fallback to stored state
  }, [audioEnabled]);

  // Sync audio state periodically to ensure UI matches reality
  useEffect(() => {
    const interval = setInterval(() => {
      const vecx = (window as any).vecx;
      // Only the 6809's PSG flag can be "reality" here: under another engine it is a
      // leftover, and syncing from it would undo that engine's mute within a second.
      if (vecx && vecx.e8910 && status === 'running' && activeEngine === 'm6809') {
        const actualState = vecx.e8910.enabled;
        if (actualState !== audioEnabled) {
          console.log('[EmulatorPanel] Audio state desync detected, syncing:', actualState);
          setAudioEnabled(actualState);
        }
      }
    }, 1000); // Check every second

    return () => clearInterval(interval);
  }, [audioEnabled, status, setAudioEnabled, activeEngine]);

  // Phase 3: Breakpoint detection system (REACTIVE - no polling)
  // The WASM emulator checks breakpoints after EVERY instruction
  // We just need to detect when it has paused
  const checkBreakpointHit = useCallback(() => {
    // Breakpoints belong to the 6809 (a stale JSVecX 'paused' must not pause another engine)
    if (useEmulatorStore.getState().activeEngine !== 'm6809') return;
    // Solo verificar si estamos en modo debug
    if (debugState !== 'running') {
      console.log('[EmulatorPanel] 🔍 checkBreakpointHit called but debugState is:', debugState);
      return;
    }
    
    try {
      const vecx = (window as any).vecx;
      if (!vecx || !vecx.e6809) return;
      
      // Check if WASM paused by breakpoint (reactive check)
      if (vecx.isPausedByBreakpoint && vecx.isPausedByBreakpoint()) {
        const currentPC = vecx.e6809?.reg_pc;
        console.log(`[EmulatorPanel] 🔴 Breakpoint hit detected at PC: ${formatAddress(currentPC)}`);
        
        // Log registers automatically
        if (vecx.e6809) {
          const regs = vecx.e6809;
          console.log(`📊 REGISTERS: A: 0x${regs.reg_a?.toString(16).padStart(2, '0')} B: 0x${regs.reg_b?.toString(16).padStart(2, '0')} X: 0x${regs.reg_x?.toString(16).padStart(4, '0')} Y: 0x${regs.reg_y?.toString(16).padStart(4, '0')} U: 0x${regs.reg_u?.toString(16).padStart(4, '0')} S: 0x${regs.reg_s?.toString(16).padStart(4, '0')} DP: 0x${regs.reg_dp?.toString(16).padStart(2, '0')} CC: 0x${regs.reg_cc?.toString(16).padStart(2, '0')} PC: 0x${regs.reg_pc?.toString(16).padStart(4, '0')}`);
        }
        
        // Pausar emulador
        if (vecx.running) {
          vecx.stop();
          console.log('[EmulatorPanel] ✓ Emulator paused by breakpoint');
        }
        
        // Actualizar debug state
        const debugStore = useDebugStore.getState();
        debugStore.setState('paused');
        debugStore.setCurrentAsmAddress(formatAddress(currentPC));

        // Bank-aware ASM navigation: open the ACTIVE bank's ASM file at the exact line.
        // asmBankAddr is keyed "bank:ADDR" (multibank PC is bank-relative), asmBankFiles
        // maps each bank to its ASM file (relative to the build dir / compiled binary).
        let navigatedToAsm = false;
        const pdb: any = pdbData;
        if (pdb?.asmBankAddr && pdb?.asmBankFiles && lastCompiledBinary) {
          const bank = (vecx.currentBank ?? 0);
          const pcHex = (currentPC & 0xFFFF).toString(16).toUpperCase().padStart(4, '0');
          const asmLine = pdb.asmBankAddr[`${bank}:${pcHex}`];
          const asmRel = pdb.asmBankFiles[String(bank)];
          if (asmLine && asmRel) {
            const binDir = lastCompiledBinary.substring(0, lastCompiledBinary.lastIndexOf('/'));
            const asmPath = `${binDir}/${asmRel}`;
            const asmUri = `file://${asmPath}`;
            const editorStore = useEditorStore.getState();
            const navigate = () => {
              (window as any).asmDebuggingMode = true;
              (window as any).asmDebuggingFile = asmUri;
              editorStore.setActive(asmUri);
              debugStore.setCurrentVpyLine(asmLine); // 1-based; highlight effect uses it directly
              editorStore.gotoLocation(asmUri, asmLine - 1, 0); // vpy.goto adds +1
              console.log(`[EmulatorPanel] ✓ ASM nav: bank ${bank} PC 0x${pcHex} → ${asmRel}:${asmLine}`);
            };
            const existing = editorStore.documents.find(d => d.uri === asmUri);
            if (existing) {
              navigate();
              navigatedToAsm = true;
            } else if ((window as any).files?.readFile) {
              navigatedToAsm = true;
              (window as any).files.readFile(asmPath).then((res: {content?: string; error?: string}) => {
                if (res && !res.error && res.content) {
                  editorStore.openDocument({ uri: asmUri, content: res.content, language: 'vpy', dirty: false, mtime: Date.now(), diagnostics: [] });
                  navigate();
                } else {
                  console.warn(`[EmulatorPanel] ⚠️ Could not read ASM file ${asmPath}: ${res?.error}`);
                }
              });
            }
          } else {
            console.log(`[EmulatorPanel] ⚠️ No asmBankAddr entry for bank ${bank} PC 0x${pcHex}`);
          }
        }

        // Fall back to VPy line mapping only if we didn't navigate to ASM.
        if (!navigatedToAsm && pdbData) {
          (window as any).asmDebuggingMode = false;
          const vpyLine = asmAddressToVpyLine(currentPC, pdbData);
          if (vpyLine !== null) {
            debugStore.setCurrentVpyLine(vpyLine);
            console.log(`[EmulatorPanel] ✓ Mapped to VPy line: ${vpyLine}`);
          } else {
            console.log(`[EmulatorPanel] ⚠️  No VPy line mapping for address ${formatAddress(currentPC)}`);
          }
        }

        console.log('[EmulatorPanel] 🛑 Execution paused at breakpoint');
      }
    } catch (e) {
      console.error('[EmulatorPanel] Error checking breakpoint:', e);
    }
  }, [debugState, pdbData, lastCompiledBinary]);

  // Phase 3: Setup breakpoint checking interval
  useEffect(() => {
    // Limpiar interval previo
    if (breakpointCheckIntervalRef.current !== null) {
      clearInterval(breakpointCheckIntervalRef.current);
      breakpointCheckIntervalRef.current = null;
    }
    
    // Activar verificación cuando estamos en debug session (running O paused)
    // checkBreakpointHit() internamente verifica que solo actúe cuando running
    if (debugState === 'running' || debugState === 'paused') {
      console.log(`[EmulatorPanel] ✓ Starting reactive breakpoint checking (state=${debugState})`);
      breakpointCheckIntervalRef.current = window.setInterval(checkBreakpointHit, 50);
    } else {
      console.log('[EmulatorPanel] Breakpoint checking disabled (stopped)');
    }
    
    return () => {
      if (breakpointCheckIntervalRef.current !== null) {
        clearInterval(breakpointCheckIntervalRef.current);
        breakpointCheckIntervalRef.current = null;
      }
    };
  }, [debugState, checkBreakpointHit]);

  // Phase 3: Listen for debug commands from debugStore
  useEffect(() => {
    const handleDebugMessage = (event: MessageEvent) => {
      console.log('[EmulatorPanel] 🔔 handleDebugMessage received event:', event.data);
      
      if (event.source !== window) {
        console.log('[EmulatorPanel] ⚠️ Event source is not window, ignoring');
        return;
      }
      
      const vecx = (window as any).vecx;
      if (!vecx) {
        console.log('[EmulatorPanel] ⚠️ vecx not initialized');
        return;
      }
      
      const { type, address, line, currentVpyLine } = event.data;
      console.log('[EmulatorPanel] 📨 Message type:', type, 'address:', address, 'line:', line, 'currentVpyLine:', currentVpyLine);

      // Run control drives the engine that owns the panel. These cases used to fall
      // through to JSVecX whenever no rp2350 loop was running, so F12, a step key or
      // MCP emulator_run/stop under the simulator, PiTrex or a stopped uvm2 started
      // the 6809 — and with no cartridge the BIOS boots Minestorm. (debug-stop also
      // called vecx.reset(), which starts the machine again 200 ms later.)
      const RUN_CONTROL = ['debug-continue', 'debug-pause', 'debug-stop',
                           'debug-step-over', 'debug-step-into', 'debug-step-out', 'debug-switch-to-asm'];
      const owner = useEmulatorStore.getState().activeEngine;
      if (RUN_CONTROL.includes(type) && owner !== 'm6809') {
        if (owner === null) {
          console.log(`[EmulatorPanel] ${type} ignored: no program loaded`);
        } else if (type === 'debug-continue') {
          runControlRef.current.play();
        } else if (type === 'debug-pause') {
          runControlRef.current.pause();
        } else if (type === 'debug-stop') {
          runControlRef.current.stop();
        } else {
          console.log(`[EmulatorPanel] ${type} ignored: stepping is for 6809 programs (active: ${owner})`);
        }
        return;
      }

      switch (type) {
        case 'debug-add-breakpoint':
          console.log(`[EmulatorPanel] ➕ Adding breakpoint: line ${line} → address ${address}`);
          if (address !== undefined) {
            // Call WASM API directly
            if (vecx.addBreakpoint) {
              vecx.addBreakpoint(address);
              console.log(`[EmulatorPanel] ✓ Breakpoint added at 0x${address.toString(16)}`);
            } else {
              console.error('[EmulatorPanel] ❌ vecx.addBreakpoint not available');
            }
          }
          break;
          
        case 'debug-remove-breakpoint':
          console.log(`[EmulatorPanel] ➖ Removing breakpoint: line ${line} → address ${address}`);
          if (address !== undefined) {
            // Call WASM API directly
            if (vecx.removeBreakpoint) {
              vecx.removeBreakpoint(address);
              console.log(`[EmulatorPanel] ✓ Breakpoint removed at 0x${address.toString(16)}`);
            } else {
              console.error('[EmulatorPanel] ❌ vecx.removeBreakpoint not available');
            }
          }
          break;
          
        case 'debug-clear-breakpoints':
          console.log('[EmulatorPanel] 🗑️  Clearing all breakpoints');
          if (vecx.clearBreakpoints) {
            vecx.clearBreakpoints();
            console.log('[EmulatorPanel] ✓ All breakpoints cleared');
          }
          break;
          
        case 'debug-continue':
          console.log('[EmulatorPanel] 🟢 Debug: Continue execution');

          // Clear current line highlight
          const debugStoreForContinue = useDebugStore.getState();
          debugStoreForContinue.setCurrentVpyLine(null);
          debugStoreForContinue.setState('running');

          // CRITICAL: Check if paused by breakpoint BEFORE changing state
          const wasPausedByBreakpoint = vecx.isPausedByBreakpoint && vecx.isPausedByBreakpoint();

          // Resume from breakpoint if it was paused by one. resumeFromBreakpoint
          // (vecx.debugContinue) only resumes while vecx.debugState is still
          // 'paused': it sets 'running', skips the breakpoint it stands on and
          // restarts the loop. Setting 'running' first made it a no-op.
          if (wasPausedByBreakpoint && vecx.resumeFromBreakpoint) {
            console.log('[EmulatorPanel] 🔓 Resuming from breakpoint');
            vecx.resumeFromBreakpoint();
            break;
          }
          vecx.debugState = 'running';
          vecx.stepMode = null; // Clear any step mode
          vecx.stepTargetAddress = null;
          console.log('[EmulatorPanel] ✓ JSVecx debugState set to running, step mode cleared');

          if (!vecx.running) {
            // Only call start() if emulator is NOT paused by breakpoint
            initPsgLogging();
            vecx.start();
            console.log('[EmulatorPanel] ✓ Emulator started');
          } else {
            // Already running, just ensure it continues
            vecx.running = true;
            console.log('[EmulatorPanel] ✓ Emulator already running, continuing');
          }
          break;
          
        case 'debug-state-changed':
          // Sync JSVecx debug state to debug store
          const debugStoreForSync = useDebugStore.getState();
          const newState = event.data.state;
          debugStoreForSync.setState(newState);
          console.log('[EmulatorPanel] 🔄 Debug state synced:', newState);
          break;
          
        case 'debug-pause':
          console.log('[EmulatorPanel] ⏸️  Debug: Pause execution');
          // Pause where it is and say where (debugger-paused): the source line is shown,
          // an in-progress step is cancelled. vecx.stop() also silences the PSG.
          if (vecx.debugPause) vecx.debugPause();
          if (vecx.running && vecx.pauseDebugger) vecx.pauseDebugger('manual', vecx.e6809.reg_pc & 0xffff);
          vecx.stop();
          break;

        case 'debug-stop':
          console.log('[EmulatorPanel] 🛑 Debug: Stop execution');
          // Stop and rewind, but stay stopped: vecx.reset() would schedule start()
          // 200 ms later and the program came back by itself.
          vecx.stop();
          vecx.vecx_reset();
          try { vecx.osint.osint_clearscreen(); } catch {}
          vecx.debugState = 'stopped';
          break;
          
        case 'debug-step-over':
          console.log('[EmulatorPanel] ⏭️  Debug: Step over');
          
          // Get debug store first
          const debugStoreForStepOver = useDebugStore.getState();
          
          // Check if we're in ASM debugging mode
          const asmDebuggingMode = (window as any).asmDebuggingMode;
          if (asmDebuggingMode) {
            console.log('[EmulatorPanel] 🔧 ASM debugging mode - executing one instruction');
            
            // In ASM mode, simply execute one instruction and let the emulator tell us the new PC
            // No need to guess instruction sizes or calculate addresses
            debugStoreForStepOver.setState('running');
            if (vecx.debugStepInto) {
              vecx.debugStepInto(false); // Step one instruction, emulator will report new PC
            }
            return; // Skip normal step over logic
          }
          
          // Clear current line highlight before stepping
          debugStoreForStepOver.setCurrentVpyLine(null);
          // NOTE: Do NOT set state to 'running' - Step Over executes instruction-by-instruction in 'paused' mode
          
          if (vecx.debugStepOver) {
            // Calculate target address (next line after current)
            const currentPC = vecx.e6809?.reg_pc;
            const stepOverPdbData = useDebugStore.getState().pdbData;
            // PC === 0 is a valid address (e.g. multibank bank-relative entry of a
            // function placed at the bank's start), so check for undefined, not truthiness.
            if (currentPC !== undefined && stepOverPdbData) {
              // Run to the next statement start (any file: a module's code counts) that
              // is not deeper in the stack: over calls, out of a finished function,
              // past an `if` whose body is skipped, round to the top of loop().
              const targets = statementAddresses(stepOverPdbData as any);
              const s = vecx.e6809?.reg_s?.value ?? 0; // e6809 keeps S as {value}
              console.log(`[EmulatorPanel] Step Over from 0x${currentPC.toString(16)} (S=0x${s.toString(16)}) to the next of ${targets.size} statements`);
              vecx.debugStepOver(targets, s);
            }
          }
          break;
          
        case 'debug-step-into':
          console.log('[EmulatorPanel] 🔽 Debug: Step into');
          {
            const debugStoreForStepInto = useDebugStore.getState();
            if (!vecx.e6809) break;

            // Step until PC maps to a *different* VPy source line. One M6809
            // instruction is rarely enough — a function call may go through a
            // cross-bank trampoline (JSR TRAMP_FOO → bank switch → JMP FOO) and
            // a non-call statement may emit several instructions before the
            // next line's address. So run (in batches, like Step Over) until PC sits
            // on the start of any statement, at any stack depth: into a called
            // function — in whatever file it lives — or on to the next statement.
            const startPC = vecx.e6809.reg_pc;
            const pdb = debugStoreForStepInto.pdbData;
            if (!pdb || !vecx.debugStepOver) break;
            console.log(`[EmulatorPanel] 📍 Step Into from PC ${formatAddress(startPC)}`);
            debugStoreForStepInto.setCurrentVpyLine(null);
            vecx.debugStepOver(statementAddresses(pdb as any), 0);
            // vecx_emu posts 'debugger-paused' where it lands; the handler shows it.
          }
          break;
          
        case 'debug-switch-to-asm':
          console.log('[EmulatorPanel] 🔧 Switching to ASM view WITHOUT executing');
          
          const debugStoreForAsmSwitch = useDebugStore.getState();
          
          // Activate ASM debugging mode (this switches the view)
          (window as any).asmDebuggingMode = true;
          
          // Get current PC and find ASM file path
          const currentPCForSwitch = vecx.e6809?.reg_pc;
          if (currentPCForSwitch !== undefined) {
            const formattedPCSwitch = formatAddress(currentPCForSwitch);
            debugStoreForAsmSwitch.setCurrentAsmAddress(formattedPCSwitch);
            
            // Get ASM file path from lastCompiledBinary
            if (lastCompiledBinary) {
              // Ensure ASM file has proper URI format (file://)
              let asmFile = lastCompiledBinary.replace('.bin', '.asm');
              if (!asmFile.startsWith('file://')) {
                asmFile = 'file://' + asmFile;
              }
              (window as any).asmDebuggingFile = asmFile;
              console.log(`[EmulatorPanel] 📁 ASM file URI: ${asmFile}`);
              
              // Find ASM line for current PC using asmAddressMap
              const currentPdbData = debugStoreForAsmSwitch.pdbData;
              if (currentPdbData?.asmAddressMap) {
                for (const [lineNum, addr] of Object.entries(currentPdbData.asmAddressMap)) {
                  if (addr.toLowerCase() === formattedPCSwitch.toLowerCase()) {
                    const targetLine = parseInt(lineNum, 10);
                    console.log(`[EmulatorPanel] 📍 Found ASM line ${targetLine} for PC ${formattedPCSwitch}`);
                    
                    // Navigate to this line using editorStore
                    const editorStore = useEditorStore.getState();
                    editorStore.gotoLocation(asmFile, targetLine, 1);
                    
                    // Set current line in debug store for highlighting
                    debugStoreForAsmSwitch.setCurrentVpyLine(targetLine);
                    
                    console.log(`[EmulatorPanel] ✓ Navigated to ASM line ${targetLine}`);
                    break;
                  }
                }
              }
            }
          }
          
          // Keep state as 'paused' - don't execute anything
          console.log('[EmulatorPanel] ✓ ASM view switch complete - execution paused at first line');
          break;
          
        case 'debug-step-out':
          console.log('[EmulatorPanel] 🔼 Debug: Step out');
          {
            // Run to the first statement back in the caller: S above this frame's
            // (RTS pops the 2-byte return address)
            const outPdb = useDebugStore.getState().pdbData;
            if (outPdb && vecx.e6809 && vecx.debugStepOver) {
              useDebugStore.getState().setCurrentVpyLine(null);
              vecx.debugStepOver(statementAddresses(outPdb as any), ((vecx.e6809.reg_s?.value ?? 0) + 2) & 0xffff);
              break;
            }
          }
          if (vecx.debugStepOut) {
            vecx.debugStepOut();
            console.log('[EmulatorPanel] ✓ Step out executed');
          }
          break;
          
        case 'debugger-paused':
          console.log('[EmulatorPanel] 🔴 Debugger paused:', event.data);
          // Update debugStore state to 'paused'
          const debugStore = useDebugStore.getState();
          debugStore.setState('paused');
          
          // Get pdbData from store directly (not from hook)
          const currentPdbData = debugStore.pdbData;
          
          if (event.data.pc && currentPdbData) {
            const pcHex = event.data.pc.replace('0x', '').toLowerCase();
            
            // Check if we're in ASM debugging mode
            const asmDebuggingMode = (window as any).asmDebuggingMode;
            if (asmDebuggingMode) {
              console.log(`[EmulatorPanel] 🔧 ASM debugging mode - checking if PC is back in VPy code: ${event.data.pc}`);
              
              // Check if PC is back in VPy code range - if so, exit ASM mode and switch to VPy file
              let backInVpy = false;
              let vpyLine = null;
              
              // Back in a VPy statement? Then leave ASM mode for that statement's file.
              const backAt = sourceAt(currentPdbData as any, parseInt(pcHex, 16));
              if (backAt) {
                vpyLine = backAt.line;
                console.log(`[EmulatorPanel] 🔄 PC back in VPy code at ${backAt.file}:${vpyLine} - exiting ASM debugging mode`);
                (window as any).asmDebuggingMode = false;
                (window as any).asmDebuggingFile = null;
                backInVpy = true;
                debugStore.setCurrentVpyLineWithFile(backAt.line, backAt.file);
                showProjectSource(backAt.file, backAt.line);
              }
              
              // If still in ASM, try to find the exact ASM line using asmLineMap
              if (!backInVpy) {
                console.log(`[EmulatorPanel] 🔧 Still in ASM debugging mode - looking for ASM line at PC: ${event.data.pc}`);
                console.log(`[EmulatorPanel] 🔍 Debug mode: ${event.data.mode}, expecting step navigation`);
                
                // Use asmLineMap (address → line) to find the ASM line
                if (currentPdbData.asmLineMap) {
                  let foundAsmLine = null;
                  const pcKey = event.data.pc; // e.g., "0x009E"
                  
                  console.log(`[EmulatorPanel] 🔍 Looking for ${pcKey} in asmLineMap`);
                  
                  // Direct lookup in asmLineMap (address → line mapping)
                  if (currentPdbData.asmLineMap[pcKey]) {
                    foundAsmLine = currentPdbData.asmLineMap[pcKey].line;
                    console.log(`[EmulatorPanel] 📍 Found exact ASM line ${foundAsmLine} for address ${pcKey}`);
                  } else {
                    console.log(`[EmulatorPanel] ⚠️ No exact match for ${pcKey} in asmLineMap - keeping current line`);
                    // DEBUG: Show what keys are available near this address
                    const currentPC = parseInt(pcKey, 16);
                    const nearbyKeys = Object.keys(currentPdbData.asmLineMap || {})
                      .map(key => ({ key, addr: parseInt(key, 16) }))
                      .filter(entry => Math.abs(entry.addr - currentPC) <= 10)
                      .sort((a, b) => a.addr - b.addr)
                      .map(entry => `${entry.key}→${currentPdbData.asmLineMap![entry.key].line}`);
                    console.log(`[EmulatorPanel] 🔍 Nearby asmLineMap entries: ${nearbyKeys.join(', ')}`);
                  }
                  
                  // If we found the ASM line, check if it's executable or just a comment
                  if (foundAsmLine && (window as any).asmDebuggingFile) {
                    const editorStore = useEditorStore.getState();
                    const debugStore = useDebugStore.getState();
                    
                    // Get the line content from the editor to check if it's executable
                    const asmDoc = editorStore.documents.find(d => d.uri === (window as any).asmDebuggingFile);
                    
                    if (asmDoc) {
                      // Get the line content (foundAsmLine is 1-based, array is 0-based)
                      const lines = asmDoc.content.split('\n');
                      let targetLine = foundAsmLine;
                      let lineContent = lines[foundAsmLine - 1] || '';
                      const trimmedContent = lineContent.trim();
                      
                      // If this line is ONLY a comment (starts with ';' or is empty), find next executable line
                      if (trimmedContent.startsWith(';') || trimmedContent === '') {
                        console.log(`[EmulatorPanel] ⚠️ Line ${foundAsmLine} is comment/empty: "${trimmedContent}"`);
                        console.log(`[EmulatorPanel] 🔍 Searching for next executable line...`);
                        
                        // Search forward for the next non-comment, non-empty line
                        for (let i = foundAsmLine; i < Math.min(foundAsmLine + 10, lines.length); i++) {
                          const nextContent = lines[i].trim();
                          if (nextContent && !nextContent.startsWith(';')) {
                            targetLine = i + 1; // Convert back to 1-based
                            console.log(`[EmulatorPanel] ✅ Found executable line ${targetLine}: "${nextContent}"`);
                            break;
                          }
                        }
                      }
                      
                      // Navigate to the target line (executable, not comment)
                      // gotoLocation adds +1 internally, so we pass targetLine - 1
                      editorStore.gotoLocation((window as any).asmDebuggingFile, targetLine - 1, 0);
                      debugStore.setCurrentVpyLine(targetLine); // Highlight ASM line
                      console.log(`[EmulatorPanel] ✅ Navigated to ASM line ${targetLine} in ${(window as any).asmDebuggingFile}`);
                    } else {
                      console.log(`[EmulatorPanel] ⚠ ASM document not loaded in editor store - falling back to PDB line`);
                      // Fallback: navigate to PDB line even if we can't verify it
                      editorStore.gotoLocation((window as any).asmDebuggingFile, foundAsmLine - 1, 0);
                      debugStore.setCurrentVpyLine(foundAsmLine);
                      console.log(`[EmulatorPanel] ✅ Navigated to ASM line ${foundAsmLine} (fallback) in ${(window as any).asmDebuggingFile}`);
                    }
                  } else if (!foundAsmLine) {
                    console.log(`[EmulatorPanel] ⚠ Could not find ASM line for address ${pcKey} - no mapping available`);
                  }
                } else {
                  console.log(`[EmulatorPanel] ❌ No asmLineMap in PDB data`);
                }
                return;
              }
            }
            
            // The statement at the PC, in its own file (an imported module too)
            let foundInVpy = false;
            const here = sourceAt(currentPdbData as any, parseInt(pcHex, 16));
            if (here) {
              const { file: vpyFileName, line: lineNumber } = here;
              console.log(`[EmulatorPanel] 📍 Highlighting VPy line ${lineNumber} in ${vpyFileName} (PC: ${event.data.pc})`);
              debugStore.setCurrentVpyLineWithFile(lineNumber, vpyFileName);
              showProjectSource(vpyFileName, lineNumber);
              foundInVpy = true;
            }
            
            // If not in VPy range, we're in ASM (native call or generated code)
            if (!foundInVpy && (event.data.mode === 'step' || event.data.mode === 'breakpoint')) {
              const modeText = event.data.mode === 'step' ? 'Step Into entered' : 'Breakpoint hit in';
              console.log(`[EmulatorPanel] 🔧 ${modeText} ASM code at PC: ${event.data.pc}`);
              
              // Get the native function we're stepping into (stored temporarily during step-into)
              const targetNativeFunction = (window as any).lastStepIntoNativeFunction;
              const skipAutoNavigation = (window as any).skipAutoNavigation; // Flag to skip re-navigation
              if (targetNativeFunction) {
                console.log(`[EmulatorPanel] 🎯 Stepping into native function: ${targetNativeFunction}`);
                // Clear the temporary storage
                (window as any).lastStepIntoNativeFunction = null;
              }
              
              // If we already navigated manually (Step Into to native), skip automatic navigation
              if (skipAutoNavigation) {
                console.log(`[EmulatorPanel] ⏭️  Skipping automatic navigation - already at target line from Step Into`);
                (window as any).skipAutoNavigation = false; // Clear flag
                return;
              }
              
              // Open ASM file in new editor and highlight the line
              if (currentPdbData.asm && currentPdbData.asmLineMap) {
                // Look up the specific ASM file and line from asmLineMap
                // event.data.pc is a string like "0x4168", so parse it correctly
                const pcStr = event.data.pc.toString().replace(/^0x/i, ''); // Remove 0x prefix if present
                const pcHex = pcStr.toUpperCase().padStart(4, '0');
                const pcKey = `0x${pcHex}`;
                
                // Try exact match first
                let asmEntry = currentPdbData.asmLineMap[pcKey];
                
                // If exact match not found, look for closest address <= PC
                if (!asmEntry) {
                  const pcValue = parseInt(pcHex, 16);
                  let closestAddr = -1;
                  let closestEntry = null;
                  
                  for (const [addrStr, entry] of Object.entries(currentPdbData.asmLineMap)) {
                    const addrValue = parseInt(addrStr.replace(/^0x/i, ''), 16);
                    if (addrValue <= pcValue && addrValue > closestAddr) {
                      closestAddr = addrValue;
                      closestEntry = entry;
                    }
                  }
                  
                  if (closestEntry) {
                    asmEntry = closestEntry;
                    console.log(`[EmulatorPanel] 📍 Found closest ASM mapping for ${pcKey}: ${closestAddr.toString(16).toUpperCase()}`);
                  }
                }
                
                if (!asmEntry) {
                  console.warn(`[EmulatorPanel] ⚠️ No ASM line mapping found for PC: ${pcKey} (raw: ${event.data.pc})`);
                  return;
                }
                
                const asmLineNumber = asmEntry.line || 1;
                const isMultibank = currentPdbData.romConfig?.isMultibank || false;
                
                // Construct ASM filename
                // Multibank: bank_0.asm, bank_1.asm, etc.
                // Single-bank: main.asm (or {project_name}.asm)
                const asmFileName = isMultibank ? `bank_${asmEntry.bankId}.asm` : `main.asm`;
                
                // Get directory from the binary path (which is in src/)
                const editorStore = useEditorStore.getState();
                
                // Get the project root by going up from src directory
                // examples/test_incremental/src -> examples/test_incremental
                const binPath = lastCompiledBinary!;
                const srcDir = binPath.substring(0, binPath.lastIndexOf('/'));
                const projectRoot = srcDir.substring(0, srcDir.lastIndexOf('/'));
                
                let asmPath: string;
                if (lastCompiledBinary) {
                  // For ASM file resolution:
                  // Binary is at: examples/test_incremental/src/main.bin
                  // ASM files are at: examples/test_incremental/build/  (single-bank) or 
                  //                  examples/test_incremental/build/asm/ (multibank)
                  
                  // Construct path based on single-bank or multibank
                  if (isMultibank) {
                    asmPath = `${projectRoot}/build/asm/${asmFileName}`;
                    console.log(`[EmulatorPanel] 📂 Opening multibank ASM: ${asmPath}`);
                  } else {
                    asmPath = `${projectRoot}/build/${asmFileName}`;
                    console.log(`[EmulatorPanel] 📂 Opening single-bank ASM: ${asmPath}`);
                  }
                } else {
                  console.error(`[EmulatorPanel] ❌ No lastCompiledBinary available`);
                  return;
                }
                
                // Check if Electron API is available
                if (!(window as any).files?.readFile) {
                  console.warn(`[EmulatorPanel] ⚠️ Electron file API not available - cannot open ASM file`);
                  return;
                }
                
                // Try to read the ASM file, with fallback for single-bank naming
                const tryReadAsmFile = (path: string): Promise<{content?: string; error?: string}> => {
                  return new Promise((resolve) => {
                    (window as any).files.readFile(path).then((result: {content?: string; error?: string}) => {
                      if (!result.error) {
                        resolve(result);
                      } else {
                        // Fallback for single-bank: try {project_name}.asm if main.asm not found
                        if (!isMultibank && asmFileName === 'main.asm') {
                          const projectName = projectRoot.substring(projectRoot.lastIndexOf('/') + 1);
                          const fallbackPath = `${projectRoot}/build/${projectName}.asm`;
                          console.log(`[EmulatorPanel] 📂 main.asm not found, trying fallback: ${fallbackPath}`);
                          (window as any).files.readFile(fallbackPath).then(resolve);
                        } else {
                          resolve(result);
                        }
                      }
                    });
                  });
                };
                  
                  // Read ASM file with fallback
                  tryReadAsmFile(asmPath).then((result: {content?: string; error?: string}) => {
                    if (result.error) {
                      console.error(`[EmulatorPanel] ❌ Error reading ASM file: ${result.error}`);
                      return;
                    }
                    const content = result.content;
                    if (!content) {
                      console.error(`[EmulatorPanel] ❌ No content in ASM file`);
                      return;
                    }
                    // Use the line number directly from asmLineMap (multibank architecture)
                    console.log(`[EmulatorPanel] ✅ Opening ASM at line ${asmLineNumber} from asmLineMap`);
                    const targetLine = asmLineNumber;
                    
                    // Open ASM file in editor
                    const asmUri = `file://${asmPath}`;
                    editorStore.openDocument({
                      uri: asmUri,
                      content: content,
                      language: 'vpy', // Monaco will use generic highlighting
                      dirty: false,
                      mtime: Date.now(),
                      diagnostics: []
                    });
                    
                    // Set as active and navigate to line
                    editorStore.setActive(asmUri);
                    console.log(`[EmulatorPanel] 🔍 Navigating to line ${targetLine} in ${asmUri}`);
                    // gotoLocation adds +1 internally (converts to 1-based), so we pass targetLine - 1
                    editorStore.gotoLocation(asmUri, targetLine - 1, 0);
                    
                    // Set flag to skip automatic navigation on next debugger-paused event
                    // (prevents re-navigation to closest PC address after Step Into)
                    (window as any).skipAutoNavigation = true;
                    
                    // Verify navigation worked
                    setTimeout(() => {
                      const currentActive = useEditorStore.getState().active;
                      console.log(`[EmulatorPanel] 📍 After navigation - active: ${currentActive}`);
                    }, 200);
                    
                    // Update debug store to highlight the current ASM line
                    debugStore.setCurrentVpyLine(targetLine); // Set ASM line for highlighting
                    debugStore.setState('paused'); // Keep debugger paused, but ready for ASM stepping
                    
                    // Set a flag to indicate we're in ASM debugging mode
                    (window as any).asmDebuggingMode = true;
                    (window as any).asmDebuggingFile = asmUri;
                    
                    console.log(`[EmulatorPanel] 🔧 Switched to ASM debugging mode at line ${targetLine}`);
                    
                    // TODO: Auto-continue disabled for debugging navigation issues
                    // setTimeout(() => {
                    //   console.log(`[EmulatorPanel] 🔄 Auto-continuing step into for ASM debugging`);
                    //   const vecxInstance = (window as any).vecx;
                    //   if (vecxInstance && vecxInstance.debugStepInto) {
                    //     vecxInstance.debugStepInto(false); // Continue stepping, but not as native call anymore
                    //   }
                    // }, 100);
                    
                  }).catch((err: any) => {
                    console.error(`[EmulatorPanel] ❌ Failed to read ASM file: ${err}`);
                  });
              }
            }
          }
          break;
      }
    };
    
    console.log('[EmulatorPanel] ✅ Registering message listener for debug events');
    window.addEventListener('message', handleDebugMessage);
    return () => {
      console.log('[EmulatorPanel] ❌ Unregistering message listener');
      window.removeEventListener('message', handleDebugMessage);
    };
  }, [addBreakpoint, removeBreakpoint, pdbData]);

  /* THE `debug-continue-hotkey` LISTENER LIVED HERE AND IT OWNED F5.
   *
   * main.ts intercepted bare F5 in `before-input-event` and sent this event, so F5 meant
   * "continue the 6809 emulator" — and on a project with no 6809 cartridge loaded that
   * boots the BIOS, which is Minestorm. It had already been patched once, for external C
   * projects only, which is why the fault survived: it looked handled.
   *
   * F5 now routes to build.run from main.ts like every other build key. Continuing a
   * paused debug session is F12 (debug.continue) — it has its own key and does not need
   * to borrow this one. Removed 2026-08-25.
   */

  // Función para cargar ROM desde dropdown (definida antes de useEffects que la usan)
  const loadROMFromDropdown = useCallback(async (romName: string) => {
    if (!romName) return;
    
    try {
      console.log(`[EmulatorPanel] Loading ROM from dropdown: ${romName}`);
      
      const response = await fetch(`/roms/${romName}`);
      if (!response.ok) {
        console.error(`[EmulatorPanel] Failed to fetch ROM: ${response.status}`);
        return;
      }
      
      const arrayBuffer = await response.arrayBuffer();
      const romData = new Uint8Array(arrayBuffer);
      
      const vecx = (window as any).vecx;
      if (!vecx) {
        console.error('[EmulatorPanel] vecx instance not available');
        return;
      }

      // A new program: nothing else may keep running or sounding.
      stopAllEngines('ROM from dropdown');
      setActiveEngine('m6809');
      setRunMode(null);
      setShowPitrexOverlay(false);
      
      // Convertir Uint8Array a string para JSVecX
      let cartDataString = '';
      for (let i = 0; i < romData.length; i++) {
        cartDataString += String.fromCharCode(romData[i]);
      }
      
      // Cargar ROM en Globals.cartdata (método correcto para JSVecX)
      const Globals = (window as any).Globals || (globalThis as any).Globals;
      if (!Globals) {
        console.error('[EmulatorPanel] Globals not available');
        return;
      }
      
      Globals.cartdata = cartDataString;
      console.log(`[EmulatorPanel] ✓ ROM loaded into Globals.cartdata (${romData.length} bytes)`);
      
      // Dispatch event para notificar a otros paneles
      window.dispatchEvent(new Event('programLoaded'));
      
      // Actualizar estado del ROM cargado
      setLoadedROM(`${romName} (${romData.length} bytes)`);
      
      // Cargar overlay automáticamente
      await loadOverlay(romName);
      
      // Reset DOBLE después de cargar - esto copiará cartdata al array cart[]
      // Primer reset para cargar cartdata
      console.log('🔄 [EmulatorPanel] CALLING vecx.reset() - Reason: First reset after ROM load');
      console.log('📍 [EmulatorPanel] Reset stack trace:', new Error().stack);
      vecx.reset();
      console.log('[EmulatorPanel] ✓ First reset after ROM load');
      
      // Esperar un poco y hacer segundo reset para asegurarse
      setTimeout(() => {
        console.log('🔄 [EmulatorPanel] CALLING vecx.reset() - Reason: Second reset after ROM load');
        console.log('📍 [EmulatorPanel] Reset stack trace:', new Error().stack);
        vecx.reset();   // starts the cartridge 200 ms later (vecx.js reset())
        console.log('[EmulatorPanel] ✓ Second reset after ROM load');
        // (A `status === 'running'` restart lived here; `status` was the closure's, not
        // the current one, and reset() starts the machine anyway.)
        vecx.debugState = 'running';
        setStatus('running');
        useDebugStore.getState().setState('running');
        
        // CRÍTICO: Aplicar estado de audio después de reset/start
        setTimeout(() => {
          applyAudioState();
        }, 100);
      }, 50);
      
    } catch (error) {
      console.error('[EmulatorPanel] Failed to load ROM from dropdown:', error);
    }
  }, [loadOverlay, applyAudioState, stopAllEngines, setActiveEngine, setStatus]);

  // Auto-load last ROM on emulator start - DISABLED (user loads manually)
  /*
  useEffect(() => {
    console.log('[EmulatorPanel] Auto-load ROM check:', {
      lastRomName,
      selectedROM,
      availableROMs: availableROMs.length,
      loadedROM,
      condition1: !!lastRomName,
      condition2: availableROMs.length > 0,
      condition3: !loadedROM?.includes(lastRomName || '')
    });
    
    // Only auto-load if we have a stored ROM, available ROMs are loaded, and we haven't loaded this ROM yet
    if (lastRomName && availableROMs.length > 0 && !loadedROM?.includes(lastRomName)) {
      console.log('[EmulatorPanel] Auto-restoring last ROM:', lastRomName, 'from', availableROMs.length, 'available ROMs');
      setSelectedROM(lastRomName);
      // If it's in the dropdown, load it automatically
      if (availableROMs.includes(lastRomName)) {
        console.log('[EmulatorPanel] ✓ Found ROM in list, loading automatically:', lastRomName);
        loadROMFromDropdown(lastRomName);
      } else {
        console.log('[EmulatorPanel] ⚠️ ROM not found in available list:', lastRomName, 'Available:', availableROMs);
      }
    }
  }, [lastRomName, availableROMs]); // Fixed: removed loadedROM to prevent reset loop when ROM display changes
  */

  // The audio effects below are keyed on `status`, which EVERY engine sets ('running'
  // also means the simulator, rp2350, uvm2 or PiTrex is running). They drive the 6809's
  // audio only, and only while the 6809 owns the panel: otherwise a 'running' from
  // another engine restarted the 6809's sound underneath it.
  const m6809Active = activeEngine === 'm6809';

  // Apply initial audio state when emulator starts
  useEffect(() => {
    if (status === 'running' && m6809Active) {
      applyAudioState();
    }
  }, [status, applyAudioState, m6809Active]); // Apply when status changes to running

  // Audio lifecycle: init worklet on enable; start/stop with status
  useEffect(() => {
    (async () => {
      if (audioEnabled) {
        try {
          await psgAudio.init();
          if (useEmulatorStore.getState().status === 'running'
              && useEmulatorStore.getState().activeEngine === 'm6809') psgAudio.start();
        } catch(e) {
          console.warn('[EmulatorPanel] audio init failed', e);
        }
      } else {
        psgAudio.stop();
      }
    })();
  }, [audioEnabled]);

  useEffect(() => {
    if (!audioEnabled) return;
    if (status === 'running' && m6809Active) {
      psgAudio.start();
    } else {
      psgAudio.stop();
    }
  }, [status, audioEnabled, m6809Active]);

  // Poll de estadísticas de audio (cada ~500ms mientras audioEnabled)
  useEffect(() => {
    if (!audioEnabled) { 
      setAudioStats(null); 
      return; 
    }
    let cancelled = false;
    const tick = () => {
      try {
        const s = psgAudio.getStats?.();
        if (s && !cancelled) setAudioStats(s);
      } catch {/* ignore */}
    };
    tick();
    const id = setInterval(tick, 500);
    return () => { 
      cancelled = true; 
      clearInterval(id); 
    };
  }, [audioEnabled]);

  // Helper: Initialize PSG logging before starting emulator
  const initPsgLogging = () => {
    const win = window as any;
    if (!win.PSG_WRITE_LOG) win.PSG_WRITE_LOG = [];
    win.PSG_WRITE_LOG.length = 0;
    win.PSG_LOG_ENABLED = false;  // disabled by default — enable via DevTools: window.PSG_LOG_ENABLED=true
    win.PSG_LOG_LIMIT = 10000;
  };

  // Initialize PSG log array (disabled by default for performance)
  useEffect(() => {
    const win = window as any;
    if (!win.PSG_WRITE_LOG) win.PSG_WRITE_LOG = [];
    win.PSG_LOG_ENABLED = false;  // disabled by default
    win.PSG_LOG_LIMIT = 10000;
  }, []);

  const onSnapshotROM = () => {
    const vecx = (window as any).vecx;
    if (!vecx || status !== 'paused') {
      console.error('[EmulatorPanel] Snapshot failed - emulator not paused');
      return;
    }

    try {
      // Create 32KB snapshot: [Bank 0 at 0x0000-0x3FFF] + [Bank 31 at 0x4000-0x7FFF]
      // Using vecx.read8() which handles all the complexity:
      // - Single-bank vs multibank detection
      // - Reading from correct container (cart or multibankRom)
      // - Bank switching via currentBank for 0x0000-0x3FFF
      // - Fixed bank #31 mapping for 0x4000-0x7FFF
      const snapshot = new Uint8Array(0x8000);
      for (let addr = 0x0000; addr < 0x8000; addr++) {
        snapshot[addr] = vecx.read8(addr);
      }

      // Download as binary file
      const blob = new Blob([snapshot], { type: 'application/octet-stream' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `rom_snapshot_bank${vecx.currentBank || 0}_and_31.bin`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);

      console.log(`[EmulatorPanel] ✓ ROM snapshot downloaded via read8() - Bank ${vecx.currentBank || 0} + Bank 31 (32KB total)`);
    } catch (e) {
      console.error('[EmulatorPanel] Snapshot error:', e);
    }
  };

  const onDecompileROM = async () => {
    const vecx = (window as any).vecx;
    if (!vecx || status !== 'paused') {
      console.error('[EmulatorPanel] Decompile failed - emulator not paused');
      alert('❌ Emulator must be paused to decompile ROM');
      return;
    }

    try {
      // Capturar 32KB: [Bank 0 at 0x0000-0x3FFF] + [Bank 31 at 0x4000-0x7FFF]
      const snapshot = new Uint8Array(0x8000);
      for (let addr = 0x0000; addr < 0x8000; addr++) {
        snapshot[addr] = vecx.read8(addr);
      }
      
      // Convertir a base64
      const base64 = btoa(String.fromCharCode(...snapshot));
      
      // Usar decompilador real (cargo run --bin disasm_full)
      const api = (window as any).electronAPI;
      if (!api?.disassembleSnapshot) {
        console.error('[EmulatorPanel] electronAPI.disassembleSnapshot not available');
        alert('❌ Decompile API not available');
        return;
      }
      
      // Backend calcula automáticamente cuántas instrucciones desensamblar basándose en el tamaño del snapshot
      // Enviar ruta del binario compilado para que backend guarde en la misma carpeta
      const result = await api.disassembleSnapshot({ base64, startHex: '0', binPath: lastCompiledBinary || undefined });
      if (!result?.ok) {
        console.error('[EmulatorPanel] Decompile failed:', result?.error, result?.stderr);
        alert('❌ Decompile failed: ' + (result?.error || 'unknown error'));
        return;
      }
      
      // Mostrar rutas de archivos guardados
      const message = result.message || `Disassembly saved to:\n${result.dissPath || 'unknown path'}`;
      console.log('[EmulatorPanel] 📖 Disassembly Complete:', message);
      console.log('Snapshot:', result.snapshotPath);
      console.log('Disassembly:', result.dissPath);
      alert(`✅ ${message}`);
      
    } catch (e) {
      console.error('[EmulatorPanel] Decompile error:', e);
      alert('❌ Decompilation failed: ' + (e as Error).message);
    }
  };

  // ── PiTrex RAF loop launcher ────────────────────────────────────────────────
  // Extracted so it can be called both from handleCompiledBin and from onReset.
  // Requires pitrexCoreRef.current to be a loaded, ready PitrexCore instance.
  const startPitrexRafLoop = useCallback(() => {
    // Cancel any previous RAF loop before starting a new one
    if (pitrexLoopRef.current !== null) {
      cancelAnimationFrame(pitrexLoopRef.current);
      pitrexLoopRef.current = null;
    }

    const PITREX_MAX_X = 16500;
    // PITREX_MAX_Y = ALG_MAX_Y/2 = 20500. The Vectrex screen is portrait (9×11 cm),
    // so the Y range in JSVecX is 41000 (half=20500) while X is 33000 (half=16500).
    // Both axes share T1 period ≈127 cycles, producing 127×127=16129 units per axis.
    // Scale: 16129 / 20500 × 205px ≈ 161px from center — same as X (161px), isotropic.
    const PITREX_MAX_Y = 20500;
    const TARGET_MS = 1000 / 50; // 50 Hz
    let lastFrameTs = 0;

    const loop = (ts: number) => {
      pitrexLoopRef.current = requestAnimationFrame(loop);
      const elapsed = ts - lastFrameTs;
      if (elapsed < TARGET_MS) return;
      lastFrameTs = ts - (elapsed % TARGET_MS);

      if (useDebugStore.getState().state !== 'running') return;

      const canvas = canvasRef.current;
      if (!canvas) return;
      const ctx = canvas.getContext('2d');
      if (!ctx) return;

      const W = canvas.width;
      const H = canvas.height;
      const scaleX = (W / 2) / PITREX_MAX_X;
      const scaleY = (H / 2) / PITREX_MAX_Y;
      const cx = W / 2;
      const cy = H / 2;

      ctx.fillStyle = '#000000';
      ctx.fillRect(0, 0, W, H);

      const result = pitrexCoreRef.current?.runFrame() ?? { segments: [], texts: [], timeout: false };
      const { segments, timeout } = result;

      for (const seg of segments) {
        if (seg.intensity <= 0) continue;
        const x0p = cx + seg.x0 * scaleX;
        const y0p = cy - seg.y0 * scaleY;
        const x1p = cx + seg.x1 * scaleX;
        const y1p = cy - seg.y1 * scaleY;
        const bright = Math.min(seg.intensity, 127);
        const lum = Math.round(bright * 255 / 127);
        ctx.strokeStyle = `rgb(${lum},${lum},${lum})`;
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(x0p, y0p);
        ctx.lineTo(x1p, y1p);
        ctx.stroke();
      }

      if (timeout) {
        ctx.fillStyle = 'rgba(255, 80, 80, 0.85)';
        ctx.font = '11px monospace';
        ctx.fillText('TIMEOUT — infinite loop?', 8, 16);
      }
    };

    pitrexLoopRef.current = requestAnimationFrame(loop);
    console.log('[EmulatorPanel] pitrex RAF loop started');
  }, []); // no deps — reads refs directly

  // ── rp2350 / uvm2 rAF loop launcher ─────────────────────────────────────────
  // ONE loop for both systems (emuCore.runFrame dispatches on the active target),
  // shared by every path that loads an ARM image and by Play / Reset. Capped at
  // 50 fps: rAF fires at the display rate (120/144 Hz on many monitors) and the game
  // logic would otherwise run faster than the 6809 path, which the 50 Hz VIA timer
  // paces (Vectrex PAL; music compiled at 50 Hz).
  const startArmRafLoop = useCallback(() => {
    if (rp2350LoopRef.current !== null) {
      cancelAnimationFrame(rp2350LoopRef.current);
      rp2350LoopRef.current = null;
    }
    const TARGET_MS = 1000 / 50;  // 20 ms per frame
    let frames = 0;
    let lastFrameTs = 0;
    /* FRAME COUNTER over a one-second window. Counts the frames the emulator PRODUCES,
     * not the ones rAF asks for: with the image running slowly the loop skips turns and
     * counting requests would always read 50. */
    let ventana = 0, desde = 0;
    const loop = (ts: number) => {
      rp2350LoopRef.current = requestAnimationFrame(loop);
      const elapsed = ts - lastFrameTs;
      if (elapsed < TARGET_MS) return;          // too soon — skip
      lastFrameTs = ts - (elapsed % TARGET_MS); // align to 50 Hz grid
      // Honour pause/stop from debug controls
      if (useDebugStore.getState().state !== 'running') return;
      frames++;
      if ((window as any).RP2350_DEBUG && (frames <= 5 || frames % 120 === 0)) {
        console.log(`[EmulatorPanel] rp2350 rAF loop frame ${frames}`);
      }
      emuCore.runFrame();
      ventana++;
      if (!desde) desde = ts;
      else if (ts - desde >= 1000) {
        const fps = (ventana * 1000) / (ts - desde);
        /* Frame bus cycles -> the refresh the drawing would allow on the console.
         * The UVM2 bus clock is 1.5 MHz (30000 cycles x 50 Hz). */
        const BUS_HZ = 30000 * 50;
        const st = (emuCore as any).uvm2FrameStats;
        useDebugStore.getState().updateStats(
          st?.ciclos ?? 0, fps, st?.ciclos ? BUS_HZ / st.ciclos : 0);
        ventana = 0; desde = ts;
      }
    };
    // Mark as running so the loop doesn't bail on the first check.
    useDebugStore.getState().setState('running');
    rp2350LoopRef.current = requestAnimationFrame(loop);
    console.log('[EmulatorPanel] ✓ rp2350/uvm2 rAF loop started');
  }, []); // no deps — reads refs directly

  // Clear the shared canvas (the previous engine's last frame stays on it otherwise).
  const clearCanvas = useCallback(() => {
    if (canvasRef.current) {
      const ctx = canvasRef.current.getContext('2d');
      if (ctx) {
        ctx.fillStyle = '#000000';
        ctx.fillRect(0, 0, canvasRef.current.width, canvasRef.current.height);
      }
    }
  }, []);

  // Play / Pause / Stop / Reset act on the engine that owns the panel (activeEngine),
  // never on "whatever ref happens to be set": the rp2350 system object outlives its
  // run, so testing for it sent Stop to rp2350 while the 6809 played on, and every
  // case that fell through to the JSVecX branch booted the BIOS behind the real engine.
  const onPlay = () => {
    const engine = useEmulatorStore.getState().activeEngine;

    if (engine === 'sim') {
      // WASM simulator stopped by Stop: start it again from the beginning.
      if (!simModulePath && stoppedSimRef.current) {
        const { path, romZip } = stoppedSimRef.current;
        stoppedSimRef.current = null;
        setSimModule(path, romZip);
        useDebugStore.getState().setState('running');
        setStatus('running');
        setEmulatorRunning(true);
        console.log('[EmulatorPanel] WASM simulator restarted');
      }
      return;
    }

    // PiTrex mode: the RAF loop already runs; just ungate it via debugStore state
    if (engine === 'pitrex') {
      if (!pitrexCoreRef.current) { console.log('[EmulatorPanel] PiTrex: nothing loaded — build again'); return; }
      useDebugStore.getState().setState('running');
      setStatus('running');
      setEmulatorRunning(true);
      // Ensure the RAF loop is actually running (may have been stopped on reset)
      if (pitrexLoopRef.current === null) {
        if (audioEnabled) pitrexCoreRef.current.startAudio();
        startPitrexRafLoop();
      }
      console.log('[EmulatorPanel] PiTrex resumed');
      return;
    }

    if (engine === 'rp2350' || engine === 'uvm2') {
      if (rp2350LoopRef.current === null) {
        // Stopped: start the same image again from the beginning.
        if (!armReloadRef.current) { console.log(`[EmulatorPanel] ${engine}: nothing loaded — build again`); return; }
        armReloadRef.current();
        clearCanvas();
        startArmRafLoop();
      }
      setArmAudioSuspended(!audioEnabled);
      useDebugStore.getState().setState('running');
      setStatus('running');
      setEmulatorRunning(true);
      console.log(`[EmulatorPanel] ${engine} running`);
      return;
    }

    // The 6809 — also when nothing is loaded yet: pressing Play is the explicit start
    // of the BIOS / inserted cartridge.
    if (engine !== 'm6809') {
      stopAllEngines('Play (6809)');
      setActiveEngine('m6809');
    }
    const vecx = (window as any).vecx;
    if (vecx) {
      // Si estaba stopped, reiniciar desde el principio
      if (status === 'stopped') {
        console.log('[EmulatorPanel] Starting from stopped - resetting first');
        vecx.stop();
        console.log('🔄 [EmulatorPanel] CALLING vecx.reset() - Reason: Start from stopped state');
        vecx.reset();

        // Reinicializar joystick a valores neutros
        vecx.write8(0xC81B, 0); // Vec_Joy_1_X neutral (signed $00 = center)
        vecx.write8(0xC81C, 0); // Vec_Joy_1_Y neutral (signed $00 = center)
      }

      initPsgLogging();
      vecx.debugState = 'running';
      vecx.start();
      setStatus('running');
      useDebugStore.getState().setState('running');
      setEmulatorRunning(true); // Persist state
      console.log('[EmulatorPanel] JSVecX started, debugStore.state set to running');
    }
  };

  const onPause = () => {
    const engine = useEmulatorStore.getState().activeEngine;
    // The WASM simulator has no pause. Do not leave the debugger reading 'paused':
    // F5 / Shift+F5 treat that as a 6809 debug session waiting to continue.
    if (engine === 'sim') {
      useDebugStore.getState().setState(simModulePath ? 'running' : 'stopped');
      console.log('[EmulatorPanel] The WASM simulator has no pause (Stop ends it, Play restarts it)');
      return;
    }

    // PiTrex mode: gate the RAF loop by setting debugStore state to 'paused'
    if (engine === 'pitrex') {
      useDebugStore.getState().setState('paused');
      setStatus('paused');
      console.log('[EmulatorPanel] PiTrex paused (RAF loop gated)');
      return;
    }

    // rp2350 / uvm2: the loop skips frames while paused; the context is suspended so
    // the last PSG state does not sustain as a note.
    if (engine === 'rp2350' || engine === 'uvm2') {
      useDebugStore.getState().setState('paused');
      setStatus('paused');
      setArmAudioSuspended(true);
      console.log(`[EmulatorPanel] ${engine} paused`);
      return;
    }

    const vecx = (window as any).vecx;
    if (vecx) {
      vecx.stop();
      setStatus('paused');
      useDebugStore.getState().setState('paused');
      // NOTE: No cambiar emulatorWasRunning - pause es temporal, mantener el estado de "estaba corriendo"
      console.log('[EmulatorPanel] JSVecX paused, debugStore.state set to paused');
    }
  };

  const onStop = () => {
    const engine = useEmulatorStore.getState().activeEngine;
    // WASM simulator: unmount it (its teardown ends the program and closes its audio).
    if (engine === 'sim') {
      if (simModulePath) {
        stoppedSimRef.current = { path: simModulePath, romZip: useEmulatorStore.getState().simRomZip ?? null };
        setSimModule(null);
      }
      useDebugStore.getState().setState('stopped');
      setStatus('stopped');
      setEmulatorRunning(false);
      console.log('[EmulatorPanel] WASM simulator stopped');
      return;
    }

    // PiTrex mode: gate the RAF loop and stop audio
    if (engine === 'pitrex') {
      useDebugStore.getState().setState('stopped');
      setStatus('stopped');
      setEmulatorRunning(false);
      try { pitrexCoreRef.current?.stopAudio(); } catch {}
      console.log('[EmulatorPanel] PiTrex stopped');
      return;
    }

    // rp2350 / uvm2: cancel the rAF loop and close the system's audio. Without
    // stopAudio() the ScriptProcessor keeps reading the last PSG state and the last
    // note sustains forever after Stop is pressed. Play reloads the image.
    if (engine === 'rp2350' || engine === 'uvm2') {
      if (rp2350LoopRef.current !== null) {
        cancelAnimationFrame(rp2350LoopRef.current);
        rp2350LoopRef.current = null;
      }
      useDebugStore.getState().setState('stopped');
      setStatus('stopped');
      setEmulatorRunning(false);
      try { (emuCore as any)._rp2350System?.stopAudio?.(); } catch {}
      try { (emuCore as any)._uvm2System?.stopAudio?.(); } catch {}
      console.log(`[EmulatorPanel] ${engine} stopped`);
      return;
    }

    const vecx = (window as any).vecx;
    if (vecx) {
      // CRITICAL: Solo parar, NO resetear aquí
      // El reset se hará cuando se presione Play después de Stop
      vecx.stop();

      setStatus('stopped');
      useDebugStore.getState().setState('stopped');
      setEmulatorRunning(false); // Persist state
      console.log('[EmulatorPanel] JSVecX stopped (will reset on next Play)');
    }
  };

  const onReset = () => {
    const engine = useEmulatorStore.getState().activeEngine;
    // WASM simulator: remount it, which starts the program again.
    if (engine === 'sim') {
      const again = simModulePath
        ? { path: simModulePath, romZip: useEmulatorStore.getState().simRomZip ?? null }
        : stoppedSimRef.current;
      stoppedSimRef.current = null;
      if (again) {
        setSimModule(again.path, again.romZip);
        useDebugStore.getState().setState('running');
        setStatus('running');
      }
      return;
    }

    // rp2350 / uvm2: reload the same image and run it from the beginning.
    if (engine === 'rp2350' || engine === 'uvm2') {
      if (!armReloadRef.current) { console.log(`[EmulatorPanel] ${engine}: nothing loaded — build again`); return; }
      if (rp2350LoopRef.current !== null) {
        cancelAnimationFrame(rp2350LoopRef.current);
        rp2350LoopRef.current = null;
      }
      try { (emuCore as any)._rp2350System?.stopAudio?.(); } catch {}
      try { (emuCore as any)._uvm2System?.stopAudio?.(); } catch {}
      armReloadRef.current();
      setArmAudioSuspended(!audioEnabled);
      clearCanvas();
      startArmRafLoop();
      setStatus('running');
      console.log(`[EmulatorPanel] ${engine} reset — image reloaded`);
      return;
    }

    if (engine === 'pitrex' && !(pitrexCoreRef.current && pitrexSFileRef.current)) {
      console.log('[EmulatorPanel] PiTrex: nothing loaded — build again');
      return;
    }

    // PiTrex mode: re-parse saved assembly and restart the RAF loop from the beginning
    if (engine === 'pitrex' && pitrexCoreRef.current && pitrexSFileRef.current) {
      console.log('[EmulatorPanel] PiTrex reset — reloading assembly');

      // Stop current loop and audio
      if (pitrexLoopRef.current !== null) {
        cancelAnimationFrame(pitrexLoopRef.current);
        pitrexLoopRef.current = null;
      }
      pitrexCoreRef.current.stopAudio();

      // Re-parse assembly into a fresh core
      import('../../pitrex/PitrexCore.js').then(({ PitrexCore }) => {
        const core = new PitrexCore();
        core.loadAssembly(pitrexSFileRef.current!, pitrexLibvpyRef.current);
        pitrexCoreRef.current = core;

        if (!core.isReady()) {
          console.error('[EmulatorPanel] PiTrex reset: failed to reload assembly');
          return;
        }

        // Clear canvas
        if (canvasRef.current) {
          const ctx = canvasRef.current.getContext('2d');
          if (ctx) {
            ctx.fillStyle = '#000000';
            ctx.fillRect(0, 0, canvasRef.current.width, canvasRef.current.height);
          }
        }

        useDebugStore.getState().setState('running');
        setStatus('running');
        if (audioEnabledRef.current) core.startAudio();
        startPitrexRafLoop();
        console.log('[EmulatorPanel] PiTrex reset complete — new loop started');
      }).catch(e => {
        console.error('[EmulatorPanel] PiTrex reset: import failed', e);
      });
      return;
    }

    // The 6809 (also with nothing loaded: Reset is an explicit start of the BIOS).
    if (engine !== 'm6809') {
      stopAllEngines('Reset (6809)');
      setActiveEngine('m6809');
    }
    const vecx = (window as any).vecx;
    if (vecx) {
      // Clear PSG log on reset
      const win = window as any;
      if (!win.PSG_WRITE_LOG) win.PSG_WRITE_LOG = [];
      win.PSG_WRITE_LOG.length = 0;
      console.log('[EmulatorPanel] JSVecX reset, PSG log cleared (length=' + win.PSG_WRITE_LOG.length + ')');

      // Clear opcode trace on reset
      if (win.clearOpcodeTrace) {
        win.clearOpcodeTrace();
        // Large trace to capture bank-switch transitions before code-into-data crashes.
        win.OPCODE_TRACE_MAX = 50000;
        // Only enable full trace if explicitly requested (not by default)
        // win.OPCODE_TRACE_FULL = true;
        console.log('[EmulatorPanel] 🧹 Opcode trace cleared on reset (max=50000)');
      }

      // Delete previous .stack on reset (if we know where the .bin is)
      try {
        const romPath = win.CURRENT_ROM_PATH;
        const stackPath = (typeof romPath === 'string') ? romPath.replace(/\.(bin|BIN)$/, '.stack') : null;
        const fileAPI = (window as any).files;
        if (stackPath && fileAPI?.deleteFile) {
          fileAPI.deleteFile(stackPath).catch(() => {});
          console.log('[EmulatorPanel] 🧽 Requested delete of .stack on reset:', stackPath);
        }
      } catch (e) {
        // Ignore
      }

      // Delete previous .tracebin on reset (if we know where the .bin is)
      try {
        const romPath = win.CURRENT_ROM_PATH;
        const tracePath = (typeof romPath === 'string') ? romPath.replace(/\.(bin|BIN)$/, '.tracebin') : null;
        const fileAPI = (window as any).files;
        if (tracePath && fileAPI?.deleteFile) {
          fileAPI.deleteFile(tracePath).catch(() => {});
          console.log('[EmulatorPanel] 🧽 Requested delete of .trace on reset:', tracePath);
        }
      } catch (e) {
        // Ignore
      }

      console.log('🔄 [EmulatorPanel] CALLING vecx.reset() - Reason: Reset button clicked');
      console.log('📍 [EmulatorPanel] Reset stack trace:', new Error().stack);
      vecx.reset();

      // CRITICAL: Initialize debugState to 'running' after reset
      vecx.debugState = 'running';
      vecx.stepMode = null;
      vecx.stepTargetAddress = null;
      console.log('[EmulatorPanel] ✓ JSVecx debugState initialized to running after reset');
      if (status === 'running') {
        initPsgLogging();
        vecx.debugState = 'running';
        vecx.start();
        console.log('[EmulatorPanel] JSVecX restarted after reset');
      }
    }
  };

  runControlRef.current = { play: onPlay, pause: onPause, stop: onStop };

  const onLoadROM = async () => {
    // Prefer the Electron native dialog: it gives us the absolute path, which we
    // need to locate the sibling .elf for rp2350 binaries. Fall back to the
    // browser <input type="file"> if the IPC bridge isn't available.
    const filesApi = (window as any).files;
    let romData: Uint8Array | null = null;
    let romName = '';
    let romPath: string | null = null;

    if (filesApi?.openBin) {
      const picked = await filesApi.openBin();
      if (!picked || (picked as any).error) {
        if ((picked as any)?.error) console.error('[EmulatorPanel] openBin error:', (picked as any).error);
        return;
      }
      romPath = picked.path;
      romName = picked.path.split(/[/\\]/).pop() || 'rom.bin';
      romData = Uint8Array.from(atob(picked.base64), c => c.charCodeAt(0));
    } else {
      const file = await new Promise<File | null>((resolve) => {
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = '.bin,.vec,.rom';
        input.onchange = (e) => resolve((e.target as HTMLInputElement).files?.[0] ?? null);
        input.click();
      });
      if (!file) return;
      romName = file.name;
      romData = new Uint8Array(await file.arrayBuffer());
    }

    try {
      console.log(`[EmulatorPanel] Loading ROM: ${romName} (${romData.length} bytes)${romPath ? ` from ${romPath}` : ''}`);

      const vecx = (window as any).vecx;
      if (!vecx) {
        console.error('[EmulatorPanel] vecx instance not available');
        return;
      }

      // A fresh ROM means a fresh run mode; the branches below set it if they
      // take over, and the plain 6809 cartridge path correctly leaves it unset.
      setRunMode(null);
      // A new program: nothing else may keep running or sounding (the uvm2 / rp2350
      // branches used to start a second rAF loop next to the old one).
      stopAllEngines('Load File');
      setShowPitrexOverlay(false);

      // Auto-detect a UVM2 image by its "2CMU" header. It carries its own
      // syscall handler and drives the VIA itself, so it goes to Uvm2System
      // rather than the RP2350 one, which would implement those syscalls in JS.
      const isUvm2 =
        romData.length >= 20 &&
        romData[0] === 0x32 && romData[1] === 0x43 &&
        romData[2] === 0x4D && romData[3] === 0x55;

      if (isUvm2) {
        console.log('[EmulatorPanel] ✓ Detected UVM2 image (magic "2CMU") — routing to Uvm2System');
        setRunMode('uvm2');
        if (typeof emuCore.loadUvm2 !== 'function') {
          console.error('[EmulatorPanel] emuCore.loadUvm2 not available — uvm2 target unsupported in this build');
          return;
        }
        /* EL ELF Y LA TARJETA, igual que el camino del rp2350 justo debajo.
         *
         * Sin ELF no hay simbolos, y sin simbolos Uvm2System no puede atrapar las
         * llamadas al lector de SD — las sirve en JS porque el driver de verdad
         * habla SPI a pelo con unos pines que el emulador no modela. El sintoma
         * no es un error: el juego arranca, dibuja perfecto, y todo lo que sale
         * de la tarjeta (el romset, la musica del jack) simplemente no esta.
         *
         * Y el .elf de una imagen .um2 no siempre esta al lado: el recipe del
         * pico-sdk lo deja en pico/, asi que se prueban los dos sitios. */
        let elfUvm2: Uint8Array | undefined;
        if (romPath && filesApi?.readFileBin) {
          const base = romPath.replace(/\.um2$/i, '');
          const dir  = base.replace(/[^/\\]*$/, '');
          const name = base.slice(dir.length);
          for (const cand of [`${base}.elf`, `${dir}pico/${name}.elf`]) {
            try {
              const r = await filesApi.readFileBin(cand);
              if (r && !(r as any).error && (r as any).base64) {
                elfUvm2 = Uint8Array.from(atob((r as any).base64), c => c.charCodeAt(0));
                console.log(`[EmulatorPanel] ✓ ELF del .um2: ${cand} (${elfUvm2.length} bytes)`);
                break;
              }
            } catch { /* el siguiente sitio */ }
          }
          if (!elfUvm2)
            console.log('[EmulatorPanel] sin .elf junto al .um2 — sin simbolos no hay SD simulada');
        }
        /* LA TARJETA SIMULADA, CON CONTENIDOS Y NO CON NOMBRES. sdSimList devuelve
         * `files: string[]`; Uvm2System.setSdFiles quiere
         * Record<ruta, Uint8Array>. Pasarle la lista tal cual compila
         * perfectamente y no sirve para nada: Object.keys de un array da
         * "0","1","2" y toda busqueda falla. Otro desajuste que no da error.
         *
         * Se saltan los .um2 y los .bin: son las imagenes de los OTROS juegos de
         * la tarjeta, decenas de megas que ningun juego lee nunca. */
        let sdUvm2Files: Record<string, Uint8Array> | undefined;
        try {
          const lista = await (window as any).electronAPI?.sdSimList?.();
          if (lista?.dir && Array.isArray(lista.files) && filesApi?.readFileBin) {
            const out: Record<string, Uint8Array> = {};
            for (const nombre of lista.files as string[]) {
              if (/\.(um2|bin)$/i.test(nombre)) continue;
              try {
                const r = await filesApi.readFileBin(`${lista.dir}/${nombre}`);
                if (r && !(r as any).error && (r as any).base64)
                  out[nombre.toLowerCase()] =
                    Uint8Array.from(atob((r as any).base64), c => c.charCodeAt(0));
              } catch { /* ese no */ }
            }
            sdUvm2Files = out;
            console.log(`[EmulatorPanel] SD simulada para uvm2: ${Object.keys(out).length} ficheros`);
          }
        } catch { /* sin tarjeta simulada */ }
        const um2 = romData;
        armReloadRef.current = () =>
          emuCore.loadUvm2!(um2, canvasRef.current ?? undefined, elfUvm2, sdUvm2Files);
        armReloadRef.current();
        setActiveEngine('uvm2');
        setArmAudioSuspended(!audioEnabled);
        clearCanvas();
        // The image paces itself against the emulated bus clock, so the host loop
        // only has to not outrun it.
        startArmRafLoop();
        setStatus('running');

        setLoadedROM(`${romName} (${romData.length} bytes, uvm2)`);
        setLastRom(null, romName);
        setSelectedROM('');
        window.dispatchEvent(new Event('programLoaded'));
        return;
      }

      // Auto-detect rp2350 binaries by magic header "VPy2" (0x56 0x50 0x79 0x32)
      const isRp2350 =
        romData.length >= 4 &&
        romData[0] === 0x56 && romData[1] === 0x50 &&
        romData[2] === 0x79 && romData[3] === 0x32;

      if (isRp2350) {
        console.log(`[EmulatorPanel] ✓ Detected rp2350 binary (magic "VPy2") — routing to Rp2350System`);
        setRunMode('rp2350');   // show the "EMULATING RP2350 (ARM)" badge
        if (typeof emuCore.loadArm !== 'function') {
          console.error('[EmulatorPanel] emuCore.loadArm not available — rp2350 target unsupported in this build');
          return;
        }

        // Try to load the sibling .elf (same path, .elf extension) so traps
        // can be registered from symbol addresses instead of prologue heuristics.
        let elfData: Uint8Array | undefined;
        if (romPath && filesApi?.readFileBin) {
          const elfPath = romPath.replace(/\.bin$/i, '.elf');
          if (elfPath !== romPath) {
            try {
              const elfRes = await filesApi.readFileBin(elfPath);
              if (elfRes && !(elfRes as any).error && (elfRes as any).base64) {
                elfData = Uint8Array.from(atob((elfRes as any).base64), c => c.charCodeAt(0));
                console.log(`[EmulatorPanel] ✓ Sibling ELF loaded: ${elfPath} (${elfData.length} bytes)`);
              } else {
                console.log(`[EmulatorPanel] No sibling .elf at ${elfPath} — using VPy2 header entry + prologue scan`);
              }
            } catch (e) {
              console.log(`[EmulatorPanel] No sibling .elf — using VPy2 header entry + prologue scan`);
            }
          }
        }

        const sdSim1 = await (window as any).electronAPI?.sdSimList?.().catch(() => null);
        const romZip1 = await loadSimRomZip(romPath);
        const armBin = romData;
        armReloadRef.current = () =>
          emuCore.loadArm!(armBin, elfData, canvasRef.current ?? undefined, sdSim1?.files ?? [], sdSim1?.previews ?? {}, romZip1);
        armReloadRef.current();
        console.log('[EmulatorPanel] ✓ ARM binary loaded into Rp2350System');
        setActiveEngine('rp2350');
        setArmAudioSuspended(!audioEnabled);

        // Clear the canvas before first rp2350 frame
        clearCanvas();
        startArmRafLoop();
        setStatus('running');

        setLoadedROM(`${romName} (${romData.length} bytes, rp2350${elfData ? ' + elf' : ''})`);
        setLastRom(null, romName);
        setSelectedROM('');
        window.dispatchEvent(new Event('programLoaded'));
        return;
      }

      // ── M6809 cartridge path ────────────────────────────────────────────
      setActiveEngine('m6809');
      applyAudioState(audioEnabled);
      let cartDataString = '';
      for (let i = 0; i < romData.length; i++) {
        cartDataString += String.fromCharCode(romData[i]);
      }

      const Globals = (window as any).Globals || (globalThis as any).Globals;
      if (!Globals) {
        console.error('[EmulatorPanel] Globals not available');
        return;
      }

      Globals.cartdata = cartDataString;
      console.log(`[EmulatorPanel] ✓ ROM loaded into Globals.cartdata (${romData.length} bytes)`);

      window.dispatchEvent(new Event('programLoaded'));
      setLoadedROM(`${romName} (${romData.length} bytes)`);
      setLastRom(null, romName);
      setSelectedROM('');
      await loadOverlay(romName);

      console.log('🔄 [EmulatorPanel] CALLING vecx.reset() - Reason: File upload (insert cartridge)');
      vecx.reset();
      console.log('[EmulatorPanel] ✓ Reset after ROM load');

      if (status === 'running') {
        vecx.debugState = 'running';
        vecx.start();
        console.log('[EmulatorPanel] ✓ Restarted after ROM load');
      }
    } catch (error) {
      console.error('[EmulatorPanel] Failed to load ROM:', error);
    }
  };



  // Cargar ROM al arrancar - última compilada del proyecto O Minestorm por defecto
  // Auto-load compiled ROM on startup DISABLED - user manually controls when to load/start
  // Previous behavior: detected project, auto-loaded last compiled binary, auto-started emulator
  useEffect(() => {
    const loadDefaultROM = async () => {
      if (defaultOverlayLoaded.current) return; // Ya se cargó
      
      // Skip auto-loading compiled ROM - commented out to give user manual control
      /* DISABLED AUTO-LOAD
      // Esperar a que projectStore esté disponible (hasta 3 segundos)
      const maxWaitTime = 3000;
      const checkInterval = 500;
      let waited = 0;
      
      while (waited < maxWaitTime) {
        const projectState = (window as any).__projectStore__?.getState?.();
        const currentProjectPath = projectState?.vpyProject?.rootDir;
        
        // Si tenemos proyecto Y ROM compilada, intentar cargarla
        if (currentProjectPath && lastCompiledBinary && lastCompiledProject === currentProjectPath) {
          try {
            const fileAPI = (window as any).files;
            if (fileAPI?.readFileBin) {
              // All binaries are .bin (unified format: single or multibank)
              const result = await fileAPI.readFileBin(lastCompiledBinary);
              
              if (result && !result.error && result.base64) {
                const vecx = (window as any).vecx;
                const Globals = (window as any).Globals;
                
                if (vecx && Globals) {
                  const binaryData = atob(result.base64);
                  Globals.cartdata = binaryData;
                  
                  vecx.stop();
                  vecx.reset();
                  vecx.write8(0xC81B, 0);
                  vecx.write8(0xC81C, 0);
                  
                  const romName = lastCompiledBinary.split(/[/\\]/).pop()?.replace(/\.(bin|BIN)$/, '') || 'compiled';
                  setLoadedROM(`Compiled - ${romName}`);
                  
                  // Clear opcode trace and set ROM name for .stack file generation
                  if ((window as any).clearOpcodeTrace) {
                    (window as any).clearOpcodeTrace();
                    // Large trace to capture bank-switch transitions and the real
                    // jump into RAM/garbage. e6809.js's default is also 50000;
                    // we set the window override explicitly so the value is the
                    // same regardless of whether code reads the global or the
                    // window property.
                    (window as any).OPCODE_TRACE_MAX = 50000;
                    // Full trace streaming to disk (.trace next to binary)
                    // Only enable if explicitly set via --enable-tracebin flag
                    // (window as any).OPCODE_TRACE_FULL = true;
                    (window as any).CURRENT_ROM_NAME = romName + '.bin';
                    (window as any).CURRENT_ROM_PATH = lastCompiledBinary;
                    console.log('[EmulatorPanel] 🧹 Opcode trace cleared for:', romName + '.bin', 'path:', lastCompiledBinary);
                  }
                  
                  // CRITICAL: Initialize debugState to 'running' when loading binary
                  if (vecx) {
                    vecx.debugState = 'running';
                    vecx.stepMode = null;
                    vecx.stepTargetAddress = null;
                    console.log('[EmulatorPanel] ✓ JSVecx debugState initialized to running for new binary');
                  }

                  // Delete previous .stack for this ROM (if any)
                  try {
                    const stackPath = lastCompiledBinary.replace(/\.(bin|BIN)$/, '.stack');
                    if (fileAPI?.deleteFile) {
                      await fileAPI.deleteFile(stackPath);
                      console.log('[EmulatorPanel] 🧽 Deleted previous .stack:', stackPath);
                    }
                  } catch (e) {
                    // Ignore if file does not exist
                  }

                  // Delete previous .tracebin for this ROM (if any)
                  try {
                    const tracePath = lastCompiledBinary.replace(/\.(bin|BIN)$/, '.tracebin');
                    if (fileAPI?.deleteFile) {
                      await fileAPI.deleteFile(tracePath);
                      console.log('[EmulatorPanel] 🧽 Deleted previous .trace:', tracePath);
                    }
                  } catch (e) {
                    // Ignore if file does not exist
                  }
                  
                  if (emulatorWasRunning) {
                    vecx.debugState = 'running';
                    vecx.start();
                    setStatus('running');
                  } else {
                    setStatus('stopped');
                  }
                  
                  await loadOverlay(romName + '.bin');
                  defaultOverlayLoaded.current = true;
                  console.log('[EmulatorPanel] ✓ Compiled ROM loaded successfully');
                  return; // Éxito - no cargar Minestorm
                }
              }
            }
          } catch (e) {
            console.warn('[EmulatorPanel] Failed to load compiled ROM:', e);
          }
          
          // Si llegamos aquí, falló la carga - continuar a Minestorm
          // continue;
        }
        break;
      }
      END DISABLED AUTO-LOAD */
      
      /* A MOUNT NEVER STARTS AN ENGINE. This used to call vecx.start() whenever the
       * persisted `emulatorWasRunning` was true — and Play sets it for EVERY engine
       * (simulator, rp2350, uvm2, PiTrex) while builds never clear it. The panel
       * remounts each time the dock layout changes and at every IDE start, so the
       * 6809 booted the BIOS with no cartridge (Minestorm) in the background, under
       * whatever was really running. JSVecX runs only when a 6809 program is loaded
       * or the user presses Play / Reset. */
      const owner = useEmulatorStore.getState().activeEngine;
      const vecx = (window as any).vecx;
      // A 6809 that is the active engine keeps running across the remount (its canvas
      // is re-bound in initJSVecX); under any other engine it must not run at all.
      if (vecx && owner !== 'm6809' && vecx.running) vecx.stop();

      // Nothing loaded yet and the 6809 is the selected target: show the BIOS as the
      // inserted "cartridge", stopped (Play starts it).
      if (owner === null && useSettings.getState().buildTarget === 'm6809') {
        console.log('[EmulatorPanel] Default: BIOS (Minestorm), stopped');
        await loadOverlay('minestorm.bin');
        setLoadedROM('BIOS - Minestorm');
        setStatus('stopped');
      }
      
      defaultOverlayLoaded.current = true;
    };
    
    // Pequeño delay inicial para JSVecX
    setTimeout(loadDefaultROM, 500);
  }, []); // Sin dependencias - solo se ejecuta al montar el componente

  // Responsive canvas sizing
  useEffect(() => {
    const updateCanvasSize = () => {
      if (!containerRef.current) return;
      
      const container = containerRef.current;
      const rect = container.getBoundingClientRect();
      
      // Aspect ratio Vectrex: 330x410 (aprox 4:5)
      const aspectRatio = 330 / 410;
      
      // Calcular tamaño máximo que cabe en el contenedor
      const maxWidth = rect.width - 40; // padding
      const maxHeight = rect.height - 40;
      
      let width = maxWidth;
      let height = width / aspectRatio;
      
      // Si la altura calculada es muy grande, ajustar por altura
      if (height > maxHeight) {
        height = maxHeight;
        width = height * aspectRatio;
      }
      
      // Mínimo tamaño
      width = Math.max(200, width);
      height = Math.max(250, height);
      
      // Máximo tamaño (mantener buena calidad)
      width = Math.min(500, width);
      height = Math.min(625, height);
      
      setCanvasSize({ width: Math.round(width), height: Math.round(height) });
    };
    
    // Ejecutar al inicio
    updateCanvasSize();
    
    // Observer para cambios de tamaño
    const resizeObserver = new ResizeObserver(updateCanvasSize);
    if (containerRef.current) {
      resizeObserver.observe(containerRef.current);
    }
    
    return () => {
      resizeObserver.disconnect();
    };
  }, []);

  // Listener para cargar binarios compilados automáticamente
  useEffect(() => {
    const electronAPI: any = (window as any).electronAPI;
    if (!electronAPI?.onCompiledBin) return;

    const handleCompiledBin = async (payload: { base64: string; size: number; binPath: string; pdbData?: any; target?: 'm6809' | 'rp2350' | 'pitrex' | 'uvm2'; elfBase64?: string | null; sFileText?: string | null; libvpyAsm?: string | null; sdFiles?: Record<string, string>; psramElfBase64?: string | null }) => {
    /* LA PRIMERA TRAZA DE LA CADENA. Todo lo que hay de aqui en adelante ya estaba
     * instrumentado —"uvm2: bin=…", "✓ .um2 image loaded", "[loadUvm2] START"— asi que si
     * no sale NINGUNA, el problema no esta en el emulador sino en que este manejador no se
     * llama, o llega con otro `target`. Distinguir esas dos cosas es lo unico que falta, y
     * sin ella hoy he depurado tres veces el fichero equivocado. */
    console.log('[EmulatorPanel] handleCompiledBin: target=', payload?.target,
                'bytes=', payload?.base64?.length ?? 0, 'bin=', payload?.binPath);
      // Clear the run-mode badge first: only the branch that handles THIS build
      // may set it. Without this it survives into the next build and a project
      // compiled for m6809 keeps claiming it is emulating whatever ran last.
      setRunMode(null);
      console.log(`[EmulatorPanel] Loading compiled binary: ${payload.binPath} (${payload.size} bytes) target=${payload.target ?? 'm6809'}`);

      // A new program is loading (any target, debug loads included): stop every engine
      // and every audio path first — the WASM simulator too — so only the engine this
      // load starts below runs and sounds.
      stopAllEngines(`compiled ${payload.target ?? 'm6809'} binary`);
      
      // Guardar última ROM compilada con su proyecto
      const projectState = (window as any).__projectStore__?.getState?.();
      const currentProjectPath = projectState?.vpyProject?.rootDir;
      console.log('[EmulatorPanel] 💾 SAVE CHECK:', {
        hasProjectStore: !!(window as any).__projectStore__,
        hasVpyProject: !!projectState?.vpyProject,
        currentProjectPath,
        binPath: payload.binPath
      });
      
      if (currentProjectPath) {
        setLastCompiledBinary(payload.binPath, currentProjectPath);
        console.log('[EmulatorPanel] ✓ Saved last compiled binary for project:', currentProjectPath);
        console.log('[EmulatorPanel] ✓ binPath saved:', payload.binPath);
        
        // Verificar que se guardó inmediatamente
        setTimeout(() => {
          const settings = useEmulatorSettings.getState();
          console.log('[EmulatorPanel] 🔍 VERIFY SAVE:', {
            lastCompiledBinary: settings.lastCompiledBinary,
            lastCompiledProject: settings.lastCompiledProject
          });
        }, 100);
      } else {
        console.warn('[EmulatorPanel] ⚠️ NOT SAVING - No current project path!');
      }
      
      // Si hay datos de debug (.pdb), cargarlos en el debugStore
      if (payload.pdbData) {
        console.log('[EmulatorPanel] ✓ Debug symbols (.pdb) received');
        useDebugStore.getState().loadPdbData(payload.pdbData);
      } else {
        console.log('[EmulatorPanel] ⚠️ No .pdb file provided - clearing old PDB data');
        useDebugStore.getState().clearPdbData();
      }
      
      // Record the outcome of this load for tools that wait on it (MCP ide_run).
      const noteLoad = (backend: 'm6809' | 'rp2350' | 'uvm2' | 'pitrex', ok: boolean, error?: string) =>
        useEmulatorStore.getState().noteLoad({ backend, binPath: payload.binPath, ok, error });

      // ── pitrex path: ARM32 interpreter + vector renderer ──
      if (payload.target === 'pitrex') {
        setHardwareOverlayKind('pitrex');
        setShowPitrexOverlay(false);
        if (!payload.sFileText) {
          console.warn('[EmulatorPanel] pitrex: no .s file text in payload — cannot start emulator');
          setPitrexImgPath(payload.binPath);
          setShowPitrexOverlay(true);
          noteLoad('pitrex', false, 'no .s file next to the pitrex image: nothing to emulate');
          return;
        }
        try {
          setActiveEngine('pitrex');

          // Dynamically import PitrexCore to avoid bundling it unless needed
          const { PitrexCore } = await import('../../pitrex/PitrexCore.js');
          const core = new PitrexCore();
          core.loadAssembly(payload.sFileText, payload.libvpyAsm);
          pitrexCoreRef.current = core;
          pitrexSFileRef.current = payload.sFileText; // persist for reset
          pitrexLibvpyRef.current = payload.libvpyAsm ?? null; // persist for reset

          if (!core.isReady()) {
            console.error('[EmulatorPanel] PitrexCore failed to load assembly');
            noteLoad('pitrex', false, 'the PiTrex interpreter could not load the assembly');
            return;
          }

          // Clear canvas
          if (canvasRef.current) {
            const ctx = canvasRef.current.getContext('2d');
            if (ctx) {
              ctx.fillStyle = '#000000';
              ctx.fillRect(0, 0, canvasRef.current.width, canvasRef.current.height);
            }
          }

          useDebugStore.getState().setState('running');
          setStatus('running');
          // Respect the panel's mute: the sound comes back with the engine, not over it.
          setPitrexAudioEnabled(audioEnabledRef.current);
          if (audioEnabledRef.current) core.startAudio();
          startPitrexRafLoop();
          noteLoad('pitrex', true);
        } catch (e) {
          console.error('[EmulatorPanel] Failed to start pitrex emulator:', e);
          noteLoad('pitrex', false, `failed to start the PiTrex emulator: ${(e as any)?.message || e}`);
        }
        const romName = payload.binPath.split(/[/\\]/).pop()?.replace(/\.(bin|BIN)$/, '') || 'compiled';
        loadOverlay(romName + '.bin');
        return;
      }

      // ── ARM paths: rp2350 (BIOS syscalls in JS) and uvm2 (the image's own
      //    halt-mode runtime). Both drive the same rAF loop below, so they
      //    share this branch and differ only in which loader they call. ──
      if (payload.target === 'rp2350' || payload.target === 'uvm2') {
        const isUvm2 = payload.target === 'uvm2';
        setShowPitrexOverlay(false);
        setRunMode(isUvm2 ? 'uvm2' : 'rp2350');
        try {
          setActiveEngine(isUvm2 ? 'uvm2' : 'rp2350');

          const bin = Uint8Array.from(atob(payload.base64), c => c.charCodeAt(0));
          const elf = payload.elfBase64
            ? Uint8Array.from(atob(payload.elfBase64), c => c.charCodeAt(0))
            : undefined;
          console.log(`[EmulatorPanel] ${payload.target}: bin=${bin.length}b elf=${elf?.length ?? 0}b canvas=${canvasRef.current ? `${canvasRef.current.width}x${canvasRef.current.height}` : 'null'}`);
          const loaderAvailable = isUvm2
            ? typeof emuCore.loadUvm2 === 'function'
            : typeof emuCore.loadArm === 'function';
          if (loaderAvailable) {
            if (isUvm2) {
              /* La SD simulada llega en base64 desde el proceso principal; se decodifica
               * aqui porque el emulador quiere bytes. Ver leerSdSimulada en main.ts. */
              const sdBytes: Record<string, Uint8Array> = {};
              for (const [k, v] of Object.entries(payload.sdFiles ?? {})) {
                sdBytes[k] = Uint8Array.from(atob(v), c => c.charCodeAt(0));
              }
              const psramElf = payload.psramElfBase64
                ? Uint8Array.from(atob(payload.psramElfBase64), c => c.charCodeAt(0))
                : undefined;
              armReloadRef.current = () =>
                emuCore.loadUvm2!(bin, canvasRef.current ?? undefined, elf, sdBytes, psramElf);
              armReloadRef.current();
              console.log('[EmulatorPanel] ✓ .um2 image loaded into Uvm2System');
            } else {
              // Pass the shared canvas so Rp2350System renders directly to it
              const sdSim2 = await (electronAPI as any)?.sdSimList?.().catch(() => null);
              const romZip2 = await loadSimRomZip(payload.binPath);
              armReloadRef.current = () =>
                emuCore.loadArm!(bin, elf, canvasRef.current ?? undefined, sdSim2?.files ?? [], sdSim2?.previews ?? {}, romZip2);
              armReloadRef.current();
              console.log('[EmulatorPanel] ✓ ARM binary loaded into Rp2350System');
            }
            // The loader opened the system's audio; keep it asleep if the panel is muted.
            setArmAudioSuspended(!audioEnabledRef.current);

            // Clear the canvas before first rp2350 frame (Minestorm may have drawn there)
            clearCanvas();

            startArmRafLoop();
            setStatus('running');
            noteLoad(isUvm2 ? 'uvm2' : 'rp2350', true);
          } else {
            console.error(`[EmulatorPanel] loader for ${payload.target} not available on emuCore`);
            noteLoad(isUvm2 ? 'uvm2' : 'rp2350', false, `no ${payload.target} loader in this build of the emulator`);
          }
        } catch (e) {
          console.error('[EmulatorPanel] Failed to load ARM binary:', e);
          noteLoad(isUvm2 ? 'uvm2' : 'rp2350', false, `failed to load the ARM binary: ${(e as any)?.message || e}`);
        }
        const romName = payload.binPath.split(/[/\\]/).pop()?.replace(/\.(bin|BIN)$/, '') || 'compiled';
        loadOverlay(romName + '.bin');
        return;
      }

      // Verificar si estamos cargando para debug session (no auto-start)
      const loadingForDebug = useDebugStore.getState().loadingForDebug;

      try {
        // Convertir base64 a bytes y cargar en JSVecX
        const binaryData = atob(payload.base64);
        const vecx = (window as any).vecx;
        
        if (!vecx) {
          console.error('[EmulatorPanel] JSVecX instance not available for loading binary');
          noteLoad('m6809', false, 'the JSVecX emulator instance is not available');
          return;
        }

        setActiveEngine('m6809');
        // The 6809's mute flag lives in its PSG (e8910.enabled): carry the panel's over.
        applyAudioState(audioEnabledRef.current);
        
        // Cargar el binario en la instancia global Globals.cartdata
        const Globals = (window as any).Globals;
        if (Globals) {
          Globals.cartdata = binaryData;
          console.log('[EmulatorPanel] ✓ Binary loaded into Globals.cartdata');
          
          // Dispatch event para notificar a otros paneles
          window.dispatchEvent(new Event('programLoaded'));
        }

        // CRITICAL: Verificar que JSVecX esté completamente inicializado antes de reset
        // Check osint.ctx (display) and e6809.vecx (CPU) — NOT vecx.ram which always exists
        console.log('[EmulatorPanel] Checking JSVecX initialization...');
        const isDisplayInitialized = !!vecx.osint?.ctx;
        const isCpuInitialized = !!vecx.e6809?.vecx;

        if (!isDisplayInitialized || !isCpuInitialized) {
          console.warn('[EmulatorPanel] JSVecX not fully initialized - running initialization...');
          try {
            if (!isDisplayInitialized) {
              vecx.osint.init(vecx);
              console.log('[EmulatorPanel] ✓ osint.init() successful');
            }
            if (!isCpuInitialized) {
              vecx.e6809.init(vecx);
              console.log('[EmulatorPanel] ✓ e6809.init() successful');
            }

            vecx.vecx_reset();
            vecx.osint.osint_clearscreen();
            console.log('[EmulatorPanel] ✓ JSVecX reset successful');
            
            // Inicializar joystick input state a valores neutros
            vecx.leftHeld = false;
            vecx.rightHeld = false;
            vecx.upHeld = false;
            vecx.downHeld = false;
            vecx.shadow_snd_regs14 = 0xFF;
            vecx.write8(0xC80F, 0x00);
            
            // console.log('[EmulatorPanel] ✓ JSVecX fully initialized in background');
          } catch (e) {
            console.error('[EmulatorPanel] Failed to initialize JSVecX:', e);
            throw new Error(`JSVecX initialization failed: ${e}`);
          }
        } else {
          console.log('[EmulatorPanel] ✓ JSVecX already initialized');
        }
        
        // Reset
        console.log('[EmulatorPanel] Resetting emulator...');
        console.log('🔄 [EmulatorPanel] CALLING vecx.reset() - Reason: Loading compiled binary from MCP');
        console.log('📍 [EmulatorPanel] Reset stack trace:', new Error().stack);
        vecx.reset();
        console.log('[EmulatorPanel] Emulator reset complete');
        
        // CRITICAL: Initialize joystick RAM to neutral values
        // $C81B = Vec_Joy_1_X (signed: $00 = center)
        // $C81C = Vec_Joy_1_Y (signed: $00 = center)
        // Without this, RAM contains garbage values interpreted as extreme positions
        vecx.write8(0xC81B, 0); // Vec_Joy_1_X neutral
        vecx.write8(0xC81C, 0); // Vec_Joy_1_Y neutral
        console.log('[EmulatorPanel] ✓ Joystick RAM initialized to neutral (128, 128)');
        
        // Comportamiento de auto-start dependiendo del modo:
        // - Normal compilation (F7): NO auto-start (user must press Play)
        // - Debug session (Ctrl+F5): wait for breakpoints, then start
        console.log(`[EmulatorPanel] Binary load - loadingForDebug=${loadingForDebug}`);
        
        if (!loadingForDebug) {
          // Compilación normal → NO auto-start, user loads manually
          vecx.debugState = 'stopped';
          console.log('[EmulatorPanel] ✓ Binary loaded (normal mode) - ready to start');
        } else {
          // Modo debug → NO auto-start, esperar a que breakpoints se sincronicen
          const debugStore = useDebugStore.getState();
          debugStore.setState('paused'); // Start in paused state
          console.log('[EmulatorPanel] ✓ Debug mode: state set to paused (waiting for breakpoints)');
          
          // CRITICAL: Sync debugState to JSVecx as 'paused'
          vecx.debugState = 'paused';
          console.log('[EmulatorPanel] ✓ JSVecx debugState set to paused');
          
          // DO NOT call vecx.start() here: the breakpoint sync starts it once the
          // breakpoints are in (now, if this program's .pdb is already loaded)
          vecx.waitingForBreakpoints = true;
          syncEmulatorBreakpoints();
          console.log('[EmulatorPanel] ⏸️ Emulator ready in debug mode (waiting for breakpoint sync)');
          
          // NO resetear el flag aquí - mantenerlo activo durante toda la sesión de debug
          // Se reseteará cuando el usuario haga Stop (debug.stop en main.tsx)
        }
        
        // Actualizar ROM cargada y buscar overlay
        setShowPitrexOverlay(false);
        const romName = payload.binPath.split(/[/\\]/).pop()?.replace(/\.(bin|BIN)$/, '') || 'compiled';
        setLoadedROM(`Compiled - ${romName}`);

        // Tell the emulator's crash trace where to save .stack files. Without
        // this, dumpOpcodeTrace() in e6809.js sees CURRENT_ROM_PATH=null and
        // silently skips the save — the only place this used to be set was a
        // different load path (file-API reload), not the Build+Run path here.
        (window as any).CURRENT_ROM_PATH = payload.binPath;
        (window as any).CURRENT_ROM_NAME = romName + '.bin';
        console.log('[EmulatorPanel] 📍 CURRENT_ROM_PATH set for crash-trace saves:', payload.binPath);
        
        // Dispatch event para notificar a otros paneles (ej: MemoryPanel recarga PDB)
        // Si tenemos pdbData, pasarlo en el evento
        if (payload.pdbData) {
          window.dispatchEvent(new CustomEvent('programLoaded', { 
            detail: { pdbData: payload.pdbData } 
          }));
        } else {
          window.dispatchEvent(new Event('programLoaded'));
        }
        
        // Save the compiled ROM info for persistence
        setLastRom(payload.binPath, `Compiled - ${romName}`);
        
        // Intentar cargar overlay si existe
        loadOverlay(romName + '.bin');
        
        console.log('[EmulatorPanel] ✓ Compiled binary loaded and emulator restarted');
        noteLoad('m6809', true);

      } catch (error) {
        console.error('[EmulatorPanel] Failed to load compiled binary:', error);
        noteLoad('m6809', false, `failed to load the ROM: ${(error as any)?.message || error}`);
      }
    };

    const unsubscribe = electronAPI.onCompiledBin(handleCompiledBin);
    console.log('[EmulatorPanel] ✓ Registered onCompiledBin listener');

    // Unsubscribe on unmount. Without it every remount of the panel (dock layout
    // changes) added one more listener that was never removed: each build was then
    // loaded once per stale panel, and each stale copy started its own rAF loop or
    // PiTrex core on refs nobody could reach any more — engines that kept running
    // and sounding after Stop and after the next load.
    return () => { if (typeof unsubscribe === 'function') unsubscribe(); };
  }, [loadOverlay, setLoadedROM, startPitrexRafLoop, stopAllEngines, setActiveEngine, startArmRafLoop, setArmAudioSuspended, setStatus, clearCanvas, applyAudioState]);

  // Manejar cambio de ROM en dropdown
  const handleROMChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const romName = e.target.value;
    setSelectedROM(romName);
    // Save the last ROM selection
    setLastRom(null, romName); // We don't have the path here, just the name
    if (romName) {
      loadROMFromDropdown(romName);
    }
  };

  // Toggle overlay visibility
  const toggleOverlay = () => {
    const newState = !overlayEnabled;
    setOverlayEnabled(newState);
  };

  // What the mute button shows: the audio state of the engine that owns the panel.
  const audioOn = simModulePath ? audioEnabled
    : pitrexCoreRef.current ? pitrexAudioEnabled
    : (activeEngine === 'rp2350' || activeEngine === 'uvm2') ? audioEnabled
    : getCurrentAudioState();

  const btn: React.CSSProperties = { 
    background: '#1d1d1d', 
    color: '#ddd', 
    border: '1px solid #444', 
    padding: '4px 12px', 
    fontSize: 12, 
    cursor: 'pointer', 
    borderRadius: 3 
  };

  return (
    <div style={{
      display: 'flex', 
      flexDirection: 'column', 
      height: '100%', 
      padding: 8, 
      boxSizing: 'border-box', 
      fontFamily: 'monospace', 
      fontSize: 12
    }}>
      {/* Controles de ROM - Simplificados */}
      <div style={{
        display: 'flex',
        alignItems: 'center',
        gap: 8,
        marginBottom: 8,
        justifyContent: 'center'
      }}>
        {/* Dropdown selector de ROMs */}
        <select 
          value={selectedROM} 
          onChange={handleROMChange}
          style={{
            ...btn,
            background: '#2a4a2a',
            minWidth: '120px',
            maxWidth: '180px'
          }}
        >
          <option value="">Select ROM...</option>
          {availableROMs.map(rom => (
            <option key={rom} value={rom}>{rom}</option>
          ))}
        </select>
        
        {/* Botón Load ROM manual (como fallback) */}
        <button 
          style={{
            ...btn, 
            background: '#3a3a3a', 
            fontSize: '10px',
            display: 'flex',
            alignItems: 'center',
            gap: '4px',
            padding: '6px 8px'
          }} 
          onClick={onLoadROM}
          title="Load ROM file from disk"
        >
          📁 <span>Load File...</span>
        </button>
      </div>

      {/* Canvas para JSVecX con overlay responsive */}
      <div 
        ref={containerRef}
        style={{
          flex: 1,
          display: 'flex', 
          justifyContent: 'center', 
          alignItems: 'center',
          minHeight: '400px',
          marginBottom: '8px'
        }}
      >
        <div style={{ position: 'relative', display: 'inline-block' }}>
          {/* Run-mode badge — SIMULATING (fast WASM, F5) vs EMULATING the RP2350
              ARM binary (slow, HW-accurate, Shift+F5). Removes the ambiguity of
              not knowing which backend a run used. */}
          {(simModulePath || runMode === 'rp2350' || runMode === 'uvm2') && (
            <div style={{
              position: 'absolute', top: 4, right: 4, zIndex: 30,
              padding: '2px 7px', borderRadius: 4, pointerEvents: 'none',
              fontFamily: 'monospace', fontSize: 10, fontWeight: 'bold',
              letterSpacing: '0.5px',
              background: simModulePath ? 'rgba(30,90,40,0.85)' : 'rgba(110,70,20,0.9)',
              color: simModulePath ? '#8f8' : '#fc9',
              border: `1px solid ${simModulePath ? '#4a4' : '#c94'}`,
            }}>
              {simModulePath
                ? '▶ SIMULATING (WASM)'
                : runMode === 'uvm2'
                  ? '🎯 EMULATING UVM2 (halt-mode bus · slow)'
                  : '🎯 EMULATING RP2350 (ARM · slow)'}
            </div>
          )}
          {/* Frames per second. `emuFps` is what the HOST manages to render (depends on
              this machine); `emuDrawFps` is the refresh the frame's bus cycles would allow
              on the real console, which is the number that actually matters. */}
          {(runMode === 'rp2350' || runMode === 'uvm2') && emuFps > 0 && (
            <div style={{
              position: 'absolute', top: 24, right: 4, zIndex: 30,
              padding: '2px 7px', borderRadius: 4, pointerEvents: 'none',
              fontFamily: 'monospace', fontSize: 10,
              background: 'rgba(20,20,20,0.85)', color: '#9cf', border: '1px solid #468',
            }}>
              {`host ${emuFps.toFixed(1)} fps`}
              {emuDrawFps > 0 && ` · console ${emuDrawFps.toFixed(1)} Hz`}
              {emuCiclos > 0 && ` · ${emuCiclos} cycles`}
            </div>
          )}
          {/* External-project WASM simulator (runs any module speaking the
              PiTrex host SDK contract). Overlays the Vectrex canvas. */}
          {simModulePath && (
            <div style={{ position: 'absolute', top: 0, left: 0, zIndex: 20 }}>
              <PitrexSimView
                key={simModuleNonce}
                modulePath={simModulePath}
                width={canvasSize.width}
                height={canvasSize.height}
                onLog={(line) => console.log(line)}
                onCanvasReady={onSimCanvasReady}
                onCaptureReady={onSimCaptureReady}
                muted={!audioEnabled}
              />
            </div>
          )}
          {/* PiTrex hardware-only overlay */}
          {showPitrexOverlay && !simModulePath && (
            <div style={{
              position: 'absolute',
              top: 0,
              left: 0,
              width: canvasSize.width,
              height: canvasSize.height,
              background: '#0a0a0a',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '10px',
              zIndex: 10,
              pointerEvents: 'none',
              border: '1px solid #333',
            }}>
              <span style={{ fontSize: '28px' }}>{hardwareOverlayKind === 'uvm2' ? '🎮' : '🥝'}</span>
              <span style={{ color: '#ccc', fontFamily: 'monospace', fontSize: '13px', fontWeight: 'bold' }}>
                {hardwareOverlayKind === 'uvm2'
                  ? 'UVM2 (Ultimate Vectrex Multicart 2)'
                  : 'PiTrex (Pi Zero / ARMv6)'}
              </span>
              <span style={{ color: '#777', fontFamily: 'monospace', fontSize: '11px' }}>
                {hardwareOverlayKind === 'uvm2'
                  ? '.um2 image built — copy to SD card'
                  : '.img image built — copy to SD card'}
              </span>
              {pitrexImgPath && (
                <span style={{ color: '#555', fontFamily: 'monospace', fontSize: '10px', maxWidth: '90%', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{pitrexImgPath}</span>
              )}
              <span style={{ color: '#444', fontFamily: 'monospace', fontSize: '10px', marginTop: '4px' }}>
                {hardwareOverlayKind === 'uvm2'
                  ? 'No in-browser emulation for UVM2'
                  : 'No in-browser emulation for Pi Zero'}
              </span>
            </div>
          )}
          <canvas 
            ref={canvasRef} 
            id="screen" 
            width="330" 
            height="410" 
            style={{
              border: '1px solid #333', 
              background: '#000', 
              width: canvasSize.width, 
              height: canvasSize.height,
              display: 'block',
              position: 'relative',
              zIndex: 1
            }} 
          />
          
          {/* Sistema dual-overlay: mezcla de colores + visibilidad */}
          {currentOverlay && overlayEnabled && (
            <>
              {/* Overlay 1: Multiply - mezcla colores con los vectores */}
              <div
                style={{
                  position: 'absolute',
                  top: 0,
                  left: 0,
                  width: canvasSize.width,
                  height: canvasSize.height,
                  pointerEvents: 'none',
                  zIndex: 2,
                  backgroundImage: `url(${currentOverlay})`,
                  backgroundSize: `${canvasSize.width}px ${canvasSize.height}px`,
                  backgroundPosition: 'center',
                  backgroundRepeat: 'no-repeat',
                  mixBlendMode: 'multiply',
                  opacity: 0.7
                }}
                onError={(e) => {
                  console.warn(`[EmulatorPanel] Failed to load overlay (multiply): ${currentOverlay}`);
                  setCurrentOverlay(null);
                }}
              />
              {/* Overlay 2: Screen - hace visible el overlay sin afectar vectores */}
              <div
                style={{
                  position: 'absolute',
                  top: 0,
                  left: 0,
                  width: canvasSize.width,
                  height: canvasSize.height,
                  pointerEvents: 'none',
                  zIndex: 3,
                  backgroundImage: `url(${currentOverlay})`,
                  backgroundSize: `${canvasSize.width}px ${canvasSize.height}px`,
                  backgroundPosition: 'center',
                  backgroundRepeat: 'no-repeat',
                  mixBlendMode: 'screen',
                  opacity: 1
                }}
              />
            </>
          )}
        </div>
      </div>

      {/* Emulator Output - Información técnica del emulador */}
      <EmulatorOutputInfo backend={runMode} />

      {/* Controles principales debajo del canvas - Estilo homogéneo */}
      <div style={{
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        gap: 8,
        marginTop: 12,
        paddingTop: 8,
        borderTop: '1px solid #333'
      }}>
        {/* Botón Play/Pause */}
        <button 
          style={{
            ...btn,
            backgroundColor: status === 'running' ? '#4a2a2a' : '#2a4a2a',
            color: status === 'running' ? '#faa' : '#afa',
            fontSize: '20px',
            padding: '10px',
            minWidth: '50px',
            minHeight: '50px',
            borderRadius: '6px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center'
          }} 
          onClick={status === 'running' ? onPause : onPlay}
          title={status === 'running' ? 'Pause emulation' : 'Start/Resume emulation'}
        >
          {status === 'running' ? '⏸️' : '▶️'}
        </button>
        
        {/* Botón Stop */}
        <button 
          style={{
            ...btn,
            backgroundColor: status === 'stopped' ? '#4a2a2a' : '#3a3a3a',
            color: status === 'stopped' ? '#faa' : '#aaa',
            fontSize: '20px',
            padding: '10px',
            minWidth: '50px',
            minHeight: '50px',
            borderRadius: '6px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center'
          }} 
          onClick={onStop}
          title="Stop emulation"
        >
          ⏹️
        </button>
        
        {/* Botón Reset */}
        <button 
          style={{
            ...btn,
            backgroundColor: '#3a3a4a',
            color: '#aaf',
            fontSize: '20px',
            padding: '10px',
            minWidth: '50px',
            minHeight: '50px',
            borderRadius: '6px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center'
          }} 
          onClick={onReset}
          title="Reset emulation"
        >
          🔄
        </button>

        {/* Botón Record vectores (.vrec) */}
        <button
          style={{
            ...btn,
            backgroundColor: isRecording ? '#5a2a2a' : '#3a3a3a',
            color: isRecording ? '#f66' : '#aaa',
            fontSize: '20px',
            padding: '10px',
            minWidth: '50px',
            minHeight: '50px',
            borderRadius: '6px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center'
          }}
          onClick={onToggleRecording}
          title={isRecording
            ? 'Stop vector recording and save .vrec'
            : `Record vectors to .vrec for game preview — stop when done (safety cap ${MAX_RECORD_SECONDS} s)`}
        >
          {isRecording ? '⏹' : '🔴'}
        </button>

        {/* Indicador de grabación: punto rojo + segundos transcurridos */}
        {isRecording && (
          <span style={{
            color: '#f44',
            fontFamily: 'monospace',
            fontSize: '12px',
            fontWeight: 'bold',
            display: 'flex',
            alignItems: 'center',
            gap: '4px',
            minWidth: '54px'
          }}>
            <span style={{
              width: 8,
              height: 8,
              borderRadius: '50%',
              background: '#f00',
              display: 'inline-block'
            }} />
            REC {recordElapsed.toFixed(1)}s
          </span>
        )}

        {/* Botón Record video de gameplay (MP4 con audio) */}
        <button
          style={{
            ...btn,
            backgroundColor: isVideoRecording ? '#5a2a2a' : '#3a3a3a',
            color: isVideoRecording ? '#f66' : '#aaa',
            fontSize: '20px',
            padding: '10px',
            minWidth: '50px',
            minHeight: '50px',
            borderRadius: '6px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center'
          }}
          onClick={onToggleVideoRecording}
          disabled={videoStatus === 'transcoding'}
          title={isVideoRecording
            ? 'Stop gameplay recording and export MP4'
            : 'Record gameplay video + audio to MP4 (for YouTube etc.)'}
        >
          {isVideoRecording ? '⏹' : '🎥'}
        </button>

        {/* Indicador de grabación de video: punto rojo + segundos / estado */}
        {isVideoRecording && (
          <span style={{
            color: '#f44',
            fontFamily: 'monospace',
            fontSize: '12px',
            fontWeight: 'bold',
            display: 'flex',
            alignItems: 'center',
            gap: '4px',
            minWidth: '54px'
          }}>
            <span style={{
              width: 8,
              height: 8,
              borderRadius: '50%',
              background: '#f00',
              display: 'inline-block'
            }} />
            VID {videoElapsed.toFixed(1)}s
          </span>
        )}
        {!isVideoRecording && videoStatus !== 'idle' && videoMessage && (
          <span style={{
            color: videoStatus === 'error' ? '#f66' : videoStatus === 'saved' ? '#6f6' : '#ccc',
            fontFamily: 'monospace',
            fontSize: '11px',
            display: 'flex',
            alignItems: 'center',
            maxWidth: '260px',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap'
          }} title={videoMessage}>
            {videoStatus === 'transcoding' ? '⏳ ' : videoStatus === 'saved' ? '✅ ' : '⚠️ '}
            {videoMessage}
          </span>
        )}

        {/* Botón Audio Mute/Unmute */}
        <button
          style={{
            ...btn,
            backgroundColor: audioOn ? '#2a4a2a' : '#4a2a2a',
            color: audioOn ? '#afa' : '#faa',
            fontSize: '20px',
            padding: '10px',
            minWidth: '50px',
            minHeight: '50px',
            borderRadius: '6px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center'
          }} 
          onClick={() => {
            // ── WASM simulator: PitrexSimView follows `audioEnabled` (muted prop) ──
            if (simModulePath) {
              setAudioEnabled(!audioEnabled);
              return;
            }
            // ── rp2350 / uvm2: suspend or resume the system's AudioContext ──────
            if (activeEngine === 'rp2350' || activeEngine === 'uvm2') {
              const next = !audioEnabled;
              setAudioEnabled(next);
              // A paused machine stays silent until Play.
              if (!next || status === 'running') setArmAudioSuspended(!next);
              return;
            }
            // ── PiTrex audio path ────────────────────────────────────────────
            if (pitrexCoreRef.current) {
              const newEnabled = !pitrexAudioEnabled;
              setPitrexAudioEnabled(newEnabled);
              setAudioEnabled(newEnabled);
              if (newEnabled) {
                pitrexCoreRef.current.startAudio();
                console.log('[EmulatorPanel] PiTrex audio unmuted');
              } else {
                pitrexCoreRef.current.stopAudio();
                console.log('[EmulatorPanel] PiTrex audio muted');
              }
              return;
            }

            // ── JSVecX / PSG audio path ──────────────────────────────────────
            const currentRealState = getCurrentAudioState();
            const newState = !currentRealState;

            console.log('[EmulatorPanel] Audio button clicked:', {
              storedState: audioEnabled,
              realCurrentState: currentRealState,
              newState,
              status,
              vecxAvailable: !!(window as any).vecx
            });

            setAudioEnabled(newState);

            const vecx = (window as any).vecx;
            if (vecx && vecx.toggleSoundEnabled) {
              const resultState = vecx.toggleSoundEnabled();
              console.log(`[EmulatorPanel] ✓ Audio toggled: ${currentRealState} → ${resultState}`);

              if (resultState !== newState) {
                console.log('[EmulatorPanel] Correcting stored state to match result:', resultState);
                setAudioEnabled(resultState);
              }
            }

            try {
              const finalState = getCurrentAudioState();
              if (finalState) {
                psgAudio.start();
                console.log('[EmulatorPanel] ✓ PSG Audio started');
              } else {
                psgAudio.stop();
                console.log('[EmulatorPanel] ✓ PSG Audio stopped');
              }
            } catch (e) {
              console.warn('[EmulatorPanel] Could not control PSG audio:', e);
            }
          }}
          title={audioOn ? 'Mute audio' : 'Unmute audio'}
        >
          {audioOn ? '🔊' : '🔇'}
        </button>
        
        {/* Botón Toggle Overlay - Solo visible si hay overlay disponible */}
        {currentOverlay && (
          <button 
            style={{
              ...btn,
              backgroundColor: overlayEnabled ? '#2a4a2a' : '#4a2a2a',
              color: overlayEnabled ? '#afa' : '#888', // Gris cuando está desactivado
              fontSize: '20px',
              padding: '10px',
              minWidth: '50px',
              minHeight: '50px',
              borderRadius: '6px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }} 
            onClick={toggleOverlay}
            title={overlayEnabled ? 'Hide overlay' : 'Show overlay'} >
            🖼️
          </button>
        )}
        
        {/* Botón Snapshot ROM (solo si está pausado) */}
        {status === 'paused' && (
          <button 
            style={{
              ...btn,
              backgroundColor: '#4a3a2a',
              color: '#ffa',
              fontSize: '18px',
              padding: '10px',
              minWidth: '50px',
              minHeight: '50px',
              borderRadius: '6px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }} 
            onClick={onSnapshotROM}
            title="Download ROM snapshot (current bank + bank 31)" >
            💾
          </button>
        )}
        {/* Botón Decompile & Compare (solo si está pausado) */}
        {status === 'paused' && (
          <button 
            style={{
              ...btn,
              backgroundColor: '#3a4a2a',
              color: '#afa',
              fontSize: '18px',
              padding: '10px',
              minWidth: '50px',
              minHeight: '50px',
              borderRadius: '6px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }} 
            onClick={onDecompileROM}
            title="Decompile ROM and compare with expected values" >
            🔍
          </button>
        )}
      </div>

      {/* Joystick Configuration Button */}
      <div style={{
        display: 'flex',
        justifyContent: 'center',
        marginTop: 12,
        paddingTop: 8,
        borderTop: '1px solid #333'
      }}>
        <button
          onClick={() => setConfigOpen(true)}
          style={{
            ...btn,
            backgroundColor: '#2d4a5a',
            color: '#aaccff',
            fontSize: '12px',
            padding: '8px 16px',
            borderRadius: '6px',
            display: 'flex',
            alignItems: 'center',
            gap: '6px'
          }}
          title="Configure joystick/gamepad"
        >
          🎮 <span>Joystick Config</span>
        </button>
      </div>

      {/* Joystick Configuration Modal */}
      <JoystickConfigDialog />

    </div>
  );
};