/**
 * AnimationEditor - Visual editor for .vanim animation files
 *
 * Edits frame-based vector animations for Vectrex.
 * Each frame can reference external .vec assets (drawn as placeholders)
 * and contain inline vector paths for moving parts.
 */

import React, {
  useRef,
  useEffect,
  useState,
  useCallback,
  useMemo,
} from 'react';
import { useEditorStore } from '../state/editorStore';
import { useProjectStore } from '../state/projectStore';

// ============================================
// Types
// ============================================

interface VanimPoint {
  x: number;
  y: number;
}

interface VanimPath {
  name: string;
  intensity: number;
  points: VanimPoint[];
}

interface VanimFrame {
  index: number;
  duration_ticks: number;
  vec_refs: string[];
  paths: VanimPath[];
}

interface VanimResource {
  version: string;
  name: string;
  loop: boolean;
  frames: VanimFrame[];
}

interface AnimationEditorProps {
  resource?: VanimResource;
  onChange?: (resource: VanimResource) => void;
}

// .vec types (subset needed for rendering)
interface VecPoint { x: number; y: number; }
interface VecPath { name: string; intensity: number; closed: boolean; points: VecPoint[]; }
interface VecLayer { name: string; visible: boolean; paths: VecPath[]; }
interface VecResource { layers: VecLayer[]; }

type Tool = 'select' | 'pen';

// ============================================
// Defaults
// ============================================

const defaultResource: VanimResource = {
  version: '1.0',
  name: 'untitled',
  loop: true,
  frames: [{ index: 0, duration_ticks: 4, vec_refs: [], paths: [] }],
};

// ============================================
// Utilities
// ============================================

function cloneResource(r: VanimResource): VanimResource {
  return JSON.parse(JSON.stringify(r));
}


function canvasToWorld(
  mx: number,
  my: number,
  w: number,
  h: number,
  zoom: number,
  pan: { x: number; y: number }
): VanimPoint {
  const scale = Math.min(w, h) / 256;
  return {
    x: Math.round((mx - w / 2 - pan.x) / (scale * zoom)),
    y: Math.round(-(my - h / 2 - pan.y) / (scale * zoom)),
  };
}

// Search project directory tree for a .vec file by asset name
async function findVecFile(name: string, rootPath: string): Promise<string | null> {
  const target = `${name}.vec`;
  // Common locations to check first (fast path)
  const candidates = [
    `${rootPath}/assets/vectors/${target}`,
    `${rootPath}/assets/${target}`,
    `${rootPath}/vectors/${target}`,
  ];
  for (const p of candidates) {
    try {
      const r = await (window as any).files?.readFile?.(p);
      if (r) return p;
    } catch { /* not found */ }
  }
  // Fallback: ask the OS to list the assets/vectors dir
  try {
    const dir = await (window as any).files?.readDirectory?.(`${rootPath}/assets/vectors`);
    if (dir?.files) {
      const found = (dir.files as Array<{path: string}>).find(f => f.path.endsWith(`/${target}`));
      if (found) return found.path;
    }
  } catch { /* ignore */ }
  return null;
}

// ============================================
// Canvas drawing
// ============================================

