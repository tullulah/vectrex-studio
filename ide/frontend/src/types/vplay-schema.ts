/**
 * VPlay Level Format v2.0 - Type Definitions
 * For Vectrex Pseudo-Python Level Designer
 */

export const VPLAY_VERSION = '2.0';

export type ObjectType = 
  | 'player_start'
  | 'enemy'
  | 'obstacle'
  | 'collectible'
  | 'background'
  | 'trigger';

export type PhysicsType = 
  | 'static'       // No movement
  | 'kinematic'    // Manual movement (controlled by code)
  | 'dynamic';     // Full physics (gravity, collisions)

export type CollisionLayer = 
  | 'none'
  | 'player'
  | 'enemy'
  | 'obstacle'
  | 'projectile'
  | 'collectible';

export type CollisionShape = 'circle' | 'rect';

export type Difficulty = 'easy' | 'medium' | 'hard';

export type AIType = 
  | 'none'
  | 'static'
  | 'patrol'
  | 'chase'
  | 'flee'
  | 'custom';

export interface VPlayMetadata {
  name: string;
  author?: string;
  difficulty?: Difficulty;
  timeLimit?: number;      // Seconds (0 = no limit)
  targetScore?: number;    // Score to complete level
  description?: string;
}

export interface VPlayWorldBounds {
  xMin: number;
  xMax: number;
  yMin: number;
  yMax: number;
}

export interface Vec2 {
  x: number;
  y: number;
}

export interface VPlayCollision {
  enabled: boolean;
  layer: CollisionLayer;
  radius?: number;         // For circle collision
  width?: number;          // For rect collision
  height?: number;
  shape: CollisionShape;
  bounceWalls?: boolean;   // Bounce on world bounds
  destroyOnCollision?: boolean;
}

export interface VPlayAI {
  type: AIType;
  speed?: number;
  waypoints?: Vec2[];
  targetTag?: string;      // For chase/flee behaviors
}

export interface VPlayPhysics {
  type: PhysicsType;
  gravity?: number;        // Gravity strength (0 = none)
  friction?: number;       // Friction coefficient (0-100)
  bounceDamping?: number;  // Bounce damping (0-100, 100 = no energy loss)
  maxSpeed?: number;       // Maximum velocity magnitude
  mass?: number;           // For collision response (future)
}

export interface VPlayCustomProperties {
  [key: string]: string | number | boolean;
}

export interface VPlayObject {
  id: string;              // Unique identifier
  type: ObjectType;
  vectorName: string;      // Reference to .vec asset
  
  // Transform
  x: number;
  y: number;
  scale?: number;          // Default: 1.0
  rotation?: number;       // Degrees 0-359 (NOTE: not supported in compiler yet)
  intensity?: number;      // 0-127, default: 127
  
  // Physics
  physics?: VPlayPhysics;
  velocity?: Vec2;         // Initial velocity
  
  // Collision
  collision?: VPlayCollision;
  
  // AI (for enemies)
  ai?: VPlayAI;
  
  // Custom properties (game-specific)
  properties?: VPlayCustomProperties;
  
  // Rendering
  layer?: 'background' | 'gameplay' | 'foreground';  // Default: 'gameplay'
  visible?: boolean;       // Default: true
  
  // Spawn control
  spawnDelay?: number;     // Frames to wait before spawning (default: 0)
  destroyOffscreen?: boolean;  // Auto-destroy if outside bounds
}

export interface VPlaySpawnPoint {
  type: string;            // Object type to spawn
  x: number;
  y: number;
  delay?: number;          // Spawn delay in seconds
  properties?: VPlayCustomProperties;
}

export interface VPlaySpawnPoints {
  player?: Vec2;           // Single player start position
  enemies?: VPlaySpawnPoint[];
  collectibles?: VPlaySpawnPoint[];
}

export interface VPlayTrigger {
  id: string;
  type: 'zone' | 'timer' | 'condition';
  
  // Zone trigger
  x?: number;
  y?: number;
  radius?: number;
  width?: number;
  height?: number;
  
  // Timer trigger
  delay?: number;          // Seconds
  
  // Condition trigger (evaluated in code)
  condition?: string;      // e.g., "all_enemies_dead", "score > 1000"
  
  // Action (handled by game code)
  action: string;          // e.g., "spawn_wave_2", "complete_level"
  properties?: VPlayCustomProperties;
}

export interface VPlayLayers {
  background: VPlayObject[];
  gameplay: VPlayObject[];
  foreground: VPlayObject[];
}

export type HotspotTrigger = 'player_near' | 'player_on' | 'projectile' | 'auto';

export interface VPlayHotspot {
  id: string;
  x: number;           // center X in Vectrex coords
  y: number;           // center Y in Vectrex coords
  w: number;           // half-width (total width = w*2)
  h: number;           // half-height (total height = h*2)
  trigger: HotspotTrigger;
  label: string;       // shown in editor and as in-game prompt
}

/**
 * Complete VPlay Level Structure v2.0
 */
export interface VPlayLevel {
  version: string;         // "2.0"
  type: 'level';           // File type identifier
  
