import React, { useEffect, useState, useRef, useMemo } from 'react';
import { useDebugStore } from '../../state/debugStore.js';

interface VecxMetrics {
  totalCycles: number;
  instructionCount: number;
  frameCount: number;
  running: boolean;
  vectorCount: number;
}

const PerformanceChart: React.FC<{
  label: string;
  data: number[];
  max: number;
  color: string;
  dangerZone?: number;
  unit?: string;
}> = ({ label, data, max, color, dangerZone, unit = '' }) => {
  const current = data[data.length - 1] || 0;
  const percentage = Math.min((current / max) * 100, 100);
  const isDanger = dangerZone && current >= dangerZone;
  const dangerPercentage = dangerZone ? (dangerZone / max) * 100 : 0;

  return (
    <div style={{ flex: 1, minWidth: 0, overflow: 'hidden' }}>
      <div style={{
        fontSize: '11px',
        marginBottom: '4px',
        color: isDanger ? '#ff6666' : '#ddd',
        fontWeight: 'bold',
        textAlign: 'center',
        whiteSpace: 'nowrap'
      }}>
        {label}{isDanger ? ' ⚠️' : ''}: {current.toLocaleString()}{unit}
      </div>

      {/* Progress bar */}
      <div style={{
        width: '100%',
        height: '16px',
        background: '#2a2a2a',
        borderRadius: '8px',
        overflow: 'hidden',
        border: '1px solid #444',
        position: 'relative',
        marginBottom: '6px'
      }}>
        {dangerZone && (
          <div style={{
            position: 'absolute',
            left: `${dangerPercentage}%`,
            width: `${100 - dangerPercentage}%`,
            height: '100%',
            background: 'rgba(255, 68, 68, 0.2)',
            zIndex: 1
          }} />
        )}

        <div style={{
          width: `${percentage}%`,
          height: '100%',
          background: isDanger ?
            'linear-gradient(90deg, #ff4444, #ff6666)' :
            `linear-gradient(90deg, ${color}, ${color}aa)`,
          transition: 'width 0.3s ease-out',
          borderRadius: '8px',
          zIndex: 2,
          position: 'relative',
          boxShadow: isDanger ? '0 0 8px rgba(255, 68, 68, 0.6)' : `0 0 6px ${color}44`
        }} />

        {dangerZone && (
          <div style={{
            position: 'absolute',
            left: `${dangerPercentage}%`,
            width: '2px',
            height: '100%',
            background: '#ff4444',
            zIndex: 3,
            boxShadow: '0 0 4px #ff4444'
          }} />
        )}
      </div>

      {/* History sparkline */}
      <div style={{
        display: 'flex',
        height: '24px',
        alignItems: 'end',
        background: '#1a1a1a',
        padding: '2px',
        borderRadius: '4px',
        border: '1px solid #333',
        overflow: 'hidden'
      }}>
        {data.map((value, index) => {
          const barHeight = Math.max(2, (value / max) * 20);
          const barColor = dangerZone && value >= dangerZone ? '#ff4444' : color;
          return (
            <div
              key={index}
              style={{
                flex: 1,
                minWidth: '1px',
                height: `${barHeight}px`,
                background: barColor,
                opacity: 0.6 + (index / Math.max(data.length, 1)) * 0.4,
                transition: 'height 0.2s ease-out',
                marginRight: index < data.length - 1 ? '1px' : '0'
              }}
            />
          );
        })}
      </div>
    </div>
  );
};

// Vectrex user RAM: $C880-$CBEA = 874 bytes available
const VECTREX_USER_RAM_START = 0xC880;
const VECTREX_USER_RAM_END = 0xCBEA;
const VECTREX_USER_RAM_TOTAL = VECTREX_USER_RAM_END - VECTREX_USER_RAM_START; // 874