function drawFrame(
  ctx: CanvasRenderingContext2D,
  w: number,
  h: number,
  frame: VanimFrame,
  selectedPathIdx: number | null,
  hoverPoint: { pathIdx: number; ptIdx: number } | null,
  zoom: number,
  pan: { x: number; y: number },
  resolvedVecs: Map<string, VecResource>
): void {
  ctx.clearRect(0, 0, w, h);

  // Background
  ctx.fillStyle = '#1a1a2e';
  ctx.fillRect(0, 0, w, h);

  const cx = w / 2;
  const cy = h / 2;
  const scale = Math.min(w, h) / 256;

  const toCanvas = (p: VanimPoint): [number, number] => [
    cx + p.x * scale * zoom + pan.x,
    cy - p.y * scale * zoom + pan.y,
  ];

  // Grid — draw relative to pan so it moves with the world
  ctx.strokeStyle = '#2a2a44';
  ctx.lineWidth = 0.5;
  const gridStep = 32 * scale * zoom;
  const gridOffsetX = (cx + pan.x) % gridStep;
  const gridOffsetY = (cy + pan.y) % gridStep;
  for (let gx = gridOffsetX; gx < w; gx += gridStep) {
    ctx.beginPath();
    ctx.moveTo(gx, 0);
    ctx.lineTo(gx, h);
    ctx.stroke();
  }
  for (let gy = gridOffsetY; gy < h; gy += gridStep) {
    ctx.beginPath();
    ctx.moveTo(0, gy);
    ctx.lineTo(w, gy);
    ctx.stroke();
  }

  // Crosshair at world origin
  const originX = cx + pan.x;
  const originY = cy + pan.y;
  ctx.strokeStyle = '#444466';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(originX, 0);
  ctx.lineTo(originX, h);
  ctx.stroke();
  ctx.beginPath();
  ctx.moveTo(0, originY);
  ctx.lineTo(w, originY);
  ctx.stroke();

  // Draw vec_refs — resolved if available, grey placeholder otherwise
  frame.vec_refs.forEach((ref) => {
    const vec = resolvedVecs.get(ref);
    if (vec) {
      ctx.save();
      for (const layer of vec.layers) {
        if (!layer.visible) continue;
        for (const path of layer.paths) {
          if (path.points.length === 0) continue;
          const brightness = path.intensity / 127;
          const v = Math.round(255 * brightness);
          ctx.strokeStyle = `rgb(${v},${v},${v})`;
          ctx.lineWidth = 1.5;
          ctx.beginPath();
          const [x0, y0] = toCanvas(path.points[0]);
          ctx.moveTo(x0, y0);
          for (let i = 1; i < path.points.length; i++) {
            const [xi, yi] = toCanvas(path.points[i]);
            ctx.lineTo(xi, yi);
          }
          if (path.closed && path.points.length > 2) {
            ctx.closePath();
          }
          ctx.stroke();
        }
      }
      ctx.restore();
    } else {
      // Placeholder for unresolved vec
      const boxHalf = 40 * scale * zoom;
      ctx.save();
      ctx.strokeStyle = '#555577';
      ctx.lineWidth = 1;
      ctx.setLineDash([4, 3]);
      ctx.strokeRect(originX - boxHalf, originY - boxHalf, boxHalf * 2, boxHalf * 2);
      ctx.setLineDash([]);
      ctx.fillStyle = '#555577';
      ctx.font = `${Math.max(10, 12 * scale)}px monospace`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(`[${ref}]`, originX, originY);
      ctx.restore();
    }
  });

  // Draw inline paths
  frame.paths.forEach((path, pathIdx) => {
    if (path.points.length === 0) return;
    const isSelected = pathIdx === selectedPathIdx;
    const brightness = path.intensity / 127;
    const r = Math.round(255 * brightness);
    const g = Math.round(255 * brightness);
    const b = Math.round(255 * brightness);
    const lineColor = isSelected
      ? '#ffff00'
      : `rgb(${r},${g},${b})`;

    ctx.save();
    ctx.strokeStyle = lineColor;
    ctx.lineWidth = isSelected ? 2 : 1.5;

    if (path.points.length > 1) {
      ctx.beginPath();
      const [x0, y0] = toCanvas(path.points[0]);
      ctx.moveTo(x0, y0);
      for (let i = 1; i < path.points.length; i++) {
        const [xi, yi] = toCanvas(path.points[i]);
        ctx.lineTo(xi, yi);
      }
      ctx.stroke();
    }

    // Draw points
    path.points.forEach((pt, ptIdx) => {
      const [px, py] = toCanvas(pt);
      const isHovered =
        hoverPoint?.pathIdx === pathIdx && hoverPoint?.ptIdx === ptIdx;
      const isFirst = ptIdx === 0;
      ctx.beginPath();
      const radius = isFirst ? 5 : isHovered ? 4 : 3;
      ctx.arc(px, py, radius, 0, Math.PI * 2);
      ctx.fillStyle = isHovered ? '#ffffff' : isFirst ? '#00ff88' : '#00cc66';
      ctx.fill();
    });

    ctx.restore();
  });
}

// ============================================
// Sub-components
// ============================================

interface FrameCardProps {
  frame: VanimFrame;
  selected: boolean;
  onClick: () => void;
  onDelete: () => void;
}

const FrameCard: React.FC<FrameCardProps> = ({
  frame,
  selected,
  onClick,
  onDelete,
}) => (
  <div
    onClick={onClick}
    style={{
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '6px 8px',
      marginBottom: 4,
      borderRadius: 4,
      cursor: 'pointer',
      background: selected ? '#3a3a6e' : '#1e1e3e',
      border: selected ? '1px solid #6666cc' : '1px solid #2a2a4a',
      userSelect: 'none',
    }}
  >
    <span style={{ color: '#ccc', fontSize: 12 }}>
      Frame {frame.index}
    </span>
    <span
      style={{
        fontSize: 10,
        color: '#88aaff',
        background: '#1a1a4e',
        padding: '1px 5px',
        borderRadius: 3,
        marginLeft: 4,
      }}
    >
      {frame.duration_ticks}t
    </span>
    <button
      onClick={(e) => {
        e.stopPropagation();
        onDelete();
      }}
      title="Delete frame"
      style={{
        background: 'transparent',
        border: 'none',
        color: '#884444',
        cursor: 'pointer',
        fontSize: 13,
        padding: '0 2px',
        marginLeft: 4,
      }}
    >
      x
    </button>
  </div>
);

interface TimelineCellProps {
  frame: VanimFrame;
  selected: boolean;
  isPlayhead: boolean;
  onClick: () => void;
}

const TimelineCell: React.FC<TimelineCellProps> = ({
  frame,
  selected,
  isPlayhead,
  onClick,
}) => (
  <div
    onClick={onClick}
    style={{
      minWidth: 56,
      height: 48,
      border: isPlayhead
        ? '2px solid #ffff00'
        : selected
        ? '2px solid #6666cc'
        : '1px solid #2a2a4a',
      borderRadius: 4,
      cursor: 'pointer',
      background: isPlayhead ? '#3a3a1e' : selected ? '#2a2a5e' : '#1a1a2e',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      flexShrink: 0,
      marginRight: 4,
      userSelect: 'none',
    }}
  >
    <span style={{ color: '#aaa', fontSize: 11 }}>{frame.index}</span>
    <span style={{ color: '#6688ff', fontSize: 10 }}>{frame.duration_ticks}t</span>
  </div>
);

// ============================================
// Main Component
// ============================================