  metadata: VPlayMetadata;
  worldBounds: VPlayWorldBounds;
  
  // New structure: organized by layers
  layers?: VPlayLayers;
  
  // Legacy: flat objects array (for backward compatibility)
  objects?: VPlayObject[];
  
  // Spawn system
  spawnPoints?: VPlaySpawnPoints;
  
  // Triggers (optional, for advanced levels)
  triggers?: VPlayTrigger[];

  // Hotspots (interactive zones queryable at runtime)
  hotspots?: VPlayHotspot[];
}

/**
 * Validation utilities
 */
export class VPlayValidator {
  static validate(level: any): { valid: boolean; errors: string[] } {
    const errors: string[] = [];
    
    // Check version
    if (!level.version) {
      errors.push('Missing version field');
    } else if (level.version !== '1.0' && level.version !== '2.0') {
      errors.push(`Unsupported version: ${level.version}`);
    }
    
    // Check type
    if (level.version === '2.0' && level.type !== 'level') {
      errors.push('Version 2.0 requires type="level"');
    }
    
    // Check metadata
    if (!level.metadata) {
      errors.push('Missing metadata field');
    } else {
      if (!level.metadata.name) {
        errors.push('Missing metadata.name');
      }
    }
    
    // Check worldBounds
    if (!level.worldBounds) {
      errors.push('Missing worldBounds field');
    } else {
      const { xMin, xMax, yMin, yMax } = level.worldBounds;
      if (xMin === undefined || xMax === undefined || yMin === undefined || yMax === undefined) {
        errors.push('Incomplete worldBounds (need xMin, xMax, yMin, yMax)');
      }
      if (xMin >= xMax) {
        errors.push('worldBounds.xMin must be < xMax');
      }
      if (yMin >= yMax) {
        errors.push('worldBounds.yMin must be < yMax');
      }
    }
    
    // Check objects (at least one of layers or objects must exist)
    const hasLayers = level.layers && (
      (level.layers.background && level.layers.background.length > 0) ||
      (level.layers.gameplay && level.layers.gameplay.length > 0) ||
      (level.layers.foreground && level.layers.foreground.length > 0)
    );
    const hasObjects = level.objects && level.objects.length > 0;
    
    if (!hasLayers && !hasObjects) {
      errors.push('Level must have either layers or objects array');
    }
    
    // Validate objects
    const allObjects = [
      ...(level.layers?.background || []),
      ...(level.layers?.gameplay || []),
      ...(level.layers?.foreground || []),
      ...(level.objects || [])
    ];
    
    allObjects.forEach((obj: any, index: number) => {
      if (!obj.id) {
        errors.push(`Object at index ${index} missing id`);
      }
      if (!obj.type) {
        errors.push(`Object ${obj.id || index} missing type`);
      }
      if (!obj.vectorName) {
        errors.push(`Object ${obj.id || index} missing vectorName`);
      }
      if (obj.x === undefined || obj.y === undefined) {
        errors.push(`Object ${obj.id || index} missing position (x, y)`);
      }
    });
    
    // Validate hotspots if present
    const validTriggers: HotspotTrigger[] = ['player_near', 'player_on', 'projectile', 'auto'];
    if (level.hotspots) {
      (level.hotspots as any[]).forEach((hs: any, index: number) => {
        if (!hs.id || hs.id.trim() === '') {
          errors.push(`Hotspot at index ${index} has empty id`);
        }
        if (!validTriggers.includes(hs.trigger)) {
          errors.push(`Hotspot ${hs.id || index} has invalid trigger: ${hs.trigger}`);
        }
        if (!(hs.w > 0)) {
          errors.push(`Hotspot ${hs.id || index} w must be > 0`);
        }
        if (!(hs.h > 0)) {
          errors.push(`Hotspot ${hs.id || index} h must be > 0`);
        }
      });
    }

    return {
      valid: errors.length === 0,
      errors
    };
  }
  
  /**
   * Migrate v1.0 to v2.0
   */
  static migrateV1toV2(v1Level: any): VPlayLevel {
    return {
      version: '2.0',
      type: 'level',
      metadata: {
        name: v1Level.name || 'Untitled Level',
        difficulty: 'medium'
      },
      worldBounds: {
        xMin: -96,
        xMax: 95,
        yMin: -128,
        yMax: 127
      },
      layers: {
        background: [],
        gameplay: v1Level.objects || [],
        foreground: []
      },
      hotspots: []
    };
  }
}

/**
 * Default empty level template
 */
export const DEFAULT_LEVEL: VPlayLevel = {
  version: '2.0',
  type: 'level',
  metadata: {
    name: 'New Level',
    difficulty: 'medium',
    timeLimit: 0,
    targetScore: 0,
    description: ''
  },
  worldBounds: {
    xMin: -96,
    xMax: 95,
    yMin: -128,
    yMax: 127
  },
  layers: {
    background: [],
    gameplay: [],
    foreground: []
  },
  spawnPoints: {
    player: { x: 0, y: -100 }
  },
  triggers: [],
  hotspots: []
};
