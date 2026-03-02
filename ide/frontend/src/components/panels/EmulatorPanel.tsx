import React, { useEffect, useRef, useState, useCallback } from 'react';
import { useEmulatorStore } from '../../state/emulatorStore';
import { useEditorStore } from '../../state/editorStore';
import { useEmulatorSettings } from '../../state/emulatorSettings';
import { useDebugStore } from '../../state/debugStore';
import type { PdbData } from '../../state/debugStore';
import { useJoystickStore } from '../../state/joystickStore';
import { useProjectStore } from '../../state/projectStore';
import { JoystickConfigDialog } from '../dialogs/JoystickConfigDialog';
import { psgAudio } from '../../psgAudio';
import { inputManager } from '../../inputManager';
import { asmAddressToVpyLine, formatAddress } from '../../utils/debugHelpers';

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
const EmulatorOutputInfo: React.FC = () => {
  const [metrics, setMetrics] = useState<VecxMetrics | null>(null);
  const [regs, setRegs] = useState<VecxRegs | null>(null);
  const [vecxRunning, setVecxRunning] = useState<boolean>(false);
  
  // Get debug state from debugStore
  const debugState = useDebugStore(s => s.state);

  const fetchStats = () => {
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
        Emulator Output
      </div>

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
    </div>
  );
};