export const AnimationEditor: React.FC<AnimationEditorProps> = ({
  resource,
  onChange,
}) => {
  const res: VanimResource = resource ?? defaultResource;

  const [selectedFrameIdx, setSelectedFrameIdx] = useState(0);
  const [selectedPathIdx, setSelectedPathIdx] = useState<number | null>(null);
  const [playing, setPlaying] = useState(false);
  const [hoverPoint, setHoverPoint] = useState<{
    pathIdx: number;
    ptIdx: number;
    x: number;
    y: number;
    wx: number;
    wy: number;
  } | null>(null);
  const [addingVecRef, setAddingVecRef] = useState(false);
  const [newVecRefText, setNewVecRefText] = useState('');

  // Zoom + Pan state
  const [zoom, setZoom] = useState(1.0);
  const [pan, setPan] = useState<{ x: number; y: number }>({ x: 0, y: 0 });

  // Tool state
  const [tool, setTool] = useState<Tool>('select');

  // Drag state
  const [dragging, setDragging] = useState<{ pathIdx: number; ptIdx: number } | null>(null);
  const [panDragging, setPanDragging] = useState<{
    startX: number;
    startY: number;
    startPan: { x: number; y: number };
  } | null>(null);

  // Resolved .vec assets for vec_refs rendering
  const [resolvedVecs, setResolvedVecs] = useState<Map<string, VecResource>>(new Map());
  const documents = useEditorStore(s => s.documents);
  const projectRoot = useProjectStore(s => s.project?.rootPath);

  const canvasRef = useRef<HTMLCanvasElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const playIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const safeFrameIdx = Math.min(selectedFrameIdx, res.frames.length - 1);
  const currentFrame = res.frames[safeFrameIdx] ?? res.frames[0];

  // ---- Resolve vec_refs from open documents or disk ----
  // Collect all unique vec ref names across all frames
  const allVecRefs = useMemo(() => {
    const names = new Set<string>();
    for (const frame of res.frames) {
      for (const name of frame.vec_refs) names.add(name);
    }
    return Array.from(names);
  }, [res.frames]);

  useEffect(() => {
    if (allVecRefs.length === 0) return;
    const next = new Map<string, VecResource>();

    const tryLoad = async () => {
      for (const name of allVecRefs) {
        // 1. Check open documents first
        const doc = documents.find(d => d.uri.endsWith(`/${name}.vec`));
        if (doc?.content) {
          try {
            next.set(name, JSON.parse(doc.content) as VecResource);
            continue;
          } catch { /* fall through */ }
        }

        // 2. Search project file tree for the .vec file and read from disk
        if (projectRoot) {
          // Search recursively through project for assets/vectors/<name>.vec
          const diskPath = await findVecFile(name, projectRoot);
          if (diskPath) {
            try {
              const result = await (window as any).files?.readFile?.(diskPath);
              const content = typeof result === 'string' ? result : result?.content;
              if (content) next.set(name, JSON.parse(content) as VecResource);
            } catch { /* ignore */ }
          }
        }
      }
      setResolvedVecs(new Map(next));
    };

    tryLoad();
  }, [allVecRefs, documents, projectRoot]);

  // ---- Canvas drawing ----

  useEffect(() => {
    const canvas = canvasRef.current;
    const container = containerRef.current;
    if (!canvas || !container) return;

    const w = container.clientWidth;
    const h = container.clientHeight;
    canvas.width = w;
    canvas.height = h;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    drawFrame(
      ctx,
      w,
      h,
      currentFrame,
      selectedPathIdx,
      hoverPoint
        ? { pathIdx: hoverPoint.pathIdx, ptIdx: hoverPoint.ptIdx }
        : null,
      zoom,
      pan,
      resolvedVecs
    );
  }, [currentFrame, selectedPathIdx, hoverPoint, safeFrameIdx, zoom, pan, resolvedVecs]);

  // ---- Playback ----

  useEffect(() => {
    if (!playing) {
      if (playIntervalRef.current !== null) {
        clearInterval(playIntervalRef.current);
        playIntervalRef.current = null;
      }
      return;
    }
    const tick = () => {
      setSelectedFrameIdx((prev) => {
        const next = prev + 1;
        if (next >= res.frames.length) {
          if (res.loop) return 0;
          setPlaying(false);
          return prev;
        }
        return next;
      });
    };
    const ms = (currentFrame.duration_ticks ?? 4) * 20;
    playIntervalRef.current = setInterval(tick, ms);
    return () => {
      if (playIntervalRef.current !== null) {
        clearInterval(playIntervalRef.current);
        playIntervalRef.current = null;
      }
    };
  }, [playing, currentFrame.duration_ticks, res.frames.length, res.loop]);

  // ---- Mutation helpers ----

  const emit = useCallback(
    (updated: VanimResource) => {
      onChange?.(updated);
    },
    [onChange]
  );

  const updateFrame = useCallback(
    (idx: number, updater: (f: VanimFrame) => VanimFrame) => {
      const next = cloneResource(res);
      next.frames[idx] = updater(next.frames[idx]);
      emit(next);
    },
    [res, emit]
  );

  const handleAddFrame = useCallback(() => {
    const next = cloneResource(res);
    const src = next.frames[safeFrameIdx];
    const newFrame: VanimFrame = {
      index: next.frames.length,
      duration_ticks: src?.duration_ticks ?? 4,
      vec_refs: src ? [...src.vec_refs] : [],
      paths: [],
    };
    next.frames.push(newFrame);
    emit(next);
    setSelectedFrameIdx(newFrame.index);
  }, [res, emit, safeFrameIdx]);

  const handleDeleteFrame = useCallback(
    (idx: number) => {
      if (res.frames.length <= 1) return;
      const next = cloneResource(res);
      next.frames.splice(idx, 1);
      next.frames.forEach((f, i) => {
        f.index = i;
      });
      emit(next);
      setSelectedFrameIdx(Math.min(idx, next.frames.length - 1));
    },
    [res, emit]
  );

  const handleLoopToggle = useCallback(() => {
    const next = cloneResource(res);
    next.loop = !next.loop;
    emit(next);
  }, [res, emit]);

  const handleDurationChange = useCallback(
    (val: number) => {
      updateFrame(safeFrameIdx, (f) => ({ ...f, duration_ticks: val }));
    },
    [updateFrame, safeFrameIdx]
  );

  const handleAddVecRef = useCallback(() => {
    const trimmed = newVecRefText.trim();
    if (!trimmed) return;
    updateFrame(safeFrameIdx, (f) => ({
      ...f,
      vec_refs: [...f.vec_refs, trimmed],
    }));
    setNewVecRefText('');
    setAddingVecRef(false);
  }, [newVecRefText, updateFrame, safeFrameIdx]);

  const handleRemoveVecRef = useCallback(
    (refIdx: number) => {
      updateFrame(safeFrameIdx, (f) => ({
        ...f,
        vec_refs: f.vec_refs.filter((_, i) => i !== refIdx),
      }));
    },
    [updateFrame, safeFrameIdx]
  );

  const handleAddPath = useCallback(() => {
    updateFrame(safeFrameIdx, (f) => ({
      ...f,
      paths: [
        ...f.paths,
        { name: `path${f.paths.length}`, intensity: 127, points: [] },
      ],
    }));
    setSelectedPathIdx((currentFrame.paths.length));
  }, [updateFrame, safeFrameIdx, currentFrame.paths.length]);

  const handleDeletePath = useCallback(
    (pathIdx: number) => {
      updateFrame(safeFrameIdx, (f) => ({
        ...f,
        paths: f.paths.filter((_, i) => i !== pathIdx),
      }));
      setSelectedPathIdx(null);
    },
    [updateFrame, safeFrameIdx]
  );

  const handlePathNameChange = useCallback(
    (pathIdx: number, name: string) => {
      updateFrame(safeFrameIdx, (f) => {
        const paths = f.paths.map((p, i) =>
          i === pathIdx ? { ...p, name } : p
        );
        return { ...f, paths };
      });
    },
    [updateFrame, safeFrameIdx]
  );

  const handlePathIntensityChange = useCallback(
    (pathIdx: number, intensity: number) => {
      updateFrame(safeFrameIdx, (f) => {
        const paths = f.paths.map((p, i) =>
          i === pathIdx ? { ...p, intensity } : p
        );
        return { ...f, paths };
      });
    },
    [updateFrame, safeFrameIdx]
  );

  const handleAddPoint = useCallback(
    (pathIdx: number) => {
      updateFrame(safeFrameIdx, (f) => {
        const paths = f.paths.map((p, i) => {
          if (i !== pathIdx) return p;
          const last = p.points[p.points.length - 1] ?? { x: 0, y: 0 };
          return { ...p, points: [...p.points, { x: last.x + 10, y: last.y }] };
        });
        return { ...f, paths };
      });
    },
    [updateFrame, safeFrameIdx]
  );

  const handleRemovePoint = useCallback(
    (pathIdx: number, ptIdx: number) => {
      updateFrame(safeFrameIdx, (f) => {
        const paths = f.paths.map((p, i) => {
          if (i !== pathIdx) return p;
          return { ...p, points: p.points.filter((_, j) => j !== ptIdx) };
        });
        return { ...f, paths };
      });
    },
    [updateFrame, safeFrameIdx]
  );

  const handlePointChange = useCallback(
    (pathIdx: number, ptIdx: number, axis: 'x' | 'y', val: number) => {
      updateFrame(safeFrameIdx, (f) => {
        const paths = f.paths.map((p, i) => {
          if (i !== pathIdx) return p;
          const points = p.points.map((pt, j) =>
            j === ptIdx ? { ...pt, [axis]: val } : pt
          );
          return { ...p, points };
        });
        return { ...f, paths };
      });
    },
    [updateFrame, safeFrameIdx]
  );

  // ---- Scale path ----

  const handleScalePath = useCallback(
    (pathIdx: number, factor: number) => {
      updateFrame(safeFrameIdx, (f) => {
        const paths = f.paths.map((p, i) => {
          if (i !== pathIdx) return p;
          return {
            ...p,
            points: p.points.map((pt) => ({
              x: Math.round(Math.max(-127, Math.min(127, pt.x * factor))),
              y: Math.round(Math.max(-127, Math.min(127, pt.y * factor))),
            })),
          };
        });
        return { ...f, paths };
      });
    },
    [updateFrame, safeFrameIdx]
  );

  // ---- Wheel zoom ----

  const handleCanvasWheel = useCallback((e: React.WheelEvent<HTMLCanvasElement>) => {
    e.preventDefault();
    setZoom((z) => Math.min(8, Math.max(0.2, z * (e.deltaY < 0 ? 1.15 : 1 / 1.15))));
  }, []);

  // ---- Canvas mouse handlers ----

  const handleCanvasMouseDown = useCallback(
    (e: React.MouseEvent<HTMLCanvasElement>) => {
      const canvas = canvasRef.current;
      if (!canvas) return;

      // Middle mouse: start pan drag
      if (e.button === 1) {
        e.preventDefault();
        setPanDragging({ startX: e.clientX, startY: e.clientY, startPan: pan });
        return;
      }

      if (e.button !== 0) return;

      const rect = canvas.getBoundingClientRect();
      const mx = e.clientX - rect.left;
      const my = e.clientY - rect.top;
      const w = canvas.width;
      const h = canvas.height;

      if (tool === 'select') {
        // Find nearest point within snap radius (scaled by zoom)
        const snapRadius = 12 / zoom;
        let foundPathIdx = -1;
        let foundPtIdx = -1;
        let bestDist = Infinity;

        for (let pi = 0; pi < currentFrame.paths.length; pi++) {
          const path = currentFrame.paths[pi];
          for (let ptI = 0; ptI < path.points.length; ptI++) {
            const pt = path.points[ptI];
            const scale = Math.min(w, h) / 256;
            const px = w / 2 + pt.x * scale * zoom + pan.x;
            const py = h / 2 - pt.y * scale * zoom + pan.y;
            const dist = Math.hypot(px - mx, py - my);
            if (dist < snapRadius * scale * zoom && dist < bestDist) {
              bestDist = dist;
              foundPathIdx = pi;
              foundPtIdx = ptI;
            }
          }
        }

        if (foundPathIdx >= 0) {
          setDragging({ pathIdx: foundPathIdx, ptIdx: foundPtIdx });
          setSelectedPathIdx(foundPathIdx);
        } else {
          setSelectedPathIdx(null);
        }
      } else if (tool === 'pen') {
        const worldPos = canvasToWorld(mx, my, w, h, zoom, pan);

        if (selectedPathIdx !== null) {
          // Add point to selected path
          updateFrame(safeFrameIdx, (f) => {
            const paths = f.paths.map((p, i) => {
              if (i !== selectedPathIdx) return p;
              return { ...p, points: [...p.points, worldPos] };
            });
            return { ...f, paths };
          });
        } else {
          // Create new path with this point
          const newPathIdx = currentFrame.paths.length;
          updateFrame(safeFrameIdx, (f) => ({
            ...f,
            paths: [
              ...f.paths,
              {
                name: `path${f.paths.length}`,
                intensity: 127,
                points: [worldPos],
              },
            ],
          }));
          setSelectedPathIdx(newPathIdx);
        }
      }
    },
    [tool, currentFrame.paths, zoom, pan, selectedPathIdx, updateFrame, safeFrameIdx]
  );

  const handleCanvasMouseMove = useCallback(
    (e: React.MouseEvent<HTMLCanvasElement>) => {
      const canvas = canvasRef.current;
      if (!canvas) return;
      const rect = canvas.getBoundingClientRect();
      const mx = e.clientX - rect.left;
      const my = e.clientY - rect.top;
      const w = canvas.width;
      const h = canvas.height;
      const scale = Math.min(w, h) / 256;

      // Pan dragging
      if (panDragging) {
        setPan({
          x: panDragging.startPan.x + (e.clientX - panDragging.startX),
          y: panDragging.startPan.y + (e.clientY - panDragging.startY),
        });
      }

      // Point dragging (select tool)
      if (dragging && tool === 'select') {
        const worldPos = canvasToWorld(mx, my, w, h, zoom, pan);
        updateFrame(safeFrameIdx, (f) => {
          const paths = f.paths.map((p, i) => {
            if (i !== dragging.pathIdx) return p;
            const points = p.points.map((pt, j) =>
              j === dragging.ptIdx ? worldPos : pt
            );
            return { ...p, points };
          });
          return { ...f, paths };
        });
        setHoverPoint({
          pathIdx: dragging.pathIdx,
          ptIdx: dragging.ptIdx,
          x: worldPos.x,
          y: worldPos.y,
          wx: e.clientX,
          wy: e.clientY,
        });
        return;
      }

      // Hover detection
      const snapRadius = 8;
      let found: typeof hoverPoint = null;
      for (let pi = 0; pi < currentFrame.paths.length; pi++) {
        const path = currentFrame.paths[pi];
        for (let ptI = 0; ptI < path.points.length; ptI++) {
          const pt = path.points[ptI];
          const px = w / 2 + pt.x * scale * zoom + pan.x;
          const py = h / 2 - pt.y * scale * zoom + pan.y;
          if (Math.hypot(px - mx, py - my) < snapRadius) {
            found = {
              pathIdx: pi,
              ptIdx: ptI,
              x: pt.x,
              y: pt.y,
              wx: e.clientX,
              wy: e.clientY,
            };
            break;
          }
        }
        if (found) break;
      }
      setHoverPoint(found);
    },
    [currentFrame.paths, zoom, pan, dragging, panDragging, tool, updateFrame, safeFrameIdx]
  );

  const handleCanvasMouseUp = useCallback(() => {
    setDragging(null);
    setPanDragging(null);
  }, []);

  const handleCanvasMouseLeave = useCallback(() => {
    setDragging(null);
    setPanDragging(null);
    setHoverPoint(null);
  }, []);

  // ---- Canvas cursor ----

  const canvasCursor = useMemo((): string => {
    if (panDragging) return 'grabbing';
    if (tool === 'pen') return 'crosshair';
    if (dragging) return 'grabbing';
    return 'default';
  }, [tool, dragging, panDragging]);

  // ---- Navigation ----

  const goPrev = useCallback(() => {
    setSelectedFrameIdx((i) => Math.max(0, i - 1));
  }, []);

  const goNext = useCallback(() => {
    setSelectedFrameIdx((i) => Math.min(res.frames.length - 1, i + 1));
  }, [res.frames.length]);

  const togglePlay = useCallback(() => {
    setPlaying((p) => !p);
  }, []);

  const handleResetView = useCallback(() => {
    setZoom(1.0);
    setPan({ x: 0, y: 0 });
  }, []);

  // ---- Computed ----

  const totalFrames = res.frames.length;

  // ---- Resize observer to redraw on container size change ----

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;
    const observer = new ResizeObserver(() => {
      const canvas = canvasRef.current;
      if (!canvas) return;
      const w = container.clientWidth;
      const h = container.clientHeight;
      canvas.width = w;
      canvas.height = h;
      const ctx = canvas.getContext('2d');
      if (!ctx) return;
      drawFrame(
        ctx,
        w,
        h,
        currentFrame,
        selectedPathIdx,
        hoverPoint
          ? { pathIdx: hoverPoint.pathIdx, ptIdx: hoverPoint.ptIdx }
          : null,
        zoom,
        pan,
        resolvedVecs
      );
    });
    observer.observe(container);
    return () => observer.disconnect();
  }, [currentFrame, selectedPathIdx, hoverPoint, zoom, pan, resolvedVecs]);

  // ---- Inline path list (memoized) ----

  const pathListItems = useMemo(
    () =>
      currentFrame.paths.map((path, pathIdx) => (
        <div
          key={pathIdx}
          style={{
            marginBottom: 8,
            border:
              selectedPathIdx === pathIdx
                ? '1px solid #6666cc'
                : '1px solid #2a2a4a',
            borderRadius: 4,
            padding: 6,
            background: selectedPathIdx === pathIdx ? '#1e1e3e' : '#16162e',
            cursor: 'pointer',
          }}
          onClick={() =>
            setSelectedPathIdx(selectedPathIdx === pathIdx ? null : pathIdx)
          }
        >
          {/* Path header */}
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 4,
              marginBottom: 4,
            }}
          >
            <input
              value={path.name}
              onChange={(e) => handlePathNameChange(pathIdx, e.target.value)}
              onClick={(e) => e.stopPropagation()}
              style={inputStyle}
              placeholder="path name"
            />
            <button
              onClick={(e) => {
                e.stopPropagation();
                handleDeletePath(pathIdx);
              }}
              style={smallDeleteBtnStyle}
              title="Delete path"
            >
              x
            </button>
          </div>

          {/* Intensity */}
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 6,
              marginBottom: 4,
            }}
          >
            <label style={labelStyle}>Intensity</label>
            <input
              type="range"
              min={0}
              max={127}
              value={path.intensity}
              onChange={(e) =>
                handlePathIntensityChange(pathIdx, parseInt(e.target.value))
              }
              onClick={(e) => e.stopPropagation()}
              style={{ flex: 1 }}
            />
            <span style={{ color: '#aaa', fontSize: 11, minWidth: 24 }}>
              {path.intensity}
            </span>
          </div>

          {/* Scale buttons */}
          <div
            style={{
              display: 'flex',
              gap: 4,
              marginBottom: 4,
            }}
          >
            <button
              onClick={(e) => {
                e.stopPropagation();
                handleScalePath(pathIdx, 2);
              }}
              style={smallAddBtnStyle}
              title="Scale all points by 2x (clamped to ±127)"
            >
              Scale 2x
            </button>
            <button
              onClick={(e) => {
                e.stopPropagation();
                handleScalePath(pathIdx, 0.5);
              }}
              style={smallAddBtnStyle}
              title="Scale all points by 0.5x"
            >
              Scale 1/2
            </button>
          </div>

          {/* Points table */}
          {path.points.length > 0 && (
            <table style={{ width: '100%', borderCollapse: 'collapse', marginBottom: 4 }}>
              <thead>
                <tr>
                  <th style={thStyle}>#</th>
                  <th style={thStyle}>X</th>
                  <th style={thStyle}>Y</th>
                  <th style={thStyle}></th>
                </tr>
              </thead>
              <tbody>
                {path.points.map((pt, ptIdx) => (
                  <tr key={ptIdx}>
                    <td style={tdStyle}>{ptIdx}</td>
                    <td style={tdStyle}>
                      <input
                        type="number"
                        value={pt.x}
                        onChange={(e) =>
                          handlePointChange(
                            pathIdx,
                            ptIdx,
                            'x',
                            parseInt(e.target.value) || 0
                          )
                        }
                        onClick={(e) => e.stopPropagation()}
                        style={{ ...numInputStyle, width: 46 }}
                      />
                    </td>
                    <td style={tdStyle}>
                      <input
                        type="number"
                        value={pt.y}
                        onChange={(e) =>
                          handlePointChange(
                            pathIdx,
                            ptIdx,
                            'y',
                            parseInt(e.target.value) || 0
                          )
                        }
                        onClick={(e) => e.stopPropagation()}
                        style={{ ...numInputStyle, width: 46 }}
                      />
                    </td>
                    <td style={tdStyle}>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          handleRemovePoint(pathIdx, ptIdx);
                        }}
                        style={smallDeleteBtnStyle}
                        title="Remove point"
                      >
                        x
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}

          <button
            onClick={(e) => {
              e.stopPropagation();
              handleAddPoint(pathIdx);
            }}
            style={smallAddBtnStyle}
          >
            + Point
          </button>
        </div>
      )),
    [
      currentFrame.paths,
      selectedPathIdx,
      handlePathNameChange,
      handleDeletePath,
      handlePathIntensityChange,
      handleScalePath,
      handlePointChange,
      handleRemovePoint,
      handleAddPoint,
    ]
  );

  // ============================================
  // Render
  // ============================================

  return (
    <div style={rootStyle}>
      {/* Toolbar */}
      <div style={toolbarStyle}>
        <label style={{ display: 'flex', alignItems: 'center', gap: 4, color: '#aaa', fontSize: 12 }}>
          <input
            type="checkbox"
            checked={res.loop}
            onChange={handleLoopToggle}
          />
          Loop
        </label>

        <div style={{ width: 1, background: '#333', alignSelf: 'stretch' }} />

        <button onClick={goPrev} style={toolBtnStyle} title="Previous frame" disabled={playing}>
          {'<'}
        </button>
        <button onClick={goNext} style={toolBtnStyle} title="Next frame" disabled={playing}>
          {'>'}
        </button>
        <button onClick={togglePlay} style={{ ...toolBtnStyle, minWidth: 60 }}>
          {playing ? 'Pause' : 'Play'}
        </button>

        <span style={{ color: '#aaa', fontSize: 12 }}>
          Frame {safeFrameIdx + 1} / {totalFrames}
        </span>

        <div style={{ width: 1, background: '#333', alignSelf: 'stretch' }} />

        {/* Tool buttons */}
        <button
          onClick={() => setTool('select')}
          style={{
            ...toolBtnStyle,
            border: tool === 'select' ? '1px solid #8888ff' : '1px solid #3a3a6a',
            color: tool === 'select' ? '#ccccff' : '#ccc',
          }}
          title="Select / drag points"
        >
          Select
        </button>
        <button
          onClick={() => setTool('pen')}
          style={{
            ...toolBtnStyle,
            border: tool === 'pen' ? '1px solid #8888ff' : '1px solid #3a3a6a',
            color: tool === 'pen' ? '#ccccff' : '#ccc',
          }}
          title="Pen: click canvas to add points"
        >
          Pen
        </button>

        <div style={{ width: 1, background: '#333', alignSelf: 'stretch' }} />

        {/* Reset view */}
        <button
          onClick={handleResetView}
          style={toolBtnStyle}
          title="Reset zoom and pan to default"
        >
          Reset View
        </button>

        <span style={{ color: '#666', fontSize: 11 }}>
          {Math.round(zoom * 100)}%
        </span>

        <div style={{ flex: 1 }} />

        <button onClick={handleAddFrame} style={addBtnStyle}>
          + Add Frame
        </button>
      </div>

      {/* Main body */}
      <div style={bodyStyle}>
        {/* Left: Frame list */}
        <div style={frameListStyle}>
          <div style={{ fontSize: 11, color: '#666', marginBottom: 6, textTransform: 'uppercase', letterSpacing: 1 }}>
            Frames
          </div>
          {res.frames.map((frame, idx) => (
            <FrameCard
              key={idx}
              frame={frame}
              selected={idx === safeFrameIdx}
              onClick={() => setSelectedFrameIdx(idx)}
              onDelete={() => handleDeleteFrame(idx)}
            />
          ))}
          <button onClick={handleAddFrame} style={{ ...addBtnStyle, width: '100%', marginTop: 4 }}>
            + Add Frame
          </button>
        </div>

        {/* Center: Canvas */}
        <div
          ref={containerRef}
          style={canvasContainerStyle}
        >
          <canvas
            ref={canvasRef}
            style={{ display: 'block', width: '100%', height: '100%', cursor: canvasCursor }}
            onMouseMove={handleCanvasMouseMove}
            onMouseLeave={handleCanvasMouseLeave}
            onMouseDown={handleCanvasMouseDown}
            onMouseUp={handleCanvasMouseUp}
            onWheel={handleCanvasWheel}
          />
          {hoverPoint && (
            <div
              style={{
                position: 'fixed',
                left: hoverPoint.wx + 12,
                top: hoverPoint.wy - 8,
                background: '#222244',
                color: '#eee',
                padding: '3px 7px',
                borderRadius: 4,
                fontSize: 11,
                pointerEvents: 'none',
                zIndex: 9999,
                border: '1px solid #4444aa',
              }}
            >
              ({hoverPoint.x}, {hoverPoint.y})
            </div>
          )}
        </div>

        {/* Right: Frame props */}
        <div style={propsStyle}>
          <div style={propsSectionTitle}>Frame Properties</div>

          {/* Duration */}
          <div style={{ marginBottom: 12 }}>
            <label style={labelStyle}>Ticks per frame</label>
            <input
              type="number"
              min={1}
              max={50}
              value={currentFrame.duration_ticks}
              onChange={(e) =>
                handleDurationChange(Math.max(1, Math.min(50, parseInt(e.target.value) || 1)))
              }
              style={{ ...numInputStyle, width: '100%' }}
            />
          </div>

          {/* Vec refs */}
          <div style={{ marginBottom: 12 }}>
            <div style={propsSectionTitle}>Vec Refs</div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4, marginBottom: 6 }}>
              {currentFrame.vec_refs.map((ref, ri) => (
                <span key={ri} style={tagStyle}>
                  {ref}
                  <button
                    onClick={() => handleRemoveVecRef(ri)}
                    style={{
                      background: 'transparent',
                      border: 'none',
                      color: '#884444',
                      cursor: 'pointer',
                      padding: '0 0 0 4px',
                      fontSize: 11,
                    }}
                  >
                    x
                  </button>
                </span>
              ))}
            </div>
            {addingVecRef ? (
              <div style={{ display: 'flex', gap: 4 }}>
                <input
                  autoFocus
                  value={newVecRefText}
                  onChange={(e) => setNewVecRefText(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') handleAddVecRef();
                    if (e.key === 'Escape') {
                      setAddingVecRef(false);
                      setNewVecRefText('');
                    }
                  }}
                  placeholder="e.g. mario"
                  style={{ ...inputStyle, flex: 1 }}
                />
                <button onClick={handleAddVecRef} style={smallAddBtnStyle}>
                  OK
                </button>
                <button
                  onClick={() => {
                    setAddingVecRef(false);
                    setNewVecRefText('');
                  }}
                  style={smallDeleteBtnStyle}
                >
                  x
                </button>
              </div>
            ) : (
              <button
                onClick={() => setAddingVecRef(true)}
                style={smallAddBtnStyle}
              >
                + Add vec ref
              </button>
            )}
          </div>

          {/* Inline paths */}
          <div>
            <div style={propsSectionTitle}>Paths</div>
            <div style={{ overflowY: 'auto', flex: 1 }}>
              {pathListItems}
            </div>
            <button onClick={handleAddPath} style={{ ...addBtnStyle, width: '100%', marginTop: 4 }}>
              + Add Path
            </button>
          </div>
        </div>
      </div>

      {/* Timeline */}
      <div style={timelineStyle}>
        <div style={timelineInnerStyle}>
          {res.frames.map((frame, idx) => (
            <TimelineCell
              key={idx}
              frame={frame}
              selected={idx === safeFrameIdx}
              isPlayhead={playing && idx === safeFrameIdx}
              onClick={() => {
                setSelectedFrameIdx(idx);
              }}
            />
          ))}
        </div>
      </div>
    </div>
  );
};

