import React, { useEffect, useState, useCallback } from 'react';
import { MemoryGridView } from './MemoryGridView';
import { useDebugStore } from '../../state/debugStore';

interface Region { name:string; start:number; end:number; }

interface VariableInfo {
  name: string;
  address: string;
  size: number;
  type: string;
  declLine?: number;
}

// Memory map aligned with README (inclusive ranges)
const REGIONS: Region[] = [
  { name: 'Cartridge 0000-BFFF', start: 0x0000, end: 0xBFFF },
  { name: 'Gap C000-C7FF', start: 0xC000, end: 0xC7FF },
  { name: 'RAM Shadow C800-CFFF', start: 0xC800, end: 0xCFFF },
  { name: 'VIA Shadow D000-D7FF', start: 0xD000, end: 0xD7FF },
  { name: 'Illegal D800-DFFF', start: 0xD800, end: 0xDFFF },
  { name: 'BIOS E000-FFFF', start: 0xE000, end: 0xFFFF },
];

function formatChunk(bytes: Uint8Array, addr: number, width = 16): string {
  let hex = '';
  let ascii = '';
  for (let i = 0; i < width; i++) {
    const b = bytes[addr + i];
    if (i === 8) hex += ' '; // mid separator
    hex += b.toString(16).padStart(2, '0') + ' ';
    ascii += (b >= 0x20 && b < 0x7f) ? String.fromCharCode(b) : '.';
  }
  return `${addr.toString(16).padStart(4,'0')}: ${hex} ${ascii}`;
}

function dumpRegion(bytes: Uint8Array, r: Region): string {
  const lines: string[] = [`>>> ${r.name}`];
  for (let a = r.start; a <= r.end; a += 16) {
    lines.push(formatChunk(bytes, a));
  }
  return lines.join('\n');
}

const NO_VARIABLES: Record<string, VariableInfo> = {};