export const OutputPanel: React.FC = () => {
  const [metrics, setMetrics] = useState<VecxMetrics | null>(null);
  const [cyclesData, setCyclesData] = useState<number[]>([]);
  const [vectorData, setVectorData] = useState<number[]>([]);
  const timerRef = useRef<number|null>(null);
  const prevRef = useRef<{ cycles: number; frames: number } | null>(null);

  // RAM allocated: computed from PDB variables (compile-time info)
  const pdbData = useDebugStore(s => s.pdbData);
  const ramAllocated = useMemo(() => {
    if (!pdbData?.variables) return 0;
    const vars = Object.values(pdbData.variables);
    if (vars.length === 0) return 0;
    // Only count variables in user RAM range ($C880-$CBEA).
    // PDB also contains ROM constants and BIOS symbols — skip those.
    let highestEnd = VECTREX_USER_RAM_START;
    for (const v of vars) {
      const addr = parseInt(v.address, 16);
      if (isNaN(addr) || addr < VECTREX_USER_RAM_START || addr >= VECTREX_USER_RAM_END) continue;
      const end = addr + v.size;
      if (end > highestEnd) highestEnd = end;
    }
    return highestEnd - VECTREX_USER_RAM_START;
  }, [pdbData]);

  const fetchStats = () => {
    try {
      const vecx = (window as any).vecx;
      if (!vecx) {
        setMetrics(null);
        return;
      }

      const m = vecx.getMetrics && vecx.getMetrics();
      setMetrics(m || null);

      if (m && m.running) {
        // Cycles per frame: delta cycles / delta frames since last sample
        let cyclesPerFrame = 0;
        const prev = prevRef.current;
        if (prev && m.frameCount > prev.frames) {
          const dCycles = m.totalCycles - prev.cycles;
          const dFrames = m.frameCount - prev.frames;
          cyclesPerFrame = Math.round(dCycles / dFrames);
        }
        prevRef.current = { cycles: m.totalCycles, frames: m.frameCount };

        // Vector count: directly from emulator (last completed frame)
        const vectors = m.vectorCount || 0;

        setCyclesData(prev => [...prev.slice(-39), cyclesPerFrame]);
        setVectorData(prev => [...prev.slice(-39), vectors]);
      } else {
        prevRef.current = null;
        setCyclesData(prev => [...prev.slice(-39), 0]);
        setVectorData(prev => [...prev.slice(-39), 0]);
      }
    } catch (e) {
      setMetrics(null);
    }
  };

  useEffect(() => { fetchStats(); }, []);
  useEffect(() => {
    timerRef.current = window.setInterval(fetchStats, 500);
    return () => { if (timerRef.current) clearInterval(timerRef.current); };
  }, []);

  // RAM bar: static value from PDB, shown as percentage of available user RAM
  const ramPercentage = Math.min((ramAllocated / VECTREX_USER_RAM_TOTAL) * 100, 100);
  const ramDanger = ramAllocated >= 700;

  return (
    <div style={{display:'flex', flexDirection:'column', height:'100%', fontSize:12}}>
      <div style={{padding:'8px 12px', borderBottom:'1px solid #333', display:'flex', alignItems:'center', gap:12}}>
        <span style={{marginLeft:'auto', opacity:0.7}}>
          Status: {metrics?.running ? '🟢 Running' : '🔴 Stopped'}
        </span>
      </div>

      <div style={{
        padding: '16px',
        flex: 1,
        overflow: 'hidden'
      }}>
        <div style={{
          display: 'flex',
          gap: '16px',
          width: '100%'
        }}>
          <PerformanceChart
            label="Cycles/Frame"
            data={cyclesData}
            max={50000}
            color="#00ff88"
            dangerZone={37500}
          />

          {/* RAM: static bar from PDB (no sparkline — compile-time value) */}
          <div style={{ flex: 1, minWidth: 0, overflow: 'hidden' }}>
            <div style={{
              fontSize: '11px',
              marginBottom: '4px',
              color: ramDanger ? '#ff6666' : '#ddd',
              fontWeight: 'bold',
              textAlign: 'center',
              whiteSpace: 'nowrap'
            }}>
              RAM{ramDanger ? ' ⚠️' : ''}: {ramAllocated} / {VECTREX_USER_RAM_TOTAL} bytes
            </div>

            <div style={{
              width: '100%',
              height: '16px',
              background: '#2a2a2a',
              borderRadius: '8px',
              overflow: 'hidden',
              border: '1px solid #444',
              position: 'relative',
              marginBottom: '6px'
            }}>
              {/* Danger zone background */}
              <div style={{
                position: 'absolute',
                left: '80%',
                width: '20%',
                height: '100%',
                background: 'rgba(255, 68, 68, 0.2)',
                zIndex: 1
              }} />

              {/* Fill bar */}
              <div style={{
                width: `${ramPercentage}%`,
                height: '100%',
                background: ramDanger ?
                  'linear-gradient(90deg, #ff4444, #ff6666)' :
                  'linear-gradient(90deg, #4488ff, #4488ffaa)',
                transition: 'width 0.3s ease-out',
                borderRadius: '8px',
                zIndex: 2,
                position: 'relative',
                boxShadow: ramDanger ? '0 0 8px rgba(255, 68, 68, 0.6)' : '0 0 6px #4488ff44'
              }} />

              {/* Danger line at 80% */}
              <div style={{
                position: 'absolute',
                left: '80%',
                width: '2px',
                height: '100%',
                background: '#ff4444',
                zIndex: 3,
                boxShadow: '0 0 4px #ff4444'
              }} />
            </div>

            {/* Label instead of sparkline */}
            <div style={{
              height: '24px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              background: '#1a1a1a',
              borderRadius: '4px',
              border: '1px solid #333',
              fontSize: '10px',
              color: '#888'
            }}>
              {ramAllocated > 0
                ? `${VECTREX_USER_RAM_TOTAL - ramAllocated} bytes free`
                : 'No PDB loaded'}
            </div>
          </div>

          <PerformanceChart
            label="Vectors/Frame"
            data={vectorData}
            max={200}
            color="#ffaa00"
            dangerZone={150}
          />
        </div>
      </div>
    </div>
  );
};
