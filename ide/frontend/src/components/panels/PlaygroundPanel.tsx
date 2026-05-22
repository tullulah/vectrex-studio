import React, { useState, useEffect, useRef } from 'react';
import { useTranslation } from 'react-i18next';
import { useProjectStore } from '../../state/projectStore';
import { VPlayLevel, VPlayObject, VPlayValidator, VPlayHotspot, HotspotTrigger, VPlayScrollLimits, DEFAULT_LEVEL, VPLAY_VERSION } from '../../types/vplay-schema';

interface VecPath {
  name: string;
  points: { x: number; y: number }[];
  intensity: number;
  closed: boolean;
}

interface VecVector {
  version: string;
  name: string;
  canvas: { width: number; height: number; origin: string };
  layers: {
    name: string;
    visible: boolean;
    paths: VecPath[];
  }[];
  /** Reusable walkable areas baked into the asset. Coordinates are relative
   *  to the vec's origin and are translated by the placed object's (x, y)
   *  at level codegen / sim time. Inheritance: .vec → .vplay → .venemy. */
  walkableAreas?: { y: number; x_min: number; x_max: number }[];
}

interface CollisionSegment {
  x1: number; y1: number; x2: number; y2: number;
}

interface SceneObject {
  id: string;
  type: 'background' | 'enemy' | 'player' | 'projectile';
  vectorName: string;
  layer?: 'background' | 'gameplay' | 'foreground';
  x: number;
  y: number;
  rotation: number;
  scale: number;
  velocity?: { x: number; y: number };
  physicsEnabled?: boolean;
  collidable?: boolean;
  collision?: { enabled?: boolean; segments?: CollisionSegment[]; width?: number; height?: number };
  gravity?: number;
  bounceDamping?: number;
  physicsType?: 'gravity' | 'bounce' | 'projectile' | 'static';
  radius?: number;
  // Enemy-specific
  enemyType?: string;
  aiType?: 'static' | 'patrol' | 'wander' | 'chase' | 'flee';
  patrolWaypoints?: { x: number; y: number }[];
  /** Phase 2: explicit walkable areas. If absent, a single area is derived
   *  from patrolWaypoints' X-range at spawn Y. */
  walkable_areas?: { y: number; x_min: number; x_max: number }[];
  /** Phase 2: optional transitions between walkable areas (by index). */
  transitions?: { from: number; to: number; type: 'jump_up' | 'drop' }[];
  wave?: number;
  respawn?: boolean;
  speed?: number;  // patrol speed in Vectrex units/frame (default 1.0)
  mirrorOnPatrol?: boolean;
  defaultFacing?: 'left' | 'right';
  _facingRight?: boolean;  // transient — not saved
}