export const EmulatorPanel: React.FC = () => {
  const status = useEmulatorStore(s => s.status);
  const setStatus = useEmulatorStore(s => s.setStatus);
  const { setConfigOpen, loadConfig } = useJoystickStore();
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  
  // Persistent emulator settings
  const { 
    audioEnabled, 
    overlayEnabled, 
    lastRomPath, 
    lastRomName,
    emulatorWasRunning,
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
  const overlayCanvasRef = useRef<HTMLCanvasElement | null>(null);
  const containerRef = useRef<HTMLDivElement | null>(null);
  const [canvasSize, setCanvasSize] = useState({ width: 300, height: 400 });
  const defaultOverlayLoaded = useRef<boolean>(false); // Flag para evitar recargar overlay por defecto
  const jsVecxInitialized = useRef<boolean>(false); // Track if JSVecx already initialized (avoid reset on resize)
  
  // Phase 3: Breakpoint system
  const [breakpoints, setBreakpoints] = useState<Set<number>>(new Set());
  const debugState = useDebugStore(s => s.state);
  const pdbData = useDebugStore(s => s.pdbData);
  const breakpointCheckIntervalRef = useRef<number | null>(null);
  
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
    };
  }, []);

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
      
      // CRITICAL: Don't re-initialize if emulator is already running/debugging
      if (vecx.running) {
        console.log('[EmulatorPanel] 🛑 Skipping re-initialization - emulator already running');
        jsVecxInitialized.current = true; // Mark as initialized
        return;
      }
      
      console.log(`[EmulatorPanel] Initializing JSVecX with canvas size: ${canvasSize.width}x${canvasSize.height} (visible: ${rect.width}x${rect.height})`);
      
      try {
      console.log('🔄 [EmulatorPanel] CALLING vecx.reset() - Reason: JSVecX initialization');
      // console.log('📍 [EmulatorPanel] Reset stack trace:', new Error().stack); // Debug only
      vecx.reset();
      console.log('[EmulatorPanel] ✓ vecx.reset() successful');
        
        // DO NOT auto-start - user controls when to start manually
        // vecx.main() would start emulator immediately
        // vecx.debugState = 'stopped'; // Don't set running yet
        console.log('[EmulatorPanel] ✓ JSVecx initialized (stopped, ready for manual start)');
        
        jsVecxInitialized.current = true; // Mark as initialized
        
        if (!cancelled) {
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
    (window as any).emulatorDebug = {
      addBreakpoint,
      removeBreakpoint,
      toggleBreakpoint,
      clearAllBreakpoints,
      getBreakpoints: () => Array.from(breakpoints),
      start: () => {
        const vecx = (window as any).vecx;
        if (vecx && vecx.debugState === 'paused') {
          console.log('[EmulatorPanel] 🚀 emulatorDebug.start() called - starting emulator');
          vecx.debugState = 'running';
          vecx.start();
        }
      }
    };
    
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

    const gamepadPollInterval = setInterval(() => {
      const vecx = (window as any).vecx;
      // Allow gamepad to work even when paused (for testing controls during debugging)
      if (!vecx) return;

      const gamepads = navigator.getGamepads();
      if (!gamepads) return;

      // Get joystick configuration from store
      const joystickConfig = useJoystickStore.getState();
      const { gamepadIndex, axisXIndex, axisYIndex, axisXInverted, axisYInverted, deadzone, buttonMappings, dpadUpButton, dpadDownButton, dpadLeftButton, dpadRightButton } = joystickConfig;

      if (gamepadIndex === null) {
        // No gamepad configured — use keyboard input (ArrowLeft/Right/Up/Down or WASD)
        const kb = inputManager.update();
        const kbX = kb.x / 127; // normalize -127..127 → -1..1
        const kbY = kb.y / 127;
        try {
          vecx.leftHeld  = kbX < -0.3;
          vecx.rightHeld = kbX > 0.3;
          vecx.downHeld  = kbY < -0.3;
          vecx.upHeld    = kbY > 0.3;
          vecx.alg_jch0 = Math.round((kbX + 1) * 127.5); // 0=left, 128=center, 255=right
          vecx.alg_jch1 = Math.round((kbY + 1) * 127.5); // 0=down,  128=center, 255=up
        } catch {}
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

      // Set JSVecX input state (directional booleans)
      // IMPORTANT: JSVecx internally converts these booleans to alg_jch0/1
      // The booleans activate from EITHER analog stick OR D-Pad buttons
      try {
        // Combine analog stick (with threshold) and D-Pad buttons
        // Analog: threshold of 0.3 to avoid drift
        // D-Pad: direct button press state
        vecx.leftHeld = (x < -0.3) || dpadLeft;
        vecx.rightHeld = (x > 0.3) || dpadRight;
        vecx.downHeld = (y < -0.3) || dpadDown;
        vecx.upHeld = (y > 0.3) || dpadUp;


        // Write analog joystick values to JSVecX hardware emulation
        // JSVecx uses UNSIGNED range: 0=left/down, 128=center, 255=right/up
        // Input x,y are in range -1.0 to +1.0 (0.0 = center)
        const analogX = Math.round((x + 1) * 127.5); // 0 to 255 (128=center)
        const analogY = Math.round((y + 1) * 127.5); // 0 to 255 (128=center)
        
        // Update JSVecx analog channels (this is what Joy_Analog BIOS reads via alg_compare)
        vecx.alg_jch0 = analogX; // Channel 0 = X axis (0=left, 128=center, 255=right)
        vecx.alg_jch1 = analogY; // Channel 1 = Y axis (0=down, 128=center, 255=up)
        
        // Read button states and build button state byte
        // In Vec_Btn_State ($C80F): 1 = pressed, 0 = released
        let buttonState = 0x00; // Default: all buttons released (all bits 0)
        
        buttonMappings.forEach(mapping => {
          const button = gamepad.buttons[mapping.gamepadButton];
          if (button && button.pressed) {
            // Button pressed: set bit (1 = pressed in Vec_Btn_State)
            const bitPosition = mapping.vectrexButton - 1;
            buttonState |= (1 << bitPosition);
          }
        });
        
        // Read previous state for debug logging only
        const prevState = lastButtonState; // Use persistent variable, not RAM
        
        // Calculate transitions manually (rising edge detection)
        // Formula: new & ~prev (bit is 1 only when new=1 AND prev=0)
        const transitions = buttonState & ~prevState & 0xFF;
        
        // Update persistent state for next frame
        lastButtonState = buttonState;
        
        // NOTE (2026-01-19): DO NOT write to $C80E (Vec_Prev_Btns) here!
        // Read_Btns in the BIOS manages Vec_Prev_Btns internally.
        // If we write buttonState to $C80E, then when Read_Btns calculates
        // transitions (new XOR prev), it sees new==prev and always returns 0.
        // Let Read_Btns handle the prev/current state tracking autonomously.
        
        // DEBUG: Log button state if any button is pressed
        if (transitions !== 0) {
          console.log('[GamepadManager] TRANSITION DETECTED:', {
            buttonState: buttonState.toString(2).padStart(4, '0'),
            transitions: transitions.toString(2).padStart(4, '0'),
            c811_written: transitions
          });
        }

        // WORKAROUND for JSVecx PSG read issue (2026-01-03):
        // Root Cause: Read_Btns auto-injects at loop start and reads PSG register 14
        // The PSG read happens AFTER our $C80F write, so Read_Btns overwrites our value
        //
        // Solution: Inject button state into window.injectedButtonStatePSG
        // JSVecx is patched to check this value when reading PSG register 14
        //
        // PSG Register 14 format (inverted: 0=pressed, 1=released)
        const psgReg14 = ~buttonState & 0xFF;
        
        // Inject into window for JSVecx to read (patched in vecx.js VIA read case 0xf)
        (window as any).injectedButtonStatePSG = psgReg14;
        
        // Also write to PSG.Regs[14] for hardware compatibility (vecx emulator)
        if (vecx.e8910 && vecx.e8910.e8910_write) {
          vecx.e8910.e8910_write(14, psgReg14);
        }
        
        // DEBUG: Monitor button state and RAM values
        if (transitions !== 0 || buttonState !== 0) {
          setTimeout(() => {
            const c811 = vecx.read8(0xC811);
            const c80f = vecx.read8(0xC80F);
            const c80e = vecx.read8(0xC80E);
            
            console.log('[Button] Frame state:', {
              'btn': buttonState.toString(2).padStart(4, '0'),
              'trans': transitions.toString(2).padStart(4, '0'),
              'C811': c811.toString(2).padStart(4, '0'),
              'C80F': c80f.toString(2).padStart(4, '0'),
              'C80E': c80e.toString(2).padStart(4, '0')
            });
          }, 5); // Quick check after emulator processes
        }
        
      } catch (error) {
        console.error('[GamepadManager] Error setting input state:', error);
      }
    }, 16); // ~60Hz polling

    return () => {
      clearInterval(gamepadPollInterval);
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
      if (vecx && vecx.e8910 && status === 'running') {
        const actualState = vecx.e8910.enabled;
        if (actualState !== audioEnabled) {
          console.log('[EmulatorPanel] Audio state desync detected, syncing:', actualState);
          setAudioEnabled(actualState);
        }
      }
    }, 1000); // Check every second

    return () => clearInterval(interval);
  }, [audioEnabled, status, setAudioEnabled]);

  // Phase 3: Breakpoint detection system (REACTIVE - no polling)
  // The WASM emulator checks breakpoints after EVERY instruction
  // We just need to detect when it has paused
  const checkBreakpointHit = useCallback(() => {
    // Solo verificar si estamos en modo debug
    if (debugState !== 'running') {
      console.log('[EmulatorPanel] 🔍 checkBreakpointHit called but debugState is:', debugState);
      return;
    }
    
    console.log('[EmulatorPanel] 🔍 checkBreakpointHit checking for breakpoint...');
    
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
        
        // Map address → VPy line using helper
        if (pdbData) {
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
  }, [debugState, pdbData]);

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
          
          // Now set debugState to 'running' AFTER checking pause state
          vecx.debugState = 'running';
          vecx.stepMode = null; // Clear any step mode
          vecx.stepTargetAddress = null;
          console.log('[EmulatorPanel] ✓ JSVecx debugState set to running, step mode cleared');
          
          // Resume from breakpoint if it was paused by one
          if (wasPausedByBreakpoint) {
            console.log('[EmulatorPanel] 🔓 Resuming from breakpoint');
            if (vecx.resumeFromBreakpoint) {
              vecx.resumeFromBreakpoint();
            }
          } else if (!vecx.running) {
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
          if (vecx.running) {
            vecx.stop();
          }
          break;
          
        case 'debug-stop':
          console.log('[EmulatorPanel] 🛑 Debug: Stop execution');
          if (vecx.running) {
            vecx.stop();
          }
          vecx.reset();
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
            if (currentPC && stepOverPdbData) {
              // Get line address map for both single-bank and multibank formats
              const lineAddressMap = getLineAddressMap(stepOverPdbData);
              
              // Find current line by exact match or closest previous address
              let currentLine: number | null = null;
              
              // First try exact match
              for (const [line, addr] of Object.entries(lineAddressMap)) {
                if (addr === currentPC) {
                  currentLine = parseInt(line, 10);
                  break;
                }
              }
              
              // If no exact match, find the line with the closest address <= currentPC
              if (currentLine === null) {
                let closestLine: number | null = null;
                let closestAddr = 0;
                for (const [line, addr] of Object.entries(lineAddressMap)) {
                  if (addr <= currentPC && addr > closestAddr) {
                    closestAddr = addr;
                    closestLine = parseInt(line, 10);
                  }
                }
                currentLine = closestLine;
                if (currentLine !== null) {
                  console.log(`[EmulatorPanel] Step Over: PC 0x${currentPC.toString(16)} mapped to closest line ${currentLine} (addr: 0x${closestAddr.toString(16)})`);
                }
              }
              
              if (currentLine !== null) {
                // Find next line with address
                const sortedLines = Object.keys(lineAddressMap).map(l => parseInt(l, 10)).sort((a, b) => a - b);
                const nextLine = sortedLines.find(l => l > currentLine!);
                if (nextLine && lineAddressMap[nextLine]) {
                  const targetAddr = lineAddressMap[nextLine];
                  console.log(`[EmulatorPanel] Step Over: line ${currentLine} → ${nextLine} (0x${targetAddr.toString(16)})`);
                  vecx.debugStepOver(targetAddr);
                } else {
                  // No next line found - stop execution instead of auto-wrapping
                  console.log(`[EmulatorPanel] ⚠️ Step Over: No next line after ${currentLine}, stopping execution`);
                  debugStoreForStepOver.setState('paused');
                  if (vecx.running) {
                    vecx.stop();
                  }
                }
              } else {
                console.log(`[EmulatorPanel] ⚠️ Step Over: Could not map PC 0x${currentPC.toString(16)} to any line`);
              }
            }
          }
          break;
          
        case 'debug-step-into':
          console.log('[EmulatorPanel] 🔽 Debug: Step into');
          
          const debugStoreForStepInto = useDebugStore.getState();
          debugStoreForStepInto.setState('running');
          
          // FIXED (2026-01-11): Execute using JSVecx's built-in step mechanism
          // Instead of manually looping, let JSVecx handle stepping properly
          if (vecx.e6809 && vecx.debugStepInto) {
            const currentPC = vecx.e6809.reg_pc;
            const currentVpyLine = getCurrentVpyLineForPC(currentPC, debugStoreForStepInto.pdbData);
            
            console.log(`[EmulatorPanel] 📍 Single step from VPy line ${currentVpyLine}, PC ${formatAddress(currentPC)}`);
            
            // Execute ONE instruction and let the normal pause mechanism handle line updates
            vecx.debugStepInto(false);
            
            // The emulator will pause after one step, and the 'debugger-paused' handler
            // will update the current line based on the new PC
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
              
              // Get line address map for both single-bank and multibank formats
              const lineAddressMap = getLineAddressMap(currentPdbData);
              const pcNum = parseInt(pcHex, 16);  // Convert "009b" to 155 (decimal)
              for (const [line, addr] of Object.entries(lineAddressMap)) {
                const addrNum = typeof addr === 'string' ? parseInt(addr, 10) : addr;
                if (addrNum === pcNum) {
                  vpyLine = parseInt(line, 10);
                  console.log(`[EmulatorPanel] 🔄 PC back in VPy code at line ${vpyLine} - exiting ASM debugging mode`);
                  (window as any).asmDebuggingMode = false;
                  (window as any).asmDebuggingFile = null;
                  backInVpy = true;
                  
                  // CRITICAL: Switch back to VPy file automatically
                  const editorStore = useEditorStore.getState();
                  
                  // Get the VPy source file URI from lastCompiledBinary
                  // (replace .bin with .vpy and go to src/ instead of build/)
                  let vpyUri: string | null = null;
                  if (lastCompiledBinary) {
                    // From: /path/to/project/build/test_bp_min.bin
                    // To:   /path/to/project/src/main.vpy
                    const projectRoot = lastCompiledBinary.substring(0, lastCompiledBinary.lastIndexOf('/build/'));
                    // Try to get source file from vpyLineMap, fallback to main.vpy
                    let sourceFile = 'main.vpy';
                    if (currentPdbData.vpyLineMap && Object.keys(currentPdbData.vpyLineMap).length > 0) {
                      const firstEntry = Object.values(currentPdbData.vpyLineMap)[0] as any;
                      if (firstEntry && firstEntry.file) {
                        sourceFile = firstEntry.file;
                      }
                    }
                    vpyUri = `file://${projectRoot}/src/${sourceFile}`;
                    
                    console.log(`[EmulatorPanel] 🔄 Auto-switching to VPy file: ${vpyUri}`);
                    editorStore.gotoLocation(vpyUri, vpyLine, 1);
                  } else {
                    console.error(`[EmulatorPanel] ❌ Cannot switch to VPy - no lastCompiledBinary`);
                  }
                  break;
                }
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
            
            // Check if PC is in VPy code range (lineMap or vpyLineMap)
            let foundInVpy = false;
            const lineAddressMap2 = getLineAddressMap(currentPdbData);
            console.log(`[EmulatorPanel] 🔍 DEBUG lineAddressMap2:`, lineAddressMap2);
            console.log(`[EmulatorPanel] 🔍 DEBUG pcHex from event:`, event.data.pc, 'parsed:', pcHex);
            const pcNum = parseInt(pcHex, 16);  // Convert "009b" to 155 (decimal)
            console.log(`[EmulatorPanel] 🔍 DEBUG pcNum (converted):`, pcNum);
            for (const [line, addr] of Object.entries(lineAddressMap2)) {
              const addrNum = typeof addr === 'string' ? parseInt(addr, 10) : addr;
              console.log(`[EmulatorPanel] 🔍 DEBUG comparing: line=${line}, addr=${addr}, addrNum=${addrNum} vs pcNum=${pcNum}`);
              if (addrNum === pcNum) {
                const lineNumber = parseInt(line, 10);
                // Get VPy filename from vpyLineMap or default to 'main.vpy'
                let vpyFileName = 'main.vpy';
                if (currentPdbData.vpyLineMap && Object.keys(currentPdbData.vpyLineMap).length > 0) {
                  const firstEntry = Object.values(currentPdbData.vpyLineMap)[0] as any;
                  if (firstEntry && firstEntry.file) {
                    vpyFileName = firstEntry.file;
                  }
                }
                console.log(`[EmulatorPanel] 📍 Highlighting VPy line ${lineNumber} in ${vpyFileName} (PC: ${event.data.pc})`);
                debugStore.setCurrentVpyLine(lineNumber); // CRITICAL: file is derived from pdbData.source
                
                // CRITICAL: Auto-switch to VPy file if we're not already in it
                const editorStore = useEditorStore.getState();
                const activeUri = editorStore.active;
                
                // Search for the VPy file in open documents
                const vpyDoc = editorStore.documents.find(d => {
                  const docFileName = d.uri.split('/').pop() || '';
                  return docFileName === vpyFileName;
                });
                
                if (vpyDoc) {
                  // File is already open - switch to it
                  if (activeUri !== vpyDoc.uri) {
                    console.log(`[EmulatorPanel] 🔄 Switching to open tab: ${vpyFileName}`);
                    editorStore.setActive(vpyDoc.uri);
                  }
                } else {
                  // File is not open - use gotoLocation to open it (auto-creates if not exists)
                  const activeDoc = editorStore.documents.find(d => d.uri === activeUri);
                  if (activeDoc) {
                    // Extract directory path from URI (remove file:// prefix first, then get directory)
                    let uriPath = activeDoc.uri.startsWith('file://') 
                      ? activeDoc.uri.substring(7) 
                      : activeDoc.uri;
                    let dirPath = uriPath.substring(0, uriPath.lastIndexOf('/'));
                    
                    // CRITICAL: If we're in /build directory, go up to project root and enter /src
                    if (dirPath.endsWith('/build')) {
                      const projectRoot = dirPath.substring(0, dirPath.lastIndexOf('/build'));
                      dirPath = `${projectRoot}/src`;
                      console.log(`[EmulatorPanel] 🔄 Adjusted path from /build to /src: ${dirPath}`);
                    }
                    
                    const vpyPath = `file://${dirPath}/${vpyFileName}`;
                    
                    console.log(`[EmulatorPanel] 📂 Opening VPy file:`);
                    console.log(`   activeDoc.uri: ${activeDoc.uri}`);
                    console.log(`   uriPath (after removing file://): ${uriPath}`);
                    console.log(`   dirPath (adjusted): ${dirPath}`);
                    console.log(`   vpyFileName: ${vpyFileName}`);
                    console.log(`   vpyPath (final): ${vpyPath}`);
                    console.log(`   lineNumber: ${lineNumber}`);
                    console.log(`[EmulatorPanel] Calling gotoLocation with vpyPath=${vpyPath}, lineNumber=${lineNumber}`);
                    editorStore.gotoLocation(vpyPath, lineNumber, 1);
                  } else {
                    console.log(`[EmulatorPanel] ⚠️ Could not find activeDoc with uri: ${activeUri}`);
                  }
                }
                
                foundInVpy = true;
                break;
              }
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

  // Listen for F5 hotkey from Electron (continue debugging)
  useEffect(() => {
    const electronAPI = (window as any).electronAPI;
    if (!electronAPI?.ipcRenderer) return;
    
    const handleF5Continue = () => {
      console.log('[EmulatorPanel] 🎮 F5 pressed - triggering debug continue');
      window.postMessage({ type: 'debug-continue' }, '*');
    };
    
    electronAPI.ipcRenderer.on('debug-continue-hotkey', handleF5Continue);
    return () => electronAPI.ipcRenderer.removeListener('debug-continue-hotkey', handleF5Continue);
  }, []);

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
        vecx.reset();
        console.log('[EmulatorPanel] ✓ Second reset after ROM load');
        
        // Si estaba corriendo, reiniciar
        if (status === 'running') {
          vecx.debugState = 'running';
          vecx.start();
          console.log('[EmulatorPanel] ✓ Restarted after ROM load');
        }
        
        // CRÍTICO: Aplicar estado de audio después de reset/start
        setTimeout(() => {
          applyAudioState();
        }, 100);
      }, 50);
      
    } catch (error) {
      console.error('[EmulatorPanel] Failed to load ROM from dropdown:', error);
    }
  }, [status, loadOverlay, applyAudioState]); // dependencias: status, loadOverlay, applyAudioState

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

  // Apply initial audio state when emulator starts
  useEffect(() => {
    if (status === 'running') {
      applyAudioState();
    }
  }, [status, applyAudioState]); // Apply when status changes to running

  // Audio lifecycle: init worklet on enable; start/stop with status
  useEffect(() => {
    (async () => {
      if (audioEnabled) {
        try {
          await psgAudio.init();
          if (status === 'running') psgAudio.start();
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
    if (status === 'running') {
      psgAudio.start();
    } else {
      psgAudio.stop();
    }
  }, [status, audioEnabled]);

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
    win.PSG_LOG_ENABLED = true;
    win.PSG_LOG_LIMIT = 10000;
    console.log('[EmulatorPanel] PSG logging initialized: enabled=true, limit=10000, log length=' + win.PSG_WRITE_LOG.length);
  };

  // Enable PSG logging on mount and keep it enabled
  useEffect(() => {
    const win = window as any;
    if (!win.PSG_WRITE_LOG) win.PSG_WRITE_LOG = [];
    win.PSG_LOG_ENABLED = true;
    win.PSG_LOG_LIMIT = 10000;
    console.log('[EmulatorPanel] PSG logging enabled globally on mount');
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

  const onPlay = () => {
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
        win.OPCODE_TRACE_MAX = 5000;
        // Only enable full trace if explicitly requested (not by default)
        // win.OPCODE_TRACE_FULL = true;
        console.log('[EmulatorPanel] 🧹 Opcode trace cleared on reset');
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

  const onLoadROM = () => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.bin,.vec,.rom';
    input.onchange = async (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (!file) return;
      
      try {
        console.log(`[EmulatorPanel] Loading ROM: ${file.name} (${file.size} bytes)`);
        
        const arrayBuffer = await file.arrayBuffer();
        const romData = new Uint8Array(arrayBuffer);
        
        const vecx = (window as any).vecx;
        if (!vecx) {
          console.error('[EmulatorPanel] vecx instance not available');
          return;
        }
        
        // Convertir Uint8Array a string para JSVecX
        let cartDataString = '';
        for (let i = 0; i < romData.length; i++) {
          cartDataString += String.fromCharCode(romData[i]);
        }
        
        // Cargar ROM en Globals.cartdata (método correcto para JSVecX)
        // Globals es una variable global, no está en window
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
        setLoadedROM(`${file.name} (${romData.length} bytes)`);
        
        // Save the loaded ROM info for persistence
        setLastRom(null, file.name); // File object doesn't have path, just name
        
        // Resetear combo selector (carga manual no debe seleccionar combo)
        setSelectedROM('');
        
        // Recalcular overlay basado en nombre del archivo
        await loadOverlay(file.name);
        
        // Reset después de cargar - esto copiará cartdata al array cart[]
        console.log('🔄 [EmulatorPanel] CALLING vecx.reset() - Reason: File upload (insert cartridge)');
        console.log('📍 [EmulatorPanel] Reset stack trace:', new Error().stack);
        vecx.reset();
        console.log('[EmulatorPanel] ✓ Reset after ROM load');
        
        // Si estaba corriendo, reiniciar
        if (status === 'running') {
          vecx.debugState = 'running';
          vecx.start();
          console.log('[EmulatorPanel] ✓ Restarted after ROM load');
        }
        
      } catch (error) {
        console.error('[EmulatorPanel] Failed to load ROM:', error);
      }
    };
    
    input.click();
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
                    // Bigger trace to capture the real jump into RAM/garbage
                    (window as any).OPCODE_TRACE_MAX = 5000;
                    // Full trace streaming to disk (.trace next to binary)
                    // Only enable if explicitly set via --enable-tracebin flag
                    // (window as any).OPCODE_TRACE_FULL = true;
                    (window as any).CURRENT_ROM_NAME = romName + '.bin';
                    (window as any).CURRENT_ROM_PATH = lastCompiledBinary;
                    console.log('[EmulatorPanel] 🧹 Opcode trace cleared for:', romName + '.bin');
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
      
      // Skip loading compiled ROM - go straight to default Minestorm
      
      // Fallback: Cargar Minestorm
      console.log('[EmulatorPanel] Loading default: Minestorm');
      await loadOverlay('minestorm.bin');
      setLoadedROM('BIOS - Minestorm');
      
      const vecx = (window as any).vecx;
      if (vecx) {
        if (emulatorWasRunning) {
          vecx.debugState = 'running';
          vecx.start();
          setStatus('running');
        } else {
          vecx.stop();
          setStatus('stopped');
        }
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

    const handleCompiledBin = (payload: { base64: string; size: number; binPath: string; pdbData?: any }) => {
      console.log(`[EmulatorPanel] Loading compiled binary: ${payload.binPath} (${payload.size} bytes)`);
      
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
      
      // Verificar si estamos cargando para debug session (no auto-start)
      const loadingForDebug = useDebugStore.getState().loadingForDebug;
      
      try {
        // Convertir base64 a bytes y cargar en JSVecX
        const binaryData = atob(payload.base64);
        const vecx = (window as any).vecx;
        
        if (!vecx) {
          console.error('[EmulatorPanel] JSVecX instance not available for loading binary');
          return;
        }

        // Detener emulador antes de cargar
        console.log('[EmulatorPanel] Stopping emulator before load...');
        vecx.stop();
        console.log('[EmulatorPanel] Emulator stopped');
        
        // Cargar el binario en la instancia global Globals.cartdata
        const Globals = (window as any).Globals;
        if (Globals) {
          Globals.cartdata = binaryData;
          console.log('[EmulatorPanel] ✓ Binary loaded into Globals.cartdata');
          
          // Dispatch event para notificar a otros paneles
          window.dispatchEvent(new Event('programLoaded'));
        }
        
        // CRITICAL: Verificar que JSVecX esté completamente inicializado antes de reset
        // Si el panel del emulador no estaba visible, JSVecX puede no estar inicializado
        console.log('[EmulatorPanel] Checking JSVecX initialization...');
        const isInitialized = vecx.ram && vecx.ram.length > 0;
        
        if (!isInitialized) {
          console.warn('[EmulatorPanel] JSVecX not initialized - running full initialization...');
          // Inicializar JSVecX completamente (igual que cuando el panel es visible)
          try {
            // Fase 1: Reset inicial
            vecx.reset();
            console.log('[EmulatorPanel] ✓ JSVecX reset successful');
            
            // Fase 2: Main initialization (necesario para setup completo)
            vecx.main();
            console.log('[EmulatorPanel] ✓ JSVecX main() successful');
            
            // CRITICAL: Set debugState to 'running' after initialization
            vecx.debugState = 'running';
            console.log('[EmulatorPanel] ✓ JSVecx debugState set to running (after main)');
            
            // Fase 3: CRITICAL - Inicializar joystick input state a valores neutros
            // Sin esto, las variables de joystick contienen basura y causan movimiento fantasma
            vecx.leftHeld = false;
            vecx.rightHeld = false;
            vecx.upHeld = false;
            vecx.downHeld = false;
            vecx.shadow_snd_regs14 = 0xFF; // PSG: 0xFF = all buttons released (active low)
            vecx.write8(0xC80F, 0x00);     // Vec_Btn_State: 0x00 = all buttons released (active high)
            // console.log('[EmulatorPanel] ✓ Joystick state initialized to neutral');
            
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
          
          // DO NOT call vecx.start() yet - MonacoEditorWrapper will start after adding breakpoints
          console.log('[EmulatorPanel] ⏸️ Emulator ready in debug mode (waiting for breakpoint sync)');
          
          // NO resetear el flag aquí - mantenerlo activo durante toda la sesión de debug
          // Se reseteará cuando el usuario haga Stop (debug.stop en main.tsx)
        }
        
        // Actualizar ROM cargada y buscar overlay
        const romName = payload.binPath.split(/[/\\]/).pop()?.replace(/\.(bin|BIN)$/, '') || 'compiled';
        setLoadedROM(`Compiled - ${romName}`);
        
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
        
      } catch (error) {
        console.error('[EmulatorPanel] Failed to load compiled binary:', error);
      }
    };

    electronAPI.onCompiledBin(handleCompiledBin);
    console.log('[EmulatorPanel] ✓ Registered onCompiledBin listener');
    
    // No cleanup function needed - onCompiledBin typically doesn't return one
  }, [loadOverlay, setLoadedROM]);

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
      <EmulatorOutputInfo />

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
        
        {/* Botón Audio Mute/Unmute */}
        <button 
          style={{
            ...btn,
            backgroundColor: getCurrentAudioState() ? '#2a4a2a' : '#4a2a2a',
            color: getCurrentAudioState() ? '#afa' : '#faa',
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
          title={getCurrentAudioState() ? 'Mute audio' : 'Unmute audio'}
        >
          {getCurrentAudioState() ? '🔊' : '🔇'}
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