// ============================================
// Styles
// ============================================

const rootStyle: React.CSSProperties = {
  display: 'flex',
  flexDirection: 'column',
  height: '100%',
  width: '100%',
  background: '#13132a',
  color: '#ccc',
  fontFamily: 'system-ui, sans-serif',
  overflow: 'hidden',
};

const toolbarStyle: React.CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 8,
  padding: '6px 12px',
  background: '#1a1a3a',
  borderBottom: '1px solid #2a2a4a',
  flexShrink: 0,
};

const bodyStyle: React.CSSProperties = {
  display: 'flex',
  flex: 1,
  overflow: 'hidden',
  minHeight: 0,
};

const frameListStyle: React.CSSProperties = {
  width: 140,
  flexShrink: 0,
  background: '#16162e',
  borderRight: '1px solid #2a2a4a',
  padding: 8,
  overflowY: 'auto',
  display: 'flex',
  flexDirection: 'column',
};

const canvasContainerStyle: React.CSSProperties = {
  flex: 1,
  position: 'relative',
  overflow: 'hidden',
  background: '#1a1a2e',
};

const propsStyle: React.CSSProperties = {
  width: 220,
  flexShrink: 0,
  background: '#16162e',
  borderLeft: '1px solid #2a2a4a',
  padding: 10,
  overflowY: 'auto',
  display: 'flex',
  flexDirection: 'column',
};

