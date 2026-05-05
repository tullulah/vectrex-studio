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
  gravity?: number;
  bounceDamping?: number;
  physicsType?: 'gravity' | 'bounce' | 'projectile' | 'static';
  radius?: number;
  // Enemy-specific
  enemyType?: string;
  aiType?: 'static' | 'patrol' | 'chase' | 'flee';
  patrolWaypoints?: { x: number; y: number }[];
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
  const [scrollLimits, setScrollLimits] = useState<VPlayScrollLimits>({});
  const [draggingLimit, setDraggingLimit] = useState<'left' | 'right' | 'top' | 'bottom' | null>(null);
  const [selectedLimit, setSelectedLimit] = useState<'left' | 'right' | 'top' | 'bottom' | null>(null);
  const [draggingWaypointInfo, setDraggingWaypointInfo] = useState<{ enemyId: string; wpIdx: number } | null>(null);

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
                // Prefer the patrol action's sprite; fall back to first action
                let spritePath: string = '';
                const patrolAction: string = data.behavior?.patrol?.patrolAction || '';
                if (patrolAction) {
                  const act = (data.actions as any[])?.find((a: any) => a.name === patrolAction);
                  spritePath = act?.sprite || '';
                }
                if (!spritePath) spritePath = data.actions?.[0]?.sprite || '';
                if (spritePath) {
                  const filename = spritePath.split('/').pop() || '';
                  const stem = filename.endsWith('.vanim')
                    ? filename.replace('.vanim', '')
                    : filename.replace('.vec', '');
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
            if (wps.length < 2) return obj;
            const idx = enemyPatrolIdxRef.current.get(obj.id) ?? 0;
            const target = wps[idx % wps.length];
            const dx = target.x - obj.x;
            const dy = target.y - obj.y;
            const dist = Math.sqrt(dx * dx + dy * dy);
            const SPEED = (obj as any).speed ?? 1.0;
            if (dist < SPEED + 0.5) {
              enemyPatrolIdxRef.current.set(obj.id, (idx + 1) % wps.length);
              return { ...obj, x: target.x, y: target.y };
            }
            const nx = obj.x + (dx / dist) * SPEED;
            const ny = obj.y + (dy / dist) * SPEED;
            return { ...obj, x: nx, y: ny, _facingRight: dx > 0 };
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
            layer: 'gameplay' as const
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
      setSelectedHotspotId(null);
      setSelectedLimit(null);
      setSelectedId(null);
      setSceneName(name); // Remember the scene name for future saves
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
      type: 'enemy',
      vectorName: draggedVector,
      layer: 'gameplay', // Por defecto gameplay
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

    // Convert to Vectrex coordinates
    const vecX = Math.round((mouseX / rect.width) * (192 * widthScreens) + worldXMin);
    const vecY = Math.round(worldYMax - (mouseY / rect.height) * (256 * heightScreens));

    setDraggingObjectId(objId);
    setDragOffset({ x: vecX - obj.x, y: vecY - obj.y });
    setSelectedId(objId);
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

  // Middle mouse button: start pan
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

    if (draggingVelocity) {
      handleVelocityArrowDrag(e);
      return;
    }

    if (!draggingObjectId || !dragOffset || !canvasRef.current) return;

    const rect = canvasRef.current.getBoundingClientRect();
    const mouseX = e.clientX - rect.left;
    const mouseY = e.clientY - rect.top;

    // Convert to Vectrex coordinates
    const vecX = Math.round((mouseX / rect.width) * (192 * widthScreens) + worldXMin);
    const vecY = Math.round(worldYMax - (mouseY / rect.height) * (256 * heightScreens));

    // Update object position
    setObjects(objects.map(obj => 
      obj.id === draggingObjectId 
        ? { ...obj, x: vecX - dragOffset.x, y: vecY - dragOffset.y }
        : obj
    ));
  };

  const handleCanvasMouseUp = () => {
    isPanningRef.current = false;
    setIsPanning(false);
    setDraggingObjectId(null);
    setDragOffset(null);
    setDraggingVelocity(false);
    setDraggingHotspotId(null);
    setHotspotDragOffset(null);
    setDraggingLimit(null);
    setDraggingWaypointInfo(null);
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
      const isSelected = selectedId === obj.id;
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
    const isSelected = selectedId === obj.id;

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
            setHotspots([]);
            setSelectedHotspotId(null);
            setScrollLimits({});
            setSelectedLimit(null);
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
        </div>

        {/* Canvas Area */}
        <div ref={containerRef} style={{
          flex: 1,
          overflow: 'auto',
          padding: '20px',
          minWidth: 0,
          minHeight: 0,
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
                cursor: isPanning ? 'grabbing' : (activeTool === 'hotspot' || activeTool === 'enemy' || activeTool === 'patrol') ? 'crosshair' : 'default',
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

            {/* Render hotspots below objects */}
            {hotspots.map(hs => renderHotspot(hs))}

            {/* Patrol paths for enemy objects */}
            {objects.filter(o => o.type === 'enemy' && o.patrolWaypoints && o.patrolWaypoints.length > 0).map(obj => {
              const wps = obj.patrolWaypoints!;
              const isSelected = obj.id === selectedId;
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
                        {obj.aiType === 'patrol' && (
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
                          {obj.aiType === 'patrol' && (
                            <span
                              onClick={() => setActiveTool('patrol')}
                              style={{ color: '#44ffff', marginLeft: 8, cursor: 'pointer' }}
                            >
                              + draw path
                            </span>
                          )}
                        </div>
                        {(obj.patrolWaypoints?.length ?? 0) > 0 && (
                          <button
                            onClick={() => setObjects(objects.map(o => o.id === selectedId ? { ...o, patrolWaypoints: [] } : o))}
                            style={{ fontSize: '10px', background: '#330000', border: '1px solid #660000', color: '#ff6666', borderRadius: 2, padding: '2px 6px', cursor: 'pointer' }}
                          >
                            Clear waypoints
                          </button>
                        )}
                      </div>
                    )}
                    <button
                      onClick={() => {
                        setObjects(objects.filter(o => o.id !== selectedId));
                        setSelectedId(null);
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
            <div style={{ fontSize: '11px', color: '#666', fontStyle: 'italic' }}>
              No object selected
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