export const MemoryPanel: React.FC = () => {
  const [text, setText] = useState<string>('');
  const [ts, setTs] = useState<number>(0);
  const [viewMode, setViewMode] = useState<'text' | 'grid'>('grid');
  const [memory, setMemory] = useState<Uint8Array>(new Uint8Array(65536));
  const [autoUpdate, setAutoUpdate] = useState<boolean>(false);
  const [targetAddress, setTargetAddress] = useState<number | null>(null);
  const [addressInput, setAddressInput] = useState<string>('');

  // The program's variables: the .pdb of the last build (or of the project's last
  // one, read when the project opens), kept in the debug store. Read from there, the
  // panel has them however late it is opened.
  const pdbVariables = useDebugStore((st) => st.pdbData?.variables);
  const variables = (pdbVariables ?? NO_VARIABLES) as Record<string, VariableInfo>;

  const refresh = useCallback(() => {
    const vecx = (window as any).vecx;
    if (!vecx) {
      setText('[memory] JSVecX not available');
      setMemory(new Uint8Array(65536));
      return;
    }
    
    try {
      // Crear snapshot de memoria - NUEVO array cada vez para forzar re-render
      const snap = new Uint8Array(65536);
      
      // OPTIMIZED: Acceso directo a RAM en lugar de 2048 llamadas a read8()!
      // JSVecx tiene vecx.ram (Array de 1024 bytes) mapeado a $C800-$CBFF
      // Esto es ~1000x más rápido que el loop anterior
      if (vecx.ram && Array.isArray(vecx.ram)) {
        // JSVecx ram es 1024 bytes, mapeado a $C800-$CBFF
        // La Vectrex real tiene 2KB ($C800-$CFFF) pero JSVecx emula solo 1KB
        for (let i = 0; i < Math.min(vecx.ram.length, 0x800); i++) {
          snap[0xC800 + i] = (vecx.ram[i] & 0xff);
        }
      } else {
        console.error('[MemoryPanel] vecx.ram not available - cannot read memory');
      }
      
      // NO leer VIA registers - son I/O y pueden causar cuelgues
      // (VIA registers en $D000-$D07F no necesitan visualizarse para debug de variables)
      
      // Opcional: leer cartridge ROM directamente si está cargado
      if (vecx.cart && Array.isArray(vecx.cart) && vecx.cart.length > 0) {
        const len = Math.min(vecx.cart.length, 0x1000); // Primeros 4KB
        for (let i = 0; i < len; i++) {
          snap[i] = (vecx.cart[i] & 0xff);
        }
      }
      
      const now = Date.now();
      
      // Update memory state - CREAR NUEVO OBJETO para forzar re-render
      setMemory(new Uint8Array(snap));
      setTs(now);
      
      // Generate text view
      const parts: string[] = [];
      REGIONS.forEach(r => parts.push(dumpRegion(snap, r)));
      setText(parts.join('\n\n'));
    } catch (e) {
      const errorMsg = '[memory] Failed to read memory from JSVecX: ' + e;
      setText(errorMsg);
      console.error('[MemoryPanel] Memory read error:', e);
      setMemory(new Uint8Array(65536));
    }
  }, []);

  useEffect(() => { refresh(); }, [refresh]);

  // Auto-update every 200ms when enabled
  useEffect(() => {
    if (!autoUpdate) return;
    
    const interval = setInterval(() => {
      refresh();
    }, 200);
    
    return () => clearInterval(interval);
  }, [autoUpdate, refresh]);

  const saveText = () => {
    const blob = new Blob([text], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `memory_dump_${ts}.txt`;
    a.click();
    URL.revokeObjectURL(url);
  };
  const saveBin = async () => {
    const vecx = (window as any).vecx;
    if (!vecx) {
      alert('JSVecX not available');
      return;
    }
    
    console.log('[MemoryPanel] Starting binary dump...');
    
    // NO pausar emulador - acceso directo es lo suficientemente rápido
    
    try {
      // Crear snapshot de memoria completa para dump binario
      const data = new Uint8Array(65536);
      
      // Usar acceso directo a arrays internos (rápido, sin bloqueos)
      if (vecx.ram && Array.isArray(vecx.ram)) {
        for (let i = 0; i < Math.min(vecx.ram.length, 0x800); i++) {
          data[0xC800 + i] = (vecx.ram[i] & 0xff);
        }
      }
      
      if (vecx.cart && Array.isArray(vecx.cart)) {
        const len = Math.min(vecx.cart.length, 0xC000); // Hasta $BFFF
        for (let i = 0; i < len; i++) {
          data[i] = (vecx.cart[i] & 0xff);
        }
      }
      
      // NO leer VIA registers - son I/O y pueden causar cuelgues
      
      const blob = new Blob([data.buffer], { type: 'application/octet-stream' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `memory_dump_${ts}.bin`;
      a.click();
      URL.revokeObjectURL(url);
      
      console.log('[MemoryPanel] ✓ Binary dump completed');
    } catch (e) {
      alert('Failed to read memory from JSVecX: ' + e);
      console.error('[MemoryPanel] Binary dump error:', e);
    }
  };

  // Jump to address functionality
  const handleJumpToAddress = () => {
    const input = addressInput.trim();
    if (!input) return;
    
    // Parse different formats: $C942, 0xC942, C942, 51522
    let addr: number;
    if (input.startsWith('$')) {
      addr = parseInt(input.substring(1), 16);
    } else if (input.startsWith('0x') || input.startsWith('0X')) {
      addr = parseInt(input.substring(2), 16);
    } else if (/^[0-9A-Fa-f]{1,4}$/.test(input)) {
      addr = parseInt(input, 16);
    } else if (/^\d+$/.test(input)) {
      addr = parseInt(input, 10);
    } else {
      alert(`Invalid address format: "${input}"\n\nSupported formats:\n  • $C942 (hex with $)\n  • 0xC942 (hex with 0x)\n  • C942 (hex)\n  • 51522 (decimal)`);
      return;
    }
    
    if (addr < 0 || addr > 0xFFFF) {
      alert(`Address out of range: ${addr}\nMust be between 0x0000 and 0xFFFF`);
      return;
    }
    
    setTargetAddress(addr);
    console.log(`[MemoryPanel] Jumping to address $${addr.toString(16).toUpperCase()} (${addr})`);
  };

  const handleAddressInputKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      handleJumpToAddress();
    }
  };

  return (
    <div style={{display:'flex', flexDirection:'column', height:'100%', fontFamily:'monospace'}}>
      <div style={{padding:'4px', borderBottom:'1px solid #444', display:'flex', gap:8, alignItems:'center'}}>
        <button onClick={refresh}>Refresh</button>        
        <button 
          onClick={() => setAutoUpdate(!autoUpdate)}
          style={{
            backgroundColor: autoUpdate ? '#2ecc71' : 'transparent',
            color: autoUpdate ? 'white' : 'inherit',
            border: '1px solid #555',
            padding: '4px 12px',
            cursor: 'pointer',
            fontWeight: autoUpdate ? 'bold' : 'normal'
          }}
        >
          {autoUpdate ? '⏸ Pause' : '▶ Auto 200ms'}
        </button>
        <button onClick={saveText}>Save TXT</button>
        <button onClick={saveBin}>Save BIN</button>
        
        {/* View mode toggle */}
        <div style={{marginLeft:16, display:'flex', gap:4}}>
          <button 
            onClick={() => setViewMode('grid')}
            style={{
              backgroundColor: viewMode === 'grid' ? '#3498db' : 'transparent',
              color: viewMode === 'grid' ? 'white' : 'inherit',
              border: '1px solid #555',
              padding: '4px 12px',
              cursor: 'pointer'
            }}
          >
            Grid
          </button>
          <button 
            onClick={() => setViewMode('text')}
            style={{
              backgroundColor: viewMode === 'text' ? '#3498db' : 'transparent',
              color: viewMode === 'text' ? 'white' : 'inherit',
              border: '1px solid #555',
              padding: '4px 12px',
              cursor: 'pointer'
            }}
          >
            Text
          </button>
        </div>
        
        <span style={{marginLeft:'auto', opacity:0.7}}>
          {(() => {
            // Calcular memoria usada sumando tamaños de variables
            const usedBytes = Object.values(variables).reduce((sum, v) => sum + (v.size || 0), 0);
            const totalBytes = 1024; // JSVecx RAM size (0x400 bytes)
            const freeBytes = totalBytes - usedBytes;
            const usedPercent = ((usedBytes / totalBytes) * 100).toFixed(1);
            
            return (
              <>
                <span style={{color: usedBytes > 900 ? '#e74c3c' : usedBytes > 700 ? '#f39c12' : '#2ecc71'}}>
                  {usedBytes}B used
                </span>
                {' / '}
                <span style={{color: '#95a5a6'}}>{freeBytes}B free</span>
                {' of '}
                {totalBytes}B
                {' '}({usedPercent}%)
                {ts > 0 && ` • ${new Date(ts).toLocaleTimeString()}`}
                {Object.keys(variables).length > 0 && ` • ${Object.keys(variables).length} vars`}
              </>
            );
          })()}
        </span>
      </div>
      
      {viewMode === 'grid' ? (
        <MemoryGridView memory={memory} variables={variables} timestamp={ts} />
      ) : (
        <div style={{flex:1, overflow:'auto', padding:'4px', whiteSpace:'pre', fontSize:'11px', lineHeight:1.2}}>
          {text || 'No data'}
        </div>
      )}
    </div>
  );
};

export default MemoryPanel;