const timelineStyle: React.CSSProperties = {
  height: 60,
  flexShrink: 0,
  background: '#12122a',
  borderTop: '1px solid #2a2a4a',
  overflowX: 'auto',
  overflowY: 'hidden',
  display: 'flex',
  alignItems: 'center',
  padding: '0 8px',
};

const timelineInnerStyle: React.CSSProperties = {
  display: 'flex',
  flexDirection: 'row',
  alignItems: 'center',
};

const toolBtnStyle: React.CSSProperties = {
  background: '#2a2a4a',
  border: '1px solid #3a3a6a',
  color: '#ccc',
  padding: '3px 10px',
  borderRadius: 4,
  cursor: 'pointer',
  fontSize: 12,
};

const addBtnStyle: React.CSSProperties = {
  background: '#2a3a5a',
  border: '1px solid #3a5a8a',
  color: '#88bbff',
  padding: '3px 10px',
  borderRadius: 4,
  cursor: 'pointer',
  fontSize: 12,
};

const smallAddBtnStyle: React.CSSProperties = {
  background: '#1e2e4e',
  border: '1px solid #2a4a7a',
  color: '#88aaff',
  padding: '2px 6px',
  borderRadius: 3,
  cursor: 'pointer',
  fontSize: 11,
};

const smallDeleteBtnStyle: React.CSSProperties = {
  background: 'transparent',
  border: '1px solid #442222',
  color: '#aa5555',
  padding: '2px 5px',
  borderRadius: 3,
  cursor: 'pointer',
  fontSize: 11,
};