export function PlaygroundPanel() {
  const { t } = useTranslation();
  const { vpyProject } = useProjectStore();
  const canvasRef = useRef<SVGSVGElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const isPanningRef = useRef(false);
  const panStartRef = useRef({ x: 0, y: 0, scrollLeft: 0, scrollTop: 0 });
  const [isPanning, setIsPanning] = useState(false);
  const [objects, setObjects] = useState<SceneObject[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [availableVectors, setAvailableVectors] = useState<string[]>([]);
  const [loadedVectors, setLoadedVectors] = useState<Map<string, VecVector>>(new Map());
  const [draggedVector, setDraggedVector] = useState<string | null>(null);
  const [draggingObjectId, setDraggingObjectId] = useState<string | null>(null);
  const [dragOffset, setDragOffset] = useState<{ x: number; y: number } | null>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [savedScene, setSavedScene] = useState<SceneObject[] | null>(null);
  const [editingVelocity, setEditingVelocity] = useState(false);
  const animationFrameRef = useRef<number | null>(null);
  const enemyPatrolIdxRef = useRef<Map<string, number>>(new Map());
  // Wander AI sub-state: 'walk' / 'idle' / 'to_takeoff' / 'air' + current area, direction, transition target.
  type WanderState = {
    sub: 'walk' | 'idle' | 'to_takeoff' | 'air';
    timer: number;
    areaIdx?: number;
    dir?: 1 | -1;
    fromX?: number;
    targetY?: number;
    targetX?: number;
    targetAreaIdx?: number;
    /** Arc velocity (positive = up) — set when entering AIRBORNE per transition type. */
    vy?: number;
    /** Cached transition type so AIRBORNE knows the arc shape. */
    transType?: 'jump_up' | 'drop' | 'jump_across';
  };
  const enemyWanderStateRef = useRef<Map<string, WanderState>>(new Map());
  const [showSaveLoadModal, setShowSaveLoadModal] = useState(false);
  const [modalMode, setModalMode] = useState<'save' | 'load'>('save');
  const [sceneName, setSceneName] = useState('');
  const [availableScenes, setAvailableScenes] = useState<string[]>([]);
  const [draggingVelocity, setDraggingVelocity] = useState(false);
  const [velocityMagnitude, setVelocityMagnitude] = useState(10);
  const [velocityAngle, setVelocityAngle] = useState(-90); // -90 = up
  const [toasts, setToasts] = useState<Array<{id: number; message: string; type: 'success' | 'error'}>>([]);
  const [hotspots, setHotspots] = useState<VPlayHotspot[]>([]);
  const [selectedHotspotId, setSelectedHotspotId] = useState<string | null>(null);
  const [activeTool, setActiveTool] = useState<'select' | 'hotspot' | 'enemy' | 'patrol'>('select');
  const [availableEnemies, setAvailableEnemies] = useState<string[]>([]);
  const [selectedEnemyType, setSelectedEnemyType] = useState<string>('');
  const [enemyTypeVectorMap, setEnemyTypeVectorMap] = useState<Map<string, string>>(new Map());
  const [draggingHotspotId, setDraggingHotspotId] = useState<string | null>(null);
  const [hotspotDragOffset, setHotspotDragOffset] = useState<{ x: number; y: number } | null>(null);
  const [widthScreens, setWidthScreens] = useState(1);
  const [heightScreens, setHeightScreens] = useState(1);
  const [groundBottomOffset, setGroundBottomOffset] = useState(42); // units from bottom edge of screen upward (42 = 128-86 for SnowBros)
  const [scrollLimits, setScrollLimits] = useState<VPlayScrollLimits>({});
  const [draggingLimit, setDraggingLimit] = useState<'left' | 'right' | 'top' | 'bottom' | null>(null);
  const [selectedLimit, setSelectedLimit] = useState<'left' | 'right' | 'top' | 'bottom' | null>(null);
  const [draggingWaypointInfo, setDraggingWaypointInfo] = useState<{ enemyId: string; wpIdx: number } | null>(null);
  // Phase 2: dragging a transition endpoint (from_x or to_x) constrains motion
  // to the X-axis within the corresponding area's range.
  const [draggingTransitionEndpoint, setDraggingTransitionEndpoint] = useState<
    { enemyId: string; transIdx: number; endpoint: 'from' | 'to' } | null
  >(null);
  // Same as draggingTransitionEndpoint but for the standalone level-wide
  // transitions overlay (no enemy owner).
  const [draggingLevelTransitionEndpoint, setDraggingLevelTransitionEndpoint] = useState<
    { transIdx: number; endpoint: 'from' | 'to' } | null
  >(null);
  const [screenBackgrounds, setScreenBackgrounds] = useState<{ screenIndex: number; imagePath: string; offsetY?: number }[]>([]);
  const [availableImages, setAvailableImages] = useState<string[]>([]);
  // Level-wide walkable areas + transitions. Enemies whose own `walkable_areas`
  // is `undefined` inherit these at codegen time (and at preview time via the
  // JS sim). An enemy that defines its own (even an empty list) overrides.
  type LevelArea = { y: number; x_min: number; x_max: number };
  type LevelTransition = { from: number; to: number; type: 'jump_up' | 'drop'; from_x?: number; to_x?: number };
  const [levelWalkableAreas, setLevelWalkableAreas] = useState<LevelArea[]>([]);
  const [levelTransitions, setLevelTransitions] = useState<LevelTransition[]>([]);
  /** When true, derive_transitions never crosses a screen boundary (256u Y
   *  band aligned to worldYMax). For per-screen games like SnowBros where
   *  each "floor" is its own level — wander enemies shouldn't auto-jump
   *  between floors. */
  const [isolateScreens, setIsolateScreens] = useState<boolean>(false);
  /** Auto-transition tuning (mirror of levelres.rs constants). */
  const [transMinXOverlap, setTransMinXOverlap] = useState<number>(4);
  const [transLateralY, setTransLateralY]       = useState<number>(8);
  const [transLateralGap, setTransLateralGap]   = useState<number>(60);
  /** Collect walkable areas from every placed .vec asset's own `walkableAreas`,
   *  translated by the object's (x, y). Used as the next fallback below the
   *  level's own `walkable_areas` and below per-enemy overrides. */
  /** Per-enemy-type feet offset = 5 - min_y across every loaded .vec whose
   *  name matches the enemy type. Mirrors compute_enemy_feet_offset() in
   *  pitrex/assets.rs so the playground preview matches the runtime. */
  const getEnemyFeetOffset = (
    enemyType: string | undefined,
    vecs: Map<string, VecVector>,
  ): number => {
    if (!enemyType) return 0;
    const plain = enemyType.toLowerCase();
    const prefix = plain + '_';
    let minY: number | null = null;
    vecs.forEach((v, name) => {
      if (name !== plain && !name.startsWith(prefix)) return;
      for (const layer of v.layers) {
        for (const p of layer.paths) {
          for (const pt of p.points) {
            if (minY === null || pt.y < minY) minY = pt.y;
          }
        }
      }
    });
    return minY === null ? 0 : 5 - minY;
  };

  const collectVecWalkableAreas = (
    objs: SceneObject[],
    vecs: Map<string, VecVector>,
  ): LevelArea[] => {
    return collectVecWalkableAreasWithSources(objs, vecs).areas;
  };
  /** Same but also returns per-area source object index (used by
   *  deriveTransitions to skip jump_up/drop between parallel shelves
   *  of the same .vec). */
  const collectVecWalkableAreasWithSources = (
    objs: SceneObject[],
    vecs: Map<string, VecVector>,
  ): { areas: LevelArea[]; sources: number[] } => {
    const areas: LevelArea[] = [];
    const sources: number[] = [];
    objs.forEach((o, idx) => {
      if (o.layer === 'foreground') return;
      const v = vecs.get(o.vectorName);
      if (!v?.walkableAreas?.length) return;
      for (const a of v.walkableAreas) {
        areas.push({ y: a.y + o.y, x_min: a.x_min + o.x, x_max: a.x_max + o.x });
        sources.push(idx);
      }
    });
    return { areas, sources };
  };
  /**
   * Mirror of levelres.rs::derive_transitions — for each area in `areas`,
   * emit transitions to its immediate vertical neighbors (X-overlap ≥ 4)
   * as jump_up/drop, and to its immediate lateral neighbors (similar Y,
   * X-gap ≤ 60) as jump_across. Used everywhere we need the effective
   * transitions list when no explicit override exists.
   */
  const deriveTransitions = (areas: LevelArea[], sources?: number[]): LevelTransition[] => {
    const MIN_X_OVERLAP = Math.max(0, transMinXOverlap);
    const LATERAL_Y     = Math.max(0, transLateralY);
    const LATERAL_GAP   = Math.max(0, transLateralGap);
    const sameSource = (i: number, j: number) =>
      sources !== undefined && sources[i] !== undefined && sources[i] === sources[j];
    const out: LevelTransition[] = [];
    const n = areas.length;
    const overlap = (a: LevelArea, b: LevelArea) =>
      Math.max(0, Math.min(a.x_max, b.x_max) - Math.max(a.x_min, b.x_min));
    const overlapMid = (a: LevelArea, b: LevelArea) =>
      Math.round((Math.max(a.x_min, b.x_min) + Math.min(a.x_max, b.x_max)) / 2);
    // Screen partition aligned to worldYMax; floor used to detect cross-
    // screen pairs that the isolateScreens flag wants to suppress.
    const screenOf = (y: number) => Math.floor((worldYMax - y) / 256);
    const sameScreen = (a: LevelArea, b: LevelArea) =>
      !isolateScreens || screenOf(a.y) === screenOf(b.y);
    for (let i = 0; i < n; i++) {
      // Immediate upper neighbor (X-overlap).
      let upper: number | null = null;
      for (let j = 0; j < n; j++) {
        if (j === i) continue;
        if (areas[j].y <= areas[i].y) continue;
        if (!sameScreen(areas[i], areas[j])) continue;
        if (sameSource(i, j)) continue;
        if (overlap(areas[i], areas[j]) < MIN_X_OVERLAP) continue;
        if (upper === null || areas[j].y < areas[upper].y) upper = j;
      }
      if (upper !== null) {
        const mid = overlapMid(areas[i], areas[upper]);
        out.push({ from: i, to: upper,  type: 'jump_up', from_x: mid, to_x: mid });
        out.push({ from: upper, to: i,  type: 'drop',    from_x: mid, to_x: mid });
      }
      // Closest lateral on each side (similar Y, no X-overlap, gap ≤ LATERAL_GAP).
      let left: number | null = null;
      let right: number | null = null;
      for (let j = 0; j < n; j++) {
        if (j === i) continue;
        if (!sameScreen(areas[i], areas[j])) continue;
        if (Math.abs(areas[i].y - areas[j].y) > LATERAL_Y) continue;
        if (overlap(areas[i], areas[j]) > 0) continue;
        if (areas[j].x_max < areas[i].x_min) {
          if (areas[i].x_min - areas[j].x_max > LATERAL_GAP) continue;
          if (left === null || (areas[i].x_min - areas[j].x_max) < (areas[i].x_min - areas[left].x_max)) left = j;
        } else if (areas[j].x_min > areas[i].x_max) {
          if (areas[j].x_min - areas[i].x_max > LATERAL_GAP) continue;
          if (right === null || (areas[j].x_min - areas[i].x_max) < (areas[right].x_min - areas[i].x_max)) right = j;
        }
      }
      if (left !== null && i < left) {
        out.push({ from: i, to: left, type: 'jump_across' as any, from_x: areas[i].x_min, to_x: areas[left].x_max });
        out.push({ from: left, to: i, type: 'jump_across' as any, from_x: areas[left].x_max, to_x: areas[i].x_min });
      }
      if (right !== null && i < right) {
        out.push({ from: i, to: right, type: 'jump_across' as any, from_x: areas[i].x_max, to_x: areas[right].x_min });
        out.push({ from: right, to: i, type: 'jump_across' as any, from_x: areas[right].x_min, to_x: areas[i].x_max });
      }
    }
    return out;
  };
  // While set, the next canvas click+drag rewrites this level area's geometry
  // (y from the click row, x_min/x_max from the drag X range).
  const [drawingLevelAreaIdx, setDrawingLevelAreaIdx] = useState<number | null>(null);
  const [drawingPreview, setDrawingPreview] = useState<
    { y: number; x_min: number; x_max: number } | null
  >(null);
  const drawingStartXRef = useRef<number | null>(null);

  // ESC cancels walkable-area draw mode without committing.
  useEffect(() => {
    if (drawingLevelAreaIdx === null) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setDrawingLevelAreaIdx(null);
        setDrawingPreview(null);
        drawingStartXRef.current = null;
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [drawingLevelAreaIdx]);
  const [imageDataUrls, setImageDataUrls] = useState<Map<string, string>>(new Map());
  const pendingScrollRef = useRef<{ top: number; left: number } | null>(null);

  // Multi-selection
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [rubberBand, setRubberBand] = useState<{ svgX1: number; svgY1: number; svgX2: number; svgY2: number } | null>(null);
  const dragStartVecRef = useRef<{ x: number; y: number } | null>(null);
  const dragInitialPositionsRef = useRef<Map<string, { x: number; y: number }>>(new Map());
  const rubberBandStartRef = useRef<{ svgX: number; svgY: number } | null>(null);
  const suppressNextClickRef = useRef(false);

  // Toast helper
  const showToast = (message: string, type: 'success' | 'error' = 'success') => {
    const id = Date.now();
    setToasts(prev => [...prev, { id, message, type }]);
    setTimeout(() => {
      setToasts(prev => prev.filter(t => t.id !== id));
    }, 3000);
  };

  // Vectrex coordinate system: 3:4 aspect ratio (192x256)
  const VECTREX_WIDTH = 192;
  const VECTREX_HEIGHT = 256;
  const VECTREX_X_MIN = -96;
  const VECTREX_X_MAX = 95;
  const VECTREX_Y_MIN = -128;
  const VECTREX_Y_MAX = 127;

  // World bounds derived from screen count
  const SVG_SCALE = 3; // pixels per Vectrex unit
  const worldXMin = VECTREX_X_MIN;
  const worldXMax = VECTREX_X_MIN + 192 * widthScreens - 1;
  const worldYMax = VECTREX_Y_MAX;
  const worldYMin = VECTREX_Y_MAX - 256 * heightScreens + 1;

  // Load available vectors from project config
  useEffect(() => {
    const loadVectors = async () => {
      if (!vpyProject) {
        console.log('[Playground] No project loaded');
        return;
      }

      try {
        const filesAPI = (window as any).files;
        if (!filesAPI) {
          console.error('[Playground] No files API available');
          return;
        }

        // Get vectors from project config
        const vectorResources = vpyProject.config.resources?.vectors;
        console.log('[Playground] Vector resources:', vectorResources);
        
        if (!vectorResources || vectorResources.length === 0) {
          console.log('[Playground] No vectors in project');
          return;
        }

        const projectPath = vpyProject.rootDir;

        // Expand glob patterns
        const vecFiles: string[] = [];
        const vecPaths = new Map<string, string>();
        
        for (const pattern of vectorResources) {
          if (pattern.includes('*')) {
            // Find the deepest non-glob directory segment
            const parts = pattern.split('/');
            const firstGlobIdx = parts.findIndex(p => p.includes('*'));
            const dirPath = firstGlobIdx > 0 ? parts.slice(0, firstGlobIdx).join('/') : '.';
            const fullDirPath = `${projectPath}/${dirPath}`;

            const result = await filesAPI.readDirectory(fullDirPath);
            if (!result.error && result.files) {
              const matchedFiles = result.files
                .filter((f: any) => !f.isDir && f.name.endsWith('.vec'))
                .map((f: any) => {
                  const name = f.name.replace('.vec', '');
                  vecPaths.set(name, `${fullDirPath}/${f.name}`);
                  return name;
                });
              vecFiles.push(...matchedFiles);
            }
          } else {
            const name = pattern.split('/').pop()?.replace('.vec', '') || '';
            vecFiles.push(name);
            vecPaths.set(name, `${projectPath}/${pattern}`);
          }
        }
        
        console.log('[Playground] Found vectors:', vecFiles.length);
        setAvailableVectors(vecFiles);

        // Load vector files using file:read IPC
        const vectors = new Map<string, VecVector>();
        for (const vecName of vecFiles) {
          try {
            const vecPath = vecPaths.get(vecName);
            if (!vecPath) continue;
            
            const result = await filesAPI.readFile(vecPath);
            if (!result.error && result.content) {
              const vecData: VecVector = JSON.parse(result.content);
              vectors.set(vecName, vecData);
            } else {
              console.error(`[Playground] Error reading ${vecName}:`, result.error);
            }
          } catch (err) {
            console.error(`[Playground] Failed to parse ${vecName}:`, err);
          }
        }
        
        setLoadedVectors(vectors);
        console.log('[Playground] Loaded', vectors.size, 'vectors');

        // Scan for background images (PNG/JPG) in assets/ and load as data URLs
        const imageFiles: string[] = [];
        const imgDataMap = new Map<string, string>();
        const imgExtensions = ['.png', '.jpg', '.jpeg'];
        const imgDirs = ['assets', 'assets/overlay', 'assets/backgrounds', 'assets/images'];
        for (const dir of imgDirs) {
          const fullDir = `${projectPath}/${dir}`;
          const dirResult = await filesAPI.readDirectory(fullDir).catch(() => ({ error: true }));
          if (!dirResult.error && dirResult.files) {
            for (const f of dirResult.files) {
              const lname = f.name.toLowerCase();
              if (!f.isDir && imgExtensions.some((ext: string) => lname.endsWith(ext))) {
                const key = `${dir}/${f.name}`;
                const absPath = `${fullDir}/${f.name}`;
                const binResult = await filesAPI.readFileBin(absPath).catch(() => null);
                if (binResult && !binResult.error && binResult.base64) {
                  const mime = lname.endsWith('.png') ? 'image/png' : 'image/jpeg';
                  imgDataMap.set(key, `data:${mime};base64,${binResult.base64}`);
                  imageFiles.push(key);
                }
              }
            }
          }
        }
        setAvailableImages(imageFiles);
        setImageDataUrls(imgDataMap);
      } catch (error) {
        console.error('[Playground] Error:', error);
      }
    };

    loadVectors();
  }, [vpyProject]);

  // Load available .vplay scenes
  useEffect(() => {
    const loadScenes = async () => {
      if (!vpyProject?.rootDir) return;
      
      try {
        const projectRoot = vpyProject.rootDir;
        const playgroundPath = `${projectRoot}/assets/playground`;
        
        const result = await (window as any).files.readDirectory(playgroundPath);
        const scenes = result.files
          .filter((f: any) => f.name.endsWith('.vplay'))
          .map((f: any) => f.name.replace('.vplay', ''));
        setAvailableScenes(scenes);
        console.log('[Playground] Found', scenes.length, 'scenes');
      } catch (error) {
        console.log('[Playground] No scenes directory yet');
      }
    };

    loadScenes();
  }, [vpyProject]);

  // Load available .venemy enemy types and build enemyType → vectorName map
  useEffect(() => {
    const loadEnemies = async () => {
      if (!vpyProject?.rootDir) return;
      const filesAPI = (window as any).files;
      try {
        const result = await filesAPI?.readDirectory?.(`${vpyProject.rootDir}/assets/enemies`);
        if (result?.files) {
          const enemies: string[] = result.files
            .filter((f: any) => f.name.endsWith('.venemy'))
            .map((f: any) => f.name.replace('.venemy', ''));
          setAvailableEnemies(enemies);

          // Parse each venemy file to find the sprite vector name (first action)
          const vecMap = new Map<string, string>();
          for (const enemyName of enemies) {
            try {
              const path = `${vpyProject.rootDir}/assets/enemies/${enemyName}.venemy`;
              const res = await filesAPI?.readFile?.(path);
              if (res?.content) {
                const data = JSON.parse(res.content);
                // Prefer first .vec action (directly renderable); vanim frames
                // are not loaded into loadedVectors so would show as diamond.
                const actions: any[] = data.actions || [];
                const vecAction = actions.find((a: any) => a.sprite?.endsWith('.vec'));
                const spritePath: string = vecAction?.sprite || actions[0]?.sprite || '';
                if (spritePath) {
                  const filename = spritePath.split('/').pop() || '';
                  const stem = filename.replace(/\.(vec|vanim)$/, '');
                  if (stem) vecMap.set(enemyName, stem);
                }
              }
            } catch {}
          }
          setEnemyTypeVectorMap(vecMap);
        }
      } catch {
        // enemies directory doesn't exist yet
      }
    };
    loadEnemies();
  }, [vpyProject]);

  // Listen for scene load requests from FileTree
  useEffect(() => {
    const handleLoadSceneRequest = (event: CustomEvent) => {
      const sceneName = event.detail.sceneName;
      console.log('[Playground] Load scene request:', sceneName);
      handleLoadScene(sceneName);
    };

    window.addEventListener('playground:loadScene' as any, handleLoadSceneRequest);
    return () => {
      window.removeEventListener('playground:loadScene' as any, handleLoadSceneRequest);
    };
  }, [vpyProject]); // handleLoadScene uses vpyProject, so include it in deps

  // Auto-load last opened scene when project is ready
  useEffect(() => {
    if (!vpyProject?.rootDir) return;
    try {
      const raw = localStorage.getItem('playground_last_scene');
      if (!raw) return;
      const { sceneName: lastScene, projectRoot } = JSON.parse(raw);
      if (projectRoot !== vpyProject.rootDir) return;
      if (!lastScene) return;
      handleLoadScene(lastScene);
    } catch {}
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [vpyProject?.rootDir]);

  // Apply pending scroll restore after render
  useEffect(() => {
    if (!pendingScrollRef.current || !containerRef.current) return;
    const { top, left } = pendingScrollRef.current;
    pendingScrollRef.current = null;
    requestAnimationFrame(() => {
      if (containerRef.current) {
        containerRef.current.scrollTop = top;
        containerRef.current.scrollLeft = left;
      }
    });
  });

  // Physics simulation loop
  useEffect(() => {
    if (!isPlaying) {
      if (animationFrameRef.current) {
        cancelAnimationFrame(animationFrameRef.current);
        animationFrameRef.current = null;
      }
      return;
    }

    const updatePhysics = () => {
      setObjects(prevObjects => {
        const newObjects = prevObjects.map(obj => {
          // Enemy patrol simulation
          if (obj.type === 'enemy' && (obj as any).aiType === 'patrol') {
            const wps: { x: number; y: number }[] = (obj as any).patrolWaypoints || [];
            const SPEED = (obj as any).speed ?? 1.0;
            if (wps.length >= 2) {
              const idx = enemyPatrolIdxRef.current.get(obj.id) ?? 0;
              const target = wps[idx % wps.length];
              const dx = target.x - obj.x;
              const dy = target.y - obj.y;
              const dist = Math.sqrt(dx * dx + dy * dy);
              if (dist < SPEED + 0.5) {
                enemyPatrolIdxRef.current.set(obj.id, (idx + 1) % wps.length);
                return { ...obj, x: target.x, y: target.y };
              }
              const nx = obj.x + (dx / dist) * SPEED;
              const ny = obj.y + (dy / dist) * SPEED;
              return { ...obj, x: nx, y: ny, _facingRight: dx > 0 };
            }
            // No waypoints: area-bounded patrol — bounce X within the
            // closest walkable area (enemy override > level > .vec-collected).
            const own = (obj as any).walkable_areas as { y: number; x_min: number; x_max: number }[] | undefined;
            const candidates: { y: number; x_min: number; x_max: number }[] =
              own !== undefined ? own
              : levelWalkableAreas.length > 0 ? levelWalkableAreas
              : collectVecWalkableAreas(prevObjects, loadedVectors);
            if (candidates.length === 0) return obj;
            let best = 0;
            let bestDy = Math.abs(candidates[0].y - obj.y);
            for (let i = 1; i < candidates.length; i++) {
              const d = Math.abs(candidates[i].y - obj.y);
              if (d < bestDy) { best = i; bestDy = d; }
            }
            const a = candidates[best];
            const feetOff = getEnemyFeetOffset((obj as any).enemyType, loadedVectors);
            const dirRight = (obj as any)._facingRight !== false;
            const targetX = dirRight ? a.x_max : a.x_min;
            const dxA = targetX - obj.x;
            if (Math.abs(dxA) <= SPEED) {
              return { ...obj, x: targetX, y: a.y + feetOff, _facingRight: !dirRight };
            }
            return { ...obj, x: obj.x + Math.sign(dxA) * SPEED, y: a.y + feetOff, _facingRight: dirRight };
          }

          // Enemy wander simulation: area-based AI mirroring the ARM runtime.
          //   - WALK: bounce between current area's x_min and x_max.
          //   - IDLE: timer, on expiry roll for transition.
          //   - AIRBORNE: linear y-interp toward target area.
          if (obj.type === 'enemy' && (obj as any).aiType === 'wander') {
            const explicit = (obj as any).walkable_areas as
              | { y: number; x_min: number; x_max: number }[]
              | undefined;
            const explicitTransitions = (obj as any).transitions as
              | { from: number; to: number; type: 'jump_up' | 'drop'; from_x?: number; to_x?: number }[]
              | undefined;
            const wps = (obj as any).patrolWaypoints as { x: number; y: number }[] | undefined;
            // Inheritance: enemy override > level > .vec-collected > waypoint-derived.
            const vecCollectedRes = collectVecWalkableAreasWithSources(prevObjects, loadedVectors);
            const vecCollected = vecCollectedRes.areas;
            const usingVecAreas = explicit === undefined && levelWalkableAreas.length === 0 && vecCollected.length > 0;
            const areas =
              explicit !== undefined
                ? explicit
                : levelWalkableAreas.length > 0
                  ? levelWalkableAreas
                  : vecCollected.length > 0
                    ? vecCollected
                    : wps && wps.length >= 2
                      ? [{
                          y: obj.y,
                          x_min: Math.min(...wps.map(w => w.x)),
                          x_max: Math.max(...wps.map(w => w.x)),
                        }]
                      : [];
            if (areas.length === 0) return obj;
            const transitions = explicitTransitions !== undefined
              ? explicitTransitions
              : levelTransitions.length > 0
                ? levelTransitions
                : deriveTransitions(areas, usingVecAreas ? vecCollectedRes.sources : undefined);
            const SPEED = (obj as any).speed ?? 1.0;
            const st = enemyWanderStateRef.current.get(obj.id) as
              | WanderState
              | undefined
              ?? { sub: 'walk' as const, timer: 0, areaIdx: 0, dir: 1 };

            // WALK_TO_TAKEOFF: walk X-only toward fromX, then transition into AIRBORNE.
            if (st.sub === 'to_takeoff' && st.fromX !== undefined) {
              const dx = st.fromX - obj.x;
              const absDx = Math.abs(dx);
              const dir: 1 | -1 = dx >= 0 ? 1 : -1;
              if (absDx <= SPEED) {
                // Arrived — initial arc velocity from transition type (mirrors
                // pitrex/builtins.rs .Lpue_w_tt_reached). For jump_up, scale
                // vy0 so vy0*(vy0+1)/2 >= dy (so the peak actually reaches the
                // target). Drop/across use small fixed impulses.
                const targetYJump = st.targetY ?? obj.y;
                const dyJump = targetYJump - obj.y;
                let vy0: number;
                if (st.transType === 'drop') vy0 = -1;
                else if (st.transType === 'jump_across') vy0 = 3;
                else {
                  vy0 = 4;
                  while (vy0 < 16 && (vy0 * (vy0 + 1)) >> 1 < dyJump) vy0++;
                }
                // Face the jump target so the sprite mirror is correct.
                const targetX = st.targetX ?? st.fromX;
                const airDir: 1 | -1 = targetX >= st.fromX ? 1 : -1;
                enemyWanderStateRef.current.set(obj.id, {
                  ...st,
                  sub: 'air',
                  timer: 0,
                  dir: airDir,
                  vy: vy0,
                });
                return { ...obj, x: st.fromX, _facingRight: airDir === 1 };
              }
              return { ...obj, x: obj.x + dir * SPEED, _facingRight: dir === 1 };
            }

            // AIRBORNE: two-phase. While X is still moving, run the
            // parabolic Y arc. Once X is at target, lerp Y toward target_y
            // at AIR_SPEED so the AIRBORNE state always ends in bounded time
            // (long jump_across used to leave enemies floating because Y
            // diverged past target while X was still moving).
            if (st.sub === 'air' && st.targetX !== undefined && st.targetY !== undefined) {
              const AIR_SPEED = 4;
              const dx = st.targetX - obj.x;
              const absDx = Math.abs(dx);
              const dir: 1 | -1 = dx >= 0 ? 1 : -1;
              if (absDx === 0) {
                // Phase B: lerp Y to target.
                const dy = st.targetY - obj.y;
                if (dy === 0) {
                  enemyWanderStateRef.current.set(obj.id, {
                    sub: 'walk', timer: 0,
                    areaIdx: st.targetAreaIdx ?? st.areaIdx ?? 0,
                    dir: st.dir ?? 1,
                  });
                  return { ...obj, x: st.targetX, y: st.targetY, _facingRight: dir === 1 };
                }
                const yStep = Math.sign(dy) * Math.min(Math.abs(dy), AIR_SPEED);
                const ny = obj.y + yStep;
                return { ...obj, y: ny, _facingRight: dir === 1 };
              }
              // Phase A: X step + parabolic Y.
              const nx = absDx <= AIR_SPEED ? st.targetX : obj.x + dir * AIR_SPEED;
              const curVy = st.vy ?? 0;
              const ny = obj.y + curVy;
              const nextVy = Math.max(-3, curVy - 1);
              enemyWanderStateRef.current.set(obj.id, { ...st, vy: nextVy });
              return { ...obj, x: nx, y: ny, _facingRight: dir === 1 };
            }

            // IDLE: count down; on expiry, scan transitions for matches.
            if (st.sub === 'idle') {
              const nextTimer = st.timer - 1;
              if (nextTimer > 0) {
                enemyWanderStateRef.current.set(obj.id, { ...st, timer: nextTimer });
                return obj;
              }
              const curArea = st.areaIdx ?? 0;
              const candidates = transitions.filter(t => t.from === curArea && t.to < areas.length);
              for (const t of candidates) {
                // 25% chance per candidate to commit (matches ARM coin-flip)
                if (Math.random() < 0.25) {
                  const srcArea = areas[t.from];
                  const dstArea = areas[t.to];
                  const fromX = (t as any).from_x ?? (srcArea.x_min + srcArea.x_max) / 2;
                  const toX   = (t as any).to_x   ?? (dstArea.x_min + dstArea.x_max) / 2;
                  // Enter WALK_TO_TAKEOFF — the enemy will walk to fromX
                  // before the actual jump. No snap here.
                  enemyWanderStateRef.current.set(obj.id, {
                    sub: 'to_takeoff', timer: 0,
                    areaIdx: curArea,
                    targetAreaIdx: t.to,
                    targetY: dstArea.y,
                    targetX: toX,
                    fromX,
                    dir: st.dir ?? 1,
                    transType: t.type as 'jump_up' | 'drop' | 'jump_across',
                  });
                  return obj;
                }
              }
              // No transition picked: back to WALK on same area.
              enemyWanderStateRef.current.set(obj.id, {
                sub: 'walk', timer: 0,
                areaIdx: curArea,
                dir: st.dir ?? 1,
              });
              return obj;
            }

            // WALK: bounce between current area's x_min, x_max.
            const curAreaIdx = st.areaIdx ?? 0;
            const area = areas[curAreaIdx] ?? areas[0];
            const dir = st.dir ?? 1;
            const targetX = dir === 1 ? area.x_max : area.x_min;
            const dx = targetX - obj.x;
            const absDx = Math.abs(dx);
            if (absDx <= SPEED) {
              // Reached edge: reverse and enter IDLE.
              const idleFrames = 30 + Math.floor(Math.random() * 64);
              enemyWanderStateRef.current.set(obj.id, {
                sub: 'idle', timer: idleFrames,
                areaIdx: curAreaIdx,
                dir: dir === 1 ? -1 : 1,
              });
              const feetOff = getEnemyFeetOffset((obj as any).enemyType, loadedVectors);
              return { ...obj, x: targetX, y: area.y + feetOff, _facingRight: dir === 1 };
            }
            const feetOff = getEnemyFeetOffset((obj as any).enemyType, loadedVectors);
            return { ...obj, x: obj.x + Math.sign(dx) * SPEED, y: area.y + feetOff, _facingRight: dir === 1 };
          }

          if (!obj.physicsEnabled) return obj;

          const physicsType = obj.physicsType || 'gravity';
          const objGravity = obj.gravity ?? 1;
          const objBounce = obj.bounceDamping ?? 0.85;
          const objRadius = (obj.radius ?? 10) * obj.scale;

          let newVelY = obj.velocity?.y || 0;
          let newVelX = obj.velocity?.x || 0;
          
          // Apply physics based on type
          if (physicsType === 'gravity') {
            // Standard gravity physics
            newVelY = newVelY - objGravity;
          } else if (physicsType === 'bounce') {
            // Perpetual bounce - no gravity, constant speed
            // Velocity stays the same until collision
          } else if (physicsType === 'projectile') {
            // Projectile with gravity but no bouncing
            newVelY = newVelY - objGravity;
          }
          // 'static' type doesn't move
          
          // Limit max velocity (Pang-style slow movement)
          const MAX_VEL = 15;
          newVelX = Math.max(-MAX_VEL, Math.min(MAX_VEL, newVelX));
          newVelY = Math.max(-MAX_VEL, Math.min(MAX_VEL, newVelY));
          
          let newX = obj.x + newVelX;
          let newY = obj.y + newVelY;
          let velX = newVelX;
          let velY = newVelY;

          // Boundary collisions based on physics type (with radius)
          if (physicsType !== 'static') {
            // Horizontal walls (left/right)
            if (newX - objRadius <= worldXMin) {
              newX = worldXMin + objRadius;
              if (physicsType === 'bounce') {
                velX = -velX; // Perfect bounce
              } else if (physicsType === 'gravity') {
                velX = -velX * objBounce; // Energy loss
              } else if (physicsType === 'projectile') {
                velX = 0; // Stop
              }
            } else if (newX + objRadius >= worldXMax) {
              newX = worldXMax - objRadius;
              if (physicsType === 'bounce') {
                velX = -velX;
              } else if (physicsType === 'gravity') {
                velX = -velX * objBounce;
              } else if (physicsType === 'projectile') {
                velX = 0;
              }
            }

            // Vertical walls (floor/ceiling)
            if (newY - objRadius <= worldYMin) {
              newY = worldYMin + objRadius + 0.5; // Keep object fully visible + safety margin
              if (physicsType === 'bounce') {
                velY = -velY; // Perfect bounce - maintains speed
              } else if (physicsType === 'gravity') {
                velY = -velY * objBounce; // Energy loss
                if (Math.abs(velY) < 2) velY = 0;
              } else if (physicsType === 'projectile') {
                velY = 0; // Stop on ground
              }
            } else if (newY + objRadius >= worldYMax) {
              newY = worldYMax - objRadius - 0.5; // Keep object fully visible + safety margin
              if (physicsType === 'bounce') {
                velY = -velY; // Perfect bounce from ceiling
              } else if (physicsType === 'gravity') {
                velY = -velY * objBounce;
              } else if (physicsType === 'projectile') {
                velY = 0;
              }
            }
          }

          return {
            ...obj,
            x: newX,
            y: newY,
            velocity: { x: velX, y: velY },
          };
        });

        // Object-to-object collisions
        const finalObjects = newObjects.map((obj, i) => {
          if (!obj.physicsEnabled) return obj;
          // Skip if current object is not collidable
          if (!obj.collidable) return obj;

          for (let j = 0; j < newObjects.length; j++) {
            if (i === j) continue;
            
            const other = newObjects[j];
            // Skip if other object is not collidable
            if (!other.collidable) continue;

            const dx = obj.x - other.x;
            const dy = obj.y - other.y;
            const distance = Math.sqrt(dx * dx + dy * dy);
            
            // Use actual radius from vector bounds
            const objRadius = (obj.radius ?? 10) * obj.scale;
            const otherRadius = (other.radius ?? 10) * other.scale;
            const minDist = objRadius + otherRadius;

            if (distance < minDist && distance > 0) {
              // Collision detected - bounce away
              const angle = Math.atan2(dy, dx);
              const targetX = other.x + Math.cos(angle) * minDist;
              const targetY = other.y + Math.sin(angle) * minDist;
              
              const velMag = Math.sqrt(
                (obj.velocity?.x || 0) ** 2 + (obj.velocity?.y || 0) ** 2
              );
              const objBounce = obj.bounceDamping ?? 0.85;
              
              return {
                ...obj,
                x: targetX,
                y: targetY,
                velocity: {
                  x: Math.cos(angle) * velMag * objBounce,
                  y: Math.sin(angle) * velMag * objBounce,
                },
              };
            }
          }
          return obj;
        });

        return finalObjects;
      });

      animationFrameRef.current = requestAnimationFrame(updatePhysics);
    };

    animationFrameRef.current = requestAnimationFrame(updatePhysics);

    return () => {
      if (animationFrameRef.current) {
        cancelAnimationFrame(animationFrameRef.current);
      }
    };
  }, [isPlaying]);

  // Save/Load scene functions
  const handleSaveScene = async () => {
    if (!sceneName.trim()) {
      showToast('Please enter a scene name', 'error');
      return;
    }

    try {
      const projectRoot = vpyProject?.rootDir;
      if (!projectRoot) {
        showToast('No project loaded', 'error');
        return;
      }

      const sceneData: VPlayLevel = {
        version: VPLAY_VERSION,
        type: 'level',
        metadata: {
          name: sceneName,
          author: '',
          difficulty: 'medium',
          timeLimit: 0,
          targetScore: 0,
          description: `Created in Playground - ${new Date().toISOString().split('T')[0]}`
        },
        worldBounds: {
          xMin: worldXMin,
          xMax: worldXMax,
          yMin: worldYMin,
          yMax: worldYMax,
        },
        // Level-wide walkable areas + transitions: only persisted when non-empty
        // so old levels round-trip unchanged.
        ...(levelWalkableAreas.length > 0 ? { walkable_areas: levelWalkableAreas } : {}),
        ...(levelTransitions.length > 0 ? { transitions: levelTransitions } : {}),
        ...(isolateScreens ? { isolateScreens: true } : {}),
        ...(transMinXOverlap !== 4 ? { transitionMinXOverlap: transMinXOverlap } : {}),
        ...(transLateralY    !== 8 ? { transitionLateralY: transLateralY }       : {}),
        ...(transLateralGap !== 60 ? { transitionLateralGap: transLateralGap }   : {}),
        layers: {
          background: objects.filter(obj => obj.layer === 'background').map(obj => ({
            ...obj,
            x: Math.round(obj.x),
            y: Math.round(obj.y),
            velocity: obj.velocity ? { 
              x: Math.round(obj.velocity.x), 
              y: Math.round(obj.velocity.y) 
            } : { x: 0, y: 0 },
            layer: 'background' as const
          })) as VPlayObject[],
          gameplay: objects.filter(obj => !obj.layer || obj.layer === 'gameplay').map(obj => ({
            ...obj,
            x: Math.round(obj.x),
            y: Math.round(obj.y),
            velocity: obj.velocity ? { 
              x: Math.round(obj.velocity.x), 
              y: Math.round(obj.velocity.y) 
            } : { x: 0, y: 0 },
            layer: 'gameplay' as const,
            // Fill vectorName for enemy objects from the enemy type's idle sprite
            vectorName: (obj.type === 'enemy' && !obj.vectorName && obj.enemyType)
              ? (enemyTypeVectorMap.get(obj.enemyType) || obj.vectorName)
              : obj.vectorName,
          })) as VPlayObject[],
          foreground: objects.filter(obj => obj.layer === 'foreground').map(obj => ({
            ...obj,
            x: Math.round(obj.x),
            y: Math.round(obj.y),
            velocity: obj.velocity ? { 
              x: Math.round(obj.velocity.x), 
              y: Math.round(obj.velocity.y) 
            } : { x: 0, y: 0 },
            layer: 'foreground' as const
          })) as VPlayObject[]
        },
        spawnPoints: {
          player: { x: 0, y: -100 }
        },
        hotspots: hotspots,
        ...(Object.keys(scrollLimits).some(k => (scrollLimits as any)[k] !== undefined)
          ? { scrollLimits }
          : {}),
        _editorMeta: {
          ...(screenBackgrounds.length > 0 ? { screenBackgrounds } : {}),
          groundBottomOffset,
        },
      };

      // Validate before saving
      const validation = VPlayValidator.validate(sceneData);
      if (!validation.valid) {
        console.error('[Playground] Validation errors:', validation.errors);
        showToast(`Validation failed: ${validation.errors[0]}`, 'error');
        return;
      }

      const filePath = `${projectRoot}/assets/playground/${sceneName}.vplay`;
      await (window as any).files.saveFile({
        path: filePath,
        content: JSON.stringify(sceneData, null, 2),
      });
      
      console.log('[Playground] Saved scene:', filePath);
      showToast(`Scene "${sceneName}" saved!`, 'success');
      setShowSaveLoadModal(false);
      // Keep sceneName so we can quick-save next time
      
      // Refresh scene list
      const result = await (window as any).files.readDirectory(`${projectRoot}/assets/playground`);
      const scenes = result.files
        .filter((f: any) => f.name.endsWith('.vplay'))
        .map((f: any) => f.name.replace('.vplay', ''));
      setAvailableScenes(scenes);
    } catch (error) {
      console.error('[Playground] Save error:', error);
      showToast('Failed to save scene', 'error');
    }
  };

  const handleLoadScene = async (name: string) => {
    try {
      const projectRoot = vpyProject?.rootDir;
      if (!projectRoot) return;

      const filePath = `${projectRoot}/assets/playground/${name}.vplay`;
      const result = await (window as any).files.readFile(filePath);
      let sceneData = JSON.parse(result.content);
      
      // Auto-migrate v1.0 to v2.0
      if (sceneData.version === '1.0') {
        console.log('[Playground] Migrating v1.0 level to v2.0');
        sceneData = VPlayValidator.migrateV1toV2(sceneData);
        showToast(`Migrated "${name}" from v1.0 to v2.0`, 'success');
      }
      
      // Validate loaded data
      const validation = VPlayValidator.validate(sceneData);
      if (!validation.valid) {
        console.error('[Playground] Validation errors:', validation.errors);
        showToast(`Invalid level: ${validation.errors[0]}`, 'error');
        return;
      }
      
      // Extract objects from layers or legacy objects array
      const loadedObjects: SceneObject[] = [];
      if (sceneData.layers) {
        loadedObjects.push(...(sceneData.layers.background || []));
        loadedObjects.push(...(sceneData.layers.gameplay || []));
        loadedObjects.push(...(sceneData.layers.foreground || []));
      } else if (sceneData.objects) {
        loadedObjects.push(...sceneData.objects);
      }
      
      // Restore world bounds (screen count) from saved data
      if (sceneData.worldBounds) {
        const wScreens = Math.max(1, Math.round(
          (sceneData.worldBounds.xMax - sceneData.worldBounds.xMin + 1) / 192
        ));
        const hScreens = Math.max(1, Math.round(
          (sceneData.worldBounds.yMax - sceneData.worldBounds.yMin + 1) / 256
        ));
        setWidthScreens(wScreens);
        setHeightScreens(hScreens);
      }

      setObjects(loadedObjects);
      setHotspots(sceneData.hotspots || []);
      setScrollLimits(sceneData.scrollLimits || {});
      setScreenBackgrounds((sceneData._editorMeta?.screenBackgrounds) || []);
      // Level-wide walkable areas / transitions (Phase 2 inheritance source).
      setLevelWalkableAreas((sceneData as any).walkable_areas ?? []);
      setLevelTransitions((sceneData as any).transitions ?? []);
      setIsolateScreens(!!(sceneData as any).isolateScreens);
      setTransMinXOverlap((sceneData as any).transitionMinXOverlap ?? 4);
      setTransLateralY((sceneData as any).transitionLateralY ?? 8);
      setTransLateralGap((sceneData as any).transitionLateralGap ?? 60);
      if (sceneData._editorMeta?.groundBottomOffset !== undefined) {
        setGroundBottomOffset(sceneData._editorMeta.groundBottomOffset);
      }
      setSelectedHotspotId(null);
      setSelectedLimit(null);
      setSelectedId(null);
      setSelectedIds(new Set());
      setSceneName(name); // Remember the scene name for future saves
      // Persist last opened scene for auto-restore on next panel visit
      if (vpyProject?.rootDir) {
        localStorage.setItem('playground_last_scene', JSON.stringify({
          sceneName: name,
          projectRoot: vpyProject.rootDir,
        }));
      }
      // Schedule scroll restore if pending (e.g. coming from auto-load)
      const savedScroll = localStorage.getItem('playground_scroll_' + name);
      if (savedScroll) {
        try {
          const { top, left } = JSON.parse(savedScroll);
          pendingScrollRef.current = { top, left };
        } catch {}
      }
      console.log('[Playground] Loaded scene:', name, `(${loadedObjects.length} objects)`);
      showToast(`Scene "${name}" loaded!`, 'success');
      setShowSaveLoadModal(false);
    } catch (error) {
      console.error('[Playground] Load error:', error);
      showToast('Failed to load scene', 'error');
    }
  };

  const handleDeleteScene = async (name: string) => {
    if (!confirm(`Delete scene "${name}"?`)) return;

    try {
      const projectRoot = vpyProject?.rootDir;
      if (!projectRoot) return;

      const filePath = `${projectRoot}/assets/playground/${name}.vplay`;
      await (window as any).files.deleteFile(filePath);
      
      console.log('[Playground] Deleted scene:', name);
      
      // Refresh scene list
      const result = await (window as any).files.readDirectory(`${projectRoot}/assets/playground`);
      const scenes = result.files
        .filter((f: any) => f.name.endsWith('.vplay'))
        .map((f: any) => f.name.replace('.vplay', ''));
      setAvailableScenes(scenes);
    } catch (error) {
      console.error('[Playground] Delete error:', error);
      showToast('Failed to delete scene', 'error');
    }
  };

  // Handle drag and drop to add objects
  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    if (!draggedVector || !canvasRef.current) return;

    const rect = canvasRef.current.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;

    // Convert screen coordinates to Vectrex coordinates
    const vecX = Math.round((x / rect.width) * (192 * widthScreens) + worldXMin);
    const vecY = Math.round(worldYMax - (y / rect.height) * (256 * heightScreens));

    const newObject: SceneObject = {
      id: `obj_${Date.now()}`,
      type: activeTool === 'enemy' ? 'enemy' : 'background',
      vectorName: draggedVector,
      layer: 'gameplay',
      x: vecX,
      y: vecY,
      rotation: 0,
      scale: 1,
      velocity: { x: 0, y: 0 },
      physicsEnabled: false,
      collidable: true,
      gravity: 1,
      bounceDamping: 0.85,
      physicsType: 'gravity',
    };

    setObjects([...objects, newObject]);
    setDraggedVector(null);
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
  };

  // Object dragging handlers
  const handleObjectMouseDown = (e: React.MouseEvent, objId: string) => {
    e.stopPropagation();
    if (!canvasRef.current) return;

    const obj = objects.find(o => o.id === objId);
    if (!obj) return;

    const rect = canvasRef.current.getBoundingClientRect();
    const mouseX = e.clientX - rect.left;
    const mouseY = e.clientY - rect.top;
    const vecX = Math.round((mouseX / rect.width) * (192 * widthScreens) + worldXMin);
    const vecY = Math.round(worldYMax - (mouseY / rect.height) * (256 * heightScreens));

    // Compute effective selection for this interaction
    let effectiveIds: Set<string>;
    if (e.shiftKey) {
      effectiveIds = new Set(selectedIds);
      if (effectiveIds.has(objId)) effectiveIds.delete(objId);
      else effectiveIds.add(objId);
    } else if (selectedIds.has(objId) && selectedIds.size > 1) {
      // Clicking inside an existing multi-selection: keep group for drag
      effectiveIds = new Set(selectedIds);
    } else {
      effectiveIds = new Set([objId]);
    }

    setSelectedIds(effectiveIds);
    setSelectedId(objId);
    setDraggingObjectId(objId);
    setDragOffset({ x: vecX - obj.x, y: vecY - obj.y });

    // Record drag start for multi-object movement
    dragStartVecRef.current = { x: vecX, y: vecY };
    dragInitialPositionsRef.current = new Map(
      [...effectiveIds].flatMap(id => {
        const o = objects.find(ob => ob.id === id);
        return o ? [[id, { x: o.x, y: o.y }]] : [];
      })
    );
  };

  const handleVelocityArrowMouseDown = (e: React.MouseEvent) => {
    if (editingVelocity && selectedId) {
      e.stopPropagation();
      setDraggingVelocity(true);
    }
  };

  const handleVelocityArrowDrag = (e: React.MouseEvent) => {
    if (!draggingVelocity || !selectedId || !canvasRef.current) return;

    const selectedObj = objects.find(o => o.id === selectedId);
    if (!selectedObj) return;

    const rect = canvasRef.current.getBoundingClientRect();
    const mouseX = e.clientX - rect.left;
    const mouseY = e.clientY - rect.top;

    // Convert to Vectrex coordinates
    const vecX = (mouseX / rect.width) * (192 * widthScreens) + worldXMin;
    const vecY = worldYMax - (mouseY / rect.height) * (256 * heightScreens);

    // Calculate velocity from mouse position relative to object
    const dx = vecX - selectedObj.x;
    const dy = vecY - selectedObj.y;
    
    // Scale down (arrow is 3x size) and clamp to max velocity
    const velX = Math.max(-15, Math.min(15, dx / 3));
    const velY = Math.max(-15, Math.min(15, dy / 3));
    
    setObjects(objects.map(o =>
      o.id === selectedId ? { ...o, velocity: { x: velX, y: velY } } : o
    ));
  };

  // Middle mouse button: start pan; Left button on empty canvas: start rubber band selection
  const handleCanvasMouseDown = (e: React.MouseEvent<SVGSVGElement>) => {
    if (e.button === 1) {
      e.preventDefault();
      isPanningRef.current = true;
      setIsPanning(true);
      panStartRef.current = {
        x: e.clientX,
        y: e.clientY,
        scrollLeft: containerRef.current?.scrollLeft ?? 0,
        scrollTop: containerRef.current?.scrollTop ?? 0,
      };
      return;
    }
    // Walkable-area draw mode: convert click to vec coords, anchor x_min/x_max
    // at the click point and remember y. Drag will sweep the x range.
    if (e.button === 0 && drawingLevelAreaIdx !== null && canvasRef.current) {
      e.preventDefault();
      e.stopPropagation();
      const rect = canvasRef.current.getBoundingClientRect();
      const mouseX = e.clientX - rect.left;
      const mouseY = e.clientY - rect.top;
      const vecX = Math.round((mouseX / rect.width) * (192 * widthScreens) + worldXMin);
      const vecY = Math.round(worldYMax - (mouseY / rect.height) * (256 * heightScreens));
      drawingStartXRef.current = vecX;
      setDrawingPreview({ y: vecY, x_min: vecX, x_max: vecX });
      return;
    }
    if (e.button === 0 && activeTool === 'select' && canvasRef.current) {
      const rect = canvasRef.current.getBoundingClientRect();
      const svgX = ((e.clientX - rect.left) / rect.width) * (192 * widthScreens);
      const svgY = ((e.clientY - rect.top) / rect.height) * (256 * heightScreens);
      rubberBandStartRef.current = { svgX, svgY };
    }
  };

  const handleCanvasMouseMove = (e: React.MouseEvent) => {
    // Middle mouse pan
    if (isPanningRef.current && containerRef.current) {
      const dx = e.clientX - panStartRef.current.x;
      const dy = e.clientY - panStartRef.current.y;
      containerRef.current.scrollLeft = panStartRef.current.scrollLeft - dx;
      containerRef.current.scrollTop = panStartRef.current.scrollTop - dy;
      return;
    }

    // Walkable-area draw mode: while the user holds the mouse down after the
    // first click, sweep x_max (and re-clamp x_min to whichever is lower).
    if (drawingLevelAreaIdx !== null && drawingStartXRef.current !== null && drawingPreview && canvasRef.current) {
      const rect = canvasRef.current.getBoundingClientRect();
      const mouseX = e.clientX - rect.left;
      const vecX = Math.round((mouseX / rect.width) * (192 * widthScreens) + worldXMin);
      const xMin = Math.min(drawingStartXRef.current, vecX);
      const xMax = Math.max(drawingStartXRef.current, vecX);
      setDrawingPreview({ y: drawingPreview.y, x_min: xMin, x_max: xMax });
      return;
    }

    if (draggingLimit && canvasRef.current) {
      const rect = canvasRef.current.getBoundingClientRect();
      const mouseX = e.clientX - rect.left;
      const mouseY = e.clientY - rect.top;
      if (draggingLimit === 'left' || draggingLimit === 'right') {
        const vecX = Math.round((mouseX / rect.width) * (192 * widthScreens) + worldXMin);
        const clamped = Math.max(worldXMin, Math.min(worldXMax, vecX));
        setScrollLimits(prev => ({ ...prev, [draggingLimit]: clamped }));
      } else {
        const vecY = Math.round(worldYMax - (mouseY / rect.height) * (256 * heightScreens));
        const clamped = Math.max(worldYMin, Math.min(worldYMax, vecY));
        setScrollLimits(prev => ({ ...prev, [draggingLimit]: clamped }));
      }
      return;
    }

    if (draggingHotspotId && hotspotDragOffset) {
      const rect = canvasRef.current?.getBoundingClientRect();
      if (!rect) return;
      const mouseX = e.clientX - rect.left;
      const mouseY = e.clientY - rect.top;
      const vecX = Math.round((mouseX / rect.width) * (192 * widthScreens) + worldXMin);
      const vecY = Math.round(worldYMax - (mouseY / rect.height) * (256 * heightScreens));
      setHotspots(prev => prev.map(hs =>
        hs.id === draggingHotspotId
          ? { ...hs, x: vecX - hotspotDragOffset.x, y: vecY - hotspotDragOffset.y }
          : hs
      ));
      return;
    }

    if (draggingWaypointInfo && canvasRef.current) {
      const rect = canvasRef.current.getBoundingClientRect();
      const mouseX = e.clientX - rect.left;
      const mouseY = e.clientY - rect.top;
      const vecX = Math.round((mouseX / rect.width) * (192 * widthScreens) + worldXMin);
      const vecY = Math.round(worldYMax - (mouseY / rect.height) * (256 * heightScreens));
      const { enemyId, wpIdx } = draggingWaypointInfo;
      setObjects(prev => prev.map(o => {
        if (o.id !== enemyId) return o;
        const wps = [...(o.patrolWaypoints || [])];
        wps[wpIdx] = { x: vecX, y: vecY };
        return { ...o, patrolWaypoints: wps };
      }));
      return;
    }

    // Phase 2: dragging a transition endpoint. Only X moves (clamped to the
    // corresponding area's x_min..x_max); Y is fixed by the area.
    if (draggingTransitionEndpoint && canvasRef.current) {
      const rect = canvasRef.current.getBoundingClientRect();
      const mouseX = e.clientX - rect.left;
      const vecX = Math.round((mouseX / rect.width) * (192 * widthScreens) + worldXMin);
      const { enemyId, transIdx, endpoint } = draggingTransitionEndpoint;
      setObjects(prev => prev.map(o => {
        if (o.id !== enemyId) return o;
        const explicit = (o as any).walkable_areas as
          | { y: number; x_min: number; x_max: number }[]
          | undefined;
        const wps2 = o.patrolWaypoints ?? [];
        const areas = explicit && explicit.length > 0
          ? explicit
          : wps2.length > 0
            ? [{
                y: o.y,
                x_min: Math.min(...wps2.map(w => w.x)),
                x_max: Math.max(...wps2.map(w => w.x)),
              }]
            : [];
        const transitions = ((o as any).transitions as
          | { from: number; to: number; type: 'jump_up' | 'drop'; from_x?: number; to_x?: number }[]
          | undefined) ?? [];
        if (transIdx >= transitions.length) return o;
        const t = transitions[transIdx];
        const areaIdx = endpoint === 'from' ? t.from : t.to;
        if (areaIdx >= areas.length) return o;
        const a = areas[areaIdx];
        const clamped = Math.max(a.x_min, Math.min(a.x_max, vecX));
        const next = [...transitions];
        next[transIdx] = endpoint === 'from'
          ? { ...t, from_x: clamped }
          : { ...t, to_x: clamped };
        return { ...o, transitions: next } as any;
      }));
      return;
    }

    // Level-wide transition endpoint drag — same logic as the per-enemy one
    // but writes to levelTransitions and clamps to the level area's range.
    if (draggingLevelTransitionEndpoint && canvasRef.current) {
      const rect = canvasRef.current.getBoundingClientRect();
      const mouseX = e.clientX - rect.left;
      const vecX = Math.round((mouseX / rect.width) * (192 * widthScreens) + worldXMin);
      const { transIdx, endpoint } = draggingLevelTransitionEndpoint;
      setLevelTransitions(prev => {
        if (transIdx >= prev.length) return prev;
        const t = prev[transIdx];
        const areaIdx = endpoint === 'from' ? t.from : t.to;
        if (areaIdx >= levelWalkableAreas.length) return prev;
        const a = levelWalkableAreas[areaIdx];
        const clamped = Math.max(a.x_min, Math.min(a.x_max, vecX));
        const next = [...prev];
        next[transIdx] = endpoint === 'from'
          ? { ...t, from_x: clamped }
          : { ...t, to_x: clamped };
        return next;
      });
      return;
    }

    if (draggingVelocity) {
      handleVelocityArrowDrag(e);
      return;
    }

    // Rubber band selection
    if (rubberBandStartRef.current && !draggingObjectId && canvasRef.current) {
      const rect = canvasRef.current.getBoundingClientRect();
      const svgX = ((e.clientX - rect.left) / rect.width) * (192 * widthScreens);
      const svgY = ((e.clientY - rect.top) / rect.height) * (256 * heightScreens);
      const { svgX: sx, svgY: sy } = rubberBandStartRef.current;
      if (Math.abs(svgX - sx) > 2 || Math.abs(svgY - sy) > 2) {
        setRubberBand({ svgX1: sx, svgY1: sy, svgX2: svgX, svgY2: svgY });
      }
      return;
    }

    if (!draggingObjectId || !canvasRef.current) return;

    const rect = canvasRef.current.getBoundingClientRect();
    const mouseX = e.clientX - rect.left;
    const mouseY = e.clientY - rect.top;

    const vecX = Math.round((mouseX / rect.width) * (192 * widthScreens) + worldXMin);
    const vecY = Math.round(worldYMax - (mouseY / rect.height) * (256 * heightScreens));

    // Multi-object drag: apply same delta to all selected objects
    if (dragStartVecRef.current && dragInitialPositionsRef.current.size > 1) {
      const dx = vecX - dragStartVecRef.current.x;
      const dy = vecY - dragStartVecRef.current.y;
      setObjects(objects.map(obj => {
        const init = dragInitialPositionsRef.current.get(obj.id);
        return init ? { ...obj, x: init.x + dx, y: init.y + dy } : obj;
      }));
      return;
    }

    // Single-object drag (original behaviour)
    if (!dragOffset) return;
    setObjects(objects.map(obj =>
      obj.id === draggingObjectId
        ? { ...obj, x: vecX - dragOffset.x, y: vecY - dragOffset.y }
        : obj
    ));
  };

  const handleCanvasMouseUp = () => {
    // Walkable-area draw mode: commit the dragged geometry to the target area
    // and exit draw mode. If the user only clicked (no drag), x_min == x_max
    // and we still commit — they can drag the input boxes later to widen.
    if (drawingLevelAreaIdx !== null && drawingPreview) {
      const idx = drawingLevelAreaIdx;
      const p = drawingPreview;
      setLevelWalkableAreas(prev => prev.map((a, i) => i === idx ? { y: p.y, x_min: p.x_min, x_max: p.x_max } : a));
      setDrawingLevelAreaIdx(null);
      setDrawingPreview(null);
      drawingStartXRef.current = null;
    }
    isPanningRef.current = false;
    setIsPanning(false);
    setDraggingObjectId(null);
    setDragOffset(null);
    setDraggingVelocity(false);
    setDraggingHotspotId(null);
    setHotspotDragOffset(null);
    setDraggingLimit(null);
    setDraggingWaypointInfo(null);
    setDraggingTransitionEndpoint(null);
    setDraggingLevelTransitionEndpoint(null);
    dragStartVecRef.current = null;

    // Finalize rubber band selection
    if (rubberBand) {
      const x1 = Math.min(rubberBand.svgX1, rubberBand.svgX2);
      const x2 = Math.max(rubberBand.svgX1, rubberBand.svgX2);
      const y1 = Math.min(rubberBand.svgY1, rubberBand.svgY2);
      const y2 = Math.max(rubberBand.svgY1, rubberBand.svgY2);
      const inside = objects.filter(obj => {
        const s = vecToSvg(obj.x, obj.y);
        return s.x >= x1 && s.x <= x2 && s.y >= y1 && s.y <= y2;
      });
      if (inside.length > 0) {
        setSelectedIds(new Set(inside.map(o => o.id)));
        setSelectedId(inside[inside.length - 1].id);
        suppressNextClickRef.current = true;
      }
      setRubberBand(null);
    }
    rubberBandStartRef.current = null;
  };

  // Convert Vectrex coordinates to SVG viewport coordinates
  const vecToSvg = (x: number, y: number) => {
    return {
      x: x - worldXMin,
      y: worldYMax - y,
    };
  };

  // Canvas click — create hotspot or deselect
  const handleCanvasClick = (e: React.MouseEvent<SVGSVGElement>) => {
    if (suppressNextClickRef.current) {
      suppressNextClickRef.current = false;
      return;
    }
    const target = e.target as SVGElement;
    const tag = target.tagName.toLowerCase();

    const svgRect = (e.currentTarget as SVGSVGElement).getBoundingClientRect();
    const mouseX = e.clientX - svgRect.left;
    const mouseY = e.clientY - svgRect.top;
    const vecX = Math.round((mouseX / svgRect.width) * (192 * widthScreens) + worldXMin);
    const vecY = Math.round(worldYMax - (mouseY / svgRect.height) * (256 * heightScreens));

    if (activeTool === 'hotspot') {
      if (tag !== 'svg' && tag !== 'rect') return;

      const newHotspot: VPlayHotspot = {
        id: `hs_${Date.now()}`,
        x: vecX,
        y: vecY,
        w: 20,
        h: 20,
        trigger: 'player_near',
        label: 'hotspot',
      };

      setHotspots(prev => [...prev, newHotspot]);
      setSelectedHotspotId(newHotspot.id);
      setSelectedId(null);
    } else if (activeTool === 'enemy') {
      if (tag !== 'svg' && tag !== 'rect') return;

      const newEnemy: SceneObject = {
        id: `enemy_${Date.now()}`,
        type: 'enemy',
        vectorName: '',
        layer: 'gameplay',
        x: vecX,
        y: vecY,
        rotation: 0,
        scale: 1,
        enemyType: selectedEnemyType || '',
        aiType: 'patrol',
        patrolWaypoints: [],
        wave: 0,
        respawn: false,
      };

      setObjects(prev => [...prev, newEnemy]);
      setSelectedId(newEnemy.id);
      setSelectedIds(new Set([newEnemy.id]));
      setSelectedHotspotId(null);
    } else if (activeTool === 'patrol') {
      // Add a waypoint to the selected enemy's patrol path
      const sel = objects.find(o => o.id === selectedId && o.type === 'enemy');
      if (!sel) return;
      const updated: SceneObject = {
        ...sel,
        patrolWaypoints: [...(sel.patrolWaypoints || []), { x: vecX, y: vecY }],
      };
      setObjects(prev => prev.map(o => o.id === selectedId ? updated : o));
    } else {
      // Select tool — clicking canvas background deselects everything
      if (tag === 'svg' || tag === 'rect') {
        setSelectedId(null);
        setSelectedIds(new Set());
        setSelectedHotspotId(null);
        setSelectedLimit(null);
      }
    }
  };

  // Render a hotspot zone on the SVG canvas
  const renderHotspot = (hs: VPlayHotspot) => {
    const svgPos = vecToSvg(hs.x, hs.y);
    const isSelected = selectedHotspotId === hs.id;
    const color = isSelected ? '#ffaa00' : '#ffaa0088';
    const fillColor = isSelected ? '#ffaa0030' : '#ffaa0015';

    const handleMouseDown = (e: React.MouseEvent) => {
      e.stopPropagation();
      setSelectedHotspotId(hs.id);
      setSelectedId(null);
      setSelectedIds(new Set());

      const rect = canvasRef.current?.getBoundingClientRect();
      if (!rect) return;
      const mouseX = e.clientX - rect.left;
      const mouseY = e.clientY - rect.top;
      const vecX = Math.round((mouseX / rect.width) * (192 * widthScreens) + worldXMin);
      const vecY = Math.round(worldYMax - (mouseY / rect.height) * (256 * heightScreens));
      setDraggingHotspotId(hs.id);
      setHotspotDragOffset({ x: vecX - hs.x, y: vecY - hs.y });
    };

    return (
      <g key={hs.id} onMouseDown={handleMouseDown} style={{ cursor: 'move' }}>
        <rect
          x={svgPos.x - hs.w}
          y={svgPos.y - hs.h}
          width={hs.w * 2}
          height={hs.h * 2}
          fill={fillColor}
          stroke={color}
          strokeWidth={isSelected ? 1.5 : 1}
          strokeDasharray="4 2"
        />
        <text
          x={svgPos.x}
          y={svgPos.y - hs.h - 3}
          fill={color}
          fontSize="7"
          textAnchor="middle"
          style={{ userSelect: 'none', pointerEvents: 'none' }}
        >
          {hs.label}
        </text>
        <text
          x={svgPos.x}
          y={svgPos.y + 4}
          fill={color}
          fontSize="5"
          textAnchor="middle"
          style={{ userSelect: 'none', pointerEvents: 'none' }}
        >
          {hs.trigger}
        </text>
      </g>
    );
  };

  // Render scroll limit guide lines on the SVG canvas
  const renderScrollLimitLines = () => {
    const svgW = 192 * widthScreens;
    const svgH = 256 * heightScreens;

    const limitDefs: Array<{
      key: 'left' | 'right' | 'top' | 'bottom';
      label: string;
      color: string;
    }> = [
      { key: 'left',   label: 'L', color: '#00FFFF' },
      { key: 'right',  label: 'R', color: '#00FFFF' },
      { key: 'top',    label: 'T', color: '#FF00FF' },
      { key: 'bottom', label: 'B', color: '#FF00FF' },
    ];

    return limitDefs.map(({ key, label, color }) => {
      const val = scrollLimits[key];
      if (val === undefined) return null;

      const isSelected = selectedLimit === key;
      const strokeW = isSelected ? 1.5 : 1;
      const opacity = isSelected ? 1.0 : 0.75;

      const isVertical = key === 'left' || key === 'right';
      let x1: number, y1: number, x2: number, y2: number;
      let labelX: number, labelY: number;

      if (isVertical) {
        const svgX = val - worldXMin;
        x1 = svgX; y1 = 0; x2 = svgX; y2 = svgH;
        labelX = svgX + 3;
        labelY = 14;
      } else {
        const svgY = worldYMax - val;
        x1 = 0; y1 = svgY; x2 = svgW; y2 = svgY;
        labelX = 4;
        labelY = svgY - 3;
      }

      // Hit-target line (wider, invisible) for easier grabbing
      const hitProps = isVertical
        ? { x1, y1, x2, y2, strokeWidth: 12, stroke: 'transparent' }
        : { x1, y1, x2, y2, strokeWidth: 12, stroke: 'transparent' };

      return (
        <g
          key={`scroll-limit-${key}`}
          style={{ cursor: isVertical ? 'ew-resize' : 'ns-resize' }}
          onMouseDown={(e) => {
            e.stopPropagation();
            setDraggingLimit(key);
            setSelectedLimit(key);
            setSelectedId(null);
            setSelectedIds(new Set());
            setSelectedHotspotId(null);
          }}
        >
          {/* Wide transparent hit target */}
          <line {...hitProps} />
          {/* Visible dashed line */}
          <line
            x1={x1} y1={y1} x2={x2} y2={y2}
            stroke={color}
            strokeWidth={strokeW}
            strokeDasharray="6 3"
            opacity={opacity}
          />
          {/* Label */}
          <text
            x={labelX}
            y={labelY}
            fill={color}
            fontSize="7"
            fontFamily="monospace"
            opacity={opacity}
            style={{ userSelect: 'none', pointerEvents: 'none' }}
          >
            {label}:{val}
          </text>
        </g>
      );
    });
  };

  // Render a vector sprite from loaded .vec data
  const renderVector = (obj: SceneObject) => {
    // Enemy objects: try to render their sprite vector, fall back to diamond marker
    if (obj.type === 'enemy') {
      const svgPos = vecToSvg(obj.x, obj.y);
      const isSelected = selectedIds.has(obj.id);
      const label = (obj as any).enemyType || 'enemy';
      const color = isSelected ? '#ff44ff' : '#cc00cc';
      const enemyVecName = enemyTypeVectorMap.get((obj as any).enemyType || '');
      const vecData = enemyVecName ? loadedVectors.get(enemyVecName) : null;

      if (vecData) {
        // Mirror horizontally when patrolling against the default facing direction
        const facingRight = obj._facingRight ?? (obj.defaultFacing !== 'left');
        const defaultRight = obj.defaultFacing !== 'left';
        const shouldMirror = obj.mirrorOnPatrol && (facingRight !== defaultRight);
        const scaleX = shouldMirror ? -obj.scale : obj.scale;
        return (
          <g
            key={obj.id}
            transform={`translate(${svgPos.x}, ${svgPos.y}) scale(${scaleX}, ${obj.scale}) rotate(${obj.rotation})`}
            onMouseDown={(e) => handleObjectMouseDown(e, obj.id)}
            style={{ cursor: draggingObjectId === obj.id ? 'grabbing' : 'grab' }}
          >
            {vecData.layers.map((layer: any, li: number) => {
              if (!layer.visible) return null;
              return layer.paths.map((path: any, pi: number) => {
                const points = path.points.map((p: any) => `${p.x},${-p.y}`).join(' ');
                const opacity = 0.5 + (path.intensity / 255) * 0.5;
                const Tag = path.closed ? 'polygon' : 'polyline';
                return (
                  <Tag
                    key={`${li}-${pi}`}
                    points={points}
                    fill="none"
                    stroke={color}
                    strokeWidth={isSelected ? 1.5 / obj.scale : 1 / obj.scale}
                    opacity={opacity}
                  />
                );
              });
            })}
            <text
              x="0" y={14 / obj.scale}
              textAnchor="middle"
              fontSize={8 / obj.scale}
              fill={color}
              style={{ pointerEvents: 'none', userSelect: 'none' }}
            >
              {label}
            </text>
          </g>
        );
      }

      // Fallback diamond placeholder when no vector is found
      return (
        <g
          key={obj.id}
          transform={`translate(${svgPos.x}, ${svgPos.y})`}
          onMouseDown={(e) => handleObjectMouseDown(e, obj.id)}
          style={{ cursor: draggingObjectId === obj.id ? 'grabbing' : 'grab' }}
        >
          <polygon
            points="0,-10 10,0 0,10 -10,0"
            fill={isSelected ? '#440044' : '#220022'}
            stroke={color}
            strokeWidth={isSelected ? 2 : 1.5}
            opacity={0.9}
          />
          <text
            x="0" y="18"
            textAnchor="middle"
            fontSize="8"
            fill={color}
            style={{ pointerEvents: 'none', userSelect: 'none' }}
          >
            {label}
          </text>
        </g>
      );
    }

    const vecData = loadedVectors.get(obj.vectorName);
    if (!vecData) return null;

    const svgPos = vecToSvg(obj.x, obj.y);
    const isSelected = selectedIds.has(obj.id);

    return (
      <g
        key={obj.id}
        transform={`translate(${svgPos.x}, ${svgPos.y}) scale(${obj.scale}) rotate(${obj.rotation})`}
        onMouseDown={(e) => handleObjectMouseDown(e, obj.id)}
        style={{ cursor: draggingObjectId === obj.id ? 'grabbing' : 'grab' }}
      >
        {vecData.layers.map((layer, layerIdx) => {
          if (!layer.visible) return null;
          
          return layer.paths.map((path, pathIdx) => {
            const points = path.points.map(p => `${p.x},${-p.y}`).join(' ');
            // Map intensity to opacity with a minimum floor so dim vecs stay visible
            const opacity = 0.5 + (path.intensity / 255) * 0.5;
            // Color coding: green=selected, blue=collidable, cyan=non-collidable
            let color = '#00ffff'; // default cyan (non-collidable)
            if (isSelected) {
              color = '#00ff00'; // bright green when selected
            } else if (obj.collidable === true) {
              color = '#6699ff'; // blue for collidable
            }

            if (path.closed) {
              // Closed polygon
              return (
                <polygon
                  key={`${layerIdx}-${pathIdx}`}
                  points={points}
                  fill="none"
                  stroke={color}
                  strokeWidth="1.5"
                  opacity={opacity}
                />
              );
            } else {
              // Open polyline
              return (
                <polyline
                  key={`${layerIdx}-${pathIdx}`}
                  points={points}
                  fill="none"
                  stroke={color}
                  strokeWidth="1.5"
                  opacity={opacity}
                />
              );
            }
          });
        })}
        
        {/* Selection indicator */}
        {isSelected && (
          <circle cx="0" cy="0" r="3" fill="#00ff00" opacity="0.5" />
        )}
        
        {/* Collision indicator */}
        {obj.collidable && !isSelected && (
          <rect x="-2" y="-2" width="4" height="4" fill="#4080ff" opacity="0.6" />
        )}
        
        {/* Velocity arrow */}
        {isSelected && editingVelocity && obj.velocity && (
          <g
            onMouseDown={handleVelocityArrowMouseDown}
            style={{ cursor: 'move' }}
          >
            <line
              x1="0"
              y1="0"
              x2={(obj.velocity.x || 0) * 3}
              y2={-(obj.velocity.y || 0) * 3}
              stroke="#ff8000"
              strokeWidth="2"
              markerEnd="url(#arrowhead)"
            />
            <circle cx="0" cy="0" r="4" fill="#ff8000" opacity="0.8" />
            {/* Draggable end point */}
            <circle
              cx={(obj.velocity.x || 0) * 3}
              cy={-(obj.velocity.y || 0) * 3}
              r="6"
              fill="#ff8000"
              stroke="#fff"
              strokeWidth="1"
              opacity="0.9"
              style={{ cursor: 'move' }}
            />
          </g>
        )}
      </g>
    );
  };

  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      height: '100%',
      width: '100%',
      overflow: 'hidden',
      backgroundColor: '#1e1e1e',
      color: '#d4d4d4',
    }}>
      {/* Toolbar */}
      <div style={{
        padding: '8px',
        borderBottom: '1px solid #3e3e3e',
        display: 'flex',
        gap: '8px',
        alignItems: 'center',
      }}>
        <span style={{ fontSize: '14px', fontWeight: 600 }}>
          🎮 Playground
        </span>
        {!isPlaying ? (
          <button
            onClick={() => {
              setSavedScene(JSON.parse(JSON.stringify(objects)));
              enemyPatrolIdxRef.current.clear();
              enemyWanderStateRef.current.clear();
              setIsPlaying(true);
            }}
            style={{
              padding: '4px 12px',
              backgroundColor: '#40a040',
              border: '1px solid #50b050',
              borderRadius: '4px',
              color: '#fff',
              cursor: 'pointer',
              fontWeight: 600,
            }}
          >
            ▶ Play
          </button>
        ) : (
          <button
            onClick={() => {
              setIsPlaying(false);
              if (savedScene) {
                setObjects(savedScene);
                setSavedScene(null);
              }
            }}
            style={{
              padding: '4px 12px',
              backgroundColor: '#c04040',
              border: '1px solid #d05050',
              borderRadius: '4px',
              color: '#fff',
              cursor: 'pointer',
              fontWeight: 600,
            }}
          >
            ⏹ Stop
          </button>
        )}
        <div style={{ borderLeft: '1px solid #555', height: '24px', margin: '0 4px' }} />
        <button
          onClick={() => { setActiveTool('select'); }}
          title="Select / Move objects"
          style={{
            padding: '4px 10px',
            background: activeTool === 'select' ? '#005500' : '#2a2a2a',
            color: activeTool === 'select' ? '#00ff00' : '#aaa',
            border: `1px solid ${activeTool === 'select' ? '#00ff00' : '#555'}`,
            cursor: 'pointer',
            fontSize: '12px',
          }}
        >
          SELECT
        </button>
        <button
          onClick={() => { setActiveTool('hotspot'); }}
          title="Place hotspot zones"
          style={{
            padding: '4px 10px',
            background: activeTool === 'hotspot' ? '#554400' : '#2a2a2a',
            color: activeTool === 'hotspot' ? '#ffaa00' : '#aaa',
            border: `1px solid ${activeTool === 'hotspot' ? '#ffaa00' : '#555'}`,
            cursor: 'pointer',
            fontSize: '12px',
          }}
        >
          HOTSPOT
        </button>
        <button
          onClick={() => { setActiveTool('enemy'); }}
          title="Place enemy instances (click canvas)"
          style={{
            padding: '4px 10px',
            background: activeTool === 'enemy' ? '#440044' : '#2a2a2a',
            color: activeTool === 'enemy' ? '#ff44ff' : '#aaa',
            border: `1px solid ${activeTool === 'enemy' ? '#ff44ff' : '#555'}`,
            cursor: 'pointer',
            fontSize: '12px',
          }}
        >
          ENEMY
        </button>
        <button
          onClick={() => {
            const sel = objects.find(o => o.id === selectedId && o.type === 'enemy');
            if (!sel) return;
            setActiveTool('patrol');
          }}
          title="Add patrol waypoints to selected enemy"
          disabled={!objects.find(o => o.id === selectedId && o.type === 'enemy')}
          style={{
            padding: '4px 10px',
            background: activeTool === 'patrol' ? '#004444' : '#2a2a2a',
            color: activeTool === 'patrol' ? '#44ffff' : (objects.find(o => o.id === selectedId && o.type === 'enemy') ? '#aaa' : '#555'),
            border: `1px solid ${activeTool === 'patrol' ? '#44ffff' : '#555'}`,
            cursor: objects.find(o => o.id === selectedId && o.type === 'enemy') ? 'pointer' : 'not-allowed',
            fontSize: '12px',
          }}
        >
          PATROL
        </button>
        <div style={{ borderLeft: '1px solid #555', height: '24px', margin: '0 4px' }} />
        {/* Scroll limit toggle buttons */}
        <span style={{ fontSize: '10px', color: '#888', marginRight: '2px' }}>SCROLL:</span>
        {(['left', 'right', 'top', 'bottom'] as const).map(side => {
          const labels: Record<string, string> = { left: 'L', right: 'R', top: 'T', bottom: 'B' };
          const cyanlimits = side === 'left' || side === 'right';
          const activeColor = cyanlimits ? '#00FFFF' : '#FF00FF';
          const activeBg = cyanlimits ? '#003333' : '#330033';
          const present = scrollLimits[side] !== undefined;
          return (
            <button
              key={side}
              title={present ? `Remove ${side} scroll limit` : `Add ${side} scroll limit`}
              onClick={() => {
                if (present) {
                  setScrollLimits(prev => {
                    const next = { ...prev };
                    delete next[side];
                    return next;
                  });
                  if (selectedLimit === side) setSelectedLimit(null);
                } else {
                  // Default position: world centre for each axis
                  const defaultVal = side === 'left' ? worldXMin
                    : side === 'right' ? worldXMax
                    : side === 'top' ? worldYMax
                    : worldYMin;
                  setScrollLimits(prev => ({ ...prev, [side]: defaultVal }));
                  setSelectedLimit(side);
                }
              }}
              style={{
                padding: '3px 7px',
                background: present ? activeBg : '#2a2a2a',
                color: present ? activeColor : '#666',
                border: `1px solid ${present ? activeColor : '#444'}`,
                cursor: 'pointer',
                fontSize: '11px',
                fontFamily: 'monospace',
                minWidth: '24px',
              }}
            >
              {labels[side]}
            </button>
          );
        })}
        {/* Inline coordinate input when a limit is selected */}
        {selectedLimit && scrollLimits[selectedLimit] !== undefined && (
          <input
            type="number"
            value={scrollLimits[selectedLimit] as number}
            onChange={e => {
              const v = parseInt(e.target.value) || 0;
              const clamped = (selectedLimit === 'left' || selectedLimit === 'right')
                ? Math.max(worldXMin, Math.min(worldXMax, v))
                : Math.max(worldYMin, Math.min(worldYMax, v));
              setScrollLimits(prev => ({ ...prev, [selectedLimit]: clamped }));
            }}
            style={{
              width: 52,
              background: '#1a1a1a',
              color: (selectedLimit === 'left' || selectedLimit === 'right') ? '#00FFFF' : '#FF00FF',
              border: `1px solid ${(selectedLimit === 'left' || selectedLimit === 'right') ? '#00FFFF' : '#FF00FF'}`,
              borderRadius: 3,
              padding: '2px 4px',
              fontSize: 11,
            }}
          />
        )}
        <div style={{ borderLeft: '1px solid #555', height: '24px', margin: '0 4px' }} />
        <button
          onClick={() => setEditingVelocity(!editingVelocity)}
          style={{
            padding: '4px 12px',
            backgroundColor: editingVelocity ? '#6060a0' : '#333',
            border: '1px solid ' + (editingVelocity ? '#7070b0' : '#555'),
            borderRadius: '4px',
            color: '#fff',
            cursor: 'pointer',
            fontSize: '11px',
          }}
        >
          {editingVelocity ? '🎯 Editing Velocity' : '➡ Set Velocity'}
        </button>
        <div style={{ borderLeft: '1px solid #555', height: '24px', margin: '0 4px' }} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
          <span style={{ color: '#888', fontSize: 11 }}>W</span>
          <input
            type="number"
            min={1}
            max={8}
            value={widthScreens}
            onChange={e => setWidthScreens(Math.max(1, Math.min(8, parseInt(e.target.value) || 1)))}
            style={{ width: 36, background: '#1a1a1a', color: '#ccc', border: '1px solid #444', borderRadius: 3, padding: '2px 4px', fontSize: 11 }}
          />
          <span style={{ color: '#888', fontSize: 11 }}>H</span>
          <input
            type="number"
            min={1}
            max={8}
            value={heightScreens}
            onChange={e => setHeightScreens(Math.max(1, Math.min(8, parseInt(e.target.value) || 1)))}
            style={{ width: 36, background: '#1a1a1a', color: '#ccc', border: '1px solid #444', borderRadius: 3, padding: '2px 4px', fontSize: 11 }}
          />
          <span style={{ color: '#555', fontSize: 10 }}>screens</span>
        </div>
        <div style={{ flex: 1 }} />
        <button
          onClick={() => {
            // Quick save: if we already have a name, save directly
            if (sceneName.trim()) {
              handleSaveScene();
            } else {
              // No name yet, open modal to ask for it
              setModalMode('save');
              setShowSaveLoadModal(true);
            }
          }}
          style={{
            padding: '4px 12px',
            backgroundColor: '#333',
            border: '1px solid #555',
            borderRadius: '4px',
            color: '#d4d4d4',
            cursor: 'pointer',
            fontSize: '11px',
          }}
        >
          💾 Save
        </button>
        <button
          onClick={() => {
            setModalMode('load');
            setShowSaveLoadModal(true);
          }}
          style={{
            padding: '4px 12px',
            backgroundColor: '#333',
            border: '1px solid #555',
            borderRadius: '4px',
            color: '#d4d4d4',
            cursor: 'pointer',
            fontSize: '11px',
          }}
        >
          📁 Load
        </button>
        <button
          onClick={() => {
            setObjects([]);
            setSelectedId(null);
            setSelectedIds(new Set());
            setHotspots([]);
            setSelectedHotspotId(null);
            setScrollLimits({});
            setSelectedLimit(null);
            setScreenBackgrounds([]);
            setLevelWalkableAreas([]);
            setLevelTransitions([]);
          }}
          style={{
            padding: '4px 12px',
            backgroundColor: '#333',
            border: '1px solid #555',
            borderRadius: '4px',
            color: '#d4d4d4',
            cursor: 'pointer',
            fontSize: '11px',
          }}
        >
          🗑️ Clear
        </button>
      </div>

      <div style={{ display: 'flex', flex: 1, overflow: 'hidden', minHeight: 0 }}>
        {/* Asset Palette */}
        <div style={{
          width: '200px',
          flexShrink: 0,
          borderRight: '1px solid #3e3e3e',
          display: 'flex',
          flexDirection: 'column',
          minHeight: 0,
          overflow: 'hidden',
        }}>
          <h3 style={{ fontSize: '12px', margin: '12px 12px 8px 12px', color: '#888', flexShrink: 0 }}>
            VECTORS
          </h3>
          <div style={{
            flex: 1,
            overflowY: 'auto',
            overflowX: 'hidden',
            padding: '0 12px 12px 12px',
            minHeight: 0,
          }}>
            {availableVectors.length === 0 && (
              <div style={{ fontSize: '11px', color: '#666', fontStyle: 'italic' }}>
                No .vec files found in assets/vectors/
              </div>
            )}
            {availableVectors.map(vec => (
              <div
                key={vec}
                draggable
                onDragStart={() => setDraggedVector(vec)}
                style={{
                  padding: '8px',
                  marginBottom: '4px',
                  backgroundColor: '#2d2d2d',
                  border: '1px solid #444',
                  borderRadius: '4px',
                  cursor: 'grab',
                  fontSize: '11px',
                  fontFamily: 'monospace',
                }}
              >
                📦 {vec}
              </div>
            ))}
          </div>

          {/* Enemy Types */}
          <h3 style={{ fontSize: '12px', margin: '8px 12px 6px 12px', color: '#888', flexShrink: 0 }}>
            ENEMIES
          </h3>
          <div style={{ padding: '0 12px 12px', flexShrink: 0 }}>
            {availableEnemies.length === 0 ? (
              <div style={{ fontSize: '11px', color: '#666', fontStyle: 'italic' }}>
                No .venemy files found
              </div>
            ) : (
              availableEnemies.map(enemy => (
                <div
                  key={enemy}
                  onClick={() => { setSelectedEnemyType(enemy); setActiveTool('enemy'); }}
                  style={{
                    padding: '6px 8px',
                    marginBottom: '4px',
                    backgroundColor: selectedEnemyType === enemy && activeTool === 'enemy' ? '#440044' : '#2d2d2d',
                    border: `1px solid ${selectedEnemyType === enemy && activeTool === 'enemy' ? '#ff44ff' : '#444'}`,
                    borderRadius: '4px',
                    cursor: 'pointer',
                    fontSize: '11px',
                    fontFamily: 'monospace',
                    color: selectedEnemyType === enemy && activeTool === 'enemy' ? '#ff44ff' : '#d4d4d4',
                  }}
                >
                  👾 {enemy}
                </div>
              ))
            )}
          </div>

          {/* Floor ground Y reference */}
          <h3 style={{ fontSize: '12px', margin: '8px 12px 6px 12px', color: '#888', flexShrink: 0 }}>
            FLOOR GROUND Y
          </h3>
          <div style={{ padding: '0 12px 8px', flexShrink: 0 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 4, marginBottom: 6 }}>
              <span style={{ fontSize: '10px', color: '#666', fontFamily: 'monospace', whiteSpace: 'nowrap' }}>
                offset desde abajo
              </span>
              <input
                type="number"
                min={0}
                max={255}
                value={groundBottomOffset}
                onChange={e => setGroundBottomOffset(Math.max(0, Math.min(255, parseInt(e.target.value) || 0)))}
                style={{
                  width: 44, background: '#1a1a1a', color: '#e8a030',
                  border: '1px solid #e8a03066', borderRadius: 3,
                  padding: '2px 4px', fontSize: '11px', fontFamily: 'monospace',
                }}
              />
            </div>
            {Array.from({ length: heightScreens }, (_, i) => {
              const f = heightScreens - i; // S1=bottom, SN=top (matches screen labels)
              const groundY = worldYMin + (f - 1) * 256 + groundBottomOffset;
              return (
                <div key={f} style={{
                  display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                  padding: '2px 4px', marginBottom: 1,
                  background: '#1e1e1e', borderRadius: 2,
                  fontSize: '10px', fontFamily: 'monospace',
                }}>
                  <span style={{ color: '#556655' }}>S{f}</span>
                  <input
                    readOnly
                    value={`Y = ${groundY}`}
                    style={{
                      background: 'transparent', border: 'none', outline: 'none',
                      color: '#e8a030', fontSize: '10px', fontFamily: 'monospace',
                      textAlign: 'right', width: 80, cursor: 'default',
                    }}
                    onClick={e => (e.target as HTMLInputElement).select()}
                  />
                </div>
              );
            })}
          </div>
        </div>

        {/* Canvas Area */}
        <div ref={containerRef} style={{
          flex: 1,
          overflow: 'auto',
          padding: '20px',
          minWidth: 0,
          minHeight: 0,
        }} onScroll={() => {
          if (!containerRef.current || !sceneName) return;
          localStorage.setItem('playground_scroll_' + sceneName, JSON.stringify({
            top: containerRef.current.scrollTop,
            left: containerRef.current.scrollLeft,
          }));
        }}>
          <div style={{ width: 'fit-content' }}>
            <svg
              ref={canvasRef}
              onDrop={handleDrop}
              onDragOver={handleDragOver}
              onMouseMove={handleCanvasMouseMove}
              onMouseUp={handleCanvasMouseUp}
              onMouseLeave={handleCanvasMouseUp}
              onMouseDown={handleCanvasMouseDown}
              onClick={handleCanvasClick}
              viewBox={`0 0 ${192 * widthScreens} ${256 * heightScreens}`}
              style={{
                width: `${192 * widthScreens * SVG_SCALE}px`,
                height: `${256 * heightScreens * SVG_SCALE}px`,
                display: 'block',
                backgroundColor: '#000',
                border: `2px solid ${activeTool === 'hotspot' ? '#ffaa00' : activeTool === 'enemy' ? '#ff44ff' : activeTool === 'patrol' ? '#44ffff' : '#00ff00'}`,
                cursor: isPanning ? 'grabbing' : (drawingLevelAreaIdx !== null || activeTool === 'hotspot' || activeTool === 'enemy' || activeTool === 'patrol') ? 'crosshair' : 'default',
              }}
            >
            {/* Grid */}
            <defs>
              <pattern id="grid" width="32" height="32" patternUnits="userSpaceOnUse">
                <path d="M 32 0 L 0 0 0 32" fill="none" stroke="#1a3319" strokeWidth="0.5" />
              </pattern>
              <marker id="arrowhead" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto">
                <polygon points="0 0, 10 3, 0 6" fill="#ff8000" />
              </marker>
            </defs>
            <rect width={192 * widthScreens} height={256 * heightScreens} fill="url(#grid)" />

            {/* Axes through Vectrex origin (0,0) */}
            <line x1="0" y1={worldYMax} x2={192 * widthScreens} y2={worldYMax} stroke="#00ff0040" strokeWidth="1" />
            <line x1={-worldXMin} y1="0" x2={-worldXMin} y2={256 * heightScreens} stroke="#00ff0040" strokeWidth="1" />

            {/* Origin marker */}
            <circle cx={-worldXMin} cy={worldYMax} r="3" fill="#00ff00" opacity="0.5" />

            {/* Screen boundary lines */}
            {Array.from({ length: widthScreens - 1 }, (_, i) => (
              <line key={`vb-${i}`} x1={(i + 1) * 192} y1={0} x2={(i + 1) * 192} y2={256 * heightScreens}
                stroke="#334433" strokeWidth="1" strokeDasharray="4 4" />
            ))}
            {Array.from({ length: heightScreens - 1 }, (_, i) => (
              <line key={`hb-${i}`} x1={0} y1={(i + 1) * 256} x2={192 * widthScreens} y2={(i + 1) * 256}
                stroke="#334433" strokeWidth="1" strokeDasharray="4 4" />
            ))}

            {/* Floor ground lines — svgY = svgI*256 + (255 - groundBottomOffset) */}
            {Array.from({ length: heightScreens }, (_, svgI) => {
              const groundSvgY = svgI * 256 + (255 - groundBottomOffset);
              const floorNum = heightScreens - svgI;
              const groundWorldY = worldYMin + (floorNum - 1) * 256 + groundBottomOffset;
              return (
                <g key={`gnd-${svgI}`}>
                  <line x1={0} y1={groundSvgY} x2={192 * widthScreens} y2={groundSvgY}
                    stroke="#e8a030" strokeWidth="0.75" strokeOpacity="0.4" strokeDasharray="8 4" />
                  <text x={192 * widthScreens - 2} y={groundSvgY - 2}
                    fill="#e8a030" fontSize="6" fontFamily="monospace" textAnchor="end" opacity="0.55">
                    {groundWorldY}
                  </text>
                </g>
              );
            })}

            {/* Screen index labels */}
            {Array.from({ length: heightScreens }, (_, svgI) => {
              const gameScreenNum = heightScreens - svgI; // S1=bottom, SN=top
              return (
                <text key={`slabel-${svgI}`} x="4" y={svgI * 256 + 10} fill="#334433" fontSize="8" fontFamily="monospace" opacity="0.7">
                  S{gameScreenNum}
                </text>
              );
            })}

            {/* Clip paths — one per screen slot so images can't overflow into adjacent floors */}
            <defs>
              {screenBackgrounds.map(sb => {
                const svgScreenIdx = heightScreens - 1 - sb.screenIndex;
                return (
                  <clipPath key={`sbgclip_${sb.screenIndex}`} id={`sbgclip_${sb.screenIndex}`}>
                    <rect x={0} y={svgScreenIdx * 256} width={192 * widthScreens} height={256} />
                  </clipPath>
                );
              })}
            </defs>

            {/* Screen background image guides (editor-only) */}
            {screenBackgrounds.map(sb => {
              const dataUrl = imageDataUrls.get(sb.imagePath);
              if (!dataUrl) return null;
              const svgScreenIdx = heightScreens - 1 - sb.screenIndex;
              const offsetY = sb.offsetY ?? 0;
              return (
                <image
                  key={`sbg_${sb.screenIndex}`}
                  href={dataUrl}
                  x={0}
                  y={svgScreenIdx * 256 + offsetY}
                  width={192 * widthScreens}
                  height={256}
                  opacity={0.25}
                  preserveAspectRatio="none"
                  clipPath={`url(#sbgclip_${sb.screenIndex})`}
                  style={{ pointerEvents: 'none' }}
                />
              );
            })}

            {/* Collision mesh segments — shown for all collidable objects (faint), highlighted for selected */}
            {objects.filter(o => o.collidable && o.collision?.segments?.length).map(obj => {
              const isSelected = obj.id === selectedId;
              const segs = obj.collision!.segments!;
              return (
                <g key={`mesh_${obj.id}`}>
                  {segs.map((seg, i) => {
                    const p1 = vecToSvg(obj.x + seg.x1, obj.y + seg.y1);
                    const p2 = vecToSvg(obj.x + seg.x2, obj.y + seg.y2);
                    return (
                      <g key={i}>
                        <line x1={p1.x} y1={p1.y} x2={p2.x} y2={p2.y}
                          stroke={isSelected ? '#00ffff' : '#00ffff55'}
                          strokeWidth={isSelected ? 1.5 : 0.75} />
                        {isSelected && <>
                          <circle cx={p1.x} cy={p1.y} r={2} fill="#00ffff" />
                          <circle cx={p2.x} cy={p2.y} r={2} fill="#00ffff" />
                        </>}
                      </g>
                    );
                  })}
                </g>
              );
            })}

            {/* Render hotspots below objects */}
            {hotspots.map(hs => renderHotspot(hs))}

            {/* Patrol paths / walkable areas for enemy objects */}
            {objects.filter(o => o.type === 'enemy' && (
              (o.patrolWaypoints && o.patrolWaypoints.length > 0)
              || ((o as any).walkable_areas && (o as any).walkable_areas.length > 0)
            )).map(obj => {
              const wps = obj.patrolWaypoints ?? [];
              const isSelected = selectedIds.has(obj.id);
              const isWander = (obj as any).aiType === 'wander';

              // Wander: render all walkable areas as horizontal bars and any
              // transitions as curved arrows between area centers. Falls back
              // to a single area derived from the waypoint X-range if no
              // explicit `walkable_areas` is defined on the enemy.
              if (isWander) {
                const explicitAreas = (obj as any).walkable_areas as
                  | { y: number; x_min: number; x_max: number }[]
                  | undefined;
                const explicitTransitions = (obj as any).transitions as
                  | { from: number; to: number; type: 'jump_up' | 'drop' }[]
                  | undefined;
                const inheritsAreas = explicitAreas === undefined;
                // Inheritance: enemy override > level > .vec-collected > waypoints.
                const vecCollected = inheritsAreas && levelWalkableAreas.length === 0
                  ? collectVecWalkableAreas(objects, loadedVectors)
                  : [];
                const areas =
                  !inheritsAreas
                    ? explicitAreas!
                    : levelWalkableAreas.length > 0
                      ? levelWalkableAreas
                      : vecCollected.length > 0
                        ? vecCollected
                        : wps.length > 0
                          ? [{
                              y: obj.y,
                              x_min: Math.min(...wps.map(w => w.x)),
                              x_max: Math.max(...wps.map(w => w.x)),
                            }]
                          : [];
                if (areas.length === 0) return null;
                const transitions = explicitTransitions !== undefined
                  ? explicitTransitions
                  : levelTransitions.length > 0
                    ? levelTransitions
                    : deriveTransitions(areas);
                // Inherited areas render dimmer + dashed to signal they
                // come from the level (not editable from the enemy panel).
                const color = isSelected
                  ? (inheritsAreas ? '#88aacc' : '#ffaa44')
                  : (inheritsAreas ? '#88aacc44' : '#ffaa4488');
                const dashed = inheritsAreas;
                return (
                  <g key={`area_${obj.id}`}>
                    {/* Walkable-area bars */}
                    {areas.map((area, ai) => {
                      const leftSvg  = vecToSvg(area.x_min, area.y);
                      const rightSvg = vecToSvg(area.x_max, area.y);
                      const strokeDashAttr = dashed ? { strokeDasharray: '2 2' } : {};
                      return (
                        <g key={`area_${ai}`}>
                          <line x1={leftSvg.x} y1={leftSvg.y} x2={rightSvg.x} y2={rightSvg.y}
                            stroke={color} strokeWidth={isSelected ? 1.5 : 1} {...strokeDashAttr} />
                          <line x1={leftSvg.x} y1={leftSvg.y - 4} x2={leftSvg.x} y2={leftSvg.y + 4}
                            stroke={color} strokeWidth={1} />
                          <line x1={rightSvg.x} y1={rightSvg.y - 4} x2={rightSvg.x} y2={rightSvg.y + 4}
                            stroke={color} strokeWidth={1} />
                          {/* Area index label — always visible so the user can match the
                              number to the from/to dropdowns in the transition editor. */}
                          <text x={(leftSvg.x + rightSvg.x) / 2} y={leftSvg.y - 3}
                            fill={color} fontSize="7" fontFamily="monospace"
                            fontWeight={isSelected ? 700 : 500}
                            textAnchor="middle"
                            style={{ pointerEvents: 'none', paintOrder: 'stroke' }}
                            stroke="#000" strokeWidth="2.5">{ai}</text>
                          <text x={(leftSvg.x + rightSvg.x) / 2} y={leftSvg.y - 3}
                            fill={color} fontSize="7" fontFamily="monospace"
                            fontWeight={isSelected ? 700 : 500}
                            textAnchor="middle"
                            style={{ pointerEvents: 'none' }}>{ai}</text>
                        </g>
                      );
                    })}
                    {/* Transitions: curved dashed arrows from (from_x, area_from.y)
                        to (to_x, area_to.y). Both endpoints draggable when the
                        enemy is selected. */}
                    {transitions.map((t, ti) => {
                      if (t.from >= areas.length || t.to >= areas.length) return null;
                      const fromArea = areas[t.from];
                      const toArea = areas[t.to];
                      const fromX = (t as any).from_x ?? (fromArea.x_min + fromArea.x_max) / 2;
                      const toX   = (t as any).to_x   ?? (toArea.x_min   + toArea.x_max)   / 2;
                      const fromPt = vecToSvg(fromX, fromArea.y);
                      const toPt   = vecToSvg(toX,   toArea.y);
                      // Bezier control point off to one side for visible arc
                      const midX = (fromPt.x + toPt.x) / 2;
                      const midY = (fromPt.y + toPt.y) / 2;
                      const dxArrow = toPt.x - fromPt.x;
                      const dyArrow = toPt.y - fromPt.y;
                      const lenArrow = Math.sqrt(dxArrow * dxArrow + dyArrow * dyArrow) || 1;
                      const px = -dyArrow / lenArrow * 10;
                      const py =  dxArrow / lenArrow * 10;
                      const ctlX = midX + px;
                      const ctlY = midY + py;
                      const tColor = t.type === 'jump_up' ? '#88ffaa' : '#ff8866';
                      const tStroke = isSelected ? tColor : tColor + '88';
                      return (
                        <g key={`trans_${ti}`}>
                          <path
                            d={`M ${fromPt.x} ${fromPt.y} Q ${ctlX} ${ctlY} ${toPt.x} ${toPt.y}`}
                            stroke={tStroke} strokeWidth={isSelected ? 1 : 0.6}
                            strokeDasharray="2 1.5" fill="none" />
                          {/* Takeoff endpoint (from). Draggable when selected. */}
                          <circle cx={fromPt.x} cy={fromPt.y} r={isSelected ? 2.6 : 1.8}
                            fill={tStroke} stroke={isSelected ? '#ffffff' : 'none'}
                            strokeWidth={0.4}
                            style={{ cursor: isSelected ? 'grab' : 'default' }}
                            onMouseDown={isSelected ? (e) => {
                              e.stopPropagation();
                              setDraggingTransitionEndpoint({ enemyId: obj.id, transIdx: ti, endpoint: 'from' });
                            } : undefined} />
                          {/* Landing endpoint (to). Slightly larger, also draggable. */}
                          <circle cx={toPt.x} cy={toPt.y} r={isSelected ? 3 : 2}
                            fill={tStroke} stroke={isSelected ? '#ffffff' : 'none'}
                            strokeWidth={0.4}
                            style={{ cursor: isSelected ? 'grab' : 'default' }}
                            onMouseDown={isSelected ? (e) => {
                              e.stopPropagation();
                              setDraggingTransitionEndpoint({ enemyId: obj.id, transIdx: ti, endpoint: 'to' });
                            } : undefined} />
                        </g>
                      );
                    })}
                    {/* Waypoint handles (still draggable; useful for editing the
                        derived single-area case). */}
                    {wps.map((wp, i) => {
                      const pt = vecToSvg(wp.x, wp.y);
                      return (
                        <circle
                          key={`wp_${i}`}
                          cx={pt.x} cy={pt.y}
                          r={isSelected ? 4 : 2}
                          fill={color}
                          stroke={isSelected ? '#ffffff' : 'none'}
                          strokeWidth={0.5}
                          style={{ cursor: isSelected ? 'grab' : 'default' }}
                          onMouseDown={isSelected ? (e) => {
                            e.stopPropagation();
                            setDraggingWaypointInfo({ enemyId: obj.id, wpIdx: i });
                          } : undefined}
                        />
                      );
                    })}
                  </g>
                );
              }

              // Patrol (and others): dashed waypoint path
              const color = isSelected ? '#44ffff' : '#44ffff66';
              const pts = wps.map(wp => vecToSvg(wp.x, wp.y));
              return (
                <g key={`patrol_${obj.id}`}>
                  {pts.map((pt, i) => i < pts.length - 1 && (
                    <line key={i} x1={pt.x} y1={pt.y} x2={pts[i+1].x} y2={pts[i+1].y}
                      stroke={color} strokeWidth="0.5" strokeDasharray="3 2" />
                  ))}
                  {pts.length > 1 && (
                    <line x1={pts[pts.length-1].x} y1={pts[pts.length-1].y} x2={pts[0].x} y2={pts[0].y}
                      stroke={color} strokeWidth="0.5" strokeDasharray="1 3" opacity="0.5" />
                  )}
                  {pts.map((pt, i) => (
                    <circle
                      key={`wp_${i}`}
                      cx={pt.x} cy={pt.y}
                      r={isSelected ? 4 : 2}
                      fill={i === 0 ? '#44ffff' : color}
                      stroke={isSelected ? '#ffffff' : 'none'}
                      strokeWidth={0.5}
                      style={{ cursor: isSelected ? 'grab' : 'default' }}
                      onMouseDown={isSelected ? (e) => {
                        e.stopPropagation();
                        setDraggingWaypointInfo({ enemyId: obj.id, wpIdx: i });
                      } : undefined}
                    />
                  ))}
                </g>
              );
            })}

            {/* Scroll limit guide lines */}
            {renderScrollLimitLines()}

            {/* Objects - render actual vectors */}
            {objects.filter(o => o.layer === 'background').map(renderVector)}
            {objects.filter(o => !o.layer || o.layer === 'gameplay').map(renderVector)}
            {objects.filter(o => o.layer === 'foreground').map(renderVector)}

            {/* Standalone render of LEVEL walkable areas + transitions.
                Always drawn so the designer can see the level pathways and
                their indices on the canvas while building, even when no
                inheriting wander enemy is around to draw them. Per-enemy
                renders draw on top of this, so own-overrides remain visible
                in orange. Style: subtle blue dashed bars, always-labeled. */}
            {(() => {
              // Resolve the level's effective areas for display: explicit
              // level walkable_areas override; else the union collected from
              // .vec-baked areas of placed objects.
              const effectiveLevel = levelWalkableAreas.length > 0
                ? levelWalkableAreas
                : collectVecWalkableAreas(objects, loadedVectors);
              const fromVec = levelWalkableAreas.length === 0 && effectiveLevel.length > 0;
              if (effectiveLevel.length === 0) return null;
              // Vec-collected areas render in a subtle green so the designer
              // can tell they came from the .vec assets, not from the level.
              const color = fromVec ? '#88cc88' : '#88aacc';
              return (
                <g key="level_walkable_areas">
                <g style={{ pointerEvents: 'none' }}>
                  {effectiveLevel.map((area, ai) => {
                    const left  = vecToSvg(area.x_min, area.y);
                    const right = vecToSvg(area.x_max, area.y);
                    return (
                      <g key={`lvl_area_${ai}`}>
                        <line x1={left.x} y1={left.y} x2={right.x} y2={right.y}
                          stroke={color} strokeWidth={0.8} strokeDasharray="2 2" />
                        <line x1={left.x} y1={left.y - 4} x2={left.x} y2={left.y + 4}
                          stroke={color} strokeWidth={1} />
                        <line x1={right.x} y1={right.y - 4} x2={right.x} y2={right.y + 4}
                          stroke={color} strokeWidth={1} />
                        {/* Halo for legibility */}
                        <text x={(left.x + right.x) / 2} y={left.y - 3}
                          fontSize="7" fontFamily="monospace" fontWeight={600}
                          textAnchor="middle" stroke="#000" strokeWidth="2.5"
                          style={{ paintOrder: 'stroke' }}>{ai}</text>
                        <text x={(left.x + right.x) / 2} y={left.y - 3}
                          fill={color} fontSize="7" fontFamily="monospace" fontWeight={600}
                          textAnchor="middle">{ai}</text>
                      </g>
                    );
                  })}
                </g>
                {/* Transitions: kept outside the pointer-events:none group so
                    the takeoff/landing handles can receive mousedown. When
                    the level has no own transitions and no own areas (vec-
                    collected), derive transitions from the effective areas. */}
                {(levelTransitions.length > 0 ? levelTransitions : deriveTransitions(effectiveLevel)).map((t, ti) => {
                    if (t.from >= effectiveLevel.length || t.to >= effectiveLevel.length) return null;
                    const fromArea = effectiveLevel[t.from];
                    const toArea = effectiveLevel[t.to];
                    const fromX = (t as any).from_x ?? (fromArea.x_min + fromArea.x_max) / 2;
                    const toX   = (t as any).to_x   ?? (toArea.x_min   + toArea.x_max)   / 2;
                    const fromPt = vecToSvg(fromX, fromArea.y);
                    const toPt   = vecToSvg(toX,   toArea.y);
                    const midX = (fromPt.x + toPt.x) / 2;
                    const midY = (fromPt.y + toPt.y) / 2;
                    const dxA = toPt.x - fromPt.x;
                    const dyA = toPt.y - fromPt.y;
                    const lenA = Math.sqrt(dxA * dxA + dyA * dyA) || 1;
                    const px = -dyA / lenA * 10;
                    const py =  dxA / lenA * 10;
                    const ctlX = midX + px;
                    const ctlY = midY + py;
                    const tColor = t.type === 'jump_up' ? '#88ffaa' : '#ff8866';
                    return (
                      <g key={`lvl_trans_${ti}`}>
                        <path d={`M ${fromPt.x} ${fromPt.y} Q ${ctlX} ${ctlY} ${toPt.x} ${toPt.y}`}
                          stroke={tColor + '99'} strokeWidth={0.6}
                          strokeDasharray="2 1.5" fill="none" />
                        {/* Takeoff endpoint — draggable; clamps to from-area X range. */}
                        <circle cx={fromPt.x} cy={fromPt.y} r={2.4}
                          fill={tColor + 'cc'} stroke="#ffffff" strokeWidth={0.4}
                          style={{ cursor: 'grab' }}
                          onMouseDown={(e) => {
                            e.stopPropagation();
                            setDraggingLevelTransitionEndpoint({ transIdx: ti, endpoint: 'from' });
                          }} />
                        {/* Landing endpoint — draggable; clamps to to-area X range. */}
                        <circle cx={toPt.x} cy={toPt.y} r={2.8}
                          fill={tColor + 'cc'} stroke="#ffffff" strokeWidth={0.4}
                          style={{ cursor: 'grab' }}
                          onMouseDown={(e) => {
                            e.stopPropagation();
                            setDraggingLevelTransitionEndpoint({ transIdx: ti, endpoint: 'to' });
                          }} />
                        <text x={ctlX} y={ctlY} fontSize="6" fontFamily="monospace"
                          textAnchor="middle" stroke="#000" strokeWidth="2"
                          style={{ paintOrder: 'stroke' }}>T{ti}</text>
                        <text x={ctlX} y={ctlY} fill={tColor} fontSize="6" fontFamily="monospace"
                          textAnchor="middle">T{ti}</text>
                      </g>
                    );
                  })}
                </g>
              );
            })()}

            {/* Walkable-area draw preview (while the user is dragging in
                draw-mode for a level area). Painted as a bright cyan bar so
                it stands out against the orange/blue area bars. */}
            {drawingPreview && drawingLevelAreaIdx !== null && (() => {
              const left  = vecToSvg(drawingPreview.x_min, drawingPreview.y);
              const right = vecToSvg(drawingPreview.x_max, drawingPreview.y);
              return (
                <g key="drawing_preview" style={{ pointerEvents: 'none' }}>
                  <line x1={left.x} y1={left.y} x2={right.x} y2={right.y}
                    stroke="#00ffff" strokeWidth="2" />
                  <line x1={left.x} y1={left.y - 5} x2={left.x} y2={left.y + 5}
                    stroke="#00ffff" strokeWidth="1.5" />
                  <line x1={right.x} y1={right.y - 5} x2={right.x} y2={right.y + 5}
                    stroke="#00ffff" strokeWidth="1.5" />
                  <text x={(left.x + right.x) / 2} y={left.y - 6}
                    fill="#00ffff" fontSize="6" fontFamily="monospace" textAnchor="middle">
                    #{drawingLevelAreaIdx} y={drawingPreview.y} {drawingPreview.x_min}..{drawingPreview.x_max}
                  </text>
                </g>
              );
            })()}

            {/* Rubber band selection rectangle */}
            {rubberBand && (
              <rect
                x={Math.min(rubberBand.svgX1, rubberBand.svgX2)}
                y={Math.min(rubberBand.svgY1, rubberBand.svgY2)}
                width={Math.abs(rubberBand.svgX2 - rubberBand.svgX1)}
                height={Math.abs(rubberBand.svgY2 - rubberBand.svgY1)}
                fill="rgba(0,200,255,0.08)"
                stroke="#00ccff"
                strokeWidth="0.5"
                strokeDasharray="3 2"
                style={{ pointerEvents: 'none' }}
              />
            )}

            {/* Status display */}
            <text x="5" y="15" fill="#00ff00" fontSize="8" fontFamily="monospace">
              {objects.length} objects | {hotspots.length} hotspots | {loadedVectors.size} vectors
              {Object.keys(scrollLimits).filter(k => (scrollLimits as any)[k] !== undefined).length > 0
                ? ` | ${Object.keys(scrollLimits).filter(k => (scrollLimits as any)[k] !== undefined).length} scroll limits`
                : ''}
            </text>
          </svg>
          </div>
        </div>

        {/* Properties Panel */}
        <div style={{
          width: '250px',
          flexShrink: 0,
          borderLeft: '1px solid #3e3e3e',
          padding: '12px',
          overflowY: 'auto',
          minHeight: 0,
        }}>
          <h3 style={{ fontSize: '12px', margin: '0 0 8px 0', color: '#888' }}>
            PROPERTIES
          </h3>

          {/* Hotspot properties panel */}
          {selectedHotspotId && (() => {
            const hs = hotspots.find(h => h.id === selectedHotspotId);
            if (!hs) return null;

            const update = (patch: Partial<VPlayHotspot>) => {
              setHotspots(prev => prev.map(h => h.id === hs.id ? { ...h, ...patch } : h));
            };

            return (
              <div style={{ padding: '8px', color: '#ffaa00', marginBottom: '8px' }}>
                <div style={{ fontWeight: 'bold', marginBottom: '8px', borderBottom: '1px solid #ffaa0044', paddingBottom: '4px', fontSize: '11px' }}>
                  HOTSPOT
                </div>

                <div style={{ marginBottom: '6px' }}>
                  <label style={{ fontSize: '11px', color: '#aaa', display: 'block', marginBottom: '2px' }}>ID</label>
                  <input
                    value={hs.id}
                    onChange={e => update({ id: e.target.value })}
                    style={{ width: '100%', background: '#1a1a1a', color: '#ffaa00', border: '1px solid #555', padding: '2px 4px', fontSize: '11px', boxSizing: 'border-box' }}
                  />
                </div>

                <div style={{ marginBottom: '6px' }}>
                  <label style={{ fontSize: '11px', color: '#aaa', display: 'block', marginBottom: '2px' }}>Label (in-game prompt)</label>
                  <input
                    value={hs.label}
                    onChange={e => update({ label: e.target.value })}
                    style={{ width: '100%', background: '#1a1a1a', color: '#ffaa00', border: '1px solid #555', padding: '2px 4px', fontSize: '11px', boxSizing: 'border-box' }}
                  />
                </div>

                <div style={{ marginBottom: '6px' }}>
                  <label style={{ fontSize: '11px', color: '#aaa', display: 'block', marginBottom: '2px' }}>Trigger</label>
                  <select
                    value={hs.trigger}
                    onChange={e => update({ trigger: e.target.value as HotspotTrigger })}
                    style={{ width: '100%', background: '#1a1a1a', color: '#ffaa00', border: '1px solid #555', padding: '2px 4px', fontSize: '11px' }}
                  >
                    <option value="player_near">player_near — proximity</option>
                    <option value="player_on">player_on — overlap</option>
                    <option value="projectile">projectile — shot hit</option>
                    <option value="auto">auto — always active</option>
                  </select>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '4px', marginBottom: '6px' }}>
                  <div>
                    <label style={{ fontSize: '10px', color: '#aaa', display: 'block' }}>X</label>
                    <input type="number" value={hs.x}
                      onChange={e => update({ x: parseInt(e.target.value) || 0 })}
                      style={{ width: '100%', background: '#1a1a1a', color: '#ffaa00', border: '1px solid #555', padding: '2px 4px', fontSize: '11px', boxSizing: 'border-box' }}
                    />
                  </div>
                  <div>
                    <label style={{ fontSize: '10px', color: '#aaa', display: 'block' }}>Y</label>
                    <input type="number" value={hs.y}
                      onChange={e => update({ y: parseInt(e.target.value) || 0 })}
                      style={{ width: '100%', background: '#1a1a1a', color: '#ffaa00', border: '1px solid #555', padding: '2px 4px', fontSize: '11px', boxSizing: 'border-box' }}
                    />
                  </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '4px', marginBottom: '6px' }}>
                  <div>
                    <label style={{ fontSize: '10px', color: '#aaa', display: 'block' }}>Width (half)</label>
                    <input type="number" value={hs.w} min={5} max={96}
                      onChange={e => update({ w: Math.max(5, parseInt(e.target.value) || 20) })}
                      style={{ width: '100%', background: '#1a1a1a', color: '#ffaa00', border: '1px solid #555', padding: '2px 4px', fontSize: '11px', boxSizing: 'border-box' }}
                    />
                  </div>
                  <div>
                    <label style={{ fontSize: '10px', color: '#aaa', display: 'block' }}>Height (half)</label>
                    <input type="number" value={hs.h} min={5} max={128}
                      onChange={e => update({ h: Math.max(5, parseInt(e.target.value) || 20) })}
                      style={{ width: '100%', background: '#1a1a1a', color: '#ffaa00', border: '1px solid #555', padding: '2px 4px', fontSize: '11px', boxSizing: 'border-box' }}
                    />
                  </div>
                </div>

                <button
                  onClick={() => {
                    setHotspots(prev => prev.filter(h => h.id !== hs.id));
                    setSelectedHotspotId(null);
                  }}
                  style={{ width: '100%', padding: '4px', background: '#3a0000', color: '#ff6666', border: '1px solid #aa3333', cursor: 'pointer', fontSize: '11px' }}
                >
                  Delete Hotspot
                </button>
              </div>
            );
          })()}

          {selectedId ? (
            <div style={{ fontSize: '11px' }}>
              {(() => {
                const obj = objects.find(o => o.id === selectedId);
                if (!obj) return null;

                return (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                    <div>
                      <label style={{ color: '#888', display: 'block', marginBottom: '4px' }}>
                        Vector
                      </label>
                      <div style={{ color: '#d4d4d4', fontFamily: 'monospace' }}>
                        {obj.vectorName}
                      </div>
                    </div>
                    <div>
                      <label style={{ color: '#888', display: 'block', marginBottom: '4px' }}>
                        Layer
                      </label>
                      <select
                        value={obj.layer || 'gameplay'}
                        onChange={(e) => {
                          const newObjects = objects.map(o =>
                            o.id === selectedId ? { ...o, layer: e.target.value as any } : o
                          );
                          setObjects(newObjects);
                        }}
                        style={{
                          width: '100%',
                          padding: '4px',
                          backgroundColor: '#2d2d2d',
                          border: '1px solid #444',
                          color: '#d4d4d4',
                          borderRadius: '2px',
                        }}
                      >
                        <option value="background">🏔️ Background (fondo, detrás)</option>
                        <option value="gameplay">⚡ Gameplay (jugable, medio)</option>
                        <option value="foreground">🌟 Foreground (frente, adelante)</option>
                      </select>
                      <div style={{ fontSize: '10px', color: '#666', marginTop: '4px' }}>
                        {obj.layer === 'background' && '🏔️ Dibuja primero - fondo del nivel'}
                        {obj.layer === 'foreground' && '🌟 Dibuja último - frente del nivel'}
                        {(!obj.layer || obj.layer === 'gameplay') && '⚡ Capa principal - objetos jugables'}
                      </div>
                    </div>
                    <div>
                      <label style={{ color: '#888', display: 'block', marginBottom: '4px' }}>
                        Position
                      </label>
                      <input
                        type="number"
                        value={obj.x}
                        onChange={(e) => {
                          const newObjects = objects.map(o =>
                            o.id === selectedId ? { ...o, x: parseInt(e.target.value) } : o
                          );
                          setObjects(newObjects);
                        }}
                        style={{
                          width: '100%',
                          padding: '4px',
                          backgroundColor: '#2d2d2d',
                          border: '1px solid #444',
                          color: '#d4d4d4',
                          borderRadius: '2px',
                        }}
                      />
                      <input
                        type="number"
                        value={obj.y}
                        onChange={(e) => {
                          const newObjects = objects.map(o =>
                            o.id === selectedId ? { ...o, y: parseInt(e.target.value) } : o
                          );
                          setObjects(newObjects);
                        }}
                        style={{
                          width: '100%',
                          padding: '4px',
                          marginTop: '4px',
                          backgroundColor: '#2d2d2d',
                          border: '1px solid #444',
                          color: '#d4d4d4',
                          borderRadius: '2px',
                        }}
                      />
                    </div>
                    <div>
                      <label style={{ color: '#888', display: 'block', marginBottom: '4px' }}>
                        Scale
                      </label>
                      <input
                        type="number"
                        step="0.1"
                        min="0.1"
                        max="5"
                        value={obj.scale}
                        onChange={(e) => {
                          const newObjects = objects.map(o =>
                            o.id === selectedId ? { ...o, scale: parseFloat(e.target.value) } : o
                          );
                          setObjects(newObjects);
                        }}
                        style={{
                          width: '100%',
                          padding: '4px',
                          backgroundColor: '#2d2d2d',
                          border: '1px solid #444',
                          color: '#d4d4d4',
                          borderRadius: '2px',
                        }}
                      />
                    </div>
                    <div>
                      <label style={{ color: '#888', display: 'block', marginBottom: '4px' }}>
                        Rotation (degrees)
                      </label>
                      <input
                        type="number"
                        step="15"
                        min="0"
                        max="360"
                        value={obj.rotation}
                        onChange={(e) => {
                          const newObjects = objects.map(o =>
                            o.id === selectedId ? { ...o, rotation: parseInt(e.target.value) } : o
                          );
                          setObjects(newObjects);
                        }}
                        style={{
                          width: '100%',
                          padding: '4px',
                          backgroundColor: '#2d2d2d',
                          border: '1px solid #444',
                          color: '#d4d4d4',
                          borderRadius: '2px',
                        }}
                      />
                    </div>
                    <div>
                      <label style={{ color: '#888', display: 'block', marginBottom: '4px' }}>
                        Initial Velocity
                      </label>
                      <div style={{ display: 'flex', gap: '4px', marginBottom: '4px' }}>
                        <div style={{ flex: 1 }}>
                          <label style={{ fontSize: '10px', color: '#666' }}>X</label>
                          <input
                            type="number"
                            step="0.5"
                            value={(obj.velocity?.x || 0).toFixed(1)}
                            onChange={(e) => {
                              const x = parseFloat(e.target.value) || 0;
                              setObjects(objects.map(o =>
                                o.id === selectedId ? { ...o, velocity: { ...o.velocity!, x, y: o.velocity?.y || 0 } } : o
                              ));
                            }}
                            style={{
                              width: '100%',
                              padding: '4px',
                              backgroundColor: '#2d2d2d',
                              border: '1px solid #444',
                              color: '#d4d4d4',
                              borderRadius: '2px',
                              fontSize: '11px',
                            }}
                          />
                        </div>
                        <div style={{ flex: 1 }}>
                          <label style={{ fontSize: '10px', color: '#666' }}>Y</label>
                          <input
                            type="number"
                            step="0.5"
                            value={(obj.velocity?.y || 0).toFixed(1)}
                            onChange={(e) => {
                              const y = parseFloat(e.target.value) || 0;
                              setObjects(objects.map(o =>
                                o.id === selectedId ? { ...o, velocity: { x: o.velocity?.x || 0, y } } : o
                              ));
                            }}
                            style={{
                              width: '100%',
                              padding: '4px',
                              backgroundColor: '#2d2d2d',
                              border: '1px solid #444',
                              color: '#d4d4d4',
                              borderRadius: '2px',
                              fontSize: '11px',
                            }}
                          />
                        </div>
                      </div>
                      <div style={{ fontSize: '10px', color: '#888', marginTop: '4px' }}>
                        {(() => {
                          const vx = obj.velocity?.x || 0;
                          const vy = obj.velocity?.y || 0;
                          const mag = Math.sqrt(vx * vx + vy * vy);
                          const angle = Math.atan2(vy, vx) * (180 / Math.PI);
                          return `📐 ${angle.toFixed(0)}° | ⚡ ${mag.toFixed(1)} px/frame`;
                        })()}
                      </div>
                      <div style={{ fontSize: '10px', color: '#666', marginTop: '4px' }}>
                        💡 Activa "Set Velocity" y arrastra la flecha naranja
                      </div>
                    </div>
                    {obj.physicsEnabled && (obj.physicsType === 'gravity' || !obj.physicsType) && (
                      <div>
                        <label style={{ color: '#888', display: 'block', marginBottom: '4px' }}>
                          Gravity
                        </label>
                        <input
                          type="range"
                          min="0"
                          max="3"
                          step="0.1"
                          value={obj.gravity ?? 1}
                          onChange={(e) => {
                            const newObjects = objects.map(o =>
                              o.id === selectedId ? { ...o, gravity: parseFloat(e.target.value) } : o
                            );
                            setObjects(newObjects);
                          }}
                          style={{ width: '100%' }}
                        />
                        <span style={{ fontSize: '10px', color: '#d4d4d4' }}>{(obj.gravity ?? 1).toFixed(1)}</span>
                      </div>
                    )}
                    {obj.physicsEnabled && (obj.physicsType === 'gravity' || !obj.physicsType) && (
                      <div>
                        <label style={{ color: '#888', display: 'block', marginBottom: '4px' }}>
                          Bounce Damping
                        </label>
                        <input
                          type="range"
                          min="0"
                          max="1"
                          step="0.05"
                          value={obj.bounceDamping ?? 0.85}
                          onChange={(e) => {
                            const newObjects = objects.map(o =>
                              o.id === selectedId ? { ...o, bounceDamping: parseFloat(e.target.value) } : o
                            );
                            setObjects(newObjects);
                          }}
                          style={{ width: '100%' }}
                        />
                        <span style={{ fontSize: '10px', color: '#d4d4d4' }}>{((obj.bounceDamping ?? 0.85) * 100).toFixed(0)}%</span>
                      </div>
                    )}
                    <div>
                      <label style={{ color: '#888', display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
                        <input
                          type="checkbox"
                          checked={obj.physicsEnabled ?? false}
                          onChange={(e) => {
                            const newObjects = objects.map(o =>
                              o.id === selectedId ? { ...o, physicsEnabled: e.target.checked } : o
                            );
                            setObjects(newObjects);
                          }}
                          style={{
                            width: '16px',
                            height: '16px',
                            cursor: 'pointer',
                          }}
                        />
                        Physics Enabled
                      </label>
                      <div style={{ fontSize: '10px', color: '#666', marginTop: '4px', marginLeft: '24px' }}>
                        {obj.physicsEnabled ? '⚡ Aplica física' : '🔒 Estático'}
                      </div>
                    </div>
                    {obj.physicsEnabled && (
                      <div>
                        <label style={{ color: '#888', display: 'block', marginBottom: '4px' }}>
                          Physics Type
                        </label>
                        <select
                          value={obj.physicsType || 'gravity'}
                          onChange={(e) => {
                            const newObjects = objects.map(o =>
                              o.id === selectedId ? { ...o, physicsType: e.target.value as any } : o
                            );
                            setObjects(newObjects);
                          }}
                          style={{
                            width: '100%',
                            padding: '4px',
                            backgroundColor: '#2d2d2d',
                            border: '1px solid #444',
                            color: '#d4d4d4',
                            borderRadius: '2px',
                          }}
                        >
                          <option value="gravity">🌍 Gravity (cae, pierde energía)</option>
                          <option value="bounce">⚡ Bounce (rebote perpetuo)</option>
                          <option value="projectile">🎯 Projectile (parábola, no rebota)</option>
                          <option value="static">🔒 Static (sin movimiento)</option>
                        </select>
                      </div>
                    )}
                    <div>
                      <label style={{ color: '#888', display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
                        <input
                          type="checkbox"
                          checked={obj.collidable ?? true}
                          onChange={(e) => {
                            const newObjects = objects.map(o =>
                              o.id === selectedId ? { ...o, collidable: e.target.checked } : o
                            );
                            setObjects(newObjects);
                          }}
                          style={{
                            width: '16px',
                            height: '16px',
                            cursor: 'pointer',
                          }}
                        />
                        Collidable (rebota)
                      </label>
                      <div style={{ fontSize: '10px', color: '#666', marginTop: '4px', marginLeft: '24px' }}>
                        {obj.collidable ? '🔷 Objeto sólido - los demás rebotan' : '⬜ Objeto atravesable - sin colisión'}
                      </div>
                    </div>

                    {/* Collision mesh editor — only for collidable objects */}
                    {obj.collidable && (
                      <div style={{ borderTop: '1px solid #333', marginTop: '8px', paddingTop: '8px' }}>
                        <div style={{ fontSize: '11px', fontWeight: 700, color: '#00cccc', marginBottom: '6px', letterSpacing: '0.06em' }}>
                          COLLISION MESH
                        </div>
                        <div style={{ fontSize: '10px', color: '#666', marginBottom: '6px' }}>
                          {obj.collision?.segments?.length
                            ? `${obj.collision.segments.length} segmento(s) — ray-cast activo`
                            : 'Sin segmentos — usa AABB automático'}
                        </div>
                        {(obj.collision?.segments || []).map((seg, si) => (
                          <div key={si} style={{ display: 'flex', gap: 2, alignItems: 'center', marginBottom: 3, background: '#1a1a1a', padding: '3px 4px', borderRadius: 3 }}>
                            <span style={{ fontSize: '9px', color: '#555', width: 14, flexShrink: 0 }}>#{si}</span>
                            {(['x1','y1','x2','y2'] as const).map(field => (
                              <input
                                key={field}
                                type="number"
                                value={(seg as any)[field]}
                                onChange={e => {
                                  const val = parseInt(e.target.value) || 0;
                                  const newSegs = (obj.collision!.segments!).map((s, idx) =>
                                    idx === si ? { ...s, [field]: val } : s
                                  );
                                  setObjects(objects.map(o => o.id === selectedId
                                    ? { ...o, collision: { ...o.collision, enabled: true, segments: newSegs } }
                                    : o
                                  ));
                                }}
                                style={{ width: 36, background: '#111', color: '#00cccc', border: '1px solid #333', borderRadius: 2, padding: '1px 3px', fontSize: '10px', fontFamily: 'monospace' }}
                              />
                            ))}
                            <button
                              onClick={() => {
                                const newSegs = (obj.collision?.segments || []).filter((_, idx) => idx !== si);
                                setObjects(objects.map(o => o.id === selectedId
                                  ? { ...o, collision: { ...o.collision, enabled: newSegs.length > 0, segments: newSegs } }
                                  : o
                                ));
                              }}
                              style={{ background: 'none', border: 'none', color: '#663333', cursor: 'pointer', fontSize: '12px', padding: '0 2px', flexShrink: 0 }}
                            >×</button>
                          </div>
                        ))}
                        <button
                          onClick={() => {
                            const newSeg: CollisionSegment = { x1: -20, y1: 0, x2: 20, y2: 0 };
                            const existing = obj.collision?.segments || [];
                            setObjects(objects.map(o => o.id === selectedId
                              ? { ...o, collision: { ...o.collision, enabled: true, segments: [...existing, newSeg] } }
                              : o
                            ));
                          }}
                          style={{ width: '100%', marginTop: 2, padding: '3px 0', background: '#1a2a2a', border: '1px solid #00cccc44', borderRadius: 3, color: '#00cccc', cursor: 'pointer', fontSize: '10px' }}
                        >+ Añadir segmento</button>
                      </div>
                    )}

                    {/* Enemy-specific properties */}
                    {obj.type === 'enemy' && (
                      <div style={{ borderTop: '1px solid #333', marginTop: '8px', paddingTop: '8px' }}>
                        <div style={{ fontSize: '11px', fontWeight: 700, color: '#ff44ff', marginBottom: '6px', letterSpacing: '0.06em' }}>
                          ENEMY
                        </div>
                        <label style={{ fontSize: '11px', color: '#888', display: 'block', marginBottom: '2px' }}>Type (.venemy)</label>
                        <select
                          value={obj.enemyType || ''}
                          onChange={e => setObjects(objects.map(o => o.id === selectedId ? { ...o, enemyType: e.target.value } : o))}
                          style={{ width: '100%', background: '#1a1a1a', color: '#ff44ff', border: '1px solid #555', padding: '2px 4px', fontSize: '11px', marginBottom: '6px' }}
                        >
                          <option value="">— none —</option>
                          {availableEnemies.map(e => <option key={e} value={e}>{e}</option>)}
                        </select>
                        <label style={{ fontSize: '11px', color: '#888', display: 'block', marginBottom: '2px' }}>AI Behavior</label>
                        <select
                          value={obj.aiType || 'patrol'}
                          onChange={e => setObjects(objects.map(o => o.id === selectedId ? { ...o, aiType: e.target.value as any } : o))}
                          style={{ width: '100%', background: '#1a1a1a', color: '#d4d4d4', border: '1px solid #555', padding: '2px 4px', fontSize: '11px', marginBottom: '6px' }}
                        >
                          <option value="patrol">patrol</option>
                          <option value="wander">wander (X-only + idle)</option>
                          <option value="chase">chase</option>
                          <option value="flee">flee</option>
                          <option value="static">static</option>
                        </select>
                        <div style={{ marginBottom: '6px' }}>
                          <label style={{ fontSize: '10px', color: '#666', display: 'block', marginBottom: '2px' }}>Patrol speed (units/frame)</label>
                          <input type="number" min={0.1} max={20} step={0.1} value={obj.speed ?? 1.0}
                            onChange={e => setObjects(objects.map(o => o.id === selectedId ? { ...o, speed: parseFloat(e.target.value) } : o))}
                            style={{ width: '100%', background: '#1a1a1a', color: '#44ffcc', border: '1px solid #555', padding: '2px 4px', fontSize: '11px' }} />
                        </div>
                        {(obj.aiType === 'patrol' || obj.aiType === 'wander') && (
                          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '4px', marginBottom: '6px' }}>
                            <div>
                              <label style={{ fontSize: '10px', color: '#666', display: 'block', marginBottom: '2px' }}>Mirror on turn</label>
                              <input type="checkbox" checked={obj.mirrorOnPatrol ?? false}
                                onChange={e => setObjects(objects.map(o => o.id === selectedId ? { ...o, mirrorOnPatrol: e.target.checked } : o))}
                                style={{ cursor: 'pointer', marginTop: '3px' }} />
                            </div>
                            <div>
                              <label style={{ fontSize: '10px', color: '#666', display: 'block', marginBottom: '2px' }}>Default facing</label>
                              <select
                                value={obj.defaultFacing ?? 'right'}
                                onChange={e => setObjects(objects.map(o => o.id === selectedId ? { ...o, defaultFacing: e.target.value as 'left' | 'right' } : o))}
                                style={{ width: '100%', background: '#1a1a1a', color: '#d4d4d4', border: '1px solid #555', padding: '2px 4px', fontSize: '11px' }}
                              >
                                <option value="right">→ Right</option>
                                <option value="left">← Left</option>
                              </select>
                            </div>
                          </div>
                        )}
                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '4px', marginBottom: '6px' }}>
                          <div>
                            <label style={{ fontSize: '10px', color: '#666', display: 'block' }}>Wave</label>
                            <input type="number" min={0} max={99} value={obj.wave ?? 0}
                              onChange={e => setObjects(objects.map(o => o.id === selectedId ? { ...o, wave: parseInt(e.target.value) } : o))}
                              style={{ width: '100%', background: '#1a1a1a', color: '#d4d4d4', border: '1px solid #555', padding: '2px 4px', fontSize: '11px' }} />
                          </div>
                          <div>
                            <label style={{ fontSize: '10px', color: '#666', display: 'block' }}>Respawn</label>
                            <input type="checkbox" checked={obj.respawn ?? false}
                              onChange={e => setObjects(objects.map(o => o.id === selectedId ? { ...o, respawn: e.target.checked } : o))}
                              style={{ marginTop: '4px', cursor: 'pointer' }} />
                          </div>
                        </div>
                        <div style={{ fontSize: '10px', color: '#666', marginBottom: '4px' }}>
                          Patrol waypoints: {obj.patrolWaypoints?.length ?? 0}
                          {(obj.aiType === 'patrol' || obj.aiType === 'wander') && (
                            <span
                              onClick={() => setActiveTool('patrol')}
                              style={{ color: '#44ffff', marginLeft: 8, cursor: 'pointer' }}
                            >
                              + draw path
                            </span>
                          )}
                        </div>
                        {(obj.patrolWaypoints?.length ?? 0) > 0 && (
                          <div style={{ marginTop: 4 }}>
                            {obj.patrolWaypoints!.map((wp, wpIdx) => (
                              <div key={wpIdx} style={{ display: 'flex', alignItems: 'center', gap: 4, marginBottom: 2, fontSize: '10px' }}>
                                <span style={{ color: '#888', width: 24 }}>wp{wpIdx}</span>
                                <span style={{ color: '#666' }}>x</span>
                                <input
                                  type="number"
                                  value={wp.x}
                                  onChange={e => {
                                    const v = parseInt(e.target.value, 10);
                                    if (Number.isNaN(v)) return;
                                    setObjects(objects.map(o => {
                                      if (o.id !== selectedId) return o;
                                      const wps = [...(o.patrolWaypoints || [])];
                                      wps[wpIdx] = { ...wps[wpIdx], x: v };
                                      return { ...o, patrolWaypoints: wps };
                                    }));
                                  }}
                                  style={{ width: 50, fontSize: '10px', padding: '1px 3px', background: '#222', color: '#fff', border: '1px solid #444', borderRadius: 2 }}
                                />
                                <span style={{ color: '#666' }}>y</span>
                                <input
                                  type="number"
                                  value={wp.y}
                                  onChange={e => {
                                    const v = parseInt(e.target.value, 10);
                                    if (Number.isNaN(v)) return;
                                    setObjects(objects.map(o => {
                                      if (o.id !== selectedId) return o;
                                      const wps = [...(o.patrolWaypoints || [])];
                                      wps[wpIdx] = { ...wps[wpIdx], y: v };
                                      return { ...o, patrolWaypoints: wps };
                                    }));
                                  }}
                                  style={{ width: 50, fontSize: '10px', padding: '1px 3px', background: '#222', color: '#fff', border: '1px solid #444', borderRadius: 2 }}
                                />
                                <button
                                  onClick={() => setObjects(objects.map(o => {
                                    if (o.id !== selectedId) return o;
                                    const wps = [...(o.patrolWaypoints || [])];
                                    wps.splice(wpIdx, 1);
                                    return { ...o, patrolWaypoints: wps };
                                  }))}
                                  title="Remove this waypoint"
                                  style={{ fontSize: '10px', background: '#330000', border: '1px solid #660000', color: '#ff6666', borderRadius: 2, padding: '1px 5px', cursor: 'pointer' }}
                                >×</button>
                              </div>
                            ))}
                            <button
                              onClick={() => setObjects(objects.map(o => o.id === selectedId ? { ...o, patrolWaypoints: [] } : o))}
                              style={{ marginTop: 2, fontSize: '10px', background: '#330000', border: '1px solid #660000', color: '#ff6666', borderRadius: 2, padding: '2px 6px', cursor: 'pointer' }}
                            >
                              Clear waypoints
                            </button>
                          </div>
                        )}

                        {/* ── Wander: walkable_areas + transitions (Phase 2) ── */}
                        {obj.aiType === 'wander' && (() => {
                          const ownAreas = (obj as any).walkable_areas as { y: number; x_min: number; x_max: number }[] | undefined;
                          const ownTransitions = (obj as any).transitions as { from: number; to: number; type: 'jump_up' | 'drop'; from_x?: number; to_x?: number }[] | undefined;
                          // Inherits from level when own field is undefined.
                          const inheritsAreas = ownAreas === undefined;
                          const inheritsTransitions = ownTransitions === undefined;
                          const areas = inheritsAreas ? levelWalkableAreas : ownAreas!;
                          const transitions = inheritsTransitions ? levelTransitions : ownTransitions!;
                          const updateAreas = (next: typeof areas) =>
                            setObjects(objects.map(o => o.id === selectedId ? ({ ...o, walkable_areas: next } as any) : o));
                          const updateTransitions = (next: typeof transitions) =>
                            setObjects(objects.map(o => o.id === selectedId ? ({ ...o, transitions: next } as any) : o));
                          // Convert from inherit → own (copy current resolved list).
                          const overrideAreas = () => updateAreas([...areas]);
                          const overrideTransitions = () => updateTransitions([...transitions]);
                          // Convert from own → inherit (delete field).
                          const resetAreas = () =>
                            setObjects(objects.map(o => {
                              if (o.id !== selectedId) return o;
                              const { walkable_areas: _wa, ...rest } = o as any;
                              return rest;
                            }));
                          const resetTransitions = () =>
                            setObjects(objects.map(o => {
                              if (o.id !== selectedId) return o;
                              const { transitions: _t, ...rest } = o as any;
                              return rest;
                            }));
                          return (
                            <>
                              <div style={{ borderTop: '1px solid #333', marginTop: 8, paddingTop: 6 }}>
                                <div style={{ fontSize: '10px', color: inheritsAreas ? '#88aacc' : '#ffaa44', marginBottom: 4 }}>
                                  Walkable areas: {areas.length}
                                  {inheritsAreas && (
                                    <span style={{ color: '#88aacc', marginLeft: 6, fontStyle: 'italic' }}>(from level)</span>
                                  )}
                                  {inheritsAreas ? (
                                    <span
                                      onClick={overrideAreas}
                                      title="Copy the level areas into this enemy and let you customize them."
                                      style={{ color: '#44ffff', marginLeft: 8, cursor: 'pointer' }}
                                    >
                                      override
                                    </span>
                                  ) : (
                                    <>
                                      <span
                                        onClick={() => {
                                          // Seed: derive a sensible default near the enemy
                                          const wps = obj.patrolWaypoints ?? [];
                                          const xMin = wps.length > 0 ? Math.min(...wps.map(w => w.x)) : obj.x - 20;
                                          const xMax = wps.length > 0 ? Math.max(...wps.map(w => w.x)) : obj.x + 20;
                                          updateAreas([...areas, { y: obj.y, x_min: xMin, x_max: xMax }]);
                                        }}
                                        style={{ color: '#44ffff', marginLeft: 8, cursor: 'pointer' }}
                                      >
                                        + add area
                                      </span>
                                      <span
                                        onClick={resetAreas}
                                        title="Delete this enemy's areas and inherit from the level again."
                                        style={{ color: '#88aacc', marginLeft: 8, cursor: 'pointer' }}
                                      >
                                        reset → level
                                      </span>
                                    </>
                                  )}
                                </div>
                                {areas.map((a, ai) => (
                                  <div key={ai} style={{ display: 'flex', alignItems: 'center', gap: 3, marginBottom: 2, fontSize: '10px', opacity: inheritsAreas ? 0.6 : 1 }}>
                                    <span style={{ color: '#888', width: 18 }}>#{ai}</span>
                                    <span style={{ color: '#666' }}>y</span>
                                    <input type="number" value={a.y} disabled={inheritsAreas}
                                      onChange={e => { const v = parseInt(e.target.value, 10); if (Number.isNaN(v)) return;
                                        const next = [...areas]; next[ai] = { ...next[ai], y: v }; updateAreas(next); }}
                                      style={{ width: 50, fontSize: '10px', padding: '1px 3px', background: '#222', color: '#fff', border: '1px solid #444', borderRadius: 2 }} />
                                    <span style={{ color: '#666' }}>x</span>
                                    <input type="number" value={a.x_min} disabled={inheritsAreas}
                                      onChange={e => { const v = parseInt(e.target.value, 10); if (Number.isNaN(v)) return;
                                        const next = [...areas]; next[ai] = { ...next[ai], x_min: v }; updateAreas(next); }}
                                      title="x_min"
                                      style={{ width: 42, fontSize: '10px', padding: '1px 3px', background: '#222', color: '#fff', border: '1px solid #444', borderRadius: 2 }} />
                                    <span style={{ color: '#666' }}>..</span>
                                    <input type="number" value={a.x_max} disabled={inheritsAreas}
                                      onChange={e => { const v = parseInt(e.target.value, 10); if (Number.isNaN(v)) return;
                                        const next = [...areas]; next[ai] = { ...next[ai], x_max: v }; updateAreas(next); }}
                                      title="x_max"
                                      style={{ width: 42, fontSize: '10px', padding: '1px 3px', background: '#222', color: '#fff', border: '1px solid #444', borderRadius: 2 }} />
                                    <button
                                      onClick={() => {
                                        // If inheriting from level, this row × means "I want a subset
                                        // of the level list" — promote to override (copy list), then
                                        // remove the row.
                                        const baseAreas = inheritsAreas ? [...areas] : areas;
                                        const baseTransitions = inheritsTransitions ? [...transitions] : transitions;
                                        const nextAreas = baseAreas.filter((_, i) => i !== ai);
                                        const nextTransitions = baseTransitions
                                          .filter(t => t.from !== ai && t.to !== ai)
                                          .map(t => ({
                                            ...t,
                                            from: t.from > ai ? t.from - 1 : t.from,
                                            to:   t.to   > ai ? t.to   - 1 : t.to,
                                          }));
                                        // Apply both in a single setObjects so the inheritance flip
                                        // doesn't briefly show stale values mid-render.
                                        setObjects(objects.map(o => {
                                          if (o.id !== selectedId) return o;
                                          const patch: any = { ...o, walkable_areas: nextAreas };
                                          if (inheritsTransitions || baseTransitions.length > 0) {
                                            patch.transitions = nextTransitions;
                                          }
                                          return patch;
                                        }));
                                      }}
                                      title={inheritsAreas
                                        ? 'Promote to per-enemy override and remove this row'
                                        : 'Remove area'}
                                      style={{ fontSize: '10px', background: '#330000', border: '1px solid #660000', color: '#ff6666', borderRadius: 2, padding: '1px 5px', cursor: 'pointer' }}
                                    >×</button>
                                  </div>
                                ))}
                                {areas.length > 0 && (
                                  <button
                                    onClick={() => {
                                      // Always sets walkable_areas to []. If we were inheriting,
                                      // this promotes to override-with-empty so the level areas no
                                      // longer apply to this enemy. Also clears transitions in the
                                      // same setObjects pass (their indices would be invalid).
                                      setObjects(objects.map(o => o.id === selectedId
                                        ? ({ ...o, walkable_areas: [], transitions: [] } as any)
                                        : o));
                                    }}
                                    title={inheritsAreas
                                      ? 'Stop inheriting from level: set this enemy to have no areas.'
                                      : "Remove all walkable areas (override stays). Use 'reset → level' to inherit again."}
                                    style={{ marginTop: 2, fontSize: '10px', background: '#330000', border: '1px solid #660000', color: '#ff6666', borderRadius: 2, padding: '2px 6px', cursor: 'pointer' }}
                                  >
                                    {inheritsAreas ? 'Clear (stop inheriting)' : 'Clear areas'}
                                  </button>
                                )}
                              </div>
                              {areas.length >= 2 && (
                                <div style={{ borderTop: '1px solid #333', marginTop: 6, paddingTop: 6 }}>
                                  <div style={{ fontSize: '10px', color: inheritsTransitions ? '#88aacc' : '#ffaa44', marginBottom: 4 }}>
                                    Transitions: {transitions.length}
                                    {inheritsTransitions && (
                                      <span style={{ color: '#88aacc', marginLeft: 6, fontStyle: 'italic' }}>(from level)</span>
                                    )}
                                    {inheritsTransitions ? (
                                      <span
                                        onClick={overrideTransitions}
                                        title="Copy the level transitions into this enemy."
                                        style={{ color: '#44ffff', marginLeft: 8, cursor: 'pointer' }}
                                      >
                                        override
                                      </span>
                                    ) : (
                                      <>
                                        <span
                                          onClick={() => updateTransitions([...transitions, { from: 0, to: 1, type: 'jump_up' as const }])}
                                          style={{ color: '#44ffff', marginLeft: 8, cursor: 'pointer' }}
                                        >
                                          + add transition
                                        </span>
                                        <span
                                          onClick={resetTransitions}
                                          title="Delete this enemy's transitions and inherit from the level again."
                                          style={{ color: '#88aacc', marginLeft: 8, cursor: 'pointer' }}
                                        >
                                          reset → level
                                        </span>
                                      </>
                                    )}
                                  </div>
                                  {transitions.map((t, ti) => (
                                    <div key={ti} style={{ display: 'flex', alignItems: 'center', gap: 3, marginBottom: 2, fontSize: '10px', opacity: inheritsTransitions ? 0.6 : 1 }}>
                                      <span style={{ color: '#888', width: 18 }}>#{ti}</span>
                                      <select value={t.from} disabled={inheritsTransitions}
                                        onChange={e => { const next = [...transitions]; next[ti] = { ...next[ti], from: parseInt(e.target.value, 10) }; updateTransitions(next); }}
                                        style={{ fontSize: '10px', background: '#222', color: '#fff', border: '1px solid #444', borderRadius: 2 }}>
                                        {areas.map((_, ai) => <option key={ai} value={ai}>{ai}</option>)}
                                      </select>
                                      <span style={{ color: '#666' }}>→</span>
                                      <select value={t.to} disabled={inheritsTransitions}
                                        onChange={e => { const next = [...transitions]; next[ti] = { ...next[ti], to: parseInt(e.target.value, 10) }; updateTransitions(next); }}
                                        style={{ fontSize: '10px', background: '#222', color: '#fff', border: '1px solid #444', borderRadius: 2 }}>
                                        {areas.map((_, ai) => <option key={ai} value={ai}>{ai}</option>)}
                                      </select>
                                      <select value={t.type} disabled={inheritsTransitions}
                                        onChange={e => { const next = [...transitions]; next[ti] = { ...next[ti], type: e.target.value as 'jump_up' | 'drop' }; updateTransitions(next); }}
                                        style={{ fontSize: '10px', background: '#222', color: '#fff', border: '1px solid #444', borderRadius: 2 }}>
                                        <option value="jump_up">jump_up</option>
                                        <option value="drop">drop</option>
                                      </select>
                                      <button
                                        onClick={() => {
                                          // If inheriting, promote to override of the resolved list,
                                          // then drop this transition.
                                          const base = inheritsTransitions ? [...transitions] : transitions;
                                          updateTransitions(base.filter((_, i) => i !== ti));
                                        }}
                                        title={inheritsTransitions
                                          ? 'Promote to per-enemy override and remove this transition'
                                          : 'Remove'}
                                        style={{ fontSize: '10px', background: '#330000', border: '1px solid #660000', color: '#ff6666', borderRadius: 2, padding: '1px 5px', cursor: 'pointer' }}
                                      >×</button>
                                    </div>
                                  ))}
                                  {transitions.length > 0 && (
                                    <button
                                      onClick={() => updateTransitions([])}
                                      title={inheritsTransitions
                                        ? 'Stop inheriting from level: set this enemy to have no transitions.'
                                        : "Remove all transitions (override stays). Use 'reset → level' to inherit again."}
                                      style={{ marginTop: 2, fontSize: '10px', background: '#330000', border: '1px solid #660000', color: '#ff6666', borderRadius: 2, padding: '2px 6px', cursor: 'pointer' }}
                                    >
                                      {inheritsTransitions ? 'Clear (stop inheriting)' : 'Clear transitions'}
                                    </button>
                                  )}
                                </div>
                              )}
                            </>
                          );
                        })()}
                      </div>
                    )}
                    <button
                      onClick={() => {
                        setObjects(objects.filter(o => o.id !== selectedId));
                        setSelectedId(null);
                        setSelectedIds(new Set());
                      }}
                      style={{
                        padding: '4px 8px',
                        backgroundColor: '#a03030',
                        border: '1px solid #c04040',
                        borderRadius: '4px',
                        color: '#fff',
                        cursor: 'pointer',
                        fontSize: '11px',
                      }}
                    >
                      Delete
                    </button>
                  </div>
                );
              })()}
            </div>
          ) : (
            <div>
              <div style={{ fontSize: '11px', color: '#666', fontStyle: 'italic', marginBottom: '12px' }}>
                No object selected
              </div>
              {/* ── Level-wide walkable areas + transitions ────────────────────── */}
              <div>
                <div style={{ fontSize: '11px', color: '#88aacc', fontWeight: 600, borderTop: '1px solid #3e3e3e', paddingTop: '10px', marginBottom: '4px' }}>
                  LEVEL WALKABLE AREAS
                </div>
                <div style={{ fontSize: '10px', color: '#555', marginBottom: '6px' }}>
                  Inherited by wander enemies that don't define their own.
                </div>
                {/* Multi-screen level isolation. When checked, auto-derived
                    transitions never cross a 256u Y screen boundary —
                    suitable for per-screen games like SnowBros. */}
                <label style={{
                  display: 'flex', alignItems: 'center', gap: 6,
                  fontSize: '10px', color: '#aac', marginBottom: '8px',
                  cursor: 'pointer',
                }}>
                  <input
                    type="checkbox"
                    checked={isolateScreens}
                    onChange={(e) => setIsolateScreens(e.target.checked)}
                    style={{ accentColor: '#88aacc' }}
                  />
                  Isolate screens (no auto-jumps between floors)
                </label>
                {/* Auto-transition tuning (drives derive_transitions). */}
                {(() => {
                  const lblStyle = { fontSize: '9px', color: '#888' } as React.CSSProperties;
                  const inputStyle = {
                    width: 42, padding: '1px 3px', fontSize: '9px',
                    background: '#222', color: '#aac', border: '1px solid #445',
                    borderRadius: '2px', fontFamily: 'monospace',
                  } as React.CSSProperties;
                  const onWheel = (e: React.WheelEvent<HTMLInputElement>) => { e.currentTarget.blur(); };
                  const numInput = (val: number, set: (n: number) => void) => (
                    <input
                      type="number"
                      key={String(val)}
                      defaultValue={val}
                      onBlur={(e) => {
                        const n = parseInt(e.currentTarget.value);
                        if (Number.isFinite(n) && n !== val) set(n);
                      }}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') e.currentTarget.blur();
                        else if (e.key === 'Escape') { e.currentTarget.value = String(val); e.currentTarget.blur(); }
                      }}
                      onWheel={onWheel}
                      style={inputStyle}
                    />
                  );
                  return (
                    <div style={{ marginBottom: '8px', display: 'grid', gridTemplateColumns: '1fr auto', gap: '3px 6px', alignItems: 'center' }}>
                      <span style={lblStyle} title="Smallest X overlap (units) for a jump_up/drop pair between vertically adjacent areas">min X-overlap (jump_up)</span>
                      {numInput(transMinXOverlap, setTransMinXOverlap)}
                      <span style={lblStyle} title="Maximum |dy| (units) to treat two areas as same-row for jump_across">max |dy| (jump_across)</span>
                      {numInput(transLateralY, setTransLateralY)}
                      <span style={lblStyle} title="Maximum horizontal gap (units) between two same-row areas for a jump_across">max gap (jump_across)</span>
                      {numInput(transLateralGap, setTransLateralGap)}
                    </div>
                  );
                })()}
                <div style={{ fontSize: '10px', color: '#88aacc', marginBottom: 4 }}>
                  Areas: {levelWalkableAreas.length}
                  <span
                    onClick={() => setLevelWalkableAreas([...levelWalkableAreas, { y: 0, x_min: -50, x_max: 50 }])}
                    style={{ color: '#44ffff', marginLeft: 8, cursor: 'pointer' }}
                  >
                    + add area
                  </span>
                </div>
                {levelWalkableAreas.map((a, ai) => {
                  const isDrawingThis = drawingLevelAreaIdx === ai;
                  return (
                  <div key={ai} style={{
                    display: 'flex', alignItems: 'center', gap: 3, marginBottom: 2, fontSize: '10px',
                    background: isDrawingThis ? '#003344' : 'transparent',
                    borderRadius: 3, padding: isDrawingThis ? '2px 3px' : 0,
                  }}>
                    <span style={{ color: '#888', width: 18 }}>#{ai}</span>
                    <span style={{ color: '#666' }}>y</span>
                    <input type="number" value={a.y}
                      onChange={e => { const v = parseInt(e.target.value, 10); if (Number.isNaN(v)) return;
                        const next = [...levelWalkableAreas]; next[ai] = { ...next[ai], y: v }; setLevelWalkableAreas(next); }}
                      style={{ width: 50, fontSize: '10px', padding: '1px 3px', background: '#222', color: '#fff', border: '1px solid #444', borderRadius: 2 }} />
                    <span style={{ color: '#666' }}>x</span>
                    <input type="number" value={a.x_min}
                      onChange={e => { const v = parseInt(e.target.value, 10); if (Number.isNaN(v)) return;
                        const next = [...levelWalkableAreas]; next[ai] = { ...next[ai], x_min: v }; setLevelWalkableAreas(next); }}
                      title="x_min"
                      style={{ width: 42, fontSize: '10px', padding: '1px 3px', background: '#222', color: '#fff', border: '1px solid #444', borderRadius: 2 }} />
                    <span style={{ color: '#666' }}>..</span>
                    <input type="number" value={a.x_max}
                      onChange={e => { const v = parseInt(e.target.value, 10); if (Number.isNaN(v)) return;
                        const next = [...levelWalkableAreas]; next[ai] = { ...next[ai], x_max: v }; setLevelWalkableAreas(next); }}
                      title="x_max"
                      style={{ width: 42, fontSize: '10px', padding: '1px 3px', background: '#222', color: '#fff', border: '1px solid #444', borderRadius: 2 }} />
                    <button
                      onClick={() => {
                        if (isDrawingThis) {
                          // Toggle off — cancel
                          setDrawingLevelAreaIdx(null);
                          setDrawingPreview(null);
                          drawingStartXRef.current = null;
                        } else {
                          setDrawingLevelAreaIdx(ai);
                          setDrawingPreview(null);
                          drawingStartXRef.current = null;
                        }
                      }}
                      title={isDrawingThis
                        ? 'Click+drag on the canvas to set the area, or click this button again to cancel'
                        : 'Edit area by drawing on the canvas (click+drag horizontally; Y comes from click row)'}
                      style={{
                        fontSize: '10px',
                        background: isDrawingThis ? '#0066aa' : '#1a3a3a',
                        border: '1px solid ' + (isDrawingThis ? '#00aaff' : '#3a5a5a'),
                        color: isDrawingThis ? '#fff' : '#88ccff',
                        borderRadius: 2, padding: '1px 5px', cursor: 'pointer',
                      }}
                    >✏️</button>
                    <button
                      onClick={() => {
                        const next = levelWalkableAreas.filter((_, i) => i !== ai);
                        setLevelWalkableAreas(next);
                        // Drop level transitions that reference the removed area; reindex others.
                        setLevelTransitions(levelTransitions
                          .filter(t => t.from !== ai && t.to !== ai)
                          .map(t => ({
                            ...t,
                            from: t.from > ai ? t.from - 1 : t.from,
                            to:   t.to   > ai ? t.to   - 1 : t.to,
                          })));
                        // Cancel draw mode if we were editing this row.
                        if (drawingLevelAreaIdx === ai) {
                          setDrawingLevelAreaIdx(null);
                          setDrawingPreview(null);
                          drawingStartXRef.current = null;
                        }
                      }}
                      title="Remove area"
                      style={{ fontSize: '10px', background: '#330000', border: '1px solid #660000', color: '#ff6666', borderRadius: 2, padding: '1px 5px', cursor: 'pointer' }}
                    >×</button>
                  </div>
                  );
                })}
                {levelWalkableAreas.length > 0 && (
                  <button
                    onClick={() => {
                      setLevelWalkableAreas([]);
                      setLevelTransitions([]);
                      setDrawingLevelAreaIdx(null);
                      setDrawingPreview(null);
                      drawingStartXRef.current = null;
                    }}
                    title="Remove all level walkable areas (and transitions, since they reference area indices)."
                    style={{ marginTop: 2, fontSize: '10px', background: '#330000', border: '1px solid #660000', color: '#ff6666', borderRadius: 2, padding: '2px 6px', cursor: 'pointer' }}
                  >
                    Clear areas
                  </button>
                )}
                {levelWalkableAreas.length >= 2 && (
                  <div style={{ marginTop: 6 }}>
                    <div style={{ fontSize: '10px', color: '#88aacc', marginBottom: 4 }}>
                      Transitions: {levelTransitions.length}
                      <span
                        onClick={() => setLevelTransitions([...levelTransitions, { from: 0, to: 1, type: 'jump_up' as const }])}
                        style={{ color: '#44ffff', marginLeft: 8, cursor: 'pointer' }}
                      >
                        + add transition
                      </span>
                    </div>
                    {levelTransitions.map((t, ti) => (
                      <div key={ti} style={{ display: 'flex', alignItems: 'center', gap: 3, marginBottom: 2, fontSize: '10px' }}>
                        <span style={{ color: '#888', width: 18 }}>#{ti}</span>
                        <select value={t.from}
                          onChange={e => { const next = [...levelTransitions]; next[ti] = { ...next[ti], from: parseInt(e.target.value, 10) }; setLevelTransitions(next); }}
                          style={{ fontSize: '10px', background: '#222', color: '#fff', border: '1px solid #444', borderRadius: 2 }}>
                          {levelWalkableAreas.map((_, ai) => <option key={ai} value={ai}>{ai}</option>)}
                        </select>
                        <span style={{ color: '#666' }}>→</span>
                        <select value={t.to}
                          onChange={e => { const next = [...levelTransitions]; next[ti] = { ...next[ti], to: parseInt(e.target.value, 10) }; setLevelTransitions(next); }}
                          style={{ fontSize: '10px', background: '#222', color: '#fff', border: '1px solid #444', borderRadius: 2 }}>
                          {levelWalkableAreas.map((_, ai) => <option key={ai} value={ai}>{ai}</option>)}
                        </select>
                        <select value={t.type}
                          onChange={e => { const next = [...levelTransitions]; next[ti] = { ...next[ti], type: e.target.value as 'jump_up' | 'drop' }; setLevelTransitions(next); }}
                          style={{ fontSize: '10px', background: '#222', color: '#fff', border: '1px solid #444', borderRadius: 2 }}>
                          <option value="jump_up">jump_up</option>
                          <option value="drop">drop</option>
                        </select>
                        <button
                          onClick={() => setLevelTransitions(levelTransitions.filter((_, i) => i !== ti))}
                          title="Remove"
                          style={{ fontSize: '10px', background: '#330000', border: '1px solid #660000', color: '#ff6666', borderRadius: 2, padding: '1px 5px', cursor: 'pointer' }}
                        >×</button>
                      </div>
                    ))}
                    {levelTransitions.length > 0 && (
                      <button
                        onClick={() => setLevelTransitions([])}
                        title="Remove all level transitions"
                        style={{ marginTop: 2, fontSize: '10px', background: '#330000', border: '1px solid #660000', color: '#ff6666', borderRadius: 2, padding: '2px 6px', cursor: 'pointer' }}
                      >
                        Clear transitions
                      </button>
                    )}
                  </div>
                )}
              </div>
              {heightScreens > 1 && (
                <div>
                  <div style={{ fontSize: '11px', color: '#888', fontWeight: 600, borderTop: '1px solid #3e3e3e', paddingTop: '10px', marginBottom: '6px' }}>
                    SCREEN BACKGROUNDS
                  </div>
                  <div style={{ fontSize: '10px', color: '#555', marginBottom: '8px' }}>
                    Image overlay per screen (editor-only)
                  </div>
                  {Array.from({ length: heightScreens }, (_, i) => {
                    const sb = screenBackgrounds.find(s => s.screenIndex === i);
                    return (
                      <div key={i} style={{ marginBottom: '6px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                          <span style={{ color: '#556655', fontSize: '10px', width: '48px', flexShrink: 0, fontFamily: 'monospace' }}>
                            S{i + 1}
                          </span>
                          <select
                            value={sb?.imagePath || ''}
                            onChange={e => {
                              const val = e.target.value;
                              setScreenBackgrounds(prev => {
                                const next = prev.filter(s => s.screenIndex !== i);
                                if (val) next.push({ screenIndex: i, imagePath: val, offsetY: 0 });
                                return [...next];
                              });
                            }}
                            style={{
                              flex: 1,
                              background: '#1a1a1a',
                              color: sb ? '#88bb88' : '#555',
                              border: `1px solid ${sb ? '#446644' : '#333'}`,
                              padding: '2px 3px',
                              fontSize: '10px',
                              borderRadius: '2px',
                            }}
                          >
                            <option value="">— none —</option>
                            {availableImages.map(img => <option key={img} value={img}>{img.split('/').pop()}</option>)}
                          </select>
                        </div>
                        {sb && (
                          <div style={{ display: 'flex', alignItems: 'center', gap: '4px', marginTop: '3px', paddingLeft: '52px' }}>
                            <span style={{ fontSize: '9px', color: '#556655', width: '16px', flexShrink: 0 }}>Y</span>
                            <input
                              type="range"
                              min={-255}
                              max={255}
                              value={sb.offsetY ?? 0}
                              onChange={e => {
                                const val = parseInt(e.target.value);
                                setScreenBackgrounds(prev => prev.map(s =>
                                  s.screenIndex === i ? { ...s, offsetY: val } : s
                                ));
                              }}
                              style={{ flex: 1, accentColor: '#446644', height: '12px' }}
                            />
                            <span style={{ fontSize: '9px', color: '#88bb88', width: '28px', textAlign: 'right', fontFamily: 'monospace' }}>
                              {sb.offsetY ?? 0}
                            </span>
                            <button
                              onClick={() => setScreenBackgrounds(prev => prev.map(s =>
                                s.screenIndex === i ? { ...s, offsetY: 0 } : s
                              ))}
                              title="Reset offset"
                              style={{ background: 'none', border: 'none', color: '#446644', cursor: 'pointer', fontSize: '10px', padding: '0 2px' }}
                            >↺</button>
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Save/Load Modal */}
      {showSaveLoadModal && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          backgroundColor: 'rgba(0,0,0,0.7)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000,
        }}>
          <div style={{
            backgroundColor: '#252526',
            border: '1px solid #444',
            borderRadius: '4px',
            padding: '20px',
            minWidth: '400px',
            maxWidth: '600px',
            maxHeight: '80vh',
            display: 'flex',
            flexDirection: 'column',
          }}>
            <h2 style={{ margin: '0 0 16px 0', fontSize: '16px', color: '#d4d4d4' }}>
              {modalMode === 'save' ? '💾 Save Scene' : '📁 Load Scene'}
            </h2>

            {modalMode === 'save' && (
              <div style={{ marginBottom: '16px' }}>
                <label style={{ display: 'block', marginBottom: '8px', fontSize: '12px', color: '#888' }}>
                  Scene Name:
                </label>
                <input
                  type="text"
                  value={sceneName}
                  onChange={(e) => setSceneName(e.target.value)}
                  placeholder="my_scene"
                  style={{
                    width: '100%',
                    padding: '8px',
                    fontSize: '12px',
                    backgroundColor: '#1e1e1e',
                    border: '1px solid #444',
                    borderRadius: '2px',
                    color: '#d4d4d4',
                  }}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') handleSaveScene();
                  }}
                />
              </div>
            )}

            {modalMode === 'load' && (
              <div style={{
                flex: 1,
                overflowY: 'auto',
                marginBottom: '16px',
                border: '1px solid #444',
                borderRadius: '2px',
              }}>
                {availableScenes.length === 0 ? (
                  <div style={{ padding: '20px', textAlign: 'center', color: '#666', fontSize: '12px' }}>
                    No saved scenes found
                  </div>
                ) : (
                  availableScenes.map(scene => (
                    <div
                      key={scene}
                      style={{
                        padding: '12px',
                        borderBottom: '1px solid #333',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                      }}
                    >
                      <span style={{ fontSize: '12px', color: '#d4d4d4' }}>{scene}</span>
                      <div style={{ display: 'flex', gap: '8px' }}>
                        <button
                          onClick={() => handleLoadScene(scene)}
                          style={{
                            padding: '4px 12px',
                            fontSize: '11px',
                            border: '1px solid #0e639c',
                            backgroundColor: '#0e639c',
                            borderRadius: '2px',
                            color: '#fff',
                            cursor: 'pointer',
                          }}
                        >
                          Load
                        </button>
                        <button
                          onClick={() => handleDeleteScene(scene)}
                          style={{
                            padding: '4px 12px',
                            fontSize: '11px',
                            border: '1px solid #c72e0f',
                            backgroundColor: '#c72e0f',
                            borderRadius: '2px',
                            color: '#fff',
                            cursor: 'pointer',
                          }}
                        >
                          Delete
                        </button>
                      </div>
                    </div>
                  ))
                )}
              </div>
            )}

            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
              {modalMode === 'save' && (
                <button
                  onClick={handleSaveScene}
                  style={{
                    padding: '8px 16px',
                    fontSize: '12px',
                    border: '1px solid #0e639c',
                    backgroundColor: '#0e639c',
                    borderRadius: '2px',
                    color: '#fff',
                    cursor: 'pointer',
                  }}
                >
                  Save
                </button>
              )}
              <button
                onClick={() => {
                  setShowSaveLoadModal(false);
                  setSceneName('');
                }}
                style={{
                  padding: '8px 16px',
                  fontSize: '12px',
                  border: '1px solid #444',
                  backgroundColor: '#3e3e3e',
                  borderRadius: '2px',
                  color: '#d4d4d4',
                  cursor: 'pointer',
                }}
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Toast notifications */}
      <div style={{
        position: 'fixed',
        bottom: '20px',
        right: '20px',
        display: 'flex',
        flexDirection: 'column',
        gap: '8px',
        zIndex: 10000,
      }}>
        {toasts.map(toast => (
          <div
            key={toast.id}
            style={{
              padding: '12px 16px',
              backgroundColor: toast.type === 'success' ? '#0e639c' : '#d32f2f',
              color: '#fff',
              borderRadius: '4px',
              boxShadow: '0 2px 8px rgba(0,0,0,0.3)',
              fontSize: '13px',
              minWidth: '200px',
              animation: 'slideIn 0.3s ease-out',
            }}
          >
            {toast.message}
          </div>
        ))}
      </div>
    </div>
  );
}