const propsSectionTitle: React.CSSProperties = {
  fontSize: 10,
  color: '#666',
  textTransform: 'uppercase',
  letterSpacing: 1,
  marginBottom: 6,
};

const labelStyle: React.CSSProperties = {
  display: 'block',
  fontSize: 11,
  color: '#888',
  marginBottom: 3,
};

const inputStyle: React.CSSProperties = {
  background: '#1a1a3a',
  border: '1px solid #2a2a5a',
  color: '#ccc',
  padding: '3px 6px',
  borderRadius: 3,
  fontSize: 12,
};

const numInputStyle: React.CSSProperties = {
  background: '#1a1a3a',
  border: '1px solid #2a2a5a',
  color: '#ccc',
  padding: '2px 4px',
  borderRadius: 3,
  fontSize: 12,
};

const tagStyle: React.CSSProperties = {
  display: 'inline-flex',
  alignItems: 'center',
  background: '#1a2a4a',
  border: '1px solid #2a4a7a',
  color: '#88aaff',
  padding: '2px 6px',
  borderRadius: 10,
  fontSize: 11,
};

const thStyle: React.CSSProperties = {
  fontSize: 10,
  color: '#555',
  textAlign: 'left',
  padding: '2px 2px',
  fontWeight: 'normal',
};

const tdStyle: React.CSSProperties = {
  padding: '2px 2px',
  fontSize: 11,
};
